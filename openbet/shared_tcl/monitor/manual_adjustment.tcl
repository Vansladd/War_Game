# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/manual_adjustment.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Manual Adjustment Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::manual_adjustment     sends a manual adjustment message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Manual Adjustment
#-------------------------------------------------------------------------------
#
# cust_id            - customer id: tCustomer.cust_id
# cust_uname         - customer username: tCustomer.username
# cust_fname         - customer first name: tCustomerReg.fname
# cust_lname         - customer last name: tCustomerReg.lname
# cust_is_notifiable - is customer notifiable: tCustomer.notifyable
# cust_reg_code      - customer reg code      
# amount_usr         - amount in user currency
# amount_sys         - amount in db currency
# ccy_code           - currency code
# madj_status        - manual adjustment status, e.g. OK, FAILED
# madj_code          - manual adjustment code, e.g. CASINO:WTD, POKER:DEP
# madj_date          - date and time manual adjustment was placed
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::manual_adjustment {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_is_notifiable
        cust_reg_code
	amount_usr
	amount_sys
	ccy_code
	madj_status
	madj_code
	madj_date
	liab_group
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: manual_adjustment}

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

	set status [_send MAN]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
