# # $Id: login.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval OB_login {

	namespace export LOGIN_DETAILS

	namespace export init_login
	namespace export get_login_uid
	namespace export ob_is_guest_user
	namespace export ob_check_login
	namespace export ob_login
	namespace export ob_logout
	namespace export make_login_cookie
	namespace export login_err
	namespace export ob_auto_login

	namespace export encrypt_acctno
	namespace export decrypt_acctno

	variable cfg
	set cfg(qrys_loaded) 0

	variable login
	array set login [list]


	variable  LOGGED_IN       0
	variable  LOGIN_ERR_CODES
	array set LOGIN_ERR_CODES [list\
					   2000 LOGIN_ACC_LOCK\
					   2001 LOGIN_BAD_UNAME\
					   2002 LOGIN_BAD_UNAME\
					   2003 LOGIN_BAD_REG\
					   2004 LOGIN_PARAMS_INCOMPLETE\
					   2005 LOGIN_SEQ\
					   2006 LOGIN_BAD_ACCT\
					   2007 LOGIN_BAD_PIN\
					   2008 LOGIN_ACCT_SUS\
					   2009 LOGIN_ACCT_LOCKED\
					   2010 LOGIN_ELITE\
					   2011 LOGIN_ACCT_CLOSED\
					   2012 LOGIN_IN_SELF_EXCL\
					   2013 LOGIN_OUT_SELF_EXCL]
	variable  LOGIN_ERRS
	array set LOGIN_ERRS [list\
	LOGIN_FAILED "Login Failed"\
	LOGIN_PARAMS_INCOMPLETE "Username or Password not entered"\
	LOGIN_BAD_UNAME "Incorrect Username or Password"\
	LOGIN_ACC_LOCK "Your account has been disabled for security reasons. Please contact customer services."\
	LOGIN_SEQ "Login Sequence missmatch, please try again"\
	LOGIN_BAD_ACCT "Incorrect Account Number or PIN"\
	LOGIN_BAD_PIN  "Incorrect Account Number or PIN"\
	LOGIN_BAD_DOB  "Incorrect Date of Birth"\
	LOGIN_ACCT_SUS "Your account has been disabled for security reasons. Please contact customer services."\
	LOGIN_ACCT_LOCKED "Your account has been disabled for security reasons. Please contact customer services."\
	EXPIRED_COOKIE "Your login has timed out"\
	LOGIN_IN_SELF_EXCL "Account Disabled, still within self-exclusion period."\
	LOGIN_OUT_SELF_EXCL "Account Disabled, call Customer Services to reset."]

	variable LOGIN_COOKIE_OK 0

}

# ======================================================================
# Login, one time initialisation functions
# login_init should be called before any other function in this file
# ----------------------------------------------------------------------

proc OB_login::prep_login_qrys {} {


	OB_db::db_store_qry login_keepalive {
		select login_keepalive from tcontrol
	} 3600

	OB_db::db_store_qry login_uid_qry {
		execute procedure pGenLoginUID()
	}

	if {[OT_CfgGet AMBIGUOUS_LOGIN 0]} {

		OB_db::db_store_qry login_qry {
			execute procedure plogin (
						  p_cust_id         =?,
						  p_username        =?,
						  p_password        =?,
						  p_acct_no         =?,
						  p_pin             =?,
						  p_dob             =?,
						  p_login_uid       =?,
						  p_enable_elite    =?,
						  p_ambiguous_login =?
						  )
		}
	} else {

		OB_db::db_store_qry login_qry {
			execute procedure plogin (
						  p_cust_id         =?,
						  p_username        =?,
						  p_password        =?,
						  p_acct_no         =?,
						  p_pin             =?,
						  p_dob             =?,
						  p_login_uid       =?,
						  p_enable_elite    =?
						  )
		}
	}

	OB_db::db_store_qry login_user_prefs {
		select   pref_name,
				 NVL(pref_cvalue, pref_ivalue) pref_value,
				 NVL(pref_pos,0) pref_pos
		from     tCustomerPref
		where    cust_id = ?
	}

	# Versioned user prefs. This may look similar to the query above
	# but it is different in that the query is cached. We actually
	# need to pass an *extra* parameter to this query even though
	# it is not used in the query itself. The extra parameter is
	# a user preference counter and is helps us to determine whether
	# or not the user has changed their preferences since we last
	# cached them. The preference counter doesn't get stored in the
	# db, or do anything in the query. Instead it is just an extra
	# parameter that will change when the user changes a preference.
	# The changed parameter will then cause the query to be executed
	# again as the parameters will not match any cached query.
	# Cache time: 1 hr
	OB_db::db_store_qry login_user_prefs_versioned {
		select   pref_name,
				 NVL(pref_cvalue, pref_ivalue) pref_value,
				 NVL(pref_pos,0) pref_pos
		from     tCustomerPref
		where    cust_id = ?
	} 3600

	OB_db::db_store_qry login_user_info {
	   select   a.acct_id,
				c.username,
				c.password,
				c.password_salt,
				c.acct_no,
				c.bib_pin pin,
				c.max_stake_scale,
				c.allow_card,
				c.lang,
				c.source,
				c.status,
				a.acct_type,
				a.ccy_code,
				c.country_code,
				a.balance,
				a.sum_ap,
				a.balance_nowtd,
				a.credit_limit,
				c.bet_count,
				c.password,
				c.login_count,
				c.temporary_pin,
				r.fname,
				r.addr_postcode,
				r.telephone,
				r.email,
				c.aff_id
	   from
				tCustomer c,
				tAcct a,
				tCustomerReg r
	   where
				c.cust_id = a.cust_id
	   and      r.cust_id = c.cust_id
	   and      c.cust_id = ?
	}

	# Note that we don't use the terminal's active_ccy as a terminal can place
	# bets in a number of currencies.
	OB_db::db_store_qry anon_login_user_info {
		select
			a.acct_id,
			c.username,
			c.password,
			c.acct_no,
			c.bib_pin pin,
			c.max_stake_scale,
			c.allow_card,
			c.lang,
			c.source,
			c.status,
			a.acct_type,
			a.ccy_code,
			c.country_code,
			a.balance,
			a.sum_ap,
			a.balance_nowtd,
			a.credit_limit,
			c.bet_count,
			c.password,
			c.login_count,
			c.temporary_pin,
			"" fname,
			"" lname,
			"" addr_postcode,
			"" telephone,
			"" email,
			"" aff_id
		from
			tCustomer           c,
			tAcct               a,
			tAdminTerm          t,
			outer tCustomerFlag f
		where
			c.cust_id        = ?
			and c.cust_id    = a.cust_id
			and a.acct_type  = "PUB"
			and t.term_code  = ?
			and f.cust_id    = c.cust_id
	}

	OB_db::db_store_qry get_dflt_lang {
		select default_lang from tcontrol
	}

	OB_db::db_store_qry get_uname_password_salt {
		select
			password_salt
		from
			tCustomer
		where
			username = ?
	}

	if {[OT_CfgGet WRITE_LOGIN_HISTORY 0]} {
		OB_db::db_store_qry write_login_history {
		insert into tLogin (
					cust_id,
					aff_id,
					source
					) values (?,?,?)
		}
	}
}

proc OB_login::init_login {} {

	global PREF_VERSION
	variable cfg

	prep_login_qrys

	set cfg(cookie_name)      [OT_CfgGet LOGIN_COOKIE]
	set cfg(reset_cookie)     [OT_CfgGet RESET_COOKIE 1]
	set cfg(acct_key)         [md5 [OT_CfgGet ACCT_KEY ""]]
	set cfg(require_sigdate)  [OT_CfgGet LOGIN_REQ_SIGDATE 0]
	set cfg(no_enc_acct)      [OT_CfgGet NO_ENCRYPT_ACCT 0]
	set cfg(session_id)       [OT_CfgGet SESSION_ID ""]
	set cfg(pwd_salt)         [OT_CfgGet CUST_PWD_SALT 0]
	set cfg(pwd_encryption)   [OT_CfgGet CUST_PWD_ENCRYPTION md5]
	set cfg(cookie_hmac)      [OT_CfgGet CUST_COOKIE_HMAC 0]
	set cfg(cookie_hmac_key)  [OT_CfgGet CUST_COOKIE_HMAC_KEY ""]
	set cfg(cookie_ip_addr)   [OT_CfgGet CUST_COOKIE_IP_ADDR 0]
	set cfg(cookie_gmt)       [OT_CfgGet CUST_COOKIE_GMT 0]
	set cfg(LOGGED_OUT_STR)   NOT_LOGGED_IN

	# sort out default lang
	set rs [OB_db::db_exec_qry get_dflt_lang]
	set cfg(DFLT_LANG) [db_get_col $rs 0 default_lang]
	OB_db::db_close $rs

	if {[catch {bintob64 testbase64}]} {
		set cfg(use_b64) 0
	} else {
		set cfg(use_b64) 1
	}

	if {[OT_CfgGet DECRYPT_KEY_HEX 0] == 0} {
		set cfg(key_type) bin
		set cfg(crypt_key) [OT_CfgGet DECRYPT_KEY]
	} else {
		set cfg(key_type) hex
		set cfg(crypt_key) [OT_CfgGet DECRYPT_KEY_HEX]
	}

	set PREF_VERSION -1
}

# ----------------------------------------------------------------------
# This function can be called to perform all login functions
# either using username/passwd or acctno/pin
#
# If a form element of name FormName contains the value fmLogin
# the a full login is using the values retrieved from the form
#
# Otherwise the values are retrieved from the cookie and a login
# check is used
# ----------------------------------------------------------------------

proc OB_login::ob_check_login args {

	global USER_ID USERNAME LOGIN_DETAILS
	variable login
	variable cfg
	variable LOGGED_IN
	variable LOGIN_COOKIE_OK

	if {![info exists cfg(cookie_name)]} {
		error "<<<<<<< HAVE YOU CALLED init_login >>>>>>>"
	}

	if {[lsearch $args -reset-cookie] >= 0} {
		set reset_cookie 1
	} elseif {[lsearch $args -no-reset-cookie] >= 0} {
		set reset_cookie 0
	}

	if {[lsearch $args -req-type] >= 0} {
		set req_type [lindex $args [expr {[lsearch $args -req-type]+1}]]
	} else {
		set req_type UNKNOWN
	}

	#
	# reset all the global params
	#

	set LOGGED_IN 0
	set LOGIN_COOKIE_OK 0
	set USER_ID   -1
	set USERNAME  guest
	if {[info exists LOGIN_DETAILS]} {
		unset LOGIN_DETAILS
	}
	array set LOGIN_DETAILS {}
	set LOGIN_DETAILS(LANG) $cfg(DFLT_LANG)
	set login(type)   ""
	set login(custid) ""
	set login(uname)  ""
	set login(passwd) ""
	set login(acctno) ""
	set login(pin)    ""
	set login(dob)    ""
	set login(uid)    ""


	set full_login 0
	if {[reqGetArg FormName] == "fmLogin"} {
		set full_login 1
		set retcode [read_login_params]
	} else {
		set retcode [unscramble_login_cookie]
	}

	if {$retcode != "OK"} {
		set LOGIN_DETAILS(LOGIN_STATUS) $retcode
		return $retcode
	}

	if {$req_type != "UNKNOWN" && $req_type != $login(type)} {
		ob::log::write INFO {types do not match}
		set LOGIN_DETAILS(LOGIN_STATUS) LOGIN_FAILED
		return LOGIN_FAILED
	}

	if {([OT_CfgGet AMBIGUOUS_LOGIN 0]) && ([reqGetArg FormName] == "fmLogin")} {
		set result [try_ambiguous_login]
	} else {
		# actually run the login query
		set result [try_login_qry]
	}

	if {$result != "OK"} {
		set LOGIN_DETAILS(LOGIN_STATUS) $result
		return $result
	}

	if {![info exists reset_cookie]} {
		if {$cfg(session_id) == "" && ($full_login || $cfg(reset_cookie))} {
			set reset_cookie 1
		} else {
			set reset_cookie 0
		}
	}

	#
	# reset the cookie if required
	#

	ob_login [get_param_list] $reset_cookie

	if {$full_login && [OT_CfgGet WRITE_LOGIN_HISTORY 0]} {
		write_login_hist
	}

	set LOGIN_DETAILS(LOGIN_STATUS) LOGIN_OK
	return LOGIN_OK
}


# ----------------------------------------------------------------------
# actually set the logged in state, this is done in a separate function
# so that it can be called from outside login.tcl
# ----------------------------------------------------------------------

proc OB_login::ob_login {params {reset_cookie 1}} {

	variable login
	variable LOGGED_IN
	variable LOGIN_COOKIE_OK

	set cookie [make_login_cookie $params]
	if {$reset_cookie} {
		set_cookie $cookie
	}

	switch -- [lindex $params 0] {
		"W" {set type PASSWD}
		"N" {set type PIN}
		default {set type [lindex $params 0]}
	}

	get_user_prefs $login(custid)
	get_user_info  $login(custid) $type

	set LOGGED_IN 1
	set LOGIN_COOKIE_OK 1
}


# ----------------------------------------------------------------------
# read form parameters - returning OK on success or an error code.
# if the procedure returns OK the login array will be populated
# with a code indicating the login type, a login uid and
# either a username/password or acct_no/pin with an optional dob
# ----------------------------------------------------------------------

proc OB_login::read_login_params {} {

	variable cfg
	variable login

	# need to be careful that we don't run these
	# parameters through an extra level of evaluation

	set uname   [reqGetArg -unsafe tbUsername]
	set passwd  [reqGetArg -unsafe tbPassword]
	set acctno  [reqGetArg tbAccNo]
	set pin     [reqGetArg tbPin]
	set dob     [string trim [reqGetArg tbDob]]
	set uid     [string trim [reqGetArg loginUID]]

	if {![is_safe $uname] || ![is_safe $passwd]} {
		return LOGIN_FAILED
	}


	# must trap this here as SP will assume a cookie login
	# if no UID is set
	if {$uid == ""} {
		ob::log::write INFO {no login UID}
		return LOGIN_FAILED
	}

	set login(uid) $uid

	if {[OT_CfgGet AMBIGUOUS_LOGIN 0]} {
		return [read_ambiguous_params $uname $passwd]
	}

	if {$uname != ""} {
		set login(type)   PASSWD
		set login(uname)  $uname
		set password_salt [get_uname_password_salt $uname]
		set login(passwd) [encrypt_password $passwd $password_salt]

	} elseif {$acctno != ""} {

		set login(type)   PIN
		if {[catch {set login(acctno) [decrypt_acctno $acctno]} msg]} {
			ob::log::write INFO {failed to decrypt acct_no: $acct_no}
			return LOGIN_FAILED
		}
		set login(pin) [encrypt_pin $pin]

		set reg {^([0-3][0-9])\/([0-1][0-9])\/([0-2][0-9][0-9][0-9])$}

		if {$cfg(require_sigdate)} {
			if {$dob == ""} {
				return LOGIN_PARAMS_INCOMPLETE
			}

			if {![regexp $reg $dob junk day mon year]} {
				return LOGIN_BAD_DOB
			}
			set login(dob) "${year}-${mon}-${day}"
		}

	} else {
		return LOGIN_PARAMS_INCOMPLETE
	}

	return OK
}

# ----------------------------------------------------------------------
# The username will be a username or acct_no and the passwd will be a
# password or a pin. The procedure tries to guess if this is a PIN or
# password login. If the login fails try_ambigous_login will try the
# other type of login before failing completely
# ----------------------------------------------------------------------

proc OB_login::read_ambiguous_params {uname passwd} {

	variable login

	if {[regexp {^([0-9]+)$} $passwd]} {
		# All numeric guess might be PIN
		set login(type) PIN
	} else {
		set login(type) PASSWD
	}

	set login(uname)  $uname
	set password_salt [get_uname_password_salt $uname]
	set login(passwd) [encrypt_password $passwd $password_salt]
	set login(pin) [encrypt_pin $passwd]

	return OK
}

# ----------------------------------------------------------------------
# decrypt the login cookie and store the parts in the login array
# a valid cookie consists of a key, user id, and encrypted password or pin
# the expiry time may be appended to the cookie but is optional.
#
# W<user id><encrypted passwd>?|<expiry time YYYY-mm-dd HH:MM:SS>?
# ----------------------------------------------------------------------

proc OB_login::unscramble_login_cookie {} {

	global LOGIN_DETAILS

	variable cfg
	variable login

		set cookie ""

		if {$cfg(session_id) != ""} {
			set cookie [reqGetArg $cfg(session_id)]
		} else {
			set cookie [get_cookie $cfg(cookie_name)]
		}

		#
		# for non-cookie capable platforms
		#

		if {$cookie == ""} {
			set cookie [reqGetArg sid]
			if {$cookie == ""} {
				return NO_COOKIE
			}
		}
		set LOGIN_DETAILS(SESSION_ID) $cookie

	if {$cfg(use_b64)} {

		set dec [blowfish decrypt -$cfg(key_type) $cfg(crypt_key) -b64 $cookie]
	} else {
		set dec [blowfish decrypt -$cfg(key_type) $cfg(crypt_key) -hex $cookie]
	}

	if {[catch {set dec [hextobin $dec]} msg]} {
		return BAD_COOKIE
	}

	if {$dec == $cfg(LOGGED_OUT_STR)} {
		return NO_COOKIE
	}

	# If HMAC-SHA1 is enabled, verify the cookie
	if {$cfg(cookie_hmac)} {

		set hmac_exp {^([0-9A-Za-z+/=]+)\|(.*)$}

		if {![regexp $hmac_exp $dec all hmac_cookie data]} {
			ob::log::write INFO {failed to parse hmac in cookie: $dec}
			return BAD_COOKIE
		}

		set hmac_data [hmac-sha1 -string $cfg(cookie_hmac_key) -string $data]
		set hmac_data [convertto b64 -hex $hmac_data]
		if {$hmac_cookie != $hmac_data} {
			ob::log::write INFO {cookie hmac does not match calculated hmac}
			return BAD_COOKIE
		}

		set dec $data
	}

	set    exp {^}
	append exp {([WN])}
	append exp {([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])}
	append exp {([0-9A-Za-z+/=]+)}
	append exp {(?:\|([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+))?}
	append exp {(?:\|(?:(....-..-.. ..:..:..)))?}
	append exp {$}


	if {![regexp $exp $dec all type id passwd ipaddr expiry]} {
		ob::log::write INFO {failed to parse cookie: $dec}
		return BAD_COOKIE
	}

	set login(custid) [string trimleft $id 0]
	#
	# the single char key maps to a login type
	#
	switch -- $type {

		"W" {
			set login(type) PASSWD

			if {$cfg(use_b64)} {
				set login(passwd) [convertto hex -b64 $passwd]
			} else {
				set login(passwd) $passwd
			}
		}

		"N" {
			set login(type) PIN
			set login(pin)  $passwd
		}
	}

	# Check the IP address is correct if enabled
	if {$cfg(cookie_ip_addr)} {
		set req_ipaddr [reqGetEnv REMOTE_ADDR]
		if {$ipaddr != $req_ipaddr} {
			ob::log::write INFO {cookie ipaddr does not match request ipaddr}
			return BAD_COOKIE
		}
	}


	#
	# expiry date may not be set in the cookie to save space
	# if it is then we validate it
	#

	if {$expiry != ""} {
		set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S" -gmt $cfg(cookie_gmt)]

		if {$now > $expiry} {
			return EXPIRED_COOKIE
		}
	}
	return OK
}


# ----------------------------------------------------------------------
# takes the login params as a list, adds an expiry time and returns
# the cookie string
# ----------------------------------------------------------------------

proc OB_login::make_login_cookie {params} {

	global LOGIN_DETAILS
	variable cfg
	variable login

	set type   [lindex $params 0]
	set passwd [lindex $params 2]
	set xtra   ""

	switch -- $type {
		"PASSWD" {
			set type   W
		}

		"PIN"   {
			set type   N
		}

		default {
			set login(custid) [string trimleft [lindex $params 1] "0"]
		}
	}

	set custid [format "%09d" $login(custid)]

	if {[catch {set rs [OB_db::db_exec_qry login_keepalive]} msg]} {
		ob::log::write WARNING {failed to get login keepalive: $msg}
		set keepalive 0
	} else {
		if {[db_get_nrows $rs] == 1} {
			set keepalive [db_get_coln $rs 0]
		}
		OB_db::db_close $rs
	}

	if {$keepalive > 0} {
		set now  [expr [clock seconds] + $keepalive]
		set xtra |[clock format $now -format "%Y-%m-%d %H:%M:%S" -gmt $cfg(cookie_gmt)]

	}

	if {$type == "W" && $cfg(use_b64)} {
		set passwd [convertto b64 -hex $passwd]
	}

	if {$cfg(cookie_ip_addr)} {
		set ipaddr "|[reqGetEnv REMOTE_ADDR]"
	} else {
		set ipaddr ""
	}

	set str "$type$custid$passwd$ipaddr$xtra"

	# If HMAC-SHA1 is enabled, stamp the cookie with it
	if {$cfg(cookie_hmac)} {

		set hmac [hmac-sha1 -string $cfg(cookie_hmac_key) -string $str]
		set hmac [convertto b64 -hex $hmac]

		# We place the hmac in front to give better randomness to blowfish
		set str "$hmac|$str"
	}

	set enc [blowfish encrypt -$cfg(key_type) $cfg(crypt_key) -bin $str]
	if {$cfg(use_b64)} {
		set enc [convertto b64 -hex $enc]
	}


	# session id for non cookie capable platforms
	set LOGIN_DETAILS(SESSION_ID) $enc
	tpBindString $cfg(session_id) $enc

	if {[OT_CfgGet HTML_VERSION 0] == 1} {
		tpBindString SESSION_ID $enc

		tpBindString ENC_ENC_SESSION_ID [urlencode $enc_url]
	}

		return "$cfg(cookie_name)=$enc"
}


# ----------------------------------------------------------------------
# call the login query,  on success the global values USER_ID, USERNAME
# are set and OK is returned
# ----------------------------------------------------------------------

proc OB_login::try_login_qry {} {

	global USER_ID USERNAME
	variable login

	if {[catch {set rs [OB_db::db_exec_qry login_qry \
				   $login(custid)\
				   $login(uname)\
				   $login(passwd)\
				   $login(acctno)\
				   $login(pin)\
				   $login(dob)\
				   $login(uid)\
				   [OT_CfgGet ENABLE_ELITE 0]]} msg]} {
		return [login_get_err_code $msg]
	}


	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob::log::write WARNING {pLogin returned $nrows, this should not happen}
		return LOGIN_FAILED
	}

	set USER_ID       [db_get_coln $rs 0]
	set USERNAME      [db_get_coln $rs 1]
	set login(custid) [db_get_coln $rs 0]
	set login(uname)  [db_get_coln $rs 1]
	set login(acctno) [db_get_coln $rs 2]

	return OK
}

# ----------------------------------------------------------------------
# The same as try_login_query only we aren't sure if we have a PIN or a
# PASSWD login. So we try our best guess as set by read_ambiguous_params
# and try the other one if it doesn't work.
# ----------------------------------------------------------------------

proc OB_login::try_ambiguous_login {} {

	global USER_ID USERNAME
	variable login

	for {set count 2} {$count > 0} {incr count -1 } {

		if {$login(type) == "PASSWD"} {
			set passwd $login(passwd)
			set pin ""
		} else {
			set pin $login(pin)
			set passwd ""
		}

		if {![catch {set rs [OB_db::db_exec_qry login_qry \
					   $login(custid)\
					   $login(uname)\
					   $passwd\
					   $login(acctno)\
					   $pin\
					   $login(dob)\
					   $login(uid)\
					   [OT_CfgGet ENABLE_ELITE 0]\
					   $count]} msg]}  {

			set nrows [db_get_nrows $rs]
			if {$nrows != 1} {
				ob::log::write WARNING {pLogin returned $nrows, this should not happen}
				return LOGIN_FAILED
			}

			set USER_ID       [db_get_coln $rs 0]
			set USERNAME      [db_get_coln $rs 1]
			set login(custid) [db_get_coln $rs 0]
			set login(uname)  [db_get_coln $rs 1]
			set login(acctno) [db_get_coln $rs 2]

			return OK

		} else {
			# Login Sequence Mismatch
			if {[string first "AX2005" $msg] > -1} {
				break;
			}
		}

		# read_ambigous_login will have guessed the login type
		# it might have got it wrong so we try the other
		if {$login(type) == "PASSWD"} {
			set login(type) PIN
		} else {
			set login(type) PASSWD
		}

	}

	return [login_get_err_code $msg]

}



proc OB_login::get_param_list {} {
	variable login

	set custid [format "%09d" $login(custid)]
	switch -- $login(type) {
		"PASSWD" {
			return [list W $custid $login(passwd)]
		}
		"PIN" {
			return [list N $custid $login(pin)]
		}
		default {
			ob::log::write ERROR {Invalid login type $login(type)}
			return ""
		}
	}
}


# ======================================================================
# Encryption/decryption functions for passwords pins etc
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# retrieve a customers password salt from the DB, fails silently
# ----------------------------------------------------------------------

proc OB_login::get_uname_password_salt {username} {

	variable cfg

	set password_salt ""

	set rs    [ob_db::exec_qry get_uname_password_salt $username]
	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set password_salt [db_get_col $rs 0 password_salt]
	} else {
		ob::log::write ERROR {LOGIN: get_uname_password_salt for $username returned $nrows rows}
	}

	OB_db::db_close $rs

	return $password_salt
}

proc OB_login::encrypt_acctno {plaintext} {

	variable cfg

	if {$cfg(no_enc_acct)} {
		return $plaintext
	}

	set acct_no [string trimleft $plaintext 0]

	if {[string length $acct_no] == 0 || $acct_no > 16777216} {
		error "acct_no out or range 1..16777216"
	}

	# best check if we're getting close within a thousand
	if {$acct_no > 16776216} {
		ob::log::write WARNING {WARNING: decrypting account number $acct_no.}
		ob::log::write WARNING {WARNING: If this number goes above 16777216 }
		ob::log::write WARNING {WARNING: three byte encrytion will not work.}
	}

	# dec-to-hex, swap bytes 0,2
	set h [format %06x $acct_no]
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# encrypt, hex-to-dec to get decimal account number
	scan [blowfish encrypt -hex $cfg(acct_key) -hex $a] %x acct_no

		#pad out account number to 8 digits
		set acct_no [format %08d $acct_no]

	return $acct_no
}


# ----------------------------------------------------------------------
# decrypt the account no
# ----------------------------------------------------------------------

proc OB_login::decrypt_acctno {enc_str} {
	variable cfg

	if {$cfg(no_enc_acct)} {
		return $enc_str
	}

	set acct_no [string trimleft $enc_str 0]

	if {[string length $acct_no] == 0 || $acct_no > 16777216} {
		error "acct_no out or range 1..16777216"
	}

	# Decrypt, return value is a hex string
	set h [blowfish decrypt -hex $cfg(acct_key) -hex [format %06x $acct_no]]

	# reverse bytes 0,2
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# hex to dec
	scan $a %x acct_no

	return $acct_no
}




# ======================================================================
# after login customer account details can be accessed through the
# global array LOGIN_DETAILS
# ----------------------------------------------------------------------
# Get the customer prefs and store in global array LOGIN_DETAILS
# ----------------------------------------------------------------------

proc OB_login::get_user_prefs {cust_id} {

	global LOGIN_DETAILS
	global PREF_VERSION

	if {$PREF_VERSION > -1} {
		# Pass the extra PREF_VERSION value to the query to control our cached preferences
		if {[catch {set rs [OB_db::db_exec_qry login_user_prefs_versioned $cust_id $PREF_VERSION]} msg]} {
			ob::log::write ERROR {failed to get user preferences: $msg}
			return
		}
	} else {
		if {[catch {set rs [OB_db::db_exec_qry login_user_prefs $cust_id]} msg]} {
			ob::log::write ERROR {failed to get user preferences: $msg}
			return
		}
	}

	#
	# Don't assume any ordering in the result set -- we sort it here...
	#
	set nrows [db_get_nrows $rs]

	set x_names [list]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend x_names  [set pname [db_get_col $rs $i pref_name]]
		lappend v_$pname [list\
			[db_get_col $rs $i pref_pos] [db_get_col $rs $i pref_value]]
	}

	foreach un [set LOGIN_DETAILS(prefs) [lsort -ascii -unique $x_names]] {
		set t [list]
		foreach li [lsort -index 0 -integer [set v_$un]] {
			lappend t [lindex $li 1]
		}
		set LOGIN_DETAILS(pref,$un,vals) $t
	}

	OB_db::db_close $rs
}


# ----------------------------------------------------------------------
# get some customer acct details and store in global array LOGIN_DETAILS
# ----------------------------------------------------------------------

proc OB_login::get_user_info {cust_id type {sort ""} {term_code ""}} {
	global LOGIN_DETAILS

	if {$term_code == ""} {
		set term_code [reqGetArg term_code]
	}

	if {$sort == "CASH"} {
		set qry_name "anon_login_user_info"
		set LOGIN_DETAILS(ANON_CASH_BET) "Y"
	} else {
		set qry_name "login_user_info"
		set LOGIN_DETAILS(ANON_CASH_BET) "N"
	}

	if {[catch {
		set rs [OB_db::db_exec_qry $qry_name $cust_id $term_code]
	} msg]} {
		ob::log::write ERROR {failed to get user info : $cust_id :$msg}
		return
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob::log::write ERROR {Error: get user info: $cust_id: got $nrows rows}
	} else {
		set LOGIN_DETAILS(USER_ID)          $cust_id
		set LOGIN_DETAILS(LOGIN_TYPE)       $type
		set LOGIN_DETAILS(ACCT_ID)          [db_get_col $rs acct_id]
		set LOGIN_DETAILS(ACCT_TYPE)        [db_get_col $rs acct_type]
		set LOGIN_DETAILS(STATUS)           [db_get_col $rs status]
		set LOGIN_DETAILS(USERNAME)         [db_get_col $rs username]
		set LOGIN_DETAILS(PASSWORD)         [db_get_col $rs password]
		set LOGIN_DETAILS(PASSWORD_SALT)    [db_get_col $rs password_salt]
		set LOGIN_DETAILS(ACCT_NO)          [db_get_col $rs acct_no]
		set LOGIN_DETAILS(PIN)              [db_get_col $rs pin]
		set LOGIN_DETAILS(MAX_STAKE_SCALE)  [db_get_col $rs max_stake_scale]
		set LOGIN_DETAILS(ALLOW_CARD)       [db_get_col $rs allow_card]
		set LOGIN_DETAILS(LANG)             [db_get_col $rs lang]
		set LOGIN_DETAILS(CHANNEL)          [db_get_col $rs source]
		set LOGIN_DETAILS(CCY_CODE)         [db_get_col $rs ccy_code]
		set LOGIN_DETAILS(CNTRY_CODE)       [db_get_col $rs country_code]
		set LOGIN_DETAILS(BALANCE)          [db_get_col $rs balance]
		set LOGIN_DETAILS(SUM_AP)           [db_get_col $rs sum_ap]
		set LOGIN_DETAILS(BALANCE_NOWTD)    [db_get_col $rs balance_nowtd]
		set LOGIN_DETAILS(CREDIT_LIMIT)     [db_get_col $rs credit_limit]
		set LOGIN_DETAILS(BET_COUNT)        [db_get_col $rs bet_count]
		set LOGIN_DETAILS(LOGIN_COUNT)      [db_get_col $rs login_count]
		set LOGIN_DETAILS(ENC_PASSWORD)     [db_get_col $rs password]
		set LOGIN_DETAILS(POSTCODE)         [db_get_col $rs addr_postcode]
		set LOGIN_DETAILS(TELEPHONE)        [db_get_col $rs telephone]
		set LOGIN_DETAILS(EMAIL)            [db_get_col $rs email]
		set LOGIN_DETAILS(FIRST_NAME)       [db_get_col $rs fname]
		set LOGIN_DETAILS(REG_AFF_ID)       [db_get_col $rs aff_id]

		switch -- $type {
			"PIN"    {set temp_auth         [db_get_col $rs temporary_pin]}
			default  {set temp_auth         "N"}
		}
		set LOGIN_DETAILS(TEMP_AUTH)        $temp_auth
	}

	OB_db::db_close $rs
}


# ----------------------------------------------------------------------
# write the login history to the database
# ----------------------------------------------------------------------

proc OB_login::write_login_hist {} {
	global LOGIN_DETAILS

	set custid $LOGIN_DETAILS(USER_ID)
	set affid  [get_cookie AFF_ID]
	set chan   [OT_CfgGet CHANNEL I]


	if {[catch {set rs [OB_db::db_exec_qry write_login_history \
				   $custid $affid $chan]} msg]} {

		## Unfortunate, but not the end of the world.
		## Return LOGIN_OK message anyway.

		ob::log::write ERROR {Failed to write into tLogin: $custid, $affid, $chan: $msg}
	}
}




# ======================================================================
# utility functions
# ----------------------------------------------------------------------
# check whether a tcl string contains and dodgy characters
# if CHARSET is set convert from the appropriate encoding first
# ----------------------------------------------------------------------

proc OB_login::is_safe {str} {
	global CHARSET

	if {[info exists CHARSET]} {
		if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8")} {
			set str [encoding convertfrom $CHARSET $str]
		}
	}

	if {[regexp {[][${}\\]} $str]} {
		return 0
	}
	return 1
}


# ----------------------------------------------------------------------
# return the symbolic error for an sp error code
# ----------------------------------------------------------------------

proc OB_login::login_get_err_code msg {

		variable LOGIN_ERR_CODES

	if {[regexp {AX([0-9][0-9][0-9][0-9])} $msg match err_code]} {

		return $LOGIN_ERR_CODES($err_code)
		}

		return LOGIN_FAILED
}

# ----------------------------------------------------------------------
# return an english message for a symbolic error_code
# ----------------------------------------------------------------------

proc OB_login::login_err err {

	variable LOGIN_ERRS

	if {[set msg [ml_printf $err]]==$err} {
		if ![info exists LOGIN_ERRS($err)] {
				return "Unknown Login Error: $err"
		}
		return $LOGIN_ERRS($err)
	} else {
		return $msg
	}
}


# ----------------------------------------------------------------------
# returns the next login uid
# ----------------------------------------------------------------------

proc OB_login::get_login_uid {} {

	if {[OT_CfgGet LOGIN_UID_IS_TIME 0]} {
		return [clock seconds]
	}

	set uid -1

	if {[catch {set rs [OB_db::db_exec_qry login_uid_qry]} msg]} {
		ob::log::write ERROR {Failed to get new login uid: $msg}
		return $uid
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {pGenLoginUID returned [db_get_nrows $rs] rows}
	} else {
		set uid [db_get_coln $rs 0 0]
	}

	OB_db::db_close $rs

	return $uid
}


# ----------------------------------------------------------------------
# set the logout cookie
# ----------------------------------------------------------------------

proc OB_login::ob_logout {} {
	variable cfg
	variable LOGGED_IN
	variable LOGIN_COOKIE_OK

	set LOGGED_IN  0

	if {$cfg(session_id) != ""} {
		return
	}


	set str $cfg(LOGGED_OUT_STR)

	set LOGIN_COOKIE_OK  0

	set enc [blowfish encrypt -$cfg(key_type) $cfg(crypt_key) -bin $str]

	if {$cfg(use_b64)} {
		set enc [convertto b64 -hex $enc]
	}
	set_cookie $cfg(cookie_name)=$enc
}


# ----------------------------------------------------------------------
# is the user logged in
# ----------------------------------------------------------------------

proc OB_login::ob_is_guest_user {} {
	variable LOGGED_IN
	variable LOGIN_COOKIE_OK

	# If we have only logged in by cookie and we are now wanting to check
	# that the user is not a guest we should do a full login
	if {$LOGIN_COOKIE_OK && !$LOGGED_IN} {
		ob_check_login
	}

	return [expr {1 - $LOGGED_IN}]
}

proc OB_login::log {level msg} {
	ob::log::write $level {Login: $msg}
}

#########################################################################
# Automatic login after a successful registration
#########################################################################
proc OB_login::ob_auto_login { {play_template Y} } {
	variable login
	global LOGIN_DETAILS USER_ID

	set uname   [reqGetArg -unsafe tbUserName]
	set passwd  [reqGetArg -unsafe tbPassword1]
	set pin     [reqGetArg tbPin1]
	set login(custid)  $USER_ID

	if {$uname != ""} {

		set login(type)   PASSWD
		set login(uname)  $uname
		set password_salt [get_uname_password_salt $uname]
		set login(passwd) [encrypt_password $passwd $password_salt]

		set params $login(type)
		lappend params $login(uname)
		lappend params $login(passwd)

	} elseif {$pin != ""} {
		if {[catch {set rs [OB_db::db_exec_qry login_user_info $login(custid)]} msg]} {
			ob::log::write ERROR {auto_login: Failed to retrieve acct_no for $login(cust_id): $msg}
			return 1
		}
		set login(type) PIN
		set login(acctno)   [db_get_col $rs acct_no]
		set login(pin)  [encrypt_pin $pin]
		set enc_acctno  [encrypt_acctno $login(acctno)]

		set params $login(type)
		lappend params $login(acctno)
		lappend params $login(pin)

		OB_db::db_close $rs

		tpBindString ACCT_NO $enc_acctno
	}

	ob_login $params

	if {[OT_CfgGet WRITE_LOGIN_HISTORY 0]} {
		write_login_hist
	}

	set LOGIN_DETAILS(LOGIN_STATUS) LOGIN_OK

	# Set-up price-type user prefs
	set price_type [reqGetArg tbPriceType]
	ob::log::write DEV {Price Type is $price_type}
	if {$price_type != ""} {
		OB_prefs::set_pref PRICE_TYPE $price_type
	}

	if {$play_template == "Y"} {
		play_reg_template RegSuccess
	}
}

# ----------------------------------------------------------------------
# checks whether the user cookie is still valid, but does not actually
# log the user in. This can be used for a very lite login that does
# not need any customer details from the database. If you then need to
# know later in the request whether a customer was logged in you
# should use ob_cookie_login_ok rather than ob_is_guest_user. Use with
# care - do not use for anything requiring any security!
# ----------------------------------------------------------------------
proc OB_login::ob_cookie_login {{reset_cookie 1}} {

	global USER_ID USERNAME LOGIN_DETAILS
	variable login
	variable cfg
	variable LOGGED_IN
	variable LOGIN_COOKIE_OK

	if {![info exists cfg(cookie_name)]} {
		error "<<<<<<< HAVE YOU CALLED init_login >>>>>>>"
	}

	set LOGGED_IN 0
	set LOGIN_COOKIE_OK 0
	set USER_ID   -1
	set USERNAME  guest
	if {[info exists LOGIN_DETAILS]} {
		unset LOGIN_DETAILS
	}
	array set LOGIN_DETAILS {}
	set LOGIN_DETAILS(LANG) $cfg(DFLT_LANG)
	set login(type)   ""
	set login(custid) ""
	set login(uname)  ""
	set login(passwd) ""
	set login(acctno) ""
	set login(pin)    ""
	set login(dob)    ""
	set login(uid)    ""


	# Check that the cookie is still valid
	set retcode [unscramble_login_cookie]
	if {$retcode != "OK"} {
		set LOGIN_DETAILS(LOGIN_STATUS) $retcode
		return $retcode
	}

	# do we want to reset the cookie?
	if {$reset_cookie && $cfg(session_id) == "" && $cfg(reset_cookie)} {
		set_cookie [make_login_cookie [get_param_list]]
	}

	set USER_ID $login(custid)
	set LOGIN_DETAILS(USER_ID) $USER_ID
	set LOGIN_COOKIE_OK 1

	return COOKIE_OK
}

# ----------------------------------------------------------------------
# checks whether the user logged in ok, use instead of ob_is_guest_user
# if only cookie login was used
# ----------------------------------------------------------------------
proc OB_login::ob_cookie_login_ok {} {
	variable LOGIN_COOKIE_OK
	return $LOGIN_COOKIE_OK
}
