# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Transfer Module of Account History Package
#
#
# Procedures:
#    core::history::transfer::init                one time initialization
#    core::history::transfer::get_page            The only proc that it is exposed as a public proc
#                                                 that's why it is the only proc registered with core::args
#                                                 Returns next page of history transfer items
#    core::history::transfer::get_pagination_rs   retrieve a result set that can be used to
#                                                 determine which transfer items should be in the page
#    core::history::transfer::get_range           get all transfer items within a cr_date range
#    core::history::transfer::get_item            retrieve details for a transfer item

set pkg_version 1.0
package provide core::history::transfer $pkg_version

package require core::args       1.0
package require core::db         1.0
package require core::history    1.0
package require core::db::schema 1.0
package require core::log        1.0


core::args::register_ns \
	-namespace core::history::transfer \
	-version     $pkg_version \
	-dependent   [list core::args core::db core::history core::db::schema core::log] \
	-desc        {Transfer Account History} \
	-docs        history/transfer.xml

# Variables
namespace eval core::history::transfer {

	variable INIT 0
	variable CFG
}

# Initialize history transfer module
core::args::register \
	-proc_name core::history::transfer::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_TRANSFER_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_TRANSFER_GET_RANGE_DIRECTIVE \
			-default {} \
			-desc {Directive for get_range queries}] \
		[list -arg -get_item_directive  -mand 0 -check STRING \
			-default_cfg HIST_TRANSFER_GET_ITEM_DIRECTIVE \
			-default {} \
			-desc {Directive for get item query}] \
		[list -arg -show_italian_transfer_history -mand 0 -check BOOL \
			-default_cfg HIST_TRANSFER_SHOW_ITALIAN_INFO -default 0 \
			-desc {Enable SOGEI sub info retrieval}] \
		[list -arg -show_free_amount_history -mand 0 -check BOOL \
			-default_cfg HIST_TRANSFER_SHOW_FREE_AMOUNT -default 0 \
			-desc {Show Casino bonus/pending amount}] \
		[list -arg -escape_untranslated_entities -mand 0 -check BOOL \
			-default_cfg HIST_ESCAPE_UNTRANSLATED_ENTITIES -default 0 \
			-desc {Escape Untranslated Entities for XML/HTML Printing}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {$INIT} {
			return
		}

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Transfer Module initialised with $formatted_name_value}
		}

		# Set Transfer Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			group               group \
			id                  xfer_id \
			cr_date             cr_date \
			amount              amount \
			remote_action       remote_action \
			remote_reference    remote_ref \
			remote_account      remote_acct \
			remote_unique_id    remote_unique_id \
			description         desc \
			source              source \
			system_id           system_id \
			system_name         system_name \
			game_display_name   game_display_name \
			held_amount         held_amount \
			token_amount        token_amount \
		]

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		# If we have tXsysHost we can join it in the queries and
		# filter by system_name.
		set CFG(sys_host_exists) [expr {[core::db::schema::table_column_exists \
			-table txsyshost -column system_id] ? 1 :0}]

		# If we have tSOGEISubInfo it will be joined in the query
		# and the extra sogei info will be added.
		set CFG(sogei_info_exists) [expr {[core::db::schema::table_column_exists \
			-table tSOGEISubInfo -column xfer_id] ? 1 :0}]

		# Mapping of groups and external system_names
		# GROUP {Xsys1 Xsys2 Xsys3}
		set CFG(external_system_groups) [core::history::get_config -name external_system_groups]

		set filters [list \
			[list system_name  ASCII ALL] \
			[list system_group ASCII ALL] \
		]

		# Check whether the Sogei table is available for the external
		# Italian info. If yes add the extra fields in the summary.
		if {$CFG(show_italian_transfer_history)} {
			if {$CFG(sogei_info_exists)} {
				lappend CFG(summary_elements) \
					sogei_id    sogei_id \
					sogei_ts    sogei_ts \
					ext_wager   ext_wager \
					ext_returns ext_returns
			} else {
				core::log::write WARNING "tSOGEISubInfo does not exist"
			}
		}

		if {$CFG(show_free_amount_history) || ($CFG(show_italian_transfer_history) && $CFG(sogei_info_exists))} {
			lappend CFG(summary_elements) \
				free_amount free_amount
		}

		# Register history transfer handlers to history package
		core::history::add_combinable_group \
			-group                          {TRANSFER} \
			-filters                        $filters \
			-page_handler                   core::history::transfer::get_page \
			-range_handler                  core::history::transfer::get_range \
			-pagination_result_handler      core::history::transfer::get_pagination_rs \
			-j_op_ref_keys                  {XSYS} \
			-detail_levels                  {SUMMARY DETAILED}

		# Register history add item handler to history package
		core::history::add_item_handler \
			-group            {TRANSFER} \
			-item_handler     core::history::transfer::get_item

		# Prepare the queries
		_prep_queries

		set INIT 1
	}


# Register proc core::history::transfer::get_page
# This proc is responsible for returning the history transfer items.
#
# It first calls get_pagination_rs to get the cr_date boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]].
core::args::register \
	-proc_name core::history::transfer::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -group         -mand 1 -check ASCII    -desc {Transaction Group Name}] \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account Id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dictionary of Filters}] \
		[list -arg -detail_level  -mand 0 -check HIST_DETAIL -desc {Summary Detail Level}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Start Date Time}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {End Date Time}] \
		[list -arg -page_boundary -mand 0 -check INT      -desc {Value of Last Id} -default -1] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page Size}] \
	] \
	-body {

		core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date)

		set rs [get_pagination_rs \
			-acct_id   $ARGS(-acct_id) \
			-filters   $ARGS(-filters) \
			-min_date  $ARGS(-min_date) \
			-max_date  $ARGS(-max_date) \
			-page_size $ARGS(-page_size) \
			-last_id   $ARGS(-page_boundary)]

		set nrows [db_get_nrows $rs]

		set new_boundary {}
		set new_max_date {}
		set results {}

		if {$nrows} {
			if {$nrows > $ARGS(-page_size)} {
				# There are more pages available.
				set more_pages 1
				set page_last_row_idx [expr {$ARGS(-page_size) - 1}]
			} else {
				set more_pages 0
				set page_last_row_idx [expr {$nrows - 1}]
			}

			set max_date [db_get_col $rs 0 cr_date]
			set min_date [db_get_col $rs $page_last_row_idx cr_date]

			set results [get_range \
				-acct_id         $ARGS(-acct_id) \
				-last_id         $ARGS(-page_boundary) \
				-lang            $ARGS(-lang) \
				-min_date        $min_date \
				-max_date        $max_date \
				-detail_level    $ARGS(-detail_level)\
				-page_size       $ARGS(-page_size) \
				-filters         $ARGS(-filters)]

			if {$more_pages && [llength $results]} {
				set new_boundary [dict get [lindex $results end] id]
				set new_max_date [dict get [lindex $results end] cr_date]
			}
		}

		core::db::rs_close -rs $rs

		return [list $new_boundary $new_max_date $results]
	}

# Get a single item by an id or other key
core::args::register \
	-proc_name core::history::transfer::get_item \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -key     -mand 0 -check ASCII -default ID -desc {Key}] \
		[list -arg -value   -mand 1 -check UINT              -desc {Value}] \
	] \
	-body {
		variable CFG

		set fn {core::history::transfer::get_item}

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::transfer::get_transfer_item} \
				-args [list $ARGS(-acct_id) $ARGS(-value)] \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {Transfer Transaction Item Does Not Exist}
			error INVALID_ITEM {core::history::transfer::get_item returned < 1 row}
		}

		set item [dict create]
		foreach {key colname} $CFG(summary_elements) {

			if {$CFG(escape_untranslated_entities)} {
				set value [core::xml::escape_entity -value [db_get_col $rs 0 $colname]]
			} else {
				set value [db_get_col $rs 0 $colname]
			}

			dict set item $key $value
		}

		core::db::rs_close -rs $rs

		set item [core::history::formatter::apply \
			-item             $item \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-detail_level     {SUMMARY}
		]

		return $item
	}

# Return a result set containing cr_dates given the parameters.
core::args::register \
	-proc_name core::history::transfer::get_pagination_rs \
	-clones core::history::pagination_result_handler \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -last_id       -mand 0 -check INT -default -1 -desc {ID of last item returned}] \
	] \
	-body {
		set fn {core::history::transfer::get_pagination_rs}

		# Load whether we should use any system_names given the request filters.
		set system_name_info [_get_system_names $ARGS(-filters)]

		# If a last_id is supplied, then use it. If not check for a system_name
		# filter, otherwise use the default query
		if {[lindex $system_name_info 0] == "Y"} {
			if {$ARGS(-last_id) != -1} {
				set query {core::history::transfer::get_transfer_pagination_system_name_last_id}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
			} else {
				set query {core::history::transfer::get_transfer_pagination_system_name}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
			}
			lappend sql_params {*}[lindex $system_name_info 1]
		} elseif {$ARGS(-last_id) != -1} {
			set query {core::history::transfer::get_transfer_pagination_last_id}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
		} else {
			set query {core::history::transfer::get_transfer_pagination}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
		}


		if {[catch {
			set rs [core::db::exec_qry \
				-name $query \
				-args $sql_params \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		return $rs
	}

# This proc is called after get_pagination_rs proc and returns all the history
# transfer items. Returns a list of items
core::args::register \
	-proc_name core::history::transfer::get_range \
	-clones core::history::range_handler \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check ASCII    -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -last_id       -mand 0 -check INT -default -1 -desc {ID of last item returned}] \
		[list -arg -ids           -mand 0 -check LIST -default {} -desc {List of pagination ids.}] \
	] \
	-body {
		variable CFG

		set fn {core::history::transfer::get_range}

		# Load whether we should use any system_names given the request filters.
		set system_name_info [_get_system_names $ARGS(-filters)]

		# If a last_id is supplied, then use it. If not check for a system_name
		# filter, otherwise use the default query
		if {[lindex $system_name_info 0] == "Y"} {
			if {$ARGS(-last_id) != -1} {
				set query {core::history::transfer::get_transfer_range_system_name_last_id}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)  $ARGS(-last_id)]
			} else {
				set query {core::history::transfer::get_transfer_range_system_name}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
			}
			# and add all the system_names which were loaded previously
			lappend sql_params {*}[lindex $system_name_info 1]
		} elseif {$ARGS(-last_id) != -1} {
			set query {core::history::transfer::get_transfer_range_last_id}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
		} else {
			set query {core::history::transfer::get_transfer_range}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
		}

		if {[catch {
			set rs [core::db::exec_qry \
				-name $query \
				-args $sql_params]
		} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		# We loop over the result set and we create a dict foreach row.
		# Each dict is formatted by a repsective proc if exists and the
		# new formatted item is appended to the result list.
		set nrows [db_get_nrows $rs]

		if {$ARGS(-page_size) < $nrows} {
			set page_last_row_idx $ARGS(-page_size)
		} else {
			set page_last_row_idx $nrows
		}

		set results [list]

		for {set i 0} {$i < $page_last_row_idx} {incr i} {
			set item [dict create]
			foreach {key colname} $CFG(summary_elements) {

				if {$CFG(escape_untranslated_entities)} {
					set value [core::xml::escape_entity -value [db_get_col $rs $i $colname]]
				} else {
					set value [db_get_col $rs $i $colname]
				}

				dict set item $key $value
			}

			set item [core::history::formatter::apply \
				-item            $item \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    $ARGS(-detail_level)]

			lappend results $item
		}

		core::db::rs_close -rs $rs

		return $results
	}

# Get the filters for system_name and system_group.
# If we are filtering by the group, get the applicable
# system_names out of the configuration and return them.
# Otherwise we use the system_name filter value as is.
# returns a list of:
# - [Y system_names]
# - [N ]
proc core::history::transfer::_get_system_names {system_filter} {
	variable CFG

	if {!$CFG(sys_host_exists)} {
		return [list N]
	}

	# Only get the system_names if tXsysHost exists
	set system_group [dict get $system_filter system_group]
	set system_name  [dict get $system_filter system_name]

	# if we have a group then use the configuration
	if {$system_group != "ALL"} {
		set system_names [list]
		foreach {cfg_group xsys} $CFG(external_system_groups) {
			if {$cfg_group == $system_group} {
				append system_names $xsys
				break
			}
		}
		return [list Y $system_names]
	# if we have just a name return that
	} elseif {$system_name != "ALL"} {
		return [list Y $system_name]
	# if no group or name is specified then ignore the filter
	} else {
		return [list N]
	}
}

# Prepare queries
proc core::history::transfer::_prep_queries {} {
	variable CFG

	set transferJoin ""
	if {$CFG(sys_host_exists)} {
		lappend transferJoin {inner join
		                           txsyshost h
		                       on
		                           (h.system_id = x.system_id)
		}
	}
	if {[core::db::schema::table_column_exists -table txsyssubxfer -column xfer_id]} {
		lappend transferJoin {left outer join
		                           txsyssubxfer xsx
		                       on
		                           (xsx.xfer_id = x.xfer_id)
		}
	}
	if {[core::db::schema::table_column_exists -table txsyssubcggame -column xsys_sub_id] &&
		[core::db::schema::table_column_exists -table txsyscggame -column cg_id]} {
		lappend transferJoin {left outer join
		                           (	txsyssubcggame scgg
		                            inner join
		                                txsyscggame cgg
	                                on
		                                (scgg.cg_id = cgg.cg_id))
		                       on
		                           (xsx.xsys_sub_id = scgg.xsys_sub_id)
		}
	}
	if {$CFG(sogei_info_exists)} {
		lappend transferJoin {left outer join
		                           tSOGEISubInfo ssi
		                       on
		                           (x.xfer_id = ssi.xfer_id)
		}
	}

	set joinClause [join $transferJoin]
	set columnsToAdd [subst {
    	[core::db::schema::add_sql_column -table tXSysXfer      -column channel      -alias {x.channel as source}                   -default {'' as source}],
    	[core::db::schema::add_sql_column -table tXSysXfer      -column free_amount  -alias {x.free_amount as free_amount}          -default {'' as free_amount}],
    	[core::db::schema::add_sql_column -table tXSysHost      -column system_id    -alias {h.system_id as system_id}              -default {'' as system_id}],
    	[core::db::schema::add_sql_column -table tXSysHost      -column name         -alias {h.name as system_name}                 -default {'' as system_name}],
    	[core::db::schema::add_sql_column -table tXSysSubXfer   -column held_amount  -alias {xsx.held_amount as held_amount}        -default {'' as held_amount}],
    	[core::db::schema::add_sql_column -table tXSysSubXfer   -column token_stake  -alias {xsx.token_stake as token_amount}       -default {'' as token_amount}],
    	[core::db::schema::add_sql_column -table tXSysCgGame    -column display_name -alias {cgg.display_name as game_display_name} -default {'' as game_display_name}],
    	[core::db::schema::add_sql_column -table tSOGEISubInfo  -column sogei_id     -alias {ssi.sogei_id as sogei_id}              -default {'' as sogei_id}],
    	[core::db::schema::add_sql_column -table tSOGEISubInfo  -column sogei_ts     -alias {ssi.sogei_ts as sogei_ts}              -default {'' as sogei_ts}],
    	[core::db::schema::add_sql_column -table tSOGEISubInfo  -column ext_wager    -alias {ssi.ext_wager as ext_wager}            -default {'' as ext_wager}],
    	[core::db::schema::add_sql_column -table tSOGEISubInfo  -column ext_returns  -alias {ssi.ext_returns as ext_returns}        -default {'' as ext_returns}]
	}]

	# For the system_name/group filters we need to
	# include in the query the tXSysHost.name check.
	set system_where_clause ""
	if {$CFG(sys_host_exists)} {
		# go through the system group config and get the longest
		# entry so we can form the query.
		set num_params 1
		foreach {cfg_group xsys} $CFG(external_system_groups) {
			set group_length [llength $xsys]
			if {$group_length > $num_params} {
				set num_params $group_length
			}
		}
		set system_where_clause [format "and h.name in (%s)" [join [lrepeat $num_params ?] ,]]
	}

	set sql [subst {
		select
			$CFG(get_range_directive)
			'TRANSFER' as group,
			x.amount,
			x.cr_date,
			x.desc,
			x.remote_acct,
			x.remote_action,
			x.remote_ref,
			x.remote_unique_id,
			x.xfer_id,
			$columnsToAdd
		from
			tXsysXfer x
			$joinClause
		where
			x.acct_id = ?
			and x.cr_date between ? and ?
			%s
		order by
			cr_date desc, xfer_id desc
	}]

	set sql_get_range [format $sql {}]
	set sql_get_range_last_id [format $sql {and x.xfer_id < ?}]
	set sql_get_range_system_name [format $sql $system_where_clause]
	set sql_get_range_system_name_last_id \
	          [format $sql "and x.xfer_id < ? $system_where_clause"]

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_range \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_range_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range_last_id

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_range_system_name \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range_system_name

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_range_system_name_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range_system_name_last_id

	set sql [subst {
		select $CFG(get_pagination_directive)
			first [expr {$CFG(max_page_size) +1}]
			x.cr_date
		from
			tXSysXfer x
			$joinClause
		where
			x.acct_id = ?
			and x.cr_date between ? and ?
			%s
		order by acct_id desc, cr_date desc
	}]

	set sql_pagination [format $sql {}]
	set sql_pagination_last_id [format $sql {and x.xfer_id < ?}]
	set sql_pagination_system_name [format $sql $system_where_clause]
	set sql_pagination_system_name_last_id \
	           [format $sql "and x.xfer_id < ? $system_where_clause"]

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_pagination \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_pagination_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination_last_id

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_pagination_system_name \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination_system_name

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_pagination_system_name_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination_system_name_last_id

	set sql [subst {
		select
			$CFG(get_item_directive)
			'TRANSFER' as group,
			x.amount,
			x.cr_date,
			x.desc,
			x.remote_acct,
			x.remote_action,
			x.remote_ref,
			x.remote_unique_id,
			x.xfer_id,
			$columnsToAdd
		from
			tXSysXfer x
			$joinClause
		where
			x.acct_id = ?
			and x.xfer_id = ?
	}]

	core::db::store_qry \
		-name  core::history::transfer::get_transfer_item \
		-force 0 \
		-cache 0 \
		-qry   $sql
}
