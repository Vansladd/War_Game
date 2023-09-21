# ==============================================================
# $Id: messages.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

array set ::MSG_SVC [list]

#======================================================================
# Setup map of msg type to host/port of router
#
proc MsgSvcConfig {svc} {

	if {[llength [set detail [split $svc : ]]] != 3} {
		error "expected host:port:type, got $svc"
	}

	ob::log::write INFO {Adding message service: $svc}

	foreach {host port type} $detail { }

	set ::MSG_SVC($type) [list $port $host]
}


#======================================================================
# Open channel for notification server
#
proc MsgSvcChanOpen {type} {

	variable ::MSG_SVC_CONNECTED

	if {![info exists ::MSG_SVC($type)]} {
		ob::log::write ERROR {MsgSvcChanOpen: no router info for type $type}
		error "Failed to find router info for type $type"
	}

	foreach {port host} $::MSG_SVC($type) { break }

	set ::MSG_SVC_CONNECTED ""
	set timeout [OT_CfgGet NOTIF_SVC_TIMEOUT 2000]
	set alarm [after $timeout {set ::MSG_SVC_CONNECTED "TIMED OUT"}]

	if {[catch {set chan [socket -async $host $port]} msg]} {
		catch {unset ::MSG_SVC($port,$host,chan)}
		error "(for $type) : failed to open socket $host $port \[$msg\]"
	}

	fileevent $chan w {set ::MSG_SVC_CONNECTED "OK"}
	vwait ::MSG_SVC_CONNECTED
	after cancel $alarm
	fileevent $chan w {}

	if {$::MSG_SVC_CONNECTED != "OK"} {
		catch {unset ::MSG_SVC($port,$host,chan)}
		error "(for $type) : failed to open socket $host $port \[stopped waiting after ${timeout}ms\]"
	}

	fconfigure $chan -buffering line
	fconfigure $chan -blocking  0

	set ::MSG_SVC($port,$host,chan) $chan

	return $chan
}


#======================================================================
# Write notification string
#
proc MsgSvcNotifyStr {type str} {

	if {![info exists ::MSG_SVC($type)]} {
		ob::log::write ERROR {MsgSvcNotifyStr: no router info for type $type}
		return
	}

	foreach {port host} $::MSG_SVC($type) { break }

	if {[catch {set chan $::MSG_SVC($port,$host,chan)}]} {
		if {[catch {set chan [MsgSvcChanOpen $type]} msg]} {
			ob::log::write ERROR {Notify ($type) failed : $msg}
			return
		}
	}

	if {[catch {puts $chan $str} msg]} {
		ob::log::write ERROR {Notify ($type) failed: $msg}
		catch {unset ::MSG_SVC($port,$host,chan)}
 		catch {close $chan}
	} elseif {[OT_CfgGet NOTIF_SVC_RECYCLE_SOCKETS 0]} {
		catch {unset ::MSG_SVC($port,$host,chan)}
		catch {close $chan}
	}
}


#======================================================================
# send a notification : args is a list of the name/value pairs to send
#
proc MsgSvcNotify {type args} {

	if {([llength $args] % 2) == 1} {
		error "Notify ($type) : need name/value pairs"
	}

	set str [concat msg-type $type $args]

	MsgSvcNotifyStr $type [join $str "\t"]
}


#======================================================================
# one-time setup...
#
set NOTIF_SVC_LIST [OT_CfgGet NOTIF_SVC_LIST [list]]

foreach NOTIF_SVC $NOTIF_SVC_LIST {
	MsgSvcConfig $NOTIF_SVC
}

catch {unset NOTIF_SVC_LIST}
catch {unset NOTIF_SVC}

if {[OT_CfgGet NOTIF_SVC_RECYCLE_SOCKETS 0]} {
	ob::log::write ERROR {Message service sockets will be recycled after each message}
}
