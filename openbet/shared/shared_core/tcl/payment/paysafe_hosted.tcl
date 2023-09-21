# Copyright (C) 2016 OpenBet Technologies Ltd. All Rights Reserved.
#
# PaySafe Hosted Payment interface
#
set pkg_version 1.0
package provide core::payment::PSHP $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0
package require core::db      1.0

core::args::register_ns \
	-namespace core::payment::PSHP \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log     \
		core::args    \
		core::check   \
	] \
	-docs xml/payment/PSHP.xml

namespace eval core::payment::PSHP {
	variable CORE_DEF

	# Mandatory argument definitions
	set CORE_DEF(type) [list -arg -type -mand 1 -check ASCII -desc {Type of Paysafe Hosted Payment}]

	# Optional argument definitions
	set CORE_DEF(system,opt)      [list -arg -system      -mand 0 -check ASCII                                -default {} -desc {System Name of originating request. References tXSysHost / tXSystem}]
	set CORE_DEF(extra,opt)       [list -arg -extra       -mand 0 -check ASCII                                -default {} -desc {Optional extra info for this payment. Should be list or dict}]
	set CORE_DEF(card_no,opt)     [list -arg -card_no     -mand 0 -check {RE -args {\d|^$}}                   -default {} -desc {Card number captured by the front end and will be passed through to Paysafe to be stored via their Vault Card API}]
	set CORE_DEF(expiry_date,opt) [list -arg -expiry_date -mand 0 -check {RE -args {(0[1-9]|1[0-2])/\d\d|^$}} -default {} -desc {Expiry date of the card}]
}

# Register PaySafe Hosted Payment interface
core::args::register \
	-interface core::payment::PSHP::init \
	-allow_rpc 1 \
	-desc      {Initialisation procedure for PaySafe Hosted Payment method}

core::args::register \
	-interface core::payment::PSHP::insert_cpm \
	-desc      {Register a new PaySafe Hosted Payment method for a customer} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id)               \
		$::core::payment::CORE_DEF(oper_id)               \
		$::core::payment::PSHP::CORE_DEF(type)            \
		$::core::payment::PSHP::CORE_DEF(card_no,opt)     \
		$::core::payment::PSHP::CORE_DEF(expiry_date,opt) \
	]

core::args::register \
	-interface core::payment::PSHP::update_cpm \
	-desc      {Update a PaySafe Hosted Payment method} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id)  \
		$::core::payment::CORE_DEF(oper_id) \
	]

core::args::register \
	-interface core::payment::PSHP::remove_cpm \
	-desc      {Remove a PaySafe Hosted method} \
	-allow_rpc 1 \
	-returns   BOOL \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id)  \
		$::core::payment::CORE_DEF(oper_id) \
	]

core::args::register \
	-interface core::payment::PSHP::get_cpm \
	-desc      {Get PaySafe Hosted method details} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id)  \
	]

core::args::register \
	-interface core::payment::PSHP::make_deposit \
	-desc      {Make a PaySafe Hosted Payment deposit} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id)          \
		$::core::payment::CORE_DEF(unique_id)        \
		$::core::payment::CORE_DEF(amount)           \
		$::core::payment::CORE_DEF(cpm_id)           \
		$::core::payment::CORE_DEF(source)           \
		$::core::payment::CORE_DEF(oper_id)          \
		$::core::payment::CORE_DEF(ipaddr,opt)       \
		$::core::payment::PSHP::CORE_DEF(system,opt) \
		$::core::payment::PSHP::CORE_DEF(extra,opt)  \
	]

core::args::register \
	-interface core::payment::PSHP::make_withdrawal \
	-desc      {Make a PaySafe Hosted Payment withdrawal} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id)          \
		$::core::payment::CORE_DEF(unique_id)        \
		$::core::payment::CORE_DEF(amount)           \
		$::core::payment::CORE_DEF(cpm_id)           \
		$::core::payment::CORE_DEF(source)           \
		$::core::payment::CORE_DEF(oper_id)          \
		$::core::payment::CORE_DEF(ipaddr,opt)       \
		$::core::payment::PSHP::CORE_DEF(system,opt) \
		$::core::payment::PSHP::CORE_DEF(extra,opt)  \
	]

core::args::register \
	-interface core::payment::PSHP::complete_transaction \
	-desc      {Complete a PaySafe Hosted Payment transaction after user has entered details via hosted payment page} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(pmt_id)  \
		$::core::payment::CORE_DEF(oper_id) \
	]

