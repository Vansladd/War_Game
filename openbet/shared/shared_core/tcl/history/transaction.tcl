#
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Transaction history
#

set pkg_version 1.0
package provide core::history::transaction $pkg_version

package require core::args       1.0
package require core::db         1.0
package require core::history    1.0
package require core::db::schema 1.0
package require core::log        1.0

core::args::register_ns \
	-namespace     core::history::transaction \
	-version       $pkg_version \
	-dependent     [list \
		core::args core::db \
		core::history \
		core::db::schema \
		core::log] \
	-desc {Transaction history} \
	-docs history/transaction.xml

namespace eval core::history::transaction {
	variable CFG
}

# Initialise the module
core::args::register \
	-proc_name core::history::transaction::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_TRANSACTION_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_TRANSACTION_GET_RANGE_DIRECTIVE \
			-desc {Directive for get_range queries}] \
	] \
	-body {
		variable CFG

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Transaction Module initialised with $formatted_name_value}
		}

		# Set Transaction Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			id                jrnl_id \
			cr_date           cr_date \
			description       desc \
			balance           balance \
			amount            amount \
			group             group \
			activity          j_op_type \
			transaction_group j_op_ref_key \
			reference_id      j_op_ref_id]

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		core::history::add_group \
			-group            TRANSACTION \
			-page_handler     core::history::transaction::get_page \
			-filters          [list [list j_op_type ASCII {}]] \
			-detail_levels    {SUMMARY} \
			-j_op_ref_keys    {} \
			-bidirectional    1

		_prepare_queries
	}

# Get config
core::args::register \
	-proc_name core::history::transaction::get_config \
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

# Register proc core::history::transaction::get_page
# This proc is responsible for returning the history transaction items.
#
# It first calls get_pagination_rs to get the cr_date boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]].
core::args::register \
	-proc_name core::history::transaction::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII    -desc {Language code for customer}] \
		[list -arg -group         -mand 1 -check ASCII    -desc {Group name}] \
		[list -arg -filters       -mand 0 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 0 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 0 -check DATETIME -desc {Latest date}] \
		[list -arg -detail_level  -mand 0 -check HIST_DETAIL -default {SUMMARY} -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -page_boundary  -mand 0 -check LIST   -default {}  -desc {List of first and last item returned}] \
		[list -arg -page_direction -mand 0 -check ASCII -default NEXT -desc {NEXT or PREV}] \
	] \
	-body {

		core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date)

		set rs [get_pagination_rs \
			-acct_id          $ARGS(-acct_id) \
			-min_date         $ARGS(-min_date) \
			-max_date         $ARGS(-max_date) \
			-page_boundary    $ARGS(-page_boundary) \
			-page_size        $ARGS(-page_size) \
			-page_direction   $ARGS(-page_direction) \
			-filters          $ARGS(-filters)]

		set nrows [db_get_nrows $rs]

		set boundary_data {}
		set new_max_date {}
		set results {}

		if {$nrows} {
			set max_idx 0
			if {$nrows > $ARGS(-page_size)} {
				# There are more pages available.
				set page_last_row_idx [expr {$ARGS(-page_size) - 1}]
				if {$ARGS(-page_direction) == {PREV}} {
					set max_idx [expr {($nrows - $ARGS(-page_size))-1}]
					set page_last_row_idx [expr {$nrows - 1}]
				}
			} else {
				set page_last_row_idx [expr {$nrows - 1}]
			}

			set max_date [db_get_col $rs $max_idx cr_date]
			set min_date [db_get_col $rs $page_last_row_idx cr_date]

			set results [get_range \
				-acct_id         $ARGS(-acct_id) \
				-page_boundary   $ARGS(-page_boundary) \
				-lang            $ARGS(-lang) \
				-min_date        $min_date \
				-max_date        $max_date \
				-detail_level    $ARGS(-detail_level)\
				-page_size       $ARGS(-page_size) \
				-page_direction  $ARGS(-page_direction) \
				-filters         $ARGS(-filters)]

			set boundary_data [list \
				[dict get [lindex $results 0] id] \
				[dict get [lindex $results end] id] \
				[dict get [lindex $results 0] cr_date] \
				[dict get [lindex $results end] cr_date]]
		}

		core::db::rs_close -rs $rs

		return [list $boundary_data $ARGS(-max_date) $results]
	}

# Return a result set containing cr_dates given the parameters.
core::args::register \
	-proc_name core::history::transaction::get_pagination_rs \
	-clones core::history::pagination_result_handler \
	-is_public 0 \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT     -desc {Account id}] \
		[list -arg -filters       -mand 1 -check ANY      -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 1 -check DATETIME -desc {Earliest date}] \
		[list -arg -max_date      -mand 1 -check DATETIME -desc {Latest date}] \
		[list -arg -page_size     -mand 1 -check UINT     -desc {Page size}] \
		[list -arg -page_boundary  -mand 0 -check LIST     -desc {IDs of first and last item returned} -default {}] \
		[list -arg -page_direction -mand 0 -check ASCII    -desc {PREV or NEXT}] \
	] \
	-body {

		set j_op_type {}
		set filtered {}
		if {[dict exists $ARGS(-filters) j_op_type]} {
			set j_op_type [dict get $ARGS(-filters) j_op_type]
			if {$j_op_type != {}} {
				set filtered {_filtered}
			}
		}

		if {$ARGS(-page_boundary) == {}} {
			set query "core::history::transaction::get_transaction_pagination${filtered}"
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
		} elseif {$ARGS(-page_direction) == {PREV}} {
			set query "core::history::transaction::get_transaction_pagination_first_id${filtered}"
			set sql_params [list $ARGS(-acct_id) [lindex $ARGS(-page_boundary) 0] [lindex $ARGS(-page_boundary) 2] $ARGS(-max_date)]
		} else {
			set query "core::history::transaction::get_transaction_pagination_last_id${filtered}"
			set sql_params [list $ARGS(-acct_id) [lindex $ARGS(-page_boundary) 1] $ARGS(-min_date) [lindex $ARGS(-page_boundary) 3]]
		}

		if {$j_op_type != {}} {
			lappend sql_params $j_op_type
		}

		if {[catch {
			set rs [core::db::exec_qry \
				-name $query \
				-args $sql_params \
		]} msg]} {
			core::log::write ERROR {Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		return $rs
	}

# Get transaction items between a date range
core::args::register \
	-proc_name core::history::transaction::get_range \
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
		[list -arg -page_boundary  -mand 0 -check LIST     -desc {ID of last item returned} -default {}] \
		[list -arg -page_direction -mand 0 -check ASCII    -desc {PREV or NEXT}] \
		[list -arg -ids           -mand 0 -check LIST -default {} -desc {List of pagination ids.}] \
	] \
	-body {
		variable CFG

		set fn {core::history::transaction::get_range}
		set start_idx 0

		set j_op_type {}
		set filtered {}
		if {[dict exists $ARGS(-filters) j_op_type]} {
			set j_op_type [dict get $ARGS(-filters) j_op_type]
			if {$j_op_type != {}} {
				set filtered {_filtered}
			}
		}

		if {$ARGS(-page_boundary) == {}} {
			set query "core::history::transaction::get_transaction_range${filtered}"
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
		} elseif {$ARGS(-page_direction) == {PREV}} {
			set start_idx 1
			set query "core::history::transaction::get_transaction_range_first_id${filtered}"
			#set sql_params [list $ARGS(-acct_id) $ARGS(-max_date) $ARGS(-min_date) [lindex $ARGS(-page_boundary) 0]]
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) [lindex $ARGS(-page_boundary) 0]]
		} else {
			set query "core::history::transaction::get_transaction_range_last_id${filtered}"
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) [lindex $ARGS(-page_boundary) 1]]
		}

		if {$filtered != {}} {
			lappend sql_params $j_op_type
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
			set page_last_row_idx [expr {$start_idx + $ARGS(-page_size)}]
		} else {
			set start_idx 0
			set page_last_row_idx $nrows
		}

		set results [list]

		for {set i $start_idx} {$i < $page_last_row_idx} {incr i} {
			set item [dict create]
			foreach {key colname} $CFG(summary_elements) {
				switch $key {
					"transaction_group" {
						set val [core::history::get_group_for_ref_key \
							-j_op_ref_key [db_get_col $rs $i $colname]]
					}
					"description" {
						set val [core::xl::XL \
							-str [db_get_col $rs $i $colname] \
							-lang $ARGS(-lang)]

						set val [core::history::xl -value $val]
					}
					default {
						set val [db_get_col $rs $i $colname]
					}
				}
				dict set item $key $val
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

#
# Private procedures
#
proc core::history::transaction::_prepare_queries {} {

	variable CFG

	set sql [subst {
		select
			$CFG(get_range_directive)
			'TRANSACTION' as group,
			j.amount,
			j.balance,
			j.cr_date,
			j.desc,
			j.j_op_type,
			j.j_op_ref_id,
			j.j_op_ref_key,
			j.jrnl_id
		from
			tJrnl j
		where
			j.acct_id = ?
			and j.cr_date between ? and ?
			%s
			%s
		order by
			acct_id %s, cr_date %s, jrnl_id %s
	}]

	set multiset_sql {
		select * from table (
			multiset (
				%s
			)
		)
		order by
			acct_id desc, cr_date desc, jrnl_id desc
	}

	set data [list \
		{} \
		[format $sql {} {} {desc} {desc} {desc}] \
		{_filtered} \
		[format $sql {} {and j.j_op_type = ?} {desc} {desc} {desc}] \
		{_last_id} \
		[format $sql {and j.jrnl_id < ?} {} {desc} {desc} {desc}] \
		{_last_id_filtered} \
		[format $sql {and j.jrnl_id < ?} {and j.j_op_type = ?} {desc} {desc} {desc}] \
		{_first_id} \
		[format $multiset_sql [format $sql {and j.jrnl_id > ?} {} {asc} {asc} {asc}]] \
		{_first_id_filtered} \
		[format $multiset_sql [format $sql {and j.jrnl_id > ?} {and j.j_op_type = ?} {asc} {asc} {asc}]] \
	]

	# Support grep friendly.
	# core::history::transaction::get_transaction_range
	# core::history::transaction::get_transaction_range_filtered
	# core::history::transaction::get_transaction_range_last_id
	# core::history::transaction::get_transaction_range_last_id_filtered
	# core::history::transaction::get_transaction_range_first_id
	# core::history::transaction::get_transaction_range_first_id_filtered

	foreach {name sql} $data {

	core::db::store_qry \
			-name  core::history::transaction::get_transaction_range${name} \
		-force 0 \
		-cache 0 \
			-qry   $sql

	}

	set sql [subst {
		select $CFG(get_pagination_directive)
			first [expr {$CFG(max_page_size) +1}]
			cr_date
		from
			tJrnl
		where
			acct_id = ?
			%s
			and cr_date between ? and ?
			%s
		order by acct_id %s, cr_date %s
	}]


	set multiset_sql {
		select * from table (
			multiset (
				%s
			)
		)
		order by
			acct_id desc, cr_date desc
	}

	# Support grep friendly.
	# core::history::transaction::get_transaction_pagination
	# core::history::transaction::get_transaction_pagination_filtered
	# core::history::transaction::get_transaction_pagination_last_id
	# core::history::transaction::get_transaction_pagination_last_id_filtered
	# core::history::transaction::get_transaction_pagination_first_id
	# core::history::transaction::get_transaction_pagination_first_id_filtered

	set data [list \
		{} \
		[format $sql {} {} {desc} {desc}] \
		{_filtered} \
		[format $sql {} {and j_op_type = ?} {desc} {desc}] \
		{_last_id} \
		[format $sql {and jrnl_id < ?} {} {desc} {desc}] \
		{_last_id_filtered} \
		[format $sql {and jrnl_id < ?} {and j_op_type = ?} {desc} {desc}] \
		{_first_id} \
		[format $multiset_sql [format $sql {and jrnl_id > ?} {} {asc} {asc}]] \
		{_first_id_filtered} \
		[format $multiset_sql [format $sql {and jrnl_id > ?} {and j_op_type = ?} {asc} {asc}]] \
	]

	foreach {name sql} $data {
	core::db::store_qry \
			-name  core::history::transaction::get_transaction_pagination${name} \
		-force 0 \
		-cache 0 \
			-qry   $sql
	}
}
