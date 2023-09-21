# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Combine account history groups
#
set pkg_version 1.0
package provide core::history::combination $pkg_version

package require core::args 1.0
package require core::util 1.0

core::args::register_ns \
	-namespace     core::history::combination \
	-version       $pkg_version \
	-dependent     [list core::args core::util] \
	-desc          {Combine account history groups} \
	-docs          history/combination.xml

namespace eval core::history::combination {
	variable GROUPS
}

core::args::register \
	-proc_name core::history::combination::add \
	-args [list \
		[list -arg -name   -check ASCII -mand 1 -desc {Name of new combination group}] \
		[list -arg -groups -check ASCII -mand 1 -desc {List of group names to combine}] \
	] \
	-body {
		variable GROUPS

		set groups $ARGS(-groups)
		if {[llength $groups] < 2} {
			core::log::write ERROR "Expected two or more groups"
			error INVALID_FORMAT
		}

		set name $ARGS(-name)

		set first_group [lindex $groups 0]
		set details [core::history::get_combinable_group -group $first_group]

		set filters        [dict get $details -filters]
		set init_filters   [list]
		set detail_levels  [dict get $details -detail_levels]
		set rs_handlers    [dict create $first_group [dict get $details -pagination_result_handler]]
		set range_handlers [dict create $first_group [dict get $details -range_handler]]

		foreach group [lrange $groups 1 end] {
			set details [core::history::get_combinable_group -group $group]
			set current_filters [dict get $details -filters]

			lappend init_filters {*}[core::util::lxor $filters $current_filters]
			set filters [core::util::intersection $filters $current_filters]
			set detail_levels [core::util::intersection $detail_levels [dict get $details -detail_levels]]

			dict set rs_handlers    $group [dict get $details -pagination_result_handler]
			dict set range_handlers $group [dict get $details -range_handler]
		}

		if {![llength $detail_levels]} {
			core::log::write ERROR "Groups $groups have no detail levels in common"
			error CANNOT_COMBINE
		}

		# The init filters are a list of filters that must be initialized with
		# their default values. It is composed of the filters that are present
		# in one or more, but not all, of the groups.
		set GROUPS($name,init_filters)   [core::util::luniq $init_filters]
		set GROUPS($name,rs_handlers)    $rs_handlers
		set GROUPS($name,range_handlers) $range_handlers

		core::history::add_group -group $name \
			-page_handler     core::history::combination::get_page \
			-filters          $filters \
			-detail_levels    $detail_levels
	}

# Get a page from a combined group
core::args::register \
	-proc_name core::history::combination::get_page \
	-args [list \
		[list -arg -acct_id      -mand 1 -check UINT      -desc {Account id}] \
		[list -arg -lang         -mand 1 -check ASCII     -desc {Language code for customer}] \
		[list -arg -group        -mand 1 -check ASCII     -desc {Group name}] \
		[list -arg -filters      -mand 1 -check ANY       -desc {Dict of filter names/filter values}] \
		[list -arg -min_date     -mand 1 -check DATETIME  -desc {Earliest date}] \
		[list -arg -max_date     -mand 1 -check DATETIME  -desc {Latest date}] \
		[list -arg -detail_level -mand 1 -check ASCII     -desc {Detail level of page items}] \
		[list -arg -page_size    -mand 1 -check UINT      -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check ASCII    -desc {Page boundary}] \
	] \
	-body {
		set group            $ARGS(-group)
		set page_size        $ARGS(-page_size)
		set page_boundary    $ARGS(-page_boundary)

		core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date)

		set ret [_get_combined_dates [array get ARGS]]
		set combined_dates    [lindex $ret 0]
		set ranges            [lindex $ret 1]
		set counts            [lindex $ret 2]
		set more_pages        [lindex $ret 3]
		set combined_max_date [lindex $combined_dates end-1]

		set ret [_get_combined_details $combined_dates $ranges $counts [array get ARGS]]
		set combined_details [lindex $ret 0]
		set page_boundary    [lindex $ret 1]

		if {!$more_pages} {
			set page_boundary {}
		}

		return [list $page_boundary $combined_max_date $combined_details]
	}


#
# Private procedures
#

# Work out how many items from each group belong on the page
# @param search_params a dict storing the parameters passed to get_page
# @return a list containing:
#  i) a list of cr_date and group for each item on the page
#  ii) a dict storing the number of items from each subgroup
#  iii) a dict storing the date ranges for each subgroup
#  iv) a boolean indicating whether there are more pages
proc core::history::combination::_get_combined_dates {search_params} {
	# Get pagination result sets for each group
	set ret [_get_pagination_rs $search_params]
	set group_results $ret

	# Combine the pagination result sets
	set ret [_combine_dates [dict get $search_params -page_size] $group_results]

	foreach rs [dict values $group_results] {
		core::db::rs_close -rs $rs
	}

	return $ret
}

# Execute pagination queries for each group
# @param  search_params a dict storing the parameters passed to get_page
# @return a dict mapping each subgroup to a result set
proc core::history::combination::_get_pagination_rs {search_params} {
	variable GROUPS

	array set ARGS $search_params

	set group         $ARGS(-group)
	set acct_id       $ARGS(-acct_id)
	set min_date      $ARGS(-min_date)
	set max_date      $ARGS(-max_date)
	set page_size     $ARGS(-page_size)
	set filters       $ARGS(-filters)
	set page_boundary $ARGS(-page_boundary)

	set rs_handlers $GROUPS($group,rs_handlers)

	set group_results [dict create]
	set more_pages 0

	# Add filters that require initializing.
	foreach filter $GROUPS($group,init_filters) {
		core::log::write INFO {_get_pagination_rs: filter = $filter}

		lassign $filter filter_name filter_check default
		lappend filters $filter_name $default
	}

	dict for {subgroup handler} $rs_handlers {
		set args [list \
			-acct_id          $acct_id \
			-min_date         $min_date \
			-max_date         $max_date \
			-page_size        $page_size \
			-filters          $filters]

		if {[dict exists $page_boundary $subgroup]} {
			lappend args -last_id [dict get $page_boundary $subgroup]
		}

		if {[catch {set rs [$handler {*}$args]} err]} {
			core::log::write ERROR {Error calling pagination handler for $subgroup: $err}
			foreach rs $group_results {
				core::db::rs_close -rs $rs
			}
			error $err $::errorInfo
		}

		set nrows [db_get_nrows $rs]
		if {$nrows} {
			dict set group_results $subgroup $rs
		} else {
			core::log::write DEBUG {No rows found for subgroup $subgroup}
			core::db::rs_close -rs $rs
		}
	}

	core::log::write DEBUG {Got pagination results $group_results}
	return $group_results
}

# Work out how many items on this page belong to each subgroup,
# and combine the pagination result sets into a single ordered list.
# @param page_size      the number of items per page
# @param group_results  a dict storing the pagination result sets for each subgroup
# @return               a list containing:
#  i) a list of cr_date and group for each item on the page
#  ii) a dict storing the number of items from each subgroup
#  iii) a dict storing the date ranges for each subgroup
#  iv) a boolean indicating whether there are more pages
proc core::history::combination::_combine_dates {page_size group_results} {
	set subgroups        [dict keys $group_results]
	set combined_results [list]
	set ranges           [dict create]

	# Current row for each subgroup
	set group_row        [dict create]

	# Size of each result set
	set group_nrows      [dict create]

	# Total number of rows accross all result sets
	set combined_nrows 0

	foreach subgroup $subgroups {
		set rs    [dict get $group_results $subgroup]
		set nrows [db_get_nrows $rs]

		dict set group_nrows $subgroup $nrows
		dict set group_row $subgroup   0

		incr combined_nrows $nrows
	}

	set more_pages [expr {$combined_nrows > $page_size}]

	set bot [core::date::get_informix_date -seconds BOT]
	for {set i 0} {$i < $page_size} {incr i} {
		set latest_date  $bot
		set latest_group {}
		set latest_id    -1

		# Work out which subgroup comes next in the page.
		# If multiple subgroups have items with the same date,
		# then the ordering will depend on which subgroup came first
		# when the combination was registered.
		foreach subgroup $subgroups {
			set nrows    [dict get $group_nrows $subgroup]
			set row      [dict get $group_row $subgroup]
			set rs       [dict get $group_results $subgroup]

			if {$row < $nrows} {
				set cr_date [db_get_coln $rs $row 0]
				if {$cr_date > $latest_date} {
					set latest_date  $cr_date
					set latest_group $subgroup
					if {"id" in [db_get_colnames $rs]} {
						set latest_id    [db_get_col $rs $row id]
					}
				}
			}
		}

		if {$latest_group == {}} {
			break
		}

		lappend combined_results $latest_date $latest_group
		dict incr group_row $latest_group

		# Restrict the date range for this subgroup
		if {![dict exists $ranges $latest_group max_date]} {
			dict set ranges $latest_group max_date $latest_date
		}
		
		dict set ranges $latest_group min_date $latest_date 
		
		if {$latest_id != -1} {
			if {![dict exists $ranges $latest_group ids]} {
				dict set ranges $latest_group ids $latest_id
			} else {
				set ids [dict get $ranges $latest_group ids]
				lappend ids $latest_id
				dict set ranges $latest_group ids $ids 
			}
		}
	}

	core::log::write DEBUG {Combined dates: $combined_results}
	core::log::write DEBUG {ranges: $ranges}
	return [list $combined_results $ranges $group_row $more_pages]
}

# Get a dict of details for each subgroup
# @param ranges        a dict storing max/min date per subgroup
# @param counts        a dict storing the number of items to return from each subgroup
# @param search_params a dict storing the parameters passed to get_page
# @return              a dict storing lists of results per group
proc core::history::combination::_get_details {ranges counts search_params} {
	variable GROUPS
	array set ARGS $search_params

	set group         $ARGS(-group)
	set acct_id       $ARGS(-acct_id)
	set lang          $ARGS(-lang)
	set page_size     $ARGS(-page_size)
	set filters       $ARGS(-filters)
	set detail_level  $ARGS(-detail_level)
	set page_boundary $ARGS(-page_boundary)

	set range_handlers $GROUPS($group,range_handlers)
	set group_details  [dict create]

	# Add filters that require initializing.
	foreach filter $GROUPS($group,init_filters) {
		core::log::write INFO {_get_pagination_rs: filter = $filter}

		lassign $filter filter_name filter_check default
		lappend filters $filter_name $default
	}

	dict for {subgroup range} $ranges {
		set num_items [dict get $counts $subgroup]
		set max_date  [dict get $range max_date]
		set min_date  [dict get $range min_date]
		set handler   [dict get $range_handlers $subgroup]
		set args      [list \
			-acct_id          $acct_id \
			-min_date         $min_date \
			-max_date         $max_date \
			-lang             $lang \
			-detail_level     $detail_level \
			-page_size        $page_size \
			-filters          $filters]

		if {[dict exists $page_boundary $subgroup]} {
			lappend args -last_id [dict get $page_boundary $subgroup]
		}

		if {[dict exists $range ids]} {
			lappend args -ids [dict get $range ids]
		}

		set details [$handler {*}$args]

		# Results may need to be truncated if there are items at the end
		# with the same cr_date
		if {[llength $details] > $num_items} {
			set details [lrange $details 0 [expr {$num_items - 1}]]
		}

		dict set group_details $subgroup $details
	}

	core::log::write DEBUG {Details $group_details}
	return $group_details
}

# Combine detailed results into a single list
# @param combined_dates  a list of date/group for every item on the page
# @param ranges          a dict storing the max/min date per subgroup
# @param group_num_items a dict storing the number of items on the page per subgroup
# @param search_params   a dict storing the parameters passed to get_page
# @return a list containing:
#  i) a list of combined details
#  ii) the updated page boundary dict (last id seen for each group)
proc core::history::combination::_get_combined_details {combined_dates ranges group_num_items search_params} {
	# Details per group
	set details [_get_details $ranges $group_num_items $search_params]

	set next [dict create]
	foreach subgroup [dict keys $details] {
		dict set next $subgroup 0
	}

	# Combine details and update the page boundary for each group
	set combined_details [list]
	set page_boundary [dict get $search_params -page_boundary]
	foreach {cr_date subgroup} $combined_dates {
		set item [lindex [dict get $details $subgroup] [dict get $next $subgroup]]
		lappend combined_details $item
		dict incr next $subgroup

		dict set page_boundary $subgroup [dict get $item id]
	}

	core::log::write DEBUG {Combined details: $combined_details}
	return [list $combined_details $page_boundary]
}
