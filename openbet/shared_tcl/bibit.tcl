# $Id: bibit.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2004-2005 Orbis Technology Ltd. All Rights Reserved.
#
# The two main commands are 'prepare', which sends a request to the bibit server
# and returns an array containing a URL which the customer should be redirected to
# 'complete' should be called by your appserver when the bibit server does the callback
# your appserver should choose the name of action to use for this
#
# based on http://www.bibit.com/pdf/implman253.pdf
#
# see also cvs/dev_utils/tcl/fake_bibit.tcl
#
# All procedures return a two or three element list containing, in order, the
# following:
#
#   success 0 or 1 to show if the procedure was succesful or failed.
#   xl      A translatable code representing either success or failure.
#   msg     An English message for logging more detailed information about the
#           error.
#
# Configuration:
#
#   FUNC_BIBIT             Activate bibit.
#   BIBIT_URL              The URL to which to post the bibit request.
#   BIBIT_TIMEOUT          The timout period in ms.
#   BIBIT_PAY_METH_MASKS   The payment method masks.
#   BIBIT_USERNAME         The username for the bibit request, also the merchant code.
#   BIBIT_PASSWORD         The password.
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
#   bibit::set_html_callback_proc  Set the procedure to call to get the html.
#   bibit::authorize               Authorize generic CC payment.
#   bibit::prepare                 Prepare an eNets query.
#   bibit::complete                Complete a bibit request.
#   bibit::complete_xml            Complete a bibit request with XML.

package require http 2.3
package require tls
package require base64
package require tdom

package require OB_Log

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
		SOLO SOL_GB-SSL   \
		SWCH SWITCH-SSL   \
		ENET ENETS-SSL    \
		ELTN VISA-SSL \
	]

	variable  CFG
	array set CFG [list                                            \
		BIBIT          [OT_CfgGetTrue FUNC_BIBIT]                  \
		URL            [OT_CfgGet     BIBIT_URL                ""] \
		TIMEOUT        [OT_CfgGet     BIBIT_TIMEOUT             0] \
		PAY_METH_MASKS [OT_CfgGet     BIBIT_PAY_METH_MASKS [list]] \
		USERNAME       [OT_CfgGet     BIBIT_USERNAME           ""] \
		PASSWORD       [OT_CfgGet     BIBIT_PASSWORD           ""] \
		DTD_URL        [OT_CfgGet     BIBIT_DTD_URL            ""] \
		XML_OPTIONS    [OT_CfgGet     BIBIT_XML_OPTIONS    [list]] \
	]

	variable  XML_OPTIONS
	array set XML_OPTIONS $CFG(XML_OPTIONS)

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

	if { $CFG(URL) != "" && [regexp ^https:// $CFG(URL)] } {
		ob::log::write INFO {bibit: BIBIT_URL is not https}
	}

	ob::log::write_array DEBUG CFG
	ob::log::write_array DEBUG XML_OPTIONS

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


proc bibit::authorize array {

	variable CFG
	variable MASKS

	upvar 1 $array pmt
OT_LogWrite 1 "file bibit.tcl - proc bibit::authorize"
	if { ![info exists MASKS($pmt(card_scheme))] } {

		ob::log::write ERROR {Unrecognized card scheme: $pmt(card_scheme)}
		return BIBIT_ERR_NO_MTHD

	}

	set pmt(mask) $MASKS($pmt(card_scheme))

	if { [lsearch $CFG(PAY_METH_MASKS) $pmt(mask)] == -1 } {

		ob::log::write ERROR {Unsupported card scheme: $pmt(card_scheme)}
		return BIBIT_ERR_NO_MTHD

	}

	if { $pmt(type) == "DEP" } {
		return [list 0 BIBIT_ERR_NO_WTD "Withdrawal is not available on bibit"]
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

	#
	# Make sure the status is set to 'U' or the Bibit call-back server will fail
	# when it tries to complete the payment.
	#
	if { [catch {
		tb_db::tb_exec_qry bibit::upd_pmt_status U $pmt(pmt_id)
	} msg] } {
		ob::log::write ERROR "bibit::upd_pmt_status query failed: $msg"
		return PMT_ERR
	}

	set pmt(status) U

	#
	# generate the xml
	#
	foreach { ok xl msg } [_get_xml_req pmt cust $pmt(amount)] {break}

	if { !$ok } {
		ob::log::write ERROR {bibit: failed to generate XML: $msg}
		return $xl
	}

	set xml $msg

	ob::log::write DEBUG {bibit: xml=$xml}

	set auth [base64::encode $pmt(client):$pmt(password)]

	if {[catch {
		set token [http::geturl \
			$pmt(host) \
			-headers [list Authorization "Basic $auth"] \
			-query   $xml \
			-timeout $pmt(conn_timeout) \
			-type    text/xml \
		]
	} msg]} {
		ob::log::write ERROR {bibit: http failure: $msg}
		return BIBIT_ERR_HTTP_FAILED
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
		ob::log::write ERROR \
			{bibit: http error: ncode = $http(ncode), status = $http(status)}
		return BIBIT_ERR_HTTP_FAILED
	}

	foreach { ok xl msg } [_parse_xml_resp $http(data) RESP] {break}

	if {!$ok} {
		ob::log::write ERROR {bibit: failed to parse xml response($xl): $msg}
		return $xl
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
			}
			5 {
				# special case of the missing post code,
				# there maybe more of these, don't be scared to add them
				switch -glob $RESP(msg) {

					"*Postal code*" {
						set err BIBIT_ERR_INVALID_POST_CODE
					}

				}

				set err BIBIT_ERR_INVALID_REQUEST

			}
			8 {
				set err BIBIT_ERR_TEMP_UNAVAIL
			}

			default {
				ob::log::write ERROR {bibit: error code $code unknown}
				set err PMT_ERR
			}

		}

		return $err

	}

	tpBindString BIBIT_REDIRECT_URL $RESP(url)

	return PMT_URL_REDIRECT

}


# Sends the pmt request to the server, this then returns an XML response that we
# can parse and then (and only then) show the customers the URL returned.
#
# 1. Generate the PMT.
# 2. Generate XML.
# 3. Post XML.
# 4. Parse XML response.
# 5. Update the PMT with the reference.
#
# There are a number of failure points, if the URL cannot be returned then we
# update the payment to fail, because we cannot show the redirect page.
#
# NOTE: only deposits are supported.
#
#   cust_id     The customer's id.
#   acct_id     The customer's account id.
#   cpm_id      The customer eNETS payment method.
#   amount      The amount of the payment.
#   unique_id   A unique id.
#   type        The type of payment (DEP or WTD)
#   RESP_ARR    An array containing the respose from the server, use this to
#               create the redirect page in your customer screens.
#
proc bibit::prepare {
	  cust_id
	  acct_id
	  cpm_id
	  amount
	  unique_id
	  type
	  RESP_ARR
	{ comm_list {} }
} {

	variable CFG

	if { !$CFG(BIBIT) } {
		return [list 0 BIBIT_ERR_DISABLED Disabled]
	}

	if { $type == "DEP" } {
		return [list 0 BIBIT_ERR_NO_WTD "Withdrawal is not available on bibit"]
	}

	if { $comm_list == {} } {
		set comm_list [list 0 $amount $amount]
	}

	#
	# get the commission, payment amount and tPmt amount from the list
	#
	set commission  [lindex $comm_list 0]
	set amount      [lindex $comm_list 1]
	set tPmt_amount [lindex $comm_list 2]

	upvar 1 $RESP_ARR RESP

	#
	# get the customers details
	#
	_get_cust $cust_id CUST

	if {!$ok} {
		return [list 0 $xl $msg]
	}

	#
	# check the amount is ok
	#
	foreach {ok xl msg} [_check_amount $amount $CUST(ccy_code)] {break}

	if {!$ok} {
		return [list 0 $xl $msg]
	}

	#
	# Insert the payment.
	#
	foreach {ok xl msg} [enets::ins_pmt_dep \
		$acct_id \
		$cpm_id \
		$tPmt_amount \
		$commission \
		$unique_id \
		"" \
		"" \
		E \
		"" \
		I \
		"" \
		PMT \
	] {break}

	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] } {
		ob_camp_track::record_camp_action $cust_id "DEP" "OB" $PMT(pmt_id)
	}

	if {!$ok} {
		return [list 0 $xl $msg]
	}

	set PMT(mask) ENETS-SSL

	#
	# generate the xml
	#
	foreach { ok xl msg } [_get_xml_req PMT CUST $amount] {break}

	if {!$ok} {

		ob::log::write ERROR {bibit: failed to get xml($xl): $msg}

		foreach {ok xl1 msg1} [enets::upd_pmt_dep $PMT(pmt_id) N] {break}

		#
		# failure on top of a failure, don't like this really,
		# we just log it, the customer will be stuck with a pending deposit
		#
		if {!$ok} {
			ob::log::write ERROR {bibit:\
				failed to update a pmt after a get xml failure($xl1): $msg1}
		}
		return [list 0 $xl $msg]

	}

	set xml $msg

	ob::log::write DEBUG {bibit: xml=$xml}

	set auth [base64::encode $CFG(USERNAME):$CFG(PASSWORD)]

	ob::log::write INFO {bibit: auth=$auth}

	# Set the status to "U"nknown. Staying at "P"ending was causing issues.

	set PMT(status) U

	# update the status before the order, so that we know we've sent the order
	foreach {ok xl msg} [enets::upd_pmt_dep \
		$PMT(pmt_id) \
		$PMT(status) \
		$PMT(gw_uid) \
		$PMT(gw_pmt_id) \
		O \
	] {break}

	if {!$ok} {
		ob::log::write ERROR {bibit: failed to update deposit($xl): $msg}
	}

	if {[catch {
		set token [http::geturl \
			$CFG(URL) \
			-headers [list Authorization "Basic $auth"] \
			-query   $xml \
			-timeout $CFG(TIMEOUT) \
			-type    text/xml \
		]
	} msg]} {

		foreach {ok xl1 msg1} [enets::upd_pmt_dep $PMT(pmt_id) N] {break}

		#
		# just carry on and log this
		#
		if {!$ok} {
			ob::log::write ERROR {bibit:\
				failed to update a pmt after a http failure($xl1): $msg1}
		}

		return [list 0 BIBIT_ERR_HTTP_FAILED $msg]

	}

	upvar #0 $token state

	foreach n {data error status code ncode} {
		set http($n) [http::$n $token]
	}

	foreach n {http meta} {
		set http($n) $state($n)
	}

	http::cleanup $token

	ob::log::write_array DEV http

	#
	# if the error is in the error range, then we must fail the request
	#
	if {$http(ncode) >= 400 || $http(status) == "error"} {

		foreach {ok xl1 msg1} [enets::upd_pmt_dep \
			$PMT(pmt_id) \
			N \
			$PMT(gw_uid) \
			$PMT(gw_pmt_id) \
			R \
		] {break}

		#
		# failure on top of a failure, just log this
		#
		if {!$ok} {
			ob::log::write ERROR {bibit: failed to update a pmt after a http failure($xl1): $msg1}
		}

		return [list 0 BIBIT_ERR_HTTP_FAILED "http failure: $http(status), $http(ncode)"]

	}

	foreach {ok xl msg} [_parse_xml_resp $http(data) RESP] {break}

	#
	# We failed to parse the response, this is bad:
	# it means that the transaction can't take place
	#
	if {!$ok} {

		ob::log::write ERROR {bibit: failed to parse xml response($xl): $msg}

		foreach {ok xl1 msg1} [enets::upd_pmt_dep \
			$PMT(pmt_id) \
			N \
			$PMT(gw_uid) \
			$PMT(gw_pmt_id) \
			R \
		] {break}

		# failure on top of a failure, just log this
		if {!$ok} {
			ob::log::write ERROR {bibit:\
				failed to update a pmt after xml parse failure($xl1): $msg1}
		}

		return [list 0 $xl $msg]

	}

	#
	# deal with an error response
	#
	if {[info exists RESP(code)]} {

		foreach {ok xl1 msg1} [enets::upd_pmt_dep \
			$PMT(pmt_id) \
			N \
			$PMT(gw_uid) \
			$PMT(gw_pmt_id) \
			R \
		] {break}

		#
		# failure on top of a failure, just log this
		#
		if {!$ok} {
			ob::log::write ERROR {bibit:\
				failed to update a pmt after a xml failure reponse($xl1): $msg1}
		}

		switch $RESP(code) {

			1 -
			2 -
			4 -
			6 -
			7 {
				set err BIBIT_ERR
			}
			5 {
				# special case of the missing post code,
				# there maybe more of these, don't be scared to add them
				switch -glob $RESP(msg) {

					"*Postal code*" {
						set err BIBIT_ERR_INVALID_POST_CODE
					}

				}

				set err BIBIT_ERR_INVALID_REQUEST

			}
			8 {
				set err BIBIT_ERR_TEMP_UNAVAIL
			}

			default {
				ob::log::write ERROR {bibit: error code $code unknown}
				set err BIBIT_ERR
			}

		}

		return [list 0 $err $RESP(msg)]

	}

	# if the reference id is returned in the xml, then use that, otherwise just use the normal one
	set gw_uid [expr {
		[info exists RESP(gw_uid)]
			? $RESP(gw_uid)
			:  $PMT(gw_uid)
	}]


	# store that we've gone to the redirect page (we assume the callee will do so)
	foreach {ok xl msg} [enets::upd_pmt_dep \
		$PMT(pmt_id) \
		$PMT(status) \
		$gw_uid \
		$PMT(gw_pmt_id) \
		D \
	] {break}

	# failure on top of a failure, just log this
	if {!$ok} {
		ob::log::write ERROR {bibit: failed to update gw_uid to $gw_uid and ext_ord_status to D ($xl): $msg}
		return [list 0 $xl $msg]
	}

	return [list 1 BIBIT_SENT_PMT_OK]

}


#
# Get details about the customer.
#
#   cust_id   The customers id.
#   CUST_ARR  An array to populate with the customer details.
#
proc bibit::_get_cust { cust_id CUST_ARR } {

	upvar 1 $CUST_ARR CUST

	# set up cust array
	foreach c {
		cust_id
		fname
		lname
		addr_street_1
		addr_street_2
		addr_street_3
		addr_street_4
		addr_city
		addr_postcode
		addr_country
		telephone
		email
		acct_id
		ccy_code
	} {
		set CUST($c) [ob::cust::get_val $c]
	}

	# for ease
	set CUST(addr_street) [list]
	foreach c {
		addr_street_1
		addr_street_2
		addr_street_3
		addr_street_4
	} {
		if {$CUST($c) != ""} {
			lappend CUST(addr_street) $CUST($c)
		}
	}
	set CUST(addr_street) [join $CUST(addr_street) ", "]

	ob::log::write_array DEBUG CUST

	return [list 1 BIBIT_GET_CUST_OK]

}


#
# Checks that the amount is not too high.
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

		ob::log::write ERROR \
			{bibit::_check_amount ($amount, $ccy_code) failed: $err}

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
		$order             setAttribute orderCode $PMT(pmt_id)
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

		set paymentMethodMask [$doc createElement paymentMethodMask]
		$order                appendChild $paymentMethodMask

		#
		# Add the correct mask.
		#
		set include         [$doc createElement include]
		$include            setAttribute code $PMT(mask)
		$paymentMethodMask  appendChild $include

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


#
# Set the procedure to call to get the html fragment.
#
proc bibit::set_html_callback_proc cb {

	variable CFG

	set CFG(HTML_CALLBACK_PROC) $cb

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

	if {[catch {
		set doc [dom parse $xml]
	} msg]} {
		return [list 0 BIBIT_ERR_PARSE_XML_RESP_FAILED $msg]
	}

	set paymentService [$doc documentElement]

	if {[catch {

		set orderStatus [$paymentService selectNodes reply/orderStatus]

		if {[llength $orderStatus] > 0} {

			set RESP(pmt_id) [$orderStatus getAttribute orderCode]

			set reference [$orderStatus selectNodes reference]

			#
			# If we get a reference then everyting is good.
			#
			if {[llength $reference] > 0} {

				if {[$reference hasAttribute id]} {
					set RESP(gw_uid) [$reference getAttribute id]
				}

				set RESP(url) [string trim [$reference text]]

			} else {

				#
				# There was an error with the order.
				#
				set error [$paymentService selectNodes reply/orderStatus/error]

				set RESP(code) [$error getAttribute code]
				set RESP(msg)  [$error text]

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

	ob::log::write_array DEBUG RESP

	return [list 1 BIBIT_PARSE_XML_RESP_OK]

}

# Attempts to complete the xml using a post.
#
#    xml - The XML post.
#
proc bibit::complete_xml {xml} {
	variable CFG

	if {!$CFG(BIBIT)} {
		return [list 0 BIBIT_ERR_DISABLED Disabled]
	}

	foreach {ok xl msg} [_parse_callback_xml $xml REQ] {break}

	if {!$ok} {
		return [list 0 $xl $msg]
	}

	return [complete REQ PMT]
}

# Parses the xml from the callback.
#
#   xml     - The XML message.
#   REQ_ARR - An array to populate with the details from the message.
#
proc bibit::_parse_callback_xml {xml REQ_ARR} {

	upvar 1 $REQ_ARR REQ

	if {[catch {
		set doc [dom parse $xml]
	} msg]} {
		return [list 0 BIBIT_ERR_PARSE_XML_FAILED $msg]
	}

	set paymentService    [$doc documentElement]

	set orderStatusEvent  [$paymentService selectNodes notify/orderStatusEvent]

	set payment           [$orderStatusEvent selectNodes payment]

	set paymentMethod     [$payment          selectNodes paymentMethod]
	set amount            [$payment          selectNodes amount]
	set lastEvent         [$payment          selectNodes lastEvent]

	# get the item and put them in an array
	set REQ(pmt_id)        [$orderStatusEvent getAttribute orderCode]

	set REQ(pay_meth)      [$paymentMethod    text]

	set REQ(ccy_code)      [$amount           getAttribute currencyCode]
	set REQ(amount)        [$amount           getAttribute value]
	set REQ(exponent)      [$amount           getAttribute exponent]

	set REQ(gw_ret_msg)    [$lastEvent        text]

	$doc delete

	return [list 1 BIBIT_XML_PARSE_OK]

}

# Complete a bibit payment.
#
# Check the documentation for where these are to come from.
#
# It is important to ensure that the server which calls this does appropriate
# firewalling to check the source of the server.
#
# see also section 6.3.3, page 26 of the implementation manual
#
#   REQ_ARR            An array containing the request, this must contain the
#                      following elements.
#   pmt_id             This is the pmt_id from tPmt.
#   gw_pmt_id          Optional third party payment id.
#   gw_ret_msg         This is the bibit status.
#   amount             The payment amount, checked against the payment amount.
#   exponent           The exponent on the amount.
#   ccy_code           The currency of the payment.
#   pay_meth           The payment method (e.g. ENETS-SSL)
#
#   PMT_ARR            An array to store the payment in, if blank then it is no populated. ("")
#
proc bibit::complete {REQ_ARR {PMT_ARR ""}} {

	variable CFG
	variable EXPONENT

	if {!$CFG(BIBIT)} {
		return [list 0 BIBIT_ERR_DISABLED Disabled]
	}

	upvar 1 $REQ_ARR REQ

	if {$PMT_ARR != ""} {
		upvar 1 $PMT_ARR PMT
	}

	array unset PMT

	set https [reqGetEnv HTTPS]

	if {$https != "on"} {
		ob::log::write INFO {The callback is not being done over secure https}
	}

	#
	# Only complete payments if we support their payment method
	#
	if { [lsearch $CFG(PAY_METH_MASKS) $REQ(pay_meth)] == -1 } {
		#
		# Ignore this completion message
		#
		return [list 0 BIBIT_ERR_CALLBACK_MTHD_BAD \
			"Cannot complete payments of type $REQ(pay_meth)"]
	}

	#
	# the exponent will be missing in non-xml requests
	#
	if { ![info exists REQ(exponent)] } {
		set REQ(exponent) $EXPONENT($REQ(ccy_code))
	}

	#
	# lets log the contents of the array
	#
	ob::log::write_array DEBUG REQ

	if { [string equal $REQ(pay_meth) ENETS-SSL] } {

		foreach { ok xl msg } [enets::get_pmt $REQ(pmt_id) PMT] {break}

		if {!$ok} {
			return [list 0 $xl $msg]
		}

		#
		# Store the fact that we've got a message for a payment
		#
		foreach {ok xl msg} [enets::upd_pmt_dep \
			$PMT(pmt_id) \
			$PMT(status) \
			$PMT(gw_uid) \
			$PMT(gw_pmt_id) \
			P \
		] {break}

		#
		# we don't have to fail here if the update fails
		#
		if {!$ok} {
			ob::log::write ERROR {bibit: failed to update payment($xl): $msg}
		}

	} else {

		if { [catch {
			set rs [tb_db::tb_exec_qry bibit::get_cc_pmt $REQ(pmt_id)]
		} msg] } {
			ob::log::write ERROR "bibit::get_cc_pmt query failed: $msg"
			return [list 0 $msg]
		}

		set PMT(pmt_id)    $REQ(pmt_id)
		set PMT(amount)    [db_get_col $rs amount]
		set PMT(ccy_code)  [db_get_col $rs ccy_code]

		db_close $rs

	}

	# check the amount etc.
	set exponent $EXPONENT($PMT(ccy_code))

	if {$PMT(amount) != $REQ(amount) / pow(10, $REQ(exponent))} {
		return [list 0 BIBIT_ERR_CALLBACK_AMT_BAD \
			"The payment amount $REQ(amount), $REQ(exponent)\
				does not match the expected value $PMT(amount)"]
	}
	if {$PMT(ccy_code) != $REQ(ccy_code)} {
		return [list 0 BIBIT_ERR_CALLBACK_CCY_BAD \
			"The payment currency $REQ(ccy_code)\
				does not match the expected value $PMT(ccy_code)"]
	}

	# get the status

	switch $REQ(gw_ret_msg) {
		AUTHORISED {
			# auth, but the amount is not transfered yet
			# the customer may change their mind on how to deal with this
			set status Y
		}
		CAPTURED {
			# the payment has been auth and done
			set status Y
		}
		REFUSED {
			# the fiscal institution failed to auth the payment
			set status N
		}
		default {
			return [list 0 BIBIT_ERR_PAY_STATUS_BAD \
				"$REQ(gw_ret_msg) not supported"]
		}
	}

	if { [string equal $REQ(pay_meth) ENETS-SSL] } {

		#
		# update the payment with the new status and payment details.
		# Note that the xml version doesn't know the gw_pmt_id (don't know why
		# yet), so if we don't know this we default to the original one.
		#
		foreach {ok xl msg} [enets::upd_pmt_dep \
			$PMT(pmt_id) \
			$status \
			$PMT(gw_uid) \
			[expr {[info exists REQ(gw_pmt_id)]
				? $REQ(gw_pmt_id)
				: $PMT(gw_pmt_id)}] \
			P \
			$REQ(gw_ret_msg) \
		] {break}

		if {!$ok} {
			return [list 0 $xl $msg]
		}

	} else {

		#
		# update the payment table whatever the response
		#
		payment_CC::cc_pmt_auth_payment                                    \
			$REQ(pmt_id)                                                   \
			$status                                                        \
			""                                                             \
			Y                                                              \
			""                                                             \
			""                                                             \
			[expr { [info exists REQ(gw_pmt_id)] ? $REQ(gw_pmt_id) : "" }] \
			""                                                             \
			$REQ(gw_ret_msg)                                               \
			""                                                             \
			""                                                             \
			0                                                              \
			""


	}

	return [list 1 BIBIT_CALLBACK_OK]

}

foreach {ok msg} [bibit::init] {break}

ob::log::write INFO {bibit: init: $msg}
