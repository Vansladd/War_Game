#------------------------------------------------------------------------------
# $Id:
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#------------------------------------------------------------------------------

# SOAP Interface for Click2Pay payment gateway functionality.
# NB - There are no special SOAP libraries being used in this file. The request
#      is built in the same manner as an XML message. The response is then
#      parsed using tdom.
#      See ob_click2pay::_msg_pack, ob_click2pay::_msg_send,
#          ob_click2pay::_msg_unpack
#
# Required Configuration:
#   FUNC_CLICK2PAY
#   CLICK2PAY_PENDING_WITHDRAWALS
#   CLICK2PAY_PRODUCTID
#
# Configuration - optional:
#   CLICK2PAY_CCYS
#   PMT_C2P_ALLOW_DIFF_UNAME - This determines if a Click2Pay CPM can be used
#                              immediately on registeration even if the
#                              Click2Pay Username differs to the customers
#                              email address on OpenBet. If switched off,
#                              the CPM should be suspended until it is has been
#                              verified.
#
#
# Optional Configuration:
#
# Synopsis:
#
# Procedures:

#   ob_click2pay::init
#   ob_click2pay::_prep_qrys
#   ob_click2pay::c2p_get_cpm_details
#   ob_click2pay::c2p_get_pan
#   ob_click2pay::verify_pan_not_used
#   ob_click2pay::do_registration
#   ob_click2pay::make_click2pay_transaction
#   ob_click2pay::make_click2pay_call
#   ob_click2pay::_transaction
#   ob_click2pay::_check
#   ob_click2pay::_msg_pack
#   ob_click2pay::_msg_send
#   ob_click2pay::_msg_unpack
#   ob_click2pay::encrypt_decrypt_pan
#   ob_click2pay::replace_midrange
#   ob_click2pay::_check_prev_pmt
#   ob_click2pay::_upd_pmt_status
#   ob_click2pay::_get_resp_val
#   ob_click2pay::remove_cpm
#

#
# requires payment_gateway.tcl
#


namespace eval ob_click2pay {

	variable INIT
	set INIT 0

	variable CFG
	variable CLICK2PAY
	variable PMG
	variable CLICK2PAY_RESP

	variable CLICK2PAY_STATUS_RESPONSE_TABLE

}


#
# One time initialisation.
# Set up error code lookup array and call query initialisation.
#
#  ob_click2pay::init
#
proc ob_click2pay::init {} {

	variable INIT
	variable CLICK2PAY_STATUS_RESPONSE_TABLE
	variable CFG

	if {$INIT} { return }

	ob::log::write INFO {ob_click2pay::init - Initialising Click2Pay}

	package require net_socket
	package require tdom
	package require util_appcontrol

	#CLICK2PAY_STATUS_RESPONSE_TABLE error codes
	#000      - Successful transaction
	#100-199  - First verification checked failed because entered data is invalid
	#200-299  - Second verification check failed due to technical error or protection
	#300-399  - gateway verification check - returned values do not allow for further processing
	#400-499  - verification based on internal rules
	#500-599  - gateway response relating to past operations
	#900-999  - problems which require manual interaction

	#CLICK2PAY_STATUS_RESPONSE_TABLE error codes
	array set CLICK2PAY_STATUS_RESPONSE_TABLE {
		 000 C2P_PMT_OK
		  1 C2P_ERR_UNKNOWN
		  2 C2P_ERR_NOCONTACT
		100 C2P_INVALID_MID
		101 C2P_INVALID_USERNAME
		102 C2P_INVALID_PAN
		103 C2P_INVALID_AMT
		104 C2P_INVALID_CURR
		105 C2P_INVALID_PRODUCTID
		106 C2P_INVALID_MODE
		107 C2P_INVALID_IP_ADDR
		109 C2P_INVALID_PMT_DETAIL_ID
		200 C2P_INVALID_USER_PAN
		201 C2P_USERNAME_NOT_EXIST
		203 C2P_ACCT_LOCKED
		204 C2P_ACCT_CLOSED
		205 C2P_AUTH_DECL
		206 C2P_ACCT_INACTIVE
		207 C2P_ACCT_RISK
		208 C2P_USER_CALLBACK
		305 C2P_DEBIT_DECL_BY_BANK
		306 C2P_AMT_EXCEEDS_DEBIT_LIMIT
		307 C2P_NO_INSTANT_FUND
		308 C2P_EFT_ACCT_NOT_ACTIVATED
		400 C2P_AMT_CREDIT_SVA
		401 C2P_AMT_EXCEEDS_CREDIT_LIMIT
		500 C2P_RTN_DECL_NO_REF_ID
		502 C2P_ADJ_DECL_NO_REF_ID
		503 C2P_CANCL_DECL_NO_REF_ID
		504 C2P_CANCL_DECL_TX_ISSUE
		505 C2P_CANCL_DECL_TIME_ISSUE
		506 C2P_RTN_DECL_INVALID_REF_ID
		507 C2P_ADJ_DECL_INVALID_REF_ID
		508 C2P_WTD_DECL_AMT_EXCEEDS_LIMIT
		509 C2P_WTD_DECL_PMT_NOT_ACTIVATED
		800 C2P_NO_PMT_MTHD_INSTANT_FUND
		900 C2P_TECHNICAL_PROBLEM
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CFG(pmt_receipt_format) 0
		set CFG(pmt_receipt_tag)    ""
	}

	ob_click2pay::_prep_qrys

	set INIT 1
}


#
# Private procedure to prepare the queries.
#
proc ob_click2pay::_prep_qrys {} {

	ob_db::store_qry ob_click2pay::cpm_ins_c2p {
    	execute procedure pCPMInsC2P (
			p_cust_id          = ?,
			p_oper_id          = ?,
			p_auth_wtd         = 'Y',
			p_auth_dep         = 'Y',
			p_transactional    = 'Y',
			p_enc_pan          = ?,
			p_username         = ?,
			p_allow_duplicates = ?,
			p_cpm_change	   = ?,
			p_strict_check     = ?
		)
	}

	ob_db::store_qry ob_click2pay::c2p_get_cpm_details {
		select
			c2p.cpm_id,
			c2p.cust_id,
			c2p.username,
			c2p.enc_pan,
			a.acct_id,
			a.ccy_code,
			a.balance,
			p.oper_id,
			p.pay_mthd,
			p.status,
			c.country_code,
			UPPER(c.lang) lang
		from
			tCPMC2P      c2p,
			tAcct        a,
			tCustPayMthd p,
			tCustomer    c
		where
			c2p.cpm_id  = p.cpm_id  and
			p.cust_id = a.cust_id and
			a.cust_id = c.cust_id and
			p.status  = 'A' and
			p.cust_id = ? and
			p.cpm_id = ?
	}

	ob_db::store_qry ob_click2pay::c2p_get_pan_active {
		select
			c.cpm_id
		from
			tCPMC2P c,
			tCustPayMthd cpm
		where
			c.enc_pan = ? and
			c.cpm_id <> ? and
			c.cpm_id = cpm.cpm_id and
			cpm.pay_mthd = 'C2P' and
			cpm.status <> 'X'
	}

	ob_db::store_qry ob_click2pay::c2p_get_pan {
		select
			enc_pan
		from
			tCPMC2P
		where
			cpm_id = ?
	}

	ob_db::store_qry ob_click2pay::pmt_ins_c2p {
		execute procedure pPmtInsC2P (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_transactional  = 'Y',
			p_oper_id        = ?,
			p_commission     = ?,
			p_unique_id      = ?,
			p_j_op_type      = ?,
			p_extra_info     = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?,
			p_overide_min_wtd= ?,
			p_call_id = ?
		)
	}

	ob_db::store_qry ob_click2pay::upd_pmt_unknown_status {
		update
			tPmt
		set
			status = 'U'
		where
			pmt_id = ?
	}

	ob_db::store_qry ob_click2pay::pmt_upd_c2p {
		execute procedure pPmtUpdC2P (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_j_op_type = ?,
			p_gw_uid = ?,
			p_gw_ret_code = ?,
			p_gw_ret_msg = ?,
			p_auth_code = ?,
			p_extra_info = ?
		)
	}

	ob_db::store_qry ob_click2pay::c2p_get_pmt_details {
		select
			p.ipaddr,
			c2p.ref_no
		from
			tPmt p,
			tPmtC2P c2p
		where
			p.pmt_id = ? and
			p.pmt_id = c2p.pmt_id
	}

	ob_db::store_qry ob_click2pay::update_pg_info {
		update
			tPmtC2P
		set
			pg_acct_id = ?,
			pg_host_id = ?
		where
			pmt_id = ?
	}

	ob_db::store_qry ob_click2pay::cancel_pay_mthd {
		update
			tCustPayMthd
		set
			status = 'X'
		where
			cpm_id=?
	}
}


#
# Get Click2Pay pay method details from DB.
#
# cust_id    - the customer unique id
#
# return     - on success a list with the format {1 cpm_id}
#              1 - success in retrieving Click2Pay payment method details
#              cpm_id - the Click2Pay customer pay method unique id
#            - on failure a list with the following format {0 msg}
#              0 - failura to retrieve the Click2Pay pay method details
#              msg - an error message
#
proc ob_click2pay::c2p_get_cpm_details {cust_id cpm_id} {

	variable CLICK2PAY

	ob::log::write DEBUG {ob_click2pay::c2p_get_cpm_details($cust_id)}

	if {[catch {set rs [ob_db::exec_qry ob_click2pay::c2p_get_cpm_details $cust_id $cpm_id]} msg] } {
		ob_log::write ERROR {ob_click2pay::get_c2p_detail: Problem retrieving customer account info for cust_id=$cust_id: $msg}
		catch {db_close $rs}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		catch {db_close $rs}
		ob_log::write INFO {ob_click2pay::get_c2p_cpm: No active Click2Pay pay method returned}
		return [list 0 "No active Click2Pay pay method"]
	} elseif {$nrows > 1} {
		#Shouldn't happen(!)
		ob_log::write ERROR {ob_click2pay::get_c2p_cpm: Returned $nrows click2pay cpm for cust_id=$cust_id}
		return [list 0 "Returned $nrows click2pay cpm for cust_id=$cust_id"]
	} else {
		catch {unset CLICK2PAY}

		set CLICK2PAY(req_id) [reqGetId]
		set CLICK2PAY(cust_id) $cust_id
		foreach col {cpm_id username acct_id cpm_id lang ccy_code balance oper_id pay_mthd status country_code} {
			set CLICK2PAY($col) [db_get_col $rs 0 $col]
		}
		set CLICK2PAY(pan)        [encrypt_decrypt_pan [db_get_col $rs 0 enc_pan] "decrypt"]

		ob_db::rs_close $rs
		return [list 1 $CLICK2PAY(cpm_id)]
	}
}


#
# Get Click2Pay pay method PAN from DB.
#
# cpm_id   - the unique customer payment id
#
# return   - on success a list with the format {1 enc_pan}
#            1 - success in retriving the pan
#            enc_pan - encrepted personla account number
#          - on failure a list with the following format {0 msg}
#            0   - failura retrieve pan
#            msg - reason of failure
#
proc ob_click2pay::c2p_get_pan {cpm_id} {

	ob::log::write DEBUG {ob_click2pay::c2p_get_pan($cpm_id)}

	if {[catch {set rs [ob_db::exec_qry ob_click2pay::c2p_get_pan $cpm_id]} msg] } {
		ob_log::write ERROR {ob_click2pay::c2p_get_pan: Problem retrieving PAN for cpm_id=$cpm_id: $msg}
		catch {db_close $rs}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		catch {db_close $rs}
		return [list 0 "No Click2Pay pay method found"]
	} elseif {$nrows > 1} {
		#Shouldn't happen(!)
		ob_log::write ERROR {ob_click2pay::c2p_get_pan Returned $nrows click2pay cpm for cpm_id=$cpm_id}
		catch {db_close $rs}
		return [list 0 "Returned $nrows click2pay cpm for cpm_id=$cpm_id"]
	} else {
		set enc_pan [db_get_col $rs 0 enc_pan]
		ob_db::rs_close $rs
		return [list 1 $enc_pan]
	}

}


#
# Checks if the passed Personal Account Number (PAN) is not active on any account
#
# enc_pna  - Click2Pay's personal account number (PAN) encrepted
# cpm_id   - the custoemr pay method unique id
#
# return   - on success a list with the format {1 OK}
#            1 - indicates that PAN is not registered on any account
#          - on failure a list with the following format {0 msg}
#            0 - indicates that pan is already registered
#
proc ob_click2pay::verify_pan_not_used {enc_pan cpm_id} {

	ob::log::write DEBUG {ob_click2pay::verify_pan_not_used($enc_pan,$cpm_id)}

	if {[catch {
		set rs [ob_db::exec_qry ob_click2pay::c2p_get_pan_active $enc_pan $cpm_id]
	} msg] } {
		ob_log::write ERROR {ob_click2pay::verify_pan_not_used: Failed to execute c2p_get_pan_active: $msg}
		return [list 0 "Failed to execute c2p_get_pan_active: $msg"]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		ob_db::rs_close $rs
		ob_log::write INFO {ob_click2pay::verify_pan_not_used: PAN is not active or suspanded}
		return [list 1 "OK"]
	} else {
		ob_log::write INFO {ob_click2pay::verify_pan_not_used: PAN is already active or suspanded}
		ob_db::rs_close $rs
		return [list 0 "PAN is already active or suspanded (this or different account)"]
	}
}


#
# Performs Click2Pay registration
#
# cust_id    - the customer id
# pan        - Click2Pay personal account number (PAN)
# username   - Click2Pay user name (e-mail address)
# oper_id    - (optional) the operator id
# allow_duplicate (optional) - whether the duplicates are allowed
# cpm_change - (optional) - whether it is change or not
#
# return      - on success a list with the format {1 cpm_id}
#               1      - indicates a successful registration
#               cpm_id - is the tCPMC2P.pmd_id of the successfully registered click2pay pay method
#             - on failure a list with the following format {0 msg}
#               0    - indicates failure to perform the registration
#               msg  - an error message that indicates what went wrong with the registration
#
proc ob_click2pay::do_registration {
	cust_id
	pan
	username
	{oper_id -1}
	{allow_duplicate "N"}
	{cpm_change "N"}
	{strict_check "Y"}
} {
	variable CLICK2PAY

	ob::log::write DEBUG {ob_click2pay::do_registration($cust_id,$pan,$username,\
		$oper_id,$allow_duplicate,$cpm_change)}

	set enc_pan [encrypt_decrypt_pan $pan "encrypt"]

	if {[catch {
		set rs [
			ob_db::exec_qry ob_click2pay::cpm_ins_c2p\
				$cust_id\
				$oper_id\
				$enc_pan\
				$username\
				$allow_duplicate\
				$cpm_change\
				$strict_check
		]
	} msg]} {
		ob::log::write ERROR {ob_click2pay::do_registration: Failed to insert Click2Pay method - $msg}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		set msg "Rows returned does not equal 1. Returned $nrows rows for cust_id $cust_id"
		ob_log::write ERROR {ob_click2pay::do_registration:$msg}
		ob_db::rs_close $rs
		return [list 0 $msg]
	}

	set cpm_id     [db_get_coln $rs 0 0]
	set cpm_status [db_get_coln $rs 0 1]
	ob_db::rs_close $rs

	if {$strict_check == "N" && $cpm_status == "S"} {
		set msg "Inserted a Click2Pay method with cpm_id = $cpm_id, but it was immmediately suspended"
		ob::log::write INFO {ob_click2pay::do_registration: $msg}
		return [list 2 $msg]
	}

	ob::log::write INFO {ob_click2pay::do_registration: Successfully inserted Click2Pay method cpm_id = $cpm_id}

	return [list 1 $cpm_id]
}


#
# This is the main function called by all applications for performing standard deposits
# and withdrawals from an openbet account to an active Click2Pay account.
# Makes call to payment gateway to choose Click2Pay
#
# cust_id                 - customer's unique id
# acct_id                 - customer account's unique id
# oper_id                 - operator id
# unique_id               - a numeric code that uniquely identifies the transaction initiation,
#                           this prevents the same request being processed twice.
# pay_sort                - payment sort (W=Withraw, D=Deposit)
# amount                  - amount to deposit or withraw
# cpm_id                  - customer's payment method unique id
# source                  - source (the channel of the transaction)
# ccy_code                - currency code
# auth_pending_wtd        - (optional, default 0) flag (true or false) determines if this is a new payment being inserted
#                           (set to 0) or the payment has already been previously inserted and a withdrawal is being
#                           authorized (set to 1).
# auth_pending_wtd_pmt_id - (optional) the transaction (withrawal) unique id that to be authorised
# extra_info              - (optional) misc free text (up to 160 chars) which will be recorded against the
#                           payment when stored in the database
# comm_list               - (optional) list of commission amounts, 3 element list containing
#                           (commission, payment_amount, tPmt_amount)
# min_overide            - overide the minimum withdrawal limit should only be used when
#                           multiple method withdrawal flow forces
# call_id                - (optional) if this is a telebetting transaction, the tCall.call_id for this
#
# return                  - on success a list with the format {1 pmt_id}
#                           1      - indicates a successful transaction
#                           pmt_id - is the tPmt.pmd_id of the successfully recorded transaction
#
#                         - on failure a list with the following format {0 error_code}
#                           0           - indicates failure to perform the transaction in full
#                           error_code  - one of the standard payment error codes in CLICK2PAY_STATUS_RESPONSE_TABLE,
#                                         or if the error is unexpected then errors generated by tcl
#
proc ob_click2pay::make_click2pay_transaction {
	cust_id
	acct_id
	oper_id
	unique_id
	pay_sort
	amount
	cpm_id
	source
	ccy_code
	{auth_pending_wtd "0"}
	{auth_pending_wtd_pmt_id ""}
	{extra_info ""}
	{comm_list {}}
	{pan_end ""}
    {min_overide "N"}
	{call_id ""}
} {

	ob::log::write DEBUG {ob_click2pay::make_click2pay_transaction(\
		$cust_id,$acct_id,$oper_id,$unique_id,$amount,$cpm_id,$source,\
		$ccy_code,$auth_pending_wtd,$auth_pending_wtd_pmt_id,$extra_info,\
		$comm_list,$min_overide,$call_id}

	variable INIT
	variable CLICK2PAY
	variable CFG

	if {!$INIT} {
		ob_click2pay::init
	}

	# OVS check.
	if {[OT_CfgGet FUNC_OVS 0] && [OT_CfgGet FUNC_OVS_VERF_C2P_CHK 1] && $auth_pending_wtd == 0} {
		set chk_resp [verification_check::do_verf_check \
			"C2P" \
			$pay_sort \
			$acct_id]

		if {![lindex $chk_resp 0]} {
			return [list 0 [lindex $chk_resp 1]]
		}
	}

	# If commission list is empty then initialize it with 0 commission
	if {$comm_list == {}} {
		set comm_list [list 0 $amount $amount]
	}

	#
	# get the commission, payment amount and tPmt amount from the list
	#
	set commission  [lindex $comm_list 0]
	set amount      [lindex $comm_list 1]
	set tPmt_amount [lindex $comm_list 2]

	catch {unset CLICK2PAY}

	set cpm_result [ob_click2pay::c2p_get_cpm_details $cust_id $cpm_id]

	if {![lindex $cpm_result 0]} {
		ob::log::write ERROR {ob_click2pay::make_click2pay_transaction: Failed to get Click2Pay payment method details}
		return [list 0 C2P_REMOVED_SUSPENDED]

	} elseif {[lindex $cpm_result 1] != $cpm_id} {
		#active click2pay retrieved is not the same click2pay we are trying to use
		ob::log::write ERROR {ob_click2pay::make_click2pay_transaction: Click2Pay not valid (removed or suspended)}
		return [list 0 C2P_REMOVED_SUSPENDED]
	}

	#Do OVS Age checking for UK Customers
	if { [OT_CfgGet FUNC_OVS 0] && [OT_CfgGet FUNC_OVS_CHK_ON_C2P_PMT 0] && $CLICK2PAY(country_code) == "UK"} {

		# Check if customer DOB exists in the database
		if { [OT_CfgGet FUNC_OVS_CHK_DOB_EXISTS 0]} {
			set dob_exists [verification_check::chk_cust_dob_exists $cust_id]
			if {[lindex $dob_exists 0] == 0} {
				return $dob_exists
			}
		}
		set prev_pmt [ob_click2pay::_check_prev_pmt $cust_id $CLICK2PAY(pan)]
		if {$prev_pmt == 0} {
			if {[OT_CfgGet FUNC_OVS_USE_SERVER 0]} {
				if {[OT_CfgGet FUNC_OVS_DO_AGE_CHECK 0]} {
					set ovs_age_result [verification_check::do_verification_via_server $cust_id "AGE"]
					if {[lindex $ovs_age_result 0] != 1} {
						return $ovs_age_result
					}
				}
			}
		}
	}

	# PAN check.

	if {[OT_CfgGet FUNC_PAN_VERF_C2P_CHK 0]} {
		# Validate that the PAN end given matches the payment method PAN

		if {[lsearch \
			[OT_CfgGet FUNC_PAN_VERF_C2P_CHK_SORTS\
				[list W D]] $pay_sort] > -1} {
				if {[string length $pan_end] != \
					[OT_CfgGet C2P_PAN_VERF_CHK_LENGTH 4]} {
					ob_log::write ERROR {ob_click2pay::make_click2pay_transaction \
										Incorrect number of chars for PAN check: $pan_end}
					return [list 3 ERR_C2P_PAN_INCORRECT_LENGTH]
				}

				if {![regexp [subst {$pan_end$}] $CLICK2PAY(pan)]} {
					ob_log::write ERROR \
						{ob_click2pay::make_click2pay_transaction \
										Incorrect PAN entered: $pan_end}
					return [list 3 ERR_C2P_PAN_INCORRECT]
				}
		}
	}

	set CLICK2PAY(req_id)       [reqGetId]

	set CLICK2PAY(cust_id)        $cust_id
	set CLICK2PAY(acct_id)        $acct_id
	set CLICK2PAY(oper_id)        $oper_id
	set CLICK2PAY(unique_id)      $unique_id
	set CLICK2PAY(pay_sort)       $pay_sort
	set CLICK2PAY(cpm_id)         $cpm_id
	set CLICK2PAY(source)         $source
	set CLICK2PAY(ccy_code)       $ccy_code

	# ensuring that amount always has 2 dp (especially when comm_list is not provided)
	set CLICK2PAY(amount)         [format {%0.2f} $amount]
	set CLICK2PAY(tPmt_amount)    [format {%0.2f} $tPmt_amount]
	set CLICK2PAY(commission)     $commission

	set CLICK2PAY(transactional)  "Y"
	set CLICK2PAY(pay_mthd)       "C2P"
	set CLICK2PAY(j_op_type)      ""
	set CLICK2PAY(gw_auth_code)   ""
	set CLICK2PAY(extra_info)     $extra_info
	set CLICK2PAY(receipt_format) $CFG(pmt_receipt_format)
	set CLICK2PAY(receipt_tag)    $CFG(pmt_receipt_tag)
	set CLICK2PAY(min_overide)    $min_overide
	set CLICK2PAY(call_id)        $call_id


	#The parameter auth_pending_wtd determines if this is a new payment being inserted or if a withdrawal
	#is being authorized. If it is set to 1 this means it has already been inserted previously.
	if {$auth_pending_wtd == 0} {
		ob::log::write INFO {ob_click2pay::make_click2pay_transaction: Inserting Click2Pay payment in Pending status}

		#Insert Click2Pay cpm with a status of Pending
		if {[catch {
				set rs [ob_db::exec_qry ob_click2pay::pmt_ins_c2p \
					$CLICK2PAY(acct_id) \
					$CLICK2PAY(cpm_id) \
					$CLICK2PAY(pay_sort) \
					$CLICK2PAY(tPmt_amount) \
					[reqGetEnv REMOTE_ADDR] \
					$CLICK2PAY(source) \
					$CLICK2PAY(oper_id) \
					$CLICK2PAY(commission) \
					$CLICK2PAY(unique_id) \
					$CLICK2PAY(j_op_type) \
					$CLICK2PAY(extra_info) \
					$CLICK2PAY(receipt_format) \
					$CLICK2PAY(receipt_tag) \
					$CLICK2PAY(min_overide) \
					$CLICK2PAY(call_id)]
			} msg]} {
			ob::log::write ERROR "Error: $msg"

	 		if {[regexp {AX5006} [lindex $msg 2]]} {
				set err INSUFFICIENT_FUNDS
			} elseif {[regexp {AX5010} [lindex $msg 2]]} {
				set err CURR_SUSPENDED
			} elseif {[regexp {AX5004} [lindex $msg 2]]} {
				set err ACCOUNT_NOT_FOUND
			} elseif {[regexp {AX5002} [lindex $msg 2]]} {
				set err ACCOUNT_CLOSED
			} else {
				set err C2P_ERR_UNKNOWN
			}
			return [list 0 "$err"]
		}

		set CLICK2PAY(pmt_id) [db_get_coln $rs 0 0]
	} else {
		set CLICK2PAY(pmt_id) $auth_pending_wtd_pmt_id
		ob::log::write INFO {ob_click2pay::make_click2pay_transaction: Authorising Click2Pay payment \
			pmt_id=$CLICK2PAY(pmt_id)}
	}

	#fraud checking for withdrawal payment
	if {$pay_sort == "W" && $auth_pending_wtd != 1} {
		set process_pmt [ob_pmt_validate::chk_wtd_all\
							$CLICK2PAY(acct_id)\
							$CLICK2PAY(pmt_id)\
							"C2P"\
							"----"\
							$CLICK2PAY(tPmt_amount)\
							$ccy_code]
		if {!$process_pmt} {
			# We will need to check the payment for potential fraud
			# For now we will return this as an fraud
			set result "C2P_PMT_OK"
			return [list 1 $CLICK2PAY(pmt_id) $result]
		}
	}

	#With the config turned on, withdrawals are not sent to Click2Pay. They are entered in a Pending status
	#and authorized (sent to Click2Pay) via the admin screens
	if {$pay_sort == "W" && $auth_pending_wtd == 0 && [OT_CfgGet FUNC_C2P_WTD_PENDING 0]} {
		ob::log::write INFO {ob_click2pay::make_click2pay_transaction: Withdrawal entered in Pending status and needs to be Authorized}
		return [list 1 $CLICK2PAY(pmt_id) C2P_PMT_OK]
	}

	#Chooses the Click2Pay payment gateway
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param CLICK2PAY]

	if {[lindex $pg_result 0] == 0} {

		set msg [lindex $pg_result 1]
		ob_log::write ERROR {ob_click2pay::make_click2pay_transaction: Transaction failed on pg_result - $msg}

		#update payment as a failed payment
		set CLICK2PAY(status) N

		# update the payment table as failed payment
		set pmt_status_res [_upd_pmt_status $CLICK2PAY(pmt_id) \
		                                    $CLICK2PAY(status) \
		                                    $CLICK2PAY(oper_id) \
		                                    $CLICK2PAY(pay_sort) \
		                                    $CLICK2PAY(extra_info)]
		if {![lindex $pmt_status_res 0]} {
			set msg [lindex $pmt_status_res 1]
			ob::log::write ERROR {ob_click2pay::make_click2pay_transaction: Failed to update failed payment status - $msg}
		}
		return [list 0 C2P_FAILED_PMG_RULES]
	}

	if {[catch {
		set rs [ob_db::exec_qry ob_click2pay::c2p_get_pmt_details $CLICK2PAY(pmt_id)]
	} msg ]} {
		ob::log::write ERROR {ob_click2pay::make_click2pay_transaction: Transaction failed - $msg}
		return [list 0 C2P_ERR_UNKNOWN]
	}

	set CLICK2PAY(apacs_ref) [db_get_col $rs 0 ref_no]
	set CLICK2PAY(ipaddr)    [db_get_col $rs 0 ipaddr]

	ob_db::rs_close $rs

	# Contact payment gateway and make the transaction
	set result [payment_gateway::pmt_gtwy_do_payment CLICK2PAY]
	ob_log::write INFO {ob_click2pay::make_click2pay_transaction: Transaction result = $result}

	if {$result != "C2P_PMT_OK"} {
		return $result
	}

	return [list 1 $CLICK2PAY(pmt_id) $result]


}


#
# Procedure to carry out the transaction
#
# ARRAY   - array holding details of transaction
#
proc ob_click2pay::make_click2pay_call {ARRAY} {

	ob::log::write DEBUG {ob_click2pay::make_click2pay_call}

	upvar $ARRAY PMT

	variable CLICK2PAY_STATUS_RESPONSE_TABLE
	variable CFG
	variable CLICK2PAY

	# payment gateway values
	set CFG(url)      $PMT(host)
	set CFG(timeout)  $PMT(resp_timeout)
	set CFG(client)   $PMT(client)
	set CFG(password) $PMT(password)

	foreach {status retcode} [_transaction \
		$PMT(cust_id) \
		$PMT(apacs_ref) \
		$PMT(pay_sort) \
		$PMT(tPmt_amount) \
		$PMT(ccy_code) \
		$PMT(mid) \
		$PMT(gw_auth_code)] {}


	set PMT(status)        [expr {$status == "OK" ? "Y" : "N"}]
	set PMT(auth_time)     [clock format [clock seconds] -format "%H:%M:%S"]
	set PMT(gw_ret_code)   $retcode
	set PMT(gw_uid)        [_get_resp_val transactionId]

	set PMT(gw_ret_msg) [join [list \
			$PMT(gw_ret_code) \
			$PMT(auth_time) \
			$PMT(gw_uid)] :]

	if {$status != "OK"} {
		ob_log::write INFO {ob_click2pay::make_click2pay_call: Transaction failed: $retcode}

		set pmt_status_res [_upd_pmt_status $PMT(pmt_id) \
											$PMT(status) \
											$PMT(oper_id) \
											$PMT(pay_sort) \
											$PMT(extra_info) \
											$PMT(gw_uid) \
											$PMT(gw_ret_code) \
											$PMT(gw_ret_msg)]

		if {![lindex $pmt_status_res 0]} {
			set msg [lindex $pmt_status_res 1]
			ob::log::write ERROR {ob_click2pay::make_click2pay_call: Failed to update failed payment status - $msg}
		}

		if {[info exists CLICK2PAY_STATUS_RESPONSE_TABLE($retcode)]} {
			return [list 0 $CLICK2PAY_STATUS_RESPONSE_TABLE($retcode)]
		} else {
			return [list 0 C2P_ERR_UNKNOWN]
		}
	}

	set gw_ret_code [list 0 C2P_ERR_UNKNOWN]

	if {[info exists CLICK2PAY_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))]} {
		set gw_ret_code $CLICK2PAY_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))
	}

	ob::log::write INFO {ob_click2pay::make_click2pay_call::Updating payment status to $PMT(status) for pmt_id $PMT(pmt_id)}

	set pmt_status_res [_upd_pmt_status $PMT(pmt_id) \
										$PMT(status) \
										$PMT(oper_id) \
										$PMT(pay_sort) \
										$PMT(extra_info) \
										$PMT(gw_uid) \
										$PMT(gw_ret_code) \
										$PMT(gw_ret_msg)]

	if {![lindex $pmt_status_res 0]} {
		set msg [lindex $pmt_status_res 1]
		ob::log::write ERROR {ob_click2pay::make_click2pay_call: Failed to update payment status for pmt_id  $PMT(pmt_id) - $msg}
		return [list 0 C2P_ERR_UNKNOWN]
	}

	return $gw_ret_code
}


#
# Private procedure to carry out steps for contacting Click2Pay
#
# cust_id      - unique ID of customer
# apacs_ref    - unique reference number
# pay_sort     - type of transaction (D, W)
# amount       - amount to be dep/wth
# ccy_code     - currency
# bcsig        - merchand ID
# gw_auth_code - (optional) authorisation code
#
#
proc ob_click2pay::_transaction {
	cust_id
	apacs_ref
	pay_sort
	amount
	ccy_code
	bcsig
	{gw_auth_code ""}
} {

	ob::log::write DEBUG {ob_click2pay::_transaction($cust_id,$apacs_ref,$pay_sort,$amount,$ccy_code,$bcsig,$gw_auth_code)}

	variable CLICK2PAY

	switch -- $pay_sort {
		"D" {
			set mode "DEBIT"
		}
		"W" {
			set mode "CREDIT"
		}
		default {
			ob::log::write ERROR "CLICK2PAY::_transaction: pay sort $pay_sort is not a valid type"
			return [list "NOK" 1]
		}
	}

	# amount passed must have 2 dp otherwise wrong amount will
	# be passed to click2pay
	if {!([string is double -strict $amount] && [regexp {\.[0-9]{2}$} $amount])} {
		ob_log::write ERROR {ob_click2pay::_transaction: wrong amount $amount}
		return [list "NOK" 1]
	}

	#This is a numeric identifier unique to the CLICK2PAY service the merchant has purchased.
	set productId [OT_CfgGet CLICK2PAY_PRODUCTID ""]

	# Mandatory Click2Pay parameters
	set CLICK2PAY(merchantId)      $bcsig
	set CLICK2PAY(userName)        $CLICK2PAY(username)
	# Amount for Click2Pay has no decimal point, e.g. 1248 meaning 12.48
	set CLICK2PAY(amount)          [string map {"." ""} $amount]
	set CLICK2PAY(curCode)         $ccy_code
	set CLICK2PAY(mode)            $mode
	set CLICK2PAY(overdraw)        "false"
	set CLICK2PAY(productId)       $productId
	set CLICK2PAY(ip)              $CLICK2PAY(ipaddr)
	set CLICK2PAY(merchantTransId) $apacs_ref

	# validate input parameters
	foreach {status ret} [ob_click2pay::_check] {
		if {$status == "ERR"} {
			ob_log::write ERROR {CLICK2PAY::_transaction _check failed: $ret}
			return [list "NOK" 1]
		}
	}

	# pack the message
	foreach {status request} [ob_click2pay::_msg_pack] {
		if {$status == "ERR"} {
			ob_log::write INFO {ob_click2pay::_transaction _msg_pack failed: $request}
			return [list "NOK" 1]
		}
	}

	set merchant_id $CLICK2PAY(merchantId)
	set pan         $CLICK2PAY(pan)

	set CLICK2PAY(merchantId) [replace_midrange $merchant_id]
	set CLICK2PAY(pan)        [replace_midrange $pan]

	# create the same message for which partially shows the merchantId and PAN in the logs
	# as we do not want to display these values in the logs for security
	foreach {log_status log_request} [ob_click2pay::_msg_pack] {
		if {$log_status == "ERR"} {
			ob_log::write INFO {ob_click2pay::_transaction _msg_pack failed: $log_request}
			return [list "NOK" 1]
		}
	}

	# set the values back to what they should be
	set CLICK2PAY(merchantId) $merchant_id
	set CLICK2PAY(pan)        $pan

	if {[catch {
		set rs [ob_db::exec_qry ob_click2pay::update_pg_info $CLICK2PAY(pg_acct_id) $CLICK2PAY(pg_host_id) $CLICK2PAY(pmt_id)]
	} msg ]} {
		ob::log::write ERROR {ob_click2pay::_transaction: Failed to update pg info for pmt_id $CLICK2PAY(pmt_id) - $msg}
		return [list "NOK" 1]
	}

	set CLICK2PAY(status) "U"
	set pmt_status_res [_upd_pmt_status $CLICK2PAY(pmt_id) \
										$CLICK2PAY(status) \
										$CLICK2PAY(oper_id) \
										$CLICK2PAY(pay_sort) \
										$CLICK2PAY(extra_info)]

	if {![lindex $pmt_status_res 0]} {
	  set msg [lindex $pmt_status_res 1]
		ob::log::write ERROR {ob_click2pay::_msg_send: Failed to update Unknown payment status for pmt_id $CLICK2PAY(pmt_id) - $msg}
		return [list "NOK" 1]
	}

	# send the message and close the socket
	foreach {status response} [ob_click2pay::_msg_send $request $log_request] {
		if {$status == "ERR"} {
			ob_log::write INFO {ob_click2pay::_transaction _msg_send failed: $response}
			return [list "NOK" $response]
		}
	}

	# unpack the message
	foreach {status ret} [ob_click2pay::_msg_unpack $response] {
		if {$status == "NOK"} {
			ob_log::write INFO {ob_click2pay::_transaction: _msg_unpack failed: $ret}
			return [list "NOK" $ret]
		}
	}

	ob_log::write INFO {ob_click2pay::_transaction: -- finished successfully}

	return [list OK $ret]
}



#
# Private procedure to validate the data length before making the call
# out to Click2Pay.
#
proc ob_click2pay::_check {} {

	ob::log::write DEBUG {ob_click2pay::_check}

	variable CLICK2PAY
	set err_count 0
	set msg ""

	# check merchantId - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(merchantId) 0 16] != "OB_OK"} {
		lappend msg "Failed to validate merchantId"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate merchantId}
		incr err_count
	}

	# check userName - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(userName) 0 64] != "OB_OK"} {
		lappend msg "Failed to validate userName"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate userName}
		incr err_count
	}

	# check Personal Account Number - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(pan) 0 16] != "OB_OK"} {
		lappend msg "Failed to validate Personal Account Number"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate Personal Account Number}
		incr err_count
	}

	# check amount - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(amount) 0 32] != "OB_OK"} {
		lappend msg "Failed to validate amount"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate amount}
		incr err_count
	}

	# check curCode - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(curCode) 0 3] != "OB_OK"} {
		lappend msg "Failed to validate curCode"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate curCode}
		incr err_count
	}

	# check mode (DEBIT,CREDIT,AUTHORIZATION) - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(mode) 0 13] != "OB_OK"} {
		lappend msg "Failed to validate mode"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate mode}
		incr err_count
	}

	# check productId - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(productId) 0 9] != "OB_OK"} {
		lappend msg "Failed to validate productId"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate productId}
		incr err_count
	}

	# check ip - mandatory
	if {[ob_chk::mandatory_txt $CLICK2PAY(ip) 0 256] != "OB_OK"} {
		lappend msg "Failed to validate ip"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate ip}
		incr err_count
	}

	# check merchantTransId - optional
	if {[ob_chk::mandatory_txt $CLICK2PAY(merchantTransId) 0 32] != "OB_OK"} {
		lappend msg "Failed to validate merchantTransId"
		ob_log::write ERROR {CLICK2PAY::_check: Failed to validate merchantTransId}
		incr err_count
	}

	if {$err_count > 0} {
		ob_log::write INFO {CLICK2PAY::_check: Failed to validate data and returning $err_count validation errors}
		return [list ERR $msg]
	}

	ob_log::write INFO {CLICK2PAY::_check: Successfully validated data}
	return [list OK]
}


#
# Private procedure to build up the SOAP request to be sent to Click2Pay
#
proc ob_click2pay::_msg_pack {} {

	ob::log::write DEBUG {ob_click2pay::_msg_pack}

	variable CLICK2PAY

	#<soapenv:Envelope/>
		#<soapenv:Body/>
			#<ns1:walletPayment/>
				#<merchantId/>
				#<userName/>
				#<pan/>
				#<amount/>
				#<curCode/>
				#<mode/>
				#<overdraw/>
				#<productId/>
				#<ip/>
				#<merchantTransId/>
			#</ns1:walletPayment>
		#</soapenv:Body>
	#</soapenv:Envelope>

	set soap_req [subst {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XML Schema-instance">
			<soapenv:Body>
				<ns1:walletPayment soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:ns1="urn:walletPayment">
					<merchantId xsi:type="xsd:string">$CLICK2PAY(merchantId)</merchantId>
					<userName xsi:type="xsd:string">$CLICK2PAY(userName)</userName>
					<pan xsi:type="xsd:string">$CLICK2PAY(pan)</pan>
					<amount xsi:type="xsd:long">$CLICK2PAY(amount)</amount>
					<curCode xsi:type="xsd:string">$CLICK2PAY(curCode)</curCode>
					<mode xsi:type="xsd:string">$CLICK2PAY(mode)</mode>
					<overdraw xsi:type="xsd:boolean">$CLICK2PAY(overdraw)</overdraw>
					<productId xsi:type="xsd:string">$CLICK2PAY(productId)</productId>
					<ip xsi:type="xsd:string">$CLICK2PAY(ip)</ip>
					<merchantTransId xsi:type="xsd:string">$CLICK2PAY(merchantTransId)</merchantTransId>
				</ns1:walletPayment>
			</soapenv:Body>
		</soapenv:Envelope>
		}]

	return [list OK "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$soap_req"]
}


#
# Private procedure to send SOAP request to Click2Pay
#
# request     - the actual request to be sent
# log_request - the same request with values partially displayed for security
#
proc ob_click2pay::_msg_send {request log_request} {

	ob::log::write DEBUG {ob_click2pay::_msg_send($request,$log_request)}

	variable CFG
	variable CLICK2PAY_RESP

	catch {unset CLICK2PAY_RESP}

	set headerList [list "SOAPAction" "$CFG(url)" "Content-Type" "text/xml" "charset" "utf-8"]

	ob_log::write INFO "CLICK2PAY:_msg_send:REQUEST:\n$log_request -- attempting send to $CFG(url)"

	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $CFG(url)] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {Bad Click2Pay URL: $msg}
		return [list "ERR" 2]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "POST" \
		           -post_data  $request \
				   -headers    $headerList \
	               -encoding   "utf-8"\
		           $CFG(url)]
	} msg]} {
		ob_log::write ERROR {Unable to build Click2Pay request: $msg}
		return [list "ERR" 2]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	set tls [expr {$api_scheme == "http" ? -1 : ""}]

	# Send the request to Click2Pay.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $CFG(timeout) \
		    -req_timeout  $CFG(timeout) \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob::log::write ERROR {Unsure whether request reached Click2Pay:\
		                      send_req blew up with $msg}
		return [list "ERR" 1]
	}

	if {$status != "OK"} {
		# Is there a chance this request might actually have got to Click2Pay?
		if {[::ob_socket::server_processed $req_id]} {
			ob::log::write ERROR \
			  {Unsure whether request reached Click2Pay: status was $status, response body is -> [::ob_socket::req_info $req_id http_body]}
			::ob_socket::clear_req $req_id
			return [list "ERR" 1]
		} else {
			ob::log::write ERROR \
			  {Unable to send request to Click2Pay: status was $status}
			::ob_socket::clear_req $req_id
			return [list "ERR" 2]
		}
	}

	set response [string trim [::ob_socket::req_info $req_id http_body]]

	::ob_socket::clear_req $req_id

	ob_log::write INFO {Click2Pay Response Body: $response}

	return [list OK $response]
}



#
# Private procedure to unpack the SOAP response
#
proc ob_click2pay::_msg_unpack {response} {

	ob::log::write DEBUG {ob_click2pay::_msg_unpack}
	ob::log::write INFO {ob_click2pay::_msg_unpack}

	variable CLICK2PAY_RESP

	#<soapenv:Envelope/>
		#<soapenv:Body/>
			#<ns1:walletPaymentResponse/>
				#<walletPaymentReturn/>
			#</ns1:walletPaymentResponse>
			#<multiRef/>
				#<message/>
				#<statusCode/>
				#<transactionId/>
			#</multiRef>
			#<multiRef/>
				#<amount/>
				#<curCode/>
				#<itemType/>
			#</multiRef>
		#</soapenv:Body>
	#</soapenv:Envelope>

	if {[catch {set doc [dom parse $response]} msg]} {
		catch {$doc delete}
		ob_log::write ERROR {ob_click2pay::_msg_unpack:Unrecognized xml format. Message is:\n $response}
		return [list "NOK" 1]
	}

	set root_doc [$doc documentElement root]
	set format_xml [$root_doc asXML]

	ob_log::write INFO {ob_click2pay::_msg_unpack: RESPONSE \n $format_xml}

	foreach item {
		message
		statusCode
		transactionId
		amount
		curCode
		itemType
		faultcode
		faultstring
	} {
		if {[catch {set element [$root_doc getElementsByTagName $item]} msg]} {
			set element ""
		}

		if {$element != ""} {
			if {[catch {set node_value [[$element firstChild] nodeValue]} msg ]} {
				ob_log::write INFO {ob_click2pay::_msg_unpack: Can't read node value for $item - $msg}
				set node_value ""
			}
			set CLICK2PAY_RESP($item) $node_value
		}
	}

	foreach { n v } [array get CLICK2PAY_RESP] {
		ob_log::write INFO {ob_click2pay::_msg_unpack: $n = $v}
	}


	if {[info exists CLICK2PAY_RESP(faultcode)] && [info exists CLICK2PAY_RESP(faultstring)]} {
		set fault_code $CLICK2PAY_RESP(faultcode)
		set fault_string $CLICK2PAY_RESP(faultstring)
		ob_log::write INFO {ob_click2pay::_msg_unpack: faultcode exists in response - faultcode = $fault_code AND faultstring = $fault_string}
		$doc delete
		return [list "NOK" 1]
	}

	if {[info exists CLICK2PAY_RESP(statusCode)]} {
			#If Transaction has been successful...
		if {$CLICK2PAY_RESP(statusCode) == "000"} {
			ob_log::write INFO {ob_click2pay::_msg_unpack: Transaction has been successful}
			$doc delete
			return [list "OK" $CLICK2PAY_RESP(statusCode)]
		} else {
			#Transaction has not been successful...
			ob_log::write INFO {ob_click2pay::_msg_unpack: Transaction has NOT been successful}
			$doc delete
			return [list "NOK" $CLICK2PAY_RESP(statusCode)]
		}
	}

	$doc delete
	return [list "NOK" 1]
}



#
# Encrypt/decrypt the PAN (Personal Account Number)
#
# para:
# pan        - Click2Pay personal account number
# mode       - encrypt or decrypt
#
# Return:    - enc_pan or pan depending on the mode passed.
#
proc ob_click2pay::encrypt_decrypt_pan {pan mode} {

	global BF_DECRYPT_KEY_HEX

	if {$mode == "encrypt"} {
		return [blowfish encrypt -hex $BF_DECRYPT_KEY_HEX -bin $pan]
	} elseif {$mode == "decrypt"} {
		return [hextobin [blowfish decrypt -hex $BF_DECRYPT_KEY_HEX -hex $pan]]
	}

}



#
# Private procedure to replace the midrange of a variable value
#
proc ob_click2pay::replace_midrange {data} {

	set data_length [string length $data]
	set replace_str "XXXXXXXXXXXXXXXX"

	set pan_string [string range $data 0 3]

	# handle the case that the length is shorter than expected (almost certainly
	# an invalid pan) - show first 4, last 4, and anything in between hidden
	# with X's
	if {$data_length > 8} {
		append pan_string [string range $replace_str 0 [expr {$data_length-9}]]
	}

	if {$data_length > 4} {
		append pan_string [string range $data end-[expr {$data_length - 5 >= 3 ? 3 : $data_length - 5}] end]
	}

	return $pan_string
}



#
# Search for previous successfuly payments
# Takes cust_id and PAN (Personal Account Number)
#
proc ob_click2pay::_check_prev_pmt {cust_id pan} {

	set enc_pan [encrypt_decrypt_pan $pan "encrypt"]

	if {[catch {
		set rs [ob_db::exec_qry ob_click2pay::check_prev_pmt $enc_pan $cust_id]} msg]} {
		ob_log::write ERROR {CLICK2PAY::_check_prev_pmt:Failed to check prev pmts on click2pay account: $msg}
		return 0
	}

	set result [expr {[db_get_nrows $rs] > 0}]

	ob_db::rs_close $rs

	return $result
}


#
# Updates the payment status
#
proc ob_click2pay::_upd_pmt_status {
	pmt_id
	status
	oper_id
	pay_sort
	{extra_info ""}
	{gw_uid ""}
	{gw_ret_code ""}
	{gw_ret_msg ""}
	{auth_code ""}
} {

	ob::log::write DEBUG {ob_click2pay::_upd_pmt_status($pmt_id,$status,$oper_id,$pay_sort,$gw_uid,\
		$gw_ret_code,$gw_ret_msg,$auth_code,$extra_info)}


	if {$status=="U"} {
		set qry upd_pmt_unknown_status
	} else {
		set qry pmt_upd_c2p
	}

	set j_op_type [expr {$pay_sort=="D"?"DEP":"WTD"}]

	if {[catch {
		set rs [ob_db::exec_qry ob_click2pay::$qry \
		                                      $pmt_id \
		                                      $status \
		                                      $oper_id \
		                                      $j_op_type \
		                                      $gw_uid \
		                                      $gw_ret_code \
		                                      $gw_ret_msg \
		                                      $auth_code \
		                                      $extra_info]} msg]} {
		ob_log::write ERROR {CLICK2PAY::_upd_pmt_status:Failed to set payment status to $status for pmt_id $pmt_id - $msg}
		return [list 0 "Failed to set payment status to $status - $msg"]
  	}

	ob_db::rs_close $rs
	ob_log::write INFO {ob_click2pay::_upd_pmt_status: Successfully updated payment status to $status for pmt_id $pmt_id}
	return [list 1 "Click2Pay payment status successfully updated to $status for pmt_id $pmt_id"]
}

#
# Private procedure to get a response value from the CLICK2PAY_RESP array
#
proc ob_click2pay::_get_resp_val {name} {

	variable CLICK2PAY_RESP

	if {[info exists CLICK2PAY_RESP($name)]} {
		return $CLICK2PAY_RESP($name)
	}

	ob_log::write INFO {CLICK2PAY::_get_resp_val:CLICK2PAY_RESP($name) does not exist}
	return ""
}



# If initial Deposit with Click2Pay fails their C2P
# payment method will be cancelled on their account
#
#   cpm_id  - CPM Id
#   returns - 1 on sucessfull updation | 0 on failure
#
proc ob_click2pay::remove_cpm {cpm_id} {
    if {[catch {set rs [ob_db::exec_qry ob_click2pay::cancel_pay_mthd $cpm_id]} msg]} {
        ob_log::write ERROR {ob_click2pay::cancel_pay_mthd: Failed to set payment status to cancelled for cpm_id :$cpm_id}
        return [list 0 "Failed to set payment method status to cancel"]
    }
    ob_db::rs_close $rs
    ob_log::write INFO {ob_click2pay::cancel_pay_mthd: Successfully updated customer payment method status to for cpm_id : $cpm_id}
    return [list 1 "Click2Pay status successfully updated"]
}

ob_click2pay::init
