# $Id: metacharge.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Metacharge Payment Gateway
#
# Procedures:
#    mcharge::init                   - one time initialisation
#    mcharge::make_metacharge_call   - main public function
#    mcharge::_translate_card_type   - convert to a metacharge card code
#    mcharge::_payment               - do initial payment or repeat payment
#    mcharge::_payment_request       - build up a 'payment request' string
#    mcharge::_repeat_request        - build up 'repeat payment request' string
#    mcharge::_refund                - do a refund
#    mcharge::_refund_request        - build up a 'refund request' string
#    mcharge::_update_payment_method - add security token to CPM
#    mcharge::_get_payment_method    - return a security_token for a CPM
#

# Namespace Variables
#
namespace eval mcharge {

	array set CARD_CODES {
		MC {MC}
		VC {VISA}
		VD {VISA}
		SWCH {SWITCH}
		SOLO {SOLO}
		ELTN {UKE}
	}

}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation
#
proc mcharge::init args {

	ob_log::write INFO {PMT mcharge: init}

	# http package
	package require tls
	package require http

	http::register https 443 ::tls::socket

	_prepare_qrys
}

# Private procedure to prepare queries
#
proc mcharge::_prepare_qrys args {

	ob_log::write INFO {PMT mcharge: _prepare_qrys}

	global SHARED_SQL

	set SHARED_SQL(update_pay_method) {
		update
			tCpmCC
		set
			gw_dep_trans_id = ?,
			gw_security_token = ?
		where
			cpm_id = ?
	}

	set SHARED_SQL(get_pay_method) {
		select
			gw_dep_trans_id,
			gw_security_token
		from
			tCpmCC
		where
			cpm_id = ?
	}
}


# Send a POST request to Metacharge
#
#   ARRAY - the PMT array used in all gateways to hold payment details
#
proc mcharge::make_metacharge_call {ARRAY} {

	upvar $ARRAY PMT

	ob_log::write INFO {PMT mcharge: make_metacharge_call}

	set call_type ""

	set pay_sort $PMT(pay_sort)

	if {[OT_CfgGet METACHARGE_REPEAT_AND_REFUND 0] == 0} {
		# Get previous transaction data if there is any stored
		# for this CPM
		foreach {call_type req} \
				[_get_call_type_and_req PMT] {}
	} else {
		if {$pay_sort != "D"} {
			if {$pay_sort == "X"} {
				set call_type "REFUND"
				set trans_id       $PMT(gw_uid)
				set security_token $PMT(mc_security_token)
				set req [_refund_request PMT $trans_id $security_token]
			} else {
				return PMT_METACHARGE_NO_REFUND
			}
		} else {
			set call_type "PAYMENT"
			set req [_payment_request PMT]
		}
	}

	if {$call_type == "ERROR"} {
		ob_log::write WARNING {PMT make_metacharge_call: Problem getting call type}
		return PMT_ERR
	} elseif {$call_type == "PMT_METACHARGE_WTD_NO_DATA"} {
		ob_log::write WARNING \
			{PMT make_metacharge_call: Cannot withdraw without previous tx data}
		return PMT_METACHARGE_WTD_NO_DATA
	}

	# Attempt to send the request to Metacharge
	foreach {success ret} [_send_req $PMT(host) $req $PMT(conn_timeout)] {}
	if {$success != "OK"} {
		ob_log::write ERROR {PMT Bad Connection : $success $ret}
		ob_log::write ERROR {PMT Server : $PMT(host)}
		if {$success == "ERR_CON_ERROR"} {
			return PMT_NO_SOCKET
		} else {
			return PMT_RESP
		}
	}

	# Move data from the return string into internal array
	set response [split $ret "&"]
	foreach c $response {
		set param [split $c =]
		set name [lindex $param 0]
		set value [lindex $param 1]

		ob_log::write INFO {PMT ${name}=${value}}
		set MCHARGE_RESP($name) $value
	}

	# Check the status return
	if {![info exists MCHARGE_RESP(intStatus)]} {
		ob_log::write WARNING {PMT make_metacharge_call: No status returned}
		return PMT_RESP
	}

	ob_log::write INFO \
		{PMT make_metacharge_call: Status: $MCHARGE_RESP(intStatus)}

	# Get the transaction identifiers from the response...
	set trans_id ""
	set security_token ""

	catch {set trans_id       $MCHARGE_RESP(intTransID)}
	catch {set security_token $MCHARGE_RESP(strSecurityToken)}

	ob_log::write INFO \
		{PMT make_metacharge_call: trans_id: $trans_id}

	ob_log::write INFO \
		{PMT make_metacharge_call: security_token: $security_token}

	if {$MCHARGE_RESP(intStatus) != 1} {

		set PMT(gw_ret_code) $MCHARGE_RESP(intStatus)

		if {[OT_CfgGet METACHARGE_REPEAT_AND_REFUND 0] == 1} {
			# There's been an error from Metacharge, we should wipe
			# trans_id, security_token and cvv2 response from the DB
			_update_payment_method "" "" $PMT(cpm_id)
		}

		# Unexpected status code so give up now
		if {$MCHARGE_RESP(intStatus) != 0} {
			return PMT_RESP
		# Payment declined (or failed), but we still want to fill
		# in the payment array
		} else {
			set res PMT_DECL
		}
	} else {
		set PMT(gw_ret_code) 1
		set res OK
	}

	# Try to fill in as many return fields as possible from Metacharge's
	# response
	catch {set PMT(gw_ret_msg)        [urldecode $MCHARGE_RESP(strMessage)]}
	catch {set PMT(gw_uid)            $MCHARGE_RESP(intTransID)}
	catch {set PMT(mc_security_token) $MCHARGE_RESP(strSecurityToken)}

	# For PAYMENT requests get extra info from the return
	if {$call_type == "PAYMENT"} {
		# Setup card type
		catch {set PMT(card_type) $MCHARGE_RESP(strPaymentType)}

		# Sort out cv2avs_status
		set intAVS ""
		set intCV2 ""

		catch {set intAVS $MCHARGE_RESP(intAVS)}
		catch {set intCV2 $MCHARGE_RESP(intCV2)}

		set PMT(cv2avs_status) [_get_cv2avs_status $intAVS $intCV2]

		# Get any fraud scoring data
		set fraud_score ""
		catch {set fraud_score $MCHARGE_RESP(intAVS)}

		if {$fraud_score != ""} {
			set PMT(fraud_score) $fraud_score
			set PMT(fraud_score_source) "MC"
		}

		if {[OT_CfgGet METACHARGE_REPEAT_AND_REFUND 0] == 1} {
			# Update the customer's payment method with the new
			# Security Token and Transaction Id.
			# N.B. CVV2 response will be handled by calling function
			_update_payment_method $trans_id $security_token $PMT(cpm_id)
		}
	}

	return $res
}



#--------------------------------------------------------------------------
# Procedures to build request strings
#--------------------------------------------------------------------------

# Build up a 'payment' request
#
#   ARRAY - the PMT array used in all gateways to hold payment details
#
proc mcharge::_payment_request { ARRAY } {

	ob_log::write INFO {PMT mcharge: _payment_request}

	upvar $ARRAY PMT

	# Get config values, and provide sensible defaults
	set intInstID [OT_CfgGet MCHARGE_INSTALL_ID]
	set intTestMode [OT_CfgGet MCHARGE_TEST_MODE 1]
	set fltAPIVersion [OT_CfgGet MCHARGE_API_VER 1.3]
	set test_card_num [OT_CfgGet MCHARGE_TEST_CARDNUM "1234123412341234"]

	set strDesc "gambling"

	# Map openbet card scheme into one Metacharge understands
	set strCardType [_translate_card_type $PMT(card_scheme)]

	if {$strCardType == ""} {
		return ERROR
	}

	# Need to strip slash from expiry
	set expiry_list [split $PMT(expiry) /]
	set expiry "[lindex $expiry_list 0][lindex $expiry_list 1]"

	# Form request string
	set req ""

	# If we want just to send to the test gateway, send extra test parameter
	# and set the test card number.
	if { $intTestMode == 1 } {
		append req "intTestMode=1"
		set PMT(card_no) $test_card_num
		set PMT(cvv2) "707"
		set strCardType "VISA"
	}

	if {$PMT(email) == ""} {
		set PMT(email) "NOEMAIL"
	}

	if {$PMT(postcode) == ""} {
		set PMT(postcode) "NOPOSTCODE"
	}

	# Get address and URL encode
	set addr [urlencode $PMT(addr_1)]
	append addr [urlencode " $PMT(addr_2)"]
	append addr [urlencode " $PMT(addr_3)"]
	append addr [urlencode " $PMT(addr_4)"]

	append req "&intInstID=$intInstID&strCartID=$PMT(apacs_ref)"
	append req "&strDesc=[urlencode $strDesc]&fltAmount=$PMT(amount)"
	append req "&strCurrency=$PMT(ccy_code)"
	append req "&strCardHolder=[urlencode $PMT(hldr_name)]"
	append req "&strAddress=$addr"
	append req "&strCity=[urlencode $PMT(city)]"
	append req "&strPostcode=[urlencode $PMT(postcode)]"
	append req "&strEmail=[urlencode $PMT(email)]"
	append req "&strCardNumber=$PMT(card_no)&strExpiryDate=$expiry"
	append req "&intCV2=$PMT(cvv2)&strCardType=$strCardType"
	append req "&fltAPIVersion=$fltAPIVersion&strTransType=PAYMENT"
	append req "&strUserIP=$PMT(ip)"

	# Append issue number if one exists
	if { $PMT(issue_no) != "" } {
		append req "&strIssueNo=$PMT(issue_no)"
	}

	# Append start date if one exists
	if { $PMT(start) != "" } {
		set start_list [split $PMT(start) /]
		set start "[lindex $start_list 0][lindex $start_list 1]"
		append req "&strStartDate=$start"
	}

	return $req
}



# Build up a 'repeat payment' request
#
#   ARRAY - the PMT array used in all gateways to hold payment details
#   trans_id - the transaction id for a previous payment (stored in tCpmCC)
#   security_token - returned from a payment request (stored in tCpmCC)
#
# returns        - the request string to use
#
proc mcharge::_repeat_request {ARRAY trans_id security_token} {

	ob_log::write INFO {PMT mcharge: _repeat_request: $trans_id, $security_token}

	upvar $ARRAY PMT

	# Get config values, and provide sensible defaults
	set intInstID [OT_CfgGet MCHARGE_INSTALL_ID]
	set intTestMode [OT_CfgGet MCHARGE_TEST_MODE 1]
	set fltAPIVersion [OT_CfgGet MCHARGE_API_VER 1.3]

	# Form request string
	set req ""

	# If we want just to send to the test gateway, send extra test parameter
	# and set the test card number.
	if { $intTestMode == 1 } {
		append req "intTestMode=1&"
	}

	append req "intInstID=$intInstID"
	append req "&intTransID=$trans_id"
	append req "&strSecurityToken=$security_token"
	append req "&fltAmount=$PMT(amount)"
	append req "&fltAPIVersion=$fltAPIVersion"
	append req "&strTransType=REPEAT"

	return $req
}



# Build up a 'refund' request string
#
# ARRAY          - the PMT array used in all gateways to hold payment details
# trans_id       - the transaction id for a previous payment (stored in tCpmCC)
# security_token - returned from a payment request (stored in tCpmCC)
#
# returns        - the request string to use
#
proc mcharge::_refund_request {ARRAY trans_id security_token} {

	ob_log::write INFO {PMT mcharge: _refund_request $trans_id $security_token}

	upvar $ARRAY PMT

	set intInstID [OT_CfgGet MCHARGE_INSTALL_ID]
	set intTestMode [OT_CfgGet MCHARGE_TEST_MODE 1]

	set strDesc "REFUND"

	set req ""

	# If we want just to send to the test gateway, send extra test parameter
	# and set the test card number.
	if { $intTestMode == 1 } {
		append req "intTestMode=1&"
	}

	append req "intInstID=$intInstID"
	append req "&intTransID=$trans_id"
	append req "&strSecurityToken=$security_token"
	append req "&fltAmount=$PMT(amount)"
	append req "&strDesc=$strDesc"
	append req "&fltAPIVersion=[OT_CfgGet MCHARGE_API_VER 1.3]"
	append req "&strTransType=REFUND"

	return $req
}



#--------------------------------------------------------------------------
# Procedures to handle actual request to Metacharge
#--------------------------------------------------------------------------

# Based on the type of transaction being requested and whether there is any
# previous Metacharge transaction data, return type of call to make and the
# request data.
#
# pay_sort - (D|W) Type of transaction, i.e. Deposit or Withdrawal
# cpm_id   - Identifier of the customer's card payment method
#
# returns  - List in following format {(call type) (request data)}
#            Call type returned as ERROR if problem getting information
#            Call type returned as PMT_METACHARGE_WTD_NO_DATA if a withdrawal
#            request is attempted with no previous transaction data.
#
proc mcharge::_get_call_type_and_req {ARRAY} {

	ob_log::write INFO {PMT mcharge: _get_call_type_and_req}

	upvar $ARRAY PMT

	set pay_sort $PMT(pay_sort)
	set cpm_id   $PMT(cpm_id)

	set res [_get_payment_method $cpm_id]

	if {[lindex $res 0] == 1} {
		set trans_id       [lindex $res 1]
		set security_token [lindex $res 2]
	} else {
		# Failure when attempting to access previous transaction data
		return [list ERROR {}]
	}

	# Work out what sort of call to make
	if {$pay_sort == "D"} {

		# Check for previous transaction data
		if {$security_token == "" || $security_token == "0"} {

			# Regular PAYMENT request is required, as we have no
			# previous information to use
			ob_log::write INFO {PMT _get_call_type_and_req: Do PAYMENT request}
			set req [_payment_request PMT]
			if {$req != "ERROR"} {
				return [list PAYMENT $req]
			} else {
				return [list ERROR {}]
			}
		} else {

			# We can use the security token and transaction id from a
			# previous successful payment, so do REPEAT request
			ob_log::write INFO {PMT _get_call_type_and_req: Do REPEAT request}
			return [list REPEAT \
					[_repeat_request PMT $trans_id $security_token]]
		}

	} elseif {$pay_sort == "W"} {

		if {!($security_token == "" || $security_token == "0")} {

			# We can use the security token and transaction id from a
			# previous successful payment, so do REFUND request
			ob_log::write INFO {PMT _get_call_type_and_req: Do REFUND request}
			return [list REFUND \
					[_refund_request PMT $trans_id $security_token]]
		} else {

			# No previous transaction data available, so can't refund
			ob_log::write WARNING \
				{PMT _get_call_type_and_req: Need previous transaction data\
				to withdraw via Metacharge}
			return PMT_METACHARGE_WTD_NO_DATA
		}

	} else {

		ob_log::write WARNING {PMT _get_call_type_and_req: Unknown payment sort}
		return ERROR
	}
}



# Actually attempt to send the request to Metacharge, using the
# standard http package
#
# url     - Metacharge payment request url
# req     - Request data to send
# timeout - Time before aborting request attempt
#
# returns - List in following format: {(Error Code) (Error Info)}
#           Error code will be OK if successful
#
proc mcharge::_send_req {url req timeout} {

	ob_log::write INFO {PMT mcharge: send_req $url $timeout}

	#make the connection
	if [catch {
		set token [http::geturl $url -query $req -timeout $timeout]
		upvar #0 $token state
	} msg] {
		# Didn't manage to establish a connection
		set res [list "ERR_CON_ERROR" $msg]
	} else {

	   switch -exact -- $state(status) {
				"ok" {
						if { [regexp {\s*(\d\d\d)\s*} $state(http) x http_code] } {
								if {$http_code == "200"} {
										set res [list "OK" $state(body)]
								} else {
										set res [list "ERR_BAD_RESPONSE" $state(http)]
								}
						} else {
								set res [list "ERR_BAD_HTTP_CODE" $state(http)]
						}
				}
				"timeout" {
						set res [list "ERR_TIMEOUT"]
				}
				"eof" {
						set res [list "ERR_NO_RESPONSE"]
				}
				"error" {
						set res [list "ERR_ERROR" $state(error)]
				}
				default {
						set res [list "ERR_UNKNOWN_STATUS" $state(status)]
				}
		}

		# check for posterror (not all post data was sent before ok response or eof
		# was received).
		if { [info exists state(posterror)] } {
				set res [list "ERR_POSTERROR" $state(posterror)]
		}

		::http::cleanup $token
	}

	return $res
}



#--------------------------------------------------------------------------
# Procedures to handle previous transaction data
#--------------------------------------------------------------------------

# Update Customers Payment Method with security token and transaction id
#
# trans_id       - the transaction id for a previous payment (stored in tCpmCC)
# security_token - returned from a payment request (stored in tCpmCC)
# cvv2_resp      - the result of CV2 and AVS checking
# cpm_id         - Customer Payment Method ID (retrieved from PMT(cpm_id)
#
# returns        - (0|1) 0 = failure, 1 = success
#
proc mcharge::_update_payment_method {trans_id security_token cpm_id} {

	ob_log::write INFO {PMT mcharge: _update_payment_method $trans_id $security_token $cpm_id}

	if {[catch {set rs [tb_db::tb_exec_qry update_pay_method\
			$trans_id $security_token $cpm_id]} msg]} {
		ob_log::write WARNING {PMT Failed to update CPM with Metacharge info}
		return 0
	}
	return 1
}



# Get a Customers Payment Method
#
#  cpm_id - Customer Payment Method ID (retrieved from PMT(cpm_id)
#
#  returns - list in following format: {success trans_id security_token}
#            success = (0|1), if 0 (i.e. failed), then other info will be blank
#
proc mcharge::_get_payment_method { cpm_id } {

	ob_log::write INFO {PMT mcharge: _get_payment_method $cpm_id}

	if {[catch {set rs [tb_db::tb_exec_qry get_pay_method $cpm_id]} msg]} {
		ob_log::write WARNING {PMT Failed to get CPM: $msg}
		return [list 0 {} {}]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set trans_id       [db_get_col $rs 0 gw_dep_trans_id]
		set security_token [db_get_col $rs 0 gw_security_token]
		db_close $rs
		return [list 1 $trans_id $security_token]
	} else {
		ob_log::write WARNING \
			{PMT _get_payment_method: Problem with CPM data, cpm_id: $cpm_id}
		db_close $rs
		return [list 0 {} {}]
	}
}



#--------------------------------------------------------------------------
# Utility functions
#--------------------------------------------------------------------------

# Take the code id from the PMT array and return a metacharge friendly code
#
#    code_id - the card_scheme from the PMT array
#
proc mcharge::_translate_card_type { code_id } {

	ob_log::write INFO {PMT mcharge: _translate_card_type}

	variable CARD_CODES

	set card_type ""

	if {[info exists CARD_CODES($code_id)]} {
		set card_type $CARD_CODES($code_id)
	}

	return $card_type
}



# Translate the AVS and CV2 response fields into Datacash standard text
# format
#
# intAVS  - Address Verification response from Metacharge
# intCV2  - Customer Security Code response from Metacharge
#
# returns - Datacash-style cv2avs_status string
#
proc mcharge::_get_cv2avs_status {intAVS intCV2} {

	# No responses
	if {($intAVS == "") || ($intCV2 == "")} {
		set cv2avs_status "DATA NOT CHECKED"
	}

	# Unexpected responses
	if {(($intAVS != 0) && ($intAVS != 1)) || \
		(($intCV2 != 0) && ($intCV2 != 1))} {

		set cv2avs_status "UNKNOWN"
	}

	# Address check failed
	if {$intAVS == 0} {
		# CV2 check failed
		if {$intCV2 == 0} {
			set cv2avs_status "NO DATA MATCHES"
		# CV2 check passed
		} else {
			set cv2avs_status "SECURITY CODE MATCH ONLY"
		}
	# Address check passed
	} elseif {$intAVS == 1} {
		# CV2 check failed
		if {$intCV2 == 0} {
			set cv2avs_status "ADDRESS MATCH ONLY"
		# CV2 check passed
		} else {
			set cv2avs_status "ALL MATCH"
		}
	}
}
