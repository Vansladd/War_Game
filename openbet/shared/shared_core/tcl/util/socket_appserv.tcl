#
# (C) 2012 Openbet Technology Ltd. All rights reserved.
#
# Make direct socket connections to an appserver bypassing Apache
#
# Synopsis:
#    package require core::socket::appserv ?1.0?
#
# Procedures:
#    core::socket::appserv::init      one time initialisation (uses config file)
#
set pkgVersion 1.0

package provide core::socket::appserv $pkgVersion

package require core::log            1.0
package require core::args           1.0
package require core::check          1.0
package require core::socket::client 1.0

namespace eval core::socket::appserv {
	variable CFG
	variable INIT 0
}

core::args::register_ns \
	-namespace core::socket::appserv \
	-version   $pkgVersion \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::socket::client] \
	-desc {}

proc core::socket::appserv::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	core::log::write INFO {core::socket::appserv: init}

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
# @param host host on which appserver is running
# @param port port on which appserver is running
# @param env_nv list of name value pairs to put in environment
# @param arg_nv list of arguments as name value pairs
#
# @return - list:
#   SUCESS :  OB_OK [response from appserver]
#   ERROR  :  err_code [error message]
#   err_code is:
#   OB_ERR_CONNECT - Cannot connect
#   OB_ERR_VERIFY  - Fail on intital handshake
#   OB_ERR_SEND    - Error sending some or all of messaage
#   OB_ERR_READ    - Failure on getting response from appserver.

core::args::register \
	-proc_name core::socket::appserv::send_request \
	-args      [list \
		[list -arg -host   -mand 1 -check ASCII -desc {host on which appserver is running}] \
		[list -arg -port   -mand 1 -check INT   -desc {port on which appserver is running}] \
		[list -arg -env_nv -mand 0 -check ANY   -desc {list of name value pairs to put in environment}] \
		[list -arg -arg_nv -mand 0 -check ANY   -desc {list of arguments as name value pairs}] \
	]

proc core::socket::appserv::send_request args {

	init

	array set ARGS [core::args::check core::socket::appserv::send_request {*}$args]

	set host   $ARGS(-host)
	set port   $ARGS(-port)
	set env_nv $ARGS(-env_nv)
	set arg_nv [encoding convertto utf-8 $ARGS(-arg_nv)]

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
		core::socket::client::force_close $sock
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
	core::log::write INFO {core::socket::appserv: TIMINGS [format "connect: %.4f, send: %.4f, resp: %.4f, total: %.4f" $connect_time $send_time $resp_time $total_time]}
	return [list OB_OK [lindex $ret 1]]
}



#----------------------------------------------------------------------------
# Private Procedures
#----------------------------------------------------------------------------

# Make a string from name/value pair arguments. Each pair is separated
# by supplied character
#
# TODO use correct urlencoding
#
proc core::socket::appserv::_mk_as_str {nv_list c {sep "="}} {

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
proc core::socket::appserv::_asConn {host port} {

	variable CFG

	core::log::write INFO {core::socket::appserv: Connecting to $host:$port with timeout $CFG(conn_timeout)}

	if {[catch {set sock [core::socket::client::connect \
		-host    $host \
		-port    $port \
		-timeout $CFG(conn_timeout)] \
	} msg]} {
		core::log::write ERROR {core::socket::appserv: Failed to connect to $host:$port. $msg}
		return [list OB_ERR_CONNECT $msg]
	}

	# Wait to read one line before sending message. A line has
	# already been read by core::socket::client, which is the Appserv
	# version line. We need to read a second line before
	# sending the request.
	# If we don't get this quicky enough we return a VERIFY error
	if {[catch {set line [core::socket::client::read \
		-sock    $sock \
		-timeout $CFG(read_timeout)] \
	} msg]} {
		core::log::write ERROR {core::socket::appserv: Failed to read. $msg}
		core::socket::client::force_close $sock
		return [list OB_ERR_VERIFY $msg]
	}

	core::log::write DEV {core::socket::appserv: Received $line}

	return [list OB_OK $sock]
}



# Send request
proc core::socket::appserv::_asSendReq {sock env_str arg_str} {

	fconfigure $sock -translation binary -buffering none

	set line [format "Env-Length = %d\nPost-Length = %d\n\n"\
		[expr {[string length $env_str]+1}]\
		[string length $arg_str]]

	set message $env_str\004$arg_str

	# Write header
	puts -nonewline $sock $line

	# Write message
	puts -nonewline $sock $message

	core::log::write DEBUG {------------------------------}
	core::log::write DEBUG {$line $message}
	core::log::write DEBUG {------------------------------}

	flush $sock
}



# Read response
proc core::socket::appserv::_asReadResp {sock} {

	variable CFG

	set resp ""
	set line ""

	fconfigure $sock -buffering line

	while {![eof $sock]} {

		if {[catch {set line [core::socket::client::read \
			-sock    $sock \
			-timeout $CFG(resp_timeout)] \
		} msg]} {
			core::log::write ERROR {core::socket::appserv: Failed to read. $msg}
			core::socket::client::force_close $sock
			return [list OB_ERR_READ $msg]
		}

		core::log::write DEV {core::socket::appserv: Received $line}

		append resp "$line\n"
	}

	catch {close $sock}

	return [list OB_OK $resp]
}
