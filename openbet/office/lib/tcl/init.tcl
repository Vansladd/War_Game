# $Id: init.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# One-time initialisation
#
# Configuration:
#
#    CGI_URL                   - application URL
#    OFFICE_STATIC_URL         - office library static URL
#                                - base directory for css, images + javascript
#                                  used within OpenBet Office Library
#    OFFICE_LIB_HTML           - HTML directory containing Office Library HTML
#                                templates
#                                - relative to the application server HTML directory
#    HTML_CHARSET              - HTML character set   (iso8859-1)
#    HTML_LANG                 - HTML language        (en)
#    CSS_CHARSET               - CSS character set    (iso8859-1)
#    XML_CHARSET               - XML character set    (iso8859-1)
#    XML_LANG                  - XML language         (en)
#    OFFICE_INIT_LOGIN         - initialise the office login namespace (0)
#    FIREBUG_EXTENSION         - use the Firefox extension FireBug to display
#                                Javascript log messages to a console (0)
#                                - DO NOT USE IN PRODUCTION
#    FIREBUG_LITE              - Enable Firebug Lite Javascript
#                                Firebug extension for non Firefox browsers, or Firefox
#                                without the extension installed.
#                                - DO NOT USE IN PRODUCTION
#    FIREBUG_LITE_URL          - Firebig Lite Javascript URL
#                                The Javascript must be supplied by caller (not part of office)
#    OFFICE_MODAL_POPUP        - Use a modal popup (0)
#                                Can use a global modal popup container, however, this must be
#                                added by the caller -
#                                <div id="modalPopupContainer" style="display: none"></div>
#    OFFICE_JS_PACKAGE         - Use the Javscript package manager (1)
#    DIV_POPUP2                - Use DivPopup2 (0)
#    OFFICE_STATIC_VERSION     - Add a version stamp to office static content ("")
#                                If defined, then each static file will have the following added:
#                                  ?ver=[md5 cvs-name + cfg-item]
#                                The cfg-item is generally a number
#    USE_ALTERNATIVE_STYLE     - Use alternative styling
#    ALTERNATIVE_STYLE_URL     - Static url for alternative styling
#    ALTERNATIVE_STYLE_IMAGE   - Static url for alternative background image
#    LOGIN_TITLE               - Specify title of login dialog box
#
# Synopsis:
#    package require office ?1.0?
#
# Procedures:
#   ob_office::init        one time initialisation
#

package provide office 1.0



# Dependencies
#
package require util_log 4.5



# Variables
#
namespace eval ob_office {

	variable CFG
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation
# Get the package configuration.
#
# Can specify any of the config' items as a name value pair (overwrites file
# config), names are:
#
#   -cgi_bin
#   -office_static_url
#   -office_lib_html
#   -office_js_static_url
#   -html_charset
#   -html_lang
#   -css_charset
#   -xml_charset
#   -xml_lang
#   -init_login
#   -login_title
#   -login_action
#   -js_package
#   -static_version
#   -office_modal_popup
#   -firebug_extension
#   -firebug_lite
#   -firebug_lite_url
#   -alternative_style_image
#   -alternative_style_url
#   -alternative_style_image
#   -add_window_cvs_id
#   -calendar
#   -calendar_autoload
#   -div_popup2
#   -func_remote_login
#
# Note: set init_login if you want to use the Office style login div-popup
#       If using the package within an application that handles it's own
#       database connection, then init the office after connection
#
proc ob_office::init args {

	variable CFG

	if {[info exists CFG]} {
		return
	}

	# init dependencies
	ob_log::init

	ob_log::write DEBUG {OFFICE: init}


	# load the config' items via args
	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}


	# set mandatory config
	foreach c [list cgi_url office_static_url office_lib_html] {
		if {![info exists CFG($c)]} {
			set CFG($c) [OT_CfgGet [string toupper $c]]
		}
	}

	# Separate static locations
	if {![info exists CFG(office_js_static_url)]} {
		set CFG(office_js_static_url) "$CFG(office_static_url)/js"
	}

	# optional charsets & language codes
	array set OPT [list charset "iso8859-1" lang "en"]
	foreach xtn [list html css xml] {
		foreach c [array names OPT] {
			set name ${xtn}_${c}
			if {![info exist CFG($name)]} {
				set CFG($name) [OT_CfgGet [string toupper $name] $OPT($c)]
			}
			tpBindString [string toupper $name] -global $CFG($name)
		}
	}


	# optional config
	foreach {c d} {
		office_modal_popup         0
		firebug_extension          0
		firebug_lite               0
		firebug_lite_url           0
		use_alternative_style      0
		alternative_style_url      0
		alternative_style_image    0
		login_title                {OpenBet Office Login} \
		add_window_cvs_id          1
		calendar                   0
		calendar_autoload          0
		div_popup2                 0
		func_remote_login          0
	} {
		if {![info exists CFG($c)]} {
			set CFG($c) [OT_CfgGet [string toupper $c] $d]
		}
	}
	if {![info exist CFG(static_version)]} {
		set CFG(static_version) [OT_CfgGet OFFICE_STATIC_VERSION ""]
	}
	if {![info exist CFG(js_package)]} {
		set CFG(js_package) [OT_CfgGet OFFICE_JS_PACKAGE 1]
	}


	# init login
	if {![info exists CFG(init_login)]} {
		set CFG(init_login) [OT_CfgGet OFFICE_INIT_LOGIN 0]
	}
	if {$CFG(init_login) && [info exists CFG(login_action)]} {
		OT_CfgSet OFFICE_LOGIN_ACTION $CFG(login_action)
	}

	ob_log::write_array DEV ob_office::CFG


	# are we using the Firefox extension Firebug
	if {$CFG(firebug_extension)} {
		ob_log::write WARNING {OFFICE: Firebug enabled}
	}
	tpSetVar FIREBUG_EXTENSION -global $CFG(firebug_extension)

	# using Firebug lite (non firefox alternative to Firebug)
	if {$CFG(firebug_lite)} {
		ob_log::write WARNING {OFFICE: Firebug Lite enabled}
		tpBindString FIREBUG_LITE_URL -global $CFG(firebug_lite_url)
	}
	tpSetVar FIREBUG_LITE -global $CFG(firebug_lite)


	# bind globals
	tpBindString OFFICE_CGI_URL          -global $CFG(cgi_url)
	tpBindString OFFICE_STATIC_URL       -global $CFG(office_static_url)
	tpBindString OFFICE_JS_STATIC_URL    -global $CFG(office_js_static_url)

	# -use packae.js
	tpSetVar OFFICE_JS_PACKAGE -global $CFG(js_package)

	# -popups
	if {$CFG(div_popup2)} {
		tpSetVar DIV_POPUP2 -global 1
	}
	if {$CFG(office_modal_popup)} {
		ob_log::write WARNING {OFFICE: Modal Popups enabled}
	}
	tpSetVar OFFICE_MODAL_POPUP -global $CFG(office_modal_popup)


	# - alternative styling
	tpBindString ALTERNATIVE_STYLE_URL    -global $CFG(alternative_style_url)
	tpBindString ALTERNATIVE_STYLE_IMAGE  -global $CFG(alternative_style_image)
	tpSetVar     USE_ALTERNATIVE_STYLE    -global $CFG(use_alternative_style)

	# -static version
	if {$CFG(static_version) != ""} {
		set v {$Name:  $}
		append v $CFG(static_version)

		ob_log::write DEBUG {OFFICE: static_version=$v}
		tpBindString OFFICE_STATIC_VERSION -global "?ver=[md5 $v]"
	}

	# -store Javascript CVS ids within a global
	tpSetVar ADD_WINDOW_CVS_ID -global $CFG(add_window_cvs_id)

	# -calendar
	tpSetVar OFFICE_CALENDAR          -global $CFG(calendar)
	tpSetVar OFFICE_CALENDAR_AUTOLOAD -global $CFG(calendar_autoload)

	# - remote login
	tpSetVar FUNC_REMOTE_LOGIN -global $CFG(func_remote_login)

	# init sub-package files
	ob_office::action::_init
	ob_office::util::_init
	if {$CFG(init_login)} {
		ob_office::login::_init
		ob_office::err::_init

		tpBindString OFFICE_LOGIN_TITLE -global $CFG(login_title)
	}
}
