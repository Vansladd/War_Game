# ==============================================================
# $Id: risk_limit.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::RISK_LIMIT {

asSetAct ADMIN::RISK_LIMIT::GoRiskLimits [namespace code go_risk_limits]
asSetAct ADMIN::RISK_LIMIT::DoRiskLimits [namespace code do_risk_limits]


#
# ----------------------------------------------------------------------------
# Go and show the risk limits for a particular number of legs
# ----------------------------------------------------------------------------
#
proc go_risk_limits {} {

	global DB
	global RISK

	catch {unset RISK}

	if {[op_allowed ManageRiskLimits]} {
		tpSetVar CanEdit 1
	}

	set num_legs [reqGetArg NumLegs]

	if {$num_legs != ""} {
		if {![string is integer -strict $num_legs] || $num_legs < 2} {
			err_bind "Invalid number of legs selected: $num_legs. Must be >= 2"
			set num_legs ""
		}
	}

	if {$num_legs == ""} {
		set sql {
			select
				NVL(MIN(num_legs),-1) num_legs
			from
				tMulRiskLimit
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_legs [db_get_col $res 0 num_legs]
		db_close $res

		if {$num_legs == -1} {
			tpSetVar NoRiskLimit 1
			asPlayFile -nocache risk_limit.html
			return
		}
	}

	#
	# Radio options for choosing the number of legs for viewing
	#
	set sql {
		select distinct
			num_legs
		from
			tMulRiskLimit
		order by
			num_legs
	}

	set stmt [inf_prep_sql $DB $sql]
	set res_l [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_l]

	tpSetVar NumNumLegs $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set RISK($i,num_legs) [db_get_col $res_l $i num_legs]
	}
	db_close $res_l

	tpBindVar NumLegs RISK num_legs risk_idx

	#
	# Risky leg win and bet limit info for the particular number of legs
	# being viewed
	#
	set sql {
		select
			num_legs_risky,
			win_limit,
			bet_limit
		from
			tMulRiskLimit
		where
			num_legs = ?
		order by
			num_legs_risky
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $num_legs]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 0} {
		reqSetArg NumLegs ""
		go_risk_limits
		return
	}

	tpSetVar NumNumLegsRisky $nrows

	tpBindTcl NumLegsRisky sb_res_data $res risk_idx num_legs_risky
	tpBindTcl WinLimit     sb_res_data $res risk_idx win_limit
	tpBindTcl BetLimit     sb_res_data $res risk_idx bet_limit

	tpSetVar ViewNumLegs $num_legs

	asPlayFile -nocache risk_limit.html

	db_close $res
}


proc do_risk_limits args {

	set submit [reqGetArg SubmitName]

	if {$submit == "Go"} {
		go_risk_limits
		return
	}

	if {![op_allowed ManageRiskLimits]} {
		err_bind "You do not have permission to set risk limits"
		go_risk_limits
		return
	}

	tpSetVar CanEdit 1

	if {$submit == "Update"} {
		update_risk_limits
	} elseif {$submit == "Delete"} {
		delete_risk_limits
	} elseif {$submit == "GoAdd"} {
		go_add_risk_limits
	} elseif {$submit == "DoAdd"} {
		do_add_risk_limits
	} elseif {$submit == "Back"} {
		go_risk_limits
	} else {
		error "Unknown SubmitName: $submit"
	}
}

proc go_add_risk_limits {} {

	global DB
	global RISK

	set num_legs [string trim [reqGetArg NewNumLegs]]

	if {![string is integer -strict $num_legs] || $num_legs < 2} {
		err_bind "Invalid number of legs: $num_legs. Must be >= 2"
		go_risk_limits
		return
	}

	set sql {
		select first 1
			num_legs
		from
			tMulRiskLimit
		where
			num_legs = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $num_legs]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]
	db_close $rs

	if {$nrows > 0} {
		err_bind "Risk Limits already exist for $num_legs legs"
		reqSetArg NumLegs $num_legs
		go_risk_limits
		return
	}

	tpSetVar Add 1
	tpBindString NumLegs $num_legs
	tpSetVar NumNumLegsRisky [expr {$num_legs + 1}]

	for {set i 0} {$i <= $num_legs} {incr i} {
		set RISK($i,num_legs_risky) $i
		set RISK($i,win_limit) ""
		set RISK($i,bet_limit) ""
	}
	tpBindVar NumLegsRisky RISK num_legs_risky risk_idx
	tpBindVar WinLimit     RISK win_limit      risk_idx
	tpBindVar BetLimit     RISK bet_limit      risk_idx

	asPlayFile -nocache risk_limit.html
}

proc do_add_risk_limits {} {

	global DB

	set num_legs [reqGetArg NumLegs]

	set sql {
		insert into tMulRiskLimit (
			num_legs,
			num_legs_risky,
			win_limit,
			bet_limit
		) values (?,?,?,?)
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	for {set i 0} {$i <= $num_legs} {incr i} {
		set win_limit [string trim [reqGetArg WinLimit_$i]]
		set bet_limit [string trim [reqGetArg BetLimit_$i]]

		if {![string is double -strict $win_limit]} {
			set err "Invalid Win Limit: $win_limit"
			break
		}
		if {![string is double -strict $bet_limit]} {
			set err "Invalid Bet Limit: $bet_limit"
			break
		}
		if {[catch {
			inf_exec_stmt $stmt $num_legs $i $win_limit $bet_limit
		} err]} {
			break
		}
	}

	if {$err != ""} {
		inf_rollback_tran $DB
		err_bind $err
		reqSetArg NewNumLegs $num_legs
		go_add_risk_limits
	} else {
		inf_commit_tran $DB
		msg_bind "Risk Limits added for $num_legs legs"
		go_risk_limits
	}
}


proc delete_risk_limits {} {

	global DB

	set num_legs [reqGetArg NumLegs]

	set sql {
		delete from tMulRiskLimit
		where
			num_legs = ?
	}
	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	inf_exec_stmt $stmt $num_legs

	inf_commit_tran $DB

	msg_bind "Risk limits deleted for $num_legs legs"

	reqSetArg NumLegs ""

	go_risk_limits
}


proc update_risk_limits {} {

	global DB

	set num_legs [reqGetArg NumLegs]

	set sql {
		update
			tMulRiskLimit
		set
			win_limit = ?,
			bet_limit = ?
		where
			num_legs = ?
		and num_legs_risky = ?
		and (win_limit <> ? or bet_limit <> ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	set err ""

	inf_begin_tran $DB

	for {set i 0} {$i <= $num_legs} {incr i} {

		set win_limit [string trim [reqGetArg WinLimit_$i]]
		set bet_limit [string trim [reqGetArg BetLimit_$i]]

		if {![string is double -strict $win_limit]} {
			set err "Invalid Win Limit: $win_limit"
			break
		}
		if {![string is double -strict $bet_limit]} {
			set err "Invalid Bet Limit: $bet_limit"
			break
		}
		if {[catch {
			inf_exec_stmt $stmt $win_limit $bet_limit $num_legs $i \
								$win_limit $bet_limit
		} err]} {
			break
		}
	}

	if {$err != ""} {
		inf_rollback_tran $DB
		err_bind $err
	} else {
		inf_commit_tran $DB
		msg_bind "Risk Limits updated for $num_legs legs"
	}

	go_risk_limits
}

# close namespace
}