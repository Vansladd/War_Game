# ==============================================================
# $Id: geopoint.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================
# Interface to Geopoint API - IP checking software
# ==============================================================
#
# Requires: QuovaConfig.ini in directory appserv is run from
#
# Config Settings:
# FUNC_GEOPOINT_IP_CHECK - 1 or 0
# GEOPOINT_LIB_DIR directory containing libgeopoint.so
#
# Also libquovaaddclient_gcc.so must be in LD_LIBRARY_PATH
#

proc ip_to_cc {ipaddr } {

	return [OB::geopoint::ip_to_cc $ipaddr ]
}

namespace eval OB::geopoint {

	variable UNKNOWN_CC
	variable AOL_CC

	# Set up some default values that can be used below
	set UNKNOWN_CC "??"
	set AOL_CC [OT_CfgGet GEOPOINT_AOL "A!"]

	proc ip_to_cc {ipaddr } {
		variable UNKNOWN_CC
		variable AOL_CC

		# Cfg settings to allow geopoint testing - can force the test ip addr to have a particular value
		if {[OT_CfgGet GEOPOINT_TEST 0] && [OT_CfgGet GEOPOINT_IP_ADDR {}] != {}} {
			set ipaddr [OT_CfgGet GEOPOINT_IP_ADDR {}]
		}

		variable ::OB::country_check::IP_CHECK_RESULTS

		array set ::OB::country_check::IP_CHECK_RESULTS [subst {
			ip_addr    ""
			ip_country $UNKNOWN_CC
			ip_is_aol  ""
			ip_city    ""
			ip_routing ""
			ip_is_blocked "N"
			country_cf ""
		}]

		# If not using Geopoint, or Geopoint is to be skipped
		# return the default
		if { ![OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK] } {
			return $::OB::country_check::IP_CHECK_RESULTS(ip_country)
		}

		ob::log::write DEV {OB::geopoint::ip_to_cc $ipaddr}

		set ::OB::country_check::IP_CHECK_RESULTS(ip_addr) $ipaddr

		# Open a connection to the GP server
		set result [open_geopoint]
		ob::log::write INFO {open_geopoint returned $result}

		array set GEOPOINT_RESP [geopoint_check_ip $ipaddr]

		# Close the connection to the GP server
		set result [close_geopoint]
		ob::log::write INFO {close_geopoint returned $result}

		if {$GEOPOINT_RESP(code)!="SUCCESS"} {
			OT_LogWrite 3 "Geopoint Error:  $GEOPOINT_RESP(code)"
			return $UNKNOWN_CC
		} else {
			OT_LogWrite 10 "GP IP Address:  $GEOPOINT_RESP(ip_address)"
			if {$GEOPOINT_RESP(ret_code)!="SUCCESS"} {
				OT_LogWrite 3 "Geopoint Error:  $GEOPOINT_RESP(ret_code)"
				return $UNKNOWN_CC

			} else {
				ob::log::write DEV {GEOPOINT_RESP IS [array get GEOPOINT_RESP]}

				set ::OB::country_check::IP_CHECK_RESULTS(req_id) [reqGetId]

				# IP country
				if {[info exists GEOPOINT_RESP(country)]} {

					set ip_country [string toupper $GEOPOINT_RESP(country)]

					if {$ip_country == "GB"} {
						set ::OB::country_check::IP_CHECK_RESULTS(ip_country) "UK"
					} else {
						set ::OB::country_check::IP_CHECK_RESULTS(ip_country) $ip_country
					}
				}

				# Routing method
				if {[info exists GEOPOINT_RESP(routing)]} {
					set ::OB::country_check::IP_CHECK_RESULTS(ip_routing) $GEOPOINT_RESP(routing)
				}

				# City
				if {[info exists GEOPOINT_RESP(city)]} {
					set ::OB::country_check::IP_CHECK_RESULTS(ip_city)    $GEOPOINT_RESP(city)
				}

				# Country Confidence Factor
				if {[info exists GEOPOINT_RESP(country_cf)]} {
					set ::OB::country_check::IP_CHECK_RESULTS(country_cf) $GEOPOINT_RESP(country_cf)
				}

				# Cfg settings to allow geopoint testing - can force the test country to take a particular value
				if {[OT_CfgGet GEOPOINT_TEST 0] && [OT_CfgGet GEOPOINT_IP_COUNTRY {}] != {}} {
					set ::OB::country_check::IP_CHECK_RESULTS(ip_country) [OT_CfgGet GEOPOINT_IP_COUNTRY {}]
				}

				# Is AOL flag
				if {[info exists GEOPOINT_RESP(aol)]} {
					set ::OB::country_check::IP_CHECK_RESULTS(ip_is_aol)  $GEOPOINT_RESP(aol)

					if {$GEOPOINT_RESP(aol) == "Y"} {
						# Store Geopoint ip country in the routing field
						append ::OB::country_check::IP_CHECK_RESULTS(ip_routing) " $::OB::country_check::IP_CHECK_RESULTS(ip_country)"

						# Don't include this functionality yet...
						# Use fake AOL country (A!) if it's an AOL ip addr
						#set ::OB::country_check::IP_CHECK_RESULTS(ip_country) $AOL_CC
					}
				}

				return $::OB::country_check::IP_CHECK_RESULTS(ip_country)
			}
		}
	}


	# =========================================================
	# This function loads all the necessary libraries in order for geopoint to work
	# =========================================================
	proc init_geopoint args {

		global quova_return_code

		OT_LogWrite 10 "proc init_geopoint"


		set quova_return_code [list SUCCESS \
								   NOT_FOUND	\
								   NO_CONFIG_FILE \
								   INVALID_INPUT \
								   INVALID_LICENSE \
								   TIMEOUT \
								   FAILURE \
								   ERROR_UNKNOWN \
								   CUSTOMER_ID_REQUIRED \
								   LICENSE_EXPIRED]


		if { [OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK] } {
			set GEOPOINT_LIB_DIR [OT_CfgGet GEOPOINT_LIB_DIR]
			ob::log::write DEV {loading $GEOPOINT_LIB_DIR/libgeopoint.so}
			load "$GEOPOINT_LIB_DIR/libgeopoint.so"
			ob::log::write DEV {geopoint loaded}
		}

	}

	# =========================================================
	# This function opens a connection to the geopoint server
	# =========================================================
	proc open_geopoint args {
		ob::log::write DEV {proc open_gepoint}

		set result [OT_InitGeopoint]
		return $result
	}


	proc geopoint_check_ip {ip_address} {

		global quova_return_code

		ob::log::write DEV {proc geopoint_check_ip}

		set response [OT_GP_Check_IP $ip_address]
		ob::log::write DEV {response is $response}
		# replace numeric geopoint ret_code with string value
		set code_pos [lsearch $response ret_code]
		if {$code_pos>=0} {
			incr code_pos
			set response [lreplace $response $code_pos $code_pos\
							  [lindex $quova_return_code [lindex $response $code_pos]]]
		}
		return $response
	}

	# =========================================================
	# This function closes a connection to the geopoint server
	# =========================================================
	proc close_geopoint args {
		ob::log::write DEV {proc close_gepoint}

		set result [OT_CloseGeopoint]
		return $result
	}

	init_geopoint
}
