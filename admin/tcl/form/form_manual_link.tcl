# ==============================================================
# $Id: form_manual_link.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================



namespace eval ADMIN::FORM {

#
# Display source/target event choice screen
#
proc go_manual_links {} {

	if {![op_allowed ManageFormFeeds]} {
		err_bind "You do not have permission to manage form feeds"
		asPlayFile -nocache form/event_choice.html
		return
	}

	set form_provider_id [reqGetArg FormProviderId]

	set default_form_provider_id [make_form_feed_provider_binds]

	if {$form_provider_id == ""} {
		set form_provider_id $default_form_provider_id
	}

	tpBindString SELECTED_FORM_PROVIDER_ID $form_provider_id

	set race_id [reqGetArg race_id]

	tpSetVar RACE_ID $race_id

	if {$race_id == ""} {
		# default, show all
		go_manual_links_races $form_provider_id
	} else {
		# race_id specified 
		go_manual_links_runners $race_id
	}

	asPlayFile -nocache form/event_choice.html
}

proc go_manual_links_races {form_provider_id} {

	global DB FORM_RACES

	set sql { 
		select
			c.name       as course_name,
			r.title      as title,
			r.start_time as race_start_time,
			r.race_id    as race_id,
			e.desc       as desc,
			e.start_time as ev_start_time,
			e.ev_id      as ev_id,
			t.name       as ev_type_name,
			e.ev_type_id as ev_type_id,
			t.ev_class_id as ev_class_id
		from
			tFormCourse c,
			tFormMeeting m,
			tFormRace r,
			outer (tEv e, tEvType t)
		where
			c.course_id = m.course_id and
			m.meeting_id = r.meeting_id and
			r.start_time >= today and
			r.form_provider_id = ? and
			r.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
		order by
			1,3,2
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt $form_provider_id]
	set nrows [db_get_nrows $rs]

	tpSetVar NumRaces $nrows

	for {set i 0} {$i < $nrows} {incr i} {
		set FORM_RACES($i,course_name)     [db_get_col $rs $i course_name]
		set FORM_RACES($i,title)           [db_get_col $rs $i title]
		set FORM_RACES($i,race_start_time) [db_get_col $rs $i race_start_time]
		set FORM_RACES($i,race_id)         [db_get_col $rs $i race_id]
		set FORM_RACES($i,desc)            [db_get_col $rs $i desc]
		set FORM_RACES($i,ev_start_time)   [db_get_col $rs $i ev_start_time]
		set FORM_RACES($i,ev_id)           [db_get_col $rs $i ev_id]
		set FORM_RACES($i,ev_type_name)    [db_get_col $rs $i ev_type_name]
		set FORM_RACES($i,ev_type_id)    [db_get_col $rs $i ev_type_id]
		set FORM_RACES($i,ev_class_id)    [db_get_col $rs $i ev_class_id]
	}

	tpBindVar COURSE_NAME     FORM_RACES course_name race_idx
	tpBindVar TITLE           FORM_RACES title race_idx
	tpBindVar RACE_START_TIME FORM_RACES race_start_time race_idx
	tpBindVar RACE_ID         FORM_RACES race_id race_idx
	tpBindVar DESC            FORM_RACES desc race_idx
	tpBindVar EV_START_TIME   FORM_RACES ev_start_time race_idx
	tpBindVar EV_ID           FORM_RACES ev_id race_idx
	tpBindVar EV_TYPE_NAME    FORM_RACES ev_type_name race_idx
	tpBindVar EV_TYPE_ID      FORM_RACES ev_type_id race_idx
	tpBindVar EV_CLASS_ID     FORM_RACES ev_class_id race_idx

	catch {db_close $rs}
	inf_close_stmt $stmt
}

proc go_manual_links_runners {race_id} {

	global DB FORM_RUNNERS

	set sql_race {
		select
			c.name        as course_name,
			r.title       as title,
			r.start_time  as race_start_time,
			r.race_id     as race_id,
			e.desc        as ev_desc,
			e.start_time  as ev_start_time,
			e.ev_id       as ev_id,
			t.name        as ev_type_name,
			e.ev_type_id  as ev_type_id,
			t.ev_class_id as ev_class_id
		from
			tFormCourse c,
			tFormMeeting m,
			tFormRace r,
			outer (tEv e, tEvType t)
		where
			c.course_id = m.course_id and
			m.meeting_id = r.meeting_id and
			r.race_id = ? and
			r.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
	}


	set sql_runners { 
		select
			co.name        as comp_name,
			ru.runner_id  as runner_id,
			ru.runner_num as runner_num,
			oc.desc       as oc_desc,
			oc.runner_num as oc_runner_num,
			oc.ev_oc_id   as oc_id
		from
			tFormRace r,
			tFormRunner ru,
			tFormCompetitor co,
			outer tEvOc oc
		where
			r.race_id = ? and
			r.race_id = ru.race_id and
			ru.competitor_id = co.competitor_id and
			ru.ev_oc_id = oc.ev_oc_id
		order by
			3
	}

	set stmt  [inf_prep_sql $DB $sql_race]
	set rs    [inf_exec_stmt $stmt $race_id]
	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		error "Failed to find race_id : $race_id"
	}

	tpBindString COURSE_NAME     [db_get_col $rs 0 course_name]
	tpBindString TITLE           [db_get_col $rs 0 title]
	tpBindString RACE_START_TIME [db_get_col $rs 0 race_start_time]
	tpBindString RACE_ID         [db_get_col $rs 0 race_id]
	tpBindString EV_DESC         [db_get_col $rs 0 ev_desc]
	tpBindString EV_START_TIME   [db_get_col $rs 0 ev_start_time]
	tpBindString EV_ID           [db_get_col $rs 0 ev_id]
	tpBindString EV_TYPE_NAME    [db_get_col $rs 0 ev_type_name]
	tpBindString EV_TYPE_ID      [db_get_col $rs 0 ev_type_id]
	tpBindString EV_CLASS_ID     [db_get_col $rs 0 ev_class_id]

	set stmt  [inf_prep_sql $DB $sql_runners]
	set rs    [inf_exec_stmt $stmt $race_id]
	set nrows [db_get_nrows $rs]

	tpSetVar NumRunners $nrows

	for {set i 0} {$i < $nrows} {incr i} {

		set FORM_RUNNERS($i,comp_name)       [db_get_col $rs $i comp_name]
		set FORM_RUNNERS($i,runner_id)       [db_get_col $rs $i runner_id]
		set FORM_RUNNERS($i,runner_num)      [db_get_col $rs $i runner_num]
		set FORM_RUNNERS($i,oc_desc)         [db_get_col $rs $i oc_desc]
		set FORM_RUNNERS($i,oc_runner_num)   [db_get_col $rs $i oc_runner_num]
		set FORM_RUNNERS($i,oc_id)           [db_get_col $rs $i oc_id]
	}


	tpBindVar COMP_NAME       FORM_RUNNERS comp_name runner_idx
	tpBindVar RUNNER_ID       FORM_RUNNERS runner_id runner_idx
	tpBindVar RUNNER_NUM      FORM_RUNNERS runner_num runner_idx
	tpBindVar OC_DESC         FORM_RUNNERS oc_desc runner_idx
	tpBindVar OC_RUNNER_NUM   FORM_RUNNERS oc_runner_num runner_idx
	tpBindVar OC_ID           FORM_RUNNERS oc_id runner_idx

	catch {db_close $rs}
	inf_close_stmt $stmt
}

#
# Attempts to link an Openbet 
#
# event - > form feed race 
# OR
# openbet selection -> form feed runner
#
# Note linking a race will attempt to link all runners in the race.
#
proc do_manual_links {} {

	if {![op_allowed ManageFormFeeds]} {
		err_bind "You do not have permission to manage form feeds"
		asPlayFile -nocache form/event_choice.html
		return
	}

	set submit_name [reqGetArg SubmitName]

	switch $submit_name {
		InsLink {ins_link}
		DelLink {del_link}
		default { error "unknown submit name action" }
	}

	go_manual_links

}

proc ins_link {} {

	global DB USERNAME

	set source_id [reqGetArg source_id]
	set target_id [reqGetArg target_id]
	set source_level [reqGetArg source_level]
	set target_level [reqGetArg target_level]

	# validation

	if {!(($source_level == "RACE" && $target_level == "EVENT") ||
		($source_level == "RUNNER" && $target_level == "SELN"))} {
		err_bind "Failed to link entities, mismatching levels"
		go_manual_links
		return
	}

	if {$source_id == "" || $target_id == ""} {
		err_bind "Error - Must supply two entities"
		go_manual_links
		return
	}

	if {$source_level == "RACE"} {
		set sql {
			execute procedure pFormLinkRace (
				p_adminuser = ?,
				p_race_id = ?,
				p_ev_id = ?
			)
		}
	} elseif {$source_level == "RUNNER"} {
		set sql {
			update
				tFormRunner
			set
				ev_oc_id = ?
			where
				runner_id = ?
		}
	}

	set stmt [inf_prep_sql $DB $sql]

	if {$source_level == "RACE"} {
		set res  [inf_exec_stmt $stmt $USERNAME $source_id $target_id]
	} else {
		set res  [inf_exec_stmt $stmt $target_id $source_id]
	}

	msg_bind "Successfully linked"

	inf_close_stmt $stmt
	db_close $res

}

proc del_link {} {

	global DB USERNAME

	set source_id [reqGetArg source_id]
	set source_level [reqGetArg source_level]

	if {$source_level == "RACE"} {
		set race_sql {
			update
				tFormRace
			set
				ev_id = null
			where
				race_id = ?
		}
		set runner_sql {
			update
				tFormRunner
			set
				ev_oc_id = null
			where
				race_id = ?
		}
	} else {
		set runner_sql {
			update
				tFormRunner
			set
				ev_oc_id = null
			where
				runner_id = ?
		}
	}

	if {$source_level == "RACE"} {
		set race_stmt [inf_prep_sql $DB $race_sql]
		set race_res  [inf_exec_stmt $race_stmt $source_id]
	}

	set runner_stmt [inf_prep_sql $DB $runner_sql]
	set runner_res  [inf_exec_stmt $runner_stmt $source_id]

	msg_bind "Successfully deleted"

	if {$source_level == "RACE"} {
		inf_close_stmt $race_stmt
		db_close $race_res
	}

	inf_close_stmt $runner_stmt
	db_close $runner_res
}



#
# Display popup drilldown
#
proc go_dd {} {

	variable FORM_LEVEL_INFO

	set choice [reqGetArg choice]

	# Tell ADMIN::POPUP_DD::go_dd that only events may be selected
	#reqSetArg selectable_levels "RACE,RUNNER,SELN,EVENT"

	set override_array ""
	reqSetArg blurb "Please select a User Controlled Event"

	return [ADMIN::POPUP_DD::go_dd $override_array [list choice]]
}

}