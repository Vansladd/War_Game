# Copyright (C) 2015 Orbis Technology Ltd. All Rights Reserved.
#
# Interface for Cash payments
#
#
set pkg_version 1.0
package provide core::payment::CSH $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log      1.0
package require core::args     1.0

core::args::register_ns \
	-namespace core::payment::CSH \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::args \
		core::log \
	] \
	-docs "xml/payment/CSH.xml"

namespace eval core::payment::CSH {
	variable CORE_DEF
}

# core::payment::CSH::init
#
# Interface for one time initialisation of cash payments
#
core::args::register \
	-interface core::payment::CSH::init \
	-desc      {Initialise cash payments interface} \
	-args [list \
		[list -arg -max_cash_wtd               -mand 0 -check INT    -default 5000 -default_cfg MAX_CASH_WTD               -desc {Maximum amount allowed for cash withdrawal}] \
		[list -arg -locale                     -mand 0 -check STRING -default {en} -default_cfg LOCALE                     -desc {Language}] \
	]

# core::payment::CSH::make_withdrawal
#
# Interface for making a cash withdrawal request
#
core::args::register \
	-interface core::payment::CSH::make_withdrawal \
	-desc      {Make a cash withdrawal transaction} \
	-allow_rpc 1 \
	-errors     [list \
		PMT_ERR_INTERNAL_ERROR \
		PMT_ERR_DB_ERROR \
		PMT_ERR_ERROR \
		PMT_ERR_INVALID_CUST_ID \
		PMT_ERR_CUST_SELF_EXCLUDED \
		PMT_ERR_INVALID_CPM_ID \
		PMT_ERR_CPM_NOT_FOUND \
		PMT_ERR_MULTIPLE_CPM_IDS \
		PMT_ERR_INVALID_AMT \
		INVALID_ARGS \
	] \
	-args [list \
		$::core::payment::CORE_DEF(cust_id)   \
		$::core::payment::CORE_DEF(ipaddr)    \
		$::core::payment::CORE_DEF(source)    \
		$::core::payment::CORE_DEF(oper_id)   \
		$::core::payment::CORE_DEF(unique_id) \
		[list -arg -amount        -mand 1 -check MONEY               -desc {Amount requested for withdrawal}]                             \
		[list -arg -cpm_id        -mand 0 -check UINT   -default {}  -desc {Customer's payment method for cash}]                          \
		[list -arg -transactional -mand 0 -check STRING -default {Y} -desc {Denotes if it is within a transaction or not}]                \
		[list -arg -outlet        -mand 0 -check STRING -default {}  -desc {Outlet from where the withdrawal amount should be collected}] \
		[list -arg -loc_code      -mand 0 -check ASCII  -default {}  -desc {Location code of the outlet}]                                 \
		[list -arg -extra_info    -mand 0 -check STRING -default {}  -desc {Any extra information about cash withdrawal}]                 \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]

# core::payment::CSH::make_deposit
#
# Interface for making a cash deposit request
#
core::args::register \
	-interface core::payment::CSH::make_deposit \
	-desc      {Make a cash deposit transaction} \
	-allow_rpc 1 \
	-errors     [list \
		PMT_ERR_INTERNAL_ERROR \
		PMT_ERR_DB_ERROR \
		PMT_ERR_ERROR \
		PMT_ERR_INVALID_CUST_ID \
		PMT_ERR_CUST_SELF_EXCLUDED \
		PMT_ERR_INVALID_CPM_ID \
		PMT_ERR_CPM_NOT_FOUND \
		PMT_ERR_MULTIPLE_CPM_IDS \
		PMT_ERR_INVALID_AMT \
		INVALID_ARGS \
	] \
	-args [list \
		$::core::payment::CORE_DEF(cust_id)   \
		$::core::payment::CORE_DEF(ipaddr)    \
		$::core::payment::CORE_DEF(source)    \
		$::core::payment::CORE_DEF(oper_id)   \
		$::core::payment::CORE_DEF(unique_id) \
		[list -arg -amount        -mand 1 -check MONEY                            -desc {Amount requested for withdrawal}]                             \
		[list -arg -cpm_id        -mand 0 -check UINT                -default {}  -desc {Customer's payment method for cash}]                          \
		[list -arg -transactional -mand 0 -check {EXACT -args {Y N}} -default {Y} -desc {Denotes if it is within a transaction or not}]                \
		[list -arg -outlet        -mand 0 -check STRING              -default {}  -desc {Outlet from where the withdrawal amount should be collected}] \
		[list -arg -loc_code      -mand 0 -check ASCII               -default {}  -desc {Location code of the outlet}]                                 \
		[list -arg -extra_info    -mand 0 -check STRING              -default {}  -desc {Any extra information about cash withdrawal}]                 \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]

# core::payment::CSH::complete_withdrawal
#
# Interface for completing a cash withdrawal request
#
core::args::register \
	-interface core::payment::CSH::complete_withdrawal \
	-desc      {Complete a cash withdrawal transaction} \
	-allow_rpc 1 \
	-errors    [list \
		PMT_ERR_DB_ERROR \
		INVALID_ARGS \
	] \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -transactional    -mand 0 -check {EXACT -args {Y N}}  -default {Y}  -desc {Denotes if it is within a transaction or not}] \
		[list -arg -collect_time     -mand 0 -check DATETIME             -default {}   -desc {Time at which the cash is collected from the outlet}] \
		[list -arg -manager          -mand 0 -check STRING               -default {}   -desc {Manager who approves the payment}] \
		[list -arg -id_serial_no     -mand 0 -check STRING               -default {}   -desc {Serial number for the payment}] \
		[list -arg -outlet           -mand 0 -check STRING               -default {}   -desc {Outlet from where the withdrawal amount should be collected}] \
		[list -arg -loc_code         -mand 0 -check ASCII                -default {}   -desc {Location code of the outlet}] \
		[list -arg -extra_info       -mand 0 -check STRING               -default {}   -desc {Any extra information about cash withdrawal}] \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]

# core::payment::CSH::cancel_withdrawal
#
# Interface for cancelling a cash withdrawal request
#
core::args::register \
	-interface core::payment::CSH::cancel_withdrawal \
	-desc      {Cancel a cash withdrawal transaction} \
	-allow_rpc 1 \
	-errors    [list \
		PMT_ERR_DB_ERROR \
		INVALID_ARGS \
	] \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id)  \
		$::core::payment::CORE_DEF(acct_id) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]


# core::payment::CSH::get_withdrawal_requests
#
# Interface for getting withdrawal requests data
#
core::args::register \
	-interface core::payment::CSH::get_withdrawal_requests \
	-desc      {get all pending cash withdrwal requests} \
	-errors    [list \
		PMT_ERR_DB_ERROR \
		INVALID_ARGS \
	] \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
	] \
	-return_data [list \
		[list -arg -wtd_data  -mand 1 -check LIST -default {} -desc {the data of withdrawal requests}] \
	]
