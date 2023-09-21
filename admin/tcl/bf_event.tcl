# ==============================================================
# $Id: bf_event.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_EV {

#
# ----------------------------------------------------------------------------
# proc to bind the mapping of openbet event to a betfair event
# ----------------------------------------------------------------------------
#
proc bind_mapped_bf_event {type_id ev_id} {
	
	global DB BF_MTCH BF_T CLAS TYP EV
	
	
	set sql [subst {
		select
			m.bf_map_id,
			i.bf_ev_items_id,
			i.bf_desc,
			i.bf_id
		from
			tEv      e,
			outer (tBFMap m,
			outer tBFEvItems i)
		where
			e.ev_id = $ev_id  and
			e.ev_id = m.ob_id and
			m.ob_type = 'EV' and
			m.bf_ev_items_id = i.bf_ev_items_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	
	tpBindString EvBFId           [db_get_col $res 0 bf_id]
	tpBindString EvBFMapId        [db_get_col $res 0 bf_map_id]  
	tpBindString EvBFEvItemsId    [db_get_col $res 0 bf_ev_items_id]
	tpSetVar BFMtchDesc           [db_get_col $res 0 bf_desc]
	
}

#
# Proc for binding all the BF events 
# under the specified BF event type
proc bind_all_bf_events {{ev_id ""} {class_id ""} {c_sort ""} {type_id ""}} {
	global DB BFEVS
	
	if {$ev_id != "" && $class_id != ""} {
		set stmt ""
		set res ""
		if {$c_sort == "HR" || $c_sort == "GR"} {
			
			if {$c_sort == "HR"} { 
				set racing_desc [OT_CfgGet BF_HORSE_RACING_TYPE "Horse Racing"]
			} else { 
				set racing_desc [OT_CfgGet BF_GREYHOUND_RACING_TYPE "Greyhound Racing"]
			}  
			
			set sql {
				select
					bf_type_id
				from
					tBFEventType
				where
					bf_ev_items_id in (
						select 
							bf_ev_items_id 
						from 
							tBFEvItems 
						where 
							bf_desc=? 
						and bf_type='ET'
					)
			}
			set stmt [inf_prep_sql $DB $sql]
		
			set res [inf_exec_stmt $stmt $racing_desc]
		} else {
			set sql {
			select
				bf_type_id
			from
				tBFEventType
			where
				bf_ev_items_id in (
						select 
							bf_ev_items_id 
						from 
							tBFMap 
						where 
								ob_id = ?
						and 	ob_type = 'EC'
						)
			}
			set stmt [inf_prep_sql $DB $sql]
		
			set res [inf_exec_stmt $stmt $class_id]
		}
		set nrows  [db_get_nrows $res]
		
		set bf_type_ids ""

		if {$nrows > 0} {
			set bf_type_ids	[db_get_col $res 0 bf_type_id]
		} else { 
		
			set match_class [ADMIN::BETFAIR_TYPE::bf_class_match ID $class_id]
			
			if {!$match_class} { 				
				set bf_type_ids [get_bf_type_id_from_ob_id TYPE $type_id] 
			} 
		}
	
		inf_close_stmt $stmt
		db_close $res
		
		# Fetch the already mapped event
		set sql {
			select
				bf_ev_items_id
			from
				tBFMap
			where
				ob_id = ?
				and ob_type = 'EV'
		}
	
		set stmt [inf_prep_sql $DB $sql]
	
		set res [inf_exec_stmt $stmt $ev_id]
	
		set nrows  [db_get_nrows $res]
		
		set Old_ev_id ""
		
		if {$nrows > 0} {
			set Old_ev_id 		[db_get_col $res 0 bf_ev_items_id]
			tpBindString Old_ev_id	$Old_ev_id
		}
	
		inf_close_stmt $stmt
		db_close $res
			
		if {$bf_type_ids != ""} {
            			
			if {[OT_CfgGet BF_MANUAL_MATCH 0]} {
			
				set sql [get_event_list_sql 0 $bf_type_ids] 
			
				set stmt [inf_prep_sql $DB $sql]
		
				set res [inf_exec_stmt $stmt $bf_type_ids]
			
				set nrows  [db_get_nrows $res]
				
				set bf_ev_list [list]
				set bf_ev_id_list [list]
				
				if {$nrows > 0} {
					for {set i 0} {$i < $nrows } {incr i} {
						set BFEVS($i,id) [db_get_col $res $i bf_ev_items_id0]
						set desc ""
						for {set k 6} {$k >= 0} {incr k -1} {
							if {[db_get_col $res $i name$k] != ""} {
								if {$desc == ""} {
									set desc [db_get_col $res $i name$k]
								} else {
									append desc " -> [db_get_col $res $i name$k]"
								}
							}
						}
						
						lappend bf_ev_list	[list $desc $BFEVS($i,id)]
						
						# store all the bf_ev_items_id in a list
						lappend bf_ev_id_list	$BFEVS($i,id)
					}
	
					# sort the list
					set bf_ev_list	[lsort $bf_ev_list]
					
					set i 0
					foreach bf_ev $bf_ev_list {
						set BFEVS($i,name) 	[lindex $bf_ev 0]
						set BFEVS($i,id) 	[lindex $bf_ev 1]
						incr i
					}
					
					tpBindVar BF_Ev_Name	BFEVS	name	bf_ev_idx
					tpBindVar BF_Ev_Id	BFEVS	id	bf_ev_idx
				}

				tpSetVar BFEvRows $nrows
				
				inf_close_stmt $stmt
				db_close $res
			
				if {[OT_CfgGet BF_USE_ACTIVE_EV 0]} {
					
					set is_mapped_event_in_list ""
					
					# If the openbet event is mapped to a betfair event
					# then check if that betfair event is present in the list of active events
					if {$Old_ev_id != "" } {
						set is_mapped_event_in_list 		[lsearch $bf_ev_id_list $Old_ev_id]
						tpBindString is_mapped_event_in_list	$is_mapped_event_in_list
					}
					
					# If BF_USE_ACTIVE_EV is set to 1 then only active events show in event match dropdown
					# In case the openbet event is mapped to a betfair event which is not active then
					# that betfair event should be visible in the event match dropdown
					if {$is_mapped_event_in_list == -1} {
						get_mapped_bf_ev_hierarchy $Old_ev_id
					}
				}
			} else {
				get_mapped_bf_ev_hierarchy $Old_ev_id
			}
		}
	}
}

proc do_bf_ev_match {ev_type_id ob_ev_id bf_ev_items_id class_sort ev_start_time {bf_ev_items_id_old ""}} {
	
	global DB USERNAME
	
	set bad 0

	if {$ob_ev_id != ""} {
		
		if { $bf_ev_items_id_old != $bf_ev_items_id } {
			
			if { $bf_ev_items_id != "" } {
				#
				# Now map the OpenBet to Betfair id
				#
				BETFAIR::UTILS::_set_map "EV" $ob_ev_id $bf_ev_items_id "M"
				
				# Fetch the bf_ev_id for this particular bf_ev_items_id
				set sql {
					select
						bf_ev_id
					from
						tBFEvent
					where
						bf_ev_items_id = ?
				}
				
				set stmt [inf_prep_sql $DB $sql]
				set res [inf_exec_stmt $stmt $bf_ev_items_id]
				
				set bf_ev_id [db_get_col $res 0 bf_ev_id]
				
				inf_close_stmt $stmt
				db_close $res

				if { $bf_ev_items_id_old != "" } {
					#Delete mkts and selection mappings under this event
					incr bad [do_bf_del_mkt_sel $ob_ev_id]
				}
				
				# Fetch the auto_match_mode for this particular event type
				set sql {
					select
						auto_match_mode,
						map_type
					from
						tBFMap
					where
						ob_type = ?
					and
						ob_id = ?
				}
			
				set stmt [inf_prep_sql $DB $sql]
		
				set res [inf_exec_stmt $stmt "ET" $ev_type_id]

				set nrows  [db_get_nrows $res]

				# set default auto_match_mode to "MATCH"
				if {$nrows > 0 } {
					set auto_match_mode [db_get_col $res 0 auto_match_mode]
					set map_type 	    [db_get_col $res 0 map_type]
				} else {
					set auto_match_mode "MATCH"					
					if {$class_sort == "HR" || $class_sort == "GR"} { 
						set map_type $class_sort
					} else { 
						set map_type ""
					} 
				}

				inf_close_stmt $stmt
				db_close $res
				
				# Fetch the bf_ev_id for this particular bf_ev_items_id
				set sql {
					select
						bf_ev_id
					from
						tBFEvent
					where
						bf_ev_items_id = ?
				}
			
				set stmt [inf_prep_sql $DB $sql]
		
				set res [inf_exec_stmt $stmt $bf_ev_items_id]

				set nrows  [db_get_nrows $res]
				
				if {$nrows > 0} {
					set bf_ev_id [db_get_col $res 0 bf_ev_id]
				} else {
					inf_close_stmt $stmt
					db_close $res
					return 1
				}

				inf_close_stmt $stmt
				db_close $res				
				
				# Insert the corresponding markets and selections in the openbet hierarchy
				if {$class_sort!="HR" && $class_sort != "GR" } {
					BETFAIR::UTILS::ins_match_mkts $ev_type_id $ob_ev_id $bf_ev_id "M" "" $auto_match_mode $map_type
				} else {
					# Pass start time of the event for Racing events
					BETFAIR::UTILS::ins_match_mkts $ev_type_id $ob_ev_id $bf_ev_id "M" $ev_start_time $auto_match_mode $map_type
				}
				
			} else {
				# Delete the EV mapping
				set sql [subst {
					delete from
						tBFMap
					where
						ob_id = ?
						and ob_type = ?
				}]
				
				set stmt [inf_prep_sql $DB $sql]
				if {[catch {set rs [inf_exec_stmt $stmt $ob_ev_id "EV"]} msg]} {
								ob::log::write ERROR {do_bf_ev_match - $msg}
								err_bind "$msg"
								return 1
				}
				
				inf_close_stmt $stmt
				db_close $rs
				
				#Delete mkts and selection mappings under this event
				incr bad [do_bf_del_mkt_sel $ob_ev_id]
			}
		}
	}
	
	if {$bad} {
		return 1
	}
	return 0
}


# Deleting the markets and selections under the BF event
# while an event match is manually modified
#
proc do_bf_del_mkt_sel {{ob_ev_id ""}} {
	global DB USERNAME

	set sql [subst {
		select
			em.ev_mkt_id
		from
			tEvMkt em,
			tBFMonitor m
		where
			em.ev_id = ?
		and
			em.ev_mkt_id= m.ob_id
		and
			m.type= 'EM'
	}]
	
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $ob_ev_id]} msg]} {
					ob::log::write ERROR {do_bf_del_mkt_sel - $msg}
					err_bind "$msg"
					return 1
	}
	
	set nrows  [db_get_nrows $rs]
	inf_close_stmt $stmt
	
	for {set i 0} {$i < $nrows} {incr i} {
		set ev_mkt_id [db_get_col $rs $i ev_mkt_id]
		
		set sql [subst {
			execute procedure pBFDelMonitor(
					p_adminuser      = ?,
					p_ob_id          = ?,
					p_type           = ?,
					p_transactional  = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt $USERNAME $ev_mkt_id "EM" "Y"} msg]} {
			ob::log::write ERROR {do_bf_del_mkt_sel - $msg}
			inf_close_stmt $stmt
			db_close $rs
			err_bind "ev_mkt_id : $ev_mkt_id $msg"
			return 1
		}
		inf_close_stmt $stmt
	}
	
	db_close $rs
	return 0
}

proc get_mapped_bf_ev_hierarchy {old_ev_id} {
	
	global DB USERNAME
	
	set sql {
		select
		    e.name as name0,
		    e1.name as name1,
		    e2.name as name2,
		    e3.name as name3,
		    e4.name as name4,
		    e5.name as name5,
		    e6.name as name6
		from
			tBFEvent e, tBFEvItems b,
			outer (tBFEvent e1,
			outer (tBFEvent e2,
			outer (tBFEvent e3,
			outer (tBFEvent e4,
			outer (tBFEvent e5,
			outer (tBFEvent e6))))))
		where
			b.bf_ev_items_id = ?
		and	b.bf_type = 'EV'
		and e.bf_ev_items_id = b.bf_ev_items_id
		and	e.bf_parent_id = e1.bf_ev_id
		and e1.bf_parent_id = e2.bf_ev_id
		and e2.bf_parent_id = e3.bf_ev_id
		and e3.bf_parent_id = e4.bf_ev_id
		and e4.bf_parent_id = e5.bf_ev_id
		and e5.bf_parent_id = e6.bf_ev_id
	}
	
	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt $old_ev_id]

	set nrows  [db_get_nrows $res]
	tpBindString BFEV_nrows $nrows
	
	if {$nrows > 0} {
		set desc ""
		for {set k 6} {$k >= 0} {incr k -1} {
			if {[db_get_col $res 0 name$k] != ""} {
				if {$desc == ""} {
					set desc [db_get_col $res 0 name$k]
				} else {
					append desc " -> [db_get_col $res 0 name$k]"
				}
			}
		}
		tpBindString BFEV_name $desc
	}
	
	inf_close_stmt $stmt
	db_close $res
}


#
# Helper routine to get the bf_type_id back from the 
# event id
#
proc get_bf_type_id_from_ob_id {type ob_id} { 

	global DB 
	
	set bf_type_id ""
	
	if {$type == "EVENT"} { 
		set sql {
			select 
				be.bf_type_id 
			from 
				tbfmap m,
				tbfevent be
			where 
				m.bf_ev_items_id = be.bf_ev_items_id 
			and m.ob_type = 'EV'
			and m.ob_id = ?
		}
	} else { 
		set sql {
				select distinct
					be.bf_type_id 
				from 
					tbfmap m,
					tbfevent be,
					tEv e
				where 
					m.bf_ev_items_id = be.bf_ev_items_id 
				and e.ev_type_id = m.ob_id 	
				and m.ob_type = 'ET'
				and e.ev_type_id = ?
		}
	} 
	
	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt $ob_id]

	set nrows  [db_get_nrows $res]

	if {$nrows > 0} { 
		set bf_type_id [db_get_col $res 0 bf_type_id]
	} 
	
	inf_close_stmt $stmt
	db_close $res

	ob_log::write INFO {get_bf_type_id_from_ob_id $type ob_id = $ob_id bf_type_id=$bf_type_id} 

	return $bf_type_id 
} 


#
# Retrieve core betfair event drilldown query 
#
proc get_event_list_sql {check_market bf_type_id} { 

	if {$check_market} { 
		set where1 [subst { exists (select bf_mkt_id
								  from 
									tBFMarket m 
								  where 
									m.bf_ev_id = e.bf_ev_id and
									m.mkt_susp_time > CURRENT) and }]
	} else { 
		set where1 ""
	} 

	if {$bf_type_id != ""} { 
		set where2 " bf_type_id = ? "
	} else { 
		set where2 " bf_type_id in (select bf_type_id from tBFEventType where status = 'A') "
	} 

	# Join the list of events with the tBFEventActive table if the active events config item is set
	if {[OT_CfgGet BF_USE_ACTIVE_EV 0]} {
		set from "tBFEventActive a,"
		set where3 " and	a.bf_ev_id = e.bf_ev_id "
	} else { 
		set from ""
		set where3 ""
	} 

	set sql [subst {
		select
				e.name as name0,
				b.bf_ev_items_id as bf_ev_items_id0,
				e1.name as name1,
				e2.name as name2,
				e3.name as name3,
				e4.name as name4,
				e5.name as name5,
				e6.name as name6
		from
				tBFEvent e, tBFEvItems b,
				$from
				outer (tBFEvent e1,
				outer (tBFEvent e2,
				outer (tBFEvent e3,
				outer (tBFEvent e4,
				outer (tBFEvent e5,
				outer (tBFEvent e6))))))
		where
				$where1	
					e.bf_parent_id = e1.bf_ev_id
				$where3		
				and e.bf_ev_items_id = b.bf_ev_items_id
				and	e1.bf_parent_id = e2.bf_ev_id
				and e2.bf_parent_id = e3.bf_ev_id
				and e3.bf_parent_id = e4.bf_ev_id
				and e4.bf_parent_id = e5.bf_ev_id
				and e5.bf_parent_id = e6.bf_ev_id
				and e.bf_ev_id in (select bf_ev_id from tbfevent where $where2)
	}]
	
	#ob_log::write INFO {******SQL = $sql} 
	
	return $sql
} 

# end of namespace 
}
