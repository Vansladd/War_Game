# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Cheque payment interface
#

set pkg_version 1.0
package provide core::payment::CHQ $pkg_version


# Dependencies
package require core::payment 1.0
package require core::args    1.0


core::args::register_ns \
	-namespace core::payment::CHQ \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/CHQ.xml

namespace eval core::payment::CHQ {
	variable CORE_DEF
}


#Register Cheque interface
core::args::register \
	-interface core::payment::CHQ::init \
	-desc      {Initialisation procedure for Cheque payment method}


core::args::register \
	-interface core::payment::CHQ::insert_cpm \
	-desc      {Add a cheque payment method} \
	-returns    ASCII \
	-args      [list \
		$core::payment::CORE_DEF(cust_id) \
		$core::payment::CORE_DEF(oper_id) \
		[list -arg -oper_notes -mand 0 -check STRING -default {} -desc {Notes about the payment method}] \
		$core::payment::CORE_DEF(country_code) \
		[list -arg -payee -mand 1 -check STRING  -desc {Payee name}] \
		[list -arg -addr_street_1 -mand 1 -check STRING  -desc {Address line 1}] \
		[list -arg -addr_street_2 -mand 0 -check STRING  -desc {Address line 2}] \
		[list -arg -addr_street_3 -mand 0 -check STRING  -desc {Address line 3}] \
		[list -arg -addr_street_4 -mand 0 -check STRING  -desc {Address line 4}] \
		[list -arg -addr_city -mand 1 -check STRING  -desc {City}] \
		[list -arg -addr_postcode -mand 1 -check STRING  -desc {Postcode}] \
		[list -arg -auth_dep -mand 0 -check {ENUM -args {Y N P}}  -default {P} -desc {}] \
		[list -arg -auth_wtd -mand 0 -check {ENUM -args {Y N P}}  -default {P} -desc {}] \
		$::core::payment::CORE_DEF(nickname,opt) \
	]


core::args::register \
	-interface core::payment::CHQ::update_cpm \
	-desc      {Update cheque details.} \
	-returns    ASCII \
	-args      [list \
		$core::payment::CORE_DEF(cust_id) \
		$core::payment::CORE_DEF(cpm_id) \
		$core::payment::CORE_DEF(oper_id) \
		$core::payment::CORE_DEF(country_code) \
		$::core::payment::CORE_DEF(oper_username,opt) \
		[list -arg -payee -mand 1 -check STRING  -desc {Payee, a name presumably?}] \
		[list -arg -addr_street_1 -mand 1 -check STRING  -desc {Address line 1}] \
		[list -arg -addr_street_2 -mand 0 -check STRING  -desc {Address line 2}] \
		[list -arg -addr_street_3 -mand 0 -check STRING  -desc {Address line 3}] \
		[list -arg -addr_street_4 -mand 0 -check STRING  -desc {Address line 4}] \
		[list -arg -addr_city -mand 1 -check STRING  -desc {City}] \
		[list -arg -addr_postcode -mand 1 -check STRING  -desc {Postcode}] \
		[list -arg -auth_dep -mand 0 -check {ENUM -args {Y N P}}  -default {P} -desc {}] \
		[list -arg -auth_wtd -mand 0 -check {ENUM -args {Y N P}}  -default {P} -desc {}] \
		$::core::payment::CORE_DEF(new_cpm_status) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]


core::args::register \
	-interface core::payment::CHQ::remove_cpm \
	-desc      {Marks a customers cheque cpm as removed in the database} \
	-returns    ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	]


core::args::register \
	-interface core::payment::CHQ::make_withdrawal \
	-desc      {Make withdrawal} \
	-returns    ASCII \
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
	-args      [list \
		$core::payment::CORE_DEF(oper_id)    \
		$core::payment::CORE_DEF(amount)     \
		$core::payment::CORE_DEF(cust_id)    \
		$core::payment::CORE_DEF(ipaddr)     \
		$core::payment::CORE_DEF(call_id)    \
		$core::payment::CORE_DEF(pmt_id,opt) \
		$core::payment::CORE_DEF(unique_id)  \
		[list -arg -source             -mand 1             -check ASCII  -desc {The source (a.k.a. channel) through which this payment is made}]         \
		[list -arg -payer              -mand 0 -default {} -check STRING -desc {Payer name}]                                                             \
		[list -arg -cheque_num         -mand 0 -default {} -check UINT   -desc {Cheque Number}]                                                          \
		[list -arg -cheque_date        -mand 0 -default {} -check DATE   -desc {Cheque Date}]                                                            \
		[list -arg -cheque_sort_code   -mand 0 -default {} -check ASCII  -desc {Sort code associated with the cheque}]                                   \
		[list -arg -cheque_account_num -mand 0 -default {} -check ASCII  -desc {Account number associated with the cheque}]                              \
		[list -arg -rec_delivery_ref   -mand 0 -default {} -check ASCII  -desc {Post office reference number if the cheque is posted recorded delivery}] \
		[list -arg -extra_info         -mand 0 -default {} -check ASCII  -desc {Any extra info that needs to be stored with the payment}]                \
		[list -arg -outlet             -mand 0 -default {} -check ASCII  -desc {Where the payment was taken}]                                            \
	]

core::args::register \
	-interface core::payment::CHQ::complete_withdrawal \
	-desc      {Complete withdrawal} \
	-errors    [list \
		PMT_ERR_DB_ERROR \
		INVALID_ARGS \
	] \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -transactional    -mand 0 -check {EXACT -args {Y N}}  -default {Y} -desc {Denotes if it is within a transaction or not}] \
		[list -arg -chq_no           -mand 0 -check UINT                 -default {}    -desc {Cheque number}] \
		[list -arg -chq_acct_no      -mand 0 -check ASCII                -default {}    -desc {Account number on the cheque}] \
		[list -arg -chq_sort_code    -mand 0 -check ASCII                -default {}    -desc {Sort code of the cheque}] \
		[list -arg -chq_date         -mand 0 -check DATE                 -default {}    -desc {Cheque date}] \
		[list -arg -rec_delivery_ref -mand 0 -check ASCII                -default {}    -desc {Reference number for recorded cheque delivery}] \
		[list -arg -payer            -mand 0 -check STRING               -default {}    -desc {Name of the Payer}] \
		[list -arg -extra_info       -mand 0 -check STRING               -default {}    -desc {Any extra information about cash withdrawal}] \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
	]
