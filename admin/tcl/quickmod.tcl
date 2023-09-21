# ==============================================================
# $Id: quickmod.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::QUICKMOD {

asSetAct ADMIN::QUICKMOD::GoSelEvent [namespace code go_sel_event]
asSetAct ADMIN::QUICKMOD::DoSelEvent [namespace code do_sel_event]
asSetAct ADMIN::QUICKMOD::DoModEvent [namespace code do_mod_event]
asSetAct ADMIN::QUICKMOD::GoSelSeln  [namespace code go_sel_seln]
asSetAct ADMIN::QUICKMOD::DoSelSeln  [namespace code do_sel_seln]
asSetAct ADMIN::QUICKMOD::DoModSeln  [namespace code do_mod_seln]
asSetAct ADMIN::QUICKMOD::DoSelnSearch [namespace code do_seln_search]

#
# ----------------------------------------------------------------------------
# Generate top-level list of event classes
# ----------------------------------------------------------------------------
#
proc bind_classes args {

	global DB CLASS

	set sql {
		select
			c.ev_class_id,
			c.name,
			c.disporder
		from
			tEvClass c
		where
			c.status = 'A'
		order by
			c.disporder,
			c.name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	for {set r 0} {$r < $rows} {incr r} {

		set CLASS($r,id)    [db_get_col $res $r ev_class_id]
		set CLASS($r,name)  [db_get_col $res $r name]
	}

	db_close $res

	tpSetVar NumClasses $rows

	tpBindVar ClassId   CLASS id   class_idx
	tpBindVar ClassName CLASS name class_idx
}


#
# ----------------------------------------------------------------------------
# Selection of event to "quick update"
# ----------------------------------------------------------------------------
#
proc go_sel_event args {

	global DB CLASS

	bind_classes

	tpSetVar SelSort Event

	tpBindString DefaultDate [clock format [clock seconds] -format "%y%m%d"]

	asPlayFile -nocache quick_ev_sel.html

	catch {unset CLASS}
}


proc do_sel_event args {

	global DB EVENT

	set class_id    [reqGetArg ClassId]
	set date        [string trim [reqGetArg EvDate]]
	set ev_shortcut [string trim [reqGetArg EvShortcut]]

	set date_str [get_eff_date $date]

	set d_lo "'$date_str 00:00:00'"
	set d_hi "'$date_str 23:59:59'"

	set where ""

	if {$ev_shortcut != ""}  {
		append where " and e.shortcut='$ev_shortcut'"
	}

	set sql [subst {
		select
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.start_time,
			e.status,
			e.disporder,
			e.displayed,
			e.settled,
			e.result_conf,
			e.shortcut
		from
			tEvtype  t,
			tEv      e
		where
			t.ev_class_id = $class_id and
			t.ev_type_id = e.ev_type_id and
			e.start_time between $d_lo and $d_hi and
			e.shortcut is not null and e.shortcut <> ''
			$where
		order by
			e.start_time asc, e.disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar event_rows [set rows [db_get_nrows $res]]

	array set EVENT [list]

	for {set r 0} {$r < $rows} {incr r} {

		set result_conf [db_get_col $res $r result_conf]
		set settled     [db_get_col $res $r settled]

		set updateable [expr {$result_conf == "N" && $settled == "N"}]

		set EVENT($r,type)       [db_get_col $res $r type_name]
		set EVENT($r,shortcut)   [db_get_col $res $r shortcut]
		set EVENT($r,ev_id)      [db_get_col $res $r ev_id]
		set EVENT($r,desc)       [db_get_col $res $r desc]
		set EVENT($r,start_time) [db_get_col $res $r start_time]
		set EVENT($r,status)     [db_get_col $res $r status]
		set EVENT($r,updateable) $updateable
	}

	tpBindVar EvType        EVENT type        event_idx
	tpBindVar EvShortcut    EVENT shortcut    event_idx
	tpBindVar EvId          EVENT ev_id       event_idx
	tpBindVar EvDesc        EVENT desc        event_idx
	tpBindVar EvStartTime   EVENT start_time  event_idx
	tpBindVar EvUpdateable  EVENT updateable  event_idx
	tpBindVar EvStatus      EVENT status      event_idx
	tpBindVar EvDisplayed   EVENT displayed   event_idx
	tpBindVar EvResultConf  EVENT result_conf event_idx
	tpBindVar EvSettled     EVENT settled     event_idx

	asPlayFile -nocache quick_event_upd.html

	db_close $res
}


proc do_mod_event args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		go_sel_event
		return
	}

	#
	# Get list of selection ids which have been modified
	#
	set upd_list [list]

	foreach ev_id [reqGetArgs EvId] {
		set old_status [reqGetArg iEvStatus_$ev_id]
		set new_status [reqGetArg  EvStatus_$ev_id]
		set old_start  [reqGetArg iEvStart_$ev_id]
		set new_start  [reqGetArg  EvStart_$ev_id]

		if {$old_status != $new_status || $old_start != $new_start} {
			lappend upd_list [list $ev_id $new_status $new_start]
		}
	}

	set sql {
		execute procedure pQuickUpdEv (
			p_adminuser = ?,
			p_aux_user_id = ?,
			p_ev_id = ?,
			p_status = ?,
			p_start_time = ?
		)
	}


	if {[llength $upd_list] > 0} {

		set aux_user_id ""

		#
		# If aux confirmation is needed for critical event changes,
		# make the check
		#
		if {[OT_CfgGetTrue FUNC_CONF_CRIT_EV_CHNG]} {
			set r [ADMIN::EVENT::do_ev_auxconf_check]
			if {[lindex $r 0] != "OK"} {
				err_bind [lindex $r 1]
				go_sel_event
				return
			}
			set aux_user_id [lindex $r 1]
		}

		set stmt [inf_prep_sql $DB $sql]

		inf_begin_tran $DB

		set r [catch {

			foreach upd $upd_list {

				set ev_id  [lindex $upd 0]
				set status [lindex $upd 1]
				set start  [lindex $upd 2]

				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$aux_user_id\
					$ev_id\
					$status\
					$start]

				db_close $res
			}

		} msg]

		inf_close_stmt $stmt

		if {$r} {
			inf_rollback_tran $DB
			err_bind $msg
			do_sel_event
			return
		}

		inf_commit_tran $DB
	}

	tpSetVar     ShowMsg 1
	tpBindString Msg     "[llength $upd_list] events updated"

	go_sel_event
}


#
# ----------------------------------------------------------------------------
# Selection of selection to "quick update"
# ----------------------------------------------------------------------------
#
proc go_sel_seln args {

	global DB CLASS

	bind_classes

	tpSetVar SelSort Seln

	tpBindString DefaultDate [clock format [clock seconds] -format "%y%m%d"]

	asPlayFile -nocache quick_ev_sel.html

}

proc do_sel_seln args {

	global DB SELN

	set class_id    [reqGetArg ClassId]
	set date        [string trim [reqGetArg EvDate]]
	set ev_shortcut [string trim [reqGetArg EvShortcut]]
	set oc_shortcut [string trim [reqGetArg OcShortcut]]

	if {[string length $ev_shortcut] != 2} {
		err_bind "please enter an event shortcut"
		go_sel_seln
		return
	}

	set date_str [get_eff_date $date]

	set d_lo "'$date_str 00:00:00'"
	set d_hi "'$date_str 23:59:59'"

	set sql [subst {
		select
			e.desc,
			e.start_time,
			e.ev_id
		from
			tEvtype  t,
			tEv      e
		where
			t.ev_class_id = $class_id and
			t.ev_type_id = e.ev_type_id and
			e.start_time between $d_lo and $d_hi and
			e.shortcut is not null and e.shortcut <> '' and
			e.shortcut = '$ev_shortcut'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows == 1} {
		set ev_id [db_get_col $res 0 ev_id]

		tpBindString EvStartTime [db_get_col $res 0 start_time]
		tpBindString EvDesc      [db_get_col $res 0 desc]
		tpBindString EvId        $ev_id
	}
	db_close $res

	if {$rows != 1} {
		err_bind "Number of markets with shortcut $ev_shortcut = $rows (must be 1)"
		go_sel_seln
		return
	}

	set where ""

	if {$oc_shortcut != ""} {
		set where "and s.shortcut = '$oc_shortcut'"
	}

	set sql [subst {
		select
			g.name,
			m.sort,
			m.disporder,
			m.ev_mkt_id,
			s.ev_oc_id,
			s.desc,
			s.shortcut,
			s.status,
			s.result_conf,
			s.settled,
			s.lp_num,
			s.lp_den
		from
			tEvMkt m,
			tEvOc s,
			tEvOcGrp g
		where
			m.ev_id = $ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id = s.ev_mkt_id and
			s.shortcut is not null and s.shortcut <> ''
			$where
		order by
			m.disporder,
			s.shortcut
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows == 0} {
		db_close $res
		err_bind "No selections match criteria"
		go_sel_seln
		return
	}

	array set SELN [list]

	set m_ix   -1
	set c_mkt  ""

	for {set r 0} {$r < $rows} {incr r} {

		set mkt   [db_get_col $res $r name]

		if {$mkt != $c_mkt} {
			incr m_ix
			set  s_ix 0
			set SELN($m_ix,name)  $mkt
			set SELN($m_ix,sort)  [db_get_col $res $r sort]
			set c_mkt $mkt
		}

		set lp_num [db_get_col $res $r lp_num]
		set lp_den [db_get_col $res $r lp_den]

		set SELN($m_ix,$s_ix,desc)        [db_get_col $res $r desc]
		set SELN($m_ix,$s_ix,ev_oc_id)    [db_get_col $res $r ev_oc_id]
		set SELN($m_ix,$s_ix,shortcut)    [db_get_col $res $r shortcut]
		set SELN($m_ix,$s_ix,status)      [db_get_col $res $r status]
		set SELN($m_ix,$s_ix,result_conf) [db_get_col $res $r result_conf]
		set SELN($m_ix,$s_ix,settled)     [db_get_col $res $r settled]
		set SELN($m_ix,$s_ix,lp)          [mk_price $lp_num $lp_den]

		set SELN($m_ix,count) [incr s_ix]
	}

	db_close $res

	tpSetVar mkt_count [expr {$m_ix+1}]

	tpBindVar MktName      SELN name        mkt_idx
	tpBindVar MktSort      SELN sort        mkt_idx
	tpBindVar OcId         SELN ev_oc_id    mkt_idx seln_idx
	tpBindVar OcDesc       SELN desc        mkt_idx seln_idx
	tpBindVar OcShortcut   SELN shortcut    mkt_idx seln_idx
	tpBindVar OcStatus     SELN status      mkt_idx seln_idx
	tpBindVar OcResultConf SELN result_conf mkt_idx seln_idx
	tpBindVar OcSettled    SELN settled     mkt_idx seln_idx
	tpBindVar OcPrice      SELN lp          mkt_idx seln_idx

	asPlayFile -nocache quick_seln_upd.html
}


proc do_mod_seln args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		go_sel_seln
		return
	}

	#
	# Get list of selection ids which have been modified
	#
	set upd_list [list]

	foreach oc_id [reqGetArgs OcId] {
		set old_status [reqGetArg iOcStatus_$oc_id]
		set new_status [reqGetArg  OcStatus_$oc_id]
		set old_price  [reqGetArg iOcPrice_$oc_id]
		set new_price  [reqGetArg  OcPrice_$oc_id]

		if {$old_status != $new_status || $old_price != $new_price} {
			lappend upd_list [list $oc_id $new_status $new_price]
		}
	}

	set sql {
		execute procedure pQuickUpdEvOc(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_status = ?,
			p_lp_num = ?,
			p_lp_den = ?
		)
	}

	if {[llength $upd_list] > 0} {

		set stmt [inf_prep_sql $DB $sql]

		inf_begin_tran $DB

		set r [catch {

			foreach upd $upd_list {

				set ev_oc_id    [lindex $upd 0]
				set status      [lindex $upd 1]
				set price       [lindex $upd 2]

				set price_parts [get_price_parts $price]

				set lp_num [lindex $price_parts 0]
				set lp_den [lindex $price_parts 1]

				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$ev_oc_id\
					$status\
					$lp_num\
					$lp_den]

				db_close $res
			}

		} msg]

		inf_close_stmt $stmt

		if {$r} {
			inf_rollback_tran $DB
			err_bind $msg
			do_sel_seln
			return
		}

		inf_commit_tran $DB
	}

	tpSetVar     ShowMsg 1
	tpBindString Msg     "[llength $upd_list] selections updated"

	go_sel_seln
}


#
# ----------------------------------------------------------------------------
# Make a YYYY-MM-DD date string based on [[YY]MM]DD input string
# ----------------------------------------------------------------------------
#
proc get_eff_date {date} {

	set t_now [clock seconds]

	set y [set Y [string trimleft [clock format $t_now -format %y] 0]]
	set m [set M [string trimleft [clock format $t_now -format %m] 0]]
	set d [set D [string trimleft [clock format $t_now -format %d] 0]]

	if {[string length $date] == 2} {
		set d [string trimleft $date 0]
		if {$d < $D} {
			if {[incr m] > 12} {
				incr y
				set m 1
			}
		}
	} elseif {[string length $date] == 4} {
		set d [string trimleft [string range $date 2 3] 0]
		set m [string trimleft [string range $date 0 1] 0]
		if {$m < $M} {
			incr y
		}
	} elseif {[string length $date] == 6} {
		set d [string trimleft [string range $date 4 5] 0]
		set m [string trimleft [string range $date 2 3] 0]
		set y [string trimleft [string range $date 0 1] 0]
	}

	if {$m <  1} { set m  1 }
	if {$m > 12} { set m 12 }
	if {$d <  1} { set d  1 }

	if {$d > [set md [days_in_month $m $y]]} {
		set d $md
	}

	return [format %04d-%02d-%02d [incr y 2000] $m $d]
}
}
