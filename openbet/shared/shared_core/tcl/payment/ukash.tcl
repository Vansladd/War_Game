# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# UKash payment interface
#
set pkg_version 1.0
package provide core::payment::UKSH $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::UKSH \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/UKSH.xml

namespace eval core::payment::UKSH {
	variable CORE_DEF

	# UKash specific parameters
	set CORE_DEF(max_ukash_fails) [list -arg -max_ukash_fails -mand 0 -check BOOL                     -default 3 -desc {Max number of logged UKash fails}]
	set CORE_DEF(pmt_mthd_code)   [list -arg -pmt_mthd_code   -mand 1 -check {ENUM -args {UKSH IKSH}}            -desc {Which UKash payment method to register UKSH or IKSH}]
	set CORE_DEF(voucher)         [list -arg -voucher         -mand 1 -check UINT                                -desc {UKash voucher digits}]
	set CORE_DEF(value)           [list -arg -value           -mand 1 -check MONEY                               -desc {Value of the UKash voucher}]
}

# Register UKash interface
core::args::register \
	-interface core::payment::UKSH::init \
	-desc      {Initialise the UKash payment interface} \
	-args      [list \
		$::core::payment::CORE_DEF(monitor) \
		$::core::payment::CORE_DEF(pmt_receipt_func) \
		$::core::payment::CORE_DEF(pmt_receipt_format) \
		$::core::payment::CORE_DEF(pmt_receipt_tag) \
		$::core::payment::UKSH::CORE_DEF(max_ukash_fails) \
		[list -arg -add_txn_point           -mand 0 -check BOOL -default 0 -desc {Enable insert of flag on point of payment}] \
		[list -arg -card_age_wtd_block      -mand 0 -check BOOL -default 0 -desc {Block withdrawals before age verification}] \
		[list -arg -func_remove_cpm_on_fail -mand 0 -check BOOL -default 1 -desc {Enable removal of the cpm when a payment fails and no previous successful payments}] \
	]

core::args::register \
	-interface core::payment::UKSH::insert_cpm \
	-desc      {Register a new UKash payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::UKSH::CORE_DEF(pmt_mthd_code) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(transactional) \
		[list -arg -auth_dep      -mand 0 -check {ENUM -args {Y N P}} -default N   -desc {Deposit authorisation status}] \
        [list -arg -auth_wtd      -mand 0 -check {ENUM -args {Y N P}} -default N   -desc {Withdrawal authorisation status}] \
		[list -arg -balance_check -mand 0 -check {ENUM -args {Y N}}   -default N   -desc {Perform balance check on payments}] \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::UKSH::update_cpm \
	-desc      {Update a UKash customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::UKSH::remove_cpm \
	-desc      {Remove the registered cpm} \
	-returns   UINT \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
	]

core::args::register \
	-interface core::payment::UKSH::make_deposit \
	-desc      {Perform a UKash deposit} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::UKSH::CORE_DEF(voucher) \
		$::core::payment::UKSH::CORE_DEF(value) \
		[list -arg -amount_ref -mand 1 -check UINT  -desc {Amount reference for the voucher}] \
	]

core::args::register \
	-interface core::payment::UKSH::make_withdrawal \
	-desc      {Perform a UKash withdrawal} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(oper_id) \
	]

core::args::register \
	-interface core::payment::UKSH::update_pmt \
	-desc      {Update a UKash payment} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(transactional) \
		[list -arg -voucher     -mand 0 -check UINT  -default {}  -desc {UKash voucher digits}] \
		[list -arg -value       -mand 0 -check MONEY -default {}  -desc {Value of the UKash voucher}] \
		[list -arg -txn_id      -mand 1 -check ASCII              -desc {UKash provided transaction id}] \
		[list -arg -err_code    -mand 1 -check INT                -desc {UKash provided error code}] \
		[list -arg -expiry      -mand 0 -check DATE  -default {}  -desc {Voucher expiry date}] \
		[list -arg -flag_cancel -mand 0 -check {ENUM -args {Y N}} -desc {Flag that the payment has been cancelled}] \
	]

core::args::register \
	-interface core::payment::UKSH::valid_voucher \
	-desc      {Check if the specified voucher is valid} \
	-returns   UINT \
	-args      [list \
		$::core::payment::UKSH::CORE_DEF(voucher) \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	]

core::args::register \
	-interface core::payment::UKSH::get_settle_amount \
	-desc      {Make a GetSettlerAmount request} \
	-returns   STRING \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::UKSH::CORE_DEF(voucher) \
		$::core::payment::UKSH::CORE_DEF(value) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(source) \
		[list -arg -arr_ref -mand 0 -check AZ -default {UKASH} -desc {Name of array to store data}] \
	]

core::args::register \
	-interface core::payment::UKSH::issue_voucher \
	-desc      {Issue a UKash voucher} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -arr_ref -mand 0 -check AZ -default {UKASH} -desc {Name of array to store data}] \
	]
