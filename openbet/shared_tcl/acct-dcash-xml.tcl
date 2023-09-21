# $Id: acct-dcash-xml.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd.  All rights reserved.
#
# OpenBet Datacash API
#
# CONFIG
#
#	DCASH_REQUIRE_CV2 - use CV2 checking (default 0)
#
# PROCEDURES
#
#	ob::DCASH::init
#	ob::DCASH::reset
#	ob::DCASH::set_up
#	ob::DCASH::authorise
#	ob::DCASH::get_resp_val
#	ob::DCASH::settle



# Package
#
package provide OB_DCASH 1.0



# Namespace
#
namespace eval ob::DCASH {

	variable INITIALISED
	set INITIALISED 0

	variable DCASH_CFG
	variable DCASH_LOOKUP
	variable DCASH_DATA
	variable DCASH_RESP
	variable DCASH_LOG
	variable DCASH_REQUIRE_CV2 0

	# The DCASH_STATUS_RESPONSE_TABLE is used to map the status field
	# to an internal pg response code
	variable DCASH_STATUS_RESPONSE_TABLE
}



# Initialise
#
proc ob::DCASH::init {} {
	variable INITIALISED
	variable DCASH_STATUS_RESPONSE_TABLE
	variable DCASH_REQUIRE_CV2

	if {$INITIALISED} {return}

	package require net_socket
	package require tdom

	ob_log::write 1 {************* INIT XML GATE **************}

	set DCASH_REQUIRE_CV2 [OT_CfgGet DCASH_REQUIRE_CV2 0]

	array set DCASH_STATUS_RESPONSE_TABLE {
		1  OK
		3  PMT_RESP
		6  PMT_RESP
		7  PMT_DECL
		8  PMT_RESP
		21 PMT_TYPE
		22 PMT_REF
		24 PMT_EXPR
		25 PMT_CRNO
		26 PMT_CLEN
		27 PMT_ISSUE
		28 PMT_STRT
		29 PMT_STRT
		36 PMT_SPEED
		56 PMT_SPEED
		120 PMT_DC_NOT_SUBSCRIBED
		121 PMT_DUP_REF
		122 PMT_NON_GBP
		123 PMT_NON_UK_CARD
		124 PMT_INVALID_CARD_NAME
		125 PMT_SYS_ERR
		126 PMT_UNKNOWN_DETAILS
		127 PMT_TRANS_LIMIT_EXCEEDED
		134 PMT_INVALID_ACC_NAME
		135 PMT_BANK_WIZARD_FAIL
		136 PMT_BANK_BACS_FAIL
		137 PMT_DDI_LOCATE_FAIL
		150 PMT_3DS_OK_REDIRECT
		158 PMT_3DS_NO_SUPPORT
		161 PMT_REFER
		162 PMT_3DS_OK_DIRECT_AUTH
		173 PMT_3DS_OK_DIRECT_AUTH
		179 PMT_3DS_VERIFY_FAIL
		183 PMT_3DS_BYPASS
	}

	set INITIALISED 1
}



# Reset variables to default state
#
proc ob::DCASH::reset {} {

	variable DCASH_CFG
	variable DCASH_DATA
	variable DCASH_RESP

	catch {unset DCASH_CFG }
	catch {unset DCASH_DATA}
	catch {unset DCASH_RESP}

}



# Initialise datacash payment gateway settings
#
#	* 0 Accept all transactions
#	* 1 Address must be checked and must match
#	* 2 Security Code must be checked and must match
#	* 3 All data must be checked and must match
#	* 4 Reverse all transactions
#	* 5 Address must match if checked
#	* 6 Security Code must match if checked
#	* 7 All data must match if checked
#
#	Policy 0 cannot be set with the transaction, only as a default policy.
#	This is useful if you want to monitor the cv2avs results for a while before
#	deciding which policy to use (or whether to implement the service).
#
#	If no policy number is provided then the policy number used is that
#	registered for the Datacash account assigned to the username and password
#	profile.
#
#	url      - Datacash account URL
#	username - Datacash account username
#	password - Datacash account password
#	timeout  - request timeout
#	policy   - an integer, 0 to 7.  Default is "".
#
#	Returns a list either "OK" or {"ERR" $err_count}
#
proc ob::DCASH::set_up {
	 url
	 username
	 password
	 timeout
	{policy ""}
	{cvv2_needed 1}
} {

	variable INITIALISED
	variable DCASH_CFG

	if {!$INITIALISED} {init}

	catch {
		unset DCASH_CFG
	}

	ob_log::write INFO {set_up:url      = $url}
	ob_log::write INFO {set_up:username = $username}
	ob_log::write INFO {set_up:timeout  = $timeout}
	ob_log::write INFO {set_up:policy   = $policy}
	ob_log::write INFO {set_up:cvv2_needed = $cvv2_needed}

	set DCASH_CFG(url)      $url
	set DCASH_CFG(timeout)  $timeout
	set DCASH_CFG(client)   $username
	set DCASH_CFG(password) $password
	set DCASH_CFG(cvv2_needed)  $cvv2_needed

	set_policy $policy

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



# Set the DataCash policy number
#
#	policy_num - Datacash policy number to use
#
#	Returns a list either "OK" or {"ERR" $err_count}
#
proc ob::DCASH::set_policy {policy_num} {

	variable INITIALISED
	variable DCASH_CFG

	if {!$INITIALISED} {init}

	if {![regexp {^[0-9]$} $policy_num] && $policy_num != ""} {
		err_add "policy passed: $policy_num is not in \[0,7\].  Failing."
		return [list ERR 1]
	}

	set DCASH_CFG(policy) $policy_num

	return [list OK]
}

# Check the transaction and card details
#
#	Returns a list either "OK" or {"ERR" $err_count}
#
# ERROR CODES
#
#	PARAM_CARD_NUM  - card number is either missing or in the wrong format
#	PARAM_EXPIRY    - expiry is missing or in the wrong format
#	PARAM_STARTDATE - start date is in the wrong format
#	PARAM_ISSUE_NUM - issue number is in the wrong format
#	PARAM_NO_REF_NO - a unique reference number to identify the transaction is
#	                  missing
#	PARAM_TXN_TYPE  - transaction type is invalid, datacash transaction types
#	                  are auth, pre, refund cardaccountpayment and erp
#	PARAM_AMOUNT    - the amount is given in the wrong format
#	PARAM_NO_CCY    - currency is missing
#
proc ob::DCASH::_check {} {

	return [list OK]
	variable DCASH_DATA

	set err_count 0

	# Check card details
	if {![ob::card::check_format CARD_NO $DCASH_DATA(pan)]} {
		err_add "I dont like your card number: $DCASH_DATA(pan)"
		incr err_count
	}

	if {![ob::card::check_format EXPIRY $DCASH_DATA(expirydate)]} {
		err_add "This : $DCASH_DATA(expirydate) is not a valid expiry date"
		incr err_count
	}

	if {$DCASH_DATA(startdate) != ""} {
		if {![ob::card::check_format START $DCASH_DATA(startdate)]} {
			err_add "$DCASH_DATA(startdate) is a bad start date"
			incr err_count
		}
	}

	if {$DCASH_DATA(issuenumber) != ""} {
		if {![ob::card::check_format ISSUE $DCASH_DATA(issuenumber)]} {
			err_add "Faulty issue number: $DCASH_DATA(issuenumber)"
			incr err_count
		}
	}

	# Check transaction details
	if {[string trim [string length $DCASH_DATA(merchantreference)]] == 0} {
		err_add "No merchant reference number provided."
		incr err_count
	}

	# cardaccountpayment is used for BACS payment to Credit Card Collection Accounts
	if {[lsearch {auth pre refund erp cardaccountpayment} $DCASH_DATA(method)] == -1} {
		err_add \
			[append ignore \
				"Bad method: $DCASH_DATA(method) -- "\
				"should be one of auth,pre,refund,cardaccountpayment,erp"]
		incr err_count
	}

	if {![regexp {^([0-9]+)(\.([0-9]([0-9])?))?$} $DCASH_DATA(amount)]} {
		err_add "Failed to regexp $amount as money"
		incr err_count
	}

	if {[string trim [string length $DCASH_DATA(currency)]] == 0} {
		err_add "What currency is this supposed to be in?"
		incr err_count
	}

	if {[string length $DCASH_DATA(cardname)] > 18} {
		err_add \
			[append ignore \
				"Cardname $DCASH_DATA(cardname) can be maximum 18 "\
				"characters in length."]
		incr err_count
	}

	if {$err_count} {
		return [list ERR $err_count]
	}

	return [list OK]
}



# This function was not a part of the original OB5 implementation. Its purpose
# to make the use of this functionality as close as possible to the rest of the
# payment gateways.
#
#
# Extended to 3DS, but 3D enabled callers should set enable_3ds to 1
# legacy code should reply on the default to turn off 3d_secure processing
# N.B. enable_3ds does not imply that the payment will necessarily
#      use 3D secure. That depends on other factors as well.
proc ob::DCASH::make_call {ARRAY {enable_3ds 0}} {

	upvar $ARRAY PMT

	variable INITIALISED
	variable DCASH_STATUS_RESPONSE_TABLE

	if {!$INITIALISED} {init}

	# Datacash XML API can require the customers address and CVV2 number
	if {[set policy $PMT(policy_no)] != ""} {

		# Policy number requirements are listed in acct-dcash-xml.tcl but apart
		# from 4, we should have the address and CVV2 number.
		if {![string is digit $policy]} {
			ob_log::write ERROR {Bad Datacash Policy $policy ; should be 1-7}
			return [list 0 "Bad datacash policy given." PMT_ERR]
		}

		if {$policy != "4" && $PMT(cvv2) == ""} {
			ob_log::write ERROR \
				{No CVV2 number passed, but it is needed for policy $policy}
		}
	}

	# Payment gateway values
	# Note: not sure why the config parameter should override the db timeout val
	# also, policy should be in tPmtGateAcct
	ob::DCASH::set_up \
		$PMT(host) \
		$PMT(client) \
		$PMT(password) \
		[OT_CfgGet DCASH_TIMEOUT $PMT(resp_timeout)] \
		$PMT(policy_no) \
		$PMT(cvv2_needed)

	# If the rule does not have an associated transaction type
	# use D(deposit) or W(withdrawal)
	if {$PMT(pg_trans_type) == ""} {
		set PMT(pg_trans_type) $PMT(pay_sort)
	}

	set 3d_secure ""
	if {$enable_3ds} {

		# Pull out the 3D Secure paramaters from the 3D Secure array
		set 3d_secure [list]
		set prefix "3d_secure,"
		set prefix_len [string length $prefix]
		foreach {n v} [array get PMT "$prefix*"] {
			lappend 3d_secure [string range $n $prefix_len end]
			lappend 3d_secure $v
		}
	}

	if {![info exists PMT(gw_ret_code_ref)]} {
		set PMT(gw_ret_code_ref) ""
	}
	if {![info exists PMT(gw_uid_ref)]} {
		set PMT(gw_uid_ref) ""
	}

	foreach {status reason} [  \
		ob::DCASH::authorise   \
			$PMT(pg_trans_type)     \
			$PMT(apacs_ref)    \
			$PMT(amount)       \
			$PMT(ccy_code)     \
			$PMT(card_no)      \
			$PMT(expiry)       \
			$PMT(start)        \
			$PMT(issue_no)     \
			$PMT(addr_1)       \
			$PMT(addr_2)       \
			$PMT(addr_3)       \
			$PMT(addr_4)       \
			$PMT(postcode)     \
			$PMT(cvv2)         \
			$PMT(cardname)     \
			$PMT(gw_auth_code) \
			$PMT(gw_ret_code_ref) \
			$PMT(gw_uid_ref)   \
			$3d_secure] {
			break
		}

	if {$status != "OK"} {
		ob_log::write INFO {DCASH: Authorisation failed: $reason}
		if {$reason == "PMT_RESP"} {
			return PMT_RESP
		}
		return PMT_ERR
	}

	if {$enable_3ds && [info exists PMT(3d_secure)] && $PMT(3d_secure)} {
		#
		#  3D Secure processing - enrolement response parsing
		#
		#  Note whether to redirect and 3D secure liability information
		#  is returned in the return code

		set PMT(3d_secure,pareq) [get_resp_val pareq_message]
		set PMT(3d_secure,acs_url) [get_resp_val acs_url]
		#  We use the datacash reference as the 3d_secure reference
		#  Although it might be different for other gateways
		set PMT(3d_secure,ref) [ob::DCASH::get_resp_val datacash_reference]
		#   3D Secure scheme (verified by Visa / Master Card Secure Code etc)
		#   Return a code that represents the scheme
		set scheme [get_resp_val card_scheme]
		switch -- $scheme {
			VISA {set 3ds_scheme VBV}
			Mastercard {set 3ds_scheme MSC}
			default {set 3ds_scheme "DEF"}
		}

		set PMT(3d_secure,scheme) $3ds_scheme

		# retreive the datacash response code for the enrolment check
		set PMT(enrol_3d_resp)    [ob::DCASH::get_resp_val status]
	}

	set PMT(status)        [expr {
		[ob::DCASH::get_resp_val status] == 1 ? "Y" : "N"
	}]
	set PMT(auth_time)     [clock format \
		[clock seconds]\
		-format "%H:%M:%S"]
	set PMT(gw_ret_code)   [ob::DCASH::get_resp_val status]
	set PMT(gw_auth_code)  [ob::DCASH::get_resp_val reason]
	set PMT(gw_uid)        [ob::DCASH::get_resp_val datacash_reference]
	set PMT(auth_code)     [ob::DCASH::get_resp_val authcode]
	set PMT(card_type)     [ob::DCASH::get_resp_val card_scheme]
	set PMT(issuer)        [ob::DCASH::get_resp_val issuer]
	set PMT(country)       [ob::DCASH::get_resp_val country]
	set PMT(time)          [ob::DCASH::get_resp_val time]
	set PMT(cv2avs_status) [ob::DCASH::get_resp_val cv2avs_status]

	set PMT(gw_ret_msg)    [join [list \
		$PMT(gw_ret_code) \
		$PMT(auth_code) \
		$PMT(time) \
		$PMT(gw_uid) \
		$PMT(card_type) \
		$PMT(issuer) \
		$PMT(country)] :]

	set gw_ret_code PMT_ERR

	if {[info exists DCASH_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))]} {
		set gw_ret_code $DCASH_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))
	}

	# Payment declined is unfortunately mixed in with payment referred... and to
	# complicate things, different card issuers phrase referrals differently in
	# the response.
	# The pattern appears to be that for referrals, the auth code will be CALL
	# AUTH CENTRE or will begin with REFER
	#
	# This was the case with the pre-XML interface and remains the same.
	#
	# Note: it may be desirable to treat all declines as potentially referrable
	# - DCASHXML_DECL_IS_REFERRAL can be used to allow TBS operators to enter an
	# auth code regardless of the response.
	if {$gw_ret_code=="PMT_DECL"} {

		set test_str [string toupper $PMT(gw_auth_code)]
		if {[OT_CfgGet DCASHXML_DECL_IS_REFERRAL 0] \
		|| $test_str=="CALL AUTH CENTRE" \
		|| [string range $test_str 0 4] == "REFER"} {
			set gw_ret_code PMT_REFER
		}
	}

	return $gw_ret_code
}

# Authorise payment
#
#	trans_type   - (W)ithdrawal or (D)eposit or (E) - pre-auth withdrawal
#                  (C)redit - direct credit to credit card collection account
#	               (via BACS)
#	ref_no       - unique reference number
#	amount       - transaction amount
#	currency     - currency
#	card_number  - card number
#	expiry_date  - expiry date of card
#	start_date   - start date of card
#	issue_number - issue number of card
#	addr1        - customer address line 1 (defaults to "")
#	addr2        - customer address line 2 (defaults to "")
#	addr3        - customer address line 3 (defaults to "")
#	addr4        - customer address line 4 (defaults to "")
#	postcode     - postcode (defaults to "")
#	cv2          - CV2 (Card Verification Value) 3 or 4 digit number (defaults
#	               to "")
#	cardname     - name of credit card collection account, usually optional
#	authcode     - the auth code acquired from the bank (when authorising a
#	               referred payment - Telebet)
#   gw_ret_code_ref - Referal code.  Used to see if we need to make a 3ds referral 
#				   (indicated  by gw_ret_code_ref = 161)
#   gw_uid      - Reference for 3D secure referrals
#
# Returns a list, either {"OK" {$status $reason}} or {ERR $err_count}
#
#	INVALID_TRANS_TYPE - invalid transaction type, should be D,W,E or C
#
proc ob::DCASH::authorise {
	 trans_type
	 ref_no
	 amount
	 currency
	 card_number
	 expiry_date
	 start_date
	 issue_number
	{addr1         ""}
	{addr2         ""}
	{addr3         ""}
	{addr4         ""}
	{postcode      ""}
	{cv2           ""}
	{cardname      ""}
	{authcode      ""}
	{gw_ret_code_ref  ""}
	{gw_uid_ref    ""}
	{3d_secure_arr ""}
} {

	variable INITIALISED
	variable DCASH_DATA
	variable DCASH_CFG

	if {!$INITIALISED} {
		init
	}

	ob_log::write INFO {DCASH: DATACASH::authorise -- starting transaction}
	catch {unset DCASH_DATA}

	# Transaction details
	set msg_proc "_msg_pack"
	switch -- $trans_type {
		"D" {
			#  If it's a 3D Secure referral then do a 3Dsecure referral
			if {${gw_ret_code_ref} == 161} {
				set method "threedsecure_authorize_referral_request"
				set msg_proc "_msg_pack_3ds_referral"
				set DCASH_DATA(gw_uid_ref) $gw_uid_ref
			} else {
				set method "pre"
			}
		}
		"W" {
			set method "refund"
		}
		"E" {
			set method "erp"
		}
		"C" {
			set method "cardaccountpayment"
			set msg_proc "_msg_pack_dc"
			}
		default {
			err_add \
				"$trans_type is not a valid transaction type: W, E, D or C please"
			return [list ERR 1]
		}
	}

	set DCASH_DATA(method)            $method
	set DCASH_DATA(amount)            $amount
	set DCASH_DATA(currency)          $currency
	set DCASH_DATA(transactionsource) ecommerce

	# Datacash requires that the reference number is padded to 16 characters
	for {set i [string length $ref_no]} {$i < 16} {incr i 1} {
		set ref_no "0$ref_no"
	}
	set DCASH_DATA(merchantreference) $ref_no

	# CARD details
	set DCASH_DATA(pan)             $card_number
	set DCASH_DATA(expirydate)      $expiry_date
	set DCASH_DATA(startdate)       $start_date
	set DCASH_DATA(issuenumber)     $issue_number

	# CV2 details
	set DCASH_DATA(street_address1) $addr1
	set DCASH_DATA(street_address2) $addr2
	set DCASH_DATA(street_address3) $addr3
	set DCASH_DATA(street_address4) $addr4
	set DCASH_DATA(postcode)\
		[expr {
			[string length $postcode] <= 9 ? $postcode : ""
		}] ;# DataCash XML imposes a 9 character limit
	set DCASH_DATA(cv2)             $cv2

	# DirectCredit details
	set DCASH_DATA(cardname)        $cardname

	# When authorising a referral (Telebet mostly)
	set DCASH_DATA(authcode)        $authcode

	#  3D Secure details
	if {$3d_secure_arr==""} {
		set DCASH_DATA(3d_secure) 0
	} else {
		set DCASH_DATA(3d_secure) 1
		foreach {k v} $3d_secure_arr {
			set DCASH_DATA(3d_secure,$k) $v
		}
	}

	# Log values passed as input
	foreach name [info args ob::DCASH::authorise] {
		if {$name != "cv2" && $name != "card_number"} {
			ob_log::write INFO {DCASH::authorise -- $name [set $name]}
		} else {
			ob_log::write INFO {DCASH::authorise -- $name ********}
		}
	}

	# Check Datacash Arguments
	foreach {status ret} [_check] {
		if {$status == "ERR"} {
			ob_log::write WARN {DCASH::authorise: _check failed: $ret}
			return [list ERR $ret]
		}
	}

	# Pack the message -- for Direct Credit we use _msg_pack_dc
	foreach {status request} [$msg_proc] {
		if {$status == "ERR"} {
			ob_log::write WARN {DCASH::authorise: _msg_pack failed: $request}
			return [list ERR $request]
		}
	}

	# Send the message (and close the socket?)
	foreach {status response} [_msg_send $request] {
		if {$status == "ERR"} {
			ob_log::write WARN {DCASH::authorise: _msg_send failed: $response}
			return [list ERR $response]
		}
	}

	# Unpack the message
	foreach {status ret} [_msg_unpack $response] {
		if {$status == "ERR"} {
			ob_log::write WARN {DCASH::authorise: _msg_unpack failed: $ret}
			return [list ERR $ret]
		}
	}

	ob_log::write WARN {DCASH::authorise -- finished successfully}

	return [list OK]
}


##
#  Helper function to create an element with a text node underneath
#
#
proc ob::DCASH::_append_text_element {doc parent_node name text {lattr ""}} {
	set elem [$doc createElement $name]
	set new_node [$parent_node appendChild $elem]
	foreach {n v} $lattr {
		$new_node setAttribute $n $v
	}
	set text_el [$doc createTextNode $text]
	set txt_node [$new_node appendChild $text_el]
	return $txt_node
}

##
#  Helper function to append an Element
proc ob::DCASH::_append_element {doc parent_node el_name {lattr ""}} {
	set elem [$doc createElement $el_name]
	set new_node [$parent_node appendChild $elem]
	foreach {n v} $lattr {
		$new_node setAttribute $n $v
	}
	return $new_node
}



# Pack XML request
#
# returns list, either "OK" or {"ERR" $err_count}
#
proc ob::DCASH::_msg_pack {} {

	variable DCASH_CFG
	variable DCASH_DATA
	variable DCASH_REQUIRE_CV2

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#   |--Transaction
	#     |--TxnDetails
	#     | |--?merchantreference
	#     | |--?amount
	#     | |--?transactionsource
	#     | |--?Order
	#     | |--?ThreeDSecure
	#     |   |--verify
	#     |   |--merchant_url
	#     |   |--purchase_desc
	#     |   |--Browser
	#     |     |--device_category
	#     |     |--accept_headers
	#     |     |--user_agent
	#     |--CardTxn
	#       |--Card
	#       | |--pan - credit card number on the face of the card
	#       | |--expirydate
	#       | |--?startdate
	#       | |--?issuenumber
	#       | |--?Cv2Avs
	#       |   |--?policy
	#       |   |--?street_address1
	#       |   |--?street_address2
	#       |   |--?street_address3
	#       |   |--?street_address4
	#       |   |--?postcode
	#       |   |--?cv2
	#       |
	#       |--method enum(auth,pre,refund,erp,cardaccountpayment)
	#
	#

	dom setResultEncoding "UTF-8"

	# Request
	set DCASH_MSG [dom createDocument "Request"]
	set request   [$DCASH_MSG documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth   [$DCASH_MSG createElement "Authentication"]
	set B_auth   [$request   appendChild $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach auth_item {
		client
		password
	} {
		set elem [$DCASH_MSG createElement  $auth_item]
		set brch [$B_auth    appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_CFG($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_MSG createElement  "Transaction"]
	set B_trans  [$request   appendChild    $E_trans]

	# Request/Transaction/TxnDetails
	set E_txndt  [$DCASH_MSG createElement  "TxnDetails"]
	set B_txndt  [$B_trans   appendChild    $E_txndt]

	# Request/Transaction/TxnDetails/merchantreference
	# Request/Transaction/TxnDetails/amount
	# Request/Transaction/TxnDetails/transactionsource
	foreach txn_item {
		merchantreference
		amount
		transactionsource
	} {
		set elem [$DCASH_MSG createElement  $txn_item]
		set brch [$B_txndt   appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_DATA($txn_item)]
		if {$txn_item == "amount"} {
			$brch setAttribute "currency" $DCASH_DATA(currency)
		}
		$brch appendChild $txtn
	}

	# 3D Secure Elements
	if {$DCASH_DATA(3d_secure) && $DCASH_DATA(3d_secure,call_type)=="enrol"} {
		set B_3dsec [_append_element $DCASH_MSG $B_txndt "ThreeDSecure"]
		if {$DCASH_DATA(3d_secure,policy,bypass_verify)} {
			_append_text_element $DCASH_MSG $B_3dsec "verify" "no"
		} else {
			_append_text_element $DCASH_MSG $B_3dsec "verify" "yes"
			_append_text_element $DCASH_MSG $B_3dsec "merchant_url" $DCASH_DATA(3d_secure,merchant_url)
			_append_text_element $DCASH_MSG $B_3dsec "purchase_desc" $DCASH_DATA(3d_secure,purchase_desc)
			_append_text_element $DCASH_MSG $B_3dsec "purchase_datetime" [clock format [clock seconds] -format "%Y%m%d %H:%M:%S"]

			set B_3dsecBrwr [_append_element $DCASH_MSG $B_3dsec "Browser"]
			_append_text_element $DCASH_MSG $B_3dsecBrwr "device_category" $DCASH_DATA(3d_secure,browser,device_category)
			_append_text_element $DCASH_MSG $B_3dsecBrwr "accept_headers" $DCASH_DATA(3d_secure,browser,accept_headers)
			_append_text_element $DCASH_MSG $B_3dsecBrwr "user_agent" $DCASH_DATA(3d_secure,browser,user_agent)
		}
	}
	# Request/Transaction/CardTxn
	set E_cdtxn  [$DCASH_MSG createElement  "CardTxn"]
	set B_cdtxn  [$B_trans   appendChild    $E_cdtxn]

	# Request/Transaction/CardTxn/authcode
	# only present if we are authorising a referred payment
	if {$DCASH_DATA(authcode) != ""} {
		set E_authcode [$DCASH_MSG createElement "authcode"]
		set B_authcode [$B_cdtxn   appendChild $E_authcode]
		set T_authcode [$DCASH_MSG createTextNode $DCASH_DATA(authcode)]
		$B_authcode appendChild	$T_authcode
	}

	# Request/Transaction/CardTxn/method
	set E_mthd   [$DCASH_MSG createElement  "method"]
	set B_mthd   [$B_cdtxn   appendChild    $E_mthd]
	set T_mthd   [$DCASH_MSG createTextNode $DCASH_DATA(method)]
	$B_mthd appendChild $T_mthd

	# Request/Transaction/CardTxn/Card
	set E_card   [$DCASH_MSG createElement  "Card"]
	set B_card   [$B_cdtxn   appendChild    $E_card]

	# Request/Transaction/CardTxn/Card/pan
	# Request/Transaction/CardTxn/Card/expirydate
	# Request/Transaction/CardTxn/Card/startdate
	# Request/Transaction/CardTxn/Card/issuenumber
	foreach card_item {
		pan
		expirydate
		startdate
		issuenumber
	} {

		if {$DCASH_DATA($card_item) != ""} {

			set elem [$DCASH_MSG createElement  $card_item]
			set brch [$B_card    appendChild    $elem]
			set txtn [$DCASH_MSG createTextNode $DCASH_DATA($card_item)]
			$brch appendChild $txtn
		}
	}

	# Request/Transaction/CardTxn/Card/Cv2Avs
	set E_cvav   [$DCASH_MSG createElement  "Cv2Avs"]
	set B_cvav   [$B_card    appendChild    $E_cvav]

	# Request/Transaction/CardTxn/Card/Cv2Avs/policy

	# If DCASH has been configured to use the default party then do not add a
	# policy field. An error is returned by DATCASH if a policy of 0 is passed
	# over.
	if {$DCASH_CFG(policy) != "" &&
		0 <= $DCASH_CFG(policy) && $DCASH_CFG(policy) <= 7} {
		set E_policy [$DCASH_MSG createElement  "policy"]
		set B_policy [$B_cvav    appendChild    $E_policy]
		set T_policy [$DCASH_MSG createTextNode $DCASH_CFG(policy)]
		$B_policy appendChild $T_policy
	}

	# AVS
	# Request/Transaction/CardTxn/Card/Cv2Avs/street_address1
	# Request/Transaction/CardTxn/Card/Cv2Avs/street_address2
	# Request/Transaction/CardTxn/Card/Cv2Avs/street_address3
	# Request/Transaction/CardTxn/Card/Cv2Avs/street_address4
	# Request/Transaction/CardTxn/Cpard/Cv2Avs/postcode

	# CV2
	# Request/Transaction/CardTxn/Card/Cv2Avs/cv2
	if {$DCASH_CFG(cvv2_needed)} {

		foreach check_item {
			street_address1
			street_address2
			street_address3
			street_address4
			postcode
			cv2
		} {
			set elem [$DCASH_MSG createElement  $check_item]
			set brch [$B_cvav    appendChild    $elem]

			if {$DCASH_DATA($check_item) != ""} {
				set txtn [$DCASH_MSG createTextNode $DCASH_DATA($check_item)]
				$brch appendChild $txtn
			}
		}
	}

	set xml_msg [$request asXML]

	$DCASH_MSG delete

	return [list OK "<?xml version=\"1.0\" encoding=\"UTF-8\"?> $xml_msg"]
}



# We need a second version for Direct Credit
#
# In an ideal world it would have been easy to modify the above to handle more
# than one message type, but the original author appears to have made the
# decision to only support one message type
#
proc ob::DCASH::_msg_pack_dc {} {

	variable DCASH_CFG
	variable DCASH_DATA

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#   |--Transaction
	#     |--TxnDetails
	#     | |--merchantreference
	#     | |--amount
	#     |
	#     |--DirectCreditTxn
	#       |--method (cardaccountpayment)
	#       | |--pan - credit card number on the face of the card
	#       | |--?expirydate
	#       | |--?cardname
	#
	#

	dom setResultEncoding "UTF-8"

	# Request
	set DCASH_MSG [dom createDocument "Request"]
	set request   [$DCASH_MSG documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth   [$DCASH_MSG createElement "Authentication"]
	set B_auth   [$request   appendChild $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach auth_item {
		client
		password
	} {
		set elem [$DCASH_MSG createElement  $auth_item]
		set brch [$B_auth    appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_CFG($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_MSG createElement  "Transaction"]
	set B_trans  [$request   appendChild    $E_trans]

	# Request/Transaction/TxnDetails
	set E_txndt  [$DCASH_MSG createElement  "TxnDetails"]
	set B_txndt  [$B_trans   appendChild    $E_txndt]

	# Request/Transaction/TxnDetails/merchantreference
	# Request/Transaction/TxnDetails/amount
	# Request/Transaction/TxnDetails/transactionsource
	foreach txn_item {
		merchantreference
		amount
	} {
		set elem [$DCASH_MSG createElement  $txn_item]
		set brch [$B_txndt   appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_DATA($txn_item)]
		if {$txn_item == "amount"} {
			$brch setAttribute "currency" $DCASH_DATA(currency)
		}
		$brch appendChild $txtn
	}

	# Request/Transaction/DirectCreditTxn
	set E_dctxn  [$DCASH_MSG createElement  "DirectCreditTxn"]
	set B_dctxn  [$B_trans   appendChild    $E_dctxn]

	# Request/Transaction/DirectCreditTxn/method
	set E_mthd   [$DCASH_MSG createElement  "method"]
	set B_mthd   [$B_dctxn   appendChild    $E_mthd]
	set T_mthd   [$DCASH_MSG createTextNode $DCASH_DATA(method)]
	$B_mthd appendChild $T_mthd

	# Request/Transaction/DirectCreditTxn/pan
	# Request/Transaction/DirectCreditTxn/expirydate
	# Request/Transaction/DirectCreditTxn/cardname
	foreach dc_item {
		pan
		expirydate
		cardname
	} {

		if {$DCASH_DATA($dc_item) != ""} {
			set elem [$DCASH_MSG createElement  $dc_item]
			set brch [$B_dctxn    appendChild    $elem]
			set txtn [$DCASH_MSG createTextNode $DCASH_DATA($dc_item)]
			$brch appendChild $txtn
		}
	}

	set xml_msg [$request asXML]

	$DCASH_MSG delete

	return [list OK "<?xml version=\"1.0\" encoding=\"UTF-8\"?> $xml_msg"]
}


# This one is for re-submitting 161s (3DS referrals)
#
proc ob::DCASH::_msg_pack_3ds_referral {} {

	variable DCASH_CFG
	variable DCASH_DATA

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#   |--Transaction
	#     |--HistoricTxn
	#     | |--reference
	#     | |--auth_code
	#     | |--method = threedsecure_authorize_referral_request
	#

	dom setResultEncoding "UTF-8"

	# Request
	set DCASH_MSG [dom createDocument "Request"]
	set request   [$DCASH_MSG documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth   [$DCASH_MSG createElement "Authentication"]
	set B_auth   [$request   appendChild $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach auth_item {
		client
		password
	} {
		set elem [$DCASH_MSG createElement  $auth_item]
		set brch [$B_auth    appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_CFG($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_MSG createElement  "Transaction"]
	set B_trans  [$request   appendChild    $E_trans]

	# Request/Transaction/HistoricTxn
	set E_histtxn  [$DCASH_MSG createElement  "HistoricTxn"]
	set B_histtxn  [$B_trans   appendChild    $E_histtxn]

	# Request/Transaction/HistoricTxn/reference
	set E_refr   [$DCASH_MSG createElement  "reference"]
	set B_refr   [$B_histtxn appendChild    $E_refr]
	set T_refr   [$DCASH_MSG createTextNode $DCASH_DATA(gw_uid_ref)]

	$B_refr appendChild $T_refr

	# Request/Transaction/HistoricTxn/auth_code
	set E_auth   [$DCASH_MSG createElement  "authcode"]
	set B_auth   [$B_histtxn appendChild    $E_auth]
	set T_auth   [$DCASH_MSG createTextNode $DCASH_DATA(authcode)]
	$B_auth appendChild $T_auth

	# Request/Transaction/HistoricTxn/method
	set E_mthd   [$DCASH_MSG createElement  "method"]
	set B_mthd   [$B_histtxn appendChild    $E_mthd]
	set T_mthd   [$DCASH_MSG createTextNode $DCASH_DATA(method)]
	$B_mthd appendChild $T_mthd


	set xml_msg [$request asXML]

	$DCASH_MSG delete

	return [list OK "<?xml version=\"1.0\" encoding=\"UTF-8\"?> $xml_msg"]
}

##
#
# ob::DCASH::auth_3D_secure
# Authenticates a message previously submitted with 3D Secure
# Takes in a PMT array defined in paymentCC.tcl
#
proc ob::DCASH::make_call_3ds_auth {ARRAY} {
	variable DCASH_CFG
	upvar $ARRAY PMT

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#   |--Transaction
	#     |--HistoricTxn
	#     | |--reference
	#     | |--method
	#     | |--?pares_message

	####
	# Check the array

	# Currently only one element but leave it easy to expand later
	set err_count 0
	foreach k {3d_secure,ref} {
		if {![info exists PMT($k)]} {
			err_add "ob::DCASH::auth_3d_secure PMT($k) must be specified"
			incr err_count
		} elseif {$PMT($k)==""} {
			err_add "ob::DCASH::auth_3d_secure PMT($k) must be specified"
			incr err_count
		}
	}
	## Currently ref is a sequence of digits
	if {![regexp {^[\d]*$} $PMT(3d_secure,ref)]} {
		err_add "ob::DCASH::auth_3d_secure PMT(3d_secure,ref)=$PMT(3d_secure,ref) should be a sequence of digits"
		incr err_count
	}

	# payment gateway values
	# Note: not sure why the config parameter should override the db timeout val
	# also, policy should be in tPmtGateAcct
	ob::DCASH::set_up $PMT(host) $PMT(client) \
					$PMT(password) \
					[OT_CfgGet DCASH_TIMEOUT $PMT(resp_timeout)] \
					[OT_CfgGet DCASH_POLICY ""]

	####
	#  Build the message

	set DCASH_MSG [dom createDocument "Request"]
	set request   [$DCASH_MSG documentElement]
	set B_auth [_append_element $DCASH_MSG $request Authentication]
	_append_text_element $DCASH_MSG $B_auth "client" $DCASH_CFG(client)
	_append_text_element $DCASH_MSG $B_auth "password" $DCASH_CFG(password)

	set B_Tran [_append_element $DCASH_MSG $request "Transaction"]
	set B_HistTran [_append_element $DCASH_MSG $B_Tran "HistoricTxn"]

	#  3d_secure parameters
	if {[info exists PMT(3d_secure)] && $PMT(3d_secure)} {

		_append_text_element $DCASH_MSG $B_HistTran reference $PMT(3d_secure,ref)
		_append_text_element $DCASH_MSG $B_HistTran method "threedsecure_authorization_request" {"tx_status_u" "accept"}

		if {[info exists PMT(3d_secure,pares)] && $PMT(3d_secure,pares)!=""} {
			set txt_node [_append_text_element $DCASH_MSG $B_HistTran "pares_message" $PMT(3d_secure,pares)]
		}
	}

	## generate the xml
	set request "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	append request [$DCASH_MSG asXML]


	####
	#  Send the message (and close the socket?)
	foreach {status response} [_msg_send $request] {
		if {$status == "ERR"} {
			ob_log::write ERROR {DCASH::3d_secure_auth: _msg_send failed: $response}
			return [list ERR $response]
		}
	}

	####
	#
	# Unpack the message
	# We can use the standard unpack mechanism here
	foreach {status code} [_msg_unpack $response] {
		if {$status == "ERR"} {
			ob_log::write ERROR {DCASH::3d_secure_auth: _msg_unpack failed: $response}
			return [list ERR $response]
		}
	}

	set gw_ret_code [_pack_pmt_array PMT]

	return [list $gw_ret_code]
}


proc ob::DCASH::_pack_pmt_array {PMT_ARR} {
	upvar 1 $PMT_ARR PMT
	variable INITIALISED
	variable DCASH_STATUS_RESPONSE_TABLE
	if {!$INITIALISED} {init}
	set gw_ret_code PMT_ERR

	set PMT(status) [expr {[ob::DCASH::get_resp_val status] == 1 ?\
								"Y" : "N"}]
	set PMT(auth_time) [clock format [clock seconds] -format "%H:%M:%S"]
	set PMT(gw_ret_code)    [ob::DCASH::get_resp_val status]
	set PMT(gw_auth_code)   [ob::DCASH::get_resp_val reason]
	set PMT(gw_uid)         [ob::DCASH::get_resp_val datacash_reference]
	set PMT(auth_code)      [ob::DCASH::get_resp_val authcode]
	set PMT(card_type)      [ob::DCASH::get_resp_val card_scheme]
	set PMT(issuer)         [ob::DCASH::get_resp_val issuer]
	set PMT(country)        [ob::DCASH::get_resp_val country]
	set PMT(time)           [ob::DCASH::get_resp_val time]
	set PMT(cv2avs_status)  [ob::DCASH::get_resp_val cv2avs_status]

	# retreive the datacash response code for the enrolment check
	set PMT(auth_3d_resp)  $PMT(gw_ret_code)

    set PMT(gw_ret_msg)     [join [list \
							       $PMT(gw_ret_code) \
							       $PMT(auth_code) \
							       $PMT(time) \
							       $PMT(gw_uid) \
							       $PMT(card_type) \
							       $PMT(issuer) \
							       $PMT(country) ] :]


	#  Some of these relate to 3D Secure, see the payment gateway page for more
	#  info
	if {[info exists DCASH_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))]} {
		set gw_ret_code $DCASH_STATUS_RESPONSE_TABLE($PMT(gw_ret_code))
	}

	#
	# Payment declined is unfortunately mixed in with
	# payment referred... and to complicate things, different
	# card issuers phrase referrals differently in the response.
	# The pattern appears to be that for referrals, the auth code
	# will be CALL AUTH CENTRE or will begin with REFER
	#
	# This was the case with the pre-XML interface and remains the
	# same.
	#
	# Note: it may be desirable to treat all declines as potentially
	# referrable - DCASHXML_DECL_IS_REFERRAL can be used to allow TBS
	# operators to enter an auth code regardless of the response.
	#
	if {$gw_ret_code=="PMT_DECL"} {
		set test_str [string toupper $PMT(gw_auth_code)]
		if {[OT_CfgGet DCASHXML_DECL_IS_REFERRAL 0] \
		|| $test_str=="CALL AUTH CENTRE" \
		|| [string range $test_str 0 4] == "REFER"} {
			set gw_ret_code PMT_REFER
		}
	}
	return $gw_ret_code
}


#
#  Helper function to get the value of a text node
#  by the xpath location of it's enclosing element
#  Optionally can specify a default if the eclosing element
#  does not exist. An empty element will return the empty string
#  if the enclosing element is not found then the default, if specified,
#  is returned, else an error is returned.
#  e.g.
proc get_el_text {ctxt_node xpath_exp {default __NONE__}} {
	set lnode [$ctxt_node selectNodes $xpath_exp type]
	if {$type != "nodes"} {
		if {$type == "empty"} {
			if {$default == "__NONE__"} {
	            error "ob::DCASH::get_el_text: xpath returns no node and no default is specified"
			} else {
	            return $default
    	    }
		} else {
			error "ob::DCASH::get_el_text: result of xpath isn't a node type=$type"
		}
	}
	set ret ""
	foreach nd $lnode {
		set txt [$nd text]
		if {$txt != ""} {
			append ret [$nd text]
		}
	}

	return $ret
}


# Unpack XML response to namespace variable
#
#	xml - XML to unpack
#
# Returns list, either "OK" or {"ERR" $err_code}
#
# Error codes
#
#	XML_FORMAT - cannot parse XML format
#	MSG_FORMAT - invalid message
#
proc ob::DCASH::_msg_unpack {xml} {

	variable DCASH_RESP
	variable DCASH_REQUIRE_CV2
	variable DCASH_CFG

	if {[catch {
		set doc      [dom parse $xml]
		set Response [$doc documentElement]
	} msg]} {
		err_add "Unrecognized xml format. Message is:\n $xml "
		return [list ERR PMT_RESP]
	}

	foreach element [split [$Response asXML] "\n"] {
		lappend xml_msg [string trim $element]
	}

	set DCASH_RESP(Response) [join $xml_msg]

	# Request/status
	# Request/reason
	if {[catch {
		foreach item {
			status
			reason
		} {
			set DCASH_RESP($item) [[[$Response getElementsByTagName $item]\
				firstChild]\
				nodeValue]
		}
	} msg]} {
		# These elements are compulsory, so if they fail
		# the entire message is pretty useless!
		err_add "Bad XML format.  Message is \n [$Response asXML]"
		return [list ERR PMT_RESP]
	}

	# Request/information        (optional)
	# Request/merchantreference  (optional)
	# Request/datacash_reference (optional)
	# Request/time               (optional)
	# Request/mode               (optional)

	foreach item {
		information
		merchantreference
		datacash_reference
		time
		mode
	} {
		if {[catch {
			set DCASH_RESP($item) [[[$Response getElementsByTagName $item]\
				firstChild]\
				nodeValue]
		}]} {
			set DCASH_RESP($item) ""
		}
	}

	# Request/CardTxn/card_scheme (optional)
	# Request/CardTxn/country     (optional)
	# Request/CardTxn/issuer      (optional)
	# Request/CardTxn/authcode    (optional)

	set CardTxn [$Response getElementsByTagName "CardTxn"]

	foreach item {
		card_scheme
		country
		issuer
		authcode
	} {
		if {[catch {
			set DCASH_RESP($item) [[[$CardTxn getElementsByTagName $item]\
				firstChild]\
				nodeValue]
		}]} {
			set DCASH_RESP($item) ""
		}
	}

	# Request/CardTxn/EbitGuard/orderid
	# Request/CardTxn/EbitGuard/fraud_status
	catch {set EbitGuard [$CardTxn getElementsByTagName "EbitGuard"]}
	foreach item {
		orderid
		fraud_status
	} {
		if {[catch {
			set DCASH_RESP($item) [[[$EbitGuard getElementsByTagName $item]\
				firstChild]\
				nodeValue]

		}]} {
			set DCASH_RESP($item) ""
		}
	}

	catch {set fraud_status [$EbitGuard getElementsByTagName fraud_status]}

	# Request/CardTxn/EbitGuard/fraud_status attribute score
	# Request/CardTxn/EbitGuard/fraud_status attribute reversal
	foreach item {
		score
		reversal
	} {
		if {[catch {
			set DCASH_RESP(fraud_status,$item) [$fraud_status getAttribute $item]
		}]} {
			set DCASH_RESP(fraud_status,$item) ""
		}
	}

	if {$DCASH_CFG(cvv2_needed)} {

		# Request/CardTxn/Cv2Avs/policy
		# Request/CardTxn/Cv2Avs/cv2avs_status
		catch {
			set Cv2Avs [$CardTxn getElementsByTagName "Cv2Avs"]
		}
		foreach item {
			policy
			cv2avs_status
		} {
			if {[catch {
				set DCASH_RESP($item) [[[$Cv2Avs getElementsByTagName $item]\
					firstChild]\
					nodeValue]
			}]} {
				set DCASH_RESP($item) ""
			}
		}

	} else {

		set DCASH_RESP(policy) ""
		set DCASH_RESP(cv2avs_status) ""
	}
	#  3D Secure processing
	set DCASH_RESP(pareq_message) [get_el_text $Response "/Response/CardTxn/ThreeDSecure/pareq_message" ""]
	set DCASH_RESP(acs_url) [get_el_text $Response "/Response/CardTxn/ThreeDSecure/acs_url" ""]

	$doc delete

	ob_log::write INFO \
		{DCASH: _msg_unpack:Response           = $DCASH_RESP(Response)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:reason             = $DCASH_RESP(reason)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:status             = $DCASH_RESP(status)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:information        = $DCASH_RESP(information)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:merchantreference  = $DCASH_RESP(merchantreference)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:datacash_reference = $DCASH_RESP(datacash_reference)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:time               = $DCASH_RESP(time)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:mode               = $DCASH_RESP(mode)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:card_scheme        = $DCASH_RESP(card_scheme)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:country            = $DCASH_RESP(country)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:issuer             = $DCASH_RESP(issuer)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:authcode           = $DCASH_RESP(authcode)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:orderid            = $DCASH_RESP(orderid)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:fraud_status       = $DCASH_RESP(fraud_status)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:reversal           = $DCASH_RESP(fraud_status,reversal)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:score              = $DCASH_RESP(fraud_status,score)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:policy             = $DCASH_RESP(policy)}
	ob_log::write INFO \
		{DCASH: _msg_unpack:cv2avs_status      = $DCASH_RESP(cv2avs_status)}

	set DCASH_REQUIRE_CV2 [OT_CfgGet DCASH_REQUIRE_CV2 0]

	return [list OK]
}



# Send message to Datacash and retrieve response
#
#	request - XML request to send
#
#	Returns list, either "OK" or {"ERR" $err_code}
#
proc ob::DCASH::_msg_send {request} {

	variable DCASH_CFG
	variable DCASH_RESP

	catch {
		unset DCASH_RESP
	}

	#! UTF-8 encoding - the nuclear option
	#
	# Strips any non-ASCII characters - this is unfortunately the only option
	# available to us as we cannot work out what character encoding the data is
	# in (eg, if the request is from the portal, it may be in the user's language
	# encoding - but if it came from OXi XML, it may already be in UTF-8)
	if {[regexp {[^\n\040-\176]} $request]} {
		set count [regsub -all {[^\n\040-\176]} $request {} request]
		ob_log::write WARN \
			{DCASH: Warning: stripped $count non-ASCII character(s) from request}
	}

	ob_log::write INFO {DCASH: _msg_send: REQUEST: attempting send}
	set startTime [OT_MicroTime -micro]

	# Figure out where we need to connect to for this URL.
	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $DCASH_CFG(url)] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {_msg_send: Badly formatted url: $msg}
		return [list ERR PMT_REQ_NOT_MADE]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set http_req [ob_socket::format_http_req \
						-method     "POST" \
						-host       $api_host \
						-post_data  $request \
						$DCASH_CFG(url)]
	} msg]} {
		ob_log::write ERROR {_msg_send: Unable to build request: $msg}
		return [list ERR PMT_REQ_NOT_MADE]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	set tls [expr {$api_scheme == "http" ? -1 : ""}]

	# Send the request to Datacash.
	# NB: We're potentially doubling the timeout by using it as
	# both the connect and request timeout.
	if {[catch {
			foreach {req_id status complete} \
			[::ob_socket::send_req \
				-tls          $tls \
				-is_http      1 \
				-conn_timeout $DCASH_CFG(timeout) \
				-req_timeout  $DCASH_CFG(timeout) \
				$http_req \
				$api_host \
				$api_port] {break}
	} msg]} {
			# We can't be sure if anything reached the server or not.
			ob_log::write ERROR {_msg_send: Request to DCASH failed: $msg}
			return [list ERR PMT_RESP]
	}

	set totalTime [format "%.2f" [expr {[OT_MicroTime -micro] - $startTime}]]
	ob_log::write INFO {DCASH: _msg_send: status=$status, Req Time=$totalTime seconds}

	if {$status != "OK"} {
		#
		# Distinguish between circumstances where req definitely wasn't made, and where it may have been.
		#
		if {[::ob_socket::server_processed $req_id] == 0} {
			# There's no way the server could have processed the request
			ob_log::write ERROR {_msg_send: req status was $status, there's no way request reached DCASH}
			set ret [list ERR PMT_REQ_NOT_MADE]
		} else {
			# Request may or may not have reached Datacash, we don't know if it
			# was processed or not.  Return status so it can be handled appropriately
			ob_log::write ERROR {_msg_send: req status was $status, the request may have reached DCASH}
			set ret [list ERR PMT_RESP]
		}

		# clean up
		::ob_socket::clear_req $req_id


		return $ret
	}

	# retrieve the XML response
	set xml_resp [::ob_socket::req_info $req_id http_body]

	# clean up after ourselves
	::ob_socket::clear_req $req_id

	ob_log::write INFO {_msg_send: RESPONSE: $xml_resp}

	return [list OK $xml_resp]
}



# Get response value
#
#	name - identifier for value
#
#	Returns value from response or "" if value not found
#
proc ob::DCASH::get_resp_val {name} {

	variable INITIALISED
	variable DCASH_RESP

	if {!$INITIALISED} {
		init
	}

	if {[info exists DCASH_RESP($name)]} {
		return $DCASH_RESP($name)
	}

	ob_log::write WARN {DCASH: DCASH_RESP($name) does not exist}
	return ""
}



# Settle transaction
#
#	trans_type - (W)ithdrawal or (D)eposit
#	amount     - transaction amount
#	auth_code  - the authcode of the original transaction
#   reference  - the unique reference of the original transaction
#
#	Returns list, either {"OK"  {$status $reason}} or {"ERR" $err_count}
#
#	Error codes
#		INVALID_TRANS_TYPE - invalid transaction type, should be D or W
#
proc ob::DCASH::settle {
	transaction_type
	amount
	auth_code
	reference
	{client ""}
	{password ""}
} {

	variable INITIALISED
	variable DCASH_DATA
	variable DCASH_CFG

	if {!$INITIALISED} {init}

	catch {unset DCASH_DATA}

	# if a payment was an ERP we need to make sure it goes through
	# the same gateway for the fulfilment
	if {$client != ""} {
		set DCASH_CFG(client) $client
	}

	if {$password != ""} {
		set DCASH_CFG(password) $password
	}

	if {[regexp {^\s*$} $transaction_type]} {

		err_add "No transaction_type passed ($transaction_type)"
		return [list ERR 1]
	}

	if {[regexp {^\s*$} $amount]} {

		err_add "No amount passed ($amount)"
		return [list ERR 1]
	}

	if {[regexp {^\s*$} $auth_code]} {

		err_add "No auth_code passed ($auth_code)"
		return [list ERR 1]
	}

	if {[regexp {^\s*$} $reference]} {

		err_add "No reference passed ($reference)"
		return [list ERR 1]
	}

	# Transaction details
	# exactly what is the point of this?  method is overridden below!
	switch -- $transaction_type {
		"D" {set method pre}
		"W" {set method refund}
		"E" {set method erp}
		"C" {
			  set method "cardaccountpayment"
			  set msg_proc "_msg_pack_dc"
			}
		default {
			err_add "Invalid transaction_type $transaction_type : W or D please"
			return [list ERR 1]
		}
	}

	set DCASH_DATA(method)     	"fulfill"
	set DCASH_DATA(amount)      $amount
	set DCASH_DATA(authcode)   	$auth_code
	set DCASH_DATA(reference)	$reference

	# Check Datacash Arguments

	# Pack the message
	foreach {status request} [_settle_msg_pack] {
		if {$status == "ERR"} {
			return [list ERR $request]
		}
	}

	# Send the message (and close the socket?)
	foreach {status response} [_msg_send $request] {
		if {$status == "ERR"} {
			return [list ERR $response]
		}
	}

	# Unpack the message
	foreach {status ret} [_msg_unpack $response] {
		if {$status == "ERR"} {
			return [list ERR $ret]
		}
	}

	return [list OK]
}



# Builds the XML request that is required to settle a prepayment with datacash
#
# Returns list, either "OK" or {"ERR" $err_count}
#
proc ob::DCASH::_settle_msg_pack {} {

	variable DCASH_CFG
	variable DCASH_DATA

	# The following request structure is required
	# to settle a transaction.
	#
	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |--Transaction
	#   | |--TxnDetails
	#     | |--?amount
	#     |--HistoricTxn
	#       |--method
	#       |--authcode
	#       |--reference
	#

	dom setResultEncoding "UTF-8"

	# Request
	set DCASH_MSG [dom createDocument "Request"]
	set request   [$DCASH_MSG documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth   [$DCASH_MSG createElement "Authentication"]
	set B_auth   [$request   appendChild $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach auth_item {
		client
		password
	} {
		set elem [$DCASH_MSG createElement  $auth_item]
		set brch [$B_auth    appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_CFG($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_MSG createElement  "Transaction"]
	set B_trans  [$request   appendChild    $E_trans]

	# Request/Transaction/HistoricTxn
	set E_historicTxn  [$DCASH_MSG createElement  "HistoricTxn"]
	set B_historicTxn  [$B_trans   appendChild    $E_historicTxn]

	# Request/Transaction/HistoricTxn/method
	# Request/Transaction/HistoricTxn/authcode
	# Request/Transaction/HistoricTxn/reference
	foreach txn_item {
		method
		authcode
		reference
	} {
		set elem [$DCASH_MSG createElement  $txn_item]
		set brch [$B_historicTxn   appendChild    $elem]
		set txtn [$DCASH_MSG createTextNode $DCASH_DATA($txn_item)]
		$brch appendChild $txtn
	}

	ob_log::write DEBUG {DCASH: _msg_pack: [$request asXML]}

	set xml_msg [$request asXML]

	$DCASH_MSG delete

	return [list OK "<?xml version=\"1.0\" encoding=\"UTF-8\"?> $xml_msg"]
}



# Assign whether CVV2 code is required
#
#	require - boolean
#
proc ob::DCASH::set_require_cvv2 {require} {

	variable DCASH_REQUIRE_CV2 $require
}
