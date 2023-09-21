#
# $Id: payment_MB.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# $Name:  $

#
# Integration with MoneyBookers API
#
# Configuration - mandatory:
#  PMT_MB_STATUS_API_URL - The URL in which MoneyBooker sends it's status
#                          reports to (after a deposit is made on the
#                          MoneyBookers site).
#  PMT_MB_DEP_API_URL    - The URL that the deposit information on OpenBet
#                          is forwarded to in order to perform a sucessful
#                          payment redirect to the MoneyBookers site.
#  PMT_MB_WTD_API_URL    - The URL that instantly processes withdraw requests
#                          to a MoneyBookers eWallet.
#  PMT_MB_QRY_API_URL    - The URL that processes MoneyBooker transaction
#                          queries (Re-post of MoneyBookers status report).
#
# Configuration - optional:
#  PMT_MB_CANCEL_URL     - The URL that MoneyBookers will refer to if the user
#                          cancels the transaction on the MoneyBookers site.
#                          This defaults to '' in which will result in a window
#                          close on the MoneyBookers site.
#  PMT_MB_CCY_CODES      - The valid country codes in which OpenBet will accept
#                          MoneyBooker transactions from. This will controlled
#                          by CPM Rules anyhow but just to be sure.
#  PMT_MB_SUPPORTED_LANGS- The languages that the MoneyBookers site supports.
#                          If the customers language isn't in the list it will
#                          default to english.
#  PMT_MB_REDIRECT_DELAY - The amount of seconds delay before the user gets
#                          redirected to the MoneyBookers site on deposits.
#  PMT_MB_API_TIMEOUT    - The timeout value associated with any API calls.
#                          Note: This should be obtained from 'tPmtGateAcct'
#                          ideally but i'll try an find a good place to do so.
#  PMT_MB_OB_EMAIL_DIFF_MB_ID - This determines if a MoneyBookers CPM can be
#                          used immediately on registeration even if the
#                          MoneyBookers ID differs to the customers email
#                          address on OpenBet. If switched off, the CPM
#                          should be suspended until it is has been verified.
#
#
# Public procedures:
#
#  payment_MB::insert_cpm        - Inserts a new MoneyBookers CPM
#  payment_MB::insert_pmt        - Inserts a new MoneyBookers payment
#  payment_MB::update_pmt        - Updates a MoneyBookers payment
#  payment_MB::update_pmt_status - Updates the status of a payment (gen payment?)
#  payment_MB::do_wtd            - Performs a MoneyBookers withdrawal
#  payment_MB::do_repost         - Performs a MoneyBooker Status Report Repost
#

#
# Dependancies (standard packages)
#
package require tdom
package require util_xl
package require pmt_validate
package require net_socket

ob_xl::init

#
# Dependancies (shared_tcl)
#
# db.tcl
# payment_gateway.tcl
# crypto.tcl
# gen_payment.tcl
#

package require OB_Log
package require util_appcontrol

if {[OT_CfgGet MONITOR 0]} {

          package require monitor_compat

}

namespace eval payment_MB {
	variable MB_INIT
	set MB_INIT 0
	variable CFG
	variable PMT_DATA
	variable WTD_AUTH_PARENT_ELEMS
	variable WTD_EXEC_PARENT_ELEMS
	variable OB_PMT
}



# -------------------------------------------------------------------------------------
#  Public Procedures
# -------------------------------------------------------------------------------------

#
# One-time Initialisaction Procedure
#
proc payment_MB::init {} {
	variable MB_INIT
	variable CFG
	variable PMT_DATA
	variable WTD_AUTH_PARENT_ELEMS
	variable WTD_EXEC_PARENT_ELEMS
	variable OB_PMT


	if {$MB_INIT} { return }

	ob_log::write INFO {payment_MB::init - Initialising MoneyBookers}

	# Moneybookers API URLs (mandatory in config file).
	foreach c [list dep_api_url wtd_api_url qry_api_url] {
		set url [OT_CfgGet "MB_PMT_[string toupper $c]"]
		set CFG($c) $url
	}

	# Optional config items.
	foreach {c dflt} [list \
	                    status_url {} \
	                    cancel_url {} \
	                    ccy_codes [list GBP EUR USD CAD AUD JPY] \
	                    supported_langs [list EN DE ES FR IT] \
	                    redirect_delay 0 \
	                    api_timeout 10000 \
	                    ob_email_diff_mb_id 1\
	                    func_quick_reg 0] {
		set CFG($c) [OT_CfgGet "MB_PMT_[string toupper $c]" $dflt]
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CFG(pmt_receipt_format) 0
		set CFG(pmt_receipt_tag)    ""
	}

	# MoneyBooker responses unfortunately lack constistency so the
	# below variables inform OpenBet what response elements to look
	# for when processing a response.
	set WTD_AUTH_PARENT_ELEMS [list error response]
	set WTD_EXEC_PARENT_ELEMS [list error transaction]

	# Hold information about an OpenBet MoneyBookers payment
	array set OB_PMT [list]

	_prep_qrys

	set MB_INIT 1
}



#
#  Insert a new MoneyBookers Customer Payment Method (CPM)
#
#  cust_id       - The customers ID
#  mb_email      - The customers MoneyBookers registered Email Address
#  auth_dep      - deposit authorisation status
#  auth_wtd      - withdrawal authorisation status
#  transactional - determines if the execution of the stored procedure
#                  is transactional/not
#  oper_id       - The Admin operator ID (if admin user adds the CPM)
#  change_cpm    - Flag that determines if the Customer is changing their
#                  existing CPM (which really consists of inserting a new
#                  CPM and scratching the existing one)
#  call_id       - (optional) if this is a telebetting transaction, the tCall.call_id for this
#
#  returns -  a list [0 error_msg] on failure on payment insertion,
#             [1 cpm_id] otherwise
#
proc payment_MB::insert_cpm {
	cust_id
	mb_email
	{auth_dep P}
	{auth_wtd P}
	{transactional Y}
	{oper_id ""}
	{change_cpm N}
	{strict_check "Y"}
} {

	ob_log::write INFO \
	      {payment_MB::insert_cpm($cust_id,$mb_email,$auth_dep,$auth_wtd,\
	       $transactional,$oper_id,$change_cpm)}

	if {[catch {set rs [tb_db::tb_exec_qry payment_MB::insert_cpm \
	                                                     $cust_id \
	                                                     $auth_dep \
	                                                     $auth_wtd \
	                                                     $transactional \
	                                                     $mb_email \
	                                                     $oper_id \
	                                                     $change_cpm \
	                                                     $strict_check]} msg]} {
		ob_log::write ERROR {payment_MB::insert_cpm: Unable to add Moneybookers CPM,  - $msg}
		return [list 0 $msg]
	} else {

		set nrows [db_get_nrows $rs]

		if {$nrows != 1} {
			set msg "Rows returned does not equal 1. Returned $nrows rows for cust_id $cust_id"
			ob_log::write ERROR {payment_MB::insert_cpm: $msg}
			db_close $rs
			return [list 0 $msg]
		}

		set cpm_id     [db_get_coln $rs 0 0]
		set cpm_status [db_get_coln $rs 0 1]
		db_close $rs

		if {$strict_check == "N" && $cpm_status == "S"} {
			set msg "Inserted a MoneyBookers method with cpm_id = $cpm_id, but it was immmediately suspended"
			ob_log::write INFO {payment_MB::insert_cpm: $msg}
			return [list 2 $msg]
		}

		ob_log::write INFO {Successfully added new MoneyBookers payment method, cpm_id: $cpm_id}
		return [list 1 $cpm_id]
	}
}



#
#  Insert a new MoneyBookers payment
#
#  acct_id       - the customers account ID
#  cpm_id        - the customers Customer Payment Method ID
#  payment_sort  - either DEP/WTD
#  amount        - the payment amount
#  ipaddr        - the ipaddr of the user who made the payment
#  source        - the Channel source of the payment
#  unique_id     - a ID value that uniquely idenitifies an OpenBet payment
#  ccy_code      - The customers OpenBet Currency Code
#  transactional - determines if the execution of the stored procedure
#                  is transactional/not
#  oper_id       - The Admin operator ID (if admin user adds the payment)
#  min_overide   - whether this payment is allowed to overide the minimum withdrawal limits
#
#  returns -  a list [0 error_msg] on failure on payment insertion,
#            [1 pmt_id pg_acct_id] otherwise
#
proc payment_MB::insert_pmt { acct_id cpm_id payment_sort amount ipaddr
                                        source unique_id ccy_code
                                        {transactional Y} {oper_id {}} \
                                        {min_overide "N"} {call_id ""}} {

	ob_log::write INFO \
	   {payment_MB::insert_pmt($acct_id,$cpm_id,$payment_sort,$amount,$ipaddr,\
	   $unique_id,$source,$ccy_code,$transactional,$oper_id,$min_overide,$call_id)}

	variable PMT_DATA

	catch {array unset PMT_DATA}

	# set up the payment sort prior to evaluating the PMG rules
	set PMT_DATA(pay_sort) $payment_sort
	set PMT_DATA(ccy_code) $ccy_code
	set PMT_DATA(pay_mthd) "MB"

	# OVS check.
	if {[OT_CfgGet FUNC_OVS 0] &&  [OT_CfgGet FUNC_OVS_VERF_MB_CHK 1]} {
		set chk_resp [verification_check::do_verf_check \
			"MB" \
			$payment_sort \
			$acct_id]

		if {![lindex $chk_resp 0]} {
			return [list 0 [lindex $chk_resp 1]]
		}
	}


	# Get the MoneyBookers Payment Gateway Account details so we
	# know which MoneyBookers merchant acocunt the payment is affecting.
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]

	if {[lindex $pg_result 0] == 0} {
		set msg [lindex $pg_result 1]
		ob_log::write ERROR {PMT Payment Rules Failed ; $msg}
		return [list 0 "MB_FAILED_PMG_RULES"]
	}

	# Useful during debugging to be able to do lots of payments.
	if { [OT_CfgGetTrue DISABLE_PMT_SPEED_CHECK] } {
		set speed_check N
	} else {
		set speed_check Y
	}

	# Attempt to insert the payment
	if {[catch {set rs [tb_db::tb_exec_qry payment_MB::insert_pmt \
								$acct_id \
								$cpm_id \
								$payment_sort \
								$amount \
								$ipaddr \
								$unique_id \
								$source \
								$PMT_DATA(pg_acct_id) \
								$PMT_DATA(pg_host_id) \
								$transactional \
								$speed_check \
								$oper_id \
								[get_cfg pmt_receipt_format] \
								[get_cfg pmt_receipt_tag] \
								$min_overide \
								$call_id \
	]} msg]} {
		ob_log::write ERROR {payment_MB::insert_pmt Failed to insert Moneybookers - $msg}

		# Use PMG code to transform error into human readable form
		set err [payment_gateway::cc_pmt_get_sp_err_code $msg]
		return [list 0 $err]
	} else {
		set pmt_id [db_get_coln $rs 0 0]
		db_close $rs

		# Send monitor message if monitors are configured on
		if {[OT_CfgGet MONITOR 0]} {

			set pmt_date [clock format [clock seconds] -format {%Y-%m-%d %T}]

			# Send the payment info to the Router
			_mb_send_pmt_ticker $acct_id $ $pmt_id $pmt_date $payment_sort $ccy_code $amount $source "P"

		}
		return [list 1 $pmt_id $PMT_DATA(client)]
	}
}



#
#  Updates a MoneyBookers payment
#
#  pmt_id    - the ID of the payment
#  status    - the status of the payment
#  mb_txn_id - the unique ID that MoneyBooker allocates to the payment attempt
#  mb_status - the status MoneyBookers assigns to the payment
#  sid       - the Session ID MoneyBooker assigns to a withdrawal request
#
#  returns - 1 on successful update, 0 otherwise
#
proc payment_MB::update_pmt { pmt_id status {mb_txn_id ""} {mb_status ""} {sid ""} {payment_type ""}} {
	ob_log::write INFO {payment_MB::update_pmt($pmt_id,$status,$mb_txn_id,$mb_status,$sid)}

	if {[catch [tb_db::tb_exec_qry payment_MB::update_pmt $pmt_id \
	                                                      $status \
	                                                      $mb_txn_id \
	                                                      $mb_status \
	                                                      $sid \
	                                                      $payment_type] msg]} {
		ob_log::write ERROR {payment_MB::update_pmt: Failed executing query - $msg}
		return 0
	}

	return 1
}



#
# Update the Status of a MoneyBookers payment
#
#  pmt_id - the ID of the payment
#  status - the status of the payment
#
#  returns - 1 on succesful update, 0 otherwise
#
proc payment_MB::update_pmt_status {pmt_id status} {
	ob_log::write INFO {payment_MB::update_pmt_status($pmt_id,$status)}

	if {[catch [tb_db::tb_exec_qry payment_MB::update_pmt_status \
	                                           $pmt_id $status] msg]} {
		ob_log::write ERROR {payment_MB::update_pmt_status: Failed to execute query - $msg}
		return 0
	}

	return 1
}



#
#  Performs a withdrawal to a MoneyBookers eWallet. It normally
#  does so via two requests, a Withdraw Authorisation request
#  (validates that the payment is ok and MoneyBBokers allocates a
#  a session ID to the payment) and then a Withdraw Execution Request
#  with actually does the funds withdrawal. The initial request can be
#  by-passed if the payment already has a Session ID (e.g. withdrawal
#  re-attempts).
#
#  pmt_id - the unique ID OpenBet gives to a payment
#
#  returns - [list 0 err_msg] on any Error encountered, [list 1 'res'
#            (contains XML on the payment details)] otherwise
#
proc payment_MB::do_wtd {pmt_id {check_fraud_status 1}} {

	ob_log::write INFO {payment_MB::do_wtd($pmt_id)}

	variable OB_PMT

	# Get the details of the payment (sanity check that the payment
	# is only  a withdrawal)
	if {![_get_pmt_details $pmt_id "W"]} {
		return [list 0 INVALID_PMT]
	}

	if {$check_fraud_status} {
		set process_pmt [ob_pmt_validate::chk_wtd_all\
			$OB_PMT(acct_id)\
			$pmt_id\
			"MB"\
			"----"\
			$OB_PMT(amount)\
			$OB_PMT(ccy_code)]

		if {!$process_pmt} {
			# We will need to check the payment for potential fraud or dealy the
			# payment before it is processed
			# For now we will return that it was successful
			return [list 1 ""]
		}
	}

	# Only send a Withdraw Auth. Request if the payment does not have
	# a MoneyBookers Session ID.
	if {$OB_PMT(sid) == ""} {
		# Now send the MoneyBookers Withdrawal Authorisation Request
		set auth_wtd_res [_send_wtd_auth_req $pmt_id]

		set res [lindex $auth_wtd_res 1]

		if {[lindex $auth_wtd_res 0] == 0} {
			ob_log::write ERROR {payment_MB::send_wtd_req: Failed MoneyBookers Withdrawal Preparation Request, $res}
			return [list 0 $res]
		}

		set OB_PMT(sid) $res
	} else {
		ob_log::write INFO {payment_MB::_send_wtd_auth_req: Bypassing Withdraw Auth. Request as a MoneyBookers Session ID ($OB_PMT(sid)) already exist for this pmt ($pmt_id)}
	}

	#
	# OK, we have the Session ID (either from the wtd auth request or it has
	# been obtained earlier) so lets make the withdrawal via the MoneyBookers
	# execute Withdrawal request
	#
	set exec_wtd_res [_send_exec_wtd_req $pmt_id]

	set res [lindex $exec_wtd_res 1]
	if {[lindex $exec_wtd_res 0] == 0} {
		ob_log::write ERROR {payment_MB::send_wtd_req: Failed MoneyBookers Withdrawal Execution Request, $res}
		return [list 0 $res]
	}

	return [list 1 $res]

}



#
#  Performs a MoneyBookers 'Repost' request. This is used to
#  prompt MoneyBookers to resend a MoneyBooker status report
#  on a deposit attempt to OpenBet.
#
#  pmt_id - the unique ID OpenBet gives to a payment
#
#  returns - [list 0 err_msg] on any Error encountered, [list 1 "OK"] otherwise
#
proc payment_MB::do_repost {pmt_id} {

	ob_log::write INFO {payment_MB::do_repost($pmt_id)}

	variable OB_PMT

	# Get the details of the payment (ensuring it's a deposit only)
	if {![_get_pmt_details $pmt_id "D"]} {
		return [list 0 INVALID_PMT]
	}

	# Build up the required parameters for a repost request
	set params_nv [list \
	                 "action"     "repost" \
	                 "email"      $OB_PMT(merch_email) \
	                 "password"   $OB_PMT(md5_merch_pwd) \
	                 "trn_id"     $pmt_id \
	                 "mb_trn_id"  $OB_PMT(mb_transaction_id) \
	                 "status_url" [payment_MB::get_cfg status_url]]

	# Send the request to MoneyBookers
	set res [_send_request $params_nv [payment_MB::get_cfg qry_api_url]]
	set res_desc [lindex $res 1]

	if {[lindex $res 0] == 0} {
		ob_log::write ERROR {payment_MB::do_repost: Failed to send Repost request, $res_desc}
		return [list 0 $res_desc]
	}

	# Response comes back in an 'response code : response message format'
	# so let's attempt to extract the info
	if {![regexp {^\s*(\d+)\s(.+)$} $res_desc -> return_code return_msg]} {
		return [list 0 $res_desc]
	} else {

		# If the response code is '200' then repost has been successful
		if {$return_code == 200} {
			return [list 1 "OK"]
		} else {

			# It can only be an error message to display the error
			return [list 0 "MoneyBookers Response :$return_msg (Error Code : $return_code)"]
		}
	}

}



#
#  Gets a MoneyBookers confuration items details
#
#  cfg_item - the required MoneyBookers config item
#
#  returns - the value of the MoneyBookers config item
#
proc payment_MB::get_cfg { cfg_item } {
	variable CFG
	return $CFG($cfg_item)
}



# -------------------------------------------------------------------------------
#  Private Procedures
# -------------------------------------------------------------------------------



#
#  Prepare required MoneyBookers database queries
#
proc payment_MB::_prep_qrys {} {
	global SHARED_SQL

	# Insert a MoneyBookers Customer Payment Method
	set SHARED_SQL(payment_MB::insert_cpm) {
		execute procedure pCPMInsMB (
			p_cust_id          = ?,
			p_auth_dep         = ?,
			p_auth_wtd         = ?,
			p_transactional    = ?,
			p_mb_email_addr    = ?,
			p_oper_id          = ?,
			p_cpm_change       = ?,
			p_strict_check     = ?
		)
	}

	# Insert a MoneyBookers payment
	set SHARED_SQL(payment_MB::insert_pmt) {
		execute procedure pPmtInsMB (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_ipaddr         = ?,
			p_unique_id      = ?,
			p_source         = ?,
			p_pg_acct_id     = ?,
			p_pg_host_id     = ?,
			p_transactional  = ?,
			p_speed_check    = ?,
			p_oper_id        = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?,
			p_overide_min_wtd= ?,
			p_call_id        = ?
		)
	}

	# Updates the status of a payment (generic?)
	set SHARED_SQL(payment_MB::update_pmt_status) {
		execute procedure pPmtUpdStatus (
			p_pmt_id         = ?,
			p_status         = ?
		)
	}

	# Update the MoneyBookers payment with the MoneyBookers Session ID allocated
	# to the payment (withdrawals only)
	set SHARED_SQL(payment_MB::update_pmt_sid) {
		update tPmtMB set
			sid    = ?
		where
			pmt_id = ?
	}

	# Update the MoneyBookers payment
	set SHARED_SQL(payment_MB::update_pmt) {
		execute procedure pPmtUpdMB (
			p_pmt_id            = ?,
			p_status            = ?,
			p_mb_transaction_id = ?,
			p_mb_status         = ?,
			p_sid               = ?,
			p_payment_type      = ?
		)
	}

	# Get the details for a payment (do we want this
	# for users with active CPMs only?)
	set SHARED_SQL(payment_MB::get_pmt_details) {
		select
			a.acct_id,
			a.ccy_code,
			c.cust_id,
			c.lang,
			cpm.cpm_id,
			cpm.auth_dep,
			mb.mb_email_addr,
			p.amount,
			p.payment_sort,
			p.status,
			mbp.sid,
			mb_transaction_id,
			pmg.pg_acct_id,
			pmg.enc_client,
			pmg.enc_client_ivec,
			pmg.enc_password,
			pmg.enc_password_ivec,
			pmg.enc_key,
			pmg.enc_key_ivec,
			pmg.data_key_id
		from
			tAcct a,
			tCustomer c,
			tCustPayMthd cpm,
			tCPMMB mb,
			tPmt p,
			tPmtMB mbp,
			tPmtGateAcct pmg
		where
			cpm.cpm_id     = p.cpm_id and
			cpm.cpm_id     = mb.cpm_id and
			c.cust_id      = a.cust_id and
			a.cust_id      = cpm.cust_id and
			p.pmt_id       = mbp.pmt_id and
			pmg.pg_acct_id = mbp.pg_acct_id and
			p.payment_sort = ? and
			p.pmt_id       = ?
	}

	# query used to get data to send to the payment non-card ticker
	set SHARED_SQL(payment_MB::get_payment_ticker_data) {
		select
			c.cust_id,
			c.cr_date as cust_reg_date,
			c.username,
			c.notifyable,
			c.country_code,
			cr.fname,
			cr.lname,
			cr.email,
			cr.code,
			cr.addr_city,
			cr.addr_postcode,
			cr.addr_country,
			a.balance,
			ccy.exch_rate
		from
			tcustomer c,
			tcustomerreg cr,
			tacct a,
			tCcy ccy
		where
			a.acct_id  = ? and
			a.cust_id  = cr.cust_id and
			cr.cust_id = c.cust_id and
			a.ccy_code = ccy.ccy_code
	}

}



#
#  Gets the OpenBet details on the MoneyBookers payment
#  and loads that info. into the 'OB_PMT' variable
#
#  pmt_id  - the unique ID OpenBet gives to a payment
#  pay_sort - the sort of payment we want to get info from (W(td)/D(ep))
#
#  returns - 1 on success, 0 otherwise
#
proc payment_MB::_get_pmt_details {pmt_id pay_sort} {

	variable OB_PMT

	catch {array unset OB_PMT}

	ob_log::write DEV {payment_MB::_get_pmt_details($pmt_id)}

	# Get the payment details
	if {[catch {set rs [tb_db::tb_exec_qry payment_MB::get_pmt_details \
	                                                         $pay_sort \
	                                                         $pmt_id]} msg]} {
		ob_log::write ERROR {payment_MB::_get_pmt_details: Failed to execute query - $msg}
		return 0
	}

	set nrows [db_get_nrows $rs]
	if { $nrows != 1} {
		ob_log::write ERROR \
		   {payment_MB::_get_pmt_details: Invalid amount of rows ($nrows)\
		   returned getting payment details for payment ID $pmt_id}
		db_close $rs
		return 0
	}

	set cols [db_get_colnames $rs]
	foreach col $cols {
		set OB_PMT($col) [db_get_col $rs 0 $col]
	}

	# decrypt the merchant email and pwd, 'md5' the pwd as that's a MoneyBookers
	# requisite when sending it over to MoneyBookers
	set enc_db_vals [list \
	                 [list $OB_PMT(enc_client) $OB_PMT(enc_client_ivec)] \
	                 [list $OB_PMT(enc_password) $OB_PMT(enc_password_ivec)]]

	set pg_acct_id  [db_get_col $rs 0 pg_acct_id]
	set data_key_id [db_get_col $rs 0 data_key_id]

	tb_db::tb_close $rs

	set decrypt_rs  [card_util::batch_decrypt_db_row $enc_db_vals \
	                                                 $data_key_id \
	                                                 $pg_acct_id \
	                                                 "tPmtGateAcct"]

	if {[lindex $decrypt_rs 0] == 0} {
		ob_log::write ERROR {ob_moneybookers::_get_pmt_details: Error\
		   decrypting merchant details: [lindex $decrypt_rs 1]}
		return 0
	} else {
		set decrypted_vals [lindex $decrypt_rs 1]
	}

	set OB_PMT(merch_email)   [lindex $decrypted_vals 0]
	set OB_PMT(md5_merch_pwd) [md5 [lindex $decrypted_vals 1]]

	return 1
}



#
#  payment_MB::_send_request
#
#  Send a request to MoneyBookers
#
#  params_nv - name value pairs of parameters to send
#  api_url   - the URL that the request will needed to be sent to. This
#              varies according to the transactoin type (dep,wtd &query lookup)
#
#  returns - a list, on success : [1 response],[0  err_msg] otherwise
#
proc payment_MB::_send_request {params_nv api_url} {

	ob_log::write DEBUG {payment_MB::_send_request($api_url)}

	# Figure out the connection settings for this API.
	set api_timeout [payment_MB::get_cfg api_timeout]
	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $api_url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {payment_MB::_send_request: Bad API URL, $msg}
		return [list 0 "MB_REQ_ERROR"]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "GET" \
		           -form_args  $params_nv \
		           $api_url]
	} msg]} {
		ob_log::write ERROR {payment_MB::_send_request: Bad request, $msg}
		return [list 0 "MB_REQ_ERROR"]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	if {$api_scheme == "http"} {
		set tls -1
	} else {
		set tls {}
	}

	# Send the request to the MoneyBookers API url.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $api_timeout \
		    -req_timeout  $api_timeout \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob_log::write ERROR {payment_MB::_send_request: send_req failed, $msg}
		return [list 0 "HTTP_ERROR"]
	}

	if {$status == "OK"} {

		# Request successful - get and return the response data.
		set res_body [::ob_socket::req_info $req_id http_body]

		ob_log::write DEBUG {payment_MB::_send_request : Response is: $res_body}

		::ob_socket::clear_req $req_id

		return [list 1 $res_body]

	} else {

		# Request failed - decode reason and return failure.
		ob_log::write ERROR {payment_MB::_send_request : Bad response, status was $status}

		::ob_socket::clear_req $req_id

		# XXX We map the status as best we can to the code that the old
		# version of this file (which used the http/tls packages) should
		# have returned
		switch -exact -- $status {
			"CONN_FAIL" -
			"HANDSHAKE_FAIL" {
				set err_code "MB_REQ_ERROR"
			}
			"CONN_TIMEOUT" {
				set err_code "TIMEOUT"
			}
			"HTTP_INFORMATION_REQ" -
			"HTTP_REDIRECT" -
			"HTTP_CLIENT_ERROR" -
			"HTTP_SERVER_ERROR" {
				set err_code "HTTP_WRONG_CODE"
			}
			default {
				set err_code "HTTP_ERROR"
			}
		}

		return [list 0 $err_code]

	}

}


#
#  Send a Withdraw Authorisation Request to MoneyBookers
#
#  pmt_id - the unique ID OpenBet gives to a payment
#
#  returns - [list 1 sid (MoneyBookers Session ID)], [list 0 err_msg] otherwise
#
proc payment_MB::_send_wtd_auth_req {pmt_id} {

	ob_log::write DEBUG {payment_MB::_send_wtd_auth_req($pmt_id)}

	variable XML_RES
	variable OB_PMT
	variable WTD_AUTH_PARENT_ELEMS

	# Before sending the request update the payment to an
	# '(I)ncomplete' status
	if {[catch [tb_db::tb_exec_qry payment_MB::update_pmt_status \
													$pmt_id \
													"I"] msg]} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Failed to execute query - $msg}
		return [list 0 INTERNAL_ERROR]
	}

	# Get subject and note translation messages, these will get displayed
	# on the MoneyBookers site for the customers transaction history
	set wtd_sub [ob_xl::sprintf $OB_PMT(lang) "MB_WTD_SUBJECT"]
	set wtd_note [ob_xl::sprintf $OB_PMT(lang) "MB_WTD_NOTE"]

	# Get the required parameters for this request
	set params_nv [list \
	                "action"      "prepare" \
	                "email"       $OB_PMT(merch_email) \
	                "password"    $OB_PMT(md5_merch_pwd) \
	                "amount"      $OB_PMT(amount) \
	                "currency"    $OB_PMT(ccy_code) \
	                "bnf_email"   $OB_PMT(mb_email_addr) \
	                "subject"     $wtd_sub \
	                "note"        $wtd_note \
	                "frn_trn_id"  $pmt_id]

	# Attempt to send the request
	set res [_send_request $params_nv [payment_MB::get_cfg wtd_api_url]]
	set res_desc [lindex $res 1]

	# Bail out if sending request failed
	if {[lindex $res 0] == 0} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Failed to send\
		   withdrawal prepartion request, $res_desc}
		return [list 0 $res_desc]
	}

	# The response given back is oddly enough in XML so we need to parse the response
	set xml_response [_parse_xml_res $res_desc $WTD_AUTH_PARENT_ELEMS]
	set xml_response_desc [lindex $xml_response 1]
	if {[lindex $xml_response 0] == 0} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Failed to process\
		   XML response, $xml_response_desc}
		return [list 0 $xml_response_desc]
	}

	# Check if we have recieved an Error
	set error_msg [_get_xml_value "error_msg"]
	if {$error_msg != ""} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Error given in\
		   response, $error_msg, updating payment status for pmt_id $pmt_id to BAD}
		payment_MB::update_pmt $pmt_id "N"
		return [list 0 $error_msg]
	}

	# Ok, we haven't received an Error, try and get the Session ID (if it has
	# been given back in the response (should always be the case if an error
	# has not been given)
	set sid [_get_xml_value "sid"]

	if {$sid == ""} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Invalid Session ID\
		   value given in response, $sid}
		return [list 0 "INVALID_RES"]
	}

	# Update the payment with it's MoneyBookers Session ID
	if {[catch [tb_db::tb_exec_qry payment_MB::update_pmt_sid \
	                                                     $sid \
	                                                     $pmt_id] msg]} {
		ob_log::write ERROR {payment_MB::send_wtd_request: Failed to execute\
		   query - $msg}
		return [list 0 INTERNAL_ERROR]
	}

	return [list 1 $sid]
}



#
#  Sends a Withdraw Execution request to MoneyBookers
#
#  pmt_id - the unique ID OpenBet gives to a payment
#
#  returns - [list 0 err_msg] on any Error encountered, [list 1 "OK"] otherwise
#
proc payment_MB::_send_exec_wtd_req {pmt_id} {

	variable XML_RES
	variable OB_PMT
	variable WTD_EXEC_PARENT_ELEMS

	# Before sending this request, update the payment to 'Unknown'
	if {[catch [tb_db::tb_exec_qry payment_MB::update_pmt_status \
		                                            $pmt_id \
		                                            "U"] msg]} {
		ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Failed to execute\
		   query - $msg}
		return [list 0 INTERNAL_ERROR]
	}

	# Get the requires parameters for the request
	set params_nv [list \
        "action"  "transfer" \
        "sid"     $OB_PMT(sid)]

	# Attempt to send the request
	set res [_send_request $params_nv [payment_MB::get_cfg wtd_api_url]]
	set res_desc [lindex $res 1]

	if {[lindex $res 0] == 0} {
		ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Failed to send\
		   withdrawal prepartion request, $res_desc}
		return [list 0 $res_desc]
	}

	# The response is in XML to we need to parse it
	set xml_response [_parse_xml_res $res_desc $WTD_EXEC_PARENT_ELEMS]
	set xml_response_desc [lindex $xml_response 1]
	if {[lindex $xml_response 0] == 0} {
		ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Failed to process\
		   XML response, $xml_response_desc}
		return [list 0 $xml_response_desc]
	}

	# Check if we have recieved an error
	set error_msg [_get_xml_value "error_msg"]

	if {$error_msg != ""} {
			ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Error given in\
			   response, $error_msg, updating payment status for pmt_id\
			   $pmt_id to BAD}

			payment_MB::update_pmt $pmt_id "N"
			return [list 0 "MoneyBookers returned - $error_msg"]
	}

	# OK, we have not got an error, try and get the payment element details
	# that should of been given from MoneyBookers in the response
	foreach elem {amount currency id status status_msg} {
		set "mb_${elem}" [_get_xml_value $elem]
	}

	# Unfortunately, we can only check the amounts if the currencies match up
	# as MoneyBookers only returns the amount withdrawn in the customers currency
	if {[string equal $OB_PMT(ccy_code) $mb_currency]} {

		if {$OB_PMT(amount) != $mb_amount} {
			ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Currency code\
			   mismatch, OB amount ($OB_PMT(amount)) does not match\
			   MoneyBookers amount ($mb_amount)}

			payment_MB::update_pmt $pmt_id "N" $mb_status "" $OB_PMT(sid)
			return [list 0 "PMT_AMOUNT_MISMATCH"]
		}
	}

	# Sanity check to ensure MoneyBooker values we've received aren't empty
	if {$mb_id == "" || $mb_status == ""} {
		ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Unvalid\
		   MoneyBookers parameters received (mb_id: $mb_id,\
		   mb_status: $mb_status}
		return [list 0 "PMT_INVALID_MB_WTD_EXEC_VALS"]
	}

	# Response looks good so lets attempt to update the payment
	set update_pmt_res [payment_MB::update_pmt $pmt_id "Y" $mb_id $mb_status]

	if {$update_pmt_res != 1} {
		ob_log::write ERROR {payment_MB::_send_exec_wtd_req: Failed to update\
		   payment (pmt_id:$pmt_id)}
		return [list 0 "FAILED_UPD_PMT"]
	}

	return [list 1 "OK"]

}

# Sends a payment message to the ticker
#
# pmt_id      - id of payment
# pmt_date    - date of payment
# type        - "WTD" for withdrawals,"DEP" for deposits
# ccy_code    - customer currenct
# amount_user - amount in customer currency
# source      - channel
# pmt_status  - status of payment
#

proc _mb_send_pmt_ticker {
	acct_id
	mb_email_addr
	pmt_id
	pmt_date
	type
	ccy_code
	amount_user
	source
	pmt_status
} {

	# Check if this message type is supported
	if {![string equal [OT_CfgGet MONITOR 0] 1] ||
	    ![string equal [OT_CfgGet PAYMENT_TICKER 0] 1]} {
		return 0
	}

	set pay_method "MB"
	set ipaddr [reqGetEnv REMOTE_ADDR]

	if {[catch {set rs [tb_db::tb_exec_qry payment_MB::get_payment_ticker_data $acct_id]} msg]} {
		ob_log::write ERROR {mb_send_pmt_ticker : Failed to execute qry\
		   payment_MB::get_payment_ticker_data : $msg}
		return 0
	}

	set cust_id       [db_get_col $rs cust_id]
	set username      [db_get_col $rs username]

	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set fname     [ob_cust::normalise_unicode [db_get_col $rs fname] 0 0]
		set lname     [ob_cust::normalise_unicode [db_get_col $rs lname] 0 0]
		set addr_city [ob_cust::normalise_unicode [db_get_col $rs addr_city] 0 0]
	}

	set postcode      [db_get_col $rs addr_postcode]
	set country_code  [db_get_col $rs country_code]
	set email         [db_get_col $rs email]
	set reg_date      [db_get_col $rs cust_reg_date]
	set reg_code      [db_get_col $rs code]
	set notifiable    [db_get_col $rs notifyable]
	set acct_balance  [db_get_col $rs balance]
	set addr_country  [db_get_col $rs addr_country]
	set exch_rate     [db_get_col $rs exch_rate]

	db_close $rs

	set bank_name "N/A"
	set pmt_sort [expr {[string equal $type "WTD"]?"W":"D"}]

	# convert user amount into system ccy
	set amount_sys [format "%.2f" [expr {$amount_user / $exch_rate}]]

	if {[catch {set result [MONITOR::send_pmt_non_card\
	                                 $cust_id\
	                                 $username\
	                                 $fname\
	                                 $lname\
	                                 $postcode\
	                                 $email\
	                                 $country_code\
	                                 $reg_date\
	                                 $reg_code\
	                                 $notifiable\
	                                 $acct_id\
	                                 $acct_balance\
	                                 "$ipaddr-${addr_country}"\
	                                 "$ipaddr-${addr_city}"\
	                                 $pay_method\
	                                 $ccy_code\
	                                 $amount_user\
	                                 $amount_sys\
	                                 $pmt_id\
	                                 $pmt_date\
	                                 $pmt_sort\
	                                 $pmt_status\
	                                 $mb_email_addr\
	                                 $bank_name\
	                                 $source]} msg]} {
		ob_log::write ERROR {_mb_send_pmt_ticker: Failed to send
		payment monitor message : $msg}
		return 0
	}
	return $result
}



#  Parses XML responses given back from MoneyBookers. Since the format of
#  the responses are inconsistant, a variable ('patent_elems') is provided
#  to tell the function parent element it should expect from a particular
#  response. The response info is then loaded into the 'XML_RES' variable
#
#  xml          - the XML given in the response
#  parent_elems - a list of valid parent elements that should be expected to be
#                 in the response (at least one element in the list)
#
#  returns - [list 0 INVALID_XML] on any Error encountered,
#            [list 1 VALID_XML] otherwise
#
proc payment_MB::_parse_xml_res {xml parent_elems} {

	variable XML_RES

	catch {array unset XML_RES}

	# Attempt to parse the incoming XML
	if {[catch {set doc [dom parse -simple $xml]} msg]} {
		ob_log::write ERROR {payment_MB::_parse_xml_res: Unable to parse XML : $msg}
		return [list 0 "INVALID_XML"]
	}

	# For each valid parent element that could be given in the response,
	# attempt to it's child elements data and store in in the 'XML_RES' variable
	foreach parent $parent_elems {
		# Get the child nodes of the document element.
		set parent_node [$doc getElementsByTagName $parent]
		if {$parent_node == ""} {
			continue
		}

		if {[catch {set child_nodes [$parent_node childNodes]} msg]} {
			_destroy_message $doc
			return [list 0 "INVALID_XML"]
		}

		# Try to get all the child elements data associated with the parent
		foreach node $child_nodes {

			set elem_name [string tolower [$node nodeName]]

			if {[catch {set elem_value [[$node selectNodes text()] data]} msg]} {
				ob_log::write ERROR {payment_MB::_parse_xml_res: Invalid\
				   element value received for $elem_name - $msg}
				_destroy_message $doc
				return [list 0 "INVALID_XML"]
			}
			set XML_RES($elem_name) $elem_value

			# If we have received an error message then return
			# immediately so the error can be dealt with. No
			# point going through other parent elements in this case.
			if {[string equal $elem_name {error_msg}]} {
				_destroy_message $doc
				return [list 1 VALID_XML]
			}
		}
	}

	_destroy_message $doc

	return [list 1 VALID_XML]
}



#
#
#  Gets the MoneyBookers value for a particular XML element
#
#  elem_name - the name of the XML element
#
#  returns - the value of the XML element ('' if it doesn't exist)
#
proc payment_MB::_get_xml_value {elem_name} {

	variable XML_RES

	if {![info exists XML_RES($elem_name)]} {
		ob_log::write DEBUG {payment_MB::_get_xml_value: Value for element\
		   $elem_name does not exist}
		set XML_RES($elem_name) {}
	}

	return $XML_RES($elem_name)
}



#
#
#  Remove all DOM tree memory associated with the passed in message.
#  Node can be any node in the DOM tree - the entire document
#  will be freed.
#
#  node - the DOM tree node that needs destroying
#
proc payment_MB::_destroy_message {node} {
	catch {
		set od [$node ownerDocument]
		$od delete
	}
}
