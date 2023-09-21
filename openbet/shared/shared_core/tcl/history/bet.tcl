# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Bet history
#
set pkg_version 1.0
package provide core::history::bet $pkg_version

package require core::args  1.0
package require core::db 1.0
package require core::db::schema 1.0
package require core::history
package require core::xl 1.0
package require core::util 1.0

core::args::register_ns \
	-namespace     core::history::bet \
	-version       $pkg_version \
	-dependent     [list core::args core::db core::db::schema core::history core::xl] \
	-desc          {Bet history} \
	-docs          history/bet.xml

namespace eval core::history::bet {
	variable CFG
	variable BET_COLS
	variable LEG_COLS
	variable PART_COLS
	variable DEDUCTION_COLS
}

# Initialise the module
core::args::register \
	-proc_name core::history::bet::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
		[list -arg -get_pagination_directive_unsettled -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_PAGINATION_U_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries using unsettled bets}] \
		[list -arg -get_range_directive_unsettled -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_RANGE_U_DIRECTIVE \
			-desc {Directive for get_range queries using unsettled bets}] \
		[list -arg -get_pagination_directive_settled -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_PAGINATION_S_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries using settled bets}] \
		[list -arg -get_range_directive_settled -mand 0 -check STRING \
			-default_cfg HIST_BET_GET_RANGE_S_DIRECTIVE \
			-desc {Directive for get_range queries using settled bets}] \
		[list -arg -id_directive -mand 0 -check STRING \
			-default_cfg HIST_BET_ID_DIRECTIVE \
			-desc {Directive for id queries}] \
		[list -arg -receipt_directive -mand 0 -check STRING \
			-default_cfg HIST_BET_RECEIPT_DIRECTIVE \
			-desc {Directive for receipt queries}] \
		[list -arg -restricted_filter_max_days -mand 0 -default 1 -check UINT -desc {Maximum days the date range must span when using hierarchy filters.}] \
		[list -arg -use_change_history -mand 0 -default_cfg HIST_BET_USE_CHANGE_HISTORY -default 0 -check BOOL -desc {Enable bet change history functionality}] \
		[list -arg -bet_hist_batch_size -mand 0 -check UINT \
			-default_cfg HIST_BET_CHANGES_BATCH_SIZE -default 10 \
			-desc {Number of placeholders to set by default to query core::history::bet::bet_hist}] \
		[list -arg -show_italian_bet_history -mand 0 -default_cfg HIST_BET_SHOW_ITALIAN_INFO -default 0 -check BOOL -desc {Enable SOGEI net info retrieval}] \
		[list -arg -sfb_tag_for_results -mand 0 -default_cfg HIST_SFB_USED_FOR_RESULTS -default {} -check STRING -desc {SFB Tag used for results}] \
		[list -arg -escape_untranslated_entities -mand 0 -default_cfg HIST_ESCAPE_UNTRANSLATED_ENTITIES -default 0 -check BOOL -desc {Escape Untranslated Entities for XML/HTML Printing}] \
		[list -arg -bet_get_item_by_uuid -mand 0 -default_cfg HIST_BET_GET_ITEM_BY_UUID -default 0 -check BOOL -desc {Allow bet items to be searched using uuid}] \
		[list -arg -uuid_directive -mand 0 -check STRING -default_cfg HIST_BET_UUID_DIRECTIVE -desc {Directive for uuid queries}] \
		[list -arg -hide_bets_with_statuses -mand 0 -check STRING -default_cfg HIST_HIDE_BET_WITH_STATUS -default {} -desc {Bets of the specified status(es) will be excluded from the result set}] \
		[list -arg -hide_cancelled_bets -mand 0 -default_cfg HIST_HIDE_CANCELLED_BETS -default 0 -check BOOL -desc {DEPRECATED: Cancelled bets to be excluded from the RS.}] \
		[list -arg -show_betgroup_info -mand 0 -default_cfg HIST_BET_SHOW_BETGROUP_INFO -default 0 -check BOOL -desc {Enable bet groups information for bets}] \
	] \
	-body {
		variable CFG
		variable BET_COLS
		variable LEG_COLS
		variable PART_COLS
		variable DEDUCTION_COLS

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Bet Module initialised with $formatted_name_value}
		}

		set CFG(max_page_size)        [core::history::get_config -name max_page_size]
		set CFG(settled_at_filtering) [core::history::get_config -name settled_at_filtering]

		set filters [list \
			[list settled     HIST_SETTLED    ALL] \
			[list ev_class_id UINT            ALL] \
			[list date_field  HIST_DATE_FIELD cr_date] \
		]

		if {$CFG(show_betgroup_info)} {
			if {![core::db::schema::table_exists -table tGrpdBets]} {
				core::log::write WARNING "tGrpdBets does not exist"
				set CFG(show_betgroup_info) 0
			}
		}

		core::check::register "UINT_LIST" "core::history::bet::check_uint_list" {}

		if {$CFG(show_betgroup_info)} {
			lappend filters [list bet_group_id    UINT_LIST ALL]
			lappend filters [list bet_group_order UINT      ALL]
		}
		if {[core::db::schema::table_column_exists -table tEvCategory -column ev_category_id]} {
			lappend filters [list ev_category_id ASCII ALL]
		}

		if {[core::db::schema::table_column_exists -table tEvMkt -column ev_mkt_id]} {
			lappend filters [list ev_mkt_id UINT ALL]
		}

		if {$CFG(show_italian_bet_history)} {
			if {![core::db::schema::table_exists -table tSGBet]} {
				core::log::write WARNING "tSGBet does not exist"
				set CFG(show_italian_bet_history) 0
			}
		}

		if {$CFG(sfb_tag_for_results)!={}} {
			if {![core::db::schema::table_exists -table tEvOcResult]} {
				core::log::write WARNING "tEvOcResult does not exist"
				set CFG(sfb_tag_for_results) {}
			}
		}

		set CFG(show_result_set_at) [core::db::schema::table_column_exists -table tEvOc -column result_set_at]

		core::history::add_combinable_group \
			-group                          BET \
			-detail_levels                  {SUMMARY DETAILED} \
			-j_op_ref_keys                  {ESB} \
			-page_handler                   core::history::bet::get_page \
			-range_handler                  core::history::bet::get_range \
			-pagination_result_handler      core::history::bet::get_pagination_rs \
			-filters                        $filters

		# Prepare queries
		core::history::bet::_prep_queries

		core::history::add_item_handler \
			-group            BET \
			-item_handler     core::history::bet::get_item_by_id \
			-key              ID

		core::history::add_item_handler \
			-group            BET \
			-item_handler     core::history::bet::get_item_by_receipt \
			-key              RECEIPT

		# Set format for detailed bet items
		set BET_COLS [list \
			id                  0 \
			cr_date             0 \
			bet_type            0 \
			leg_type            0 \
			stake               0 \
			stake_per_line      0 \
			status              0 \
			settled             0 \
			settled_at          0 \
			winnings            0 \
			refund              0 \
			receipt             0 \
			num_legs            0 \
			num_lines           0 \
			num_selns           0 \
			source              0 \
			num_lines_win       0 \
			num_lines_lose      0 \
			num_lines_void      0 \
			settle_info         1 \
			token_value         0 \
			potential_payout    0 \
			async_status        0 \
			async_org_stk_line  0 \
			async_cancel_reason 1 \
			call_id             0 \
			placed_by           0 \
			user_id             0 \
			bonus               0 \
			tax                 0 \
			tax_type            0 \
			tax_rate            0 \
			paid                0 \
			unique_id           0 \
			token_payout        0 \
		]

		if {$CFG(show_italian_bet_history)} {
			lappend BET_COLS ticket_id 0 \
			                 sg_status 0
		}

		if {$CFG(show_betgroup_info)} {
			lappend BET_COLS grpd_bet_id  0 \
							grpd_bet_type  0 \
							grpd_bet_order 0
		}

		set LEG_COLS [list \
			leg_sort   0 \
			leg_type   0 \
			leg_status 0 \
			leg_no     0 \
		]

		set PART_COLS [list \
			price_type       0 \
			price_num        0 \
			price_den        0 \
			banker           0 \
			in_running       0 \
			bir_index        0 \
			sp_num           0 \
			sp_den           0 \
			oc_name          1 \
			oc_result        0 \
			oc_place         0 \
			runner_num       0 \
			fb_result        0 \
			hcap_value       0 \
			ew_fac_num       0 \
			ew_fac_den       0 \
			ew_places        0 \
			ev_name          1 \
			ev_id            0 \
			venue            1 \
			race_number      0 \
			ev_type_id       0 \
			ev_type_name     1 \
			ev_class_id      0 \
			ev_class_name    1 \
			no_combi         0 \
			oc_id            0 \
			result_conf      0 \
			mkt_id           0 \
			mkt_sort         0 \
			mkt_type         0 \
			mkt_hcap_makeup  0 \
			mkt_name         1 \
			mkt_name_raw     0 \
			mkt_blurb        1 \
			start_time       0 \
			ev_category_name 1 \
			ev_category_id   0 \
			part_no          0 \
			part_sort        0 \
			oc_result_set_at 0 \
		]

		set DEDUCTION_COLS [list \
			market           0 \
			deduction        0 \
			time_from        0 \
			time_to          0 \
		]

		if {[core::db::schema::table_column_exists -table tOBet -column leg_type]} {
			lappend LEG_COLS leg_type 0
		} else {
			lappend BET_COLS leg_type 0
		}

		# Bet change history
		if {$CFG(use_change_history)} {
			if {[core::db::schema::table_exists -table tBetHist] == 1 && \
				[core::db::schema::table_column_exists -table tBet -column num_hists] == 1} {

				# Prepare Queries
				core::history::bet::_prep_qry_bet_hist

				# Add tbet.num_hist to the existing queries
				lappend BET_COLS num_hists 0
			} else {
				set CFG(use_change_history) 0
			}
		}

	}

# Get config
core::args::register \
	-proc_name core::history::bet::get_config \
	-is_public 0 \
	-args [list \
		[list -arg -name    -mand 1 -check ASCII -desc {Config name}] \
		[list -arg -default -mand 0 -default {} -check ANY -desc {Default value}] \
	] \
	-body {
		variable CFG

		if {![info exists CFG($ARGS(-name))]} {
			return $ARGS(-default)
		}

		return $CFG($ARGS(-name))
	}

#
# Interfaces that retrieve extra information (possibly customer specific)
#
core::args::register \
	-interface core::history::bet::post_handler \
	-mand_impl 0 \
	-desc    {Add extra information to bet item} \
	-args [list \
		[list -arg -item         -mand 1 -check ANY         -desc {Item requiring extra information}] \
		[list -arg -detail_level -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
	]

core::args::register \
	-interface core::history::bet::range_post_handler \
	-mand_impl 0 \
	-desc      {Add extra information to a dict or to a list of dicts} \
	-args [list \
		[list -arg -bets         -mand 1 -check ANY         -desc {Dict of a bet or list of dicts of bets}] \
		[list -arg -detail_level -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -grouped      -mand 1 -check BOOL        -desc {Indicates whether the -bets parameter is passed as a list of dicts}] \
	] \
	-return_data [list \
		[list -arg -bets         -mand 0 -check ANY         -desc {Dict of bets}] \
	] \
	-errors [list \
		DB_ERROR \
		ERROR \
	]

# Get a page of bet items
core::args::register \
	-proc_name core::history::bet::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT             -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII            -desc {Language code for customer}] \
		[list -arg -group         -mand 1 -check {ENUM -args {BET}}     -desc {Group name}] \
		[list -arg -filters       -mand 1 -check ANY              -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME         -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME         -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check HIST_DETAIL -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT             -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check INT -default -1  -desc {ID of last item returned}] \
	] \
	-body {
		set date_field [dict get $ARGS(-filters) date_field]

		if {[is_restricted $ARGS(-filters)]} {
			# These filters should not be used to retrieve more than (by default)
			# a day's worth of bets.  In the worst case scenario where there
			# are no matching bets, all of the customer's bets that fall within
			# the date range will be scanned.
			set max_days [get_config -name restricted_filter_max_days]
			core::history::validate_date_range \
				-from            $ARGS(-min_date) \
				-to              $ARGS(-max_date) \
				-max_days        $max_days
		} else {
			core::history::validate_date_range \
				-from            $ARGS(-min_date) \
				-to              $ARGS(-max_date)
		}

		set rs [get_pagination_rs \
			-acct_id          $ARGS(-acct_id) \
			-filters          $ARGS(-filters) \
			-min_date         $ARGS(-min_date) \
			-max_date         $ARGS(-max_date) \
			-page_size        $ARGS(-page_size) \
			-last_id          $ARGS(-page_boundary)]

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

# Get a single bet by id
core::args::register \
	-proc_name core::history::bet::get_item_by_id \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check ASCII  -desc {Bet ID or bet UUID}] \
	] \
	-body {


		if {[get_config -name bet_get_item_by_uuid] && \
			[core::check::check_value $ARGS(-value) {AND} UUID]\
		} {
			set rs [core::db::exec_qry -name core::history::bet::uuid \
				-args [list $ARGS(-value) $ARGS(-acct_id)]]
		} else {

			set rs [core::db::exec_qry -name core::history::bet::id \
				-args [list $ARGS(-value) $ARGS(-acct_id)]]
		}

		set ret [_format_item $rs $ARGS(-lang)]

		set ret [core::history::formatter::apply \
				-item            $ret \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    {DETAILED}
			]

		if {[core::args::is_implemented -interface core::history::bet::post_handler]} {
			set ret [core::history::bet::post_handler \
					-item $ret \
					-detail_level {DETAILED}
			]
		}

		if {[core::args::is_implemented -interface core::history::bet::range_post_handler]} {
			set ret [core::history::bet::range_post_handler \
					-bets $ret \
					-detail_level {DETAILED} \
					-grouped 0
			]

			set ret [dict get $ret -bets]
		}

		core::db::rs_close -rs $rs

		return $ret
	}

# Get a single bet by receipt
core::args::register \
	-proc_name core::history::bet::get_item_by_receipt \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check ASCII  -desc {Receipt}] \
	] \
	-body {
		set rs [core::db::exec_qry -name core::history::bet::receipt \
			-args [list $ARGS(-value) $ARGS(-acct_id)]]

		set ret [_format_item $rs $ARGS(-lang)]

		set ret [core::history::formatter::apply \
				-item            $ret \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    {DETAILED}
			]

		if {[core::args::is_implemented -interface core::history::bet::post_handler]} {
			set ret [core::history::bet::post_handler \
				-item $ret \
				-detail_level {DETAILED}
			]
		}

		if {[core::args::is_implemented -interface core::history::bet::range_post_handler]} {
			set ret [core::history::bet::range_post_handler \
				-bets $ret \
				-detail_level {DETAILED} \
				-grouped 0
			]

			set ret [dict get $ret -bets]
		}

		core::db::rs_close -rs $rs

		return $ret
	}

# Get cr_date values for one page of bet items
core::args::register \
	-proc_name core::history::bet::get_pagination_rs \
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
	-proc_name core::history::bet::get_range \
	-clones core::history::range_handler \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level  -mand 1 -check {ENUM -args {SUMMARY DETAILED}} -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -last_id       -mand 0 -check INT -default -1 -desc {ID of last item returned}] \
		[list -arg -ids           -mand 0 -check LIST -default {} -desc {List of pagination ids.}] \
	] \
	-body {
		variable CFG
		set results [list]

		set query [_get_qry_args main $ARGS(-last_id) $ARGS(-acct_id) \
			$ARGS(-min_date) $ARGS(-max_date) $ARGS(-filters)]

		if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
			core::log::write ERROR {Unable to execute query: $err}
			error SERVER_ERROR $::errorInfo
		}

		set nrows    [db_get_nrows    $rs]
		set colnames [db_get_colnames $rs]

		if {$ARGS(-detail_level) == "DETAILED"} {
			set id_list [list]

			if {$nrows > 1} {
				set id_list [db_get_col_list $rs -name id]
				set padded_list [core::util::lpad -list $id_list -size $CFG(max_page_size) -padding -1]

				if {[catch {set detail_rs [core::db::exec_qry -name core::history::bet::ids -args [list {*}$padded_list $ARGS(-acct_id)]]} err]} {
					core::log::write ERROR {Unable to execute query: $err}
					error SERVER_ERROR $::errorInfo
				}
			} else {
				lappend id_list [db_get_col $rs 0 id]

				if {[catch {set detail_rs [core::db::exec_qry -name core::history::bet::id -args [list $id_list $ARGS(-acct_id)]]} err]} {
					core::log::write ERROR {Unable to execute query: $err}
					error SERVER_ERROR $::errorInfo
				}
			}
		}

		# Work around until we fix the queries
		# When joining tbet on tobet we get multiple rows
		set current_id 0
		for {set i 0} {$i < $nrows} {incr i} {
			if {[db_get_col $rs $i id] != $current_id} {

				if {$ARGS(-detail_level) == "DETAILED"} {
					set rows [db_search -all $detail_rs [list id int [db_get_col $rs $i id]]]

					set l_bound [lindex $rows 0]
					set u_bound [lindex $rows end]

					set item [_format_item $detail_rs $ARGS(-lang) $l_bound $u_bound]

				} else {
					set item [dict create group BET]
					foreach col $colnames {
						dict set item $col [db_get_col $rs $i $col]
					}
				}

				set ret [core::history::formatter::apply \
					-item           $item \
					-acct_id        $ARGS(-acct_id) \
					-lang           $ARGS(-lang) \
					-detail_level   $ARGS(-detail_level)
				]

				if {[core::args::is_implemented -interface core::history::bet::post_handler]} {
					set ret [core::history::bet::post_handler \
								-item $ret \
								-detail_level $ARGS(-detail_level)
							]
				}

				lappend results $ret
				set current_id [db_get_col $rs $i id]
				incr ARGS(-page_size) -1
				if {$ARGS(-page_size) == 0} {
					break
				}
			} else {
				continue
			}
		}

		if {[core::args::is_implemented -interface core::history::bet::range_post_handler]} {
			set results [core::history::bet::range_post_handler \
				-bets $results \
				-detail_level $ARGS(-detail_level) \
				-grouped 1
			]

			set results [dict get $results -bets]
		}

		if {$ARGS(-detail_level) == "DETAILED"} {
			core::db::rs_close -rs $detail_rs
		}

		core::db::rs_close -rs $rs

		return $results
	}

# Get bet changes history for a given list of bet_id
#
# Example of the returning value:
#
# bet_id 12345
# bet_changes {
#     {
#         change_date {
#             2013-10-25 17:21:29
#         }
#         change_no 0
#         potential_payout 25.00
#         leg_changes {
#             {
#                 leg_no 1
#                 price_num 21
#                 price_den 20
#             } {
#                 leg_no 2
#                 ew_places 4
#             }
#         }
#     }
#     {
#         change_date {
#             2013-10-25 17:22:00
#         }
#         change_no 1
#         reason_code PRICE_BOOST
#         reason_desc {
#             Price Boost
#         }
#         user_id 14356
#         username FOB_user
#         potential_payout 30.00
#         leg_changes {
#             {
#                 leg_no 1
#                 price_num 23
#                 price_den 20
#             }
#         }
#     }
#     {
#         change_date {
#             2013-10-25 18:00:00
#         }
#         change_no 2
#         reason_code RETROSPECTIVE
#         reason_desc {
#             Retrospective Price Change
#         }
#         user_id 143143
#         username TraderX
#         leg_changes {
#             {
#                 leg_no 2
#                 ew_places 3
#             }
#         }
#     }
# }
core::args::register \
	-proc_name core::history::bet::get_change_history_by_ids \
	-desc {Get bet changes history for a given list of bet_id} \
	-args [list \
		[list -arg -bet_ids -mand 1 -check LIST -desc {List of Bet IDs}] \
	] \
	-body {
		variable CFG

		set fn {core::history::bet::get_change_history_by_ids}

		if {$CFG(use_change_history) != 1} {
			core::log::write ERROR {$fn - Missing columns on the current DB schema.}
			error "$fn - Missing columns on the current DB schema" {} BET_HIST
		}

		# Data Validation
		set bet_list $ARGS(-bet_ids)
		if {[llength $bet_list] == 0} {
			core::log::write INFO {$fn - called with 0 bets.}
			return [list]
		}

		# Check each element of the list is formatted as UINT
		foreach bet_id $bet_list {
			if {![core::check::integer $bet_id]} {
				core::log::write ERROR {$fn - Invalid bet_id list format}
				error "$fn - Invalid bet_id list format" {} BET_HIST
			}
		}

		set bet_count [llength $bet_list]

		# If we have more items than placeholders we need
		# to split up the list and process in batches
		if {$bet_count > $CFG(bet_hist_batch_size)} {

			# Create the main empty result set
			set rs [db_create [list \
				bet_id \
				stake_per_line \
				potential_payout \
				stake \
				cr_date \
				ev_oc_id \
				leg_no \
				o_num \
				o_den \
				ew_fac_num \
				ew_fac_den \
				ew_places \
				bet_hist_id \
				bet_hist_stake_per_line \
				bet_hist_potential_payout \
				bet_hist_stake \
				bet_hist_winnings \
				bet_hist_date \
				bet_hist_user_id \
				bet_hist_username \
				bet_hist_reason_code \
				bet_hist_reason_desc \
				obet_hist_id \
				ohist_o_num \
				ohist_o_den \
				ohist_ew_fac_num \
				ohist_ew_fac_den \
				ohist_ew_places \
				cashout_amount \
				cashout_date \
				cashout_type \
				cashout_location
			]]


			# Chop the list into pieces and execute each piece
			foreach chopped_list \
				[core::util::lchop -list $bet_list -size $CFG(bet_hist_batch_size) -pad_list 1 -padding -1] {

				if {[catch {
					set c_rs [core::db::exec_qry -name core::history::bet::bet_hist -args $chopped_list]
				} err]} {
					core::log::write ERROR {$fn - Unable to execute query: $err}
					error "$fn - Could not get bet history: $err" $::errorInfo SYSTEM_ERROR
				}

				# Support 58236: Only try to move a non-shared query
				# Prefer moving if it's not shared (save memory)
				if {[db_get_shared $c_rs]} {
					db_merge -copy $rs $c_rs
				} else {
					db_merge -move $rs $c_rs
				}

				core::db::rs_close -rs $c_rs

			}
		} elseif {$bet_count==1} {

				set bet_id [lindex $bet_list 0]
				if {[catch {
					set rs [core::db::exec_qry -name core::history::bet::bet_hist_id -args $bet_id]
				} err]} {
					core::log::write ERROR {$fn - Unable to execute query: $err}
					error "$fn - Could not get bet history: $err" $::errorInfo SYSTEM_ERROR
				}

		} else {

			set bet_list [core::util::lpad -list $bet_list -size $CFG(bet_hist_batch_size) -padding -1]

			if {[catch {
				set rs [core::db::exec_qry -name core::history::bet::bet_hist -args $bet_list]
			} err]} {
				core::log::write ERROR {$fn - Unable to execute query: $err}
				error "$fn - Could not get bet history: $err" $::errorInfo SYSTEM_ERROR
			}
		}

		set nrows [db_get_nrows $rs]
		if {$nrows == 0} {
			core::db::rs_close -rs $rs
			core::log::write INFO {$fn - No Results Found}
			return [list]
		} else {
			core::log::write INFO {$fn - $nrows rows found}
		}

		set prev_bet_no {}
		set prev_change_id {}
		set prev_leg_change_id {}

		# The main dict structure that is being built for all the bets passed in
		set bet_change_history_list {}
		# The dict structure that represents the current 'bet' being built + 'bet changes'
		set curr_bet_dict {}
		# The dict structure that represents the current 'bet change' being built + 'leg changes'
		set curr_change_dict {}
		set curr_change0_dict {}

		# Main loop to create and fill the returned data structure
		for {set i 0} {$i < $nrows} {incr i} {

			# Current row's info
			set bet_no               [db_get_col $rs $i bet_id]
			set change_id            [db_get_col $rs $i bet_hist_id]
			set leg_change_id        [db_get_col $rs $i obet_hist_id]

			# BET
			# Check if this row of the result set contains a new bet
			if {$prev_bet_no != $bet_no} {

				#   Final bet processing, for the previous bet
				if {$prev_change_id != {}} {
					dict lappend curr_bet_dict bet_changes $curr_change_dict

					dict lappend curr_bet_dict bet_changes $curr_change0_dict

					# Append the prev bet to the list
					set curr_bet_dict [_process_bet_changes $curr_bet_dict]
					lappend bet_change_history_list $curr_bet_dict
				}

				# New Bet
				# create a new bet definition dictionary
				set curr_bet_dict [dict create \
					bet_id $bet_no \
					bet_changes [list]]

				set bet_date                [db_get_col $rs $i cr_date]
				set curr_change0_dict       [dict create \
					change_date      $bet_date \
					change_no        {} \
					reason_code      {} \
					reason_desc      {} \
					user_id          {} \
					username         {} \
					stake_per_line   {} \
					stake            {} \
					winnings         {} \
					potential_payout {} \
					cashout_amount   {} \
					cashout_date	 {} \
					cashout_type     {} \
					cashout_location {} \
					leg_changes [list]]

			}


			# CHANGE
			# Does this row start a new Bet Change?
			if {$prev_change_id != $change_id} {

				# If this is a change for the same bet, append the last bet change
				if {($prev_bet_no == $bet_no) && ($prev_change_id != {})} {
					dict lappend curr_bet_dict bet_changes $curr_change_dict
				}

				# New Bet Change
				set bet_change_dict [dict create \
					change_id        $change_id \
					change_date      [db_get_col $rs $i bet_hist_date] \
					change_no        {}  \
					reason_code      [db_get_col $rs $i bet_hist_reason_code] \
					reason_desc      [db_get_col $rs $i bet_hist_reason_desc] \
					user_id          [db_get_col $rs $i bet_hist_user_id] \
					username         [db_get_col $rs $i bet_hist_username] \
					stake_per_line   [db_get_col $rs $i bet_hist_stake_per_line] \
					potential_payout [db_get_col $rs $i bet_hist_potential_payout] \
					stake            [db_get_col $rs $i bet_hist_stake] \
					winnings         [db_get_col $rs $i bet_hist_winnings] \
					cashout_amount   [db_get_col $rs $i cashout_amount] \
					cashout_date     [db_get_col $rs $i cashout_date] \
					cashout_type     [db_get_col $rs $i cashout_type] \
					cashout_location [db_get_col $rs $i cashout_location] \
					leg_changes      [list]]


				# Build the current bet state dict
				set bet [dict create \
					change_date      [db_get_col $rs $i cr_date] \
					stake            [db_get_col $rs $i stake] \
					stake_per_line   [db_get_col $rs $i stake_per_line] \
					potential_payout [db_get_col $rs $i potential_payout]]

				# Build up the change0 structure for the new bet
				set var_list {stake_per_line potential_payout stake}
				set bet_change0_result [_perform_change0_diff \
					$bet_change_dict $curr_change0_dict $bet $var_list]
				set bet_change_dict   [lindex $bet_change0_result 0]
				set curr_change0_dict [lindex $bet_change0_result 1]

				# Finally, store the current bet_change for future processing
				set curr_change_dict $bet_change_dict
			}

			# LEG
			# Does this row start a new Leg Change for the current Bet Change?
			# This processing logic depends on the Query Ordering
			if {$leg_change_id != {}} {
				# A new Leg Change for the same Bet Change

				# Build the Leg Change dict
				set curr_leg_no     [db_get_col $rs $i leg_no]
				set leg_change_dict [dict create \
					leg_change_id   $leg_change_id \
					leg_no          $curr_leg_no \
					price_num       [db_get_col $rs $i ohist_o_num] \
					price_den       [db_get_col $rs $i ohist_o_den] \
					ew_fac_num      [db_get_col $rs $i ohist_ew_fac_num] \
					ew_fac_den      [db_get_col $rs $i ohist_ew_fac_den] \
					ew_places       [db_get_col $rs $i ohist_ew_places]]

				# Build the current bet state dict
				set bet [dict create \
					price_num       [db_get_col $rs $i o_num] \
					price_den       [db_get_col $rs $i o_den] \
					ew_fac_num      [db_get_col $rs $i ew_fac_num] \
					ew_fac_den      [db_get_col $rs $i ew_fac_den] \
					ew_places       [db_get_col $rs $i ew_places]]

				# Find the change0 leg dictionary to update
				set curr_leg_change0_dict {}
				foreach leg_change [dict get $curr_change0_dict leg_changes] {
					if {[dict get $leg_change leg_no] == $curr_leg_no} {
						set curr_leg_change0_dict $leg_change
						break
					}
				}

				# No change0_leg was found - create a new skeleton
				if {$curr_leg_change0_dict == {}} {
					set curr_leg_change0_dict [dict create \
						leg_no     $curr_leg_no \
						price_num  {} \
						price_den  {} \
						ew_fac_num {} \
						ew_fac_den {} \
						ew_places  {}]
				}

				# Build the change0 object for this leg from the leg change data
				set var_list {price_num price_den ew_fac_num ew_fac_den ew_places}
				set leg_change0_result [_perform_change0_diff \
					$leg_change_dict $curr_leg_change0_dict $bet $var_list]
				set leg_change_dict       [lindex $leg_change0_result 0]
				set curr_leg_change0_dict [lindex $leg_change0_result 1]

				# Now that we have the change0 for this leg, add or update it in the main change0 structure
				set curr_change0_dict [_update_leg_change0 \
					$curr_change0_dict $curr_leg_change0_dict $curr_leg_no]

				# Logic for appending leg change is different to 'bet' and 'bet change'
				# Simply append it now!
				dict lappend curr_change_dict leg_changes $leg_change_dict

			}

			# Current bet/change/leg will be last on next iteration
			set prev_bet_no $bet_no
			set prev_change_id $change_id
			set prev_leg_change_id $leg_change_id
		}

		# Last iteration remaining processing

		# Add the curr_bet_change to the list of changes for this bet
		dict lappend curr_bet_dict bet_changes $curr_change_dict

		# Add the curr_bet_change0 to the list of changes for this bet
		dict lappend curr_bet_dict bet_changes $curr_change0_dict

		# Add the curr_bet to the bet_change_history_list, after final processing
		set curr_bet_dict [_process_bet_changes $curr_bet_dict]
		lappend bet_change_history_list $curr_bet_dict
		core::db::rs_close -rs $rs

		return $bet_change_history_list
	}

#
# Private procedures
#

# Helper procedures for bet change history processing
#
# Update (or insert) the leg_change0 for this leg
#
proc core::history::bet::_update_leg_change0 {change0_dict new_leg_change0_dict curr_leg_no} {
	set leg_changes_list [list]
	set found 0
	foreach leg_change [dict get $change0_dict leg_changes] {

		if {[dict get $leg_change leg_no] == $curr_leg_no} {
			lappend leg_changes_list $new_leg_change0_dict
			set found 1
		} else {
			lappend leg_changes_list $leg_change
		}
	}

	# There was no previous leg_change0 for this leg, add it
	if {$found == 0} {
		lappend leg_changes_list $new_leg_change0_dict
	}
	dict set change0_dict leg_changes $leg_changes_list
	return $change0_dict
}


# A generic function that works at either the bet_change or leg_change level.
# This function performs the 'compare current with change0' algorithm
#
# This algorithm only works as you walk backwards through the t(O)BetHist rows
#
# current_dict: A dictionary of the current row of the result set's values
#               from the bet history query
#
# change0_dict: The currently built-up version of the change0 dictionary
#               at the current point in time.  This is required to compare
#               what already exists in the change0 dict.
#
# bet_dict:     A dictionary with the same key names as current_dict
#               which holds the most recent state of the bet.  These
#               values can be used to fill in the bet_change structures.
#
# var_list:     A list of the keys to process in the above 3 dictionaries.
#
# Returns:      Copies of the updated current and change0 dicts passed in
#               with the values set/swapped around as required as a TCL list
proc core::history::bet::_perform_change0_diff {current_dict change0_dict bet_dict var_list} {
	# Build the change0 'object' from this 'object' (bet or leg) change
	set ignore_list [list]
	foreach name $var_list {
		# The value was added previously as part of a compound value
		if {[lsearch $ignore_list $name] != -1} {
			continue
		}
		set key_id [lindex [dict keys $current_dict {*change_id}] 0]
		set id [dict get $current_dict $key_id]
		set change0_val [dict get $change0_dict $name]
		set change_val  [dict get $current_dict $name]
		set bet_val     [dict get $bet_dict $name]

		if {($change_val != $change0_val)} {
			# Take in special consideration compound values such as price or each way terms
			switch -exact -- $name {
				price_num {
					set paired_name price_den
				}
				price_den {
					set paired_name price_num
				}
				ew_fac_num {
					set paired_name ew_fac_den
				}
				ew_fac_den {
					set paired_name ew_fac_num
				}
				default {
					set paired_name ""
				}
			}

			if {$change0_val != {}} {
				# This value is different from what is in change0, update change0
				dict set change0_dict $name $change_val
				dict set current_dict $name $change0_val
				if {$paired_name != ""} {
					set pair_change_val  [dict get $current_dict $paired_name]
					set pair_change0_val [dict get $change0_dict $paired_name]
					dict set change0_dict $paired_name $pair_change_val
					dict set current_dict $paired_name $pair_change0_val
				}
			} elseif {$change_val != $bet_val} {
				# This value does not exist in the change0 structure, add it
				dict set change0_dict $name $change_val
				dict set current_dict $name $bet_val
				if {$paired_name != ""} {
					set pair_change_val  [dict get $current_dict $paired_name]
					set pair_change0_val [dict get $bet_dict     $paired_name]
					dict set change0_dict $paired_name $pair_change_val
					dict set current_dict $paired_name $pair_change0_val
				}
			} else {
				if {$paired_name == ""} {
					# Clear the value in the current dict if these values are the same
					dict set current_dict $name {}
				} else {
					# Check if the paired value has changed
					set paired_change_val [dict get $current_dict $paired_name]
					set paired_bet_val    [dict get $bet_dict $paired_name]
					if {$paired_change_val == $paired_bet_val} {
						# None of both values changed:
						# Clear the value in the current dict if these values are the same
						dict set current_dict $name {}
						dict set current_dict $paired_name {}
					} else {
						# The paired value has changed, don't add it to ignore list
						set paired_name ""
					}
				}
			}
			if {$paired_name != ""} {
				# We don't want to update the value twice
				lappend ignore_list $paired_name
			}
		}
	}
	return [list $current_dict $change0_dict]
}


#
# A helper function to reverse the list of bet changes and number
# them accordingly
#
proc core::history::bet::_process_bet_changes {bet_dict} {

	# Foreach on the bet_changes, add the change numbers and sort by leg_no
	set bet_change_index 0
	set orig_bet_changes_list [dict get $bet_dict bet_changes]
	dict set bet_dict bet_changes [list]

	# Reverse loop through the bet changes
	for {set i [expr [llength $orig_bet_changes_list] - 1]} {$i >= 0} {incr i -1} {
		set change [lindex $orig_bet_changes_list $i]
		dict set change change_no $bet_change_index

		# Adding a reason code to changeNo = 0 to make this more readable
		if {$bet_change_index == 0} {
			dict set change reason_code "ORIGINAL_VALUES"
			dict set change reason_desc "Original values"
		}
		# sort the legs on the list of leg changes
		# This is only required for multiples to work correctly
		set leg_changes_list [lsort -index 1 [dict get $change leg_changes]]
		dict set change leg_changes $leg_changes_list

		dict lappend bet_dict bet_changes $change
		incr bet_change_index
	}

	return $bet_dict
}


# Prepare all queries
#
# Four queries must be prepared for each combination of filters
# (pagination query + main query with and without last id)
# This results in 40 possible queries which may be used by get_page.
proc core::history::bet::_prep_queries {} {
	variable CFG

	set group_id_values    {ALL}
	set group_order_values {ALL}
	if {$CFG(show_betgroup_info)} {
		lappend group_id_values    bet_group_id
		lappend group_order_values bet_group_order
	}

	foreach settled {Y N ALL} {
		foreach hierarchy_filter {ev_class_id ev_category_id ALL} {
			foreach first_page {Y N} {

				foreach group_id $group_id_values {
					foreach group_order $group_order_values {
						set filter_list [list $first_page $settled $hierarchy_filter cr_date $group_order $group_id]
						_prep_qry pagination {*}$filter_list
						_prep_qry main       {*}$filter_list
					}
				}
			}
		}
	}

	# This should be called only if acct_id has been added to tBetStl
	if {$CFG(settled_at_filtering)} {
		foreach first_page {Y N} {
			_prep_qry pagination $first_page Y ALL settled_at
			_prep_qry main       $first_page Y ALL settled_at
		}
	}

	# Leg type could be set at the bet level or the leg level
	set leg_type [core::db::schema::add_sql_column -table tOBet -column leg_type \
		-alias {ob.leg_type} -default {b.leg_type}]

	set leg_status [core::db::schema::add_sql_column -table tOBet -column status \
	-alias {ob.status as leg_status} -default {b.status as leg_status}]

	# Part sort
	set part_sort [core::db::schema::add_sql_column -table tOBet -column part_sort \
		-alias {ob.part_sort} -default {'' as part_sort}]

	# Token Payout
	set token_payout [core::db::schema::add_sql_column -table tBet -column token_payout \
		-alias {b.token_payout} -default {'' as token_payout}]

	# Bet history
	if {$CFG(use_change_history)} {
		set bet_history "b.num_hists,"
	} else {
		set bet_history ""
	}

	if {$CFG(show_italian_bet_history)} {
		if {[core::db::schema::table_column_exists -table tSGBet -column bet_ref_id]} {
			set bet_col {bet_ref_id}
		} else {
			set bet_col {bet_id}
		}
		set sogei_cols {, NVL(sg.status, 'U') as sg_status, sg.ticket_id}
		set sg_table [subst {left outer join (tSGBet sg) on (sg.$bet_col = b.bet_id)}]
	} else {
		set sogei_cols {}
		set sg_table {}
	}

	if {$CFG(sfb_tag_for_results)!={}} {
		set result_col {ocr.place as oc_place, ocr.result as oc_result, ocr.result_conf}
		set sfb_table  {inner join tEvOcResult ocr on (ob.ev_oc_id = ocr.ev_oc_id)}
		set sfb_check  "and ocr.tag = '$CFG(sfb_tag_for_results)'"
	} else {
		set result_col {o.place as oc_place, o.result as oc_result, o.result_conf}
		set sfb_table  {}
		set sfb_check  {}

		if {$CFG(show_result_set_at)} {
			append result_col {, o.result_set_at as oc_result_set_at}
		} else {
			append result_col {, '' as oc_result_set_at}
		}
	}

	if {$CFG(show_betgroup_info)} {
		set betgroup_cols  {, gbs.grpd_bet_id, gbs.grpd_bet_order, gb.grpd_bet_type}
		set betgroup_table {
			left outer join (
				tGrpdBets gbs
				inner join tGrpdBet gb on (gbs.grpd_bet_id = gb.grpd_bet_id)
			) on (b.bet_id = gbs.bet_id)
		}
	} else {
		set betgroup_cols  {}
		set betgroup_table {}
	}

	# ID and receipt queries
	#
	# OVERVIEW
	# These should use the index on bet_id or receipt to retrieve a bet.
	#
	# EXPECTED USAGE:
	# TODO
	#
	# TESTING:
	# Tested against an account with 3856 bets
	# Explain plan follows the ordering below. # of Buffer reads = 189
	#
	# EXPECTED IMPACT:
	# TODO
	set query [subst {
		select
		%s
			[core::db::schema::add_sql_column -table tEvCategory -column ev_category_id -alias {y.ev_category_id} -default {y.category as ev_category_id}],
			[core::db::schema::add_sql_column -table tEvCategory -column name -alias {y.name as ev_category_name} -default {y.category as ev_category_name}],
			ab.org_stake_per_line as async_org_stk_line,
			ab.reason_code as async_cancel_reason,
			ab.status as async_status,
			b.bet_id as id,
			b.bet_type,
			b.cr_date,
			b.leg_type,
			b.num_legs,
			b.num_lines,
			b.num_lines_lose,
			b.num_lines_void,
			b.num_lines_win,
			b.num_selns,
			b.potential_payout,
			b.receipt,
			b.refund,
			b.settled,
			b.settled_at,
			b.settle_info,
			b.source,
			b.stake,
			b.stake_per_line,
			b.status,
			b.token_value,
			b.winnings,
			b.call_id,
			b.placed_by,
			b.user_id,
			b.bonus,
			b.tax,
			b.tax_type,
			b.tax_rate,
			b.paid,
			b.unique_id,
			$token_payout,
			$bet_history
			c.ev_class_id,
			c.name as ev_class_name,
			e.desc as ev_name,
			e.ev_id,
			e.race_number,
			e.start_time,
			e.venue,
			$leg_status,
			$leg_type,
			nvl(m.name, trim(g.name)) as mkt_name,
			nvl(m.name, trim(g.name)) as mkt_name_raw,
			m.blurb as mkt_blurb,
			m.ev_mkt_id as mkt_id,
			m.sort as mkt_sort,
			m.type as mkt_type,
			m.hcap_makeup as mkt_hcap_makeup,
			case when m.ew_with_bet = 'N' then m.ew_fac_den else ob.ew_fac_den end as ew_fac_den,
			case when m.ew_with_bet = 'N' then m.ew_fac_num else ob.ew_fac_num end as ew_fac_num,
			case when m.ew_with_bet = 'N' then m.ew_places else ob.ew_places end as ew_places,
			mb.desc_1 as man_desc_1,
			mb.desc_2 as man_desc_2,
			mb.desc_3 as man_desc_3,
			mb.desc_4 as man_desc_4,
			mb.to_settle_at,
			nvl(o.fb_result, 'N') as fb_result,
			ob.banker,
			ob.bir_index,
			ob.hcap_value,
			ob.in_running,
			ob.leg_no,
			ob.leg_sort,
			ob.no_combi,
			ob.part_no,
			$part_sort,
			ob.price_type,
			case when ob.price_type='S' then o.sp_den else ob.o_den end as price_den,
			case when ob.price_type='S' then o.sp_num else ob.o_num end as price_num,
			o.desc as oc_name,
			o.ev_oc_id as oc_id,
			$result_col,
			o.runner_num,
			o.sp_den,
			o.sp_num,
			t.ev_type_id,
			t.name as ev_type_name,
			r.market,
			r.deduction,
			r.time_from,
			r.time_to
			$sogei_cols
			$betgroup_cols
		from tBet b
		left outer join (
			tOBet ob
			inner join tEvOc o on (ob.ev_oc_id = o.ev_oc_id)
			$sfb_table
			inner join tEvMkt m on (o.ev_mkt_id = m.ev_mkt_id)
			inner join tEvOcGrp g on (m.ev_oc_grp_id = g.ev_oc_grp_id)
			inner join tEv e on (m.ev_id = e.ev_id)
			inner join tEvType t on (e.ev_type_id = t.ev_type_id)
			inner join tEvClass c on (t.ev_class_id = c.ev_class_id)
			inner join tEvCategory y on (c.category = y.category)
			left outer join (tEvMktRule4 r)
				on (m.ev_mkt_id = r.ev_mkt_id)
		) on (b.bet_id = ob.bet_id)
		left outer join (
			tManOBet mb
		) on (b.bet_id = mb.bet_id)
		left outer join (
			tAsyncBetOff ab
		) on (b.bet_id = ab.bet_id)
		$sg_table
		$betgroup_table
		where
			%s
			$sfb_check
			and b.acct_id = ?
		order by
			b.bet_id,
			ob.leg_no,
			ob.part_no
	}]

	core::db::store_qry -name core::history::bet::id \
		-qry [format $query [get_config -name id_directive] {b.bet_id = ?}] \
		-cache 0

	core::db::store_qry -name core::history::bet::receipt \
		-qry [format $query [get_config -name receipt_directive] {b.receipt = ?}] \
		-cache 0

	if {[get_config -name bet_get_item_by_uuid]} {
		core::db::store_qry -name core::history::bet::uuid \
			-qry [format $query [get_config -name uuid_directive] {b.uuid = ?}] \
			-cache 0
	}

	set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]

	core::db::store_qry -name core::history::bet::ids \
		-qry [format $query [get_config -name id_directive] "b.bet_id in ($ph)"] \
		-cache 0

}

# Prepare the pagination or range query for a given combination of filters.
#
# OVERVIEW:
#
# The pagination query has FIRST to restrict the date range as much as we can.
# We avoid ordering by bet_id at this stage so the right indexes are used.
#
# The main query then pulls back all details for the page, and does the full
# ordering, including bet_id.
#
# If settled = N, we use tBetUnstl. The query always looks at all the
# customer's unsettled bets, but this number is expected to be small.
#
# If settled = Y we can either use tBetStl.settled_at or tBet.cr_date to
# delimit the page. The composite index with acct_id is used in both cases.
#
# If settled = ALL we use the acct_id, cr_date index on tBet.
#
# If hierarchy filters are applied, the query could examine *all* tOBet
# rows looking for a match. By default we restrict the date range to 1 day
# to keep this number managable. This value is controlled by the init flag
# -restricted_filter_max_days.
#
# EXPECTED USAGE:
#
# Very large histories could contain ~10,000 settled bets and ~100 unsettled bets.
# An average user could be expected to have around ~100 bets
#
# We expect the number of bets placed in one day to be < 100.
#
# TESTING:
#
# The following accounts were used for testing:
# 1) 3756 settled, 100 unsettled bets
# 2) 11096/48368 settled bets
# 3) 216 settled bets with 101 placed at the same time
# 4) 430 settled bets (settled_at queries)
#
# A page size of 10 was used. Date range was restricted to 1 day
# for restricted filtering, and all of time for the other queries.
#
# All query plans followed the specified ordering.
# The following buffer read values were observed:
#
# Value  Query
# -------------------------------------------------------------------
#     -  core::history::bet::pagination.Y.Y.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.Y.ev_class_id.cr_date.ALL.ALL
#  1727  core::history::bet::pagination.N.Y.ev_class_id.cr_date.ALL.ALL
#   568  core::history::bet::main.N.Y.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.Y.ev_category_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.Y.ev_category_id.cr_date.ALL.ALL
#  2432  core::history::bet::pagination.N.Y.ev_category_id.cr_date.ALL.ALL
#  1790  core::history::bet::main.N.Y.ev_category_id.cr_date.ALL.ALL
#    89  core::history::bet::pagination.Y.Y.ALL.cr_date.ALL.ALL
#   166  core::history::bet::main.Y.Y.ALL.cr_date.ALL.ALL
#    91  core::history::bet::pagination.N.Y.ALL.cr_date.ALL.ALL
#   156  core::history::bet::main.N.Y.ALL.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.N.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.N.ev_class_id.cr_date.ALL.ALL
#  3419  core::history::bet::pagination.N.N.ev_class_id.cr_date.ALL.ALL
#   659  core::history::bet::main.N.N.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.N.ev_category_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.N.ev_category_id.cr_date.ALL.ALL
#  4331  core::history::bet::pagination.N.N.ev_category_id.cr_date.ALL.ALL
#  1445  core::history::bet::main.N.N.ev_category_id.cr_date.ALL.ALL
#  1120  core::history::bet::pagination.Y.N.ALL.cr_date.ALL.ALL
#  1093  core::history::bet::main.Y.N.ALL.cr_date.ALL.ALL
#   301  core::history::bet::pagination.N.N.ALL.cr_date.ALL.ALL
#  1029  core::history::bet::main.N.N.ALL.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.ALL.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.ALL.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::pagination.N.ALL.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::main.N.ALL.ev_class_id.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.ALL.ev_category_id.cr_date.ALL.ALL
#     -  core::history::bet::main.Y.ALL.ev_category_id.cr_date.ALL.ALL
#     -  core::history::bet::pagination.N.ALL.ev_category_id.cr_date.ALL.ALL
#     -  core::history::bet::main.N.ALL.ev_category_id.cr_date.ALL.ALL
#    79  core::history::bet::pagination.Y.ALL.ALL.cr_date.ALL.ALL
#   121  core::history::bet::main.Y.ALL.ALL.cr_date.ALL.ALL
#    89  core::history::bet::pagination.N.ALL.ALL.cr_date.ALL.ALL
#   136  core::history::bet::main.N.ALL.ALL.cr_date.ALL.ALL
#     -  core::history::bet::pagination.Y.Y.ALL.settled_at.ALL.ALL
#     -  core::history::bet::main.Y.Y.ALL.settled_at.ALL.ALL
#    86  core::history::bet::pagination.N.Y.ALL.settled_at.ALL.ALL
#   115  core::history::bet::main.N.Y.ALL.settled_at.ALL.ALL
#
# If show_betgroup_info is enabled, the first 4 filters are combined with the bet group id and bet group order filters.
#     -  core::history::bet::*.*.*.*.cr_date.bet_group_order.ALL
#     -  core::history::bet::*.*.*.*.cr_date.bet_group_order.bet_group_id
#     -  core::history::bet::*.*.*.*.cr_date.ALL.bet_group_id
#
# EXPECTED IMPACT:
#
# There are two prepared statements for every allowed combination of filters.
# The "main" query is run every time the "pagination" query returns results.
# None of the queries are cached.
#
# The use of these queries will be proportional to the # of users using
# the application. We expect most users to only visit the first page, with
# default filtering, so we can assume that that form of the queries will be
# run about 10x as often as each of the others.
proc core::history::bet::_prep_qry {query_type first_page settled hierarchy_filter date_filter {bet_group_order ALL} {bet_group_id ALL}} {

	variable CFG

	set name [format "core::history::bet::%s.%s.%s.%s.%s.%s.%s" \
		$query_type \
		$first_page \
		$settled \
		$hierarchy_filter \
		$date_filter \
		$bet_group_order \
		$bet_group_id]

	if {$query_type == {pagination}} {
		set directive_name get_pagination_directive
	} else {
		set directive_name get_range_directive
	}

	set betgroup_filter   ""
	set betgroup_where    ""

	if {$CFG(show_betgroup_info)} {

		if {$bet_group_order != {ALL}} {
			set betgroup_filter "tGrpdBets gbs,"
			append betgroup_where " and gbs.grpd_bet_order = ?"
		}

		if {$bet_group_id != {ALL}} {
			set betgroup_filter "tGrpdBets gbs,"

			set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]
			append betgroup_where " and gbs.grpd_bet_id in ( $ph ) and gbs.bet_id = b.bet_id"
		}
	}

	# The basic query forms.
	# If this is not the first page, the min_date and last_id values will
	# be used to anchor the start of the page at the right bet.
	set alias {b}
	switch -glob $settled.$date_filter {
		Y.cr_date {
			# SETTLED by cr_date
			set from {
				tBet b
			}
			set where {
				b.acct_id = ?
				and b.cr_date between ? and ?
				and b.settled = 'Y'
			}
		}
		Y.settled_at {
			# SETTLED by settled_at
			set alias {s}
			set select {s.settled_at}
			set from {
				tBetStl s
			}
			if {$query_type != {pagination}} {
				append from {inner join tBet b on (s.bet_id = b.bet_id)}
			}
			set where {
				s.acct_id = ?
				and s.settled_at between ? and ?
			}
			append directive_name {_settled}
		}
		N.* {
			# UNSETTLED
			set from {
				tBetUnstl u
				inner join tBet b on (u.bet_id = b.bet_id)
			}
			set where {
				u.acct_id = ?
				and b.cr_date between ? and ?
			}
			append directive_name {_unsettled}
		}
		default {
			# ALL
			set from {
				tBet b
			}
			set where {
				b.acct_id = ?
				and b.cr_date between ? and ?
			}
		}
	}


	set select ""
	if {$query_type == {pagination}} {
		set select "$alias.$date_filter"
	}

	# Ensures the page starts at the right place
	if {$first_page == {N}} {
		if {$date_filter == {settled_at}} {
			append where "and (s.settled_at < ? or (s.settled_at = ? and s.bet_id < ?))"
		} else {
			append where "and b.bet_id < ?"
		}
	}
	
	set bet_status_filters [list]

	if {[string length $CFG(hide_bets_with_statuses)]} {
		set bet_status_filters [split $CFG(hide_bets_with_statuses)]
	}

	if {$CFG(hide_cancelled_bets)} {
		core::log::write INFO {This procedure is deprecated. You should pass\
			in 'X' in the configuration HIST_HIDE_BET_WITH_STATUS}

		lappend bet_status_filters X
	}

	# Combine the bet statuses into a single query to filter
	if {[llength $bet_status_filters]} {
		core::log::write DEBUG {bet_status_filters=$bet_status_filters}

		append where \
			" and b.status NOT IN ('[join $bet_status_filters {','}]')"
	}

	# Handling for hierarchy filtering (not applicable if date_filter is "settled_at")
	switch -- $hierarchy_filter {
		ev_class_id {
			append from {
				inner join tOBet ob on (b.bet_id = ob.bet_id)
				inner join tEvOc o on (ob.ev_oc_id = o.ev_oc_id)
				inner join tEv e on (o.ev_id = e.ev_id and e.ev_class_id = ?)
			}
		}
		ev_category_id {
			append from {
				inner join tOBet ob on (b.bet_id = ob.bet_id)
				inner join tEvOc o on (ob.ev_oc_id = o.ev_oc_id)
				inner join tEv e on (o.ev_id = e.ev_id)
				inner join tEvClass c on (e.ev_class_id = c.ev_class_id)
				inner join tEvCategory y on (c.category = y.category and y.ev_category_id = ?)
			}
		}
		ev_mkt_id {
			append from {
				inner join tOBet ob on (b.bet_id = ob.bet_id)
				inner join tEvOc o on (ob.ev_oc_id = o.ev_oc_id)
				inner join tEvMkt m on (o.ev_mkt_id = m.ev_mkt_id)
			}
		}
	}

	# Italian specific info
	if {$CFG(show_italian_bet_history)} {
		if {[core::db::schema::table_column_exists -table tSGBet -column bet_ref_id]} {
			set bet_col {bet_ref_id}
		} else {
			set bet_col {bet_id}
		}
		append select {
			, NVL(sg.status, 'U') as sg_status, sg.ticket_id
		}
		append from [subst {
			left outer join tSGBet sg on (b.bet_id = sg.$bet_col)
		}]
	}


	set directive [get_config -name $directive_name]
	set limit     [expr {[get_config -name max_page_size] + 1}]

	# If we join on tOBet we need to filter out duplicate rows in case multiple legs/parts match
	set distinct {}
	if {$hierarchy_filter != {ALL}} {
		set distinct {distinct}
		append select ", b.acct_id, b.bet_id"
	}

	# Token Payout for summary
	set token_payout [core::db::schema::add_sql_column -table tBet -column token_payout \
		-alias {, b.token_payout} -default {, '' as token_payout}]
	append select $token_payout

	if {$query_type == {pagination}} {
		core::db::store_qry -cache 0 -name $name -qry [subst {
			select $directive
			first $limit $distinct
				$select
			from
				$betgroup_filter
				$from
			where
				$where
				$betgroup_where
			order by $alias.acct_id desc, $alias.$date_filter desc
		}]
	} else {
		core::db::store_qry -cache 0 -name $name -qry [subst {
			select $directive
			$distinct
				b.bet_id as id,
				b.bet_type,
				b.cr_date,
				b.leg_type,
				b.num_legs,
				b.num_lines,
				b.num_selns,
				b.potential_payout,
				b.receipt,
				b.refund,
				b.settled,
				b.settled_at,
				b.source,
				b.stake,
				b.stake_per_line,
				b.status,
				b.token_value,
				b.winnings
				$select
			from
				$betgroup_filter
				$from
			where
				$where
				$betgroup_where
			order by b.$date_filter desc, b.bet_id desc
		}]
	}
}


proc core::history::bet::_prep_qry_bet_hist {} {
	# Bet change history query
	#
	# OVERVIEW:
	#
	# The bet change history query will retrieve all changes at the bet and selection
	# level, for a list of given bet_ids, plus the current state of the bet and selections.
	#
	# EXPECTED USAGE:
	#
	# There is no documentation on how our clients will use the bet change feature or
	# how many changes will a bet usually have.
	#
	# TESTING:
	# Ran with a list of 40 bet_ids and took 1184 buffer reads.
	#
	# EXPECTED IMPACT:
	#
	# This query will be run for getting the list of bet changes for a particular user and
	# is not yet defined how often will execute it.
	#

	# Prepare the list of x placeholders
	variable CFG
	set list_placeholders [list]
	for {set i 0} {$i < $CFG(bet_hist_batch_size)} {incr i} {
		lappend list_placeholders "?"
	}
	set placeholders [join $list_placeholders {,}]
	set qry_bet_hist [subst {
		select
			-- Bet Info
			b.bet_id,
			b.stake_per_line,
			b.potential_payout,
			b.stake,
			b.cr_date,

			-- OBet Info
			o.ev_oc_id,
			o.leg_no,
			o.o_num,
			o.o_den,
			o.ew_fac_num,
			o.ew_fac_den,
			o.ew_places,

			-- Bet History Info
			bh.bet_hist_id,
			bh.stake_per_line   bet_hist_stake_per_line,
			bh.potential_payout bet_hist_potential_payout,
			bh.stake            bet_hist_stake,
			case when
				bc.cashout_amount is null
			then
				NVL(bh.winnings,0)
			else
				NVL(bh.winnings,0) + bc.cashout_amount
			end		    bet_hist_winnings,
			bh.cr_date          bet_hist_date,
			bh.user_id          bet_hist_user_id,
			u.username          bet_hist_username,
			bhr.reason_code     bet_hist_reason_code,
			bhr.desc            bet_hist_reason_desc,

			-- OBet History Info
			oh.obet_hist_id,
			oh.o_num            ohist_o_num,
			oh.o_den            ohist_o_den,
			oh.ew_fac_num       ohist_ew_fac_num,
			oh.ew_fac_den       ohist_ew_fac_den,
			oh.ew_places        ohist_ew_places,

			-- BetCashout Info
			bc.cashout_amount   cashout_amount,
			bc.cr_date          cashout_date,
			bc.type             cashout_type,
			bc.location         cashout_location
		from
			tBet                b,
			tBetHist            bh,
			tBetHistReason      bhr,
			outer tAdminUser    u,
			outer (tOBetHist oh, tOBet o),
			outer tBetCashout   bc
		where
			    b.bet_id              = bh.bet_id
			AND bh.bet_hist_id        = oh.bet_hist_id
			AND oh.bet_id             = o.bet_id
			AND oh.leg_no             = o.leg_no
			AND oh.part_no            = o.part_no
			AND bh.bet_hist_reason_id = bhr.bet_hist_reason_id
			AND bh.user_id            = u.user_id
			AND bh.ref_id             = bc.bet_cashout_id
			AND %s
		order by
			b.bet_id            asc,
			bh.bet_hist_id      desc,
			oh.leg_no           asc
	}]

	core::db::store_qry -name core::history::bet::bet_hist \
		-qry [subst [format $qry_bet_hist {b.bet_id IN ($placeholders)}]]\
		-cache 0

	core::db::store_qry -name core::history::bet::bet_hist_id \
		-qry [format $qry_bet_hist {b.bet_id = ?}]  \
		-cache 0
}

# Work out the query and query parameters for the current set of filters
proc core::history::bet::_get_qry_args {name last_id acct_id date_from date_to filters} {

	variable CFG
	set sql_params        [list]
	set hierarchy_filter  {ALL}
	set groupid_filter    {ALL}
	set grouporder_filter {ALL}
	set ev_category_id    {ALL}
	set ev_mkt_id         {ALL}
	set ev_class_id       {ALL}
	set bet_group_id      {ALL}
	set bet_group_order   {ALL}

	set first_page     [expr {($last_id == -1) ? {Y} : {N}}]
	set settled        [dict get $filters settled]
	set date_filter    [dict get $filters date_field]

	if {[dict exists $filters ev_class_id]} {
		set ev_class_id [dict get $filters ev_class_id]
	}

	if {[dict exists $filters ev_category_id]} {
		set ev_category_id [dict get $filters ev_category_id]
	}

	if {[dict exists $filters ev_mkt_id]} {
		set ev_mkt_id [dict get $filters ev_mkt_id]
	}

	if {[dict exists $filters bet_group_id]} {
		set bet_group_id [dict get $filters bet_group_id]
	}

	if {[dict exists $filters bet_group_order]} {
		set bet_group_order [dict get $filters bet_group_order]
	}

	if {$ev_class_id != {ALL} && $ev_category_id != {ALL}} {
		core::log::write ERROR {Cannot specify both class and category}
		error INVALID_FILTER_COMBI
	}

	if {$ev_class_id != {ALL} && $ev_mkt_id != {ALL}} {
		core::log::write ERROR {Cannot specify both class and market}
		error INVALID_FILTER_COMBI
	}

	if {$ev_mkt_id != {ALL} && $ev_category_id != {ALL}} {
		core::log::write ERROR {Cannot specify both category and market}
		error INVALID_FILTER_COMBI
	}

	if {$bet_group_id == {ALL} && $bet_group_order != {ALL}} {
		core::log::write ERROR {Cannot specify bet group order without bet group id}
		error INVALID_FILTER_COMBI
	}

	if {$ev_class_id != {ALL}} {
		lappend sql_params $ev_class_id
		set hierarchy_filter {ev_class_id}
	}

	if {$ev_category_id != {ALL}} {
		lappend sql_params $ev_category_id
		set hierarchy_filter {ev_category_id}
	}

	if {$ev_mkt_id != {ALL}} {
		lappend sql_params $ev_mkt_id
		set hierarchy_filter {ev_mkt_id}
	}

	lappend sql_params $acct_id $date_from $date_to

	if {$first_page == "N"} {
		if {$date_filter == {settled_at}} {
			lappend sql_params $date_to $date_to $last_id
		} else {
			lappend sql_params $last_id
		}
	}

	if {$bet_group_order != {ALL}} {
		lappend sql_params $bet_group_order
		set grouporder_filter {bet_group_order}
	}

	if {$bet_group_id != {ALL}} {
		if {[llength $bet_group_id] > $CFG(max_page_size)} {
			core::log::write ERROR "Cannot specify more group ids than maximum number: $CFG(max_page_size)"
			error INVALID_FILTER_COMBI
		}
		set padded_list [core::util::lpad -list $bet_group_id -size $CFG(max_page_size) -padding -1]
		lappend sql_params {*}$padded_list
		set groupid_filter {bet_group_id}
	}

	if {$date_filter == {settled_at} && ($settled != {Y} || $hierarchy_filter != {ALL})} {
		core::log::write ERROR {Cannot send settled_at date field filter without settled="Y" filter}
		error INVALID_FILTER_COMBI
	}

	set name [format "core::history::bet::%s.%s.%s.%s.%s.%s.%s" \
		$name \
		$first_page \
		$settled \
		$hierarchy_filter \
		$date_filter \
		$grouporder_filter \
		$groupid_filter]

	return [dict create -name $name -args $sql_params]
}

# Format a detailed bet item dict given the result set
proc core::history::bet::_format_item {rs lang {l_bound {}} {u_bound {}}} {
	variable BET_COLS
	variable LEG_COLS
	variable PART_COLS
	variable DEDUCTION_COLS
	variable CFG

	set bet   [dict create group BET]

	if {$l_bound == {} && $u_bound == {}} {
		set nrows [db_get_nrows $rs]
		set lower_bound 0
		set upper_bound $nrows

	} elseif {$l_bound != {} && $u_bound != {}} {
		if {$l_bound > $u_bound} {
			core::log::write ERROR {core::history::bet::_format_item: l_bound should be less or equal than u_bound}
			error SERVER_ERROR {core::history::bet::_format_item: l_bound should be less or equal than u_bound}
		}

		set nrows [expr {$u_bound + 1}]
		set lower_bound $l_bound
		set upper_bound $u_bound
	} else {
		core::log::write ERROR {core::history::bet::_format_item: an index parameter is missing from the call}
		error SERVER_ERROR {core::history::bet::_format_item: an index parameter is missing from the call}
	}

	if {!$nrows} {
		core::log::write ERROR {No results found}
		error INVALID_ITEM {core::history::bet::_format_item returned < 1 row}
	}

	foreach {col xl} $BET_COLS {
		if {$xl} {
			switch -- $col {
				mkt_name {
					set value [core::xl::XL \
						-str   [db_get_col $rs $lower_bound $col] \
						-lang  $lang \
						-args  [list [db_get_col $rs $lower_bound bir_index]]]
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
			set value [db_get_col $rs $lower_bound $col]
		}
		dict set bet $col $value
	}

	# Manual bets have a description instead of legs
	if {[dict get $bet bet_type] == {MAN}} {
		dict set bet to_settle_at [db_get_col $rs $lower_bound to_settle_at]

		set man_desc {}
		foreach col {man_desc_1 man_desc_2 man_desc_3 man_desc_4} {
			append man_desc [db_get_col $rs $lower_bound $col]
		}

		set man_desc [core::xl::XL -str $man_desc -lang $lang]

		set man_desc [core::history::xl -value $man_desc]

		dict set bet man_desc $man_desc

		return $bet
	}

	# If not a manual bet, add the legs
	dict set bet legs [list]
	set leg           {}
	set part          {}
	set deduction     {}
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
			set part [dict create deductions [list]]
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

		# Add at the part the deductions
		set deduction_no [db_get_col $rs $i deduction]
		if {$deduction_no != {}} {
			set deduction [dict create]
			foreach {col xl} $DEDUCTION_COLS {
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
				dict set deduction $col $value
			}
			dict lappend part deductions $deduction
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
proc core::history::bet::is_restricted {filters} {

	set ev_category_id 0
	if {[dict exists $filters ev_category_id] && [dict get $filters ev_category_id] != {ALL}} {
		incr ev_category_id
	}

	set ev_class_id 0
	if {[dict exists $filters ev_class_id] && [dict get $filters ev_class_id] != {ALL}} {
		incr ev_class_id
	}

	set ev_mkt_id 0
	if {[dict exists $filters ev_mkt_id] && [dict get $filters ev_mkt_id] != {ALL}} {
		incr ev_mkt_id
	}

	return [expr {($ev_category_id || $ev_class_id || $ev_mkt_id) && ([dict get $filters settled] != N)}]
}


# Returns if all in the elements in the list are unsigned integer values
proc core::history::bet::check_uint_list { list args } {

	foreach item $list {
		if {![regexp {^0*([0-9]+)$} $item]} {
			return 0
		}
	}
	return 1
}
