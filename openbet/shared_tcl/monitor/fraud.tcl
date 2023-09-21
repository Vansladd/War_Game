# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/fraud.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Fraud Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::fraud     sends a fraud message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Fraud
#-------------------------------------------------------------------------------
#
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::fraud {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_acctno
	cust_reg_date
	cust_reg_code
	cust_is_notifiable
	card_reg_date
	ccy_code
	channel
	country_code
	fraud_status
	fraud_bank
	fraud_ip
	num_cards
	amount_usr
	amount_sys
	fraud_reason
	fraud_card
	cust_reg_postcode
	cust_reg_email
	ip_city
	ip_country
	ip_routing_method
	country_cf
	hldr_name
	liab_group
	args
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: fraud}

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

	set status [_send FRD]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
