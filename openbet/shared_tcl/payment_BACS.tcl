# $Id: payment_BACS.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Openbet
#
# Copyright (C) 2000 Orbis Technology Ltd. All rights reserved.
#

package require pmt_validate
package require util_appcontrol

namespace eval payment_BACS {

	variable INIT 0

	namespace export init
	namespace export make_payment
	namespace export do_transaction
	namespace export transfer_funds
	namespace export auth_payment
}

proc payment_BACS::init args {
	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	ob_db::init

	payment_gateway::pmt_gtwy_init

	ob_db::store_qry bacs_pmt_insert_pmt {
		execute procedure pPmtInsBankXfer (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_extra_info = ?,
			p_transactional = ?,
			p_min_amt = ?,
			p_max_amt = ?,
			p_call_id = ?,
			p_j_op_type = ?,
			p_ref_no_offset = ?
		)
	}

	ob_db::store_qry bacs_pmt_upd_pmt {
		execute procedure pPmtUpdBankXfer (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_j_op_type = ?,
			p_transactional = ?,
			p_auth_code = ?,
			p_gw_auth_code = ?,
			p_gw_uid = ?,
			p_gw_ret_code = ?,
			p_gw_ret_msg = ?,
			p_wtd_do_auth = ?
		)
	}

	# Retrieve the just stored ref no
	# Update the payment to unknown
	ob_db::store_qry bacs_pmt_get_ref {
		execute procedure pPmtGetBACSRefNo (
			p_pmt_id = ?
		)
	}

	ob_db::store_qry bacs_pmt_update_pg_info {
		update tPmtBankXfer set
			pg_host_id = ?,
			pg_acct_id = ?,
			cp_flag = ?
		where
			pmt_id = ?
	}


	# To retrieve cust_id
	ob_db::store_qry bacs_pmt_acct_info {
		select
			a.cust_id,
			a.ccy_code,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_postcode
		from
			tAcct a,
			tCustomerReg r
		where
			a.acct_id = ?
			and a.cust_id = r.cust_id
	}

	ob_db::store_qry bacs_pmt_cpm_info {
		select
			bank_name,
			country_code,
			bank_acct_no,
			bank_sort_code,
			bank_acct_name,
			bank_branch
		from
			tCPMBankXfer
		where
			cpm_id = ?
	}
}



proc payment_BACS::make_payment {
	acct_id
	oper_id
	unique_id
	pay_sort
	amount
	cpm_id
	source
	{auth_code ""}
	{extra_info ""}
	{j_op_type ""}
	{call_id ""}
	{gw_auth_code ""}
	{admin "0"}
	{comm_list {}}
	{min_amt ""}
	{max_amt ""}
} {

	ob_log::write INFO {PMT_BACS: => payment_BACS::make_payment}

	# Check the payment sort
	if {$pay_sort != "W"} {
		return [list \
			0 \
			[payment_gateway::pmt_gtwy_xlate_err_code PMT_TYPE]\
			PMT_TYPE]
	}

	set DATA(acct_id)       $acct_id
	set DATA(oper_id)       $oper_id
	set DATA(unique_id)     $unique_id
	set DATA(pay_sort)      $pay_sort
	set DATA(cpm_id)        $cpm_id
	set DATA(source)        $source
	set DATA(auth_code)     $auth_code
	set DATA(gw_auth_code)  $gw_auth_code
	set DATA(extra_info)    $extra_info
	set DATA(j_op_type)     $j_op_type
	set DATA(call_id)       $call_id
	set DATA(transactional) "Y"
	set DATA(admin)         $admin
	set DATA(min_amt)		$min_amt
	set DATA(max_amt)		$max_amt

	ob_log::write_array DEBUG DATA

	# Grab some other data
	set result [get_data DATA]
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	ob_log::write_array DEBUG DATA

	# If commission list is empty then initialize it with 0 commission
	if {$comm_list == {}} {
		set comm_list [list 0 $amount $amount]
	}

	# Get the commission, payment amount and tPmt amount from the list
	set DATA(commission)  [lindex $comm_list 0]
	set DATA(amount)      [lindex $comm_list 1]
	set DATA(tPmt_amount) [lindex $comm_list 2]

	# Verify data and record
	set result [verify_and_record DATA]
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	# Do not send if we need to do a fraud check on the payment
	set process_pmt [ob_pmt_validate::chk_wtd_all\
		$DATA(acct_id)\
		$DATA(pmt_id)\
		"BACS"\
		"----"\
		$DATA(tPmt_amount)\
		$DATA(ccy_code)]

	if {!$process_pmt} {
		# We will process the payment later so return success
		set pmt_id $DATA(pmt_id)
		unset DATA
		return [list 1 $pmt_id ""]
	}

	# Do transaction
	set result [do_transaction DATA]
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	set pmt_id $DATA(pmt_id)
	set msg [lindex $result 1]

	unset DATA

	ob_log::write INFO {PMT_BACS: <= payment_BACS::make_payment}

	# Return the payment id
	return [list 1 $pmt_id $msg]
}



# Retrieve the account details from the database
#
proc payment_BACS::get_data {ARRAY} {

	upvar 1 $ARRAY DATA

	# In a catch block as reqGetEnv not available from affiliate manager cronjob
	set DATA(ip) "localhost"
	catch {set DATA(ip) [reqGetEnv REMOTE_ADDR]}

	# Account information
	if {[catch {
		set rs [ob_db::exec_qry bacs_pmt_acct_info $DATA(acct_id)]
	} msg]} {
		ob_log::write ERROR \
			{PMT_BACS: Error retrieving account information; $msg}
		return [list 0 "Could not retrieve account information: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		return [list \
			0 \
			[payment_gateway::pmt_gtwy_xlate_err_code PMT_NOCCY] \
			PMT_NOCCY]
	}

	set DATA(ccy_code) [db_get_col $rs 0 ccy_code]
	set DATA(cust_id)  [db_get_col $rs 0 cust_id]

	## Needed for DCASH XML calls
	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set DATA(addr_1)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_1]]
		set DATA(addr_2)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_2]]
		set DATA(addr_4)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_4]]
	} else {
		set DATA(addr_1)  [db_get_col $rs 0 addr_street_1]
		set DATA(addr_2)  [db_get_col $rs 0 addr_street_2]
		set DATA(addr_4)  [db_get_col $rs 0 addr_street_4]
	}
	
	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set DATA(addr_1)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_1] 0 0]
		set DATA(addr_2)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_2] 0 0]
		set DATA(addr_4)  [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_4] 0 0]
	} else {
		set DATA(addr_1)  [db_get_col $rs 0 addr_street_1]
		set DATA(addr_2)  [db_get_col $rs 0 addr_street_2]
		set DATA(addr_4)  [db_get_col $rs 0 addr_street_4]
	}
	set DATA(addr_3)   [db_get_col $rs 0 addr_street_3]
	set DATA(postcode) [db_get_col $rs 0 addr_postcode]

	ob_db::rs_close $rs

	#
	# cpm information
	#
	if [catch {
		set rs [ob_db::exec_qry bacs_pmt_cpm_info $DATA(cpm_id)]
	} msg] {
		ob_log::write ERROR \
			{PMT_BACS: Error retrieving account information; $msg}
		return [list 0 "Could not retrieve account information: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		return [list \
			0 \
			[payment_gateway::pmt_gtwy_xlate_err_code PMT_NO_CPM]\
			PMT_NO_CPM]
	}

	set DATA(bank_name)      [db_get_col $rs 0 bank_name]
	set DATA(country_code)   [db_get_col $rs 0 country_code]
	set DATA(bank_acct_no)   [db_get_col $rs 0 bank_acct_no]
	set DATA(bank_sort_code) [db_get_col $rs 0 bank_sort_code]
	set DATA(bank_acct_name) [db_get_col $rs 0 bank_acct_name]
	set DATA(bank_branch)    [db_get_col $rs 0 bank_branch]
	set DATA(pay_mthd)       "BACS"

	return [list 1]
}



proc payment_BACS::do_transaction {ARRAY} {

	upvar 1 $ARRAY DATA

	ob_log::write INFO {PMT_BACS: => payment_BACS::do_transaction}

	# Get the time payment started
	set time               [clock seconds]
	set DATA(payment_date) [clock format $time -format "%Y-%m-%d"]
	set DATA(payment_time) [clock format $time -format "%H:%M:%S"]

	# Set array variables to blanks for cases where payment exits before they are created
	set DATA(status)          " "
	set DATA(auth_date)       " "
	set DATA(auth_time)       " "
	set DATA(gw_auth_code)    " "
	set DATA(gw_ret_code)     " "
	set DATA(gw_ret_msg)      " "
	set DATA(gw_redirect_url) ""

	# Overrride CC specific stuff for payment_gateway
	set DATA(country)     ""
	set DATA(card_type)   ""
	set DATA(card_scheme) ""
	set DATA(bank)        ""
	set DATA(card_bin)    ""
	set DATA(start)       ""
	set DATA(start)       ""
	set DATA(expiry)      ""
	set DATA(issue_no)    ""

	ob_log::write DEBUG {--------Payment Details----------}
	ob_log::write_array DEBUG DATA
	ob_log::write DEBUG {---------------------------------}

	# Get the correct payment gateway details for this payment
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param DATA]

	if {[lindex $pg_result 0] == 0} {
		set msg [lindex $pg_result 1]
		ob_log::write ERROR {PMT_BACS: Payment Rules Failed: $msg}
		set DATA(status) N

		# Update the payment table as failed payment
		cc_pmt_auth_payment \
			$DATA(pmt_id) \
			$DATA(status) \
			$DATA(oper_id) \
			$DATA(transactional) \
			$DATA(auth_code) \
			"" \
			"" \
			"" \
			"Payment Rules Failed : $msg" \
			"" \
			$DATA(j_op_type)
		return [list 0 "Payment Rules Failed : $msg" PMT_ERR $DATA(pmt_id)]
	}

	# Set the pg_host_id, pg_acct_id and cp_flag just prior to making the
	# payment
	if {[catch {
		set rs [ob_db::exec_qry bacs_pmt_update_pg_info \
			$DATA(pg_host_id) \
			$DATA(pg_acct_id) \
			$DATA(cp_flag) \
			$DATA(pmt_id)]
	} msg]} {
		ob_log::write ERROR \
			{PMT_BACS: Error recording payment gateway parameters; $msg}
		return [list \
			0 \
			"Could not record payment gateway parameters: $msg"\
			PMT_ERR \
			$DATA(pmt_id)]
	}

	# Grab the ref_no (generated during insert pmt) and mark payment status as
	# unknown
	if {[catch {
		set rs [ob_db::exec_qry bacs_pmt_get_ref $DATA(pmt_id)]
	} msg]} {
		ob_log::write ERROR {PMT_BACS: Error retrieving ref; $msg}
		return [list 0 "Could not retrieve ref: $msg" PMT_ERR $DATA(pmt_id)]
	}

	set apacs_ref       [db_get_coln $rs 0 0]
	set DATA(apacs_ref) $apacs_ref

	ob_db::rs_close $rs

	# Contact payment gateway
	set result [payment_gateway::pmt_gtwy_do_payment DATA]

	set DATA(message) ""

	ob_log::write INFO {PMT_BACS: result: $result}
	set time [clock seconds]

	# Process the result
	if {$result == "PMT_RESP"} {
		return [list \
			0 \
			[payment_gateway::pmt_gtwy_xlate_err_code $result]\
			$result \
			$DATA(pmt_id)]
	} elseif {$result == "OK"} {
		set DATA(status) Y
		set DATA(auth_date) [clock format $time -format "%Y-%m-%d"]
		set DATA(auth_time) [clock format $time -format "%H:%M:%S"]
	} else {
		set DATA(status) N
		set DATA(auth_date) " "
		set DATA(auth_time) " "
	}

	if {$DATA(status) != "Y" && $result == "PMT_REFER" && $DATA(admin)} {
		set no_settle 1
	} else {
		set no_settle 0
	}

	# Update the payment table whatever the response
	auth_payment \
		$DATA(pmt_id) \
		$DATA(status) \
		$DATA(oper_id) \
		$DATA(transactional) \
		$DATA(auth_code) \
		$DATA(gw_auth_code) \
		$DATA(gw_uid) \
		$DATA(gw_ret_code) \
		$DATA(gw_ret_msg) \
		$DATA(apacs_ref) \
		$DATA(j_op_type) \
		$no_settle

	if {$DATA(status) != "Y"} {
		return [list \
			0 \
			[payment_gateway::pmt_gtwy_xlate_err_code $result]\
			$result \
			$DATA(pmt_id)]
	}

	ob_log::write INFO {PMT_BACS: <= payment_BACS::do_transaction}

	return [list 1 [payment_gateway::pmt_gtwy_xlate_err_code $DATA(message)]]
}

proc payment_BACS::auth_payment {
	pmt_id
	status
	oper_id
	transactional
	auth_code
	gw_auth_code
	gw_uid
	gw_ret_code
	gw_ret_msg
	ref_no
	j_op_type
	{no_settle 0}
} {

	# Ignore the no_settle flag
	if [catch {
		set rs [ob_db::exec_qry bacs_pmt_upd_pmt \
			$pmt_id \
			$status \
			$oper_id \
			$j_op_type \
			$transactional \
			$auth_code \
			$gw_auth_code \
			$gw_uid \
			$gw_ret_code \
			$gw_ret_msg \
			[OT_CfgGet DCASH_WTD_DO_AUTH N]]
	} msg] {

		ob_log::write ERROR {PMT_BACS: >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
		ob_log::write ERROR {PMT_BACS: Error updating payment record; $msg}
		ob_log::write ERROR {PMT_BACS: >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

		return [list 0 $msg PMT_ERR]
	}
	catch {
		ob_db::rs_close $rs
	}

	return [list 1]
}



proc payment_BACS::verify_and_record {ARRAY} {

	global DB

	upvar 1 $ARRAY DATA

	ob_log::write DEBUG {PMT_BACS: proc payment_BACS::verify_and_record}

	# Insert the payment record
	set result [insert_payment \
		$DATA(acct_id) \
		$DATA(cpm_id) \
		$DATA(pay_sort) \
		$DATA(tPmt_amount) \
		$DATA(commission) \
		$DATA(ip) \
		$DATA(source) \
		$DATA(oper_id) \
		$DATA(unique_id) \
		$DATA(extra_info) \
		$DATA(transactional) \
		$DATA(min_amt) \
		$DATA(max_amt) \
		$DATA(call_id) \
		$DATA(j_op_type)]
	if {![lindex $result 0]} {
		set code [payment_gateway::cc_pmt_get_sp_err_code [lindex $result 1]]
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
	}

	set DATA(pmt_id) [lindex $result 1]

	return [list 1]
}


proc payment_BACS::insert_payment {
	acct_id
	cpm_id
	pay_sort
	amount
	commission
	ip
	source
	oper_id
	unique_id
	extra_info
	transactional
	min_amt
	max_amt
	call_id
	j_op_type
} {
	# The number returned by pGenApacsUID is padded with zeroes and prefixed
	# with a number from the config file.  This ensure that systems that use
	# different databases but talk to the same payment gateway don't overlap
	# payment reference numbers.

	global _ref_no_offset

	if {![info exists _ref_no_offset]} {
		set _ref_no_offset [OT_CfgGet REF_NO_PREFIX 1]

		# We'll make sure not to exceed the INT precision
		if {$_ref_no_offset == 1} {
			set offset_length 10
		} else {
			set offset_length 9
		}

		set pad_len [expr $offset_length - [string length $_ref_no_offset]]
		for {set i 0} {$i < $pad_len} {incr i} {
			append _ref_no_offset "0"
		}

		if {[string length $_ref_no_offset] > 10} {
			ob_log::write ERROR \
				{PMT_BACS: Error generating ref_no_offset - too long $ref_no_offset}
			unset _ref_no_offset
			return [list 0 ""]
		}
	}


	if {[catch {
		set rs [ob_db::exec_qry bacs_pmt_insert_pmt \
			$acct_id \
			$cpm_id \
			$pay_sort \
			$amount \
			$commission \
			$ip \
			$source \
			$oper_id \
			$unique_id \
			$extra_info \
			$transactional \
			$min_amt \
			$max_amt \
			$call_id \
			$j_op_type \
			$_ref_no_offset]
	} msg]} {
		ob_log::write ERROR {PMT_BACS: Error inserting payment record; $msg}
		return [list 0 $msg]
	}

	# Return the payment id
	set pmt_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs
	return [list 1 $pmt_id]
}
