# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# POLi payment interface
#
# Marketing blurb : POLi offers a great alternative to credit cards
# at the checkout for every consumer. We provide a seamless and secure payment
# experience by connecting you directly to your bank, without any registration
# needed! Our goal is to make paying for goods and services online quick and easy.
#
# http://www.polipayments.com/
#
set pkg_version 1.0
package provide core::payment::POLI $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::payment::POLI \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/POLI.xml

namespace eval core::payment::POLI {
	variable CORE_DEF

	# POLI specific mandatory args
	set CORE_DEF(bank_id)      [list -arg -bank_id      -mand 1 -check UINT  -desc {The customers bank id}]
	set CORE_DEF(poli_receipt) [list -arg -poli_receipt -mand 0 -check ASCII -desc {POLi receipt}]
	set CORE_DEF(timeout)      [list -arg -timeout      -mand 1 -check UINT  -desc {How long the user has to complete the transaction with POLi (in seconds)}]
	set CORE_DEF(token)        [list -arg -token        -mand 1 -check ASCII -desc {the payment token returned by POLi}]
	set CORE_DEF(trans_ref)    [list -arg -trans_ref    -mand 1 -check ASCII -desc {Poli's unique transaction ref for payment}]

	# POLI specific optional args
	set CORE_DEF(success_url,opt)  [list -arg -success_url  -mand 0 -default_cfg POLI_SUCCESS_URL -default {} -check ASCII -desc {The URL that the customer is returned to after a successful transaction}]
	set CORE_DEF(fail_url,opt)     [list -arg -fail_url     -mand 0 -default_cfg POLI_FAIL_URL    -default {} -check ASCII -desc {The URL that the customer is returned to after an unsuccessful transaction}]
	set CORE_DEF(merch_url,opt)    [list -arg -merch_url    -mand 0 -default_cfg POLI_MERCH_URL   -default {} -check ASCII -desc {The URL the customer is returned to if they cancel the payment}]
	set CORE_DEF(notify_url,opt)   [list -arg -notify_url   -mand 0 -default_cfg POLI_NOTIFY_URL  -default {} -check ASCII -desc {The URL the poli nudge returns to}]
	set CORE_DEF(pmt_id)           [list -arg -pmt_id       -mand 1                                           -check UINT   -desc {The POLi payment ID}]
	set CORE_DEF(status)           [list -arg -status       -mand 1                                           -check ASCII  -desc {The status of the payment}]
	set CORE_DEF(bank_id,opt)      [list -arg -bank_id      -mand 0                               -default {} -check UINT  -desc {The customers bank id}]
}

# Register POLi interface interface.
core::args::register \
	-interface core::payment::POLI::init \
	-args [list \
		[list -arg -xml_namespace_url          -default_cfg POLI.NS                  -mand 0 -check STRING -default {} -desc {XML schema namespace for POLI requests}] \
		[list -arg -xml_namespace_instance_url -default_cfg POLI.NS.I                -mand 0 -check STRING -default {} -desc {XML schema instance for POLI requests}] \
		[list -arg -xml_transaction_schema_url -default_cfg POLI.TRAN.DCO            -mand 0 -check STRING -default {} -desc {XML schema for POLI transaction requests}] \
		[list -arg -is_monitor_enabled         -default_cfg MONITOR                  -mand 0 -check BOOL   -default 0  -desc {Is the Monitor enabled}] \
		[list -arg -is_payment_ticker_enabled  -default_cfg PAYMENT_TICKER           -mand 0 -check BOOL   -default 0  -desc {Is the payment ticker enabled}] \
		[list -arg -perform_ovs_check          -default_cfg FUNC_OVS_VERF_POLI_CHK   -mand 0 -check BOOL   -default 0  -desc {Perform OVS check for POLi payments}] \
		[list -arg -normalise_foreign_chars    -default_cfg NORMALISE_FOREIGN_CHARS  -mand 0 -check BOOL   -default 0  -desc {Normalise foreign characters for the payments ticker}] \
	] \
	-body {
	
		# Initialise the harness if it is on the auto path
		# The harness nor the tests will be deployed in a live
		# environment and they are configured off by default
		if {![catch {
			package require core::harness::payment::POLI 1.0
		} err]} {
			core::harness::payment::POLI::init
		}
	}

core::args::register \
	-interface core::payment::POLI::insert_cpm \
	-desc      {Insert a new POLi cust pay method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::POLI::CORE_DEF(bank_id) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::POLI::update_cpm \
	-desc      {Update a POLi customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::POLI::CORE_DEF(bank_id,opt) \
	]

core::args::register \
	-interface core::payment::POLI::insert_pmt \
	-desc      {Insert a new POLi payment} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::POLI::CORE_DEF(bank_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::CORE_DEF(min_overide) \
	]

core::args::register \
	-interface core::payment::POLI::update_pmt \
	-desc      {Update a POLi payment} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::POLI::CORE_DEF(bank_id) \
		$::core::payment::POLI::CORE_DEF(poli_receipt) \
	]

core::args::register \
	-interface core::payment::POLI::update_pmt_status \
	-desc      {Update a POLi payment status} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
	]

core::args::register \
	-interface core::payment::POLI::make_deposit \
	-desc      {Make a deposit using POLi} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::POLI::CORE_DEF(bank_id) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(min_overide) \
		$::core::payment::POLI::CORE_DEF(success_url,opt) \
		$::core::payment::POLI::CORE_DEF(fail_url,opt) \
		$::core::payment::POLI::CORE_DEF(merch_url,opt) \
		$::core::payment::POLI::CORE_DEF(notify_url,opt) \
		$::core::payment::POLI::CORE_DEF(timeout) \
	]

core::args::register \
	-interface core::payment::POLI::complete_payment \
	-desc      {Complete the POLi payment after a redirect, check transaction was completed successfully and update the database} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::POLI::CORE_DEF(token) \
	]

core::args::register \
	-interface core::payment::POLI::get_financial_inst \
	-desc      {Send a request to POLi to find out which financial institutions can be used with POLi} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(source) \
	]

core::args::register \
	-interface core::payment::POLI::get_detailed_tran \
	-desc      {Send a request to POLi to find out the status of an a payment, which is unkown in our db} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::POLI::CORE_DEF(trans_ref) \
	]

# deprecated. See OBCORE-502.
core::args::register \
	-interface core::payment::POLI::initiate_transaction \
	-desc      {Send an initial message to POLi with details of the payment and check to make sure it initialised successfully.} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(ipaddr) \
		[list -arg -success_url -mand 0 -default_cfg POLI_SUCCESS_URL -default {} -check ASCII -desc {The URL that the customer is returned to after a successful transaction}] \
		[list -arg -fail_url    -mand 0 -default_cfg POLI_FAIL_URL    -default {} -check ASCII -desc {The URL that the customer is returned to after an unsuccessful transaction}] \
		[list -arg -merch_url   -mand 0 -default_cfg POLI_MERCH_URL   -default {} -check ASCII -desc {The URL the customer is returned to if they cancel the payment}] \
		[list -arg -notify_url  -mand 0 -default_cfg POLI_NOTIFY_URL  -default {} -check ASCII -desc {The URL the poli nudge returns to}] \
		[list -arg -timeout     -mand 1 -check UINT  -desc {How long the user has to complete the transaction with POLi (in seconds)}] \
		[list -arg -bank_code   -mand 1 -check ASCII -desc {The code of the bank that the customer wishes to deposit with}] \
	]

# deprecated. See OBCORE-502.
core::args::register \
	-interface core::payment::POLI::get_transaction \
	-desc      {Send a message to POLi to make sure the transaction has been completed and was successful and update the db with the payment details} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(source) \
		[list -arg -token -mand 1 -check ASCII -desc {the payment token returned by POLi}] \
	]

# deprecated. See OBCORE-502.
core::args::register \
	-interface core::payment::POLI::send_monitor_msg \
	-desc      {Grab pmt details and send a monitor message.} \
	-returns   ASCII \
	-args [list \
		$::core::payment::POLI::CORE_DEF(pmt_id) \
		$::core::payment::POLI::CORE_DEF(status) \
	]
