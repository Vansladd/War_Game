# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/man_bet.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# man_bet - Sends a manual bet message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::man_bet - Sends a manual bet message   
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
proc ::ob_monitor::man_bet {
	oper_id
	oper_name
	cust_id
	cust_uname
	cust_name
	cust_liab_group
	cust_reg_code
	cust_reg_postcode
	cust_reg_email
	cust_is_elite
	cust_is_notifiable
	stake_factor
	country_code
	category
	channel
	bet_id
	bet_date
	expected_settle_date
	amount_usr
	amount_sys
	ccy_code
	class_id
	class_name
	type_id
	type_name
	desc

} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: man_bet}

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

	set status [_send MAN_B]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
