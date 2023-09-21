# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/urn_match.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
#  urn_match - Sends registration information to the ticker when
#                  there is a URN match by the criteria in module cust_matcher::
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::urn_match     Sends registration information to the ticker when
#                      there is a URN match by the criteria in module cust_matcher
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

##
# MONITOR::urn_match - Sends registration information to the ticker when
#                  there is a URN match by the criteria in module cust_matcher::
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
#   [cust_orign_uname] - username of matched customer: tCustomer.username
#
##
proc ::ob_monitor::urn_match {
	cust_reg_date
	cust_uname
	cust_acct_no
	cust_addr_1
	cust_reg_postcode
	cust_orign_uname
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

	set status [_send URNM]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
