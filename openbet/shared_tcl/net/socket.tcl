# ============================================================================
#
# $Id: socket.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# ============================================================================
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

# Either use all asynchronous requests or all synchronous. In particular the
# synchronous call assumes that there is only one send_req call in the system
# at one time (assuming no other process would change a package variable during
# the request); Hence, the following code would be disasterous:
# after 1000 [::ob_sock::send_req $req1 $server1 $port1]
# after 1000 [::ob_sock::send_req $req2 $server2 $port2]
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
# OK:                   Success.  if -is_http flag is set, indicates a 2** status code
#
# Example usage:
# ==============
#
# Run from the command line:
# --------------------------
#
# ::ob_sock::configure -log_proc STDOUT
#
# Send a simple request /response:
# --------------------------------
#
# foreach {req_id status complete} [::ob_sock::send_req "My Request String" $MYSERVER $MYPORT] {break}
# if {$status == "OK"} {
#     process_response [::ob_sock::req_info $req_id response]
# }
# ::ob_sock::clear_req $req_id
#
# Send a simple http request:
# ---------------------------
#
# set host "www.apple.com"
# set req [::ob_sock::format_http_req -host $host -method "GET" "/"]
# foreach {req_id status complete} [::ob_sock::send_req -is_http 1 $req $host 80] {break}
# if {$status == "OK"} {
#     puts [::ob_sock::req_info $req_id http_body]
# }
# ::ob_sock::clear_req $req_id
#
# Send request over SSL:
# ----------------------
#
# set host "www.apple.com"
# set req [::ob_sock::format_http_req -host $host -method "GET" "/"]
# foreach {req_id status complete} [::ob_sock::send_req -tls {} -is_http 1 $req $host 443] {break}
# if {$status == "OK"} {
#     puts [::ob_sock::req_info $req_id http_body]
# }
# ::ob_sock::clear_req $req_id
#
# Login to a site and resend the login cookie in the next request
# ---------------------------------------------------------------
#
# set host "myhost.com"
# set form_args [list "username" "joe" "password" "shmoe"]
# set req [::ob_sock::format_http_req -host $host -form_args $form_args "/app/do_login"]
# foreach {req_id status complete} [::ob_sock::send_req -tls {} -is_http 1 $req $host 443] {break}
#
# if {$status == "OK"} {
#     set cookie [::ob_sock::req_info $req_id http_header Set-Cookie]
#     if {$cookie != ""} {
#         set headers [list Cookie $cookie]
#     } else {
#         set headers [list]
#     }
#     set req [::ob_sock::format_http_req -host $host -headers $header "/app/next_page"]
#     ::ob_sock::clear_req $req_id
# } else {
#     ::ob_sock::clear_req $req_id
#     return
# }
#
# foreach {req_id status complete} [::ob_sock::send_req -is_http 1 $req $host 80] {break}
#
# if {$status == "OK"} {
#     puts [::ob_sock::req_info $req_id http_body]
# }
# ::ob_sock::clear_req $req_id
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
#     ::ob_sock::clear_req $req_id
#     incr ::num_oustanding -1
#     if {$::num_oustanding == 0} {
#         set ::g_vwait "COMPLETE"
#     }
# }
#
# set host1 "www.microsoft.com"
# set req1 [::ob_sock::format_http_req -host $host1 -method "GET" "/"]
# ::ob_sock::send_req -async "req_callback" -client_data "Microsoft" -is_http 1 $req1 $host1 80
# incr num_oustanding
#
# set host2 "www.apple.com"
# set req2 [::ob_sock::format_http_req -host $host2 -method "GET" "/"]
# ::ob_sock::send_req -async "req_callback" -client_data "Apple" -is_http 1 $req2 $host2 80
# incr num_oustanding
#
# set host3 "www.slashdot.org"
# set req3 [::ob_sock::format_http_req -host $host3 -method "GET" "/"]
# ::ob_sock::send_req -async "req_callback" -client_data "Slashdot" -is_http 1 $req3 $host3 80
# incr num_oustanding
#
# vwait g_vwait
#
# On error check to see if the server has process the request:
# ------------------------------------------------------------
#
# foreach {req_id status complete} [::ob_sock::send_req "My Request String" $MYSERVER $MYPORT] {break}
# if {$status == "OK"} {
#     process_response [::ob_sock::req_info $req_id response]
# } else {
#     if {[::ob_sock::server_processed $req_id]} {
#         set_pmt "UNKNOWN"
#     } else {
#         set pmt "BAD"
#     }
# }
# ::ob_sock::clear_req $req_id
#
# TODO:
# =====
#
# deal with transport and content encodings
# Transfer-Encodings:
#
#  chunked       Transfer in a series of chunks                     [RFC2616] (section 3.6.1)
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

package provide net_socket 4.5

package require util_log 4.5

namespace eval ob_socket {

	package require tls

	namespace export configure
	namespace export send_req
	namespace export clear_req
	namespace export req_info
	namespace export format_http_req
	namespace export server_processed

	variable default_encoding          binary
	variable default_conn_timeout      10000
	variable default_req_timeout       10000
	variable num_requests              0
	variable reqs_processed            0
	variable write_buffer              4096
	variable log_proc                  "ob_log::write"
	variable log_level                 3
	variable log_numeric_error_level   1
	variable log_numeric_warning_level 2
	variable log_numeric_info_level    3
	variable log_numeric_debug_level   10
	variable log_numeric_dev_level     50
	variable num_requests_complete	   0
	variable req_arr
	array set req_arr [list]

	# Does the application server support setting/getting its status string?
	variable get_status [string equal [info commands asGetStatus] asGetStatus]
	variable set_status [string equal [info commands asSetStatus] asSetStatus]
}

#
# Configure the package across all future requests
# For further details see _usage_configure
#
proc ::ob_socket::configure args {

	variable default_encoding
	variable default_conn_timeout
	variable default_req_timeout
	variable write_buffer
	variable log_proc
	variable log_level
	variable log_numeric_error_level
	variable log_numeric_warning_level
	variable log_numeric_info_level
	variable log_numeric_debug_level
	variable log_numeric_dev_level

	if {[llength $args] % 2} {
		error "[_usage_configure]"
	}
	foreach {n v} $args {
		switch -- $n {
			"-default_encoding"          {set default_encoding $v}
			"-default_conn_timeout"      {set default_conn_timeout $v}
			"-default_req_timeout"       {set default_req_timeout $v}
			"-write_buffer"              {set write_buffer $v}
			"-log_proc"                  {set log_proc $v}
			"-log_level"                 {set log_level $v}
			"-log_numeric_error_level"   {set log_numeric_error_level $v}
			"-log_numeric_warning_level" {set log_numeric_warning_level $v}
			"-log_numeric_info_level"    {set log_numeric_info_level $v}
			"-log_numeric_debug_level"   {set log_numeric_debug_level $v}
			"-log_numeric_dev_level"     {set log_numeric_dev_level $v}
			default {error "[_usage_configure]\n\nUnknown param $n"}
		}
	}
}

#
# Start the process of sending the request.  If the -async flag is set
# the request is started when the application enters the vwait loop
# For further details see _usage_send_req below
#
proc ::ob_socket::send_req args {

	variable num_requests
	variable req_arr
	variable default_conn_timeout
	variable default_req_timeout
	variable default_encoding
	variable get_status
	variable set_status

	_log INFO "ob_socket::send_req called"

	#parse args
	if {[llength $args] < 3} {
		error "[_usage_send_req]"
	}

	#Required fields
	set req  [lindex $args end-2]
	set host [lindex $args end-1]
	set port [lindex $args end]

	#Optional fields
	set tls  "-1"
	set client_data ""
	set conn_timeout $default_conn_timeout
	set req_timeout  $default_req_timeout
	set async ""
	set is_http 0
	set encoding $default_encoding

	set opt_args [lrange $args 0 end-3]

	if {[llength $opt_args] % 2} {
		error "[_usage_send_req]"
	}

	foreach {n v} $opt_args {
		switch -- $n {
			"-conn_timeout" {set conn_timeout $v}
			"-req_timeout"  {set req_timeout $v}
			"-tls"          {set tls $v}
			"-async"        {set async $v}
			"-client_data"  {set client_data $v}
			"-is_http"      {set is_http $v}
			"-encoding"     {set encoding $v}
			default {
				error "[_usage_send_req]\n\nUnknown param $n"
			}
		}
	}
	if {$req == ""} {
		error "[_usage_send_req]\n\nNo request."
	}
	if {$host == ""} {
		error "[_usage_send_req]\n\nNo host."
	}
	if {$port == ""} {
		error "[_usage_send_req]\n\nNo port."
	}

	#add the request object
	set req_id $num_requests
	set req_arr($req_id,req) $req
	set req_arr($req_id,host) $host
	set req_arr($req_id,port) $port
	set req_arr($req_id,tls) $tls
	set req_arr($req_id,conn_timeout) $conn_timeout
	set req_arr($req_id,req_timeout) $req_timeout
	set req_arr($req_id,async) $async
	set req_arr($req_id,client_data) $client_data
	set req_arr($req_id,is_http) $is_http
	set req_arr($req_id,encoding) $encoding
	set req_arr($req_id,status) "PRE_CONN"
	set req_arr($req_id,sock) ""
	set req_arr($req_id,after_id) ""
	set req_arr($req_id,response) ""
	set req_arr($req_id,write_pointer) 0
	set req_arr($req_id,http_status)  ""
	set req_arr($req_id,http_headers) [list]
	set req_arr($req_id,http_body_start) 0
	set req_arr($req_id,complete) 0

	incr num_requests
	if {$get_status} {
		set req_arr($req_id,appserv_status) [asGetStatus]
	} else {
		set req_arr($req_id,appserv_status) ""
	}

	if {$set_status} {
		asSetStatus "net: [clock format [clock seconds] -format "%T"] - $host:$port"
	}

	#start the request
	_log INFO "ob_socket::send_req host $host port $port req $req_id"
	set ret [_do_conn $req_id]

	if {$ret != 0 && $req_arr($req_id,async) == ""} {
		_log DEBUG "ob_socket::send_req synchronous call.  Entering vwait loop"
		vwait ::ob_socket::reqs_processed
	} else {
		_log DEBUG "ob_socket::send_req asynchronous call. Not going into vwait."
	}

	_log DEBUG "ob_socket::send_req finished"

	return [list $req_id $req_arr($req_id,status) $req_arr($req_id,complete)]
}

#
# Free the memory associated with the request.  Incomplete requests can
# also be deleted
#
proc ::ob_socket::clear_req {req_id} {

	variable req_arr
	variable num_requests

	_log INFO "ob_socket::clear_req called.  req_id = $req_id"

	if {![info exists req_arr($req_id,sock)]} {
		# req_id doesn't exist.  If it was a previous req assume closed previously
		# and continue.  Otherwise something's a bit wrong: throw an error
		if {$req_id < $num_requests} {
			return
		} else {
			_log ERROR "::ob_socket::clear_req trying to clear non-existent request $req_id"
			error "::ob_socket::clear_req Unknown req $req_id"
		}
	}

	if {$req_arr($req_id,complete) == 1} {
		#Request completed normally
		_tidy_req $req_id 1
	} else {
		#Request in progress
		_log WARNING "::ob_socket::clear_req Removing request before completion $req_id"
		_finish_req $req_id $req_arr($req_id,status) "interupted"
	}

	foreach f {
		req host port tls conn_timeout req_timeout
		async client_data is_http status sock after_id
		response write_pointer http_status http_headers
		http_body_start complete encoding
	} {
		catch {unset req_arr($req_id,$f)}
	}

	_log DEBUG "ob_socket::clear_req finished"
}

#
# Details of the request
# For further details see _usage_req_info below
#
proc ::ob_socket::req_info {req_id item {sub_item ""}} {

	variable req_arr

	switch -- $item {
		"host"         -
		"port"         -
		"tls"          -
		"conn_timeout" -
		"req_timeout"  -
		"async"        -
		"client_data"  -
		"is_http"      -
		"status"       -
		"response"     -
		"complete"     -
		"http_headers" -
		"http_status"  - 
		"start_time"   -
		"req_start_time" {
			return $req_arr($req_id,$item)
		}
		"http_body"    {
			set body_start $req_arr($req_id,http_body_start)
			if {$body_start == 0} {
				return ""
			} else {
				return [string range $req_arr($req_id,response) $body_start end]
			}
		}
		"http_header"  {
			#Headers stored as list rather than hash as we never expect many of them
			if {$sub_item == ""} {
				error "[_usage_req_info]\n\nSpecify sub_item for http_header."
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
			error "[_usage_req_info]\n\nUnknown item $item"
		}
	}
}

#
# Formats an http request
# For further information see _usage_format_http_req below
#
proc ::ob_socket::format_http_req args {

	variable default_encoding

	#parse args
	if {[llength $args] < 1} {
		error "[_usage_format_http_req]"
	}

	#Required fields
	set url [lindex $args end]

	#Optional fields
	set host ""
	set port ""
	set form_args [list]
	set form_args_str ""
	set http_version "1.0"
	set method "POST"
	set headers [list]
	set form_args [list]
	set form_args_str ""
	set post_data ""
	set encoding $default_encoding
	set urlencode_unsafe 0

	set opt_args [lrange $args 0 end-1]

	if {[llength $opt_args] % 2} {
		error "[_usage_format_http_req]"
	}

	foreach {n v} $opt_args {
		switch -- $n {
			"-method"            {set method $v}
			"-host"              {set host $v}
			"-port"              {set port $v}
			"-form_args"         {set form_args $v}
			"-headers"           {set headers $v}
			"-post_data"         {set post_data $v}
			"-encoding"          {set encoding $v}
			"-urlencode_unsafe"  {set urlencode_unsafe $v}
			default {
				error "[_usage_format_http_req]\n\nUnknown param $n"
			}
		}
	}

	if {$port != ""} {
		 append host ":" $port
	}

	set ret ""
	set content_type_specified 0

	#the method
	if {$method != "POST" && $method != "GET"} {
		error "[_usage_format_http_req]\n\nUnknown method $method"
	}
	append ret "$method "

	#url
	if {$url == ""} {
		error "[_usage_format_http_req]\n\nNo URL"
	}
	append ret "$url"

	#form args
	if {$form_args != {}} {
		if {[llength $form_args] % 2} {
			error "[_usage_format_http_req]\n\nform_args should be a list of name/value pairs"
		}
		foreach {n v} $form_args {
			if {$urlencode_unsafe} {
				append form_args_str "[urlencode_unsafe $n]=[urlencode_unsafe $v]&"
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
			error "[_usage_format_http_req]\n\nheaders should be a list of name/value pairs"
		}
		foreach {n v} $headers {
			if {[string equal -nocase $n "Content-Type"]} {
				set content_type_specified 1
			}
			append ret "$n: $v\r\n"
		}
	}

	#request data
	if {$method == "POST"} {
		if {!$content_type_specified} {
			#assume it's form data
			append ret "Content-Type: application/x-www-form-urlencoded\r\n"
		}
		#Not going to allow form data and other post data to be sent in the same request.
		#It would be a fair http thing to do to append the form args to the url with a
		#post request, I am however assuming that if the user is selecting the POST method
		#they may not want the arguments appearing in the web server logs and browser history.
		#If you really want to do this I would suggest rolling you own URL with the form
		#args already appended
		if {$post_data != "" && $form_args_str != ""} {
			error "[_usage_format_http_req]\n\nCannot have form data AND post data in request"
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

#
# This procedure will return true (1) if the server MAY have had a chance to
# process the data.  It will return false (0) if the server DEFINITELY didn't/
# will not process any data if the request is complete or terminated at this point.
#
# A slight note of caution here - HTTP 4** errors are returned as not processed
# as the web server cannot process the business logic due to a client error in
# the request.
#
proc ::ob_socket::server_processed {req_id} {

	variable req_arr

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


#
# Split an absolute URL for an IP-based protocol into its constituent parts.
#
# Takes a URL like:
#
#  "scheme://<user>:<password>@<host>:<port>/<url-path>"
#
#  (in which the parts "<user>:<password>@", ":<password>",
#   ":<port>", and "/<url-path>" are optional)
#
# and returns a list of the form:
#
#   {scheme host port slash-urlpath username password}
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
#   split_url "http://www.sun.com/foo/bar" ->
#     [list http "www.sun.com" 80 "/foo/bar" "" ""]
#
#   split_url "https://bootes.orbis:4443" ->
#     [list https "bootes.orbis" 4443 "" "" ""]
#
#   split_url "ftp://foo:secret@127.0.0.1/README" ->
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
proc ::ob_socket::split_url {url} {

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
proc ::ob_socket::_consume_scheme {s} {

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
proc ::ob_socket::_split_ip_scheme_part {schemepart} {

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
proc ::ob_socket::_consume_user_and_pass {s} {

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
proc ::ob_socket::_unescape_octets {s} {

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
proc ::ob_socket::_consume_hostport {s} {

	foreach {host remainder} [_consume_host $s] {}
	set port ""
	regexp {^:([0-9]+)(.*)$} $remainder junk port remainder

	return [list $host $port $remainder]
}

# Internal - Try to read a host from a string, returning it and the
# remainder of the string. See split_url.
proc ::ob_socket::_consume_host {s} {

	# XXX The host grammar in the RFC is quite tricky to implement.
	# We'll use a weaker one - downside is that we will fail to spot
	# some invalid hostnames - e.g. "a.b.c.123", "1.2.3".

	set host_re {^([A-Za-z0-9\-.]*[A-Za-z0-9])(.*)$}

	if {![regexp $host_re $s junk host remainder]} {
		error "\"$s\" does not start with a valid hostname or hostnumber"
	}

	return [list $host $remainder]
}



#
# Initiates the connection
#
proc ::ob_socket::_do_conn {req_id} {

	variable req_arr

	_log DEBUG "ob_socket::_do_conn called.  req_id = $req_id"

	set req_arr($req_id,status) "CONN"
	set req_arr($req_id,start_time) [_get_time]

	if {[catch {
		socket -async $req_arr($req_id,host) $req_arr($req_id,port)
	} sock]} {
		#Error probably due to unknown host or invalid port number
		_log WARNING "::ob_socket::_do_conn socket -async threw error $sock"

		if {$req_arr($req_id,async) == ""} {
			# we're synchronous so finish the req immediately
			_finish_req $req_id "CONN_FAIL" $sock
		} else {
			# we're asynchronous so arrange for the req to be finished shortly
			# (for consistency we want to return to the app in the same way as
			# we would if the req were to fail in some other way)
			after 0 [list ::ob_socket::_finish_req $req_id "CONN_FAIL" $sock]
		}

		return 0
	}
	set req_arr($req_id,sock) $sock
	#Explicitly deal with end of line chars if http.  For greater flexibility the client
	#should make sure that it is sending in an encoding that the server understands
	fconfigure $sock -blocking 0 -buffering none -encoding $req_arr($req_id,encoding) -translation "lf"

	fileevent $sock writable [list ::ob_socket::_check_conn $req_id]


	set req_arr($req_id,after_id)\
	    [after $req_arr($req_id,conn_timeout) [list ::ob_socket::_finish_req $req_id "CONN_TIMEOUT" ""]]

	_log DEBUG "ob_socket::_do_conn finished"
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
proc ::ob_socket::_check_conn {req_id} {

	variable req_arr

	_log DEBUG "ob_socket::_check_conn called.  req_id = $req_id"

	set sock $req_arr($req_id,sock)

	if {[catch {read $sock} msg]} {
		_finish_req $req_id "CONN_FAIL" $sock
		return
	}

	if {$req_arr($req_id,tls) == "-1"} {
		fileevent $sock writable [list ::ob_socket::_do_send $req_id]
	} else {
		#let tls handle the socket
		eval tls::import $sock $req_arr($req_id,tls)
		fileevent $sock writable [list ::ob_socket::_do_handshake $req_id]
	}

	_log DEBUG "ob_socket::_check_conn finished"
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
proc ::ob_socket::_do_handshake {req_id} {

	variable req_arr

	_log DEBUG "ob_socket::_do_handshake called.  req_id = $req_id"

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) "HANDSHAKE"

	#remove writable filevent
	_tidy_req $req_id 0

	if {[catch {tls::handshake $sock} hshake_status]} {
		if {[lindex $::errorCode 1] == "EAGAIN"} {
			#this error is fine it just indicates that we should call the
			#tls::handshake command again. Leave the readable filevent
			#open
			_log DEBUG "tls::handshake threw EAGAIN error: $hshake_status"
			fileevent $sock readable [list ::ob_socket::_do_handshake $req_id]
		} else {
			_finish_req $req_id "HANDSHAKE_FAIL" $hshake_status
		}
		return
	}

	if {$hshake_status == "1"} {
		_do_send $req_id
	} else {
		_log DEBUG "tls::handshake returned 0. Going back into vwait loop"
		fileevent $sock readable [list ::ob_socket::_do_handshake $req_id]
		#_finish_req $req_id "HANDSHAKE_FAIL" "tls::handshake returned 0"
	}

	_log DEBUG "ob_socket::_do_handshake finished"
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
proc ::ob_socket::_do_send {req_id} {

	variable req_arr
	variable write_buffer

	_log DEBUG "ob_socket::_do_send called.  req_id = $req_id"

	set sock $req_arr($req_id,sock)
	set ::ob_socket::req_arr($req_id,status) "SEND"

	#Connection successful remove conn timeout and add req timeout
	if {$req_arr($req_id,write_pointer) == 0} {
		set req_arr($req_id,req_start_time) [_get_time]
		_tidy_req $req_id 1
		set req_arr($req_id,after_id)\
		    [after $req_arr($req_id,req_timeout) [list ::ob_socket::_finish_req $req_id "REQ_TIMEOUT" ""]]
		fileevent $sock writable [list ::ob_socket::_do_send $req_id]
	}

	#implement our own buffering so that we can successfully close the socket
	#when we can no longer write to it
	set curr_pos $req_arr($req_id,write_pointer)
	set req_length [string length $req_arr($req_id,req)]

	if {$curr_pos >= $req_length} {
		#finished writing
		_tidy_req $req_id 0
		fileevent $sock readable [list ::ob_socket::_do_read $req_id]
	}

	set end_pos  [expr {$curr_pos + $write_buffer - 1}]
	if {[catch {
		puts -nonewline $sock [string range $req_arr($req_id,req) $curr_pos $end_pos]
	} msg]} {
		_finish_req $req_id "SEND_FAIL" $msg
		return
	}

	incr req_arr($req_id,write_pointer) $write_buffer

	_log DEBUG "ob_socket::_do_send finished"
}

#
# Read the response from the server
#
proc ::ob_socket::_do_read {req_id} {

	variable req_arr

	_log DEBUG "ob_socket::_do_read called.  req_id = $req_id"

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) "READ"

	if {[eof $sock]} {
		_finish_req $req_id "OK" ""
		return
	}

	_tidy_req $req_id 0
	fileevent $sock readable [list ::ob_socket::_do_read $req_id]
	if {[catch {read $req_arr($req_id,sock)} ret]} {
		_finish_req $req_id "READ_FAIL" $ret
		return
	}
	_log DEBUG "::ob_socket::_do_read [string length $ret] read"
	append req_arr($req_id,response) $ret

	_log DEBUG "ob_socket::_do_read finished"
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
proc ::ob_socket::_tidy_req {req_id remove_timeout} {

	variable req_arr

	_log DEBUG "ob_socket::_tidy_req called. req_id = $req_id remove_timeout = $remove_timeout"

	set sock $req_arr($req_id,sock)

	if {[catch {fileevent $sock writable {}} msg]} {
		_log DEBUG "Unable to remove writable fileevent $msg"
	}
	if {[catch {fileevent $sock readable {}}]} {
		_log DEBUG "Unable to remove readable fileevent $msg"
	}
	if {$remove_timeout} {
		catch {after cancel $req_arr($req_id,after_id)}
		set req_arr($req_id,after_id) ""
	}

	_log DEBUG "ob_socket::_tidy_req finished"
}

#
# Called both when the request has been successful and on error too.
#
proc ::ob_socket::_finish_req {req_id status msg {complete 1}} {

	variable reqs_processed
	variable req_arr
	variable set_status

	_log DEBUG "ob_socket::_finish_req called. req_id = $req_id, status = $status, msg = $msg"

	set sock $req_arr($req_id,sock)
	set req_arr($req_id,status) $status
	set req_arr($req_id,complete) $complete

	_tidy_req $req_id 1
	catch {close $sock}

	set req_arr($req_id,end_time) [_get_time]
	switch -- $status {
		"PRE_CONN" {
			_log INFO "::ob_socket:: $req_arr($req_id,host) Connection Interrupted - not attempted"
		}
		"CONN" -
		"CONN_FAIL" -
		"CONN_TIMEOUT" -
		"HANDSHAKE" -
		"HANDSHAKE_FAIL" {
			set conn_time [_diff_time $req_arr($req_id,start_time) $req_arr($req_id,end_time)]
			_log INFO "::ob_socket:: $req_arr($req_id,host): Conn Time: $conn_time Status: $status"
		}
		default {
			set conn_time [_diff_time $req_arr($req_id,start_time) $req_arr($req_id,req_start_time)]
			set req_time [_diff_time $req_arr($req_id,req_start_time) $req_arr($req_id,end_time)]
			_log INFO "::ob_socket:: $req_arr($req_id,host): Conn: Time $conn_time  Req Time: $req_time Status: $status"
		}
	}

	#If we indicate this is an http request, parse the response
	if {$status == "OK" && $req_arr($req_id,is_http)} {
		_parse_http_response $req_id
	}

	if {$req_arr($req_id,async) == ""} {
		incr reqs_processed
	} elseif {$complete == 1} {
		$req_arr($req_id,async)\
		    $req_id\
		    $req_arr($req_id,status)\
		    $msg\
		    $req_arr($req_id,client_data)
	}

	if {$set_status} {
		asSetStatus $req_arr($req_id,appserv_status)
	}

	_log DEBUG "ob_socket::_finish_req finished"
}

#
# Go through response from the server and parse it as http.
# In all likelyhood the header part of the response should be small
# whereas the data part could be huge.  Hence the most efficient way
# of parsing it would be to parse it "in place".  Couldn't think
# how to do this so if anyone wants to make it more efficient: feel free...
#
proc ::ob_socket::_parse_http_response {req_id} {

	variable req_arr

	set start 0
	set end [string first "\n" $req_arr($req_id,response)]
	set status_str [string range $req_arr($req_id,response) 0 [expr {$end - 1}]]
	# Line breaks should be \r\n in http
	set status_str [string trimright $status_str "\r"]

	# Should have the form HTTP/[HTTP_VERSION] [HTTP_STATUS] [HTTP_STATUS_DESC]
	set status_re {^HTTP/\S+\s([0-9]+)\s}
	if {![regexp $status_re $status_str all status]} {
		_log WARNING "ob_socket::_parse_http_response: Invalid HTTP header: $status_str"
		set req_arr($req_id,status) "HTTP_INVALID"
		return
	}

	# Parse the headers these should have the form HEADER: VALUE
	set header_re {([^:\s]+):\s*(.*)$}
	# HTTP headers can stretch across multiple lines if the next line starts
	# with any number of space, tab characters
	set header_cont_re {\s*(.*)$}
	set headers [list]
	set body_start 0
	set start [expr {$end + 1}]

	#Iterate through the response to read the headers
	set curr_header_name ""
	set curr_header_val  ""

	while {1} {
		set end [string first "\n" $req_arr($req_id,response) $start]

		if {$end == -1} {
			_log WARNING "::ob_socket::_parse_http_response req_id = $req_id. No body data"
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
			_log WARNING "ob_socket::_parse_http_response: Invalid HTTP header: $header"
			set req_arr($req_id,status) "HTTP_INVALID"
			return
		}
		set start [expr {$end + 2}]
	}

	#check the status code
	switch -- [expr {$status / 100}] {
		1 {set req_arr($req_id,http_status) "HTTP_INFORMATION_REQ"}
		2 {set req_arr($req_id,http_status) "OK"}
		3 {set req_arr($req_id,http_status) "HTTP_REDIRECT"}
		4 {set req_arr($req_id,http_status) "HTTP_CLIENT_ERROR"}
		5 {set req_arr($req_id,http_status) "HTTP_SERVER_ERROR"}
		default {
			set req_arr($req_id,http_status) "HTTP_UNKNOWN_STATUS"
		}
	}

	set req_arr($req_id,http_headers)    $headers
	set req_arr($req_id,http_body_start) $body_start
	set req_arr($req_id,status) OK
}

#
# OT_MicroTime occassionally throws an error - retry on failure
# tcl8.5 has clock milliseconds if we ever get that far
#
proc ::ob_socket::_get_time {} {

	for {set i 0} {$i < 3} {incr i} {
		if {[catch OT_MicroTime ret]} {
			_log WARNING "OT_MicroTime failed: $ret"
		} else {
			return $ret
		}
	}
	return -1
}

#
# Allows for OT_MicroTime errors
#
proc ::ob_socket::_diff_time {time_a time_b} {

	if {$time_a == -1 || $time_b == -1} {
		return "ERR"
	} else {
		return [format "%0.3f" [expr {$time_b - $time_a}]]
	}
}

#
# Return number of requests submitted for information purposes
#
proc ::ob_socket::get_num_requests {} {

	variable num_requests

	return $num_requests
}

#
# Return number of requests submitted for information purposes
#
proc ::ob_socket::get_num_requests_complete {} {

	variable num_requests_complete

	return $num_requests_complete
}


#
# Usage of send_req
#
proc ::ob_socket::_usage_send_req {} {

	variable default_conn_timeout
	variable default_req_timeout
	variable default_encoding

	set ret "USAGE: send_req ?options? request host port\n"
	append ret "request:  Request string to be sent to server.\n"
	append ret "host:     Server to send the request to.\n"
	append ret "port:     Server port.\n\n"
	append ret "options:\n"
	append ret "-conn_timeout TIMEOUT:  Set the connection timeout to TIMEOUT ms default=$default_conn_timeout\n"
	append ret "-req_timeout TIMEOUT:   Set the request timeout to TIMEOUT ms default=$default_req_timeout\n"
	append ret "-tls tls_string:        Send the request via ssl.  If specific cerificates or ssl versions are\n"
	append ret "                        required put them in the tls_string.  Otherwise use empty string -tls \{\}\n"
	append ret "                        the tls_string will be passed to tls::socket see tls docs for futher info.\n"
	append ret "-async callback:        Procedure will return immediately and the request will be processed\n"
	append ret "                        when the application goes back into the vwait/tkwait loop.\n"
	append ret "                        When the request has finished \(completed, timed out or encountered an\n"
	append ret "                        error\), the callback_function will be called.  It needs to accept 4 params:\n"
	append ret "                        req_id, status, err_msg (empty on success) and client_data \(see below\)\n"
	append ret "-client_data:           Application specific data that will be passed to the callback function when\n"
	append ret "                        when sending requests asynchronously\n"
	append ret "-is_http:               Attempt to parse the response as http on a successful connection attempt\n"
	append ret "-encoding ENCODING:     Encoding to send request to the server in default=$default_encoding. \n\n"
	append ret "Returns a list; \{req_id, connection_status, complete\[1|0\]\}"
	return $ret
}

#
# Usage of configure
#
proc ::ob_socket::_usage_configure {} {

	variable default_conn_timeout
	variable default_req_timeout
	variable default_encoding
	variable write_buffer
	variable log_proc
	variable log_level
	variable log_numeric_error_level
	variable log_numeric_warning_level
	variable log_numeric_info_level
	variable log_numeric_debug_level
	variable log_numeric_dev_level

	set ret "USAGE: configure ?options?\n\n"
	append ret "options:\n"
	append ret "-default_conn_timeout TIMEOUT:  Default connection timeout in ms. Currently set to $default_conn_timeout\n"
	append ret "-default_req_timeout TIMEOUT:   Default request timeout in ms. Currently set to $default_req_timeout\n"
	append ret "-default_encoding ENCODING:     Default encoding to send requests. Currently set to $default_encoding\n"
	append ret "-write_buffer SIZE:             Size in bytes of chunks sent to the socket. Currently set to $write_buffer\n"
	append ret "-log_proc PROC_NAME:            Procedure for logging.\n"
	append ret "                                -log_proc STDOUT will log to stdout\n"
	append ret "                                -log_proc NONE will supress logging\n"
	append ret "                                -log_proc OT_LogWrite will use OT_LogWrite\n"
	append ret "                                Otherwise the procedure PROC_NAME must accept two params, level and message\n"
	append ret "                                It must recognise the levels ERROR,WARNING,INFO,DEBUG and DEV\n"
	append ret "                                Currently set to $log_proc\n"
	append ret "-log_level NUM                  Logging level used when logging to stdout.  Currently set to $log_level\n"
	append ret "-log_numeric_error_level NUM    When logging to stdout or OT_Logwrite. Numeric level of ERROR message ($log_numeric_error_level)\n"
	append ret "-log_numeric_warning_level NUM  When logging to stdout or OT_Logwrite. Numeric level of WARNING message ($log_numeric_warning_level)\n"
	append ret "-log_numeric_info_level NUM     When logging to stdout or OT_Logwrite. Numeric level of INFO message ($log_numeric_info_level)\n"
	append ret "-log_numeric_debug_level NUM    When logging to stdout or OT_Logwrite. Numeric level of DEBUG message ($log_numeric_debug_level)\n"
	append ret "-log_numeric_dev_level NUM      When logging to stdout or OT_Logwrite. Numeric level of DEV message ($log_numeric_dev_level)\n"
	return $ret
}

#
# Usage of format_http_req
#
proc ::ob_socket::_usage_format_http_req {} {

	variable default_encoding

	set ret "USAGE: format_http_req ?options? URL\n\n"
	append ret "URL:  Request URL on server.\n"
	append ret "options:\n"
	append ret " -method METHOD:        GET or POST.  Default=POST\n"
	append ret " -host HOSTNAME:        Host to send request to.  Useful if going via proxy server\n"
	append ret " -form_args LIST:       List of name value pairs of form arguments.  Default={}\n"
	append ret " -headers LIST:         List of name value pairs of HTTP headers (Cookies etc...).  Default={}\n"
	append ret " -post_data DATA:       Data to be posted with the request.  Cannot have both form_args and post_data set\n"
	append ret " -encoding ENCODING:    Encoding we will be sending the request in Default=$default_encoding\n\n"
	append ret "Returns formatted http string."
	return $ret
}

#
# Usage of req_info
#
proc ::ob_socket::_usage_req_info {} {

	set ret "USAGE: req_info item ?sub_item?\n\n"
	append ret "Allowable items are:\n"
	append ret "host:                    Where request is sent to\n"
	append ret "port:                    Server port\n"
	append ret "tls:                     String passed to tls::socket to send request over SSL. -1 Indates non SSL.\n"
	append ret "conn_timeout:            Connection timeout for this request\n"
	append ret "req_timeout:             Request timeout for this request\n"
	append ret "status:                  Current connection status\n"
	append ret "response:                Response from server\n"
	append ret "async:                   Procedure, request will call when completed.  \{\} indicates synchronous request\n"
	append ret "client_data:             Non socket data that will be sent to the async callback function\n"
	append ret "complete:                \[1|0\] Whether request is still processing. Synchronous reqs always return 1\n"
	append ret "is_http:                 \[1|0\] 1 indicates that req will attempt to parse response as http. 0 indicates not\n"
	append ret "http_headers:            \(need -is_http 1\) Name Value list of all the http headers\n"
	append ret "http_header HEADER_NAME: \(need -is_http 1\) Return value of HEADER_NAME.  \{\} if not set\n"
	append ret "http_body:               \(need -is_http 1\) Returns data portion of HTTP request.\n"
	return $ret

}

#
# Logging
# The intention is to use this from appserver, telebet client, command line etc,
# so please don't go around replacing _log messages with your logging proc of choice
# Thanks.
#
proc ::ob_socket::_log {level msg} {

	variable log_proc
	variable log_level
	variable log_numeric_error_level
	variable log_numeric_warning_level
	variable log_numeric_info_level
	variable log_numeric_debug_level
	variable log_numeric_dev_level

	switch -- $log_proc {
		"NONE" {
			#no logging
			return
		}
		"STDOUT" {
			switch -- $level {
				"ERROR"   {set l $log_numeric_error_level}
				"WARNING" {set l $log_numeric_warning_level}
				"INFO"    {set l $log_numeric_info_level}
				"DEBUG"   {set l $log_numeric_debug_level}
				"DEV"     {set l $log_numeric_dev_level}
				default {
					error ("Unknown error level $level")
				}
			}

			if {$l <= $log_level} {
				puts "$msg"
			}
		}
		"OT_LogWrite" {
			switch -- $level {
				"ERROR"   {set l $log_numeric_error_level}
				"WARNING" {set l $log_numeric_warning_level}
				"INFO"    {set l $log_numeric_info_level}
				"DEBUG"   {set l $log_numeric_debug_level}
				"DEV"     {set l $log_numeric_dev_level}
				default {
					error ("Unknown error level $level")
				}
			}
			OT_LogWrite $l $msg
		}
		default {
			$log_proc $level $msg
		}
	}
}



# Url encode only the reserved/unsafe characters (rather than all chars that
# aren't in the range A-Z,a-z,0-9,_ as is done by appserv urlencode)
#
#    str - the string to encode
#
#    returns - the urlencoded string
#
proc ::ob_socket::_urlencode_unsafe {str} {

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

