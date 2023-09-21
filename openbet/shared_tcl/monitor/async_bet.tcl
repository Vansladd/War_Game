# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/async_bet.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# 
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::async_bet   Sends an asynchronous bet message to the ticker
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Async Bet 
#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::async_bet {
        bet_id
	cust_uname
	cust_fname
	cust_lname
	cust_acctno
	cust_is_notifiable
	bet_date
	bet_type
	ev_name
	sln_name
	price
	amount_usr
	ccy_code
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: async_bet}

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

	set status [_send ASY]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
