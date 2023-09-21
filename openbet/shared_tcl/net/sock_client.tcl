# $Id: sock_client.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Client Socket
# API to provide client based TCP/IP socket communications with servers.
#
# Synopsis:
#    package require net_sockclient ?4.5?
#
# Procedures:
#    ob_sockclt::connect   connect to server
#    ob_sockclt::read      read a message/line with timeout
#    ob_sockclt::write     write a message/line
#    ob_sockclt::send      connect, write, read & close
#

package provide net_sockclient 4.5



# Dependencies
# - not initialised
#
package require util_log 4.5



# Variables
#
namespace eval ob_sockclt {
}



#--------------------------------------------------------------------------
# Connect
#--------------------------------------------------------------------------

# Connect to a server.
#
# The socket will be blocking and set to line buffering.
# Will raise an 'error' if enable to connect to the server.
#
#    host    - server hostname/ip
#    port    - server port number
#    timeout - connection timeout (milliseconds)
#              if set to 'none', then no timeout
#    returns - created socket
#
proc ob_sockclt::connect { host port {timeout none} } {

	variable connected

	# set timeout on connection
	if {$timeout != "none"} {

		# set a flag if timed out
		set connected ""
		set id [after $timeout {set ob_sockclt::connected "TIMED_OUT"}]

		# connect
		if {[catch {set sock [socket -async $host $port]} msg]} {
			ob_log::write ERROR {SOCKCLT: $msg}
			after cancel $id
			error $msg
		}

		# wait for the response, setting flag with status
		fileevent $sock w {set ob_sockclt::connected "OK"}
		vwait ob_sockclt::connected

		# cancel status flags
		after cancel $id
		fileevent $sock w {}

		# report if timed-out
		if {$connected == "TIMED_OUT"} {
			set msg "socket timeout after $timeout ms"
			ob_log::write ERROR {SOCKCLT: $msg}
			catch {close $sock}
			error $msg
		}

	# no timeout on connection
	} elseif {[catch {set sock [socket $host $port]} msg]} {
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	# attempt a non-blocking get in an attempt to capture a 'rare' connection
	# problem!
	fconfigure $sock -blocking 0
	if {[catch {gets $sock a} msg]} {
		ob_log::write ERROR {SOCKCLT: non-blocking get failed - $msg}
		catch {close $sock}
		error "non-blocking get failed - $msg"
	}

	# set blocking and line buffering
	fconfigure $sock -blocking 1 -buffering line

	ob_log::write INFO {SOCKCLT: outbound socket created on $host:$port}
	return $sock
}



#--------------------------------------------------------------------------
# Read/Write
#--------------------------------------------------------------------------

# Read a line from the server with timeout.
# Will raise an 'error' if connection times out or the socket is already closed
# (eof).
#
#   sock     - client socket
#   timeout  - timeout (milliseconds)
#   returns  - received line
#
proc ob_sockclt::read { sock timeout } {

	variable read

	set read ""

	# has socket closed?
	if {[eof $sock]} {
		set msg "read set eof for $sock"
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	# set a flag if timed out
	set id [after $timeout {set ob_sockclt::read "TIMED_OUT"}]

	# wait for the response, setting flag with status
	fileevent $sock r { set ob_sockclt::read "OK"}
	vwait ob_sockclt::read

	# cancel status flags
	fileevent $sock r {}
	after cancel $id

	# report if timed-out
	if {$read == "TIMED_OUT"} {
		set msg "socket timeout after $timeout ms"
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	# get the reply
	if {[catch {set reply [gets $sock]} msg]} {
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	return $reply
}



# Write a message/line to the server.
# Will raise an 'error' if socket is already closed (eof) or write operation
# fails.
#
#   sock - client socket
#   msg  - message/line
#
proc ob_sockclt::write { sock msg } {

	# has socket closed?
	if {[eof $sock]} {
		set msg "read set eof for $sock"
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	# write
	if {[catch {puts $sock $msg} msg]} {
		ob_log::write ERROR {SOCKCLT: $msg}
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
#    host     - server hostname/ip
#    port     - server port number
#    message  - message to write
#    timeout  - overall 'send' timeout (milliseconds)
#    returns  - reply
#
proc ob_sockclt::send { host port message timeout } {

	variable status

	# set a flag on timeout
	set status ""
	set id [after $timeout {set ob_sockclt::status "TIMED_OUT"}]

	# connect
	if {[catch {set sock [socket -async $host $port]} msg]} {
		ob_log::write ERROR {SOCKCLT: $msg}
		after cancel $id
		error $msg
	}

	# wait for the response, setting flag with status
	fileevent $sock w {set ob_sockclt::status "OK"}
	vwait ob_sockclt::status
	fileevent $sock w {}

	# report if timed-out
	if {$status != "OK"} {
		set msg "socket timeout after $timeout ms"
		ob_log::write ERROR {SOCKCLT: $msg}
		after cancel $id
		close $sock
		error $msg
	}

	ob_log::write INFO {SOCKCLT: outbound socket created on $host:$port}

	# attempt a non-blocking get in an attempt to capture a 'rare' connection
	# problem!
	fconfigure $sock -blocking 0
	if {[catch {gets $sock a} msg]} {
		ob_log::write ERROR {SOCKCLT: non-blocking get failed - $msg}
		after cancel $id
		close $sock
		error "non-blocking get failed - $msg"
	}

	# set blocking and line buffering
	fconfigure $sock -blocking 1 -buffering line

	# write message
	if {[catch {write $sock $message} msg]} {
		ob_log::write ERROR {SOCKCLT: $msg}
		after cancel $id
		close $sock
		error $msg
	}

	# read the reply
	set msg ""
	set reply ""
	while {![eof $sock]} {

		# wait for the response, setting flag with status
		fileevent $sock r {set ob_sockclt::status "OK"}
		vwait ob_sockclt::status

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
		ob_log::write ERROR {SOCKCLT: $msg}
		error $msg
	}

	return $reply
}
