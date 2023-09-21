# ==============================================================
# $Id: bf_dd_tools.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (c) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================


# 
namespace eval ADMIN::BF_DD_TOOLS {

# Action Handlers
asSetAct ADMIN::BF_DD_TOOLS::GoBFEventTypes [namespace code go_bf_event_types]
asSetAct ADMIN::BF_DD_TOOLS::GoBFEvent      [namespace code go_bf_event]
asSetAct ADMIN::BF_DD_TOOLS::GoBFMarket     [namespace code go_bf_market]
asSetAct ADMIN::BF_DD_TOOLS::GoBFUnmatchedSelns \
		[namespace code go_bf_unmatched_selns]
asSetAct ADMIN::BF_DD_TOOLS::DoBFUpdateMarketSelns [namespace code update_market_selections]
asSetAct ADMIN::BF_DD_TOOLS::DoBFUpdateTypeStatus [namespace code update_event_types]


#
# List all betfair event types in the system
#
proc go_bf_event_types args {

	global DB BF_TYPE_DATA

	catch {unset BF_TYPE_DATA}

	# get all bf event types
	set sql {
		select
			bf_type_id,
			name,
			status 
		from
			tBFEventType
		order by name asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	array set BF_TYPE_DATA [list]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set BF_TYPE_DATA($i,id)   	[db_get_col $res $i bf_type_id]
		set BF_TYPE_DATA($i,name) 	[db_get_col $res $i name]
		set BF_TYPE_DATA($i,status) [db_get_col $res $i status]
	}

	# Bind up values
	tpBindVar bf_type_id   BF_TYPE_DATA id         bf_type_idx
	tpBindVar name         BF_TYPE_DATA name       bf_type_idx
	tpBindVar status       BF_TYPE_DATA status     bf_type_idx

	tpSetVar  NumTypes $nrows

	db_close $res

	asPlayFile bf_dd_ev_types.html
}


#
# Update the status of event types. If a type is suspended, new events won't be created 
# by the feed. 
#
proc update_event_types args { 

	global DB BF_TYPE_DATA

	catch {unset BF_TYPE_DATA}

	if {![op_allowed BFControlInfo]} {
		err_bind "User does not have required permissions to add,update types."
		go_bf_event_types
		return		
	}

	# get all bf event types
	set sql {
		select
			bf_type_id,
			name,
			status 
		from
			tBFEventType
		order by name asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	set sql [subst {
		update tBFEventType set status = ? where bf_type_id = ?
	}] 
					
	set stmt [inf_prep_sql $DB $sql]
				
	for {set i 0} {$i < $nrows} {incr i 1} {

		set type_id [db_get_col $res $i bf_type_id]
		set status  [db_get_col $res $i status]
		set name    [db_get_col $res $i name]
				
		if {[reqGetArg isActive_$type_id] == "on"} {
			set new_status "A"	
		} else {
			set new_status "S"
		}

		if {$status != $new_status} { 
			if {[catch {inf_exec_stmt $stmt $new_status $type_id} msg]} {
				ob_log::write ERROR {update_event_types bf_ev_type_id :: ERROR \
						Failed to update type $name in tBFEvType: $msg}
				inf_close_stmt $stmt
				inf_rollback_tran $DB
				err_bind "Could not update type $name. $msg"
				db_close $res
				go_bf_event_types
				return					
			}			
		} 
	}
	
	db_close $res

	go_bf_event_types
} 


#
# Display all betfair events for a given betfair event type/event
#
proc go_bf_event args {

	global DB BF_EV_DATA BF_MKT_DATA

	catch {unset BF_EV_DATA}
	catch {unset BF_MKT_DATA}
	catch {unset PREV_HIST_DATA}

	# get request arguments
	set bf_parent_id [reqGetArg bf_parent_id]
	set bf_type_id   [reqGetArg bf_type_id]

	_bind_prev_hist

	# get events
	ob_log::write INFO {BF_DD_TOOLS -> go_bf_event: bf_parent_id=$bf_parent_id, \
		bf_type_id=$bf_type_id}

	if {$bf_parent_id == ""} {
		set sql {
			select
				bf_ev_id,
				name
			from
				tBFEvent e
			where
				bf_type_id = ?
			and bf_parent_id is null
			and exists (
				select
					1
				from
					tBFEventActive a
				where
					a.bf_ev_id = e.bf_ev_id
			)
			order by name asc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bf_type_id]

	} else {
		set sql {
			select
				bf_ev_id,
				name
			from
				tBFEvent e
			where
				bf_parent_id = ?
			and exists (
				select
					1
				from
					tBFEventActive a
				where
					a.bf_ev_id = e.bf_ev_id
			)
			order by name asc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bf_parent_id]
	}
	

	set nrows [db_get_nrows $res]

	if {$nrows == 0} {
		tpSetVar has_events 0
	} else {
		tpSetVar has_events 1
	}

	ob_log::write INFO {BF_DD_TOOLS -> nrows = $nrows}

	array set BF_EV_DATA [list]

	for {set i 0} {$i < $nrows} {incr i 1} {
		set BF_EV_DATA($i,id)   [db_get_col $res $i bf_ev_id]
		set BF_EV_DATA($i,name) [db_get_col $res $i name]
	}

	# Bind up values
	tpBindVar bf_ev_id   BF_EV_DATA id         bf_ev_idx
	tpBindVar name       BF_EV_DATA name       bf_ev_idx

	db_close $res
	tpSetVar  NumEvs $nrows


	# get markets
	if {$bf_parent_id != ""} {

		set sql {
			select
				bf_mkt_id,
				name,
				mkt_susp_time,
				ext_mkt_id
			from
				tBFMarket m
			where
				bf_ev_id = ?
			and exists (
				select
					1
				from
					tBFEventActive a
				where
					a.bf_ev_id = m.bf_ev_id
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bf_parent_id]

		set nrows_mkt [db_get_nrows $res]

		if {$nrows_mkt != 0} {
				
			set sql1 { 
				select 
					count (*) 
				from 
					tbfevitems 
				where 
					bf_id = ? 
				and bf_type = 'EM' 
			} 			
		
			for {set j 0} {$j < $nrows_mkt} {incr j 1} {
				set BF_MKT_DATA($j,id)   		[db_get_col $res $j bf_mkt_id]
				set BF_MKT_DATA($j,name) 		[db_get_col $res $j name]
				set BF_MKT_DATA($j,mkt_time) 	[db_get_col $res $j mkt_susp_time]
				set BF_MKT_DATA($j,bf_id) 		[db_get_col $res $j ext_mkt_id]
				
				# Add in extra check for duplicate markets 
				set stmt1 [inf_prep_sql $DB $sql1]
				set res1  [inf_exec_stmt $stmt1 $BF_MKT_DATA($j,bf_id)]
				set nrows1 [db_get_coln $res1 0 ]
				db_close $res1
				set BF_MKT_DATA($j,mkt_dup) $nrows1 
			}

			inf_close_stmt $stmt1

			# Bind up values
			tpBindVar bf_mkt_id  BF_MKT_DATA id        bf_mkt_idx
			tpBindVar mkt_name   BF_MKT_DATA name      bf_mkt_idx
			tpBindVar mkt_time   BF_MKT_DATA mkt_time  bf_mkt_idx
			tpBindVar mkt_dup    BF_MKT_DATA mkt_dup   bf_mkt_idx
			tpBindVar bf_id      BF_MKT_DATA bf_id     bf_mkt_idx

			tpSetVar  NumMkts $nrows_mkt

			tpSetVar has_markets 1

			db_close $res

		} else {
			tpSetVar has_markets 0
		}
	} else {
		tpSetVar has_markets 0
	}


	asPlayFile bf_dd_ev.html
}



#
# Display all betfair markets for a given betfair event
#
proc go_bf_market args {

	global DB BF_SELN_DATA

	catch {unset BF_SELN_DATA}

	_bind_prev_hist

	set bf_mkt_id [reqGetArg bf_mkt_id]

	# get all bf event types
	set sql {
		select
			o.bf_ev_oc_id,			
			o.name,
			i.bf_id
		from			
			tBFEvItems i,
			tBFMarket m,
			outer tBFEvOc o
		where
			m.bf_mkt_id = ?
		and o.bf_mkt_id = m.bf_mkt_id
		and m.bf_ev_items_id = i.bf_ev_items_id
		order by o.name asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bf_mkt_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	array set BF_SELN_DATA [list]

	set bf_id ""

	for {set i 0} {$i < $nrows} {incr i 1} {
		set BF_SELN_DATA($i,id)   [db_get_col $res $i bf_ev_oc_id]
		set BF_SELN_DATA($i,name) [db_get_col $res $i name]
		set bf_id [db_get_col $res $i bf_id]
	}

	db_close $res

	# Bind up values
	tpBindVar bf_ev_oc_id  BF_SELN_DATA id         bf_seln_idx
	tpBindVar name         BF_SELN_DATA name       bf_seln_idx

	tpSetVar  NumSelns $nrows
	tpBindString  bf_mkt_id $bf_mkt_id 	
	tpBindString  bf_id $bf_id 

	asPlayFile bf_dd_ev_mkt.html
}



#
# Bind up a breadcrumb trail of the betfair drilldown
#
proc _bind_prev_hist args {

	global PREV_HIST_DATA

	catch {unset PREV_HIST_DATA}

	# This argument is a special one. It enables us to build a list of where
	# the current list of events fits into the overall picture.
	#
	# It contains name/value pairs for each previous level in the hierachy.
	# These must the be bound up so that they can be iterated over on the
	# resulting page.
	#
	# e.g. "1:Soccer,2:English Soccer,3:Barclays Premiership"
	set prev_hist [reqGetArg prev_hist]
	tpBindString prev_hist $prev_hist

	ob_log::write INFO {BF_DD_TOOLS -> prev_hist = $prev_hist}

	# first split on , to get each pair
	set hist_pairs [split $prev_hist ,]
	set running_hist [list]

	# now we loop through each of these construcing our array
	for {set i 0} {$i < [llength $hist_pairs]} {incr i 1} {
		set tmp_list [split [lindex $hist_pairs $i] :]
		lappend running_hist "[lindex $tmp_list 0]:[lindex $tmp_list 1]"

		set PREV_HIST_DATA($i,id)        [lindex $tmp_list 0]
		set PREV_HIST_DATA($i,name)      [lindex $tmp_list 1]
		set PREV_HIST_DATA($i,prev_hist) [join $running_hist ,]

		ob_log::write INFO {BF_DD_TOOLS -> id=[lindex $tmp_list 0]}
		ob_log::write INFO {BF_DD_TOOLS -> name=[lindex $tmp_list 1]}
		
	}

	ob_log::write INFO {BF_DD_TOOLS -> NumPrevHist = [llength $hist_pairs]}
	tpSetVar NumPrevHist [llength $hist_pairs]

	tpBindVar prev_hist_id        PREV_HIST_DATA id         prev_hist_idx
	tpBindVar prev_hist_name      PREV_HIST_DATA name       prev_hist_idx
	tpBindVar prev_hist_prev_hist PREV_HIST_DATA prev_hist  prev_hist_idx
}



#
# Display a page that lists any events that have selections that should
# be mapped to Betfair, but aren't.
#
# For example, in a horse race with 10 runners, where one runner is a non
# runner. We have already updated the selection name to be appended with N/R.
# After this, we try to auto-match to Betfair, but only 9 runners match due to
# the N/R name change. This page would then report this to the operator so that
# they could manually match if required.
#
proc go_bf_unmatched_selns args {

	global DB
	global UNMATCHED_ARR

	catch {unset UNMATCHED_ARR}

	# Find all markets mapped to betfair (auto or manual)
	# Obviously, only interested in non-settled, in the future etc.
	set bf_sql {
		select
			bmm.bf_map_id,
			count(*) as num_selns
		from
			tBFEventActive ba,
			tBFMap bmm,
			tBFEvItems bi,
			tBFMarket bm,
			tEvMkt m,
			tBFEvOc bo,
			tBFMap bmo
		where
			m.ev_mkt_id = bmm.ob_id
		and bi.bf_ev_items_id = bm.bf_ev_items_id
		and bm.bf_ev_id = ba.bf_ev_id
		and bmm.bf_ev_items_id = bi.bf_ev_items_id
		and bo.bf_mkt_id = bm.bf_mkt_id
		and bmo.bf_ev_items_id = bo.bf_ev_items_id
		and bmm.ob_type = 'EM'
		and bmo.ob_type = 'OC'
		group by
			1
	}

	set ob_sql {
		select
			bmm.bf_map_id,
			t.name as type_name,
			e.desc as ev_name,
			g.name as mkt_name,
			m.ev_mkt_id,
			count(*) as num_selns
		from
			tBFEventActive ba,
			tBFMap bmm,
			tBFEvItems bi,
			tBFMarket bm,
			tEvMkt m,
			tEvOc o,
			tEvType t,
			tEv e,
			tEvOcGrp g
		where
			m.ev_mkt_id = bmm.ob_id
		and bi.bf_ev_items_id = bm.bf_ev_items_id
		and bm.bf_ev_id = ba.bf_ev_id
		and bmm.bf_ev_items_id = bi.bf_ev_items_id
		and m.ev_mkt_id = o.ev_mkt_id
		and t.ev_type_id = e.ev_type_id
		and e.ev_id = m.ev_id
		and m.ev_oc_grp_id = g.ev_oc_grp_id
		and bmm.ob_type = 'EM'
		group by
			1,2,3,4,5
	}

	set bf_stmt [inf_prep_sql $DB $bf_sql]
	set bf_res  [inf_exec_stmt $bf_stmt]

	set ob_stmt [inf_prep_sql $DB $ob_sql]
	set ob_res  [inf_exec_stmt $ob_stmt]

	array set BF_ARR [list]
	array set OB_ARR [list]
	array set UNMATCHED_ARR [list]

	set bf_nrows [db_get_nrows $bf_res]

	for {set i 0} {$i < $bf_nrows} {incr i 1} {
		set id [db_get_col $bf_res $i bf_map_id]
		set BF_ARR($id,count) [db_get_col $bf_res $i num_selns]
	}

	set ob_nrows [db_get_nrows $ob_res]

	for {set i 0} {$i < $ob_nrows} {incr i 1} {
		set id [db_get_col $ob_res $i bf_map_id]
		set OB_ARR($id,count) 		[db_get_col $ob_res $i num_selns]
		set OB_ARR($id,type_name) 	[db_get_col $ob_res $i type_name]
		set OB_ARR($id,ev_name) 	[db_get_col $ob_res $i ev_name]
		set OB_ARR($id,mkt_name) 	[db_get_col $ob_res $i mkt_name]
		set OB_ARR($id,mkt_id) 		[db_get_col $ob_res $i ev_mkt_id]
	}

	# For each of these markets, check the number of openbet selections
	# against the number of mapped selections (and optionally) against
	# the number of betfair selections

	set u_id 0

	foreach key [array names OB_ARR *count] {
		set id [lindex [split $key ,] 0]
				
		if {[info exists BF_ARR($key)]} {
			if {$OB_ARR($key) != $BF_ARR($key)} {
			
				ob_log::write DEBUG {$OB_ARR($key) VS $BF_ARR($key)} 
			
				set UNMATCHED_ARR($u_id,type_name) 	$OB_ARR($id,type_name)
				set UNMATCHED_ARR($u_id,ev_name) 	$OB_ARR($id,ev_name)
				set UNMATCHED_ARR($u_id,mkt_name) 	$OB_ARR($id,mkt_name)
				set UNMATCHED_ARR($u_id,mkt_id) 	$OB_ARR($id,mkt_id)
				incr u_id 1
			}
		} else {
		
			ob_log::write DEBUG {key $key doesn't exist} 
		
			set UNMATCHED_ARR($u_id,type_name) 	$OB_ARR($id,type_name)
			set UNMATCHED_ARR($u_id,ev_name) 	$OB_ARR($id,ev_name)
			set UNMATCHED_ARR($u_id,mkt_name) 	$OB_ARR($id,mkt_name)
			set UNMATCHED_ARR($u_id,mkt_id) 	$OB_ARR($id,mkt_id)
			incr u_id 1
		}
	}

	# Bind up any unmatched markets
	tpSetVar num_unmatched_selns $u_id

	tpBindVar type_name UNMATCHED_ARR type_name    umatched_idx
	tpBindVar ev_name   UNMATCHED_ARR ev_name      umatched_idx
	tpBindVar mkt_name  UNMATCHED_ARR mkt_name     umatched_idx
	tpBindVar mkt_id    UNMATCHED_ARR mkt_id       umatched_idx

	asPlayFile bf_auto_match_status.html
}


#
# Send a get_market call to Betfair to get XML. Parse this and add all selections 
# which currently haven't been added to this market. 
#
proc update_market_selections {args} { 

	global DB USERNAME
	global BF_MKT

	set bf_ev_mkt_id [reqGetArg bf_id]
	set bf_mkt_id    [reqGetArg bf_mkt_id] 
	
	ob::log::write INFO {Attempting to update market selections for bf_ev_mkt_id=$bf_ev_mkt_id} 

	set ob_sql {
		select 		
			i.bf_exch_id
		from
			tBFEvItems i
		where
			i.bf_id = ?
		and i.bf_type = 'EM'		
	}

	set stmt [inf_prep_sql $DB $ob_sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_mkt_id]
	inf_close_stmt $stmt

	set nrows  [db_get_nrows $rs]
	set stored_ids [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set bf_exch_id [db_get_col $rs $i bf_exch_id]
	}

	db_close $rs

	if {$nrows < 1} { 
		err_bind "Failed to retrieve market details $bf_ev_mkt_id"
		go_bf_market 
		return 
	} elseif {$nrows > 1} { 
		err_bind "Found duplicate market details for Betfair market bf_id=$bf_ev_mkt_id\
			See support notices for fix."
		go_bf_market 
		return	
	} 
				
	set service [BETFAIR::INT::get_service $bf_exch_id]
	
	catch {unset BF_MKT}

	if {[BETFAIR::SESSION::create_session] == -1} {
		ob_log::write INFO {Failed creating a Betfair Session}
		err_bind "Failed to create Betfair Session"
		go_bf_market 
		return 
	} 
	
	#
	# Make call to Betfair
	#
	BETFAIR::INT::get_market $service 1 "$bf_exch_id,$bf_ev_mkt_id" ""

	ob_log::write_array INFO BF_MKT

	#
	# Check we've got useful information 
	#
	if {![info exists BF_MKT($bf_exch_id,$bf_ev_mkt_id,num_runners)]} {
		ob_log::write ERROR {bf-feed-worker::_get_market_info -\
			ERROR invalid market response $bf_exch_id,$bf_ev_mkt_id,num_runners }
		err_bind "Market information could not be obtained."
		go_bf_market 
		return 
	}

	#
	# Retrieve the current selections we have for this market in the Betfair 
	# heirarchy.
	#
	set sql {
		select
			bf_id,
			bf_exch_id,
			bf_asian_id
		from
			tBFEvItems
		where
			bf_parent_id = ?
		and bf_type      = 'OC'
		and bf_parent_id > 0
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_mkt_id]
	inf_close_stmt $stmt

	set nrows  [db_get_nrows $rs]
	set stored_ids [list]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend stored_ids "[db_get_col $rs $i bf_exch_id],[db_get_col $rs $i bf_id],[db_get_col $rs $i bf_asian_id]"
	}

	db_close $rs

	set num_runners $BF_MKT($bf_exch_id,$bf_ev_mkt_id,num_runners)
	
	set no_inserted 0 
	
	for {set i 0} {$i < $num_runners} {incr i} {

		#
		# Check each runner in the XML to see if we've already got it
		#
		set bf_seln_id 			$BF_MKT($bf_exch_id,$bf_ev_mkt_id,$i,selection_id)		
		set bf_asian_line_id 	$BF_MKT($bf_exch_id,$bf_ev_mkt_id,$i,asian_line_id)
		set name 				$BF_MKT($bf_exch_id,$bf_ev_mkt_id,$i,name)
		
		if {[lsearch $stored_ids "$bf_exch_id,$bf_seln_id,$bf_asian_line_id"] == "-1"} {

			set market_type $BF_MKT($bf_exch_id,$bf_ev_mkt_id,market_type)
			
			inf_begin_tran $DB
			
			#
			# Insert market selection ev items
			#			
			set sql [subst {execute procedure pBFInsEvItem (
				p_adminuser    = ?,
				p_status       = ?,
				p_bf_type      = ?,
				p_bf_exch_id   = ?,
				p_bf_parent_id = ?,
				p_bf_id        = ?,
				p_bf_asian_id  = ?,
				p_bf_desc      = ?,
				p_allow_mult   = ?
				)
			}]
			
			set stmt [inf_prep_sql $DB $sql]
			
			if {[catch {set rs [inf_exec_stmt $stmt $USERNAME\
									"A"\
									"OC"\
									$bf_exch_id\
									$bf_ev_mkt_id\
									$bf_seln_id\
									$bf_asian_line_id\
									$name\
							    	"N"]} msg]} {
				ob_log::write ERROR {update_market_selections ins_ev_item_exch :: ERROR \
						Failed to insert OC in tBFEvItems: $msg}
				inf_close_stmt $stmt
				inf_rollback_tran $DB
				err_bind "Could not insert runner $name. $msg"
				continue 				
			}
			
			set bf_ev_items_id [db_get_coln $rs 0 0]
			db_close $rs
						
			#
			# Insert the selection into tBFEvOc
			#			
			set sql [subst {
				execute procedure pBFInsEvOc (
							p_ext_ev_oc_id 	= ?,
							p_name 		= ?,
							p_bf_mkt_id 	= ?,
							p_handicap 	= ?,
							p_bf_ev_items_id = ?,
							p_bf_asian_line_id  = ?
				)
			}]
			
			set stmt [inf_prep_sql $DB $sql]
			
			if {[catch {set rs [inf_exec_stmt $stmt \
								$bf_seln_id \
								$name \
								$bf_mkt_id \
								$BF_MKT($bf_exch_id,$bf_ev_mkt_id,$i,handicap)\
								$bf_ev_items_id\
								$bf_asian_line_id]} msg]} {
				ob_log::write ERROR {_insert_new_selections ins_selection:: ERROR \
						Failed to insert OC in tBFEvOc: $msg}
				inf_close_stmt $stmt
				inf_rollback_tran $DB
				err_bind "Could not insert runner $name. $msg"
				continue
			}
			
			set bf_oc_id [db_get_coln $rs 0 0]
			db_close $rs
			
			inf_commit_tran $DB			
			incr no_inserted 
			
			ob_log::write ERROR {INSERTED OC name=$name bf_oc_id=$bf_oc_id bf_ev_items_id=$bf_ev_items_id } 
		} else { 
			ob_log::write ERROR {ALREADY HAVE OC $name} 
		} 
	}

	if {$no_inserted > 0} { 
		tpBindString UpdateMessage "Inserted $no_inserted selection(s)" 
	} else { 
		tpBindString UpdateMessage "No selections inserted" 
	} 
	
	go_bf_market	
} 



# close namespace
}
