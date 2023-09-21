# $Id: sock_server.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Server Socket
# API to provide server based TCP/IP socket communications with clients. The API
# is very simple and maybe restrictive for some implementations. In such cases
# use the package as a reference/example for building your server.
#
# All created sockets are line buffered.
#
# Synopsis:
#    package require net_sockserver ?4.5?
#
# Procedures:
#    ob_socksvr::create  create a server socket
#    ob_socksvr::close   close a server socket
#

package provide net_sockserver 4.5



# Dependencies
#
package require util_log 4.5



# Variables
#
namespace eval ob_socksvr {

	variable CFG
	variable OPT_CFG

	# set optional cfg default values
	array set OPT_CFG [list\
	               message_handler {ob_socksvr::_msg_handler}]
}



#--------------------------------------------------------------------------
# Socket Create/Close
#--------------------------------------------------------------------------

# Create a server socket (set to line buffering).
#
# Allows the definition of a message handler which is called on each client
# request. The handler can process this request and send a reply (if necessary).
# If a handler is not supplied, then the default package handler is used which
# only returns a reply back to the client. The handler is only supplied as an
# example.
#
# Will raise an 'error' if unable to create the server socket.
#
#   port    - port number
#   handler - message handler (ob_socksvr::msg_handler)
#   returns - created socket
#
proc ob_socksvr::create { port {handler "::ob_socksvr::msg_handler"} } {

	variable CFG
	variable OPT_CFG

	# already created the socket
	if {[info exist CFG($port,socket)]} {
		error "Port $port already created"
	}

	# does the handler exist
	if {[info commands $handler] == ""} {
		error "Unknown handler \'$handler\'"
	}
	set CFG($port,handler) $handler

	# create the server socket
	# - pass the server port to the connection handler so we can use it to
	#   identify the configuration within CFG variable
	if {[catch {set CFG($port,socket) \
		      [socket -server [list ob_socksvr::_connect $port] $port]} msg]} {
		ob_log::write ERROR {SOCKSVR: $msg}
		_clear_cfg $port
		error $msg
	}

	# put server-socket into line-buffered mode
	fconfigure $CFG($port,socket) -buffering line

	ob_log::write INFO \
		{SOCKSVR: inbound socket $CFG($port,socket), created on port $port}
	return $CFG($port,socket)
}



# Close a server socket.
#
#    port - server port number
#
proc ob_socksvr::close { port } {

	variable CFG

	if {[info exists CFG($port,socket)]} {
		catch {close $CFG($port,socket)}
		_clear_cfg $port
	}
}



# Private procedure to clear the configuration for a server port.
#
#   port - server port
#
proc ob_socksvr::_clear_cfg { port } {

	variable CFG

	foreach f [array names CFG $port,*] {
		unset CFG($f)
	}
}



#--------------------------------------------------------------------------
# Handlers
#--------------------------------------------------------------------------

# Private procedure to handle a client connection.
# The connected client's socket is set to non-blocking and line buffered.
#
# The procedure is automatically called whenever a client makes a connection,
# and sets a fileevent to accept client messages (event handler).
#
# Do not call this procedure directly.
#
#   svr_port - server port (identifies server configuration)
#   sock     - client socket
#   addr     - client IP address
#   port     - client port number
#
proc ob_socksvr::_connect { svr_port sock addr port } {

	ob_log::write INFO \
	   {SOCKSVR: client connected, server=$svr_port addr=$addr:$port sock=$sock}

	# put client-socket into non-blocking, line-buffered mode
	fconfigure $sock -blocking  0
	fconfigure $sock -buffering line

	# Add handler for incoming message
	# - additional parameters added to handler to identify the server port
	#   and the client's socket
	set h [list ob_socksvr::_event_handler $svr_port $sock]
	if {[catch {fileevent $sock readable $h} msg]} {
		ob_log::write ERROR {SOCKSVR: $msg}
		error $msg
	}
}



# Private procedure to handle an incoming client message/request.
#
# The handler is called for each received message. The procedure will get the
# message then call the user-defined message handler, as defined on socket
# creation.
#
# Do not call this procedure directly.
#
#   svr_port - server port (identifies server configuration)
#   sock     - client socket
#
proc ob_socksvr::_event_handler { svr_port sock } {

	variable CFG

	# check if this is a configured port
	if {![info exists CFG($svr_port,socket)]} {
		ob_log::write ERROR {SOCKSVR: unknown configured server port}
		_disconnect $sock
		return
	}

	# eof reached?
	if {[eof $sock]} {
		ob_log::write DEBUG {SOCKSVR: read set eof for $sock}
		_disconnect $sock
		return
	}

	# read the message
	# - force a disconnect on error
	if {[catch {set r [gets $sock line]} msg]} {
		ob_log::write ERROR {SOCKSVR: read from order agent failed: $msg}
		_disconnect $sock
		return
	}

	# no error, but no data
	if {$r == -1} {
		return
	}

	# eof on client socket
	if {[eof $sock]} {
		ob_log::write DEBUG {SOCKSVR: read set eof for $sock}
		_disconnect $sock
		return
	}

	# call the message_handler to process the read message
	if {[catch {eval [subst {$CFG($svr_port,handler) $sock {$line}}]} msg]} {
		ob_log::write ERROR \
		    {SOCKSVR: failed to execute message handler - $msg}
	}
}



# Default message handler.
#
# Called by the event handler to process the client request and perform any
# necessary response[s]. This handler is provided as an example, as it only
# returns a simple message.
#
# A caller should provide their own handler to the socket create procedure
# to perform their specific operations.
#
#   sock    - client socket
#   message - message
#
proc ob_socksvr::msg_handler { sock {message ""} } {

	set msg "SOCKSVR: sock=$sock msg=$message"
	ob_log::write DEV {$msg}

	puts $sock $msg
}



#--------------------------------------------------------------------------
# Client Disconnect
#--------------------------------------------------------------------------

# Private procedure to disconnect/close a client socket.
#
#   sock - client socket
#
proc ob_socksvr::_disconnect { sock } {

	ob_log::write DEBUG {SOCKSVR: closing socket $sock}

	catch {fileevent $sock readable ""}
	catch {close $sock}
}
