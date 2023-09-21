# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# BPAY payment interface
#
# Synopsis:
#   BPAY is a deposit-only payment method allowing customers to pay
#   the bookmaker through their bank. When we make a BPAY deposit in
#   OpenBet, the bookmaker will already have received the money, so
#   the logic is quite simple. We insert the payment as pending and
#   immediately attempt to complete it. There is no 'unknown'
#   phase. Payments will be created by an upload, or directly by an
#   admin user, not by the customer in the sportsbook.
#
set pkg_version 1.0
package provide core::payment::BPAY $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::payment::BPAY \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/BPAY.xml

namespace eval core::payment::BPAY {
	variable CORE_DEF
	set CORE_DEF(acct_id)   [list -arg -acct_id   -mand 1 -check UINT   -desc {The Customer's account id tAcct.acct_id}]
	set CORE_DEF(cpm_id)    [list -arg -cpm_id    -mand 1 -check UINT   -desc {The customers Customer Payment Method ID}]
	set CORE_DEF(unique_id) [list -arg -unique_id -mand 1 -check ASCII  -desc {Unique id identifying a payment}]
	set CORE_DEF(amount)    [list -arg -amount    -mand 1 -check MONEY  -desc {The payment amount}]
}

# Register BPAY interface.
core::args::register \
	-interface core::payment::BPAY::init

core::args::register \
	-interface core::payment::BPAY::gen_cust_ref \
	-desc      {Generate a BPAY customer reference number based on a numeric acct no} \
	-returns   UINT \
	-args      [list \
		[list -arg -acct_no -mand 1 -check ASCII -desc {The customer's account number}] \
	]

core::args::register \
	-interface core::payment::BPAY::luhn_check \
	-desc      {Validate a BPAY customer reference number using the Luhn formula} \
	-returns   UINT \
	-args      [list \
			[list -arg -crn -mand 1 -check UINT -desc {The customer's bpay reference number}] \
	]

core::args::register \
	-interface core::payment::BPAY::insert_cpm \
	-desc      {Insert a BPAY customer pay method} \
	-returns   ASCII \
	-args      [list \
		[list -arg -cust_id       -mand 1 -check UINT                           -desc {The customer's cust id}] \
		[list -arg -bpay_crn      -mand 1 -check UINT                           -desc {The customer's bpay reference number}] \
		[list -arg -oper_id       -mand 0 -check ASCII              -default "" -desc {The operator's id}] \
		[list -arg -oper_notes    -mand 0 -check ASCII              -default "" -desc {The operator's notes}] \
		[list -arg -transactional -mand 0 -check {ENUM -args {Y N}} -default Y  -desc {Determines if the execution of the stored procedure is transactional/not}] \
		[list -arg -auth_dep      -mand 0 -check {ENUM -args {Y N}} -default Y  -desc {Determines whether to authorize deposits/not}] \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::BPAY::update_cpm \
	-desc      {Update BPAY customer pay method details} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::BPAY::make_deposit \
	-desc      {Make a deposit via BPAY} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::BPAY::CORE_DEF(acct_id) \
		$::core::payment::BPAY::CORE_DEF(cpm_id) \
		$::core::payment::BPAY::CORE_DEF(unique_id) \
		$::core::payment::BPAY::CORE_DEF(amount) \
		[list -arg -source     -mand 0 -check ASCII -default I  -desc {Channel through which this payment is made}] \
		[list -arg -oper_id    -mand 0 -check ASCII -default {} -desc {Operator's id}] \
		[list -arg -batch_id   -mand 0 -check ASCII -default {} -desc {Identifies the batch of which this payment is a part}] \
		[list -arg -extra_info -mand 0 -check ASCII -default {} -desc {Optional extra info for this payment}] \
		[list -arg -comm_list  -mand 0 -check ASCII -default {} -desc {List of commissions}] \
		[list -arg -ipaddr     -mand 0 -check ASCII -default {} -desc {The ipaddr of the user who made the payment}] \
	]

core::args::register \
	-interface core::payment::BPAY::make_withdrawal \
	-desc      {BPAY credit card withdrawal. Note: the withdrawal is not done via BPAY, the bpay_biller_code is only used to make the withdrawal to a card} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::BPAY::CORE_DEF(acct_id) \
		$::core::payment::BPAY::CORE_DEF(cpm_id) \
		$::core::payment::BPAY::CORE_DEF(unique_id) \
		$::core::payment::BPAY::CORE_DEF(amount) \
		[list -arg -source -mand 1 -check ASCII -desc {Channel through which this payment is made}] \
	]
