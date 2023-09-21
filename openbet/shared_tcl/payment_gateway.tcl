# $Id: payment_gateway.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
#
# Wrapper functions for the various payment mechanisms
# These functions can be used to carry out authorisations against
# the various payment gateways. The openbet payment tables will be
# updated accordingly.
#
# used by payment_CC.tcl, make_payment.tcl



# Namespace
#
namespace eval payment_gateway {



	# Procedures
	#
	namespace export pmt_gtwy_init
	namespace export pmt_gtwy_do_payment
	namespace export pmt_gtwy_xlate_err_code
	namespace export pmt_gtwy_get_active_host
	namespace export calcCommission
	namespace export getCommRules
	namespace export getJsCommRules
	namespace export is_poker_delay



	# Variables
	#
	variable PG_INITIALISED
	variable PMT_ERR_CODES
	variable PG_SHM_CACHE
	array set PMT_ERR_CODES {
		PMT_INVALID_CUST_DETAILS    {In order to make this payment you must have fully completed your personal details}
		PMT_INVALID_DETAILS         {The payment details are invalid}
		PMT_GUEST                   {The guest user cannot make payments}
		PMT_PWD                     {Password/PIN Incorrect}
		PMT_TYPE                    {Invalid Payment type}
		PMT_CARD                    {Invalid card number}
		PMT_CARD_UNKNWN             {Unknown card type}
		PMT_STRT                    {Invalid start date please enter as MM/YY}
		PMT_EXPR                    {Invalid expiry date please enter as MM/YY}
		PMT_NO_DEBIT                {This is not a debit card.  You can only use a debit card.}
		PMT_ISSUE                   {Invalid issue number}
		PMT_CCARD                   {You have no card registered against your account}
		PMT_CCY                     {Unable to retrieve currency}
		PMT_CPERM                   {This card is not allowed, please contact customer services}
		PMT_CC_BLOCKED              {This card has been blocked, please contact customer services}
		PMT_CC_LOCATION             {You are not allowed to make any payments from this location, please contact customer services}
		PMT_DECL                    {Sorry, payment declined}
		PMT_RESP                    {UNABLE TO AUTHORISE FUNDS. Payment attempt cannot be confirmed, a manual authorisation check must be completed to determine transaction status.}
		PMT_REQ_NOT_MADE            {Request did not reach payment gateway}
		PMT_CRNO                    {Invalid card number}
		PMT_CLEN                    {Invalid card number (length is incorrect)}
		PMT_SPEED                   {Speed limit hit, please wait a few minutes before trying again}
		PMT_AMNT                    {Invalid amount}
		PMT_NOFT                    {Funds transfers is disabled}
		PMT_NODEP                   {Deposit is not allowed}
		PMT_SUSP                    {Your account is locked}
		PMT_FTSY                    {Fantasy accounts cannot deposit or withdraw}
		PMT_CUST                    {Customer details not found}
		PMT_CCYLK                   {Currency is locked}
		PMT_DUPL                    {This payment has already been processed}
		PMT_WMIN                    {Withdrawal below the minimum and not equal to balance}
		PMT_WMAX                    {Withdrawal greater than the maximum allowed}
		PMT_WTIME                   {Withdrawal not allowed, you have not been an active customer for long enough to use this withdrawal method, please contact customer services}
		PMT_DMIN                    {Deposit below the minimum}
		PMT_DMAX                    {Deposit greater than the maximum allowed}
		PMT_2CRD                    {You already have a card registered}
		PMT_USED                    {This card has been used on another account}
		PMT_CARD_ACTIVE             {Card is not active on this account}
		PMT_ERR                     {There was an error carrying out the transaction}
		PMT_INVALID      			{Deposit declined due to invalid details}
		PMT_FUND                    {You do not have sufficient funds in your account}
		PMT_REFER                   {Payment Referred}
		PMT_MASTERCARD              {Sorry, MasterCard holders can only withdraw via cheque. Please email us with the amount you wish to withdraw and your username. Thank you.}
		PMT_RA                      {This card has been flagged as lost or stolen}
		PMT_B1                      {Bad Card Number}
		PMT_B2                      {Card past expiry date}
		PMT_B3                      {Card before effective date}
		PMT_C0                      {The total purchase amount was about the limit for this card}
		PMT_RX                      {We cannot accept transactions on this type of card}
		PMT_NOCARD                  {Could not find any card details for this method}
		PMT_NOCCY                   {Could not find a valid currency}
		PMT_REF                     {Invalid reference number}
		PMT_ERR_INSERT_BANK         {Could not carry out bank payment at this time}
		PMT_ERR_INSERT_CC           {Could not carry out card payment at this time}
		PMT_ERR_INSERT_CHQ          {Could not carry out cheque payment at this time}
		PMT_ERR_INSERT_CSH          {Could not carry out cash payment at this time}
		PMT_ERR_INSERT_GDEP         {Could not carry out deposit at this time}
		PMT_ERR_ID                  {Could not find record of original payment}
		PMT_ERR_NOT_REFER_PEND      {You cannot refer this payment}
		PMT_ERR_ALREADY_STL         {This payment has already been settled}
		PMT_ERR_PENDING             {You cannot mark this payment as pending}
		PMT_ERR_MTHD_WTD_PEND       {This customer's payment method has not yet been authorised for withdrawal.}
		PMT_ERR_MTHD_DEP_PEND       {This customer's payment method has not yet been authorised for deposit.}
		PMT_ERR_MTHD_BAD_DEP        {You cannot make deposits using this method}
		PMT_ERR_MTHD_BAD_WTD        {You cannot make withdrawals using this method}
		PMT_ERR_INVALID_MTHD        {You cannot perform this operation on this type of payment method}
		PMT_NOWITH                  {Withdrawal is not allowed}
		PMT_ERR_INVALID_STATUS      {Invalid status}
		PMT_ERR_INVALID_MTHD_STATUS {This payment method has an invalid status for this operation}
		PMT_ERR_NOT_UNKNOWN         {This transactions status is incorrect and cannot be updated}
		PMT_NO_SOCKET               {UNABLE TO CONNECT TO PAYMENT GATEWAY. No payment attempt has been made, please re-attempt transaction.}
		PMT_DAILY_LIMIT_WTD         {The daily limit for withdrawals has been exceeded}
		PMT_PAYBACK                 {Card does not accept withdrawal by payback. You must arrange withdrawal by cheque}
		PMT_RESP_BANK               {Your card issuer is not responding, please try later}
		PMT_NO_PAYBACK_ACC          {We require additional information about your card before we can process this withdrawal. Please contact customer services.}
		PMT_PB_PMT_2CRD             {You already have a phone number registered}
		PMT_PB_PMT_USED             {This phone number has been used on another account}
		PMT_PB_SPEED                {Speed limit hit, please wait a few minutes before trying again}
		PMT_METACHARGE_WTD_NO_DATA  {Metacharge will not process withdrawals without a previous deposit to refund against.}
		PMT_ERR_CFT_LIMIT           {Customer exceeded CFT daily maximum withdrawal limit.}
		PMT_METACHARGE_NO_REFUND    {Withdrawals cannot be processed via Metacharge}
		PMT_RG_REFUSED              {Sorry, we cannot process your transaction at the moment}
		PMT_TIMEOUT_ABANDON         {TIMED OUT WAITING FOR TRANSACTION RESPONSE. The transaction attempt will be abandoned, please re-attempt transaction.}
		PMT_3DS_OK_REDIRECT    {3D Secure verificarion required via a Redirect}
		PMT_3DS_NO_SUPPORT     {This transaction cannot benefit from 3D Secure liability protection}
		PMT_3DS_OK_DIRECT_AUTH {This transaction will benefit from 3D secure liability protection and can be submitted without customer verification via a Redirect}
		PMT_3DS_BYPASS         {3D Secure verification has been bypassed for this transaction}
		PMT_3DS_VERIFY_FAIL    {3D Secure verification has failed}
	}
	# Indicates that this file still needs to be initialised.
	set PG_INITIALISED 0

}


# ----------------------------------------------------------------------
# Initialise the payment gateway functions
# ----------------------------------------------------------------------
proc payment_gateway::pmt_gtwy_init args {

	variable PG_INITIALISED
	variable PG_SHM_CACHE

	ob_log::write INFO {PMT_GTWY: <== pmt_gtwy_init}

	# are we storing details in shared memory to share between children?
	if {[OT_CfgGet PMT_GATEWAY_USE_SHM 0] && [llength [info commands asStoreRs]]} {
		set PG_SHM_CACHE 1
	} else {
		set PG_SHM_CACHE 0
	}


	# Get the current default pg acct info
	# and the default pg host info for
	# that account type (eg DCASH/FLEXICOM)
	#
	ob_db::store_qry payment_gateway::pmt_get_default_pg_all {

		select
			a.pg_acct_id,
			a.pg_type,
			a.enc_client,
			a.enc_client_ivec,
			a.enc_password,
			a.enc_password_ivec,
			a.enc_mid,
			a.enc_mid_ivec,
			a.merchant_id,
			a.merchant_id_ivec,
			a.data_key_id,
			a.pg_version,
			a.enc_key,
			a.enc_key_ivec,
			a.desc as a_desc,
			a.method pg_method,
			h.pg_host_id,
			h.pg_ip,
			h.pg_ip_second,
			h.pg_port,
			h.resp_timeout,
			h.conn_timeout,
			a.delay_threshold,
			a.pg_3ds_enabled,
			a.policy
		from
			tPmtGateAcct a,
			tPmtGateHost h
		where a.default_acct = 'Y'
		  and a.status = 'A'
		  and a.pg_type = h.pg_type
		  and h.status = 'A'
		  and h.default = 'Y'
	} [OT_CfgGet PMT_GATEWAY_QRY_CACHE 60]

	# Get the specified pg acct info and the default pg host info for that
	# account type (eg DCASH/FLEXICOM)
	ob_db::store_qry payment_gateway::pmt_get_pg_acct_default_host {
		select
			a.pg_acct_id,
			a.pg_type,
			a.enc_client,
			a.enc_client_ivec,
			a.enc_password,
			a.enc_password_ivec,
			a.enc_mid,
			a.enc_mid_ivec,
			a.merchant_id,
			a.merchant_id_ivec,
			a.pg_version,
			a.enc_key,
			a.enc_key_ivec,
			a.data_key_id,
			a.desc as a_desc,
			a.method pg_method,
			h.pg_host_id,
			h.pg_ip,
			h.pg_ip_second,
			h.pg_port,
			h.resp_timeout,
			h.conn_timeout,
			a.delay_threshold,
			a.policy,
			a.pg_3ds_enabled
		from
			tPmtGateAcct a,
			tPmtGateHost h
		where
			a.pg_acct_id = ?
			and a.pg_type = h.pg_type
			and h.status = 'A'
			and h.default = 'Y'
	} [OT_CfgGet PMT_GATEWAY_QRY_CACHE 60]

	# Returns a list of which pmt gateway accts to use according to which (tcl
	# encoded) conditions, ordered by priority of rule
	ob_db::store_qry payment_gateway::pmt_get_pg_acct_rules {
		select
			c.pg_rule_id,
			c.cp_flag,
			c.priority,
			a.pg_3ds_enabled,
			c.condition_tcl_1,
			c.condition_tcl_2,
			c.condition_desc,
			a.pg_trans_type,
			d.pg_acct_id,
			d.pg_host_id,
			d.percentage,
			h.desc as h_desc,
			h.pg_host_id,
			h.pg_ip,
			h.pg_ip_second,
			h.pg_port,
			h.resp_timeout,
			h.conn_timeout,
			a.desc as a_desc,
			a.enc_client,
			a.enc_client_ivec,
			a.enc_password,
			a.enc_password_ivec,
			a.enc_key,
			a.enc_key_ivec,
			a.enc_mid,
			a.enc_mid_ivec,
			a.merchant_id,
			a.merchant_id_ivec,
			a.data_key_id,
			a.pg_version,
			a.pg_type,
			a.delay_threshold,
			a.policy,
			a.method pg_method,
			a2.pg_acct_id pg_sub_acct_id,
			a2.enc_client enc_sub_client,
			a2.enc_client_ivec enc_sub_client_ivec,
			a2.enc_password enc_sub_password,
			a2.enc_password_ivec enc_sub_password_ivec,
			a2.enc_key enc_sub_key,
			a2.enc_key_ivec enc_sub_key_ivec,
			a2.enc_mid enc_sub_mid,
			a2.enc_mid_ivec enc_sub_mid_ivec,
			a2.data_key_id sub_data_key_id
		from
			tPmtGateChoose c,
			tPmtRuleDest d,
			tPmtGateAcct a,
			outer tPmtGateHost h,
			outer tPmtGateAcct a2
		where c.pg_rule_id = d.pg_rule_id
		and d.pg_acct_id = a.pg_acct_id
		and d.pg_host_id = h.pg_host_id
		and d.pg_sub_acct_id = a2.pg_acct_id
		and c.status = 'A'
		order by
			3,1
	} [OT_CfgGet PMT_GATEWAY_QRY_CACHE 60]

	# Returns the combination of gateway parameters that were used when the
	# payment was sent
	ob_db::store_qry payment_gateway::pmt_get_pmt_pg_params {
		select
			cc.pmt_id,
			cc.pg_acct_id,
			h.pg_host_id,
			cc.gw_ret_code,
			cc.gw_uid,
			cc.cp_flag,
			a.pg_type,
			a.enc_client,
			a.enc_client_ivec,
			a.enc_password,
			a.enc_password_ivec,
			a.enc_mid,
			a.enc_mid_ivec,
			a.merchant_id,
			a.merchant_id_ivec,
			a.pg_version,
			a.enc_key,
			a.enc_key_ivec,
			a.data_key_id,
			a.pg_trans_type,
			a.pg_3ds_enabled,
			a.method pg_method,
			h.pg_ip,
			h.pg_ip_second,
			h.pg_port,
			h.resp_timeout,
			h.conn_timeout
		from
			tPmtCC cc,
			outer (tPmtGateAcct a, tPmtGateHost h)
		where
			cc.pg_acct_id = a.pg_acct_id
		-- We also need to send this through the exact same host.
		and cc.pg_host_id = h.pg_host_id
		and a.pg_type = h.pg_type
		and h.default = 'Y'
		and cc.pmt_id = ?
	}

	# Returns the details of a known pg_acct and host id
	ob_db::store_qry payment_gateway::pmt_get_acct_pg_params {
		select
			a.pg_acct_id,
			"" cp_flag,
			a.pg_type,
			a.enc_client,
			a.enc_client_ivec,
			a.enc_password,
			a.enc_password_ivec,
			a.enc_mid,
			a.enc_mid_ivec,
			a.merchant_id,
			a.merchant_id_ivec,
			a.pg_version,
			a.enc_key,
			a.enc_key_ivec,
			a.data_key_id,
			a.pg_trans_type,
			a.pg_3ds_enabled,
			a.method pg_method,
			h.pg_host_id,
			h.pg_ip,
			h.pg_ip_second,
			h.pg_port,
			h.resp_timeout,
			h.conn_timeout
		from
			tPmtGateAcct a,
			tPmtGateHost h
		where
			a.pg_acct_id = ? and
			h.pg_host_id = ?
	} [OT_CfgGet PMT_GATEWAY_QRY_CACHE 60]

	# Returns a list of payment gateway 'types' eg DCASH, CYBERSOURCE that could
	# be used
	ob_db::store_qry payment_gateway::pmt_get_pg_types {
		select
			distinct pg_type
		from
			tPmtGateAcct
 	} [OT_CfgGet PMT_GATEWAY_QRY_CACHE 60]

	 # returns current status of the payment
	 ob_db::store_qry payment_gateway::pmt_get_status {
	 	select
			status
		from
			tPmt
		where
			pmt_id = ?
	 }

	ob_db::store_qry payment_gateway::get_poker_delay {
		execute procedure pGetPokerDelay (
			p_pmt_id = ?,
			p_delay_time = ?
		)
	}

	## gets currency external multiplier
	ob_db::store_qry payment_gateway::pmt_get_ccy_mult {
		select
			nvl(ext_multiplier,1) as ext_multiplier,
			nvl(ext_ccy_code,ccy_code) as ext_ccy_code
		from
			tCCY
		where
			ccy_code = ?
 	}

	# Queries to find commission rules that apply to this payment common select
	# part
	set sql_sel_comm {
		select
			c.percent_charge,
			c.amt_charge,
			c.min_charge,
			c.max_charge
	}

	# Specific select part
	set sql_sel_spec {
			,
			c.amt_from,
			c.amt_to
	}

	# Common part
	set sql_comm {
		from
			tPmtComm c
		where
			c.pay_mthd  = ?
		and
			c.ccy_code  = ?
		and
			c.type      in (?,'B')
	}

	# Clauses that limit to amount range
	set sql_limit {
		and
			c.amt_from <= ?
		and (
			c.amt_to    > ?
		or
			c.amt_to is null
		)
	}

	# Pay method filter clause
	set sql_pay_mthd_filter {
		and
			c.pay_mthd_filter = ?
	}

	# Set the commission queries
	ob_db::store_qry payment_gateway::pmt_not_done_qry [subst {
		$sql_sel_comm
		$sql_comm
		$sql_limit
	}]

	ob_db::store_qry payment_gateway::pmt_not_done_filter_qry [subst {
		$sql_sel_comm
		$sql_comm
		$sql_limit
		$sql_pay_mthd_filter
	}]

	ob_db::store_qry payment_gateway::pmt_done_qry [subst {
		$sql_sel_comm
		$sql_sel_spec
		$sql_comm
	}]

	ob_db::store_qry payment_gateway::pmt_done_filter_qry [subst {
		$sql_sel_comm
		$sql_sel_spec
		$sql_comm
		$sql_pay_mthd_filter
	}]

	# Initialise each of the specific gateway types
	if {[catch {
		set rs [ob_db::exec_qry payment_gateway::pmt_get_pg_types]
	} msg]} {
		error $msg
	}

	set nrows [db_get_nrows $rs]

	if {$nrows < 1} {
		 ob_db::rs_close $rs
		 error "Could not find single default payment gateway type"
	}

	for {set i 0} {$i < $nrows} {incr i} {

		set pg_type [db_get_col $rs $i pg_type]

		switch -- $pg_type {
			MARQISA {
				if {[payment_gateway::is_gateway_used marqisa_init]} {
					marqisa::marqisa_init
				}
			}
			DCASH {
				if {[payment_gateway::is_gateway_used dcash_init]} {
					datacash::dcash_init
				}
			}
			DCASHXML {
				if {[payment_gateway::is_gateway_used ::ob::DCASH::init]} {
					ob_log::write DEBUG \
						{PMT_GTWY: Initialising XML datacash gateway}
					ob::DCASH::init
				}
			}
			RLOGIC {
				if {[payment_gateway::is_gateway_used rlogic_init]} {
					rlogic::rlogic_init
				}
			}
			CYBERSOURCE {
				if {[payment_gateway::is_gateway_used ::ICS::init]} {
					ICS::init
				}
			}
			FLEXICOM {
				if {[payment_gateway::is_gateway_used flexicom_init]} {
					Flexicom::flexicom_init
				}
			}
			PAYBOX {
				# TODO:
			}
			TMARQUE -
			TMARQUEREF {
				if {[payment_gateway::is_gateway_used ::trustmarque::trustmarque_init]} {
					trustmarque::trustmarque_init
				}
			}
			VENTMEAR {
			}
			METACHARGE {
				if {[payment_gateway::is_gateway_used ::mcharge::init]} {
					::mcharge::init
				}
			}
			WIRECARD {
				if {[payment_gateway::is_gateway_used ::ob_wirecard::init]} {
					::ob_wirecard::init
				}
			}
			BARCLAYCARD {
				if {[payment_gateway::is_gateway_used ::ob_barclaycard::init]} {
					::ob_barclaycard::init
				}
			}
			QUEST {
				if {[payment_gateway::is_gateway_used ::ob_questpmt::init]} {
					::ob_questpmt::init
				}
			}
			COMMIDEA {
				if {[payment_gateway::is_gateway_used ::ob_commidea::init]} {
					::ob_commidea::init
				}
			}
			MONEYBOOKERS {
				if {[payment_gateway::is_gateway_used ::payment_MB::init]} {
					::payment_MB::init
				}
			}
			NETELLER {
				if {[is_gateway_used ::OB_neteller::init]} {::OB_neteller::init}
			}
			CLICK2PAY {
				if {[payment_gateway::is_gateway_used ::ob_click2pay::init]} {
					::ob_click2pay::init
				}
			}
			PPAL {
				if {[payment_gateway::is_gateway_used ::ob_paypal::init]} {
					::ob_paypal::init
				}
			}
			CLICKANDBUY {
				if {[payment_gateway::is_gateway_used ::ob_clickandbuy::init]} {
					 ::ob_clickandbuy::init
				}
			}
			default {
				ob_log::write ERROR \
					{Unable to initialise payment gateway type ($pg_type)}
			}
		}
	}

	ob_db::rs_close $rs

	# get the currency limit for a cc deposit to be made without
	# cvv2 being checked
	ob_db::store_qry payment_gateway::get_cvv2_check_value {
		select
			c.cvv2_check_value
		from
			tCcy c,
			tCpmCC m,
			tAcct a
		where
			m.cpm_id = ? and
			m.cust_id = a.cust_id and
			a.ccy_code = c.ccy_code
	}

	# retrieve cvv2_length and check_flag_value using cpm_id
	ob_db::store_qry payment_gateway::get_cvv2_details {
		select
			s.cvv2_length,
			s.check_flag,
			s.first_dep_pol,
			s.flag_channels
		from
			tCpmCC c,
			tCardScheme s
		where
			c.cpm_id = ? and
			s.bin_lo = (select max(cs.bin_lo) from tCardScheme cs where cs.bin_lo <= c.card_bin) and
			s.bin_hi >= c.card_bin
	}

	# returns the number of valid deposits made given a cpm_id
	# We are just selecting 1 because we are just interested
	# in whether any rows exists
	ob_db::store_qry payment_gateway::get_deposits_made {
		select first 1
			'Y'
		from
			tPmt p
		where
			p.cpm_id = ? and
			p.payment_sort = 'D' and
			p.status = 'Y'
	}

	set PG_INITIALISED 1
	return $PG_INITIALISED
}



# Helper method used to determine whether a payment gateway interface has been
# sourced - this allows the database to contain information about gateways that
# are not being used by the current application
#
proc payment_gateway::is_gateway_used {gateway_method} {

	if {[llength [info commands $gateway_method]] > 0} {
		return 1
	} else {
		return 0
	}
}



# The payment call, this calls the appropriate payment gateway
# function depending on the payment gateway type specified in the
# supplied array.
#
# returns: 1 on success or 0 on failure
# on failure the err_list will contain suitable error_messages
#
proc payment_gateway::pmt_gtwy_do_payment {ARRAY} {

	upvar $ARRAY PMT

	# C - direct credit payment for MC (only used by Datacash XML)
	# D - deposit
	# W - withdrawal
	# X - deposit cancellation as a result of cv2avs check
	# Y - transaction confirmation (currently only used by Commidea)
	if {[lsearch [list C D W X Y] $PMT(pay_sort)] == -1} {
		return PMT_TYPE
	}

	# Set status to Pending to begin with
	set PMT(status)       P

	# Return values for the payment gateway
	set PMT(gw_ret_code)  		""

	# Used as reference number for cancelled payments
	# Also needed for confirming Commidea transactions (pay_sort - Y)
	if {[lsearch [list X Y] $PMT(pay_sort)] == -1} {
		set PMT(gw_uid)      ""
	}

	set PMT(card_type)       ""
	set PMT(gw_ret_msg)      ""
	set PMT(gw_redirect_url) ""

	# Needed by DCASH XML
	set PMT(cardname)        ""

	# Show the details of the payment
	pmt_print PMT INFO

	# If we've been asked to withdraw to a some credit cards and we're using the
	# Datacash XML gateway, we should put this through as a
	# "cardaccountpayement" instead of a withdrawal. This is also known as
	# a "Direct Credit".
	# NB - this isn't really the right place to do this check; however,
	# it's hard to see exactly where it does belong
	# - hmmm... acct-dcash-xml.tcl? - just going for a q&d change for now
	if {$PMT(pg_type) == "DCASHXML" \
		&& $PMT(pay_sort) == "W" \
		&& $PMT(pg_method) == "DC"
	} {
		set PMT(pay_sort) "C"
		set bin $PMT(card_bin)
		ob_log::write INFO \
			{PMT_GTWY: pg_method is DC. Bin: $bin. Changing pay_sort from W to C}
	}

	# Get the external multiplier for this ccy
	# This is for currencies that have such high exchange rates that we are
	# unable to store the values in the database as they are. Instead we create
	# a *mega* currency which we can multiply out at the point where the payment
	# is made.
	# Primarily this is for turkish lira which has an exchange rate so high we
	# have a multiplier of 1 million and name the currency mega lira
	if {[catch {
		set rs [ob_db::exec_qry payment_gateway::pmt_get_ccy_mult \
			$PMT(ccy_code)]
	} msg]} {
		 error "Could not get ext_mult: $msg"
	}
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		 ob_db::rs_close $rs
		 error "Could not find single ccy"
	}

	set ext_multiplier [db_get_col $rs 0 ext_multiplier]
	set ext_ccy_code   [db_get_col $rs 0 ext_ccy_code]
	ob_db::rs_close $rs

	# If we have a multiplier or an ext ccy code, then we need to transform the
	# pmt details
	if {[expr {$ext_multiplier != 1}] || $ext_ccy_code != $PMT(ccy_code)} {
		set unexpanded_amount $PMT(amount)
		set internal_ccy_code $PMT(ccy_code)

		set PMT(amount) [expr {$unexpanded_amount * $ext_multiplier}]
		set PMT(ccy_code) $ext_ccy_code

		ob_log::write INFO \
			{PMT_GTWY: Converting using ext_multiplier for ccy}
		ob_log::write INFO \
			{PMT_GTWY: $ext_ccy_code -> $internal_ccy_code}
		ob_log::write INFO \
			{PMT_GTWY: $unexpanded_amount -> $PMT(amount)}
	}

	# Should we be using 3D Secure?
	if {$PMT(pay_sort) eq "D" &&
	    $PMT(pg_3ds_enabled) eq "Y" &&
	    [info exists PMT(3d_secure)] && $PMT(3d_secure)} {
		set enable_3ds 1
	} else {
		set enable_3ds 0
	}

	# Call the appropriate payment gateway
	switch -- $PMT(pg_type) {
		MARQISA {
			set result [marqisa::make_marqisa_call PMT]
		}
		DCASH {
			set result [datacash::make_dcash_call PMT]
		}
		DCASHXML {
			set result [ob::DCASH::make_call PMT $enable_3ds]
		}
		RLOGIC {
			set result [rlogic::make_rlogic_call PMT]
		}
		CYBERSOURCE {
			set result [ICS::authorise PMT]
		}
		FLEXICOM {
			set result [Flexicom::make_flexicom_call PMT]
		}
		PAYBOX {
		}
		TMARQUE {
			# Trustmarque PayBack gateway for UK card refunds
			set result [trustmarque::make_trustmarque_call PMT]
		}
		TMARQUEREF {
			# Trustmarque PayTrust gateway for refunds onto all cards
			set result [trustmarque::make_trustmarque_call PMT 1]
		}
		VENTMEAR {
			set result [ventmear::make_ventmear_call PMT]
		}
		METACHARGE {
			set result [mcharge::make_metacharge_call PMT]
		}
		BIBIT {
			set result [bibit::authorize PMT]
		}
		WIRECARD {
			set result [ob_wirecard::make_call PMT]
		}
		BARCLAYCARD {
			set result [ob_barclaycard::authorize PMT]
		}
		QUEST {
			set result [ob_questpmt::authorize PMT]
		}
		COMMIDEA {

			if {$enable_3ds &&
			    [info exists PMT(3d_secure,policy,bypass_verify)] &&
			    $PMT(3d_secure,policy,bypass_verify) == 0} {
				# Do an enrollment check
				set PMT(req_type) "ENR"
			}

			set result [ob_commidea::make_call PMT]
		}
		SAFECHARGE {
			set result [ob_safecharge::make_call PMT $enable_3ds]
		}
		CLICK2PAY {
			set result [ob_click2pay::make_click2pay_call PMT]
		}

		default  {
			ob_log::write ERROR {*********************************************}
			ob_log::write ERROR {Payment Gateway ($PMT(pg_type)) not supported}
			ob_log::write ERROR {*********************************************}

			return "Payment Gateway ($PMT(pg_type)) not supported"
		}
	}

	return $result
}

# ----------------------------------------------------------------------
# PAYMENT GATEWAY 3D SECURE AUTH
# ----------------------------------------------------------------------
proc payment_gateway::pmt_gtwy_3ds_auth {ARRAY} {

	upvar 1 $ARRAY PMT

	if {$PMT(pay_sort) != "D" && $PMT(pay_sort) != "W"} {
		return PMT_TYPE
	}

	# Sanity check to ensure payment has not already been settled
	# (i.e. been marked as 'good/bad')
	set res [payment_gateway::chk_pmt_not_settled $PMT(pmt_id)]

	if {$res != "OK"} {
		return $res
	}

	# Set status to Pending to begin with
	set PMT(status)       P

	# Return values for the payment gateway
	set PMT(gw_ret_code)  		""
	set PMT(gw_uid)       		""
	set PMT(card_type)    		""
	set PMT(gw_ret_msg)   		""
	set PMT(gw_redirect_url)	""
	set PMT(gw_redirect_type)	""

	#
	# show the details of the payment
	#
	pmt_print PMT 3

	if {[OT_CfgGet PMT_GTWY_LOG_TIME 1]} {
		set pg_start_time [OT_MicroTime]
	}

	#
	# call the appropriate payment gateway
	#
	switch -- $PMT(pg_type) {
		DCASHXML {
			set result [ob::DCASH::make_call_3ds_auth PMT]
		}
		DCASHXMLBACS {
			set result [ob::DCASH::make_call_3ds_auth PMT]
		}
		COMMIDEA {

			# Authenticate the details
			set PMT(req_type) "PAY_AUTH"
			set result [ob_commidea::make_call PMT]

			if {$result eq "OK"} {
				# Process the payment
				set PMT(req_type) ""
				set result [ob_commidea::make_call PMT]
			}
		}
		SAFECHARGE {
			set PMT(req_type) "3DSSALE"
			set result [ob_safecharge::make_call PMT]
		}
		default  {
			OT_LogWrite 1 "*********************************************"
			OT_LogWrite 1 "Payment Gateway 3D Secure auth ($PMT(pg_type)) not supported"
			OT_LogWrite 1 "*********************************************"
		}
	}

	if {[OT_CfgGet PMT_GTWY_LOG_TIME 1]} {
		set pg_time [format "%.2f" [expr {[OT_MicroTime] - $pg_start_time}]]
		OT_LogWrite 1 "payment gateway 3D Secure Auth $PMT(pg_type) took $pg_time"
	}

	return $result
}



# Print the details of a payment request
#
proc payment_gateway::pmt_print {ARRAY {level INFO}} {

	upvar $ARRAY PMT

	ob_log::write $level {PMT_GTWY: Making payment request:}

	foreach v {apacs_ref pay_sort amount start expiry issue_no ccy_code} {
		if {[info exists PMT($v)]} {
			ob_log::write $level {PMT_GTWY: $v\t==> $PMT($v)}
		}
	}
}



# Extract the sp error code from the return message
# return the corresponding PMT error code
#
proc payment_gateway::cc_pmt_get_sp_err_code {msg {not_found_code PMT_ERR}} {

	if {![regexp {AX([0-9]+):.*$} $msg all code]} {
		return $not_found_code
	}

	switch -- $code {
		5000    {return PMT_AMNT}
		5014    {return PMT_NOFT}
		5001    {return PMT_PWD}
		5002    {return PMT_SUSP}
		5003    {return PMT_FTSY}
		5004    {return PMT_CUST}
		5005    {return PMT_SUSP}
		5006    {return PMT_FUND}
		5007    {return PMT_2CRD}
		50071   {return PMT_CC_BLOCKED}
		5008    {return PMT_USED}
		5009    {return PMT_CCY}
		5010    {return PMT_CCYLK}
		5011    {return PMT_WMIN}
		5012    {return PMT_DMIN}
		5013    {return PMT_DMAX}
		5014    {return PMT_ERR}
		5015    {return PMT_NOFT}
		5016    {return PMT_NODEP}
		5017    {return PMT_WMAX}
		5018    {return PMT_DAILY_LIMIT_WTD}
		5019    {return PMT_DAILY_LIMIT_DEP}
		5020    {return PMT_NOWITH}
		5500    {return PMT_PWD}
		5501    {return PMT_ERR}
		5502    {return PMT_ERR}
		5503    {return PMT_ERR}
		5504    -
		5505    {return PMT_FUND}
		5506    {return PMT_DUPL}
		6007    {return PMT_PB_PMT_2CRD}
		6008    {return PMT_PB_PMT_USED}
		50014   {return PMT_ERR}
		50015   {return PMT_SPEED}
		default {return $not_found_code}
	}
}



# Translates the PMT error code into the associated message
#
proc payment_gateway::pmt_gtwy_xlate_err_code {code_id} {

	variable PMT_ERR_CODES

	if {[info exists PMT_ERR_CODES($code_id)]} {
		return $PMT_ERR_CODES($code_id)
	}
	return $code_id

}



# Load the payment gateway account info from the DB.
#
# Inserts into  PG_ACCT_CHOOSE, a sequence of tcl encoded expressions to be
# evaluated in a prioritised order.
#
# The first expression to be satisfied dictates the payment gateway
# account to be used to process the payment
#
proc payment_gateway::pmt_gtwy_get_pmt_rules {} {

	global   PG_ACCT_CHOOSE
	variable PG_SHM_CACHE

	array unset PG_ACCT_CHOOSE

	if { [catch {
		set rs [ob_db::exec_qry payment_gateway::pmt_get_pg_acct_rules]
	} msg]} {
		ob_log::write ERROR {Error reading payment gateway acct rules; $msg}
		return [list 0 $msg]
	}

	set rules_nrows [db_get_nrows $rs]

	for {set i 0} {$i < $rules_nrows} {incr i} {

		set pg_acct_id      [db_get_col $rs $i pg_acct_id]
		set pg_sub_acct_id  [db_get_col $rs $i pg_sub_acct_id]
		set pg_rule_id      [db_get_col $rs $i pg_rule_id]
		set pg_host_id      [db_get_col $rs $i pg_host_id]
		set percentage      [db_get_col $rs $i percentage]
		set data_key_id     [db_get_col $rs $i data_key_id]
		set sub_data_key_id [db_get_col $rs $i sub_data_key_id]

		lappend PG_ACCT_CHOOSE(rule,$pg_rule_id)\
			[list $pg_acct_id $pg_host_id $pg_sub_acct_id $percentage]

		foreach f {pg_acct_id pg_sub_acct_id pg_rule_id pg_host_id} {
			set PG_ACCT_CHOOSE($i,$f) [set $f]
		}

		set PG_ACCT_CHOOSE($i,condition_tcl) [concat \
			[db_get_col $rs $i condition_tcl_1]      \
			[db_get_col $rs $i condition_tcl_2]      \
		]

		set data_map [list \
			A pg_3ds_enabled    pg_3ds_enabled  0\
			A pg_trans_type     pg_trans_type   0\
			A a_desc            a_desc          0\
			A pg_version        pg_version      0\
			A pg_method         pg_method       0\
			A pg_type           pg_type         0\
			A enc_client        client          1\
			A enc_password      password        1\
			A enc_key           key             1\
			A enc_mid           mid             1\
			A merchant_id       merchant_id     1\
			A delay_threshold   delay_threshold 0\
			A policy            gateway_policy  0\
			H h_desc            h_desc          0\
			H pg_ip             pg_ip           0\
			H pg_ip_second      pg_ip_second    0\
			H pg_port           pg_port         0\
			H resp_timeout      resp_timeout    0\
			H conn_timeout      conn_timeout    0\
			S enc_sub_client    sub_client      1\
			S enc_sub_password  sub_password    1\
			S enc_sub_key       sub_key         1\
			S enc_sub_mid       sub_mid         1\
			C priority          priority        0\
			C condition_desc    condition_desc  0\
			C cp_flag           cp_flag         0\
		]

		set acct_params     [list A	$data_key_id $pg_acct_id]
		set sub_acct_params [list S	$sub_data_key_id $pg_sub_acct_id]

		#  decrypt the accts
		foreach params {acct_params sub_acct_params} {

			foreach {params_type params_data_key_id params_pg_acct_id} [set $params] {
			}

			set enc_db_vals [list]
			set enc_db_cols [list]
			set enc_db_type [list]

			foreach {type col var_name enc} $data_map {
				if {$enc && $type == $params_type} {
					# Decrypt if necessary
					set val      [db_get_col $rs $i $col]
					set val_ivec [db_get_col $rs $i ${col}_ivec]

					if {$val != "" } {

						set shm_found 0

						# are we using shm caching?
						if {$PG_SHM_CACHE} {
							# do we have the value in shared memory?
							set known_type 1
							switch -- $type {
								"A"       {set shm_key_base "PG_A_${pg_acct_id}"}
								"H"       {set shm_key_base "PG_H_${pg_host_id}"}
								"S"       {set shm_key_base "PG_A_${pg_sub_acct_id}"}
								default   {set known_type 0}
							}

							if {$known_type} {
								if {![catch {set $col [asFindString ${shm_key_base}_${col}_${val}]} msg]} {
									set shm_found 1
								}
							}

							if {!$shm_found} {
								lappend enc_db_vals [list $val $val_ivec]
								lappend enc_db_cols $col
								lappend enc_db_type $type
							}
						} else {
							lappend enc_db_vals [list $val $val_ivec]
							lappend enc_db_cols $col
							lappend enc_db_type $type
						}
					} else {
						set $col {}
					}
				}
			}

			if {$enc_db_vals != "" && $params_data_key_id != ""} {
				set decrypt_rs  [card_util::batch_decrypt_db_row \
				   $enc_db_vals \
				   $params_data_key_id \
				   $params_pg_acct_id \
				   "tPmtGateAcct"]

				if {[lindex $decrypt_rs 0] == 0} {
					ob_log::write ERROR "Error decrypting payment gateway acct info; [lindex $decrypt_rs 1]"
					return [list 0 [lindex $decrypt_rs 1]]
				} else {
					set decrypted_vals [lindex $decrypt_rs 1]
				}

				set result_index 0

				foreach col $enc_db_cols {
					set dec_val [lindex $decrypted_vals $result_index]
					set $col $dec_val

					# store the value in shared memory if active
					if {$PG_SHM_CACHE} {

						set enc_val [lindex [lindex $enc_db_vals $result_index] 0]
						set enc_type [lindex $enc_db_type $result_index]

						set known_type 1
						switch -- $enc_type {
							"A"       {set shm_key_base "PG_A_${pg_acct_id}"}
							"H"       {set shm_key_base "PG_H_${pg_host_id}"}
							"S"       {set shm_key_base "PG_A_${pg_sub_acct_id}"}
							default   {set known_type 0}
						}

						if {$known_type} {
							asStoreString \
								$dec_val \
								${shm_key_base}_${col}_${enc_val} \
								[OT_CfgGet PMT_GATEWAY_SHM_CACHE_TIME 1800]
						}

					}

					incr result_index

				}
			}

		}

		foreach {type col var_name enc} $data_map {

			if {$enc} {
				set val [set $col]
			} else {
				set val [db_get_col $rs $i $col]
			}

			set PG_ACCT_CHOOSE($i,$var_name) $val

			switch -- $type {
				"A" {
					# Account Details
					set PG_ACCT_CHOOSE(acct,$pg_acct_id,$var_name) $val
				}
				"H" {
					# Host Details
					set PG_ACCT_CHOOSE(host,$pg_host_id,$var_name) $val
				}
				"S" {
					if {$pg_sub_acct_id ne ""} {
						# Sub Account Details
						# Remove the leading "sub_"
						set var_name [string range $var_name 4 end]
						set PG_ACCT_CHOOSE(acct,$pg_sub_acct_id,$var_name) $val
					}
				}
				default {
					# No reason the store rest under a separate index
				}
			}
		}
	}

	ob_db::rs_close $rs

	set PG_ACCT_CHOOSE(num_entries) $rules_nrows

	return [list 1]
}



# Choose the correct payment message parameters.
#
# This includes the physical location to send the message, the correct datacash
# client values to put in the message (Merchant ID, password etc) and the
# timeout values to use when connecting and waiting for responses
#
proc payment_gateway::pmt_gtwy_get_msg_param {ARRAY} {

	global PG_ACCT_CHOOSE

	variable PG_INITIALISED

	# Run this the first time this function is called
	if {!$PG_INITIALISED} {
		if {[catch {
			set PG_INITIALISED [pmt_gtwy_init]
		} msg]} {
			return [list 0 $msg]
		}
	}

	ob_log::write INFO {PMT_GTWY: ==> pmt_gtwy_get_msg_param}

	set rules_result [pmt_gtwy_get_pmt_rules]

	if {[lindex $rules_result 0] == 0} {
		# error return
		return [list 0 [lindex $rules_result 1]]
	}

	upvar $ARRAY PMT

	#
	# These are the variables which may be used in the TCL expresssions stored
	# in the DB. PMT values now have defaults as it was previously too CC
	# specific.
	#
	foreach {pmg_val pmg_val_dflt} [list\
		acct_type     {}\
		card_type     {}\
		source        {}\
		ccy_code      {}\
		pay_sort      {}\
		admin         {}\
		country       {}\
		type          {}\
		amount        0.00\
		bank          {}\
		card_bin      {}\
		pay_mthd      {}\
		card_scheme   {}\
		reg_source    {I}] {

		if {![info exists PMT(${pmg_val})]} {
			set PMT($pmg_val) $pmg_val_dflt
		}

		# Also since payment variables can be referenced in the payment
		# gateway rules, ensure that those variables map to it's
		# equivalent value in the 'PMT' array.
		set $pmg_val $PMT($pmg_val)
	}

	# First we evaluate the rules stored in the database to see if the payment
	# satisfies any of the conditions.  Each condition must at least specifiy a
	# pg_acct_id, but may also specify a pg_host_id and cp_flag.
	set PMT(pg_acct_id)      ""
	set PMT(pg_host_id)      ""
	set PMT(cp_flag)         ""
	set PMT(pg_trans_type)   ""
	set PMT(pg_3ds_enabled)	 ""
	set PMT(pg_sub_acct_id)  ""
	set PMT(pg_sub_client)   ""
	set PMT(pg_sub_password) ""
	set PMT(pg_sub_mid)      ""
	set PMT(pg_sub_key)      ""


	OT_LogWrite 1 " USE_DCASH_XML=[OT_CfgGet USE_DCASH_XML 0] POKER_DELAY_WTD_ERP=[OT_CfgGet POKER_DELAY_WTD_ERP 0]"

	if {$PMT(pay_sort) == "W" && [OT_CfgGet USE_DCASH_XML 0] == 1 && [OT_CfgGet POKER_DELAY_WTD_ERP 0] == 1} {
		if {[is_poker_delay $PMT(pmt_id)]} {
			set PMT(poker_delay) "Y"
		}

	}

	for { set i 0} { $i < $PG_ACCT_CHOOSE(num_entries)} { incr i} {

		set tcl_pg_acct_rule $PG_ACCT_CHOOSE($i,condition_tcl)

		if {[catch {
			set satisfied [eval $tcl_pg_acct_rule]
		} msg]} {
			ob_log::write ERROR {PMT_GTWY: Rule failed to eval : $msg}
			return [list 0 $msg]
		}

		if {$satisfied} {
			set priority $PG_ACCT_CHOOSE($i,priority)
			ob_log::write INFO \
				{PMT_GTWY Payment Condition $PG_ACCT_CHOOSE($i,priority) satisfied}
			set PMT(pg_rule_id)     $PG_ACCT_CHOOSE($i,pg_rule_id)
			set PMT(pg_trans_type)  $PG_ACCT_CHOOSE($i,pg_trans_type)
			set PMT(cp_flag)        $PG_ACCT_CHOOSE($i,cp_flag)

			if {$PMT(cp_flag) == ""} {
				set PMT(cp_flag) [OT_CfgGet DEFAULT_PMT_CP_FLAG "I"]
			}

			pmt_gtwy_get_pmt_rule_destination PMT
			break
		}
	}

	if {$PMT(pg_acct_id) ne ""} {

		set pg_acct_id $PMT(pg_acct_id)

		foreach f {
			client
			password
			mid
			key
			pg_version
			pg_method
			pg_type
			pg_3ds_enabled
			delay_threshold
			gateway_policy
		} {
			set PMT($f) $PG_ACCT_CHOOSE(acct,$pg_acct_id,$f)
		}
	}

	if {$PMT(pg_host_id) ne ""} {

		set pg_host_id $PMT(pg_host_id)

		foreach {f var_name} {
			pg_ip        host
			pg_ip_second host_second
			pg_port      port
			resp_timeout resp_timeout
			conn_timeout conn_timeout
		} {
			set PMT($var_name) $PG_ACCT_CHOOSE(host,$pg_host_id,$f)
		}
	}

	if {$PMT(pg_sub_acct_id) ne ""} {

		set pg_sub_acct_id $PMT(pg_sub_acct_id)

		foreach f {
			client
			password
			mid
			key
		} {
			set PMT(sub_$f) $PG_ACCT_CHOOSE(acct,$pg_sub_acct_id,$f)
		}
	}

	if {$PMT(pg_acct_id) != "" && $PMT(pg_host_id) != ""} {
		# We already have all the details
		return 1
	}

	# The rules either didn't match an account or host.  We will have
	# to use the default values

	if {$PMT(pg_acct_id) == "" && $PMT(pg_host_id) == ""} {

		# 1. None of the rules evaluated to true.  Use the default pg acct
		# and the default pg host for that type (eg DCASH/FLEXICOM etc)
		set pg_acct_qry "pmt_get_default_pg_all"
		set qry_param   ""
	} elseif {$PMT(pg_acct_id) != "" && $PMT(pg_host_id) == ""} {

		# 2. One of the rules has specified a pg account, but no host.
		# Use the default pg host for that account type.
		set pg_acct_qry "pmt_get_pg_acct_default_host"
		set qry_param   "$PMT(pg_acct_id)"

	} else {

		# Can't specify a host and not an acct.
		ob_log::write ERROR \
			{PMT_GTWY: Payment condition did not specify an account}
	}

	if {[catch {
		set rs [eval ob_db::exec_qry payment_gateway::$pg_acct_qry $qry_param]
	} msg]} {
		ob_log::write ERROR \
			{PMT_GTWY: Error reading current payment gateway parameters; $msg}
		return [list 0 $msg]
	}

	if {[db_get_nrows $rs] == 0} {
		ob_log::write ERROR \
			{PMT_GTWY: Could not find gateway account for $pg_acct_qry}
		ob_log::write ERROR \
			{PMT_GTWY:	with parameters: $qry_param}
		ob_db::rs_close $rs
		return [list 0 "Could not find payment gateway account"]
	} elseif {[db_get_nrows $rs] > 1} {
		ob_log::write ERROR \
			"PMT_GTWY: More than one gateway returned - pg_acct_qry = $pg_acct_qry, qry_param = $qry_param"
		ob_db::rs_close $rs
		return [list 0 "More than one gateway returned"]
	}

	# Required values for decryption
	set enc_db_vals [list]
	foreach {col ivec} {
		enc_client   enc_client_ivec
		enc_password enc_password_ivec
		enc_key      enc_key_ivec
		enc_mid      enc_mid_ivec
		merchant_id  merchant_id_ivec
	} {
		lappend enc_db_vals [list\
			[db_get_col $rs 0 $col] [db_get_col $rs 0 $ivec]]
	}

	set pg_acct_id  [db_get_col $rs 0 pg_acct_id]
	set data_key_id [db_get_col $rs 0 data_key_id]

	set decrypt_rs  [card_util::batch_decrypt_db_row $enc_db_vals \
	                                                 $data_key_id \
	                                                 $pg_acct_id \
	                                                 "tPmtGateAcct"]

	if {[lindex $decrypt_rs 0] == 0} {
		ob_log::write ERROR "Error decrypting payment gateway acct info; [lindex $decrypt_rs 1]"
		return [list 0 [lindex $decrypt_rs 1]]
	} else {
		set decrypted_vals [lindex $decrypt_rs 1]
	}

	set PMT(client)      [lindex $decrypted_vals 0]
	set PMT(password)    [lindex $decrypted_vals 1]
	set PMT(key)         [lindex $decrypted_vals 2]
	set PMT(mid)         [lindex $decrypted_vals 3]
	set PMT(merchant_id) [lindex $decrypted_vals 4]

	# Required values for decryption
	set data_key_id [db_get_col $rs 0 data_key_id]

	set PMT(pg_acct_id)      [db_get_col $rs 0 pg_acct_id]
	set PMT(pg_version)      [db_get_col $rs 0 pg_version]
	set PMT(pg_method)       [db_get_col $rs 0 pg_method]
	set PMT(pg_type)         [db_get_col $rs 0 pg_type]
	set PMT(pg_host_id)      [db_get_col $rs 0 pg_host_id]
	set PMT(host)            [db_get_col $rs 0 pg_ip]
	set PMT(host_second)     [db_get_col $rs 0 pg_ip_second]
	set PMT(port)            [db_get_col $rs 0 pg_port]
	set PMT(resp_timeout)    [db_get_col $rs 0 resp_timeout]
	set PMT(conn_timeout)    [db_get_col $rs 0 conn_timeout]
	set PMT(delay_threshold) [db_get_col $rs 0 delay_threshold]
	set PMT(gateway_policy)  [db_get_col $rs 0 policy]
	set PMT(pg_3ds_enabled)  [db_get_col $rs 0 pg_3ds_enabled]

	ob_db::rs_close $rs

	# Finally if no cp_flag has been specified by the conditions, use the
	# default (which can be a config setting).
	#
	if {$PMT(cp_flag) == ""} {
		set PMT(cp_flag) [OT_CfgGet DEFAULT_PMT_CP_FLAG "I"]
	}

	return [list 1]
}



proc payment_gateway::is_poker_delay {pmt_id} {


	# Check poker wtd delay, and change the payment sort to E (erp)
	# if they have played poker recently
	if [catch {set rs [ob_db::exec_qry get_poker_delay $pmt_id [OT_CfgGet POKER_WTD_DELAY_PROCESS_TIME 0]]} msg] {
		ob::log::write ERROR "ERROR get_poker_delay: $msg"
	}

	set nrows [db_get_nrows $rs]
	set delay [db_get_coln $rs 0 0]
	db_close $rs

	return $delay

}

# Generate a random number between 0 and 100
# Select the rule destination whose percentile covers the random number
#
proc payment_gateway::pmt_gtwy_get_pmt_rule_destination {ARRAY} {

	global PG_ACCT_CHOOSE

	upvar $ARRAY PMT

	ob_log::write INFO {PMT_GTWY: ==> pmt_gtwy_get_pmt_rule_destination rule =$PMT(pg_rule_id) }

	set random_num [expr {int(rand() * 100)}]

	set pg_rule_id $PMT(pg_rule_id)

	set min_percent  0

	foreach dest $PG_ACCT_CHOOSE(rule,$pg_rule_id) {
		set pg_acct_id     [lindex $dest 0]
		set pg_host_id     [lindex $dest 1]
		set pg_sub_acct_id [lindex $dest 2]
		set percentage     [lindex $dest 3]

		set max_percent [expr {$min_percent + $percentage}]
		if {($random_num >= $min_percent) && ($random_num < $max_percent)} {
			set PMT(pg_acct_id)     $pg_acct_id
			set PMT(pg_host_id)     $pg_host_id
			set PMT(pg_sub_acct_id) $pg_sub_acct_id
			return
		}
		set min_percent $max_percent
	}
}



# Load the array with the same payment gateway merchant acct parameters
# that were used when processing the payment with the supplied pmt_id,
# and the current default pmt gate host parameters
#
# This should be used when sending auth codes for previous payments,
# which should be made to the same IP and using the same set of
# merchant IDs etc
#
proc payment_gateway::pmt_gtwy_get_pmt_pg_params {ARRAY pmt_id {pg_acct_id {}} {pg_host_id {}}} {

	global PG_ACCT_CHOOSE

	variable PG_INITIALISED

	# Run this the first time this function is called
	if {!$PG_INITIALISED} {
		set PG_INITIALISED [pmt_gtwy_init]
	}

	upvar $ARRAY PMT

	if {$pg_acct_id != "" && $pg_host_id != ""} {
		set qry    payment_gateway::pmt_get_acct_pg_params
		set params [list $pg_acct_id $pg_host_id]
	} else {
		set qry    payment_gateway::pmt_get_pmt_pg_params
		set params $pmt_id
	}

	if {[catch {
		set rs [eval ob_db::exec_qry $qry $params]
	} msg]} {
		ob_log::write ERROR \
			{PMT_GTWY: Error in payment gateway params for ID $pmt_id; $msg}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		ob_log::write ERROR \
			{PMT_GTWY: Couldn't find payment for ID: $pmt_id ($nrows returned)}
		return [list 0 "Could not find original payment"]
	}

	# Required values for decryption
	set enc_db_vals [list]
	foreach {col ivec} {
		enc_client   enc_client_ivec
		enc_password enc_password_ivec
		enc_key      enc_key_ivec
		enc_mid      enc_mid_ivec
		merchant_id  merchant_id_ivec
	} {
		lappend enc_db_vals [list\
			[db_get_col $rs 0 $col] [db_get_col $rs 0 $ivec]]
	}

	set data_key_id [db_get_col $rs 0 data_key_id]
	set pg_acct_id  [db_get_col $rs 0 pg_acct_id]

	set decrypt_rs  [card_util::batch_decrypt_db_row $enc_db_vals \
	                                                 $data_key_id \
	                                                 $pg_acct_id \
	                                                 "tPmtGateAcct"]

	if {[lindex $decrypt_rs 0] == 0} {
		ob_log::write ERROR "Error decrypting payment gateway acct info; [lindex $decrypt_rs 1]"
		return [list 0 [lindex $decrypt_rs 1]]
	} else {
		set decrypted_vals [lindex $decrypt_rs 1]
	}

	set PMT(client)      [lindex $decrypted_vals 0]
	set PMT(password)    [lindex $decrypted_vals 1]
	set PMT(key)         [lindex $decrypted_vals 2]
	set PMT(mid)         [lindex $decrypted_vals 3]
	set PMT(merchant_id) [lindex $decrypted_vals 4]

	set PMT(pg_type)      [db_get_col $rs 0 pg_type]
	set PMT(pg_acct_id)   [db_get_col $rs 0 pg_acct_id]
	set PMT(pg_host_id)   [db_get_col $rs 0 pg_host_id]
	set PMT(pg_type)      [db_get_col $rs 0 pg_type]
	set PMT(pg_trans_type) [db_get_col $rs 0 pg_trans_type]
	set PMT(version)      [db_get_col $rs 0 pg_version]
	set PMT(pg_method)    [db_get_col $rs 0 pg_method]
	set PMT(cp_flag)      [db_get_col $rs 0 cp_flag]
	set PMT(host)         [db_get_col $rs 0 pg_ip]
	set PMT(host_second)  [db_get_col $rs 0 pg_ip_second]
	set PMT(port)         [db_get_col $rs 0 pg_port]
	set PMT(resp_timeout) [db_get_col $rs 0 resp_timeout]
	set PMT(conn_timeout) [db_get_col $rs 0 conn_timeout]
	set PMT(pg_3ds_enabled)     [db_get_col $rs 0 pg_3ds_enabled]

	if {$qry == "payment_gateway::pmt_get_pmt_pg_params"} {
		set PMT(gw_ret_code_ref) [db_get_col $rs 0 gw_ret_code]
		set PMT(gw_uid_ref)      [db_get_col $rs 0 gw_uid]
	}

	ob_db::rs_close $rs

	# If there was no payment gateway into recorded against the payment
	# it means the payment was sent before pPmtInsCC started recording
	# this info against payments.
	#
	# We'll log everything and throw an error

	if {$PMT(pg_acct_id) == ""} {

		ob_log::write ERROR \
			{PMT_GTWY: **WARNING: No PG details recorded against ID: $pmt_id}
		return [list 0 "Payment Gateway params not recorded for this payment"]
	}

	return [list 1]
}



proc payment_gateway::socket_timeout {host port timeout} {
	variable connected

	set connected ""
	set id [after $timeout {set payment_gateway::connected "TIMED_OUT"}]

	set sock [socket -async $host $port]

	fileevent $sock w {set payment_gateway::connected "OK"}
	vwait payment_gateway::connected

	after cancel $id
	fileevent $sock w {}

	if {$connected == "TIMED_OUT"} {
		catch {
			close $sock
		}
		error "Connection attempt timed out after $timeout ms"

	} else {
		fconfigure $sock -blocking 0
		if [catch {gets $sock a}] {
			close $sock
			error "Connection failed"
		}
		fconfigure $sock -blocking 1 -buffering line
	}

	return $sock
}



#-------------------------------------------------------
# Decrypts payment gateway parameters stored in
# database
#
# Currently takes in a list of encrypted values and decrypts each
# separately with card_util::card_decrypt
# primary_key for the row in question is also passed in to handle the
# event that we encounter corrupted data, in which case we store
# this fact in tabname.enc_status/enc_date
#-------------------------------------------------------
proc payment_gateway::pmt_gtwy_decrypt {values data_key_id primary_key {tabname "tPmtGateAcct"}} {

	set enc_data      [list]
	set empty_indexes [list]
	set decrypted     [list]

	for {set i 0} {$i < [llength $values]} {incr i} {
		set val [lindex $values $i]
		set enc_val [lindex $val 0]

		if {$enc_val != ""} {
			set ivec    [lindex $val 1]
			lappend enc_data [list $enc_val $ivec $data_key_id]
		} else {
			# Some values in tPmtGateAcct are empty, and decrypting these will fail,
			# so remove them from the list of things to process, we'll then need to
			# put the empty strings back in the return list later in the correct place
			lappend empty_indexes $i
		}
	}

	set dec_rs [card_util::card_decrypt_batch $enc_data]

	if {[lindex $dec_rs 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db
		if {[lindex $dec_rs 1] == "CORRUPT_DATA"} {
			card_util::update_data_enc_status $tabname $primary_key [lindex $dec_rs 2]
		}
		return $dec_rs
	} else {
		# Payment gateway values are encrypted using the old method of moving
		# the first 8 characters to the end pre-encryption, so need to put it
		# all back
		foreach dec_val [lindex $dec_rs 1] {
			lappend decrypted $dec_val
		}
	}

	# We may have some empty elements to put back in our decrypted values list...
	foreach idx $empty_indexes {
		set decrypted [linsert $decrypted $idx ""]
	}

	return [list 1 $decrypted]
}



# Gets the commission rules from the db
#
#	pay_mthd        - payment method
#	                  CC = credit/debit card
#	pay_mthd_filter - allows a single pay method to be split
#	                  C = credit card
#	                  D = debit card
#	ccy_code        - currency of the payment
#	pay_type        - payment type
#	                  D = deposit
#	                  W = withdrawal
#	returns a list where each element is a list representing a rule, each rule
#	is a list {amt_from amt_to percent_charge amt_charge min_charge max_charge}
#	and blank inner list elements are represented by the string 'null'
#
proc payment_gateway::getCommRules {pay_mthd pay_mthd_filter ccy_code pay_type} {

	# convert args to upper case for comparisons
	set pay_mthd        [string toupper $pay_mthd]
	set pay_mthd_filter [string toupper $pay_mthd_filter]
	set ccy_code        [string toupper $ccy_code]
	set pay_type        [string toupper $pay_type]

	ob::log::write DEBUG {getCommRules called with:\
						  pay_mthd = $pay_mthd,\
						  pay_mthd_filter = $pay_mthd_filter,\
						  ccy_code = $ccy_code,\
						  pay_type = $pay_type}

	if {$pay_mthd == {CC}} {
		# if pay_mthd_filter empty then assume credit card
		if {$pay_mthd_filter == {}} {
			set pay_mthd_filter C
			ob_log::write ERROR \
				{No pay method filter, assume credit card in getCommRules}
		}

		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_done_filter_qry \
				$pay_mthd \
				$ccy_code \
				$pay_type \
				$pay_mthd_filter]
			} msg]} {

			ob_log::write ERROR {pmt_done_filter_qry failed: $msg}
			error {pmt_done_filter_qry failed in getCommRules}
			return [list]
		}
	} else {
		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_done_qry \
				$pay_mthd \
				$ccy_code \
				$pay_type]
		} msg]} {

			ob_log::write ERROR {pmt_done_qry failed: $msg}
			error {pmt_done_qry failed in getCommRules}
			return [list]
		}
	}

	# Get num rows returned
	set num_rows [db_get_nrows $rs]

	if {$num_rows == 0} {
		return [list]
	} else {
		set rules [list]
	}

	# Add each rule to the result list
	for {set i 0} {$i < $num_rows} {incr i} {

		# Use format to ensure numbers are to 2 decimal places for consistency
		set percent_charge [format %.2f [db_get_col $rs $i percent_charge]]
		set amt_charge     [format %.2f [db_get_col $rs $i amt_charge]]
		set min_charge     [format %.2f [db_get_col $rs $i min_charge]]
		set amt_from       [format %.2f [db_get_col $rs $i amt_from]]
		set amt_to         [db_get_col $rs $i amt_to]
		set max_charge     [db_get_col $rs $i max_charge]

		# amt_to and max_charge can be null
		if {$amt_to == {}} {
			set amt_to null
		} else {
			set amt_to [format %.2f $amt_to]
		}
		if {$max_charge == {}} {
			set max_charge null
		} else {
			set max_charge [format %.2f $max_charge]
		}

		# Add the rule to the list
		lappend rules [list \
			$amt_from \
			$amt_to \
			$percent_charge \
			$amt_charge \
			$min_charge \
			$max_charge]
	}

	# Return the rules list
	return $rules
}



# Gets the payment commission rules as a javascript array initialization string
#	pay_type   - D (deposit)     or W (withdrawal)
#	pay_filter - C (credit card) or D (debit card)
#
proc payment_gateway::getJsCommRules {pay_type pay_method ccy_code {pay_filter {}}} {

	# Config item to turn on payment commissions
	# We need to determine the rules that javascript will use to obtain
	# commission confirmation from the customer
	set str_pay_type [string toupper [string index $pay_type 0]]
	if {[OT_CfgGet CHARGE_COMMISSION 0]} {

		# Determine the commission rules
		# A string that initializes a javascript array where each element is an
		# array representing a rule
		# Each rule is of the form:
		#	[amt_from, amt_to, percent_charge, amt_charge, min_charge, max_charge]
		#
		set comm_rules_list [getCommRules \
			$pay_method \
			$pay_filter \
			$ccy_code \
			$str_pay_type]

		set comm_rules [getJsArray $comm_rules_list]

	} else {
		set comm_rules null
	}
	return $comm_rules
}



# Converts from a tcl list of lists to a string that initialises a JavaScript
# array
# Requires each inner list to contain at least 1 element
# Blank inner list elements should be represented by the string 'null'
#
proc payment_gateway::getJsArray {tcl_list} {
	# If list is empty
	if {[llength $tcl_list] == 0} {
		return null
	} else {
		set js_arr {[}

		# Add each rule to the result string
		foreach inner_list $tcl_list {
			append js_arr {[}

			foreach inner_list_el $inner_list {
				append js_arr $inner_list_el ,
			}

			# Trim the trailing comma
			set    js_arr [string trimright $js_arr ,]
			# Add the closing ] and ,
			append js_arr {],}
		}

		# trim the trailing comma
		set    js_arr [string trimright $js_arr ,]
		# add the final ]
		append js_arr {]}

		# return the rules string
		return $js_arr
	}
}



# Calculates commission by checking rules in db
#
#	pay_mthd        - payment method
#	                  CC = credit/debit card
#	pay_mthd_filter - allows a single pay method to be split
#	                  C = credit card
#	                  D = debit card
#	ccy_code        - currency of the payment
#	pay_type        - payment type
#	                  D = deposit
#	                  W = withdrawal
#	amount          - amount by which account balance should change if
#	                  is_pmt_done is false; amount that has already gone through
#	                  the gateway otherwise
#	is_pmt_done     - (optional) if true then the money has already been paid
#	                  so calculate commission for each rule before working out
#	                  whether the rule's range applies
#
#	returns a 3 element list containing commission, payment amount & tPmt amount
#		commission     - amount of commission the customer will pay on this
#		                 payment
#		payment amount - amount to go through the payment gateway
#		                 (amount + commission) for deposits
#		                 (amount - commission) for withdrawals
#		tPmt amount    - amount to be inserted into tPmt
#	                     same as amount for deposits
#		                 (amount - commission) for withdrawals
#
proc payment_gateway::calcCommission {
	pay_mthd
	pay_mthd_filter
	ccy_code
	pay_type
	amount
	{is_pmt_done 0}
} {

	# Convert args to upper case for comparisons
	set pay_mthd        [string toupper $pay_mthd]
	set pay_mthd_filter [string toupper $pay_mthd_filter]
	set ccy_code        [string toupper $ccy_code]
	set pay_type        [string toupper $pay_type]

	# If payment is done then amount has already gone through the gateway so we
	# calc commission for each rule before working out whether the rule's range
	# applies
	if {$is_pmt_done} {
		set comm_list [calcCommissionPmtDone \
			$pay_mthd \
			$pay_mthd_filter \
			$ccy_code \
			$pay_type \
			$amount]

	# Else payment is not done so we only check commission rules with ranges
	# that include the specified amount
	} else {
		set comm_list [calcCommissionPmtNotDone \
			$pay_mthd \
			$pay_mthd_filter \
			$ccy_code \
			$pay_type \
			$amount]
	}

	# Log commission details if it has been charged
	if {[lindex $comm_list 0] > 0} {
		ob_log::write INFO \
			{PMT_GTWY: calcCommission - commission applies:}
		ob_log::write INFO \
			{PMT_GTWY:	Pay method: $pay_mthd}
		ob_log::write INFO \
			{PMT_GTWY:	Pay method filter: $pay_mthd_filter}
		ob_log::write INFO \
			{PMT_GTWY:	Ccy: $ccy_code}
		ob_log::write INFO \
			{PMT_GTWY:	Payment type: $pay_type}
		ob_log::write INFO \
			{PMT_GTWY:	Commission, pay_amount, tPmt_amount: $comm_list}
	}

	return $comm_list
}



# Calculates commission by checking rules in db when payment is done amount has
# already gone through the gateway so we calc each commission before working out
# whether the rule's range applies
#
#	pay_mthd        - payment method
#	                  CC = credit/debit card
#	pay_mthd_filter - allows a single pay method to be split
#	                  C = credit card
#	                  D = debit card
#	ccy_code        - currency of the payment
#	pay_type        - payment type
#	                  D = deposit
#	                  W = withdrawal
#	amount          - amount that has already gone through the gateway
#
#	returns a 3 element list containing commission, payment amount & tPmt amount
#		commission     - amount of commission the customer will pay on this
#	                     payment
#		payment amount - amount that has gone through the payment gateway
#		                 (amount + commission) for deposits
#		                 (amount - commission) for withdrawals
#		tPmt amount    - amount to be inserted into tPmt
#		                 same as amount for deposits
#		                 (amount - commission) for withdrawals
#
proc payment_gateway::calcCommissionPmtDone {
	pay_mthd
	pay_mthd_filter
	ccy_code
	pay_type
	amount
} {

	if {$pay_mthd == {CC}} {
		# if pay_mthd_filter empty then assume credit card
		if {$pay_mthd_filter == {}} {
			set pay_mthd_filter C
			ob_log::write ERROR \
				{PMT_GTWY: No filter, assume card in calcCommissionPmtDone}
		}

		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_done_filter_qry \
				$pay_mthd \
				$ccy_code \
				$pay_type \
				$pay_mthd_filter]
		} msg]} {
			ob_log::write ERROR {PMT_GTWY: pmt_done_filter_qry failed: $msg}
			error {pmt_done_filter_qry failed in proc calcCommissionPmtDone}
			return [list 0 $amount $amount]
		}
	} else {
		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_done_qry \
				$pay_mthd \
				$ccy_code \
				$pay_type]
		} msg]} {

			ob_log::write ERROR {pmt_done_qry failed: $msg}
			error {pmt_done_qry failed in proc calcCommissionPmtDone}
			return [list 0 $amount $amount]
		}
	}

	# Initialise the max commission found
	set max_comm_found 0

	# Get num rows returned
	set num_rows [db_get_nrows $rs]

	# For each rule calculate the commission and payment amount (checking the
	# min and max)
	for {set i 0} {$i < $num_rows} {incr i} {

		# Use format to ensure numbers are decimals for division in calculations
		set percent_charge [db_get_col $rs $i percent_charge]
		set amt_charge     [db_get_col $rs $i amt_charge]
		set min_charge     [db_get_col $rs $i min_charge]
		set max_charge     [db_get_col $rs $i max_charge]
		set amt_from       [db_get_col $rs $i amt_from]
		set amt_to         [db_get_col $rs $i amt_to]

		# Calculate commission
		set comm [getComm $pay_type $amount $percent_charge $amt_charge true]

		# Calculate the balance change amount
		set bal_change_amt [getBalChangeAmt $pay_type $amount $comm]

		# Check amount range to determine whether the rule applies
		if {$bal_change_amt >= $amt_from} {
			if {$amt_to == {} || $bal_change_amt < $amt_to} {

				# If commission amount is not 0 ensure it is in the min-max
				# charge range
				if {$comm > 0} {
					if {$comm < $min_charge} {
						set comm $min_charge
					} elseif {$max_charge != {} && $comm > $max_charge} {
						set comm $max_charge
					}
				}

				# Compare the commission to the current maximum
				if {$comm > $max_comm_found} {
					set max_comm_found $comm
				}
			}
		}
	}

	ob_db::rs_close $rs

	# Calculate the balance change amount
	set bal_change_amt [getBalChangeAmt $pay_type $amount $max_comm_found]

	# Calculate payment amount - amount to go through the payment gateway
	set payment_amt $amount

	# Calculate tPmt amount - amount to be inserted into tPmt
	# it is amount for deposits but (amount - commission) for withdrawals
	set tPmt_amount [get_tPmtAmt $pay_type $bal_change_amt $max_comm_found]

	# Return the commission, payment amount and tPmt amount
	return [list $max_comm_found $payment_amt $tPmt_amount]
}



# Calculates commission by checking rules in db when payment is not done
# we only check commission rules with ranges that include the specified amount
#
#	pay_mthd        - payment method
#	                  CC = credit/debit card
#	pay_mthd_filter - allows a single pay method to be split
#	                  C = credit card
#	                  D = debit card
#	ccy_code        - currency of the payment
#	pay_type        - payment type
#	                  D = deposit
#	                  W = withdrawal
#	amount          - amount by which account balance should change
#
# 	returns	a 3 element list containing commission, payment amount & tPmt amount
#	commission      - amount of commission the customer will pay on this payment
#	payment amount  - amount that has gone through the payment gateway
#	                  (amount + commission) for deposits
#	                  (amount - commission) for withdrawals
#	tPmt amount     - amount to be inserted into tPmt
#	                  same as amount for deposits
#	                  (amount - commission) for withdrawals
#
proc payment_gateway::calcCommissionPmtNotDone {
	pay_mthd
	pay_mthd_filter
	ccy_code
	pay_type
	amount
} {

	# Find rules that apply to this payment
	# Run the query
	if {$pay_mthd == {CC}} {
		# if pay_mthd_filter empty then assume credit card
		if {$pay_mthd_filter == {}} {
			set pay_mthd_filter C
			ob_log::write ERROR \
				{PMT_GTWY: No filter, assume card in calcCommissionPmtNotDone}
		}

		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_not_done_filter_qry \
				$pay_mthd \
				$ccy_code\
				$pay_type \
				$amount \
				$amount \
				$pay_mthd_filter]
		} msg]} {

			ob_log::write ERROR {PMT_GTWY: pmt_not_done_filter_qry failed: $msg}
			error {pmt_not_done_filter_qry failed in proc calcCommissionPmtDone}
			return [list 0 $amount $amount]
		}
	} else {
		if {[catch {
			set rs [ob_db::exec_qry payment_gateway::pmt_not_done_qry \
				$pay_mthd \
				$ccy_code \
				$pay_type \
				$amount \
				$amount]
		} msg]} {

			ob_log::write ERROR {PMT_GTWY: pmt_not_done_qry failed: $msg}
			error {pmt_not_done_qry failed in proc calcCommissionPmtDone}
			return [list 0 $amount $amount]
		}
	}

	# Initialise the max commission found
	set max_comm_found 0

	# Get num rows returned
	set num_rows [db_get_nrows $rs]

	# For each rule calc the commission and payment amount (checking the min
	# and max)
	for {set i 0} {$i < $num_rows} {incr i} {

		# Use format to ensure numbers are decimals for division in calculations
		set percent_charge [db_get_col $rs $i percent_charge]
		set amt_charge     [db_get_col $rs $i amt_charge]
		set min_charge     [db_get_col $rs $i min_charge]
		set max_charge     [db_get_col $rs $i max_charge]

		# Calculate commission
		set comm [getComm $pay_type $amount $percent_charge $amt_charge false]

		# If commission amount is not 0 ensure it is in the min-max charge range
		if {$comm > 0} {
			if {$comm < $min_charge} {
				set comm $min_charge
			} elseif {$comm > $max_charge && $max_charge != {}} {
				set comm $max_charge
			}
		}

		# Compare the commission to the current maximum
		if {$comm > $max_comm_found} {
			set max_comm_found $comm
		}
	}

	# Calculate payment amount - amount to go through the payment gateway
	# It is (amount + commission) for deposits but (amount - commission) for
	# withdrawals
	set payment_amt [getPayAmt $pay_type $amount $max_comm_found]

	# Calculate tPmt amount - amount to be inserted into tPmt
	# It is amount for deposits but (amount - commission) for withdrawals
	set tPmt_amount [get_tPmtAmt $pay_type $amount $max_comm_found]

	# Return the commission, payment amount and tPmt amount
	return [list $max_comm_found $payment_amt $tPmt_amount]
}



# Calcs and returns the commission
# 	amount - amount by which account balance should change if is_pmt_done is
#	         false; amount that has already gone through the gateway otherwise
#
# Commission is calculated as follows:
#
#	if payment is not done:
#		if deposit:
#			percent charge of the amount is calculated, customer is charged
#			amount + percent charge + flat charge
#		if withdrawal:
#			percent charge applies to the amount customer is to receive,
#			customer receives amount - percent charge - flat charge
#
#	if payment is done:
#		if deposit:
#			specified amount has already been paid by customer, percent charge
#			of the balance change amount is calculated, customer has already
#			paid balance change amount + percent charge + flat charge
#		if withdrawal (hard to see when we would charge comm after cust has been
#			paid): specified amount has already been received by customer,
#			percent charge of the amount customer has received is calculated,
#			customer has already received balance change amount - percent charge
#			- flat charge
#
proc payment_gateway::getComm {pay_type amount percent_charge amt_charge is_pmt_done} {

	# use format to ensure numbers are decimals
	# so that division returns a decimal and not just an int
	set amount         [format %.2f $amount]
	set percent_charge [format %.2f $percent_charge]
	set amt_charge     [format %.2f $amt_charge]

	if {$is_pmt_done} {

		# calc commission
		if {$pay_type == {D}} {
			# deposit
			set comm [expr {
				(($amount * $percent_charge) + (100 * $amt_charge))
					/ (100 + $percent_charge)
			}]
		} else {
			# withdrawal
			set comm [expr {($amount * $percent_charge / 100) + $amt_charge}]
		}
	} else {

		# calc commission
		if {$pay_type == {D}} {
			# deposit
			set comm [expr {($amount * $percent_charge / 100) + $amt_charge}]
		} else {
			# withdrawal
			set comm [expr {
				(($amount * $percent_charge) + (100 * $amt_charge))
					/ (100 + $percent_charge)
			}]
		}
	}

	# round the commission to 2 decimal places
	set comm [format %.2f $comm]

	# return commission
	return $comm
}



# Calcs and returns the payment amount - amount to go through the payment
# gateway
#
proc payment_gateway::getPayAmt {pay_type amount comm} {

	# calc payment amount - amount to go through the payment gateway
	# it is (amount + commission) for deposits but (amount - commission) for
	# withdrawals
	if {$pay_type == {D}} {
		set payment_amt [expr {$amount + $comm}]
	} else {
		set payment_amt [expr {$amount - $comm}]
	}

	# ensure 2 decimal places
	set payment_amt [format %.2f $payment_amt]

	# return payment amount
	return $payment_amt
}



# Calcs and returns the tPmt amount - amount to be inserted into tPmt
#
proc payment_gateway::get_tPmtAmt {pay_type amount comm} {

	# calc tPmt amount - this is the amount to be inserted into tPmt
	# it is amount for deposits but (amount - commission) for withdrawals
	if {$pay_type == {D}} {
		set tPmt_amt $amount
	} else {
		set tPmt_amt [expr {$amount - $comm}]
	}

	# ensure 2 decimal places
	set tPmt_amt [format %.2f $tPmt_amt]

	# return tPmt amount
	return $tPmt_amt
}



# Calcs and returns the balance change amount - amount by which customer's
# balance will change
#
proc payment_gateway::getBalChangeAmt {pay_type payment_amount comm} {

	# calc amount - this is the amount by which the customer's balance will
	# change it is (amount - commission) for deposits but (amount + commission)
	# for withdrawals
	if {$pay_type == {D}} {
		set amount [expr {$payment_amount - $comm}]
	} else {
		set amount [expr {$payment_amount + $comm}]
	}

	# ensure 2 decimal places
	set amount [format %.2f $amount]

	# return amount
	return $amount
}



# Check if the payment has already been settled (i.e. been marked
# as good or bad or cancelled).
#
# pmt_id - The ID of the payment
#
# returns - 'OK' is the payment has not been completed (i.e. good/bad),
#           otherwise an error is returned
#
proc payment_gateway::chk_pmt_not_settled {pmt_id} {

	variable PG_INITIALISED

	# Run this the first time this function is called
	if {!$PG_INITIALISED} {
		set PG_INITIALISED [pmt_gtwy_init]
	}

	# Check that we are not about to send a payment that is already set to Y or N
	if {[catch {set rs [ob_db::exec_qry payment_gateway::pmt_get_status $pmt_id]} msg]} {
		ob::log::write ERROR "Could not obtain payment status: $msg"
		return "PMT_ERR"
	}
	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		ob::log::write ERROR "Incorrect number of rows returned for payment"
		return "PMT_ERR_NOT_FOUND"
	}
	set pmt_status [db_get_col $rs 0 status]
	db_close $rs

	if {$pmt_status == "Y" || $pmt_status == "N" || $pmt_status == "X"} {
		ob::log::write ERROR "Payment $pmt_id is already set to $pmt_status. Don't make\
		 the payment"
		return "PMT_ERR_ALREADY_STL"
	}

	return "OK"

}




# Determines whether cvv2 is going to be required and which datacash policy to use
#
proc payment_gateway::get_cvv2_policy {{cpm_id ""} {amount ""} {gtwy_pol ""}} {

	variable PG_INITIALISED

	#
	# Run this the first time this function is called
	#
	if {!$PG_INITIALISED} {
		set PG_INITIALISED [pmt_gtwy_init]
	}

	set cvv2_needed 0
	set avs_needed  0
	set policy_no   ""

	# get the ccy check value
	if {[catch {
		set rs [ob_db::exec_qry payment_gateway::get_cvv2_check_value $cpm_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_cvv2_check_value qry for cpm_id $cpm_id : $msg}
		return [list "Could not retrieve currency details for your account." 0 0 "" 0]
	}

	set cvv2_check_value [db_get_col $rs 0 cvv2_check_value]
	ob_db::rs_close $rs

	set policy_result [work_out_policy $amount $cvv2_check_value $gtwy_pol $cpm_id]

	if {[lindex $policy_result 0] == "OK"} {
		set policy_no   [lindex $policy_result 1]
		set cvv2_length [lindex $policy_result 2]
	} else {
		return [list [lindex $policy_result 0] 0 0 "" 0]
	}

	# check which policies require a cvv2 number
	if {[lsearch [list 0 2 3 6 7] $policy_no] > -1} {
		set cvv2_needed 1
	}

	# check which policies require address for avs
	# HEAT 25674 - took out or condition which evaluated
	#              to true if cvv2_needed was == 1 here.
	if {[lsearch [list 1 3 5 7] $policy_no] > -1} {
		set avs_needed 1
	}

	# datacash don't allow a policy of 0 to be sent with the
	# transaction. the vtids default policy is 0 so # setting it to null will have
	# the same effect
	if {$policy_no == 0} {set policy_no ""}

	# all OK, return info
	return [list "OK" $cvv2_needed $cvv2_length $policy_no $avs_needed]
}



# decodes the check_flag to determine the policy to be used
# returns [list message policy_no cvv2_length]
#
proc payment_gateway::work_out_policy {amount cvv2_check_value gtwy_pol cpm_id} {

	if {[catch {
		set rs [ob_db::exec_qry payment_gateway::get_cvv2_details $cpm_id]
	} msg]} {
		ob_log::write ERROR {Failed to get card scheme for cpm_id $cpm_id. $msg}
		return [list "Could not retrieve account details." "" 0]
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		# card belongs to more than one scheme or card doesn't belong
		# to a scheme, therefore an error has occured
		ob_log::write ERROR {$nrows card schemes found for cpm_id $cpm_id. Should be 1.}
		return [list "Unrecognised card number." "" 0]
	}

	set check_flag    [db_get_col $rs 0 check_flag]
	set cvv2_length   [db_get_col $rs 0 cvv2_length]
	set first_dep_pol [db_get_col $rs 0 first_dep_pol]
	set flag_channels [db_get_col $rs 0 flag_channels]
	set amount_pol    [OT_CfgGet DCASH_STRICT_POLICY 0]

	ob_log::write INFO {check_flag = $check_flag first_dep_pol = $first_dep_pol cvv2_length = $cvv2_length amount_pol = $amount_pol}

	if {$cvv2_length == 0} {
		return [list "OK" "" 0]
	}

	# admin doesn't have an entry in tchannel, so wouldn't be in flag_channels
	set cfg_channel [OT_CfgGet CHANNEL ""]
	set channel [expr {$cfg_channel == "A" ? "P" : $cfg_channel}]

	ob_log::write DEV {cfg_channel = $cfg_channel channel = $channel}

	if {[string first $channel $flag_channels] > -1} {
		if {
			$amount != "" &&
			$amount > $cvv2_check_value &&
			$cvv2_check_value != 0 &&
			$check_flag != "N" &&
			$amount_pol != 0
		} {
			set policy_no $amount_pol

		} else {
			# does the check flag indicate first deposit?
			if {$check_flag == "F"} {
				if {[catch {
					set rs [ob_db::exec_qry payment_gateway::get_deposits_made $cpm_id]
				} msg]} {
					ob_log::write ERROR {Failed to get deposits made for cpm_id $cpm_id. $msg}
					return [list "Could not retrieve account details." "" 0]
				}
				if {[db_get_nrows $rs] < 1} {
					# this is customer's first deposit
					set policy_no $first_dep_pol
				} else {
					set policy_no $gtwy_pol
				}
				ob_db::rs_close $rs

			# always check
			} elseif {$check_flag == "A"} {
				set policy_no $gtwy_pol

			# never check
			} elseif {$check_flag == "N"} {
				set policy_no 0

			# specific datacash policy
			} elseif {
				($check_flag >= 0 && $check_flag <= 3) ||
				($check_flag >= 5 && $check_flag <= 7)
			} {
				set policy_no $check_flag
			}

		}
	} else {
		set policy_no [OT_CfgGet DCASH_CHANNEL_POLICY ""]
	}

	return [list "OK" $policy_no $cvv2_length]
}


#
#  A Public Procedure that gets the Pay Method of a Payment Gateway
#
#  id - the ID value to be used in the query
#  type - determines if we're using the PMG Account/Host on lookup
#
#  returns - 'INVALID_PAY_MTD' on any Error encountered, the pay method otherwise
#
proc payment_gateway::get_pmg_pay_mthd {id type} {

	global DB

	switch -exact $type {
		"acct" {
			set sql [subst {
				select
					pay_mthd
				from
					tPmtGateAcct
				where
					pg_acct_id = $id}]
		}
		"host" {
			set sql [subst {
				select
					first 1 pay_mthd
				from
					tPmtGateAcct a,
					tPmtGateHost h
				where
					a.pg_type = h.pg_type and
					h.pg_host_id = $id}]
		}
		default {
			OT_LogWrite 3 "get_pmg_pay_mthd : Unknown type given, $type"
			return "INVALID_PAY_MTD"
		}
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		OT_LogWrite 3 "get_pmg_pay_mthd : Ivalid number of rows returned ($nrows)"
		return "INVALID_PAY_MTD"
	}

	set pay_mthd [db_get_coln $res 0 0]

	db_close $res

	return $pay_mthd

}
