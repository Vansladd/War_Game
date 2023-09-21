# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# footballpoolbet history
#
set pkg_version 1.0
package provide core::history::footballpoolbet $pkg_version

package require core::args  1.0
package require core::db 1.0
package require core::db::schema 1.0
package require core::history
package require core::xl 1.0

core::args::register_ns \
	-namespace          core::history::footballpoolbet \
	-version            $pkg_version \
	-dependent          [list core::args core::db core::db::schema core::history core::xl] \
	-desc               {footballpoolbet history} \
	-docs               history/footballpoolbet.xml

namespace eval core::history::footballpoolbet {
	variable CFG
}

# Initialise the module
core::args::register \
	-proc_name core::history::footballpoolbet::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_FOOTBALLPOOLBET_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_FOOTBALLPOOLBET_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
		[list -arg -id_directive -mand 0 -check STRING \
			-default_cfg HIST_FOOTBALLPOOLBET_ID_DIRECTIVE \
			-desc {Directive for id queries}] \
		[list -arg -subscription_directive -mand 0 -check STRING \
			-default_cfg HIST_FOOTBALLPOOLBET_SUBSCRIPTION_DIRECTIVE \
			-desc {Directive for subscription queries}] \
	] \
	-body {
		variable CFG
		variable BET_COLS

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Footballpoolbet Module initialised with $formatted_name_value}
		}

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		# Filter name, filter type, default.
		set filters [list \
			[list settled         HIST_SETTLED  ALL] \
			[list subscription_id UINT          -1] \
			[list date_field      ASCII         cr_date] \
		]

		core::history::add_combinable_group \
			-group                          FOOTBALLPOOLBET \
			-detail_levels                  {SUMMARY DETAILED} \
			-j_op_ref_keys                  {SXSB} \
			-page_handler                   core::history::footballpoolbet::get_page \
			-range_handler                  core::history::footballpoolbet::get_range \
			-pagination_result_handler      core::history::footballpoolbet::get_pagination_rs \
			-filters                        $filters

		# Prepare queries
		core::history::footballpoolbet::_prep_queries

		core::history::add_item_handler \
			-group            FOOTBALLPOOLBET \
			-item_handler     core::history::footballpoolbet::get_item_by_id \
			-key              ID
	}

# Get a page of bet items
core::args::register \
	-proc_name core::history::footballpoolbet::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -group         -mand 1 -check ASCII    -desc {Group name}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check ASCII    -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check INT -default -1 -desc {ID of last item returned}] \
	] \
	-body {
		variable CFG

		set date_field [dict get $ARGS(-filters) date_field]

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

			if {$more_pages} {
				set new_boundary [dict get [lindex $results end] id]
				set new_max_date [dict get [lindex $results end] $date_field]
			}
		}

		core::db::rs_close -rs $rs

		return [list $new_boundary $new_max_date $results]
	}

# Get a single footballpoolbet by id.
core::args::register \
	-proc_name core::history::footballpoolbet::get_item_by_id \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check UINT  -desc {Bet ID}] \
	] \
	-body {
		set rs [core::db::exec_qry -name core::history::footballpoolbet::id \
			-args [list $ARGS(-value) $ARGS(-acct_id)]]


		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {footballpoolbet Bet Item Does Not Exist}
			error INVALID_ITEM {core::history::footballpoolbet::get_item_by_id returned < 1 row}
		}

		set item [dict create group FOOTBALLPOOLBET]
		set colnames [db_get_colnames $rs]

		foreach col $colnames {
			dict set item $col [db_get_col $rs 0 $col]
		}

		# Multiple rows may be returned due to an outer join to tSAXGameBall.
		dict create balls [list]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			dict set balls [db_get_col $rs $i ball_no] \
				name [db_get_col $rs $i ball_name]
		}

		# In addition to the pipe separated picks and results, augment the item
		# dict with a list of results and a list of picks.
		set result_list [list]
		foreach ball_no [split [dict get $item results] "|"] {
			if {[dict exists $balls $ball_no]} {
				set ball_name [dict get $balls $ball_no name]
			} else {
				set ball_name ""
			}

			lappend result_list [list \
				ball_no $ball_no ball_name $ball_name]
		}

		dict set item result_list $result_list

		# Do the same for picks.
		set pick_list [list]
		foreach ball_no [split [dict get $item picks] "|"] {
			if {[dict exists $balls $ball_no]} {
				set ball_name [dict get $balls $ball_no name]
			} else {
				set ball_name ""
			}

			lappend pick_list [list \
				ball_no $ball_no ball_name $ball_name]
		}

		dict set item pick_list $pick_list

		core::db::rs_close -rs $rs

		set item [core::history::formatter::apply \
			-item             $item \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-detail_level     {DETAILED} \
		]

		core::db::rs_close -rs $rs

		return $item
	}

# Get cr_date values for one page of bet items
core::args::register \
	-proc_name core::history::footballpoolbet::get_pagination_rs \
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
		set fn {core::history::footballpoolbet::get_pagination_rs}

		set query [core::history::footballpoolbet::get_qry_args \
			-query_type pagination \
			-acct_id    $ARGS(-acct_id) \
			-last_id    $ARGS(-last_id) \
			-min_date   $ARGS(-min_date) \
			-max_date   $ARGS(-max_date) \
			-filters    $ARGS(-filters)]

		if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
			core::log::write ERROR {$fn Error executing query: $err}
			error SERVER_ERROR $::errorInfo
		}

		return $rs
	}

# Get bet items between a date range
# This should be called after get_pagination_rs with the date range reduced
# so that the expected number of rows scanned is equal to the max page size.
#
# The number of rows may be slightly more in the case where multiple
# bets were placed at max_date, so any extra must be removed in the code.
core::args::register \
	-proc_name core::history::footballpoolbet::get_range \
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
	] \
	-body {
		set fn {core::history::footballpoolbet::get_range}

		set query [core::history::footballpoolbet::get_qry_args \
			-query_type range \
			-acct_id    $ARGS(-acct_id) \
			-last_id    $ARGS(-last_id) \
			-min_date   $ARGS(-min_date) \
			-max_date   $ARGS(-max_date) \
			-filters    $ARGS(-filters)]

		if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
			core::log::write ERROR {$fn Error executing query: $err}
			error SERVER_ERROR $::errorInfo
		}

		# We loop over the result set and we create a dict foreach row
		# Each dict is formatted by a repsective proc if exists and the
		# new formatted item is appended to the result list
		set results [list]
		set colnames [db_get_colnames $rs]

		set nrows [db_get_nrows $rs]
		if {$nrows > $ARGS(-page_size)} {
			set rows_required $ARGS(-page_size)
		} else {
			set rows_required $nrows
		}

		set current_id 0
		for {set i 0} {$i < $rows_required} {incr i} {
			set item [dict create group FOOTBALLPOOLBET]
			foreach col $colnames {
				dict set item $col [db_get_col $rs $i $col]
			}

			set item [core::history::formatter::apply \
				-item            $item \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    $ARGS(-detail_level)
			]

			lappend results $item
		}

		core::db::rs_close -rs $rs

		return $results
	}

#
# Private procedures
#

# Prepare all queries
#
# 2 queries must be prepared for each value of the settled filter.
# (pagination query + main query with and without last id)
# This results in 12 possible queries which may be used by get_page.
proc core::history::footballpoolbet::_prep_queries {} {
	variable CFG

	# Prepare cr_date date filters.
	foreach has_sub_id {Y N} {
		foreach first_page {Y N} {
			foreach settled {Y N ALL} {
				foreach query_type {pagination range} {
					core::history::footballpoolbet::prep_qry \
						-query_type    $query_type \
						-first_page    $first_page \
						-has_sub_id    $has_sub_id \
						-settled       $settled \
						-date_filter   cr_date
				}
			}
		}
	}

	# Prepare settled_at date filters (obviously settled must be 'Y').
	foreach first_page {Y N} {
		foreach has_sub_id {Y N} {
			foreach query_type {pagination range} {
				core::history::footballpoolbet::prep_qry \
					-query_type     $query_type \
					-first_page     $first_page \
					-has_sub_id     $has_sub_id \
					-settled        "Y" \
					-date_filter    settled_at
			}
		}
	}

	# Detail queries for saxgame_bet_id.
	set query [subst {
		select
			%s
			a.ccy_code,
			ball.ball_name,
			ball.ball_no,
			b.cr_date,
			b.num_lines,
			b.num_selns,
			b.picks,
			b.refund,
			b.saxgame_bet_id as id,
			b.saxgame_sub_id,
			b.settled,
			b.settled_at,
			b.stake,
			b.stake_per_line,
			b.token_value,
			b.winnings,
			d.name,
			g.draw_at,
			g.results,
			g.saxgame_id,
			s.cr_date as sub_cr_date,
			s.num_subs,
			s.source,
			s.stake_per_bet
		from
			tSAXGameBet b
			inner join tSAXGame g on (b.saxgame_id = g.saxgame_id)
			inner join tSAXGameSub s on (b.saxgame_sub_id = s.saxgame_sub_id)
			inner join tSAXGameDef d on (g.sort = d.sort)
			inner join tAcct a on (s.acct_id = a.acct_id)
			left join tSAXGameBall ball on (g.saxgame_id = ball.saxgame_id)
		where
			%s
			and s.acct_id = ?
	}]

	core::db::store_qry -name core::history::footballpoolbet::id \
		-qry [format $query $CFG(id_directive) {b.saxgame_bet_id = ?}] \
		-cache 0
}

core::args::register \
	-proc_name core::history::footballpoolbet::prep_qry \
	-is_public 0 \
	-args [list \
		[list -arg -query_type     -mand 1 -check {ENUM -args {range pagination}} -desc {The basic purpose of the query}] \
		[list -arg -first_page     -mand 1 -check {ENUM -args {Y N}} -desc {Whether this is the first page}] \
		[list -arg -has_sub_id     -mand 1 -check {ENUM -args {Y N}} -desc {Whether the query filters by subscription_id}] \
		[list -arg -settled        -mand 1 -check {ENUM -args {Y N ALL}} -desc {Settled filter}] \
		[list -arg -date_filter    -mand 1 -check {ENUM -args {cr_date settled_at}} -desc {Type of date filter}] \
	] \
	-body {
		variable CFG

		# Note that the ordering of inserting parameters into the 'where' dict
		# is important and must be mirrored when executing the query.

		# Where clauses based on value of date_filter.
		dict set where -date_filter cr_date       {b.cr_date between ? and ?}
		dict set where -date_filter settled_at    {b.settled_at between ? and ?}

		# Where clauses based on value of settled.
		dict set where -settled Y {b.settled = 'Y'}
		dict set where -settled N {b.settled = 'N'}

		switch -- $ARGS(-date_filter) {
			cr_date     {
				dict set where -first_page N {b.saxgame_bet_id < ?}
			}
			settled_at  {
				dict set where -first_page N \
					{b.settled_at < ? or (b.settled_at = ? and b.saxgame_bet_id < ?)}
			}
		}

		# Where clause based on value of has_sub_id.
		dict set where -has_sub_id Y  {b.saxgame_sub_id = ?}

		# Build a list of where clauses.
		# If a key doesn't exist, then the clause will not be added.
		set where_list [list]
		foreach key [dict keys $where] {
			if {[dict exists $where $key $ARGS($key)]} {
				lappend where_list [dict get $where $key $ARGS($key)]
			}
		}
		set wheres [join $where_list " and "]

		switch -- $ARGS(-query_type) {
			pagination {
				set sql [subst {
					select
						$CFG(get_pagination_directive)
						first [expr {$CFG(max_page_size) +1}]
						b.cr_date
					from
						tSAXGameBet b
						inner join tSAXGameSub s on (b.saxgame_sub_id = s.saxgame_sub_id)
					where
						s.acct_id = ?
						and $wheres
					order by
						acct_id desc, b.$ARGS(-date_filter) desc
				}]
			}
			range {
				# Range queries.
				set sql [subst {
					select
						$CFG(get_range_directive)
						a.ccy_code,
						b.cr_date,
						b.num_lines,
						b.num_selns,
						b.refund,
						b.saxgame_bet_id as id,
						b.saxgame_sub_id,
						b.settled,
						b.settled_at,
						b.stake,
						b.stake_per_line,
						b.token_value,
						b.winnings,
						d.name,
						s.source
					from
						tSAXGameBet b
						inner join tSAXGame g on (b.saxgame_id = g.saxgame_id)
						inner join tSAXGameSub s on (b.saxgame_sub_id = s.saxgame_sub_id)
						inner join tSAXGameDef d on (g.sort = d.sort)
						inner join tAcct a on (s.acct_id = a.acct_id)
					where
						s.acct_id = ?
						and $wheres
					order by
						b.$ARGS(-date_filter) desc, b.saxgame_bet_id desc
				}]
			}
			default {
				error "Invalid query type: $ARGS(query_type)"
			}
		}

		set name [format "core::history::footballpoolbet::%s.%s.%s.%s.%s" \
			$ARGS(-query_type) \
			$ARGS(-first_page) \
			$ARGS(-has_sub_id) \
			$ARGS(-settled) \
			$ARGS(-date_filter)]

		core::db::store_qry -cache 0 -name $name -qry $sql
	}

# Validate the inputs and generate arguments to the query.
# Note that this is tighly coupled to the prep_qry proc.
core::args::register \
	-proc_name core::history::footballpoolbet::get_qry_args \
	-is_public 0 \
	-args [list \
		[list -arg -query_type -mand 1 -check {ENUM -args {range pagination}} -desc {The basic purpose of the query}] \
		[list -arg -acct_id    -mand 1 -check UINT            -desc {Account id}] \
		[list -arg -last_id    -mand 0 -check INT -default -1 -desc {ID of last item returned}] \
		[list -arg -min_date   -mand 1 -check DATETIME        -desc {Earliest date}] \
		[list -arg -max_date   -mand 1 -check DATETIME        -desc {Latest date}] \
		[list -arg -filters    -mand 1 -check ANY             -desc {Dict of filter names/filter values}] \
	] \
	-body {
		set sql_params [list]
		set hierarchy_filter {ALL}

		set first_page     [expr {($ARGS(-last_id) == -1) ? {Y} : {N}}]
		set settled        [dict get $ARGS(-filters) settled]
		set date_filter    [dict get $ARGS(-filters) date_field]
		set sub_id         [dict get $ARGS(-filters) subscription_id]
		set has_sub_id     [expr {($sub_id == -1) ? {N} : {Y}}]

		lappend sql_params $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)

		if {$first_page == "N"} {
			switch -- $date_filter {
				cr_date     { lappend sql_params $ARGS(-last_id) }
				settled_at  { lappend sql_params $ARGS(-date_to) $ARGS(-date_to) $ARGS(-last_id) }
			}
		}

		if {$has_sub_id == "Y"} {
			lappend sql_params $sub_id
		}

		if {$date_filter == {settled_at} && $settled != {Y}} {
			core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
			error INVALID_FILTER_COMBI
		}

		set name [format "core::history::footballpoolbet::%s.%s.%s.%s.%s" \
			$ARGS(-query_type) \
			$first_page \
			$has_sub_id \
			$settled \
			$date_filter]

		return [dict create -name $name -args $sql_params]
	}
