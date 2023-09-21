# $Id: stats.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
# OpenBet %Z%%M% %R%.%L% %E%
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval stats {

	variable STATS
	variable REQ_TIME
	variable REQ_SVC

	set STATS(host) [OT_CfgGet STATS_HOST ""]
	set STATS(port) [OT_CfgGet STATS_PORT ""]
	set STATS(chan) ""

	namespace export req_init
	namespace export req_end
}


#
# Mark the time of request initialisation
#
proc stats::req_init svc {
	variable REQ_TIME
	variable REQ_SVC
	set REQ_SVC $svc
	set REQ_TIME [OT_MicroTime -milli]
}


#
# Mark the end of the request - send a message to the stats server if
# a connection is/can be established
#
proc stats::req_end {action} {
	variable REQ_TIME
	variable REQ_SVC
	variable STATS
	if {$STATS(chan) == ""} {
		if {![stats::chan_open]} {
			return
		}
	}
	set now [OT_MicroTime -milli]
	set ivl [expr {$now-$REQ_TIME}]
	set msg [list $REQ_SVC action $action $ivl]


	if {[catch {puts $STATS(chan) $msg}]} {
		catch {close $STATS(chan)}
		set STATS(chan) ""
	}

	return

	if {[info commands ::OB_db::read_stats] != ""} {
		set msg [join [::OB_db::read_stats $REQ_SVC] "\n"]
		if {$msg != ""} {

			if {[catch {puts $STATS(chan) $msg}]} {
				catch {close $STATS(chan)}
				set STATS(chan) ""
			}
		}

	}
}


#
# Open channel to stats server
#
proc stats::chan_open {} {

	variable STATS

	if {$STATS(chan) != ""} {
		return 1
	}

	if {$STATS(host) != "" && $STATS(port) != ""} {
		if {[catch {set s [socket $STATS(host) $STATS(port)]}]} {
			set STATS(chan) ""
			return 0
		}
	} else {
		return 0
	}

	catch {fconfigure $s -buffering line}
	catch {fconfigure $s -blocking  0}

	set STATS(chan) $s

	return 1
}
