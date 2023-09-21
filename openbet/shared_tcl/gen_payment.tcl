# $Id: gen_payment.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# Creates Customer payment methods and inserts and authorises new payments
# Normal procedure:
#	1. call OB_gen_payment::prepare_gen_pmt_qrys once to prepare the queries
#	2. reset the variable ::OB_gen_payment::GEN_PMT (for adding a payment)
#                         ::OB_gen_payment::GEN_MTHD (for adding a mthod)
#	3. set the required fields in either the array GEN_PMT or GEN_MTHD
#	4. call add_gen_wtd or add_gen_dep to add a payment,
#	   ins_cust_method to add a new method
#	5. expect a list to be returned - element 0: status, element 1: id

package require pmt_validate
package require util_appcontrol

namespace eval OB_gen_payment {

	# GEN_PMT fields
	#
	# REQUIRED FIELDS
	#
	#	GEN_PMT(TYPE): Mthod type CHQ,TT,XP,BANK.CSH
	#	GEN_PMT(amount) - has to be > 0
	#	GEN_PMT(acct_id)
	#	GEN_PMT(cpm_id)
	#	GEN_PMT(source)
	#	GEN_PMT(ccy_code)
	#
	# NON MANDATORY FIELDS
	#
	#	GEN_PMT(unique_id)  - can be specified to make sure a page isn't
	#	                      submitted twice
	#	GEN_PMT(ref_key)    - can be added as a double check against cpm_id
	#	GEN_PMT(oper_id)    - telebet or admin screen operator id
	#	GEN_PMT(auth_code)  - optional authorisation code to store against the
	#	                      payment
	#	GEN_PMT(oper_notes) - optional operator notes about the payment
	#
	# Cash payment information
	#
	#	GEN_PMT(collect_time)
	#	GEN_PMT(extra_info)
	#
	# CHQ TT and XP info
	#
	#	GEN_PMT(cheque_date)
	#	GEN_PMT(cheque_number)
	#	GEN_PMT(rec_delivery_ref)
	#
	# Bank payment extra info
	#
	#	GEN_PMT(bank_code)
	#
	# Western union extra info
	#
	#	GEN_PMT(wu_code)

	variable GEN_PMT
	namespace export GEN_PMT

	# GEN_MTHD fields
	#
	# REQUIRED FIELDS
	#
	#	GEN_MTHD(TYPE): Mthod type CHQ,TT,XP,BANK.CSH
	#	GEN_MTHD(CUST_ID)
	#
	# NON MANDATORY FIELDS
	#
	#	GEN_MTHD(DEP_STATUS) - defaults to P:
	#		P(Pending),
	#		Y(Authorised),
	#		N(Not Authorised),
	#		E Exclusive,
	#		M Method Exclusivity
	#
	# External Accounts
	#
	#	GEN_MTHD(WTD_STATUS) P, Y, N, M, E -defaults to P
	#	GEN_MTHD(CODE) - External account type,
	#	GEN_MTHD(ACCT_NO) - External Account number
	#
	# Cheque methods
	#
	#	GEN_MTHD(PAYEE)
	#	GEN_MTHD(ADDR_1)
	#	GEN_MTHD(ADDR_2)
	#	GEN_MTHD(ADDR_3)
	#	GEN_MTHD(ADDR_4)
	#	GEN_MTHD(ADDR_CITY)
	#	GEN_MTHD(ADDR_POSTCODE)
	#	GEN_MTHD(COUNTRY_CODE)
	#
	# Cash
	#
	#	GEN_MTHD(OUTLET) Outlet id
	#
	# Bank
	#
	#	GEN_MTHD(BANK_NAME)
	#	GEN_MTHD(ADDR_1)
	#	GEN_MTHD(ADDR_2)
	#	GEN_MTHD(ADDR_3)
	#	GEN_MTHD(ADDR_4)
	#	GEN_MTHD(ADDR_CITY)
	#	GEN_MTHD(COUNTRY_CODE)
	#	GEN_MTHD(ADDR_POSTCODE)
	#	GEN_MTHD(ACCT_NAME)
	#	GEN_MTHD(ACCT_NO)
	#	GEN_MTHD(SORT_CODE)

	variable GEN_MTHD
	namespace export GEN_MTHD

	variable GEN_PMT_CHKD "N"

	namespace export prepare_gen_pmt_qrys
	namespace export add_pmt_wtd
	namespace export add_pmt_dep
	namespace export auth_txn
	namespace export ins_cust_method
	namespace export get_cust_mthd_ids
	namespace export get_num_active_cust_cpms
	namespace export get_active_cpm_ids
	namespace export send_pmt_method_registered


	array set ERR_CODE [list\
		5006  WTD_INSUFFICIENT_FUNDS\
		8206  WTD_NEED_PAYER_ID\
		5010  CURR_SUSPENDED\
		5004  ACCOUNT_NOT_FOUND\
		5002  ACCOUNT_CLOSED]
}



# Prepares the general payment queries
proc OB_gen_payment::prepare_gen_pmt_qrys {} {

	ob_db::store_qry OB_gen_payment::txn_bank {
		execute procedure pPmtInsBank (
			p_payment_sort   = ?,
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_amount         = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_transactional  = ?,
			p_oper_id        = ?,
			p_code           = ?,
			p_extra_info     = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?
		 )
	}

	ob_db::store_qry OB_gen_payment::txn_chq {
		execute procedure pPmtInsChq (
			p_payment_sort     = ?,
			p_acct_id          = ?,
			p_cpm_id           = ?,
			p_amount           = ?,
			p_ipaddr           = ?,
			p_source           = ?,
			p_transactional    = ?,
			p_oper_id          = ?,
			p_chq_date         = ?,
			p_chq_no           = ?,
			p_rec_delivery_ref = ?,
			p_receipt_format   = ?,
			p_receipt_tag      = ?
		 )
	}

	ob_db::store_qry OB_gen_payment::check_for_existing_cpms {
		select
			m.cpm_id
		from
			tCustPayMthd m
		where
			m.cust_id = ?
		and m.status  = "A"
	}

#    ob_db::store_qry OB_gen_payment::txn_csh {
#        execute procedure pPmtInsCsh (
#           p_payment_sort=?,
#           p_acct_id=?,
#           p_cpm_id=?,
#           p_amount=?,
#           p_ipaddr=?,
#           p_source=?,
#           p_transactional=?,
#           p_oper_id=?,
#           p_collect_time=?,
#           p_extra_info=?
#         )
#    }

#    ob_db::store_qry OB_gen_payment::txn_wu {
#        execute procedure pPmtInsWU (
#           p_payment_sort=?,
#           p_acct_id=?,
#           p_cpm_id=?,
#           p_amount=?,
#           p_ipaddr=?,
#           p_source=?,
#           p_transactional=?,
#           p_oper_id=?,
#           p_wu_code=?,
#           p_extra_info=?
#         )
#    }

#    ob_db::store_qry OB_gen_payment::txn_ext {
#        execute procedure pPmtInsExtAcc (
#           p_payment_sort=?,
#           p_acct_id=?,
#           p_cpm_id=?,
#           p_amount=?,
#           p_ipaddr=?,
#           p_source=?,
#           p_transactional=?,
#           p_oper_id=?,
#           p_extra_info = ?
#         )
#    }

	ob_db::store_qry OB_gen_payment::auth_txn {
		execute procedure pPmtUpd (
			p_pmt_id        = ?,
			p_status        = ?,
			p_oper_id       = ?,
			p_auth_code     = ?,
			p_transactional = ?
		)
	}

	ob_db::store_qry OB_gen_payment::reverse_wtd {
		execute procedure pPmtReverseWtd (
			p_pmt_id        = ?,
			p_status        = ?,
			p_adminuser     = ?,
			p_transactional = ?
		)
	}

	ob_db::store_qry OB_gen_payment::ins_cust_extrnlacc {
		EXECUTE PROCEDURE pCPMInsExtAcc(
			p_cust_id   = ?,
			p_acct_type = ?,
			p_acct_no   = ?,
			p_auth_dep  = ?,
			p_auth_wtd  = ?
		)
	}

	ob_db::store_qry OB_gen_payment::ins_cust_bank {
		EXECUTE PROCEDURE pCPMInsBank(
			p_cust_id        = ?,
			p_bank_name      = ?,
			p_bank_addr_1    = ?,
			p_bank_addr_2    = ?,
			p_bank_addr_3    = ?,
			p_bank_addr_4    = ?,
			p_bank_addr_city = ?,
			p_bank_addr_pc   = ?,
			p_country_code   = ?,
			p_bank_acct_name = ?,
			p_bank_acct_no   = ?,
			p_bank_sort_code = ?,
			p_bank_branch    = ?
		)
	}

	ob_db::store_qry OB_gen_payment::ins_cust_chq {
		EXECUTE PROCEDURE pCPMInsChq(
			p_cust_id       = ?,
			p_payee         = ?,
			p_addr_street_1 = ?,
			p_addr_street_2 = ?,
			p_addr_street_3 = ?,
			p_addr_street_4 = ?,
			p_addr_city     = ?,
			p_addr_postcode = ?,
			p_country_code  = ?
		)
	}

	ob_db::store_qry OB_gen_payment::ins_cust_csh {
		EXECUTE PROCEDURE pCPMInsCsh(
			p_cust_id  = ?,
			p_auth_dep = ?,
			p_auth_wtd = ?
		)
	}

	ob_db::store_qry OB_gen_payment::get_cust_mthd_ids {
		select
		   cpm_id
		from
		   tCustPayMthd
		where
			cust_id  =  ?
		and pay_mthd =  ?
		and auth_dep in (?, ?, ?)
		and auth_wtd in (?, ?, ?)
	}

	ob_db::store_qry OB_gen_payment::get_active_cpm_ids {
		select
		   cpm_id
		from
		   tCustPayMthd
		where
			cust_id = ?
		and pay_mthd = ?
		and status = 'A'
		order by cpm_id desc
	}

	ob_db::store_qry OB_gen_payment::get_ticker_details {
		select
			c.username,
			r.fname,
			r.lname,
			c.cr_date,
			r.code,
			r.addr_postcode,
			r.addr_street_1,
			r.addr_city,
			r.telephone,
			r.gender,
			r.dob,
			r.email,
			c.notifyable,
			c.country_code,
			a.ccy_code,
			cc.exch_rate,
			c.liab_group
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			tCCY cc
		where
			c.cust_id  = ? and
			c.cust_id  = a.cust_id and
			c.cust_id  = r.cust_id and
			a.ccy_code = cc.ccy_code
	}
}



# Adds a generic withdrawal
#
#	auth -
#		N: payment is added without being authorised
#		Y: attempt will be made to authorise the payment
#
#	returns a list - element 0 status (success = OK), element 1 gen_pmt_id
#
# NB. GEN_PMT fields need to be set before calling the procedure
#
proc OB_gen_payment::add_pmt_wtd {{auth N}} {

	variable GEN_PMT
	variable GEN_PMT_CHKD

	set GEN_PMT_CHKD N

	set GEN_PMT(payment_sort) "W"

	set fmt_ret [format_pay_input]
	if {$fmt_ret != "OK"} {
		return [list $fmt_ret ""]
	}
	set GEN_PMT_CHKD Y

	add_pmt_txn $auth
}



# Adds a generic deposit
#	auth -
#		N: payment is added without being authorised
#		Y: attempt will be made to authorise the payment
#
#	returns a list: element 0 status (success = OK), element 1 gen_pmt_id
#
# NB. GEN_PMT fields need to be set before calling the procedure
#
proc OB_gen_payment::add_pmt_dep {{auth N}} {

	variable GEN_PMT
	variable GEN_PMT_CHKD

	set GEN_PMT_CHKD N

	set GEN_PMT(payment_sort) "D"

	set fmt_ret [format_pay_input]
	if {$fmt_ret != "OK"} {
		return [list $fmt_ret ""]
	}
	set GEN_PMT_CHKD Y

	add_pmt_txn $auth
}



# Authorises a pending generic payment
#	txn_code - generic payment id
#	status   - Y authorised N not authorised
#
#	returns a list: element 0 status (success = OK), element 1 gen_pmt_id
#
# NB. GEN_PMT fields need to be set before calling the procedure
#
proc OB_gen_payment::auth_gen_txn {txn_code {status Y} {prcd_trans Y} } {

	variable GEN_PMT
	variable GEN_PMT_CHKD

	if {$GEN_PMT_CHKD == "Y"} {
		#reset the flag
		set GEN_PMT_CHKD "N"
	} else {
		set fmt_ret [format_pay_input]
		if {$fmt_ret != "OK"} {
			return [list $fmt_ret ""]
		}
	}

	# Nullable fields
	if {![info exists GEN_PMT(auth_code)]} {
		set GEN_PMT(auth_code) ""
	}

	if {![info exists GEN_PMT(oper_notes)]} {
		set GEN_PMT(oper_notes) ""
	}

	ob_log::write INFO {gen_payment: authorising payment for ref: $txn_code}

	set err [catch {
		set rs [ob_db::exec_qry OB_gen_payment::auth_txn \
			$txn_code\
			$status\
			$GEN_PMT(oper_id)\
			$GEN_PMT(auth_code)\
			$prcd_trans]
	} msg]

	if {$err != 0} {
		return [list $msg $txn_code]
	} else {
		return [list OK $txn_code]
	}
}



# Interface for inserting new customer payment methods
#
#	returns a list: element 0 status (success = OK), element 1 mthd_id
#
# NB. It is the responsibility of the calling function to set and reset the
# variable GEN_MTHD
#
proc OB_gen_payment::ins_cust_method {} {

	ob_log::write DEBUG {gen_payment: ==>OB_gen_payment::ins_cust_method}

	variable GEN_MTHD

	#required fields
	if {!([info exists GEN_MTHD(TYPE)])} {
		return [list "MTHD_ERR_NO_ID" ""]
	}

	if {!([info exists GEN_MTHD(CUST_ID)])} {
		return [list "MTHD_ERR_NO_CUST_ID" ""]
	}

	#default fields
	foreach field {DEP_STATUS WTD_STATUS} {
		if {!([info exists GEN_MTHD($field)])} {
			set GEN_MTHD($field) "P"
		}
	}

	if {($GEN_MTHD(TYPE) == "MJC")
		|| ($GEN_MTHD(TYPE) == "CDM")
	} {

		return [ins_extrnl_acc]

	} elseif {($GEN_MTHD(TYPE) == "CHQ")
		|| ($GEN_MTHD(TYPE) == "TT")
		|| ($GEN_MTHD(TYPE)  == "XP")
	} {

		return [ins_chq]

	} elseif {$GEN_MTHD(TYPE) == "BANK"} {

		return [ins_bank]

	}  elseif {($GEN_MTHD(TYPE) == "CSH")
		|| ($GEN_MTHD(TYPE) == "CSHC")
	} {

		return [ins_csh]
	}

	return [list "MTHD_ERR_BAD_MTHD" ""]
}



# This procedure will return the method ids for a particular status set up for
# this type
#
#	mthd   - BANK CHQ CSH etc.
#	txn    - dep or wtd
#	status - Y (Allowed) N(Disallowed) P(Pending)
#
proc OB_gen_payment::get_cust_mthd_ids {cust mthd txn {status A}} {

	if {($txn != "dep") && ($txn != "wtd")} {
		return [list "MTHD_ERR_TXN_TYPE" ""]
	}

	if {($status != "Y") && ($status != "N") && ($status != "P") } {
		return [list "MTHD_ERR_TXN_STATUS" ""]
	}

	if {$txn == "dep"} {
		set arg_list [list $cust $mthd $status $status $status Y N P $mthd]
	} else {
		set arg_list [list $cust $mthd Y N P $status $status $status $mthd]
	}

	if {[catch {
		set rs [eval ob_db::exec_qry OB_gen_payment::get_cust_mthd_ids \
			$arg_list]
	} msg]} {
		return [list "MTHD_ERR_INTERNAL" ""]
	}

	if {[db_get_nrows $rs] <= 0} {
		ob_db::rs_close $rs
		return [list GEN_ERR_NO_MTHD 0]
	}

	return [list OK $rs]
}



# Returns CPM IDs for a customer's active pay method.
#
#	cust_id - a customer's customer ID
#	mthd    - type of customer pay method choose one from {BANK,CC,CHQ ....}
#
proc OB_gen_payment::get_active_cpm_ids {cust_id mthd} {

	# Execute the query
	if {[catch {
		set rs [eval ob_db::exec_qry OB_gen_payment::get_active_cpm_ids \
			$cust_id \
			$mthd]
	} msg]} {
		ob_log::write ERROR {query OB_gen_payment::get_active_cpm_ids failed: $msg}
		return [list "MTHD_ERR_INTERNAL" ""]
	}

	# Return the result
	if {[db_get_nrows $rs] <= 0} {
		return [list GEN_ERR_NO_MTHD 0]
	}
	return [list OK [db_get_col $rs 0 cpm_id]]
}



# Returns the number of existing Pay Methods for a customer
#
#	cust_id - a customer's customer id
#
proc OB_gen_payment::get_num_active_cust_cpms {cust_id} {

	ob_log::write DEBUG {==>get_num_active_cust_cpms}

	# Execute query checking for existing payment methods
	if {[catch {
		set result [ob_db::exec_qry OB_gen_payment::check_for_existing_cpms \
			$cust_id]
	} msg]} {
		ob_log::write ERROR \
			{gen_payment: Failed to exec qry check_for_existing_cpms: $msg}
		return -1
	}

	ob_log::write DEBUG {gen_payment: <==get_num_active_cust_cpms}
	set nrows [db_get_nrows $result]

	ob_db::rs_close $result

	return $nrows
}



# Send ticker with information about this fraud screening
#
proc OB_gen_payment::send_pmt_method_registered {
	cust_id
	channel
	amount
	pmt_method
	cpm_id
	generic_pmt_mthd_id
	pmt_mthd_other
	args
} {

	global DB

	if {![OT_CfgGet MONITOR 0]} { return }

	if {[catch {
		set res [ob_db::exec_qry OB_gen_payment::get_ticker_details $cust_id]
	} msg]} {
		ob_log::write ERROR \
			{gen_payment: Failed to get monitor information: $msg}
		return
	}

	# Get values from db query
	set cust_uname         [db_get_col $res username]
	set cust_fname         [db_get_col $res fname]
	set cust_lname         [db_get_col $res lname]
	set cust_reg_date      [db_get_col $res cr_date]
	set cust_reg_code      [db_get_col $res code]
	set cust_reg_postcode  [db_get_col $res addr_postcode]
	set cust_reg_email     [db_get_col $res email]
	set cust_is_notifiable [db_get_col $res notifyable]
	set country_code       [db_get_col $res country_code]
	set ccy_code           [db_get_col $res ccy_code]
	set liab_group         [db_get_col $res liab_group]
	set exch_rate          [db_get_col $res exch_rate]

	set liab_group [db_get_col $res liab_group]

	ob_db::rs_close $res

	# Can only carry out country/ip checks for internet customers
	if {
		[string equal $channel "I"] && [OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK]
	} {

		OB::country_check::cookie_check $cust_id

		set ip_city           $OB::country_check::IP_CHECK_RESULTS(ip_city)
		set ip_country        $OB::country_check::IP_CHECK_RESULTS(ip_country)
		set ip_routing_method $OB::country_check::IP_CHECK_RESULTS(ip_routing)
		set country_cf        $OB::country_check::IP_CHECK_RESULTS(country_cf)

	} else {
		foreach var {ip_city ip_country ip_routing_method country_cf} {
			set $var ""
		}
	}

	# Convert user amount into system ccy
	if {![string equal $amount "N/A"]} {
		set amount_sys [expr {$amount / $exch_rate}]
		set amount_sys [format "%.2f" $amount_sys]
	} else {
		set amount_sys "N/A"
	}

	if {[catch {
		set res [ob_db::exec_qry OB_gen_payment::check_for_existing_cpms \
			$cust_id]
	} msg]} {
		ob_log::write ERROR \
			{gen_payment: Failed to get number of active payment methods: $msg}
		return
	}

	set pmt_method_count [db_get_nrows $res]

	ob_db::rs_close $res

	# send to monitor
	eval {MONITOR::send_pmt_method_registered \
		$cust_id \
		$cust_uname \
		$cust_fname \
		$cust_lname \
		$cust_reg_date \
		$cust_reg_code \
		$cust_reg_postcode \
		$cust_reg_email \
		$cust_is_notifiable \
		$country_code \
		$ccy_code \
		$channel \
		$amount \
		$amount_sys \
		$ip_city \
		$ip_country \
		$ip_routing_method \
		$country_cf \
		$liab_group \
		$pmt_method \
		$cpm_id \
		$pmt_method_count \
		$generic_pmt_mthd_id \
		$pmt_mthd_other
	} $args
}



proc OB_gen_payment::format_pay_input {} {

	variable GEN_PMT

	# NB. Most of the validation is done within the stored procedures

	# Check amount has been set up and is positive
	if { ![info exist GEN_PMT(amount)]} {
		return GEN_ERR_NO_AMOUNT
	}
	if {$GEN_PMT(amount) < 0} {
		return GEN_ERR_NEG_AMOUNT
	}

	# Get the ip address
	set GEN_PMT(ipaddr) [reqGetEnv REMOTE_ADDR]

	# Receipt formatting options - This may not be the best place to do this...
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set GEN_PMT(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set GEN_PMT(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set GEN_PMT(pmt_receipt_format) 0
		set GEN_PMT(pmt_receipt_tag)    ""
	}
	

	ob_log::write INFO {gen_payment: Adding payment of type is $GEN_PMT(type)}

	switch -- $GEN_PMT(type) {
		"BANK" {

			set GEN_PMT(qry) txn_bank
			set extra_fields {bank_code extra_info pmt_receipt_format pmt_receipt_tag}
		}
		"CHQ" {
			set GEN_PMT(qry) txn_chq
			set extra_fields {cheque_date cheque_number rec_delivery_ref pmt_receipt_format pmt_receipt_tag}
		}
		"XP" {
			set GEN_PMT(qry) txn_chq
			set extra_fields {cheque_date cheque_number rec_delivery_ref}
		}
		"TT" {
			set GEN_PMT(qry) txn_chq
			set extra_fields {cheque_date cheque_number rec_delivery_ref}
		}
		"CSH" {
			set GEN_PMT(qry) txn_csh
			set extra_fields {collect_time extra_info}
		}
		"CSHC" {
			set GEN_PMT(qry) txn_csh
			set extra_fields {collect_time extra_info}
		}
		"WU" {
			set GEN_PMT(qry) txn_wu
			set extra_fields {wu_code extra_info}
		}
		"MJC" {
			set GEN_PMT(qry) txn_ext
			set extra_fields {extra_info}
		}
		"CDM" {
			set GEN_PMT(qry) txn_ext
			set extra_fields {extra_info}
		}
	}

	set GEN_PMT(extra_fields) [list]
	foreach field $extra_fields {
		if {![info exists GEN_PMT($field)]} {
			set GEN_PMT($field) ""
		}
		lappend GEN_PMT(extra_fields) $GEN_PMT($field)
	}

	return OK
}



proc OB_gen_payment::add_pmt_txn {{auth N}} {
	variable GEN_PMT

	if {![info exists GEN_PMT(transactional)]} {
		set GEN_PMT(transactional) "Y"
	}

	ob_log::write INFO {gen_payment: In add_pmt_txn:}
	ob_log::write INFO {gen_payment:	transactional: $GEN_PMT(transactional)}
	ob_log::write INFO {gen_payment:	auth: $auth}

	if {($GEN_PMT(transactional) == "Y") && ($auth == "Y")} {
		ob_db::begin_tran
		set prcd_trans "N"
	} elseif {($GEN_PMT(transactional) == "Y") && ($auth == "N")} {
		set prcd_trans "Y"
	} else {
		set prcd_trans "N"
	}


	set err [catch {
		ob_log::write INFO {gen_payment: Generating payment}
		ob_log::write INFO {gen_payment:	acct:$GEN_PMT(acct_id)}
		ob_log::write INFO {gen_payment: 	amount: $GEN_PMT(amount)}

		ob_log::write_array DEV GEN_PMT

		set rs [eval ob_db::exec_qry OB_gen_payment::$GEN_PMT(qry) \
			$GEN_PMT(payment_sort)\
			$GEN_PMT(acct_id)\
			$GEN_PMT(cpm_id)\
			$GEN_PMT(amount)\
			$GEN_PMT(ipaddr)\
			$GEN_PMT(source)\
			$prcd_trans\
			$GEN_PMT(extra_fields)\
	]} msg]

	if {$err != 0} {
		catch {db_rollback_tran}
		ob_log::write ERROR {gen_payment: Generation of payment failed: $msg}
		return [list $msg ""]
	}

	set txn_code [db_get_coln $rs 0 0]

	ob_db::rs_close $rs

	set process_pmt 1

	if {$GEN_PMT(payment_sort) == "W"} {
		set process_pmt [ob_pmt_validate::chk_wtd_all\
			$GEN_PMT(acct_id)\
			$txn_code\
			$GEN_PMT(type)\
			"----"\
			$GEN_PMT(amount)\
			$GEN_PMT(ccy_code)]
	}

	if {$process_pmt && $auth == "Y"} {
		set auth_ret [lindex [auth_gen_txn $txn_code Y N] 0]
		if {$auth_ret != "OK"} {
			catch {ob_db::rollback_tran}
			return [list $auth_ret ""]
		} elseif {$GEN_PMT(transactional) == "Y"} {
			ob_db::commit_tran
		}
	}

	return [list OK $txn_code]
}



proc OB_gen_payment::ins_extrnl_acc {} {

	variable GEN_MTHD

	set GEN_MTHD(qry) txn_extrnl

	#required fields
	if {!([info exists GEN_MTHD(ACCT_NO)])} {
		return [list "PMT_ERR_NO_ACCT" ""]
	}

	if {[catch {
		set rs [ob_db::exec_qry OB_gen_payment::ins_cust_extrnlacc \
			$GEN_MTHD(CUST_ID)\
			$GEN_MTHD(TYPE)\
			$GEN_MTHD(ACCT_NO)\
			$GEN_MTHD(CODE)\
			$GEN_MTHD(DEP_STATUS)\
			$GEN_MTHD(WTD_STATUS)]
	} msg]} {
		catch {
			ob_db::rs_close $rs
		}
		return [list $msg ""]
	}

	set method_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs
	return [list OK $method_id]
}



proc OB_gen_payment::ins_chq {} {

	variable GEN_MTHD

	set GEN_MTHD(qry) txn_chq

	# Nullable fields
	foreach field {
		PAYEE
		ADDR_1
		ADDR_2
		ADDR_3
		ADDR_4
		ADDR_CITY
		ADDR_POSTCODE
		COUNTRY_CODE
	} {
		if {![info exists GEN_MTHD($field)]} {
			set GEN_MTHD($field) ""
		}
	}

	# Defaults
	if {![info exists GEN_MTHD(USE_REG_ADD)]} {
		set GEN_MTHD(USE_REG_ADD) "N"
	}

	# TO_DO implement default to registration details

	if {[catch {
		set rs [ob_db::exec_qry OB_gen_payment::ins_cust_chq \
			$GEN_MTHD(CUST_ID)\
			$GEN_MTHD(PAYEE)\
			$GEN_MTHD(ADDR_1)\
			$GEN_MTHD(ADDR_2)\
			$GEN_MTHD(ADDR_3)\
			$GEN_MTHD(ADDR_4)\
			$GEN_MTHD(ADDR_CITY)\
			$GEN_MTHD(ADDR_POSTCODE)\
			$GEN_MTHD(COUNTRY_CODE)\
			$GEN_MTHD(DEP_STATUS)\
			$GEN_MTHD(WTD_STATUS)]
	} msg]} {
		catch {ob_db::rs_close $rs}
		return [list $msg ""]
	}

	set method_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs
	return [list OK $method_id]
}



proc OB_gen_payment::ins_csh {} {

	variable GEN_MTHD

	# Nullable fields
	if {![info exists GEN_MTHD(OUTLET)]} {
		set GEN_MTHD(OUTLET) ""
	}

	if {[catch {
		set rs [ob_db::exec_qry OB_gen_payment::ins_cust_csh \
			$GEN_MTHD(CUST_ID)\
			$GEN_MTHD(TYPE)\
			$GEN_MTHD(OUTLET)]
	} msg]} {
		catch {ob_db::rs_close $rs}
		return [list $msg ""]
	}

	set method_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs
	return [list OK $method_id]
}



proc OB_gen_payment::ins_bank {} {

	ob_log::write DEBUG {gen_payment: ==>OB_gen_payment::ins_bank}

	variable GEN_MTHD

	# Required fields
	if {![info exists GEN_MTHD(BANK_NAME)]} {
		return [list "MTHD_ERR_NO_BANK_NAME" ""]
	}

	if {![info exists GEN_MTHD(COUNTRY_CODE)]} {
		return [list "MTHD_ERR_NO_COUNTRY_CODE" ""]
	}

	# Nullable fields
	foreach field [list \
		ADDR_1 \
		ADDR_2 \
		ADDR_3 \
		ADDR_4 \
		ACCT_NAME \
		ACCT_NO \
		SORT_CODE \
		BANK_BRANCH] {
		if {![info exists GEN_MTHD($field)]} {
			set GEN_MTHD($field) ""
		}
	}

	if {[catch {
		set rs [ob_db::exec_qry OB_gen_payment::ins_cust_bank \
			$GEN_MTHD(CUST_ID)\
			$GEN_MTHD(BANK_NAME)\
			$GEN_MTHD(ADDR_1)\
			$GEN_MTHD(ADDR_2)\
			$GEN_MTHD(ADDR_3)\
			$GEN_MTHD(ADDR_4)\
			$GEN_MTHD(ADDR_CITY)\
			$GEN_MTHD(ADDR_POSTCODE)\
			$GEN_MTHD(COUNTRY_CODE)\
			$GEN_MTHD(ACCT_NAME)\
			$GEN_MTHD(ACCT_NO)\
			$GEN_MTHD(SORT_CODE)\
			$GEN_MTHD(BANK_BRANCH)]
	} msg]} {

		catch {ob_db::rs_close $rs}
		return [list $msg ""]
	}

	set method_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	if {[OT_CfgGet FRAUD_SCREEN 0] != 0} {
		set monitor_details [fraud_check::screen_customer_bank\
			$GEN_MTHD(CUST_ID)\
			$GEN_MTHD(source)\
			$GEN_MTHD(amount)]

		lappend monitor_details bank_sort_code $GEN_MTHD(SORT_CODE)
		lappend monitor_details bank_acct_name $GEN_MTHD(ACCT_NAME)
		lappend monitor_details bank_acct_no   $GEN_MTHD(ACCT_NO)
		lappend monitor_details bank_addr_1    $GEN_MTHD(ADDR_1)
		lappend monitor_details bank_addr_2    $GEN_MTHD(ADDR_2)
		lappend monitor_details bank_addr_city $GEN_MTHD(ADDR_CITY)

		eval fraud_check::send_ticker $monitor_details
	}

	return [list OK $method_id]
}



# Send a payment message to the ticker
#
# pmt_id     - id of payment
# pmt_date   - date of payment
# pmt_status - payment status
# GEN_PMT_ARR - name of array containing payment details
#
proc OB_gen_payment::send_pmt_ticker {
				pmt_id
				pmt_date
				pmt_status
				GEN_PMT_ARR} {

	global DB
	variable GEN_MTHD

	upvar 1 $GEN_PMT_ARR GEN_PMT

	# Check if this message type is supported
	if {![string equal [OT_CfgGet MONITOR 0] 1] ||
	    ![string equal [OT_CfgGet PAYMENT_TICKER 0] 1]} {
		return 0
	}

	set pay_method $GEN_PMT(type)

	set sql {
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
		a.ccy_code,
		ccy.exch_rate,
		ccy.max_deposit,
		ccy.max_withdrawal,
		f.flag_value
		from
		tcustomer c,
		tcustomerreg cr,
		tacct a,
		tCcy ccy,
		outer tCustomerFlag f
		where
		a.acct_id = ? and
		a.cust_id = cr.cust_id and
		cr.cust_id = c.cust_id and
		a.ccy_code = ccy.ccy_code and
		f.cust_id = c.cust_id and
		f.flag_name = 'trading_note'
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $GEN_PMT(acct_id)]
	inf_close_stmt $stmt

	set cust_id        [db_get_col $rs cust_id]
	set username       [db_get_col $rs username]
	set fname          [db_get_col $rs fname]
	set lname          [db_get_col $rs lname]
	set postcode       [db_get_col $rs addr_postcode]
	set country_code   [db_get_col $rs country_code]
	set email          [db_get_col $rs email]
	set reg_date       [db_get_col $rs cust_reg_date]
	set reg_code       [db_get_col $rs code]
	set notifiable     [db_get_col $rs notifyable]
	set acct_balance   [db_get_col $rs balance]
	set addr_city      [db_get_col $rs addr_city]
	set addr_country   [db_get_col $rs addr_country]
	set exch_rate      [db_get_col $rs exch_rate]
	set ccy_code       [db_get_col $rs ccy_code]
	set trading_note   [db_get_col $rs flag_value]
	set max_deposit    [db_get_col $rs max_deposit]
	set max_withdrawal [db_get_col $rs max_withdrawal]

	db_close $rs

	set ext_unique_id [expr {[info exists GEN_PMT(ext_unique_id)]?"$GEN_PMT(ext_unique_id)":"N/A"}]

	if {[info exists GEN_PMT(bank_name)]} {
		set bank_name $GEN_PMT(bank_name)
	} elseif {[info exists GEN_MTHD(BANK_NAME)]} {
		set bank_name $GEN_MTHD(BANK_NAME)
	} else {
		set bank_name "N/A"
	}

	if {[info exist GEN_PMT(trading_note)]} {
		set trading_note $GEN_PMT(trading_note)
	}

	# Bank name is present for both bank transfer/bankline
	if {[string equal $bank_name "N/A"] &&
	    [string first $GEN_PMT(type) "BL/BANK"] > -1} {
		set sql [subst {
			select
				bank_name
			from
				tCpm${GEN_PMT(type)}
			where
				cpm_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $GEN_PMT(cpm_id)]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] > 0} {
			set bank_name [db_get_col $rs 0 bank_name]
		}
		db_close $rs
	}

	if {[info exists GEN_PMT(shop_id)]} {
		set shop_id $GEN_PMT(shop_id)
	} else {
		set shop_id "N/A"
	}

	if {[info exists GEN_PMT(rad_id)]} {
		set rad_id $GEN_PMT(rad_id)
	} else {
		set rad_id "N/A"
	}

	# convert user amount into system ccy
	set amount_sys [format "%.2f" [expr {$GEN_PMT(amount) / $exch_rate}]]


	set cum_wtd_usr ""
	set cum_wtd_sys ""
	set cum_dep_usr ""
	set cum_dep_sys ""
	set max_wtd_pc ""
	set max_dep_pc ""
	if {[OT_CfgGet MON_CUM_DEPWTD 0]} {
		if {$GEN_PMT(payment_sort) == "W"} {
			set cum_wtd_usr [OB_gen_payment::get_daily_sum $GEN_PMT(acct_id) $GEN_PMT(payment_sort)]
			set cum_wtd_sys [format "%.2f" [expr {$cum_wtd_usr / $exch_rate}]]
			set max_wtd_pc [format "%.2f" [expr {($cum_wtd_usr / $max_withdrawal) * 100.0}]]
		} elseif {$GEN_PMT(payment_sort) == "D"} {
			set cum_dep_usr [OB_gen_payment::get_daily_sum $GEN_PMT(acct_id) $GEN_PMT(payment_sort)]
			set cum_dep_sys [format "%.2f" [expr {$cum_dep_usr / $exch_rate}]]
			set max_dep_pc [format "%.2f" [expr {($cum_dep_usr / $max_deposit) * 100.0}]]
		}
	}

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
	                                 $GEN_PMT(acct_id)\
	                                 $acct_balance\
	                                 "$GEN_PMT(ipaddr)-${addr_country}"\
	                                 "$GEN_PMT(ipaddr)-${addr_city}"\
	                                 $pay_method\
	                                 $ccy_code\
	                                 $GEN_PMT(amount)\
	                                 $amount_sys\
	                                 $pmt_id\
	                                 $pmt_date\
	                                 $GEN_PMT(payment_sort)\
	                                 $pmt_status\
	                                 $ext_unique_id\
	                                 $bank_name\
	                                 $GEN_PMT(source)\
	                                 $trading_note\
	                                 $cum_wtd_usr\
	                                 $cum_wtd_sys\
	                                 $cum_dep_usr\
	                                 $cum_dep_sys\
	                                 $max_wtd_pc\
	                                 $max_dep_pc\
	                                 $shop_id\
	                                 $rad_id]} msg]} {
		ob::log::write ERROR {OB_gen_payment::send_pmt_ticker: Failed to send
		payment monitor message : $msg}
		return 0
	}

	#ob::log::write DEV {OB_gen_payment::send_pmt_ticker: now going to check num_payments}
	# Is this the first payment on this particular CPM? If so we also need to send a message to the fraud tickers
	#if {[num_payments $GEN_PMT(cpm_id)] == 1 && [OT_CfgGet FRAUD_MONITOR_NON_CARD_CPM_REG 0]} {
	#	set monitor_details [fraud_check::screen_customer_non_card\
	#		$cust_id\
	#		$GEN_PMT(source)\
	#		$GEN_PMT(amount)\
	#		$pay_method \
	#		$GEN_PMT(payment_sort)\
	#	]

	#	eval fraud_check::send_ticker $monitor_details
	#}

	return $result
}


proc OB_gen_payment::reverse_wtd {pmt_id adminuser {transactional "N"}} {

	if {[catch {
		ob_db::exec_qry OB_gen_payment::reverse_wtd $pmt_id "B" $adminuser $transactional
	} msg]} {

		ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
		ob_log::write ERROR {PMT Error Reversing payment $pmt_id : **$msg**}
		ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

		return [list 0 [_get_err_code $msg]]
	}

	return [list 1]
}


proc OB_gen_payment::reverse_wtds {pmts adminuser} {

	if {![llength $pmts]} {
		return 0
	}

	ob_db::begin_tran

	foreach pmt_id $pmts {
		if {[catch {
			ob_db::exec_qry OB_gen_payment::reverse_wtd $pmt_id "B" $adminuser "N"
		} msg]} {

			ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
			ob_log::write ERROR {PMT Error Reversing payment $pmt_id : **$msg**}
			ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

			catch {ob_db::rollback_tran}

			return 0
		}
	}

	#commit
	ob_db::commit_tran

	return 1
}


#
# Try to return the correct error code according to the exceptions
# in the pmt stored procs.
#
proc OB_gen_payment::_get_err_code {msg} {

	variable ERR_CODE

	# try to parse a msg in format (-746) ERR_CODE
	if {[regexp {\(-746\) ([A-Z_]*)} $msg j err_code]} {
		return $err_code
	}

	# try to handle format "AX4000 Message"
	if {[regexp {AX([0-9][0-9][0-9][0-9])} $msg all err_code]} {
		if {[info exists ERR_CODE($err_code)]} {
			return $ERR_CODE($err_code)
		}
	}

	# none of the above worked, return default error msg
	return PMT_ERR


}


