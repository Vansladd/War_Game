# Copyright (C) 2015 Openbet Ltd. All Rights Reserved.
#
# eNets payment interface
#
set pkg_version 1.0
package provide core::payment::ENET $pkg_version

# Dependencies
package require core::payment 1.0
package require core::args    1.0
package require core::log     1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::ENET \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/enets.xml

namespace eval core::payment::ENET {
	variable CORE_DEF

	# eNets specific parameters. Oper_id, although it is found in core payment interface,
	# is redefined to change the default value in order for it to work as we want.
	set CORE_DEF(oper_id)            [list -arg -oper_id            -mand 0 -default "" -check ASCII     -desc {The operator's id}]
	set CORE_DEF(trans_id)           [list -arg -trans_id           -mand 0 -default "" -check ASCII     -desc {the transaction ID defined by eNets' notify message}]
	set CORE_DEF(enet_res_code)      [list -arg -enet_res_code      -mand 0 -default "" -check ASCII     -desc {The result code received from eNets}]
	set CORE_DEF(msg)                [list -arg -msg                -mand 0             -check ASCII     -desc {The eNETS message}]
	set CORE_DEF(ext_process_date)   [list -arg -ext_process_date   -mand 0 -default "" -check LOOSEDATE -desc {Date when payment is processed by 3rd party}]
	set CORE_DEF(trans_id)           [list -arg -trans_id           -mand 0 -default {}  -check ASCII                                     -desc {the transaction ID defined by eNets' notify message}]
	set CORE_DEF(enet_res_code)      [list -arg -enet_res_code      -mand 0 -default {}  -check ASCII                                     -desc {The result code received from eNets}]
	set CORE_DEF(msg)                [list -arg -msg                -mand 0              -check ASCII                                     -desc {The eNETS message}]
	set CORE_DEF(enets_redirect_url) [list -arg -enets_redirect_url -mand 0              -check ASCII  -default_cfg ENETS_REDIRECT_URL    -desc {The eNets URL where the customer will be redirected to}]
	set CORE_DEF(message)            [list -arg -message            -mand 0 -default {}  -check ASCII                                     -desc {encrypted payment request message sent to eNets}]
	set CORE_DEF(enets_commission)   [list -arg -enets_commission   -mand 0 -default 1   -check MONEY  -default_cfg ENETS_COMMISSION      -desc {eNets Commission}]
	set CORE_DEF(min_deposit)        [list -arg -min_deposit        -mand 0              -check MONEY                                     -desc {Customer payment method minimum deposit}]
	set CORE_DEF(max_deposit)        [list -arg -max_deposit        -mand 0              -check MONEY                                     -desc {Customer Payment Method maximum deposit}]
	set CORE_DEF(cpm_status)         [list -arg -status             -mand 1              -check {STRING -min_str 1 -max_str 1}            -desc {Customer payment method status}]
	set CORE_DEF(ext_amount)         [list -arg -ext_amount         -mand 0             -check MONEY     -desc {Amount processed by third party}]
    set CORE_DEF(ext_status)         [list -arg -ext_status         -mand 0 -default "" -check ASCII     -desc {Transaction status in the third party}]
    set CORE_DEF(merchant_txn_id)    [list -arg -merchant_txn_id    -mand 1             -check UINT      -desc {Merchant transaction ID received from eNets}]
    set CORE_DEF(txn_amount)         [list -arg -txn_amount         -mand 1             -check MONEY     -desc {Transaction amount as received from eNets}]
    set CORE_DEF(txn_date)           [list -arg -txn_date           -mand 0 -default {} -check DATETIME  -desc {Date and time at which the transaction was processed as received from eNets}]
    set CORE_DEF(txn_status)         [list -arg -txn_status         -mand 1 -default {} -check STRING    -desc {Status of transaction as received from eNets}]
}

# Register eNets interface
core::args::register \
	-interface core::payment::ENET::init \
	-desc      {Initialise the eNets package} \
	-args      [list \
		$::core::payment::ENET::CORE_DEF(enets_commission) \
		[list -arg -gpg_encr_passphrase     -mand 0 -check ASCII -default {}  -default_cfg GPG_ENCR_PASSPHRASE      -desc {The GPG encryption passphrase}] \
		[list -arg -gpg_decr_passphrase     -mand 0 -check ASCII -default {}  -default_cfg GPG_DECR_PASSPHRASE      -desc {The GPG decryption passphrase}] \
		[list -arg -gpg_recipient           -mand 0 -check ASCII -default {}  -default_cfg GPG_RECIPIENT            -desc {The GPG recipient}] \
		[list -arg -gpg_owner               -mand 0 -check ASCII -default {}  -default_cfg GPG_OWNER                -desc {The GPG owner}] \
		[list -arg -gpg_homedir             -mand 0 -check ASCII -default {}  -default_cfg GPG_HOMEDIR              -desc {Extra arguments to pass to gpg}] \
		[list -arg -func_enets              -mand 0 -check BOOL  -default 0   -default_cfg FUNC_ENETS               -desc {Enable eNets}] \
		[list -arg -func_ovs                -mand 0 -check BOOL  -default 0   -default_cfg FUNC_OVS                 -desc {Enable OVS}] \
		[list -arg -func_ovs_verf_enets_chk -mand 0 -check BOOL  -default 0   -default_cfg FUNC_OVS_VERF_ENET_CHK   -desc {OVS check for eNets}] \
		[list -arg -enets_redirect_url      -mand 0 -check ASCII              -default_cfg ENETS_REDIRECT_URL       -desc {The eNets URL where the customer will be redirected to}] \
		[list -arg -enets_merchant_tmz      -mand 0 -check ASCII              -default_cfg ENETS_MERCHANT_TMZ       -desc {the merchant's time zone}] \
		[list -arg -enets_merchant_id       -mand 0 -check ASCII              -default_cfg ENETS_MERCHANT_ID        -desc {the merchant ID assigned from eNets}] \
		[list -arg -enets_merchant_cert_id  -mand 0 -check ASCII              -default_cfg ENETS_MERCHANT_CERT_ID   -desc {ID of the Certificate used for this transaction. It \
                                                                                                                           is assigned by eNETS after merchant generates his key \
                                                                                                                           pair and uploads the public certificate to the gateway.}] \
	]

core::args::register \
	-interface core::payment::ENET::insert_pmt_dep \
	-desc      {Inserts a new eNets deposit payment and returns its details} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(unique_id) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_INS_PMT_DEP_OK}} -desc {Status code}] \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::ENET::CORE_DEF(enets_redirect_url) \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(payment_sort) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::CORE_DEF(ipaddr) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::ENET::CORE_DEF(enets_commission) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::ENET::CORE_DEF(message) \
	] \
	-errors [list \
		DB_ERROR \
		ENET_INVALID_AMOUNT \
		SYSTEM_ERROR \
		SELF_EXCL \
		ENET_DEP_LIMIT_ERR \
		ENETS_ERR_ONLY_ONE_CPM \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
		ENETS_ERR_MSG \
		ENETS_ERR_ENCRYPT_MSG \
		ERR_INVALID_CPM \
	]


core::args::register \
	-interface core::payment::ENET::update_pmt_status \
	-desc      {Updates the status of eNets payment} \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::ENET::CORE_DEF(trans_id) \
		$::core::payment::ENET::CORE_DEF(enet_res_code) \
		$::core::payment::ENET::CORE_DEF(ext_process_date) \
		$::core::payment::ENET::CORE_DEF(ext_amount) \
		$::core::payment::ENET::CORE_DEF(ext_status) \
		$::core::payment::CORE_DEF(reconciled_by,opt) \
		$::core::payment::CORE_DEF(reconciled_at,opt) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_UPD_PMT_OK}} -desc {Status code}] \
	] \
	-errors [list \
		DB_ERROR \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::insert_cpm \
	-desc      {Inserts an eNets customer payment method and returns its details} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(source) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(oper_notes,opt) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_INS_CPM_OK}} -desc {Status Code}] \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::ENET::CORE_DEF(cpm_status) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(oper_id) \
		$::core::payment::CORE_DEF(oper_notes,opt) \
	] \
	-errors [list \
		DB_ERROR \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::get_cpm \
	-desc      {Get's a customer eNETS payment method and returns its details} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_GET_CPM_OK}} -desc {Status code}] \
		$::core::payment::CORE_DEF(cpm_id)            \
		$::core::payment::CORE_DEF(ccy_code)          \
		$::core::payment::ENET::CORE_DEF(min_deposit) \
		$::core::payment::ENET::CORE_DEF(max_deposit) \
		$::core::payment::CORE_DEF(status)            \
		$::core::payment::CORE_DEF(auth_dep)          \
		$::core::payment::CORE_DEF(status_dep)        \
	] \
	-errors [list \
		DB_ERROR \
		ENETS_ERR_ONLY_ONE_CPM \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::delete_cpm \
	-desc      {Deletes eNets payment method of a customer} \
	-args      [list \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_DEL_CPM_OK}} -desc {Status code}] \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(cpm_id) \
	] \
	-errors [list \
		DB_ERROR \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::encrypt_msg \
	-desc      {Encrypts a plain text eNets message} \
	-args      [list \
		$::core::payment::ENET::CORE_DEF(msg) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENCRYPTION_OK}} -desc {Status code}] \
		$::core::payment::ENET::CORE_DEF(msg)
	] \
	-errors [list \
		ENETS_ERR_ENCRYPT_MSG \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::decrypt_msg \
	-desc      {Decrypts an encrypted eNets message} \
	-args      [list \
		$::core::payment::ENET::CORE_DEF(msg) \
	] \
	-return_data [list \
		[list -arg -status_code -mand 1 -check {EXACT -args {DECRYPTION_OK}} -desc {Status code}] \
		$::core::payment::ENET::CORE_DEF(msg)
	] \
	-errors [list \
		ENETS_ERR_DECRYPT_MSG \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::get_pmt_details \
	-desc      {Gets the details of an eNets payment} \
	-args      [list \
		$::core::payment::CORE_DEF(pmt_id) \
	] \
	-return_data [list \
		$::core::payment::CORE_DEF(pmt_id) \
		[list -arg -status_code -mand 1 -check {EXACT -args {ENETS_GET_PMT_OK}} -desc {Status code}] \
		$::core::payment::CORE_DEF(status) \
		$::core::payment::CORE_DEF(amount) \
		$::core::payment::ENET::CORE_DEF(enets_commission) \
		$::core::payment::ENET::CORE_DEF(trans_id) \
		$::core::payment::ENET::CORE_DEF(enet_res_code) \
	] \
	-errors [list \
		DB_ERROR \
		ENETS_ERR_ONLY_ONE_PMT \
		ENETS_ERR_DISABLED \
		INVALID_ARGS \
	]

core::args::register \
	-interface core::payment::ENET::reconcile_pmt \
	-desc      {Reconcile an eNets payment} \
	-args      [list \
		$::core::payment::ENET::CORE_DEF(merchant_txn_id) \
		$::core::payment::ENET::CORE_DEF(txn_amount) \
		$::core::payment::ENET::CORE_DEF(txn_date) \
		$::core::payment::ENET::CORE_DEF(txn_status) \
		$::core::payment::ENET::CORE_DEF(oper_id) \
	] \
	-return_data [list \
		[list -arg -status -mand 1 -check {BOOL} -desc {Status of the response : 1 success, 0 error}] \
	] \
	-errors      [list \
		ENETS_INTERNAL_ERROR \
		ENETS_ERR_PMT_INVALID \
		DB_ERROR \
		INVALID_ARGS \
	]
