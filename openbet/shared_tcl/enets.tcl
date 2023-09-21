# $Id: enets.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# This is a pretty primitive implementation of eNETS payment method. This provides
# functionality to add payment methods to a customer, as well as do payments.
#
# This must be used in conjunction with a method such as bibit to provide the
# actual transferral of funds.
#
# insert into tPayMthd (
#    pay_mthd, desc, blurb
# ) values (
#    "ENET", "eNETS", "Deposit only eNETS method"
# );
#
# All procedures return a two or three element list containing, in order, the following:
#
#   sucess                 0 or 1 to show if the procedure was succesful or failed.
#   xl                     A translatable code representing either success (e.g. ENETS_UPD_CPM_OK) or failure (e.g. ENETS_ERR_DB).
#   msg                    An English message for logging more detailed information about the error.
#
# Configuration:
#
#   ENETS                  Activate eNETS. (0)
#
# Synopsis:
#
#   none
#
# Procedures:
#
#   enets::init          One time initialisation.
#   enets::ins_cpm       Inserts a cpm for a customer.
#   enets::get_cpm       Gets the eNETS cpm for a customer.
#   enets::del_cpm       Deletes the customers eNETS payment method.
#   enets::ins_pmt_dep   Inserts a deposit payment.
#   enets::ins_pmt_wtd   Inserts a withdrawal payment for a customer.
#   enets::get_pmt       Gets the payment and puts it in an array.
#   enets::upd_pmt_dep   Updates the deposit payment.
#   enets::upd_pmt_wtd   Updates the withdrawal payment.

package require OB_Log
package require util_appcontrol

namespace eval enets {
	variable CFG
	array set CFG [list \
		ENETS    [OT_CfgGet FUNC_ENETS 0] \
	]
}

# One time initialisation.
proc enets::init {} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	_prep_qrys

	return [list 1 ENETS_INIT_OK]
}

# Prepare the db queries.
proc enets::_prep_qrys {} {
	global SHARED_SQL

	set SHARED_SQL(ENETS_ins_cpm) {
		execute procedure pCPMInseNETS (
			p_cust_id       = ?,
			p_oper_id       = ?,
			p_auth_dep      = 'Y',
			p_auth_wtd      = 'N',
			p_status_wtd    = 'S',
			p_transactional = 'Y'
		)
	}

	set SHARED_SQL(ENETS_get_cpm) {
		select
			cpm.cpm_id,
			c.ccy_code,
			c.min_deposit,
			c.max_deposit
		from
			tCPMeNETS    n,
			tAcct        a,
			tCustPayMthd cpm,
			tCcy         c
		where
			n.cpm_id       = cpm.cpm_id
		and cpm.cust_id    = a.cust_id
		and cpm.status     = 'A'
		and a.ccy_code     = c.ccy_code
		and cpm.pay_mthd   = 'ENET'
		and cpm.cust_id    = ?
	}

	set SHARED_SQL(ENETS_del_cpm) {
		update
			tCustPayMthd
		set
			status = 'X'
		where
			cpm_id = ?
	}

	set SHARED_SQL(ENETS_ins_pmt) {
		execute procedure pPmtInseNETS (
			p_acct_id       = ?,
			p_cpm_id        = ?,
			p_payment_sort  = ?,
			p_amount        = ?,
			p_commission    = ?,
			p_ipaddr        = ?,
			p_gw_uid        = ?,
			p_gw_pmt_id     = ?,
			p_ext_ord_status = ?,
			p_gw_ret_msg    = ?,
			p_source        = ?,
			p_transactional = 'Y',
			p_j_op_type     = ?,
			p_oper_id       = ?,
			p_unique_id     = ?
		)
	}

	set SHARED_SQL(ENETS_upd_pmt) {
		execute procedure pPmtUpdeNETS (
			p_pmt_id       = ?,
			p_status       = ?,
			p_gw_uid       = ?,
			p_gw_pmt_id    = ?,
			p_ext_ord_status = ?,
			p_gw_ret_msg   = ?
		)
	}

	set SHARED_SQL(ENETS_get_pmt) {
		select
			a.cust_id,
			a.acct_id,
			a.ccy_code,
			p.*,
			n.*
		from
			tAcct     a,
			tPmt      p,
			tPmteNETS n
		where
			p.pmt_id  = ?
		and p.acct_id = a.acct_id
		and p.pmt_id  = n.pmt_id
	}
}

# Convert AX codes into a translation.
#
#     msg       The database error message.
#     returns   A translatable code.
#
proc enets::_get_db_xl_for_msg {msg} {
	switch -glob $msg {
		*AX5000* {
			return ENETS_ERR_AMOUNT_BAD
		}
		*AX5015* {
			return ENETS_ERR_FUNDS_XFER_NOT_ALLOWED
		}
		*AX5505* {
			return ENETS_ERR_INSUFFICIENT_FUNDS
		}
		*AX5506* {
			return ENETS_ERR_DUPLICATE_TXN
		}
		default {
			# not found one, use a generic one
			return ENETS_ERR_DB
		}
	}
}

# Insert a eNETS payment method for a customer.
#
#    cust_id   The customer's id.
#    oper_id   The operator's id.
#    CPM_ARR   An array to put the new cpm into, if blank the array is not set.
#
proc enets::ins_cpm {cust_id channel {oper_id ""} {CPM_ARR ""}} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {$CPM_ARR != ""} {
		upvar 1 $CPM_ARR CPM
	}

	array unset CPM

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_ins_cpm $cust_id $oper_id]
	} msg] } {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec ENETS_ins_cpm: $msg"
		return [list 0 $xl $msg]
	}

	array set CPM {
		cpm_id  [db_get_coln $rs 0]
		status  A
		cust_id $cust_id
		oper_id $oper_id
	}


	### Send message to Monitor ###

	set amount  "N/A"
	set mthd    "ENET"
	set cpm_id  [db_get_coln $rs 0]
	set generic_pmt_mthd_id ""
	set other ""

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		$mthd \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other

	### End of Monitor code ###

	db_close $rs

	return [list 1 ENETS_INS_CPM_OK]
}

# Get's a customer eNETS payment method and optionally puts it into the array.
#
#   cust_id   The customer's id.
#   CPM_ARR   An array for the CPM to go into, if blank this is not populated.
#
proc enets::get_cpm {cust_id {CPM_ARR ""}} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {$CPM_ARR != ""} {
		upvar 1 $CPM_ARR CPM
	}

	array unset CPM

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_get_cpm $cust_id]
	} msg]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec ENETS_ins_cpm: $msg"
		return [list 0 $xl $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		db_close $rs
		set msg "enets: failed to get unique cpm, $nrows rows returned"
		return [list 0 ENETS_ERR_ONLY_ONE_CPM $msg]
	}

	foreach col [db_get_colnames $rs] {
		set CPM($col) [db_get_col $rs 0 $col]
	}

	db_close $rs

	ob::log::write_array DEBUG CPM

	return [list 1 ENETS_GET_CPM_OK]
}

# Deletes (sets status to X) a customer payment method.
#
#    cust_id   The customer's id.
#
proc enets::del_cpm {cust_id} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	# check the cpm exists
	foreach {ok xl msg} [get_cpm $cust_id CPM] {break}
	if {!$ok} {
		return [list 0 ENETS_ERR_ONLY_ONE_CPM "Only one active cpm per customer is allowed"]
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_del_cpm $CPM(cpm_id)]
	} msg]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec qry ENETS_del_cpm: $msg"
		return [list 0 $xl $msg]
	}
	db_close $rs

	return [list 1 ENETS_DEL_CPM_OK]
}

# Inserts a deposit.
#
# NOTE: This doesn't do any of the actual transaction with the third party.
#
#   acct_id       The customers account id.
#   cpm_id        The customer payment method id.
#   amount        The amount of the deposit.
#   unique_id     A unique id.
#   gw_uid        The payments third party reference id.
#   gw_pmt_id     The payments third party payment id.
#   ext_ord_status The order status.
#   gw_ret_msg    The bibit return msg.
#   source        The source of the payments. (I - Internet)
#   oper_id       The optional operator id.
#   PMT_ARR       An array to put the payment in, if this is blank then it is not populated.
#
proc enets::ins_pmt_dep {
	acct_id
	cpm_id
	amount
	commission
	unique_id
	{gw_uid ""}
	{gw_pmt_id   ""}
	{ext_ord_status E}
	{gw_ret_msg   ""}
	{source       I}
	{oper_id      ""}
	{PMT_ARR      ""}
} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {$PMT_ARR != ""} {
		upvar 1 $PMT_ARR PMT
	}

	array unset PMT

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_ins_pmt \
			$acct_id \
			$cpm_id \
			D \
			$amount \
			$commission \
			[reqGetEnv REMOTE_ADDR] \
			$gw_uid \
			$gw_pmt_id \
			$ext_ord_status \
			$gw_ret_msg \
			$source\
			DEP\
			$oper_id\
			$unique_id\
	]} msg ]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec qry ENETS_ins_pmt: $msg"
		return [list 0 $xl $msg]
	}

	# a simple way to avoid hitting the database twice, yet get useful information
	array set PMT [list \
		pmt_id       [db_get_coln $rs 0] \
		cpm_id       $cpm_id \
		payment_sort D \
		amount       $amount \
		ipaddr       [reqGetEnv REMOTE_ADDR] \
		gw_uid       $gw_uid \
		gw_pmt_id    $gw_pmt_id \
		ext_ord_status $ext_ord_status \
		gw_ret_msg   $gw_ret_msg \
		source       $source \
		oper_id      $oper_id \
		unique_id    $unique_id \
		status       P \
	]

	db_close $rs

	foreach n {acct_id cpm_id amount unique_id source oper_id} {
		set PMT($n) [set $n]
	}

	ob::log::write_array DEBUG PMT

	return [list 1 ENETS_INS_PMT_DEP_OK]
}

# Inserts a withdrawal.
#
# NOTE: This doesn't do that actual transaction with the third party.
#
#   acct_id        The customer's account id.
#   cpm_id         The customer's eNETS cpm id.
#   amount         The amount to withdraw.
#   unique_id      A unique reference id.
#   gw_uid         The third party reference id.
#   gw_pmt_id      The third party payment id.
#   ext_ord_status The order status.
#   gw_ret_msg     The Bibit return msg.
#   source         The source of the withdrawal (I - Internet)
#   oper_id        The operator id.
#   PMT_ARR        An array to populate with the payment, if blank it is not populated.
#
proc enets::ins_pmt_wtd {
	acct_id
	cpm_id
	amount
	unique_id
	{gw_uid ""}
	{gw_pmt_id ""}
	{ext_ord_status E}
	{gw_ret_msg ""}
	{source I}
	{oper_id ""}
	{PMT_ARR ""}
} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {$PMT_ARR != ""} {
		upvar 1 $PMT_ARR PMT
	}


	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_ins_pmt \
			$acct_id \
			$cpm_id \
			W \
			$amount \
			[reqGetEnv REMOTE_ADDR] \
			$gw_uid \
			$gw_pmt_id \
			$ext_ord_status \
			$gw_ret_msg \
			$source\
			WTD\
			$oper_id\
			$unique_id\
	]} msg ]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to execute ENETS_ins_pmt: $msg"
		return [list 0 $xl $msg]
	}

	# a simple way to avoid hitting the database twice, yet get useful information
	array set PMT [list \
		pmt_id       [db_get_coln $rs 0] \
		cpm_id       $cpm_id \
		payment_sort W \
		amount       $amount \
		ipaddr       [reqGetEnv REMOTE_ADDR] \
		gw_uid       $gw_uid \
		gw_pmt_id    $gw_pmt_id  \
		ext_ord_status $ext_ord_status \
		gw_ret_msg   $gw_ret_msg \
		source       $source \
		oper_id      $oper_id \
		unique_id    $unique_id \
		status       P \
	]

	db_close $rs

	foreach n {acct_id cpm_id amount unique_id source oper_id} {
		set PMT($n) [subst $$n]
	}

	ob::log::write_array DEBUG PMT

	return [list 1 ENETS_INS_PMT_WTD_OK]
}

# Get the payment and put it in an array.
#
#   pmt_id   The payment's id.
#   PMT_ARR  An array to put the payment into.
#
proc enets::get_pmt {pmt_id {PMT_ARR ""}} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {$PMT_ARR != ""} {
		upvar 1 $PMT_ARR PMT
	}

	array unset PMT

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_get_pmt $pmt_id]
	} msg]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec qry ENETS_get_pmt: $msg"
		return [list 0 $xl $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		db_close $rs
		set msg "enets: failed to get cpm, $nrows rows returned"
		return [list 0 ENETS_ERR_ONLY_ONE_PMT $msg]
	}

	foreach col [db_get_colnames $rs] {
		set PMT($col) [db_get_col $rs 0 $col]
	}

	db_close $rs

	ob::log::write_array DEBUG PMT

	return [list 1 ENETS_GET_PMT_OK]
}

# Updates the status of the deposit.
#
#   pmt_id         The payment's id.
#   status         The status of the payment.
#   gw_uid         The third party reference id.
#   gw_pmt_id      The third party payment id.
#
proc enets::upd_pmt_dep {
	pmt_id
	status
	{gw_uid ""}
	{gw_pmt_id ""}
	{ext_ord_status E}
	{gw_ret_msg   ""}
} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_upd_pmt \
			$pmt_id \
			$status \
			$gw_uid \
			$gw_pmt_id \
			$ext_ord_status \
			$gw_ret_msg
		]
	} msg ]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec qry ENETS_upd_pmt: $msg"
		return [list 0 $xl $msg]
	}
	db_close $rs

	return [list 1 ENETS_UPD_PMT_DEP_OK]
}

# Updates the status of the withdrawal.
#
#   pmt_id         The payment's id.
#   status         The status of the payment.
#   gw_uid         The third party reference id.
#   gw_pmt_id      The third party payment id.
#
proc enets::upd_pmt_wtd {
	pmt_id
	status
	{gw_uid ""}
	{gw_pmt_id   ""}
	{ext_ord_status E}
	{gw_ret_msg   ""}
} {
	variable CFG

	if {!$CFG(ENETS)} {
		return [list 0 ENETS_ERR_DISABLED]
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry ENETS_upd_pmt \
			$pmt_id \
			$status \
			$gw_uid \
			$gw_pmt_id \
			$ext_ord_status \
			$gw_ret_msg
		]
	} msg ]} {
		set xl [_get_db_xl_for_msg $msg]
		set msg "enets: failed to exec qry ENETS_upd_pmt: $msg"
		return [list 0 $xl $msg]
	}
	db_close $rs

	return [list 1 ENETS_UPD_PMT_WTD_OK]
}

# init this file when sourced
foreach {ok msg} [enets::init] {break}

ob::log::write INFO {enets: init: $msg}
