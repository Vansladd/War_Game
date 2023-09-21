# $Id: openbet.tcl,v 1.1 2011/10/04 12:40:39 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Ovs Card Check Provider Code
#
# Provides card scheme and card bin range checking functionality.
#
# Synopsis:
#	package require ovs_datacash
#
# Configurations: No Config needed
#
# Procedures:
#	ob_ovs_openbet::init            - One initialisation for package
#	ob_ovs_openbet::run_check       - Card provider interface to the main application
#	ob_ovs_openbet::_run_card       - Run the card data against the required checks
#
package provide ovs_openbet 4.5



# Dependencies
#
package require tls
package require http 2.3
package require tdom
package require util_db
package require util_log



# Variables
#
namespace eval ob_ovs_openbet {

	variable INITIALISED
	set INITIALISED 0

}



# One time initialisation
#
proc ob_ovs_openbet::init {} {

	global auto_path
	variable INITIALISED

	if {$INITIALISED} {return}

	ob_log::write DEV "Initialising Card Check Functionality"

	_prep_ob_card_queries

	set INITIALISED 1
}



# Prepares general stored queries
#
proc ob_ovs_openbet::_prep_ob_card_queries {} {

	# Get valid profile definition using a unique code
	ob_db::store_qry ob_ovs_openbet::check_card_bin {
		select
			bin_lo,
			bin_hi,
			score,
			vrf_chk_def_id
		from
			tVrfCardBinDef
		where
			vrf_chk_def_id = ? AND
			bin_lo <= ? AND
			bin_hi >= ? AND
			status = 'A'
	}
}


#  Runs a suite of card checks depending on whether the data is present
#
proc ob_ovs_openbet::run_check {array_list} {
	OT_LogWrite 10 "Running Card Check operations"

	#Decide what subtype of the card class we need to run

	return [ob_ovs_openbet::_run_card $array_list "check"]
}



#  preforms the card checks
#
#	input - array list
#
#       returns - status (OB_OK denotes success) and array with results of card checks
#
proc ob_ovs_openbet::_run_card { {array_list} {type} args} {

	variable INITIALISED
	variable CARD_DATA

	if {!$INITIALISED} {init}

	array set CARD_DATA $array_list

	#Card Bin Check
	if { $CARD_DATA(card_bin,bin) != "" } {

		if {[catch {
			set res [ob_db::exec_qry ob_ovs_openbet::check_card_bin \
				$CARD_DATA(OB_CARD_BIN,$CARD_DATA(card_bin,bin),vrf_chk_def_id) $CARD_DATA(card_bin,bin) $CARD_DATA(card_bin,bin)]
		} msg]} {
			ob_db::rs_close $res
			ob_log::write ERROR \
				{OVS: Failed to run query ob_ovs_openbet::check_card_bin: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		#Set the response to the card BIN range check
		set bin_match [db_get_nrows $res]
		set responses [list]

		if {$bin_match > 0} {

			#Bin failed
			for {set m 0} {$m < $bin_match} {incr m} {
				set bin_lo [db_get_col $res $m bin_lo]
				set bin_hi [db_get_col $res $m bin_hi]
				set lookup "${bin_lo}-${bin_hi}"

				lappend responses $lookup
				set CARD_DATA(OB_CARD_BIN,$lookup) $lookup
				set CARD_DATA(OB_CARD_BIN,$lookup,score) [db_get_col $res $m score]
				set CARD_DATA(OB_CARD_BIN,$lookup,result) "FAILED"
			}
			#Overwrite the responses list for use with the scoring system
			set CARD_DATA(OB_CARD_BIN,responses) $responses
		} else {

			#Passed
			set CARD_DATA(OB_CARD_BIN,$CARD_DATA(card_bin,bin),result) "PASSED"
			set CARD_DATA(OB_CARD_BIN,$CARD_DATA(card_bin,bin),score) 0
			#Set the responses to be the successful bin range
			set CARD_DATA(OB_CARD_BIN,responses) $CARD_DATA(card_bin,bin)
		}
		ob_db::rs_close $res
	}

	#Card Scheme Check
	if { $CARD_DATA(scheme,type) != "" } {
		#Set the response to the card scheme check
		set CARD_DATA(OB_CARD_SCHEME,responses) "$CARD_DATA(scheme,type)"
	}

	#Send back the check results
	return [list OB_OK [array get CARD_DATA]]
}
