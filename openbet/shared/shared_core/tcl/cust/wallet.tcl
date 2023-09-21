# Copyright (C) 2012 OpenBet Technology Ltd. All Rights Reserved.
#
# External Wallet requests
#
# Synopsis:
#   This is the interface for accessing 3rd party wallets
#
set pkg_version 1.0
package provide core::cust::wallet $pkg_version

# Dependencies
package require core::args   1.0
package require core::check  1.0
package require core::log    1.0

core::args::register_ns \
	-namespace core::cust::wallet \
	-version   $pkg_version \
	-dependent [list \
		core::args \
		core::check \
	] \
	-docs xml/wallet/wallet.xml

namespace eval core::cust::wallet {
	variable CORE_DEF
	set CORE_DEF(cust_id)     [list -arg -cust_id   -mand 1 -check UINT   -desc {Customers identifier}]
	set CORE_DEF(oper_id)     [list -arg -oper_id   -mand 0 -check UINT   -default {}  -desc {The Admin operator ID}]
}

# Register wallet interface

core::args::register \
	-interface core::cust::wallet::init \
	-desc {Initialises the wallet package} \
	-args [list]

core::args::register \
	-interface core::cust::wallet::balance \
	-desc {wallet balances} \
	-args [list \
		$::core::cust::wallet::CORE_DEF(cust_id) \
		$::core::cust::wallet::CORE_DEF(oper_id) \
		[list -arg -wallets     -mand 1 -check LIST   -desc {A list of customer wallets}] \
	]\
	-return_data [list \
		[list -arg -balances    -mand 1 -check LIST -default {} -desc {list of dictionaries containing balance info, i.e. -status {} -wallet {} -name {} -balance {} -wtd_funds {} -currency {} -bonus_funds {} -debug {}}] \
	] \
	-errors        [list \
		WALLET_INVALID_ARGUMENTS \
		WALLET_UNKNOWN_PARAM \
		WALLET_CUST_GUEST \
		WALLET_UNKNOWN_WALLET \
	]


core::args::register \
	-interface core::cust::wallet::transfer_funds \
	-desc {Transfer funds between wallets} \
	-args [list \
		$::core::cust::wallet::CORE_DEF(cust_id) \
		$::core::cust::wallet::CORE_DEF(oper_id) \
		[list -arg -amount      -mand 1 -check MONEY  -desc {Transfer amount}] \
		[list -arg -ccy_code    -mand 1 -check ASCII  -desc {Currency code}] \
		[list -arg -from_wallet -mand 1 -check STRING -desc {wallet transferring from}] \
		[list -arg -to_wallet   -mand 1 -check STRING -desc {wallet transferring to}] \
		[list -arg -password    -mand 1 -check STRING -desc {External system password}] \
		[list -arg -promo_code  -mand 0 -default {}   -check ASCII  -desc {Promotional Code}] \
	]\
	-return_data [list \
		[list -arg -xfer_id  -mand 1 -check LIST    -default {} -desc {the unique xfer_id(s) for the transaction}] \
	] \
	-errors        [list \
		WALLET_INVALID_ARGUMENTS \
		WALLET_UNKNOWN_PARAM \
		WALLET_UNKNOWN_WALLET \
		WALLET_INVALID_AMOUNT \
		WALLET_DUPLICATE_WALLET \
		WALLET_TRANS_FAIL \
		WALLET_TRANS_PART_FAIL \
	]

