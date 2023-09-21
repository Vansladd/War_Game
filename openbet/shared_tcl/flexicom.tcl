# $Id: flexicom.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# Flexicom Authorisation Host
# ---------------------------
# This script implements a client for the Fleixcom Authorisation Server.
# It performs authorisation requests on demand.
#
# This script relies on the global array FLEXICOM_CONFIG for its
# configuration information.
# The following variables in array FLEXICOM_CONFIG MUST be set
# with appropriate values before calling any procedures
# in this namespace:
#  - SERVER:
#      IP address or host name of server
#  - PORT:
#      The port number of the server
#
# The following variable in array FLEXICOM_CONFIG may be set
# before calling any procedures in this namespace:
#  - MERCHANT_NO:
#     The merchant number to use.
#     If this is left unset, then server will derive the merchant number
#     from the server's internal config files.
#  - TERMINAL_ID:
#     The terminal id to use.
#     If this is left unset, then server will derive the terminal id
#     from the server's internal config files.
# If any of the above are set, then it will apply to all transactions
# that are authorised after they have been set.
#
#
namespace eval Flexicom {

namespace export flexicom_init
namespace export make_flexicom_call

namespace export authorise
namespace export testharness

# field separating value
variable FIELD_SEP ","

# unit separating value
variable UNIT_SEP "\x1F"

# success value from auth server
variable RESPONSE_OK "00"

# transaction types
variable TRANS_TYPES
array set TRANS_TYPES {
	"P" "01"
	"p" "01"
	"D" "01"
	"d" "01"
	"R" "02"
	"r" "02"
	"W" "02"
	"w" "02"
}

# textual description of some error codes
variable ERROR_CODES
array set ERROR_CODES {
	"RA" "Lost or stolen card"
	"RX" "Unsupported card scheme"
	"RB" "Not authorised"
	"A0" "Incorrect number of fields in auth request"
	"A1" "Bad track2 data"
	"A2" "Bad expiry date"
	"A3" "Bad field length"
	"A4" "Bad field type"
	"B0" "Bad track2 LRC (swiped cards only)"
	"B1" "Bad card number"
	"B2" "Card past expiry date"
	"B3" "Card before effective date"
	"C0" "Total amount above purchase ceiling limit"
	"C1" "Cashback amount above cashback ceiling limit"
	"C2" "Cashback not permitted for card"
	"C3" "Cashback greater than total amount"
	"D0" "Currency request not supported"
	"D1" "Unknown card scheme"
	"D2" "Unsupported on-line comms method"
	"E0" "Internal error: bad currency table"
	"E1" "Internal error: currency conversion error"
	"E2" "Internal error: timeout response"
	"E3" "Invalid host response"
	"E4" "Pipe error: internal system comms error"
}

#
# Initialise the flexicom payment gateway
#
proc flexicom_init {} {

}

#
# This is the function that is called by payment_gateway for making
# calls to the flexicom gateway
#
proc make_flexicom_call {ARRAY} {

	 upvar $ARRAY PMT

	if { $PMT(pay_sort) == "D" } {
		set payment_sort "D"
	} elseif { $PMT(pay_sort) == "W" } {
		set payment_sort "W"
	}

	set sdate "[string range $PMT(start) 3 4][string range $PMT(start) 0 1]"
	set edate "[string range $PMT(expiry) 3 4][string range $PMT(expiry) 0 1]"


	OT_LogWrite 5 "sdate = $sdate, edate = $edate"


	if [catch {set results [::Flexicom::authorise $payment_sort $PMT(card_no) $edate [expr int ( $PMT(amount) * 100 )] [flexicom_convert $PMT(ccy_code)] "0000" $PMT(host) $PMT(port) "" $PMT(issue_no)] } errmsg ] {
		err_add $errmsg
		return PMT_ERR
	}

	array set response $results

	set PMT(gw_ret_code)     $response(RESP_CODE)
	set PMT(card_type)       $response(CARD_SCHEME)
	set PMT(merchant_no)     $response(MERCHANT_NO)
	set PMT(gw_uid)          $response(ACSC)
	set PMT(gw_auth_code)    $response(AUTH_CODE)
	set PMT(display_text)    $response(DISPLAY_TEXT)
	set PMT(print_text)      $response(PRINT_TEXT)
	set PMT(aux_text)        $response(AUX_TEXT)
	set PMT(gw_ret_msg)      $results


	OT_LogWrite 5 "Response code = $response(RESP_CODE) "

	switch $PMT(gw_ret_code) {
		"00" { return OK }
		"RA" { return PMT_RA }
		"RX" { return PMT_RX }
		"B1" { return PMT_B1 }
		"B2" { return PMT_B2 }
		"B3" { return PMT_B3 }
		"C0" { return PMT_C0 }
		"D1" { return PMT_RX }
		default { return PMT_ERR }
	}
}

proc flexicom_convert {txt_code} {

	#
	# Takes a ccy code as used by the databse (GBP,IEP etc.)
	# and returns the iso equivalent for use with Flexicom xfers
	#
	if {$txt_code=="GBP"} {
		# English Pounds
		return "0826"
	} elseif {$txt_code=="EUR"} {
		# Euros
		return "0978"
	} elseif {$txt_code=="USD"} {
		# US Dollars
		return "0840"
	} elseif {$txt_code=="AUD"} {
		# Australian Dollars
		return "0036"
	} elseif {$txt_code=="HKD"} {
		# Hong Kong Dollars
		return "0344"
	} elseif {$txt_code=="IEP"} {
		# Irish Punts
		return "0372"
	}

	# Not known. Generate a Flexicom error.
	return "xxxx"
}




#
# Method to call to authorise a request
# Arguments passed to this method MUST NOT
# contain a comma (\x2C) character
#
# args:
#  - trans_type:
#    Set to P, D if it is a payment request, else
#    set to R, W if it is a refund request.
#  - card_no:
#    The card number to use (must be <= 22 in length)
#  - expiry_date
#    The card's expiry date in YYMM format.
#  - amount
#    The amount to authorise, must be in base unit of currency.
#    (e.g. for UK pounds use pence, for Italian lira use lira.)
#  - currency
#    The currency code used as specified by ISO 3166
#  - dept_id:
#    The department id to use, must be a 4 digit number.
#  - ref_text:
#    Reference text to be recorded with transaction (must be <= 40 in length)
#    This is an optional arg, defaults to empty string.
#  - issue_no:
#    The card issue number to use. Can be empty, or it must be 2 digits.
#    This is an optional arg, defaults to empty string.
#  - off_auth_code
#    The off-line auth code. Can be empty, or it must be <= 9 in length.
#    This is an optional arg, defaults to empty string.
#  - serat_no:
#    The SERAT number. Can be empty, or it must be <= 15 in length.
#    This is an optional arg, defaults to empty string.
#
#
# returns:
#  - A flatten array which can be reconstructed using the tcl command 'array set'.
#    This array contains the response from the server:
#      RESP_CODE - response code - RESPONSE_OK for success
#      CARD_SCHEME - card scheme
#      MERCHANT_NO - merchant number
#      ACSC - authorisation code source code
#      AUTH_CODE - authorisation code
#      DISPLAY_TEXT - information text
#      PRINT_TEXT - information text
#      AUX_TEXT - information text
#
proc authorise { trans_type card_no expiry_date amount currency_code dept_id server port
		{ref_text ""} {issue_no ""} {off_auth_code ""} {serat_no ""} } {

	OT_LogWrite 3 "$ref_text: authorising"

	# Validate the input arguments
	set errmsgs [validateAuthRequest $trans_type \
			$card_no $expiry_date $amount \
			$currency_code $dept_id \
			$ref_text $issue_no $off_auth_code $serat_no]
	if { [llength $errmsgs] > 0 } {
		# got bad input
		set errmsg [join $errmsgs "\n"]
		OT_LogWrite 1 "ERROR: bad args given for authorise: $errmsg"
		error "$ref_text: bad args given: $errmsg"
	}

	# format the message
	set request [packAuthRequest $trans_type \
			$card_no $expiry_date $amount \
			$currency_code $dept_id \
			$ref_text $issue_no $off_auth_code $serat_no]

	OT_LogWrite 3 "$ref_text: request auth msg built"

	# create the socket
	if [catch {set sock [socket $server $port]} msg] {
		OT_LogWrite 1 "ERROR: $ref_text: failed to establish socket to $server:$port : $msg"
		error "$ref_text: failed to establish socket to $server:$port"
	}
	OT_LogWrite 3 "$ref_text: socket $server:$port ==> $sock"

	# send the request
	if [catch {puts $sock $request; flush $sock} msg] {
		OT_LogWrite 1 "ERROR: $ref_text: failed to send flexicom request : $msg"
		catch {close $sock}
		error "$ref_text: failed to send request"
	}
	OT_LogWrite 3 "$ref_text: reading response..."

	# retreive the response
	if [catch {gets $sock resp_msg} msg] {
		OT_LogWrite 1 "ERROR: $ref_text: failed to read flexicom response : $msg"
		catch {close $sock}
		error "$ref_text: failed to read response"
	}

	# close the socket to the server
	catch {close $sock}
	OT_LogWrite 3 "$ref_text: auth response retrieved"

	# unpack the response
	set response(RESP_CODE) ""
	unpackAuthResponse $ref_text $resp_msg response

	# validate the response
	set errmsgs [validateAuthResponse $ref_text response]
	if { [llength $errmsgs] > 0 } {
		set errmsg [join $errmsgs "\n"]
		OT_LogWrite 1 "ERROR: $ref_text: bad auth response from server: $errmsg"
		error "$ref_text: bad response from server: $errmsg"
	}

	OT_LogWrite 3 "$ref_text: auth response validated okay"

	return [array get response]
}


#
# Validates the authorisation request args.
#
proc validateAuthRequest { trans_type card_no expiry_date amount currency_code dept_id
		ref_text issue_no off_auth_code serat_no } {

	variable TRANS_TYPES

	set errmsgs {}

	# check for commas in arguments
	foreach {n v} [list \
		"trans_type" "$trans_type" \
		"card_no" "$card_no" \
		"expiry_date" "$expiry_date" \
		"amount" "$amount" \
		"currency_code" "$currency_code" \
		"dept_id" "$dept_id" \
		"ref_text" "$ref_text" \
		"issue_no" "$issue_no" \
		"off_auth_code" "$off_auth_code" \
		"serat_no" "$serat_no" \
	] {
		if { [string first "," "$v"] > -1 } {
			lappend errmsgs "$n '$v' MUST NOT contain a comma"
		}
	}

	if { ![info exists TRANS_TYPES($trans_type)] } {
		# transaction type is invalid
		set t [join [array names TRANS_TYPES] " or "]
		lappend errmsgs "trans_type '$trans_type' must be $t"
	}

	if { ![isNumber $card_no "y"] } {
		# card no not a number
		lappend errmsgs "card_no '$card_no' must be a valid card number"
	} elseif { [string length [delWhiteSpace $card_no] ] > 22 } {
		# card no too long
		lappend errmsgs "card_no '${card_no}' must be <= 22 in length"
	}

	if { ![isYYMMFormat $expiry_date] } {
		# expiry date not a nubmer
		lappend errmsgs "expiry_date '$expiry_date' must be in YYMM format"
	}

	if { ![isNumber $amount] } {
		# amount is not a number
		lappend errmsgs "amount '$amount' must be a whole number"
	} elseif { [string length $amount] > 20 } {
		# amount too long
		lappend errmsgs "amount '${amount}' must be <= 20 in length"
	} elseif { $amount < 1 } {
		# amount is zero
		lappend errmsgs "amount '${amount}' must be > 0 in value"
	}

	if { ![isNumber $currency_code] } {
		# currency code is not a number
		lappend errmsgs "currency_code '$currency_code' must be a number"
	} elseif { [string length $currency_code] != 4 } {
		# currency code not right length
		lappend errmsgs "currency_code '${currency_code}' must be a 4 digit number"
	}

	if { ![isNumber $dept_id] } {
		# dept id is not a number
		lappend errmsgs "dept_id '$dept_id' must be a number"
	} elseif { [string length $dept_id] != 4 } {
		# dept id not right length
		lappend errmsgs "dept_id '${dept_id}' must be a 4 digit number"
	}

	if { [string length $ref_text] > 40 } {
		# ref text too long
		lappend errmsgs "ref_text '${ref_text}' must be <= 40 in length"
	}

	if { ![isNumber $issue_no "n" "y"] } {
		# issue not a number
		lappend errmsgs "issue_no '${issue_no}' must be a number"
	} elseif { [string length $issue_no] > 2 } {
		# issue number too long
		lappend errmsgs "issue_no '${issue_no}' must be <= 2 in length"
	}

	if { [string length $off_auth_code] > 9 } {
		# auth code too long
		lappend errmsgs "off_auth_code '${off_auth_code}' must be <= 9 in length"
	}

	if { [string length $serat_no] > 15 } {
		# serat number too long
		lappend errmsgs "serat_no '${serat_no}' must be <= 15 in length"
	}

	return $errmsgs
}


#
# Format the request into some bytes that can be sent down a socket
#
proc packAuthRequest { trans_type card_no expiry_date amount currency_code dept_id
		ref_text issue_no off_auth_code serat_no } {

	variable FIELD_SEP
	variable UNIT_SEP
	variable TRANS_TYPES

	set fields {}

	# track 1 not used
	lappend fields ""

	# track 2 used for card details
	set card_details $UNIT_SEP
	append card_details [delWhiteSpace $card_no]
	append card_details $UNIT_SEP
	append card_details $expiry_date
	if { $issue_no != "" } {
		append card_details $UNIT_SEP
		append card_details $issue_no
	}
	lappend fields $card_details

	# track 3 not used
	lappend fields ""

	# request type
	lappend fields $TRANS_TYPES($trans_type)

	# request id - not used
	lappend fields "0000"

	# department id
	lappend fields $dept_id

	# total amount
	lappend fields [expr int($amount)]

	# cashback amount - not used
	lappend fields ""

	# currency code
	lappend fields $currency_code

	# off-line auth code
	lappend fields $off_auth_code

	# merchant number
	lappend fields [getMerchantNo]

	# SERAT number
	lappend fields $serat_no

	# terminal id
	lappend fields [getTerminalId]

	# auxiliary text
	lappend fields $ref_text

	set msg [join $fields $FIELD_SEP]
	# use lowest log level for logging card details
	# OT_LogWrite 10 "$ref_text: request auth msg: [binToStr $msg]"

	return $msg
}

#
# Format the response into an array
#
proc unpackAuthResponse { ref_text msg response_name } {

	variable FIELD_SEP

	# get handle to results array
	upvar $response_name response


	# parse the response message
	set fields [split $msg $FIELD_SEP]

	set l [llength $fields]
	set i 0
	foreach n {
		"RESP_CODE"
		"CARD_SCHEME"
		"MERCHANT_NO"
		"ACSC"
		"AUTH_CODE"
		"DISPLAY_TEXT"
		"PRINT_TEXT"
		"AUX_TEXT"
	} {

		if { $l > $i } {
			set response($n) [lindex $fields $i]
		} else {
			set response($n) ""
		}
		OT_LogWrite 10 "$ref_text: auth response($n)=$response($n)"
		incr i
	}

}

#
# Validate that the response is correct
#
proc validateAuthResponse { ref_text response_name } {

	variable RESPONSE_OK

	# get handle to results array
	upvar $response_name response

	set errmsgs {}

	if { $response(RESP_CODE) == "" } {
		lappend errmsgs "No response code retrieved"
	} elseif { $response(RESP_CODE) == $RESPONSE_OK } {
		if { $response(AUTH_CODE) == "" } {
			lappend errmsgs "No auth code retrieved"
		}
	}

	return $errmsgs
}

#
# Returns the merchant no from FLEXICOM_CONFIG
#
proc getMerchantNo {} {
	global FLEXICOM_CONFIG

	if { [info exists FLEXICOM_CONFIG(MERCHANT_NO)] } {
		set v $FLEXICOM_CONFIG(MERCHANT_NO)
		set l [string length $v]

		if { [isNumber $v "n" "y"] && ($l <= 12) } {
			# merchant is empty, or a number that is less than 13 in length
			return $v
		} else {
			# invalid length
			error "merchant no. must be empty or 12 characters or less in length"
		}
	}

	# doesn't need to be set in config array
	return ""
}

#
# Returns the terminal id from FLEXICOM_CONFIG
#
proc getTerminalId {} {
	global FLEXICOM_CONFIG

	if { [info exists FLEXICOM_CONFIG(TERMINAL_ID)] } {
		set v $FLEXICOM_CONFIG(TERMINAL_ID)
		set l [string length $v]

		if { $l == 0 } {
			# terminal id is empty
			return ""
		} elseif {$l < 8 } {
			# need to left-justify, space padded the terminal id
			for {set i 0} {$i < (8 - $l) } {incr i} {
				append v " "
			}
			return $v
		} elseif {$l == 8 } {
			return $v
		} else {
			# invalid length
			error "terminal id must be empty or 8 characters or less in length"
		}
	}

	# doesn't need to be set in config array
	return ""
}

#
# If ignore_space is set to "y", then spaces are ignored.
# If empty_ok is set to "y", then val can be empty.
# Returns 1 if val is a number,
# otherwise returns 0.
#
proc isNumber { val {ignore_space ""} {empty_ok ""} } {

	if { $empty_ok == "y" } {
		# can be empty
		if { [string length $val] == 0 } {
			return 1
		}
	}

	set exp {^[0-9]+$}
	if { $ignore_space == "y" } {
		# spaces allowed
		set exp {^[0-9 ]+$}
	}

	return [regexp $exp $val]
}

#
# Returns 1 if val contains 4 digits, with last 2 digits a valid month,
# otherwise returns 0
#
proc isYYMMFormat { val } {

	if { [regexp {^([0-9][0-9])([0-9][0-9])$} $val dummy yy mm] == 1 } {
		# convert 00 - 09 into numbers
		set mm [convertToNumber $mm]

		# make sure its a valid month
		if { ($mm >= 1) && ($mm <= 12) } {
			return 1
		}
	}

	return 0
}

proc convertToNumber { val } {

	set x [string trimleft $val 0]
	if { $x == "" } {
		return 0
	}

	return $x
}

#
# Returns val with whitespace removed
#
proc delWhiteSpace { val } {
	return [join [split $val] {} ]
}


#
# Self test for this package
#
proc testharness {} {

	global FLEXICOM_CONFIG


	if { ![info exists FLEXICOM_CONFIG(SERVER)] } {
		set FLEXICOM_CONFIG(SERVER) "daz.orbis-local.co.uk"
	}
	if { ![info exists FLEXICOM_CONFIG(PORT)] } {
		set FLEXICOM_CONFIG(PORT) 8000
	}

	eval {proc OT_LogWrite { level msg } { puts "DBG($level): $msg"}}

	OT_LogWrite 1 "Starting selftest..."

	#
	# test each individual method
	#
	#	"validateAuthRequestTest"
	#	"authoriseTest"
	foreach p {
		"authoriseTest"
	} {
		OT_LogWrite 1 $p
		if [catch $p msg] {
			OT_LogWrite 1 "Failed $p: $msg"
		} else {
			OT_LogWrite 1 "Passed $p"
		}
	}

}

#
# Test validation method
#
proc validateAuthRequestTest {} {

	set data {}

	# field order:
	#   testId result_expected
	#   trans_type card_no expiry_date amount currency_code dept_id
	#   ref_text issue_no off_auth_code serat_no

	# good fields
	lappend data { 1 "G" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "0001" "test" "" "" "" }
	# no trans_type
	lappend data { 2 "B" "" "123456" "0012" "10000" "0372" "0001" "test" "" "" "" }
	# bad trans_type
	lappend data { 3 "B" "0" "123456" "0012" "10000" "0372" "0001" "test" "" "" "" }
	# no card number
	lappend data { 4 "B" "P" "" "0012" "10000" "0372" "0001" "test" "" "" "" }
	# bad card number digits
	lappend data { 5 "B" "P" "adfdafd123456" "0012" "10000" "0372" "0001" "test" "" "" "" }
	# bad card number size
	lappend data { 6 "B" "P" "12345678901234567890123" "0012" "10000" "0372" "0001" "test" "" "" "" }
	# no expiry date
	lappend data { 7 "B" "P" "1234567890 1234567890 12" "" "10000" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 8 "B" "P" "1234567890 1234567890 12" "abcd" "10000" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 9 "B" "P" "1234567890 1234567890 12" "001" "10000" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 10 "B" "P" "1234567890 1234567890 12" "00 1" "10000" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 11 "B" "P" "1234567890 1234567890 12" "1200" "10000" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 12 "B" "P" "1234567890 1234567890 12" "01111" "10000" "0372" "0001" "test" "" "" "" }
	# no amount
	lappend data { 13 "B" "P" "1234567890 1234567890 12" "0112" "" "0372" "0001" "test" "" "" "" }
	# bad amount
	lappend data { 14 "B" "P" "1234567890 1234567890 12" "0112" "abcd" "0372" "0001" "test" "" "" "" }
	# bad amount
	lappend data { 15 "B" "P" "1234567890 1234567890 12" "0112" "0" "0372" "0001" "test" "" "" "" }
	# bad amount
	lappend data { 16 "B" "P" "1234567890 1234567890 12" "0112" "00 00" "0372" "0001" "test" "" "" "" }
	# bad amount
	lappend data { 17 "B" "P" "1234567890 1234567890 12" "0112" "0000" "0372" "0001" "test" "" "" "" }
	# bad amount
	lappend data { 18 "B" "P" "1234567890 1234567890 12" "0112" "123456789012345678901" "0372" "0001" "test" "" "" "" }
	# bad issue number
	lappend data { 19 "B" "P" "1234567890 1234567890 12" "a" "10000" "0372" "0001" "test" "1" "" "" }
	# bad issue number
	lappend data { 20 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "0001" "test" "a" "" "" }
	# bad issue number
	lappend data { 21 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "0001" "test" "001" "" "" }
	# bad currency code
	lappend data { 21 "B" "P" "1234567890 1234567890 12" "0112" "10000" "aaaa" "0001" "test" "01" "" "" }
	# bad currency code
	lappend data { 21 "B" "P" "1234567890 1234567890 12" "0112" "10000" "00001" "0001" "test" "01" "" "" }
	# bad dept id
	lappend data { 21 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "aaaa" "test" "01" "" "" }
	# bad dept id
	lappend data { 21 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "00011" "test" "01" "" "" }
	# bad off-line auth code
	lappend data { 22 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "0001" "test" "00" "1234567890" "" }
	# bad serat number
	lappend data { 23 "B" "P" "1234567890 1234567890 12" "0112" "10000" "0372" "0001" "test" "00" "1234567" "1234567890123456789" }
	# bad everything
	lappend data { 24 "B" "," "," "," "," "," "," "," "," "," ","}

	set failed {}

	foreach {
		test_id
		expected
		trans_type
		card_no
		expiry_date
		amount
		currency_code
		dept_id
		ref_text
		issue_no
		off_auth_code
		serat_no
	} [join $data] {

		set errmsgs [validateAuthRequest $trans_type \
				$card_no $expiry_date $amount \
				$currency_code $dept_id \
				$ref_text $issue_no $off_auth_code $serat_no ]
		set errlen [llength $errmsgs]
		if {$expected == "G"} {
			# no error message expected
			if { $errlen == 0 } {
				OT_LogWrite 1 "Passed test $test_id"
			} else {
				OT_LogWrite 1 "Failed test $test_id"
				lappend failed $test_id
			}
		} else {
			# error message expected
			if { $errlen == 0 } {
				OT_LogWrite 1 "Failed test $test_id: error expected as result"
				lappend failed $test_id
			} else {
				OT_LogWrite 1 "Passed test $test_id: error expected"
				foreach e $errmsgs {
					OT_LogWrite 1 $e
				}
			}
		}
	}

	set noFailed [llength $failed]
	if { $noFailed > 0 } {
		set strFailed [join $failed ","]
		error "Failed $noFailed (test_id: $strFailed ) out of [llength $data] tests"
	}
}

#
# Test authorise method
#
proc authoriseTest {} {

	set data {}

	# good VISA
	lappend data { 1 "G" "P" "4921095584288227" "0011" "99" "0372" "0001" "test" "" "" "" }
	# good VISA
	lappend data { 2 "G" "R" "4921095584288227" "0011" "99" "0372" "0001" "test" "25" "" "" }

	# good MASTERCARD
	lappend data { 3 "G" "P" "5500000000000004" "0004" "10" "0372" "0001" "test" "" "" "" }
	# good MASTERCARD
	lappend data { 4 "G" "R" "5500000000000004" "0004" "25" "0372" "0001" "test" "01" "" "" }

	# bad card number
	lappend data { 5 "E" "P" "1234567890 1234567890 12" "0112" "25" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 6 "E" "P" "4111111111111111" "9712" "35" "0372" "0001" "test" "" "" "" }
	# bad expiry date
	lappend data { 7 "E" "P" "4111111111111111" "5503" "35" "0372" "0001" "test" "00" "" "" }

	set failed {}

	foreach {
		test_id
		expected
		trans_type
		card_no
		expiry_date
		amount
		currency_code
		dept_id
		ref_text
		issue_no
		off_auth_code
		serat_no
	} [join $data] {

		if [catch {set results [authorise \
				$trans_type $card_no $expiry_date \
				$amount $currency_code $dept_id $ref_text \
				$issue_no $off_auth_code $serat_no ] } errmsg ] {

			# got an error
			global errorInfo
			OT_LogWrite 1 "Failed test $test_id: error not expected"
			OT_LogWrite 1 $errorInfo
			lappend failed $test_id
			continue
		}

		array set response $results
		if {$expected == "G"} {
			# no error message expected
			if { $response(RESP_CODE) == $Flexicom::RESPONSE_OK } {
				OT_LogWrite 1 "Passed test $test_id"
				foreach n [array names response] {
					OT_LogWrite 1 "$n=$response($n)"
				}
			} else {
				OT_LogWrite 1 "Failed test $test_id"
				lappend failed $test_id
			}
		} else {
			# error message expected
			# no error message expected
			if { $response(RESP_CODE) != $Flexicom::RESPONSE_OK } {
				OT_LogWrite 1 "Passed test $test_id"
				foreach n [array names response] {
					OT_LogWrite 1 "$n=$response($n)"
				}
			} else {
				OT_LogWrite 1 "Failed test $test_id"
				lappend failed $test_id
			}
		}
	}

	set noFailed [llength $failed]
	if { $noFailed > 0 } {
		set strFailed [join $failed ","]
		error "Failed $noFailed (test_id: $strFailed ) out of [llength $data] tests"
	}
}


#
# Prints out binary strings
#
proc binToStr {str} {

	set bin "(dec) => "
	set asc "(asc) => "
	for {set i 0} {$i < [string length $str]} {incr i} {
		set c [string index $str $i]
		binary scan $c c v
		append bin "$v "
		if {($v < 32) || ($v > 126)} {
			append asc ".  "
		} else {
			append asc "$c  "
		}
	}
	return "(str) => $str\n$bin\n$asc"
}


}

