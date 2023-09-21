# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/first_transfer.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send First Transfer Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::first_transfer     sends a first_transfer message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# First Transfer
#-------------------------------------------------------------------------------
#
# cust_id            - customer id : tCustomer.cust_id
# cust_uname         - customer's username
# cust_is_notifiable - is customer notifiable: tCustomer.notifyable
# transfer_time      - date & time of transaction
# ccy_code           - currency.
# country_code       - country
# ip_country         - IP address followed by country.
# transfer_type      - Transfer type i.e. Deposit or Withdrawal
# amount_sys         - the amount transfered
# casino_code        - code of the casino from which the message orginates
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::first_transfer {
	cust_id
	cust_uname
	cust_is_notifiable
	transfer_time
	ccy_code
	country_code
	ip_country
	transfer_type
	amount_sys
	casino_code
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: first_transfer}

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

	set status [_send 1XFER]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
