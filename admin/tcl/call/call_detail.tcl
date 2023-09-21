# ==============================================================
# $Id: call_detail.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CALL {

asSetAct ADMIN::CALL::GoCall           [namespace code go_call]
asSetAct ADMIN::CALL::GoOverride       [namespace code go_override]
asSetAct ADMIN::CALL::GoXGOverride     [namespace code go_xgame_override]
asSetAct ADMIN::CALL::bind_call_bets   [namespace code bind_call_bets]
asSetAct ADMIN::CALL::bind_call_pmts   [namespace code bind_call_pmts]
asSetAct ADMIN::CALL::bind_call_detail [namespace code bind_call_detail]

#
# ----------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------
#

proc go_call args {

	global DB BET DATA

	set call_id [reqGetArg call_id]
	tpSetVar     call_id $call_id
	tpBindString call_id $call_id

	asPlayFile -nocache call/call_details.html

}

proc go_override args {

	global DB DATA

	set ref_id  [reqGetArg RefId]
	set ref_key [reqGetArg RefKey]

	set call_id [reqGetArg CallId]

	# this is a bit gross
	if {[string length $ref_id] == 0} {
		set sql [subst {
		select
		o.override_id,
		o.cust_id,
		c.username,
		o.oper_id,
		u.username operator,
		o.override_by,
		b.username or_operator,
		o.cr_date,
		o.action,
		o.ref_id,
		o.ref_key,
		o.leg_no,
		o.part_no,
		o.reason
		from
		tOverride o,
		tCustomer c,
		tAdminUser u,
		tAdminUser b
		where
		o.cust_id     = c.cust_id
		and o.oper_id     = u.user_id
		and o.override_by = b.user_id
		and o.call_id     = ?
		order by
		o.override_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $call_id]
	} elseif {[string length $call_id] == 0} {
		set sql [subst {
		select
		o.override_id,
		o.cust_id,
		c.username,
		o.oper_id,
		u.username operator,
		o.override_by,
		b.username or_operator,
		o.cr_date,
		o.action,
		o.ref_id,
		o.ref_key,
		o.leg_no,
		o.part_no,
		o.reason
		from
		tOverride o,
		tCustomer c,
		tAdminUser u,
		tAdminUser b
		where
		o.cust_id     = c.cust_id
		and o.oper_id     = u.user_id
		and o.override_by = b.user_id
		and o.ref_id      = ?
		and o.ref_key	  = ?
		order by
		o.override_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ref_id $ref_key]
	}

	inf_close_stmt $stmt

	tpSetVar NumOR [db_get_nrows $res]

	foreach f [db_get_colnames $res] {
		tpBindTcl OR_${f} sb_res_data $res or_idx $f
	}

	asPlayFile -nocache call/call_bet_override.html

	db_close $res
}


proc go_xgame_override args {

	global DB DATA

	set ref_id [reqGetArg RefId]
	set ref_key [reqGetArg RefKey]

	set call_id [reqGetArg CallId]

	if {[string length $ref_id] == 0} {
		set sql [subst {
		select
		o.override_id,
		o.cust_id,
		c.username,
		o.oper_id,
		u.username operator,
		o.override_by,
		b.username or_operator,
		o.cr_date,
		o.action,
		o.ref_id,
		o.ref_key,
		o.leg_no,
		o.part_no,
		o.reason,
		d.name
		from
		tOverride o,
		tCustomer c,
		tAdminUser u,
		tAdminUser b,
		tXGamesub s,
		tXGameDef d,
		tXGame g
		where
		o.cust_id     = c.cust_id
		and o.oper_id     = u.user_id
		and o.override_by = b.user_id
		and o.call_id     = ?
		and s.xgame_sub_id = o.ref_id
		and g.xgame_id = s.xgame_id
		and d.sort = g.sort
		and
		order by
		o.override_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $call_id]
	} elseif {[string length $call_id] == 0} {
		set sql [subst {
		select
		o.override_id,
		o.cust_id,
		c.username,
		o.oper_id,
		u.username operator,
		o.override_by,
		b.username or_operator,
		o.cr_date,
		o.action,
		o.ref_id,
		o.ref_key,
		o.leg_no,
		o.part_no,
		o.reason,
		d.name
		from
		tOverride o,
		tCustomer c,
		tAdminUser u,
		tAdminUser b,
		tXGameSub s,
		tXGameDef d,
		tXGame g
		where
		o.cust_id     = c.cust_id
		and o.oper_id     = u.user_id
		and o.override_by = b.user_id
		and o.ref_id      = ?
		and o.ref_key	  = ?
		and s.xgame_sub_id = o.ref_id
		and g.xgame_id = s.xgame_id
		and d.sort = g.sort
		order by
		o.override_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ref_id $ref_key]
	}

	inf_close_stmt $stmt

	tpSetVar NumOR [db_get_nrows $res]

	foreach f [db_get_colnames $res] {
		tpBindTcl OR_${f} sb_res_data $res or_idx $f
	}

	asPlayFile -nocache call/call_xgame_override.html

	db_close $res
}

proc bind_call_detail {call_id} {

	global DB

	set sql [subst {
		select
			l.call_id,
			l.oper_id,
			l.source,
			l.term_code,
			l.telephone,
			l.acct_id,
			l.start_time,
			l.end_time,
			l.num_bets,
			l.num_bet_grps,
			l.cancel_code,
			l.cancel_txt,
			u.username operator,
			c.cust_id,
			c.username,
			c.acct_no,
			r.fname,
			r.lname
		from
			tCall l,
			tAcct a,
			tAdminUser u,
			tCustomer c,
			tCustomerReg r
		where
			l.oper_id = u.user_id
		and l.acct_id = a.acct_id
		and a.cust_id = c.cust_id
		and a.cust_id = r.cust_id
		and l.call_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $call_id]

	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString CALL_$c [db_get_col $res 0 $c]
	}


	# Find out how many overrides there were for this call
	set sql2 [subst {
		select count(override_id)
		from tOverride
		where call_id = ?}]

	set stmt2 [inf_prep_sql $DB $sql2]
	set res2  [inf_exec_stmt $stmt2 $call_id]
	inf_close_stmt $stmt2

	tpSetVar CALL_number_of_overrides [db_get_col $res2 0 "(count)"]
	tpBindString CALL_number_of_overrides_str [db_get_col $res2 0 "(count)"]

	db_close $res2
	db_close $res
}

proc bind_call_bets {call_id} {

	global DB BET

	set sql {
		select
			c.cust_id,
			c.username,
			a.ccy_code,
			b.call_id,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.winnings,
			b.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			e.desc ev_name,
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
			""||o.o_num o_num,
			""||o.o_den o_den,
			"B" as odds_type
		from
			tBet b,
			tOBet o,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tCall l
		where
			b.call_id      = ?
		and	b.call_id      = l.call_id
		and l.acct_id      = b.acct_id
		and b.cr_date      > l.start_time
		and b.bet_id       = o.bet_id
		and b.acct_id      = a.acct_id
		and a.cust_id      = c.cust_id
		and o.ev_oc_id     = s.ev_oc_id
		and s.ev_mkt_id    = m.ev_mkt_id
		and m.ev_oc_grp_id = g.ev_oc_grp_id
		and s.ev_id        = e.ev_id

		union

		select
			c.cust_id,
			c.username,
			a.ccy_code,
			b.call_id,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.winnings,
			b.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			e.desc ev_name,
			g.name mkt_name,
			s.desc seln_name,
			s.result,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			o.pool_bet_id as bet_id,
			o.leg_no,
			o.part_no,
			"" leg_sort,
			"" price_type,
			"" o_num,
			"" o_den,
			"P" as odds_type
		from
			tPoolBet b,
			tPBet o,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tCall l
		where
			b.call_id      = ?
		and b.call_id      = l.call_id
		and l.acct_id      = b.acct_id
		and b.cr_date      > l.start_time
		and b.pool_bet_id  = o.pool_bet_id
		and b.acct_id      = a.acct_id
		and a.cust_id      = c.cust_id
		and o.ev_oc_id     = s.ev_oc_id
		and s.ev_mkt_id    = m.ev_mkt_id
		and m.ev_oc_grp_id = g.ev_oc_grp_id
		and s.ev_id        = e.ev_id

		union

		select
			c.cust_id,
			c.username,
			a.ccy_code,
			b.call_id,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.winnings,
			b.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			m.desc_1 ev_name,
			m.desc_2 mkt_name,
			m.desc_3 seln_name,
			'-' result,
			0 ev_mkt_id,
			0 ev_oc_id,
			0 ev_id,
			m.bet_id,
			1 leg_no,
			1 part_no,
			'--' leg_sort,
			'L' price_type,
			'' o_num,
			'' o_den,
			"M" as odds_type
		from
			tBet b,
			tManOBet m,
			tAcct a,
			tCustomer c,
			tCall l
		where
			b.call_id  = ?
		and	b.call_id  = l.call_id
		and l.acct_id  = b.acct_id
		and b.cr_date  > l.start_time
		and b.bet_id   = m.bet_id
		and b.acct_id  = a.acct_id
		and a.cust_id  = c.cust_id
		and b.bet_type = 'MAN'

		union

		select
			c.cust_id,
			c.username,
			a.ccy_code,
			s.call_id,
			s.cr_date,
			""||s.xgame_sub_id as receipt,
			b.stake,
			s.status,
			b.settled,
			b.winnings,
			b.refund,
			1 as num_lines,
			"XGAME" as bet_type,
			"-" as leg_type,
			d.name as ev_name,
			dd.desc as mkt_name,
			b.picks as seln_name,
			"-" as  result,
			0 as ev_mkt_id,
			0 as ev_oc_id,
			0 as ev_id,
			b.xgame_sub_id as bet_id,
			1 as leg_no,
			1 as part_no,
			"--" as leg_sort,
			"S" as price_type,
			"",
			"",
			"X" as odds_type
		from
			tXGameSub s,
			tXGameBet b,
			tXGame g,
			tXGameDef d,
			tXGameDrawDesc dd,
			tXGamePrice p,
			tAcct a,
			tCustomer c,
			tCall l
		where
			s.call_id 			= ?
			and l.call_id       = s.call_id
			and l.acct_id       = s.acct_id
			and s.cr_date       > l.start_time
			and s.acct_id 		= a.acct_id
			and a.cust_id 		= c.cust_id
			and b.xgame_sub_id 	= s.xgame_sub_id
			and b.xgame_id		= g.xgame_id
			and g.sort 			= d.sort
			and g.draw_desc_id 	= dd.desc_id
			and g.sort 			= p.sort
			and p.num_picks 	= 1+length(s.picks)-length(replace(s.picks,"|",""))

	order by
		22 desc, 23 asc, 24 asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $call_id $call_id $call_id $call_id]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set bet_type {}
	set cur_id 0
	set b -1
	catch {
		unset BET
	}
	array set BET [list]

	for {set r 0} {$r < $rows} {incr r} {

		set call_id [db_get_col $res $r call_id]
		set bet_id  [db_get_col $res $r bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set l 0
			incr b
			set BET($b,num_selns) 0
		}
		incr BET($b,num_selns)

		if {$l == 0} {
			set bet_type [db_get_col $res $r bet_type]
			if {$bet_type == "MAN"} {
				set man_bet 1
			} else {
				set man_bet 0
			}
			if {$bet_type == "XGAME"} {
				set xgame_bet 1
			} else {
				set xgame_bet 0
			}

			set BET($b,bet_type)  $bet_type
			set BET($b,bet_id)    $bet_id
			set BET($b,receipt)   [db_get_col $res $r receipt]
			set BET($b,bet_time)  [db_get_col $res $r cr_date]
			set BET($b,leg_type)  [db_get_col $res $r leg_type]
			set BET($b,stake)     [db_get_col $res $r stake]
			set BET($b,ccy)       [db_get_col $res $r ccy_code]
			set BET($b,cust_id)   [db_get_col $res $r cust_id]
			set BET($b,cust_name) [db_get_col $res $r username]
			set BET($b,status)    [db_get_col $res $r status]
			set BET($b,settled)   [db_get_col $res $r settled]
			set BET($b,winnings)  [db_get_col $res $r winnings]
			set BET($b,refund)    [db_get_col $res $r refund]
			set BET($b,odds_type) [db_get_col $res $r odds_type]
		}

		set price_type [db_get_col $res $r price_type]

		if {$price_type == "L" || $price_type == "S"} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			if {$o_num=="" || $o_den==""} {
				set p_str "-"
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str "SP"
				}
			}
		} else {
			set p_str "DIV"
		}
		set BET($b,$l,price)     $p_str
		set BET($b,$l,man_bet)   $man_bet
		set BET($b,$l,xgame_bet) $xgame_bet
		set BET($b,$l,leg_sort)  [db_get_col $res $r leg_sort]
		set BET($b,$l,leg_no)    [db_get_col $res $r leg_no]
		set ev_name              [string trim [db_get_col $res $r ev_name]]
		if {$man_bet==0} {
			set BET($b,$l,event)     $ev_name
			set BET($b,$l,mkt)       [db_get_col $res $r mkt_name]
			set BET($b,$l,seln)      [db_get_col $res $r seln_name]
			set BET($b,$l,result)    [db_get_col $res $r result]
			set BET($b,$l,ev_id)     [db_get_col $res $r ev_id]
			set BET($b,$l,ev_mkt_id) [db_get_col $res $r ev_mkt_id]
			set BET($b,$l,ev_oc_id)  [db_get_col $res $r ev_oc_id]
		} else {
			set BET($b,$l,event)     [string range $ev_name  0 25]
			set BET($b,$l,mkt)       [string range $ev_name 26 51]
			set BET($b,$l,seln)      [string range $ev_name 52 77]
			set BET($b,$l,result)    "-"
		}
		incr l
	}
	if {$bet_type=="XGAME"} {
		set BET($b,num_selns) 1
	}

	tpSetVar NumBets [expr {$b+1}]

	tpBindVar CustId      BET cust_id   bet_idx
	tpBindVar CustName    BET cust_name bet_idx
	tpBindVar BetId       BET bet_id    bet_idx
	tpBindVar BetReceipt  BET receipt   bet_idx
	tpBindVar Manual      BET manual    bet_idx
	tpBindVar BetTime     BET bet_time  bet_idx
	tpBindVar BetSettled  BET settled   bet_idx
	tpBindVar BetType     BET bet_type  bet_idx
	tpBindVar LegType     BET leg_type  bet_idx
	tpBindVar BetCCY      BET ccy       bet_idx
	tpBindVar BetStake    BET stake     bet_idx
	tpBindVar Winnings    BET winnings  bet_idx
	tpBindVar Refund      BET refund    bet_idx
	tpBindVar OddsType    BET odds_type bet_idx
	tpBindVar BetLegNo    BET leg_no    bet_idx seln_idx
	tpBindVar BetLegSort  BET leg_sort  bet_idx seln_idx
	tpBindVar EvDesc      BET event     bet_idx seln_idx
	tpBindVar MktDesc     BET mkt       bet_idx seln_idx
	tpBindVar SelnDesc    BET seln      bet_idx seln_idx
	tpBindVar Price       BET price     bet_idx seln_idx
	tpBindVar Result      BET result    bet_idx seln_idx
	tpBindVar EvId        BET ev_id     bet_idx seln_idx
	tpBindVar EvMktId     BET ev_mkt_id bet_idx seln_idx
	tpBindVar EvOcId      BET ev_oc_id  bet_idx seln_idx

	db_close $res

	set sql {
		select
			'BET' ref_key,
			o.ref_id
		from
			tBet b,
			outer tOverride o
		where
			b.call_id = ?
		and	b.bet_id = o.ref_id
		and	o.ref_key = 'BET'

		union all

		select
			'XGAM' ref_key,
			o.ref_id
		from
			tXgameSub x,
			outer tOverride o
		where
			x.call_id = ?
		and	x.xgame_sub_id = o.ref_id
		and	o.ref_key = 'XGAM'

		union all

		select
			'POOL' ref_key,
			o.ref_id
		from
			tPoolBet b,
			outer tOverride o
		where
			b.call_id = ?
		and	b.pool_bet_id = o.ref_id
		and	o.ref_key = 'POOL'

		order by 1,2
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $call_id $call_id $call_id]
	inf_close_stmt $stmt

	set override_bets [list]
	set override_key  [list]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		set ref_id [db_get_col $res $r ref_id]
		if {$ref_id != ""} {
			lappend override_bets $ref_id
		}

		set BET($r,RefKey) [db_get_col $res $r ref_key]
	}

	for {set b 0} {$b < [tpGetVar NumBets]} {incr b} {
		set overrideset [lsearch $override_bets $BET($b,bet_id)]
		if { $overrideset == -1} {
			set BET($b,override) N
		} else {
			set BET($b,override) Y
		}
	}

	tpBindVar Override BET override bet_idx
	tpBindVar RefKey   BET RefKey   bet_idx

	db_close $res
}

proc bind_call_pmts {call_id} {

	global DB DATA

	set sql {
		select
			c.username,
			c.acct_no,
			c.cust_id,
			a.acct_id,
			a.ccy_code,
			p.pmt_id,
			p.cr_date,
			p.source,
			p.settled_by,
			p.oper_id,
			p.payment_sort,
			p.amount,
			p.commission,
			p.status,
			p.ipaddr,
			p.call_id,
			m.pay_mthd,
			m.desc,
			pc.ref_no
		from
			tPmt p,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tCustPayMthd cpm,
			tPayMthd m,
		outer
			tPmtCC pc
		where
			p.pmt_id     = pc.pmt_id
		and p.acct_id    = a.acct_id
		and a.cust_id    = c.cust_id
		and a.cust_id    = r.cust_id
		and c.cust_id    = r.cust_id
		and p.cpm_id     = cpm.cpm_id
		and cpm.pay_mthd = m.pay_mthd
		and p.call_id = ?
		order by
			p.pmt_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $call_id]
	inf_close_stmt $stmt

	tpSetVar NumPmts [set NumPmts [db_get_nrows $res]]

	array set DATA [list]

	for {set r 0} {$r < $NumPmts} {incr r} {
		set DATA($r,acct_no) [acct_no_enc  [db_get_col $res $r acct_no]]
	}


	tpBindTcl CustId      sb_res_data $res pmt_idx cust_id
	tpBindTcl Username    sb_res_data $res pmt_idx username
	tpBindTcl Date        sb_res_data $res pmt_idx cr_date
	tpBindTcl CCYCode     sb_res_data $res pmt_idx ccy_code
	tpBindTcl PmtSource   sb_res_data $res pmt_idx source
	tpBindTcl PmtStatus   sb_res_data $res pmt_idx status
	tpBindTcl PmtSort     sb_res_data $res pmt_idx payment_sort
	tpBindTcl Amount      sb_res_data $res pmt_idx amount
	tpBindTcl Commission  sb_res_data $res pmt_idx commission
	tpBindTcl Desc        sb_res_data $res pmt_idx desc
	tpBindTcl pmt_id      sb_res_data $res pmt_idx pmt_id
	tpBindTcl PmtMthd     sb_res_data $res pmt_idx pay_mthd
	tpBindTcl AcctNo      sb_res_data $res pmt_idx acct_no
	tpBindTcl RefNo       sb_res_data $res pmt_idx ref_no

}

}
