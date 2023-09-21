# ================================================================================================
# $Id: bf_events_unmatched.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ================================================================================================

namespace eval ADMIN::BETFAIR_EV {

asSetAct ADMIN::BETFAIR_EV::DoEvBFMatch          [namespace code do_unmatched_ev_bf_match]



#
#------------------------------------------------------------------------------------------------------------
# Search for Unmatched Openbet Events
#------------------------------------------------------------------------------------------------------------
#
proc go_ev_unmatch_sel_qry args {

	global DB EV_UNMATCHED

	if {[info exists EV_UNMATCHED]} {
		unset EV_UNMATCHED
	}

	# retreives the search filter from proc do_ev_sel_qry in ev_sel.tcl
	set where [ADMIN::EV_SEL::do_ev_sel_qry "n" "y"]

	# To retrive ev_sub_type_id
	set bf_sub_type_match [OT_CfgGet BF_SUB_TYPE_MATCH 0]

	# To retrieve the unmatched events

	set sql [subst {
		select  distinct
			c.category,
			c.name class_name,
			c.sort csort,
			t.ev_class_id class_id,
			t.name type_name,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.start_time,
			be.bf_type_id
			[expr {$bf_sub_type_match ? {,est.ev_sub_type_id} : {}}]
			[expr {$bf_sub_type_match ? {,est.name sub_type_name} : {}}]
		from
			tEvClass c,
			tEvtype  t,
			tEv      e,
			tBFMap bm,
			outer tBFEvent be
			[expr {$bf_sub_type_match ? {,outer tEvSubType est} : {}}]
		where
			e.ev_type_id = t.ev_type_id 
		and	t.ev_class_id = c.ev_class_id 
		and	t.ev_type_id = bm.ob_id 
		and	[expr {$bf_sub_type_match ? { est.ev_sub_type_id = bm.ob_sub_type_id } : {}}]
		and	bm.ob_type = 'ET' 
		and	bm.bf_ev_items_id = be.bf_ev_items_id 
		and	e.ev_id not in (select
						ob_id
					from
						tBFMap
					where
						ob_type = 'EV') 
			[expr {$bf_sub_type_match ? {and est.ev_sub_type_id = e.ev_sub_type_id } : {}}]
                        $where
                order by
                        e.start_time desc
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		ob::log::write ERROR {go_ev_unmatch_sel_qry - $msg}
	}
	
	inf_close_stmt $stmt

	set nrows_ev [db_get_nrows $res]

	set bf_type_id_hr 0

	for {set i 0} {$i < $nrows_ev} {incr i} {

		set class_id	[db_get_col $res $i class_id]
		set ev_id  		[db_get_col $res $i ev_id]
		set c_sort		[db_get_col $res $i csort]

		# if the class sort is Racing, then we need to retrieve the
		# bf_type_id from tBFEventType instead of tBFEvent
		if {$c_sort == "HR" || $c_sort == "GR"} {
			if {$bf_type_id_hr == 0} {
				# Perform this SQL as a one-time call
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
				set rs [inf_exec_stmt $stmt $racing_desc]

				if {[db_get_nrows $rs] > 0} {
					set bf_type_id [db_get_col $rs 0 bf_type_id]
					set bf_type_id_hr $bf_type_id
				}
				
				inf_close_stmt $stmt
				db_close $rs

			} else {
				set bf_type_id $bf_type_id_hr
			}
		} else {
			set bf_type_id		[db_get_col $res $i bf_type_id]
		}

		set EV_UNMATCHED($i,category)   [db_get_col $res $i category]
		set EV_UNMATCHED($i,class_name) [db_get_col $res $i class_name]
		set EV_UNMATCHED($i,type_name)  [db_get_col $res $i type_name]
		set EV_UNMATCHED($i,class_id)   $class_id
		set EV_UNMATCHED($i,ev_type_id) [db_get_col $res $i ev_type_id]
		set EV_UNMATCHED($i,ev_id)      $ev_id
		set EV_UNMATCHED($i,desc)       [db_get_col $res $i desc]
		set EV_UNMATCHED($i,start_time) [db_get_col $res $i start_time]
		set EV_UNMATCHED($i,c_sort)		$c_sort
		
		if {$bf_sub_type_match} {
			set EV_UNMATCHED($i,ev_sub_type_id)     [expr {[db_get_col $res $i ev_sub_type_id] != "" ?\
									[db_get_col $res $i ev_sub_type_id] : -99999}]
			set EV_UNMATCHED($i,sub_type_name)	[db_get_col $res $i sub_type_name]
		}
    }

    db_close $res

	tpBindString Nrows $nrows_ev

	tpBindVar Category  EV_UNMATCHED category    ev_idx
	tpBindVar Class     EV_UNMATCHED class_name  ev_idx
	tpBindVar Type      EV_UNMATCHED type_name   ev_idx
	tpBindVar EvTypeId  EV_UNMATCHED ev_type_id  ev_idx
	tpBindVar Event     EV_UNMATCHED desc        ev_idx
	tpBindVar EvId      EV_UNMATCHED ev_id       ev_idx
	tpBindVar StartTime EV_UNMATCHED start_time  ev_idx
	tpBindVar ClassSort EV_UNMATCHED c_sort	     ev_idx
	tpBindVar BFEvRows  EV_UNMATCHED bf_ev_rows  ev_idx
	tpBindVar BF_Ev_Nam EV_UNMATCHED name        ev_idx bf_ev_idx
	tpBindVar BF_Ev_Id  EV_UNMATCHED id          ev_idx bf_ev_idx

	if {$bf_sub_type_match} {
		tpBindVar SubType   EV_UNMATCHED sub_type_name   ev_idx
		tpBindVar SubTypeId EV_UNMATCHED ev_sub_type_id  ev_idx
	}

	asPlayFile bf_unmatch_ev_list.html
}



#
#------------------------------------------------------------------------------------------------------------
# Matching events to betfair events
#------------------------------------------------------------------------------------------------------------
#
proc do_unmatched_ev_bf_match args {

	global DB

	set nrows [reqGetArg Nrows]

	for {set i 0} {$i < $nrows} {incr i} {

		# Retrieving all the ev_id's and corresponding bf_ev_id's to which it has to be mapped
		set ev_id($i)           [reqGetArg EvId_$i]
		set bf_ev_id($i)        [reqGetArg BF_EventMatch_$ev_id($i)]
		set ev_type_id($i)      [reqGetArg EvTypeId_$i]
		set ev_start_time($i)	[reqGetArg EvStartTime_$i]
		set class_sort($i)		[reqGetArg ClassSort_$i]

		# Calling do_bf_ev_match to match the openbet event with the betfair event
		set bad [do_bf_ev_match $ev_type_id($i) $ev_id($i) $bf_ev_id($i) $class_sort($i) $ev_start_time($i)]

		if {$bad} {
			# Something went wrong
			err_bind "could not match the events"
			ob::log::write ERROR {do_unmatched_ev_bf_match - could not match openbet event $ev_id($i) to betfair  $bf_ev_id($i)}
			tpSetVar  EvMatched 0
			ADMIN::EV_SEL::go_ev_sel
		}
	}

	# to show that events are matched
	tpSetVar  EvMatched 1

	# To go to the events selection page
	ADMIN::EV_SEL::go_ev_sel

}

# end of namespace
}
