# $Id: openbet_cleanup.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CLEANUP {



asSetAct ADMIN::CLEANUP::GoUnstlEvSel         [namespace code go_unstl_ev_sel]
asSetAct ADMIN::CLEANUP::DoMktStlCleanup      [namespace code do_mkt_stl_cleanup]
asSetAct ADMIN::CLEANUP::GoUnstlEvQueue       [namespace code go_mkt_stl_cleanup_queue]
asSetAct ADMIN::CLEANUP::GoNoBetSettleCleanup [namespace code go_nobet_stl_cleanup]
asSetAct ADMIN::CLEANUP::GoBackUnstlEvList    [namespace code go_back_unstl_ev_list]

asSetAct ADMIN::CLEANUP::GoCouponCleanup      [namespace code go_coupon_cleanup_list]
asSetAct ADMIN::CLEANUP::DoCouponCleanup      [namespace code do_coupon_cleanup]
asSetAct ADMIN::CLEANUP::GoEmptyEvCleanup     [namespace code go_empty_ev_cleanup_list]
asSetAct ADMIN::CLEANUP::DoEmptyEventCleanup  [namespace code do_empty_ev_cleanup]
asSetAct ADMIN::CLEANUP::DoEmptyMarketCleanup [namespace code do_empty_mkt_cleanup]



#
# prepare the search forms for cleaning up markets, coupons, and empty events
#
proc go_unstl_ev_sel args {

	make_class_type_sort_binds
	make_category_binds 0 [list] 1

	asPlayFile unsettled_event_sel.html
}



#
# adds/removes market to a queue (in tSettleMsg)
# for future settlement by a cron job
#
proc do_mkt_stl_cleanup {} {

	set which [reqGetArg SubmitName]
	set back_type [reqGetArg BackType]
	ob::log::write INFO {=> do_mkt_stl_cleanup. Type: ${which}}

	if {![op_allowed Settle]} {
		err_bind "You don't have permission to quick settle events"
		go_unstl_ev_sel
		return
	}

	if {$which == "AddToQueue"} {
		do_mkt_cleanup_add
	} elseif {$which == "AddToQueueEvLvl"} {
		do_mkt_cleanup_ev_lvl_add
	} elseif {$which == "RemoveFromQueue"} {
		do_mkt_cleanup_remove
	} elseif {$which == "Back"} {
		if {$back_type == 0} {
			go_unstl_ev_sel
		} else {
			go_back_unstl_ev_list
		}
	} else {
		ob::log::write ERROR {=> do_mkt_stl_cleanup. Invalid request type : ${which}}
		err_bind "Unexpected SubmitName: $which. No markets were deleted/added to the settlement queue"
		go_unstl_ev_sel
	}
}



#
# adds markets to the automated settlement queue
#
proc do_mkt_cleanup_add {} {

	global DB USERID

	ob::log::write INFO {=> do_mkt_cleanup_add}

	set no_mkts     [reqGetArg NumMkts]

	if {![op_allowed AllowVoidAutoStl]} {
		set auto_result "V"
	} else {
		set auto_result [reqGetArg AutoResult]
	}

	if {![op_allowed AllowAutoUndisplay]} {
		set auto_display ""
	} else {
		set auto_display [reqGetArg AutoDisplay]
	}

	set sql {
		insert into
			tSettleMsg(user_id,ev_mkt_id,ev_displayed,ev_status,mkt_displayed,mkt_status,auto_result,auto_display)
		values
			(?,?,?,?,?,?,?,?)
	}
	set stmt [inf_prep_sql $DB $sql]

	set errors ""
	set no_insert 0

	for {set i 0} {$i < $no_mkts} {incr i} {
		set ev_mkt_id [reqGetArg ev_mkt_id_${i}]
		if {[reqGetArg stl_${ev_mkt_id}] == "Y"} {
			# add to the settlement queue
			incr no_insert

			set ev_displayed   [reqGetArg ev_disp_${ev_mkt_id}]
			set ev_status      [reqGetArg ev_status_${ev_mkt_id}]
			set mkt_displayed  [reqGetArg mkt_disp_${ev_mkt_id}]
			set mkt_status     [reqGetArg mkt_status_${ev_mkt_id}]

			if {[catch {set res  [inf_exec_stmt $stmt $USERID $ev_mkt_id $ev_displayed $ev_status $mkt_displayed $mkt_status $auto_result $auto_display]} msg]} {
				ob::log::write ERROR {Failed to add ev_mkt_id: ${ev_mkt_id} to the message queue. Msg: $msg}
				set mkt_desc [reqGetArg mkt_desc_${ev_mkt_id}]
				append errors "<br>Failed to add: ${mkt_desc} to the settlement queue"
			} else {
				ob::log::write INFO {=> do_mkt_stl_cleanup. Ev_mkt_id: ${ev_mkt_id} successfully added to the settlement queue.}
				db_close $res
			}
		}
	}

	inf_close_stmt $stmt

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$no_insert == 0} {
			err_bind "No markets were selected for addition to the settlement queue"
		} else {
			msg_bind "All selected markets were succesfully added to the settlement queue"
		}
	}

	go_mkt_stl_cleanup_queue
}



#
# adds markets to the automated settlement queue
#
proc do_mkt_cleanup_ev_lvl_add {} {

	global DB USERID

	ob::log::write INFO {=> do_mkt_cleanup_ev_lvl_add}

	# get the search terms that were used for the initial markets query
	set event_args    [reqGetArg EventArgs]
	set rs            [split $event_args |]
	set mkt_status    [lindex $rs 5]
	set mkt_displayed [lindex $rs 7]
	set is_bir        [lindex $rs 11]
	set a_result      [lindex $rs 12]
	set a_display     [lindex $rs 13]

	set no_evts       [reqGetArg NumEvts]

	if {![op_allowed AllowVoidAutoStl]} {
		set auto_result "V"
	} else {
		set auto_result $a_result
	}

	if {![op_allowed AllowAutoUndisplay]} {
		set auto_display ""
	} else {
		set auto_display $a_display
	}

	set where ""
	if {$mkt_status != "-"} {
		append where " and m.status='$mkt_status'"
	}
	if {$mkt_displayed != "-"} {
		append where " and m.displayed='$mkt_displayed'"
	}
	if {$is_bir != "-" && $is_bir != ""} {
		append where "and m.bet_in_run ='$is_bir'"
	}

	set sql [subst {
		select distinct
			e.displayed ev_displayed,
			e.status ev_status,
			g.name mkt_name,
			m.displayed mkt_displayed,
			m.status mkt_status,
			m.ev_mkt_id
		from
			tEvUnStl u,
			tEv e,
			tEvMkt m,
			tEvOcGrp g
		where
			u.ev_id        = e.ev_id and
			e.ev_id        = m.ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.settled      != 'Y' and
			not exists (select 1 from tOBet, tEvOc where tOBet.ev_oc_id = tEvOc.ev_oc_id and tEvOc.ev_mkt_id = m.ev_mkt_id) and
			not exists (select 1 from tPBet, tEvOc where tPBet.ev_oc_id = tEvOc.ev_oc_id and tEvOc.ev_mkt_id = m.ev_mkt_id) and
			not exists (select 1 from tSettleMsg where m.ev_mkt_id = tSettleMsg.ev_mkt_id) and
			e.ev_id = ?
			$where}]

	set stmt1 [inf_prep_sql $DB $sql]

	set sql {
		insert into
			tSettleMsg(user_id,ev_mkt_id,ev_displayed,ev_status,mkt_displayed,mkt_status,auto_result,auto_display)
		values
			(?,?,?,?,?,?,?,?)
	}
	set stmt2 [inf_prep_sql $DB $sql]

	set errors ""
	set no_insert 0

	for {set i 0} {$i < $no_evts} {incr i} {
		# will add all the markets for this event
		set ev_id     [reqGetArg ev_id_${i}]

		if {[reqGetArg stlev_${i}] == "Y"} {
			# get the markets
			set mkt_rs [inf_exec_stmt $stmt1 $ev_id]
			set nrows   [db_get_nrows $mkt_rs]

			for {set r 0} {$r < $nrows} {incr r} {
				incr no_insert
				set ev_mkt_id     [db_get_col $mkt_rs $r ev_mkt_id]
				set mkt_displayed [db_get_col $mkt_rs $r mkt_displayed]
				set mkt_status    [db_get_col $mkt_rs $r mkt_status]
				set ev_displayed  [db_get_col $mkt_rs $r ev_displayed]
				set ev_status     [db_get_col $mkt_rs $r ev_status]
				if {[catch {set res  [inf_exec_stmt $stmt2 $USERID $ev_mkt_id $ev_displayed $ev_status $mkt_displayed $mkt_status $auto_result $auto_display]} msg]} {
					ob::log::write ERROR {Failed to add ev_mkt_id: ${ev_mkt_id} to the message queue. Msg: $msg}
					set mkt_desc [db_get_col $mkt_rs $r mkt_name]
					append errors "<br>Failed to add: ${mkt_desc} to the settlement queue"
				} else {
					ob::log::write INFO {=> do_mkt_cleanup_ev_lvl_add. Ev_mkt_id: ${ev_mkt_id} successfully added to the settlement queue.}
					db_close $res
				}
			}
			db_close $mkt_rs
		}
	}

	inf_close_stmt $stmt1
	inf_close_stmt $stmt2

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$no_insert == 0} {
			err_bind "No markets were selected for addition to the settlement queue"
		} else {
			msg_bind "All selected markets were succesfully added to the settlement queue"
		}
	}

	go_mkt_stl_cleanup_queue
}



#
# removes markets from the automated settlement queue
#
proc do_mkt_cleanup_remove {} {

	global DB USERID

	ob::log::write INFO {=> do_mkt_cleanup_remove}

	set no_mkts     [reqGetArg NumQueuedMkts]

	set sql {
		delete from
			tSettleMsg
		where
			ev_mkt_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set errors ""
	set no_delete 0

	for {set i 0} {$i < $no_mkts} {incr i} {
		set ev_mkt_id [reqGetArg queue_mkt_id_${i}]
		if {[reqGetArg remove_${ev_mkt_id}] == "Y"} {
			incr no_delete
			if {[catch {set res  [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
				ob::log::write ERROR {=> do_mkt_stl_cleanup. Failed to delete ev_mkt_id: ${ev_mkt_id} from the message queue. Msg: ${msg}}
				set mkt_desc [reqGetArg queue_desc_${ev_mkt_id}]
				append errors "<br>Failed to delete: ${mkt_desc} from the settlement queue"
			} else {
				ob::log::write INFO {=> do_mkt_stl_cleanup. Ev_mkt_id: ${ev_mkt_id} successfully removed from the settlement queue.}
				db_close $res
			}
		}
	}

	inf_close_stmt $stmt

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$no_delete == 0} {
			err_bind "No markets were selected for removal from the settlement queue"
		} else {
			msg_bind "All selected markets were succesfully deleted from the settlement queue"
		}
	}

	go_unstl_ev_sel
}



#
# view the queue of markets waiting to be settled by a cron job
#
proc go_mkt_stl_cleanup_queue {} {

	global DB MKT QUEUE

	tpBindString EVENT_INFO [reqGetArg EventArgs]

	set sql {
		select
				c.name class_name,
				t.name type_name,
				e.ev_id,
				e.desc ev_name,
				e.start_time,
				g.name mkt_name,
				m.ev_mkt_id
		from
				tEvClass c,
				tEvType t,
				tEv e,
				tEvMkt m,
				tEvOcGrp g,
				tSettleMsg s
		where
				t.ev_class_id  = c.ev_class_id and
				t.ev_type_id   = e.ev_type_id and
				e.ev_id        = m.ev_id and
				m.ev_oc_grp_id = g.ev_oc_grp_id and
				m.ev_mkt_id    = s.ev_mkt_id
	}

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
			set QUEUE($r,ev_id)         [db_get_col $rs $r ev_id]
			set QUEUE($r,ev_name)       [db_get_col $rs $r ev_name]
			set QUEUE($r,ev_mkt_id)     [db_get_col $rs $r ev_mkt_id]
			set QUEUE($r,mkt_name)      [db_get_col $rs $r mkt_name]
			set QUEUE($r,event_type)    "[db_get_col $rs $r class_name]:[db_get_col $rs $r type_name]"
			set QUEUE($r,start_time)    [db_get_col $rs $r start_time]
	}

	db_close $rs
	unset rs

	tpSetVar queue_rows $nrows

	tpBindVar QueuedEvent         QUEUE   ev_name            queue_idx
	tpBindVar QueuedEvId          QUEUE   ev_id              queue_idx
	tpBindVar QueuedEvType        QUEUE   event_type         queue_idx
	tpBindVar QueuedStartTime     QUEUE   start_time         queue_idx
	tpBindVar QueuedMktName       QUEUE   mkt_name           queue_idx
	tpBindVar QueuedMktId         QUEUE   ev_mkt_id          queue_idx

	asPlayFile mkt_stl_cleanup_queue.html
}



#
# pulls out events with no bets placed against them that can be scheduled
# for automatic settlement - FOR NON-POOLS MARKETS ONLY
#
proc go_nobet_stl_cleanup {} {
	global DB MKT EVT QUEUE

	set class_id      [reqGetArg TypeId]
	set date_lo       [reqGetArg date_lo]
	set date_hi       [reqGetArg date_hi]
	set date_sel      [reqGetArg date_range]
	set ev_status     [reqGetArg EvStatus]
	set mkt_status    [reqGetArg MktStatus]
	set ev_displayed  [reqGetArg EvDisplayed]
	set mkt_displayed [reqGetArg MktDisplayed]
	set args          [reqGetArg SubmitName]
	# will determine whether the result page displays events or markets
	set result_level  [reqGetArg ResultLevel]
	# if the following is set, then only the markets for this event will be displayed
	set event_id      [reqGetArg EventId]


	if {[OT_CfgGet FUNC_BIR_SEARCH_UNSTL_EVS 0]} {
		set is_bir    [reqGetArg is_bir]
	} else {
		set is_bir "-"
	}

	set event_info "$class_id|$date_lo|$date_hi|$date_sel|$ev_status|$mkt_status|$ev_displayed|$mkt_displayed|$args|$result_level|$event_id|$is_bir|[reqGetArg auto_result]|[reqGetArg auto_display]"

	tpBindString EVENT_INFO $event_info

	if { $event_id == "" } {

		set d_lo "'0001-01-01 00:00:00'"
		set d_hi "'9999-12-31 23:59:59'"
		set where [list]

		if {[OT_CfgGet UNSET_USE_CURRENT_TIME 0]} {
			set date_time [clock format [clock seconds] -format "%H:%M:%S"]
			set d_hi "'[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]'"
		} else {
			set date_time "23:59:59"
		}

		if {$date_lo != "" || $date_hi != ""} {
			if {$date_lo != ""} {
				set d_lo "'$date_lo 00:00:00'"
			}
			if {$date_hi != ""} {
				set d_hi "'$date_hi $date_time'"
			}
		} else {
			set dt [clock format [clock seconds] -format "%Y-%m-%d"]
			foreach {y m d} [split $dt -] {
					set y [string trimleft $y 0]
					set m [string trimleft $m 0]
					set d [string trimleft $d 0]
			}

			if {[OT_CfgGet USE_SMALL_DATE_RANGE 0]} {
				set format "%Y-%m-%d %H:%M:%S"
				set short_fm "%Y-%m-%d"
				set time [clock seconds]

				if {$date_sel == "1"} {
					set d_hi "'[clock format $time -format $format]'"
					set d_lo "'[clock format [expr {$time - 3600}] -format $format]'"
				} elseif {$date_sel == "2"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "3"} {
					if {[incr d -1] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "4"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
						if {[incr d -7] <= 0} {
							if {[incr m -1] < 1} {
								set m 12
								incr y -1
							}
							set d [expr {[days_in_month $m $y]+$d}]
						}
						set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				}
			} else {
				if {$date_sel == "1"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr d -7] <= 0} {
						if {[incr m -1] < 1} {
								set m 12
								incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "2"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr d -14] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "3"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr m -1] < 1} {
							set m 12
							incr y -1
					}
					if {$d > [days_in_month $m $y]} {
							set d [days_in_month $m $y]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "4"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr m -2] < 1} {
						set m [expr 12 + $m]
						incr y -1
					}
					if {$d > [days_in_month $m $y]} {
						set d [days_in_month $m $y]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "5"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr m -5] < 1} {
						set m [expr 12 + $m]
						incr y -1
					}
					if {$d > [days_in_month $m $y]} {
						set d [days_in_month $m $y]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "6"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					incr y -1
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]

				} elseif {$date_sel == "7"} {
					set d_lo "'0001-01-01 00:00:00'"
					if {[incr d -7] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_hi [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} elseif {$date_sel == "8"} {
					set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				}
			}
		}

		# Search for events between the 2 specified dates iff present
		set where "and e.start_time between $d_lo and $d_hi"

		# Check if status of event is active/suspended
		if {$ev_status != "-"} {
			append where " and e.status='$ev_status'"
		}

		# Check if event is displayed
		if {$ev_displayed != "-"} {
			append where " and e.displayed='$ev_displayed'"
		}

		# Search at the class level or type level
		if {$class_id != 0} {

			set cs [split $class_id :]

			if {[lindex $cs 0] == "C"} {
				append where " and u.ev_class_id=[lindex $cs 1]"
			} else {
				append where " and u.ev_type_id=$class_id"
			}
		}


	} else {
		# the query is event-specific therefore we dont need to check some of the parameters
			append where " and e.ev_id=$event_id"

	}

	# Check if status of market is active/suspended
	if {$mkt_status != "-"} {
		append where " and m.status='$mkt_status'"
	}

	# Check if market is displayed
	if {$mkt_displayed != "-"} {
		append where " and m.displayed='$mkt_displayed'"
	}

	if {$is_bir != "-" && $is_bir != ""} {
		append where "and m.bet_in_run ='$is_bir'"
	}

	# pull out the class ids of pools events so they can be ignored
	# this is relevant only when the query is not event-specific
	if {$event_id == "" && [OT_CfgGet FUNC_POOLS 1]} {

		set sql {
			select
				ev_class_id
			from
				tEvClass c
			where exists
				(select
					1
				from
					ttrnimap t
				where
					t.level = 'CLASS' and
					t.id = c.ev_class_id)
			or exists
				(select 1
					from
						ttotemap m
					where
						m.level = 'CLASS' and
						m.id = c.ev_class_id
				);
		}
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		set class_list [db_get_col_list $rs -name ev_class_id]
		if {[llength $class_list] > 0 && $class_list != "" && ![op_allowed AllowAutoStlPools]} {
			append where " and c.ev_class_id not in ([join $class_list ","])"
		}
		db_close $rs
	}

	set select_stmt ""
	if {$result_level == "M"} {
		set select_stmt ",g.name mkt_name,m.displayed mkt_displayed,m.status mkt_status,o.result,o.result_conf,m.ev_mkt_id"
	}

	set order_by ""
	if {$result_level == "M"} {
		set order_by ",m.ev_mkt_id"
	}

	set sql [subst {
		select distinct
			c.name class_name,
			t.name type_name,
			e.ev_id,
			e.desc ev_name,
			e.start_time,
			e.displayed ev_displayed,
			e.status ev_status
			$select_stmt
		from
			tEvClass c,
			tEvType t,
			tEvUnStl u,
			tEv e,
			tEvMkt m,
			tEvOcGrp g,
			tEvOc o
		where
			t.ev_class_id  = c.ev_class_id and
			t.ev_type_id   = u.ev_type_id and
			u.ev_id        = e.ev_id and
			e.ev_id        = m.ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id    = o.ev_mkt_id and
			m.settled      != 'Y' and
			not exists (select 1 from tOBet, tEvOc where tOBet.ev_oc_id = tEvOc.ev_oc_id and tEvOc.ev_mkt_id = m.ev_mkt_id) and
			not exists (select 1 from tPBet, tEvOc where tPBet.ev_oc_id = tEvOc.ev_oc_id and tEvOc.ev_mkt_id = m.ev_mkt_id) and
			not exists (select 1 from tSettleMsg where m.ev_mkt_id = tSettleMsg.ev_mkt_id)
			$where
		order by
			e.start_time desc
			$order_by
	}]

	set stmt               [inf_prep_sql $DB $sql]
	set rs                 [inf_exec_stmt $stmt]
	inf_close_stmt         $stmt
	set nrows              [db_get_nrows $rs]

	if {$result_level == "M"} {

		set no_mkts            0
		set prev_mkt_id        -1

		for {set r 0} {$r < $nrows} {incr r} {
			set mkt_id [db_get_col $rs $r ev_mkt_id]

			if {$prev_mkt_id != $mkt_id} {
				set ev_id [db_get_col $rs $r ev_id]

				set MKT($no_mkts,ev_id)         $ev_id
				set MKT($no_mkts,ev_name)       [db_get_col $rs $r ev_name]
				set MKT($no_mkts,ev_mkt_id)     [db_get_col $rs $r ev_mkt_id]
				set MKT($no_mkts,event_type)    "[db_get_col $rs $r class_name]:[db_get_col $rs $r type_name]"
				set MKT($no_mkts,start_time)    [db_get_col $rs $r start_time]
				set MKT($no_mkts,ev_displayed)  [db_get_col $rs $r ev_displayed]
				set MKT($no_mkts,ev_status)     [db_get_col $rs $r ev_status]

				set MKT($no_mkts,mkt_name)      [db_get_col $rs $r mkt_name]
				set MKT($no_mkts,mkt_displayed) [db_get_col $rs $r mkt_displayed]
				set MKT($no_mkts,mkt_status)    [db_get_col $rs $r mkt_status]

				# now for the result info
				if {[db_get_col $rs $r result_conf] == "Y"} {
					set MKT($no_mkts,num_res_conf) 1
					set MKT($no_mkts,num_res_unset) 0
					set MKT($no_mkts,num_res_set_unconf) 0
				} else {
					set MKT($no_mkts,num_res_conf) 0
					if {[db_get_col $rs $r result] == "-"} {
						set MKT($no_mkts,num_res_unset) 1
						set MKT($no_mkts,num_res_set_unconf) 0
					} else {
						set MKT($no_mkts,num_res_unset) 0
						set MKT($no_mkts,num_res_set_unconf) 1
					}
				}

				set prev_mkt_id $MKT($no_mkts,ev_mkt_id)
				incr no_mkts
			} else {
					if {[db_get_col $rs $r result_conf] == "Y"} {
						incr MKT([expr {$no_mkts - 1}],num_res_conf)
					} else {
						if {[db_get_col $rs $r result] == "-"} {
							incr MKT([expr {$no_mkts - 1}],num_res_unset) 1
						} else {
							incr MKT([expr {$no_mkts - 1}],num_res_set_unconf) 1
						}
					}
			}
		}

	# set up the result strings
		for {set i 0} {$i < $no_mkts} {incr i} {
			set MKT($i,result_string) ""
			if {$MKT($i,num_res_conf) > 0} {
				set MKT($i,result_string) "$MKT($i,num_res_conf) Confirmed "
			}
			append MKT($i,result_string) "$MKT($i,num_res_set_unconf) Set $MKT($i,num_res_unset) Unset"
		}

		tpSetVar mkt_rows   $no_mkts

		tpBindVar Event         MKT   ev_name            mkt_idx
		tpBindVar EvId          MKT   ev_id              mkt_idx
		tpBindVar EvDisplayed   MKT   ev_displayed       mkt_idx
		tpBindVar EvType        MKT   event_type         mkt_idx
		tpBindVar StartTime     MKT   start_time         mkt_idx
		tpBindVar EvStatus      MKT   ev_status          mkt_idx
		tpBindVar MktName       MKT   mkt_name           mkt_idx
		tpBindVar MktDisplayed  MKT   mkt_displayed      mkt_idx
		tpBindVar MktStatus     MKT   mkt_status         mkt_idx
		tpBindVar MktType       MKT   event_type         mkt_idx
		tpBindVar MktId         MKT   ev_mkt_id          mkt_idx
		tpBindVar ResultInfo    MKT   result_string      mkt_idx

	} else {
	# result is event list
		set no_evts 0

		for {set r 0} {$r < $nrows} {incr r} {
			set ev_id [db_get_col $rs $r ev_id]

			set EVT($no_evts,ev_id)         $ev_id
			set EVT($no_evts,ev_name)       [db_get_col $rs $r ev_name]
			set EVT($no_evts,event_type)    "[db_get_col $rs $r class_name]:[db_get_col $rs $r type_name]"
			set EVT($no_evts,start_time)    [db_get_col $rs $r start_time]
			set EVT($no_evts,ev_displayed)  [db_get_col $rs $r ev_displayed]
			set EVT($no_evts,ev_status)     [db_get_col $rs $r ev_status]

			incr no_evts
		}

		tpSetVar evt_rows $no_evts

		tpBindVar Event         EVT   ev_name            evt_idx
		tpBindVar EvId          EVT   ev_id              evt_idx
		tpBindVar EvDisplayed   EVT   ev_displayed       evt_idx
		tpBindVar EvType        EVT   event_type         evt_idx
		tpBindVar StartTime     EVT   start_time         evt_idx
		tpBindVar EvStatus      EVT   ev_status          evt_idx

		# bind the query details to link to the markets page
		set var_string "&MktStatus=$mkt_status&MktDisplayed=$mkt_displayed&SubmitName=$args&is_bir=[reqGetArg is_bir]&auto_result=[reqGetArg auto_result]&auto_display=[reqGetArg auto_display]&ResultLevel=M"
		tpBindString varString $var_string

	}

	db_close $rs
	unset rs


	if {![op_allowed AllowVoidAutoStl]} {
		tpBindString AutoResult  "V"
	} else {
		tpBindString AutoResult  [reqGetArg auto_result]
	}

	if {![op_allowed AllowAutoUndisplay]} {
		tpBindString AutoDisplay ""
	} else {
		tpBindString AutoDisplay [reqGetArg auto_display]
	}

	if {$result_level == "E"} {
		asPlayFile -nocache evt_stl_cleanup_list.html
	} else {
		asPlayFile -nocache mkt_stl_cleanup_list.html
	}
	catch {unset MKT}
	catch {unset EVT}
}



#
# go back to the unsettled event list selection
#
proc go_back_unstl_ev_list {} {

	set event_args         [reqGetArg EventArgs]
	set rs                 [split $event_args |]
	reqSetArg TypeId       [lindex $rs 0]
	reqSetArg date_lo      [lindex $rs 1]
	reqSetArg date_hi      [lindex $rs 2]
	reqSetArg date_range   [lindex $rs 3]
	reqSetArg EvStatus     [lindex $rs 4]
	reqSetArg MktStatus    [lindex $rs 5]
	reqSetArg EvDisplayed  [lindex $rs 6]
	reqSetArg MktDisplayed [lindex $rs 7]
	reqSetArg SubmitName   [lindex $rs 8]
	reqSetArg ResultLevel  [lindex $rs 9]
	reqSetArg EventId      [lindex $rs 10]
	reqSetArg is_bir       [lindex $rs 11]
	reqSetArg auto_result  [lindex $rs 12]
	reqSetArg auto_display [lindex $rs 13]

	go_nobet_stl_cleanup
}



#
# search for unused coupons (without valid markets) to cleanup
#
proc go_coupon_cleanup_list args {

	global DB COUPON

	set category  [reqGetArg coup_cleanup_cat]
	set class     [reqGetArg coup_cleanup_class]
	set date_sel  [reqGetArg coup_cleanup_date_range]
	set date_lo   [reqGetArg coup_cleanup_date_lo]
	set date_hi   [reqGetArg coup_cleanup_date_hi]
	set displayed [reqGetArg coup_cleanup_displayed]
	set args      [reqGetArg SubmitName]

	set coupon_info "$category|$class|$date_sel|$date_lo|$date_hi|$displayed|$args"

	tpBindString COUPON_INFO $coupon_info

	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"
	set where [list]

	# the date should never be in the future
	set date_time [clock format [clock seconds] -format "%H:%M:%S"]
	set d_hi "'[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi $date_time'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]
		foreach {y m d} [split $dt -] {
				set y [string trimleft $y 0]
				set m [string trimleft $m 0]
				set d [string trimleft $d 0]
		}

		if {[OT_CfgGet USE_SMALL_DATE_RANGE 0]} {
			set format "%Y-%m-%d %H:%M:%S"
			set short_fm "%Y-%m-%d"
			set time [clock seconds]

			if {$date_sel == "1"} {
				set d_hi "'[clock format $time -format $format]'"
				set d_lo "'[clock format [expr {$time - 3600}] -format $format]'"
			} elseif {$date_sel == "2"} {
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "3"} {
				if {[incr d -1] <= 0} {
					if {[incr m -1] < 1} {
						set m 12
						incr y -1
					}
					set d [expr {[days_in_month $m $y]+$d}]
				}
				set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "4"} {
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr d -7] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
		} else {
			if {$date_sel == "1"} {
				# Today
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
			if {$date_sel == "2"} {
				# 1 week
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				if {[incr d -7] <= 0} {
					if {[incr m -1] < 1} {
							set m 12
							incr y -1
					}
					set d [expr {[days_in_month $m $y]+$d}]
				}
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "3"} {
				# 3 months
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				if {[incr m -3] < 1} {
						set m 12
						incr y -1
				}
				if {$d > [days_in_month $m $y]} {
						set d [days_in_month $m $y]
				}
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "4"} {
				# 1 year
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				incr y -1
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "5"} {
				# older than a year
				set d_lo "'0001-01-01 00:00:00'"
				incr y -1
				set d_hi [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
		}
	}

	# Search for coupons created between the 2 specified dates
	set where "and cp.cr_date between $d_lo and $d_hi"

	# Check if coupon is displayed
	if {$displayed != "-"} {
		append where " and cp.displayed='$displayed'"
	}

	# Search for a specific category
	if {$category != "" && $category != 0} {
		append where " and cp.category='$category'"
	}

	# Search for a specific class
	if {$class != "" && $class != 0} {
		append where " and cp.ev_class_id=$class"
	}


	set sql [subst {
		select
			cp.coupon_id,
			cp.desc,
			cp.displayed,
			cp.cr_date,
			cp.disporder,
			cp.ev_class_id,
			cp.category,
			cp.sort,
			(select count(*) from tBetBlockBuster where tBetBlockBuster.bb_coupon_id = cp.coupon_id) as has_bbbet
		from
			tCoupon cp
		where
			not exists (
				select
					1
				from
					tCouponMkt cpm,
					tEvMkt     m
				where
					cp.coupon_id  = cpm.coupon_id and
					cpm.ev_mkt_id = m.ev_mkt_id   and
					m.settled     = 'N'
			)
			$where
		order by cp.cr_date
	}]


	set stmt  [inf_prep_sql $DB $sql]

	set rs    [inf_exec_stmt $stmt]

	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]
	set num_coups 0

	for {set r 0} {$r < $nrows} {incr r} {

		set COUPON($num_coups,coup_id)   [db_get_col $rs $r coupon_id]
		set COUPON($num_coups,desc)      [db_get_col $rs $r desc]
		set COUPON($num_coups,displayed) [db_get_col $rs $r displayed]
		set COUPON($num_coups,cr_date)   [db_get_col $rs $r cr_date]
		set COUPON($num_coups,class_id)  [db_get_col $rs $r ev_class_id]
		set COUPON($num_coups,category)  [db_get_col $rs $r category]

		set is_bb 0
		if {[db_get_col $rs $r sort] == "BB"} {set is_bb 1}
		set COUPON($num_coups,is_bb)     $is_bb
		set COUPON($num_coups,has_bbbet) [db_get_col $rs $r has_bbbet]

		incr num_coups
	}

	db_close $rs
	unset rs

	tpSetVar coup_rows $num_coups

	tpBindVar CoupId     COUPON   coup_id    coup_idx
	tpBindVar Desc       COUPON   desc       coup_idx
	tpBindVar Displayed  COUPON   displayed  coup_idx
	tpBindVar CrDate     COUPON   cr_date    coup_idx
	tpBindVar CoupClass  COUPON   class_id   coup_idx
	tpBindVar CoupCat    COUPON   category   coup_idx
	tpBindVar IsBB       COUPON   is_bb      coup_idx
	tpBindVar HasBBBet   COUPON   has_bbbet  coup_idx

	asPlayFile -nocache coupon_cleanup_list.html

}



#
# Undisplay or delete selected coupons
#
proc do_coupon_cleanup args {

	global DB USERNAME

	ob::log::write INFO {=> do_coupon_cleanup}

	set num_coups     [reqGetArg NumCoups]

	set sql {
		update
			tcoupon
		set
			displayed = "N"
		where
			displayed = "Y"
			and coupon_id = ?
	}
	set stmt1 [inf_prep_sql $DB $sql]

	set sql {
		execute procedure pDelCoupon(
			p_adminuser = ?,
			p_coupon_id = ?
		)
	}
	set stmt2 [inf_prep_sql $DB $sql]

	set sql {
		delete from
			tBlockBuster
		where
			coupon_id = ?
	}
	set stmt3 [inf_prep_sql $DB $sql]

	set errors ""
	set num_changes 0
	set delete_for_real 0

	for {set i 0} {$i < $num_coups} {incr i} {
		set coupId [reqGetArg coup_id_${i}]
		if {[reqGetArg act_${i}] == "U"} {
			# undisplay
			incr num_changes
			if {[catch {set res  [inf_exec_stmt $stmt1 $coupId]} msg]} {
				ob::log::write ERROR {Failed to undisplay coup id: ${coupId}. Msg: $msg}
				set coup_desc [reqGetArg coup_desc_${i}]
				append errors "<br>Failed to undisplay: ${coup_desc}"
			} else {
				ob::log::write INFO {=> do_coupon_cleanup. Coupon id: ${coupId} successfully undisplayed.}
				db_close $res
			}
		} elseif {[reqGetArg act_${i}] == "D"} {
			#delete
			inf_begin_tran $DB
			set is_error 0
			incr num_changes
			set has_bbbet [reqGetArg has_bbbet_${i}]
			if {$has_bbbet != "" && $has_bbbet > 0} {
				ob::log::write ERROR {A Blockbuster coupon ${coupId} with bets cannot be deleted.}
				append errors "<br>A Blockbuster coupon with bets cannot be deleted: ${coup_desc}"
				set is_error 1
			} else {
				set is_bb [reqGetArg is_bb_${i}]
				if {$is_bb != "" && $is_bb > 0} {
					# delete empty blockbuster before we can delete the coupon
					if { [catch {set res  [inf_exec_stmt $stmt3 $coupId]} msg]} {
						ob::log::write ERROR {Failed to delete empty blockbuster, coup id: ${coupId}. Msg: $msg}
						set is_error 1
					} else {
						ob::log::write INFO {=> do_coupon_cleanup. Blockbuster coupon id: ${coupId} successfully deleted.}
						db_close $res
					}
				}

				if {$is_error == 0} {
					if { [catch {set res  [inf_exec_stmt $stmt2 $USERNAME $coupId]} msg]} {
						ob::log::write ERROR {Failed to delete coup id: ${coupId}. Msg: $msg}
						set coup_desc [reqGetArg coup_desc_${i}]
						append errors "<br>Failed to delete: ${coup_desc}. The coupon might still be in use."
						set is_error 1
					} else {
						db_close $res
						ob::log::write INFO {=> do_coupon_cleanup. Coupon id: ${coupId} successfully deleted.}
						inf_commit_tran $DB
					}
				}
			}
			if {$is_error == 1} {
				inf_rollback_tran $DB
			}
		}
	}

	catch {inf_close_stmt $stmt1}
	catch {inf_close_stmt $stmt2}

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$num_changes == 0} {
			err_bind "No coupons were undisplayed or deleted."
		} else {
			msg_bind "All selected coupons were succesfully undisplayed/deleted."
		}
	}

	go_back_coupon_cleanup_list

}



#
# go back to the coupon list
#
proc go_back_coupon_cleanup_list {} {

	set coupon_args                   [reqGetArg CoupArgs]
	set rs                            [split $coupon_args |]
	reqSetArg coup_cleanup_cat        [lindex $rs 0]
	reqSetArg coup_cleanup_class      [lindex $rs 1]
	reqSetArg coup_cleanup_date_range [lindex $rs 2]
	reqSetArg coup_cleanup_date_lo    [lindex $rs 3]
	reqSetArg coup_cleanup_date_hi    [lindex $rs 4]
	reqSetArg coup_cleanup_displayed  [lindex $rs 5]
	reqSetArg SubmitName              [lindex $rs 6]

	go_coupon_cleanup_list
}



#
# search for events without markets or with markets without selections
#
proc go_empty_ev_cleanup_list args {

	global DB EEVENT

	set class_id      [reqGetArg TypeId]
	set date_lo       [reqGetArg empty_ev_date_lo]
	set date_hi       [reqGetArg empty_ev_date_hi]
	set date_sel      [reqGetArg empty_ev_date_range]
	set ev_status     [reqGetArg empty_ev_status]
	set ev_displayed  [reqGetArg empty_ev_displayed]
	set result_type   [reqGetArg empty_ev_result]
	set args          [reqGetArg SubmitName]

	set event_info "$class_id|$date_lo|$date_hi|$date_sel|$ev_status|$ev_displayed|$result_type|$args"

	tpBindString EEVENT_INFO $event_info

	set where [list]

	set date_time [clock format [clock seconds] -format "%H:%M:%S"]
	# set d_hi "'[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]'"
	set d_lo "'0001-01-01 00:00:00'"
	set d_hi "'9999-12-31 23:59:59'"

	if {$date_lo != "" || $date_hi != ""} {
		if {$date_lo != ""} {
			set d_lo "'$date_lo 00:00:00'"
		}
		if {$date_hi != ""} {
			set d_hi "'$date_hi $date_time'"
		}
	} else {
		set dt [clock format [clock seconds] -format "%Y-%m-%d"]
		foreach {y m d} [split $dt -] {
				set y [string trimleft $y 0]
				set m [string trimleft $m 0]
				set d [string trimleft $d 0]
		}

		if {[OT_CfgGet USE_SMALL_DATE_RANGE 0]} {
			set format "%Y-%m-%d %H:%M:%S"
			set short_fm "%Y-%m-%d"
			set time [clock seconds]

			if {$date_sel == "1"} {
				set d_hi "'[clock format $time -format $format]'"
				set d_lo "'[clock format [expr {$time - 3600}] -format $format]'"
			} elseif {$date_sel == "2"} {
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "3"} {
				if {[incr d -1] <= 0} {
					if {[incr m -1] < 1} {
						set m 12
						incr y -1
					}
					set d [expr {[days_in_month $m $y]+$d}]
				}
				set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "4"} {
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
					if {[incr d -7] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
		} else {
			if {$date_sel == "1"} {
				# Today
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
			if {$date_sel == "2"} {
				# 1 week
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				if {[incr d -7] <= 0} {
					if {[incr m -1] < 1} {
							set m 12
							incr y -1
					}
					set d [expr {[days_in_month $m $y]+$d}]
				}
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "3"} {
				# 3 months
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				if {[incr m -3] < 1} {
						set m 12
						incr y -1
				}
				if {$d > [days_in_month $m $y]} {
						set d [days_in_month $m $y]
				}
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "4"} {
				# 1 year
				set d_hi [format "'%s-%02d-%02d $date_time'" $y $m $d]
				incr y -1
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "5"} {
				# older than a year
				set d_lo "'0001-01-01 00:00:00'"
				incr y -1
				set d_hi [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			} elseif {$date_sel == "6"} {
				# 1 month in the future
				set d_lo [format "'%s-%02d-%02d $date_time'" $y $m $d]
				if {[incr m 1] > 12} {
						set m 1
						incr y 1
				}
				if {$d > [days_in_month $m $y]} {
						set d [days_in_month $m $y]
				}
				set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			} elseif {$date_sel == "7"} {
				# 1 year in the future
				set d_lo [format "'%s-%02d-%02d $date_time'" $y $m $d]
				incr y 1
				if {$d > [days_in_month $m $y]} {
					set d [days_in_month $m $y]
				}
				set d_hi [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
			} elseif {$date_sel == "8"} {
				# 1 year in the future
				set d_hi "'9999-12-31 23:59:59'"
				incr y 1
				if {$d > [days_in_month $m $y]} {
					set d [days_in_month $m $y]
				}
				set d_lo [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
			}
		}
	}

	# Search for events between the 2 specified dates iff present
	set where "and e.start_time between $d_lo and $d_hi"

	# Check if status of event is active/suspended
	if {$ev_status != "-" && $ev_status != ""} {
		append where " and e.status='$ev_status'"
	}

	# Check if event is displayed
	if {$ev_displayed != "-"} {
		append where " and e.displayed='$ev_displayed'"
	}


	# Search at the class level or type level
	if {$class_id != 0} {

		set cs [split $class_id :]

		if {[lindex $cs 0] == "C"} {
			append where " and u.ev_class_id=[lindex $cs 1]"
		} else {
			append where " and u.ev_type_id=$class_id"
		}
	}

	# pull out the class ids of pools events so they can be ignored
	if {[OT_CfgGet FUNC_POOLS 1]} {

		set sql {
			select
				ev_class_id
			from
				tEvClass c
			where exists
				(select
					1
				from
					ttrnimap t
				where
					t.level = 'CLASS' and
					t.id = c.ev_class_id)
			or exists
				(select 1
					from
						ttotemap m
					where
						m.level = 'CLASS' and
						m.id = c.ev_class_id
				);
		}
		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		set class_list [db_get_col_list $rs -name ev_class_id]
		if {[llength $class_list] > 0 && $class_list != "" && ![op_allowed AllowAutoStlPools]} {
			append where " and c.ev_class_id not in ([join $class_list ","])"
		}
		db_close $rs
	}

	# if result = market:
	#  - get market group name
	#  - don't pick settled markets
	#  - pick only markets without selections
	#  - don't pick scorecast markets
	# if result = event:
	#  - outer-join markets on the events
	#  - pick only events that have only markets with no selections or no markets at all
	#  - don't pick events that have scorecast markets
	if {$result_type == "M"} {
		# for markets
		set select "g.name mkt_name,"
		set from " tEvMkt m, tEvOcGrp g"
		append where " and m.ev_oc_grp_id = g.ev_oc_grp_id and m.settled != 'Y' and \
			not exists (select 1 from tEvOc where m.ev_mkt_id = tEvOc.ev_mkt_id) and \
			m.sort != 'SC'"

		if {[OT_CfgGet HIDE_NEW_EEVS_FOR_HRS 0] > 0} {
			append where "and m.cr_date < CURRENT - [OT_CfgGet HIDE_NEW_EEVS_FOR_HRS 0] units hour"
		}

	} else {
		# for events
		set select ""
		set from " outer tEvMkt m"
		append where " and \
			not exists (select 1 from tEvMkt mm, tEvOc where e.ev_id = mm.ev_id and mm.ev_mkt_id = tEvOc.ev_mkt_id) \
			and not exists (select 1 from tEvMkt mmm where e.ev_id = mmm.ev_id and mmm.sort = 'SC')"

		if {[OT_CfgGet HIDE_NEW_EEVS_FOR_HRS 0] > 0} {
			append where "and e.cr_date < CURRENT - [OT_CfgGet HIDE_NEW_EEVS_FOR_HRS 0] units hour"
		}

	}

	# A query to get all the unsettled events that dont have at least one market selection
	# or markets without selections
	set sql [subst {
		select
			c.name class_name,
			t.name type_name,
			e.ev_id,
			e.desc ev_name,
			e.start_time,
			e.cr_date,
			e.displayed ev_displayed,
			e.status ev_status,
			m.ev_mkt_id,
			$select
			m.displayed mkt_displayed
		from
			tEvClass c,
			tEvType t,
			tEvUnStl u,
			tEv e,
			$from
		where
			t.ev_class_id  = c.ev_class_id         and
			t.ev_type_id   = u.ev_type_id          and
			u.ev_id        = e.ev_id               and
			e.ev_id = m.ev_id
			$where
		order by
			e.start_time, e.ev_id, m.ev_mkt_id
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set rs    [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set num_evs 0
	set current_event -1

	for {set r 0} {$r < $nrows} {incr r} {
		set event_id [db_get_col $rs $r ev_id]
		set ev_mkt_id [db_get_col $rs $r ev_mkt_id]
		if {$current_event != $event_id} {

			set EEVENT($num_evs,event_type) "[db_get_col $rs $r class_name]:[db_get_col $rs $r type_name]"
			set EEVENT($num_evs,ev_id)      [db_get_col $rs $r ev_id]
			set EEVENT($num_evs,desc)       [db_get_col $rs $r ev_name]
			set EEVENT($num_evs,start_time) [db_get_col $rs $r start_time]
			set EEVENT($num_evs,cr_date)    [db_get_col $rs $r cr_date]
			set EEVENT($num_evs,displayed)  [db_get_col $rs $r ev_displayed]
			set EEVENT($num_evs,status)     [db_get_col $rs $r ev_status]
			set EEVENT($num_evs,markets)    [list]

			incr num_evs
			set current_event $event_id
		}

		if {$ev_mkt_id != ""} {
			lappend EEVENT([expr ($num_evs - 1)],markets) $ev_mkt_id
			if {$result_type == "M"} {
				set EEVENT($ev_mkt_id,mkt_name) [db_get_col $rs $r mkt_name]
				set EEVENT($ev_mkt_id,mkt_disp) [db_get_col $rs $r mkt_displayed]
			}
		}
	}

	db_close $rs
	unset rs

	tpSetVar ee_rows $num_evs

	tpBindVar EvId       EEVENT   ev_id      ee_idx
	tpBindVar Desc       EEVENT   desc       ee_idx
	tpBindVar Displayed  EEVENT   displayed  ee_idx
	tpBindVar Status     EEVENT   status     ee_idx
	tpBindVar CrDate     EEVENT   cr_date    ee_idx
	tpBindVar StartTime  EEVENT   start_time ee_idx
	tpBindVar EventType  EEVENT   event_type ee_idx
	tpBindVar Markets    EEVENT   markets    ee_idx



	if {$result_type == "M"} {
		tpBindVar MktName    EEVENT   mkt_name   mkt_idx
		tpBindVar MktDisp    EEVENT   mkt_disp   mkt_idx

		# Check whether deletion is allowed
		if {[ob_control::get allow_dd_deletion] == "Y"} {
			tpSetVar AllowDDDeletion 1
		} else {
			tpSetVar AllowDDDeletion 0
		}

		asPlayFile empty_market_cleanup_list.html
	} else {
		asPlayFile empty_event_cleanup_list.html
	}

}



#
# Settle selected events
#
proc do_empty_ev_cleanup args {

	global DB USERNAME

	ob::log::write INFO {=> do_empty_ev_cleanup}

	set num_eevs [reqGetArg NumEEvs]

	set sql {
		execute procedure pSettleMktNoBet (
			p_admin_user = ?,
			p_ev_mkt_id = ?
		)
	}
	set stmt1 [inf_prep_sql $DB $sql]

	set sql {
		execute procedure pSetSettled(
			p_adminuser = ?,
			p_obj_type = ?,
			p_obj_id = ?
		)
	}
	set stmt2 [inf_prep_sql $DB $sql]

	set errors ""
	set num_changes 0

	for {set i 0} {$i < $num_eevs} {incr i} {
		set event_id [reqGetArg ee_ev_id_${i}]
		if {[reqGetArg ee_stl_${event_id}] == "Y"} {
			set markets [reqGetArg ee_markets_${event_id}]
			set e_desc [reqGetArg ee_ev_desc_${event_id}]
			# settle
			incr num_changes
			if {$markets != "" && [llength $markets] > 0} {
				set is_error 0
				# settle each market - last market will trigger event settling
				foreach market $markets {
					if {$is_error == 0} {
						if { [catch {set res [inf_exec_stmt $stmt1 $USERNAME $market]} msg]} {
							set is_error 1
							ob::log::write ERROR {Failed to settle event ${event_id} with market: ${market}. Msg: $msg}
							append errors "<br>Failed to settle markets for: ${e_desc}"
						} else {
							ob::log::write INFO {=> do_empty_ev_cleanup. Market: ${market} successfully settled.}
						}
						catch {db_close $res}
					}
				}
			} else {
				# settle the event
				if {[catch { set res [inf_exec_stmt $stmt2 $USERNAME "E" $event_id]} msg]} {
					ob::log::write ERROR {Failed to settle ev id: ${event_id}. Msg: $msg}
					append errors "<br>Failed to settle: ${e_desc}"
				} else {
					ob::log::write INFO {=> do_empty_ev_cleanup. Event id: ${event_id} successfully settled.}
				}
				catch {db_close $res}
			}
		}
	}

	catch {inf_close_stmt $stmt1}
	catch {inf_close_stmt $stmt2}

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$num_changes == 0} {
			err_bind "No events were settled."
		} else {
			msg_bind "All selected events were succesfully settled."
		}
	}
	go_back_empty_ev_cleanup
}



#
# Settle or delete selected markets
#
proc do_empty_mkt_cleanup args {

	global DB USERNAME
	ob::log::write INFO {=> do_empty_mkt_cleanup}
	set num_eevs     [reqGetArg NumEEvs]

	set sql {
		execute procedure pSettleMktNoBet (
			p_admin_user = ?,
			p_ev_mkt_id = ?
		)
	}
	set stmt1 [inf_prep_sql $DB $sql]

	set sql {
		execute procedure pDelEvMkt(
			p_adminuser = ?,
			p_ev_mkt_id = ?
		)
	}
	set stmt2 [inf_prep_sql $DB $sql]

	set errors ""
	set num_changes 0

	for {set i 0} {$i < $num_eevs} {incr i} {
		set event_id [reqGetArg ee_ev_id_${i}]
		set markets  [reqGetArg ee_markets_${event_id}]

		# settle each market
		foreach market $markets {
			if {[reqGetArg act_${market}] == "S"} {
				incr num_changes
				if { [catch {set res  [inf_exec_stmt $stmt1 $USERNAME $market]} msg]} {
					ob::log::write ERROR {Failed to settle a market, market id: ${market}. Msg: $msg}
					set market_desc [reqGetArg ee_mkt_desc_${i}]
					append errors "<br>Failed to settle: ${market_desc}."
				} else {
					ob::log::write INFO {=> do_empty_mkt_cleanup. Market: ${market} successfully settled.}
					db_close $res
				}
			} elseif {[reqGetArg act_${market}] == "D"} {
				incr num_changes
				if { [catch {set res  [inf_exec_stmt $stmt2 $USERNAME $market]} msg]} {
					ob::log::write ERROR {Failed to delete a market, market id: ${market}. Msg: $msg}
					set market_desc [reqGetArg ee_mkt_desc_${i}]
					append errors "<br>Failed to delete: ${market_desc}."
				} else {
					ob::log::write INFO {=> do_empty_mkt_cleanup. Market: ${market} successfully deleted.}
					db_close $res
				}
			}
		}
	}

	if {$errors != ""} {
		err_bind $errors
	} else {
		if {$num_changes == 0} {
			err_bind "No markets were settled/deleted."
		} else {
			msg_bind "All selected markets were succesfully settled/deleted."
		}
	}
	go_back_empty_ev_cleanup
}



#
# go back to the empty event/market list
#
proc go_back_empty_ev_cleanup {} {

	set empty_event_args          [reqGetArg EEventArgs]
	set rs                        [split $empty_event_args |]
	reqSetArg TypeId              [lindex $rs 0]
	reqSetArg empty_ev_date_lo    [lindex $rs 1]
	reqSetArg empty_ev_date_hi    [lindex $rs 2]
	reqSetArg empty_ev_date_range [lindex $rs 3]
	reqSetArg empty_ev_status     [lindex $rs 4]
	reqSetArg empty_ev_displayed  [lindex $rs 5]
	reqSetArg empty_ev_result     [lindex $rs 6]
	reqSetArg SubmitName          [lindex $rs 7]

	go_empty_ev_cleanup_list
}



}
