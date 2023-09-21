# $Id: login.tcl,v 1.1 2011/10/04 12:26:34 xbourgui Exp $
#  2005 Orbis Technology Ltd. All rights reserved.
#
# Handle Admin User/Operator login & logout.
#
# Configuration:
#    ADMIN_LOGIN_KEEPALIVE           login keepalive                   - (14000)
#    ADMIN_LOGIN_KEY                 encryption key
#    ADMIN_LOGIN_CACHE_PERM          permission cache time             - (0)
#    ADMIN_LOGIN_JUST_CHECK_LOGIN    pAdminLogin uses p_just_chk_login - (1)
#    ADMIN_LOGIN_LOC                 default login location            - ("")
#                                    if "", then uses IP address from req' env'
#    ADMIN_LOGIN_STORE_USER_ID       Whether or not to tag the login with the user_id
#    ADMIN_LOGIN_STORE_AUTH_KEY_ID   Whether or not to tag the login with a unique
#                                    auth_key_id and store that in the login cookie.
#                                    Is created on login only and can be retrieved from cookie only.
#
# Synopsis:
#    package require admin_login ?4.5?
#
# Procedures:
#    ob_admin_login::init            one-time initialisation
#    ob_admin_login::get             get admin user information
#    ob_admin_login::has_permission  user got a permission set
#    ob_admin_login::force_update    force an update of the user login info
#    ob_admin_login::is_guest        is_guest
#    ob_admin_login::form_login      form login
#    ob_admin_login::logout          logout
#    ob_admin_login::check_cookie    cookie (only) login
#    ob_admin_login::get_uid         get login UID
#

package provide admin_login 4.5



# Dependencies
#
package require util_db    4.5
package require util_log   4.5
package require util_util  4.5
package require util_crypt 4.5



# Variables
#
namespace eval ob_admin_login {

	variable CFG
	variable INIT
	variable LOGIN
	variable ERR_CODE
	variable COOKIE_COLS

	# current request number
	set LOGIN(req_no) ""

	# init flag
	set INIT 0

	# cookie date items
	set COOKIE_COLS [list uid login_status critical username pwd cookie]

	# pAdminLogin stored procedure error code translations
	array set ERR_CODE [list\
	    2100 OB_ERR_ADMIN_USER_SUSP\
	    2101 OB_ERR_ADMIN_USERNAME\
	    2102 OB_ERR_ADMIN_LOGIN_SEQ\
	    2103 OB_ERR_ADMIN_LOGIN_LOC\
	    2105 OB_ERR_ADMIN_PWD_EXPIRED\
	    2109 OB_ERR_ADMIN_USE_LOCK]
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare the queries
#
# Can specify any of the configuration items as a name value pair (overwrites
# file configuration), names are
#
#     -keepalive
#     -key
#     -cache_perm
#
proc ob_admin_login::init args {

	variable CFG
	variable INIT
	variable COOKIE_COLS

	# already initialised
	if {$INIT} {
		return
	}

	# can auto-reset login details?
	if {[info commands reqGetId] == ""} {
		error "ADMIN_LOGIN: reqGetId not available for auto reset"
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_crypt::init

	ob_log::write DEBUG {ADMIN_LOGIN: init}

	# load the config' items via args
	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	# load config
	array set OPT [list \
	    key              ""\
	    key_secure       ""\
	    keepalive        14000\
	    keepalive_secure 14000\
	    cache_perm       0\
	    just_check_login 1\
	    check_password_expiry N\
	    store_auth_key_id 0\
	    store_user_id    0\
	    loc              ""]

	foreach c [array names OPT] {
		if {![info exists CFG($c)]} {
			set CFG($c) [OT_CfgGet ADMIN_LOGIN_[string toupper $c] $OPT($c)]
		}
	}

	if {$CFG(key) == ""} {
		error "ADMIN_LOGIN: encryption key not defined"
	}

	if {$CFG(cache_perm) > 0} {
		ob_log::write WARNING {ADMIN_LOGIN: caching permissions}
	}

	if {!$CFG(just_check_login)} {
		ob_log::write WARNING {ADMIN_LOGIN: just_check_login disabled}
	}

	# prepare the queries
	_prepare_qrys

	# denote we have already initialised
	set INIT 1

	if {$CFG(store_user_id)} {
		lappend COOKIE_COLS user_id
	}
}



# Private procedure to prepare the package queries
#
proc ob_admin_login::_prepare_qrys {} {

	variable CFG

	# get login-uid
	ob_db::store_qry ob_admin_login::get_uid {
		execute procedure pGenAdminLoginUID()
	}

	# login
	if {$CFG(just_check_login)} {
		ob_db::store_qry ob_admin_login::login [subst {
			execute procedure pAdminLogin(
			    p_username       = ?,
			    p_password       = ?,
			    p_login_uid      = ?,
			    p_login_loc      = ?,
			    p_just_chk_login = ?,
				p_pwd_expires    = "$CFG(check_password_expiry)"
			)
		}]
	} else {
		ob_db::store_qry ob_admin_login::login [subst {
			execute procedure pAdminLogin(
			    p_username       = ?,
			    p_password       = ?,
			    p_login_uid      = ?,
			    p_login_loc      = ?,
				p_pwd_expires    = "$CFG(check_password_expiry)"
			)
		}]
	}

	# logout
	ob_db::store_qry ob_admin_login::logout {
		execute procedure pAdminLogout(
		    p_username = ?
		)
	}

	# get admin user details
	ob_db::store_qry ob_admin_login::get {
		select
		    username,
		    fname,
		    lname,
		    status,
		    login_time
		from
		    tAdminUser
		where
		    user_id = ?
	}

	# get admin user permissions
	# - user specified cache (0 indicated no cache)
	#   NB: if caching, then any permission update will not be immediately
	#       realised until the cache expires
	ob_db::store_qry ob_admin_login::get_permissions {
		select
		    action
		from
		    tAdminUserOp
		where
		    user_id = ?

		union

		select
		    gop.action
		from
		    tAdminUserGroup ug,
		    tAdminGroupOp   gop
		where
		    ug.user_id      = ?
		and ug.group_id     = gop.group_id

		union

		select
		    gop.action
		from
		    tAdminPosnGroup pg,
		    tAdminGroupOp   gop,
		    tAdminUser      u
		where
		    u.user_id      = ?
		and u.position_id  = pg.position_id
		and pg.group_id    = gop.group_id
	} $CFG(cache_perm)
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_admin_login::_auto_reset args {

	variable LOGIN

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$LOGIN(req_no) != $id} {
		catch {unset LOGIN}
		set LOGIN(req_no) $id
		ob_log::write DEV {ADMIN_LOGIN: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}



# Private procedure to clear the login details.
#
proc ob_admin_login::_clear args {

	variable LOGIN

	foreach c {uid pwd username cookie cookie permission} {
		set LOGIN($c) ""
	}
}



#--------------------------------------------------------------------------
# Accessor
#--------------------------------------------------------------------------

# Get a login data item.
# The admin-user data is stored within the package cache, loaded from
# database if not previously done so within the scope of a request.
#
#   name    - admin-user data name
#   dflt    - default data value if the requested data item contains no data
#             (default: "")
#   returns - list {status data}
#
proc ob_admin_login::get { name {dflt ""} } {

	variable CFG
	variable LOGIN
	variable COOKIE_COLS

	# different request, or no username (!performed a login, or failed login)?
	if {[_auto_reset] ||\
	        (![info exists LOGIN(username)] || $LOGIN(username) == "")} {

		if {$name == "login_status" && [info exists LOGIN(login_status)] &&\
				$LOGIN(login_status) != ""} {
			return [list OB_ERR_ADMIN_GUEST $LOGIN(login_status)]
		}

		return [list OB_ERR_ADMIN_GUEST $dflt]
	}

	# if requesting a non DB data, can only be retrieved from cookie
	if {$name == "auth_key_id"} {
		if {![info exists LOGIN(auth_key_id)]} {
			return [list OB_ERR_ADMIN_NO_DATA $dflt]
		}
		return $LOGIN(auth_key_id)
	}

	# if requesting a non-cookie data item and only performed a cookie check,
	# do a critical login
	# - if failed, then return default value (login_status will contain error
	#   details)
	set cookie_col [lsearch $COOKIE_COLS $name]
	if {$cookie_col == -1 && $LOGIN(critical) == 0} {

		ob_log::write DEBUG {ADMIN_LOGIN: get critical ($name) - perfom login}

		set LOGIN(critical) 1
		set LOGIN(login_status) [_db_login]

		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			ob_log::write ERROR\
			    {ADMIN_LOGIN: critical login failed - $LOGIN(login_status)}
			return [list $LOGIN(login_status) $dflt]
		}

	# else if a cookie data item, then return the data
	} elseif {$cookie_col != -1 && $LOGIN(critical) == 0} {
		if {$LOGIN($name) != ""} {
			return [list OB_OK $LOGIN($name)]
		} else {
			return [list OB_OK $dflt]
		}
	}

	# force an update, i.e. something about the user has changed
	if {[info exists LOGIN(force_update)] && $LOGIN(force_update)} {
		ob_log::write DEBUG {ADMIN_LOGIN: forced update detected}
		set force_upd 1
	} else {
		set force_upd 0
	}

	# does data already exist
	# - if blank, have an attempt to fetch from database 1st
	if {!$force_upd && [info exists LOGIN($name)] && $LOGIN($name) != ""} {
		return [list OB_OK $LOGIN($name)]
	}

	# already retreived data
	if {!$force_upd && [info exists LOGIN(qry)]} {
		if {![info exists LOGIN($name)]} {
			return [list OB_ERR_ADMIN_NO_DATA $dflt]
		}
		return [list OB_OK $dflt]
	}

	# get the data
	if {[_load] != "OB_OK"} {
		return [list $LOGIN(login_status) $dflt]
	}

	# does data exist?
	if {[info exists LOGIN($name)]} {
		if {$LOGIN($name) != ""} {
			return [list OB_OK $LOGIN($name)]
		} else {
			return [list OB_OK $dflt]
		}
	} else {
		return [list OB_ERR_ADMIN_NO_DATA $dflt]
	}
}



# Has the current user got a particular permission.
# Will perform a critical login if not done within the scope of the request
#
#   action  - permission action
#   returns - 1 if the user has the permission, 0 if not, or not logged in
#
proc ob_admin_login::has_permission { action } {

	variable LOGIN

	# different request, or no username (! performed a login, or failed login)?
	if {[_auto_reset] ||\
	        (![info exists LOGIN(username)] || $LOGIN(username) == "")} {
		return 0
	}

	# get the permissions
	# - performs a critical login if not done within scope of the request
	foreach {status permission} [get permission] {}
	if {$status != "OB_OK"} {
		ob_log::write ERROR {ADMIN_LOGIN: has_permission $status}
		return 0
	}

	return [expr {[lsearch $permission $action] >= 0}]
}



# Force an update of the login-data.
# The package cannot detect if any of data has changed within the scope of a
# request. This method simply denotes that the next get accessor call will
# reload the data.
#
proc ob_admin_login::force_update args {

	variable LOGIN

	if {![_auto_reset]} {
		set LOGIN(force_update) 1
	}
}



# Private procedure to load data from the database and add to the package
# cache.
#
proc ob_admin_login::_load args {

	variable LOGIN

	# load
	set rs [ob_db::exec_qry ob_admin_login::get $LOGIN(user_id)]
	if {[db_get_nrows $rs] != 1} {
		set LOGIN(login_status) OB_ERR_ADMIN_NO_USER
		ob_db::rs_close $rs
		return $LOGIN(login_status)
	}

	set cols [db_get_colnames $rs]
	foreach c $cols {
		set LOGIN($c) [db_get_col $rs 0 $c]
	}
	ob_db::rs_close $rs

	# get user permissions
	set LOGIN(permission) [list]
	set rs [ob_db::exec_qry ob_admin_login::get_permissions\
	        $LOGIN(user_id) $LOGIN(user_id) $LOGIN(user_id)]

	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend LOGIN(permission) [db_get_col $rs $i action]
	}
	ob_db::rs_close $rs

	# denote data is loaded
	set LOGIN(qry)          1
	set LOGIN(force_update) 0

	return OB_OK
}



#--------------------------------------------------------------------------
# Login
#--------------------------------------------------------------------------

# Is guest access only.
#
# Determines if the admin-user has successfully logged in within the scope of a
# request. If only performed a ::check_cookie, the procedure will verify the
# cookie details against the database (failure will result in guest access
# only).
#
#   returns - 1 if guest, 0 if admin-user
#
proc ob_admin_login::is_guest args {

	variable LOGIN

	# guest if new request, or no username
	# - no username will also denote a failed login attempt, as the
	#   the login data items are always cleared on error
	if {[_auto_reset] ||  \
	        (![info exists LOGIN(username)] || $LOGIN(username) == "")} {

		# denote guest access error?
		if {![info exists LOGIN(login_status)] || $LOGIN(login_status) == ""} {
			set LOGIN(login_status) OB_ERR_ADMIN_GUEST
		}

		return 1
	}

	# if only performed a check_cookie, then must verify the
	# details against the database before determining if a guest user
	# - NB: if login error, then denote as a guest
	if {$LOGIN(critical) == 0} {

		ob_log::write DEBUG {ADMIN_LOGIN: is_guest performing login}

		set LOGIN(critical) 1
		set LOGIN(login_status) [_db_login]

		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			ob_log::write ERROR \
			    {ADMIN_LOGIN: critical login failed - $LOGIN(login_status)}
			return 1
		}
	}

	# non-guest
	return 0
}



# Perform form based login (supplied a username and pwd).
#
# Checks the supplied details against the database, via pAdminLogin stored
# procedure and encrypts a login cookie (stored in package cache).
#
# The procedure allows multiple login calls per request. The package cache is
# always reset.
#
# NB: The procedure does not get the login parameters from a HTML/WML form, or
# set the login-cookie. It is caller's responsibility to get and supply the
# login details and store the cookie within a HTTP header or form argument.
#
#   username - username or acct_no (depends on type or if ambiguous login)
#   pwd      - unencrypted password or pin
#   uid      - login uid (should be different per login request)
#   ip_addr  - IP address (if not defined, then uses cfg ADMIN_LOGIN_LOC)
#   returns  - login status string (OB_OK denotes success)
#
proc ob_admin_login::form_login { username pwd uid {ip_addr ""} {is_secure N} } {

	variable LOGIN
	variable CFG

	ob_log::write DEBUG {ADMIN_LOGIN: form login user=$username uid=$uid}

	# check login parameters
	if {![ob_util::is_safe $username] || ![ob_util::is_safe $pwd] ||\
	        $uid == ""} {
		return OB_ERR_ADMIN_LOGIN_FAILED
	}

	# reset package cache (in-case not performed within scope of request)
	# and denote critical login
	_auto_reset
	set LOGIN(critical) 1

	if {[OT_CfgGetTrue CONVERT_ADMIN_HASHES]} {
		ob_crypt::convert_admin_password_hash $username $pwd
	}

	set salt_resp [ob_crypt::get_admin_salt $username]
	set salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set salt ""
	}

	# store login details
	set LOGIN(username) $username
	set LOGIN(pwd)      [ob_crypt::encrypt_admin_password $pwd $salt]
	set LOGIN(uid)      $uid

	if {$CFG(store_auth_key_id)} {
		# tag the login session with a unique id
		set LOGIN(auth_key_id) [OT_UniqueId]
	}

	# login
	set LOGIN(login_status) [_db_login $ip_addr N]

	# encrypt the cookie (only stored in the package)
	# - clear the data on error
	if {$LOGIN(login_status) == "OB_OK"} {
		set LOGIN(cookie) [encrypt_cookie $is_secure]
	} else {
		_clear
	}

	return $LOGIN(login_status)
}



# Private procedure to perform login via pAdminLogin stored procedure.
#
#   ip_addr        - IP address (if not defined, then uses cfg ADMIN_LOGIN_LOC)
#   just_chk_login - flag to denote if we are just checking login details
#   returns        - login status string (OB_OK denotes success)
#
proc ob_admin_login::_db_login { {ip_addr ""} {just_chk_login Y} } {

	variable CFG
	variable LOGIN

	# only get the IP address if we want to really annoy our customers...
	if {[OT_CfgGet AWKWARD_LOGIN "Y"] == "Y"} {
		# get the IP address
		if {$ip_addr == ""} {
			if {$CFG(loc) == "" && [info commands reqGetEnv] != ""} {
				set ip_addr [reqGetEnv REMOTE_ADDR]
			} else {
				set ip_addr $CFG(loc)
			}
			ob_log::write DEBUG {ADMIN_LOGIN: ip_addr=$ip_addr}
		}
	} else {
		set ip_addr "unknown"
	}

	# login
	if {[catch {set rs [ob_db::exec_qry ob_admin_login::login\
	                    $LOGIN(username)\
	                    $LOGIN(pwd)\
	                    $LOGIN(uid)\
	                    $ip_addr\
	                    $just_chk_login]} msg]} {
		ob_log::write ERROR {ADMIN_LOGIN: $msg}
		return [_get_err_code $msg]
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_db::rs_close $rs
		ob_log::write ERROR {ADMIN_LOGIN: pAdmin login returned $nrows rows}
		return OB_ERR_ADMIN_LOGIN_FAILED
	}

	# set user_id
	set LOGIN(user_id) [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	ob_log::write INFO {ADMIN_LOGIN: db-login user_id=$LOGIN(user_id)}
	return OB_OK
}



#--------------------------------------------------------------------------
# Logout
#--------------------------------------------------------------------------

# Logout.
# Creates a cookie string which contains 'logged-out'.
# The package cache is reset to denote the customer has logged out.
#
# NB: The procedures does not set the login-cookie. It is caller's
# responsibility to store the cookie within a HTTP header or form argument.
#
#   returns - cookie containing logged out string
#
proc ob_admin_login::logout args {

	variable LOGIN

	# get the usernmae
	set username ""
	if {[info exists LOGIN(username)] && $LOGIN(username) != ""} {
		set username $LOGIN(username)
	}

	# denote logged out
	_clear
	set LOGIN(username) ""

	# denote logged out within db
	if {$username != ""} {
		if {[catch {ob_db::exec_qry ob_admin_login::logout $username} msg]} {
			ob_log::write WARNING {ADMIN_LOGIN: $msg}
		}
	}

	return "logged_out"
}



#--------------------------------------------------------------------------
# Login Cookie
#--------------------------------------------------------------------------

# Check the login cookie.
# The procedure should be always be called via req_init to verify a login
# cookie. The procedure does not verify the cookie against the database
# (call ::is_guest or ::get within the scope of the request to perform full
# login), but simply checks the format and has the cookie expired.
#
# NB: The procedure does not get the cookie from a HTTP header or form
# argument. It is caller's responsibility to supply the cookie string.
#
#   cookie  - login cookie string
#   returns - login status string (OB_OK denotes success)
#
proc ob_admin_login::check_cookie { cookie {is_secure N} } {

	variable CFG
	variable LOGIN

	# already attempted to login within this request
	if {![_can_login]} {
		ob_log::write DEBUG \
		    {ADMIN_LOGIN: repeated login (status=$LOGIN(login_status))}
		return $LOGIN(login_status)
	}

	# clear data
	_clear
	set LOGIN(critical) 0

	# decrypt cookie (details stored within package cache)
	set LOGIN(login_status) [_decrypt_cookie $cookie $is_secure]
	if {$LOGIN(login_status) != "OB_OK"} {
		_clear
		return $LOGIN(login_status)
	}

	# encrypt a new cookie (details store in package cache
	set LOGIN(cookie) [encrypt_cookie $is_secure]

	return $LOGIN(login_status)
}



# Private procedure to decrypt the login cookie.
#
# NB: The procedure does not get the cookie from a HTTP header or form
# argument. It is caller's responsibility to supply the cookie string.
#
#   cookie  - encrypted cookie string
#   returns - login status string (OB_OK denotes success)
#
proc ob_admin_login::_decrypt_cookie { cookie {is_secure N} } {

	variable CFG
	variable LOGIN

	# initially denote the customer as logged out
	set LOGIN(cust_id) ""
	set LOGIN(cookie)  $cookie

	# logged out?
	if {$cookie == "logged_out"} {
		return OB_ERR_ADMIN_GUEST
	}

	# work out which key to use
	set key $CFG(key)
	if {$is_secure} {
		set key $CFG(key_secure)
	}

	# decrypt
	if {[catch {
		set dec [blowfish decrypt -bin $key -hex $cookie]
		set dec [hextobin $dec]
	} msg]} {
		ob_log::write ERROR {ADMIN_LOGIN: $msg}
		return OB_ERR_ADMIN_BAD_COOKIE
	}

	# How many fields in the cookie?
	set num_cookie_fields 4
	if {$CFG(store_user_id)} {
		incr num_cookie_fields
	}
	if {$CFG(store_auth_key_id)} {
		incr num_cookie_fields
	}

	# split
	set vals [split $dec |]
	if {[llength $vals] != $num_cookie_fields} {
		ob_log::write ERROR {ADMIN_LOGIN: invalid cookie format ($dec)}
		return OB_ERR_ADMIN_BAD_COOKIE
	}

	# get details from the decrypted cookie
	foreach {crud password_hash username expiry auth_key_id user_id} $vals {}

	if {$CFG(store_user_id) && $user_id == ""} {
		ob_log::write ERROR {ADMIN_LOGIN: invalid cookie format. Missing user_id}
		return OB_ERR_ADMIN_BAD_COOKIE
	}

	if {$CFG(store_auth_key_id) && $auth_key_id == ""} {
		ob_log::write ERROR {ADMIN_LOGIN: invalid cookie format. Missing auth_key_id}
		return OB_ERR_ADMIN_BAD_COOKIE
	}

	# check expiry
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $expiry\
	        all y m d hh mm]} {
		ob_log::write ERROR {ADMIN_LOGIN: failed to parse expiry ($expiry)}
		return OB_ERR_ADMIN_BAD_COOKIE
	}

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	if {[string compare $now $expiry] >= 0} {
		ob_log::write ERROR {ADMIN_LOGIN: expired cookie (now=$now expiry=$expiry)}
		return OB_ERR_ADMIN_EXPIRED_COOKIE
	}

	# store the cookie details within the cache
	set LOGIN(username)    $username
	set LOGIN(pwd)         $password_hash

	if {$CFG(store_auth_key_id)} {
		set LOGIN(auth_key_id) $auth_key_id
	}

	if {$CFG(store_user_id)} {
		set LOGIN(user_id) $user_id
	}

	return OB_OK
}



# Private procedure to encrypt a login cookie.
#
# The cookie details are taken from the package cache. The cookie expiry
# time is either taken from cfg CUST_LOGIN_KEEPALIVE or
# tControl.login_keepalive. If not set, or equals zero, then no expiry time
# is appended to cookie string. The new encrypted cookie will be stored
# in LOGIN(cookie).
#
# NB: The procedure does not set/add the cookie to HTTP header or set form
# variable[s]. It is caller's responsibility to set the cookie.
#
proc ob_admin_login::encrypt_cookie {{is_secure N}} {

	variable CFG
	variable LOGIN

	# work out which key/keepalive to use
	set key       $CFG(key)
	set keepalive $CFG(keepalive)
	if {$is_secure} {
		set key       $CFG(key_secure)
		set keepalive $CFG(keepalive_secure)
	}

	# set crud!?!
	set now    [clock seconds]
	set crud   [string range [md5 [expr {srand($now)}]] 8 15]

	# set expiry time
	set expiry [expr {$now + $keepalive}]
	set expiry [clock format $expiry -format {%Y-%m-%d %H:%M:%S}]

	# build the cookie
	set cookie $crud|$LOGIN(pwd)|$LOGIN(username)|$expiry

	if {$CFG(store_auth_key_id)} {
		append cookie "|$LOGIN(auth_key_id)"
	}

	if {$CFG(store_user_id)} {
		append cookie |$LOGIN(user_id)
	}

	return [blowfish encrypt -bin $key -bin $cookie]
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Get the login UID.
#
#   returns - [list status UID]
#
proc ob_admin_login::get_uid args {

	set uid    ""
	set status OB_OK

	set rs [ob_db::exec_qry ob_admin_login::get_uid]
	if {[db_get_nrows $rs] != 1} {
		set status OB_ERR_ADMIN_NO_UID
	} else {
		set uid [db_get_coln $rs 0 0]
	}
	ob_db::rs_close $rs

	return [list $status $uid]
}



# Private procedure to get the symbolic error code from a stored procedure
# exception message.
#
#   msg     - exception message
#   dflt    - default error code if an unknown code within message
#             (default: OB_ERR_ADMIN_LOGIN_FAILED)
#   returns - symbolic error code
#
proc ob_admin_login::_get_err_code { msg {dflt OB_ERR_ADMIN_LOGIN_FAILED} } {

	variable LOGIN
	variable ERR_CODE

	if {[regexp {AX([0-9][0-9][0-9][0-9])} $msg all err_code]} {
		if {[info exists ERR_CODE($err_code)]} {
			return $ERR_CODE($err_code)
		}
	}

	return $dflt
}



# Private procedure to determine if an admin user can login within the scope
# of the current request.
#
#   returns  - non-zero if customer can login, zero if not
#
proc ob_admin_login::_can_login args {

	variable LOGIN

	if {[eval {set status_exists [info exists LOGIN(login_status)]}]} {
		set status $LOGIN(login_status)
	}

	if {[_auto_reset] \
	        || !$status_exists \
	        || ($status == "OB_OK" && ![info exists LOGIN(critical)])} {
		return 1
	}

	return 0
}
