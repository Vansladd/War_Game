# $Id: nohttp.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Make direct connections to an appserver bypassing Apache
#
# Required Configuration:
#
# Optional Configuration:
#
# Synopsis:
#    package require appserv_nohttp ?4.5?
#
# Procedures:
#    ob_nohttp::init      one time initialisation (uses config file)
#

package provide appserv_nohttp 4.5

package require util_log
package require net_sockclient


namespace eval ob_nohttp {
	variable CFG
	variable INIT 0
}


proc ob_nohttp::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	ob_log::write INFO {ob_nohttp: init}

	array set OPT [list \
		conn_timeout 30000 \
		read_timeout 30000 \
		resp_timeout 300000 \
		log         1 \
	]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "NO_HTTP_[string toupper $c]" $OPT($c)]
	}

	set INIT 1
}



# send_request - Send request to an appserver
#
#   host   - host on which appserver is running
#   port   - port on which appserver is running
#   env_nv - list of name value pairs to put in environment
#   arg_nv - list of arguments as name value pairs
#
#   Returns - list:
#   SUCESS :  OB_OK [response from appserver]
#   ERROR  :  err_code [error message]
#   err_code is:
#   OB_ERR_CONNECT - Cannot connect
#   OB_ERR_VERIFY  - Fail on intital handshake
#   OB_ERR_SEND    - Error sending some or all of messaage
#   OB_ERR_READ    - Failure on getting response from appserver.
proc ob_nohttp::send_request {host port env_nv arg_nv} {
	init
	set total_start [OT_MicroTime -micro]

	set estr [_mk_as_str $env_nv \004]
	set astr [_mk_as_str $arg_nv &]

	set connect_start [OT_MicroTime -micro]
	# connect
	set ret [_asConn $host $port]
	set connect_time [expr {[OT_MicroTime -micro] - $connect_start}]

	if {[lindex $ret 0] != "OB_OK"} {
		return $ret
	}

	set sock [lindex $ret 1]

	set send_start [OT_MicroTime -micro]
	if {[catch {
		_asSendReq $sock $estr $astr
	} msg]} {
		ob_sockclt::force_close $sock
		return [list OB_ERR_SEND $msg]
	}
	set send_time [expr {[OT_MicroTime -micro] - $send_start}]

	set resp_start [OT_MicroTime -micro]
	set ret [_asReadResp $sock]

	if {[lindex $ret 0] != "OB_OK"} {
		return $ret
	}
	set resp_time [expr {[OT_MicroTime -micro] - $resp_start}]

	set total_time [expr {[OT_MicroTime -micro] - $total_start}]
	ob_log::write INFO {ob_nohttp: TIMINGS [format "connect: %.4f, send: %.4f, resp: %.4f, total: %.4f" $connect_time $send_time $resp_time $total_time]}
	return [list OB_OK [lindex $ret 1]]
}



#----------------------------------------------------------------------------
# Private Procedures
#----------------------------------------------------------------------------

# Make a string from name/value pair arguments. Each pair is separated
# by supplied character
#
proc ob_nohttp::_mk_as_str {nv_list c {sep "="}} {

	set vals [list]

	foreach {n v} $nv_list {
		lappend vals "${n}${sep}${v}"
	}

	return [join $vals $c]
}



# Connect to appserver
#
# Returns a list:
#     OK socket
#     err_code  msg
#   where err_code is
#   OB_ERR_CONNECT - Error connecting
#   OB_ERR_VERIFY  - Error with intial handshake after connection
proc ob_nohttp::_asConn {host port} {

	variable CFG

	ob_log::write INFO {ob_nohttp: Connecting to $host:$port with timeout $CFG(conn_timeout)}

	if {[catch {set sock [ob_sockclt::connect $host $port $CFG(conn_timeout)]} msg]} {
		ob_log::write ERROR {ob_nohttp: Failed to connect to $host:$port. $msg}
		return [list OB_ERR_CONNECT $msg]
	}

	# Wait to read one line before sending message. A line has
	# already been read by ob_sockclt, which is the Appserv
	# version line. We need to read a second line before
	# sending the request.
	# If we don't get this quicky enough we return a VERIFY error
	if {[catch {set line [ob_sockclt::read $sock $CFG(read_timeout)]} msg]} {
		ob_log::write ERROR {ob_nohttp: Failed to read. $msg}
		ob_sockclt::force_close $sock
		return [list OB_ERR_VERIFY $msg]
	}

	ob_log::write DEV {ob_nohttp: Received $line}

	return [list OB_OK $sock]
}



# Send request
#
proc ob_nohttp::_asSendReq {sock env_str arg_str} {

	fconfigure $sock -translation binary -buffering none

	set line [format "Env-Length = %d\nPost-Length = %d\n\n"\
		[expr {[string length $env_str]+1}]\
		[string length $arg_str]]

	# Write header
	puts -nonewline $sock $line

	# Write message
	puts -nonewline $sock $env_str\004$arg_str

	flush $sock
}



# Read response
#
proc ob_nohttp::_asReadResp {sock} {

	variable CFG

	set resp ""
	set line ""

	fconfigure $sock -buffering line

	while {![eof $sock]} {

		if {[catch {set line [ob_sockclt::read $sock $CFG(resp_timeout)]} msg]} {
			ob_log::write ERROR {ob_nohttp: Failed to read. $msg}
			ob_sockclt::force_close $sock
			return [list OB_ERR_READ $msg]
		}

		ob_log::write DEV {ob_nohttp: Received $line}

		append resp "$line\n"
	}

	catch {close $sock}

	return [list OB_OK $resp]
}
