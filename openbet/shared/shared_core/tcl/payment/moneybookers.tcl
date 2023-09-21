# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# Moneybookers payment interface
#

set pkg_version 1.0
package provide core::payment::MB $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::MB \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/MB.xml

namespace eval core::payment::MB {
	variable CORE_DEF

	# Moneybookers specific parameters
	set CORE_DEF(mb_email)     [list -arg -mb_email     -mand 1             -check EMAIL -desc {The customer MoneyBookers email}]
	set CORE_DEF(mb_txn_id)    [list -arg -mb_txn_id    -mand 0 -default {} -check UINT  -desc {The unique ID that MoneyBookers allocates to the payment attempt}]
	set CORE_DEF(mb_status)    [list -arg -mb_status    -mand 0 -default {} -check INT   -desc {The status MoneyBookers assigns to the payment}]
	set CORE_DEF(sid)          [list -arg -sid          -mand 0 -default {} -check UINT  -desc {The Session ID MoneyBookers assigns to a withdrawal request}]
	set CORE_DEF(payment_type) [list -arg -payment_type -mand 0 -default {} -check ASCII -desc {The payment type of the payment}]

}

# Register Moneybookers interface
core::args::register \
	-interface core::payment::MB::init \
	-desc      {Initialise the Moneybookers package} \
	-args      [list \
		[list -arg -dep_api_url             -mand 1 -check ASCII                                         -desc {Moneybookers Deposit api url}] \
		[list -arg -wtd_api_url             -mand 1 -check ASCII                                         -desc {Moneybookers Withdrawal api url}] \
		[list -arg -qry_api_url             -mand 1 -check ASCII                                         -desc {Moneybookers Query api url}] \
		[list -arg -status_url              -mand 0 -check ASCII -default {}                             -desc {Url to send pmt status}] \
		[list -arg -cancel_url              -mand 0 -check ASCII -default {}                             -desc {Url to send pmt cancel}] \
		[list -arg -ccy_codes               -mand 0 -check ASCII -default [list GBP EUR USD CAD AUD JPY] -desc {Currency codes}] \
		[list -arg -supported_languages     -mand 0 -check ASCII -default [list EN DE ES FR IT]          -desc {Supported languages}] \
		[list -arg -redirect_delay          -mand 0 -check BOOL  -default 0                              -desc {Delay before posting redirect form to Moneybookers}] \
		[list -arg -api_timeout             -mand 0 -check UINT  -default 10000                          -desc {APi timeout value}] \
		[list -arg -ob_email_diff_mb_id     -mand 0 -check BOOL  -default 1                              -desc {Openbet email different to Moneybookers id}] \
		[list -arg -func_quick_reg          -mand 0 -check BOOL  -default 0                              -desc {Enable/Disable quick reg}] \
		$::core::payment::CORE_DEF(pmt_receipt_func) \
		$::core::payment::CORE_DEF(pmt_receipt_format) \
		$::core::payment::CORE_DEF(pmt_receipt_tag) \
		[list -arg -func_ovs                -mand 0 -check BOOL  -default 0                              -desc {Enable OVS}] \
		[list -arg -func_ovs_verf_mb_chk    -mand 0 -check BOOL  -default 0                              -desc {OVS check for Moneybookers}] \
		[list -arg -disable_speed_check     -mand 0 -check BOOL  -default 0                              -desc {Disbale speed check}] \
		$::core::payment::CORE_DEF(monitor) \
		$::core::payment::CORE_DEF(payment_ticker) \
		[list -arg -normalise_foreign_chars -mand 0 -check BOOL  -default 0                              -desc {Normalise foreign characters in payment ticker}] \
	]

core::args::register \
	-interface core::payment::MB::insert_cpm \
	-desc      {Insert a new MoneyBookers cust pay method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::MB::CORE_DEF(mb_email) \
		[list -arg -auth_dep      -mand 0 -default P  -check {ENUM -args {Y N P}}  -desc {Deposit authorisation status}] \
		[list -arg -auth_wtd      -mand 0 -default P  -check {ENUM -args {Y N P}}  -desc {Withdrawal authorisation status}] \
		[list -arg -transactional -mand 0 -default Y  -check {EXACT -args {Y N}}   -desc {Whether the execution of the stored proc is transactional or not}] \
		[list -arg -oper_id       -mand 0 -default {} -check UINT                  -desc {The Admin operator ID}] \
		[list -arg -change_cpm    -mand 0 -default N  -check {EXACT -args {Y N}}   -desc {Flag that determines whether the customer is changing their existing CPM}] \
		[list -arg -strict_check  -mand 0 -default Y  -check {EXACT -args {Y N}}   -desc {Flag that determines whether a strict check is made by the stored proc}] \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::MB::update_cpm \
	-desc      {Update a Moneybookers customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::MB::insert_pmt \
	-desc      {Insert a new MoneyBookers payment} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::CORE_DEF(min_overide) \
		$::core::payment::CORE_DEF(call_id) \
	]

core::args::register \
	-interface core::payment::MB::update_pmt \
	-desc      {Updates a MoneyBookers payment} \
	-returns   INT \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::MB::CORE_DEF(mb_txn_id) \
		$::core::payment::MB::CORE_DEF(mb_status) \
		$::core::payment::MB::CORE_DEF(sid) \
		$::core::payment::MB::CORE_DEF(payment_type) \
	]

core::args::register \
	-interface core::payment::MB::update_pmt_status \
	-desc      {Update the status of a MoneyBookers payment} \
	-returns   INT \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
	]

core::args::register \
	-interface core::payment::MB::make_withdrawal \
	-desc      {Performs a withdrawal to a MoneyBookers eWallet} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		[list -arg -check_fraud_status -mand 0 -default 1 -check BOOL -desc {Whether to perform a fraud status check}] \
	]

core::args::register \
	-interface core::payment::MB::do_repost \
	-desc      {Performs a MoneyBookers 'Repost' request} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]

core::args::register \
	-interface core::payment::MB::get_cfg \
	-desc      {Gets a moneybookers config (such as urls)} \
	-returns   ASCII \
	-args      [list \
		[list -arg -cfg_item -mand 1 -check NONE -desc {Moneybookers config item to get}] \
	]
