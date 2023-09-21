# $Id: realmapping.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# Interface to RealMapping server, provides 'ip_to_cc' function
# to convert IP addresses to their likely 2-char ISO country code
#
# The following configuration entries affect this module:
#
#   REALMAPPING_HOST        Host IP for the RealMapping server
#   REALMAPPING_PORT        Port number for the RealMapping server
#   REALMAPPING_UNKNOWN     Pseudo country code for unknown IPs (default: '??')
#   REALMAPPING_AOL         Pseudo country code for AOL IPs (default: REALMAPPING_UNKNOWN)
#   REALMAPPING_LOG_LEVEL   Log level for all RealMapping output
#

proc ip_to_cc {ipaddr} {
#
# This is required to provide the same functionality as the
#  TraceWare library (which adds 'ip_to_cc' into the root namespace)
#

	return [OB::RealMapping::ip_to_cc $ipaddr]
}

namespace eval OB::RealMapping {

	variable initialised
	set initialised 0

	variable RM_HOST
	variable RM_PORT
	variable RM_UNKNOWN
	variable RM_AOL
	variable LOG_LEVEL

	namespace export init
	namespace export ip_to_cc

}

proc OB::RealMapping::init {} {

	variable RM_HOST
	variable RM_PORT
	variable RM_UNKNOWN
	variable RM_AOL
	variable LOG_LEVEL

	variable initialised

	package require OB_Log

	set RM_HOST      [OT_CfgGet REALMAPPING_HOST localhost]
	set RM_PORT      [OT_CfgGet REALMAPPING_PORT 3000]
	set RM_UNKNOWN   [OT_CfgGet REALMAPPING_UNKNOWN "??"]
	set RM_AOL       [OT_CfgGet REALMAPPING_AOL $RM_UNKNOWN]

	set initialised 1
}

proc OB::RealMapping::ip_to_cc {ipaddr} {

	variable RM_HOST
	variable RM_PORT
	variable RM_UNKNOWN
	variable RM_AOL

	variable initialised

	if {!$initialised} {
		init
	}

	if [catch {set s [socket $RM_HOST $RM_PORT]}] {
		ob::log::write CRITICAL {failed to connect to server $RM_HOST:$RM_PORT}
		return $RM_UNKNOWN
	}

	puts  $s "<RSERVER><IP>$ipaddr</IP></RSERVER>"
	flush $s

	set ret ""
	while {![eof $s]} {
		append ret [read $s]
	}
	close $s

	#
	# basically we only care if it worked, we could easily
	# decipher the error, but we're not really interested.
	#

	if {[regexp "<Country_ISO_2>(\[A-Z\]\[A-Z\])</Country_ISO_2>" $ret all cc]} {
		ob::log::write INFO {RealMapping identified $ipaddr as $cc}
		return $cc
	} elseif {[regexp "<Country_ISO_2>11</Country_ISO_2>" $ret]} {
		ob::log::write INFO {RealMapping $ipaddr as AOL, returning $RM_AOL}
		return $RM_AOL
	}

	regsub -all {[\n\r]} $ret {} ret

	ob::log::write INFO {RealMapping did not identify $ipaddr and returned $RM_UNKNOWN}

	return $RM_UNKNOWN
}


