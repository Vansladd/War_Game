# $Id: paysafecard.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#

namespace eval ob_psc {

	# This variable is used to make sure we only INIT once
	variable INIT 0
}


proc ob_psc::init {} {

	# This is the (one-time) initialisation procedure.
	# ------------------------------------------------

	variable INIT
	variable PSC_CERT
	variable PSC_KEY_PW ""
	variable PSC_RESP
	variable PSC_LOCALES
	variable PMT_DATA
	variable PSC_ERROR

	# If we've already initialised, get out.
	if {$INIT} {
		return
	}

	ob_log::write INFO {ob_psc::init - Initialising paysafecard}

	# source dependencies
	package require net_socket
	package require tls

	if {[OT_CfgGet MONITOR 0] && [OT_CfgGet PAYMENT_TICKER 0]} {

                        package require    monitor_compat 1.0
	}

	# prepare queries
	_prepare_qrys

	# store certificate locations
	foreach ccy_code [OT_CfgGet PSC_CERT_CCYS ""] {
		set PSC_CERT($ccy_code) [OT_CfgGet PSC_CERT_${ccy_code}]
	}

	# store locale mapping
	array set PSC_LOCALES [OT_CfgGet PSC_LOCALE_MAP ""]

	# specify error to return depending on error code
	array set PSC_ERROR [list \
		default PMT_PSC_ERR_DEFAULT \
		1 PMT_PSC_ERR \
		2 PMT_PSC_ERR \
		3 PMT_PSC_ERR \
		4 PMT_PSC_ERR \
		5 PMT_PSC_ERR \
		6 PMT_PSC_ERR \
		7 PMT_PSC_ERR \
		8 PMT_PSC_ERR \
		9 PMT_PSC_ERR \
		10 PMT_PSC_ERR \
		11 PMT_PSC_ERR \
		12 PMT_PSC_ERR \
		13 PMT_PSC_ERR \
		14 PMT_PSC_ERR \
		15 PMT_PSC_ERR \
		16 PMT_PSC_ERR \
		17 PMT_PSC_ERR \
		20 PMT_PSC_ERR \
		21 PMT_PSC_ERR \
		25 PMT_PSC_ERR \
		26 PMT_PSC_ERR \
		30 PMT_PSC_ERR \
		31 PMT_PSC_ERR \
		35 PMT_PSC_ERR \
		36 PMT_PSC_ERR \
		40 PMT_PSC_ERR \
		41 PMT_PSC_ERR \
		45 PMT_PSC_ERR \
		46 PMT_PSC_ERR \
		50 PMT_PSC_ERR \
		51 PMT_PSC_ERR \
		55 PMT_PSC_ERR \
		56 PMT_PSC_ERR \
		60 PMT_PSC_ERR \
		65 PMT_PSC_ERR \
		70 PMT_PSC_ERR \
		71 PMT_PSC_ERR \
		72 PMT_PSC_ERR \
		75 PMT_PSC_ERR \
		76 PMT_PSC_ERR \
		77 PMT_PSC_ERR \
		80 PMT_PSC_CARD \
		81 PMT_PSC_CARD \
		85 PMT_PSC_CARD \
		90 PMT_PSC_ERR \
		95 PMT_PSC_ERR \
		96 PMT_PSC_ERR \
		100 PMT_PSC_ERR \
		101 PMT_PSC_ERR \
		102 PMT_PSC_ERR \
		103 PMT_PSC_ERR \
		104 PMT_PSC_ERR \
		105 PMT_PSC_ERR \
		106 PMT_PSC_ERR \
		107 PMT_PSC_ERR \
		110 PMT_PSC_ERR \
		115 PMT_PSC_ERR \
		116 PMT_PSC_ERR \
		120 PMT_PSC_ERR \
		125 PMT_PSC_NOCCY \
		126 PMT_PSC_NOCCY \
		130 PMT_PSC_ERR \
		131 PMT_PSC_ERR \
		135 PMT_PSC_ERR \
		136 PMT_PSC_ERR \
		140 PMT_PSC_NOCCY \
		141 PMT_PSC_NOCCY \
		145 PMT_PSC_ERR \
		146 PMT_PSC_ERR \
		147 PMT_PSC_ERR \
		150 PMT_PSC_ERR \
		151 PMT_PSC_ERR \
		152 PMT_PSC_ERR \
		153 PMT_PSC_ERR \
		154 PMT_PSC_ERR \
		155 PMT_PSC_ERR \
		156 PMT_PSC_ERR \
		157 PMT_PSC_ERR \
		158 PMT_PSC_ERR \
		159 PMT_PSC_ERR \
		160 PMT_PSC_ERR \
		161 PMT_PSC_ERR \
		162 PMT_PSC_ERR \
		163 PMT_PSC_ERR \
		164 PMT_PSC_ERR \
		165 PMT_PSC_ERR \
		166 PMT_PSC_ERR \
		167 PMT_PSC_ERR \
		168 PMT_PSC_ERR \
		169 PMT_PSC_ERR \
		170 PMT_PSC_ERR \
		171 PMT_PSC_ERR \
		172 PMT_PSC_ERR \
		175 PMT_PSC_ERR \
		176 PMT_PSC_ERR \
		180 PMT_PSC_ERR \
		181 PMT_PSC_ERR \
		185 PMT_PSC_ERR \
		186 PMT_PSC_ERR \
		190 PMT_PSC_ERR \
		191 PMT_PSC_ERR \
		192 PMT_PSC_ERR \
		193 PMT_PSC_ERR \
		194 PMT_PSC_ERR \
		195 PMT_PSC_ERR \
		196 PMT_PSC_ERR \
		197 PMT_PSC_ERR \
		200 PMT_PSC_ERR \
		201 PMT_PSC_ERR \
		202 PMT_PSC_ERR \
		203 PMT_PSC_ERR \
		204 PMT_PSC_ERR \
		205 PMT_PSC_ERR \
		206 PMT_PSC_ERR \
		207 PMT_PSC_ERR \
		208 PMT_PSC_ERR \
		209 PMT_PSC_ERR \
		210 PMT_PSC_ERR \
		211 PMT_PSC_ERR \
		212 PMT_PSC_ERR \
		213 PMT_PSC_ERR \
		214 PMT_PSC_ERR \
		215 PMT_PSC_ERR \
		216 PMT_PSC_ERR \
		217 PMT_PSC_ERR \
		218 PMT_PSC_ERR \
		219 PMT_PSC_ERR \
		220 PMT_PSC_ERR \
		221 PMT_PSC_ERR \
		222 PMT_PSC_ERR \
		223 PMT_PSC_ERR \
		224 PMT_PSC_ERR \
		300 PMT_PSC_ERR \
		301 PMT_PSC_ERR \
		302 PMT_PSC_ERR \
		303 PMT_PSC_ERR \
		305 PMT_PSC_ERR \
		306 PMT_PSC_ERR \
		307 PMT_PSC_ERR \
		308 PMT_PSC_ERR \
		309 PMT_PSC_ERR \
		310 PMT_PSC_ERR \
		311 PMT_PSC_ERR \
		315 PMT_PSC_ERR \
		316 PMT_PSC_ERR \
		350 PMT_PSC_ERR_TECHNICAL \
		351 PMT_PSC_ERR \
		400 PMT_PSC_ERR \
		401 PMT_PSC_ERR \
		402 PMT_PSC_ERR \
		403 PMT_PSC_ERR \
		404 PMT_PSC_ERR \
		405 PMT_PSC_ERR \
		406 PMT_PSC_ERR \
		1001 PMT_PSC_ERR \
		1002 PMT_PSC_ERR \
		1003 PMT_PSC_ERR \
		1004 PMT_PSC_CARD \
		1005 PMT_PSC_CARD \
		1006 PMT_PSC_CARD \
		1007 PMT_PSC_CARD \
		1008 PMT_PSC_ERR \
		1009 PMT_PSC_ERR \
		1010 PMT_PSC_CARD \
		1011 PMT_PSC_NOCCY \
		1012 PMT_PSC_CARD \
		1013 PMT_PSC_ERR \
		1014 PMT_PSC_CARD \
		1015 PMT_PSC_ERR \
		1016 PMT_PSC_ERR \
		1017 PMT_PSC_ERR \
		1018 PMT_PSC_CARD \
		1019 PMT_PSC_ERR \
		1020 PMT_PSC_ERR \
		1021 PMT_PSC_CARD \
		1022 PMT_PSC_CARD \
		1023 PMT_PSC_CARD \
		1024 PMT_PSC_CARD \
		1025 PMT_PSC_CARD \
		1026 PMT_PSC_ERR \
		1027 PMT_PSC_ERR \
		1028 PMT_PSC_ERR \
		1029 PMT_PSC_ERR \
		1030 PMT_PSC_CARD \
		1031 PMT_PSC_CARD \
		1032 PMT_PSC_CARD \
		1033 PMT_PSC_CARD \
		1034 PMT_PSC_CARD \
		1035 PMT_PSC_CARD \
		1036 PMT_PSC_CARD \
		1037 PMT_PSC_CARD \
		1038 PMT_PSC_CARD \
		1039 PMT_PSC_CARD \
		1040 PMT_PSC_CARD \
		1041 PMT_PSC_CARD \
		1042 PMT_PSC_CARD \
		1043 PMT_PSC_CARD \
		1044 PMT_PSC_CARD \
		1045 PMT_PSC_CARD \
		1046 PMT_PSC_CARD \
		1901 PMT_PSC_CARD \
		1902 PMT_PSC_CARD \
		1903 PMT_PSC_ERR \
		1904 PMT_PSC_CARD \
		1905 PMT_PSC_CARD \
		2001 PMT_PSC_ERR \
		2002 PMT_PSC_ERR \
		2003 PMT_PSC_ERR \
		2004 PMT_PSC_DECL \
		2005 PMT_PSC_DECL \
		2006 PMT_PSC_NOCCY \
		2007 PMT_PSC_AMNT \
		2008 PMT_PSC_AMNT \
		2009 PMT_PSC_AMNT \
		2010 PMT_PSC_AMNT \
		2011 PMT_PSC_NOCCY \
		2012 PMT_PSC_DECL \
		2013 PMT_PSC_ERR \
		2014 PMT_PSC_ERR \
		2015 PMT_PSC_DECL \
		2016 PMT_PSC_ERR \
		2017 PMT_PSC_ERR \
		2018 PMT_PSC_ERR \
		2019 PMT_PSC_ERR \
		2020 PMT_PSC_ERR \
		2021 PMT_PSC_AMNT \
		2022 PMT_PSC_CARD \
		2023 PMT_PSC_ERR \
		2024 PMT_PSC_ERR \
		2025 PMT_PSC_AMNT \
		2026 PMT_PSC_AMNT \
		2027 PMT_PSC_AMNT \
		2028 PMT_PSC_ERR \
		2901 PMT_PSC_ERR \
		2902 PMT_PSC_ERR \
		2903 PMT_PSC_ERR \
		2904 PMT_PSC_ERR \
		2905 PMT_PSC_ERR \
		2906 PMT_PSC_ERR \
		3001 PMT_PSC_ERR \
		3002 PMT_PSC_NOCCY \
		3003 PMT_PSC_ERR \
		3004 PMT_PSC_ERR \
		3005 PMT_PSC_ERR \
		3006 PMT_PSC_CARD \
		3007 PMT_PSC_ERR \
		3008 PMT_PSC_CARD \
		3009 PMT_PSC_CARD \
		3010 PMT_PSC_ERR \
		3011 PMT_PSC_ERR \
		3012 PMT_PSC_ERR \
		3013 PMT_PSC_ERR \
		3014 PMT_PSC_ERR \
		3015 PMT_PSC_ERR \
		3901 PMT_PSC_ERR \
		3902 PMT_PSC_ERR \
		4001 PMT_PSC_ERR_TECHNICAL \
		4002 PMT_PSC_ERR_TECHNICAL \
		4003 PMT_PSC_ERR_TECHNICAL \
		4004 PMT_PSC_ERR_TECHNICAL \
		4005 PMT_PSC_ERR_TECHNICAL \
		4006 PMT_PSC_ERR_TECHNICAL \
		4007 PMT_PSC_ERR_TECHNICAL \
		4008 PMT_PSC_ERR_TECHNICAL \
		4010 PMT_PSC_ERR_TECHNICAL \
		4011 PMT_PSC_ERR_TECHNICAL \
		4012 PMT_PSC_ERR_TECHNICAL \
		4013 PMT_PSC_ERR_TECHNICAL \
		4014 PMT_PSC_ERR_TECHNICAL \
		5001 PMT_PSC_ERR_TECHNICAL \
		5002 PMT_PSC_ERR_TECHNICAL \
	]

	# Set INIT to 1 so we know not to run this procedure again.
	set INIT 1
}



# Retrieves payment and gateway details.
#
# pmt_id    - the payment ID
# cust_id   - the customer ID
#
# return    - 1 - success
#           - 0 - failure
#
proc ob_psc::_load_pmt {pmt_id cust_id} {

	ob_log::write INFO {ob_psc::_load_pmt: pmt_id=$pmt_id,cust_id=$cust_id}

	variable PMT_DATA
	array unset PMT_DATA

	if {[catch {
		set rs [ob_db::exec_qry ob_psc::load_pmt $pmt_id $cust_id]
	} msg]} {
		ob_log::write ERROR "ob_psc::_load_pmt: Failed to retrieve data for \
				pmt_id=$pmt_id - $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_log::write ERROR "ob_psc::_load_pmt: Invalid row number for payment \
				pmt_id=$pmt_id - Rows returned = $nrows"
		ob_db::rs_close $rs
		return 0
	}

	set PMT_DATA(pmt_id) $pmt_id
	foreach col [db_get_colnames $rs] {
		set PMT_DATA($col) [db_get_col $rs 0 $col]
	}
	ob_db::rs_close $rs

	# decrypt mid and key
	set enc_db_vals [list \
		[list $PMT_DATA(enc_key)  $PMT_DATA(enc_key_ivec) $PMT_DATA(data_key_id)] \
		[list $PMT_DATA(enc_mid)  $PMT_DATA(enc_mid_ivec) $PMT_DATA(data_key_id)] \
	]
	set decrypt_rs  [card_util::card_decrypt_batch $enc_db_vals]

	if {[lindex $decrypt_rs 0] == 0} {
		ob_log::write ERROR "Error decrypting payment gateway acct info \
			[lindex $decrypt_rs 1]"
		return 0
	} else {
		set decrypted_vals [lindex $decrypt_rs 1]
	}

	set PMT_DATA(key)    [lindex $decrypted_vals 0]
	set PMT_DATA(mid)    [lindex $decrypted_vals 1]

	return 1
}



#  Performs the actual debit from PaySafeCard cards. It does it via
#  two requests, a Get Serial Numbers request (queries the payment on
#  the PaySafeCard side and retrieves PaySafeCard cards serial numbers
#  used in the transaction) and then a Execute Debit Request
#  that does the funds transfer. The Execute Debit Request ONLY
#  is executed if the status of transaction on PaySafeCard is di(S)posed.
#
#  pmt_id  - the unique ID OpenBet gives to a payment
#  cust_id - the unique customer ID
#
#  returns - [list 0 err_msg cpm_id] on transaction being unsuccessful,
#          - [list 1 unique_id amount] otherwise
proc ob_psc::execute_deposit {pmt_id cust_id} {

	variable PMT_DATA

	init

	ob_log::write INFO {ob_psc::execute_deposit pmt_id=$pmt_id,cust_id=$cust_id}

	# retrieve payment details
	if {![ob_psc::_load_pmt $pmt_id $cust_id]} {
		return [list 0 "PMT_PSC_INVALID_PMT"]
	}

	set serial_result [get_serial_numbers $pmt_id $cust_id]

	set ok        [lindex $serial_result 0]
	set state     [lindex $serial_result 1]
	set amount    [lindex $serial_result 2]
	set ccy_code  [lindex $serial_result 3]

	ob_log::write INFO {ob_psc::execute_deposit: serial_result = $serial_result}

	if {$ok} {

		# check if state is S (disposed) meaning we can confirm transaction
		if {$state == "S"} {

			# check amount and currency code in db match with transaction info
			# returned
			if {[format %.2f $amount] == [format %.2f $PMT_DATA(amount)] &&
			    $ccy_code == $PMT_DATA(ccy_code)} {

				# Execute the debit
				set execute_result [_execute_debit $pmt_id]
				set ok      [lindex $execute_result 0]
				set msg     [lindex $execute_result 1]

				if {$ok} {

					return [list 1 "OK"]
				} else {

					return [list 0 $msg]
				}
			} else {

				ob_log::write ERROR "ob_psc::execute_deposit - returned amount \
						$amount $ccy_code, should be $PMT_DATA(amount) \
						$PMT_DATA(ccy_code)"

				return [list 0 "PMT_PSC_ERR_DETAILS"]
			}
		} else {

			# unexpected state, update along with status if relevant
			set status ""

			# if state is L Cancelled or X Expired, cancel the transaction
			# else leave status unchanged as we're not sure what status the
			# payment is in
			if {[lsearch [list "L" "X"] $state] > -1} {
				ob_log::write INFO {ob_psc::execute_deposit Cancelling deposit}
				set status "X"
			}

			if {$status == ""} {
				ob_log::write INFO "ob_psc::execute_deposit Leaving pmt status \
						unchanged"
			}

			if {![update_pmt $pmt_id $status $state]} {
				return [list 0 "PMT_PSC_ERR_UNEXPECTED_STATE"]
			}
		}
	}

	# error performing deposit
	return [list 0 $state]
}



# Sends a request to the PaySafeCard server to ***GetSerialNumbersServlet***.
# It queries the status of the dispostion on PaySafeCard site and retrieved the serial numbers
# and associated values used in the payment. For each tuple (serial, value) it will insert
# into the PSCInfo table in the DB.
#
# pmt_id   - the payment ID
#
proc ob_psc::get_serial_numbers {pmt_id cust_id} {

	variable PMT_DATA
	variable PSC_RESP

	init

	# retrieve payment details if not already loaded
	if {![info exists PMT_DATA(pmt_id)] || $PMT_DATA(pmt_id) != $pmt_id} {
		if {![ob_psc::_load_pmt $pmt_id $cust_id]} {
			return [list 0 "PMT_PSC_INVALID_PMT"]
		}
	}

	# Prepare the URL
	set api_url "$PMT_DATA(host)/GetSerialNumbersServlet"

	ob_log::write INFO "ob_psc::get_serial_numbers: pmt_id=$pmt_id, \
			api_url=$api_url"

	# Get the required parameters for this request
	set params_nv [list \
	                "mid"               $PMT_DATA(mid) \
	                "mtid"              $PMT_DATA(unique_id) \
	                "outputFormat"      "xml_v1"]

	# Send the request
	foreach {status err} [_send_request \
			$params_nv \
			$api_url \
			$PMT_DATA(conn_timeout) \
			$PMT_DATA(resp_timeout) \
			$PMT_DATA(ccy_code) \
			$PMT_DATA(key) \
	] {}

	if {$status == 0} {
		ob_log::write ERROR {ob_psc::get_serial_numbers send failed: $err}
		return [list 0 $err]
	}

	# check if serial numbers have already been inserted for this pmt
	if {[catch {
		set rs [ob_db::exec_qry ob_psc::serials_for_pmt $pmt_id]
	} msg]} {
		ob_log::write ERROR "ob_psc::get_serial_numbers: Failed to run \
				ob_psc::serials_for_pmt - $pmt_id - $msg"
		return [list 0 "PMT_PSC_ERR_STATE"]
	}

	set existing_num_serials [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	# insert serial numbers for transaction if required and info is available
	if {$existing_num_serials == 0 &&
		[info exists PSC_RESP(PaysafecardTransaction,SerialNumber,CardDispositionValue)] &&
	    [info exists PSC_RESP(PaysafecardTransaction,SerialNumber,CardSerialNumber)]} {

		# Get the cards serial numbers and values redeemed in the transactions
		set num_serials [llength $PSC_RESP(PaysafecardTransaction,SerialNumber,CardSerialNumber)]

		if {$num_serials > 0} {

			set ok 1
			ob_db::begin_tran

			for {set i 0} {$i < $num_serials} {incr i} {

				set serial_num    [lindex $PSC_RESP(PaysafecardTransaction,SerialNumber,CardSerialNumber) $i]
				set serial_amount [lindex $PSC_RESP(PaysafecardTransaction,SerialNumber,CardDispositionValue) $i]

				if {$serial_num != "" && $serial_amount != ""} {

					# Attempt to insert into PSCInfo
					if {[catch {
						set rs [ob_db::exec_qry ob_psc::ins_psc_info \
								 $pmt_id \
								 [format "%016d" $serial_num] \
								 $serial_amount]
					} msg]} {
						ob_log::write ERROR {ob_psc::get_serial_numbers: Failed to insert - $msg}
						ob_db::rollback_tran
						set ok 0
						break
					}

					set psc_id [db_get_coln $rs 0 0]
					ob_db::rs_close $rs

					ob_log::write INFO {ob_psc::get_serial_numbers: psc_id=$psc_id}
				}
			}

			if {$ok} {
				ob_db::commit_tran
			}
		}
	}

	# get disposition details
	if {[info exists PSC_RESP(PaysafecardTransaction,txCode)]} {

		# return code of 0 => success
		if {$PSC_RESP(PaysafecardTransaction,txCode) == 0} {

			# return state
			return [list \
					1 \
					$PSC_RESP(PaysafecardTransaction,TransactionState) \
					$PSC_RESP(PaysafecardTransaction,Amount) \
					$PSC_RESP(PaysafecardTransaction,Currency) ]
		}
	}

	return [list 0 "PMT_PSC_ERR_STATE"]
}


# Sends a request to the PaySafeCard server to ****DebitServlet***.
# This function will execute the actual debit.
#
# pmt_id    - the payment ID
#
# return    - [1 PMT_SUCCESS_PSC] - successfully executed debit
#           - [0 error_msg] - error otherwise
proc ob_psc::_execute_debit {pmt_id} {

	variable PMT_DATA
	variable PSC_RESP
	variable PSC_ERROR

	init

	# retrieve payment details if not already loaded
	if {![info exists PMT_DATA(pmt_id)] || $PMT_DATA(pmt_id) != $pmt_id} {
		if {![ob_psc::_load_pmt $pmt_id $cust_id]} {
			return [list 0 "PMT_PSC_ERR_EXEC_DEBIT"]
		}
	}

	# set status to Unknown before attempting
	if {![update_pmt $pmt_id "U"]} {
		return [list 0 "PMT_PSC_ERR_EXEC_DEBIT"]
	}

	# Prepare the URL
	set api_url "$PMT_DATA(host)/DebitServlet"

	ob_log::write INFO {ob_psc::_execute_debit: api_url=$api_url}

	# Get the required parameters for this request
	set params_nv [list \
	                "mid"               $PMT_DATA(mid) \
	                "mtid"              $PMT_DATA(unique_id) \
	                "amount"            $PMT_DATA(amount) \
	                "currency"          $PMT_DATA(ccy_code) \
	                "close"             1 \
	                "outputFormat"      "xml_v1"]

	# Send the request
	foreach {ok err} [_send_request \
			$params_nv \
			$api_url \
			$PMT_DATA(conn_timeout) \
			$PMT_DATA(resp_timeout) \
			$PMT_DATA(ccy_code) \
			$PMT_DATA(key) \
	] {}

	if {!$ok} {
		ob_log::write ERROR {ob_psc::_execute_debit failed: $err}
		return [list 0 $err]
	}

	if {[info exists PSC_RESP(PaysafecardTransaction,txCode)]} {

		set uid ""
		if {[info exists PSC_RESP(PaysafecardTransaction,MTID)]} {
			set uid $PSC_RESP(PaysafecardTransaction,MTID)
		}

		# return code of 0 => success
		if {$PSC_RESP(PaysafecardTransaction,txCode) == 0} {

			ob_log::write INFO {ob_psc::_execute_debit: Transaction was successful}

			# PSC state for final execute debit having been called is 'O'
			if {![update_pmt $pmt_id "Y" "O"]} {
				return [list 0 "PMT_PSC_ERR_EXEC_DEBIT"]
			}

			return [list 1 "OK"]

		} else {

			ob_log::write ERROR "ob_psc::_execute_debit: txCode \
					$PSC_RESP(PaysafecardTransaction,txCode)"

			set error_code $PSC_RESP(PaysafecardTransaction,errCode)
			set error_msg  $PSC_RESP(PaysafecardTransaction,errMessage)

			ob_log::write ERROR "ob_psc::_execute_debit: Transaction \
					Unsuccessful err_code=$error_code, err_message=$error_msg"

			# payment declined, leave PSC state unchanged
			if {![update_pmt $pmt_id \
				             "N" \
							 "" \
				             $error_code \
				             $error_msg]} {

				return [list 0 "PMT_PSC_ERR_EXEC_DEBIT"]
			}

			# remove cpm if first deposit
			if {[OT_CfgGet FUNC_REMOVE_CPM_ON_FAIL 1]} {
				ob_psc::remove_cpm_on_first_payment $PMT_DATA(cpm_id)
			}

			# check if its an expected error code
			if {[info exists PSC_ERROR($error_code)]} {
				return [list 0 $PSC_ERROR($error_code)]
			} else {
				return [list 0 $PSC_ERROR(default)]
			}
		}
	}

	#Somthing is wrong with the resopnse body
	ob_log::write ERROR {ob_psc::_execute_debit: Invalid XML Format}
	return [list 0 "PMT_PSC_ERR_EXEC_DEBIT"]
}



# Sends a HTTPS request to PaySafeCard. XML response stored in PSC_RESP
#
# params_nv   - Request arguments to send to PaySafeCard (names and values).
# api_url     - The name of the api to which the request will be sent.
# conn_timeout - Timeout in ms for sending request.
# resp_timeout - Timeout in ms for awaiting response.
# ccy_code    - Certificate needed if over https which is currently ccy specific
# key_pw      - Password to unlock certificate's private key (only needed if
#               using certificate)
#
# return      - [1 OK] if successful or
#               [0 err_msg] otherwise
#
proc ob_psc::_send_request {
		params_nv
		api_url
		{conn_timeout 30000}
		{resp_timeout 30000}
		{ccy_code ""}
		{key_pw ""}
	} {

	variable PSC_CERT
	variable PSC_RESP

	# reset response array
	catch {unset PSC_RESP}

	ob_log::write INFO "ob_psc::_send_request: params_nv=$params_nv \
			api_url=$api_url ccy_code=$ccy_code"

	if {[catch {
		foreach {api_scheme api_host api_port api_urlpath junk junk} \
		  [ob_socket::split_url $api_url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {ob_psc::_send_request: Bad API URL - $msg}
		return [list 0 "PMT_PSC_ERR_REQ"]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "GET" \
		           -form_args  $params_nv \
		           $api_urlpath]
	} msg]} {
		ob_log::write ERROR "ob_psc::_send_request: Unable to build \
				PaySafeCard request - $msg"
		return [list 0 "PMT_PSC_ERR_REQ"]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	if {$api_scheme == "http"} {
		# -1 used by net_socket package to specify tls not to be used
		set tls -1
	} else {
		# need to set up args for call to tls::import made by the net_socket pkg

		# add certificate location
		if {![info exists PSC_CERT($ccy_code)]} {
			ob_log::write ERROR "ob_psc::_send_request: Certificate not specified \
					for ccy $ccy_code"
			return [list 0 "PMT_PSC_ERR_REQ"]
		}
		lappend tls_args "-certfile $PSC_CERT($ccy_code)"

		# add cert key password callback proc and set key password
		lappend tls_args "-password ob_psc::get_key_pw"
		set_key_pw $key_pw

		set tls [join $tls_args " "]
	}

	# Send the request to the PaySafeCard API url.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $conn_timeout \
		    -req_timeout  $resp_timeout \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob_log::write ERROR "ob_psc::_send_request: Unsure whether request \
				reached PaySafeCard, send_req failed - $msg"

		# reset key pw
		set_key_pw ""

		return [list 0 "PMT_PSC_ERR_REQ"]
	}

	# reset key pw
	set_key_pw ""

	if {$status == "OK"} {

		# Request successful - get and return the response data.
		set res_body [string trim [::ob_socket::req_info $req_id http_body]]
		ob_log::write INFO "ob_psc::_send_request: Request successful, response\
				is $res_body"
		::ob_socket::clear_req $req_id

		# parse and store response
		if {[catch {
			parse_xml::parseBody $res_body 1
			upvar parse_xml::XML_RESPONSE ::ob_psc::PSC_RESP
		} msg]} {
			ob_log::write ERROR "ob_psc::_send_request: Unable to parse \
					response $msg"
			return [list 0 "PMT_PSC_ERR_REQ"]
		}

		return [list 1 "OK"]

	} else {

		# Request failed - return failure.
		ob_log::write INFO "ob_psc::_send_request: Request NOT successful, \
				status was $status"

		# Is there a chance this request might actually have got to PaySafeCard
		if {[::ob_socket::server_processed $req_id]} {
			ob_log::write ERROR "ob_psc::_send_request: Unsure whether \
					request reached PaySafeCard, status was $status"
			set err_msg "PMT_PSC_ERR_REQ"
		} else {
			ob_log::write ERROR "ob_psc::_send_request: Unable to send request \
					to PaySafeCard, status was $status"
			set err_msg "PMT_PSC_ERR_REQ"
		}

		::ob_socket::clear_req $req_id

		return [list 0 $err_msg]
	}

}



#
# This is the function that is called first when a customer
# says he/she wants to deposit from PSC. If this is successful,
# then the customer is redirected to the PSC payment panel.
#
proc ob_psc::create_disposition {
		cust_id
		acct_id
		cpm_id
		channel
		ccy_code
		payment_sort
		unique_id
		amount
		okurl
		nokurl
	} {

	variable PSC_RESP
	variable PSC_ERROR

	ob_log::write INFO {ob_psc::create_disposition}

	init

	ob_log::write DEBUG {PSC okurl  = $okurl}
	ob_log::write DEBUG {PSC nokurl = $nokurl}

	# retrieve gateway details. need to set up some variables so rules can
	# be evaluated
	set PMT_DATA(pay_mthd)       "PSC"
	set PMT_DATA(ccy_code)       $ccy_code
	set PMT_DATA(pay_sort)       $payment_sort

	# get gateway details, these will be set in the PMT_DATA array
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]
	if {[lindex $pg_result 0] == 0} {
		set msg [lindex $pg_result 1]
		ob_log::write ERROR "ob_psc::create_disposition - couldn't obtain \
				host details - $msg"
		return [list 0 "PMT_PSC_ERR_CREATE_DISP"]
	}

	# insert payment
	foreach {ok data} [insert_pmt \
		$acct_id \
		$cpm_id \
		$payment_sort \
		$amount \
		$PMT_DATA(pg_host_id) \
		$PMT_DATA(pg_acct_id) \
		$channel \
		$unique_id \
	] {}

	if {$ok} {
		set pmt_id $data
	} else {
		set err $data
		return [list 0 $err]
	}

	# append transaction information to return urls
	append okurl  [create_enc_str $cust_id $pmt_id $amount $ccy_code 0]
	append nokurl [create_enc_str $cust_id $pmt_id $amount $ccy_code 1]

	# Prepare the URL
	set api_url "$PMT_DATA(host)/CreateDispositionServlet"

	# Get the required parameters for this request
	set params_nv [list \
	                "mid"               $PMT_DATA(mid) \
	                "mtid"              $unique_id \
	                "amount"            $amount \
	                "currency"          $ccy_code \
	                "businesstype"      "I" \
	                "reportingcriteria" "" \
	                "okurl"             $okurl \
	                "nokurl"            $nokurl \
	                "outputFormat"      "xml_v1"]

	# Send the request
	foreach {status response} [_send_request \
			$params_nv \
			$api_url \
			$PMT_DATA(conn_timeout) \
			$PMT_DATA(resp_timeout) \
			$ccy_code \
			$PMT_DATA(key) \
	] {}

	if {$status == 0} {
		ob_log::write INFO {ob_psc::create_disposition: Send request failed - $response}
		return [list 0 $response]
	}

	# check response
	if {[info exists PSC_RESP(PaysafecardTransaction,txCode)]} {

		# return code of 0 => success
		if {$PSC_RESP(PaysafecardTransaction,txCode) == 0} {

			# Before redirecting the customer update the payment to an (I)ncomlete status
			if {![update_pmt $pmt_id "I"]} {
				return [list 0 "PMT_PSC_ERR_CREATE_DISP"]
			}

			return [list 1 "OK" $PMT_DATA(mid)]

		# return code of 1 => logical error, 2 ==> technical error
		} elseif {$PSC_RESP(PaysafecardTransaction,txCode) == 1 || $PSC_RESP(PaysafecardTransaction,txCode) == 2} {

			ob_log::write ERROR "ob_psc::create_disposition: txCode \
					$PSC_RESP(PaysafecardTransaction,txCode)"

			set error_code $PSC_RESP(PaysafecardTransaction,errCode)
			set error_msg  $PSC_RESP(PaysafecardTransaction,errMessage)

			set uid ""
			if {[info exists PSC_RESP(PaysafecardTransaction,MTID)]} {
				set uid $PSC_RESP(PaysafecardTransaction,MTID)
			}

			ob_log::write ERROR "ob_psc::create_disposition: Disposition is \
					unsuccessful - err_code=$error_code, error_msg=$error_msg"

			if {![update_pmt $pmt_id \
				             "N" \
							 "" \
				             $error_code \
				             $error_msg \
				             "N"]} {

				return [list 0 "PMT_PSC_ERR_CREATE_DISP"]
			}

			# check if its an expected error code
			return [list 0 "PMT_PSC_ERR_CREATE_DISP"]
		}

	}

	#Somthing is wrong with the resopnse body
	ob_log::write ERROR {ob_psc::create_disposition: Invalid XML Format}
	return [list 0 "PMT_PSC_ERR_CREATE_DISP"]
}



#
# Update payment details. Allow null defaults for args as pPmtUpdPSC will not
# update pmt field to null if a value is set
#
# status - tPmt.status
# state - tPmtPSC.state
#
proc ob_psc::update_pmt {
		pmt_id
		{status ""}
		{state ""}
		{errcode ""}
		{errmessage ""}
		{transactional "Y"}
	} {

	init

	if {[catch {
		set rs [ob_db::exec_qry ob_psc::update_pmt \
				$pmt_id \
				$status \
				$state \
				$errcode \
				$errmessage \
				$transactional \
		]
	} msg]} {
		ob_log::write ERROR {ob_psc::update_pmt - Unable to update pmt - $msg}
		return 0
	} else {
		ob_db::rs_close $rs
		return 1
	}
}



#
# Insert PSC payment method for customer
#
proc ob_psc::insert_cpm_psc {cust_id {transactional Y}} {

	ob_log::write INFO {ob_psc::insert_cpm_psc cust_id = $cust_id}

	init

	if {[catch {
		set rs [ob_db::exec_qry ob_psc::ins_cpm_psc $cust_id $transactional]
	} msg]} {

		ob_log::write ERROR {ob_psc::insert_cpm_psc failed to add PSC CPM: $msg}

		# try and parse msg for error
		set err_list [list \
			PMT_PSC_ERR_CPM_SUSP \
		]

		set err ACCT_CANT_ADD_CPM
		if {[lsearch $err_list [lindex $msg end]] > -1} {
			set err [lindex $msg end]
		}

		return [list 0 $err]
	}

	set cpm_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	ob_log::write INFO {ob_psc::insert_cpm_psc new PSC CPM: cpm_id = $cpm_id}
	return [list 1 $cpm_id]

}



proc ob_psc::insert_pmt {
		acct_id
		cpm_id
		payment_sort
		amount
		pg_host_id
		pg_acct_id
		channel
		unique_id
	} {

	ob_log::write INFO {ob_psc::insert_pmt for acct_id $acct_id amount $amount}

	init

	# payment defaults
	set ipaddr        [reqGetEnv REMOTE_ADDR]
	set amount        [format %.2f $amount]
	set transactional "Y"
	set pay_mthd      "PSC"
	set status        "P"

	# Useful during debugging to be able to do lots of payments.
	if { [OT_CfgGetTrue DISABLE_PMT_SPEED_CHECK] } {
		set speed_check N
		ob_log::write INFO {Speed check disabled for PSC payments}
	} else {
		set speed_check Y
	}

	#
	# Attempt to insert the payment
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_psc::ins_pmt \
			$acct_id \
			$cpm_id \
			$payment_sort \
			$amount \
			$pg_host_id \
			$pg_acct_id \
			$ipaddr \
			$channel \
			$unique_id \
			$status \
			$speed_check \
			$transactional \
		]
	} msg]} {

		ob_log::write ERROR {ob_psc::insert_pmt - $msg}

		return [list 0 [payment_gateway::cc_pmt_get_sp_err_code $msg PMT_PSC_ERR_CREATE_DISP]]
	}

	set pmt_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	# Send monitor message if monitors are configured on
	if {[OT_CfgGet MONITOR 0] && [OT_CfgGet PAYMENT_TICKER 0]} {

		# store some information in an array used by the monitor proc
		set DATA(type)              "PSC"
		set DATA(acct_id)           $acct_id
		set DATA(cpm_id)            $cpm_id
		set DATA(amount)            $amount
		set DATA(payment_sort)      $payment_sort
		set DATA(ipaddr)            $ipaddr
		set DATA(source)            $channel

		ob_log::write INFO "ob_psc::insert_pmt - Sending monitor msg for PSC \
				pmt_id $pmt_id"

		if {![OB_gen_payment::send_pmt_ticker \
				$pmt_id \
				[clock format [clock seconds] -format {%Y-%m-%d %T}] \
				$status \
				DATA \
			]} {

			ob_log::write ERROR "ob_psc::insert_pmt - Unable to send monitor \
					msg for PSC pmt_id $pmt_id"
		}
	}

	return [list 1 $pmt_id]
}



#
# Returns key set by ob_psc::set_key_pw. Will typically be used as the callback
# proc by the tls package (in place of tls::password)
#
proc ob_psc::get_key_pw {} {

	variable PSC_KEY_PW

	return $PSC_KEY_PW
}



#
# Set the key password to be returned by ob_psc::get_key_pw
#
proc ob_psc::set_key_pw {key_pw} {

	variable PSC_KEY_PW

	set PSC_KEY_PW $key_pw
}



#
# Create an encrypted string to be appended to the return urls sent to PSC
#
proc ob_psc::create_enc_str {cust_id pmt_id amount ccy_code pmt_cancel} {

	set str [join [list $cust_id $pmt_id $amount $ccy_code $pmt_cancel] "|"]
	set enc_str [ob_crypt::encrypt_by_bf $str]

	return $enc_str
}



#
# Parse encrypted string created by ob_psc::create_enc_str
#
proc ob_psc::parse_enc_str {enc_str} {

	set str [ob_crypt::decrypt_by_bf $enc_str]
	set exp {^(\d+)\|(\d+)\|(\d+.\d\d)\|(\w+)\|(\d+)$}

	if {![regexp $exp $str -> cust_id pmt_id amount ccy_code pmt_cancel]} {
		return [list 0 "" "" "" "" ""]
	}

	return [list 1 $cust_id $pmt_id $amount $ccy_code $pmt_cancel]
}



#
# Construct locale string based on language
#
proc ob_psc::get_locale {lang} {

	variable PSC_LOCALES

	set default "en_uk"
	if {[info exists PSC_LOCALES(default)]} {
		set default $PSC_LOCALES(default)
	}

	if {[info exists PSC_LOCALES($lang)]} {
		return $PSC_LOCALES($lang)
	}

	return $default
}



#
# Remove a PSC payment method (if no successful/active payments)
#
#   cpm_id - id of payment method to remove
#
#  returns - 1 on successful removal, 0 otherwise
#
proc ob_psc::remove_cpm_on_first_payment { cpm_id } {

	ob_log::write INFO {ob_psc::remove_cpm_on_first_payment cpm_id: $cpm_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_psc::remove_cpm $cpm_id $cpm_id]
	} msg]} {
		ob_log::write ERROR "ob_psc::remove_cpm_on_first_payment Error \
				executing query ob_psc::remove_cpm - $msg"
		return 0
	}

	# did we remove?
	if {![ob_db::garc ob_psc::remove_cpm]} {
		ob_log::write INFO "ob_psc::remove_cpm_on_first_payment Did not remove \
				cpm: $cpm_id"
		return 0
	}

	return 1
}



#
# prep queries
#
proc ob_psc::_prepare_qrys args {

	ob_log::write INFO {ob_psc::_prepare_qrys}

	# insert new paysafecard payment method
	ob_db::store_qry ob_psc::ins_cpm_psc {
		execute procedure pCPMInsPSC (
			p_cust_id  = ?,
			p_auth_dep = 'P',
			p_status_dep = 'A',
			p_auth_wtd = 'N',
			p_status_wtd = 'S',
			p_disallow_wtd_rsn  = 'Withdrawals not supported by PSC',
			p_balance_check = 'Y',
			p_transactional = ?
		)
	}

	# insert paysafecard payment
	ob_db::store_qry ob_psc::ins_pmt {
		execute procedure pPmtInsPSC (
			p_acct_id       = ?,
			p_cpm_id        = ?,
			p_payment_sort  = ?,
			p_amount        = ?,
			p_pg_host_id    = ?,
			p_pg_acct_id    = ?,
			p_ipaddr        = ?,
			p_source        = ?,
			p_unique_id     = ?,
			p_status        = ?,
			p_speed_check   = ?,
			p_transactional = ?
		)
	}

	# update payment details
	ob_db::store_qry ob_psc::update_pmt {
		execute procedure pPmtUpdPSC (
			p_pmt_id             = ?,
			p_status             = ?,
			p_state              = ?,
			p_errcode            = ?,
			p_errmessage         = ?,
			p_transactional      = ?
		)
	}

	# Get payment details
	ob_db::store_qry ob_psc::load_pmt {
		select
			p.amount,
			p.unique_id,
			p.cpm_id,
			a.ccy_code,
			pgh.pg_ip as host,
			pgh.resp_timeout,
			pgh.conn_timeout,
			pga.pg_acct_id,
			pga.data_key_id,
			pga.enc_mid,
			pga.enc_mid_ivec,
			pga.enc_key,
			pga.enc_key_ivec
		from
			tPmt  p,
			tPmtPSC psc,
			tPmtGateAcct pga,
			tPmtGateHost pgh,
			tAcct a
		where
			p.pmt_id  = ? and
			p.acct_id = a.acct_id and
			a.cust_id = ? and
			p.pmt_id = psc.pmt_id and
			psc.pg_acct_id = pga.pg_acct_id and
			psc.pg_host_id = pgh.pg_host_id
	}

	# insert additional paysafecard information
	ob_db::store_qry ob_psc::ins_psc_info {
		execute procedure pInsPSCInfo (
			p_pmt_id     = ?,
			p_psc_serial = ?,
			p_psc_value  = ?
		)
	}

	# remove a customer payment method (only if there are no successful/
	# incomplete payments on it)
	ob_db::store_qry ob_psc::remove_cpm {
		update tCustPayMthd set
			status = 'X'
		where
			cpm_id = ? and
			pay_mthd = 'PSC' and
			not exists (
				select
					pmt_id
				from
					tPmt
				where
					cpm_id = ? and
					status not in ('N','X')
			)
	}

	# check for serial numbers for a pmt
	ob_db::store_qry ob_psc::serials_for_pmt {
		select
			count(*)
		from
			tPSCInfo
		where
			pmt_id = ?
	}
}

