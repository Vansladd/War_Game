# ==============================================================
# $Id: amalco.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================
# Used to simulate the application that amalco
# would use to send incidents through to openbet
#
namespace eval ADMIN::AMALCO {

asSetAct ADMIN::AMALCO::go_incidents  [namespace code go_incidents]
asSetAct ADMIN::AMALCO::show_incident [namespace code show_incident]
asSetAct ADMIN::AMALCO::adjust_clock  [namespace code adjust_clock]

proc go_incidents args {
	global DB
	global SPORT STATISTIC SCORETYPE PERIOD COMPETITOR PLAYER LANG

	catch {unset SPORT}
	catch {unset STATISTIC}
	catch {unset SCORETYPE}
	catch {unset PERIOD}
	catch {unset COMPETITOR}
	catch {unset PLAYER}
	catch {unset LANG}

	set ev_id [reqGetArg EvId]

	set sql_lang {
		select
			lang,
			name
		from
			tLang
	}

	set sql_periods {
		select
			cpt.period_code period_code,
			cpt.desc        period_desc
		from
			tComSportPeriod csp,
			tComPeriodType  cpt
		where
			csp.period_code = cpt.period_code and
			csp.ob_id     = (
				case
					when ob_level = 'Y' then (
						select
							ey.ev_category_id
						from
							tEvCategory ey,
							tEvClass    ec,
							tEvType     et,
							tEv         e
						where
							ey.category    = ec.category    and
							ec.ev_class_id = et.ev_class_id and
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
					when ob_level = 'C' then (
						select
							et.ev_class_id
						from
							tEvType     et,
							tEv         e
						where
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
				end
			)
	}

	set sql_stats {
		select
			cst.stat_code stat_code,
			cst.desc      stat_desc
		from
			tComSportStat css,
			tComStatType  cst
		where
			css.stat_code = cst.stat_code and
			css.ob_id        = (
				case
					when ob_level = 'Y' then (
						select
							ey.ev_category_id
						from
							tEvCategory ey,
							tEvClass    ec,
							tEvType     et,
							tEv         e
						where
							ey.category    = ec.category    and
							ec.ev_class_id = et.ev_class_id and
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
					when ob_level = 'C' then (
						select
							et.ev_class_id
						from
							tEvType     et,
							tEv         e
						where
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
				end
			)
	}

	set sql_scores {
		select
			cst.score_code score_code,
			cst.desc       score_desc
		from
			tComSportScore css,
			tComScoreType  cst
		where
			css.score_code = cst.score_code and
			css.ob_id         = (
				case
					when ob_level = 'Y' then (
						select
							ey.ev_category_id
						from
							tEvCategory ey,
							tEvClass    ec,
							tEvType     et,
							tEv         e
						where
							ey.category    = ec.category    and
							ec.ev_class_id = et.ev_class_id and
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
					when ob_level = 'C' then (
						select
							et.ev_class_id
						from
							tEvType     et,
							tEv         e
						where
							et.ev_type_id  = e.ev_type_id   and
							e.ev_id        = ?
					)
				end
			)
	}

	set sql_participants {
		select
			cp.ext_id,
			eo.desc
		from
			tComParticipant cp,
			tEvOc           eo
		where
			cp.ev_oc_id  = eo.ev_oc_id and
			cp.part_type = ?           and
			cp.ev_id     = ?
	}

	set sql_current_event_time {
		select
			c.state,
			cast((case
				when c.state = 'R' then CURRENT       - c.offset - e.start_time
				when c.state = 'S' then c.last_update - c.offset - e.start_time
			end) as interval hour to second) current_event_time,
			c.period_code
		from
			tComClockState c,
			tEv e
		where
			c.ev_id = e.ev_id and
			e.ev_id = ?
	}

	# Languages
	set stmt [inf_prep_sql $DB $sql_lang]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set LANG(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $LANG(nrows)} {incr i} {
		set LANG($i,lang_code) [db_get_col $rs $i lang]
		set LANG($i,lang_name) [db_get_col $rs $i name]
	}
	db_close $rs

	# Periods
	set stmt [inf_prep_sql $DB $sql_periods]
	set rs   [inf_exec_stmt $stmt $ev_id $ev_id]
	inf_close_stmt $stmt

	set PERIOD(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $PERIOD(nrows)} {incr i} {
		set PERIOD($i,period_code) [db_get_col $rs $i period_code]
		set PERIOD($i,period_desc) [db_get_col $rs $i period_desc]
	}
	db_close $rs

	# Statistics
	set stmt [inf_prep_sql $DB $sql_stats]
	set rs   [inf_exec_stmt $stmt $ev_id $ev_id]
	inf_close_stmt $stmt

	set STATISTIC(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $STATISTIC(nrows)} {incr i} {
		set STATISTIC($i,stat_code) [db_get_col $rs $i stat_code]
		set STATISTIC($i,stat_desc) [db_get_col $rs $i stat_desc]
	}
	db_close $rs

	# Scores
	set stmt [inf_prep_sql $DB $sql_scores]
	set rs   [inf_exec_stmt $stmt $ev_id $ev_id]
	inf_close_stmt $stmt

	set SCORETYPE(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $SCORETYPE(nrows)} {incr i} {
		set SCORETYPE($i,score_code) [db_get_col $rs $i score_code]
		set SCORETYPE($i,score_desc) [db_get_col $rs $i score_desc]
	}
	db_close $rs

	# Competitor information
	set stmt [inf_prep_sql $DB $sql_participants]
	set rs   [inf_exec_stmt $stmt "C" $ev_id]
	inf_close_stmt $stmt

	set COMPETITOR(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $COMPETITOR(nrows)} {incr i} {
		set COMPETITOR($i,competitor_id)   [db_get_col $rs $i ext_id]
		set COMPETITOR($i,competitor_desc) [string trim [db_get_col $rs $i desc] "|"]
	}
	db_close $rs

	# Player information
	set stmt [inf_prep_sql $DB $sql_participants]
	set rs   [inf_exec_stmt $stmt "P" $ev_id]
	inf_close_stmt $stmt

	set PLAYER(nrows) [db_get_nrows $rs]
	for {set i 0} {$i < $PLAYER(nrows)} {incr i} {
		set PLAYER($i,player_id)   [db_get_col $rs $i ext_id]
		set PLAYER($i,player_desc) [string trim [db_get_col $rs $i desc] "|"]
	}
	db_close $rs

	# Current event time
	set stmt [inf_prep_sql $DB $sql_current_event_time]
	set rs   [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {
		set current_event_time   [convert_to_mmss [db_get_col $rs 0 current_event_time]]
		set current_event_period [db_get_col $rs 0 period_code]
		set current_event_state  [db_get_col $rs 0 state]
	} else {
		set current_event_time   "00:00:00"
		set current_event_period "ns"
		set current_event_state  "S"
	}

	if {$current_event_state == "S"} {
		tpBindString stop_disabled "disabled=\"disabled\""
	} else {
		tpBindString start_disabled "disabled=\"disabled\""
	}

	tpBindString current_event_time   $current_event_time
	tpBindString current_event_period $current_event_period
	tpBindString current_event_state  $current_event_state

	tpBindVar lang_code         LANG       lang_code       lang_idx
	tpBindVar lang_name         LANG       lang_name       lang_idx
	tpBindVar PERIOD_code       PERIOD     period_code     period_idx
	tpBindVar PERIOD_desc       PERIOD     period_desc     period_idx
	tpBindVar STAT_code         STATISTIC  stat_code       stat_idx
	tpBindVar STAT_desc         STATISTIC  stat_desc       stat_idx
	tpBindVar SCORE_code        SCORETYPE  score_code      score_idx
	tpBindVar SCORE_desc        SCORETYPE  score_desc      score_idx
	tpBindVar COMPETITOR_id     COMPETITOR competitor_id   competitor_idx
	tpBindVar COMPETITOR_desc   COMPETITOR competitor_desc competitor_idx
	tpBindVar PLAYER_id         PLAYER     player_id       player_idx
	tpBindVar PLAYER_desc       PLAYER     player_desc     player_idx

	tpBindString ev_id [reqGetArg EvId]

	asPlayFile -nocache amalco.html
}

proc show_incident args {
	global DB

	set sql_incident {
		execute procedure pInsComIncident (
			p_ev_id         = ?,
			p_ev_msg_id     = ?,
			p_ext_inc_id    = ?,
			p_period_code   = ?,
			p_period_num    = ?,
			p_score_code    = ?,
			p_score_value   = ?,
			p_competitor_id = ?
		)
	}

	set sql_participant {
		select
			cp.ev_oc_id,
			cp.part_type
		from
			tComParticipant cp,
			tevoc           eo
		where
			cp.ev_oc_id = eo.ev_oc_id and
			eo.ev_id    = ?           and
			eo.desc  like ?
	}

	set ev_id         [reqGetArg EvId]
	set incident_type [reqGetArg incident_type]

	set period_code [reqGetArg period]
	set stat_code   [reqGetArg statistic]

	# Encapsulate score in stat
	if {$stat_code == ""} {
		set stat_code "SCRE"
	}

	set score_code  [reqGetArg score]
	set participant [reqGetArg participant]

	set value       [reqGetArg value]
	set freeform_text [reqGetArg freeform_text]
	set freeform_lang [reqGetArg freeform_lang]

	# Generate a random incident id
	# A string of alpha-numeric characters
	set ext_inc_id {}
	set str "abcdefghijklmnopqrstuvwxyz1234567890"
	set len [string length $str]
	# Creating a 8-character long alphanumeric id
	for {set i 0} {$i < 8} {incr i} {
	     append ext_inc_id [string index $str [expr {int(rand()*$len)}]]
	}

	set period_num 0

	# Get the incident time in MM:SS format
	set incident_time [reqGetArg incident_time]

	# And convert it to HH:MM:SS format
	set incident_time [convert_to_hhmmss $incident_time]

	# Determine the numerical id's and type of the participant
	set stmt [inf_prep_sql $DB $sql_participant]
	set rs   [inf_exec_stmt $stmt $ev_id "%${participant}%"]
	inf_close_stmt $stmt
	set participant_id [db_get_col $rs 0 ev_oc_id]
	set type           [db_get_col $rs 0 part_type]
	db_close $rs

	# Now decide whether to insert into tComMsg.(competitor_id|player_id)
	if {$type == "C"} {
		set participant_param "p_competitor_id"
	} else {
		set participant_param "p_player_id"
	}

	set sql_msg [subst {
		execute procedure pInsComMsg (
			p_ev_id         = ?,
			p_clock_time    = ?,
			p_period_code   = ?,
			p_period_num    = ?,
			p_stat_code     = ?,
			$participant_param = ?,
			p_free_txt      = ?,
			p_free_txt_lang = ?
		)
	}]

	# Insert the incident/message into the DB
	set stmt [inf_prep_sql $DB $sql_msg]
	set rs   [inf_exec_stmt $stmt $ev_id $incident_time $period_code $period_num $stat_code $participant_id $freeform_text $freeform_lang]
	inf_close_stmt $stmt
	set ev_msg_id [db_get_coln $rs 0 0]

	db_close $rs

	set stmt [inf_prep_sql $DB $sql_incident]
	inf_exec_stmt $stmt $ev_id $ev_msg_id $ext_inc_id $period_code $period_num $score_code $value $participant_id
	inf_close_stmt $stmt


	# Now bind everything up for output back to the screen
	tpBindString inc_period_code $period_code
	tpBindString inc_participant $participant

	if {$incident_type == "t"} {
		tpBindString incident_type "Statistic"
		tpBindString inc_code $stat_code
	} elseif {$incident_type == "s"} {
		tpBindString incident_type "Score"
		tpBindString inc_code $score_code
	}

	tpBindString inc_value $value
	tpBindString inc_freeform_text $freeform_text
	tpBindString inc_freeform_lang $freeform_lang
	tpBindString inc_incident_time [convert_to_mmss $incident_time]

	reqSetArg EvId $ev_id
	go_incidents
}

proc adjust_clock args {
	global DB

	set start_stop_clock_sql {
		execute procedure pUpdComClock (
			p_ev_id       = ?,
			p_period_code = ?,
			p_operation   = ?,
			p_has_bir     = ?
		)
	}

	set adjust_clock_sql {
		execute procedure pUpdComClock (
			p_ev_id       = ?,
			p_period_code = ?,
			p_operation   = ?,
			p_has_bir     = ?,
			p_new_time    = ?
		)
	}

	set operation   [reqGetArg operation]
	set ev_id       [reqGetArg ev_id]
	set period_code [reqGetArg period_code]

	switch $operation {
		"startClock" {
			set stmt [inf_prep_sql $DB $start_stop_clock_sql]
			set rs   [inf_exec_stmt $stmt $ev_id $period_code "C" "Y"]
		}
		"stopClock" {
			set stmt [inf_prep_sql $DB $start_stop_clock_sql]
			set rs   [inf_exec_stmt $stmt $ev_id $period_code "S" "Y"]
		}
		"adjustClock" {
			set stmt [inf_prep_sql $DB $start_stop_clock_sql]
			set rs   [inf_exec_stmt $stmt $ev_id $period_code "A" "Y" $new_time]
		}
	}
	inf_close_stmt $stmt

	set current_state  [db_get_coln $rs 0 0]
	set current_time   [convert_to_mmss [db_get_coln $rs 0 1]]
	set current_period [db_get_coln $rs 0 2]

	db_close $rs

	set str "VAL|$current_state|$current_time|$current_period"

	play_AJAX_string $str
}

# Play a html string for use with AJAX apps
#
#   Some string that we want played
#
proc play_AJAX_string {string} {

	ob_log::write INFO {*** playing AJAX request ***}

	tpBufAddHdr "Content-Type" "text/html;charset=utf-8"
	tpBufWrite $string

}

#
# Convert time that is in MM:SS format into HH:MM:SS format
#
proc convert_to_hhmmss {incident_time} {
	set time_list [split $incident_time ":"]

	set ss [lindex $time_list 1]

	set mm [lindex $time_list 0]
	if {$mm > 0} {
		set mm [string trimleft $mm "0"]
	}

	set hh [expr {$mm / 60}]
	set mm [expr {$mm % 60}]

	if {[string length $hh] < 2} {
		set hh "0$hh"
	}

	if {[string length $mm] < 2} {
		set mm "0$mm"
	}

	set incident_time "$hh:$mm:$ss"

	return $incident_time
}

proc convert_to_mmss {incident_time} {
	set time_list [split $incident_time ":"]

	set hh [lindex $time_list 0]
	set mm [lindex $time_list 1]

	if {$hh > 0} {
		set hh [string trimleft $hh "0"]
	}

	if {$mm > 0} {
		set mm [string trimleft $mm "0"]
	}

	set ss [lindex $time_list 2]

	set mm [expr {($hh * 60) + $mm}]

	set incident_time "$mm:$ss"

	if {[string length $incident_time] < 5} {
		set incident_time "0$incident_time"
	}

	return $incident_time
}
}
