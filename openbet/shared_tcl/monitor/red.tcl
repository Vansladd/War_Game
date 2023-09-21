# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/red.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Monitor Message for Payments made excluding Credit/Debit cards, Entropay,
# and 1-pay & IPS methods
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::red      sends a Sends a red message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}


##
# MONITOR::send_red - Sends a red message
#
#
#
# PARAMS
#
#	[cust_id] - customer id: tCustomer.cust_id
#
#	[cust_uname] - customer username: tCustomer.username
#
#	[cust_fname] - customer first name: tCustomerReg.fname
#
#	[cust_lname] - customer last name: tCustomerReg.lname
#
#	[cust_reg_date] - customer registration date: tCustomer.cr_date
#
#   [cust_is_notifiable] - is customer notifiable: tCustomer.notifyable
#
#	[amount_usr] - amount in user's currency
#
#	[amount_sys] - bet stake amount in db currency
#
#	[ccy_code] - currency code
#
#	[channel] - channel
#
#	[red_date] - red check date and time
#
#	[red_status] - red fraud status
#
#	[red_bank] - red bank
#
#	[red_ip] - red IP address
#

proc ::ob_monitor::red {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_date
	cust_is_notifiable
	amount_usr
	amount_sys
	ccy_code
	channel
	red_date
	red_status
	red_bank
	red_ip
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: red}

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

	set status [_send RED]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
