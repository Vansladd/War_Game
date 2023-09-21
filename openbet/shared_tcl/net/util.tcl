# $Id: util.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# Net Utils
#
# Synopsis:
#    package require net_util ?4.5?
#
# Procedures:
#    ob_net_util::get_best_guess_ip   - return a best guess as to an
#                                       originating ip address
#

package provide net_util 4.5



# Dependencies
#
package require util_validate 4.5
package require util_log 4.5



# Variables
#
namespace eval ob_net_util {
}



#--------------------------------------------------------------------------
# Net Utilities
#--------------------------------------------------------------------------

# Returns a best guess as to the originating ip address
#
#    remote_addr     - the remote_addr from header
#    x_forwarded_for - x_forwarded_for from header
#    returns         - ip_addr (OB_NO_VALID_IP if no valid address)
#
proc ob_net_util::get_best_guess_ip { remote_addr x_forwarded_for {check_local_addr 1}} {

	set fn {ob_net_util::get_best_guess_ip}
	ob_log::write INFO {$fn: remote_addr $remote_addr x_forwarded_for $x_forwarded_for}

	if {[ob_chk::ipaddr $remote_addr] != "OB_OK"} {
		return "OB_NO_VALID_IP"
	}

	set ip_addr $remote_addr

	set forwarded_ips [split $x_forwarded_for ","]

	for {set i 0} {$i < [llength $forwarded_ips]} {incr i} {
		set fwd_ip [string map {" " ""} [lindex $forwarded_ips $i]]

		if {[ob_chk::ipaddr $fwd_ip] == "OB_OK"} {

			if {$check_local_addr} {

				# only use if it is a public ip
				if {![_is_loopback_addr $fwd_ip] && ![_is_local_addr $fwd_ip]} {
					return $fwd_ip
				}

			} else {

				# only use if it is a public ip
				if {![_is_loopback_addr $fwd_ip]} {
					return $fwd_ip
				}
			}
		}
	}

	return $ip_addr
}



# Private procedure to see if IP is a loopback address
# (range 127.0.0.0 - 127.255.255.255)
#
#    ipaddr  - ip to check
#    returns - 1/0
#
proc ob_net_util::_is_loopback_addr {ipaddr} {

	return [regexp {^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$} $ipaddr]

}



# Private procedure to determine if IP a local address
# (10.0.0.0 - 10.255.255.255, 192.168.00.00 - 192.168.255.255,
# 172.16.0.0 - 172.31.255.255)
#
#    ipaddr  - ip to check
#    returns - 1/0
#
proc ob_net_util::_is_local_addr {ipaddr} {

	if {[regexp {^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$} $ipaddr] || \
	    [regexp {^192\.168\.[0-9]{1,3}\.[0-9]{1,3}$} $ipaddr] || \
	    [regexp {^172\.(1[6789]|2\d|3[01])\.[0-9]{1,3}\.[0-9]{1,3}$} $ipaddr] \
	} {
		return 1
	} else {
		return 0
	}
}
