# ==============================================================
# $Id: popup_dd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Copyright (c) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::POPUP_DD {

	asSetAct ADMIN::POPUP_DD::GoDD      [namespace code go_dd]

	variable DFLT_LEVEL_INFO


	set DFLT_LEVEL_INFO(TOP,name) {Top}
	set DFLT_LEVEL_INFO(TOP,plural) {}
	set DFLT_LEVEL_INFO(TOP,sql_name) {}
	set DFLT_LEVEL_INFO(TOP,sql_parent) {}
	set DFLT_LEVEL_INFO(TOP,sql_children) {
		select
			'CLASS'        as level,
			c.ev_class_id  as id,
			c.name         as name
		from
			tEvClass c
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(ROOT,name) {Root}
	set DFLT_LEVEL_INFO(ROOT,plural) {}
	set DFLT_LEVEL_INFO(ROOT,sql_name) {}
	set DFLT_LEVEL_INFO(ROOT,sql_parent) {}
	set DFLT_LEVEL_INFO(ROOT,sql_children) {
		select
			'CATEGORY'        as level,
			c.ev_category_id  as id,
			c.name         as name
		from
			tEvCategory c
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(CATEGORY,name)   {Category}
	set DFLT_LEVEL_INFO(CATEGORY,plural) {Categories}
	set DFLT_LEVEL_INFO(CATEGORY,sql_name) {
		select
			c.name
		from
			tEvCategory c
		where
			c.ev_category_id = ?
	}

	set DFLT_LEVEL_INFO(CATEGORY,sql_parent) {}
	set DFLT_LEVEL_INFO(CATEGORY,sql_children) {
		select
			'CLASS'       as level,
			c.ev_class_id as id,
			c.name       as name
		from
			tEvClass c,
			tEvCategory y
		where
			y.category = c.category and
			y.ev_category_id  = ?
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(CLASS,name)   {Event Class}
	set DFLT_LEVEL_INFO(CLASS,plural) {Event Classes}
	set DFLT_LEVEL_INFO(CLASS,sql_name) {
		select
			c.name
		from
			tEvClass c
		where
			c.ev_class_id = ?
	}
	set DFLT_LEVEL_INFO(CLASS,sql_parent) {}
	set DFLT_LEVEL_INFO(CLASS,sql_children) {
		select
			'TYPE'       as level,
			t.ev_type_id as id,
			t.name       as name
		from
			tEvType t
		where
			t.ev_class_id = ?
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(TYPE,name)   {Event Type}
	set DFLT_LEVEL_INFO(TYPE,plural) {Event Types}
	set DFLT_LEVEL_INFO(TYPE,sql_name) {
		select
			t.name
		from
			tEvType t
		where
			t.ev_type_id = ?
	}
	set DFLT_LEVEL_INFO(TYPE,sql_parent) {
		select
			'CLASS'        as level,
			c.ev_class_id  as id,
			c.name         as name
		from
			tEvType  t,
			tEvClass c
		where
				t.ev_type_id  = ?
			and t.ev_class_id = c.ev_class_id
	}
	set DFLT_LEVEL_INFO(TYPE,sql_children) {
		select
			'EVENT'     as level,
			e.ev_id     as id,
			e.desc      as name,
			e.start_time as date
		from
			tEv e,
			tEvUnstl eu
		where
			    eu.ev_type_id  = ?
			and eu.ev_id       = e.ev_id
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(EVENT,name)   {Event}
	set DFLT_LEVEL_INFO(EVENT,plural) {Events}
	set DFLT_LEVEL_INFO(EVENT,sql_name) {
		select
			e.desc as name,
			e.start_time as date
		from
			tEv e
		where
				ev_id = ?
	}
	set DFLT_LEVEL_INFO(EVENT,sql_parent) {
		select
			'TYPE'        as level,
			t.ev_type_id  as id,
			t.name        as name
		from
			tEv      e,
			tEvType  t
		where
				e.ev_id      = ?
			and e.ev_type_id = t.ev_type_id
	}
	set DFLT_LEVEL_INFO(EVENT,sql_children) {
		select
			'MARKET'     as level,
			m.ev_mkt_id  as id,
			g.name
		from
			tEvMkt   m,
			tEvOcGrp g
		where
				m.ev_id        = ?
			and m.ev_oc_grp_id = g.ev_oc_grp_id
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(MARKET,name)   {Market}
	set DFLT_LEVEL_INFO(MARKET,plural) {Markets}
	set DFLT_LEVEL_INFO(MARKET,sql_name) {
		select
			g.name
		from
			tEvMkt   m,
			tEvOcGrp g
		where
				m.ev_mkt_id    = ?
			and m.ev_oc_grp_id = g.ev_oc_grp_id
	}
	set DFLT_LEVEL_INFO(MARKET,sql_parent) {
		select
			'EVENT'      as level,
			e.ev_id      as id,
			e.desc       as name,
			e.start_time as date
		from
			tEvMkt  m,
			tEv     e
		where
				m.ev_mkt_id  = ?
			and m.ev_id      = e.ev_id
	}
	set DFLT_LEVEL_INFO(MARKET,sql_children) {
		select
			'SELN'       as level,
			oc.ev_oc_id  as id,
			oc.desc      as name
		from
			tEvOc oc
		where
			oc.ev_mkt_id = ?
		order by
			1, 3
	}

	set DFLT_LEVEL_INFO(SELN,name)   {Selection}
	set DFLT_LEVEL_INFO(SELN,plural) {Selections}
	set DFLT_LEVEL_INFO(SELN,sql_name) {
		select
			oc.desc as name
		from
			tEvOc oc
		where
			oc.ev_oc_id = ?
	}
	set DFLT_LEVEL_INFO(SELN,sql_parent) {
		select
			'MARKET'     as level,
			m.ev_mkt_id  as id,
			g.desc       as name
		from
			tEvOc    oc,
			tEvMkt   m,
			tEvOcGrp g
		where
				oc.ev_oc_id    = ?
			and oc.ev_mkt_id   = m.ev_mkt_id
			and m.ev_oc_grp_id = g.ev_oc_grp_id
	}
	set DFLT_LEVEL_INFO(SELN,sql_children) {}

	variable OVER_LEVEL_INFO
	variable LEVEL_INFO
}



##
#
# Find the parent of an event hierarchy object.
# Returns list of form [list level id name].
# The top of the event hierarchy is represented as [list TOP 0 Top]
#
##
proc ADMIN::POPUP_DD::_get_parent {level id} {

	global DB
	variable LEVEL_INFO
	variable TOP_LEVEL

	set sql $LEVEL_INFO($level,sql_parent)
	if {![string length $sql]} {
		return [list $TOP_LEVEL 0 $TOP_LEVEL]
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $id]
	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		error "Unable to find parent of $level #$id"
	}

	set plevel [db_get_col $rs level]
	set pid    [db_get_col $rs id]
	set pname  [db_get_col $rs name]

	db_close $rs

	return [list $plevel $pid $pname]
}



##
#
# Find the name of an event hierarchy object.
# The top of the hierarchy is called 'Top'.
#
##
proc ADMIN::POPUP_DD::_get_name {level id} {

	global DB
	variable LEVEL_INFO
	variable TOP_LEVEL

	if {$level == $TOP_LEVEL} {
		return $LEVEL_INFO($level,name)
	}

	set sql $LEVEL_INFO($level,sql_name)

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $id]
	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		error "Unable to find name of $level #$id"
	}

	set name  [db_get_col $rs name]

	db_close $rs

	return $name
}



##
#
# Obtain a result set containing the levels, ids and names of the
# children of an event hierarchy object. May be empty.
#
# Will be sorted by level first.
#
# Caller should close the result set when done with it.
#
##
proc ADMIN::POPUP_DD::_get_children_rs {level id} {

	global DB
	variable LEVEL_INFO

	set sql $LEVEL_INFO($level,sql_children)

	if {![string length $sql]} {
		return [db_create [list level id name]]
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $id $id $id $id]
	return $rs
}



##
#
# Given an Event Hierarchy path (a list of the form {level id level id ...}),
# add additional elements to the head of the path until the top of the event
# hierarchy is reached, and return the resulting path.
#
# e.g. [_full_path {EVENT 123 MARKET 99}] gives
#      {TOP 0 CLASS 49 TYPE 66 EVENT 123 MARKET 99}
#
##
proc ADMIN::POPUP_DD::_full_path {path} {

	variable TOP_LEVEL

	if {![llength $path]} {
		return [list $TOP_LEVEL 0]
	}

	while {[lindex $path 0] != $TOP_LEVEL} {
		set level [lindex $path 0]
		set id    [lindex $path 1]
		foreach {plevel pid junk} [_get_parent $level $id] {}
		set path [linsert $path 0 $plevel $pid]
	}

	return $path
}


##
#
# Action handler for POPUP_DD::GoDD.
#
# This action allows the user to select an object from the Event Hierarchy.
#
# When the user selects an object, the Javascript function set_vals will be
# called in the opener of the popup window with arguments level, id and name.
#
# The levels available are (from highest to lowest) are
# CATEGORY (only if selected_level is ROOT), CLASS, TYPE, EVENT, MARKET and SELN.
#
# Request Arguments:
#
#   selected_level, selected_id
#     Optional level and id of an object to pre-select. Provided no path
#     argument is supplied, the popup will show this object and its siblings.
#
#   selectable_levels
#     A comma separated list of those levels that may be selected,
#     or "" to allow selection of any level.
#
#   blurb
#     Optional instructive text to show the user.
#
#   path (intended for internal use)
#     A comma separated list of levels and ids describing the object whose
#     children will be shown, and optionally the ancestors of the object.
#     e.g. CLASS,49,TYPE,244
#
# Note that this procedure is optimised for clarity and extensibility, not
# performance. It's intended to be able to cope with children of different
# types appearing together - e.g. TYPES and COUPONS.
#
# Procedure parameters:
#
#   overrideArray
#     The name of an array in the callers context containing elements which
#     are to override those in DFLT_LEVEL_INFO.
#
#   pass_thru
#     List of request arguments to pass through to subsequent requests.
#
##
proc ADMIN::POPUP_DD::go_dd { {overrideArray ""} {pass_thru ""}} {

	variable LEVEL_INFO
	variable DFLT_LEVEL_INFO

	variable TOP_LEVEL

	# XXX This is a bit inefficient - it would be nice to use traces
	# or another technique to avoid array copying.
	catch {unset LEVEL_INFO}
	array set LEVEL_INFO [array get DFLT_LEVEL_INFO]
	if {$overrideArray != ""} {
		upvar 1 $overrideArray CALLER_LEVEL_INFO
		array set LEVEL_INFO [array get CALLER_LEVEL_INFO]
	}

	global ANCESTORS
	global CHILDREN
	global PASS_THRU

	catch {unset ANCESTORS}
	catch {unset CHILDREN}
	catch {unset PASS_THRU}

	# Get request arguments
	set path              [split [reqGetArg path] ,]
	set selected_level    [reqGetArg selected_level]
	set selected_id       [reqGetArg selected_id]
	set selectable_levels [split [reqGetArg selectable_levels] ,]
	set blurb             [reqGetArg blurb]
	set select_option     [reqGetArg select_option]
	set close_on_select   [reqGetArg close_on_select]
	set show_date         [reqGetArg show_date]

	set disable_links_at_level [reqGetArg disable_links_at_level]

	set TOP_LEVEL "TOP"

	if {$selected_level == "ROOT"} {
		set TOP_LEVEL "ROOT"
	}

	if {$close_on_select == ""} {set close_on_select 0}

	if {[catch {set disable_dd_evs    [split [reqGetArg disable_dd_evs] |]}]} {
		set disable_dd_evs ""
	}

	# If we have not been given a path, but we have been given
	# a selected object, set the path to the parent of that object.
	if {![string length $path] && [string length $selected_level]} {
		foreach {parent_level parent_id junk} \
			[_get_parent $selected_level $selected_id] {}
		set path [list $parent_level $parent_id]
	}

	# Expand the path up to the top of the hierarchy
	set path [_full_path $path]

	# Look up details of the objects in the path (our ancestors)
	set anc_idx 0
	for {set i 0} {$i < [llength $path]} {incr i 2} {
		set level [lindex $path $i]
		set id    [lindex $path [expr {$i+1}]]
		set ANCESTORS($anc_idx,level_name) $LEVEL_INFO($level,name)
		set ANCESTORS($anc_idx,name)  \
			[string map {"|" ""} [_get_name $level $id]]
		set ANCESTORS($anc_idx,path)  \
			[join [lrange $path 0 [expr {$i+1}]] ,]
		incr anc_idx
	}

	# Bind up objects in the path
	tpSetVar  NumAncestors $anc_idx
	tpBindVar ANCLevelName ANCESTORS  level_name anc_idx
	tpBindVar ANCName      ANCESTORS  name       anc_idx
	tpBindVar ANCPath      ANCESTORS  path       anc_idx

	# Find the children of the last item in the path
	set rs [_get_children_rs [lindex $path end-1] [lindex $path end]]

	set child_idx 0
	set last_level "NONE"
	set has_selectable 0
	set has_clickable  0
	set child_level_names [list]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {

		set level [db_get_col $rs $i level]
		set id    [db_get_col $rs $i id]

		set CHILDREN($child_idx,level) $level
		set CHILDREN($child_idx,id)    $id

		set CHILDREN($child_idx,name)  \
			[escape_html [string map {"|" ""} [db_get_col $rs $i name]]]

		if {$level == "EVENT" && $show_date == 1} {
			set timestamp [clock scan [db_get_col $rs $i date]]
			set date [clock format $timestamp -format "%D"]
		} else {
			set date ""
		}
		append CHILDREN($child_idx,name) " $date"

		if {$level == "EVENT" && [lsearch $disable_dd_evs $id] != -1} {
            set CHILDREN($child_idx,can_click)  0
            set CHILDREN($child_idx,can_select) 0
		} else {

			set CHILDREN($child_idx,can_select) \
				[expr {   $selectable_levels == "" \
					|| [lsearch $selectable_levels $level] != -1}]

			# If coming from the Sports page, do not allow drill down beyond category level
			# ie , class name will not be clickable
			if { ($disable_links_at_level != "") && ($disable_links_at_level == $level)} {
				set CHILDREN($child_idx,can_click) 0
			} else {
				set CHILDREN($child_idx,can_click) \
					[string length $LEVEL_INFO($level,sql_children)]
			}
		}

		set CHILDREN($child_idx,selected) \
			[expr {   $CHILDREN($child_idx,can_select) \
			       && [string equal $level $selected_level] \
			       && [string equal $id    $selected_id] }]

		# We only populate this if it changes
		if {![string equal $level $last_level]} {
			set CHILDREN($child_idx,new_level_str) $LEVEL_INFO($level,plural)
			lappend child_level_names $LEVEL_INFO($level,name)
			set last_level $level
		} else {
			set CHILDREN($child_idx,new_level_str) ""
		}

		set has_selectable \
			[expr {$has_selectable || $CHILDREN($child_idx,can_select)}]

		set has_clickable \
			[expr {$has_clickable  || $CHILDREN($child_idx,can_click)}]

		incr child_idx
	}

	# Bind up the children
	tpSetVar     NumChildren       $child_idx
	tpSetVar     HasSelectable     $has_selectable
	tpSetVar     HasClickable      $has_clickable
	tpBindVar    ChildLevel        CHILDREN  level          child_idx
	tpBindVar    ChildId           CHILDREN  id             child_idx
	tpBindVar    ChildName         CHILDREN  name           child_idx
	tpBindVar    ChildSelected     CHILDREN  selected       child_idx
	tpBindVar    ChildCanSelect    CHILDREN  can_select     child_idx
	tpBindVar    ChildCanClick     CHILDREN  can_click      child_idx
	tpBindVar    ChildNewLevelStr  CHILDREN  new_level_str  child_idx
	tpBindVar    ChildDate         CHILDREN  date           child_idx

	# Let's get the indefinite article right
	set child_level_names [join $child_level_names " or "]
	if {[string match -nocase {[aeiou]*} $child_level_names]} {
		set child_level_article "an"
	} else {
		set child_level_article "a"
	}
	tpBindString ChildLevelNames   [escape_javascript $child_level_names]
	tpBindString ChildLevelArticle $child_level_article

	# Bind up information we need to pass through to any subsequent requests
	tpBindString SelectOption     $select_option
	tpBindString SelectedLevel    $selected_level
	tpBindString SelectedId       $selected_id
	tpBindString SelectableLevels [join $selectable_levels ,]
	tpBindString Blurb            [escape_html $blurb]
	tpBindString disableLinksAtLevel $disable_links_at_level
	tpBindString CloseOnSelect    $close_on_select
	tpBindString ShowDate         $show_date

	set pass_idx 0
	foreach arg $pass_thru {
		set PASS_THRU($pass_idx,name)  $arg
		set PASS_THRU($pass_idx,value) [escape_html [reqGetArg -unsafe $arg]]
		incr pass_idx
	}
	tpSetVar  NumPassThru $pass_idx
	tpBindVar PassName    PASS_THRU name   pass_idx
	tpBindVar PassValue   PASS_THRU value  pass_idx

	asPlayFile -nocache popup_dd.html

	catch {unset ANCESTORS}
	catch {unset CHILDREN}
}
