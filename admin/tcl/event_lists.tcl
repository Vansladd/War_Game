# ==============================================================
# $Id: event_lists.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Event Lists management
# the Next Events section of the sportsbook
#
# This is used to control how the markets / events are displayed in the
# Sportsbook, depending on the view choosen.
#
# TODO : factorise regexp
# TODO : validation handling. Some regexp blank erroneous matching, causing
#        errors when doing things because we have the blank string as an input
#        When input is not correct, the error handling is not very user friendly

namespace eval ADMIN::EVENTLISTS {

asSetAct ADMIN::EVENTLISTS::GoEventLists [namespace code go_event_lists]
asSetAct ADMIN::EVENTLISTS::DoEventLists [namespace code do_event_lists]

#==============================================================================
#
# go_event_lists  : display the event_list editing interface
#
proc ::ADMIN::EVENTLISTS::go_event_lists { {filter_view ""} \
										   {filter_sport -1}  \
										   {order_by "disporder"} } {

	global DB

	if {$filter_view == ""} {
		set filter_view [ob_control::get default_view]

		# just in case we don't have a default_view set in tcontrol.
		if {$filter_view == ""} {
			set rs [inf_exec_stmt [inf_prep_sql $DB {select first 1 view from tviewtype}]]
			set filter_view [db_get_coln $rs 0 0]
			db_close $rs
		}
	}

	ob_log::write DEBUG \
			{::ADMIN::EVENTLISTS::go_event_lists $filter_view $filter_sport}

	set selected_sport [list]

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $filter_sport]

	# Bind the sport view configuration
	_bind_sportview_config $filter_view [lindex $selected_sport 0]

	# Bind view filter dropdown
	_bind_view_dropdown

	# Bind Event List for this sport and view
	_bind_event_list_for_sport $filter_view \
							   [lindex $selected_sport 0] \
							   [lindex $selected_sport 1] \
							   $order_by

	tpBindString SelectedView $filter_view

	asPlayFile event_lists_main.html
}



#==============================================================================
#
# do_event_lists : handling form submission actions
#
proc ::ADMIN::EVENTLISTS::do_event_lists args {

	# Arguments validation
	set action \
	  [ob_chk::get_arg SubmitName -on_err "en" {RE -args {^[A-Za-z]+$}}]
	set view_filter [ob_chk::get_arg view_filter -on_err "" {ALNUM}]
	set sport_filter \
	  [ob_chk::get_arg sport_filter -on_err "" {RE -args {^[0-9]+$}}]
	set sort \
	  [ob_chk::get_arg sort -on_err "disporder" {RE -args {^[a-zA-Z_]+$}}]

	ob_log::write DEBUG \
		{::ADMIN::EVENTLISTS::do_event_lists $action $view_filter $sport_filter $sort}

	set to_update_list [list]
	set to_delete_list [list]

	# Work out what we have to do
	switch -exact $action {

		"SortList"    -
		"FilterSport" -
		"FilterView"  -
		"Cancel" {
			# We are updating the filters, or cancelling, so just redirect
			::ADMIN::EVENTLISTS::go_event_lists $view_filter $sport_filter $sort
		}

		"SaveChanges" {
			# Get the flags to denote what has been changed
			set view_changed \
				[ob_chk::get_arg view_changed -on_err "0" {RE -args {^[0|1]$}}]
			set sport_changed \
				[ob_chk::get_arg sport_changed -on_err "0" {RE -args {^[0|1]$}}]

			# The list of id to be updated
			set to_update_list [ob_chk::get_arg ev_id_update \
			  -on_err "" {RE -args {^[[0-9 ]+$}}]
			set to_delete_list [ob_chk::get_arg ev_id_delete \
			  -on_err "" {RE -args {^[[0-9 ]+$}}]
			# This is in the form [[ev_id|disporder] ]*
			set to_add_list    [ob_chk::get_arg ev_id_add \
			  -on_err "" {RE -args {^[[0-9| -]+$}}]

			# Do the update
			::ADMIN::EVENTLISTS::_do_update $view_filter \
											$sport_filter \
											$view_changed \
											$sport_changed \
											$to_update_list \
											$to_delete_list \
											$to_add_list

			# Go to the previous list
			::ADMIN::EVENTLISTS::go_event_lists $view_filter $sport_filter
		}

		default {
			# We don't want to go here
			error {::ADMIN::EVENTLISTS::do_event_lists - Unknown action}
		}
	}


}



#==============================================================================
#
#_do_update
# Perform the update. What is being updated depends on what is coming
# from the form. As we have a generic "Save Changes" button, we will do this
# in a transaction to ensure that everything is committed or discarded as a
# whole
#
proc ::ADMIN::EVENTLISTS::_do_update { view_filter \
									   {sport_filter -1} \
									   {view_changed 0} \
									   {sport_changed 0} \
									   {to_update {}} \
									   {to_delete {}} \
									   {to_add {}}} {

	global DB

	# Initialize variables
	set max_other_events  {}
	set max_my_events     {}
	set max_sport_ev      {}
	set max_home_bir_ev   {}

	# Initialize the 'commit' flag to false
	set do_update 0

	# Initialize the upds of maximum events to false
	set do_upd_other_events 0
	set do_upd_my_events 0
	set do_upd_bir_threshold_num 0
	set do_upd_bir_threshold_den 0

	# Do we have to update tViewConfig ?
	if {$view_changed} {

		# Qry to update max_other_event if it has changed
		set view_upd [inf_prep_sql $DB {
			update
				tViewConfig
			set
				value = ?
			where
				view   = ? and
				name   = 'max_other_events'
		}]

		# Qry to update max_my_events if it has changed
		set view_upd_my_ev [inf_prep_sql $DB {
			update
				tViewConfig
			set
				value = ?
			where
				view   = ? and
				name   = 'max_my_events'
		}]

		# Qry to update the bir threshold num if it has changed
		set view_upd_bir_threshold_num [inf_prep_sql $DB {
			update
				tViewConfig
			set
				value = ?
			where
				view   = ? and
				name   = 'bir_threshold_num'
		}]

		# Qry to update the bir threshold den if it has changed
		set view_upd_bir_threshold_den [inf_prep_sql $DB {
			update
				tViewConfig
			set
				value = ?
			where
				view   = ? and
				name   = 'bir_threshold_den'
		}]

		# Parameter Validation
		set max_other_events \
			[ob_chk::get_arg max_other_events -on_err "10" {RE -args {^[[0-9]+$}}]

		set orig_max_other_events \
			[ob_chk::get_arg orig_max_other_events -on_err "" {RE -args {^[[0-9]+$}}]
		
		set max_my_events \
			[ob_chk::get_arg max_my_events -on_err "" {RE -args {^[[0-9]+$}}]

		set orig_max_my_events \
			[ob_chk::get_arg orig_max_my_events -on_err "" {RE -args {^[[0-9]+$}}]

		set bir_threshold_num \
			[ob_chk::get_arg bir_threshold_num -on_err "" {RE -args {^[[0-9]+$}}]

		set orig_bir_threshold_num \
			[ob_chk::get_arg orig_bir_threshold_num -on_err "" {RE -args {^[[0-9]+$}}]

		set bir_threshold_den \
			[ob_chk::get_arg bir_threshold_den -on_err "" {RE -args {^[[0-9]+$}}]

		set orig_bir_threshold_den \
			[ob_chk::get_arg orig_bir_threshold_den -on_err "" {RE -args {^[[0-9]+$}}]

		# If there is an error with the parameters, we don't do an upd
		if {($max_other_events != "") && ($max_other_events != $orig_max_other_events)} {
			set do_upd_other_events 1
			set do_update 1
		}

		if {($max_my_events != "") && ($max_my_events != $orig_max_my_events)} {
			set do_upd_my_events 1
			set do_update 1
		}

		if {($bir_threshold_num != "") && ($bir_threshold_num != $orig_bir_threshold_num)} {
			set do_upd_bir_threshold_num 1
			set do_update 1
		}

		if {($bir_threshold_den != "") && ($bir_threshold_den != $orig_bir_threshold_den)} {
			set do_upd_bir_threshold_den 1
			set do_update 1
		}

	}

	# Do we have to update tSportDispCfg ?
	if {$sport_changed} {

		set sport_upd [inf_prep_sql $DB {
			update
				tSportDispCfg
			set
				max_sport_ev    = ?,
				max_home_bir_ev = ?
			where
				sport_id = ? and
				view     = ?
		}]

		# Parameter Validation
		set max_sport_ev \
			[ob_chk::get_arg max_sport_other_events \
			  -on_err "5" {RE -args {^[[0-9]+$}}]

		set max_home_bir_ev \
			[ob_chk::get_arg max_sport_hpage_events \
			  -on_err "5" {RE -args {^[[0-9]+$}}]

		set do_update 1
	}

	# Do we have to update events ?
	if { $to_update != "" || $to_delete != "" || $to_add != ""} {

		set event_upd [inf_prep_sql $DB {
			update
				tView
			set
				disporder = ?
			where
				view = ? and
				sort = 'EVENT' and
				id = ?
		}]

		set event_del [inf_prep_sql $DB {
			delete from
				tview
			where
				id = ? and
				sort = 'EVENT' and
				view = ?
		}]

		set event_check [inf_prep_sql $DB {
			select
				1
			from
				tEv
			where
				ev_id = ? and
				sport_id = ?
		}]

		set event_add [inf_prep_sql $DB {
			insert into
				tView (view, sort, id, disporder)
			values
				(?, 'EVENT', ?, ?)
		}]

		set do_update 1

	}

	# If we called this function, we should have something to update so at
	# this point we should always pass this test ... but just in case :)
	if { $do_update } {

		# Do we have to add anything?
		if { $to_add != ""} {
			foreach id_add [split $to_add { }] {

				# We are passing the new disporder in the add_list
				set ev_id [lindex [split $id_add |] 0]

				set res [inf_exec_stmt $event_check $ev_id $sport_filter]

				# We have to get exactly 1 row
				if { [db_get_nrows $res] != 1 } {

					# Otherwise it's an error, cleanup and raise error
					inf_close_stmt $event_add
					inf_close_stmt $event_upd
					inf_close_stmt $event_del
					inf_close_stmt $event_check
					db_close $res

					error {Cannot add an event of a different sport}

				}
				db_close $res

			}

			inf_close_stmt $event_check

		}

		# Transactional
		inf_begin_tran $DB

		# Execute view changes
		if {$view_changed} {
			ob_log::write DEBUG \
			  {::ADMIN::EVENTLISTS::_do_update : view $max_other_events \
			    $view_filter}

			if {$do_upd_other_events == 1} {
				# Update
				inf_exec_stmt $view_upd $max_other_events $view_filter
				# Cleanup
				inf_close_stmt $view_upd
			}

			if {$do_upd_my_events == 1} {
				# Update
				inf_exec_stmt $view_upd_my_ev $max_my_events $view_filter
				# Cleanup
				inf_close_stmt $view_upd_my_ev
			}

			if {$do_upd_bir_threshold_num == 1} {
				# Update
				inf_exec_stmt $view_upd_bir_threshold_num $bir_threshold_num $view_filter
				# Cleanup
				inf_close_stmt $view_upd_bir_threshold_num
			}

			if {$do_upd_bir_threshold_den == 1} {
				# Update
				inf_exec_stmt $view_upd_bir_threshold_den $bir_threshold_den $view_filter
				# Cleanup
				inf_close_stmt $view_upd_bir_threshold_den
			}
			
		}

		# Execute sport changes
		if {$sport_changed} {
			ob_log::write DEBUG \
				{::ADMIN::EVENTLISTS::_do_update : sport $max_sport_ev \
				  $max_home_bir_ev \
				  $sport_filter\
				  $view_filter}

			# Update
			inf_exec_stmt $sport_upd \
						  $max_sport_ev \
						  $max_home_bir_ev \
						  $sport_filter \
						  $view_filter

			# Cleanup
			inf_close_stmt $sport_upd
		}

		# Execute Event Display changes
		if { $to_update != "" || $to_delete != "" || $to_add != "" } {

			# Do all the updates (if any)
			foreach id_upd [split $to_update { }] {
				# Get the right value for this update
				set curr_disporder \
					[ob_chk::get_arg disporder_$id_upd \
					   -on_err "" {RE -args {^[[0-9 -]+$}}]

				ob_log::write DEBUG \
					{::ADMIN::EVENTLISTS::_do_update: updating event: $id_upd \
					  $curr_disporder \
					  $view_filter }
				# Update
				inf_exec_stmt $event_upd $curr_disporder $view_filter $id_upd
			}

			# Do all the deletions (if any)
			foreach id_del [split $to_delete { }] {
				# Delete
				inf_exec_stmt $event_del $id_del $view_filter
			}

			# Do all the additions (if any)
			foreach id_add [split $to_add { }] {

				# We are passing the new disporder in the add_list
				set params [split $id_add |]

				set ev_id              [lindex $params 0]
				set new_disporder      [lindex $params 1]

				ob_log::write DEBUG \
					{::ADMIN::EVENTLISTS::_do_update: adding event: $ev_id \
					  $new_disporder \
					  $view_filter }

				# Add
				inf_exec_stmt $event_add $view_filter $ev_id $new_disporder
			}

			# Cleanup
			inf_close_stmt $event_add
			inf_close_stmt $event_upd
			inf_close_stmt $event_del
		}

		# Commit
		inf_commit_tran $DB

	} else {
		# This is unexpected, so it's an error :)
		error {::ADMIN::EVENTLISTS::_do_update : Unexpected Update Request}
	}

}



#==============================================================================
#
# _bind_sports: Bind Up the sports information for the dropdown
#
proc ::ADMIN::EVENTLISTS::_bind_sports { {sport_sel -1} } {

	global DB
	variable SPORTS
	unset -nocomplain SPORTS

	ob_log::write DEV {::ADMIN::EVENTLISTS::_bind_sports $sport_sel}

	set stmt [inf_prep_sql $DB {
		select
			sport_id,
			name,
			ob_level,
			ob_id
		from
			tSport
		order by
			name;
	}]

	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSports [set n_rows [db_get_nrows $res]]

	# Cycle on sports
	for {set r 0} {$r < $n_rows} {incr r} {
		set SPORTS($r,sport_id) [db_get_col $res $r sport_id]
		set SPORTS($r,ob_id)    [db_get_col $res $r ob_id]
		set SPORTS($r,ob_level) [db_get_col $res $r ob_level]
		set SPORTS($r,name)     [db_get_col $res $r name]

		# set the default to the 1st sport in the dropdown
		if {$r == 0 || ($SPORTS($r,sport_id) == $sport_sel)} {
			set default_sport_id   $SPORTS($r,sport_id)
			set default_sport_dd   $SPORTS($r,ob_level)
			set default_sport_obid $SPORTS($r,ob_id)
			if { $SPORTS($r,sport_id) == $sport_sel } {
				set SPORTS($r,selected) {selected="selected"}
			}
		}
	}

	tpBindString SelectedSportId $default_sport_id
	tpBindString SportOBId       $default_sport_obid

	# Remember the drilldown level for the default sport
	switch -exact $default_sport_dd {
		"y" {
			tpBindString SelectedSportDD ROOT
		}
		"c" {
			tpBindString SelectedSportDD CLASS
		}
		default {
			error {Drilldown filter is not 'y' or 'c'}
		}

	}

	set cns [namespace current]

	tpBindVar SportId   ${cns}::SPORTS   sport_id   sport_idx
	tpBindVar SportName ${cns}::SPORTS   name       sport_idx
	tpBindVar SportLev  ${cns}::SPORTS   ob_level   sport_idx
	tpBindVar SportSel  ${cns}::SPORTS   selected   sport_idx

	# Cleanup
	GC::mark SPORTS
	db_close $res

	# Return the default to be pre selected.
	return [list $default_sport_id $default_sport_dd]

}



#==============================================================================
#
# _bind_sportview_config : Bind the configuration items that are associated to
#  the filter sport and view values
#
#	filter_view - the selected view (tviewtype.view)
#	filter_sport - the selected sport (tsport.sport_id)
#
proc ::ADMIN::EVENTLISTS::_bind_sportview_config { filter_view \
												   {filter_sport -1} } {

	global DB
	ob_log::write DEV \
		{::ADMIN::EVENTLISTS::_bind_sportview_config $filter_view $filter_sport}

	# Easier to cycle trough results
	set stmt [inf_prep_sql $DB [format [subst {
		select
			c.name  as name,
			c.value as value
		from
			tViewConfig c
		where
			c.view  = '%s' and
			(c.name = '%s' or c.name = '%s' or c.name = '%s' or c.name = '%s')
		union
		select
			'max_sport_ev' as name,
			max_sport_ev as value
		from
			tSportDispCfg
		where
			view = '%s' and
			sport_id = %s
		union
		select
			'max_home_bir_ev' as name,
			max_home_bir_ev as value
		from
			tSportDispCfg
		where
			view = '%s' and
			sport_id = %s
		}] $filter_view \
		   "max_other_events" \
		   "max_my_events" \
		   "bir_threshold_num" \
		   "bir_threshold_den" \
		    $filter_view \
		    $filter_sport \
		    $filter_view \
		    $filter_sport ]]

	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		set name    [db_get_col $res $r name]
		set value   [db_get_col $res $r value]

		# Bind up the values for the template
		tpBindString $name $value
	}

	db_close $res

}



#==============================================================================
#
#  _bind_event_list_for_sport : Work out what events we need to display
#  for the filtered sport / view combination
#
proc ::ADMIN::EVENTLISTS::_bind_event_list_for_sport { filter_view \
													   {filter_sport -1} \
													   {filter_dd ""} \
													   {order_by "disporder"} } {

	global DB
	variable EVENT_LIST
	unset -nocomplain EVENT_LIST

	ob_log::write DEV \
		{::ADMIN::EVENTLISTS::_bind_event_list_for_sport $filter_view \
														 $filter_sport \
														 $filter_dd}

	# We use a different query depending on the drilldown level
	switch -exact $filter_dd {

	"c" {
	set stmt [inf_prep_sql $DB [format [subst {
	select
			v.id         as ev_id,
			v.disporder  as disporder,
			e.desc       as event_name,
			t.name       as type_name
		from
			tView v,
			tEv e,
			tEvType t,
			tEvClass c,
			tSport s
		where
			v.view = '%s' and
			v.sort = 'EVENT'  and
			e.ev_id = v.id and
			e.settled = 'N' and
			e.ev_type_id = t.ev_type_id and
			e.ev_class_id = c.ev_class_id and
			c.ev_class_id = s.ob_id and
			s.sport_id = '%s'
		order by
			%s
		}] $filter_view $filter_sport $order_by]]
	}

	"y" {
	set stmt [inf_prep_sql $DB [format [subst {
		select
			v.id         as ev_id,
			v.disporder  as disporder,
			e.desc       as event_name,
			t.name       as type_name
		from
			tView v,
			tEv e,
			tEvType t,
			tEvClass c,
			tEvCategory y,
			tSport s
		where
			v.view = '%s' and
			v.sort = 'EVENT'  and
			e.ev_id = v.id and
			e.settled = 'N' and
			e.ev_type_id = t.ev_type_id and
			e.ev_class_id = c.ev_class_id and
			c.category = y.category and
			y.ev_category_id = s.ob_id and
			s.sport_id = '%s'
		order by
			%s
		}] $filter_view $filter_sport $order_by]]
		}

	default {
		error {::ADMIN::EVENTLISTS::_bind_event_list_for_sport - \
				Unsupported drilldown value}
		}
	}

	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumEvents [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set EVENT_LIST($r,ev_id)      [db_get_col $res $r ev_id]
		set EVENT_LIST($r,disporder)  [db_get_col $res $r disporder]
		set EVENT_LIST($r,event_name) [db_get_col $res $r event_name]
		set EVENT_LIST($r,type_name)  [db_get_col $res $r type_name]
	}

	set cns [namespace current]

	tpBindVar EvId         ${cns}::EVENT_LIST   ev_id        event_idx
	tpBindVar EvDisporder  ${cns}::EVENT_LIST   disporder    event_idx
	tpBindVar EventName    ${cns}::EVENT_LIST   event_name   event_idx
	tpBindVar TypeName     ${cns}::EVENT_LIST   type_name    event_idx

	# Cleanup
	GC::mark EVENT_LIST
	db_close $res
}

# namespace end
}

