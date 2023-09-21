# ==============================================================
# $Id: pmt_search.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {


asSetAct ADMIN::PMT::GoPmtQry                  [namespace code go_pmt_query]
asSetAct ADMIN::PMT::do_pmt_query              [namespace code do_pmt_query]
asSetAct ADMIN::PMT::do_pmt_paypal_query       [namespace code do_pmt_paypal_query]
asSetAct ADMIN::PMT::do_pmt_ukash_query        [namespace code do_pmt_ukash_query]
asSetAct ADMIN::PMT::do_pmt                    [namespace code do_pmt]
asSetAct ADMIN::PMT::do_pmt_ntlr_query         [namespace code do_pmt_ntlr_query]
asSetAct ADMIN::PMT::do_pmt_clickandbuy_query  [namespace code do_pmt_clickandbuy_query]
asSetAct ADMIN::PMT::do_pmt_click2pay_query    [namespace code do_pmt_click2pay_query]
asSetAct ADMIN::PMT::do_pmt_moneybookers_query [namespace code do_pmt_moneybookers_query]
asSetAct ADMIN::PMT::do_pmt_envoy_query        [namespace code do_pmt_envoy_query]
asSetAct ADMIN::PMT::do_pmt_paysafecard_query  [namespace code do_pmt_paysafecard_query]

#
# ----------------------------------------------------------------------------
# Generate customer selection criteria
# ----------------------------------------------------------------------------
#
proc go_pmt_query args {

	global DB

	#
	# Pre-load currency and country code/name pairs
	#
	set stmt [inf_prep_sql $DB {
		select
			ccy_code,
			ccy_name,
			disporder
		from
			tccy
		order by
			disporder
	}]
	set res_ccy [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCCYs [db_get_nrows $res_ccy]

	tpBindTcl CCYCode sb_res_data $res_ccy ccy_idx ccy_code
	tpBindTcl CCYName sb_res_data $res_ccy ccy_idx ccy_name

	set stmt [inf_prep_sql $DB {
		select
			country_code,
			country_name,
			disporder
		from
			tcountry
		order by
			disporder,
			country_name,
			country_code
	}]
	set res_cntry [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCNTRYs [db_get_nrows $res_cntry]

	tpBindTcl CNTRYCode sb_res_data $res_cntry cntry_idx country_code
	tpBindTcl CNTRYName sb_res_data $res_cntry cntry_idx country_name

	# Filter per customer code
	if {[OT_CfgGetTrue FUNC_PMT_SEARCH_CUST_GRP]} {
		_bind_customer_codes
	}


	# Add check to ensure that if FUNC_BASIC_PAY is set to 1, the Basic Pay option does not appear
	set where ""
	if {[OT_CfgGet FUNC_BASIC_PAY 0] != 1} {
		set where "where pay_mthd != \"BASC\""
	}

	#
	# Get list of Payment Methods
	#
	set sql [subst {
		select
			pay_mthd,
			desc
		from
			tPayMthd
		$where
		order by
			desc
	}]

	set stmt   [inf_prep_sql $DB $sql]
	set res_pm [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumMthds [db_get_nrows $res_pm]

	set basc_index -1
	set nrows [db_get_nrows $res_pm]
	for {set r 0} {$r < $nrows} {incr r} {
		if {[db_get_col $res_pm $r pay_mthd] == "BASC"} {
			set basc_index $r
			ob::log::write INFO {basc_index set to $r}
		}
	}

	tpBindTcl pay_mthd      sb_res_data $res_pm mthd_idx pay_mthd
	tpBindTcl pay_mthd_desc sb_res_data $res_pm mthd_idx desc

	#
	# Get Payment Gateway Hosts
	#
	set sql [subst {
		select
			h.pg_host_id,
			h.desc as pg_host_desc
		from
			tPmtGateHost h
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_ph  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumPGHosts [db_get_nrows $res_ph]

	tpBindTcl pg_host_id   sb_res_data $res_ph pg_host_idx pg_host_id
	tpBindTcl pg_host_desc sb_res_data $res_ph pg_host_idx pg_host_desc

	#
	# Get Payment Gateway Accounts
	#
	set sql [subst {
		select
			a.pg_acct_id,
			a.desc as pg_acct_desc
		from
			tPmtGateAcct a
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_pa  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumPGAccts [db_get_nrows $res_pa]

	tpBindTcl pg_acct_id   sb_res_data $res_pa pg_acct_idx pg_acct_id
	tpBindTcl pg_acct_desc sb_res_data $res_pa pg_acct_idx pg_acct_desc

	asPlayFile -nocache pmt/pmt_search.html

	db_close $res_ph
	db_close $res_pm
	db_close $res_pa
	db_close $res_ccy
	db_close $res_cntry
}


#
# ----------------------------------------------------------------------------
# Payment search
# ----------------------------------------------------------------------------
#
proc do_pmt_query args {

	global DB

	if {![op_allowed DoPaymentSearch]} {
		err_bind "You do not have permission to search customer payments"
		ADMIN::PMT::go_pmt_query
		return
	}

	#
	# rebind most of the posted variables
	#
	foreach f {
		SR_username
		SR_upper_username
		SR_fname
		SR_lname
		SR_email
		SR_acct_no_exact
		SR_acct_no
		SR_date_1
		SR_date_2
		SR_date_range
		SR_status
		SR_not_status
		SR_payment_sort
		SR_channel
		SR_pay_mthd
		SR_PG_host
		SR_PG_acct
		SR_cpm_id
		SR_cust_id
		SR_CCYCode
		SR_CNTRYCode
		SR_PMT_ID
		SR_pmt_receipt
		SR_operator
		SR_settled_by
		SR_REF_NUM
		SR_fulfilled
		SR_fulfil_status
		SR_fc_auth_status
		SR_lr_auth_status
		SR_REF_NO
		SR_resub_status
		SR_CustGrp
	} {
		set $f [reqGetArg $f]
		tpBindString $f [subst "$$f"]
	}

	if {[OT_CfgGet VALIDATE_PMT_SEARCHES 0]} {
		# Run some validation to check that we've got some decent filters in the
		# query to avoid running horrible queries
		set compulsory_fields ""

		foreach f {
			SR_username
			SR_lname
			SR_email
			SR_acct_no
			SR_date_1
			SR_date_2
			SR_date_range
			SR_PMT_ID
			SR_REF_NO
			SR_operator
			SR_settled_by
		} {
			append compulsory_fields [subst "$$f"]
		}

		if {$compulsory_fields == ""} {
			# We've got none of the compulsory fields, so bail
			err_bind "There aren't sufficient filters on the payment query.
				Please enter a new search."
			ADMIN::PMT::go_pmt_query
			return
		}
	}

	# Load up an array with the names of the pmt batch types
	# mapped to the batch codes
	set sql [subst {
		select
			batch_type,
			desc
		from
			tPmtBatchType
		order by batch_type
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set BATCH([db_get_col $res $i batch_type]) [db_get_col $res $i desc]
	}
	db_close $res


	set where        [list]
	set select       ""
	set from         ""
	set more_where   ""
	set pend_join    ""
	set pc_join      ",outer tPmtCC pc"
	set pb_join      ",outer tPmtPB pb"
	set pa_join      ""
	set pm_join      ",outer tPmtMB p_mb"
	set pe_join      ",outer tPmtEnvoy p_envoy, outer (tExtSubCPMLink scl, tExtSubPayMthd epm)"
	set pn_join      ",outer tPmtNeteller p_ntlr"
	set pc2p_join    ",outer tPmtC2P p_c2p"
	set pp_join      ",outer tPmtPayPal p_ppal"
	set psc_join     ",outer tPmtPSC p_psc"
	set pmg_pay_mthd ""
	set fraud_join   ",outer tPmtPendStatus pst"
	set cgrp_join    ""

	#
	# Customer fields
	#
	if {[string length $SR_username] > 0} {
		if {$SR_upper_username == "Y"} {
			lappend where "c.username_uc like [upper_q '${SR_username}%']"
		} else {
			lappend where "c.username like \"${SR_username}%\""
		}
	}

	if {[string length $SR_CCYCode] > 0} {
		lappend where "a.ccy_code = '$SR_CCYCode'"
	}

	if {[string length $SR_CNTRYCode] > 0} {
		lappend where "c.country_code = '$SR_CNTRYCode'"
	}

	# index on the customer's id
	if {[string length $SR_cust_id] > 0} {
		lappend where "r.cust_id = $SR_cust_id"
	}

	if {[string length $SR_fname] > 0} {
		lappend where "[upper_q r.fname] = [upper_q '$SR_fname']"
	}

	if {[string length $SR_lname] > 0} {
		lappend where [get_indexed_sql_query $SR_lname lname]
	}

	if {[string length $SR_email] > 0} {
		lappend where [get_indexed_sql_query $SR_email email]
	}

	if { [OT_CfgGetTrue FUNC_PMT_SEARCH_CUST_GRP] } {

		set cgrp_join  ",outer tCustCode cco"
		set select "$select, nvl(cco.desc,'N/A') as cust_code_desc"
		lappend where "cco.cust_code = r.code"

		if {[string length $SR_CustGrp] > 0} {
			# Are we searching only Platinum ?
			if {$SR_CustGrp == "OPT_AllPlatinum"} {

				set plat_search_string [ADMIN::CUST::get_platinum_search_string]

				if {$plat_search_string != ""} {
					lappend where "r.code in $plat_search_string"
				}

			} else {
				lappend where "r.code = '$SR_CustGrp'"
			}
		}
	}

	if {[string length $SR_acct_no] > 0} {
		if {$SR_acct_no_exact == "Y"} {
			lappend where "c.acct_no = '$SR_acct_no'"
		} else {
			lappend where "c.acct_no like '$SR_acct_no%'"
		}
	}

	# filter on the status
	if {$SR_status != ""} {

		# Pending Payment Searched are going to be quite common so
		# we want the search to be driven from the tPmtPending table
		if {$SR_status == "P" || $SR_status == "PD"} {
			set pend_join ",tPmtPending pp"
			lappend where "p.pmt_id = pp.pmt_id"
			if {$SR_status == "PD"} {
				lappend where "NVL(pp.process_date, current) > current"
			} elseif {$SR_status == "P"} {
				lappend where "NVL(pp.process_date, current) <= current"
			}
		} else {
			lappend where "p.status in ('[join [split $SR_status {}] {', '}]')"
		}
	}
	# excluding status
	if {$SR_not_status != ""} {
		lappend where "p.status not in ('[join [split $SR_not_status {}] {', '}]')"
	}

	# The javascript should ensure that we've got a date range or a selection
	# on the drop-down box
	if {$SR_date_range != "" && $SR_date_1 == "" && $SR_date_2 == ""} {
		set now [clock seconds]

		switch -exact -- $SR_date_range {
			"HR" {
				# Last hour
				set hour [expr {$now-60*60}]
				set SR_date_1 [clock format $hour -format {%Y-%m-%d %H:%M:%S}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"TD" {
				# today
				set SR_date_1 [clock format $now -format {%Y-%m-%d 00:00:00}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d 23:59:59}]
			}
			"YD" {
				# yesterday
				set yday [expr {$now-60*60*24}]
				set SR_date_1   [clock format $yday -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $yday -format {%Y-%m-%d 23:59:59}]
			}
			"L3" {
				# last 3 days
				set 3day [expr {$now-3*60*60*24}]
				set SR_date_1   [clock format $3day -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"L7" {
				# last 7 days
				set 7day [expr {$now-7*60*60*24}]
				set SR_date_1   [clock format $7day -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"CM" {
				# This month
				set SR_date_1 [clock format $now -format {%Y-%m-01 00:00:00}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			default {
				set SR_date_1 [set SR_date_2 ""]
			}
		}
	}

	if {$SR_date_1 != ""} {
	    tpBindString SR_date_1 $SR_date_1
	    lappend where "p.cr_date >= '$SR_date_1'"
	}
	if {$SR_date_2 != ""} {
	    tpBindString SR_date_2 $SR_date_2
	    lappend where "p.cr_date <= '$SR_date_2'"
	}

	if {$SR_payment_sort != ""} {
		lappend where "p.payment_sort = '$SR_payment_sort'"
	}

	if {$SR_channel != ""} {
		lappend where "p.source = '$SR_channel'"
	}

	set retry_prev_outer "outer"
	set retry_resub_outer "outer"

	set SR_resub_status [reqGetArg SR_resub_status]

	if {$SR_resub_status != ""} {
		if {$SR_resub_status == "R"} {
			set retry_prev_outer ""
		} else {
			set retry_resub_outer ""
		}
	}

	if {[string length $SR_pay_mthd] > 0} {
		lappend where "pm.pay_mthd = '$SR_pay_mthd'"
	}

	if {[string length $SR_PG_host] > 0} {

		# Get the PMG payment method as we need to focus on
		# on a particular PMG based on it's pay method
		set pmg_pay_mthd [payment_gateway::get_pmg_pay_mthd $SR_PG_host "host"]

		switch -exact $pmg_pay_mthd {
			"CC" {
				set pc_join ",tPmtCC pc"
				lappend where "pc.pg_host_id = $SR_PG_host"
				}
			"MB" {
				set pm_join ",tPmtMB p_mb"
				lappend where "p_mb.pg_host_id = $SR_PG_host"
			}
			"ENVO" {
				set pe_join ",tPmtEnvoy p_envoy, tExtSubCPMLink scl, tExtPayMthd epm"
				lappend where "p_envoy.pg_host_id = $SR_PG_host"
			}
			"NTLR" {
				set pn_join ",tPmtNeteller p_ntlr"
				lappend where "p_ntlr.pg_host_id = $SR_PG_host"
			}
			"C2P" {
				set pc2p_join ",tPmtC2P p_c2p"
				lappend where "p_c2p.pg_host_id = $SR_PG_host"
			}
			"PPAL" {
				set pp_join ",tPmtPayPal p_ppal"
				lappend where "p_ppal.pg_host_id = $SR_PG_host"
			}
			"PSC" {
				set psc_join ",tPmtPSC p_psc"
				lappend where "p_psc.pg_host_id = $SR_PG_host"
			}
			default {
				# do nothing
			}
		}
	}

	if {[string length $SR_PG_acct] > 0} {

		if {$pmg_pay_mthd == ""} {
			set pmg_pay_mthd [payment_gateway::get_pmg_pay_mthd $SR_PG_acct "acct"]
		}

		switch -exact $pmg_pay_mthd {
			"CC" {
				set pc_join ",tPmtCC pc"
				lappend where "pc.pg_acct_id = $SR_PG_acct"
			}
			"MB" {
				set pm_join ",tPmtMB p_mb"
				lappend where "p_mb.pg_acct_id = $SR_PG_acct"
			}
			"ENVO" {
				set pe_join ",tPmtEnvoy p_envoy, tExtSubCPMLink scl, tExtPayMthd epm"
				lappend where "p_envoy.pg_acct_id = $SR_PG_acct"
			}
			"NTLR" {
				set pn_join ",tPmtNeteller p_ntlr"
				lappend where "p_ntlr.pg_acct_id = $SR_PG_acct"
			}
			"C2P" {
				set pc2p_join ",tPmtC2P p_c2p"
				lappend where "p_c2p.pg_acct_id = $SR_PG_acct"
			}
			"PPAL" {
				set pp_join ",tPmtPayPal p_ppal"
				lappend where "p_ppal.pg_acct_id = $SR_PG_acct"
			}
			"PSC" {
				set psc_join ",tPmtPSC p_psc"
				lappend where "p_psc.pg_acct_id = $SR_PG_acct"
			}
			default {
				# do nothing
			}
		}
	}

	# index on the cpm_id
	if {[string length $SR_cpm_id] > 0} {
		lappend where "p.cpm_id = $SR_cpm_id"
	}

	if {[string length $SR_PMT_ID] > 0} {
		if {![regexp {^[0-9]+$} $SR_PMT_ID]} {
			err_bind "Payment Id entered is invaild.Payment Id can only have numeric characters."
			ADMIN::PMT::go_pmt_query
			return
		} else {
			# user entered payment ID
			lappend where "p.pmt_id = $SR_PMT_ID"
		}
	}

	set SR_pmt_receipt [reqGetArg SR_pmt_receipt]
	if {[string length $SR_pmt_receipt] > 0} {
		# user entered payment receipt
		# ignore all others - can't refine search any more than this.
		# split receipt on '/' to get <pmt_sort> <pmt_id> <F|N>
		set receipt_list [split $SR_pmt_receipt "/"]
		# only search on pmt_id if the receipt tag matches the environment
		# - also validate the other parts of the receipt while we're at it.
		if {[lindex $receipt_list 2] != [OT_CfgGet PMT_RECEIPT_TAG ""] ||
			[lsearch -exact {[list D W]} [lindex $receipt_list 0]] < 0 ||
			[regexp {^[0-9]*$} [lindex $receipt_list 1]] == 0 } {
			err_bind "receipt in incorrect format - \
				should be < D|W >/< number >/< 1 character tag >"
			ADMIN::PMT::go_pmt_query
			return
		}
		set receipt_pmt_id [lindex $receipt_list 1]
		set where [list [subst { p.pmt_id = "$receipt_pmt_id" }]]
	}

	set SR_REF_NO [reqGetArg SR_REF_NO]
	if {[string length $SR_REF_NO] > 0} {
		# user entered payment ref no. not the same as basic pay.
		lappend where "pc.ref_no = $SR_REF_NO"
		set pc_join ",tPmtCC pc"

	}

	if {[string length $SR_operator] > 0} {
		set from "$from tAdminUser au1, "
		lappend where "p.oper_id    = au1.user_id and au1.username = '$SR_operator'"
	}

	if {[string length $SR_settled_by] > 0} {
		set from "$from tAdminUser au2, "
		lappend where "p.settled_by = au2.user_id and au2.username = '$SR_settled_by'"
	}

	if {[OT_CfgGet FUNC_PAY_SEARCH_ON_FULFILL 0]} {

		if {$SR_fulfilled == "Y"} {
			lappend where "pc.fulfilled_at is not null"
			set pc_join ",tPmtCC pc"
		} elseif {$SR_fulfilled == "N"} {
			lappend where "pc.fulfilled_at is null"
			set pc_join ",tPmtCC pc"
		}

		if {$SR_fulfil_status == "Y"} {
			lappend where "NVL(pc.fulfil_status,'-') = 'Y'"
			set pc_join ",tPmtCC pc"
		} elseif {$SR_fulfil_status == "N"} {
			lappend where "NVL(pc.fulfil_status,'-') = 'N'"
			set pc_join ",tPmtCC pc"
		}
	}

	if {[OT_CfgGet DELAY_AND_CANCEL_ERP_PAYMENTS 0]} {
		set select "$select , pg.pg_trans_type"
		set more_where " and pg.pg_acct_id = pc.pg_acct_id"

		if {$pc_join == ",tPmtCC pc"} {
			set pc_join ",tPmtCC pc, tPmtGateAcct pg"
		} else {
			set pc_join ",outer (tPmtCC pc, tPmtGateAcct pg)"
		}
	}

	if {[string length $SR_REF_NUM] > 0} {
		# user entered a reference number for Basic Pay
		# ignore all others - can't refine search any more than this!?
		set where [list "pa.ext_ref = '$SR_REF_NUM'" "p.pmt_id  = pa.pmt_id"]
		set pa_join ",tPmtBasic pa"
	}

	if {$SR_lr_auth_status != "" || $SR_fc_auth_status != ""} {
		if {$SR_lr_auth_status == "P" || $SR_fc_auth_status == "P"} {
			tpSetVar PendFraudCheck 1
		}
		set fraud_join ",tPmtPendStatus pst"

		set clause ""
		if {$SR_lr_auth_status != ""} {
			set clause "NVL(pst.large_ret_auth, '-') = '$SR_lr_auth_status'"
		}
		if {$SR_fc_auth_status != ""} {
			if {$clause != ""} {
				append clause " OR "
			}
			append clause "NVL(pst.fraud_check_auth, '-') = '$SR_fc_auth_status'"
		}
		set clause "(${clause})"

		lappend where $clause

	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	# Only return the first n items from this search.
	set first_n ""
	if {[set n [OT_CfgGet SELECT_FIRST_N 0]]} {
		set first_n " first $n "
	}

	set sql [subst {
		select $first_n
			c.username,
			c.acct_no,
			c.cust_id,
			c.elite,
			r.fname,
			r.lname,
			a.acct_id,
			a.ccy_code,
			p.pmt_id,
			rtry_prev.pmt_id as prev_pmt_id,
			rtry_resub.retry_pmt_id as retry_pmt_id,
			p.cr_date,
			p.source,
			p.settled_by,
			p.oper_id,
			p.settled_by,
			p.payment_sort,
			p.amount,
			p.commission,
			p.status,
			p.ipaddr,
			pm.pay_mthd,
			pm.desc,
			pc.ref_no,
			pe.ref_no as ep_ref_no,
			pc.fulfilled_at,
			pc.fulfil_status,
			pc.last_fulfil_att,
			cpm.cpm_id,
			case
				when p.ref_key = 'CSH' then pcsh.extra_info
				else pc.gw_ret_msg
			end as cc_ret_msg,
			case
				when pm.pay_mthd = 'BANK' then b.bank_acct_no
				else ''
			end as bank_acct_no,
			case
				when pm.pay_mthd = 'BANK' then b.bank_sort_code
				else ''
			end as bank_sort_code,
			pb.gw_ret_msg pb_ret_msg,
			pcsh.outlet,
			pgdep.pay_type as gdep_pay_type,
			pgwtd.pay_type as gwtd_pay_type,
			(p.amount / cy.exch_rate) as sys_amt,
			pst.large_ret_auth,
			pst.lr_auth_user_id,
			pst.lr_auth_date,
			pst.fraud_check_auth,
			pst.fc_auth_user_id,
			pst.fc_auth_date,
			epm.desc as sub_mthd_desc
			$select
		from
			tPmt p,
			$retry_prev_outer tPmtRetryLink rtry_prev,
			$retry_resub_outer tPmtRetryLink rtry_resub,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tCustPayMthd cpm,
			tPayMthd pm,
			tCcy cy,
			$from
			outer tCpmBank b,
			outer tpmtep pe,
			outer tpmtcsh pcsh,
			outer tpmtgdep pgdep,
			outer tpmtgwtd pgwtd
			$pend_join
			$pc_join
			$pa_join
			$pb_join
			$pm_join
			$pe_join
			$pn_join
			$pp_join
			$pc2p_join
			$psc_join
			$fraud_join
			$cgrp_join
		where
			p.pmt_id     = rtry_prev.retry_pmt_id and
			p.pmt_id     = rtry_resub.pmt_id and
			a.ccy_code   = cy.ccy_code and
			p.pmt_id     = pc.pmt_id and
			p.pmt_id     = pb.pmt_id and
			p.pmt_id     = pe.pmt_id and
			p.pmt_id     = pcsh.pmt_id and
			p.pmt_id     = pgdep.pmt_id and
			p.pmt_id     = pgwtd.pmt_id and
			p.pmt_id     = p_c2p.pmt_id and
			p.pmt_id     = p_ntlr.pmt_id and
			p.pmt_id     = p_ppal.pmt_id and
			p.pmt_id     = p_mb.pmt_id and
			p.pmt_id     = p_envoy.pmt_id and
			p.pmt_id     = p_psc.pmt_id and
			p.acct_id    = a.acct_id and
			a.cust_id    = c.cust_id and
			r.cust_id    = c.cust_id and
			p.cpm_id     = b.cpm_id and
			p.cpm_id     = cpm.cpm_id and
			cpm.pay_mthd = pm.pay_mthd and
			p.pmt_id     = pst.pmt_id and
			a.owner      <> 'D' and
			p.cpm_id     = scl.cpm_id and
			scl.sub_type_code = epm.sub_type_code
			$where
			$more_where
		order by
			p.pmt_id
	}]
	ob::log::write INFO $sql

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumPmts [set NumPmts [db_get_nrows $res]]
	set high_val_perm [op_allowed PmtAuthDeclineHighVa]
	set auth_pmt_perm [op_allowed UpdPaymentStatus]
	set auth_wu_perm [op_allowed PmtWUAuth]
	set max_auth_val [OT_CfgGet AUTH_LARGE_PMT 6000]

	global DATA

	array set DATA [list]
	set elite 0

	set output_data ""

	for {set r 0} {$r < $NumPmts} {incr r} {

		set DATA($r,acct_no) [acct_no_enc  [db_get_col $res $r acct_no]]
		foreach f [db_get_colnames $res] {
			set DATA($r,$f) [db_get_col $res $r $f]
		}
		set DATA($r,auth_disabled) ""
		if {[OT_CfgGet FUNC_PERM_AUTH_LARGE_PMT 0] && !($high_val_perm) && ($DATA($r,sys_amt) > $max_auth_val)} {
			set DATA($r,auth_disabled) "disabled"
		}
		if {!($auth_pmt_perm) && ($DATA($r,pay_mthd) != "WU")} {
			set DATA($r,auth_disabled) "disabled"
		}
		if {!($auth_wu_perm) && ($DATA($r,pay_mthd) == "WU")} {
			set DATA($r,auth_disabled) "disabled"
		}

		if {[db_get_col $res $r pay_mthd] == "BANK" && [db_get_col $res $r status] == "P"} {
			set str "[db_get_col $res $r bank_sort_code][db_get_col $res $r bank_acct_no]099"
			set amount [expr [db_get_col $res $r amount]*100]
			set str "$str                  [format %011u [expr round($amount)]]"
			set str "$str                  Ref [db_get_col $res $r pmt_id]        "
			set str "$str[db_get_col $res $r fname] [db_get_col $res $r lname]\r\n"
			append output_data $str
		}

		set DATA($r,acct_no)          [acct_no_enc  [db_get_col $res $r acct_no]]
		set DATA($r,cust_id)          [db_get_col $res $r cust_id]
		set DATA($r,elite)            [db_get_col $res $r elite]
		set DATA($r,username)         [db_get_col $res $r username]
		set DATA($r,cr_date)          [db_get_col $res $r cr_date]
		set DATA($r,ccy_code)         [db_get_col $res $r ccy_code]
		set DATA($r,source)           [db_get_col $res $r source]
		set DATA($r,status)           [db_get_col $res $r status]
		set DATA($r,payment_sort)     [db_get_col $res $r payment_sort]
		set DATA($r,amount)           [db_get_col $res $r amount]
		set DATA($r,commission)       [db_get_col $res $r commission]
		set DATA($r,pmt_id)           [db_get_col $res $r pmt_id]
		set DATA($r,prev_pmt_id)      [db_get_col $res $r prev_pmt_id]
		set DATA($r,retry_pmt_id)     [db_get_col $res $r retry_pmt_id]
		set DATA($r,pay_mthd)         [db_get_col $res $r pay_mthd]
		set DATA($r,acct_no)          [db_get_col $res $r acct_no]
		set DATA($r,ref_no)           [db_get_col $res $r ref_no]
		set DATA($r,cc_ret_msg)       [db_get_col $res $r cc_ret_msg]
		set DATA($r,ep_ref_no)        [db_get_col $res $r ep_ref_no]
		set DATA($r,pb_ret_msg)       [db_get_col $res $r pb_ret_msg]
		set DATA($r,ipaddr)           [db_get_col $res $r ipaddr]
		set DATA($r,outlet)           [db_get_col $res $r outlet]
		set DATA($r,fulfilled_at)     [db_get_col $res $r fulfilled_at]
		set DATA($r,last_fulfil_att)  [db_get_col $res $r last_fulfil_att]
		set DATA($r,fulfil_status)    [db_get_col $res $r fulfil_status]
		set DATA($r,large_ret_auth)   [db_get_col $res $r large_ret_auth]
		set DATA($r,lr_auth_user_id)  [db_get_col $res $r lr_auth_user_id]
		set DATA($r,lr_auth_date)     [db_get_col $res $r lr_auth_date]
		set DATA($r,fraud_check_auth) [db_get_col $res $r fraud_check_auth]
		set DATA($r,fc_auth_user_id)  [db_get_col $res $r fc_auth_user_id]
		set DATA($r,fc_auth_date)     [db_get_col $res $r fc_auth_date]

		set fraud_flags ""
		if {$DATA($r,fraud_check_auth) == "P"} {
			set fraud_flags "FC"
		}
		if {$DATA($r,large_ret_auth) == "P"} {
			append fraud_flags " LR"
		}
		set DATA($r,fraud_flags) $fraud_flags

		if {[db_get_col $res $r elite] == "Y"} {
			incr elite
		}
	}
	if {[reqGetArg toFile] == 1} {
		tpBufAddHdr "Content-Type"  "text/plain;"
		tpBufAddHdr "Content-Disposition" "attachment; filename=\"BACS.txt\";"
		tpBufWrite $output_data
		return
	}

	tpBindVar CustId            DATA cust_id          pmt_idx
	tpBindVar Username          DATA username         pmt_idx
	tpBindVar Elite             DATA elite            pmt_idx
	tpBindVar Date              DATA cr_date          pmt_idx
	tpBindVar CCYCode           DATA ccy_code         pmt_idx
	tpBindVar PmtSource         DATA source           pmt_idx
	tpBindVar PmtStatus         DATA status           pmt_idx
	tpBindVar CustGroup         DATA cust_code_desc   pmt_idx
	tpBindVar PmtSort           DATA payment_sort     pmt_idx
	tpBindVar Amount            DATA amount           pmt_idx
	tpBindVar Commission        DATA commission       pmt_idx
	tpBindVar pmt_id            DATA pmt_id           pmt_idx
	tpBindVar prev_pmt_id       DATA prev_pmt_id      pmt_idx
	tpBindVar retry_pmt_id      DATA retry_pmt_id     pmt_idx
	tpBindVar PmtMthd           DATA pay_mthd         pmt_idx
	tpBindVar AcctNo            DATA acct_no          pmt_idx
	tpBindVar RefNo             DATA ref_no           pmt_idx
	tpBindVar CC_ret_msg        DATA cc_ret_msg       pmt_idx
	tpBindVar EpRefNo           DATA ep_ref_no        pmt_idx
	tpBindVar PB_ret_msg        DATA pb_ret_msg       pmt_idx
	tpBindVar IPAddress         DATA ipaddr           pmt_idx
	tpBindVar Outlet            DATA outlet           pmt_idx
	tpBindVar FulfilledAt       DATA fulfilled_at     pmt_idx
	tpBindVar Sys_amt           DATA sys_amt          pmt_idx
	tpBindVar Auth_Disabled     DATA auth_disabled    pmt_idx
	tpBindVar LastFulfilAttempt DATA last_fulfil_att  pmt_idx
	tpBindVar FulfilStatus      DATA fulfil_status    pmt_idx
	tpBindVar LargeRetAuth      DATA large_ret_auth   pmt_idx
	tpBindVar FraudCheckAuth    DATA fraud_check_auth pmt_idx
	tpBindVar FraudFlags        DATA fraud_flags      pmt_idx

	tpSetVar IS_ELITE $elite

	if {[OT_CfgGet DELAY_AND_CANCEL_ERP_PAYMENTS 0]} {
		tpBindVar PG_TRANS_TYPE DATA pg_trans_type pmt_idx
	}

	if {$NumPmts > 0} {
		for {set r 0} {$r < $NumPmts} {incr r} {
			# Set Method to be "Method(agent)" if it is BASC
			if {[db_get_col $res $r pay_mthd] == "BASC"} {
				set cpm_id [db_get_col $res $r cpm_id]
				if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
					set desc "MCA"
				} else {
					set desc "Basic Pay"
				}
				tpBindString CPM_Desc_$r "$desc ([ADMIN::PMT::bind_detail_BASC $cpm_id 1])"
			} elseif {[db_get_col $res $r pay_mthd] == "GDEP"} {
				set pay_type [db_get_col $res $r gdep_pay_type]
				set pay_type_desc [db_get_col $res $r gdep_pay_type]
				if {[info exists BATCH($pay_type)]} {
					set pay_type_desc $BATCH($pay_type)
				}
				tpBindString CPM_Desc_$r "[db_get_col $res $r desc] ($pay_type_desc)"
			} elseif {[db_get_col $res $r pay_mthd] == "GWTD"} {
				set pay_type [db_get_col $res $r gwtd_pay_type]
				set pay_type_desc [db_get_col $res $r gwtd_pay_type]
				if {[info exists BATCH($pay_type)]} {
					set pay_type_desc $BATCH($pay_type)
				}
				tpBindString CPM_Desc_$r "[db_get_col $res $r desc] ($pay_type_desc)"
			} elseif {[db_get_col $res $r pay_mthd] == "ENVO"} {
				tpBindString CPM_Desc_$r "[db_get_col $res $r desc] [db_get_col $res $r sub_mthd_desc]"
			} else {
				tpBindString CPM_Desc_$r [db_get_col $res $r desc]
			}
		}
	}

	#
	# now calculate some totals
	#
	set sql [subst {
		select
			sum(p.amount) as amount,
			a.ccy_code
		from
			tPmt p,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tCustPayMthd cpm,
			$from
			tPayMthd pm
			$pend_join
			$pa_join
			$pc_join
			$pm_join
			$pe_join
			$pn_join
			$pp_join
			$pc2p_join
			$psc_join
			$fraud_join
			$cgrp_join
		where
			p.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			p.cpm_id  = cpm.cpm_id and
			p.pmt_id  = pc.pmt_id and
			p.pmt_id  = p_mb.pmt_id and
			p.pmt_id  = p_envoy.pmt_id and
			p.pmt_id  = p_ntlr.pmt_id and
			p.pmt_id  = p_c2p.pmt_id and
			cpm.pay_mthd = pm.pay_mthd and
			p.pmt_id  = p_ppal.pmt_id and
			p.pmt_id  = p_psc.pmt_id and
			p.pmt_id  = pst.pmt_id and
			a.owner   <> 'D' and
			p.cpm_id  = scl.cpm_id and
			scl.sub_type_code = epm.sub_type_code
			$where
		group by
			2
	}]

	set stmt   [inf_prep_sql $DB $sql]
	set rs_sum [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs_sum]

	tpSetVar SUM_nrows $nrows
	tpBindTcl SUM_total sb_res_data $rs_sum s_idx amount
	tpBindTcl SUM_ccy   sb_res_data $rs_sum s_idx ccy_code

	asPlayFile -nocache pmt/pmt_qry_list.html

	unset DATA

	db_close $res
	db_close $rs_sum
}



# Search for a PayPal payment using the PayPal transaction id
#
proc do_pmt_paypal_query args {
	global DB

	set pp_txn_id [string trim [reqGetArg pp_txn_id]]

	# don't want to seach for all the empty ones...
	if {$pp_txn_id == ""} {
		err_bind "A transaction id must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set sql [subst {
		select
			pmt_id
		from
			tPmtPayPal pp
		where
			pp.pp_txn_id = '$pp_txn_id'
	}]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		ob_log::write ERROR {do_pmt_paypal_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query

	} else {

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find PayPal payment with transaction id '$pp_txn_id'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}
}

proc do_pmt_ukash_query args {
	global DB

	set pay_mthd      [string trim [reqGetArg pay_mthd]]
	set ukash_voucher [string trim [reqGetArg ukash_voucher]]
	set ukash_txn_id  [string trim [reqGetArg ukash_txn_id]]

	ob::log::write INFO {do_pmt_ukash_query($pay_mthd,$ukash_voucher,\
		$ukash_txn_id)}

	switch -exact $pay_mthd {
		"UKSH" {
			set cpm_desc "Quickcash"
		}
		"IKSH" {
			set cpm_desc "Ukash International"
		}
		default {
			set cpm_desc $pay_mthd
		}
	}

	if {$ukash_voucher == {} && $ukash_txn_id == {}} {
		err_bind "Please enter either a $cpm_desc voucher or transaction id"
		ADMIN::PMT::go_pmt_query
		return
	}

	set where [list]


	if {$ukash_voucher != {}} {
		set enc [ob_ukash::encrypt_voucher $ukash_voucher]
		lappend where [subst {
			u.enc_voucher = '$enc'
		}]
	}

	if {$ukash_txn_id != {}} {
		lappend where [subst {
			u.txn_id = '$ukash_txn_id'
		}]
	}

	set sql [subst {
		select
			u.pmt_id
		from
			tPmtUkash u,
			tPmt      p
		where
			p.ref_key = '$pay_mthd' and
			p.pmt_id  = u.pmt_id    and
			[join $where { and }]
	}]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		ob::log::write ERROR {do_pmt_ukash_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query

	} else {

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			ADMIN::TXN::GPMT::go_pmt $pmt_id
		} elseif {$nrows > 1} {

			set pmt_ids [list]

			for {set i 0} {$i < $nrows} {incr i} {
				lappend pmt_ids [db_get_col $res $i pmt_id]
			}

			ADMIN::PMT::do_pmt_query $pmt_ids

		} else {
			err_bind "Can't find $cpm_desc payment"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}
}

# Search for a neteller payment using the transaction id
#
proc do_pmt_ntlr_query args {
	global DB

	set ntlr_txn_id [string trim [reqGetArg ntlr_txn_id]]

	ob::log::write INFO {do_pmt_ntlr_query: $ntlr_txn_id}

	set sql {
		select
			pmt_id
		from
			tPmtNeteller ntlr
		where
			ntlr.gw_uid = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ntlr_txn_id]
		inf_close_stmt $stmt
	} msg]} {

		ob::log::write ERROR {do_pmt_ntlr_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query

	} else {

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			ADMIN::TXN::GPMT::go_pmt $pmt_id
		} else {
			err_bind "Can't find Neteller payment with transaction id '$ntlr_txn_id'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}
}

# Search for a clickandbuy payment using the BDR id
#
proc do_pmt_clickandbuy_query args {
	global DB

	set cb_bdr_id [string trim [reqGetArg cb_bdr_id]]

	# don't want to seach for all the empty ones...
	if {$cb_bdr_id == ""} {
		err_bind "A BDR id must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set sql [subst {
		select
			pmt_id
		from
			tPmtClickAndBuy
		where
			cb_bdr_id = '$cb_bdr_id'
	}]

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {do_pmt_clickandbuy_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query
	} else {
		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find Click and Buy payment with BDR ID '$cb_bdr_id'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}

}

# Search for a click2pay payment using the gateway uid
#
proc do_pmt_click2pay_query args {
	global DB

	set gw_uid [string trim [reqGetArg gw_uid]]

	# don't want to seach for all the empty ones...
	if {$gw_uid == ""} {
		err_bind "A Gateway UID must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set sql {
		select
			pmt_id
		from
			tPmtC2P
		where
			gw_uid = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $gw_uid]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {do_pmt_click2pay_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query
	} else {
		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find Click2Pay payment with Gateway UID '$gw_uid'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}

}

# Search for a money bookers payment using the ref id
#
proc do_pmt_moneybookers_query args {
	global DB

	set mb_transaction_id [string trim [reqGetArg mb_transaction_id]]

	# don't want to seach for all the empty ones...
	if {$mb_transaction_id == ""} {
		err_bind "A Ref Id must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set sql {
		select
			pmt_id
		from
			tPmtMB
		where
			mb_transaction_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $mb_transaction_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {do_pmt_moneybookers_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query
	} else {
		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find Money Bookers payment with Ref id '$mb_transaction_id'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}

}

# Search for a envoy payment using the epac ref
#
proc do_pmt_envoy_query args {
	global DB

	set fn "PMT::do_pmt_envoy_query: "

	set envoy_epac_ref [string trim [reqGetArg envoy_epac_ref]]

	# don't want to seach for all the empty ones...
	if {$envoy_epac_ref == ""} {
		err_bind "A EPAC Ref must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set sql {
		select
			pmt_id
		from
			tPmtEnvoy
		where
			epacs_ref = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $envoy_epac_ref]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {$fn Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query
	} else {
		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find Envoy payment with Ref id '$envoy_epac_ref'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}


}

# Search for a pay safe card payment using the mtid id
#
proc do_pmt_paysafecard_query args {
	global DB

	set psc_transaction_id [string trim [reqGetArg psc_transaction_id]]

	# don't want to seach for all the empty ones...
	if {$psc_transaction_id == ""} {
		err_bind "A Transaction Id must be provided"
		ADMIN::PMT::go_pmt_query
		return
	}

	set len [expr [string length $psc_transaction_id] -15]
	set cust_id [string range $psc_transaction_id 0 $len]

	set sql {
		select
			p.pmt_id
		from
			tAcct a,
			tPmt p
		where
			p.acct_id = a.acct_id and
			a.cust_id = ? and
			p.unique_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id $psc_transaction_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {do_pmt_paysafecard_query: Error executing query - $msg}
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_pmt_query
	} else {
		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set pmt_id [db_get_col $res 0 pmt_id]
			reqSetArg pmt_id $pmt_id
			ADMIN::TXN::GPMT::go_pmt
		} else {
			err_bind "Can't find Pay Safe Card payment with Ref id '$psc_transaction_id'"
			ADMIN::PMT::go_pmt_query
		}

		db_close $res
	}

}

#
# ----------------------------------------------------------------------------
# Update a specific payment - route to the appropriate handler based on
# the sort of payment
# ----------------------------------------------------------------------------
#
proc do_pmt args {

	if {[reqGetArg SubmitName] == "Back"} {
		do_pmt_query
		return
	}
}

}
