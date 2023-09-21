set pkg_version 1.0

package provide core::history::wagering_requirement $pkg_version

package require core::args  1.0
package require core::history

core::args::register_ns \
	-namespace     core::history::wagering_requirement \
	-version       $pkg_version \
	-dependent     [list core::args core::history] \
	-desc          {wagering requirements history} \
	-docs          history/wagering_requirement.xml

namespace eval core::history::wagering_requirement {
	variable INIT 0
	variable CFG
}

core::args::register \
	-proc_name core::history::wagering_requirement::init \
	-args [list \
	] \
	-body {
		variable INIT
		variable CFG

		if {![OT_CfgGet PROMOTION_SERVICE_ENABLED 0]} {
                        return
                }

		if {$INIT} {
			return
		}

		core::history::add_group \
			-group            {WAGERREQT} \
			-page_handler     core::history::wagering_requirement::get_page \
			-filters          [list] \
			-detail_levels    {DETAILED} \
			-j_op_ref_keys    {}


		core::history::add_item_handler \
			-group            {WAGERREQT} \
			-item_handler     core::history::wagering_requirement::get_item \
			-key              ID

		core::log::write INFO {Wagering Requirement Module initialised}

		set INIT 1
	}

core::args::register \
	-proc_name core::history::wagering_requirement::get_item \
	-clones core::history::item_handler \
	-args [list \
		[list -arg -acct_id  -mand 1 -check UINT              -desc {Account id}] \
		[list -arg -lang     -mand 1 -check ASCII             -desc {Language code for customer}] \
		[list -arg -value    -mand 1 -check ASCII             -desc {Value}] \
	] \
	-body {
                variable CFG

                set fn {core::history::wagering_requirement::get_item}

                if {[catch {
                       set wagerreqt_item [core::api::promotion_service::get_wagering_requirement_history \
		       		    -wagering_id	$ARGS(-value) \
		       ]
                } msg]} {
                        core::log::write ERROR {$fn Error executing $msg}
                        error SERVER_ERROR $::errorInfo
                }

		dict set wagerreqt_item group WAGERREQT

		return $wagerreqt_item
        }

core::args::register \
	-proc_name core::history::wagering_requirement::get_page \
	-clones core::history::page_handler \
	-args [list \
		[list -arg -acct_id       -mand 1 -check UINT        -desc {Account id}] \
		[list -arg -lang          -mand 1 -check ASCII       -desc {Language code for customer}] \
		[list -arg -group         -mand 1 -check ASCII       -desc {Group name}] \
		[list -arg -filters       -mand 0 -check ANY         -desc {Dict of filter names/filter values}] \
		[list -arg -min_date      -mand 0 -check DATETIME    -desc {Earliest date}] \
		[list -arg -max_date      -mand 0 -check DATETIME    -desc {Latest date}] \
		[list -arg -detail_level  -mand 0 -check HIST_DETAIL -default {SUMMARY} -desc {Detail level of page items}] \
		[list -arg -page_size     -mand 1 -check UINT        -desc {Page size}] \
		[list -arg -page_boundary -mand 0 -check INT         -default -1  -desc {ID of last item returned}] \
	] \
	-body {

		return [list]
	}
