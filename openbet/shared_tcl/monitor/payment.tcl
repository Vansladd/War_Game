# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/payment.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Payment Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::payment     sends a payment message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Payment
#-------------------------------------------------------------------------------
#
# cust_id            - customer id: tCustomer.cust_id
# cust_uname         - customer username: tCustomer.username
# cust_fname         - customer first name: tCustomerReg.fname
# cust_lname         - customer last name: tCustomerReg.lname
# cust_acctno        - customer account number: tCustomer.acct_no
# cust_reg_code      - Custoer Reg code
# cust_is_notifiable - is customer notifiable: tCustomer.notifyable
# acct_balance       - account balance: tAcct.balance in user currency
# amount_usr         - payment amount in user's currency
# amount_sys         - payment amount in system's currency
# ccy_code           - currency code
# pmt_id             - payment id: tPmt.id
# pmt_date           - payment date and time
# pmt_status         - payment status: tPmt.status
# pmt_sort           - payment sort: tPmt.payment_sort
# channel            - channel
# gw_auth_date       - payment gateway authorization date and time
# gw_auth_code       - payment gateway authorization code
# gw_ret_code        - payment gateway return code
# gw_ret_msg         - payment gateway return message
# gw_ref_no          - payment gateway reference number
# hldr_name 
# liab_group
# cv2avs_status
#-------------------------------------------------------------------------------
proc ::ob_monitor::payment {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	country_code
	cust_reg_date
	cust_acctno
	cust_reg_code
	cust_is_notifiable
	acct_balance
	amount_usr
	amount_sys
	ccy_code
	pmt_id
	pmt_date
	pmt_status
	pmt_sort
	channel
	gw_auth_date
	gw_auth_code
	gw_ret_code
	gw_ret_msg
	gw_ref_no
	hldr_name
	liab_group
	cv2avs_status
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: payment}

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

	set status [_send PMT]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
