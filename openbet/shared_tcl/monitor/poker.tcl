# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/poker.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Poker Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::poker     sends a poker message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Poker
#-------------------------------------------------------------------------------
#
# cust_id            - customer id : tCustomer.cust_id
# cust_uname         - customer's username
# cust_is_notifiable - is customer notifiable: tCustomer.notifyable
# fraud_status       - Fraud status
# poker_datetime     - date & time of poker transaction
# ccy_code           - currency.
# country_code       - country
# ip_country         - IP address followed by country.
# transfer_type      - Transfer type i.e. Deposit or Withdrawal
# amount_sys         - the amount transfered
# cust_cr_date       - creation date of customer account
# casino_code        - The casino from which the message originated
# alias              - the user's poker alias
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::poker {
	cust_id
	cust_uname
	cust_is_notifiable
	fraud_status
	transfer_time
	ccy_code
	country_code
	ip_country
	transfer_type
	amount_sys
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: poker}

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

	set status [_send PKR]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
