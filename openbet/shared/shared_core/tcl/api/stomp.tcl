# (C) 2011 OpenBet Technologies Ltd. All rights reserved.
#
# STOMP
# Library to format, send and receive messages to a STOMP server
#

set pkg_version 1.0
package provide core::api::stomp $pkg_version

#
# Dependencies
#
package require core::socket::client 1.0
package require core::args           1.0
package require core::log            1.0


core::args::register_ns \
	-namespace core::api::stomp \
	-version $pkgVersion \
	-dependent [list core::args core::log core::socket::client] \
	-desc {STOMP library} \
	-docs "xml/api/stomp.xml"

namespace eval core::api::stomp {
	variable CFG
	# list queue of incoming frames
	variable INCOMING_FRAMES [list]
	# fileevent's on socket
	variable WRITE_STATUS_FLAG {}
	# emitted by parser when a full STOMP frame is parsed
	variable READ_FULL_FRAME_FLAG {}

	array set CFG [list]
	set CFG(init) 0
	set CFG(connected) 0
	set CFG(stomp_socket) {}
}


core::args::register \
	-proc_name core::api::stomp::init \
	-desc {Initialise stomp connection} \
	-args [list \
		[list -arg -remote_host        -mand 0 -check STRING -default_cfg STOMP_HOST         -default {}    -desc {Remote Host}] \
		[list -arg -port               -mand 0 -check UINT   -default_cfg STOMP_PORT         -default 0     -desc {Remote Port}] \
		[list -arg -virtual_host       -mand 0 -check STRING -default_cfg STOMP_VHOST        -default {}    -desc {Virtual Host}] \
		[list -arg -login              -mand 0 -check STRING -default_cfg STOMP_LOGIN        -default {}    -desc {Host login}] \
		[list -arg -passcode           -mand 0 -check STRING -default_cfg STOMP_PASSCODE     -default {}    -desc {Host password}] \
		[list -arg -heart_beat         -mand 0 -check STRING -default_cfg STOMP_HEART_BEAT   -default {}    -desc {Heart beating}] \
		[list -arg -connection_timeout -mand 0 -check INT    -default_cfg STOMP_CONN_TIMEOUT -default 10000 -desc {Connection timeout. -1 for no timeout.}] \
		[list -arg -force_init         -mand 0 -check BOOL                                   -default 0     -desc {Force initialisation}]
	] \
	-body {
		variable CFG

		# already initialised?
		if {$CFG(init) && !$ARGS(-force_init)} {
			return
		}

		# We might be forcing a re-initialisation, disconnect if already connected
		if {$CFG(connected)} {
			_close_socket $CFG(stomp_socket)
		}

		# initalise dependencies
		core::log::init

		set CFG(remote_host)        $ARGS(-remote_host)
		set CFG(port)               $ARGS(-port)
		set CFG(virtual_host)       $ARGS(-virtual_host)
		set CFG(login)              $ARGS(-login)
		set CFG(passcode)           $ARGS(-passcode)
		set CFG(heart_beat)         $ARGS(-heart_beat)
		set CFG(connection_timeout) $ARGS(-connection_timeout)

		set CFG(init)      1
		set CFG(connected) 0

		core::log::write INFO {STOMP Initialised}
	}

# This proc is to initalise the connection, which will be kept open persistently unless
# it stops working and a forced close is required
core::args::register \
	-proc_name core::api::stomp::connect \
	-desc      {Connect to a JMS host} \
	-body {
		variable CFG

		set fn {core::api::stomp::connect}

		if {$CFG(connected)} {
			core::log::write INFO {$fn: already connected, reinitalising connection}
			_close_socket $CFG(stomp_socket)
		}

		set CFG(stomp_socket) [core::api::stomp::_connect\
			$CFG(remote_host)\
			$CFG(port)\
			$CFG(virtual_host)\
			$CFG(connection_timeout) \
			$CFG(login)\
			$CFG(passcode)\
			$CFG(heart_beat)]
	}



#--------------------------------------------------------------------------
# Send
#--------------------------------------------------------------------------

# This proc initiates a STOMP connection by calling the _connect proc.
# If the connection is successful, it send the message to the STOMP server
# with the SEND frame. If the message was received by the server successfully,
# a response holding the receipt id is returned. The proc then strips the
# receipt id from the response and returns it to the calling proc.
#
#    data         - body of the STOMP message
#    remote_host  - server hostname
#    port         - server port number
#    login        - login for a secured Stomp server. If not set then
#                   authentication is not used.
#    passcode     - passcode for a secured Stomp server
#    destination  - location the message is destined to(queue or topic name)
#    content_type - content type of the message body
#    msg_id       - message identifier
#    headers      - additional client specific headers
#    timeout      - connection timeout (milliseconds)
#
#    returns      - receipt id

#
# This proc initialises the connection if it isn't there, then pushes the messages to JMS.
#
core::args::register \
	-proc_name core::api::stomp::send \
	-desc {Initialise the connection if it isn't there, then push the messages to JMS} \
	-args [list \
		[list -arg -data               -mand 1 -check STRING                                            -desc {Body of the STOMP message}] \
		[list -arg -destination        -mand 1 -check STRING                                            -desc {Message destination (queue or topic name)}] \
		[list -arg -content_type       -mand 1 -check STRING                                            -desc {Content type of the message body}] \
		[list -arg -msg_id             -mand 1 -check STRING                                            -desc {Message identifier}] \
		[list -arg -headers            -mand 1 -check STRING                                            -desc {Additional client specific headers}] \
		[list -arg -timeout            -mand 0 -check UINT    -default_cfg STOMP_TIMEOUT -default 10000 -desc {Request timeout}] \
		[list -arg -retry              -mand 0 -check BOOL                               -default 1     -desc {Retry (once) upon failure}] \
	] \
	-body {
		variable CFG

		set fn {core::api::stomp::send}
		core::log::write INFO {$fn: destination=$ARGS(-destination)}
		core::log::write INFO {$fn: content_type=$ARGS(-content_type)}
		core::log::write INFO {$fn: msg_id=$ARGS(-msg_id)}
		core::log::write INFO {$fn: headers=$ARGS(-headers)}
		core::log::write INFO {$fn: timeout=$ARGS(-timeout)}
		core::log::write INFO {$fn: retry=$ARGS(-retry)}

		if {!$CFG(init)} {
			error "Package not initialised" {} SEND_ERROR
		}
		core::api::stomp::_start_timeout $ARGS(-timeout)
		core::log::write DEBUG {$fn : timeout started}

		if {!$CFG(connected)} {
			core::log::write DEBUG {$fn: not connected - connecting...}
			core::api::stomp::connect
			core::log::write DEBUG {$fn: connected}
		}

		if {[catch {
			set receipt [core::api::stomp::_send_stomp_frame\
				$CFG(stomp_socket)\
				$ARGS(-destination)\
				$ARGS(-content_type)\
				$ARGS(-msg_id)\
				$ARGS(-headers)\
				$ARGS(-data)]
		} msg]} {
			# In case of failure we need to force the socket to close,
			# and set CFG(connected) to 0 so the connection will be re-initialised.
			_close_socket $CFG(stomp_socket)
			if {$ARGS(-retry) == 1} {
				core::log::write WARNING {$fn: send failed: $msg - retrying}
				return [core::api::stomp::send \
					-data               $ARGS(-data)               \
					-destination        $ARGS(-destination)        \
					-content_type       $ARGS(-content_type)       \
					-msg_id             $ARGS(-msg_id)             \
					-headers            $ARGS(-headers)            \
					-timeout            $ARGS(-timeout)            \
					-retry 0 \
				]

			}
			core::log::write ERROR {$fn: send failed: $msg}
			error "Send failed: $msg" $::errorInfo SEND_ERROR
		}

		core::log::write INFO {$fn: receipt=$receipt}

		return $receipt

	}



#--------------------------------------------------------------------------
# Subscribe
#--------------------------------------------------------------------------
#
# This proc creates a persistent listening socket to receive messages
# broadcast on the JMS.
# It will construct an STOMP subscribe frame and return the created socket.
# Any messages still pending to be read with listen() from previous
# subscriptions in the INCOMING_FRAMES array will be purged.
#
# This does not trigger a callback when the socket is readable and so
# it is the responsibility of the calling code to read messages off of the queue.
core::args::register \
	-proc_name core::api::stomp::subscribe \
	-desc {Subscribe to the JMS, If no connection exists it will be initialised} \
	-args [list \
		[list -arg -destination        -mand 1 -check STRING                                            -desc {Message destination (queue or topic name)}] \
		[list -arg -retry              -mand 0 -check BOOL                               -default 1     -desc {Retry (once) upon failure}] \
		[list -arg -timeout            -mand 0 -check UINT    -default_cfg STOMP_TIMEOUT -default 10000 -desc {Request timeout}] \
		[list -arg -id                 -mand 0 -check UINT                               -default -1    -desc {Message ID used for request response reconcilation}] \
		[list -arg -ack_type           -mand 0 -check STRING                             -default auto   -desc {Message acknowledgement type}] \
		[list -arg -callback           -mand 0 -check STRING  -default {} -desc {Callback proc to call for each valid STOMP frame received}] \
	] \
	-body {
		variable CFG
		variable INCOMING_BUFFER {}
		variable INCOMING_FRAMES [list]

		set fn {core::api::stomp::subscribe}

		core::log::write INFO {$fn: destination=$ARGS(-destination) timeout=$ARGS(-timeout) retry=$ARGS(-retry)}

		if {!$CFG(init)} {
			error "Package not initialised" {} SEND_ERROR
		}

		core::log::write DEBUG {$fn: timeout started}

		if {!$CFG(connected)} {
			core::log::write DEBUG {$fn : not connected - connecting...}
			core::api::stomp::connect
			core::log::write DEBUG {$fn : connected}
		}

		if {[catch {
			set frame [core::api::stomp::_construct_subscribe_frame \
							$ARGS(-destination) \
							$ARGS(-id) \
							$ARGS(-ack_type)]

			core::log::write DEBUG {$fn : SUBSCRIBE frame constructed}
			core::api::stomp::_send_frame $CFG(stomp_socket) $frame 0

		} msg]} {
			if {$ARGS(-retry)} {
				core::log::write WARNING {$fn: failed: $msg - retrying}
				return [core::api::stomp::subscribe         \
					-destination $ARGS(-destination) \
					-retry       0
				]
			} else {
				error "Unabled to send subscribe frame: $msg" ::$errorInfo SEND_ERROR
			}
		}

		# register optional callback to call with each new STOMP frame received
		if {$ARGS(-callback) != ""} {
			if {[info complete $ARGS(-callback)]} {
				set CFG(callback) $ARGS(-callback)
				core::log::write INFO {successfully registered callback: $CFG(callback)}
			} else {
				core::log::write WARNING {not registered callback: $CFG(callback) - check namespace}
			}
		}

		return $CFG(stomp_socket)
	}



#--------------------------------------------------------------------------
# Listen
#
# Listen (poll) for incoming messages on a socket.  This should be used in conjunction
# with the subscribe procedure in order to consume the queue.
# This is a LEGACY/compatibility call that returns only the FIRST of the
# messages in the incoming stomp frame queue. Thus, you'll need to call it repeatedly
# to consume the queue of messages (eg. when resubscribing after a disconnection)
# You'd probably be better off registering a callback while calling subscribe()
#--------------------------------------------------------------------------
core::args::register \
	-proc_name core::api::stomp::listen \
	-desc {Listen for incoming messages} \
	-args [list \
		[list -arg -socket  -mand 0 -check STRING -default CONF  -desc {Socket to listen on}]\
		[list -arg -timeout -mand 0 -check STRING -default 10000 -desc {Socket timeout}]\
	] \
	-body {
		variable CFG

		set fn {core::api::stomp::listen}

		if {$ARGS(-socket) == {CONF}} {
			set ARGS(-socket) $CFG(stomp_socket)
		}

		set resp_frame      [_get_resp_frame]

		core::api::stomp::_log_stomp_frame INFO {STOMP RESP} $resp_frame

		return $resp_frame
	}

#--------------------------------------------------------------------------
# Check the queue length on the management API
#--------------------------------------------------------------------------
#
core::args::register \
	-proc_name core::api::stomp::check_queue_length \
	-desc {Check queue length on the management API} \
	-args [list \
		[list -arg -management_address -mand 1 -check STRING                -desc {Management queue address}] \
		[list -arg -reply_address      -mand 1 -check STRING                -desc {Reply address}] \
		[list -arg -destination        -mand 1 -check STRING                -desc {Queue or topic name}] \
		[list -arg -timeout            -mand 0 -check UINT   -default 10000 -desc {Request timeout}] \
		[list -arg -action             -mand 1 -check STRING                -desc {Action}] \
	] \
	-body {
		variable CFG

		set fn {core::api::stomp::check_queue_length}
		core::log::write INFO {$fn: destination=$ARGS(-destination)}

		if {!$CFG(init)} {
			error "Package not initialised" {} CHECK_QUEUE_LENGTH_ERROR
		}

		core::api::stomp::_start_timeout $ARGS(-timeout)
		core::log::write DEBUG {$fn: timeout started}

		if {!$CFG(connected)} {
			core::log::write DEBUG {$fn: not connected - connecting...}
			core::api::stomp::connect
			core::log::write DEBUG {$fn: connected}
		}


		#
		# Contruct and send the management frame
		#
		set frame [core::api::stomp::_construct_management_frame \
			$ARGS(-management_address) \
			$ARGS(-reply_address) \
			$ARGS(-destination) \
			$ARGS(-action)]

		core::log::write DEBUG {$fn: core::api::stomp::_construct_management_frame complete}

		core::api::stomp::_send_frame $CFG(stomp_socket) $frame 0

		core::log::write DEBUG {$fn: core::api::stomp::_send_frame : complete}

		#
		# Subscribe to the queue where the management message is going and wait
		# for a response.
		#
		set frame [core::api::stomp::_construct_subscribe_frame $ARGS(-reply_address)]

		core::log::write DEBUG {$fn :core::api::stomp::_construct_subscribe_frame complete}

		lassign [core::api::stomp::_send_frame $CFG(stomp_socket) $frame] command headers body

		core::log::write DEBUG {$fn: core::api::stomp::_send_frame : complete}
		core::log::write DEBUG {$fn: frame = $command, $headers, $body}

		#
		# Now unsubscribe -- no response expected.
		#
		set frame [core::api::stomp::_construct_unsubscribe_frame $ARGS(-reply_address)]
		core::log::write DEBUG {$fn: core::api::stomp::_construct_unsubscribe_frame complete}


		core::api::stomp::_send_frame $CFG(stomp_socket) $frame 0
		core::log::write DEBUG {$fn: core::api::stomp::_send_frame : complete}

		#
		# Parse the response
		#
		if { ![dict exists $headers _HQ_OperationSucceeded] } {
			core::log::write ERROR {$fn: _HQ_OperationSucceeded not defined}
			error "_HQ_OperationSucceeded not defined" {} CHECK_QUEUE_LENGTH_ERROR
		}

		if { [dict get $headers _HQ_OperationSucceeded] ne "true" } {
			core::log::write ERROR {$fn: _HQ_OperationSucceeded = [dict get $headers _HQ_OperationSucceeded]}
			error "_HQ_OperationSucceeded not true" {} CHECK_QUEUE_LENGTH_ERROR
		}

		if { ![regexp {^\[(\d+)\]$} $body {} queue_length] } {
			core::log::write ERROR {$fn: bad queue-length: $body}
			error "Invalid response body" {} CHECK_QUEUE_LENGTH_ERROR
		}

		core::log::write DEBUG {<== core::api::stomp::check_queue_length : SUCCESS}
		return $queue_length
	}



#
# Get the STOMP socket
#
proc core::api::stomp::get_stomp_socket {} {
	variable CFG

	if {![info exists CFG(stomp_socket)]} {
		error "No STOMP connecion available" {} GET_STOMP_SOCK_ERROR
	}

	return $CFG(stomp_socket)
}

#--------------------------------------------------------------------------
# Timeout
#--------------------------------------------------------------------------

proc core::api::stomp::_start_timeout {timeout} {
	variable absolute_timeout

	if {$timeout == -1} {
		set absolute_timeout -1
	} else {
		set absolute_timeout [expr {[clock clicks -milliseconds] + $timeout}]
	}
}

proc core::api::stomp::_remaining_time {} {
	variable absolute_timeout

	if {$absolute_timeout == -1} {
		return -1
	}

	return [expr {$absolute_timeout - [clock clicks -milliseconds]}]
}

proc core::api::stomp::_read_socket_timeout { sock } {
	variable CFG

	core::log::write ERROR {$fn: TIMEOUT}

	_close_socket $sock

	error "Timeout" {} READ_SOCKET_ERROR
}

#--------------------------------------------------------------------------
# Connect
#--------------------------------------------------------------------------

# Initialises a connection with the STOMP server by sending the CONNECT
# command.
#
#   host           - server hostname
#   port           - server port number
#   vhost          - virtual hostname
#   timeout        - connection timeout (milliseconds)
#   login          - login for a secured Stomp server. If not set then
#                    authentication is not used.
#   passcode       - passcode for a secured Stomp server
#
#   returns        - if connection is successful, returns the socket
#

proc core::api::stomp::_connect {host port vhost timeout {login {}} {passcode {}} {heart_beat {}}} {
  variable CFG

	set fn {core::api::stomp::_connect}
	core::log::write INFO {$fn: host=$host port=$port timeout=$timeout login=$login}

	# Create the socket to the Stomp message broker
	set sock [core::socket::client::connect -host $host \
		-port $port \
		-timeout $timeout]

	#
	# Set the socket configuration that will be used for the whole session.
	#
	# While STOMP requires that lines be terminated by line-feeds and that the
	# command and headers be encoded in UTF-8, it also allows message bodies to
	# be transferred in other encodings, so we configure the socket as binary
	# and deal with encoding conversions later.
	#
	fconfigure $sock -blocking 0 -translation binary
	core::log::write INFO {$fn: socket information: [fconfigure $sock]}

	# initialise the socket read handler
	core::api::stomp::_read_socket $sock $timeout

	set connect_frame [core::api::stomp::_construct_connect_frame $vhost \
		$login \
		$passcode \
		$heart_beat]

	core::api::stomp::_start_timeout $timeout

	set CFG(connected) 1

	lassign [core::api::stomp::_send_frame $sock $connect_frame] command

	# Parse the response
	if { $command eq "CONNECTED" } {
		return $sock
	} else {
		error "Returned command $command, expected CONNECTED" {} STOMP_CONNECTION_ERROR
	}
}


#--------------------------------------------------------------------------
# Send
#--------------------------------------------------------------------------

# Send a STOMP frame and parse the response
#
proc core::api::stomp::_send_stomp_frame {sock destination content_type msg_id headers request_data} {

	set fn {core::api::stomp::_send_stomp_frame}

	set frame [core::api::stomp::_construct_stomp_frame\
		$destination\
		$content_type\
		$msg_id\
		$headers\
		$request_data]

	core::log::write DEBUG {$fn: core::api::stomp::_construct_stomp_frame complete, frame=$frame}

	lassign [core::api::stomp::_send_frame $sock $frame] command headers body

	core::log::write DEBUG {$fn: core::api::stomp::_send_frame : complete}

	# Parse the response
	if { $command eq "RECEIPT" } {
		core::log::write INFO {$fn : SUCCESS}
		return [dict get $headers receipt-id]
	} else {
		core::log::write ERROR {$fn: bad response: $command $headers $body}
		error "Bad response" {} SEND_STOMP_FRAME_ERROR
	}
}

# Generic send/receive
#
proc core::api::stomp::_send_frame {sock frame {reply 1}} {
	core::log::write DEBUG {==> core::api::stomp::_send_frame sock=$sock}

	variable CFG
	variable INCOMING_FRAMES

	set fn {core::api::stomp::_send_frame}

	set req_start_time [OT_MicroTime]

	core::api::stomp::_log_stomp_frame INFO {STOMP REQ} $frame

	if {[catch {
		core::api::stomp::_write_socket $frame $sock [core::api::stomp::_remaining_time]
	} msg]} {
		_close_socket $sock
		error "$fn: $msg" $::errorInfo SEND_FRAME_ERROR
	}

	if {!$reply} {
		return
	}

	# no time out
	if {$CFG(connection_timeout) == -1} {
		set timeout -1
	} else {
		set timeout [core::api::stomp::_remaining_time]
	}

	if {[catch {
		set resp_frame  [_get_resp_frame]
	} msg]} {
		core::log::write ERROR {$fn: read failure: $msg}
		_close_socket $sock
		error $msg $::errorInfo SEND_FRAME_ERROR
	}

	set req_end_time [OT_MicroTime]

	core::api::stomp::_log_stomp_frame INFO {STOMP RESP} $resp_frame
	set req_time [_diff_time $req_start_time $req_end_time]
	core::api::stomp::_log_stomp_frame INFO {STOMP RESP} "Req Time: $req_time"

	return $resp_frame
}

proc core::api::stomp::_diff_time {time_a time_b} {
	return [format "%0.3f" [expr {$time_b - $time_a}]]
}

#--------------------------------------------------------------------------
# Logging
#--------------------------------------------------------------------------

proc core::api::stomp::_log_stomp_frame {level prefix frame} {
	foreach line [split $frame "\n"] {
		# Apply filters for anything that should never be logged
		regsub -all {passcode:[^\n]*} $line {passcode:*****} line

		core::log::write $level {$prefix: $line}
	}
}

#--------------------------------------------------------------------------
# Validate header
#--------------------------------------------------------------------------

# Checks if the header names and header values are compliant with the
# STOMP 1.0 specification
#
proc core::api::stomp::_valid_header {header_name header_value} {
	core::log::write DEBUG {==> core::api::stomp::_validate_header $header_name $header_value}

	# name checks
	if {[string first "\n" $header_name] > -1 || [string first ":" $header_name] > -1} {
		return 0
	}

	# value checks
	if {[string first "\n" $header_value] > -1} {
		return 0
	}

	return 1
}

#--------------------------------------------------------------------------
# Contruct STOMP frames
#--------------------------------------------------------------------------

# Construct a CONNECT frame
#
proc core::api::stomp::_construct_connect_frame {host login passcode heart_beat} {

	set fn {core::api::stomp::_construct_connect_frame}

	set mandatory_header_list [list\
		accept-version 1.0\
		host           $host]

	set optional_header_list [list]

	if {$login != {}} {
		core::log::write INFO {$fn: using authentication to connect to Stomp server: login=$login}
		lappend optional_header_list \
			login      $login\
			passcode   $passcode
	}

	if {$heart_beat != {}} {
		core::log::write INFO {$fn: using heart-beating to connect to Stomp server: heart-beat=$heart_beat}
		lappend optional_header_list \
			heart-beat $heart_beat
	}

	set frame_header_list [concat $mandatory_header_list $optional_header_list]

	return [core::api::stomp::_construct_frame CONNECT $frame_header_list {}]
}

# Construct a MANAGEMENT frame
#
proc core::api::stomp::_construct_management_frame {destination reply_to resource action} {
	core::log::write DEBUG {==> core::api::stomp::_construct_management_frame}

	set mandatory_header_list [list destination       $destination \
		reply-to          $reply_to\
		_HQ_ResourceName  $resource\
		_HQ_OperationName $action]

	return [core::api::stomp::_construct_frame SEND $mandatory_header_list {[null]}]
}

# Construct a SUBSCRIBE frame
#
proc core::api::stomp::_construct_subscribe_frame {destination {id -1} {ack_type ""}} {
	core::log::write DEBUG {==> core::api::stomp::_construct_subscribe_frame}

	set mandatory_header_list [list destination $destination]

	if {$id != -1} {
		lappend mandatory_header_list "id" $id
	}

	if {$ack_type != ""} {
		lappend mandatory_header_list "ack" $ack_type
	}

	return [core::api::stomp::_construct_frame SUBSCRIBE $mandatory_header_list]
}

# Construct an UNSUBSCRIBE frame
#
proc core::api::stomp::_construct_unsubscribe_frame {destination} {
	core::log::write DEBUG {==> core::api::stomp::_construct_unsubscribe_frame}

	set mandatory_header_list [list destination $destination]

	return [core::api::stomp::_construct_frame UNSUBSCRIBE \
		$mandatory_header_list \
		{[null]}]
}

# Construct a SEND frame
#
proc core::api::stomp::_construct_stomp_frame {destination content_type msg_id headers request_data} {

	set fn {core::api::stomp::_construct_stomp_frame}
	set mandatory_header_list [list\
		destination  $destination\
		receipt      $msg_id\
		content-type $content_type\
		persistent   {true}]

	set frame_header_list [concat $mandatory_header_list $headers]

	core::log::write DEBUG {$fn: full header list=$frame_header_list}

	return [core::api::stomp::_construct_frame SEND $frame_header_list $request_data]
}

proc core::api::stomp::_construct_frame {action header_list {data ""}} {

	set fn {core::api::stomp::_construct_frame}

	set frame_header {}
	foreach [list name value] $header_list {
		if {[core::api::stomp::_valid_header $name $value] == 1} {
			append frame_header "$name:$value\n"
		} else {
			core::log::write ERROR {$fn: invalid header given: name=$name value=$value: skipping}
		}
	}

	return "$action\n$frame_header\n$data\u0000"
}

#--------------------------------------------------------------------------
# Socket IO
#--------------------------------------------------------------------------

# This proc is written for circumstances where the socket is non-blocking
# and line buffered.
#
proc core::api::stomp::_write_socket {data sock timeout} {
	variable WRITE_STATUS_FLAG
	variable CFG

	set fn {core::api::stomp::_write_socket}

	core::log::write DEBUG {$fn: data=$data}
	if {$timeout != -1} {
		core::log::write DEBUG {setting timeout: $timeout}
		set timeout_event_id [after $timeout {set core::api::stomp::WRITE_STATUS_FLAG TIMEOUT}]
	}

	fileevent $sock writable {set core::api::stomp::WRITE_STATUS_FLAG WRITE}

	if {[set code [catch {

		vwait core::api::stomp::WRITE_STATUS_FLAG

		if {$WRITE_STATUS_FLAG == {WRITE}} {
			puts -nonewline $sock $data
		} elseif {$WRITE_STATUS_FLAG == {TIMEOUT}} {
			core::log::write ERROR {$fn: TIMEOUT}
			error "Timeout" {} WRITE_SOCKET_ERROR
		} else {
			core::log::write ERROR {$fn: unexpected error: invalid WRITE_STATUS_FLAG $WRITE_STATUS_FLAG}
			error "invalid WRITE_STATUS_FLAG $WRITE_STATUS_FLAG" {} WRITE_SOCKET_ERROR
		}
		if {$timeout != -1} {
			after cancel $timeout_event_id
		}

		core::log::write DEBUG {$fn: success: written [string bytelength $data] bytes}

	} msg]]} {

		if {$timeout != -1} {
			after cancel $timeout_event_id
		}

		fileevent $sock writable {}

		if {$code == 2} {
			return $msg
		} else {
			core::log::write ERROR {$fn: caught $msg}
			error $msg $::errorInfo WRITE_SOCKET_ERROR
		}
	}
}


#
# Simply appends data to INCOMING_BUFFER. Keep it simple.
#
proc core::api::stomp::_socket_readable {sock timeout} {
	variable CFG
	variable INCOMING_BUFFER

	set fn {core::api::stomp::_socket_readable}

	if {[eof $sock]} {
		core::log::write ERROR {socket $sock unexpectedly disconnected}
		_close_socket $sock
		error "socket EOF"
	}

	# reset timeout
	if {$timeout != -1} {
		after cancel $timeout_event_id
		set timeout_event_id [after $timeout {
			_read_socket_timeout
		}]
	}

	set read_data [read $sock]

	# simply append read data to INCOMING_BUFFER
	append INCOMING_BUFFER $read_data
	core::log::write DEBUG {$fn: read [string bytelength $read_data] bytes: $read_data}

	# ... and call the parser
	_parse_resp_frames
}

# Initialise the read handler for the given socket
# This proc is written for a non-blocking socket.
#
proc core::api::stomp::_read_socket {sock timeout} {
	variable INCOMING_BUFFER

	set fn {core::api::stomp::_read_socket}

	if {$timeout != -1} {
		set timeout_event_id [after $timeout {
			_read_socket_timeout
		}]
	}

	# when the socket is readable...
	fileevent $sock readable "core::api::stomp::_socket_readable $sock $timeout"

}

# close the socket, removing all fileevents
proc core::api::stomp::_close_socket { sock } {
	variable READ_FULL_FRAME_FLAG
	variable CFG
	set fn {core::api::stomp::_close_socket}

	fileevent $sock readable {}
	fileevent $sock writable {}
	core::log::write INFO {closing socket: $sock}
	core::socket::client::force_close -sock $sock
	set CFG(connected) 0

	# frame subscribers (listen / _get_resp_frame) must be woken up
	set READ_FULL_FRAME_FLAG 0
}

#
# Parse all the parsable stomp frame in the buffer and return it
#
proc core::api::stomp::_parse_resp_frames {} {
	set fn {core::api::stomp::_parse_resp_frames}

	variable CFG
	variable INCOMING_BUFFER
	variable INCOMING_FRAMES
	variable READ_FULL_FRAME_FLAG

	set command  {}
	set headers  [dict create]
	set body     {}
	set nframes  0
	set nbytes   0

	while {$CFG(connected)} {

		# try to locate the frame boundary
		set frame_boundary [string first \u0000 $INCOMING_BUFFER]
		if {$frame_boundary > -1} {
			set frame          [string range $INCOMING_BUFFER 0 $frame_boundary]
			set frameobj       [_parse_resp_frame $frame]
			core::log::write DEBUG {$fn: frameobj=$frameobj}
			if {$frameobj != ""} {
				incr nbytes [string bytelength $frame]
				incr nframes
				if {[info exists CFG(callback)] && $CFG(callback) != ""} {
					core::log::write DEBUG {calling $CFG(callback) ...}
					$CFG(callback) $frameobj
				} else {
					# legacy mode
					lappend INCOMING_FRAMES $frameobj
				}
				# truncate incoming buffer
				set INCOMING_BUFFER [string range $INCOMING_BUFFER [expr $frame_boundary + 1] end]
				core::log::write DEBUG {$fn: INCOMING_BUFFER is: $INCOMING_BUFFER}
			} else {
				break
			}
		} else {
			# If we've read 64k and haven't found a message, it's likely something went wrong.
			if {[string bytelength $INCOMING_BUFFER] > 65536} {
				core::log::write WARNING {STOMP frame too large - Discarding buffer}
				set INCOMING_BUFFER {}
			}
			break
		}
	}
	if {$nframes > 0} {
		# inform any vwait'ed procs for incoming frames
		set ::core::api::stomp::READ_FULL_FRAME_FLAG $nframes
		core::log::write DEBUG {$fn:success: read $nframes frames ($nbytes bytes), remaining buffer length: [string length $INCOMING_BUFFER]}
	} else {
		core::log::write DEBUG {$fn: no full frames in buffer}
	}
	return $INCOMING_FRAMES

}

proc core::api::stomp::_get_resp_frame { } {
	set fn {core::api::stomp::_get_resp_frame}
	variable INCOMING_FRAMES

	core::log::write DEBUG {$fn: [llength $INCOMING_FRAMES] parsed frames in queue}
	# Are there parsed messages waiting to be delivered to the app?
	if {[llength $INCOMING_FRAMES] == 0} {
		# No. Just wait for the parser to produce some
		vwait ::core::api::stomp::READ_FULL_FRAME_FLAG
	}
	# pop the queue
	set resp_frame      [lindex $INCOMING_FRAMES 0]
	set INCOMING_FRAMES [lrange $INCOMING_FRAMES 1 end]
	return $resp_frame
}

proc core::api::stomp::_parse_resp_frame { buffer } {
	set fn "core::api::stomp::_parse_resp_frame"

  # trim whitespace up to the first ASCII char
	set buffer [string trimleft $buffer]
	set cmdidx [string first \n $buffer]
	set bdyidx [string first \n\n $buffer]
	#
	if { $cmdidx == -1 || $bdyidx == -1 || $cmdidx == $bdyidx } {
		core::log::write ERROR  {$fn: malformed STOMP frame: $buffer}
		error "Malformed STOMP frame" {} READ_SOCKET_ERROR
	}

	set command    [string range $buffer 0         $cmdidx-1]
	set allheaders [string range $buffer $cmdidx+1 $bdyidx-1]
	set headers    [_parse_header_list $allheaders]
	set bodystart  [expr $bdyidx + 2]
	set body       {}

	# we now have enough information to try to extract the body
	set bodylength [core::api::stomp::_get_frame_payload_size $headers $buffer $bodystart]

	core::log::write DEBUG  {$fn: frame body length: $bodylength}

	if {$bodylength > 0} {

		set fmt "a${bodystart}a${bodylength}a*"
 		binary scan $buffer $fmt foo body rest

		if { [dict exists $headers content-type] } {
			#
			# If there is a content-type header, convert the body
			# appropriately.  Headers may be appear more than once,
			# but only the first is significant.
			#
			regexp  {^([^/]+)/([^;]+)(?:;charset=(.+))?} \
				[lindex [dict get $headers content-type] 0] \
				{} \
				type \
				subtype \
				charset

			if { $charset ne "" } {
				set body [encoding convertfrom $charset $body]
			} elseif { $type eq "text" } {
				set body [encoding convertfrom utf-8 $body]
			}
		}
	}
	core::log::write DEBUG  {$fn: decoded frame is: {$command $headers $body}}
	return [list $command $headers $body]
}

proc core::api::stomp::_parse_header_list { allheaders } {
	set fn "core::api::stomp::_parse_headers"
	set headers  [dict create]

	if {[string length $allheaders] > 0} {
		foreach line [split $allheaders "\n"] {

			core::log::write DEBUG {header line: $line}
			if { ![regexp {^([^:]+):(.+)$} $line {} name value] } {
				core::log::write ERROR {$fn: bad header}
				error "Bad header" {} READ_SOCKET_ERROR
			}

			dict lappend headers $name $value
		}
	}
	return $headers
}


# Get the length of the current stomp frame's payload in the head of
# buffer. If there is none, or there is part of the next one,
# return -1
proc core::api::stomp::_get_frame_payload_size { headers buffer {body_offset 0} } {
	set fn "core::api::stomp::_get_frame_payload_size"

	if {[string length $buffer] > 0} {
		if { [dict exists $headers content-length] } {
			set length [dict get $headers content-length]
			if {[expr $body_offset + $length] > [string length $buffer]} {
				core::log::write ERROR {$fn: partial STOMP frame, got [string length $buffer] bytes, but expecting $expected bytes}
				error "partial STOMP frame" {} READ_SOCKET_ERROR
			}
		} else {
			set length [expr [string first \u0000 $buffer] - $body_offset]
			if {$length < 0} {
				return -1
			}
		}
		return $length
	} else {
		# empty buffer
		error "$fn: incoming buffer is empty" {} READ_SOCKET_ERROR
	}
}
