# $Id: datacash.tcl,v 1.1 2011/10/04 12:40:39 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to the ProveURU verification system.
#
# Provides an XML client for the ProveURU systems via Datacash's XML interface
# Allows customer details to be verified and the result interpreted.
# Also enables older searches to be retrieved from ProveURU logs.
#
# Synopsis:
#	package require ovs_datacash
#
# Configurations:
#
#	OVS_DCASH_TIMEOUT    timeout        (10000)
#
# Procedures:
#	ob_ovs_dcash::init      - one initialisation for package
#	ob_ovs_dcash::set_up    - initialise datacash gateway settings
#	ob_ovs_dcash::run_check - pass details for verification request and parse
#	                          response
#	ob_ovs_dcash::run_log   - pass details for verification log request and parse
#	                          response
#
package provide ovs_datacash 4.5



# Dependencies
#
package require tls
package require http 2.3
package require tdom
package require util_db
package require util_log



# Variables
#
namespace eval ob_ovs_dcash {

	variable INITIALISED
	set INITIALISED 0

	variable URU_LOOKUP
	array set URU_LOOKUP {}
}



# One time initialisation
#
proc ob_ovs_dcash::init {} {

	global auto_path
	variable INITIALISED

	if {$INITIALISED} {return}

	ob_log::write CRITICAL "************* INITIALISING URU CONNECTIVITY"
	#ob_log::write_stack 1

	::http::register https 443 ::tls::socket

	variable DCASH_CFG
	variable URU_LOOKUP

	catch {unset DCASH_CFG}

	foreach item [list \
		timeout \
		uru_ids] {

		set config OVS_DCASH_[string toupper $item]
		set DCASH_CFG($item) [OT_CfgGet $config]
		if {$DCASH_CFG($item) == ""} {
			error "$config value missing from configuration file"
		}
	}

	foreach [list type id] $DCASH_CFG(uru_ids) {
		set URU_LOOKUP($type) $id
	}

	set INITIALISED 1
}



# Requests an XML verification request for Datacash API
#
#	array_list - array of variables to bind into the XML request
#
proc ob_ovs_dcash::run_check {array_list} {

	return [_run_uru $array_list "check"]
}



# Requests an XML log request for Datacash API
#
#	returns - status (OB_OK denotes success) and array of log data if no error
#
proc ob_ovs_dcash::run_log {array_list} {

	return [_run_uru $array_list "log"]
}



# Constructs an XML request for Datacash API. Takes response and parses it for
# verification details.
#
#	returns - status (OB_OK denotes success) and array of log data if no error
#
proc ob_ovs_dcash::_run_uru {array_list type} {

	variable INITIALISED
	variable DCASH_DATA
	variable DCASH_XML_DOM
	variable DCASH_HTTP_TOKEN

	if {!$INITIALISED} {init}

	array set DCASH_DATA $array_list
	if {[info exists DCASH_XML_DOM]} {
		catch {$DCASH_XML_DOM delete}
	}

	set DCASH_DATA(merchantreference) [clock seconds]

	if {$type == "check"} {
		set err CHECK
	} else {
		set err LOG
	}

	# Pack the message
	if {[catch {

		set request [_${type}_msg_pack]

	} msg]} {

		catch {$DCASH_XML_DOM delete}

		ob_log::write ERROR {OVS_DCASH: Error building XML request: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_PACK
	}

	ob_log::write DEV {OVS_DCASH: sending $request}

	# Send the message
	if {[catch {

		set response [_msg_send $request]

	} msg]} {

		catch {::http::cleanup $DCASH_HTTP_TOKEN}

		ob_log::write ERROR {OVS_DCASH: Error sending XML request: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_SEND
	}

	ob_log::write DEV {OVS_DCASH: received $response}

	ob_log::write DEV {OVS_DCASH: unpacking $type message}

	# Unpack the message
	if {[catch {

		ob_log::write ERROR {OVS_DCASH: Response received - $response}

		set reference [_msg_unpack $response $type]

	} msg]} {

		catch {$DCASH_XML_DOM delete}

		ob_log::write ERROR {OVS_DCASH: _msg_unpack failed: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_UNPACK
	}

	set DCASH_DATA(URU,reference) $reference

	ob_log::write DEV {OVS_DCASH: finished $type successfully}

	return [list OB_OK [array get DCASH_DATA]]
}



# Constructs the XML for a check request to Datacash API
# NOTE: Calls to this function should be placed in a wrapper to catch any
# errors and delete the XML document
#
proc ob_ovs_dcash::_check_msg_pack {} {

	variable DCASH_CFG
	variable DCASH_DATA
	variable DCASH_REQUIRE_CV2
	variable DCASH_XML_DOM

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#	|--Transaction
	#	|  |--TxnDetails
	#	|     |--merchantreference
	#   |
	#	|--URUTxn
	#	  |--method
	#     |  |--"authenticate"
	#     |
	#     |--Basic
	#     | |--forename
	#     | |--middle_initial
	#     | |--surname
	#     | |--dob_day
	#     | |--dob_month
	#     | |--dob_year
	#     | |--gender
	#     |
	#     |--UKData
	#     | |--Address1
	#     | | |--postcode
	#     | | |--building_name
	#     | | |--building_no
	#     | | |--sub_building
	#     | | |--organisation
	#     | | |--street
	#     | | |--sub_street
	#     | | |--town
	#     | | |--district
	#     | | |--first_year_of_residence
	#     | | |--last_year_of_residence
	#     | |
	#     | |--Address2
	#     | | |--postcode
	#     | | |--building_name
	#     | | |--building_no
	#     | | |--sub_building
	#     | | |--organisation
	#     | | |--street
	#     | | |--sub_street
	#     | | |--town
	#     | | |--district
	#     | | |--first_year_of_residence
	#     | | |--last_year_of_residence
	#     | |
	#     | |--Address3
	#     | | |--postcode
	#     | | |--building_name
	#     | | |--building_no
	#     | | |--sub_building
	#     | | |--organisation
	#     | | |--street
	#     | | |--sub_street
	#     | | |--town
	#     | | |--district
	#     | | |--first_year_of_residence
	#     | | |--last_year_of_residence
	#     | |
	#     | |--Address4
	#     | | |--postcode
	#     | | |--building_name
	#     | | |--building_no
	#     | | |--sub_building
	#     | | |--organisation
	#     | | |--street
	#     | | |--sub_street
	#     | | |--town
	#     | | |--district
	#     | | |--first_year_of_residence
	#     | | |--last_year_of_residence
	#     | |
	#     | |--Passport
	#     | | |--number1
	#     | | |--number2
	#     | | |--number3
	#     | | |--number4
	#     | | |--number5
	#     | | |--number6
	#     | | |--expiry_day
	#     | | |--expiry_month
	#     | | |--expiry_year
	#     | |
	#     | |--Electric
	#     | | |--number1
	#     | | |--number2
	#     | | |--number3
	#     | | |--number4
	#     | | |--mail_sort
	#     | | |--postcode
	#     | |
	#     | |--Telephone exdirectory=''
	#     | | |--number
	#     | | |--active_month
	#     | | |--active_year
	#     | |
	#     | |--Birth
	#     | | |--mothers_maiden_name
	#     | | |--country_of_birth
	#     | |
	#     | |--Driver
	#     |   |--number1
	#     |   |--number2
	#     |   |--number3
	#     |   |--number4
	#     |   |--mail_sort
	#     |   |--postcode
	#     |
	#     |--Employment
	#     | |--residence_type
	#     | |--employment_status
	#     | |--current_time
	#     |
	#     |--CreditDebitCard cardtype=''
	#     | |--card_number
	#     | |--card_expiry_date
	#     | |--card_issue_number
	#     | |--card_verification_code
	#

	if {[info exists DCASH_XML_DOM]} {
		catch {$DCASH_XML_DOM delete}
	}

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set DCASH_XML_DOM [dom createDocument "Request"]

	# Request
	set request [$DCASH_XML_DOM documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth   [$DCASH_XML_DOM createElement "Authentication"]
	set B_auth   [$request appendChild   $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach {auth_field auth_item} {
		client   chk_client
		password chk_pword
	} {
		set elem [$DCASH_XML_DOM createElement  $auth_field]
		set brch [$B_auth  appendChild    $elem]
		set txtn [$DCASH_XML_DOM createTextNode $DCASH_CFG($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_XML_DOM  createElement  "Transaction"]
	set B_trans  [$request  appendChild    $E_trans]

	# Request/Transaction/TxnDetails
	set E_txndt  [$DCASH_XML_DOM  createElement  "TxnDetails"]
	set B_txndt  [$B_trans  appendChild    $E_txndt]

	# Request/Transaction/TxnDetails/merchantreference
	set E_mref   [$DCASH_XML_DOM  createElement  "merchantreference"]
	set B_mref   [$B_txndt  appendChild    $E_mref]
	set txtn     [$DCASH_XML_DOM  createTextNode $DCASH_DATA(merchantreference)]
	$B_mref appendChild $txtn

	# Request/Transaction/URUTxn
	set E_urutxn [$DCASH_XML_DOM  createElement  "URUTxn"]
	set B_urutxn [$B_trans  appendChild    $E_urutxn]

	# Request/Transaction/URUTxn/method
	set E_mthd   [$DCASH_XML_DOM  createElement  "method"]
	set B_mthd   [$B_urutxn appendChild    $E_mthd]
	set T_mthd   [$DCASH_XML_DOM  createTextNode "authenticate"]
	$B_mthd appendChild $T_mthd

	# Request/Transaction/URUTxn/Basic
	set E_basic  [$DCASH_XML_DOM  createElement  "Basic"]
	set B_basic  [$B_urutxn appendChild    $E_basic]

	# Request/Transaction/URUTxn/Basic/forename
	# Request/Transaction/URUTxn/Basic/middle_initial
	# Request/Transaction/URUTxn/Basic/surname
	# Request/Transaction/URUTxn/Basic/dob_year
	# Request/Transaction/URUTxn/Basic/dob_month
	# Request/Transaction/URUTxn/Basic/dob_day
	# Request/Transaction/URUTxn/Basic/gender
	foreach basic_item {
		forename
		middle_initial
		surname
		dob_year
		dob_month
		dob_day
		gender
	} {

		if {$DCASH_DATA($basic_item) != ""} {
			set elem [$DCASH_XML_DOM createElement  $basic_item]
			set brch [$B_basic appendChild    $elem]
			set txtn [$DCASH_XML_DOM createTextNode $DCASH_DATA($basic_item)]
			$brch appendChild $txtn
		}
	}

	set E_ukdata [$DCASH_XML_DOM createElement "UKData"]
	set B_ukdata [$E_urutxn appendChild $E_ukdata]

	if {[OT_CfgGet USE_SET_ADDRESS_COUNT 0]} {
		set DCASH_DATA(address_count) [OT_CfgGet SET_ADDRESS_COUNT 0]
	}

	for {set i 1} {$i <= $DCASH_DATA(address_count)} {incr i} {
		# Request/Transaction/URUTxn/AddressN
		set E_addr($i) [$DCASH_XML_DOM createElement "Address$i"]
		set B_addr($i) [$E_ukdata appendChild $E_addr($i)]

		# Request/Transaction/URUTxn/UKData/AddressN/postcode
		# Request/Transaction/URUTxn/UKData/AddressN/building_name
		# Request/Transaction/URUTxn/UKData/AddressN/building_no
		# Request/Transaction/URUTxn/UKData/AddressN/sub_building
		# Request/Transaction/URUTxn/UKData/AddressN/organisation
		# Request/Transaction/URUTxn/UKData/AddressN/street
		# Request/Transaction/URUTxn/UKData/AddressN/sub_street
		# Request/Transaction/URUTxn/UKData/AddressN/town
		# Request/Transaction/URUTxn/UKData/AddressN/district
		# Request/Transaction/URUTxn/UKData/AddressN/first_year_of_residence
		# Request/Transaction/URUTxn/UKData/AddressN/last_year_of_residence
		foreach addr_item {
			postcode
			building_name
			building_no
			sub_building
			organisation
			street
			sub_street
			town
			district
			first_year_of_residence
			last_year_of_residence
		} {

			if {$DCASH_DATA(address${i},$addr_item) != ""} {
				set elem [$DCASH_XML_DOM createElement $addr_item]
				set brch [$B_addr($i) appendChild $elem]
				set txtn [$DCASH_XML_DOM createTextNode \
					               $DCASH_DATA(address${i},$addr_item)]
				$brch appendChild $txtn
			}
		}
	}

	if {$DCASH_DATA(driver,number1) != ""} {
		# Request/Transaction/URUTxn/Driver
		set E_driver [$DCASH_XML_DOM createElement "Driver"]
		set B_driver [$E_ukdata appendChild $E_driver]

		# Request/Transaction/URUTxn/UKData/Driver/number1
		# Request/Transaction/URUTxn/UKData/Driver/number2
		# Request/Transaction/URUTxn/UKData/Driver/number3
		# Request/Transaction/URUTxn/UKData/Driver/number4
		# Request/Transaction/URUTxn/UKData/Driver/mail_sort
		# Request/Transaction/URUTxn/UKData/Driver/postcode
		foreach driver_item {
			number1
			number2
			number3
			number4
			mail_sort
			postcode

		} {

			if {$DCASH_DATA(driver,$driver_item) != ""} {
				set elem [$DCASH_XML_DOM createElement $driver_item]
				set brch [$B_driver appendChild $elem]
				set txtn [$DCASH_XML_DOM \
					createTextNode \
					$DCASH_DATA(driver,$driver_item)]
				$brch appendChild $txtn
			}
		}
	}

	if {$DCASH_DATA(passport,number1) != ""} {
		# Request/Transaction/URUTxn/Passport
		set E_passport [$DCASH_XML_DOM  createElement "Passport"]
		set B_passport [$E_ukdata appendChild $E_passport]

		# Request/Transaction/URUTxn/UKData/Passport/number1
		# Request/Transaction/URUTxn/UKData/Passport/number2
		# Request/Transaction/URUTxn/UKData/Passport/number3
		# Request/Transaction/URUTxn/UKData/Passport/number4
		# Request/Transaction/URUTxn/UKData/Passport/number5
		# Request/Transaction/URUTxn/UKData/Passport/number6
		# Request/Transaction/URUTxn/UKData/Passport/expiry_day
		# Request/Transaction/URUTxn/UKData/Passport/expiry_month
		# Request/Transaction/URUTxn/UKData/Passport/expiry_year
		foreach passport_item {
			number1
			number2
			number3
			number4
			number5
			number6
			expiry_day
			expiry_month
			expiry_year
		} {

			if {$DCASH_DATA(passport,$passport_item) != ""} {
				set elem [$DCASH_XML_DOM createElement $passport_item]
				set brch [$B_passport appendChild $elem]
				set txtn [$DCASH_XML_DOM \
					createTextNode \
					$DCASH_DATA(passport,$passport_item)]
				$brch appendChild $txtn
			}
		}
	}

	if {$DCASH_DATA(electric,number1) != ""} {
		# Request/Transaction/URUTxn/Electric
		set E_electric [$DCASH_XML_DOM createElement "Electric"]
		set B_electric [$E_ukdata appendChild $E_electric]

		# Request/Transaction/URUTxn/UKData/Electric/number1
		# Request/Transaction/URUTxn/UKData/Electric/number2
		# Request/Transaction/URUTxn/UKData/Electric/number3
		# Request/Transaction/URUTxn/UKData/Electric/number4
		# Request/Transaction/URUTxn/UKData/Electric/mail_sort
		# Request/Transaction/URUTxn/UKData/Electric/postcode
		foreach electric_item {
			number1
			number2
			number3
			number4
			mail_sort
			postcode
		} {

			if {$DCASH_DATA(electric,$electric_item) != ""} {
				set elem [$DCASH_XML_DOM createElement $electric_item]
				set brch [$B_electric appendChild $elem]
				set txtn [$DCASH_XML_DOM \
					createTextNode \
					$DCASH_DATA(electric,$electric_item)]
				$brch appendChild $txtn
			}
		}
	}

	if {$DCASH_DATA(telephone,number) != ""} {
		# Request/Transaction/URUTxn/Telephone
		set E_telephone [$DCASH_XML_DOM createElement "Telephone"]
		set B_telephone [$E_ukdata appendChild $E_telephone]

		# Call: 20719 - exdirectory being unset
		if {$DCASH_DATA(telephone,exdirectory) == ""} {
			set DCASH_DATA(telephone,exdirectory) "no"
		}

		# Request/Transaction/URUTxn/UKData/Telephone/exdirectory
		$E_telephone setAttribute "exdirectory" $DCASH_DATA(telephone,exdirectory)

		# Request/Transaction/URUTxn/UKData/Telephone/number
		# Request/Transaction/URUTxn/UKData/Telephone/active_month
		# Request/Transaction/URUTxn/UKData/Telephone/active_year
		foreach telephone_item {
			number
			active_month
			active_year
		} {

			if {$DCASH_DATA(telephone,$telephone_item) != ""} {
				set elem [$DCASH_XML_DOM createElement $telephone_item]
				set brch [$B_telephone appendChild $elem]
				set txtn [$DCASH_XML_DOM \
					createTextNode \
					$DCASH_DATA(telephone,$telephone_item)]
				$brch appendChild $txtn
			}
		}
	}

	if {$DCASH_DATA(card,number) != ""} {
		# Request/Transaction/URUTxn/Telephone
		set E_creditdebit [$DCASH_XML_DOM createElement "CreditDebitCard"]
		set B_creditdebit [$E_urutxn appendChild $E_creditdebit]

		# Request/Transaction/URUTxn/CreditDebitCard/cardtype
		$E_creditdebit setAttribute "cardtype" $DCASH_DATA(card,type)

		# Request/Transaction/URUTxn/CreditDebitCard/card_number
		# Request/Transaction/URUTxn/CreditDebitCard/card_expiry_date
		# Request/Transaction/URUTxn/CreditDebitCard/card_issue_number
		# Request/Transaction/URUTxn/CreditDebitCard/card_verification_code
		foreach card_item {
			number
			expiry_date
			issue_number
			verification_code
		} {

			if {$DCASH_DATA(card,$card_item) != ""} {
				set elem [$DCASH_XML_DOM createElement card_$card_item]
				set brch [$B_creditdebit appendChild $elem]
				set txtn [$DCASH_XML_DOM \
					createTextNode \
					$DCASH_DATA(card,$card_item)]
				$brch appendChild $txtn
			}
		}
	}

	# Convert to text
	set request "<?xml version=\"1.0\" encoding=\"UTF-8\"?> [$DCASH_XML_DOM asXML]"

	$DCASH_XML_DOM delete

	return $request
}



# Constructs the XML for a log request to Datacash API
# NOTE: Calls to this function should be placed in a wrapper to catch any
# errors and delete the XML document
#
proc ob_ovs_dcash::_log_msg_pack {} {

	variable DCASH_CFG
	variable DCASH_DATA
	variable DCASH_XML_DOM

	# REQUEST
	#   |--Authentication
	#   | |--client
	#   | |--password
	#   |
	#	|--Transaction
	#	|  |--TxnDetails
	#	|     |--merchantreference
	#   |
	#	|--URUTxn
	#	  |--method
	#     |  |--"get_log_by_authentication_id"
	#     |
	#     |--guid

	if {[info exists DCASH_XML_DOM]} {
		catch {$DCASH_XML_DOM delete}
	}

	dom setResultEncoding "UTF-8"

	# Request
	set DCASH_XML_DOM [dom createDocument "Request"]
	set request     [$DCASH_XML_DOM documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Authentication
	set E_auth [$DCASH_XML_DOM createElement "Authentication"]
	set B_auth [$request appendChild $E_auth]

	# Request/Authentication/client
	# Request/Authentication/password
	foreach {auth_field auth_item} {
		client   provider_uname
		password provider_passwd
	} {
		set elem [$DCASH_XML_DOM createElement  $auth_field]
		set brch [$B_auth      appendChild    $elem]
		set txtn [$DCASH_XML_DOM createTextNode $DCASH_DATA($auth_item)]
		$brch appendChild $txtn
	}

	# Request/Transaction
	set E_trans  [$DCASH_XML_DOM createElement "Transaction"]
	set B_trans  [$request     appendChild   $E_trans]

	# Request/Transaction/TxnDetails
	set E_txndt  [$DCASH_XML_DOM createElement "TxnDetails"]
	set B_txndt  [$B_trans     appendChild   $E_txndt]

	# Request/Transaction/TxnDetails/merchantreference
	set E_mref   [$DCASH_XML_DOM createElement  "merchantreference"]
	set B_mref   [$B_txndt     appendChild    $E_mref]
	set txtn     [$DCASH_XML_DOM createTextNode $DCASH_DATA(merchantreference)]
	$B_mref appendChild $txtn

	# Request/Transaction/URUTxn
	set E_urutxn [$DCASH_XML_DOM  createElement  "URUTxn"]
	set B_urutxn [$B_trans      appendChild    $E_urutxn]

	# Request/Transaction/URUTxn/method
	set E_mthd   [$DCASH_XML_DOM  createElement  "method"]
	set B_mthd   [$B_urutxn     appendChild    $E_mthd]
	set T_mthd   [$DCASH_XML_DOM  createTextNode "get_log_by_authentication_id"]
	$B_mthd appendChild $T_mthd

	# Request/Transaction/URUTxn/guid
	set E_mthd   [$DCASH_XML_DOM  createElement  "guid"]
	set B_mthd   [$B_urutxn     appendChild    $E_mthd]
	set T_mthd   [$DCASH_XML_DOM  createTextNode $DCASH_DATA(authentication_id)]
	$B_mthd appendChild $T_mthd

	set xml_msg  [$DCASH_XML_DOM asXML]

	$DCASH_XML_DOM delete

	return "<?xml version=\"1.0\" encoding=\"UTF-8\"?> $xml_msg"
}



# Unpacks an XML response from the Datacash server, adding the elements to an
# array.
#
# NOTE: Must be wrapped in a catch statement that ensures that variable
# DCASH_XML_DOM is wiped if an error occurs
#
#	xml     - XML response to unpack
#	type    - Code showing whether XML is from a check response (check) or a log
#	          response (log).
#
#	returns - unique reference
#
proc ob_ovs_dcash::_msg_unpack {xml type} {

	variable DCASH_DATA
	variable URU_LOOKUP
	variable DCASH_XML_DOM

	# RESPONSE (GOOD)
	#   |--datacash_reference
	#   |--status
	#   |--merchantreference
	#   |--reason
	#   |--mode
	#   |
	#	|--URUTxn
	#     |--customer_ref
	#     |--ProfileId
	#     |--ProfileVersion
	#     |--profile_revision
	#	  |--authentication_id
	#	  |--authentication_count
	#     |--timestamp
	#     |--score
	#     |
	#     |--Results
	#     | |--URULogResult
	#     |   |--uru_id
	#     |   |--code
	#     |   |--text
	#     |
	#     |--UserData ...
	#
	ob_log::write DEBUG {OVS_DCASH: unpacking $xml}

	set DCASH_XML_DOM [dom parse $xml]

	ob_log::write DEBUG {OVS_DCASH: parsed XML}

	set Response [$DCASH_XML_DOM documentElement]

	ob_log::write DEBUG {OVS_DCASH: found root element}

	# Response/datacash_reference
	# Response/status
	# Response/merchantreference
	# Response/reason
	# Response/mode

	foreach item {
		merchantreference
		datacash_reference
		status
		reason
		mode
	} {
		set element [$Response getElementsByTagName $item]
		if {$element == ""} {
			error "Missing element Response/$element"
		}
		set $item [[$element firstChild] nodeValue]
		ob_log::write DEBUG {OVS_DCASH: $item = [set $item]}
	}

	# If status is not 1
	# Response/information
	if {$status != 1} {
		set element [$Response getElementsByTagName information]
		if {$element == ""} {
			error "Missing element Response/information"
		}
		set information [[$element firstChild] nodeValue]
		error "Query failed with error code $status."
	}
	# Response/URUTxn/customer_ref
	# Response/URUTxn/profile_id
	# Response/URUTxn/profile_version
	# Response/URUTxn/profile_revision
	# Response/URUTxn/timestamp
	# Response/URUTxn/score

	set fields [list \
		customer_ref \
		profile_id \
		profile_version \
		profile_revision \
		timestamp \
		score]

	if {$type == "check"} {
		# Specific for check requests
		# Response/URUTxn/timestamp
		# Response/URUTxn/authentication_id
		# Response/URUTxn/authentication_count

		lappend fields \
			timestamp \
			authentication_id \
			authentication_count

	} else {
		# Specific for log requests
		# Response/URUTxn/state

		lappend fields \
			timestamp \
			authentication_id \
			state
	}

	set URUTxn [$Response getElementsByTagName "URUTxn"]

	if {[llength $URUTxn] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn"
	}

	foreach item $fields {
		set element [$URUTxn getElementsByTagName $item]

		if {$element == ""} {
			error "Bad XML format. Unable to retrieve Response/URUTxn/$item"
		}

		set $item [[$element firstChild] nodeValue]

		if {[set $item] == ""} {
			# This element is compulsory
			error "Bad XML format. Unable to retrieve Response/URUTxn/$item"
		}
		set DCASH_DATA(URU,$item) [set $item]
	}

	# Response/URUTxn/Results
	set Results [$URUTxn getElementsByTagName "Results"]

	if {[llength $Results] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn/Results"
	}
	set DCASH_RESP(uru_ids) [list]

	if {$type == "check"} {
		set result_field "URUResult2"
	} else {
		set result_field "URULogResult"
	}
	# Response/URUTxn/Results/$result_field
	set result_list [$Results getElementsByTagName $result_field]
	if {[llength $result_list] < 1} {
		error "Bad XML format. Unable to retrieve Response/URUTxn/$result_field"
	}
	ob_log::write DEBUG {OVS_DCASH: Received [llength $result_list] results}
	foreach result_item $result_list {

		# Response/URUTxn/Results/$result_field/uru_id
		# Response/URUTxn/Results/$result_field/code
		# Response/URUTxn/Results/$result_field/text
		foreach item {
			uru_id
			code
			text
		} {
			set item_desc "Response/URUTxn/Results/$result_field/$item"
			set element [$result_item getElementsByTagName $item]

			if {$element == ""} {
				error "Bad XML format. Unable to retrieve $item_desc"
			}

			set $item [[$element firstChild] nodeValue]

			if {[set $item] == ""} {
				# These elements are compulsory and should appear at least once
				error "Bad XML format. Unable to retrieve $item_desc"
			}
		}
		set DCASH_RESP($uru_id,$code) $text
		lappend DCASH_RESP($uru_id,codes) $code
		if {[lsearch $DCASH_RESP(uru_ids) $uru_id] == -1} {
			lappend DCASH_RESP(uru_ids) $uru_id
		}
	}

	lsort DCASH_RESP(uru_ids)

	foreach check_type $DCASH_DATA(URU,checks) {

		set uru_id $URU_LOOKUP($check_type)

		if {[info exists DCASH_RESP($uru_id,codes)]} {
			set DCASH_DATA($check_type,responses) $DCASH_RESP($uru_id,codes)
		} else {
			set DCASH_DATA($check_type,responses) [list]
		}
	}

	# If we're running a verification we're done
	if {$type == "check"} {
		$DCASH_XML_DOM delete
		return $DCASH_DATA(URU,authentication_id)
	}

	# If it's a log request we're processing, though there's still the user
	# data to process
	# Response/URUTxn/UserData
	set UserData [$URUTxn getElementsByTagName "UserData"]

	if {[llength $UserData] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn/UserData: $msg"
	}

	# Response/URUTxn/UserData/Basic
		set Basic [$UserData getElementsByTagName "Basic"]

	if {[llength $Basic] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn/UserData/Basic"
	}
	# Response/URUTxn/UserData/Basic/forename
	# Response/URUTxn/UserData/Basic/middle_initial
	# Response/URUTxn/UserData/Basic/surname
	# Response/URUTxn/UserData/Basic/dob_year
	# Response/URUTxn/UserData/Basic/dob_month
	# Response/URUTxn/UserData/Basic/dob_day
	# Response/URUTxn/UserData/Basic/gender
	foreach basic_item {
		forename
		middle_initial
		surname
		dob_year
		dob_month
		dob_day
		gender
	} {
		set basic_list [$Basic getElementsByTagName $basic_item]
		set item_desc  "Response/URUTxn/UserData/Basic/$basic_item"

		if {[llength $basic_list] == 1} {

			set element [$basic_list firstChild]

			if {$element == ""} {
				error "Bad XML format. Unable to retrieve $item_desc"
			}

			set DCASH_DATA($basic_item) [$element nodeValue]
			ob_log::write DEBUG \
				{OVS_DCASH: $basic_item $DCASH_DATA($basic_item)}
		}
	}

	set DCASH_DATA(address_count) 0

	for {set i 1} {$i <= 4} {incr i} {

		# Response/URUTxn/UserData/AddressN

		set Address$i [$UserData getElementsByTagName "Address$i"]

		if {[llength [set Address$i]] == 1} {

			incr DCASH_DATA(address_count)
			ob_log::write DEBUG \
				{OVS_DCASH: address_count = $DCASH_DATA(address_count)}

			# Response/URUTxn/UserData/AddressN/postcode
			# Response/URUTxn/UserData/AddressN/building_name
			# Response/URUTxn/UserData/AddressN/building_no
			# Response/URUTxn/UserData/AddressN/sub_building
			# Response/URUTxn/UserData/AddressN/organisation
			# Response/URUTxn/UserData/AddressN/street
			# Response/URUTxn/UserData/AddressN/sub_street
			# Response/URUTxn/UserData/AddressN/town
			# Response/URUTxn/UserData/AddressN/district
			# Response/URUTxn/UserData/AddressN/first_year_of_residence
			# Response/URUTxn/UserData/AddressN/last_year_of_residence
			foreach addr_item {
				postcode
				building_name
				building_no
				sub_building
				organisation
				street
				sub_street
				town
				district
				first_year_of_residence
				last_year_of_residence
			} {
				set addr_list [[set Address$i] getElementsByTagName $addr_item]

				if {[llength $addr_list] == 1} {
					set child [$addr_list firstChild]

					if {$child != ""} {
						set DCASH_DATA(address$i,$addr_item) [$child nodeValue]
						set log_text {OVS_DCASH: address$i,$addr_item}
						append log_text {$DCASH_DATA(address$i,$addr_item)}
						ob_log::write DEBUG $log_text
					}
				}
			}
		}
	}

	set Driver [$UserData getElementsByTagName "Driver"]

	if {[llength $Driver] == 1} {

		# Response/URUTxn/UserData/Driver/number1
		# Response/URUTxn/UserData/Driver/number2
		# Response/URUTxn/UserData/Driver/number3
		# Response/URUTxn/UserData/Driver/number4
		# Response/URUTxn/UserData/Driver/mail_sort
		# Response/URUTxn/UserData/Driver/postcode
		foreach driver_item {
			number1
			number2
			number3
			number4
			mail_sort
			postcode

		} {
			set driver_list [$Driver getElementsByTagName $driver_item]

			if {[llength $driver_list] == 1} {
				set child [$driver_list firstChild]

				if {$child != ""} {
					set DCASH_DATA(driver,$driver_item) [$child nodeValue]
					set info_text {OVS_DCASH: driver,$driver_item}
					append info_text {$DCASH_DATA(driver,$driver_item)}
					ob_log::write DEBUG $info_text
				}
			}
		}
	}

	set Passport [$UserData getElementsByTagName "Passport"]

	if {[llength $Passport] == 1} {

		# Response/URUTxn/UserData/Passport/number1
		# Response/URUTxn/UserData/Passport/number2
		# Response/URUTxn/UserData/Passport/number3
		# Response/URUTxn/UserData/Passport/number4
		# Response/URUTxn/UserData/Passport/number5
		# Response/URUTxn/UserData/Passport/number6
		# Response/URUTxn/UserData/Passport/expiry_day
		# Response/URUTxn/UserData/Passport/expiry_month
		# Response/URUTxn/UserData/Passport/expiry_year
		foreach passport_item {
			number1
			number2
			number3
			number4
			number5
			number6
			expiry_day
			expiry_month
			expiry_year
		} {
			set passport_list [$Passport getElementsByTagName $passport_item]

			if {[llength $passport_list] == 1} {
				set child [$passport_list firstChild]

				if {$child != ""} {
					set DCASH_DATA(passport,$passport_item) [$child nodeValue]
					set info_text {OVS_DCASH: passport,$passport_item}
					append info_text {$DCASH_DATA(passport,$passport_item)}
					ob_log::write DEBUG $info_text
				}
			}
		}
	}

	set Electric [$UserData getElementsByTagName "Electric"]

	if {[llength $Electric] == 1} {

		# Response/URUTxn/UserData/Electric/number1
		# Response/URUTxn/UserData/Electric/number2
		# Response/URUTxn/UserData/Electric/number3
		# Response/URUTxn/UserData/Electric/number4
		# Response/URUTxn/UserData/Electric/mail_sort
		# Response/URUTxn/UserData/Electric/postcode
		foreach electric_item {
			number1
			number2
			number3
			number4
			mail_sort
			postcode
		} {
			set electric_list [$Electric getElementsByTagName $electric_item]

			if {[llength $electric_list] == 1} {
				set child [$electric_list firstChild]

				if {$child != ""} {
					set DCASH_DATA(electric,$electric_item) [$child nodeValue]
					set info_text {OVS_DCASH: electric,$electric_item}
					append info_text {$DCASH_DATA(electric,$electric_item)}
					ob_log::write DEBUG $info_text
				}
			}
		}
	}

	set Telephone [$UserData getElementsByTagName "Telephone"]

	if {[llength $Telephone] == 1} {

		set DCASH_DATA(telephone,exdirectory)\
			[$Telephone getAttribute "exdirectory"]

		# Response/URUTxn/UserData/Telephone/number
		# Response/URUTxn/UserData/Telephone/active_month
		# Response/URUTxn/UserData/Telephone/active_year
		foreach telephone_item {
			number
			active_month
			active_year
		} {
			set telephone_list [$Telephone \
				getElementsByTagName \
				$telephone_item]

			if {[llength $telephone_list] == 1} {
				set child [$telephone_list firstChild]

				if {$child != ""} {
					set DCASH_DATA(telephone,$telephone_item) [$child nodeValue]
					set info_text {OVS_DCASH: telephone,$telephone_item}
					append info_text {$DCASH_DATA(telephone,$telephone_item)}
					ob_log::write DEBUG $info_text
				}
			}
		}
	}

	set Card [$UserData getElementsByTagName "CreditDebitCard"]

	if {[llength $Card] == 1} {

		# Response/URUTxn/UserData/CreditDebitCard/cardtype
		#set DCASH_DATA(card,type) [$Card getAttribute "cardtype"]

		# Response/URUTxn/UserData/CreditDebitCard/card_number
		# Response/URUTxn/UserData/CreditDebitCard/card_expiry_date
		# Response/URUTxn/UserData/CreditDebitCard/card_issue_number
		# Response/URUTxn/UserData/CreditDebitCard/card_verification_code
		foreach card_item {
			cardtype
			card_number
			card_expiry_date
			card_issue_number
			card_verification_code
		} {
			set card_list [$Card \
				getElementsByTagName \
				$card_item]

			if {[llength $card_list] == 1} {
				set child [$card_list firstChild]

				if {$child != ""} {
					set DCASH_DATA(card,$card_item) [$child nodeValue]
					set info_text {OVS_DCASH: card,$card_item}
					append info_text {$DCASH_DATA(card,$card_item)}
					ob_log::write DEBUG $info_text
				}
			}
		}
	}
	$DCASH_XML_DOM delete

	return $DCASH_DATA(URU,authentication_id)
}



# Sends an XML request to the Datacash API
# NOTE: All errors from this procedure should be caught and the HTTP token deleted
#
#	request - XML request to be sent
#
#	returns - response message body
#
proc ob_ovs_dcash::_msg_send {request} {

	variable DCASH_CFG
	variable DCASH_DATA
	variable DCASH_HTTP_TOKEN

	#! UTF-8 encoding - the nuclear option
	#
	# strips any non-ASCII characters - this is unfortunately the only option
	# available to us as we cannot work out what character encoding the data is
	# in (eg, if the request is from the portal, it may be in the user's
	# language encoding - but if it came from OXi XML, it may already be in
	# UTF-8)
	if {[regexp {[^\n\040-\176]} $request]} {
		set count [regsub -all {[^\n\040-\176]} $request {} request]
		ob_log::write WARN \
			{Warning: stripped $count non-ASCII character(s) from request}
	}

	set DCASH_HTTP_TOKEN [::http::geturl \
		$PROVEURU_DATA(provider_uri) \
		-query $request \
		-timeout $DCASH_CFG(timeout)]

	set ncode [::http::ncode $DCASH_HTTP_TOKEN]

	ob_log::write DEV {OVS_DCASH: status = [::http::status $DCASH_HTTP_TOKEN]}

	set body [::http::data $DCASH_HTTP_TOKEN]

	::http::cleanup $DCASH_HTTP_TOKEN

	if {$ncode != "200"} {
		ob_log::write DEV {OVS_DCASH: body = $body}
		error "OVS_DCASH: Error sending verification request: $ncode"
	}

	return $body
}
