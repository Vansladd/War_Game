# ==============================================================
# $Id: pmt_control.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT_CONTROL {

asSetAct ADMIN::PMT_CONTROL::GoControl  [namespace code go_control]
asSetAct ADMIN::PMT_CONTROL::DoControl  [namespace code do_control]

variable PS_RE {^[A-Z0-9-]{2,4},[A-Z0-9-]{2,4}$}

variable VIEW_ADMIN_OP   "ViewPmtControl"
variable GLOBAL_ADMIN_OP "DoPmtControl"
variable CCY_ADMIN_OP    "DoPmtControlCcy"
variable MTHD_ADMIN_OP   "DoPmtControlMthd"
variable ACCT_ADMIN_OP   "DoPmtControlAcct"
variable EARLY_ADMIN_OP  "DoPmtControlEarly"


proc go_control {} {

	set submit_name [ob_chk::get_arg SubmitName NULL Az]

	switch -- $submit_name {
		"InsCcy"   {go_ins_control "InsCcy"}
		"InsMthd"  {go_ins_control "InsMthd"}
		"InsAcct"  {go_ins_acct_control}
		"UpdCcy"   {go_upd_control "UpdCcy"}
		"UpdMthd"  {go_upd_control "UpdMthd"}
		"UpdAcct"  {go_upd_acct_control}
		"UpdEarly" {go_upd_early_control}
		"Back"     {go_control_main}
		"BackAcct" {ADMIN::CUST::go_cust}
		""         {go_control_main}
		default  {
			tpBindString ErrMsg "Unknown action"
			go_control_main
		}
	}
}

proc do_control {} {

	set submit_name [ob_chk::get_arg SubmitName Az]

	switch -- $submit_name {
		"InsCcy"    {do_ins_control "InsCcy"}
		"InsMthd"   {do_ins_control "InsMthd"}
		"InsAcct"   {do_ins_acct_control}
		"InsEarly"  {do_ins_early_control}
		"UpdGlobal" {do_upd_control "UpdGlobal"}
		"UpdCcy"    {do_upd_control "UpdCcy"}
		"UpdMthd"   {do_upd_control "UpdMthd"}
		"UpdAcct"   {do_upd_acct_control}
		"UpdEarly"  {do_upd_early_control}
		"DelCcy"    {do_del_control "DelCcy"}
		"DelMthd"   {do_del_control "DelMthd"}
		"DelAcct"   {do_del_acct_control}
		"DelEarly"  {do_del_early_control}
		"UpdPmtChk" {do_upd_pmt_change_chks}
		default  {
			tpBindString ErrMsg "Unknown action"
			go_control_main
		}
	}
}

proc get_limits_bind_columns {{include_ccy 0}} {

	set ret [list]

	if {$include_ccy} {
		set ret [concat $ret [list Ccy ccy_code]]
	}

	set ret [concat $ret [list \
		AllowDep       allow_funds_dep\
		MaxDepH        max_dep_h\
		MaxDepS        max_dep_s\
		MaxDayDepH     max_day_dep_h\
		MaxDayDepS     max_day_dep_s\
		MaxNumDayDep   max_num_day_dep\
		MinDep         min_dep\
		AllowWtd       allow_funds_wtd\
		MaxWtdH        max_wtd_h\
		MaxWtdS        max_wtd_s\
		MaxDayWtdH     max_day_wtd_h\
		MaxDayWtdS     max_day_wtd_s\
		MaxNumDayWtd   max_num_day_wtd\
		MinWtd         min_wtd]]

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		set ret [concat $ret [list \
			MaxWeekWtdH     max_week_wtd_h\
			MaxWeekDepH     max_week_dep_h\
			MaxWeekDepS     max_week_dep_s\
			MaxWeekWtdS     max_week_wtd_s\
			MaxNumWeekDep   max_num_week_dep\
			MaxNumWeekWtd   max_num_week_wtd]]
	}
	return $ret
}



proc go_control_main {} {

	global DB

	global CCY_DATA
	global MTHD_DATA
	global EARLY_DATA

	global EXT_SUBS

	variable VIEW_ADMIN_OP
	variable GLOBAL_ADMIN_OP
	variable CCY_ADMIN_OP
	variable MTHD_ADMIN_OP
	variable EARLY_ADMIN_OP

	# Unset just incase anything went wrong unsetting them at the end of a request
	array unset CCY_DATA
	array unset MTHD_DATA
	array unset EARLY_DATA
	array unset EXT_SUBS

	if {![op_allowed $VIEW_ADMIN_OP]} {
		error "You do not have permission to view this data"
	}

	tpSetVar GlobalAdminOp $GLOBAL_ADMIN_OP
	tpSetVar CcyAdminOp    $CCY_ADMIN_OP
	tpSetVar MthdAdminOp   $MTHD_ADMIN_OP
	tpSetVar EarlyAdminOp  $EARLY_ADMIN_OP

	# Get the list of active currencies
	set stmt [inf_prep_sql $DB {
		select
			ccy_code,
			ccy_name,
			disporder
		from
			tCcy
		where status = 'A'
		order by 3
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	array set CCY_DATA [list]
	set CCY_DATA(ccys) [list]

	# Defaults
	set CCY_DATA(---,ccy_code) "---"
	set CCY_DATA(---,ccy_name) "--DEFAULT--"

	for {set i 0} {$i < $nrows} {incr i} {
		set ccy_code [db_get_col $rs $i ccy_code]
		lappend CCY_DATA(ccys) $ccy_code

		set CCY_DATA($ccy_code,ccy_code) $ccy_code
		set CCY_DATA($ccy_code,ccy_name) [db_get_col $rs $i ccy_name]

	}
	db_close $rs

	tpBindVar CcyCode CCY_DATA ccy_code ccy_code
	tpBindVar CcyName CCY_DATA ccy_name ccy_code

	# Schemes
	set schemes [list]
	set stmt [inf_prep_sql $DB {
		select
			scheme,
			scheme_name
		from
			tCardSchemeInfo
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend schemes [list\
			[db_get_col $rs $i scheme]\
			[db_get_col $rs $i scheme_name]]
	}
	db_close $rs


	# List of Payment Methods
	set stmt [inf_prep_sql $DB {
		select
			pay_mthd,
			desc
		from
			tPayMthd
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	array set MTHD [list]
	set pay_mthds [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set pay_mthd [db_get_col $rs $i pay_mthd]

		if {$pay_mthd == "CC"} {
			set pay_schemes $schemes
		} else {
			set pay_schemes [list [list "----" ""]]
		}

		foreach s $pay_schemes {

			set scheme      [lindex $s 0]
			set scheme_desc [lindex $s 1]

			set ps "$pay_mthd,$scheme"

			lappend pay_mthds $ps

			set MTHD_DATA($ps,existing_ccys) [list]
			set MTHD_DATA($ps,remaining_ccys) [list]
			set MTHD_DATA($ps,pay_mthd) $pay_mthd
			set MTHD_DATA($ps,scheme) $scheme
			set MTHD_DATA($ps,scheme_desc) $scheme_desc
			set MTHD_DATA($ps,desc) [db_get_col $rs $i desc]
		}
	}
	db_close $rs

	tpBindVar MthdPayMthd    MTHD_DATA pay_mthd    pay_mthd
	tpBindVar MthdScheme     MTHD_DATA scheme      pay_mthd
	tpBindVar MthdSchemeDesc MTHD_DATA scheme_desc pay_mthd
	tpBindVar MthdDesc       MTHD_DATA desc        pay_mthd

	# Payment Method Weekly Limits
	set week_limits ""
	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		foreach a {,max_week_wtd_h
					,max_week_dep_h \
					,max_num_week_dep \
					,max_num_week_wtd \
					,max_week_wtd_s \
					,max_week_dep_s} {
			set week_limits "$week_limits $a"
		}
	}

	# Get the global settings
	set stmt [inf_prep_sql $DB  [subst {
		select
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep_h,
			max_day_dep_s,
			max_day_wtd_h,
			max_day_wtd_s,
			max_dep_h,
			max_dep_s,
			max_wtd_h,
			max_wtd_s,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from
			tPmtControl
	}]]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		tpBindString ErrMsg "Global settings not set.  Please insert a row into tPmtControl before continuing"
	}

	set bind_columns [get_limits_bind_columns]

	foreach {a b} $bind_columns {
		tpBindString $a   [db_get_col $rs 0 $b]
	}

	db_close $rs

	# Get the Currency settings

	set CCY_DATA(existing_ccys) [list]

	set stmt [inf_prep_sql $DB [subst {
		select
			ccy_code,
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep_h,
			max_day_dep_s,
			max_day_wtd_h,
			max_day_wtd_s,
			max_dep_h,
			max_dep_s,
			max_wtd_h,
			max_wtd_s,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from
			tPmtControlCcy
	}]]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set ccy_code [db_get_col $rs $i ccy_code]
		lappend CCY_DATA(existing_ccys) $ccy_code

		set CCY_DATA($ccy_code,allow_funds_dep) [db_get_col $rs $i allow_funds_dep]
		set CCY_DATA($ccy_code,allow_funds_wtd) [db_get_col $rs $i allow_funds_wtd]

		foreach {a b} $bind_columns {
			set val [db_get_col $rs $i $b]
			if {$val == ""} {
				set CCY_DATA($ccy_code,$b) -
			} elseif {$val == "-1"} {
				set CCY_DATA($ccy_code,$b) "unlimited"
			} else {
				set CCY_DATA($ccy_code,$b) $val
			}
		}
	}
	db_close $rs

	foreach {a b} $bind_columns {
		tpBindVar Ccy$a         CCY_DATA  $b             ccy_code
	}

	# Populate the remaining currencies
	foreach ccy $CCY_DATA(ccys) {
		if {![info exists CCY_DATA($ccy,allow_funds_dep)]} {
			lappend CCY_DATA(remaining_ccys) $ccy
		}
	}

	set stmt [inf_prep_sql $DB [subst {
		select
			pay_mthd,
			scheme,
			ccy_code,
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep_h,
			max_day_dep_s,
			max_day_wtd_h,
			max_day_wtd_s,
			max_dep_h,
			max_dep_s,
			max_wtd_h,
			max_wtd_s,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from
			tPmtControlMthd
		order by 1,2,3
	}]]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	array set MTHD_DATA [list]
	set MTHD_DATA(existing_mthds) [list]

	set prev_ps ""
	for {set i 0} {$i < $nrows} {incr i} {
		set pay_mthd [db_get_col $rs $i pay_mthd]
		set scheme   [db_get_col $rs $i scheme]

		set ps "$pay_mthd,$scheme"

		if {$ps != $prev_ps} {
			lappend MTHD_DATA(existing_mthds) $ps
			set prev_ps $ps
		}

		set ccy_code [db_get_col $rs $i ccy_code]
		lappend MTHD_DATA($ps,existing_ccys) $ccy_code

		set MTHD_DATA($ps,$ccy_code,allow_funds_dep) [db_get_col $rs $i allow_funds_dep]
		set MTHD_DATA($ps,$ccy_code,allow_funds_wtd) [db_get_col $rs $i allow_funds_wtd]

		foreach {a b} $bind_columns {
			set val [db_get_col $rs $i $b]
			if {$val == ""} {
				set MTHD_DATA($ps,$ccy_code,$b) -
			} elseif {$val == "-1"} {
				set MTHD_DATA($ps,$ccy_code,$b) "unlimited"
			} else {
				set MTHD_DATA($ps,$ccy_code,$b) $val
			}
		}

	}

	set MTHD_DATA(remaining_mthds) [list]
	foreach ps $pay_mthds {
		set found 0
		foreach ccy [concat "---" $CCY_DATA(ccys)] {
			if {![info exists MTHD_DATA($ps,$ccy,allow_funds_dep)]} {
				lappend MTHD_DATA($ps,remaining_ccys) $ccy
			} else {
				set found 1
			}
		}
		if {!$found} {
			lappend MTHD_DATA(remaining_mthds) $ps
		}
	}

	db_close $rs

	foreach {a b} $bind_columns {
		tpBindVar Mthd$a         MTHD_DATA  $b     pay_mthd   ccy_code
	}

	OT_LogWrite 1 "Pay Mthds $pay_mthds"

	# Early Withdraw restrictions
	set stmt [inf_prep_sql $DB {
		select
			pay_mthd,
			scheme,
			period,
			max_amount,
			time_between_wtds
		from
			tPmtControlEarly
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	array set EARLY_DATA [list]
	set EARLY_DATA(existing_mthds) [list]
	set EARLY_DATA(remaining_mthds) [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set pay_mthd [db_get_col $rs $i pay_mthd]
		set scheme   [db_get_col $rs $i scheme]

		set ps "$pay_mthd,$scheme"
		lappend EARLY_DATA(existing_mthds) $ps

		set EARLY_DATA($ps,period)            [db_get_col $rs $i period]
		set EARLY_DATA($ps,max_amount)        [db_get_col $rs $i max_amount]
		set EARLY_DATA($ps,time_between_wtds) [db_get_col $rs $i time_between_wtds]
	}

	foreach ps $pay_mthds {
		if {![info exists EARLY_DATA($ps,period)]} {
			lappend EARLY_DATA(remaining_mthds) $ps
		}
	}

	db_close $rs

	tpBindVar EarlyPeriod          EARLY_DATA period            pay_mthd
	tpBindVar EarlyMaxAmount       EARLY_DATA max_amount        pay_mthd
	tpBindVar EarlyTimeBetweenWtds EARLY_DATA time_between_wtds pay_mthd

	# Get the payment method change check settings
	set stmt [inf_prep_sql $DB [subst {
		select
			max_sb_balance,
			max_ext_balance,
			max_total_balance,
			max_card_changes,
			card_change_period,
			max_pmb_remove,
			max_poker_in_play,
			max_casino_wallet,
			max_poker_wallet,
			max_poker_bonus,
			max_casino_bonus
		from
			tPmtChangeChk
	}]]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	tpBindString MaxSBBalance      [db_get_col $rs 0 max_sb_balance]
	tpBindString MaxExtBalance     [db_get_col $rs 0 max_ext_balance]
	tpBindString MaxTotalBalance   [db_get_col $rs 0 max_total_balance]

	tpBindString MaxCardChanges    [db_get_col $rs 0 max_card_changes]
	tpBindString CardChangePeriod  [db_get_col $rs 0 card_change_period]
	tpBindString MaxPMBRemove      [db_get_col $rs 0 max_pmb_remove]

	tpBindString MaxPokerInPlay    [db_get_col $rs 0 max_poker_in_play]
	tpBindString MaxCasinoWallet   [db_get_col $rs 0 max_casino_wallet]
	tpBindString MaxPokerWallet    [db_get_col $rs 0 max_poker_wallet]

	tpBindString MaxPokerBonus     [db_get_col $rs 0 max_poker_bonus]
	tpBindString MaxCasinoBonus    [db_get_col $rs 0 max_casino_bonus]


	db_close $rs

	asPlayFile -nocache pmt_control.html

	array unset CCY_DATA
	array unset MTHD_DATA
	array unset EARLY_DATA
}

proc go_ins_control {type} {

	global DB

	variable PS_RE

	set ccy_code [ob_chk::get_arg CcyCode {AZ -min_str 3 -max_str 3} {EXACT -args "---"}]

	switch -- $type {
		"InsCcy" {
			tpBindString UpdDesc "Currency $ccy_code"
		}
		"InsMthd" {
			set pay_mthd [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]
			set mthd_desc [get_mthd_desc $pay_mthd]
			tpBindString UpdDesc "Method $mthd_desc Currency $ccy_code"
			tpBindString PayMthd $pay_mthd
			tpSetVar isMthd 1
		}
		default {
			error "Unknown submit name $type"
		}
	}

	tpBindString ButtonName   "Add"
	tpBindString SubmitName   $type
	tpBindString CcyCode      $ccy_code

	asPlayFile -nocache pmt_control_upd.html
}

proc go_ins_acct_control {} {

	global   SYS_LIMIT_DATA
	global   SYS_LIMIT_MTHD
	variable PS_RE

	set acct_id [ob_chk::get_arg AcctId UINT]

	bind_cust_limits $acct_id

	set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]

	tpBindString SubmitName        "InsAcct"
	tpBindString AcctId            $acct_id
	tpBindString CustId            [ob_chk::get_arg CustId UINT]
	tpBindString PayMthd           $ps
	tpBindString PayMthdDesc       $SYS_LIMIT_MTHD($ps,desc)
	tpBindString PayMthdSchemeDesc $SYS_LIMIT_MTHD($ps,scheme_desc)

	asPlayFile -nocache pmt_control_acct_upd.html
}

proc go_upd_control {type} {

	global DB
	variable PS_RE

	set ccy_code [ob_chk::get_arg CcyCode {AZ -min_str 3 -max_str 3} {EXACT -args "---"}]

	set week_limits ""

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		foreach a {,max_week_wtd_h
				,max_week_dep_h \
				,max_num_week_dep \
				,max_num_week_wtd \
				,max_week_wtd_s \
				,max_week_dep_s} {
			set week_limits "$week_limits $a"
		}
	}

	switch -- $type {
		"UpdCcy" {
			set table "tPmtControlCcy"
			set where ""
			tpBindString DelSubmitName   "DelCcy"
			tpBindString UpdDesc "Currency $ccy_code"
			tpSetVar isMthd 0
		}
		"UpdMthd" {
			set table "tPmtControlMthd"
			set where "and pay_mthd = ? and scheme = ?"
			set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]
			tpBindString PayMthd $ps

			foreach {pay_mthd scheme} [split $ps ","] {break}
			set mthd_desc [get_mthd_desc $ps]
			tpBindString DelSubmitName   "DelMthd"
			tpBindString UpdDesc "Method $mthd_desc Currency $ccy_code"
			tpSetVar isMthd 1
		}
		default {
			error "Unknown submit name $type"
		}
	}

	set stmt [inf_prep_sql $DB [subst {
		select
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep_h,
			max_day_dep_s,
			max_day_wtd_h,
			max_day_wtd_s,
			max_dep_h,
			max_dep_s,
			max_wtd_h,
			max_wtd_s,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from
			$table
		where
			ccy_code = ?
		$where
	}]]

	if {$type == "UpdCcy"} {
		set rs [inf_exec_stmt $stmt $ccy_code]
	} else {
		set rs [inf_exec_stmt $stmt $ccy_code $pay_mthd $scheme]
	}
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		tpBindString ErrMsg "Unable to find entry to update"
		go_control_main
		return
	}

	tpSetVar isUpd 1

	tpBindString SubmitName   $type
	tpBindString ButtonName   "Update"

	tpBindString CcyCode      $ccy_code
	set bind_columns [get_limits_bind_columns]

	foreach {a b} $bind_columns {
		tpBindString $a  [db_get_col $rs 0 $b]
	}

	db_close $rs

	asPlayFile -nocache pmt_control_upd.html
}

proc go_upd_acct_control {} {

	global   SYS_LIMIT_DATA
	global   SYS_LIMIT_MTHD
	global DB

	variable PS_RE

	set acct_id [ob_chk::get_arg AcctId UINT]
	set ps      [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]

	bind_cust_limits $acct_id

	foreach {pay_mthd scheme} [split $ps ","] {break}
	#tpSetVar isMthd 1


	set columns [list \
					AllowDep     allow_funds_dep\
					AllowWtd     allow_funds_wtd\
					MaxDep       max_dep\
					MaxWtd       max_wtd\
					MaxDayDep    max_day_dep\
					MaxDayWtd    max_day_wtd\
					MaxNumDayDep max_num_day_dep\
					MaxNumDayWtd max_num_day_wtd\
					MinDep       min_dep\
					MinWtd       min_wtd]

	set week_limits ""

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		set week_limits ",max_week_wtd,max_week_dep,max_num_week_dep,max_num_week_wtd"
		lappend columns \
			MaxWeekWtd    max_week_wtd\
			MaxWeekDep    max_week_dep\
			MaxNumWeekDep max_num_week_dep\
			MaxNumWeekWtd max_num_week_wtd
	}

	set stmt [inf_prep_sql $DB [subst {
		select
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep,
			max_day_wtd,
			max_dep,
			max_wtd,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from
			tPmtControlAcct
		where
			acct_id  = ?
		and pay_mthd = ?
		and scheme   = ?
	}]]

	set rs [inf_exec_stmt $stmt $acct_id $pay_mthd $scheme]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		tpBindString ErrMsg "Unable to find entry to update"
		go_cust
		return
	}

	tpSetVar isUpd 1

	tpBindString SubmitName   "UpdAcct"

	tpBindString AcctId            $acct_id
	tpBindString PayMthd           $ps
	tpBindString CustId            [ob_chk::get_arg CustId UINT]
	tpBindString PayMthdDesc       $SYS_LIMIT_MTHD($ps,desc)
	tpBindString PayMthdSchemeDesc $SYS_LIMIT_MTHD($ps,scheme_desc)



	foreach {a b} $columns {
		tpBindString $a [db_get_col $rs 0 $b]
	}

	db_close $rs

	asPlayFile -nocache pmt_control_acct_upd.html
}

proc go_upd_early_control {} {

	global DB

	variable PS_RE

	# Get and Check input args
	set arg_err_list [list]

	set ps [ob_chk::get_arg PayMthd\
		-err_msg "Invalid payment method"\
		-err_list arg_err_list [list RE -args $PS_RE]]

	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		tpBindString ErrMsg [join $arg_err_list "<br>"]
		go_control_main
		return
	}

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB {
		select
			period,
			max_amount,
			time_between_wtds
		from
			tPmtControlEarly
		where pay_mthd = ?
		and   scheme   = ?
	}]

	set rs [inf_exec_stmt $stmt $pay_mthd $scheme]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		tpBindString ErrMsg "Unable to find entry to update"
		go_control_main
		return
	}

	tpBindString PayMthd         $ps
	tpBindString Period          [db_get_col $rs 0 period]
	tpBindString MaxAmount       [db_get_col $rs 0 max_amount]
	tpBindString TimeBetweenWtds [db_get_col $rs 0 time_between_wtds]

	db_close $rs

	asPlayFile -nocache pmt_control_early_upd.html
}

proc do_ins_control {type} {

	global DB

	variable PS_RE

	set include_ccy 1
	set bindings_columns [get_limits_bind_columns $include_ccy]

	switch -- $type {
		"InsCcy" {
			set table "tPmtControlCcy"
			set fields ""
			set values ""
		}
		"InsMthd" {
			set table "tPmtControlMthd"
			set fields ",pay_mthd,scheme"
			set values ",?,?"

			set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]
			foreach {pay_mthd scheme} [split $ps ","] {break}
		}
		default {
			error "Unknown submit name $type"
		}
	}

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		foreach a {,max_week_wtd_h
			,max_week_dep_h \
			,max_num_week_dep \
			,max_num_week_wtd \
			,max_week_wtd_s \
			,max_week_dep_s} {
			set fields "$fields $a"
			set values "$values ,?"
		}
	}

	foreach {arg var} $bindings_columns {
		# TODO - check args
		set $var [reqGetArg $arg]
	}

	set stmt [inf_prep_sql $DB [subst {
		insert into $table (
			ccy_code,
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep_h,
			max_day_dep_s,
			max_day_wtd_h,
			max_day_wtd_s,
			max_dep_h,
			max_dep_s,
			max_wtd_h,
			max_wtd_s,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$fields
		) values (
			?,?,?,?,?,?,?,?,?,?,?,?,?,?,?$values
		)
	}]]


	switch -- $type {
		"InsCcy" {
			if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
				inf_exec_stmt $stmt\
					$ccy_code\
					$allow_funds_dep\
					$allow_funds_wtd\
					$max_day_dep_h\
					$max_day_dep_s\
					$max_day_wtd_h\
					$max_day_wtd_s\
					$max_dep_h\
					$max_dep_s\
					$max_wtd_h\
					$max_wtd_s\
					$min_dep\
					$min_wtd\
					$max_num_day_dep\
					$max_num_day_wtd\
					$max_week_wtd_h\
					$max_week_dep_h\
					$max_num_week_dep\
					$max_num_week_wtd\
					$max_week_wtd_s\
					$max_week_dep_s
			} else {
				inf_exec_stmt $stmt\
					$ccy_code\
					$allow_funds_dep\
					$allow_funds_wtd\
					$max_day_dep_h\
					$max_day_dep_s\
					$max_day_wtd_h\
					$max_day_wtd_s\
					$max_dep_h\
					$max_dep_s\
					$max_wtd_h\
					$max_wtd_s\
					$min_dep\
					$min_wtd\
					$max_num_day_dep\
					$max_num_day_wtd
			}
		}
		"InsMthd" {
			if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
				inf_exec_stmt $stmt\
					$ccy_code\
					$allow_funds_dep\
					$allow_funds_wtd\
					$max_day_dep_h\
					$max_day_dep_s\
					$max_day_wtd_h\
					$max_day_wtd_s\
					$max_dep_h\
					$max_dep_s\
					$max_wtd_h\
					$max_wtd_s\
					$min_dep\
					$min_wtd\
					$max_num_day_dep\
					$max_num_day_wtd\
					$pay_mthd\
					$scheme\
					$max_week_wtd_h\
					$max_week_dep_h\
					$max_num_week_dep\
					$max_num_week_wtd\
					$max_week_wtd_s\
					$max_week_dep_s
			} else {
				inf_exec_stmt $stmt\
					$ccy_code\
					$allow_funds_dep\
					$allow_funds_wtd\
					$max_day_dep_h\
					$max_day_dep_s\
					$max_day_wtd_h\
					$max_day_wtd_s\
					$max_dep_h\
					$max_dep_s\
					$max_wtd_h\
					$max_wtd_s\
					$min_dep\
					$min_wtd\
					$max_num_day_dep\
					$max_num_day_wtd\
					$pay_mthd\
					$scheme
			}
		}
		default {
			error "Unknown submit name $type"
		}
	}
	inf_close_stmt $stmt

	go_control_main
}

proc do_ins_acct_control {} {

	global DB

	variable PS_RE

	set columns [list \
		AcctId       acct_id\
		AllowDep     allow_funds_dep\
		MaxDep       max_dep\
		MaxDepDay    max_day_dep\
		MaxNumDayDep max_num_day_dep\
		MinDep       min_dep\
		AllowWtd     allow_funds_wtd\
		MaxWtd       max_wtd\
		MaxWtdDay    max_day_wtd\
		MaxNumDayWtd max_num_day_wtd\
		MinWtd       min_wtd]

	set week_limits ""
	set week_values ""

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		lappend columns \
				MaxWeekWtd max_week_wtd \
				MaxWeekDep max_week_dep \
				MaxNumWeekDep max_num_week_dep \
				MaxNumWeekWtd max_num_week_wtd

		set week_limits ",max_week_wtd,max_week_dep,max_num_week_dep,max_num_week_wtd"
		set week_values ",?,?,?,?"
	}

	foreach {arg var} $columns {
		# TODO - check args
		set $var [reqGetArg $arg]
	}
	set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB [subst {
		insert into tPmtControlAcct (
			acct_id,
			pay_mthd,
			scheme,
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep,
			max_day_wtd,
			max_dep,
			max_wtd,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		) values (
			?,?,?,?,?,?,?,?,?,?,?,?,?$week_values
		)
	}]]

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		inf_exec_stmt $stmt\
			$acct_id\
			$pay_mthd\
			$scheme\
			$allow_funds_dep\
			$allow_funds_wtd\
			$max_day_dep\
			$max_day_wtd\
			$max_dep\
			$max_wtd\
			$min_dep\
			$min_wtd\
			$max_num_day_dep\
			$max_num_day_wtd\
			$max_week_wtd\
			$max_week_dep\
			$max_num_week_dep\
			$max_num_week_wtd
	} else {
		inf_exec_stmt $stmt\
			$acct_id\
			$pay_mthd\
			$scheme\
			$allow_funds_dep\
			$allow_funds_wtd\
			$max_day_dep\
			$max_day_wtd\
			$max_dep\
			$max_wtd\
			$min_dep\
			$min_wtd\
			$max_num_day_dep\
			$max_num_day_wtd
	}

	inf_close_stmt $stmt

	ADMIN::CUST::go_cust
}

proc do_upd_acct_control {} {

	global DB

	variable PS_RE

	set columns [list \
		AcctId       acct_id\
		AllowDep     allow_funds_dep\
		MaxDep       max_dep\
		MaxDepDay    max_day_dep\
		MaxNumDayDep max_num_day_dep\
		MinDep       min_dep\
		AllowWtd     allow_funds_wtd\
		MaxWtd       max_wtd\
		MaxWtdDay    max_day_wtd\
		MaxNumDayWtd max_num_day_wtd\
		MinWtd       min_wtd]

	set week_limits ""
	set week_values ""

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		lappend columns \
				MaxWeekWtd max_week_wtd \
				MaxWeekDep max_week_dep \
				MaxNumWeekDep max_num_week_dep \
				MaxNumWeekWtd max_num_week_wtd

		set week_limits ",max_week_wtd=?,max_week_dep=?,max_num_week_dep=?,max_num_week_wtd=?"
	}

	foreach {arg var} $columns {
		# TODO - check args
		set $var [reqGetArg $arg]
	}
	set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB [subst {
		update tPmtControlAcct
		set
			allow_funds_dep  = ?,
			allow_funds_wtd  = ?,
			max_day_dep      = ?,
			max_day_wtd      = ?,
			max_dep          = ?,
			max_wtd          = ?,
			min_dep          = ?,
			min_wtd          = ?,
			max_num_day_dep  = ?,
			max_num_day_wtd  = ?
			$week_limits
		where
			acct_id          = ? and
			pay_mthd         = ? and
			scheme           = ?
	}]]


	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		inf_exec_stmt $stmt\
			$allow_funds_dep\
			$allow_funds_wtd\
			$max_day_dep\
			$max_day_wtd\
			$max_dep\
			$max_wtd\
			$min_dep\
			$min_wtd\
			$max_num_day_dep\
			$max_num_day_wtd\
			$max_week_wtd\
			$max_week_dep\
			$max_num_week_dep\
			$max_num_week_wtd\
			$acct_id\
			$pay_mthd\
			$scheme
	} else {
		inf_exec_stmt $stmt\
			$allow_funds_dep\
			$allow_funds_wtd\
			$max_day_dep\
			$max_day_wtd\
			$max_dep\
			$max_wtd\
			$min_dep\
			$min_wtd\
			$max_num_day_dep\
			$max_num_day_wtd\
			$acct_id\
			$pay_mthd\
			$scheme
	}
	inf_close_stmt $stmt

	ADMIN::CUST::go_cust
}

proc do_ins_early_control {} {

	global DB

	variable PS_RE

	set arg_err_list [list]

	# Get and Check the input arguments
	set period [ob_chk::get_arg Period\
		-err_msg "Period - number of hours since first deposit min: 1"\
		-err_list arg_err_list {UINT -min_num 1}]
	set max_amount [ob_chk::get_arg MaxAmount\
		-err_msg "Max Amount should be a number"\
		-err_list arg_err_list NULL MONEY]
	set time_between_wtds [ob_chk::get_arg TimeBetweenWtds\
		-err_msg "Period - number of hours since previous withdrawal min: 1"\
		-err_list arg_err_list NULL {UINT -min_num 1}]
	set ps [ob_chk::get_arg PayMthd\
		-err_msg "Invalid payment method"\
		-err_list arg_err_list [list RE -args $PS_RE]]

	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		tpBindString ErrMsg [join $arg_err_list "<br>"]
		go_control_main
		return
	}

	if {$max_amount == "" && $time_between_wtds == ""} {
		tpBindString ErrMsg "Please supply either Max Amount or Time Between Withdrawals"
		go_control_main
		return
	}

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB {
		insert into tPmtControlEarly (
			pay_mthd,
			scheme,
			period,
			max_amount,
			time_between_wtds
		) values (
			?,?,?,?,?
		)
	}]

	inf_exec_stmt $stmt\
		$pay_mthd\
		$scheme\
		$period\
		$max_amount\
		$time_between_wtds

	inf_close_stmt $stmt

	go_control_main
}



proc do_upd_control {type} {

	global DB

	variable PS_RE

	set arg_err_list [list]

	set bind_columns [get_limits_bind_columns]

	# Retrieve and check the input arguments
	foreach {arg var} {
		AllowDep     allow_funds_dep
		AllowWtd     allow_funds_wtd
	} {
		set $var [ob_chk::get_arg $arg -err_msg "$var should be Y or N"\
			-err_list arg_err_list {EXACT -args {"Y" "N"}}]
	}

	foreach {arg var} {
		MaxDepH         max_dep_h
		MaxDepS         max_dep_s
		MaxDayDepH      max_day_dep_h
		MaxDayDepS      max_day_dep_s
		MinDep          min_dep
		MaxWtdH         max_wtd_h
		MaxWtdS         max_wtd_s
		MaxDayWtdH      max_day_wtd_h
		MaxDayWtdS      max_day_wtd_s
		MinWtd          min_wtd
		MaxWeekWtdH     max_week_wtd_h
		MaxWeekDepH     max_week_dep_h
		MaxWeekWtdS     max_week_wtd_s
		MaxWeekDepS     max_week_dep_s
	} {
		#puts "$arg $var"
		set $var [ob_chk::get_arg $arg\
			-err_msg "$var should be a positive number. -1 Signifies unlimited"\
			-err_list arg_err_list\
			NULL MONEY {EXACT -args "-1"}]
	}

	foreach {arg var} {
		MaxNumDayDep    max_num_day_dep
		MaxNumDayWtd    max_num_day_wtd
		MaxNumWeekWtd   max_num_week_wtd
		MaxNumWeekDep   max_num_week_dep
	} {
		set $var [ob_chk::get_arg $arg\
			-err_msg "$var should be a number. -1 Signifies unlimited"\
			-err_list arg_err_list\
			NULL UINT {EXACT -args "-1"}]
	}

	if {$type != "UpdGlobal"} {
		set ccy_code [ob_chk::get_arg Ccy -err_msg "Invalid currency"\
			-err_list arg_err_list {AZ -min_str 3 -max_str 3} {EXACT -args "---"}]
	}

	OT_LogWrite 1 "Errors from input args: $arg_err_list"


	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		tpBindString ErrMsg [join $arg_err_list "<br>"]
		go_control_main
		return
	}

	set update_values [list]

	set i 1

	foreach {a b} $bind_columns {
		if {$i} {
			set fields "${b}=?"
			set i 0
		} else {
			set fields "$fields ,${b}=?"
		}
		lappend update_values [set $b]
	}


	switch -- $type {
		"UpdGlobal" {
			set table "tPmtControl"
			set where ""
		}
		"UpdCcy" {
			set table "tPmtControlCcy"
			set where " where ccy_code = ?"
		}
		"UpdMthd" {
			set table "tPmtControlMthd"
			set where " where ccy_code = ? and pay_mthd = ? and scheme = ?"
			set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]
		foreach {pay_mthd scheme} [split $ps ","] {break}
		}
		default {
			error "Unknown submit name $type"
		}
	}

	set stmt [inf_prep_sql $DB [subst {
		update $table set $fields $where
	}]]

	switch -- $type {
		"UpdGlobal" {
			eval inf_exec_stmt $stmt $update_values
		}
		"UpdCcy" {
			eval inf_exec_stmt $stmt $update_values $ccy_code
		}
		"UpdMthd" {
			eval inf_exec_stmt $stmt $update_values $ccy_code $pay_mthd $scheme
		}
		default {
			error "Unknown submit name $type"
		}
	}

	inf_close_stmt $stmt
	go_control_main
}

proc do_upd_early_control {} {

	global DB

	variable PS_RE

	set arg_err_list [list]

	# Get and Check the input arguments
	set period [ob_chk::get_arg Period\
		-err_msg "Period - number of hours since first deposit min: 1"\
		-err_list arg_err_list UINT]
	set max_amount [ob_chk::get_arg MaxAmount\
		-err_msg "Max Amount should be a number"\
		-err_list arg_err_list NULL MONEY]
	set time_between_wtds [ob_chk::get_arg TimeBetweenWtds\
		-err_msg "Period - number of hours since previous withdrawal min: 1"\
		-err_list arg_err_list NULL UINT]
	set ps [ob_chk::get_arg PayMthd\
		-err_msg "Invalid payment method"\
		-err_list arg_err_list [list RE -args $PS_RE]]

	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		tpBindString ErrMsg [join $arg_err_list "<br>"]
		go_control_main
		return
	}

	if {$max_amount == "" && $time_between_wtds == ""} {
		tpBindString ErrMsg "Please supply either Max Amount or Time Between Withdrawals"
		go_control_main
		return
	}

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB {
		update tPmtControlEarly
		set
			period            = ?,
			max_amount        = ?,
			time_between_wtds = ?
		where
			pay_mthd          = ?
		and scheme            = ?
	}]

	inf_exec_stmt $stmt\
		$period\
		$max_amount\
		$time_between_wtds\
		$pay_mthd\
		$scheme

	inf_close_stmt $stmt

	go_control_main
}


proc do_del_control {type} {

	global DB

	variable PS_RE

	set ccy_code [ob_chk::get_arg Ccy {AZ -min_str 3 -max_str 3} {EXACT -args "---"}]

	switch -- $type {
		"DelCcy" {
			set table "tPmtControlCcy"
			set where ""
		}
		"DelMthd" {
			set table "tPmtControlMthd"
			set where "and pay_mthd = ? and scheme = ?"
			set ps [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]
			foreach {pay_mthd scheme} [split $ps ","] {break}
		}
		default {
			error "Unknown submit name $type"
		}
	}

	set stmt [inf_prep_sql $DB [subst {
		delete from $table
		where ccy_code = ? $where
	}]]

	if {$type == "DelCcy"} {
		inf_exec_stmt $stmt $ccy_code
	} elseif {$type == "DelMthd"} {
		inf_exec_stmt $stmt $ccy_code\
			$pay_mthd\
			$scheme
	}

	inf_close_stmt $stmt

	go_control_main
}

proc do_del_acct_control {} {

	global DB

	variable PS_RE

	set acct_id [ob_chk::get_arg AcctId UINT]
	set ps      [ob_chk::get_arg PayMthd [list RE -args $PS_RE]]

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB {
		delete from tPmtControlAcct
		where acct_id  = ?
		and   pay_mthd = ?
		and   scheme   = ?
	}]

	inf_exec_stmt $stmt $acct_id\
		$pay_mthd\
		$scheme

	inf_close_stmt $stmt

	ADMIN::CUST::go_cust
}

proc do_del_early_control {} {

	global DB

	variable PS_RE

	set arg_err_list [list]

	# Get and Check the input arguments
	set ps [ob_chk::get_arg PayMthd\
		-err_msg "Invalid payment method"\
		-err_list arg_err_list [list RE -args $PS_RE]]

	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		tpBindString ErrMsg [join $arg_err_list "<br>"]
		go_control_main
		return
	}

	foreach {pay_mthd scheme} [split $ps ","] {break}

	set stmt [inf_prep_sql $DB {
		delete from tPmtControlEarly
		where pay_mthd = ?
		and   scheme   = ?
	}]

	inf_exec_stmt $stmt\
		$pay_mthd\
		$scheme

	inf_close_stmt $stmt

	go_control_main
}

proc bind_cust_limits {acct_id} {

	global SYS_LIMIT_DATA
	global SYS_LIMIT_MTHD

	global DB

	array unset SYS_LIMIT_DATA
	array unset SYS_LIMIT_MTHD

	set SYS_LIMIT_MTHD(existing_mthds) [list]
	set SYS_LIMIT_MTHD(remaining_mthds) [list]

	set week_limits ""
	set columns [list max_day_dep \
					max_day_wtd \
					max_dep \
					max_wtd \
					min_dep \
					min_wtd \
					max_num_day_dep \
					max_num_day_wtd]


	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		set week_limits ",max_week_wtd,max_week_dep,max_num_week_dep,max_num_week_wtd"
		lappend columns max_week_wtd max_week_dep max_num_week_dep max_num_week_wtd
	}

	# Get the account settings
	set stmt [inf_prep_sql $DB [subst {
		select
			pay_mthd,
			scheme,
			allow_funds_dep,
			allow_funds_wtd,
			max_day_dep,
			max_day_wtd,
			max_dep,
			max_wtd,
			min_dep,
			min_wtd,
			max_num_day_dep,
			max_num_day_wtd
			$week_limits
		from tPmtControlAcct
		where acct_id = ?
		order by 1,2
	}]]

	set rs [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	array set SYS_LIMIT_DATA [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set pay_mthd [db_get_col $rs $i pay_mthd]
		set scheme   [db_get_col $rs $i scheme]
		set ps "$pay_mthd,$scheme"
		lappend SYS_LIMIT_MTHD(existing_mthds) $ps

		set SYS_LIMIT_DATA($ps,allow_funds_dep) [db_get_col $rs $i allow_funds_dep]
		set SYS_LIMIT_DATA($ps,allow_funds_wtd) [db_get_col $rs $i allow_funds_wtd]

		foreach f $columns {
			set val [db_get_col $rs $i $f]
			if {$val == ""} {
				set SYS_LIMIT_DATA($ps,$f) -
			} elseif {$val == "-1"} {
				set SYS_LIMIT_DATA($ps,$f) "unlimited"
			} else {
				set SYS_LIMIT_DATA($ps,$f) $val
			}
		}
	}

	db_close $rs

	tpBindVar MthdAllowDep       SYS_LIMIT_DATA allow_funds_dep pay_mthd
	tpBindVar MthdMaxDep         SYS_LIMIT_DATA max_dep         pay_mthd
	tpBindVar MthdMaxDayDep      SYS_LIMIT_DATA max_day_dep     pay_mthd
	tpBindVar MthdMaxNumDayDep   SYS_LIMIT_DATA max_num_day_dep pay_mthd
	tpBindVar MthdMinDep         SYS_LIMIT_DATA min_dep         pay_mthd
	tpBindVar MthdAllowWtd       SYS_LIMIT_DATA allow_funds_wtd pay_mthd
	tpBindVar MthdMaxWtd         SYS_LIMIT_DATA max_wtd         pay_mthd
	tpBindVar MthdMaxDayWtd      SYS_LIMIT_DATA max_day_wtd     pay_mthd
	tpBindVar MthdMaxNumDayWtd   SYS_LIMIT_DATA max_num_day_wtd pay_mthd
	tpBindVar MthdMinWtd         SYS_LIMIT_DATA min_wtd         pay_mthd

	if {[OT_CfgGet WEEKLY_PMT_LIMITS 0]} {
		tpBindVar MthdMaxWeekDep        SYS_LIMIT_DATA max_week_dep     pay_mthd
		tpBindVar MthdMaxNumWeekDep     SYS_LIMIT_DATA max_num_week_dep pay_mthd
		tpBindVar MthdMaxWeekWtd        SYS_LIMIT_DATA max_week_wtd     pay_mthd
		tpBindVar MthdMaxNumWeekWtd     SYS_LIMIT_DATA max_num_week_wtd pay_mthd
	}

	# Schemes
	set schemes [list]
	set stmt [inf_prep_sql $DB {
		select
			scheme,
			scheme_name
		from
			tCardSchemeInfo
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend schemes [list\
			[db_get_col $rs $i scheme]\
			[db_get_col $rs $i scheme_name]]
	}
	db_close $rs

	# Payment Methods
	set stmt [inf_prep_sql $DB {
		select
			pay_mthd,
			desc
		from
			tPayMthd
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	set SYS_LIMIT_MTHD(----,----,desc)        "Default"
	set SYS_LIMIT_MTHD(----,----,scheme_desc) ""
	set SYS_LIMIT_MTHD(----,----,pay_mthd)    "----"
	set SYS_LIMIT_MTHD(----,----,scheme)      "----"
	set pay_mthds "----,----"

	for {set i 0} {$i < $nrows} {incr i} {
		set pay_mthd [db_get_col $rs $i pay_mthd]

		if {$pay_mthd == "CC"} {
			set pay_schemes $schemes
		} else {
			set pay_schemes [list [list "----" ""]]
		}

		foreach s $pay_schemes {

			set scheme      [lindex $s 0]
			set scheme_desc [lindex $s 1]

			set ps "$pay_mthd,$scheme"

			lappend pay_mthds $ps

			set SYS_LIMIT_MTHD($ps,pay_mthd) $pay_mthd
			set SYS_LIMIT_MTHD($ps,scheme) $scheme
			set SYS_LIMIT_MTHD($ps,scheme_desc) $scheme_desc
			set SYS_LIMIT_MTHD($ps,desc) [db_get_col $rs $i desc]
		}
	}
	db_close $rs

	tpBindVar MthdPayMthd    SYS_LIMIT_MTHD pay_mthd    pay_mthd
	tpBindVar MthdScheme     SYS_LIMIT_MTHD scheme      pay_mthd
	tpBindVar MthdSchemeDesc SYS_LIMIT_MTHD scheme_desc pay_mthd
	tpBindVar MthdDesc       SYS_LIMIT_MTHD desc        pay_mthd

	foreach ps $pay_mthds {
		if {![info exists SYS_LIMIT_DATA($ps,allow_funds_dep)]} {
			lappend SYS_LIMIT_MTHD(remaining_mthds) $ps
		}
	}
}



#
# Get payment method description using method code (tPayMthd.pay_mthd)
#
proc get_mthd_desc {pay_mthd_str} {

	global DB
	foreach {pay_mthd scheme} [split $pay_mthd_str ","] {}

	if {$pay_mthd == "CC"} {

		set sql [subst {
			select
				m.desc || ' ' || s.scheme_name as mthd_desc
			from
				tpaymthd m,
				tcardschemeinfo s
			where
				m.pay_mthd = ? and
				s.scheme = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $pay_mthd $scheme]
	} else {

		set sql [subst {
			select
				desc mthd_desc
			from
				tpaymthd
			where
				pay_mthd = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $pay_mthd]
	}

	inf_close_stmt $stmt
	if {[db_get_nrows $rs] == 1} {

		set mthd_desc [db_get_col $rs 0 mthd_desc]
	} else {

		set mthd_desc $pay_mthd
	}
	db_close $rs

	return $mthd_desc
}


# Update tPmtChangeChk with new values and status for checks.
proc do_upd_pmt_change_chks {} {

	global DB

	set arg_err_list [list]

	# Retrieve and check the input arguments
	foreach {arg var} {
		MaxSBBalance      max_sb_balance
		MaxExtBalance     max_ext_balance
		MaxTotalBalance   max_total_balance
		MaxCardChanges    max_card_changes
		CardChangePeriod  card_change_period
		MaxPMBRemove      max_pmb_remove
		MaxPokerInPlay    max_poker_in_play
		MaxPokerWallet    max_poker_wallet
		MaxCasinoWallet   max_casino_wallet
		MaxPokerBonus     max_poker_bonus
		MaxCasinoBonus    max_casino_bonus

	} {
		set $var [ob_chk::get_arg $arg\
			-err_msg "$var should be a positive number."\
			-err_list arg_err_list\
			NULL UINT]
	}

	if {[llength $arg_err_list]} {
		tpSetVar IsError 1
		OT_LogWrite 1 "Errors from input args: $arg_err_list"
		tpBindString ErrMsg "Errors from input args: [join $arg_err_list '<br>']"
		go_control_main
		return
	}

	set stmt [inf_prep_sql $DB {
		update tPmtChangeChk
		set
			max_sb_balance     = ?,
			max_ext_balance    = ?,
			max_total_balance  = ?,
			max_card_changes   = ?,
			card_change_period = ?,
			max_pmb_remove     = ?,
			max_poker_in_play  = ?,
			max_poker_wallet   = ?,
			max_casino_wallet  = ?,
			max_poker_bonus    = ?,
			max_casino_bonus   = ?

	}]

	inf_exec_stmt $stmt \
			$max_sb_balance \
			$max_ext_balance \
			$max_total_balance \
			$max_card_changes \
			$card_change_period \
			$max_pmb_remove \
			$max_poker_in_play \
			$max_poker_wallet \
			$max_casino_wallet \
			$max_poker_bonus \
			$max_casino_bonus

	inf_close_stmt $stmt

	go_control_main
}



}
