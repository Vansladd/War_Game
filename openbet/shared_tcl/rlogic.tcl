# ==============================================================
# $Id: rlogic.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval rlogic {

namespace export rlogic_init
namespace export make_rlogic_call

# ----------------------------------------------------------------------
# Interface to the Retail logic Payment gateway
#
# This is provided by the C tcl package ec_apacs_tcl
# the interface is single currency GBP ONLY.
# ----------------------------------------------------------------------


proc rlogic_init {} {

	set rlogic_lib [OT_CfgGet RLOGIC_LIB]
	if {$rlogic_lib != ""} {
		load $rlogic_lib
	}

	package require ec_apacs_tcl

	ec_apacs_server     [OT_CfgGet RLOGIC_SERVER]
	ec_apacs_portno     [OT_CfgGet RLOGIC_PORT]
	ec_apacs_sid        [OT_CfgGet RLOGIC_SID]

}


proc make_rlogic_call {ARRAY} {

	upvar $ARRAY PMT


	#
	# build up the authorisation command
	#

	set cmd ec_apacs_authorise
	lappend cmd {-card_no} $PMT(card_no)

	# amount in pence
	lappend cmd {-amount} [expr {round($PMT(amount) * 100)}]

	# expiry date yymm format
	foreach {mm yy} [split $PMT(expiry) "/"] {
		set exp ${yy}${mm}
	}
	lappend cmd {-exp_date} $exp

	# issue number, if set
	if {$PMT(issue_no) != ""} {
		lappend cmd {-issue_no} [format "%02u" $PMT(issue_no)]
	}

	# our reference number
	set ref_no  [format "%06u" "$PMT(apacs_ref)"]
	lappend cmd {-trans_no} $ref_no

	# transaction type
	switch -- $PMT(pay_sort) {
		"D" {set type purchase}
		"W" {set type refund}
		default {
			ob::log::write ERROR {Bad payment type $PMT(pay_sort)}
			return PMT_TYPE
		}
	}
	lappend cmd {-trans_type} $type

	# store the customer id in the reference text
	lappend cmd {-ref_txt} "(cust_id=$PMT(cust_id))"

	if [catch {array set aresp [eval $cmd]} msg] {
		ob::log::write ERROR {Caught rlogic exception: $msg}
		return PMT_RESP
	}

	if {$aresp(error_code) == "00"} {
		set PMT(gw_uid)      ""
		set PMT(card_type)   ""
		set PMT(gw_ret_msg)  $aresp(message)
		switch -- $aresp(resp_code) {
			"2" {
				set PMT(gw_ret_code) 1
				set PMT(auth_code)   $aresp(auth_code)
				return OK
			}
			"4" {
				set PMT(gw_ret_code) 4
				return PMT_DECL
			}
			"R" {
				set PMT(gw_ret_code) "R"
				return PMT_REFER
			}
			default {
				set PMT(gw_ret_code) $aresp(resp_code)
				return PMT_ERR
			}
		}
	}

	set  PMT(gw_ret_code) $aresp(resp_code)
	set  PMT(gw_ret_code) "E:$aresp(error_code) M:$aresp(message)"

	return PMT_ERR
}

}
