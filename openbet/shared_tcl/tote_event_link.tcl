# ==============================================================
# $Id: tote_event_link.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# Copyright OpenBet 2011. All rights reserved.
# ==============================================================
#
# Shared functions to be used to link tote events to Fixed
# odd events.
#
#
# Procedures:
# ==============================================================
# ins_ev_link - Attempts to find and create a suitable link
#               between Tote events and Fixed odd events.
# ==============================================================


namespace eval TOTE_EVENT_LINK {
}



##
# DESCRIPTION
#
# This procedures attempts find and create a suitable link from the
#   specified event. This is achieved by looking for a type linking and
#   creating the link based on the type and start time.
#
#   NORMAL              TOTE
#
#   type  --  link  --  type     poolType
#    |                   |
#   event --  link  --  event    pool
#                        |
#                       mkt  --  poolMkt
#
# NOTE: This procedures is used by both
#    -  tote/feed/client_db.tcl and
#    -  openbet/admin/tcl/tote.tcl
##
proc TOTE_EVENT_LINK::ins_ev_link {ev_id start_time {expected_norm_ev_id -1} {transactional "Y"}} {

	OT_LogWrite 1 "in TOTE_EVENT_LINK::ins_ev_link"

	if {![string is integer -strict $ev_id] ||\
			![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d(:\d\d)?$} $start_time]} {
		error "Invalid arguments: the ev_id must be an integer and the\
			start_time must be a informix date (year to minute)."
	}

	# look up the matching event
	ob_db::store_qry TOTE_EVENT_LINK::sel_ev_link {
		select
			en.ev_id
		from
			tEv            en,
			tEvType        tn,
			tToteTypeLink  l,
			tEvType        tt,
			tEv            et
		where
			en.ev_type_id         = tn.ev_type_id
			and tn.ev_type_id     = l.ev_type_id_norm
			and l.ev_type_id_tote = tt.ev_type_id
			and tt.ev_type_id     = et.ev_type_id
			and et.ev_id          = ?
			and extend(en.start_time, year to minute) = extend(?,year to minute);
	}

	set rs    [ob_db::exec_qry TOTE_EVENT_LINK::sel_ev_link $ev_id [string range $start_time 0 15]]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set ev_id_norm [db_get_col $rs 0 ev_id]
	}
	ob_db::rs_close $rs
	ob_db::unprep_qry TOTE_EVENT_LINK::sel_ev_link

	if {$nrows != 1} {
		error "A suitable link could not be created for event $ev_id,$start_time\
				because $nrows rows were found."
	}

	# If we have an ev_id we are expecting to have matched to, check it now.
	if {$expected_norm_ev_id != -1 && $expected_norm_ev_id != $ev_id_norm} {
		OT_LogWrite 1 "expected_norm_ev_id ($expected_norm_ev_id) not equal to matched\
				norm ev_id ($ev_id_norm)."
		return [list 0 $ev_id_norm]
	}

	ob_db::store_qry TOTE_EVENT_LINK::ins_ev_link {
		execute procedure pInsToteEvLink(
			p_ev_id_tote    = ?,
			p_ev_id_norm    = ?,
			p_transactional = ?
		);
	}

	if {[catch {\
		ob_db::rs_close [ob_db::exec_qry TOTE_EVENT_LINK::ins_ev_link $ev_id $ev_id_norm $transactional]\
	} msg]} {
		OT_LogWrite 1 "ins_ev_link - $msg"
		ob_db::unprep_qry TOTE_EVENT_LINK::ins_ev_link
		return [list 0 INS_EV_LINK]
	}

	ob_db::unprep_qry TOTE_EVENT_LINK::ins_ev_link

	return [list 1 $ev_id_norm]
}

# Link a scoop6 event to the tote ev_id it is cloned from. We then use the tote
# linking table (with the assumption that the tote event will have come through
# the feed first and linked) to get the fixed odd ev_id.
proc TOTE_EVENT_LINK::ins_scoop6_ev_link { \
	ev_id                            \
	race_name                        \
	start_time                       \
	tote_class_id                    \
	{expecting_fixed_odds_mapping 1} \
	{transactional              {Y}} \
} {

	set fn "TOTE_EVENT_LINK::ins_scoop6_ev_link"

	OT_LogWrite 1 "==> $fn - ev_id=$ev_id, race_name=$race_name,\
			start_time=$start_time, tote_class_id=$tote_class_id"

	if {![string is integer -strict $ev_id] || ![string is integer -strict $tote_class_id] || ![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d(:\d\d)?$} $start_time] } {
		error "Invalid arguments: the ev_id must be an integer, the\
			start_time must be a informix date (year to minute)."
	}

	set ret [_process_scoop6_race_name $race_name]

	if {[lindex $ret 0] == 0} {
		error [lindex $ret 1]
	}

	set ev_type_first_name [lindex $ret 1]
	set ev_type_full_name  [lindex $ret 2]
	set race_number        [lindex $ret 3]

	set ev_type_first_name_wc "${ev_type_first_name}%"

	OT_LogWrite 1 "$fn - ev_type_first_name_wc = $ev_type_first_name_wc,\
			ev_type_full_name = $ev_type_full_name, race_number = $race_number"

	# We now check to find the correct tote ev id using the race number, event type
	# name, a fixed value for the class type and the start time
	ob_db::store_qry TOTE_EVENT_LINK::find_fixed_odds_ev_id {
		select
			NVL(tl.ev_id_norm,-1) as fo_ev_id,
			t.ev_id,
			t.start_time,
			tt.name
		from
			tEv               t,
			tEvType           tt,
			outer tToteEvLink tl
		where
			t.ev_id                              =    tl.ev_id_tote             and
			t.ev_type_id                         =    tt.ev_type_id             and
			t.ev_class_id                        =    ?                         and
			tt.ev_class_id                       =    ?                         and
			tt.name                              like ?                         and
			t.race_number                        =    ?                         and
			extend(t.start_time, YEAR TO MINUTE) =    extend(?,YEAR TO MINUTE);
	}

	set rs [ob_db::exec_qry TOTE_EVENT_LINK::find_fixed_odds_ev_id\
			$tote_class_id         \
			$tote_class_id         \
			$ev_type_first_name_wc \
			$race_number           \
			[string range $start_time 0 15]]

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		error "Unable to find tote event match for scoop6 ev_id = $ev_id."
	}

	set tote_match_found 0
	for {set i 0} {$i < $nrows} {incr i} {

		set fo_ev_id           [db_get_col $rs $i fo_ev_id]
		set tote_ev_id         [db_get_col $rs $i ev_id]
		set tote_ev_start_time [db_get_col $rs $i start_time]
		set db_ev_type_name    [db_get_col $rs $i name]

		OT_LogWrite 1 "$fn - db row = $i, fo_ev_id = $fo_ev_id, tote_ev_id =\
				$tote_ev_id, db_ev_type_name = $db_ev_type_name"

		# If we return only 1 row, we will assume that it is a correct match.
		if {$nrows == 1} {
			set tote_match_found 1
			break
		}

		# If there are multiple rows returned, we will only match if we find an
		# exact match for the event type name.
		if {$db_ev_type_name == $ev_type_full_name} {
			OT_LogWrite 1 "$fn - find_fixed_odds_ev_id has returned more than one\
					row, we have identified a match though for the full type name -\
					$ev_type_full_name"
			set tote_match_found 1
			break
		}
	}

	ob_db::rs_close $rs
	ob_db::unprep_qry TOTE_EVENT_LINK::find_fixed_odds_ev_id

	if {$tote_match_found == 0} {
		OT_LogWrite 1 "$fn - Unable to find tote event match for scoop6 ev_id = $ev_id.\
				Multiple rows returned by the query."
		error "Unable to find tote event match for scoop6 ev_id = $ev_id."
	}

	OT_LogWrite 1 "$fn - Matched Scoop6 event (ev_id = $ev_id) to Tote event\
			(tote_ev_id = $tote_ev_id). Checking for valid link to fixed odds event in\
			tToteEvLink."

	if {$fo_ev_id == -1} {

		if {$expecting_fixed_odds_mapping == 1} {

			OT_LogWrite 1 "$fn - a Tote match was found for this Scoop6 event however no\
					link to a fixed odds event could be found with the tote event."

			# At this point if this occurs too frequently we can add functionality to
			# add the details to a queue table and then have a cron attempt the
			# match again later. This may happen if the Scoop6 event comes down the feed
			# before its related Tote event.
			error "Unable to find a fixed odds event match for scoop6 ev_id = $ev_id using\
					tToteEvLink and tote ev_id = $tote_ev_id"
		} else {

			OT_LogWrite 1 "$fn - not expecting a fixed odds mapping. Returning found\
					tote_ev_id = $tote_ev_id"

			# Return the tote_ev_id
			return [list 1 $tote_ev_id $tote_ev_start_time]
		}
	}

	OT_LogWrite 1 "$fn - A fixed odds ev_id has been found for this Scoop6 event.\
			Scoop6 ev_id = $ev_id, fixed odds ev_id = $fo_ev_id."

	# Add the fixed odds ev_id to the linking table tEvLink
	ob_db::store_qry TOTE_EVENT_LINK::ins_scoop6_ev_link {
		execute procedure pInsEvLink(
			p_ev_id         = ?,
			p_rel_ev_id     = ?,
			p_type          = ?,
			p_transactional = ?
		);
	}

	# p_ev_id is the fixed odds event, p_rel_ev_id is the Scoop6 event.
	set rs [ob_db::exec_qry TOTE_EVENT_LINK::ins_scoop6_ev_link \
			$fo_ev_id \
			$ev_id    \
			"Scoop6"  \
			$transactional]

	set ev_link_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs
	ob_db::unprep_qry TOTE_EVENT_LINK::ins_scoop6_ev_link

	OT_LogWrite 1 "$fn - Successfully inserted into tEvLink, ev_link_id = $ev_link_id"

	return [list 1 $fo_ev_id]
}

# Takes the tote event start time, event type name and race number and compares
# with the scoop6 event start time and the race number and event type name found
# in the event desc column.
proc TOTE_EVENT_LINK::compare_tote_and_scoop6 {\
	tote_ev_id           \
	scoop6_ev_id         \
	tote_ev_type_name    \
	tote_ev_start_time   \
	tote_ev_race_number  \
	scoop6_ev_desc       \
	scoop6_ev_start_time \
} {

	set fn "TOTE_EVENT_LINK::compare_tote_and_scoop6"

	OT_LogWrite 1 "$fn - Comparing tote event to scoop6 event. scoop6_ev_id =\
			$scoop6_ev_id, tote_ev_id = $tote_ev_id."

	# Before even looking at the scoop6 description etc. we can check the start
	# times.
	if {$tote_ev_start_time != $scoop6_ev_start_time} {
		# Failed to match.
		OT_LogWrite 1 "Didn't match on start time. tote start time =\
				$tote_ev_start_time, scoop6 start time = $scoop6_ev_start_time"
		return [list 0 START_TIME]
	}

	# Process the scoop6 event description.
	set ret [_process_scoop6_race_name $scoop6_ev_desc]

	if {[lindex $ret 0] == 0} {
		OT_LogWrite 1 "_process_scoop6_race_name has failed."
		error [lindex $ret 1]
	}

	set scoop6_ev_type_first_name [lindex $ret 1]
	set scoop6_ev_type_full_name  [lindex $ret 2]
	set scoop6_race_number        [lindex $ret 3]

	OT_LogWrite 1 "$fn - Scoop6 info: ev_type_first_name = $scoop6_ev_type_first_name,\
			ev_type_full_name = $scoop6_ev_type_full_name, race_number = $scoop6_race_number"

	OT_LogWrite 1 "$fn - Tote info: ev_type_name = $tote_ev_type_name,\
			race_number = $tote_ev_race_number"

	# We only need a match against the first name; in conjunction with the start
	# time it's fair to say we've matched the correctly.
	set match_index [string first $tote_ev_type_name $scoop6_ev_type_first_name]

	# The match must be at the start of the string - match_index must be 0
	if {$match_index != 0} {
		# Failed to match.
		OT_LogWrite 1 "Didn't match on event type name."
		return [list 0 EV_TYPE_NAME]
	}

	# Checks passed.
	return 1
}

proc TOTE_EVENT_LINK::_process_scoop6_race_name {race_name} {

	OT_LogWrite 1 "==> TOTE_EVENT_LINK::_process_scoop6_race_name"

	if {![regexp {^Clone Race of} $race_name]} {
		set msg "Invalid race_name - must start with 'Clone Race of'."
		return [list 0 $msg]
	}

	# We need to establish the tote event that this has been cloned from.
	#
	# Get the ev type name from the race_name string. We know that the class type
	# is |Tote Pools| so we can get the event type from this (config).
	#
	# Usefully some event type names are different to that in the string we get
	# through the feed for scoop6. E.g Newmarket Rowley Mile (in tEvType) and
	# Clone Race of Newmarket (Rowley M) Race 3 through the feed. For this reason
	# we will do a wild card search in the query using the first word of the event
	# type only and them compare the result to the full string if more than one
	# result is returned. This is fine for the majority, and should prevent
	# incorrect matching for differing feed string event names as explained above.
	#
	# Remove the leading characters.
	set race_name [string map {{Clone Race of } {}} $race_name]

	# Get the race number half of the string race_name. (This deals with any
	# potential trailing characters after the race number).
	if {![regexp { Race \d+.*} $race_name race_num_half]} {
		set msg "Invalid race_name - should be Clone Race of -type_name- Race\
				-race_number-"
		return [list 0 $msg]
	}

	# Get the race number.
	if {![regexp { Race \d+} $race_num_half race_num_match]} {
		set msg "Invalid race_name - should be Clone Race of -type_name- Race\
				-race_number-"
		return [list 0 $msg]
	}

	# Our match is of the format "Race + <race_number>"
	set race_number [lindex $race_num_match 1]

	# Now we have the race number, we can remove the race number half from the
	# race_name string to give us the full ev_type_name.
	set ev_type_full_name [string trimright $race_name $race_num_half]

	# Remove any erroneous leading or trailing spaces.
	set ev_type_full_name [string trim $ev_type_full_name { }]

	# As explained above we use just the first word of the ev type name to do a
	# wildcard search.
	set ev_type_first_name [lindex $ev_type_full_name 0]

	return [list 1 $ev_type_first_name $ev_type_full_name $race_number]
}
