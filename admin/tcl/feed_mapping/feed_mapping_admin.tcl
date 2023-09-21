# ==============================================================
# $Id: feed_mapping_admin.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
#  This file handles the Opta integration.
#  This is mainly concerned with the manual mapping of matches
#


namespace eval ADMIN::FEED_MAPPING {

	asSetAct ADMIN::FEED_MAPPING::DoOpta              [namespace code do_opta]
	asSetAct ADMIN::FEED_MAPPING::GoOpta              [namespace code go_opta]
	asSetAct ADMIN::FEED_MAPPING::DoOptaRemoveMap     [namespace code do_opta_remove_map]
	asSetAct ADMIN::FEED_MAPPING::GoDD                [namespace code go_dd]
	asSetAct ADMIN::FEED_MAPPING::DoOptaConfirmMap    [namespace code do_opta_confim_mapping]
	asSetAct ADMIN::FEED_MAPPING::DoLequipeConfirmMap [namespace code do_lequipe_confim_mapping]


	asSetAct ADMIN::FEED_MAPPING::DoLequipe          [namespace code do_lequipe]
	asSetAct ADMIN::FEED_MAPPING::GoLequipe          [namespace code go_lequipe]
	asSetAct ADMIN::FEED_MAPPING::DoLequipeRemoveMap [namespace code do_lequipe_remove_map]

	asSetAct ADMIN::FEED_MAPPING::GoCompetitionList  [namespace code go_competition_list]
	asSetAct ADMIN::FEED_MAPPING::GoCompetition      [namespace code go_competition]
	asSetAct ADMIN::FEED_MAPPING::DoCompetition      [namespace code do_competition]

}


proc ADMIN::FEED_MAPPING::_init args {

}

proc ADMIN::FEED_MAPPING::do_opta args {

	set SubmitName [reqGetArg SubmitName]
	if {$SubmitName == "map_event"} {
		ADMIN::FEED_MAPPING::do_event_map "OPTA"
		return
	}
	ADMIN::FEED_MAPPING::go_feed "OPTA"
}

proc ADMIN::FEED_MAPPING::do_lequipe args {

	set SubmitName [reqGetArg SubmitName]
	if {$SubmitName == "map_event"} {
		ADMIN::FEED_MAPPING::do_event_map "LEQUIPE"
		return
	}
	ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
}


proc ADMIN::FEED_MAPPING::go_opta args {
	ADMIN::FEED_MAPPING::go_feed "OPTA"
}

proc ADMIN::FEED_MAPPING::go_lequipe args {
	ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
}


#
# Get and display the events stored in the Opta tables
#
proc ADMIN::FEED_MAPPING::go_feed {feed_provider} {

	global FEED SPORT DATE

	catch {unset FEED}
	catch {unset SPORT}
	catch {unset DATE}

	# n - Not matched
	# p - pending
	# g - matched

	set sport_id_n [reqGetArg sports_filter_n]
	set sport_id_p [reqGetArg sports_filter_p]
	set sport_id_g [reqGetArg sports_filter_g]
	set date_n     [reqGetArg date_filter_n]
	set date_p     [reqGetArg date_filter_p]
	set date_g     [reqGetArg date_filter_g]

	set sport_id_n [expr {$sport_id_n == "" ? "--" : $sport_id_n}]
	set sport_id_p [expr {$sport_id_p == "" ? "--" : $sport_id_p}]
	set sport_id_g [expr {$sport_id_g == "" ? "--" : $sport_id_g}]

	set dflt_date "A"
	if {[OT_CfgGet FEED_EV_MATCHING_DATE_RANGE "-1"] != -1} {
		set dflt_date "C"
	}
	set date_n [expr {$date_n == "" ? $dflt_date : $date_n}]
	set date_p [expr {$date_p == "" ? $dflt_date : $date_p}]
	set date_g [expr {$date_g == "" ? $dflt_date : $date_g}]

	tpBindString CommEvSport_N $sport_id_n
	tpBindString CommEvSport_P $sport_id_p
	tpBindString CommEvSport_G $sport_id_g

	tpBindString StartTime_N $date_n
	tpBindString StartTime_P $date_p
	tpBindString StartTime_G $date_g

	set show_pending_events [OT_CfgGet FUNC_${feed_provider}_SHOW_PENDING_EVENTS 1]

	set FEED(disable_dd_evs) [list]

	ob_log::write INFO {ADMIN::FEED_MAPPING::go_feed - Binding Unmached Events}
	set num_unmatched [_bind_events $feed_provider "N" $sport_id_n $date_n]

	ob_log::write_array INFO FEED

	if {[lindex $num_unmatched 0] == -1} {
		set msg [lindex $num_unmatched 1]
		err_bind $msg
		ob_log::write ERROR {$msg}
	} elseif {$show_pending_events} {
		ob_log::write INFO {ADMIN::FEED_MAPPING::go_feed - Binding Pending Events}
		set num_pending [_bind_events $feed_provider "P" $sport_id_p $date_p $num_unmatched]
	} else {
		set num_pending 0
	}

	if {[lindex $num_pending 0] == -1} {
		set msg [lindex $num_pending 1]
		err_bind $msg
		ob_log::write ERROR {$msg}
	} else {
		ob_log::write INFO {ADMIN::FEED_MAPPING::go_feed - Binding Matched Events}
		set num_matched [_bind_events $feed_provider "G" $sport_id_g $date_g [expr $num_pending + $num_unmatched]]
	}

	if {[lindex $num_matched 0] == -1} {
		set msg [lindex $num_matched 1]
		err_bind $msg
		ob_log::write ERROR {$msg}
	}

	tpSetVar   SHOW_PENDING_EVENTS    $show_pending_events
	tpSetVar   FEED_NUM_UNMATCHED     $num_unmatched
	tpSetVar   FEED_NUM_MATCHED       $num_matched
	tpSetVar   FEED_NUM_PENDING       $num_pending
	tpSetVar   FEED_NUM_UN_AND_PEND   [expr $num_unmatched + $num_pending]
	tpSetVar   FEED_NUM_TOTAL         [expr $num_unmatched + $num_matched + $num_pending]

	tpBindVar  FEED_COMM_EV_NAME       FEED comm_ev_name   feed_idx

	tpBindVar  FEED_MATCH_ID           FEED comm_ev_id   feed_idx
	tpBindVar  FEED_MATCH_HAS_STARTED  FEED has_started  feed_idx

	tpBindVar  FEED_MATCH_TYPE_ID      FEED ev_type_id   feed_idx
	tpBindVar  FEED_MATCH_EV_ID        FEED ev_id        feed_idx
	tpBindVar  FEED_MATCH_EV_DESC      FEED ev_desc      feed_idx

	tpBindString FEED_DISABLE_DD_EVS   [join $FEED(disable_dd_evs) |]
	tpBindString FEED_PROVIDER         $feed_provider

	# Bind Sports
	_bind_sports $feed_provider

	if {$feed_provider == "OPTA"} {
		tpBindString Provider "Opta"
		tpBindString ProviderTitle "OPTA"
	} elseif {$feed_provider == "LEQUIPE"} {
		tpBindString Provider "Lequipe"
		tpBindString ProviderTitle "L'Equipe.fr"
	}

	asPlayFile -nocache feed_mapping/feed_mapping.html

}

#
# Calls proc to map an Opta match to an OB event
#
proc ADMIN::FEED_MAPPING::do_event_map {provider} {

	if {$provider == "OPTA"} {
		if {![op_allowed AllowOptaMapping 0]} {
			ob_log::write INFO "Failed Opta permisions"
			err_bind "You don't have permission to update Opta event matching"
			return 0
		}
	} elseif {$provider == "LEQUIPE"} {
		if {![op_allowed AllowLequipeMapping 0]} {
			ob_log::write INFO "Failed L'equipe.fr permisions"
			err_bind "You don't have permission to update L'equipe.fr event matching"
			return 0
		}
	}

	set match_id [reqGetArg match_id]
	set event_id [reqGetArg event_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_event_map - Matching tCommEv.comm_ev_id=$match_id to tEv.event_id=$event_id}
	set res [_map_event $match_id $event_id]

	if {[lindex $res 0] == 0} {
		set msg [lindex $res 1]
		err_bind $msg
		ob_log::write ERROR {do_event_map:$msg}
		ADMIN::FEED_MAPPING::go_feed $provider
		return
	}
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_event_map - Match Complete}
	ADMIN::FEED_MAPPING::go_feed $provider
}

#
# Calls the Admin screen to select the event to match the event with
#
proc ADMIN::FEED_MAPPING::go_dd args {

	set provider [reqGetArg feed_prov]

	ob_log::write INFO {ADMIN::FEED_MAPPING::go_dd - Checking permisions - provider=$provider}

	if {$provider == "OPTA"} {
		if {![op_allowed AllowOptaMapping 0]} {
			ob_log::write INFO "Failed Opta permisions"
			err_bind "You don't have permission to update Opta event matching"
			ADMIN::FEED_MAPPING::go_feed $provider
			return
		}
	} elseif {$provider == "LEQUIPE"} {
		if {![op_allowed AllowLequipeMapping 0]} {
			ob_log::write INFO "Failed L'equipe.fr permisions"
			err_bind "You don't have permission to update L'equipe.fr event matching"
			ADMIN::FEED_MAPPING::go_feed $provider
			return
		}
	}

	set type_id [reqGetArg type_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::go_dd - Starting event drill down to find match}
	reqSetArg selectable_levels "EVENT"
	if {$type_id != ""} {
		reqSetArg path "TYPE,$type_id"
	}

	reqSetArg blurb "Please select the corresponding openbet event"
	ADMIN::POPUP_DD::go_dd
}

#
# Calls proc to remove a mapping from an Opta match to an OB event
#
proc ADMIN::FEED_MAPPING::do_opta_remove_map args {

	if {![op_allowed AllowOptaMapping 0]} {
		ob_log::write INFO "Failed Opta permisions"
		err_bind "You don't have permission to update Opta event matching"
		ADMIN::FEED_MAPPING::go_feed "OPTA"
		return 0
	}

	set match_id [reqGetArg match_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_opta_remove_map - Removing Mapping on comm_ev_id=$match_id}
	set res [_remove_map $match_id]

	if {[lindex $res 0] == 0} {
		set msg [lindex $res 1]
		err_bind $msg
		ob_log::write ERROR {do_opta_remove_map:$msg}
		ADMIN::FEED_MAPPING::go_feed "OPTA"
		return
	}
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_opta_remove_map - Mapping Removed}
	ADMIN::FEED_MAPPING::go_feed "OPTA"
}

#
# Calls a local proc to change an Opta event match from pending to good
#
proc ADMIN::FEED_MAPPING::do_opta_confim_mapping args {

	if {![op_allowed AllowOptaMapping 0]} {
		ob_log::write INFO "Failed Opta permisions"
		err_bind "You don't have permission to update Opta event matching"
		ADMIN::FEED_MAPPING::go_feed "OPTA"
		return 0
	}

	set comm_ev_id [reqGetArg match_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_opta_confim_mapping - confirming mapping on comm_ev_id=$comm_ev_id}
	set ret [_do_confirm_mapping $comm_ev_id]

	if {[lindex $ret 0] == 0} {
		set msg [lindex $ret 1]
		err_bind $msg
		ob_log::write ERROR {$msg}
	}
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_opta_confim_mapping - Mapping comfirmed}
	ADMIN::FEED_MAPPING::go_feed "OPTA"
}

#
# Calls proc to remove a mapping from an L'equipe.fr match to an OB event
#
proc ADMIN::FEED_MAPPING::do_lequipe_remove_map args {

	if {![op_allowed AllowLequipeMapping 0]} {
		ob_log::write INFO "Failed L'equipe.fr permisions"
		err_bind "You don't have permission to update L'equipe.fr event matching"
		ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
		return 0
	}

	set match_id [reqGetArg match_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_lequipe_remove_map - Removing Mapping on comm_ev_id=$match_id}
	set res [_remove_map $match_id]

	if {[lindex $res 0] == 0} {
		set msg [lindex $res 1]
		err_bind $msg
		ob_log::write ERROR {do_opta_remove_map:$msg}
		ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
		return
	}
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_lequipe_remove_map - Mapping Removed}
	ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
}

#
# Calls a local proc to change an L'equipe.fr event match from pending to good
#
proc ADMIN::FEED_MAPPING::do_lequipe_confim_mapping args {

	if {![op_allowed AllowLequipeMapping 0]} {
		ob_log::write INFO "Failed L'equipe.fr permisions"
		err_bind "You don't have permission to update L'equipe.fr event matching"
		ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
		return 0
	}

	set comm_ev_id [reqGetArg match_id]
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_lequipe_confim_mapping - confirming mapping on comm_ev_id=$comm_ev_id}
	set ret [_do_confirm_mapping $comm_ev_id]

	if {[lindex $ret 0] == 0} {
		set msg [lindex $ret 1]
		err_bind $msg
		ob_log::write ERROR {$msg}
	}
	ob_log::write INFO {ADMIN::FEED_MAPPING::do_lequipe_confim_mapping - Mapping comfirmed}
	ADMIN::FEED_MAPPING::go_feed "LEQUIPE"
}

#
#
#
proc ADMIN::FEED_MAPPING::go_competition_list {} {

	global DB

	set feed_provider [reqGetArg FeedProvider]
	tpBindString FeedProvider $feed_provider

	set sql {
		select
			cs.name as sport_name,
			cc.comp_id,
			cc.ext_comp_id,
			cc.ext_comp_code,
			cc.ev_type_id,
			cc.name,
			cc.desc,
			t.ev_type_id,
			t.name as t_name,
			c.ev_class_id,
			c.name as c_name
		from
			tCommCompetition cc,
			tCommProvider    cp,
			tCommSport       cs,
			outer (tEvType   t, tEvClass c)

		where
			cp.comm_prov_name = ? and
			cp.comm_prov_id   = cc.comm_prov_id and
			cc.comm_sport     = cs.comm_sport and
			cc.ev_type_id     = t.ev_type_id and
			t.ev_class_id     = c.ev_class_id
		order by
			cc.comm_sport,
			cc.comp_id,
			cc.ext_comp_id,
			cc.ext_comp_code

	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $feed_provider]
	inf_close_stmt $stmt

	tpSetVar NumComps [db_get_nrows $rs]

	tpBindTcl CompId      sb_res_data $rs comp_idx comp_id
	tpBindTcl SportName   sb_res_data $rs comp_idx sport_name
	tpBindTcl ExtCompId   sb_res_data $rs comp_idx ext_comp_id
	tpBindTcl ExtCompCode sb_res_data $rs comp_idx ext_comp_code
	tpBindTcl TypeId      sb_res_data $rs comp_idx ev_type_id
	tpBindTcl CompName    sb_res_data $rs comp_idx name
	tpBindTcl CompDesc    sb_res_data $rs comp_idx desc
	tpBindTcl TypeId      sb_res_data $rs comp_idx ev_type_id
	tpBindTcl TypeName    sb_res_data $rs comp_idx t_name
	tpBindTcl ClassId     sb_res_data $rs comp_idx ev_class_id
	tpBindTcl ClassName   sb_res_data $rs comp_idx c_name

	asPlayFile feed_mapping/comp_list.html

	db_close $rs

}

#
#
#
proc ADMIN::FEED_MAPPING::go_competition args {

	global DB SPORT
	catch {unset SPORT}

	set act           [reqGetArg SubmitName]
	set comp_id       [reqGetArg CompId]
	set feed_provider [reqGetArg FeedProvider]
	set comp_sport    ""

	if {$act == "Back"} {
		ADMIN::FEED_MAPPING::go_feed $feed_provider
		return
	}

	foreach {n v} $args {
		set $n $v
	}

	# Bind Sports
	_bind_sports $feed_provider

	if {$comp_id == ""} {

		tpSetVar opAdd 1

		tpBindString CompSport  ""
		tpBindString CompTypeId ""

	} else {

		tpSetVar opAdd 0

		# Get comp info
		set sql {
			select
				comm_sport,
				ext_comp_id,
				ext_comp_code,
				ev_type_id,
				name,
				desc
			from
				tCommCompetition c
			where
				comp_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $comp_id]
		inf_close_stmt $stmt

		tpBindString CompSport   [db_get_col $rs 0 comm_sport]
		tpBindString ExtCompId   [db_get_col $rs 0 ext_comp_id]
		tpBindString ExtCompCode [db_get_col $rs 0 ext_comp_code]
		tpBindString CompTypeId  [db_get_col $rs 0 ev_type_id]
		tpBindString CompName    [db_get_col $rs 0 name]
		tpBindString CompDesc    [db_get_col $rs 0 desc]

		set comp_sport [db_get_col $rs 0 comm_sport]

		db_close $rs
	}

	# Get type information
	set qry_param ""
	for {set i 0} {$i < $SPORT(nrows)} {incr i} {
		if {$comp_sport == $SPORT($i,comm_sport)} {
			tpBindString CompSportName $SPORT($i,name)
			if {$SPORT($i,ob_level) == "CLS"} {
				set qry_param ", tEvClass c
					         where
					            c.ev_class_id     = t.ev_class_id
					            and c.ev_class_id = $SPORT($i,ob_id)"
				break;
			} elseif {$SPORT($i,ob_level) == "CAT"} {
				set qry_param ", tEvClass c, tEvCategory cat
					         where
					            c.ev_class_id          = t.ev_class_id
					            and c.category         = cat.category
					            and cat.ev_category_id = $SPORT($i,ob_id)"
				break;
			}
		}
	}

	set sql [subst {
		select
			t.ev_type_id,
			t.name
		from
			tEvType    t
		$qry_param
		order by
			t.name
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set rs_type [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTypes [db_get_nrows $rs_type]

	tpBindTcl TypeId   sb_res_data $rs_type type_idx ev_type_id
	tpBindTcl TypeName sb_res_data $rs_type type_idx name

	tpBindString CompId       $comp_id
	tpBindString FeedProvider $feed_provider

	asPlayFile feed_mapping/competition.html

	db_close $rs_type
}

#
# Add/Update/Delete Competition
#
proc ADMIN::FEED_MAPPING::do_competition {} {

	set act [reqGetArg SubmitName]

	if {$act == "CompAdd"} {
		ADMIN::FEED_MAPPING::_do_comp_add
	} elseif {$act == "CompMod"} {
		ADMIN::FEED_MAPPING::_do_comp_upd
	} elseif {$act == "CompDel"} {
		ADMIN::FEED_MAPPING::_do_comp_del
	} elseif {$act == "Back"} {
		ADMIN::FEED_MAPPING::go_competition_list
	} else {
		error "unexpected SubmitName: $act"
	}
}



#
# Gets and binds all Feed events and where applicable OB event data
#
proc ADMIN::FEED_MAPPING::_bind_events {provider status {sport_id "--"} {date "A"} {existing_entries 0}} {

	global DB FEED

	ob_log::write INFO {_bind_events - provider=$provider, status=$status, sport_id=$sport_id, date=$date, existing_entries=$existing_entries}

	set select ""
	set where  ""

	if {$status == "N"} {
		set select ", case when ce.start_time <= current then 'Y' else 'N' end as has_started \
			    , ce.start_time as start_time"

		if {[lsearch {A C} $date] == -1} {
			append where " and ce.start_time between '$date 00:00:00' and '$date 23:59:59'"
		} elseif {$date == "C"} {
			append where " and ce.start_time >= EXTEND(CURRENT, year to day) - [OT_CfgGet FEED_EV_MATCHING_DATE_RANGE] units day"
		}

	} elseif {$status == "P" || $status == "G"} {
		set select ", (pCheckEvStarted(e.start_time,e.suspend_at,e.is_off)) as has_started \
			    , DECODE(ce.start_time,null,e.start_time)               as start_time"

		if {[lsearch {A C} $date] == -1} {
			append where " and e.start_time between '$date 00:00:00' and '$date 23:59:59'"
		} elseif {$date == "C"} {
			append where " and e.start_time >= EXTEND(CURRENT, year to day) - [OT_CfgGet FEED_EV_MATCHING_DATE_RANGE] units day"
		}
	}

	if {$sport_id != "--"} {
		append where " and cs.comm_sport = '$sport_id'"
	}


	if {$status == "N"} {

		set sql [subst {
			select
				ce.comm_ev_id,
				cc.name                as comp_name,
				cc.ext_comp_code       as ext_comp_code,
				NVL(cc.ev_type_id, '') as ev_type_id,
				ce.comm_sport,
				cs.name                as sport_name,
				ce.venue,
				cth.name               as home_team,
				cta.name               as away_team,
				ce.desc                as comm_ev_desc,
				''      as ev_id,
				''      as ev_desc
				$select
			from
				tCommEv          ce,
				tCommProvider    cp,
				tCommSport       cs,
				tCommCompetition cc,
				outer (tCommEvTeam ceth, tCommEvTeam ceta, tCommTeam cth, tCommTeam cta)

			where
				cc.comp_id             = ce.comp_id
				and ce.matching_status = ?
				and ce.comm_ev_id      = ceth.comm_ev_id
				and ce.comm_ev_id      = ceta.comm_ev_id
				and ceth.team_type     = 'HOME'
				and ceta.team_type     = 'AWAY'
				and cth.comm_team_id   = ceth.comm_team_id
				and cta.comm_team_id   = ceta.comm_team_id
				and ce.comm_prov_id    = cp.comm_prov_id
				and cp.comm_prov_name  = ?
				and ce.comm_sport      = cs.comm_sport
				$where
			order by
				start_time
		}]

	} else {

		set sql [subst {
			select
				ce.comm_ev_id,
				cc.name                as comp_name,
				cc.ext_comp_code       as ext_comp_code,
				NVL(cc.ev_type_id, '') as ev_type_id,
				ce.comm_sport,
				cs.name                as sport_name,
				ce.venue,
				cth.name               as home_team,
				cta.name               as away_team,
				ce.desc                as comm_ev_desc,
				NVL(ce.ev_id, '')      as ev_id,
				NVL(e.desc, '')        as ev_desc
				$select
			from
				tCommEv          ce,
				tCommProvider    cp,
				tCommSport       cs,
				tCommCompetition cc,
				outer (tCommEvTeam ceth, tCommEvTeam ceta, tCommTeam cth, tCommTeam cta),
				tEv        e
			where
				cc.comp_id             = ce.comp_id
				and ce.matching_status = ?
				and ce.comm_ev_id      = ceth.comm_ev_id
				and ce.comm_ev_id      = ceta.comm_ev_id
				and e.ev_id            = ce.ev_id
				and e.settled          = 'N'
				and ceth.team_type     = 'HOME'
				and ceta.team_type     = 'AWAY'
				and cth.comm_team_id   = ceth.comm_team_id
				and cta.comm_team_id   = ceta.comm_team_id
				and ce.comm_prov_id    = cp.comm_prov_id
				and cp.comm_prov_name  = ?
				and ce.comm_sport      = cs.comm_sport
				$where
			order by
				start_time
		}]
	}

	ob_log::write DEBUG {$sql}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		set rs [inf_exec_stmt $stmt $status $provider]
	} msg]} {
		ob_log::write ERROR {ADMIN::FEED_MAPPING::_bind_events: couldn't retrieve the event list : $msg}
		inf_close_stmt $stmt
		return [list -1 "$msg"]
	}

	inf_close_stmt $stmt

	if {[set n_rows [db_get_nrows $rs]] <= 0} {
		ob_log::write ERROR {ADMIN::FEED_MAPPING::_bind_events: Found $n_rows rows.}
		db_close $rs
		return $n_rows
	}


	ob_log::write INFO {ADMIN::FEED_MAPPING::_bind_events - Adding events, n_rows=$n_rows}
	set arr_pos $existing_entries
	set match_dates [list]

	for {set i 0} {$i < $n_rows} {incr i} {
		foreach colName [db_get_colnames $rs] {
			if {$colName == "ev_desc"} {
				set FEED($arr_pos,$colName) [string map { "|" "" } [db_get_col $rs $i $colName]]
			} else {
				set FEED($arr_pos,$colName) [db_get_col $rs $i $colName]
			}
		}

		# Set comm ev description
		set FEED($arr_pos,comm_ev_name) $FEED($arr_pos,sport_name)
		if {$FEED($arr_pos,comp_name) != ""} {
			append FEED($arr_pos,comm_ev_name) " - $FEED($arr_pos,comp_name)"
		} else {
			append FEED($arr_pos,comm_ev_name) " - $FEED($arr_pos,ext_comp_code)"
		}
		if {$FEED($arr_pos,comm_ev_desc) != ""} {
			append FEED($arr_pos,comm_ev_name) " - $FEED($arr_pos,comm_ev_desc)"
		} elseif {$FEED($arr_pos,home_team) != "" && $FEED($arr_pos,away_team) != ""} {
			append FEED($arr_pos,comm_ev_name) " - $FEED($arr_pos,home_team) vs $FEED($arr_pos,away_team)"
		}

		if {$FEED($arr_pos,start_time) != ""} {
			append FEED($arr_pos,comm_ev_name) " on $FEED($arr_pos,start_time)"
		}

		if {$FEED($arr_pos,venue) != ""} {
			append FEED($arr_pos,comm_ev_name) " at $FEED($arr_pos,venue)"
		}

		# If this is matched then we will want to ensure it is not selectable in
		#  the drill down again. (but only if it is a good match, ie not pending)
		if {$status == "G"} {
			lappend FEED(disable_dd_evs) $FEED(${arr_pos},ev_id)
		}

		if {$FEED($arr_pos,start_time) != "" && [lsearch $match_dates $FEED($arr_pos,start_time)] < 0} {
			lappend match_dates $FEED($arr_pos,start_time)
		}
		incr arr_pos
	}

	db_close $rs

	# Bind Dates
	_bind_dates $provider $status $match_dates

	return $n_rows

}


#
# Bind up the sport drop downs
#
proc ADMIN::FEED_MAPPING::_bind_sports {feed_provider} {

	global DB SPORT

	# Get sport information
	set sql {
		select
			comm_sport,
			name,
			ob_id,
			ob_level
		from
			tCommSport
	}

	set stmt     [inf_prep_sql $DB $sql]
	set rs_sport [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set SPORT(nrows) [db_get_nrows $rs_sport]

	for {set i 0} {$i < $SPORT(nrows)} {incr i} {

		foreach coln [db_get_colnames $rs_sport] {
			set SPORT($i,$coln) [db_get_col $rs_sport $i $coln]
		}

	}

	db_close $rs_sport

	tpSetVar NumSports $SPORT(nrows)

	tpBindVar Sport     SPORT comm_sport sport_idx
	tpBindVar SportName SPORT name       sport_idx

}


#
# Bind up the date drop downs
#
proc ADMIN::FEED_MAPPING::_bind_dates {feed_provider status dates} {

	global DB DATE

	set where ""

	if {$status == "N"} {

		if {[llength $dates] > 0} {
			set where "and start_time in ('[join [lsort -unique $dates] ',']')"
		}

		# Get dates
		set sql [subst {
			select distinct
				EXTEND(start_time, year to day) as match_date
			from
				tCommEv,
				tCommProvider
			where
				matching_status              = 'N'
				and tCommEv.comm_prov_id     = tCommProvider.comm_prov_id
				and tCommProvider.comm_prov_name = '${feed_provider}'
			order by
				1 desc
		}]

	} else {

		if {[llength $dates] > 0} {
			set where "and e.start_time in ('[join [lsort -unique $dates] ',']')"
		}

		# Get dates
		set sql [subst {
			select distinct
				EXTEND(e.start_time, year to day) as match_date
			from
				tCommEv   ce,
				tEv       e,
				tCommProvider cp
			where
				ce.matching_status    = '${status}'
				and ce.ev_id          = e.ev_id
				and ce.comm_prov_id   = cp.comm_prov_id
				and cp.comm_prov_name = '${feed_provider}'
				$where
			order by
				1 desc
		}]
	}

	set stmt    [inf_prep_sql $DB $sql]
	set rs_date [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs_date]

	set date_c 0
	for {set i 0} {$i < $nrows} {incr i} {
		if {[db_get_col $rs_date $i match_date] != ""} {
			set DATE($status,$date_c,date) [lindex [split [db_get_col $rs_date $i match_date] " "] 0]
			incr date_c
		}
	}

	db_close $rs_date

	ob_log::write_array INFO DATE

	tpSetVar NumDates_${status} $date_c

	tpBindVar Date DATE date status_idx date_idx

}

#
# Map a feed to an OpenBet event
# Return 1 if success or 0 with a message if there is an error
#
proc ADMIN::FEED_MAPPING::_map_event {comm_ev_id event_id} {
    global DB

	set stmt [inf_prep_sql $DB {
		update tCommEv
		set ev_id = ?, matching_status = 'G'
		where comm_ev_id = ?
	}]

	if {[catch {set rs [inf_exec_stmt $stmt $event_id $comm_ev_id]} msg]} {
		OT_LogWrite ERROR "opta: couldn't update comm_ev_id $comm_ev_id : $msg"
		inf_close_stmt $stmt
		return [list 0 "$msg"]
	}

	inf_close_stmt $stmt
	db_close $rs

	return 1
}

#
# Removes a mapped feed to an OpenBet event
# Return 1 if success or 0 with a message if there is an error
#
proc ADMIN::FEED_MAPPING::_remove_map {comm_ev_id} {
	global DB

	set stmt [inf_prep_sql $DB {
        	update tCommEv
		set
			ev_id = null,
			matching_status = 'N'
		where
			comm_ev_id = ?
	}]

	if {[catch {set rs [inf_exec_stmt $stmt $comm_ev_id]} msg]} {
        	OT_LogWrite ERROR "opta: couldn't remove mapping from comm_ev_id $comm_ev_id : $msg"
        	inf_close_stmt $stmt
		return [list 0 "$msg"]
	}

	inf_close_stmt $stmt
	db_close $rs
	return 1
}

#
# Confirms a mapped feed to an OpenBet event
# Return 1 if success or 0 with a message if there is an error
#
proc ADMIN::FEED_MAPPING::_do_confirm_mapping {comm_ev_id} {
	global DB

	set stmt [inf_prep_sql $DB {
		update tCommEv
		set matching_status = 'G'
		where comm_ev_id = ?
	}]

	if {[catch {set rs [inf_exec_stmt $stmt $comm_ev_id]} msg]} {
		OT_LogWrite ERROR "opta: couldn't confirm mapping from comm_ev_id $comm_ev_id : $msg"
		inf_close_stmt $stmt
		return [list 0 "$msg"]
	}

	inf_close_stmt $stmt
	db_close $rs

	return 1
}

#
#
#
proc ADMIN::FEED_MAPPING::_do_comp_upd {} {

	global DB

	set feed_provider [reqGetArg FeedProvider]
	tpBindString FeedProvider $feed_provider

	if {$feed_provider == "OPTA" && ![op_allowed AllowOptaMapping 0]} {
		err_bind "You don't have permission to update Opta competition"
		ADMIN::FEED_MAPPING::go_competition
		return
	}
	if {$feed_provider == "LEQUIPE" && ![op_allowed AllowLequipeMapping 0]} {
		err_bind "You don't have permission to update L'equipe.fr competition"
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	set sql {
		update
			tCommCompetition
		set
			ev_type_id    = ?,
		        name          = ?,
		        desc          = ?
		where
			comp_id       = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg EvType]\
			[reqGetArg CompName]\
			[reqGetArg CompDesc]\
			[reqGetArg CompId]]

		inf_close_stmt $stmt
		db_close $res

	} msg]} {
		# Something went wrong
		err_bind $msg
		inf_close_stmt $stmt
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	msg_bind "Competition Updated"

	ADMIN::FEED_MAPPING::go_competition
}

#
#
#
proc ADMIN::FEED_MAPPING::_do_comp_add {} {

	global DB

	set feed_provider [reqGetArg FeedProvider]
	tpBindString FeedProvider $feed_provider

	# check permissions
	if {$feed_provider == "OPTA" && ![op_allowed AllowOptaMapping 0]} {
		err_bind "You don't have permission to add Opta competition"
		ADMIN::FEED_MAPPING::go_competition_list
		return
	}
	if {$feed_provider == "LEQUIPE" && ![op_allowed AllowLequipeMapping 0]} {
		err_bind "You don't have permission to add L'equipe.fr competition"
		ADMIN::FEED_MAPPING::go_competition_list
		return
	}

	# check some values
	set ext_comp_id   [reqGetArg ExtCompId]
	set ext_comp_code [reqGetArg ExtCompCode]

	if {$ext_comp_id eq "" && $ext_comp_code eq ""} {
		err_bind "External Id and External Code values are empty. Please provide either External Id or External Code."
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	set sql {
		select
			comm_prov_id
		from
			tCommProvider
		where
			comm_prov_name = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $feed_provider]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		db_close $res
		err_bind "Failed to add new competition"
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	set comm_prov_id [db_get_coln $res 0 0]
	db_close $res

	set sql [subst {
		execute procedure pInsCommCompetition(
			p_comm_prov_id = ?,
			p_comm_sport = ?,
			p_ext_comp_id = ?,
			p_ext_comp_code = ?,
			p_ev_type_id = ?,
			p_name = ?,
			p_desc = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	# attempt to insert new competition
	if {[catch {

		set res [inf_exec_stmt $stmt\
			$comm_prov_id\
			[reqGetArg Sport]\
			[reqGetArg ExtCompId]\
			[reqGetArg ExtCompCode]\
			[reqGetArg EvType]\
			[reqGetArg CompName]\
			[reqGetArg CompDesc]]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add new competition"
			db_close $res
			ADMIN::FEED_MAPPING::go_competition
			return
		}

		set comp_id [db_get_coln $res 0 0]
		db_close $res

	} msg]} {
		# Something went wrong
		inf_close_stmt $stmt
		err_bind $msg
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	msg_bind "Competition Added"
	ADMIN::FEED_MAPPING::go_competition comp_id $comp_id feed_provider $feed_provider
}

#
#
#
proc ADMIN::FEED_MAPPING::_do_comp_del {} {

	global DB

	set feed_provider [reqGetArg FeedProvider]
	tpBindString FeedProvider $feed_provider

	if {$feed_provider == "OPTA" && ![op_allowed AllowOptaMapping 0]} {
		err_bind "You don't have permission to delete Opta competition"
		ADMIN::FEED_MAPPING::go_competition_list
		return
	}
	if {$feed_provider == "LEQUIPE" && ![op_allowed AllowLequipeMapping 0]} {
		err_bind "You don't have permission to delete L'equipe.fr competition"
		ADMIN::FEED_MAPPING::go_competition_list
		return
	}

	set comp_id [reqGetArg CompId]

	set sql [subst {
		delete
		from tCommCompetition
		where comp_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt $comp_id]
	} msg]} {
		# Something went wrong
		inf_close_stmt $stmt
		err_bind $msg
		ADMIN::FEED_MAPPING::go_competition
		return
	}

	inf_close_stmt $stmt
	db_close $res

	msg_bind "Competition Deleted"
	ADMIN::FEED_MAPPING::go_competition_list
}
