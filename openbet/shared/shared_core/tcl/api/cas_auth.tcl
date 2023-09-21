# Copyright (C) 2015 Orbis Technology Ltd. All Rights Reserved.
#
# CAS (Central Authentication Service) integration
#
# Synopsis:
# =========
# The Central Authentication Service (CAS) is a single-sign-on /
# single-sign-off protocol for the web. It permits a user to access
# multiple applications while providing their credentials (such as
# userid and password) only once to a central CAS Server application.
#
# This package mostly provides the service ticket (ST) validation
# facility that is needed when a user/3rd party tries to access a
# front-end service (like admin, TI or telebet) OR back-end service
# (like OXi, feed_handler etc)
#
set pkg_version 1.0
package provide core::api::cas_auth $pkg_version
# Dependencies
package require tdom
package require core::log      1.0
package require core::xml      1.0
package require core::args     1.0
package require core::check    1.0
package require core::socket   1.0

core::args::register_ns \
	-namespace core::api::cas_auth \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::xml \
		core::args \
		core::check \
		core::socket] \
	-docs xml/api/cas_auth.xml

namespace eval core::api {
	namespace eval cas_auth {
		variable CFG
		variable CAS
	}
}

# INIT
# ===========================================================
core::args::register \
-proc_name "core::api::cas_auth::init" \
-desc {initialise the Central Authentication Service API.} \
-args [list \
	[list -arg -is_front_end_app -mand 1 -check BOOL                -desc {Is this a front-end application? (ie, uses core::view) so it can issue browser redirections?}] \
	[list -arg -service_url      -mand 0 -check {STRING -min_str 1} -desc {The application's own service URL eg "https://office.example.com/openbetAPI", mandatory only for back-end apps.}] \
	[list -arg -cgi_url          -mand 0 -check STRING              -default_cfg CGI_URL] \
] \
-body {
	variable CFG

	core::log::write INFO {CAS: initializing core::api::cas_auth}
	package require core::socket 1.0
	package require core::xml    1.0
	core::xml::init

	foreach n [array names ARGS] {
		set CFG([string trimleft $n -]) $ARGS($n)
		# make sure the CGI URL starts with /
	}
	if {[string last / $CFG(cgi_url)] < 0} {
		set CFG(cgi_url) "/$CFG(cgi_url)"
	}
	set CFG(cas_urls) [list]

	if ($CFG(is_front_end_app)) {
		# front-end app, must have a CGI_URL
		if {$CFG(cgi_url) == ""} {
			error "CGI_URL not set in config, please define it with -cgi_url" {} CGI_URL_REQUIRED
		}
	} else {
		# back-end app, service_url is mandatory
		if {$ARGS(-service_url) == ""} {
			error "-service_url is mandatory for back-end applications!" {} SERVICE_URL_REQUIRED
		}
	}
}

# REGISTER_CAS
# ===========================================================
core::args::register \
-proc_name "core::api::cas_auth::register_cas" \
-desc {register a Central Authentication Service.} \
-args [list \
	[list -arg -cas_url                -mand 1 -check {STRING -min_str 4} -desc {The Central Authentication Service URL eg "https://cas.example.com/cas"}] \
	[list -arg -default_cas            -mand 0 -check BOOL                -desc {Use this as the default CAS service to validate ST requests}] \
	[list -arg -on_validation_success  -mand 0 -check ASCII -default {}   -desc {Callback to call when the ST has been validated and the user has been granted access to the application.} ] \
	[list -arg -on_validation_failure  -mand 0 -check ASCII -default {}   -desc {Callback to call when the ST has failed validation} ] \
] \
-body {
	variable CFG
	variable CAS

	set cas [string trim $ARGS(-cas_url)]
	# CAS requires end-to-end SSL for authentication
	if {[string first https $cas] != 0} {
		error "CAS auth url must start with https" {} CAS_AUTH_URL_IS_NOT_HTTPS
	}
	# set this CAS server as default if
	# - 1) we define it as such by passing in "-default_cas 1" OR
	# - 2) its simply the first CAS server the app is registering
	if {[array get ARGS -default_cas] == 1 || \
		[llength $CFG(cas_urls)] == 0} {
		core::log::write DEBUG {CAS: setting '$cas' as default}
		set CFG(default_cas) $cas
	}

	foreach n { on_validation_success on_validation_failure } {
		set CAS($cas,$n) $ARGS(-$n)
	}
	lappend $CFG(cas_urls) $cas

	core::log::write INFO {CAS: registered '$cas'}
}


# GUESS_SERVICE_URL
# reconstruct the service URL from the standard CGI headers
# ===========================================================
core::args::register \
-proc_name "core::api::cas_auth::guess_service_url" \
-desc {Get an application's service URL from the relevant CGI parameters.} \
-args [list \
	[list -arg -req_host  -mand 1 -check {STRING -min_str 1} -desc {The request's HTTP_HOST header}] \
	[list -arg -req_port  -mand 1 -check UINT                -desc {The request's SERVER_PORT header}] \
	[list -arg -req_uri   -mand 1 -check STRING              -desc {the REQUEST_URI}] \
	[list -arg -req_https -mand 0 -check STRING -default 0   -desc {Set to 'on' if this an HTTPS secure request}] \
] \
-body {
	variable CFG

	set proto [expr {$ARGS(-req_https) == "on" ? "https" :"http"}]
	set path $ARGS(-req_uri)
	# strip out the query part
	set qmark [string first "?" $ARGS(-req_uri)]
	if {$qmark > -1} {
		set path [string range $ARGS(-req_uri) 0 $qmark-1]
	}
	# make sure the path starts with /
	if {[string first / $path] < 0} {
		set path "/$path"
	}
	# HTTP_HOST could contain the port number:
	# http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.23
	# in this case this should use this port number instead of SERVER_PORT
	if {[regexp {.*(:(\d*))} $ARGS(-req_host) host unused unused2]} {
		set service_url "$proto://$host$path"
	} else {
		switch $ARGS(-req_port) {
			80      -
	    443     { set service_url "$proto://$ARGS(-req_host)$path" }
	    default { set service_url "$proto://$ARGS(-req_host):$ARGS(-req_port)$path" }
		}
	}
	_set_service_url $service_url
	return $service_url
}

# CAS_VALIDATE
# ===========================================================================
core::args::register \
-proc_name "core::api::cas_auth::cas_validate" \
-desc {Validates a service ticket against the given CAS instance. RETURNS: boolean 0 (fail) or 1 (success) } \
-args [list \
		[list -arg -ticket      -mand 1 -check {STRING -min_str 1} -desc {The service ticket ID supplied by CAS}] \
		[list -arg -cas_url     -mand 0 -check {STRING -min_str 1} -desc {CAS URL to validate against (You must have registered it first)}] \
	] \
-body {
	variable CFG

	set cas               [core::api::cas_auth::_assert_cas_registered $ARGS(-cas_url)]
	core::log::write INFO {CAS: validating service ticket for $CFG(service_url) against $cas}
	# make the backend call to CAS to validate the ticket
	set ret               [core::api::cas_auth::_cas_validate $ARGS(-ticket) $cas]
	set doc               [lindex $ret 1]
	set root              [$doc documentElement]
	set service_response  [$root selectNodes "//cas:serviceResponse/*"]
	set validation_result [$service_response nodeName]
	# was the ST validation a success?
	set logged_in         [expr {$validation_result == "cas:authenticationSuccess"}]
	if {$logged_in} {
		core::api::cas_auth::_handle_success $service_response $cas
	} else {
		core::api::cas_auth::_handle_failure $service_response $cas
	}
	$doc delete
	return $logged_in
}

# CAS_LOGIN_REDIRECT
# ============================================================================
core::args::register \
-proc_name "core::api::cas_auth::cas_login_redirect" \
-desc {Redirects to CAS login page to get the user authorised. This proc should be called by front-end facing apps only.} \
-args [list \
		[list -arg -cas_url     -mand 0 -check {STRING -min_str 1} -desc {CAS URL to redirect to}] \
	] \
-body {
	variable CFG

	if {$CFG(is_front_end_app)} {
		# construct the redirection URL after successful CAS login
		set url [_make_cas_url $ARGS(-cas_url) login 1 $CFG(service_url)]
		core::log::write INFO {CAS: redirecting to CAS login page ($url)}
		core::api::cas_auth::_redirect $url
	}
}

# CAS_LOGOUT
# ============================================================================
core::args::register \
-proc_name "core::api::cas_auth::cas_logout" \
-args [list \
		[list -arg -cas_url         -mand 0 -check {STRING -min_str 1} -desc {CAS instance to logout from}] \
		[list -arg -show_logout_msg -mand 0 -check BOOL  -default 0 -desc {Land the user on CASes 'You have been logged out' page?} ] \
		[list -arg -tgt             -mand 0 -check ANY              -desc {TGT for logging out - this is only needed for back-end services which use the REST API}] \
	] \
-desc {Logout from CAS SSO: simply redirect the browser to CAS/logout and the TGT will be destroyed.} \
-body {
	variable CFG

	if {$CFG(is_front_end_app)} {
		# as per CAS 3.0 protocol spec, the CAS /logout handler MAY redirect us back to the service,
		# hiding the 'successfully logged out' message. This will mean that
		# eventually the user will be redirected back to the CAS login form.
		# be sure to enable "cas.logout.followServiceRedirects" in cas.properties
		set append_service [expr {!$ARGS(-show_logout_msg)}]
		set url [_make_cas_url $ARGS(-cas_url) logout $append_service $CFG(service_url)]
		core::log::write INFO {CAS LOGOUT: redirecting browser to $url}
		core::api::cas_auth::_redirect $url

	} else {

		set url "$cas/v1/tickets/"
		if {$ARGS(-tgt) == ""} {
			# in order for this call to make sense, we need to be aware of the TGT
			error "The TGT is needed to perform logout from a back-end app" {} TGT_REQUIRED
		} else {
			append url $ARGS(-tgt)
		}
		core::log::write INFO {CAS LOGOUT: making back-end call to $url}
		lassign [::core::socket::send_http_req \
			-method  DELETE \
			-url     $url \
		] req_id status complete

		core::log::write DEBUG {CAS LOGOUT: $status}
		core::socket::clear_req -req_id $req_id
	}
}


# If you use core::controller, wire in this proc into your app's authentication prehandler
# (usually just after the cookie check has failed). This greatly simplifies your app's CAS integration!
# It will return 1 should this request come from a successful ST redirection (following a successful
# CAS login), you can then safely assume the user is logged in. Otherwise, you'll get an error raised.
# This proc will also set your application's service_url for you, in case you didn't define it
# ============================================================================
core::args::register \
-proc_name "core::api::cas_auth::controller_prehandler_hook" \
-desc {core::controller authentication prehandler. This proc should be called by front-end facing apps only.} \
-args [list \
	[list -arg -req_uri   -mand 1 -check {STRING -min_str 1} -desc {The full request URI}] \
	[list -arg -req_host  -mand 1 -check {STRING -min_str 1} -desc {The request's HTTP_HOST header}] \
	[list -arg -req_port  -mand 1 -check UINT                -desc {The request's SERVER_PORT header}] \
	[list -arg -req_https -mand 1 -check STRING              -desc {Set to 'on' if this an HTTPS secure request}] \
	[list -arg -is_login  -mand 0 -check BOOL   -default 0   -desc {Front-end apps: Should we redirect the user to CAS for login?}] \
	[list -arg -is_logout -mand 0 -check BOOL   -default 0   -desc {Front-end apps: Should we log out the user?}] \
] \
-body {
	variable CFG

	if {[info exists ARGS(-is_login)] && \
		[info exists ARGS(-is_logout)] && \
		$ARGS(-is_login) && $ARGS(-is_logout)} {
		error "can't log in and log out with the same request!" {} OB_ERR
	}

	# we must reconstruct the service URL from CGI env vars for each request.
	# requests can arrive via both HTTP and HTTPS from the same 'session'
	guess_service_url \
		-req_host  $ARGS(-req_host) \
		-req_port  $ARGS(-req_port) \
		-req_uri   $ARGS(-req_uri)  \
		-req_https $ARGS(-req_https)

	# Get the request handler from the uri
	# TODO: use HTTP_REFERER to induce which CAS sent this ST (not just the default)
	if {[regexp {\?ticket=([^&]*)} $ARGS(-req_uri) -> ticket]} {
		# yup this looks like a ST indeed
		set cas [core::api::cas_auth::_assert_cas_registered]
		core::log::write INFO {CAS: Initiating service ticket validation}
		return  [core::api::cas_auth::cas_validate \
				-ticket   $ticket \
				-cas_url  $cas ]
	} else {
		if {$ARGS(-is_login)} {
			core::api::cas_auth::cas_login_redirect
		}
		if {$ARGS(-is_logout)} {
			core::api::cas_auth::cas_logout
		}
		error "Unauthorised Request" {} OB_ERR
	}
}

# ===================================================================
# Private Procedures
# ===================================================================

# make the actual HTTPS call to CAS to validate a service ticket
# returns a two-element list:
# 	 {OK <XML document>}
# or throws an error if any of core::socket or core::xml::parse calls fail}
proc core::api::cas_auth::_cas_validate { ticket cas } {
	set fn   "core::api::cas_auth::_cas_validate"
	variable CFG

	lassign [::core::socket::send_http_req \
		-method     POST \
		-url        "$cas/p3/serviceValidate" \
		-form_args  [list "service" $CFG(service_url) "ticket" $ticket] \
	] req_id status complete

	if {$status == "OK"} {
		set xml     [core::socket::req_info -req_id $req_id -item http_body]
		core::socket::clear_req -req_id $req_id
		core::log::write DEBUG $xml
		# core::xml::parse already returns a list of [<STATUS>, <DATA>]
		return      [core::xml::parse -strict 0 -xml $xml]
	} else {
		core::log::write ERROR {$fn: Request to CAS failed: $status}
		core::socket::clear_req -req_id $req_id
		error "Request to CAS failed: $status" {} SYSTEM_ERROR
	}
}

# process a successful validation response
proc core::api::cas_auth::_handle_success { service_response cas } {
	variable CFG
	variable CAS

	set principal_username    [[$service_response selectNodes "cas:user"] text]
	set principal_attributes  [dict create]

	core::log::write DEBUG {cas:user == $principal_username}
	foreach node [$service_response selectNodes "cas:attributes/*"] {
		set key [$node nodeName]
		set val [$node text]
		dict append principal_attributes $key $val
		core::log::write DEBUG {$key == $val}
	}

	# call the validation success handler for this CAS instance
	# this callback should set up the app's session cookie
	# arg 1: principal's username eg "Administrator"
	# arg 2: principal's attribute dictionary {user_id:1, fname:Elias, lname:Karakoulakis etc}
	core::api::cas_auth::_cb \
		$CAS($cas,on_validation_success) \
		$principal_username $principal_attributes

	# redirect to the service's root URL
	# this is meant to hide the "?ticket=ST-1-xyz" from the browser's address bar
	if {$CFG(is_front_end_app)} {
		core::log::write INFO {CAS: login successful, redirecting to $CFG(service_url)}
		core::api::cas_auth::_redirect $CFG(service_url)
	}
}

# process a cas:authenticationFailure reply
proc core::api::cas_auth::_handle_failure { service_response cas } {
	variable CFG
	variable CAS

	set errcode [$service_response getAttribute code]
	core::log::write ERROR {CAS: validation failed: $errcode}

	core::api::cas_auth::_cb $CAS($cas,on_validation_failure) $errcode

	if ($CFG(is_front_end_app)) {
		core::api::cas_auth::cas_login_redirect
	}
}

# generic callback caller
proc core::api::cas_auth::_cb {callback args} {
	if {$callback != {} && [info complete $callback] } {
		core::log::write DEBUG {CAS: calling $callback}
		return [$callback {*}$args]
	}
}

# if a cas server is passed, assert the given CAS URL is already registered
# if no cas server URL is passed, assert there's at least a default CAS
proc core::api::cas_auth::_assert_cas_registered {{cas_instance ""}} {
	variable CFG

	if {$cas_instance == ""} {
		if {![info exists CFG(default_cas)] || $CFG(default_cas) == ""} {
			error "No CAS server has been registered! Please register one first" {} NO_CAS_SERVER_REGISTERED
		}
		return $CFG(default_cas)
	} else {
		if {![lsearch -exact $CFG(cas_urls) $cas_instance]} {
			error "Unknown CAS instance: $cas_instance. Please register it first before using it" {} UNKNOWN_CAS_SERVER
		}
	}
	return $cas_instance
}

# not all apps have core::view installed and initialised!
proc core::api::cas_auth::_redirect {url} {
	if {[namespace exists ::core::view] && \
		[info exists ::core::view::INIT] && \
		$::core::view::INIT } {
		core::view::redirect -url $url
	} else {
		core::log::write DEBUG {core::api::cas_auth::_redirect: Raw redirection to $url}
		# perform raw redirect
		tpBufAddHdr "Status"   "302"
		tpBufAddHdr "Location" $url
	}
}


proc core::api::cas_auth::_make_cas_url {cas_url command {append_service 0} {service_url ""}} {
	variable CFG

	set url "[_assert_cas_registered $cas_url]/$command"
	if {$append_service && $service_url != ""} {
		append url "?service=[urlencode $service_url]"
	}
	return $url
}

proc core::api::cas_auth::_set_service_url {service_url} {
	variable CFG
	if {$service_url != ""} {
		if {![info exists CFG(service_url)] || \
			$CFG(service_url) != $service_url } {
			core::log::write INFO {CAS: setting service_url to '$service_url'}
			set CFG(service_url) $service_url
		}
	}
}
