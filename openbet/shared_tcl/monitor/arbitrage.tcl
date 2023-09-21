# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/arbitrage.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# arbitrage
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::arbitrage -  Sends an arbitrage message
#
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
#  Sends an arbitrage message
#
#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::arbitrage {
        class_id
        class_name
        type_id
        type_name
        ev_id
        ev_name
        mkt_id
        mkt_name
        sln_id
        sln_name
        price
        bf_price
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: arbitrage}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	set MESSAGE [list]

	# Get the name of the current procedure
	set current_proc [lindex [info level [info level]] 0]

	# For each arg passed to this procedure, append it to message
	foreach n [info args $current_proc] {
		lappend MESSAGE $n [set $n]
	}

	set status [_send ARB]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
