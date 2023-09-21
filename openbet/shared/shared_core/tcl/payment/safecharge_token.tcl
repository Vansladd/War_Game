# Copyright (C) 2013 OpenBet Technology Ltd. All Rights Reserved.
#
# SafeCharge payment interface
#
# SafeCharge tokenised payments
# The PAN for payment cards will not be stored or handled by the OB system,
# which will only contain tokens referencing the payment card in the SC system.
# OB will store the token, and where necessary, will pass the token to SC
# in order to perform payments.
# A customer does not register a new CPM on the client website, but is redirected
# to the SafeCharge PPP site where he/she enters PAN etc.
#
#
# http://www.safecharge.com/
#
set pkg_version 1.0
package provide core::payment::SCTK $pkg_version


# Dependencies
package require core::payment  1.0
package require core::args     1.0
package require core::check    1.0


core::args::register_ns \
	-namespace core::payment::SCTK \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::args \
		core::check] \
	-docs xml/payment/SCTK.xml


namespace eval core::payment::SCTK {
	variable CORE_DEF

	set CORE_DEF(concat_fields)            [list -arg -concat_fields        -mand 1 -check ASCII              -desc {Concatenation string from SafeCharge fields for checksum}]
	set CORE_DEF(authorise)                [list -arg -authorise            -mand 1 -check {ENUM -args {Y N}} -desc {Authorise (Y) or Decline (N) payment - conceptually higher level than pmt status}]
	set CORE_DEF(start_time)               [list -arg -start_time           -mand 1 -check DATETIME           -desc {Start datetime - used when working with payments in given timeframe}]
	set CORE_DEF(end_time)                 [list -arg -end_time             -mand 1 -check DATETIME           -desc {End datetime   - used when working with payments in given timeframe}]

	set CORE_DEF(cvv2,opt)                 [list -arg -cvv2                 -mand 0 -check {RE -args {^([0-9]{3,4}){0,1}$}} -default {}  -desc {CVV2 - must never be stored or logged!}]
	set CORE_DEF(expiry_month,opt)         [list -arg -expiry_month         -mand 0 -check {RE -args {^\d{2}$}}             -default {}  -desc {CC expiry month}]
	set CORE_DEF(expiry_year,opt)          [list -arg -expiry_year          -mand 0 -check {RE -args {^\d{2}$}}             -default {}  -desc {CC expiry year}]
	set CORE_DEF(card_bin,opt)             [list -arg -card_bin             -mand 0 -check {RE -args {^\d{6}$}}             -default {}  -desc {CC BIN}]
	set CORE_DEF(card_last_4_digits,opt)   [list -arg -card_last_4_digits   -mand 0 -check {RE -args {^\d{4}$}}             -default {}  -desc {CC last four (4) digits}]
	set CORE_DEF(err_code,opt)             [list -arg -err_code             -mand 0 -check {RE -args {^[+-]?[0-9]*$}}       -default {}  -desc {ErrCode returned by Safecharge}]
	set CORE_DEF(ex_err_code,opt)          [list -arg -ex_err_code          -mand 0 -check {RE -args {^[+-]?[0-9]*$}}       -default {}  -desc {ExErrorCode returned by SafeCharge}]
	set CORE_DEF(extra_info,opt)           [list -arg -extra_info           -mand 0 -check ASCII                            -default {}  -desc {Additional message from the DMN listener}]
	set CORE_DEF(migrated_cpm_id,opt)      [list -arg -migrated_cpm_id      -mand 0 -check UINT                             -default {}  -desc {Id of CC card that is being migrated to SafeCharge}]
	set CORE_DEF(safecharge_token,opt)     [list -arg -safecharge_token     -mand 0 -check ASCII                            -default {}  -desc {The SafeCharge unique token representing a CPM}]
	set CORE_DEF(safecharge_unique_cc,opt) [list -arg -safecharge_unique_cc -mand 0 -check ASCII                            -default {}  -desc {The SafeCharge UniqueCC representing a CPM but only for reporting reasons}]
	set CORE_DEF(transaction_id,opt)       [list -arg -transaction_id       -mand 0 -check ASCII                            -default {}  -desc {Transaction ID supplied by SafeCharge}]
	set CORE_DEF(success_url,opt)          [list -arg -success_url          -mand 0 -check ASCII                            -default {}  -desc {The url to redirect after a successful transaction with SafeCharge}]
	set CORE_DEF(error_url,opt)            [list -arg -error_url            -mand 0 -check ASCII                            -default {}  -desc {The url to redirect after an unsuccessful transaction with SafeCharge}]
	set CORE_DEF(auth_code,opt)            [list -arg -auth_code            -mand 0 -check ASCII                            -default {}  -desc {AuthCode supplied by SafeCharge}]
	set CORE_DEF(client,opt)               [list -arg -client               -mand 0 -check ASCII                            -default {}  -desc {Client's name}]
	set CORE_DEF(password,opt)             [list -arg -password             -mand 0 -check ASCII                            -default {}  -desc {Client's password}]
	set CORE_DEF(host,opt)                 [list -arg -host                 -mand 0 -check ASCII                            -default {}  -desc {Gateway's ip/domain}]
	set CORE_DEF(port,opt)                 [list -arg -port                 -mand 0 -check UINT                             -default {}  -desc {Gateway's port}]
	set CORE_DEF(conn_timeout,opt)         [list -arg -conn_timeout         -mand 0 -check UINT                             -default {}  -desc {Time threshold for SCTK connection}]
	set CORE_DEF(resp_timeout,opt)         [list -arg -resp_timeout         -mand 0 -check UINT                             -default {}  -desc {Time threshold fo SCTK response}]
	set CORE_DEF(cust_id,opt)              [list -arg -cust_id              -mand 0 -check UINT                             -default {0} -desc {Customer identifier}]
	set CORE_DEF(3Ds_pa_req,opt)           [list -arg -3Ds_pa_req           -mand 0 -check ASCII                            -default {}  -desc {3D Secure Payment Authentication request (PaReq) field of a post 3DS redirection to ACS server.}]
	set CORE_DEF(3Ds_pa_res,opt)           [list -arg -3Ds_pa_res           -mand 0 -check ASCII                            -default {}  -desc {3D Secure Payment Authentication Response (PaRes) field of a post 3DS redirection from ACS server.}]
	set CORE_DEF(3Ds_md_id,opt)            [list -arg -3Ds_md_id            -mand 0 -check ASCII                            -default {}  -desc {3D Secure Merchant ID (MD) field of a post 3DS redirection.}]
	set CORE_DEF(3Ds_acs_url,opt)          [list -arg -3Ds_acs_url          -mand 0 -check ASCII                            -default {}  -desc {3D Secure url for the ACS server to redirect to.}]
	set CORE_DEF(3Ds_passed,opt)           [list -arg -3Ds_passed           -mand 0 -check BOOL                             -default {0} -desc {3D Secure successfull authentication.}]
}


# Register SafeCharge interface interface.
core::args::register \
	-interface core::payment::SCTK::init \
	-returns   INT \
	-body {
		# Initialise the harness if it is on the auto path
		# The harness nor the tests will be deployed in a live
		# environment and they are configured off by default
		if {![catch {
			package require core::harness::payment::SCTK 1.0
		} err]} {
			core::harness::payment::SCTK::init
		}
	}


# return: success {1 {cpm_id <int> status <char> url <ascii>}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::insert_cpm \
	-desc      {Insert a new SafeCharge cust pay method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::CORE_DEF(auth_dep,opt) \
		$::core::payment::CORE_DEF(auth_wtd,opt) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::SCTK::CORE_DEF(migrated_cpm_id,opt) \
		$::core::payment::SCTK::CORE_DEF(success_url,opt) \
		$::core::payment::SCTK::CORE_DEF(error_url,opt) \
	]


#
# If safecharge_token is not null in db, then only updatable fields are:
#    - nickname
#    - status
#
# return: success {1}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::update_cpm \
	-desc      {Update a SafeCharge customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::CORE_DEF(auth_dep,opt) \
		$::core::payment::CORE_DEF(status_dep,opt) \
		$::core::payment::CORE_DEF(order_dep,opt) \
		$::core::payment::CORE_DEF(disallow_dep_rsn,opt) \
		$::core::payment::CORE_DEF(auth_wtd,opt) \
		$::core::payment::CORE_DEF(status_wtd,opt) \
		$::core::payment::CORE_DEF(order_wtd,opt) \
		$::core::payment::CORE_DEF(disallow_wtd_rsn,opt) \
		$::core::payment::CORE_DEF(oper_notes,opt) \
		$::core::payment::SCTK::CORE_DEF(expiry_month,opt) \
		$::core::payment::SCTK::CORE_DEF(expiry_year,opt) \
		$::core::payment::SCTK::CORE_DEF(card_bin,opt) \
		$::core::payment::SCTK::CORE_DEF(card_last_4_digits,opt) \
		$::core::payment::SCTK::CORE_DEF(err_code,opt) \
		$::core::payment::SCTK::CORE_DEF(ex_err_code,opt) \
		$::core::payment::SCTK::CORE_DEF(extra_info,opt) \
		$::core::payment::SCTK::CORE_DEF(safecharge_token,opt) \
		$::core::payment::SCTK::CORE_DEF(safecharge_unique_cc,opt) \
		$::core::payment::SCTK::CORE_DEF(transaction_id,opt) \
		$::core::payment::SCTK::CORE_DEF(3Ds_passed,opt) \
	]


# return: success {1}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::remove_cpm \
	-desc      {remove a SafeCharge customer payment method} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(transactional) \
	]


# return: success {1 {key value key value key value...}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::get_cpm_details \
	-desc      {Get a SafeCharge customer payment method. \
		If the cust_id is being provided then the cpm_id is checked \
		if it belongs to this user. If not an error is returned. \
		} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id,opt) \
	]


# return: success {<status> <list-of-details>}
#         e.g. successful deposit  :  {1 {pmt_id <int> status <char>}}
#              3ds redirect needed :  {2 {pmt_id <int> transaction_id <int> pa_req <ascii> md_id <int> acs_url <ascii>}}
#              error               :  {0 <error_code> <error_msg>}
#
core::args::register \
	-interface core::payment::SCTK::make_deposit \
	-desc      {Insert to db and make call to SafeCharge} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::SCTK::CORE_DEF(cvv2,opt) \
	]


#
# return: success {1 {pmt_id <int> status <char>}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::make_withdrawal \
	-desc      {Perform a call to SafeCharge in order to withdraw money.
				If pmt_id is present then a withdrawal of this payment is performed.\
				(Other arguments are ignored in this case.)
				If pmt_id is not present, then the other arguments needs to be\
				presentired as a new payment will be added.} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(pmt_id,opt) \
		$::core::payment::CORE_DEF(acct_id,opt) \
		$::core::payment::CORE_DEF(cpm_id,opt) \
		$::core::payment::CORE_DEF(amount,opt) \
		$::core::payment::CORE_DEF(ipaddr,opt) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id,opt) \
		$::core::payment::CORE_DEF(ccy_code,opt) \
		$::core::payment::CORE_DEF(transactional) \
	]


# return: success {1 {pmt_id <int> status <char>}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::insert_pmt \
	-desc      {Insert a new SafeCharge payment} \
	-returns   ASCII \
	-args [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::CORE_DEF(transactional) \
	]


# return: success {1}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::authorise_pmt \
	-desc      {Payment authorisation in OB system (typically status change in\
				the db). This should not perform Auth request to SafeCharge.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::SCTK::CORE_DEF(authorise) \
	]


core::args::register \
	-interface core::payment::SCTK::fulfill_pmt \
	-desc      {If called with pmt_id only, then the proc retreives all required\
				details and performs fulfillment/settlement of the payment.
				Otherwise all arguments needs to be populated. This second option\
				is used in case the Pay Settlers app performs batch fulfillments\
				and caches e.g. decrypted credentials.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(ccy_code,opt) \
		$::core::payment::SCTK::CORE_DEF(transaction_id,opt) \
		$::core::payment::SCTK::CORE_DEF(auth_code,opt) \
		$::core::payment::SCTK::CORE_DEF(client,opt) \
		$::core::payment::SCTK::CORE_DEF(password,opt) \
		$::core::payment::SCTK::CORE_DEF(host,opt) \
		$::core::payment::SCTK::CORE_DEF(port,opt) \
		$::core::payment::SCTK::CORE_DEF(conn_timeout,opt) \
		$::core::payment::SCTK::CORE_DEF(resp_timeout,opt) \
	]


# return: success {1}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::scratch_pmts \
	-desc      {Scratches old undefined payments. A payment can become undefined\
				e.g. when we get response timeout and cannot safely say, whether\
				the payment reached SafeCharge and was processed or not.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::SCTK::CORE_DEF(start_time) \
		$::core::payment::SCTK::CORE_DEF(end_time) \
	]


# return: success {1 {<sc_checksum>}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface core::payment::SCTK::create_checksum \
	-desc      {Creates Safecharge checsksum without exposing SafeCharge credentials.
				This can also be used to validate a checksum returned by SafeCharge.
				The reason for it accepting a list of fields is because SafeCharge\
				use different fields to calculate the checksum depending on what \
				action returns the checksum.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(ccy_code) \
		$::core::payment::SCTK::CORE_DEF(concat_fields) \
	]


# return : success {1 <nickname>}
#          error   {0 <error_code> <error_msg>}
core::args::register \
	-interface  {core::payment::SCTK::get_default_nickname} \
	-desc       {Returns the default nickname.} \
	-returns    ASCII \
	-args       [list \
		$::core::payment::CORE_DEF(cust_id) \
	]


# return: success {1 {pmt_id <int> status <char>}}
#         error   {0 <error_code> <error_msg>}
#
core::args::register \
	-interface {core::payment::SCTK::complete_deposit} \
	-desc      {Finalises a deposit post 3ds redirection taking place.
		It should perform the final Auth request to Safecharge including \
		details from the 3ds authorisation that just took place.} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(transactional) \
		$::core::payment::SCTK::CORE_DEF(3Ds_pa_res,opt) \
		$::core::payment::SCTK::CORE_DEF(3Ds_md_id,opt) \
	]


# return: success {1 {key value key value key value...}}
#         error   {0 <error_code> <error_msg>}
core::args::register \
	-interface {core::payment::SCTK::get_pmt_details} \
	-desc      {Get a SafeCharge payment details.
		If the cust_id is being provided then the pmt_id is checked \
		if it belongs to this user. If not an error is returned. \
		} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(acct_id,opt) \
	]
