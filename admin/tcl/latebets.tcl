# ==============================================================
# $Id: latebets.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::LATEBET {


asSetAct ADMIN::LATEBET::VoidLateBets [namespace code show_void_late_bets]
asSetAct ADMIN::LATEBET::VoidOption   [namespace code show_void_option]



#
# Displays date range and drill down for user to select an event.
#
proc show_void_late_bets args {

	global DB
	global EVENTINFO

	set date_from       [reqGetArg date_from]
	set date_to         [reqGetArg date_to]
	set category        [reqGetArg category]
	set class           [reqGetArg class]
	set type            [reqGetArg type]
	set event           [reqGetArg event]
	set market          [reqGetArg market]
	set show_markets    0
	set show_selections 0

	#
	# If a date update has been performed then clear any passed arguements
	#

	switch [reqGetArg SubmitName] {
		"category" {
			set class ""
			set type  ""
			set event ""
		}
		"class"    {
			set type  ""
			set event ""
		}
		"type"     {
			set event ""
		}
		"UpdateDateRange" {
			foreach key { "category" "class" "type" "event" } {
				set $key ""
			}
		}
		"showMarkets" {
			set show_markets 1
		}
		"showSelections" {
			set show_selections 1
		}
		"voidConfirm" {
			show_void_confirm
			return
		}
		"voidOption" {
			show_void_option
			return
		}
		"doVoid" {
			do_void
			return
		}
		default {}
	}

	set disable_class "disabled"
	set disable_type  "disabled"
	set disable_event "disabled"
	set num_class     0
	set num_type      0
	set num_event     0
	set num_market    0
	set num_selection 0

	set start_time_clause [mk_between_clause " AND e.start_time" "date" $date_from $date_to]
	#
	# Get list of available categories, classes, types & event
	#
	set num_cat [bind_categories $category $start_time_clause]

	# If Category is set then get classes
	if {$category != "" && $num_cat != 0} {
		set num_class [bind_classes $category $class $start_time_clause]
		set disable_class "enabled"
	}

	# If class is set then get type
	if {$class != "" && $num_class != 0} {
		set num_type [bind_types $class $type $start_time_clause]
		set disable_type "enabled"
	}

	set start_time_clause [mk_between_clause " AND start_time" "date" $date_from $date_to]

	# If type is set then get events
	if {$type != "" && $num_type != 0} {
		set num_event [bind_events $type $event $start_time_clause]
		set disable_event "enabled"
	}


	if {$show_markets == 1} {
		bind_markets $event $show_markets
	}


	if {$show_selections == 1} {
		bind_selections $market $show_selections
	}


	tpBindString DATE_FROM $date_from
	tpBindString DATE_TO   $date_to

	tpBindString DISABLE_CLASS  $disable_class
	tpBindString DISABLE_TYPE   $disable_type
	tpBindString DISABLE_EVENT  $disable_event


	asPlayFile void_late_bets.html
}


#
# Selection of bind procs to build the drop dows menus & market / sel display
#
proc bind_categories {category start_time_clause} {

	global EVENTINFO
	global DB

	set cat_sql [subst {
		select
			c.ev_category_id,
			c.category
		from
			tEvCategory c
		where
			c.displayed   = 'Y'           AND
			exists (
				select
					e.ev_id
				from
					tEvClass l,
					tEv      e
				where
					c.category    = l.category    AND
					l.ev_class_id = e.ev_class_id
					$start_time_clause
			)
		order by
			1
	}]

	set stmt    [inf_prep_sql $DB $cat_sql]
	set cat_rs  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_cat [db_get_nrows $cat_rs]

	for {set i 0} {$i < $num_cat} {incr i} {

		set EVENTINFO($i,category,cat_id)   [db_get_col $cat_rs $i ev_category_id]
		set EVENTINFO($i,category,category) [db_get_col $cat_rs $i category]

		if {$EVENTINFO($i,category,cat_id) == $category} {
			tpBindString SEL_CAT_ID $EVENTINFO($i,category,cat_id)
		}
	}

	tpSetVar     numCat         $num_cat
	tpBindVar    CAT_ID         EVENTINFO   "category,cat_id"    cat_idx
	tpBindVar    CATEGORY       EVENTINFO   "category,category"  cat_idx

	return $num_cat
}


proc bind_classes {category class start_time_clause} {

	global EVENTINFO
	global DB

	set class_sql [subst {
		select
			l.disporder,
			l.ev_class_id,
			l.name
		from
			tEvCategory c,
			tEvClass    l
		where
			c.ev_category_id = $category           AND
			l.category       = c.category    AND
			l.displayed      = 'Y'           AND
			exists (
				select
					ev_id
				from
					tEv e
				where
					l.ev_class_id    = e.ev_class_id
					$start_time_clause
			)
		order by
			1
	}]

	set stmt     [inf_prep_sql $DB $class_sql]
	set class_rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_class [db_get_nrows $class_rs]

	for {set i 0} {$i < $num_class} {incr i} {
		set EVENTINFO($i,class,class_id) [db_get_col $class_rs $i ev_class_id]
		set EVENTINFO($i,class,class)    [db_get_col $class_rs $i name]

		if {$EVENTINFO($i,class,class_id) == $class} {
			tpBindString SEL_CLASS_ID $EVENTINFO($i,class,class_id)
		}
	}

	tpSetVar     numClass       $num_class
	tpBindVar    CLASS_ID       EVENTINFO   "class,class_id"     class_idx
	tpBindVar    CLASS          EVENTINFO   "class,class"        class_idx

	return $num_class
}


proc bind_types {class type start_time_clause} {

	global EVENTINFO
	global DB

	set type_sql [subst {
		select
			t.disporder,
			t.ev_type_id,
			t.name
		from
			tEvType  t
		where
			t.ev_class_id = $class   AND
			t.displayed   = 'Y'      AND
			exists (
				select
					ev_id
				from
					tEv e
				where
					t.ev_type_id  = e.ev_type_id
					$start_time_clause
			)
		order by
			1
	}]

	set stmt     [inf_prep_sql $DB $type_sql]
	set type_rs  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_type [db_get_nrows $type_rs]

	for {set i 0} {$i < $num_type} {incr i} {
		set EVENTINFO($i,type,type_id) [db_get_col $type_rs $i ev_type_id]
		set EVENTINFO($i,type,type)    [db_get_col $type_rs $i name]

		if {$EVENTINFO($i,type,type_id) == $type} {
			tpBindString SEL_TYPE_ID $EVENTINFO($i,type,type_id)
		}
	}

	tpSetVar     numType        $num_type
	tpBindVar    TYPE_ID        EVENTINFO   "type,type_id"       type_idx
	tpBindVar    TYPE           EVENTINFO   "type,type"          type_idx

	return $num_type

}


proc bind_events {type event start_time_clause} {

	global EVENTINFO
	global DB

	set event_sql [subst {
		select unique
			disporder,
			ev_id,
			desc as name
		from
			tEv
		where
			ev_type_id  =  $type
			$start_time_clause
		order by
			1
	}]

	set stmt     [inf_prep_sql $DB $event_sql]
	set event_rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_event [db_get_nrows $event_rs]

	for {set i 0} {$i < $num_event} {incr i} {
		set EVENTINFO($i,event,event_id) [db_get_col $event_rs $i ev_id]
		set EVENTINFO($i,event,event)    [db_get_col $event_rs $i name]

		if {$EVENTINFO($i,event,event_id) == $event} {
			tpBindString SEL_EVENT_ID $EVENTINFO($i,event,event_id)
		}
	}


	tpSetVar     numEvent       $num_event
	tpBindVar    EVENT_ID       EVENTINFO   "event,event_id"     event_idx
	tpBindVar    EVENT          EVENTINFO   "event,event"        event_idx

	return $num_event

}


proc bind_markets {event show_markets} {

	global EVENTINFO
	global DB

	set market_sql [subst {
		select unique
			m.disporder,
			m.ev_mkt_id,
			m.settled,
			g.name
		from
			tEvMkt   m,
			tEvOcGrp g
		where
			m.ev_id = $event AND
			m.ev_oc_grp_id = g.ev_oc_grp_id
		order by
			1
	}]


	set stmt      [inf_prep_sql $DB $market_sql]
	set market_rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_market [db_get_nrows $market_rs]

	for {set i 0} {$i < $num_market} {incr i} {
		set EVENTINFO($i,market,market_id) [db_get_col $market_rs $i ev_mkt_id]
		set EVENTINFO($i,market,market)    [db_get_col $market_rs $i name]

		if {[db_get_col $market_rs $i settled] == "Y"} {
			set EVENTINFO($i,market,settled) "Settled"
		} else {
			set EVENTINFO($i,market,settled) "Unsettled"
		}
	}

	tpSetVar     numMarket      $num_market
	tpSetVar     showMarkets    $show_markets
	tpBindVar    MARKET_ID      EVENTINFO   "market,market_id"   market_idx
	tpBindVar    MARKET         EVENTINFO   "market,market"      market_idx
	tpBindVar    MARKET_SETTLED EVENTINFO   "market,settled"     market_idx
}


proc bind_selections {market show_selections} {

	global EVENTINFO
	global DB

	set selection_sql [subst {
		select unique
			disporder,
			ev_oc_id,
			desc as name
		from
			tEvOc
		where
			ev_mkt_id = $market
		order by
			1
	}]


	set stmt         [inf_prep_sql $DB $selection_sql]
	set selection_rs [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_selection [db_get_nrows $selection_rs]

	for {set i 0} {$i < $num_selection} {incr i} {
		set EVENTINFO($i,selection,selection_id) [db_get_col $selection_rs $i ev_oc_id]
		set EVENTINFO($i,selection,selection)    [db_get_col $selection_rs $i name]
	}

	tpBindString SEL_MARKET_ID $market
	tpSetVar     numSelection   $num_selection
	tpSetVar     showSelections $show_selections
	tpBindVar    SELECTION_ID   EVENTINFO   "selection,selection_id"   selection_idx
	tpBindVar    SELECTION      EVENTINFO   "selection,selection"      selection_idx
}



#
# This proc build the specific Market / Selection page depending on
#   where the user has 'drileld down' to.
#
proc show_void_option args {

	global DB
	global OPTIONINFO

	set category  [reqGetArg category]
	set class     [reqGetArg class]
	set type      [reqGetArg type]
	set event     [reqGetArg event]
	set market    [reqGetArg market]
	set selection [reqGetArg selection]

	set parts [list category class type event market]

	#
	# Sets psrticulars to SQL if selection / market
	#
	if {$selection != ""} {
		set select ", o.desc as selection_name"
		set from   ", tEvOc o"
		set where  "AND o.ev_oc_id = $selection"
		lappend parts "selection"
		tpSetVar ShowSelection 1
	} else {
		set select ""
		set from   ""
		set where  ""
	}


	set sql [subst {
		select
			c.category as category_name,
			l.name     as class_name,
			t.name     as type_name,
			e.desc     as event_name,
			e.start_time,
			g.name     as market_name
			$select
		from
			tEvCategory c,
			tEvClass    l,
			tEvType     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    g
			$from
		where
			c.ev_category_id = $category      AND
			l.ev_class_id    = $class         AND
			t.ev_type_id     = $type          AND
			e.ev_id          = $event         AND
			m.ev_mkt_id      = $market        AND
			g.ev_oc_grp_id   = m.ev_oc_grp_id
			$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_row [db_get_nrows $rs]


	foreach name $parts {
		tpBindString [string toupper $name]_ID [set $name]
		tpBindString [string toupper $name] [db_get_col $rs 0 ${name}_name]
	}
	tpBindString START_TIME [db_get_col $rs 0 start_time]

	tpBindString DATE_FROM  [reqGetArg date_from]
	tpBindString DATE_TO    [reqGetArg date_to]


	asPlayFile void_option.html

}


#
# Displays a summery of the bets that would be void if this action
#   is pursued. Give the user the choice of voiding the bets or
#   returning to previous screen.
#
proc show_void_confirm args {

	global DB
	global BETINFO

	set category  [reqGetArg category]
	set class     [reqGetArg class]
	set type      [reqGetArg type]
	set event     [reqGetArg event]
	set market    [reqGetArg market]
	set selection [reqGetArg selection]
	set date_from [reqGetArg date_from]
	set date_to   [reqGetArg date_to]


	array set BETINFO [list]
	set bet_ids [list]
	set parts [list category class type event market]

	set cr_date_clause [mk_between_clause " AND b.cr_date" "date" $date_from $date_to]

	#
	# Sets psrticulars to SQL if selection / market
	#
	if {$selection != ""} {
		set where  "AND o.ev_oc_id = $selection"
		lappend parts "selection"
	} else {
		set where  ""
	}


	set sql [subst {
		select
			b.bet_id,
			b.receipt,
			b.cr_date,
			e.ev_id,
			e.desc as event,
			m.ev_mkt_id,
			g.name as market
		from
			tBet     b,
			tOBet    o,
			tEvOc    c,
			tEv      e,
			tEvMkt   m,
			tEvOcGrp g
		where
			c.ev_mkt_id    =  m.ev_mkt_id    AND
			o.ev_oc_id     =  c.ev_oc_id     AND
			m.ev_mkt_id    =  $market        AND
			g.ev_oc_grp_id =  m.ev_oc_grp_id AND
			e.ev_id        =  c.ev_id        AND
			b.bet_id       =  o.bet_id       AND
			b.settled      =  'N'
			$cr_date_clause
			$where
	}]


	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set num_rows [db_get_nrows $rs]

	for {set i 0} {$i < $num_rows} {incr i} {
		set BETINFO($i,bet_id)  [db_get_col $rs $i bet_id]
		set BETINFO($i,receipt) [db_get_col $rs $i receipt]
		set BETINFO($i,cr_date) [db_get_col $rs $i cr_date]
		set BETINFO($i,ev_id    [db_get_col $rs $i ev_id]
		set BETINFO($i,event)   [db_get_col $rs $i event]
		set BETINFO($i,mkt_id)  [db_get_col $rs $i ev_mkt_id]
		set BETINFO($i,market)  [db_get_col $rs $i market]

		lappend bet_ids $BETINFO($i,bet_id)
	}

	tpSetVar  numBets  $num_rows

	tpBindVar BET_ID     BETINFO  bet_id     bet_idx
	tpBindVar RECEIPT    BETINFO  receipt    bet_idx
	tpBindVar DATE       BETINFO  cr_date    bet_idx
	tpBindVar EV_ID      BETINFO  ev_id      bet_idx
	tpBindVar EVENT      BETINFO  event      bet_idx
	tpBindVar MARKET_ID  BETINFO  ev_mkt_id  bet_idx
	tpBindVar MARKET     BETINFO  market     bet_idx
	tpBindVar INFO       BETINFO  info       bet_idx


	foreach name $parts {
		tpBindString [string toupper $name]_ID [set $name]
	}

	if {$date_from == ""} {
		set date_from "start of time"
	}
	if {$date_to == ""} {
		set date_to "end of time"
	}

	tpBindString DATE_FROM  $date_from
	tpBindString DATE_TO    $date_to

	if {[llength $bet_ids] > 0} {
		tpBindString BET_IDS [join $bet_ids "|"]
	}

	asPlayFile void_confirm.html
}


#
# Once confirmed this proc settles the bets to 'void'
#
proc do_void args {

	global DB USERNAME SUMMARY

	#
	# Get bet ids to loop through.
	#
	set bet_ids [split [reqGetArg bet_ids] "|"]

	OT_LogWrite 1 "Void Bets - bet_ids to void are: $bet_ids"

	set PARK_ON_WINNINGS_ONLY [OT_CfgGet PARK_ON_WINNINGS_ONLY "0"]
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE"} {
		set freebets_enabled Y
	} else {
		set freebets_enabled N
	}

	OT_LogWrite 10 "freebets_enabled: $freebets_enabled"

	# if we want to reclaim token value from winnings then pass this in
	if {[OT_CfgGet LOSE_FREEBET_TOKEN_VALUE "FALSE"]} {
		set lose_token_value Y
	} else {
		set lose_token_value N
	}

	#
	# Loop throug each of the bet ids
	#
	set bet_ok   0
	set bet_fail 0
	foreach bet_id $bet_ids {

		OT_LogWrite 1 "Void Bets - Attempting to void bet_id: $bet_id"

		#
		# Get information require to void the bet
		#
		set bet_id_sql [subst {
			select
				num_lines,
				stake
			from
				tbet
			where
				bet_id = $bet_id
		}]

		set stmt [inf_prep_sql $DB $bet_id_sql]
		set rs   [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		set num_lines [db_get_col $rs 0  num_lines]
		set stake     [db_get_col $rs 0 stake]


		set sql [subst {
			execute procedure pSettleBet(
				p_adminuser = '$USERNAME',
				p_op = 'X',
				p_bet_id = $bet_id,
				p_num_lines_win = 0,
				p_num_lines_lose = 0,
				p_num_lines_void = $num_lines,
				p_winnings = 0,
				p_tax = 0,
				p_refund = $stake,
				p_settled_how = 'M',
				p_settle_info = 'Settled via Late Bets',
				p_park_by_winnings = '$park_limit_on_winnings',
				p_lose_token_value = '$lose_token_value',
				p_freebets_enabled = '$freebets_enabled',
				p_r4_limit = [OT_CfgGet MAX_APPLIED_RULE4_DEDUCTION 100]
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		#
		# Settle the bet as void
		#
		if {[catch {
			set res [inf_exec_stmt $stmt]
		} msg]} {

			OT_LogWrite 1 "Void Bets - Failed to void bet: $bet_id"
			OT_LogWrite 1 "Void Bets - Reason: $msg"

			set SUMMARY($bet_fail,fail,bet_id) $bet_id
			set SUMMARY($bet_fail,fail,msg)    $msg

			err_bind $msg

			incr bet_fail

		} else {

			OT_LogWrite 1 "Void Bets - Successfully void bet: $bet_id"

			set SUMMARY($bet_ok,ok,bet_id) $bet_id

			incr bet_ok
		}

		inf_close_stmt $stmt
	}

	tpSetVar  numFail  $bet_fail
	tpSetVar  numOk    $bet_ok

	tpBindVar FAIL_BET_ID  SUMMARY   "fail,bet_id"   fail_idx
	tpBindVar FAIL_MSG     SUMMARY   "fail,msg"      fail_idx

	tpBindVar OK_BET_ID    SUMMARY   "ok,bet_id"     ok_idx

	asPlayFile void_summary.html
}

#End of namespace
}
