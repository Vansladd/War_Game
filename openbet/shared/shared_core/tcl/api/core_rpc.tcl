#
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#
# Core RPC API library
#
# Supports JSON-RPC 2.0 by default
#
# This is an internal API that does not have any security
# Please use at your own risk
#
set pkg_version 1.0
package provide core::api::core_rpc $pkg_version

package require core::log           1.0
package require core::util          1.0
package require core::check         1.0
package require core::args          1.0
package require core::gc            1.0
package require core::socket        1.0
package require core::view          1.0
package require tls
package require http

core::args::register_ns \
	-namespace core::api::core_rpc \
	-version   $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::xml \
		core::util] \
	-docs xml/api/core_rpc.xml

namespace eval ::core::api::core_rpc {
	variable CFG
	variable DEF

	set CFG(enabled)     0
	set CFG(initialised) 0
}

# Initialise the API
core::args::register \
	-proc_name core::api::core_rpc::init \
	-args [list \
		[list -arg -force_init       -mand 0 -check BOOL                                       -default 0              -desc {Force initialisation}] \
		[list -arg -enabled          -mand 0 -check BOOL    -default_cfg CORE_RPC_ENABLED      -default 0              -desc {Is RPC available}] \
		[list -arg -host             -mand 0 -check STRING  -default_cfg CORE_RPC_HOST         -default {localhost}    -desc {Core RPC server host}] \
		[list -arg -url              -mand 0 -check STRING  -default_cfg CORE_RPC_URL          -default {/rpc_server}  -desc {Core RPC server url}] \
		[list -arg -json_rpc_version -mand 0 -check STRING  -default_cfg CORE_JSON_RPC_VERSION -default {2.0}          -desc {JSON RPC version}] \
	] \
	-body {
		variable CFG

		if {$CFG(initialised) && !$ARGS(-force_init)} {
			core::log::write INFO {API already Initialised}
			return
		}

		set CFG(enabled)          $ARGS(-enabled)
		set CFG(host)             $ARGS(-host)
		set CFG(url)              $ARGS(-url)
		set CFG(json_rpc_version) $ARGS(-json_rpc_version)


		# The following packages may not be available
		# so we should disable the package if they aren't
		if {[catch {
			core::util::load_package -package yajltcl
			core::util::load_package -package json
		} err]} {
			core::log::write WARN {WARNING $err}
			set CFG(enabled) 0
		}

		if {$CFG(enabled)} {
			core::log::write INFO {Core RPC Initialised $CFG(host) $CFG(url)}
		} else {
			core::log::write INFO {Core RPC Disabled}
		}


		incr CFG(initialised)
	}

# Initialise the API
core::args::register \
	-proc_name core::api::core_rpc::get_config \
	-args [list \
		[list -arg -name    -check STRING -desc {Config name}] \
		[list -arg -default -check STRING -desc {Default value}] \
	] \
	-body {
		variable CFG

		set name $ARGS(-name)

		if {![info exists CFG($name)]} {
			return $ARGS(-default)
		}

		return $CFG($name)
	}

core::args::register \
	-proc_name core::api::core_rpc::add_headers \
	-args      [list \
		[list -arg -content_type -mand 0 -check ASCII -default "text/html" -desc {Content type}] \
		[list -arg -charset      -mand 0 -check ASCII -default "UTF-8"     -desc {Charset}] \
	] \
	-body {
		variable ::CFG

		core::view::add_header \
			-name  "Content-Type" \
			-value "$ARGS(-content_type); charset=$ARGS(-charset)"

		core::view::add_header \
			-name  "Cache-Control" \
			-value "no-cache"

		core::view::add_header \
			-name  "Expires" \
			-value "0"
	}

core::args::register \
	-proc_name core::api::core_rpc::send_error_response \
	-args [list \
		[list -arg -id     -mand 1 -check INT                -desc {Request ID}] \
		[list -arg -code   -mand 1 -check STRING             -desc {Error code}] \
		[list -arg -msg    -mand 1 -check STRING             -desc {Error message}] \
		[list -arg -debug  -mand 0 -check ANY    -default {} -desc {Stack trace for debugging}] \
	] \
	-body {
		variable CFG

		core::log::write ERROR {ERROR $ARGS(-id) $ARGS(-code) $ARGS(-msg)}

		yajl create x -beautify 1

		x map_open \
			string jsonrpc string $CFG(json_rpc_version) \
			string error \
				map_open \
					string code    string $ARGS(-code) \
					string message string $ARGS(-msg) \
				map_close \
			string id \
			string $ARGS(-id) \
		map_close

		set json [x get]

		foreach line [split $json \n] {
			core::log::write DEBUG {ERROR JSON: $line}
		}

		core::log::write ERROR {ERROR $ARGS(-code) $ARGS(-msg)}
		foreach line [split $ARGS(-debug) \n] {
			core::log::write DEBUG {ERROR DEBUG: $line}
		}

		x free

		add_headers
		core::view::write -str $json

		return
	}

# Make the rpc request
core::args::register \
	-proc_name core::api::core_rpc::make_request \
	-args [list \
		[list -arg -proc_name    -mand 1 -check STRING -desc {Procedure name}] \
		[list -arg -id           -mand 1 -check INT    -desc {Request ID}] \
		[list -arg -arg_list     -mand 0 -check STRING -desc {Argument list n/v pair}] \
	] \
	-body {
		variable CFG

		# Marshal the message
		set message [marshal_request \
			-proc_name   $ARGS(-proc_name) \
			-id          $ARGS(-id) \
			-arg_list    $ARGS(-arg_list)]

		set req [core::socket::format_http_req \
			-host      $CFG(host) \
			-method    "POST" \
			-headers   [list Content-Type "application/json-rpc"] \
			-post_data $message \
			-encoding  "utf-8" \
			-url       $CFG(url)]

		foreach {req_id status complete} [::core::socket::send_req \
			-is_http     1 \
			-req         $req \
			-host        $CFG(host) \
			-port        80] {break}

		if {$status != "OK"} {
			core::socket::clear_req -req_id $req_id
			error "Error sending RPC request: $status" {} RPC_SEND
		}

		# Request successful - get and return the response data.
		set message [core::socket::req_info -req_id $req_id -item http_body]

		puts "$message"

		core::socket::clear_req -req_id $req_id

		lassign [unmarshal_response -message $message] id ret_list

		return $ret_list
	}

# Package the request to the core rpc server
core::args::register \
	-proc_name core::api::core_rpc::marshal_request \
	-args [list \
		[list -arg -proc_name   -mand 1 -check STRING -desc {Procedure name}] \
		[list -arg -id          -mand 1 -check INT    -desc {Request ID}] \
		[list -arg -arg_list    -mand 0 -check STRING -desc {Argument list n/v pair}] \
	] \
	-body {
		variable CFG

		yajl create x -beautify 1

		x map_open \
			string jsonrpc string $CFG(json_rpc_version) \
			string method  string $ARGS(-proc_name) \
			string id      string $ARGS(-id) \
			string params  map_open\

		foreach {arg_name arg_value} $ARGS(-arg_list) {
			x string $arg_name string $arg_value \
		}

		x map_close map_close

		set json [x get]

		foreach line [split $json \n] {
			core::log::write DEBUG {JSON REQ: $line}
		}

		x free

		# Return the JSON object
		return $json
	}

# Parse the request to the core rpc server
core::args::register \
	-proc_name core::api::core_rpc::unmarshal_request \
	-args [list \
		[list -arg -message -mand 1 -check STRING -desc {RPC message}] \
	] \
	-body {

		foreach line [split $ARGS(-message) \n] {
			core::log::write DEBUG {JSON REQ: $line}
		}

		set dict [::json::json2dict $ARGS(-message)]

		set proc_name [dict get $dict method]
		set id        [dict get $dict id]
		set arg_list  [list]

		dict for {n v} [dict get $dict params] {
			lappend arg_list $n $v
		}

		return [list $proc_name $id $arg_list]
	}

# Package the response from the core rpc server
core::args::register \
	-proc_name core::api::core_rpc::marshal_response \
	-args [list \
		[list -arg -id        -mand 1 -check INT    -desc    {Request ID}] \
		[list -arg -return    -mand 0 -check STRING -default {} -desc {Return data}] \
	] \
	-body {
		variable CFG

		yajl create x -beautify 1

		x map_open \
			string jsonrpc string $CFG(json_rpc_version) \
			string id      string $ARGS(-id) \
			string result  map_open\

		foreach {arg_name arg_value} $ARGS(-return) {
			x string $arg_name string $arg_value \
		}

		x map_close map_close

		set json [x get]

		foreach line [split $json \n] {
			core::log::write DEBUG {JSON RESP: $line}
		}

		x free

		# Return the JSON object
		return $json
	}

# Parse the response from the core rpc server
core::args::register \
	-proc_name core::api::core_rpc::unmarshal_response \
	-args [list \
		[list -arg -message -mand 1 -check STRING -desc {RPC message}] \
	] \
	-body {
		variable CFG

		foreach line [split $ARGS(-message) \n] {
			core::log::write DEBUG {JSON RESP: $line}
		}

		set dict [::json::json2dict $ARGS(-message)]

		# We need to establish if an error was encountered
		if {[dict exists $dict error]} {
			set code     [dict get [dict get $dict error] code]
			set message  [dict get [dict get $dict error] message]

			error "unmarshal_response ERROR $message" {} $code
		}

		set id           [dict get $dict id]
		set result_list  [list]

		dict for {n v} [dict get $dict result] {
			lappend result_list $n $v
		}

		return [list $id $result_list]
	}
