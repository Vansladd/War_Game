# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Provides access to a customer's account history for display purposes
#
set pkg_version 1.0
package provide core::history $pkg_version

package require core::args                 1.0
package require core::check                1.0
package require core::date                 1.0
package require core::interface            1.0
package require core::security::token      1.0
package require core::history::formatter   1.0
package require core::history::combination 1.0
package require core::db::schema           1.0
package require core::xml                  1.0

core::args::register_ns \
	-namespace     core::history \
	-version       $pkg_version \
	-dependent     [list \
		core::args core::check core::db core::date core::interface core::security::token] \
	-desc          {Account history} \
	-docs          history/history.xml

namespace eval core::history {
	variable HANDLERS
	variable J_OP_REF_KEYS
	variable CFG

	set HANDLERS(groups) [list]
}

catch {
	# Register some useful data types.
	# Prefix with HIST to avoid name collisions
	core::check::register HIST_SETTLED    core::history::_check_type_SETTLED    {}
	core::check::register HIST_DETAIL     core::history::_check_type_DETAIL     {}
	core::check::register HIST_ITEM_KEY   core::history::_check_type_ITEM_KEY   {}
	core::check::register HIST_DATE_FIELD core::history::_check_type_DATE_FIELD {}
}

proc core::history::_check_type_SETTLED {value args} {
	if {$value != {Y} && $value != {N} && $value != {ALL}} {
		return 0
	}

	return 1
}

proc core::history::_check_type_DETAIL {value args} {
	if {$value != {SUMMARY} && $value != {DETAILED}} {
		return 0
	}

	return 1
}

proc core::history::_check_type_ITEM_KEY {value args} {
	if {$value != {ID} && $value != {RECEIPT}} {
		return 0
	}

	return 1
}

proc core::history::_check_type_ITEM_KEY {value args} {
	if {$value != {ID} && $value != {RECEIPT}} {
		return 0
	}

	return 1
}

proc core::history::_check_type_DATE_FIELD {value args} {
	variable CFG

	set available_date_field_filters [list cr_date]
	if {$CFG(settled_at_filtering)} {
		lappend available_date_field_filters {settled_at}
	}

	if {[lsearch $value $available_date_field_filters] == -1} {
		return 0
	} else {
		return 1
	}
}

# Format for item handlers
core::args::register \
	-interface core::history::item_handler \
	-args [list \
		[list -arg -acct_id  -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang     -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -value    -mand 1 -check ASCII             -desc {Value}] \
	]

# Format for page handlers
core::args::register \
	-interface core::history::page_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT        -desc {Account id}] \
		[list -arg -uuid          -mand 0 -check ASCII       -desc {Customer uuid}] \
		[list -arg -lang          -mand 1 -check ASCII       -desc {Language code for customer}] \
		[list -arg -ccy_code      -mand 0 -check ASCII       -desc {Currency code for customer}] \
		[list -arg -group         -mand 1 -check ASCII       -desc {Group name}] \
		[list -arg -filters       -mand 1 -check ANY         -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME    -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME    -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT        -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check UINT        -desc {Page boundary}] \
	]

# Format for pagination result handler (combinable groups only)
core::args::register \
	-interface core::history::pagination_result_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT      -desc {Account id}] \
		[list -arg -filters       -mand 1 -check ANY       -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME  -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME  -desc {Latest date}] \
		[list -arg -page_size     -mand 1 -check UINT      -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check UINT      -desc {Page boundary}] \
	]

# Format for date range handler (combinable groups only)
core::args::register \
	-interface core::history::range_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT        -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII       -desc {Language code for customer}] \
		[list -arg -filters       -mand 1 -check ANY         -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME    -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME    -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT        -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check ANY         -desc {Page boundary}] \
	]

# Initialise the history package
core::args::register \
	-proc_name core::history::init \
	-args [list \
		[list -arg -max_page_size \
			-mand 0 -default 20 -check UINT -desc {Maximum items per page}] \
		[list -arg -token_crypt_key   -mand 1 -check HEX  -desc {Encryption key for pagination token}] \
		[list -arg -token_mac_key     -mand 1 -check HEX  -desc {HMAC key for pagination token}] \
		[list -arg -escape_entities   -mand 0 -default 1  -check BOOL -desc {Escape Special Characters for XML/HTML Printing}] \
		[list -arg -convert_encoding  -mand 0 -default 1  -check BOOL -desc {Encoding converstion from a flattened utf8 bytes into tcl native}] \
		[list -arg -external_system_groups  -mand 0 -check STRING \
			-default_cfg HIST_EXTERNAL_SYSTEM_GROUPS \
			-default {} \
			-desc {Grouping of external systems}] \
		[list -arg -use_fs_history    -mand 0 -check BOOL -default_cfg USE_FS_HISTORY -default 1 -desc {Call Funding Service to get history}]
	] \
	-body {
		variable CFG
		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {History initialised with $formatted_name_value}
		}

		if {[core::db::schema::table_column_exists -table tBetStl -column acct_id] \
			&& [core::db::schema::table_column_exists -table tPoolBetStl -column acct_id]} {
			set CFG(settled_at_filtering) 1
		} else {
			set CFG(settled_at_filtering) 0
		}

		core::log::write INFO {Set max page size to $CFG(max_page_size)}
	}

core::args::register \
	-proc_name core::history::get_config \
	-args [list \
		[list -arg -name    -mand 1             -check ASCII -desc {Config name}] \
		[list -arg -default -mand 0 -default {} -check ANY   -desc {Default value}] \
	] \
	-body {
		variable CFG

		if {![info exists CFG($ARGS(-name))]} {
			return $ARGS(-default)
		}

		return $CFG($ARGS(-name))
	}

# Get a single item by an id or other key
core::args::register \
	-proc_name core::history::get_item \
	-args [list \
		[list -arg -acct_id  -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang     -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -group    -mand 1 -check ASCII             -desc {Group name}] \
		[list -arg -key      -mand 0 -check HIST_ITEM_KEY -default ID -desc {Key}] \
		[list -arg -value    -mand 1 -check ASCII             -desc {Value}] \
	] \
	-body {
		variable HANDLERS

		set group $ARGS(-group)
		set key $ARGS(-key)

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		if {![info exists HANDLERS($group,$key,item_handler)]} {
			core::log::write ERROR {Key $key is not valid for $group}
			error INVALID_ITEM_KEY
		}

		set handler $HANDLERS($group,$key,item_handler)

		return [$handler \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-value            $ARGS(-value) \
		]
	}

# Get a page of items
# Returns a token if there are more results
core::args::register \
	-proc_name core::history::get_page \
	-args [list \
		[list -arg -acct_id      -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -uuid         -mand 0 -check ASCII    -desc {Customer uuid}] \
		[list -arg -lang         -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -ccy_code     -mand 0 -check ASCII    -desc {Currency code for customer}] \
		[list -arg -group        -mand 1 -check ASCII    -desc {Group name}] \
		[list -arg -filters      -mand 0 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date     -mand 0 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date     -mand 0 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level -mand 0 -check HIST_DETAIL -default {SUMMARY} -desc {Detail level of page items}] \
		[list -arg -page_size    -mand 1 -check UINT     -desc {Page size}] \
	] \
	-body {
		variable HANDLERS
		variable CFG

		set args [array get ARGS]
		core::log::write INFO {Getting history with $args}

		array set ARGS [core::history::_check_get_page {*}$args]

		set group $ARGS(-group)

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		set handler $HANDLERS($group,page_handler)

		if {$CFG(use_fs_history) && $ARGS(-group) == "TRANSACTION"} {
			set extra_params [list \
				-ccy_code $ARGS(-ccy_code) \
				-uuid     $ARGS(-uuid)
				]
		} else {
			set extra_params [list]
		}

		set ret [$handler \
			-acct_id      $ARGS(-acct_id) \
			-lang         $ARGS(-lang) \
			-group        $group \
			-filters      $ARGS(-filters) \
			-min_date     $ARGS(-min_date) \
			-max_date     $ARGS(-max_date) \
			-detail_level $ARGS(-detail_level) \
			-page_size    $ARGS(-page_size) \
			{*}$extra_params
		]


		set page_boundary [lindex $ret 0]
		set has_next [expr {$page_boundary != {}}]
		# When requesting a page, in the current api prev_page will always be 0
		set has_prev 0
		set max_date      [lindex $ret 1]
		if {[core::history::_two_way_page_support -group $group]} {
			set has_next [lindex $ret 3]
			set has_prev [lindex $ret 4]
		}

		if {!$has_next} {
			set token {}
		} else {
			set token [_create_token \
				-acct_id       $ARGS(-acct_id) \
				-lang          $ARGS(-lang) \
				-group         $group \
				-filters       $ARGS(-filters) \
				-min_date      $ARGS(-min_date) \
				-max_date      $max_date \
				-detail_level  $ARGS(-detail_level) \
				-page_size     $ARGS(-page_size) \
				-page_boundary $page_boundary \
				{*}$extra_params
			]
		}
		set paging_info [dict create "token" $token "has_next" $has_next "has_prev" $has_prev]
		return [dict create "paging" $paging_info "results" [lindex $ret 2]]
	}

# Get the next page of items using a pagination token
# Returns a token if there are more results
core::args::register \
	-proc_name core::history::get_next_page \
	-args [list \
		[list -arg -acct_id          -mand 1 -check UINT      -desc {Account id}] \
		[list -arg -pagination_token -mand 0 -check ASCII -desc {Pagination token}] \
	] \
	-body {
		variable HANDLERS
		variable CFG

		array set ARGS [core::history::_parse_token {*}[array get ARGS]]

		core::log::write INFO {Getting next page of history with [array get ARGS]}

		set group $ARGS(-group)

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		set handler $HANDLERS($group,page_handler)

		if {$CFG(use_fs_history) && $ARGS(-group) == "TRANSACTION"} {
			set extra_params [list \
				-ccy_code $ARGS(-ccy_code) \
				-uuid     $ARGS(-uuid)
			]
		} else {
			set extra_params [list]
		}

		set ret [$handler \
			-acct_id       $ARGS(-acct_id) \
			-lang          $ARGS(-lang) \
			-group         $group \
			-filters       $ARGS(-filters) \
			-min_date      $ARGS(-min_date) \
			-max_date      $ARGS(-max_date) \
			-detail_level  $ARGS(-detail_level) \
			-page_size     $ARGS(-page_size) \
			-page_boundary $ARGS(-page_boundary) \
			{*}$extra_params
		]

		set boundary_data [lindex $ret 0]
		set max_date      [lindex $ret 1]
		set two_way_paging [core::history::_two_way_page_support -group $group]
		if {$two_way_paging} {
			# Two way paging is supported so we know that we have has_next and has_prev in the response
			set has_next [lindex $ret 3]
			set has_prev [lindex $ret 4]
		} else {
			# Two way paging is not supported but since we go next
			# prev is always avail
			set has_prev 1
			set has_next 1
			# No two way paging so we rely on boundary data
			if {[llength $boundary_data] == 0 && $boundary_data == {}} {
				set has_next 0
			}
		}

		set return_token [expr {$has_next || $has_prev}]

		if {$return_token == 0} {
			set token {}
		} else {
			set token [_create_token \
				-acct_id       $ARGS(-acct_id) \
				-lang          $ARGS(-lang) \
				-group         $group \
				-filters       $ARGS(-filters) \
				-min_date      $ARGS(-min_date) \
				-max_date      $max_date \
				-detail_level  $ARGS(-detail_level) \
				-page_size     $ARGS(-page_size) \
				-page_boundary $boundary_data \
				{*}$extra_params
			]
		}

		set paging_info [dict create "token" $token "has_next" $has_next "has_prev" $has_prev]
		return [dict create "paging" $paging_info "results"  [lindex $ret 2]]
	}



# Get the previous page of items using a pagination token
# Returns a token if there are more results
core::args::register \
	-proc_name core::history::get_prev_page \
	-args [list \
		[list -arg -acct_id          -mand 1 -check UINT      -desc {Account id}] \
		[list -arg -pagination_token -mand 0 -check ASCII -desc {Pagination token}] \
	] \
	-body {
		variable HANDLERS
		variable CFG

		array set ARGS [core::history::_parse_token {*}[array get ARGS]]

		core::log::write INFO {Getting previous page of history with [array get ARGS]}

		set group $ARGS(-group)

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		set handler $HANDLERS($group,page_handler)

		if {$HANDLERS($group,bidirectional) == 0} {
			core::log::write ERROR {$group is not registered as bi-directional}
			error INVALID_ACTION
		}

		if {$CFG(use_fs_history) && $ARGS(-group) == "TRANSACTION"} {
			set extra_params [list \
				-ccy_code $ARGS(-ccy_code) \
				-uuid     $ARGS(-uuid)
			]
		} else {
			set extra_params [list]
		}

		set ret [$handler \
			-acct_id        $ARGS(-acct_id) \
			-lang           $ARGS(-lang) \
			-group          $group \
			-filters        $ARGS(-filters) \
			-min_date       $ARGS(-min_date) \
			-max_date       $ARGS(-max_date) \
			-detail_level   $ARGS(-detail_level) \
			-page_size      $ARGS(-page_size) \
			-page_boundary  $ARGS(-page_boundary) \
			-page_direction PREV \
			{*}$extra_params
		]

		set boundary_data [lindex $ret 0]
		set max_date      [lindex $ret 1]

		if {[core::history::_two_way_page_support -group $group]} {
			# Two way paging is supported so we know that we have has_next and has_prev in the response
			set has_next [lindex $ret 3]
			set has_prev [lindex $ret 4]
		} else {
			# Two way paging not supported but since we travel prev, next is always avail
			set has_next 1
			# When response is not fro mthe FS, then has_prev needs to be calculated
			# from boundary data
			set has_prev 1
			if {[llength $boundary_data] == 0 && $boundary_data == {}} {
				set has_prev 0
			}
		}

		set return_token [expr {$has_next || $has_prev}]

		if {$return_token == 0} {
			set token {}
		} else {
			set token [_create_token \
				-acct_id       $ARGS(-acct_id) \
				-lang          $ARGS(-lang) \
				-group         $group \
				-filters       $ARGS(-filters) \
				-min_date      $ARGS(-min_date) \
				-max_date      $max_date \
				-detail_level  $ARGS(-detail_level) \
				-page_size     $ARGS(-page_size) \
				-page_boundary $boundary_data \
				{*}$extra_params
			]
		}

		# We always return the paging info. Clients that don't support two
		# way paging will ignore this
		set paging_info [dict create "token" $token "has_next" $has_next "has_prev" $has_prev]
		return [dict create "paging" $paging_info "results" [lindex $ret 2]]
	}

# Helper Proc to determine if Two way paging is supported by the caller and the service
core::args::register \
	-proc_name core::history::_two_way_page_support \
	-args	[list \
		[list -arg -group -mand 1 -check ASCII -desc {The group of the transaction history checked}] \
	] \
	-body {
		variable CFG
		# Only the funding service has two way paging support
		# The TRANSACTION group is the only group that goes via the FS.
		if {$CFG(use_fs_history) && $ARGS(-group) == "TRANSACTION"} {
			return 1
		}
		return 0
	}

# Get available groups
core::args::register \
	-proc_name core::history::get_groups \
	-body {
		variable HANDLERS
		return $HANDLERS(groups)
	}

# Get available filters
core::args::register \
	-proc_name core::history::get_filters \
	-args [list \
		[list -arg -group -mand 0 -check ASCII -desc {Group name}] \
	] \
	-body {
		variable HANDLERS

		set group $ARGS(-group)

		set ret [list]
		foreach filter $HANDLERS($group,filters) {
			lappend ret [list \
				$filter \
				$HANDLERS($group,$filter,type) \
				$HANDLERS($group,$filter,default) \
			]
		}

		return $ret
	}


#
# Functions called by modules
#

# Register a group and its page handler
core::args::register \
	-proc_name core::history::add_group \
	-args [list \
		[list -arg -group         -mand 1 -check ASCII -desc {Group name}] \
		[list -arg -page_handler  -mand 1 -check ASCII -desc {Function to get a page of data}] \
		[list -arg -filters       -mand 0 -check ASCII -desc {List of available filters. Each filter should be a list of name, type, and default values. Valid types are the same as those used in core::args}] \
		[list -arg -detail_levels -mand 0 -check ASCII -default {SUMMARY} -desc {Valid detail levels for this group}] \
		[list -arg -j_op_ref_keys -mand 0 -check ASCII -desc {List of tJrnl j_op_ref_key codes that should be used to link journal entries to this group.}] \
		[list -arg -bidirectional -mand 0 -check INT   -default 0 -desc {Does the page handler work bi-directionally}]
	] \
	-body {
		variable HANDLERS
		variable J_OP_REF_KEYS
		variable CFG

		set group $ARGS(-group)

		set detail_levels [lsort -unique $ARGS(-detail_levels)]
		if {$detail_levels == {}} {
			core::log::write ERROR {core::history::add_group: Invalid format for detail_levels: expected one or more of SUMMARY, DETAILED}
			error INVALID_FORMAT
		}

		foreach detail_level $detail_levels {
			if {[lsearch {SUMMARY DETAILED} $detail_level] == -1} {
				core::log::write ERROR {core::history::add_group: Invalid format for detail_levels: expected one or more of SUMMARY, DETAILED}
				error INVALID_FORMAT
			}
		}

		set page_handler [string trimleft $ARGS(-page_handler) {::}]
		core::interface::check_proc \
			-interface core::history::page_handler \
			-proc_name $page_handler

		if {[info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group already exists}
			error ALREADY_EXISTS
		}

		set HANDLERS($group,detail_levels) $detail_levels
		set HANDLERS($group,filters) [list]

		foreach filter $ARGS(-filters) {
			if {[llength $filter] != 3} {
				core::log::write ERROR {Invalid format for filter $filter}
				error INVALID_FORMAT
			}
			_add_filter $group {*}$filter
		}

		set HANDLERS($group,page_handler) $page_handler

		set HANDLERS($group,bidirectional) $ARGS(-bidirectional)

		# Ensure that a j_ref_key can only be associated with one module.
		# This does not affect combination modules - combination modules
		# are not associated with j_ref_keys.
		foreach key $ARGS(-j_op_ref_keys) {
			if {[lsearch [array names J_OP_REF_KEYS] $key] != -1} {
				core::log::write ERROR {j_ref_key is already associated with a group}
				error {j_ref_key is already associated with a group} {} J_REF_KEY_ALREADY_USED
			}
			set J_OP_REF_KEYS($key) $group
		}

		lappend HANDLERS(groups) $group

		core::log::write INFO {Registered history group $group}
	}

# Register a combinable group.
# Combinable groups must provide a function to return a pagination result set,
# and a function to return items within a date range.
core::args::register \
	-proc_name core::history::add_combinable_group \
	-args [list \
		[list -arg -group                 -mand 1 -check ASCII -desc {Group name}] \
		[list -arg -page_handler          -mand 1 -check ASCII -desc {Function to get a page}] \
		[list -arg -pagination_result_handler -mand 1 -check ASCII -desc {Function to get a pagination result set}] \
		[list -arg -range_handler         -mand 1 -check ASCII -desc {Function to get all items within a date range}] \
		[list -arg -filters               -mand 0 -check ASCII -desc {List of available filters and their types}] \
		[list -arg -detail_levels         -mand 0 -check ASCII -default {SUMMARY} -desc {Valid detail levels for this group}] \
		[list -arg -j_op_ref_keys         -mand 0 -check ASCII -desc {List of tJrnl j_op_ref_key codes that should be used to link journal entries to this group.}] \
	] \
	-body {
		variable HANDLERS
		variable CFG

		set group $ARGS(-group)

		add_group \
			-group            $group \
			-filters          $ARGS(-filters) \
			-page_handler     $ARGS(-page_handler) \
			-detail_levels    $ARGS(-detail_levels) \
			-j_op_ref_keys    $ARGS(-j_op_ref_keys)

		set rs_handler    $ARGS(-pagination_result_handler)
		set range_handler $ARGS(-range_handler)

		set HANDLERS($group,pagination_result_handler) $rs_handler
		set HANDLERS($group,range_handler) $range_handler

		core::log::write INFO {Registered combinable history group $group}
	}

# Get details of a combinable group
core::args::register \
	-proc_name core::history::get_combinable_group \
	-args [list \
		[list -arg -group -check ASCII -mand 1 -desc {Group name}] \
	] \
	-body {
		variable HANDLERS
		set group $ARGS(-group)

		if {[catch {
			set ret [dict create \
				-filters                       [get_filters -group $group] \
				-detail_levels                 $HANDLERS($group,detail_levels) \
				-range_handler                 $HANDLERS($group,range_handler) \
				-pagination_result_handler     $HANDLERS($group,pagination_result_handler) \
				-page_handler                  $HANDLERS($group,page_handler)]
		} err]} {
			core::log::write DEBUG {Cannot combine group $group: $err}
			error INVALID_GROUP_COMBI
		}

		return $ret
	}

# Register a proc to get a single item
core::args::register \
	-proc_name core::history::add_item_handler \
	-args [list \
		[list -arg -group        -mand 1 -check ASCII -desc {Group name}] \
		[list -arg -item_handler -mand 1 -check ASCII -desc {Function to get a single item}] \
		[list -arg -key          -mand 0 -check HIST_ITEM_KEY -default {ID} -desc {Key type to search by}] \
	] \
	-body {
		variable HANDLERS

		set group $ARGS(-group)
		set key $ARGS(-key)

		# Check no existing handler
		if {[info exists HANDLERS($group,$key,item_handler)]} {
			core::log::write ERROR {Item handler already exists for $ARGS(-group) $ARGS(-key)}
			error ALREADY_EXISTS
		}

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		set item_handler [string trimleft $ARGS(-item_handler) {::}]
		core::interface::check_proc \
			-interface core::history::item_handler \
			-proc_name $item_handler

		set HANDLERS($group,$key,item_handler) $item_handler
	}

# Get the group that handles items associated with a j_op_ref_key
core::args::register \
-proc_name core::history::get_group_for_ref_key \
-args [list \
	[list -arg -j_op_ref_key -check ASCII -mand 1 -desc {Journal reference key to get the group for}] \
] \
	-body {
		variable J_OP_REF_KEYS

		set key $ARGS(-j_op_ref_key)
		set group $key

		if {[catch {set group $J_OP_REF_KEYS($key)} err]} {
			core::log::write WARNING {No handler found for key $key}
		}

		return $group
	}


#
# Private procedures
#

# Create pagination token containing all args
core::args::register \
	-proc_name core::history::_create_token \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -uuid          -mand 0 -check ASCII    -desc {Customer uuid}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -ccy_code      -mand 0 -check ASCII    -desc {Currency code for customer}] \
		[list -arg -group         -mand 1 -check ASCII    -desc {Group name}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -page_boundary -mand 1 -check ANY      -desc {Page boundary information (its a list of min_id and max_id}] \
	] \
	-body {
		variable CFG

		return [core::security::token::create \
			-aes_key          $CFG(token_crypt_key) \
			-hmac_key         $CFG(token_mac_key) \
			-content          [array get ARGS] \
			-encoding         BASE64 \
			-type             PAGINATION \
		]
	}

# Parse pagination token
# Returns a dict containing the args to _create_token
core::args::register \
	-proc_name core::history::_parse_token \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id          -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -pagination_token -mand 1 -check ASCII -desc {Pagination token}] \
	] \
	-body {
		variable CFG

		set acct_id $ARGS(-acct_id)
		set token   $ARGS(-pagination_token)

		if {[catch {
			set ret [core::security::token::verify \
				-aes_key         $CFG(token_crypt_key) \
				-hmac_key        $CFG(token_mac_key) \
				-token           $token \
				-encoding        BASE64 \
				-type            PAGINATION \
			]
		} err]} {
			core::log::write ERROR {Invalid token: $err}
			error INVALID_TOKEN $::errorInfo
		}

		if {[dict get $ret -acct_id] != $acct_id} {
			core::log::write ERROR {Account id $acct_id does not match acct_id from pagination token $acct_id}
			error INVALID_TOKEN
		}

		return $ret
	}

# Helper proc to validate the arguments to get_page.
# This sets the default date range if none were passed in, and returns the
# validated arguments as name/value pairs.
core::args::register \
	-proc_name core::history::_check_get_page \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id      -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -uuid         -mand 0 -check ASCII    -desc {Customer uuid}] \
		[list -arg -lang         -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -ccy_code     -mand 0 -check ASCII    -desc {Currency code for customer}] \
		[list -arg -group        -mand 1 -check ASCII    -desc {Group name}] \
		[list -arg -filters      -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date     -mand 1 -check ANY      -desc {Earliest date}] \
		[list -arg -max_date     -mand 1 -check ANY      -desc {Latest date}] \
		[list -arg -detail_level -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -page_size    -mand 1 -check UINT     -desc {Page size}] \
	] \
	-body {
		variable HANDLERS

		array set ARGS $args
		set group $ARGS(-group)

		if {![info exists HANDLERS($group,page_handler)]} {
			core::log::write ERROR {Group $group does not exist}
			error INVALID_GROUP
		}

		if {$ARGS(-min_date) == {}} {
			set ARGS(-min_date) [core::date::get_informix_date -seconds BOT]
		}

		if {$ARGS(-max_date) == {}} {
			set ARGS(-max_date) [core::date::get_informix_date -seconds [clock seconds]]
		}

		dict for {filter_name filter_value} $ARGS(-filters) {
			_check_filter $group $filter_name $filter_value
		}

		foreach filter_name $HANDLERS($group,filters) {
			if {![dict exists $ARGS(-filters) $filter_name]} {
				set default_value $HANDLERS($group,$filter_name,default)
				dict set ARGS(-filters) $filter_name $default_value
				core::log::write DEBUG {Set $filter_name to default value $default_value}
			}
		}

		if {[lsearch $HANDLERS($group,detail_levels) $ARGS(-detail_level)] == -1} {
			core::log::write ERROR {Invalid detail level $ARGS(-detail_level) for group $group}
			error INVALID_DETAIL_LEVEL
		}

		set max_page_size [get_config -name max_page_size]
		if {$ARGS(-page_size) > $max_page_size} {
			core::log::write ERROR {Page size too high: requested $ARGS(-page_size) max $max_page_size}
			error PAGE_SIZE_HIGH
		} elseif {$ARGS(-page_size) < 1} {
			core::log::write ERROR {Page size too low: requested $ARGS(-page_size) min 1}
			error PAGE_SIZE_LOW
		}

		return [array get ARGS]
	}

# Register a filter for a group
proc core::history::_add_filter {group name type dflt} {
	variable HANDLERS

	set filter [string tolower $name]

	if {[lsearch $HANDLERS($group,filters) $filter] != -1} {
		core::log::write ERROR {Filter $filter already exists for group $group}
		error ALREADY_EXISTS
	}

	lappend HANDLERS($group,filters) $filter

	set HANDLERS($group,$filter,default) $dflt

	if {![lindex [core::check::command_for_type [lindex $type 0]] 0]} {
		core::log::write ERROR {Invalid type for filter $filter: $type}
		error INVALID_FORMAT
	}

	set HANDLERS($group,$filter,type)    $type
}

# Check whether a filter is valid for a group
proc core::history::_check_filter {group filter_name filter_value} {
	variable HANDLERS

	if {[lsearch $HANDLERS($group,filters) $filter_name] == -1} {
		core::log::write ERROR {Unsupported filter for $group: $filter_name}
		error INVALID_FILTER
	}

	if {[catch {
		set valid [core::check::check_value \
			$filter_value \
			{AND} [list $HANDLERS($group,$filter_name,type)]]
	} err]} {
		core::log::write ERROR {Invalid format for $filter_name (type $HANDLERS($group,$filter_name,type)): $err}
		error INVALID_FORMAT $::errorInfo
	}

	if {!$valid} {
		core::log::write ERROR {Invalid format for filter $filter_name (type $HANDLERS($group,$filter_name,type))}
		error INVALID_FORMAT
	}
}

# Validate the date range.
# If -max_days is specified, the date range must be narrower than the required
# number of days. This may be used for specific groups/filters that do not scale
# well enough to use with a long time period.
core::args::register \
	-proc_name core::history::validate_date_range \
	-args [list \
		[list -arg -from      -check DATETIME -mand 1 -desc {Earliest date}] \
		[list -arg -to        -check DATETIME -mand 1 -desc {Latest date}] \
		[list -arg -max_days  -check UINT     -mand 0 -desc {Maximum number of days}] \
	] \
	-body {
		set start  [clock scan $ARGS(-from)]
		set end    [clock scan $ARGS(-to)]
		if {$start >= $end} {
			core::log::write ERROR {Date range invalid: $ARGS(-from)-$ARGS(-to)}
			error "INVALID_DATE_RANGE"
		}

		if {$ARGS(-max_days) != {}} {
			set max_end [clock add $start $ARGS(-max_days) days]

			# Add 1 hour to account for daylight savings
			set max_end [clock add $max_end 1 hours]

			if {$end > $max_end} {
				core::log::write ERROR {Date range $ARGS(-from)-$ARGS(-to) too wide, max $ARGS(-max_days) days}
				error "DATE_RANGE_WIDE"
			}
		}
	}

# Convert flattened utf8 values and escape special characters
core::args::register \
	-proc_name core::history::xl \
	-args [list \
		[list -arg -value -check ANY -mand 1 -desc {String to be converted and escaped}] \
	] \
	-body {
		variable CFG

		set value $ARGS(-value)
		if {$CFG(convert_encoding) && [info exists ::env(AS_CHARSET)] && \
			[string equal $::env(AS_CHARSET) "UTF-8"]} {
			set value [core::util::convert_encoding $value]
		}

		if {$CFG(escape_entities)} {
			set value [core::xml::escape_entity -value $value]
		}

		return $value
	}
