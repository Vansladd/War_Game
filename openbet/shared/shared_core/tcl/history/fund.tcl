set pkg_version 1.0

package provide core::history::fund $pkg_version

package require core::args  1.0
package require core::history

core::args::register_ns \
	-namespace     core::history::fund \
	-version       $pkg_version \
	-dependent     [list core::args core::history] \
	-desc          {funds history} \
	-docs          history/fund.xml

namespace eval core::history::fund {
	variable INIT 0
}

core::args::register \
	-proc_name core::history::fund::init \
	-args [list \
	] \
	-body {
		variable INIT

		if {![OT_CfgGet FUNDING_SERVICE_ENABLED 0]} {
			return
		}

		if {$INIT} {
			return
		}

		core::history::add_group \
			-group            FUND \
			-page_handler     core::history::fund::get_page \
			-filters          [list] \
			-detail_levels    {DETAILED} \
			-j_op_ref_keys    {}


		core::history::add_item_handler \
			-group            FUND \
			-item_handler     core::history::fund::get_item \
			-key              ID

		core::log::write INFO {Fund Module initialised}

		set INIT 1
	}

#
# Get fund details
#
core::args::register \
	-proc_name core::history::fund::get_item \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id  -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang     -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -value    -mand 1 -check ASCII             -desc {Value}] \
	] \
	-body {
		if {[catch {
			set fund_item [core::api::funding_service::get_fund_history \
				-fund_id             $ARGS(-value) \
		]} err]} {
			core::log::write ERROR {Funding Service Error: $::errorInfo}
			error SERVER_ERROR $::errorInfo
		}

		set fund_requested [dict get $fund_item fund_requested]

		set fund_id [dict get $fund_requested id]

		dict set fund_item id $fund_id
		dict set fund_item group FUND

		return $fund_item
	}

#dummy proc
core::args::register \
	-proc_name core::history::fund::get_page \
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
		[list -arg -page_boundary -mand 0 -check INT   -default -1  -desc {ID of last item returned}] \
	] \
	-body {

		return [list]
	}
