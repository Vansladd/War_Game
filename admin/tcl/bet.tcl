# ==============================================================
# $Id: bet.tcl,v 1.1.1.1.2.1 2012/02/29 09:15:50 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BET {

asSetAct ADMIN::BET::GoBetQuery             [namespace code go_bet_query]
asSetAct ADMIN::BET::DoBetQuery             [namespace code do_bet_query]
asSetAct ADMIN::BET::DoManualBetDesc        [namespace code do_manual_bet_desc]
asSetAct ADMIN::BET::GoManualBetDescUpd     [namespace code go_manual_bet_desc_upd]
asSetAct ADMIN::BET::DoStlPendQuery         [namespace code do_stl_pend_query]
asSetAct ADMIN::BET::GoBetReceipt           [namespace code go_bet_receipt]
asSetAct ADMIN::BET::GoPoolsReceipt         [namespace code go_pools_receipt]
asSetAct ADMIN::BET::GoXGameReceipt         [namespace code go_xgame_receipt]
asSetAct ADMIN::BET::GoXGame                [namespace code go_xgame_all_bets]
asSetAct ADMIN::BET::GoXGameSub             [namespace code go_xgame_sub_query]
asSetAct ADMIN::BET::DoXGameSubVoid         [namespace code do_xgame_sub_void]
asSetAct ADMIN::BET::DoXGameBetVoid         [namespace code do_xgame_bet_void]
asSetAct ADMIN::BET::DoManualSettle         [namespace code do_manual_settle]
asSetAct ADMIN::BET::DoPoolsManualSettle    [namespace code do_pools_manual_settle]
asSetAct ADMIN::BET::DoXGameManualSettle    [namespace code do_xgame_manual_settle]
asSetAct ADMIN::BET::DoRetroBet             [namespace code do_retro_bet]
asSetAct ADMIN::BET::DoXGRetroBet           [namespace code do_retro_xgame_bet]
asSetAct ADMIN::BET::DoRetroOverBet         [namespace code do_retro_over_bet]
asSetAct ADMIN::BET::DoRetroOverXGameBet    [namespace code do_retro_over_xgame_bet]
asSetAct ADMIN::BET::DoStlRetroBet          [namespace code do_stl_retro_bet]
asSetAct ADMIN::BET::DoStlRetroXGBet        [namespace code do_stl_retro_xgame_bet]
asSetAct ADMIN::BET::DoManualBetQuery       [namespace code do_manual_bet_query]
asSetAct ADMIN::BET::PayForAP               [namespace code pay_for_antepost_bet]
asSetAct ADMIN::BET::GetParkedXGBets        [namespace code get_parked_xgamebets]
asSetAct ADMIN::BET::DoPoolsRetroOverBet    [namespace code do_retro_over_bet_pools]
asSetAct ADMIN::BET::DoXGameRetroOverBet    [namespace code do_retro_over_bet_xgames]
asSetAct ADMIN::BET::DoCustUstlBetQuery     [namespace code do_cust_ustl_bet_query]
asSetAct ADMIN::BET::DoHedgeFieldBetQuery   [namespace code do_hf_bet_query]
asSetAct ADMIN::BET::GoCancelAllBetsForCust [namespace code do_cust_ustl_bet_query]
asSetAct ADMIN::BET::DoCancelAllBetsForCust [namespace code do_cancel_all_bets_for_cust]


#
# ----------------------------------------------------------------------------
# Generate bet selection criteria
# ----------------------------------------------------------------------------
#
proc go_bet_query {{query_type ""}} {

	global BETTYPE BET_CHANNELS RETRO_CHAN
	global DB

	# if there was a param passed in the request, get it and set it appropriately
	foreach param {
		AcctNo
	} {
		tpBindString $param [reqGetArg $param]
		ob_log::write DEBUG {Fetching param $param: value "[tpBindGet $param]"}
	}

	# Get a list of all the channels
	set channel_grps ""
	if {[OT_CfgGet HIDE_HEDG_FIEL 0]} {
		set channel_grps " and channel_grp <> 'HEDG' and channel_grp <> 'FIEL'"
	} elseif {[OT_CfgGet ON_COURSE_BETTING 0]} {
		set channel_grps " and channel_grp <> 'HEDG' "
	}


	if {[OT_CfgGet USE_SITE_OPERATOR 0]} {
		# don't get hedging channels
		set sql [subst {
			select c.channel_id, c.desc
			from tchannel c, tchangrplink cgl
			where c.channel_id = cgl.channel_id
			$channel_grps
		}]
	} else {
		set sql [subst {
			select channel_id, desc
			from tchannel
		}]
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set BET_CHANNELS($i,id) [db_get_col $res $i channel_id]
		set BET_CHANNELS($i,desc) [db_get_col $res $i desc]
	}

	set BET_CHANNELS(NumBetChannels) $nrows

	tpBindVar BetChannel        BET_CHANNELS id   bc_idx
	tpBindVar BetChannelDesc    BET_CHANNELS desc bc_idx

	db_close $res

	# Get channels for retro search (from config file)

	array set retro_channels [OT_CfgGet RETRO_CHANNEL ""]
	if {[array size retro_channels] > 0} {
		set RETRO_CHAN(0,code) "All"
		set RETRO_CHAN(0,name) "All"
		set idx 1
		foreach {code name} [array get retro_channels] {
			set RETRO_CHAN($idx,code) $code
			set RETRO_CHAN($idx,name) $name
			incr idx
		}

		set RETRO_CHAN(num) $idx
		unset idx

		# the one letter code, the name of the contact method
		tpBindVar retro_chan_code	RETRO_CHAN code	retro_chan_idx
		tpBindVar retro_chan_name	RETRO_CHAN name	retro_chan_idx
	}
	array unset retro_channels

	# Are we dislaying Sports, XGames or Pools?
	if {$query_type==""} {
		set query_type [reqGetArg type]
	}

	# Hmm, we should have a sensible default here
	if {$query_type == ""} {
		# still nothing?
		set query_type "sports"
	}

	tpSetVar QUERY_TYPE $query_type

	if {$query_type == "sports" || $query_type == "birfail"} {

		# Bind Game type?

		set nrows [get_bet_types 1]

		tpSetVar  bet_type_rows $nrows

		tpBindVar  BetType BETTYPE bet_type   bet_type_idx
		tpBindVar  BetName BETTYPE xl         bet_type_idx

		if {$query_type != "birfail"} {

			# Get the pending bets stake threshold
			set sql [subst {
				select
				stl_pay_limit
				from
				tControl
			}]

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt]

			inf_close_stmt $stmt

			tpBindString WinThresh [db_get_col $res 0 stl_pay_limit]
			db_close $res

			set sql {
				select
					ev_class_id,
					name
				from
					tevclass
				order by
					name
			}

			set classstmt [inf_prep_sql $DB $sql]
			set classres [inf_exec_stmt $classstmt]

			inf_close_stmt $classstmt

			tpSetVar class_rows [db_get_nrows $classres]

			tpBindTcl EvClassName sb_res_data $classres class_name_idx name
			tpBindTcl EvClassId sb_res_data $classres class_name_idx ev_class_id
		}

	} elseif {$query_type == "xgame"} {

		# Bind Game type?

		set sql [subst {
			select
				sort,
				name
			from
				tXGameDef
			order by
				name
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		tpSetVar bet_type_rows [db_get_nrows $res]

		tpBindTcl BetType sb_res_data $res bet_type_idx sort
		tpBindTcl BetName sb_res_data $res bet_type_idx name

	} elseif {$query_type == "pools" } {

		set sql {
			select
				t.pool_type_id,
				s.desc || " - " || t.name as pool_name
			from
				tPoolType t,
				tPoolSource s
			where
				t.pool_source_id = s.pool_source_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		tpSetVar pool_type_rows [db_get_nrows $res]

		tpBindTcl PoolType sb_res_data $res pool_type_idx pool_type_id
		tpBindTcl PoolName sb_res_data $res pool_type_idx pool_name

		# the appserver actually cleans up results sets now
		# but don't tell anybody

		# We should config which classes are pools bet classes
        # If not we will make an ugly ttempt to guess which
		# Classes and types are pools bettable.
		set pools_classes [OT_CfgGet POOLS_BET_CLASSES ""]
		if {$pools_classes != ""} {
			set sql [subst {
				select
					t.ev_type_id pool_meeting_id,
					t.name pool_meeting_name,
					t.displayed,
					t.disporder,
					upper(t.name) as uptname
				from
					tevtype t
				where
					t.ev_class_id in ($pools_classes)
				order by
					t.displayed desc,
					uptname asc
			}]
		} else {

			set sql {
				select
					t.ev_type_id pool_meeting_id,
					t.name pool_meeting_name,
					t.displayed,
					t.disporder,
					upper(t.name) as uptname
				from
					tevtype t,
					tevclass c
				where
					c.sort in ('HR', 'PL')
				and
					t.ev_class_id = c.ev_class_id
				order by
					t.displayed desc,
					uptname asc
			}
		}

		set stmt [inf_prep_sql $DB $sql]
		set res2 [inf_exec_stmt $stmt]

		tpSetVar pool_meeting_rows [db_get_nrows $res2]

		tpBindTcl MeetingType sb_res_data $res2 pool_meeting_idx pool_meeting_id
		tpBindTcl MeetingName sb_res_data $res2 pool_meeting_idx pool_meeting_name

	} elseif {$query_type == "iballs" } {

		# Get the game type id and names for the iBalls from the DB

		set sql {
			select
				s.type_id as game_type_id,
				s.desc as game_name
			from
				tBallsSubType s
			order by
				type_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		tpSetVar pool_type_rows [db_get_nrows $res]

		tpBindTcl GameType sb_res_data $res game_type_idx game_type_id
		tpBindTcl GameName sb_res_data $res game_type_idx game_name

	}

	asPlayFile -nocache bet_query.html

	catch {db_close $sportres}
	catch {unset BET_CHANNELS}
	catch {unset BETTYPE}
}

proc get_bet_types {{noPools 0}} {

	global DB BETTYPE
	if {$noPools == 1} {
		set sql [subst {
			select
				bet_type,
				bet_name,
				num_selns,
				bet_settlement,
				disporder
			from
				tBetType
			where
				bet_type not in ('DLEG', 'TLEG')
			order by
				disporder, num_selns
		}]
	} else {
		set sql [subst {
			select
				bet_type,
				bet_name,
				num_selns,
				bet_settlement,
				disporder
			from
				tBetType
			order by
				disporder, num_selns
		}]
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set bet_type                   [db_get_col $res $i bet_type]
		set BETTYPE($i,bet_type)       $bet_type
		set BETTYPE($i,xl_code)        BET_TYPE_NAME_$bet_type
		set BETTYPE($i,xl)             [ob_xl::sprintf [ob_xl_compat::get_lang] $BETTYPE($i,xl_code)]
		set bet_name                   [db_get_col $res $i bet_name]
		set bet_settlement             [db_get_col $res $i bet_settlement]
		set BETTYPE($bet_type,bet_settlement) $bet_settlement
		if { $bet_settlement == "Manual" } {
			set BETTYPE($i,bet_name) "* $bet_name"
		} else {
			set BETTYPE($i,bet_name) $bet_name
		}
	}

	db_close $res
	return $nrows
}


# Search for a customer's unsettled bets.
proc do_cust_ustl_bet_query args {

	reqSetArg BetDate2 [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	reqSetArg Settled  N

	ob_log::write DEBUG {do_cust_ustl_bet_query}

	set cust_id              [reqGetArg CustId]
	set show_cancel_all_bets [reqGetArg ShowCancelAllBets]

	foreach {n v} $args {
		set $n $v
	}

	ob_log::write DEV {CustId = $cust_id, ShowCancelAllBets = $show_cancel_all_bets }

	if {$show_cancel_all_bets == 1
	     && [op_allowed CancelAllBetsForCust]
	} {
		tpSetVar     ShowCancelAllBets  1
		tpBindString Cust_Id            $cust_id

	} else {
		tpSetVar ShowCancelAllBets  0
	}

	do_bet_query specific_cust_id $cust_id
}


#
# ----------------------------------------------------------------------------
# Bet search
# ----------------------------------------------------------------------------
#
proc do_bet_query args {


}

proc get_parked_xgamebets args {
	global DB XG_BET

	if {[info exists XG_BET]} {
		unset XG_BET
	}

	OT_LogWrite 1 "Find Parked XG Bets"

	set where        [list]
	set where_clause ""

	#
	# Bet "park" date fields
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]


	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
		lappend where [mk_between_clause b.cr_date date $bd1 $bd2]
	}

	set thresh [reqGetArg WinThresh]
	if {[string length $thresh] > 0} {
		lappend where "p.winnings >= $thresh"
	}

	if {[llength $where]} {
		set where_clause [concat and [join $where " and "]]
	}

	set sql [subst {
			select
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
				p.winnings,
				p.refund,
				g.comp_no,
				s.num_subs,
				s.picks,
				NVL(g.results,'-') as results,
				d.num_picks_max,
				d.sort,
				d.name,
				p.num_lines_win,
				p.num_lines_lose,
				p.num_lines_void
			from
				tAcct a,
				tCustomer c,
				tXGameSub s,
				tXGameBet b,
				tXGame g,
				tXGameDef d,
				tXGBetStlPending p
			where
				a.cust_id = c.cust_id and
				a.acct_id = s.acct_id and
				s.xgame_sub_id = b.xgame_sub_id and
				b.xgame_id = g.xgame_id and
				g.sort = d.sort and
				p.xgame_bet_id = b.xgame_bet_id and
				a.owner <> 'D'
				$where_clause
	}]

	#OT_LogWrite 1 "$sql"

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	for {set r 0} {$r < $rows} {incr r} {
		set XG_BET($r,xgame_sub_id)   [db_get_col $res $r xgame_sub_id]
		set XG_BET($r,xgame_bet_id)   [db_get_col $res $r xgame_bet_id]
		set XG_BET($r,username)       [db_get_col $res $r username]
		set XG_BET($r,acct_no)        [db_get_col $res $r acct_no]
		set XG_BET($r,cr_date)        [db_get_col $res $r cr_date]
		set XG_BET($r,settled)        [db_get_col $res $r settled]
		set XG_BET($r,sort)           [db_get_col $res $r sort]
		set XG_BET($r,ccy_code)       [db_get_col $res $r ccy_code]
		set XG_BET($r,cust_id)        [db_get_col $res $r cust_id]
		set XG_BET($r,stake)          [db_get_col $res $r stake]
		set XG_BET($r,winnings)       [db_get_col $res $r winnings]
		set XG_BET($r,refund)         [db_get_col $res $r refund]
		set XG_BET($r,comp_no)        [db_get_col $res $r comp_no]
		set XG_BET($r,num_subs)       [db_get_col $res $r num_subs]
		set XG_BET($r,picks)          [db_get_col $res $r picks]
		set XG_BET($r,results)        [db_get_col $res $r results]
		set XG_BET($r,num_picks_max)  [db_get_col $res $r num_picks_max]
		set XG_BET($r,sort)           [db_get_col $res $r sort]
		set XG_BET($r,name)           [db_get_col $res $r name]
		set XG_BET($r,num_lines_win)  [db_get_col $res $r num_lines_win]
		set XG_BET($r,num_lines_lose) [db_get_col $res $r num_lines_lose]
		set XG_BET($r,num_lines_void) [db_get_col $res $r num_lines_void]
	}

	db_close $res

	tpSetVar NumBets $rows

	#OT_LogWrite 1 "ROWS: $rows"

	tpBindVar xgame_sub_id   XG_BET xgame_sub_id   xg_bet_idx
	tpBindVar xgame_bet_id   XG_BET xgame_bet_id   xg_bet_idx
	tpBindVar username       XG_BET username       xg_bet_idx
	tpBindVar acct_no        XG_BET acct_no        xg_bet_idx
	tpBindVar cr_date        XG_BET cr_date        xg_bet_idx
	tpBindVar settled        XG_BET settled        xg_bet_idx
	tpBindVar sort           XG_BET sort           xg_bet_idx
	tpBindVar ccy_code       XG_BET ccy_code       xg_bet_idx
	tpBindVar cust_id        XG_BET cust_id        xg_bet_idx
	tpBindVar stake          XG_BET stake          xg_bet_idx
	tpBindVar winnings       XG_BET winnings       xg_bet_idx
	tpBindVar refund         XG_BET refund         xg_bet_idx
	tpBindVar comp_no        XG_BET comp_no        xg_bet_idx
	tpBindVar num_subs       XG_BET num_subs       xg_bet_idx
	tpBindVar picks          XG_BET picks          xg_bet_idx
	tpBindVar results        XG_BET results        xg_bet_idx
	tpBindVar num_picks_max  XG_BET num_picks_max  xg_bet_idx
	tpBindVar sort           XG_BET sort           xg_bet_idx
	tpBindVar name           XG_BET name           xg_bet_idx
	tpBindVar num_lines_win  XG_BET num_lines_win  xg_bet_idx
	tpBindVar num_lines_lose XG_BET num_lines_lose xg_bet_idx
	tpBindVar num_lines_void XG_BET num_lines_void xg_bet_idx

	asPlayFile -nocache parked_xgame_bets.html

}

#
# ----------------------------------------------------------------------------
# Get "parked" bets...
# ----------------------------------------------------------------------------
#
proc do_stl_pend_query args {

	global DB BET

	set query_type [reqGetArg  QueryType]
	OT_LogWrite 1 "Find Parked Bets: query_type=$query_type"
	if {$query_type == "pools"} {
		do_pool_stl_pend_query $args
		return
	}

	set where        [list]
	set where_clause ""

	set bad 0

	#
	# Bet "park" date fields
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]


	tpSetVar QUERY_TYPE $query_type


	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
		lappend where [mk_between_clause p.cr_date date $bd1 $bd2]
	}

	set thresh [reqGetArg WinThresh]
	if {[string length $thresh] > 0} {
		lappend where "p.winnings >= $thresh"
	}

	if {[llength $where]} {
		set where_clause [concat and [join $where " and "]]
	}

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			p.winnings,
			p.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			e.desc ev_name,
			m.name mkt_name,
			s.desc seln_name,
			s.result,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			b.bet_id,
			o.leg_no,
			o.part_no,
			o.leg_sort,
			o.price_type,
			o.o_num o_num,
			o.o_den o_den,
			case when
			(
				   (NVL(e.suspend_at,e.start_time) < b.cr_date and o.in_running == "N")
			)
			then 'Y' else 'N' end late,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBetStlPending p,
			tBet b,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer (
				tOBet o,
				tEvOc s,
				tEvMkt m,
				tEvOcGrp g,
				tEv e
			),
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
		where
			p.bet_id = b.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id and
			b.bet_id = o.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			a.owner <> 'Y' and
			a.owner <> 'D' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
			$where_clause
		order by
			b.bet_id desc,
			o.leg_no asc,
			o.part_no asc
	}]

	OT_LogWrite 1 "do_stl_pend_query: sql=$sql"
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows == 1 && [db_get_col $res 0 bet_type] != "MAN"} {
		OT_LogWrite 1 "do_stl_pend_query: issuing data for bet_id=[db_get_col $res 0 bet_id]"
		go_bet_receipt bet_id [db_get_col $res 0 bet_id]
		db_close $res
		return
	}

	if {[OT_CfgGet ENABLE_LATE_BET_TOL_RULE 0]} {
		OT_LogWrite 1 "do_stl_pend_query: ENABLE_LATE_BET_TOL_RULE, setting LateBets=1"
		tpSetVar LateBets 1
	}

	bind_sports_bet_list $res 0 1


	asPlayFile -nocache bet_list.html

	db_close $res

	unset BET
}

#
# ----------------------------------------------------------------------------
# Get "parked" Pools bets...
# ----------------------------------------------------------------------------
#
proc do_pool_stl_pend_query args {

	global DB POOL_BET

	OT_LogWrite 1 "Find Parked pools Bets"

	set where        [list]
	set where_clause ""

	set bad 0

	#
	# Bet "park" date fields
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]

	set query_type [reqGetArg  QueryType]

	tpSetVar QUERY_TYPE $query_type


	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
		lappend where [mk_between_clause p.cr_date date $bd1 $bd2]
	}

	set thresh [reqGetArg WinThresh]
	if {[string length $thresh] > 0} {
		lappend where "p.winnings >= $thresh"
	}

	if {[llength $where]} {
		set where_clause [concat and [join $where " and "]]
	}

	OT_LogWrite 1 "Find Parked pools Bets where:$where_clause"
	set sql [subst {
		select
		b.pool_bet_id,
		c.cust_id,
		c.username,
		c.acct_no,
		c.elite,
		a.ccy_code,
		b.cr_date,
		b.receipt,
		b.ccy_stake,
		b.stake,
		b.status,
		b.settled,
		p.winnings,
		b.refund,
		b.num_lines,
		(b.stake / b.num_lines) unitstake,
		b.bet_type,
		e.desc ev_name,
		t.name meeting_name,
		s.desc seln_name,
		s.result,
		s.ev_oc_id,
		s.ev_id,
		pb.leg_no,
		pb.part_no,
		po.pool_id,
		po.pool_type_id,
		po.rec_dividend,
		po.result_conf pool_conf,
		pt.name as pool_name,
		ps.ccy_code as pool_ccy_code
		from
		tPoolBet b,
		tPBet pb,
		tAcct a,
		tCustomer c,
		tEvOc s,
		tEvMkt m,
		tEv e,
		tEvType t,
		tCustomerReg r,
		tPool po,
		tPoolType pt,
		tPoolSource ps,
		tPoolBetStlPending p
		where
		b.pool_bet_id = pb.pool_bet_id and
		b.pool_bet_id = p.pool_bet_id and
		b.acct_id = a.acct_id and
		a.cust_id = c.cust_id and
		r.cust_id = c.cust_id and
		pb.ev_oc_id = s.ev_oc_id and
		s.ev_mkt_id = m.ev_mkt_id and
		s.ev_id = e.ev_id and
		t.ev_type_id = e.ev_type_id and
		pb.pool_id = po.pool_id and
		po.pool_type_id = pt.pool_type_id and
		po.pool_source_id = pt.pool_source_id and
		pt.pool_source_id = ps.pool_source_id
		$where_clause
		order by 1 desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	OT_LogWrite 1 "Find Parked pools Bets:Found $rows Rows"
	bind_pools_bet_list $res


	asPlayFile -nocache pool_bet_list.html

	db_close $res

	unset POOL_BET

}
#
# ----------------------------------------------------------------------------
# Get manual bet description
# ----------------------------------------------------------------------------
#
proc do_manual_bet_desc args {

	global DB

	set req_type [reqGetArg SR_type]
	if {$req_type=="FromPmt"} {
		tpSetVar FromPmt 1
		foreach f {SR_username SR_upper_username SR_fname SR_lname SR_email \
					SR_acct_no_exact SR_acct_no SR_date_1 SR_date_2 \
					SR_date_range SR_status SR_payment_sort SR_channel \
					SR_pay_mthd} {
			tpBindString $f [reqGetArg $f]
		}
	} else {
		foreach f {SR_UseSub SR_Customer SR_UpperCust SR_FName SR_LName \
			SR_Email SR_AcctNo SR_Receipt SR_CompNo SR_BetDate1 SR_BetDate2 \
			SR_StlDate1 SR_StlDate2 SR_Stake1 SR_Stake2 SR_Wins1 SR_Wins2 \
			SR_Settled SR_BetTypeOp SR_BetType SR_Manual SR_GameType SR_BetPlacedFrom} {
			tpBindString $f [reqGetArg $f]
		}
	}

	tpBindString BatchRefId [reqGetArg batch_ref_id]
	tpBindString ManOnly    [reqGetArg man_only]

	set bet_id [reqGetArg BetId]
	set sql [subst {
		   select
				m.desc_1,
				m.desc_2,
				m.desc_3,
				m.desc_4,
				to_settle_at,
				m.temp_desc_1,
				m.temp_desc_2,
				m.temp_desc_3,
				m.temp_desc_4,
				m.ev_class_id,
				m.ev_type_id
			 from
			 	tBet b,
				tManOBet m
			where
				b.bet_id = ? and
				b.bet_id = m.bet_id
		}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set desc         "[db_get_col $res 0 desc_1] [db_get_col $res 0 desc_2] [db_get_col $res 0 desc_3] [db_get_col $res 0 desc_4]"
	set temp_desc    "[db_get_col $res 0 temp_desc_1] [db_get_col $res 0 temp_desc_2] [db_get_col $res 0 temp_desc_3] [db_get_col $res 0 temp_desc_4]"

	set man_ev_class_id [db_get_col $res 0 ev_class_id]
	set man_ev_type_id [db_get_col $res 0 ev_type_id]

	tpBindString BetId      $bet_id
	tpBindString Desc       $desc
	tpBindString TempDesc   $temp_desc
	tpBindString ToSettleAt [string range [db_get_col $res 0 to_settle_at] 0 9]
	db_close $res

	do_man_event_desc $man_ev_class_id $man_ev_type_id

	asPlayFile -nocache bet_man_desc.html
}

#
# ----------------------------------------------------------------------------
# Get the event class and event type information for allowing the manual bet
# to be associated with an event [LBR079]
# ----------------------------------------------------------------------------
#
proc do_man_event_desc {man_ev_class_id man_ev_type_id} {
	global DB
	global DATA

	set evclass_sql {
		select
			ev_class_id,
			name,
			upper(name) as uname
		from
			tEvClass
		where
			status='A' and
			displayed = 'Y'
		order by uname
	}

	set stmt [inf_prep_sql $DB $evclass_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	tpSetVar NumEvClass [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set evclass [db_get_col $res $r name]
		set evclassid [db_get_col $res $r ev_class_id]
		set DATA($r,evclass)   $evclass
		set DATA($r,evclassid)   $evclassid
	}
	tpBindVar EvClass      DATA evclass         evclass_idx
	tpBindVar EvClassId    DATA evclassid       evclass_idx

	if {$man_ev_class_id == ""} {set man_ev_class_id 0}
	tpBindString EvClassSel   $man_ev_class_id

	# At the moment, for LBR079, types are only displayed for horse races..
	set evtype_sql {
		select
			t.ev_type_id,
			t.ev_class_id,
			t.name,
			upper(t.name) as uname
		from
			tEvType t,
			tEvClass c
		where
			c.ev_class_id = t.ev_class_id and
			c.sort = 'HR' and
			t.status = 'A' and
			t.displayed = 'Y'
		order by uname
	}

	set stmt [inf_prep_sql $DB $evtype_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	tpSetVar NumEvType [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set evtype [db_get_col $res $r name]
		set evtypeid [db_get_col $res $r ev_type_id]
		set evtypeclassid [db_get_col $res $r ev_class_id]
		set DATA($r,evtype)   	   $evtype
		set DATA($r,evtypeid)      $evtypeid
		set DATA($r,evtypeclassid) $evtypeclassid
	}
	tpBindVar EvType        DATA evtype          evtype_idx
	tpBindVar EvTypeId      DATA evtypeid        evtype_idx
	tpBindVar EvTypeClassId DATA evtypeclassid   evtype_idx
	tpBindString EvTypeSel   	$man_ev_type_id

}


#
# ----------------------------------------------------------------------------
# Update manual bet description
# ----------------------------------------------------------------------------
#
proc go_manual_bet_desc_upd args {

	global DB

	set action [reqGetArg SubmitName]
	if {$action == "Back"} {
		set req_type [reqGetArg SR_type]
		if {$req_type=="FromPmt"} {
			foreach f {SR_username SR_upper_username SR_fname SR_lname \
				SR_email SR_acct_no_exact SR_acct_no SR_date_1 SR_date_2 \
				SR_date_range SR_status SR_payment_sort SR_channel \
				SR_pay_mthd} {
				reqSetArg $f [reqGetArg $f]
			}
			ADMIN::PMT::do_pmt_query
			return
		} else {
			foreach f {SR_UseSub SR_Customer SR_UpperCust SR_FName SR_LName \
				SR_Email SR_AcctNo SR_Receipt SR_CompNo SR_BetDate1 SR_BetDate2 \
				SR_StlDate1 SR_StlDate2 SR_Stake1 SR_Stake2 SR_Wins1 SR_Wins2 \
				SR_Settled SR_BetTypeOp SR_BetType SR_Manual SR_GameType SR_BetPlacedFrom} {
				reqSetArg [string range $f 3 end] [reqGetArg $f]
			}

			reqSetArg ManBetOrd    [reqGetArg ManBetOrd]
			reqSetArg BetDate1     [reqGetArg BetDate1]
			reqSetArg BetDate2     [reqGetArg BetDate2]
			reqSetArg batch_ref_id [reqGetArg batch_ref_id]
			reqSetArg man_only     [reqGetArg man_only]

			do_manual_bet_query
			return
		}
	}

	set upd_desc     [reqGetArg current]
	set to_settle_at "[reqGetArg ToStlAt] 00:00:00"
	set bet_id       [reqGetArg BetId]
	set len [string length $upd_desc]
	set desc_1 ""
	set desc_2 ""
	set desc_3 ""
	set desc_4 ""

	set ev_class_id [reqGetArg evclassid]
	set ev_type_id  [reqGetArg evtypeid]

	#
	# The ev_class_id and ev_type_id are only passed from certain form configurations
	#
	if {[string is integer $ev_class_id] && \
	    [string is integer $ev_type_id]  && \
	    $ev_class_id != {} && \
	    $ev_type_id  != {}} {
		ob_log::write DEBUG {  UPDATING ev_class_id ($ev_class_id) and ev_type_id ($ev_type_id)}
		set upd_event_ids 1
		set sql_fields   {
			,ev_class_id = ?,
			ev_type_id   = ?
		}
	} else {
		ob_log::write DEBUG {  ** NOT updating ev_class_id ($ev_class_id) and ev_type_id ($ev_type_id)}
		set upd_event_ids 0
		set sql_fields   {}
	}

	if { $len != 0 } {
		if { $len > 255 } {
			append desc_1 [string range $upd_desc 0 254]
		} else {
			append desc_1 [string range $upd_desc 0 end]
		}
		if { $len > 255 && $len >= 509} {
			append desc_2 [string range $upd_desc 255 509]
		} else {
			append desc_2 [string range $upd_desc 255 end]
		}
		if { $len > 509 && $len >= 764} {
			append desc_3 [string range $upd_desc 510 764]
		} else {
			append desc_3 [string range $upd_desc 510 end]
		}
		if { $len > 764 && $len == 1019} {
			append desc_4 [string range $upd_desc 765 1019]
		} else {
			append desc_4 [string range $upd_desc 765 end]
		}
	}
	set sql [subst {
		update tManOBet set
			desc_1 = ?,
			desc_2 = ?,
			desc_3 = ?,
			desc_4 = ?,
			to_settle_at = ?
			$sql_fields
		where
			bet_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set sqlquery [list inf_exec_stmt $stmt $desc_1 $desc_2 $desc_3 $desc_4 $to_settle_at]
	if {$upd_event_ids} {
		lappend sqlquery $ev_class_id $ev_type_id
	}
	lappend sqlquery $bet_id

	set res  [eval [concat $sqlquery]]

	inf_close_stmt $stmt

	tpSetVar     DescUpd 1

	set next_action [reqGetArg NextAction]
	if { [OT_CfgGet NO_UNVETTED_BET_DESCRIPTION 0] && \
		 $next_action == "ADMIN::BET::GoBetReceipt"} {
		go_bet_receipt
	} else {
		do_manual_bet_desc
	}
}


#
# ----------------------------------------------------------------------------
# Create appropriate bindings for sports bet list
# ----------------------------------------------------------------------------
#
proc bind_sports_bet_list {res {manual_bet "0"} {include_oncourse_data "0"}} {

	global BET BETTYPE

	set rows [db_get_nrows $res]

	set cur_id 0
	set b -1

	array set BET [list]

	get_bet_types

	set elite 0

	set check_notifications_referrals 0
	set colnames [db_get_colnames $res]

	if {[OT_CfgGet FUNC_SHOP_FIELDING_ACCOUNTS 0]} {
		# Check if we have info on the shop bets about notifications and referrals
		# We need this check because many searches use this proc to bind the result data
		if {([lsearch $colnames is_shop_fielding_bet] != -1) &&
		    ([lsearch $colnames is_referral] != -1)} {
		    set check_notifications_referrals 1
		}
	}

	# Only some queries have this
	if {([lsearch $colnames hcap_value] != -1)} {
		set has_hcap 1
	} else {
		set has_hcap 0
	}


	for {set r 0} {$r < $rows} {incr r} {

		set bet_id [db_get_col $res $r bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set l 0
			if {[OT_CfgGet BF_ACTIVE 0]} {
				if {([reqGetArg BFPassThru] == "N") && [db_get_col $res $r bf_pass_bet_id] != ""} {
					continue
				} elseif {([reqGetArg BFRiskReduce] == "N") && [db_get_col $res $r bf_order_id] != ""} {
					continue
				}
			}
			incr b
			set BET($b,num_selns) 0
			set BET($b,late_bet) N
		}
		incr BET($b,num_selns)

		if {$l == 0} {
			set bet_type [db_get_col $res $r bet_type]

			if {$bet_type=="MAN"} {
				set man_bet 1
				tpSetVar ManBet 1
			} else {
				set man_bet 0
			}

			set BET($b,bet_id)         $bet_id
			set BET($b,receipt)        [db_get_col $res $r receipt]
			set BET($b,ipaddr)         [db_get_col $res $r ipaddr]
			set BET($b,bet_time)       [db_get_col $res $r cr_date]
			set BET($b,manual)         $man_bet
			set BET($b,bet_type)       $bet_type
			set BET($b,leg_type)       [db_get_col $res $r leg_type]
			set BET($b,stake)          [db_get_col $res $r stake]
			set BET($b,ccy)            [db_get_col $res $r ccy_code]
			set BET($b,cust_id)        [db_get_col $res $r cust_id]
			set BET($b,cust_name)      [db_get_col $res $r username]
			set BET($b,acct_no)        [db_get_col $res $r acct_no]
			set BET($b,elite)          [db_get_col $res $r elite]
			set BET($b,status)         [db_get_col $res $r status]
			set BET($b,settled)        [db_get_col $res $r settled]
			set BET($b,winnings)       [db_get_col $res $r winnings]
			set BET($b,refund)         [db_get_col $res $r refund]

                        if {[OT_CfgGet BF_ACTIVE 0]} {
                                set BET($b,bf_order_id)    [db_get_col $res $r bf_order_id]
                                set BET($b,bf_pass_bet_id) [db_get_col $res $r bf_pass_bet_id]
                        }

			# Bind up the rep_code and on_course_type if we're doing the fixed
			# odds bet query
			if {$include_oncourse_data && [OT_CfgGet FUNC_HYBRID_HEDGING 0]} {
				set BET($b,rep_code)       [db_get_col $res $r rep_code]
				set BET($b,on_course_type) [db_get_col $res $r on_course_type]

				# If this bet has been hedged, we need to reverse the stake, winnings
				# and refund values. Also need to set the course type.
				if {[db_get_col $res $r hedged_id] != ""} {
					set BET($b,stake) [format "%0.2f" [expr {$BET($b,stake) * -1}]]

					if {$BET($b,winnings) != 0} {
						set BET($b,winnings) [format "%0.2f" [expr {$BET($b,winnings) * -1}]]
					}

					if {$BET($b,refund) != 0} {
						set BET($b,refund)   [format "%0.2f" [expr {$BET($b,refund) * -1}]]
					}
				}
			}

			if {[tpGetVar UnstlManBet 0]==1} {
				set BET($b,ord_date) [string range [db_get_col $res $r ord_date] 0 9]
			}
			if {[db_get_col $res $r elite] == "Y"} {
				incr elite
			}

			if {$check_notifications_referrals} {
				set is_shop_fielding_bet [db_get_col $res $r is_shop_fielding_bet]
				set is_referral          [db_get_col $res $r is_referral]

				if {$is_shop_fielding_bet && $is_referral} {
					set BET($b,notif_ref) "R"
				} elseif {$is_shop_fielding_bet} {
					set BET($b,notif_ref) "N"
				} else {
					set BET($b,notif_ref) ""
				}
			}

		}

		if {[tpGetVar LateBets 0]==1 && [db_get_col $res $r late] == "Y"} {
			# Mark the bet as late if any of its selections are flagged as late
			set BET($b,late_bet) "Y"
		}

		set price_type [db_get_col $res $r price_type]

		if {[string first $price_type "LSBN12"] >= 0} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			if {$o_num=="" || $o_den==""} {
				set p_str [get_price_type_desc $price_type]
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str [get_price_type_desc $price_type]
				}
			}
		} else {
			if {$man_bet} {
				set p_str "MAN"
			} else {
				set p_str "DIV"
			}
		}

		if {[tpGetVar DispOrigPrice 0]} {
			set BET($b,$l,old_price)   [mk_price [db_get_col $res $r old_num] [db_get_col $res $r old_den]]
		}

		set BET($b,$l,price)      $p_str
		set BET($b,$l,leg_sort)   [db_get_col $res $r leg_sort]
		set BET($b,$l,leg_no)     [db_get_col $res $r leg_no]

		if {$has_hcap == 1} {
			set BET($b,$l,hcap_value) [db_get_col $res $r hcap_value]
		} else {
			set BET($b,$l,hcap_value) ""
		}

		#how are the legs combined - this info won't be available
		#for manual bets
		if {[catch {
			set no_combi  [db_get_col $res $r no_combi]
			set banker    [db_get_col $res $r banker]
		} msg]} {
			set combi "All"
			set banker "N"
			OT_LogWrite 1 {The results set passed to bet.tcl:bind_sports_bet_list does not contain no_combi or banker fields}
			OT_LogWrite 1 "Using defaults - combi=$combi; banker=$banker"
		} else {
			if {$banker == "Y"} {
				set combi "Banker"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != "" && $no_combi % 2 == 0} {
				set combi "Even"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != ""} {
				set combi "Odd"
				tpSetVar ShowCombiKey 1
			} else {
				set combi "All"
			}
		}
		set BET($b,$l,combi)  $combi
		set BET($b,$l,banker) $banker

		set BET($b,$l,man_bet)   $man_bet
		set ev_name              [string trim [db_get_col $res $r ev_name]]

		if {[OT_CfgGet BF_ACTIVE 0]} {
			# Pass Through Bets id is required for displaying
			tpBindVar BFPassThruBetId BET bf_pass_bet_id bet_idx

			# Betfair Order Id
			tpBindVar BFOrderId BET bf_order_id bet_idx
		}

		# Event class is required for manual bets
		if { $manual_bet==1 } {
			set BET($b,$l,ev_class_name)   [db_get_col $res $r ev_class_name]
		}

		if {$man_bet==0} {
			set BET($b,$l,event)     $ev_name
			set BET($b,$l,mkt)       [db_get_col $res $r mkt_name]
			set BET($b,$l,seln)      [db_get_col $res $r seln_name]
			set BET($b,$l,result)    [db_get_col $res $r result]
			set ev_id                [db_get_col $res $r ev_id]
			set ev_mkt_id            [db_get_col $res $r ev_mkt_id]
			set ev_oc_id             [db_get_col $res $r ev_oc_id]
			set BET($b,$l,ev_id)     [db_get_col $res $r ev_id]
			set BET($b,$l,ev_mkt_id) [db_get_col $res $r ev_mkt_id]
			set BET($b,$l,ev_oc_id)  [db_get_col $res $r ev_oc_id]
		} else {
			set BET($b,$l,event)     [string range $ev_name 0 25]
			set BET($b,$l,mkt)       [string range $ev_name 26 51]
			set BET($b,$l,seln)      [string range $ev_name 52 77]
			set BET($b,$l,result)    "-"
		}

		incr l
	}
	OT_LogWrite 1 "bind_sports_bet_list: number of bets processed=[expr {$b+1}]"
	tpSetVar NumBets [expr {$b+1}]
	tpSetVar IS_ELITE $elite
	tpBindVar CustId         BET cust_id        bet_idx
	tpBindVar CustName       BET cust_name      bet_idx
	tpBindVar AcctNo         BET acct_no        bet_idx
	tpBindVar Elite          BET elite          bet_idx
	tpBindVar BetId          BET bet_id         bet_idx
	tpBindVar BetReceipt     BET receipt        bet_idx
	tpBindVar IPaddr         BET ipaddr         bet_idx
	tpBindVar BetTime        BET bet_time       bet_idx
	tpBindVar Manual         BET manual         bet_idx
	tpBindVar BetSettled     BET settled        bet_idx
	tpBindVar BetType        BET bet_type       bet_idx
	tpBindVar LegType        BET leg_type       bet_idx
	tpBindVar BetCCY         BET ccy            bet_idx
	tpBindVar BetStake       BET stake          bet_idx
	tpBindVar Winnings       BET winnings       bet_idx
	tpBindVar Refund         BET refund         bet_idx
	tpBindVar OnCourseType   BET on_course_type bet_idx
	tpBindVar RepCode        BET rep_code       bet_idx

	# increase the colspan from default if we are showing any additional fields
	set col_span 19

	# if we're hiding usernames, decrease the col_span
	if {[OT_CfgGet FUNC_HIDE_USERNAMES 0]} {
		incr col_span -1
	}

	tpSetVar ChkNotifRef $check_notifications_referrals
	if {$check_notifications_referrals} {
		tpBindVar NotifRef BET notif_ref bet_idx
		incr col_span
	}

	if {[tpGetVar LateBets 0]==1} {
		tpBindVar Late        BET late_bet  bet_idx
		incr col_span
	}

	tpBindVar BetLegNo    BET leg_no     bet_idx seln_idx
	tpBindVar BetLegSort  BET leg_sort   bet_idx seln_idx
	tpBindVar BetCombi    BET combi      bet_idx seln_idx
	tpBindVar BetBanker   BET banker     bet_idx seln_idx
	tpBindVar EvDesc      BET event      bet_idx seln_idx
	tpBindVar MktDesc     BET mkt        bet_idx seln_idx
	tpBindVar SelnDesc    BET seln       bet_idx seln_idx
	tpBindVar Price       BET price      bet_idx seln_idx
	tpBindVar HcapValue   BET hcap_value bet_idx seln_idx
	tpBindVar Result      BET result     bet_idx seln_idx
	tpBindVar EvId        BET ev_id      bet_idx seln_idx
	tpBindVar EvMktId     BET ev_mkt_id  bet_idx seln_idx
	tpBindVar EvOcId      BET ev_oc_id   bet_idx seln_idx

	# Event class is required for manual bet
	if { $manual_bet==1 } {
		tpBindVar EventClass  BET ev_class_name   bet_idx seln_idx
	}

	# This functionality controls the number of columns in the bet_list page because in the case
	# of manual bets it shows the event class
	tpSetVar EventClassShown $manual_bet

	# increase the title colspan if we are showing the extra column
	if {$manual_bet} {
		incr col_span
	}

	tpSetVar ColSpan $col_span

	if {[tpGetVar UnstlManBet 0]} {
		tpBindVar ExpSettle BET ord_date bet_idx
	}

	# bind up old price
	if {[tpGetVar DispOrigPrice 0]} {
		tpBindVar OldPrice       BET old_price     bet_idx seln_idx
	}

	if {[tpGetVar ManBet 0]} {
		# bind up query data
		foreach f {UseSub Customer UpperCust FName LName \
			Email AcctNo Receipt CompNo BetDate1 BetDate2 \
			StlDate1 StlDate2 Stake1 Stake2 Wins1 Wins2 \
			Settled BetTypeOp BetType Manual GameType BetPlacedFrom} {
			set $f [reqGetArg $f]
			tpBindString SR_$f [reqGetArg $f]
		}
	}

	ob_log::write_array DEV BET

	catch {
		unset BETTYPE
	}
}

proc bind_pools_bet_list {res} {

	global DB POOL_BET

	set rows [db_get_nrows $res]

	set cur_id 0
	set b -1

	array set POOL_BET [list]

	set elite 0

	for {set r 0} {$r < $rows} {incr r} {

		set bet_id [db_get_col $res $r pool_bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set l 0
			incr b
			set POOL_BET($b,num_selns) 0
		}
		incr POOL_BET($b,num_selns)

		set pname [db_get_col $res $r pool_name]
		set btype [db_get_col $res $r bet_type]

		if { $btype == "TLEG" } {
			set pname "Win/Plc/Shw"
		} elseif { $btype == "DLEG"} {
			#
			# If bet_type id dleg perform a second query to
			# determine full bet type, one of Win/Shw, Win/Plc or Plc/Shw
			#

			set sql [subst {
				select
					o.pool_type_id
				from
					tpoolbet b,
					tPbet p,
					tpool o
				where
					b.pool_bet_id = ? and
					b.pool_bet_id = p.pool_bet_id and
					p.pool_id = o.pool_id
			}]

			set stmt [inf_prep_sql $DB $sql]
			set c [catch {set rs  [inf_exec_stmt $stmt $bet_id]} msg]
			inf_close_stmt $stmt

			if {$c} {
				# give up and return the initial pool_name
				set pname [db_get_col $res $r pool_name]
			} else {
				for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
					lappend dleg_type [db_get_col $rs $i pool_type_id]
				}
				if {[lsearch $dleg_type WIN] == -1} {
					set pname "Plc/Shw"
				} else {
					if {[lsearch $dleg_type PLC] == -1} {
						set pname "Win/Shw"
					} else {
						set pname "Win/Plc"
					}
				}
			}
			db_close $rs
		}

		if {$l == 0} {
			set POOL_BET($b,bet_id)    $bet_id
			set POOL_BET($b,receipt)   [db_get_col $res $r receipt]
			set POOL_BET($b,cust_id)   [db_get_col $res $r cust_id]
			set POOL_BET($b,cust_name) [db_get_col $res $r username]
			set POOL_BET($b,acct_no)   [db_get_col $res $r acct_no]
			set POOL_BET($b,elite)     [db_get_col $res $r elite]
			set POOL_BET($b,bet_time)  [db_get_col $res $r cr_date]
			set POOL_BET($b,settled)   [db_get_col $res $r settled]
			set POOL_BET($b,acct_ccy)  [db_get_col $res $r ccy_code]
			set POOL_BET($b,pool_ccy)  [db_get_col $res $r pool_ccy_code]
			set POOL_BET($b,pool)      $pname
			set POOL_BET($b,meeting)   [db_get_col $res $r meeting_name]
			set POOL_BET($b,pool_id)   [db_get_col $res $r pool_id]
			set POOL_BET($b,div_rec)   [db_get_col $res $r rec_dividend]
			set POOL_BET($b,pool_conf) [db_get_col $res $r pool_conf]
			set POOL_BET($b,ccy_stake) [db_get_col $res $r ccy_stake]
			set POOL_BET($b,stake)     [db_get_col $res $r stake]
			set POOL_BET($b,unitstake) [format "%0.2f" [db_get_col $res $r unitstake]]
			set POOL_BET($b,num_lines) [db_get_col $res $r num_lines]
			set POOL_BET($b,status)    [db_get_col $res $r status]
			set POOL_BET($b,winnings)  [db_get_col $res $r winnings]
			set POOL_BET($b,refund)    [db_get_col $res $r refund]
			if {[db_get_col $res $r elite] == "Y"} {
				incr elite
			}
		}

		set POOL_BET($b,$l,ev_name)    [db_get_col $res $r ev_name]
		set POOL_BET($b,$l,ev_id)      [db_get_col $res $r ev_id]
		set POOL_BET($b,$l,seln_name)  [db_get_col $res $r seln_name]
		set POOL_BET($b,$l,ev_oc_id)   [db_get_col $res $r ev_oc_id]
		set POOL_BET($b,$l,result)     [db_get_col $res $r result]


		incr l
	}

	tpSetVar NumPoolBets [expr {$b+1}]
	tpSetVar IS_ELITE $elite

	tpBindVar PoolCustId  POOL_BET cust_id   bet_idx
	tpBindVar PoolCustName    POOL_BET cust_name bet_idx
	tpBindVar PoolAcctNo      POOL_BET acct_no   bet_idx
	tpBindVar Elite           POOL_BET elite     bet_idx
	tpBindVar PoolBetId       POOL_BET bet_id    bet_idx
	tpBindVar PoolBetReceipt  POOL_BET receipt   bet_idx
	tpBindVar PoolBetTime     POOL_BET bet_time  bet_idx
	tpBindVar PoolBetSettled  POOL_BET settled   bet_idx
	tpBindVar PoolStatus      POOL_BET status    bet_idx
	tpBindVar PoolType        POOL_BET pool      bet_idx
	tpBindVar Meeting         POOL_BET meeting   bet_idx
	tpBindVar PoolId          POOL_BET pool_id   bet_idx
	tpBindVar PoolRecDividend POOL_BET div_rec   bet_idx
	tpBindVar PoolConf        POOL_BET pool_conf bet_idx
	tpBindVar PoolAcctCCY     POOL_BET acct_ccy  bet_idx
	tpBindVar PoolCCY         POOL_BET pool_ccy  bet_idx
	tpBindVar PoolCcyStake    POOL_BET ccy_stake bet_idx
	tpBindVar PoolStake       POOL_BET stake     bet_idx
	tpBindVar UnitStake       POOL_BET unitstake bet_idx
	tpBindVar NumLines        POOL_BET num_lines bet_idx
	tpBindVar PoolWinnings    POOL_BET winnings  bet_idx
	tpBindVar PoolRefund      POOL_BET refund    bet_idx
	tpBindVar PoolBetLegNo    POOL_BET leg_no    bet_idx seln_idx
	tpBindVar PoolEvDesc      POOL_BET ev_name   bet_idx seln_idx
	tpBindVar PoolEvId        POOL_BET ev_id     bet_idx seln_idx
	tpBindVar PoolEvOcId      POOL_BET ev_oc_id  bet_idx seln_idx
	tpBindVar PoolSelnDesc    POOL_BET seln_name bet_idx seln_idx
	tpBindVar Poolresult      POOL_BET result    bet_idx seln_idx

}


#
# ----------------------------------------------------------------------------
# Create appropriate bindings for failed BIR bet list
# ----------------------------------------------------------------------------
#
proc bind_failed_bir_bet_list {res {query_type ""}} {

	global BET

	array set BET [list]

	set rows [db_get_nrows $res]

	set last_bir_bet_id -1

	for {set r 0} {$r < $rows} {incr r} {

		set current_bir_bet_id    [db_get_col $res $r bir_bet_id]
		set failure_reason        [db_get_col $res $r failure_reason]
		set failure_description   [db_get_col $res $r failure_description]

		if {$current_bir_bet_id != $last_bir_bet_id} {
			set BET($r,bir_bet_id)             $current_bir_bet_id
			set BET($r,cr_date)                [db_get_col $res $r cr_date]
			set BET($r,bet_type)               [db_get_col $res $r bet_type]
			set BET($r,stake_per_line)         [db_get_col $res $r stake_per_line]
			set BET($r,username)               [db_get_col $res $r username]
			set BET($r,cust_id)                [db_get_col $res $r cust_id]
			set BET($r,placed_date)            [db_get_col $res $r placed_date]
		}

		if {$failure_description == ""} {
			set BET($r,failure_description) $failure_reason
		} else {
			if {[string match "HCAP_CHG*" $failure_description]} {
				# Change HCAP_CHG|-5.5|-7.5000 - change to - HCAP_CHG from -5.5 to -7.5
				set failure_description [string replace $failure_description [string first "|" $failure_description] [string first "|" $failure_description] " "]
				set failure_description [string replace $failure_description [string last "|" $failure_description] [string last "|" $failure_description] " from "]
			} elseif {[string match "PRC_CHG*" $failure_description]} {
				# Change PRC_CHG|8|5|9|7 change to - PRC_CHG|8-5 to 9-7
				set failure_description [string replace $failure_description [string last "|" $failure_description] [string last "|" $failure_description] "-"]
				set failure_description [string replace $failure_description [string last "|" $failure_description] [string last "|" $failure_description] " to "]
				set failure_description [string replace $failure_description [string last "|" $failure_description] [string last "|" $failure_description] "-"]
			}
			set BET($r,failure_description)  $failure_description
		}

		if {$BET($r,failure_description) == "OVERRIDES"} {
			set BET($r,failure_description)  "Not failed Part"
		}

		set BET($r,leg_no)     [db_get_col $res $r leg_no]
		set BET($r,part_no)    [db_get_col $res $r part_no]
		set BET($r,ev_oc_id)   [db_get_col $res $r ev_oc_id]
		set BET($r,ev_oc_desc) [db_get_col $res $r ev_oc_desc]
		set BET($r,ev_id)      [db_get_col $res $r ev_id]
		set BET($r,ev_desc)    [db_get_col $res $r ev_desc]

		set last_bir_bet_id  [db_get_col $res $r bir_bet_id]
	}

	tpSetVar NumBets $rows

	tpBindVar FailureDescription   BET   failure_description   bir_bet_idx
	tpBindVar BIRBetId             BET   bir_bet_id            bir_bet_idx
	tpBindVar CreationDate         BET   cr_date               bir_bet_idx
	tpBindVar BetType              BET   bet_type              bir_bet_idx
	tpBindVar StakePerLine         BET   stake_per_line        bir_bet_idx
	tpBindVar Username             BET   username              bir_bet_idx
	tpBindVar CustId               BET   cust_id               bir_bet_idx
	tpBindVar LegNo                BET   leg_no                bir_bet_idx
	tpBindVar PartNo               BET   part_no               bir_bet_idx
	tpBindVar EvOcId               BET   ev_oc_id              bir_bet_idx
	tpBindVar EvOcDesc             BET   ev_oc_desc            bir_bet_idx
	tpBindVar EvId                 BET   ev_id                 bir_bet_idx
	tpBindVar EvDesc               BET   ev_desc               bir_bet_idx

}


#
# ----------------------------------------------------------------------------
# Bet receipt
# ----------------------------------------------------------------------------
#
proc go_bet_receipt args {

	global DB BET PMT

	catch {unset BET}

	set bet_id     [reqGetArg BetId]

	foreach {n v} $args {
		set $n $v
	}

	set sql_m [subst {
		select
			b.bet_id,
			b.aff_id,
			b.ipaddr,
			b.cr_date,
			b.bet_type,
			b.status,
			b.acct_id,
			a.ccy_code,
			a.owner,
			a.owner_type,
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			c.lang,
			b.stake,
			b.tax_type,
			b.tax,
			b.stake_per_line,
			b.max_payout,
			b.tax_rate,
			b.num_selns,
			b.num_legs,
			b.leg_type,
			b.num_lines,
			b.receipt,
			b.settled,
			b.settled_at,
			NVL(b.settled_how,"-") settled_how,
			b.settle_info,
			b.user_id,
			b.paid,
			m.username admin_user,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.winnings,
			b.refund,
			p.cr_date parked_date,
			p.num_lines_win p_num_lines_win,
			p.num_lines_lose p_num_lines_lose,
			p.num_lines_void p_num_lines_void,
			p.winnings p_winnings,
			p.refund p_refund,
			p.tax p_tax,
			o.username operator,
			l.telephone line_no,
			b.source,
			b.token_value,
			l.retro_term_code,
			l.retro_date,
			o2.username as retro_username,
			NVL(case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
				end, "--") as rep_code,
			NVL(case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
				end, "--") as on_course_type
		from
			tBet b,
			tAcct a,
			tCustomer c,
			outer tBetStlPending p,
			outer tAdminUser m,
			outer (tAdminUser o,
					 tCall l, outer tAdminUser o2),
			outer (tHedgedBet hb, outer tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, outer tOnCourseRep ocrF)
		where
			b.bet_id        = ?          and
			b.acct_id       = a.acct_id  and
			a.cust_id       = c.cust_id  and
			b.bet_id        = p.bet_id   and
			b.user_id       = m.user_id  and
			b.call_id       = l.call_id  and
			l.oper_id       = o.user_id  and
			l.retro_user    = o2.user_id and
			b.bet_id        = hb.bet_id  and
			b.bet_id        = ocb.bet_id and
			hb.rep_code_id  = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id

	}]

	set stmt [inf_prep_sql $DB $sql_m]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set manual 0
	if {[db_get_col $res 0 bet_type] == "MAN"} {
		set manual 1
	}

	set parked_date [db_get_col $res 0 parked_date]
	set tax_type    [db_get_col $res 0 tax_type]
	set tax_rate    [db_get_col $res 0 tax_rate]

	set elite 0
	if {[db_get_col $res 0 elite] == "Y"} {
		set elite 1
	}

	tpSetVar IS_ELITE $elite

	tpSetVar TaxType [expr {$tax_rate == 0.0 ? "-" : $tax_type}]

	#
	# Set the on course type to user friendly format
	#
	set on_course_type [db_get_col $res 0 on_course_type]
	switch -- $on_course_type {
		"H" {set on_course_type "Hedged"}
		"B" {set on_course_type "Book"}
		"C" {set on_course_type "Card"}
	}

	#
	# If the bet is a hedged bet, we want to reverse the signs for the stake
	#
	set stake          [db_get_col $res 0 stake]
	set stake_per_line [db_get_col $res 0 stake_per_line]

	if {$on_course_type == "Hedged" && [OT_CfgGet FUNC_HYBRID_HEDGING 0]} {
		set stake          [format "%0.2f" [expr \
			{$stake > 0 ? $stake * -1 : $stake}]]
		set stake_per_line [format "%0.2f" [expr \
			{$stake_per_line > 0 ? $stake_per_line * -1 : $stake_per_line}]]
	}

	tpBindString BetId        $bet_id
	tpBindString AffId        [db_get_col $res 0 aff_id]
	tpBindString CustId       [db_get_col $res 0 cust_id]
	tpBindString AcctNo       [db_get_col $res 0 acct_no]
	tpBindString Username     [db_get_col $res 0 username]
	tpBindString Elite        [db_get_col $res 0 elite]
	tpBindString BetType      [db_get_col $res 0 bet_type]
	tpBindString LegType      [db_get_col $res 0 leg_type]
	tpBindString NumLines     [db_get_col $res 0 num_lines]
	tpBindString IPaddr       [db_get_col $res 0 ipaddr]
	tpBindString BetDate      [db_get_col $res 0 cr_date]
	tpBindString CCYCode      [db_get_col $res 0 ccy_code]
	tpBindString Stake        $stake
	tpBindString StakePerLine $stake_per_line
	tpBindString TaxInfo      [db_get_col $res 0 tax]
	tpBindString TaxRate      $tax_rate
	tpBindString TaxType      $tax_type
	tpBindString Receipt      [db_get_col $res 0 receipt]
	tpBindString MaxPayout    [db_get_col $res 0 max_payout]
	tpBindString Operator	  [db_get_col $res 0 operator]
	tpBindString TerminalID   [db_get_col $res 0 line_no]
	tpBindString Source       [db_get_col $res 0 source]
	tpBindString TokenValue   [db_get_col $res 0 token_value]
	tpBindString RepCode      [db_get_col $res 0 rep_code]
	tpBindString OnCourseType $on_course_type

	tpSetVar BetStatus [db_get_col $res 0 status]

	set settled [db_get_col $res 0 settled]

	if {$settled == "Y"} {

		#
		# If the bet is a hedged bet, we want to reverse the signs for the
		# winnings and refund
		#
		set winnings [db_get_col $res 0 winnings]
		set refunds  [db_get_col $res 0 refund]

		if {$on_course_type == "Hedged" && [OT_CfgGet FUNC_HYBRID_HEDGING 0]} {
			set winnings [format "%0.2f" [expr \
				{$winnings > 0 ? $winnings * -1 : $winnings}]]
			set refunds  [format "%0.2f" [expr \
				{$refunds > 0 ? $refunds * -1 : $refunds}]]
		}

		tpSetVar settled YES
		tpBindString SettledAt    [db_get_col $res 0 settled_at]
		tpBindString SettleInfo   [db_get_col $res 0 settle_info]
		tpBindString SettledBy    [db_get_col $res 0 admin_user]
		tpBindString SettledHow   [db_get_col $res 0 settled_how]
		tpBindString Winnings     $winnings
		tpBindString Refunds      $refunds
		tpBindString NumLinesWin  [db_get_col $res 0 num_lines_win]
		tpBindString NumLinesLose [db_get_col $res 0 num_lines_lose]
		tpBindString NumLinesVoid [db_get_col $res 0 num_lines_void]
	} elseif {$parked_date != ""} {
		tpSetVar settled PENDING
		tpBindString P_Winnings     [db_get_col $res 0 p_winnings]
		tpBindString P_Refund       [db_get_col $res 0 p_refund]
		tpBindString P_NumLinesWin  [db_get_col $res 0 p_num_lines_win]
		tpBindString P_NumLinesLose [db_get_col $res 0 p_num_lines_lose]
		tpBindString P_NumLinesVoid [db_get_col $res 0 p_num_lines_void]
		tpBindString P_Tax          [db_get_col $res 0 p_tax]
	} else {
		tpSetVar settled NO
	}

	tpSetVar RETRO 0
	if {[db_get_col $res 0 retro_date] != ""} {
		tpSetVar RETRO 1
		tpBindString RetroDate      [db_get_col $res 0 retro_date]
		tpBindString RetroTermCode  [db_get_col $res 0 retro_term_code]
		tpBindString RetroUsername  [db_get_col $res 0 retro_username]
	}


	tpSetVar ap_paid [db_get_col $res 0 paid]

	set num_legs [db_get_col $res 0 num_legs]

	tpSetVar num_legs $num_legs

	set owner      [db_get_col $res 0 owner]
	set owner_type [db_get_col $res 0 owner_type]

	if {$owner == "F" && [regexp {^(STR|VAR|OCC|REG|LOG)$} $owner_type]} {
		tpSetVar ShopFieldingBet "Y"
	}

	db_close $res

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR::bind_bet_receipt $bet_id
	}

	#
	# Get the payment status for any payments associated with the bet
	#
	set sql_p [subst {
		select
			p.status,
			p.pmt_id,
			p.call_id
		from
			tBet b,
			tPmt p
		where
			b.bet_id = ? and
			b.call_id = p.call_id

	}]

	set stmt [inf_prep_sql $DB $sql_p]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	array set PMT [list]

	set internal_funds_used 1

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		switch -- [db_get_col $res $r status] {
			"Y" {set pmt_status " Success"}
			"N" {set pmt_status " Failed"}
			"P" {set pmt_status " Pending"}
			"R" {set pmt_status " Referred"}
			"L" {set pmt_status " Later"}
			"X" {set pmt_status " Cancelled"}
			default {set pmt_status " Unknown"}
		}
		#PT3887
		#When internal funds transfer takes place there is no entry in tPmt.
		#If a payment was declined, and then the customer lowered the stake
		#to be covered completely using internal funds (from there account)
		#then there will be a failure entry in tPmt, then no further tPmt
		#entries...
		if {$pmt_status != " Failed"} {
			set internal_funds_used 0
		}

		set PMT($r,pmt_status) $pmt_status
		set PMT($r,pmt_id)     [db_get_col $res $r pmt_id]
		set PMT($r,call_id)    [db_get_col $res $r call_id]

	}
	#if we've had status of N, and an entry in tbet, then
	#the bet was finally fulfilled using internal funds i.e. the
	#stake was reduced.
	#so add an extra 'row' of No Payments....
	if {$internal_funds_used} {
		incr nrows
		set PMT($r,pmt_status) "Internal Funds Used"
		set PMT($r,pmt_id)     0
		set PMT($r,call_id)    0
	}

	db_close $res

	tpSetVar num_pmts $nrows
	tpSetVar internal_funds_used $internal_funds_used

	tpBindVar PmtStatus PMT pmt_status pmt_idx
	tpBindVar PmtID     PMT pmt_id     pmt_idx
	tpBindVar CallID    PMT call_id    pmt_idx

	#
	# Get selection info
	#
	set sql_d [subst {
		select
			o.bet_id,
			o.leg_no-1 leg_no,
			o.part_no-1 part_no,
			o.leg_sort,
			o.ev_oc_id,
			o.o_num,
			o.o_den,
			o.price_type,
			o.ep_active,
			NVL(o.no_combi,'') no_combi,
			o.banker,
			o.bir_index,
			case
				when b.leg_type='E'
				then nvl(o.ew_fac_num,0)
			end ew_fac_num,
			case
				when b.leg_type='E'
				then nvl(o.ew_fac_den,0)
			end ew_fac_den,
			case
				when b.leg_type='E'
				then nvl(o.ew_places,0)
			end ew_places,
			o.hcap_value,
			m.name,
			case
				when e.result_conf='Y' or s.result_conf='Y'
				then s.result else '-'
			end result,
			s.place,
			s.ev_oc_id ev_oc_id,
			s.desc seln_desc,
			s.lp_num,
			s.lp_den,
			s.sp_num,
			s.sp_den,
			s.fb_result,
			m.name mkt_name,
			m.ev_mkt_id,
			m.sort mkt_sort,
			m.type mkt_type,
			m.hcap_makeup,
			e.desc ev_desc,
			e.ev_id ev_id,
			e.start_time,
			t.name type_name,
			c.name class_name,
			o.in_running
		from
			tBet b,
			tOBet o,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvType t,
			tEvClass c
		where
			b.bet_id = ? and
			o.bet_id = b.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id
		order by
			2 asc,
			3 asc
	}]

	set stmt [inf_prep_sql $DB $sql_d]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set cur_leg_no -1

	array set BET [list]

	set nrows [db_get_nrows $res]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		set leg_no  [db_get_col $res $r leg_no]
		set part_no [db_get_col $res $r part_no]

		if {$leg_no != $cur_leg_no} {

			set cur_leg_no $leg_no

			set BET($leg_no,leg_sort)   [db_get_col $res $r leg_sort]
			set BET($leg_no,class)      [db_get_col $res $r class_name]
			set BET($leg_no,type)       [db_get_col $res $r type_name]
			set BET($leg_no,ev_id)      [db_get_col $res $r ev_id]
			set BET($leg_no,event)      [db_get_col $res $r ev_desc]
			set BET($leg_no,start_time) [db_get_col $res $r start_time]
			set BET($leg_no,ev_mkt_id)  [db_get_col $res $r ev_mkt_id]
			set BET($leg_no,market)     [db_get_col $res $r mkt_name]
			set BET($leg_no,ew_fac_num) [db_get_col $res $r ew_fac_num]
			set BET($leg_no,ew_fac_den) [db_get_col $res $r ew_fac_den]
			set BET($leg_no,ew_places)  [db_get_col $res $r ew_places]
			set BET($leg_no,mkt_sort)   [db_get_col $res $r mkt_sort]
			set BET($leg_no,mkt_type)   [db_get_col $res $r mkt_type]
			set BET($leg_no,bir_index) 	[db_get_col $res $r bir_index]
			set BET($leg_no,in_running) [db_get_col $res $r in_running]


			# xlate all the columns that are xlatable
			foreach xl_col {
				class
				type
				event
				leg_sort
			} {
				set BET($leg_no,xl_${xl_col}) [OB_mlang::ml_printf $BET($leg_no,$xl_col)]
			}

			if {$BET($leg_no,leg_sort) == "CW"} {
				set BET($leg_no,xl_market) [OB_mlang::ml_printf $BET($leg_no,market) $BET($leg_no,bir_index)]
			} else {
				set BET($leg_no,xl_market) [OB_mlang::ml_printf $BET($leg_no,market)]
			}

			#how are the legs combined
			set no_combi  [db_get_col $res $r no_combi]
			set banker    [db_get_col $res $r banker]
			if {$banker == "Y"} {
				set combi "Banker"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != "" && $no_combi % 2 == 0} {
				set combi "Even"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != ""} {
				set combi "Odd"
				tpSetVar ShowCombiKey 1
			} else {
				set combi "All"
			}
			set BET($leg_no,combi)  $combi
			set BET($leg_no,banker) $banker
		}

		set BET($leg_no,num_parts) [expr {$part_no+1}]

		set BET($leg_no,$part_no,ev_oc_id) [db_get_col $res $r ev_oc_id]
		set BET($leg_no,$part_no,seln)     [db_get_col $res $r seln_desc]

		# XLATE xlateable column
		set BET($leg_no,$part_no,xl_seln)  [OB_mlang::ml_printf $BET($leg_no,$part_no,seln)]

		set o_pt     [db_get_col $res $r price_type]

		# Need these for choosing a guaranteed price
		set gp_price ""
		set sp_num [db_get_col $res $r sp_num]
		set sp_den [db_get_col $res $r sp_den]

		if {$o_pt == "L" || $o_pt == "G"} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			set price [mk_price $o_num $o_den]

			# If GP, we want to append the GP price, but have price as ???
			# if unsettled, settled price otherwise

			if {$o_pt == "G"} {
				set o_price $price

				if {$settled == "Y"} {

					# Compare the SP and LP, change price to SP if higher

					if {[catch {
						set o_price_frac [expr "${o_num}.0 / $o_den"]
					} msg]} {
						set o_price_frac 0
						ob_log::write INFO {ADMIN::BET::go_bet_receipt: no \
							live price set for $BET($leg_no,$part_no,ev_oc_id)}
					}

					if {$sp_num != "" && $sp_den != ""} {
						set sp_price     [expr "${sp_num}.0 / $sp_den"]
					} else {
						set sp_price 0
					}

					if {$o_price_frac < $sp_price} {
						set price [mk_price $sp_num $sp_den]
					}

				} else {
					set price "???"
				}

				append price " (GP=$o_price)"
			}

			# Append handicap information

			set mkt_type $BET($leg_no,mkt_type)

			if {[string first $mkt_type "AHLMU"] >= 0} {

				set fb_result  [db_get_col $res $r fb_result]
				set hcap_value [db_get_col $res $r hcap_value]

				set hcap_str [mk_hcap_str $mkt_type $fb_result $hcap_value]

				append price " \[$hcap_str\]"
			}

		} elseif {$o_pt == "S"} {
			set price SP
		} elseif {$o_pt == "D"} {
			set price DIV
		} elseif {$o_pt == "B"} {
			set price BP
		} elseif {$o_pt == "N"} {
			set price NP
		} elseif {$o_pt == "1"} {
			set price FS
		} elseif {$o_pt == "2"} {
			set price SS
		} elseif {$manual} {
			set price MAN
		} else {
			set price "???"
		}

		set BET($leg_no,$part_no,price) $price

		# Early Prices Active flag - display flag if it is set
		set ep_active [db_get_col $res $r ep_active]
		if {$ep_active=="Y"} {
			set BET($leg_no,$part_no,ep_active) "(Early)"
		} else {
			set BET($leg_no,$part_no,ep_active) ""
		}

		set result [db_get_col $res $r result]
		set place  [db_get_col $res $r place]

		if {$place != ""} {
			append result " (place $place)"
		}
		if {$sp_num != ""} {
			set sp [mk_price $sp_num $sp_den]
			append result " (SP=$sp)"
		}

		set BET($leg_no,$part_no,result) $result
	}

	tpBindVar EventClass  BET xl_class    leg_idx
	tpBindVar EventType   BET xl_type     leg_idx
	tpBindVar EventStart  BET start_time  leg_idx
	tpBindVar EventName   BET xl_event    leg_idx
	tpBindVar EventId     BET ev_id       leg_idx
	tpBindVar LegSort     BET xl_leg_sort leg_idx
	tpBindVar MarketName  BET xl_market   leg_idx
	tpBindVar MarketId    BET ev_mkt_id   leg_idx
	tpBindVar Ew_fac_num  BET ew_fac_num  leg_idx
	tpBindVar Ew_fac_den  BET ew_fac_den  leg_idx
	tpBindVar Ew_places   BET ew_places   leg_idx
	tpBindVar BIR_INDEX   BET bir_index   leg_idx
	tpBindVar InRunning   BET in_running  leg_idx
	tpBindVar BetCombi    BET combi       leg_idx
	tpBindVar BetBanker   BET banker      leg_idx
	tpBindVar SelnId      BET ev_oc_id    leg_idx part_idx
	tpBindVar SelnName    BET xl_seln     leg_idx part_idx
	tpBindVar SelnResult  BET result      leg_idx part_idx
	tpBindVar SelnPrice   BET price       leg_idx part_idx
	tpBindVar EPActive    BET ep_active   leg_idx part_idx

	if {$manual == 1} {
		set sql [subst {
			select
			 o.desc_1,
			 o.desc_2,
			 o.desc_3,
			 o.desc_4,
			 to_char(o.to_settle_at,'%d %b %Y') as to_settle_at_str,
			 to_settle_at,
			 nvl(o.real_cr_date,"N/A")          real_cr_date,
			 nvl(o.batch_ref_id,"Not in batch") batch_ref_id,
			 nvl(br.location,"Not in batch")    batch_location,
			 c.name as ev_class_name,
			 t.name as ev_type_name,
			 o.temp_desc_1,
			 o.temp_desc_2,
			 o.temp_desc_3,
			 o.temp_desc_4
			  from
			 tBet b,
			 tManOBet o,
			 outer tEvClass c,
			 outer tEvType t,
			 outer tBatchReference br
			 where
			 b.bet_id = ? and
			 b.bet_id = o.bet_id and
			 c.ev_class_id = o.ev_class_id and
			 t.ev_type_id = o.ev_type_id and
			 o.batch_ref_id = br.batch_ref_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bet_id]

		inf_close_stmt $stmt

		tpSetVar     ManualStl 1
		tpBindString Manual    1
		tpBindString ManDesc "[db_get_col $res 0 desc_1]\
		 [db_get_col $res 0 desc_2] [db_get_col $res 0 desc_3]\
		 [db_get_col $res 0 desc_4]"
		tpBindString TempManDesc "[db_get_col $res 0 temp_desc_1]\
		 [db_get_col $res 0 temp_desc_2]\
		 [db_get_col $res 0 temp_desc_3]\
		 [db_get_col $res 0 temp_desc_4]"
		tpBindString ManEventClass [db_get_col $res 0 ev_class_name]
		tpBindString ManEventType  [db_get_col $res 0 ev_type_name]
		tpBindString ToSettleAtStr [db_get_col $res 0 to_settle_at_str]
		tpBindString ToSettleAt    [string range [db_get_col $res 0 to_settle_at] 0 9]
		tpBindString RealBetDate   [db_get_col $res 0 real_cr_date]
		tpBindString BatchRefID    [db_get_col $res 0 batch_ref_id]
		tpBindString BatchLocation [db_get_col $res 0 batch_location]
	} else {
		tpSetVar     ManualStl 0
	}
	db_close $res

	set sql [subst {
		select count(override_id)
		from tOverride
		where ref_id = ? and
		ref_key = 'BET'}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set num_or [db_get_col $res 0 "(count)"]
	tpSetVar bet_number_of_overrides $num_or

	db_close $res
	if {$num_or != 0} {
		tpBindString bet_number_of_overrides_str $num_or
	} else {
		tpBindString bet_number_of_overrides_str "none"
	}

	tpBindString BetID $bet_id

	bind_man_adj "BET" $bet_id

	asPlayFile -nocache bet_receipt.html


	unset BET
	unset PMT
}


proc bind_man_adj {ref_key ref_id} {

	#
	# Get all linked Manual Adjustments
	#
	global MAN_ADJ_DATA DB
	set sql [subst {
		select
			madj_id
		from
			tManAdj
		where
			    ref_key = ?
			and ref_id  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ref_key $ref_id]
	inf_close_stmt $stmt

	tpSetVar NumAdjs [set NumAdjs [db_get_nrows $res]]

	for {set r 0} {$r < $NumAdjs} {incr r} {
		set MAN_ADJ_DATA($r,madj_id) [db_get_col $res $r madj_id]
	}

	tpBindVar ManAdjId MAN_ADJ_DATA madj_id adj_idx

}


#
# ----------------------------------------------------------------------------
# Pools Bet receipt
# ----------------------------------------------------------------------------
#
proc go_pools_receipt args {

	global DB BET

	catch {unset BET}

	set bet_id [reqGetArg BetId]

	foreach {n v} $args {
		set $n $v
		if {$n == "bet_id"} {
			set bet_id $v
		}
	}

	OT_LogWrite 1 "go_pools_receipt: $bet_id"

	if {[OT_CfgGet ENABLE_TOTE_TSN 1]} {
		set tsn_col    "t.tsn"
		set tsn_table  ", outer tToteTSN t"
		set tsn_constr "and t.pool_bet_id = b.pool_bet_id"
	} else {
		set tsn_col    " '' as tsn"
		set tsn_table  ""
		set tsn_constr ""
	}

	set sql [subst {
		select
			b.pool_bet_id,
			b.settled			as bet_settled,
			b.settled_at		as bet_settled_at,
			b.settle_info		as bet_settle_info,
			NVL(b.settled_how,"-") settled_how,
			b.receipt			as receipt,
			b.ipaddr,
			b.cr_date			as bet_date,
			b.acct_id			as bet_acct_id,
			b.stake,
			b.ccy_stake,
			b.ccy_stake_per_line,
			b.max_payout		as bet_max_payout,
			b.winnings			as bet_winnings,
			b.refund			as bet_refund,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.bet_type,
			b.call_id,
			b.paid,
			b.status,
			s.winnings as pend_winnings,
			s.refund as pend_refund,
			s.num_lines_win as pnum_lines_win,
			s.num_lines_lose as pnum_lines_lose,
			s.num_lines_void as pnum_lines_void,
			ch.desc as source,
			case when exists (select 1 from tPmt p where p.call_id = l.call_id and p.status in ('R','L'))
				then 'Y'
				else 'N'
			end as pending,
			b.source,
			r.username			as admin_user,
			l.telephone			as line_no,
			u.username			as operator,
			pb.leg_no,
			pb.part_no,
			pb.ev_oc_id,
			nvl(pb.banker_info, '-') as banker_info,
			p.pool_id,
			pt.name                  as pool_name,
			ps.desc                  as pool_source,
			ps.ccy_code              as pool_ccy,
			e.desc                   as ev_name,
			e.ev_id,
			e.start_time             as ev_time,
			o.desc                   as oc_name,
			nvl(o.result, '-')       as oc_result,
			nvl(o.place, '-')        as oc_place,
			o.runner_num,
			a.ccy_code,
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			y.name as type_name,
			y.ev_type_id,
			$tsn_col

		from
			tPoolBet b,
			tPbet pb,
			tPool p,
			tPoolType pt,
			tPoolSource ps,
			tevoc o,
			tev e,
			tEvType y,
			tAcct a,
			tCustomer c,
			tChannel ch,
			outer tAdminUser r,
			outer tPoolBetStlPending s,
			outer (tCall l, tAdminUser u)
			$tsn_table
		where

			b.pool_bet_id = ? and
			b.pool_bet_id = pb.pool_bet_id and
			b.pool_bet_id = s.pool_bet_id and
			pb.ev_oc_id = o.ev_oc_id and
			o.ev_id = e.ev_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			pb.pool_id = p.pool_id and
			p.pool_type_id = pt.pool_type_id and
			pt.pool_source_id = ps.pool_source_id and
			b.user_id = r.user_id and
			b.call_id = l.call_id and
			b.source  = ch.channel_id and
			l.oper_id = u.user_id and
			y.ev_type_id = e.ev_type_id
			$tsn_constr

	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	tpSetVar nrows $nrows

	#
	# If the bet type is TLEG set the pool name to be Win/Plc/Show
	# if the bet type is DLEG, detemine pool name, one of Win/Shw, Win/Plc or Plc/Shw
	# Otherwise just use the bet_type
	#

	set pname [db_get_col $res 0 pool_name]
	set btype [db_get_col $res 0 bet_type]

	if { $btype == "TLEG" } {
		set pname "Win/Plc/Shw"
	} elseif { $btype == "DLEG"} {
		#
		# If bet_type id dleg perform a second query to
		# determine full bet type, one of Win/Shw, Win/Plc or Plc/Shw
		#

			set sql [subst {
			select
				o.pool_type_id
			from
 	 	 	 	tpoolbet b,
 	 	 	 	tPbet p,
 	 	 	 	tpool o
 	 	 	where
				b.pool_bet_id = ? and
				b.pool_bet_id = p.pool_bet_id and
				p.pool_id = o.pool_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set c [catch {set rs  [inf_exec_stmt $stmt $bet_id]} msg]
		inf_close_stmt $stmt

		if {$c} {
			# give up and return the initial pool_name
			set pname [db_get_col $res 0 pool_name]
		} else {
			for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
				lappend dleg_type [db_get_col $rs $r pool_type_id]
			}
			if {[lsearch $dleg_type WIN] == -1} {
				set pname "Plc/Shw"
			} else {
				if {[lsearch $dleg_type PLC] == -1} {
					set pname "Win/Shw"
				} else {
					set pname "Win/Plc"
				}
			}
		}
		db_close $rs
	}

	set elite 0

	#
	# Interpret source
	#

	tpBindString Source		 		[db_get_col $res source]

	tpBindString BetId		 		[db_get_col $res pool_bet_id]
	tpBindString Receipt			[db_get_col $res receipt]
	tpBindString IPaddr             [db_get_col $res ipaddr]
	tpBindString BetDate			[db_get_col $res bet_date]
	tpBindString Status             [db_get_col $res status]
	tpBindString AcctId         	[db_get_col $res bet_acct_id]
	tpBindString Stake				[db_get_col $res stake]
	tpBindString CcyStake			[db_get_col $res ccy_stake]
	tpBindString CcyStakePerLine	[db_get_col $res ccy_stake_per_line]
	tpBindString MaxPayout			[db_get_col $res bet_max_payout]
	tpBindString TSN				[set BET(TSN) [db_get_col $res tsn]]
	tpBindString BetType			[db_get_col $res bet_type]
	if { [string length [db_get_col $res pend_winnings]] > 0 } {
		tpBindString Winnings			[db_get_col $res pend_winnings]
	} else {
		tpBindString Winnings			[db_get_col $res bet_winnings]
	}
	if { [string length [db_get_col $res pend_refund]] > 0 } {
		tpBindString Refunds			[db_get_col $res pend_refund]
	} else {
		tpBindString Refunds			[db_get_col $res bet_refund]
	}
	tpBindString NumLines			[db_get_col $res 0 num_lines]
	if { [string length [db_get_col $res pnum_lines_win]] > 0 } {
		tpBindString NumLinesWin			[db_get_col $res pnum_lines_win]
	} else {
		tpBindString NumLinesWin			[db_get_col $res num_lines_win]
	}
	if { [string length [db_get_col $res pnum_lines_lose]] > 0 } {
		tpBindString NumLinesLose			[db_get_col $res pnum_lines_lose]
	} else {
		tpBindString NumLinesLose			[db_get_col $res num_lines_lose]
	}
	if { [string length [db_get_col $res pnum_lines_void]] > 0 } {
		tpBindString NumLinesVoid			[db_get_col $res pnum_lines_void]
	} else {
		tpBindString NumLinesVoid			[db_get_col $res num_lines_void]
	}
	tpBindString CallId  			[db_get_col $res 0 call_id]
	tpBindString paid				[db_get_col $res 0 paid]
	tpBindString Operator			[db_get_col $res 0 operator]
	tpBindString TerminalId			[db_get_col $res 0 line_no]
	tpBindString PoolCcy            [db_get_col $res 0 pool_ccy]
	tpBindString PoolType           $pname
	tpBindString AcctCcy            [db_get_col $res 0 ccy_code]
	tpBindString CustId				[db_get_col $res 0 cust_id]
	tpBindString Username			[db_get_col $res 0 username]
	tpBindString AcctNo				[db_get_col $res 0 acct_no]
	tpBindString Elite             [db_get_col $res 0 elite]
	tpBindString EvTypeId			[db_get_col $res 0 ev_type_id]
	tpBindString TypeName			[db_get_col $res 0 type_name]

	if {[db_get_col $res 0 elite] == "Y"} {
		incr elite
	}

	tpSetVar IS_ELITE $elite

	set cols {leg_no part_no banker_info pool_id pool_name pool_source
			  ev_name ev_id ev_time oc_name ev_oc_id
			  oc_result oc_place runner_num}

	for {set i 0} {$i<$nrows} {incr i} {
		foreach c $cols {
			set BET($i,$c) [db_get_col $res $i $c]
		}
	}

	tpBindVar LegNo      BET leg_no      pool_idx
	tpBindVar PartNo     BET part_no     pool_idx
	tpBindVar BankerInfo BET banker_info pool_idx
	tpBindVar EvOcId     BET ev_oc_id    pool_idx
	tpBindVar PoolId     BET pool_id     pool_idx
	tpBindVar PoolName   BET pool_name   pool_idx
	tpBindVar PoolSource BET pool_source pool_idx
	tpBindVar EvName     BET ev_name     pool_idx
	tpBindVar EvTime     BET ev_time     pool_idx
	tpBindVar EvId       BET ev_id       pool_idx
	tpBindVar OcName     BET oc_name     pool_idx
	tpBindVar OcResult   BET oc_result   pool_idx
	tpBindVar OcPlace    BET oc_place    pool_idx
	tpBindVar RunnerNum  BET runner_num  pool_idx


	tpSetVar BetStatus  [db_get_col $res status]
	tpSetVar BetSettled [db_get_col $res bet_settled]

	if {[db_get_col $res bet_settled] == "Y"} {
		tpBindString SettledAt    [db_get_col $res bet_settled_at]
		tpBindString SettledBy    [db_get_col $res admin_user]
		tpBindString SettleInfo	  [db_get_col $res bet_settle_info]
		tpBindString SettledHow   [db_get_col $res 0 settled_how]
		tpBindString Winnings     [db_get_col $res bet_winnings]
		tpBindString Refunds      [db_get_col $res bet_refund]
	}


	set pool_bet_id [db_get_col $res pool_bet_id]
	db_close $res

	set sql [subst {
		select count(override_id)
		from tOverride
		where ref_id = ? and
		ref_key = 'POOL'}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pool_bet_id]

	inf_close_stmt $stmt

	set num_or [db_get_col $res 0 "(count)"]
	tpSetVar bet_number_of_overrides $num_or

	db_close $res
	if {$num_or != 0} {
		tpBindString bet_number_of_overrides_str $num_or
	} else {
		tpBindString bet_number_of_overrides_str "none"
	}

	bind_man_adj "POOL" $pool_bet_id

	asPlayFile -nocache pools_bet_receipt.html

}



#
# ----------------------------------------------------------------------------
# XGame Bet receipt
# ----------------------------------------------------------------------------
#
proc go_xgame_receipt args {

	global DB PMT

	set bet_id [reqGetArg BetId]

	foreach {n v} $args {
		set $n $v
		if {$n == "bet_id"} {
			set bet_id $v
		}
	}

	set sql [subst {
		select
			s.xgame_sub_id,
			b.xgame_bet_id,
			b.xgame_id,
			s.cr_date subdate,
			s.num_subs,
			s.stake_per_bet,
			s.picks,
			s.ipaddr,
			s.authorized,
			s.source src,
			s.aff_id,
			s.no_funds_email,
			s.status,
			s.bet_type,
			s.num_selns,
			s.stake_per_line,
			NVL(s.void_reason,'-') as void_reason,
			b.cr_date betdate,
			NVL(b.stake,'-') as stake,
			b.winnings,
			b.refund,
			b.settled,
			b.settled_at,
			b.paymethod,
			b.output,
			c.username,
			c.acct_no,
			c.elite,
			d.sort,
			d.name,
			a.ccy_code,
			c.cust_id,
			g.comp_no,
			g.draw_at,
			NVL(g.results,'-') as results,
			l.telephone			as line_no,
			u.username			as operator,
			b.bet_type,
			b.stake_per_line,
			b.num_selns,
			b.num_lines,
			b.num_lines_void,
			b.num_lines_win,
			b.num_lines_lose,
			s.prices,
			b.settled_how,
			b.settle_info,
			b.status as bet_status,
			b.settled_by,
			s.receipt
		from
			tAcct a,
			tCustomer c,
			tXGameSub s,
			tXGameBet b,
			tXGame g,
			tXGameDef d,
			outer (tCall l, tAdminUser u)
		where
			b.xgame_bet_id = ? and
			a.cust_id = c.cust_id and
			a.acct_id = s.acct_id and
			s.xgame_sub_id = b.xgame_sub_id and
			b.xgame_id = g.xgame_id and
			g.sort = d.sort and
			s.call_id = l.call_id and
			l.oper_id = u.user_id
		order by
			b.xgame_bet_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	inf_close_stmt $stmt

	#
	# Interpret pay method
	#
	set pay_method [db_get_col $res 0 paymethod]

	if {$pay_method == "L"} {
		set pay_method "Cheque"
	} elseif {$pay_method == "O"} {
		set pay_method "OpenBet Acct"
	} elseif {$pay_method == "P"} {
		set pay_method "Prize"
	} elseif {$pay_method == "F"} {
		set pay_method "Free bet"
	} else {
		set pay_method "-"
	}

	#
	# Interpret status
	#
	set sub_status [db_get_col $res 0 status]
	if {$sub_status == "P"} {
		set sub_status "Active"
	} elseif {$sub_status == "V"} {
		set sub_status "Void"
	} elseif {$sub_status == "F"} {
		set sub_status "Fulfilled"
	} else {
		set sub_status "-"
	}

	#
	# Interpret source
	#
	set sub_source [db_get_col $res 0 src]
	if {$sub_source == "I"} {
		set sub_source "Internet"
	} elseif {$sub_source == "W"} {
		set sub_source "Wap"
	} elseif {$sub_source == "T"} {
		set sub_source "Telewest"
	} elseif {$sub_source == "P"} {
		set sub_source "Telebet"
	} elseif {$sub_source == "E"} {
		set sub_source "Elite"
	}

	set sub_id [db_get_col $res 0 xgame_sub_id]

	set elite 0
	if {[db_get_col $res 0 elite] == "Y"} {
		incr elite
	}

	tpBindString SubId        $sub_id
	tpBindString BetId        [db_get_col $res 0 xgame_bet_id]
	tpBindString GameId       [db_get_col $res 0 xgame_id]
	tpBindString CustId       [db_get_col $res 0 cust_id]
	tpBindString AcctNo       [db_get_col $res 0 acct_no]
	tpBindString Elite        [db_get_col $res 0 elite]
	tpBindString Username     [db_get_col $res 0 username]
	tpBindString SubDate      [db_get_col $res 0 subdate]
	tpBindString NumSubs      [db_get_col $res 0 num_subs]
	tpBindString Stake  	  [db_get_col $res 0 stake_per_bet]
	tpBindString Picks        [db_get_col $res 0 picks]
	tpBindString IPaddr       [db_get_col $res 0 ipaddr]
	tpBindString Auth         [db_get_col $res 0 authorized]
	tpBindString Source       $sub_source
	tpBindString AffId        [db_get_col $res 0 aff_id]
	tpBindString NoFunds      [db_get_col $res 0 no_funds_email]
	tpBindString Status       $sub_status
	tpBindString VoidReason   [db_get_col $res 0 void_reason]
	tpBindString BetDate      [db_get_col $res 0 betdate]
	tpBindString StakePerLine [db_get_col $res 0 stake]
	tpBindString Output       [db_get_col $res 0 output]
	tpBindString GameType     [db_get_col $res 0 sort]
	tpBindString Results      [db_get_col $res 0 results]
	tpBindString ccyCode      [db_get_col $res 0 ccy_code]
	tpBindString CompNo	      [db_get_col $res 0 comp_no]
	tpBindString DrawAt	      [db_get_col $res 0 draw_at]
	tpBindString GameName 	  [db_get_col $res 0 name]
	tpBindString LineNumber	  [db_get_col $res 0 line_no]
	tpBindString Operator 	  [db_get_col $res 0 operator]
	tpBindString SubReceipt   [db_get_col $res 0 receipt]

	##new values re bettypes
	tpBindString bet_type 	  [db_get_col $res 0 bet_type]
	tpBindString stake_per_line 	  [db_get_col $res 0 stake_per_line]
	tpBindString num_selns 	  [db_get_col $res 0 num_selns]
	tpBindString num_lines 	  [db_get_col $res 0 num_lines]
	tpBindString num_lines_void 	  [db_get_col $res 0 num_lines_void]
	tpBindString num_lines_win 	  [db_get_col $res 0 num_lines_win]
	tpBindString num_lines_lose 	  [db_get_col $res 0 num_lines_lose]
	tpBindString prices 	  [db_get_col $res 0 prices]
	tpBindString settled_how 	  [db_get_col $res 0 settled_how]
	tpBindString settle_info 	  [db_get_col $res 0 settle_info]
	tpBindString BT_betType 	    [db_get_col $res 0 bet_type]
	tpBindString BT_numSelns 	    [db_get_col $res 0 num_selns]
	tpBindString BT_stakePerLine	[db_get_col $res 0 stake_per_line]

	set settled_by [db_get_col $res 0 settled_by]

	tpSetVar bet_status	[db_get_col $res 0 bet_status]
	tpSetVar IS_ELITE $elite
	##


	if {[db_get_col $res 0 output] == "N"} {
		# can void these
		tpSetVar output 0
	} else {
		# can't void these - file already exported
		tpSetVar output 1
	}

	if {[db_get_col $res 0 settled] == "Y"} {
		tpSetVar settled 1
		tpBindString SettledAt    [db_get_col $res 0 settled_at]
		tpBindString Winnings     [db_get_col $res 0 winnings]
		tpBindString Refunds      [db_get_col $res 0 refund]
		tpBindString PayMethod    $pay_method
	} else {
		tpSetVar settled 0
	}

	db_close $res

	set sql [subst {
		select
			username
		from
			tadminuser
		where
			user_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $settled_by]

	set nrows [db_get_nrows $res]

	if {$nrows>0} {
		tpBindString settled_by_uname [db_get_col $res 0 username]
		tpBindString settled_by_uid $settled_by
	}

	inf_close_stmt $stmt
	db_close $res

	set sql [subst {
		select
			xgame_bet_id,
			winnings,
			refund,
			num_lines_win,
			num_lines_lose,
			num_lines_void,
			settle_info
		from
			tXGBetStlPending
		where
			xgame_bet_id =?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	set nrows [db_get_nrows $res]

	if {$nrows>0} {
		tpBindString P_Winnings [db_get_col $res 0 winnings]
		tpBindString P_Refund [db_get_col $res 0 refund]
		tpBindString P_NumLinesWin [db_get_col $res 0 num_lines_win]
		tpBindString P_NumLinesLose [db_get_col $res 0 num_lines_lose]
		tpBindString P_NumLinesVoid [db_get_col $res 0 num_lines_void]
	}

	inf_close_stmt $stmt
	db_close $res

	set sql_p [subst {
		select
			p.status,
			p.pmt_id,
			p.call_id
		from
			tXGameSub s,
			tPmt p
		where
			s.xgame_sub_id = ? and
			s.call_id = p.call_id

	}]

	set stmt [inf_prep_sql $DB $sql_p]
	set res  [inf_exec_stmt $stmt $sub_id]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		switch -- [db_get_col $res $r status] {
			"Y" {set pmt_status " Success"}
			"N" {set pmt_status " Failed"}
			"P" {set pmt_status " Pending"}
			"R" {set pmt_status " Referred"}
			"L" {set pmt_status " Later"}
			default {set pmt_status " Unknown"}
		}

		set PMT($r,pmt_status) $pmt_status
		set PMT($r,pmt_id)     [db_get_col $res $r pmt_id]
		set PMT($r,call_id)    [db_get_col $res $r call_id]

	}

	db_close $res

	tpSetVar num_pmts $nrows

	tpBindVar PmtStatus PMT pmt_status pmt_idx
	tpBindVar PmtID     PMT pmt_id     pmt_idx
	tpBindVar CallID    PMT call_id    pmt_idx

	set sql [subst {
		select count(override_id)
		from tOverride
		where ref_id = ? and
		ref_key = 'XGAM'}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $sub_id]

	inf_close_stmt $stmt

	set num_or [db_get_col $res 0 "(count)"]
	tpSetVar bet_number_of_overrides $num_or

	db_close $res
	if {$num_or != 0} {
		tpBindString bet_number_of_overrides_str $num_or
	} else {
		tpBindString bet_number_of_overrides_str "none"
	}

	bind_man_adj "XBET" $bet_id

	asPlayFile -nocache xgame_bet_receipt.html

	#unset PMT
}


#
# ----------------------------------------------------------------------------
# Manually settle a bet - the stored procedure does all the work...
# ----------------------------------------------------------------------------
#
proc do_manual_settle args {

	global USERNAME USERID

	set op_name      [reqGetArg SubmitName]
	set bet_id       [reqGetArg BetId]
	set bet_type     [reqGetArg BetType]
	set win_lines    [reqGetArg BetWinLines]
	set lose_lines   [reqGetArg BetLoseLines]
	set void_lines   [reqGetArg BetVoidLines]
	set winnings     [reqGetArg BetWinnings]
	set winnings_tax [reqGetArg BetWinningsTax]
	set refund       [reqGetArg BetRefund]
	set comment      [string trim [reqGetArg BetComment]]

	set ret [ob_settle::do_settle_bet \
		$USERNAME \
		$USERID \
		$op_name \
		$bet_id \
		$bet_type \
		$win_lines \
		$lose_lines \
		$void_lines \
		$winnings \
		$winnings_tax \
		$refund \
		$comment \
	]

	if {[lindex $ret 0] == 0} {
		err_bind [lindex $ret 1]
	}

	#
	# Re-play the receipt page
	#
	go_bet_receipt
}

#
# ----------------------------------------------------------------------------
# Manually settle a pools bet - the stored procedure does all the work.. I hope
# ----------------------------------------------------------------------------
#
proc do_pools_manual_settle args {

	global USERNAME

	set op_name    [reqGetArg SubmitName]
	set bet_id     [reqGetArg BetId]
	set win_lines  [reqGetArg BetWinLines]
	set lose_lines [reqGetArg BetLoseLines]
	set void_lines [reqGetArg BetVoidLines]
	set winnings   [reqGetArg BetWinnings]
	set refund     [reqGetArg BetRefund]
	set comment    [string trim [reqGetArg BetComment]]

	set ret [ob_settle::do_settle_pools_bet \
		$USERNAME \
		$op_name \
		$bet_id \
		$win_lines \
		$lose_lines \
		$void_lines \
		$winnings \
		$refund \
		$comment \
	]

	if {[lindex $ret 0] == 0} {
		err_bind [lindex $ret 1]
	}

	go_pools_receipt
}


#
# ----------------------------------------------------------------------------
# Manually settle an xgame bet - the stored procedure does all the work...
# ----------------------------------------------------------------------------
#
proc do_xgame_manual_settle args {

	global USERNAME USERID

	set bet_id   [reqGetArg BetId]
	set op_name  [reqGetArg SubmitName]
	set winnings [reqGetArg BetWinnings]
	set refund   [reqGetArg BetRefund]
	set comment  [string trim [reqGetArg BetComment]]

	set ret [ob_settle::do_settle_xgame_bet \
		$USERNAME \
		$USERID \
		$bet_id \
		$op_name \
		$winnings \
		$refund \
		$comment \
	]

	if {[lindex $ret 0] == 0} {
		err_bind [lindex $ret 1]
	}

	go_xgame_receipt
}

#
# ----------------------------------------------------------------------------
# Display all bets (and calls) which have override set (pools)
# ----------------------------------------------------------------------------
#
proc do_retro_over_bet_pools args {

	global DB POOL_BET

	set select	     ""
	set where	     ""
	set from	     ""
	set nested_where     ""


	catch {unset BETS} err

	set date_lo  [reqGetArg ev_date_lo]
	set date_hi  [reqGetArg ev_date_hi]
	set date_sel [reqGetArg ev_date_range]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}

		if {$date_sel == "YEAR"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set m 1
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "MONTH"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "WEEK"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "3DAYS"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "YESTERDAY"} {
			if {[incr d -1] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "TODAY"} {
			set d_lo "'$dt 00:00:00'"
			set d_hi "'$dt 23:59:59'"
		}
	}

	# Override Type
	set override_type  [reqGetArg override_type]

	# Settled
	set settled  [reqGetArg settled]

	if {$settled != "-"}  {
		append where " and b.settled='$settled'"
	}

	# Elite customers

	set ELITE [reqGetArg EliteSearch]

	if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
		append where "and c.elite = 'Y'"
	}

	# Display Original Price & Set Where clauses

	if {[string length [set elitecust [string trim [reqGetArg DispOrigPrice]]]] > 0
		&& $override_type == "PriceOverride"} {
				tpBindString DispOrigPrice  1
		tpSetVar     DispOrigPrice  1

		append select ", op.p_num as old_num\
				   , op.p_den as old_den"

		append from ", tEvOcPrice op\
				 , tOverride ir"

		append where " and 	 s.ev_oc_id = op.ev_oc_id\
				   and	 b.pool_bet_id = ir.ref_id\
				   and 	 ir.leg_no = o.leg_no\
				   and 	 ir.cr_date between $d_lo and $d_hi\
				   and       op.cr_date in (\
						  	select max(iop.cr_date)\
						  	from tEvOcPrice iop\
						  	where iop.ev_oc_id = s.ev_oc_id and\
							          iop.cr_date < b.cr_date )"

		if {$override_type != ""} {
			append where "and ir.action = '$override_type'"
		}


		} else {
		tpBindString DispOrigPrice  0
		tpSetVar     DispOrigPrice  0

		append nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		append where " and b.pool_bet_id in (\
					select\
						pb.pool_bet_id\
					from\

						tPoolBet pb,\
						tPBet sp,\
						tOverride sr,\
						tEvOc ss,\
						tEv se\
					where\
						pb.bet_type <> 'MAN' and\
						sr.ref_id = pb.pool_bet_id and\
						pb.pool_bet_id = sp.pool_bet_id and\
						sp.ev_oc_id = ss.ev_oc_id and\
						sp.part_no = 1 and\
						ss.ev_id = se.ev_id\
						$nested_where\
				)"
	}

	#
	# Pull out the bets placed after one of the constituent
	# selctions "started"
	#

	set sql [subst {
		select
			b.pool_bet_id,
			b.cr_date,
			b.stake,
			b.settled,
			b.num_legs,
			b.num_lines,
			b.receipt,
			b.winnings,
			b.bet_type bet_type,
			b.ccy_stake,
			b.refund,
			b.status,
			(b.stake / b.num_lines) unitstake,
			o.pool_id,
			o.leg_no,
			o.part_no,
			o.ev_oc_id,
			o.banker_info,
			s.desc as seln_name,
			m.name,
			s.result,
			s.place,
			r.fname,
			r.lname,
			c.cust_id,
			c.acct_no,
			c.username,
			c.elite,
			e.desc as ev_name,
			e.start_time as ev_time,
			e.ev_id,
			p.pool_id,
			p.rec_dividend,
			t.name as pool_name,
			a.ccy_code,
			et.name as meeting_name,
			ps.ccy_code as pool_ccy_code,
			p.result_conf as pool_conf
			$select
		from
			tPoolBet b,
			tPBet o,
			tEvOc s,
			tEvOcGrp g,
			tEvMkt m,
			tPool p,
			tEv e,
			tPoolSource ps,
			tPoolType t,
			tAcct a,
			tCustomer c,
			tevtype et,
			outer tCustomerReg r
			$from
		where
			o.pool_bet_id = b.pool_bet_id
			and s.ev_oc_id = o.ev_oc_id
			and s.ev_id = e.ev_id
			and g.ev_oc_grp_id = m.ev_oc_grp_id
			and m.ev_mkt_id = s.ev_mkt_id
			and p.pool_id = o.pool_id
			and g.ev_type_id = et.ev_type_id
			and t.pool_type_id = p.pool_type_id
			and t.pool_source_id = p.pool_source_id
			and b.acct_id = a.acct_id
			and a.cust_id = c.cust_id
			and r.cust_id = c.cust_id
			and a.owner   <> 'D'
			$where
			order by
				b.pool_bet_id asc,
				p.pool_id asc,
				b.cr_date asc,
				o.leg_no asc,
				o.part_no asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	#tpSetVar NumPoolBets $nrows

	# Make necessary bindings
	if {$nrows > 0} {
		bind_pools_bet_list $res
	}

	db_close $res

	tpSetVar OverrideType $override_type

	# Now we've got all the appropriate bets with overrides in place, lets
	# go and see if there are any calls with overrides that we can grab.
	# We should already have the date and all that good stuff sorted....

	if {$nrows == 0 || $override_type == ""} {

		set nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		set where " and l.call_id in (\
					select\
						sl.call_id\
					from\
						tCall sl,\
						tOverride sr\
					where\
						sr.call_id = sl.call_id and\
						sr.ref_id is null and\
						sr.call_id is not null\
						$nested_where\
			)"


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
				l.oper_id     = u.user_id
				and l.acct_id     = a.acct_id
				and a.cust_id     = c.cust_id
				and a.cust_id     = r.cust_id
				$where
			order by
				l.call_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCalls [set NumCalls [db_get_nrows $rs]]

		tpBindTcl CustId      sb_res_data $rs call_idx cust_id
		tpBindTcl Username    sb_res_data $rs call_idx username
		tpBindTcl FName       sb_res_data $rs call_idx fname
		tpBindTcl LName       sb_res_data $rs call_idx lname
		tpBindTcl Date        sb_res_data $rs call_idx cr_date
		tpBindTcl Acct        sb_res_data $rs call_idx acct_no
		tpBindTcl CallId      sb_res_data $rs call_idx call_id
		tpBindTcl Operator    sb_res_data $rs call_idx operator
		tpBindTcl Source      sb_res_data $rs call_idx source
		tpBindTcl TermCode    sb_res_data $rs call_idx term_code
		tpBindTcl Telephone   sb_res_data $rs call_idx telephone
		tpBindTcl StartTime   sb_res_data $rs call_idx start_time
		tpBindTcl EndTime     sb_res_data $rs call_idx end_time
		tpBindTcl BetNum      sb_res_data $rs call_idx num_bets
		tpBindTcl GrpNum      sb_res_data $rs call_idx num_bet_grps
		tpBindTcl CancelCode  sb_res_data $rs call_idx cancel_code
		tpBindTcl CancelText  sb_res_data $rs call_idx cancel_txt

		asPlayFile -nocache bet_list_retro_pools.html
		db_close $rs

	} else {
		asPlayFile -nocache bet_list_retro_pools.html
	}
	catch {unset POOL_BET}
}
#
# ----------------------------------------------------------------------------
# Display all bets (and calls) which have override set (xgames)
# ----------------------------------------------------------------------------
#
proc do_retro_over_bet_xgames args {

	global DB BET
	global RETRO_XG_BETS

	set select	     ""
	set where	     ""
	set from	     ""
	set nested_where     ""


	# Event suspend date

	set date_lo  [reqGetArg ev_date_lo]
	set date_hi  [reqGetArg ev_date_hi]
	set date_sel [reqGetArg ev_date_range]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}

		if {$date_sel == "YEAR"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set m 1
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "MONTH"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "WEEK"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "3DAYS"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "YESTERDAY"} {
			if {[incr d -1] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "TODAY"} {
			set d_lo "'$dt 00:00:00'"
			set d_hi "'$dt 23:59:59'"
		}
	}

	# Override Type
	set override_type  [reqGetArg override_type]

	# Settled
	set settled  [reqGetArg settled]

	if {$settled != "-"}  {
		append where "and b.settled='$settled'"
	}

	# Elite customers
		if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
				append where "and c.elite = 'Y'"
		}

	# Display Original Price & Set Where clauses


	tpBindString DispOrigPrice  0
	tpSetVar     DispOrigPrice  0

	append nested_where\
		"and sr.cr_date between $d_lo and $d_hi"

	if {$override_type != ""} {
		append nested_where "and sr.action = '$override_type'"
	}

	append where "and s.xgame_sub_id in (\
				select\
					sb.xgame_sub_id\
				from\
					tXGameSub sb,\
					tOverride sr\
				where\
					sb.bet_type <> 'MAN' and\
					sr.ref_key == 'XGAM' and\
					sb.xgame_sub_id = sr.ref_id\
					$nested_where\
				)"


	#
	# Pull out the bets placed after one of the constituent
	# selctions "started"
	#

	set sql [subst {
		select
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
					g.comp_no,
					s.num_subs,
					s.picks,
					NVL(g.results,'-') as results,
					d.name,
					b.bet_type,
					s.prices
			$select

			from
					txgameBet b,
					txgamesub s,
					tAcct a,
					tCustomer c,
					txgame g,
					txgamedef d
			$from

			where
					b.xgame_sub_id = s.xgame_sub_id
				and
					s.acct_id = a.acct_id
				and
					a.cust_id = c.cust_id
				and
					b.xgame_id = g.xgame_id
				and
					g.sort = d.sort
				and
					a.owner <> 'D'
				$where
		order by
			b.cr_date desc
		}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	tpSetVar NumBets $nrows

	# Make necessary bindings
	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {

			set RETRO_XG_BETS($r,xgame_sub_id)  [db_get_col $res $r xgame_sub_id]
			set RETRO_XG_BETS($r,xgame_bet_id)  [db_get_col $res $r xgame_bet_id]
			set RETRO_XG_BETS($r,username)      [db_get_col $res $r username]
			set RETRO_XG_BETS($r,acct_no)       [db_get_col $res $r acct_no]
			set RETRO_XG_BETS($r,cr_date)       [db_get_col $res $r cr_date]
			set RETRO_XG_BETS($r,settled)       [db_get_col $res $r settled]
			set RETRO_XG_BETS($r,sort)          [db_get_col $res $r sort]
			set RETRO_XG_BETS($r,ccy_code)      [db_get_col $res $r ccy_code]
			set RETRO_XG_BETS($r,cust_id)       [db_get_col $res $r cust_id]
			set RETRO_XG_BETS($r,stake)         [db_get_col $res $r stake]
			set RETRO_XG_BETS($r,winnings)      [db_get_col $res $r winnings]
			set RETRO_XG_BETS($r,refund)        [db_get_col $res $r refund]
 			set RETRO_XG_BETS($r,comp_no)       [db_get_col $res $r comp_no]
			set RETRO_XG_BETS($r,num_subs)      [db_get_col $res $r num_subs]
			set RETRO_XG_BETS($r,picks)         [db_get_col $res $r picks]
			set RETRO_XG_BETS($r,results)       [db_get_col $res $r results]
			set RETRO_XG_BETS($r,name)          [db_get_col $res $r name]
			set RETRO_XG_BETS($r,bet_type)	    [db_get_col $res $r bet_type]
			set RETRO_XG_BETS($r,prices)        [db_get_col $res $r prices]
			}

			tpSetVar nrows $nrows

		tpBindVar   SubId       RETRO_XG_BETS   xgame_sub_id    bet_idx
		tpBindVar   BetId       RETRO_XG_BETS   xgame_bet_id    bet_idx
		tpBindVar   UName       RETRO_XG_BETS   username        bet_idx
		tpBindVar   AcctNo      RETRO_XG_BETS   acct_no         bet_idx
		tpBindVar   CRDate      RETRO_XG_BETS   cr_date         bet_idx
		tpBindVar   Settled     RETRO_XG_BETS   settled         bet_idx
		tpBindVar   Sort        RETRO_XG_BETS   sort            bet_idx
		tpBindVar   CcyCode     RETRO_XG_BETS   ccy_code        bet_idx
		tpBindVar   CustId      RETRO_XG_BETS   cust_id         bet_idx
		tpBindVar   Stake       RETRO_XG_BETS   stake           bet_idx
		tpBindVar   Winnings    RETRO_XG_BETS   winnings        bet_idx
		tpBindVar   Refund      RETRO_XG_BETS   refund          bet_idx
		tpBindVar   CompNo      RETRO_XG_BETS   comp_no         bet_idx
		tpBindVar   NumSubs     RETRO_XG_BETS   num_subs        bet_idx
		tpBindVar   Picks       RETRO_XG_BETS   picks           bet_idx
		tpBindVar   Results     RETRO_XG_BETS   results         bet_idx
		tpBindVar   Name        RETRO_XG_BETS   name            bet_idx
		tpBindVar   BetType     RETRO_XG_BETS   bet_type        bet_idx
		tpBindVar   Prices     	RETRO_XG_BETS   prices        	bet_idx
}

	db_close $res

	tpSetVar OverrideType $override_type

# Now we've got all the appropriate bets with overrides in place, lets
# go and see if there are any calls with overrides that we can grab.
# We should already have the date and all that good stuff sorted....

	if {$nrows == 0 || $override_type == ""} {

		set nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		set where " and l.call_id in (\
					select\
						sl.call_id\
					from\
						tCall sl,\
						tOverride sr\
					where\
						sr.call_id = sl.call_id and\
						sr.ref_id is null and\
						sr.call_id is not null\
						$nested_where\
			)"


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
				l.oper_id     = u.user_id
				and l.acct_id     = a.acct_id
				and a.cust_id     = c.cust_id
				and a.cust_id     = r.cust_id
				$where
			order by
				l.call_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCalls [set NumCalls [db_get_nrows $rs]]

		tpBindTcl CustId      sb_res_data $rs call_idx cust_id
		tpBindTcl Username    sb_res_data $rs call_idx username
		tpBindTcl FName       sb_res_data $rs call_idx fname
		tpBindTcl LName       sb_res_data $rs call_idx lname
		tpBindTcl Date        sb_res_data $rs call_idx cr_date
		tpBindTcl Acct        sb_res_data $rs call_idx acct_no
		tpBindTcl CallId      sb_res_data $rs call_idx call_id
		tpBindTcl Operator    sb_res_data $rs call_idx operator
		tpBindTcl Source      sb_res_data $rs call_idx source
		tpBindTcl TermCode    sb_res_data $rs call_idx term_code
		tpBindTcl Telephone   sb_res_data $rs call_idx telephone
		tpBindTcl StartTime   sb_res_data $rs call_idx start_time
		tpBindTcl EndTime     sb_res_data $rs call_idx end_time
		tpBindTcl BetNum      sb_res_data $rs call_idx num_bets
		tpBindTcl GrpNum      sb_res_data $rs call_idx num_bet_grps
		tpBindTcl CancelCode  sb_res_data $rs call_idx cancel_code
		tpBindTcl CancelText  sb_res_data $rs call_idx cancel_txt

		asPlayFile -nocache bet_list_retro_override_xgames.html
		db_close $rs

	} else {
		asPlayFile -nocache bet_list_retro_override_xgames.html
	}
	catch {unset RETRO_XG_BETS}
}

#
# ----------------------------------------------------------------------------
# Display all bets (and calls) which have override set
# ----------------------------------------------------------------------------
#
proc do_retro_over_bet args {

	global DB BET CALLS

	set select	     ""
	set where	     ""
	set from	     ""
	set nested_where     ""


	# Event suspend date

	set date_lo  [reqGetArg ev_date_lo]
	set date_hi  [reqGetArg ev_date_hi]
	set date_sel [reqGetArg ev_date_range]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}

		if {$date_sel == "YEAR"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set m 1
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "MONTH"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "WEEK"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "3DAYS"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "YESTERDAY"} {
			if {[incr d -1] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "TODAY"} {
			set d_lo "'$dt 00:00:00'"
			set d_hi "'$dt 23:59:59'"
		}
	}

	# Override Type
	set override_type  [reqGetArg override_type]

	# Settled
	set settled  [reqGetArg settled]

	if {$settled != "-"}  {
		append where " and b.settled='$settled'"
	}

	# Elite customers
		if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
				append where "and c.elite = 'Y'"
		}

	# Display Original Price & Set Where clauses
	if {[string length [set elitecust [string trim [reqGetArg DispOrigPrice]]]] > 0
		&& $override_type == "PriceOverride"} {
				tpBindString DispOrigPrice  1
		tpSetVar     DispOrigPrice  1

		append select ", op.p_num as old_num\
				   , op.p_den as old_den"

		append from ", tEvOcPrice op\
				 , tOverride r"

		append where " and 	 s.ev_oc_id = op.ev_oc_id\
				   and	 b.bet_id = r.ref_id\
				   and 	 r.leg_no = o.leg_no\
				   and 	 r.cr_date between $d_lo and $d_hi\
				   and       op.cr_date in (\
						  	select max(iop.cr_date)\
						  	from tEvOcPrice iop\
						  	where iop.ev_oc_id = s.ev_oc_id and\
							          iop.cr_date < b.cr_date )"

		if {$override_type != ""} {
			append where "and r.action = '$override_type'"
		}

		} else {
		tpBindString DispOrigPrice  0
		tpSetVar     DispOrigPrice  0

		append nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		append where " and b.bet_id in (\
					select\
						sb.bet_id\
					from\
						tBet sb,\
						tOBet so,\
						tOverride sr,\
						tEvOc ss,\
						tEv se\
					where\
						sb.bet_type <> 'MAN' and\
						sr.ref_id = sb.bet_id and\
						sb.bet_id = so.bet_id and\
						so.ev_oc_id = ss.ev_oc_id and\
						so.part_no = 1 and\
						ss.ev_id = se.ev_id\
						$nested_where\
				)"
	}

	#
	# Pull out the bets placed after one of the constituent
	# selctions "started"
	#
	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			e.desc ev_name,
			e.start_time,
			m.name mkt_name,
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
			o.o_den o_den,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
				then "H"
				else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
				then ocrH.rep_code
				else ocrF.rep_code
			end as rep_code
			$select
		from
			tBet b,
			tOBet o,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
			$from
		where
			b.bet_id = o.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			a.owner <> 'D' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
			$where
		order by
			o.bet_id desc,o.leg_no asc,o.part_no asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	tpSetVar NumBets $nrows

	# Make necessary bindings
	if {$nrows > 0} {
		bind_sports_bet_list $res 0 1
	}

	db_close $res

	tpSetVar OverrideType $override_type

# Now we've got all the appropriate bets with overrides in place, lets
# go and see if there are any calls with overrides that we can grab.
# We should already have the date and all that good stuff sorted....

	if {$nrows == 0 || $override_type == ""} {

		set nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		set where " and l.call_id in (\
					select\
						sl.call_id\
					from\
						tCall sl,\
						tOverride sr\
					where\
						sr.call_id = sl.call_id and\
						sr.ref_id is null and\
						sr.call_id is not null\
						$nested_where\
			)"


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
				c.elite,
				r.fname,
				r.lname
			from
				tCall l,
				tAcct a,
				tAdminUser u,
				tCustomer c,
				tCustomerReg r
			where
				l.oper_id     = u.user_id
				and l.acct_id     = a.acct_id
				and a.cust_id     = c.cust_id
				and a.cust_id     = r.cust_id
				$where
			order by
				l.call_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCalls [set NumCalls [db_get_nrows $rs]]

		if {$NumCalls > 0} {
			for {set r 0} {$r < $NumCalls} {incr r} {
				set CALLS($r,cust_id)      [db_get_col $rs $r cust_id]
				set CALLS($r,username)     [db_get_col $rs $r username]
				set CALLS($r,fname)        [db_get_col $rs $r fname]
				set CALLS($r,lname)        [db_get_col $rs $r lname]
				set CALLS($r,acct_no)      [db_get_col $rs $r acct_no]
				set CALLS($r,elite)        [db_get_col $rs $r elite]
				set CALLS($r,call_id)      [db_get_col $rs $r call_id]
				set CALLS($r,operator)     [db_get_col $rs $r operator]
				set CALLS($r,source)       [db_get_col $rs $r source]
				set CALLS($r,term_code)    [db_get_col $rs $r term_code]
				set CALLS($r,telephone)    [db_get_col $rs $r telephone]
				set CALLS($r,start_time)   [db_get_col $rs $r start_time]
				set CALLS($r,end_time)     [db_get_col $rs $r end_time]
				set CALLS($r,num_bets)     [db_get_col $rs $r num_bets]
				set CALLS($r,num_bet_grps) [db_get_col $rs $r num_bet_grps]
				set CALLS($r,cancel_code)  [db_get_col $rs $r cancel_code]
				set CALLS($r,cancel_txt)   [db_get_col $rs $r cancel_txt]
			}

			tpBindVar CustId     CALLS cust_id      call_idx
			tpBindVar Username   CALLS username     call_idx
			tpBindVar FName      CALLS fname        call_idx
			tpBindVar LName      CALLS lname        call_idx
			tpBindVar LName      CALLS lname        call_idx
			tpBindVar Date       CALLS cr_date      call_idx
			tpBindVar Acct       CALLS acct_no      call_idx
			tpBindVar Elite      CALLS elite        call_idx
			tpBindVar CallId     CALLS call_id      call_idx
			tpBindVar Operator   CALLS operator     call_idx
			tpBindVar Source     CALLS source       call_idx
			tpBindVar TermCode   CALLS term_code    call_idx
			tpBindVar Telephone  CALLS telephone    call_idx
			tpBindVar StartTime  CALLS start_time   call_idx
			tpBindVar EndTime    CALLS end_time     call_idx
			tpBindVar BetNum     CALLS num_bets     call_idx
			tpBindVar GrpNum     CALLS num_bet_grps call_idx
			tpBindVar CancelCode CALLS cancel_code  call_idx
			tpBindVar CancelText CALLS cancel_txt   call_idx

		}

		asPlayFile -nocache bet_list_retro.html
		db_close $rs

	} else {
		asPlayFile -nocache bet_list_retro.html
	}
	catch {unset BET}
	catch {unset CALLS}
}

#
# ----------------------------------------------------------------------------
# Display all unsettled xgame bets
# ----------------------------------------------------------------------------
#

proc do_retro_xgame_bet args {
	global DB

	global RETRO_XG_BETS

	if {[info exists RETRO_XG_BETS]} {
		unset RETRO_XG_BETS
	}

	#
	# Event start dates
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]

	if {([string length $bd1] > 0) && ([string length $bd2] > 0)} {

		set where_bet_cr_date "b.cr_date > '$bd1 00:00:00' and b.cr_date < '$bd2 00:00:00' and"

	} elseif {([string length $bd1] > 0) || ([string length $bd2] > 0)} {

		if {[string length $bd1]} {

			set where_bet_cr_date "b.cr_date > '$bd1 00:00:00' and"

		} elseif {[string length $bd2]} {

			set where_bet_cr_date "b.cr_date < '$bd2 00:00:00' and"

		}
	} else {
		set where_bet_cr_date ""
	}

	set elite_search [reqGetArg EliteSearch]

	if {$elite_search=="Y"} {
		set eliteonly "and c.elite = 'Y'"
	} else {
		set eliteonly ""
	}

	set sql [subst {
		select
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
			g.comp_no,
			s.num_subs,
			s.picks,
			NVL(g.results,'-') as results,
			d.name,
			b.bet_type,
			s.prices
		from
			txgameBet b,
			txgamesub s,
			tAcct a,
			tCustomer c,
			txgame g,
			txgamedef d
		where

			$where_bet_cr_date

			b.xgame_sub_id = s.xgame_sub_id
		and
			s.acct_id = a.acct_id
		and
			a.cust_id = c.cust_id
		and
			b.xgame_id = g.xgame_id
		and
			g.sort = d.sort
		and
			b.cr_date > g.shut_at
		and
			b.settled = 'N'
		and
			a.owner   <> 'D'
		$eliteonly
		order by b.cr_date desc
	}]

	#OT_LogWrite 1 "$sql"

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {

			set RETRO_XG_BETS($r,xgame_sub_id)  [db_get_col $res $r xgame_sub_id]
			set RETRO_XG_BETS($r,xgame_bet_id)  [db_get_col $res $r xgame_bet_id]
			set RETRO_XG_BETS($r,username)      [db_get_col $res $r username]
			set RETRO_XG_BETS($r,acct_no)       [db_get_col $res $r acct_no]
			set RETRO_XG_BETS($r,cr_date)       [db_get_col $res $r cr_date]
			set RETRO_XG_BETS($r,settled)       [db_get_col $res $r settled]
			set RETRO_XG_BETS($r,sort)          [db_get_col $res $r sort]
			set RETRO_XG_BETS($r,ccy_code)      [db_get_col $res $r ccy_code]
			set RETRO_XG_BETS($r,cust_id)       [db_get_col $res $r cust_id]
			set RETRO_XG_BETS($r,stake)         [db_get_col $res $r stake]
			set RETRO_XG_BETS($r,winnings)      [db_get_col $res $r winnings]
			set RETRO_XG_BETS($r,refund)        [db_get_col $res $r refund]
			set RETRO_XG_BETS($r,comp_no)       [db_get_col $res $r comp_no]
			set RETRO_XG_BETS($r,num_subs)      [db_get_col $res $r num_subs]
			set RETRO_XG_BETS($r,picks)         [db_get_col $res $r picks]
			set RETRO_XG_BETS($r,results)       [db_get_col $res $r results]
			set RETRO_XG_BETS($r,name)          [db_get_col $res $r name]
			set RETRO_XG_BETS($r,bet_type)      [db_get_col $res $r bet_type]
			set RETRO_XG_BETS($r,prices)      [db_get_col $res $r prices]
		}

		tpSetVar nrows $nrows

		tpBindVar   SubId       RETRO_XG_BETS   xgame_sub_id    bet_idx
		tpBindVar   BetId       RETRO_XG_BETS   xgame_bet_id    bet_idx
		tpBindVar   UName       RETRO_XG_BETS   username        bet_idx
		tpBindVar   AcctNo      RETRO_XG_BETS   acct_no         bet_idx
		tpBindVar   CRDate      RETRO_XG_BETS   cr_date         bet_idx
		tpBindVar   Settled     RETRO_XG_BETS   settled         bet_idx
		tpBindVar   Sort        RETRO_XG_BETS   sort            bet_idx
		tpBindVar   CcyCode     RETRO_XG_BETS   ccy_code        bet_idx
		tpBindVar   CustId      RETRO_XG_BETS   cust_id         bet_idx
		tpBindVar   Stake       RETRO_XG_BETS   stake           bet_idx
		tpBindVar   Winnings    RETRO_XG_BETS   winnings        bet_idx
		tpBindVar   Refund      RETRO_XG_BETS   refund          bet_idx
		tpBindVar   CompNo      RETRO_XG_BETS   comp_no         bet_idx
		tpBindVar   NumSubs     RETRO_XG_BETS   num_subs        bet_idx
		tpBindVar   Picks       RETRO_XG_BETS   picks           bet_idx
		tpBindVar   Results     RETRO_XG_BETS   results         bet_idx
		tpBindVar   Name        RETRO_XG_BETS   name            bet_idx
		tpBindVar   BetType     RETRO_XG_BETS   bet_type        bet_idx
		tpBindVar   Prices     RETRO_XG_BETS   prices        bet_idx
	}

	db_close $res
	asPlayFile -nocache bet_list_retro_xgame.html
}

#
# ----------------------------------------------------------------------------
# Display all xgame bets (and calls) which have override set
# ----------------------------------------------------------------------------
#
proc do_retro_over_xgame_bet args {

	global DB BET

	set select	     ""
	set where	     ""
	set from	     ""
	set nested_where     ""

	# Event suspend date

	set date_lo  [reqGetArg ev_date_lo]
	set date_hi  [reqGetArg ev_date_hi]
	set date_sel [reqGetArg ev_date_range]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}

		if {$date_sel == "YEAR"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set m 1
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "MONTH"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d 1
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "WEEK"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "3DAYS"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "YESTERDAY"} {
			if {[incr d -1] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "TODAY"} {
			set d_lo "'$dt 00:00:00'"
			set d_hi "'$dt 23:59:59'"
		}
	}

	# Override Type
	set override_type  [reqGetArg override_type]

	# Elite customers
		if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
				append where "and c.elite = 'Y'"
		}

	append nested_where\
		"sr.cr_date between $d_lo and $d_hi"

	if {$override_type != ""} {
		append nested_where "and sr.action = '$override_type'"
	}

	append where " and s.xgame_sub_id in (\
				select\
					sb.xgame_sub_id\
				from\
					tXGameSub sb,\
					tOverride sr\
				where\
					sb.bet_type <> 'MAN' and\
					sr.ref_id = sb.xgame_sub_id and\
					$nested_where\
			)"

	#
	# Pull out the bets placed after one of the constituent
	# selctions "started"
	#

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			s.cr_date,
			s.xgame_sub_id as receipt,
			s.bet_type,
			s.num_subs,
			s.stake_per_line,
			s.status,
			s.num_lines,
			s.picks,
			d.name
		from
			tXGameSub s,
			tAcct a,
			tCustomer c,
			tXGame g,
			tXGameDef d
		where
			g.xgame_id = s.xgame_id and
			d.sort = g.sort and
			a.acct_id = s.acct_id and
			a.cust_id = c.cust_id and
			s.cr_date between $d_lo and $d_hi
			$where
		order by
			s.xgame_sub_id desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	tpSetVar NumBets $nrows

	# Make necessary bindings

	if {$nrows > 0} {
		bind_sports_bet_list $res
	}

	db_close $res

	tpSetVar OverrideType $override_type

# Now we've got all the appropriate bets with overrides in place, lets
# go and see if there are any calls with overrides that we can grab.
# We should already have the date and all that good stuff sorted....

	if {$nrows == 0 || $override_type == ""} {

		set nested_where\
			"and sr.cr_date between $d_lo and $d_hi"

		if {$override_type != ""} {
			append nested_where "and sr.action = '$override_type'"
		}

		set where " and l.call_id in (\
					select\
						sl.call_id\
					from\
						tCall sl,\
						tOverride sr\
					where\
						sr.call_id = sl.call_id and\
						sr.ref_id is null and\
						sr.call_id is not null\
						$nested_where\
			)"


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
				l.oper_id     = u.user_id
				and l.acct_id     = a.acct_id
				and a.cust_id     = c.cust_id
				and a.cust_id     = r.cust_id
				$where
			order by
				l.call_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCalls [set NumCalls [db_get_nrows $rs]]

		tpBindTcl CustId      sb_res_data $rs call_idx cust_id
		tpBindTcl Username    sb_res_data $rs call_idx username
		tpBindTcl FName       sb_res_data $rs call_idx fname
		tpBindTcl LName       sb_res_data $rs call_idx lname
		tpBindTcl Date        sb_res_data $rs call_idx cr_date
		tpBindTcl Acct        sb_res_data $rs call_idx acct_no
		tpBindTcl CallId      sb_res_data $rs call_idx call_id
		tpBindTcl Operator    sb_res_data $rs call_idx operator
		tpBindTcl Source      sb_res_data $rs call_idx source
		tpBindTcl TermCode    sb_res_data $rs call_idx term_code
		tpBindTcl Telephone   sb_res_data $rs call_idx telephone
		tpBindTcl StartTime   sb_res_data $rs call_idx start_time
		tpBindTcl EndTime     sb_res_data $rs call_idx end_time
		tpBindTcl BetNum      sb_res_data $rs call_idx num_bets
		tpBindTcl GrpNum      sb_res_data $rs call_idx num_bet_grps
		tpBindTcl CancelCode  sb_res_data $rs call_idx cancel_code
		tpBindTcl CancelText  sb_res_data $rs call_idx cancel_txt

		asPlayFile -nocache bet_list_retro.html
		db_close $rs

	} else {
		asPlayFile -nocache bet_list_retro.html
	}
	catch {unset BET}
}


#
# ----------------------------------------------------------------------------
# Display all bets which are not been settled but have some settled selns
# ----------------------------------------------------------------------------
#
proc do_retro_bet args {

	global DB BET

	#
	# Event start dates
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]

	set where_event_start ""
	set where_bet_cr_date ""

	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
		set where_event_start\
			"[mk_between_clause se.start_time date $bd1 $bd2] and"
		if {[string length $bd1] > 0} {
			set where_bet_cr_date "sb.cr_date > '$bd1 00:00:00' and"
		}
	}

	if {[string length [set retrochannel [string trim [reqGetArg RetroChannel]]]] > 0} {
		if {$retrochannel == "All"} {
			set source ""
		} elseif { $retrochannel == "PL" } {
			set source "and (b.source = 'P' or b.source = 'L')"
		} else {
			set source "and b.source = '$retrochannel'"
		}
	} else {
		set source ""
	}

	#
	# Pull out the bets placed after one of the constituent
	# selctions "started"
	#
	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			e.desc ev_name,
			e.start_time,
			m.name mkt_name,
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
			o.o_den o_den,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBet b,
			tOBet o,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tCall cl,
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
		where
			cl.call_id = b.call_id
			and cl.retro_term_code is not null
			and cl.retro_date      is not null
			and b.bet_id in (
				select
					sb.bet_id
				from
					tBetUnstl su,
					tBet sb,
					tOBet so,
					tEvOc ss,
					tEv se
				where
					su.bet_type <> 'MAN' and
					su.bet_id = sb.bet_id and
					$where_bet_cr_date
					sb.bet_id = so.bet_id and
					so.ev_oc_id = ss.ev_oc_id and
					so.part_no = 1 and
					ss.ev_id = se.ev_id and
					$where_event_start
					sb.cr_date > se.start_time and
					so.in_running != "Y"
			) and
			b.bet_id = o.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			a.owner <> 'Y' and
			a.owner <> 'D' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
			$source
		order by
			o.bet_id desc,o.leg_no asc,o.part_no asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]


	tpSetVar NumBets $nrows
	tpSetVar NumCalls 0

	if {$nrows > 0} {
		bind_sports_bet_list $res 0 1
	}

	db_close $res
	asPlayFile -nocache bet_list_retro.html
	catch {unset BET}
}

#
# ----------------------------------------------------------------------------
# Bets to be settled manually
# ----------------------------------------------------------------------------
#
proc do_manual_bet_query args {

	global DB BET

	set orderHow     [reqGetArg ManBetOrd]
	set from_sql     ""
	set to_sql       ""
	set from_sql_MAN ""
	set to_sql_MAN   ""
	set bd1          [reqGetArg BetDate1]
	set bd2          [reqGetArg BetDate2]
	set batch_ref_id [reqGetArg batch_ref_id]
	set man_only     [reqGetArg man_only]

	switch -- $orderHow {
		R {
			set ord_date_qry [subst {
				NVL((
					select
						max(ee.start_time)
					from
						tObet oo,
						tEvOc ss,
						tEv   ee
					where
						oo.bet_id = b.bet_id and
						oo.ev_oc_id = ss.ev_oc_id and
						ss.settled = 'Y' and
						ss.ev_id = ee.ev_id
				),(
					select
						min(ee.start_time)
					from
						tObet oo,
						tEvOc ss,
						tEv   ee
					where
						oo.bet_id = b.bet_id and
						oo.ev_oc_id = ss.ev_oc_id and
						ss.ev_id = ee.ev_id
				))
			}]
		}
		L {
			set ord_date_qry [subst {(
				select
					max(ee.start_time)
				from
					tObet oo,
					tEvOc ss,
					tEv   ee
				where
					oo.bet_id = b.bet_id and
					oo.ev_oc_id = ss.ev_oc_id and
					ss.ev_id = ee.ev_id
			)}]
		}
		E -
		default {
			set ord_date_qry [subst {(
				select
					min(ee.start_time)
				from
					tObet oo,
					tEvOc ss,
					tEv   ee
				where
					oo.bet_id = b.bet_id and
					oo.ev_oc_id = ss.ev_oc_id and
					ss.ev_id = ee.ev_id
			)}]
		}
	}

	if {$bd1 != "" && $bd2 != ""} {

		set time_sql [subst {
			and exists (
				select
					1
				from
					tobet iobet,
					tevoc ievoc,
					tev iev
				where
					b.bet_id = iobet.bet_id and
					ievoc.ev_oc_id = iobet.ev_oc_id and
					iev.ev_id = ievoc.ev_id and
					iev.start_time between '$bd1 00:00:00' and '$bd2 23:59:59'
			)
		}]
		set time_sql_MAN [subst {
			and o.to_settle_at between '$bd1 00:00:00' and '$bd2 23:59:59'
		}]

	} elseif {$bd1 != ""} {

		set time_sql [subst {
			and exists (
				select
					1
				from
					tobet iobet,
					tevoc ievoc,
					tev iev
				where
					b.bet_id = iobet.bet_id and
					ievoc.ev_oc_id = iobet.ev_oc_id and
					iev.ev_id = ievoc.ev_id and
					iev.start_time >= '$bd1 00:00:00'
			)
		}]
		set time_sql_MAN [subst {
			and o.to_settle_at >= '$bd1 00:00:00'
		}]

	} elseif {$bd2 != ""} {

		set time_sql [subst {
			and exists (
				select
					1
				from
					tobet iobet,
					tevoc ievoc,
					tev iev
				where
					b.bet_id = iobet.bet_id and
					ievoc.ev_oc_id = iobet.ev_oc_id and
					iev.ev_id = ievoc.ev_id and
					iev.start_time <= '$bd2 23:59:59'
			)
		}]
		set time_sql_MAN [subst {
			and o.to_settle_at <= '$bd2 23:59:59'
		}]

	} else {

		set time_sql     ""
		set time_sql_MAN ""
	}

	# look for manual bets by batch reference
	# note that this search does not search for
	# unsettled bets only
	if {[string length $batch_ref_id]} {
		set acct_where  ""
		set batch_where "and o.batch_ref_id = $batch_ref_id"
		set unstl_where ""
		set unstl_from  ""
	} else {
		set    acct_where "and a.owner <> 'Y'"
		set    batch_where ""
		set    unstl_from  ", tBetUnstl u"
		set    unstl_where "and u.bet_type = 'MAN'"
		append unstl_where "and u.bet_id   = b.bet_id"
	}

	if {$man_only != "Y"} {

		set non_man_qry [subst {
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			m.name mkt_name,
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
			''||o.o_num o_num,
			''||o.o_den o_den,
			$ord_date_qry ord_date,
			ec.name ev_class_name,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBetUnstl u,
			tBetType  bt,
			tBet      b,
			tOBet     o,
			tEvOc     s,
			tEv       e,
			tEvMkt    m,
			tEvOcGrp  g,
			tAcct     a,
			tCustomer c,
			tEvType   t,
			tEvClass  ec,
			outer (tHedgedBet hb, outer tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, outer tOnCourseRep ocrF)
		where
			u.bet_type not in ('SGL','DBL','TBL','MAN') and
			u.bet_type = bt.bet_type and
			bt.bet_settlement = 'Manual' and
			u.bet_id = b.bet_id and
			b.bet_id = o.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_id = e.ev_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			t.ev_type_id = e.ev_type_id and
			t.ev_class_id = ec.ev_class_id and
			a.owner <> 'D' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
			$acct_where
			$time_sql

		union all select
		}]
	} else {
		set non_man_qry ""
	}


	set sql [subst {
		select
			$non_man_qry
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			o.desc_1 ev_name,
			o.desc_2 mkt_name,
			o.desc_3 selnbatch_where_name,
			'-' result,
			0 ev_mkt_id,
			0 ev_oc_id,
			0 ev_id,
			o.bet_id,
			1 leg_no,
			1 part_no,
			'--' leg_sort,
			'L' price_type,
			'' o_num,
			'' o_den,
			o.to_settle_at ord_date,
			ec.name ev_class_name,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBet b,
			tManOBet o,
			tAcct a,
			tCustomer c,
			outer tEvClass ec,
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
			$unstl_from
		where
			b.bet_id  = o.bet_id  and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			o.ev_class_id = ec.ev_class_id and
			a.owner <> 'D' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
			$acct_where
			$time_sql_MAN
			$batch_where
			$unstl_where
		order by
			31 asc,24,25,26
		}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows == 1 && [db_get_col $res 0 bet_type] != "MAN"} {
		go_bet_receipt bet_id [db_get_col $res 0 bet_id]
		db_close $res
		return
	}

	tpSetVar UnstlManBet 1

	tpBindString ManBetOrd  $orderHow
	tpBindString BetDate1   $bd1
	tpBindString BetDate2   $bd2
	tpBindString BatchRefId $batch_ref_id
	tpBindString ManOnly    $man_only

	bind_sports_bet_list $res 1 1

	asPlayFile -nocache bet_list.html

	db_close $res

	unset BET
}


#
# ----------------------------------------------------------------------------
# Settle the retrospective bets
# ----------------------------------------------------------------------------
#
proc do_stl_retro_xgame_bet args {

	set nrows_settled 0
	set nrows_parked 0
	set nrows_failed 0

	set bet_ids [reqGetArgs settle_bet]

	foreach {bet_id} $bet_ids {
		set settled_parked [settle_bet_with_bet_type $bet_id]

		if {$settled_parked!=-1} {
			incr nrows_settled [lindex $settled_parked 0]
			incr nrows_parked [lindex $settled_parked 1]
			incr nrows_failed [lindex $settled_parked 2]
		}
	}

	#if {[info exists errors]} {
	#	foreach e $errors {
	#		handle_err "Error" "$e"
	#	}
	#	return
	#}

	tpBindString settled $nrows_settled
	tpBindString parked $nrows_parked
	tpBindString failed $nrows_failed

	asPlayFile -nocache xgame/xgame_settlement_done.html

	#handle_success "Retro Bets Settlement" "Settled $nrows_settled bet(s). $nrows_parked bet(s) parked"

	return
}

#
# ----------------------------------------------------------------------------
# Settle the retrospective bets
# ----------------------------------------------------------------------------
#
proc do_stl_retro_bet args {

	set bet_ids [reqGetArgs settle_bet]

	foreach {bet_id} $bet_ids {
		ADMIN::SETTLE::stl_settle bet $bet_id Y
	}

	return
}

#
# ----------------------------------------------------------------------------
# Pay for an antepost bet
# ----------------------------------------------------------------------------
#
proc pay_for_antepost_bet args {

	global DB USERID

	if {![op_allowed PayAntepost]} {
		err_bind "You do not have permission to pay for an antepost bet"
		go_bet_receipt
		return
	}

	set bet_id  [reqGetArg BetId]

	set sql [subst {
		execute procedure pAPStakeDebit(
			p_user_id       = ?,
			p_bet_id        = ?,
			p_transactional = 'Y',
			p_ap_op_type = 'APMT'
		)
	}]

	set stmt   [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt $USERID $bet_id} msg]} {
		err_bind $msg
	} else {
		msg_bind "AP stake paid successfully"
	}

	inf_close_stmt $stmt

	go_bet_receipt
}

#
# ----------------------------------------------------------------------------
# Display all the bets placed on Xgame
# ----------------------------------------------------------------------------
#
proc go_xgame_all_bets args {

	global DB BET

	set game_id [reqGetArg XGameID]

	set sql [subst {
		select
			s.xgame_sub_id,
			b.xgame_bet_id,
			b.xgame_id,
			s.picks,
			b.cr_date betdate,
			b.stake,
			b.winnings,
			b.refund,
			b.settled,
			c.username,
			c.acct_no,
			d.sort,
			c.cust_id,
			g.comp_no,
			d.name,
			NVL(g.results,'-') as results
		from
			tAcct a,
			tCustomer c,
			tXGameSub s,
			tXGameBet b,
			tXGame g,
			tXGameDef d
		where
			b.xgame_id = ? and
			a.cust_id = c.cust_id and
			a.acct_id = s.acct_id and
			s.xgame_sub_id = b.xgame_sub_id and
			b.xgame_id = g.xgame_id and
			g.sort = d.sort
		order by
			b.xgame_bet_id desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $game_id]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	#if only one bet in game
	if {$rows == 1} {
	   	tpSetVar NumBets [expr {$rows}]

		tpBindString GameId   $game_id
		tpBindString GameName [db_get_col $res 0 name]
		tpBindString CompNo	  [db_get_col $res 0 comp_no]
		tpBindString Results  [db_get_col $res 0 results]
		tpBindString SubId    [db_get_col $res 0 xgame_sub_id]
		tpBindString BetId    [db_get_col $res 0 xgame_bet_id]
		tpBindString CustId   [db_get_col $res 0 cust_id]
		tpBindString CustName [db_get_col $res 0 username]
		tpBindString AcctNo   [db_get_col $res 0 acct_no]
		tpBindString Picks    [db_get_col $res 0 picks]
		tpBindString BetDate  [db_get_col $res 0 betdate]
		tpBindString BetStake [db_get_col $res 0 stake]
		tpBindString GameType [db_get_col $res 0 sort]
		tpBindString Winnings [db_get_col $res 0 winnings]
		tpBindString Refund   [db_get_col $res 0 refund]
		tpBindString BetSettled  [db_get_col $res 0 settled]

		db_close $res

		asPlayFile -nocache xgame_bets.html

	} else {

	set b 0

	array set BET [list]
	for {set r 0} {$r < $rows} {incr r} {
		set BET($b,xgame_sub_id) [db_get_col $res $r xgame_sub_id]
		set BET($b,xgame_bet_id) [db_get_col $res $r xgame_bet_id]
		set BET($b,cust_id)   [db_get_col $res $r cust_id]
		set BET($b,cust_name) [db_get_col $res $r username]
		set BET($b,acct_no)   [db_get_col $res $r acct_no]
		set BET($b,picks)     [db_get_col $res $r picks]
		set BET($b,betdate)   [db_get_col $res $r betdate]
		set BET($b,stake)     [db_get_col $res $r stake]
		set BET($b,gametype)  [db_get_col $res $r sort]
		set BET($b,winnings)  [db_get_col $res $r winnings]
		set BET($b,refund)    [db_get_col $res $r refund]
		set BET($b,settled)   [db_get_col $res $r settled]

		incr b
	}

	tpSetVar NumBets [expr {$b+1}]
	tpBindString GameId   $game_id
	tpBindString GameName [db_get_col $res 0 name]
	tpBindString CompNo	  [db_get_col $res 0 comp_no]
	tpBindString Results  [db_get_col $res 0 results]

	db_close $res

	tpBindVar SubId       BET xgame_sub_id bet_idx
	tpBindVar BetId       BET xgame_bet_id bet_idx
	tpBindVar CustId      BET cust_id      bet_idx
	tpBindVar CustName	  BET cust_name    bet_idx
	tpBindVar AcctNo      BET acct_no      bet_idx
	tpBindVar Picks       BET picks	       bet_idx
	tpBindVar BetDate     BET betdate      bet_idx
	tpBindVar BetStake    BET stake        bet_idx
	tpBindVar GameType    BET gametype     bet_idx
	tpBindVar Winnings    BET winnings	   bet_idx
	tpBindVar Refund      BET refund  	   bet_idx
	tpBindVar BetSettled  BET settled      bet_idx

	asPlayFile -nocache xgame_bets.html

	unset BET
   }
}


#
# ----------------------------------------------------------------------------
# Display all the bets for the subscription
# ----------------------------------------------------------------------------
#
proc go_xgame_sub_query args {

	global DB BET

	set sub_id [reqGetArg SubId]

	if {[string first "L" $sub_id] != -1}   {
		set index [string last "/" $sub_id]
		incr index
		set sub_id [string range $sub_id $index end]
	}

	foreach {n v} $args {
		set $n $v
		if {$n == "sub_id"} {
			set sub_id $v
		}
	}
	set sql [subst {
		(select
			s.xgame_sub_id,
			b.xgame_bet_id,
			s.source src,
			s.cr_date subdate,
			s.num_subs,
			s.stake_per_bet,
			s.picks,
			s.status,
			s.authorized,
			length(s.draws)-length(replace(s.draws,"|",""))-1 as num_dif_draws,
			b.cr_date betdate,
			b.stake,
			b.winnings,
			b.refund,
			b.settled,
			c.username,
			c.cust_id,
			c.acct_no,
			c.elite,
			d.name,
			NVL(g.results,'-') as results,
			d.num_picks_max,
			d.sort,
			s.bet_type,
			s.num_selns,
			s.stake_per_line,
			dd.desc,
			s.receipt
		from
			tAcct a,
			tCustomer c,
			tXGameSub s,
			tXGameBet b,
			tXGame g,
			tXGameDef d,
			outer tXGameDrawdesc dd
		where
			b.xgame_sub_id = ? and
			a.cust_id = c.cust_id and
			a.acct_id = s.acct_id and
			s.xgame_sub_id = b.xgame_sub_id and
			b.xgame_id = g.xgame_id and
			dd.desc_id = g.draw_desc_id and
			g.sort = d.sort and
			s.authorized = 'Y')

		union
		(select
			s.xgame_sub_id,
			-1 as xgame_bet_id,
			s.source src,
			s.cr_date subdate,
			s.num_subs,
			s.stake_per_bet,
			s.picks,
			s.status,
			s.authorized,
			length(s.draws)-length(replace(s.draws,"|",""))-1 as num_dif_draws,
			s.cr_date betdate,
			0 as stake,
			0 as winnings,
			0 as refund,
			'-' as settled,
			c.username,
			c.cust_id,
			c.acct_no,
			c.elite,
			d.name,
			NVL(g.results,'-') as results,
			d.num_picks_max,
			d.sort,
			s.bet_type,
			s.num_selns,
			s.stake_per_line,
			dd.desc,
			s.receipt
		from
			tAcct a,
			tCustomer c,
			tXGameSub s,
			tXGame g,
			tXGameDef d,
			outer tXGameDrawdesc dd
		where
			s.xgame_sub_id = ? and
			a.cust_id = c.cust_id and
			a.acct_id = s.acct_id and
			s.xgame_id = g.xgame_id and
			g.sort = d.sort and
			dd.desc_id = g.draw_desc_id and
			s.authorized = 'N')
		}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $sub_id $sub_id]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set test [db_get_col $res 0 xgame_sub_id]

	set authorized [db_get_col $res 0 authorized]

	#Interpret source
	set sub_source [db_get_col $res 0 src]
	if {$sub_source == "I"} {
		set sub_source "Internet"
	} elseif {$sub_source == "W"} {
		set sub_source "Wap"
	} elseif {$sub_source == "T"} {
		set sub_source "Telewest"
	} elseif {$sub_source == "P"} {
		set sub_source "Telebet"
	} elseif {$sub_source == "E"} {
		set sub_source "Elite"
	}

	# Interpret status
	set sub_status [db_get_col $res 0 status]
	if {$sub_status == "P"} {
		set sub_status "Active"
	} elseif {$sub_status == "V"} {
		set sub_status "Void"
	} elseif {$sub_status == "F"} {
		set sub_status "Fulfilled"
	} else {
		set sub_status "-"
	}


	# Display description of which draws bets are placed on
	set num_dif_draws [db_get_col $res 0 num_dif_draws]
	set desc [db_get_col $res 0 desc]
	set num_subs [db_get_col $res 0 num_subs]


	if {$desc == ""} {
		tpBindString DrawsDesc "next $num_subs draws"
	} else {
		if {$num_subs == 1 } {
			tpBindString DrawsDesc "next $desc"
		} else {
			if {$num_dif_draws > 1} {
				tpBindString DrawsDesc "next $num_subs draws"
			} else {
				tpBindString DrawsDesc "next $num_subs $desc"
			}
		}
	}

	set elite 0

	if {[db_get_col $res 0 elite] == "Y"} {
		incr elite
	}

	tpSetVar IS_ELITE $elite

	# If no bets yet placed then just display sub details
	if {$authorized == "N"} {
		tpSetVar NumBets 0

		tpBindString SubId    	$sub_id
		tpBindString CustId   	[db_get_col $res 0 cust_id]
		tpBindString CustName 	[db_get_col $res 0 username]
		tpBindString AcctNo     [db_get_col $res 0 acct_no]
		tpBindString Elite      [db_get_col $res 0 elite]
		tpBindString SubDate   	[db_get_col $res 0 subdate]

		tpBindString NumSubs 	$num_subs
		tpBindString StakePerBet [db_get_col $res 0 stake_per_bet]
		tpBindString Picks     	[db_get_col $res 0 picks]
		tpBindString SubSource 	$sub_source
		tpBindString GameName  	[db_get_col $res 0 name]
		tpBindString Status    	$sub_status
		tpBindString BetsLeft 	$num_subs
		tpBindString Auth 	   	$authorized
		tpSetVar CanVoid 0

		tpBindString betType      [db_get_col $res 0 bet_type]
		tpBindString numSelns     [db_get_col $res 0 num_selns]
		tpBindString stakePerLine [db_get_col $res 0 stake_per_line]
		tpBindString SubReceipt   [db_get_col $res 0 receipt]

		db_close $res

		asPlayFile -nocache xgame_sub.html

	#if only one bet in subscription
	} elseif {$rows == 1} {
	   	tpSetVar NumBets [expr {$rows}]

		tpBindString SubId     $sub_id
		tpBindString CustId    [db_get_col $res 0 cust_id]
		tpBindString CustName  [db_get_col $res 0 username]
		tpBindString AcctNo    [db_get_col $res 0 acct_no]
		tpBindString Elite     [db_get_col $res 0 elite]
		tpBindString SubDate   [db_get_col $res 0 subdate]

		tpBindString NumSubs 	$num_subs
		tpBindString StakePerBet [db_get_col $res 0 stake_per_bet]
		tpBindString Picks     	[db_get_col $res 0 picks]
		tpBindString SubSource 	$sub_source
		tpBindString GameName  	[db_get_col $res 0 name]
		tpBindString BetId     	[db_get_col $res 0 xgame_bet_id]
		tpBindString BetDate   	[db_get_col $res 0 betdate]
		tpBindString BetStake  	[db_get_col $res 0 stake]
		tpBindString Results   	[db_get_col $res 0 results]
		tpBindString Winnings  	[db_get_col $res 0 winnings]
		tpBindString Refund    	[db_get_col $res 0 refund]
		tpBindString BetSettled [db_get_col $res 0 settled]
		tpBindString Status    $sub_status

		tpBindString num_picks_max [db_get_col $res num_picks_max]
		tpSetVar     num_picks_max [db_get_col $res num_picks_max]
		tpSetVar     sort          [db_get_col $res sort]
		tpBindString betType       [db_get_col $res 0 bet_type]
		tpBindString numSelns      [db_get_col $res 0 num_selns]
		tpBindString stakePerLine  [db_get_col $res 0 stake_per_line]
		tpBindString SubReceipt    [db_get_col $res 0 receipt]

		set betsleft [expr {$num_subs-$rows}]
		tpBindString BetsLeft $betsleft

		if {$betsleft > 0} {
			# and not already voided
			if {$sub_status == "V"} {
				tpSetVar CanVoid 0
			} else {
				tpSetVar CanVoid 1
			}
		} else {
			tpSetVar CanVoid 0
		}

		tpBindString Auth $authorized

		db_close $res

		asPlayFile -nocache xgame_sub.html

	} else {

		set b 0

		array set BET [list]
		for {set r 0} {$r < $rows} {incr r} {
			set BET($b,xgame_bet_id) [db_get_col $res $r xgame_bet_id]
			set BET($b,betdate)   [db_get_col $res $r betdate]
			set BET($b,stake)     [db_get_col $res $r stake]
			set BET($b,results)   [db_get_col $res $r results]
			set BET($b,winnings)  [db_get_col $res $r winnings]
			set BET($b,refund)    [db_get_col $res $r refund]
			set BET($b,settled)   [db_get_col $res $r settled]

			incr b
		}

		tpSetVar NumBets [expr {$b+1}]

		tpBindString SubId       $sub_id
		tpBindString CustId      [db_get_col $res 0 cust_id]
		tpBindString CustName    [db_get_col $res 0 username]
		tpBindString Elite       [db_get_col $res 0 elite]
		tpBindString AcctNo      [db_get_col $res 0 acct_no]
		tpBindString SubDate     [db_get_col $res 0 subdate]
		tpBindString SubReceipt  [db_get_col $res 0 receipt]

		set num_subs 			[db_get_col $res 0 num_subs]
		tpBindString NumSubs 	$num_subs
		tpBindString StakePerBet [db_get_col $res 0 stake_per_bet]
		tpBindString Picks    	[db_get_col $res 0 picks]
		tpBindString SubSource 	$sub_source
		tpBindString Status  	$sub_status
		tpBindString GameName 	[db_get_col $res 0 name]
		tpBindString Auth     	$authorized

		tpBindString num_picks_max [db_get_col $res 0 num_picks_max]
		tpSetVar     num_picks_max [db_get_col $res 0 num_picks_max]

		tpBindString betType [db_get_col $res 0 bet_type]
		tpBindString numSelns [db_get_col $res 0 num_selns]
		tpBindString stakePerLine [db_get_col $res 0 stake_per_line]

		db_close $res

		tpBindVar BetId       	BET xgame_bet_id bet_idx
		tpBindVar BetDate    	BET betdate      bet_idx
		tpBindVar BetStake    	BET stake        bet_idx
		tpBindVar Results	  	BET results      bet_idx
		tpBindVar Winnings    	BET winnings	   bet_idx
		tpBindVar Refund      	BET refund  	   bet_idx
		tpBindVar BetSettled  	BET settled      bet_idx


		set betsleft [expr {$num_subs-$rows}]
		tpBindString BetsLeft 	$betsleft
		if {$betsleft > 0} {
			tpSetVar CanVoid 1
		} else {
			tpSetVar CanVoid 0
		}

		asPlayFile -nocache xgame_sub.html

		unset BET
	}
}


#
# ----------------------------------------------------------------------------
# Void subscription
# ----------------------------------------------------------------------------
#
proc do_xgame_sub_void args {

	global DB USERNAME

	set sub_id [reqGetArg SubId]
	set authorized [reqGetArg Auth]

	# if authorized = N then easy, set status to V
	if {$authorized == "N"} {
		set sql [subst {
			Update tXGameSub set
				status = "V"
			where
				xgame_sub_id = ? and
				authorized = "N"
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $sub_id]

		inf_close_stmt $stmt

		#???error	failed to update status

	# if authorized = Y
	} elseif {$authorized =="Y"} {

		# Need to set num_subs to the number of bets played
		set bets_left [reqGetArg BetsLeft]
		set num_subs  [reqGetArg NumSubs]
		set bets_played [expr {$num_subs-$bets_left}]

		# call pVoidSub.sql
		set sql [subst {
			execute procedure pVoidSub(
				p_adminuser = ?,
				p_sub_id = ?,
				p_bets_played = ?,
				p_bets_left = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt $stmt\
				$USERNAME\
				$sub_id\
				$bets_played\
				$bets_left]
		} msg]} {
			set bad 1
			err_bind $msg
		}
		inf_close_stmt $stmt
	}
	go_xgame_sub_query
}


#
# ----------------------------------------------------------------------------
# Void bet
# ----------------------------------------------------------------------------
#
proc do_xgame_bet_void args {

	global DB USERNAME

	set bet_id [reqGetArg BetId]

	set sql [subst {
		execute procedure pVoidSubBet(
			p_adminuser = ?,
			p_bet_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$bet_id]
	} msg]} {
		set bad 1
		err_bind $msg
	}
	inf_close_stmt $stmt

	go_xgame_receipt bet_id $bet_id
}

################################################################################
# Procedure :   send_parked_bet_ticker
# Description : send ticker with information about this parked bet
# Input :       username - the customer's username
# 				bet_id - the id of the parked bet
#               winnings - the bet winning
#				refund 	- the amount refunded
# Output :
# Author :      D.Coleman
################################################################################
proc send_parked_bet_ticker {bet_id username winnings refund} {

	global DB

	foreach v {receipt cust_id acct_no cr_date settled bet_type leg_type ccy_code stake cust_uname bet_winnings bet_refund} {
		set $v {}
	}

	set sql {
		select
			c.cust_id,
			c.acct_no,
			a.ccy_code,
			b.ipaddr,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			e.desc ev_name,
			m.name mkt_name,
			s.desc seln_name,
			s.result,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			b.bet_id,
			o.leg_no,
			o.part_no,
			o.leg_sort,
			o.price_type,
			o.o_num o_num,
			o.o_den o_den
		from
			tBetStlPending p,
			tBet b,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer (
				tOBet o,
				tEvOc s,
				tEvMkt m,
				tEvOcGrp g,
				tEv e
			)
		where
			p.bet_id = ? and
			p.bet_id = b.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id and
			b.bet_id = o.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id
		order by
			b.bet_id desc,
			o.leg_no asc,
			o.part_no asc
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $bet_id]} msg]} {
		ob::log::write ERROR {failed to get ticker information on parked bet (bet_id => $bet_id): $msg}
		return
	}

	set limit [expr {[db_get_nrows $res] - 1}]

	for {set r $limit} {$r >= 0} {incr r -1} {
		# If multiple selections, display repeated fields only once
		if {$r == 0} {
			foreach v {receipt cust_id acct_no cr_date settled bet_type leg_type ccy_code stake} {
				set $v [db_get_col $res $r $v]
			}
			set cust_uname   $username
			set bet_winnings $winnings
			set bet_refund   $refund
		}

		if {$r == $limit} {
			set bet_type [db_get_col $res $r bet_type]

			if {$bet_type=="MAN"} {
				set man_bet 1
			} else {
				set man_bet 0
			}

			# Display repeated fields once only
			if {$limit != 0} {
				set bet_type {}
			}
		}

		foreach v {leg_no leg_sort mkt_name seln_name price_type result} {
			set $v [db_get_col $res $r $v]
		}
		set ev_name [string trim [db_get_col $res $r ev_name]]

		if {[string first $price_type "LSBN12"] >= 0} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			if {$o_num=="" || $o_den==""} {
				set p_str [get_price_type_desc $price_type]
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str [get_price_type_desc $price_type]
				}
			}
		} else {
			if {$man_bet} {
				set p_str "MAN"
			} else {
				set p_str "DIV"
			}
		}

		# send details to monitor
		MONITOR::send_parked_bet \
			$receipt \
			$cust_uname \
			$acct_no \
			$cr_date \
			$settled \
			$bet_type \
			$leg_no \
			$leg_type \
			$ccy_code \
			$stake \
			$bet_winnings \
			$bet_refund \
			$leg_sort \
			$ev_name \
			$mkt_name \
			$seln_name \
			$p_str \
			$result

		# Unset the variables for reuse
		unset leg_sort ev_name mkt_name seln_name price_type result o_num o_den p_str

	}
	inf_close_stmt $stmt
}


#
# ----------------------------------------------------------------------------------
# Display all hedged/fielded bets (ie placed by customers with tAcct.owner = 'Y'/'F'
# ----------------------------------------------------------------------------------
#
proc do_hf_bet_query {} {

	global DB BET

	set select	     ""
	set where	     ""
	set from	     ""
	set nested_where     ""

	set type [reqGetArg HedgeField]
	OT_LogWrite 16 "Type of report is $type"

	# Bet placed date
	set date_lo  [reqGetArg BetDate1]
	set date_hi  [reqGetArg BetDate2]
	set date_sel [reqGetArg BetPlacedFrom]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {

		# a date range has been specified, so use it
		if {$date_lo != ""} {
			set d_lo "$date_lo 00:00:00"
		}
		if {$date_hi != ""} {
			set d_hi "$date_hi 23:59:59"
		}
	} else {

		# use the value from the dropdown
		set end_format "%Y-%m-%d 23:59:59"
		set start_format "%Y-%m-%d 00:00:00"

		switch -exact -- $date_sel {
			5 {
				# last month
				set d_hi [clock format [clock seconds] -format $end_format]
				set d_lo [clock format [clock scan "-1 month"] -format $start_format]
			}
			4 {
				# last 7 days
				set d_hi [clock format [clock seconds] -format $end_format]
				set d_lo [clock format [clock scan "-1 week"] -format $start_format]
			}
			3 {
				# last 3 days
				set d_hi [clock format [clock seconds] -format $end_format]
				set d_lo [clock format [clock scan "-3 day"] -format $start_format]
			}
			2 {
				# yesterday
				set d_hi [clock format [clock scan "-1 day"] -format $end_format]
				set d_lo [clock format [clock scan "-1 day"] -format $start_format]
			}
			1 {
				# today
				set d_hi [clock format [clock seconds] -format $end_format]
				set d_lo [clock format [clock seconds] -format $start_format]
			}
		}
	}

	# Get the hedged/fielded bets - which must have been placed on a hedging/fielding account
	# i.e. acct owner = 'Y' or 'F'
	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			m.name mkt_name,
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
			NVL(o.no_combi,'') no_combi,
			o.banker,
			""||o.o_num o_num,
			""||o.o_den o_den,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBet b,
			tBetType t,
			tOBet o,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tCustomerReg r,
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
		where
			b.bet_id = o.bet_id and
			b.bet_type = t.bet_type and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id and
			b.cr_date between '$d_lo' and '$d_hi' and
			a.owner = '$type' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
		union
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			a.ccy_code,
			b.ipaddr,
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
			o.desc_1 ev_name,
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
			''  no_combi,
			'N' banker,
			'' o_num,
			'' o_den,
			hb.bet_id hedged_id,
			case when hb.bet_id is not null
					then "H"
					else ocb.on_course_type
			end as on_course_type,
			case when hb.bet_id is not null
					then ocrH.rep_code
					else ocrF.rep_code
			end as rep_code
		from
			tBet b,
			tManOBet o,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer tBetType t,
			outer (tHedgedBet hb, tOnCourseRep ocrH),
			outer (tOnCourseRepBet ocb, tOnCourseRep ocrF)
		where
			b.bet_id = o.bet_id and
			b.bet_type = t.bet_type and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			b.bet_type = 'MAN' and
			b.cr_date between '$d_lo' and '$d_hi' and
			a.owner = '$type' and
			b.bet_id = hb.bet_id and
			b.bet_id = ocb.bet_id and
			hb.rep_code_id = ocrH.rep_code_id and
			ocb.rep_code_id = ocrF.rep_code_id
		order by 1 desc, 8, 25, 26
	}]


	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	# Play
	if {$rows == 1 && [db_get_col $res 0 bet_type] != "MAN"} {
		go_bet_receipt bet_id [db_get_col $res 0 bet_id]

		db_close $res
		return
	}

	bind_sports_bet_list $res 0 1

	asPlayFile -nocache bet_list.html

	catch {unset BET}
}

#
# This proc returns 1 if the bet was placed by a shop fielding account
#
proc _is_shop_fielding_bet {bet_id} {

	global DB

	set sql {
		select
			a.owner,
			a.owner_type
		from
			tBet b,
			tAcct a
		where
			b.acct_id = a.acct_id
		and
			a.owner = 'F'
		and
			a.owner_type in ('STR','VAR','OCC','REG','LOG')
		and
			b.bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $bet_id]} msg]} {
		ob::log::write ERROR {ERROR getting account information: $msg}
		inf_close_stmt $stmt
		err_bind $msg
		return 0
	}

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "Bet missing from the database"
		return 0
	}

	set owner      [db_get_col $rs 0 owner]
	set owner_type [db_get_col $rs 0 owner_type]

	db_close $rs

	if {$owner == "F" && [regexp {^(STR|VAR|OCC|REG|LOG)$} $owner_type]} {
		return 1
	} else {
		err_bind "This bet was not placed by a shop fielding account"
		return 0
	}
}

#
# ----------------------------------------------------------------------------------
# Void all pending (unsettled) bets for a specific cust_id and return to the
# customer page
# ----------------------------------------------------------------------------------
#
proc do_cancel_all_bets_for_cust {} {

	global DB USERNAME

	ob_log::write DEBUG {do_cancel_all_bets_for_cust}

	array set void_bet [list]
	set void_bet(ids) [list]

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set j [reqGetNthName $i]
		if {[regexp {^void_bet_id_([0-9]*)$} $j match bet_id] == 1} {
			lappend void_bet(ids) $bet_id
		}
	}

	ob_log::write INFO {Cancelling the following bets: [join $void_bet(ids) ","]}


	#
	# Get bet details. Make sure the sum of stakes being voided is at least
	# the sum of the deposit being cancelled
	#
	set bet_sql {
		select
			b.stake,
			b.tax,
			b.num_lines
		from
			tBet b
		where
			b.bet_id = ?
	}

	set stmt_bet [inf_prep_sql $DB $bet_sql]

	foreach bet_id $void_bet(ids) {

		ob_log::write DEBUG {Getting info for bet #$bet_id}

		set res [inf_exec_stmt $stmt_bet $bet_id]
		set nrows [db_get_nrows $res]
		if {$nrows != 1} {
			db_close $res
			error "Details for bet $bet_id cannot be found"
		}
		set void_bet($bet_id,stake)     [db_get_col $res stake]
		set void_bet($bet_id,tax)       [db_get_col $res tax]
		set void_bet($bet_id,num_lines) [db_get_col $res num_lines]
		db_close $res
	}

	inf_close_stmt $stmt_bet


	# Some global parameters needed when voiding freebets
	foreach {config} { \
		ENABLE_FREEBETS2 \
		RETURN_FREEBETS_VOID \
		RETURN_FREEBETS_CANCEL \
	} {
		set [string tolower $config] [expr {[OT_CfgGet $config "FALSE"] == "TRUE" ? "Y" : "N"}]
	}

	set freebets_no_token_on_void \
		[expr {[OT_CfgGetTrue FREEBETS_NO_TOKEN_ON_VOID] ? "Y" : "N"}]

	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

	set void_sql [subst {
		execute procedure pSettleBet(
			p_adminuser = '$USERNAME',
			p_op = 'X',
			p_bet_id = ?,
			p_num_lines_win = 0,
			p_num_lines_lose = 0,
			p_num_lines_void = ?,
			p_winnings = 0.00,
			p_tax = ?,
			p_refund = ?,
			p_settled_how = 'M',
			p_settle_info = 'Closing Account',
			p_enable_parking = 'N',
			p_freebets_enabled = '$enable_freebets2',
			p_return_freebet   = '$return_freebets_void',
			p_rtn_freebet_can  = '$return_freebets_cancel',
			p_no_token_on_void = '$freebets_no_token_on_void',
			p_r4_limit = '$r4_limit'
		)
	}]

	ob_log::write DEBUG {$void_sql}

	set stmt_void [inf_prep_sql $DB $void_sql]

	set err 0

	foreach bet_id $void_bet(ids) {

		ob_log::write DEBUG {Cancelling bet #$bet_id}

		if {[catch {
			inf_exec_stmt $stmt_void\
			$bet_id\
			$void_bet($bet_id,num_lines)\
			0.00\
			$void_bet($bet_id,tax)\
			$void_bet($bet_id,stake)
		} msg]} {
			err_bind "Could not cancel bet $bet_id: $msg"
			set err 1
			break
		}
	}

	inf_close_stmt    $stmt_void

	set cust_id [reqGetArg cust_id]
	if {$err} {
		do_cust_ustl_bet_query \
			cust_id $cust_id \
			show_cancel_all_bets 1
	} else {

		ob_log::write DEV {Cancelled all bets successfully.}

		# Send the user back to the cust page
		ADMIN::CUST::go_cust cust_id [reqGetArg cust_id]
	}

}

}

