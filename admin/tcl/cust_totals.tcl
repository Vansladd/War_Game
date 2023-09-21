# ==============================================================
# $Id: cust_totals.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Configuration:
#   FUNC_CUST_SIMPLE_TOTALS -  If simple (daily) totals are available [0|1].
#
# Permissions
#    ViewCustSimpleTotals   - If the user is allowed to view simple (daily) totals.
#
#    insert into tAdminOp (action, desc, type) values ("ViewCustSimpleTotals", "View the simple(daily) totals for a customer.", "CSV");
#
# Procedures:
#   ADMIN::CUST_TOTALS::allowed_cust_simple_totals - If the user is allowed to
#                                                    view simple (daily) totals.
#   ADMIN::CUST_TOTALS::go_cust_simple_totals - Show a customers simple totals.
#
namespace eval ADMIN::CUST_TOTALS {

asSetAct ADMIN::CUST_TOTALS::DoCustTotals    [namespace code do_cust_totals]
asSetAct ADMIN::CUST_TOTALS::GoCustSimpleTotals [namespace code go_cust_simple_totals]


proc go_cust_totals {} {

	global DB
	global DATA

	set cust_id [reqGetArg CustId]

	set acct_id [_get_acct_id $cust_id]

	#
	# calculate the totals for each op type and each BSTK, channel
	#
	array set DATA ""
  
    # Choose whenever or not calculating totals over BP or over regular month
    if { [OT_CfgGetTrue FUNC_BUSINESS_PERIOD] && [OT_CfgGetTrue CALCULATE_OVER_BP] }  {
       set calculate_on_bp 1
    } else {
        set calculate_on_bp 0
    }

    ob_log::write INFO "ADMIN::CUST_TOTALS::go_cust_totals >> Calculating totals (bp flag is $calculate_on_bp)"
	acct_totals::calculate_totals $acct_id DATA $calculate_on_bp


	tpSetVar nOpTypes   $DATA(optypes,number)
	tpSetVar nChannels  $DATA(channels,number)
	tpSetVar optypes  optypes
	tpSetVar channels channels
	tpSetVar week week

    if { $calculate_on_bp  == 1 } {
        # binding template vars for business period
		if { $DATA(error_message) != ""} {
			tpSetVar IsError 1
			tpBindString ErrMsg $DATA(error_message)
			ob_log::write ERROR {ADMIN::CUST_TOTALS::go_cust_totals >> $DATA(error_message)}
		} else {
			ob_log::write INFO {ADMIN::CUST_TOTALS::go_cust_totals >> Binding tpvars over Business Period}
			tpBindString BperiodFrom    [clock format [clock scan $DATA(bperiod,from)] -format {%d %b %y}]
			tpBindString BperiodTo      [clock format [clock scan $DATA(bperiod,to)] -format {%d %b %y}]
		
			tpBindVar OBperiodAmt  DATA bperiod,amount optypes j_op_idx
			tpBindVar CBperiodAmt  DATA bperiod,amount channels channel_idx
			tpBindString TotalStakeBperiod  $DATA(BSTK,bperiod,amount)
			tpBindString WLBperiod  $DATA(WL,bperiod,amount)
			tpBindString WLPBperiod  $DATA(WLP,bperiod,amount)
		}
    } else {
        # binding template vars for monthly period
        ob_log::write INFO {ADMIN::CUST_TOTALS::go_cust_totals >> Binding tpvars over current month}
        tpBindVar OMnthAmt DATA month,amount optypes j_op_idx
        tpBindVar CMnthAmt DATA month,amount channels channel_idx
        tpBindString TotalStakeMnth $DATA(BSTK,month,amount)
        tpBindString WLMnth $DATA(WL,month,amount)
        tpBindString WLPMnth $DATA(WLP,month,amount)
    }

	tpBindVar j_op_name DATA name optypes j_op_idx
	tpBindVar channel   DATA name channels channel_idx

	tpBindVar OStmtAmt DATA stmt,amount optypes j_op_idx
	tpBindVar CStmtAmt DATA stmt,amount channels channel_idx
	tpBindVar OWeekAmt DATA week,amount optypes j_op_idx
	tpBindVar CWeekAmt DATA week,amount channels channel_idx
	tpBindVar OYearAmt DATA year,amount optypes j_op_idx
	tpBindVar CYearAmt DATA year,amount channels channel_idx
	tpBindVar OAllAmt  DATA all,amount optypes j_op_idx
	tpBindVar CAllAmt  DATA all,amount channels channel_idx

	tpBindString TotalStakeStmt $DATA(BSTK,stmt,amount)
	tpBindString TotalStakeWeek $DATA(BSTK,week,amount)
	tpBindString TotalStakeYear $DATA(BSTK,year,amount)
	tpBindString TotalStakeAll  $DATA(BSTK,all,amount)

	tpBindString WLStmt $DATA(WL,stmt,amount)
	tpBindString WLWeek $DATA(WL,week,amount)
	tpBindString WLYear $DATA(WL,year,amount)
	tpBindString WLAll  $DATA(WL,all,amount)

	tpBindString WLPStmt $DATA(WLP,stmt,amount)
	tpBindString WLPWeek $DATA(WLP,week,amount)
	tpBindString WLPYear $DATA(WLP,year,amount)
	tpBindString WLPAll  $DATA(WLP,all,amount)


	tpBindString CustId $cust_id

	asPlayFile -nocache cust_totals.html

	unset DATA
}


proc do_cust_totals {} {

	set action [reqGetArg SubmitName]
	ob_log::write DEBUG {action=$action}
	if {$action == "Back"} {
		if {[string equal [reqGetArg back] "TxnQuery"]} {
			ADMIN::CUST_TXN::go_txn_query
		} else {
			ADMIN::CUST::go_cust
		}
		return
	} else {
		error "unrecognised action"
	}
}

# Gets the account id for the customer id.
#
#   cust_id -  The customer's cust_id.
#
#   returns -  The customer's acct_id.
#
proc _get_acct_id {cust_id {ACCT_ARR ""}} {
	global DB

	if {$ACCT_ARR != ""} {
		upvar 1 $ACCT_ARR ACCT
	}

	if {![string is integer -strict $cust_id] || $cust_id < 0} {
		error "cust_id is not an positive integer"
	}

	set sql {
		select
			c.username,
			c.acct_no,
			a.acct_id
		from
			tAcct     a,
			tCustomer c
		where
			a.cust_id = c.cust_id
		and c.cust_id = ?
	}

	set stmt    [inf_prep_sql $DB $sql]
	set rs      [inf_exec_stmt $stmt $cust_id]

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		foreach col [db_get_colnames $rs] {
			set ACCT($col) [db_get_col $rs 0 $col]
		}
	}

	db_close $rs
	inf_close_stmt $stmt

	if {$nrows == 1} {
		return $ACCT(acct_id)
	} else {
		error "$nrows rows returned, expected 1"
	}
}

# If the user is allowed to use simple (daily) totals.
#
#   returns - [0|1]
#
proc allowed_cust_simple_totals {} {
	return [expr {
		[OT_CfgGet FUNC_CUST_SIMPLE_TOTALS 0] &&
		[op_allowed ViewCustSimpleTotals]
	}]
}

# Get simple (daily) totals for fixed odds, pools, xgames and deposits for a
# certain period of time.
#
proc go_cust_simple_totals {} {
	global DATA
	global DATA_DAYS

	if {![allowed_cust_simple_totals]} {
		error "You are not allowed to view daily totals"
	}

	set cust_id    [reqGetArg CustId]
	tpBindString CustId $cust_id

	set acct_id    [_get_acct_id $cust_id ACCT]

	set start_time [reqGetArg start_time]
	set end_time   [reqGetArg end_time]

	if {[OT_CfgGet SHOW_WEEKLY_TOTALS 0]} {
		set page_name  [reqGetArg page_name]

		set daily 0

		if {$page_name == ""} {
			set page_name "Daily Totals"
			set daily 1
			tpSetVar isDaily 1
		}

		tpBindString SIMPLE_TOTALS_title $page_name
	}
	foreach {ok xl msg} [acct_totals::calculate_simple_totals \
		$acct_id \
		DATA \
		DATA_DAYS \
		$start_time \
		$end_time] {break}

	if {!$ok} {
		error "Failed to get totals: $msg"
	}

	ob::log::write_array DEBUG DATA

	foreach method [list fixed pool xgame total] {
		foreach name [list stk stl ustl winnings refund profit] {
			tpBindString SIMPLE_TOTALS_${method}_$name $DATA(${method}_$name)
		}
	}

	tpBindVar SIMPLE_TOTALS_RK_cpm_id  DATA cpm_id  SIMPLE_TOTALS_RK_idx
	tpBindVar SIMPLE_TOTALS_RK_ref_key DATA ref_key SIMPLE_TOTALS_RK_idx
	tpBindVar SIMPLE_TOTALS_RK_dep     DATA dep     SIMPLE_TOTALS_RK_idx
	tpBindVar SIMPLE_TOTALS_RK_wtd     DATA wtd     SIMPLE_TOTALS_RK_idx

	tpSetVar SIMPLE_TOTALS_RK_nrows $DATA(RK_nrows)

	tpBindString SIMPLE_TOTALS_RK_total_dep $DATA(total_dep)
	tpBindString SIMPLE_TOTALS_RK_total_wtd $DATA(total_wtd)

	tpBindString SIMPLE_TOTALS_start_time $DATA(start_time)
	tpBindString SIMPLE_TOTALS_end_time   $DATA(end_time)

	if {[OT_CfgGet SHOW_WEEKLY_TOTALS 0]  && $daily} {
		set today [clock format [clock scan today] -format {%Y-%m-%d}]
		set week_start [clock format [clock scan "$today - 6 days"] -format {%Y-%m-%d 00:00:00}]
		set week_end "$today 23:59:59"

		tpBindString SIMPLE_TOTALS_week_start $week_start
		tpBindString SIMPLE_TOTALS_week_end   $week_end
	}

	if {[OT_CfgGet SHOW_WEEKLY_TOTALS 0]} {
		tpSetVar SIMPLE_TOTALS_DAYS_nrows  $DATA_DAYS(nrows)

		tpBindVar SIMPLE_TOTALS_DAY_refkey DATA_DAYS ref_key DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_scheme DATA_DAYS scheme  DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_day    DATA_DAYS day     DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_numdep DATA_DAYS numdep  DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_numwtd DATA_DAYS numwtd  DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_dep    DATA_DAYS dep     DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_wtd    DATA_DAYS wtd     DAYS_idx
		tpBindVar SIMPLE_TOTALS_DAY_date   DATA_DAYS date    DAYS_idx
	}


	foreach {n v} [array get ACCT] {
		tpBindString ACCT_$n $v
	}

	asPlayFile -nocache acct_simple_totals.html

	array unset DATA
	array unset DATA_DAYS
}

# close namespace
}
