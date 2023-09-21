# $Id: proveURU.tcl,v 1.1 2011/10/04 12:40:40 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to the ProveURU verification (Direct webservice)
#
# Provides an XML client for the ProveURU systems directly avoid the
# need to use the datacache interface.  Allows customer details to be
# verified and the result interpreted by the ProveURU system.  Furthermore
# ProvoURU provides the ability for oldersearches to be retrieved
# from ProveURU logs.
#
# Synopsis:
#	package require ovs_datacash
#
# Configurations:
#
#	OVS_PROVEURU_TIMEOUT    timeout        (10000)
#	OVS_PROVEURU_VERSION    version        (6c)
#	Cunningly enough, the test/Pilot environment runs a different
#	version of the engine (6d) to the live environment (6c), which is not
#       backwards compatible. Set this to 6d to run on pilot
#
# Procedures:
#	ob_ovs_proveuru::init             - one initialisation for package
#	ob_ovs_proveuru::_build_log_xml   - initialise datacash gateway settings
#	ob_ovs_proveuru::_build_check_xml - pass details for verification request and parse
#	                                    response
#	ob_ovs_proveuru::_msg_send        - pass details for verification log request and parse
#	                                    response
#	_msg_unpack
#	ob_ovs_proveuru::_convert_data    - Converts from OVS format to ProveURU compatiable data format
#	ob_ovs_proveuru::_destroy_message - Util for releasing the XML DOM after use
#
package provide ovs_proveuru 4.5



# Dependencies
#
package require tls
package require http 2.3
package require tdom
package require util_db
package require util_log

# Variables
#
namespace eval ob_ovs_proveuru {

	variable INITIALISED
	set INITIALISED 0

	variable URU_LOOKUP
	array set URU_LOOKUP {}
}



# One time initialisation
#
proc ob_ovs_proveuru::init {} {

	global auto_path
	variable INITIALISED

	if {$INITIALISED} {return}

	ob_log::write DEV "Initialising ProveURU"

	::http::register https 443 ::tls::socket

	variable PROVEURU_CFG
	variable URU_LOOKUP

	catch {unset PROVEURU_CFG}

	foreach item [list \
		timeout \
		uru_ids] {

		set config OVS_PROVEURU_[string toupper $item]
		set PROVEURU_CFG($item) [OT_CfgGet $config]
		if {$PROVEURU_CFG($item) == ""} {
			error "$config value missing from configuration file"
		}

	}

	set PROVEURU_CFG(version) [OT_CfgGet OVS_PROVEURU_VERSION "6c"]

	foreach [list type id] $PROVEURU_CFG(uru_ids) {
		set URU_LOOKUP($type) $id
	}

	set INITIALISED 1
}



# Requests an XML verification request for ProveURU API
#
#	array_list - array of variables to bind into the XML request
#
proc ob_ovs_proveuru::run_check {array_list} {
	OT_LogWrite 10 "Running proveURU Check operation"
	return [_run_proveuru $array_list "check"]
}



# Requests an XML log request for ProveURU API
#
#	returns - status (OB_OK denotes success) and array of log data if no error
#
proc ob_ovs_proveuru::run_log {array_list} {
	OT_LogWrite 10 "Running proveURU log operation"
	return [_run_proveuru $array_list "log"]
}



# Constructs an XML request for ProveURU API. Takes response and parses it for
# verification details.
#
#	returns - status (OB_OK denotes success) and array of log data if no error
#
proc ob_ovs_proveuru::_run_proveuru {array_list type} {

	variable INITIALISED
	variable PROVEURU_DATA
	variable DCASH_DATA
	variable PROVEURU_XML_DOM
	variable URU_HTTP_TOKEN

	if {!$INITIALISED} {init}

	#Convert DCASH to PROVEURU format
	array set PROVEURU_DATA $array_list
	array set PROVEURU_DATA [_convert_data [array get PROVEURU_DATA]]

	#Initialise the XML DOM
	if {[info exists PROVEURU_XML_DOM]} {
		catch {$PROVEURU_XML_DOM delete}
	}

	set PROVEURU_DATA(merchantreference) [clock seconds]

	if {$type == "check"} {
		set err CHECK
	} else {
		set err LOG
	}

	# Pack the message
	if {[catch {

		set request [_${type}_msg_pack]

	} msg]} {

		catch {$PROVEURU_XML_DOM delete}

		ob_log::write ERROR {OVS_PROVEURU: Error building XML request: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_PACK
	}

	ob_log::write DEV {OVS_PROVEURU: sending to $PROVEURU_DATA(provider_uri) \n[_hide_message $request]}

	# Send the message
	if {[catch {

		set response [_msg_send $request]

	} msg]} {

		catch {::http::cleanup $URU_HTTP_TOKEN}

		ob_log::write ERROR {OVS_PROVEURU: Error sending XML request: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_SEND
	}

	ob_log::write DEV {OVS_PROVEURU: received [_hide_message $response]}

	ob_log::write DEV {OVS_PROVEURU: unpacking $type message}

	if {[catch {
		ob_log::write ERROR {OVS_PROVEURU: Response received - [_hide_message $response]}

		#Unpack the proveURU SOAP response
		set reference [_msg_unpack $response $type]
	} msg]} {
		catch {$PROVEURU_XML_DOM delete}
		ob_log::write ERROR {OVS_PROVEURU: _msg_unpack failed: $msg}
		return OB_ERR_OVS_DCASH_${err}_MSG_UNPACK
	}

	#Finish Up Everything
	set PROVEURU_DATA(URU,reference) $reference
	ob_log::write DEV {OVS_PROVEURU: finished $type successfully}

	#Send back the data
	return [list OB_OK [array get PROVEURU_DATA]]
}



# Constructs the XML for a log request to ProveURU API
# NOTE: Calls to this function should be placed in a wrapper to catch any
# errors and delete the XML document
#
# The comment Request equals the following for brevity
#   soap:Envelope/soap:Body/LogonAndGetLogByAuthenticationId
#
proc ob_ovs_proveuru::_log_msg_pack {} {
	variable PROVEURU_CFG
	variable PROVEURU_DATA

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set PROVEURU_XML_DOM [dom createDocument "soapenv:Envelope"]

	set E_env [$PROVEURU_XML_DOM documentElement]

	# URU test (Pilot) environment uses 6d, which has different tags
	#
	if {$PROVEURU_CFG(version) == "6c"} {
		$E_env setAttribute \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
		"xmlns:urul"    "https://www.prove-uru.co.uk/URULog/URULogWS6c.asmx"
	} else {
		$E_env setAttribute \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
		"xmlns:urul"    "https://www.prove-uru.co.uk/URULog/URULogWS6d.asmx"
	}

	set E_body [$PROVEURU_XML_DOM createElement "soapenv:Body"]
	set B_body [$E_env appendChild $E_body]

	#Request
	set E_auth [$PROVEURU_XML_DOM createElement "urul:LogonAndGetLogByAuthenticationId"]
	set B_auth [$E_body appendChild $E_auth]

	# Request/AccountName
	set E_account [$PROVEURU_XML_DOM createElement "urul:AccountName"]
	set B_account [$E_auth appendChild $E_account]
	set T_account [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(provider_uname)]
	$B_account appendChild $T_account

	# Request/Password
	set E_pwd [$PROVEURU_XML_DOM createElement "urul:Password"]
	set B_pwd [$E_auth appendChild $E_pwd]
	set T_pwd [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(provider_passwd)]
	$B_pwd appendChild $T_pwd

	# Request/AuthenticationId
	set E_auth_id [$PROVEURU_XML_DOM createElement "urul:AuthenticationId"]
	set B_auth_id [$E_auth appendChild $E_auth_id]
	set T_auth_id [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(authentication_id)]
	$B_auth_id appendChild $T_auth_id

	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$PROVEURU_XML_DOM asXML]"

	$PROVEURU_XML_DOM delete

	return $xml_msg
}



# Constructs the XML for a check request to Datacash API
# NOTE: Calls to this function should be placed in a wrapper to catch any
# errors and delete the XML document
#
# The comment Request equals the following for brevity
#   soap:Envelope/soap:Body/AuthenticateByProfile
#
proc ob_ovs_proveuru::_check_msg_pack {} {
	variable PROVEURU_CFG
	variable PROVEURU_DATA

	#
	#  Add basic check items
	#
	#     |--Basic
	#     | |--Title
	#     | |--Forename
	#     | |--MiddleInitial
	#     | |--Surname
	#     | |--Gender
	#     | |--DOBYear
	#     | |--DOBMonth
	#     | |--DOBDay
	#     |--UKData
	#     | |--Address(x)  (where x is an address number up to a max of address_count)
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
	#     | | ....
	#     | |--Driver
	#     | | |--number1
	#     | | |--number2
	#     | | |--number3
	#     | | |--number4
	#     | | |--mail_sort
	#     | | |--postcode
	#     | | |--microfiche
	#     | | |--issue_day
	#     | | |--issue_month
	#     | | |--issue_year
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
	#     | |--Telephone
	#     | | |--number
	#     | | |--active_month
	#     | | |--active_year
	#     | | |--exdirectory
 	#     | |--Electric
	#     | | |--number1
	#     | | |--number2
	#     | | |--number3
	#     | | |--number4
	#     | | |--mail_sort
	#     | | |--postcode
	#     | |--CreditDebitCard
	#     | | |--card_number
	#     | | |--card_expiry_date
	#     | | |--card_issue_number
	#     | | |--card_verification_code
	#     |--UKDATA
	#     |
	#     | USDATA
	#     | |-- International Passport
	#     | | |--number1
	#     | | |--number2
	#     | | |--number3
	#     | | |--number4
	#     | | |--number5
	#     | | |--number6
	#     | | |--number7
	#     | | |--number8
	#     | | |--number9
	#     | | |--expiry_day
	#     | | |--expiry_month
	#     | | |--expiry_year
	#     | | |--country_of_origin
	#     | USDATA

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set PROVEURU_XML_DOM [dom createDocument "soapenv:Envelope"]

	# Request
	set E_env [$PROVEURU_XML_DOM documentElement]

	#Different xml namespace for log and check messages
	 if {$PROVEURU_CFG(version) == "6c"} {
		$E_env setAttribute \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
		"xmlns:uru6"    "https://www.prove-uru.co.uk/URUWS/URU6c.asmx"
	} else {
		$E_env setAttribute \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
		"xmlns:uru6"    "https://www.prove-uru.co.uk/URUWS/URU6d.asmx"
	}

	set E_body [$PROVEURU_XML_DOM createElement "soapenv:Body"]
	set B_body [$E_env appendChild $E_body]

	# Request
	set E_auth [$PROVEURU_XML_DOM createElement "uru6:AuthenticateByProfile"]
	set B_auth [$E_body appendChild $E_auth]

	# Request/userdata
	if {$PROVEURU_CFG(version) == "6c"} {
		set E_user [$PROVEURU_XML_DOM createElement "uru6:userdata"]
	} else {
		set E_user [$PROVEURU_XML_DOM createElement "uru6:UserData"]
	}
	set B_user [$E_auth appendChild $E_user]

	# Request/userdata/Basic
	set E_basic [$PROVEURU_XML_DOM createElement "uru6:Basic"]
	set B_basic [$E_user appendChild $E_basic]

	# Request/Userdata/Basic/Title
	# Request/Userdata/Basic/Forename
	# Request/Userdata/Basic/MiddleInitial
	# Request/Userdata/Basic/Surname
	# Request/Userdata/Basic/Gender
	# Request/Userdata/Basic/DOBDay
	# Request/Userdata/Basic/DOBMonth
	# Request/Userdata/Basic/DOBYear
	foreach basic_item {
		Title
		Forename
		MiddleInitial
		Surname
		Gender
		DOBDay
		DOBMonth
		DOBYear
	} {
		if {$PROVEURU_DATA($basic_item) != ""} {
			set E_node [$PROVEURU_XML_DOM createElement "uru6:$basic_item"]
			set B_node [$E_basic appendChild $E_node]
			set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA($basic_item)]
			$B_node appendChild $T_node
		}
	}

	# Retrieve the number of address to process from the Config file
	#
	if {[OT_CfgGet USE_SET_ADDRESS_COUNT 0]} {
		set PROVEURU_DATA(address_count) [OT_CfgGet SET_ADDRESS_COUNT 0]
	}

	# Request/Userdata/UKData
	set E_uk [$PROVEURU_XML_DOM createElement "uru6:UKData"]
	set B_uk [$E_user appendChild $E_uk]

	for {set i 1} {$i <= $PROVEURU_DATA(address_count)} {incr i} {
		# Request/Userdata/AddressN
		set E_addr1 [$PROVEURU_XML_DOM createElement "uru6:Address${i}"]
		set B_addr1 [$E_uk appendChild $E_addr1]

		# Request/Userdata/AddressN/FixedFormat
		set E_fixed1 [$PROVEURU_XML_DOM createElement "uru6:FixedFormat"]
		set B_fixed1 [$E_addr1 appendChild $E_fixed1]

		# Request/Userdata/UKData/AddressN/FixedFormat/Postcode
		# Request/Userdata/UKData/AddressN/FixedFormat/BuildingName
		# Request/Userdata/UKData/AddressN/FixedFormat/BuildingNo
		# Request/Userdata/UKData/AddressN/FixedFormat/SubBuilding
		# Request/Userdata/UKData/AddressN/FixedFormat/Organisation
		# Request/Userdata/UKData/AddressN/FixedFormat/Street
		# Request/Userdata/UKData/AddressN/FixedFormat/SubStreet
		# Request/Userdata/UKData/AddressN/FixedFormat/Town
		# Request/Userdata/UKData/AddressN/FixedFormat/District
		foreach addr_item {
			Postcode
			BuildingName
			BuildingNo
			SubBuilding
			Organisation
			Street
			SubStreet
			Town
			District
		} {
			if {$PROVEURU_DATA(address${i},$addr_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$addr_item"]
				set B_node [$E_fixed1 appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(address${i},$addr_item)]
				$B_node appendChild $T_node
			}
		}

		# Request/Userdata/UKData/AddressN/FirstYearOfResidence
		# Request/Userdata/UKData/AddressN/LastYearOfResidence
		foreach year {
			FirstYearOfResidence
			LastYearOfResidence
		} {
			if {$PROVEURU_DATA(address${i},$year) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$year"]
				set B_node [$E_addr1 appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(address${i},$year)]
				$B_node appendChild $T_node
			}
		}
	}

	# Driving Licence Check
	#
	if {$PROVEURU_DATA(driver,Number1) != ""} {
		# Request/Body/AuthenticateByProfile/userdata/UKData/Driver
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:Driver"]
		set B_cc [$E_uk appendChild $E_cc]

		# Request/Userdata/UKData/Driver/Number1
		# Request/Userdata/UKData/Driver/Number2
		# Request/Userdata/UKData/Driver/Number3
		# Request/Userdata/UKData/Driver/Number4
		# Request/Userdata/UKData/Driver/MailSort
		# Request/Userdata/UKData/Driver/Postcode
		# Request/Userdata/UKData/Driver/Microfiche
		# Request/Userdata/UKData/Driver/IssueDay
		# Request/Userdata/UKData/Driver/IssueMonth
		# Request/Userdata/UKData/Driver/IssueYear
		foreach driver_item {
			Number1
			Number2
			Number3
			Number4
			MailSort
			Postcode
			Microfiche
			IssueDay
			IssueMonth
			IssueYear
		} {
			if {$PROVEURU_DATA(driver,$driver_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$driver_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(driver,$driver_item)]
				$B_node appendChild $T_node
			}
		}
	}

	#  Domestic Passport Check
	#
	if {$PROVEURU_DATA(passport,Number1) != ""} {

		# Request/Userdata/UKData/Passport
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:Passport"]
		set B_cc [$E_uk appendChild $E_cc]

		# Request/Userdata/UKData/Passport/Number1
		# Request/Userdata/UKData/Passport/Number2
		# Request/Userdata/UKData/Passport/Number3
		# Request/Userdata/UKData/Passport/Number4
		# Request/Userdata/UKData/Passport/Number5
		# Request/Userdata/UKData/Passport/Number6
		# Request/Userdata/UKData/Passport/ExpiryDay
		# Request/Userdata/UKData/Passport/ExpiryMonth
		# Request/Userdata/UKData/Passport/ExpiryYear
		foreach passport_item {
			Number1
			Number2
			Number3
			Number4
			Number5
			Number6
			ExpiryDay
			ExpiryMonth
			ExpiryYear
		} {
			if {$PROVEURU_DATA(passport,$passport_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$passport_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(passport,$passport_item)]
				$B_node appendChild $T_node
			}
		}
	}

	# Telephone Bill
	#
	if {$PROVEURU_DATA(telephone,Number) != ""} {
		# Request/Userdata/UKData/Telephone
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:Telephone"]
		set B_cc [$E_uk appendChild $E_cc]

		# Request/Userdata/UKData/Telephone/Number
		# Request/Userdata/UKData/Telephone/ActiveMonth
		# Request/Userdata/UKData/Telephone/ActiveYear
		# Request/Userdata/UKData/Telephone/ExDirectory
		foreach telephone_item {
			Number
			ActiveMonth
			ActiveYear
			ExDirectory
		} {
			if {$PROVEURU_DATA(telephone,$telephone_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$telephone_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(telephone,$telephone_item)]
				$B_node appendChild $T_node
			}
		}
	}

	# Electricity Bill
	#
	if {$PROVEURU_DATA(electric,Number1) != ""} {
		# Request/Userdata/UKData/Electric
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:Electric"]
		set B_cc [$E_uk appendChild $E_cc]

		# Request/Userdata/UKData/Electric/Number1
		# Request/Userdata/UKData/Electric/Number2
		# Request/Userdata/UKData/Electric/Number3
		# Request/Userdata/UKData/Electric/Number4
		# Request/Userdata/UKData/Electric/MailSort
		# Request/Userdata/UKData/Electric/Postcode
		foreach electric_item {
			Number1
			Number2
			Number3
			Number4
			MailSort
			Postcode
		} {
			if {$PROVEURU_DATA(electric,$electric_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$electric_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(electric,$electric_item)]
				$B_node appendChild $T_node
			}
		}
	}

	# Credit/Debit Card check
	#
	if {$PROVEURU_DATA(card,Number) != ""} {
		# Request/Userdata/UKData/CreditDebitCard
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:CreditDebitCard"]
		set B_cc [$E_user appendChild $E_cc]
		$E_creditdebit setAttribute "cardtype" $PROVEURU_DATA(card,type)

		# Request/Userdata/UKData/CreditDebitCard/Number
		# Request/Userdata/UKData/CreditDebitCard/ExpiryDate
		# Request/Userdata/UKData/CreditDebitCard/IssueNumber
		# Request/Userdata/UKData/CreditDebitCard/VerificationCode
		foreach card_item {
			Number
			ExpiryDate
			IssueNumber
			VerificationCode
		} {
			if {$PROVEURU_DATA(card,$card_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$card_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(card,$card_item)]
				$B_node appendChild $T_node
			}
		}
	}

	#  International Passport Check
	#
	if {$PROVEURU_DATA(passport_int,Number1) != ""} {
		# Request/Userdata/USData/InternationalPassport
		set E_cc [$PROVEURU_XML_DOM createElement "uru6:InternationalPassport"]
		set B_cc [$E_uk appendChild $E_cc]

		# Request/Userdata/USData/InternationalPassport/Number1
		# Request/Userdata/USData/InternationalPassport/Number2
		# Request/Userdata/USData/InternationalPassport/Number3
		# Request/Userdata/USData/InternationalPassport/Number4
		# Request/Userdata/USData/InternationalPassport/Number5
		# Request/Userdata/USData/InternationalPassport/Number6
		# Request/Userdata/USData/InternationalPassport/Number7
		# Request/Userdata/USData/InternationalPassport/Number8
		# Request/Userdata/USData/InternationalPassport/Number9
		# Request/Userdata/USData/InternationalPassport/ExpiryDay
		# Request/Userdata/USData/InternationalPassport/ExpiryMonth
		# Request/Userdata/USData/InternationalPassport/ExpiryYear
		# Request/Userdata/USData/InternationalPassport/CountryOfOrigin
		foreach intpassport_item {
			Number1
			Number2
			Number3
			Number4
			Number5
			Number6
			Number7
			Number8
			Number9
			ExpiryDay
			ExpiryMonth
			ExpiryYear
			CountryOfOrigin
		} {
			if {$PROVEURU_DATA(passport_int,$intpassport_item) != ""} {
				set E_node [$PROVEURU_XML_DOM createElement "uru6:$intpassport_item"]
				set B_node [$E_cc appendChild $E_node]
				set T_node [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(passport_int,$intpassport_item)]
				$B_node appendChild $T_node
			}
		}
	}

	# Request/ProfileId
	set E_account [$PROVEURU_XML_DOM createElement "uru6:ProfileId"]
	set B_account [$E_auth appendChild $E_account]
	set T_account [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(ext_profile_id)]
	$B_account appendChild $T_account

	# Request/AccountName
	set E_account [$PROVEURU_XML_DOM createElement "uru6:AccountName"]
	set B_account [$E_auth appendChild $E_account]
	set T_account [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(provider_uname)]
	$B_account appendChild $T_account

	# Request/Password
	set E_pwd [$PROVEURU_XML_DOM createElement "uru6:Password"]
	set B_pwd [$E_auth appendChild $E_pwd]
	set T_pwd [$PROVEURU_XML_DOM createTextNode $PROVEURU_DATA(provider_passwd)]
	$B_pwd appendChild $T_pwd

	# Convert to text
	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$PROVEURU_XML_DOM asXML]"

	$PROVEURU_XML_DOM delete

	return $xml_msg

}



# Sends an SOAP request to the ProveURU API
# NOTE: All errors from this procedure should be caught and the HTTP token deleted
#
#	request     - XML request to be sent
#	returns     - response message body
#
proc ob_ovs_proveuru::_msg_send {request} {

	variable PROVEURU_CFG
	variable PROVEURU_DATA
	variable URU_HTTP_TOKEN

	#! UTF-8 encoding - the nuclear option
	#
	# strips any non-ASCII characters - this is unfortunately the only option
	# available to us as we cannot work out what character encoding the data is
	# in (eg, if the request is from the portal, it may be in the user's
	# language encoding - but if it came from OXi XML, it may already be in
	# UTF-8)
	if {[regexp {[^\n\040-\176]} $request]} {
		set count [regsub -all {[^\n\040-\176]} $request {} request]
		ob_log::write ERROR {Warning: stripped $count non-ASCII character(s) from request}
	}

	set URU_HTTP_TOKEN [::http::geturl \
		$PROVEURU_DATA(provider_uri) \
		-query   $request \
		-type    "text/xml" \
		-headers "SOAPAction $PROVEURU_DATA(provider_action)" \
		-timeout $PROVEURU_CFG(timeout)]

	set ncode [::http::ncode $URU_HTTP_TOKEN]

	ob_log::write DEV {OVS_PROVEURU: status = [::http::status $URU_HTTP_TOKEN]}

	set body [::http::data $URU_HTTP_TOKEN]

	::http::cleanup $URU_HTTP_TOKEN

	if {$ncode != "200"} {
		ob_log::write DEV {OVS_PROVEURU: body = [_hide_message $body]}
		error "OVS_PROVEURU: Error sending verification request: $ncode"
	}

	return $body
}



# Unpacks an XML response from the ProveURU server, adding the elements to an
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
proc ob_ovs_proveuru::_msg_unpack {xml type} {
	variable PROVEURU_CFG
	variable PROVEURU_DATA
	variable URU_LOOKUP
	variable PROVEURU_XML_DOM

	# RESPONSE (GOOD)
	#  |--soap:Envelope
	#    |--soap:Body
	#      |--AuthenticateByProfileResponse
	#        |--customer_ref
	#        |--ProfileId
	#        |--ProfileVersion
	#        |--profile_revision
	#        |--authentication_id
	#        |--authentication_count
	#        |--timestamp
	#        |--score
	#        |
	#        |--Results
	#        | |--URULogResult
	#        |   |--uru_id
	#        |   |--code
	#        |   |--text
	ob_log::write DEV {OVS_PROVEURU: unpacking xml}

	set PROVEURU_XML_DOM [dom parse $xml]

	ob_log::write DEBUG {OVS_PROVEURU: parsed XML}

	set Response [$PROVEURU_XML_DOM documentElement]

	ob_log::write DEBUG {OVS_PROVEURU: found root element}

	# Response/soap:Envelope/soap:Body
	set Body [$Response selectNodes /soap:Envelope/soap:Body]

	set Response [$Body childNodes]
	set ResponseTag [lindex $Response 0]

	# Response/soap:Envelope/soap:Body/soap:Fault
	if {[$ResponseTag nodeName] == "soap:Fault"} {
		error {OVS_PROVEURU: Soap Fault Received}
	}

	# Get the Soap Action, this should be one of
	#   AuthenticateByProfile
	#   LoginAndGetLogByAuthenticationIdResult
	set split_soapAction [split $PROVEURU_DATA(provider_action) /]
	set split_length [llength $split_soapAction]
	set adj_split [expr $split_length - 1]
	set soap_action [lindex $split_soapAction $adj_split ]

	if {[$ResponseTag nodeName] != "${soap_action}Response"} {
		error {OVS_PROVEURU: Soap Action Response mismatch.}
	}

	set Results [$ResponseTag childNodes]
	set ResultsTag [lindex $Results 0]

	if {[$ResultsTag nodeName] != "${soap_action}Result"} {
		error {OVS_PROVEURU: Soap Action Result mismatch.}
	}

	#Check to see if results have any children in the event of no data
	if {![$ResultsTag hasChildNodes]} {
		error "Results has no data (AuthenticateByProfileResults contained no children)"
	}

	# From here on in Response means the following for brevity
	#   Response/soap:Envelope/soap:Body/Response/Result

	# Response/CustomerRef
	# Response/ProfileId
	# Response/ProfileVersion
	# Response/ProfileRevision
	# Response/Timestamp
	# Response/Score

	set dcash [list \
		profile_id \
		profile_version \
		profile_revision \
		timestamp \
		authentication_id]

	if {$type == "check"} {
		if {$PROVEURU_CFG(version) == "6c"} {
			set proveuru [list \
			ProfileId \
			ProfileVersion \
			ProfileRevision \
			Timestamp \
			AuthenticationID]
		} else {
			set proveuru [list \
			ProfileId \
			ProfileVersion \
			ProfileRevision \
			Timestamp \
			AuthenticationId]
		}
	} else {
		set proveuru [list \
			ProfileId \
			ProfileVersion \
			ProfileRevision \
			TimeStamp \
			AuthenticationId]
	}

	for {set i 0} {$i < [llength $dcash]} {incr i} {

		set dcash_item    [lindex $dcash $i]
		set proveuru_item [lindex $proveuru $i]

		set element [$ResultsTag getElementsByTagName $proveuru_item]

		if {$element == ""} {
			error "Bad XML format. Unable to retrieve Response/$proveuru_item"
		}

		set item [[$element firstChild] nodeValue]

		if {$item == ""} {
			# This element is compulsory
			error "Bad XML format. Unable to retrieve Response/$proveuru_item"
		}

		set PROVEURU_DATA(URU,$dcash_item) $item
	}

	# Response/Score
	set element [$ResultsTag getElementsByTagName Score]
	set item    ""
	if {$element != ""} {
		set item [[$element firstChild] nodeValue]
	}
	set PROVEURU_DATA(URU,score) $item

	# Response/Results
	set Results [$ResultsTag getElementsByTagName "Results"]
	set PROVEURU_RESP(uru_ids) [list]

	if {[llength $Results] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/$proveResponse/Results"
	}

	#  Decide type of element parsing depending on check or log request
	if {$type == "check"} {
		set result_field "URUResult2"
	} else {
		set result_field "URULogResult"
	}

	set result_list [$Results getElementsByTagName $result_field]
	if {[llength $result_list] < 1} {
		error "Bad XML format. Unable to retrieve Response/$proveResponse/$result_field"
	}

	ob_log::write DEBUG {OVS_PROVEURU: Received [llength $result_list] results}

	# Response/$result_field/URUID
	# Response/$result_field/Code
	# Response/$result_field/Text
	set dcash    [list uru_id code text]
	set proveuru [list URUID Code Text]

	foreach result_item $result_list {

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			set element [$result_item getElementsByTagName $proveuru_item]

			if {$element == ""} {
				error "Bad XML format. Unable to retrieve Response/$result_field/$proveuru_item"
			}

			set $dcash_item [[$element firstChild] nodeValue]

			if {[set $dcash_item] == ""} {
				error "Bad XML format. Unable to retrieve Response/$result_field/$proveuru_item"
			}
		}

		set PROVEURU_RESP($uru_id,$code) $text
		lappend PROVEURU_RESP($uru_id,codes) $code

		if {[lsearch $PROVEURU_RESP(uru_ids) $uru_id] == -1} {
			lappend PROVEURU_RESP(uru_ids) $uru_id
		}
	}

	#Sort the list
	lsort PROVEURU_RESP(uru_ids)

	foreach check_type $PROVEURU_DATA(URU,checks) {
		set uru_id $URU_LOOKUP($check_type)

		if {[info exists PROVEURU_RESP($uru_id,codes)]} {
			set PROVEURU_DATA($check_type,responses) $PROVEURU_RESP($uru_id,codes)
		} else {
			set PROVEURU_DATA($check_type,responses) [list]
		}
	}

	# If we're running a verification we're done
	if {$type == "check"} {
		return $PROVEURU_DATA(URU,authentication_id)
	}

	#  If Log operations are what you need, continue on.....

	# Response/UserData
	set UserData [$ResultsTag getElementsByTagName "UserData"]

	if {[llength $UserData] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn/UserData: $UserData"
	}

	# Response/UserData/Basic
	set Basic [$UserData getElementsByTagName "Basic"]

	if {[llength $Basic] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/URUTxn/UserData/Basic"
	}

	# Response/UserData/Basic/Forename
	# Response/UserData/Basic/MiddleInitial
	# Response/UserData/Basic/Surname
	# Response/UserData/Basic/Gender
	# Response/UserData/Basic/DOBDay
	# Response/UserData/Basic/DOBMonth
	# Response/UserData/Basic/DOBYear
	set dcash [list title \
		forename \
		middle_initial \
		surname \
		dob_year \
		dob_month \
		dob_day \
		gender]

	set proveuru [list Title \
		Forename \
		MiddleInitial \
		Surname \
		DOBYear \
		DOBMonth \
		DOBDay \
		Gender]

	for {set i 0} {$i < [llength $dcash]} {incr i} {

		set dcash_item    [lindex $dcash $i]
		set proveuru_item [lindex $proveuru $i]

		# Response/UserData/Basic
		set basic_list [$Basic getElementsByTagName $proveuru_item]

		if {[llength $basic_list] == 1} {
			set element [$basic_list firstChild]

			if {$element == ""} {
				error "Bad XML format. Unable to retrieve Response/UserData/Basic/$proveuru_item"
			}

			set PROVEURU_DATA($dcash_item) [$element nodeValue]

			ob_log::write DEBUG {OVS_PROVEURU: $dcash_item $PROVEURU_DATA($dcash_item)}
		}
	}

	#   Extract the returned address(es)
	#
	set PROVEURU_DATA(address_count) 0

	# Response/UserData/UKDATA/AddressN/FixedFormat/Postcode
	# Response/UserData/UKDATA/AddressN/FixedFormat/BuildingName
	# Response/UserData/UKDATA/AddressN/FixedFormat/BuildingNo
	# Response/UserData/UKDATA/AddressN/FixedFormat/SubBuilding
	# Response/UserData/UKDATA/AddressN/FixedFormat/Organisation
	# Response/UserData/UKDATA/AddressN/FixedFormat/Street
	# Response/UserData/UKDATA/AddressN/FixedFormat/SubStreet
	# Response/UserData/UKDATA/AddressN/FixedFormat/Town
	# Response/UserData/UKDATA/AddressN/FixedFormat/District
	# Response/UserData/UKDATA/AddressN/FirstYearOfResidence
	# Response/UserData/UKDATA/AddressN/LastYearOfResidence
	set dcash [list postcode \
		building_name \
		building_no \
		sub_building \
		organisation \
		street \
		sub_street \
		town \
		district]

	set proveuru [list Postcode \
		BuildingName \
		BuildingNo \
		SubBuilding \
		Organisation \
		Street \
		SubStreet \
		Town \
		District]

	set dcash_year [list first_year_of_residence \
		last_year_of_residence]

	set proveuru_year [list FirstYearOfResidence \
		LastYearOfResidence]

	for {set i 1} {$i <= 4} {incr i} {

		# Response/UserData/UKDATA/AddressN/
		set Address${i} [$UserData getElementsByTagName "Address${i}"]

		if {[llength [set Address${i}]] == 1} {

			incr PROVEURU_DATA(address_count)

			for {set j 0} {$j < [llength $dcash]} {incr j} {

				set dcash_item    [lindex $dcash $j]
				set proveuru_item [lindex $proveuru $j]

				# Response/UserData/UKDATA/AddressN/FixedFormat
				set addr_list [[set Address${i}] getElementsByTagName $proveuru_item]

				if {[llength $addr_list] == 1} {

					set child [$addr_list firstChild]

					if {$child != ""} {
						set PROVEURU_DATA(address${i},$dcash_item) [$child nodeValue]

						ob_log::write DEBUG {OVS_PROVEURU: address${i},$dcash_item $PROVEURU_DATA(address${i},$dcash_item)}
					}
				}
			}

			# Years of residence
			#
			for {set k 0} {$k < [llength $dcash_year]} {incr k} {

				set dcash_item    [lindex $dcash_year $k]
				set proveuru_item [lindex $proveuru_year $k]

				# Response/UserData/UKDATA/AddressN/FirstYearOfResidence
				# Response/UserData/UKDATA/AddressN/LastYearOfResidence
				set yearElement [[set Address${i}] getElementsByTagName $proveuru_item]

				if {[llength $yearElement] == 1} {
					set child [$yearElement firstChild]

					if {$child != ""} {
						set PROVEURU_DATA(address${i},$dcash_item) [$child nodeValue]

						ob_log::write DEBUG {OVS_PROVEURU: address${i},$dcash_item $PROVEURU_DATA(address${i},$dcash_item)}
					}
				}
			}
		}
	}

	# Response/UserData/UKDATA/Driver
	set Driver [$UserData getElementsByTagName "Driver"]

	# Response/UserData/UKDATA/Driver/Number1
	# Response/UserData/UKDATA/Driver/Number2
	# Response/UserData/UKDATA/Driver/Number3
	# Response/UserData/UKDATA/Driver/Number4
	# Response/UserData/UKDATA/Driver/MailSort
	# Response/UserData/UKDATA/Driver/Postcode
	if {[llength $Driver] == 1} {

		set dcash [list number1 \
			number2 \
			number3 \
			number4 \
			mail_sort \
			postcode]

		set proveuru [list Number1 \
			Number2 \
			Number3 \
			Number4 \
			MailSort \
			Postcode]

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			# Response/UserData/UKDATA/Driver/
			set driver_list [$Driver getElementsByTagName $proveuru_item]

			if {[llength $driver_list] == 1} {
				# Response/UserData/UKDATA/Driver/<Childnode>
				set child [$driver_list firstChild]

				if {$child != ""} {
					set PROVEURU_DATA(driver,$dcash_item) [$child nodeValue]

					ob_log::write DEBUG {OVS_PROVEURU: driver,$dcash_item $PROVEURU_DATA(driver,$dcash_item)}
				}
			}
		}
	}

	# Response/UserData/UKDATA/Passport
	set Passport [$UserData getElementsByTagName "Passport"]

	# Response/UserData/UKDATA/Passport/Number1
	# Response/UserData/UKDATA/Passport/Number2
	# Response/UserData/UKDATA/Passport/Number3
	# Response/UserData/UKDATA/Passport/Number4
	# Response/UserData/UKDATA/Passport/Number5
	# Response/UserData/UKDATA/Passport/Number6
	# Response/UserData/UKDATA/Passport/ExpiryDay
	# Response/UserData/UKDATA/Passport/ExpiryMonth
	# Response/UserData/UKDATA/Passport/ExpiryYear
	if {[llength $Passport] == 1} {

		set dcash [list number1 \
			number2 \
			number3 \
			number4 \
			number5 \
			number6 \
			expiry_day \
			expiry_month \
			expiry_year]

		set proveuru [list Number1 \
			Number2 \
			Number3 \
			Number4 \
			Number5 \
			Number6 \
			ExpiryDay \
			ExpiryMonth \
			ExpiryYear]

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			# Response/UserData/UKDATA/Passport/
			set passport_list [$Passport getElementsByTagName $proveuru_item]

			if {[llength $passport_list] == 1} {

				# Response/UserData/UKDATA/Passport/<ChildNode>
				set child [$passport_list firstChild]

				if {$child != ""} {
					set PROVEURU_DATA(passport,$dcash_item) [$child nodeValue]

					ob_log::write DEBUG {OVS_PROVEURU: passport,$dcash_item $PROVEURU_DATA(passport,$dcash_item)}
				}
			}
		}
	}

	# Response/UserData/UKDATA/Telephone
	set Telephone [$UserData getElementsByTagName "Telephone"]

	# Response/UserData/UKDATA/Telephone/Number
	# Response/UserData/UKDATA/Telephone/ActiveMonth
	# Response/UserData/UKDATA/Telephone/ActiveYear
	# Response/UserData/UKDATA/Telephone/ExDirectory
	if {[llength $Telephone] == 1} {

		set dcash [list number \
			active_month \
			active_year \
			exdirectory]

		set proveuru [list Number \
			ActiveMonth \
			ActiveYear \
			ExDirectory]

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			# Response/UserData/UKDATA/Telephone
			set telephone_list [$Telephone getElementsByTagName $proveuru_item]

			if {[llength $telephone_list] == 1} {

				# Response/UserData/UKDATA/Telephone/<ChildNode>
				set child [$telephone_list firstChild]

				if {$child != ""} {
					set PROVEURU_DATA(telephone,$dcash_item) [$child nodeValue]

					# ExDirectory
					if {$dcash_item == "exdirectory"} {
						set val $PROVEURU_DATA(telephone,$dcash_item)

						if {$val != "" || $val == "false"} {
							set PROVEURU_DATA(telephone,$dcash_item) "no"
						} else {
							set PROVEURU_DATA(telephone,$dcash_item) "yes"
						}
					}

					ob_log::write DEBUG {OVS_PROVEURU: telephone,$dcash_item $PROVEURU_DATA(telephone,$dcash_item)}
				}
			}
		}
	}

	# Response/UserData/UKDATA/Electric/
	set Electric [$UserData getElementsByTagName "Electric"]

	# Response/UserData/UKDATA/Electric/Number1
	# Response/UserData/UKDATA/Electric/Number2
	# Response/UserData/UKDATA/Electric/Number3
	# Response/UserData/UKDATA/Electric/Number4
	# Response/UserData/UKDATA/Electric/MailSort
	# Response/UserData/UKDATA/Electric/Postcode
	if {[llength $Electric] == 1} {

		set dcash [list number1 \
			number2 \
			number3 \
			number4 \
			mail_sort \
			postcode]

		set proveuru [list Number1 \
			Number2 \
			Number3 \
			Number4 \
			MailSort \
			Postcode]

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			# Response/UserData/UKDATA/Electric/
			set electric_list [$Electric getElementsByTagName $proveuru_item]

			if {[llength $electric_list] == 1} {

				# Response/UserData/UKDATA/Electric/<ChildNode>
				set child [$electric_list firstChild]

				if {$child != ""} {
					set PROVEURU_DATA(electric,$dcash_item) [$child nodeValue]

					ob_log::write DEBUG {OVS_PROVEURU: electric,$dcash_item $PROVEURU_DATA(electric,$dcash_item)}
				}
			}
		}
	}

	# Response/UserData/UKDATA/CreditDebitCard
	set Card [$UserData getElementsByTagName "CreditDebitCard"]

	# Response/UserData/UKDATA/CreditDebitCard/Number
	# Response/UserData/UKDATA/CreditDebitCard/ExpiryDate
	# Response/UserData/UKDATA/CreditDebitCard/IssueNumber
	# Response/UserData/UKDATA/CreditDebitCard/VerificationCode
	if {[llength $Card] == 1} {

		set dcash [list number \
			expiry_date \
			issue_number \
			verification_code]

		set proveuru [list Number \
			ExpiryDate \
			IssueNumber \
			VerificationCode]

		for {set i 0} {$i < [llength $dcash]} {incr i} {

			set dcash_item    [lindex $dcash $i]
			set proveuru_item [lindex $proveuru $i]

			# Response/UserData/UKDATA/CreditDebitCard/
			set card_list [$Card getElementsByTagName $proveuru_item]

			if {[llength $card_list] == 1} {

				# Response/UserData/UKDATA/CreditDebitCard/<ChildNode>
				set child [$card_list firstChild]

				if {$child != ""} {
					set PROVEURU_DATA(card,$dcash_item) [$child nodeValue]

					ob_log::write DEBUG {OVS_PROVEURU: card,$dcash_item $PROVEURU_DATA(card,$dcash_item)}
				}
			}
		}
	}

	return $PROVEURU_DATA(URU,authentication_id)
}



#   _convert_data
#
#	Converts the Data Cash centric array to a proveURU compatible version
#
#	request: OVS formatted array
#	returns: PROVEURU formatted array
proc ob_ovs_proveuru::_convert_data { {array_list} args} {

	variable PROVEURU_DATA
	variable DCASH_DATA

	#Set the data cash centric array
	array set DCASH_DATA $array_list
	ob_log::write DEBUG {Converting the data from Data Cash format to Prove URU format}

	set counter 0
	set basic [list Title \
		Forename \
		MiddleInitial \
		Surname \
		DOBDay \
		DOBMonth \
		DOBYear]

	foreach basic_item {
		title
		forename
		middle_initial
		surname
		dob_day
		dob_month
		dob_year
	} {
		set PROVEURU_DATA([lindex $basic $counter]) $DCASH_DATA($basic_item)
		incr counter
	}

	#Special case for gender
	set PROVEURU_DATA(Gender) "Male"
	if { $DCASH_DATA(gender) == "F" || $DCASH_DATA(gender) == "f"} {
		set PROVEURU_DATA(Gender) "Female"
	}

	set PROVEURU_DATA(address_count) $DCASH_DATA(address_count)
	set address [list Postcode \
		BuildingName \
		BuildingNo \
		SubBuilding \
		Organisation \
		Street \
		SubStreet \
		Town \
		District]

	set resident [list FirstYearOfResidence \
			LastYearOfResidence]

	for {set i 1} {$i <= $PROVEURU_DATA(address_count)} {incr i} {

		set counter 0
		set year_count 0

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
		} {
			set PROVEURU_DATA(address${i},[lindex $address $counter]) $DCASH_DATA(address${i},$addr_item)
			incr counter
		}

		#First and last year of resisdence have to be appended after
		#the closure of the fixed/freeform address type tag
		foreach year {
			first_year_of_residence
			last_year_of_residence
		} {
			set PROVEURU_DATA(address${i},[lindex $resident $year_count]) $DCASH_DATA(address${i},$year)
			incr year_count
		}
	}

	set counter 0
	set dlicence [list Number1 \
		Number2 \
		Number3 \
		Number4 \
		MailSort \
		Postcode \
		Microfiche \
		IssueDay \
		IssueMonth \
		IssueYear]

	foreach driver_item {
		number1
		number2
		number3
		number4
		mail_sort
		postcode
	} {
		set PROVEURU_DATA(driver,[lindex $dlicence $counter]) $DCASH_DATA(driver,$driver_item)
		incr counter
	}

	set counter 0
	set passport [list Number1 \
		Number2 \
		Number3 \
		Number4 \
		Number5 \
		Number6 \
		ExpiryDay \
		ExpiryMonth \
		ExpiryYear]

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
		set PROVEURU_DATA(passport,[lindex $passport $counter]) $DCASH_DATA(passport,$passport_item)
		incr counter
	}

	set counter 0
	set passport_int [list Number1 \
		Number2 \
		Number3 \
		Number4 \
		Number5 \
		Number6 \
		Number7 \
		Number8 \
		Number9 \
		ExpiryDay \
		ExpiryMonth \
		ExpiryYear \
		CountryOfOrigin]

	foreach passport_int_item {
		number1
		number2
		number3
		number4
		number5
		number6
		number7
		number8
		number9
		expiry_day
		expiry_month
		expiry_year
		country_of_origin
	} {
		set PROVEURU_DATA(passport_int,[lindex $passport_int $counter]) $DCASH_DATA(passport_int,$passport_int_item)
		incr counter
	}

	set counter 0
	set telephone [list Number \
		ActiveMonth \
		ActiveYear \
		ExDirectory]

	foreach telephone_item {
		number
		active_month
		active_year
		exdirectory
	} {
		set PROVEURU_DATA(telephone,[lindex $telephone $counter]) $DCASH_DATA(telephone,$telephone_item)
		incr counter
	}

	#Special Circumstances for Exdirectory
	set exdir_nocase [string tolower $DCASH_DATA(telephone,exdirectory)]
	if {$DCASH_DATA(telephone,exdirectory) != "" || $exdir_nocase == "no"} {
		set PROVEURU_DATA(telephone,ExDirectory) "false"
	} else {
		set PROVEURU_DATA(telephone,ExDirectory) "true"
	}

	set counter 0
	set electric [list Number1 \
		Number2 \
		Number3 \
		Number4 \
		MailSort \
		Postcode]

	foreach electric_item {
		number1
		number2
		number3
		number4
		mail_sort
		postcode
	} {
		set PROVEURU_DATA(electric,[lindex $electric $counter]) $DCASH_DATA(electric,$electric_item)
		incr counter
	}

	set counter 0
	set card [list Number \
		ExpiryDate \
		IssueNumber \
		VerificationCode]

	foreach card_item {
		number
		expiry_date
		issue_number
		verification_code
	} {
		set PROVEURU_DATA(card,[lindex $card $counter]) $DCASH_DATA(card,$card_item)
		incr counter
	}

	#Return the new array with updated data
	return [array get PROVEURU_DATA]
}



#    _destroy_message
#
#	Remove all DOM tree memory associated with the passed in message.
#	request:   the DOM tree node that needs destroying
proc ob_ovs_proveuru::_destroy_message {node} {
	catch {
		set od [$node ownerDocument]
		$od delete
	}
}



# Private procedure to hide any replace the midrange of a variable value
#
proc ob_ovs_proveuru::_hide_message {msg} {

	foreach ns {uru6 urul} {
		foreach tag {Password AccountName} {
			set str_search  "<${ns}:${tag}>.*</${ns}:${tag}>"
			set str_replace "<${ns}:${tag}>XXXX</${ns}:${tag}>"

			regsub -all $str_search $msg $str_replace msg
		}
	}

	return $msg
}
