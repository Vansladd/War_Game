# $Id: alert.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
# 2005 Orbis Technology Ltd. All rights reserved.
#
# Send Monitor Alert
#
# Configuration:
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#    ::ob_monitor::alert     send an alert message
#



# Variables
#
namespace eval ::ob_monitor {
}



#--------------------------------------------------------------------------
# Alert
#--------------------------------------------------------------------------

# Send an alert message
#
#	class_id    - class identifier
#	class_name  - class name/desc
#	type_id     - type identifier
#	type_name   - type name/desc
#	ev_id       - event identifier
#	ev_name     - event name/desc
#	mkt_id      - market identifier
#	mkt_name    - market name
#	sln_id      - selection/outcome identifier
#	sln_name    - selection/outcome name
#	alert_code  - alert code
#	alert_date  - alert data
#	returns     - monitor status, OB_OK denotes success
#
proc ::ob_monitor::alert {
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
	alert_code
	alert_date
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: alert}

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

	set status [_send ALT]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
