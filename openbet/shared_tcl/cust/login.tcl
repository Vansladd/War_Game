# $Id: login.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle customer/user login & logout.
#
# Configuration:
#    CUST_PRE_AUTH              pre-auth' server              - (1)
#    CUST_LOGIN_KEY_HEX         hexadecimal login key         - (0)
#    CUST_LOGIN_KEY_BIN         binary login key
#    CUST_LOGGED_OUT_STR        logged out cookie string      - (NOT_LOGGED_IN)
#    CUST_LOGIN_KEEPALIVE       login keepalive               - ("")
#    CUST_AMBIGUOUS_LOGIN       ambiguous login               - (0)
#    CUST_3PARTY_LOGIN          3rd party login               - (0)
#    CUST_UID_IS_TIME           login UID is time             - (0)
#    CUST_ENABLE_ELITE          enable elite customer         - (0)
#    CUST_WRITE_LOGIN_HIST      enable login history          - (0)
#    CUST_LOGIN_COOKIE_FMT      cookie string format          - (NEW)
#    CUST_SESSION_TRACKING      session tracking enabled      - (0)
#    CUST_DO_SITE_CHECKING      enable site operator checking - (0)
#    CUST_SITE_CHECK_CHANNEL    channel to be used for site operator
#                               checking                      - (I)
#    CUST_INSECURE_COOKIE_ITEMS additional items to be stored in cookie
#    CUST_MIGRATE_PASSWORDS     migrate existing customer passwords to openbet
#                               hashes - (0)
#    CUST_HASH_PROC             hash proc for migrated passwords - ("")
#                               *must* be set if CUST_MIGRATE_PASSWORDS != 0
#                               proc should take username and password as args
#    CUST_PWD_CASE_INSENSITIVE  case insensitive passwords - (0)
#    CUST_CSRF_PROTECTION       UID in secure cookie against CSRF - (0)
#								NB: Expects a parameter called csrf_uid in
#								the insecure cookie.
#
# Synopsis:
#    package require cust_login ?4.5?
#
# Procedures:
#    ob_login::init          one time initialisation
#    ob_login::get           get customer information
#    ob_login::force_update  force an update of the customer login information
#    ob_login::check_cookie  check login cookie
#    ob_login::check_insecure_cookie   checks insecure login cookie
#    ob_login::is_guest      is guest
#    ob_login::form_login    form login
#    ob_login::auto_login    automatic login (after registration)
#    ob_login::tbs_login     telebet server login
#    ob_login::logout        logout
#    ob_login::get_uid       get login UID
#    ob_login::upd_pwd       update password
#    ob_login::upd_pin       update pin
#    ob_login::upd_lang      update lang
#

package provide cust_login 4.5



# Dependencies
#
package require util_log     4.5
package require util_db      4.5
package require util_crypt   4.5
package require util_control 4.5
package require util_util    4.5



# Variables
#
namespace eval ob_login {

	variable CFG
	variable INIT
	variable LOGIN
	variable ERR_CODE
	variable REG_COLS
	variable POK_COLS
	variable COOKIE_COLS

	# current request number
	set LOGIN(req_no) ""

	# pLogin stored procedure error code translations
	array set ERR_CODE [list\
		2000 OB_ERR_CUST_ACCT_LOCKED\
		2001 OB_ERR_CUST_BAD_UNAME\
		2002 OB_ERR_CUST_BAD_UNAME\
		2003 OB_ERR_CUST_BAD_REG\
		2004 OB_ERR_CUST_PARAMS_INCOMPLETE\
		2005 OB_ERR_CUST_SEQ\
		2006 OB_ERR_CUST_BAD_ACCT\
		2007 OB_ERR_CUST_BAD_PIN\
		2008 OB_ERR_CUST_ACCT_SUS\
		2009 OB_ERR_CUST_ACCT_LOCKED\
		2010 OB_ERR_CUST_ELITE\
		2011 OB_ERR_CUST_ACCT_CLOSED\
		2012 OB_ERR_CUST_IN_SELF_EXCL\
		2013 OB_ERR_CUST_OUT_SELF_EXCL\
		2014 OB_ERR_CUST_BAD_UNAME\
		2015 OB_ERR_ACCT_SUS_NOT_AGE_VRF\
		2202 OB_ERR_CUST_BAD_UNAME\
		2203 OB_ERR_CUST_ACCT_SUS\
		2300 OB_ERR_CUST_PIN_LEN\
		2301 OB_ERR_CUST_NO_PINPWD\
		2500 OB_ERR_CUST_PWD_LEN\
		2501 OB_ERR_CUST_BAD_UNAME\
		2502 OB_ERR_CUST_ACCT_SUS]

	# columns from tCustomerReg (backwards compliance)
	set REG_COLS [list postcode telephone email title first_name last_name city code \
		addr_street_1 addr_street_2 addr_street_3 addr_street_4 country]

	# columns from tPokCust
	set POK_COLS [list pok_ext_user_id pok_nickname pok_freeplay_bal\
	                   pok_avatar_id]

	# cookie data items
	set COOKIE_COLS [list login_status critical cust_id cookie pwd pin type]

	# insecure cookie cols
	set INSECURE_COOKIE_COLS [list cust_id acct_id insecure_cookie]

	# init flag
	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
# Automatically sets the cookie encryption base. If bintob64 (libOT_Tcl)
# is present, then the base is set to base64, else hexadecimal.
#
proc ob_login::init args {

	variable CFG
	variable INIT
	variable INSECURE_COOKIE_COLS

	# already initialised
	if {$INIT} {
		return
	}

	# init dependencies
	ob_db::init
	ob_log::init
	ob_util::init
	ob_crypt::init
	ob_control::init

	ob_log::write DEBUG {LOGIN: init}

	# get configuration
	array set OPT [list \
		pre_auth                  1\
		uid_is_time               0\
		login_key_hex             0\
		pwd_salt                  1\
		cookie_hmac               1\
		cookie_hmac_key           1\
		cookie_ip_addr            1\
		cookie_gmt                1\
		func_insecure_cookie      0\
		insecure_key_hex          0\
		logged_out_str            NOT_LOGGED_IN\
		login_keepalive           ""\
		ambiguous_login           0\
		do_site_checking          0\
		site_check_channel        I\
		enable_elite              0\
		write_login_hist          0\
		login_cookie_fmt          NEW\
		session_tracking          0\
		login_poker               0\
		migrate_passwords         0\
		hash_proc                 ""\
		pwd_case_insensitive      0\
		3party_login              0\
		csrf_protection           0]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "CUST_[string toupper $c]" $OPT($c)]
	}

	if {$CFG(pre_auth)} {
		ob_log::write WARNING {LOGIN: pre-auth flag enabled}
	}

	if { $CFG(session_tracking) } {
		if { $CFG(login_cookie_fmt) ne "NEW" } {
			error "LOGIN: session_tracking required new login-cookie format"
		} else {
			package require cust_session
			::ob_session::init
		}
	}

	# can use b64 cookies
	if {[catch {bintob64 testbase64} msg]} {
		ob_log::write WARNING {LOGIN: b64 disabled - $msg}
		set CFG(crypt_base) hex
	} else {
		set CFG(crypt_base) b64
	}

	# cookie decrypt key & type
	if {$CFG(login_key_hex) == 0} {
		set CFG(login_key_type) bin
		set CFG(login_key)      [OT_CfgGet CUST_LOGIN_KEY_BIN]
	} else {
		set CFG(login_key_type) hex
		set CFG(login_key)      $CFG(login_key_hex)
	}

	# cookie decrypt key & type
	if {$CFG(func_insecure_cookie) && $CFG(insecure_key_hex) == 0} {
		set CFG(insecure_key_type) bin
		set CFG(insecure_key)      [OT_CfgGet CUST_INSECURE_KEY_BIN ""]
	} else {
		set CFG(insecure_key_type) hex
		set CFG(insecure_key)      $CFG(insecure_key_hex)
	}

	# insecure cookie items
	set CFG(insecure_cookie_items) [list]
	foreach {item pattern} [join [OT_CfgGet CUST_INSECURE_COOKIE_ITEMS {}] " "] {
		lappend CFG(insecure_cookie_items)         $item
		lappend INSECURE_COOKIE_COLS               $item
		set     CFG(insecure_cookie_pattern,$item) $pattern
	}

	# (MAC) Missing Account Creation Configuration
	if {[OT_CfgGet MISSING_ACCOUNT_CREATION.ENABLED  0]} {
		set CFG(MISSING_ACCOUNT_CREATION.ENABLED) 1
		set CFG(MISSING_ACCOUNT_CREATION.DFLT_PWD) [md5 [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_PWD ""]]
		set CFG(MISSING_ACCOUNT_CREATION.DFLT_CCY) [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_CCY "GBP"]
		set CFG(MISSING_ACCOUNT_CREATION.DFLT_TXT) [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_TXT "Auto Account Creation"]
		set CFG(MISSING_ACCOUNT_CREATION.DFLT_COUNTRY_CODE) [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_COUNTRY_CODE "FR"]
		set CFG(MISSING_ACCOUNT_CREATION.DFLT_LANG) [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_LANG "fr"]
	} else {
		set CFG(MISSING_ACCOUNT_CREATION.ENABLED) 0
	}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "LOGIN: reqGetId not available for auto reset"
	}

	# prepare package queries
	_prepare_qrys
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_login::_prepare_qrys args {

	variable CFG

	# store login UID qry if not using clock seconds as UID
	if {!$CFG(uid_is_time)} {
		ob_db::store_qry ob_login::get_uid {
		    execute procedure pGenLoginUID()
		}
	}

	# login
	ob_db::store_qry ob_login::login {
		execute procedure pLogin(
		    p_cust_id          = ?,
		    p_username         = ?,
		    p_password         = ?,
		    p_password_mig     = ?,
		    p_acct_no          = ?,
		    p_pin              = ?,
		    p_login_uid        = ?,
		    p_enable_elite     = ?,
		    p_ambiguous_login  = ?,
		    p_do_site_checking = ?,
		    p_channel          = ?
		)
	}

	# 3rd party login
	# if the (MAC) Missing Account Creating functionality is enabled
	# then we create a stub account if the account does not exist
	if {$CFG(MISSING_ACCOUNT_CREATION.ENABLED)} {
		ob_db::store_qry ob_login::3PLogin [subst {
			execute procedure p3PLogin(
				p_cust_id                   = ?,
				p_acct_no                   = ?,
				p_login_uid                 = ?,
				p_enable_elite              = ?,
				p_do_site_checking          = ?,
				p_channel                   = ?,
				p_missing_acct_cr           = 'Y',
				p_missing_acct_pwd          = '$CFG(MISSING_ACCOUNT_CREATION.DFLT_PWD)',
				p_missing_acct_ccy          = '$CFG(MISSING_ACCOUNT_CREATION.DFLT_CCY)',
				p_missing_acct_txt          = '$CFG(MISSING_ACCOUNT_CREATION.DFLT_TXT)',
				p_missing_acct_country_code = '$CFG(MISSING_ACCOUNT_CREATION.DFLT_COUNTRY_CODE)',
				p_missing_acct_lang         = '$CFG(MISSING_ACCOUNT_CREATION.DFLT_LANG)'
			)
		}]
	} else {
		ob_db::store_qry ob_login::3PLogin {
			execute procedure p3PLogin(
				p_cust_id          = ?,
				p_acct_no          = ?,
				p_login_uid        = ?,
				p_enable_elite     = ?,
				p_do_site_checking = ?,
				p_channel          = ?
			)
		}
	}

	ob_db::store_qry ob_login::get_cur_uid {
		select
			login_uid
		from
			tcustomer
		where
			username = ?
	}

	# get registration data (backwards compliance)
	ob_db::store_qry ob_login::get_reg {
		select
			addr_postcode as postcode,
			telephone,
			email,
			title,
			fname as first_name,
			lname as last_name,
			addr_city as city,
			code,
			addr_street_1,
			addr_street_2,
			addr_street_3,
			addr_street_4,
			addr_country as country
		from
			tCustomerReg
		where
			cust_id = ?
	}

	# get poker user data
	if {$CFG(login_poker)} {
		ob_db::store_qry ob_login::get_poker {
			select
			    ext_user_id  as pok_ext_user_id,
			    nickname     as pok_nickname,
			    freeplay_bal as pok_freeplay_bal,
			    avatar_id    as pok_avatar_id
			from
			    tPokCust
			where
			    cust_id = ?
		}
	}

	# get customer data
	if {$CFG(pre_auth)} {
		ob_db::store_qry ob_login::get {
			select
			    a.acct_id,
			    a.acct_type,
			    a.ccy_code,
			    a.balance,
			    a.sum_ap,
			    a.balance_nowtd,
			    a.credit_limit,
			    a.owner,
				a.owner_type,
			    c.type as cust_type,
			    c.max_stake_scale,
			    c.allow_card,
			    c.lang,
			    c.source as channel,
			    c.status,
			    c.reg_status,
			    c.country_code as cntry_code,
			    c.bet_count,
			    c.login_count,
			    c.login_uid,
			    c.temporary_pin as temp_pin,
			    c.temporary_password as temp_pwd,
			    c.password as pwd,
			    c.password_salt,
			    c.bib_pin as pin,
			    c.username,
			    c.acct_no,
			    c.aff_id,
			    c.elite,
			    c.notifyable
			from
			    tAcct a,
			    tCustomer c
			where
			    a.cust_id = ?
			and c.cust_id = a.cust_id
		}
	} else {
		ob_db::store_qry ob_login::get {
			select
			    a.acct_id,
			    a.acct_type,
			    a.ccy_code,
			    a.balance,
			    a.sum_ap,
			    a.balance_nowtd,
			    a.credit_limit,
			    a.owner,
				a.owner_type,
			    c.type as cust_type,
			    c.max_stake_scale,
			    c.allow_card,
			    c.lang,
			    c.source as channel,
			    c.status,
			    c.country_code as cntry_code,
			    c.bet_count,
			    c.login_count,
			    c.password as pwd,
			    c.password_salt,
			    c.bib_pin as pin,
			    c.username,
			    c.acct_no,
			    c.aff_id,
			    c.elite,
			    c.notifyable
			from
			    tAcct a,
			    tCustomer c
			where
			    a.cust_id = ?
			and c.cust_id = a.cust_id
		}
	}

	# get acct_no
	ob_db::store_qry ob_login::get_acct_no {
		select
		    acct_no
		from
		    tCustomer
		where
		    cust_id = ?
	}

	# get password_salt
	ob_db::store_qry ob_login::get_password_salt {
		select
		    password_salt
		from
		    tCustomer
		where
		    cust_id = ?
	}

	# get password_salt
	ob_db::store_qry ob_login::get_uname_password_salt {
		select
		    password_salt
		from
		    tCustomer
		where
		    username_uc = ?
	}

	# write login history
	if {$CFG(write_login_hist)} {
		ob_db::store_qry ob_login::write_history {
		    insert into tLogin(cust_id, aff_id, source)
		    values (?, ?, ?)
		}
	}

	# update password
	ob_db::store_qry ob_login::upd_pwd {
		execute procedure pUpdCustPasswd(
		    p_username = ?,
		    p_old_pwd  = ?,
		    p_new_pwd  = ?,
		    p_temp_pwd = ?
		)
	}

	# update pin
	ob_db::store_qry ob_login::upd_pin {
		execute procedure pUpdCustPIN(
		    p_acct_no        = ?,
		    p_old_pin        = ?,
		    p_password       = ?,
		    p_new_pin        = ?,
		    p_min_pin_length = ?,
		    p_max_pin_length = ?
		)

	}

	# update language
	ob_db::store_qry ob_login::upd_lang {
		update
			tCustomer
		set
			lang = ?
		where
			cust_id = ?
	}

	# acct balance
	ob_db::store_qry ob_login::get_balance {
		select
			(a.balance + a.sum_ap) as balance
		from
			tAcct     a
		where
			a.acct_id = ?
	}

	# decrement the failed login counter when re-trying using the second
	# hash function
	ob_db::store_qry ob_login::decrement_failed_counter {
		update
			tCustomer
		set
			login_fails = login_fails - 1
		where
			    username_UC = UPPER(?)
			and login_fails > 0
	}

	# Count the customer messages
	ob_db::store_qry ob_login::get_message_count {
		select
			COUNT(message) as messages
		from
			tCustomerMsg
		where
			cust_id = ?
			and sort in ('O','S')

	}
}




# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_login::_auto_reset args {

	variable LOGIN

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$LOGIN(req_no) != $id} {
		catch {unset LOGIN}
		set LOGIN(req_no) $id
		ob_log::write DEV {LOGIN: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}



# Private procedure to clear the login details.
#
proc ob_login::_clear args {

	variable CFG
	variable LOGIN
	variable INSECURE_COOKIE_COLS
	global LOGIN_DETAILS USER_ID USERNAME

	foreach c {uid type pwd pin cust_id username acct_no cookie} {
		set LOGIN($c) ""
	}

	if {$CFG(func_insecure_cookie)} {
		foreach c $INSECURE_COOKIE_COLS {
			set LOGIN($c) ""
		}
	}

	catch {unset LOGIN_DETAILS}
	catch {unset USERNAME}
	catch {unset USER_ID}
}


#--------------------------------------------------------------------------
# Accessor
#--------------------------------------------------------------------------

# Get a login data item.
# The customer data is stored within the package cache, loaded from
# database if not previously done so within the scope of a request.
#
#   name    - customer data name
#   dflt    - default data value if the requested data item contains no data
#             (default: "")
#   returns - customer data value
#             or an empty string if -
#             - the name does not exist
#             - not logged in
#             - different request
#             - have not performed a critical login and requesting
#               critical data (tAcct.acct_id)
#
proc ob_login::get { name {dflt ""} } {

	variable CFG
	variable LOGIN
	variable REG_COLS
	variable POK_COLS
	variable COOKIE_COLS
	variable INSECURE_COOKIE_COLS

	# different request, or no cust_id (not performed a login, or failed login)?
	if {[_auto_reset] ||
	    (![info exists LOGIN(cust_id)] || $LOGIN(cust_id) == "")} {

		if {$name == "login_status"           &&
		    [info exists LOGIN(login_status)] &&
		    $LOGIN(login_status) != ""} {
			return $LOGIN(login_status)
		}
		return $dflt
	}

	# if requesting a non-cookie data item and only performed a cookie check,
	# do a critical login
	# - if failed, then return default value (login_status will contain error
	#   details)
	set cookie_col          [lsearch $COOKIE_COLS          $name]
	set insecure_cookie_col [lsearch $INSECURE_COOKIE_COLS $name]

	if {$cookie_col == -1
		&& (!$CFG(func_insecure_cookie) || $insecure_cookie_col == -1)
		&& $LOGIN(critical) == 0} {

		ob_log::write DEBUG {LOGIN: get critical ($name) - perform login}

		if {$CFG(func_insecure_cookie) &&
		    $LOGIN(login_method) == "INSECURE_COOKIE"} {
			# We don't allow full login without the full cookie
			error "Cannot perform login from an insecure cookie check."
		}

		set LOGIN(critical) 1

		if {$CFG(3party_login)} {
			set LOGIN(login_status) [_3party_db_login]
		} elseif {$CFG(ambiguous_login)} {
			set LOGIN(login_status) [_ambiguous_db_login]
		} else {
			set LOGIN(login_status) [_db_login $LOGIN(pwd) $LOGIN(pin)]
		}

		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			ob_log::write ERROR \
			    {LOGIN: critical login failed, status=$LOGIN(login_status)}

			return $dflt
		}

	# else if a cookie data item, then return the data
	} elseif {$cookie_col != -1 && $LOGIN(critical) == 0} {

		if {[info exists LOGIN($name)] && $LOGIN($name) != ""} {
			return $LOGIN($name)
		} else {
			return $dflt
		}
	} elseif {$CFG(func_insecure_cookie) &&
	          $insecure_cookie_col != -1 &&
	          $LOGIN(critical)     ==  0} {

		if {[info exists LOGIN($name)] && $LOGIN($name) != ""} {
			return $LOGIN($name)
		} else {
			return $dflt
		}
	}

	# force an update?
	if {[info exists LOGIN(force_update)] && $LOGIN(force_update)} {
		ob_log::write DEBUG {LOGIN: forced update detected}
		set force_upd 1
	} else {
		set force_upd 0
	}

	# does data already exist
	# - if blank, have an attempt to fetch from database 1st
	if {!$force_upd && [info exists LOGIN($name)] && $LOGIN($name) != ""} {
		return $LOGIN($name)
	}

	# which query to use
	# - do not have a join on customer reg or poker, as don't think this is
	#  common data to retrieve, but added for backwards compliance

	if { $name == "messages" } {
		set qry ob_login::get_message_count
	} elseif {[lsearch $REG_COLS $name] != -1} {
		set qry ob_login::get_reg
	} elseif {$CFG(login_poker) && [lsearch $POK_COLS $name] != -1} {
		set qry ob_login::get_poker
	} else {
		set qry ob_login::get
	}

	# already retrieved cust data
	if {!$force_upd && [info exists LOGIN($qry)]} {
		if {![info exists LOGIN($name)]} {
			error "can't read LOGIN($name): no such variable"
		}
		return $dflt
	}

	# get data
	_load $qry $name

	# does data exist?
	if {[info exists LOGIN($name)]} {
		if {$LOGIN($name) != ""} {
			return $LOGIN($name)
		} else {
			return $dflt
		}

	# allow for poker/backgammon details not present
	# - upto the caller to verify data
	} elseif {$qry == "ob_login::get_poker"} {
		return $dflt
	} else {
		error "can't read LOGIN($name): no such variable"
	}
}



# Get balance from db, update cookie
#
proc ob_login::get_balance {} {

	variable CFG
	variable LOGIN
	variable INSECURE_COOKIE_COLS

	if {[get login_status] != "OB_OK"} {
		return OB_ERR_CUST_GUEST
	}

	if {[catch {set rs [ob_db::exec_qry ob_login::get_balance [get acct_id]]} msg]} {
		ob_log::write ERROR {ob_login::get_balance - $msg}
		return OB_GET_BALANCE_ERR
	}

	if {![db_get_nrows $rs]} {
		ob_db::rs_close $rs
		ob_log::write ERROR {ob_login::get_balance - no row found}
		return OB_GET_BALANCE_NO_ROW_ERR
	}

	set balance [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	set LOGIN(balance) $balance

	# We need to regenerate the insecure cookie if it contains the balance
	if {$CFG(func_insecure_cookie) && [lsearch $INSECURE_COOKIE_COLS balance] != -1} {
		_encrypt_insecure_cookie

	}

	return $balance
}



# Force an update of the login-data.
# The package cannot detect if any of data has changed within the scope of a
# request. This method simply denotes that the next get accessor call will
# reload the data.
#
proc ob_login::force_update args {

	variable LOGIN

	if {![_auto_reset]} {
		set LOGIN(force_update) 1
	}
}



# Private procedure to load data from the database and add to the package
# cache.
#
#   qry  - load query name
#   name - customer data name
#
proc ob_login::_load { qry name } {

	variable CFG
	variable LOGIN

	# load
	set rs    [ob_db::exec_qry $qry $LOGIN(cust_id)]
	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_db::rs_close $rs

		# error if not the poker query
		# - we might be testing for the existence of a poker/backgammon customer
		#   therefore we leave to caller to handle the missing data
		if {$qry != "ob_login::get_poker"} {
			error "Returned $nrows of customer data"
		}
		return
	}
	set cols  [db_get_colnames $rs]
	foreach c $cols {
		set LOGIN($c) [db_get_col $rs 0 $c]
	}
	ob_db::rs_close $rs

	if {$qry == "ob_login::get"} {

		# if using authentication-server, set data which is no-longer part
		# of tCustomer (backwards-compliance)
		if {!$CFG(pre_auth)} {
			set LOGIN(temp_pwd)   N
			set LOGIN(temp_pin)   N
			set LOGIN(reg_status) ""
		}

		# set temp-auth
		if {$LOGIN(type) == "W"} {
			set LOGIN(temp_auth) $LOGIN(temp_pwd)
		} elseif {$LOGIN(type) == "N"} {
			set LOGIN(temp_auth) $LOGIN(temp_pin)
		} else {
			set LOGIN(temp_auth) N
		}

		# set encoded password (backward-compliance)
		set LOGIN(enc_password) $LOGIN(pwd)
	}

	# denote data as loaded
	set LOGIN($qry) 1
	set LOGIN(force_update) 0
}



#--------------------------------------------------------------------------
# Login
#--------------------------------------------------------------------------

# Is guest access only.
#
# Determines if the user has successfully logged in within the scope of a
# request. If only performed a ::check_cookie, the procedure will verify the
# cookie details against the database (failure will result in guest access
# only).
#
#   returns - 1 if guest, zero if openbet customer
#
proc ob_login::is_guest args {

	variable CFG
	variable LOGIN

	# guest if new request, or no cust_id
	# - no cust_id will also denote a failed login attempt, as the
	#   the login data items are always cleared on error
	if {[_auto_reset] ||
	    (![info exists LOGIN(cust_id)] || $LOGIN(cust_id) == "")} {

		# denote guest access error?
		if {![info exists LOGIN(login_status)] || $LOGIN(login_status) == ""} {
			set LOGIN(login_status) OB_ERR_CUST_GUEST
		}

		return 1
	}

	# if only performed a check_cookie, then must verify the
	# details against the database before determining if a guest user
	# - NB: if login error, then denote as a guest
	if {$LOGIN(critical) == 0} {

		ob_log::write DEBUG {LOGIN: is_guest performing login}

		set LOGIN(critical) 1
		if {$CFG(3party_login)} {
			set LOGIN(login_status) [_3party_db_login]
		} elseif {$CFG(ambiguous_login)} {
			set LOGIN(login_status) [_ambiguous_db_login]
		} else {
			set LOGIN(login_status) [_db_login $LOGIN(pwd) $LOGIN(pin)]
		}

		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			ob_log::write ERROR \
			    {LOGIN: critical login failed, status=$LOGIN(login_status)}
			return 1
		}
	}

	# non-guest
	return 0
}



# Perform form based login (supplied a username/acct_no and pwd/pin).
#
# Checks the supplied details against the database, via pLogin stored procedure
# and encrypts a login cookie (stored in package cache).
#
# The procedure allows multiple login calls per request. The package cache is
# always reset.
#
# NB: The procedure does not get the login parameters from a HTML/WML form
# It is caller's responsibility to get and supply the login details.
#
#   type     - login type (pass'W'ord | pi'N')
#   username - username or acct_no (depends on type or if ambiguous login)
#   pwd      - password or pin (enc_pwd denotes if encrypted/uncrypted)
#              (depends on type or if ambiguous login)
#   uid      - login uid (should be different per login request)
#   aff_id   - affiliate identifier
#              only required if cfg CUST_WRITE_LOGIN_HIST is enabled
#              (default - "")
#   source   - channel source
#              only required if cfg CUST_WRITE_LOGIN_HIST is enabled
#              (default - I)
#   enc_pwd  - is the supplied password or pin encrypted (0)
#   mig_pwd  - is the supplied password already hashed with the custom $CFG(hash_proc)
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::form_login {
	  type
	  username
	  pwd
	  uid
	{ aff_id "" }
	{ source  I }
	{ enc_pwd 0 }
	{ mig_pwd 0 }
} {

	variable CFG
	variable LOGIN

	ob_log::write DEBUG {LOGIN: form login type=$type user=$username uid=$uid}

	# check login parameters
	if {
		![ob_util::is_safe $username]
		|| ![ob_util::is_safe $pwd]
		|| ($uid == "" && !$CFG(3party_login))
		|| $type != "N" && $type != "W" && !$CFG(ambiguous_login)
	} {
		return OB_ERR_CUST_LOGIN_FAILED
	}

	# Are passwords case_insensitive and the supplied password not already
	# hashed?
	if {$CFG(pwd_case_insensitive) && !$mig_pwd} {
		set pwd [string toupper $pwd]
	}

	# reset package cache (in-case not performed within scope of request)
	# and denote critical login
	_auto_reset
	set LOGIN(critical) 1

	# is it a migrated password?
	set LOGIN(is_pwd_mig) 0

	# build the login parameters and attempt to login
	if {$CFG(3party_login)} {
		_build_login_params $type $username $pwd $uid $enc_pwd
		set LOGIN(login_status) [_3party_db_login]
	} elseif {$CFG(ambiguous_login)} {
		_build_ambiguous_login_params $username $pwd $uid $enc_pwd
		set LOGIN(login_status) [_ambiguous_db_login]

	} else {
		_build_login_params $type $username $pwd $uid $enc_pwd
		set LOGIN(login_status) [_db_login $LOGIN(pwd) $LOGIN(pin)]
		if {$CFG(migrate_passwords) && $LOGIN(login_status) != "OB_OK"} {
			# If the standard login failed give them another bite of the cherry
			# using the migrated password hashing proc
			if {!$mig_pwd} {
				foreach {status pwd_mig} [$CFG(hash_proc) $LOGIN(username) $pwd] {}

				# record that we're updating a migrated password
				set LOGIN(is_pwd_mig) 1

			} else {
				# We already provided the migration hashed pwd
				set status OK
				set pwd_mig $pwd
			}

			if {$status eq "OK"} {
				ob_log::write DEBUG {LOGIN: pwd_mig=$pwd_mig}

				# The first failed attempt to login using the standard hash
				# would have incremented the failed logins counter for this
				# user. We need to decrement it before trying again
				if {[catch {
					ob_db::exec_qry ob_login::decrement_failed_counter $LOGIN(username)
				} msg]} {
					ob_log::write WARNING \
						{LOGIN: Failed to decrement failed login counter - $msg}
				}

				set LOGIN(login_status) \
					[_db_login $LOGIN(pwd) $LOGIN(pin) 0 $pwd_mig]
			} else {
				set LOGIN(login_status) $status
			}
		}
	}

	# start session
	if { $CFG(session_tracking) && $LOGIN(login_status) == "OB_OK" } {

		if { [catch {
			set LOGIN(login_status) [::ob_session::start $LOGIN(cust_id)]
		} err] } {
			ob_log::write ERROR {LOGIN: could not start session: $err}
			set LOGIN(login_status) OB_ERR_CUST_SESS_START
		}

		if { $LOGIN(login_status) == "OB_OK" } {
			set LOGIN(session_id) [::ob_session::get session_id]
		}

	}

	# write login history
	if {$CFG(write_login_hist) && $LOGIN(login_status) == "OB_OK"} {
		set LOGIN(login_status) [_write_history $aff_id $source]
	}

	# protect against CSRF
	if {$CFG(csrf_protection)} {
		# tag the login session with a unique id
		set LOGIN(csrf_uid) [OT_UniqueId]
	}

	# encrypt the cookie
	# - clear the data on error
	if {$LOGIN(login_status) == "OB_OK"} {
		_encrypt_cookie

		if {$CFG(func_insecure_cookie)} {
			_encrypt_insecure_cookie
		}
	} else {
		_clear
	}

	return $LOGIN(login_status)
}



# Check password
#
# Returns - OK or ERR
#
proc ob_login::password_ok {pwd} {

	variable CFG

	if {$CFG(pwd_case_insensitive)} {
		set pwd [string toupper $pwd]
	}

	set cust_id [ob_login::get cust_id]

	# get the password salt if enabled
	if {$CFG(pwd_salt)} {

		set rs    [ob_db::exec_qry ob_login::get_password_salt $cust_id]
		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			ob_db::rs_close $rs
			ob_log::write ERROR {LOGIN: get_password_salt returned $nrows rows}
			_clear
			return ERR
		}

		set password_salt [db_get_col $rs 0 password_salt]
		ob_db::rs_close $rs

	} else {
		set password_salt ""
	}

	set encrypt_pwd [ob_crypt::encrypt_password $pwd $password_salt]
	if {$encrypt_pwd == [ob_login::get enc_password]} {
		return OK
	} else {
		return ERR
	}
}



# Perform automatic login after registration, by constructing a login cookie
# string (stored in package cache).
#
# The procedure allows multiple login calls per request. The package cache is
# always reset.
#
# NB: The procedure does not get the login parameters from a HTML/WML form
# It is caller's responsibility to get and supply the login details.
#
#   cust_id  - customer identifier
#   pwd      - password or pin (type is dependent if username is supplied)
#   username - username (default: "")
#              if supplied then password type, else pin type where the
#              account number is extracted from the database
#   aff_id   - affiliate identifier
#              only required if cfg CUST_WRITE_LOGIN_HIST is enabled
#              (default - "")
#   source   - channel source
#              only required if cfg CUST_WRITE_LOGIN_HIST is enabled
#              (default - I)
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::auto_login {
	  cust_id
	  pwd
	{ username "" }
	{ aff_id   "" }
	{ source    I }
	{ in_tran   0 }
} {

	variable CFG
	variable LOGIN

	# check login parameters
	if {$cust_id == "" || $pwd == ""} {
		return OB_ERR_CUST_LOGIN_FAILED
	}

	if {$CFG(pwd_case_insensitive)} {
		set pwd [string toupper $pwd]
	}

	# reset package cache (in-case not performed within scope of request)
	# and denote critical login
	_auto_reset
	_clear
	set LOGIN(cust_id)  $cust_id
	set LOGIN(critical) 1

	# supplied a username, then password login
	if {$username != ""} {

		# get the password salt if enabled
		if {$CFG(pwd_salt)} {
			set rs    [ob_db::exec_qry ob_login::get_password_salt $cust_id]
			set nrows [db_get_nrows $rs]
			if {$nrows != 1} {
				ob_db::rs_close $rs
				ob_log::write ERROR {LOGIN: get_password_salt returned $nrows rows}
				_clear
				return [set LOGIN(login_status) OB_ERR_CUST_LOGIN_FAILED]
			}

			set password_salt [db_get_col $rs 0 password_salt]

			ob_db::rs_close $rs
		} else {
			set password_salt ""
		}

		set LOGIN(type)     W
		set LOGIN(username) $username
		set LOGIN(pwd)      [ob_crypt::encrypt_password $pwd $password_salt]
		set LOGIN(pin)      ""

	# else pin login
	} else {

		# get the acct_no
		set rs    [ob_db::exec_qry ob_login::get_acct_no $cust_id]
		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			ob_db::rs_close $rs
			ob_log::write ERROR {LOGIN: get acct_no returned $nrows rows}
			_clear
			return [set LOGIN(login_status) OB_ERR_CUST_LOGIN_FAILED]
		}

		set LOGIN(type)    N
		set LOGIN(acct_no) [db_get_col $rs 0 acct_no]
		set LOGIN(pin)     [ob_crypt::encrypt_pin $pwd]
		set LOGIN(pwd)      ""

		ob_db::rs_close $rs
	}

	# start session
	if { $CFG(session_tracking) } {

		if { [catch {
			set LOGIN(login_status) \
				[::ob_session::start \
					$LOGIN(cust_id) \
					"" \
					"" \
					I \
					M \
					"" \
					"" \
					$in_tran]
		} err] } {
			ob_log::write ERROR {LOGIN: could not start session: $err}
			return [set LOGIN(login_status) OB_ERR_CUST_SESS_START]
		}

		if { $LOGIN(login_status) ne "OB_OK" } {
			return $LOGIN($login_status)
		}

		set LOGIN(session_id) [::ob_session::get session_id]

	}

	# write login history
	if {$CFG(write_login_hist) && [_write_history $aff_id $source] != "OB_OK"} {
		return [set LOGIN(login_status) OB_ERR_CUST_LOGIN_FAILED]
	}

	# protect against CSRF
	if {$CFG(csrf_protection)} {
		# tag the login session with a unique id
		set LOGIN(csrf_uid) [OT_UniqueId]
	}

	# encrypt the cookie
	_encrypt_cookie

	if {$CFG(func_insecure_cookie)} {
		_encrypt_insecure_cookie
	}

	ob_log::write INFO {LOGIN: auto-login cust_id=$cust_id}
	return [set LOGIN(login_status) OB_OK]
}



# Perform Telebet (TBS) login.
#
# TBS does not perform cookie or form based login on a customer, but does have
# a customer identifier. The procedure fools the package into thinking that a
# full critical login has successfully occurred, therefore, providing TBS with
# full access to the customer's details.
#
# This procedure should only be called by TBS.
#
#   cust_id  - customer identifier
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::tbs_login { cust_id } {

	variable LOGIN

	# check parameters
	if {$cust_id == ""} {
		return OB_ERR_CUST_LOGIN_FAILED
	}

	# reset package cache (in-case not performed within scope of request)
	# and denote critical login
	_auto_reset
	_clear
	set LOGIN(cust_id)      $cust_id
	set LOGIN(critical)     1
	set LOGIN(force_update) 1

	ob_log::write INFO {LOGIN: tbs login, cust_id=$cust_id}
	return [set LOGIN(login_status) OB_OK]
}



# Private procedure to build the form login parameters (see ::form_login).
# Adds the supplied parameters to the package cache.
#
#   type     - login type (pass'W'ord | pi'N')
#   username - username or acct_no (depends on type)
#   pwd      - unencrypted password or pin (depends on type)
#   uid      - login uid (should be different per login request)
#   enc_pwd  - is the supplied password or pin encrypted
#
proc ob_login::_build_login_params { type username pwd uid enc_pwd } {

	variable CFG
	variable LOGIN

	# clear data
	_clear

	# set params based on login type
	set LOGIN(type) $type
	switch -- $type {
		"W" {
			set LOGIN(username) $username
			if {!$enc_pwd} {
				# Load the password salt if required
				set password_salt ""
				if {$CFG(pwd_salt)} {
					set rs    [ob_db::exec_qry ob_login::get_uname_password_salt [string toupper $username]]
					set nrows [db_get_nrows $rs]
					if {$nrows == 1} {
						set password_salt [db_get_col $rs 0 password_salt]
					} else {
						ob_log::write ERROR {LOGIN: get_uname_password_salt returned $nrows rows}
					}
					ob_db::rs_close $rs
				}
				set LOGIN(pwd) [ob_crypt::encrypt_password $pwd $password_salt]
			} else {
				set LOGIN(pwd) $pwd
			}
		}
		"N" {
			set LOGIN(acct_no)  $username
			if {!$enc_pwd} {
				set LOGIN(pin) [ob_crypt::encrypt_pin $pwd]
			} else {
				set LOGIN(pin) $pwd
			}
		}
	}

	# set UID
	set LOGIN(uid) $uid
}



# Private procedure to build the form login parameters for ambiguous login
# (see ::form_login). Adds the supplied parameters to the package cache.
#
# Attempts to guess the login type by checking if the supplied password
# only contains numbers, in which case denote as PIN type. However,
# database login will swap the login type if failed.
#
#   username - username or acct_no
#   pwd      - unencrypted password or pin
#   uid      - login uid (should be different per login request)
#   enc_pwd  - is the supplied password or pin encrypted
#
proc ob_login::_build_ambiguous_login_params { username pwd uid enc_pwd } {

	variable LOGIN

	# clear data
	_clear

	# try to guess the login type
	if {[regexp {^([0-9]+)$} $pwd]} {
		set LOGIN(type) N
	} else {
		set LOGIN(type) W
	}

	# set details
	set LOGIN(username) $username
	if {!$enc_pwd} {
		# Load the password salt if required
		set password_salt ""
		if {$CFG(pwd_salt)} {
			set rs    [ob_db::exec_qry ob_login::get_uname_password_salt $username]
			set nrows [db_get_nrows $rs]
			if {$nrows == 1} {
				set password_salt [db_get_col $rs 0 password_salt]
			} else {
				ob_log::write ERROR {LOGIN: get_uname_password_salt returned $nrows rows}
			}
			ob_db::rs_close $rs
		}
		set LOGIN(pwd) [ob_crypt::encrypt_password $pwd $password_salt]
		set LOGIN(pin) [ob_crypt::encrypt_pin $pwd]
	} else {
		set LOGIN(pwd) $pwd
		set LOGIN(pin) $pwd
	}

	# set UID
	set LOGIN(uid) $uid
}


# Private procedure to perform ambiguous login via pLogin stored procedure.
# Attempts login with the supplied login type (guessed by
# ::_build_ambiguous_login_params), however, if this fails, the procedure
# will swap the type (if this fails, a failed login is denoted).
#
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::_ambiguous_db_login args {

	variable CFG
	variable LOGIN

	# try password, then pin; or pin then password
	for {set count 2} {$count > 0} {incr count -1} {

		ob_log::write DEBUG {LOGIN: ambiguous login, type=$LOGIN(type)}

		# set pwd & pin
		if {$LOGIN(type) == "W"} {
			set pwd $LOGIN(pwd)
			set pin ""
		} else {
			set pwd ""
			set pin $LOGIN(pin)
		}

		# attempt to login
		set status [_db_login $pwd $pin $count]
		if {$status == "OB_OK" || $status == "OB_ERR_CUST_SEQ"} {
			return $status
		}

		# not successful, swap login type maybe wrong guess
		if {$LOGIN(type) == "W"} {
			set LOGIN(type) N
		} else {
			set LOGIN(type) W
		}
	}

	return $status
}



# Private procedure to perform login via pLogin stored procedure.
#
#   pwd              - password
#   pin              - pin
#   ambiguous_login  - ambiguous login count (default: 0)
#   pwd_mig          - existing (migrated) password hash (default: "")
#   returns          - login status string (OB_OK denotes success)
#
proc ob_login::_db_login { pwd pin {ambiguous_login 0} {pwd_mig ""}} {

	variable CFG
	variable LOGIN

	# attempt to login
	if {[catch {
		set rs [ob_db::exec_qry ob_login::login \
		           $LOGIN(cust_id)\
		           $LOGIN(username)\
		           $pwd\
		           $pwd_mig\
		           $LOGIN(acct_no)\
		           $pin\
		           $LOGIN(uid)\
		           $CFG(enable_elite)\
		           $ambiguous_login\
		           $CFG(do_site_checking)\
		           $CFG(site_check_channel)]
	} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return [_get_err_code $msg]
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_db::rs_close $rs
		ob_log::write ERROR {LOGIN: plogin returned $nrows rows}
		return OB_ERR_CUST_LOGIN_FAILED
	}

	# set login details
	set LOGIN(cust_id)  [db_get_coln $rs 0]
	set LOGIN(username) [db_get_coln $rs 1]
	set LOGIN(acct_no)  [db_get_coln $rs 2]

	ob_db::rs_close $rs

	ob_log::write INFO {LOGIN: db-login cust_id=$LOGIN(cust_id)}
	return OB_OK
}



# Private procedure to perform login via p3PLogin stored procedure.
# It only checks whether a given customer exists in the Openbet database.
#
#   returns          - login status string (OB_OK denotes success)
#
proc ob_login::_3party_db_login {} {

	variable CFG
	variable LOGIN

	# attempt to login
	if {[catch {
		set rs [ob_db::exec_qry ob_login::3PLogin \
			$LOGIN(cust_id) \
			$LOGIN(acct_no) \
			$LOGIN(uid) \
			$CFG(enable_elite) \
			$CFG(do_site_checking) \
			$CFG(site_check_channel) \
		]
	} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return [_get_err_code $msg]
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_db::rs_close $rs
		ob_log::write ERROR {LOGIN: plogin returned $nrows rows}
		return OB_ERR_CUST_LOGIN_FAILED
	}

	# set login details
	set LOGIN(cust_id)       [db_get_coln $rs 0]
	set LOGIN(acct_no)       [db_get_coln $rs 1]
	set LOGIN(stub_created)  [db_get_coln $rs 2]

	ob_db::rs_close $rs

	if {$LOGIN(stub_created) == "Y"} {
		ob_log::write INFO {LOGIN: We have created a stub account}
	}

	# Here, we perform freebet checks for registration after stub account creation
	# If the config is enabled, and a stub account was created during the third party login
	# we check for the registration triggers
	if {[OT_CfgGet MISSING_ACCOUNT_CREATION.ENABLED  0]} {
		# We check the registration trigger here, if we had to create a stub account
		if {$LOGIN(stub_created) == "Y"} {

			# freebet registration check
			::ob_fbets::check_action_fast \
			-cust_id $LOGIN(cust_id) \
			-actions "REG" \
			-channel "I" \
			-lang $CFG(MISSING_ACCOUNT_CREATION.DFLT_LANG) \
			-ccy_code $CFG(MISSING_ACCOUNT_CREATION.DFLT_CCY) \
			-reg_aff_id "" \
			-country_code $CFG(MISSING_ACCOUNT_CREATION.DFLT_COUNTRY_CODE) \
			-aff_id ""
		}
	}

	ob_log::write INFO {LOGIN: db-login cust_id=$LOGIN(cust_id)}
	return OB_OK
}



# Private procedure to write login history.
#
#   aff_id  - affiliate identifier
#   source  - channel source
#   returns - login status string (OB_OK denotes success)
#
proc ob_login::_write_history { aff_id source } {

	variable LOGIN
	if {[catch {ob_db::exec_qry ob_login::write_history \
		        $LOGIN(cust_id)\
		        $aff_id\
		        $source} msg]} {
		ob_log::write ERROR {LOGIN: write history - $msg}
		return OB_ERR_CUST_LOGIN_FAILED
	}

	return OB_OK

}


#--------------------------------------------------------------------------
# Logout
#--------------------------------------------------------------------------

# Logout.
# Creates a cookie string which contains cfg CUST_LOGGED_OUT_STR.
# The resultant cookie is either base64 or hexadecimal (see init).
# The package cache is reset to denote the customer has logged out.
#
#   status  - (opt) set login_status to this
#   returns - encrypted cookie containing logged out string
#
proc ob_login::logout { {status ""} } {

	variable CFG
	variable LOGIN

	if { $CFG(session_tracking) && [info exists LOGIN(session_id)] } {
		::ob_session::end $LOGIN(session_id)
	}

	# denote logged out
	_clear
	set LOGIN(cust_id)      ""
	set LOGIN(login_status) $status

	# encrypt logged out cookie
	# - if using b64, convert cookie to b64
	set cookie [blowfish encrypt -$CFG(login_key_type) $CFG(login_key) \
	                             -bin                  $CFG(logged_out_str)]
	if {$CFG(crypt_base) == "b64"} {
		set cookie [convertto b64 -hex $cookie]
	}

	ob_log::write DEBUG {LOGIN: encrypted cookie $cookie}
	return $cookie
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
#   cookie          - login cookie string
#   insecure_cookie - insecure cookie string
#   secure_only     - flag to specify if we are specifically only logging in
#                     from the secure cookie (used from apps like OXi)
#   returns         - login status string (OB_OK denotes success)
#
proc ob_login::check_cookie { cookie {insecure_cookie ""} {secure_only 0}} {

	variable CFG
	variable LOGIN

	# already attempted to login within this request
	if {![_can_login 0]} {
		ob_log::write DEBUG \
		    {LOGIN: repeated login (status=$LOGIN(login_status))}
		return $LOGIN(login_status)
	}

	# clear data
	_clear
	set LOGIN(critical) 0

	if {$CFG(func_insecure_cookie) && !$secure_only} {
		set LOGIN(login_status) [_decrypt_insecure_cookie $insecure_cookie]
		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			return $LOGIN(login_status)
		}
	}

	# decrypt cookie (details stored within package cache)
	set LOGIN(login_status) [_decrypt_cookie $cookie $secure_only]
	if {$LOGIN(login_status) != "OB_OK"} {
		_clear
		return $LOGIN(login_status)
	}

	if { $CFG(session_tracking) } {

		set LOGIN(login_status) [::ob_session::check $LOGIN(session_id)]
		if {$LOGIN(login_status) != "OB_OK"} {
			_clear
			return $LOGIN(login_status)
		}

	}

	# encrypt a new cookie (details store in package cache
	_encrypt_cookie

	if {$CFG(func_insecure_cookie)} {
		_encrypt_insecure_cookie
	}

	return $LOGIN(login_status)
}



# Check the insecure login cookie.
#
# This checks the given cookie using the insecure encryption key.
#
proc ob_login::check_insecure_cookie { cookie } {

	variable CFG
	variable LOGIN

	if {!$CFG(func_insecure_cookie)} {
		error "Login insecure cookie function is turned off."
	}

	# already attempted to login within this request
	if {![_can_login 0]} {
		ob_log::write DEBUG \
		    {LOGIN: repeated login (status=$LOGIN(login_status))}
		return $LOGIN(login_status)
	}

	# clear data
	_clear
	set LOGIN(critical) 0

	# decrypt cookie (details stored within package cache)
	set LOGIN(login_status) [_decrypt_insecure_cookie $cookie]
	if {$LOGIN(login_status) != "OB_OK"} {
		_clear
		return $LOGIN(login_status)
	}

	# encrypt a new cookie (details store in package cache
	_encrypt_insecure_cookie

	return $LOGIN(login_status)
}



# Private procedure to decrypt the login cookie.
# The unencrypted format of the login cookie must be -
#
#     if new cookie format: type|cust_id|pwd[|expiry]
#     if old cookie format: typecust_idpwd[|expiry]
#
# where:
#     new/old cookie format determined by cfg CUST_LOGIN_COOKIE_FMT
#     type    login type (pass'W'ord | pi'N')
#     cust_id customer identifier
#             9 zero padded number if using older cookie format
#     pwd     encrypted password or pin (depends on type)
#     expiry  optional cookie expiry time (YYYY-MM-DD HH:MM:SS)
#
# The encrypted cookie must be either base64 or hexadecimal (see init).
# The contents of the cookie are stored in the package cache.
#
# NB: The procedure does not get the cookie from a HTTP header or form
# argument. It is caller's responsibility to supply the cookie string.
#
#   cookie      - encrypted cookie string
#   returns     - login status string (OB_OK denotes success)
#
proc ob_login::_decrypt_cookie { cookie {secure_only 0}} {

	variable CFG
	variable LOGIN

	# get login keepalive, uses either cfg value or tControl.login_keepalive
	if {[set keepalive $CFG(login_keepalive)] == ""} {
		if {[set keepalive [ob_control::get login_keepalive]] == ""} {
			set keepalive 0
		}
	}

	# initially denote the customer as logged out
	set LOGIN(cust_id) ""
	set LOGIN(cookie)  $cookie

	# No cookie?
	ob_log::write DEBUG {Login Cookie Value: $cookie}

	if {$cookie == ""} {
		return OB_ERR_CUST_GUEST
	}

	if {$CFG(func_insecure_cookie) && !$secure_only &&
		$LOGIN(login_method) != "INSECURE_COOKIE"} {
		ob_log::write ERROR {LOGIN: Insecure cookie must be decrypted first}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# decrypt cookie string (hex result)
	if {[catch {
		set hex [blowfish decrypt \
			-$CFG(login_key_type) $CFG(login_key) -$CFG(crypt_base) $cookie]
	} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# convert to binary
	if {[catch {set bin [hextobin $hex]} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# logged out?
	if {$bin == $CFG(logged_out_str)} {
		return OB_ERR_CUST_GUEST
	}

	# If HMAC-SHA1 is enabled, verify the cookie
	if {$CFG(cookie_hmac)} {

		set hmac_exp {^([0-9A-Za-z+/=]+)\|(.*)$}

		if {![regexp $hmac_exp $bin all hmac_cookie data]} {
			ob_log::write WARNING {LOGIN: failed to parse hmac in cookie: $bin}
			return OB_ERR_CUST_BAD_COOKIE
		}

		set hmac_data [hmac-sha1 -string $CFG(cookie_hmac_key) -string $data]
		set hmac_data [convertto b64 -hex $hmac_data]
		if {$hmac_cookie != $hmac_data} {
			ob_log::write WARNING {LOGIN: cookie hmac does not match calculated hmac}
			return OB_ERR_CUST_BAD_COOKIE
		}

		set bin $data
	}


	# build regexp expression for parsing the cookie string, dependent on
	# cfg CUST_LOGIN_COOKIE_FMT
	if {$CFG(login_cookie_fmt) == "NEW"} {

		set    exp {^}
		append exp {([WN])}
		append exp {\|([0-9]+)}

		if { $CFG(session_tracking) } {
			append exp {\|([0-9]+)}
		}

		append exp {\|([0-9A-Za-z+/=]+)}
		append exp {(?:\|([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+))?}
		append exp {(?:\|(....-..-.. ..:..:..))?}
		append exp {$}

	} else {

		set    exp {^}
		append exp {([WN])}
		append exp {([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])}
		append exp {([0-9A-Za-z+/=]+)}
		append exp {(?:\|([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+))?}
		append exp {(?:\|(?:(....-..-.. ..:..:..)))?}
		append exp {$}

		ob_log::write WARNING {LOGIN: _decrypt_cookie with older regexp}

	}

	if {
		$CFG(session_tracking)
			? ![regexp $exp $bin all type cust_id session_id pwd ipaddr expiry]
			: ![regexp $exp $bin all type cust_id            pwd ipaddr expiry]
	} {
		ob_log::write ERROR {LOGIN: failed to parse cookie - $bin}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# Check the IP address is correct if enabled
	if {$CFG(cookie_ip_addr)} {
		set req_ipaddr [reqGetEnv REMOTE_ADDR]
		if {$ipaddr != $req_ipaddr} {
			ob_log::write ERROR {LOGIN: IP address $req_ipaddr does not match cookie $ipaddr}
			return OB_ERR_CUST_BAD_COOKIE
		}
	}

	# We don't check secure cookie expiry if using insecure cookie, however
	# if we are just doing a secure cookie login, then we have to
	if {!$CFG(func_insecure_cookie) || $secure_only} {
		# expiry date is optional (save space)
		if {$expiry != ""} {
			set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S" -gmt $CFG(cookie_gmt)]
			if {$now > $expiry} {
				return OB_ERR_CUST_EXPIRED_COOKIE
			}
		} elseif {$keepalive > 0} {
			ob_log::write WARNING {LOGIN: No cookie expiry but keepalive is enabled}
			return OB_ERR_CUST_EXPIRED_COOKIE
		} else {
			ob_log::write WARNING {LOGIN: decrypt cookie, no expiry}
		}
	}

	if { $CFG(session_tracking) } {
		set LOGIN(session_id) $session_id
	}

	# set login type & password/pin
	# - if b64, convert a password to hexadecimal
	set LOGIN(type) $type
	switch -- $type {
		"W" {
			if {$CFG(crypt_base) == "b64"} {
				set LOGIN(pwd) [convertto hex -b64 $pwd]
			} else {
				set LOGIN(pwd) $pwd
			}
		}
		"N" {
			set LOGIN(pin)  $pwd
		}
	}

	# set cust_id (denotes customer has logged in)
	set LOGIN(login_method) COOKIE
	set LOGIN(cust_id) [string trimleft $cust_id 0]

	# log the decrypted cookie (if log level is set)
	set sym_level [ob_log::get_sym_level]
	if {$sym_level == "DEV" || $sym_level == "DEBUG"} {
		if {$CFG(login_cookie_fmt) == "NEW"} {
			if { $CFG(session_tracking) } {
				set cookie $type|$cust_id|$session_id|$pwd|$expiry
			} else {
				set cookie $type|$cust_id|$pwd|$expiry
			}
		} else {
			set cookie $type$cust_id$pwd|$expiry
		}
		ob_log::write DEBUG {LOGIN: decrypted cookie $cookie}
	}

	return OB_OK
}



# Private procedure to decrypt the insecure login cookie
#
# The unencrypted format of the login cookie must be -
#
#     format: [HMAC-SHA1|]cust_id[|extra_data][|expiry]
#
proc ob_login::_decrypt_insecure_cookie { cookie } {

	variable CFG
	variable LOGIN

	# get login keepalive, uses either cfg value or tControl.login_keepalive
	if {[set keepalive $CFG(login_keepalive)] == ""} {
		if {[set keepalive [ob_control::get login_keepalive]] == ""} {
			set keepalive 0
		}
	}

	# initially denote the customer as logged out
	set LOGIN(cust_id) ""
	set LOGIN(cookie)  $cookie

	ob_log::write DEBUG {Insecure Login Cookie Value: $cookie}
	# No cookie?
	if {$cookie == ""} {
		return OB_ERR_CUST_GUEST
	}

	# decrypt cookie string (hex result)
	if {[catch {
		set hex [blowfish decrypt \
			-$CFG(insecure_key_type) $CFG(insecure_key) -$CFG(crypt_base) $cookie]
	} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# convert to binary
	if {[catch {set bin [hextobin $hex]} msg]} {
		ob_log::write ERROR {LOGIN: $msg}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# Fix for the usernames that include foreign characters
	set bin [encoding convertfrom utf-8 $bin]

	# If HMAC-SHA1 is enabled, verify the cookie
	if {$CFG(cookie_hmac)} {

		set hmac_exp {^([0-9A-Za-z+/=]+)\|(.*)$}

		if {![regexp $hmac_exp $bin all hmac_cookie data]} {
			ob_log::write WARNING {LOGIN: failed to parse hmac in insecure cookie: $bin}
			return OB_ERR_CUST_BAD_COOKIE
		}

		set hmac_data [hmac-sha1 -string $CFG(cookie_hmac_key) -string $data]
		set hmac_data [convertto b64 -hex $hmac_data]
		if {$hmac_cookie != $hmac_data} {
			ob_log::write WARNING {LOGIN: insecure cookie hmac does not match calculated hmac}
			return OB_ERR_CUST_BAD_COOKIE
		}

		set bin $data
	}

	# build regexp expression for parsing the cookie string

	if {[OT_CfgGet DO_LATIN_UNICODE_CHECK 0]} {
		set foreign_chars [join [OT_CfgGet FOREIGN_CHARACTERS {}] {}]
	} else {
		set foreign_chars {}
	}


	# begin
	set    exp {^}
	# cust_id
	append exp {([0-9]+)}
	# acct_id
	append exp {\|([0-9]+)}
	# other items
	foreach item $CFG(insecure_cookie_items) {
		set pattern $CFG(insecure_cookie_pattern,$item)
		regsub -all "%\{FOREIGN_CHARS\}" $pattern $foreign_chars pattern
		append exp "\\|($pattern)"
	}
	# expiry
	append exp {(?:\|(?:(....-..-.. ..:..:..)))?}
	# end
	append exp {$}

	 if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) eq "UTF-8")} {
		set cookie_string [encoding convertfrom utf-8 $bin]
	} else {
		set cookie_string $bin
	}

	# parse cookie
	if {![eval [list regexp $exp $cookie_string all cust_id acct_id] \
	           $CFG(insecure_cookie_items) \
	           [list expiry]]} {
		ob_log::write ERROR {LOGIN: failed to parse insecure cookie - $bin}
		return OB_ERR_CUST_BAD_COOKIE
	}

	# expiry date is optional (save space)
	if {$expiry != ""} {
		set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S" -gmt $CFG(cookie_gmt)]
		if {$now > $expiry} {
			ob_log::write WARNING {LOGIN: Insecure cookie has expired}
			return OB_ERR_CUST_EXPIRED_COOKIE
		}
	} elseif {$keepalive > 0} {
		ob_log::write WARNING {LOGIN: No cookie expiry but keepalive is enabled}
		return OB_ERR_CUST_EXPIRED_COOKIE
	} else {
		ob_log::write WARNING {LOGIN: decrypt insecure cookie, no expiry}
	}

	set LOGIN(login_method) INSECURE_COOKIE
	set LOGIN(cust_id)  $cust_id
	set LOGIN(acct_id)  $acct_id
	foreach item $CFG(insecure_cookie_items) {
		set LOGIN($item) [set $item]
	}

	return OB_OK
}



# Private procedure to encrypt a login cookie (see _encrypt_cookie for
# format).
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
proc ob_login::_encrypt_cookie args {

	variable CFG
	variable LOGIN

	# get login keepalive, uses either cfg value or tControl.login_keepalive
	if {[set keepalive $CFG(login_keepalive)] == ""} {
		if {[set keepalive [ob_control::get login_keepalive]] == ""} {
			set keepalive 0
		}
	}

	# set expiry time if a login keepalive
	if {$keepalive > 0} {
		set t      [expr {[clock seconds] + $keepalive}]
		set expiry |[clock format $t -format "%Y-%m-%d %H:%M:%S" -gmt $CFG(cookie_gmt)]
	} else {
		set expiry ""
		ob_log::write WARNING {LOGIN: encrypt cookie, no expiry}
	}

	# if using b64 encryption, convert password to base 64
	if {$LOGIN(type) == "W" && $CFG(crypt_base) == "b64"} {
		set pwd [convertto b64 -hex $LOGIN(pwd)]
	} elseif {$LOGIN(type) == "W"} {
		set pwd $LOGIN(pwd)
	} else {
		set pwd $LOGIN(pin)
	}

	if {$CFG(cookie_ip_addr)} {
		set ipaddr "|[reqGetEnv REMOTE_ADDR]"
	} else {
		set ipaddr ""
	}

	# build unencrypted cookie, format dependent on cfg CUST_LOGIN_COOKIE_FMT
	if { $CFG(login_cookie_fmt) == "NEW" } {

		if { $CFG(session_tracking) } {
			set LOGIN(cookie) \
				$LOGIN(type)|$LOGIN(cust_id)|$LOGIN(session_id)|$pwd$ipaddr$expiry
		} else {
			set LOGIN(cookie) $LOGIN(type)|$LOGIN(cust_id)|$pwd$ipaddr$expiry
		}

	} else {
		set LOGIN(cookie) [format "%s%09d%s%s"\
		    $LOGIN(type)\
		    $LOGIN(cust_id)\
		    $pwd\
		    $ipaddr\
		    $expiry]
		ob_log::write WARNING {LOGIN: _encrypt_cookie with older format}
	}

	# If HMAC-SHA1 is enabled, stamp the cookie with it
	if { $CFG(cookie_hmac) } {

		set hmac [hmac-sha1 -string $CFG(cookie_hmac_key) -string $LOGIN(cookie)]
		set hmac [convertto b64 -hex $hmac]

		# We place the hmac in front to give better randomness to blowfish
		set LOGIN(cookie) "$hmac|$LOGIN(cookie)"
	}

	# encrypt cookie
	set LOGIN(cookie) [blowfish encrypt \
		-$CFG(login_key_type) $CFG(login_key) -bin $LOGIN(cookie)]

	# - if using b64, convert cookie to b64
	if {$CFG(crypt_base) == "b64"} {
		set LOGIN(cookie) [convertto b64 -hex $LOGIN(cookie)]
	}

	ob_log::write DEBUG {LOGIN: encrypted cookie $LOGIN(cookie)}
}


# Private procedure to encrypt the insecure cookie.
#
# The unencrypted format of the login cookie must be -
#
#     format: [HMAC-SHA1|]cust_id[|extra_data][|expiry]
#
proc ob_login::_encrypt_insecure_cookie args {

	variable CFG
	variable LOGIN

	# get login keepalive, uses either cfg value or tControl.login_keepalive
	if {[set keepalive $CFG(login_keepalive)] == ""} {
		if {[set keepalive [ob_control::get login_keepalive]] == ""} {
			set keepalive 0
		}
	}

	# set expiry time if a login keepalive
	if {$keepalive > 0} {
		set t      [expr {[clock seconds] + $keepalive}]
		set expiry |[clock format $t -format "%Y-%m-%d %H:%M:%S" -gmt $CFG(cookie_gmt)]
	} else {
		set expiry ""
		ob_log::write WARNING {LOGIN: encrypt cookie, no expiry}
	}

	set LOGIN(insecure_cookie) $LOGIN(cust_id)
	append LOGIN(insecure_cookie) "|[get acct_id]"
	foreach item $CFG(insecure_cookie_items) {
		append LOGIN(insecure_cookie) "|[get $item]"
	}
	append LOGIN(insecure_cookie) $expiry

	# If HMAC-SHA1 is enabled, stamp the cookie with it
	if { $CFG(cookie_hmac) } {

		set hmac [hmac-sha1 -string $CFG(cookie_hmac_key) -string $LOGIN(insecure_cookie)]
		set hmac [convertto b64 -hex $hmac]

		# We place the hmac in front to give better randomness to blowfish
		set LOGIN(insecure_cookie) "$hmac|$LOGIN(insecure_cookie)"
	}

	# utf-8 conversion for foreign characters.
	#Only needs to be done if blowfish is called with -bin
	set LOGIN(insecure_cookie) [encoding convertto utf-8 $LOGIN(insecure_cookie)]

	# encrypt cookie
	set LOGIN(insecure_cookie) [blowfish encrypt \
		-$CFG(insecure_key_type) $CFG(insecure_key) -bin $LOGIN(insecure_cookie)]

	# - if using b64, convert cookie to b64
	if {$CFG(crypt_base) == "b64"} {
		set LOGIN(insecure_cookie) [convertto b64 -hex $LOGIN(insecure_cookie)]
	}
}



#--------------------------------------------------------------------------
# Update password/pin
#--------------------------------------------------------------------------

# Update the customer's password.
# The procedure was originally part of acct_qry.tcl; which created a new cookie
# based on the older format, causing login failure on subsequent requests.
#
# With the procedure being part of the login package, it allows the
# construction of cookie in the new format (unless performed a PIN login),
# The new cookie is stored in the package cache
#
# NB: The procedure does not get the parameters from a HTML/WML form, play
# any templates or set the cookie. It is caller's responsibility to get and
# supply the details, set the cookie and play any templates.
#
#   old      - old password (unencrypted)
#   new      - new password (unencrypted)
#   vfy_new  - new password verification (unencrypted)
#   temp_pwd - temp' password (default: N)
#   in_tran  - in transaction flag (default: 0)
#              if non-zero, the caller must begin, rollback & commit
#              if zero, then must be called outside a transaction
#   no_old   - no old pwd provided
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::upd_pwd { old new vfy_new {temp_pwd N} {in_tran 0} {no_old 0}} {

	variable LOGIN
	variable CFG

	ob_log::write DEBUG {LOGIN: upd_pwd in_tran=$in_tran}

	# check if guest
	if {[is_guest]} {
		if {[info exists LOGIN(login_status)] && \
		        $LOGIN(login_status) != "OB_OK"} {
			return $LOGIN(login_status)
		}
		return [set LOGIN(login_status) OB_ERR_CUST_GUEST]
	}

	# get current password/username
	# - might of performed a PIN login, where the password/username is unknown
	get pwd
	get password_salt

	if {$CFG(pwd_case_insensitive)} {
		set old     [string toupper $old]
		set new     [string toupper $new]
		set vfy_new [string toupper $vfy_new]
	}


	# encrypt supplied passwords
	if {$no_old} {
		set enc_old $LOGIN(pwd)
	} else {
		set enc_old [ob_crypt::encrypt_password $old $LOGIN(password_salt)]
	}
	set enc_new [ob_crypt::encrypt_password $new $LOGIN(password_salt)]

	if {!$no_old} {
		# check supplied passwords
		if {$enc_old != $LOGIN(pwd)} {
			return OB_ERR_CUST_BAD_CPWD
		}
		if {$enc_old == $enc_new} {
			return OB_ERR_CUST_PWD_MATCH
		}
	}

	set status [ob_chk::pwd $new $vfy_new $LOGIN(username)]

	if {$status != "OB_OK"} {
		return $status
	}

	# start update
	if {!$in_tran} {
		ob_db::begin_tran
	}

	# update the password
	if {[catch {
		ob_db::exec_qry ob_login::upd_pwd $LOGIN(username) \
		                                  $enc_old \
		                                  $enc_new \
		                                  $temp_pwd
	} msg]} {

		if {!$in_tran} {
			ob_db::rollback_tran
		}
		ob_log::write ERROR {LOGIN: $msg}
		return [_get_err_code $msg OB_ERR_CUST_PWD_FAILED]
	}

	# commit update
	if {!$in_tran} {
		ob_db::commit_tran
	}

	# construct a new login cookie
	set LOGIN(pwd) $enc_new
	if {$LOGIN(type) == "W"} {
		_encrypt_cookie
	}

	# force an update of customer information
	force_update

	ob_log::write INFO {REG: updated password cust_id=$LOGIN(cust_id)}
	return OB_OK
}



# Update the customer's PIN.
# The procedure was originally part of acct_qry.tcl; which created a new cookie
# based on the older format, causing login failure on subsequent requests.
#
# With the procedure being part of the login package, it allows the
# construction of cookie in the new format (unless performed a password login),
# The new cookie is stored in the package cache
#
# NB: The procedure does not get the parameters from a HTML/WML form, play
# any templates or set the cookie. It is caller's responsibility to get and
# supply the details, set the cookie and play any templates.
#
#   old      - old PIN/password (unencrypted)
#   new      - new PIN (unencrypted)
#   vfy_new  - new PIN verification (unencrypted)
#   type     - is old a password (W) or pin (N) (default: N)
#   min      - minimum length of the new PIN (default: 6)
#   max      - maximum length of the new PIN (default: 8)
#   in_tran  - in transaction flag (default: 0)
#              if non-zero, the caller must begin, rollback & commit
#              if zero, then must be called outside a transaction
#   returns  - login status string (OB_OK denotes success)
#
proc ob_login::upd_pin { old new vfy_new {type N} {min 6} {max 8} \
	                   {in_tran 0} } {

	variable LOGIN

	ob_log::write DEBUG {LOGIN: upd_pin type=$type in_tran=$in_tran}

	# check if guest
	if {[is_guest]} {
		if {[info exists LOGIN(login_status)] && \
		        $LOGIN(login_status) != "OB_OK"} {
			return $LOGIN(login_status)
		}
		return [set LOGIN(login_status) OB_ERR_CUST_GUEST]
	}

	# get current pin/acct_no & pwd/username
	# - might of performed a PWD/PIN login, where the details are unknown
	get pin
	get pwd

	# encrypt pin/password
	set enc_old ""
	set enc_pwd ""
	set enc_new [ob_crypt::encrypt_pin $new]

	# check new pins
	set status [ob_chk::pin $new $vfy_new $min $max]
	if {$status != "OB_OK"} {
		return $status
	}

	# check old/current pin
	if {$type == "N"} {
		set enc_old [ob_crypt::encrypt_pin $old]
		if {$enc_old != $LOGIN(pin)} {
			return OB_ERR_CUST_BAD_CPIN
		}
		if {$enc_old == $enc_new} {
			return OB_ERR_CUST_PIN_MATCH
		}

	# check old/current password
	} else {
		set enc_pwd [ob_crypt::encrypt_password $old $LOGIN(password_salt)]
		if {$enc_pwd != $LOGIN(pwd)} {
			return OB_ERR_CUST_BAD_CPWD
		}
	}

	# start update
	if {!$in_tran} {
		ob_db::begin_tran
	}

	# update the pin
	if {[catch {ob_db::exec_qry ob_login::upd_pin $LOGIN(acct_no)\
		        $enc_old $enc_pwd\
		        $enc_new $min $max} msg]} {

		if {!$in_tran} {
			ob_db::rollback_tran
		}
		ob_log::write ERROR {LOGIN: $msg}
		return [_get_err_code $msg OB_ERR_CUST_PIN_FAILED]
	}

	# commit update
	if {!$in_tran} {
		ob_db::commit_tran
	}

	# construct a new login cookie
	set LOGIN(pin) $enc_new
	if {$LOGIN(type) == "N"} {
		_encrypt_cookie
	}

	# force an update of customer information
	force_update

	ob_log::write INFO {REG: updated PIN cust_id=$LOGIN(cust_id)}
	return OB_OK
}



# Updates the customer's language in tCustomer.lang
#
#   lang  - new language
#
proc ob_login::upd_lang {lang} {
	variable LOGIN

	ob_log::write DEBUG {LOGIN: upd_lang lang=$lang}

	# check if guest
	if {[is_guest]} {
		ob_log::write ERROR {LOGIN: Unable to update guest's lang}
		return
	}

	if {[catch {ob_db::exec_qry ob_login::upd_lang $lang $LOGIN(cust_id)} msg]} {
		ob_log::write ERROR {LOGIN: Unable to update customer's lang: $msg}
		return
	}
	ob_log::write INFO {LOGIN: Updated lang to $lang for cust_id $LOGIN(cust_id)}
}



#--------------------------------------------------------------------------
# Login Utilities
#--------------------------------------------------------------------------

# Get the login UID.
# The UID is taken from pGenLoginUID or [clock seconds] if
# CUST_UID_IS_TIME cfg is enabled.
# The procedure should not be called within a transaction. An error condition
# will be raised if the pGenLoginUID does not return once row.
#
#   returns - login UID
#
proc ob_login::get_uid args {

	variable CFG

	# use time for UID
	if {$CFG(uid_is_time)} {
		return [clock seconds]
	}

	# use pGenLoginUID
	set rs    [ob_db::exec_qry ob_login::get_uid]
	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set uid [db_get_coln $rs 0 0]
		ob_db::rs_close $rs
		return $uid
	} else {
		ob_db::rs_close $rs
		error "pGenLoginUID returned $nrows rows"
	}
}



# Get the current UID
#
#   username   - username
#   returns    - uid or -1 on error
#
proc ob_login::get_cur_uid {username} {

	set rs    [ob_db::exec_qry ob_login::get_cur_uid $username]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set uid [db_get_coln $rs 0 0]
		ob_db::rs_close $rs
		return $uid
	} else {
		ob_db::rs_close $rs
		return -1
	}
}



# Get the current UID
#
#   name     - cfg name
#   returns  - config value or "" if not found
#
proc ob_login::get_cfg {name} {

	variable CFG

	set cfg_value ""

	if {[info exists CFG($name)] && $CFG($name) != ""} {
		set cfg_value $CFG($name)

	# if login keepalive is not found then use tControl.login_keepalive
	} elseif {$name == "login_keepalive"} {
		if {[set cfg_value [ob_control::get login_keepalive]] == ""} {
			set cfg_value 0
		}
	}

	return $cfg_value
}



# Private procedure to get the symbolic error code from a stored procedure
# exception message.
#
#   msg     - exception message
#   dflt    - default error code if an unknown code within message
#             (default: OB_ERR_CUST_LOGIN_FAILED)
#   returns - symbolic error code
#
proc ob_login::_get_err_code { msg {dflt OB_ERR_CUST_LOGIN_FAILED} } {

	variable LOGIN
	variable ERR_CODE

	if {[regexp {AX([0-9][0-9][0-9][0-9])} $msg all err_code]} {
		if {[info exists ERR_CODE($err_code)]} {

			# change PIN login error code?
			if {[info exists LOGIN(type)] && $LOGIN(type) == "N" &&
			        $ERR_CODE($err_code) == "OB_ERR_CUST_BAD_UNAME"} {
				return OB_ERR_CUST_BAD_ACCT
			} else {
				return $ERR_CODE($err_code)
			}
		}
	}

	return $dflt
}



# Private procedure to determine if a customer can login within the scope
# of the current request.
#
#   returns  - non-zero if customer can login, zero if not
#
proc ob_login::_can_login args {

	variable LOGIN

	if {[set status_exists [info exists LOGIN(login_status)]]} {
		set status $LOGIN(login_status)
	}

	if {[_auto_reset]
	        || !$status_exists
	        || ($status == "OB_OK" && ![info exists LOGIN(critical)])} {
		return 1
	}

	return 0
}
