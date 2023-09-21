# $Id: crypt.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Encryption/Decryption utilities.
#
# Configuration:
#    CUST_ACCT_KEY               account number encryption key          - ("")
#    CUST_NO_ENC_ACCT            do not encrypt an account number & pin - (0)
#    CUST_NO_ENC_PIN             do not encrypt pin number              - ("")
#                                overrides CUST_NO_ENC_ACCT
#    BF_DECRYPT_KEY              blowfish decrypt key                   - ("")
#    BF_DECRYPT_KEY_HEX          blowfish decrypt key in hex            - ("")
#    (One of BF_DECRYPT_KEY and BF_DECRYPT_KEY_HEX must be set)
#
# Synopsis:
#     package require util_crypt ?4.5?
#
# If not using the package within appserv, then load libOT_Tcl.so
#
# Procedures:
#    ob_crypt::init               one time initialisation
#    ob_crypt::generate_salt      generate a password salt
#    ob_crypt::encrypt_admin_password encrypt openbet admin user password
#    ob_crypt::encrypt_password   encrypt password
#    ob_crypt::encrypt_pin        encrypt pin
#    ob_crypt::encrypt_acctno     encrypt account number
#    ob_crypt::encrypt_by_bf      encrypt by blowfish
#    ob_crypt::encrypt_cardno     encrypt payment card number
#    ob_crypt::decrypt_acctno     decrypt account number
#    ob_crypt::decrypt_by_bf      decrypt by blowfish
#    ob_crypt::decrypt_cardno     decrypt payment card number
#

package provide util_crypt 4.5


# Dependencies
#
package require util_log 4.5
package require util_db 4.5



# Variables
#
namespace eval ob_crypt {

	variable CFG
	variable INIT

	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
proc ob_crypt::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_log::write DEBUG {CRYPT: init}
	ob_db::init

	# get configuration
	array set OPT [list\
	                pwd_encryption md5\
	                no_enc_acct    0\
	                no_enc_pin     ""\
	                acct_key       ""]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "CUST_[string toupper $c]" $OPT($c)]
	}

	if {[set bf_decrypt_key [OT_CfgGet BF_DECRYPT_KEY ""]] != ""} {
		set CFG(bf_decrypt_key_hex) [bintohex $bf_decrypt_key]
	} else {
		set CFG(bf_decrypt_key_hex) [OT_CfgGet BF_DECRYPT_KEY_HEX ""]
	}

	# override encoding pin, if not set use no_enc_acct
	if {$CFG(no_enc_pin) == ""} {
		set CFG(no_enc_pin) $CFG(no_enc_acct)
	}

	set CFG(admin_pwd_encryption) \
		[string toupper [OT_CfgGet ADMIN_PASSWORD_HASH MD5]]

	# hex encrypted key
	set CFG(acct_key) [md5 $CFG(acct_key)]

	# Prepare queries
	ob_crypt::_prepare_queries

	# We need to initialise this variable from the DB, including prepping the
	# query ob_crypto::get_pwd_history depending on the value
	ob_crypt::get_prev_admin_pwd_count 0

	# successfully initialised
	set INIT 1
}



# Prepare package queries on init
#
proc ob_crypt::_prepare_queries {} {

	ob_db::store_qry ob_crypt::get_admin_salt {
		select
			u.password_salt
		from
			tAdminUser u
		where
			u.username = ?
	}

	ob_db::store_qry ob_crypt::reset_admin_salt {
		update
			tAdminUser
		set
			tAdminUser.password_salt = ?
		where
			tAdminUser.username = ?;
	}

	ob_db::store_qry ob_crypt::get_user_id {
		select
			u.user_id
		from
			tAdminUser u
		where
			u.username = ? and
			u.password = ?
	}

	ob_db::store_qry ob_crypt::update_user_password {
		update
			tAdminUser
		set
			tAdminUser.password = ?,
			tAdminUser.password_salt = ?
		where
			tAdminUser.user_id = ?;
	}

	ob_db::store_qry ob_crypt::get_sha1_flag {
		select
			u.user_id as user_id,
			count(f.user_id) as has_flag
		from
			tAdminUser u,
			outer tAdminUserFlag f
		where
			u.user_id = f.user_id and
			u.username = ? and
			f.flag_name = "HASH_IS_SHA1"
		group by
			u.user_id;
	}

	ob_db::store_qry ob_crypt::add_sha1_flag {
			insert
			into tAdminUserFlag
				(user_id, flag_name)
			values
				(?, "HASH_IS_SHA1");
	}

	ob_db::store_qry ob_crypto::get_prev_pwds {
		select
			u.password,
			u.password_salt
		from
			tAdminUser u
		where
			u.username = ?
	}

	ob_db::store_qry ob_crypt::get_pwd_count {
		select
			admn_pwd_num_rpt
		from
			tControl;
	}
}



#--------------------------------------------------------------------------
# Encryption Utilities
#--------------------------------------------------------------------------

# Generate salt to be used for password encryption
#
#   returns - hex representation of salt
#
proc ob_crypt::generate_salt {} {
	set salt [string range [md5 [expr rand()]] 16 31]

	return $salt
}



# Gets the salt for an admin user, looking by username
#
#   username - the username of the admin user to get salt for
#   returns  - either NO_SUCH_USER or the user's salt (or INF_ERR
#              if there's an informix error)
#
proc ob_crypt::get_admin_salt { username } {
	set fn {ob_crypt::get_admin_salt}

	if {[catch {set rs [ob_db::exec_qry ob_crypt::get_admin_salt $username]} msg]} {
		ob_log::write ERROR {$fn: Failed to get salt - $msg}
		return [list ERROR INF_ERR]
	} else {
		set numrows [db_get_nrows $rs]

		if {$numrows < 1} {
			ob_db::rs_close $rs
			return [list ERROR NO_SUCH_USER]
		}

		set salt [db_get_col $rs 0 password_salt]
		ob_db::rs_close $rs
		return [list OK $salt]
	}
}



# Resets the specified user's password hash salt.
#
# ** ONLY USE WHEN CHANGING THE PASSWORD FOR AN ACCOUNT **
# Changing this without updating the stored hash to match will
# invalidate a user's account.
#
#   username - the username of the admin user to generate salt for
#   returns  - either NO_SUCH_USER or the user's new salt (or INF_ERR
#              if there's an informix error)
#
proc ob_crypt::reset_admin_salt { username {new_salt ""} } {
	set fn {ob_crypt::reset_admin_salt}

	if {$new_salt == ""} {
		set new_salt [ob_crypt::generate_salt]
	}

	if {[catch {set rs [ob_db::exec_qry ob_crypt::reset_admin_salt \
			$stmt \
			$new_salt \
			$username]} msg]} {
		ob_log::write ERROR {$fn: Failed to reset user salt - $msg}
		return [list ERROR INF_ERR]
	} else {
		set numrows [db_get_nrows $rs]
		ob_db::rs_close $rs
		if {$numrows < 1} {
			return [list ERROR NO_SUCH_USER]
		}

		return [list OK $new_salt]
	}
}



# Encrypt an admin user password
#
#   pwd     - plain text password to encrypt
#   salt    - optional salt to append before hashing
#   returns - encrypted password
#
proc ob_crypt::encrypt_admin_password { pwd {salt ""} } {
	if {$salt != ""} {
		set pwd ${pwd}[hextobin ${salt}]
	}

	variable CFG
	switch $CFG(admin_pwd_encryption) {
		SHA1 {
			return [sha1 -bin $pwd]
		}
		MD5 -
		default {
			return [md5 -bin $pwd]
		}
	}
}



# Converts an existing password hash into salted SHA-1
#
#   username - the username of the user to change
#   password - the password of the user to change
#
#  returns:
#	- SUCCESS      - password hash successfully changed to SHA-1
#	- WRONG_LOGIN  - username/password is not valid, this may be due to an
#                    existing SHA-1 hash
#   - INF_ERR      - informix error
#
proc ob_crypt::convert_admin_password_hash {username password} {
	set fn {ob_crypt::convert_admin_password_hash}

	if {[catch {set rs [ob_db::exec_qry ob_crypt::get_user_id \
		                       $username \
							   [md5 -bin $password]]} msg]} {
		ob_log::write ERROR {$fn: Failed to get user_id - $msg}
		return INF_ERR
	} else {
		set numrows [db_get_nrows $rs]
		if {$numrows < 1} {
			ob_db::rs_close $rs
			return WRONG_LOGIN
		}

		set user_id [db_get_col $rs 0 "user_id"]
		ob_db::rs_close $rs
	}

	set salt [ob_crypt::generate_salt]
	set hash [ob_crypt::encrypt_admin_password $password $salt]

	if {[catch {set rs [ob_db::exec_qry ob_crypt::update_user_password \
		                       $hash \
							   $salt \
							   $user_id]} msg]} {
		ob_log::write ERROR {$fn: Failed to update user password - $msg}
		return INF_ERR
	}

	ob_db::rs_close $rs
	add_admin_sha1_flag $username

	return SUCCESS
}

# Adds a flag to the tAdminUserFlags table, marking the given
# user as having an SHA-1 password hash. Will silently fail if
# one already exists.
#
#    username - the username of the user to be affected
#
#  returns:
#	- SUCCESS      - flag successfully added
#	- ALREADY_SHA1 - flag already exists
#	- NO_SUCH_USER - user_id does not exist
#   - INF_ERR      - informix error
#
proc ob_crypt::add_admin_sha1_flag {username} {
	set fn {ob_crypt::add_admin_sha1_flag}

	# Look for a matching user and check for a SHA-1 flag
	if {[catch {set rs [ob_db::exec_qry ob_crypt::get_sha1_flag \
		                       $username]} msg]} {
		ob_log::write ERROR {$fn: Failed to get sha1 flag for $username - $msg}
		return INF_ERR
	} else {
		set numrows [db_get_nrows $rs]
		if {$numrows < 1} {
			ob_db::rs_close $rs
			return NO_SUCH_USER
		}

		set user_id  [db_get_col $rs 0 "user_id"]
		set has_flag [db_get_col $rs 0 "has_flag"]
		ob_db::rs_close $rs
	}


	# If there's no SHA-1 flag, add one.
	if {$has_flag < 1} {
		if {[catch {set rs [ob_db::exec_qry ob_crypt::add_sha1_flag \
								$user_id]} msg]} {
			ob_log::write ERROR {$fn: Failed to add sha1 flag for $user_id -\
									$msg}
			return INF_ERR
		}
		return SUCCESS
	}
	return ALREADY_SHA1
}



# Checks for the presence of an entry in tAdminPassHist that conflicts
# with the given username and password. Also checks against the current
# password in tAdminUser.
#
#    username - the username of the user to be checked
#    password - the password to be checked for
#
#  returns:
#	- PWD_IS_OK      - no conflict with old password found
#	- PWD_IS_BAD     - new password matches old password
#   - INF_ERR        - informix error
#
proc ob_crypt::is_prev_admin_pwd {username password} {
	set fn {ob_crypt::is_prev_admin_pwd}

	set num_pwds [ob_crypt::get_prev_admin_pwd_count]

	# Grab password entries
	if {[catch {set rs [ob_db::exec_qry ob_crypto::get_prev_pwds \
		                       			$username]} msg]} {
		ob_log::write ERROR {$fn: Failed to get previous passwords\
								  for $username - $msg}
		return INF_ERR
	} else {
		set numrows [db_get_nrows $rs]
		if {$numrows < 1} {
			return PWD_IS_OK
		}

		set old_hash [db_get_col $rs 0 "password"]
		set old_salt [db_get_col $rs 0 "password_salt"]

		set new_hash [ob_crypt::encrypt_admin_password $password \
													   $old_salt]

		if {$new_hash == $old_hash} {
			ob_db::rs_close $rs
			return PWD_IS_BAD
		}

		ob_db::rs_close $rs
	}

	if {[catch {set rs [ob_db::exec_qry ob_crypto::get_pwd_history \
				                        $username]} msg]} {
		ob_log::write ERROR {$fn: Failed to get password histiory for\
								  $username - $msg}
		return INF_ERR
	} else {

		set numrows [db_get_nrows $rs]
		if {$numrows < 1} {
			return PWD_IS_OK
		}

		for {set i 0} {$i <  $numrows} {incr i} {
			set old_hash [db_get_col $rs $i "password"]
			set old_salt [db_get_col $rs $i "password_salt"]

			if {[string length $old_hash] < 40} {
				set new_hash [md5 $password]
			} else {
				set new_hash [ob_crypt::encrypt_admin_password $password \
															   $old_salt]
			}

			if {$new_hash == $old_hash} {
				ob_db::rs_close $rs
				return PWD_IS_BAD
			}
		}

		ob_db::rs_close $rs
		return PWD_IS_OK
	}
}



# Grabs the number of previous admin passwords to check from the database
#
# unprep - If the number of passwords to check has changed then we'll need
#          to unprep ob_crypto::get_pwd_history and reprep it...but the
#          the db-admin package doesn't support ob_db::check_qry so handle
#          the first initialisation by passing in 0 to this parameter.
proc ob_crypt::get_prev_admin_pwd_count {{unprep 1}} {
	variable CFG

	set fn {ob_crypt::get_prev_admin_pwd_count}

	# Grab the number of old passwords to check
	if {[catch {set rs [ob_db::exec_qry ob_crypt::get_pwd_count]} msg]} {
		ob_log::write ERROR {$fn: Failed to get password count - $msg}
		return INF_ERR
	} else {

		set num_pwds  [db_get_col $rs 0 "admn_pwd_num_rpt"]
		ob_db::rs_close $rs

		if {![info exists CFG(num_pwds)] || $CFG(num_pwds) != $num_pwds} {
			# We need to unprep and reprep this query as it uses the num_pwd's
			# variable it's "select first N", and the N has now changed
			if {$unprep} {
				ob_db::unprep_qry ob_crypto::get_pwd_history
			}

			ob_db::store_qry ob_crypto::get_pwd_history [subst {
				select first $num_pwds
					u.user_id,
					h.hist_pass_id,
					h.password,
					h.password_salt
				from
					tAdminUser u,
					tAdminPassHist h
				where
					u.user_id = h.user_id and
					u.username = ?
				order by h.hist_pass_id desc;
			}]

			set CFG(num_pwds) $num_pwds
		}

		return $num_pwds
	}
}



# Encrypt a customer password using the specified hashing function.
#
#   pwd     - plain text password to encrypt
#   salt    - hex salt to apply to password
#   returns - encrypted password
#
proc ob_crypt::encrypt_password { pwd {salt ""} } {

	variable CFG

	set orig_pwd $pwd

	# Append the salt if supplied
	if {$salt != ""} {
		set pwd ${pwd}[hextobin ${salt}]
	}

	#
	# It is important to use the -bin option (especially when using a salt)
	# As the behaviour can change when AS_CHARSET is turned on and the
	# input is -string (which is the default)
	#
	if {$CFG(pwd_encryption) == "sha1"} {
		return [sha1 -bin $pwd]
	} else {
		return [md5 -bin $pwd]
	}


}



# Encrypt/md5 a pin.
# If CUST_NO_ENC_PIN/CUST_NO_ENC_ACCT cfg value is set (CUST_NO_ENC_ACCT value
# is used if CUST_NO_ENC_PIN is not defined), the pin will not be encrypted.
#
#   pin     - plain text pin to encrypt
#   returns - 8 character encrypted string,
#             or pin if CUST_NO_ENC_ACCT cfg value is set
#
proc ob_crypt::encrypt_pin { pin } {

	variable CFG

	# encrypt the pin?
	if {$CFG(no_enc_pin)} {
		return $pin
	}

	set e [md5 $pin]
	set p ""
	foreach i {4 6 10 12 16 18 22 28} {
		append p [string index $e $i]
	}

	return $p
}



# Encrypt an account number.
# If CUST_NO_ENC_ACCT cfg value is set, the account number will not be
# encrypted.
# The account number is converted to a three byte blowfish encrypted number,
# zero padded to 8 characters. If the supplied account number is < 1, or
# larger than 16777216, the procedure will raise an error.
#
#   acctno  - account number to encrypt
#   returns - zero padded 8 character encrypted number,
#             or acctno if CUST_NO_ENC_ACCT cfg value is set
#
proc ob_crypt::encrypt_acctno { acctno } {

	variable CFG

	# encrypt the account number?
	if {$CFG(no_enc_acct)} {
		return $acctno
	}

	# remove leading zeros
	set acctno [string trimleft $acctno 0]

	# valid account number
	if {[string length $acctno] == 0 || $acctno > 16777216} {
		error "Account number out or range 1..16777216"
	}

	# check if account number is within 1k of max' range
	if {$acctno > 16776216} {
		ob_log::write WARNING {CUST: decrypting account number $acctno}
		ob_log::write WARNING {CUST: If this number goes above 16777216}
		ob_log::write WARNING {CUST: three byte encrytion will not work}
	}

	# dec-to-hex, swap bytes 0,2
	set h [format %06x $acctno]
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# encrypt, hex-to-dec to get decimal account number
	scan [blowfish encrypt -hex $CFG(acct_key) -hex $a] %x acctno

	# pad out account number to 8 digits
	return [format %08d $acctno]
}



# Encrypt by blowfish
#
#   data - data to encrypt
#   returns - encrypted data
#
proc ob_crypt::encrypt_by_bf { data } {

	variable CFG

	if {[string length $data] == 0} {
	    return ""
	}

	return [blowfish encrypt -hex $CFG(bf_decrypt_key_hex) -bin $data]
}



# Encrypt a payment card number by blowfish
#
#   card_no - card number to be encrypted
#   returns - encrypted card number
#
proc ob_crypt::encrypt_cardno { card_no } {

	regsub -all {[^0-9]} $card_no "" card_no

	if {[string length $card_no] == 0} {
	    return ""
	}

	set fx_num [string range $card_no 8 end][string range $card_no 0 7]

	set card_enc [ob_crypt::encrypt_by_bf $fx_num]

	return $card_enc
}




#--------------------------------------------------------------------------
# Decryption Utilities
#--------------------------------------------------------------------------

# Decrypt an account number.
# If CUST_NO_ENC_ACCT cfg value is set, the account number will not be
# decrypted.
# See ob_crypt::encrypt_acctno for details of the supplied encrypted
# account number.
#
#   acctno  - account number to decrypt
#   returns - decrypted number,
#             or acctno if CUST_NO_ENC_ACCT cfg value is set
#
proc ob_crypt::decrypt_acctno { acctno } {

	variable CFG

	# decrypt the account number?
	if {$CFG(no_enc_acct)} {
	    return $acctno
	}

	# remove leading zeros
	set acctno [string trimleft $acctno 0]

	# valid account number
	if {[string length $acctno] == 0 || $acctno > 16777216} {
	    error "Account number out or range 1..16777216"
	}

	# Decrypt, return value is a hex string
	set h [blowfish decrypt -hex $CFG(acct_key) -hex [format %06x $acctno]]

	# reverse bytes 0,2
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# hex to dec
	scan $a %x acctno

	return $acctno
}



# Decrypt by blowfish
#
#   data - data to be decrypted
#   returns - decrypted data
#
proc ob_crypt::decrypt_by_bf { data } {

	variable CFG

	if {[string length $data] == 0} {
	    return ""
	}

	set hex [blowfish decrypt -hex $CFG(bf_decrypt_key_hex) -hex $data]

	return [hextobin $hex]
}



# Decrypt card number by blowfish
#
#   enc_card_no      - encrypted card number to be decrypted
#   replace_midrange - 1 if the mid-range of card digits is to be obscured
#   returns          - decrypted card number
#
proc ob_crypt::decrypt_cardno { enc_card_no {replace_midrange 1}} {

	if {[string length $enc_card_no] == 0} {
	    return ""
	}

	set card_unenc [ob_crypt::decrypt_by_bf $enc_card_no]

	set l [string length $card_unenc]

	set bit_0 [string range $card_unenc [expr {$l-8}] end]
	set bit_1 [string range $card_unenc 0 [expr {$l-9}]]

	set card_plain $bit_0$bit_1

	if {$replace_midrange} {

	    set repl "XXXXXXXXXXXXXXXXXXXX"

	    set disp_0 [string range $card_plain 0 5]
	    set disp_1 [string range $repl 6 [expr {$l-5}]]
	    set disp_2 [string range $card_plain [expr {$l-4}] end]

	    set card_plain $disp_0$disp_1$disp_2
	}
	return $card_plain
}



# Generate ivec to be used in blowfish encryption
#
#   returns - specified length ivec
#
proc ob_crypt::generate_ivec { {len 8} } {

	set timestamp [clock seconds]
	set salt      [ob_crypt::generate_salt]
	set ivec_full [md5 ${timestamp}${salt}]
	set ivec      ""

	for {set i 0} {$i < $len} {incr i} {
		set p [expr {int(rand()*32)}]
		append ivec [string index $ivec_full $p]
	}

	return $ivec
}