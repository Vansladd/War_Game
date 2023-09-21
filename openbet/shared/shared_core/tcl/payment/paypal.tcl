#
# (C) 2015 OpenBet Technology Ltd.  All rights reserved.
#
# OpenBet PayPal API
#
# PayPal Payment Interfaces
#       make_deposit     - Attempt to authorise a deposit
#       complete_deposit - Settle a previously authorised deposit
#       make_withdrawal  - Queue up a withdrawal to be processed
#       make_masspay     - Prepare and send a batch of withdrawals to PayPal
#       process_ipn      - Process an Instant Payment Notification message
#
# PayPal Gateway Interfaces
#       set_express_checkout         - Send the details of the transaction to be initiated
#       get_express_checkout_details - Get the status and details of the transaction
#       do_express_checkout          - Action the transaction
#       send_masspay                 - see PayPal Payment Interfaces
#       process_ipn                  - see PayPal Payment Interfaces
#
# Additional Interfaces
#       update_pmt_status - Update the status of the PayPal payment throws error on failure
#       get_cfg           - Gets a PayPal config
#

# package
#
set pkg_version 1.0
package provide core::payment::PPAL $pkg_version


# Dependencies
#
package require core::payment 1.0
package require core::args    1.0

# Namespace
#
core::args::register_ns \
	-namespace core::payment::PPAL \
	-version $pkg_version

namespace eval core::payment::PPAL {}


# Initialise
#
core::args::register \
	-interface core::payment::PPAL::init \
	-desc      {Initialisation procedure for PayPal payment method} \
	-allow_rpc 1 \



core::args::register \
	-interface core::payment::PPAL::insert_cpm \
	-args [list \
		[list -arg -cust_id       -mand 1 -check UINT                     -desc {Customer id}] \
		[list -arg -payer_id      -mand 0 -check ASCII                    -desc {PayPal Payer ID (unique in Paypals end)}] \
		[list -arg -email         -mand 0 -check ASCII                    -desc {PayPal email (username) used for payment}] \
		[list -arg -auth_dep      -mand 0 -check {ENUM -args {Y N P}}     -desc {Deposit authorisation status}] \
		[list -arg -auth_wtd      -mand 0 -check {ENUM -args {Y N P}}     -desc {Withdrawal authorisation status}] \
		[list -arg -transactional -mand 0 -check {ENUM -args {Y N}}       -desc {Is the execution of the stored procedure transactional}] \
	] \
	-return_data [list \
		[list -arg -cpm_id           -mand 1 -check UINT                  -desc {Payment method id}] \
	] \
	-errors [list PMT_ERR_ADD_CPM]



core::args::register \
	-interface core::payment::PPAL::get_details \
	-args [list \
		[list -arg -cust_id          -mand 1 -check UINT                  -desc {Customer id}] \
		[list -arg -cpm_id           -mand 1 -check UINT                  -desc {Customer pay method id}] \
	] \
	-return_data [list \
		[list -arg -email            -mand 1 -check ASCII                 -desc {Email address associated with the PayPal payment method}] \
		[list -arg -status           -mand 1 -check {ENUM -args {A S}}    -desc {Payment method status}] \
		[list -arg -payer_id         -mand 0 -check ASCII   -default {}   -desc {Paypal payer_id token that verifies the paypal account has been validated}] \
	] \
	-errors [list PMT_NOCPM]



core::args::register \
	-interface core::payment::PPAL::make_deposit \
	-args [list \
		[list -arg -cpm_id           -mand 1 -check UINT                  -desc {Customer pay method id}] \
		[list -arg -cust_id          -mand 1 -check UINT                  -desc {Customer id}] \
		[list -arg -amount           -mand 1 -check UMONEY                -desc {Amount for transaction}] \
		[list -arg -return_url       -mand 1 -check ASCII                 -desc {URL customer sent to after successful transaction}] \
		[list -arg -cancel_url       -mand 1 -check ASCII                 -desc {URL customer sent to after cancelled transaction}] \
		[list -arg -ip_addr          -mand 0 -check IPADDR -default {}    -desc {IP Address that the  transaction is made from}] \
		[list -arg -source           -mand 0 -check ASCII  -default {I}   -desc {The channel that the  transaction is made from}] \
		[list -arg -oper_id          -mand 0 -check UINT   -default {}    -desc {The operator id that the  transaction is made from}] \
	] \
	-return_data [list \
		[list -arg -pmt_id           -mand 1 -check UINT                  -desc {Payment id}] \
		[list -arg -redirect_url     -mand 1 -check ASCII                 -desc {PayPal URL where customer can authorise payment}] \
	] \
	-errors [list \
		PMT_CUST \
		INTERNAL_ERROR \
		EXCEEDED_DEP_LIMIT \
		PMT_SPEED \
		PMT_INVALID_CPM \
		PMT_ERR_MTHD_BAD_DEP \
		PMT_RESP \
		PMT_PAYPAL_MISSING_TOKEN \
		PMT_SESSION_EXPIRED \
		PMT_REF \
		PMT_MAX \
		PMT_ALREADY_COMPLETED \
		PMT_PAYPAL_PMT_SOURCE \
		PMT_REDIRECT_PENDING \
		PMT_NOT_AUTHORISED \
		PMT_DECL \
		PMT_PENDING_FRAUD_INVESTIGATION \
		PMT_FRAUD_ERR \
	]



core::args::register \
	-interface core::payment::PPAL::complete_deposit \
	-args [list \
		[list -arg -cust_id          -mand 1 -check UINT                  -desc {Customer id}] \
		[list -arg -token            -mand 1 -check ASCII                 -desc {PayPal token to identify transaction}] \
		[list -arg -is_cancel        -mand 1 -check {ENUM -args {Y N}}    -desc {Is the deposit cancelled}] \
	] \
	-return_data [list \
		[list -arg -pmt_id           -mand 1 -check UINT                  -desc {Payment id}] \
	] \
	-errors [list \
		PMT_CUST \
		PMT_PAYPAL_MISSING_TOKEN \
		INTERNAL_ERROR \
		PMT_ERR_ID \
		PMT_ERR_INVALID_STATUS \
		PMT_PAYPAL_INVALID_EMAIL_DOMAIN \
		PMT_PAYPAL_DUPLICATE_PAYER_ID \
		PMT_PAYPAL_PAYER_ID_CHANGE \
		PMT_RESP \
		PMT_PAYPAL_MISSING_TOKEN \
		PMT_SESSION_EXPIRED \
		PMT_REF \
		PMT_MAX \
		PMT_ALREADY_COMPLETED \
		PMT_PAYPAL_PMT_SOURCE \
		PMT_REDIRECT_PENDING \
		PMT_NOT_AUTHORISED \
		PMT_DECL \
		PMT_PENDING_FRAUD_INVESTIGATION \
		PMT_FRAUD_ERR \
		PMT_FUNDS \
	]



core::args::register \
	-interface core::payment::PPAL::make_withdrawal \
	-args [list \
		[list -arg -cpm_id           -mand 1 -check UINT                  -desc {Customer pay method id}] \
		[list -arg -cust_id          -mand 1 -check UINT                  -desc {Customer id}] \
		[list -arg -amount           -mand 1 -check UMONEY                -desc {Amount for transaction}] \
		[list -arg -ip_addr          -mand 1 -check ASCII                 -desc {IP Address that the  transaction is made from}] \
		[list -arg -source           -mand 1 -check ASCII                 -desc {The channel that the  transaction is made from}] \
	] \
	-return_data [list \
		[list -arg -pmt_id           -mand 1 -check UINT                  -desc {Payment id}] \
	] \
	-errors [list \
		PMT_CUST \
		INTERNAL_ERROR \
		PMT_FUNDS \
		PMT_SPEED \
		PMT_INVALID_CPM \
		PMT_ERR_MTHD_BAD_WTD \
		PMT_WTD_DEP_FIRST \
	]



core::args::register \
	-interface core::payment::PPAL::update_pmt \
    -desc      {Update the status of the PayPal payment throws error on failure} \
	-args [list \
		[list -arg -pmt_id           -mand 1 -check UINT                                     -desc {Payment id}] \
		[list -arg -status           -mand 1 -check {ENUM -args {P Y N R U L I W H X B A E}} -desc {Payment status}] \
		[list -arg -no_settle        -mand 0 -check {ENUM -args {1 0}} -default 1            -desc {Prevent setting settled_by and settled_at and prevent returning payment for withdrawals}] \
		[list -arg -pp_txn_id        -mand 0 -check ASCII                                    -desc {Transaction id to associate with the payment}] \
		[list -arg -extra_info       -mand 0 -check ASCII                                    -desc {Extra info to associate with the payment}] \
	] \
	-errors [list \
		INTERNAL_ERROR \
	]



# Do Masspay request
#
# Example -payment_details value:
# 0 {pmt_id 23 pp_inv_num P23 payer_id W45RTY7UI email tom@openbet.com amount 10.00} \
# 1 {pmt_id 24 pp_inv_num P24 payer_id K57ESB2BS email joe@openbet.com amount 16.00}
#
core::args::register \
	-interface core::payment::PPAL::do_masspay \
    -desc      {Process Masspay payments} \
	-args [list \
		[list -arg -ccy_code         -mand 1 -check ASCII                 -desc {The currency to use in this MassPay request}] \
		[list -arg -total_amount     -mand 1 -check UMONEY                -desc {Sum of all the individual batch amounts}] \
		[list -arg -payment_details  -mand 1 -check ASCII                 -desc {Contains nested dict with payment details}] \
		[list -arg -note             -mand 0 -check ASCII  -default {}    -desc {Custom note sent to the recipient of the payment}] \
		[list -arg -email_subject    -mand 0 -check ASCII  -default {}    -desc {The subject line of PayPal email sent on completion}] \
	]



core::args::register \
	-interface core::payment::PPAL::authenticate_notification \
	-desc      {Authenticate the notification by sending it back to the gateway} \
	-args [list \
		[list -arg -notification     -mand 1 -check ASCII                  -desc {The notification received from the IPN}] \
	] \
	-return_data [list \
		[list -arg -method             -mand 1 -check ASCII    -desc {Method of the original transaction e.g. masspay}] \
		[list -arg -txn_status         -mand 1 -check ASCII    -desc {Status provided in the notification}] \
		[list -arg -decoded_parameters -mand 1 -check ASCII    -desc {Name Value pairs of information parsed from the Notification}] \
	]



core::args::register \
	-interface core::payment::PPAL::get_notification_acknowledgement \
	-desc      {Generate and return the message used to acknowledge the notification} \
	-args [list \
		[list -arg -notification     -mand 1 -check ASCII     -desc {The notification received from the IPN}] \
	] \
	-return_data [list \
		[list -arg -acknowledgement  -mand 1 -check ASCII     -desc {Message returned to acknowledge the notification}] \
	]



core::args::register \
	-interface core::payment::PPAL::process_masspay_notification \
	-desc      {Verify the Masspay request by checking the Openbet database} \
	-args [list \
		[list -arg -decoded_parameters     -mand 1 -check ASCII    -desc {Name Value pairs of parameters decoded from IPN}] \
	] \
	-errors [list \
		PMT_ERR_INVALID_STATUS \
		INTERNAL_ERROR \
	]



core::args::register \
	-interface core::payment::PPAL::process_case_notification \
	-desc      {Process a Case (chargeback / complaint / dispute) Notification} \
	-args [list \
		[list -arg -decoded_parameters     -mand 1 -check ASCII    -desc {Name Value pairs of parameters decoded from IPN}] \
	] \
	-errors [list \
		INTERNAL_ERROR \
	]



core::args::register \
	-interface core::payment::PPAL::process_reversal_notification \
	-desc      {Process a Reversal Notification} \
	-args [list \
		[list -arg -decoded_parameters     -mand 1 -check ASCII    -desc {Name Value pairs of parameters decoded from IPN}] \
	] \
	-errors [list \
		INTERNAL_ERROR \
	]



core::args::register \
    -interface core::payment::PPAL::get_cfg \
    -desc      {Gets a PayPal config} \
    -returns   ASCII \
    -args      [list \
		[list -arg -cfg_item        -mand 1 -check NONE                   -desc {PayPal config item to get}] \
    ]



core::args::register \
    -interface core::payment::PPAL::get_ref_uid \
	-desc      {Get next payment ref and format it as per Datacash requirements} \
	-returns   ASCII
