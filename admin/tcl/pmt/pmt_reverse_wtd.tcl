# ==============================================================
# $Id: pmt_reverse_wtd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

	asSetAct ADMIN::PMT::GoReversibleWtd [namespace code go_reversible_wtd]
	asSetAct ADMIN::PMT::DoReversibleWtd [namespace code do_reversible_wtd]
}

#
# Build the list of all reversible withdrawals on an account and bind it.
#
proc ADMIN::PMT::go_reversible_wtd {} {

	global DB

	variable REV_WTD
	GC::mark ADMIN::PMT::REV_WTD

	set acct_id [reqGetArg AcctId]
	tpBindString AcctId $acct_id

	set CustId [reqGetArg CustId]
	tpBindString CustId $CustId

	set sql {
		select
			p.cr_date,
			p.amount,
			pm.pay_mthd,
			pm.desc as pmt_mthd_desc,
			p.status,
			p.pmt_id,
			a.ccy_code,
			pp.process_date,
			c.cust_id,
			c.username
		from
			tPmt p,
			tPmtPending pp,
			tAcct a,
			tCustPayMthd cpm,
			tPayMthd pm,
			tCustomer c
		where
				a.acct_id = ?
			and p.acct_id = a.acct_id
			and a.cust_id = c.cust_id
			and p.pmt_id  = pp.pmt_id
			and p.status  = 'P'
			and pp.process_date > ?
			and p.payment_sort = 'W'
			and p.cpm_id     = cpm.cpm_id
			and cpm.pay_mthd = pm.pay_mthd
	}

	set current_server_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $acct_id $current_server_date]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set total_wtd 0

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set REV_WTD($i,$c) [db_get_col $rs $i $c]
		}
		set total_wtd [expr {$total_wtd + [db_get_col $rs $i amount]}]
	}

	set total_wtd [format "%.2f" $total_wtd]

	tpBindString num_reversible_wtd $nrows
	tpBindString total_wtd          $total_wtd
	tpBindString CustId             $CustId

	foreach c [db_get_colnames $rs] {
		tpBindVar $c ADMIN::PMT::REV_WTD $c rev_wtd_idx
	}

	db_close $rs

	# check 'no_reverse_wtd' flag
	set no_rev_wtd_flag_sql {
		select
			f.flag_value
		from
			tCustomerflag f,
			tCustomer c,
			tAcct a
		where
				a.acct_id = ?
			and f.flag_name = 'no_reverse_wtd'
			and f.cust_id = c.cust_id
			and c.cust_id = a.cust_id
	}

	set no_rev_wtd_flag_stmt [inf_prep_sql $DB $no_rev_wtd_flag_sql]
	set no_rev_wtd_flag_res  [inf_exec_stmt $no_rev_wtd_flag_stmt $acct_id]
	inf_close_stmt $no_rev_wtd_flag_stmt

	if {[db_get_nrows $no_rev_wtd_flag_res] == 0 || [db_get_col $no_rev_wtd_flag_res 0 flag_value] == "N"} {
		tpSetVar no_override_flag 1
	}

	db_close $no_rev_wtd_flag_res


	asPlayFile -nocache pmt/pmt_reverse_wtd.html
}


#
# Switch to either reverse of force through a list of pmts
#
proc ADMIN::PMT::do_reversible_wtd {} {

	set action [reqGetArg submit_name]

	switch -exact $action {
		"Reverse" {
			_do_reverse_wtd
		}
		"Force" {
			_do_force_wtd
		}
	}
}

#
# Actually reverse pmts
#
proc ADMIN::PMT::_do_reverse_wtd {} {

	global USERNAME

	if {![op_allowed RevCustWtd]} {
		return
		go_reversible_wtd
	}

	set success  [list]
	set failures [list]

	foreach p [reqGetArgs payments] {
		if {[reqGetArg reverse_pmt_${p}] == "Y"} {
			OT_LogWrite 6 "Attempting to reverse payment $p"
			set ret [OB_gen_payment::reverse_wtd $p $USERNAME]
			if {[lindex $ret 0]} {
				lappend success $p
			} else {
				lappend failures $p
			}
		}
	}

	if {[llength $failures]} {
		err_bind "the following pmts could not be reversed $failures"
	}

	if {[llength $success]} {
		msg_bind "successfully reversed pmts [join $success ,]"
	}

	go_reversible_wtd
}


#
# Actually force through pmts.
#
proc ADMIN::PMT::_do_force_wtd {} {

	global DB

	if {![op_allowed ForceCustWtd]} {
		return
		go_reversible_wtd
	}

	set success  [list]
	set failures [list]

	set sql {
		update
			tPmtPending
		set process_date = ?
		where pmt_id     = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	foreach p [reqGetArgs payments] {
		if {[reqGetArg force_pmt_${p}] == "Y"} {
			if {[catch {set rs [inf_exec_stmt $stmt $now $p]} msg]} {
				OT_LogWrite 2 "Could not force payment $p : $msg"
				lappend failures $p
			} else {
				lappend success $p
				db_close $rs
			}
		}
	}

	if {[llength $failures]} {
		err_bind "the following pmts could not be forced: $failures"
	}

	if {[llength $success]} {
		msg_bind "successfully forced pmts [join $success ,]"
	}

	go_reversible_wtd
}




