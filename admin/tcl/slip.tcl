# ==============================================================
# $Id: slip.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SLIP {

asSetAct ADMIN::SLIP::GoSlipQuery         [namespace code go_slip_query]
asSetAct ADMIN::SLIP::DoSlipQuery         [namespace code do_slip_query]
asSetAct ADMIN::SLIP::GoSlipReceipt       [namespace code go_slip_receipt]
asSetAct ADMIN::SLIP::DoSlipCancel        [namespace code do_slip_cancel]

proc go_slip_query {} {
	asPlayFile -nocache slip_query.html
}

proc do_slip_query {} {
	global DB SLIP

	#
	# Customer fields
	#
	set where ""
	set call_inner 0
	if {[string length [set name [reqGetArg Customer]]] > 0} {
		if {[reqGetArg UpperCust] == "Y"} {
			lappend where "[upper_q c.username] like [upper_q '${name}%']"
		} else {
			lappend where "c.username like \"${name}%\""
		}
	}
	if {[string length [set fname [reqGetArg FName]]] > 0} {
		lappend where "[upper_q r.fname] = [upper_q \'$fname\']"
	}
	if {[string length [set lname [reqGetArg LName]]] > 0} {
		lappend where [get_indexed_sql_query $lname lname]
	}
	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where [get_indexed_sql_query "%$email" email]
	}
	if {[string length [set acctno [reqGetArg AcctNo]]] > 0} {
		lappend where "upper(c.acct_no) = upper('$acctno')"
	}

	#
	# Slip fields
	#
	set bar_code [string toupper [reqGetArg BarCode]]

	if {[string length $bar_code] > 0} {
		lappend where "upper(s.bar_code) like '${bar_code}%'"
	}

	set slip_status [string toupper [reqGetArg SlipStatus]]

	if {[string length $slip_status] > 0} {
		lappend where "s.status = '${slip_status}'"
	}

	set sd1 [reqGetArg SlipDate1]
	set sd2 [reqGetArg SlipDate2]

	if {([string length $sd1] > 0) || ([string length $sd2] > 0)} {
		lappend where [mk_between_clause s.capture_date date $sd1 $sd2]
	}

	set sdperiod [reqGetArg SlipPlacedFrom]

	if {[string length $sdperiod] > 0 && $sdperiod > 0} {

		set now [clock seconds]

		switch -exact -- $sdperiod {
			1 {
				# today
				set lo [clock format $now -format {%Y-%m-%d 00:00:00}]
				set hi [clock format $now -format {%Y-%m-%d 23:59:59}]
			}
			2 {
				# yesterday
				set yday [expr {$now-60*60*24}]
				set lo   [clock format $yday -format {%Y-%m-%d 00:00:00}]
				set hi   [clock format $yday -format {%Y-%m-%d 23:59:59}]
			}
			3 {
				# last 3 days
				set 3day [expr {$now-3*60*60*24}]
				set lo   [clock format $3day -format {%Y-%m-%d 00:00:00}]
				set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			4 {
				# last 7 days
				set 7day [expr {$now-7*60*60*24}]
				set lo   [clock format $7day -format {%Y-%m-%d 00:00:00}]
				set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			5 {
				# This month
				set lo [clock format $now -format {%Y-%m-01 00:00:00}]
				set hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			default {
				set lo [set hi ""]
			}
		}

		if {$lo != ""} {
			lappend where [mk_between_clause s.capture_date date $lo $hi]
		}
	}



	#
	# Shop Fields
	#
	set loc_name [string toupper [reqGetArg LocName]]

	if {[string length $loc_name] > 0} {
		lappend where "upper(lo.loc_name) like '${loc_name}%'"
		set call_inner 1
	}

	set term_code [string toupper [reqGetArg TermCode]]

	if {[string length $term_code] > 0} {
		lappend where "upper(te.term_code) = '${term_code}'"
		set call_inner 1
	}


	#
	# Don't run a query with no search criteria...
	#
	if {![llength $where]} {
		# Nothing selected
		err_bind "Please enter some search criteria"
		go_slip_query
		return
	}

	set where     [concat and [join $where " and "]]

	if {$call_inner} {
		set call_tables {tCall ca, tAdminLoc lo, tAdminTerm te}
	} else {
		set call_tables {outer (tCall ca,tAdminLoc lo,tAdminTerm te)}
	}

	#Note that this query will return Yes for settled, if there are NO
	#entries in tslippart for the tslip.
	set sql [subst {
		select
		  s.slip_id,
		  c.cust_id,
		  c.username,
		  c.acct_no,
		  a.ccy_code,
		  s.capture_date,
		  s.amount stake,
		  s.tax,
		  s.status,
		  s.call_id,
		  s.bar_code,
		  ca.term_code,
		  lo.loc_name,
		  case when exists (
		  	select 1
				from
					tbet b,
					tslippart sp
				where
					sp.slip_id=s.slip_id and
					sp.part_ref_key<>'MADJ' and
					sp.part_ref_id=b.bet_id and
					b.settled = 'N'
			) then 'No' else 'Yes' end as settled
		from
		  tCustomer c,
		  tCustomerReg r,
		  tAcct a,
		  tSlip s,
		  $call_tables
		where
		  s.acct_id = a.acct_id
		and
		  a.cust_id = c.cust_id
		and
		  c.cust_id = r.cust_id
		and
		  s.call_id = ca.call_id
		and
		  ca.term_code = te.term_code
		and
		  te.loc_code = lo.loc_code
		$where
		order by capture_date desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows == 1} {
		go_slip_receipt slip_id [db_get_col $res 0 slip_id]
		db_close $res
		return
	}

	for {set r 0} {$r < $rows} {incr r} {
		switch -- [db_get_col $res $r status] {
			"N" {set slip_status "Not Completed"}
			"D" {set slip_status "Completed"}
			"X" {set slip_status "Cancelled"}
		}

		#Only display settled value if the slip is completed
		if {$slip_status == "Completed"} {
			set SLIP($r,settled)  [db_get_col $res $r settled]
		} else {
			set SLIP($r,settled)  ""
		}

		set SLIP($r,slip_id)      [db_get_col $res $r slip_id]
		set SLIP($r,capture_date) [db_get_col $res $r capture_date]
		set SLIP($r,bar_code)     [db_get_col $res $r bar_code]
		set SLIP($r,call_id)      [db_get_col $res $r call_id]
		set SLIP($r,stake)        [db_get_col $res $r stake]
		set SLIP($r,ccy)          [db_get_col $res $r ccy_code]
		set SLIP($r,cust_id)      [db_get_col $res $r cust_id]
		set SLIP($r,cust_name)    [db_get_col $res $r username]
		set SLIP($r,acct_no)      [db_get_col $res $r acct_no]
		set SLIP($r,status)       $slip_status
		set SLIP($r,loc_name)     [db_get_col $res $r loc_name]
		set SLIP($r,term_code)    [db_get_col $res $r term_code]
	}
	tpSetVar NumSlips $rows

	tpBindVar CustId      SLIP cust_id      slip_idx
	tpBindVar CaptureDate SLIP capture_date slip_idx
	tpBindVar CustName    SLIP cust_name    slip_idx
	tpBindVar AcctNo      SLIP acct_no      slip_idx
	tpBindVar SlipId      SLIP slip_id      slip_idx
	tpBindVar BarCode     SLIP bar_code     slip_idx
	tpBindVar SlipCCY     SLIP ccy          slip_idx
	tpBindVar SlipStake   SLIP stake        slip_idx
	tpBindVar SlipStatus  SLIP status       slip_idx
	tpBindVar LocName     SLIP loc_name     slip_idx
	tpBindVar TermCode    SLIP term_code    slip_idx
	tpBindVar SlipSettled SLIP settled      slip_idx

	asPlayFile -nocache slip_list.html

	catch {unset SLIP}
}

proc go_slip_receipt args {
	global DB BET POOL_BET XGAME_BET MANADJ_LIST

	set slip_id [reqGetArg SlipId]
	foreach {n v} $args {
		set $n $v
	}


	set sql [subst {
		select
		  c.cust_id,
		  c.username,
		  c.acct_no,
		  a.ccy_code,
		  s.slip_id,
		  s.capture_date,
		  s.upd_date,
		  s.amount stake,
		  s.tax,
		  s.status,
		  s.call_id,
		  s.bar_code,
		  	  s.cancel_reason,
		  ad.username cancel_username,
		  ca.term_code,
		  lo.loc_name
		from
		  tCustomer c,
		  tAcct a,
	   		  tSlip s,
		  outer tAdminUser ad,
		  outer (tCall ca,
				 tAdminLoc lo,
				 tAdminTerm te)
		where
		  s.acct_id = a.acct_id
		and
		  a.cust_id = c.cust_id
		and
		  s.cancel_user_id = ad.user_id
		and
		  s.call_id = ca.call_id
		and
		  ca.term_code = te.term_code
		and
		  te.loc_code = lo.loc_code
		and
		  s.slip_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $slip_id]
	inf_close_stmt $stmt

	tpBindString SlipId       $slip_id
	tpBindString SlipCustId   [db_get_col $res 0 cust_id]
	tpBindString SlipAcctNo   [db_get_col $res 0 acct_no]
	tpBindString SlipUsername [db_get_col $res 0 username]
	tpBindString SlipCCY      [db_get_col $res 0 ccy_code]
	tpBindString SlipStake    [db_get_col $res 0 stake]
	tpBindString BarCode      [db_get_col $res 0 bar_code]
	tpBindString SlipDate     [db_get_col $res 0 capture_date]
	tpBindString SlipCancelDate   [db_get_col $res 0 upd_date]
	tpBindString SlipCancelReason [db_get_col $res 0 cancel_reason]
	tpBindString SlipCancelUsername [db_get_col $res 0 cancel_username]
	tpBindString SlipTermCode [db_get_col $res 0 term_code]
	tpBindString SlipLocName  [db_get_col $res 0 loc_name]

	tpSetVar SlipStatus [db_get_col $res 0 status]

	db_close $res

	#
	# get the individual bet details
	#
	set sports_list {}
	set xgame_list  {}
	set pool_list   {}
	set manadj_list {}

	set sql_part [subst {
	  select
		slip_part_id,
		part_ref_key,
		part_ref_id
	  from
		tSlipPart
	  where
		slip_id = ?
	  order by 2,3
	}]

	set stmt [inf_prep_sql $DB $sql_part]
	set res_part  [inf_exec_stmt $stmt $slip_id]
	inf_close_stmt $stmt

	set num_parts [db_get_nrows $res_part]

	if {$num_parts == 0} {
		tpSetVar PartsExist "N"
		db_close $res_part
		asPlayFile -nocache slip_receipt.html
		return
	}

	tpSetVar PartsExist "Y"

	for {set r 0} {$r < $num_parts} {incr r} {
		switch -- [db_get_col $res_part $r part_ref_key] {
			"ESB" {
				lappend sports_list [db_get_col $res_part $r part_ref_id]
			}
			"XGAM" {
				lappend xgame_list [db_get_col $res_part $r part_ref_id]
			}
			"TPB" {
				lappend pool_list [db_get_col $res_part $r part_ref_id]
			}
			"MADJ" {
				lappend manadj_list [db_get_col $res_part $r part_ref_id]
			}
		}
	}

	db_close $res_part
	set completedby ""

	if {[llength $sports_list] > 0} {
		tpSetVar NumBets [llength $sports_list]

		set bet_sql [subst {
		  select
			  '' cust_id,
			  '' username,
			  '' acct_no,
			  '' ccy_code,
			  b.cr_date,
			  b.receipt,
			  b.stake,
			  b.status,
			  b.winnings,
			  b.refund,
			  b.settled,
			  b.num_lines,
			  b.bet_type,
			  b.leg_type,
			  b.ipaddr,
			  a.username as placed_by,
			  e.desc ev_name,
			  e.start_time,
			  g.name mkt_name,
			  s.desc seln_name,
			  s.result,
			  s.ev_mkt_id,
			  s.ev_oc_id,
			  s.ev_id,
			  o.bet_id,
			  o.leg_no,
			  o.part_no,
			  o.leg_sort,
			  o.price_type,
			  o.o_num o_num,
			  o.o_den o_den
		  from
			  tBet b,
			  tOBet o,
			  outer (tAdminUser a),
			  tEvOc s,
			  tEvMkt m,
			  tEvOcGrp g,
			  tEv e
		  where
			  b.bet_id = o.bet_id and
			  o.ev_oc_id = s.ev_oc_id and
			  s.ev_mkt_id = m.ev_mkt_id and
			  m.ev_oc_grp_id = g.ev_oc_grp_id and
			  s.ev_id = e.ev_id and
			  b.placed_by = a.user_id and
		 	  b.bet_id in ([join $sports_list ,])
		  union
		  select
			  '' cust_id,
			  '' username,
			  '' acct_no,
			  '' ccy_code,
			  b.cr_date,
			  b.receipt,
			  b.stake,
			  b.status,
			  b.winnings,
			  b.refund,
			  b.settled,
			  b.num_lines,
			  b.bet_type,
			  b.leg_type,
			  b.ipaddr,
			  a.username as placed_by,
			  o.desc_1 ev_name,
			  extend(current, year to second) start_time,
			  o.desc_2 mkt_name,
			  o.desc_3 seln_name,
			  '-' result,
			  0 ev_mkt_id,
			  0 ev_oc_id,
			  0 ev_id,
			  o.bet_id,
			  1 leg_no,
			  1 part_no,
			  '--' leg_sort,
			  'L' price_type,
			  1 o_num,
			  1 o_den
		  from
			  tBet b,
			  outer (tAdminUser a),
			  tManOBet o
		  where
			  b.bet_id = o.bet_id and
			  b.placed_by = a.user_id and
		 	  b.bet_id in ([join $sports_list ,])
		  order by
			  25, 26, 27

		}]

		set stmt [inf_prep_sql $DB $bet_sql]
		set bet_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set n_rows [db_get_nrows $bet_res]
		for {set r 0} {$r < $n_rows} {incr r} {
			set completedby [db_get_col $bet_res $r placed_by]
			if {[string length $completedby] > 0} {
				break
			}
		}


		ADMIN::BET::bind_sports_bet_list $bet_res

		db_close $bet_res

	}
	if {[llength $pool_list] > 0} {
		tpSetVar NumPoolBets [llength $pool_list]

		set pool_sql [subst {
			select
				b.pool_bet_id,
				c.cust_id,
				c.username,
				c.acct_no,
				a.ccy_code,
				b.cr_date,
				b.receipt,
				b.ipaddr,
				b.ccy_stake,
				b.stake,
				b.status,
				b.settled,
				b.winnings,
				b.refund,
				b.num_lines,
				(b.stake / b.num_lines) unitstake,
				b.bet_type,
				d.username as placed_by,
				e.desc ev_name,
				t.name meeting_name,
				s.desc seln_name,
				s.result,
				s.ev_oc_id,
				s.ev_id,
				pb.leg_no,
				pb.part_no,
				p.pool_id,
				p.pool_type_id,
				p.rec_dividend,
				p.result_conf pool_conf,
				pt.name as pool_name,
				ps.ccy_code as pool_ccy_code
			from
				tPoolBet b,
				tPBet pb,
				tAcct a,
				outer (tAdminuser d),
				tCustomer c,
				tEvOc s,
				tEvMkt m,
				tEv e,
				tEvType t,
				tCustomerReg r,
				tPool p,
				tPoolType pt,
				tPoolSource ps
			where
				b.pool_bet_id = pb.pool_bet_id and
				b.acct_id = a.acct_id and
				a.cust_id = c.cust_id and
				r.cust_id = c.cust_id and
				pb.ev_oc_id = s.ev_oc_id and
				s.ev_mkt_id = m.ev_mkt_id and
				s.ev_id = e.ev_id and
				t.ev_type_id = e.ev_type_id and
				pb.pool_id = p.pool_id and
				p.pool_type_id = pt.pool_type_id and
				p.pool_source_id = pt.pool_source_id and
				pt.pool_source_id = ps.pool_source_id and
			  	b.placed_by = d.user_id and
				b.pool_bet_id in ([join $pool_list ,])
			order by 1 desc
		}]

		set stmt [inf_prep_sql $DB $pool_sql]
		set pool_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if {[string length $completedby] == 0} {
			set n_rows [db_get_nrows $pool_res]
			for {set r 0} {$r < $n_rows} {incr r} {
				set completedby [db_get_col $pool_res $r placed_by]
				if {[string length $completedby] > 0} {
					break
				}
			}
		}
		ADMIN::BET::bind_pools_bet_list $pool_res

		db_close $pool_res

	}
	if {[llength $xgame_list] > 0} {
		OT_LogWrite 3 "xgame bets: $xgame_list"
		tpSetVar NumXGameBets [llength $xgame_list]

		set xgame_sql [subst {
			(select
				s.xgame_sub_id,
				b.xgame_bet_id,
				c.username,
				c.acct_no,
				b.cr_date,
				b.settled,
				d.sort,
				a.ccy_code,
				c.cust_id,
				b.stake,
				b.winnings,
				b.refund,
				u.username as placed_by,
				g.comp_no,
				s.num_subs,
				s.picks,
				NVL(g.results,'-') as results,
				d.name
			from
				tAcct a,
				tCustomer c,
				tXGameSub s,
				tXGameBet b,
				tSlipPart sp,
				outer (tAdminUser u),
				tXGame g,
				tXGameDef d
			where
				a.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_sub_id = b.xgame_sub_id and
				b.xgame_id = g.xgame_id and
				g.sort = d.sort and
				sp.part_ref_id = s.xgame_sub_id and
				sp.part_ref_key = 'XGAM' and
				sp.slip_id = $slip_id and
			  	sp.user_id = u.user_id and
				s.xgame_sub_id in ([join $xgame_list ,]))
			union
			(select
				s.xgame_sub_id,
				-1 as xgame_bet_id,
				c.username,
				c.acct_no,
				s.cr_date,
				'-' as settled,
				d.sort,
				a.ccy_code,
				c.cust_id,
				s.stake_per_bet as stake,
				0 as winnings,
				0 as refund,
				"" as placed_by,
				g.comp_no,
				s.num_subs,
				s.picks,
				NVL(g.results,'-') as results,
				d.name
			from
				tAcct a,
				tCustomer c,
				tXGameSub s,
				tXGame g,
				tXGameDef d
			where
				a.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_id = g.xgame_id and
				g.sort = d.sort and
				s.authorized = 'N' and
				s.xgame_sub_id in ([join $xgame_list ,]))
			order by
				1 desc, 2 desc
			}]

		set stmt [inf_prep_sql $DB $xgame_sql]
		set xgame_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if {[string length $completedby] == 0} {
			set n_rows [db_get_nrows $xgame_res]
			for {set r 0} {$r < $n_rows} {incr r} {
				set completedby [db_get_col $xgame_res $r placed_by]
				if {[string length $completedby] > 0} {
					break
				}
			}
		}
		set cur_id 0
		set b -1

		array set XGAME_BET [list]
		set rows [db_get_nrows $xgame_res]

		for {set r 0} {$r < $rows} {incr r} {
			set bet_id [db_get_col $xgame_res $r xgame_sub_id]
			if {$bet_id != $cur_id} {
				set cur_id $bet_id
				set l 0
				incr b

				set XGAME_BET($b,num_subs) 0
			}

			incr XGAME_BET($b,num_subs)

			if {$l == 0} {
				set XGAME_BET($b,xgame_sub_id) $bet_id
				set XGAME_BET($b,bet_type)  [db_get_col $xgame_res $r sort]
				set XGAME_BET($b,stake)     [db_get_col $xgame_res $r stake]
				set XGAME_BET($b,ccy)       [db_get_col $xgame_res $r ccy_code]
				set XGAME_BET($b,picks)     [db_get_col $xgame_res $r picks]
				set XGAME_BET($b,cust_id)   [db_get_col $xgame_res $r cust_id]
				set XGAME_BET($b,cust_name) [db_get_col $xgame_res $r username]
				set XGAME_BET($b,acct_no)   [db_get_col $xgame_res $r acct_no]
				set XGAME_BET($b,game_name) [db_get_col $xgame_res $r name]
			}

					# if xgame_bet_id = -1 then sub not authorized
			set xgame_bet_id [db_get_col $xgame_res $r xgame_bet_id]
			if {$xgame_bet_id == -1} {
				set valid_bet 	0
				set no_bet "-"
				set no_bet_id ""
				set XGAME_BET($b,$l,xgame_bet_id) $no_bet_id
				set XGAME_BET($b,$l,comp_no)   	$no_bet
				set XGAME_BET($b,$l,bet_time)  	$no_bet
				set XGAME_BET($b,$l,results)   	$no_bet
				set XGAME_BET($b,$l,settled)   	$no_bet
				set XGAME_BET($b,$l,winnings)  	$no_bet
				set XGAME_BET($b,$l,refund)    	$no_bet

			} else {
				set valid_bet 	1
				set XGAME_BET($b,$l,xgame_bet_id) $xgame_bet_id
				set XGAME_BET($b,$l,comp_no)   [db_get_col $xgame_res $r comp_no]
				set XGAME_BET($b,$l,bet_time)  [db_get_col $xgame_res $r cr_date]
				set XGAME_BET($b,$l,results)   [db_get_col $xgame_res $r results]
				set XGAME_BET($b,$l,settled)   [db_get_col $xgame_res $r settled]
				set XGAME_BET($b,$l,winnings)  [db_get_col $xgame_res $r winnings]
				set XGAME_BET($b,$l,refund)    [db_get_col $xgame_res $r refund]
			}
			incr l
		}

		db_close $xgame_res

		tpSetVar NumXGameBets [expr {$b+1}]
		tpBindVar XGameSubId       XGAME_BET xgame_sub_id  xgame_idx
		tpBindVar XGameBetType     XGAME_BET bet_type      xgame_idx
		tpBindVar XGameBetCCY      XGAME_BET ccy           xgame_idx
		tpBindVar XGameBetPicks	   XGAME_BET picks		   xgame_idx
		tpBindVar XGameBetStake    XGAME_BET stake         xgame_idx
		tpBindVar XGameGameName    XGAME_BET game_name     xgame_idx

		if {$valid_bet==1} {
			tpBindVar XGameBetID  	  XGAME_BET xgame_bet_id xgame_idx xgame_seln_idx
			tpBindVar XGameCompNo	  XGAME_BET comp_no	     xgame_idx xgame_seln_idx
			tpBindVar XGameBetTime     XGAME_BET bet_time    xgame_idx xgame_seln_idx
			tpBindVar XGameResult      XGAME_BET results     xgame_idx xgame_seln_idx
			tpBindVar XGamePrice       XGAME_BET price       xgame_idx xgame_seln_idx
			tpBindVar XGameBetSettled  XGAME_BET settled     xgame_idx xgame_seln_idx
			tpBindVar XGameWinnings    XGAME_BET winnings	 xgame_idx xgame_seln_idx
			tpBindVar XGameRefund	  XGAME_BET refund  	 xgame_idx xgame_seln_idx

		} else {
			tpBindVar XGameBetID  	  XGAME_BET xgame_bet_id xgame_idx
			tpBindVar XGameCompNo	  XGAME_BET comp_no	     xgame_idx
			tpBindVar XGameBetTime    XGAME_BET bet_time     xgame_idx
			tpBindVar XGameResult     XGAME_BET results      xgame_idx
			tpBindVar XGamePrice      XGAME_BET price        xgame_idx
			tpBindVar XGameBetSettled XGAME_BET settled      xgame_idx
			tpBindVar XGameWinnings   XGAME_BET winnings	 xgame_idx
			tpBindVar XGameRefund	  XGAME_BET refund  	 xgame_idx
		}

		#asPlayFile -nocache xgame_sub_list.html
	}

	if {[llength $manadj_list] > 0} {
		OT_LogWrite 3 "manual adjustments: $manadj_list"
		tpSetVar NumManAdj [llength $manadj_list]

		set manadj_sql [subst {
			select
				m.madj_id,
				m.cr_date,
				m.type,
				m.desc,
				m.amount,
				m.pending,
				mt.desc as type_desc
			from
				tManAdj m,
				tManAdjType mt
			where
				m.madj_id in ([join $manadj_list ,]) and
				m.type = mt.type
			}]

		set stmt [inf_prep_sql $DB $manadj_sql]
		set manadj_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		array set MANADJ_LIST [list]
		set rows [db_get_nrows $manadj_res]

		for {set r 0} {$r < $rows} {incr r} {
			set MANADJ_LIST($r,madj_id)   [db_get_col $manadj_res $r madj_id]
			set MANADJ_LIST($r,cr_date)   [db_get_col $manadj_res $r cr_date]
			set MANADJ_LIST($r,type)      [db_get_col $manadj_res $r type]
			set MANADJ_LIST($r,desc)      [db_get_col $manadj_res $r desc]
			set MANADJ_LIST($r,amount)    [db_get_col $manadj_res $r amount]
			set MANADJ_LIST($r,pending)   [db_get_col $manadj_res $r pending]
			set MANADJ_LIST($r,type_desc) [db_get_col $manadj_res $r type_desc]
		}

		tpBindVar ManAdjMadjId    MANADJ_LIST madj_id   manadj_idx
		tpBindVar ManAdjCrDate    MANADJ_LIST cr_date   manadj_idx
		tpBindVar ManAdjType      MANADJ_LIST type      manadj_idx
		tpBindVar ManAdjDesc      MANADJ_LIST desc      manadj_idx
		tpBindVar ManAdjAmount    MANADJ_LIST amount    manadj_idx
		tpBindVar ManAdjPending   MANADJ_LIST pending   manadj_idx
		tpBindVar ManAdjTypeDesc  MANADJ_LIST type_desc manadj_idx

		}

		tpBindString CompletedBy $completedby

	asPlayFile -nocache slip_receipt.html
	catch {unset BET}
	catch {unset POOL_BET}
	catch {unset XGAME_BET}
}

proc do_slip_cancel {} {
	global DB USERNAME

	set slip_id [reqGetArg SlipId]
	set bar_code [reqGetArg BarCode]
	set cancel_reason [reqGetArg CancelReason]

	set sql [subst {
		execute procedure pCancelSlip (
		  p_slip_id   = $slip_id,
		  p_adminuser = '$USERNAME',
		  p_cancel_reason = '$cancel_reason'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 3 "Slip cancel failed $msg"
		err_bind $msg
	} else {
		msg_bind "Slip $bar_code: successfully cancelled"
		OT_LogWrite 3 "Slip cancel succeeded"
	}

	inf_close_stmt $stmt
	go_slip_query
}

}
