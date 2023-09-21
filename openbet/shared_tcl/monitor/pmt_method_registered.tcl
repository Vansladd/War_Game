# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/pmt_method_registered.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Payment Method Registered Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::pmt_method_registered     sends a payment method reg message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Payment Method Registered
#-------------------------------------------------------------------------------
#
# cust_id             -
# cust_uname          -
# cust_fname          -
# cust_lname          -
# cust_reg_date       -
# cust_reg_code       -
# cust_reg_postcode   -
# cust_reg_email      -
# cust_is_notifiable  -
# country_code        -
# ccy_code            -
# channel             -
# amount_usr          -
# amount_sys          -
# ip_city             -
# ip_country          -
# ip_routing_method   -
# country_cf          -
# liab_group          -
# pmt_method          -
# cpm_id              -
# pmt_method_count    -
# generic_pmt_mthd_id -
# pmt_mthd_other      -
# args                -
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::pmt_method_registered {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_date
        cust_reg_code
	cust_reg_postcode
	cust_reg_email
	cust_is_notifiable
	country_code
	ccy_code
	channel
	amount_usr
	amount_sys
	ip_city
	ip_country
	ip_routing_method
	country_cf
	liab_group
	pmt_method
	cpm_id
	pmt_method_count
	generic_pmt_mthd_id
	pmt_mthd_other
	args
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: pmt_method_registered}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	set MESSAGE [list]

	# Get the name of the current procedure
	set current_proc [lindex [info level [info level]] 0]

	# For each arg passed to this procedure, append it to message
	foreach n [info args $current_proc] {
		if {$n == "args"} {continue}
		lappend MESSAGE $n [set $n]
	}

	foreach {n v} $args {
		lappend MESSAGE $n $v
	}

	set status [_send PMTHD]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
