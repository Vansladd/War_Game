#
# $id:$
#
# Integration with the PayPal APIs
#
#
#    Configuration - optional:
#      PAYPAL_CCY_CODES             - list of currency codes
#                                     (default: GBP, EUR, USD, CAD, AUD, JPY)
#      PAYPAL_API_VERSION           - Version of API currently in use
#                                     (default: 1.0)
#      PAYPAL_MASSPAY_MAX_PMTS      - the maximum number of transactions per
#                                     MassPay API request (default: 250)
#      PAYPAL_UNKNOWN_PMT_DELAY     - time to wait before processing unknown
#                                     pmts in the cronjob (default: 10 minutes)
#      PAYPAL_TS_LOWER_RANGE        - seconds before payment cr_date to start
#                                     transaction search
#      PAYPAL_TS_UPPER_RANGE        - seconds after payment cr_date to end
#                                     transaction search
#      PAYPAL_QUICK_REQ_CHECK_IP    - during paypal quick registration, do we
#                                     check the ip
#      PAYPAL_REDIRECT_DELAY        - delay to use when redirecting
#                                     (default: 5000)
#      PAYPAL_MAX_SEARCH_PMTS       - maximium number of payments returned by a
#                                     transaction search
#      PAYPAL_USE_CERT              - whether to use a certification file
#                                     (default: no)
#      PAYPAL_LOCALE_MAP            - language to paypal local mapping
#      PAYPAL_IPN_PROCESSOR         - URL for the IPN processing app
#      PAYPAL_EXPRESS_CHECKOUT_URL  - express checkout url
#      PAYPAL_CERT_FILE             - location of the certification file
#

#
# Dependancies (standard packages)
#
package require net_socket
package require util_appcontrol
package require pmt_validate

#if {[OT_CfgGet MONITOR 0]} {
#	package require MONITOR
#}

namespace eval ob_paypal {
	variable INIT
	set INIT 0
	variable CFG
	variable PMT_DATA
}

proc ob_paypal::init {} {
	variable INIT
	variable CFG
	variable PMT_DATA

	if {$INIT} { return }

	ob_log::write INFO {Initialising ob_paypal}

	# optional config items
	# NOTE: wtd_delay has been deprecated by tPayMthdCtrl
	foreach {c dflt} [list\
						ccy_codes             [list GBP EUR USD CAD AUD JPY] \
						wtd_delay             10 \
						api_version           1.0 \
						masspay_max_pmts      250 \
						unknown_pmt_delay     10 \
						ts_lower_range        5 \
						ts_upper_range        15 \
						quick_req_check_ip    1 \
						redirect_delay        5000 \
						max_search_pmts       100 \
						use_cert              0 \
						cert_file             {} \
						ipn_processor         SETME \
						express_checkout_url  SETME] {
		set CFG($c) [OT_CfgGet "PAYPAL_[string toupper $c]" $dflt]
	}

	# set up locales
	set locale_map [OT_CfgGet PAYPAL_LOCALE_MAP {}]
	foreach {lang locale} $locale_map {
		set CFG(locale_map,$lang) $locale
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CFG(pmt_receipt_format) 0
		set CFG(pmt_receipt_tag)    ""
	}

	# setup default payment information for the PMG
	array set PMT_DATA   [list]
	set PMT_DATA(type)   "PPAL"

	ob_paypal::prep_qrys

	set INIT 1

}

proc ob_paypal::prep_qrys {} {

	# insert a paypal pay method
	ob_db::store_qry ob_paypal::insert_cpm {
		execute procedure pCPMInsPayPal (
			p_cust_id       = ?,
			p_auth_dep      = ?,
			p_auth_wtd      = ?,
			p_transactional = ?,
			p_payer_id      = ?,
			p_email         = ?
		)
	}

	# insert a paypal payment
	ob_db::store_qry ob_paypal::insert_pmt {
		execute procedure pPmtInsPayPal (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_pg_acct_id     = ?,
			p_pg_host_id     = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_unique_id      = ?,
			p_pp_txn_id      = ?,
			p_pp_token       = ?,
			p_extra_info     = ?,
			p_pp_inv_num     = ?,
			p_transactional  = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?,
			p_overide_min_wtd =?,
			p_call_id        = ?
		)
	}

	# Update the pmt
	ob_db::store_qry ob_paypal::update_pmt {
		execute procedure pPmtUpdPayPal (
			p_pmt_id     = ?,
			p_status     = ?,
			p_no_settle  = ?,
			p_pp_txn_id  = ?,
			p_extra_info = ?
		)
	}

	# update a paypal token
	ob_db::store_qry ob_paypal::update_token {
		execute procedure pPayPalUpdToken (
			p_pmt_id   = ?,
			p_pp_token = ?
		)
	}

	# update a paypal token on a quick reg
	ob_db::store_qry ob_paypal::update_token_quick_reg {
		update tPayPalQuickReg
			set pp_token = ?
		where
			reg_id = ?
	}

	# update a paypal payer_id
	ob_db::store_qry ob_paypal::update_payer_id {
		execute procedure pPayPalUpdPayerId (
			p_acct_id  = ?,
			p_cpm_id   = ?,
			p_payer_id = ?,
			p_email    = ?,
			p_pmt_id   = ?
		)
	}

	# get details of a payment
	ob_db::store_qry ob_paypal::get_monitor_data {
		select
			p.payment_sort,
			p.ipaddr,
			p.source,
			p.cr_date,
			p.amount      as amount_user,
			p.acct_id,
			cpm.payer_id,
			a.balance,
			a.ccy_code,
			c.cust_id,
			c.username,
			c.country_code,
			c.notifyable,
			c.cr_date     as reg_date,
			cr.fname,
			cr.lname,
			cr.addr_postcode,
			cr.email,
			cr.addr_country,
			cr.addr_city,
			cr.code       as reg_code,
			ccy.exch_rate
		from
			tPmt         p,
			tCpmPayPal   cpm,
			tAcct        a,
			tCustomer    c,
			tCustomerReg cr,
			tCcy         ccy
		where
			p.pmt_id   = ?            and
			p.cpm_id   = cpm.cpm_id   and
			p.acct_id  = a.acct_id    and
			a.cust_id  = c.cust_id    and
			c.cust_id  = cr.cust_id   and
			a.ccy_code = ccy.ccy_code
	}

	# get details of a payment based on token
	ob_db::store_qry ob_paypal::get_pmt_by_token {
		select
			p.pmt_id,
			p.amount,
			p.status,
			pp.pp_inv_num,
			cp.cpm_id,
			cp.payer_id,
			cp.email
		from
			tPmt         p,
			tPmtPayPal   pp,
			tCPMPayPal   cp
		where
			p.acct_id             = ?         and
			p.pmt_id              = pp.pmt_id and
			pp.pp_token           = ?         and
			NVL(pp.pp_token,'')  != ''        and
			p.cpm_id              = cp.cpm_id
	}

	# remove a customer payment method (only if there are no successful/
	# incomplete payments on it)
	ob_db::store_qry ob_paypal::remove_cpm {
		update tCustPayMthd set
			status = 'X'
		where
			cpm_id = ? and
			not exists (
				select
					pmt_id
				from
					tPmt
				where
					cpm_id = ? and
					status not in ('N','X')
			)
	}

	# insert a quick registration attempt
	ob_db::store_qry ob_paypal::ins_quick_reg {
		insert into tPayPalQuickReg (
			ipaddr,
			linked_md5
		) values (
			?,
			?
		)
	}

	# validate a quick reg return attempt
	ob_db::store_qry ob_paypal::validate_quick_reg_return {
		execute procedure pPayPalQckRegVal (
			p_pp_token    = ?,
			p_ipaddr      = ?,
			p_check_ip    = ?
		)
	}

	# validate a quick reg registration attempt
	ob_db::store_qry ob_paypal::validate_quick_reg_register {
		select
			reg_id
		from
			tPayPalQuickReg q
		where
			q.pp_token   = ?
		and q.linked_md5 = ?
		and not exists (
			select
				pmt_id
			from
				tPmtPayPal p
			where
				p.pp_token = ?
		)
	}
}



#
#  ob_paypal::get_cfg
#
#    cfg -the config item to get
#
#    Returns the value of the config item
#
proc ob_paypal::get_cfg { cfg } {
	variable CFG
	return $CFG($cfg)
}



#
#  ob_paypal::insert_cpm
#
#  Insert a new PayPal customer payment method (CPM) - assumes that a check has
#  already been made to ensure it is allowed
#
#  cust_id       - the customer's ID
#  payer_id      - the PayPal Payer ID (unique in Paypals end)
#  email         - the PayPal email (username) used for payment
#  auth_dep      - deposit authorisation status
#  auth_wtd      - withdrawal authorisation status
#  transactional - determines if the execution of the stored procedure is
#                  transactional/not
#
#  returns -  a list [0 error_msg] on failure on payment insertion, [1 cpm_id]
#             otherwise
#
proc ob_paypal::insert_cpm {
	cust_id
	{payer_id {}}
	{email {}}
	{auth_dep P}
	{auth_wtd P}
	{transactional Y}
} {

	ob_log::write INFO \
		{ob_paypal::insert_cpm($cust_id,$payer_id,$email,$auth_dep,$auth_wtd,$transactional)}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::insert_cpm \
			$cust_id $auth_dep $auth_wtd $transactional $payer_id $email]
	} msg]} {

		ob_log::write ERROR {Error executing query ob_paypal::insert_cpm - $msg}
		return [list 0 PAYPAL_INSERT_CPM_ERROR]

	} else {
		set cpm_id [db_get_coln $rs 0 0]
		ob_db::rs_close $rs
		return [list 1 $cpm_id]
	}
}



#
#  ob_paypal::insert_pmt
#
#  Insert a new PayPal payment
#
#  acct_id            - the customers account ID
#  cpm_id             - the customers Customer Payment Method ID
#  payment_sort       - either DEP/WTD
#  amount             - the payment amount
#  ipaddr             - the ipaddr of the user who made the payment
#  source             - the Channel source of the payment
#  unique_id          - a unique ID value
#  pp_txn_id          - The paypal transaction ID
#  pp_token           - The paypal token (for Express Checkout only)
#  ccy_code           - the users currency code
#  inv_num            - invoice number to reference payment with PayPal
#  extra_info         - contains any extra info neccessary to describe the
#                       payment
#  transactional      - determines if the stored procedure execute is
#                       transactional or not
#  check_fraud_status - check fraud status if a withdrawal
#  min_overide   - whether this payment is allowed to overide the minimum withdrawal limits
#  call_id       - (optional) if this is a telebetting transaction, the tCall.call_id for this
#
#  returns -  a list [0 error_msg] on failure on payment insertion,
#             [1 pmt_id inv_num] otherwise
#
proc ob_paypal::insert_pmt {
	acct_id
	cpm_id
	payment_sort
	amount
	ipaddr
	source
	unique_id
	pp_txn_id
	pp_token
	ccy_code
	{inv_num {}}
	{extra_info {}}
	{transactional Y}
	{check_fraud_status 1}
	{min_overide "N"}
	{call_id ""}
} {

	variable PMT_DATA
	variable CFG

	set fn "ob_paypal::insert_pmt"

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
	 	return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	# OVS check.
	if { [OT_CfgGet FUNC_OVS 0] && [OT_CfgGet FUNC_OVS_VERF_PPAL_CHK 1]} {
		set chk_resp [verification_check::do_verf_check \
			"PPAL" \
			$payment_sort \
			$acct_id]

		if {![lindex $chk_resp 0]} {
			return [list 0 [lindex $chk_resp 2]]
		}
	}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::insert_pmt \
			$acct_id \
			$cpm_id \
			$payment_sort \
			$amount \
			$PMT_DATA(pg_acct_id) \
			$PMT_DATA(pg_host_id) \
			$ipaddr \
			$source \
			$unique_id \
			$pp_txn_id \
			$pp_token \
			$extra_info \
			$inv_num \
			$transactional \
			$CFG(pmt_receipt_format) \
			$CFG(pmt_receipt_tag) \
			$min_overide \
			$call_id ]
	} msg]} {

		ob_log::write ERROR \
			{$fn Error executing query ob_paypal::insert_pmt - $msg}

		# if its a known error set correct error otherwise use a
		# generic error
		switch -glob $msg {
			*AX8206* {
				set status PAYPAL_WTD_NEED_PAYER_ID
			}
			*AX5006* {
				set status PAYPAL_WTD_INSUFFICIENT_FUNDS
			}
			*AX50015* {
				set status PAYPAL_SPEED_LIMIT
			}
			default {
				set status PAYPAL_PMT_INS_FAIL
			}
		}

		return [list 0 $status]

	} else {

		set pmt_id  [db_get_coln $rs 0 0]
		set inv_num [db_get_coln $rs 0 1]
		ob_db::rs_close $rs

		# if withdrawal, may need to check the fraud status
		if {$payment_sort == "W" && $check_fraud_status} {
			set process_pmt [ob_pmt_validate::chk_wtd_all\
				$acct_id\
				$pmt_id\
				"PPAL"\
				"----"\
				$amount\
				$ccy_code]
		}

		return [list 1 $pmt_id $inv_num]
	}
}



# Store details of a PayPal quick Registration attempt
#
#   ipaddr   - the ip address
#
#   returns  - 1 if successful, 0 if fails
#
proc ob_paypal::ins_quick_reg { ipaddr } {

	set fn "ob_paypal::ins_quick_reg"

	set linked_md5 [md5 [expr {rand()}]]

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::ins_quick_reg \
			$ipaddr $linked_md5]
	} msg]} {
		ob_log::write ERROR \
			{$fn executing query ob_paypal::ins_quick_reg - $msg}
		return [list 0]
	}

	# did we insert?
	if {![ob_db::garc ob_paypal::ins_quick_reg]} {
		ob_log::write ERROR {$fn  Failed to insert quick reg}
		return [list 0]
	}

	set reg_id [ob_db::get_serial_number ob_paypal::ins_quick_reg]

	ob_db::rs_close $rs

	return [list 1 $reg_id]

}



#
#  ob_paypal::update_pmt_status
#
# Update a PayPal payment
#
#  pmt_id     - the ID of the payment
#  status     - the status of the payment
#  no_settle  -
#  pp_txn_id  - optional transaction id to associate with the payment
#  extra_info - optional extra info to associate with the payment
#
#  returns - 1 on succesful update, 0 otherwise
#
proc ob_paypal::update_pmt_status {
	pmt_id
	status
	{no_settle 1}
	{pp_txn_id ""}
	{extra_info ""}
} {

	set fn "ob_paypal::update_pmt_status"

	ob_log::write INFO \
		{$fn - $pmt_id,$status,$no_settle,$pp_txn_id,$extra_info}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::update_pmt \
			$pmt_id $status $no_settle $pp_txn_id $extra_info]
	} msg]} {
		ob_log::write ERROR {Error executing query ob_paypal::update_pmt - $msg}
		return 0
	}

	if {
		($status == "Y" || $status == "N" || $status == "X") &&
		[OT_CfgGet MONITOR 0]
	} {
		ob_paypal::send_monitor_msg $pmt_id $status
	}

	return 1
}



#
#  ob_paypal::remove_cpm_on_first_payment
#
# Remove a PayPal payment method (if no successful/active payments)
#
#   cpm_id - id of payment method to remove
#
#  returns - 1 on successful removal, 0 otherwise
#
proc ob_paypal::remove_cpm_on_first_payment { cpm_id } {

	set fn "ob_paypal::remove_cpm_on_first_payment"

	ob_log::write INFO \
		{$fn cpm_id: $cpm_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::remove_cpm $cpm_id $cpm_id]
	} msg]} {
		ob_log::write ERROR \
			{$fn Error executing query ob_paypal::update_pmt - $msg}
		return 0
	}

	# did we remove?
	if {![ob_db::garc ob_paypal::remove_cpm]} {
		ob_log::write INFO {$fn Did not remove cpm: $cpm_id}
		return 0
	}

	return 1
}



#
# Grab pmt details and send a monitor message.
#
# pmt_id - the pmt to send details of
# status - the status of the payment
#
proc ob_paypal::send_monitor_msg { pmt_id status } {

	set fn "ob_paypal::send_monitor_msg"

	ob_log::write DEBUG {$fn pmt_id: $pmt_id, status: $status)}

	if {[catch {set rs [ob_db::exec_qry ob_paypal::get_monitor_data $pmt_id]} msg]} {
		ob_log::write ERROR \
			{$fn Error executing ob_paypal::get_monitor_data - $msg}
	} else {
		set nrows [db_get_nrows $rs]

		if {$nrows == 1} {

			set cols [db_get_colnames $rs]

			foreach c $cols {
				set PMT($c) [db_get_col $rs 0 $c]
			}

			set amount_sys \
				[format "%.2f" [expr {$PMT(amount_user) / $PMT(exch_rate)}]]

			if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
				set PMT(fname)        [ob_cust::normalise_unicode $PMT(fname) 0 0]
				set PMT(lname)        [ob_cust::normalise_unicode $PMT(lname) 0 0]
				set PMT(addr_country) [ob_cust::normalise_unicode $PMT(addr_country) 0 0]
				set PMT(addr_city)    [ob_cust::normalise_unicode $PMT(addr_city) 0 0]
			}

			if {[catch {set result [MONITOR::send_pmt_non_card\
				$PMT(cust_id)\
				$PMT(username)\
				$PMT(fname)\
				$PMT(lname)\
				$PMT(addr_postcode)\
				$PMT(email)\
				$PMT(country_code)\
				$PMT(reg_date)\
				$PMT(reg_code)\
				$PMT(notifyable)\
				$PMT(acct_id)\
				$PMT(balance)\
				"$PMT(ipaddr)-$PMT(addr_country)"\
				"$PMT(ipaddr)-$PMT(addr_city)"\
				"PPAL"\
				$PMT(ccy_code)\
				$PMT(amount_user)\
				$amount_sys\
				$pmt_id\
				$PMT(cr_date)\
				$PMT(payment_sort)\
				$status\
				$PMT(payer_id)\
				"N/A"\
				$PMT(source)]
			} msg]} {
				ob_log::write ERROR {$fn Failed to send monitor message : $msg}
			}
		} else {
			ob_log::write ERROR {$fn Can't find payment with pmt_id=$pmt_id}
		}

		ob_db::rs_close $rs
	}
}



#
# Update a PayPal payment's token field
#
#    pmt_id   - payment identifier
#    pp_token - paypal token
#
#    returns 1 if successful, 0 if not
#
proc ob_paypal::update_token { pmt_id pp_token } {

	ob_log::write INFO {ob_paypal::update_token($pmt_id,$pp_token)}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::update_token $pmt_id $pp_token]
	} msg]} {
		ob_log::write ERROR \
			{Error executing query ob_paypal::update_token - $msg}
		return 0
	}
	return 1
}



#
# Update a PayPal payment's token field (for quick reg)
#
#    reg_id   - registration identifier
#    pp_token - paypal token
#
#    returns - 1 if successful, 0 if not
#
proc ob_paypal::update_token_quick_reg { reg_id pp_token } {

	ob_log::write INFO {ob_paypal::update_token_quick_reg($reg_id,$pp_token)}

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::update_token_quick_reg \
			$pp_token $reg_id]
	} msg]} {
		ob_log::write ERROR \
			{Error executing query ob_paypal::update_token_quick_reg - $msg}
		return 0
	}
	return 1
}



#
#  ob_paypal::do_transaction_search
#
#  A Public Procedure that makes a TransactionSearch
#  Paypal API call. A Start Date must be specified in
#  order for the details on a users transacrtions to be given.
#
#  inv_num     - the invoice number used to identify payment on paypal side
#  start_date  - the start date range for the Transaction search (mandatory)
#  ccy_code    - the currency which the user is using
#
#  returns - a list  of the following format:
#                  -> [0 error_info] on any failure encountered (either on
#                       req/response stage)
#                  ->[1 response_info] on a successful request,
#                       'response info' : a list of name/value pairs
#
proc ob_paypal::do_transaction_search { inv_num start_date ccy_code } {

	variable CFG

	set fn "ob_paypal::do_transaction_search"

	if {$inv_num == ""} {
		return [list 0 "PAYPAL_INVALID_INV_NUM"]
	}

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
		return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	# get the start & end time ranges for tyhe transaction search lookup
	set start_date_seconds [clock scan $start_date]
	set start_time [ob_paypal::_format_time [expr {$start_date_seconds - $CFG(ts_lower_range)}]]
	set end_time   [ob_paypal::_format_time [expr {$start_date_seconds + $CFG(ts_upper_range)}]]

	set params [list \
		INVNUM       $inv_num \
		STARTDATE    $start_time \
		ENDDATE      $end_time \
	]

	# send the TransactionSearch request
	foreach {success resp} [_send_nvp_request "TransactionSearch" $params] {}

	# was it successful?
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}

		return [list 0 $resp]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}
		return [list 0 $pairs]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		ob_log::write ERROR {$fn ACK not found in response}
		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	# was the request successful
	if {$RESP(ACK)!="Success" && $RESP(ACK)!="SuccessWithWarning"} {
		ob_log::write ERROR {$fn Failed. ACK: $RESP(ACK)}
		return [list 0 PAYPAL_REQUEST_FAILED]
	}

	set pmts [list]

	# loop through each of the payments
	for {set i 0} {$i < $CFG(max_search_pmts)} {incr i} {
		if {![info exists RESP(L_TRANSACTIONID${i})]} {
			break
		} else {
			set pmt [list]
			foreach f {L_TRANSACTIONID L_EMAIL L_STATUS L_AMT} {
				lappend pmt $f $RESP(${f}${i})
			}
			lappend pmts $pmt
		}
	}

	# did we find any payments?
	if {[llength $pmts]} {
		return [list 1 $pmts]
	} else {
		return [list 0 PAYPAL_NO_DATA_FOUND]
	}

}



#
#  ob_paypal::get_transaction_details
#
# makes a GetTransactionDetails Paypal call. The Transaction ID must be
# specified in order for the details to be given.
#
#  pp_txn_id  - the Transaction ID that we're searchign for details of
#  ccy_code   - the users currency
#
#  returns - a list  of the following format:
#                  -> [0 error_info] on any failure encountered (either on
#                       req/response stage)
#                  ->[1 response_info] on a successful request,
#                       'response info' : a list of name/value pairs
#
proc ob_paypal::get_transaction_details {pp_txn_id ccy_code} {

	set fn "ob_paypal::get_transaction_details"

	ob_log::write INFO {$fn $pp_txn_id $ccy_code}

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
	 	return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	set params [list TRANSACTIONID $pp_txn_id]

	# send the TransactionSearch request
	foreach {success resp} [_send_nvp_request "GetTransactionDetails" $params] {}

	# was it successful?
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}

		return [list 0 $resp]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}
		return [list 0 $pairs]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		ob_log::write ERROR {$fn ACK not found in response}
		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	# was the request successful
	if {$RESP(ACK)!="Success" && $RESP(ACK)!="SuccessWithWarning"} {
		ob_log::write ERROR {$fn Failed. ACK: $RESP(ACK)}
		return [list 0 PAYPAL_REQUEST_FAILED]
	}

	return [list 1 $pairs]
}



#
#  ob_paypal::do_mass_pay
#
#  A Public Procedure that makes a MassPay Paypal API call. It
#  requires a list of withdrawal payment details in the following tuples
#  [Paypal email, Amount CCY]. Max tuple amount is 250 as Paypal
#  max processing amount for MassPay request is 250
#
#  ccy_code         - the currency to use in this MassPay request
#  payment_details  - Contains list of withdrawl detail tuples (mandatory)
#
#  returns - a list  of the following format ...
#                  -> [0 error_info] on any failure encountered (either on
#                       req/response stage)
#                  ->[1 response_info] on a successful request, 'response info':
#                      an Ack as it only requires a simply response
#
proc ob_paypal::do_mass_pay { ccy_code payment_details } {

	variable CFG

	set fn "ob_paypal::do_mass_pay"

	ob_log::write INFO {$fn $ccy_code}

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
	 	return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	# sanity check to ensure that list of tuple data does not exceed max allowed
	set payment_details_len [llength $payment_details]
	if {$payment_details_len > [expr {$CFG(masspay_max_pmts) * 5}]} {
		ob_log::write ERROR \
			{$fn Amount of withdrawals to be processed exceeds $CFG(masspay_max_pmts),$payment_details_len}
		return [list 0 PAYPAL_EXCEED_MAX_TXN]
	}

	set params [list \
		RECEIVERTYPE "UserID" \
		CURRENCYCODE  $ccy_code \
	]

	set n 0

	foreach {pmt_id pp_inv_num receiver_id receiver_email amount} $payment_details {
		lappend params \
			"L_AMT$n"        $amount \
			"L_RECEIVERID$n" $receiver_id \
			"L_UNIQUEID$n"   $pp_inv_num

		incr n
	}

	# send the MassPay request
	foreach {success resp} [_send_nvp_request "MassPay" $params] {}

	# was it successful?
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}

		return [list 0 $resp]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}
		return [list 0 $pairs]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		ob_log::write ERROR {$fn ACK not found in response}
		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	# was the request successful
	if {$RESP(ACK)!="Success" && $RESP(ACK)!="SuccessWithWarning"} {
		ob_log::write ERROR {$fn Failed. ACK: $RESP(ACK)}
		return [list 0 PAYPAL_REQUEST_FAILED]
	}

	# mass pay request successfully processed
	return [list 1 $pairs]

}



#
# Set PayPal express checkout
#
#    pmt_id         - id of payment setting express checkout for
#    cpm_id         - id of the payment method using
#    inv_num        - the invoice number to use for referencing payment
#    amount         - amount of payment
#    ccy_code       - the users currency
#    return_url     - the return url
#    cancel_url     - the cancel url
#    lang           - language customer is viewing the site in
#    is_quick_reg   - is it a quick registration - if so no payment associated
#    reg_id         - the id of the quick reg (if relevant)
#    hdr_color      - optional hexidecimal colour value to use in background of
#                     PayPal header
#    hdr_image      - optional image to use in background of PayPal header
#
#    returns - list
#                [1 token] if successful
#                [0 error_code] if fails
#
proc ob_paypal::set_express_checkout {
	pmt_id
	cpm_id
	inv_num
	amount
	ccy_code
	return_url
	cancel_url
	lang
	{is_quick_reg 0}
	{reg_id {}}
	{hdr_color ""}
	{hdr_image  ""}
} {

	variable CFG

	set fn "ob_paypal::set_express_checkout"

	if {[info exists CFG(locale_map,$lang)]} {
		set locale $CFG(locale_map,$lang)
	} else {
		# default to GB
		set locale "GB"
	}

	# params for SetExpressCheckout request
	set params [list \
		AMT               $amount \
		RETURNURL         $return_url \
		CANCELURL         $cancel_url \
		INVNUM            $inv_num \
		PAYMENTACTION     "Sale" \
		REQBILLINGADDRESS 1 \
		HDRBACKCOLOR      $hdr_color \
		HDRIMG            $hdr_image \
		LOCALECODE        $locale \
		CURRENCYCODE      $ccy_code \
		NOSHIPPING        1
	]

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	# send the SetExpressCheckout request
	foreach {success resp} [_send_nvp_request "SetExpressCheckout" $params] {}

	# was it successful
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 $resp]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 $pairs]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		ob_log::write ERROR {$fn ACK not found in response}

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	# was the request successful
	if {$RESP(ACK)!="Success" && $RESP(ACK)!="SuccessWithWarning"} {
		ob_log::write ERROR {$fn Failed. ACK: $RESP(ACK)}

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 PAYPAL_REQUEST_FAILED]
	}

	# do we have the PayPal token
	if {![info exists RESP(TOKEN)]} {
		ob_log::write ERROR {$fn Failed. TOKEN not found in response}

		# try to cancel the payment and remove cpm (if allowed)
		if {!$is_quick_reg} {
			_cancel_payment $pmt_id $cpm_id
		}

		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	# if not quick reg
	if {!$is_quick_reg} {
		# associate the PayPal token with the payment
		if {![ob_paypal::update_token $pmt_id $RESP(TOKEN)]} {

			# try to cancel the payment and remove cpm (if allowed)
			if {!$is_quick_reg} {
				_cancel_payment $pmt_id $cpm_id
			}

			return [list 0 PAYPAL_FAILED_TOKEN_UPD]
		}
	} else {
		# associate the PayPal token with the Quick Reg attempt
		if {![ob_paypal::update_token_quick_reg $reg_id $RESP(TOKEN)]} {

			return [list 0 PAYPAL_FAILED_TOKEN_UPD]
		}
	}

	return [list 1 $RESP(TOKEN)]
}



# Get details of a PayPal express checkout payment
#
#    token         - the token of the payment to get details for
#    ccy_code      - the currency of the payment
#
#    returns - list
#                [1 [list of name/value pairs]] if successful
#                [0 error_code] if fails
#
proc ob_paypal::get_express_checkout_details {
	token
	ccy_code
} {

	set fn "ob_paypal::get_express_checkout_details"

	# params for GetExpressCheckoutDetails request
	set params [list \
		TOKEN $token
	]

	# get the Paypal Payment Gateway Acct details based on currency.
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
		return [list 0 "PAYPAL_FAILED_PMG_RULES"]
	}

	# send the SetExpressCheckout request
	foreach {success resp} \
		[_send_nvp_request "GetExpressCheckoutDetails" $params] {}

	# was it successful
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}
		return [list 0 $resp]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}
		return [list 0 $pairs]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		ob_log::write ERROR {$fn ACK not found in response}
		return [list 0 PAYPAL_INVALID_RESPONSE]
	}

	if {$RESP(ACK)!="Success"} {
		return [list 0 PAYPAL_GET_PMT_FAILED]
	}

	return [list 1 $pairs]
}



# Cancel an Express Checkout payment
#
#    cust_id - customer identifier
#    token   - the PayPal token
#
#    returns 1 if successful, 0 if not
#
proc ob_paypal::cancel_nvp_payment { acct_id token } {

	set fn "ob_paypal::cancel_nvp_payment"

	# can't have an empty token
	if {$token == ""} {
		ob_log::write ERROR \
			{$fn Invalid token: $token}
		return 0
	}

	# grab the pmt_id for this token (also used to ensure the payment is the
	# correct status and belongs to this customer)
	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::get_pmt_by_token $acct_id $token]
	} msg]} {
		ob_log::write ERROR \
			{$fn Error executing query ob_paypal::get_pmt_by_token - $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {

		ob_db::rs_close $rs

		ob_log::write ERROR \
			{$fn Failed to find payment, acct_id: $acct_id token: $token}
		return 0
	}

	set pmt_id   [db_get_col $rs 0 pmt_id]
	set status   [db_get_col $rs 0 status]
	set cpm_id   [db_get_col $rs 0 cpm_id]

	ob_db::rs_close $rs

	# payment must be pending
	if {$status != "P"} {
		ob_log::write ERROR {$fn Cannot cancel payment. Invalid status: $status}
		return 0
	}

	return [_cancel_payment $pmt_id $cpm_id]

}



# Validate a quick reg return. Rules are:
#   1) the token must not be on an existing payment
#   2) this token must not have been validated before (to stop
#      customers reusing an old PayPal reg attempt)
#   3) the ipaddr must not have changed
#
#   token  - PayPal Express Checkout token
#   ipaddr - IP address
#
#   list -
#       success    - OK if successful, error code if not
#       linked_md5 - the random code to play in page to validate the reg
#                    when finally submitted (only if successful)
#
proc ob_paypal::validate_quick_reg_return { token ipaddr } {

	variable CFG

	set fn "ob_paypal::validate_quick_reg_return"

	set check_ip [expr {$CFG(quick_req_check_ip) == 1 ? "Y" : "N"}]

	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::validate_quick_reg_return \
			$token $ipaddr $check_ip]
	} msg]} {

		ob_log::write ERROR \
			{$fn Error executing query ob_paypal::validate_quick_reg - $msg}

		# if its a known error set correct error otherwise use a
		# generic error
		switch -glob $msg {
			*AX8200* {
				set status PAYPAL_QUICK_REG_TOKEN_NOT_FOUND
			}
			*AX8201* {
				set status PAYPAL_QUICK_REG_INVALID_IP
			}
			*AX8202* {
				set status PAYPAL_QUICK_REG_REUSE
			}
			*AX8203* {
				set status PAYPAL_QUICK_REG_HAS_PMT
			}
			default {
				set status PAYPAL_QUICK_REG_ERROR
			}
		}

		return [list $status]

	}

	set linked_md5 [db_get_coln $rs 0]
	ob_db::rs_close $rs

	return [list OK $linked_md5]

}



# Validate a quick reg reigstration
#
#   token       - PayPal Express Checkout token
#   linked_md5  - md5 linked to the token
#
# returns [list 1 reg_id] if ok, 0 if not
#
proc ob_paypal::validate_quick_reg_register { token linked_md5 } {

	set fn "ob_paypal::validate_quick_reg_register"

	# is there a quick reg token in tPayPalQuickReg with this md5 and which
	# is not currently linked to an actual payment?
	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::validate_quick_reg_register \
			$token $linked_md5 $token]
	} msg]} {

		ob_log::write ERROR \
			{$fn Error executing ob_paypal::validate_quick_reg_register - $msg}
		return [list 0]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {

		ob_db::rs_close $rs

		ob_log::write ERROR \
			{$fn Invalid rows found for token: $token, linked_md5: $linked_md5}
		return [list 0]

	} else {

		set reg_id [db_get_col $rs 0 reg_id]

		return [list 1 $reg_id]

	}

}



# do a PayPal Express Checkout payment (using NVP API)
#
#    cust_id  - customer identifier
#    token    - the PayPal token
#    payer_id - the PayPal payer id
#    ccy_code - currency code
#
#    list -
#       status - OK if successful, error code if not
#       pmt_id - the payment id (only if payment found - -1 if not)
#       amount - the payment amount (only if payment was successful)
#
proc ob_paypal::do_nvp_payment { acct_id token payer_id ccy_code } {

	variable CFG

	set fn "ob_paypal::do_nvp_payment"

	# can't have an empty token
	if {$token == ""} {
		ob_log::write ERROR \
			{$fn Invalid token: $token}
		return 0
	}

	# grab the pmt_id for this token (also used to ensure the payment is the
	# correct status and belongs to this customer)
	if {[catch {
		set rs [ob_db::exec_qry ob_paypal::get_pmt_by_token $acct_id $token]
	} msg]} {
		ob_log::write ERROR \
			{$fn Error executing query ob_paypal::get_pmt_by_token - $msg}
		return [list PAYPAL_GET_PMT_ERROR -1]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR \
			{$fn ob_paypal::get_pmt_by_token, acct_id: $acct_id token: $token, returned invalid rows}
		ob_db::rs_close $rs
		return [list PAYPAL_PMT_NOT_FOUND -1]
	}

	set pmt_id      [db_get_col $rs 0 pmt_id]
	set inv_num     [db_get_col $rs 0 pp_inv_num]
	set status      [db_get_col $rs 0 status]
	set amount      [db_get_col $rs 0 amount]
	set cpm_id      [db_get_col $rs 0 cpm_id]

	# grab the current value of payer_id, email in the db
	set db_payer_id [db_get_col $rs 0 payer_id]
	set db_email    [db_get_col $rs 0 email]

	ob_db::rs_close $rs

	# payment should be pending (pPmtUpd will prevent any race conditions with
	# bad status transitions but bail out early here if not what we expect)
	if {$status != "P"} {
		ob_log::write ERROR {$fn Cannot do payment. Invalid status: $status}
		return [list PAYPAL_PMT_INVALID_STATUS $pmt_id]
	}

	# store and validate the payer_id if we haven't set it previously
	if {$db_payer_id == ""} {

		# get paypals details of customer
		set res [ob_paypal::get_express_checkout_details $token $ccy_code]

		if {![lindex $res 0]} {
			ob_log::write ERROR {$fn Failed to GetExpressCheckoutDetails}

			# try to cancel the payment and remove cpm (if allowed)
			_cancel_payment $pmt_id $cpm_id

			return [list PAYPAL_GET_DETAILS_ERROR $pmt_id]
		}

		array set DETAILS [lindex $res 1]

		if {![info exists DETAILS(EMAIL)]} {
			ob_log::write ERROR {$fn EMAIL not found in response}

			# try to cancel the payment and remove cpm (if allowed)
			_cancel_payment $pmt_id $cpm_id

			return [list PAYPAL_INVALID_RESPONSE $pmt_id]
		}

		if {[OT_CfgGet FUNC_RESTRICT_EMAIL 0] &&
		    [ob_restrict_email::is_restricted $DETAILS(EMAIL)]} {
			ob_log::write ERROR {$fn Invalid email domain: $DETAILS(EMAIL)}

			# try to cancel the payment and remove cpm (if allowed)
			_cancel_payment $pmt_id $cpm_id

			return [list PAYPAL_INVALID_EMAIL_DOMAIN $pmt_id]
		}

		if {[catch {
			set rs [ob_db::exec_qry ob_paypal::update_payer_id \
				$acct_id $cpm_id $payer_id $DETAILS(EMAIL) $pmt_id]
		} msg]} {
			ob_log::write ERROR \
				{$fn Error executing query ob_paypal::update_payer_id - $msg}

			# try to cancel the payment and remove cpm (if allowed)
			_cancel_payment $pmt_id $cpm_id

			return [list PAYPAL_UPDATE_PAYER_ID_ERROR $pmt_id]
		}

		set is_dup [db_get_coln $rs 0]

		ob_db::rs_close $rs

		if {$is_dup} {
			ob_log::write ERROR \
				{$fn Duplicate payer id:- $payer_id}

			# try to cancel the payment, but don't remove
			_cancel_payment $pmt_id $cpm_id 0

			return [list PAYPAL_PMT_INVALID_PAYER_ID $pmt_id]
		}

	# payer_id must not change
	} elseif { $payer_id != $db_payer_id } {

		ob_log::write ERROR \
			{$fn payer_id: $payer_id does not match db payer_id: $db_payer_id}

		# try to cancel the payment and remove cpm (if allowed)
		_cancel_payment $pmt_id $cpm_id

		return [list PAYPAL_PAYER_ID_CHANGE $pmt_id]

	}

	# params for DoExpressCheckout request
	set params [list \
		AMT               $amount \
		PAYERID           $payer_id \
		TOKEN             $token \
		PAYMENTACTION     "SALE" \
		INVNUM            $inv_num \
		CURRENCYCODE      $ccy_code \
		NOTIFY_URL        $CFG(ipn_processor)
	]

	# bind up the Paypal Payment Gateway Acct details
	if {[ob_paypal::_get_pmg_params $ccy_code] != 1} {
		# Failed - bail out and let the PayPal cron tidy up the payment
		ob_log::write ERROR {$fn Failed to load payment gateway details}

		# try to cancel the payment and remove cpm (if allowed)
		_cancel_payment $pmt_id $cpm_id

	 	return [list PAYPAL_FAILED_PMG_RULES $pmt_id]
	}

	# mark payment as unknown
	set upd_pmt_res [ob_paypal::update_pmt_status $pmt_id "U"]

	if {!$upd_pmt_res} {
		# Failed
		ob_log::write ERROR \
			{$fn Cannot do payment. Failed to update status: $status}

		# try to cancel the payment and remove cpm (if allowed)
		_cancel_payment $pmt_id $cpm_id

		return [list PAYPAL_PMT_INVALID_STATUS $pmt_id]
	}

	# send the SetExpressCheckout request
	foreach {success resp} \
		[_send_nvp_request "DoExpressCheckoutPayment" $params] {}

	# was it successful?
	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to obtain valid response: $resp}

		# need to leave payment in unknown status to be processed
		# by unknown payment cron
		return [list $resp $pmt_id]
	}

	# parse the response
	foreach {success pairs} [_parse_nvp_response $resp] {}

	if {!$success} {
		ob_log::write ERROR \
			{$fn: Failed to parse response: $pairs}
		return [list $pairs $pmt_id]
	}

	array set RESP $pairs

	if {![info exists RESP(ACK)]} {
		# response doesn't contain what was expected - don't update the
		# status to cancelled as can't be sure what went wrong
		ob_log::write ERROR {$fn ACK not found in response}
		return [list PAYPAL_INVALID_RESPONSE $pmt_id]
	}

	# was the request successful
	if {$RESP(ACK)!="Success" && $RESP(ACK)!="SuccessWithWarning"} {
		ob_log::write ERROR {$fn Failed. ACK: $RESP(ACK)}

		# mark the payment as bad
    	_process_pmt_error $pmt_id $cpm_id $pairs

		return [list PAYPAL_REQUEST_FAILED $pmt_id]
	}

	# double check token
	if {![info exists RESP(TOKEN)]} {
		ob_log::write ERROR {$fn TOKEN not found in response}
		return [list PAYPAL_INVALID_RESPONSE $pmt_id]
	}

	if {$RESP(TOKEN) != $token} {
		ob_log::write ERROR {$fn Invalid token found in response}
		return [list PAYPAL_INVALID_RESPONSE $pmt_id]
	}

	# do we have the PayPal payment status
	if {![info exists RESP(PAYMENTSTATUS)]} {
		# missing parameter - let the payment cron tidy up payment
		ob_log::write ERROR {$fn Failed. PAYMENTSTATUS not found in response}
		return [list PAYPAL_INVALID_RESPONSE $pmt_id]
	}

	# successful
	if {$RESP(PAYMENTSTATUS) == "Completed"} {

		if {
			![info exists RESP(AMT)]           ||
			![info exists RESP(CURRENCYCODE)]  ||
			![info exists RESP(TRANSACTIONID)]
		} {
			ob_log::write ERROR {$fn paramenters missing from response}
			return [list PAYPAL_INVALID_RESPONSE $pmt_id]
		}

		if {$RESP(AMT) != $amount || $RESP(CURRENCYCODE) != $ccy_code} {
			ob_log::write ERROR {$fn invalid payment amount or currency}
			return [list PAYPAL_INVALID_PAYMENT_AMOUNT $pmt_id]
		}

		# all good. Mark payment as complete
		set upd_pmt_res \
			[ob_paypal::update_pmt_status $pmt_id "Y" 0 $RESP(TRANSACTIONID)]

		return [list OK $pmt_id $amount]

	} else {

		# mark payment as bad
		_process_pmt_error $pmt_id $cpm_id $pairs

		return [list PAYPAL_PAYMENT_FAILED $pmt_id]
	}

}



# -------------------------------------------------------------------------------
#  Private Procedures
# -------------------------------------------------------------------------------

#
#  ob_paypal::_get_pmg_params
#
#  Get PMG parameters for a given request. This isn't really
#  an issue at the moment but whenever Paypal uses multiple
#  business accounts for each currency this will be of use as
#  different API accounts will need to be used
#
#  ccy_code - The Paypal customers currency
#
proc ob_paypal::_get_pmg_params {ccy_code} {

	variable PMT_DATA

	# setup the ccy_code for the customer as they may get used
	# in the PMG rules tcl conditions stored in the DB
	set PMT_DATA(ccy_code) $ccy_code
	set PMT_DATA(pay_mthd) "PPAL"

	# Get the correct payment gateway details for this payment
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]

	# cater for PMG error
	if {[lindex $pg_result 0] == 0} {
		ob_log::write ERROR {ob_paypal::_get_pmg_params:PMG Rules failed,[lindex $pg_result 1]}
		return 0
	}

	# all looks good, 'PMT_DATA' has been populated with the appropriate data
	return 1
}



#
#  ob_paypal::_format_time
#
#  PayPal use Coordinated Universal Time (UTC)
#
#  seconds - the time to convert (default: empty string, which means current time)
#
#  returns - the formatted date (YYYY-DD-MMThh:mm:ss.sZ)
#
proc ob_paypal::_format_time { {seconds {}} } {
	if {$seconds == {}} {
		set seconds [clock seconds]
	}
	return [clock format $seconds -format {%Y-%m-%dT%T.00Z} -gmt 1]
}



# Cancel a PayPal payment and try to remove the payment method if possible
#
#    pmt_id     - the id of the payment to cancel
#    cpm_id     - the id of the customer payment method
#    remove_cpm - whether to attempt removal of the cpm
#
#    returns 1 if cancelled, 0 if not
#
proc ob_paypal::_cancel_payment { pmt_id cpm_id { remove_cpm 1 } } {

	set fn "ob_paypal::_cancel_payment"

	# mark payment as cancelled
	set upd_pmt_res [ob_paypal::update_pmt_status $pmt_id "X"]

	# try to remove the payment method for the customer so can register an
	# alternative method - wont get removed if there is a
	# successful/outstanding payment using that method
	if {$upd_pmt_res && $remove_cpm && [OT_CfgGet FUNC_REMOVE_CPM_ON_FAIL 1]} {
		ob_paypal::remove_cpm_on_first_payment $cpm_id
	}

	if {!$upd_pmt_res} {
		# just log error in cancelling payment
		ob_log::write ERROR \
			{$fn Failed to cancel payment: $pmt_id}
		return 0
	}

	return 1
}



# Process a nvp payment error -
#    1) marks the payment as bad
#    2) if first payment, will attempt to remove the payment method
#    3) logs out details of the errors in response and will store as much as
#       possible in the tPmtPayPal.extra_info db field for future reference
#
#    pmt_id      - the id of the payment
#    cpm_id      - id of payment method
#    response    - name value pairs received in response from PayPal
#
proc ob_paypal::_process_pmt_error { pmt_id cpm_id response } {

	set fn "ob_paypal::_process_pmt_error"

	array set RESP $response

	set extra_info ""

    set err_num   0
	set err_code  [list]
	set err_short [list]
	set err_long  [list]

	# Don't know how many errors we've got from PayPal - cycle through them
	# until can't find it
	while (1) {

		if {
			![info exists RESP(L_ERRORCODE${err_num})] ||
			![info exists RESP(L_SHORTMESSAGE${err_num})] ||
			![info exists RESP(L_LONGMESSAGE${err_num})]
		} {
			break
		}

		ob_log::write ERROR \
			{$fn err_num: $err_num - $RESP(L_ERRORCODE${err_num}),$RESP(L_SHORTMESSAGE${err_num}),$RESP(L_LONGMESSAGE${err_num})}

		lappend err_code  $RESP(L_ERRORCODE${err_num})
 		lappend err_long  $RESP(L_LONGMESSAGE${err_num})
		incr err_num
	}

	if {[llength $err_code] } {
		# make sure we store all error codes if possible
		set extra_info [join $err_code ","]
		append extra_info ": "
		append extra_info [join $err_long ","]
	} else {
		set extra_info ""
	}

	# can only store 255 chars
	set extra_info [string range $extra_info 0 255]

	# mark payment as bad
	set upd_pmt_res \
		[ob_paypal::update_pmt_status $pmt_id "N" 1 {} $extra_info]

	# try to remove payment method
	if {$upd_pmt_res && [OT_CfgGet FUNC_REMOVE_CPM_ON_FAIL 1]} {
		ob_paypal::remove_cpm_on_first_payment $cpm_id
	}
}



#
#  ob_paypal::_parse_nvp_response
#
#  Parses an nvp response obtained from a Paypal request
#
#  response  - the response sent back from Paypal
#
#  returns - a list
#               [1 [list of name value pairs in response]] if fails to parse
#               [0 error info] if fails to parse [1 response info]
#
proc ob_paypal::_parse_nvp_response {response} {

	set pair_list [list]

	set arg_list [split $response &]

	foreach arg $arg_list {

		# remove any whitespace, new line characters
		set arg [string trim $arg]

		# check validity of arg (must have exactly one ='s sign in it that is
		# not at the beginning
		if {![regexp {^([^=]+)=([^=]*)$} $arg arg name value]} {
			return [list 0 PAYPAL_INVALID_RESPONSE]
		}

		lappend pair_list $name

		# url decode the value
		lappend pair_list [urldecode $value]
	}

	return [list 1 $pair_list]

}



#
#  ob_paypal::_send_request
#
#  Send a Paypal NVP request to Paypals NVP API URL (configurable)
#
#  method  - the method to use
#  pairs   - a list of name value pairs to include in the request
#
#  returns - a list, on success : [1 paypal_response],
#                  [0  PAYPAL_REQ_ERROR] otherwise
#
proc ob_paypal::_send_nvp_request { method {pairs {}} } {

	variable PMT_DATA
	variable CFG

	set fn "ob_paypal::_send_nvp_request"

	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $PMT_DATA(host)] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn Bad Host: $msg}
		return [list 0 "PAYPAL_REQ_ERROR"]
	}

	lappend pairs \
		METHOD    $method \
		USER      $PMT_DATA(client) \
		PWD       $PMT_DATA(password) \
		VERSION   $CFG(api_version)

	if {$CFG(use_cert)} {
		set tls "-certfile $CFG(cert_file)"
	} else {
		set tls {}
		lappend pairs \
			SIGNATURE $PMT_DATA(mid)
	}

	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "POST" \
		           -form_args  $pairs \
		           $PMT_DATA(host)]
	} msg]} {
		ob_log::write ERROR {$fn Unable to build PayPal request: $msg}
		return [list 0 PAYPAL_REQ_ERROR]
	}

	# Send the request to PayPal
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $PMT_DATA(conn_timeout) \
		    -req_timeout  $PMT_DATA(conn_timeout) \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		ob_log::write ERROR \
			{$fn Unexpected error contacting PayPal: $msg}
		return [list 0 PAYPAL_REQ_ERROR]
	}

	if {$status != "OK"} {
		ob_log::write ERROR \
			{$fn Error sending request: status was $status}
		::ob_socket::clear_req $req_id
		return [list 0 PAYPAL_REQ_ERROR]
	}

	# get response
	set response [string trim [::ob_socket::req_info $req_id http_body]]
	::ob_socket::clear_req $req_id

	ob_log::write DEBUG {$fn: Response is: $response}

	return [list 1 $response]
}
