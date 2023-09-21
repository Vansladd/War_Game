# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Client Socket
# API to provide client based TCP/IP socket communications with servers.
#
# Synopsis:
#    package require core::socket::client ?1.0?
#
# Procedures:
#    core::socket::client::connect   connect to server
#    core::socket::client::read      read a message/line with timeout
#    core::socket::client::write     write a message/line
#    core::socket::client::send      connect, write, read & close
#

set pkgVersion 1.0

package provide core::socket::client $pkgVersion


# Dependencies
# - not initialised
#
package require core::log   1.0
package require core::args  1.0
package require core::check 1.0

# Variables
namespace eval core::socket::client {}

core::args::register_ns \
	-namespace core::socket::client \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args] \
	-desc      {}

#--------------------------------------------------------------------------
# Connect
#--------------------------------------------------------------------------

# Connect to a server.
#
# The socket will be blocking and set to line buffering.
# Will raise an 'error' if enable to connect to the server.
#
#  @param host     server hostname/ip
#  @param port     server port number
#  @param timeout  connection timeout (milliseconds)
#     if set to -1, then no timeout
#  @return created socket
#

core::args::register \
	-proc_name core::socket::client::connect \
	-args      [list \
		[list -arg -host    -mand 1 -check ASCII             -desc {server hostname/ip}] \
		[list -arg -port    -mand 1 -check ASCII             -desc {server port number}] \
		[list -arg -timeout -mand 0 -check INT   -default -1 -desc {connection timeout (milliseconds)}] \
	]

proc core::socket::client::connect args {

	variable connected

	array set ARGS [core::args::check core::socket::client::connect {*}$args]

	set host    $ARGS(-host)
	set port    $ARGS(-port)
	set timeout $ARGS(-timeout)

	# set timeout on connection
	if {$timeout > -1} {

		# set a flag if timed out
		set connected ""
		set id [after $timeout {set connected "TIMED_OUT"}]

		# connect
		if {[catch {set sock [socket -async $host $port]} msg]} {
			core::log::write ERROR {core::socket::client: $msg}
			after cancel $id
			error $msg
		}

		# wait for the response, setting flag with status
		fileevent $sock w {set connected "OK"}
		vwait connected

		# cancel status flags
		after cancel $id
		fileevent $sock w {}

		# report if timed-out
		if {$connected == "TIMED_OUT"} {
			set msg "socket timeout after $timeout ms"
			core::log::write ERROR {core::socket::client: $msg}
			#  Attempt to close the socket in the background
			force_close -sock $sock
			error $msg
		}

	# no timeout on connection
	} elseif {[catch {set sock [socket $host $port]} msg]} {
		core::log::write ERROR {core::socket::client: $msg}
		error $msg
	}

	#  This checks to see if there is any error in opening
	#  as we are opening asynchronously
	#  This replaces the previous non-blocking read check
	# which was decidedly dodgy
	set msg [fconfigure $sock -error]
	if {$msg != ""} {
		core::log::write INFO {core::socket::client: connect error - $msg}
		force_close -sock $sock
		error "connect error - $msg"
	}

	# Set blocking and line buffering
	fconfigure $sock \
		-blocking  1 \
		-buffering line \
		-encoding  utf-8

	core::log::write INFO {core::socket::client: outbound socket $sock created on $host:$port}
	return $sock
}


#--------------------------------------------------------------------------
# Read/Write
#--------------------------------------------------------------------------

# Read a line from the server with timeout.
# Will raise an 'error' if connection times out or the socket is already closed
# (eof).
#
#   @param sock client socket
#   @param timeout timeout (milliseconds)
#   @return  received line
#
core::args::register \
	-proc_name core::socket::client::read \
	-args      [list \
		[list -arg -sock    -mand 1 -check ASCII             -desc {client socket}] \
		[list -arg -timeout -mand 0 -check INT   -default -1 -desc {connection timeout (milliseconds)}] \
	]
proc core::socket::client::read args {

	variable read

	array set ARGS [core::args::check core::socket::client::read {*}$args]

	set sock    $ARGS(-sock)
	set timeout $ARGS(-timeout)
	set read    ""

	# has socket closed?
	if {[eof $sock]} {
		set msg "read set eof for $sock"
		core::log::write ERROR {core::socket::client: $msg}
		set read "EOF"
		error $msg
	}

	# set a flag if timed out
	set id [after $timeout {set read "TIMED_OUT"}]

	# wait for the response, setting flag with status
	fileevent $sock r {set read "OK"}
	vwait read

	# cancel status flags
	fileevent $sock r {}
	after cancel $id

	# report if timed-out
	if {$read == "TIMED_OUT"} {
		set msg "socket timeout after $timeout ms"
		core::log::write ERROR {core::socket::client: $msg}
		set read "ERROR"
		error $msg
	}

	# get the reply
	if {[catch {set reply [gets $sock]} msg]} {
		core::log::write ERROR {core::socket::client: $msg}
		set read "ERROR"
		error $msg
	}

	return $reply
}

proc core::socket::client::read_status {} {
	variable read
	if {[info exists read]} {
		return $read
	} else {
		return ""
	}
}

# Write a message/line to the server.
# Will raise an 'error' if socket is already closed (eof) or write operation
# fails.
#
# @param sock client socket
# @param msg  message/line
#
core::args::register \
	-proc_name core::socket::client::write \
	-args      [list \
		[list -arg -sock -mand 1 -check ASCII -desc {client socket}] \
		[list -arg -msg  -mand 1 -check ANY   -desc {message/line}] \
	]

proc core::socket::client::write args {

	array set ARGS [core::args::check core::socket::client::write {*}$args]

	set sock $ARGS(-sock)
	set msg  $ARGS(-msg)

	# has socket closed?
	if {[eof $sock]} {
		set msg "read set eof for $sock"
		core::log::write ERROR {core::socket::client: $msg}
		error $msg
	}

	# write
	if {[catch {puts $sock $msg} msg]} {
		core::log::write ERROR {core::socket::client: $msg}
		error $msg
	}
}


#--------------------------------------------------------------------------
# Send (connect, write & read)
#--------------------------------------------------------------------------

# Connect, write a message, read the reply and close with timeout.
# The procedure incorporates a timeout for the whole operation, therefore,
# unable to utilise the connect and read APIs which set their own timeouts.
#
# @param host server hostname/ip
# @param port server port number
# @param message message to write
# @param timeout overall 'send' timeout (milliseconds)
# @return reply
#
core::args::register \
	-proc_name core::socket::client::send \
	-args      [list \
		[list -arg -host    -mand 1 -check ASCII -desc {server hostname/ip}] \
		[list -arg -port    -mand 1 -check INT   -desc {server port number}] \
		[list -arg -message -mand 1 -check ANY   -desc {message to write}] \
		[list -arg -timeout -mand 1 -check INT   -desc {overall 'send' timeout (milliseconds)}]
	]

proc core::socket::client::send args {

	variable status

	array set ARGS [core::args::check core::socket::client::send {*}$args]

	set host    $ARGS(-host)
	set port    $ARGS(-port)
	set message $ARGS(-message)
	set timeout $ARGS(-timeout)

	# set a flag on timeout
	set status ""
	set id [after $timeout {set status "TIMED_OUT"}]

	# connect
	if {[catch {set sock [socket -async $host $port]} msg]} {
		core::log::write ERROR {core::socket::client: $msg}
		after cancel $id
		error $msg
	}

	# wait for the response, setting flag with status
	fileevent $sock w {set status "OK"}
	vwait status
	fileevent $sock w {}

	# report if timed-out
	if {$status != "OK"} {
		set msg "socket timeout after $timeout ms"
		core::log::write ERROR {core::socket::client: $msg}
		after cancel $id
		force_close -sock $sock
		error $msg
	}

	core::log::write INFO {core::socket::client: outbound socket created on $host:$port}

	# attempt a non-blocking get in an attempt to capture a 'rare' connection
	# problem!
	fconfigure $sock -blocking 0
	if {[catch {gets $sock a} msg]} {
		core::log::write ERROR {SOCKCLT: non-blocking get failed - $msg}
		after cancel $id
		force_close -sock $sock
		error "non-blocking get failed - $msg"
	}

	# set blocking and line buffering
	fconfigure $sock -blocking 1 -buffering line

	# write message
	if {[catch {write -sock $sock -msg $message} msg]} {
		core::log::write ERROR {core::socket::client: $msg}
		after cancel $id
		force_close -sock $sock
		error $msg
	}

	# read the reply
	set msg ""
	set reply ""
	while {![eof $sock]} {

		# wait for the response, setting flag with status
		fileevent $sock r {set status "OK"}
		vwait status

		# report if time-out
		if {$status != "OK"} {
			set msg "socket timeout after $timeout ms"
			break
		}

		# read
		if {[catch {set r [gets $sock line]} msg]} {
			break
		}
		if {$r > 0} {
			append reply $line
		}
		set msg ""
	}

	# cleanup
	fileevent $sock r {}
	after cancel $id
	close $sock

	if {$msg != ""} {
		core::log::write ERROR {core::socket::client: $msg}
		error $msg
	}

	return $reply
}

#--------------------------------------------------------------------------
# Force Close
#--------------------------------------------------------------------------
#   Forces a non-blocking close
#   in case of error logs but continues
#    sock     - socket

core::args::register \
	-proc_name core::socket::client::force_close \
	-args      [list \
		[list -arg -sock -mand 1 -check ASCII -desc {socket}]
	]


proc core::socket::client::force_close args {

	array set ARGS [core::args::check core::socket::client::force_close {*}$args]

	set sock $ARGS(-sock)

	core::log::write INFO {SOCKCLT: Closing $sock}

	if {[catch {
		fconfigure $sock -blocking 0
		close $sock
	} msg]} {
		core::log::write ERROR {core::socket::client: Ignoring close error : $msg}
	}
}
