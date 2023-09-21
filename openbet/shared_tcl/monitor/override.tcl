# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/override.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Override Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::override     sends an override message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Override
#-------------------------------------------------------------------------------
#
# cust_id       - what data type is 'a'
# cust_reg_code -
# oper_id       - what data type is 'b'
# oper_auth_id  - what data type is 'c', the default value.
# action        -
# override_date - ANSI style timestamp of override.
# call_id       -
# leg_no        -
# part_no       -
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::override {
	cust_id
	cust_reg_code
	oper_id
	oper_auth_id
	action
	override_date
	call_id
	leg_no
	part_no
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: override}

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

	set status [_send OVR]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
