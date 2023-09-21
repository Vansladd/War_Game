# $Id: bibit_xml.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2004-2005 Orbis Technology Ltd. All Rights Reserved.
#
# This is a direct implementation of BIBIT rather than the redirect version
# We send an xml request to BIBIT and then parse an XML response
#
# This file started off the same as bibit.tcl, then changes were made
# to make sure we keep the redirect method (used by enets) and the direct
# method seperate
#
# NOTE: THE DIRECT VERSION ALLOWS CREDIT CARD WTD's BUT THE REDIRECT VERSION
# DOES NOT
#
# NOTE: just like dcash and dcash_xml this has the same namespace as
# bibit.tcl so only one can be sourced
#
# based on http://www.bibit.com/pdf/implman253.pdf
#
#
# Configuration:
#
#   FUNC_BIBIT_XML         Activate bibit.
#   BIBIT_PAY_METH_MASKS   The payment method masks.
#   BIBIT_DTD_URL          The URL at which to find the DTD.
#   BIBIT_XML_OPTIONS      Options for the formatting of the Xml:
#                          add_order_content.
#                          add_shopper.
#                          add_shipping_address.
#
# Synopsis:
#
#   none
#
# Procedures:
#
#   bibit::init                    One time initialisation.
#   bibit::authorize               Authorize generic CC payment.
#   bibit::prepare                 Prepare an eNets query.

package require tdom
package require http 2.3
package require tls
package require base64

namespace eval bibit {

	#
	# The exponent (the number of decimal places) in which bibit
	# represent the currency:
	#
	variable  EXPONENT
	array set EXPONENT [list \
		SGD 2                \
		EUR 2                \
		GBP 2                \
		USD 2                \
	]

	#
	# Maps card schemes on to payment-method masks.  If the mask isn't supported
	# the payment is rejected.
	#
	variable  MASKS
	array set MASKS [list \
		VD   VISA-SSL     \
		VC   VISA-SSL     \
		MC   ECMC-SSL     \
		SOLO SOLO_GB-SSL   \
		SWCH SWITCH-SSL   \
		ENET ENETS-SSL    \
		ELTN VISA-SSL \
	]

	variable  CFG
	array set CFG [list                                            \
		BIBIT          [OT_CfgGetTrue FUNC_BIBIT_XML]              \
		PAY_METH_MASKS [OT_CfgGet     BIBIT_PAY_METH_MASKS [list VISA-SSL ECMC-SSL SOLO_GB-SSL SWITCH-SSL ENETS-SSL]] \
		DTD_URL        [OT_CfgGet     BIBIT_DTD_URL            ""] \
		XML_OPTIONS    [OT_CfgGet     BIBIT_XML_OPTIONS    "add_order_content    0 add_shipping_address 0 add_shopper 0 add_card_address 0 add_session 1"]
	]

	variable  XML_OPTIONS
	array set XML_OPTIONS $CFG(XML_OPTIONS)

	variable AUTH_CODE_MAP

	array set AUTH_CODE_MAP {
		{AUTHORISED} OK
		{SENT_FOR_AUTHORISATION} PMT_REFER
		{WITHDRAWAL} OK
		{REFUSED} PMT_DECL
		{CAPTURED} OK
		{ERROR} PMT_ERR
		{CANCELLED} PMT_DECL
		{CHARGED_BACK} PMT_DECL
		{SETTLED} OK
		{SENT_FOR_REFUND} OK
		{REFUNDED} OK
		{EXPIRED} PMT_ERR
		{INFORMATION_REQUESTED} PMT_REFER
		{INFORMATION_SUPPLIED} OK
		{CHARGEBACK_REVERSED} PMT_ERR

	}

}

#
# Initialise the namespace, done at end of file.
#
#   returns a list indicating success or failure to init
#
proc bibit::init {} {

	variable CFG

	if {!$CFG(BIBIT)} {
		return [list 0 BIBIT_ERR_DISABLED Disabled]
	}

	variable CFG
	variable XML_OPTIONS

	http::register https 443 ::tls::socket

	set ::SHARED_SQL(bibit::upd_pmt_status) {

		update tPmt set
			status = ?
		where pmt_id = ?
	}

	set ::SHARED_SQL(bibit::get_cc_pmt) {

		select
			p.pmt_id,
			a.ccy_code,
			p.amount
		from
			tPmt  p,
			tAcct a
		where p.acct_id = a.acct_id
		  and p.pmt_id  = ?

	}

	return [list 1 BIBIT_INIT_OK]

}

proc bibit::log {level msg} {

	OT_LogWrite $level "BIBIT: $msg"
}

proc bibit::set_up {
	 url
	 username
	 password
	 timeout
	 dtd_url
} {

	variable BIBIT_CFG

	catch { unset BIBIT_CFG }

	log 15 "set_up:url      = $url"
	log 15 "set_up:username = $username"
	log 15 "set_up:password = $password"
	log 15 "set_up:timeout  = $timeout"
	log 15 "set_up:dtd_url  = $dtd_url"

	set BIBIT_CFG(url)          $url
	set BIBIT_CFG(timeout)      $timeout
	set BIBIT_CFG(client)       $username
	set BIBIT_CFG(password)     $password
	set BIBIT_CFG(dtd_url)      $dtd_url


	set err_count 0
	foreach item {
		url
		username
		password
		timeout
	} {
		if {[set $item] == ""} {
			err_add "$item is incomplete.... cannot proceed."
			incr err_count
		}
	}

	if {$err_count} {
		return [list ERR $err_count]
	}

	return [list OK]
}

proc bibit::_lookup_auth {auth_code} {
	variable AUTH_CODE_MAP

	if {[info exists AUTH_CODE_MAP($auth_code)]} {
		return $AUTH_CODE_MAP($auth_code)
	} else {
		return PMT_ERR
	}
}

proc bibit::authorize array {

	variable CFG
	variable MASKS

	upvar 1 $array pmt

	if { ![info exists MASKS($pmt(card_scheme))] } {

		bibit::log ERROR {Unrecognized card scheme: $pmt(card_scheme)}
		return BIBIT_ERR_NO_MTHD

	}

	set pmt(mask) $MASKS($pmt(card_scheme))

	if { [lsearch $CFG(PAY_METH_MASKS) $pmt(mask)] == -1 } {

		bibit::log ERROR {Unsupported card scheme: $pmt(card_scheme)}
		return BIBIT_ERR_NO_MTHD

	}

	#
	# Check the amount isn't going to cause a problem when we adjust by the
	# exponent.
	#
	foreach { ok xl msg } [_check_amount $pmt(amount) $pmt(ccy_code)] { break }

	if { !$ok } { return $xl }

	#
	# set up cust array
	#
	foreach {
		c             p
	} {
		cust_id       cust_id
		fname         fname
		lname         lname
		addr_city     city
		addr_postcode postcode
		addr_country  cntry
		email         email
		telephone     telephone
		acct_id       acct_id
		ccy_code      ccy_code
	} {
		set cust($c) $pmt($p)
	}

	set cust(addr_street) [list]
	foreach p {
		addr_1
		addr_2
		addr_3
		addr_4
	} {
		if {$pmt($p) != ""} {
			lappend cust(addr_street) $pmt($p)
		}
	}
	set cust(addr_street) [join $cust(addr_street) ", "]
	set cust(country_code) [_lookup_country $cust(addr_country)]

	#
	# Make sure the status is set to 'U'
	#
	if { [catch {
		tb_db::tb_exec_qry bibit::upd_pmt_status U $pmt(pmt_id)
	} msg] } {
		bibit::log ERROR "bibit::upd_pmt_status query failed: $msg"
		return PMT_ERR
	}

	set pmt(status) U

	#
	# generate the xml
	#
	foreach { ok xl msg } [_get_xml_req pmt cust $pmt(amount)] {break}

	if { !$ok } {
		bibit::log ERROR "bibit: failed to generate XML: $msg"
		return $xl
	}

	set xml $msg

	bibit::log DEBUG "xml=$xml"

	bibit::log DEBUG "header = $pmt(client):$pmt(password)"
	bibit::log DEBUG "sending url = $pmt(host)"

	set auth [base64::encode "$pmt(client):$pmt(password)"]

	if {[catch {
		set token [http::geturl \
			$pmt(host) \
			-headers [list Authorization "Basic $auth"] \
			-query   $xml \
			-timeout $pmt(conn_timeout) \
			-type    text/xml \
		]
	} msg]} {
		bibit::log ERROR "http failure: $msg"
		bibit::log WARNING "xml=$xml"
		return PMT_RESP
	}

	upvar #0 $token state

	foreach n {data error status code ncode} {
		set http($n) [http::$n $token]
	}

	foreach n {http meta} {
		set http($n) $state($n)
	}

	http::cleanup $token

	#
	# if the error is in the error range, then we must fail the request
	#
	if {$http(ncode) >= 400 || $http(status) == "error"} {
		bibit::log ERROR \
			"http error: ncode = $http(ncode), status = $http(status)"
		return PMT_RESP
	}

	foreach { ok xl msg } [_parse_xml_resp $http(data) RESP] {break}

	if {!$ok} {
		bibit::log ERROR "failed to parse xml response($xl): $msg"
		return PMT_RESP
	}



	#
	# deal with an error response
	#
	if {[info exists RESP(code)]} {

		switch $RESP(code) {

			1 -
			2 -
			4 -
			6 -
			7 {
				set err PMT_ERR
				bibit::log WARNING "xml=$xml"
			}
			5 {
				# special case of the missing post code,
				# there maybe more of these, don't be scared to add them
				switch -glob $RESP(msg) {

					"*Postal code*" {
						set err BIBIT_ERR_INVALID_POST_CODE
						bibit::log WARNING "xml=$xml"
					}

				}

				set err BIBIT_ERR_INVALID_REQUEST
				bibit::log WARNING "xml=$xml"

			}
			8 {
				set err BIBIT_ERR_TEMP_UNAVAIL
				bibit::log WARNING "xml=$xml"
			}
			9 {
				if {$pmt(pay_sort) == "W"} {
					set pmt(leave_pending) 1
				}
				set err OK
			}
			default {
				bibit::log ERROR "error code $code unknown"
				set err PMT_ERR
				bibit::log WARNING "xml=$xml"
			}

		}

		if {![info exists RESP(msg)]} {
			set RESP(msg) ""
		}

		_log_resp pmt $RESP(code) $err $RESP(msg)

		return $err

	}

	bibit::log DEBUG "resp = $RESP(auth_code) "

	set resp [_lookup_auth $RESP(auth_code)]

	if {$resp != "OK"} {
		bibit::log WARNING "xml=$xml"
	}

	_log_resp pmt "" $RESP(auth_code) $resp

	return $resp

}

proc bibit::_log_resp {array return_code resp_code ret_msg} {
	upvar 1 $array pmt

	set pmt(gw_ret_code) $return_code
	set pmt(gw_auth_code) $resp_code
	set pmt(gw_ret_msg) $ret_msg

}


##
#
##
proc bibit::settle {order_code} {

	variable BIBIT_DATA

	set BIBIT_DATA(order_code) $order_code

	# Pack the message
	foreach { ok xl xml } [_settle_msg_pack] {break}
	if { !$ok } {
		log 20 {bibit: failed to generate XML: $xml}
		return [list ERR $xl]
	}

	# Send the message (and close the socket?)
	foreach {status response} [_msg_send $xml] {
		log 20 "status=$status"
		if {$status == "ERR"} {
			log 5 {bibit: Dodgey response: $response}
			return [list ERR $response]
		}
	}

	# Unpack the message
	foreach {status ret} [_msg_unpack $response] {
		if {$status == "ERR"} {
			return [list ERR $ret]
		}
	}

	log 20 "returning OK response to settler"
	return [list OK]
}
proc bibit::_settle_msg_pack {} {

	variable BIBIT_DATA
	variable BIBIT_CFG

	# The following request structure is required
	# to settle a transaction.
	#
	# REQUEST
	#   |--paymentService
	#   | |--merchantCode
	#   | |--version
	#   | |inquiry
	#   | |--orderInquiry
	#     | |--orderCode

	dom setResultEncoding "UTF-8"

	if {[catch {
		set declaration {<?xml version="1.0"?>}
		set doctype     [subst {<!DOCTYPE paymentService PUBLIC\
			"-//Bibit/DTD Bibit PaymentService v1//EN" "$BIBIT_CFG(dtd_url)">}]

		set doc            [dom createDocument paymentService]

		set paymentService [$doc documentElement]

		$paymentService setAttribute version 1.4 merchantCode [_safe $BIBIT_CFG(client)]


		# Request/paymentService/Inquiry
		set inquiry  [$doc createElement  "inquiry"]
		set orderInquiry [$doc createElement "orderInquiry"]
		$orderInquiry    setAttribute orderCode $BIBIT_DATA(order_code)
		$inquiry appendChild $orderInquiry
		$paymentService appendChild $inquiry

		set xml    $declaration\n
		append xml $doctype\n
		append xml [$doc asXML]

		$doc delete
	} msg]} {
		catch {$doc delete}
		return [list 0 $msg "msg; $::errorInfo"]
	}

	return [list 1 BIBIT_GET_XML_OK $xml]
}

proc bibit::_msg_send {request} {
	variable BIBIT_CFG
	variable BIBIT_RESP

        catch { unset BIBIT_RESP }

	#! UTF-8 encoding - the nuclear option
        #
        # strips any non-ASCII characters - this is unfortunately the only option
        # available to us as we cannot work out what character encoding the data is
        # in (eg, if the request is from the portal, it may be in the user's language
        # encoding - but if it came from OXi XML, it may already be in UTF-8)
        if {[regexp {[^\n\040-\176]} $request]} {
                set count [regsub -all {[^\n\040-\176]} $request {} request]
                OT_LogWrite 5 "Warning: stripped $count non-ASCII character(s) from request"
        }

		log 10 "_msg_send: REQUEST: attempting send"
		log 10 "_msg_send: before enc $BIBIT_CFG(client):$BIBIT_CFG(password)"
		log 10 "_msg_send: sendind to url: $BIBIT_CFG(url)"

		set auth [base64::encode "$BIBIT_CFG(client):$BIBIT_CFG(password)"]
		log 10 "_msg_send: auth=$auth"
		if {[catch {
			set token [http::geturl \
				$BIBIT_CFG(url) \
				-headers [list Authorization "Basic $auth"] \
				-query   $request \
				-timeout $BIBIT_CFG(timeout) \
				-type    text/xml \
			]
		} msg]} {
			return PMT_RESP
		}

		upvar #0 $token state

		foreach n {data error status code ncode} {
			log 1 "http($n) [http::$n $token]"
			set http($n) [http::$n $token]
		}

		set status [http::status $token]

		log 10 "_msg_send: status=$status"

		if {$status == "timeout"} {
			err_add "Timed out after $BIBIT_CFG(timeout) ms"
			return [list ERR PMT_RESP]
		}


		log 10 "_msg_send: RESPONSE:OK"
		return [list OK $state(body)]

}


proc bibit::_msg_unpack {xml} {

	#reply
	#reply/orderStatus
	#reply/orderStatus/payment
	#reply/orderStatus/payment/paymentMethod
	#reply/orderStatus/payment/amount
	#reply/orderStatus/payment/lastEvent
	# (refused) reply/orderStatus/payment/ISO8583ReturnCode
	#reply/orderStatus/date

	variable BIBIT_RESP

	if {[catch {
		set doc      [dom parse $xml]
		set Response [$doc documentElement]
	} msg]} {
		err_add "Unrecognized xml format.  Message is:\n $xml "
		return [list ERR PMT_RESP]
	}

	foreach element [split [$Response asXML] "\n"] {
		lappend xml_msg [string trim $element]
	}

	set BIBIT_RESP(Response) [join $xml_msg]

	# really only concerned with the status so need the
	set orderStatus [$Response selectNodes reply/orderStatus]

	if {[llength $orderStatus] > 0} {

		if {[info exists [$Response selectNodes reply/orderStatus/error]]} {
			set error_msg [$Response selectNodes reply/orderStatus/error]
			err_add "_msg_unpack - [$error text]"
			return [list ERR PMT_RESP]
		}

		set payment     [$Response selectNodes reply/orderStatus/payment]
		set lastEvent   [$Response selectNodes reply/orderStatus/payment/lastEvent]

		set BIBIT_RESP(lastEvent) [$lastEvent text]

		if {[catch {
			set reason [$Response selectNodes reply/orderStatus/payment/ISO8583ReturnCode]
			set BIBIT_RESP(reason) [$reason text]
		}]} {
			set BIBIT_RESP(reason) ""
		}

		switch -- $BIBIT_RESP(lastEvent) {
			"SETTLED" {set BIBIT_RESP(status) "Y"}
			"REFUNDED"\
                      {set BIBIT_RESP(status) "Y"}
			"REFUSED" {set BIBIT_RESP(status) "N"}
			default   {set BIBIT_RESP(status) "-"
					   set BIBIT_RESP(reason) "Response from Bibit is $BIBIT_RESP(lastEvent)"}
		}

		log 15 "_msg_unpack:status             = $BIBIT_RESP(status)"
		log 15 "_msg_unpack:reason             = $BIBIT_RESP(reason)"

		$doc delete
		return [list OK]

	} else {

		set error [$Response selectNodes reply/orderStatus/error]
		return [list ERR [$error text]]
	}
}

proc bibit::get_resp_val {name} {

	variable BIBIT_RESP

	if {[info exists BIBIT_RESP($name)]} {
		return $BIBIT_RESP($name)
	}

	log 15 "BIBIT_RESP($name) does not exist"
	return ""
}










#
#
#   amount    The amount.
#   ccy_code  The currency code.
#
proc bibit::_check_amount { amount ccy_code } {

	variable EXPONENT

	#
	# If the amount is too big, this will generate an integer overflow error:
	#
	if { [catch {
		expr { int ($amount * pow (10, $EXPONENT($ccy_code))) }
	} err] } {

		bibit::log ERROR "bibit::_check_amount ($amount, $ccy_code) failed: $err"

		return [list \
			0 \
			BIBIT_ERR_AMOUNT_BAD \
			"The amount is too large, unable to represent it." \
		]

	}

	return [list 1 BIBIT_AMOUNT_OK]

}


#
# Generates the XML request to be send to bibit to get the URL.
#
#    PMT_ARR    An array containing information about the payemnt.
#    CUST_ARR   An array containing information about the customer.
#    returns    A normal three element list, but the third element is the XML.
#
proc bibit::_get_xml_req { PMT_ARR CUST_ARR payment_amt } {

	variable CFG
	variable EXPONENT
	variable XML_OPTIONS

	upvar 1 $PMT_ARR  PMT
	upvar 1 $CUST_ARR CUST

	set exponent $EXPONENT($CUST(ccy_code))

	set exponent_amount [expr {int($payment_amt * pow(10, $exponent))}]

	# the amount in the request is not allowed to have decimal points, so we shift it left
	array set BIBIT [list \
		amount   $exponent_amount \
		exponent $exponent \
	]

	if { [info exists PMT(client)] } {
		set username $PMT(client)
	} else {
		set username $CFG(USERNAME)
	}

	if {[catch {

		# see the bibit implementation manual for more information of the format of the xml request

		set declaration {<?xml version="1.0"?>}
		set doctype     [subst {<!DOCTYPE paymentService PUBLIC\
			"-//Bibit/DTD Bibit PaymentService v1//EN" "$CFG(DTD_URL)">}]

		set doc            [dom createDocument paymentService]

		set paymentService [$doc documentElement]

		$paymentService    setAttribute version 1.4 merchantCode [_safe $username]

		set submit         [$doc createElement submit]

		$paymentService    appendChild $submit

		set order          [$doc createElement order]
		$order             setAttribute orderCode "[OT_CfgGet BIBIT_PREFIX ""]$PMT(pmt_id)"
		$submit            appendChild $order

		set description    [$doc createElement description]
		$description       appendChild [$doc createTextNode [ml_printf BIBIT_ORD_DESCRIPTION]]
		$order             appendChild $description

		set amount         [$doc createElement amount]
		$amount            setAttribute \
								value        $BIBIT(amount) \
								currencyCode $CUST(ccy_code) \
								exponent     $BIBIT(exponent)
		$order             appendChild $amount

		# we don't have to have the orderContent element, it is optional
		if {$XML_OPTIONS(add_order_content)} {
			_add_xml_order_content $doc $order PMT CUST
		}

		# payment details - just for bibit_xml (direct payments)
		_add_credit_card_details $doc $order PMT CUST

		# shopper is optional, this is used for some fraud screening, bibit
		# implmenetation manual is not too specific about this
		if {$XML_OPTIONS(add_shopper)} {
			_add_xml_shopper $doc $order CUST
		}

		# you could add a shipping address here
		# if you decide to do it, but it is not mandatory
		if {$XML_OPTIONS(add_shipping_address)} {
			_add_xml_shipping_address $doc $order CUST
		}


		set xml    $declaration\n
		append xml $doctype\n
		append xml [$doc asXML]

		$doc delete
	} msg]} {
		catch {$doc delete}
		return [list 0 BIBIT_ERR_GET_XML_FAILED "$msg; $::errorInfo"]
	}

	return [list 1 BIBIT_GET_XML_OK $xml]

}

proc bibit::_add_credit_card_details {doc order PMT_ARR CUST_ARR} {

	variable XML_OPTIONS

	upvar 1 $PMT_ARR  PMT
	upvar 1 $CUST_ARR CUST

	set paymentDetails [$doc createElement paymentDetails]
	if {$PMT(pay_sort) == "W"} {
		$paymentDetails setAttribute action "REFUND"
	}
	$order              appendChild $paymentDetails

	set mask [$doc createElement "$PMT(mask)"]
	$paymentDetails     appendChild $mask

	set cardNumber     [$doc createElement cardNumber]
	$cardNumber        appendChild [$doc createTextNode [_safe $PMT(card_no)]]
	$mask appendChild $cardNumber

	regexp {([0-9][0-9])/([0-9][0-9])} $PMT(expiry) match expiry_mth expiry_year

	set expiryDate [$doc createElement expiryDate]
	$mask appendChild $expiryDate

	set date [$doc createElement date]
	$date    setAttribute \
						month  $expiry_mth \
						year   "20$expiry_year"
	$expiryDate appendChild $date

	if {$PMT(hldr_name) == ""} {
		set PMT(hldr_name) "$CUST(fname) $CUST(lname)"
	}

	set cardHolderName [$doc createElement cardHolderName]
	$cardHolderName    appendChild [$doc createTextNode [_safe $PMT(hldr_name)]]
	$mask appendChild $cardHolderName

	if {$PMT(start) != "" && ($PMT(mask) == "SWITCH-SSL" || $PMT(mask) == "SOLO_GB-SSL")} {
		regexp {([0-9][0-9])/([0-9][0-9])} $PMT(start) match start_mth start_year
		set startDate [$doc createElement startDate]
		$mask appendChild $startDate

		set date [$doc createElement date]
		$date    setAttribute \
							month  $start_mth \
							year   "20$start_year"
		$startDate appendChild $date
	}

	if {$PMT(issue_no) != "" && ($PMT(mask) == "SWITCH-SSL" || $PMT(mask) == "SOLO_GB-SSL")} {
		set issueNumber    [$doc createElement issueNumber]
		$issueNumber       appendChild [$doc createTextNode [_safe $PMT(issue_no)]]
		$mask appendChild  $issueNumber
	}

	if {$PMT(cvv2) != ""} {
		set cvc            [$doc createElement cvc]
		$cvc               appendChild [$doc createTextNode [_safe $PMT(cvv2)]]
		$mask appendChild  $cvc
	}


	if {$XML_OPTIONS(add_card_address)} {

		set cardAddress     [$doc createElement cardAddress]

		set address         [$doc createElement address]
		$cardAddress        appendChild $address

		set firstName       [$doc createElement firstName]
		$firstName          appendChild [$doc createTextNode [_safe $CUST(fname)]]
		$address            appendChild $firstName

		set lastName        [$doc createElement lastName]
		$lastName           appendChild [$doc createTextNode [_safe $CUST(lname)]]
		$address            appendChild $lastName

		set street          [$doc createElement street]
		$street             appendChild [$doc createTextNode [_safe $CUST(addr_street)]]
		$address            appendChild $street

		set postalCode      [$doc createElement postalCode]
		$postalCode         appendChild [$doc createTextNode [_safe $CUST(addr_postcode)]]
		$address            appendChild $postalCode

		set city            [$doc createElement city]
		$city               appendChild [$doc createTextNode [_safe $CUST(addr_city)]]
		$address            appendChild $city

		set countryCode     [$doc createElement countryCode]
		$countryCode        appendChild [$doc createTextNode [_safe $CUST(country_code)]]
		$address            appendChild $countryCode

		set telephoneNumber [$doc createElement telephoneNumber]
		$telephoneNumber    appendChild [$doc createTextNode [_safe $CUST(telephone)]]
		$address            appendChild $telephoneNumber

		$mask  appendChild $cardAddress

	}

	# add session element here
	if {$XML_OPTIONS(add_session)} {
		_add_xml_session $doc $paymentDetails PMT CUST
	}
}

# Cleans special chars from string.
#
#   str       The str to clean.
#   returns   A clean string.
#
proc bibit::_safe {str} {
	return [string map {< &lt; > &gt; [ {} ] {} $ {}} $str]
}

# Adds the shipping address to an order
#
#   doc        The tdom document.
#   order      The tdom order node.
#   CUST_ARR   An array of customer stuff.
#   returns    Nothing.
#
proc bibit::_add_xml_shipping_address {doc order CUST_ARR} {
	upvar 1 $CUST_ARR CUST

	set shippingAddress [$doc createElement shippingAddress]
	$order              appendChild $shippingAddress

	set address         [$doc createElement address]
	$shippingAddress    appendChild $address

	set firstName       [$doc createElement firstName]
	$firstName          appendChild [$doc createTextNode [_safe $CUST(fname)]]
	$address            appendChild $firstName

	set lastName        [$doc createElement lastName]
	$lastName           appendChild [$doc createTextNode [_safe $CUST(lname)]]
	$address            appendChild $lastName

	set street          [$doc createElement street]
	$street             appendChild [$doc createTextNode [_safe $CUST(addr_street)]]
	$address            appendChild $street

	set postalCode      [$doc createElement postalCode]
	$postalCode         appendChild [$doc createTextNode [_safe $CUST(addr_postcode)]]
	$address            appendChild $postalCode

	set city            [$doc createElement city]
	$city               appendChild [$doc createTextNode [_safe $CUST(addr_city)]]
	$address            appendChild $city

	set countryCode     [$doc createElement countryCode]
	$countryCode        appendChild [$doc createTextNode [_safe $CUST(country_code)]]
	$address            appendChild $countryCode

	set telephoneNumber [$doc createElement telephoneNumber]
	$telephoneNumber    appendChild [$doc createTextNode [_safe $CUST(telephone)]]
	$address            appendChild $telephoneNumber
}

# Convenience proc to add a new element to the given
# 'parent' node which is part of the 'doc' document
# object. Optional 'text' can be passed which will be
# added as a text node to the newly created child of
# name 'child_name'.
#
# eg: addElement $doc $p "myNode"
# would create:
#     <myNode>
#           .....
#     </myNode>
#
# or: addElement $doc $p "myNode" "The text"
# would create:
#     <myNode>The text</myNode>
#

proc bibit::_add_element {doc parent child_name {text ""}} {

	set eChild [$doc createElement $child_name]
	$parent appendChild $eChild
	if {$text != ""} {
	set tChild [$doc createTextNode $text]
	$eChild appendChild $tChild
	}
	return $eChild
}

# Add a shopper element to the order
#
#   doc        A tdom doc.
#   order      The order node.
#   CUST_ARR   The customer array.
#   returns    Nothing.
#
proc bibit::_add_xml_shopper {doc order CUST_ARR} {
	upvar 1 $CUST_ARR CUST

	set shopper         [$doc createElement shopper]
	$order              appendChild $shopper

	set shopperEmailAddress [$doc createElement shopperEmailAddress]
	$shopperEmailAddress    appendChild [$doc createTextNode [_safe $CUST(email)]]
	$shopper                appendChild $shopperEmailAddress

	set authenticatedShopperID [$doc createElement authenticatedShopperID]
	$authenticatedShopperID    appendChild [$doc createTextNode $CUST(acct_id)]
	$shopper                   appendChild $authenticatedShopperID
}

# Add a session element to the order
#
#   doc        A tdom doc.
#   order      The order node.
#   PMT_ARR    The payment array.
#   returns    Nothing.
#
proc bibit::_add_xml_session {doc order PMT_ARR CUST_ARR} {
	upvar 1 $PMT_ARR PMT
	upvar 1 $CUST_ARR CUST

	set session         [$doc createElement session]
	$session            setAttribute \
									shopperIPAddress [_safe $PMT(ip)] \
									id [_safe $CUST(cust_id)]
	$order              appendChild $session
}

# Generate the HTML fragment that goes in the XML request.
#
#   doc        The tdom document element.
#   order      The order node.
#   PMT_ARR    The payment array.
#   CUST_ARR   The customer array.
#   returns    Nothing.
#
proc bibit::_add_xml_order_content {doc order PMT_ARR CUST_ARR} {
	variable CFG

	upvar 1 $PMT_ARR  PMT
	upvar 1 $CUST_ARR CUST

	foreach {name val} [array get PMT] {
		tpBindString PMT_$name $val
	}

	tpBindString PMT_amount [print_ccy $PMT(amount) $CUST(ccy_code)]

	foreach {name val} [array get CUST] {
		tpBindString CUST_$name $val
	}

	# execute the callback procedure
	if {![info exists CFG(HTML_CALLBACK_PROC)]} {
		error "Please set the HTML callback proc, using\
			::bibit::set_html_callback_proc."
	}

	# if this fails, then it will be caught by the calling procedure
	set html [$CFG(HTML_CALLBACK_PROC)]

	if {$html == ""} {
		error "The html is empty"
	}

	set orderContent    [$doc createElement orderContent]
	$orderContent       appendChild [$doc createCDATASection $html]
	$order              appendChild $orderContent
}


# Parses the XML response and determines if the request was successful.
#
#   xml        The XML to parse.
#   RESP_ARR   The array to populate with the response.
#
proc bibit::_parse_xml_resp {xml RESP_ARR} {

	upvar 1 $RESP_ARR RESP

	bibit::log DEBUG "xml = $xml"

	if {[catch {
		set doc [dom parse $xml]
	} msg]} {
		bibit::log ERROR "resp xml = $xml"
		return [list 0 BIBIT_ERR_PARSE_XML_RESP_FAILED $msg]
	}

	set paymentService [$doc documentElement]

	if {[catch {

		set orderStatus [$paymentService selectNodes reply/orderStatus]
		set isRefund    [$paymentService selectNodes reply/ok]

		if {[llength $orderStatus] > 0} {

			set RESP(pmt_id) [$orderStatus getAttribute orderCode]
			set auth_code [$orderStatus selectNodes payment/lastEvent]
			set RESP(auth_code) [$auth_code text]

		} elseif {[llength $isRefund] > 0} {
			set refundReceived [$paymentService selectNodes reply/ok/refundReceived]

			if {[llength $refundReceived] > 0} {
				set RESP(pmt_id) [$refundReceived getAttribute orderCode]
				set RESP(auth_code) "WITHDRAWAL"
				set RESP(code) 9

			} else {
				set RESP(auth_code) "FAIL"
			}

		} else {
			#
			# Some general error, e.g., IP check failure.
			#
			set error [$paymentService selectNodes reply/error]

			set RESP(code) [$error getAttribute code]
			set RESP(msg)  [$error text]

		}

	} msg]} {

		global errorInfo

		$doc delete
		return [list 0 BIBIT_ERR_PARSE_XML_RESP_FAILED "$msg; $errorInfo"]

	}

	$doc delete

	bibit::log DEBUG "[array get RESP]"

	return [list 1 BIBIT_PARSE_XML_RESP_OK]

}

proc bibit::_lookup_country {country_code} {

	array set CC_EXPANSION {
		{UNSPECIFIED} 00
		{ANDORRA} AD
		{UNITED ARAB EMIRATES} AE
		{AFGHANISTAN} AF
		{ANTIGUA AND BARBUDA} AG {ANTIGUA & BARBUDA} AG {ANTIGUA} AG {BARBUDA} AG
		{ANGUILLA} AI
		{ALBANIA} AL
		{ARMENIA} AM
		{NETHERLANDS ANTILLES} AN
		{ANGOLA} AO
		{ANTARCTICA} AQ
		{ARGENTINA} AR
		{AMERICAN SAMOA} AS
		{AUSTRIA} AT
		{AUSTRALIA} AU
		{ARUBA} AW
		{ALAND ISLANDS} AX
		{AZERBAIJAN} AZ
		{BOSNIA AND HERZEGOVINA} BA {BOSNIA & HERZEGOVINA} BA {BOSNIA} BA {HERZEGOVINA} BA
		{BARBADOS} BB
		{BANGLADESH} BD
		{BELGIUM} BE
		{BURKINA FASO} BF
		{BULGARIA} BG
		{BAHRAIN} BH
		{BURUNDI} BI
		{BENIN} BJ
		{BERMUDA} BM
		{BRUNEI DARUSSALAM} BN {BRUNEI} BN
		{BOLIVIA} BO
		{BRAZIL} BR
		{BAHAMAS} BS
		{BHUTAN} BT
		{BOUVET ISLAND} BV
		{BOTSWANA} BW
		{BELARUS} BY
		{CANADA} CA
		{COCOS (KEELING) ISLANDS} CC {COCOS ISLANDS} CC {KEELING ISLANDS} CC
		{CENTRAL AFRICAN REPUBLIC} CF
		{CONGO} CG
		{SWITZERLAND} CH
		{COTE D'IVOIRE} CI {IVORY COAST} CI
		{COOK ISLANDS} CK
		{CHILE} CL
		{CAMEROON} CM
		{CHINA} CN {CHINA, PEOPLE'S REP. OF} CN {CHINA, PEOPLES REP. OF} CN {CHINA, PEOPLE'S REPUBLIC OF} CN {CHINA, PEOPLES REPUBLIC OF} CN {PEOPLE'S REP. OF CHINA} CN {PEOPLES REP. OF CHINA} CN {PEOPLE'S REPUBLIC OF CHINA} CN {PEOPLES REPUBLIC OF CHINA} CN {CHINA (HONG KONG S.A.R.)} CN
		{COLOMBIA} CO
		{COSTA RICA} CR
		{CZECHOSLOVAKIA} CS
		{CUBA} CU
		{CAPE VERDE} CV
		{CHRISTMAS ISLAND} CX
		{CYPRUS} CY
		{CZECH REPUBLIC} CZ
		{GERMANY} DE
		{DJIBOUTI} DJ
		{DENMARK} DK
		{DOMINICA} DM
		{DOMINICAN REPUBLIC} DO
		{ALGERIA} DZ
		{ECUADOR} EC
		{ESTONIA} EE
		{EGYPT} EG
		{WESTERN SAHARA} EH
		{ERITREA} ER
		{SPAIN} ES
		{ETHIOPIA} ET
		{FINLAND} FI
		{FIJI} FJ
		{FALKLAND ISLANDS} FK {MALVINAS} FK
		{MICRONESIA} FM
		{FAROE ISLANDS} FO
		{FRANCE} FR
		{GABON} GA
		{GREAT BRITAIN} GB {ENGLAND} GB {SCOTLAND} GB {WALES} GB {NORTHERN IRELAND} GB {UNITED KINGDOM} GB {UK} GB {U.K.} GB {G.B.} GB
		{GRENADA} GD
		{GEORGIA} GE
		{FRENCH GUIANA} GF
		{GHANA} GH
		{GIBRALTAR} GI
		{GREENLAND} GL
		{GAMBIA} GM
		{GUINEA} GN
		{GUADELOUPE} GP
		{EQUATORIAL GUINEA} GQ
		{GREECE} GR
		{SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS} GS {SOUTH GEORGIA & THE SOUTH SANDWICH ISLANDS} GS
		{GUATEMALA} GT
		{GUAM} GU
		{GUINEA BISSAU} GW
		{GUYANA} GY
		{HONG KONG} HK {HONG-KONG} HK {HONG KONG, CHINA} HK {HONG-KONG, CHINA} HK
		{HEARD AND MCDONALD ISLANDS} HM
		{HONDURAS} HN
		{CROATIA} HR {HRVATSKA} HR
		{HAITI} HT
		{HUNGARY} HU
		{INDONESIA} ID
		{IRELAND} IE {IRELAND, REPUBLIC OF} IE {REPUBLIC OF IRELAND} IE
		{EIRE} IE
		{ISRAEL} IL
		{INDIA} IN
		{BRITISH INDIAN OCEAN TERRITORY} IO
		{IRAQ} IQ
		{IRAN} IR {ISLAMIC REPUBLIC OF IRAN} IR
		{ICELAND} IS
		{ITALY} IT
		{JAMAICA} JM
		{JORDAN} JO
		{JAPAN} JP
		{KENYA} KE
		{KYRGYZSTAN} KG
		{CAMBODIA} KH
		{KIRIBATI} KI
		{COMOROS} KM
		{SAINT KITTS AND NEVIS} KN {SAINT KITTS-NEVIS} KN {SAINT KITTS & NEVIS} KN {ST. KITTS AND NEVIS} KN {ST. KITTS-NEVIS} KN {ST. KITTS & NEVIS} KN
		{NORTH KOREA} KP
		{KOREA, REPUBLIC OF} KR {REPUBLIC OF KOREA} KR {SOUTH KOREA} KR {KOREA} KR
		{KUWAIT} KW
		{CAYMAN ISLANDS} KY
		{KAZAKHSTAN} KZ
		{LAOS} LA
		{LEBANON} LB
		{SAINT LUCIA} LC {ST. LUCIA} LC
		{LIECHTENSTEIN} LI
		{SRI LANKA} LK
		{LIBERIA} LR
		{LESOTHO} LS
		{LITHUANIA} LT
		{LUXEMBOURG} LU
		{LATVIA} LV
		{LIBYA} LY
		{MOROCCO} MA
		{MONACO} MC
		{MOLDOVA} MD
		{MADAGASCAR} MG
		{MARSHALL ISLANDS} MH
		{MACEDONIA} MK
		{MALI} ML
		{MYANMAR} MM
		{MONGOLIA} MN
		{MACAO} MO {MACAU} MO
		{NORTHERN MARIANA ISLANDS} MP
		{MARTINIQUE} MQ
		{MAURITANIA} MR
		{MONTSERRAT} MS
		{MALTA} MT
		{MAURITIUS} MU
		{MALDIVES} MV
		{MALAWI} MW
		{MEXICO} MX
		{MALAYSIA} MY
		{MOZAMBIQUE} MZ
		{NAMIBIA} NA
		{NEW CALEDONIA} NC
		{NIGER} NE
		{NORFOLK ISLAND} NF
		{NIGERIA} NG
		{NICARAGUA} NI
		{NETHERLANDS} NL {THE NETHERLANDS} NL {HOLLAND} NL
		{NORWAY} NO
		{NEPAL} NP
		{NAURU} NR
		{NIUE} NU
		{NEW ZEALAND} NZ {AOTEAROA} NZ
		{OMAN} OM
		{PANAMA} PA
		{PERU} PE
		{FRENCH POLYNESIA} PF
		{PAPUA NEW GUINEA} PG
		{PHILIPPINES} PH
		{PAKISTAN} PK
		{POLAND} PL
		{ST PIERRE AND MIQUELON} PM {ST PIERRE & MIQUELON} PM
		{PITCAIRN} PN
		{PUERTO RICO} PR
		{PALESTINIAN TERRITORY} PS
		{PORTUGAL} PT
		{PALAU} PW
		{PARAGUAY} PY
		{QATAR} QA
		{REUNION} RE
		{ROMANIA} RO
		{RUSSIA} RU {RUSSIAN FEDERATION} RU
		{RWANDA} RW
		{SAUDI ARABIA} SA
		{BRITISH SOLOMON ISLANDS} SB {SOLOMON ISLANDS} SB
		{SEYCHELLES} SC
		{SUDAN} SD
		{SWEDEN} SE
		{SINGAPORE} SG
		{ST HELENA} SH
		{SLOVENIA} SI
		{SVALBARD AND JAN MAYEN ISLANDS} SJ {SVALBARD & JAN MAYEN ISLANDS} SJ
		{SLOVAK REPUBLIC} SK {SLOVAKIA} SK
		{SIERRA LEONE} SL
		{SAN MARINO} SM
		{SENEGAL} SN
		{SOMALIA} SO
		{SURINAME} SR
		{SAO TOME AND PRINCIPE} ST {SAO TOME & PRINCIPE} ST
		{USSR} SU
		{EL SALVADOR} SV
		{SYRIA} SY
		{SWAZILAND} SZ
		{TURKS AND CAICOS ISLANDS} TC {TURKS & CAICOS ISLANDS} TC
		{CHAD} TD
		{FRENCH SOUTHERN TERRITORIES} TF
		{TOGO} TG
		{THAILAND} TH
		{TAJIKISTAN} TJ
		{TOKELAU} TK
		{TIMOR-LESTE} TL
		{TURKMENISTAN} TM
		{TUNISIA} TN
		{TONGA} TO
		{EAST TIMOR} TP
		{TURKEY} TR
		{TRINIDAD AND TOBAGO} TT {TRINIDAD & TOBAGO} TT {TRINIDAD} TT {TOBAGO} TT
		{TUVALU} TV
		{TAIWAN} TW
		{TANZANIA} TZ
		{UKRAINE} UA
		{UGANDA} UG
		{UNITED STATES MINOR OUTLYING ISLANDS} UM
		{AMERICA} US {UNITED STATES} US {U.S.} US {UNITED STATES OF AMERICA} US {USA} US {U.S.A.} US
		{URUGUAY} UY
		{UZBEKISTAN} UZ
		{VATICAN CITY STATE} VA {HOLY SEE} VA
		{SAINT VINCENT AND THE GRENADINES} VC {SAINT VINCENT & THE GRENADINES} VC {SAINT VINCENT & GRENADINES} VC {SAINT VINCENT} VC {ST. VINCENT AND THE GRENADINES} VC {ST. VINCENT & THE GRENADINES} VC {ST. VINCENT & GRENADINES} VC {ST. VINCENT} VC {THE GRENADINES} VC
		{VENEZUELA} VE
		{BRITISH VIRGIN ISLANDS} VG {VIRGIN ISLANDS (BRITISH)} VG
		{US VIRGIN ISLANDS} VI {U.S. VIRGIN ISLANDS} VI {VIRGIN ISLANDS (US)} VI {VIRGIN ISLANDS (U.S.)} VI {VIRGIN ISLANDS} VI
		{VIET NAM} VN {VIETNAM} VN
		{VANUATU} VU
		{WALLIS AND FUTUNA ISLANDS} WF
		{SAMOA} WS
		{YEMEN} YE
		{MAYOTTE} YT
		{SOUTH AFRICA} ZA
		{ZAMBIA} ZM
		{ZIMBABWE} ZW
	}

	set country_code [string toupper $country_code]

	if {[info exists CC_EXPANSION($country_code)]} {
		return $CC_EXPANSION($country_code)
	} else {
		return "00"
	}
}

foreach {ok msg} [bibit::init] {break}

bibit::log INFO {bibit: init: $msg}
