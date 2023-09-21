# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# Neteller payment interface
#
set pkg_version 1.0
package provide core::payment::NTLR $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::NTLR \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/NTLR.xml

namespace eval core::payment::NTLR {
	variable CORE_DEF

	# Neteller specific parameters
	set CORE_DEF(neteller_id) [list -arg -neteller_id -mand 1 -check UINT -desc {Neteller account id}]
	set CORE_DEF(secure_id)   [list -arg -secure_id   -mand 1 -check UINT -desc {Neteller secure id}]
}

# Register Neteller interface
core::args::register \
	-interface core::payment::NTLR::init \
	-desc      {Initialisation procedure for Neteller payment method} \
	-args       [list \
		[list -arg -neteller_merchant_id         -mand 1 -check UINT                     -desc {Neteller merchant id}] \
		[list -arg -neteller_merchant_key        -mand 1 -check UINT                     -desc {Neteller merchant key}] \
		[list -arg -neteller_merchant_pass       -mand 1 -check ASCII                    -desc {Neteller merchant password}] \
		[list -arg -neteller_url_wtd             -mand 0 -check ASCII   -default {https} -desc {Neteller iwithdrawal url}] \
		[list -arg -neteller_url_dep             -mand 0 -check ASCII   -default {https} -desc {Neteller deposit url}] \
		[list -arg -neteller_timeout             -mand 0 -check UINT    -default 10000   -desc {Neteller request tiemout}] \
		[list -arg -neteller_link_back_url       -mand 0 -check ASCII   -default {}      -desc {Neteller link back url}] \
		[list -arg -neteller_wtd_ver             -mand 0 -check DECIMAL -default 4.0     -desc {Neteller withdrawla api version}] \
		[list -arg -neteller_dep_ver             -mand 0 -check DECIMAL -default 4.1     -desc {Neteller deposit api version}] \
		[list -arg -neteller_pending_withdrawals -mand 0 -check BOOL    -default 0       -desc {Neteller withdrawals should not be processed pending authorisation and approval}] \
		[list -arg -neteller_simerror            -mand 0 -check STRING  -default {}      -desc {Always simulate this neteller error}] \
		[list -arg -neteller_auth_dep            -mand 0 -check BOOL    -default 0       -desc {Authorisation status of neteller deposits}] \
		[list -arg -neteller_auth_wtd            -mand 0 -check BOOL    -default 0       -desc {Authorisation status of neteller withdrawals}] \
		[list -arg -neteller_reuse_acct          -mand 0 -check BOOL    -default 0       -desc {Reuse a removed neteller cpm when the same customer attempts to re add the neteller id}] \
		[list -arg -func_italy                   -mand 0 -check BOOL    -default 0       -desc {Enable Italy specific neteller}] \
		[list -arg -italy_site_operator_name     -mand 0 -check STRING  -default {Italy} -desc {Italian site operator name}] \
		[list -arg -italy_neteller_merchant_id   -mand 0 -check UINT    -default {}      -desc {Italy specific neteller merchant id}] \
		[list -arg -italy_neteller_merchant_key  -mand 0 -check UINT    -default {}      -desc {Italy specific neteller merchant key}] \
		[list -arg -italy_neteller_merchant_pass -mand 0 -check ASCII   -default {}      -desc {Italy specific neteller merchant password}] \
		[list -arg -func_ovs                     -mand 0 -check BOOL    -default 0       -desc {Enable OVS Verification}] \
		[list -arg -func_ovs_verf_ntlr_chk       -mand 0 -check BOOL    -default 1       -desc {OVS verification check for neteller}] \
		$::core::payment::CORE_DEF(pmt_receipt_format) \
		$::core::payment::CORE_DEF(pmt_receipt_tag)\
		$::core::payment::CORE_DEF(monitor) \
		$::core::payment::CORE_DEF(payment_ticker) \
		[list -arg -campaign_tracking            -mand 0 -check BOOL    -default 0       -desc {Enable campaign tracking}] \
	]

core::args::register \
	-interface core::payment::NTLR::delete_cpm \
	-desc      {Marks a customers Neteller cpm as removed in the database} \
	-returns    ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
	]

core::args::register \
	-interface core::payment::NTLR::check_prev_pmt \
	-desc      {Search for previously successful payments} \
	-returns   UINT \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::NTLR::CORE_DEF(neteller_id) \
	]

core::args::register \
	-interface core::payment::NTLR::auth \
	-desc      {Check and update the status of an unknown Neteller payment} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(pmt_id) \
	]

core::args::register \
	-interface core::payment::NTLR::make_deposit \
	-desc      {Perform a Neteller deposit} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::NTLR::CORE_DEF(secure_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(comm_list) \
	]

core::args::register \
	-interface core::payment::NTLR::make_withdrawal \
	-desc      {Perform a Neteller withdrawal} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(comm_list) \
		$::core::payment::CORE_DEF(min_overide) \
		$::core::payment::CORE_DEF(call_id) \
	]

core::args::register \
	-interface core::payment::NTLR::send_wtd \
	-desc      {Send a withdrawal to neteller} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(source) \
		[list -arg -pmt_date -mand 1 -check DATETIME -desc {Date time of the payment}] \
		[list -arg -v_type   -mand 1 -check {ENUM -args {DEP WTD AUTH}} -desc {v_type}] \
	]

core::args::register \
	-interface core::payment::NTLR::get_neteller \
	-desc      {Get the neteller id registered for the customer} \
	-returns   UINT \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		[list -arg -cpm_id -mand 0 -check UINT -default {} -desc {Optional cpm_id when using multiple payment methods}] \
	]

core::args::register \
	-interface core::payment::NTLR::insert_cpm \
	-desc      {Register a new neteller customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::NTLR::CORE_DEF(neteller_id) \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -allow_duplicate -mand 0 -check {ENUM -args {Y N}} -default N -desc {Whether to register the cpm if it is a duplicate}] \
		[list -arg -strict_check    -mand 0 -check {ENUM -args {Y N}} -default Y -desc {Whether to perform a strict duplicate check}] \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::NTLR::update_cpm \
	-desc      {Update a Moneybookers customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::NTLR::verify_no_duplicate_id \
	-desc      {Checks to see if the passed neteller_id already exists for another account} \
	-returns   UINT \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::NTLR::CORE_DEF(neteller_id) \
	]

core::args::register \
	-interface core::payment::NTLR::verify_neteller_id_not_used \
	-desc      {Checks to see if the passed neteller_id already exists and is active} \
	-returns   UINT \
	-args      [list \
		$::core::payment::NTLR::CORE_DEF(neteller_id) \
	]
