# ==============================================================
# $Id: teamtalk_race.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Look up event for race
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::lookup_race_event {ev_id event_ref} {
	global DB

	upvar $event_ref event
	set sql {
		select
			e.ev_id,
			e.start_time,
			e.desc event_name,
			t.ev_type_id,
			t.name type_name
		from
			tEv     e,
			tEvType t
		where
			e.ev_id = ?
		and
			e.ev_type_id = t.ev_type_id
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $ev_id]
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		catch {db_close $rs}
		inf_close_stmt $stmt
		error "failed lookup_race_event: expected one row but got $nrows for ev_id($ev_id)"
	}

	set event(ev_id)      [db_get_col $rs 0 ev_id]
	set event(start_time) [db_get_col $rs 0 start_time]
	set event(event_name) [db_get_col $rs 0 event_name]
	set event(type_name)  [db_get_col $rs 0 type_name]
	set event(course)     [string tolower $event(type_name)]
	set event(meet_date)  [string range $event(start_time) 0 9]

	catch {db_close $rs}
	inf_close_stmt $stmt

}

#
# ----------------------------------------------------------------------------
# Look up race by start time and course
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::lookup_race {start_time course race_ref} {
	global DB

	upvar $race_ref race

	set race(race_id)    ""
	set race(updateable) ""
	set race(start_time) ""
	set race(meet_id)    ""
	set race(overview)   ""
	set race(audio_url)  ""

	# translate Ladbrokes course to Teamtalk course. 
	set course [string map {"|" ""} $course]
	set course [string tolower $course]

	set sql {
		select
			r.race_id,
			r.updateable,
			r.start_time,
			r.meet_id,
			r.overview,
			r.audio_url
		from
			tTeamTalkRace   r,
			tTeamTalkMeet   m,
			tTeamTalkCourse c
		where
			r.start_time = ?
		and
			r.meet_id = m.meet_id
		and
			m.course_id = c.course_id
		and
			c.name = ?
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $start_time $course]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set race(race_id)    [db_get_col $rs 0 race_id]
		set race(updateable) [db_get_col $rs 0 updateable]
		set race(start_time) [db_get_col $rs 0 start_time]
		set race(meet_id)    [db_get_col $rs 0 meet_id]
		set race(overview)   [db_get_col $rs 0 overview]
		set race(audio_url)  [db_get_col $rs 0 audio_url]
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

}

#
# ----------------------------------------------------------------------------
# Go to Team Talk add/update for course info
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::go_race args {
	global DB RCOURSE

	set ev_id [reqGetArg EvId]
	tpBindString EvId $ev_id

	ADMIN::TEAMTALK::lookup_race_event $ev_id event
	tpBindString EvTypeName $event(type_name)
	tpBindString EventName  $event(event_name)
	tpBindString StartTime  $event(start_time)

	ADMIN::TEAMTALK::lookup_race $event(start_time) $event(course) race

	if {$race(race_id) == ""} {
		tpSetVar OpAdd 1
		set meet_id ""

	} else {
		OT_LogWrite 10 "TTFRACE: race_id = $race(race_id)"
		tpBindString RaceId        $race(race_id)
		tpBindString Updateable    $race(updateable)
		tpBindString MeetId        $race(meet_id)
		tpBindString Overview      $race(overview)
		tpBindString AudioURL      $race(audio_url)
		tpSetVar Updateable        $race(updateable)
		tpSetVar OpAdd 0

		set meet_id $race(meet_id)
	}

	# Need to get courses and available meetings for this event time
	set sql [subst {
		select
			c.course_id,
			c.name course_name,
			m.meet_id
		from
			tTeamTalkCourse c,
			tTeamTalkMeet   m
		where 
			c.course_id = m.course_id
		and m.meet_date = ?
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $event(meet_date)]
	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set RCOURSE($r,meet_id)     [db_get_col $rs $r meet_id]
		set RCOURSE($r,course_name) [db_get_col $rs $r course_name]

		if {$RCOURSE($r,meet_id) == $meet_id} {
			set RCOURSE($r,selected) SELECTED
		} else {
			set RCOURSE($r,selected) ""
		}
	}

	tpSetVar NumCourses $nrows
	tpBindVar M1_MeetId     RCOURSE meet_id     M1_Idx
	tpBindVar M1_CourseName RCOURSE course_name M1_Idx
	tpBindVar M1_Selected   RCOURSE selected    M1_Idx

	catch {db_close $rs}
	inf_close_stmt $stmt

	asPlayFile -nocache teamtalk/teamtalk_race.html
}

#
# ----------------------------------------------------------------------------
# Maintain Team Talk Race Information
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_race args {

	set act [reqGetArg SubmitName]

	switch -- $act {
		"Back"    { ADMIN::EVENT::go_ev_upd   }
		"RaceAdd" { do_race_add }
		"RaceMod" { do_race_upd }
		"RaceDel" { do_race_del }
		default   { error "unexpected SubmitName: $act" }
	}

}

#
# ----------------------------------------------------------------------------
# Insert Team Talk Race
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_race_add args {

	global DB USERNAME

	set start_time [reqGetArg StartTime]
	set meet_id    [reqGetArg MeetId]
	set overview   [reqGetArg Overview]
	set audio_url  [reqGetArg AudioURL]
	set updateable [reqGetArg Updateable]

	if {$meet_id == ""} {
		err_bind "No team talk meeting exists for this race"
		go_race
		return
	}

	set sql [subst {
		execute procedure pTTFInsRace (
			p_adminuser  = ?,
			p_start_time = ?,
			p_meet_id    = ?,
			p_ev_id      = -1,
			p_overview   = ?,
			p_audio_url  = ?,
			p_updateable = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if [catch {set res [inf_exec_stmt $stmt \
		$USERNAME \
		$start_time \
		$meet_id \
		$overview \
		$audio_url \
		$updateable \
	]} err_msg] {
		err_bind $err_msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetArg NthName $a] [reqGetNthVal $a]
		}

	} else {
		tpSetVar RaceAdded 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_race
}

#
# ----------------------------------------------------------------------------
# Update Team Talk Race
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_race_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pTTFUpdRace (
			p_adminuser  = ?,
			p_race_id    = ?,
			p_start_time = ?,
			p_meet_id    = ?,
			p_overview   = ?,
			p_audio_url  = ?,
			p_updateable = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt $USERNAME\
		                             [reqGetArg RaceId]\
		                             [reqGetArg StartTime]\
		                             [reqGetArg MeetId]\
		                             [reqGetArg Overview]\
		                             [reqGetArg AudioURL]\
		                             [reqGetArg Updateable]]
	} msg]} {
		err_bind $msg
	} else {
		tpSetVar RaceUpdated 1
	}

	catch { db_close $res }
	inf_close_stmt $stmt

	go_race
}

#
# ----------------------------------------------------------------------------
# Delete Team Talk Race
# ----------------------------------------------------------------------------
#
proc ADMIN::TEAMTALK::do_race_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pTTFDelRace (
			p_adminuser = ?,
			p_race_id   = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt $USERNAME [reqGetArg RaceId]]
	} msg]} {
		err_bind $msg
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	ADMIN::EVENT::go_ev_upd

}


