# $Id: user.tcl,v 1.1 2011/10/04 12:26:34 xbourgui Exp $
# (C) 2010 Orbis Technology Ltd. All rights reserved.
#
# Handle Admin User credential changes
#
# Configuration:
#    CONVERT_ADMIN_HASHES            convert a password hash into salted SHA-1
#    PWD_REGEXPS                     reg exp for password check
#
# Synopsis:
#    package require admin_user ?4.5?
#
# Procedures:
#    ob_admin_user::init             one-time initialisation
#    ob_admin_user::update_password  perform a password check/change
#

package provide admin_user 4.5

# Dependencies
#
package require util_db    4.5
package require util_log   4.5
package require util_util  4.5
package require util_crypt 4.5

# Variables
#
namespace eval ob_admin_user {

	variable CFG

	# Config reading
	foreach {c d} {
		convert_admin_hashes    0
		chk_previous_pwds        1
		pwd_regexps             {{[a-zA-Z]} {[0-9]}}
	} {
		set CFG($c) [OT_CfgGet [string toupper $c] $d]
	}

}


#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One-time initialisation
#
proc ob_admin_user::init {} {

	variable CFG

	ob_log::write INFO {Initialise admin_user}

	_prepare_queries

}


#-------------------------------------------------------------------------------
# Public
#-------------------------------------------------------------------------------

# Perform a password check/change
#
#
# username          - Admin User username
# password_0        - Admin User current password
# password_1        - Admin User new password
# password_2        - Admin User new password (check)
# password_type     - type of password for this OpenBet customer
#     md5           - passwords based on md5
#     sha1          - passwords based on salt
# validation_only   - boolean
#     0             - a password change will be done
#     1             - new password will be checked for validity
#
# Returns
#     1 [MSG_CODE]  - successful check/change
# or
#     0 [MSG_CODE]  - failure with failure code
#
proc ob_admin_user::update_password {
	username
	password_0
	password_1
	password_2
	{password_type   md5}
	{validation_only 0}
} {

	variable CFG

	set fn {admin_user::update}

	ob_log::write INFO {$fn: Updating password for user: $username}


	# Get password prerequisites
	set pwd_min_length [ob_control::get admn_pwd_min_len]

	if {$pwd_min_length == ""} {
		set pwd_min_length 6
	}


	# Perform basic checks
	if {$password_1 != $password_2} {
		return [list 0 PWD_ERR_MISMATCH]
	}

	if {$password_0 == $password_1} {
		return [list 0 PWD_ERR_NOCHANGE]
	}

	if {[string length $password_1] < $pwd_min_length} {
		return [list 0 PWD_ERR_LEN]
	}


	# Apply regular expression to password to check its validity
	foreach rexp $CFG(pwd_regexps) {
		if {[regexp $rexp $password_1] == 0} {
			ob_log::write ERROR {$fn: ERROR - password must contain letters and numbers}
			return [list 0 PWD_ERR_INVALID]
		}
	}


	# If a validation was only required, everything is okay!
	if {$validation_only == 1} {
		return [list 1 PWD_OK]
	}


	# Should we covert the current password?
	if {$CFG(convert_admin_hashes)} {
		ob_log::write INFO {$fn: Converting admin hashes for user: $username}
		ob_crypt::convert_admin_password_hash $username $password_1
	}


	# Encode the passwords
	switch -- $password_type {
		"md5" {
			set pwd_old_md5  [ob_crypt::encrypt_admin_password $password_0]
			set pwd_new_md5  [ob_crypt::encrypt_admin_password $password_1]
		}
		"sha1" {
			set salt_resp [ob_crypt::get_admin_salt $username]
			set salt [lindex $salt_resp 1]
			if {[lindex $salt_resp 0] == "ERROR"} {
				set salt ""
			}

			set pwd_old_sha1 [ob_crypt::encrypt_admin_password $password_0 $salt]
			set pwd_new_sha1 [ob_crypt::encrypt_admin_password $password_1 $salt]
		}
	}

	# Check for duplicates in the last n passwords
	if {$CFG(chk_previous_pwds)} {
		if {[ob_crypt::is_prev_admin_pwd $username $password_1] != "PWD_IS_OK"} {
			return [list 0 PWD_ERR_REUSE]
		}
	}

	# Update the password
	switch -- $password_type {
		"md5" {
			if {[catch {set rs \
				[ob_db::exec_qry ob_admin_user::do_change_md5 \
					$username \
					$pwd_old_md5 \
					$pwd_new_md5]
			} msg]} {
				ob_log::write ERROR {$fn: ERROR - failed to change user ($username) password: $msg}
				return [list 0 PWD_ERR_UPD_FAILED]
			}
		}
		"sha1" {
			if {[catch {set rs \
				[ob_db::exec_qry ob_admin_user::do_change_sha1 \
					$username \
					$pwd_old_sha1 \
					$pwd_new_sha1 \
					$salt]
			} msg]} {
				ob_log::write ERROR {$fn: ERROR - failed to change user ($username) password: $msg}
				return [list 0 PWD_ERR_UPD_FAILED]
			}
		}
	}

	if {[db_get_coln $rs 0] == 1} {
		ob_log::write INFO {$fn: Password change successful}
		return [list 1 PWD_UPD_SUCCESS]
	} else {
		ob_log::write ERROR {$fn: ERROR - failed to change password}
		return [list 0 PWD_ERR_INVALID]
	}

}


#-------------------------------------------------------------------------------
# Private
#-------------------------------------------------------------------------------

# Prepare admin_user queries
#
proc ob_admin_user::_prepare_queries {} {

	variable CFG

	ob_db::store_qry ob_admin_user::do_change_md5 {
		execute procedure pChgAdminPwd (
			p_username = ?,
			p_old_pass = ?,
			p_new_pass = ?
		)
	}

	ob_db::store_qry ob_admin_user::do_change_sha1 {
		execute procedure pChgAdminPwd (
			p_username = ?,
			p_old_pass = ?,
			p_new_pass = ?,
			p_new_salt = ?
		)
	}

}

