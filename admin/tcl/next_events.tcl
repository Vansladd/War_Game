# ==============================================================
# $Id: next_events.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Define which sports are used to populate
# the Next Events section of the sportsbook
#

namespace eval ADMIN::NEXT_EVENTS {

asSetAct ADMIN::NEXT_EVENTS::GoNextEvents [namespace code go_next_events]
asSetAct ADMIN::NEXT_EVENTS::DoNextEvents [namespace code do_next_events]

#
# ----------------------------------------------------------------------------
# Generate list of sports
# ----------------------------------------------------------------------------
#
proc go_next_events args {
	global DB
	global SPORTS VIEW

	GC::mark SPORTS
	GC::mark VIEW

	set view [ob_chk::get_arg view -on_err "" {ALNUM}]
	if {$view == ""} {
		set view [ob_control::get default_view]

		# just in case we don't have a default_view set in tcontrol.
		if {$view == ""} {
			set stmt [inf_prep_sql $DB {select first 1 view from tviewtype}]
			set rs [inf_exec_stmt $stmt]
			inf_close_stmt $stmt
			set view [db_get_coln $rs 0 0]
			db_close $rs
		}
	}

	set stmt [inf_prep_sql $DB {
		select
			s.sport_id,
			s.name,
			d.next_all_status as all,
			d.next_evs_status as evs,
			d.next_res_status as res
		from
			tSport s,
			outer tSportDispCfg d
		where
			s.sport_id = d.sport_id
			and d.view = ?
	}]

	set rs [inf_exec_stmt $stmt $view]
	inf_close_stmt $stmt

	set SPORTS(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $SPORTS(nrows)} {incr i} {
		set SPORTS($i,sport_id) [db_get_col $rs $i sport_id]
		set SPORTS($i,name)     [db_get_col $rs $i name]

		if {[db_get_col $rs $i all] == "A"} {
			set SPORTS($i,nextall) "checked"
		} else {
			set SPORTS($i,nextall) "unchecked"
		}

		if {[db_get_col $rs $i evs] == "A"} {
			set SPORTS($i,nextevs) "checked"
		} else {
			set SPORTS($i,nextevs) "unchecked"
		}

		if {[db_get_col $rs $i res] == "A"} {
			set SPORTS($i,nextres) "checked"
		} else {
			set SPORTS($i,nextres) "unchecked"
		}

		# This is to prevent the same sport being
		# selected as both NEXTEVS and NEXTALL
		if {$SPORTS($i,nextevs) == "checked"} {
			tpBindString initial_nextevs $SPORTS($i,sport_id)
		}
	}
	db_close $rs

	tpBindVar sport_id SPORTS sport_id next_idx
	tpBindVar name     SPORTS name     next_idx
	tpBindVar nextevs  SPORTS nextevs  next_idx
	tpBindVar nextall  SPORTS nextall  next_idx
	tpBindVar nextres  SPORTS nextres  next_idx

	_bind_view_dropdown
	tpBindString SelectedView $view

	asPlayFile -nocache next_events.html
}

#
# ----------------------------------------------------------------------------
# Update the Next Events settings
# ----------------------------------------------------------------------------
#
proc do_next_events args {
	global DB

	# grab all the req args
	set num_vals [reqGetNumVals]
	for {set n 0} {$n < $num_vals} {incr n} {
		set ARGS([reqGetNthName $n]) [reqGetNthVal $n]
	}

	# setup insert sql
	set stmt_ins [inf_prep_sql $DB {
		insert into tSportDispCfg (
			sport_id,
			view,
			next_all_status,
			next_evs_status,
			next_res_status
		) values (
			?,
			?,
			?,
			?,
			?
		)
	}]

	# setup update sql
	set stmt_upd [inf_prep_sql $DB {
		update
			tSportDispCfg
		set
			next_all_status = ?,
			next_evs_status = ?,
			next_res_status = ?
		where
			sport_id = ? and
			view     = ?
	}]

	# First select the existing config
	set stmt_current [inf_prep_sql $DB {
		select
			sport_id,
			next_all_status,
			next_evs_status,
			next_res_status
		from
			tSportDispCfg
		where
			view = ?
	}]

	set rs [inf_exec_stmt $stmt_current $ARGS(view)]
	inf_close_stmt $stmt_current

	array set EXISTING_CFG [list]
	set EXISTING_CFG(ids) [list]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set sport_id [db_get_col $rs $i sport_id]
		lappend EXISTING_CFG(ids) $sport_id
		set EXISTING_CFG($sport_id,NEXTALL) [db_get_col $rs $i next_all_status]
		set EXISTING_CFG($sport_id,NEXTEVS) [db_get_col $rs $i next_evs_status]
		set EXISTING_CFG($sport_id,NEXTRES) [db_get_col $rs $i next_res_status]
	}
	db_close $rs

	# get all sport ids.
	set stmt_sports [inf_prep_sql $DB {
		select
			sport_id
		from
			tSport
	}]
	set rs_sports [inf_exec_stmt $stmt_sports]
	inf_close_stmt $stmt_sports

	array set INS [list]
	array set UPD [list]
	set INS(ids) [list]
	set UPD(ids) [list]

	# organise the sports into ins, upd, del
	for {set i 0} {$i < [db_get_nrows $rs_sports]} {incr i} {

		set sport_id [db_get_col $rs_sports $i sport_id]

		# translate the submitted data into statuses
		if {[reqGetArg evs_sport_id] == $sport_id} {
			set next_evs_status "A"
		} else {
			set next_evs_status "S"
		}
		if {[reqGetArg all_$sport_id] != ""} {
			set next_all_status "A"
		} else {
			set next_all_status "S"
		}
		if {[reqGetArg res_$sport_id] != ""} {
			set next_res_status "A"
		} else {
			set next_res_status "S"
		}

		# if there exists config in the db for this sport
		if {[lsearch $EXISTING_CFG(ids) $sport_id] != -1} {

			# update for any changes
			if {$EXISTING_CFG($sport_id,NEXTEVS) != $next_evs_status ||
				$EXISTING_CFG($sport_id,NEXTALL) != $next_all_status ||
				$EXISTING_CFG($sport_id,NEXTRES) != $next_res_status} {

				lappend UPD(ids) $sport_id
				set UPD($sport_id,NEXTEVS) $next_evs_status
				set UPD($sport_id,NEXTALL) $next_all_status
				set UPD($sport_id,NEXTRES) $next_res_status
				continue
			}

		# otherwise insert sports with any active status
		} else {

			if {$next_evs_status == "A" || $next_all_status == "A" || $next_res_status == "A"} {
				lappend INS(ids) $sport_id
				set INS($sport_id,NEXTEVS) $next_evs_status
				set INS($sport_id,NEXTALL) $next_all_status
				set INS($sport_id,NEXTRES) $next_res_status
				continue
			}
		}
	}

	# Begin transaction
	inf_begin_tran $DB

	# insert
	foreach id $INS(ids) {
		inf_exec_stmt $stmt_ins $id $ARGS(view) $INS($id,NEXTALL) $INS($id,NEXTEVS) $INS($id,NEXTRES)
	}

	# update
	foreach id $UPD(ids) {
		inf_exec_stmt $stmt_upd $UPD($id,NEXTALL) $UPD($id,NEXTEVS) $UPD($id,NEXTRES) $id $ARGS(view)
	}

	# Commit
	inf_commit_tran $DB

	inf_close_stmt $stmt_ins
	inf_close_stmt $stmt_upd

	go_next_events
}

}
