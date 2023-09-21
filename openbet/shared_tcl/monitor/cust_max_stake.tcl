# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/cust_max_stake.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# cust_max_stake
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::cust_max_stake -  Sends a customer max stake factor message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
#  Sends a customer max stake factor message
#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::cust_max_stake {
        change_timestamp
	cust_stk_acctno
	cust_stk_lname
	cust_stk_username
	stk_factor_level
	cust_stk_factor
	level_value
	level_prev_value
	op_performed
	operator    
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: cust_max_stake}

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

	set status [_send MSTK]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
