# ================================================================================================
# $Id: bf_dd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# Allows an admin user to navigate through the betfair event hierarchy
# in a popup to select an event to match
#
# ================================================================================================

namespace eval ADMIN::BETFAIR_DD {

asSetAct ADMIN::BETFAIR_DD::GoBfDD			[namespace code go_bf_dd]
asSetAct ADMIN::BETFAIR_DD::GoBfEv			[namespace code go_bf_ev]
asSetAct ADMIN::BETFAIR_DD::GoBfMkts 		[namespace code go_bf_mkt]
asSetAct ADMIN::BETFAIR_DD::GoBfTypeDD		[namespace code go_bf_type_dd]
asSetAct ADMIN::BETFAIR_DD::GoBfClassDD		[namespace code go_bf_class_dd]
asSetAct ADMIN::BETFAIR_DD::GoBfEvType		[namespace code go_bf_type_ev]
asSetAct ADMIN::BETFAIR_DD::GoBFHierChanges [namespace code go_bf_hier_changes]

#
#------------------------------------------------------------------------------------------------------------
# Open up the betfair event hierarchy at a mapped event type
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_dd {} {

	global DB

	set ev_type_id	[reqGetArg ev_type_id]
	set ev_id	[reqGetArg ev_id]

	set ev_sub_type_id [reqGetArg ev_sub_type_id]

	set bf_sub_type_match [OT_CfgGet BF_SUB_TYPE_MATCH 0]

	if {$bf_sub_type_match && $ev_sub_type_id != "" && $ev_sub_type_id != "-99999"} {	
		set where "and m.ob_sub_type_id = ?"
	} else {
		set where "and m.ob_sub_type_id is null"
	}

	#so that the back button is not displayed
	tpSetVar ShowBackButton 0

	set sql [subst {
		select
		    m.bf_ev_items_id,
		    i.bf_type
		from
		    tBFMap     m,
		    tBFEvItems i
		where
		    m.ob_type        = 'ET'
		and m.ob_id          = ?
		and m.bf_ev_items_id = i.bf_ev_items_id
		$where
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {$ev_sub_type_id != "" } {
		set rs [inf_exec_stmt $stmt $ev_type_id $ev_sub_type_id]
	} else {
		set rs [inf_exec_stmt $stmt $ev_type_id]
	}
		

	if {[db_get_nrows $rs]} {
		set bf_type        [db_get_col $rs 0 bf_type]
		set bf_ev_items_id [db_get_col $rs 0 bf_ev_items_id]
	} else {
		set bf_type "_none_"
	}

	inf_close_stmt $stmt
	db_close $rs

	switch $bf_type {
		"ET" { go_bf_ev_type $bf_ev_items_id $ev_id }
		"EV" { go_bf_ev $bf_ev_items_id $ev_id }
		default {
			tpBindString title ERROR
			asPlayFile -nocache bf_dd.html
		}
	}
}

#
#------------------------------------------------------------------------------------------------------------
# Retrieve all betfair events one level beneath an event type
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_ev_type {bf_ev_items_id ev_id} {

	global DB
	global BF_DD
	
	array unset BF_DD
	
	ob::log::write INFO {go_bf_ev_type - Betfair events for bf_ev_items_id=$bf_ev_items_id}

	set bf_match_name	[reqGetArg bf_match_name]
	
	#to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select {+ORDERED}
			t.bf_type_id,
			t.name as bf_type_name,
			t.bf_ev_items_id as bf_parent_items_id,
			e.bf_ev_id,
			e.bf_ev_items_id,
			e.name,
			nvl(round(count(c.bf_ev_id)),0)  as num_child,
			nvl(round(count(m.bf_mkt_id)),0) as num_mkts
		from
			tBFEventType    t,
			tBFEvent        e,
			OUTER tBFEvent  c,
			OUTER tBFMarket m
			[expr {$use_tbfeventactive ? {,tbfeventactive ea} : {}}]
		where
			t.bf_ev_items_id = ?
			and t.bf_type_id     = e.bf_type_id
			and e.bf_level       = 2
			and e.bf_parent_id   is null
			and e.bf_ev_id       = c.bf_parent_id
			and e.bf_ev_id       = m.bf_ev_id
			[expr {$use_tbfeventactive ? {and ea.bf_ev_id = e.bf_ev_id} : {}}]
		group by
			1,2,3,4,5,6
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_items_id]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]
	
	if {$nrows} {
		set bf_name "[db_get_col $rs 0 bf_type_name]"
	} else {
		set bf_name ""
	}


	for {set i 0} {$i < $nrows} {incr i} {
		foreach n $cols {
			set BF_DD($i,$n) [db_get_col $rs $i $n]
		}
		set BF_DD($i,BF_NAME) "$bf_name -> [db_get_col $rs $i name] "
	}

	inf_close_stmt $stmt
	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}
	tpBindVar BF_NAME BF_DD BF_NAME dd_idx
	
	tpBindString level TYPE
	tpSetVar     level TYPE

	if {$nrows} {
		tpBindString title $BF_DD(0,bf_type_name)
	}

	tpBindString EV_ID $ev_id

	asPlayFile -nocache bf_dd.html

}

#
#------------------------------------------------------------------------------------------------------------
# Retrieve all the child events of a betfair event
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_ev { {bf_ev_items_id ""} {ev_id ""} } {

	global DB
	global BF_DD

	array unset BF_DD
	
	ob::log::write INFO {go_bf_ev - Betfair events for bf_ev_items_id=$bf_ev_items_id}

	set bf_match_name	[reqGetArg bf_match_name]
	
	#to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	if {$bf_ev_items_id eq ""} {
		set bf_ev_items_id [reqGetArg bf_ev_items_id]
	}

	if {$ev_id eq ""} {
		set ev_id [reqGetArg ev_id]
	}

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select {+ORDERED}
			t.bf_type_id,
			t.name           as bf_type_name,
			e.bf_ev_id       as bf_parent_ev_id0,
			e.name           as bf_parent_name0,
			e1.name          as bf_parent_name1,
                        e2.name          as bf_parent_name2,
                        e3.name          as bf_parent_name3,
                        e4.name          as bf_parent_name4,
                        e5.name          as bf_parent_name5,
                        e6.name          as bf_parent_name6,
			c.bf_ev_items_id,
			c.bf_ev_id,
			c.name,
			nvl(round(count(cl.bf_ev_id)),0)  as num_child,
			nvl(round(count(m.bf_mkt_id)),0)  as num_mkts
		from
			tBFEvent        e,
			tBFEventType    t,
			tBFEvent        c,
			OUTER tBFEvent  cl,
			OUTER (tBFEvent e1,
			OUTER (tBFEvent e2,
			OUTER (tBFEvent e3,
			OUTER (tBFEvent e4,
			OUTER (tBFEvent e5,
			OUTER (tBFEvent e6)))))),
			OUTER tBFMarket m
			[expr {$use_tbfeventactive ? {,tbfeventactive ea} : {}}]
		where
			e.bf_ev_items_id = ?
			and e.bf_type_id     = t.bf_type_id
			and e.bf_ev_id       = c.bf_parent_id
			and c.bf_ev_id       = cl.bf_parent_id
			and e.bf_parent_id   = e1.bf_ev_id
			and e1.bf_parent_id  = e2.bf_ev_id
                	and e2.bf_parent_id  = e3.bf_ev_id
	                and e3.bf_parent_id  = e4.bf_ev_id
        	        and e4.bf_parent_id  = e5.bf_ev_id
                	and e5.bf_parent_id  = e6.bf_ev_id
			and c.bf_ev_id       = m.bf_ev_id
			[expr {$use_tbfeventactive ? {and ea.bf_ev_id = c.bf_ev_id} : {}}]
		group by
			1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
			11,12,13
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_items_id]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]

	if {$nrows} {
		set bf_name "[db_get_col $rs 0 bf_type_name]" 

		for {set i 6} {$i >= 0 } {incr i -1} {
			if {[db_get_col $rs 0 bf_parent_name$i] != "" } {
				set bf_name "$bf_name -> [db_get_col $rs 0 bf_parent_name$i]"
			}	
		}
	} else {
                set bf_name ""
        }


	for {set i 0} {$i < $nrows} {incr i} {
		foreach n $cols {
			set BF_DD($i,$n) [db_get_col $rs $i $n]
		}
		set BF_DD($i,BF_NAME) "$bf_name -> [db_get_col $rs $i name] "
	}

	inf_close_stmt $stmt
	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}
	tpBindVar BF_NAME BF_DD BF_NAME dd_idx
	
	tpBindString level EVENT
	tpSetVar     level EVENT

	if {$nrows} {
		tpBindString title $bf_name 
	}

	tpBindString EV_ID $ev_id

	asPlayFile -nocache bf_dd.html
}

#
#------------------------------------------------------------------------------------------------------------
# Retrieve all the markets of a betfair event
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_mkt { {bf_ev_items_id ""} {ev_id ""} } {

	global DB
	global BF_DD

	array unset BF_DD
	
	ob::log::write INFO {go_bf_mkt - Betfair markets for bf_ev_items_id=$bf_ev_items_id}

	set bf_match_name	[reqGetArg bf_match_name]
	set ev_id 		[reqGetArg ev_id]

	#to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	if {$bf_ev_items_id eq ""} {
		set bf_ev_items_id [reqGetArg bf_ev_items_id]
	}

	if {$ev_id eq ""} {
		set ev_id [reqGetArg ev_id]
	}

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select {+ORDERED}
                        t.name           as bf_type_name,
                        t.bf_type_id,
                        e.bf_ev_items_id as bf_parent_items_id0,
                        e.name           as bf_parent_name0,
                        e1.name          as bf_parent_name1,
                        e2.name          as bf_parent_name2,
                        e3.name          as bf_parent_name3,
                        e4.name          as bf_parent_name4,
                        e5.name          as bf_parent_name5,
                        e6.name          as bf_parent_name6,
                        m.bf_ev_items_id,
                        m.bf_ev_id,
                        m.name
                from
                        tBFEvent        e,
                        tBFMarket       m,
                        tBFEventType    t,
                        OUTER (tBFEvent e1,
                        OUTER (tBFEvent e2,
                        OUTER (tBFEvent e3,
                        OUTER (tBFEvent e4,
                        OUTER (tBFEvent e5,
                        OUTER (tBFEvent e6))))))
			[expr {$use_tbfeventactive ? {, tbfeventactive ea} : {}}]
                where
			e.bf_ev_items_id = ?
	                and e.bf_ev_id       = m.bf_ev_id
        	        and m.bf_type_id     = t.bf_type_id
                	and e.bf_parent_id   = e1.bf_ev_id
			and e1.bf_parent_id  = e2.bf_ev_id
        	        and e2.bf_parent_id  = e3.bf_ev_id
                	and e3.bf_parent_id  = e4.bf_ev_id
	                and e4.bf_parent_id  = e5.bf_ev_id
        	        and e5.bf_parent_id  = e6.bf_ev_id
			[expr {$use_tbfeventactive ? {and ea.bf_ev_id = e.bf_ev_id} : {}}]
	}]
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_items_id]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach n $cols {
			set BF_DD($i,$n) [db_get_col $rs $i $n]
		}
	}

	inf_close_stmt $stmt

	if {$nrows} {
	    set bf_name "[db_get_col $rs 0 bf_type_name]"
	} else {
		set bf_name ""
	}
	for {set i 6} {$i >= 0 } {incr i -1} {
		if {[db_get_col $rs 0 bf_parent_name$i] != "" } {
			set bf_name "$bf_name -> [db_get_col $rs 0 bf_parent_name$i]"
		}
	}

	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}

	tpBindString level MARKET
	tpSetVar     level MARKET

	if {$nrows} {
		tpBindString title $bf_name
	}

	tpBindString EV_ID $ev_id

	asPlayFile -nocache bf_dd.html
}

#
#------------------------------------------------------------------------------------------------------------
# Open up the betfair event hierarchy at a mapped class level
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_type_dd {} {

    global DB

	set ev_class_id [reqGetArg ev_class_id]

	#so that the back button is not displayed
	tpSetVar ShowBackButton 0
	
	set match_class [ADMIN::BETFAIR_TYPE::bf_class_match "ID" $ev_class_id]

	if {!$match_class} { 		
		set bf_ev_items_id [reqGetArg bf_ev_items_id]
		set bf_type "ET"

	} else {
		set sql [subst {
				select
					m.bf_ev_items_id,
					i.bf_type
				from
					tBFMap     m,
					tBFEvItems i
				where
					m.ob_type        = 'EC'
				and m.ob_id          = ?
				and m.bf_ev_items_id = i.bf_ev_items_id
		}]

		set stmt [inf_prep_sql $DB $sql]

		set rs [inf_exec_stmt $stmt $ev_class_id]

		if {[db_get_nrows $rs]} {
			set bf_type        [db_get_col $rs 0 bf_type]
			set bf_ev_items_id [db_get_col $rs 0 bf_ev_items_id]
		} else {
			set bf_type "_none_"
		}

		inf_close_stmt $stmt
		db_close $rs
	}

	switch $bf_type {
		"ET" { 
			go_bf_type $bf_ev_items_id
		}
		default {
	 		tpBindString title ERROR
			asPlayFile -nocache bf_dd.html
		}
	}
}

#
#------------------------------------------------------------------------------------------------------------
# Retrieve all betfair events one level beneath an event type
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_type {bf_ev_items_id} {

	global DB
	global BF_DD

	array unset BF_DD
	
	ob::log::write INFO {go_bf_type - Betfair events for bf_ev_items_id=$bf_ev_items_id}

	set bf_match_name	[reqGetArg bf_match_name]
	set ev_type_id  	[reqGetArg ev_type_id]
	set ev_sub_type_id 	[reqGetArg ev_sub_type_id]

	# to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select {+ORDERED}
			t.bf_type_id,
			t.name as bf_type_name,
			t.bf_ev_items_id as bf_parent_items_id,
			e.bf_ev_id,
			e.bf_ev_items_id,
			e.name,
			nvl(round(count(c.bf_ev_id)),0)  as num_child
		from
			tBFEventType    t,
			tBFEvent        e,
			OUTER tBFEvent  c
			[expr {$use_tbfeventactive ? {,tbfeventactive ea} : {}}]
		where
			t.bf_ev_items_id = ?
			and t.bf_type_id     = e.bf_type_id
			and e.bf_level       = 2
			and e.bf_parent_id   is null
			and e.bf_ev_id       = c.bf_parent_id
			[expr {$use_tbfeventactive ? {and ea.bf_ev_id = e.bf_ev_id} : {}}]
		group by
			1,2,3,4,5,6
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_items_id]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]
	
	if {$nrows} {
		set bf_name "[db_get_col $rs 0 bf_type_name]"
	} else {
    	set bf_name ""
    }


	for {set i 0} {$i < $nrows} {incr i} {
		foreach n $cols {
			set BF_DD($i,$n) [db_get_col $rs $i $n]
		}
		set BF_DD($i,BF_NAME) "$bf_name -> [db_get_col $rs $i name] "
	}

	inf_close_stmt $stmt
	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}
	tpBindVar BF_NAME BF_DD BF_NAME dd_idx

	if {$nrows} {
		tpBindString title $BF_DD(0,bf_type_name)
	}
	
	tpBindString EV_TYPE_ID $ev_type_id
	
	asPlayFile -nocache bf_type_dd.html
}

#
#------------------------------------------------------------------------------------------------------------
# Retrieve all the child events of a betfair event
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_type_ev {} {

	global DB
	global BF_DD

	array unset BF_DD
	
	set bf_match_name	[reqGetArg bf_match_name]
	
	#to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	set bf_ev_items_id 	[reqGetArg bf_ev_items_id]
	set ev_type_id		[reqGetArg ev_type_id]
	set ev_sub_type_id 	[reqGetArg ev_sub_type_id]
	
	ob::log::write INFO {go_bf_type_ev - Betfair events for bf_ev_items_id=$bf_ev_items_id}

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select {+ORDERED}
			t.bf_type_id,
			t.name           as bf_type_name,
			e.bf_ev_id       as bf_parent_ev_id0,
			e.name           as bf_parent_name0,
			e1.name          as bf_parent_name1,
			e2.name          as bf_parent_name2,
			e3.name          as bf_parent_name3,
			e4.name          as bf_parent_name4,
			e5.name          as bf_parent_name5,
			e6.name          as bf_parent_name6,
			c.bf_ev_items_id,
			c.bf_ev_id,
			c.name,
			nvl(round(count(cl.bf_ev_id)),0)  as num_child
		from
			tBFEvent        e,
			tBFEventType    t,
			tBFEvent        c,
			OUTER tBFEvent  cl,
			OUTER (tBFEvent e1,
			OUTER (tBFEvent e2,
			OUTER (tBFEvent e3,
			OUTER (tBFEvent e4,
			OUTER (tBFEvent e5,
			OUTER (tBFEvent e6))))))
			[expr {$use_tbfeventactive ? {,tbfeventactive ea} : {}}]
		where
			e.bf_ev_items_id = ?
			and e.bf_type_id     = t.bf_type_id
			and e.bf_ev_id       = c.bf_parent_id
			and c.bf_ev_id       = cl.bf_parent_id
			and e.bf_parent_id   = e1.bf_ev_id
			and e1.bf_parent_id  = e2.bf_ev_id
			and e2.bf_parent_id  = e3.bf_ev_id
			and e3.bf_parent_id  = e4.bf_ev_id
			and e4.bf_parent_id  = e5.bf_ev_id
			and e5.bf_parent_id  = e6.bf_ev_id
			[expr {$use_tbfeventactive ? {and ea.bf_ev_id = c.bf_ev_id} : {}}]
		group by
			1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
			11,12,13
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ev_items_id]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]

	if {$nrows} {
		set bf_name "[db_get_col $rs 0 bf_type_name]" 

		for {set i 6} {$i >= 0 } {incr i -1} {
			if {[db_get_col $rs 0 bf_parent_name$i] != "" } {
				set bf_name "$bf_name -> [db_get_col $rs 0 bf_parent_name$i]"
			}	
		}
	} else {
		set bf_name ""
	}

	for {set i 0} {$i < $nrows} {incr i} {
		foreach n $cols {
			set BF_DD($i,$n) [db_get_col $rs $i $n]
		}
		set BF_DD($i,BF_NAME) "$bf_name -> [db_get_col $rs $i name] "
	}

	inf_close_stmt $stmt
	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}
	tpBindVar BF_NAME BF_DD BF_NAME dd_idx
	
	if {$nrows} {
		tpBindString title $bf_name 
	}

	tpBindString EV_TYPE_ID $ev_type_id

	asPlayFile -nocache bf_type_dd.html
}


#
#------------------------------------------------------------------------------------------------------------
# Retrieve all betfair events one level beneath an event type
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_class_dd {args} {

	global DB
	global BF_DD

	array unset BF_DD
	
	ob::log::write INFO {go_bf_class_dd - Betfair Active Classes}

	set bf_match_name	[reqGetArg bf_match_name]
	set ev_type_id  	[reqGetArg ev_type_id]
	set ev_class_id  	[reqGetArg ev_class_id]
	set ev_sub_type_id 	[reqGetArg ev_sub_type_id]

	# to show deselect button
	if {$bf_match_name eq ""} {
		tpSetVar ShowDeselectButton 0
	}
	tpBindString bf_match_name $bf_match_name

	set use_tbfeventactive [OT_CfgGet BF_USE_ACTIVE_EV 0]

	set sql [subst {
		select
			t.bf_type_id,
			t.name,
			t.status,
			t.bf_ev_items_id
		from
			tBFEventType    t		
		order by 
			t.name asc		
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	set cols [db_get_colnames $rs]

	tpSetVar bf_dd_nrows [set nrows [db_get_nrows $rs]]

	for {set i 0} {$i < $nrows} {incr i} {
		set BF_DD($i,bf_type_id) 		[db_get_col $rs $i bf_type_id]
		set BF_DD($i,status) 	 		[db_get_col $rs $i status]
		set BF_DD($i,name) 				[db_get_col $rs $i name]
		set BF_DD($i,bf_ev_items_id) 	[db_get_col $rs $i bf_ev_items_id]		
	}

	inf_close_stmt $stmt
	db_close $rs

	foreach c $cols {
		tpBindVar $c BF_DD $c dd_idx
	}
		
	tpBindString EV_TYPE_ID $ev_type_id
	tpBindString EV_CLASS_ID $ev_class_id
	
	asPlayFile -nocache bf_class_dd.html
}



#
#------------------------------------------------------------------------------------------------------------
# Open up the betfair event hierarchy at a mapped event type
#------------------------------------------------------------------------------------------------------------
#
proc go_bf_hier_changes {} {

	global DB
	global HIER

	set sql [subst {
		select
			i.bf_ev_items_id,
			i.bf_id,
			c.cr_date,
		    c.bf_desc as old_bf_desc,
		    c.country as old_country,
		    c.mkt_time as old_mkt_time,
		    c.name as old_name,
		    c.menu_path as old_menu_path,
		    c.ev_hierarchy as old_ev_hierarchy,
		    i.bf_desc,
		    m.country,
		    m.mkt_time,
		    m.name,
		    m.menu_path,
		    m.ev_hierarchy
		from
		    tBFMktChange c,
		    tBFEvItems i,
		    tBFMarket m
		where 
			c.bf_ev_items_id = i.bf_ev_items_id
		and m.bf_ev_items_id = i.bf_ev_items_id
		order by c.cr_date desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	set cols [db_get_colnames $rs]
	
	set nrows [db_get_nrows $rs]

	ob_log::write INFO {AAA $nrows} 

	set cf_cols [list "bf_desc" "country" "mkt_time" "name" "menu_path" "ev_hierarchy"]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c $cols {
			set HIER($i,$c) [db_get_col $rs $i $c]
		}	
		
		foreach c $cf_cols {
			if {$HIER($i,old_$c) != $HIER($i,$c)} { 
				set HIER($i,changed_$c) 1
			} else { 
				set HIER($i,changed_$c) 0
			} 
		} 
	} 
	
	inf_close_stmt $stmt	
	db_close $rs

	tpSetVar NumChanges $nrows

	foreach c $cols {
		tpBindVar $c HIER $c dd_idx
	}
	
	foreach c $cf_cols { 
		tpBindVar changed_$c HIER changed_$c dd_idx
	} 
	
	asPlayFile -nocache bf_hier_change.html
}


# end of namespace
}
