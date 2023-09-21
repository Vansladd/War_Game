# ==============================================================
# $Id: ev_sel.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::EV_SEL {

asSetAct ADMIN::EV_SEL::GoEvSel              [namespace code go_ev_sel]
asSetAct ADMIN::EV_SEL::GoEvSelPopUp         [namespace code go_ev_sel_popup]
asSetAct ADMIN::EV_SEL::GoUnstlEvSel         [namespace code go_unstl_ev_sel]
asSetAct ADMIN::EV_SEL::GoRampMonitoring     [namespace code go_ramp_monitoring]
asSetAct ADMIN::EV_SEL::DoEvSel              [namespace code do_ev_sel]
asSetAct ADMIN::EV_SEL::DoEvSettle           [namespace code do_ev_settle_sel]
asSetAct ADMIN::EV_SEL::GoEvQuickConfirm     [namespace code go_ev_quick_confirm]
asSetAct ADMIN::EV_SEL::GoEvQuickSettle      [namespace code go_ev_quick_settle]
asSetAct ADMIN::EV_SEL::DoSelnSearch         [namespace code do_seln_search]
asSetAct ADMIN::EV_SEL::ShowSel              [namespace code show_sel]


#
# ----------------------------------------------------------------------------
#  Procedure to Search specified Event , Market or  Selection 
# ----------------------------------------------------------------------------
#
proc show_sel { } {

	set type [reqGetArg SubmitName]

	ob_log::write DEBUG $type

	switch  $type {
	"event" {
				# check condition to make sure , we are not passing Empty string to the corresponding
				# Handlers
				if { [reqGetArg EvId] !="" && [catch {ADMIN::EVENT::go_ev } msg] } {
						err_bind " Invalid Search Criteria - Event Id :[reqGetArg EvId]"
						go_ev_sel 0
					}
			}

	"market" {

				if { [reqGetArg MktId] !="" &&  [catch {ADMIN::MARKET::go_mkt } msg] } {
						err_bind " Invalid Search Criteria - Market Id :[reqGetArg MktId]"
						go_ev_sel 0
					}
				
			}

	"selection" {

				if { [reqGetArg OcId] !="" && [catch {ADMIN::SELN::go_oc } msg] } {
						err_bind " Invalid Search Criteria - Selection Id :[reqGetArg OcId]"
						go_ev_sel 0
					}
				
			}

	default {
				err_bind "Invalid Search Criteria"
				go_ev_sel 0
			}
	}

}


#
# ----------------------------------------------------------------------------
# Generate top-level list of event classes
# ----------------------------------------------------------------------------
#
proc go_ev_sel_popup args {

	go_ev_sel 1
}

#
# ----------------------------------------------------------------------------
# Generate top-level list of event classes
# ----------------------------------------------------------------------------
#
proc go_ev_sel {{show_popup 0} args} {

	global DB CLASS TYPE SORT
	set where ""

	#
	# Check if suspended event classes should be listed
	# and make necesary bindings.
	#
	if {[OT_CfgGet FUNC_HIDE_SUSP_EV_CLASS 0]==1} {
		if {[reqGetArg show_susp_evs] == "Y"} {
			tpBindString ShowSuspEvs "N"
			tpBindString WhatSusp    "Hide"
		} else {
			set where "and c.status <> 'S'"
			tpBindString ShowSuspEvs "Y"
			tpBindString WhatSusp    "Show"
		}
	}

	set sql [subst {
		select
			c.ev_class_id,
			c.name cname,
			c.sort,
			c.displayed cdisp,
			c.disporder cdispo,
			t.ev_type_id,
			t.name tname,
			t.displayed tdisp,
			t.disporder tdispo,
			upper(c.name) as upcname,
			upper(t.name) as uptname
		from
			tEvClass c,
			tEvType t
		where
			c.ev_class_id = t.ev_class_id
			$where
		order by
			c.displayed desc,
			upcname asc,
			c.ev_class_id,
			t.displayed desc,
				tdispo asc,
			uptname asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set c_ix       -1
	set c_class_id -1

	for {set r 0} {$r < $rows} {incr r} {

		set class_id [db_get_col $res $r ev_class_id]
		set type_id  [db_get_col $res $r ev_type_id]
		set cname    [db_get_col $res $r cname]
		set tname    [db_get_col $res $r tname]
		set sort	 [db_get_col $res $r sort]

		if {$class_id != $c_class_id} {

			incr c_ix

			set CLASS($c_ix,id)    $class_id
			set CLASS($c_ix,name)  [remove_tran_bars $cname]
			set CLASS($c_ix,sort)  $sort
			set CLASS($c_ix,types) 0

			set c_class_id $class_id
		}

		set t_ix $CLASS($c_ix,types)

		set TYPE($c_ix,$t_ix,id)   $type_id
		set TYPE($c_ix,$t_ix,name) [string map {+ " "} [urlencode [remove_tran_bars $tname]]]
		set SORT($r,type)		   $type_id
		set SORT($r,sort)		   $sort

		incr CLASS($c_ix,types)
	}

	tpSetVar NumClasses [expr {$c_ix+1}]
	tpSetVar NumSorts	$rows

	tpBindVar ClassId   CLASS id   class_idx
	tpBindVar ClassName CLASS name class_idx
	tpBindVar ClassSort CLASS sort class_idx
	tpBindVar TypeId    TYPE  id   class_idx type_idx
	tpBindVar TypeName  TYPE  name class_idx type_idx
	tpBindVar SortType  SORT  type sort_idx
	tpBindVar TypeSort  SORT  sort sort_idx

	tpBindString Ev_Displayed [OT_CfgGet DFLT_EVENT_SEL_STATUS "A"]

	# Check whether it is allowed to insert or delete events.
	# When allow_dd_creation is set to Y, it enables the creating and
	# deleting of any dilldown items. Such as categories, classes
	# types and markets.
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	if {$show_popup == 0} {
		asPlayFile event_sel.html
	} else {
		asPlayFile ev_type_list_popup.html
	}

	db_close $res

	catch {unset CLASS}
	catch {unset TYPE}
	catch {unset SORT}
}


proc go_unstl_ev_sel args {

	global DB CLASS TYPE SORT

	set where ""

	#
	# Check if suspended event classes should be listed
	# and make necesary bindings.
	#
	if {[OT_CfgGet FUNC_HIDE_SUSP_EV_CLASS 0]==1} {
		if {[reqGetArg show_susp_evs] == "Y"} {
			tpBindString ShowSuspEvs "N"
			tpBindString WhatSusp    "Hide"
		} else {
			set where "and c.status <> 'S'"
			tpBindString ShowSuspEvs "Y"
			tpBindString WhatSusp    "Show"
		}
	}

	asPlayFile event_sel.html

	db_close $res

	catch {unset CLASS}
	catch {unset TYPE}
	catch {unset SORT}
}


proc go_ramp_monitoring args {

	global DB CLASS TYPE SORT


	set sql [subst {
		select
			c.ev_class_id,
			c.name cname,
			c.sort,
			c.displayed cdisp,
			c.disporder cdispo,
			t.ev_type_id,
			t.name tname,
			t.displayed tdisp,
			t.disporder tdispo,
			upper(c.name) as upcname,
			upper(t.name) as uptname
		from
			tEvClass c,
			tEvType t
		where
			c.ev_class_id = t.ev_class_id
		order by
			c.displayed desc,
			upcname asc,
			c.ev_class_id,
			t.displayed desc,
				tdispo asc,
			uptname asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set c_ix       -1
	set c_class_id -1

	for {set r 0} {$r < $rows} {incr r} {

		set class_id [db_get_col $res $r ev_class_id]
		set type_id  [db_get_col $res $r ev_type_id]
		set cname    [db_get_col $res $r cname]
		set tname    [db_get_col $res $r tname]
		set sort	 [db_get_col $res $r sort]

		if {$class_id != $c_class_id} {

			incr c_ix

			set CLASS($c_ix,id)    $class_id
			set CLASS($c_ix,name)  [remove_tran_bars $cname]
			set CLASS($c_ix,sort)  $sort
			set CLASS($c_ix,types) 0
			
			set c_class_id $class_id
		}

		set t_ix $CLASS($c_ix,types)

		set TYPE($c_ix,$t_ix,id)   $type_id
		set TYPE($c_ix,$t_ix,name) [remove_tran_bars $tname]

		set SORT($r,type)		   $type_id
		set SORT($r,sort)		   $sort

		incr CLASS($c_ix,types)
	}

	tpSetVar NumClasses [expr {$c_ix+1}]
	tpSetVar NumSorts	$rows

	tpBindVar ClassId   CLASS id   class_idx
	tpBindVar ClassName CLASS name class_idx
	tpBindVar ClassSort CLASS sort class_idx
	
	tpBindVar TypeId   TYPE   id   class_idx type_idx
	tpBindVar TypeName TYPE   name class_idx type_idx


	tpBindVar SortType  SORT  type sort_idx
	tpBindVar TypeSort  SORT  sort sort_idx

	tpBindString Ev_Displayed [OT_CfgGet DFLT_EVENT_SEL_STATUS "A"]

	asPlayFile ramp_monitoring.html

	db_close $res

	catch {unset CLASS}
	catch {unset TYPE}
	catch {unset SORT}
}




# remove any "|" characters that may surround words, indicating
# that they're translatable.  This does it properly, removing
# all such bars, rather than just the first and the last.
proc remove_tran_bars {tran} {

	if {[OT_CfgGet RMV_PIPES_FROM_EV_SEL 0]} {
		set map [list "|" ""]
		set tran [string map $map $tran]
	}

	return $tran
}


#
# ----------------------------------------------------------------------------
# Event search activator - can be routed to a straight search, or to the
# "add event" function
# ----------------------------------------------------------------------------
#
proc do_ev_sel args {

	set which      [reqGetArg SubmitName]
	set class_sort [reqGetArg ClassSort]

	if {$which == "EvShow"} {
		do_ev_sel_qry
	} elseif {$which == "RampShow"} {
		do_ramp_sel_qry
	} elseif {$which == "EvAdd"} {
		ADMIN::EVENT::go_ev_add
	} elseif {$which == "EvShowUnmatch"} {
		# To retrieve all the unmatched events
		ADMIN::BETFAIR_EV::go_ev_unmatch_sel_qry
	} elseif {$which == "EvAddFB"} {
		ADMIN::AUTOGEN::go_ev_add_$class_sort
	} elseif {$which == "EvResFB"} {
		ADMIN::AUTORES::go_ev_res_$class_sort
	} elseif {$which == "EvConfStlFB"} {
		ADMIN::AUTOCONF::go_ev_conf_stl_$class_sort
	} elseif {$which == "EvUpdShow"} {
		ADMIN::EVENT::go_evs_upd
	} elseif {$which == "EvConfStlPools"} {
		do_ev_sel_qry y
	} elseif {$which == "Refresh"} {
		go_ev_sel
	} else {
		error "unexpected SubmitName: $which"
	}
}


#
# ----------------------------------------------------------------------------
# Search for events
# unmatch_ev_sel - To reuse the search filter called from
#		   ADMIN::BETFAIR_EV::go_ev_unmatch_sel_qry
# ----------------------------------------------------------------------------
#
proc do_ev_sel_qry {{confstl_pools n} {unmatch_ev_sel n}} {

	if {$confstl_pools == "y" && ![op_allowed PoolQuickConfStl]} {
		err_bind "You don't have permission to confirm or settle pools"
		go_ev_sel
		return
	}

	global DB

	set class_id    [reqGetArg TypeId]
	set date_lo     [reqGetArg date_lo]
	set date_hi     [reqGetArg date_hi]
	set date_sel    [reqGetArg date_range]
	set settled     [reqGetArg settled]
	set status      [reqGetArg status]
	set displayed   [reqGetArg displayed]
	set result_conf [reqGetArg result_conf]
	set allow_stl 	[reqGetArg allow_stl]

	set start_or_susp 	[reqGetArg start_or_susp]
	set is_bir 	        [reqGetArg is_bir]

	# defaults
	set d_lo ""
	set d_hi ""

	if {$date_lo != "" || $date_hi != ""} {
		set d_lo $date_lo
		set d_hi $date_hi
	} else {
		set d_hi [clock scan now]
		set d_lo [clock scan now]

		if {$date_sel == "-3"} {
			# last 7 days
			set d_lo [clock scan "7 days ago"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "-2"} {
			# last three days
			set d_lo [clock scan "3 days ago"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "-1"} {
			# yesterday
			set d_lo [clock scan "yesterday"]

			set d_hi [clock format $d_lo -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "0"} {
			# today
			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]
		} elseif {$date_sel == "1"} {
			# tomorrow
			set d_lo [clock scan "tomorrow"]

			set d_hi [clock format $d_lo -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "2"} {
			# next 3 days
			set d_hi [clock scan "next 3 days"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "3"} {
			# next 7 days
			set d_hi [clock scan "next 7 days"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]
		} elseif {$date_sel == "4"} {
			# In the future
			set d_lo CURRENT
			set d_hi ""
		} else {
			set d_hi ""
			set d_lo ""
		}
	}

	if {$start_or_susp == "susp"} {
		set where [mk_between_clause "and e.suspend_at" date $d_lo $d_hi]
	} else {
		set where [mk_between_clause "and e.start_time" date $d_lo $d_hi]
	}

	if {$is_bir == "Y"} {
		append where " and e.has_bet_in_run = 'Y'"
	} elseif {$is_bir == "N"} {
		append where " and e.has_bet_in_run = 'N'"
	}

	if {$displayed == "Y"} {
		append where " and e.displayed = 'Y'"
	} elseif {$displayed == "N"} {
		append where " and e.displayed = 'N'"
	}

	set sel_type 0

	if {$class_id != 0} {

		set cs [split $class_id :]

		if {[lindex $cs 0] == "C"} {
			append where " and t.ev_class_id=[lindex $cs 1]"
		} else {
			append where " and t.ev_type_id=$class_id"

			set sel_type $class_id
		}
	}

	if {$settled != "-"}  {
		append where " and e.settled='$settled'"
	}

	if {[OT_CfgGet FUNC_ALLOW_SETTLE 0] && $allow_stl != "-"}  {
		append where " and e.allow_stl='$allow_stl'"
	}

	switch -- $result_conf {
		- {
			# do nothing
		}
		Y {
			append where " and e.result_conf = 'Y'"
		}
		N1 {
			append where " and e.result_conf = 'N'"
			append where " and not exists ("
			append where " select * from tevoc s"
			append where " where s.ev_id=e.ev_id and s.result='-' )"
		}
		N2 {
			append where " and e.result_conf = 'N'"
			append where " and exists ("
			append where " select * from tevoc s"
			append where " where s.ev_id=e.ev_id and s.result='-' )"
		}
	}

	if {$status != "-"} {
		append where " and e.status='$status'"
	}

	if {$unmatch_ev_sel == "y"} {
		# bf_betfair
		return $where
	}

	if {$confstl_pools == "y"} {
		append where {
			and not exists (
				select
					p.pool_id
				from
					tPool    p,
					tPoolMkt pm,
					tEvMkt   em
				where
					e.ev_id        = em.ev_id     and
					em.ev_mkt_id   = pm.ev_mkt_id and
					pm.pool_id     = p.pool_id    and
					p.rec_dividend = 'N'          and
					p.pool_type_id <> 'W_P'
			)
		}
	}

	set sql [subst {
		select
			c.category,
			c.name class_name,
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.start_time,
			e.status,
			e.disporder,
			e.settled,
			e.displayed,
			e.result_conf
		from
			tEvClass c,
			tEvtype  t,
			tEv      e
		where
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id
			$where
		order by
			c.category, c.name, e.start_time desc, e.disporder
	}]


	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar event_rows [db_get_nrows $res]

	tpBindTcl Category   sb_res_data $res event_idx category
	tpBindTcl Class      sb_res_data $res event_idx class_name
	tpBindTcl Type       sb_res_data $res event_idx type_name
	tpBindTcl TypeId     sb_res_data $res event_idx ev_type_id
	tpBindTcl EvId       sb_res_data $res event_idx ev_id
	tpBindTcl Event      sb_res_data $res event_idx desc
	tpBindTcl StartTime  sb_res_data $res event_idx start_time
	tpBindTcl Settled    sb_res_data $res event_idx settled
	tpBindTcl ResultConf sb_res_data $res event_idx result_conf
	tpBindTcl Displayed  sb_res_data $res event_idx displayed
	tpBindTcl Status     sb_res_data $res event_idx status

	tpSetVar CanAddEv [expr {($sel_type>0)?1:0}]

	tpBindString TypeId $sel_type

	#
	# Bind search criteria, in case we need it again when we go back.
	#
	tpBindString type_id     [reqGetArg TypeId]
	tpBindString date_range  [reqGetArg date_range]
	tpBindString date_lo     [reqGetArg date_lo]
	tpBindString date_hi     [reqGetArg date_hi]
	tpBindString settled     [reqGetArg settled]
	tpBindString result_conf [reqGetArg result_conf]
	tpBindString status      [reqGetArg status]
	tpBindString allow_stl   [reqGetArg allow_stl]

	tpBindString ClassSort  [reqGetArg ClassSort]
	tpBindString ClassId    [reqGetArg ClassId]

	# Check whether it is allowed to insert or delete events.
	# When allow_dd_creation is set to Y, it enables the creating and
	# deleting of any dilldown items. Such as categories, classes
	# types and markets.
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile event_list.html

	db_close $res
}

#
# proc for deciding status for ramp channels
#
proc ramp_setup_ch_data {index rs} {

	global MKT CHANNEL_MAP
	read_channel_info

	foreach level {c t e o m} {
		# collect the channels into a more concise variable
		set CHANNELS($level) [db_get_col $rs $index ${level}_chan]
	}

	set ramp_chan_idx 0
	foreach channel [split [OT_CfgGet RAMP_CHANNELS ""] {}] {

		set MKT($index,$ramp_chan_idx,name) $CHANNEL_MAP(code,$channel)
		# set defaults
		set MKT($index,$ramp_chan_idx,channel_displayed) 0
		set MKT($index,$ramp_chan_idx,channel_status)    ""

		# Is the event available in the hierarchy above the market?
		set above_levels_available 1
		foreach level {c t e} {
			if {![regexp $channel $CHANNELS($level)]} {
				set above_levels_available 0
			}
		}
		
		if {$above_levels_available} {
			if {![regexp $channel $CHANNELS(o)]} {
				# if the event is not available at evocgrp level, mark as *
				set MKT($index,$ramp_chan_idx,channel_status) "*"
			} else {

				# if the event is available at evocgrp level, set the page 
				# to display a checkbox and determine whether it is checked
				set MKT($index,$ramp_chan_idx,channel_displayed) 1
				if {[regexp $channel $CHANNELS(m)]} {
					set MKT($index,$ramp_chan_idx,channel_status) "checked"
				}

			}
		}
		incr ramp_chan_idx
	}

}

# This proc gets information for RAMP
# it shows all the markets for selected events so PMU
# can see what's been added recently via RAMP
proc do_ramp_sel_qry {} {

	global DB MKT

	set class_id    [reqGetArg TypeId]
	set date_lo     [reqGetArg date_lo]
	set date_hi     [reqGetArg date_hi]
	set date_sel    [reqGetArg date_range]
	set status      [reqGetArg status]
	set displayed   [reqGetArg displayed]

	# defaults
	set d_lo ""
	set d_hi ""

	if {$date_lo != "" || $date_hi != ""} {
		set d_lo $date_lo
		set d_hi $date_hi
	} else {
		set d_hi [clock scan now]
		set d_lo [clock scan now]

		if {$date_sel == "-3"} {
			# 2 hours ago
			set d_lo [clock scan "2 hours ago"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d %H:%M:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d %H:%M:59"]

		} elseif {$date_sel == "-2"} {
			# last three days
			set d_lo [clock scan "3 days ago"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "-1"} {
			# yesterday
			set d_lo [clock scan "yesterday"]

			set d_hi [clock format $d_lo -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "0"} {
			# today
			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]
		} elseif {$date_sel == "1"} {
			# tomorrow
			set d_lo [clock scan "tomorrow"]

			set d_hi [clock format $d_lo -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "2"} {
			# next 3 days
			set d_hi [clock scan "next 3 days"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]

		} elseif {$date_sel == "3"} {
			# next 7 days
			set d_hi [clock scan "next 7 days"]

			set d_hi [clock format $d_hi -format "%Y-%m-%d 23:59:59"]
			set d_lo [clock format $d_lo -format "%Y-%m-%d 00:00:00"]
		} elseif {$date_sel == "4"} {
			# In the future
			set d_lo CURRENT
			set d_hi ""
		} else {
			set d_hi ""
			set d_lo ""
		}
	}

	set where [mk_between_clause "and m.cr_date" date $d_lo $d_hi]


	if {$displayed == "Y"} {
		append where " and m.displayed = 'Y'"
	} elseif {$displayed == "N"} {
		append where " and m.displayed = 'N'"
	}

	set sel_type 0

	if {$class_id != 0} {

		set cs [split $class_id :]

		if {[lindex $cs 0] == "C"} {
			append where " and t.ev_class_id=[lindex $cs 1]"
		} else {
			append where " and t.ev_type_id=$class_id"

			set sel_type $class_id
		}
	}

	if {$status != "-"} {
		append where " and m.status='$status'"
	}

	set sql [subst {
		select
			c.category,
			c.name class_name,
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.start_time,
			m.status,
			c.channels  as c_chan,
			t.channels  as t_chan,
			o.channels  as o_chan,
			e.channels  as e_chan,
			m.channels  as m_chan,
			e.disporder,
			e.settled,
			m.displayed,
			e.result_conf,
			m.name market_name,
			m.cr_date,
			m.ev_mkt_id
		from
			tEvClass    c,
			tEvtype     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    o
			
		where
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			e.ev_id = m.ev_id and
			o.ev_oc_grp_id = m.ev_oc_grp_id
			$where
		order by
			m.cr_date desc, c.category, c.name, e.disporder, m.ev_mkt_id desc

	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	tpSetVar event_rows $nrows
	
	ob_log::write INFO "do_ramp_sel_qry: Binding Ramp variables"
	
	for {set r 0} {$r < $nrows} {incr r} {
		# set up the ramp channel columns
		ramp_setup_ch_data $r $res
		
		set MKT($r,category)       [db_get_col $res $r category]
		set MKT($r,class_name)     [db_get_col $res $r class_name]
		set MKT($r,type_name)      [db_get_col $res $r type_name]
		set MKT($r,ev_type_id)     [db_get_col $res $r ev_type_id]
		set MKT($r,ev_id)          [db_get_col $res $r ev_id]
		set MKT($r,desc)           [db_get_col $res $r desc]
		set MKT($r,start_time)     [db_get_col $res $r start_time]
		set MKT($r,displayed)      [db_get_col $res $r displayed]
		set MKT($r,status)         [db_get_col $res $r status]
		set MKT($r,market_name)    [db_get_col $res $r market_name]
		set MKT($r,cr_date)        [db_get_col $res $r cr_date]
		set MKT($r,ev_mkt_id)      [db_get_col $res $r ev_mkt_id]
		
		set MKT($r,start_time) [clock format [clock scan $MKT($r,start_time)] -format "%d/%m/%Y %H:%M:%S"]
		set MKT($r,cr_date)    [clock format [clock scan $MKT($r,cr_date)] -format "%d/%m/%Y %H:%M:%S"]
	}
	
	tpBindVar Category     MKT   category    event_idx
	tpBindVar Class        MKT   class_name  event_idx
	tpBindVar Type         MKT   type_name   event_idx
	tpBindVar TypeId       MKT   ev_type_id  event_idx
	tpBindVar EvId         MKT   ev_id       event_idx
	tpBindVar Event        MKT   desc        event_idx
	tpBindVar StartTime    MKT   start_time  event_idx
	tpBindVar Displayed    MKT   displayed   event_idx
	tpBindVar Status       MKT   status      event_idx
	tpBindVar Market       MKT   market_name event_idx
	tpBindVar MktCrDate    MKT   cr_date     event_idx
	tpBindVar MktId        MKT   ev_mkt_id   event_idx


	# Channel template player variable setup:
	# ChannelDisplayed - 0/1 on whether text or checkbox
	# ChannelStatus    - text to display or checkbox status
	# ChannelName      - channel name string

	tpSetVar  NumRampChannels  [string length [OT_CfgGet RAMP_CHANNELS ""]]
	tpBindVar ChannelDisplayed MKT channel_displayed event_idx ramp_chan_idx
	tpBindVar ChannelStatus    MKT channel_status    event_idx ramp_chan_idx
	tpBindVar ChannelName      MKT name              event_idx ramp_chan_idx
	
	tpBindString TypeId $sel_type

	#
	# Bind search criteria, in case we need it again when we go back.
	#
	tpBindString type_id     [reqGetArg TypeId]
	tpBindString date_range  [reqGetArg date_range]
	tpBindString date_lo     [reqGetArg date_lo]
	tpBindString date_hi     [reqGetArg date_hi]
	tpBindString status      [reqGetArg status]

	tpBindString ClassSort  [reqGetArg ClassSort]
	tpBindString ClassId    [reqGetArg ClassId]

	asPlayFile ramp_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Event Settle search activator
# ----------------------------------------------------------------------------
#
proc do_ev_settle_sel args {

	set which      [reqGetArg SubmitName]
	set class_sort [reqGetArg ClassSort]

	if {$which == "EvShowSettle"} {
		do_ev_settle_sel_qry
	} else {
		error "unexpected SubmitName: $which"
	}
}


#
# ----------------------------------------------------------------------------
# Search for events which are confirmed
# ----------------------------------------------------------------------------
#
proc do_ev_settle_sel_qry args {

	global DB
	global EV_CONF
	global EV_STL

	set class_id [reqGetArg TypeId]
	set date_lo  [reqGetArg date_lo]
	set date_hi  [reqGetArg date_hi]
	set date_sel [reqGetArg date_range]

	set start_or_susp 	[reqGetArg start_or_susp]
	set is_bir 	        [reqGetArg is_bir]


	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set d_hi [clock scan now]
		set d_lo [clock scan now]

		if {$date_sel == "-3"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "-2"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "-1"} {
			# yesterday
			set d_lo [clock scan "yesterday"]

			set d_hi [clock format $d_lo -format "'%Y-%m-%d 23:59:59'"]
			set d_lo [clock format $d_lo -format "'%Y-%m-%d 00:00:00'"]

		} elseif {$date_sel == "0"} {
			# today
			set d_hi [clock format $d_hi -format "'%Y-%m-%d 23:59:59'"]
			set d_lo [clock format $d_lo -format "'%Y-%m-%d 00:00:00'"]
		} elseif {$date_sel == "1"} {
			# tomorrow
			set d_lo [clock scan "tomorrow"]

			set d_hi [clock format $d_lo -format "'%Y-%m-%d 23:59:59'"]
			set d_lo [clock format $d_lo -format "'%Y-%m-%d 00:00:00'"]

		} elseif {$date_sel == "2"} {
			# next 3 days
			set d_hi [clock scan "next 3 days"]

			set d_hi [clock format $d_hi -format "'%Y-%m-%d 23:59:59'"]
			set d_lo [clock format $d_lo -format "'%Y-%m-%d 00:00:00'"]

		} elseif {$date_sel == "3"} {
			# next 7 days
			set d_hi [clock scan "next 7 days"]

			set d_hi [clock format $d_hi -format "'%Y-%m-%d 23:59:59'"]
			set d_lo [clock format $d_lo -format "'%Y-%m-%d 00:00:00'"]
		} elseif {$date_sel == "4"} {
			set d_lo CURRENT
			set d_hi "'9999-12-31 23:59:59'"
		} else {
			set d_lo "'0001-01-01 00:00:00'"
			set d_hi "'9999-12-31 23:59:59'"
		}
	}

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

	set sel_type 0

	if {$class_id != 0} {

		set cs [split $class_id :]

		if {[lindex $cs 0] == "C"} {
			append where " and t.ev_class_id=[lindex $cs 1]"
		} else {
			append where " and t.ev_type_id=$class_id"

			set sel_type $class_id
		}
	}

	#
	# Get all events to be confirmed (result_conf = 'N' and all selections have results set)
	#
	set qry_confirm [subst {
		select
			c.category,
			c.name class_name,
			c.sort as class_sort,
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.disporder,
			e.start_time
		from
			tEvClass c,
			tEvtype  t,
			tEv      e,
			tEvUnstl u
		where
			u.ev_type_id = t.ev_type_id and
			u.ev_class_id = c.ev_class_id and
			u.ev_id = e.ev_id and
			e.allow_stl = 'Y' and
			e.settled ='N' and
			(e.result_conf = 'Y' or (e.result_conf = 'N' and
				 not exists (
					select *
					from tevoc s
					where s.ev_id=e.ev_id and s.result='-'
					)
				)
			) and
			not exists (
						select
							1
						from
							tEVMkt m,
							tEvOC  o
						where
							m.ev_id = e.ev_id                   and
							m.type in ('A','H','U','L','l','M') and
							m.hcap_makeup is null               and
							m.ev_mkt_id   = o.ev_mkt_id         and
							o.result      != 'V'
			)
			$where
		order by
			c.category,
			c.name,
			e.start_time desc,
			e.disporder
	}]


	set stmt [inf_prep_sql $DB $qry_confirm]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set n_conf [db_get_nrows $res]
	array set EV_CONF [list]

	for {set r 0} {$r < $n_conf} {incr r} {

		set EV_CONF($r,row)        $r
		set EV_CONF($r,ev_type_id) [db_get_col $res $r ev_type_id]
		set EV_CONF($r,ev_id)      [db_get_col $res $r ev_id]
		set EV_CONF($r,desc)       [db_get_col $res $r desc]
		set EV_CONF($r,start_time) [db_get_col $res $r start_time]
		set EV_CONF($r,class_sort) [db_get_col $res $r class_sort]

	}

	db_close $res

	ob_log::write_array INFO EV_CONF

	#
	# Get all events which can be settled (result_conf = 'Y')
	#
	set sql_settle [subst {
		select
			c.category,
			c.name class_name,
			c.sort as class_sort,
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.disporder,
			e.start_time,
			e.result_conf
		from
			tEvClass c,
			tEvtype  t,
			tEv      e,
			tEvUnstl u
		where
			u.ev_type_id = t.ev_type_id and
			u.ev_class_id = c.ev_class_id and
			u.ev_id = e.ev_id and
			e.allow_stl = 'Y' and
			e.settled ='N' and
			e.result_conf = 'Y' and
			not exists (
				select 1 from tevmkt m, outer tevoc s
				where m.ev_id = e.ev_id and m.result_conf = 'N'
				      and m.ev_mkt_id = s.ev_mkt_id and s.result_conf = 'N'
			)
			$where
		order by
			c.category,
			c.name,
			e.start_time desc,
			e.disporder
	}]

	set stmt [inf_prep_sql $DB $sql_settle]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set n_stl [db_get_nrows $res]
	array set EV_STL  [list]

	for {set r 0} {$r < $n_stl} {incr r} {

		set EV_STL($r,row)        $r
		set EV_STL($r,ev_type_id) [db_get_col $res $r ev_type_id]
		set EV_STL($r,ev_id)      [db_get_col $res $r ev_id]
		set EV_STL($r,desc)       [db_get_col $res $r desc]
		set EV_STL($r,start_time) [db_get_col $res $r start_time]
		set EV_STL($r,class_sort) [db_get_col $res $r class_sort]

	}

	db_close $res


	tpSetVar     NumConfEvs $n_conf
	tpBindString NumConfEvs $n_conf

	tpBindVar ConfRow        EV_CONF row        conf_ev_idx
	tpBindVar ConfTypeId     EV_CONF ev_type_id conf_ev_idx
	tpBindVar ConfEvId       EV_CONF ev_id      conf_ev_idx
	tpBindVar ConfEvent      EV_CONF desc       conf_ev_idx
	tpBindVar ConfStartTime  EV_CONF start_time conf_ev_idx
	tpBindVar ConfClassSort  EV_CONF class_sort conf_ev_idx

	tpSetVar     NumStlEvs $n_stl
	tpBindString NumStlEvs $n_stl

	tpBindVar StlRow         EV_STL  row        stl_ev_idx
	tpBindVar StlTypeId      EV_STL  ev_type_id stl_ev_idx
	tpBindVar StlEvId        EV_STL  ev_id      stl_ev_idx
	tpBindVar StlEvent       EV_STL  desc       stl_ev_idx
	tpBindVar StlStartTime   EV_STL  start_time stl_ev_idx
	tpBindVar StlClassSort   EV_STL  class_sort stl_ev_idx

	asPlayFile event_confirmed_list.html

	unset EV_CONF
	unset EV_STL
}


#
# ----------------------------------------------------------------------------
# Event Quick Confirm search activator
# ----------------------------------------------------------------------------
#
proc go_ev_quick_confirm args {

	if {![op_allowed ConfirmResults]} {
		err_bind "You don't have permission to confirm results"
		go_ev_sel
		return
	}

	set which [reqGetArg SubmitName]

	if {$which == "EvQuickConfirm"} {
		do_ev_quick_confirm
	} elseif {$which == "Back"} {
		go_ev_sel
	} else {
		error "unexpected SubmitName: $which"
	}
}


#
# ----------------------------------------------------------------------------
# Quick Confirm events
# ----------------------------------------------------------------------------
#
proc do_ev_quick_confirm args {

	global EVT USERNAME

	set sql {
		execute procedure pSetResultConf(
			p_adminuser = ?,
			p_obj_type  = 'E',
			p_obj_id    = ?,
			p_conf      = 'Y'
		)
	}

	set stmt [inf_prep_sql $::DB $sql]

	set c_ix 0

	for {set i 0} {$i < [reqGetArg NumEvts]} {incr i} {

		if {[reqGetArg ConfCheck_$i] == "Y"} {

			set ev_id [reqGetArg row_$i]
			set desc  [reqGetArg name_$i]

			set EVT($c_ix,ev_id) $ev_id
			set EVT($c_ix,desc)  $desc

			inf_begin_tran $::DB

			set c [catch {
				inf_exec_stmt $stmt\
					$USERNAME\
					$ev_id
			} msg]

			if {!$c} {
				inf_commit_tran $::DB
				set EVT($c_ix,status) confirmed
				set EVT($c_ix,class)  infoyes
			} else {
				inf_rollback_tran $::DB
				set EVT($c_ix,status) "not confirmed"
				set EVT($c_ix,class)  infono
			}

	   		incr c_ix
		}
	}

	inf_close_stmt $stmt

	tpSetVar NumEvts $c_ix

	tpBindVar ConfEvId   EVT ev_id  evt_idx
	tpBindVar ConfEvent  EVT desc   evt_idx
	tpBindVar ConfStatus EVT status evt_idx
	tpBindVar ConfClass  EVT class  evt_idx

	asPlayFile quick_evt_confirm.html

	catch {unset EVT}
}


#
# ----------------------------------------------------------------------------
# Event Quick Settle search activator
# ----------------------------------------------------------------------------
#
proc go_ev_quick_settle args {

	if {![op_allowed Settle]} {
		err_bind "You don't have permission to quick settle events"
		go_ev_sel
		return
	}

	set which [reqGetArg SubmitName]

	if {$which == "EvQuickSettle"} {
		do_ev_quick_settle
	} elseif {$which == "Back"} {
		go_ev_sel
	} else {
		error "unexpected SubmitName: $which"
	}
}


#
# ----------------------------------------------------------------------------
# Quick Settle events
# ----------------------------------------------------------------------------
#
proc do_ev_quick_settle args {

	global EVT USERNAME

	set c_ix 0

	for {set i 0} {$i < [reqGetArg NumEvts]} {incr i} {

		if {[reqGetArg "StlCheck_${i}"] == "Y"} {

			set ev_id [reqGetArg "row_${i}"]

			set StlObj   "event"
			set StlObjId $ev_id
			set StlDoIt  "Y"

		  	ADMIN::SETTLE::stl_settle $StlObj $StlObjId $StlDoIt

			set EVT($c_ix,stl_obj_id) $StlObjId

	   		incr c_ix
		}
	}

	tpSetVar NumEvts $c_ix

	tpBindVar StlObjId EVT stl_obj_id evt_idx

	asPlayFile quick_evt_settle.html

	catch {unset EVT}
}

#
# ----------------------------------------------------------------------------
# Searchs for a selection
# ----------------------------------------------------------------------------
#
proc do_seln_search args {
	global DB EV

	set seln_name [string tolower [reqGetArg selection]]
	set class_id  [reqGetArg TypeId]
	set settled   [reqGetArg Settled]
	set date_lo   [reqGetArg date_lo]
	set date_hi   [reqGetArg date_hi]
	set date_sel  [reqGetArg date_range]
	set status    [reqGetArg Status]

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"
	set where [list]

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi 23:59:59'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}


		if {$date_sel == "-3"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -7] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "-2"} {
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			if {[incr d -3] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "-1"} {
			if {[incr d -1] <= 0} {
				if {[incr m -1] < 1} {
					set m 12
					incr y -1
				}
				set d [expr {[days_in_month $m $y]+$d}]
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
		} elseif {$date_sel == "0"} {
			set d_lo "'$dt 00:00:00'"
			set d_hi "'$dt 23:59:59'"
		} elseif {$date_sel == "1"} {
			if {[incr d] > [days_in_month $m $y]} {
				set d 1
				if {[incr m] > 12} {
					set m 1
					incr y
				}
			}
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
		} elseif {$date_sel == "2"} {
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			set md [days_in_month $m $y]
			if {[incr d 3] > $md} {
				set d [expr {$d-$md}]
				if {[incr m] > 12} {
					set m 1
					incr y
				}
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
		} elseif {$date_sel == "3"} {
			set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			set md [days_in_month $m $y]
			if {[incr d 7] > $md} {
				set d [expr {$d-$md}]
				if {[incr m] > 12} {
					set m 1
					incr y
				}
			}
			set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
		} elseif {$date_sel == "4"} {
			set d_lo CURRENT
		}
	}

	# Search for events between the 2 specified dates iff present
	set where "and e.start_time between $d_lo and $d_hi"

	# Check if event being searched is settled/non-settled
	if {$settled != "-"}  {
		append where " and o.settled='$settled'"
	}

	# Check if status of event is active/suspended
	if {$status != "-"} {
		append where " and o.status='$status'"
	}

	# Use tEvUnstl if settled equals N
	switch -- $settled {
		"N" {
			set use_tevunstl 1
			set table {u}
		}
		default {
			set use_tevunstl 0
			set table {t}
		}
	}

	# Search at the class level or type level
	if {$class_id != 0} {

		set cs [split $class_id :]

		if {[lindex $cs 0] == "C"} {
			append where " and ${table}.ev_class_id=[lindex $cs 1]"
		} else {
			append where " and ${table}.ev_type_id=$class_id"
		}
	}

	# Replace any single quotes
	regsub -all {[\']} $seln_name {''} mod_seln_name

	append  where " and lower(o.desc) like '%${seln_name}%'"

	if {$use_tevunstl} {
		set sql [subst {
			select
				distinct
				c.category,
				c.name class_name,
				t.name type_name,
				e.ev_id,
				e.desc ev_name,
				e.start_time,
				e.displayed,
				e.status,
				e.settled,
				e.result_conf
			from
				tEvClass c,
				tEvType t,
				tEvUnStl u,
				tEv e,
				tEvMkt m,
				tEvOc o
			where
				t.ev_class_id = c.ev_class_id and
				t.ev_type_id  = u.ev_type_id and
				u.ev_id       = e.ev_id and
				e.ev_id       = m.ev_id and
				m.ev_mkt_id   = o.ev_mkt_id
				$where
			order by
				e.start_time desc
		}]
	} else {
		set sql [subst {
			select
				distinct
				c.category,
				c.name class_name,
				t.name type_name,
				e.ev_id,
				e.desc ev_name,
				e.start_time,
				e.displayed,
				e.status,
				e.settled,
				e.result_conf
			from
				tEvClass c,
				tEvType t,
				tEv e,
				tEvMkt m,
				tEvOc o
			where
				t.ev_class_id = c.ev_class_id and
				e.ev_type_id = t.ev_type_id and
				e.ev_id       = m.ev_id and
				m.ev_mkt_id   = o.ev_mkt_id
				$where
			order by
				e.start_time desc
		}]
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set EV($r,ev_id)       [db_get_col $rs $r ev_id]
		set EV($r,ev_name)     [db_get_col $rs $r ev_name]
		set EV($r,displayed)   [db_get_col $rs $r displayed]
		set EV($r,class_name)  [db_get_col $rs $r class_name]
		set EV($r,type_name)   [db_get_col $rs $r type_name]
		set EV($r,start_time)  [db_get_col $rs $r start_time]
		set EV($r,status)      [db_get_col $rs $r status]
		set EV($r,settled)     [db_get_col $rs $r settled]
		set EV($r,result_conf) [db_get_col $rs $r result_conf]
		set EV($r,category)    [db_get_col $rs $r category]
	}

	db_close $rs
	unset rs

	tpSetVar event_rows $nrows
	tpSetVar EventSearch 1
	tpBindString Selection $seln_name

	tpBindVar Event         EV    ev_name      event_idx
	tpBindVar EvId          EV    ev_id        event_idx
	tpBindVar Displayed     EV    displayed    event_idx
	tpBindVar Class         EV    class_name   event_idx
	tpBindVar Category      EV    category     event_idx
	tpBindVar Type          EV    type_name    event_idx
	tpBindVar StartTime     EV    start_time   event_idx
	tpBindVar Status        EV    status       event_idx
	tpBindVar Settled       EV    settled      event_idx
	tpBindVar ResultConf    EV    result_conf  event_idx

	# Check whether it is allowed to insert or delete classes.
	# When allow_dd_creation is set to Y, it enables the creating and
	# deleting of any dilldown items. Such as categories, classes
	# types and markets.
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile -nocache event_list.html
}

}
