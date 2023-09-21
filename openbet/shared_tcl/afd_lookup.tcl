# ==============================================================
# $Id: afd_lookup.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

package require http
http::config

namespace eval afd {

	namespace export afd_postcode_lookup
	variable SERVER_URL
	variable SERVER_TIMEOUT

	proc init_afd args {

		variable SERVER_URL
		variable SERVER_TIMEOUT

		# check configs for afd information
		set SERVER_URL     [OT_CfgGet AFD_URL ""]
		set SERVER_TIMEOUT [OT_CfgGet AFD_TIMEOUT 5000]
	}

	proc afd_postcode_lookup {house_no pcode type} {

		variable SERVER_URL
		variable SERVER_TIMEOUT

		# send request, check it's valid, build up address array or bind depending on type
		if {$SERVER_URL != ""} {
			set url "${SERVER_URL}addresslookup.pce?[http::formatQuery postcode $pcode property $house_no]"

			if {[catch {set http_response [http::geturl $url -timeout $SERVER_TIMEOUT]} msg]} {
				ob::log::write ERROR {AFD:  failed to retrieve response from afd server: $msg}
				return FAULT
			}
			set result [response_validate $http_response]
			if {[lindex $result 0]>0} {
				ob::log::write ERROR {AFD:  afd_postcode_lookup:ERROR: [lindex $result 1]}
				return FAULT
			}

			# parse the data
			parse_xml::parseBody [http::data $http_response]

			# Garbage collect request
			http::cleanup $http_response
			if {$type == "return"} {
				# build up the ADDRESS array from the response
				set address [build_user_address parse_xml::XML_RESPONSE]
				return $address
			} elseif {$type == "bind"} {
				# bind address from the response
				set result [bind_user_address $house_no parse_xml::XML_RESPONSE]
				return $result
			}
		} else {
			ob::log::write ERROR {AFD:  Server Url config empty}
			return 0
		}
	}

	proc response_validate {http_response} {

		set http_error 		[http::error $http_response]
		set http_code 		[http::code $http_response]
		set http_wait 		[http::wait $http_response]

		if {$http_wait != "ok"} {
			return [list 1 "TIMEOUT (code=$http_wait)"]
		}
		if {$http_error != ""} {
			return [list 1 "HTTP_ERROR (code=$http_error)"]
		}
		if {![string match "*200*" $http_code]} {
			return [list 1 "HTTP_WRONG_CODE (code=$http_code)"]
		}
		return [list 0 OK]
	}

	proc build_user_address {xml_response} {

		upvar 1 $xml_response xml

		set address [list]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,Property)]           ? $xml(AFDPostcodeEverywhere,Address,Property) : ""}]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,Street)]             ? $xml(AFDPostcodeEverywhere,Address,Street) : ""}]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,Locality)]           ? $xml(AFDPostcodeEverywhere,Address,Locality) : ""}]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,Town)]               ? $xml(AFDPostcodeEverywhere,Address,Town) : ""}]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,County)]             ? $xml(AFDPostcodeEverywhere,Address,County) : ""}]
		lappend  address [expr {[info exists xml(AFDPostcodeEverywhere,Address,Postcode)]           ? $xml(AFDPostcodeEverywhere,Address,Postcode) : ""}]
		if {[info exists xml(AFDPostcodeEverywhere,Address,Postcode)]} {
			if {[string first Error $xml(AFDPostcodeEverywhere,Address,Postcode)] >= 0 } {
				return 0
			} else {
				return $address
			}
		}
	}

	proc bind_user_address {house_no xml_response} {

		upvar 1 $xml_response xml

		# Check for errors
		if {[info exists xml(AFDPostcodeEverywhere,Address,Postcode)]} {
			if {[string first Error $xml(AFDPostcodeEverywhere,Address,Postcode)] >= 0 } {
				return 0
			} else {
				tpBindString postcode $xml(AFDPostcodeEverywhere,Address,Postcode)
			}
		} else {
			return 0
		}

		# Now fiddle about with the contents of Property, Street and the
		# passed-in house_no to try to create a first line of address
		if {[info exists xml(AFDPostcodeEverywhere,Address,Property)]} {
			set addr_street_1 "$xml(AFDPostcodeEverywhere,Address,Property) "
		}
		if {[info exists xml(AFDPostcodeEverywhere,Address,Street)]} {
			append addr_street_1 $xml(AFDPostcodeEverywhere,Address,Street)
		}

		if {[string first $house_no $addr_street_1] == -1} {
			set addr_street_1 "${house_no} $addr_street_1"
		}
		tpBindString addr_street_1 $addr_street_1

		# Now sort out the rest of it
		if {[info exists xml(AFDPostcodeEverywhere,Address,Locality)]} {
			tpBindString addr_street_2 $xml(AFDPostcodeEverywhere,Address,Locality)
		}
		if {[info exists xml(AFDPostcodeEverywhere,Address,County)]} {
			tpBindString addr_street_4 $xml(AFDPostcodeEverywhere,Address,County)
		}
		if {[info exists xml(AFDPostcodeEverywhere,Address,Town)]} {
			tpBindString addr_city $xml(AFDPostcodeEverywhere,Address,Town)
		}
		return 1
	}

init_afd

}

