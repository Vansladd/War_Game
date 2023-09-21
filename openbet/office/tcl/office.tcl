# $Id: office.tcl,v 1.1 2011/10/04 12:30:14 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office
# Office Menu Handler
#
# Configuration:
#    OFFICE_APPS          list of back office applications (name/url pairs)
#
#    SHOW_REL_ENV_INFO    turn on or off the functionality for showing release
#                         and environment information
#
#    REL_ENV_FILE         the file containing the release and environment
#                         information to be displayed.   
#
# Procedures
#    office::H_menu       office menu
#

# Namespace Variables
#
namespace eval office {

	variable CFG
	variable RELEASE_INFO
}



#--------------------------------------------------------------------------
# Init
#--------------------------------------------------------------------------

# Private procedure to perform one time init
#
proc office::_init args {

	variable CFG
	variable RELEASE_INFO

	ob_log::write INFO {office: init}

	set CFG(apps) [OT_CfgGet OFFICE_APPS]
	set CFG(show_rel_env_info) [OT_CfgGet SHOW_REL_ENV_INFO 0]
	set CFG(rel_env_file) [OT_CfgGet REL_ENV_FILE ""]
	
	set RELEASE_INFO ""
	
	# Read the release info for display purposes from
	# the specified file if instructed to do so.
	if {$CFG(show_rel_env_info)} {
		office::_get_release_tags_info
	}

	# action handlers
	asSetAct GoOfficeMenu  office::H_menu
	asSetAct GoOfficePane  office::H_pane
}



#--------------------------------------------------------------------------
# Action Handlers
#--------------------------------------------------------------------------

# Action handle to play the Office Menu contains all the back-office
# applications as defined within the config OFFICE_APPS
#
proc office::H_menu args {

	variable CFG
	global APP

	ob_log::write DEBUG {office: H_menu}

	# get back-office application details
	# - only get this once per child
	if {![info exists APP(total)]} {
		set APP(total) 0
		set APP(cols)  [list name url]

		foreach app $CFG(apps) {
			foreach {name url} $app {
				set i $APP(total)
				set APP($i,name) $name
				set APP($i,url)  $url
				incr APP(total)
			}
		}
	}

	# bind
	foreach c $APP(cols) {
		tpBindVar app_${c} APP $c app_idx
	}

	tpSetVar OFFICE_MENU 1
	ob_office::util::play menu.html
}



# Action handle to display the Office Pane window
#
proc office::H_pane args {

	variable CFG
	variable RELEASE_INFO

	ob_log::write DEBUG {office: H_pane}

	tpSetVar OFFICE_BACKGROUND 1
	
	# Bind up the information and show this on the main page.
	if {$CFG(show_rel_env_info)} {
		tpSetVar SHOW_REL_ENV_INFO 1
		tpBindString RELEASE_TAG_INFO $RELEASE_INFO	
	}
	
	ob_office::util::play office.html
}



#
# Get the release and environment informtaion from 
# the specified file. Set the RELEASE_INFO variable to this
#
# If we can't read the file don't exit just move on.
#
proc office::_get_release_tags_info args {

	variable CFG
	variable RELEASE_INFO

	ob_log::write DEBUG {office: _get_release_tags_info}
		
	set fname $CFG(rel_env_file)
	if [catch {set fileid [open $fname "r"]} msg] {
		ob_log::write ERROR {Cannot open file for reading: $fname so move on.}
		return
	}
	
	fconfigure $fileid -buffering line
	
	set env_tags_info ""
	while {![eof $fileid]} {
		gets $fileid line
		set env_tags_info "$env_tags_info<br>$line"
	}
	set env_tags_info "$env_tags_info<br>"
	close $fileid	
	
	set RELEASE_INFO $env_tags_info
}



# self init
if {![info exists office::CFG]} {
	office::_init
}