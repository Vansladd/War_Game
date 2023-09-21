# ==============================================================
# $Id: teamplayer.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TEAMPLAYER {

asSetAct ADMIN::TEAMPLAYER::doBlank      [namespace code doBlank]
asSetAct ADMIN::TEAMPLAYER::doTeamPlayer [namespace code doTeamPlayer]
asSetAct ADMIN::TEAMPLAYER::doTeam       [namespace code doTeam]
asSetAct ADMIN::TEAMPLAYER::doPlayer     [namespace code doPlayer]
asSetAct ADMIN::TEAMPLAYER::doCSS        [namespace code doStyleSheet]
asSetAct ADMIN::TEAMPLAYER::GoTeamEvent  [namespace code go_team_event]
asSetAct ADMIN::TEAMPLAYER::GoTeamPlayer [namespace code go_team_player]
asSetAct ADMIN::TEAMPLAYER::GoTeamEvOc   [namespace code go_team_evoc]


#
# Play a blank template.
#
proc doBlank {} {
	asPlayFile -nocache blank.html
}

proc doStyleSheet {} {
	asPlayFile -nocache admin.css
}

#
# Startup.
#
proc doTeamPlayer {} {
	asPlayFile -nocache frames.html
}

#
# ----------------------------------------------------------------------------
# Player management
# ----------------------------------------------------------------------------
#
proc doPlayer {} {

	set act [reqGetArg SubmitName]

	if {$act == "add"} {
		if {[op_allowed ManageTeamPlayer]} {
			doAddPlayer
		}
		doShowPlayers
	} elseif {$act == "upd"} {
		if {[op_allowed ManageTeamPlayer]} {
			doUpdPlayer
		}
		doShowPlayers
	} elseif {$act == "del"} {
		if {[op_allowed ManageTeamPlayer]} {
			doDelPlayer
		}
		doShowPlayers
	} elseif {$act == "show"} {
		doShowPlayers
	} elseif {$act == ""} {
		doShowPlayers
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc doAddPlayer {} {

	global DB

	set stmt_1 [inf_prep_sql $DB {
		insert into
			tPlayer (fname, lname, position, perf)
		values
			(?, ?, ?, ?)
	}]

	set stmt_2 [inf_prep_sql $DB {
		insert into
			tPlayerTeam (player_id, team_id)
		values
			(?, ?)
	}]

	inf_begin_tran $DB

	set c [catch {

		set rs_1 [inf_exec_stmt $stmt_1\
			[reqGetArg playerFirstName]\
			[reqGetArg playerLastName]\
			[reqGetArg playerPosition]\
			[reqGetArg playerPerf]]

		set player_id [inf_get_serial $stmt_1]

		set rs_2 [inf_exec_stmt $stmt_2 $player_id [reqGetArg teamID]]

	} msg]

	catch {db_close $rs_1}
	catch {db_close $rs_2}
	catch {inf_close_stmt $stmt_1}
	catch {inf_close_stmt $stmt_2}

	if {$c} {
		inf_rollback_tran $DB
		error $msg
	} else {
		inf_commit_tran $DB
	}
}

proc doUpdPlayer {} {

	global DB

	set stmt [inf_prep_sql $DB {
		update
			tPlayer
		set
			fname = ?,
			lname = ?,
			position = ?,
			perf = ?
		where
			player_id = ?
	}]

	set c [catch {
		set rs [inf_exec_stmt $stmt\
			[reqGetArg playerFirstName]\
			[reqGetArg playerLastName]\
			[reqGetArg playerPosition]\
			[reqGetArg playerPerf]\
			[reqGetArg playerID]]\
	} msg]

	catch {db_close $rs}
	catch {inf_close_stmt $stmt}

	if {$c} {
		error $msg
	}
}

proc doDelPlayer {} {

	global DB

	set stmt_1 [inf_prep_sql $DB {
		delete from
			tPlayerTeam
		where
			player_id = ? and team_id = ?

	}]

	set stmt_2 [inf_prep_sql $DB {
		delete from
			tPlayer
		where
			player_id = ?
	}]

	inf_begin_tran $DB

	set c [catch {
		set rs_1 [inf_exec_stmt $stmt_1 [reqGetArg playerID] [reqGetArg teamID]]
		set rs_2 [inf_exec_stmt $stmt_2 [reqGetArg playerID]]
	} msg]

	catch {db_close $rs_1}
	catch {db_close $rs_2}

	catch {inf_close_stmt $stmt_1}
	catch {inf_close_stmt $stmt_2}

	if {$c} {
		inf_rollback_tran $DB
		error $msg
		return
	}
	inf_commit_tran $DB
}

proc doShowPlayers {} {

	global DB PLAYERS

	#
	# Display the team details.
	#
	set stmt [inf_prep_sql $DB {
		select
			team_id,
			name,
			code
		from
			tTeam
		where
			team_id = ?
	}]

	set rs [inf_exec_stmt $stmt [reqGetArg teamID]]

	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		error "no such team"
		return
	}

	tpBindString teamID		[db_get_col $rs 0 team_id]
	tpBindString teamName	[db_get_col $rs 0 name]
	tpBindString teamCode	[db_get_col $rs 0 code]

	db_close $rs

	#
	# Display a list of players in this team.
	#
	set stmt [inf_prep_sql $DB {
		select
			p.player_id,
			p.fname,
			p.lname,
			p.position,
			p.perf,
			t.team_id,
			t.code,
			t.name
		from
			tTeam t,
			tPlayer p,
			tPlayerTeam tp
		where
			p.player_id = tp.player_id
		and tp.team_id = t.team_id
		and t.team_id = ?
		order by
			p.lname
	}]

	set rs [inf_exec_stmt $stmt [reqGetArg teamID]]

	inf_close_stmt $stmt

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set PLAYERS(nrows) $nrows

	for {set row 0} {$row < $nrows} {incr row} {
		foreach col $cols {
			set PLAYERS($row,$col) [db_get_col $rs $row $col]
		}
	}

	db_close $rs

	tpBindVar playerID			PLAYERS player_id c_idx
	tpBindVar playerFirstName	PLAYERS fname     c_idx
	tpBindVar playerLastName	PLAYERS lname     c_idx
	tpBindVar playerPosition	PLAYERS position  c_idx
	tpBindVar playerPerf		PLAYERS perf      c_idx

	if {[op_allowed ManageTeamPlayer]} {
		tpSetVar manageTeamPlayer 1
		tpBindString manage 1
	} else {
		tpBindString manage 0
	}
	asPlayFile -nocache players.html

	unset PLAYERS
}

#
# ----------------------------------------------------------------------------
# Team management
# ----------------------------------------------------------------------------
#
proc doTeam {} {

	set act [reqGetArg SubmitName]

	if {$act == "add"} {
		if {[op_allowed ManageTeamPlayer]} {
			doAddTeam
		}
		doShowTeams
	} elseif {$act == "upd"} {
		if {[op_allowed ManageTeamPlayer]} {
			doUpdTeam
		}
		doShowTeams
	} elseif {$act == "del"} {
		if {[op_allowed ManageTeamPlayer]} {
			doDelTeam
		}
		doShowTeams
	} elseif {$act == "show"} {
		doShowTeams
	} elseif {$act == ""} {
		doShowTeams
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc doAddTeam {} {

	global DB

	set stmt [inf_prep_sql $DB {
		insert into
			tTeam (name, code, sort_name)
		values
			(?, ?, ?)
	}]

	set c [catch {
		set rs [inf_exec_stmt $stmt\
			[reqGetArg teamName]\
			[reqGetArg teamCode]\
			[reqGetArg teamSortName]]
	} msg]

	if {!$c} {
		tpBindString selectedTeamID [inf_get_serial $stmt]
	}

	catch {inf_close_stmt $stmt}
	catch {db_close $rs}

	if {$c} {
		error $msg
	}
}

proc doUpdTeam {} {

	global DB

	set stmt [inf_prep_sql $DB {
		update tTeam set
			name = ?,
			code = ?,
			sort_name = ?
		where
			team_id = ?
	}]

	set c [catch {
		set rs [inf_exec_stmt $stmt\
			[reqGetArg teamName]\
			[reqGetArg teamCode]\
			[reqGetArg teamSortName]\
			[reqGetArg teamID]]
	} msg]

	catch {inf_close_stmt $stmt}
	catch {db_close $rs}

	if {$c} {
		error $msg
	}

	tpBindString selectedTeamID [reqGetArg teamID]
}

proc doDelTeam {} {

	global DB

	set stmt_1 [inf_prep_sql $DB {
		delete from
			tPlayerTeam
		where
			team_id = ?
	}]
	set stmt_2 [inf_prep_sql $DB {
		delete from
			tTeam
		where
			team_id = ?
	}]

	inf_begin_tran $DB

	set c [catch {
		set rs_1 [inf_exec_stmt $stmt_1 [reqGetArg teamID]]
		set rs_2 [inf_exec_stmt $stmt_2 [reqGetArg teamID]]
	} msg]

	catch {inf_close_stmt $stmt_1}
	catch {inf_close_stmt $stmt_2}
	catch {db_close $rs_1}
	catch {db_close $rs_2}

	if {$c} {
		inf_rollback_tran $DB
		error $msg
		return
	}
	inf_commit_tran $DB
}

proc doShowTeams {} {

	global DB TEAMS CFG

	set stmt [inf_prep_sql $DB {
		select
			team_id,
			name,
			code,
			sort_name,
			nvl(sort_name, "ZZZZZZ") sort,
			status
		from
			tTeam
		where
			status = 'A'
		order by
			status,
			sort,
			name
	}]

	set c [catch {
		set rs [inf_exec_stmt $stmt]
	} msg]

	catch {inf_close_stmt $stmt}

	if {$c} {
		error $msg
		return
	}

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set TEAMS(nrows) $nrows

	for {set row 0} {$row < $nrows} {incr row} {
		foreach col $cols {
			set TEAMS($row,$col) [db_get_col $rs $row $col]
		}
		#
		# Prepend the sort name for menu display purposes (if not zero length).
		#
		if {[set sort_name [db_get_col $rs $row sort_name]] != ""} {
			set TEAMS($row,menu_name) "$sort_name,[db_get_col $rs $row name]"
		} else {
			set TEAMS($row,menu_name) [db_get_col $rs $row name]
		}
	}
	db_close $rs

	tpBindVar teamID   TEAMS team_id c_idx
	tpBindVar teamName TEAMS name    c_idx
	tpBindVar teamCode TEAMS code    c_idx
	tpBindVar teamSortName TEAMS sort_name    c_idx
	tpBindVar teamMenuName TEAMS menu_name    c_idx

	if {[op_allowed ManageTeamPlayer]} {
		tpSetVar manageTeamPlayer 1
		tpBindString manage 1
	} else {
		tpBindString manage 0
	}
	asPlayFile -nocache teams.html

	unset TEAMS
}

#
# ----------------------------------------------------------------------------
# Team-player management
# ----------------------------------------------------------------------------
#
proc go_team_player {} {

	global DB PLAYERS

	set stmt [inf_prep_sql $DB {
		select
			tp.tp_id,
			t.code,
			p.fname,
			p.lname,
			t.name,
			te.side
		from
			tTeam t,
			tTeamEvent te,
			tPlayer p,
			tPlayerTeam tp
		where
			p.player_id = tp.player_id
			and tp.team_id = t.team_id
			and t.team_id = te.team_id
			and te.ev_id = ?
			and t.status = 'A'
		order by
			te.side desc,
			p.lname,
			p.fname
	}]

	set eventID [reqGetArg eventID]

	set rs [inf_exec_stmt $stmt [reqGetArg eventID]]

	inf_close_stmt $stmt

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set PLAYERS(nrows) $nrows

	for {set row 0} {$row < $nrows} {incr row} {
		foreach col $cols {
			set PLAYERS($row,$col) [db_get_col $rs $row $col]
		}
	}

	db_close $rs

	tpBindVar teamPlayerID    PLAYERS tp_id c_idx
	tpBindVar playerTeamCode  PLAYERS code  c_idx
	tpBindVar playerFirstName PLAYERS fname c_idx
	tpBindVar playerLastName  PLAYERS lname c_idx
	tpBindVar playerSide      PLAYERS side  c_idx

	asPlayFile -nocache teamplayer.html

	unset PLAYERS
}

#
# ----------------------------------------------------------------------------
# Team-event management
# ----------------------------------------------------------------------------
#
proc go_team_event {} {

	global DB TEAMS

	set stmt [inf_prep_sql $DB {
		select
			team_id,
			name,
			code,
			sort_name,
			nvl(sort_name, "ZZZZZZ") sort
		from
			tTeam
		where
			status = 'A'
		order by
			sort,
			name
	}]

	set rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set TEAMS(nrows) $nrows

	for {set row 0} {$row < $nrows} {incr row} {
		foreach col $cols {
			set TEAMS($row,$col) [db_get_col $rs $row $col]
		}
		#
		# Prepend the sort name for menu display purposes (if not zero length).
		#
		if {[set sort_name [db_get_col $rs $row sort_name]] != ""} {
			set TEAMS($row,menu_name) "$sort_name,[db_get_col $rs $row name]"
		} else {
			set TEAMS($row,menu_name) [db_get_col $rs $row name]
		}
	}

	db_close $rs

	tpBindVar teamID    TEAMS team_id c_idx
	tpBindVar teamName  TEAMS name    c_idx
	tpBindVar teamCode  TEAMS code    c_idx
	tpBindVar teamMenuName TEAMS menu_name    c_idx

	asPlayFile -nocache teamevent.html

	unset TEAMS
}



#
# ----------------------------------------------------------------------------
# Team-selection management
# ----------------------------------------------------------------------------
#
proc go_team_evoc {} {

	global DB TEAMS

	set stmt [inf_prep_sql $DB {
		select
			team_id,
			name,
			code,
			sort_name,
			nvl(sort_name, "ZZZZZZ") sort
		from
			tTeam
		where
			status = 'A'
		order by
			sort,
			name
	}]

	set rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set cols  [db_get_colnames $rs]
	set nrows [db_get_nrows $rs]

	set TEAMS(nrows) $nrows

	for {set row 0} {$row < $nrows} {incr row} {
		foreach col $cols {
			set TEAMS($row,$col) [db_get_col $rs $row $col]
		}
		#
		# Prepend the sort name for menu display purposes (if not zero length).
		#
		if {[set sort_name [db_get_col $rs $row sort_name]] != ""} {
			set TEAMS($row,menu_name) "$sort_name,[db_get_col $rs $row name]"
		} else {
			set TEAMS($row,menu_name) [db_get_col $rs $row name]
		}
	}

	db_close $rs

	tpBindVar teamID       TEAMS team_id      c_idx
	tpBindVar teamName     TEAMS name         c_idx
	tpBindVar teamCode     TEAMS code         c_idx
	tpBindVar teamMenuName TEAMS menu_name    c_idx

	asPlayFile -nocache teamevoc.html

	unset TEAMS
}



}
