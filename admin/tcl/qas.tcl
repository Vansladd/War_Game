# ==============================================================
# $Id: qas.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::QAS {

asSetAct ADMIN::QAS::DoAddressLookup [namespace code do_address_lookup]
asSetAct ADMIN::QAS::DoAddressRefine [namespace code do_address_refine]
asSetAct ADMIN::QAS::GoQASLookup     [namespace code go_qas_lookup]

#
# Address completion lookup.
#
proc do_address_lookup args {

	set fn {do_address_lookup}

	if {[catch {

		set addr_street_1 [ob_chk::get_arg addr_street_1 -on_err "" SAFE]
		set addr_street_2 [ob_chk::get_arg addr_street_2 -on_err "" SAFE]
		set addr_street_3 [ob_chk::get_arg addr_street_3 -on_err "" SAFE]
		set addr_street_4 [ob_chk::get_arg addr_street_4 -on_err "" SAFE]
		set addr_city     [ob_chk::get_arg addr_city     -on_err "" SAFE]
		set addr_postcode [ob_chk::get_arg addr_postcode -on_err "" SAFE]
	
		set list_args [list $addr_street_1 $addr_street_2 $addr_street_3 \
			$addr_street_4 $addr_city $addr_postcode]
	
		# Joining all data together and eliminating extra |s from the string
		regsub -all {\|+} [join $list_args {|}] {|} search_str
	
		set result [qas::do_singleline_search $search_str]

		_display_addr_completion_resp $result

	} msg]} {
		ob_log::write ERROR {$fn: action failed}
		ob_log::write ERROR {$::errorInfo}

		tpBindString reg_result "ERR_AJAX_FAILED"
		asPlayFile -nocache "qas_response.json"
	}
}


#
# Address completion refinement.
#
proc do_address_refine args {

	set fn {do_address_refine}

	if {[catch {

		set addr_id [ob_chk::get_arg addr_id -on_err "" SAFE]
		set result  [qas::do_refine $addr_id]
	
		_display_addr_completion_resp $result

	} msg]} {
		ob_log::write ERROR {$fn: action failed}
		ob_log::write ERROR {$::errorInfo}

		tpBindString reg_result "ERR_AJAX_FAILED"
		asPlayFile -nocache "qas_response.json"
	}
}


#
# Display json address completion response.
#
proc _display_addr_completion_resp {data} {

	set fn {sb_reg::_display_addr_completion_resp}

	# Act on the type of data being parsed.
	set type [lindex $data 0]
	switch -- $type {
		MULTIPLE {
			global PICKLIST
			ob_gc::add PICKLIST
			array set PICKLIST [list]

			# Get picklist details
			set i 0
			set picklist [lindex $data 1]
			if {$picklist == "TOO_MANY"} {
				# Number of addresses has exceeded criteria.
				ob::log::write ERROR "${fn}: Address completion search criteria too vague."
				tpBindString reg_result "TOO_MANY"
				asPlayFile -nocache "qas_response.json"
			} else {
				foreach {item} $picklist {
					set PICKLIST($i,id)      [lindex $item 0]
					set PICKLIST($i,address) [lindex $item 1]
					incr i
				}
	
				# Bind.
				tpSetVar  reg_lookup_picklist_num     [llength $picklist]
				tpBindVar reg_lookup_partial_id       PICKLIST id      reg_picklist_idx
				tpBindVar reg_lookup_partial_address  PICKLIST address reg_picklist_idx
	
				tpBindString reg_result "OK"
				asPlayFile -nocache "qas_response.json"
			}
		}
		FULL_ADDRESS {
			set address_data [lindex $data 1]

			# Get relevant parts of the address.
			set moniker [lindex $address_data 0]
			set address [lindex $address_data 1]

			# Get the final address.
			array set ADDRESS [qas::do_get_address $moniker]

			# Bind.
			tpBindString reg_lookup_addr_street_1 $ADDRESS(0)
			tpBindString reg_lookup_addr_street_2 $ADDRESS(1)
			tpBindString reg_lookup_addr_city     $ADDRESS(2)
			tpBindString reg_lookup_addr_region   $ADDRESS(3)
			tpBindString reg_lookup_addr_postcode $ADDRESS(4)

			tpSetVar reg_lookup_full_addr 1

			tpBindString reg_result "OK"
			asPlayFile -nocache "qas_response.json"
		}
		GENERIC_ERROR -
		default {
			# Invalid type.
			ob::log::write ERROR "${fn}: Invalid address type."
			tpBindString reg_result "ERROR"
			asPlayFile -nocache "qas_response.json"
		}
	}
}

#
# Display Quick Address Search Standalone page#

proc go_qas_lookup args {
	asPlayFile -nocache "qas_standalone.html"
}

}