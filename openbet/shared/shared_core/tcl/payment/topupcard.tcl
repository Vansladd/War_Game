# Copyright (C) 2015 Openbet Ltd. All Rights Reserved.
#
# Top-Up Card payment interface
#
set pkg_version 1.0
package provide core::payment::TOPC $pkg_version

# Dependencies
package require core::payment 1.0
package require core::args    1.0
package require core::xml     1.0
package require core::socket  1.0
package require core::log     1.0
package require core::db      1.0
package require core::soap    1.0

core::args::register_ns \
	-namespace core::payment::TOPC \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check \
		core::xml \
		core:socket \
		core::db \
		core::soap] \
	-docs      xml/payment/topup.xml

namespace eval core::payment::TOPC {
	variable CORE_DEF

	# Top Up specific parameters
	set CORE_DEF(card_no)            [list -arg -card_no         -mand 1             -check UINT                -desc {The Top Up Card Number}]
	set CORE_DEF(topc_provider)      [list -arg -topc_provider   -mand 1             -check ASCII               -desc {The Top Up Card Provider}]
	set CORE_DEF(validation_code)    [list -arg -validation_code -mand 0 -default "" -check UINT                -desc {The Top Up card Security Code used to validate the card}]
	set CORE_DEF(check_existing)     [list -arg -check_existing  -mand 0 -default Y  -check {EXACT -args {Y N}} -desc {Check if an entry already exists}]
	set CORE_DEF(oper_id)            [list -arg -oper_id         -mand 0 -default "" -check ASCII               -desc {The operator's id}]
	set CORE_DEF(response_code)      [list -arg -response_code   -mand 0 -default "" -check ASCII               -desc {The Top Up Card Provider response code}]
}

# Register Top Up interface
core::args::register \
	-interface core::payment::TOPC::init \
	-desc      {Initialise the Top Up package} \
	-args      [list \
		[list -arg -topc_provider_list     -mand 0 -check ASCII                -desc {A list of supported Top Up Card providers codes}  -default_cfg TOPC_PROVIDER_LIST] \
		[list -arg -api_request_timeout    -mand 0 -check UINT  -default 10000 -desc {Top Up request timeout value}] \
		[list -arg -api_conn_timeout       -mand 0 -check UINT  -default 10000 -desc {Top Up request connection value}] \
		[list -arg -func_ovs               -mand 0 -check BOOL  -default 0     -desc {Enable OVS}] \
		[list -arg -func_ovs_verf_topc_chk -mand 0 -check BOOL  -default 0     -desc {OVS check for Top Up Card}] \
	]


core::args::register \
	-interface core::payment::TOPC::make_deposit \
	-desc      {Makes a Top Up Card transaction} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(oper_notes,opt) \
		$::core::payment::CORE_DEF(disallow_dep_rsn,opt) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::TOPC::CORE_DEF(oper_id) \
		$::core::payment::TOPC::CORE_DEF(card_no) \
		$::core::payment::TOPC::CORE_DEF(validation_code) \
		$::core::payment::CORE_DEF(unique_id) \
	] \
	-return_data [list \
		[list -arg -status        -mand 1             -check {EXACT -args {OK NOT_OK ERROR}} -desc {The Top Up Card Provider's response status}] \
		[list -arg -pmt_id        -mand 0 -default "" -check UINT                            -desc {The payment's ID}] \
		[list -arg -response_code -mand 0 -default "" -check ASCII                           -desc {The Top Up Card Provider response code}] \
	] \
	-errors [list \
		TOPC_REQ_ARG_MISSING \
		INVALID_CUST_ID \
		NO_TOPC_CPM \
		INVALID_RESPONSE \
		INVALID_CARD_DETAILS \
		CUST_VALIDATION_ERROR \
		DEPOSIT_LIMIT_EXCEEDED \
		SELF_EXCL \
		MULTIPLE_CPM_IDS \
		TOPC_ERR_DEP_API_URL \
		MISSING_MAND_REQ_ELEM \
		INVALID_REQ_ERROR \
		TOPC_ERR_CREATE_REQ_MSG \
		ERR_OBSOAP_UNKNOWN \
		REASON_UNKNOWN \
		ERR_OBSOAP_NOCONTACT \
		ERR_OBSOAP_UNKNOWN \
		INVALID_RESPONSE \
		DB_ERROR \
		INVALID_TOPC_PROVIDER \
		INVALID_ARGS \
		ERR_INVALID_CPM \
		ERR_CARD_USED \
		ERR_CARD_EXPIRED \
		ERR_INVALID_CODE \
		ERR_INVALID_CARD \
	]


core::args::register \
	-interface core::payment::TOPC::insert_cpm \
	-desc      {Insert a Top Up Card customer payment method} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(oper_notes,opt) \
		$::core::payment::CORE_DEF(disallow_dep_rsn,opt) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::TOPC::CORE_DEF(oper_id) \
		$::core::payment::TOPC::CORE_DEF(topc_provider) \
		$::core::payment::TOPC::CORE_DEF(check_existing) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(cpm_id) \
	]\
	-errors [list \
		MULTIPLE_CPM_IDS \
		TOPC_CPM_EXISTS \
		DB_ERROR \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::TOPC::get_cpm_details \
	-desc      {Get the status for a Top Up Card payment method} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(status)     \
		$::core::payment::CORE_DEF(auth_dep)   \
		$::core::payment::CORE_DEF(status_dep) \
	]\
	-errors [list \
		UNKNOWN_CPM \
		DB_ERROR \
		INVALID_ARGS \
	]
