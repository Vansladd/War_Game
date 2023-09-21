# ==============================================================
# $Id: capscan.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

#
# Warning - This file calls init_capscan immediately after being sourced
#
package require http
http::config


namespace eval capscan {

namespace export capscan_pcode_lookup
namespace export capitalise_first

variable INSTALL_TYPE
variable SERVER_URL
variable SERVER_TIMEOUT

#########################
proc init_capscan args {
#########################

	variable INSTALL_TYPE
	variable SERVER_URL
	variable SERVER_TIMEOUT

	if {![OT_CfgGet FUNC_CUST_ADDRESS_LOOKUP 0]} {
		ob::log::write INFO {CAPSCAN:  disabled: FUNC_CUST_ADDRESS_LOOKUP = 0 or not set}

	} elseif {[OT_CfgGet FUNC_CAPSCAN_SERVER 0]} {
		ob::log::write INFO {CAPSCAN:  Using capscan server on <[OT_CfgGet CAPSCAN_URL ""]>}
		set INSTALL_TYPE   SERVER
		set SERVER_URL     [OT_CfgGet CAPSCAN_URL ""]
		set SERVER_TIMEOUT [OT_CfgGet CAPSCAN_TIMEOUT 5000]

	} else {
		ob::log::write INFO {CAPSCAN:  Using capscan local copy}

		set INSTALL_TYPE   LOCAL

		set lib_dir [OT_CfgGet CAPSCAN_LIB_DIR]
		load "$lib_dir/libcapscan.so"

		set capscan_db [OT_CfgGet CAPSCAN_DB]
		set result [OT_GetDirs "$capscan_db"]
	}
}

#########################
proc capscan_pcode_lookup {house_no pcode} {
#########################

	variable INSTALL_TYPE
	variable SERVER_URL
	variable SERVER_TIMEOUT

	# returns list with items:
	# 0 - Organisation
	# 1 - Sub-Buliding
	# 2 - Building
	# 3 - Buildling Number
	# 4 - Dependent Street
	# 5 - Street
	# 6 - Dependent Locality
	# 7 - Locality
	# 8 - Post Town
	# 9 - County
	# 10 - Post Code

	if {![info exists INSTALL_TYPE]} {
		ob::log::write ERROR {CAPSCAN: Not initialised}
		return
	}

	switch -- $INSTALL_TYPE {
		"SERVER" {
			set house_no [urlencode $house_no]
			set pcode    [urlencode $pcode]

			set url "$SERVER_URL?action=get_address&address=${house_no}&postcode=${pcode}"
			if {[catch {set http_response [http::geturl $url -timeout $SERVER_TIMEOUT]} msg]} {
				ob::log::write ERROR {CAPSCAN:  failed to retrieve response from capscan server: $msg}
				return FAULT
			}

			# check that the response is valid
			set result [validate_response $http_response]
			if {[lindex $result 0]>0} {
				ob::log::write ERROR {CAPSCAN:  capscan_pcode_lookup:ERROR: [lindex $result 1]}
				return FAULT
			}

			# parse the data
			parse_xml::parseBody [http::data $http_response]

			# Garbage collect request
			http::cleanup $http_response

			# build up the ADDRESS array from the response
			set address [build_address parse_xml::XML_RESPONSE]
			return $address
		}

		"LOCAL" {
			if {[catch {set plookup_result [OT_GetAddress $house_no $pcode]} msg]} {
				ob::log::write ERROR {CAPSCAN: OT_GetAddress Error: $msg}
				return FAULT
			}
			return $plookup_result
		}

		default {
			ob::log::write ERROR {CAPSCAN: Invalid INSTALL_TYPE ($INSTALL_TYPE)}
		}
	}
}


#########################
proc validate_response {http_response} {
#########################

	set http_error 		[http::error $http_response]
	set http_code 		[http::code $http_response]
	set http_wait 		[http::wait $http_response]

	if {$http_wait != "ok"} {
		return [list 1 "TIMEOUT (code=$http_wait)"]
	}
	if {$http_error != ""} {
		return [list 1 "HTTP_ERROR (code=$http_error)"]
	}
	if {$http_code != "HTTP/1.1 200 OK"} {
		return [list 1 "HTTP_WRONG_CODE (code=$http_code)"]
	}
	return [list 0 OK]
}


#########################
proc build_address {DATA_IN} {
#########################
	upvar 1 $DATA_IN xml

	set address [list]
	lappend  address [expr {[info exists xml(address,organisation)]       ? $xml(address,organisation) : ""}]
	lappend  address [expr {[info exists xml(address,sub_buliding)]       ? $xml(address,sub_buliding) : ""}]
	lappend  address [expr {[info exists xml(address,building)]           ? $xml(address,building) : ""}]
	lappend  address [expr {[info exists xml(address,building_number)]    ? $xml(address,building_number) : ""}]
	lappend  address [expr {[info exists xml(address,dependent_street)]   ? $xml(address,dependent_street) : ""}]
	lappend  address [expr {[info exists xml(address,street)]             ? $xml(address,street) : ""}]
	lappend  address [expr {[info exists xml(address,dependent_locality)] ? $xml(address,dependent_locality) : ""}]
	lappend  address [expr {[info exists xml(address,locality)]           ? $xml(address,locality) : ""}]
	lappend  address [expr {[info exists xml(address,post_town)]          ? $xml(address,post_town) : ""}]
	lappend  address [expr {[info exists xml(address,county)]             ? $xml(address,county) : ""}]
	lappend  address [expr {[info exists xml(address,postcode)]           ? $xml(address,postcode) : ""}]
	return $address
}

#########################
proc split_pcode {pcode} {
#########################
	regsub -all " " $pcode "" pcode
	set l [string length $pcode]
	if {$l < 5} {
		return $pcode
	}
	set f [string range $pcode 0 [expr $l - 4]]
	set e [string range $pcode [expr $l - 3] $l]
	return "$f $e"
}

#########################
proc capitalise_first {phrase} {
#########################
	#
	# capitalises the first letter of each word in phrase
	#
	set words     [split $phrase " "]
	set new_words [list]

	foreach f $words {
		lappend new_words "[string toupper [string index $f 0]][string tolower [string range $f 1 [string length $f]]]"
	}

	return [join $new_words " "]
}

init_capscan
# close namespace
}
