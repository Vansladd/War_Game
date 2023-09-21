# $Id: login.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# Login
#
# Synopsis:
#    package require office ?1.0?
#
# Configuration:
#    ADMIN_LOGIN_COOKIE_NAME             login cookie name (OFFICELOGIN)
#    ADMIN_LOGIN_COOKIE_PATH             login cookie path (/)
#    OFFICE_LOGIN_ACTION                 default action on successful login
#    VALIDATE_UNAME                      do we want the Javascript to validate
#                                        usernames other than the lenght.
#                                        Some customers don't want it to do this.
#
#  FUNC_REMOTE_LOGIN                     log in taking username from env var (default 0)
#  FUNC_REMOTE_LOGIN_NO_DOMAIN           strip off domain part from remote user name (default 0)
#  FUNC_REMOTE_LOGIN_CASE_INSENSITIVE    ignore case for remote user name (default 0)
#  REMOTE_USER                           env variable (existing Openbet Admin username)
#
# Procedures:
#    ob_office::login::req_init          request init
#    ob_office::login::H_login           display login page
#    ob_office::login::H_do_login        login
#    ob_office::login::H_logout          logout
#

# Variables
#
namespace eval ob_office::login {

	variable CFG
	variable LOGGED_IN 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one-time initialisation
#
proc ob_office::login::_init { {dependencies 0} } {

	variable CFG

	# already initialised?
	if {[info exists CFG]} {
		return
	}

	ob_log::write DEBUG {OFFICE: login init}

	# dependencies
	package require admin_login
	package require util_util

	ob_admin_login::init
	ob_util::init

	# config
	array set OPT [list\
	               cookie_name  OFFICELOGIN\
	               cookie_path  "/"]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet ADMIN_LOGIN_[string toupper $c] $OPT($c)]
	}

	# LDAP support
	foreach {c d} {
		remote_login 0
		use_secure_login_cookie 0
	} {
		set CFG($c) [OT_CfgGet FUNC_[string toupper $c] $d]
	}

	set CFG(action) [OT_CfgGet OFFICE_LOGIN_ACTION]
	set CFG(validate_uname) [OT_CfgGet VALIDATE_UNAME 1]

	ob_log::write_array DEV ob_office::login::CFG

	# action handlers
	asSetAct ob_office::GoLogin     ob_office::login::H_login
	asSetAct ob_office::DoLogin     ob_office::login::H_do_login
	asSetAct ob_office::GoLogout    ob_office::login::H_logout
}



# Initialise the login details on request initialisation
# Checks the login cookie and if found attempts a 'non-critical login'.
# If no cookie, or failed login, sets the login UID
#
#   action  - request action
#   returns - 1 if logged in (or performing a Office call), zero on failure
#
proc ob_office::login::req_init { action } {

	variable CFG

	# ignore Office calls
	if {[regexp {^(ob_office::.+)$} $action]} {
		return 1
	}

	set status ""

	# get the login cookie
	set cookie [ob_util::get_cookie $CFG(cookie_name)]

	if {$cookie != ""} {

		# perform non-critical login
		set status [ob_admin_login::check_cookie $cookie]
		ob_log::write DEBUG {OFFICE: login check login status=$status}

		# get + re-set the cookie
		if {$status == "OB_OK"} {
			foreach {status cookie} [ob_admin_login::get cookie] {}
			if {$status == "OB_OK"} {
				_set_cookie $cookie
			}
			foreach {s username} [ob_admin_login::get username] {}
			if {$s == "OB_OK"} {
				tpBindString login_username $username
			} else {
				ob_log::write WARNING {OFFICE: login $s}
			}
		}

		if {$status != "OB_OK"} {
			ob_log::write ERROR {OFFICE: login $status}
		}
	} else {
		ob_log::write ERROR {OFFICE: login cookie not found}
	}

	ob_log::write DEBUG {OFFICE: login check login status=$status}

	if {$status != "OB_OK" && $CFG(remote_login)} {
		ob_log::write DEBUG {OFFICE: Not logged in via cookie status=$status}
		ob_log::write DEBUG {OFFICE: Attempting remote login}

		set status [ob_office::login::_do_remote_login]
	}

	# if not logged in, set the login uid
	if {$status != "OB_OK"} {
		_bind_uid
		return 0
	}

	return 1
}



#--------------------------------------------------------------------------
# Action handlers
#--------------------------------------------------------------------------

# Action handler to display the login page
#
proc ob_office::login::H_login args {

	variable CFG

	ob_log::write DEBUG {OFFICE: H_login}

	tpSetVar OFFICE_BACKGROUND 1

	# Do we want to validate usernames
	# other than checking length
	if {$CFG(validate_uname) == 1} {
		tpBindString VAL_UNAME true
	} else {
		tpBindString VAL_UNAME false
	}

	ob_office::util::play $ob_office::CFG(office_lib_html)/login.html
}



# Action handle to perform user login
#
proc ob_office::login::H_do_login args {

	variable CFG

	ob_log::write DEBUG {OFFICE: H_do_login}

	foreach c [list username password uid] {
		set $c [reqGetArg $c]
	}

	# login
	set status [ob_admin_login::form_login $username $password $uid]

	# get + set the cookie
	if {$status == "OB_OK"} {
		foreach {status cookie} [ob_admin_login::get cookie] {}
		if {$status == "OB_OK"} {
			_set_cookie $cookie
		}
	}

	# re-bind on error
	if {$status != "OB_OK"} {
		ob_office::err::xl_add $status ERROR [reqGetArg action]
		tpBindString username $username

		# reset the uid
		if {$status == "OB_ERR_ADMIN_LOGIN_SEQ"} {
			reqSetArg uid ""
		}
		_bind_uid

		return [H_login]
	}

	# default action on successful login
	eval {$CFG(action)}
}



# Action handler to logout
#
#   play_form - play the login form after logout (1)
#
proc ob_office::login::H_logout { {play_form 1} } {

	variable CFG

	ob_log::write DEBUG {OFFICE: H_logout: play_form=$play_form}

	# ensure that the login package is correctly initialised
	set status \
		[ob_admin_login::check_cookie [ob_util::get_cookie $CFG(cookie_name)]]

	ob_log::write DEBUG {OFFICE: H_logout status:$status}

	# regardless of response to check_cookie, still call logout to tidy
	# everything up
	set cookie [ob_admin_login::logout]
	_set_cookie $cookie 0

	if {$play_form} {
		_bind_uid
		H_login
	}
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Private procedure to the set the login cookie.
#
#   cookie    - login cookie string
#   logged_in - flag to denote if successfully logged in (default: 1)
#
proc ob_office::login::_set_cookie { cookie {logged_in 1} } {

	variable CFG
	variable LOGGED_IN

	if {$CFG(use_secure_login_cookie)} {
		ob_util::set_cookie "$CFG(cookie_name)=$cookie" $CFG(cookie_path) 1 "" "" 1
	} else {
		ob_util::set_cookie "$CFG(cookie_name)=$cookie" $CFG(cookie_path)
	}

	set LOGGED_IN $logged_in
	tpSetVar LOGGED_IN $logged_in

	# set the login prefix
	if {$logged_in} {
		foreach {status user_id} [ob_admin_login::get user_id] {}
	} else {
		set user_id ""
	}
	ob_log::set_prefix [format "%03d:%04d:%s" [asGetId] [reqGetId] $user_id]
}



# Private procedure to get and bind the login uid
#
proc ob_office::login::_bind_uid args {

	set uid [reqGetArg uid]
	if {$uid == ""} {
		foreach {status uid} [ob_admin_login::get_uid] {}
		if {$status != "OB_OK"} {
			set uid ""
			ob_log::write WARNING {login: bind_uid $status}
		}
	}
	tpBindString uid $uid
}



# Private procedure to the perform a remote login.
#
# Login based on the Apache REMOTE_USER env variable been set with
# an existing Openbet Admin username.
# REMOTE_USER is assumed to be pre-populated by some
# network authentication protocol.
#
proc ob_office::login::_do_remote_login args {

	variable CFG

	set remote_user [reqGetEnv REMOTE_USER]
    set remote_user [ob_admin_login::parse_remote_username $remote_user]
	set admin_user_l [ob_admin_login::get_adminuser $remote_user]

	if {[lindex $admin_user_l 0] != 1} {
		ob_office::err::add [lindex $admin_user_l 1] ERROR "ob_office::DoLogin"
		return ""
	}

	# login
	foreach {status loginuid} [ob_admin_login::get_uid] {break}

	if {$status != "OB_OK"} {
		ob_office::err::add $status ERROR "ob_office::DoLogin"
		return ""
	}

	set username [lindex $admin_user_l 1]
	set pwd_hash [lindex $admin_user_l 2]

	set status [ob_admin_login::form_login $username $pwd_hash $loginuid]

	if {$status != "OB_OK"} {
		ob_office::err::add $status ERROR "ob_office::DoLogin"
		return ""
	}

	foreach {status cookie} [ob_admin_login::get cookie] {}

	if {$status == "OB_OK"} {
		_set_cookie $cookie
	} else {
		ob_office::err::add $status ERROR "ob_office::DoLogin"
		return ""
	}

	foreach {s username} [ob_admin_login::get username] {}
	if {$s == "OB_OK"} {
		tpBindString login_username $username
	} else {
		ob_office::err::add $s ERROR "ob_office::DoLogin"
		return ""
	}

	return "OB_OK"
}

