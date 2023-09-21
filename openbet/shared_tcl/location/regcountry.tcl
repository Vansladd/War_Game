# ==============================================================
# $Id: regcountry.tcl,v 1.1 2011/10/04 12:27:04 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================
# This file contains functionality to retrieve the customer's
# country of registration in a way that can be plugged into 
# the authentication server instead of third party
# ip-address checking software
# ==============================================================
#
# Config Settings:
#   FUNC_GEOPOINT_IP_CHECK - 1 or 0
#
#

package provide location_regcountry 4.5

package require cust_login 4.5

proc ip_to_cc {ipaddr} {
	# Get the customer's country of registration (ie tCustomer.country_code)
	# defaulting to "??" if not logged in or undefined
	set country_code [ob_login::get cntry_code "??"]

	set ::OB::country_check::IP_CHECK_RESULTS(req_id)     [reqGetId]
	set ::OB::country_check::IP_CHECK_RESULTS(ip_country) $country_code

	return $country_code
}
