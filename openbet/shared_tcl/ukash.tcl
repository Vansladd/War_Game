#
# $Id: ukash.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Provides an interface to the Ukash API. Requests...
#
# 1) GetSettleAmount - check the value of a voucher in another currency
# 2) Redemption      - redeem a voucher
#
# Configuration:
#
#  UKASH_REDEMPTION_TYPE  - for Redemption request. (default: 2). Possible values...
#                            1 = Cash Withdrawal
#                            2 = Account Deposit
#                            3 = Product/Service Purchase
#

#
# Dependancies (standard packages)
#
package require tdom
package require http
package require tls
package require util_crypt
package require util_xml 4.5
#
# Dependancies (shared_tcl)
#
# payment_gateway.tcl


package require OB_Log 1.0

if {[OT_CfgGet MONITOR 0]} {

        package require    monitor_compat 1.0

}


package provide ob_ukash 1.0

namespace eval ob_ukash {
	variable INIT 0
	variable PMT
}

#
# One time initialisation of this module
#
proc ob_ukash::init {} {

	variable INIT
	variable CFG

	if {$INIT} { return }

	ob::log::init

	ob::log::write INFO {ob_ukash:init}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CFG(pmt_receipt_format) 0
		set CFG(pmt_receipt_tag)    ""
	}

	ob_ukash::prepare_queries

	set INIT 1
}

#
# Prepare any queries we need for this module
#
proc ob_ukash::prepare_queries {} {
	ob::log::write INFO {ob_ukash::prepare_queries}

	ob_db::store_qry ob_ukash::get_matching_block {
		select first 1
			voucher
		from
			tUkashBlock
		where
			status = 'A' and
			voucher = substr(?, 0, length(voucher))
	}

	ob_db::store_qry ob_ukash::insert_cpm {
		execute procedure pCPMInsUkash (
			p_pay_mthd      = ?,
			p_cust_id       = ?,
			p_auth_dep      = ?,
			p_status_dep    = ?,
			p_auth_wtd      = ?,
			p_status_wtd    = ?,
			p_balance_check = ?,
			p_transactional = ?
		)
	}

	ob_db::store_qry ob_ukash::set_unknown {
		execute procedure pPmtUpdStatus (
			p_pmt_id        = ?,
			p_status        = 'U'
		)
	}

	ob_db::store_qry ob_ukash::remove_cpm {
		update tCustPayMthd set
			status = 'X'
		where
			cpm_id = ?
	}

	ob_db::store_qry ob_ukash::insert_pmt {
		execute procedure pPmtInsUkash (
			p_pay_mthd       = ?,
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_unique_id      = ?,
			p_pg_acct_id     = ?,
			p_status         = ?,
			p_enc_voucher    = ?,
			p_voucher_hash   = ?,
			p_value          = ?,
			p_prod_code      = ?,
			p_oper_id        = ?,
			p_transactional  = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?
		)
	}

	ob_db::store_qry ob_ukash::update_pmt {
		execute procedure pPmtUpdUkash (
			p_pmt_id        = ?,
			p_status        = ?,
			p_oper_id       = ?,
			p_txn_id        = ?,
			p_err_code      = ?,
			p_enc_voucher   = ?,
			p_voucher_hash  = ?,
			p_value         = ?,
			p_expiry        = ?,
			p_flag_cancel   = ?,
			p_transactional = ?
		)
	}

	ob_db::store_qry ob_ukash::get_pmt {
		select
			p.acct_id,
			p.ipaddr,
			p.cpm_id,
			p.payment_sort,
			p.source,
			p.amount
		from
			tPmt p
		where
			p.pmt_id = ?
	}

	ob_db::store_qry ob_ukash::first_pmt {
		select
			first 1
			pmt_id
		from
			tPmt
		where
			cpm_id = ?
		and payment_sort = ?
		and status not in ('N', 'X')
	}

	ob_db::store_qry ob_ukash::successful_pmt {
		select
		first 1
			1
		from
			tPmt
		where
			cpm_id = ?
		and payment_sort = ?
		and status = 'Y'
	}

	ob_db::store_qry ob_ukash::get_acct_details {
		select
			cust_id,
			ccy_code
		from
			tAcct
		where
			acct_id = ?
	}

	ob_db::store_qry ob_ukash::get_country_code {
		select
			country_code
		from
			tCustomer
		where
			cust_id = ?
	}

	ob_db::store_qry ob_ukash::get_acct_id {
		select
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	ob_db::store_qry ob_ukash::prev_usage {
		select
			u.voucher_hash,
			p.acct_id,
			p.payment_sort,
			p.status
		from
			tPmtUkash u,
			tPmt p
		where
			u.enc_voucher = ?   and
			u.pmt_id = p.pmt_id
	}

	ob_db::store_qry ob_ukash::record_fail {
		execute procedure pCPMFail (
			p_cpm_id       = ?,
			p_fail_reason  = ?,
			p_max_attempts = ?
		)
	}

	ob_db::store_qry ob_ukash::get_pay_mthd_with_cpm_id {
		select
			pay_mthd
		from
			tCustPayMthd
		where
			cpm_id = ?
	}

	ob_db::store_qry ob_ukash::get_pay_mthd_with_pmt_id {
		select
			cpm.pay_mthd
		from
			tCustPayMthd cpm,
			tPmt         p
		where
			p.pmt_id = ?          and
			p.cpm_id = cpm.cpm_id
	}
}

#
# Check if the given voucher is valid.
#
# returns - 1 if the voucher is valid, 0 otherwise
#
proc ob_ukash::valid_voucher { voucher acct_id cpm_id } {

	ob::log::write DEBUG {ob_ukash::valid_voucher($voucher)}

	# vouchers are 19 digits
	if {![regexp {^\d{19}$} $voucher]} {
		return 0
	}

	# This type of voucher isn't blocked

	set res [ob_db::exec_qry ob_ukash::get_matching_block $voucher]

	if {[db_get_nrows $res]} {
		ob_db::rs_close $res
		ob::log::write INFO {ob_ukash::valid_voucher Ukash vouchers starting [db_get_col $res 0 voucher] are blocked}
		return 0
	}

	ob_db::rs_close $res

	# Make sure this voucher number hasn't been used in the system before
	# on another account
	set enc_voucher [encrypt_voucher $voucher]

	if {[catch {ob_db::exec_qry ob_ukash::prev_usage $enc_voucher} rs]} {
		ob::log::write ERROR {ob_ukash::valid_voucher: error running prev_usage: $rs}
		return 0
	}

	set used_before 0
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		# The voucher can be used providing it was previously used
		# by this same customer either when withdrawing from the account
		# or having used it to make an unsuccessful deposit

		if {[db_get_col $rs $r acct_id] != $acct_id ||
			([db_get_col $rs $r payment_sort] eq "D" &&
			 [db_get_col $rs $r status] eq "Y")} {
			set used_before 1
			break
		}

		# One last check to make sure the voucher hasn't been moved from
		# one account to the other in the backend
		if {[db_get_col $rs $r voucher_hash] ne
			[hash_voucher $voucher $acct_id]} {
			ob::log::write ERROR {ob_ukash::valid_voucher: voucher_account $acct_id but voucher hash incorrect hash for this account}
			set used_before 1
			break
		}
	}

	ob_db::rs_close $rs

	if {$used_before} {
		record_fail_attempt $cpm_id "Voucher used before"
		return 0
	}

	return 1
}

#
# Pull out the voucher currency code
#
proc ob_ukash::get_voucher_ccy_code { voucher } {
	# the 7th-9th digits represent the voucher currency
	return [string range $voucher 6 8]
}

#
# Make a GetSettleAmount request
#
# voucher  - the voucher for which we want the settle amount
# value    - the value of the voucher
# ccy_code - the base currency we want to convert the voucher to
#
# returns  - UKASH_OK for succeeded or relevant error message
#
proc ob_ukash::get_settle_amount { acct_id cpm_id voucher value ccy_code {arr_ref UKASH} } {

	variable PMT

	upvar $arr_ref UKASH

	ob::log::write DEBUG {ob_ukash::get_settle_amount($voucher,$value,$ccy_code)}

	init

	# create the response array
	array set UKASH [list]

	# check the format of the voucher
	if {![ob_ukash::valid_voucher $voucher $acct_id $cpm_id]} {
		ob::log::write ERROR {ob_ukash::get_settle_amount: invalid voucher - $voucher}
		return UKASH_INVALID_VOUCHER
	}

	# Check the format of the value field
	set value [string trim $value]

	if {$value == {}} {
		return UKASH_INVALID_VALUE
	}

	set value [format {%.2f} $value]

	# Get the currency code from the ukash voucher
	set ukash_ccy_code [ob_ukash::get_voucher_ccy_code $voucher]

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "cpm" $cpm_id]] == "ERROR"} {
		return UKASH_ERROR
	}

	# Set the gateway parameters
	if {![ob_ukash::get_pmt_gateway_params $pay_mthd]} {
		return UKASH_PMT_GWAY_ERROR
	}

	# Set up all the details in the payment array
	set PMT(UKASHVoucherNumber)  $voucher
	set PMT(UKASHVoucherValue)   $value
	set PMT(UKASHBaseCurr)       $ccy_code
	set PMT(UKASHProductCode)    $ukash_ccy_code

	if {$pay_mthd == "IKSH"} {
		# for IKSH use RedemptionType = 3
		set PMT(UKASHRedemptionType) "3"
	} else {
		set PMT(UKASHRedemptionType) "2"
	}

	if {$PMT(pg_type) eq "UKASH"} {

		set ret [ob_ukash::send_settle_amount]

	} elseif {$PMT(pg_type) eq "COMMIDEA"} {

		set ret [ob_commidea::make_call "PMT"]

	} else {
		ob::log::write ERROR {get_settle_amount: Unknown pg_type: $PMT(pg_type)}
		return UKASH_ERROR
	}

	if {$ret ne "OK"} {
		return UKASH_ERROR
	}

	foreach i {settleAmount amountReference errCode errDescription} {
		if {[info exists PMT($i)]} {
			set UKASH($i) $PMT($i)
		}
	}

	switch -exact $UKASH(errCode) {
		{} -
		0 {
			# No errors in the request - check data values

			if {![regexp {^\d+\.\d{1,2}$} $UKASH(settleAmount)]} {
				return UKASH_RESP_DATA_ERROR
			}

			if {![regexp {^.{0,255}$} $UKASH(amountReference)]} {
				return UKASH_RESP_DATA_ERROR
			}

			return UKASH_OK

		}
		default {
			# The request failed with some error code
			return UKASH_ERROR
		}
	}
}

proc ob_ukash::send_settle_amount {} {

	variable PMT

	# build some xml for the request
	set doc [dom createDocument UKashTransaction]
	set root [$doc documentElement]

	set elements [list \
		ukashLogin             $PMT(client)\
		ukashPassword          $PMT(password)\
		voucherCurrProductCode $PMT(UKASHProductCode)\
		voucherValue           $PMT(UKASHVoucherValue)\
		baseCurr               $PMT(UKASHBaseCurr)\
		brandId                $PMT(mid)]

	# build up the xml
	foreach {tag value} $elements {
		set n [$doc createElement $tag]
		set t [$doc createTextNode $value]
		$n appendChild $t
		$root appendChild $n
	}

	# log request hiding sensitive data
	set req_log [ob_xml::mask_nodes [$root asXML]\
		[list ukashLogin ukashPassword brandId]]
	ob_log::write INFO {ob_ukash::send_settle_amount: request =\n$req_log}

	set data [$root asXML -indent none]

	# free the request document
	$doc delete

	set ret [ob_ukash::build_request GetSettleAmount $data]

	if {![lindex $ret 0]} {
		return [lindex $ret 1]
	}

	# The full XML that will be sent
	set data [lindex $ret 1]

	# Need to set these properly
	set soap_action {http://tempuri.org/UKash/Service1/GetSettleAmount}

	# Make the request
	set ret [ob_ukash::send_request \
		$PMT(host) $PMT(conn_timeout) $soap_action $data]

	if {![lindex $ret 0]} {
		return [lindex $ret 1]
	}

	# Parse the reponse
	set ret [ob_ukash::parse_response GetSettleAmount [lindex $ret 1]]

	if {![lindex $ret 0]} {
		return [lindex $ret 1]
	}

	ob::log::write DEBUG {ob_ukash::get_settle_amount - [lindex $ret 1]}

	set response [lindex $ret 1]

	# Now parse the GetSettleAmount data
	if {[catch {set doc [dom parse $response]} msg]} {
		ob::log::write ERROR {ob_ukash::get_settle_amount: error in response data xml - $msg}
		return UKASH_RESP_XML_ERROR
	}

	set root [$doc documentElement]

	# log response
	set resp_log [$root asXML]
	ob_log::write INFO {ob_ukash::send_settle_amount: response =\n$resp_log}

	# Expected elements
	set dtd {settleAmount amountReference errCode errDescription}

	foreach tag $dtd {
		set PMT($tag) [string trim [$root selectNodes "string($tag)"]]
	}

	# free the response document
	$doc delete

	return OK
}

#
# Redeem the given voucher
#
proc ob_ukash::redemption { voucher value base_ccy txn_id time {amt_ref {}} {arr_ref UKASH} } {

	variable PMT

	upvar $arr_ref UKASH

	ob::log::write DEBUG {ob_ukash::redemption($voucher,$value,$base_ccy,$txn_id,$time,$amt_ref,$arr_ref)}

	init

	# create the response array
	array set UKASH [list]

	# We have already validated the voucher by this point
	# Check the format of the value field
	set value [string trim $value]

	if {$value == {}} {
		return UKASH_INVALID_VALUE
	}

	set value [format {%.2f} $value]

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "pmt" $txn_id]] == "ERROR"} {
		return UKASH_ERROR
	}

	# Set the gateway parameters
	if {![ob_ukash::get_pmt_gateway_params $pay_mthd]} {
		return UKASH_PMT_GWAY_ERROR
	}

	# Set up all the details in the payment array
	set PMT(UKASHVoucherNumber)  $voucher
	set PMT(UKASHVoucherValue)   $value
	set PMT(UKASHBaseCurr)       $base_ccy
	set PMT(pay_sort)            "D"
	set PMT(transactionId)       $txn_id
	set PMT(time)                $time
	set PMT(UKASHAmountRef)      $amt_ref

	if {$pay_mthd == "IKSH"} {
		# for IKSH use RedemptionType = 3
		set PMT(UKASHRedemptionType) "3"
	} else {
		set PMT(UKASHRedemptionType) "2"
	}

	if {$PMT(pg_type) eq "UKASH"} {

		set ret [ob_ukash::send_redemption]

	} elseif {$PMT(pg_type) eq "COMMIDEA"} {

		set ret [ob_commidea::make_call "PMT"]

	} else {
		ob::log::write ERROR {redemption: Unknown pg_type: $PMT(pg_type)}
		return UKASH_ERROR
	}

	if {$ret ne "OK"} {
		return UKASH_ERROR
	}

	set dtd {
		txCode                   {^[0-9]*$}
		errCode                  {.*}
		errDescription           {.*}
		txDescription            {.{1,255}}
		settleAmount             {^\d+\.\d{1,2}$}
		changeIssueVoucherNumber {^$}
		changeIssueVoucherCurr   {^$}
		changeIssueAmount        {^.*$}
		changeIssueExpiryDate    {^$}
		ukashTransactionId       {^.{1,50}$}
		currencyConversion       {^(TRUE|FALSE|1|0)?$}
	}

	set errors [list]

	foreach {tag re} $dtd {
		set UKASH($tag) $PMT($tag)
		if {![regexp $re $PMT($tag)]} {
			lappend errors "$tag=$PMT($tag)"
		}
	}

	switch -exact $PMT(txCode) {
		0 {
			# Accepted - so carry on and check the rest of the data
		}
		1 {
			# Declined
			return UKASH_DECLINED
		}
		99 {
			return UKASH_FAILED
		}
		default {
			return UKASH_RESP_DATA_ERROR
		}
	}

	if {[llength $errors] > 0} {
		return UKASH_RESP_DATA_ERROR
	}

	return UKASH_ACCEPTED
}

proc ob_ukash::send_redemption {} {

	variable PMT

	# build some xml for the request
	set doc [dom createDocument UKashTransaction]

	set root [$doc documentElement]

	# elements to be sent to Ukash
	set elements [list \
		ukashLogin       $PMT(client)\
		ukashPassword    $PMT(password)\
		transactionId    $PMT(transactionId)\
		brandId          $PMT(mid)\
		voucherNumber    $PMT(UKASHVoucherNumber)\
		voucherValue     $PMT(UKASHVoucherValue)\
		baseCurr         $PMT(UKASHBaseCurr)\
		ticketValue      {}\
		redemptionType   $PMT(UKASHRedemptionType)\
		merchDateTime    $PMT(time)\
		merchCustomValue {}\
		storeLocationId  {}\
		amountReference  $PMT(UKASHAmountRef)]

	# build up the xml
	foreach {tag value} $elements {
		set n [$doc createElement $tag]
		set t [$doc createTextNode $value]
		$n appendChild $t
		$root appendChild $n
	}

	# log request hiding sensitive data
	set req_log [ob_xml::mask_nodes [$root asXML]\
		[list ukashLogin ukashPassword brandId voucherNumber]]
	ob_log::write INFO {ob_ukash::send_redemption: request =\n$req_log}

	set data [$root asXML -indent none]

	# free the request document
	$doc delete

	set ret [ob_ukash::build_request Redemption $data]

	if {![lindex $ret 0]} {
		return [lindex $ret 1]
	}

	# The full XML that will be sent
	set data [lindex $ret 1]

	# send the request
	set soap_action {http://tempuri.org/UKash/Service1/Redemption}

	set ret [ob_ukash::send_request \
		$PMT(host) $PMT(conn_timeout) $soap_action $data]

	if {![lindex $ret 0]} {
		# error making request
		return [lindex $ret 1]
	}

	set ret [ob_ukash::parse_response Redemption [lindex $ret 1]]

	if {![lindex $ret 0]} {
		return [lindex $ret 1]
	}

	set doc  [dom parse [lindex $ret 1]]
	set root [$doc documentElement]

	# log response hiding sensitive data
	set resp_log [ob_xml::mask_nodes [$root asXML]\
		[list changeIssueVoucherNumber]]
	ob_log::write INFO {ob_ukash::send_redemption: response =\n$resp_log}

	# these are the expected elements
	set dtd {
		txCode
		txDescription
		settleAmount
		changeIssueVoucherNumber
		changeIssueVoucherCurr
		changeIssueAmount
		changeIssueExpiryDate
		ukashTransactionId
		currencyConversion
		errCode
		errDescription
	}

	foreach tag $dtd {
		set PMT($tag) [string trim [$root selectNodes "string($tag)"]]
	}

	# free the response document
	$doc delete

	return "OK"


}

proc ob_ukash::deposit { acct_id ccy_code cpm_id amount voucher value amount_ref ipaddr channel unique_id {oper_id {}} } {

	ob::log::write INFO {ob_ukash::deposit($acct_id,$ccy_code,$cpm_id,$amount,$voucher,$value,$amount_ref,$ipaddr,$channel,$unique_id)}


	# Check the format of the voucher
	if {![ob_ukash::valid_voucher $voucher $acct_id $cpm_id]} {
		ob::log::write ERROR {ob_ukash::deposit: invalid voucher - $voucher}
		return UKASH_INVALID_VOUCHER
	}

	# Initially we set pmt to Unknown
	set status U

	# Only interested in deposits here
	set payment_sort D

	# Insert an unknown pmt
	set ret [ob_ukash::insert_pmt \
		$acct_id \
		$cpm_id \
		$payment_sort \
		$amount \
		$voucher \
		$value \
		$status \
		$ipaddr \
		$channel \
		$unique_id \
		$oper_id]

	if {[lindex $ret 0]} {
		# Successful insert
		set pmt_id [lindex $ret 1]
		if {[OT_CfgGet ADD_TXN_POINT 0] == 1} {
			if {[catch {set res [txn_point::insert_pmt_flag $pmt_id "point of deposit"]} msg]} {
				ob::log::write ERROR "ERROR: Could not insert point of deposit $msg"
			}
		}
	} else {
		# Failed insert
		return [payment_gateway::cc_pmt_get_sp_err_code [lindex $ret 1] UKASH_ERROR]
	}

	set time [clock format [clock seconds] -format {%Y-%m-%d %T}]

	# An amount reference of 0 means that the
	# voucher is in the base currency
	if {$amount_ref == 0} {
		set amount_ref {}
	}

	# Make the call to Ukash to redeem the voucher
	set ret_status [ob_ukash::redemption\
		$voucher\
		$value\
		$ccy_code\
		$pmt_id\
		$time\
		$amount_ref REDEEM]


	switch -exact -- $ret_status {
		UKASH_ACCEPTED {
			# Ukash have accepted the pmt
			# txCode = 0
			set status Y

			set flag 0
			#check if there was no successful deposit before
			if {[ob_ukash::successful_pmt $cpm_id $payment_sort] == 0} {
				set flag 1
			}

			set upd_ret [ob_ukash::update_pmt $acct_id $pmt_id $status $REDEEM(ukashTransactionId) $REDEEM(errCode) $oper_id]

			if {[lindex $upd_ret 0] && $flag == 1} {
				set rs [ob_db::exec_qry ob_ukash::get_acct_details $acct_id]
				set cust_id [db_get_col $rs 0 cust_id]
				set ccy_code [db_get_col $rs 0 ccy_code]
				set res [ob_db::exec_qry ob_ukash::get_country_code $cust_id]
				set country_code [db_get_col $res 0 country_code]
				# Perform age checks!
				if {[OT_CfgGet CARD_AGE_WTD_BLOCK 0] && [card_util::is_suspected_youth $cust_id "UKASH" $country_code $ccy_code]} {
					set txt_reason {Withdrawal blocked till age verification is done}
					card_util::set_cust_status_flag $cust_id WTD AGER $txt_reason
				}
				ob_db::rs_close $rs
				ob_db::rs_close $res
			}
			# Error updating so the pmt will be left in unknown status
			if {![lindex $upd_ret 0]} {
				return UKASH_ERROR
			}
		}
		UKASH_DECLINED -
		UKASH_FAILED {

			# This may be an invalid amount or voucher number
			# record the attempt.  A  customer can only have
			# a set number before the method is suspended
			record_fail_attempt $cpm_id $REDEEM(errDescription)

			# The pmt was declined or the response contains an error message
			# txCode = 1 or 99
			set status N

			set upd_ret [ob_ukash::update_pmt $acct_id $pmt_id $status $REDEEM(ukashTransactionId) $REDEEM(errCode) $oper_id]

			# Error updating so the pmt will be left in unknown status
			if {![lindex $upd_ret 0]} {
				return UKASH_ERROR
			}

			if {[OT_CfgGet FUNC_REMOVE_CPM_ON_FAIL 1]} {
				# Since this pmt has failed, if this is the first
				# payment attempt then remove the CPM
				if {[ob_ukash::first_pmt $cpm_id $payment_sort] == 1} {
					ob_ukash::remove_cpm $cpm_id
				}
			}
		}
	}

	return [list $ret_status $pmt_id $REDEEM(ukashTransactionId)]
}

proc ob_ukash::withdraw { acct_id ccy_code cpm_id amount ipaddr channel unique_id {oper_id {}} } {

	ob::log::write INFO {ob_ukash::withdraw($acct_id,$ccy_code,$cpm_id,$amount,$ipaddr,$channel,$unique_id)}

	init

	set payment_sort W
	set status       P

	# Insert an unknown pmt
	set ret [insert_pmt \
		$acct_id \
		$cpm_id \
		$payment_sort \
		$amount \
		"" \
		$amount \
		$status \
		$ipaddr \
		$channel \
		$unique_id \
		$oper_id]

	if {[lindex $ret 0]} {
		# Successful insert
		set pmt_id [lindex $ret 1]

	} else {
		# Failed insert
		return [payment_gateway::cc_pmt_get_sp_err_code [lindex $ret 1] UKASH_ERROR]
	}

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "cpm" $cpm_id]] == "ERROR"} {
		return UKASH_ERROR
	}

	# Can we issue the voucher now or should there be a delay or
	# a fraud check.
	set process_pmt [ob_pmt_validate::chk_wtd_all\
		$acct_id\
		$pmt_id\
		$pay_mthd\
		"----"\
		$amount\
		$ccy_code]

	if {!$process_pmt} {
		# Payment delayed to be processed later
		return [list "UKASH_DELAYED" $pmt_id]
	}

	return [issue_voucher $acct_id $pmt_id $amount $ccy_code $oper_id UKASH]

}

proc ob_ukash::issue_voucher {acct_id pmt_id amount ccy_code oper_id arr_ref} {

	variable PMT

	upvar $arr_ref UKASH

	init

	set time [clock format [clock seconds] -format {%Y-%m-%d %T}]

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "pmt" $pmt_id]] == "ERROR"} {
		return UKASH_ERROR
	}

	# Set the gateway parameters
	if {![get_pmt_gateway_params $pay_mthd]} {
		return UKASH_PMT_GWAY_ERROR
	}

	# Set up all the details in the payment array
	set PMT(UKASHVoucherValue)   $amount
	set PMT(UKASHBaseCurr)       $ccy_code
	set PMT(UKASHRedemptionType) "4"
	set PMT(pay_sort)            "W"
	set PMT(transactionId)       $pmt_id
	set PMT(time)                $time

	# Default return values
	set UKASH(ukashTransactionId)  ""
	set UKASH(errCode)             ""
	set UKASH(issuedVoucherNumber) ""
	set UKASH(issuedAmount)        ""
	set UKASH(issuedExpiryDate)    ""

	# Set to unknown before sending to the gateway
	if {[catch {ob_db::exec_qry ob_ukash::set_unknown $pmt_id} msg]} {
		ob_log::write ERROR {ob_ukash::issue_voucher: cannot set pmt to unknown: $msg}
		return "UKASH_ERROR"
	}

	foreach {status flag_cancel}\
		[send_issue_voucher $ccy_code $amount UKASH] {break}

	if {$status eq "UKASH_ACCEPTED"} {

		set pmt_status "Y"

	} else {

		# We're going to treat this slightly differently to other payment
		# methods in so far as the user cannot do anything with the funds
		# without the voucher number.  Hence even if the transaction is
		# in an unknown state we are going to return the funds to the
		# customer and flag the payment as a tranaction that would
		# need cancellation through UKASH's system

		set pmt_status "N"
	}

	set upd_ret [ob_ukash::update_pmt\
		$acct_id\
		$pmt_id\
		$pmt_status\
		$UKASH(ukashTransactionId)\
		$UKASH(errCode)\
		$oper_id\
		$UKASH(issuedVoucherNumber)\
		$UKASH(issuedAmount)\
		$UKASH(issuedExpiryDate)\
		$flag_cancel\
		"Y"]

	if {![lindex $upd_ret 0]} {
		return UKASH_ERROR
	}

	return [list $status\
		$pmt_id\
		$UKASH(ukashTransactionId)\
		$UKASH(issuedVoucherNumber)\
		$UKASH(issuedExpiryDate)]
}

proc ob_ukash::send_issue_voucher {ccy_code amount {arr_ref UKASH}} {

	variable PMT

	upvar $arr_ref UKASH

	if {$PMT(pg_type) ne "COMMIDEA"} {
		ob::log::write ERROR {ob_ukash::issue_voucher: Unknown pg_type: $PMT(pg_type)}
		return [list UKASH_ERR_UKKNOWN_PGTYPE 0]
	}

	# Send off the request to the provider

	set ret [ob_commidea::make_call "PMT"]

	if {$ret ne "OK"} {

		# Error on contacting the gateway.  If a connection was established
		# we may need to cancel the payment
		if {$ret eq "PMT_NO_SOCKET"} {
			return [list UKASH_ERROR N]
		} else {
			return [list UKASH_ERROR Y]
		}
	}

	switch -exact $PMT(errCode) {
		{} -
		0 {
			# No errors in the request - check data values

			switch -exact $PMT(txCode) {
				0 {
					# Accepted - so carry on and check the rest of the data
				}
				1 {
					# Declined
					return [list UKASH_DECLINED N]
				}
				99 {
					# The payment failed we can cancel
					return [list UKASH_FAILED N]
				}
				default {
					return [list  UKASH_RESP_UNKNOWN Y]
				}
			}

			set dtd {
				errCode                  {.*}
				txDescription            {.{1,255}}
				changeIssueVoucherNumber {^$}
				changeIssueVoucherCurr   {^$}
				changeIssueAmount        {^.*$}
				changeIssueExpiryDate    {^$}
				ukashTransactionId       {^.{1,50}$}
				issuedVoucherNumber      {^\d{19}$}
				issuedVoucherCurr        {^[A-Z]{3}$}
				issuedAmount             {^\d+\.\d{1,2}$}
				issuedExpiryDate         {^\d{4}-\d{2}-\d{2}$}
				currencyConversion       {^(TRUE|FALSE|1|0)?$}
			}

			set errors [list]

			foreach {tag re} $dtd {
				set UKASH($tag) $PMT($tag)
				if {![regexp $re $PMT($tag)]} {
					lappend errors "$tag=$PMT($tag)"
				}
			}

			if {[llength $errors] > 0} {
				return [list UKASH_RESP_DATA_ERROR Y]
			}

			# Lets do some sanity checks on what we're getting back
			if {$ccy_code ne $UKASH(issuedVoucherCurr)} {
				return [list UKASH_CCY_MISMATCH Y]
			}

			if {$amount != $UKASH(issuedAmount)} {
				return [list UKASH_AMOUNT_MISMATCH Y]
			}
		}
		default {
			# The request failed with some error code
			return [list UKASH_RESP_DATA_ERROR Y]
		}
	}

	# We have a successful payment
	return [list UKASH_ACCEPTED N]
}

#
# Convert the error code into an error description.
#
# err_code - the integer error code
#
# returns - the error description text
#
proc ob_ukash::err_desc { err_code } {
	switch -exact -- $err_code {
		{} -
		0 {
			# Zero or empty string means no error
			return {None}
		}
		100 { return {Invalid incoming XML} }
		200 { return {Non numeric Voucher Value} }
		201 { return {Base Currency not 3 characters in length} }
		202 { return {Non numeric Ticket Value} }
		203 { return {Invalid BrandId} }
		204 { return {Invalid MerchDateTime} }
		205 { return {Invalid transactionId: greater than 20 characters} }
		206 { return {Invalid Redemption Type} }
		207 { return {Negative Ticket Value not allowed} }
		208 { return {No decimal place given in Ticket Value} }
		209 { return {No decimal place given in Voucher Value} }
		210 { return {Negative Voucher Value not allowed} }
		211 { return {Invalid or unsupported voucher product code} }
		212 { return {AmountReference with TicketValue not allowed} }
		213 { return {No voucherNumber supplied} }
		214 { return {No transactionId supplied} }
		215 { return {No brandId supplied} }
		216 { return {Ticket Value cannot be greater than Voucher Value without Currency Conversion} }
		219 { return {Invalid Voucher Number} }
		300 { return {Invalid Login and/or Password} }
		400 { return {Required Currency Conversion not supported} }
		500 { return {Error In Currency Conversion} }
		501 { return {Converted Settle Amount greater than Voucher Value} }
		800 { return {Max duration between getSettleAmount and Redemption exceeded.} }
		801 { return {Invalid amountReference Submitted} }
		900 { return {Technical Error. Please contact Ukash Merchant Support.} }
		default {
			return {Unknown error code}
		}
	}
}

proc ob_ukash::get_pmt { pmt_id {arr_ref DATA} } {
	ob_log::write DEBUG {ob_ukash::get_pmt($pmt_id,$arr_ref)}

	upvar $arr_ref DATA

	if {[catch {set rs [ob_db::exec_qry ob_ukash::get_pmt $pmt_id]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::get_pmt - $msg}
		return -1

	} else {

		if {[db_get_nrows $rs] == 1} {

			set cols [db_get_colnames $rs]
			foreach c $cols {
				set DATA($c) [db_get_col $rs 0 $c]
			}
			set ret 1

		} else {
			ob::log::write ERROR {ob_ukash::get_pmt - can't find pmt_id=$pmt_id}
			set ret 0
		}

		ob_db::rs_close $rs
		return $ret
	}
}

#
# Check if a customer has had a successful payment with this CPM
#
# cpm_id - the customer payment method to check against
# payment_sort - either D(eposit) od W(ithdrawal)
#
# returns - 1 if this is the first pmt, 0 if it isn't and -1 on error
#
proc ob_ukash::first_pmt { cpm_id payment_sort } {
	ob::log::write DEBUG {ob_ukash::get_pmt($cpm_id,$payment_sort)}

	if {[catch {set rs [ob_db::exec_qry ob_ukash::first_pmt $cpm_id $payment_sort]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::first_pmt - $msg}
		return -1

	} else {

		set nrows [db_get_nrows $rs]
		ob_db::rs_close $rs

		# if we get zero rows back from the query then this is the first payment
		return [expr {$nrows == 0}]
	}
}

# Function to insert Ukash payment method (UKSH/IKSH)
#
proc ob_ukash::insert_cpm {
	pay_mthd
	cust_id
	auth_dep
	{auth_wtd      N}
	{balance_check N}
	{transactional Y}
} {
	ob::log::write DEBUG {ob_ukash::insert_cpm($pay_mthd, $cust_id, $auth_dep, \
		$auth_wtd, $balance_check)}

	init

	set status_dep A

	if {$auth_wtd == {N}} {
		set status_wtd S
	} else {
		set status_wtd A
	}

	if {[catch {
		set rs [ob_db::exec_qry ob_ukash::insert_cpm \
			$pay_mthd \
			$cust_id \
			$auth_dep \
			$status_dep \
			$auth_wtd \
			$status_wtd \
			$balance_check \
			$transactional \
		]
	} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::insert_cpm - $msg}
		return [list 0 $msg]
	} else {
		set cpm_id [db_get_coln $rs 0 0]
		ob_db::rs_close $rs

		#
		# Perform age checks!
		#

		#Get customer acct_id
		set res [ob_db::exec_qry ob_ukash::get_acct_id $cust_id]
		set acct_id [db_get_col $res 0 acct_id]
		ob_db::rs_close $res

		#Get the country code
		set res [ob_db::exec_qry ob_ukash::get_country_code $cust_id]
		set country_code [db_get_col $res 0 country_code]
		ob_db::rs_close $res

		#Get the currency code
		set res [ob_db::exec_qry ob_ukash::get_acct_details $acct_id]
		set ccy_code [db_get_col $res 0 ccy_code]
		ob_db::rs_close $res

		if {[OT_CfgGet CARD_AGE_WTD_BLOCK 0] && [card_util::is_suspected_youth $cust_id "UKASH" $country_code $ccy_code]} {
			set txt_reason {Withdrawal blocked till age verification is done}
			card_util::set_cust_status_flag $cust_id WTD AGER $txt_reason
		}
		return [list 1 $cpm_id]
	}
}

proc ob_ukash::remove_cpm { cpm_id } {
	ob::log::write DEBUG {ob_ukash::remove_cpm($cpm_id)}

	if {[catch {set rs [ob_db::exec_qry ob_ukash::remove_cpm $cpm_id]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::remove_cpm - $msg}
		return 0
	}
	return 1
}


proc ob_ukash::insert_pmt { acct_id cpm_id payment_sort amount voucher value status ipaddr source unique_id {oper_id {}} {transactional Y} } {

	variable PMT
	variable CFG

	ob::log::write DEBUG {ob_ukash::insert_pmt($acct_id,$cpm_id,$payment_sort,$amount,$voucher,$value,$status,$ipaddr,$source,$unique_id,$oper_id,$transactional)}

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "cpm" $cpm_id]] == "ERROR"} {
		return [list 0 UKASH_ERROR]
	}

	if {$payment_sort == "W" && $pay_mthd != "UKSH"} {
		# Only Quickash supports withdrawals
		return [list 0 UKASH_ERROR]
	}

	# Retrieve the pmt gateway settings
	if {![ob_ukash::get_pmt_gateway_params $pay_mthd]} {
		return [list 0 UKASH_PMT_GWAY_ERROR]
	}

	if {$voucher ne ""} {

		# product code (currency code in digits) from unencrypted ukash voucher
		set prod_code [ob_ukash::get_voucher_ccy_code $voucher]

		set enc_voucher  [encrypt_voucher $voucher]
		set voucher_hash [hash_voucher $voucher $acct_id]

	} else {
		set prod_code    ""
		set enc_voucher  ""
		set voucher_hash ""
	}

	if {[catch {set rs [ob_db::exec_qry ob_ukash::insert_pmt \
							$pay_mthd \
							$acct_id \
							$cpm_id \
							$payment_sort \
							$amount \
							$ipaddr \
							$source \
							$unique_id \
							$PMT(pg_acct_id) \
							$status \
							$enc_voucher \
							$voucher_hash \
							$value \
							$prod_code \
							$oper_id \
							$transactional \
							$CFG(pmt_receipt_format) \
							$CFG(pmt_receipt_tag)]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::insert_pmt - $msg}
		return [list 0 $msg]
	} else {
		set pmt_id [db_get_coln $rs 0 0]
		ob_db::rs_close $rs

		if {[OT_CfgGet MONITOR 0]} {
			ob_ukash::send_monitor_msg $pmt_id $status
		}

		return [list 1 $pmt_id]
	}
}

proc ob_ukash::update_pmt {
	acct_id
	pmt_id
	status
	txn_id
	err_code
	{oper_id {}}
	{voucher {}}
	{value   {}}
	{expiry  {}}
	{flag_cancel {N}}
	{transactional Y} } {

	ob::log::write DEBUG {ob_ukash::update_pmt($acct_id,$pmt_id,$status,$txn_id,$err_code,$oper_id,$voucher,$value,$expiry,$flag_cancel,$transactional)}

	if {$voucher ne ""} {
		set enc_voucher  [encrypt_voucher $voucher]
		set voucher_hash [hash_voucher $voucher $acct_id]
	} else {
		set enc_voucher  ""
		set voucher_hash ""
	}

	if {[catch {set rs [ob_db::exec_qry ob_ukash::update_pmt \
							$pmt_id \
							$status \
							$oper_id \
							$txn_id \
							$err_code \
							$enc_voucher \
							$voucher_hash \
							$value \
							$expiry \
							$flag_cancel \
							$transactional]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::update_pmt - $msg}
		return [list 0 $msg]
	}

	if {[OT_CfgGet MONITOR 0]} {
		ob_ukash::send_monitor_msg $pmt_id $status
	}

	ob_db::rs_close $rs

	return [list 1]
}


#
# Private procedures
#

#
# Send a request to the gateway.
#
# url - the url to send the request to.
# timeout - the length of time to wait for a response.
# soap_action - SOAPaction
# data - the data to send
#
# returns - a list containing 1 and the response data
#           on success, 0 and error code on failure
#
proc ob_ukash::send_request { url timeout soap_action data } {

	set fn "ob_ukash::send_request"

	ob::log::write DEBUG {$fn ($url, $timeout, $soap_action)}

	if {[catch {
		foreach {api_scheme api_host api_port action junk junk} \
		  [ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn: bad URL ($url): $msg}
		return [list 0 UKASH_REQ_ERROR]
	}

	set headerList [list\
		"Content-Type" "text/xml; charset=utf-8" \
		"SOAPaction"   $soap_action \
	]

	if {[catch {
		set req [ob_socket::format_http_req \
			-host       $api_host \
			-method     "POST" \
			-post_data  $data \
			-headers    $headerList \
			-encoding   "utf-8" \
			$action \
		]
	} msg]} {
		ob_log::write ERROR {$fn: Unable to build request: $msg}
		return [list 0 UKASH_REQ_ERROR]
	}

	if {[catch {
		foreach {req_id status complete} \
			[ob_socket::send_req \
				-tls          1 \
				-is_http      1 \
				-conn_timeout $timeout \
				-req_timeout  $timeout \
				$req \
				$api_host \
				$api_port \
			] {break}
	} msg]} {
		ob_log::write ERROR {$fn: Unsure whether request reached Ukash: $msg}
		return [list 0 UKASH_REQ_ERROR]
	}

	if {$status != "OK"} {

		# Is there a chance this request might actually have got to Ukash?
		if {[ob_socket::server_processed $req_id]} {

			set response [ob_socket::req_info $req_id http_body]
			set response [string trim $response]

			ob_log::write ERROR {$fn:\
				Unsure whether request reached Ukash,\
				status: $status, response body:\n$response}

			ob_socket::clear_req $req_id
			return [list 0 UKASH_REQ_ERROR]
		}

		ob_socket::clear_req $req_id

		ob_log::write ERROR {$fn:\
			Unable to send request to Ukash, status: $status}

		if {$status == "CONN_TIMEOUT"} {
			ob_log::write ERROR {$fn: request timed out}
			return [list 0 UKASH_TIMEOUT]
		}

		return [list 0 UKASH_REQ_ERROR]
	}

	ob_log::write INFO {$fn: Request successful}

	set response [ob_socket::req_info $req_id http_body]
	set response [string trim $response]

	ob_socket::clear_req $req_id

	return [list 1 $response]
}

#
# Build the XML for a request
# data - the data string to be sent with the request
#
# returns - 1 and the XML to be sent on success, 0 and error code on failure
#
proc ob_ukash::build_request { type data } {
	ob::log::write DEBUG {ob_ukash::build_get_settle_amount($type,$data)}

	switch $type {
		GetSettleAmount -
		Redemption {
			# valid request types
		}
		default {
			return [list 0 UKASH_INVALID_REQUEST_TYPE]
		}
	}

	# SOAP Envelope
	set doc [dom createDocument soap:Envelope]

	set root [$doc documentElement]
	$root setAttribute \
		xmlns:xsi  {http://www.w3.org/2001/XMLSchema-instance} \
		xmlns:xsd  {http://www.w3.org/2001/XMLSchema} \
		xmlns:soap {http://schemas.xmlsoap.org/soap/envelope/}

	# SOAP Body
	set body [$doc createElement soap:Body]
	$root appendChild $body

	# GetSettleAmount parent element
	set req [$doc createElement $type]
	$req setAttribute xmlns {http://tempuri.org/UKash/Service1}
	$body appendChild $req

	# sRequest
	set sreq [$doc createElement sRequest]
	$req appendChild $sreq

	# Plug in the data as a text node (XML encoding done by tdom)
	set t [$doc createTextNode $data]
	$sreq appendChild $t

	set xml [subst {<?xml version="1.0" encoding="utf-8"?>[$root asXML -indent none]}]

	# Tidy up
	$doc delete

	return [list 1 $xml]
}

#
# Parse the XML from a response
# data - the data to parse
#
# returns - 1 and the XML data string on success, 0 and error code on failure
#
proc ob_ukash::parse_response { type data } {
	ob::log::write DEBUG {ob_ukash::parse_response($type,$data)}

	switch $type {
		GetSettleAmount -
		Redemption {
			# valid request types
		}
		default {
			return [list 0 UKASH_INVALID_REQUEST_TYPE]
		}
	}

	# Parse the response
	if {[catch {set doc [dom parse $data]} msg]} {
		ob::log::write ERROR {ob_ukash::parse_response: error in response xml - $msg}
		return [list 0 UKASH_RESP_XML_ERROR]
	}

	set root [$doc documentElement]

	# Grab the result node which is all were interested in...
	set node [$root getElementsByTagName "${type}Result"]

	# ...and the actual data
	set text_node [$node firstChild]
	set data [$text_node nodeValue]

	# Tidy up
	$doc delete

	return [list 1 $data]
}

#
# Get pmt gateway parameters for a given request.
#
proc ob_ukash::get_pmt_gateway_params {pay_mthd} {

	variable PMT

	array set PMT [array unset PMT]

	ob::log::write DEBUG {ob_ukash::get_pmt_gateway_params: $pay_mthd}

	# some value required by the pmt gateway code
	set PMT(pay_mthd) $pay_mthd

	# Get the correct payment gateway details for this payment
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT]

	# cater for PMG error
	if {![lindex $pg_result 0]} {
		ob::log::write ERROR {ob_ukash::get_pmt_gateway_params: failed to get\
			pmt gateway details - [lindex $pg_result 1]: pay_mthd = $pay_mthd}
		return 0
	}

	return 1
}

proc ob_ukash::send_monitor_msg { pmt_id status } {
	ob::log::write DEBUG {ob_ukash::send_monitor_msg($pmt_id,$status)}

	if {[ob_ukash::get_pmt $pmt_id] != 1} {
		ob::log::write ERROR {ob_ukash::send_monitor_msg - can't send monitor message}
		return 0
	}

	# get pay_mthd (UKSH/IKSH)
	if {[set pay_mthd [_get_pay_mthd "pmt" $pmt_id]] == "ERROR"} {
		return 0
	}

	set pmt_date [clock format [clock seconds] -format {%Y-%m-%d %T}]

	set DATA(type) $pay_mthd

	OB_gen_payment::send_pmt_ticker $pmt_id $pmt_date $status DATA
}

proc ob_ukash::successful_pmt { cpm_id payment_sort } {

	if {[catch {set rs [ob_db::exec_qry ob_ukash::successful_pmt $cpm_id $payment_sort]} msg]} {
		ob::log::write ERROR {Error executing query ob_ukash::successful_pmt - $msg}
		return -1

	} else {

		set nrows [db_get_nrows $rs]
		ob_db::rs_close $rs

		# if we get a row back from the query then there has been a successful deposit
		if {$nrows > 0} {
			return 1
		} else {
			return 0
		}
	}
}

proc ob_ukash::encrypt_voucher {plaintext} {

	return [ob_crypt::encrypt_by_bf $plaintext]
}

proc ob_ukash::decrypt_voucher {enc_voucher} {

	return [ob_crypt::decrypt_by_bf $enc_voucher]
}

proc ob_ukash::hash_voucher {voucher acct_id} {

	return [md5 "UKASH|$voucher|$acct_id"]
}

proc ob_ukash::record_fail_attempt {cpm_id reason} {

	ob_log::write INFO {UKASH fail attempt logged for cpm_id $cpm_id: $reason}

	if {[catch {
		ob_db::exec_qry ob_ukash::record_fail\
			$cpm_id\
			$reason\
			[OT_CfgGet MAX_UKASH_FAILS 3]
	} rs]} {
		ob_log::write ERROR {ob_ukash::record_fail_attempt: couldn't record failure: $rs}
	}

	ob_db::rs_close $rs
}


# Get specific Ukash pay_mthd (UKSH/IKSH)
#
proc ob_ukash::_get_pay_mthd {ref ref_id} {

	if {[catch {
		set rs [ob_db::exec_qry ob_ukash::get_pay_mthd_with_${ref}_id $ref_id]
	} msg]} {
		ob::log::write ERROR {Error executing query \
			ob_ukash::get_pay_mthd_with_${ref}_id: $msg}

		return "ERROR"
	}

	if {![db_get_nrows $rs]} {
		ob::log::write ERROR {ob_ukash::_get_pay_mthd: can't find pay_mthd: \
			ref = $ref, ref_id = $ref_id}

		ob_db::rs_close $rs
		return "ERROR"
	}

	set pay_mthd [db_get_col $rs 0 pay_mthd]
	ob_db::rs_close $rs

	if {[lsearch -exact {IKSH UKSH} $pay_mthd] == -1} {
		ob::log::write ERROR {ob_ukash::_get_pay_mthd: pay_mthd not supported: \
			pay_mthd = $pay_mthd}

		return "ERROR"
	}

	return $pay_mthd
}
