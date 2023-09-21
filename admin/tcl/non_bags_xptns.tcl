# $Id: non_bags_xptns.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2007 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::NONBAGSX {

asSetAct ADMIN::NONBAGSX::GoNonBAGSX               [namespace code go_non_bags_x]
asSetAct ADMIN::NONBAGSX::DoNonBAGSXUpd            [namespace code do_non_bags_x_upd]
asSetAct ADMIN::NONBAGSX::DoAddNonBAGSX            [namespace code do_add_non_bags_x]
#
# ---------------------------------------------
# Generate the non-BAGS exceptions page
# ---------------------------------------------
#
proc go_non_bags_x args {

	global DB TRACK NB_TRACK
	
	set stmt_nbx [inf_prep_sql $DB {
		select
			t.ev_type_id,
			t.name,
			x.exception,
			x.is_off,
			x.lp_avail,
			x.tc_avail
		from
			tevtype t,
			outer tnonbagsxptn x
		where
			x.ev_type_id = t.ev_type_id and
			t.ev_class_id = ?
		order by
			t.name
	}]

	set res_nbx  [inf_exec_stmt $stmt_nbx [OT_CfgGet DOGS_EV_CLASS_ID 3]]
	inf_close_stmt $stmt_nbx

	set track_rows [db_get_nrows $res_nbx]
	
	set nbx_rows 0
	set nb_rows  0
	# Add each row to either the Non-BAGS exceptions list (TRACK) or the Non-BAGS list
	# (NB_TRACK) depending on exception flag setting in DB.
	for {set i 0} {$i < $track_rows} {incr i} {
		if {[db_get_col $res_nbx $i exception] == "Y"} {
			incr nbx_rows
			set TRACK($nbx_rows,ev_type_id) [db_get_col $res_nbx $i ev_type_id]
			set TRACK($nbx_rows,name)       [db_get_col $res_nbx $i name]
			set TRACK($nbx_rows,exception)  [db_get_col $res_nbx $i exception]
			set TRACK($nbx_rows,is_off)     [db_get_col $res_nbx $i is_off]
			set TRACK($nbx_rows,lp_avail)   [db_get_col $res_nbx $i lp_avail]
			set TRACK($nbx_rows,tc_avail)   [db_get_col $res_nbx $i tc_avail]
			OT_LogWrite 1 "AK : TRACK($nbx_rows,name)=$TRACK($nbx_rows,name)"
		} else {
			incr nb_rows
			set NB_TRACK($nb_rows,ev_type_id) [db_get_col $res_nbx $i ev_type_id]
			set NB_TRACK($nb_rows,name)       [db_get_col $res_nbx $i name]
			set NB_TRACK($nb_rows,exception)  [db_get_col $res_nbx $i exception]
			set NB_TRACK($nb_rows,is_off)     [db_get_col $res_nbx $i is_off]
			set NB_TRACK($nb_rows,lp_avail)   [db_get_col $res_nbx $i lp_avail]
			set NB_TRACK($nb_rows,tc_avail)   [db_get_col $res_nbx $i tc_avail]
			OT_LogWrite 1 "AK : NB_TRACK($nb_rows,name)=$NB_TRACK($nb_rows,name)"
		}
	}
	tpSetVar nbx_rows $nbx_rows
	tpSetVar nb_rows  $nb_rows
	tpBindString nbx_rows $nbx_rows
	tpBindString nb_rows  $nb_rows

	tpBindVar ev_type_id TRACK ev_type_id track_idx
	tpBindVar track_name TRACK name       track_idx
	tpBindVar exception  TRACK exception  track_idx
	tpBindVar is_off     TRACK is_off     track_idx
	tpBindVar lp_avail   TRACK lp_avail   track_idx
	tpBindVar tc_avail   TRACK tc_avail   track_idx
	
	tpBindVar nb_ev_type_id NB_TRACK ev_type_id nb_track_idx
	tpBindVar nb_track_name NB_TRACK name       nb_track_idx
	tpBindVar nb_exception  NB_TRACK exception  nb_track_idx
	tpBindVar nb_is_off     NB_TRACK is_off     nb_track_idx
	tpBindVar nb_lp_avail   NB_TRACK lp_avail   nb_track_idx
	tpBindVar nb_tc_avail   NB_TRACK tc_avail   nb_track_idx

	asPlayFile -nocache non_bags_xptns.html
	
	db_close $res_nbx
	
	catch {unset TRACK}
	catch {unset NB_TRACK}
}

proc do_non_bags_x_upd args {
	global DB
	set num_rows [reqGetArg num_rows]
	
	set sql {
		update
			tnonbagsxptn
		set
			exception = ?,
			is_off = ?,
			lp_avail = ?,
			tc_avail = ?
		where
			ev_type_id = ?
	}
	
	set stmt [inf_prep_sql $DB $sql]

	set bad 0
	
	for {set a 1} {$a <= $num_rows} {incr a} {
	
		set ev_type_id [reqGetArg ev_type_id_$a]
		set exception  [reqGetArg exception_$a]
		set is_off     [reqGetArg is_off_$a]
		set lp_avail   [reqGetArg lp_avail_$a]
		set tc_avail   [reqGetArg tc_avail_$a]

		OT_LogWrite 1 "ADMIN::NONBAGSX::do_non_bags_x_upd ev_type_id=$ev_type_id exception=$exception is_off=$is_off lp_avail=$lp_avail tc_avail=$tc_avail"
				
		if {[catch {
			inf_exec_stmt $stmt \
					$exception \
					$is_off \
					$lp_avail \
					$tc_avail \
					$ev_type_id \
					} msg]} {
			err_bind $msg
			set bad 1
		}
		
		if {$bad} {
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			go_non_bags_x
			return
		}
	}
	
	inf_close_stmt $stmt
	
	go_non_bags_x
	return
}

proc do_add_non_bags_x args {
	global DB
	
	set ev_type_id [reqGetArg ev_type_id]
	set exception  [reqGetArg exception]
	set is_off     [reqGetArg is_off]
	set lp_avail   [reqGetArg lp_avail]
	set tc_avail   [reqGetArg tc_avail]

	OT_LogWrite 1 "ADMIN::NONBAGSX::do_add_non_bags_x ev_type_id=$ev_type_id exception=$exception is_off=$is_off lp_avail=$lp_avail tc_avail=$tc_avail"
	
	set sql {
		update
			tnonbagsxptn
		set
			exception = ?,
			is_off = ?,
			lp_avail = ?,
			tc_avail = ?
		where
			ev_type_id = ?
	}
	
	set stmt [inf_prep_sql $DB $sql]
	set bad 0
	
	if {[catch {
		inf_exec_stmt $stmt \
			      $exception \
			      $is_off \
			      $lp_avail \
			      $tc_avail \
			      $ev_type_id \
				  } msg]} {
		err_bind $msg
		set bad 1
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_non_bags_x
		return
	}

	if {[inf_get_row_count $stmt] != 1} {
		# exception row for track doesn't exist yet
		set sql_insert {
			insert into
				tnonbagsxptn
			(
				ev_type_id,
				exception,
				is_off,
				lp_avail,
				tc_avail
			)
			values
			(
				?,
				?,
				?,
				?,
				?
			)
		}

		set stmt_insert [inf_prep_sql $DB $sql_insert]

		OT_LogWrite 1 "test $ev_type_id \
					$exception \
					$is_off \
					$lp_avail \
					$tc_avail"

		if {[catch {
			inf_exec_stmt $stmt_insert \
					$ev_type_id \
					$exception \
					$is_off \
					$lp_avail \
					$tc_avail \
		} msg]} {
			err_bind $msg
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			go_non_bags_x
			return
		}

		inf_close_stmt $stmt_insert
	}

	inf_close_stmt $stmt
	
	go_non_bags_x
	return
}
# end namespace
}