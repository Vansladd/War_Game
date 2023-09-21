# ==============================================================
# $Id: marqisa.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# TCL Script controlling the interface to the Marqisa payment
# gateway. Uses the build_xml and parse_xml packages to form /
# parse the XML.
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

namespace eval marqisa {

	namespace export marqisa_init
	namespace export make_marqisa_call

	#Array of the <card scheme> --> <tag name> mappings
	array set MQISA_CARD_TYPE {
		LASR   LASER-SSL
		MC     ECMC-SSL
		SOLO   SOLO_GB-SSL
		SWCH   SWITCH-SSL
		VC     VISA-SSL
		VD     VISA-SSL
	}

	#Deposit return code mappings
	array set RETURN_MAPPINGS {
		AUTHORISED      OK
		SENT_FOR_REFUND OK
		CAPTURED        OK
		REFUSED         PMT_DECL
		ERROR           PMT_ERR
	}

	#Map HTTP return codes to generic Payment return codes
	array set HTTP_CODE_TX {
		200 OK
		201 OK
		203 PMT_RESP
		204 PMT_RESP
		301 PMT_RESP
		302 PMT_RESP
		303 PMT_RESP
		304 PMT_RESP
		400 PMT_RESP
		404 PMT_RESP
		401 PMT_UNAUTHORIZED
		403 PMT_UNAUTHORIZED
		500 PMT_SERVER_ERROR
		501 PMT_SERVER_ERROR
	}

	# ----------------------------------------------------------------------
	# Attempts to open an SSL connection to marqisa, post the XML message
	# string and await the XML response.
	#
	# note that there are 2 levels of error handling - first for the actual
	# HTTP call, and then for any Marqisa reported exceptions which are embedded
	# in the XML
	#
	# The data in the message returned by marqisa is stored in the XML_RESPONSE
	# array
	# ----------------------------------------------------------------------
	proc make_marqisa_call {ARRAY} {

		upvar    $ARRAY PMT
		variable RETURN_MAPPINGS

		#Construct the necessary data
		switch -- $PMT(pay_sort) {
			"D" {
				set MQISA_DATA(OP) "AUTHORISE"
			}
			"W" {
				set MQISA_DATA(OP) "REFUND"
			}
			default {
				ob_log::write WARNING {PMT Bad payment sort $PMT(pay_sort)}
				return PMT_TYPE
			}
		}

		#Retrieve the card info
		set card_info [card_util::get_card_scheme $PMT(card_no)]
		if {$card_info == ""} {return PMT_CARD}
		set MQISA_DATA(CARD_TYPE) [lindex $card_info 0]
		set MQISA_DATA(USE_START_DATE) [lindex $card_info 1]
		set MQISA_DATA(ISSUE_LENGTH) [lindex $card_info 2]

		set MQISA_DATA(AMOUNT) 		  $PMT(amount)
		set MQISA_DATA(ORDER_NO)      $PMT(apacs_ref)
		set MQISA_DATA(CARD_NUM)      $PMT(card_no)
		set MQISA_DATA(START)         $PMT(start)
		set MQISA_DATA(EXPIRY)        $PMT(expiry)
		set MQISA_DATA(ISSUE_NO)      $PMT(issue_no)
		set MQISA_DATA(CCY)           $PMT(ccy_code)
		set MQISA_DATA(AUTH_CODE)	  $PMT(gw_auth_code)
		set MQISA_DATA(DESCRIPTION)   "Payment to $PMT(client)"

		# payment gateway values
		set MQISA_DATA(MERCHANT_CODE) $PMT(client)
		set MQISA_DATA(URL)           $PMT(host)
		set MQISA_DATA(PORT)          $PMT(port)
		set MQISA_DATA(RESP_TIMEOUT)  [OT_CfgGet MQISA_TIMEOUT         $PMT(resp_timeout)]
		set MQISA_DATA(CONN_TIMEOUT)  [OT_CfgGet MQISA_SOCKET_TIMEOUT  $PMT(conn_timeout)]
		set MQISA_DATA(SOURCE)        $PMT(cp_flag)

		#Build the authorisation string
		set MQISA_DATA(AUTHORISATION) [bintob64 "$PMT(client):$PMT(password)"]

		#Check if we have an authorisation code or not - if we do then we are authorising
		#a previously referred payment, otherwise we are sending a new payment
		build_xml::xmlInit
		if {[string trim $MQISA_DATA(AUTH_CODE)] != ""} {

			OT_LogWrite 5 "Processing referred payment orderCode=$MQISA_DATA(ORDER_NO) - authorisationCode=$MQISA_DATA(AUTH_CODE)."
			set err [build_modify MQISA_DATA]

		} else {

			set err [build_submit MQISA_DATA]
		}

		#Check the return
		if {$err != "OK"} {
			build_xml::xmlReset
			return $err
		}
		set XML_OUT [build_xml::buildString 1]
		OT_LogWrite 20 "Outgoing XML: \n$XML_OUT\n"

		build_xml::xmlReset

		# make the marqisa call
		OT_LogWrite 5 "http::geturl $MQISA_DATA(URL) -timeout $MQISA_DATA(RESP_TIMEOUT) -type text/xml -headers Authorization {Basic $MQISA_DATA(AUTHORISATION)} -query $XML_OUT"
		set resp_array [http::geturl $MQISA_DATA(URL) -timeout $MQISA_DATA(RESP_TIMEOUT) \
						-type "text/xml" \
						-headers "Authorization {Basic $MQISA_DATA(AUTHORISATION)}" \
						-query $XML_OUT]

		#Initialise the payment return stuff
		set PMT(gw_ret_code)        ""
		set PMT(gw_uid)             $MQISA_DATA(ORDER_NO)
		set PMT(card_type)          $MQISA_DATA(CARD_TYPE)
		set PMT(gw_ret_msg)         ""

		#Check the HTTP response
		set httpResp [check_http_resp $resp_array]
		if {$httpResp != "OK"} {
			http::cleanup $resp_array
			return $httpResp
		}

		OT_LogWrite 20 "Marqisa response:\n [::http::data $resp_array]"

		#Looks like the HTTP transaction was OK - create the XML tree
		parse_xml::clean
		parse_xml::parseBody [::http::data $resp_array]

		#Can now close down the resp_array
		::http::cleanup $resp_array

		#Store auth code if not a referral
		if {[string trim $PMT(gw_auth_code)] == ""} {
			set PMT(gw_auth_code)       [getElement paymentService,reply,orderStatus,payment,AuthorisationId,id]
		}

		#Build the Return Message - check for the 4 most key fields (Note: error tag can appear in two places)
		set ret_msg  ""
		if {[getElement paymentService,reply,orderStatus,error] != "" || [getElement paymentService,reply,error] != ""} {
			set ret_msg "ERROR=[getElement paymentService,reply,orderStatus,error][getElement paymentService,reply,error];"
		}
		if {[getElement paymentService,reply,orderStatus,payment,lastEvent] != ""} {
			set ret_msg "$ret_msg LASTEVENT=[getElement paymentService,reply,orderStatus,payment,lastEvent];"
		}
		if {[getElement paymentService,reply,orderStatus,payment,ISO8583ReturnCode,code] != ""} {
			set ret_msg "$ret_msg ISO8583RETURNCODE=[getElement paymentService,reply,orderStatus,payment,ISO8583ReturnCode,code]:[getElement paymentService,reply,orderStatus,payment,ISO8583ReturnCode,description]"
		}
		if {[getElement paymentService,reply,orderStatus,payment,AuthorisationId,id] != ""} {
			set ret_msg "$ret_msg AuthorisationId=[getElement paymentService,reply,orderStatus,payment,AuthorisationId,id]"
		}
		if {[getElement paymentService,reply,orderStatus,payment,riskScore,value] != ""} {
			set ret_msg "$ret_msg riskScore=[getElement paymentService,reply,orderStatus,payment,riskScore,value]"
		}

		OT_LogWrite 20 "Return msg: $ret_msg"
		set PMT(gw_ret_msg) [string range $ret_msg 0 159]

		#Now examine the returned XML - first check for an error element
		if {[getElement "paymentService,reply,error"] != "" || \
			[getElement paymentService,reply,orderStatus,error] != ""} {

			#Log the error
			OT_LogWrite 5 "Marqisa returned error : [getElement paymentService,reply,error][getElement paymentService,reply,orderStatus,error]"

			#Retrieve the error code
			#All but "invalid payment details" are handled as an unknown error
			if {[getElement "paymentService,reply,error,code"] == 7 || \
				[getElement "paymentService,reply,orderStatus,error,code"] == 7}	{
				return PMT_INVALID_DETAILS
			} else {
				return PMT_ERR
			}
		}

		#If no error exists then check the last event type
		if {[info exists parse_xml::XML_RESPONSE(paymentService,reply,orderStatus,payment,lastEvent)] && \
			[info exists RETURN_MAPPINGS($parse_xml::XML_RESPONSE(paymentService,reply,orderStatus,payment,lastEvent))]} {

			set retCode $RETURN_MAPPINGS($parse_xml::XML_RESPONSE(paymentService,reply,orderStatus,payment,lastEvent))
			set isoCode [getElement paymentService,reply,orderStatus,payment,ISO8583ReturnCode]

			#Check for a referral
			if {$retCode == "PMT_DECL" && \
				[getElement paymentService,reply,orderStatus,payment,ISO8583ReturnCode,description] == "REFERRED"} {

				if {[OT_CfgGetTrue MARQISA_ALLOW_PMT_REFER]} {
					#We have a referred payment
					return PMT_REFER
				} else {
					#Stop referrals on all lasercards
					return PMT_ERR
				}

			} elseif {$retCode == "OK" && $isoCode != ""} {

				# Just make absolutely sure that marqisa hasn't screwed up again - if we have
				# an ISO8583 return code, then it should be 0 - Authorised.
				switch  -- $isoCode {

					0 {
						# All OK
						return OK
					}

					2 {

						# Looks like we have a referred payment
						OT_LogWrite 1 "MARQISA returned an unexpected referral payment! -> order no: $MQISA_DATA(ORDER_NO)"

						if {[OT_CfgGetTrue MARQISA_ALLOW_PMT_REFER]} {
							return PMT_REFER
						} else {
							#Stop referrals on all lasercards
							return PMT_ERR
						}
					}

					default {

						# Unexpected return code
						OT_LogWrite 1 "MARQISA returned an unexpected ISO code : $isoCode! -> order no: $MQISA_DATA(ORDER_NO)"
						return PMT_ERR
					}
				}

			} else {

				#Otherwise return the mapped code
				return $retCode
			}
		}

		#If we've reached here then we've got an error case
		return PMT_ERR
	}

	#--------------------------------------------------------
	# Checks whether there were any problems with the http call associated
	# with the passed http response array
	#--------------------------------------------------------
	proc check_http_resp {resp_array} {

		variable HTTP_CODE_TX

		#Examine the return status
		OT_LogWrite 10 "HTTP status : [::http::status $resp_array]"
		switch [::http::status $resp_array] {

			"ok" {
				#No problems
			}

			"timeout" {
				#Return code for no response
				return PMT_RESP
			}

			"ioerror" {
				#Return code for no socket
				return PMT_NO_SOCKET
			}

			default {
				#Catch all other errors
				return PMT_ERR
			}
		}

		#Examine the HTTP response code
		regexp {^[^ ]* ([0-9][0-9][0-9]) (.*)$} [::http::code $resp_array] trash code message

		if {[info exists HTTP_CODE_TX($code)]} {

			if {$HTTP_CODE_TX($code) != "OK"} {
				OT_LogWrite 5 "Marqisa HTTP call failed : $message"
				return $HTTP_CODE_TX($code)
			}

		} else {

			#unknown code - just return a no response error
			return PMT_ERR
		}

		#So far so good!
		return OK
	}

	#----------------------------------------------------------
	# Build the XML for a new payment request. Uses the build_xml package.
	# to populate the XML_DATA array. The calling method can then
	# retrieve the XML string when required with a call to
	# build_xml::build_string
	#----------------------------------------------------------
	proc build_submit {ARRAY} 	{

		upvar    $ARRAY DATA
		variable MQISA_CARD_TYPE
		variable ISSUE_START_REQD

		OT_LogWrite 10 ">>>>build_submit"

		#DEBUG
		#OT_LogWrite 15 "\n ---- DATA ARRAY ----\n"
		#foreach name [array names DATA] {
		#    OT_LogWrite 15 "----> DATA($name) == $DATA($name)"
		#}

		#Initialise
		build_xml::setDoctype "<!DOCTYPE paymentService SYSTEM 'http://dtd.bibit.com/paymentService_v1.dtd'>"

		#Root node
		set paymentService [build_xml::addRootNode "paymentService"]
		build_xml::addAttributes $paymentService [list "version"      "1.3" \
											"merchantCode" $DATA(MERCHANT_CODE)]

		#Submit node
		set submit [build_xml::addChildNode $paymentService "submit"]

		#Order node
		set order  [build_xml::addChildNode $submit "order"]
		build_xml::addAttributes $order [list "orderCode" $DATA(ORDER_NO)]

		#Description node
		build_xml::addChildNode $order "description" $DATA(DESCRIPTION)

		#Amount node
		set amountValue [expr $DATA(AMOUNT) * 100]
		if {[expr $amountValue == floor($amountValue)]} {set amountValue [format %.0f $amountValue]}
		set amount [build_xml::addChildNode $order "amount"]
		build_xml::addAttributes $amount [list  "currencyCode"         $DATA(CCY) \
												"exponent"             "2"        \
												"debitCreditIndicator" "credit"   \
												"value"                $amountValue]

		#Order content node
		build_xml::addChildNode $order "orderContent" $DATA(DESCRIPTION)

		#Payment Details node
		set paymentDetails [build_xml::addChildNode $order "paymentDetails"]
		build_xml::addAttributes $paymentDetails [list "action" $DATA(OP)]

		#Add the card specific nodes
		if {![info exists MQISA_CARD_TYPE($DATA(CARD_TYPE))]} {

			#Unsupported card type
			return PMT_CARD_UNKNWN
		}

		#Card node
		set cardNode [build_xml::addChildNode $paymentDetails $MQISA_CARD_TYPE($DATA(CARD_TYPE))]

		#Card Number
		build_xml::addChildNode $cardNode "cardNumber" $DATA(CARD_NUM)

		#Expiry date
		set expiryDate [build_xml::addChildNode $cardNode "expiryDate"]
		set expiryDateValue [build_xml::addChildNode $expiryDate "date"]
		if [catch {
			build_xml::addAttributes $expiryDateValue [list "month" [string range $DATA(EXPIRY) 0 1] \
															 "year" [get4digitYear [string range $DATA(EXPIRY) 3 end]]]
		}] {

			#Problem with the expiry date
			return PMT_EXPR
		}

		#Cardholder name can be used to test different responses - just uncomment the response required.
		#For production, insert a dummy name - miss i ng

		build_xml::addChildNode $cardNode "cardHolderName" "Miss I Ng"
		#build_xml::addChildNode $cardNode "cardHolderName" "REFERRED"
		#build_xml::addChildNode $cardNode "cardHolderName" "ERROR"
		#build_xml::addChildNode $cardNode "cardHolderName" "REFUSED"

		#Issue/start date
		if {$DATA(USE_START_DATE) == "Y" && $DATA(START) != ""} {

			#Start date node
			set startDate [build_xml::addChildNode $cardNode "startDate"]
			set startDateValue [build_xml::addChildNode $startDate "date"]
			if [catch {
				build_xml::addAttributes $startDateValue [list "month" [string range $DATA(START) 0 1] \
																"year"  [get4digitYear [string range $DATA(START) 3 end]]]
			}] {

				#Problem with the start date
				return PMT_STRT
			}

		} elseif {$DATA(ISSUE_LENGTH) > 0 && $DATA(ISSUE_NO) != ""} {

			#Issue Number
			build_xml::addChildNode $cardNode "issueNumber" $DATA(ISSUE_NO)

		}

		OT_LogWrite 10 "<<<< build_submit"

		#All looks OK
		return OK

	}

	#----------------------------------------------------------
	# Build the XML for authorising a previously referred payment
	# request. Uses the build_xml package to populate the XML_DATA
	# array. The calling method can then retrieve the XML string
	# when required with a call to build_xml::build_string
	#----------------------------------------------------------
	proc build_modify {ARRAY} 	{

		upvar    $ARRAY DATA

		OT_LogWrite 10 ">>>> build_modify"

		#Initialise
		build_xml::setDoctype "<!DOCTYPE paymentService SYSTEM 'http://dtd.bibit.com/paymentService_v1.dtd'>"

		#Root node
		set paymentService [build_xml::addRootNode "paymentService"]
		build_xml::addAttributes $paymentService [list "version"      "1.3" \
											"merchantCode" $DATA(MERCHANT_CODE)]

		#Modify node
		set modify [build_xml::addChildNode $paymentService "modify"]

		#Order node
		set orderModification  [build_xml::addChildNode $modify "orderModification"]
		build_xml::addAttributes $orderModification [list "orderCode" $DATA(ORDER_NO)]

		#Authorise node
		set authorise [build_xml::addChildNode $orderModification "authorise"]
		build_xml::addAttributes $authorise [list "authorisationCode" $DATA(AUTH_CODE)]

		OT_LogWrite 10 "<<<< build_modify"

		#All looks OK
		return OK

	}

	#--------------------------------------------------------
	# Helper method to convert a 2 digit year into a 4 digit year.
	# This relies on assuming that if the year is greater than 90,
	# then it must refer to 1990 as opposed to 2090
	#--------------------------------------------------------
	proc get4digitYear {year} {

		if {[string length $year] == 2} {
			if {$year < 90} {
				return "20$year"
			} else {
				return "19$year"
			}
		} else {
			return $year
		}
	}

	#--------------------------------------------------------
	# Helper procedure used to safely retrieve an element from the XML_RESPONSE
	# array if it exists, or an empty string if it doesn't exist
	#--------------------------------------------------------
	proc getElement {elementKey} {

		if [info exist parse_xml::XML_RESPONSE($elementKey)] {
			return $parse_xml::XML_RESPONSE($elementKey)
		} else {
			return ""
		}
	}

	#--------------------------------------------------------
	# Initialises anything which is specific to marqisa
	# messaging
	#--------------------------------------------------------
	proc marqisa_init {} {

		ob_log::write INFO {PMT ==> marqisa_init}
		package require tls 1.4
		package require http
		http::register https 443 ::tls::socket
	}
}

proc marqisa_init {} {

	ob_log::write INFO {PMT ==> marqisa_init: Please remove this call, call payment_gateway::pmt_gtwy_init instead}
}
