# $Id: init.tcl,v 1.1 2011/10/04 12:30:14 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office
# One-time initialisation
#
# Configuration:
#    TCL_SCRIPT_DIR        tcl script directory - tcl
#    TCL_XTN               tcl file extension   - tbc
#    CGI_URL               office url
#    OFFICE_STATIC_URL     office static URL
#                          - base directory for css, images + javascript
#                            used within OpenBet Office
#    DISPLAY_ENV_NAME      Environment name, displayed right of menu ("")
#    TRACK_LICENSE_EXPIRY  0 or 1 - when on maintains the application expiry date in
#                          tLicenseExpiry table
#
# Procedures:
#    main_init             one time initialisation
#    req_error             handle unexpected errors
#


# global application configuration
global APP_CFG
array set OPT [list\
	tcl_script_dir     tcl\
	tcl_xtn            tbc\
	ports              ""\
	cgi_url            ""\
	office_static_url  ""\
]
foreach c [array names OPT] {
	if {$OPT($c) != ""} {
		set APP_CFG($c) [OT_CfgGet [string toupper $c] $OPT($c)]
	} else {
		set APP_CFG($c) [OT_CfgGet [string toupper $c]]
	}
}



# new shared_tcl & Office API package paths
set xtn $APP_CFG(tcl_xtn)
lappend auto_path [file join $APP_CFG(tcl_script_dir) shared_tcl]
lappend auto_path [file join $APP_CFG(tcl_script_dir) office_lib]


# denote we are using the standard db packages of database API
set admin_screens 0



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation
#
proc main_init args {

	global APP_CFG

	# util packages
	package require util_util
	ob_util::init

	package require util_control
	ob_control::init

	package require util_log
	ob_log::init
	ob_log::set_prefix [format "%03d:INIT" [asGetId]]

	package require util_db
	ob_db::init

	package require util_gc
	ob_gc::init

	# office API
	package require office
	ob_office::init\
		-cgi_url           $APP_CFG(cgi_url)\
		-office_static_url $APP_CFG(office_static_url)\
		-office_lib_html   office_lib\
		-init_login        1\
		-login_action      http::H_default

	# office application
	foreach c {http office} {
		source [file join $APP_CFG(tcl_script_dir) ${c}.$APP_CFG(tcl_xtn)]
	}

	# bind globals
	tpBindString CGI_URL -global $APP_CFG(cgi_url)
	tpBindString JS_URL  -global $APP_CFG(office_static_url)/js
	tpBindString GIF_URL -global $APP_CFG(office_static_url)/images
	tpBindString CSS_URL -global $APP_CFG(office_static_url)/css

	tpBindString DISPLAY_ENV_NAME -global [OT_CfgGet DISPLAY_ENV_NAME ""]
	set environment [OT_CfgGet DISPLAY_ENV_NAME ""]
	if {$environment != "" && [string compare -nocase [string trim $environment] "live"] == 0 } {
		tpBindString DISPLAY_ENV_CLASSNAME -global "live"
	} else {
		tpBindString DISPLAY_ENV_CLASSNAME -global "notlive"
	}

	ob_log::write INFO {$APP_CFG(cgi_url):$APP_CFG(ports)}

	ob_log::set_prefix ""

	# Maintain the expiry date of this app's license key
	if {[OT_CfgGet TRACK_LICENSE_EXPIRY 0] && [asGetId] == 0} {
		ob_util::update_license_expiry
	}
}



# Handle unexpected errors
#
proc req_error args {

	http::req_error $::errorInfo
}
