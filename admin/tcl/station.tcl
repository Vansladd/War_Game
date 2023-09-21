# ==============================================================
# $Id: station.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::STATION {

asSetAct ADMIN::STATION::GoStationList [namespace code go_station_list]
asSetAct ADMIN::STATION::GoStation     [namespace code go_station]
asSetAct ADMIN::STATION::DoStation     [namespace code do_station]

#
# ----------------------------------------------------------------------------
# Go to station list
# ----------------------------------------------------------------------------
#
proc go_station_list args {

	global DB

	set sql [subst {
		select
			station_id,
			name,
			status,
			disporder,
			image,
			station_code
		from
			tStation
		order by
			status, disporder, name, station_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumStations [db_get_nrows $res]

	tpBindTcl StationId          sb_res_data $res station_idx station_id
	tpBindTcl StationName        sb_res_data $res station_idx name
	tpBindTcl StationStatus      sb_res_data $res station_idx status
	tpBindTcl StationDisporder   sb_res_data $res station_idx disporder
	tpBindTcl StationImage       sb_res_data $res station_idx image
	tpBindTcl StationCode        sb_res_data $res station_idx station_code

	asPlayFile -nocache station_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to single station add/update
# ----------------------------------------------------------------------------
#
proc go_station args {

	global DB

	set station_id [reqGetArg StationId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString StationId $station_id

	if {$station_id == ""} {

		if {![op_allowed ManageTVChannels]} {
			err_bind "You do not have permission to update station information"
			go_station_list
			return
		}

		tpBindString StationDisporder 0

		if {[OT_CfgGet FUNC_VIEWS 0]} {
			# Default to all views
			make_view_binds "" - 1
			# Find all languages that appear in active views
			if {[OT_CfgGetTrue FUNC_VIEWS_LANG_LIST]} {
				# Find
				set sql [subst {
					select
						distinct l.name
					from
						tViewType vt,
						tViewLang vl,
						tLang l
					where
						vt.status = 'A' and
						vt.view   = vl.view and
						vl.lang   = l.lang
				}]

				set stmt [inf_prep_sql $::DB $sql]
				set rs   [inf_exec_stmt $stmt]
				inf_close_stmt $stmt

				set lang_list [list]
				for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
					lappend lang_list [db_get_col $rs $i name]
				}
				db_close $rs
				if {[llength $lang_list] < 1} {
					set lang_list "No Views Selected"
				}
				tpBindString lang_list $lang_list
			}
		}

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get station information
		#
		set sql [subst {
			select
				station_id,
				name,
				status,
				disporder,
				image,
				station_code
			from
				tStation
			where
				station_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $station_id]
		inf_close_stmt $stmt

		tpBindString StationId          [db_get_col $res 0 station_id]
		tpBindString StationName        [db_get_col $res 0 name]
		tpBindString StationStatus      [db_get_col $res 0 status]
		tpBindString StationDisporder   [db_get_col $res 0 disporder]
		tpBindString StationImage       [db_get_col $res 0 image]
		tpBindString StationCode        [db_get_col $res 0 station_code]

		db_close $res

		if {[OT_CfgGet FUNC_VIEWS 0]} {
			#
			# Build up the View array
			#
			set sql [subst {
				select
					view,
					sort
				from
					tView
				where
					    id   = ?
					and sort = ?
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $station_id STATION]
			inf_close_stmt $stmt

			set view_list     [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend view_list [db_get_col $rs $i view]
			}

			make_view_binds $view_list - 0

			db_close $rs

			if {[OT_CfgGetTrue FUNC_VIEWS_LANG_LIST]} {

				#
				# Build up a list of languages that will need to be translated
				# with the current view list
				#
				set sql [subst {
					select
						distinct name
					from
						tView c,
						tViewLang v,
						tLang l
					where
						c.view = v.view and
						v.lang = l.lang and
						c.id   = ? and
						c.sort = ?
				}]

				set stmt [inf_prep_sql $::DB $sql]
				set rs   [inf_exec_stmt $stmt $station_id STATION]
				inf_close_stmt $stmt

				set lang_list [list]

				for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
					lappend lang_list [db_get_col $rs $i name]
				}

				if {[llength $lang_list] < 1} {
					set lang_list "No Views Selected"
				}

				tpBindString lang_list $lang_list

				db_close $rs
			}
		}

	}

	asPlayFile -nocache station.html
}

proc do_station args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_station_list
		return
	}

	if {![op_allowed ManageTVChannels]} {
		err_bind "You do not have permission to update station information"
		go_station_list
		return
	}

	if {$act == "StationAdd"} {
		do_station_add
	} elseif {$act == "StationMod"} {
		do_station_upd
	} elseif {$act == "StationDel"} {
		do_station_del
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_station_add args {

	global DB USERNAME

	set unique [unique_station_code [reqGetArg StationCode] [reqGetArg StationId]]

	if {$unique == 0} {
		err_bind "Station Code already exists"
		go_station
		return
	}

	set sql [subst {
		insert into tStation (
			name,
			status,
			disporder,
			image,
			station_code
		) values (
			?, ?, ?, ?, ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg StationName]\
			[reqGetArg StationStatus]\
			[reqGetArg StationDisporder]\
			[reqGetArg StationImage]\
			[reqGetArg StationCode]\
			]} msg]} {
		err_bind $msg
		set bad 1
	}

	if {!$bad} {
		set station_id [inf_get_serial $stmt]
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {[OT_CfgGet FUNC_VIEWS 0] && $bad == 0} {
		set upd_view [ADMIN::VIEWS::upd_view STATION $station_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_station
	}

	go_station_list
}

proc do_station_upd args {

	global DB USERNAME

	set unique [unique_station_code [reqGetArg StationCode] [reqGetArg StationId]]

	if {$unique == 0} {
		err_bind "Station Code already exists"
		go_station
		return
	}

	set sql [subst {
		update tStation set
			name         = ?,
			status       = ?,
			disporder    = ?,
			image        = ?,
			station_code = ?
		where
			station_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg StationName]\
			[reqGetArg StationStatus]\
			[reqGetArg StationDisporder]\
			[reqGetArg StationImage]\
			[reqGetArg StationCode]\
			[reqGetArg StationId]\
			]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {[OT_CfgGet FUNC_VIEWS 0] && $bad == 0} {
		set upd_view [ADMIN::VIEWS::upd_view STATION [reqGetArg StationId]]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_station
		return
	}
	go_station_list
}

proc do_station_del args {

	global DB USERNAME
	set bad 0

	# First remove this station from all events that were set to appear on it
	set ev_sql {delete from tEvStation where station_id = ?}
	set ev_stmt [inf_prep_sql $DB $ev_sql]

	if {[catch {set ev_res [inf_exec_stmt $ev_stmt [reqGetArg StationId]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $ev_res}
	inf_close_stmt $ev_stmt

	# Now delete the actual station
	set sql {delete from tStation where station_id = ?}
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt [reqGetArg StationId]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {[OT_CfgGet FUNC_VIEWS 0] && $bad == 0} {
		set del_view [ADMIN::VIEWS::del_view STATION [reqGetArg StationId]]
		if {[lindex $del_view 0]} {
			err_bind [lindex $del_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_station
		return
	}
	go_station_list
}

#
# Update the set of TV stations on which an event is shown.
#
# Up to the caller to check permissions and provide a transaction.
#
# Throws an error if unable to perform update.
#
proc upd_stations_for_ev {ev_id station_ids} {

	global DB

	ob_log::write INFO {Updating station ids for event $ev_id to ([join $station_ids ,])}

	set get_sql {
		select station_id from tEvStation where ev_id = ?
	}
	set insert_sql {
		insert into tEvStation (ev_id, station_id) values (?, ?)
	}
	set delete_sql {
		delete from tEvStation where ev_id = ? and station_id = ?
	}

	set current_ids [list]
	set get_stmt [inf_prep_sql $DB $get_sql]
	set rs [inf_exec_stmt $get_stmt $ev_id]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		lappend current_ids [db_get_col $rs $i station_id]
	}
	db_close $rs
	inf_close_stmt $get_stmt

	set insert_ids [list]
	foreach id $station_ids {
		if {[lsearch -exact $current_ids $id] == -1} {
			lappend insert_ids $id
		}
	}

	set delete_ids [list]
	foreach id $current_ids {
		if {[lsearch -exact $station_ids $id] == -1} {
			lappend delete_ids $id
		}
	}

	ob_log::write INFO {Current station ids are ([join $current_ids ,]), so inserting ([join $insert_ids ,]) and deleting ([join $delete_ids ,])}

	if {[llength $insert_ids] > 0} {
		set insert_stmt [inf_prep_sql $DB $insert_sql]
	}
	if {[llength $delete_ids] > 0} {
		set delete_stmt [inf_prep_sql $DB $delete_sql]
	}

	foreach id $insert_ids {
		inf_exec_stmt $insert_stmt $ev_id $id
	}

	foreach id $delete_ids {
		inf_exec_stmt $delete_stmt $ev_id $id
	}

	if {[llength $insert_ids] > 0} {inf_close_stmt $insert_stmt}
	if {[llength $delete_ids] > 0} {inf_close_stmt $delete_stmt}

	return 1
}


# Called when uploading an event, to set stations from a list of station codes provided in the upload CSV
proc upload_stations_for_ev {ev_id station_codes} {

	global DB

	set stations_ids   [list]
	set stations_codes [list]
	set stations_codes [split $station_codes "~"]

	set stations_sql {
						select
							station_id,
							station_code
						from
							tStation
					}

	set stations_stmt [inf_prep_sql $DB $stations_sql]
	set stations_rs [inf_exec_stmt $stations_stmt]

	for {set i 0} {$i < [db_get_nrows $stations_rs]} {incr i} {
		set code [db_get_col $stations_rs $i station_code]
		if {[lsearch -exact $stations_codes $code] != -1} {
			lappend stations_ids [db_get_col $stations_rs $i station_id]

		}
	}

	db_close $stations_rs
	inf_close_stmt $stations_stmt


	if {[llength $stations_ids] > 0} {
		set insert_sql {
			insert into tEvStation (ev_id, station_id) values (?, ?)
		}
		set insert_stmt [inf_prep_sql $DB $insert_sql]
	}

	foreach id $stations_ids {
		inf_exec_stmt $insert_stmt $ev_id $id
	}

	if {[llength $stations_ids] > 0} {inf_close_stmt $insert_stmt}
}


proc unique_station_code {station_code station_id} {

	global DB

	set sql {select
				station_code
			from
				tStation
			where
				station_code = ? and
				station_id <> ?
			}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $station_code $station_id]

	if {[db_get_nrows $res] == 0} {
		set unique 1
	} else {
		set unique 0
	}

	db_close $res
	inf_close_stmt $stmt

	return $unique

}


# End namespace
}
