# Copyright (C) 2012 Orbis Technology Ltd. All Rights Reserved.
#
# Core payment functionality
#
#
set pkg_version 1.0
package provide core::payment $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::payment \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/payment.xml

namespace eval core::payment {

	variable CORE_DEF

	set CORE_DEF(cust_id)            [list -arg -cust_id            -mand 1 -check UINT                                        -desc {Customer identifier}]
	set CORE_DEF(amount)             [list -arg -amount             -mand 1 -check MONEY                                       -desc {The payment amount}]
	set CORE_DEF(source)             [list -arg -source             -mand 0 -check ASCII                          -default {I} -desc {Source / Channel}]
	set CORE_DEF(cpm_id)             [list -arg -cpm_id             -mand 1 -check UINT                                        -desc {The customers Customer Payment Method ID}]
	set CORE_DEF(pmt_id)             [list -arg -pmt_id             -mand 1 -check UINT                                        -desc {The payment ID}]
	set CORE_DEF(ccy_code)           [list -arg -ccy_code           -mand 1 -check ASCII                                       -desc {The customers OpenBet Currency Code}]
	set CORE_DEF(ipaddr)             [list -arg -ipaddr             -mand 1 -check IPADDR                                      -desc {The ipaddr of the user who made the payment}]
	set CORE_DEF(acct_id)            [list -arg -acct_id            -mand 1 -check UINT                                        -desc {The customer acct_id}]
	set CORE_DEF(payment_sort)       [list -arg -payment_sort       -mand 1 -check {ENUM -args {D W}}                          -desc {Whether the payment is a Deposit (D) or Withdrawal (W)}]
	set CORE_DEF(unique_id)          [list -arg -unique_id          -mand 1 -check ASCII                                       -desc {An ID value that uniquely idenitifies an OpenBet payment}]
	set CORE_DEF(oper_id)            [list -arg -oper_id            -mand 0 -check INT                            -default {}  -desc {The Admin operator ID}]
	set CORE_DEF(comm_list)          [list -arg -comm_list          -mand 0 -check ASCII                          -default {}  -desc {List of commission values}]
	set CORE_DEF(transactional)      [list -arg -transactional      -mand 0 -check {EXACT -args {Y N}}            -default Y   -desc {Whether the execution of the stored proc is transactional or not}]
	set CORE_DEF(min_overide)        [list -arg -min_overide        -mand 0 -check {ENUM -args {Y N}}             -default N   -desc {whether this payment is allowed to overide the minimum withdrawal limits}]
	set CORE_DEF(call_id)            [list -arg -call_id            -mand 0 -check UINT                           -default {}  -desc {If this is a telebetting transaction, tCall.call_id for this}]
	set CORE_DEF(status)             [list -arg -status             -mand 1 -check {STRING -min_str 1 -max_str 1}              -desc {Payment status}]
	set CORE_DEF(pmt_receipt_func)   [list -arg -pmt_receipt_func   -mand 0 -check BOOL                           -default 0   -desc {Enable payment receipts}]
	set CORE_DEF(pmt_receipt_format) [list -arg -pmt_receipt_format -mand 0 -check BOOL                           -default 0   -desc {Payment receipt format}]
	set CORE_DEF(pmt_receipt_tag)    [list -arg -pmt_receipt_tag    -mand 0 -check {STRING -min_str 1 -max_str 1} -default {}  -desc {Payment receipt tag}]
	set CORE_DEF(monitor)            [list -arg -monitor            -mand 0 -check BOOL                           -default 0   -desc {Monitor enabled}]
	set CORE_DEF(payment_ticker)     [list -arg -payment_ticker     -mand 0 -check BOOL                           -default 0   -desc {Payment ticker enabled}]
	set CORE_DEF(country_code)       [list -arg -country_code       -mand 1 -check STRING                                      -desc {Country Code}]
	set CORE_DEF(nickname)           [list -arg -nickname           -mand 1 -check STRING                         -default {}  -desc {Nickname to identify for the customer payment method}]
	set CORE_DEF(new_cpm_status)     [list -arg -new_cpm_status     -mand 1 -check {AZ -min_str 1 -max_str 1}     -default {}  -desc {New status for customer payment method}]
	set CORE_DEF(pay_mthd)           [list -arg -pay_mthd           -mand 1 -check ASCII                                       -desc {Definition of the payment method {e.g. CC, BANK etc}}]
	set CORE_DEF(auth_dep)           [list -arg -auth_dep           -mand 1 -check {ENUM -args {Y P N}}                        -desc {tCustPayMthd.auth_dep}]
	set CORE_DEF(status_dep)         [list -arg -status_dep         -mand 1 -check {STRING -min_str 1 -max_str 1}              -desc {Deposit status}]

	# Newly added optional arguments should be defined here and follow the
	# "*,opt" array key naming convention
	set CORE_DEF(cust_id,opt)          [list -arg -cust_id          -mand 0 -check UINT                           -default {}  -desc {Customer identifier}]
	set CORE_DEF(nickname,opt)         [list -arg -nickname         -mand 0 -check STRING                         -default {}  -desc {Nickname to identify for the customer payment method}]
	set CORE_DEF(new_cpm_status,opt)   [list -arg -new_cpm_status   -mand 0 -check {AZ -min_str 1 -max_str 1}     -default {}  -desc {New status for customer payment method}]
	set CORE_DEF(oper_username,opt)    [list -arg -oper_username    -mand 0 -check STRING                         -default {}  -desc {Admin operator username}]
	set CORE_DEF(auth_dep,opt)         [list -arg -auth_dep         -mand 0 -check {ENUM -args {Y P N {}}}        -default {}  -desc {tCustPayMthd.auth_dep}]
	set CORE_DEF(auth_wtd,opt)         [list -arg -auth_wtd         -mand 0 -check {ENUM -args {Y P N {}}}        -default {}  -desc {tCustPayMthd.auth_wtd}]
	set CORE_DEF(amount,opt)           [list -arg -amount           -mand 0 -check MONEY                          -default {}  -desc {The payment amount}]
	set CORE_DEF(cpm_id,opt)           [list -arg -cpm_id           -mand 0 -check UINT                           -default {}  -desc {The customers Customer Payment Method ID}]
	set CORE_DEF(pmt_id,opt)           [list -arg -pmt_id           -mand 0 -check UINT                           -default {}  -desc {The payment ID}]
	set CORE_DEF(ccy_code,opt)         [list -arg -ccy_code         -mand 0 -check ASCII                          -default {}  -desc {The customers OpenBet Currency Code}]
	set CORE_DEF(ipaddr,opt)           [list -arg -ipaddr           -mand 0 -check IPADDR                         -default {}  -desc {The ipaddr of the user who made the payment}]
	set CORE_DEF(acct_id,opt)          [list -arg -acct_id          -mand 0 -check UINT                           -default {}  -desc {The customer acct_id}]
	set CORE_DEF(unique_id,opt)        [list -arg -unique_id        -mand 0 -check ASCII                          -default {}  -desc {An ID value that uniquely idenitifies an OpenBet payment}]
	set CORE_DEF(order_dep,opt)        [list -arg -order_dep        -mand 0 -check INT                            -default {}  -desc {}]
	set CORE_DEF(order_wtd,opt)        [list -arg -order_wtd        -mand 0 -check INT                            -default {}  -desc {}]
	set CORE_DEF(status_dep,opt)       [list -arg -status_dep       -mand 0 -check {STRING -min_str 1 -max_str 1} -default {}  -desc {Deposit status}]
	set CORE_DEF(status_wtd,opt)       [list -arg -status_wtd       -mand 0 -check {STRING -min_str 1 -max_str 1} -default {}  -desc {Withdrawal status}]
	set CORE_DEF(oper_notes,opt)       [list -arg -oper_notes       -mand 0 -check ASCII                          -default {}  -desc {Operator's notes}]
	set CORE_DEF(disallow_dep_rsn,opt) [list -arg -disallow_dep_rsn -mand 0 -check ASCII                          -default {}  -desc {Comment on why the deposit method is not allowed}]
	set CORE_DEF(disallow_wtd_rsn,opt) [list -arg -disallow_wtd_rsn -mand 0 -check ASCII                          -default {}  -desc {Comment on why the withdrawal method is not allowed}]
	set CORE_DEF(country_code,opt)     [list -arg -country_code     -mand 0 -check ASCII                          -default {}  -desc {Country Code}]
	set CORE_DEF(status,opt)           [list -arg -status           -mand 0 -check {STRING -min_str 1 -max_str 1} -default {}  -desc {Payment status}]
	set CORE_DEF(pay_mthd,opt)         [list -arg -pay_mthd         -mand 0 -check ASCII                          -default {}  -desc {Definition of the payment method {e.g. CC, BANK etc}}]
	set CORE_DEF(reconciled_by,opt)    [list -arg -reconciled_by    -mand 0 -check ASCII                          -default {}  -desc {Operator's ID who performed reconciliation}]
	set CORE_DEF(reconciled_at,opt)    [list -arg -reconciled_at    -mand 0 -check LOOSEDATE                      -default {}  -desc {Date and time at which reconciliation was performed}]
	set CORE_DEF(description,opt)      [list -arg -description      -mand 0 -check ASCII                          -default {}  -desc {Description for payment}]
}

# Define the init procedure
core::args::register \
	-interface core::payment::init \
	-desc      {Initialise the payment package} \
	-mand_impl 0

# Get details of how to split a withdrawal into smaller withdrawals in order to satisfy withdrawal restrictions
core::args::register \
	-interface core::payment::get_split_withdrawal \
	-desc      {Get details of how to split a withdrawal into smaller withdrawals in order to satisfy withdrawal restrictions} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(cpm_id,opt) \
		[list -arg -cust_balance    -mand 1 -check MONEY                            -desc {Customer's current balance}] \
		[list -arg -return_all_cpms -mand 0 -check {EXACT -args {Y N}} -default {N} -desc {Whether or not to always return all the customer's payment methods}] \
	]

# Attempt to make the multiple withdrawals defined in a split withdrawal
core::args::register \
	-interface core::payment::make_split_withdrawal \
	-desc      {Attempt to make the multiple withdrawals defined in a split withdrawal} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(ipaddr,opt) \
		$::core::payment::CORE_DEF(source) \
		[list -arg -payment_list -mand 1 -check ASCII -desc {List containing the payment split. Consists of pairs of the form: cpm_id amount}] \
	]

# Get details about the customer's registered payment methods
core::args::register \
	-interface core::payment::get_registered_methods \
	-desc      {Get details about the customer's registered payment methods} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(source)  \
		[list -arg -cpm_ids -mand 0 -check ASCII -desc {List containing payment method IDs to get details for}] \
	]

# Get a list of payment ids that can be reversed/cancelled.
core::args::register \
	-interface core::payment::get_reversible_payments \
	-desc      {Get a list of payments that can be reversed} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		[list -arg -start_time -mand 0 -check DATETIME -desc {Start datetime to look for reversable payments}] \
		[list -arg -end_time   -mand 0 -check DATETIME -desc {End datetime to look for reversable payments}] \
	]

# Cancel a payment
core::args::register \
	-interface core::payment::cancel_payment \
	-desc      {Cancel a payment} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(transactional) \
	]

# Check if a customer can add a new cpm
core::args::register \
	-interface core::payment::can_insert_cpm \
	-desc      {Check if a customer can add a new cpm} \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(ccy_code,opt) \
		$::core::payment::CORE_DEF(country_code,opt) \
		$::core::payment::CORE_DEF(pay_mthd) \
		[list -arg -cpm_type          -mand 1 -check ASCII               -desc {Define the type of the cpm like tCustPayMthd.type {e.g. UK}}] \
		[list -arg -card_no           -mand 0 -check UINT   -default {}  -desc {Card number if it is cc}] \
		[list -arg -check_max_methods -mand 0 -check BOOL   -default {1} -desc {Define if we have to check that total cpms match with max cpm}] \
		[list -arg -msg_type          -mand 0 -check ASCII  -default {}  -desc {Defines the action customer performed and will be used by cpm rules}] \
	] \
	-return_data [list \
		[list -arg -status   -mand 1  -check {EXACT -args {OK}}  -desc {The original status value}] \
	] \
	-errors [list \
		DB_ERROR \
		CANNOT_INSERT \
		MAX_CPM_ALLOWED \
		DUPLICATE_CPM \
		CPM_ADD_ERROR \
	]

# Check if the cpm can be updated to X(deleted) if status is "X" else check if it is D(ormant) or A(ctive) or not provided in order to be able to update the nickname
core::args::register \
	-interface core::payment::can_update_cpm \
	-desc      {Check if the cpm is Active or Dormant in order to be updated} \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		[list -arg -status -mand 0 -check {RE -args {^[A-Z]$}} -desc {Payment method's new status value. e.g. "A", "D", "X"}] \
	] \
	-return_data [list \
		[list -arg -status -mand 1 -check {EXACT -args {OK}}   -desc {The original status value}] \
	] \
	-errors [list \
		DB_ERROR \
		CPM_NOT_FOUND \
		CPM_ALREADY_DELETED \
		NET_DEPOSIT_POSITIVE \
		NET_DEPOSIT_ERROR \
		ERROR_CPM_CHK_XSYSFER \
		ERROR_CPM_CHK_BALANCE \
		ERROR_CPM_CHK_UNSETTLEDBETS \
		ERROR_CPM_CHK_GAMESMULTISTATE \
		ERROR_CPM_CHK_PENDINGPMTS \
		ERROR_CPM_CHK_BALLSSUB \
		ERROR_CPM_CHK_PTECH_POKER \
		ERROR \
	]

# Check if customer is able to make the payment, either deposit or withdrawal
core::args::register \
	-interface core::payment::can_make_payment \
	-desc      {Check if customer can make the payment} \
	-args [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(payment_sort) \
	] \
	-return_data [list \
		[list -arg -status -mand 1 -check {EXACT -args {OK}} -desc {The original status value}] \
	] \
	-errors [list \
		DB_ERROR \
		WTD_FROM_DEP_ONLY \
		CALC_ERROR \
		WTD_BELOW_MIN_DEP \
		WTD_NOT_POSSIBLE \
		NET_DEPOSIT_ERROR \
		ERROR \
	]

# A generic interface to lock funds via funding service that can be called by different withdrawal methods
core::args::register \
	-interface core::payment::lock_funds_using_fs \
	-desc      {Locks funds through funding service} \
	-args [list \
		$::core::payment::CORE_DEF(cust_id,opt) \
		$::core::payment::CORE_DEF(acct_id,opt) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(description,opt) \
	] \
	-errors [list \
		INVALID_ARGS \
		DB_ERROR \
		INVALID_CUSTOMER_CREDENTIALS \
	]