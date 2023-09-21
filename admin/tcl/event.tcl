#
# $Id: event.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::EVENT {

asSetAct ADMIN::EVENT::GoEv            [namespace code go_ev]
asSetAct ADMIN::EVENT::DoEv            [namespace code do_ev]
asSetAct ADMIN::EVENT::DoEvsUpd        [namespace code do_evs_upd]
asSetAct ADMIN::EVENT::DoEvConf        [namespace code do_ev_conf]
asSetAct ADMIN::EVENT::GoCritEvConf    [namespace code go_crit_ev_conf]
asSetAct ADMIN::EVENT::GoShowEvResults [namespace code go_show_results]
asSetAct ADMIN::EVENT::UpdBIRDisplay   [namespace code upd_bir_display]

#
# ----------------------------------------------------------------------------
# Management of event tags...
# ----------------------------------------------------------------------------
#
proc make_ev_tag_binds {c_sort {str ""}} {
	global EVTAG

	set tag_list [ADMIN::MKTPROPS::class_flag $c_sort event-tags]
	set tag_used [split $str ,]

	set i 0

	foreach {t n} $tag_list {
		set EVTAG($i,code) $t
		set EVTAG($i,name) $n

		if {[lsearch -exact $tag_used $t] >= 0} {
			set EVTAG($i,selected) CHECKED
		} else {
			set EVTAG($i,selected) ""
		}
		incr i
	}

	tpSetVar NumEvTags $i

	ob_log::write_array ERROR EVTAG

	tpBindVar EvTagName EVTAG name     ev_tag_idx
	tpBindVar EvTagCode EVTAG code     ev_tag_idx
	tpBindVar EvTagSel  EVTAG selected ev_tag_idx
}

proc make_ev_tag_str {c_sort {prefix EVTAG_}} {
	global DB

	set res [list]

	foreach {t n} [ADMIN::MKTPROPS::class_flag $c_sort event-tags] {
		if {[reqGetArg ${prefix}$t] != ""} {
			lappend res $t
		}
	}

	if {[OT_CfgGet FUNC_TV_CHANNEL 0]} {
		set sql [subst {
			select
				tv_channel_id,
				channel_desc
			from
				tTVChannel
			order by channel_desc
		}]

		set stmt [inf_prep_sql $DB $sql]
		set tvres  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		for {set r 0} {$r < [db_get_nrows $tvres]} {incr r} {
			set tv_channel_id [db_get_col $tvres $r tv_channel_id]
			if {[reqGetArg CHANNELTAG_$tv_channel_id] != ""} {
				lappend res "T$tv_channel_id"
			}
		}

		db_close $tvres
	}

	return [join $res ,]
}


proc make_ev_sort_binds {c_sort {ev_sort ""}} {

	global EVSORT

	set sort_list [ADMIN::MKTPROPS::class_flag $c_sort event-sorts]

	set i 0

	foreach {s n} $sort_list {
		set EVSORT($i,code) $s
		set EVSORT($i,name) $n
		incr i
	}

	tpSetVar NumEvSorts $i

	tpBindVar EvSortName EVSORT name ev_sort_idx
	tpBindVar EvSortCode EVSORT code ev_sort_idx

	tpBindString EvSort $ev_sort
}


proc make_ev_tv_channel_binds {flags_str} {

	global EVTVCHAN
	global DB

	catch {unset EVTVCHAN}

	set sql [subst {
		select
			tv_channel_id,
			channel_desc
		from
			tTVChannel
		order by channel_desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set i 0
	set nrows [db_get_nrows $res]
	for {set r 0} {$r < $nrows} {incr r} {
		set tv_channel_id [db_get_col $res $r tv_channel_id]
		set channel_desc  [db_get_col $res $r channel_desc]

		set EVTVCHAN($i,tv_channel_id) $tv_channel_id
		set EVTVCHAN($i,channel_desc)  $channel_desc

		if {[regexp "(^|,)T${tv_channel_id}(,|$)" $flags_str]} {
			set EVTVCHAN($i,selected) {checked}
		} else {
			set EVTVCHAN($i,selected) ""
		}
		incr i
	}
	db_close $res

	tpSetVar NumEvTVChans $i

	tpBindVar EvTVChanId       EVTVCHAN tv_channel_id  ev_tvchan_idx
	tpBindVar EvTVChanDesc     EVTVCHAN channel_desc   ev_tvchan_idx
	tpBindVar EvTVChanSelected EVTVCHAN selected       ev_tvchan_idx
}


#
# ----------------------------------------------------------------------------
# Add a new event
# ----------------------------------------------------------------------------
#
proc go_ev args {

	global DB

	set ev_id [reqGetArg EvId]

	if {$ev_id == ""} {
		if {[reqGetArg SubmitName]=="EvAdd"} {
			go_ev_add
		} else {
			go_evs_upd
		}
	} else {
		go_ev_upd
	}
}


#
# ----------------------------------------------------------------------------
# Add a new event
# ----------------------------------------------------------------------------
#
proc go_ev_add args {

	global DB FB_CHART_MAP TRADERS

	set type_id [reqGetArg TypeId]

	if {[string index $type_id 0] == "C"} {

		tpSetVar NeedTypeToAddEv 1
		ADMIN::EV_SEL::go_ev_sel
		return
	}

	set sql [subst {
		select
			c.name cname,
			t.name tname,
			c.ev_class_id,
			c.sort,
			t.channels,
			t.flags
		from
			tEvClass c,
			tEvType  t
		where
			t.ev_type_id = $type_id and
			t.ev_class_id = c.ev_class_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set c_sort [db_get_col $res 0 sort]

	tpSetVar ClassSort $c_sort

	tpBindString TypeId    $type_id
	tpBindString ClassSort $c_sort
	tpBindString ClassName [db_get_col $res 0 cname]
	tpBindString TypeName  [db_get_col $res 0 tname]
	tpSetVar     ClassId   [db_get_col $res 0 ev_class_id]

	ADMIN::FBCHARTS::fb_read_chart_info

	tpSetVar NumDomains $FB_CHART_MAP(num_domains)

	tpBindVar DomainFlag FB_CHART_MAP flag domain_idx
	tpBindVar DomainName FB_CHART_MAP name domain_idx
	tpBindString MBS 0

	tpBindString EvDisplayed [OT_CfgGet DFLT_NEW_EVENT_DISPLAYED "N"]
	tpBindString EvStatus    [OT_CfgGet DFLT_NEW_EVENT_STATUS    "S"]

	tpSetVar opAdd 1

	make_channel_binds "" [db_get_col $res 0 channels] 1

	make_language_binds

	if {[OT_CfgGet FUNC_STATIONS 0]} {
		make_station_binds {} - 0
	}

	if {[OT_CfgGet FUNC_TYPE_FLAGS 0]} {
		make_ev_tag_binds  $c_sort [db_get_col $res 0 flags]
	} else {make_ev_tag_binds  $c_sort RN}
	make_ev_sort_binds $c_sort

	if {[OT_CfgGet FUNC_TV_CHANNELS 0]} {
		make_ev_tv_channel_binds ""
	}

	db_close $res

	set sql [subst {
		select
			NVL(t.ev_min_bet, b.min_bet) min_bet,
			NVL(t.ev_max_bet, b.max_bet) max_bet
		from
			tBetType b,
			tEvType  t
		where
			t.ev_type_id = $type_id and
			bet_type = 'SGL'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString MinBet    [db_get_col $res 0 min_bet]
	tpBindString MaxBet    [db_get_col $res 0 max_bet]

	## default allow settle is 'Y'
	tpSetVar EvAllowSettle "Y"

	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any dilldown items. Such as categories, classes types and
	# markets. and allow_dd_deletion is for deleting items
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	if {[op_allowed AssignTrader]} {
		bind_trader_data "Trader"
	}

	asPlayFile event.html

	catch {unset TRADERS}
}


#
# ----------------------------------------------------------------------------
# Event select activator
# ----------------------------------------------------------------------------
#
proc go_ev_upd args {

	global DB FB_CHART_MAP MKT USERNAME TRADERS BF_MTCH BFEVS BF_T

	tpSetVar opAdd 0

	set ev_id [reqGetArg EvId]

	foreach {n v} $args {
		set $n $v
	}

	set sql [subst {
		select
			c.name cname,
			c.sort csort,
			c.ev_class_id,
			t.name tname,
			t.ev_type_id,
			t.channels type_channels,
			e.desc,
			e.venue,
			e.country,
			e.sort,
			e.flags,
			e.status,
			e.displayed,
			e.disporder,
			e.start_time,
			e.est_start_time,
			e.suspend_at,
			e.late_bet_tol,
			e.late_bet_tol_op,
			e.off_time,
			e.is_off,
			e.close_time,
			e.settled,
			e.tax_rate,
			e.fb_dom_int,
			e.mult_key,
			e.min_bet,
			e.max_bet,
			e.sp_max_bet,
			e.feed_updateable,
			e.t_bet_cutoff,
			e.ext_key,
			e.url,
			e.shortcut,
			e.result_conf,
			e.settled,
			e.channels,
			e.fastkey,
			e.blurb,
			e.result,
			e.calendar,
			e.notes,
			e.allow_stl,
			e.max_pot_win,
			e.max_multiple_bet,
			e.ew_factor,
			e.has_bet_in_run,
			e.sp_allbets_from,
			e.sp_allbets_to,
			e.auto_traded,
			d.code as ev_code,
			NVL(NVL(e.max_multiple_bet, t.max_multiple_bet), 'n/a') f_max_multiple_bet,
			e.trader_user_id,
			e.req_guid,
			e.bir_delay,
			pGetHierarchyBIRDelayLevel ("EVENT", $ev_id) as bir_hierarchy,
			pGetHierarchyBIRDelay ("EVENT", $ev_id) as bir_hierarchy_value
		from
			tEvClass c,
			tEvType  t,
			tEv      e,
			outer tEvCode d
		where
			e.ev_id       = ?             and
			e.ev_type_id  = t.ev_type_id  and
			t.ev_class_id = c.ev_class_id and
			d.ev_id       = e.ev_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	set c_sort       [db_get_col $res 0 csort]
	set channel_mask [db_get_col $res 0 type_channels]
	set channels     [db_get_col $res 0 channels]
	set type_id      [db_get_col $res 0 ev_type_id]
	set result_conf  [db_get_col $res 0 result_conf]
	set settled      [db_get_col $res 0 settled]
	set status       [db_get_col $res 0 status]
	set start        [db_get_col $res 0 start_time]
	set est_start    [db_get_col $res 0 est_start_time]
	set calendar     [db_get_col $res 0 calendar]
	if {$calendar == "Y"} {
		tpBindString CALENDAR CHECKED
	}

	make_channel_binds $channels $channel_mask

	make_ev_tag_binds  $c_sort [db_get_col $res 0 flags]
	make_ev_sort_binds $c_sort [db_get_col $res 0 sort]

	if {[OT_CfgGet FUNC_TV_CHANNEL 0]} {
		make_ev_tv_channel_binds [db_get_col $res 0 flags]
	}

	set bir_delay     [db_get_col $res 0 bir_delay]
	set bir_hierarchy [db_get_col $res 0 bir_hierarchy]
	set class_id      [db_get_col $res 0 ev_class_id]

	tpBindString EvId                   $ev_id
	tpBindString ClassName              [db_get_col $res 0 cname]
	tpBindString ClassSort              $c_sort
	tpBindString TypeName               [db_get_col $res 0 tname]
	tpBindString ClassId                $class_id
	tpSetVar     ClassId                $class_id
	tpBindString TypeId                 $type_id
	tpBindString EvDesc                 [db_get_col $res 0 desc]
	tpBindString EvVenue                [db_get_col $res 0 venue]
	tpBindString EvCountry              [db_get_col $res 0 country]
	tpBindString EvMultKey              [db_get_col $res 0 mult_key]
	tpBindString EvExtKey               [db_get_col $res 0 ext_key]
	tpBindString EvShortcut             [db_get_col $res 0 shortcut]
	tpBindString EvDisporder            [db_get_col $res 0 disporder]
	tpBindString EvDisplayed            [db_get_col $res 0 displayed]
	tpBindString EvFeedUpdateable       [db_get_col $res 0 feed_updateable]
	tpBindString EvFBDomain             [db_get_col $res 0 fb_dom_int]
	tpBindString EvURL                  [db_get_col $res 0 url]
	tpBindString EvStartTime            $start
	tpBindString EvEstStartTime         $est_start
	tpBindString EvCloseTime            [db_get_col $res 0 close_time]
	tpBindString EvOfficialOff          [db_get_col $res 0 off_time]
	tpBindString EvIsOff                [db_get_col $res 0 is_off]
	tpBindString EvSuspendAt            [db_get_col $res 0 suspend_at]
	tpBindString EvSettleAtSPFrom       [db_get_col $res 0 sp_allbets_from]
	tpBindString EvSettleAtSPTo         [db_get_col $res 0 sp_allbets_to]
	tpBindString EvStatus               $status
	tpBindString EvTaxRate              [db_get_col $res 0 tax_rate]
	tpBindString EvMinBet               [db_get_col $res 0 min_bet]
	tpBindString EvMaxBet               [db_get_col $res 0 max_bet]
	tpBindString EvSpMaxBet             [db_get_col $res 0 sp_max_bet]
	tpBindString EvBetCutoff            [db_get_col $res 0 t_bet_cutoff]
	tpBindString EvFastkey              [db_get_col $res 0 fastkey]
	tpBindString EvBlurb                [db_get_col $res 0 blurb]
	tpBindString EvResult               [db_get_col $res 0 result]
	tpBindString EvNotes                [db_get_col $res 0 notes]
	tpBindString EvHasBIR               [db_get_col $res 0 has_bet_in_run]
	tpBindString EvNoMoreBetTime        [db_get_col $res 0 late_bet_tol]
	tpBindString EvNoMoreBetTimeOp      [db_get_col $res 0 late_bet_tol_op]
	tpBindString EvMaxMultipleBet       [db_get_col $res 0 max_multiple_bet]
	tpBindString FinalMaxMultipleBet    [db_get_col $res 0 f_max_multiple_bet]
	tpBindString EvTrader               [db_get_col $res 0 trader_user_id]
	tpBindString ReqGUID                [db_get_col $res 0 req_guid]
	tpBindString EvBirDelay             $bir_delay

	if {$bir_delay == "" && $bir_hierarchy != ""} {
			tpSetVar displayBIRHierarchy 1
			tpBindString BIRHierarchy     $bir_hierarchy
			tpBindString BIRHierarchyVal  [db_get_col $res 0 bir_hierarchy_value]
	}

	set ev_code [db_get_col $res 0 ev_code]
	if {$ev_code != ""} {
		tpBindString EvCode [format "%03d" $ev_code]
	}

	tpSetVar EvAllowSettle  [db_get_col $res 0 allow_stl]

	tpBindString EvEachWayFactor     [db_get_col $res 0 ew_factor]
	tpBindString EvMaxPotWin         [db_get_col $res 0 max_pot_win]
	tpBindString EvAutoTraded        [db_get_col $res 0 auto_traded]

	if {[OT_CfgGet FUNC_LAY_TO_LOSE_EV 0] == 1} {
		# if MMB, LMB and liability values exist for this event then bind up the strings
		set sql_evltl {
			select
			  l.least_max_bet,
			  l.most_max_bet,
			  l.liability,
			  l.lay_to_lose
			from
			  tLayToLoseEv l
			where
			  l.ev_id = ?
		}
		set stmt_evltl [inf_prep_sql $DB $sql_evltl]
		set res_evltl [inf_exec_stmt $stmt_evltl $ev_id]
		inf_close_stmt $stmt_evltl
		if {[db_get_nrows $res_evltl] == 1} {
			tpBindString LeastMaxBet  [db_get_col $res_evltl 0 least_max_bet]
			tpBindString MostMaxBet   [db_get_col $res_evltl 0 most_max_bet]
			tpBindString Liability    [db_get_col $res_evltl 0 liability]
			tpBindString LayToLose    [db_get_col $res_evltl 0 lay_to_lose]
			if {[db_get_col $res_evltl 0 most_max_bet] == ""} {
				tpSetVar EvMaxBetAvail 0
			} else {
				tpSetVar EvMaxBetAvail 1
			}
		} else {
			tpSetVar EvMaxBetAvail 0
		}

		db_close $res_evltl

		# if laytolose values exist for this event type then bind up the EvMaxLayToLose string
		set sql_ltl {
			select
			  t.ltl_win_lp,
			  t.ltl_win_sp,
			  t.ltl_place_lp,
			  t.ltl_place_sp
			from
			  tEvType t
			where
			  t.ev_type_id = ?
		}
		set stmt_ltl [inf_prep_sql $DB $sql_ltl]
		set res_ltl [inf_exec_stmt $stmt_ltl $type_id]
		inf_close_stmt $stmt_ltl
		if {[db_get_nrows $res_ltl] == 1} {
			set ev_max_lay_to_lose \
				[max [db_get_col $res_ltl 0 ltl_win_lp] [db_get_col $res_ltl 0 ltl_win_sp] [db_get_col $res_ltl 0 ltl_place_lp] [db_get_col $res_ltl 0 ltl_place_sp]]
			tpBindString EvMaxLayToLose $ev_max_lay_to_lose
			tpBindString TypeMostMaxBet $ev_max_lay_to_lose
		}
		db_close $res_ltl
	}

	# Sets the money back special checkbox
	set sql_sp {
		select
			sp.lang,
			Case
				when sp.special_type = "MBS" then '1'
				else '0'
			end as special_type
		from
			tSpecialOffer sp
		where
			sp.id    = ?  and
			sp.level = 'EVENT'
	}

	set stmt_sp [inf_prep_sql $DB $sql_sp]
	set res_sp [inf_exec_stmt $stmt_sp $ev_id]
	inf_close_stmt $stmt_sp
	set mbs_rows [db_get_nrows $res_sp]
	if {$mbs_rows != 0} {
		tpBindString MBS 1
	} else {
		tpBindString MBS 0
	}

	if {$mbs_rows > 1} {
		ob_log::write INFO "Found multiple money back specials for selected event"
	}

	set lang_list ""
	for {set i 0} {$i < $mbs_rows} {incr i} {
		append lang_list "[db_get_col $res_sp $i lang] "
	}

	db_close $res_sp
	make_language_binds $lang_list -
	#
	#
	# If we've just come from the event list results page
	# we have to remember what the search criteria is to go
	# back to this page successfully.  If we've come from
	# anywhere else, these values will just be blank.
	# slee
	#
	tpBindString ClassId    [reqGetArg ClassId]
	tpBindString type_id    [reqGetArg type_id]
	tpBindString date_range [reqGetArg date_range]
	tpBindString date_lo    [reqGetArg date_lo]
	tpBindString date_hi    [reqGetArg date_hi]
	tpBindString settled    [reqGetArg settled]
	tpBindString status     [reqGetArg status]
	tpBindString allow_stl  [reqGetArg allow_stl]

	#
	# If this is a FB event, display the home/away team names if
	# they exist
	#
	if {$c_sort == "FB"} {

		set home_team_name "(Unset)"
		set away_team_name "(Unset)"

		set team_sql  [subst {
			select
				te.side,
				t.name
			from
				tTeamEvent te,
				tTeam t
			where
				te.ev_id = ? and
				te.team_id = t.team_id
		}]

		set team_stmt [inf_prep_sql $DB $team_sql]
		set team_res  [inf_exec_stmt $team_stmt $ev_id]
		inf_close_stmt $team_stmt

		set n_teams [db_get_nrows $team_res]

		for {set i 0} {$i < $n_teams} {incr i} {
			if {[db_get_col $team_res $i side] == "H"} {
				set home_team_name [db_get_col $team_res $i name]
			} elseif {[db_get_col $team_res $i side] == "A"} {
				set away_team_name [db_get_col $team_res $i name]
			}
		}

		tpBindString EvHomeTeam  $home_team_name
		tpBindString EvAwayTeam  $away_team_name

		db_close $team_res

	}


	tpSetVar Confirmed [expr {$result_conf == "Y"}]
	tpSetVar Settled   [expr {$settled == "Y"}]
	tpSetVar Suspended [expr {$status == "S"}]
	tpSetVar ClassSort $c_sort

	set now  [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	#
	# Count number of selections with no results
	#
	if {[string compare $start $now] <= 0} {

		tpSetVar AfterEventStart 1

		if {$result_conf == "N"} {

			set sql {
				select count(*) num_unconf
				from   tEvOc
				where  ev_id = ?
				and    result = '-'
			}

			set stmt [inf_prep_sql $DB $sql]
			set resc [inf_exec_stmt $stmt $ev_id]

			inf_close_stmt $stmt

			set nres [db_get_col $resc 0 num_unconf]

			if {$nres == ""} {
				set nres 0
			}

			tpSetVar     NumSelnsNoRslt $nres
			tpBindString NumSelnsNoRslt $nres
		}

	} else {
		tpSetVar AfterEventStart 0
	}

	db_close $res

	ADMIN::FBCHARTS::fb_read_chart_info

	tpSetVar NumDomains $FB_CHART_MAP(num_domains)

	tpBindVar DomainFlag FB_CHART_MAP flag domain_idx
	tpBindVar DomainName FB_CHART_MAP name domain_idx

	if {[OT_CfgGet FUNC_STATIONS 0]} {
		# Find which stations this event is shown on
		set sql [subst {
			select
				es.station_id
			from
				tEvStation es,
				tStation   st
			where
					es.ev_id      = ?
				and st.station_id = es.station_id
				and st.status     = 'A'
		}]

		set stmt  [inf_prep_sql $::DB $sql]
		set st_rs [inf_exec_stmt $stmt $ev_id]
		inf_close_stmt $stmt

		set station_list [list]
		for {set i 0} {$i < [db_get_nrows $st_rs]} {incr i} {
			lappend station_list [db_get_col $st_rs $i station_id]
		}
		db_close $st_rs
		make_station_binds $station_list - 0
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_EV::bind_mapped_bf_event $type_id $ev_id
	}

	#
	# Find out if the event has a commentary
	#

	set sql [subst {
		select first 1
			ev_id
		from
			tComEvSetup c
		where
			c.ev_id  =  $ev_id

	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_comm [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	if {[db_get_nrows $res_comm] < 1} {
		set has_commentary 0
	} else {
		set has_commentary 1
	}

	tpSetVar ShowClearButton $has_commentary

	#
	# Now read the markets for the event
	#
	set sql {
		select
			m.ev_mkt_id,
			m.name,
			m.type,
			m.sort,
			m.status,
			m.settled,
			m.result_conf,
			m.displayed,
			m.disporder,
			m.ew_avail,
			m.ew_fac_num,
			m.ew_fac_den,
			m.ew_places,
			m.lp_avail,
			m.sp_avail,
			m.hcap_value
		from
			tEvMkt   m
		where
			ev_id = ?
		order by
			m.disporder, m.ev_mkt_id
	}

	set stmt    [inf_prep_sql $DB $sql]
	set res_mkt [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	#
	# Sort out which market operations to display
	#
	set n_mkts [db_get_nrows $res_mkt]

	tpSetVar NumMkts $n_mkts

	for {set r 0} {$r < $n_mkts} {incr r} {

		set mkt_type [db_get_col $res_mkt $r type]
		set status   [db_get_col $res_mkt $r status]
		set hcap     [db_get_col $res_mkt $r hcap_value]

		switch -- $mkt_type {
			A -
			l {
				set hcap_str "([ah_string $hcap])"
			}
			H -
			U -
			M -
			L {
				set hcap_str "($hcap)"
			}
			default {
				set hcap_str ""
			}
		}

		set MKT($r,hcap_str) $hcap_str
		set MKT($r,status)   $status
	}

	tpBindTcl MktId         sb_res_data $res_mkt mkt_idx ev_mkt_id
	tpBindTcl MktName       sb_res_data $res_mkt mkt_idx name
	tpBindTcl MktSettled    sb_res_data $res_mkt mkt_idx settled
	tpBindTcl MktResultConf sb_res_data $res_mkt mkt_idx result_conf
	tpBindTcl MktDisplayed  sb_res_data $res_mkt mkt_idx displayed
	tpBindTcl MktDisporder  sb_res_data $res_mkt mkt_idx disporder
	tpBindTcl MktEWAvail    sb_res_data $res_mkt mkt_idx ew_avail
	tpBindTcl MktEWPlaces   sb_res_data $res_mkt mkt_idx ew_places
	tpBindTcl MktEW_N       sb_res_data $res_mkt mkt_idx ew_fac_num
	tpBindTcl MktEW_D       sb_res_data $res_mkt mkt_idx ew_fac_den
	tpBindTcl MktLP         sb_res_data $res_mkt mkt_idx lp_avail
	tpBindTcl MktSP         sb_res_data $res_mkt mkt_idx sp_avail

	tpBindVar MktStatus  MKT status   mkt_idx
	tpBindVar MktHcapStr MKT hcap_str mkt_idx

	#
	# Now read a list of all the markets applicable to this type
	#
	set sql {
		select
			ev_oc_grp_id,
			name,
			disporder
		from
			tEvOcGrp
		where
			ev_type_id = ?
		order by
			disporder asc
	}

	set stmt        [inf_prep_sql $DB $sql]
	set res_mkt_grp [inf_exec_stmt $stmt $type_id]
	inf_close_stmt $stmt

	tpSetVar NumMktGrps [db_get_nrows $res_mkt_grp]

	tpBindTcl MktGrpId   sb_res_data $res_mkt_grp mkt_grp_idx ev_oc_grp_id
	tpBindTcl MktGrpName sb_res_data $res_mkt_grp mkt_grp_idx name


	#
	# Index trading markets
	#
	if {[OT_CfgGet FUNC_INDEX_TRADE 0]} {

		#
		# Get event index markets
		#
		set sql {
			select
				m.f_mkt_id,
				m.disporder,
				m.displayed,
				m.sort,
				m.status,
				m.index_min,
				m.index_max,
				m.channels,
				m.name,
				m.code,
				m.makeup,
				m.result_conf,
				m.settled
			from
				tfMkt m
			where
				m.ev_id = ?
			order by
				m.disporder asc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ev_id]
		inf_close_stmt $stmt

		tpSetVar NumIxMkts [set n_rows [db_get_nrows $res]]

		GC::mark ::EVIXMKT

		for {set r 0} {$r < $n_rows} {incr r} {
			set ::EVIXMKT($r,f_mkt_id)    [db_get_col $res $r f_mkt_id]
			set ::EVIXMKT($r,disporder)   [db_get_col $res $r disporder]
			set ::EVIXMKT($r,displayed)   [db_get_col $res $r displayed]
			set ::EVIXMKT($r,sort)        [db_get_col $res $r sort]
			set ::EVIXMKT($r,status)      [db_get_col $res $r status]
			set ::EVIXMKT($r,index_min)   [db_get_col $res $r index_min]
			set ::EVIXMKT($r,index_max)   [db_get_col $res $r index_max]
			set ::EVIXMKT($r,name)        [db_get_col $res $r name]
			set ::EVIXMKT($r,code)        [db_get_col $res $r code]
			set ::EVIXMKT($r,makeup)      [db_get_col $res $r makeup]
			set ::EVIXMKT($r,result_conf) [db_get_col $res $r result_conf]
			set ::EVIXMKT($r,settled)     [db_get_col $res $r settled]
		}

		db_close $res

		tpBindVar IxMktId         ::EVIXMKT f_mkt_id    ixmkt_idx
		tpBindVar IxMktDisporder  ::EVIXMKT disporder   ixmkt_idx
		tpBindVar IxMktDisplayed  ::EVIXMKT displayed   ixmkt_idx
		tpBindVar IxMktSort       ::EVIXMKT sort        ixmkt_idx
		tpBindVar IxMktStatus     ::EVIXMKT status      ixmkt_idx
		tpBindVar IxMktIndexMin   ::EVIXMKT index_min   ixmkt_idx
		tpBindVar IxMktIndexMax   ::EVIXMKT index_max   ixmkt_idx
		tpBindVar IxMktName       ::EVIXMKT name        ixmkt_idx
		tpBindVar IxMktCode       ::EVIXMKT code        ixmkt_idx
		tpBindVar IxMktMakeup     ::EVIXMKT makeup      ixmkt_idx
		tpBindVar IxMktResultConf ::EVIXMKT result_conf ixmkt_idx
		tpBindVar IxMktSettled    ::EVIXMKT settled     ixmkt_idx

		#
		# Now read a list of all the markets applicable to this type
		#
		set sql {
			select
				f.f_mkt_grp_id,
				f.sort,
				f.name,
				f.disporder
			from
				tfMktGrp f
			where
				f.ev_type_id = ? and
				f.f_mkt_grp_id not in (
					select
						f_mkt_grp_id
					from
						tfMkt
					where
						sort <> 'DFLT' and ev_id = ?
				)
			order by
				disporder asc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $type_id $ev_id]
		inf_close_stmt $stmt

		tpSetVar NumIxMktGrps [set n_rows [db_get_nrows $res]]

		GC::mark ::EVIXMKTGRP

		for {set r 0} {$r < $n_rows} {incr r} {
			set ::EVIXMKTGRP($r,id)     [db_get_col $res $r f_mkt_grp_id]
			set ::EVIXMKTGRP($r,name)   [db_get_col $res $r name]
		}

		db_close $res

		tpBindVar IxMktGrpId   ::EVIXMKTGRP id   ixmktgrp_idx
		tpBindVar IxMktGrpName ::EVIXMKTGRP name ixmktgrp_idx
	}
	if {[op_allowed AssignTrader]} {
		bind_trader_data "Trader"
	}

	if {[OT_CfgGet FUNC_FORM_FEEDS 0]} {
		ADMIN::FORM::make_form_feed_provider_binds
	}


	#
	#RT1819 - Count number of markets with nonvoid selections and no hcap makeup
	#
	set CanConfHcaps 1
	set sqlx {
		select
			count(*) num_non_void
		from
			tEVMkt m,
			tEvOC  o
		where
			m.ev_id = ?                         and
			m.type in ('A','H','U','L','l','M') and
			m.hcap_makeup is null               and
			m.ev_mkt_id   = o.ev_mkt_id         and
			o.result      != 'V'
	}
	set stmt [inf_prep_sql $DB $sqlx]
	set res  [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res]
	if {$nrows > 0} {
		set num_non_void [db_get_col $res 0 num_non_void]
		if {$num_non_void > 0} {
			# cannot confirm hcap markets unless hcap_makeup is set for markets
			# with nonvoid selections
			set CanConfHcaps 0
		}
	}
	tpBindString CanConfHcaps $CanConfHcaps
	db_close $res


	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any dilldown items. Such as categories, classes types and
	# markets. and allow_dd_deletion is for deleting items
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_EV::bind_all_bf_events $ev_id $class_id $c_sort
	}

	asPlayFile event.html

	db_close $res_mkt
	db_close $res_mkt_grp

	catch {unset BF_MTCH}
	catch {unset BFEVS}
	catch {unset MKT TRADERS}
}



#
# ----------------------------------------------------------------------------
# Go to bulk event update
# ----------------------------------------------------------------------------
#

proc go_ev_quick_stl_results args {

	global USERNAME

	asPlayFile -nocache event_quick_settle_results.html

}

proc do_ev_quick_stl_results args {

	for {set i 0; set n [reqGetNumVals]} {$i < $n} {incr i} {

		set name [reqGetNthName $i]

		if {[regexp {^confirm_(\d+)$} $name match ev_id]} {

			switch -- [reqGetArg $name] {

				u {
					if {[do_ev_conf_yn N $ev_id]} {
						tpBufWrite "Failed to uncomfirm results for event #$ev_id\n"
					} else {
						tpBufWrite "Uncomfirming results for event #$ev_id\n"
					}
				}

				c {
					if {[do_ev_conf_yn Y $ev_id]} {
						tpBufWrite "Failed to confirm results for event #$ev_id\n"
					} else {
						tpBufWrite "Comfirming results for event #$ev_id\n"
					}
				}

				s {
					if {[catch {ADMIN::SETTLE::stl_settle event \
							$ev_id Y} msg] == 1 ||
						[catch {ADMIN::SETTLE::stl_settle evt_pools \
							$ev_id Y} msg] == 1} {
						tpBufWrite $msg
					}
				}

			}

		}
	}
}

proc go_crit_ev_conf args {

	tpBindString AuxLoginUID [ADMIN::LOGIN::gen_login_uid]

	asPlayFile -nocache event_auxconf.html
}


#
# ----------------------------------------------------------------------------
# Go to bulk event update
# ----------------------------------------------------------------------------
#
proc go_evs_upd args {

	global DB CHANNELS CHANNEL_MAP QUICK_UPD_FLAGS QUICK_UPD_FLAG_MAP EV_STATUS TRADERS

	if {[info exists CHANNELS]==1} {
		unset CHANNELS
	}

	set d_lo	  [reqGetArg d_lo]
	set d_hi	  [reqGetArg d_hi]
	set date_lo   [reqGetArg date_lo]
	set date_hi   [reqGetArg date_hi]
	set date_sel  [reqGetArg date_range]
	set settled   [reqGetArg Settled]
	set status    [reqGetArg Status]
	set displayed [reqGetArg Displayed]
	set class_id  [reqGetArg ClassId]

	set all_status  [reqGetArg all_status]
	set all_displayed  [reqGetArg all_displayed]
	set all_off     [reqGetArg all_off]

	set start_or_susp 	[reqGetArg start_or_susp]
	set is_bir 	        [reqGetArg is_bir]

	tpBindString AllStatus $all_status
	tpBindString AllDisplayed $all_displayed
	tpBindString AllOff $all_off

	tpBindString Settled $settled
	tpBindString Status	 $status
	tpBindString Displayed $displayed

	if {$d_lo=="" || $d_hi==""} {

		set d_lo "'0001-01-01 00:00:00'"
		set d_hi "'9999-12-31 23:59:59'"

		if {$date_lo != "" || $date_hi != ""} {
			if {$date_lo != ""} {
				set d_lo "'$date_lo 00:00:00'"
			}
			if {$date_hi != ""} {
				set d_hi "'$date_hi 23:59:59'"
			}
		} else {
			set format "%Y-%m-%d %H:%M:%S"
			set short_fm "%Y-%m-%d"
			set time [clock seconds]

			if {$date_sel == "-2"} {
				#
				# Previous hour
				#
				set d_hi "'[clock format $time -format $format]'"
				set d_lo "'[clock format [expr {$time - 3600}] -format $format]'"
			} elseif {$date_sel == "-1"} {
				#
				# Previous 30 mins
				#
				set d_hi "'[clock format $time -format $format]'"
				set d_lo "'[clock format [expr {$time - 1800}] -format $format]'"
			} elseif {$date_sel == "0"} {
				#
				# Today
				#
				set d_lo "'[clock format $time -format $short_fm] 00:00:00'"
				set d_hi "'[clock format $time -format $short_fm] 23:59:59'"
			} elseif {$date_sel == "1"} {
				#
				# Tomorrow
				#
				set d_lo "'[clock format [expr {$time + 86400}] -format $short_fm] 00:00:00'"
				set d_hi "'[clock format [expr {$time + 86400}] -format $short_fm] 23:59:59'"
			} elseif {$date_sel == "2"} {
				#
				# Future
				#
				set d_lo CURRENT
			}
		}
	}

	set res\
		[get_evs_to_update $settled $status $displayed $d_lo $d_hi $class_id $start_or_susp $is_bir]

	set numEvents [db_get_nrows $res]

	read_channel_info
	read_quick_update_flags

	set num_flags    $QUICK_UPD_FLAG_MAP(num_flags)
	set num_channels $CHANNEL_MAP(num_channels)

	tpSetVar     NumFlags    $num_flags
	tpBindString NumFlags    $num_flags
	tpSetVar     NumChannels $num_channels
	tpBindString NumChannels $num_channels

	for {set i 0} {$i < $numEvents} {incr i} {

		set flags [db_get_col $res $i flags]
		set type_channels [db_get_col $res $i type_channels]
		set ev_channels   [db_get_col $res $i ev_channels]
		set ntc           [string length $type_channels]

		set flags_list [split $flags ,]

		set result_set [db_get_col $res $i result_set]

		if {$result_set=="N"} {
			if {$all_status=="A"} {
				set EV_STATUS($i,status) "A"
			} elseif {$all_status=="S"} {
				set EV_STATUS($i,status) "S"
			} else {
				set EV_STATUS($i,status) [db_get_col $res $i status]
			}
		} else {
			set EV_STATUS($i,status) [db_get_col $res $i status]
		}

		for {set j 0} {$j < $num_flags} {incr j} {

			set QUICK_UPD_FLAGS($i,$j,code) $QUICK_UPD_FLAG_MAP($j,code)
			set QUICK_UPD_FLAGS($i,$j,name) $QUICK_UPD_FLAG_MAP($j,name)
			set QUICK_UPD_FLAGS($i,$j,type) checkbox

			if {[lsearch -exact $flags_list $QUICK_UPD_FLAG_MAP($j,code)] >= 0} {
				set QUICK_UPD_FLAGS($i,$j,use) "checked"
			} else {
				set QUICK_UPD_FLAGS($i,$j,use) ""
			}

		}

		#
		# Support #16903 - mstephen
		# I've taken this code from RC_OpenBet4_5
		#
		# HEAT 13850 - jbrandt
		# Don't assume that all channels listed in type or event
		# are really defined in tChannel (Playboy Admin)
		for {set j 0} {$j < $num_channels} {incr j} {

			set chnnl_code $CHANNEL_MAP($j,code)
			set chnnl_name $CHANNEL_MAP($j,name)

			if {[string first $chnnl_code $type_channels] >= 0} {

				set CHANNELS($i,$j,chnnl_name) $chnnl_name
				set CHANNELS($i,$j,channel_cd) $chnnl_code
				set CHANNELS($i,$j,chnnl_type) checkbox

				if {[string first $chnnl_code $ev_channels] >= 0} {
					set CHANNELS($i,$j,use) "checked"
				} else {
					set CHANNELS($i,$j,use) ""
				}

			} else {

				set CHANNELS($i,$j,chnnl_name) ""
				set CHANNELS($i,$j,chnnl_type) "hidden"
				set CHANNELS($i,$j,channel_cd) ""
				set CHANNELS($i,$j,use)        ""
			}
		}

	}

	if {[op_allowed AssignTrader]} {
		bind_trader_data "Trader"
	}

	tpBindVar ChannelInput CHANNELS chnnl_type seln_idx chnnl_idx
	tpBindVar ChannelCd    CHANNELS channel_cd seln_idx chnnl_idx
	tpBindVar ChannelUse   CHANNELS use        seln_idx chnnl_idx
	tpBindVar ChannelName  CHANNELS chnnl_name seln_idx chnnl_idx

	tpBindVar FlagInput QUICK_UPD_FLAGS type seln_idx flag_idx
	tpBindVar FlagCode  QUICK_UPD_FLAGS code seln_idx flag_idx
	tpBindVar FlagUse   QUICK_UPD_FLAGS use  seln_idx flag_idx
	tpBindVar FlagName  QUICK_UPD_FLAGS name seln_idx flag_idx

	tpSetVar NumEvents  $numEvents

	tpBindTcl EvId         sb_res_data $res seln_idx ev_id
	tpBindTcl EvDesc       sb_res_data $res seln_idx desc
	tpBindTcl EvStartTime  sb_res_data $res seln_idx start_time
	tpBindTcl EvResultSet  sb_res_data $res seln_idx result_set
	tpBindTcl EvResultConf sb_res_data $res seln_idx result_conf
	tpBindTcl EvStarted    sb_res_data $res seln_idx started
	tpBindTcl EvSettled    sb_res_data $res seln_idx settled
	tpBindTcl EvDisporder  sb_res_data $res seln_idx disporder
	tpBindTcl EvMinBet     sb_res_data $res seln_idx min_bet
	tpBindTcl EvMaxBet     sb_res_data $res seln_idx max_bet
	tpBindTcl EvMultKey    sb_res_data $res seln_idx mult_key
	tpBindTcl EvMinBet     sb_res_data $res seln_idx min_bet
	tpBindTcl EvMaxBet     sb_res_data $res seln_idx max_bet
	tpBindTcl EvTrader     sb_res_data $res seln_idx trader_user_id
	tpBindVar EvRightNow   CHANNELS rightnow seln_idx
	tpBindTcl EvBirDelay        sb_res_data $res seln_idx bir_delay
 	tpBindTcl EvBirHierarchy    ADMIN::EVENT::get_bir_hierarchy $res seln_idx

	if {$all_displayed=="Y"} {
		tpBindString EvDisplayed "Y"
	} elseif {$all_displayed=="N"} {
		tpBindString EvDisplayed "N"
	} else {
		tpBindTcl EvDisplayed  sb_res_data $res seln_idx displayed
	}

	if {$all_off=="Y"} {
		tpBindString EvIsOff {Y}
	} elseif {$all_off=="S"} {
		tpBindString EvIsOff {N}
	} elseif {$all_off=="-"} {
		tpBindString EvIsOff {-}
	} else {
		tpBindTcl EvIsOff  sb_res_data $res seln_idx is_off
	}

	tpBindVar EvStatus  EV_STATUS status seln_idx

	tpBindString ClassId $class_id
	tpBindString d_lo    $d_lo
	tpBindString d_hi    $d_hi

	tpBindString start_or_susp 	$start_or_susp
	tpBindString is_bir 	    $is_bir

	asPlayFile event_upd.html

	db_close $res

	catch {unset TRADERS}
}


proc get_evs_to_update {settled status displayed d_lo d_hi class_id start_or_susp is_bir} {

	global DB

	if {$start_or_susp == "susp"} {
		set where "and e.suspend_at between $d_lo and $d_hi"
	} else {
		set where "and e.start_time between $d_lo and $d_hi"
	}

	if {$is_bir == "Y"} {
		append where " and e.has_bet_in_run = 'Y'"
	} elseif {$is_bir == "N"} {
		append where " and e.has_bet_in_run = 'N'"
	}

	if {$class_id != "0"} {
		append where " and t.ev_class_id=$class_id"
	}
	if {$settled != "-"}  {
		append where " and e.settled='$settled'"
	}
	if {$status != "-"} {
		append where " and e.status='$status'"
	}
	if {$displayed != "-"} {
		append where " and e.displayed='$displayed'"
	}


	set sql [subst {
		select
			e.ev_id,
			e.desc,
			e.start_time,
			e.status,
			e.displayed,
			e.disporder,
			e.settled,
			e.min_bet,
			e.max_bet,
			e.mult_key,
			e.channels ev_channels,
			e.fb_dom_int,
			e.result_conf,
			e.ext_key,
			e.url,
			e.tax_rate,
			e.t_bet_cutoff,
			e.suspend_at,
			e.blurb,
			e.flags,
			e.trader_user_id,
			case
			  when exists (select 'Y' from tEvOc oc
						  where e.ev_id = oc.ev_id
						  and	oc.result = '-'
						  ) then "N"
			  else "Y"
			end result_set,
			case
				when e.start_time < CURRENT then "Y"
				else "N"
			end started,
			t.channels type_channels,
			t.ev_type_id,
			case
				when c.sort in ("HR","GR") then
					e.is_off
				else "X"
			end is_off,
			e.bir_delay,
			pGetHierarchyBIRDelayLevel("EVENT", e.ev_id) as bir_hierarchy_level,
			pGetHierarchyBIRDelay("EVENT", e.ev_id) as bir_hierarchy_value
		from
			tEv e,
			tEvType t,
			tEvClass c
		where
			e.ev_type_id = t.ev_type_id
		and t.ev_class_id = c.ev_class_id
			$where
		order by
			t.ev_type_id,e.disporder,e.start_time
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res	 [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	return $res
}

#
# ----------------------------------------------------------------------------
# Router event add/update/delete to appropriate handler
# ----------------------------------------------------------------------------
#
proc do_ev args {

	set act [reqGetArg SubmitName]

	if {$act == "EvAdd"} {
		do_ev_add
	} elseif {$act == "EvMod"} {
		do_ev_upd
	} elseif {$act == "EvDel"} {
		do_ev_del
	} elseif {$act == "Back"} {

		#
		# Check, do we need to go back to the results page
		# or straight to the event search form.
		# slee
		#
		if {[reqGetArg date_range] == ""} {
			ADMIN::EV_SEL::go_ev_sel
		} else {
			reqSetArg SubmitName EvShow
			reqSetArg TypeId     [reqGetArg type_id]
			ADMIN::EV_SEL::do_ev_sel
		}
	} elseif {[OT_CfgGet FUNC_CLEAR_EVENT 0] && $act == "DoClearEv"} {
		do_clear_ev
	} elseif {$act == "GenUpdBIR"} {
		do_ltl_upd "Y"
	} elseif {$act == "GenUpdPRE"} {
		do_ltl_upd "N"
	} elseif {$act == "LiabUpd"} {
		# go_ev_upd is the callback function
		do_liab_upd {go_ev_upd}
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}


#
# ----------------------------------------------------------------------------
# Event Add
# ----------------------------------------------------------------------------
#
proc do_ev_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsEv(
			p_adminuser = ?,
			p_ev_type_id = ?,
			p_desc = ?,
			p_country = ?,
			p_venue = ?,
			p_ext_key = ?,
			p_shortcut = ?,
			p_start_time = ?,
			p_late_bet_tol = ?,
			p_late_bet_tol_op = ?,
			p_is_off = ?,
			p_close_time = ?,
			p_sort = ?,
			p_flags = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_url = ?,
			p_status = ?,
			p_tax_rate = ?,
			p_feed_updateable = ?,
			p_mult_key = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_max_place_lp = ?,
			p_max_place_sp = ?,
			p_t_bet_cutoff = ?,
			p_suspend_at = ?,
			p_sp_allbets_from = ?,
			p_sp_allbets_to = ?,
			p_fb_dom_int = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_home_team_id = ?,
			p_away_team_id = ?,
			p_blurb = ?,
			p_calendar = ?,
			p_notes = ?,
			p_allow_stl = ?,
			p_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_ew_factor = ?,
			p_event_ll = ?,
			p_event_lm = ?,
			p_event_mm = ?,
			p_event_ltl = ?,
			p_est_start_time = ?,
			p_trader_user_id = ?,
			p_bir_delay = ?
		)
	}]

	set channels [make_channel_str]
	set ev_tags  [make_ev_tag_str [reqGetArg ClassSort]]
	set calendar [reqGetArg Calendar]
	if {$calendar != ""} {
		set calendar "Y"
	}


	set bir_delay [reqGetArg EvBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_ev_add
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_ev_add
			return
		}

	}

	set ev_type_id [reqGetArg TypeId]
	set close_time [reqGetArg EvCloseTime]

	if {[get_sort $ev_type_id]=="FM" && $close_time==""} {
		# it's an index event - make sure they enter a close_time
		err_bind "Must have a close time for an index event"
		go_ev_add
		return
	}

	if {[OT_CfgGet FUNC_GEN_EV_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	# check that our values are numeric -- allow aaaaa and aaaaa.bb and null
	set least_max_bet [reqGetArg LeastMaxBet]
	set lay_to_lose [reqGetArg LayToLose]
	set most_max_bet [reqGetArg MostMaxBet]
	set liability [reqGetArg Liability]
	set elist [ list ]
	if { [valid_input $least_max_bet] == 1 } {
	} else {
		lappend elist "least max bet"
	}
	if { [valid_input $most_max_bet] == 1 } {
	} else {
		lappend elist "most max bet"
	}
	if { [valid_input $lay_to_lose] == 1 } {
	} else {
		lappend elist "lay to lose"
	}
	if { [valid_input $liability] == 1 } {
	} else {
		lappend elist "liability"
	}
	if { [llength $elist] != 0 } {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		set estr [join $elist ", "]
		err_bind "Re enter values for $estr"
		go_ev_add
		return
	}


	# check for sensible values
	if {$least_max_bet < 0} {set least_max_bet 0}
	if {$most_max_bet != ""} {
		if {$most_max_bet < 0} {set most_max_bet 0}
		if {$most_max_bet < $least_max_bet} {
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			err_bind "Most max bet cannot be less than least max bet."
			go_ev_upd
			return
		}
	}

	if {$lay_to_lose != ""} {
		if {$lay_to_lose < 0} {
			set lay_to_lose 0
		}
		if {$most_max_bet == "" || $most_max_bet == 0} {
			set most_max_bet $lay_to_lose
		}
	} else {
		if {$most_max_bet == "" || $most_max_bet == 0} {
			set most_max_bet [reqGetArg EvMaxLayToLose]
		}
	}

	if {$liability < 0} {set liability 0}
	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	# propagate max_bet to max_place_lp and max_bet_sp to max_place_sp
	# if the max_place fields aren't filled in
	if { [reqGetArg EvMaxPlaceLP] == "" } {
		set max_place_lp [reqGetArg MaxBet]
	} else {
		set max_place_lp [reqGetArg EvMaxPlaceLP]
	}
	if { [reqGetArg EvMaxPlaceSP] == "" } {
		set max_place_sp [reqGetArg EvSpMaxBet]
	} else {
		set max_place_sp [reqGetArg EvMaxPlaceSP]
	}
	set allow_stl [reqGetArg EvAllowStl]

	if {$allow_stl != "Y"} {
		set allow_stl "N"
	}

	# Money back special settings
	set has_MBS [reqGetArg MBS]
	if {$has_MBS == ""} {
		set has_MBS 0
	}

	if {[catch {
		set res  [inf_exec_stmt $stmt\
					$USERNAME\
					$ev_type_id\
					[reqGetArg EvDesc]\
					[reqGetArg EvCountry]\
					[reqGetArg EvVenue]\
					[reqGetArg EvExtKey]\
					[reqGetArg EvShortcut]\
					[reqGetArg EvStartTime]\
					[reqGetArg EvNoMoreBetTime]\
					[reqGetArg EvNoMoreBetTimeOp]\
					[reqGetArg EvIsOff]\
					$close_time\
					[reqGetArg EvSort]\
					$ev_tags\
					[reqGetArg EvDisplayed]\
					[reqGetArg EvDisporder]\
					[reqGetArg EvURL]\
					[reqGetArg EvStatus]\
					[reqGetArg EvTaxRate]\
					[reqGetArg EvFeedUpdateable]\
					[reqGetArg EvMultKey]\
					[reqGetArg EvMinBet]\
					[reqGetArg EvMaxBet]\
					[reqGetArg SpMaxBet]\
					$max_place_lp\
					$max_place_sp\
					[reqGetArg EvBetCutoff]\
					[reqGetArg EvSuspendAt]\
					[reqGetArg EvSettleAtSPFrom]\
					[reqGetArg EvSettleAtSPTo]\
					[reqGetArg EvFBDomain]\
					$channels\
					[reqGetArg EvFastkey]\
					[reqGetArg EvHomeTeamId]\
					[reqGetArg EvAwayTeamId]\
					[reqGetArg EvBlurb]\
					$calendar\
					[reqGetArg EvNotes]\
					$allow_stl\
					[reqGetArg EvMaxPotWin]\
					[reqGetArg EvMaxMultipleBet]\
					[reqGetArg EvEachWayFactor]\
					$liability\
					$least_max_bet\
					$most_max_bet\
					$lay_to_lose\
					[reqGetArg EvEstStartTime]\
					[reqGetArg EvTrader]\
					$bir_delay] } msg]} {
					err_bind $msg
					set bad 1
	}

	set ev_id [db_get_coln $res 0 0]

	# Puts the money back special flags into tSpecialOffer
	if {!$bad && $has_MBS} {
		set special_langs [make_special_langs_list]
		if {[catch {
			set passed update_special_type EVENT $ev_id "MBS" $special_langs 1 1 0
		} msg]} {
			ob_log::write ERROR {Failed to set special type for event: $msg}
			err_bind "Failed to set special type for event: $msg"
			set bad 1
		}
		if {!$passed} {set bad  1}
	}

	if {!$bad && [OT_CfgGet FUNC_STATIONS 0]} {
		set station_ids [make_station_str]
		if {[catch {
			ADMIN::STATION::upd_stations_for_ev $ev_id $station_ids
		} msg]} {
			ob_log::write ERROR {Failed to set TV stations for event: $msg}
			err_bind "Failed to set TV stations for event: $msg"
			set bad 1
		}
	}

	inf_close_stmt $stmt

	if {($bad == 1) || ([db_get_nrows $res] != 1)} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ev_add
		return
	}

	db_close $res

	#
	# Insertion was OK, go back to the event screen in update mode
	#
	tpSetVar EvAdded 1

	go_ev_upd ev_id $ev_id
}


#
# ----------------------------------------------------------------------------
# Event Update
# ----------------------------------------------------------------------------
#
proc do_ev_auxconf_check {} {

	global DB USERNAME

	set u [reqGetArg AuxAdminName]
	set p [reqGetArg AuxAdminPwd]

	# The usernames must be different since it is a second user who
	# is confirming the actions of the first.
	if {$u == $USERNAME} {
		return [list BAD "Confirmation username/password invalid"]
	}

	set sql {
		select
			u.user_id,o.action,gro.action
		from
			tAdminUser u,
			outer tAdminUserOp o,
			outer (tAdminUserGroup ug, tAdminGroup g, tAdminGroupOp gro)
		where
			u.user_id = o.user_id and
			u.username = ? and
			u.password = ? and
			u.status = 'A' and
			ug.user_id = u.user_id and
			g.group_id = ug.group_id and
			gro.group_id = g.group_id and
			o.action = 'ConfirmEvChange' and
			gro.action = 'ConfirmEvChange'
		group by 1,2,3
		having o.action is not null or gro.action is not null
	}

	set stmt [inf_prep_sql $DB $sql]

	set salt_resp [ob_crypt::get_admin_salt $u]
	set salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set salt ""
	}

	ob_crypt::encrypt_admin_password $p $salt

	set res  [inf_exec_stmt $stmt $u $phash]
	inf_close_stmt $stmt

	set n [db_get_nrows $res]

	if {$n != 1} {
		db_close $res
		return [list BAD "Confirmation username/password invalid"]
	}

	set user_id [db_get_col $res 0 user_id]

	db_close $res

	return [list OK $user_id]
}


#
# ----------------------------------------------------------------------------
# Event Update
# ----------------------------------------------------------------------------
#
proc do_ev_upd args {

	global DB USERNAME

	set ev_id [reqGetArg EvId]

	set aux_user_id ""

	if {[OT_CfgGetTrue FUNC_CONF_CRIT_EV_CHNG]} {
		#
		# If start time changed or status changed (S => A), need to do
		# some stuff...
		#
		set sql {
			select
				start_time,
				status
			from
				tEv
			where
				ev_id = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ev_id]
		inf_close_stmt $stmt

		set i_start_time [db_get_col $res 0 start_time]
		set i_status     [db_get_col $res 0 status]

		db_close $res

		set z_start_time [reqGetArg EvStartTime]
		set z_status     [reqGetArg EvStatus]

		set perm_check 0

		if {"$i_start_time" != "$z_start_time"} {
			set perm_check 1
		}
		if {"$i_status" == "S" && "$z_status" == "A"} {
			set perm_check 1
		}

		if {$perm_check} {
			set r [do_ev_auxconf_check]
			if {[lindex $r 0] != "OK"} {
				err_bind [lindex $r 1]
				go_ev_upd
				return
			}
			set aux_user_id [lindex $r 1]
		}
	}

	set sql {
		execute procedure pUpdEv(
			p_adminuser = ?,
			p_aux_user_id = ?,
			p_ev_id = ?,
			p_desc = ?,
			p_country = ?,
			p_venue = ?,
			p_ext_key = ?,
			p_shortcut = ?,
			p_start_time = ?,
			p_late_bet_tol = ?,
			p_late_bet_tol_op = ?,
			p_is_off = ?,
			p_close_time = ?,
			p_sort = ?,
			p_flags = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_url = ?,
			p_status = ?,
			p_tax_rate = ?,
			p_feed_updateable = ?,
			p_mult_key = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_t_bet_cutoff = ?,
			p_suspend_at = ?,
			p_sp_allbets_from = ?,
			p_sp_allbets_to = ?,
			p_fb_dom_int = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_home_team_id = ?,
			p_away_team_id = ?,
			p_blurb = ?,
			p_result = ?,
			p_calendar = ?,
			p_notes = ?,
			p_allow_stl = ?,
			p_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_ew_factor = ?,
			p_ev_code = ?,
			p_est_start_time = ?,
			p_trader_user_id = ?,
			p_bir_delay = ?
		)
	}

	set channels [make_channel_str]
	set ev_tags  [make_ev_tag_str [reqGetArg ClassSort]]
	set calendar [reqGetArg Calendar]
	if {$calendar != ""} {
		set calendar "Y"
	}

	set ev_type_id [reqGetArg TypeId]
	set close_time [reqGetArg EvCloseTime]

	if {[get_sort $ev_type_id]=="FM" && $close_time==""} {
		# it's an index event - make sure they enter a close_time
		err_bind "Must have a close time for an index event"
		go_ev_upd
		return
	}

	set ev_code [reqGetArg EvCode]
	if {![OT_CfgGet FUNC_GEN_EV_CODE 0] || $ev_code == ""} {
		set ev_code 0
	}

	# heat 12835 - fix so that if you remove blurb it actually removes
	# it. Before fix it was treating "" as a null and not updating it.
	# Now a zero length entry is in the DB if you enter a one space string for blurb
	set blurb "[reqGetArg EvBlurb]"
	if {$blurb == ""} {
		set blurb " "
	}


	# set late bet tolerance value
	set new_lbt [reqGetArg EvNoMoreBetTime]

	# RT2669 - if the is_off value is changed from N to Y, we append the
	# late bet tolerance value with the difference between CURRENT and start_time.
	if {[OT_CfgGet FUNC_OFF_FLAG_UPDATES_LBT 0]} {
		if {[reqGetArg EvIsOffOldValue] == "N" && [reqGetArg EvIsOff] == "Y"} {
			# current late bet tolerance value
			set lbt_cur [reqGetArg EvNoMoreBetTime 0]

			# time difference between now and start_time
			set ev_start_time [clock scan [reqGetArg EvStartTime]]
			set time_now      [clock seconds]
			set diff_seconds  [expr $time_now - $ev_start_time]

			# new late bet tolerance value - only if diff is positive (start time is in past)
			if {$diff_seconds > 0} {
				set new_lbt [expr $lbt_cur + $diff_seconds]
			}
		}
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set allow_stl [reqGetArg EvAllowStl]

	# Gets Money back special details
	set has_MBS [reqGetArg MBS]
	if {$has_MBS == ""} {
		set has_MBS 0
	}
	if {$allow_stl != "Y"} {
		set allow_stl "N"

	}

	set ev_id [reqGetArg EvId]
	set bir_delay [reqGetArg EvBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_ev_upd
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_ev_upd
			return
		}

	}

	if {[catch {
		set res  [inf_exec_stmt $stmt\
			$USERNAME\
			$aux_user_id\
			$ev_id\
			[reqGetArg EvDesc]\
			[reqGetArg EvCountry]\
			[reqGetArg EvVenue]\
			[reqGetArg EvExtKey]\
			[reqGetArg EvShortcut]\
			[reqGetArg EvStartTime]\
			$new_lbt\
			[reqGetArg EvNoMoreBetTimeOp]\
			[reqGetArg EvIsOff]\
			$close_time\
			[reqGetArg EvSort]\
			$ev_tags\
			[reqGetArg EvDisplayed]\
			[reqGetArg EvDisporder]\
			[reqGetArg EvURL]\
			[reqGetArg EvStatus]\
			[reqGetArg EvTaxRate]\
			[reqGetArg EvFeedUpdateable]\
			[reqGetArg EvMultKey]\
			[reqGetArg EvMinBet]\
			[reqGetArg EvMaxBet]\
			[reqGetArg SpMaxBet]\
			[reqGetArg EvBetCutoff]\
			[reqGetArg EvSuspendAt]\
			[reqGetArg EvSettleAtSPFrom]\
			[reqGetArg EvSettleAtSPTo]\
			[reqGetArg EvFBDomain]\
			$channels\
			[reqGetArg EvFastkey]\
			[reqGetArg EvHomeTeamId]\
			[reqGetArg EvAwayTeamId]\
			$blurb\
			[reqGetArg EvResult]\
			$calendar\
			[reqGetArg EvNotes]\
			$allow_stl\
			[reqGetArg EvMaxPotWin]\
			[reqGetArg EvMaxMultipleBet]\
			[reqGetArg EvEachWayFactor]\
			$ev_code\
			[reqGetArg EvEstStartTime]\
			[reqGetArg EvTrader]\
			$bir_delay]
	} msg]} {
		err_bind $msg
		set bad 1

	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {!$bad && [OT_CfgGet FUNC_STATIONS 0]} {
		set station_ids [make_station_str]
		if {[catch {
			ADMIN::STATION::upd_stations_for_ev $ev_id $station_ids
		} msg]} {
			ob_log::write ERROR {Failed to set TV stations for event: $msg}
			err_bind "Failed to set TV stations for event: $msg"
			set bad 1
		}
	}

	if {[OT_CfgGet BF_ACTIVE 0] && [OT_CfgGet BF_MANUAL_MATCH 0]} {
		set bf_ev_id		[reqGetArg BF_EventMatch]
		set bf_ev_id_old 	[reqGetArg BF_EvId_old]
		set class_sort      [reqGetArg ClassSort]
		set ev_start_time   [reqGetArg EvStartTime]
		incr bad [ADMIN::BETFAIR_EV::do_bf_ev_match $ev_type_id $ev_id $bf_ev_id $class_sort $ev_start_time $bf_ev_id_old]
	}

	# Stores the money back special flag in tSpecialOffer
	if {!$bad} {
		set special_langs [make_special_langs_list]
		if {[catch {
			if {$has_MBS} {
				set passed [update_special_type "EVENT" $ev_id "MBS" $special_langs 0 1 1]
			} else {
				set passed [update_special_type "EVENT" $ev_id "" $special_langs 0 1 1]
			}
			if {!$passed} {set bad  1}
		} msg]} {
			ob_log::write ERROR {Failed to set special type for event: $msg}
			err_bind "Failed to set special type for event: $msg"
			set bad 1
		}
	}
	if {$bad} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ev_upd
		return

	}
	#
	# Update was OK, go back to the event screen in update mode
	#
	tpSetVar EvUpdated 1

	go_ev_upd
}


#
# ----------------------------------------------------------------------------
# Do bulk event update
# ----------------------------------------------------------------------------
#
proc do_evs_upd args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
		return
	}

	if {![op_allowed ManageEv]} {
		err_bind "You don't have permission to update events"
		go_evs_upd
		return
	}

	set aux_user_id ""

	set d_lo        [reqGetArg d_lo]
	set d_hi        [reqGetArg d_hi]
	set l_settled   [reqGetArg Settled]
	set l_status    [reqGetArg Status]
	set l_displayed [reqGetArg Displayed]
	set class_id    [reqGetArg ClassId]

	set start_or_susp 	[reqGetArg start_or_susp]
	set is_bir 	        [reqGetArg is_bir]

	set res [get_evs_to_update\
		$l_settled $l_status $l_displayed $d_lo $d_hi $class_id $start_or_susp $is_bir]

	set numEvents [db_get_nrows $res]

	set bad 0
	set evsUpdated 0

	set sql {
		execute procedure pUpdEv (
			p_adminuser    = ?,
			p_aux_user_id  = ?,
			p_ev_id        = ?,
			p_start_time   = ?,
			p_displayed    = ?,
			p_disporder    = ?,
			p_status       = ?,
			p_mult_key     = ?,
			p_min_bet      = ?,
			p_max_bet      = ?,
			p_ext_key      = ?,
			p_url          = ?,
			p_tax_rate     = ?,
			p_t_bet_cutoff = ?,
			p_suspend_at = ?,
			p_blurb = ?,
			p_channels = ?,
			p_is_off = ?,
			p_calendar = ?,
			p_flags = ?,
			p_do_tran = ?,
			p_bir_delay = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	#
	# If aux confirmation is needed for critical event changes,
	# set the perm_check flag to 1
	#
	set perm_check [OT_CfgGetTrue FUNC_CONF_CRIT_EV_CHNG]

	inf_begin_tran $DB

	for {set i 0} {$i < $numEvents} {incr i} {

		set ev_id     [db_get_col $res $i ev_id]
		set status    [reqGetArg status_$ev_id]
		set bir_delay [reqGetArg bir_delay_$ev_id]

		if {$status==""} {
			continue
		}

		set o_start_time   [db_get_col $res $i start_time]
		set o_displayed    [db_get_col $res $i displayed]
		set o_disporder    [db_get_col $res $i disporder]
		set o_min_bet      [db_get_col $res $i min_bet]
		set o_max_bet      [db_get_col $res $i max_bet]
		set o_mult_key     [db_get_col $res $i mult_key]
		set o_status       [db_get_col $res $i status]
		set o_ext_key      [db_get_col $res $i ext_key]
		set o_url          [db_get_col $res $i url]
		set o_tax_rate     [db_get_col $res $i tax_rate]
		set o_t_bet_cutoff [db_get_col $res $i t_bet_cutoff]
		set o_suspend_at   [db_get_col $res $i suspend_at]
		set o_blurb        [db_get_col $res $i blurb]
		set o_channels     [db_get_col $res $i ev_channels]
		set o_is_off       [db_get_col $res $i is_off]
		set o_flags		   [db_get_col $res $i flags]
		set o_trader_user_id [db_get_col $res $i trader_user_id]
		set o_flags_list [split $o_flags ,]
		set o_bir_delay    [db_get_col $res $i bir_delay]

		if {$o_is_off == "X"} {
			set o_is_off "-"
		}

		set displayed   [reqGetArg displayed_$ev_id]
		set start_time  [string trim [reqGetArg start_time_$ev_id]]
		set disporder   [string trim [reqGetArg disporder_$ev_id]]
		set min_bet     [string trim [reqGetArg min_bet_$ev_id]]
		set max_bet     [string trim [reqGetArg max_bet_$ev_id]]
		set mult_key    [string trim [reqGetArg mult_key_$ev_id]]
		set channels    [make_channel_str CN_ $ev_id]
		set is_off      [string trim [reqGetArg isoff_$ev_id]]
		set calendar    [reqGetArg Calendar]
		set flags_list  [update_flags_list $o_flags_list FL_ $ev_id]
		set trader_user_id [reqGetArg trader_$ev_id]
		if {$calendar != ""} {
			set calendar "Y"
		}

		set flags [join $flags_list ,]

		set changed 0

		if {$o_displayed != $displayed \
		||  $o_status != $status \
		||	$o_start_time != $start_time \
		||  $o_disporder != $disporder \
		||  $o_min_bet != $min_bet \
		||  $o_max_bet != $max_bet \
		||  $o_channels != $channels \
		||  $o_is_off != $is_off \
		||  $o_mult_key != $mult_key\
		||  $o_trader_user_id != $trader_user_id\
		||  $o_flags != $flags \
		||  $o_bir_delay != $bir_delay} {
			set changed 1
		}

		if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

			if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
				err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
				go_evs_upd
				return
			}

		} else {

			if {$bir_delay != "" && $bir_delay < 0 } {
				err_bind "BIR delay value cannot be less than 0"
				go_evs_upd
				return
			}

		}

		if {$changed} {

			if {$perm_check} {
				set do_check 0
				if {$o_start_time != $start_time} {
					set do_check 1
				}
				if {$o_status == "S" && $status == "A"} {
					set do_check 1
				}
				if {$do_check} {
					set r [do_ev_auxconf_check]

					if {[lindex $r 0] != "OK"} {
						err_bind [lindex $r 1]
						set bad 1
						break
					}

					set aux_user_id [lindex $r 1]
				}
				# No need to check permissions again...
				set perm_check 0
			}

			set desc [db_get_col $res $i desc]

			OT_LogWrite 2 "Updating event $ev_id: $desc"

			if {[catch {inf_exec_stmt $stmt\
					$USERNAME \
					$aux_user_id\
					$ev_id \
					$start_time \
					$displayed \
					$disporder \
					$status \
					$mult_key \
					$min_bet \
					$max_bet \
					$o_ext_key \
					$o_url \
					$o_tax_rate \
					$o_t_bet_cutoff \
					$o_suspend_at \
					$o_blurb \
					$channels \
					$is_off \
					$calendar \
					$flags \
					"N" \
					$bir_delay} msg]} {
				set bad 1
				err_bind "$desc: $msg"
				break
			} else {
			  incr evsUpdated
			}
		}
	}

	inf_close_stmt $stmt

	if {$bad==1} {
		inf_rollback_tran $DB
		tpSetVar EventsUpdated 0
		go_evs_upd
		return
	}

	inf_commit_tran $DB
	tpSetVar EventsUpdated $evsUpdated
	go_evs_upd
}



#
# ----------------------------------------------------------------------------
# Event Delete
# ----------------------------------------------------------------------------
#
proc do_ev_del args {

	global DB USERNAME

	set ev_id [reqGetArg EvId]

	set sql [subst {
		execute procedure pDelEv(
			p_adminuser = ?,
			p_ev_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res  [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_id]} msg]} {
		set bad 1
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ev_upd
		return
	}

	ADMIN::EV_SEL::go_ev_sel
}


#
# ----------------------------------------------------------------------------
# Event Confirm/Unconfirm/Settle
# ----------------------------------------------------------------------------
#
proc do_ev_conf args {

	set act [reqGetArg SubmitName]

	if {$act == "EvConf"} {
		do_ev_conf_yn Y
		go_ev_upd
	} elseif {$act == "EvUnconf"} {
		do_ev_conf_yn N
		go_ev_upd
	} elseif {$act == "EvStl"} {
		do_ev_settle
	} elseif {$act == "EvReStl"} {
		do_ev_resettle
	} else {
		error "unexpected action: $act"
	}
}


proc do_ev_conf_yn {conf_yn {ev_id ""}} {

	global DB USERNAME

	if {$ev_id==""} {
	  set ev_id [reqGetArg EvId]
	}


	if {$conf_yn=="Y"} {

		set errors [check_event_dividend_set $ev_id]

		if {$errors != ""} {
			err_bind $errors
			OT_LogWrite 30 "Result confirm attempted for ev_id:$ev_id with forecast/tricast dividends unset"
			return
		}

		# RT1819. If this event has a Handicap market, force the user to set hcap_makeup
		# unless all the selections in that market are void
		# (which is why this is not enforced in a constraint)
		set CanConfHcaps [reqGetArg CanConfHcaps]
		if {$CanConfHcaps !="" && !$CanConfHcaps} {
			set msg "Set handicap result to confirm results for handicap markets"
			err_bind $msg
			OT_LogWrite 30 $msg
			return
		}
	}


	#
	# dividends set, so confirm the markets
	#
	set sql [subst {
		execute procedure pSetResultConf(
			p_adminuser = ?,
			p_obj_type = ?,
			p_obj_id = ?,
			p_conf = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res  [inf_exec_stmt $stmt\
			$USERNAME\
			E\
			$ev_id\
			$conf_yn]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt
	return $bad
}


proc do_ev_settle args {

	global USERNAME

	set errors [check_event_dividend_set [reqGetArg EvId]]
	if {$errors != ""} {
		err_bind $errors
		set mkt_id [reqGetArg MktId]
		go_ev
		return
	}

	tpSetVar StlObj   event
	tpSetVar StlObjId [reqGetArg EvId]
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

proc do_ev_resettle args {

	global USERNAME

	if {![op_allowed ReSettle]} {
		err_bind "You don't have permission to re-settle events"
		go_ev
		return
	} else {
		do_ev_settle
	}

}

#
# ----------------------------------------------------------------------------
# Show results for given event
# ----------------------------------------------------------------------------
#
proc go_show_results args {

	global DB MKTS SELN

	set ev_id   [reqGetArg EvId]
	set class_sort [reqGetArg ClassSort]

	OT_LogWrite 10 "go_show_results: ev_id=$ev_id"

	tpBindString EvId      $ev_id
	tpBindString EvDesc    [reqGetArg EvDesc]
	tpBindString StartTime [reqGetArg StartTime]

	# find all markets for given event

	set mkt_sql [subst {
		select
			m.ev_mkt_id,
			m.name as mkt_name,
			m.type,
			m.sort,
			m.ew_avail,
			m.ew_fac_num,
			m.ew_fac_den,
			m.ew_places,
			m.lp_avail,
			m.sp_avail,
			m.fc_avail,
			m.tc_avail,
			decode(m.auto_dh_redn,'Y',1,0) auto_dh
		from
			tEvMkt   m
		where
			ev_id = ?
		order by
			m.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $mkt_sql]
	set res  [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt
	set mkt_nrows [db_get_nrows $res]

	tpSetVar NumMkts $mkt_nrows
	for {set i 0} {$i < $mkt_nrows} {incr i} {
		set mkt_id     [db_get_col $res $i ev_mkt_id]
		set mkt_name   [db_get_col $res $i mkt_name]

		# note if standard (need to know for Rule 4s)
		set mkt_type   [db_get_col $res $i type]
		if {$mkt_type == "-" && [lsearch [split [OT_CfgGet RULE4_CLASS_LIST HR] "|"] $class_sort] >= 0 } {
			set MKTS($i,rule4) 1

			set r4_sql [subst {
				select
					is_valid,
					market,
					time_from,
					time_to,
					deduction
				from
					tEvMktRule4 d

				where
					d.ev_mkt_id = ?
			}]

			set stmt [inf_prep_sql $DB $r4_sql]
			set r4_res  [inf_exec_stmt $stmt $mkt_id]
			inf_close_stmt $stmt
			set r4_nrows [db_get_nrows $r4_res]

			set MKTS($i,NumR4s) $r4_nrows

			for {set l 0} {$l < $r4_nrows} {incr l} {
				set MKTS($i,$l,is_valid)  [db_get_col $r4_res $l is_valid]
				if {[db_get_col $r4_res $l market] == "L"} {
					set MKTS($i,$l,market) "LP"
				} else {
					set MKTS($i,$l,market)  "SP"
				}
				set MKTS($i,$l,time_from) [db_get_col $r4_res $l time_from]
				set MKTS($i,$l,time_to)   [db_get_col $r4_res $l time_to]
				set MKTS($i,$l,deduction) [db_get_col $r4_res $l deduction]
			}

			tpBindVar IsValid   MKTS is_valid  mkt_idx  r4_idx
			tpBindVar Market    MKTS market    mkt_idx  r4_idx
			tpBindVar TimeFrom  MKTS time_from mkt_idx  r4_idx
			tpBindVar TimeTo    MKTS time_to   mkt_idx  r4_idx
			tpBindVar Deduction MKTS deduction mkt_idx  r4_idx

			db_close $r4_res

		} else {
			set MKTS($i,rule4) 0
		}

		set mkt_sort   [db_get_col $res $i sort]
		if {$mkt_sort == "AH" || $mkt_sort == "WH"} {
			set MKTS($i,handicap) 1
		} else {
			set MKTS($i,handicap) 0
		}

		set ew_avail   [db_get_col $res $i ew_avail]
		if {$ew_avail =="Y"} {
			set MKTS($i,ew) 1
		} else {
			set MKTS($i,ew) 0
		}

		set ew_fac_num [db_get_col $res $i ew_fac_num]
		set ew_fac_den [db_get_col $res $i ew_fac_den]
		set ew_places  [db_get_col $res $i ew_places]
		set auto_dh    [db_get_col $res $i auto_dh]

		# are we offering live/starting prices?
		if {[db_get_col $res $i lp_avail] =="Y"} {
			set MKTS($i,lp) 1
		} else {
			set MKTS($i,lp) 0
		}
		if {[db_get_col $res $i sp_avail] =="Y"} {
			set MKTS($i,sp) 1
		} else {
			set MKTS($i,sp) 0
		}

		# are we offering forecast/tricasts?
		set fc_tc 0
		if {[db_get_col $res $i fc_avail] =="Y"} {
			set MKTS($i,fc) 1
			set fc_tc 1
		} else {
			set MKTS($i,fc) 0
		}
		if {[db_get_col $res $i tc_avail] =="Y"} {
			set MKTS($i,tc) 1
			set fc_tc 1
		} else {
			set MKTS($i,tc) 0
		}
		set MKTS($i,fc_tc) $fc_tc

		# get dividends for forecasts/tricasts
		set MKTS($i,NumDivs) 0
		if {$fc_tc > 0} {
			set fc_sql [subst {
				select
					d.type,
					d.seln_1,
					s1.desc desc_1,
					d.seln_2,
					s2.desc desc_2,
					d.seln_3,
					s3.desc desc_3,
					d.dividend
				from
					tDividend   d,
					tEvOc       s1,
					outer tEvOc s2,
					outer tEvOc s3
				where
					d.ev_mkt_id = ? and
					d.seln_1 = s1.ev_oc_id and
					d.seln_2 = s2.ev_oc_id and
					d.seln_3 = s3.ev_oc_id
				order by
					2,1
			}]

			set stmt [inf_prep_sql $DB $fc_sql]
			set fc_res  [inf_exec_stmt $stmt $mkt_id]
			inf_close_stmt $stmt
			set div_nrows [db_get_nrows $fc_res]

			set MKTS($i,NumDivs) $div_nrows

			for {set k 0} {$k < $div_nrows} {incr k} {
				set type      [db_get_col $fc_res $k type]
				switch -- $type {
					TW {
						set type "Tote win"
						}
					TP {
						set type "Tote place"
						}
					FC {
						set type "Forecast"
						}
					default {
						set type "Tricast"
						}
				}

				set desc_1    [db_get_col $fc_res $k desc_1]
				set desc_2    [db_get_col $fc_res $k desc_2]
				set desc_3    [db_get_col $fc_res $k desc_3]
				set dividend  [db_get_col $fc_res $k dividend]

				set MKTS($i,$k,type)   $type
				set MKTS($i,$k,desc_1) $desc_1
				set MKTS($i,$k,desc_2) $desc_2
				set MKTS($i,$k,desc_3) $desc_3
				set MKTS($i,$k,dividend) $dividend
			}

			tpBindVar DivType   MKTS type     mkt_idx  div_idx
			tpBindVar Desc1     MKTS desc_1   mkt_idx  div_idx
			tpBindVar Desc2     MKTS desc_2   mkt_idx  div_idx
			tpBindVar Desc3     MKTS desc_3   mkt_idx  div_idx
			tpBindVar Dividend  MKTS dividend mkt_idx  div_idx

			db_close $fc_res
		}

		# get the rest of the market info
		set MKTS($i,mkt_name) $mkt_name
		set MKTS($i,mkt_type) $mkt_type
		set MKTS($i,mkt_sort) $mkt_sort
		set MKTS($i,ew_avail) $ew_avail
		set MKTS($i,ew_fac_num) $ew_fac_num
		set MKTS($i,ew_fac_den) $ew_fac_den
		set MKTS($i,ew_places)  $ew_places

		if {$mkt_sort != "CW"} {

		# find all selections for given market
		set seln_sql [subst {
			select
				o.ev_oc_id,
				o.desc,
				o.result,
				NVL(o.place,'-') as place,
				o.hcap_score,
				o.lp_num,
				o.lp_den,
				o.sp_num,
				o.sp_den
			from
				tEvOc o
			where
				o.ev_mkt_id = ? and
				o.result in ('W','P','H','V','U')
			order by
				 place, o.result desc
		}]

		} else {

		set seln_sql [subst {
			select
				i.mkt_bir_idx,
				i.bir_index as place,
				i.ev_mkt_id,
				r.ev_oc_id,
				r.result,
				o.desc,
				o.hcap_score,
				o.lp_num,
				o.lp_den,
				o.sp_num,
				o.sp_den
			from
				tMktBirIdx i,
				tMktBirIdxRes r,
				tEvOc o
			where
				i.mkt_bir_idx = r.mkt_bir_idx and
				i.ev_mkt_id = ? and
				i.result_conf = 'Y' and
				o.ev_oc_id = r.ev_oc_id
		}]

		}

		# check that the loading of dead heat
		# reductions was successful
		set do_auto_dh [expr {[OT_CfgGet FUNC_AUTO_DH 0] ? $auto_dh : 0}]
		if {![ob_dh_redn::load "M" $mkt_id $do_auto_dh 1 0]} {
			err_bind [ob_dh_redn::get_err]
		}

		array set DH [ob_dh_redn::get_all]

		set stmt [inf_prep_sql $DB $seln_sql]
		set seln_res  [inf_exec_stmt $stmt $mkt_id]
		inf_close_stmt $stmt
		set seln_nrows [db_get_nrows $seln_res]

		set MKTS($i,NumSeln) $seln_nrows
		set MKTS($i,win_redn) 0
		set MKTS($i,pl_redn) 0

		for {set j 0} {$j < $seln_nrows} {incr j} {
			set seln_desc      [db_get_col $seln_res $j desc]
			set result         [db_get_col $seln_res $j result]
			set place          [db_get_col $seln_res $j place]
			set hcap_score     [db_get_col $seln_res $j hcap_score]
			set lp_num         [db_get_col $seln_res $j lp_num]
			set lp_den         [db_get_col $seln_res $j lp_den]
			set sp_num         [db_get_col $seln_res $j sp_num]
			set sp_den         [db_get_col $seln_res $j sp_den]
			set ev_oc_id       [db_get_col $seln_res $j ev_oc_id]

			set MKTS($i,$j,seln_desc) $seln_desc
			set MKTS($i,$j,result)    $result
			set MKTS($i,$j,place)     $place
			set MKTS($i,$j,hcap_score) $hcap_score

			set MKTS($i,$j,lp_price) [mk_price $lp_num $lp_den]
			set MKTS($i,$j,sp_price) [mk_price $sp_num $sp_den]

			# Dead Heat Reductions
			foreach dh_type {W P} {

				set MKTS($i,$j,${dh_type}_dh) [list]

				foreach dh_key [array names DH $dh_type,$ev_oc_id,0,*,dh_num] {

					regexp {^\w*,\w*,\w*,\w*} $dh_key dh_key

					set dh_num $DH($dh_key,dh_num)
					set dh_den $DH($dh_key,dh_den)

					# ignore even reductions
					if {$dh_num == $dh_den} {
						continue
					}

					lappend MKTS($i,$j,${dh_type}_dh) [mk_price $dh_num $dh_den]
				}

				set MKTS($i,$j,${dh_type}_dh) [join $MKTS($i,$j,${dh_type}_dh) ","]

				if {$MKTS($i,$j,${dh_type}_dh) != ""} {
					set MKTS($i,${dh_type}_dh) 1
				}
			}

		}

		tpBindVar SelnDesc    MKTS seln_desc      mkt_idx  seln_idx
		tpBindVar Result      MKTS result         mkt_idx  seln_idx
		tpBindVar Place       MKTS place          mkt_idx  seln_idx
		tpBindVar HcapScore   MKTS hcap_score     mkt_idx  seln_idx
		tpBindVar LpPrice     MKTS lp_price       mkt_idx  seln_idx
		tpBindVar SpPrice     MKTS sp_price       mkt_idx  seln_idx
		tpBindVar WinRedPrice MKTS W_dh           mkt_idx  seln_idx
		tpBindVar PlRedPrice  MKTS P_dh           mkt_idx  seln_idx

		db_close $seln_res

	}

	tpBindVar MktName  MKTS mkt_name    mkt_idx
	tpBindVar MktType  MKTS mkt_type    mkt_idx
	tpBindVar MktRule4 MKTS rule4       mkt_idx
	tpBindVar MktSort  MKTS mkt_sort    mkt_idx
	tpBindVar Handicap MKTS handicap    mkt_idx
	tpBindVar EwAvail  MKTS ew_avail    mkt_idx
	tpBindVar EW       MKTS ew          mkt_idx
	tpBindVar EwFacNum MKTS ew_fac_num  mkt_idx
	tpBindVar EwFacDen MKTS ew_fac_den  mkt_idx
	tpBindVar EwPlaces MKTS ew_places   mkt_idx
	tpBindVar LP       MKTS lp          mkt_idx
	tpBindVar SP       MKTS sp          mkt_idx
	tpBindVar FC       MKTS fc          mkt_idx
	tpBindVar TC       MKTS tc          mkt_idx
	tpBindVar FC_TC    MKTS fc_tc       mkt_idx

	db_close $res

	asPlayFile -nocache quick_evt_results.html

	catch {unset MKTS}

}

proc get_sort {ev_type_id} {
	global DB

	set sql {
		select
			sort
		from
			tEvClass c,
			tEvType t
		where
			t.ev_class_id = c.ev_class_id and
			t.ev_type_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_type_id]
	inf_close_stmt $stmt

	set sort [db_get_col $res sort]

	db_close $res

	return $sort
}

#
#check all the markets for ev_id to see if dividends have been set
#for those markets allowing forecasts and/or tricasts
#
proc check_event_dividend_set {ev_id} {

	global DB

	set sql [subst {
		select
			m.ev_mkt_id,
			m.fc_avail,
			m.tc_avail,
			g.name

		from
			tEvMkt m,
			tEvOcGrp g
		where
			m.ev_id = ? and
			m.ev_oc_grp_id = g.ev_oc_grp_id
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	set errors ""
	for {set i 0} {$i < $nrows} {incr i} {

		set ev_mkt_id [db_get_col $res $i ev_mkt_id]
		if {[db_get_col $res $i fc_avail] == "Y" && ![ADMIN::MARKET::check_dividend_set $ev_mkt_id "FC"]} {
			append errors "<BR> &nbsp;&nbsp;&nbsp;&nbsp;Can't confirm/settle results until forecast dividends are set for: [db_get_col $res $i name]"

		}
		if {[db_get_col $res $i tc_avail] == "Y" && ![ADMIN::MARKET::check_dividend_set $ev_mkt_id "TC"]} {
			append errors "<BR> &nbsp;&nbsp;&nbsp;&nbsp;Can't confirm/settle results until tricast dividends are set for: [db_get_col $res $i name]"
		}
	}

	return $errors
}



proc do_clear_ev {} {
	global DB
	global MKTS

	set ev_id [reqGetArg EvId]
	OT_LogWrite 16 {in do_clear_ev(ev_id=$ev_id)}

	# clear this event, mkts and selns (if possible)
	set sql {
	execute procedure pClearEv (p_ev_id=?)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $ev_id
	inf_close_stmt $stmt

	# get all the mkt info
	set sql {
	select g.name name, m.ev_mkt_id mkt_id, m.settled settled
	from   tEv e, tEvMkt m, tEvOcGrp g
	where  e.ev_id = ?
	and    e.ev_id = m.ev_id
	and    m.ev_oc_grp_id = g.ev_oc_grp_id
	order by m.settled desc, g.name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt

	set MKTS(num_mkts) [set nrows [db_get_nrows $rs]]

	for {set i 0} {$i < $nrows} {incr i} {
	foreach field {name mkt_id settled} {
		set MKTS($i,$field) [db_get_col $rs $i $field]
	}
	}

	db_close $rs

	tpBindVar MktName MKTS name   mkt_idx
	tpBindVar MktId   MKTS mkt_id mkt_idx

	tpBindString EvId $ev_id

	asPlayFile -nocache clear_event.html
}

proc do_ltl_upd {{bet_in_run "-"} {call_back_func "go_ev_upd"}} {

	global DB USERNAME

	if {[OT_CfgGet FUNC_LAY_TO_LOSE 0] != 1} {
		eval $call_back_func
		return
	}

	set ev_id         [reqGetArg EvId]
	set least_max_bet [reqGetArg LeastMaxBet]
	set most_max_bet  [reqGetArg MostMaxBet]
	#Get lay to lose from req. Otherwise default to evmaxlaytolose
	set lay_to_lose   [reqGetArg LayToLose]
	set type_id       [reqGetArg TypeId]


	# if least_max_bet, most_max_bet and lay_to_lose are all
	# empty then do nothing
	set flag 0
	if {![info exists least_max_bet] || $least_max_bet == ""} {
		incr flag
		# if least max bet doesn't exist then deafult it to zero
		set least_max_bet 0
	}
	# nomaxbet bet records whether most max bet field is empty
	# this is used when displaying the correct acknowledgement message
	set nomaxbet 0
	if {![info exists most_max_bet] || $most_max_bet == ""} {
		incr flag
		set nomaxbet 1
	}
	if {![info exists lay_to_lose] || $lay_to_lose == ""} {
		incr flag
	}
	if {$flag == 3} {
		if {$call_back_func != ""} {
			err_bind "Nothing has been updated as all lay to lose fields were empty"
			eval $call_back_func
			return
		} else {
			error "Nothing has been updated as all lay to lose fields were empty"
		}
	}

	# check that our values are numeric -- allow aaaaa and aaaaa.bb and null
	set elist [ list ]
	if { [valid_input $least_max_bet] == 1 } {
	} else {
		lappend elist "least max bet"
	}
	if { [valid_input $most_max_bet] == 1 } {
	} else {
		lappend elist "most max bet"
	}
	if { [valid_input $lay_to_lose] == 1 } {
	} else {
		lappend elist "lay to lose"
	}
	if { [llength $elist] != 0 } {
		set estr [join $elist ", "]
		if {$call_back_func != ""} {
			err_bind "Re enter values for $estr"
			eval $call_back_func
			return
		} else {
			error "Re enter values for $estr"
		}
	}

	# check for sensible values
	if {$least_max_bet < 0} {set least_max_bet 0}
	if {$most_max_bet != ""} {
		if {$most_max_bet < 0} {set most_max_bet 0}
		if {$most_max_bet < $least_max_bet} {
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			if {$call_back_func != ""} {
				err_bind "Most max bet cannot be less than least max bet."
				eval $call_back_func
				return
			} else {
				error "Most max bet cannot be less than least max bet."
			}
		}
	}
	if {$lay_to_lose != ""} {
		if {$lay_to_lose < 0} {
			set lay_to_lose 0
		}
	}

	# add the max bet values into tLayToLoseEv
	set sql [subst {
		execute procedure pUpdLaytoloseEv(
			p_adminuser = ?,
			p_ev_id = ?,
			p_least_max_bet = ?,
			p_lay_to_lose = ?,
			p_most_max_bet = ?
		)
	}]

	set bad 0
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_id\
			$least_max_bet\
			$lay_to_lose\
			$most_max_bet]} msg]} {

		if {$call_back_func != ""} {
			set bad 1
			err_bind $msg
		} else {
			catch {inf_close_stmt $stmt}
			catch {db_close $res}
			error $msg
		}
	}
	inf_close_stmt $stmt

	if {!$bad} {
		# determine the markets for this particular event
		set sql_mkt [subst {
			select
			  m.ev_mkt_id,
			  l.win_lp,
			  l.win_sp,
			  l.place_lp,
			  l.place_sp,
			  g.event_lmb,
			  g.event_mmb,
			  g.event_ltl
			from
			  tEvMkt m,
			  outer tLayToLose l,
			  tEvOcGrp g
			where
			  m.ev_id = $ev_id and
			  m.ev_oc_grp_id = g.ev_oc_grp_id and
			  l.ev_mkt_id = m.ev_mkt_id
		}]

		if {$bet_in_run != "-"} {
			append sql_mkt " and m.bet_in_run = '$bet_in_run'"
		}

		set stmt_mkt [inf_prep_sql $DB $sql_mkt]
		set rs_mkt   [inf_exec_stmt $stmt_mkt]
		set nrows    [db_get_nrows $rs_mkt]

		# get type level info
		set sql [subst {
			select
			  ltl_win_lp,
			  ltl_win_sp,
			  ltl_place_lp,
			  ltl_place_sp
			from tEvType
			where ev_type_id = $type_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt]

		set ltl_win_lp   [db_get_col $res 0 ltl_win_lp]
		set ltl_win_sp   [db_get_col $res 0 ltl_win_sp]
		set ltl_place_lp [db_get_col $res 0 ltl_place_lp]
		set ltl_place_sp [db_get_col $res 0 ltl_place_sp]
		inf_close_stmt $stmt
		db_close $res

		for {set n 0} {$n < $nrows} {incr n} {
			set ev_mkt_id [db_get_col $rs_mkt $n ev_mkt_id]
			set win_lp    [db_get_col $rs_mkt $n win_lp]
			set win_sp    [db_get_col $rs_mkt $n win_sp]
			set place_lp  [db_get_col $rs_mkt $n place_lp]
			set place_sp  [db_get_col $rs_mkt $n place_sp]
			set event_lmb [db_get_col $rs_mkt $n event_lmb]
			set event_mmb [db_get_col $rs_mkt $n event_mmb]
			set event_ltl [db_get_col $rs_mkt $n event_ltl]

			if { $event_lmb == "" } { set event_lmb 100 }
			if { $event_mmb == "" } { set event_mmb 100 }
			if { $event_ltl == "" } { set event_ltl 100 }

			if {$most_max_bet == "" || $most_max_bet == 0} {
				set maxval [max $win_lp [max $win_sp [max $place_lp $place_sp]]]
				set most_max_bet $maxval
			}

			if {$most_max_bet == ""} {
				if {$lay_to_lose != ""} {
					set most_max_bet $lay_to_lose
				} elseif {$ltl_place_sp != ""} {
					set most_max_bet $ltl_place_sp
				} else {
					set most_max_bet $ltl_win_lp
				}
			}

			set mkt_least_max_bet [expr double($least_max_bet) / 100 * $event_lmb]

			if {$most_max_bet != ""} {
				set mkt_most_max_bet  [expr double($most_max_bet) / 100 * $event_mmb]
			} else {
				set mkt_most_max_bet  ""
			}

			set mkt_least_max_bet [expr double($least_max_bet) / 100 * $event_lmb]

			################### This might be the bone of contention ###############
			if {$lay_to_lose != ""} {
				set mkt_lay_to_lose   [expr double($lay_to_lose) / 100 * $event_ltl]
				foreach c {
					win_lp
					win_sp
					place_lp
					place_sp
				} {
					set $c $mkt_lay_to_lose
				}
				OT_LogWrite 5 "Applying percentage of event ltl to market. New mkt lay to lose will be $mkt_lay_to_lose"
			}
			############################End of bone of contention ##############################

			if { $mkt_most_max_bet < $mkt_least_max_bet } {
				OT_LogWrite 2 "After applying ev_oc_grp ltl percentages, most max bet ($mkt_most_max_bet) is \
											less than least max bet ($mkt_least_max_bet), mmb set to lmb"
				set mkt_most_max_bet $mkt_least_max_bet
			}

			set sql {execute procedure pLayToLose(\
					  p_ev_mkt_id = ?,\
					  p_win_lp = ?,\
					  p_win_sp = ?,\
					  p_place_lp = ?,\
					  p_place_sp = ?,\
					  p_t_win_lp = ?,\
					  p_t_win_sp = ?,\
					  p_t_place_lp = ?,\
					  p_t_place_sp = ?,\
					  p_min_bet = ?,\
					  p_max_bet = ?\
			)}
			set stmt [inf_prep_sql $DB $sql ]
			set res  [inf_exec_stmt $stmt $ev_mkt_id $win_lp $win_sp \
						  $place_lp $place_sp $ltl_win_lp $ltl_win_sp \
						  $ltl_place_lp $ltl_place_sp $mkt_least_max_bet \
						  $mkt_most_max_bet]

			inf_close_stmt $stmt
			db_close $res
		}
		inf_close_stmt $stmt_mkt
		db_close $rs_mkt
	}

	if {$bad} {
		#
		# Something went wrong : go back to the event with the form elements
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		eval $call_back_func
		return
	} else {
		# write the appropriate messages dependent upon what has been changed
		set message [list]
		if { $lay_to_lose == "" } {
			if {$nrows == 0} {
				lappend message  "There are no markets for this event or no markets exist for which \
					lay to lose values have been specified."
			} else {
				if {$nomaxbet} {
					lappend message "Most max bet and lay to lose values were not specified. Therefore \
						lay to lose values will remain unchanged in all markets for this event."
					lappend message "Most max bet for each market has been set to the greatest lay to lose value \
						for that specific market."
				} else {
					lappend message "Lay to lose value was not specified. Therefore only markets that \
						have at least one lay to lose value specified, will have their least and most \
						max bet values updated."
				}
			}
		} else {
			if {$bet_in_run == "N"} {
				set bir "Pre-Match"
			} else {
				set bir "BIR"
			}
			if {$nrows == 0} {

				err_bind "There are no $bir markets for this event."
			} else {
				lappend message "Lay to lose and max bet values for all $bir markets of this event have been updated."
				if {$nomaxbet} {
					lappend message "Most max bet was not specified so it has been set to $most_max_bet \
						which is the value specified for lay to lose."
				}
			}
		}
		msg_bind [join $message "<br/>"]
		eval $call_back_func
	}
}

proc do_liab_upd {{call_back_func "go_ev_upd"}} {

	global DB USERNAME

	set ev_id [reqGetArg EvId]
	set liability [reqGetArg Liability]

	# if liability is empty then do nothing
	if {![info exists ev_id] || $liability == ""} {
		if {$call_back_func != ""} {
			err_bind "Nothing has been updated as liability limit field was empty"
			eval $call_back_func
			return
		} else {
			error "Nothing has been updated as liability limit field was empty"
		}
	}

	# check that liability is numeric
	if { [valid_input $liability] == 0 } {
		if {$call_back_func != ""} {
			err_bind "Re enter value for liability limit"
			eval $call_back_func
			return
		} else {
			error "Re enter value for liability limit"
		}
	}

	# check for sensible value
	if {$liability < 0} {set liability 0}

	# add the liability limit to tLayToLoseEv
	set sql_liab [subst {
		execute procedure pUpdLiabLimitEv(
			p_adminuser = ?,
			p_ev_id = ?,
			p_liability = ?
		)
	}]
	set bad 0
	set stmt_liab [inf_prep_sql $DB $sql_liab]
	if {[catch {
		set res_liab [inf_exec_stmt $stmt_liab\
			$USERNAME\
			$ev_id\
			$liability]} msg]} {

		if {$call_back_func != ""} {
			set bad 1
			err_bind $msg
		} else {
			catch {inf_close_stmt $stmt_liab}
			catch {db_close $res_liab}
			error $msg
		}
	}
	inf_close_stmt $stmt_liab
	db_close $res_liab

	if {$bad} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		eval $call_back_func
		return
	} else {
		msg_bind "Liability limits for all markets of this event have been updated"
		eval $call_back_func
	}
}

# simple procedure for validating inputs. null values are valid
proc valid_input {input args} {
	if { [ regexp {^([0-9]+\.)?[0-9]*$} $input match ] == 1 } {
		return 1
	} else { return 0 }
}



# Update the display properties of all bir markets on the event
#
proc upd_bir_display {} {

	global DB

	set sql {
		update
			tEvMkt
		set
			displayed = ?
		where
			ev_id      = ? and
			bet_in_run = 'Y'
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt [reqGetArg Displayed] [reqGetArg EvId]
	inf_close_stmt $stmt

	tpSetVar EvUpdated 1

	go_ev_upd

}

proc bind_trader_data { traders_group } {

	global TRADERS DB

	set sql {
		select
			ug.user_id,
			u.username
		from
			tAdminUserGroup ug,
			tAdminGroup g,
			tAdminUser u
		where
			g.group_name = ? and
			ug.group_id = g.group_id and
			u.user_id = ug.user_id
		}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $traders_group]
	inf_close_stmt $stmt

	set nusers [db_get_nrows $res]
	tpSetVar NumTraders $nusers

	for {set user 0} {$user < $nusers} {incr user} {
		set TRADERS($user,id)   [db_get_col $res $user user_id]
		set TRADERS($user,name) [db_get_col $res $user username]
	}

	db_close $res

	tpBindVar TraderID   TRADERS id   trader_idx
	tpBindVar TraderName TRADERS name trader_idx
	tpSetVar  PERM_AssignTrader 1

}


# Get the value of BIR delay from hierarchy
#
proc get_bir_hierarchy {res row} {
	if {[db_get_col $res [tpGetVar $row] bir_delay] != ""} {
		tpBufWrite ""
	} else {
		set bir_delay "[db_get_col $res [tpGetVar $row] bir_hierarchy_value] sec from [db_get_col $res [tpGetVar $row] bir_hierarchy_level]"
		tpBufWrite $bir_delay
	}

}


# close namespace now
}
