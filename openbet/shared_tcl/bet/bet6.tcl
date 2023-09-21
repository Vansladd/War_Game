################################################################################
# $Id: bet6.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
#
# Initialise bet placement to work with openbet6 packages
################################################################################
package provide bet_bet 4.5

if {[catch {load libOT_Addons.so} msg]} {
	error "Make sure libOT_Addons.so is in the LD_LIBRARY_PATH: $msg"
}

#required packages
package require util_log 4.5
package require util_db 4.5
package require util_control 4.5

#iniitialise the required packages
ob_control::init

# logging functions
namespace eval ob_bet {
	namespace export _log
}

proc ::ob_bet::_log {level msg} {
	ob_log::write $level "BET- $msg"
}

::ob_bet::_log INFO "sourced bet6.tcl"