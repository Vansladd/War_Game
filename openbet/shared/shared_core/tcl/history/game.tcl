

# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Bet history
#
set pkg_version 1.0
package provide core::history::game $pkg_version

package require core::args  1.0
package require core::db 1.0
package require core::db::schema 1.0
package require core::history
package require core::xl 1.0
package require core::xml 1.0
package require core::game_history_service 1.0

core::args::register_ns \
	-namespace     core::history::game \
	-version       $pkg_version \
	-dependent     [list core::args core::db core::db::schema core::history core::xl] \
	-desc          {Game history} \
	-docs          history/game.xml

namespace eval core::history::game {
	variable CFG
}

# Initialise the module
core::args::register \
	-proc_name core::history::game::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_GAME_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_GAME_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
		[list -arg -get_games_directive -mand 0 -check STRING \
			-default_cfg HIST_GET_GAMES_DIRECTIVE \
			-desc {Directive for get games query}] \
		[list -arg -get_games_details_from_db -mand 0 -check BOOL -default 0 \
			-default_cfg HIST_GET_GAMES_DETAILS_FROM_DB \
			-desc {Controls whether games Detailed info will be retrieved from db instead of GHS}] \
		[list -arg -escape_untranslated_entities -mand 0 -check BOOL -default 0 \
			-default_cfg HIST_ESCAPE_UNTRANSLATED_ENTITIES \
			-desc {Escape Untranslated Entities Characters for XML/HTML Printing}] \
	] \
	-body {
		variable CFG

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Game Module initialised with $formatted_name_value}
		}

		# Set Transaction Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			id                id           0 \
			cr_date           cr_date      0 \
			finished          finished     0 \
			stakes            stakes       0 \
			winnings          winnings     0 \
			name              display_name 1]

		if {[get_config -name get_games_details_from_db]} {

			#dictionary to populate , COLUMN_LIST query_to_call
			set CFG(detail_info) [list \
				gameplay_info     game_details_cols        core::history::game::get_game_detail_info \
				externalFund_info external_funds_cols      core::history::game::get_external_funds_info \
				progressive_info  progressive_details_cols core::history::game::get_progressive_details_info \
				bonus_info        bonus_info_cols          core::history::game::get_bonus_info \
				wageringreqt_info wagering_reqts_cols      core::history::game::get_wagering_reqt_info \
				heldfund_info     held_funds_cols          core::history::game::get_held_funds_info]

			set CFG(game_details_cols) [list \
				id                 0 \
				order              0 \
				summary_id         0 \
				cr_date            0 \
				started            0 \
				finished           0 \
				name               0 \
				game_name          1 \
				class              0 \
				stakes             0 \
				winnings           0 \
				status             0]


			set CFG(external_funds_cols) [list \
				rgs_xfer_id        0\
				ext_xfer_id        0\
				interaction        0\
				amount             0\
				token_amount       0\
				held_amount        0\
				type               0\
				status             0\
				summary_id         0\
				ext_type           0\
				ext_value          0\
				rgs_nrtoken        0\
				rgi_nrtoken        0]

			set CFG(progressive_details_cols) [list \
				play_id            0\
				id                 0\
				name               0\
				min_prize          0\
				jackpot            0\
				summary_id         0\
				stake_from         0\
				stakes             0\
				winnings           0\
				bonus_winnings     0\
				prog_contribution  0\
				draw_result        0]

			set CFG(bonus_info_cols) [list \
				name               0\
				description        1\
				customer_token_id  0\
				redeemed_amount    0\
				summary_id         0]

			set CFG(wagering_reqts_cols) [list \
				name               0\
				description        1\
				customer_token_id  0\
				op_type            0\
				summary_id         0\
				amount             0\
				balance            0]

			set CFG(held_funds_cols) [list \
				j_op_ref_id        0\
				name               0\
				description        1\
				customer_token_id  0\
				op_type            0\
				summary_id         0\
				amount             0\
				balance            0]
		}

		set CFG(max_page_size)     [core::history::get_config -name max_page_size]

		set filters [list \
			[list cg_id UINT ALL] \
		]

		core::history::add_combinable_group \
			-group                          GAME \
			-page_handler                   core::history::game::get_page \
			-range_handler                  core::history::game::get_range \
			-pagination_result_handler      core::history::game::get_pagination_rs \
			-filters                        $filters \
			-detail_levels                  {SUMMARY DETAILED} \
			-j_op_ref_keys                  {IGF}

		# Register history add item handler to history package
		core::history::add_item_handler \
			-group            {GAME} \
			-item_handler     core::history::game::get_item

		# Prepare queries
		core::history::game::_prep_queries
	}

# Get config
core::args::register \
	-proc_name core::history::game::get_config \
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


# Get a single item by an id or other key
core::args::register \
	-proc_name core::history::game::get_item \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -key     -mand 0 -check ASCII -default ID -desc {Key}] \
		[list -arg -value   -mand 1 -check UINT              -desc {Value}] \
	] \
	-body {
		variable CFG

		set handler {core::game_history_service::get_details}

		if {[get_config -name get_games_details_from_db]} {
			set handler {core::history::game::get_details}
		}
		core::log::write INFO {core::history::game::get_item will use handler: $handler}

		if {[catch {set ret [$handler \
			-acct_id $ARGS(-acct_id) -game_id $ARGS(-value) -lang $ARGS(-lang)]} err]} {
			core::log::write ERROR {Unable to get game details: $err}
			error $::errorCode $::errorInfo
		}

		set item $ret

		dict set item group {GAME}

		set item [core::history::formatter::apply \
			-item             $item \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-detail_level     {DETAILED}
		]

		return $item
	}


# Register proc core::history::game::get_page
# This proc is responsible to return the history game items
# It first calls get_pagination_rs to get the started boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]]
core::args::register \
	-proc_name core::history::game::get_page \
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

			if {$more_pages} {
				set new_boundary [dict get [lindex $results end] id]
				set new_max_date [dict get [lindex $results end] cr_date]
			}
		}

		core::db::rs_close -rs $rs

		return [list $new_boundary $new_max_date $results]
	}


# Get started date values for one page of game items
core::args::register \
	-proc_name core::history::game::get_pagination_rs \
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

# Get game items between a date range
# This should be called after get_pagination_rs with the date range reduced
# so that the expected number of rows scanned is equal to the max page size.
#
# The number of rows may be slightly more in the case where multiple
# games were played at max_date, so any extra must be removed in the code.
core::args::register \
	-proc_name core::history::game::get_range \
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

		set results [list]

		set query [_get_qry_args main $ARGS(-last_id) $ARGS(-acct_id) \
			$ARGS(-min_date) $ARGS(-max_date) $ARGS(-filters)]

		if {[catch {set rs [core::db::exec_qry {*}$query]} err]} {
			core::log::write ERROR {Unable to execute query: $err}
			error SERVER_ERROR $::errorInfo
		}

		set nrows [db_get_nrows $rs]

		if {$nrows < 1} {
			core::db::rs_close -rs $rs
			return [list]
		}

		if {$ARGS(-page_size) < $nrows} {
			set limit $ARGS(-page_size)
		} else {
			set limit $nrows
		}

		set results  [list]
		set game_ids [list]

		array set ADDITIONAL_STAKES [array unset ADDITIONAL_STAKES]
		array set ADDITIONAL_WINS   [array unset ADDITIONAL_WINS]
		array set DETAILED_INFO     [array unset DETAILED_INFO]

		for {set i 0} {$i < $limit} {incr i} {
			set item [dict create group GAME]
			set cg_game_id [db_get_col $rs $i id]

			lappend game_ids $cg_game_id

			set ADDITIONAL_STAKES($cg_game_id) 0.00
			set ADDITIONAL_WINS($cg_game_id)   0.00

			foreach {key colname translation} $CFG(summary_elements) {
				if {$translation} {
					set val [core::xl::XL -str [db_get_col $rs $i $colname] -lang $ARGS(-lang)]

					set val [core::history::xl -value $val]

					dict set item $key $val
				} else {
					set val [db_get_col $rs $i $colname]
					# If this is not a standalone game we should retrieve stakes and winnings
					# from tCGMasterSummary table (master_stakes and master_winnings)
					if {$key == {stakes} || $key == {winnings}} {
						if {[db_get_col $rs $i cg_master_id] != {}} {
							set val [db_get_col $rs $i master_${key}]
						}
					}
					dict set item $key $val
				}
			}

			set item [core::history::formatter::apply \
				-item            $item \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    $ARGS(-detail_level) \
			]

			lappend results $item
		}

		core::db::rs_close -rs $rs

		# Collect additional stake and winnings from progressive data
		set padded_list [core::util::lpad -list $game_ids -size $CFG(max_page_size) -padding -1]

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::game::get_progressive_data} \
				-args [list {*}$padded_list $ARGS(-acct_id)] \
			]} msg]} {
			core::log::write ERROR {Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}


		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set cg_game_id [db_get_col $rs $i cg_game_id]
			if {[db_get_col $rs $i stake_from] != {B}} {
				set ADDITIONAL_STAKES($cg_game_id) \
					[expr {$ADDITIONAL_STAKES($cg_game_id) + [db_get_col $rs $i stake]}]
			}

			set ADDITIONAL_WINS($cg_game_id) \
				[expr {$ADDITIONAL_WINS($cg_game_id) + [db_get_col $rs $i winnings] \
					+ [db_get_col $rs $i bonus_win]}]
		}
		core::db::rs_close -rs $rs


		# Collect additional stake and winnings from accumulator_data
		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::game::get_accumulator_data} \
				-args $padded_list \
			]} msg]} {
			core::log::write ERROR {Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set cg_game_id [db_get_col $rs $i cg_game_id]
			set ADDITIONAL_WINS($cg_game_id) \
				[expr {$ADDITIONAL_WINS($cg_game_id) + [db_get_col $rs $i sum_winnings]}]
		}

		# Add extra detailed information
		if {$ARGS(-detail_level) == "DETAILED" && [get_config -name get_games_details_from_db]} {
			foreach {dict_name column_list_name qry} $core::history::game::CFG(detail_info) {
				set ret [_get_detail_info $padded_list $ARGS(-lang) $qry $column_list_name]
				foreach item $ret {
					set item_id [dict get $item summary_id]
					set DETAILED_INFO($item_id,$dict_name) [list $item]
				}
			}
		}

		set total_results [list]

		# We have now collected all additional stakes and winnings, we have to
		# update the respective dicts in the result.
		foreach item $results {
			set cg_game_id       [dict get $item id]
			set current_stakes   [dict get $item stakes]
			set new_stakes       [expr {$current_stakes + $ADDITIONAL_STAKES($cg_game_id)}]
			set current_winnings [dict get $item winnings]
			set new_winnings     [expr {$current_winnings + $ADDITIONAL_WINS($cg_game_id)}]
			dict set item stakes   $new_stakes
			dict set item winnings $new_winnings
			if {$ARGS(-detail_level) == "DETAILED" && [get_config -name get_games_details_from_db]} {
				foreach {dict_name column_list_name qry} $core::history::game::CFG(detail_info) {
					if {[info exists DETAILED_INFO($cg_game_id,$dict_name)]} {
						dict set item $dict_name $DETAILED_INFO($cg_game_id,$dict_name)
					} else {
						dict set item $dict_name [list]
					}
				}
			}

			lappend total_results $item
		}

		return $total_results
	}

# Get Games Proc. Returns a list of games and game ids a user has played
#
core::args::register \
	-proc_name core::history::game::get_games \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
	] \
	-body {

		variable CFG

		set results [list]

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::game::get_games} \
				-args [list $ARGS(-acct_id)] \
		]} msg]} {
			core::log::write ERROR {Error executing $msg}
			error SERVER_ERROR $::errorInfo GHS_ERROR_DB
		}

		set nrows [db_get_nrows $rs]

		# The results will be a list of cg_id - name pairs
		for {set i 0} {$i < $nrows} {incr i} {
			lappend results [db_get_col $rs $i cg_id]
			set val [core::xl::XL -str [db_get_col $rs $i name] -lang $ARGS(-lang)]

			set val [core::history::xl -value $val]
			lappend results $val
		}

		return $results
	}


# Work out the query and query parameters for the current set of filters
proc core::history::game::_get_qry_args {name last_id acct_id date_from date_to filters} {
	set sql_params [list $acct_id $date_from $date_to]

	set first_page     [expr {($last_id == -1) ? {Y} : {N}}]
	set cg_id          [dict get $filters cg_id]


	if {!$first_page} {
		lappend sql_params $last_id
	}

	if {$cg_id != {ALL}} {
		lappend sql_params [dict get $filters cg_id]
		set cg_id {CG_ID}
	}

	set name [format "core::history::game::%s.%s.%s" \
		$name \
		$first_page \
		$cg_id]

	return [dict create -name $name -args $sql_params]
}


#
# Private Procedures
# Prepare All Queries
#
proc core::history::game::_prep_queries {} {

	variable CFG

	foreach first_page {Y N} {
		_prep_qry pagination $first_page ALL
		_prep_qry pagination $first_page CG_ID
		_prep_qry main       $first_page ALL
		_prep_qry main       $first_page CG_ID
	}

	set directive [get_config -name get_games_directive]

	if {[core::db::schema::table_exists -table tCGCmtyBonus]} {
		set bonus_filter {and g.cg_id not in (select cg_id from tCGCmtyBonus)}
	} else {
		set bonus_filter {}
	}

	core::db::store_qry -cache 0 -name core::history::game::get_games -qry [subst {
		select $directive
			unique(g.cg_id) as cg_id,
			g.name          as name
		from
			tCGGame g
			inner join tCGGameLastPlay lp on (g.cg_id = lp.cg_id)
			inner join tCGAcct ga         on (lp.cg_acct_id = ga.cg_acct_id)
		where
			ga.acct_id = ?
			and lp.cg_stack_id = 0
			$bonus_filter
		order by
			g.name
	}]

	# We just initialise the queries below we are not preparing them now.

	set CFG(progressive_data) {
		select
			ps.cg_game_id,
			NVL(ps.winnings,0.00) as winnings,
			p.stake_from,
			case when p.stake_rate = 0.00
			then ps.fixed_stake
			else ps.fixed_stake * pc.fx_rate
			end as stake,
			NVL(ps.bonus_win,0.00) as bonus_win
		from
			tCGProgSummary ps,
			tCGProgHist ph,
			tCGProgressive p,
			tCGProgCcy pc
		where
			ps.cg_game_id         IN (%s)
			AND ps.prog_hist_id   = ph.prog_hist_id
			AND ph.progressive_id = p.progressive_id
			AND ph.progressive_id = pc.progressive_id
			AND pc.ccy_code       = (select ccy_code from tAcct where acct_id = ?)
	}
	

	set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]
	set CFG(progressive_data) [format $CFG(progressive_data) $ph]

	core::db::store_qry \
		-cache 0 \
		-name core::history::game::get_progressive_data \
		-qry $CFG(progressive_data)

	set CFG(accumulator_data) {
		select
			cg_game_id,
			NVL(sum(winnings), 0.00) as sum_winnings
		from
			tCGAcclatorOutHist
		where
			cg_game_id IN (%s)
		group by 1
	}

	set CFG(accumulator_data) [format $CFG(accumulator_data) $ph]

	core::db::store_qry \
		-cache 0 \
		-name core::history::game::get_accumulator_data \
		-qry $CFG(accumulator_data)

	if {[get_config -name get_games_details_from_db]} {

		set CFG(game_id_subquery) {SELECT nvl(gs2.cg_game_id, gs1.cg_game_id)
				FROM                    tCGGameSummary gs1
					left outer join tCGGameSummary gs2 on (gs1.cg_master_id = gs2.cg_master_id)
				WHERE gs1.cg_game_id %s }

		set CFG(query_game_detail_info) {
			SELECT
				g.cg_id         as id,
				cg.order        as order,
				gs.cg_game_id   as summary_id,
				g.cr_date       as cr_date,
				gs.started      as started,
				f.finished      as finished,
				g.name          as name,
				g.display_name  as game_name,
				g.cg_class      as class,
				gs.stakes       as stakes,
				gs.winnings     as winnings,
				gs.state        as status
			FROM
				           tCGGameSummary    gs
				inner join tCGGame            g on (gs.cg_id         = g.cg_id)
				left outer join tCGChainGame cg on (g.cg_id          = cg.cg_id)
				left outer join tCGGsFinished f on (gs.cg_game_id    = f.cg_game_id)
			WHERE
				gs.cg_game_id IN (%s)
			ORDER BY
				cg.order, gs.cg_game_id;
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_game_detail_info_by_id \
			-qry [format $CFG(query_game_detail_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_game_detail_info_by_ids \
			-qry [format $CFG(query_game_detail_info) [format $CFG(game_id_subquery) "in ($ph)"]]

		set CFG(query_external_funds_info) {
			SELECT
				x.rgs_xfer_id,
				x.ext_xfer_id,
				x.interaction,
				x.amount,
				x.token_amount,
				x.held_amount,
				x.type,
				x.status,
				x.cg_game_id as summary_id,
				t.type as ext_type,
				ex.ext_fund_amount as ext_value,
				rgs_nrtoken,
				rgi_nrtoken
			from
				      tCGRGSXfer x
				left outer join (
					           tCGRGSExtXfer     ex
					inner join tCGRGSExtFundType t   on (ex.rgs_ext_fund_type_id = t.rgs_ext_fund_type_id)
				) on (x.rgs_xfer_id = ex.rgs_xfer_id)
			where
				x.cg_game_id         IN (%s);
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_external_funds_info_by_id \
			-qry [format $CFG(query_external_funds_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_external_funds_info_by_ids \
			-qry [format $CFG(query_external_funds_info) [format $CFG(game_id_subquery) "in ($ph)"]]

		set CFG(query_progressive_details_info) {
			SELECT
				ps.prog_play_id as play_id,
				p.progressive_id as id,
				p.name,
				ps.min_prize,
				ps.jackpot,
				ps.cg_game_id as summary_id,
				p.stake_from,
				case
					when p.stake_rate = 0.00
					then ps.fixed_stake
					else ps.fixed_stake * pc.fx_rate
				end                       as stakes,
				NVL(ps.winnings,0.00)     as winnings,
				NVL(ps.bonus_win,0.00)    as bonus_winnings,
				NVL(ph.contribution,0.00) as prog_contribution,
				dr.draw                   as draw_result
			FROM
					   tCGProgressive p
				inner join tCGProgHist    ph on (p.progressive_id  = ph.progressive_id)
				inner join tCGProgSummary ps on (ps.prog_hist_id   = ph.prog_hist_id)
				left outer join
					tCGProgDrawResult dr on (dr.prog_play_id   = ps.prog_play_id)
				inner join tCGProgCcy     pc on (pc.progressive_id = ph.progressive_id)
			WHERE
				ps.cg_game_id  IN (%s) ;
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_progressive_details_info_by_id \
			-qry [format $CFG(query_progressive_details_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_progressive_details_info_by_ids \
			-qry [format $CFG(query_progressive_details_info) [format $CFG(game_id_subquery) "in ($ph)"]]

		set CFG(query_bonus_info) {
			SELECT
				o.name,
				o.description,
				ct.cust_token_id     as customer_token_id,
				tr.redemption_amount as redeemed_amount,
				tr.redemption_id     as summary_id
			FROM
				           tOffer              o
				inner join tToken              t on (o.offer_id         = t.offer_id)
				inner join tCustomerToken     ct on (t.token_id         = ct.token_id)
				inner join tCustTokRedemption tr on (ct.cust_token_id   = tr.cust_token_id)
			WHERE
				    tr.redemption_type in ('FOG', 'IGF')
				AND tr.redemption_id   IN (%s) ;
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_bonus_info_by_id \
			-qry [format $CFG(query_bonus_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_bonus_info_by_ids \
			-qry [format $CFG(query_bonus_info) [format $CFG(game_id_subquery) "in ($ph)"]]

		set CFG(query_wagering_reqt_info) {
			SELECT
				o.name,
				o.description,
				ct.cust_token_id as customer_token_id,
				cj.j_op_type     as op_type,
				cj.j_op_ref_id   as summary_id,
				cj.amount,
				cj.balance
			FROM
				           tOffer          o
				inner join tToken          t on (o.offer_id          = t.offer_id)
				inner join tCustomerToken ct on (t.token_id          = ct.token_id)
				inner join tCGCustWgrReqt wr on (ct.cust_token_id    = wr.cust_token_id)
				inner join tCGCustWRJrnl  cj on (wr.cust_wgr_reqt_id = cj.cust_wgr_reqt_id)
			WHERE
				    cj.j_op_ref_key  = 'IGF'
				AND cj.j_op_ref_id  IN (%s) ;
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_wagering_reqt_info_by_id \
			-qry [format $CFG(query_wagering_reqt_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_wagering_reqt_info_by_ids \
			-qry [format $CFG(query_wagering_reqt_info) [format $CFG(game_id_subquery) "in ($ph)"]]

		set CFG(query_held_funds_info) {
			SELECT
				j_op_ref_id,
				o.name,
				o.description,
				ct.cust_token_id as customer_token_id,
				cj.j_op_type     as op_type,
				cj.j_op_ref_id   as summary_id,
				cj.amount,
				cj.balance
			FROM
				          tOffer           o
				inner join tToken          t  on (o.offer_id           = t.offer_id)
				inner join tCustomerToken  ct on (t.token_id           = ct.token_id)
				inner join tCGCustWgrReqt  wr on (ct.cust_token_id     = wr.cust_token_id)
				inner join tCGCustHeldFund hf on (wr.cust_wgr_reqt_id  = hf.cust_wgr_reqt_id)
				inner join tCGCustHFJrnl   cj on (hf.cust_held_fund_id = cj.cust_held_fund_id)
			WHERE
				    cj.j_op_ref_key  = 'IGF'
				AND cj.j_op_ref_id  IN (%s) ;
		}

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_held_funds_info_by_id \
			-qry [format $CFG(query_held_funds_info) [format $CFG(game_id_subquery) "= ?"]]

		core::db::store_qry \
			-cache 0 \
			-name core::history::game::get_held_funds_info_by_ids \
			-qry [format $CFG(query_held_funds_info) [format $CFG(game_id_subquery) "in ($ph)"]]
	}
}


# Prepare the pagination or range query for a given combination of filters.
#
proc core::history::game::_prep_qry {query_type first_page cg_id} {

	set name [format "core::history::game::%s.%s.%s" \
		$query_type \
		$first_page \
		$cg_id]

	if {$query_type == {pagination}} {
		set directive_name get_pagination_directive
	} else {
		set directive_name get_range_directive
	}

	set directive [get_config -name $directive_name]
	set limit     [expr {[get_config -name max_page_size] + 1}]

	if {$query_type == {pagination}} {
		set where { and s.started between ? and ?}
		if {$first_page == {N}} {
			append where { and s.cg_game_id < ?}
		}
		if {$cg_id == {CG_ID}} {
			append where { and s.cg_id = ?}
		}
		core::db::store_qry -cache 0 -name $name -qry [subst {
			select $directive
			first $limit
				s.started as cr_date
			from
				tCGGameSummary s
			where
				s.cg_acct_id = (select cg_acct_id from tCGAcct ga where ga.acct_id = ?)
				$where
				and (
					s.cg_master_id is null
					or exists (
						select 1
						from tCGChainGame c
						where s.cg_id = c.cg_id
						and c.order = 1
					)
				)
			order by s.cg_acct_id desc, s.started desc
		}]
	} else {

		if {[core::db::schema::table_exists -table tCGCmtyBonus]} {
			set bonus_filter { and g.cg_id not in (select cg_id from tCGCmtyBonus)}
		} else {
			set bonus_filter {}
		}

		if {$first_page == {N}} {
			set page_filter { and s.cg_game_id < ?}
		} else {
			set page_filter {}
		}

		if {$cg_id == {CG_ID}} {
			set cg_filter { and s.cg_id = ?}
		} else {
			set cg_filter {}
		}

		core::db::store_qry -cache 0 -name $name -qry [subst {
			select $directive
				s.cg_acct_id,
				f.finished,
				g.display_name,
				s.cg_game_id as id,
				s.stakes,
				s.started as cr_date,
				s.state,
				s.stakes,
				s.winnings,
				s.cg_master_id,
				ms.stakes as master_stakes,
				ms.winnings as master_winnings
			from
				tCGGameSummary s
				inner join tCGGame       g  on (s.cg_id       = g.cg_id)
				left outer join tCGGSFinished f  on (s.cg_game_id  = f.cg_game_id)
				left outer join tCGMasterSummary ms on (s.cg_master_id = ms.cg_master_id)
			where
				s.cg_acct_id = (select cg_acct_id from tCGAcct ga where ga.acct_id = ?)
				and s.started between ? and ? and
				(
					s.cg_master_id is null
					or exists (
						select 1
						from tCGChainGame c
						where s.cg_id = c.cg_id
						and c.order = 1
					)
				)
				$page_filter
				$cg_filter
				$bonus_filter
				group by 1,2,3,4,5,6,7,8,9,10,11,12
				order by cg_acct_id desc, cr_date desc
		}]
	}
}

core::args::register \
	-proc_name core::history::game::get_details \
	-is_public 1 \
	-desc {This is what reqAccountHistory will eventually run to get game detail data} \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Customer's account id}] \
		[list -arg -game_id -mand 1 -check UINT  -desc {Game Id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
	] \
	-body {
		variable CFG

		# We will check if the this game belongs to the account id passed in
		if {[catch {set rs [core::db::exec_qry -name core::game_history_service::check_game \
			-args [list $ARGS(-game_id) $ARGS(-acct_id)]]} err]} {
			core::log::write ERROR {Unable to execute query: $err}
			error {Unable to execute query} $::errorInfo GHS_ERROR_DB
		}

		if {[db_get_nrows $rs] != 1} {
			core::log::write ERROR {core::history::game::get_details: Game does not belong to user}
			error {Game does not belong to user} $::errorInfo GHS_ERROR_WRONG_CUSTOMER
		}

		set game [dict create group {GAME}]
		dict set game id $ARGS(-game_id)

		foreach {dict_name column_list_name qry} $core::history::game::CFG(detail_info) {
			set ret  [_get_detail_info $ARGS(-game_id) $ARGS(-lang) $qry $column_list_name]
			dict set game $dict_name $ret
		}

		return $game
	}



proc core::history::game::_get_detail_info {game_ids lang query col_list_name} {

	set query_type [expr {[llength $game_ids] !=1 ? "_by_ids" : "_by_id"}]
	append query $query_type

	if {[catch {set rs [core::db::exec_qry -name $query -args [list  {*}$game_ids]]} err]} {
		core::log::write ERROR {Unable to execute query: $err}
		error SERVER_ERROR $::errorInfo GHS_ERROR_DB
	}

	set ret [core::history::game::_format_item $col_list_name $rs $lang]

	core::db::rs_close -rs $rs
	return $ret
}


# Format a detailed bet item dict given the result set
proc core::history::game::_format_item {column_list_name rs lang} {
	variable CFG

	core::log::write INFO {core::history::game::_format_item Formatting:$column_list_name lang:$lang}
	# to be picked up from above vars
	set column_list  $CFG($column_list_name)

	set results [list]
	set nrows [db_get_nrows $rs]
	if {!$nrows} {
		core::log::write ERROR {core::history::game::_format_item:No results found}
		return $results
	}

	for {set i 0} {$i < $nrows} {incr i} {
		set working_dict [dict create]
		foreach {col xl} $column_list {
			set value [db_get_col $rs $i $col]
			if {$xl} {
				set value [core::history::xl -value $value]
			} else {
				if {$CFG(escape_untranslated_entities)} {
					set value [core::xml::escape_entity -value $value]
				}
			}
			core::log::write DEBUG {core::history::game::_format_item col:$col val:$value}
			dict set working_dict $col $value
		}
		lappend results $working_dict
	}

	return $results
}

