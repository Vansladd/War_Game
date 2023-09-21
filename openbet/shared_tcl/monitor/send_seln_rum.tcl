# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/send_seln_rum.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send selection RUM message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::send_seln_rum     sends a seln rum message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Selection RUM message
#-------------------------------------------------------------------------------
#
#       [sln_id] - event outcome id: tEvOc.ev_oc_id
#
#       [sln_name] - Description of the Selection: tEvOc.desc
#
#       [start_time] - Time of the market: tEvOc.ev_oc_id
#
#       [rum_total] - the total RUM figure for this selection
#
#       [rum_liab_total] - the total RUM liability for this selection
#
#       [ev_mkt_name] - the market of the selection
proc ::ob_monitor::send_seln_rum {
	sln_id
	sln_name
	ev_date
	rum_total
	rum_liab_total
	mkt_name
	class_name
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: send_seln_rum}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	set alert_date [MONITOR::datetime_now]
	
        set MESSAGE [list]

	foreach n [list \
		sln_id \
		sln_name \
		ev_date \
		rum_total \
		rum_liab_total \
		mkt_name \
		class_name \
		alert_date \
		] {
			lappend MESSAGE $n [set $n]
		  }



	set status [_send SRM]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
