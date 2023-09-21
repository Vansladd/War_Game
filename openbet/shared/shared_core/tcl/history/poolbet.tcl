# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Poolbet history
#
set pkg_version 1.0
package provide core::history::poolbet $pkg_version

package require core::args  1.0
package require core::db 1.0
package require core::db::schema 1.0
package require core::history
package require core::xl 1.0

core::args::register_ns \
	-namespace     core::history::poolbet \
	-version       $pkg_version \
	-dependent     [list core::args core::db core::db::schema core::history core::xl] \
	-desc          {Poolbet history} \
	-docs          history/poolbet.xml

namespace eval core::history::poolbet {
	variable CFG
	variable BET_COLS
	variable LEG_COLS
	variable PART_COLS
}

# Initialise the module
core::args::register \
	-proc_name core::history::poolbet::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
		[list -arg -get_pagination_directive_unsettled -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_PAGINATION_U_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries using unsettled bets}] \
		[list -arg -get_range_directive_unsettled -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_RANGE_U_DIRECTIVE \
			-desc {Directive for get_range queries using unsettled bets}] \
		[list -arg -get_pagination_directive_settled -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_PAGINATION_S_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries using settled bets}] \
		[list -arg -get_range_directive_settled -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_GET_RANGE_S_DIRECTIVE \
			-desc {Directive for get_range queries using settled bets}] \
		[list -arg -id_directive -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_ID_DIRECTIVE \
			-desc {Directive for id queries}] \
		[list -arg -receipt_directive -mand 0 -check STRING \
			-default_cfg HIST_POOLBET_RECEIPT_DIRECTIVE \
			-desc {Directive for receipt queries}] \
		[list -arg -restricted_filter_max_days -mand 0 -default 1 -check UINT -desc {Maximum days the date range must span when using hierarchy filters.}] \
		[list -arg -escape_untranslated_entities -mand 0 -default_cfg HIST_ESCAPE_UNTRANSLATED_ENTITIES -default 0 -check BOOL -desc {Escape Untranslated Entities for XML/HTML Printing}] \
	] \
	-body {
		variable CFG
		variable BET_COLS
		variable LEG_COLS
		variable PART_COLS

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Poolbet Module initialised with $formatted_name_value}
		}

		set CFG(max_page_size)        [core::history::get_config -name max_page_size]
		set CFG(settled_at_filtering) [core::history::get_config -name settled_at_filtering]

		set filters [list \
			[list settled     HIST_SETTLED    ALL] \
			[list ev_class_id ASCII           ALL] \
			[list date_field  HIST_DATE_FIELD cr_date] \
		]

		if {[core::db::schema::table_column_exists -table tEvCategory -column ev_category_id]} {
			lappend filters [list ev_category_id  ASCII ALL]
		}

		core::history::add_combinable_group \
			-group                           POOLBET \
			-detail_levels                   {SUMMARY DETAILED} \
			-j_op_ref_keys                   {TPB} \
			-page_handler                    core::history::poolbet::get_page \
			-range_handler                   core::history::poolbet::get_range \
			-pagination_result_handler       core::history::poolbet::get_pagination_rs \
			-filters                         $filters

		# Prepare queries
		core::history::poolbet::_prep_queries

		core::history::add_item_handler \
			-group            POOLBET \
			-item_handler     core::history::poolbet::get_item_by_id \
			-key              ID

		core::history::add_item_handler \
			-group            POOLBET \
			-item_handler     core::history::poolbet::get_item_by_receipt \
			-key              RECEIPT

		# Set format for detailed bet items
		set BET_COLS [list \
			id                  0  \
			cr_date             0  \
			pool_name           1  \
			pool_type_id        0  \
			bet_type            0  \
			stake               0  \
			ccy_stake           0  \
			ccy_stake_per_line  0  \
			status              0  \
			settled             0  \
			settled_at          0  \
			winnings            0  \
			refund              0  \
			receipt             0  \
			num_legs            0  \
			num_lines           0  \
			num_selns           0  \
			source              0  \
			pool_ccy            0  \
			\
			num_lines_win       0  \
			num_lines_lose      0  \
			num_lines_void      0  \
			settle_info         1  \
			leg_type            0 \
			pool_source         0  \
		]

		set LEG_COLS [list \
			leg_no      0 \
			ev_name     1 \
			track       0 \
			start_time  0 \
			race_number 0 \
		]

		set PART_COLS [list \
			part_no    0 \
			oc_id      0 \
			oc_name    1 \
			oc_result  0 \
			oc_place   0 \
			runner_num 0 \
		]
	}

# Get config
core::args::register \
	-proc_name core::history::poolbet::get_config \
	-is_public 0 \
	-args [list \
		[list -arg -name    -mand 1 -check ASCII -desc {Config name}] \
		[list -arg -default -mand 0 -default {} -check ANY -desc {Default value}] \
	]
proc core::history::poolbet::get_config args {
	variable CFG
	array set ARGS [core::args::check core::history::poolbet::get_config {*}$args]

	if {![info exists CFG($ARGS(-name))]} {
		return $ARGS(-default)
	}

	return $CFG($ARGS(-name))
}

# Get a page of bet items
core::args::register \
	-proc_name core::history::poolbet::get_page \
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
		set date_field [dict get $ARGS(-filters) date_field]

		if {[is_restricted $ARGS(-filters)]} {
			# These filters should not be used to retrieve more than (by default) a days worth of bets.
			# In the worst case scenario where there are no matching bets, all of the customer's bets
			# that fall within the date range will be scanned.
			set max_days [get_config -name restricted_filter_max_days]
			core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date) -max_days $max_days
		} else {
			core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date)
		}

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

			set max_date [db_get_col $rs 0 date]
			set min_date [db_get_col $rs $page_last_row_idx date]
			
			set id_list [db_get_col_list $rs -name id]
			
			set results [get_range \
				-acct_id         $ARGS(-acct_id) \
				-last_id         $ARGS(-page_boundary) \
				-lang            $ARGS(-lang) \
				-min_date        $min_date \
				-max_date        $max_date \
				-detail_level    $ARGS(-detail_level)\
				-page_size       $ARGS(-page_size) \
				-filters         $ARGS(-filters) \
				-ids             $id_list]

			if {$more_pages} {
				set new_boundary [dict get [lindex $results end] id]
				set new_max_date [dict get [lindex $results end] $date_field]
			}
		}

		core::db::rs_close -rs $rs

		return [list $new_boundary $new_max_date $results]
	}

# Get a single bet by id
core::args::register \
	-proc_name core::history::poolbet::get_item_by_id \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check UINT  -desc {Bet ID}] \
	] \
	-body {
		set rs [core::db::exec_qry -name core::history::poolbet::id \
			-args [list $ARGS(-value) $ARGS(-acct_id)]]

		set ret [_format_item $rs $ARGS(-lang)]

		set ret [core::history::formatter::apply \
				-item            $ret \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    {DETAILED}
			]

		core::db::rs_close -rs $rs

		return $ret
	}

# Get a single bet by receipt
core::args::register \
	-proc_name core::history::poolbet::get_item_by_receipt \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check ASCII  -desc {Receipt}] \
	] \
	-body {
		set rs [core::db::exec_qry -name core::history::poolbet::receipt \
			-args [list $ARGS(-value) $ARGS(-acct_id)]]

		set ret [_format_item $rs $ARGS(-lang)]

		set ret [core::history::formatter::apply \
				-item            $ret \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    {DETAILED}
			]

		core::db::rs_close -rs $rs

		return $ret
	}

# Get cr_date values for one page of bet items
core::args::register \
	-proc_name core::history::poolbet::get_pagination_rs \
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

		set query [_get_qry_args pagination $ARGS(-last_id) $ARGS(-acct_id) \
			$ARGS(-min_date) $ARGS(-max_date) $ARGS(-filters)]

		if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
			core::log::write ERROR {Unable to execute query: $err}
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
	-proc_name core::history::poolbet::get_range \
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

		if {$ARGS(-detail_level) != "DETAILED"} {
			
			set query [_get_qry_args main $ARGS(-last_id) $ARGS(-acct_id) \
				$ARGS(-min_date) $ARGS(-max_date) $ARGS(-filters)]

			if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
				core::log::write ERROR {Unable to execute query: $err}
				error SERVER_ERROR $::errorInfo
			}
			
		} else {	
			set date_filter    [dict get $ARGS(-filters) date_field]
			set padded_list [core::util::lpad -list $ARGS(-ids) \
											   -size $CFG(max_page_size) \
											   -padding -1]
											   
			set rs [core::db::exec_qry -name core::history::poolbet::ids::$date_filter \
				-args [list {*}$padded_list $ARGS(-acct_id)] ]
		}
		
		set current_id 0
		set colnames [db_get_colnames $rs]
		set nrows    [db_get_nrows $rs]
		set results  [list]

		# Work around until we fix the queries
		# When joining tbet on tobet we get multiple rows
		for {set i 0} {$i < $nrows} {incr i} {	
				
			if {[db_get_col $rs $i id] != $current_id} {		                          

				if {$ARGS(-detail_level) == "DETAILED"} {
					set rows [db_search -all $rs [list id int [db_get_col $rs $i id]]]

					set l_bound [lindex $rows 0]
					set u_bound [lindex $rows end]

					set item [_format_item $rs $ARGS(-lang) $l_bound $u_bound]
				} else {
					set item [dict create group POOLBET]
					foreach col $colnames {
						dict set item $col [db_get_col $rs $i $col]
					}
				}

				set ret [core::history::formatter::apply \
						-item            $item \
						-acct_id         $ARGS(-acct_id) \
						-lang            $ARGS(-lang) \
						-detail_level    $ARGS(-detail_level)
				]

				lappend results $ret
				incr ARGS(-page_size) -1
				if {$ARGS(-page_size) == 0} {
					break
				}
			} else {
				continue
			}
		}

		core::db::rs_close -rs $rs

		return $results
	}

#
# Private procedures
#

# Prepare all queries
#
# Four queries must be prepared for each combination of filters
# (pagination query + main query with and without last id)
# This results in 40 possible queries which may be used by get_page.
proc core::history::poolbet::_prep_queries {} {
	variable CFG

	foreach settled {Y N ALL} {
		foreach hierarchy_filter {ev_class_id ev_category_id ALL} {
			foreach first_page {Y N} {
				_prep_qry pagination $first_page $settled $hierarchy_filter cr_date
				_prep_qry main       $first_page $settled $hierarchy_filter cr_date
			}
		}
	}

	# This should be called only if acct_id has been added to tPoolBetStl
	if {$CFG(settled_at_filtering)} {
		foreach first_page {Y N} {
			_prep_qry pagination $first_page Y ALL settled_at
			_prep_qry main       $first_page Y ALL settled_at
		}
	}

	# ID and receipt queries
	set query [subst {
		select
			%s
			b.bet_type,
			b.ccy_stake,
			b.ccy_stake_per_line,
			b.cr_date,
			b.num_legs,
			b.num_lines,
			b.num_lines_lose,
			b.num_lines_void,
			b.num_lines_win,
			b.num_selns,
			b.pool_bet_id as id,
			b.receipt,
			b.refund,
			b.settled,
			b.settled_at,
			b.settle_info,
			b.source,
			b.stake,
			b.status,
			b.winnings,
			b.leg_type,
			e.desc as ev_name,
			e.race_number,
			e.start_time,
			l.name as pool_name,
			o.desc as oc_name,
			o.ev_oc_id as oc_id,
			o.result as oc_result,
			o.place as oc_place,
			o.runner_num as runner_num,
			p.leg_no,
			p.part_no,
			s.ccy_code as pool_ccy,
			s.desc as pool_source,
			t.pool_type_id,
			y.name as track
		from
			tPoolBet b
			inner join tPBet p on (b.pool_bet_id = p.pool_bet_id)
			inner join tEvOc o on (p.ev_oc_id = o.ev_oc_id)
			inner join tEv e on (o.ev_id = e.ev_id)
			inner join tEvType y on (e.ev_type_id  = y.ev_type_id)
			inner join tPoolMkt m on (o.ev_mkt_id = m.ev_mkt_id)
			inner join tPool l on (p.pool_id = l.pool_id and m.pool_id = l.pool_id)
			inner join tPoolType t on (l.pool_type_id = t.pool_type_id)
			inner join tPoolSource s on (l.pool_source_id = s.pool_source_id)
		where
			%s
			and b.acct_id = ?
		order by
			%s
			p.leg_no,
			p.part_no
	}]

	# No order additional ordering required for individual bet lookups
	core::db::store_qry -name core::history::poolbet::id \
		-qry [format $query [get_config -name id_directive] {b.pool_bet_id = ?} {}] \
		-cache 0
		
	core::db::store_qry -name core::history::poolbet::receipt \
		-qry [format $query [get_config -name receipt_directive] {b.receipt = ?} {}] \
		-cache 0

	set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]

	core::db::store_qry -name core::history::poolbet::ids::cr_date \
		-qry [format $query [get_config -name id_directive] "b.pool_bet_id in ($ph)" {b.cr_date desc,}] \
		-cache 0

	core::db::store_qry -name core::history::poolbet::ids::settled_at \
		-qry [format $query [get_config -name id_directive] "b.pool_bet_id in ($ph)" {b.settled_at desc,}] \
		-cache 0
}

# Prepare the pagination or range query for a given combination of filters.
#
# We use the acct_id, cr_date index to efficiently order
# and filter the results.
#
# For settled bets there is also the option of ordering by settled_date,
# which uses the acct_id, settled_at index on tPoolBetStl instead.
#
# If this is not the first page, the min_date and last_id values will
# be used to anchor the start of the page.
proc core::history::poolbet::_prep_qry {query_type first_page settled hierarchy_filter date_filter} {
	set name [format "core::history::poolbet::%s.%s.%s.%s.%s" \
		$query_type \
		$first_page \
		$settled \
		$hierarchy_filter \
		$date_filter]

	if {$query_type == {pagination}} {
		set directive_name get_pagination_directive
	} else {
		set directive_name get_range_directive
	}

	set limit          [expr [get_config -name max_page_size] + 1]
	set order_by       "b.acct_id desc, $date_filter desc"
	set select         {}
	set has_tpbet_join 0

	switch -glob $settled.$date_filter {
		Y.cr_date {
			set select       {b.cr_date as date, b.pool_bet_id as id, b.acct_id}

			if {$query_type != {pagination}} {
				set from {
					tPoolBet b
						inner join tPBet p on (b.pool_bet_id = p.pool_bet_id)
						inner join tPool l on (p.pool_id = l.pool_id)
				}
				set has_tpbet_join 1
			} else {
				set from {tPoolBet b}
				set has_tpbet_join 0
			}

			set where {
				b.acct_id = ?
				and b.cr_date between ? and ?
				and b.settled = 'Y'
			}
		}
		Y.settled_at {
			set select       {s.settled_at as date, s.pool_bet_id as id, s.acct_id}
			set from {}

			if {$query_type != {pagination}} {
				set from {
					tPoolBetStl s
						inner join tPoolBet b on (s.pool_bet_id = b.pool_bet_id)
						inner join tPBet p on (s.pool_bet_id = p.pool_bet_id)
						inner join tPool l on (p.pool_id = l.pool_id)
				}
			} else {
				set from {
					tPoolBetStl s
						inner join tPBet p on (s.pool_bet_id = p.pool_bet_id)
				}
			}

			set where {
				s.acct_id = ?
				and s.settled_at between ? and ?
			}

			set order_by "s.acct_id desc, s.settled_at desc"
			set has_tpbet_join 1

			append directive_name {_settled}
		}
		N.settled_at {
			core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
			error INVALID_FILTER_COMBI
		}
		ALL.settled_at {
			core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
			error INVALID_FILTER_COMBI
		}
		N.cr_date {
			set select       {b.cr_date as date, b.pool_bet_id as id, b.acct_id}

			set from {
				tPoolBetUnstl u
					inner join tPoolBet b on (u.pool_bet_id = b.pool_bet_id)
					inner join tPBet p on (u.pool_bet_id = p.pool_bet_id)
					inner join tPool l on (p.pool_id = l.pool_id)
			}
			set where {
				u.acct_id = ?
				and b.cr_date between ? and ?
			}
			append directive_name {_unsettled}
			set has_tpbet_join 1
		}
		default {
			set select       {b.cr_date as date, b.pool_bet_id as id, b.acct_id}

			if {$query_type != {pagination}} {
				set from {
					tPoolBet b
						inner join tPBet p on (b.pool_bet_id = p.pool_bet_id)
						inner join tPool l on (p.pool_id = l.pool_id)
				}
				set has_tpbet_join 1
			} else {
				set from {tPoolBet b}
				set has_tpbet_join 0
			}
			set where {
				b.acct_id = ?
				and b.cr_date between ? and ?
			}
		}
	}

	if {$first_page != {Y}} {
		if {$date_filter == {settled_at}} {
			append where "and (s.settled_at < ? or (s.settled_at = ? and s.pool_bet_id < ?))"
		} else {
			append where "and b.pool_bet_id < ?"
		}
	}

	set tpbet_join {}
	if {!$has_tpbet_join} {
		set tpbet_join { inner join tPBet p on (b.pool_bet_id = p.pool_bet_id)}
	}
	switch -- $hierarchy_filter {
		ev_class_id {
			append from $tpbet_join
			append from {
				inner join (
					tPoolMkt pm
					inner join tEvMkt m on (pm.ev_mkt_id = m.ev_mkt_id)
					inner join tEvOc o on (m.ev_mkt_id = o.ev_mkt_id)
					inner join tEv e on (m.ev_id = e.ev_id)
					inner join tEvType t on (e.ev_type_id = t.ev_type_id)
					inner join tEvClass c on (t.ev_class_id = c.ev_class_id and c.ev_class_id = ?)
				) on (p.pool_id = pm.pool_id)
			}
		}
		ev_category_id {
			append from $tpbet_join
			append from {
				inner join (
					tPoolMkt pm
					inner join tEvMkt m on (pm.ev_mkt_id = m.ev_mkt_id)
					inner join tEvOc o on (m.ev_mkt_id = o.ev_mkt_id)
					inner join tEv e on (m.ev_id = e.ev_id)
					inner join tEvType t on (e.ev_type_id = t.ev_type_id)
					inner join tEvClass c on (t.ev_class_id = c.ev_class_id)
					inner join tEvCategory y on (c.category = y.category and y.ev_category_id = ?)
				) on (p.pool_id = pm.pool_id)
			}
		}
	}

	set directive [get_config -name $directive_name]

	if {$query_type == {pagination}} {
		set qry [subst {
			select $directive
			first $limit distinct
				$select
			from
				$from
			where
				$where
			order by $order_by
		}]

		core::db::store_qry -cache 0 -name $name -qry $qry
	} else {
		# Range query.
		set qry [subst {
			select $directive
			distinct
				b.bet_type,
				b.ccy_stake,
				b.ccy_stake_per_line,
				b.cr_date,
				b.leg_type,
				b.num_legs,
				b.num_lines,
				b.num_selns,
				b.pool_bet_id as id,
				b.receipt,
				b.refund,
				b.settled,
				b.settled_at,
				b.source,
				b.stake,
				b.status,
				b.winnings,
				l.name as pool_name,
				l.pool_type_id
			from
				$from
			where
				$where
			order by b.$date_filter desc, b.pool_bet_id desc
		}]

		core::db::store_qry -cache 0 -name $name -qry $qry
	}
}

# Work out the query and query parameters for the current set of filters
proc core::history::poolbet::_get_qry_args {name last_id acct_id date_from date_to filters} {
	set sql_params       [list]
	set hierarchy_filter {ALL}
	set ev_category_id   {ALL}

	set first_page     [expr {($last_id == -1) ? {Y} : {N}}]
	set ev_class_id    [dict get $filters ev_class_id]
	# If ev_category_id is not in the filters (does not exist when ev_category_id is not
	# in the schema) we set ev_category_id to ALL so we wont filter
	if {[dict exists $filters ev_category_id]} {
		set ev_category_id [dict get $filters ev_category_id]
	}
	set settled        [dict get $filters settled]
	set date_filter    [dict get $filters date_field]

	if {$ev_class_id != {ALL} && $ev_category_id != {ALL}} {
		core::log::write ERROR {Cannot specify both class and category}
		error INVALID_FILTER_COMBI
	}

	if {$ev_class_id != {ALL}} {
		lappend sql_params [dict get $filters ev_class_id]
		set hierarchy_filter {ev_class_id}
	}

	if {$ev_category_id != {ALL}} {
		lappend sql_params [dict get $filters ev_category_id]
		set hierarchy_filter {ev_category_id}
	}

	lappend sql_params $acct_id $date_from $date_to

	if {!$first_page} {
		if {$date_filter == {settled_at}} {
			lappend sql_params $date_to $date_to $last_id
		} else {
			lappend sql_params $last_id
		}
	}

	if {$date_filter == {settled_at} && ($settled != {Y} || $hierarchy_filter != {ALL})} {
		core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
		error INVALID_FILTER_COMBI
	}

	set name [format "core::history::poolbet::%s.%s.%s.%s.%s" \
		$name \
		$first_page \
		$settled \
		$hierarchy_filter \
		$date_filter]

	return [dict create -name $name -args $sql_params]
}

# Format a detailed bet item dict given the result set
proc core::history::poolbet::_format_item {rs lang {l_bound {}} {u_bound {}}} {
	variable BET_COLS
	variable LEG_COLS
	variable PART_COLS
	variable CFG

	set bet   [dict create group {POOLBET}]
	set nrows [db_get_nrows $rs]

	if {$l_bound == {} && $u_bound == {}} {
		set nrows [db_get_nrows $rs]
		set lower_bound 0
		set upper_bound $nrows

	} elseif {$l_bound != {} && $u_bound != {}} {
		if {$l_bound > $u_bound} {
			core::log::write ERROR {core::history::poolbet::_format_item: l_bound should be less or equal than u_bound}
			error SERVER_ERROR {core::history::poolbet::_format_item: l_bound should be less or equal than u_bound}
		}

		set nrows [expr {$u_bound + 1}]
		set lower_bound $l_bound
		set upper_bound $u_bound
	} else {
		core::log::write ERROR {core::history::poolbet::_format_item: an index parameter is missing from the call}
		error SERVER_ERROR {core::history::poolbet::_format_item: an index parameter is missing from the call}
	}

	if {!$nrows} {
		core::log::write ERROR {No results found}
		error INVALID_ITEM {core::history::poolbet::_format_item returned < 1 row}
	}

	foreach {col xl} $BET_COLS {
		if {$xl} {
			switch -- $col {
				mkt_name {
					set value [core::xl::XL \
						-str    [db_get_col $rs 0 $col] \
						-lang   $lang -args [list [db_get_col $rs $lower_bound bir_index]]]
				}
				async_cancel_reason {
					set value [core::xl::sprintf -code [db_get_col $rs $lower_bound $col] -lang $lang]
				}
				default {
					set value [core::xl::XL -str [db_get_col $rs $lower_bound $col] -lang $lang]
				}
			}

			set value [core::history::xl -value $value]
		} else {
			if {$CFG(escape_untranslated_entities)} {
				set value [core::xml::escape_entity -value [db_get_col $rs $lower_bound $col]]
			} else {
				set value [db_get_col $rs $lower_bound $col]
			}
		}
		dict set bet $col $value
	}

	# add the legs
	dict set bet legs [list]
	set leg           {}
	set part          {}
	set new_leg       1
	set new_part      1

	for {set i $lower_bound; set j [expr $lower_bound + 1]} {$i < $nrows} {incr i; incr j} {
		set leg_no  [db_get_col $rs $i leg_no]
		set part_no [db_get_col $rs $i part_no]

		if {$new_leg} {
			set leg  [dict create parts [list]]
			foreach {col xl} $LEG_COLS {
				if {$xl} {
					set value [core::xl::XL -str [db_get_col $rs $i $col] -lang $lang]

					set value [core::history::xl -value $value]
				} else {
					if {$CFG(escape_untranslated_entities)} {
						set value [core::xml::escape_entity -value [db_get_col $rs $i $col]]
					} else {
						set value [db_get_col $rs $i $col]
					}
				}
				dict set leg $col $value
			}
		}

		if {$new_part} {
			set part [dict create]
			foreach {col xl} $PART_COLS {
				if {$xl} {
					set value [core::xl::XL -str [db_get_col $rs $i $col] -lang $lang]

					set value [core::history::xl -value $value]
				} else {
					if {$CFG(escape_untranslated_entities)} {
						set value [core::xml::escape_entity -value [db_get_col $rs $i $col]]
					} else {
						set value [db_get_col $rs $i $col]
					}
				}
				dict set part $col $value
			}
		}

		# Look ahead to see if we are done with this leg/part
		# If so, add it to the parent dict
		set new_leg [expr {$j == $nrows || \
			[db_get_col $rs $j leg_no] != $leg_no}]
		set new_part [expr {$new_leg || $j == $nrows || \
			[db_get_col $rs $j part_no] != $part_no}]

		if {$new_part} {
			dict lappend leg parts $part
		}

		if {$new_leg} {
			dict lappend bet legs $leg
		}
	}

	return $bet
}

# Certain filters are expensive. We restrict these to ensure
# they are not applied to a large number of bets
proc core::history::poolbet::is_restricted {filters} {

	set ev_category_id 0
	if {[dict exists $filters ev_category_id] && [dict get $filters ev_category_id] != {ALL}} {
		incr ev_category_id
	}

	set ev_class_id 0
	if {[dict exists $filters ev_class_id] && [dict get $filters ev_class_id] != {ALL}} {
		incr ev_class_id
	}

	return [expr {($ev_category_id || $ev_class_id) && ([dict get $filters settled] != N)}]
}
