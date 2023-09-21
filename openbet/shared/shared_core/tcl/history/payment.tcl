# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Payment Module of Account History Package
#
#
# Procedures:
#    core::history::payment::init                 one time initialization
#    core::history::payment::get_page             The only proc that it is exposed as a public proc
#                                                 that's why it is the only proc registered with core::args
#                                                 Returns next page of history payment items
#    core::history::payment::get_pagination_rs    retrieve a result set that can be used to
#                                                 determine which payment items should be in the page
#    core::history::payment::get_range            get all payment items within a cr_date range
#    core::history::payment::get_item             retrieve details for a payment item

set pkg_version 1.0
package provide core::history::payment $pkg_version

package require core::args       1.0
package require core::db         1.0
package require core::history    1.0
package require core::db::schema 1.0
package require core::log        1.0

core::args::register_ns \
	-namespace core::history::payment \
	-version   $pkg_version \
	-dependent [list core::args core::db core::history core::db::schema core::log] \
	-desc      {Payment Account History} \
	-docs      history/payment.xml

# Variables
namespace eval core::history::payment {

	variable INIT 0
	variable CFG
	variable PAY_MTHD

	set CFG(pay_mthd) {
		          C2P   cpm_id tCpmC2p         username\
		          MB    pmt_id tCpmMb          mb_email_addr\
		          NTLR  cpm_id tCpmNeteller    neteller_id\
		          PPAL  cpm_id tCpmPayPal      email\
		          WU    cpm_id tCpmWu          payee\
		          CB    cpm_id tCpmClickAndBuy cb_email\
		          CHQ   cpm_id tCpmChq         payee\
		          BANK  cpm_id tCpmBank        bank_acct_name\
		          ENVO  cpm_id tCpmEnvoy       additional_info1\
		          CC    cpm_id tCpmCC          card_last_4_digits\
		          GDEP  {}     {}              {}\
		          CSH   {}     {}              {}\
		          ENET  {}     {}              {}\
		          BACS  {}     {}              {}\
		          SHOP  {}     {}              {}\
		          UKSH  {}     {}              {}\
		          PSC   {}     {}              {}\
		          IKSH  {}     {}              {}\
		          EPYV  {}     {}              {}\
		          BPNG  {}     {}              {}\
		          TOPC  {}     {}              {}\
		}

	set CFG(sub_mthd) {
		     MB   tPmtMB         payment_type\
		     ENVO tExtSubCPMLink sub_type_code\
		     CC   tCardInfo      scheme\
	}
}

# Initialize history payment module
core::args::register \
	-proc_name core::history::payment::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING -default_cfg HIST_PAYMENT_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING -default_cfg HIST_PAYMENT_GET_RANGE_DIRECTIVE -default {} -desc {\
			Directive for get_range queries}] \
		[list -arg -get_item_directive  -mand 0 -check STRING -default_cfg HIST_PAYMENT_GET_ITEM_DIRECTIVE  -default {} -desc {\
			Directive for get item query}] \
		[list -arg -show_italian_payment_history -mand 0 -check BOOL \
			-default_cfg HIST_PAYMENT_SHOW_ITALIAN_INFO -default 0 \
			-desc {Enable SOGEI info retrieval}] \
	] \
	-body {
		variable INIT
		variable CFG

		set fn {core::history::payment::init}

		if {$INIT} {
			return
		}

		foreach {n v} [array get ARGS] {
			set n [string trimleft $n -]
			set CFG($n) $v
			set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
			core::log::write INFO {Payment Module initialised with $formatted_name_value}
		}

		# Set Payment Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			group           group \
			id              pmt_id \
			cr_date         cr_date \
			method_nickname nickname \
			method_type     pay_mthd \
			method_id       cpm_id \
			payment_sort    payment_sort \
			amount          amount \
			commission      commission \
			status          status \
			settled_at      settled_at\
			processed_at    processed_at \
			source          source \
			process_date    process_date \
			ipaddr          ipaddr \
			call_id         call_id \
			receipt         receipt \
		]

		# pay_mthd list as per tPayMthd.
		foreach {pmt_mthd index table column} $CFG(pay_mthd) {

			set CFG($pmt_mthd,available) 0
			set CFG($pmt_mthd,index)     $index
			set CFG($pmt_mthd,table)     $table
			set CFG($pmt_mthd,column)    $column

			if {[core::db::schema::table_column_exists \
			           -table $table -column $column]} {
				set CFG($pmt_mthd,available) 1
			}
		}

		foreach {pmt_mthd table column} $CFG(sub_mthd) {
			if {![core::db::schema::table_column_exists \
			           -table $table -column $column]} {
				set CFG($pmt_mthd,available) 0

				core::log::write WARNING {$fn : payment info unavailiable for\
				                $pmt_mthd as sub table ${table}.${column} missing}
			}
		}

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		# If we have tSOGEISubInfo it will be joined in the query
		# and the extra sogei info will be added.
		set CFG(sogei_info_exists) [expr {[core::db::schema::table_column_exists \
			-table tSOGEITransaction -column receipt_id] ? 1 :0}]

		# Check whether the Sogei table is available for the Italian
		# info. If yes add the extra fields in the summary.
		if {$CFG(show_italian_payment_history)} {
			if {$CFG(sogei_info_exists)} {
				lappend CFG(summary_elements) \
					sg_receipt_id  sg_receipt_id
			} else {
				core::log::write WARNING "tSOGEITransaction does not exist"
			}
		}

		set filters [list \
			[list payment_sort ASCII ALL] \
			[list status ASCII ALL] \
			[list pay_mthd ASCII ALL] \
		]

		# Register history payment handlers to history package
		core::history::add_combinable_group \
			-group                          {PAYMENT} \
			-filters                        $filters \
			-page_handler                   core::history::payment::get_page \
			-range_handler                  core::history::payment::get_range \
			-pagination_result_handler      core::history::payment::get_pagination_rs \
			-j_op_ref_keys                  {GPMT} \
			-detail_levels                  {SUMMARY DETAILED}

		core::history::add_item_handler \
			-group            {PAYMENT} \
			-item_handler     core::history::payment::get_item_by_id \
			-key              ID

		core::history::add_item_handler \
			-group            {PAYMENT} \
			-item_handler     core::history::payment::get_item_by_receipt \
			-key              RECEIPT

		# Prepare the queries
		_prep_queries

		set INIT 1
	}


# Register proc core::history::payment::get_page
# This proc is responsible to return the history payment items
# It first calls get_pagination_rs to get the cr_date boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]]
core::args::register \
	-proc_name core::history::payment::get_page \
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
				-detail_level    $ARGS(-detail_level) \
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

# Get a single item by an id
core::args::register \
	-proc_name core::history::payment::get_item_by_id \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check UINT              -desc {Value}] \
	] \
	-body {
		variable CFG

		set fn {core::history::payment::get_item_by_id}

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::payment::get_payment_item_by_id} \
				-args [list $ARGS(-acct_id) $ARGS(-value) ] \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {Payment Transaction Item Does Not Exist}
			error INVALID_ITEM {core::history::payment::get_item_by_id returned < 1 row}
		}

		set item [dict create]
		foreach {key colname} $CFG(summary_elements) {
			dict set item $key [db_get_col $rs 0 $colname]
		}

		core::db::rs_close -rs $rs

		set items [list]
		lappend items $item
		set item [lindex [_add_payment_info $items] 0]

		set item [core::history::formatter::apply \
			-item             $item \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-detail_level     {SUMMARY}
		]

		return $item
	}

# Get a single item by receipt
core::args::register \
	-proc_name core::history::payment::get_item_by_receipt \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -value   -mand 1 -check ASCII             -desc {Value}] \
	] \
	-body {
		variable CFG

		set fn {core::history::payment::get_item_by_receipt}

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::payment::get_payment_item_by_receipt} \
				-args [list $ARGS(-acct_id) $ARGS(-value) ] \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {Payment Transaction Item Does Not Exist}
			error INVALID_ITEM {core::history::payment::get_item_by_receipt returned < 1 row}
		}

		set item [dict create]
		foreach {key colname} $CFG(summary_elements) {
			dict set item $key [db_get_col $rs 0 $colname]
		}

		core::db::rs_close -rs $rs

		set items [list]
		lappend items $item
		set item [lindex [_add_payment_info $items] 0]

		set item [core::history::formatter::apply \
			-item             $item \
			-acct_id          $ARGS(-acct_id) \
			-lang             $ARGS(-lang) \
			-detail_level     {DETAILED}
		]

		return $item
	}

# This proc returns a start cr_date and an end cr_date when given a start and an
# end date.
core::args::register \
	-proc_name core::history::payment::get_pagination_rs \
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
		set fn {core::history::payment::get_pagination_rs}

		set filtered 0
		set pay_mthd {%}
		set status {%}
		set payment_sort {%}
		if {[dict exists $ARGS(-filters) pay_mthd]} {
			set v [dict get $ARGS(-filters) pay_mthd]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set pay_mthd $v
			}
		}
		if {[dict exists $ARGS(-filters) status]} {
			set v [dict get $ARGS(-filters) status]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set status $v
			}
		}
		if {[dict exists $ARGS(-filters) payment_sort]} {
			set v [dict get $ARGS(-filters) payment_sort]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set payment_sort $v
			}
		}

		if ($filtered) {
			if {$ARGS(-last_id) == -1} {
				set query {core::history::payment::get_payment_pagination_filtered}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $pay_mthd $payment_sort $status]
			} else {
				set query {core::history::payment::get_payment_pagination_last_id_filtered}
				set sql_params [list $ARGS(-acct_id) $ARGS(-last_id) $ARGS(-min_date) $ARGS(-max_date) $pay_mthd $payment_sort $status]
			}
		} else {
			if {$ARGS(-last_id) == -1} {
				set query {core::history::payment::get_payment_pagination}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
			} else {
				set query {core::history::payment::get_payment_pagination_last_id}
				set sql_params [list $ARGS(-acct_id) $ARGS(-last_id) $ARGS(-min_date) $ARGS(-max_date)]
			}
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
# payment items. Returns a list of items
core::args::register \
	-proc_name core::history::payment::get_range \
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

		set fn {core::history::payment::get_range}

		set filtered 0
		set pay_mthd {%}
		set status {%}
		set payment_sort {%}
		if {[dict exists $ARGS(-filters) pay_mthd]} {
			set v [dict get $ARGS(-filters) pay_mthd]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set pay_mthd $v
			}
		}
		if {[dict exists $ARGS(-filters) status]} {
			set v [dict get $ARGS(-filters) status]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set status $v
			}
		}
		if {[dict exists $ARGS(-filters) payment_sort]} {
			set v [dict get $ARGS(-filters) payment_sort]
			if {$v != {ALL} && $v != {}} {
				set filtered 1
				set payment_sort $v
			}
		}

		if {$filtered} {
			if {$ARGS(-last_id) == -1} {
				set query "core::history::payment::get_payment_range_filtered"
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $pay_mthd $payment_sort $status]
			} else {
				set query "core::history::payment::get_payment_range_last_id_filtered"
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id) $pay_mthd $payment_sort $status]
			}
		} else {
			if {$ARGS(-last_id) == -1} {
				set query "core::history::payment::get_payment_range"
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
			} else {
				set query "core::history::payment::get_payment_range_last_id"
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
			}
		}

		if {[catch {
			set rs [core::db::exec_qry \
				-name $query \
				-args $sql_params \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		# We loop over the result set and we create a dict foreach row
		# Each dict is formatted by a repsective proc if exists and the
		# new formatted item is appended to the result list
		set nrows [db_get_nrows $rs]

		if {$ARGS(-page_size) < $nrows} {
			set limit $ARGS(-page_size)
		} else {
			set limit $nrows
		}


		set items [list]

		# Retrieve data
		for {set i 0} {$i < $limit} {incr i} {
			set item [dict create]
			foreach {key colname} $CFG(summary_elements) {
				dict set item $key [db_get_col $rs $i $colname]
			}

			lappend items $item

		}

		core::db::rs_close -rs $rs

		if {$ARGS(-detail_level) == "DETAILED"} {
			set items   [_add_payment_info $items]
		}

		set results [list]

		# Format data
		foreach item $items {

			set item [core::history::formatter::apply \
				-item            $item \
				-acct_id         $ARGS(-acct_id) \
				-lang            $ARGS(-lang) \
				-detail_level    $ARGS(-detail_level)
			]

			lappend results $item
		}

		return $results
	}

# _add_payment_info
#
# Takes a list of payments dictionaries and retrieves additional info
# if available
#
proc core::history::payment::_add_payment_info {items} {

	variable CFG

	set fn {core::history::payment::_add_payment_info}

	core::log::write DEBUG {$fn : items $items}

	set results        [list]
	set PMT(pay_mthds) [list]
	set paymethod_info [dict create "item" {} "value" {} "sub_method" {}]

	# Parse items creating lists of id_placeholders
	foreach item $items {
		set pay_mthd   [dict get $item method_type]
		set cpm_id     [dict get $item method_id]
		set pmt_id     [dict get $item id]

		# what column are we filtering by?
		if {$CFG($pay_mthd,index) == "cpm_id"} {
			set id $cpm_id
		} else {
			set id $pmt_id
		}

		# create a list of ids and payment methods
		if {[info exists PMT($pay_mthd,ids)]} {
			lappend PMT($pay_mthd,ids) $id
		} else {
			set PMT($pay_mthd,ids) [list $id]
			lappend PMT(pay_mthds) $pay_mthd
		}
	}

	# Retrieve extra info
	foreach pay_mthd $PMT(pay_mthds) {

		if {$CFG(${pay_mthd},available)} {

			set unique_list [lsort -unique $PMT($pay_mthd,ids)]
			set padded_list [core::util::lpad -list $unique_list -size $CFG(max_page_size) -padding -1]

			if {[catch {
				set rs [core::db::exec_qry \
					-name "core::history::payment::${pay_mthd}::get_info" \
					-args [list {*}$padded_list] \
			]} msg]} {
				core::log::write ERROR {$fn Error executing ${pay_mthd}::get_info :  $msg}
				error "Invalid sql called for ${pay_mthd}" $::errorInfo PMT_MTHD_SQL_ERROR
			}

			set nrows [db_get_nrows $rs]

			if {$nrows < 1} {
				core::db::rs_close -rs $rs
				core::log::write ERROR {Additional Transaction Info Does Not Exist}
				# Have to assume bad data ok to continue
				continue
			}

			set item [dict create]
			for {set i 0} {$i < $nrows} {incr i} {

				set paymethod_info [dict create "item" {} "value" {} "sub_method" {}]
				set id [db_get_col $rs $i $CFG($pay_mthd,index)]

				dict set paymethod_info "item"       [db_get_col $rs $i "pay_method_info"]
				dict set paymethod_info "value"      [db_get_col $rs $i "pay_method_value"]
				dict set paymethod_info "sub_method" [db_get_col $rs $i "sub_method_info"]

				set PMT(${pay_mthd},${id}) $paymethod_info
			}

			core::db::rs_close -rs $rs
		}
	}

	# add paymethod_info to each item
	foreach item $items {

		set pay_mthd   [dict get $item method_type]
		set cpm_id     [dict get $item method_id]
		set pmt_id     [dict get $item id]

		if {$CFG($pay_mthd,index) == "cpm_id"} {
			set id $cpm_id
		} else {
			set id $pmt_id
		}

		if {![info exists PMT(${pay_mthd},${id})]} {
			dict set item paymethod_info \
			           [dict create "item" {} "value" {} "sub_method" {}]
		} else {
			dict set item paymethod_info $PMT(${pay_mthd},${id})
		}

		core::log::write DEBUG {$fn : item $item}

		lappend results $item
	}

	return $results
}

# Prepare queries
proc core::history::payment::_prep_queries {} {
	variable CFG

	set fn {core::history::payment::_prep_queries}

	set nickname [core::db::schema::add_sql_column -table tcustpaymthd -column nickname \
		-alias {m.nickname as nickname,} -default {'' as nickname,}]

	set process_date [core::db::schema::add_sql_column -table tpmtpending -column process_date \
		-alias {pp.process_date as process_date,} -default {'' as process_date,}]

	set receipt [core::db::schema::add_sql_column -table tpmt -column receipt \
		-alias {p.receipt as receipt,} -default {'' as receipt,}]

	set sg_receipt_id [core::db::schema::add_sql_column -table tSOGEITransaction -column receipt_id \
		-alias {sgt.receipt_id as sg_receipt_id} -default {'' as sg_receipt_id}]

	set pmt_pending_sql {}
	if {[core::db::schema::table_exists -table tpmtpending]} {
		set pmt_pending_sql {
			left outer join tPmtPending pp on (
				pp.pmt_id = p.pmt_id
				and p.status  = 'P'
			)
		}
	}

	set sogei_sql {}
	if {$CFG(sogei_info_exists)} {
		set sogei_sql {
			left outer join tSOGEITransaction sgt on (
				sgt.ref_id = p.pmt_id
				and sgt.ref_type  = 'P'
			)
		}
	}

	set sql [subst {
		select
			$CFG(get_range_directive)
			'PAYMENT' as group,
			m.cpm_id,
			m.pay_mthd,
			$nickname
			p.amount,
			p.commission,
			p.cr_date,
			p.payment_sort,
			p.pmt_id,
			p.processed_at,
			p.settled_at,
			p.source,
			$process_date
			p.status,
			p.ipaddr,
			p.call_id,
			$receipt
			$sg_receipt_id
		from
			tpmt p
			inner join tcustpaymthd m on (p.cpm_id = m.cpm_id)
			$pmt_pending_sql
			$sogei_sql
		where
			p.acct_id = ?
			%s
			and p.display = 'Y'
			%s
			%s
		order by
			cr_date desc, pmt_id desc
	}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_range \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and p.cr_date between ? and ?} {} {}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_range_last_id \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and p.cr_date between ? and ?} {and p.pmt_id < ?} {}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_range_filtered \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and p.cr_date between ? and ?} {} {and m.pay_mthd like ? and p.payment_sort like ? and p.status like ?}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_range_last_id_filtered \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and p.cr_date between ? and ?} {and p.pmt_id < ?} {and m.pay_mthd like ? and p.payment_sort like ? and p.status like ?}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_item_by_id \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {} {and p.pmt_id = ?} {}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_item_by_receipt \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {} {and p.receipt = ?} {}]

	#
	# Payment types
	#

	set id_placeholders [join [split [string repeat ? $CFG(max_page_size)] {}] ,]

	# C2P
	if {$CFG(C2P,available)} {

		core::db::store_qry \
			-name  core::history::payment::C2P::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'email' as pay_method_info,
					c.email as pay_method_value,
					'' as sub_method_info
				from
					tCpmC2p c
				where
					c.cpm_id in ($id_placeholders)
		}]
	}

	# MB
	if {$CFG(MB,available)} {

		core::db::store_qry \
			-name  core::history::payment::MB::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					m.pmt_id,
					'mb_email_addr' as pay_method_info,
					c.mb_email_addr as pay_method_value,
					m.payment_type as sub_method_info
				from
					tPmt p
						inner join tpmtMB m on (m.pmt_id = p.pmt_id)
						inner join tcpmmb c on (c.cpm_id = p.cpm_id)
				where
					p.pmt_id in ($id_placeholders)
		}]



	}

	# NTLR
	if {$CFG(NTLR,available)} {

		core::db::store_qry \
			-name  core::history::payment::NTLR::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'neteller_id' as pay_method_info,
					c.neteller_id as pay_method_value,
					'' as sub_method_info
				from
					tCpmNeteller c
				where
					c.cpm_id in ($id_placeholders)
		}]

	}

	# PPAL tCpmPayPal      email
	if {$CFG(PPAL,available)} {

		core::db::store_qry \
			-name  core::history::payment::PPAL::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'email' as pay_method_info,
					c.email as pay_method_value,
					'' as sub_method_info
				from
					tCpmPayPal c
				where
					c.cpm_id in ($id_placeholders)
		}]

	}

	# WU
	if {$CFG(WU,available)} {

		core::db::store_qry \
			-name  core::history::payment::WU::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'payee' as pay_method_info,
					c.payee as pay_method_value,
					'' as sub_method_info
				from
					tCpmWu c
				where
					c.cpm_id in ($id_placeholders)
		}]

	}


	# CB   tCpmClickAndBuy cb_email
	if {$CFG(CB,available)} {

		core::db::store_qry \
			-name  core::history::payment::CB::get_info \
			-force 0 \
			-cache 0 \
			-qry    [subst {
				select
					c.cpm_id,
					'cb_email' as pay_method_info,
					c.cb_email as pay_method_value,
					'' as sub_method_info
				from
					tCpmClickAndBuy c
				where
					c.cpm_id in ($id_placeholders)
		}]
	}

	# CHQ  tCpmChq         payee
	if {$CFG(CHQ,available)} {

		core::db::store_qry \
			-name  core::history::payment::CHQ::get_info \
			-force 0 \
			-cache 0 \
			-qry    [subst {
				select
					c.cpm_id,
					'payee' as pay_method_info,
					c.payee as pay_method_value,
					'' as sub_method_info
				from
					tCpmChq c
				where
					c.cpm_id in ($id_placeholders)
		}]
	}


	# BANK tCpmBank        bank_acct_name
	if {$CFG(BANK,available)} {

		core::db::store_qry \
			-name  core::history::payment::BANK::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'bank_acct_name' as pay_method_info,
					c.bank_acct_name as pay_method_value,
					'' as sub_method_info
				from
					tCpmBank c
				where
					c.cpm_id in ($id_placeholders)
		}]


	}


	# ENVO tCpmEnvoy       additional_info1
	if {$CFG(ENVO,available)} {

		core::db::store_qry \
			-name  core::history::payment::ENVO::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'additional_info1' as pay_method_info,
					c.additional_info1 as pay_method_value,
					l.sub_type_code as sub_method_info
				from
					tCpmEnvoy c
							left outer join tExtSubCPMLink l on (l.cpm_id = c.cpm_id)
				where
					c.cpm_id in ($id_placeholders)
		}]
	}


	#  CC   tCpmCC          card_last_4_digits
	if {$CFG(CC,available)} {

		core::db::store_qry \
			-name  core::history::payment::CC::get_info \
			-force 0 \
			-cache 0 \
			-qry   [subst {
				select
					c.cpm_id,
					'card_last_4_digits' as pay_method_info,
					c.card_last_4_digits as pay_method_value,
					i.scheme as sub_method_info
				from
					tCpmCC c
							inner join tCardInfo i on (i.card_bin = c.card_bin)
				where
					c.cpm_id in ($id_placeholders)
		}]
	}

	set sql [subst {
		select $CFG(get_pagination_directive)
			first [expr {$CFG(max_page_size) + 1}]
			p.cr_date,
			p.pmt_id,
			m.pay_mthd
		from
			tpmt p
			inner join tcustpaymthd m on (p.cpm_id = m.cpm_id)
		where
			acct_id = ?
			%s
			and p.cr_date between ? and ?
			%s
		order by acct_id desc, cr_date desc
	}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_pagination \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {} {}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_pagination_last_id \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and pmt_id < ?} {}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_pagination_filtered \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {} {and m.pay_mthd like ? and p.payment_sort like ? and p.status like ?}]

	core::db::store_qry \
		-name  core::history::payment::get_payment_pagination_last_id_filtered \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and pmt_id < ?} {and m.pay_mthd like ? and p.payment_sort like ? and p.status like ?}]

}

