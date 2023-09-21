# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/bf_order.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# bf_order
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::bf_order -  Sends a BetFair order message
#
#
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
#  Sends a BetFair order message
##
#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::bf_order {
        order_reason
	ev_id
	ev_name
	mkt_id
	mkt_name
	sln_id
	sln_name
	bf_bet_id
	bf_status
	bf_price
	bf_size_matched
	bf_size
	bf_order_id
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: bf_order}

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

	set status [_send BFORD]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
