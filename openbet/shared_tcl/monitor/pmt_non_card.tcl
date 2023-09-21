# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/pmt_non_card.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
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
#   ::ob_monitor::pmt_non_card     sends a pmt_non_card message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Non Card Payments
#-------------------------------------------------------------------------------
#
# cust_id            - customer id: tCustomer.cust_id
# cust_uname         - customer username: tCustomer.username
# cust_fname         - customer first name: tCustomerReg.fname
# cust_lname         - customer last name: tCustomerReg.lname
# cust_reg_postcode  - customer postcode: tCustomerReg.addr_postcode
# cust_reg_email     - customer email address :tCustomerReg.email
# country_code       - country_code
# cust_reg_date      - customer registration date: tCustomer.cr_date
# cust_reg_code      - 
# cust_is_notifiable - is customer notifiable: tCustomer.notifyable
# cust_acctno        - customer account number : tAcct.acct_id
# acct_balance       - customer account balance :tAcct.balance
# ip_country         - IP address followed by country.
# ip_city            - IP address followed by city.
# pmt_method         - Payment method : tCustPayMthd.pay_mthd
# ccy_code           - currency code
# amount_usr         - amount in user currency
# amount_sys         - amount in db currency
# pmt_id             - payment id : tPmt.pmt_id
# pmt_date           - payment data : tpmt:cr_date
# pmt_sort           - payment sort : tPmt.payment_sort
# pmt_status         - payment status :tPmt.status
# ext_unique_id      - external unique identifier (acct. no/neteller)
# bank               - bank name
# channel            - channel
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::pmt_non_card {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_postcode
	cust_reg_email
	country_code
	cust_reg_date
	cust_reg_code
	cust_is_notifiable
	cust_acctno
	acct_balance
	ip_country
	ip_city
	pmt_method
	ccy_code
	amount_usr
	amount_sys
	pmt_id
	pmt_date
	pmt_sort
	pmt_status
	ext_unique_id
	bank
	channel
	{trading_note ""}
	{cum_wtd_usr ""}
	{cum_wtd_sys ""}
	{cum_dep_usr ""}
	{cum_dep_sys ""}
	{max_wtd_pc ""}
	{max_dep_pc ""}
	args
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: pmt_non_card}

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

	set status [_send PMTNC]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
