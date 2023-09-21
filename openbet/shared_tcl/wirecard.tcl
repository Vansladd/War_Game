# $Id: wirecard.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# Copyright 2004 Orbis Technology Ltd. All rights reserved.
#
# XML Interface for Wirecard payment gateway.
#
# Procedures:
#   ob_wirecard::init
#   ob_wirecard::make_call
#

# Dependencies
#
package require util_db
package require util_log
package require util_validate


# Variables
#
namespace eval ob_wirecard {

	variable INITIALISED
	set INITIALISED 0

	variable WIRECARD_CFG
	variable WIRECARD_DATA
	variable WIRECARD_RESP

	variable WIRECARD_STATUS_RESPONSE_TABLE
}


# One time initialisation.
# Setup the response code table and prepare queries.
#
proc ob_wirecard::init {} {

	variable INITIALISED
	variable WIRECARD_STATUS_RESPONSE_TABLE

	if {$INITIALISED} {
	  	return
	}

	package require tls
	package require http 2.3
	package require tdom

	http::register https 443 ::tls::socket

	array set WIRECARD_STATUS_RESPONSE_TABLE {
		  ACK OK
		    0 OK
		    1 PMT_ERR
		    2 PMT_VOICE_AUTH
		    3 PMT_INVALID_MERCHANT_NUMBER
		    4 PMT_RETAIN_CARD
		    5 PMT_AUTH_DENIED
		    6 PMT_DECL
		   14 PMT_CARD
		   91 PMT_RESP_BANK
		  222 PMT_B2
		  223 PMT_NOCCY
		  240 PMT_CARD_UNKNWN
		  270 PMT_CARD
		20070 PMT_CARD
	}

	set INITIALISED 1

	_prep_qrys

}


# Private procedure to prepare the queries.
#
proc ob_wirecard::_prep_qrys {} {

	ob_db::store_qry ob_wirecard::get_cust_info {
		select
			r.fname || ' ' || r.lname as fullname,
			r.title,
			r.fname,
			r.lname,
			r.email,
			r.telephone,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_postcode,
			c.country_code
		from
			tCustomer c,
			tCustomerReg r
		where
			c.cust_id = ? and
			c.cust_id = r.cust_id
	}
}


#
# Private procedure to validate the data before making the call
# out to Wirecard.
#
proc ob_wirecard::_check {} {

	variable WIRECARD_DATA

	set err_count 0

	# check JobID - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(JobID) 0 32] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate JobID}
		incr err_count
	}

	# check BusinessCaseSignature - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(BusinessCaseSignature) 0 16] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate BusinessCaseSignature}
		incr err_count
	}

	# check FunctionID - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(FunctionID) 0 32] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate FunctionID}
		incr err_count
	}

	# check TransactionID - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(TransactionID) 0 32] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate TransactionID}
		incr err_count
	}

	# check Amount - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(Amount) 0 32] != "OB_OK" ||
			[ob_chk::integer $WIRECARD_DATA(Amount)] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate Amount}
		incr err_count
	}

	# check Currency - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(Currency) 3 3] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate Currency}
		incr err_count
	}

	# check CountryCode - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(CountryCode) 2 2] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate CountryCode}
		incr err_count
	}

	# check Usage - optional
	if {[ob_chk::optional_txt $WIRECARD_DATA(Usage) 0 256] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate Usage}
		incr err_count
	}

	# check PurchaseDesc - optional
	if {[ob_chk::optional_txt $WIRECARD_DATA(PurchaseDesc) 0 256] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate PurchaseDesc}
		incr err_count
	}

	# check CreditCardNumber - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(CreditCardNumber) 12 20] != "OB_OK" ||
			[ob_chk::integer $WIRECARD_DATA(CreditCardNumber)] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate CreditCardNumber}
		incr err_count
	}

	# check ExpirationYear - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(ExpirationYear) 4 4] != "OB_OK" ||
			[ob_chk::integer $WIRECARD_DATA(ExpirationYear)] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate ExpirationYear}
		incr err_count
	}

	# check ExpirationMonth - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(ExpirationMonth) 2 2] != "OB_OK" ||
			[ob_chk::integer $WIRECARD_DATA(ExpirationMonth)] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate ExpirationMonth}
		incr err_count
	}

	# check CardHolderName - mandatory
	if {[ob_chk::mandatory_txt $WIRECARD_DATA(CardHolderName) 0 256] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate CardHolderName}
		incr err_count
	}

	# check CardStartYear - optional
	if {$WIRECARD_DATA(CardStartYear) != ""} {
		if {[ob_chk::optional_txt $WIRECARD_DATA(CardStartYear) 4 4] != "OB_OK" ||
				[ob_chk::integer $WIRECARD_DATA(CardStartYear)] != "OB_OK"} {
			ob_log::write ERROR {WIRECARD:_check: Failed to validate CardStartYear}
			incr err_count
		}
	}

	# check CardStartMonth - optional
	if {$WIRECARD_DATA(CardStartMonth) != ""} {
		if {[ob_chk::optional_txt $WIRECARD_DATA(CardStartMonth) 2 2] != "OB_OK" ||
				[ob_chk::integer $WIRECARD_DATA(CardStartMonth)] != "OB_OK"} {
			ob_log::write ERROR {WIRECARD:_check: Failed to validate CardStartMonth}
			incr err_count
		}
	}

	# check CardIssueNumber - optional
	if {$WIRECARD_DATA(CardIssueNumber) != ""} {
		if {[ob_chk::optional_txt $WIRECARD_DATA(CardIssueNumber) 0 2] != "OB_OK" ||
				[ob_chk::integer $WIRECARD_DATA(CardIssueNumber)] != "OB_OK"} {
			ob_log::write ERROR {WIRECARD:_check: Failed to validate CardIssueNumber}
			incr err_count
		}
	}

	# check IPAddress - optional
	if {[ob_chk::optional_txt $WIRECARD_DATA(IPAddress) 0 256] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate IPAddress}
		incr err_count
	}

	# check CVV2 - optional
	if {[ob_chk::optional_txt $WIRECARD_DATA(CVC2) 0 3] != "OB_OK"} {
		ob_log::write ERROR {WIRECARD:_check: Failed to validate CVV}
		incr err_count
	}


	if {$err_count > 0} {
		return [list ERR $err_count]
	}

	return [list OK]
}


# Private procedure to get a response value from the
# WIRECARD_RESP array
#
proc ob_wirecard::_get_resp_val {name} {

	variable INITIALISED
	variable WIRECARD_RESP

	if {!$INITIALISED} {
		init
	}

	if {[info exists WIRECARD_RESP($name)]} {
		return $WIRECARD_RESP($name)
	}

	ob_log::write INFO {WIRECARD:_get_resp_val:WIRECARD_RESP($name) does not exist}
	return ""
}


# Private procedure to get extra customer information required
# that is not available in the LOGIN cookie.
#
proc ob_wirecard::_get_cust_info {cust_id} {

	variable WIRECARD_DATA

	if [catch {set rs [ob_db::exec_qry ob_wirecard::get_cust_info $cust_id]} msg] {
		ob_log::write ERROR {WIRECARD:Problem retrieving customer account information for WireCard: $msg}
		ob_db::rs_close $rs
		return [list 0 $msg]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		return [list 0 PMT_CUST]
	}

	set WIRECARD_DATA(CardHolderName) [db_get_col $rs 0 fullname]
	set WIRECARD_DATA(CountryCode)    [db_get_col $rs 0 country_code]

	ob_db::rs_close $rs

	return [list 1]
}


# Make the request to Wirecard for a payment.
#
#   ARRAY   - the PMT array from payment_gateway.tcl
#
#   returns - response code from Wirecard.
#
proc ob_wirecard::make_call {ARRAY} {

	upvar $ARRAY PMT

	variable INITIALISED
	variable WIRECARD_STATUS_RESPONSE_TABLE
	variable WIRECARD_CFG

	if {!$INITIALISED} {
		init
	}

	# payment gateway values
	set WIRECARD_CFG(url)      $PMT(host)
	set WIRECARD_CFG(timeout)  $PMT(resp_timeout)
	set WIRECARD_CFG(client)   $PMT(client)
	set WIRECARD_CFG(password) $PMT(password)
	set WIRECARD_CFG(bcsig)    $PMT(mid)

	foreach {status retcode} [_transaction \
		$PMT(cust_id) \
		$PMT(apacs_ref) \
		$PMT(pay_sort) \
		$PMT(amount) \
		$PMT(ccy_code) \
		$PMT(card_no) \
		$PMT(expiry) \
		$PMT(start) \
		$PMT(issue_no) \
		$PMT(cvv2) \
		$PMT(gw_auth_code) \
		$WIRECARD_CFG(bcsig)] {}

	if {$status != "OK"} {
		ob_log::write DEBUG {WIRECARD:make_call: Transaction failed: $retcode}

		# wirecard helpfully seem to put leading zero's in front of some error codes
		set retcode [string trimleft $retcode 0]
		if {[info exists WIRECARD_STATUS_RESPONSE_TABLE($retcode)]} {
			return $WIRECARD_STATUS_RESPONSE_TABLE($retcode)
		} else {
			return PMT_ERR
		}
	}

	set PMT(status)        [expr {$status == "OK" ? "Y" : "N"}]
	set PMT(auth_time)     [clock format [clock seconds] -format "%H:%M:%S"]
	set PMT(gw_ret_code)   $retcode
	set PMT(gw_auth_code)  [_get_resp_val AuthorizationCode]
	set PMT(gw_uid)        [_get_resp_val GuWID]

	# TimeStamp is in the format: YYYY-MM-DD HH:MI:SS
	set timestamp [_get_resp_val TimeStamp]
	set timeIndex [expr {[string first " " $timestamp] + 1}]
	set PMT(time) [string range $timestamp $timeIndex end]

	set PMT(gw_ret_msg) [join [list \
			$PMT(gw_ret_code) \
			$PMT(gw_auth_code) \
			$PMT(time) \
			$PMT(gw_uid)] :]

	set gw_ret_code PMT_ERR

	if {[info exists WIRECARD_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))]} {
		set gw_ret_code $WIRECARD_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))
	}

	if {$PMT(gw_ret_code) == "ACK"} {
		set PMT(gw_ret_code) 0
	}

	return $gw_ret_code

}


#
# Private procedure to handle the transaction with Wirecard
#
proc ob_wirecard::_transaction {
	cust_id
	apacs_ref
	pay_sort
	amount
	ccy_code
	card_no
	expiry
	start
	issue_no
	cvv2
	{gw_auth_code ""}
	bcsig
} {

	variable INITIALISED
	variable WIRECARD_DATA

	if {!$INITIALISED} {
		init
	}

	catch {unset WIRECARD_DATA}

	# get cust info not in PMT array
	set result [_get_cust_info $cust_id]
	if {[lindex $result 0] == 0} {
		return PMT_ERR
	}

	if {$expiry != ""} {
		set split_expiry [split $expiry "/"]
		set expiry_month [lindex $split_expiry 0]
		set expiry_year  20[lindex $split_expiry 1]
	} else {
		set expiry_month ""
		set expiry_year ""
	}

	if {$start != ""} {
		set split_start [split $start "/"]
		set start_month [lindex $split_start 0]
		set start_year  20[lindex $split_start 1]
	} else {
		set start_month ""
		set start_year ""
	}

	# Amount for wirecard has no decimal point
	# But first make sure that the amount is correctly formatted, see call#19896
	set formatted_amount [format "%.2f" $amount]
	set wc_amount [string map {"." ""} $formatted_amount]

	set WIRECARD_DATA(pay_sort)              $pay_sort

	# Mandatory WireCard parameters
	set WIRECARD_DATA(JobID)                 $apacs_ref
	set WIRECARD_DATA(BusinessCaseSignature) $bcsig
	set WIRECARD_DATA(FunctionID)            $apacs_ref
	set WIRECARD_DATA(Amount)                $wc_amount
	set WIRECARD_DATA(Currency)              $ccy_code
	set WIRECARD_DATA(CreditCardNumber)      $card_no
	set WIRECARD_DATA(ExpirationYear)        $expiry_year
	set WIRECARD_DATA(ExpirationMonth)       $expiry_month

	# Optional WireCard parameters
	set WIRECARD_DATA(TransactionID)         $apacs_ref
	set WIRECARD_DATA(Usage)                 ""
	set WIRECARD_DATA(PurchaseDesc)          ""
	set WIRECARD_DATA(CardStartYear)         $start_year
	set WIRECARD_DATA(CardStartMonth)        $start_month
	set WIRECARD_DATA(CardIssueNumber)       $issue_no
	set WIRECARD_DATA(CVC2)                  $cvv2
	set WIRECARD_DATA(IPAddress)             [reqGetEnv REMOTE_ADDR]

	# if reqGetEnv doesn't return an IP then don't bother sending
	# the parameter to wirecard as it'll just refuse the request.
	if {$WIRECARD_DATA(IPAddress) == "-"} {
		unset WIRECARD_DATA(IPAddress)
	}

	# log input parameters to WireCard
	foreach {name value} [array get WIRECARD_DATA] {
		ob_log::write DEBUG {WIRECARD::WIRECARD_DATA($name) = $WIRECARD_DATA($name)}
	}

	# validate input parameters
	foreach {status ret} [_check] {
		if {$status == "ERR"} {
			ob_log::write INFO {WIRECARD::_transaction _check failed: $ret}
			return [list ERR $ret]
		}
	}

	# pack the message
	foreach {status request} [_msg_pack] {
		if {$status == "ERR"} {
			ob_log::write INFO {WIRECARD::_transaction _msg_pack failed: $request}
			return [list ERR $request]
		}
	}

	# send the message and close the socket
	foreach {status response} [_msg_send $request] {
		if {$status == "ERR"} {
			ob_log::write INFO {WIRECARD::_transaction _msg_send failed: $response}
			return [list ERR $response]
		}
	}

	# unpack the message
	foreach {status ret} [_msg_unpack $response] {
		if {$status == "NOK"} {
			ob_log::write INFO {WIRECARD::_transaction _msg_unpack failed: $ret}
			return [list ERR $ret]
		}
	}

	ob_log::write INFO {WIRECARD::_transaction -- finished successfully}

	return [list OK $status]
}


# Private procedure to build up the XML to be sent to Wirecard
#
proc ob_wirecard::_msg_pack {} {

	variable WIRECARD_DATA

	# <W REQUEST>
	#		<W JOB>
	#			<JobID/>
	#			<BusinessCaseSignature/>
	#			<FNC CC TRANSACTION>
	#				<FunctionID/>
	#				<CC TRANSACTION>
	#					<TransactionID/>
	#					<Amount/>
	#					<Currency/>
	#					<CountryCode/>
	#					?<Usage/>
	#					?<PurchaseDesc/>
	#					<CREDIT CARD DATA>
	#						<CreditCardNumber/>
	#						<ExpirationYear/>
	#						<ExpirationMonth/>
	#						<CardHolderName/>
	#                       <CVC2/>
	#						?<CardStartYear/>
	#						?<CardStartMonth/>
	#						?<IssueNumber/>
	#					</CREDIT CARD DATA>
	#				</CC TRANSACTION>
	#			</FNC TRANSACTION>
	#		</W JOB>
	#	</W REQUEST>

	catch {unset wc_msg}
	dom setResultEncoding "utf-8"

	dom createDocument "WIRECARD_BXML" wc_msg

	$wc_msg documentElement req

	$req setAttributeNS "" "xmlns:xsi" "http://www.w3.org/1999/XMLSchema-instance"
	$req setAttributeNS "http://www.w3.org/1999/XMLSchema-instance" "xsi:noNamespaceLocation" "wirecard.xsd"

	# top level request element
	$wc_msg createElement "W_REQUEST" w_request
	$req appendChild $w_request

	# W_JOB element
	$wc_msg createElement "W_JOB" w_job
	$w_request appendChild $w_job

	foreach w_job_item {
		JobID
		BusinessCaseSignature
	} {
		if {$WIRECARD_DATA($w_job_item) != ""} {
			$wc_msg createElement $w_job_item elem
			$w_job appendChild $elem
			$wc_msg createTextNode $WIRECARD_DATA($w_job_item) txt
			$elem appendChild $txt
		} else {
			# mandatory elements, if we don't have data for these we have to give up.
			ob_log::write ERROR {WIRECARD:_msg_pack: Missing mandatory data for $w_job_item}
			$wc_msg delete
			return [list ERR PMT_RESP]
		}
	}

	# Deposit = FNC_CC_TRANSACTION element
	# Withdrawal = FNC_CC_REFUND element
	if {$WIRECARD_DATA(pay_sort) == "D"} {
		$wc_msg createElement "FNC_CC_TRANSACTION" fnc_cc
	} elseif {$WIRECARD_DATA(pay_sort) == "W"} {
		$wc_msg createElement "FNC_CC_REFUND" fnc_cc
	} else {
		ob_log::write ERROR {WIRECARD: Not a deposit or withdrawal!}
		$wc_msg delete
		return [list ERR PMT_RESP]
	}
	$w_job appendChild $fnc_cc

	# FunctionID
	if {$WIRECARD_DATA(FunctionID) == ""} {
		# mandatory element, give up if we don't have this.
		ob_log::write ERROR {WIRECARD:_msg_pack: Missing mandatory data for FunctionID}
		$wc_msg delete
		return [list ERR PMT_RESP]
	}
	$wc_msg createElement "FunctionID" elem
	$fnc_cc appendChild $elem
	$wc_msg createTextNode $WIRECARD_DATA(FunctionID) txt
	$elem appendChild $txt

	# CC_TRANSACTION element
	$wc_msg createElement "CC_TRANSACTION" cc_transaction
	$fnc_cc appendChild $cc_transaction

	foreach cc_item {
		TransactionID
		Amount
		Currency
		CountryCode
	} {
		if {$WIRECARD_DATA($cc_item) != ""} {
			$wc_msg createElement $cc_item elem
			$cc_transaction appendChild $elem
			$wc_msg createTextNode $WIRECARD_DATA($cc_item) txt
			$elem appendChild $txt
		} else {
			# mandatory elements, give up if we don't have these
			ob_log::write ERROR {WIRECARD:_msg_pack: Missing mandatory data for $cc_item}
			$wc_msg delete
			return [list ERR PMT_RESP]
		}
	}

	# optional items
	foreach cc_item {
		Usage
		PurchaseDesc
	} {
		if {$WIRECARD_DATA($cc_item) != ""} {
			$wc_msg createElement $cc_item elem
			$cc_transaction appendChild $elem
			$wc_msg createTextNode $WIRECARD_DATA($cc_item) txt
			$elem appendChild $txt
		}
	}

	# CREDIT_CARD_DATA element
	$wc_msg createElement "CREDIT_CARD_DATA" credit_card_data
	$cc_transaction appendChild $credit_card_data

	foreach credit_card_data_item {
		CreditCardNumber
		ExpirationYear
		ExpirationMonth
		CardHolderName
	} {
		if {$WIRECARD_DATA($credit_card_data_item) != ""} {
			$wc_msg createElement $credit_card_data_item elem
			$credit_card_data appendChild $elem
			$wc_msg createTextNode $WIRECARD_DATA($credit_card_data_item) txt
			$elem appendChild $txt
		} else {
			# mandatory elements, give up if we don't have them
			ob_log::write ERROR {WIRECARD:_msg_pack: Missing mandatory data for $credit_card_data_item}
			$wc_msg delete
			return [list ERR PMT_RESP]
		}
	}

	# optional items
	foreach credit_card_data_item {
		CardStartYear
		CardStartMonth
		CardIssueNumber
		CVC2
	} {
		if {($WIRECARD_DATA($credit_card_data_item) != "") || \
		     $credit_card_data_item == "CVC2"} {
			$wc_msg createElement $credit_card_data_item elem
			$credit_card_data appendChild $elem
			$wc_msg createTextNode $WIRECARD_DATA($credit_card_data_item) txt
			$elem appendChild $txt
		}
	}

	# CONTACT_DATA element
	$wc_msg createElement "CONTACT_DATA" contact_data
	$cc_transaction appendChild $contact_data

	# IPAddress
	if {$WIRECARD_DATA(IPAddress) != ""} {
		$wc_msg createElement IPAddress elem
		$contact_data appendChild $elem
		$wc_msg createTextNode $WIRECARD_DATA(IPAddress) txt
		$elem appendChild $txt
	}

	set xml_msg [$req asXML]

	$wc_msg delete

	return [list OK "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n$xml_msg"]
}


# Private procedure to process the XML response from Wirecard
#
proc ob_wirecard::_msg_unpack {xml} {

	variable WIRECARD_RESP

	if {[catch {
		dom parse $xml doc
		$doc documentElement response
	} msg]} {
		ob_log::write ERROR "WIRECARD:Unrecognized xml format. Message is:\n $xml"
		return [list NOK 1]
	}

	foreach element [split [$response asXML] "\n"] {
		lappend xml_msg [string trim $element]
	}

	set WIRECARD_RESP(response) [join $xml_msg]

	# mandatory elements
	if {[catch {
		foreach item {
			JobID
			FunctionID
			TransactionID
			GuWID
			FunctionResult
			TimeStamp
		} {
			set WIRECARD_RESP($item) [[[$response getElementsByTagName $item]\
				firstChild] nodeValue]
		}
	} msg]} {
		# entire message is useless if we're missing some mandatory elements
		ob_log::write ERROR "WIRECARD:_msg_unpack:Bad XML format. Message is\n[$response asXML]"

		$doc delete
		return [list NOK 1]
	}

	# optional elements

	foreach item {
		AuthorizationCode
	} {
		if {[catch {
			set WIRECARD_RESP($item) [[[$response getElementsByTagName $item]\
				firstChild] nodeValue]
		}]} {
			set WIRECARD_RESP($item) ""
		}
	}

	# is there an error?
	set errorList [$response getElementsByTagName "ERROR"]

	if {[llength $errorList] > 0} {
		# mandatory error elements
		if {[catch {
			foreach item {
				Type
				Number
			} {
				set WIRECARD_RESP($item) [[[$response getElementsByTagName $item]\
					firstChild] nodeValue]
			}
		} msg]} {
			# entire message is useless if we're missing some mandatory elements
			ob_log::write ERROR "WIRECARD:_msg_unpack:Bad XML format. Message is\n[$response asXML]"
		}

		# optional error elements
		foreach item {
			Advice
			Message
		} {
			if {[catch {
				set WIRECARD_RESP($item) [[[$response getElementsByTagName $item]\
					firstChild] nodeValue]
			}]} {
				set WIRECARD_RESP($item) ""
			}
		}

		ob_log::write ERROR {WIRECARD:$WIRECARD_RESP(Type) $WIRECARD_RESP(Number)}
		ob_log::write ERROR {WIRECARD:$WIRECARD_RESP(Message)}
		ob_log::write ERROR {WIRECARD:$WIRECARD_RESP(Advice)}

		$doc delete

		return [list $WIRECARD_RESP(FunctionResult) $WIRECARD_RESP(Number)]
	}

	$doc delete

	foreach { n v } [array get WIRECARD_RESP] {
		ob_log::write DEBUG {WIRECARD:_msg_unpack: $n = $v}
	}

	# FunctionResult should be either 'ACK' meaning good transaction or 'NOK'
	# meaning something went wrong.
	return [list $WIRECARD_RESP(FunctionResult)]
}


# Private procedure to build up a replacement for the whole request
# string with the credit card number obscured.
#
proc ob_wirecard::_blank_ccn_request {request} {

	set startIndex [string first "<CreditCardNumber>" $request]
	set endIndex   [string first "</CreditCardNumber>" $request]

	# need to offset startIndex by position that card number actually
	# starts at (+18) and then move along another 6 places so that we
	# do get the card_bin
	set startIndex [expr {$startIndex + 24}]

	# actual end of credit card number
	set endIndex [expr {$endIndex - 1}]

	set blankLength [expr {$endIndex - $startIndex}]
	for {set i 0} {$i < $blankLength} {incr i} {
		append blankString "X"
	}

	return [string replace $request $startIndex $endIndex $blankString]

}

# Private procedure to send (and receive) the XML over HTTPS
# to Wirecard.
#
proc ob_wirecard::_msg_send {request} {

	variable WIRECARD_CFG
	variable WIRECARD_RESP

	catch {unset WIRECARD_RESP}

	# need to obscure the credit card number from the log output
	set logRequest [_blank_ccn_request $request]
	ob_log::write DEBUG "WIRECARD:_msg_send:REQUEST:\n$logRequest -- attempting send $WIRECARD_CFG(url)"

	set headerList [list "Authorization"]
	lappend headerList "Basic [bintob64 $WIRECARD_CFG(client):$WIRECARD_CFG(password)]"

	if [catch {set token [http::geturl $WIRECARD_CFG(url)\
		-query $request\
		-timeout $WIRECARD_CFG(timeout)\
		-headers $headerList\
		-type "text/xml"]} msg] {
		return [list ERR $msg]
	}

	set status [http::status $token]

	ob_log::write INFO {WIRECARD:_msg_send: status=$status}

	if {$status != "ok"} {
		if {$status == "timeout"} {
			ob_log::write ERROR {Timed out after $WIRECARD_CFG(timeout) ms}
		}
		return [list ERR PMT_RESP]
	}

	upvar #0 $token state

	ob_log::write DEBUG "WIRECARD:_msg_send:RESPONSE:\n$state(body)"

	return [list OK $state(body)]
}
