# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# Credit Card payment interface
#
set pkg_version 1.0
package provide core::payment::CC $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0
package require core::db      1.0

core::args::register_ns \
	-namespace core::payment::CC \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs xml/payment/CC.xml

namespace eval core::payment::CC {
	variable CORE_DEF

	# Credit Card specific parameters
	set CORE_DEF(card_no)       [list -arg -card_no       -mand 1 -check UINT -desc {Credit card number}]
	set CORE_DEF(use_3D_secure) [list -arg -use_3D_secure -mand 1 -check BOOL -desc {Populated 3D secure array for this transaction}]

	# Optional Credit Card specific parameters
	set CORE_DEF(auth_code,opt)        [list -arg -auth_code        -mand 0 -check STRING                 -default {} -desc {General customer authorisation code to store agains the payment}]
	set CORE_DEF(extra_info,opt)       [list -arg -extra_info       -mand 0 -check STRING                 -default {} -desc {Misc free test which will be recorded against the payment in the database}]
	set CORE_DEF(min_amt,opt)          [list -arg -min_amt          -mand 0 -check UMONEY                 -default {} -desc {Minimum allowable currency amount}]
	set CORE_DEF(max_amt,opt)          [list -arg -max_amt          -mand 0 -check UMONEY                 -default {} -desc {Maximum allowable currency amount}]
	set CORE_DEF(gw_auth_code,opt)     [list -arg -gw_auth_code     -mand 0 -check {RE -args {\d\d\d\d}}  -default {} -desc {Four digit code supplied by the bank which may be required for 'referred' payments}]
	set CORE_DEF(is_admin,opt)         [list -arg -is_admin         -mand 0 -check BOOL                   -default 0  -desc {Has this transaction been initiated through admin}]
	set CORE_DEF(cvv2,opt)             [list -arg -cvv2             -mand 0 -check {RE -args {\d|^$}}     -default {} -desc {Card verification value}]
	set CORE_DEF(merchant_url,opt)     [list -arg -merchant_url     -mand 0 -check ASCII                  -default {} -desc {URL that the customer will be returned to}]
	set CORE_DEF(purchase_desc,opt)    [list -arg -purchase_desc    -mand 0 -check STRING                 -default {} -desc {Purchase description, required for 3D Secure}]
	set CORE_DEF(extra_info_3Ds,opt)   [list -arg -extra_info_3Ds   -mand 0 -check ASCII                  -default {} -desc {Freeform text field that will be embedded in the MD, and passed back to us}]
	set CORE_DEF(browser_category,opt) [list -arg -browser_category -mand 0 -check UINT                   -default {} -desc {Browser category}]
	set CORE_DEF(accept_headers,opt)   [list -arg -accept_headers   -mand 0 -check ASCII                  -default {} -desc {Broswer accept headers, http header of the customer}]
	set CORE_DEF(user_agent,opt)       [list -arg -user_agent       -mand 0 -check ASCII                  -default {} -desc {The HTTP user agent of the customer}]
	set CORE_DEF(card_no,opt)          [list -arg -card_no          -mand 0 -check UINT                   -default {} -desc {Credit card number}]

}

# Register Credit Card interface
core::args::register \
	-interface core::payment::CC::init \
	-desc      {Initialisation procedure for Credit Card payment method} \
	-allow_rpc 1 \
	-args      [list \
		[list -arg -verbose_3Ds_codes       -mand 0 -check BOOL  -default 0  -desc {Store verbose 3D Secure codes}] \
		[list -arg -3Ds_policy_codes        -mand 0 -check BOOL  -default 0  -desc {Resubmit 3D Secure policy codes}] \
		[list -arg -3Ds_resubmit_allowed    -mand 0 -check BOOL  -default 0  -desc {3D Secure resubmit allowed}] \
		[list -arg -3Ds_resubmit_conditions -mand 0 -check ASCII -default {} -desc {3D Secure Resubmit conditions}] \
		[list -arg -3Ds_crypt_key_hex       -mand 0 -check HEX   -default {} -desc {3D Secure hexadecimal crypt key}] \
		[list -arg -3Ds_crypt_key_bin       -mand 0 -check ASCII -default {} -desc {3D Secure binary crypt key}] \
		$::core::payment::CORE_DEF(pmt_receipt_func) \
		$::core::payment::CORE_DEF(pmt_receipt_format) \
		$::core::payment::CORE_DEF(pmt_receipt_tag) \
		[list -arg -traceware_check         -mand 0 -check BOOL  -default 0  -desc {Traceware checking enabled}] \
		[list -arg -check_scheme_allowed    -mand 0 -check BOOL  -default 0  -desc {Card scheme checking enabled}] \
		[list -arg -enable_intercept_pmts   -mand 0 -check BOOL  -default 0  -desc {Enable payment intercepts}] \
		[list -arg -pmt_status_change_users -default_cfg PMT_STATUS_CHANGE_USERS -mand 0 -check ASCII -default {} -desc {List of users that can update payments and payment methods}] \
		[list -arg -enable_cvv2_checks      -default_cfg PAYMENT_CC_ENFORCE_CV2  -mand 0 -check BOOL  -default 1  -desc {Use cvv2 number when making a payment}] \
		[list -arg -enable_commission       -default_cfg CHARGE_COMMISSION       -mand 0 -check BOOL  -default 0  -desc {Calculate and charge commission when making payments}] \
		[list -arg -insert_wtd_as_pending    -default_cfg DO_GENERIC_WTD_CC       -mand 0 -check BOOL  -default 0  -desc {Only insert the withdrawal as pending and do not send it for processing}] \
		[list -arg -micro_txn_max_rand_chrg  -default_cfg MICRO_TXN_MAX_RAND_CHRG -mand 0 -check UMONEY  -default 1  -desc {Micro transaction maximum value}] \
		[list -arg -micro_txn_min_rand_chrg  -default_cfg MICRO_TXN_MIN_RAND_CHRG -mand 0 -check UMONEY  -default 0  -desc {Micro transaction minimum value}] \
		[list -arg -micro_txn_upd_cpm_on_verif  -default_cfg MICRO_TXN_UPD_CPM_ON_VERIF    -mand 0 -check BOOL  -default 0  -desc {Allow status update on micro transaction verification check failure}] \
		[list -arg -micro_txn_max_failed_count  -default_cfg MICRO_TXN_MAX_FAILED_COUNT    -mand 0 -check UINT  -default 3  -desc {Maximum allowed verification check failures before voiding}] \
		[list -arg -micro_txn_upd_cpm_on_refund -default_cfg MICRO_TXN_UPD_CPM_ON_REFUND   -mand 0 -check BOOL  -default 0  -desc {Allow status update on micro transaction refund}] \
		[list -arg -block_card_with_prev_pmts   -default_cfg BLOCK_CARD_WITH_PREV_PMTS     -mand 0 -check BOOL  -default 1  -desc {Do not add this card if there are payments against it}]\
	] \
	-body {
		if {![catch {
			package require core::harness::payment::CC 1.0
		} msg]} {
			core::harness::payment::CC::init
		}
	}

core::args::register \
	-interface core::payment::CC::insert_cpm \
	-desc      {Register a new CC payment method for a customer} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CC::CORE_DEF(card_no,opt) \
		[list -arg -expiry_date        -mand 0 -check {RE -args {(0[1-9]|1[0-2])/\d\d}}                 -desc {Expiry date of the credit card}] \
		$::core::payment::CORE_DEF(transactional) \
		[list -arg -allow_duplicates   -mand 0 -check {ENUM -args {Y N}}                   -default {N} -desc {Allow same credit card number to be registered more than once}] \
		[list -arg -use_dummy_scheme   -mand 0 -check BOOL                                 -default 0   -desc {Use a dummy scheme for creating this cpm}] \
		[list -arg -start_date         -mand 0 -check {RE -args {(0[1-9]|1[0-2])/\d\d|^$}} -default {}  -desc {Start date of the credit card}] \
		[list -arg -issue_no           -mand 0 -check {RE -args {\d|^$}}                   -default {}  -desc {Card issue number}] \
		[list -arg -holder_name        -mand 0 -check STRING                               -default {}  -desc {Card Holder's name}] \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -oper_notes         -mand 0 -check STRING                               -default {}  -desc {Operator's notes}] \
		[list -arg -allow_multiple_cpm -mand 0 -check {ENUM -args {Y N}}                   -default {N} -desc {Should multiple cpm's be allowed for this customer}] \
		[list -arg -is_reissue         -mand 0 -check {ENUM -args {Y N}}                   -default {N} -desc {Is this registration for a reissued card}] \
		[list -arg -reissue_cpm_id     -mand 0 -check UINT                                 -default 0   -desc {Cpm id of old card (if this is a reissue)}] \
		[list -arg -reissue_auth_dep   -mand 0 -check {ENUM -args {Y N 0}}                 -default 0   -desc {Old Deposit authorisation status (if this is a reissue)}] \
		[list -arg -bpay_biller_code   -mand 0 -check INT                                  -default {}  -desc {BPAY biller code used for credit card withdrawals in Australia}] \
		$::core::payment::CORE_DEF(nickname,opt) \
		[list -arg -token_id   -mand 0 -check {STRING}                                     -default {}  -desc {Reference Id to the tokenised transaction, if missing (and card as well) a new transaction will be setup}] \
	]

core::args::register \
	-interface core::payment::CC::remove_cpm \
	-desc      {Remove a CC payment method} \
	-allow_rpc 1 \
	-returns   BOOL \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	]

core::args::register \
	-interface core::payment::CC::update_cpm \
	-desc      {Update a Credit card payment method} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		[list -arg -expiry_date        -mand 0 -check {RE -args {(0[1-9]|1[0-2])/\d\d}}    -default {}  -desc {Expiry date of the credit card}] \
		[list -arg -allow_duplicates   -mand 0 -check {ENUM -args {Y N}}                   -default {N} -desc {Allow same credit card number to be registered more than once}] \
		[list -arg -use_dummy_scheme   -mand 0 -check BOOL                                 -default 0   -desc {Use a dummy scheme for creating this cpm}] \
		[list -arg -start_date         -mand 0 -check {RE -args {(0[1-9]|1[0-2])/\d\d|^$}} -default {}  -desc {Start date of the credit card}] \
		[list -arg -issue_no           -mand 0 -check {RE -args {\d|^$}}                   -default {}  -desc {Card issue number}] \
		[list -arg -holder_name        -mand 0 -check STRING                               -default {}  -desc {Card Holder's name}] \
		$::core::payment::CORE_DEF(oper_id) \
		[list -arg -oper_notes         -mand 0 -check STRING                               -default {}  -desc {Operator's notes}] \
		[list -arg -allow_multiple_cpm -mand 0 -check BOOL                                 -default 0   -desc {Should multiple cpm's be allowed for this customer}] \
		[list -arg -is_reissue         -mand 0 -check BOOL                                 -default 0   -desc {Is this registration for a reissued card}] \
		[list -arg -reissue_cpm_id     -mand 0 -check UINT                                 -default 0   -desc {Cpm id of old card (if this is a reissue)}] \
		[list -arg -reissue_auth_dep   -mand 0 -check {ENUM -args {Y N 0}}                 -default 0   -desc {Old Deposit authorisation status (if this is a reissue)}] \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		[list -arg -bpay_biller_code   -mand 0 -check INT                                  -default {}  -desc {BPAY biller code used for credit card withdrawals in Australia}] \
		$::core::payment::CORE_DEF(nickname,opt) \
		$::core::payment::CORE_DEF(oper_username,opt) \
	]

core::args::register \
	-interface core::payment::CC::send_micro_transaction \
	-desc      {Send a micro transaction for verification of the card details} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CC::CORE_DEF(cvv2,opt) \
		[list -arg -skip_cvv2_check -mand 0 -default 0 -check BOOL -desc {Do not check cvv2 is present or required}] \
	]

core::args::register \
	-interface core::payment::CC::verify_micro_transaction \
	-desc      {Confirm the micro transaction amount to verify the card} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CC::CORE_DEF(auth_code,opt) \
	]

core::args::register \
	-interface core::payment::CC::refund_micro_transaction \
	-desc      {Refund the amount from the micro transaction} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(oper_username,opt) \
		$::core::payment::CC::CORE_DEF(auth_code,opt) \
	]

core::args::register \
	-interface core::payment::CC::make_deposit \
	-desc      {Make a credit card deposit} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(call_id) \
		$::core::payment::CORE_DEF(country_code) \
		$::core::payment::CORE_DEF(min_overide) \
		$::core::payment::CC::CORE_DEF(auth_code,opt) \
		$::core::payment::CC::CORE_DEF(extra_info,opt) \
		$::core::payment::CC::CORE_DEF(min_amt,opt) \
		$::core::payment::CC::CORE_DEF(max_amt,opt) \
		$::core::payment::CC::CORE_DEF(gw_auth_code,opt) \
		$::core::payment::CC::CORE_DEF(is_admin,opt) \
		$::core::payment::CC::CORE_DEF(cvv2,opt) \
		$::core::payment::CC::CORE_DEF(use_3D_secure) \
		$::core::payment::CC::CORE_DEF(merchant_url,opt) \
		$::core::payment::CC::CORE_DEF(purchase_desc,opt) \
		$::core::payment::CC::CORE_DEF(extra_info_3Ds,opt) \
		$::core::payment::CC::CORE_DEF(browser_category,opt) \
		$::core::payment::CC::CORE_DEF(accept_headers,opt) \
		$::core::payment::CC::CORE_DEF(user_agent,opt) \
		[list -arg -skip_cvv2_check -mand 0 -default 0 -check BOOL -desc {Do not check cvv2 is present or required}] \
		[list -arg -return_url -mand 0 -check STRING -default 0 \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - success}] \
		[list -arg -expiry_url -mand 0 -check STRING -default 0  \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - failure}] \
	]

core::args::register \
	-interface core::payment::CC::make_withdrawal \
	-desc      {Make a credit card withdrawal} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(acct_id) \
		$::core::payment::CORE_DEF(unique_id) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(call_id) \
		$::core::payment::CORE_DEF(country_code) \
		$::core::payment::CORE_DEF(min_overide) \
		$::core::payment::CC::CORE_DEF(auth_code,opt) \
		$::core::payment::CC::CORE_DEF(extra_info,opt) \
		$::core::payment::CC::CORE_DEF(min_amt,opt) \
		$::core::payment::CC::CORE_DEF(max_amt,opt) \
		$::core::payment::CC::CORE_DEF(gw_auth_code,opt) \
		$::core::payment::CC::CORE_DEF(is_admin,opt) \
		$::core::payment::CC::CORE_DEF(cvv2,opt) \
		[list -arg -skip_cvv2_check -mand 0 -default 0 -check BOOL -desc {Do not check cvv2 is present or required}] \
		[list -arg -return_url -mand 0 -check STRING -default 0 \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - success}] \
		[list -arg -expiry_url -mand 0 -check STRING -default 0  \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - failure}] \
	]
	
core::args::register \
	-interface core::payment::CC::complete_transaction \
	-desc      {Complete make a credit card transaction after capture info by 3dparty page} \
	-allow_rpc 1 \
	-returns   ASCII \
	-args      [list \
		[list -arg -encrypted_info -mand 1 -check ASCII -desc {Encrypted information that was previous setup in our system in order to process the payment}] \
		[list -arg -ref_capture -mand 1 -check ASCII -desc {reference to the data capture}] \
	]
# return data difficult ot setup, this proc will call the existing make_withdrawal with rsuming the operation and chcek that the page is filled.
core::args::register \
	-interface core::payment::CC::3D_secure_auth \
	-desc      {Handle the authentication of a payment that has been made through 3D secure} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(pmt_id) \
		[list -arg -payer_auth_response -check ASCII -mand 1 -desc {Payer authentication response. The value received at the conclusion of 3D Secure authentication}] \
		[list -arg -encrypted_string    -check ASCII -mand 1 -desc {Encrypted string that is supplied to and echoed back from 3D Secure authentication redirect. Contains OpenBet system payment info}] \
	]

core::args::register \
	-interface core::payment::CC::get_card_details \
	-desc      {Format the card number to display on a page} \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id,opt) \
		$::core::payment::CORE_DEF(oper_username,opt) \
		$::core::payment::CORE_DEF(status,opt) \
		[list -arg -mask_char                -mand 0 -check {ASCII -min_len 1 -max_len 1} -default X  -desc {Character to Mask digits with}] \
		[list -arg -show_all_digits          -mand 0 -check BOOL                          -default 0  -desc {Should we display the full card number}] \
		[list -arg -decrypt_reason           -mand 0 -check STRING                        -default {} -desc {Reason for doing decrypt}] \
		[list -arg -return_card_no_only      -mand 0 -check BOOL                          -default 0  -desc {returned only the card number details}] \
		[list -arg -callback_format_card_no  -mand 0 -check STRING                        -default {} -desc {callback proc to format the card number}] \
	] \
	-error_data [list \
		[list -code FAILED_TO_DECRYPT_CARD -desc {Failed to decrypt the card number} ]\
		[list -code FAILED_TO_GET_CPM      -desc {Failed to retrieve the cpm from the database} ]\
		[list -code MISSING_PARAMS         -desc {Missing parameters} ]\
	] \

core::args::register \
	-interface core::payment::CC::register_tokenised_card \
	-desc      {Register a tokenised card using a 3d hosted page - setup transaction} \
	-error_data [list \
		[list -code SYSTEM_ERROR -desc {System error} ] \
	] \
	-args [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id,opt) \
		[list -arg -return_url -mand 0 -check STRING -default 0 \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - success}] \
		[list -arg -expiry_url -mand 0 -check STRING -default 0  \
			-desc {Url to redirect the end user after fill the page in the 3dparty hosted page - failure}] \
		[list -arg -cv2_only -mand 0 -check BOOL -default 0  -desc {Define if we need to capture only cv2 in the hosted page.}] \
		[list -arg -amount -mand 0 -check UMONEY -default {} -desc {Define an amount value to show in the setup page, only for cv2}] \
	] \
	-return_data [list \
		[list -arg -redirect_url -mand 0 -check {STRING} -desc {Url of the hosted page to redirect the user}] \
	]