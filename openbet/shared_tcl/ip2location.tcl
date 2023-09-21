# ==============================================================
# $Id: ip2location.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================
# Code for using the ip2location data to convert IP to location
# ==============================================================
#
# There must be data in tIP2Location
#

proc ip_to_cc {ipaddr} {

	return [OB::ip2location::ip_to_cc $ipaddr]

}

namespace eval OB::ip2location {

	variable INIT 0
	variable UNKNOWN_CC "??"

	proc ip_to_cc {ipaddr} {

		variable UNKNOWN_CC
		variable ::OB::country_check::IP_CHECK_RESULTS

		array set ::OB::country_check::IP_CHECK_RESULTS [subst {
			ip_addr ""
			ip_country $UNKNOWN_CC
			ip_is_aol ""
			ip_city ""
			ip_routing ""
			ip_is_blocked "N"
			country_cf ""
		}]

		if {![OT_CfgGet FUNC_IP2LOCATION_IP_CHECK 0]} {
			return $UNKNOWN_CC
		}

		set ::OB::country_check::IP_CHECK_RESULTS(ip_addr) $ipaddr

		_init

		foreach {w x y z} [split $ipaddr "."] {}

		if {[catch {

			set ip_num [expr {($w * 16777216.0) + ($x * 65536.0) + ($y * 256) + $z}]
		} msg]} {
			OT_LogWrite 3 "Invalid IP: $ipaddr"
			return $UNKNOWN_CC
		}

		if {$w > 255 || $w < 0 ||
			$x > 255 || $x < 0 ||
			$y > 255 || $y < 0 ||
			$z > 255 || $z < 0} {
			OT_LogWrite 3 "Invalid IP: $ipaddr"
			return $UNKNOWN_CC
		}

		set dp [string first "." $ip_num]
		if {$dp >= 0} {
			set ip_num [string range $ip_num 0 [expr {$dp-1}]]
		}

		if {[catch {
			set rs [db_exec_qry ip2location_get_cc $ip_num $ip_num]
		} msg]} {
			OT_LogWrite 3 "Failed ip2location_get_cc: $msg"
			return $UNKNOWN_CC
		}

		set ::OB::country_check::IP_CHECK_RESULTS(req_id) [reqGetId]

		if {[db_get_nrows $rs] == 1} {
			set country_code [db_get_col $rs 0 country_code]
		} else {
			set country_code $UNKNOWN_CC
		}
		db_close $rs

		if {[OT_CfgGet IP2LOCATION_TEST 0] && [OT_CfgGet IP2LOCATION_IP_COUNTRY {}] != {}} {
			set country_code [OT_CfgGet IP2LOCATION_IP_COUNTRY {}]
		}

		set ::OB::country_check::IP_CHECK_RESULTS(ip_country) $country_code

		return $country_code
	}

	proc _init {} {
		variable INIT

		if {$INIT} {
			return
		}

		db_store_qry ip2location_get_cc {
			select FIRST 1
				country_code,
				ip_to - ip_from as range_size
			from
				tIP2Location
			where
				ip_from = (
					select max(ip_from)
					from
						tIP2Location
					where
						ip_from <= ?
				)
				and ip_to >= ?
			order by
				range_size
		}

		set INIT 1
	}
}






