# Copyright (C) 2012 Openbet Ltd. All Rights Reserved.
#
# Dineromail payment interface
#

set pkg_version 1.0
package provide core::payment::DMBC $pkg_version

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0

core::args::register_ns \
	-namespace core::payment::DMBC \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check] \
	-docs      xml/payment/DMBC.xml

namespace eval core::payment::DMBC {
	variable CORE_DEF

	# Dineromail specific proc arguments.
	set CORE_DEF(plaintext_barcode) [list \
		-arg               -plaintext_barcode \
		-mand              1 \
		-check             ASCII \
		-desc              {Plaintext barcode to be encrypted}]

	set CORE_DEF(encrypted_barcode) [list \
		-arg               -encrypted_barcode \
		-mand              1 \
		-check             ASCII \
		-desc              {Encrypted barcode to be decrypted}]

	set CORE_DEF(pmt_receipt_func,opt) [list \
		-arg               -pmt_receipt_func \
		-mand              0 \
		-default           0 \
		-default_cfg       PMT_RECEIPT_FUNC \
		-check             BOOL \
		-desc              {Whether payment receipt formatting is enabled}]

	set CORE_DEF(pmt_receipt_format,opt) [list \
		-arg               -pmt_receipt_format \
		-mand              0 \
		-default           0   \
		-default_cfg       PMT_RECEIPT_FORMAT \
		-check             BOOL \
		-desc              {Payment receipt format, default used when pmt_receipt_func is disabled}]

	set CORE_DEF(pmt_receipt_tag,opt) [list \
		-arg               -pmt_receipt_tag \
		-mand              0 \
		-default           "" \
		-default_cfg       PMT_RECEIPT_TAG \
		-check             ASCII \
		-desc              {Payment receipt tag, default used when pmt_receipt_func is disabled}]

	set CORE_DEF(monitor,opt) [list \
		-arg              -monitor \
		-mand             0 \
		-default          0 \
		-default_cfg      MONITOR \
		-check            BOOL \
		-desc             {Whether to send monitor messages}]

	set CORE_DEF(providers,opt) [list \
		-arg              -providers \
		-mand             0 \
		-default          [list ixe oxxo seveneleven hsbc scotia banamex santander bancomer bajio] \
		-default_cfg      DINEROMAIL_PROVIDERS \
		-check            ASCII \
		-desc             {List of accepted providers}]

	set CORE_DEF(ccy_code,opt) [list \
		-arg              -ccy_code \
		-mand             0 \
		-default          {MXN} \
		-default_cfg      DINEROMAIL_CCY_CODE \
		-check            ASCII \
		-desc             {The currency code which is used for Dineromail payments}]

	set CORE_DEF(type) [list \
		-arg              -type \
		-mand             1 \
		-check            ASCII \
		-desc             {Dineromail Response type}]

	set CORE_DEF(value) [list \
		-arg              -value \
		-mand             1 \
		-check            ASCII \
		-desc             {Dineromail return value for the type}]

	set CORE_DEF(dflt) [list \
		-arg              -dflt \
		-mand             1 \
		-check            ASCII \
		-desc             {Default response to return for invalid value}]

	set CORE_DEF(auth_dep,opt) [list \
		-arg              -auth_dep \
		-mand             0 \
		-check            {ENUM -args {Y N}} \
		-default          Y \
		-desc             {Determines whether to authorize deposits/not}]

	set CORE_DEF(auth_wtd,opt) [list \
		-arg              -auth_wtd \
		-mand             0 \
		-check            {ENUM -args {Y N}} \
		-default          N \
		-desc             {Determines whether to authorize withdrawals/not}]

	set CORE_DEF(balance_check,opt) [list \
		-arg              -balance_check \
		-mand             0 \
		-check            {ENUM -args {Y N}} \
		-default          Y \
		-desc             {Do balance check}]

	set CORE_DEF(nickname,opt) [list \
		-arg              -nickname \
		-mand             0 \
		-check STRING     -default {Dineromail} \
		-desc             {Nickname to identify for the customer payment method}]

	set CORE_DEF(pmt_ids) [list \
		-arg              -pmt_ids \
		-mand             1 \
		-check            ASCII \
		-desc             {List of payment ids whose status is required}]

	set CORE_DEF(url) [list \
		-arg              -url \
		-mand             1 \
		-check            ASCII \
		-desc             {Dineromail IPN URL}]

	set CORE_DEF(conn_timeout) [list \
		-arg              -conn_timeout \
		-mand             1 \
		-check            UINT \
		-desc             {Connection timeout for this request}]

	set CORE_DEF(txn_id,opt) [list \
		-arg              -txn_id \
		-mand             0 \
		-check            ASCII \
		-default          {} \
		-desc             {Dineromail transaction id}]

	set CORE_DEF(ipn_txn_id,opt) [list \
		-arg              -ipn_txn_id \
		-mand             0 \
		-check            ASCII \
		-default          {} \
		-desc             {Dineromail IPN transaction id}]

	set CORE_DEF(dm_status,opt) [list \
		-arg              -dm_status \
		-mand             0 \
		-check            ASCII \
		-default          {} \
		-desc             {Dineromail status}]

	set CORE_DEF(barcode,opt) [list \
		-arg              -barcode \
		-mand             0 \
		-check            ASCII \
		-default          {} \
		-desc             {Dineromail barcode}]

	set CORE_DEF(message,opt) [list \
		-arg              -message \
		-mand             0 \
		-check            ASCII \
		-default          {} \
		-desc             {Dineromail or Admin message}]

	set CORE_DEF(no_settle,opt) [list \
		-arg              -no_settle \
		-mand             0 \
		-check            {ENUM -args {0 1}} \
		-default          0 \
		-desc             {Determine whether to settle or not in the stored procedure}]

	set CORE_DEF(provider) [list \
		-arg              -provider \
		-mand             1 \
		-check            ASCII \
		-desc             {Payment provider}]
}

# Register Dineromail interface
core::args::register \
	-interface    core::payment::DMBC::init \
	-desc         {Initialise the Dineromail package} \
	-args [list \
		$core::payment::DMBC::CORE_DEF(pmt_receipt_func,opt) \
		$core::payment::DMBC::CORE_DEF(pmt_receipt_format,opt) \
		$core::payment::DMBC::CORE_DEF(pmt_receipt_tag,opt) \
		$core::payment::DMBC::CORE_DEF(monitor,opt) \
		$core::payment::DMBC::CORE_DEF(providers,opt) \
		$core::payment::DMBC::CORE_DEF(ccy_code,opt) \
	] \
	-body {

		# Initialise the harness if it has been provided with package ifneeded.
		#
		# The harness nor the tests will be deployed in a live
		# environment and they are configured off by default
		if {"core::harness::payment::DMBC" in [package names]} {
			if {![catch {
				package require core::harness::payment::DMBC 1.0
			} err]} {
				core::harness::payment::DMBC::init
			} else {
				core::log::write INFO {Error initialising DMBC Harness: $err $::errorInfo}
			}
		}
	}

core::args::register \
	-interface    core::payment::DMBC::encrypt_barcode \
	-desc         {Encrypt and return a barcode given its plaintext} \
	-returns      ASCII \
	-args [list \
		$core::payment::DMBC::CORE_DEF(plaintext_barcode) \
	]

core::args::register \
	-interface    core::payment::DMBC::decrypt_barcode \
	-desc         {Decrypt and return an encrypted barcode} \
	-returns      ASCII \
	-args [list \
		$core::payment::DMBC::CORE_DEF(encrypted_barcode) \
	]

core::args::register \
	-interface    core::payment::DMBC::response_desc \
	-desc         {Returns the description code of a response item, given the numeric identifier} \
	-returns      ASCII \
	-args [list \
		$core::payment::DMBC::CORE_DEF(type) \
		$core::payment::DMBC::CORE_DEF(value) \
		$core::payment::DMBC::CORE_DEF(dflt) \
	]

core::args::register \
	-interface    core::payment::DMBC::response_code \
	-desc         {Returns the numeric identifier of a response item, given the descriptive code} \
	-returns      ASCII \
	-args [list \
		$core::payment::DMBC::CORE_DEF(type) \
		$core::payment::DMBC::CORE_DEF(value) \
		$core::payment::DMBC::CORE_DEF(dflt) \
	]

core::args::register \
	-interface    core::payment::DMBC::insert_cpm \
	-desc         {Insert a Dineromail payment method} \
	-returns      ASCII \
	-args [list \
		$core::payment::CORE_DEF(cust_id) \
		$core::payment::DMBC::CORE_DEF(auth_dep,opt) \
		$core::payment::DMBC::CORE_DEF(auth_wtd,opt) \
		$core::payment::DMBC::CORE_DEF(balance_check,opt) \
		$core::payment::CORE_DEF(transactional) \
		$core::payment::DMBC::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface core::payment::DMBC::update_cpm \
	-desc      {Update DMBC customer pay method details} \
	-returns   ASCII \
	-args      [list \
		$::core::payment::CORE_DEF(cpm_id) \
		$::core::payment::CORE_DEF(cust_id) \
		$::core::payment::CORE_DEF(new_cpm_status,opt) \
		$::core::payment::CORE_DEF(nickname,opt) \
	]

core::args::register \
	-interface    core::payment::DMBC::remove_cpm \
	-desc         {Remove a Dineromail payment method} \
	-returns      ASCII \
	-args [list \
		$core::payment::CORE_DEF(cpm_id) \
	]

core::args::register \
	-interface    core::payment::DMBC::make_ipn_request \
	-desc         {Makes a request to the Dineromail Instant Payment Notification service and parses the response} \
	-returns      ASCII \
	-args [list \
		$core::payment::DMBC::CORE_DEF(pmt_ids) \
		$core::payment::DMBC::CORE_DEF(url) \
		$core::payment::DMBC::CORE_DEF(conn_timeout) \
		$core::payment::CORE_DEF(source) \
	]

core::args::register \
	-interface    core::payment::DMBC::update_pmt \
	-desc         {Updates an existing Dineromail payment} \
	-returns      ASCII \
	-args [list \
		$core::payment::CORE_DEF(pmt_id) \
		$core::payment::CORE_DEF(status) \
		$core::payment::DMBC::CORE_DEF(txn_id,opt) \
		$core::payment::DMBC::CORE_DEF(ipn_txn_id,opt) \
		$core::payment::DMBC::CORE_DEF(dm_status,opt) \
		$core::payment::CORE_DEF(oper_id) \
		$core::payment::DMBC::CORE_DEF(barcode,opt) \
		$core::payment::DMBC::CORE_DEF(message,opt) \
		$core::payment::DMBC::CORE_DEF(no_settle,opt) \
		$core::payment::CORE_DEF(transactional) \
	]

core::args::register \
	-interface    core::payment::DMBC::make_deposit \
	-desc         {Makes a Dineromail payment} \
	-returns      ASCII \
	-args [list \
		$core::payment::CORE_DEF(acct_id) \
		$core::payment::CORE_DEF(cpm_id) \
		$core::payment::CORE_DEF(amount) \
		$core::payment::DMBC::CORE_DEF(provider) \
		$core::payment::CORE_DEF(ipaddr) \
		$core::payment::CORE_DEF(source) \
		$core::payment::CORE_DEF(unique_id) \
		$core::payment::CORE_DEF(oper_id) \
		$core::payment::CORE_DEF(comm_list) \
	]

core::args::register \
	-interface    core::payment::DMBC::get_pmt_details \
	-desc         {Get details of a Dineromail payment by the pmt_id} \
	-returns      ASCII \
	-args [list \
		$core::payment::CORE_DEF(pmt_id) \
	]

core::args::register \
	-interface    core::payment::DMBC::get_registered_ccy_code \
	-desc         {Get the CCY code that is used for Dineromail payment} \
	-returns      ASCII
