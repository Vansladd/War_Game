# $Id: login-compat.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle login compatibility with non-package login APIs.
#
# Enables traces on the globals LOGIN_DETAILS, USERNAME and USER_ID. The
# customer packages do not use these variables, however, they are referenced
# by some older shared_tcl files (will be eventually phased out) and user
# applications.
# The trace will set certain LOGIN_DETAILS elements, USERNAME or USER_ID, when
# read by a caller (the variable is only set once within the scope of a
# request).
#
# The package also provides wrappers for each of the older APIs which are
# potentially still been used within other shared_tcl files or the calling
# application.
# Avoid calling the wrapper APIs within your applications, always use the
# cust_login package (ob_login namespace).
#
# The package should always be loaded when using cust_login 4.5 package.
# Do not source login.tcl when using the login packages.
#
# Configuration:
#    CUST_LOGIN_COMPAT_LOG_LEVEL    trace log symbolic level (WARNING)
#
# Synopsis:
#    package require cust_login_compat ?4.5?
#
# Procedures:
#    ob_login_compat::init          one time initialisation
#

package provide cust_login_compat 4.5



# Dependencies
#
package require util_log   4.5
package require util_crypt 4.5
package require cust_pref  4.5
package require cust_login 4.5



# Variables and export old namespace APIs
#
namespace eval ob_login_compat {

	variable CFG
	variable INIT
	variable LD_COLS

	# global LOGIN_DETAILS available columns with their variable LOGIN
	# equivalents (package cache)
	array set LD_COLS [list \
	   LOGIN_STATUS      login_status\
	   SESSION_ID        cookie\
	   USER_ID           cust_id\
	   LOGIN_TYPE        type\
	   ACCT_ID           acct_id\
	   REG_STATUS        reg_status\
	   ACCT_TYPE         acct_type\
	   STATUS            status\
	   USERNAME          username\
	   PASSWORD          pwd\
	   PASSWORD_SALT     password_salt\
	   ACCT_NO           acct_no\
	   PIN               pin\
	   MAX_STAKE_SCALE   max_stake_scale\
	   ALLOW_CARD        allow_card\
	   LANG              lang\
	   CHANNEL           channel\
	   CCY_CODE          ccy_code\
	   CNTRY_CODE        cntry_code\
	   BALANCE           balance\
	   SUM_AP            sum_ap\
	   BALANCE_NOWTD     balance_nowtd\
	   CREDIT_LIMIT      credit_limit\
	   BET_COUNT         bet_count\
	   LOGIN_COUNT       login_count\
	   ENC_PASSWORD      enc_password\
	   POSTCODE          postcode\
	   TELEPHONE         telephone\
	   EMAIL             email\
	   FIRST_NAME        first_name\
	   TEMP_AUTH         temp_auth\
	   REG_AFF_ID        aff_id]

	# init flag
	set INIT 0
}



# export old namespace APIs
namespace eval OB_login {

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
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_login_compat::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_crypt::init
	ob_cpref::init
	ob_login::init

	# get cfg
	set CFG(log_level) [OT_CfgGet CUST_LOGIN_COMPAT_LOG_LEVEL WARNING]

	# set trace on LOGIN_DETAILS
	ob_log::write WARNING {COMPAT: setting trace on LOGIN_DETAILS...}
	_create_ld_trace

	# set trace on USER_ID
	ob_log::write WARNING {COMPAT: setting trace on USER_ID...}
	_create_id_trace

	# set trace on USERNAME
	ob_log::write WARNING {COMPAT: setting trace on USERNAME...}
	_create_username_trace

	# initialised
	set INIT 1
}



#--------------------------------------------------------------------------
# LOGIN_DETAILS trace
#--------------------------------------------------------------------------

# Private procedure to create a trace on access to the global LOGIN_DETAILS.
#
proc ob_login_compat::_create_ld_trace args {

	global LOGIN_DETAILS

	array set LOGIN_DETAILS [list]
	trace variable LOGIN_DETAILS u ob_login_compat::_create_ld_trace
	trace variable LOGIN_DETAILS r ob_login_compat::_ld_trace
}



# Private procedure to set global LOGIN_DETAILS data, called the first time
# LOGIN_DETAILS element (LD_COLS & prefs,?,vals) is read within the scope of a
# request. If the requested element is not known, the procedure does nothing
# resulting in an exception been raised within the caller.
#
# Sets the data to the login package cache equivalent, via ob_login::get, or
# via cust_pref::get.
#
#   a - LOGIN_DETAILS array
#   e - LOGIN_DETAILS array element
#   o - operation (always 'r'ead)
#
proc ob_login_compat::_ld_trace { a e o } {

	variable CFG
	variable LD_COLS
	global $a

	set level $CFG(log_level)

	# Accessing an element of LD_COLS.
	if {[info exists LD_COLS($e)]} {

		# Will set the element if different request, or does not exist
		# - NB: LOGIN details can only be set via a login operation which
		#   always clears LOGIN_DETAILS, therefore, changes will be picked up!
		if {[ob_login::_auto_reset] || ![info exists ${a}($e)]} {

			ob_log::write $level {COMPAT: *************************************}
			ob_log::write $level {COMPAT: Access to LOGIN_DETAILS($e) detected}
			ob_log::write $level {COMPAT: replaced by cust_login package cache.}
			ob_log::write $level {COMPAT: Using \[ob_login::get $LD_COLS($e)\]}
			ob_log::write $level {COMPAT: *************************************}

			# get the requested data from the login package cache
			set value [ob_login::get $LD_COLS($e)]

			# if requested the login type, convert types to older format
			if {$e == "LOGIN_TYPE"} {
				if {$value == "W"} {
					set value PASSWD
				} elseif {$value == "N"} {
					set value PIN
				}
			}

			# set the global
			set ${a}($e) $value
		}

	# Accessing a customer preference
	} elseif {![info exists ${a}($e)] \
		        && [regexp {^(pref,)([0-9A-Za-z\_]+)(,vals)$} $e l p name]} {

		# only set the element if logged in
		if {[ob_login::get login_status] == "OB_OK"} {

			set cust_id [ob_login::get cust_id]

			ob_log::write $level {COMPAT: *************************************}
			ob_log::write $level {COMPAT: Access to LOGIN_DETAILS($e) detected}
			ob_log::write $level {COMPAT: replaced by cust_cpref package cache.}
			ob_log::write $level\
				{COMPAT: Using \[ob_cpref::get $name $cust_id\]}
			ob_log::write $level {COMPAT: *************************************}

			# set the global
			uplevel 1 [list set ${a}($e) [ob_cpref::get $name $cust_id]]
		}
	}
}



#--------------------------------------------------------------------------
# USER_ID trace
#--------------------------------------------------------------------------

# Private procedure to create a trace on access to the global USER_ID.
# Once all references to USER_ID have been removed from the shared_tcl, the
# trace can be removed!
#
proc ob_login_compat::_create_id_trace args {

	global USER_ID

	trace variable USER_ID u ob_login_compat::_create_id_trace
	trace variable USER_ID r ob_login_compat::_id_trace
}



# Private procedure to set global USER_ID data, called the first time
# USER_ID element is read within the scope of a request.
#
# Sets the data to the package cache equivalent, via ob_login::get
#
#   a - USER_ID array
#   e - array element (not used)
#   o - operation (always 'r'ead)
#
proc ob_login_compat::_id_trace { a e o } {

	variable CFG
	global $a

	# Will set the global if different request, or does not exist.
	# - NB: LOGIN details can only be set via a login operation which
	#   always clears USER_ID, therefore, changes will be picked up
	#
	if {[ob_login::_auto_reset] || ![info exists ${a}]} {

		set level $CFG(log_level)
		ob_log::write $level {COMPAT: *************************************}
		ob_log::write $level {COMPAT: Access to USER_ID detected}
		ob_log::write $level {COMPAT: replaced by cust_login package cache.}
		ob_log::write $level {COMPAT: Using \[ob_login::get cust_id\]}
		ob_log::write $level {COMPAT: *************************************}

		# set the global
		set ${a} [ob_login::get cust_id]
	}
}



#--------------------------------------------------------------------------
# USERNAME trace
#--------------------------------------------------------------------------

# Private procedure to create a trace on access to the global USERNAME.
# Once all references to USERNAME have been removed from the shared_tcl, the
# trace can be removed!
#
proc ob_login_compat::_create_username_trace args {

	global USERNAME

	trace variable USERNAME u ob_login_compat::_create_username_trace
	trace variable USERNAME r ob_login_compat::_username_trace
}



# Private procedure to set global USERNAME data, called the first time
# USERNAME element is read within the scope of a request.
#
# Sets the data to the package cache equivalent, via ob_login::get
#
#   a - USER_ID array
#   e - array element (not used)
#   o - operation (always 'r'ead)
#
proc ob_login_compat::_username_trace { a e o } {

	variable CFG
	global $a

	# Will set the global if different request, or does not exist.
	# - NB: LOGIN details can only be set via a login operation which
	#   always clears USERNAME, therefore, changes will be picked up
	#
	if {[ob_login::_auto_reset] || ![info exists ${a}]} {

		set level $CFG(log_level)
		ob_log::write $level {COMPAT: *************************************}
		ob_log::write $level {COMPAT: Access to USERNAME detected}
		ob_log::write $level {COMPAT: replaced by cust_login package cache.}
		ob_log::write $level {COMPAT: Using \[ob_login::get username\]}
		ob_log::write $level {COMPAT: *************************************}

		# set the global
		set username [ob_login::get username]
		if {$username == ""} {
			set ${a} guest
		} else {
			set ${a} $username
		}
	}
}



#--------------------------------------------------------------------------
# Old namespace wrappers
#--------------------------------------------------------------------------

# One time initialisation
#
proc OB_login::init_login args {
}



# Get the login UID.
#
#   returns - login UID
#
proc OB_login::get_login_uid args {
	return [ob_login::get_uid]
}



# Is guest access only.
#
#   returns - 1 if guest, zero if openbet customer
#
proc OB_login::ob_is_guest_user args {
	return [ob_login::is_guest]
}



# Not supported.
# cust_login package does not handle HTML/WML forms and HTTP cookies.
#
proc OB_login::ob_check_login args {
	error "Not supported - OB_login::ob_check_login"
}



# Not supported.
# cust_login package does not handle HTML/WML forms and HTTP cookies.
#
proc OB_login::ob_login { params {reset_cookie 1} } {
	error "Not supported - OB_login::ob_login"
}



# Not supported.
# cust_login package does not handle HTML/WML forms and HTTP cookies.
#
proc OB_login::ob_logout args {
	error "Not supported - OB_login::ob_logout"
}



# Not supported.
# cust_login package does not handle HTML/WML forms and HTTP cookies.
#
proc OB_login::make_login_cookie { params } {
	error "Not supported - OB_login::make_login_cookie"
}


# Not supported.
# Private access within cust_login package.
#
proc OB_login::login_err { err } {
	error "Not supported - OB_login::login_err"
}



# Not supported.
# cust_login package does not handle HTML/WML forms and HTTP cookies.
#
proc OB_login::ob_auto_login { {play_template Y} } {
	error "Not supported - OB_login::ob_auto_login"
}



# Encrypt a password.
#
#   pwd     - plain text password to encrypt
#   returns - encrypted password
#
proc OB_login::encrypt_password { pwd {salt ""} } {
	return [ob_crypt::encrypt_password $pwd $salt]
}



# Encrypt an account number.
#
#   acctno  - account number to encrypt
#   returns - zero padded 8 character encrypted number,
#             or acctno if CUST_NO_ENC_ACCT cfg value is set
#
proc OB_login::encrypt_acctno { acctno } {
	return [ob_crypt::encrypt_acctno $acctno]
}



# Decrypt an account number.
#
#   acctno  - account number to decrypt
#   returns - decrypted number,
#             or acctno if CUST_NO_ENC_ACCT cfg value is set
#
proc OB_login::decrypt_acctno { acctno } {
	return [ob_crypt::decrypt_acctno $acctno]
}



# Encrypt/md5 a pin.
#
#   pin     - plain text pin to encrypt
#   returns - 8 character encrypted string,
#             or pin if CUST_NO_ENC_ACCT cfg value is set
#
proc OB_login::encrypt_pin { pin } {
	return [ob_crypt::encrypt_pin $pin]
}



#--------------------------------------------------------------------------
# Start up
#--------------------------------------------------------------------------

# automatically initialise the package
ob_login_compat::init
