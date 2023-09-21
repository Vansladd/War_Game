# $Id: generic.tcl,v 1.1 2011/10/04 12:40:39 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to the ProveURU verification system.
#
# Provides an XML client for the generic verification test harness
# Allows customer details to be verified and the result interpreted.
# Also enables older searches to be retrieved from ProveURU logs.
#
# Synopsis:
#	package require ovs_generic
#
# Configurations:
#
#	OVS_GENERIC_HOST    API URL  (https://venus.orbis/OVS_harness)
#	OVS_GENERIC_TIMEOUT timeout  (10000)
#	OVS_GENERIC_CLIENT  account  (88000002)
#	OVS_GENERIC_PWORD   password (fred)
#
# Procedures:
#	ob_ovs_generic::init      - one initialisation for package
#	ob_ovs_generic::set_up    - initialise generic test harness settings
#	ob_ovs_generic::run_check - pass details for verification request and parse
#	                            response
#
package provide ovs_generic 4.5



# Dependencies
#
package require tls
package require http 2.3
package require tdom



# Variables
#
namespace eval ob_ovs_generic {

	variable INITIALISED
	set INITIALISED 0
}



# One time initialisation
#
proc ob_ovs_generic::init {} {

	global auto_path
	variable INITIALISED

	if {$INITIALISED} {return}

	ob_log::write CRITICAL "************* INITIALISING GENERIC CONNECTIVITY"
	#ob_log::write_stack 1

	::http::register https 443 ::tls::socket

	variable GENERIC_CFG

	catch {unset GENERIC_CFG}

	set GENERIC_CFG(host)     [OT_CfgGet OVS_GENERIC_HOST]
	set GENERIC_CFG(timeout)  [OT_CfgGet OVS_GENERIC_TIMEOUT]

	set INITIALISED 1
}



# Requests an XML verification request for generic text harness
#
#	array_list - array of variables to bind into the XML request
#
proc ob_ovs_generic::run_check {array_list} {

	variable INITIALISED
	variable GENERIC_DATA
	variable GENERIC_XML_DOM
	variable GENERIC_HTTP_TOKEN

	if {!$INITIALISED} {init}

	array set GENERIC_DATA $array_list
	if {[info exists GENERIC_XML_DOM]} {
		catch {$GENERIC_XML_DOM delete}
	}

	set GENERIC_DATA(merchantreference) [clock seconds]

	# Pack the message
	if {[catch {

		set request [_msg_pack]

	} msg]} {

		catch {$GENERIC_XML_DOM delete}

		ob_log::write ERROR {OVS_GENERIC: Error building XML request: $msg}
		return OB_ERR_OVS_GENERIC_MSG_PACK
	}

	ob_log::write DEV {OVS_GENERIC: sending $request}

	# Send the message
	if {[catch {

		set response [_msg_send $request]

	} msg]} {

		catch {::http::cleanup $GENERIC_HTTP_TOKEN}

		ob_log::write ERROR {OVS_GENERIC: Error sending XML request: $msg}
		return OB_ERR_OVS_GENERIC_MSG_SEND
	}

	ob_log::write DEV {OVS_GENERIC: received $response}

	ob_log::write DEV {OVS_GENERIC: unpacking message}

	# Unpack the message
	if {[catch {

		_msg_unpack $response

	} msg]} {

		catch {$GENERIC_XML_DOM delete}

		ob_log::write ERROR {OVS_GENERIC: _msg_unpack failed: $msg}
		return OB_ERR_OVS_GENERIC_MSG_UNPACK
	}

	ob_log::write DEV {OVS_GENERIC: finished successfully}

	return [list OB_OK [array get GENERIC_DATA]]
}



# Constructs the XML for a verification request to generic test harness
# NOTE: Calls to this function should be placed in a wrapper to catch any
# errors and delete the XML document
#
proc ob_ovs_generic::_msg_pack {} {

	variable GENERIC_CFG
	variable GENERIC_DATA
	variable GENERIC_REQUIRE_CV2
	variable GENERIC_XML_DOM

	# REQUEST
	#  |--Basic
	#  | |--forename
	#  | |--middle_initial
	#  | |--surname
	#  | |--dob_day
	#  | |--dob_month
	#  | |--dob_year
	#  | |--gender
	#  |
	#  |--Address
	#  | |--postcode
	#  | |--building_name
	#  | |--building_no
	#  | |--sub_building
	#  | |--organisation
	#  | |--street
	#  | |--sub_street
	#  | |--town
	#  | |--district
	#  |
	#  |--Telephone
	#    |--number

	if {[info exists GENERIC_XML_DOM]} {
		catch {$GENERIC_XML_DOM delete}
	}

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set GENERIC_XML_DOM [dom createDocument "Request"]

	# Request
	set request [$GENERIC_XML_DOM documentElement]
	#$request setAttribute "version" "1.0"

	# Request/Basic
	set E_basic  [$GENERIC_XML_DOM createElement  "Basic"]
	set B_basic  [$request         appendChild    $E_basic]

	# Request/Basic/forename
	# Request/Basic/middle_initial
	# Request/Basic/surname
	# Request/Basic/dob_year
	# Request/Basic/dob_month
	# Request/Basic/dob_day
	# Request/Basic/gender
	foreach basic_item {
		forename
		middle_initial
		surname
		dob_year
		dob_month
		dob_day
		gender
	} {

		if {$GENERIC_DATA($basic_item) != ""} {
			set elem [$GENERIC_XML_DOM createElement  $basic_item]
			set brch [$B_basic         appendChild    $elem]
			set txtn [$GENERIC_XML_DOM createTextNode $GENERIC_DATA($basic_item)]
			$brch appendChild $txtn
		}
	}

	# Request/Address
	set E_addr [$GENERIC_XML_DOM createElement "Address"]
	set B_addr [$request         appendChild   $E_addr]

	# Request/Address/postcode
	# Request/Address/building_name
	# Request/Address/building_no
	# Request/Address/sub_building
	# Request/Address/organisation
	# Request/Address/street
	# Request/Address/sub_street
	# Request/Address/town
	# Request/Address/district
	foreach addr_item [list \
		postcode \
		building_name \
		building_no \
		sub_building \
		organisation \
		street \
		sub_street \
		town \
		district] {

		if {$GENERIC_DATA(address1,$addr_item) != ""} {
			set elem [$GENERIC_XML_DOM createElement $addr_item]
			set brch [$B_addr          appendChild   $elem]
			set txtn [$GENERIC_XML_DOM createTextNode \
				$GENERIC_DATA(address1,$addr_item)]
			$brch appendChild $txtn
		}
	}

	# Request/Telephone
	set E_telephone [$GENERIC_XML_DOM createElement "Telephone"]
	set B_telephone [$request         appendChild   $E_telephone]

	# Request/Telephone/number
	if {$GENERIC_DATA(telephone,number) != ""} {
		set elem [$GENERIC_XML_DOM createElement "number"]
		set brch [$B_telephone     appendChild   $elem]
		set txtn [$GENERIC_XML_DOM createTextNode \
			$GENERIC_DATA(telephone,number)]
		$brch appendChild $txtn
	}

	# Convert to text
	set request "<?xml version=\"1.0\" encoding=\"UTF-8\"?> [$GENERIC_XML_DOM asXML]"

	$GENERIC_XML_DOM delete

	return $request
}



# Unpacks an XML response from the generic test harness, adding the elements to an
# array.
#
# NOTE: Must be wrapped in a catch statement that ensures that variable GENERIC_XML_DOM
# is wiped if an error occurs
#
#	xml     - XML response to unpack
#
#	returns - unique reference
#
proc ob_ovs_generic::_msg_unpack {xml} {

	variable GENERIC_DATA
	variable GENERIC_XML_DOM

	# RESPONSE (GOOD)
	#   |--status
	#   |--time
	#   |
	#   |--Results
	#   | |--Result
	#   |   |--type
	#   |   |--code
	#   |   |--text
	#
	ob_log::write DEV {OVS_GENERIC: unpacking $xml}

	set GENERIC_XML_DOM [dom parse $xml]

	ob_log::write DEV {OVS_GENERIC: parsed XML}

	set Response [$GENERIC_XML_DOM documentElement]

	ob_log::write DEV {OVS_GENERIC: found root element}

	# Response/status
	# Response/time

	foreach item {
		status
		time
	} {
		ob_log::write DEV {OVS_GENERIC: checking $item element}
		set element [$Response getElementsByTagName $item]
		if {[llength $element] != 1} {
			# This element is compulsory and should only appear once
			error "Bad XML format. Unable to retrieve Response/$item"
		}
		set $item [[$element firstChild] nodeValue]
		if {[set $item] == ""} {
			# These elements are compulsory and should appear at least once
			error "Bad XML format. Unable to retrieve Response/$item nodeValue"
		}
	}

	# If status is not OB_OK
	# Response/information
	if {$status != "OB_OK"} {
		error $status
	}

	# Response/Results
	set Results [$Response getElementsByTagName "Results"]

	if {[llength $Results] != 1} {
		# This element is compulsory and should only appear once
		error "Bad XML format. Unable to retrieve Response/Results"
	}
	set GENERIC_DATA(types) [list]

	# Response/Results/Result
	set result_list [$Results getElementsByTagName "Result"]
	if {[llength $result_list] < 1} {
		error "Bad XML format. Unable to retrieve Response/Results/Result"
	}
	foreach result_item $result_list {

		# Response/Results/Result/type
		# Response/Results/Result/code
		# Response/Results/Result/text
		foreach item {
			type
			code
			text
		} {
			set item_desc "Response/Results/Result/$item"
			ob_log::write DEV {OVS_GENERIC: checking $item_desc element}
			set element [$result_item getElementsByTagName $item]
			if {[llength $element] != 1} {
				# These elements are compulsory and should appear at least once
				error "Bad XML format. Unable to retrieve $item_desc"
			}

			set $item [[$element firstChild] nodeValue]
			if {[set $item] == ""} {
				# These elements are compulsory and should appear at least once
				error "Bad XML format. Unable to retrieve $item_desc nodeValue"
			}
		}
		set GENERIC_DATA($type,$code) $text
		lappend GENERIC_DATA($type,responses) $code
		if {[lsearch $GENERIC_DATA(types) $type] == -1} {
			lappend GENERIC_DATA(types) $type
		}
	}

	lsort GENERIC_DATA(types)

	# If we're running a verification we're done
	$GENERIC_XML_DOM delete
}



# Sends an XML request to the generic test harness
# NOTE: All errors from this procedure should be caught the HTTP token deleted
#
#	request - XML request to be sent
#
#	returns - response message body
#
proc ob_ovs_generic::_msg_send {request} {

	variable GENERIC_CFG
	variable GENERIC_HTTP_TOKEN

	#! UTF-8 encoding - the nuclear option
	#
	# strips any non-ASCII characters - this is unfortunately the only option
	# available to us as we cannot work out what character encoding the data is
	# in (eg, if the request is from the portal, it may be in the user's
	# language encoding - but if it came from OXi XML, it may already be in
	# UTF-8)
	if {[regexp {[^\n\040-\176]} $request]} {
		set cnt [regsub -all {[^\n\040-\176]} $request {} request]
		ob_log::write WARN \
			{Warning: stripped $cnt non-ASCII character(s) from request}
	}

	set GENERIC_HTTP_TOKEN [::http::geturl \
		$GENERIC_CFG(host) \
		-query $request \
		-timeout $GENERIC_CFG(timeout)]

	set ncode [::http::ncode $GENERIC_HTTP_TOKEN]

	ob_log::write DEV {OVS_GENERIC: status = [::http::status $GENERIC_HTTP_TOKEN]}

	if {$ncode != "200"} {
		error "OVS_GENERIC: Error sending verification request: $ncode"
	}

	set body [::http::data $GENERIC_HTTP_TOKEN]
	::http::cleanup $GENERIC_HTTP_TOKEN

	return $body
}

