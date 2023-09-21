# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# Click and Buy payment interface
#
set pkg_version 1.0
package provide core::payment::CB $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0
package require core::db      1.0

core::args::register_ns \
	-namespace core::payment::CB \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/CB.xml

# Namespace setup
namespace eval core::payment::CB {
	variable CORE_DEF

	set CORE_DEF(lang) [list -arg -lang -check ASCII -mand 1 -desc {The ISO language for the customer. Given to the API to hint at which language to display.}]
	set CORE_DEF(cb_crn) [list -arg -cb_crn -check ASCII -mand 1 -desc {The Click and Buy Customer Reference Number for the customer}]
	set CORE_DEF(cb_email) [list -arg -cb_email -check ASCII -mand 1 -desc {The Click and Buy registered email for the customer}]
	set CORE_DEF(cb_bdr_id) [list -arg -cb_bdr_id -check ASCII -mand 0 -default {} -desc {Unique BDR ID for the CB transaction - can be empty}]
}

# Register interfaces
core::args::register \
	-interface core::payment::CB::init \
	-desc      {Initialisation procedure for Click and Buy payment method} \
	-allow_rpc 1 \
	-args      [list]

core::args::register \
	-interface core::payment::CB::insert_cpm \
	-desc      {Insert a Click and Buy CPM} \
	-returns   LIST \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CB::CORE_DEF(cb_crn) \
		[list -arg -auth_dep -check {ENUM -args {Y P N}} -mand 1 -desc {Deposit allow status}] \
		[list -arg -auth_wtd -check {ENUM -args {Y P N}} -mand 1 -desc {Withdrawal allow status}] \
		$::core::payment::CB::CORE_DEF(cb_email) \
		$::core::payment::CORE_DEF(transactional) \
	] \

core::args::register \
	-interface core::payment::CB::insert_pmt \
	-desc      {Insert a Click and Buy payment into tPmt} \
	-returns   LIST \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		[list -arg -payment_sort -check {ENUM -args {DEP WTD}} -mand 1 -desc {Payment sort (deposit or withdrawal)}] \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CB::CORE_DEF(cb_bdr_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -min_override -check ASCII -mand 0 -default {N} -desc {Override min for generic insert payment calls}] \
		$::core::payment::CORE_DEF(call_id) \
		[list -arg -product_source -check ASCII -mand 0 -default {XX} -desc {Product source}] \
	] \

core::args::register \
	-interface core::payment::CB::make_credit_request \
	-desc      {Build a creditRequest Click and Buy SOAP API call and send it} \
	-returns   LIST \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CB::CORE_DEF(cb_crn) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CB::CORE_DEF(lang) \
	]

core::args::register \
	-interface core::payment::CB::make_pay_request \
	-desc      {Build a payRequest Click and Buy SOAP API call and send it} \
	-returns   LIST \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CB::CORE_DEF(lang) \
		[list -arg -product_source -check ASCII -mand 0 -default {XX} -desc {Product source}] \
	]

core::args::register \
	-interface core::payment::CB::make_status_request \
	-desc      {Update the status of a CB payment via an API statusRequest} \
	-returns   LIST \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(ccy_code) \
	]

core::args::register \
	-interface core::payment::CB::update_pmt \
	-desc      {Update a Click and Buy payment in tPmt} \
	-returns   INT \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(transactional) \
	]

