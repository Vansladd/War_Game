# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Lotterybet history
#
set pkg_version 1.0
package provide core::history::lotterybet $pkg_version

package require core::args  1.0
package require core::db 1.0
package require core::db::schema 1.0
package require core::history
package require core::xl 1.0

core::args::register_ns \
	-namespace          core::history::lotterybet \
	-version            $pkg_version \
	-dependent          [list core::args core::db core::db::schema core::history core::xl] \
	-desc               {Lotterybet history} \
	-docs               history/lotterybet.xml

namespace eval core::history::lotterybet {
	variable CFG
}

# Initialise the module
core::args::register \
	-proc_name core::history::lotterybet::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_LOTTERYBET_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_LOTTERYBET_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
		[list -arg -id_directive -mand 0 -check STRING \
			-default_cfg HIST_LOTTERYBET_ID_DIRECTIVE \
			-desc {Directive for id queries}] \
		[list -arg -subscription_directive -mand 0 -check STRING \
			-default_cfg HIST_LOTTERYBET_SUBSCRIPTION_DIRECTIVE \
			-desc {Directive for subscription queries}] \
	] \
	-body {
		variable CFG
		variable BET_COLS

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Lotterybet Module initialised with $formatted_name_value}
		}

		set CFG(max_page_size)   [core::history::get_config -name max_page_size]

		# identify which xgame table references the customer's account
		# if it's not tXGame (with alias "b") then it must be table with alias "s"
		set CFG(xgame_acct)      [core::db::schema::add_sql_column -table tXGameBet -column acct_id -alias {b.acct_id} -default {s.acct_id}]
		set CFG(xgame_acct_join) {}

		if {![core::db::schema::table_column_exists -table tXGameBet -column acct_id]} {
			set CFG(xgame_acct_join) {
				inner join
					tXGameSub s
				on
					(b.xgame_sub_id = s.xgame_sub_id)
			}
		}

		#tXGameDef join on tXGame
		set CFG(xgamedef_join) {}
		set CFG(xgamedef_name) {'' as name}
		
		if {[core::db::schema::table_column_exists -table txgamedef -column xgame_def_id] && [core::db::schema::table_column_exists -table txgame -column xgame_def_id]} {
			set CFG(xgamedef_join) {
				inner join
					tXGameDef d
				on
					(g.xgame_def_id = d.xgame_def_id)
			}
		} elseif {[core::db::schema::table_column_exists -table txgamedef -column sort]} {
			set CFG(xgamedef_join) {
				inner join
					tXGameDef d
				on
					(g.sort = d.sort)
			}
		}

		# if we have a join then lets set the name
		if {[llength $CFG(xgamedef_join)]} {
			set CFG(xgamedef_name) [core::db::schema::add_sql_column -table tXGameDef -column name -alias {d.name} -default {'' as name}]
		}

		if {[core::db::schema::table_column_exists -table tXGameDrawDesc -column desc]} {
			append CFG(xgamedef_name) ", dd.desc as draw_name"
			append CFG(xgamedef_join) {
				 inner join
					tXGameDrawDesc dd
				on
					(dd.desc_id      = g.draw_desc_id)
			}
		}

		# join to tXGameSyndicateBet if available
		set CFG(txgamesyndicatebet_join) {}
		set CFG(txgamesyndicatebet_parts) {'' as parts}

		if {[core::db::schema::table_column_exists -table txgamesyndicatebet -column xgame_bet_id]} {
			set CFG(txgamesyndicatebet_join) {
				left outer join
					tXGameSyndicateBet gs
				on
					(gs.xgame_bet_id = b.xgame_bet_id)
			}
			set CFG(txgamesyndicatebet_parts) [core::db::schema::add_sql_column -table tXGameSyndicateBet -column parts -alias {gs.parts} -default {'' as parts}]
		}

		# join to tXGameBetSlip if available
		set CFG(txgamebetslip_join) {}
		set CFG(txgamebetslip_receipt) {'' as betslip_receipt}

		if {[core::db::schema::table_column_exists -table txgamebetslip -column xgame_betslip_id]} {
			set CFG(txgamebetslip_join) {
				inner join
					tXGameBetSlip bs
				on
					(b.xgame_betslip_id = bs.xgame_betslip_id)
			}
			set CFG(txgamebetslip_receipt) [core::db::schema::add_sql_column -table tXGameBetSlip -column receipt -alias {bs.receipt as betslip_receipt} -default {'' as betslip_receipt}]
		}

		# join to tXGameSubSlip if available
		set CFG(txgamesubslip_join) {}
		set CFG(txgamesubslip_receipt) {'' as subslip_receipt}

		if {[core::db::schema::table_column_exists -table txgamesubslip -column xgame_subslip_id]} {
			set CFG(txgamesubslip_join) {
				left outer join
					tXGameSubSlip ss
				on
					(s.xgame_subslip_id = ss.xgame_subslip_id)
			}
			set CFG(txgamesubslip_receipt) [core::db::schema::add_sql_column -table tXGameSubSlip -column receipt -alias {ss.receipt as subslip_receipt} -default {'' as subslip_receipt}]
		}

		# Filter name, filter type, default.
		set filters [list \
			[list settled         HIST_SETTLED  ALL] \
			[list subscription_id UINT          -1] \
			[list date_field      ASCII         cr_date] \
		]

		core::history::add_combinable_group \
			-group                          LOTTERYBET \
			-detail_levels                  {SUMMARY DETAILED} \
			-j_op_ref_keys                  {XGAM} \
			-page_handler                   core::history::lotterybet::get_page \
			-range_handler                  core::history::lotterybet::get_range \
			-pagination_result_handler      core::history::lotterybet::get_pagination_rs \
			-filters                        $filters

		# Prepare queries
		core::history::lotterybet::_prep_queries

		core::history::add_item_handler \
			-group            LOTTERYBET \
			-item_handler     core::history::lotterybet::get_item_by_id \
			-key              ID
	}

#
# Interface that retrieves extra information (possibly customer specific)
#
core::args::register \
	-interface core::history::lotterybet::post_handler \
	-mand_impl 0 \
	-desc  {Add extra information to bet item} \
	-args [list \
			[list -arg -item         -mand 1 -check ANY         -desc {Item requiring extra information}] \
			[list -arg -detail_level -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
	]

# Get a page of bet items
core::args::register \
	-proc_name core::history::lotterybet::get_page \
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

			set max_date [db_get_col $rs 0 $date_field]
			set min_date [db_get_col $rs $page_last_row_idx $date_field]

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

# Get a single lotterybet by id.
core::args::register \
	-proc_name core::history::lotterybet::get_item_by_id \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check UINT  -desc {Bet ID}] \
	] \
	-body {
		set rs [core::db::exec_qry \
			-name core::history::lotterybet::id \
			-args [list $ARGS(-value) $ARGS(-acct_id)]]

		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {Lotterybet Bet Item Does Not Exist}
			error INVALID_ITEM {core::history::lotterybet::get_item_by_id returned < 1 row}
		}

		set items [core::history::lotterybet::build_formatted_items \
			-rs           $rs \
			-acct_id      $ARGS(-acct_id) \
			-lang         $ARGS(-lang) \
			-detail_level {DETAILED} \
			-num_items    1]

		set item [lindex $items 0]

		core::db::rs_close -rs $rs

		return $item
	}

# Get cr_date values for one page of bet items
core::args::register \
	-proc_name core::history::lotterybet::get_pagination_rs \
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
		set fn {core::history::lotterybet::get_pagination_rs}

		set query [core::history::lotterybet::get_qry_args \
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
	-proc_name core::history::lotterybet::get_range \
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
		[list -arg -ids           -mand 0 -check LIST -default {} -desc {List of pagination ids}] \
	] \
	-body {
		variable CFG

		set fn {core::history::lotterybet::get_range}

		set query [core::history::lotterybet::get_qry_args \
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

		set nrows [db_get_nrows $rs]
		if {$nrows > $ARGS(-page_size)} {
			set items_required $ARGS(-page_size)
		} else {
			set items_required $nrows
		}

		if {$ARGS(-detail_level) == "DETAILED"} {
			# Retrieve list of bet ids and fetch a more detailed result set
			set ids [list]
			for {set i 0} {$i < $items_required} {incr i} {
				lappend ids [db_get_col $rs $i id]
			}
			set ids [core::util::lpad -list $ids -size $CFG(max_page_size) -padding -1]
			core::db::rs_close -rs $rs

			if {[catch {set rs [core::db::exec_qry \
				-name core::history::lotterybet::ids \
				-args [list {*}$ids $ARGS(-acct_id)] \
			]} err]} {
				core::log::write ERROR {$fn Error executing query: $err}
				error SERVER_ERROR $::errorInfo
			}

			# Make sure our detailed result set is sorted
			# in the same order as our original query
			set date_filter [dict get $ARGS(-filters) date_field]
			db_sort [list $date_filter string descending id numeric descending] $rs
		}

		# We loop over the result set and we create a dict for each bet
		# Each dict is formatted by a respective proc if it exists
		set results [core::history::lotterybet::build_formatted_items \
			-rs           $rs \
			-acct_id      $ARGS(-acct_id) \
			-lang         $ARGS(-lang) \
			-detail_level $ARGS(-detail_level) \
			-num_items    $items_required]

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
proc core::history::lotterybet::_prep_queries {} {
	variable CFG

	# Prepare cr_date date filters.
	foreach has_sub_id {Y N} {
		foreach first_page {Y N} {
			foreach settled {Y N ALL} {
				foreach query_type {pagination range} {
					core::history::lotterybet::prep_qry \
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
				core::history::lotterybet::prep_qry \
					-query_type     $query_type \
					-first_page     $first_page \
					-has_sub_id     $has_sub_id \
					-settled        "Y" \
					-date_filter    settled_at
			}
		}
	}

	# Detail queries for xgame_bet_id.
	set query [subst {
		select
			%s
			a.ccy_code,
			ball.ball_name,
			ball.ball_no,
			b.bet_type,
			b.cr_date,
			b.num_lines,
			b.num_selns,
			b.picks,
			b.refund,
			b.settled,
			b.settled_at,
			b.stake,
			b.stake_per_line,
			b.token_value,
			b.winnings,
			b.xgame_bet_id as id,
			b.xgame_sub_id,
			[core::db::schema::add_sql_column -table tXGameBet -column receipt   -alias {b.receipt}   -default {'' as receipt}],
			[core::db::schema::add_sql_column -table tXGameBet -column auto_pick -alias {b.auto_pick} -default {'' as auto_pick}],
			%s,
			g.draw_at,
			g.results,
			g.xgame_id,
			s.cr_date as sub_cr_date,
			s.num_subs,
			[core::db::schema::add_sql_column -table tXGameSub  -column outstanding_subs -alias {s.outstanding_subs}             -default {'' as outstanding_subs}],
			[core::db::schema::add_sql_column -table tXGameSub  -column receipt          -alias {s.receipt as xgame_sub_receipt} -default {'' as xgame_sub_receipt}],
			s.source,
			s.stake_per_bet,
			t.bet_name,
			%s,
			%s,
			%s
		from
			tXGameBet b
			inner join tXGame g on (b.xgame_id = g.xgame_id)
			%s
			%s
			%s
			inner join tXGameSub s on (b.xgame_sub_id = s.xgame_sub_id)
			%s
			inner join tXGameBetType t on (b.bet_type = t.bet_type)
			inner join tAcct a on (%s = a.acct_id)
			left join tXGameBall ball on (g.xgame_id = ball.xgame_id)
		where
			%s
	}]

	core::db::store_qry -name core::history::lotterybet::id \
		-qry [format $query \
			$CFG(id_directive) \
			$CFG(xgamedef_name) \
			$CFG(txgamesyndicatebet_parts) \
			$CFG(txgamebetslip_receipt) \
			$CFG(txgamesubslip_receipt) \
			$CFG(xgamedef_join) \
			$CFG(txgamesyndicatebet_join) \
			$CFG(txgamebetslip_join) \
			$CFG(txgamesubslip_join) \
			$CFG(xgame_acct) \
			"b.xgame_bet_id = ? and $CFG(xgame_acct) = ?"] \
		-cache 0

	# As above for multiple xgame_bet_ids
	set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]

	core::db::store_qry -name core::history::lotterybet::ids \
		-qry [format $query \
			$CFG(id_directive) \
			$CFG(xgamedef_name) \
			$CFG(txgamesyndicatebet_parts) \
			$CFG(txgamebetslip_receipt) \
			$CFG(txgamesubslip_receipt) \
			$CFG(xgamedef_join) \
			$CFG(txgamesyndicatebet_join) \
			$CFG(txgamebetslip_join) \
			$CFG(txgamesubslip_join) \
			$CFG(xgame_acct) \
			"b.xgame_bet_id in ($ph) and $CFG(xgame_acct) = ?"] \
		-cache 0
}

core::args::register \
	-proc_name core::history::lotterybet::prep_qry \
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
				dict set where -first_page N {b.xgame_bet_id < ?}
			}
				settled_at  {
					if {$ARGS(-query_type) == "pagination" } {
						dict set where -first_page N \
							{((b.settled_at = ? and b.xgame_bet_id < ?) or (b.settled_at < ?))}
					} else {
						dict set where -first_page N \
							{((b.settled_at = (select settled_at from txgamebet where xgame_bet_id = ?) and b.xgame_bet_id < ?) or \
								(b.settled_at < (select settled_at from txgamebet where xgame_bet_id = ?)))}
					}
				}
		}

		# Where clause based on value of has_sub_id.
		dict set where -has_sub_id Y  {b.xgame_sub_id = ?}

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
						b.$ARGS(-date_filter),
						b.xgame_bet_id as id
					from
						tXGameBet b
						$CFG(xgame_acct_join)
					where
						$CFG(xgame_acct) = ?
						and $wheres
					order by
						$CFG(xgame_acct) desc, b.$ARGS(-date_filter) desc, b.xgame_bet_id desc
				}]
			}
			range {
				# Range queries.
				set sql [subst {
					select
						$CFG(get_range_directive)
						a.ccy_code,
						b.bet_type,
						b.cr_date,
						b.num_lines,
						b.num_selns,
						b.refund,
						b.settled,
						b.settled_at,
						b.stake,
						b.stake_per_line,
						b.token_value,
						b.winnings,
						b.xgame_bet_id as id,
						b.xgame_sub_id,
						$CFG(xgamedef_name),
						s.source,
						t.bet_name
					from
						tXGameBet b
						inner join tXGame g on (b.xgame_id = g.xgame_id)
						$CFG(xgamedef_join)
						inner join tXGameSub s on (b.xgame_sub_id = s.xgame_sub_id)
						inner join tXGameBetType t on (b.bet_type = t.bet_type)
						inner join tAcct a on ($CFG(xgame_acct) = a.acct_id)
					where
						$CFG(xgame_acct) = ?
						and $wheres
					order by
						b.$ARGS(-date_filter) desc, b.xgame_bet_id desc
				}]
			}
			default {
				error "Invalid query type: $ARGS(query_type)"
			}
		}

		set name [format "core::history::lotterybet::%s.%s.%s.%s.%s" \
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
	-proc_name core::history::lotterybet::get_qry_args \
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
				settled_at  {
					if {$ARGS(-query_type) == "pagination"} {
						lappend sql_params $ARGS(-max_date) $ARGS(-last_id) $ARGS(-max_date)
					} else {
						lappend sql_params $ARGS(-last_id) $ARGS(-last_id) $ARGS(-last_id)
					}
				}
			}
		}

		if {$has_sub_id == "Y"} {
			lappend sql_params $sub_id
		}

		if {$date_filter == {settled_at} && $settled != {Y}} {
			core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
			error INVALID_FILTER_COMBI
		}

		set name [format "core::history::lotterybet::%s.%s.%s.%s.%s" \
			$ARGS(-query_type) \
			$first_page \
			$has_sub_id \
			$settled \
			$date_filter]

		return [dict create -name $name -args $sql_params]
	}

# Extract items from result set, create a dictionary for each one and format it.
core::args::register \
	-proc_name core::history::lotterybet::build_formatted_items \
	-is_public 0 \
	-args [list \
		[list -arg -rs           -mand 1 -check NONE            -desc {The result set to parse}] \
		[list -arg -acct_id      -mand 1 -check UINT            -desc {Account id}] \
		[list -arg -lang         -mand 1 -check ASCII           -desc {Language code for customer}] \
		[list -arg -detail_level -mand 1 -check ASCII           -desc {Detail level of page items}] \
		[list -arg -num_items    -mand 0 -check UINT -default 0 -desc {Number of items to build}] \
	] \
	-body {
		set colnames [db_get_colnames $ARGS(-rs)]

		set ball_set [dict create]
		set item [dict create]

		if {$ARGS(-detail_level) == "DETAILED"} {
			# Preparse the detailed result set to extract the ball set for each game
			for {set i 0} {$i < [db_get_nrows $ARGS(-rs)]} {incr i} {
				set xgame_id [db_get_col $ARGS(-rs) $i xgame_id]

				dict set ball_set $xgame_id \
					ball [db_get_col $ARGS(-rs) $i ball_no] \
					name [db_get_col $ARGS(-rs) $i ball_name]
			}
		}

		# Capture item information into dict
		for {set i 0} {$i < [db_get_nrows $ARGS(-rs)]} {incr i} {
			set id [db_get_col $ARGS(-rs) $i id]

			if {[dict exists $item $id]} {
				continue
			}

			dict set item $id [dict create group LOTTERYBET]
			foreach col $colnames {
				dict set item $id $col [db_get_col $ARGS(-rs) $i $col]
			}

			if {$ARGS(-detail_level) != "DETAILED"} {
				continue
			}

			# In addition to the pipe separated picks and results, augment
			# the item dict with a list of results and a list of picks.
			set xgame_id [db_get_col $ARGS(-rs) $i xgame_id]

			set pick_list [list]
			foreach ball_no [split [dict get $item $id picks] "|"] {
				if {[dict exists $ball_set $xgame_id ball $ball_no name]} {
					set ball_name [dict get $ball_set $xgame_id ball $ball_no name]
				} else {
					set ball_name ""
				}

				lappend pick_list [list ball_no $ball_no ball_name $ball_name]
			}

			dict set item $id pick_list $pick_list

			set result_list [list]
			foreach ball_no [split [dict get $item $id results] "|"] {
				if {[dict exists $ball_set $xgame_id ball $ball_no name]} {
					set ball_name [dict get $ball_set $xgame_id ball $ball_no name]
				} else {
					set ball_name ""
				}

				lappend result_list [list ball_no $ball_no ball_name $ball_name]
			}

			dict set item $id result_list $result_list

			if {[core::args::is_implemented -interface core::history::lotterybet::post_handler]} {
				dict set item $id \
					[core::history::lotterybet::post_handler \
						-item [dict get $item $id] \
						-detail_level $ARGS(-detail_level)]
			}

		}

		# Format items
		set items [list]
		foreach id [dict keys $item] {
			lappend items [core::history::formatter::apply \
				-item         [dict get $item $id] \
				-acct_id      $ARGS(-acct_id) \
				-lang         $ARGS(-lang) \
				-detail_level $ARGS(-detail_level)]

			if {$ARGS(-num_items) > 0 && [llength $items] >= $ARGS(-num_items)} {
				# We've built enough items - stop processing
				break
			}
		}

		return $items
	}
