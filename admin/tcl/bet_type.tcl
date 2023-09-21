# ==============================================================
# $Id: bet_type.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BET_TYPE {

asSetAct ADMIN::BET_TYPE::GoBetTypes [namespace code go_bet_type_list]
asSetAct ADMIN::BET_TYPE::GoBetType  [namespace code go_bet_type]
asSetAct ADMIN::BET_TYPE::DoBetType  [namespace code do_bet_type]


#
# ----------------------------------------------------------------------------
# Go to bet type list
# ----------------------------------------------------------------------------
#
proc go_bet_type_list args {

	global DB

	set sql [subst {
		select
			bet_type,
			stl_sort,
			bet_name,
			bet_settlement,
			num_selns,
			num_bets_per_seln,
			num_lines,
			min_combi,
			max_combi,
			min_bet,
			max_bet,
			max_losers,
			disporder,
			status,
			stake_factor,
			channels
		from
			tBetType
		order by
			disporder, status, num_selns, num_lines
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumBetTypes [db_get_nrows $res]

	tpBindTcl BetType        sb_res_data $res bet_type_idx bet_type
	tpBindTcl BetName        sb_res_data $res bet_type_idx bet_name
	tpBindTcl NumSelns       sb_res_data $res bet_type_idx num_selns
	tpBindTcl NumBets        sb_res_data $res bet_type_idx num_lines
	tpBindTcl NumBetsPerSeln sb_res_data $res bet_type_idx num_bets_per_seln
	tpBindTcl MinPerLine     sb_res_data $res bet_type_idx min_bet
	tpBindTcl MaxPerLine     sb_res_data $res bet_type_idx max_bet
	tpBindTcl Status         sb_res_data $res bet_type_idx status
	tpBindTcl BetTypeFactor  sb_res_data $res bet_type_idx stake_factor
	tpBindTcl Channels       sb_res_data $res bet_type_idx channels
	tpBindTcl Disporder      sb_res_data $res bet_type_idx disporder

	asPlayFile -nocache bet_type_list.html

	db_close $res
}


proc go_bet_type args {

	global DB

	set bet_type [reqGetArg BetType]

	set sql [subst {
		select
			bet_name,
			min_bet,
			max_bet,
			disporder,
			status,
			channels,
			blurb,
			stake_factor
		from
			tBetType
		where
			bet_type = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_type]
	inf_close_stmt $stmt

	tpBindString BetType       $bet_type
	tpBindString BetName       [db_get_col $res 0 bet_name]
	tpBindString MinBet        [db_get_col $res 0 min_bet]
	tpBindString MaxBet        [db_get_col $res 0 max_bet]
	tpBindString Disporder     [db_get_col $res 0 disporder]
	tpBindString Status        [db_get_col $res 0 status]
	tpBindString Blurb         [db_get_col $res 0 blurb]
	tpBindString BetTypeFactor [db_get_col $res 0 stake_factor]

	make_channel_binds [db_get_col $res 0 channels] -

	db_close $res

	asPlayFile -nocache bet_type.html
}


proc do_bet_type args {

	global DB

	if {![op_allowed ManageBetLimits]} {
		err_bind "You do not have permission to set bet limits"
		go_bet_type
		return
	}

	set sql [subst {
		update tBetType set
			bet_name = ?,
			min_bet = ?,
			max_bet = ?,
			disporder = ?,
			status = ?,
			channels = ?,
			blurb = ?,
			stake_factor = ?
		where
			bet_type = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	OT_LogWrite 5 "blurb = [reqGetArg blurb]"

	set bet_type_factor 1.0
	if {[reqGetArg BetTypeFactor] != ""} {
		set bet_type_factor [reqGetArg BetTypeFactor]
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg BetName]\
			[reqGetArg MinBet]\
			[reqGetArg MaxBet]\
			[reqGetArg Disporder]\
			[reqGetArg Status]\
			[make_channel_str]\
			[reqGetArg blurb]\
			$bet_type_factor\
			[reqGetArg BetType]]} msg]} {
		err_bind $msg
		set bad 1
		OT_LogWrite 1 "bad"
	}

	inf_close_stmt $stmt

	if {$bad} {
		go_bet_type
		return
	}

	go_bet_type_list
}

}
