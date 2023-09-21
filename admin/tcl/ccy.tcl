# ==============================================================
# $Id: ccy.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::CCY {

asSetAct ADMIN::CCY::GoCCYList   [namespace code go_ccy_list]
asSetAct ADMIN::CCY::GoCCY       [namespace code go_ccy]
asSetAct ADMIN::CCY::DoCCY       [namespace code do_ccy]
asSetAct ADMIN::CCY::GoCCYHist   [namespace code go_ccy_hist]
asSetAct ADMIN::CCY::DoCCYHist   [namespace code do_ccy_hist]
asSetAct ADMIN::CCY::GoXSYSCCY   [namespace code go_xsys_ccy]
asSetAct ADMIN::CCY::DoXSYSCCY   [namespace code do_xsys_ccy]
asSetAct ADMIN::CCY::DoExtMapCCY [namespace code do_ccy_ext_map]

#
# ----------------------------------------------------------------------------
# Go to currency list
# ----------------------------------------------------------------------------
#
proc go_ccy_list args {

	global DB
	global ccy_info

	set sql [subst {
		select
			ccy_code,
			ccy_name,
			exch_rate,
			exch_rate_b,
			exch_rate_s,
			min_deposit,
			max_deposit,
			min_withdrawal,
			max_withdrawal,
			status,
			disporder,
			ext_multiplier,
			ext_ccy_code,
			cvv2_check_value,
			num_iso_code,
			default_bank_route
		from
			tCCY
		order by
			disporder asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumCCYs [db_get_nrows $res]

	tpBindTcl CCYCode       sb_res_data $res ccy_idx ccy_code
	tpBindTcl CCYName       sb_res_data $res ccy_idx ccy_name
	tpBindTcl CCYExchRate   sb_res_data $res ccy_idx exch_rate
	tpBindTcl CCYExchRateB  sb_res_data $res ccy_idx exch_rate_b
	tpBindTcl CCYExchRateS  sb_res_data $res ccy_idx exch_rate_s
	tpBindTcl CCYMinDep     sb_res_data $res ccy_idx min_deposit
	tpBindTcl CCYMaxDep     sb_res_data $res ccy_idx max_deposit
	tpBindTcl CCYMinWtd     sb_res_data $res ccy_idx min_withdrawal
	tpBindTcl CCYMaxWtd     sb_res_data $res ccy_idx max_withdrawal
	tpBindTcl CCYStatus     sb_res_data $res ccy_idx status
	tpBindTcl CCYDisporder  sb_res_data $res ccy_idx disporder
	tpBindTcl CCYMultiplier sb_res_data $res ccy_idx ext_multiplier
	tpBindTcl CCYExtCCYCode sb_res_data $res ccy_idx ext_ccy_code
	tpBindTcl CCYCVV2CheckValue sb_res_data $res ccy_idx cvv2_check_value
	tpBindTcl CCYNumIsoCode sb_res_data $res ccy_idx num_iso_code
	tpBindTcl CCYDefBankRoute   sb_res_data $res ccy_idx default_bank_route

	if {[OT_CfgGet FUNC_MCS_POKER 0] || [OT_CfgGet FUNC_XSYSHOST_CCY 0]} {

		# Retrieve list of all xsyshosts.

		set sql [subst {
			select
				system_id,
				name
			from
				txsyshost
		}]
		set stmt        [inf_prep_sql $DB $sql]
		set xsyshost_res [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		tpSetVar XSYS_num [set n_sys [db_get_nrows $xsyshost_res]]

		#
		# Retrieve information on currencies for each of those xsyshosts.
		#
		set sql [subst {
			select
				t1.ccy_code,
				t2.ccy_name,
				t1.exch_rate,
				t1.status
			from
				txsysccy t1,
				tccy t2
			where
				t1.system_id = ? and
				t1.ccy_code = t2.ccy_code
			order by
				ccy_code,system_id asc
		}]

		set stmt [inf_prep_sql $DB $sql]

		for {set s 0} {$s < $n_sys} {incr s} {

			set sys_id [db_get_col $xsyshost_res $s system_id]

			set ccy_res [inf_exec_stmt $stmt $sys_id]

			set n_ccy [db_get_nrows $ccy_res]

			set ccy_info($s,num_ccys)  $n_ccy
			set ccy_info($s,xsys_name) [db_get_col $xsyshost_res $s name]
			set ccy_info($s,system_id)   $sys_id

			for {set c 0} {$c < $n_ccy} {incr c} {
				set ccy_info($s,$c,ccy_code)  [db_get_col $ccy_res $c ccy_code]
				set ccy_info($s,$c,ccy_name)  [db_get_col $ccy_res $c ccy_name]
				set ccy_info($s,$c,exch_rate) [db_get_col $ccy_res $c exch_rate]
				set ccy_info($s,$c,status)    [db_get_col $ccy_res $c status]
			}

			db_close $ccy_res
		}

		inf_close_stmt $stmt

		db_close $xsyshost_res

		tpBindVar XSYS_ccyCode  ccy_info ccy_code  sys_idx ccy_idx
		tpBindVar XSYS_ccyName  ccy_info ccy_name  sys_idx ccy_idx
		tpBindVar XSYS_exchRate ccy_info exch_rate sys_idx ccy_idx
		tpBindVar XSYS_status   ccy_info status    sys_idx ccy_idx

		tpBindVar XSYS_numCurrencies ccy_info num_ccys  sys_idx
		tpBindVar XSYS_system_id     ccy_info system_id sys_idx
		tpBindVar XSYS_xsys_name     ccy_info xsys_name sys_idx
	}

	asPlayFile -nocache ccy_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to single currency add/update
# ----------------------------------------------------------------------------
#
proc go_ccy args {

	global DB ENVO_ALLOWED

	GC::mark ENVO_ALLOWED

	set ccy_code [reqGetArg CCYCode]
	set view_all [reqGetArg ViewAll]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString CCYCode $ccy_code

	if {$ccy_code == ""} {

		tpBindString CCYCVV2CheckValue 0

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get ccy information
		#
		set sql [subst {
			select
				ccy_code,
				ccy_name,
				exch_rate,
				exch_rate_b,
				exch_rate_s,
				min_deposit,
				max_deposit,
				min_withdrawal,
				max_withdrawal,
				status,
				disporder,
				ext_multiplier,
				ext_ccy_code,
				cvv2_check_value,
				num_iso_code,
				default_bank_route
			from
				tCCY
			where
				ccy_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ccy_code]

		inf_close_stmt $stmt

		tpBindString CCYCode      [db_get_col $res 0 ccy_code]
		tpBindString CCYName      [db_get_col $res 0 ccy_name]
		tpBindString CCYExchRate  [db_get_col $res 0 exch_rate]
		tpBindString CCYExchRateB [db_get_col $res 0 exch_rate_b]
		tpBindString CCYExchRateS [db_get_col $res 0 exch_rate_s]
		tpBindString CCYMinDep    [db_get_col $res 0 min_deposit]
		tpBindString CCYMaxDep    [db_get_col $res 0 max_deposit]
		tpBindString CCYMinWtd    [db_get_col $res 0 min_withdrawal]
		tpBindString CCYMaxWtd    [db_get_col $res 0 max_withdrawal]
		tpBindString CCYStatus    [db_get_col $res 0 status]
		tpBindString CCYDisporder [db_get_col $res 0 disporder]
		tpBindString CCYMultiplier [db_get_col $res 0 ext_multiplier]
		tpBindString CCYExtCCYCode [db_get_col $res 0 ext_ccy_code]
		tpBindString CCYCVV2CheckValue [db_get_col $res 0 cvv2_check_value]
		tpBindString CCYNumIsoCode [db_get_col $res 0 num_iso_code]
		tpBindString CCYDefBankRoute   [db_get_col $res 0 default_bank_route]

		db_close $res

		#
		# Default is to only select dates from previous year so set that up
		#
		set today [clock format [expr {[clock seconds]}] -format {%Y-%m-%d}]
		set lastyear  [clock format [clock scan "$today - 1 year"] -format {%Y-%m-%d}]
		
		#
		# But if the button is pressed then get dates from all years
		#
		if {$view_all == 1} {
			set datefilter ""
		} else {
			set datefilter "and extend(date_from, year to day) >= '$lastyear'"
		}
		
		#
		# Get ccy history information
		#
		set sql [subst {
			select
				ccy_hist_id,
				ccy_code,
				date_from,
				exch_rate,
				exch_rate_b,
				exch_rate_s
			from
				tCCYHist
			where
				ccy_code = ?
			$datefilter
			order by
				date_from desc
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ccy_code]

		inf_close_stmt $stmt

		tpSetVar NumCCYHist [db_get_nrows $res]
		tpSetVar ViewAll    $view_all

		tpBindTcl CCYHistId    sb_res_data $res ccy_hist_idx ccy_hist_id
		tpBindTcl CCYHistDate  sb_res_data $res ccy_hist_idx date_from
		tpBindTcl CCYHistRate  sb_res_data $res ccy_hist_idx exch_rate
		tpBindTcl CCYHistRateB sb_res_data $res ccy_hist_idx exch_rate_b
		tpBindTcl CCYHistRateS sb_res_data $res ccy_hist_idx exch_rate_s
	}


	# Get the Envoy country / tExtSubPayMthd mappings
	if {[OT_CfgGet FUNC_ENVOY 0]} {

		set sql [subst {
		select
			s.sub_type_code,
			s.desc,
			NVL(c.ccy_code,0)   as selected
		from
			tExtPayMthd       p,
			tExtSubPayMthd    s,
		outer
			tExtSubPayCCY     c
		where
			p.pay_mthd         = 'ENVO'             and
			s.ext_pay_mthd_id  = p.ext_pay_mthd_id  and
			c.sub_type_code    = s.sub_type_code    and
			c.ccy_code         = ?
		}]

		set stmt  [inf_prep_sql $DB $sql]
		set res   [inf_exec_stmt $stmt $ccy_code]

		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set ENVO_ALLOWED($i,type)  [db_get_col $res $i sub_type_code]
			set ENVO_ALLOWED($i,desc)  [db_get_col $res $i desc]

			if {[db_get_col $res $i selected] != 0} {
				set ENVO_ALLOWED($i,checked) "checked"
			}
		}
		inf_close_stmt $stmt
		db_close $res

		tpSetVar  num_envo_types $nrows
		tpBindVar envo_type    ENVO_ALLOWED type    envo_all_idx
		tpBindVar envo_desc    ENVO_ALLOWED desc    envo_all_idx
		tpBindVar envo_checked ENVO_ALLOWED checked envo_all_idx

	}

	asPlayFile -nocache ccy.html
}


#
# ----------------------------------------------------------------------------
# Logic to insert the CCY to Sub Pay Type
#
# Expects the argument ext_ccys_checked
#
# ----------------------------------------------------------------------------
#
proc do_ccy_ext_map args {
	global DB

	OT_LogWrite 5 "==> do_ccy_ext_map"

	set ext_ccys_checked [reqGetArgs ext_ccys_checked]

	# Get the desired CCY code
	set ccy_code [reqGetArg CCYCode]

	# get existing settings
	set sql {
		select
			sub_type_code
		from
			tExtSubPayCCY
		where
			ccy_code = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set res  [inf_exec_stmt $stmt $ccy_code]
	inf_close_stmt $stmt

	set existing_list [list]

	set nrows [db_get_nrows $res]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend existing_list [db_get_col $res $i sub_type_code]
	}

	set STMT(insert_list) [list]
	set STMT(delete_list) [list]

	# which ones need inserting?
	foreach type $ext_ccys_checked {
		if {[lsearch $existing_list $type] == -1} {
			lappend STMT(insert_list) $type
		}
	}

	# which ones need deleting?
	foreach type2 $existing_list {
		if {[lsearch $ext_ccys_checked $type2] == -1} {
			lappend STMT(delete_list) $type2
		}
	}

	set sql_i [subst {
		insert into tExtSubPayCCY (
			sub_type_code,
			ccy_code
		) values (
			?,
			?
		)
	}]

	set sql_d [subst {
		delete from
			tExtSubPayCCY
		where
			sub_type_code = ? and
			ccy_code      = ?
	}]

	if [llength $STMT(insert_list)] { set stmt_i [inf_prep_sql $DB $sql_i] }
	if [llength $STMT(delete_list)] { set stmt_d [inf_prep_sql $DB $sql_d] }

	if {[catch {
		foreach ty $STMT(insert_list) {
			inf_exec_stmt $stmt_i $ty $ccy_code
		}
		foreach ty $STMT(delete_list) {
			inf_exec_stmt $stmt_d $ty $ccy_code
		}
	} msg]} {
		OT_LogWrite 1 "Couldn't update ccy permissions for External Sub Type '$type' : $msg"
		err_bind      "Couldn't update ccy permissions for External Sub Type '$type' : $msg"
	}

	if {[info exists stmt_i]} { inf_close_stmt $stmt_i }
	if {[info exists stmt_d]} { inf_close_stmt $stmt_d }

	# Excellent, now replay the page
	go_ccy
}



#
# ----------------------------------------------------------------------------
# Go to single xsyshost currency add/update
# ----------------------------------------------------------------------------
#
proc go_xsys_ccy args {

	global DB
	global undef_ccy
	global XSYS_HIST

	set ccy_code [reqGetArg CCYCode]
	set xsys     [reqGetArg XSYS]

	foreach {n v} $args {
		set $n $v
	}

	GC::mark undef_ccy

	tpBindString CCYCode $ccy_code
	tpBindString XSYS $xsys

	#
	# If adding a new currency, need to retrieve list of as-yet-undefined ccys
	#
	if {$ccy_code == ""} {

		tpSetVar opAdd 1

		set sql [subst {
			select
				ccy_code
			from
				tccy
			where
				ccy_code not in (
					select ccy_code from txsysccy where system_id = ?
				)
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $xsys]

		inf_close_stmt $stmt

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			set undef_ccy($i,ccy_code) [db_get_col $res $i ccy_code]
		}

		tpSetVar  XSYS_num_ccy    [db_get_nrows $res]
		tpBindVar XSYS_undef_ccy  undef_ccy ccy_code ccy_idx

		db_close $res

	} else {

		tpSetVar opAdd 0

		#
		# Get ccy information
		#
		set sql [subst {
			select
				t1.ccy_code,
				t2.ccy_name,
				t1.exch_rate,
				t1.status
			from
				txsysccy t1,
				tCCY t2
			where
				t1.ccy_code = ? and
				t1.ccy_code = t2.ccy_code and
				t1.system_id = ?

		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ccy_code $xsys]

		inf_close_stmt $stmt

		tpBindString CCYCode      [db_get_col $res 0 ccy_code]
		tpBindString CCYName      [db_get_col $res 0 ccy_name]
		tpBindString CCYExchRate  [db_get_col $res 0 exch_rate]
		tpBindString CCYStatus    [db_get_col $res 0 status]

		db_close $res


		set sql [subst {
			select
				date_from,
				date_to,
				exch_rate
			from
				tXSysCCYHist
			where
				ccy_code = ?
			and     system_id = ?
			order by
				1,2
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ccy_code $xsys]

		inf_close_stmt $stmt

		tpSetVar xsys_hist_nrows [db_get_nrows $res]

		for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
			set XSYS_HIST($r,date_from)   [db_get_col $res $r date_from]
			set XSYS_HIST($r,date_to)     [db_get_col $res $r date_to]
			set XSYS_HIST($r,exch_rate)   [db_get_col $res $r exch_rate]
		}
		
		tpBindVar XSYS_HIST_date_from    XSYS_HIST   date_from   xsys_hist_idx
		tpBindVar XSYS_HIST_date_to      XSYS_HIST   date_to     xsys_hist_idx
		tpBindVar XSYS_HIST_exch_rate    XSYS_HIST   exch_rate   xsys_hist_idx

	}

	tpSetVar mode xsyshost

	asPlayFile -nocache ccy.html
}


#
# ----------------------------------------------------------------------------
# Do currency insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_ccy args {

	set act [reqGetArg SubmitName]


	if {$act == "CCYAdd"} {
		do_ccy_add
	} elseif {$act == "CCYMod"} {
		do_ccy_upd
	} elseif {$act == "CCYDel"} {
		do_ccy_del
	} elseif {$act == "Back"} {
		go_ccy_list
		return
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_xsys_ccy args {

	set act [reqGetArg SubmitName]

	if {$act == "CCYAdd"} {
		do_xsys_ccy_add
	} elseif {$act == "CCYMod"} {
		do_xsys_ccy_upd
	} elseif {$act == "CCYDel"} {
		do_xsys_ccy_del
	} elseif {$act == "Back"} {
		go_ccy_list
		return
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_ccy_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsCCY(
			p_adminuser = ?,
			p_ccy_code = ?,
			p_ccy_name = ?,
			p_exch_rate = ?,
			p_exch_rate_b = ?,
			p_exch_rate_s = ?,
			p_min_deposit = ?,
			p_max_deposit = ?,
			p_min_withdrawal = ?,
			p_max_withdrawal = ?,
			p_status = ?,
			p_disporder = ?,
			p_ext_multiplier = ?,
			p_ext_ccy_code = ?,
			p_cvv2_check_value = ?,
			p_num_iso_code = ?,
			p_def_bank_route = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CCYCode]\
			[reqGetArg CCYName]\
			[reqGetArg CCYExchRate]\
			[reqGetArg CCYExchRateB]\
			[reqGetArg CCYExchRateS]\
			[reqGetArg CCYMinDep]\
			[reqGetArg CCYMaxDep]\
			[reqGetArg CCYMinWtd]\
			[reqGetArg CCYMaxWtd]\
			[reqGetArg CCYStatus]\
			[reqGetArg CCYDisporder]\
			[reqGetArg CCYMultiplier]\
			[reqGetArg CCYExtCCYCode]\
			[reqGetArg CCYCVV2CheckValue]\
			[reqGetArg CCYNumIsoCode]\
			[reqGetArg DefBankRoute]]} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	catch {db_close $res}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ccy
		return
	}

	go_ccy
}


proc do_xsys_ccy_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsXSysCCY(
			p_adminuser = ?,
			p_ccy_code = ?,
			p_exch_rate = ?,
			p_status = ?,
			p_system_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME \
			[reqGetArg CCYCode]\
			[reqGetArg CCYExchRate]\
			[reqGetArg CCYStatus]\
			[reqGetArg XSYS]]} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	catch {db_close $res}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_xsys_ccy
		return
	}

	go_xsys_ccy
}

proc do_ccy_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdCCY(
			p_adminuser = ?,
			p_ccy_code = ?,
			p_ccy_name = ?,
			p_exch_rate = ?,
			p_exch_rate_b = ?,
			p_exch_rate_s = ?,
			p_min_deposit = ?,
			p_max_deposit = ?,
			p_min_withdrawal = ?,
			p_max_withdrawal = ?,
			p_status = ?,
			p_disporder = ?,
			p_ext_multiplier = ?,
			p_ext_ccy_code = ?,
			p_cvv2_check_value = ?,
			p_num_iso_code = ?,
			p_def_bank_route = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CCYCode]\
			[reqGetArg CCYName]\
			[reqGetArg CCYExchRate]\
			[reqGetArg CCYExchRateB]\
			[reqGetArg CCYExchRateS]\
			[reqGetArg CCYMinDep]\
			[reqGetArg CCYMaxDep]\
			[reqGetArg CCYMinWtd]\
			[reqGetArg CCYMaxWtd]\
			[reqGetArg CCYStatus]\
			[reqGetArg CCYDisporder]\
			[reqGetArg CCYMultiplier]\
			[reqGetArg CCYExtCCYCode]\
			[reqGetArg CCYCVV2CheckValue]\
			[reqGetArg CCYNumIsoCode]\
			[reqGetArg DefBankRoute]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ccy
		return
	}

	go_ccy_list
}

proc do_xsys_ccy_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdXSysCCY(
			p_adminuser = ?,
			p_exch_rate = ?,
			p_status    = ?,
			p_ccy_code  = ?,
			p_system_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME \
			[reqGetArg CCYExchRate]\
			[reqGetArg CCYStatus]\
			[reqGetArg CCYCode]\
			[reqGetArg XSYS]\
			]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_xsys_ccy
		return
	}

	go_ccy_list
}

proc do_ccy_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelCCY(
			p_adminuser = ?,
			p_ccy_code = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CCYCode]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ccy
		return
	}

	go_ccy_list
}

proc do_xsys_ccy_del args {

	global DB USERNAME

	set sql [subst {
		delete from
			txsysccy
		where
			ccy_code =? and
			system_id =?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg CCYCode]\
			[reqGetArg XSYS]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch { db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_xsys_ccy
		return
	}

	go_ccy_list
}

#
# ----------------------------------------------------------------------------
# Go to historic exchange rate entry
# ----------------------------------------------------------------------------
#
proc go_ccy_hist args {

	global DB

	set ccy_hist_id [reqGetArg CCYHistId]

	foreach {n v} $args {
		set $n $v
	}

	set sql [subst {
		select
			ccy_hist_id,
			ccy_code,
			date_from,
			exch_rate,
			exch_rate_b,
			exch_rate_s
		from
			tCCYHist
		where
			ccy_hist_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ccy_hist_id]

	inf_close_stmt $stmt

	tpBindString CCYHistId    [db_get_col $res 0 ccy_hist_id]
	tpBindString CCYCode      [db_get_col $res 0 ccy_code]
	tpBindString CCYHistDate  [db_get_col $res 0 date_from]
	tpBindString CCYExchRate  [db_get_col $res 0 exch_rate]
	tpBindString CCYExchRateB [db_get_col $res 0 exch_rate_b]
	tpBindString CCYExchRateS [db_get_col $res 0 exch_rate_s]

	db_close $res

	asPlayFile -nocache ccy_hist.html

}


#
# ----------------------------------------------------------------------------
# Update historic exchange rate entry
# ----------------------------------------------------------------------------
#
proc do_ccy_hist args {

	global DB USERNAME

	set op_name [reqGetArg SubmitName]

	if {$op_name == "CCYHistMod"} {
		set hist_upd_op U
	} elseif {$op_name == "CCYHistDel"} {
		set hist_upd_op D
	} elseif {$op_name == "CCYHistAdd"} {
		set hist_upd_op I
	} elseif {$op_name == "CCYHistBack"} {
		go_ccy
		return
	} else {
		error "unexpected SubmitName : $op_name"
	}

	set sql [subst {
		execute procedure pUpdCCYHist(
			p_adminuser = ?,
			p_ccy_hist_id = ?,
			p_op = ?,
			p_ccy_code = ?,
			p_exch_rate = ?,
			p_exch_rate_b = ?,
			p_exch_rate_s = ?,
			p_date_from = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CCYHistId]\
			$hist_upd_op\
			[reqGetArg CCYCode]\
			[reqGetArg CCYExchRate]\
			[reqGetArg CCYExchRateB]\
			[reqGetArg CCYExchRateS]\
			[reqGetArg CCYHistDate]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ccy_hist
		return
	}

	go_ccy
}

}
