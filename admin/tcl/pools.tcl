# ==============================================================
# $Id: pools.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::POOLS {

asSetAct ADMIN::POOLS::GoPoolTypes   [namespace code go_pool_types]
asSetAct ADMIN::POOLS::GoType        [namespace code go_type_edit]
asSetAct ADMIN::POOLS::GoUpdateType  [namespace code go_update_type]
asSetAct ADMIN::POOLS::GoPools       [namespace code go_pools]
asSetAct ADMIN::POOLS::GoPoolInfo    [namespace code go_pool_info]
asSetAct ADMIN::POOLS::GoUpdatePool  [namespace code go_update_pool]
asSetAct ADMIN::POOLS::GoConfirmPool [namespace code go_confirm_pool]
asSetAct ADMIN::POOLS::GoUnConfirmPool [namespace code go_un_confirm_pool]
asSetAct ADMIN::POOLS::GoSearchPools [namespace code go_search_pools]
asSetAct ADMIN::POOLS::GoPoolDivs    [namespace code go_pool_divs]
asSetAct ADMIN::POOLS::GoUpdPoolDiv  [namespace code do_pool_div_upd]
asSetAct ADMIN::POOLS::GoSettlePool  [namespace code go_settle_pool]
asSetAct ADMIN::POOLS::GoSettleLosers [namespace code go_settle_losers]
asSetAct ADMIN::POOLS::GoSettleBet   [namespace code go_settle_bet]
asSetAct ADMIN::POOLS::GoBets        [namespace code go_bets]
asSetAct ADMIN::POOLS::GoSearchBets  [namespace code go_search_bets]
asSetAct ADMIN::POOLS::GoPoolsBack   [namespace code go_pools_back]

#
# ----------------------------------------------------------------------------
# Generate list of pool types
# ----------------------------------------------------------------------------
#
proc go_pool_types args {
	global DB

	set sql {
		select
			t.pool_type_id,
			t.pool_source_id,
			t.name,
			t.disporder,
			s.desc
		from
			tPoolType t,
			tPoolSource s
		where
			t.pool_source_id = s.pool_source_id
		order by
			t.pool_source_id, t.disporder asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTypes [db_get_nrows $res]
	tpBindTcl TypeID sb_res_data $res type_idx pool_type_id
	tpBindTcl TypeName sb_res_data $res type_idx name
	tpBindTcl Source sb_res_data $res type_idx desc
	tpBindTcl SourceID sb_res_data $res type_idx pool_source_id

	asPlayFile "pool_type.html"

	db_close $res
}

proc go_type_edit args {
	global DB

	set bet_sql {
		select
			bet_type,
			bet_name
		from
			tBetType
	}

	set bet_stmt [inf_prep_sql $DB $bet_sql]
	set bet_res  [inf_exec_stmt $bet_stmt]
	inf_close_stmt $bet_stmt

	tpSetVar NumBetTypes [set n_betrows [db_get_nrows $bet_res]]
	if {$n_betrows > 0} {
		tpBindTcl BTID   sb_res_data $bet_res idx bet_type
		tpBindTcl BTName sb_res_data $bet_res idx bet_name
	}

	set source_sql {
		select
			pool_source_id,
			desc
		from
			tPoolSource
	}

	set source_stmt [inf_prep_sql $DB $source_sql]
	set source_res  [inf_exec_stmt $source_stmt]

	inf_close_stmt $source_stmt

	tpSetVar NumSourceTypes [set n_sourcerows [db_get_nrows $source_res]]
	if {$n_sourcerows > 0} {
		tpBindTcl SrcID sb_res_data $source_res idx pool_source_id
		tpBindTcl SrcDesc sb_res_data $source_res idx desc
	}

	if {[set type_id [reqGetArg type_id]] != "" &&
		[set source_id [reqGetArg source_id]] != ""} {
		set type_sql {
			select
				t.pool_type_id,
				t.name,
				t.num_legs,
				t.leg_type,
				t.bet_type,
				b.bet_name,
				t.all_up_avail,
				t.void_action,
				t.favourite_avail,
				t.min_stake,
				t.max_stake,
				t.max_payout,
				t.min_unit,
				t.max_unit,
				t.stake_incr,
				t.tax_rate,
				t.num_subs,
				t.status,
				t.min_runners,
				t.num_picks,
				t.disporder,
				t.grouped_divs,
				t.blurb,
				s.pool_source_id,
				s.desc
			from
				tPoolType t,
				tPoolSource s,
				tBetType b
			where
				t.bet_type = b.bet_type
			and
				s.pool_source_id = t.pool_source_id
			and
				t.pool_type_id = ?
			and
				t.pool_source_id = ?
		}

		set type_stmt [inf_prep_sql $DB $type_sql]
		set type_res  [inf_exec_stmt $type_stmt $type_id $source_id]

		inf_close_stmt $type_stmt

		if {[tpGetVar NumQualif] == 1} {
			if {[db_get_col $type_res 0 num_runners] == ""} {
				tpSetVar NumQualif 0
			}
		}
		tpSetVar Update 1

		foreach {var col} {TypeID pool_type_id \
							   Name name \
							   Blurb blurb \
							   NumLegs num_legs \
							   LegType leg_type \
							   BetType bet_type \
							   AllupAvail all_up_avail \
							   VoidAction void_action \
							   FavouriteAvail favourite_avail\
							   MinStake min_stake \
							   MaxStake max_stake \
							   MaxPayout max_payout \
							   TaxRate tax_rate \
							   NumSubs num_subs \
							   MinUnit min_unit \
							   MaxUnit max_unit \
							   StakeIncr stake_incr \
							   SourceID pool_source_id \
							   SourceDesc desc \
							   Status status \
							   BetName bet_name \
							   NumPicks num_picks \
							   MinRunners min_runners \
							   DispOrder disporder \
							   GroupedDivs grouped_divs} {
			tpBindString $var [db_get_col $type_res 0 $col]
		}

		if {![op_allowed PoolEditType]} {
			tpBindString Status      [string map {A Active S Suspended}                [db_get_col $type_res 0 status]]
			tpBindString LegType     [string map {W Win P Place O Ordered U Unordered} [db_get_col $type_res 0 leg_type]]
			tpBindString AllupAvail  [string map {Y Yes N No}                          [db_get_col $type_res 0 all_up_avail]]
			tpBindString VoidAction  [string map {R Refund S Substitute}               [db_get_col $type_res 0 void_action]]
			tpBindString FavouriteAvail  [string map {Y Yes N No}               [db_get_col $type_res 0 favourite_avail]]
			tpBindString GroupedDivs [string map {Y Yes N No}                          [db_get_col $type_res 0 grouped_divs]]
		}

		db_close $type_res

	} else {

		tpSetVar Update 0
	}

	asPlayFile "edit_pool_type.html"
	db_close $bet_res
	db_close $source_res
}

proc go_update_type args {
	global DB
	global USERNAME

	# If we're not allowed to do this then go back to the pools
	if {![op_allowed PoolEditType]} {
		return [ADMIN::POOLS::go_pool_types]
	}

	if {[reqGetArg Update] == "Update"} {
		set update 1
	} else {
		set update 0
	}

	set sql {
		execute procedure pInsPoolType
		(
		 p_adminuser = ?,
		 p_pool_type_id = ?,
		 p_pool_source_id = ?,
		 p_name = ?,
		 p_blurb = ?,
		 p_num_legs = ?,
		 p_leg_type = ?,
		 p_bet_type = ?,
		 p_all_up_avail = ?,
		 p_void_action = ?,
		 p_favourite_avail = ?,
		 p_min_stake = ?,
		 p_max_stake = ?,
		 p_min_unit = ?,
		 p_max_unit = ?,
		 p_stake_incr = ?,
		 p_max_payout = ?,
		 p_tax_rate = ?,
		 p_num_subs = ?,
		 p_status = ?,
		 p_min_runners = ?,
		 p_num_picks = ?,
		 p_disporder = ?,
		 p_grouped_divs = ?
		 )
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt \
							$USERNAME \
							[reqGetArg TypeID] \
							[reqGetArg SourceID] \
							[reqGetArg Name] \
							[reqGetArg Blurb] \
							[reqGetArg NumLegs] \
							[reqGetArg LegType] \
							[reqGetArg BetType] \
							[reqGetArg AllupAvail] \
							[reqGetArg VoidAction] \
							[reqGetArg FavouriteAvail] \
							[reqGetArg MinStake] \
							[reqGetArg MaxStake] \
							[reqGetArg MinUnit] \
							[reqGetArg MaxUnit] \
							[reqGetArg StakeIncr] \
							[reqGetArg MaxPayout] \
							[reqGetArg TaxRate] \
							[reqGetArg NumSubs] \
							[reqGetArg Status] \
							[reqGetArg MinRunners] \
							[reqGetArg NumPicks] \
							[reqGetArg DispOrder] \
							[reqGetArg GroupedDivs]]} err]} {
		OT_LogWrite 3 "go_update_type: error inserting/updating pool_type: $err"
		error "go_update_type: error inserting/updating pool_type"
	}

	if {[inf_get_row_count $stmt] != 1} {
		OT_LogWrite 3 "go_update_type: unable to create pool type"
		error "unable to create pool type"
	}

	inf_close_stmt $stmt

	db_close $rs

	ADMIN::POOLS::go_pool_types
}

proc go_pools args {
	global DB

	set srcsql {
		select
			pool_source_id,
			desc
		from
			tPoolSource
	}

	set betsql {
		select
			t.pool_type_id,
			t.name,
			t.pool_source_id
		from
			tPoolType t
	}

	set typsql {
		select
			t.ev_type_id,
			t.name,
			t.disporder
		from
			tEvType t
		where
			exists (select e.ev_id
				from tEv e, tEvMkt m, tPoolMkt p
				where
					 t.ev_type_id = e.ev_type_id
				and  e.start_time > current - (7) units day
				and  e.ev_id = m.ev_id
				and  m.ev_mkt_id = p.ev_mkt_id)
		order by t.disporder, t.name
	}

	set stmt  [inf_prep_sql $DB $srcsql]
	set srcrs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumSources [db_get_nrows $srcrs]

	tpBindTcl SourceID   sb_res_data $srcrs idx pool_source_id
	tpBindTcl SourceDesc sb_res_data $srcrs idx desc

	set stmt  [inf_prep_sql $DB $betsql]
	set betrs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumTypes [db_get_nrows $betrs]

	tpBindTcl TypeID     sb_res_data $betrs idx pool_type_id
	tpBindTcl TypeName   sb_res_data $betrs idx name
	tpBindTcl TypeSource sb_res_data $betrs idx pool_source_id

	set stmt  [inf_prep_sql $DB $typsql]
	set typrs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumEvTypes [db_get_nrows $typrs]

	tpBindTcl EvTypeID   sb_res_data $typrs idx ev_type_id
	tpBindTcl EvTypeName sb_res_data $typrs idx name

	asPlayFile "pool_search.html"

	db_close $srcrs
	db_close $betrs
	db_close $typrs
}


proc go_search_pools args {
	global DB

	if {[reqGetArg settle] == "Yes"} {
		return [go_settle_all_pools]
	}
	OT_LogWrite 1 "**SD** args = $args backup = -[reqGetArg backup]- backup_cookie = -[get_cookie backup]-"
	if {[reqGetArg backup] == "Y" && [set backup_cookie [get_cookie backup]] != ""} {
		set backup_cookie [html_decode $backup_cookie]
		OT_LogWrite 5 "go_search_pools: retrieved backup cookie: $backup_cookie"
		foreach name {source bet_type ev_type date_lo date_hi date_sel settled status} \
			val [split $backup_cookie "|"] {
				set $name $val
			}
	} else {
		set source [reqGetArg Source]
		set bet_type [reqGetArg BetType]
		set ev_type  [reqGetArg Type]
		set date_lo  [reqGetArg date_lo]
		set date_hi  [reqGetArg date_hi]
		set date_sel [reqGetArg date_range]
		set settled  [reqGetArg settled]
		set status   [reqGetArg status]

		set backup_cookie "backup=[html_encode "$source|$bet_type|$ev_type|$date_lo|$date_hi|$date_sel|$settled|$status; path=/"]"
		tpBufAddHdr Set-Cookie $backup_cookie
		OT_LogWrite 5 "go_search_pools: backup cookie: $backup_cookie"
	}

	set d_lo "0001-01-01 00:00:00"
	set d_hi "9999-12-31 23:59:59"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "$date_lo 00:00:00"
		}
		if {$date_hi != ""} {
			set d_hi "$date_hi 23:59:59"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]
		# td will be the clock seconds value for the
		# start of today
		set td [clock scan $dt]
		set secs_in_day [expr {24 * 60 * 60}]

		if {$date_sel == "-3"} {
			# last 7 days
			set s_lo [expr {$td - (7 * $secs_in_day)}]
			set s_hi $td
		} elseif {$date_sel == "-2"} {
			# last 3 days
			set s_lo [expr {$td - (3 * $secs_in_day)}]
			set s_hi $td
		} elseif {$date_sel == "-1"} {
			# yesterday
			set s_lo [expr {$td - (1 * $secs_in_day)}]
			set s_hi $td
		} elseif {$date_sel == "0"} {
			# today
			set s_lo $td
			set s_hi [expr {$td + (1 * $secs_in_day)}]
		} elseif {$date_sel == "1"} {
			# tomorrow
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (2 * $secs_in_day)}]
		} elseif {$date_sel == "2"} {
			# next 3 days
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (4 * $secs_in_day)}]
		} elseif {$date_sel == "3"} {
			# next 7 days
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (7 * $secs_in_day)}]
		} elseif {$date_sel == "4"} {
			set s_lo [clock seconds]
		}

		if {[info exists s_lo]} {
			set d_lo [clock format $s_lo -format "%Y-%m-%d %H:%M:%S"]
		}
		if {[info exists s_hi]} {
			set d_hi [clock format $s_hi -format "%Y-%m-%d %H:%M:%S"]
		}
	}

	if {$d_lo == "" && $d_hi == ""} {
		set where ""
	} else {
		set where [subst {
		and
			v.start_time between '$d_lo' and '$d_hi'
		}]
	}

	if {$settled != "-"}  {
		append where " and p.settled='$settled'"
	}
	if {$status != "-"} {
		append where " and p.status='$status'"
	}
	if {$source != "-"} {
		append where " and s.pool_source_id='$source'"
	}
	if {$bet_type != "-"} {
		append where " and p.pool_type_id='$bet_type'"
	}
	if {$ev_type != "-"} {
		append where " and y.ev_type_id='$ev_type'"
	}

	set sql [subst {
		select {+ORDERED}
			p.pool_id,
			p.settled,
			p.result_conf,
			DECODE(p.status||t.status, 'AA', 'A', 'S') as status,
			p.is_void,
			p.displayed,
			p.name,
			s.pool_source_id,
			s.desc,
			y.name track,
			p.pool_type_id,
			p.rec_dividend,
			min(v.start_time) as stime,
			min(k.leg_num) as first_race,
			max(k.leg_num) as last_race
		from
			tEv v,
 			tEvMkt m,
 			tPoolMkt k,
 			tPool p,
 			tPoolType t,
 			tPoolSource s,
 			tEvType y
		where
			p.pool_id = k.pool_id
		and m.ev_mkt_id = k.ev_mkt_id
		and v.ev_id = m.ev_id
		and p.pool_type_id = t.pool_type_id
		and t.pool_source_id = s.pool_source_id
		and y.ev_type_id = v.ev_type_id
--		and v.start_time =
--			(
--			 	select
--					min(start_time)
--				from
--					tEv e2,
--					tEvMkt m2,
--					tPoolMkt p2
--				where
--					p2.pool_id = p.pool_id
--				and
--					p2.ev_mkt_id = m2.ev_mkt_id
--				and
--					m2.ev_id = e2.ev_id
--			)
		$where
		group by 1,2,3,4,5,6,7,8,9,10,11,12
		order by
			stime,first_race,p.pool_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumPools [db_get_nrows $rs]

	tpBindTcl Settled     sb_res_data $rs idx settled
	tpBindTcl ResultConf  sb_res_data $rs idx result_conf
	tpBindTcl Status      sb_res_data $rs idx status
	tpBindTcl RecDividend sb_res_data $rs idx rec_dividend
	tpBindTcl IsVoid      sb_res_data $rs idx is_void
	tpBindTcl Displayed   sb_res_data $rs idx displayed
	tpBindTcl Provider    sb_res_data $rs idx desc
	tpBindTcl StartTime   sb_res_data $rs idx stime
	tpBindTcl Name        sb_res_data $rs idx name
	tpBindTcl PoolId      sb_res_data $rs idx pool_id
	tpBindTcl Track       sb_res_data $rs idx track

	tpBindTcl Source      sb_res_data $rs idx pool_source_id
	tpBindTcl Type	      sb_res_data $rs idx pool_type_id

	tpBindTcl RaceNos     ::ADMIN::POOLS::get_pool_races $rs idx
	asPlayFile "pool_list.html"
	db_close $rs
}

proc get_pool_races {rs idx_name} {

	set row [tpGetVar $idx_name]
	set first [db_get_col $rs $row first_race]
	set last  [db_get_col $rs $row first_race]

	if {$first == $last} {
		tpBufWrite "$first"
	} else {
		tpBufWrite "$first - $last"
	}
}

proc go_pool_info args {
	global DB divs

	set pool_id [reqGetArg PoolId]

	set sql {
		select
			p.pool_id,
			p.cr_date,
			p.name,
			p.status,
			p.displayed,
			p.is_void,
			p.result_conf,
			p.rec_dividend,
			p.settled,
			p.min_stake,
			p.max_stake,
			p.min_unit,
			p.max_unit,
			p.stake_incr,
			p.max_payout,
			decode(p.settled||p.result_conf, 'NY', 'Y', 'N') as settle_ready,
			g.name mkt_name,
			t.favourite_avail,
			t.name pool_type_name,
			t.pool_type_id,
			c.name class_name,
			y.name type_name,
			e.desc event,
			e.start_time,
			c.ev_class_id,
			y.ev_type_id,
			m.ev_mkt_id,
			m.result_conf,
			e.ev_id
		from
			tPool p,
			outer tPoolType t,
			tPoolMkt k,
			tEvMkt m,
			tEvOcGrp g,
			tEvClass c,
			tEvType y,
			tEv e
		where
			p.pool_id = k.pool_id
		and
			t.pool_type_id = p.pool_type_id
		and
			t.pool_source_id = p.pool_source_id
		and
			m.ev_mkt_id = k.ev_mkt_id
		and
			g.ev_oc_grp_id = m.ev_oc_grp_id
		and
			e.ev_id = m.ev_id
		and
			y.ev_type_id = e.ev_type_id
		and
			c.ev_class_id = y.ev_class_id
		and
			p.pool_id = ?
		order by
			start_time asc
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $pool_id]} err]} {
		OT_LogWrite 5 "go_pool_info: error retrieving pools info: $err"
		error "retrieving pool info"
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	tpSetVar NumRows $nrows

	if {$nrows > 0} {
		tpSetVar CanConfirm  [db_get_col $rs 0 rec_dividend]
		tpSetVar SettleReady [db_get_col $rs 0 settle_ready]
		tpSetVar Settled     [db_get_col $rs 0 settled]

		foreach {place col} {PoolId pool_id \
								 Created cr_date \
								 TypeID pool_type_id \
								 Name name \
								 Status status \
								 Displayed displayed \
								 IsVoid is_void \
								 FavouriteAvail favourite_avail \
								 MinStake min_stake \
								 MaxStake max_stake \
								 MinUnit min_unit \
								 MaxUnit max_unit \
								 StakeIncr stake_incr \
								 MaxPayout max_payout\
								 ResultConf result_conf \
								 DivRec rec_dividend \
								 TypeName pool_type_name} {
			tpBindString $place [db_get_col $rs 0 $col]
		}

		if {![op_allowed PoolEditPool]} {
			tpBindString Status    [string map {A Active S Supspended} [db_get_col $rs 0 status]]
			tpBindString Displayed [string map {Y Yes N No} [db_get_col $rs 0 displayed]]
			tpBindString IsVoid    [string map {Y Yes N No} [db_get_col $rs 0 is_void]]
			tpBindString FavouriteAvail    [string map {Y Yes N No} [db_get_col $rs 0 favourite_avail]]
		}

		foreach {place col} {Class class_name \
								 Type type_name \
								 Event event \
								 StartTime start_time \
								 Market mkt_name \
								 ClassId ev_class_id \
								 TypeId ev_type_id \
								 EvId ev_id \
								 MktId ev_mkt_id} {
			tpBindTcl $place sb_res_data $rs idx $col
		}
	}

	if {[db_get_col $rs rec_dividend] == "Y"} {
		set drs [get_pool_divs]
	}

	set sql [subst {
		select
			s.ccy_code,
			t.num_legs,
			t.num_picks
		from
			tPool p,
			tPoolType t,
			tPoolSource s
		where
			p.pool_id = $pool_id
		and p.pool_type_id = t.pool_type_id
		and t.pool_source_id = s.pool_source_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set ad_rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString CcyCode [db_get_col $ad_rs ccy_code]
	tpSetVar NumLegs    [db_get_col $ad_rs num_legs]
	set num_picks [db_get_col $ad_rs num_picks]
	if {[tpGetVar NumPlaces] == "" || [tpGetVar NumPlaces] < $num_picks} {
		tpSetVar NumPlaces  $num_picks
	}
	tpBindTcl Leg {tpBufWrite [tpGetVar leg]}
	tpBindTcl Plc {tpBufWrite [tpGetVar place]}
	db_close $ad_rs

	OT_LogWrite 5 "playing pool_info.html"

	asPlayFile -nocache "pool_info.html"

	db_close $rs

	if {[info exists drs]} {
		db_close $drs
	}
}

proc go_pools_back args {
	global DB

	set pool_id [reqGetArg PoolId]

	set sql {
		select
			ev_mkt_id
		from
			tPoolMkt
		where
			pool_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pool_id]
	set MktId [db_get_col $res 0 ev_mkt_id]


	inf_close_stmt $stmt
	db_close $res
	reqSetArg MktId $MktId
	ADMIN::MARKET::go_mkt


}
proc go_update_pool args {
	global DB

	# Check we're allowed to edit the pool
	if {![op_allowed PoolEditPool]} {
		return [go_pools]
	}

	set sql {
		update
			tPool
		set
			status       = ?,
			displayed    = ?,
			is_void      = ?,
			rec_dividend = ?,
			min_stake    = ?,
			max_stake    = ?,
			min_unit     = ?,
			max_unit     = ?,
			stake_incr   = ?,
			max_payout   = ?
		where
			pool_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt [reqGetArg Status]\
							        [reqGetArg Displayed]\
							        [reqGetArg IsVoid]\
							        [reqGetArg DivRec]\
							        [reqGetArg MinStake]\
							        [reqGetArg MaxStake]\
							        [reqGetArg MinUnit]\
							        [reqGetArg MaxUnit]\
									[reqGetArg StakeIncr]\
							        [reqGetArg MaxPayout]\
							        [reqGetArg PoolId]} err]} {
		OT_LogWrite 5 "go_update_pool: error updating pool status: $err"
		error "go_update_pool: updating pool status"
	}
	inf_close_stmt $stmt

	go_pool_info
}

proc go_confirm_pool args {

	global DB

	# Check we're allowed to edit the pool
	if {![op_allowed PoolEditPool]} {
		return [go_pools]
	}

	inf_begin_tran $DB

	set sql {
		update
			tPool
		set
			result_conf  = 'Y'
		where
			pool_id = ?
		and (is_void = 'Y' or rec_dividend = 'Y')
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt [reqGetArg PoolId]} err]} {
		inf_close_stmt $stmt
		inf_rollback_tran $DB
		OT_LogWrite 5 "go_update_pool: error updating pool status: $err"
		error "go_update_pool: updating pool status"
	}
	if {[inf_get_row_count $stmt] != 1} {
		inf_rollback_tran $DB
		OT_LogWrite 5 "Failed to confirm pool"
		error "Failed to confirm pool"
	}

	inf_close_stmt $stmt


	set sql {
		update tPoolDividend set
			confirmed = 'Y'
		where pool_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt [reqGetArg PoolId]} err]} {
		inf_close_stmt $stmt
		inf_rollback_tran $DB
		OT_LogWrite 5 "go_update_pool: error updating pool status: $err"
		error "go_update_pool: updating pool status"
	}
	inf_close_stmt $stmt

	inf_commit_tran $DB

	go_pool_info
}

proc go_un_confirm_pool args {

	global DB

	# Check we're allowed to edit the pool
	if {![op_allowed PoolEditPool]} {
		return [go_pools]
	}

	set sql {
		update
			tPool
		set
			result_conf = 'N'
		where
			pool_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt [reqGetArg PoolId]} err]} {
		inf_close_stmt $stmt
		OT_LogWrite 5 "go_update_pool: error updating pool status: $err"
		error "go_update_pool: updating pool status"
	}

	inf_close_stmt $stmt
	go_pool_info
}

proc go_pool_divs args {
	global DB divs

	set confirmation [reqGetArg confirmed]
	# If we're updating confirmation of the dividend
	if {($confirmation == "Y" || $confirmation == "N") && [op_allowed PoolEditDividend]} {
		set stmt [inf_prep_sql $DB "update tPoolDividend set confirmed = '$confirmation' where pool_dividend_id = [reqGetArg div_id]"]
		if {[catch {inf_exec_stmt $stmt} err]} {
			OT_LogWrite 3 "go_pool_divs: error updating dividend \#[reqGetArg div_id] confirmation status: $err"
		}
		inf_close_stmt $stmt
	}

	set rs [get_pool_divs]
	asPlayFile pool_divs.html
	db_close $rs
}

proc do_pool_div_upd {} {

	switch -- [reqGetArg SubmitName] {
		"Confirm" -
		"UnConfirm" {
			do_conf_pool_div
		}

		"Update"  -
		"Add" {
			do_upd_div
		}

		"Delete" {
			do_del_div
		}
	}


	go_pool_info
}

proc do_conf_pool_div {} {

	global DB
	set div_id [reqGetArg DivId]
	set pool_id [reqGetArg PoolId]

	if {[reqGetArg SubmitName] == "Confirm"} {
		set conf Y
	} else {
		set conf N
	}

	set sql [subst {
		update tPoolDividend set
			confirmed = '$conf'
		where
			pool_dividend_id = $div_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt} err]} {
		OT_LogWrite 3 "error updating pool dividend $div_id: $err"
	}
	inf_close_stmt $stmt



	if {$conf == "N"} {

		#
		# set the pool result unconfirmed
		# if we are unconfirming a dividend
		#

		set sql [subst {
			update tPool set
				result_conf = 'N'
			where
				pool_id = $pool_id
			and result_conf = 'Y'
		}]
		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt} err]} {
			OT_LogWrite 3 "error updating pool result_conf $pool_id: $err"
		}
		inf_close_stmt $stmt
	}
}

proc do_upd_div {} {

	global DB

	set pool_id [reqGetArg PoolId]
	set div_id  [reqGetArg DivId]


	set sql [subst {
		select
			t.num_legs,
			t.num_picks,
			t.grouped_divs,
			s.dividend_unit
		from
			tPoolSource s,
			tPoolType   t,
			tPool       p
		where
			p.pool_id = $pool_id
		and p.pool_type_id = t.pool_type_id
		and t.pool_source_id = s.pool_source_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		OT_LogWrite 3 "error retrieving pool type info for $pool_id"
	}

	set n_legs   [db_get_col $res num_legs]
	set n_places [db_get_col $res num_picks]
	set grouped_divs [db_get_col $res grouped_divs]
	set div_unit [db_get_col $res dividend_unit]
	db_close $res

	# j - the place
	# i - the leg

	set legs [list]
	for {set i 0} {$i < $n_legs} {incr i} {
		set places [list]
		for {set j 0} {$j < $n_places} {incr j} {
			set r [string trim [reqGetArg runner_${i}_${j}]]
			if {$grouped_divs == "Y"} {
				set r [split $r ","]
			}
			foreach subr $r {
				if {![regexp {^[0-9]+$} $subr]} {
					OT_LogWrite 5 "bad runner num $subr - perhaps you are trying to use grouped dividends when they're disabled?"
				} else {
					lappend places $subr
				}
			}
		}

		lappend legs [join $places ","]
	}

	for {} {$i <= 9} {incr i} {
		lappend legs {}
	}

	set div [string trim [reqGetArg Dividend]]
	if {![regexp {^[0-9]+(\.[0-9][0-9]?)?$} $div]} {
		OT_LogWrite 5 "bad dividend $div"
	}

	set div [expr {$div * $div_unit}]

	if {$div_id == ""} {
		add_div $pool_id $div $n_legs $legs
	} else {
		upd_div $div_id $div $n_legs $legs
	}
}

proc add_div {pool_id div n_legs legs} {

	global DB
	set sql [subst {
		insert into tPoolDividend (
			pool_id,
			num_legs,
			num_legs_req,
			dividend,
			confirmed,
			leg_1,
			leg_2,
			leg_3,
			leg_4,
			leg_5,
			leg_6,
			leg_7,
			leg_8,
			leg_9
		) values (
			$pool_id,
			$n_legs,
			$n_legs,
			$div,
			'N',
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)
	}]

	inf_begin_tran $DB
	set stmt [inf_prep_sql $DB $sql]
	eval [concat inf_exec_stmt $stmt $legs]
	inf_close_stmt $stmt

	set sql [subst {
		update tPool set
			rec_dividend = 'Y'
		where
			pool_id = $pool_id
		and rec_dividend = 'N'
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt
	inf_commit_tran $DB
}

proc upd_div {div_id div n_legs legs} {

	global DB
	set sql [subst {
		update tPoolDividend set
			dividend = $div,
			leg_1 = ?,
			leg_2 = ?,
			leg_3 = ?,
			leg_4 = ?,
			leg_5 = ?,
			leg_6 = ?,
			leg_7 = ?,
			leg_8 = ?,
			leg_9 = ?
		where
			pool_dividend_id = $div_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	eval [concat inf_exec_stmt $stmt $legs]
	inf_close_stmt $stmt
}


proc do_del_div {} {

	global DB

	set div_id  [reqGetArg DivId]
	set pool_id [reqGetArg PoolId]

	set sql [subst {
		delete from tPoolDividend where pool_dividend_id = $div_id
	}]

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	set sql [subst {
		update tPool set
			rec_dividend = 'N'
		where
			pool_id = $pool_id
		and not exists (select * from tpooldividend d where d.pool_id = tPool.pool_id)
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_commit_tran $DB
}

proc get_pool_divs args {

	global DB divs

	catch {unset divs} {}

	set sql {
		select
			d.pool_dividend_id,
			d.pool_id,
			d.num_legs,
			d.confirmed,
			s.ccy_code,
			round(d.dividend/s.dividend_unit, 2) as dividend,
			t.num_picks,
			t.grouped_divs,
			d.leg_1,
			d.leg_2,
			d.leg_3,
			d.leg_4,
			d.leg_5,
			d.leg_6,
			d.leg_7,
			d.leg_8,
			d.leg_9
		from
			tPoolDividend d,
			tPool         p,
			tPoolType     t,
			tPoolSource   s
		where
			d.pool_id = ?
		and d.pool_id = p.pool_id
		and p.pool_type_id = t.pool_type_id
		and t.pool_source_id = s.pool_source_id
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt [reqGetArg PoolId]]} err]} {
		OT_LogWrite 5 "go_pool_divs: error getting pool dividends: $err"
		error "go_pool_divs: getting pool dividends"
	}
	inf_close_stmt $stmt

	set ndivs [db_get_nrows $rs]
	tpSetVar NumDivs $ndivs
	tpSetVar NumLegs   [db_get_col $rs num_legs]
	tpSetVar NumPlaces [db_get_col $rs num_picks]

	tpBindString CcyCode [db_get_col $rs ccy_code]

	tpBindTcl Value sb_res_data $rs div dividend
	tpBindTcl DivId sb_res_data $rs div pool_dividend_id

	tpBindTcl Leg {tpBufWrite [tpGetVar leg]}
	tpBindTcl Plc {tpBufWrite [tpGetVar place]}

	set grouped_divs [db_get_col $rs grouped_divs]

	set cur_id -1
	for {set row 0} {$row < $ndivs} {incr row} {

		set divs($row,confirmed) [db_get_col $rs $row confirmed]

		for {set leg 0} {$leg < 9} {incr leg} {
			set div [string trim [db_get_col $rs $row leg_[expr $leg + 1]] " ,"]
			if {$grouped_divs == "N"} {
				set div [split $div ","]
			}
			# Updated so that if the data is completed by a feed, for example the Tote
			# feed, then it will show all the positions. This allows for dead heats.
			if {[llength $div] > [tpGetVar NumPlaces]} {
				tpSetVar	NumPlaces [llength $div]
			}
			for {set place 0} {$place < [llength $div]} {incr place} {
				set divs($row,$leg,$place) [string trim [lindex $div $place]]
			}
		}
	}
	# Bind the runner number
	tpBindTcl RunnerNum {tpBufWrite [expr {[info exists divs($div,$leg,$place)]?$divs($div,$leg,$place):""}]}

	return $rs
}

proc go_settle_all_pools args {
	global USERNAME

	tpSetVar StlObj allpools
	tpSetVar StlObjId ""
	tpSetVar StlDoIt [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

proc go_settle_pool args {
	global USERNAME

	tpSetVar StlObj pool
	tpSetVar StlObjId [reqGetArg PoolId]
	tpSetVar StlDoIt [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

proc go_settle_losers args {
	global USERNAME

	tpSetVar StlObj pool
	tpSetVar StlObjId [reqGetArg PoolId]
	tpSetVar StlDoIt [reqGetArg DoSettle]
	tpSetVar StlLosers 1

	asPlayFile -nocache settlement.html
}

proc go_settle_bet args {
	global USERNAME

	tpSetVar StlObj poolBet
	tpSetVar StlObjId [reqGetArg BetId]
	tpSetVar StlDoIt "Y"

	asPlayFile -nocache settlement.html
}

proc go_bets args {
	global DB

	set srcsql {
		select
			pool_source_id,
			desc
		from
			tPoolSource
	}

	set betsql {
		select
			t.pool_type_id,
			t.name,
			t.pool_source_id
		from
			tPoolType t
	}

	set stmt  [inf_prep_sql $DB $srcsql]
	set srcrs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumSources [db_get_nrows $srcrs]

	tpBindTcl SourceID   sb_res_data $srcrs idx pool_source_id
	tpBindTcl SourceDesc sb_res_data $srcrs idx desc


	set stmt  [inf_prep_sql $DB $betsql]
	set betrs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	tpSetVar NumTypes [db_get_nrows $betrs]

	tpBindTcl TypeID     sb_res_data $betrs idx pool_type_id
	tpBindTcl TypeName   sb_res_data $betrs idx name
	tpBindTcl TypeSource sb_res_data $betrs idx pool_source_id

	asPlayFile "bet_search.html"
	db_close $srcrs
	db_close $betrs
}


proc go_search_bets args {
	global DB
	global BETS

	catch {unset BETS} err

	set fname    [reqGetArg FirstName]
	set lname    [reqGetArg LastName]
	set acct_no  [reqGetArg acct_no]
	set rec1     [reqGetArg Receipt_1]
	set rec2     [reqGetArg Receipt_2]
	set rec3     [reqGetArg Receipt_3]
	set tsn		[reqGetArg TSN]
	set source   [reqGetArg Source]
	set bet_type [reqGetArg BetType]
	set date_lo  [reqGetArg date_lo]
	set date_hi  [reqGetArg date_hi]
	set date_sel [reqGetArg date_range]
	set settled  [reqGetArg settled]
	set status   [reqGetArg status]

	set d_lo "0001-01-01 00:00:00"
	set d_hi "9999-12-31 23:59:59"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "$date_lo 00:00:00"
		}
		if {$date_hi != ""} {
			set d_hi "$date_hi 23:59:59"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]
		# td will be the clock seconds value for the
		# start of today
		set td [clock scan $dt]
		set secs_in_day [expr {24 * 60 * 60}]

		if {$date_sel == "-2"} {
			# last 3 days
			set s_lo [expr {$td - (3 * $secs_in_day)}]
			set s_hi $td
		} elseif {$date_sel == "-1"} {
			# yesterday
			set s_lo [expr {$td - (1 * $secs_in_day)}]
			set s_hi $td
		} elseif {$date_sel == "0"} {
			# today
			set s_lo $td
			set s_hi [expr {$td + (1 * $secs_in_day)}]
		} elseif {$date_sel == "1"} {
			# tomorrow
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (2 * $secs_in_day)}]
		} elseif {$date_sel == "2"} {
			# next 3 days
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (4 * $secs_in_day)}]
		} elseif {$date_sel == "3"} {
			# next 7 days
			set s_lo [expr {$td + (1 * $secs_in_day)}]
			set s_hi [expr {$td + (7 * $secs_in_day)}]
		} elseif {$date_sel == "4"} {
			set s_lo [clock seconds]
		}

		if {[info exists s_lo]} {
			set d_lo [clock format $s_lo -format "%Y-%m-%d %H:%M:%S"]
		}
		if {[info exists s_hi]} {
			set d_hi [clock format $s_hi -format "%Y-%m-%d %H:%M:%S"]
		}
	}

	if {$d_lo == "" && $d_hi == ""} {
		set where ""
	} else {
		set where [subst {
		and
			b.cr_date between '$d_lo' and '$d_hi'
		}]
	}

	if {$settled != "-"}  {
		append where " and b.settled='$settled'"
	}
	if {$source != "-"} {
		append where " and p.pool_source_id='$source'"
	}
	if {$bet_type != "-"} {
		append where " and p.pool_type_id='$bet_type'"
	}
	if {$fname != ""} {
		append where " and lower(r.fname) like '%[string tolower $fname]%'"
	}
	if {$lname != ""} {
		append where " and lower(r.lname) like '%[string tolower $lname]%'"
	}
	if {$acct_no != ""} {
		append where " and c.acct_no = $acct_no"
	}
	if {$rec1 != "" && $rec2 != "" && $rec3 != ""} {
		append where " and b.receipt = '[format "%s/%08d/%08d" $rec1 $rec2 $rec3]'"
	}
	# Tote TSN
	if {$tsn != ""} {
		append where "and exists (
			select
				1
			from
				tToteTSN
			where
				tToteTSN.pool_bet_id	= b.pool_bet_id
			and	tToteTSN.tsn			= '$tsn'
		)"
	}
	if {$status != "-"} {
		append where " and b.status = '$status'"
	}

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
			b.bet_type bet_name,
			o.pool_id,
			o.leg_no,
			o.part_no,
			o.ev_oc_id,
			o.banker_info,
			s.desc,
			g.name,
			s.result,
			s.place,
			r.fname,
			r.lname,
			c.acct_no,
			c.username,
			p.pool_id,
			t.name pool_type,
			p.result_conf as pool_conf
		from
			tPoolBet b,
			tPBet o,
			tEvOc s,
			tEvOcGrp g,
			tEvMkt m,
			tPool p,
			tPoolType t,
			tAcct a,
			tCustomer c,
			outer tCustomerReg r
		where
			o.pool_bet_id = b.pool_bet_id
		and s.ev_oc_id = o.ev_oc_id
		and g.ev_oc_grp_id = m.ev_oc_grp_id
		and m.ev_mkt_id = s.ev_mkt_id
		and p.pool_id = o.pool_id
		and t.pool_type_id = p.pool_type_id
		and t.pool_source_id = p.pool_source_id
		and b.acct_id = a.acct_id
		and a.cust_id = c.cust_id
		and r.cust_id = c.cust_id
		$where
		order by
			b.pool_bet_id asc,
			p.pool_id asc,
			b.cr_date asc,
			o.leg_no asc,
			o.part_no asc
	}]


	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	set num_bets -1
	set old_bet -1

	for {set row 0} {$row < $nrows} {incr row} {
		set bet_id [db_get_col $rs $row pool_bet_id]
		set leg_no [expr [db_get_col $rs $row leg_no] - 1]
		set part_no [expr [db_get_col $rs $row part_no] - 1]

		if {$old_bet != $bet_id} {
			set old_bet $bet_id
			set old_leg -1
			set old_pool -1

			incr num_bets

			foreach col {pool_bet_id cr_date bet_name stake settled num_lines receipt
				winnings fname lname acct_no username pool_conf} {
				set BETS($num_bets,$col) [db_get_col $rs $row $col]
			}
		}

		if {$old_leg != $leg_no} {
			set old_leg $leg_no

			if {![info exists BETS($num_bets,num_legs)]} {
				set BETS($num_bets,num_legs) 1
			} else {
				incr BETS($num_bets,num_legs)
			}

			set BETS($num_bets,$leg_no,num_parts) 0
			set BETS($num_bets,$leg_no,pool_no) [db_get_col $rs $row pool_id]
			set BETS($num_bets,$leg_no,pool_type) [db_get_col $rs $row pool_type]

			if {$BETS($num_bets,$leg_no,pool_no) != $old_pool} {
				set old_pool $BETS($num_bets,$leg_no,pool_no)
				set disp_leg 1
			} else {
				incr disp_leg
			}

			set BETS($num_bets,$leg_no,leg_no) $disp_leg
		}

		foreach col {ev_oc_id banker_info desc result place} {
			set BETS($num_bets,$leg_no,$part_no,$col) [db_get_col $rs $row $col]
		}

		if {[set banker_info [db_get_col $rs $row banker_info]] != ""} {
			if {[regexp -- {B(M?)([0-9]+)} $banker_info all multiple place]} {
				set banker_info "Banker"

				if {$multiple == "M"} {
					append banker_info " Multiple"
				}

				append banker_info " place: $place"
			} else {
				set banker_info ""
			}
			set BETS($num_bets,$leg_no,$part_no,banker_info) $banker_info
		} else {
			set BETS($num_bets,$leg_no,$part_no,banker_info) [db_get_col $rs $row banker_info]
		}

		incr BETS($num_bets,$leg_no,num_parts)
	}
	db_close $rs

	incr num_bets

	OT_LogWrite 5 "displaying $num_bets bets"

	tpSetVar NumBets $num_bets

	tpBindVar UserID     BETS username    bet_idx
	tpBindVar AcctNo     BETS acct_no     bet_idx
	tpBindVar BetID      BETS pool_bet_id bet_idx
	tpBindVar BetType    BETS bet_name    bet_idx
	tpBindVar Stake      BETS stake       bet_idx
	tpBindVar NumLines   BETS num_lines   bet_idx

	tpBindVar LegNo      BETS leg_no      bet_idx leg_idx
	tpBindVar PoolNo     BETS pool_no     bet_idx leg_idx
	tpBindVar PoolType   BETS pool_type   bet_idx leg_idx

	tpBindVar SelnID     BETS ev_oc_id    bet_idx leg_idx part_idx
	tpBindVar SelnName   BETS desc        bet_idx leg_idx part_idx
	tpBindVar BankerInfo BETS banker_info bet_idx leg_idx part_idx

	asPlayFile "pool_bet_list.html"

	catch {unset BETS}
}
}
