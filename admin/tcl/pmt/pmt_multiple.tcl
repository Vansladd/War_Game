# ==============================================================
# $Id: pmt_multiple.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT_MULTIPLE {

	asSetAct ADMIN::PMT_MULTIPLE::GoPMTMultiple [namespace code go_pmt_multiple]
	asSetAct ADMIN::PMT_MULTIPLE::DoUpdPMB      [namespace code do_upd_pmb]
	asSetAct ADMIN::PMT_MULTIPLE::DoCustPMBExp  [namespace code do_cust_pmb_exp]
	asSetAct ADMIN::PMT_MULTIPLE::DoUpdMultiPmt [namespace code do_upd_multi_pmt]
	asSetAct ADMIN::PMT_MULTIPLE::GoPMBHistory  [namespace code go_pmb_history]
}



proc ADMIN::PMT_MULTIPLE::go_pmt_multiple {} {

	global PMB
	global DB

	set stmt [inf_prep_sql $DB {
		select
			m.pay_mthd,
			m.pmt_scheme,
			m.pmb_period,
			m.pmb_priority,
			m.max_combine,
			pm.desc
		from
			tCPMMultiControl m,
			tPayMthd pm
		where
			m.pay_mthd = pm.pay_mthd
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set PMB($i,pay_mthd)      [db_get_col $rs $i pay_mthd]
		set PMB($i,pay_mthd_desc) [db_get_col $rs $i desc]
		set PMB($i,pmt_scheme)    [db_get_col $rs $i pmt_scheme]
		set PMB($i,pmb_period)    [db_get_col $rs $i pmb_period]
		set PMB($i,pmb_priority)  [db_get_col $rs $i pmb_priority]
		set PMB($i,max_combine)   [db_get_col $rs $i max_combine]
	}

	db_close $rs

	tpSetVar NrPmtSchemes $nrows
	tpBindVar PayMthd     PMB pay_mthd      pmb_idx
	tpBindVar PayMthdDesc PMB pay_mthd_desc pmb_idx
	tpBindVar PmtScheme   PMB pmt_scheme    pmb_idx
	tpBindVar PMBPeriod   PMB pmb_period    pmb_idx
	tpBindVar PMBPriority PMB pmb_priority  pmb_idx
	tpBindVar MaxCombine  PMB max_combine   pmb_idx

	# Bind global settings related to multiple payment methods
	set stmt [inf_prep_sql $DB {
		select
			max_pmt_mthds,
			nr_fraud_cpms,
			fraud_cpms_period,
			max_cards
		from
			tPmtMultiControl
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		err_bind "Error getting global settings from database"
		asPlayFile -nocache pmt/pmt_multiple.html
		return
	}

	tpBindString MaxPmtMthds     [db_get_col $rs 0 max_pmt_mthds]
	tpBindString NrFraudCPMs     [db_get_col $rs 0 nr_fraud_cpms]
	tpBindString FraudCPMsPeriod [db_get_col $rs 0 fraud_cpms_period]
	tpBindString MaxCards        [db_get_col $rs 0 max_cards]

	db_close $rs

	asPlayFile -nocache pmt/pmt_multiple.html
}



# Updates the global settings related to multiple payment methods
proc ADMIN::PMT_MULTIPLE::do_upd_multi_pmt {} {

	global DB

	set nr_fraud_cpms     [reqGetArg nr_fraud_cpms]
	set fraud_cpms_period [reqGetArg fraud_cpms_period]

	set stmt [inf_prep_sql $DB {
		update
			tPmtMultiControl
		set
			nr_fraud_cpms = ?,
			fraud_cpms_period = ?
	}]

	if {[catch {
		inf_exec_stmt $stmt $nr_fraud_cpms $fraud_cpms_period
		inf_close_stmt $stmt
	} msg]} {
		inf_close_stmt $stmt
		err_bind "Error updating multiple payment methods settings: $msg"
		go_pmt_multiple
		return
	}

	go_pmt_multiple
}



# Updates the system-wide PMB expiry days for each payment method.
proc ADMIN::PMT_MULTIPLE::do_upd_pmb {} {

	global DB

	if {![op_allowed UpdatePMBExpiry]} {
		err_bind "You do not have permission to update PMB expiry values at system level"
		go_pmt_multiple
		return
	}
	
	set max_pmt_mthds     [reqGetArg max_pmt_mthds]	
	set max_cards         [reqGetArg max_cards]

	set stmt1 [inf_prep_sql $DB {
		update
			tPmtMultiControl
		set
			max_pmt_mthds = ?,
			max_cards = ?
	}]
	
	
	if {[catch {
		inf_exec_stmt $stmt1 $max_pmt_mthds $max_cards
		inf_close_stmt $stmt1
	} msg]} {
		inf_close_stmt $stmt1
		err_bind "Error updating multiple payment methods settings: $msg"
		go_pmt_multiple
		return
	}

	set sql {
		update
			tCPMMultiControl
		set
			pmb_period = ?,
			pmb_priority = ?,
			max_combine = ?
		where
			pay_mthd = ? and
			pmt_scheme = ?
	}

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set arg_name [reqGetNthName $i]
		set arg_val  [reqGetNthVal $i]

		if {[regexp {PMBExp} $arg_name]} {
			foreach {pay_mthd pmt_scheme type} [split $arg_name _] break

			set exp_val      $arg_val
			set pri_val      [reqGetArg ${pay_mthd}_${pmt_scheme}_Pri]
			set max_comb_val [reqGetArg ${pay_mthd}_${pmt_scheme}_MaxComb]

			if {[regexp {^\d{1,3}$} $exp_val] && [regexp {^\d{1,3}$} $pri_val] && [regexp {^\d{1,3}$} $max_comb_val]} {
				if {$exp_val > 366} {
					err_bind "PMB expiry must be between 0 and 366 days."
					go_pmt_multiple
					return
				}
				if {[catch {
					set stmt [inf_prep_sql $DB $sql]
					inf_exec_stmt $stmt $exp_val $pri_val $max_comb_val $pay_mthd $pmt_scheme
					inf_close_stmt $stmt
				} msg]} {
					inf_close_stmt $stmt
					err_bind "Error updating PMB expiry values."
					go_pmt_multiple
					return
				}
			} else {
				err_bind "Values must be positive decimal numbers of up to 3 digits"
				go_pmt_multiple
				return
			}
		}
	}

	go_pmt_multiple
}



# Adds/deletes/updates an exception for the PMB period for a customer and
# payment scheme.
proc ADMIN::PMT_MULTIPLE::do_cust_pmb_exp {action} {

	global DB

	set cust_id    [reqGetArg CustId]
	set pay_mthd   [reqGetArg pay_mthd]
	set pmt_scheme [reqGetArg pmt_scheme]
	set pmb_period [reqGetArg PMBPeriod]

	if {![op_allowed UpdatePMBExpiryAcc]} {
		err_bind "You do not have permission to update PMB expiry values at account level."
		return
	}

	if {$pmb_period < 0 || $pmb_period > 366} {
		err_bind "PMB expiry value must be between 0 and 366 days."
		return
	}

	if {$pmt_scheme == ""} {
		set pmt_scheme "----"
	}

	if {$action == "add"} {

		if {$pay_mthd == "ALL"} {
			# Set values here to override the maximum PMB
			# period for the customer
			ADMIN::CUST::set_cust_multi_limits $cust_id "" $pmb_period ""
			return
		}

		set stmt [inf_prep_sql $DB {
			insert into
				tCustPMBPeriod (cust_id, pay_mthd, pmt_scheme, pmb_period)
			values
				(?, ?, ?, ?)
		}]

		if {[catch {
			inf_exec_stmt $stmt $cust_id $pay_mthd $pmt_scheme $pmb_period
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error adding PMB expiry value"
			return
		}

		inf_close_stmt $stmt
	} elseif {$action == "del"} {

		if {$pay_mthd == "ALL"} {
			ADMIN::CUST::set_cust_multi_limits $cust_id "" -1 ""
			return
		}

		set stmt [inf_prep_sql $DB {
			delete from
				tCustPMBPeriod
			where
				cust_id = ? and
				pay_mthd = ? and
				pmt_scheme = ?
		}]

		if {[catch {
			inf_exec_stmt $stmt $cust_id $pay_mthd $pmt_scheme
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error deleting PMB expiry value"
			return
		}

		inf_close_stmt $stmt
	} elseif {$action == "upd"} {

		if {$pay_mthd == "ALL"} {
			ADMIN::CUST::set_cust_multi_limits $cust_id "" $pmb_period ""
			return
		}

		set stmt [inf_prep_sql $DB {
			update
				tCustPMBPeriod
			set
				pmb_period = ?
			where
				cust_id = ? and
				pay_mthd = ? and
				pmt_scheme = ?
		}]

		if {[catch {
			inf_exec_stmt $stmt $pmb_period $cust_id $pay_mthd $pmt_scheme
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error updating PMB expiry value"
			return
		}

		inf_close_stmt $stmt
	}
}



# Adds/deletes/updates an exception for the maximum number of methods for a
# customer and payment scheme.
proc ADMIN::PMT_MULTIPLE::do_cust_max_combine {action} {

	global DB

	set cust_id     [reqGetArg CustId]
	set pay_mthd    [reqGetArg pay_mthd]
	set pmt_scheme  [reqGetArg pmt_scheme]
	set max_combine [reqGetArg MaxCombine]

	if {![op_allowed UpdateMaxCombineAcc]} {
		err_bind "You do not have permission to update the maximum number of payment methods."
		return
	}

	if {$max_combine < 0} {
		err_bind "Maximum number of payment methods must be 0 or more."
		return
	}

	if {$pmt_scheme == ""} {
		set pmt_scheme "----"
	}

	if {$action == "add"} {

		set stmt [inf_prep_sql $DB {
			insert into
				tCustMaxPmtMthd (cust_id, pay_mthd, pmt_scheme, max_combine)
			values
				(?, ?, ?, ?)
		}]

		if {[catch {
			inf_exec_stmt $stmt $cust_id $pay_mthd $pmt_scheme $max_combine
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error adding max combine"
			return
		}

		inf_close_stmt $stmt
	} elseif {$action == "del"} {

		set stmt [inf_prep_sql $DB {
			delete from
				tCustMaxPmtMthd
			where
				cust_id = ? and
				pay_mthd = ? and
				pmt_scheme = ?
		}]

		if {[catch {
			inf_exec_stmt $stmt $cust_id $pay_mthd $pmt_scheme
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error deleting max combine"
			return
		}

		inf_close_stmt $stmt
	} elseif {$action == "upd"} {

		set stmt [inf_prep_sql $DB {
			update
				tCustMaxPmtMthd
			set
				max_combine = ?
			where
				cust_id = ? and
				pay_mthd = ? and
				pmt_scheme = ?
		}]

		if {[catch {
			inf_exec_stmt $stmt $max_combine $cust_id $pay_mthd $pmt_scheme
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Error updating max combine"
			return
		}

		inf_close_stmt $stmt
	}
}



# Display the transactions that contribute to a PMB value
proc ADMIN::PMT_MULTIPLE::go_pmb_history {} {

	global DB

	reqSetArg CustId   [reqGetArg CustId]
	reqSetArg AcctId   [reqGetArg AcctId]
	reqSetArg AcctNo   [reqGetArg AcctNo]
	reqSetArg Username [reqGetArg Username]

	set cpm_id [reqGetArg cpm_id]

	foreach {success period} [payment_multi::get_cpm_period $cpm_id] {}

	if {!$success} {
		ob_log::write ERROR {Failed to find period to check}
		err_bind "Error finding payment method history"
		ADMIN::CUST::go_cust cust_id [reqGetArg CustId]
		return
	}

	set start_date [clock format [expr [clock seconds] - (($period -1) * 86400)] -format "%Y-%m-%d 00:00:00"]
	set end_date   [clock format [clock seconds] -format "%Y-%m-%d 23:59:59"]

	reqSetArg TxnDate1   $start_date
	reqSetArg TxnDate2   $end_date

	reqSetArg SubmitName First

	return [ADMIN::CUST_TXN::do_txn_query $cpm_id 1]
}



# Update the customer flag giving default combination
#
proc ADMIN::PMT_MULTIPLE::do_cust_default_max_combine {} {

	set cust_id     [reqGetArg CustId]
	set max_methods [reqGetArg DefaultMaxCombine]
	
	if {$max_methods == "" } {
		set max_methods -1
	}

	if {[ADMIN::CUST::set_cust_multi_limits $cust_id $max_methods "" ""]} {
		msg_bind "Successfully updated default number of methods"
	}

	ADMIN::CUST::go_cust cust_id $cust_id

}


# Update the max number of cards a customer is allowed
#
proc ADMIN::PMT_MULTIPLE::do_cust_max_cards {} {

	set cust_id   [reqGetArg CustId]
	set max_cards [reqGetArg MaxCustCards]

	if {$max_cards == "" } {
		set max_cards -1
	}

	if {[ADMIN::CUST::set_cust_multi_limits $cust_id "" "" $max_cards]} {
		msg_bind "Successfully updated max number of cards"
	}

	ADMIN::CUST::go_cust cust_id $cust_id

}
