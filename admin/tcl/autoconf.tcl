# ==============================================================
# $Id: autoconf.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUTOCONF {

asSetAct ADMIN::AUTOCONF::DoEvConfStl [namespace code do_ev_conf_stl]

#
# ----------------------------------------------------------------------------
# Confirm/Settle events
# ----------------------------------------------------------------------------
#
proc go_ev_conf_stl_BB {} {
	go_ev_conf_stl BB
}

proc go_ev_conf_stl_FB {} {
	go_ev_conf_stl FB
}

proc go_ev_conf_stl { csort { full_page 1 } } {

	global DB EVENTARRAY ACTIONARRAY

	if { !$full_page && [info exists EVENTARRAY] } {
		unset EVENTARRAY
	} else {
		GC::mark EVENTARRAY ACTIONARRAY
	}

	set type_id [reqGetArg TypeId]

	#
	# Use the requested data range
	#
	set data_range [reqGetArg date_range]
	set date_lo    [reqGetArg date_lo]
	set date_hi    [reqGetArg date_hi]

	if {[regexp {^\d+-\d+-\d+$} $date_lo]} {
		set date_lo "$date_lo 00:00:00"
	}
	if {[regexp {^\d+-\d+-\d+$} $date_hi]} {
		set date_hi "$date_hi 23:59:59"
	}

	if {$date_hi == "" || $date_lo == ""} {
		set now [clock seconds]

		switch -exact -- $data_range {
			-2 {
				# last 3 days
				set 3day [expr {$now-3*60*60*24}]
				set date_lo   [clock format $3day -format {%Y-%m-%d 00:00:00}]
				set date_hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			-1 {
				# yesterday
				set yday [expr {$now-60*60*24}]
				set date_lo   [clock format $yday -format {%Y-%m-%d 00:00:00}]
				set date_hi   [clock format $yday -format {%Y-%m-%d 23:59:59}]
			}
			0 {
				# today
				set date_lo [clock format $now -format {%Y-%m-%d 00:00:00}]
				set date_hi [clock format $now -format {%Y-%m-%d 23:59:59}]
			}
			default {
				set 7day [expr {$now-7*60*60*24}]
				set date_lo [clock format $7day -format {%Y-%m-%d 00:00:00}]
				set date_hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
		}
	}

	#
	# Need to get the available Event Outcome Groups
	#
	set res_events [get_confirm_settle_events $csort $type_id $date_lo $date_hi]

	tpSetVar NumEvents [set numEvents [db_get_nrows $res_events]]

	array set CONFIRM     [list Y Confirmed N Unconfirmed]
	array set EVENTARRAY  [list]
	array set ACTIONARRAY [list]

	for {set i 0} {$i < $numEvents} {incr i} {

		set ev_id       [db_get_col $res_events $i ev_id]
		set desc        [db_get_col $res_events $i desc]
		set allow_stl   [db_get_col $res_events $i allow_stl]
		set result_conf [db_get_col $res_events $i result_conf]

		set res_mkts  [get_resulted_markets $ev_id "N" "N" 1]
		set conf_mkts [get_resulted_markets $ev_id "N" "N" 0]
		set uset_mkts [get_resulted_markets $ev_id "Y" "N" 0]
		set sett_mkts [get_resulted_markets $ev_id "Y" "Y" 0]
		set num_res   [db_get_nrows $res_mkts]
		set num_conf  [db_get_nrows $conf_mkts]
		set num_uset  [db_get_nrows $uset_mkts]
		set num_sett  [db_get_nrows $sett_mkts]

		set unresulted_markets  [list]
		set unconfirmed_markets [list]
		set unsettled_markets   [list]
		set settled_markets     [list]

		# Obtain a list of markets that haven't been resulted
		for {set j 0} {$j < $num_res} {incr j} {
			lappend unresulted_markets [db_get_col $res_mkts $j sort]
		}

		# Obtain a list of markets that can be confirmed
		for {set j 0} {$j < $num_conf} {incr j} {
			lappend unconfirmed_markets [db_get_col $conf_mkts $j sort]
		}

		# Obtain a list of markets that can be settled
		for {set j 0} {$j < $num_uset} {incr j} {
			lappend unsettled_markets [db_get_col $uset_mkts $j sort]
		}

		# Obtain a list of markets that have been settled
		for {set j 0} {$j < $num_sett} {incr j} {
			lappend settled_markets [db_get_col $sett_mkts $j sort]
		}

		#
		# HACK ZONE AHEAD --- NEED TO MERGE FROM SLOT BRANCH SO RESULTS
		# ARE STORED ON tEv AND NOT tResult
		#
		if {$csort=="FB"} {
			set ft_result_desc [ADMIN::AUTORES::get_score_result_desc $ev_id MR]
			set ft_result_score [ADMIN::AUTORES::get_match_result $ev_id FT]
			set hf_result_desc [ADMIN::AUTORES::get_score_result_desc $ev_id HF]
			set hf_result_score [ADMIN::AUTORES::get_match_result $ev_id HT]

			if {$ft_result_desc==""} {
				set ft_result_desc "?"
			}
			if {$ft_result_score==""} {
				set ft_result_score [get_match_result_desc $ev_id CS]
				if {$ft_result_score == ""} {
					set ft_result_score "-"
				}
			} else {
				set s [split $ft_result_score "|"]
				set ft_result_score "[lindex $s 0]-[lindex $s 1]"
			}
			if {$hf_result_desc==""} {
				set hf_result_desc [get_match_result_desc $ev_id HF]
				if {$hf_result_desc==""} {
					set hf_result_desc "?"
				}
			}
			set EVENTARRAY($i,result) $ft_result_desc
			set EVENTARRAY($i,score)  $ft_result_score
			set EVENTARRAY($i,htft)   $hf_result_desc
		}

		set EVENTARRAY($i,reslt)  [join $unresulted_markets ","]
		set EVENTARRAY($i,conf)   [join $unconfirmed_markets ","]
		set EVENTARRAY($i,uset)   [join $unsettled_markets ","]
		set EVENTARRAY($i,sett)   [join $settled_markets ","]
		set EVENTARRAY($i,ev_id)  $ev_id
		set EVENTARRAY($i,desc)   $desc
		set EVENTARRAY($i,status) $CONFIRM($result_conf)

		set actions [list "'-'" "'---------'"]

		if {[llength $unconfirmed_markets] > 0} {
			lappend actions "'C'" "'Confirm'"
		}

		if {[llength $unsettled_markets] > 0} {
			lappend actions "'U'" "'Unconfirm'"

			if {$allow_stl == "Y"} {
				lappend actions "'S'" "'Settle'"
			}
		}

		set EVENTARRAY($i,options) [join $actions ","]

		if {[info exists ACTIONARRAY($ev_id)]} {
			set EVENTARRAY($i,actionCode) $ACTIONARRAY($ev_id)
		} else {
			set EVENTARRAY($i,actionCode) "-"
		}
	}

	db_close $res_events

	tpBindVar EVENT_NAME         EVENTARRAY desc       ev_idx
	tpBindVar EVENT_ID           EVENTARRAY ev_id      ev_idx
	tpBindVar ACTOPTIONS         EVENTARRAY options    ev_idx
	tpBindVar ACTCODE            EVENTARRAY actionCode ev_idx
	tpBindVar STATUS             EVENTARRAY status     ev_idx
	tpBindVar EVENT_UNRESULTED   EVENTARRAY reslt      ev_idx
	tpBindVar EVENT_UNCONFIRMED  EVENTARRAY conf       ev_idx
	tpBindVar EVENT_UNSETTLED    EVENTARRAY uset       ev_idx
	tpBindVar EVENT_SETTLED      EVENTARRAY sett       ev_idx

	#
	# HACK ZONE 2
	#
	#
	if {$csort=="FB"} {
		tpBindVar EVENT_RESULT    EVENTARRAY result ev_idx
		tpBindVar EVENT_SCORE     EVENTARRAY score  ev_idx
		tpBindVar EVENT_HTFT      EVENTARRAY htft   ev_idx
	}

	if {$type_id != "0"} {
		set cs [split $type_id :]
		if {[lindex $cs 0] == "C"} {
			set type_sel [subst {
				select
					ev_type_id
				from
					tevtype
				where
					ev_class_id=[lindex $cs 1]
			}]
		} else {
			set type_sel $type_id
		}
	}

	set sql [subst {
		select
			c.name cname,
			t.name tname,
			c.sort
		from
			tEvClass c,
			tEvType  t
		where
			t.ev_type_id in ($type_sel)
		and t.ev_class_id = c.ev_class_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString ClassName [db_get_col $res 0 cname]
	tpBindString TypeName  [db_get_col $res 0 tname]
	tpBindString CSort     $csort
	tpBindString TypeId    $type_id
	tpBindString date_lo   $date_lo
	tpBindString date_hi   $date_hi

	db_close $res

	if { $full_page } {
		asPlayFile -nocache autoconf.html
	} else {
		#
		# We've already called asPlayFile for the top half of the page, which
		# will have set up the headers, so this second time we call the raw
		# w__asPlayFile (vide init.tcl).
		#
		w__asPlayFile -nocache autoconf_bottom.html
	}

}


proc get_match_result_desc {ev_id sort} {

	global DB

	set sql [subst {
		select
			o.desc
		from
			tEvOc o,
			tEvMkt m
		where
			o.ev_mkt_id = m.ev_mkt_id
		and o.result = 'W'
		and o.ev_id = ?
		and m.sort  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_id $sort]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		set ret ""
	} else {
		set ret [db_get_col $res 0 desc]
		if {$sort == "CS"} {
			set ix [string last - $ret]
			if {$ix > 0} {
			  incr ix -1
			  set ret [string range $ret $ix end]
			}
		}
	}

	db_close $res

	return $ret
}


#
# ----------------------------------------------------------------------------
# Route action to appropriate handler
# ----------------------------------------------------------------------------
#
proc do_ev_conf_stl args {

	set act [reqGetArg SubmitName]

	if {$act == "EvConfStl"} {
		do_conf_stl
	} elseif {$act == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}


#
# ----------------------------------------------------------------------------
# Event Confirm/Settle
# ----------------------------------------------------------------------------
#
proc do_conf_stl args {

	global DB USERNAME ACTIONARRAY EVENTARRAY

	GC::mark EVENTARRAY ACTIONARRAY

	set csort   [reqGetArg CSort]
	set type_id [reqGetArg TypeId]
	set date_lo [reqGetArg date_lo]
	set date_hi [reqGetArg date_hi]

	set ev_rs [get_confirm_settle_events $csort $type_id $date_lo $date_hi]

	set numEvents [db_get_nrows $ev_rs]

	for {set i 0} {$i < $numEvents} {incr i} {

		set EVENTARRAY($i,ev_id)      [db_get_col $ev_rs $i ev_id]
		set EVENTARRAY($i,actionCode) [reqGetArg "E$EVENTARRAY($i,ev_id)"]

		set ACTIONARRAY($EVENTARRAY($i,ev_id)) $EVENTARRAY($i,actionCode)

	}

	db_close $ev_rs

	asPlayFile -nocache autoconf_top.html

	set count(C) 0
	set count(S) 0
	set count(U) 0
	set count(-) 0

	tpBindString NumConf   $count(C)
	tpBindString NumUnconf $count(U)
	tpBindString NumStl    $count(S)

	set      stl_count 0
	tpSetVar EvResConfStl 1

	tpBufWrite "<PRE>"

	set bad 0

	for {set i 0} {$i < $numEvents} {incr i} {

		set ev_id  $EVENTARRAY($i,ev_id)
		set action $EVENTARRAY($i,actionCode)

		if { $action == "" } { continue }

		switch -- $action {

			C {
				set bad [ADMIN::EVENT::do_ev_conf_yn Y $ev_id]
			}

			U {
				set bad [ADMIN::EVENT::do_ev_conf_yn N $ev_id]
			}

			S {

				set res [get_resulted_markets $ev_id "Y" "N" 0]
				set nrows [db_get_nrows $res]

				for {set r 0} {$r < $nrows} {incr r} {

					set mkt_id [db_get_col $res $r ev_mkt_id]

					if { [catch {
						ADMIN::SETTLE::stl_settle market $mkt_id Y
					} msg] } {
						OT_LogWrite 1 "Could not settle market: $msg"
						err_bind $msg
						set bad 1
					}

				}
				db_close $res

			}

			default { }

		}

		if {$bad} {
			tpBufWrite "</PRE>"
			autoconfstl_error $csort
			return
		}

		incr count($action)

		tpBindString NumConf   $count(C)
		tpBindString NumUnconf $count(U)
		tpBindString NumStl    $count(S)
	}

	tpBufWrite "</PRE>"

	go_ev_conf_stl $csort 0

	catch {unset EVENTARRAY}
	catch {unset ACTIONARRAY}

}

proc autoconfstl_error {csort} {
	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
		tpBindString [reqGetNthName $a] [reqGetNthVal $a]
	}
	go_ev_conf_stl $csort
}

proc get_resulted_markets {ev_id confirmed settled unresulted} {
	global DB

	set not ""
	set scsett ""
	set scconf ""

	if {!$unresulted} {
		set not "not"
	}
	if {$settled == "Y"} {
		set scsett "not"
	}
	if {$confirmed == "Y"} {
		set scconf "not"
	}

	# Gaaah Scorecast - the evil special case of doom
	# The scorecast market is a join between First Scorer and Correct Score
	# The market itself only acts as a dummy market so we need to look at FS and CS
	# to determine whether it is 'confirmed', 'settled' etc rather than at the market.
	# SC will only be returned if there are FS and CS markets and they have outcomes.
	# If either of these markets is incorrectly set up, the SC market will not appear.

	set sql [subst {
		select
			m.ev_mkt_id,
			g.name,
			g.sort
		from
			tEvMkt m,
			tEvOcGrp g
		where
			g.sort <> "SC"
			and m.result_conf = ?
			and g.ev_oc_grp_id = m.ev_oc_grp_id
			and m.settled = ?
			and m.ev_id = ?
			and exists (
				select 1
				from   tEvOc oc
				where  oc.ev_mkt_id = m.ev_mkt_id)
			and $not exists (
				select 1
				from   tEvOc oc
				where  oc.ev_mkt_id = m.ev_mkt_id
				and  oc.result = '-'
			)

		union

		select
			m.ev_mkt_id,
			g.name,
			g.sort
		from
			tEvMkt m,
			tEvOcGrp g
		where
			g.sort = "SC"
			and g.ev_oc_grp_id = m.ev_oc_grp_id
			and m.ev_id = ?
			and exists (
				select 1
				from   tEvOc soc, tEvMkt sm, tEvOcGrp sg
				where  sm.ev_id = m.ev_id
				and    soc.ev_mkt_id = sm.ev_mkt_id
				and    sg.ev_oc_grp_id = sm.ev_oc_grp_id
				and    sg.sort = "CS"
			)
			and exists (
				select 1
				from   tEvOc soc, tEvMkt sm, tEvOcGrp sg
				where  sm.ev_id = m.ev_id
				and    soc.ev_mkt_id = sm.ev_mkt_id
				and    sg.ev_oc_grp_id = sm.ev_oc_grp_id
				and    sg.sort = "FS"
			)
			and $scconf exists (
				select 1
				from   tEvMkt sm
				where  sm.ev_id = m.ev_id
				and    (sm.sort = "CS" or sm.sort = "FS")
				and    sm.result_conf = 'N'
			)
			and $scsett exists (
				select 1
				from   tEvMkt sm
				where  sm.ev_id = m.ev_id
				and    (sm.sort = "CS" or sm.sort = "FS")
				and    sm.settled = 'N'
			)
			and $not exists (
				select 1
				from   tEvOc oc, tEvMkt sm
				where  sm.ev_id = m.ev_id
				and    (sm.sort = "CS" or sm.sort = "FS")
				and    oc.ev_mkt_id = sm.ev_mkt_id
				and    oc.result = '-'
			)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $confirmed $settled $ev_id $ev_id]
	inf_close_stmt $stmt
	return $res
}

proc get_confirm_settle_events {csort type_id date_lo date_hi} {

	global DB

	# Add date contraint
	if {$date_lo != "" && $date_hi != ""} {
		set date "e.start_time > '$date_lo' and e.start_time < '$date_hi' and "
	} else {
		set date ""
	}

	if {$type_id != ""} {
		if {$type_id != "0"} {
			set cs [split $type_id :]
			if {[lindex $cs 0] == "C"} {
				set type_sel "eu.ev_class_id = [lindex $cs 1]"
			} else {
				set type_sel "eu.ev_type_id = $type_id"
			}
		}
	}

	set sql [subst {
		select
			e.ev_id,
			e.desc,
			e.result_conf,
			e.start_time,
			e.allow_stl
		from
			tEvUnStl eu,
			tEv e
		where
			$date
		eu.ev_id = e.ev_id
		and exists (
				select 1
				from  tEvOc oc
				where oc.ev_id = e.ev_id
				and   oc.result <> '-'
		)
		and exists (
				select 1
				from   tEvMkt m
				  where  m.ev_id = e.ev_id
				  and    m.sort = ?
		)
		and e.settled = 'N'
		and $type_sel
		order by
			e.start_time
	}]

	set stmt [inf_prep_sql $DB $sql]

	switch -- $csort {
		FB {
			set dflt_mkt MR
		}
		BB {
			set dflt_mkt WH
		}
		default {
			error "can't handle class sort $csort"
		}
	}
	set res [inf_exec_stmt $stmt $dflt_mkt]
	inf_close_stmt $stmt
	return $res
}

}
