# ==============================================================
# $Id: IB.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::IB {

asSetAct ADMIN::TXN::IB::GoTxn   [namespace code go_balls_sub]


#
# ----------------------------------------------------------------------------
# this proc outputs information for a given subscription such as whether it is
# completed, num drws remaining etc.
# ----------------------------------------------------------------------------
#
proc go_balls_sub args {

	global DB BALLS

	set CUST_BALLS_PAYOUT_SUB {
		select
			p.sub_id
		from
			tBallsPayout p
		where
			p.payout_id = ?
	}

	set CUST_BALLS_SUB_INFO {
		select
			p.payout_id,
			p.payout,
			d.drw_id,
			d.ball1,
			d.ball2,
			d.ball3,
			d.ball4,
			d.ball5,
			d.ball6,
			s.ndrw,
			s.sub_id,
			s.cr_date,
			s.seln,
			s.firstdrw_id,
			s.lastdrw_id,
			s.stake,
			s.returns
		from
			tBallsSub s,
			tBallsDrw d,
			outer tBallsPayout p
		where
			s.sub_id= ? and
			d.drw_id between s.firstdrw_id and s.lastdrw_id and
			p.sub_id=s.sub_id and
			p.drw_id=d.drw_id
		order by
			d.drw_id
	}

	set CUST_BALLS_SUB_DETAILS {
		select
			c.ccy_code,
			c.exch_rate,
			s.firstdrw_id,
			s.lastdrw_id,
			s.stake,
			s.returns,
			t.desc
		from
			tAcct a,
			tBallsSub s,
			tBallsSubType t,
			tCcy c
		where
			s.sub_id = ? and
			s.type_id = t.type_id and
			s.acct_id = a.acct_id and
			a.ccy_code = c.ccy_code
	}

	set CUST_BALLS_SUB_PAYOUT {
		select
			count(*) as total
		from
			tBallsPayout
		where
			sub_id = ?
	}

	set CUST_BALLS_SUB_CURRENTDRW {
		select
			lastdrw_id
		from
			tBallsDrwInfo
	}

	if {[string equal "IB--" [reqGetArg op_type]]} {
		set sub_id [reqGetArg op_ref_id]
	} else {
		set stmt_sub [inf_prep_sql $DB $CUST_BALLS_PAYOUT_SUB]
		set rs_sub [inf_exec_stmt $stmt_sub [reqGetArg op_ref_id]]
		set sub_id [db_get_col $rs_sub 0 sub_id]
		db_close $rs_sub
                inf_close_stmt $stmt_sub
	}

	set stmt_info       [inf_prep_sql $DB $CUST_BALLS_SUB_INFO]
	set rs_info         [inf_exec_stmt $stmt_info $sub_id]

	set stmt_payout     [inf_prep_sql $DB $CUST_BALLS_SUB_PAYOUT]
	set rs_payout       [inf_exec_stmt $stmt_payout $sub_id]

	set stmt_details    [inf_prep_sql $DB $CUST_BALLS_SUB_DETAILS]
	set rs_details      [inf_exec_stmt $stmt_details $sub_id]

	set stmt_current    [inf_prep_sql $DB $CUST_BALLS_SUB_CURRENTDRW]
	set rs_current      [inf_exec_stmt $stmt_current]

	set numdrws          [db_get_col $rs_info    0 ndrw]
	set lastDrw_id       [db_get_col $rs_details 0 lastdrw_id]
	set currentDrw_id    [db_get_col $rs_current 0 lastdrw_id]
	set firstDrw_id      [db_get_col $rs_details 0 firstdrw_id]

	set numDrwsExecuted  [expr {$currentDrw_id-$firstDrw_id+1}]
	set numRemainingDrws [expr {$numdrws-$numDrwsExecuted}]

	if {$numRemainingDrws < 0} {
		set numRemainingDrws 0
	}

	set temp_stake           [db_get_col $rs_details 0 stake]
	set total_stake          [expr {$numdrws*$temp_stake}]

	if  {$lastDrw_id < $currentDrw_id} {
		set subIsFinished Yes
	} else {
		set subIsFinished No
	}

	tpBindString SubDate        [db_get_col $rs_info 0 cr_date]
	tpBindString SubSeln        [db_get_col $rs_info 0 seln]
	tpBindString SubDraws       $numdrws
	tpBindString SubDrawsLeft   $numRemainingDrws
	tpBindString SubFirstDrawId $firstDrw_id
	tpBindString SubLastDrawId  $lastDrw_id
	tpBindString SubWinCount    [db_get_col $rs_payout 0 total]
	tpBindString SubCCYCode     [db_get_col $rs_details ccy_code]
	tpBindString SubStake       $total_stake
	tpBindString SubReturns     [db_get_col $rs_details 0 returns]
	tpBindString SubCompleted   $subIsFinished
	tpBindString SubDesc        [db_get_col $rs_details 0 desc]

	db_close $rs_info
	inf_close_stmt $stmt_info
	db_close $rs_payout
	inf_close_stmt $stmt_payout
	db_close $rs_details
	inf_close_stmt $stmt_details
	db_close $rs_current
	inf_close_stmt $stmt_current

	asPlayFile -nocache balls_sub.html
}


}
