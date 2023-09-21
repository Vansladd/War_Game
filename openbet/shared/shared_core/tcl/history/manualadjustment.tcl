# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# manualadjustment Module of Account History Package
#
#
# Procedures:
#    core::history::manualadjustment::init                one time initialization
#    core::history::manualadjustment::get_page            The only proc that it is exposed as a public proc
#                                                         that's why it is the only proc registered with core::args
#                                                         Returns next page of history manualadjustment items
#    core::history::manualadjustment::get_pagination_rs   retrieve a result set that can be used to
#                                                         determine which manualadjustment items should be in the page
#    core::history::manualadjustment::get_range           get all manualadjustment items within a cr_date range
#    core::history::manualadjustment::get_item            retrieve details for a manualadjustment item

set pkg_version 1.0
package provide core::history::manualadjustment $pkg_version

package require core::args       1.0
package require core::db         1.0
package require core::history    1.0
package require core::db::schema 1.0
package require core::log        1.0


core::args::register_ns \
	-namespace core::history::manualadjustment \
	-version     $pkg_version \
	-dependent   [list core::args core::db core::history core::db::schema core::log] \
	-desc        {Manual Adjustment Account History} \
	-docs        history/manualadjustment.xml

# Variables
namespace eval core::history::manualadjustment {

	variable INIT 0
	variable CFG
}

# Initialize history manualadjustment module
core::args::register \
	-proc_name core::history::manualadjustment::init \
	-args [list \
		[list -arg -get_pagination_directive -mand 0 -check STRING \
			-default_cfg HIST_MANUALADJUSTMENT_GET_PAGINATION_DIRECTIVE \
			-desc {Directive for get_pagination_rs queries}] \
		[list -arg -get_range_directive -mand 0 -check STRING \
			-default_cfg HIST_MANUALADJUSTMENT_GET_RANGE_DIRECTIVE \
			-default {} \
			-desc {Directive for get_range queries}] \
		[list -arg -get_item_directive  -mand 0 -check STRING \
			-default_cfg HIST_MANUALADJUSTMENT_GET_ITEM_DIRECTIVE \
			-default {} \
			-desc {Directive for get item query}] \
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
			core::log::write INFO {Manual Adjustment Module initialised with $formatted_name_value}
		}

		# Set manualadjustment Summary detail level key - dbvalue
		set CFG(summary_elements) [list \
			group               group \
			id                  madj_id \
			date                cr_date \
			amount              amount \
			display       	    display \
			pending             pending \
			withdrawable        withdrawable \
			type                type \
			desc                desc \
		]

		# Set manualadjustment Summary detail level key - dbvalue
		set CFG(detailed_elements) [list \
			type_desc	    type_desc \
			ref_id	        ref_id \
			ref_key	        ref_key \
			subtype_code	subtype_code \
			subtype_desc	subtype_desc \
		]

		set CFG(max_page_size) [core::history::get_config -name max_page_size]

		# Register history manualadjustment handlers to history package
		core::history::add_combinable_group \
			-group                          {MANUALADJUSTMENT} \
			-filters                        [list] \
			-page_handler                   core::history::manualadjustment::get_page \
			-range_handler                  core::history::manualadjustment::get_range \
			-pagination_result_handler      core::history::manualadjustment::get_pagination_rs \
			-j_op_ref_keys                  {MADJ} \
			-detail_levels                  {SUMMARY DETAILED}

		# Register history add item handler to history package
		core::history::add_item_handler \
			-group            {MANUALADJUSTMENT} \
			-item_handler     core::history::manualadjustment::get_item

		# Prepare the queries
		_prep_queries

		set INIT 1
	}


# Register proc core::history::manualadjustment::get_page
# This proc is responsible for returning the history manualadjustment items.
#
# It first calls get_pagination_rs to get the cr_date boundaries
# and then get_range to retrieve the actual items
# it returns a [list last_seen_id max_date [list of items]].
core::args::register \
	-proc_name core::history::manualadjustment::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -group         -mand 1 -check ASCII       -desc {Transaction Group Name}] \
		[list -arg -acct_id       -mand 1 -check UINT        -desc {Account Id}] \
		[list -arg -lang          -mand 1 -check ASCII       -desc {Language}] \
		[list -arg -filters       -mand 1 -check ANY         -desc {Dictionary of Filters}] \
		[list -arg -detail_level  -mand 0 -check HIST_DETAIL -desc {Summary Detail Level}] \
		[list -arg -min_date      -mand 1 -check DATETIME    -desc {Start Date Time}] \
		[list -arg -max_date      -mand 1 -check DATETIME    -desc {End Date Time}] \
		[list -arg -page_boundary -mand 0 -check INT         -desc {Value of Last Id} -default -1] \
		[list -arg -page_size     -mand 1 -check UINT        -desc {Page Size}] \
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
				set new_max_date [dict get [lindex $results end] date]
			}
		}

		core::db::rs_close -rs $rs

		return [list $new_boundary $new_max_date $results]
	}

# Get a single item by an id or other key
core::args::register \
	-proc_name core::history::manualadjustment::get_item \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang    -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -key     -mand 0 -check ASCII -default ID -desc {Key}] \
		[list -arg -value   -mand 1 -check UINT             -desc {Value}] \
	] \
	-body {
		variable CFG

		set fn {core::history::manualadjustment::get_item}

		if {[catch {
			set rs [core::db::exec_qry \
				-name {core::history::manualadjustment::get_manualadjustment_item} \
				-args [list $ARGS(-acct_id) $ARGS(-value)] \
		]} msg]} {
			core::log::write ERROR {$fn Error executing $msg}
			error SERVER_ERROR $::errorInfo
		}

		if {[db_get_nrows $rs] < 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {manualadjustment Transaction Item Does Not Exist}
			error INVALID_ITEM {core::history::manualadjustment::get_item returned < 1 row}
		}

		set item [dict create]
		foreach {key colname} [concat $CFG(summary_elements) $CFG(detailed_elements)] {
			dict set item $key [db_get_col $rs 0 $colname]
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
	-proc_name core::history::manualadjustment::get_pagination_rs \
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
		set fn {core::history::manualadjustment::get_pagination_rs}

		if {$ARGS(-last_id) == -1} {
			set query {core::history::manualadjustment::get_manualadjustment_pagination}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
		} else {
			set query {core::history::manualadjustment::get_manualadjustment_pagination_last_id}
			set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
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
# manualadjustment items. Returns a list of items
core::args::register \
	-proc_name core::history::manualadjustment::get_range \
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

		set fn {core::history::manualadjustment::get_range}

		if {$ARGS(-detail_level) == "DETAILED" && [llength $ARGS(-ids)]} {
			set padded_list [core::util::lpad -list $ARGS(-ids) \
											   -size $CFG(max_page_size) \
											   -padding -1]
			set query {core::history::manualadjustment::get_manualadjustment_items}
			set sql_params [list $ARGS(-acct_id) {*}$padded_list]
		} else {
			if {$ARGS(-last_id) == -1} {
				set query {core::history::manualadjustment::get_manualadjustment_range}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date)]
			} else {
				set query {core::history::manualadjustment::get_manualadjustment_range_last_id}
				set sql_params [list $ARGS(-acct_id) $ARGS(-min_date) $ARGS(-max_date) $ARGS(-last_id)]
			}
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
				dict set item $key [db_get_col $rs $i $colname]
			}

			if {$ARGS(-detail_level) == "DETAILED"} {
				foreach {key colname} $CFG(detailed_elements) {
					dict set item $key [db_get_col $rs $i $colname]
				}	
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

# Prepare queries
proc core::history::manualadjustment::_prep_queries {} {
	variable CFG

	set sql [subst {
		select
			$CFG(get_range_directive)
			'MANUALADJUSTMENT' as group,
			m.madj_id,
			m.cr_date,
			m.amount,
			m.display,
			m.pending,
			m.withdrawable,
			m.type,
			m.desc
		from
			tManAdj m
		where
			m.acct_id = ?
			and m.cr_date between ? and ?
			%s
		order by
			cr_date desc, madj_id desc
	}]

	set sql_get_range [format $sql {}]
	set sql_get_range_last_id [format $sql {and m.madj_id < ?}]

	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_range \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range

	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_range_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_get_range_last_id

	set sql [subst {
		select $CFG(get_pagination_directive)
			cr_date,
			m.madj_id as id
		from
			tManAdj m
		where
			acct_id = ?
			and cr_date between ? and ?
			%s
		order by acct_id desc, cr_date desc
	}]

	set sql_pagination [format $sql {}]
	set sql_pagination_last_id [format $sql {and madj_id < ?}]

	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_pagination \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination

	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_pagination_last_id \
		-force 0 \
		-cache 0 \
		-qry   $sql_pagination_last_id

	set from   {}

	if {[core::db::schema::table_column_exists \
			           -table tManAdjType -column type] && 
		[core::db::schema::table_column_exists \
			           -table tManAdjType -column desc] } {

		append from "inner join (tManAdjType mt) on (m.type = mt.type) "
		
		if {[core::db::schema::table_column_exists \
			           -table tManAdjSubType -column subtype]} {			   
                
			append from "left outer join tManAdjSubType mst on (m.type = mst.type and m.subtype = mst.subtype) "			   
		} 				
				
	}

	set sql [subst {			
		select
			$CFG(get_item_directive)
			'MANUALADJUSTMENT' as group,
			m.madj_id,
			m.cr_date,
			m.amount,
			m.display,
			m.pending,
			m.withdrawable,
			m.type,
			m.desc,
			[core::db::schema::add_sql_column -table tManAdj -column ref_id -alias {ref_id} -default {'' as ref_id}],
			[core::db::schema::add_sql_column -table tManAdj -column ref_key -alias {ref_key} -default {'' as ref_key}],
			[core::db::schema::add_sql_column -table tManAdjType -column desc -alias {mst.desc as type_desc} -default {'' as type_desc}],
			[core::db::schema::add_sql_column -table tManAdjSubType -column subtype -alias {mst.subtype as subtype_code} -default {'' as subtype_code}],
			[core::db::schema::add_sql_column -table tManAdjSubType -column desc -alias {mst.desc as subtype_desc} -default {'' as subtype_desc}]
		from
			tManAdj         m
			$from
		where
				m.acct_id = ?
			%s
		order by acct_id desc, cr_date desc
	}]
		
	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_item \
		-force 0 \
		-cache 0 \
		-qry   [format $sql {and m.madj_id = ?}]

	set ph [join [split [string repeat ? $CFG(max_page_size)] {}] ,]

	core::db::store_qry \
		-name  core::history::manualadjustment::get_manualadjustment_items \
		-force 0 \
		-cache 0 \
		-qry   [format $sql "and m.madj_id in ($ph)"]
}
