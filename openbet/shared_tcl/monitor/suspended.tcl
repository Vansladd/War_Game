# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/suspended.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
#  suspended- Sends registration information along with a reason
#                           to the ticker when a customer is suspended
#
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::suspended   Sends registration information along with a reason
#                           to the ticker when a customer is suspended
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

##
# suspended - Sends registration information along with a reason
#                           to the ticker when a customer is suspended
#
#
# PARAMS
#
#
#	[cust_reg_date] - customer registration date: tCustomer.cr_date
#
#	[cust_uname] - customer username: tCustomer.username
#
#	[cust_acct_no] - customer account number: tCustomer.acct_no
#
#	[cust_addr_1] - customer street: tCustomerReg.steet_addr_1
#
#	[cust_reg_postcode] - customer postcode: tCustomerReg.addr_postcode
#
#      [cust_orign_uname] - username of matched customer: tCustomer.username
#
#    [reason] - note to indicate the reason the customer was suspended
#
proc  ::ob_monitor::send_suspended {
	cust_reg_date
	cust_uname
	cust_acct_no
	cust_addr_1
	cust_reg_postcode
	cust_orign_uname
	suspended_code
} {
	variable MESSAGE

	ob_log::write DEBUG {MONITOR: urn_match}

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

	set status [_send SUSP_$suspended_code]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
