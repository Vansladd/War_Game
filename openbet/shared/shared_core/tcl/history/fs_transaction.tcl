#
# (C) 2015 Openbet Technologies Ltd. All rights reserved.
#
# Transaction history
#

set pkg_version 1.0
package provide core::history::fs_transaction $pkg_version

package require core::args                 1.0
package require core::history              1.0
package require core::log                  1.0
package require core::api::funding_service 1.0

core::args::register_ns \
	-namespace     core::history::fs_transaction \
	-version       $pkg_version \
	-dependent     [list \
		core::history \
		core::log] \
	-desc {Transaction history} \
	-docs history/fs_transaction.xml

namespace eval core::history::fs_transaction {
	variable CFG
}

# Initialise the module
core::args::register \
	-proc_name core::history::fs_transaction::init \
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
			core::log::write INFO {fs_transaction Module initialised with $formatted_name_value}
		}

		# Set Transaction Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			id                transaction_id \
			cr_date           transaction_date \
			description       description \
			balance           balance \
			amount            transaction_amount \
			group             TRANSACTION \
			activity          transaction_type \
			transaction_group funding_operation_type \
			reference_id      ext_op_ref_id]

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		set filters [list \
			[list activity_types ANY {}] \
			[list transaction_types ANY {}]
		]

		core::history::add_group \
			-group            TRANSACTION \
			-page_handler     core::history::fs_transaction::get_page \
			-filters          $filters \
			-detail_levels    {SUMMARY} \
			-j_op_ref_keys    {} \
			-bidirectional    1

	}

# Get config
core::args::register \
	-proc_name core::history::fs_transaction::get_config \
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

# Register proc core::history::fs_transaction::get_page
# This proc is responsible for returning the history transaction items.
#
# It first calls get_pagination_rs to get the cr_date boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]].
core::args::register \
	-proc_name core::history::fs_transaction::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -acct_id        -mand 0 -check UINT        -desc {Account id}] \
		[list -arg -uuid           -mand 1 -check ASCII       -desc {Customer uuid}] \
		[list -arg -lang           -mand 1 -check ASCII       -desc {Language code for customer}] \
		[list -arg -ccy_code       -mand 1 -check ASCII       -desc {Currency code for customer}] \
		[list -arg -group          -mand 1 -check ASCII       -desc {Group name}] \
		[list -arg -filters        -mand 0 -check ANY         -desc {Dict of filter names/filter values}] \
		[list -arg -min_date       -mand 0 -check DATETIME    -desc {Earliest date}] \
		[list -arg -max_date       -mand 0 -check DATETIME    -desc {Latest date}] \
		[list -arg -detail_level   -mand 0 -check HIST_DETAIL -default {SUMMARY} -desc {Detail level of page items}] \
		[list -arg -page_size      -mand 1 -check UINT        -desc {Page size}] \
		[list -arg -page_boundary  -mand 0 -check LIST        -default {}  -desc {List of first and last item returned}] \
		[list -arg -page_direction -mand 0 -check ASCII       -default NEXT -desc {NEXT or PREV}] \
	] \
	-body {
		variable CFG

		core::history::validate_date_range -from $ARGS(-min_date) -to $ARGS(-max_date)

		set results       {}
		set extra_params  [list]

		if {$ARGS(-page_boundary) != {}} {
			lappend extra_params -page_boundary
			lappend extra_params $ARGS(-page_boundary)
		}

		set res [core::api::funding_service::get_fund_account_history \
				-customer_id       $ARGS(-uuid) \
				-currency_id       $ARGS(-ccy_code) \
				-from_date         $ARGS(-min_date) \
				-to_date           $ARGS(-max_date) \
				-page_size         $ARGS(-page_size) \
				-transaction_id    1 \
				-activity_types    [dict get $ARGS(-filters) activity_types] \
				-transaction_types [dict get $ARGS(-filters) transaction_types] \
				-page_direction    $ARGS(-page_direction) \
				{*}$extra_params
			]

		set transactions [dict get $res transactions]
		set has_next     [dict get $res has_next]
		set has_previous [dict get $res has_prev]

		foreach transaction $transactions {

			foreach {key colname} $CFG(summary_elements) {
				switch $key {
					"transaction_group" {
						set val [core::history::get_group_for_ref_key \
							-j_op_ref_key [dict get [lindex [dict get $transaction funding_operations] 0] $colname]]
					}
					"description" {
						set val [core::xl::XL \
							-str [dict get $transaction $colname] \
							-lang $ARGS(-lang)]

						set val [core::history::xl -value $val]
					}
					"group" {
						set val $colname
					}
					"balance" {
						set wallets [dict get $transaction wallets]
						foreach wallet $wallets {
							set wallet_type [dict get $wallet walletType]
							if {$wallet_type == "CASH"} {
								set val [dict get $wallet totalBalance]
							}
						}
					}
					"reference_id" {
						set ext_op_ref [lindex [dict get $transaction funding_operations] 0]
						# Some historical data might not have reference
						if {$ext_op_ref !={}} {
							set val [dict get $ext_op_ref operation_id]
						} else {
							set val {}
						}

					}
					default {
						set val [dict get $transaction $colname]
					}
				}

				dict set item $key $val

			}

			lappend results $item

		}

		# Calculate boundary data
		# The funding service calls returns exactly what we need
		# Funding service returns hasNext and hasPrev flags to indicate pagination
		set t_length [llength $transactions]
		set boundary_data {}
		# As long as we have results we have a boundary (we need a boundary to be able to create preveious pages)
		if {$t_length != 0} {
			set boundary_data [list \
				[dict get [lindex $transactions 0]   transaction_id] \
				[dict get [lindex $transactions [expr {$t_length - 1}]] transaction_id] \
				[dict get [lindex $transactions 0]   transaction_date] \
				[dict get [lindex $transactions [expr {$t_length - 1}]] transaction_date]]
		}

		return [list $boundary_data $ARGS(-max_date) $results $has_next $has_previous]
	}
