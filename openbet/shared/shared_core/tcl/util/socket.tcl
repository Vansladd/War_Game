#
# Copyright (c) 2006 Orbis Technology Ltd. All rights reserved.
#
# Make calls over (secure) socket without churning CPU
# and leaving hanging connection
#
# Possible Gotchas
# =================
#
# Advice: The synchronous request mechanism is here as a short cut.  If your
# application uses any other vwaits in the same scope I would STRONGLY recommend
# using the -async callback mechanism.

# It is NOT RECOMMENDED to make synchronous requests from within callbacks.
# Either use all asynchronous requests or all synchronous.
# For example, the following may not work as expected:

# after 1000 [list ::core::socket::send_req $req1 $server1 $port1]
# after 1000 [list ::core::socket::send_req $req2 $server2 $port2]
# vwait forever
# If setting off the requests from a timer use the -async CALLBACK flag
#
# Connection Statuses:
# ====================
#
# PRE_CONN:             Connection not yet attempted
# CONN:                 Connection attempt
# CONN_FAIL:            Connection attempt failed
# CONN_TIMEOUT:         Connection attempt timed out
# HANDSHAKE:            Negotiating SSL handshake (-tls flag set)
# HANDSHAKE_FAIL:       Error negotiating handshake
# SEND:                 Sending request to server
# SEND_FAIL:            Error whilst sending data
# READ:                 Reading response from server
# READ_FAIL:            Error whilst reading response
# REQ_TIMEOUT:          Request timed out
# HTTP_INVALID:         Response received is an invalid HTTP resp (-is_http 1 flag set)
# HTTP_INFORMATION_REQ: Server sent a 1** HTTP status code (-is_http 1 flag set)
# HTTP_REDIRECT:        Server sent a 3** HTTP status code (-is_http 1 flag set)
# HTTP_CLIENT_ERROR:    Server sent a 4** HTTP status code (-is_http 1 flag set)
# HTTP_SERVER_ERROR:    Server sent a 5** HTTP status code (-is_http 1 flag set)
# HTTP_UNKNOWN_STATUS:  Server sent unknown HTTP status code (-is_http 1 flag set)
# HTTP_BAD_RESP_LENGTH:      Response received is shorter than Content-Length header
# HTTP_BAD_RESP_CHUNK:       Error in handing chunked transfer-encoding
# OK:                   Success.  if -is_http flag is set, indicates a 2** status code
#
# Example usage:
# ==============
#
# Run from the command line:
# --------------------------
#
# ::core::socket::configure
#
# Send a simple request /response (not HTTP):
# --------------------------------
#
# foreach {req_id status complete} [core::socket::send_req \
#   -req  "My Request String" \
#   -host $MYSERVER \
#   -port $MYPORT] {break}
# if {$status == "OK"} {
#     process_response [::core::socket::req_info -req_id $req_id -item response]
# }
# ::core::socket::clear_req -req_id $req_id
#
# Send a simple http request:
# ---------------------------
#
# lassign [::core::socket::send_http_req\
#              -url http://www.apple.com] \
#         ] req_id status complete
# if {$status == "OK"} {
#     puts [core::socket::req_info -req_id $req_id -item http_body]
# }
# core::socket::clear_req -req_id $req_id
#
# Send request over SSL:
# ----------------------
#
# lassign [::core::socket::send_http_req\
#              -url https://www.apple.com] \
#         ] req_id status complete
# if {$status == "OK"} {
#     puts [core::socket::req_info -req_id $req_id -item http_body]
# }
# core::socket::clear_req -req_id $req_id
#
#
# Login to a site and resend the login cookie in the next request
# ---------------------------------------------------------------
#
# set host "myhost.com"
# set form_args [list "username" "joe" "password" "shmoe"]
# lassign [::core::socket::send_http_req \
#     -form_args $form_args  \
#     -url       "https://${host}/app/do_login" \
#     ] req_id status complete
#
# if {$status == "OK"} {
#     set cookie [::core::socket::req_info -req_id $req_id -item http_header -sub_item Set-Cookie]
#     if {$cookie != ""} {
#         set headers [list Cookie $cookie]
#     } else {
#         set headers [list]
#     }
#     ::core::socket::clear_req -req_id $req_id
# } else {
#     ::core::socket::clear_req -req_id $req_id
#     return
# }
#
# lassign [::core::socket::send_http_req \
#    -url https://${host}/app/next_page  \
#    ] req_id status complete
#
# if {$status == "OK"} {
#     puts [::core::socket::req_info -req_id $req_id -item http_body]
# }
# ::core::socket::clear_req -req_id $req_id
#
# Send Asnycronous requests:
# --------------------------
#
# set num_oustanding 0
# set g_vwait "WAIT"
#
# proc req_callback {req_id status msg client_data} {
#     if {$status == "OK"} {
#         puts "$client_data returned"
#     } else {
#         puts "$client_data failed"
#     }
#     ::core::socket::clear_req -req_id $req_id
#     incr ::num_oustanding -1
#     if {$::num_oustanding == 0} {
#         set ::g_vwait "COMPLETE"
#     }
# }
#
# ::core::socket::send_http_req \
#    -async       "req_callback" \
#    -client_data "Microsoft" \
#    -url   http://www.microsoft.com \
#
# incr num_oustanding
#
# ::core::socket::send_http_req \
#    -async       "req_callback" \
#    -client_data "Apple" \
#    -url "http://www.apple.com"
#
# incr num_oustanding
#
# ::core::socket::send_http_req \
#    -async       "req_callback" \
#    -client_data "Slashdot" \
#    -url         http://www.slashdot.org
#
# incr num_oustanding
#
# vwait g_vwait
#
# On error check to see if the server has process the request:
# ------------------------------------------------------------
#
# foreach {req_id status complete} [core::socket::send_req \
#    -req  "My Request String" \
#    -host $MYSERVER \
#    -port $MYPORT] {break}
# if {$status == "OK"} {
#     process_response [core::socket::req_info -req_id $req_id -item response]
# } else {
#     if {[core::socket::server_processed -req_id $req_id]} {
#         set_pmt "UNKNOWN"
#     } else {
#         set pmt "BAD"
#     }
# }
# ::core::socket::clear_req -req_id $req_id
#
# TODO:
# =====
#
# deal with transport and content encodings
# Transfer-Encodings:
#
#  compress      UNIX "compress" program method                     [RFC2616] (section 3.6)
#  deflate       "zlib" format [RFC1950] with "deflate" compression [RFC2616] (section 3.6)
#  gzip          Same as GNU zip [RFC1952]                          [RFC2616] (section 3.6)
#
# Content-Encodings:
#
#  compress      UNIX "compress" program method                     [RFC2616] (section 3.5)
#  deflate       "zlib" format [RFC1950] with "deflate" compression [RFC2616] (section 3.5)
#  gzip          Same as GNU zip [RFC1952]                          [RFC2616] (section 3.5)
#  identity      No transformation                                  [RFC2616] (section 3.5)
#  pack200-gzip  Network Transfer Format for Java Archives          [JSR200]
#

set pkgVersion 1.0
package provide core::socket $pkgVersion


# Dependencies
package require core::log   1.0
package require core::check 1.0
package require core::args  1.0
package require core::util  1.0

core::args::register_ns \
	-namespace core::socket \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args] \
	-docs      util/socket.xml

namespace eval core::socket {

	package require tls

	variable CFG

	set CFG(default_encoding)     binary

	set CFG(default_conn_timeout) 10000
	set CFG(default_req_timeout)  10000
	set CFG(write_buffer)         4096

	variable num_requests          0
	variable num_requests_complete 0
	variable req_arr
	array set req_arr [list]

	# Does the application server support setting/getting its status string?
	variable get_status [string equal [info commands asGetStatus] asGetStatus]
	variable set_status [string equal [info commands asSetStatus] asSetStatus]
	set DEFAULT_TLS_PROTOCOLS [list ssl2 0 ssl3 0 tls1 1]
	variable LABEL_CHECK {RE -args {^[[:alnum:]_.-]*$}}
}

core::args::register \
	-proc_name core::socket::configure \
	-args [list \
		[list -arg -default_encoding     -mand 0 -check ASCII -default binary  -desc {Default connection timeout in ms}] \
		[list -arg -default_conn_timeout -mand 0 -check UINT  -default 10000   -desc {Default request timeout in ms}] \
		[list -arg -default_req_timeout  -mand 0 -check UINT  -default 10000   -desc {Default encoding to send requests}] \
		[list -arg -write_buffer         -mand 0 -check UINT  -default 4096    -desc {Size in bytes of chunks sent to the socket}] \
	]

# Configure the package across all future requests
# @param -default_encoding Default encoding for the socket
# @param -default_conn_timeout Default request timeout in ms
# @param -default_req_timeout Default encoding to send requests
# @param -write_buffer Size in bytes of chunks sent to the socket
proc core::socket::configure args {

	variable CFG

	array set ARGS [core::args::check core::socket::configure {*}$args]

	set CFG(default_encoding)     $ARGS(-default_encoding)
	set CFG(default_conn_timeout) $ARGS(-default_conn_timeout)
	set CFG(default_req_timeout)  $ARGS(-default_req_timeout)
	set CFG(write_buffer)         $ARGS(-write_buffer)
}

core::args::register \
	-proc_name core::socket::get_num_requests

# Return number of requests submitted for information purposes
proc core::socket::get_num_requests args {

	variable num_requests

	return $num_requests
}

core::args::register \
	-proc_name core::socket::get_num_requests_complete

# Return number of requests submitted for information purposes
proc core::socket::get_num_requests_complete args {

	variable num_requests_complete

	return $num_requests_complete
}


# Nine times out of ten, we're just going to be wanting to send a simple http
# request, and the process of splitting, formatting, sending requests in the
# calling code gets quickly cumbersome when you need to do this a lot.  Hence
# this wrapper function for format_http_req/send_req.
#
# For simplicity, this doesn't handle async requests.  Bear in mind requests
# still need to be cleaned up by the calling process.
#
# Returns same values as send_req, or tuple list on error, {ERR_TYPE ERR_MSG}
# Possible values for ERR_TYPE:
#   ERR         - general error, essentially invalid arguments
#   ERR_SPLIT   - URL is invalid
#   ERR_FORMAT  - Unable to format http request in format_http_req
#   ERR_SENDING - Error sending request
#
core::args::register \
	-desc {Helper function for sending an http request in one call} \
	-proc_name core::socket::send_http_req \
	-args [list \
		[list -arg -url                  -mand 1 -check ASCII                           -desc {Request URL on server}] \
		[list -arg -label                -mand 0 -check $core::socket::LABEL_CHECK      -desc {Label to use instead of host when logging timings. Defaults to -host if not specified}] \
		[list -arg -method               -mand 0 -check ASCII  -default {}              -desc {HTTP method, GET, POST, PUT, DELETE or PATCH. If not specified defaults to POST if either -post_data or -form_args are specified, GET otherwise}] \
		[list -arg -http_ver             -mand 0 -check {ENUM -args {1.0 1.1}}          -default 1.0 -default_cfg NET_SOCKET_DEFAULT_HTTP_VER \
																			-desc {HTTP version. If HTTP 1.1 sends a Connection: close header}] \
		[list -arg -conn_timeout         -mand 0 -check INT    -default -1              -desc {Connection timeout for this request}] \
		[list -arg -req_timeout          -mand 0 -check INT    -default -1              -desc {Request timeout for this request}] \
		[list -arg -tls_args             -mand 0 -check LIST   -default {}              -desc {List of arguments to be passed to tls::socket if the request is sent over SSL. DEPRECATED please use individual tls parameters}] \
		[list -arg -tls_validate_cert    -mand 0 -check BOOL   -default 0               -desc {Check the certificate provided by the server is valid}] \
		[list -arg -tls_client_cert_file -mand 0 -check STRING -default {}              -desc {File containing client certificate to be provided to server}] \
		[list -arg -tls_client_key_file  -mand 0 -check STRING -default {}              -desc {File containing the private key to use for this connection}] \
		[list -arg -tls_ca_dir           -mand 0 -check STRING -default {/etc/pki/tls/} -desc {Directory to search for CA certificates}] \
		[list -arg -tls_validate_subject -mand 0 -check BOOL   -default 0               -desc {Check the CN strings in the servers certificate match the host we are contacting}] \
		[list -arg -tls_host_to_match    -mand 0 -check STRING -default {}              -desc {Hostname to match against the server certificates subject}] \
		[list -arg -tls_protocols        -mand 0 -check LIST   \
			-default $core::socket::DEFAULT_TLS_PROTOCOLS -default_cfg NET_SOCKET_TLS_PROTOCOLS       -desc {The protocol versions and boolean values to support for this request}] \
			[list -arg -encoding             -mand 0 -check ASCII  -default {}              -desc {Encoding we will be sending the request in}] \
		[list -arg -headers              -mand 0 -check LIST   -default [list]          -desc {List of name value pairs of HTTP headers (Cookies etc...)}] \
		[list -arg -form_args            -mand 0 -check LIST   -default [list]          -desc {List of name value pairs of form arguments. If -method is GET then these are appended to the URL, otherwise this defaults -method POST and sent as post x-www-form-urlencoded arguments}] \
		[list -arg -post_data            -mand 0 -check ANY    -default {}              -desc {Raw Data to be posted with the request. Cannot have both form_args and post_data set. You should set an appropriate Content-Type header explicitly}] \
		[list -arg -urlencode_unsafe     -mand 0 -check BOOL   -default 0               -desc {URL encode unsafe characters}] \
		[list -arg -async                -mand 0 -check ANY    -default {}              -desc {Async callback procedure. If specified then HTTP call will be asynchronous rather than synchronous, and this proc will be registered as a callback once the call completes}] \
		[list -arg -client_data          -mand 0 -check ANY    -default {}              -desc {Non socket data that will be sent to the async callback function -async}] \
	] \
	-returns {A list of req_id status_code completed. Throws an error for bad arguments} \
-body {
	variable CFG
	set fn {core::socket::send_http_req}

	#  Allow caller to specify a TLS string to pass to tls is https is
	#  used
	set url       $ARGS(-url)
	set label     $ARGS(-label)
	set tls_args  $ARGS(-tls_args)
	set post_data $ARGS(-post_data)
	set form_args $ARGS(-form_args)

	set encoding $CFG(default_encoding)
	if {$ARGS(-encoding) != ""} {
		set encoding $ARGS(-encoding)
	}

	# Default method to POST, as this is default in format_req
	set lformat_arg   [list]
	set lsend_req_arg [list]

	set method $ARGS(-method)
	if {$method == ""} {
		if {$post_data == "" && [llength $form_args] == 0} {
			set method GET
		} else {
			set method POST
		}
	}

	lappend lformat_arg -urlencode_unsafe $ARGS(-urlencode_unsafe)

	if {$ARGS(-conn_timeout) != -1} {
		lappend lsend_req_arg  -conn_timeout $ARGS(-conn_timeout)
	}
	if {$ARGS(-req_timeout)} {
		lappend lsend_req_arg  -req_timeout $ARGS(-req_timeout)
	}
	if {[llength $ARGS(-headers)] > 0} {
		lappend lformat_arg    -headers $ARGS(-headers)
	}

	lappend lsend_req_arg  -encoding $encoding
	lappend lformat_arg    -encoding $encoding


	if {$form_args != ""} {
		lappend lformat_arg  -form_args $form_args
	}
	if {$post_data != ""} {
		lappend lformat_arg  -post_data $post_data
	}
	lappend lformat_arg -method $method

	# Split to get host and port, needed for send_req and to get tls option
	if {[catch {
		set lpart [core::socket::split_url -url $url]
	} msg]} {
		core::log::write ERROR {$fn: Cannot parse URL $url $msg}
		error [list "ERR_URL" "$msg"]
	}

	lassign $lpart scheme host port loc
	core::log::write DEBUG {$scheme $host $port $loc}
	# format_http_req needs the host
	lappend lformat_arg    -host $host

	if {$scheme == "https"} {
		if {$tls_args != {}} {
			core::log::write WARNING {core::socket::send_http_req : -tls_args parameter is deprecated,\
				please update your code to use the individual tls parameters}
			lappend lsend_req_arg  -tls $tls_args
		} else {
			lappend lsend_req_arg -tls 1
			lappend lsend_req_arg -tls_validate_cert $ARGS(-tls_validate_cert)
			lappend lsend_req_arg -tls_client_cert_file $ARGS(-tls_client_cert_file)
			lappend lsend_req_arg -tls_client_key_file $ARGS(-tls_client_key_file)
			lappend lsend_req_arg -tls_ca_dir $ARGS(-tls_ca_dir)
			lappend lsend_req_arg -tls_validate_subject $ARGS(-tls_validate_subject)
			lappend lsend_req_arg -tls_host_to_match $ARGS(-tls_host_to_match)
			lappend lsend_req_arg -tls_protocols     $ARGS(-tls_protocols)
		}
	} elseif {$scheme != "http"} {
		core::log::write ERROR {$fn: Unknown scheme $scheme}
		error [list ERR_SCHEME "$fn: Unknown scheme $scheme"]
	}

	lappend lformat_arg -http_ver $ARGS(-http_ver)

	if {$ARGS(-async) != ""} {
		lappend lsend_req_arg -async $ARGS(-async)
	}
	if {$ARGS(-client_data) != ""} {
		lappend lsend_req_arg -client_data $ARGS(-client_data)
	}

	#  Set the path to pass in the HTTP header
	#  Make sure it starts with /
	if {$loc == ""} {
		set path "/"
	} elseif {[string index $loc 0] != "/"} {
		set path "/"
		append path $loc
	} else {
		set path $loc
	}

	# Format request in order to send
	if {[catch {
		set request [core::socket::format_http_req {*}$lformat_arg -url $path]
	} msg]} {
		core::log::write ERROR {$fn: Unable to format request - $msg}
		error [list ERR_FORMAT $msg]
	}

	# Send formatted request
	if {[catch {
		lassign [core::socket::send_req  -is_http 1 \
								-label $label \
								{*}$lsend_req_arg \
								-req $request      \
								-host $host          \
								-port $port] req_id status complete
	} msg]} {
		core::log::write ERROR {$fn: Unable to send req to $host - $msg}
		error [list ERR_SEND "$fn: error in core::socket::send_req :- $msg"]
	}

	return [list $req_id $status $complete]
}

core::args::register \
	-proc_name core::socket::send_req \
	-args [list \
		[list -arg -req                  -mand 1 -check ANY                             -desc {Request}] \
		[list -arg -label                -mand 0 -check $core::socket::LABEL_CHECK      -desc {Label to use instead of host when logging timings. Defaults to -host if not specified}] \
		[list -arg -host                 -mand 1 -check ASCII                           -desc {Connection host}] \
		[list -arg -port                 -mand 1 -check UINT                            -desc {Connection port}] \
		[list -arg -tls                  -mand 0 -check ASCII  -default 0               -desc {Enable tls. For Compatibility this can also be passed a string of parameters to pass to the tls package, which will disable the use of other tls parameters. This legacy compatibility is deprecated and will be removed}] \
		[list -arg -tls_validate_cert    -mand 0 -check BOOL   -default 1               -desc {Check the certificate provided by the server is valid}] \
		[list -arg -tls_client_cert_file -mand 0 -check STRING -default {}              -desc {File containing client certificate to be provided to server}] \
		[list -arg -tls_client_key_file  -mand 0 -check STRING -default {}              -desc {File containing the private key to use for this connection}] \
		[list -arg -tls_ca_dir           -mand 0 -check STRING -default {/etc/pki/tls/} -desc {Directory to search for CA certificates}] \
		[list -arg -tls_validate_subject -mand 0 -check BOOL   -default 1               -desc {Check the CN strings in the servers certificate match the host we are contacting}] \
		[list -arg -tls_host_to_match    -mand 0 -check STRING -default {}              -desc {Hostname to match against the server certificates subject}] \
		[list -arg -tls_protocols        -mand 0 -check LIST   \
			-default $core::socket::DEFAULT_TLS_PROTOCOLS -default_cfg NET_SOCKET_TLS_PROTOCOLS       -desc {The protocol versions and boolean values to support for this request}] \
		[list -arg -client_data          -mand 0 -check ANY    -default {}              -desc {Non socket data that will be sent to the async callback function}] \
		[list -arg -conn_timeout         -mand 0 -check INT    -default -1              -desc {Connection timeout for this request}] \
		[list -arg -req_timeout          -mand 0 -check INT    -default -1              -desc {Request timeout for this request}] \
		[list -arg -encoding             -mand 0 -check ASCII  -default {}              -desc {Encoding we will be sending the request in}] \
		[list -arg -async                -mand 0 -check ANY    -default {}              -desc {Procedure, request will call when completed. \{\} indicates synchronous request}] \
		[list -arg -is_http              -mand 0 -check BOOL   -default 0               -desc {1 indicates that req will attempt to parse response as http. 0 indicates not}] \
	]

# Start the process of sending the request.  If the -async flag is set
# the request is started when the application enters the vwait loop
#
# @param -req Request
# @param -host Connection host
# @param -port Connection port
# @param -tls String passed to tls::socket to send request over SSL. -1 Indates non SSL.
# @param -client_data Non socket data that will be sent to the async callback function
# @param -conn_timeout Connection timeout for this reques
# @param -req_timeout Request timeout for this request
# @param -encoding Encoding we will be sending the request in
# @param -async Procedure, request will call when completed. \{\} indicates synchronous request
# @param -is_http 1 indicates that req will attempt to parse response as http. 0 indicates not
proc core::socket::send_req args {
	set fn {core::socket::send_req}
	variable CFG
	variable num_requests
	variable req_arr
	variable get_status
	variable set_status

	array set ARGS [core::args::check core::socket::send_req {*}$args]

	core::log::write DEBUG {core::socket::send_req called $::core::socket::CFG(default_req_timeout)}

	# Set defaults based on configured values. Note this can be specified after the request
	# is registered so we need to set this here as opposed to using -default

	if {$ARGS(-conn_timeout) == -1} {
		set ARGS(-conn_timeout) $CFG(default_conn_timeout)
	}

	if {$ARGS(-req_timeout) == -1} {
		set ARGS(-req_timeout) $CFG(default_req_timeout)
	}

	if {$ARGS(-encoding) == {}} {
		set ARGS(-encoding) $CFG(default_encoding)
	}

	if {$ARGS(-is_http)} {
		#  Grab the HTTP Version from the request

		if {![regexp -linestop -- {^[A-Z]+ .* HTTP/(1.[01])} $ARGS(-req) http_line http_ver]} {
			core::log::write ERROR {$fn: -req (length [string length $ARGS(-req)]) did not contain a valid HTTP header}
			error "core::socket::send_req: -req must be a valid HTTP request"
		}
	} else {
		#  If non-http then blank http_ver
		#
		set http_ver {}
	}

	set host  $ARGS(-host)
	set label $ARGS(-label)
	if {$label eq ""} {
		set label $host
	}
	set port $ARGS(-port)
	set encoding $ARGS(-encoding)

	# Note
	#  -encoding
	#  -translation
	#  -http_ver should match the
	#

	#add the request object
	set req_id $num_requests
	#  For http 1.1 this is the binary encodings
	#  Otherwise its in TCL native Unicode
	#  Whether to set the socket as binary

	if {$http_ver == "1.1"} {
		#  and convert to / from the encoding
		if {$encoding == "binary"} {
			set req $ARGS(-req)
		} else {
			set req [encoding convertto $encoding $ARGS(-req)]
		}
		set req_arr($req_id,req) $req
	} else {
		#  For backwards compatibility we rely on the socket
		#  encoding
		set req_arr($req_id,req)             $ARGS(-req)
	}

	# Setup tls
	set req_arr($req_id,verify_host) {}
	if {[string is integer -strict $ARGS(-tls)] && $ARGS(-tls) <= 0} {
		set req_arr($req_id,tls) 0
		set req_arr($req_id,tls_args) {}
	} elseif {[string is integer -strict $ARGS(-tls)] && $ARGS(-tls) == 1} {
		set req_arr($req_id,tls)      1
		set req_arr($req_id,tls_args) {}

		append req_arr($req_id,tls_args) {-require } $ARGS(-tls_validate_cert)

		foreach {proc_arg tls_item} {
			tls_client_cert_file -certfile
			tls_client_key_file  -keyfile
			tls_ca_dir           -cadir
		} {
			if {$ARGS(-$proc_arg) != {}} {
				append req_arr($req_id,tls_args) { } $tls_item { } $ARGS(-$proc_arg)
			}
		}

		set req_arr($req_id,verify_host) {}
		if {$ARGS(-tls_validate_subject) != 0} {
			if {$ARGS(-tls_host_to_match) != {}} {
				set req_arr($req_id,verify_host) $ARGS(-tls_host_to_match)
			} else {
				set req_arr($req_id,verify_host) $ARGS(-host)
			}
		}
	} else {
		# We must have some old compat tls args stuffed into the
		# -tls parameter. Mold this into the new data items.
		# **NOTE** This functionality is deprecated and WILL
		# be removed in a future release
		core::log::write WARNING {core::socket::send_req : Placing tls args into the -tls parameter is deprecated,\
			please update your code to use the individual tls parameters}
		set req_arr($req_id,tls)      1
		set req_arr($req_id,tls_args) $ARGS(-tls)
	}

	# Specify the protocols to pass to the tls package
	# OBCORE-911 and TD-XXX to counter the SSL poodle attack and
	# vulnerabilities in SSL3
	#
	# First get defaults
	set default_proto [OT_CfgGet NET_SOCKET_TLS_PROTOCOLS $core::socket::DEFAULT_TLS_PROTOCOLS]
	foreach {protocol def_value} $default_proto {
		set proto_index [lsearch -exact $ARGS(-tls_protocols) $protocol]

		if {$proto_index != -1} {
			set value [lindex $ARGS(-tls_protocols) [expr {$proto_index + 1}]]

			lappend req_arr($req_id,tls_args) -$protocol $value
		} else {
			core::log::write INFO {core::socket::send_req : Using default for protocol $protocol \{$def_value\}}
			lappend req_arr($req_id,tls_args) -$protocol $def_value
		}
	}

	core::log::write INFO {core::socket::send_req : tls_args $req_arr($req_id,tls_args)}

	set req_arr($req_id,host)            $host
	set req_arr($req_id,label)           $label
	set req_arr($req_id,port)            $port
	set req_arr($req_id,conn_timeout)    $ARGS(-conn_timeout)
	set req_arr($req_id,req_timeout)     $ARGS(-req_timeout)
	set req_arr($req_id,async)           $ARGS(-async)
	set req_arr($req_id,client_data)     $ARGS(-client_data)
	set req_arr($req_id,is_http)         $ARGS(-is_http)
	set req_arr($req_id,http_ver)        $http_ver
	set req_arr($req_id,encoding)        $encoding


	set req_arr($req_id,status)          "PRE_CONN"
	set req_arr($req_id,sock)            ""
	set req_arr($req_id,after_id)        ""
	set req_arr($req_id,response)        ""
	set req_arr($req_id,write_pointer)   0
	set req_arr($req_id,http_status)     ""
	set req_arr($req_id,http_status_str) ""
	set req_arr($req_id,http_headers)    [list]
	#  ,http_body is used for http 1.1 requests
	#  to hold the response after de-chunking
	#  and convertfrom
	set req_arr($req_id,http_body)       {}
	set req_arr($req_id,http_body_start) 0
	set req_arr($req_id,complete)        0
	set req_arr($req_id,start_time)      -1
	set req_arr($req_id,end_time)        -1

	incr num_requests
	if {$get_status} {
		set req_arr($req_id,appserv_status) [asGetStatus]
	} else {
		set req_arr($req_id,appserv_status) ""
	}

	if {$set_status} {
		asSetStatus "net: [clock format [clock seconds] -format "%T"] - $label"
	}

	#start the request
	core::log::write INFO {core::socket::send_req host $host port $port req $req_id http_ver $http_ver}
	set ret [_do_conn $req_id]

	if {$ret != 0 && $req_arr($req_id,async) == ""} {
		core::log::write DEBUG {core::socket::send_req synchronous call.  Entering vwait loop}
		vwait "::core::socket::req_arr($req_id,complete)"
	} else {
		core::log::write DEBUG {core::socket::send_req asynchronous call. Not going into vwait.}
	}

	core::log::write DEBUG {core::socket::send_req finished}

	return [list $req_id $req_arr($req_id,status) $req_arr($req_id,complete)]
}

core::args::register \
	-proc_name core::socket::clear_req \
	-args [list \
		[list -arg -req_id -mand 1 -check UINT -desc {Request Identifier}] \
	]

# Free the memory associated with the request.  Incomplete requests can
# also be deleted
# @param -req_id Request Identifier
proc core::socket::clear_req args {

	variable req_arr
	variable num_requests

	array set ARGS [core::args::check core::socket::clear_req {*}$args]

	set req_id $ARGS(-req_id)

	core::log::write INFO {core::socket::clear_req called.  req_id = $req_id}

	if {![info exists req_arr($req_id,sock)]} {
		# req_id doesn't exist.  If it was a previous req assume closed previously
		# and continue.  Otherwise something's a bit wrong: throw an error
		if {$req_id < $num_requests} {
			return
		} else {
			core::log::write ERROR {::core::socket::clear_req trying to clear non-existent request $req_id}
			error "::core::socket::clear_req Unknown req $req_id"
		}
	}

	if {$req_arr($req_id,complete) == 1} {
		#Request completed normally
		_tidy_req $req_id 1
	} else {
		#Request in progress
		core::log::write WARNING {::core::socket::clear_req Removing request before completion $req_id}
		_finish_req $req_id $req_arr($req_id,status) "interupted"
	}

	array unset req_arr "$req_id,*"

	core::log::write DEBUG {core::socket::clear_req finished}
}

core::args::register \
	-proc_name core::socket::req_info \
	-args [list \
		[list -arg -req_id   -mand 1 -check UINT              -desc {Request Identifier}] \
		[list -arg -item     -mand 1 -check ASCII             -desc {Name of the object to retrieve}] \
		[list -arg -sub_item -mand 0 -check ASCII -default {} -desc {Name of the sub object to retrieve}] \
	]

# Details of the request
# @param -req_id Request Identifier
# @param -item Name of the object to retrieve
# @param -sub_item Name of the sub object to retrieve
proc core::socket::req_info args {

	variable req_arr

	array set ARGS [core::args::check core::socket::req_info {*}$args]

	set req_id   $ARGS(-req_id)
	set item     $ARGS(-item)
	set sub_item $ARGS(-sub_item)
	set usage    [core::args::proc_usage_info core::socket core::socket::req_info]

	switch -- $item {
		"host"         -
		"port"         -
		"conn_timeout" -
		"req_timeout"  -
		"async"        -
		"client_data"  -
		"is_http"      -
		"status"       -
		"response"     -
		"complete"     -
		"http_status"  -
		"http_status_str" -
		"http_headers" -
		"start_time"   -
		"req_start_time" {
			return $req_arr($req_id,$item)
		}
		"tls" {
			return $req_arr($req_id,tls_args)
		}
		"http_body"    {
			if {$req_arr($req_id,http_ver) == "1.1"} {
				return $req_arr($req_id,http_body)
			} else {
				set body_start $req_arr($req_id,http_body_start)
				if {$body_start == 0} {
					return ""
				} else {
					return [string range $req_arr($req_id,response) $body_start end]
				}
			}
		}
		"http_header"  {
			#Headers stored as list rather than hash as we never expect many of them
			if {$sub_item == ""} {
				error "$usage\n\nSpecify sub_item for http_header."
			}
			set ret [list]
			foreach {n v} $req_arr($req_id,http_headers) {
				#http headers are case insensitive
				if {[string equal -nocase $n $sub_item]} {
					lappend ret $v
				}
			}
			#in the HTTP RFC repeated header lines are equivalent to comma separated
			#items
			return [join $ret ","]
		}
		"conn_time" {
			return [_diff_time $req_arr($req_id,start_time) \
				$req_arr($req_id,req_start_time)]
		}
		"req_time" {
			set req_time [_diff_time $req_arr($req_id,req_start_time) \
				$req_arr($req_id,end_time)]
		}
		default {
			error "$usage\n\nUnknown item $item"
		}
	}
}

core::args::register \
	-proc_name core::socket::format_http_req \
	-args [list \
		[list -arg -url              -mand 1 -check ASCII                -desc {Request URL on server}] \
		[list -arg -method           -mand 0 -check ASCII  -default POST -desc {GET, POST, PUT, DELETE or PATCH}] \
		[list -arg -host             -mand 0 -check ASCII  -default {}   -desc {Host to send request to.  Useful if going via proxy server}] \
		[list -arg -port             -mand 0 -check UINT   -default -1   -desc {Port to connect to on server}] \
		[list -arg -form_args        -mand 0 -check STRING -default {}   -desc {List of name value pairs of form arguments}] \
		[list -arg -headers          -mand 0 -check ASCII  -default {}   -desc {List of name value pairs of HTTP headers (Cookies etc...)}] \
		[list -arg -post_data        -mand 0 -check ANY    -default {}   -desc {Data to be posted with the request.  Cannot have both form_args and post_data set}] \
		[list -arg -encoding         -mand 0 -check ASCII  -default {}   -desc {Port to connect to on server}] \
		[list -arg -urlencode_unsafe -mand 0 -check BOOL   -default 0    -desc {URL encode unsafe characters}] \
		[list -arg -http_ver         -mand 0 -check {ENUM -args {1.0 1.1}} -default 1.0 -default_cfg NET_SOCKET_DEFAULT_HTTP_VER \
																		-desc {HTTP version. Specifying 1.1 will also add Connection: close HTTP header}] \
	]

# Formats an http request
# @param -url               Request URL on server
# @param -method            GET, POST, PUT, DELETE or PATCH
# @param -host              Host to send request to.  Useful if going via proxy server
# @param -port              Port to connect to on server
# @param -form_args         List of name value pairs of form arguments
# @param -headers           List of name value pairs of HTTP headers (Cookies etc...)
# @param -post_data         Data to be posted with the request. Cannot have both form_args and post_data set
# @param -encoding          Port to connect to on server
# @param -urlencode_unsafe  URL encode unsafe characters
proc core::socket::format_http_req args {
	set fn {core::socket::format_http_req}
	variable CFG

	array set ARGS [core::args::check core::socket::format_http_req {*}$args]

	if {$ARGS(-encoding) == {}} {
		set ARGS(-encoding) $CFG(default_encoding)
	}

	set url                    $ARGS(-url)
	set host                   $ARGS(-host)
	set port                   $ARGS(-port)
	set form_args              $ARGS(-form_args)
	set method                 $ARGS(-method)
	set headers                $ARGS(-headers)
	set post_data              $ARGS(-post_data)
	set encoding               $ARGS(-encoding)
	set urlencode_unsafe       $ARGS(-urlencode_unsafe)
	set form_args_str          ""
	set http_version           $ARGS(-http_ver)
	set ret                    ""
	set content_type_specified 0
	set usage                  [core::args::proc_usage_info core::socket core::socket::format_http_req]
	# banned headers must be lower case
	set lbanned_header         [list]

	if {$port != -1} {
		append host ":" $port
	}

	# The method
	if {[lsearch {GET POST PUT DELETE PATCH} $method] == -1} {
		error "$usage\n\nUnknown method $method"
	}

	append ret "$method "

	# Url
	if {$url == ""} {
		error "$usage\n\nNo URL"
	}

	append ret "$url"

	if {$http_version == "1.1"} {
		lappend lbanned_header connection
	}

	# Form args
	if {$form_args != {}} {
		if {[llength $form_args] % 2} {
			error "$usage\n\nform_args should be a list of name/value pairs"
		}
		foreach {n v} $form_args {
			if {$urlencode_unsafe} {
				append form_args_str "[urlencode_unsafe -str $n]=[urlencode_unsafe -str $v]&"
			} else {
				append form_args_str "[urlencode $n]=[urlencode $v]&"
			}
		}
		set form_args_str [string trimright $form_args_str "&"]
	}

	if {$method == "GET" && $form_args_str != ""} {
		append ret "?$form_args_str"
	}

	# Version - for now only dealing with HTTP1.0 so that we don't have to
	# deal with keepalives and chunked encodings
	append ret " HTTP/${http_version}\r\n"

	# Host: Even though this is an HTTP1.1 header it can be useful to pass through
	# when going via a proxy server
	append ret "Host: $host\r\n"

	# Headers
	if {$headers != {}} {
		if {[llength $headers] % 2} {
			error "$usage\n\nheaders should be a list of name/value pairs"
		}
		foreach {n v} $headers {
			if {[string equal -nocase $n "Content-Type"]} {
				set content_type_specified 1
			}
			if {[string tolower $n] in $lbanned_header} {
				core::log::write ERROR {$fn: Header '$n' is banned - skipping}
			} else {
				append ret "$n: $v\r\n"
			}
		}
	}
		if {$http_version == "1.1"} {
			#  For HTTP 1.1 we need to signal that we are
			#  not using persistent connections
			append ret "Connection: close\r\n"
		}

	# Request data
	if {$method in [list "POST" "PUT" "PATCH"]} {
		if {!$content_type_specified} {
			# assume it's form data
			append ret "Content-Type: application/x-www-form-urlencoded\r\n"
		}
		# Not going to allow form data and other post data to be sent in the same request.
		# It would be a fair http thing to do to append the form args to the url with a
		# post request, I am however assuming that if the user is selecting the POST method
		# they may not want the arguments appearing in the web server logs and browser history.
		# If you really want to do this I would suggest rolling you own URL with the form
		# args already appended
		if {$post_data != "" && $form_args_str != ""} {
			error "$usage\n\nCannot have form data AND post data in request"
		}
		if {$post_data != ""} {
			set data $post_data
		} else {
			set data $form_args_str
		}

		if {$encoding == "binary"} {
			set content_length [string length $data]
		} else {
			set content_length [string length [encoding convertto $encoding $data]]
		}
		append ret "Content-Length: $content_length\r\n\r\n"
		append ret "$data"
	} else {
		append ret "\r\n"
	}
	return $ret
}

core::args::register \
	-proc_name core::socket::server_processed \
	-args [list \
		[list -arg -req_id -mand 1 -check UINT -desc {Request Identifier}] \
	]

# This procedure will return true (1) if the server MAY have had a chance to
# process the data.  It will return false (0) if the server DEFINITELY didn't/
# will not process any data if the request is complete or terminated at this point.
#
# A slight note of caution here - HTTP 4** errors are returned as not processed
# as the web server cannot process the business logic due to a client error in
# the request.
#
# @param -req_id Request identifier
proc core::socket::server_processed args {

	variable req_arr

	array set ARGS [core::args::check core::socket::server_processed {*}$args]

	set req_id $ARGS(-req_id)

	switch -- $req_arr($req_id,status) {
		"PRE_CONN"       -
		"CONN"           -
		"CONN_FAIL"      -
		"CONN_TIMEOUT"   -
		"HANDSHAKE"      -
		"HANDSHAKE_FAIL" -
		"HTTP_CLIENT_ERROR" {
			return 0
		} default {
			return 1
		}
	}
}


core::args::register \
	-proc_name core::socket::split_url \
	-args [list \
		[list -arg -url -mand 1 -check ANY -desc {Absolute URL}] \
	]

# Split an absolute URL for an IP-based protocol into its constituent parts.
#
# @param -url
#
#  "scheme://<user>:<password>@<host>:<port>/<url-path>"
#
#  (in which the parts "<user>:<password>@", ":<password>",
#   ":<port>", and "/<url-path>" are optional)
#
# @return  {scheme host port slash-urlpath username password}
#
# Notes:
#
# If the port is not explicitly specified in the URL, it will be set to the
# default scheme port if the scheme is http, https or ftp. For other schemes,
# the port will be blank if not explicitly specified in the URL.
#
# The user and password fields will be blank if not specified in the URL.
#
# Escape sequences (%xx) will be decoded ONLY within the username and password
# fields.
#
# The url-path (if any) will be returned unchanged, INCLUDING the leading
# slash which is not strictly part of the url-path.
#
# Will throw an error if the URL is invalid, not for an IP-based protocol,
# or is a relative URL.
#
# Examples:
#   split_url -url "http://www.sun.com/foo/bar" ->
#     [list http "www.sun.com" 80 "/foo/bar" "" ""]
#
#   split_url -url "https://bootes.orbis:4443" ->
#     [list https "bootes.orbis" 4443 "" "" ""]
#
#   split_url -url "ftp://foo:secret@127.0.0.1/README" ->
#     [list ftp "127.0.0.1" 21 "/README" "foo" "secret"]
#
# See Also:
#  RFC 1738 - http://www.ietf.org/rfc/rfc1738.txt
#
# Bugs:
#  - Slightly too lax about hostnames.
#  - Doesn't distinguish between no username/password and the empty
#    username/password.
#  - Doesn't validate characters in the url-path.
#
proc core::socket::split_url args {

	array set ARGS [core::args::check core::socket::split_url {*}$args]

	set url $ARGS(-url)

	set scheme   ""
	set host     ""
	set port     ""
	set urlpath  ""
	set user     ""
	set password ""

	if {[catch {
		foreach {scheme schemepart} [_consume_scheme $url] {}
		foreach {username password host port urlpath} \
			[_split_ip_scheme_part $schemepart] {}
	} msg]} {
		error "Could not split URL \"$url\": $msg"
	}

	if {$port == ""} {
		switch -exact -- $scheme {
			"ftp"    { set port 21 }
			"http"   { set port 80 }
			"https"  { set port 443 }
		}
	}

	return [list $scheme $host $port $urlpath $username $password]
}


# Internal - Read a scheme from a string, returning it and the
# remainder of the string. See split_url.
proc core::socket::_consume_scheme {s} {

	# genericurl     = scheme ":" schemepart
	# scheme         = 1*[ lowalpha | digit | "+" | "-" | "." ]

	set genericurl_re {(^[a-z0-9+\-.]+):(.*)$}

	if {![regexp -nocase $genericurl_re $s junk scheme schemepart]} {
		error "\"$s\" does not start with a valid scheme"
	}

	# the scheme is in lower case; interpreters should use case-ignore

	set scheme [string tolower $scheme]

	return [list $scheme $schemepart]
}

# Internal - Split an ip-schemepart into its constituent parts.
# Returns a list of the form:
#   [list username password host port slash-urlpath]
# See split_url.
proc core::socket::_split_ip_scheme_part {schemepart} {

	if {[string range $schemepart 0 1] != "//"} {
		error "schemepart \"$schemepart\" does not start with //"
	}

	set s [string range $schemepart 2 end]

	set username ""
	set password ""
	catch {
		foreach {username password s} [_consume_user_and_pass $s] {}
	}

	foreach {host port s} [_consume_hostport $s] {}

	if {[string length $s] && [string index $s 0] != "/"} {
		error "end of URL \"$s\" does not start with /"
	}

	return [list $username $password $host $port $s]
}


# Internal - Try to read a username and password from a string, returning them
# and the remainder of the string. See split_url. The username and
# password will have any escape characters expanded.
proc core::socket::_consume_user_and_pass {s} {

	set user_and_pass_re {(?x)
		^
		([A-Za-z0-9$\-_.+!*'(),%;?&=]*)
		(?:\:([A-Za-z0-9$\-_.+!*'(),%;?&=]*))?
		@
		(.*)
		$
	}

	if {![regexp $user_and_pass_re $s junk username password remainder]} {
		error "\"$s\" does not start with a valid username"
	}

	return [list \
		[_unescape_octets $username] \
		[_unescape_octets $password] $remainder]
}


# Internal - Replace any escapes of the form %XX (where XX is a pair of
# hexadecimal digits) within a string with the characters they represent.
# A bit like urldecode, but doesn't decode pluses into spaces for example.
proc core::socket::_unescape_octets {s} {

	set out ""
	set end_of_last_esc 0

	while {1} {

		set pc_pos [string first "%" $s $end_of_last_esc]

		if {$pc_pos < 0} {
			# No more escapes, copy the rest of the string and we're done.
			append out [string range $s $end_of_last_esc end]
			break
		}

		# Copy the string up to the escape.
		append out [string range $s $end_of_last_esc [expr {$pc_pos - 1}]]

		# Extract the escape and move our last escape marker.
		set escape [string range $s $pc_pos [expr {$pc_pos + 2}]]
		set end_of_last_esc [expr {$pc_pos + 3}]

		if {![regexp -nocase {^%[0-9A-F][0-9A-F]$} $escape]} {
			# The escape isn't valid - copy it verbatim.
			append out $escape
		} else {
			# Append the character indicated by the hex digits.
			set hex [string range $escape 1 end]
			scan $hex "%x" octet
			append out [format "%c" $octet]
		}

	}

	return $out
}

# Internal - Try to read a host and port from a string, returning them and the
# remainder of the string. See split_url. Port will be blank if not
# specified.
proc core::socket::_consume_hostport {s} {

	foreach {host remainder} [_consume_host $s] {}
	set port ""
	regexp {^:([0-9]+)(.*)$} $remainder junk port remainder

	return [list $host $port $remainder]
}

# Internal - Try to read a host from a string, returning it and the
# remainder of the string. See split_url.
proc core::socket::_consume_host {s} {

	# XXX The host grammar in the RFC is quite tricky to implement.
	# We'll use a weaker one - downside is that we will fail to spot
	# some invalid hostnames - e.g. "a.b.c.123", "1.2.3".

	set host_re {^([A-Za-z0-9\-._]*[A-Za-z0-9])(.*)$}

	if {![regexp $host_re $s junk host remainder]} {
		error "\"$s\" does not start with a valid hostname or hostnumber"
	}

	return [list $host $remainder]
}



#
# Initiates the connection
#
proc core::socket::_do_conn {req_id} {

	variable req_arr

	core::log::write DEBUG {core::socket::_do_conn called. $req_arr($req_id,label) req_id = $req_id $req_arr($req_id,host):$req_arr($req_id,port)}

	set req_arr($req_id,status)     "CONN"
	set req_arr($req_id,start_time) [_get_time]

	if {[catch {
		socket -async $req_arr($req_id,host) $req_arr($req_id,port)
	} sock]} {
		#Error probably due to unknown host or invalid port number
		core::log::write WARNING {::core::socket::_do_conn socket -async threw error $sock}

		if {$req_arr($req_id,async) == ""} {
			# we're synchronous so finish the req immediately
			_finish_req $req_id "CONN_FAIL" $sock
		} else {
			# we're asynchronous so arrange for the req to be finished shortly
			# (for consistency we want to return to the app in the same way as
			# we would if the req were to fail in some other way)
			after 0 [list ::core::socket::_finish_req $req_id "CONN_FAIL" $sock]
		}

		return 0
	}
	set req_arr($req_id,sock) $sock
	if {$req_arr($req_id,http_ver) == "1.1"} {
	#  For HTTP 1.0 we *need* to get the request as raw binary
	#  so we handle chunked encoding
		set sock_encoding    binary
		set sock_translation binary
	} else {
		#Explicitly deal with end of line chars if http.  For greater flexibility the client
		#should make sure that it is sending in an encoding that the server understands
		set sock_encoding    $req_arr($req_id,encoding)
		set sock_translation "lf"
	}
	fconfigure $sock \
		-blocking 0 \
		-buffering none \
		-encoding  $sock_encoding \
		-translation $sock_translation

	fileevent $sock writable [list ::core::socket::_check_conn $req_id]

	set req_arr($req_id,after_id)\
		[after $req_arr($req_id,conn_timeout) [list ::core::socket::_finish_req $req_id "CONN_TIMEOUT" ""]]

	core::log::write DEBUG {core::socket::_do_conn finished}

	return 1
}

#
# By this stage we have opened the socket asynchronously and triggered a writable fileevent
# This can mean one of two things:
# 1.  The connection is established
# 2.  The connection couldn't be esblished and the "writable" fileevent indicates an
#     error on the socket
# We can check this by attempting to read from the socket.  If ESTABLISHED read should return
# straight away (non blocking socket) having read 0 bytes.  Otherwise it should throw an error
#
proc core::socket::_check_conn {req_id} {

	variable req_arr

	core::log::write DEBUG {core::socket::_check_conn called.  req_id = $req_id}

	set sock $req_arr($req_id,sock)

	if {[catch {read $sock} msg]} {
		core::log::write ERROR {core::socket::_error reading. error was: $msg}
		_finish_req $req_id "CONN_FAIL" $msg
		return
	}

	if {$req_arr($req_id,tls) == "0"} {
		fileevent $sock writable [list ::core::socket::_do_send $req_id]
	} else {
		# Our socket was configured in _do_conn based on the flags passed
		# by the callee, tls::import doesn't maintain this state so capture
		# now to ensure we honour these parameters.
		foreach i [list blocking buffering translation encoding] {
			set sock_state($i) [fconfigure $sock -$i]
			core::log::write DEBUG {core::socket::_check_conn: captured $i as $sock_state($i)}
		}

		# let tls handle the socket
		eval tls::import $sock $req_arr($req_id,tls_args)

		# Re-apply socket state - encoding post translation to ensure
		# any flag is truely honoured (translation binary will blat any
		# previous encoding setting)
		foreach i [list blocking buffering translation encoding] {
			fconfigure $sock -$i $sock_state($i)
			core::log::write DEBUG {core::socket::_check_conn: reset $i as $sock_state($i)}
		}

		fileevent $sock writable [list ::core::socket::_do_handshake $req_id]
	}

	core::log::write DEBUG {core::socket::_check_conn finished}
}

#
# Initiates the ssl handshake.  (Request specified with -tls flag)
#
# We explicitly start the handshake due to a bug in tls/tcl when using
# non blocking sockets.
# If not started explicitly tls will attempt to negotiate the handshake
# when you first send anything to the socket.  Now this will normally
# write the initial request without problems but block on the read.  As
# this is a nonblocking socket the kernel gives a EWOULDBLOCK error and
# tcl sets up an implicit WRITABLE fileevent as we initiated the call
# by writing to the socket.  Hence when we go back into the vwait loop
# select returns straight away due to the writable file event
# (the socket is writable after all) but we are attempting to do a READ
# Hence this will spin on the select until the socket is readable.
#
proc core::socket::_do_handshake {req_id} {

	variable req_arr

	core::log::write DEBUG {core::socket::_do_handshake called.  req_id = $req_id}

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) "HANDSHAKE"

	#remove writable filevent
	_tidy_req $req_id 0

	if {[catch {tls::handshake $sock} hshake_status]} {
		if {[lindex $::errorCode 1] == "EAGAIN"} {
			#this error is fine it just indicates that we should call the
			#tls::handshake command again. Leave the readable filevent
			#open
			core::log::write DEBUG {tls::handshake threw EAGAIN error: $hshake_status}
			fileevent $sock readable [list ::core::socket::_do_handshake $req_id]
		} else {
			_finish_req $req_id "HANDSHAKE_FAIL" $hshake_status
		}
		return
	}

	if {$hshake_status == "1"} {

		if {![core::socket::_validate_certificate_to_host $req_id]} {
			_finish_req $req_id {CERT_HOST_MISMATCH} {Failed to match certificate subject to hostname}
			return
		}

		_do_send $req_id
	} else {
		core::log::write DEBUG {tls::handshake returned 0. Going back into vwait loop}
		fileevent $sock readable [list ::core::socket::_do_handshake $req_id]
		#_finish_req $req_id "HANDSHAKE_FAIL" "tls::handshake returned 0"
	}

	core::log::write DEBUG {core::socket::_do_handshake finished}
}

proc core::socket::_validate_certificate_to_host req_id {
	variable req_arr

	if {$req_arr($req_id,verify_host) == {}} {
		return 1
	}

	set sock $req_arr($req_id,sock)
	set host $req_arr($req_id,verify_host)

	set parsed_dn [core::util::parse_dn_string \
		-dn_string [dict get [tls::status $sock] subject]]

	set cn_elements [list]

	foreach rdn_index [dict keys $parsed_dn] {
		foreach cn [dict keys [dict get $parsed_dn $rdn_index] {[Cc][Nn]}] {
			# create the regexp to match
			set cn_value [dict get $parsed_dn $rdn_index $cn]
			set reg_exp [string map {. {\.} * [^\\.\]+} $cn_value]

			# Try and match to the hostname
			if {[regexp -nocase -- ^$reg_exp\$ $host]} {
				return 1
			}
		}
	}

	# No CNs have matched the hostname
	return 0
}



#
# Send the request data to the socket
#
# We do our own buffering here due to tcl bug
# We should be able to do the following:
# set sock -async $host $port
# fconfigure $sock -blocking 0 -buffering full
#
# ... check connection esablished
#
# fileevent $sock writable do_write
# set req "*"
# for {set i 0} {$i < 1000000} {incr i} {
#     append req *
# }
# puts $sock $req
# flush $sock
# after $timeout do_timeout
#
# ...
#
# proc timeout args {
#  fileevent $sock writable {}
#  ...
# }
#
# However if there is ?much? data in the buffers it seems to be impossible to remove
# the writable fileevent.  Without removing this or processing the data, [close] will
# not close the socket and tcl will change the socket to blocking on [exit] or script
# end.  This will cause the script to hang.
#
#
proc core::socket::_do_send {req_id} {

	variable req_arr
	variable CFG

	core::log::write DEBUG {core::socket::_do_send called.  req_id = $req_id}

	set sock $req_arr($req_id,sock)
	set ::core::socket::req_arr($req_id,status) "SEND"

	# Connection successful remove conn timeout and add req timeout
	if {$req_arr($req_id,write_pointer) == 0} {
		set req_arr($req_id,req_start_time) [_get_time]
		_tidy_req $req_id 1
		set req_arr($req_id,after_id)\
			[after $req_arr($req_id,req_timeout) [list ::core::socket::_finish_req $req_id "REQ_TIMEOUT" ""]]
		fileevent $sock writable [list ::core::socket::_do_send $req_id]
	}

	#implement our own buffering so that we can successfully close the socket
	#when we can no longer write to it
	set curr_pos $req_arr($req_id,write_pointer)
	set req_length [string length $req_arr($req_id,req)]

	if {$curr_pos >= $req_length} {
		#finished writing
		_tidy_req $req_id 0
		fileevent $sock readable [list ::core::socket::_do_read $req_id]
	}

	set end_pos  [expr {$curr_pos + $CFG(write_buffer) - 1}]
	if {[catch {
		puts -nonewline $sock [string range $req_arr($req_id,req) $curr_pos $end_pos]
	} msg]} {
		_finish_req $req_id "SEND_FAIL" $msg
		return
	}

	incr req_arr($req_id,write_pointer) $CFG(write_buffer)

	core::log::write DEBUG {core::socket::_do_send finished}
}

#
# Read the response from the server
#
proc core::socket::_do_read {req_id} {

	variable req_arr

	core::log::write DEBUG {core::socket::_do_read called.  req_id = $req_id}

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) "READ"

	if {[eof $sock]} {
		_finish_req $req_id "OK" ""
		return
	}

	_tidy_req $req_id 0
	fileevent $sock readable [list ::core::socket::_do_read $req_id]
	if {[catch {read $req_arr($req_id,sock)} ret]} {
		_finish_req $req_id "READ_FAIL" $ret
		return
	}

	core::log::write DEBUG {::core::socket::_do_read [string length $ret] read}
	append req_arr($req_id,response) $ret

	core::log::write DEBUG {core::socket::_do_read finished}
}

#
# Remove fileevents and timeout from the event list.
#
# Sometimes efficiency is sacrificed in favour of making sure that we
# never leave unwanted fileevents on a socket.  ie:  Sometimes a f-event
# will be removed and put straight back on again; sometimes we may try
# removing it from a closed socket.  These operations are not costly, whereas
# leaving an unwanted fileevent on the socket may spin the CPU when the
# applications goes into the vwait loop.
#
proc core::socket::_tidy_req {req_id remove_timeout} {

	variable req_arr

	core::log::write DEBUG {core::socket::_tidy_req called. req_id = $req_id remove_timeout = $remove_timeout}

	set sock $req_arr($req_id,sock)

	if {[catch {fileevent $sock writable {}} msg]} {
		core::log::write DEBUG {Unable to remove writable fileevent $msg}
	}
	if {[catch {fileevent $sock readable {}} msg]} {
		core::log::write DEBUG {Unable to remove readable fileevent $msg}
	}
	if {$remove_timeout} {
		catch {after cancel $req_arr($req_id,after_id)}
		set req_arr($req_id,after_id) ""
	}

	core::log::write DEBUG {core::socket::_tidy_req finished}
}

#
# Called both when the request has been successful and on error too.
#
proc core::socket::_finish_req {req_id status msg {complete 1}} {

	variable num_requests_complete
	variable req_arr
	variable set_status

	core::log::write DEBUG {core::socket::_finish_req called. req_id = $req_id, status = $status, msg = $msg}

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) $status
	set req_arr($req_id,complete) $complete

	_tidy_req $req_id 1
	if {[catch {close $sock} msg]} {
		core::log::write ERROR {core::socket: Error closing socket '$msg' - carrying on regardless}
	} else {
		core::log::write DEBUG {core::socket:: $req_arr($req_id,host) Socket closed}
	}

	set req_arr($req_id,end_time) [_get_time]
	switch -- $status {
		"PRE_CONN" {
			core::log::write INFO {::core::socket:: $req_arr($req_id,label) Connection Interrupted - not attempted}
		}
		"CONN" -
		"CONN_FAIL" -
		"CONN_TIMEOUT" -
		"HANDSHAKE" -
		"HANDSHAKE_FAIL" -
		"CERT_HOST_MISMATCH" {
			set conn_time [_diff_time $req_arr($req_id,start_time) $req_arr($req_id,end_time)]
			core::log::write INFO {::core::socket:: $req_arr($req_id,label): Conn Time: $conn_time Status: $status}
		}
		default {
			set conn_time [_diff_time $req_arr($req_id,start_time) $req_arr($req_id,req_start_time)]
			set req_time [_diff_time $req_arr($req_id,req_start_time) $req_arr($req_id,end_time)]
			core::log::write INFO {::core::socket:: $req_arr($req_id,label): Conn Time: $conn_time Req Time: $req_time Status: $status}
		}
	}

	#If we indicate this is an http request, parse the response
	if {$status == "OK" && $req_arr($req_id,is_http)} {
		_parse_http_response $req_id
	}

	if {$set_status} {
		set appserv_status $req_arr($req_id,appserv_status)
	}

	if {$req_arr($req_id,async) == ""} {
		incr num_requests_complete
	} elseif {$complete == 1} {
		$req_arr($req_id,async)\
			$req_id\
			$req_arr($req_id,status)\
			$msg\
			$req_arr($req_id,client_data)
	}

	if {$set_status} {
		asSetStatus $appserv_status
	}

	core::log::write DEBUG {core::socket::_finish_req finished}
}

#
# Go through response from the server and parse it as http.
# In all likelyhood the header part of the response should be small
# whereas the data part could be huge.  Hence the most efficient way
# of parsing it would be to parse it "in place".  Couldn't think
# how to do this so if anyone wants to make it more efficient: feel free...
#
proc core::socket::_parse_http_response {req_id} {

	variable req_arr

	set start 0
	set end [string first "\n" $req_arr($req_id,response)]
	set status_str [string range $req_arr($req_id,response) 0 [expr {$end - 1}]]
	# Line breaks should be \r\n in http
	set status_str [string trimright $status_str "\r"]

	# Should have the form HTTP/[HTTP_VERSION] [HTTP_STATUS] [HTTP_STATUS_DESC]
	set status_re {^HTTP/\S+\s([0-9]+)\s}
	if {![regexp $status_re $status_str all status]} {
		core::log::write WARNING {core::socket::_parse_http_response: Invalid HTTP header: $status_str}
		set req_arr($req_id,status) "HTTP_INVALID"
		return
	}

	# Parse the headers these should have the form HEADER: VALUE
	set header_re {([^:\s]+):\s*(.*)$}
	# HTTP headers can stretch across multiple lines if the next line starts
	# with any number of space, tab characters
	set header_cont_re {\s*(.*)$}
	set headers        [list]
	set body_start     0
	set start          [expr {$end + 1}]

	#Iterate through the response to read the headers
	set curr_header_name ""
	set curr_header_val  ""

	while {1} {
		set end [string first "\n" $req_arr($req_id,response) $start]

		if {$end == -1} {
			core::log::write WARNING {::core::socket::_parse_http_response req_id = $req_id. No body data}
			break
		}
		incr end -1
		set header [string range $req_arr($req_id,response) $start $end]
		set header [string trimright $header "\r"]
		if {$header == ""} {
			#This blank line indicates the start of the body
			set body_start [expr {$end + 2}]
			#add the current header
			if {$curr_header_name != ""} {
				lappend headers $curr_header_name $curr_header_val
			}
			break
		}
		if {[regexp $header_re $header all n v]} {
			# New header
			if {$curr_header_name != ""} {
				lappend headers $curr_header_name $curr_header_val
			}
			set curr_header_name $n
			set curr_header_val  $v
		} elseif {[regexp $header_cont_re $header all v] && $curr_header_name != ""} {
			# Continuation of current header
			append curr_header_val " $v"
		} else {
			core::log::write WARNING {core::socket::_parse_http_response: Invalid HTTP header: $header}
			set req_arr($req_id,status) "HTTP_INVALID"
			return
		}
		set start [expr {$end + 2}]
	}

	#check the status code
	switch -- [expr {$status / 100}] {
		1 {set req_arr($req_id,status) "HTTP_INFORMATION_REQ"}
		2 {set req_arr($req_id,status) "OK"}
		3 {set req_arr($req_id,status) "HTTP_REDIRECT"}
		4 {set req_arr($req_id,status) "HTTP_CLIENT_ERROR"}
		5 {set req_arr($req_id,status) "HTTP_SERVER_ERROR"}
		default {
			set req_arr($req_id,status) "HTTP_UNKNOWN_STATUS"
		}
	}

	set req_arr($req_id,http_headers)    $headers
	set req_arr($req_id,http_body_start) $body_start
	set req_arr($req_id,http_status)     $status
	set req_arr($req_id,http_status_str) $status_str

	# For http 1.1 ONLY we decode the response here
	if {$req_arr($req_id,http_ver) == "1.1"} {
		core::log::write DEBUG {::core::socket::_parse_http_response req_id = $req_id. Decoding HTTP 1.1}
		lassign [_get_http_body $req_id] decode_status http_body
		core::log::write DEBUG {::core::socket::_parse_http_response req_id = $req_id. _get_http_body returned $decode_status}
		if {$decode_status != "OK"} {
			set req_arr($req_id,status)     $decode_status
			set http_body  {}
		}
		set req_arr($req_id,http_body) $http_body
	}

}

#
#  Proc that parses the response from the
#  Only used for http 1.1 (currently)
#
# returns [list "OK" resp]
#
# where resp is in TCL native unicode
#
# or
# [list <err_code?> msg
#
proc core::socket::_get_http_body {req_id} {
	variable req_arr
	set fn {core::socket::_get_http_body}

	#   We are only interested in some headers
	#   but need them case-insensitive

	set dheader [dict create \
		connection           {}  \
		content-length       {}  \
		content-encoding     {}  \
		transfer-encoding    {}]

	foreach {n v} $req_arr($req_id,http_headers) {
		 set n [string tolower $n]
		 set v [string tolower $v]
		if {[dict exists $dheader $n]} {
			dict set dheader $n $v
		}
	}

	set transfer_encoding [dict get $dheader transfer-encoding]
	set content_length    [dict get $dheader content-length]


	core::log::write INFO {$fn: $dheader}
	set status {}
	set http_body   {}
	set body_start   $req_arr($req_id,http_body_start)
	set response     $req_arr($req_id,response)
	set encoding     $req_arr($req_id,encoding)

	switch -- $transfer_encoding {
		chunked {
			lassign [_get_chunked_body $req_id $dheader] status http_body
			if {$status != "OK"} {
				#  TODO this should be on the request
				#  but now do it here
				return [list $status $http_body]
			}
		}
		default {
			# This should be handled as 'identity', which is the only other value.
			if {$body_start > 0} {
				set http_body [string range $response $body_start end]

				if {[string is integer -strict $content_length]} {
					set http_body_len [string length $http_body]
					if {$content_length == 0} {
						set http_body {}
					} elseif {$content_length < $http_body_len} {
						# Truncate the response to the content length
						# in case sever sends extra stuff on the socket
						core::log::write INFO {$fn: Received extra bytes - $http_body_len, truncating to content-length $content_length}
						set http_body [string range $http_body 0 [expr {$content_length - 1}]]
					} elseif {$content_length > $http_body_len} {
						#  Hmm - we haven't received the full response as per the Content-Length
						core::log::write ERROR {$fn: Expecting Content-Length $content_length, but only recieved $http_body_len}
						return [list HTTP_BAD_RESP_LENGTH "Expecting Content-Length $content_length, but only recieved $http_body_len"]
					}
				}
			}
		}
	}

	#  Convert to encoding
	#
	#  Note if we are http 1.1 we should be binary encoding here

	if {$encoding != "binary"} {
		set raw_len [string length $http_body]
		set http_body [encoding convertfrom $encoding $http_body]
		set tclnative_len [string length $http_body]
		core::log::write INFO {$fn: Converted response to $encoding, length $raw_len -> $tclnative_len}
	}
	return [list OK $http_body]
}

#  Parses a chunked socket
#  Returns binary response
proc core::socket::_get_chunked_body {req_id dheader} {
	set fn {core::socket::_get_chunked_body}
	variable req_arr

	set response    $req_arr($req_id,response)
	set response_len [string length $response]

	set status        {}
	set http_body     {}

	set pos         $req_arr($req_id,http_body_start)
	set err ""

	#  See http://en.wikipedia.org/wiki/Chunked_transfer_encoding
	#  for a good explanation of the spec
	#  Note we need the socket to be in binary mode
	#  so that the chunk lengths are preserved.
	set lchunk [list]
	while {true} {
		core::log::write DEV {$fn: At position $pos}
		if {$pos >= $response_len} {
			set err "Premature end of chunked encoding at pos $pos"
			break
		}


		#  Check for the chunk line
		#  ^start of line, hex chars, some optional chars, CRLF
		#
		if {![regexp -start $pos -- {\A([[:xdigit:]]+)([^\n\r]*)\r\n} $response chunk_line chunk_hex chunk_extra]} {
			core::log::write ERROR {$fn: Cannot find chunk header at [string range $response $pos [expr {$pos + 20}]]}
			set err "Cannot find chunked header at $pos"
			break
		}

		incr pos [string length $chunk_line]
		if {![scan $chunk_hex {%x} chunk_len]} {
			set err "Unable to parse hex of $chunk_hex"
			break
		}
		core::log::write DEV {$fn: Chunk length $chunk_len, hex $chunk_hex, extra '$chunk_extra'}

		#  Point to the end of the chunk
		set chunk_end_pos [expr {$pos + $chunk_len - 1}]
		#  Note chunks have a CRLF after them which is not factored into the
		#  chunk length. First check the length
		if {$chunk_end_pos + 2 >= $response_len} {
			set err "Chunk length $chunk_len extends beyond length of response $response_len"
			break
		}
		set chunk [string range $response $pos $chunk_end_pos]
		#  Move pointer to byte after the end of the chunk,
		#  which should point to \r\n
		set pos [expr {$chunk_end_pos + 1}]

		#  And check for trailing \r\n
		set chunk_end_str [string range $response $pos [expr {$pos + 1}]]
		if {$chunk_end_str ne "\r\n"} {
			set err "Failed to find trailing CRLF at pos $pos '$chunk_end_str' "
			break
		}
		#  If we got this far without error all is well

		#  Empty chunk means end of response
		#  Drop out of loop
		if {$chunk_len == 0} {
			core::log::write DEV {$fn: Got empty chunk - finishing up}
			break
		}
		#  OK - we have a good chunk
		lappend lchunk $chunk_len
		append http_body $chunk

		#  Move pointer past \r\n, to point to start of next chunk line
		incr pos 2


	}
	set http_body_len [string length $http_body]

	if {$err != ""} {
		core::log::write ERROR {$fn: Error in chunking - $err}
		core::log::write ERROR {$fn: Already Received $http_body_len bytes, in [llength $lchunk] chunks of sizes : $lchunk}
		return [list HTTP_BAD_RESP_CHUNK $err]
	}

	core::log::write INFO {$fn: Received $http_body_len bytes, in [llength $lchunk] chunks of sizes : $lchunk}
	return [list OK $http_body]

}

#
# OT_MicroTime occasionally throws an error - retry on failure
# tcl8.5 has clock milliseconds if we ever get that far
#
proc core::socket::_get_time {} {

	for {set i 0} {$i < 3} {incr i} {
		if {[catch {set ret [OT_MicroTime]} msg]} {
			core::log::write WARNING {core::socket::_get_time: OT_MicroTime failed: $msg}
		} else {
			return $ret
		}
	}
	return -1
}

#
# Allows for OT_MicroTime errors
#
proc core::socket::_diff_time {time_a time_b} {

	if {$time_a == -1 || $time_b == -1} {
		return "ERR"
	} else {
		return [format "%0.3f" [expr {$time_b - $time_a}]]
	}
}


# Url encode only the reserved/unsafe characters (rather than all chars that
# aren't in the range A-Z,a-z,0-9,_ as is done by appserv urlencode)
#
#    str - the string to encode
#
#    returns - the urlencoded string
#
proc core::socket::_urlencode_unsafe {str} {

	set encode ""

	for {set i 0} {$i<[string length $str]} {incr i} {
		set char [string range $str $i $i]

		if {[string match {[^a-zA-Z0-9$_.!*'(),-]} $char]} {
			append encode $char
		} elseif {$char == " "} {
			append encode "+"
		} else {
			binary scan $char H2 charval
			append encode "%$charval"
		}
	}

	return $encode
}
