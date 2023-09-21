# ==============================================================
# $Id: teamtalk_ride.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


#
# ----------------------------------------------------------------------------
# Look up selection for ride 
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::lookup_ride_selection { ev_oc_id seln_ref } {
	global DB

	upvar $seln_ref seln
	set sql {
		select
			ev_oc_id,
			desc,
			disporder
		from
			tEvOC
		where
			ev_oc_id = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $ev_oc_id]
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		catch {db_close $rs}
		inf_close_stmt $stmt
		error "failed lookup_ride_selection: expected one row but got $nrows for ev_oc_id($ev_oc_id)"
	}

	set seln(ev_oc_id)  [db_get_col $rs 0 ev_oc_id]
	set seln(desc)      [db_get_col $rs 0 desc]
	set seln(disporder) [db_get_col $rs 0 disporder]

	catch {db_close $rs}
	inf_close_stmt $stmt

}


#
# ----------------------------------------------------------------------------
# Look up ride by race id and horse or cloth number
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::lookup_ride { race_id horse cloth_num ride_ref } {
	global DB

	upvar $ride_ref ride
	set ride(ride_id)      ""
	set ride(horse)        ""
	set ride(cloth_num)    ""
	set ride(draw_num)     ""
	set ride(bred)         ""
	set ride(jockey)       ""
	set ride(trainer)      ""
	set ride(silk_id)      ""
	set ride(formguide)    ""
	set ride(updateable)   ""
	set ride(status)       ""

	# try to see if horse or cloth number can be matched
	set sql {
		select
			ride_id,
			horse,
			cloth_num,
			draw_num,
			bred,
			jockey,
			trainer,
			silk_id,
			formguide,
			updateable,
			status
		from
			tTeamTalkRide
		where
			race_id = ?
		and
			(horse = ? or cloth_num = ?)
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $race_id $horse $cloth_num]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set ride(ride_id)    [db_get_col $rs 0 ride_id]
		set ride(horse)      [db_get_col $rs 0 horse]
		set ride(cloth_num)  [db_get_col $rs 0 cloth_num]
		set ride(draw_num)   [db_get_col $rs 0 draw_num]
		set ride(bred)       [db_get_col $rs 0 bred]
		set ride(jockey)     [db_get_col $rs 0 jockey]
		set ride(trainer)    [db_get_col $rs 0 trainer]
		set ride(silk_id)    [db_get_col $rs 0 silk_id]
		set ride(formguide)  [db_get_col $rs 0 formguide]
		set ride(updateable) [db_get_col $rs 0 updateable]
		set ride(status)     [db_get_col $rs 0 status]
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

}


#
# ----------------------------------------------------------------------------
# Go to Team Talk add/update for jockey and trainer information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::go_ride args {

	global DB

	set ev_id     [reqGetArg EvId]
	tpBindString EvId $ev_id

	set ev_oc_id  [reqGetArg OcId]
	tpBindString OcId $ev_oc_id

	ADMIN::TEAMTALK::lookup_ride_selection $ev_oc_id seln
	tpBindString EvOcName $seln(desc) 

	ADMIN::TEAMTALK::lookup_race_event $ev_id event
	ADMIN::TEAMTALK::lookup_race $event(start_time) $event(course) race

	if {$race(race_id) == ""} {
		error "No team talk race exists for this horse"
	}
	tpBindString RaceId $race(race_id)

	# get ride information
	ADMIN::TEAMTALK::lookup_ride $race(race_id) $seln(desc) $seln(disporder) ride

	if {$ride(ride_id) == ""} {
		tpSetVar OpAdd 1

		tpBindString Horse    $seln(desc)
		tpBindString ClothNum $seln(disporder)

	} else {
		tpSetVar OpAdd 0

		tpBindString RideId       $ride(ride_id)
		tpBindString Horse        $ride(horse)
		tpBindString ClothNum     $ride(cloth_num)
		tpBindString DrawNum      $ride(draw_num)
		tpBindString Bred         $ride(bred)
		tpBindString Jockey       $ride(jockey)
		tpBindString Trainer      $ride(trainer)
		tpBindString SilkId       $ride(silk_id)
		tpBindString FormGuide    $ride(formguide)

		tpSetVar Updateable $ride(updateable)
	}

	asPlayFile -nocache teamtalk/teamtalk_ride.html
}

#
# ----------------------------------------------------------------------------
# Manage Team Talk ride information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_ride args {

	set act [reqGetArg SubmitName]

	switch -- $act {
		"Back"    { ADMIN::SELN::go_oc_upd }
		"RideAdd" { do_ride_add }
		"RideMod" { do_ride_upd }
		"RideDel" { do_ride_del }
		default   { error "unexpected SubmitName: $act" }
	}

}

#
# ----------------------------------------------------------------------------
# Insert team talk ride information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_ride_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pTTFInsRide (
			p_adminuser  = ?,
			p_race_id    = ?,
			p_cloth_num  = ?,
			p_horse      = ?,
			p_bred       = ?,
			p_trainer    = ?,
			p_jockey     = ?,
			p_silk_id    = ?,
			p_formguide  = ?,
			p_updateable = ?,
			p_draw_num   = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt $USERNAME\
	                                 [reqGetArg RaceId]\
	                                 [reqGetArg ClothNum]\
	                                 [reqGetArg Horse]\
	                                 [reqGetArg Bred]\
	                                 [reqGetArg Trainer]\
	                                 [reqGetArg Jockey]\
	                                 [reqGetArg SilkId]\
	                                 [reqGetArg FormGuide]\
	                                 [reqGetArg Updateable]\
	                                 [reqGetArg DrawNum]]
		
	} msg]} {

		err_bind $msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

	} else {

		tpSetVar RideAdded 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_ride
}

#
# ----------------------------------------------------------------------------
# Update Team Talk Ride Information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_ride_upd args {

	global DB USERNAME
	
	set sql [subst {
		execute procedure pTTFUpdRide (
			p_adminuser  = ?,
			p_ride_id    = ?,
			p_race_id    = ?,
			p_cloth_num  = ?,
			p_horse      = ?,
			p_bred       = ?,
			p_trainer    = ?,
			p_jockey     = ?,
			p_silk_id    = ?,
			p_formguide  = ?,
			p_updateable = ?,
			p_draw_num   = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt $stmt $USERNAME\
		                             [reqGetArg RideId]\
		                             [reqGetArg RaceId]\
		                             [reqGetArg ClothNum]\
		                             [reqGetArg Horse]\
		                             [reqGetArg Bred]\
		                             [reqGetArg Trainer]\
		                             [reqGetArg Jockey]\
		                             [reqGetArg SilkId]\
		                             [reqGetArg FormGuide]\
		                             [reqGetArg Updateable]\
		                             [reqGetArg DrawNum]]

	} msg]} {
		
		err_bind $msg

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

	} else {

		tpSetVar RideUpdated 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_ride
}


#
# ----------------------------------------------------------------------------
# Delete Team Talk Ride Information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_ride_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pTTFDelRide (
			p_adminuser = ?,
			p_ride_id   = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {

		set res [inf_exec_stmt $stmt $USERNAME [reqGetArg RideId]]

	} msg]} {
		
		err_bind $msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	ADMIN::SELN::go_oc_upd
}


