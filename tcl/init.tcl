# ==============================================================
# $Id: init.tcl,v 1.1.1.1.2.1 2011/11/03 13:33:14 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

# ==============================================================
# ~/git_src/induction/training/admin/tcl/init.tcl
# ==============================================================

set admin_screens 1

set vrsn [info tclversion]

set tcl_lib [file join [OT_CfgGet TCL /opt/tcl${vrsn}] lib tcl${vrsn}]

package require msgcat

#
# Normalize TCL_SCRIPT_DIR, so that we won't have problems finding packages
# as they're loaded dynamcially after the app has been initialised.
#
set tcl_dir [file normalize [OT_CfgGet TCL_SCRIPT_DIR tcl]]

set xtn [OT_CfgGet TCL_XTN tcl]

OT_LogWrite 1 "Tcl version   is $vrsn"
OT_LogWrite 1 "Tcl library   is $tcl_lib"
OT_LogWrite 1 "Tcl directory is $tcl_dir"

lappend auto_path $tcl_dir/shared_tcl

lappend auto_path $tcl_dir/ovs
lappend auto_path $tcl_dir/OXi

lappend auto_path $tcl_dir/core
lappend auto_path [OT_CfgGet TCL_SCRIPT_DIR tcl]/shared_core

lappend auto_path $tcl_dir/handlers


OT_LogWrite 4 "auto_path=$auto_path"

#source $tcl_lib/package.tcl
#package unknown tclPkgUnknown

#
# Some packages cannot be loaded lazily, so we make sure they are sourced and
# loaded here.
#
if { [OT_CfgGetTrue LIB_NEED_SOAP] } {
	package require SOAP
}

package require tdom
package require http

http::config


package require util_util
set ob_util_init [list "ob_util::init"]
if {[set perform_proxy_name [OT_CfgGet PERFORM_USE_PROXY ""]] != ""} {
	lappend ob_util_init -proxy,${perform_proxy_name},host [OT_CfgGet ${perform_proxy_name}.HOST ""]
	lappend ob_util_init -proxy,${perform_proxy_name},port [OT_CfgGet ${perform_proxy_name}.PORT ""]
}
eval $ob_util_init

package require util_log
package require util_log_compat
ob_log::init

package require util_db
ob_db::init

package require util_gc

# Crypt utilities
package require util_crypt
ob_crypt::init

# validation
package require util_validate
ob_chk::init

# register some validation checks
ob_chk::register "NUMERIC14"  ob_chk::_re {^[0-9]{14}$}
ob_chk::register "ALPHANUM_1" ob_chk::_re {^[A-Za-z0-9_-]+$}
ob_chk::register "ALPHANUM_2" ob_chk::_re {^[A-Za-z0-9 #.,'/-]+$}
ob_chk::register "ALPHANUM_3" ob_chk::_re {^[A-Za-z0-9 #&.,'/-]+$}
ob_chk::register "ALPHANUM_4" ob_chk::_re {^[A-Za-z0-9_+-]+$}

if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {
	package require util_email
	ob_email::init
}

# need price package for decimal odds auto chart lookup
package require util_price
ob_price::init

# need currency conversion for async
package require util_exchange
ob_exchange::init

if { [OT_CfgGetTrue ENTROPAY] } {
	source $tcl_dir/shared_tcl/entropay.${xtn}
	source $tcl_dir/entropay.${xtn}
}




package require cust_login
package require cust_util
ob_cust::init

package require util_esc

if {[OT_CfgGetTrue FUNC_XSYS_MGMT]} {
	package require xsys 1.0
	::xsys::init
}

package require bet_bet

source $tcl_dir/util.${xtn}
source $tcl_dir/shared_tcl/err.${xtn}
source $tcl_dir/shared_tcl/multipart.${xtn}
source $tcl_dir/shared_tcl/mlang.${xtn}
source $tcl_dir/shared_tcl/util.${xtn}
source $tcl_dir/shared_tcl/autosettler.${xtn}

source $tcl_dir/shared_tcl/payment_MB.${xtn}

source $tcl_dir/shared_tcl/payment_ENVO.${xtn}
payment_ENVO::init

source $tcl_dir/shared_tcl/click_and_buy.${xtn}
ob_clickandbuy::init


source $tcl_dir/shared_tcl/monitor/monitor-compat.${xtn}

if { [OT_CfgGetTrue MONITOR] } {
	package require monitor_compat  1.0 
   }





# Risk Guardian
if {[OT_CfgGet ENABLE_RISKGUARDIAN 0]} {
	source $tcl_dir/shared_tcl/trustmarque.${xtn}
	source $tcl_dir/shared_tcl/risk_guardian.${xtn}
	riskGuardian::init
}

# URN Customer Matching
if {[OT_CfgGetTrue CUST_MATCHER_ENABLED]} {
	source $tcl_dir/shared_tcl/util/db-compat.${xtn}
	package require util_db_compat
	source $tcl_dir/shared_tcl/cust_matcher/cust_matcher.${xtn}
	cust_matcher::init
}


if { [OT_CfgGet FUNC_OVS 0] && [OT_CfgGet FUNC_OVS_USE_SERVER 0]} {

	package require ovs_ovs
	source [OT_CfgGet OVS_QUEUE_CALLBACK_PATH ""]
}

# using the OpenBet Office?
set OFFICE [OT_CfgGetTrue FUNC_OFFICE]
if {$OFFICE} {
	lappend auto_path $tcl_dir/office_lib
	package require office
	ob_office::init -office_lib_html office_lib
}

if {[OT_CfgGetTrue FUNC_MENU_CHAT]} {
	lappend auto_path $tcl_dir/chat
	lappend auto_path $tcl_dir/shared_chat
	package require ADMIN::Chat
	package require ob_chat
	ADMIN::Chat::init
}

source $tcl_dir/shared_tcl/net/socket.${xtn}

package require util_throttle

package require util_appcontrol

if {[OT_CfgGetTrue FUNC_CC_CHECKS_ON_REMOVE]} {
	source $tcl_dir/shared_tcl/cc_change_check.${xtn}
	cc_change::init
}

if {[OT_CfgGetTrue FUNC_RESTRICT_EMAIL]} {
	package require util_restrict_email
}

if {[OT_CfgGetTrue FUNC_OXI_PUSH_SERVER]} {
	package require oxipushserver
}

if {[OT_CfgGet FUNC_CUST_STATEMENTS 0] && [OT_CfgGet POSTSCRIPT_STMTS 0]} {
	source [OT_CfgGet PS_TEMPLATE_DIR][OT_CfgGet PS_TCL_FILE]
}

source $tcl_dir/shared_tcl/payment_multi.${xtn}
payment_multi::init

source $tcl_dir/shared_tcl/pmt_util.${xtn}
pmt_util::init

# ob_control - interface to tControl
package require util_control
ob_control::init

package require core::args
core::args::init

package require core::controller
core::controller::init\
        -strict_mode     [OT_CfgGet CONTROLLER_STRICT_MODE 0]


core::view::init \
	-strict_mode     0 \
	-default_charset UTF-8 \
		
source $tcl_dir/handlers/training/training.tcl
# ob_training - interface to training module
if {[OT_CfgGet FUNC_MENU_TRAINING 0]} {
	source $tcl_dir/training/training.tcl
}

source $tcl_dir/war_games/war_game.tcl


set ::MAIN_INIT_COMPLETE 0

#
# ----------------------------------------------------------------------------
# Application server one-off initialisation
# ----------------------------------------------------------------------------
#
proc main_init {} {

	ob::log::write 1 {INIT: main_init begin}

	global CHARSET
	global USE_COMPRESSION
	global EMAIL_TYPES
	global MAIN_INIT_COMPLETE
	global OFFICE

	set MAIN_INIT_COMPLETE 0

	main_aux_logs

	#
	# If DB_LAZY_CONN is set true, we arrange to connect to the database
	# when needed, rather than right now
	#
	if {[OT_CfgGet DB_LAZY_CONN 0]} {
		trace variable ::DB r main_db_conn
	} else {
		main_db_conn
	}

	set USE_COMPRESSION [OT_CfgGetTrue USE_COMPRESSION]

	set ::MEM_BRK_START [asGetBrk]
	set ::MEM_BRK_CUR   $::MEM_BRK_START

	set max_mem_use [OT_CfgGet MAX_MEM_USE 0]

	regsub -all {M} $max_mem_use {*1024K} max_mem_use
	regsub -all {K} $max_mem_use {*1024}  max_mem_use

	set ::MEM_MAX_USE [expr 1*$max_mem_use]

	#
	# Per-site functionality
	#
	tpSetVar FuncMultiCCY       -global [OT_CfgGetTrue FUNC_MULTI_CCY]
	tpSetVar FuncMultiLang      -global [OT_CfgGetTrue FUNC_MULTI_LANG]
	tpSetVar FuncChannels       -global [OT_CfgGetTrue FUNC_CHANNELS]
	tpSetVar FuncTeamPlayer     -global [OT_CfgGetTrue FUNC_TEAM_PLAYER]
	tpSetVar FuncIdCardSearch   -global [OT_CfgGetTrue FUNC_ID_CARD_SEARCH]
	tpSetVar FuncUKBankInfo     -global [OT_CfgGetTrue FUNC_UK_BANK_INFO]
	tpSetVar FuncPersQuest1     -global [OT_CfgGetTrue FUNC_PERS_QUEST_1]
	tpSetVar FuncPersQuest2     -global [OT_CfgGetTrue FUNC_PERS_QUEST_2]
	tpSetVar FuncMemorableDate  -global [OT_CfgGetTrue FUNC_MEMORABLE_DATE]
	tpSetVar FuncPaymentQuery   -global [OT_CfgGetTrue FUNC_PAYMENT_QUERY]
	tpSetVar FuncNewsLocation   -global [OT_CfgGetTrue FUNC_NEWS_LOCATIONS]
	tpSetVar FuncDimensions     -global [OT_CfgGetTrue FUNC_NEWS_DIMENSIONS]
	tpSetVar FuncBankAcctUpd    -global [OT_CfgGet FUNC_BANK_ACCT_UPD     0]
	tpSetVar FuncShowDDId       -global [OT_CfgGetTrue FUNC_SHOW_DD_ID]

	# Part of the OpenBet Office
	tpSetVar FuncOffice -global $OFFICE

	#
	# Global variable and site bindings
	#
	set CHARSET [OT_CfgGet HTML_CHARSET "iso8859-1"]

	tpBindString CGI_URL      -global [OT_CfgGet CGI_URL]
	tpBindString CHARSET      -global $CHARSET
	tpBindString BgColour     -global [OT_CfgGet BG_COLOUR {#3333CC}]

	#
	# Map request URL actions to Tcl calls
	#
	asSetAct restart                    asRestart
	asSetAct get_stats                  get_stats
	asSetAct stylesheet                 {sb_null_bind admin.css}
	asSetAct print_stylesheet           {sb_null_bind print.css}
	asSetAct stylesheet_splash          {sb_null_bind splash.css}
	asSetAct war_game_stylesheet		{sb_null_bind war_games/styles.css}
	asSetAct go_popup_calendar          {sb_null_bind calendar.html}
	asSetAct go_popup_calendar_js       {sb_null_bind calendar.js}
	asSetAct GoMenubar                  {sb_null_bind menu_bar.html}
	asSetAct GoMenu                     {sb_null_bind menu.html}
	asSetAct ShowLogo                   ADMIN::MENU::show_logo
	asSetAct GoBottomBar                {sb_null_bind bottom_bar.html}
	asSetAct GoMain                     {sb_null_bind main_area.html}
	asSetAct DynText                    {sb_null_bind dynamic_text.js}
	asSetAct GetAppStatus               get_application_status
	asSetAct auto_complete_style        {sb_null_bind auto_complete.css}
	asSetAct auto_complete_js           {sb_null_bind auto_complete.js}
	asSetAct list_js                    {sb_null_bind list.js}
	if { [OT_CfgGetTrue FUNC_REG_QAS_LOOKUP] } {
		asSetAct qasearch_js                {sb_null_bind qasearch.js}
	}

	# Allows pre-upgrade PMT jrnl transactions to be viewed.
	asSetAct ADMIN::TXN::PMT::GoTxn     ADMIN::TXN::GPMT::GoTxn

	OB_gen_payment::prepare_gen_pmt_qrys

	#
	# External Games
	#
	if {[OT_CfgGetTrue FUNC_XGAME]} {
		xgame_init
	}

	if {[OT_CfgGetTrue ENTROPAY]} {
		entropay::init
	}

	if {[OT_CfgGet FUNC_PAYPAL 0]} {
		ob_paypal::init
	}

	if {[OT_CfgGet FUNC_KYC 0]} {
		ob_kyc::init
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		BETFAIR::INT::init
		BETFAIR::UTILS::init

		BETFAIR::LIAB::init
	}

	# Child throttling
	ob_throttle::init

	foreach {email_type email_id} [OT_CfgGet EMAIL_TYPES ""] {
		set ::EMAIL_TYPES($email_type) $email_id
	}

	verification_check::verification_init

	# Initialise new crypto settings (if necessary)
	if {![OT_CfgGet ENCRYPT_FROM_CONF 0]} {
		cryptoAPI::init
	}

	# Initialize External Systems management module
	if {[OT_CfgGetTrue FUNC_XSYS_MGMT]} {
		ADMIN::XSYS_MGMT::init
	}


	#
	# Free bets
	#
	asSetAct GoTriggerTypesList go_trigger_type_list
	asSetAct GoTriggerType      go_trigger_type
	asSetAct GoAddTType         go_add_trigger_type
	asSetAct DoTriggerType      do_trigger_type

	asSetAct GoOffersList       go_offer_list
	asSetAct GoOffer            go_offer
	asSetAct GoAddOffer         go_add_offer
	asSetAct DoOffer            do_offer

	asSetAct GoAddTrigger       go_add_trigger
	asSetAct GoTrigger          go_trigger
	asSetAct DoTrigger          do_trigger
	asSetAct GoTriggerSelect	go_trigger_select

	asSetAct GoRValList         go_rval_list
	asSetAct GoRVal             go_rval
	asSetAct GoAddRVal          go_add_rval
	asSetAct DoRVal             do_rval
	asSetAct GoRvalSelect       go_rval_select

	asSetAct GoAddToken         go_add_token
	asSetAct GoToken            go_token
	asSetAct DoToken            do_token

	asSetAct GoPossBet          go_pb
	asSetAct GoAddPB            do_add_pb
	asSetAct GoDelPB            do_pb_del

	asSetAct GoGenerateVouchers go_generate_vouchers
	asSetAct DoGenerateVouchers	do_generate_vouchers

	#
	# Initialise MCS server communication
	#
	init_mcs

	if {[catch {load libOT_Addons.so} msg]} {
		OT_LogWrite 2 "failed to load libOT_Addons ($msg)"
	}

	OT_LogWrite INFO {INIT: payment_gateway}
	if {[catch {payment_gateway::pmt_gtwy_init} msg]} {
		OT_LogWrite ERROR "failed to init payment gateway: $msg"
	}

	# This is a bit dirty but you can use external stuff without
	# having it in the EXT namespace by forcing the EXT namespace
	# to load on start up, so we can have
	# ADMIN::SKYSVC etc instead of having to have ADMIN::EXT for everything
	if {[OT_CfgGet FUNC_EXT_FUNCS 0]} {
		add_namespace ADMIN::EXT
	}

	package require util_xl_compat
	ob_xl::init
	namespace import OB_mlang::*

	# Maintain the expiry date of this app's license key
	if {[OT_CfgGet TRACK_LICENSE_EXPIRY 0] && [asGetId] == 0} {
		ob_util::update_license_expiry
	}

	package require core::request
	core::request::init \
    -strict_mode    [OT_CfgGet CONTROLLER_STRICT_MODE 0]

	#
	# Clear any ongoing sessions in war games
	#
	# war_game_gc
	war_game_init

	set MAIN_INIT_COMPLETE 1

}


#
# ----------------------------------------------------------------------------
# Add the code for the relevant namespace
#
# This loads (sources) the Tcl required to implement a given named
# namespace - it is typically called from an 'unknown' handler
# ----------------------------------------------------------------------------
#
proc add_namespace ns {

	global  NAMESPACE_MAP \
			MAIN_INIT_COMPLETE \
			tcl_dir \
			xtn

	if {![info exists NAMESPACE_MAP($ns,files)]} {
		error "unknown namespace: $ns"
	}

	OT_LogWrite 1 "Unknown namespace $ns ==>\
		sourcing: [join $NAMESPACE_MAP($ns,files) ", "]"

	set NAMESPACE_MAP($ns,sourced) 1

	foreach file $NAMESPACE_MAP($ns,files) {

		if ![regexp {\.(tcl|tbc)$} $file] {
			append file ".$xtn"
		}

		uplevel #0 source [file join $tcl_dir $file]
	}

}


#
# ----------------------------------------------------------------------------
# 'unknown' handler
#
# Attempt to parse the command name: if it is a namespace command, attempt
# to load the relevant namespace code
# ----------------------------------------------------------------------------
#
proc unknown {cmd args} {

	global NAMESPACE_MAP errorCode

	if {![regexp {^((\w+::)*\w+)::\w+} $cmd all ns]} {
		error "unknown command: $cmd ($args)"
	}

	if {![info exists NAMESPACE_MAP]} {
		foreach e [OT_CfgGet NAMESPACE_MAP ""] {

			set n [lindex $e 0]
			set NAMESPACE_MAP($n,files)   [lindex $e 1]
			set NAMESPACE_MAP($n,sourced) 0
		}
	}

	if {[info exists NAMESPACE_MAP($ns,sourced)]} {
		if {$NAMESPACE_MAP($ns,sourced) == 1} {
			error "unknown command: $cmd ($args)"
		}
	}

	if {[set ret [catch {add_namespace $ns} result]] == 0} {
		set ret [catch {uplevel $cmd $args} result]
	}

	if {$ret == 0} {
		return $result
	}

	return -code $ret -errorcode $errorCode $result
}


#
# ----------------------------------------------------------------------------
# Gadget to "garbage collect" global variables
# ----------------------------------------------------------------------------
#
namespace eval GC {

	variable vars [list]

	proc mark args {
		variable vars
		foreach m $args {
			if {[lsearch -exact $vars $m] < 0} {
				lappend vars $m
			}
		}
	}
	proc collect {} {
		variable vars
		foreach v $vars {
			set v [string trimleft $v :]
			if {[info exists ::$v]} {
				unset ::$v
			}
		}
		set vars [list]
	}
}


#
# ----------------------------------------------------------------------------
# Connect to database
# ----------------------------------------------------------------------------
#
proc main_db_conn args {

	set server   [OT_CfgGet DB_SERVER   ""]
	set database [OT_CfgGet DB_DATABASE ""]
	set username [OT_CfgGet DB_USERNAME ""]
	set password [OT_CfgGet DB_PASSWORD ""]

	if {$server == "" || $database == ""} {
		OT_LogWrite 1 "DB_SERVER/DB_DATBASE must be specified"
		asRestart
	}

	#
	# If there's a read trace to this proc on ::DB, remove it
	#
	trace vdelete ::DB r main_db_conn

	OT_LogWrite 1 "Connecting to $database@$server"

	#
	# Create (global) database connection
	#
	if {[catch {
		if {$username == "" || $password == ""} {
			set ::DB [inf_open_conn $database@$server]
		} else {
			set ::DB [inf_open_conn $database@$server $username $password]
		}

		#
		# Set lock mode - wait 22 allows onstat -g to identify admin apps
		#
		set stmt [inf_prep_sql $::DB "set lock mode to wait 22"]
		inf_exec_stmt $stmt
		inf_close_stmt $stmt
	} msg]} {
		OT_LogWrite 1 "Failed to connect to DB: $msg"
		asRestart
	}
}


#
# ----------------------------------------------------------------------------
# Open additional log files - this is used mainly for debugging/testing
# ----------------------------------------------------------------------------
#
proc main_aux_logs args {

	set LOG_AUX [string trim [OT_CfgGet LOG_AUX ""]]

	if {$LOG_AUX == ""} {
		return
	}

	foreach ld $LOG_AUX {

		foreach {l_tok l_name l_level l_mode l_rot} $ld { break }

		global $l_tok

		if {$l_tok == "LOG_EMAIL"} {
			set LOG_AUX_DIR [string trim [OT_CfgGet EMAIL_LOG_DIR]]
		} else {
			set LOG_AUX_DIR [string trim [OT_CfgGet LOG_DIR ""]]
		  }

		set c [catch {
			set l [OT_LogOpen\
				-rotation $l_rot\
				-mode     $l_mode\
				-level    $l_level [file join $LOG_AUX_DIR $l_name]]
		} msg]

		if {!$c} {
			set $l_tok $l
		}
	}
}


#
# ----------------------------------------------------------------------------
# Wrappers around reqGetArg - these are needed to be able to retrieve "unsafe"
# multibyte characters...
# ----------------------------------------------------------------------------
#
rename reqGetArg    w__reqGetArg
rename reqGetNthArg w__reqGetNthArg
rename reqGetNthVal w__reqGetNthVal

proc reqGetArg {a {b ""}} {
	if {$b == ""} {
		return [w__reqGetArg -unsafe $a]
	}
	return [w__reqGetArg -unsafe $b]
}
proc reqGetNthArg {a b {c ""}} {
	if {$c == ""} {
		return [w__reqGetNthArg -unsafe $a $b]
	}
	return [w__reqGetArg -unsafe $b $c]
}
proc reqGetNthVal {a {b ""}} {
	if {$b == ""} {
		return [w__reqGetNthVal -unsafe $a]
	}
	return [w__reqGetNthVal -unsafe $b]
}

proc reqGetArgDflt {a d} {
	if {[set r [reqGetArg $a]] == ""} {
		return $d
	}
	return $r
}


#
# ----------------------------------------------------------------------------
# Wrapper around db_close - this is to stop it spitting an error when
# the name of the result set is "" (empty string)
# ----------------------------------------------------------------------------
#
rename db_close w__db_close

proc db_close {res} {
	if {$res != ""} {
		w__db_close $res
	}
}


#
# ----------------------------------------------------------------------------
# Wrapper around asPlayFile to use compression if possible
# ----------------------------------------------------------------------------
#
rename asPlayFile w__asPlayFile

proc asPlayFile args {

	global USE_COMPRESSION

	ob::log::write INFO "==>[info level [info level]]"

	set compress 0

	if {$USE_COMPRESSION} {
		if {[file extension [lindex $args end]] == ".html"} {
			foreach e [split [reqGetEnv HTTP_ACCEPT_ENCODING] ,] {
				if {[string trim $e] == "gzip"} {
					set compress 1
					break
				}
			}
		}
	}

	if {$compress} {
		tpBufAddHdr "Content-Encoding" "gzip"
		tpBufCompress 1
	} else {
		tpBufCompress 0
	}

	# need to figure out the language to use here
	# if there's a cookie we're expecting, we can get the language from that

	set lang_cookie [get_cookie [OT_CfgGet ADMIN_LANG_COOKIE "ADMINLANG"]]

	# right now the only contents of the cookie is the language code
	# expect this to change
	set lang $lang_cookie

	if {$lang != ""} {
		# add the language to the play file command
		set args [concat [list "-lang" "$lang"] $args]
	}


	eval {uplevel 1 w__asPlayFile} $args
}


#
# ----------------------------------------------------------------------------
# Per-request initialisation
# ----------------------------------------------------------------------------
#
proc req_init {} {
	OT_LogWrite 1 "REQUEST INIT CALLED"

	global CHARSET USE_COMPRESSION USERNAME OFFICE

	set USERNAME {}

	# multipart uploads
	process_any_multipart_args

	set t [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	tpBindString TimeNow $t

	if {!$USE_COMPRESSION} {
		tpBufCompress 0
	}

	if {[OT_CfgGetTrue CAMPAIGN_TRACKING]} {
		ob_camp_track::req_init
	}

	tpBufAddHdr   "Connection"    "close"
	tpBufAddHdr   "Content-Type"  "text/html; charset=$CHARSET"

	if {[OT_CfgGet SEND_NO_CACHE_HDRS 1]} {
		tpBufAddHdr "Pragma"        "no-cache"
		tpBufAddHdr "Expires"       "-1"
		tpBufAddHdr "Cache-Control" "no-cache; no-store"
	}


	OT_LogSetPrefix "[format %03d [asGetId]]:[format %04d [reqGetId]]"

	set logged_in [ADMIN::LOGIN::check_login]
	tpSetVar LoggedIn $logged_in
	if {$logged_in} {
		OT_LogSetPrefix "[format %03d [asGetId]]:[format %04d [reqGetId]]:$USERNAME"
	}


	# Ensure that the user does not have too many other child processes active
	if {![ob_throttle::reserve USER_$USERNAME]} {
		ob_throttle::release USER_$USERNAME
		catch {error "High User Usage Warning, user $USERNAME has exceeded system resource allocation"}
		asSetAction "req_error"
	}

	#
	# Let through certain activators without checking login details...
	#
	set action [string trim [reqGetArg action]]

	if {$action == ""} {
		if {$logged_in && $OFFICE} {
			asSetAction play_index
		} else {
			asSetAction ADMIN::LOGIN::go_login
		}
		return ""
	}

	ob::log::write 1 {************ REQ START **************}
	ob::log::write INFO {REQ_INIT: action=[reqGetArg action]}
	ob::log::write INFO {REQ_INIT: child =[asGetId]}
	ob::log::write INFO {REQ_INIT: req_id=[reqGetId]}

	#
	# Let these do what they want to do without interference
	#
	switch -- $action {
		stylesheet            -
		stylesheet_splash     -
		GoMenubar             -
		GoBottomBar           -
		GetAppStatus          -
		ADMIN::LOGIN::GoLogin -
		ADMIN::LOGIN::DoLogin -
		ADMIN::USERS::DoPassword {
			return ""
		}
	}

	# set the language for use by mlang later
	# need to figure out the language to use here
	# if there's a cookie we're expecting, we can get the language from that

	set lang_cookie [get_cookie [OT_CfgGet ADMIN_LANG_COOKIE "ADMINLANG"]]

	# right now the only contents of the cookie is the language code
	# expect this to change
	set lang $lang_cookie

	ob_xl_compat::set_lang $lang

	if {!$logged_in} {
		# handle expired password login page
		if {[reqGetArg action] == "ADMIN::LOGIN::GoPwdExprLogin"} {
			asSetAction ADMIN::LOGIN::go_pwd_expr_login
			return ""
		}

		# squirrel away request whilst we do login
		set stored_req [list]
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			lappend stored_req "_[reqGetNthName $i]" [reqGetNthVal $i]
			ob::log::write DEBUG {REQ_INIT: [reqGetNthName $i]=[reqGetNthVal $i]}
		}
		foreach {n v} $stored_req {
			reqSetArg $n $v
		}

		asSetAction ADMIN::LOGIN::go_login
		return ""
	}

	# Setup this admin user for appropriate app name prefixing for crypto requests
	if {[OT_CfgGet CRYPTO_INCLUDE_ADMIN_USER 0]} {
		cryptoAPI::setAdminUser $USERNAME
	}

	#
	# If the "SubmitName" argument is "GoAudit", change the action to
	# produce the audit data...
	#
	if {[reqGetArg SubmitName] == "GoAudit"} {
		asSetAction ADMIN::AUDIT::go_audit
		return ""
	}

	return ""
}


#
# ----------------------------------------------------------------------------
# Per-request cleanup
#
# Issue a rollback and raise the alarm (in the log file) if the rollback
# didn't generate an error (it should, because all transaction handling
# within action handlers should be of the form:
#    inf_begin_tran
#    if {[catch { some database code }]} {
#       inf_rollback_tran
#    } else {
#       inf_commit tran
#    }
# ----------------------------------------------------------------------------
#
proc req_end {} {

	global errorInfo DB

	OT_LogWrite 1 "REQUEST END CALLED"

	if {[catch {w__inf_rollback_tran $DB}] == 0} {
		OT_LogWrite 1 "ALERT: rollback work didn't generate an error"
		set n [reqGetNumVals]
		set l 0
		for {set i 0} {$i < $n} {incr i} {
			set x [string length [reqGetNthName $i]]
			if {$x > $l} {
				set l $x
			}
		}
		set f "    %-${l}s = %s"
		for {set i 0} {$i < $n} {incr i} {
			OT_LogWrite 2 [format $f [reqGetNthName $i] [reqGetNthVal $i]]
		}
	}

	GC::collect

	# Clear the throttle data for this request
	ob_throttle::release


	#
	# Check to see if we've blown a memory usage limit
	#
	if {$::MEM_MAX_USE > 0} {
		set ::MEM_BRK_CUR [asGetBrk]
		if {$::MEM_BRK_CUR-$::MEM_BRK_START > $::MEM_MAX_USE} {
			set v [expr {$::MEM_BRK_CUR-$::MEM_BRK_START}]
			OT_LogWrite 2 "restart ($v used, $::MEM_MAX_USE max)"
			asRestart
		}
	}

	# Clean up any request set variables.
	app_control::clean_up

	catch {set DB}
	set errorInfo ""
	ob::log::write 1 {************* REQ END ***************}
	return ""
}


#
# ----------------------------------------------------------------------------
# Handler for unknown requests
#
# Attempt to  parse the action name: if its is a namespace-style action,
# try to load the relevant namespace code
# ----------------------------------------------------------------------------
#
proc req_unknown args {

	set action [reqGetArg action]

	if {[string length $action] == 0} {
		asPlayFile -nocache [OT_CfgGet STARTUP_HTML]
	}


	if {![regexp {^((\w+::)*\w+)::\w+} $action all ns]} {
		error "unknown command: $action ($args)"
	}

	add_namespace $ns

	set cmd [asGetAct $action]

	if {[string length $cmd] == 0} {
		error "undefined action: $action"
	}

	eval $cmd
}


#
# ----------------------------------------------------------------------------
# Per-request error-handler
#
# Most "application" errors should be trapped in the code - this is the
# handler of last resort called when a request has returned an error to
# the application server. It just plays an error page displaying the request
# stack and the name/value input arguments
# ----------------------------------------------------------------------------
#
proc req_error {} {

	global errorInfo

	set a [reqGetArg action]
	if {$a == ""} {
		set a default
	}
	tpBindString Action $a

	tpSetVar NumActs [reqGetNumVals]

	tpBindTcl ActName {tpBufWrite [reqGetNthName [tpGetVar arg_idx]]}
	tpBindTcl ActVal  {tpBufWrite [reqGetNthVal  [tpGetVar arg_idx]]}

	if {[string length $errorInfo] > 0} {
		tpBindString TclErrorInfo $errorInfo
	}

	asPlayFile error.html
}


#
# ----------------------------------------------------------------------------
# Bind error variables
# ----------------------------------------------------------------------------
#
proc err_bind msg {

	tpBindString ErrMsg  $msg
	tpSetVar     IsError 1
}


#
# Clear error message. (when an error is wilfully ignored and not displayed to user)
#
proc err_clear {} {
	tpSetVar     IsError 0
}


#
# ----------------------------------------------------------------------------
# and nice messages
# ----------------------------------------------------------------------------
#
proc msg_bind msg {
	tpBindString BindMsg  $msg
	tpSetVar     IsBindMsg 1
}


#
# ----------------------------------------------------------------------------
# App server stats
# ----------------------------------------------------------------------------
#
proc get_stats {} {

	tpBufDelHdrs
	tpBufAddHdr "Content-Type" "text/plain"

	set detail [expr {([string length [reqGetArg detail]]>0) ? 1 : 0}]

	set rslts [inf_get_rslt_list]

	set tb 0
	set ts 0
	tpBufWrite "Result sets:\n"
	foreach rslt [inf_get_rslt_list] {
		set b [db_get_bytes $rslt]
		set s [db_get_saved $rslt]
		set r [db_get_nrows $rslt]
		set c [db_get_ncols $rslt]
		tpBufWrite [format "%-10s %2d cols %4d rows (%6d bytes %6d saved)\n"\
			$rslt $c $r $b $s]
		if {$detail} {
			tpBufWrite "[join [db_get_colnames $rslt] ,]\n"
		}
		incr tb $b
		incr ts $s
	}
	tpBufWrite "Total allocated: $tb, total saved: $ts\n"
}


#
# ----------------------------------------------------------------------------
# Load packages for MCS
# ----------------------------------------------------------------------------
#
proc init_mcs {} {
	if {[OT_CfgGetTrue MCS_UPDATE_PASSWORD]} {
		set c [catch {
			package require tls
			http::register https 443 tls::socket
		} msg]

		if {$c} {
			OT_LogWrite 1 "Failed to load TLS library: $msg"
		} else {
			OT_LogWrite 15 "Loaded TLS library successfully"
		}
	} else {
		OT_LogWrite 15 "MCS update disabled"
	}
}

#
# ----------------------------------------------------------------------------
# Clean up server packages for War Game
# ----------------------------------------------------------------------------
#
proc war_game_gc {} {
	global DB

	ob::log::write 1 {************ WAR GAME GARBAGE COLLECTION START **************}

	set sql {
		DELETE FROM 
			tactivewaruser
	}

	if {[catch {set stmt [inf_prep_sql $DB $sql]} msg]} {
		tpBindString err_msg "error occured while preparing statement"
		ob::log::write ERROR {===>error: $msg}
		tpSetVar err 1
		asPlayFile -nocache war_games/login.html
		return
	}
		
	if {[catch [inf_exec_stmt $stmt] msg]} {
		tpBindString err_msg "error occured while executing query"
		ob::log::write ERROR {===>error: $msg}
		catch {inf_close_stmt $stmt}
		tpSetVar err 1
		asPlayFile -nocache war_games/login.html
		return
	}

	catch {inf_close_stmt $stmt}

	ob::log::write info {ALL SESSIONS HAVE BEEN CLEARED}

	ob::log::write 1 {************ WAR GAME GARBAGE COLLECTION END **************}
	# OT_CfgSet war_game_init 1
	# puts "-------------> War Game has been initialised: [OT_CfgGet war_game_init]"
	
}

#
# ----------------------------------------------------------------------------
# Initialise war game server
# ----------------------------------------------------------------------------
#
proc war_game_init {} {
	ob::log::write 1 {************ WAR GAME INITIALISATION START **************}

	if {![OT_CfgGet APP_IS_PMT 0]} {

		if {[asGetId] == 0 && [asGetGroupId] == 0} {
			asSetTimeoutProc     WAR_GAME::disconnect_timeout_users
			asSetTimeoutInterval 1000
			asSetReqAccept       0
			asSetReqKillTimeout  10000
		} else {
			after 500
		}
	}

	ob::log::write info {CHILD PROCESS ASSIGNED TO TIMEOUT USERS}

	ob::log::write 1 {************ WAR GAME INITIALISATION END **************}
}

#
# ----------------------------------------------------------------------------
# Play the home page
# ----------------------------------------------------------------------------
#
proc play_index args {

	asPlayFile -nocache index.html
}
