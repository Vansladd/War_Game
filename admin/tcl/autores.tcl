# ==============================================================
# $Id: autores.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUTORES {

asSetAct ADMIN::AUTORES::DoEvResFB [namespace code do_ev_res_FB]
asSetAct ADMIN::AUTORES::DoEvResBB [namespace code do_ev_res_BB]


#
# ----------------------------------------------------------------------------
# Show the result of the current event
# ----------------------------------------------------------------------------
#
proc go_ev_res_FB {{error 0}} {

	global FBEVENTS FSOC LSOC LGOC GTOC SFOC C3OC B3OC GSOC

	catch {unset FBEVENTS}
	catch {unset FSOC}
	catch {unset LSOC}
	catch {unset GSOC}

	tpBindString TypeId [reqGetArg TypeId]

	set ev_id [reqGetArg EvFBId]

	set res [get_all_started_events FB MR]

	set numEv [db_get_nrows $res]

	tpSetVar NumEvents $numEv

	if {$ev_id == ""} {
		if {$numEv > 0} {
			set ev_id [db_get_col $res 0 ev_id]
		} else {
			asPlayFile -nocache autoresult_FB.html
			db_close $res
			return
		}
	}

	show_match_result_FB $ev_id
	set FBSORT [list]
	# Order by event name - grab data out of db and sort
		for {set i 0} {$i < $numEv} {incr i} {
		regsub -all {\|} [db_get_col $res $i desc] {} desc
		set id [db_get_col $res $i ev_id]
		set start [db_get_col $res $i start_time]
		lappend FBSORT [list $desc $id $start]
	}

	# Sort!
	set FBSORT [lsort $FBSORT]

	for {set i 0} {$i < $numEv} {incr i} {
		set current [lindex $FBSORT $i]
		set FBEVENTS($i,ev_id) [lindex $current 1]
		set FBEVENTS($i,desc) [lindex $current 0]
		set EVTIME([lindex $current 1])	[lindex $current 2]
	}

	db_close $res

	# If they requested an event that isn't in our list, default to the first
	# event and bind an error for them
	set found 0
	for {set i 0} {$i < $numEv} {incr i} {
		if {$FBEVENTS($i,ev_id) == $ev_id} { set found 1 }
	}

	if {!$found} {
		err_bind "Event ($ev_id) not found or already confirmed"
		set ev_id [lindex [lindex $FBSORT 0] 1]
	}

	tpBindVar Ev_Id   FBEVENTS ev_id ev_idx
	tpBindVar Ev_Name FBEVENTS desc  ev_idx

	#if {$error == 0} {

		set fs_outcomes [get_scorer_outcomes $ev_id FS]
		set numFS       [db_get_nrows $fs_outcomes]

		OT_LogWrite 7 "Number of First Scorers outcomes: $numFS"

		tpSetVar NumFirstScorers $numFS

		for {set i 0} {$i < $numFS} {incr i} {

			set rs [db_get_col $fs_outcomes $i result]

			set FSOC($i,ev_oc_id)      [db_get_col $fs_outcomes $i ev_oc_id]
			set FSOC($i,desc)          [db_get_col $fs_outcomes $i desc]
		   	set FSOC($i,settled)       [db_get_col $fs_outcomes $i settled]
		   	set FSOC($i,status)        [db_get_col $fs_outcomes $i status]
		   	set FSOC($i,displayed)     [db_get_col $fs_outcomes $i displayed]
			set FSOC($i,result)        [expr {($rs=="-")?"L":$rs}]
		}

		if {$numFS > 0} {
			set FSMktResultConf [db_get_col $fs_outcomes 0 result_conf]

			tpBindString FSMktResultConf $FSMktResultConf
			tpBindString FSMktSettled    [db_get_col $fs_outcomes 0 settled]
			tpBindString FSMktStatus     [db_get_col $fs_outcomes 0 status]
			tpBindString FSMktDisplayed  [db_get_col $fs_outcomes 0 displayed]
		}

		db_close $fs_outcomes

		tpBindVar FS_NAME  FSOC desc        fs_idx
		tpBindVar EvIdFS   FSOC ev_oc_id    fs_idx
		tpBindVar EvResFS  FSOC result      fs_idx


		set ls_outcomes [get_scorer_outcomes $ev_id LS]
		set numLS       [db_get_nrows $ls_outcomes]

		OT_LogWrite 7 "Number of Last Scorers outcomes: $numLS"

		tpSetVar NumLastScorers $numLS

		for {set i 0} {$i < $numLS} {incr i} {

			set rs [db_get_col $ls_outcomes $i result]

			set LSOC($i,ev_oc_id) [db_get_col $ls_outcomes $i ev_oc_id]
			set LSOC($i,desc)     [db_get_col $ls_outcomes $i desc]
			set LSOC($i,result)   [expr {($rs=="-")?"L":$rs}]
		}

				if {$numLS > 0} {
			set LSMktResultConf [db_get_col $ls_outcomes 0 result_conf]

			tpBindString LSMktResultConf $LSMktResultConf
			tpBindString LSMktSettled    [db_get_col $ls_outcomes 0 settled]
			tpBindString LSMktStatus     [db_get_col $ls_outcomes 0 status]
			tpBindString LSMktDisplayed  [db_get_col $ls_outcomes 0 displayed]
		}

		db_close $ls_outcomes

		tpBindVar LS_NAME LSOC desc     ls_idx
		tpBindVar EvIdLS  LSOC ev_oc_id ls_idx
		tpBindVar EvResLS LSOC result   ls_idx

		# GoalScore outcomes
		set gs_outcomes [get_scorer_outcomes $ev_id GS]
		set numGS       [db_get_nrows $gs_outcomes]

		OT_LogWrite 7 "Number of GoalScorer outcomes: $numGS"

		tpSetVar NumGoalScorers $numGS

		for {set i 0} {$i < $numGS} {incr i} {

			set rs [db_get_col $gs_outcomes $i result]

			set GSOC($i,ev_oc_id) [db_get_col $gs_outcomes $i ev_oc_id]
			set GSOC($i,desc)     [db_get_col $gs_outcomes $i desc]
			set GSOC($i,result)   [expr {($rs=="-")?"L":$rs}]
		}

		if {$numGS > 0} {
			set GSMktResultConf [db_get_col $gs_outcomes 0 result_conf]

			tpBindString GSMktResultConf $GSMktResultConf
			tpBindString GSMktSettled    [db_get_col $gs_outcomes 0 settled]
			tpBindString GSMktStatus     [db_get_col $gs_outcomes 0 status]
			tpBindString GSMktDisplayed  [db_get_col $gs_outcomes 0 displayed]
		}

		db_close $gs_outcomes

		tpBindVar GS_NAME GSOC desc     gs_idx
		tpBindVar EvIdGS  GSOC ev_oc_id gs_idx
		tpBindVar EvResGS GSOC result   gs_idx

		# First to score for each team
		set sf_outcomes [get_scorer_outcomes $ev_id SF]
		set numSF       [db_get_nrows $sf_outcomes]

		OT_LogWrite 7 "Number of First Scorer for each team outcomes: $numFS"

		tpSetVar NumFirstScorerTeam $numSF

		for {set i 0} {$i < $numSF} {incr i} {

			set rs [db_get_col $sf_outcomes $i result]

			set SFOC($i,ev_oc_id)      [db_get_col $sf_outcomes $i ev_oc_id]
			set SFOC($i,desc)          [db_get_col $sf_outcomes $i desc]
		   	        set SFOC($i,settled)       [db_get_col $sf_outcomes $i settled]
		   	        set SFOC($i,status)        [db_get_col $sf_outcomes $i status]
		   	        set SFOC($i,displayed)     [db_get_col $sf_outcomes $i displayed]
			set SFOC($i,result)        [expr {($rs=="-")?"L":$rs}]
		}

		if {$numSF > 0} {
			set SFMktResultConf [db_get_col $sf_outcomes 0 result_conf]

			tpBindString SFMktResultConf $SFMktResultConf
			tpBindString SFMktSettled    [db_get_col $sf_outcomes 0 settled]
			tpBindString SFMktStatus     [db_get_col $sf_outcomes 0 status]
			tpBindString SFMktDisplayed  [db_get_col $sf_outcomes 0 displayed]
		}

		db_close $sf_outcomes

		tpBindVar SF_NAME  SFOC desc        sf_idx
		tpBindVar EvIdSF   SFOC ev_oc_id    sf_idx
		tpBindVar EvResSF  SFOC result      sf_idx
	#}

	set half_time_desc [get_score_result_desc $ev_id HF]

	if {$half_time_desc != ""} {
		set half_time_desc [split $half_time_desc /]
		set half_time_desc [lindex $half_time_desc 0]
	}

	tpBindString HALFTIME_DESC $half_time_desc
	tpBindString FULLTIME_DESC [get_score_result_desc $ev_id MR]
	tpBindString EvFBId        $ev_id
	tpBindString EV_START_TIME $EVTIME($ev_id)

	# Last team to score
	set lg_outcomes [get_scorer_outcomes $ev_id LG]
	set numLG       [db_get_nrows $lg_outcomes]

	OT_LogWrite 7 "Last team to score : $numLG"

	tpSetVar NumTeamLastGoal $numLG

	for {set i 0} {$i < $numLG} {incr i} {

		set rs [db_get_col $lg_outcomes $i result]

		set LGOC($i,ev_oc_id)      [db_get_col $lg_outcomes $i ev_oc_id]
		set LGOC($i,desc)          [db_get_col $lg_outcomes $i desc]
			set LGOC($i,settled)       [db_get_col $lg_outcomes $i settled]
			set LGOC($i,status)        [db_get_col $lg_outcomes $i status]
			set LGOC($i,displayed)     [db_get_col $lg_outcomes $i displayed]
		set LGOC($i,result)        [expr {($rs=="-")?"L":$rs}]
	}

	if {$numLG > 0} {
		set LGMktResultConf [db_get_col $lg_outcomes 0 result_conf]

		tpBindString LGMktResultConf $LGMktResultConf
		tpBindString LGMktSettled    [db_get_col $lg_outcomes 0 settled]
		tpBindString LGMktStatus     [db_get_col $lg_outcomes 0 status]
		tpBindString LGMktDisplayed  [db_get_col $lg_outcomes 0 displayed]
	}

	db_close $lg_outcomes

	tpBindVar LG_NAME  LGOC desc        lg_idx
	tpBindVar EvIdLG   LGOC ev_oc_id    lg_idx
	tpBindVar EvResLG  LGOC result      lg_idx

	# Time of first goal
	set gt_outcomes [get_scorer_outcomes $ev_id GT]
	set numGT       [db_get_nrows $gt_outcomes]

	OT_LogWrite 7 "Time of first goal : $numGT"

	tpSetVar NumTimeFirstGoal $numGT

	for {set i 0} {$i < $numGT} {incr i} {

		set rs [db_get_col $gt_outcomes $i result]

		set GTOC($i,ev_oc_id)      [db_get_col $gt_outcomes $i ev_oc_id]
		set GTOC($i,desc)          [db_get_col $gt_outcomes $i desc]
			set GTOC($i,settled)       [db_get_col $gt_outcomes $i settled]
			set GTOC($i,status)        [db_get_col $gt_outcomes $i status]
			set GTOC($i,displayed)     [db_get_col $gt_outcomes $i displayed]
		set GTOC($i,result)        [expr {($rs=="-")?"L":$rs}]
	}

	if {$numGT > 0} {
		set GTMktResultConf [db_get_col $gt_outcomes 0 result_conf]

		tpBindString GTMktResultConf $GTMktResultConf
		tpBindString GTMktSettled    [db_get_col $gt_outcomes 0 settled]
		tpBindString GTMktStatus     [db_get_col $gt_outcomes 0 status]
		tpBindString GTMktDisplayed  [db_get_col $gt_outcomes 0 displayed]
	}

	db_close $gt_outcomes

	tpBindVar GT_NAME  GTOC desc        gt_idx
	tpBindVar EvIdGT   GTOC ev_oc_id    gt_idx
	tpBindVar EvResGT  GTOC result      gt_idx

	# Corners
	set c3_outcomes [get_scorer_outcomes $ev_id C3]
	set numC3       [db_get_nrows $c3_outcomes]

	OT_LogWrite 7 "Corners : $numC3"

	tpSetVar NumCorners $numC3

	for {set i 0} {$i < $numC3} {incr i} {

		set rs [db_get_col $c3_outcomes $i result]

		set C3OC($i,ev_oc_id)      [db_get_col $c3_outcomes $i ev_oc_id]
		set C3OC($i,desc)          [db_get_col $c3_outcomes $i desc]
			set C3OC($i,settled)       [db_get_col $c3_outcomes $i settled]
			set C3OC($i,status)        [db_get_col $c3_outcomes $i status]
			set C3OC($i,displayed)     [db_get_col $c3_outcomes $i displayed]
		set C3OC($i,result)        [expr {($rs=="-")?"L":$rs}]
	}

	if {$numC3 > 0} {
		set C3MktResultConf [db_get_col $c3_outcomes 0 result_conf]

		tpBindString C3MktResultConf $C3MktResultConf
		tpBindString C3MktSettled    [db_get_col $c3_outcomes 0 settled]
		tpBindString C3MktStatus     [db_get_col $c3_outcomes 0 status]
		tpBindString C3MktDisplayed  [db_get_col $c3_outcomes 0 displayed]
	}

	db_close $c3_outcomes

	tpBindVar C3_NAME  C3OC desc        c3_idx
	tpBindVar EvIdC3   C3OC ev_oc_id    c3_idx
	tpBindVar EvResC3  C3OC result      c3_idx

	# Bookings
	set b3_outcomes [get_scorer_outcomes $ev_id B3]
	set numB3       [db_get_nrows $b3_outcomes]

	OT_LogWrite 7 "Bookings : $numB3"

	tpSetVar NumBookings $numB3

	for {set i 0} {$i < $numB3} {incr i} {

		set rs [db_get_col $b3_outcomes $i result]

		set B3OC($i,ev_oc_id)      [db_get_col $b3_outcomes $i ev_oc_id]
		set B3OC($i,desc)          [db_get_col $b3_outcomes $i desc]
			set B3OC($i,settled)       [db_get_col $b3_outcomes $i settled]
			set B3OC($i,status)        [db_get_col $b3_outcomes $i status]
			set B3OC($i,displayed)     [db_get_col $b3_outcomes $i displayed]
		set B3OC($i,result)        [expr {($rs=="-")?"L":$rs}]
	}

	if {$numB3 > 0} {
		set B3MktResultConf [db_get_col $b3_outcomes 0 result_conf]

		tpBindString B3MktResultConf $B3MktResultConf
		tpBindString B3MktSettled    [db_get_col $b3_outcomes 0 settled]
		tpBindString B3MktStatus     [db_get_col $b3_outcomes 0 status]
		tpBindString B3MktDisplayed  [db_get_col $b3_outcomes 0 displayed]
	}

	db_close $b3_outcomes

	tpBindVar B3_NAME  B3OC desc        b3_idx
	tpBindVar EvIdB3   B3OC ev_oc_id    b3_idx
	tpBindVar EvResB3  B3OC result      b3_idx

	catch {unset EVTIME}

	asPlayFile -nocache autoresult_FB.html

	catch {unset FBEVENTS}
	catch {unset FSOC}
	catch {unset LSOC}
	catch {unset GSOC}
	catch {unset SFOC}
	catch {unset LGOC}
	catch {unset GTOC}
	catch {unset C3OC}
	catch {unset B3OC}
}


proc go_ev_res_BB args {

	global BBEVENTS

	catch {unset BBEVENTS}

	tpBindString TypeId [reqGetArg TypeId]

	set ev_id [reqGetArg EvId]
	set res   [get_all_started_events BB WH]
	set numEv [db_get_nrows $res]

	tpSetVar NumEvents $numEv

	if {$ev_id == ""} {
		if {$numEv > 0} {
			set ev_id [db_get_col $res 0 ev_id]
		} else {
			asPlayFile -nocache autoresult_BB.html
			db_close $res
			return
		}
	}

	show_match_result_BB $ev_id

	for {set i 0} {$i < $numEv} {incr i} {

		set BBEVENTS($i,ev_id) [db_get_col $res $i ev_id]
		set BBEVENTS($i,desc)  [db_get_col $res $i desc]

		set EVTIME($BBEVENTS($i,ev_id))	[db_get_col $res $i start_time]
	}

	db_close $res

	tpBindVar Ev_Id   BBEVENTS ev_id ev_idx
	tpBindVar Ev_Name BBEVENTS desc  ev_idx

	tpBindString FULLTIME_DESC [get_score_result_desc $ev_id MR]
	tpBindString EvId          $ev_id
	tpBindString EV_START_TIME $EVTIME($ev_id)

	catch {unset EVTIME}

	asPlayFile -nocache autoresult_BB.html

	catch {unset BBEVENTS}
}



#
# ----------------------------------------------------------------------------
# Create string binds for HT/FT results
# ----------------------------------------------------------------------------
#
proc show_match_result_FB {ev_id} {

	set ht_home [reqGetArg HalfTimeHome]
	set ht_away [reqGetArg HalfTimeAway]
	set ft_home [reqGetArg FullTimeHome]
	set ft_away [reqGetArg FullTimeAway]


	set ht_result [get_match_result $ev_id HT]

	OT_LogWrite 7 "Half Time result: $ht_result"

	if {$ht_result != ""} {
		set ht_res_list [split $ht_result "|"]
		if {$ht_home==""} {
			set ht_home [lindex $ht_res_list 0]
		}
		if {$ht_away==""} {
			set ht_away [lindex $ht_res_list 1]
		}
	}

	set ft_result [get_match_result $ev_id FT]

	OT_LogWrite 7 "Full Time result: $ft_result"

	if {$ft_result != ""} {
		set ft_res_list [split $ft_result "|"]
		if {$ft_home==""} {
			set ft_home [lindex $ft_res_list 0]
		}
		if {$ft_away==""} {
			set ft_away [lindex $ft_res_list 1]
		}
	}

	tpBindString HalfTimeHome $ht_home
	tpBindString HalfTimeAway $ht_away
	tpBindString FullTimeHome $ft_home
	tpBindString FullTimeAway $ft_away
}

proc show_match_result_BB {ev_id} {

	set FT_H [reqGetArg FT_H]
	set FT_A [reqGetArg FT_A]

	if {[set ft_result [get_match_result $ev_id FT]] != ""} {
		set ft_res_list [split $ft_result "|"]
		if {$FT_H==""} {
			set FT_H [lindex $ft_res_list 0]
		}
		if {$FT_A==""} {
			set FT_A [lindex $ft_res_list 1]
		}
	}

	tpBindString FT_H $FT_H
	tpBindString FT_A $FT_A
}


#
# ----------------------------------------------------------------------------
# Get all started events with given market
# ----------------------------------------------------------------------------
#
proc get_all_started_events {class_sort mkt_sort} {

	global DB

	set type_id [reqGetArg TypeId]

	set where ""

	if {$type_id != ""} {
		if {$type_id != 0} {
			set cs [split $type_id :]
			if {[lindex $cs 0] == "C"} {
				set where " c.ev_class_id=[lindex $cs 1] and"
			} else {
				set where " t.ev_type_id=$type_id and"
			}
		}
	}

	set sql [subst {
		select
			e.ev_id,
			e.desc,
			e.start_time,
			date(e.start_time) as start_date
		from
			tEvClass c,
			tEvType t,
			tEvUnStl eu,
			tEv e
 		where
			c.sort = ? and
			c.ev_class_id = t.ev_class_id and
			t.ev_type_id = eu.ev_type_id and
			$where
			eu.ev_id = e.ev_id and
			exists (
				select 1
				from   tEvMkt m
				where  m.ev_id = e.ev_id and m.sort = ?
			) and
			e.result_conf = 'N' and
			e.sort = 'MTCH' and
			e.start_time < CURRENT
		order by
			start_time, desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $class_sort $mkt_sort]
	inf_close_stmt $stmt

	return $res
}


proc get_scorer_outcomes {ev_id sort} {

	global DB

	set sql [subst {
		select
			o.ev_oc_id,
			o.desc,
			o.result,
			m.result_conf,
			m.settled,
			m.status,
			m.displayed
		from
			tEvMkt m,
			tEvOc o
		where
			m.ev_id = ?
		and m.sort = ?
		and o.ev_mkt_id = m.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_id $sort]
	inf_close_stmt $stmt

	return $res
}


proc get_match_result {ev_id sort} {

	global DB

	set sql [subst {
		select
			result
		from
			tResult
		where
			ev_id = ? and sort  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_id $sort]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {
		set ret [db_get_col $res 0 result]
	} else {
		set ret ""
	}
	db_close $res
	return $ret
}


proc set_match_result {ev_id sort home away} {

	global DB USERNAME

	set result "$home|$away"

	# Check that market is not already confirmed
	set sql [subst {
		select
			result_conf
		from
			tEv
		where
			ev_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_id]

	if {[db_get_nrows $res] !=1 } {
		inf_close_stmt $stmt
		catch {db_close $res}
		set msg "Unable to find event with ev_id=$ev_id"
		OT_LogWrite 5 $msg
		err_bind $msg
		#return 0
		error $msg
	}

	if {[db_get_col $res 0 result_conf] == "Y"} {
		inf_close_stmt $stmt
		catch {db_close $res}
		set msg "This event has already been confirmed and cannot be changed (ev_id=$ev_id)"
		OT_LogWrite 5 $msg
		err_bind $msg
		#return 0
		error $msg
	}

	inf_close_stmt $stmt

	# If the result is "", we want to set the result in the db to null
	if {$result == ""} {
		set sql {
			execute procedure pSetResult(
				p_ev_id = ?,
				p_sort = ?,
				p_adminuser = ?
			)
		}
	} else {
	set sql {
			execute procedure pSetResult(
				p_ev_id = ?,
				p_sort = ?,
				p_result = ?,
				p_adminuser = ?
			)
		}
	}

	set stmt [inf_prep_sql $DB $sql]

	if {$result == ""} {
		set c [catch {
			inf_exec_stmt $stmt $ev_id $sort $USERNAME
		} msg]
	} else {
		set c [catch {
			inf_exec_stmt $stmt $ev_id $sort $result $USERNAME
		} msg]
	}

	inf_close_stmt $stmt

	if {$c} {
		err_bind $msg
		return 0
	}
	return 1
}


proc get_score_result_desc {ev_id sort} {

	global DB

	set sql [subst {
		select
			o.desc
		from
			tEvOc o,
			tEv e,
			tEvMkt m
		where
			o.ev_id = e.ev_id
		and	o.ev_mkt_id = m.ev_mkt_id
		and	o.result = "W"
		and m.sort = '$sort'
		and e.ev_id = $ev_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {
		set desc [db_get_col $res 0 desc]
	} else {
		set desc ""
	}
	db_close $res
	return $desc
}


#
# ----------------------------------------------------------------------------
# Update the actual result
# ----------------------------------------------------------------------------
#
proc do_ev_res_FB args {

	set act [reqGetArg SubmitName]

	if {
		   $act == "EvUpdResFB"
		|| $act == "EvUpdResFBFS"
		|| $act == "EvUpdResFBLS"
		|| $act == "EvUpdResFBLG"
		|| $act == "EvUpdResFBSF"
		|| $act == "EvUpdResFBGT"
		|| $act == "EvUpdResFBC3"
		|| $act == "EvUpdResFBB3"
		|| $act == "EvUpdResFBGS"
	} {
		if {[catch {
			do_ev_upd_res_FB 1
		} msg]} {
			err_bind $msg
			autores_error FB
		} else {
			go_ev_res_FB
		}
	} elseif {$act == "EvVoid"} {
		do_ev_void [reqGetArg EvFBId]
	} elseif {$act == "EvChanged"} {
		go_ev_res_FB
	} elseif {$act == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}

proc do_ev_res_BB args {

	set act [reqGetArg SubmitName]

	if {$act == "EvUpdResBB"} {
		do_ev_upd_res_BB
	} elseif {$act == "EvChanged"} {
		go_ev_res_BB
	} elseif {$act == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}

#
# ----------------------------------------------------------------------------
# Void all outcomes for an event (srobins 08/2002)
# ----------------------------------------------------------------------------
#
proc do_ev_void {ev_id} {

	global DB USERNAME

	set sql {
		select
			ev_oc_id
		from
			tevoc
		where
			ev_mkt_id in (
			select
				ev_mkt_id
			from
				tevmkt
			where
				ev_id = ? and
				result_conf = "N"
			)
	}
	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_id]
	inf_close_stmt $stmt


	set sql {
		execute procedure pSetEvOcResult(
			p_adminuser = ?,
			p_ev_oc_id  = ?,
			p_result    = 'V'
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	set n [db_get_nrows $res]
	inf_begin_tran $DB
	if [catch {
			for {set i 0} {$i < $n} {incr i} {
				set ev_oc_id [db_get_col $res $i ev_oc_id]
				inf_exec_stmt $stmt $USERNAME $ev_oc_id
			}
	} msg] {
		inf_rollback_tran $DB
		err_bind "Failed to void results"
		autores_error FB
		OT_LogWrite 4 "$msg"
		return
	}
	inf_commit_tran $DB
	db_close $res
	tpSetVar ResultUpdated 1
	go_ev_res_FB
}

#
# ----------------------------------------------------------------------------
# Result Update
# ----------------------------------------------------------------------------
#
proc do_ev_upd_res_FB {trans} {
	# If trans it set to 1, inf_begin_tran and inf_commit_tran etc are used
	# If 0, the calling procedure wil handle the transaction.

	global DB FSOC LSOC LGOC GTOC SFOC C3OC B3OC GSOC

	set ev_id [reqGetArg EvFBId]

	catch {unset FSOC}
	catch {unset LSOC}
	catch {unset GSOC}
	catch {unset LGOC}
	catch {unset GTOC}
	catch {unset SFOC}
	catch {unset C3OC}
	catch {unset B3OC}

	set fsonly    [reqGetArg FSOnly]
	set lsonly    [reqGetArg LSOnly]
	set gsonly    [reqGetArg GSOnly]
	set scoreonly [reqGetArg ScoreOnly]
	set lgonly    [reqGetArg LGOnly]
	set gtonly    [reqGetArg GTOnly]
	set sfonly    [reqGetArg SFOnly]
	set c3only    [reqGetArg C3Only]
	set b3only    [reqGetArg B3Only]
	set setresult [reqGetArg SetResult]

	ob::log::write INFO {fsonly: $fsonly  lsonly: $lsonly sfonly: $sfonly  lgonly: $lgonly gtonly: $gtonly \
				 c3only : $c3only b3only : $b3only gsonly $gsonly : setresult: $setresult}

	if {$scoreonly != "" || $setresult != ""} {
		# We are not specifically setting the first / last scorer

		#
		# Check that scores are ok
		#
		set sc(HT_H) [reqGetArg HalfTimeHome]
		set sc(HT_A) [reqGetArg HalfTimeAway]
		set sc(FT_H) [reqGetArg FullTimeHome]
		set sc(FT_A) [reqGetArg FullTimeAway]

		foreach n {HT_H HT_A FT_H FT_A} {
			if {![regexp {^[0-9]+$} $sc($n)] && $sc($n) != ""} {
				error "The $n score must be a valid number"
			}
		}
		if {($sc(FT_H) != "" && $sc(HT_H) > $sc(FT_H)) || ($sc(FT_A) != "" && $sc(HT_A) > $sc(FT_A))} {
			error "HT > FT"
		}

		OT_LogWrite 3 "Autores: $sc(HT_H)-$sc(HT_A) ... $sc(FT_H)-$sc(FT_A)"
	}

	if {$fsonly != "" || $setresult != ""} {
		#
		# Get first scorer stuff
		#
		set fs_outcomes [get_scorer_outcomes $ev_id FS]

		set FSOC(entries) [set numFS [db_get_nrows $fs_outcomes]]

		for {set i 0} {$i < $numFS} {incr i} {
			set FSOC($i,ev_oc_id) [db_get_col $fs_outcomes $i ev_oc_id]
			set FSOC($i,result)   [reqGetArg E$FSOC($i,ev_oc_id)]
		}

		db_close $fs_outcomes
	}

	if {$lsonly != "" || $setresult != ""} {
		#
		# Get last scorer stuff
		#
		set ls_outcomes [get_scorer_outcomes $ev_id LS]

		set LSOC(entries) [set numLS [db_get_nrows $ls_outcomes]]

		for {set i 0} {$i < $numLS} {incr i} {
			set LSOC($i,ev_oc_id) [db_get_col $ls_outcomes $i ev_oc_id]
			set LSOC($i,result)   [reqGetArg E$LSOC($i,ev_oc_id)]
		}

		db_close $ls_outcomes
	}

	if {$gsonly != "" || $setresult != ""} {
		#
		# Get goalscorers stuff
		#
		set gs_outcomes [get_scorer_outcomes $ev_id GS]

		set GSOC(entries) [set numGS [db_get_nrows $gs_outcomes]]

		for {set i 0} {$i < $numGS} {incr i} {
			set GSOC($i,ev_oc_id) [db_get_col $gs_outcomes $i ev_oc_id]
			set GSOC($i,result)   [reqGetArg E$GSOC($i,ev_oc_id)]
		}

		db_close $gs_outcomes
		OT_LogWrite 5 "Finished"
	}


	if {$lgonly != "" || $setresult != ""} {
		#
		# Get last team to score stuff
		#
		set lg_outcomes [get_scorer_outcomes $ev_id LG]

		set LGOC(entries) [set numLG [db_get_nrows $lg_outcomes]]

		for {set i 0} {$i < $numLG} {incr i} {
			set LGOC($i,ev_oc_id) [db_get_col $lg_outcomes $i ev_oc_id]
			set LGOC($i,result)   [reqGetArg E$LGOC($i,ev_oc_id)]
		}

		db_close $lg_outcomes
	}

	if {$gtonly != "" || $setresult != ""} {
		#
		# Get time of goal stuff
		#
		set gt_outcomes [get_scorer_outcomes $ev_id GT]

		set GTOC(entries) [set numGT [db_get_nrows $gt_outcomes]]

		for {set i 0} {$i < $numGT} {incr i} {
			set GTOC($i,ev_oc_id) [db_get_col $gt_outcomes $i ev_oc_id]
			set GTOC($i,result)   [reqGetArg E$GTOC($i,ev_oc_id)]
		}

		db_close $gt_outcomes
	}

	if {$sfonly != "" || $setresult != ""} {
		#
		# Get first goalscorer for each team stuff
		#
		set sf_outcomes [get_scorer_outcomes $ev_id SF]

		set SFOC(entries) [set numSF [db_get_nrows $sf_outcomes]]

		for {set i 0} {$i < $numSF} {incr i} {
			set SFOC($i,ev_oc_id) [db_get_col $sf_outcomes $i ev_oc_id]
			set SFOC($i,result)   [reqGetArg E$SFOC($i,ev_oc_id)]
		}

		db_close $sf_outcomes
	}

	if {$c3only != "" || $setresult != ""} {
		#
		# Get corner stuff
		#
		set c3_outcomes [get_scorer_outcomes $ev_id C3]

		set C3OC(entries) [set numC3 [db_get_nrows $c3_outcomes]]

		for {set i 0} {$i < $numC3} {incr i} {
			set C3OC($i,ev_oc_id) [db_get_col $c3_outcomes $i ev_oc_id]
			set C3OC($i,result)   [reqGetArg E$C3OC($i,ev_oc_id)]
		}

		db_close $c3_outcomes
	}

	if {$b3only != "" || $setresult != ""} {
		#
		# Get bookings stuff
		#
		set b3_outcomes [get_scorer_outcomes $ev_id B3]

		set B3OC(entries) [set numB3 [db_get_nrows $b3_outcomes]]

		for {set i 0} {$i < $numB3} {incr i} {
			set B3OC($i,ev_oc_id) [db_get_col $b3_outcomes $i ev_oc_id]
			set B3OC($i,result)   [reqGetArg E$B3OC($i,ev_oc_id)]
		}

		db_close $b3_outcomes
	}

	set ok 1

	if {$trans} { inf_begin_tran $DB }

	set c [catch {
		if {$scoreonly != "" || $setresult != ""} {
			if {$ok && ![set_match_result $ev_id HT $sc(HT_H) $sc(HT_A)]} {
				set ok 0
			}
			if {$ok && ![set_match_result $ev_id FT $sc(FT_H) $sc(FT_A)]} {
				set ok 0
			}

			# Handle markets that do not require FT
			if {$ok && $sc(FT_H) != "" && $sc(FT_A) != ""} {
                # adding HL & MH
				foreach m {MR H1 H2 HF CS cs AH OU TG GC OE hl A2 QR DC WL GG\
							HT TG DN HL MH} {
					if {![do_ev_res_mkt FB $m $ev_id\
							H1 $sc(HT_H)\
							A1 $sc(HT_A)\
							H2 $sc(FT_H)\
							A2 $sc(FT_A)\
							H $sc(FT_H)\
							A $sc(FT_A)]} {
						set ok 0
						break
					}
				}
			}
		}

		if {($fsonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id FS]} {
			set ok 0
		}
		if {($lsonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id LS]} {
			set ok 0
		}
		if {($gsonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id GS]} {
			set ok 0
		}
		if {($sfonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id SF]} {
			set ok 0
		}
		if {($gtonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id GT]} {
			set ok 0
		}
		if {($lgonly != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id LG]} {
			set ok 0
		}
		if {($c3only != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id C3]} {
			set ok 0
		}
		if {($b3only != "" || $setresult != "") && $ok && ![do_ev_res_oc $ev_id B3]} {
			set ok 0
		}
	} msg]

	if {$c || !$ok} {
		if {$trans} {inf_rollback_tran $DB}
		error "failed to set results: $msg ok:$ok $c"
	}

	if {$trans} {inf_commit_tran $DB}

	tpSetVar ResultUpdated 1
	return 1
}

proc do_ev_upd_res_BB args {

	global DB

	set ev_id [reqGetArg EvId]

	#
	# Check that scores are ok
	#
	set sc(FT_H) [reqGetArg FT_H]
	set sc(FT_A) [reqGetArg FT_A]

	foreach n {FT_H FT_A} {
		if {![regexp {^[0-9]+$} $sc($n)]} {
			err_bind "The $n score must be a valid number"
			autores_error BB
			return
		}
	}

	OT_LogWrite 3 "Autores: $sc(FT_H)-$sc(FT_A)"

	set ok 1

	inf_begin_tran $DB

	set c [catch {

		if {$ok && ![set_match_result $ev_id FT $sc(FT_H) $sc(FT_A)]} {
			set ok 0
		}
		foreach m {WH OE HL} {
			if {![do_ev_res_mkt BB $m $ev_id\
					H $sc(FT_H)\
					A $sc(FT_A)]} {
				set ok 0
				break
			}
		}
	} msg]

	if {$c || !$ok} {
		inf_rollback_tran $DB
		autores_error BB
		err_bind "failed to set results"
		return
	}

	inf_commit_tran $DB

	tpSetVar ResultUpdated 1

	go_ev_res_BB
}

#
# Settle results for markets depending on the argument 'mode'
#
proc do_ev_res_oc {ev_id mode} {

	if {$mode == {FS}} {
		upvar FSOC local_array
	} elseif {$mode == {LS}} {
		upvar LSOC local_array
	} elseif {$mode == {GS}} {
		upvar GSOC local_array
	} elseif {$mode == {SF}} {
		upvar SFOC local_array
	} elseif {$mode == {GT}} {
		upvar GTOC local_array
	} elseif {$mode == {LG}} {
		upvar LGOC local_array
	} elseif {$mode == {C3}} {
		upvar C3OC local_array
	} elseif {$mode == {B3}} {
		upvar B3OC local_array
	}

	for {set i 0} {$i < $local_array(entries)} {incr i} {
		if {$local_array($i,result) != "" && ![set_result_for_outcome $local_array($i,ev_oc_id) $local_array($i,result)]} {
			return 0
		}
	}
	return 1
}

#
# Set results for a market.
#
# This procedure handles a variety of markets based on the detailed
# market configuration information.
#
proc do_ev_res_mkt {c_sort m_sort ev_id args} {


	#
	# Create local variables from the args array passed in - these are
	# craftily used in "expr" calls which evaluate strings read from the
	# configuration for each market, these strings contain references to
	# these variables...
	#
	foreach {n v} $args {
		set $n $v
	}


	#
	# Get selections
	#

	if { [info exists MKTID] && $MKTID != "" } {
		set rs    [get_event_outcomes_by_market $MKTID]
	} else {
		set rs    [get_event_outcomes $ev_id $m_sort]
	}

	if {![info exists REQ_GUID]} {
		set REQ_GUID {}
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 1
	}

	for {set r 0} {$r < $nrows} {incr r} {
		set SELN($r,ev_oc_id) [db_get_col $rs $r ev_oc_id]
		set SELN($r,tag)      [db_get_col $rs $r fb_result]
		set SELN($r,CSH)      [db_get_col $rs $r cs_home]
		set SELN($r,CSA)      [db_get_col $rs $r cs_away]
	}

	db_close $rs


	#
	# Get market configuration information
	#
	set set_res [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort set-res]
	set scores  [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort scores]
	set mtype   [ADMIN::MKTPROPS::mkt_type $c_sort $m_sort]


	#
	# set-res in the config file can take one of several values:
	#    implied   the result is implied from the results in other markets
	#              at settlement time (e.g. scorecast)
	#    special   a special procedure exists (in this file) to settle
	#              this sort of market
	#    manual    result settlement must be done manually (this is the
	#              same as not having a value for set-res
	#    handicap  this is a handicap market (either asian or standard). The
	#              market makeup is set by setting scores for each selection
	#    hilo      a higher/lower market. The market makeup is the sum of
	#              the scores for the two selections
	#
	if {$set_res == "" || $set_res == "manual"} {
		OT_LogWrite 1 "Autores ($c_sort/$m_sort): manual"
		return 1
	} elseif {$set_res == "implied"} {
		OT_LogWrite 1 "Autores ($c_sort/$m_sort): set-res = implied"
		return 1
	} elseif {$set_res == "special"} {
		OT_LogWrite 1 "Autores ($c_sort/$m_sort): set-res = special..."
		return 0
	}

	array set TAG   [list]
	array set SCORE [list]

	#
	# Hilo and over/under special treatment to set the market makeup.
	# The expression used to generate the makeup is in the market
	# configuration with the name "hcap-makeup"
	#
	if {$mtype == "L" || $mtype == "U" || $mtype == "l"} {

		set mu_str [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort hcap-makeup]
		set mu_val [expr $mu_str]

		OT_LogWrite 1 "Autores ($c_sort/$m_sort) : makeup $mu_str = $mu_val"

		if { [info exists MKTID] && $MKTID != "" } {
			update_handicap_market_makeup_specific $MKTID $mu_val $REQ_GUID
		} {
			update_handicap_market_makeup $ev_id $m_sort $mu_val $REQ_GUID
		}
		
	}

	#
	# Now set score (from expression) or tag result depending on
	# what the configuration set-res parameter says
	#
	if {$set_res == "handicap"} {

		foreach {tag exp} $scores {
			set SCORE($tag) $exp
			OT_LogWrite 1 "Autores ($c_sort/$m_sort): $tag = $exp"
		}

	} elseif {$set_res == "hilo"} {

	} else {

		foreach {tag exp} $set_res {
			set TAG($tag) $exp
			OT_LogWrite 1 "Autores ($c_sort/$m_sort): $tag = $exp"
		}

	}

	#
	# Set result flag for each selection
	#
	for {set r 0} {$r < $nrows} {incr r} {

		set ev_oc_id $SELN($r,ev_oc_id)
		set tag      $SELN($r,tag)
		set CSH      $SELN($r,CSH)
		set CSA      $SELN($r,CSA)

		if {$set_res == "handicap"} {

			set res H

			if {$tag != "L"} {
				set score [expr $SCORE($tag)]
				OT_LogWrite 1 "($m_sort,$tag) : $SCORE($tag) => $score"
			} else {
				# We don't need to set a score value for the line selection
				# as the hcap_makeup value will be worked out when we result
				# the 'H'ome and 'A'way selections
				set score ""
			}
		} elseif {$set_res == "hilo"} {
			set res H
			set score ""
			OT_LogWrite 1 "($m_sort,$tag): result = H"
		} else {
			set res   [expr $TAG($tag)]
			set score ""
			OT_LogWrite 1 "($m_sort,$tag): $TAG($tag) => $res"
		}

		if {[set_result_for_outcome $ev_oc_id $res $score $REQ_GUID] == 0} {
			OT_LogWrite 1 "set_result_for_outcome $ev_oc_id $res $score failed"
			return 0
		}
	}

	return 1
}


proc get_event_outcomes {ev_id sort} {

	global DB

	set sql [subst {
		select
			o.ev_oc_id,
			o.fb_result,
			o.cs_home,
			o.cs_away,
			m.hcap_value
		from
			tEvOc o,
			tEvMkt m
		where
			o.ev_mkt_id = m.ev_mkt_id
		and	o.result_conf = ?
		and	o.ev_id = ?
		and m.sort = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt N $ev_id $sort]
	inf_close_stmt $stmt
	return $res
}


proc get_event_outcomes_by_market {ev_mkt_id} {

        global DB

        set sql [subst {
                select
                        o.ev_oc_id,
                        o.fb_result,
                        o.cs_home,
                        o.cs_away,
                        m.hcap_value
                from
                        tEvOc o,
                        tEvMkt m
                where
			m.ev_mkt_id = ?
                and     o.ev_mkt_id = m.ev_mkt_id
                and     o.result_conf = ?
        }]

        set stmt [inf_prep_sql $DB $sql]
        set res [inf_exec_stmt $stmt $ev_mkt_id N]
        inf_close_stmt $stmt
        return $res
}


proc update_handicap_market_makeup {ev_id sort makeup {req_guid ""}} {

	global DB

	set sql {
		update
			tEvMkt
		set
			hcap_makeup = ?,
			req_guid = ?
		where
			 ev_id = ? and sort = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set ret [inf_exec_stmt $stmt $makeup $req_guid $ev_id $sort]
		db_close $ret
	} msg]

	inf_close_stmt $stmt

	if {$c} {
		err_bind $msg
		return 0
	}
	return 1
}

proc update_handicap_market_makeup_specific {ev_mkt_id makeup {req_guid""}} {

	global DB

	set sql {
		update
			tEvMkt
		set
			hcap_makeup = ?,
			req_guid = ?
		where
			 ev_mkt_id = ?
		}
	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set ret [inf_exec_stmt $stmt $makeup $req_guid $ev_mkt_id]
		db_close $ret
	} msg]

	inf_close_stmt $stmt

	if {$c} {
		err_bind $msg
		return 0
	}
	return 1
}


proc set_result_for_outcome {ev_oc_id result {hcap_score ""} {req_guid ""}} {

	global DB USERNAME

	set sql [subst {
		execute procedure pSetEvOcResult(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_result = ?,
			p_hcap_score = ?,
			p_req_guid = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set ret [inf_exec_stmt $stmt $USERNAME $ev_oc_id $result $hcap_score $req_guid]
	} msg]

	inf_close_stmt $stmt

	if {$c} {
		OT_LogWrite 1 "$msg"
		err_bind $msg
		return 0
	}
	return 1
}

# Used to upload quick results for halftime and fulltime
proc upload_qr {category class type name date half full} {
	global DB

	OT_LogWrite 5 "upload_qr: $category $class $type $name $date $half $full"

	# Validate scores
	if {![regexp {^(\d+)\-(\d+)$} $half unused hhome haway]} {
		set msg "Halftime is invalid"
		OT_LogWrite 1 $msg
		error $msg
	}

	# Case that they are only entering halftime scores
	if {$full == ""} {
		set fhome ""
		set faway ""
	} elseif {![regexp {^(\d+)\-(\d+)$} $full unused fhome faway]} {
		set msg "Fulltime is invalid"
		OT_LogWrite 1 $msg
		error $msg
	}

	# Date should already have been converted to yyyy-mm-dd hh:mm:ss

	# Retrieve the Event ID
	set sql [subst {
		select
			e.ev_id
		from
			tEvClass c,
			tEvType t,
			tEv e
		where
			c.category = ? and
			c.name = ? and
			t.name = ? and
			e.desc = ? and
			e.start_time = ? and
			c.ev_class_id = e.ev_class_id and
			e.ev_type_id = t.ev_type_id

	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $category $class $type $name $date]
	set rows [db_get_nrows $res]

	# Check what we got fom the db
	if {$rows != 1} {
		set msg "$rows row(s) returned from the database for this event"
		OT_LogWrite 1 "$msg"
		err_bind $msg
		error $msg
	}

	set event_id [db_get_col $res 0 ev_id]
	inf_close_stmt $stmt
	OT_LogWrite 5 "EventID $event_id found"

	# Update event in database
	reqSetArg EvFBId $event_id
	reqSetArg HalfTimeHome $hhome
	reqSetArg HalfTimeAway $haway
	reqSetArg FullTimeHome $fhome
	reqSetArg FullTimeAway $faway

	if {[catch {
		do_ev_upd_res_FB 0
	} msg]} {
		OT_LogWrite 1 "Error: $msg"
		error $msg
	}

	return 1
}


proc autores_error {class_sort} {
	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
		tpBindString [reqGetNthName $a] [reqGetNthVal $a]
	}
	go_ev_res_$class_sort 1
}

}
