# $Id: action.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# Action handler
#
# Synopsis:
#    package require office ?1.0?
#
# Procedures:
#    ob_office::action::H_header     play standard Office HTML header
#    ob_office::action::H_popup      play a popup HTML div
#

# Variables
#
namespace eval ob_office::action {
	variable CFG
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one-time initialisation
#
proc ob_office::action::_init args {

	# action handlers
	asSetAct ob_office::GoHeader  ob_office::action::H_header
	asSetAct ob_office::GoPopup   ob_office::action::H_popup
}



#--------------------------------------------------------------------------
# Action handlers
#--------------------------------------------------------------------------

# Action handler to play the standard office HTML header template
# Includes all the necessary header setting to utilise the Office API
# stylesheets, and Javascript
#
#   cache       cache time - seconds (0)
#   add_hdr     add HTTP headers (0)
#   css         play CSS ("")
#               if blank then do not set
#   js          play JS ("")
#               if blank then do not set
#
proc ob_office::action::H_header { {cache 0} {add_hdr 0} {css ""} {js ""} } {

	ob_log::write DEBUG {OFFICE: H_header $cache,$add_hdr,$css,$js}

	if {$css != ""} {
		tpSetVar OFFICE_HEADER_CSS $css
	}
	if {$js != ""} {
		tpSetVar OFFICE_HEADER_JS $js
	}

	set charset [ob_office::util::get_lang_charset html]

	ob_office::util::play $ob_office::CFG(office_lib_html)/header.html\
	    $cache $add_hdr "" 1 $charset
}



# Action handler to play a popup HTML division
#
#   popup   - popup to play ("")
#   cache   - cache time - seconds (0)
#   add_hdr - add HTTP headers     (1)
#
proc ob_office::action::H_popup { {popup ""} {cache 0} {add_hdr 1} } {

	ob_log::write DEBUG {OFFICE: H_popup $popup,$cache,$add_hdr}

	set charset [ob_office::util::get_lang_charset html]

	if {$popup == ""} {
		set popup [reqGetArg popup]
	}

	ob_office::util::play $ob_office::CFG(office_lib_html)/$popup.html\
	    $cache $add_hdr "" 1 $charset
}
