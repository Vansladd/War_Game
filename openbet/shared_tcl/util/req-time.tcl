# $Id: req-time.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Set of utilities which allow a request to be timed accurately.
#
# Configuration:
#    UTIL_REQTIME_LOG_SYMLEVEL      time log symbolic level (INFO)
#
# Synopsis:
#    package require util_req_time ?4.5?
#
# Procedures:
#    ob_reqtime::req_init           init request time
#    ob_reqtime::req_end            end request time (report times)
#    ob_reqtime::set_action         set the request action
#

package provide util_req_time 4.5



# Dependencies
#
package require util_log 4.5



# Variables
#
namespace eval ob_reqtime {

	variable CFG
	variable REQ
	variable INIT

	set INIT 0
	set CFG(log_symlevel) INFO
	set CFG(cpu_time)     0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
proc ob_reqtime::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init

	ob_log::write DEBUG {REQTIME: init}

	# get configuration
	set CFG(log_symlevel) [OT_CfgGet UTIL_REQTIME_LOG_SYMLEVEL INFO]

	# can we get cpu time (appserv API)
	if {[info commands asGetTime] == "asGetTime"} {
		set CFG(cpu_time) 1
	}

	set INIT 1
}



#--------------------------------------------------------------------------
# Request Init/End
#--------------------------------------------------------------------------

# Initialise/Start request timing.
# Call from application's req_init.
#
#    action - request action (default: reqGetArg action)
#
proc ob_reqtime::req_init { {action "__NONE"} } {

	variable CFG
	variable REQ

	set REQ(real)   [OT_MicroTime -micro]

	if {$action == "__NONE"} {
		set action [ob_chk::get_arg action -on_err "" Az]
	}

	set REQ(action) $action

	if {$CFG(cpu_time)} {
		set REQ(user) [asGetTime -self -user]
		set REQ(sys)  [asGetTime -self -system]
	}
}



# End request timing and report results.
# Call from application's req_end
#
proc ob_reqtime::req_end args {

	variable CFG
	variable REQ

	set REQ(real) [expr {[OT_MicroTime -micro] - $REQ(real)}]
	set msg "action=$REQ(action) real=[format %0.4f $REQ(real)]"

	if {$CFG(cpu_time)} {
		set REQ(user) [expr {[asGetTime -self -user] - $REQ(user)}]
		set REQ(sys)  [expr {[asGetTime -self -system] - $REQ(sys)}]

		append msg " user=[format %0.4f $REQ(user)]"
		append msg " sys=[format %0.4f $REQ(sys)]"
	}

	ob_log::write $CFG(log_symlevel) {REQ::TIME $msg}
}



#--------------------------------------------------------------------------
# Set Action
#--------------------------------------------------------------------------

# Provide the means of setting the request action.
#
#   action - request action
#
proc ob_reqtime::set_action { action } {

	variable REQ

	set REQ(action) $action
}

