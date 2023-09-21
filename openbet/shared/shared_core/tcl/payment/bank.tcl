# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Bank payment interface
#
set pkg_version 1.0
package provide core::payment::BANK $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

# This package uses some arg data-types that aren't
# available in the core::check package.

core::args::register_ns \
	-namespace core::payment::BANK \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/BANK.xml

namespace eval core::payment::BANK {
	variable CORE_DEF

	set CORE_DEF(cust_id)                 [list -arg -cust_id             -mand 1 -check UINT                                                                   -desc {The customer id}]
	set CORE_DEF(country_code)            [list -arg -country_code        -mand 1 -check {RE -args {^[A-Z]{2}$}}                                                -desc {Country code of the bank's location}]
	set CORE_DEF(bank_name)               [list -arg -bank_name           -mand 1 -check ASCII                                                                  -desc {The bank's name}]
	set CORE_DEF(bank_name,opt)           [list -arg -bank_name           -mand 0 -check ASCII                              -default {}                         -desc {The bank's name}]
	set CORE_DEF(bank_addr_1)             [list -arg -bank_addr_1         -mand 1 -check ASCII                                                                  -desc {Bank address line 1}]
	set CORE_DEF(bank_addr_2)             [list -arg -bank_addr_2         -mand 1 -check ASCII                                                                  -desc {Bank address line 2}]
	set CORE_DEF(bank_addr_3)             [list -arg -bank_addr_3         -mand 1 -check ASCII                                                                  -desc {Bank address line 3}]
	set CORE_DEF(bank_addr_4)             [list -arg -bank_addr_4         -mand 1 -check ASCII                                                                  -desc {Bank address line 4}]
	set CORE_DEF(acct_name)               [list -arg -acct_name           -mand 1 -check STRING                                                                 -desc {Bank account name}]
	set CORE_DEF(bank_addr_1,opt)         [list -arg -bank_addr_1         -mand 0 -check ASCII                              -default {}                         -desc {Bank address line 1}]
	set CORE_DEF(bank_addr_2,opt)         [list -arg -bank_addr_2         -mand 0 -check ASCII                              -default {}                         -desc {Bank address line 2}]
	set CORE_DEF(bank_addr_3,opt)         [list -arg -bank_addr_3         -mand 0 -check ASCII                              -default {}                         -desc {Bank address line 3}]
	set CORE_DEF(bank_addr_4,opt)         [list -arg -bank_addr_4         -mand 0 -check ASCII                              -default {}                         -desc {Bank address line 4}]
	set CORE_DEF(acct_name,opt)           [list -arg -acct_name           -mand 0 -check STRING                             -default {}                         -desc {Bank account name}]
	set CORE_DEF(bank_city,opt)           [list -arg -bank_city           -mand 0 -check ASCII                              -default {}                         -desc {The bank's city address}]
	set CORE_DEF(bank_postcode,opt)       [list -arg -bank_postcode       -mand 0 -check ASCII                              -default {}                         -desc {The bank's postcode}]
	set CORE_DEF(bsb,opt)                 [list -arg -bsb                 -mand 0 -check {RE -args {^(\d{3}[\s-]?\d{3})?$}} -default {}                         -desc {The bank's bsb number}]
	set CORE_DEF(bank_id)                 [list -arg -bank_id             -mand 1 -check UINT                                                                   -desc {The bank's id in the database}]
	set CORE_DEF(bank_code)               [list -arg -bank_code           -mand 1 -check ASCII                                                                  -desc {The bank code}]
	set CORE_DEF(bank_code,opt)           [list -arg -bank_code           -mand 0 -check ASCII                              -default {}                         -desc {The bank code}]
	set CORE_DEF(acct_num,opt)            [list -arg -acct_num            -mand 0 -check ASCII                              -default {}                         -desc {Account number}]
	set CORE_DEF(country_code,opt)        [list -arg -country_code        -mand 0 -check ASCII                              -default {}                         -desc {Country code of the bank's location}]
	set CORE_DEF(ccy_code,opt)            [list -arg -ccy_code            -mand 0 -check ASCII                              -default {}                         -desc {currency used by the account}]
	set CORE_DEF(swift_code,opt)          [list -arg -swift_code          -mand 0 -check SWIFT                              -default {}                         -desc {the bank's swift code (also known as bic)}]
	set CORE_DEF(status,opt)              [list -arg -status              -mand 0 -check {ENUM -args {A S}}                 -default S                          -desc {the bank's status}]
	set CORE_DEF(site_operator_id,opt)    [list -arg -site_operator_id    -mand 0 -check ASCII                              -default {}                         -desc {id of the site operator}]
	set CORE_DEF(disporder,opt)           [list -arg -disporder           -mand 0 -check ASCII                              -default {}                         -desc {display order of this entry}]
	set CORE_DEF(cpm_id)                  [list -arg -cpm_id              -mand 1 -check ASCII                              -default {}                         -desc {Customer payment method id}]
	set CORE_DEF(iban_code,opt)           [list -arg -iban_code           -mand 0 -check IBAN                               -default {}                         -desc {The iban code of the bank}]
	set CORE_DEF(day_dep_limit,opt)       [list -arg -day_dep_limit       -mand 0 -check DEP_LIMIT                                                              -desc {The daily limit a customer can spend using IDD}]
	set CORE_DEF(dep_limit,opt)           [list -arg -dep_limit           -mand 0 -check DEP_LIMIT                                                              -desc {The limit per transaction for IDD}]
	set CORE_DEF(bank_acct_type,opt)      [list -arg -bank_acct_type      -mand 0 -check ASCII                              -default {}                         -desc {The bank account type (ex. Savings, Current, etc)}]
	set CORE_DEF(txn_id,opt)              [list -arg -txn_id              -mand 0 -check ASCII                              -default {}                         -desc {The transaction ID that links a payment with the bet placement}]
	set CORE_DEF(txn_type,opt)            [list -arg -txn_type            -mand 0 -check {ENUM -args {B S F L X}}                                               -desc {The transaction type for an automated payment}]
	set CORE_DEF(ext_process_date,opt)    [list -arg -ext_process_date    -mand 0 -check LOOSEDATE                          -default {}                         -desc {The date the transaction was processed by the bank}]
	set CORE_DEF(ext_status,opt)          [list -arg -ext_status          -mand 0 -check ASCII                              -default {}                         -desc {The bank's status for the transaction.}]
	set CORE_DEF(ext_reason_code,opt)     [list -arg -ext_reason_code     -mand 0 -check ASCII                              -default {}                         -desc {The response code, if any, associated with external status}]
	set CORE_DEF(ext_batch_seq_no,opt)    [list -arg -ext_batch_seq_no    -mand 0 -check ASCII                              -default {}                         -desc {The batch sequence number of the file received from bank.}]
	set CORE_DEF(adhoc_sweepback,opt)     [list -arg -adhoc_sweepback     -mand 0 -check {ENUM -args {Y N {}}}              -default {}                         -desc {The flag that denotes whether a customer wants an adhoc withdrawal}]
	set CORE_DEF(branch_name,opt)         [list -arg -branch_name         -mand 0 -check ASCII                              -default {}                         -desc {The branch name of the bank}]
	set CORE_DEF(sort_code,opt)           [list -arg -sort_code           -mand 0 -check ASCII                              -default {}                         -desc {The bank's sort code}]
	set CORE_DEF(channel,opt)             [list -arg -channel             -mand 0 -check ASCII                              -default {}                         -desc {The channels for this customer payment method}]
	set CORE_DEF(acct_no,opt)             [list -arg -acct_no             -mand 0 -check ASCII                              -default {}                         -desc {Account number}]
	set CORE_DEF(channel)                 [list -arg -channel             -mand 1 -check ASCII                                                                  -desc {The channels for this customer payment method}]

	# For SPPL there's no moneylaundering check for this payment method, as it's the only payment method used for withdrawals. However, if this payment method is going to be used
	# with other payment methods, i.e. Credit Cards, then we need to make sure that moneylaundering checks and rules will apply!
	set CORE_DEF(sweepback_threshold,opt) [list -arg -sweepback_threshold -mand 0 -check UMONEY                                                                 -desc {The customer's swepback wtd theshold for BDC}]
	set CORE_DEF(sweepback_period,opt)    [list -arg -sweepback_period    -mand 0 -check {ENUM -args {D W M}}                                                   -desc {The customer's swepback wtd period for BDC}]
	set CORE_DEF(bank_codes,opt)          [list -arg -bank_codes          -mand 0 -check ASCII                              -default {} -default_cfg BANK_CODES -desc {The bank names and codes used for the DDA creation}]

	set CORE_DEF(extra_info,opt)          [list -arg -extra_info          -mand 0 -check ASCII                              -default {}                         -desc {Informative note.}]
	set CORE_DEF(ext_reference,opt)       [list -arg -ext_reference       -mand 0 -check ASCII                              -default {}                         -desc {The bank's unique identifier for the transaction.}]
	set CORE_DEF(ext_amount,opt)          [list -arg -ext_amount          -mand 0 -check MONEY                              -default {}                         -desc {The bank's unique identifier for the transaction.}]
	set CORE_DEF(ext_ccy_code,opt)        [list -arg -ext_ccy_code        -mand 0 -check ASCII                              -default {}                         -desc {The bank's unique identifier for the transaction.}]
	set CORE_DEF(initiator,opt)           [list -arg -initiator           -mand 0 -check {ENUM -args {AUTOMATIC CUSTOMER}}  -default {AUTOMATIC}                -desc {The initiator behind a payment either Automatic or by the Customer}]
	set CORE_DEF(type,opt)                [list -arg -type                -mand 0 -check ASCII                              -default {W}                        -desc {Type of the payment}]
	set CORE_DEF(commission,opt)          [list -arg -commission          -mand 0 -check ASCII                              -default 0                          -desc {The commission for this payment}]
	set CORE_DEF(min_override,opt)        [list -arg -min_override        -mand 0 -check ASCII                              -default {N}                        -desc {Minimum override for this payment}]
}

catch {
	# Register data type for SWIFT code.
	core::check::register SWIFT core::payment::BANK::_check_type_SWIFT {}
}
catch {
	# Register data type for IBAN code.
	core::check::register IBAN core::payment::BANK::_check_type_IBAN {}
}
catch {
	# Register data type for dep_limit and day_dep_limit
	core::check::register DEP_LIMIT core::payment::BANK::_check_type_DEP_LIMIT {}
}

# Validate a Swift(BIC) banking codes.
#
#   swift_code - BIC (swift) banking code is "should" be in the format:
#       DEUT       DE            FF             123
#       [bank code][country code][location code][branch code]
#       [A-Z]      [A-Z]         [A-Z1-9]       [A-Z0-9]
#   return - success(0/1)
#
proc core::payment::BANK::_check_type_SWIFT {swift_code args} {
	# Check its of the correct format.
	if {$swift_code == "" || [regexp {^[A-Z]{6}[A-Z1-9]{2}([A-Z0-9]{3})?$} $swift_code]} {
		return 1
	} else {
		return 0
	}
}

# Validate a IBAN banking code.
#   iban_code - IBAN banking code is "should" be in the format:
#       [country code][checksums][country specific account numbers]
#   return - success(0/1)
#
proc core::payment::BANK::_check_type_IBAN  {iban_code args} {
	# Break apart the IBAN string.
	set country_code [string range $iban_code 0 1]
	set chk_sum      [string range $iban_code 2 3]
	set reg_num      [string range $iban_code 4 end]

	# Move first 4 chars to the end of the string for validation.
	set iban_chk_str "${reg_num}${country_code}${chk_sum}"

	# Convert letters to number representation.
	# Convert char codes to a=10, b=11, c=12 etc...
	set iban_chk_no {}
	for {set i 0} {$i < [string length $iban_chk_str]} {incr i} {
		# Get letter in upper case.
		set cur_char [string toupper [string range $iban_chk_str $i $i]]

		if {![string is digit $cur_char]} {
			scan $cur_char "%c" ascii_ccode
			# a=10, b=11, c=12 etc... so minus 55 from its ascii value.
			set iban_chk_no "${iban_chk_no}[expr {$ascii_ccode - 55}]"
		} else {
			set iban_chk_no "${iban_chk_no}${cur_char}"
		}
	}

	# Remove the leading zeros we don't need these.
	set iban_chk_no [string trimleft $iban_chk_no "0"]

	# Do [expr {iban_chk_no % 97}] number to big to do this.
	#   So do old school long division.
	set idx      0
	set rmdr     [string range $iban_chk_no 0 0]
	while {$idx < [string length $iban_chk_no]} {
		if {$rmdr >= 97} {
			set rmdr [expr {$rmdr % 97}]
		} else {
			incr idx
			set rmdr "[expr {$rmdr ? $rmdr : ""}][string range $iban_chk_no $idx $idx]"
		}
	}

	# If the remainder is '1' then it is valid.
	if {$rmdr == 1} {
		return 1
	} else {
		return 0
	}
}

proc core::payment::BANK::_check_type_DEP_LIMIT {amount args} {

	# Amount is valid if it is an empty string or of 'MONEY' type

	variable RE_UMONEY    {^\d+(\.\d{1,2})?$}

	foreach {n v} $args {
		switch -- $n {
			-min_num { set min_num $v }
			-max_num { set max_num $v }
		}
	}

	if {![regexp $RE_UMONEY $amount]} {
			if {$amount != {}} {
				return 0
			}
	}

	if {[info exists min_num] && $amount < $min_num} {
		return 0
	}

	if {[info exists max_num] && $amount > $max_num} {
		return 0
	}

	return 1
}

# Register BANK interface.
core::args::register \
	-interface core::payment::BANK::init \
	-desc      {Initialises the Bank payment method} \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_codes,opt) \
	]

core::args::register \
	-interface core::payment::BANK::get_templates \
	-desc      {Builds and array of bank templates} \
	-args      [list \
		[list -arg -array -mand 1 -check ASCII -desc {The variable which should be populated by the proc}] \
	]

core::args::register \
	-interface core::payment::BANK::check_iban \
	-desc      {Check an IBAN} \
	-returns   ASCII \
	-args      [list \
		[list -arg -iban -mand 1 -check ASCII -desc {The IBAN to check}] \
	]

core::args::register \
	-interface core::payment::BANK::get_bank_template_id \
	-desc      {Get the bank template id for a specific country} \
	-returns   UINT \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(country_code) \
	]

core::args::register \
	-interface core::payment::BANK::get_envoy_template_id \
	-desc      {Get the envoy template id for a specific country} \
	-returns   UINT \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(country_code) \
	]

core::args::register \
	-interface core::payment::BANK::bank_duplicate_check \
	-desc      {Check for a duplicate bank account} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(cust_id) \
		[list -arg -bank_acct_no -mand 1 -check ASCII -desc {The bank account number}] \
		[list -arg -sort_code    -mand 1 -check ASCII -desc {The bank's sort code}] \
	]

core::args::register \
	-interface core::payment::BANK::insert_cpm \
	-desc      {Insert a bank customer payment method} \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(cust_id) \
		$::core::payment::BANK::CORE_DEF(bank_name) \
		$::core::payment::BANK::CORE_DEF(country_code) \
		$::core::payment::BANK::CORE_DEF(bank_city,opt) \
		$::core::payment::BANK::CORE_DEF(bank_postcode,opt) \
		$::core::payment::BANK::CORE_DEF(bsb,opt) \
		$::core::payment::BANK::CORE_DEF(swift_code,opt) \
		$::core::payment::BANK::CORE_DEF(iban_code,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_1) \
		$::core::payment::BANK::CORE_DEF(bank_addr_2) \
		$::core::payment::BANK::CORE_DEF(bank_addr_3) \
		$::core::payment::BANK::CORE_DEF(bank_addr_4) \
		$::core::payment::BANK::CORE_DEF(acct_name) \
		$::core::payment::BANK::CORE_DEF(acct_no,opt) \
		$::core::payment::BANK::CORE_DEF(branch_name,opt) \
		$::core::payment::BANK::CORE_DEF(sort_code,opt) \
		$::core::payment::BANK::CORE_DEF(channel,opt) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::BANK::CORE_DEF(day_dep_limit,opt) \
		$::core::payment::BANK::CORE_DEF(dep_limit,opt) \
		$::core::payment::BANK::CORE_DEF(sweepback_threshold,opt) \
		$::core::payment::BANK::CORE_DEF(sweepback_period,opt) \
		$::core::payment::CORE_DEF(status_dep,opt) \
		$::core::payment::CORE_DEF(status_wtd,opt) \
		$::core::payment::CORE_DEF(auth_dep,opt) \
		$::core::payment::CORE_DEF(auth_wtd,opt) \
		$::core::payment::CORE_DEF(status,opt) \
		$::core::payment::BANK::CORE_DEF(bank_acct_type,opt) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(cpm_id) \
	] \
	-errors [list \
		INVALID_ARGS \
		PMT_DDA_GEN_ERR \
		PMT_ERR_BANK_NO \
		PMT_ERR_BANK_INSERT_CPM \
	]

core::args::register \
	-interface core::payment::BANK::get_cpm_details \
	-desc      {Gets the details of a payment given a valid cpm_id} \
	-returns    LIST \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(cpm_id) \
		$::core::payment::BANK::CORE_DEF(cust_id) \
	]

core::args::register \
	-interface core::payment::BANK::update_cpm \
	-desc      {Update a bank customer payment method} \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(cpm_id) \
		$::core::payment::BANK::CORE_DEF(cust_id) \
		$::core::payment::BANK::CORE_DEF(bank_name,opt) \
		$::core::payment::BANK::CORE_DEF(country_code,opt) \
		$::core::payment::BANK::CORE_DEF(bank_city,opt) \
		$::core::payment::BANK::CORE_DEF(bank_postcode,opt) \
		$::core::payment::BANK::CORE_DEF(bsb,opt) \
		$::core::payment::BANK::CORE_DEF(swift_code,opt) \
		$::core::payment::BANK::CORE_DEF(iban_code,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_1,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_2,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_3,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_4,opt) \
		$::core::payment::BANK::CORE_DEF(acct_name,opt) \
		$::core::payment::BANK::CORE_DEF(acct_no,opt) \
		$::core::payment::BANK::CORE_DEF(branch_name,opt) \
		$::core::payment::BANK::CORE_DEF(sort_code,opt) \
		$::core::payment::BANK::CORE_DEF(channel,opt) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::BANK::CORE_DEF(day_dep_limit,opt) \
		$::core::payment::BANK::CORE_DEF(dep_limit,opt) \
		$::core::payment::BANK::CORE_DEF(sweepback_threshold,opt) \
		$::core::payment::BANK::CORE_DEF(sweepback_period,opt) \
		$::core::payment::CORE_DEF(status_dep,opt) \
		$::core::payment::CORE_DEF(status_wtd,opt) \
		$::core::payment::CORE_DEF(auth_dep,opt) \
		$::core::payment::CORE_DEF(auth_wtd,opt) \
		$::core::payment::CORE_DEF(status,opt) \
		$::core::payment::BANK::CORE_DEF(bank_acct_type,opt) \
		$::core::payment::BANK::CORE_DEF(adhoc_sweepback,opt) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(cpm_id) \
	] \
	-errors [list \
		INVALID_ARGS \
		PMT_ERR_NO_CPM_FOUND \
		PMT_ERR_INVALID_CPM \
		PMT_DB_ERROR \
		PMT_DDA_GEN_ERR \
		PMT_ERR_BANK_NO \
		PMT_ERR_BANK_UPDATE_CPM \
	]

core::args::register \
	-interface core::payment::BANK::insert_pmt \
	-desc      {Insert a bank withdrawal} \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::BANK::CORE_DEF(channel) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::BANK::CORE_DEF(type,opt) \
		$::core::payment::CORE_DEF(ipaddr,opt) \
		$::core::payment::BANK::CORE_DEF(commission,opt) \
		$::core::payment::BANK::CORE_DEF(min_override,opt) \
		$::core::payment::BANK::CORE_DEF(txn_id,opt) \
		$::core::payment::BANK::CORE_DEF(txn_type,opt) \
		$::core::payment::BANK::CORE_DEF(initiator,opt) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	] \
	-errors [list \
		INVALID_ARGS \
		PMT_ERR_OVS \
		PMT_ERR_UNKNOWN_ACCOUNT \
		PMT_ERR_DB \
		PMT_ERR_FUNDING_SERVICE \
		PMT_ERR_UNKNOWN_BALANCE \
		PMT_ERR_INSUFFICIENT_FUND \
		PMT_ERR_NO_ACCT_FOUND \
		PMT_ERR_GEN_DEP_LIMITS \
		PMT_ERR_NO_CPM_FOUND \
		PMT_ERR_DAY_DEP_LIMIT \
		PMT_ERR_DEP_LIMIT \
		PMT_ERR_DDA_NOT_FOUND \
		PMT_ERR_UPD_PMT_STATUS \
		PMT_ERR_SEND_REQUEST \
		PMT_ERR_SYNC_PMT \
		PMT_ERR_PMT_QUEUE \
		PMT_ERR_ASYNC_PMT \
		ERR_ACCT \
		ERR_INVALID_ACCT_TYPE \
		ERR_NO_DAY_LIMIT \
		ERR_DDA_EXPIRED \
		ERR_WTD_CLOSED \
		ERR_DEP_CLOSED \
		ERR_SYNTAX \
		ERR_MAND_FIELD \
		ERR_VERSION \
		ERR_DUPLICATE \
		ERR_MERCH_ID \
		ERR_SYSTEM \
		ERR_VALIDATION \
		ERR_INT_ERROR \
		ERR_DECLINED \
		PMT_ERR_IDD_URL \
		PMT_ERR_IDD_SOCKET \
		PMT_IDD_NO_REQ_ELEMENTS \
		PMT_ERR_INVALID_CPM \
        ]

core::args::register \
	-interface core::payment::BANK::ins_bookmaker_bank \
	-desc      {Insert the bookmaker's bank details. Deposits can be made to this bank.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_name) \
		$::core::payment::BANK::CORE_DEF(bank_code,opt) \
		$::core::payment::BANK::CORE_DEF(acct_name,opt) \
		$::core::payment::BANK::CORE_DEF(bsb,opt) \
		$::core::payment::BANK::CORE_DEF(acct_num,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_1,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_2,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_3,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_4,opt) \
		$::core::payment::BANK::CORE_DEF(bank_city,opt) \
		$::core::payment::BANK::CORE_DEF(bank_postcode,opt) \
		$::core::payment::BANK::CORE_DEF(country_code,opt) \
		$::core::payment::BANK::CORE_DEF(ccy_code,opt) \
		$::core::payment::BANK::CORE_DEF(swift_code,opt) \
		$::core::payment::BANK::CORE_DEF(status,opt) \
		$::core::payment::BANK::CORE_DEF(site_operator_id,opt) \
		$::core::payment::BANK::CORE_DEF(disporder,opt) \
	]

core::args::register \
	-interface core::payment::BANK::upd_bookmaker_bank \
	-desc      {Update the bookmaker's bank details.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_id) \
		$::core::payment::BANK::CORE_DEF(bank_name) \
		$::core::payment::BANK::CORE_DEF(bank_code,opt) \
		$::core::payment::BANK::CORE_DEF(acct_name,opt) \
		$::core::payment::BANK::CORE_DEF(bsb,opt) \
		$::core::payment::BANK::CORE_DEF(acct_num,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_1,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_2,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_3,opt) \
		$::core::payment::BANK::CORE_DEF(bank_addr_4,opt) \
		$::core::payment::BANK::CORE_DEF(bank_city,opt) \
		$::core::payment::BANK::CORE_DEF(bank_postcode,opt) \
		$::core::payment::BANK::CORE_DEF(country_code,opt) \
		$::core::payment::BANK::CORE_DEF(ccy_code,opt) \
		$::core::payment::BANK::CORE_DEF(swift_code,opt) \
		$::core::payment::BANK::CORE_DEF(status,opt) \
		$::core::payment::BANK::CORE_DEF(site_operator_id,opt) \
		$::core::payment::BANK::CORE_DEF(disporder,opt) \
	]

core::args::register \
	-interface core::payment::BANK::del_bookmaker_bank \
	-desc      {Delete a bookmaker's bank from the database.} \
	-returns   LIST \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_id) \
	]

core::args::register \
	-interface {core::payment::BANK::update_pmt} \
	-desc      {Update bank payment details} \
	-return_data [list \
		[list -arg -status -mand 1 -check {ANY}  -desc {Status of request: 1 success, 0 error}] \
	] \
	-errors     [list \
		SYSTEM_ERROR \
		ERR_QUERY_EXEC \
		INVALID_ARGS \
	] \
	-args       [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(status,opt) \
		$::core::payment::BANK::CORE_DEF(extra_info,opt) \
		$::core::payment::BANK::CORE_DEF(ext_reference,opt) \
		$::core::payment::BANK::CORE_DEF(ext_amount,opt) \
		$::core::payment::BANK::CORE_DEF(ext_ccy_code,opt) \
		$::core::payment::BANK::CORE_DEF(ext_batch_seq_no,opt) \
		$::core::payment::BANK::CORE_DEF(ext_process_date,opt) \
		$::core::payment::BANK::CORE_DEF(ext_reason_code,opt) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(reconciled_by,opt) \
		$::core::payment::CORE_DEF(reconciled_at,opt) \
		$::core::payment::CORE_DEF(transactional) \
	]


core::args::register \
	-interface {core::payment::BANK::get_pmt_details} \
	-desc      {Get a bank payment details.
		If the acct_id is being provided then the pmt_id is checked \
		if it belongs to this user. If not an error is returned. \
	} \
	-return_data [list \
		[list -arg -details -mand 1 -check {ANY}  -desc {Dictionary with the details.}] \
	] \
	-errors      [list \
		SYSTEM_ERROR \
		ERR_QUERY_EXEC \
		ERR_PMT_NOT_FOUND \
		INVALID_ARGS \
	] \
	-args       [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(acct_id,opt) \
	]

core::args::register \
	-interface {core::payment::BANK::reconcile_pmt} \
	-desc      {Process bank payments of unknown status.
		This is to be used to validate that the payment status is the correct one.
		e.g. We validate the OB payment status with BANKs status.
		It is expected that this will update customers balance and payment \
		status accordingly.
	} \
	-return_data [list \
		[list -arg -status -mand 1 -check {BOOL} -desc {Status of the responce : 1 success, 0 error}] \
	] \
	-errors      [list \
		SYSTEM_ERROR \
		ERR_QUERY_EXEC \
		ERR_PMT_NOT_FOUND \
		ERR_PMT_INVALID \
		ERR_PMT_INVALID_STATUS \
		INVALID_ARGS \
	] \
	-args       [list \
		$::core::payment::CORE_DEF(pmt_id,opt) \
		$::core::payment::BANK::CORE_DEF(acct_num,opt) \
		$::core::payment::BANK::CORE_DEF(ext_status,opt) \
		$::core::payment::BANK::CORE_DEF(ext_reason_code,opt) \
		$::core::payment::BANK::CORE_DEF(ext_reference,opt) \
		$::core::payment::BANK::CORE_DEF(ext_amount,opt) \
		$::core::payment::BANK::CORE_DEF(ext_ccy_code,opt) \
		$::core::payment::BANK::CORE_DEF(ext_batch_seq_no,opt) \
		$::core::payment::BANK::CORE_DEF(ext_process_date,opt) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(transactional) \
	]

core::args::register \
	-interface core::payment::BANK::post_reconciliation \
	-desc      {Closes all unmatched transactions after BDC file processing has finished} \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_code) \
		$::core::payment::CORE_DEF(oper_id) \
	] \
	-return_data [list \
		[list -arg -no_of_tran -mand 1 -check {INT}  -desc {The number of unmatched transactions}] \
		[list -arg -error_list -mand 0 -check ASCII  -desc {A list with errors occured while trying to close unmatched transactions}] \
	] \
	-errors      [list \
		DB_ERROR \
	]

core::args::register \
	-interface core::payment::BANK::lock_wtd_funds \
	-desc      {Creates BDC payments for each legitimate BDC account in a specific bank} \
	-args      [list \
		$::core::payment::BANK::CORE_DEF(bank_name) \
		[list -arg -ipaddr       -mand 0 -check IPADDR                           -desc {The ipaddr of the user who made the payment}] \
		[list -arg -rerun        -mand 0 -check {EXACT -args {Y N}} -default "N" -desc {Whether we recreate the bank BDC message or it is a new run}] \
		[list -arg -auto_process -mand 0 -check {EXACT -args {Y N}} -default "N" -desc {Whether the BDC process is manual or automatic}] \
	] \
	-return_data [list \
		[list -arg -status       -mand 1 -check ASCII                    -desc {The process status}] \
		[list -arg -pmt_num      -mand 0 -check UINT                     -desc {The number of funds locked}] \
		[list -arg -total_amount -mand 0 -check UMONEY                   -desc {The total amount of funds locked}] \
		[list -arg -errors       -mand 0 -check ASCII                    -desc {A list of errors that might occurred}] \
	] \
	-errors [list \
		BDC_PROCESS_CANT_RUN_TODAY \
		BDC_PROCESS_ALREADY_RUN \
		DB_ERROR \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::BANK::request_adhoc_wtd \
	-desc      {Add a withdrawal to the request queue} \
	-returns   BOOL \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
	] \
	-errors [list \
		DB_ERROR \
		INVALID_ARGS \
	]
