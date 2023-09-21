# $Id: auth_pro.tcl,v 1.1 2011/10/04 12:40:39 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Interface to the Experian Authenticate Pro system
#
# Synopsis
#    package require ovs_auth_pro
#
# Configuration:
#    OVS_AUTH_PRO_TIMEOUT    - timeout for http requests to the Auth Pro server
#    OVS_AUTH_PRO_XMLNS_QAS  - namespace uri for qas
#                              (http://www.qas.com/web-2005-10)
#
package provide ovs_auth_pro 4.5


# Dependencies
#
package require tls
package require http 2.3
package require tdom
package require util_db
package require util_log

# Variables
#
namespace eval ob_ovs_auth_pro {

	variable INITIALISED
	set INITIALISED 0

}


# Prefix log messages with OVS_AUTH_PRO
#
proc ob_ovs_auth_pro::log {level msg} {
	ob_log::write $level "OVS_AUTH_PRO: $msg"
}


# One time initialisation
#
proc ob_ovs_auth_pro::init {} {

	global auto_path
	variable INITIALISED

	if {$INITIALISED} {return}

	log CRITICAL "************* INITIALISING Auth Pro"

	_prep_qrys

	set INITIALISED 1
}


# Prepare queries
#
proc ob_ovs_auth_pro::_prep_qrys {} {

	# Get the responses of the most recent customer check
	ob_db::store_qry ob_ovs_auth_pro::get_cust_check {
		select
			c.cr_date,
			ud.response_no,
			uc.resp_value
		from
			tVrfChk        c,
			tVrfAuthProChk uc,
			tVrfAuthProDef ud
		where
			uc.vrf_auth_pro_def_id = ud.vrf_auth_pro_def_id and
			uc.vrf_check_id        = c.vrf_check_id         and
			c.vrf_check_id in (
				select
					max(c1.vrf_check_id)
				from
					tVrfChk  c1,
					tVrfPrfl p
				where
					p.cust_id       = ?               and
					p.vrf_prfl_id   = c1.vrf_prfl_id  and
					c1.vrf_chk_type = ?
			)
	}
}


# Requests an XML verification request for Authenticate Pro
#
#	array_list - array of variables to bind into the XML request
#
proc ob_ovs_auth_pro::run_check {array_list} {

	return [_run_auth_pro $array_list "check"]
}


# Constructs an XML request for Authenticate Pro. Takes response and parses it
# for verification details.
#
#	returns - status (OB_OK denotes success) and array of log data if no error
#
proc ob_ovs_auth_pro::_run_auth_pro {array_list type} {
	variable INITIALISED
	variable AUTH_PRO_DATA
	variable AUTH_PRO_HTTP_TOKEN
	variable XML_DOM

	set fn {ob_ovs_auth_pro::_run_auth_pro}

	if {!$INITIALISED} {init}
	array set AUTH_PRO_DATA $array_list

	# Get address items from the array and build serach string.
	if {[llength $AUTH_PRO_DATA(address1,building_no)]} {
		set addr_str $AUTH_PRO_DATA(address1,building_no)
	} else {
		set addr_str $AUTH_PRO_DATA(address1,building_name)
	}
	
	foreach addr_item {
		street
		sub_street
		town
		district
		postcode
	} {
		append addr_str "|$AUTH_PRO_DATA(address1,$addr_item)"
	}

	if {[OT_CfgGet USE_VERIFICATION_SEARCH 1] == 1} {
		# Do the address verification
		set result [qas::do_verification_search "$addr_str"]
		if {[llength $result] > 0} {

			array set ADDRESS $result

			set AUTH_PRO_DATA_LIST(ADDR_FLAT)         $ADDRESS(0)
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)    $ADDRESS(1)
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER)  $ADDRESS(2)
			set AUTH_PRO_DATA_LIST(ADDR_STREET)       $ADDRESS(3)
			set AUTH_PRO_DATA_LIST(ADDR_DISTRICT)     $ADDRESS(4)
			set AUTH_PRO_DATA_LIST(ADDR_TOWN)         $ADDRESS(5)
			set AUTH_PRO_DATA_LIST(ADDR_COUNTY)       $ADDRESS(6)
			set AUTH_PRO_DATA_LIST(ADDR_POSTCODE)     $ADDRESS(7)

			# Log out the captured address
			ob_log::write ERROR "${fn} - Address

			set AUTH_PRO_DATA_LIST(ADDR_FLAT)         $ADDRESS(0)
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)    $ADDRESS(1)
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER)  $ADDRESS(2)
			set AUTH_PRO_DATA_LIST(ADDR_STREET)       $ADDRESS(3)
			set AUTH_PRO_DATA_LIST(ADDR_DISTRICT)     $ADDRESS(4)
			set AUTH_PRO_DATA_LIST(ADDR_TOWN)         $ADDRESS(5)
			set AUTH_PRO_DATA_LIST(ADDR_COUNTY)       $ADDRESS(6)
			set AUTH_PRO_DATA_LIST(ADDR_POSTCODE)     $ADDRESS(7)
			"

		} else {

			# Address could not be verified, so use the original customer address after trying to format it correctly
			set addr1 $AUTH_PRO_DATA(address1,street)
			set addr2 $AUTH_PRO_DATA(address1,sub_street)
			
			# If the second line of the address contains the street name, append it to the first line
			set CFG(STREET_NAMES) [OT_CfgGet STREET_NAMES]
			foreach street_name $CFG(STREET_NAMES) {
				if {[string match *[string tolower $street_name]* [string tolower $addr2]] == 1} {
					set addr1 "$addr1, $addr2"
					break
				}
			}
			
			# Set ADDR_FLAT, ADDR_HOUSENAME, ADDR_HOUSENUMBER and ADDR_STREET to empty string by default
			set AUTH_PRO_DATA_LIST(ADDR_FLAT)        ""
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)   ""
			set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER) ""
			set AUTH_PRO_DATA_LIST(ADDR_STREET)      ""
			
			# Get the flat or apartment name if it exists
			set first_word [lindex $addr1 0]
			set CFG(SUBBUILDING_NAMES) [OT_CfgGet SUBBUILDING_NAMES]
			foreach subbuilding_name $CFG(SUBBUILDING_NAMES) {
				if {[string tolower $first_word] eq [string tolower $subbuilding_name]} {
					set AUTH_PRO_DATA_LIST(ADDR_FLAT) "$first_word [lindex $addr1 1]"
					# Remove trailing commas
					regsub -all {[,]*} $AUTH_PRO_DATA_LIST(ADDR_FLAT) "" AUTH_PRO_DATA_LIST(ADDR_FLAT)
					set addr1 [lrange $addr1 2 end]
					break
				}
			}

			# Get the house name, number and street

			# HOUSE_NAME(,) NUMBER(,) STREET_NAME
			if {[regexp {^([[:alpha:] .\d]+)(,.[ ]?| )([\d/-]+)(,.[ ]?| )([[:alpha:] .]+)[ ]*$} $addr1 match house_name separator1 house_number separator2 street] == 1} {
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)   $house_name
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER) $house_number
				set AUTH_PRO_DATA_LIST(ADDR_STREET)      $street
			# HOUSENAME, STREET_NAME
			} elseif {[regexp {^([[:alpha:] .]+),[ ]*([[:alpha:] .]+)[ ]*$} $addr1 match house_name street] == 1} {
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)   $house_name
				set AUTH_PRO_DATA_LIST(ADDR_STREET)      $street
			# NUMBER(,) STREET_NAME
			} elseif {[regexp {^([\d/-]+)(,.[ ]?| )([[:alpha:] ]+)[ .]*$} $addr1 match house_number separator street] == 1} {
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER)   $house_number
				set AUTH_PRO_DATA_LIST(ADDR_STREET)        $street
			# HOUSE_NAME STREET_NAME
			} elseif {[regexp {[\d,]} $addr1 match] == 0} {
				set AUTH_PRO_DATA_LIST(ADDR_STREET)    [lrange $addr1 end-1 end]
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME) [lrange $addr1 0 end-2]
			# SUBBUILDING_NAME(,) HOUSE_NAME(,) HOUSE_NUMBER(,) STREET_NAME
			} elseif {[regexp {^([[:alpha:] .\d]+)(,[ ]?| )([[:alpha:] .]+)(,[ ]?| )([\d/-]+)(,[ ]?| )([[:alpha:] .]+)[ ]*$} $addr1 match subbuilding_name separator1 house_name separator2 house_number separator3 street] == 1} {
				set AUTH_PRO_DATA_LIST(ADDR_FLAT)        $subbuilding_name
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)   $house_name
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER) $house_number
				set AUTH_PRO_DATA_LIST(ADDR_STREET)      $street
			# SUBBUILDING_NAME(,) HOUSE_NAME(,) STREET_NAME(,) TOWN
			} elseif {[regexp {^([[:alpha:] .\d]+)(,[ ]?| )([[:alpha:] .]+)(,[ ]?| )([[:alpha:] .]+)(,[ ]?| )([[:alpha:] .]+)[ ]*$} $addr1 match subbuilding_name separator1 house_name separator2 street separator3 town] == 1} {
				set AUTH_PRO_DATA_LIST(ADDR_FLAT)        $subbuilding_name
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENAME)   $house_name
				set AUTH_PRO_DATA_LIST(ADDR_STREET)      $street
			}

			set AUTH_PRO_DATA_LIST(ADDR_TOWN)         $AUTH_PRO_DATA(address1,town)
			set AUTH_PRO_DATA_LIST(ADDR_COUNTY)       $AUTH_PRO_DATA(address1,district)
			set AUTH_PRO_DATA_LIST(ADDR_POSTCODE)     $AUTH_PRO_DATA(address1,postcode)
		}
	} else {
		# Do the address capture.
		set result [qas::do_singleline_search "$addr_str"]

		# Parse the response.
		set type [lindex $result 0]
		switch -- $type {
			FULL_ADDRESS {
				set address_data [lindex $result 1]

				# Get relevant parts of the address.
				set moniker [lindex $address_data 0]
				set address [lindex $address_data 1]

				# Get the final address.
				array set ADDRESS [qas::do_get_address $moniker "AgeVerf"]

				set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER)  $ADDRESS(0)
				set AUTH_PRO_DATA_LIST(ADDR_STREET)       $ADDRESS(1)
				set AUTH_PRO_DATA_LIST(ADDR_TOWN)         $ADDRESS(2)
				set AUTH_PRO_DATA_LIST(ADDR_COUNTY)       $ADDRESS(3)
				set AUTH_PRO_DATA_LIST(ADDR_POSTCODE)     $ADDRESS(4)

				# Log out the captured address
				ob_log::write ERROR "${fn} - Address
				set AUTH_PRO_DATA_LIST(ADDR_HOUSENUMBER)  $ADDRESS(0)
				set AUTH_PRO_DATA_LIST(ADDR_STREET)       $ADDRESS(1)
				set AUTH_PRO_DATA_LIST(ADDR_TOWN)         $ADDRESS(2)
				set AUTH_PRO_DATA_LIST(ADDR_COUNTY)       $ADDRESS(3)
				set AUTH_PRO_DATA_LIST(ADDR_POSTCODE)     $ADDRESS(4)	
				"

			}
			MULTIPLE -
			TOO_MANY -
			GENERIC_ERROR -
			default {
				# Unable to retrieve single address.
				ob_log::write ERROR "${fn} - Unable to retrieve a single address from details entered."

				# Return bad response.
				foreach check_type $AUTH_PRO_DATA(AUTH_PRO,checks) {
					set AUTH_PRO_DATA($check_type,responses) {error_msg decision decision_text}

					set AUTH_PRO_DATA($check_type,error_msg,value) "Unable to retrieve a single address from details entered."
					set AUTH_PRO_DATA($check_type,error_msg,score) 0

					# Decision
					set AUTH_PRO_DATA($check_type,decision,value) "NA00"
					set AUTH_PRO_DATA($check_type,decision,score) 0

					# Decision Text.
					set AUTH_PRO_DATA($check_type,decision_text,value) "No matches found!"
					set AUTH_PRO_DATA($check_type,decision_text,score) 0
				}

				return [list OB_OK [array get AUTH_PRO_DATA]]
			}
		}
	}

	# Populate remaining parts of the QAS array.
	set AUTH_PRO_DATA_LIST(CTRL_SEARCHCONSENT) "Y"
	set AUTH_PRO_DATA_LIST(NAME_DATEOFBIRTH)   "$AUTH_PRO_DATA(dob_day)/$AUTH_PRO_DATA(dob_month)/$AUTH_PRO_DATA(dob_year)"
	set AUTH_PRO_DATA_LIST(CTRL_CHANNEL)       "I"
	set AUTH_PRO_DATA_LIST(NAME_INITIALS)      $AUTH_PRO_DATA(middle_initial)
	set AUTH_PRO_DATA_LIST(NAME_TITLE)         $AUTH_PRO_DATA(title)
	set AUTH_PRO_DATA_LIST(NAME_FORENAME)      $AUTH_PRO_DATA(forename)
	set AUTH_PRO_DATA_LIST(NAME_SURNAME)       $AUTH_PRO_DATA(surname)
	set AUTH_PRO_DATA_LIST(NAME_SEX)           $AUTH_PRO_DATA(gender)

	# Run the search.
	set result [qas::do_search_authenticate \
						[array get AUTH_PRO_DATA_LIST] \
						[OT_CfgGet QAS_AUTH_PRO_FEILDS]]
						
	ob_log::write INFO {AUTH PRO RESULT: $result}

	# The search failed...
	if {[lindex $result 0] != "OB_OK"} {
		ob_log::write ERROR "${fn} - do_search_authenticate failed!"
		return OB_ERR_OVS_AUTH_PRO_ERROR
	}

	# Get response
	array set AUTH_PRO_RESP [lindex $result 1]

	# Loop through all checks.
	foreach check_type $AUTH_PRO_DATA(AUTH_PRO,checks) {
		set AUTH_PRO_DATA($check_type,responses) [array names AUTH_PRO_RESP]

		# Set the value of the response being returne
		foreach response [array names AUTH_PRO_RESP] {
			set AUTH_PRO_DATA($check_type,$response,value) $AUTH_PRO_RESP($response)
		}
	}

	# The score only applies to one on the responses for Authenticate Pro.
	# Map the data back to it generic form, only need one score for
	# Authenticate Pro.

	if {[info exists AUTH_PRO_RESP(decision)]} {
		array set D_MAP [OT_CfgGet OVS_AUTH_PRO_MAPPINGS]
		set AUTH_PRO_DATA($check_type,decision,score) $D_MAP($AUTH_PRO_RESP(decision))
	} else {
		# Error response
		ob_log::write ERROR "${fn} - Error response."
		return [get_xml_err]
	}

	# Return generic array.
	return [list OB_OK [array get AUTH_PRO_DATA]]
}



proc ob_ovs_auth_pro::get_addr_err {} {
	variable AUTH_PRO_DATA

	# Return bad response.
	foreach check_type $AUTH_PRO_DATA(AUTH_PRO,checks) {
		set AUTH_PRO_DATA($check_type,responses) {error_msg decision decision_text}

		set AUTH_PRO_DATA($check_type,error_msg,value) "Unable to retrieve a single address from details entered."
		set AUTH_PRO_DATA($check_type,error_msg,score) 0

		# Decision
		set AUTH_PRO_DATA($check_type,decision,value) "NA00"
		set AUTH_PRO_DATA($check_type,decision,score) 0

		# Decision Text.
		set AUTH_PRO_DATA($check_type,decision_text,value) "No matches found!"
		set AUTH_PRO_DATA($check_type,decision_text,score) 0
	}

	return [list OB_OK [array get AUTH_PRO_DATA]]
}

proc ob_ovs_auth_pro::get_xml_err {} {
	variable AUTH_PRO_DATA

	foreach check_type $AUTH_PRO_DATA(AUTH_PRO,checks) {
		# Prefill a error response.
		set AUTH_PRO_DATA($check_type,responses) {error_msg decision decision_text}
		set AUTH_PRO_DATA($check_type,error_msg,value) "Failed to complete check, no matches found."
		set AUTH_PRO_DATA($check_type,error_msg,score) 0

		# Decision
		set AUTH_PRO_DATA($check_type,decision,value) "NA00"
		set AUTH_PRO_DATA($check_type,decision,score) 0

		# Decision Text.
		set AUTH_PRO_DATA($check_type,decision_text,value) "No matches found!"
		set AUTH_PRO_DATA($check_type,decision_text,score) 0
	}

	return [list OB_OK [array get AUTH_PRO_DATA]]
}



# Get details of a customers most recent auth pro check of a given type
#
#    cust_id - customer identifier
#    type    - type of customer check
#
#	returns - list
#               result   - 0 if error, 1 if successful
#               date     - date of last check (or empty if no check present)
#               response - returns list of check name, response pairs
#
proc ob_ovs_auth_pro::get_cust_check {cust_id type} {

	set fn "ob_ovs_auth_pro::get_cust_check"

	array set CHECK [list]

	if {[catch {
		set rs [ob_db::exec_qry ob_ovs_auth_pro::get_cust_check $cust_id $type]
	} msg]} {
		ob_log::write ERROR {$fn Failed to get cust_check - $msg}
		return [list 0 {}]
	}

	set nrows [db_get_nrows $rs]

	if {!$nrows} {
		ob_db::rs_close $rs
		return [list 1 {} {}]
	}

	set cr_date [db_get_col $rs 0 cr_date]

	for {set i 0} {$i < $nrows} {incr i} {
		set CHECK([db_get_col $rs $i response_no]) \
			[db_get_col $rs $i resp_value]
	}

	ob_db::rs_close $rs

	return [list 1 $cr_date [array get CHECK]]
}
