# ==============================================================
# $Id: login.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::LOGIN {

	asSetAct ADMIN::LOGIN::GoLogin         [namespace code go_login]
	asSetAct ADMIN::LOGIN::DoLogin         [namespace code do_login]
	asSetAct ADMIN::LOGIN::GoLogout        [namespace code go_logout]
	asSetAct ADMIN::LOGIN::GoPwdExprLogin  [namespace code go_pwd_expr_login]
	asSetAct ADMIN::LOGIN::GoChangeLang    [namespace code go_change_lang]
	asSetAct ADMIN::LOGIN::DoChangeLang    [namespace code do_change_lang]


	variable LOGIN_KEY            [OT_CfgGet LOGIN_KEY]
	variable LOGIN_REFRESH        [OT_CfgGet LOGIN_REFRESH AUTO]
	variable LOGIN_KEEPALIVE      [OT_CfgGet LOGIN_KEEPALIVE 14400]
	variable LOGIN_COOKIE_NAME    [OT_CfgGet LOGIN_COOKIE_NAME]
	variable LOGIN_COOKIE_PATH    [OT_CfgGet LOGIN_COOKIE_PATH /]
	variable LOGIN_COOKIE_DOMAIN  [OT_CfgGet LOGIN_COOKIE_DOMAIN ""]
	variable LOGIN_APP_TAG        [OT_CfgGet LOGIN_APP_TAG "ADMIN"]

	variable PREP_LOGIN_UID_SQL   ""
	variable PREP_LOGIN_SQL       ""
	variable PREP_LOGOUT_SQL      ""
	variable PREP_PERMS_SQL       ""

	variable LOGIN_LOCATION_PROC  [OT_CfgGet LOGIN_LOCATION_PROC ""]

	variable LOGIN_PERMS_CACHE    [OT_CfgGet LOGIN_PERMS_CACHE 0]

	variable ERROR_CODES          {
		AX2100 "Account Suspended"
		AX2101 "Username and password combination not recognised"
		AX2102 "Session Expired"
		AX2103 "Login location mismatch"
		AX2104 "Account suspended due to lack of use"
		AX2105 "Password has expired"
	}
}



# Default procedure for determining login location
#
proc ADMIN::LOGIN::get_login_location args {

	variable LOGIN_LOCATION_PROC

	if {$LOGIN_LOCATION_PROC == ""} {
		return [reqGetEnv REMOTE_ADDR]
	}

	return [$LOGIN_LOCATION_PROC]
}



# Login location check is not necessary
#
proc ADMIN::LOGIN::no_login_location args {

	return {}
}



# Prepare login queries
#
proc ADMIN::LOGIN::prep_login_sql args {

	global DB

	variable PREP_LOGIN_UID_SQL
	variable PREP_LOGIN_SQL
	variable PREP_LOGOUT_SQL
	variable PREP_PERMS_SQL

	if {$PREP_LOGIN_UID_SQL == ""} {
		set PREP_LOGIN_UID_SQL [inf_prep_sql $DB {
			execute procedure pGenAdminLoginUID()
		}]
	}

	set app_tag [OT_CfgGet LOGIN_APP_TAG ""]
	if {$app_tag != ""} {
		set app_tag ", p_app_tag='$app_tag'"
	}

	if {$PREP_LOGIN_SQL == ""} {
		set expiry ""
		if {[OT_CfgGet FUNC_PWD_EXPIRY 0]} {
			set expiry ", p_pwd_expires = 'Y'"
		}

		set PREP_LOGIN_SQL [inf_prep_sql $DB [subst {
			execute procedure pAdminLogin(
				p_username = ?,
				p_password = ?,
				p_login_uid = ?,
				p_login_loc = ?,
				p_just_chk_login = ?
				$app_tag
				$expiry
			)
		}]]
	}

	if {$PREP_LOGOUT_SQL == ""} {
		set PREP_LOGOUT_SQL [inf_prep_sql $DB [subst {
			execute procedure pAdminLogout(
				p_username = ?
				$app_tag
			)
		}]]
	}

	if {$PREP_PERMS_SQL == ""} {
		set PREP_PERMS_SQL [inf_prep_sql $DB {
			select action
			from   tAdminUserOp
			where  user_id = ?

			union

			select gop.action
			from   tAdminUserGroup ug,
				   tAdminGroupOp gop
			where  ug.user_id = ? and
				   ug.group_id = gop.group_id

			union

			select gop.action
			from   tAdminPosnGroup pg,
				   tAdminGroupOp gop,
				   tAdminUser u
			where  u.user_id = ? and
				   u.position_id = pg.position_id and
				   pg.group_id = gop.group_id
		}]
	}
}



# Re-initialise sql stuff (after something's broken)
#
proc ADMIN::LOGIN::sql_reset args {

	global DB

	variable PREP_LOGIN_UID_SQL
	variable PREP_LOGIN_SQL
	variable PREP_LOGOUT_SQL
	variable PREP_PERMS_SQL

	set c [catch {

		catch {inf_close_stmt $PREP_LOGIN_SQL}
		catch {inf_close_stmt $PREP_LOGOUT_SQL}
		catch {inf_close_stmt $PREP_PERMS_SQL}
		catch {inf_close_stmt $PREP_LOGIN_UID_SQL}

		set PREP_LOGIN_UID_SQL ""
		set PREP_LOGIN_SQL     ""
		set PREP_LOGOUT_SQL    ""
		set PREP_PERMS_SQL     ""

		catch {inf_close_conn $DB}

		main_db_conn

		prep_login_sql
	}]
}



# Get next login uid
#
proc ADMIN::LOGIN::gen_login_uid args {

	global DB

	variable PREP_LOGIN_UID_SQL

	set uid -1

	set c [catch {
		prep_login_sql
		set res [inf_exec_stmt $PREP_LOGIN_UID_SQL]
	} msg]

	if {$c} {
		# This is your last chance...
		set last_err [inf_last_err_num]

		OT_LogWrite 1 "caught PREP_LOGIN_UID_SQL error ($last_err)"
		global errorInfo
		OT_LogWrite 1 "$errorInfo"

		if {$last_err == -1803 || $last_err == -25582 || $last_err == -25580} {

			OT_LogWrite 1 "error code $last_err => retry"

			set c [catch {

				sql_reset

				set res [inf_exec_stmt $PREP_LOGIN_UID_SQL]

			} msg]
		}

		# Even though we might've just pulled a rabbit out of a hat, restart
		# the app server to avoid any lingering badness...
		asRestart
	}

	if {$c} {
		err_bind $msg
		catch {
			db_close $res
		}
		return 0
	}

	if {[db_get_nrows $res] != 1} {
		OT_LogWrite 1 "pGenAdminLoginUID returned [db_get_nrows $res] rows"
		err_bind "failed to generate uid"
	} else {
		set uid [db_get_coln $res 0 0]
	}
	catch {db_close $res}

	return $uid
}



# Check login query - try to rerieve user_id for given username, password
#
proc ADMIN::LOGIN::do_login_query {
	username
	password
	{login_uid ""}
	{login_loc ""}
	{p_just_chk_login "N"}
} {

	global DB

	variable PREP_LOGIN_SQL
	variable PREP_PERMS_SQL
	variable LOGIN_PERMS_CACHE
	variable LOGIN_APP_TAG

	# Call the login procedure - a successful call will return exactly one row
	#
	# We deliberately circumvent the informix wrappers here: if we get an error
	# which looks like a broken connection we re-prepare the two offending
	# queries and try it again - this should make the failover from a broken
	# database to a good one a bit smoother
	set c [catch {
		prep_login_sql

		set res [inf_exec_stmt\
			$PREP_LOGIN_SQL\
			$username\
			$password\
			$login_uid\
			$login_loc\
			$p_just_chk_login]
	} msg]

	if {$c} {
		# This is your last chance...
		set last_err [inf_last_err_num]

		OT_LogWrite 1 "caught error error ($last_err)"
		global errorInfo
		OT_LogWrite 1 "$errorInfo"

		if {$last_err == -1803 || $last_err == -25582 || $last_err == -25580} {

			OT_LogWrite 1 "error code $last_err => retry"

			set c [catch {

				sql_reset

				set res [inf_exec_stmt\
					$PREP_LOGIN_SQL\
					$username\
					$password\
					$login_uid\
					$login_loc\
					$p_just_chk_login]

			} msg]
		}

		# Even though we might've just pulled a rabbit out of a hat, restart
		# the app server to avoid any lingering badness...
		asRestart
	}

	if {$c} {
		catch {db_close $res}
		error $msg
	}

	if {[db_get_nrows $res] != 1} {
		db_close $res
		error "Failed to close $res"
	}

	set user_id [db_get_coln $res 0 0]

	db_close $res

	# Get a list of all the permissions assigned to the user, and create a
	# corresponding template variable for each one
	if {$LOGIN_PERMS_CACHE > 0} {
		if {[catch {
			set res [asFindRs USER-PERMS($user_id)]
		}]} {
			set res [inf_exec_stmt $PREP_PERMS_SQL\
				$user_id \
				$user_id \
				$user_id]
			catch {
				asStoreRs $res USER-PERMS($user_id) $LOGIN_PERMS_CACHE
			}
		}
	} else {
		set res [inf_exec_stmt $PREP_PERMS_SQL $user_id $user_id $user_id]
	}

	set np [db_get_nrows $res]

	for {set p 0} {$p < $np} {incr p} {
		set perm [db_get_col $res $p action]
		tpSetVar PERM_$perm 1
	}

	db_close $res

	return $user_id
}



# Check login - if no valid cookie return 0, else 1
#
proc ADMIN::LOGIN::check_login args {

	global DB USERNAME USERID

	variable LOGIN_REFRESH
	variable LOGIN_COOKIE_NAME
	variable LOGIN_KEY

	if {[set cookie [get_cookie $LOGIN_COOKIE_NAME]] == ""} {
		return 0
	}

	if {$cookie == "logged_out"} {
		return 0
	}

	set dec [blowfish decrypt -bin $LOGIN_KEY -hex $cookie]

	if [catch {set dec [hextobin $dec]} msg] {
		OT_LogWrite 1 "Bad cookie: $cookie_val ($msg)"
		return 0
	}

	if {[llength [set vals [split $dec |]]] != 4} {
		OT_LogWrite 3 "split cookie doesn't contain 4 elements"
		return 0
	}

	foreach {crud password_hash username expiry} $vals { break }

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $expiry all y m d hh mm]} {
		OT_LogWrite 3 "Bad cookie : failed to parse expiry ($expiry)"
		return 0
	}

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	if {[string compare $now $expiry] >= 0} {
		OT_LogWrite 5 "Cookie expired: now=$now cookie=$expiry"
		return 0
	}

	set loc [get_login_location]

	if {[catch {
		set user_id [do_login_query $username $password_hash "" $loc "Y"]
	} msg]} {
		ob::log::write ERROR {Error with login: $msg}
		return 0
	}

	OT_LogWrite 4 "CheckLogin: user=($username) id=$user_id"

	set USERNAME $username
	set USERID   $user_id

	if {$LOGIN_REFRESH == "AUTO"} {
		tpBufAddHdr Set-Cookie [login_cookie $username $password_hash]
	}

	return 1
}



# Play login page
#
proc ADMIN::LOGIN::go_login args {

	# store request if diverted to login during another action
	global NEXTREQ
	array set NEXTREQ [list]
	set c 0
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[regexp {^_} [reqGetNthName $i]]} {
			set NEXTREQ($c,name) [reqGetNthName $i]
			set NEXTREQ($c,value) [reqGetNthVal $i]
			incr c
		}
	}
	tpBindVar argname NEXTREQ name idx
	tpBindVar argvalue NEXTREQ value idx
	tpSetVar numargs $c

	tpBindString LoginUID [gen_login_uid]
	asPlayFile -nocache login.html
}



# Play login page for an expired password
#
proc ADMIN::LOGIN::go_pwd_expr_login args {
	tpBindString LoginUID [gen_login_uid]
	asPlayFile -nocache login_expired_pwd.html
}



# Logout
#
proc ADMIN::LOGIN::go_logout args {

	global DB USERNAME USERID

	variable LOGIN_COOKIE_NAME
	variable LOGIN_COOKIE_DOMAIN
	variable LOGIN_COOKIE_PATH
	variable LOGIN_APP_TAG
	variable PREP_LOGOUT_SQL

	set cv $LOGIN_COOKIE_NAME=logged_out

	if {$LOGIN_COOKIE_DOMAIN != ""} {
		append cv "; domain=$LOGIN_COOKIE_DOMAIN"
	}

	if {$LOGIN_COOKIE_PATH != ""} {
		append cv "; path=$LOGIN_COOKIE_PATH"
	}

	tpBufAddHdr Set-Cookie $cv

	set c [catch {
		prep_login_sql

		set res [inf_exec_stmt\
			$PREP_LOGOUT_SQL\
			$USERNAME]
	} msg]

	if {$c} {
		# This is your last chance...
		set last_err [inf_last_err_num]

		OT_LogWrite 1 "caught PREP_LOGOUT_UID_SQL error ($last_err)"

		if {$last_err == -1803 || $last_err == -25582 || $last_err == -25580} {

			OT_LogWrite 1 "error code $last_err => retry"

			set c [catch {

				sql_reset

				set res [inf_exec_stmt\
					$PREP_LOGOUT_SQL\
					$USERNAME]

			} msg]
		}

		# Even though we might've just pulled a rabbit out of a hat, restart the
		# app server to avoid any lingering badness...
		asRestart
	}

	if {$c} {
		err_bind $msg
		catch {db_close $res}
		return 0
	}

	ADMIN::LOGIN::go_login
}



# Process login form
#
proc ADMIN::LOGIN::do_login {{play 1}} {

	global DB USERNAME USERID

	variable LOGIN_KEY
	variable LOGIN_KEEPALIVE

	set username [reqGetArg username]
	set password [reqGetArg password]
	set loginuid [reqGetArg loginuid]

	if {[string trim $loginuid] == ""} {
		error "no login uid in login page"
	}

	if {[OT_CfgGetTrue CONVERT_ADMIN_HASHES]} {
		# Changes the hash in tAdminUsers to be a SHA-1 hash. Shouldn't
		# require handling of returns, as the password is checked later.
		convert_admin_password_hash $username $password
	}

	set salt_resp [get_admin_salt $username]
	set salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set salt ""
	}

	set password_hash [encrypt_admin_password $password $salt]

	set loc          [get_login_location]

	if {[catch {
		set user_id [do_login_query $username $password_hash $loginuid $loc]
	} msg]} {
		foreach {val code err_msg} [get_error_message $msg] {
			break
		}
		if {$val} {
			ob::log::write ERROR {Error with login: $msg}
		}
		tpSetVar Error 1
		tpBindString ErrorMessage $err_msg
		if {$code == "AX2105"} {
			tpSetVar is_login 1
			tpSetVar show_pw_policy 1

			set min_length_sql {
				select
					admn_pwd_min_len
				from
					tControl
			}
			set stmt  [inf_prep_sql $DB $min_length_sql]
			set res   [inf_exec_stmt $stmt]
			set nrows [db_get_nrows $res]
			if {$nrows < 1} {
				tpBindString pwdMinLength 6
			}
			tpBindString pwdMinLength [db_get_col $res 0 admn_pwd_min_len]

			db_close $res


			tpSetVar username $username
			ADMIN::USERS::go_password
		} else {
			go_login
		}
		return 0
	}
	ob::log::write INFO {Login OK: user_id $user_id}

	tpBufAddHdr Set-Cookie [login_cookie $username $password_hash]

	# restore pre-login request (if any)
	#if {[reqGetArg _action] == "ADMIN::MONITOR::GoReportAdmin"}
	# look for the action in a configurable list of actions we can redirect
	if {[lsearch [OT_CfgGet LOGIN_REDIRECT_ACTIONS [list]] [reqGetArg _action]] != -1} {
		global NEXTREQ
		array set NEXTREQ [list]
		set c 0
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			if {[regexp {^_} [reqGetNthName $i]]} {
				set NEXTREQ($c,name)  [string range [reqGetNthName $i] 1 end]
				set NEXTREQ($c,value) [reqGetNthVal $i]
				incr c
			}
		}
		tpBindVar argname  NEXTREQ name  idx
		tpBindVar argvalue NEXTREQ value idx
		tpSetVar numargs $c

		OT_LogWrite 4 "Redirecting to [reqGetArg _action]"
		asPlayFile -nocache redirect.html
	} else {
		# are we going to play the index?
		if {$play} {
			asPlayFile -nocache index.html
		}
	}
}



# Make a login cookie
#
proc ADMIN::LOGIN::login_cookie {username password_hash} {

	variable LOGIN_KEEPALIVE
	variable LOGIN_KEY
	variable LOGIN_COOKIE_PATH
	variable LOGIN_COOKIE_NAME
	variable LOGIN_COOKIE_DOMAIN

	set t_now [clock seconds]
	set t_exp [expr {$t_now+$LOGIN_KEEPALIVE}]

	set expiry [clock format $t_exp -format "%Y-%m-%d %H:%M:%S"]

	set crud [string range [md5 [expr {srand($t_now)}]] 8 15]

	set cookie_plain "$crud|$password_hash|$username|$expiry"

	set cookie_enc [blowfish encrypt -bin $LOGIN_KEY -bin $cookie_plain]

	set cv "$LOGIN_COOKIE_NAME=$cookie_enc"

	if {$LOGIN_COOKIE_DOMAIN != ""} {
		append cv "; domain=$LOGIN_COOKIE_DOMAIN"
	}
	if {$LOGIN_COOKIE_PATH != ""} {
		append cv "; path=$LOGIN_COOKIE_PATH"
	}

	return $cv
}



# Takes an error code and returns the appropriate error message
#
proc ADMIN::LOGIN::get_error_message {err_msg} {
	variable ERROR_CODES

	if {[regexp {(AX[0-9]+):.*$} $err_msg all code]} {
		foreach {err_code msg} $ERROR_CODES {
			if {$err_code == $code} {
				return [list 0 $code $msg]
			}
		}
	}
	return [list 1 "" "Unknown error: $err_msg"]
}

#
# ----------------------------------------------------------------------------
# Get the current language setting
# ----------------------------------------------------------------------------
#
proc _get_lang {} {

	set cookie_name [OT_CfgGet ADMIN_LANG_COOKIE "ADMINLANG"]

	# if no lang, then we're just gonna set it to the default
	set lang [get_cookie $cookie_name]

	if {$lang == ""} {
		# cookie didn't exist/ was blank
		# set it
		set lang [ob_control::get default_lang]
	}

	return $lang

}
#
# ----------------------------------------------------------------------------
# Fiddle with language cookies
# ----------------------------------------------------------------------------
#
proc ADMIN::LOGIN::set_lang {{lang ""}} {

	# hierarchy of places to get the language from (in order of pref)
	# 1: direct as an argument (direct pass) handled in do_change_lang
	# 2: as an argument (reqGetArg) (indirect pass)
	# 3: from the current cookie (passive pass)
	# 4: from tControl.default_lang (default)

	set cookie_name [OT_CfgGet ADMIN_LANG_COOKIE "ADMINLANG"]

	if {$lang == ""} {
		# if no lang, then we're just gonna set it to the default
		set lang [_get_lang]
	}

	set_cookie "$cookie_name=$lang"

}



#
# ----------------------------------------------------------------------------
# Display language choice for multi-lingual admin screens
# ----------------------------------------------------------------------------
#
proc ADMIN::LOGIN::go_change_lang {{changed 0}} {

	global DB

	global DISP_LANGS

	# safety first!
	catch {unset DISP_LANGS}

	# if we're being told that the language was changed prior to this request
	# don't bother with all the binding etc, just display the quick landing page
	if {$changed} {
		tpSetVar LangChanged 1
	} else {
		# first get the current language
		set current_lang [_get_lang]

		# now prep the sql to get all languages
		if {[catch {
			set lang_stmt [inf_prep_sql $DB {
				select
					lang,
					name
				from
					tLang
				where
					displayed = 'Y'
				order by
					disporder
			}]

			set res [inf_exec_stmt $lang_stmt]
		} msg]} {

			# error
			ob_log::write ERROR {Failed to get languages: $msg}
			return
		}

		if {![db_get_nrows $res]} {
			# got no languages
			set msg {Failed to get languages: no languages found!}
			ob_log::write WARNING $msg
			err_bind $msg
			catch {db_close $res}
			return 0
		}

		# got here -> languages found
		# build an array from these

		for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
			set code [db_get_col $res $r lang]
			set name [db_get_col $res $r name]
			# grab the col values
			set DISP_LANGS($r,lang) $code
			set DISP_LANGS($r,name) $name

			set DISP_LANGS($code)   $name

			# Make a note of which one is the currently selected language
			# so that we can make this entry NOT a link on the page
			set DISP_LANGS($r,current) [expr {$code eq $current_lang}]

		}

		set DISP_LANGS(num_langs) [db_get_nrows $res]

		catch {db_close $res}

		tpBindVar lang_code DISP_LANGS lang    lang_idx
		tpBindVar lang_name DISP_LANGS name    lang_idx
		tpBindVar current   DISP_LANGS current lang_idx
	}

	# play the template

	asPlayFile -nocache change_lang.html

}

#
# ----------------------------------------------------------------------------
# Change language cookie value from a request
# ----------------------------------------------------------------------------
#
proc ADMIN::LOGIN::do_change_lang {} {

	set_lang [reqGetArg lang]

	go_change_lang 1

}


