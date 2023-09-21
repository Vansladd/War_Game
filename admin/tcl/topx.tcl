# ==============================================================
# $Id: topx.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Manage configuration settings and event weightings for Top X Bets system
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::TOPX {

asSetAct ADMIN::TOPX::GoTopx    [namespace code go_topx]
asSetAct ADMIN::TOPX::DoTopx    [namespace code do_topx]
asSetAct ADMIN::TOPX::Select    [namespace code go_hierarchy]

set CFG_TYPE(BS_TEASER_STATUS)    char
set CFG_TYPE(BS_TEASER_EXPANDED)  char
set CFG_TYPE(BS_TEASER_BETS)      int
set CFG_TYPE(BS_CANVAS_BETS)      int
set CFG_TYPE(MIN_START_TIME_MINS) int
set CFG_TYPE(MAX_EVENT_END_HOURS) int

set CFG_TYPE(TOLERANCE_WIDE)      int
set CFG_TYPE(TOLERANCE_NARROW)    int
set CFG_TYPE(TOLERANCE_INIT)      int

set CFG_TYPE(POPULARITY_WIDE)     int
set CFG_TYPE(POPULARITY_NARROW)   int
set CFG_TYPE(POPULARITY_INIT)     int

# -----------------------------------------------------------------------------
# Action Handlers
# -----------------------------------------------------------------------------

# Show the initial settings page
proc go_topx args {
	if {![op_allowed TopXModify]} {
		return
	}

	global VIEWS SPORTS TOPX

	set view [get_current_view]

	tpSetVar NumViews       [bind_views VIEWS]
	tpSetVar NumSports      [bind_sports SPORTS $view]	

	# See if we have a sort request
	set sort [reqGetArg sort]
	if {$sort == "spots" || $sort == "weight" || $sort == "total"} {
		tpSetVar NumTopX [bind_topx TOPX $sort]
	} else {
		tpSetVar NumTopX [bind_topx TOPX]
	}

	bind_settings

	tpBindString View $view
	tpBindString ToleranceLimit  [OT_CfgGet TOLERANCE_LIMIT  500]
	tpBindString PopularityLimit [OT_CfgGet POPULARITY_LIMIT 500]

	asPlayFile topx.html

	catch {unset VIEWS}
	catch {unset SPORTS}
	catch {unset TOPX}
}

# Helper function to create a list of crumbs for use with
# bind_breadcrumbs from the stage we are at and a result from
# a get_*_by_id proc
proc build_crumbs {stage data_name} {
	upvar $data_name data
	set crumbs [list]

	set stages [list category class type event market selection]
	lappend crumbs [list "Choose a category" "?action=ADMIN::TOPX::Select"]

	foreach s $stages {
		if {$s == $stage} {
			lappend crumbs [list $data(${s}_name)]
				break
		} else {
			lappend crumbs [list $data(${s}_name) \
				"?action=ADMIN::TOPX::Select&$s=$data(${s}_id)"]
		}
	}

	return $crumbs
}

proc go_hierarchy args {
	if {![op_allowed TopXModify]} {
		return
	}

	global MENU CRUMBS SELN

	#
	# Set the name of the current view
	#
	set view [get_current_view]
	set numv [bind_views views]

	for {set i 0} {$i < $numv} {incr i} {
		if {$views($i,view) == $view} {
			tpBindString ViewName $views($i,name)
		}
	}

	#
	# Find out where we are in the hierarchy and fill menu items
	#
	# 1. Check for request variables in reverse order of the stages of the
	#    hierarchy to see what stage we have reached (selection stage gets
	#    special treatment)
	# 2. Generate a list containing the links to each previous stage for the
	#    breadcrumb navigation.
	# 3. Fill menu items for this stage from the database
	#


	set stages [list selection market event type class category start]

	foreach stage $stages {
		if {[reqGetArg $stage] != ""} {
			get_${stage}_by_id [reqGetArg $stage] result

			set crumbs [build_crumbs $stage result]
			tpSetVar NumCrumbs [bind_breadcrumbs CRUMBS $crumbs]

			if {$stage == "market"} {
				fill_selection_menu MENU $result(market_id)
				tpBindString MarketId $result(market_id)
				tpSetVar NumSeln [bind_selections_for_market SELN $result(market_id)]
				tpSetVar Stage "market"
			} else {
				set next_stage [lindex $stages [expr {[lsearch $stages $stage] - 1}]]
				fill_${next_stage}_menu MENU $result(${stage}_id)
			}
			break
		}

		if {$stage == "start"} {
			set breadcrumbs {
				{"Choose a category:"}
			}
			tpSetVar NumCrumbs [bind_breadcrumbs CRUMBS $breadcrumbs]

			fill_category_menu MENU
			break
		}
	}

	tpBindString View $view

	asPlayFile topx_hierarchy.html

	catch {unset MENU}
	catch {unset CRUMBS}
	catch {unset SELN}
}


# Delegate actions for form submissions
proc do_topx args {
	if {![op_allowed TopXModify]} {
		return
	}

	set act [reqGetArg SubmitName]

	switch $act {
		"ChangeView"     go_topx
		"GoHierarchy"    go_hierarchy
		"TopxUpdate"     do_topx_mod
		"UpdateWeight"   do_weight_mod
		"UpdateTopXConf" do_search_mod

		default {
			error "Unexpected action '$act'"
		}
	}
}

# Detect if we came from the hierarchy page or topx page and
# despatch to the corresponding action handler
proc go_back args {
	if {[reqGetArg select] == "true"} {
		reqSetArg market [reqGetArg MarketId]
		return [go_hierarchy]
	} else {
		return [go_topx]
	}

}

proc do_search_mod args {
	global DB
	variable CFG_TYPE

	set view              [reqGetArg view]

	set tolerance_init    [reqGetArg tolerance_init]
	set tolerance_wide    [reqGetArg tolerance_wide]
	set tolerance_narrow  [reqGetArg tolerance_narrow]
	set popularity_init   [reqGetArg popularity_init]
	set popularity_wide   [reqGetArg popularity_wide]
	set popularity_narrow [reqGetArg popularity_narrow]

	if {$CFG_TYPE(TOLERANCE_WIDE) != $tolerance_wide} {
		_do_upd_search_tolerance "TOLERANCE_WIDE" $tolerance_wide $view	
	}

	if {$CFG_TYPE(TOLERANCE_NARROW) != $tolerance_narrow} {
		_do_upd_search_tolerance "TOLERANCE_NARROW" $tolerance_narrow $view	
	}

	if {$CFG_TYPE(TOLERANCE_INIT) != $tolerance_init} {
		_do_upd_search_tolerance "TOLERANCE_INIT" $tolerance_init $view	
	}

	if {$CFG_TYPE(POPULARITY_WIDE) != $popularity_wide} {
		_do_upd_search_tolerance "POPULARITY_WIDE" $popularity_wide $view	
	}

	if {$CFG_TYPE(POPULARITY_NARROW) != $popularity_narrow} {
		_do_upd_search_tolerance "POPULARITY_NARROW" $popularity_narrow $view	
	}

	if {$CFG_TYPE(POPULARITY_INIT) != $popularity_init} {
		_do_upd_search_tolerance "POPULARITY_INIT" $popularity_init $view	
	}

	go_topx
}

proc _do_upd_search_tolerance {config_name config_value {view "gb"}} {
	global DB

	set sql {
		update tTopXCfg
		set 
			topxcfg_int = ?
		where 
			topxcfg_type = ?
			and view = ?
	}


	set st [inf_prep_sql $DB $sql]
	inf_exec_stmt $st $config_value $config_name $view

	inf_close_stmt $st
}

# Add a weighting for selection
proc do_weight_mod args {
	global DB

	set selection_id [reqGetArg ev_oc_id]
	set weighting    [reqGetArg weight_$selection_id]
	# If we are coming from topx_hierarchy.html, arg is just "weight"
	if {$weighting == ""} {
		set weighting [reqGetArg weight]
	}

	set view         [get_current_view]

	if {![string is integer $weighting]} {
		ob_log::write ERROR "Trying to update weighting but received non-integer weight value"
		err_bind "Weight must be an integer"
		return [go_back]
	}

	inf_begin_tran $DB
	#
	# Add a 0 value spot count if there isn't an entry already
	#
	set sql {
		select
			count
		from
			tTopXSeln
		where
			ev_oc_id = ?
	}

	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $selection_id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]
	db_close $rs

	if {$nrows == 0} {
		set sql {
			insert into tTopXSeln(
				ev_oc_id,
				count
			) values (
				?, 0
			)
		}

		set st [inf_prep_sql $DB $sql]

		if {[catch {
			inf_exec_stmt $st $selection_id
		} msg]} {
			inf_rollback_tran $DB
			ob_log::write ERROR "Error inserting 0 value row into TopX summary table: $msg"
			err_bind "Error updating summary table for manual weighting"
			inf_close_stmt $st
			return [go_back]
		}
		inf_close_stmt $st
	}

	#
	# Delete anything already in there
	#
	set sql {
		delete from
			tTopXWeight
		where
			ev_oc_id = ?
			and view = ?
	}

	set st [inf_prep_sql $DB $sql]
	inf_exec_stmt $st $selection_id $view
	inf_close_stmt $st

	#
	# Then insert the new value
	#
	if {$weighting != 0} {
		set sql {
			insert into tTopXWeight(
				ev_oc_id,
				weighting,
				view
			) values (
				?, ?, ?
			)
		}

		set st [inf_prep_sql $DB $sql]

		if {[catch {
			inf_exec_stmt $st $selection_id $weighting $view
		} msg]} {
			inf_rollback_tran $DB
			ob_log::write ERROR "Error inserting manual weighting for selection $selection_id: $msg"
			err_bind "Error inserting manual weighting for selection $selection_id"
			inf_close_stmt $st
			return [go_back]
		}
		inf_close_stmt $st
	}


	inf_commit_tran $DB
	msg_bind "Successfully added weighting"
	go_topx
}

# Copy settings and sports from one view to another
proc do_topx_copy args {
	global DB
	set dest_view [get_current_view]
	set src_view  [reqGetArg copy_view]

	if {$dest_view == $src_view} {
		err_bind "Cannot copy a view to itself"
		return
	}

	# ---------------------------------
	# Sport Config
	# ---------------------------------

	set delete_sql {
		delete from
			tTopXViewSports
		where
			view = ?
	}

	set sql [subst {
		insert into tTopXViewSports(
			sport_id,
			view
		) select
			sport_id,
			"$dest_view" as view
		from
			tTopXViewSports
		where
			view = ?
	}]

	set st [inf_prep_sql $DB $delete_sql]
	inf_exec_stmt $st $dest_view
	inf_close_stmt $st

	inf_begin_tran $DB
	set st [inf_prep_sql $DB $sql]
	if {[catch {
		inf_exec_stmt $st $src_view
	} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR "Error copying TopX sport config: $msg"
		error "Error copying sports"
	}
	inf_close_stmt $st


	# ---------------------------------
	# Settings
	# ---------------------------------

	set delete_sql {
		delete from
			tTopXCfg
		where
			view = ?
	}

	set sql [subst {
		insert into tTopXCfg(
			topxcfg_type,
			topxcfg_int,
			topxcfg_char,
			topxcfg_time,
			view
		) select
			topxcfg_type,
			topxcfg_int,
			topxcfg_char,
			topxcfg_time,
			"$dest_view" as view
		from
			tTopXCfg
		where
			view = ?
	}]

	set st [inf_prep_sql $DB $delete_sql]
	inf_exec_stmt $st $dest_view
	inf_close_stmt $st

	set st [inf_prep_sql $DB $sql]
	if {[catch {
		inf_exec_stmt $st $src_view
	} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR "Error copying TopX settings: $msg"
		error "Error copying settings"
	}

	# ---------------------------------
	# Weightings
	# ---------------------------------

	set delete_sql {
		delete from
			tTopXWeight
		where
			view = ?
	}

	set sql [subst {
		insert into tTopXWeight(
			ev_oc_id,
			weighting,
			view
		) select
			ev_oc_id,
			weighting,
			"$dest_view" as view
		from
			tTopXWeight
		where
			view = ?
	}]

	set st [inf_prep_sql $DB $delete_sql]
	inf_exec_stmt $st $dest_view
	inf_close_stmt $st

	set st [inf_prep_sql $DB $sql]
	if {[catch {
		inf_exec_stmt $st $src_view
	} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR "Error copying TopX weightings: $msg"
		error "Error copying weightings"
	}

	inf_close_stmt $st
	inf_commit_tran $DB

	go_topx
}

# Modify all settings
proc do_topx_mod args {
	global SPORTS

	#
	# Check if this is a request to copy settings
	#
	if {[reqGetArg settings] == "copy"} {
		return [do_topx_copy]
	}


	set view [get_current_view]


	# ---------------------------------
	# Sport Config
	# ---------------------------------

	set num_sports [bind_sports SPORTS $view]

	# These are the Ids of the sports to either set or clear for this view
	set set_list   [list]
	set clear_list [list]

	for {set i 0} {$i < $num_sports} {incr i} {
		set sport_id $SPORTS($i,id)
		set checked [reqGetArg "SP_$sport_id"]

		if {$checked == "" && $SPORTS($i,sport_view) != ""} {
			lappend clear_list $sport_id
		} elseif {$checked == Y && $SPORTS($i,sport_view) == ""} {
			lappend set_list $sport_id
		}
	}

	insert_sport_cfgs [reqGetArg view] $set_list
	delete_sport_cfgs [reqGetArg view] $clear_list

	catch {unset SPORTS}

	# ---------------------------------
	# Settings
	# ---------------------------------

	if {[reqGetArg BsTeaserStatus] == Y} {
		update_topx_setting BS_TEASER_STATUS    Y
	} else {
		update_topx_setting BS_TEASER_STATUS    N
	}

	set BsTeaserExpanded [ob_chk::get_arg BsTeaserExpanded -on_err N {EXACT -args {Y N}}]
	set BsTeaserBets [ob_chk::get_arg BsTeaserBets -on_err 3 UINT]
	set BsCanvasBets [ob_chk::get_arg BsCanvasBets -on_err 3 UINT]

	set MinStartTime [reqGetArg MinStartTime]
	if {$MinStartTime != ""} {
		set MinStartTime [ob_chk::get_arg MinStartTime -on_err "" INT]
	}

	set MaxEventEnd [reqGetArg MaxEventEnd]
	if {$MaxEventEnd != ""} {
		set MaxEventEnd [ob_chk::get_arg MaxEventEnd -on_err "" INT]
	}


	update_topx_setting BS_TEASER_EXPANDED  $BsTeaserExpanded
	update_topx_setting BS_TEASER_BETS      $BsTeaserBets
	update_topx_setting BS_CANVAS_BETS      $BsCanvasBets
	update_topx_setting MIN_START_TIME_MINS $MinStartTime
	update_topx_setting MAX_EVENT_END_HOURS $MaxEventEnd

	msg_bind "Successfully updated settings"

	go_topx
}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------


# Bind available Views into a given array
#
#   arr_name - Name of the array to populate
#
proc bind_views {arr_name} {
	global DB

	upvar $arr_name VIEWS

	set sql {
		select
			view,
			name
		from
			tViewType
		where
			status = 'A'
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set VIEWS($r,view) [db_get_col $rs $r view]
		set VIEWS($r,name) [db_get_col $rs $r name]
	}


	tpBindVar ViewValue $arr_name view view_idx
	tpBindVar ViewName  $arr_name name view_idx

	db_close $rs

	return $nrows
}

# Bind sports and if they are in the TopX query for the given view
#
#   arr_name - Name of the array to populate
#   view     - Code of the view to filter on
#
proc bind_sports {arr_name view} {
	global DB

	upvar $arr_name SPORTS

	set sql {
		select
			s.name,
			s.sport_id,
			c.view as sport_view
		from
			tSport s,
			outer tTopXViewSports c
		where
			c.sport_id = s.sport_id
			and view = ?
		order by
			s.name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $view]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set SPORTS($r,id)         [db_get_col $rs $r sport_id]
		set SPORTS($r,name)       [db_get_col $rs $r name]
		set SPORTS($r,sport_view) [db_get_col $rs $r sport_view]
	}


	tpBindVar SportId   $arr_name id sport_idx
	tpBindVar SportName $arr_name name sport_idx
	tpBindVar SportView $arr_name sport_view sport_idx

	db_close $rs

	return $nrows
}


# Bind sports and if they are in the TopX query for the given view
#
#   arr_name - Name of the array to populate
#   sort     - On which field to sort results (always desc)
#
proc bind_topx {arr_name {sort "total"}} {
	global DB

	upvar $arr_name TOPX

	set view [get_current_view]


	#
	# Get Date constraint config from DB
	#
	set cfg_sql [subst {
		select
			topxcfg_type,
			NVL(topxcfg_int, "") as topxcfg_int
		from
			tTopXCfg
		where
			   (topxcfg_type = 'MAX_EVENT_END_HOURS'
			or topxcfg_type = 'MIN_START_TIME_MINS')
			and view = ?
	}]

	set stmt [inf_prep_sql $DB $cfg_sql]
	set rs   [inf_exec_stmt $stmt $view]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set type  [db_get_col $rs $r topxcfg_type]
		set value [db_get_col $rs $r topxcfg_int]

		set cfg($type) $value
	}

	if {![info exists cfg(MIN_START_TIME_MINS)]} {
		set cfg(MIN_START_TIME_MINS) ""
	}

	if {![info exists cfg(MAX_EVENT_END_HOURS)]} {
		set cfg(MAX_EVENT_END_HOURS) ""
	}

	if {![info exists cfg(TOLERANCE_WIDE)]} {
		set cfg(TOLERANCE_WIDE) 50
	}

	if {![info exists cfg(TOLERANCE_NARROW)]} {
		set cfg(TOLERANCE_NARROW) 20
	}

	if {![info exists cfg(TOLERANCE_INIT)]} {
		set cfg(TOLERANCE_INIT) ""
	}

	if {![info exists cfg(POPULARITY_WIDE)]} {
		set cfg(POPULARITY_WIDE) 100
	}

	if {![info exists cfg(POPULARITY_NARROW)]} {
		set cfg(POPULARITY_NARROW) 50
	}

	if {![info exists cfg(POPULARITY_INIT)]} {
		set cfg(POPULARITY_INIT) 100
	}


	set min_start_time $cfg(MIN_START_TIME_MINS)
	set max_event_end  $cfg(MAX_EVENT_END_HOURS)
	db_close $rs

	#
	# Construct date constraint clauses
	#
	if {$min_start_time == ""} {
		set min_start_time 0
	}

	set current_date [clock seconds]
	set bottom_limit_date [clock scan "+$min_start_time minutes" -base $current_date]
	set bottom_limit_date [clock format $bottom_limit_date -format "%Y-%m-%d %H:%M:%S"]
	set min_start_time_clause "and e.start_time > '$bottom_limit_date'"

	set max_event_end_clause ""

	if {$max_event_end != ""} {
		set top_limit_date [clock scan "+$max_event_end hours" -base $current_date]
		set top_limit_date [clock format $top_limit_date -format "%Y-%m-%d %H:%M:%S"]
		set max_event_end_clause "and e.start_time < '$top_limit_date'"
	}


	set sql [subst {
		select
			first 20
			o.ev_oc_id as selection_id,
			o.desc as selection,
			x.count as spots,
			NVL(w.weighting,0) as weight,
			(x.count + NVL(w.weighting,0)) as total,
			e.desc as event,
			t.name as type,
			c.name as class,
			cat.name as category,
			m.name as market,
			m.ev_mkt_id as market_id
		from
			tTopXSeln x,
			outer tTopXWeight w,
			tEvOc o,
			tEv e,
			tEvUnStl u,
			tEvType t,
			tEvClass c,
			tEvCategory cat,
			tEvMkt m
		where
			    x.ev_oc_id = o.ev_oc_id
			and x.ev_oc_id = w.ev_oc_id
			and o.ev_id = e.ev_id
			and e.ev_id = u.ev_id
			and e.ev_type_id = t.ev_type_id
			and t.ev_class_id = c.ev_class_id
			and c.category = cat.category
			and o.ev_mkt_id = m.ev_mkt_id

			and (
				e.sport_id in (
					select
						sport_id
					from
						tTopXViewSports
					where
						view = ?
				)
				or e.sport_id = ''
				or e.sport_id is null
			)

			and w.view = ?
			$min_start_time_clause
			$max_event_end_clause
		order by
			$sort desc
	}]

	ob_log::write DEV $sql

	set view [get_current_view]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $view $view]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set TOPX($r,selection) [db_get_col $rs $r selection]
		set TOPX($r,oc_id)     [db_get_col $rs $r selection_id]
		set TOPX($r,spots)     [db_get_col $rs $r spots]
		set TOPX($r,weight)    [db_get_col $rs $r weight]
		set TOPX($r,total)     [db_get_col $rs $r total]
		set TOPX($r,event)     [db_get_col $rs $r event]
		set TOPX($r,type)      [db_get_col $rs $r type]
		set TOPX($r,class)     [db_get_col $rs $r class]
		set TOPX($r,category)  [db_get_col $rs $r category]
		set TOPX($r,market)    [db_get_col $rs $r market]
		set TOPX($r,market_id) [db_get_col $rs $r market_id]
	}


	tpBindVar TopxSelection $arr_name selection topx_idx
	tpBindVar TopxOcId      $arr_name oc_id     topx_idx
	tpBindVar TopxSpots     $arr_name spots     topx_idx
	tpBindVar TopxWeight    $arr_name weight    topx_idx
	tpBindVar TopxTotal     $arr_name total     topx_idx
	tpBindVar TopxEvent     $arr_name event     topx_idx
	tpBindVar TopxType      $arr_name type      topx_idx
	tpBindVar TopxClass     $arr_name class     topx_idx
	tpBindVar TopxCategory  $arr_name category  topx_idx
	tpBindVar TopxMarket    $arr_name market    topx_idx
	tpBindVar TopxMarketId  $arr_name market_id topx_idx

	db_close $rs

	return $nrows
}


# Create an array for the template player from a list of breadcrumb values
# List format is {{"Link Text 1" "Link Href 2"} {"Link Text 2" "Link Href 2"}}
proc bind_breadcrumbs {arr_name crumbs} {
	upvar $arr_name CRUMBS

	set nrows [llength $crumbs]
	for {set i 0} {$i < $nrows} {incr i} {
		set CRUMBS($i,href) [lindex [lindex $crumbs $i] 1]
		set CRUMBS($i,text) [lindex [lindex $crumbs $i] 0]
	}

	tpBindVar CrumbHref $arr_name href crumb_idx
	tpBindVar CrumbText $arr_name text crumb_idx

	return $nrows
}

# Bind selections with spots and weighting for a given market
proc bind_selections_for_market {arr_name id} {
	global DB
	upvar $arr_name SELN

	set sql {
		select
			o.desc as selection_name,
			o.ev_oc_id as selection_id,
			NVL(x.count,0) as seln_spots,
			NVL(w.weighting,0) as seln_weight
		from
			tEvOc o,
			outer tTopXSeln x,
			outer tTopXWeight w

		where
			    o.ev_mkt_id = ?
			and w.view      = ?
			and x.ev_oc_id  = o.ev_oc_id
			and w.ev_oc_id  = o.ev_oc_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $id [get_current_view]]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set SELN($r,id)     [db_get_col $rs $r selection_id]
		set SELN($r,name)   [db_get_col $rs $r selection_name]
		set SELN($r,spots)  [db_get_col $rs $r seln_spots]
		set SELN($r,weight) [db_get_col $rs $r seln_weight]
	}

	tpBindVar SelectionId     $arr_name id     seln_idx
	tpBindVar SelectionName   $arr_name name   seln_idx
	tpBindVar SelectionSpots  $arr_name spots  seln_idx
	tpBindVar SelectionWeight $arr_name weight seln_idx

	db_close $rs

	return $nrows
}

proc get_selection_by_id {id arr_name} {
	upvar $arr_name result

	set view [get_current_view]

	set sql [subst {
		select
			o.desc as selection_name,
			o.ev_oc_id as selection_id,
			NVL(x.count,0) as seln_spots,
			NVL(w.weighting,0) as seln_weight,
			m.name as market_name,
			m.ev_mkt_id as market_id,
			e.desc as event_name,
			e.ev_id as event_id,
			t.name as type_name,
			t.ev_type_id as type_id,
			c.name as class_name,
			c.ev_class_id as class_id,
			cat.name as category_name,
			cat.category as category_id
		from
			tEvOc o,
			outer tTopXSeln x,
			outer tTopXWeight w,
			tEvMkt m,
			tEv e,
			tEvType t,
			tEvClass c,
			tEvCategory cat
		where
			    o.ev_oc_id = ?
			and w.view = '$view'
			and x.ev_oc_id = o.ev_oc_id
			and w.ev_oc_id = o.ev_oc_id
			and o.ev_mkt_id = m.ev_mkt_id
			and o.ev_id = e.ev_id
			and e.ev_type_id = t.ev_type_id
			and t.ev_class_id = c.ev_class_id
			and c.category = cat.category
	}]

	return [sql_to_array $sql $id result]
}

# Helper function for get_*_by_id procs, takes the sql, id arg to pass
# to informix, and the array name to fill with results.  This only expects
# one row to be returned.
proc sql_to_array {sql id arr_name} {
	global DB
	upvar $arr_name result

	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	foreach c [db_get_colnames $rs] {
		set result($c) [db_get_col $rs 0 $c]
	}

	db_close $rs
	return $nrows
}


proc get_market_by_id {id arr_name} {
	upvar $arr_name result

	set sql {
		select
			m.ev_mkt_id as market_id,
			m.name as market_name,
			e.desc as event_name,
			e.ev_id as event_id,
			t.name as type_name,
			t.ev_type_id as type_id,
			c.name as class_name,
			c.ev_class_id as class_id,
			cat.name as category_name,
			cat.category as category_id
		from
			tEvMkt m,
			tEv e,
			tEvType t,
			tEvClass c,
			tEvCategory cat
		where
			    m.ev_mkt_id = ?
			and m.ev_id = e.ev_id
			and e.ev_type_id = t.ev_type_id
			and t.ev_class_id = c.ev_class_id
			and c.category = cat.category
	}

	return [sql_to_array $sql $id result]
}

#
# Get details for an event
#   event_id - The id of the event to query
#   arr_name - The name of the array to store the data
#
#   returns: 1 if successful, 0 on error (usually no record found)
#
proc get_event_by_id {event_id arr_name} {
	global DB
	set sql {
		select
			e.desc as event_name,
			e.ev_id as event_id,
			t.name as type_name,
			t.ev_type_id as type_id,
			c.name as class_name,
			c.ev_class_id as class_id,
			cat.name as category_name,
			cat.category as category_id
		from
			tEv e,
			tEvType t,
			tEvClass c,
			tEvCategory cat
		where
			    e.ev_id = ?
			and e.ev_type_id = t.ev_type_id
			and t.ev_class_id = c.ev_class_id
			and c.category = cat.category
	}


	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $event_id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	upvar $arr_name event

	set event(event_name) [db_get_col $rs 0 event_name]
	set event(event_id)   [db_get_col $rs 0 event_id]
	set event(type_name)  [db_get_col $rs 0 type_name]
	set event(type_id)    [db_get_col $rs 0 type_id]
	set event(class_name) [db_get_col $rs 0 class_name]
	set event(class_id)   [db_get_col $rs 0 class_id]
	set event(category_name)   [db_get_col $rs 0 category_name]
	set event(category_id)     [db_get_col $rs 0 category_id]

	db_close $rs
	return 1
}

proc get_type_by_id {id arr_name} {
	global DB
	set sql {
		select
			t.name as type_name,
			t.ev_type_id as type_id,
			c.name as class_name,
			c.ev_class_id as class_id,
			cat.name as category_name,
			cat.category as category_id
		from
			tEvType t,
			tEvClass c,
			tEvCategory cat
		where
			    t.ev_type_id = ?
			and t.ev_class_id = c.ev_class_id
			and c.category = cat.category
	}


	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	upvar $arr_name event

	set event(type_name)  [db_get_col $rs 0 type_name]
	set event(type_id)    [db_get_col $rs 0 type_id]
	set event(class_name) [db_get_col $rs 0 class_name]
	set event(class_id)   [db_get_col $rs 0 class_id]
	set event(category_name)   [db_get_col $rs 0 category_name]
	set event(category_id)     [db_get_col $rs 0 category_id]

	db_close $rs
	return 1
}

proc get_class_by_id {id arr_name} {
	global DB
	set sql {
		select
			c.name as class_name,
			c.ev_class_id as class_id,
			cat.name as category_name,
			cat.category as category_id
		from
			tEvClass c,
			tEvCategory cat
		where
			    c.ev_class_id = ?
			and c.category = cat.category
	}


	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	upvar $arr_name event

	set event(class_name) [db_get_col $rs 0 class_name]
	set event(class_id)   [db_get_col $rs 0 class_id]
	set event(category_name)   [db_get_col $rs 0 category_name]
	set event(category_id)     [db_get_col $rs 0 category_id]

	db_close $rs
	return 1
}

proc get_category_by_id {id arr_name} {
	global DB
	set sql {
		select
			cat.name as category_name,
			cat.category as category_id
		from
			tEvCategory cat
		where
			cat.category = ?
	}


	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $id]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	upvar $arr_name event

	set event(category_name)   [db_get_col $rs 0 category_name]
	set event(category_id)     [db_get_col $rs 0 category_id]

	db_close $rs
	return 1
}

# Insert a row for each sport in the id_list for view
proc insert_sport_cfgs {view id_list} {
	if {[llength $id_list] == 0} return

	global DB

	set update_sql {
		insert into tTopXViewSports(
			view,
			sport_id
		) values (?, ?)
	}

	inf_begin_tran $DB
	set st [inf_prep_sql $DB $update_sql]
	foreach id $id_list {
		if {[catch {
			inf_exec_stmt $st $view $id
		} msg]} {
			inf_rollback_tran $DB
			ob_log::write ERROR "ERROR inserting value for sport $id: $msg"
			err_bind "Error inserting value for sport $id: $msg"
			inf_close_stmt $st
			exit
		}
	}
	inf_commit_tran $DB
	inf_close_stmt $st
}

# Delete all the sport associations in id_list for view
proc delete_sport_cfgs {view id_list} {
	if {[llength $id_list] == 0} return

	global DB

	set id_list [join $id_list ,]

	set delete_sql [subst {
		delete from
			tTopXViewSports
		where
			view = ? and
			sport_id in ($id_list)
	}]

	set st [inf_prep_sql $DB $delete_sql]
	inf_exec_stmt $st $view
	inf_close_stmt $st
}


# Update a TopX setting in the DB
proc update_topx_setting {name value} {
	global DB
	variable CFG_TYPE

	if {$value == "" && $name != "MIN_START_TIME_MINS"
	&& $name != "MAX_EVENT_END_HOURS"} {
		ob_log::write ERROR "Updating setting for topx bets but got blank value for $name"
		err_bind "Cannot use a  blank value for $name"
		return
	}
	set type $CFG_TYPE($name)

	set delete_sql {
		delete from
			tTopXCfg
		where
			topxcfg_type = ?
			and view = ?
	}

	set sql [subst {
		insert into tTopXCfg (
			topxcfg_type,
			topxcfg_$type,
			view
		) values (?, ?, ?)
	}]

	set st [inf_prep_sql $DB $delete_sql]
	inf_exec_stmt $st $name [get_current_view]
	inf_close_stmt $st

	inf_begin_tran $DB
	set st [inf_prep_sql $DB $sql]
	if {[catch {
		inf_exec_stmt $st $name $value [get_current_view]
	} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR "Error updating TopX setting $name: $msg"
		err_bind "Error updating TopX setting"
	} else {
		inf_commit_tran $DB
	}
	inf_close_stmt $st
}

# Find out what the current view is
proc get_current_view {} {
	set req_view [reqGetArg view]
	if {$req_view == ""} {
		return "gb"
	}

	return $req_view
}

proc bind_settings {} {
	global DB
	variable CFG_TYPE

	set sql {
		select
			*
		from
			tTopXCfg
		where
			view = ?
	}

	set view [get_current_view]

	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $view]
	inf_close_stmt $st

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set name [db_get_col $rs $i topxcfg_type]
		if {[info exists CFG_TYPE($name)]} {
			set data_type $CFG_TYPE($name)
			tpBindString $name [db_get_col $rs $i topxcfg_$data_type]
		}
	}

	db_close $rs

	set allowed_views [OT_CfgGet DISPLAY_ST_CFG_VIEWS "gb"]

	if {[lsearch -exact $allowed_views $view] != -1 } {
		tpSetVar show_search_tolerance 1
	}

	return $nrows
}

# -----------------------------------------------------------------------------
# Functions for filling hierarchy select menu
# -----------------------------------------------------------------------------

proc fill_category_menu {arr_name} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			name,
			category
		from
			tEvCategory
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&category=[db_get_col $rs $r category]"
		set MENU($r,text) [db_get_col $rs $r name]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs
}

proc fill_class_menu {arr_name category} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			name,
			ev_class_id
		from
			tEvClass
		where
			category = ?
			and status = "A"
		order by
			name

	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $category]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&class=[db_get_col $rs $r ev_class_id]"
		set MENU($r,text) [db_get_col $rs $r name]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs
}

proc fill_selection_menu {arr_name market} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			desc,
			ev_oc_id
		from
			tEvOc
		where
			ev_mkt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $market]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&selection=[db_get_col $rs $r ev_oc_id]"
		set MENU($r,text) [db_get_col $rs $r desc]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs
}

proc fill_market_menu {arr_name event} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			name,
			ev_mkt_id
		from
			tEvMkt
		where
			ev_id = ?
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $event]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&market=[db_get_col $rs $r ev_mkt_id]&Event=$event"
		set MENU($r,text) [db_get_col $rs $r name]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs

}

proc fill_event_menu {arr_name type} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			desc,
			ev_id
		from
			tEv
		where
			    ev_type_id = ?
			and start_time > current - 24 units hour
			and settled = "N"
		order by
			desc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $type]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&event=[db_get_col $rs $r ev_id]"
		set MENU($r,text) [db_get_col $rs $r desc]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs
}

proc fill_type_menu {arr_name class} {
	global DB
	upvar $arr_name MENU

	set sql {
		select
			name,
			ev_type_id
		from
			tEvType
		where
			ev_class_id = ?
			and status = "A"
		order by
			name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $class]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set MENU($r,href) "?action=ADMIN::TOPX::Select&type=[db_get_col $rs $r ev_type_id]"
		set MENU($r,text) [db_get_col $rs $r name]
	}


	tpBindVar MenuHref MENU href menu_idx
	tpBindVar MenuText MENU text menu_idx

	tpSetVar NumMenu $nrows

	db_close $rs
}

}

