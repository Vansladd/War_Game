# (C) 2011 OpenBet Technologies Ltd. All rights reserved.
#
# AMQP
# Library to format, send and receive messages to a AMQP server
#


package provide core::api::amqp $pkg_version

#
# Dependencies
#
package require core::socket::client 1.0
package require core::args           1.0
package require core::log            1.0
package require core::xml            1.0


core::args::register_ns \
	-namespace core::api::amqp \
	-version $pkgVersion \
	-dependent [list core::args core::log core::socket::client core::xml] \
	-desc {AMQP library} \
	-docs "xml/api/amqp.xml"

namespace eval core::api::amqp {
	variable CFG
	variable CONST
	variable CLASS_FIELDS
	variable METHOD_LIST
	variable METHOD_DATA
	variable VERSION

	array set CFG [list]
	array set CONST [list]
	array set CLASS_FIELDS [list]
	set METHOD_LIST [list]
	array set METHOD_DATA [list]
	array set VERSION [list]

	set CFG(init) 0
	set CFG(connected) 0
	set CFG(channel_created) 0
	set CFG(amqp_socket) {}
	set CFG(amqp_size) 0
	set CFG(server_properties) [dict create]

	#TODO: Add a comment to describe the significance of values of these constants
	set POSITION 15
	set LENGTH_CONST 7
	set BIT_STATE_LOW 0
	set BIT_STATE_HIGH 8
}

core::args::register \
	-proc_name core::api::amqp::init \
	-desc {Initialise amqp connection} \
	-args [list \
		[list -arg -remote_host        -mand 0 -check STRING -default_cfg AMQP_HOST         -default {}    -desc {Remote Host}] \
		[list -arg -port               -mand 0 -check UINT   -default_cfg AMQP_PORT         -default 0     -desc {Remote Port}] \
		[list -arg -virtual_host       -mand 0 -check STRING -default_cfg AMQP_VIRTUALHOST  -default {/}   -desc {Virtual Host}] \
		[list -arg -secure             -mand 0 -check BOOL   -default_cfg AMQP_SECURE       -default 0     -desc {Use SSL/TLS}] \
		[list -arg -username           -mand 0 -check STRING -default_cfg AMQP_LOGIN        -default guest -desc {Host username}] \
		[list -arg -password           -mand 0 -check STRING -default_cfg AMQP_PASSCODE     -default guest -desc {Host password}] \
		[list -arg -connection_timeout -mand 0 -check INT    -default_cfg AMQP_CONN_TIMEOUT -default 10000 -desc {Connection timeout. -1 for no timeout.}] \
		[list -arg -frame_size         -mand 0 -check INT    -default_cfg AMQP_FRAME_SIZE   -default 0     -desc {Maximum AMQP frame size. Will fragment above this value}] \
		[list -arg -heartbeat          -mand 0 -check INT    -default_cfg AMQP_HEARTBEAT    -default 0     -desc {Maximum heartbeat timeout in seconds}] \
		[list -arg -locale             -mand 0 -check STRING -default_cfg AMQP_LOCALE       -default {}    -desc {Locale (space seperated list)}] \
		[list -arg -force_init         -mand 0 -check BOOL                                  -default 0     -desc {Force initialisation}] \
		[list -arg -xml_file           -mand 1 -check STRING                                               -desc {XML filename}]
	] \
	-body {
		variable CFG

		# already initialised?
		if {$CFG(init) && !$ARGS(-force_init)} {
			return
		}

		# We might be forcing a re-initialisation, disconnect if already connected
		if {$CFG(connected)} {
			core::api::amqp::_disconnect
		}

		# initalise dependencies
		core::log::init
		core::xml::init

		set CFG(remote_host)        $ARGS(-remote_host)
		set CFG(port)               $ARGS(-port)
		set CFG(vhost)              $ARGS(-virtual_host)
		set CFG(secure)             $ARGS(-secure)
		set CFG(username)           $ARGS(-username)
		set CFG(password)           $ARGS(-password)
		set CFG(connection_timeout) $ARGS(-connection_timeout)
		set CFG(frame_size)         $ARGS(-frame_size)
		set CFG(heartbeat)          $ARGS(-heartbeat)
		set CFG(locale)             $ARGS(-locale)
		set CFG(xml_file)           $ARGS(-xml_file)

		set CFG(init)      1
		set CFG(connected) 0
		set CFG(channel_created) 0

		core::log::write INFO {AMQP Initialised}

		core::api::amqp::_parse_xml $CFG(xml_file)
	}

# This proc is to initalise the connection, which will be kept open persistently unless
# it stops working and a forced close is required
core::args::register \
	-proc_name core::api::amqp::connect \
	-desc      {Connect to a AMQP host} \
	-body {
		variable CFG

		set fn {core::api::amqp::connect}

		if {$CFG(connected)} {
			core::log::write INFO {$fn: already connected, reinitalising connection}
			core::api::amqp::_disconnect
		}

		core::api::amqp::_connect \
			$CFG(remote_host) \
			$CFG(port) \
			$CFG(secure) \
			$CFG(connection_timeout) \
			$CFG(locale) \
			$CFG(vhost) \
			$CFG(username) \
			$CFG(password) \
			$CFG(frame_size) \
			$CFG(heartbeat)
	}



core::args::register \
	-proc_name core::api::amqp::disconnect \
	-desc      {Disconnect from AMQP host} \
	-body {
		variable CFG

		set fn {core::api::amqp::disconnect}

		if {!$CFG(connected)} {
			core::log::write INFO {$fn: already disconnected}
			return
		}

		core::api::amqp::_disconnect
	}



core::args::register \
	-proc_name core::api::amqp::send_method \
	-desc {Send a method to AMQP server} \
	-args [list \
		[list -arg -class              -mand 1 -check STRING             -desc {Class name}] \
		[list -arg -method             -mand 1 -check STRING             -desc {Method name}] \
		[list -arg -arguments          -mand 0 -check ANY                -desc {Dict of method arguments}] \
		[list -arg -properties         -mand 0 -check ANY                -desc {Dict of header properties}] \
		[list -arg -body               -mand 0 -check ANY                -desc {Method body}] \
		[list -arg -response           -mand 0 -check BOOL   -default 0  -desc {Expect a method response}] \
		[list -arg -response_check     -mand 0 -check STRING -default {} -desc {Expect a specific method response}] \
	] \
	-body {
		variable CFG

		set fn {core::api::amqp::send_method}

		core::log::write INFO {$fn: class=$ARGS(-class)}
		core::log::write INFO {$fn: method=$ARGS(-method)}
		core::log::write INFO {$fn: arguments=$ARGS(-arguments)}
		core::log::write INFO {$fn: properties=$ARGS(-properties)}
		core::log::write INFO {$fn: body=$ARGS(-body)}
		core::log::write INFO {$fn: response=$ARGS(-response)}
		core::log::write INFO {$fn: response_check=$ARGS(-response_check)}

		if {!$CFG(init)} {
			core::log::write ERROR {$fn: Package not initialised}
			error "Package not initialised" {} SEND_ERROR
		}

		if {!$CFG(connected)} {
			core::log::write DEBUG {$fn: not connected - connecting...}
			core::api::amqp::connect
			core::log::write DEBUG {$fn: connected}
		}

		if {$ARGS(-class) == {connection}} {
			set channel 0
		} else {
			set channel 1
		}

		if {$ARGS(-response_check) != {}} {
			set ARGS(-response) 1
		}

		set ret [core::api::amqp::_get_method_data "$ARGS(-class).$ARGS(-method)"]
		lassign $ret class_id method_id content fields

		set frame [core::api::amqp::_construct_method_frame $channel $class_id $method_id $fields $ARGS(-arguments)]
		core::api::amqp::_send_frame $CFG(amqp_socket) $frame

		if {$content} {
			set frames [core::api::amqp::_construct_content_frames $channel $class_id $ARGS(-body) $ARGS(-properties)]

			foreach frame $frames {
				core::api::amqp::_send_frame $CFG(amqp_socket) $frame
			}
		}

		if {$ARGS(-response)} {
			set response_check $ARGS(-response_check)

			set ret [core::api::amqp::_receive_method_frame $CFG(amqp_socket)]
			lassign $ret full_name response_arguments response_properties response_body

			if {$full_name == {connection.close}} {
				if {$response_check != $full_name} {
					set reply_text [dict get $response_arguments {reply-text}]
					set class_id  [dict get $response_arguments {class-id}]
					set method_id  [dict get $response_arguments {method-id}]

					if {$class_id == 0} {
						set full_name {}
					} else {
						set full_name [core::api::amqp::_find_method_data $class_id $method_id]
					}

					core::log::write ERROR {$fn: Error reply: $full_name $reply_text}

					error "ERROR: $full_name $reply_text" {} REPLY_ERROR
				}
			}

			if {$response_check != {}} {
				if {$full_name != $response_check} {
					core::log::write ERROR {$fn: Incorrect response type: $full_name (expected $response_check)}
					error {Incorrect response type} {} INCORRECT_RESPONSE
				}

				return $response_arguments
			}

			return [list $full_name $response_arguments]
		}
	}

	core::args::register \
	-proc_name core::api::amqp::publish \
	-desc {Publish message to amqp connection} \
	-args [list \
		[list -arg -exchange       -mand 1 -check STRING                             -desc {Exchange}] \
		[list -arg -routing_key    -mand 1 -check STRING                             -desc {Routing key}] \
		[list -arg -content_type   -mand 0 -check STRING -default {application/json} -desc {Content type}] \
		[list -arg -body           -mand 1 -check STRING                             -desc {Content}] \
		[list -arg -durable        -mand 0 -check BOOL   -default 0                  -desc {Durable message}] \
		[list -arg -transaction    -mand 0 -check BOOL   -default 0                  -desc {Wrap in a transaction}] \
		[list -arg -reply_to       -mand 0 -check STRING                             -desc {Reply to}] \
		[list -arg -expiry         -mand 0 -check INT                                -desc {Expiry time (seconds since epoch)}] \
		[list -arg -correlation_id -mand 0 -check STRING                             -desc {Correlation ID}] \
		[list -arg -properties     -mand 0 -check ANY                                -desc {Dict of extra properties}] \
	] \
	-body {
		variable CFG

		set fn {core::api::amqp::publish}

		core::log::write INFO {$fn: exchange=$ARGS(-exchange)}
		core::log::write INFO {$fn: routing_key=$ARGS(-routing_key)}
		core::log::write INFO {$fn: content_type=$ARGS(-content_type)}
		core::log::write INFO {$fn: body=$ARGS(-body)}
		core::log::write INFO {$fn: durable=$ARGS(-durable)}
		core::log::write INFO {$fn: transaction=$ARGS(-transaction)}
		core::log::write INFO {$fn: reply_to=$ARGS(-reply_to)}
		core::log::write INFO {$fn: expiry=$ARGS(-expiry)}
		core::log::write INFO {$fn: correlation_id=$ARGS(-correlation_id)}
		core::log::write INFO {$fn: properties=$ARGS(-properties)}

		if {$ARGS(-transaction)} {
			core::api::amqp::send_method \
				-class          {tx} \
				-method         {select} \
				-response_check {tx.select-ok}
		}

		if {$ARGS(-durable)} {
			set delivery_mode 1
		} else {
			set delivery_mode 0
		}

		set arguments [dict create]

		dict set arguments {exchange} $ARGS(-exchange)
		dict set arguments {routing-key} $ARGS(-routing_key)

		set properties [dict create]

		if {$ARGS(-reply_to) != {}} {
			dict set properties {reply-to} $ARGS(-reply_to)
		}
		if {$ARGS(-expiry) != {}} {
			dict set properties {expiration} $ARGS(-expiry)
		}
		if {$ARGS(-correlation_id) != {}} {
			dict set properties {correlation-id} $ARGS(-correlation_id)
		}

		dict set properties {timestamp} [clock seconds]
		dict set properties {app-id} [format "%03d:%04d" [asGetId] [reqGetId]]
		dict set properties {user-id} [dict get $CFG(server_properties) {username}]
		dict set properties {content-type} $ARGS(-content_type)
		dict set properties {delivery-mode} $delivery_mode

		if {$ARGS(-properties) != {}} {
			dict for {name value} $ARGS(-properties) {
				dict set properties $name $value
			}
		}

		core::api::amqp::send_method \
			-class      {basic} \
			-method     {publish} \
			-arguments  $arguments \
			-properties $properties \
 			-body       $ARGS(-body)

		if {$ARGS(-transaction)} {
			core::api::amqp::send_method \
				-class          {tx} \
				-method         {commit} \
				-response_check {tx.commit-ok}
		}
	}

proc core::api::amqp::_receive_method_frame {sock} {
	set ret [core::api::amqp::_receive_typed_frame $sock {method}]
	lassign $ret full_name content arguments

	set properties [dict create]
	set body {}

	if {$content} {
		set ret [core::api::amqp::_receive_typed_frame $sock {header}]
		lassign $ret class_id size properties

		while {$size > [string length $body]} {
			set data [core::api::amqp::_receive_typed_frame $sock {body}]

			append body [lindex $data 0]
		}
	}

	return [list $full_name $arguments $properties $body]
}

proc core::api::amqp::_receive_typed_frame {sock frame_type} {
	set frame [core::api::amqp::_receive_frame $sock]

	set ret [core::api::amqp::_process_frame $frame]
	set data [lassign $ret type]

	if {$type == {heartbeat}} {
		core::log::write DEBUG {$fn Received heartbeat}
		return [core::api::amqp::_receive_typed_frame $sock $frame_type]
	}

	if {$type != $frame_type} {
		core::log::write ERROR {$fn: Incorrect frame type: $type (expected $frame_type)}
		error {Incorrect frame type} {} INCORRECT_FRAME_TYPE
	}

	return $data
}

proc core::api::amqp::_get_method_data {full_name} {
	variable METHOD_DATA

	set fn {core::api::amqp::_get_method_data}

	core::log::write DEBUG {$fn: full_name=$full_name}

	set class_id $METHOD_DATA($full_name,class)
	set method_id $METHOD_DATA($full_name,method)
	set content $METHOD_DATA($full_name,content)
	set fields $METHOD_DATA($full_name,fields)

	return [list $class_id $method_id $content $fields]
}



core::args::register \
	-proc_name core::api::amqp::receive_method \
	-desc {Receive an AMQP method} \
	-body {
		variable CFG

		set fn {core::api::amqp::read}

		if {!$CFG(init)} {
			core::log::write ERROR {$fn: Package not initialised}
			error "Package not initialised" {} PACKAGE_UNINITIALIZED
		}

		if {!$CFG(connected)} {
			core::log::write ERROR {$fn: Not connected}
			error "Not connected" {} NOT_CONNECTED
		}

		return [core::api::amqp::_receive_method_frame $CFG(amqp_socket)]
	}




core::args::register \
	-proc_name core::api::amqp::server_properties \
	-desc {Get server properties from connection} \
	-body {
		variable CFG

		set fn {core::api::amqp::server_properties}

		core::log::write INFO {$fn: $CFG(server_properties)}

		return $CFG(server_properties)
	}





proc core::api::amqp::_parse_xml {filename} {
	variable CONST
	variable CLASS_FIELDS
	variable METHOD_LIST
	variable METHOD_DATA
	variable VERSION

	set fn {core::api::amqp::_parse_xml}
	core::log::write INFO {$fn: filename=$filename}

	set ret [core::xml::parse -strict 0 -filename $filename]

	lassign $ret error doc

	if {$error != {OK}} {
		core::xml::highlight_parse_error \
			-xml $filename \
			-err $error

		core::log::write ERROR {$fn: Couldn't parse XML file}
		error {Couldn't parse XML file:$filename Error:$error} {} XML_PARSE_ERROR
	}

	set VERSION(major) [core::xml::extract_data -node $doc -xpath "amqp/@major"]
	set VERSION(minor) [core::xml::extract_data -node $doc -xpath "amqp/@minor"]
	set VERSION(revision) [core::xml::extract_data -node $doc -xpath "amqp/@revision"]
	set VERSION(port) [core::xml::extract_data -node $doc -xpath "amqp/@port"]

	foreach c_node [core::xml::extract_data -node $doc -return_node 1 -xpath "amqp/constant"] {
		set name [core::xml::extract_data -node $c_node -xpath "@name"]
		set value [core::xml::extract_data -node $c_node -xpath "@value"]

		set CONST($name) $value
	}

	foreach d_node [core::xml::extract_data -node $doc -return_node 1 -xpath "amqp/domain"] {
		set name [core::xml::extract_data -node $d_node -xpath "@name"]
		set type [core::xml::extract_data -node $d_node -xpath "@type"]

		set DOMAIN($name) $type
	}

	foreach c_node [core::xml::extract_data -node $doc -return_node 1 -xpath "amqp/class"] {
		set class [core::xml::extract_data -node $c_node -xpath "@name"]
		set class_id [core::xml::extract_data -node $c_node -xpath "@index"]

		set CLASS_FIELDS($class_id) [list]

		foreach f_node [core::xml::extract_data -node $c_node -return_node 1 -xpath "field"] {
			set name [core::xml::extract_data -node $f_node -xpath "@name"]
			set domain [core::xml::extract_data -node $f_node -xpath "@domain"]
			set type [core::xml::extract_data -node $f_node -xpath "@type"]

			if {$domain != {}} {
				set type $DOMAIN($domain)
			}

			lappend CLASS_FIELDS($class_id) $name $type
		}

		foreach m_node [core::xml::extract_data -node $c_node -return_node 1 -xpath "method"] {
			set method [core::xml::extract_data -node $m_node -xpath "@name"]
			set method_id [core::xml::extract_data -node $m_node -xpath "@index"]
			set sync [core::xml::extract_data -node $m_node -xpath "@synchronous"]
			set content [core::xml::extract_data -node $m_node -xpath "@content"]
			set response [core::xml::extract_data -node $m_node -xpath "response/@name"]

			if {$content == {}} {
				set content 0
			}

			set full_name "$class.$method"

			lappend METHOD_LIST $full_name

			set METHOD_DATA($full_name,class) $class_id
			set METHOD_DATA($full_name,method) $method_id
			set METHOD_DATA($full_name,sync) $sync
			set METHOD_DATA($full_name,content) $content
			set METHOD_DATA($full_name,response) $response
			set METHOD_DATA($full_name,fields) [list]

			foreach f_node [core::xml::extract_data -node $m_node -return_node 1 -xpath "field"] {
				set name [core::xml::extract_data -node $f_node -xpath "@name"]
				set domain [core::xml::extract_data -node $f_node -xpath "@domain"]
				set type [core::xml::extract_data -node $f_node -xpath "@type"]
				set reserved [core::xml::extract_data -node $f_node -xpath "@reserved"]

				if {$domain != {}} {
					set type $DOMAIN($domain)
				}

				if {$reserved == {}} {
					set reserved 0
				}

				lappend METHOD_DATA($full_name,fields) $name [list $type $reserved]
			}
		}
	}
}

proc core::api::amqp::_construct_connect_frame {} {
	variable VERSION

	set fn {core::api::amqp::_construct_connect_frame}

	# "AMQP" + NULL
	set output [list 65 77 81 80 0]

	set output [core::api::amqp::_encode_octet $VERSION(major) $output]
	set output [core::api::amqp::_encode_octet $VERSION(minor) $output]
	set output [core::api::amqp::_encode_octet $VERSION(revision) $output]

	return $output
}

proc core::api::amqp::_construct_frame {type channel payload} {
	variable CONST

	set fn {core::api::amqp::_construct_frame}

	set output [core::api::amqp::_encode_octet $type]
	set output [core::api::amqp::_encode_short $channel $output]
	set output [core::api::amqp::_encode_long [llength $payload] $output]
	lappend output {*}$payload
	lappend output $CONST(frame-end)

	return $output
}

proc core::api::amqp::_construct_method_frame {channel class_id method_id fields arguments} {
	variable CONST

	set fn {core::api::amqp::_construct_method_frame}

	set payload [core::api::amqp::_encode_short $class_id]
	set payload [core::api::amqp::_encode_short $method_id $payload]

	set bit_state 0

	foreach {name field} $fields {
		lassign $field type reserved

		if {$type == "longstr" || $type == "shortstr" || $type == "table"} {
			set value {}
		} else {
			set value 0
		}

		if {!$reserved && [dict exists $arguments $name]} {
			set value [dict get $arguments $name]
		}

		set ret [core::api::amqp::_encode_field $bit_state $type $value $payload]
		lassign $ret bit_state payload
	}

	return [core::api::amqp::_construct_frame $CONST(frame-method) $channel $payload]
}

proc core::api::amqp::_encode_field {bit_state type value payload} {
	set fn {core::api::amqp::_encode_field}

	if {$type != "bit"} {
		set bit_state 0
	}

	switch -exact -- $type {
		"bit" {
			set ret [core::api::amqp::_encode_bit $bit_state $value $payload]
			lassign $ret bit_state payload
		}
		"long" {
			set payload [core::api::amqp::_encode_long $value $payload]
		}
		"longlong" {
			set payload [core::api::amqp::_encode_longlong $value $payload]
		}
		"longstr" {
			set payload [core::api::amqp::_encode_longstr $value $payload]
		}
		"octet" {
			set payload [core::api::amqp::_encode_octet $value $payload]
		}
		"short" {
			set payload [core::api::amqp::_encode_short $value $payload]
		}
		"shortstr" {
			set payload [core::api::amqp::_encode_shortstr $value $payload]
		}
		"table" {
			set payload [core::api::amqp::_encode_table $value $payload]
		}
		"timestamp" {
			set payload [core::api::amqp::_encode_longlong $value $payload]
		}
		default {
			core::log::write ERROR {$fn: Unknown type: $type}
			error "Unknown type: $type" {} UNKNOWN_TYPE
		}
	}

	return [list $bit_state $payload]
}

proc core::api::amqp::_construct_content_frames {channel class_id body properties} {
	variable CFG

	set fn {core::api::amqp::_construct_content_frames}

	if {$channel == 0} {
		core::log::write ERROR {$fn: Channel cannot be zero for content frames}
		error {Channel cannot be zero for content frames} {} INCORRECT_CHANNEL
	}

	set size [string length $body]

	set frames [list]

	lappend frames [core::api::amqp::_construct_header_frame $channel $class_id $size $properties]

	set frame_size $CFG(amqp_size)
	incr frame_size -8

	while {[string length $body] > 0} {
		set data [string range $body 0 $frame_size]
		set body [string range $body $frame_size+1 end]

		lappend frames [core::api::amqp::_construct_body_frame $channel $data]
	}

	return $frames
}

proc core::api::amqp::_construct_header_frame {channel class_id size properties} {
	variable CONST
	variable CLASS_FIELDS

	set fn {core::api::amqp::_construct_header_frame}

	variable POSITION

	set payload [core::api::amqp::_encode_short $class_id]
	set payload [core::api::amqp::_encode_short 0 $payload]
	set payload [core::api::amqp::_encode_longlong $size $payload]

	set flags [list]
	set data [list]
	set bit_state 0

	set fields $CLASS_FIELDS($class_id)

	foreach {name type} $fields {
		if {[dict exists $properties $name]} {
			lappend flags 1

			set value [dict get $properties $name]

			set ret [core::api::amqp::_encode_field $bit_state $type $value $data]
			lassign $ret bit_state data
		} else {
			lappend flags 0
		}
	}

	set pos $POSITION
	set value 0

	for {set i 0} {$i < [llength $flags]} {incr i} {
		set bit [lindex $flags $i]
		set value [expr {$value | ($bit << $pos)}]

		incr pos -1

		if {$pos == 0} {
			core::log::write ERROR {$fn: > 15 header properties not implemented}
			error {> 15 header properties not implemented} {} INCORRECT_NO_OF_PROPERTIES

			if {$i != [llength $flags]} {
				set payload [core::api::amqp::_encode_short $value $payload]

				set pos $POSITION
				set value 0
			}
		}
	}

	set payload [core::api::amqp::_encode_short $value $payload]
	lappend payload {*}$data

	return [core::api::amqp::_construct_frame $CONST(frame-header) $channel $payload]
}

proc core::api::amqp::_construct_body_frame {channel body} {
	variable CONST

	set fn {core::api::amqp::_construct_body_frame}

	set payload [list]

	set size [string length $body]

	for {set i 0} {$i < $size} {incr i} {
		lappend payload [scan [string index $body $i] %c]
	}

	return [core::api::amqp::_construct_frame $CONST(frame-body) $channel $payload]
}

proc core::api::amqp::_find_method_data {class_id method_id} {
	variable METHOD_LIST
	variable METHOD_DATA

	set fn {core::api::amqp::_find_method_data}

	set full_name {}

	foreach key $METHOD_LIST {
		if {$METHOD_DATA($key,class) == $class_id && $METHOD_DATA($key,method) == $method_id} {
			set full_name $key

			break
		}
	}

	if {$full_name == {}} {
		core::log::write ERROR {$fn: Return type not found}
		error {Return type not found} {} UNKNOWN_RETURN_TYPE
	}

	return $full_name
}

proc core::api::amqp::_deconstruct_method_frame {payload} {
	set fn {core::api::amqp::_deconstruct_method_frame}

	set ret [core::api::amqp::_decode_short $payload 1]
	lassign $ret class_id payload

	set ret [core::api::amqp::_decode_short $payload 1]
	lassign $ret method_id payload

	set full_name [core::api::amqp::_find_method_data $class_id $method_id]

	set ret [core::api::amqp::_get_method_data $full_name]
	lassign $ret class_id method_id content fields

	set arguments [dict create]

	foreach {name field} $fields {
		lassign $field type reserved

		set ret [core::api::amqp::_decode_field $type $payload]
		lassign $ret value payload

		dict set arguments $name $value
	}

	return [list {method} $full_name $content $arguments]
}

proc core::api::amqp::_deconstruct_header_frame {payload} {
	variable CLASS_FIELDS
	variable POSITION

	set fn {core::api::amqp::_deconstruct_header_frame}

	set ret [core::api::amqp::_decode_short $payload 1]
	lassign $ret class_id payload

	set ret [core::api::amqp::_decode_short $payload 1]
	lassign $ret weight payload

	set ret [core::api::amqp::_decode_longlong $payload 1]
	lassign $ret size payload

	set flags [list]
	set loop 1

	while {$loop} {
		set ret [core::api::amqp::_decode_short $payload 1]
		lassign $ret flag payload

		if {[expr {$flag & 0x01}] == 0} {
			set loop 0
		}

		for {set i $POSITION} {$i > 0} {incr i -1} {
			lappend flags [expr {($flag >> $i) & 0x01}]
		}
	}

	set fields $CLASS_FIELDS($class_id)

	set pos 0

	set properties [dict create]

	foreach {name type} $fields {
		if {[lindex $flags $pos] == 0} {
			incr pos 1

			continue
		}

		incr pos 1

		set ret [core::api::amqp::_decode_field $type $payload]
		lassign $ret value payload

		dict set properties $name $value
		dict set properties "_$name" $type
	}

	return [list {header} $class_id $size $properties]
}

proc core::api::amqp::_deconstruct_body_frame {payload} {
	set fn {core::api::amqp::_deconstruct_body_frame}

	set body {}

	for {set i 0} {$i < [llength $payload]} {incr i} {
		append body [format %c [lindex $payload $i]]
	}

	return [list {body} $body]
}

proc core::api::amqp::_decode_field {type payload} {
	set fn {core::api::amqp::_decode_field}

	if {$type == "bit"} {
		# Note: This doesn't handle adjoining bit fields correctly
		set ret [core::api::amqp::_decode_octet $payload 1]
	} elseif {$type == "long"} {
		set ret [core::api::amqp::_decode_long $payload 1]
	} elseif {$type == "longlong"} {
		set ret [core::api::amqp::_decode_longlong $payload 1]
	} elseif {$type == "longstr"} {
		set ret [core::api::amqp::_decode_longstr $payload 1]
	} elseif {$type == "octet"} {
		set ret [core::api::amqp::_decode_octet $payload 1]
	} elseif {$type == "short"} {
		set ret [core::api::amqp::_decode_short $payload 1]
	} elseif {$type == "shortstr"} {
		set ret [core::api::amqp::_decode_shortstr $payload 1]
	} elseif {$type == "table"} {
		set ret [core::api::amqp::_decode_table $payload 1]
	} elseif {$type == "timestamp"} {
		set ret [core::api::amqp::_decode_longlong $payload 1]
	} else {
		core::log::write ERROR {$fn: Unknown type: $type}
		error "Unknown type $type" {} UNKNOWN_TYPE
	}

	return $ret
}

proc core::api::amqp::_deconstruct_frame {frame} {
	variable CONST

	set ret [core::api::amqp::_decode_octet $frame 1]
	lassign $ret type frame

	set ret [core::api::amqp::_decode_short $frame 1]
	lassign $ret channel frame

	set ret [core::api::amqp::_decode_long $frame 1]
	lassign $ret size frame

	set payload {}

	if {$size > 0} {
		set payload [lrange $frame 0 $size]
	}

	if {[lindex $frame end] != $CONST(frame-end)} {
		core::log::write ERROR {$fn: Missing frame end}
		error {Missing frame end} {} MISSING_FRAME_END
	}

	return [list $type $channel [lrange $payload 0 end-1]]
}


proc core::api::amqp::_connect {host port secure timeout locale vhost username password frame_size heartbeat} {
	variable CFG
	variable CONST
	variable VERSION

	set fn {core::api::amqp::_connect}

	core::log::write INFO {$fn: host=$host}
	core::log::write INFO {$fn: port=$port}
	core::log::write INFO {$fn: secure=$secure}
	core::log::write INFO {$fn: timeout=$timeout}
	core::log::write INFO {$fn: locale=$locale}
	core::log::write INFO {$fn: vhost=$vhost}
	core::log::write INFO {$fn: username=$username frame_size=$frame_size heartbeat=$heartbeat}
	core::log::write INFO {$fn: frame_size=$frame_size heartbeat=$heartbeat}
	core::log::write INFO {$fn: heartbeat=$heartbeat}

	if {$secure} {
		core::log::write ERROR {$fn: SSL not implemented}
		error {SSL not implemented} {} SSL_NOT_IMPLEMENTED
	}

	if {$port == 0} {
		set port VERSION(port)
	}

	set CFG(amqp_socket) [core::socket::client::connect -host $host \
		-port $port \
		-timeout $timeout]

	set CFG(connected) 1

	fconfigure $CFG(amqp_socket) -blocking 1 -translation binary
	core::log::write DEBUG {$fn: socket information: [fconfigure $CFG(amqp_socket)]}

	set connect_frame [core::api::amqp::_construct_connect_frame]

	core::api::amqp::_send_frame $CFG(amqp_socket) $connect_frame

	set ret [core::api::amqp::_receive_method_frame $CFG(amqp_socket)]
	lassign $ret full_name response_arguments response_properties response_body

	if {$full_name != {connection.start}} {
		core::log::write ERROR {$fn: Incorrect response type: $full_name (expected connection.start)}
		error "Incorrect response type: $full_name (expected connection.start)" {} INCORRECT_RESPONSE_TYPE
	}

	set major [dict get $response_arguments {version-major}]
	set minor [dict get $response_arguments {version-minor}]

	if {$major != 0 || $minor != 9} {
		core::log::write ERROR {$fn: Server doesn't support correct version: $major.$minor (expected 0.9)}
		error "Server doesn't support correct version: $major.$minor (expected 0.9)" {} UNSUPPORTED_VERSION
	}

	set CFG(server_properties) [dict get $response_arguments {server-properties}]
	set server_mechanisms [dict get $response_arguments {mechanisms}]
	set server_locales [dict get $response_arguments {locales}]

	dict set CFG(server_properties) {username} $username

	set arguments [dict create]

	dict set arguments {client-properties} [dict create {product} {OpenBet core::api::amqp}]
	dict set arguments {mechanism} [core::api::amqp::_choose_compatible $server_mechanisms {PLAIN}]
	dict set arguments {response} [core::api::amqp::_generate_sasl $username $password]
	dict set arguments {locale} [core::api::amqp::_choose_compatible $server_locales $locale]

	set response_arguments [core::api::amqp::send_method \
		-class          {connection} \
		-method         {start-ok} \
		-arguments      $arguments \
		-response_check {connection.tune} \
	]

	dict for {name value} $response_arguments {
		dict set CFG(server_properties) $name $value
	}

	set frame_max [dict get $response_arguments {frame-max}]
	set server_heartbeat [dict get $response_arguments {heartbeat}]

	if {$frame_size == 0 || $frame_size > $frame_max} {
		set frame_size $frame_max
	}

	if {$frame_size < $CONST(frame-min-size)} {
		set frame_size $CONST(frame-min-size)
	}

	if {$heartbeat == 0 || $heartbeat > $server_heartbeat} {
		set heartbeat $server_heartbeat
	}

	dict set CFG(server_properties) {frame-size} $frame_size
	dict set CFG(server_properties) {heartbeat-time} $heartbeat

	set arguments $response_arguments
	dict set arguments {frame-max} $frame_size
	dict set arguments {heartbeat} $heartbeat

	set CFG(amqp_size) $frame_size

	core::api::amqp::send_method \
		-class     {connection} \
		-method    {tune-ok} \
		-arguments $arguments

	core::api::amqp::send_method \
		-class          {connection} \
		-method         {open} \
		-arguments      [dict create {virtual-host} $vhost] \
		-response_check {connection.open-ok}

	core::api::amqp::send_method \
		-class          {channel} \
		-method         {open} \
		-response_check {channel.open-ok}

	set CFG(channel_created) 1
}


proc core::api::amqp::_generate_sasl {username password} {
	set sasl {}

	append sasl [format %c 0x00]
	append sasl $username
	append sasl [format %c 0x00]
	append sasl $password

	return $sasl
}

proc core::api::amqp::_choose_compatible {server client} {
	if {$client == {}} {
		set client $server
	}

	foreach choice $client {
		foreach check $server {
			if {$check == $choice} {
				return $choice
			}
		}
	}

	core::log::write ERROR {$fn: No compatible options (client=$client, server=$server)}
	error "No compatible options (client=$client, server=$server)" {} INCOMPATIBLE_OPTIONS
}

proc core::api::amqp::_disconnect {} {
	variable CFG

	if {!$CFG(connected)} {
		return
	}

	set arguments [dict create]

	dict set arguments {reply-code} 200
	dict set arguments {reply-text} {Normal shutdown}
	dict set arguments {class-id} 0
	dict set arguments {method-id} 0

	if {$CFG(channel_created)} {
		core::api::amqp::send_method \
			-class          {channel} \
			-method         {close} \
			-arguments      $arguments \
			-response_check {channel.close-ok}

		set CFG(channel_created) 0
	}

	core::api::amqp::send_method \
		-class          {connection} \
		-method         {close} \
		-arguments      $arguments \
		-response_check {connection.close-ok}

	core::socket::client::force_close -sock $CFG(amqp_socket)
	set CFG(connected) 0
	set CFG(server_properties) [dict create]
}


proc core::api::amqp::_process_frame {frame} {
	variable CONST

	set fn {core::api::amqp::_process_frame}

	set ret [core::api::amqp::_deconstruct_frame $frame]

	lassign $ret type channel payload

	switch -- $type {
		$CONST(frame-method) {
			return [core::api::amqp::_deconstruct_method_frame $payload]
		}
		$CONST(frame-header) {
			return [core::api::amqp::_deconstruct_header_frame $payload]
		}
		$CONST(frame-body) {
			return [core::api::amqp::_deconstruct_body_frame $payload]
		}
		$CONST(frame-heartbeat) {
			return [list {heartbeat}]
		}
		default {
			core::log::write ERROR {$fn: Unknown frame type: $type}
			error "Unknown frame type: $type" {} UNKNOWN_FRAME_TYPE
		}

	}
}

# Generic send/receive
#
proc core::api::amqp::_send_frame {sock frame} {
	core::log::write DEBUG {==> core::api::amqp::_send_frame sock=$sock}

	variable CFG

	set fn {core::api::amqp::_send_frame}

	core::log::write DEBUG {AMQP FRAME $frame}

	if {[catch {
		foreach char $frame {
			puts -nonewline $sock [format %c $char]
		}
		flush $sock
	} msg]} {
		core::log::write ERROR {$fn: write failure: $msg}
		core::socket::client::force_close -sock $sock
		set CFG(connected) 0
		error $msg $::errorInfo SEND_FRAME_ERROR
	}
}

proc core::api::amqp::_receive_frame {sock} {
	core::log::write DEBUG {==> core::api::amqp::_receive_frame sock=$sock}

	variable CFG

	set fn {core::api::amqp::_receive_frame}

	variable LENGTH_CONST
	set length $LENGTH_CONST
	set frame [list]

	while {$length > 0} {
		set char [read $sock 1]

		lappend frame [scan $char %c]

		incr length -1

		if {$length == 0 && [llength $frame] == $LENGTH_CONST} {
			set size [core::api::amqp::_decode_long [lrange $frame 3 6]]

			incr length [expr {$size + 1}]
		}
	}

	return $frame
}

proc core::api::amqp::_encode_bit {bit_state input {output {}}} {
	set fn {core::api::amqp::_encode_octet}
	variable BIT_STATE_LOW
	variable BIT_STATE_HIGH

	if {$bit_state > $BIT_STATE_LOW} {
		set input [expr {[lindex $output end] | ($input << $bit_state)}]

		set output [lrange $output 0 end-1]
	}

	lappend output $input

	incr bit_state 1

	if {$bit_state > $BIT_STATE_HIGH} {
		set bit_state 0
	}

	return [list $bit_state $output]
}

proc core::api::amqp::_encode_octet {input {output {}}} {
	set fn {core::api::amqp::_encode_octet}

	lappend output $input

	return $output
}

proc core::api::amqp::_encode_short {input {output {}}} {
	set fn {core::api::amqp::_encode_short}

	lappend output [expr {($input >> 8) & 0xFF}]
	lappend output [expr {$input & 0xFF}]

	return $output
}

proc core::api::amqp::_encode_long {input {output {}}} {
	set fn {core::api::amqp::_encode_long}

	lappend output [expr {($input >> 24) & 0xFF}]
	lappend output [expr {($input >> 16) & 0xFF}]
	lappend output [expr {($input >> 8) & 0xFF}]
	lappend output [expr {$input & 0xFF}]

	return $output
}

proc core::api::amqp::_encode_longlong {input {output {}}} {
	set fn {core::api::amqp::_encode_longlong}

	lappend output [expr {($input >> 56) & 0xFF}]
	lappend output [expr {($input >> 48) & 0xFF}]
	lappend output [expr {($input >> 40) & 0xFF}]
	lappend output [expr {($input >> 32) & 0xFF}]
	lappend output [expr {($input >> 24) & 0xFF}]
	lappend output [expr {($input >> 16) & 0xFF}]
	lappend output [expr {($input >> 8) & 0xFF}]
	lappend output [expr {$input & 0xFF}]

	return $output
}

proc core::api::amqp::_encode_table {input {output {}}} {
	set fn {core::api::amqp::_encode_table}

	set entries [list]

	dict for {name value} $input {
		if {[string index $name 0] == {_}} {
			continue
		}

		# Assume everything is a string unless specified
		if {[dict exists $input "_$name"]} {
			set type [dict get $input "_$name"]
		} else {
			set type {string}
		}

		if {$type == {string} || ($type == {short-string} && [string length $value] > 255)} {
			set type {long-string}
		}

		set entries [core::api::amqp::_encode_shortstr $name $entries]

		if {$type == {table}} {
			set entries [core::api::amqp::_encode_octet [scan {F} %c] $entries]
			set entries [core::api::amqp::_encode_table $value $entries]
		} elseif {$type == {boolean}} {
			set entries [core::api::amqp::_encode_octet [scan {t} %c] $entries]
			set entries [core::api::amqp::_encode_octet $value $entries]
		} elseif {$type == {short-string}} {
			set entries [core::api::amqp::_encode_octet [scan {s} %c] $entries]
			set entries [core::api::amqp::_encode_shortstr $value $entries]
		} elseif {$type == {long-string}} {
			set entries [core::api::amqp::_encode_octet [scan {S} %c] $entries]
			set entries [core::api::amqp::_encode_longstr $value $entries]
		} else {
			core::log::write ERROR {$fn: Unknown type: $type}
			error "Unknown type: $type" {} UNKNOWN_TYPE
		}
	}

	set output [core::api::amqp::_encode_long [llength $entries] $output]
	lappend output {*}$entries

	return $output
}

proc core::api::amqp::_encode_shortstr {input {output {}}} {
	set fn {core::api::amqp::_encode_shortstr}

	set size [string length $input]

	set output [core::api::amqp::_encode_octet $size $output]

	for {set i 0} {$i < $size} {incr i} {
		lappend output [scan [string index $input $i] %c]
	}

	return $output
}

proc core::api::amqp::_encode_longstr {input {output {}}} {
	set fn {core::api::amqp::_encode_longstr}

	set size [string length $input]

	set output [core::api::amqp::_encode_long $size $output]

	for {set i 0} {$i < $size} {incr i} {
		lappend output [scan [string index $input $i] %c]
	}

	return $output
}

proc core::api::amqp::_decode_octet {input {chain 0}} {
	set fn {core::api::amqp::_decode_octet}

	set output [expr {[lindex $input 0]}]

	if {$chain} {
		return [list $output [lrange $input 1 end]]
	}

	return $output
}

proc core::api::amqp::_decode_short {input {chain 0}} {
	set fn {core::api::amqp::_decode_short}

	set output [expr {([lindex $input 0] << 8) + [lindex $input 1]}]

	if {$chain} {
		return [list $output [lrange $input 2 end]]
	}

	return $output
}

proc core::api::amqp::_decode_long {input {chain 0}} {
	set fn {core::api::amqp::_decode_long}

	set output [expr {([lindex $input 0] << 24) + ([lindex $input 1] << 16) + ([lindex $input 2] << 8) + [lindex $input 3]}]

	if {$chain} {
		return [list $output [lrange $input 4 end]]
	}

	return $output
}

proc core::api::amqp::_decode_longlong {input {chain 0}} {
	set fn {core::api::amqp::_decode_longlong}

	set output [expr {([lindex $input 0] << 56) + ([lindex $input 1] << 48) + ([lindex $input 2] << 40) + ([lindex $input 3] << 32) + ([lindex $input 4] << 24) + ([lindex $input 5] << 16) + ([lindex $input 6] << 8) + [lindex $input 7]}]

	if {$chain} {
		return [list $output [lrange $input 8 end]]
	}

	return $output
}

proc core::api::amqp::_decode_longstr {input {chain 0}} {
	set fn {core::api::amqp::_decode_longstr}

	set ret [core::api::amqp::_decode_long $input 1]
	lassign $ret size input

	set output {}

	for {set i 0} {$i < $size} {incr i} {
		append output [format %c [lindex $input $i]]
	}

	if {$chain} {
		return [list $output [lrange $input $size end]]
	}

	return $output
}

proc core::api::amqp::_decode_shortstr {input {chain 0}} {
	set fn {core::api::amqp::_decode_shortstr}

	set size [core::api::amqp::_decode_octet [lindex $input 0]]

	set output {}

	for {set i 1} {$i < [expr {$size + 1}]} {incr i} {
		append output [format %c [lindex $input $i]]
	}

	if {$chain} {
		return [list $output [lrange $input [expr {$size + 1}] end]]
	}

	return $output
}

proc core::api::amqp::_decode_table {input {chain 0}} {
	set fn {core::api::amqp::_decode_table}

	set ret [core::api::amqp::_decode_long $input 1]
	lassign $ret size input

	set output [dict create]

	set data [lrange $input 0 [expr {$size - 1}]]

	while {[llength $data] > 0} {
		set ret [core::api::amqp::_decode_shortstr $data 1]
		lassign $ret name data

		set ret [core::api::amqp::_decode_octet $data 1]
		lassign $ret type data

		set type [format %c $type]

		if {$type == "F"} {
			set type {table}
			set ret [core::api::amqp::_decode_table $data 1]
		} elseif {$type == "t"} {
			set type {boolean}
			set ret [core::api::amqp::_decode_octet $data 1]
		} elseif {$type == "s"} {
			set type {short-string}
			set ret [core::api::amqp::_decode_shortstr $data 1]
		} elseif {$type == "S"} {
			set type {long-string}
			set ret [core::api::amqp::_decode_longstr $data 1]
		} else {
			core::log::write ERROR {$fn: Unknown type: $type}
			error "Unknown type: $type" {} UNKNOWN_TYPE
		}

		lassign $ret value data

		dict set output $name $value
		dict set output "_$name" $type
	}

	if {$chain} {
		return [list $output [lrange $input $size end]]
	}

	return $output
}
