# ==============================================================
# $Id: form_race.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Look up event for race
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::lookup_race_event {ev_id event_ref} {
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
	set event(meeting_date)  [string range $event(start_time) 0 9]

	catch {db_close $rs}
	inf_close_stmt $stmt

}

#
# ----------------------------------------------------------------------------
# Look up race by start time and course
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::lookup_race {form_provider_id ev_id race_ref} {
	global DB

	upvar $race_ref race

	set race(ext_race_id)    ""
	set race(updateable) ""
	set race(start_time) ""
	set race(meeting_id) ""
	set race(title)      ""
	set race(overview)   ""
	set race(dist_f)     ""
	set race(dist_y)     ""
	set race(going)      ""
	set race(class)      ""
	set race(prize)     ""
	set race(flat_or_jumps)    ""


	set sql {
		select
			r.ext_race_id,
			r.updateable,
			r.start_time,
			r.meeting_id,
			r.title,
			r.race_no,
			r.overview,
			r.dist_f,
			r.dist_y,
			r.going,
			r.class,
			r.prize,
			r.flat_or_jumps
		from
			tFormRace   r,
			tFormMeeting   m,
			tFormCourse c
		where
			r.ev_id = ?
		and
			r.form_provider_id = ?
		and
			r.meeting_id = m.meeting_id
		and
			r.form_provider_id = m.form_provider_id
		and
			m.course_id = c.course_id
		and
			m.form_provider_id = c.form_provider_id
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $ev_id $form_provider_id]
	set nrows [db_get_nrows $rs]

	OT_LogWrite 1 "jsutherl : nrows $nrows"

	if {$nrows == 1} {
		set race(ext_race_id)    [db_get_col $rs 0 ext_race_id]
		set race(updateable) [db_get_col $rs 0 updateable]
		set race(start_time) [db_get_col $rs 0 start_time]
		set race(meeting_id) [db_get_col $rs 0 meeting_id]
		set race(title)      [db_get_col $rs 0 title]
		set race(race_no)    [db_get_col $rs 0 race_no]
		set race(overview)   [db_get_col $rs 0 overview]
		set race(dist_f)     [db_get_col $rs 0 dist_f]
		set race(dist_y)     [db_get_col $rs 0 dist_y]
		set race(going)      [db_get_col $rs 0 going]
		set race(class)      [db_get_col $rs 0 class]
		set race(prize)      [db_get_col $rs 0 prize]
		set race(flat_or_jumps) [db_get_col $rs 0 flat_or_jumps]
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

}

#
# ----------------------------------------------------------------------------
# Go to Form feed add/update for course info
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::go_race args {
	global DB RCOURSE

	set ev_id [reqGetArg EvId]
	tpBindString EvId $ev_id

	set form_provider_id [reqGetArg FormProviderId]
	tpBindString FormProviderId $form_provider_id

	ADMIN::FORM::lookup_race_event $ev_id event
	tpBindString EvTypeName $event(type_name)
	tpBindString EventName  $event(event_name)
	tpBindString StartTime  $event(start_time)

	ADMIN::FORM::lookup_race $form_provider_id $ev_id race

	if {$race(ext_race_id) == ""} {
		err_bind "Event has no form feed data available for this provider"
		ADMIN::EVENT::go_ev $ev_id
		return

	} else {
		OT_LogWrite 10 "FormRACE: ext_race_id = $race(ext_race_id)"
		tpBindString ExtRaceId     $race(ext_race_id)
		tpBindString Updateable    $race(updateable)
		tpBindString Title         $race(title)
		tpBindString RaceNo        $race(race_no)
		tpBindString MeetingId     $race(meeting_id)
		tpBindString Overview      $race(overview)
		tpBindString DistF         $race(dist_f)
		tpBindString DistY         $race(dist_y)
		tpBindString Going         $race(going)
		tpBindString Class         $race(class)
		tpBindString Prize         $race(prize)
		tpBindString FlatOrJumps   $race(flat_or_jumps)
		tpSetVar Updateable        $race(updateable)
		tpSetVar OpAdd 0

		set meeting_id $race(meeting_id)
	}

	# Need to get courses and available meetings for this event time
	set sql [subst {
		select
			c.course_id,
			c.name course_name,
			m.meeting_id
		from
			tFormCourse c,
			tFormMeeting   m
		where
			c.form_provider_id = ?
		and c.course_id = m.course_id
		and c.form_provider_id = m.form_provider_id
		and m.meeting_date = ?
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $form_provider_id $event(meeting_date)]
	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set RCOURSE($r,meeting_id)     [db_get_col $rs $r meeting_id]
		set RCOURSE($r,course_name) [db_get_col $rs $r course_name]

		if {$RCOURSE($r,meeting_id) == $meeting_id} {
			set RCOURSE($r,selected) SELECTED
		} else {
			set RCOURSE($r,selected) ""
		}
	}

	tpSetVar NumCourses $nrows
	tpBindVar M1_MeetingId  RCOURSE meeting_id     M1_Idx
	tpBindVar M1_CourseName RCOURSE course_name M1_Idx
	tpBindVar M1_Selected   RCOURSE selected    M1_Idx

	catch {db_close $rs}
	inf_close_stmt $stmt

	asPlayFile -nocache form/form_race.html
}

#
# ----------------------------------------------------------------------------
# Maintain Team Talk Race Information
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::do_race args {

	set act [reqGetArg SubmitName]

	switch -- $act {
		"Back"    { ADMIN::EVENT::go_ev_upd   }
		"RaceMod" { do_race_upd }
		default   { error "unexpected SubmitName: $act" }
	}

}

#
# ----------------------------------------------------------------------------
# Update Form feed Race
# ----------------------------------------------------------------------------
#
proc ADMIN::FORM::do_race_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdFormRace (
			p_adminuser        = ?,
			p_form_provider_id = ?,
			p_meeting_id       = ?,
			p_ext_race_id      = ?,
			p_start_time       = ?,
			p_title            = ?,
			p_race_no          = ?,
			p_dist_y           = ?,
			p_dist_f           = ?,
			p_going            = ?,
			p_class            = ?,
			p_prize            = ?,
			p_flat_or_jumps    = ?,
			p_overview         = ?,
			p_updateable       = ?
		)
	}]
   
	set stmt [inf_prep_sql $DB $sql]
   
	if {[catch {
		set res [inf_exec_stmt -inc-type $stmt $USERNAME STRING\
		                             [reqGetArg FormProviderId] STRING\
		                             [reqGetArg MeetingId] STRING\
		                             [reqGetArg ExtRaceId] STRING\
		                             [reqGetArg StartTime] STRING\
		                             [reqGetArg Title] STRING\
		                             [reqGetArg RaceNo] STRING\
		                             [reqGetArg DistY] STRING\
		                             [reqGetArg DistF] STRING\
		                             [reqGetArg Going] STRING\
		                             [reqGetArg Class] STRING\
		                             [reqGetArg Prize] STRING\
		                             [reqGetArg FlatOrJumps] STRING\
		                             [reqGetArg Overview] TEXT\
		                             [reqGetArg Updateable] STRING]
	} msg]} {
		err_bind $msg
	} else {
		tpSetVar RaceUpdated 1
	}

	catch { db_close $res }
	inf_close_stmt $stmt

	go_race
}