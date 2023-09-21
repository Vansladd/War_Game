# $Id: geopoint.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2002 Orbis Technology Ltd. All rights reserved.
#
# Interface to Geopoint API - IP checking software
#
# Requires: QuovaConfig.ini in directory appserv is run from, or set the
# environment variable QUOVA_PROPS_FILE.
#
# Also libquovaaddclient_gcc.so must be in LD_LIBRARY_PATH
#
# Configurations:
#   GEOPOINT_AOL            AOL country code: if set would replace country
#                           code for AOL IP addresses, e.g. A!     -("")
#   GEOPOINT_TEST           Test only?                             -(0)
#   GEOPOINT_IP_ADDR        Test IP address                        -("")
#   GEOPOINT_IP_COUNTRY     Test country                           -("")
#   GEOPOINT_LIB_DIR        Directory with libgeopoint.so          -("")
#
# Synopsis:
#   package require security_geopoint ?4.5?
#
# Procedures:
#   ob_geopoint::init       one time initialisation
#   ob_geopoint::ip_to_cc   maps ip address to country code
#

package provide security_geopoint 4.5


# Dependencies
#
package require util_log 4.5


# Variables
#
namespace eval ob_geopoint {

	variable CFG
	variable INIT
	variable UNKNOWN_CC
	variable RET_CODES

	set RET_CODES [list SUCCESS \
						NOT_FOUND    \
						NO_CONFIG_FILE \
						INVALID_INPUT \
						INVALID_LICENSE \
						TIMEOUT \
						FAILURE \
						ERROR_UNKNOWN \
						CUSTOMER_ID_REQUIRED \
						LICENSE_EXPIRED]

	set UNKNOWN_CC "??"
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_geopoint::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init

	ob_log::write DEBUG {GEOPOINT: init}

	# set optional cfg default values
	array set OPT [list \
		aol           ""\
		test          0\
		ip_addr       ""\
		ip_country    ""\
		lib_dir       ""]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet GEOPOINT_[string toupper $c] $OPT($c)]
	}

	# load geopoint libraries
	if {[catch {load "$CFG(lib_dir)/libgeopoint.so"} msg]} {
		ob_log::write ERROR\
		    {GEOPOINT: failed to load libgeopoint.so from directory $CFG(lib_dir): $msg}
		error $msg
	}

	set INIT 1
}


#--------------------------------------------------------------------------
# Maps ip address to country code
#--------------------------------------------------------------------------

# Maps an ip address to a country code, using a Geopoint server
#
#   ipaddr  - IP address to map
#   returns - list of ip_country, ip_is_aol ip_city ip_routing country_cf
#
proc ob_geopoint::ip_to_cc { ipaddr } {

	variable CFG
	variable UNKNOWN_CC

	# Test override
	if {$CFG(test) && $CFG(ip_addr) != ""} {
		set ipaddr $CFG(ip_addr)
	}

	set ip_country $UNKNOWN_CC
	set ip_is_aol  ""
	set ip_city    ""
	set ip_routing ""
	set country_cf ""

	ob_log::write DEV {GEOPOINT: ip_to_cc $ipaddr}

	if {[catch {

		_open_geopoint
		array set GEOPOINT_RESP [_geopoint_check_ip $ipaddr]

	} msg]} {

		ob_log::write ERROR {GEOPOINT: _geopoint_check_ip failed: $msg}
		_close_geopoint
		error $msg
	}

	_close_geopoint

	if {$GEOPOINT_RESP(code) != "SUCCESS"} {
		ob_log::write INFO {GEOPOINT: Error response was $GEOPOINT_RESP(code)}
	} else {
		ob_log::write INFO {GEOPOINT: IP Address $GEOPOINT_RESP(ip_address)}

		if {$GEOPOINT_RESP(ret_code) != "SUCCESS"} {
			ob_log::write INFO {GEOPOINT: Error code $GEOPOINT_RESP(ret_code)}
		} else {
			ob_log::write DEV\
			    {GEOPOINT: GEOPOINT_RESP IS [array get GEOPOINT_RESP]}

			if {[info exists GEOPOINT_RESP(country)]} {
				set ip_country [string toupper $GEOPOINT_RESP(country)]

				if {$ip_country == "GB"} {
					set ip_country "UK"
				}
			}

			# Routing method
			if {[info exists GEOPOINT_RESP(routing)]} {
				set ip_routing $GEOPOINT_RESP(routing)
			}

			# City
			if {[info exists GEOPOINT_RESP(city)]} {
				set ip_city $GEOPOINT_RESP(city)
			}

			# Country Confidence Factor
			if {[info exists GEOPOINT_RESP(country_cf)]} {
				set country_cf $GEOPOINT_RESP(country_cf)
			}

			# Cfg settings to allow geopoint testing - can force the test
			# country to take a particular value
			if {$CFG(test) && $CFG(ip_country) != ""} {
				set ip_country $CFG(ip_country)
			}

			# Is AOL flag
			if {[info exists GEOPOINT_RESP(aol)]} {
				set ip_is_aol $GEOPOINT_RESP(aol)

				if {$ip_is_aol == "Y"} {

					# Store Geopoint ip country in the routing field
					append ip_routing $ip_country

					# Use fake AOL country if it's an AOL ip addr
					if {$CFG(aol) != ""} {
						set ip_country $CFG(aol)
					}
				}
			}
		}
	}

	return [list $ip_country $ip_is_aol $ip_city $ip_routing $country_cf]
}



# Private procedure to open connection to Geopoint server
#
proc ob_geopoint::_open_geopoint args {

	set result [OT_InitGeopoint]
	ob_log::write INFO \
	    {GEOPOINT: opening connection to server returned $result}
}



# Private procedure to close connection to Geopoint server
#
proc ob_geopoint::_close_geopoint args {

	set result [OT_CloseGeopoint]
	ob_log::write INFO \
	    {GEOPOINT: closing connection to server returned $result}
}



# Private procedure to check an IP address
#
#   ip_address - IP address
#   returns    - Geopoint response
#
proc ob_geopoint::_geopoint_check_ip {ip_address} {

	variable RET_CODES

	set response [OT_GP_Check_IP $ip_address]

	ob_log::write DEV {GEOPOINT: response for $ip_address is $response}

	set code_pos [lsearch $response ret_code]
	if {$code_pos>=0} {
		incr code_pos
		set response [lreplace $response $code_pos $code_pos\
		             [lindex $RET_CODES [lindex $response $code_pos]]]
	}
	return $response
}
