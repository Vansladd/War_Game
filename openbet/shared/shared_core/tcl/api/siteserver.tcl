# Copyright (C) 2011 OpenBet Technology Ltd. All rights reserved.
#
# Tcl wrapper for the SiteServer API.
#

set pkgVersion 1.0
package provide core::siteserver $pkgVersion

#
# Dependencies.
# NB: Relies on a new appserv module, OT_SSClient, for talking to SiteServer.
#

package require Tcl 8.5
package require core::check
package require core::args
package require core::log

namespace eval core::siteserver {

	variable INIT
	variable CFG

	# SSL Options for the OT_SSClient library
	variable SSL_OPTS

	# OT_SSClient connection object to re-use if possible
	variable CONN
	
	set CFG(lib_error) {}
	
	if {[catch {package present OT_SSClient}]} {
		if {[catch {load libOT_SSClient[info sharedlibextension]} err]} {
			set CFG(lib_error) $err 
		}
	}
}

# This package uses some arg data-types that aren't currently
# available in the core::check package (but perhaps should be).

catch {
	# Register data type for an absolute or relative URI reference.
	core::check::register URL core::siteserver::_check_type_URL {}
}
catch {
	# Register data type for strings that many contain any
	# characters (including non-Tcl safe ones).
	core::check::register STR_ANY core::siteserver::_check_type_STR_ANY {}
}
catch {
	# Register data type for dictionary values that contain any
	# number of entries whose keys & values may be of any data type.
	core::check::register DICT_ANY core::siteserver::_check_type_DICT_ANY {}
}
catch {
	# Register data type for lists that contain any number of
	# elements which may be of any data type.
	core::check::register LIST_ANY core::siteserver::_check_type_LIST_ANY {}
}

proc core::siteserver::_check_type_URL {value args} {
	# Can't be very strict without knowing the scheme.
	return [regexp {^[A-Za-z0-9_:/+%&=?#]+$} $value]
}
proc core::siteserver::_check_type_STR_ANY {value args} {
	return 1
}
proc core::siteserver::_check_type_DICT_ANY {value args} {
	if {[catch {dict size $value}]} {
		return 0
	} else {
		return 1
	}
}
proc core::siteserver::_check_type_LIST_ANY {value args} {
	if {[catch {llength $value}]} {
		return 0
	} else {
		return 1
	}
}

#
# We also define a new arg data type specifically for SiteServer records.
#

catch {
	# Register data type for OpenBet SiteServer record.
	core::check::register OBSSREC core::siteserver::_check_type_OBSSREC {}
}

proc core::siteserver::_check_type_OBSSREC {value args} {
	# Should be a two-element list whose 2nd element is a dict.
	if {[catch {llength $value}]} {
		return 0
	}
	if {[llength $value] != 2} {
		return 0
	}
	if {[catch {dict size [lindex $value 1]}]} {
		return 0
	}
	return 1
}

core::args::register_ns \
  -namespace core::siteserver \
  -version   $pkgVersion \
  -docs      xml/api/siteserver.xml

core::args::register \
	-proc_name core::siteserver::init \
	-desc      {Initialise the package} \
	-returns   {Nothing} \
	-args      [list \
		[list -arg -base_api_url        -mand 0 -check URL     -default_cfg OB_SITESERVER_BASE_API_URL       -default {}       -desc {URL for the root of the SiteServer API}] \
		[list -arg -timeout_ms          -mand 0 -check UINT    -default_cfg OB_SITESERVER_TIMEOUT_MS         -default 0        -desc {Time in milliseconds to wait for and entire SiteServer request and response operation to complete before throwing an error, or zero for no timeout.}] \
		[list -arg -connect_timeout_ms  -mand 0 -check UINT    -default_cfg OB_SITESERVER_CONNECT_TIMEOUT_MS -default 0        -desc {Time in milliseconds to wait for a socket connection to be established to SiteServer before throwing an error, or zero for no timeout.}] \
		[list -arg -cache_type          -mand 0 -check ASCII   -default_cfg OB_SITESERVER_CACHE_TYPE         -default -        -desc {Storage for the client-side response cache; either "appserv" (to use appserv asFindString/asStoreString commands), "nodist" to use the same but with distributed caching disabled, or "none" to disable caching. Default is "appserv" provided that the asFindString/asStoreString commands are available, or "none" otherwise.}] \
		[list -arg -correlation_prefix  -mand 0 -check ASCII   -default_cfg OB_SITESERVER_CORRELATION_PREFIX -default "tclapp" -desc {A short string to include in the correlationId parameter of each request to help identify the source of request in the SiteServer logs.Default is "tclapp".}] \
		[list -arg -ssl_verify          -mand 0 -check BOOL    -default_cfg OB_SITESERVER_SSL_VERIFY         -default 1        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_version         -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_VERSION        -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_cert_file       -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_CERT_FILE      -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_cert_type       -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_CERT_TYPE      -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_key_file        -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_KEY_FILE       -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_key_type        -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_KEY_TYPE       -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_key_pass        -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_KEY_PASS       -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_ca_dir          -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_CA_DIR         -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_ca_file         -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_CA_FILE        -default -        -desc {See libcurl setopt SSL options.}] \
		[list -arg -ssl_ciphers         -mand 0 -check STR_ANY -default_cfg OB_SITESERVER_SSL_CIPHERS        -default -        -desc {See libcurl setopt SSL options.}] \
	]

proc core::siteserver::init {args} {
	
	array set ARGS [core::args::check core::siteserver::init {*}$args]

	variable INIT
	variable CONN
	variable CFG
	variable SSL_OPTS
	
	if {$CFG(lib_error) != {}} {
		error "Unable to load OT_SSClient library: $CFG(lib_error)"
	}

	if {[info exists INIT] && $INIT} {
		error "already initialised"
	}

	set CFG(base_api_url)       $ARGS(-base_api_url)
	set CFG(timeout_ms)         $ARGS(-timeout_ms)
	set CFG(connect_timeout_ms) $ARGS(-connect_timeout_ms)
	set CFG(correlation_prefix) $ARGS(-correlation_prefix)

	set cache_type $ARGS(-cache_type)
	if {$cache_type eq "-"} {
		if {[llength [info commands asFindString]]} {
			set cache_type "appserv"
		} else {
			set cache_type "none"
		}
	}
	if {[lsearch {appserv nodist none} $cache_type] < 0} {
		error "unknown cache_type $cache_type"
	}
	set CFG(cache_type) $cache_type

	foreach ssl_opt {
		verify
		version
		cert_file
		cert_type
		key_file
		key_type
		key_pass
		ca_dir
		ca_file
		ciphers
	} {
		set val $ARGS(-ssl_$ssl_opt)
		if {$val ne "-"} {
			lappend SSL_OPTS -$ssl_opt $val
		}
	}

	set INIT 1
}

# Examples:
#
#   Retrieve details of those classes with ids 1, 2 and 3 that are active:
#
#   set response_record \
#    [send_request \
#     -resource Drilldown/1.0/Class/1,2,3
#     -query_params [list simpleFilter class.isActive]]
#   set class_records \
#     [record_children -record $response_record -record_type class]
#   foreach class_record $class_records {
#     puts "got class record: $class_record"
#   }
#
#   The following three examples are essentially equivalent
#   to the above, but vary in how the request is constructed:
#
#   set response_record \
#    [send_request \
#     -resource Drilldown/1.0/Class/~%a
#     -resource_params [list a class [list 1 2 3]]
#     -query_params [list simpleFilter class.isActive]]
#
#   set response_record \
#    [send_request \
#     -url {/Drilldown/1.0/Class/1,2,3?simpleFilter=class.isActive}]
#
#   set url {http://www.example.com/openbet-ssviewer/Drilldown/1.0/Class/1,2,3}
#   append url {?simpleFilter=class.isActive}
#   set response_record \
#    [send_request \
#     -method GET \
#     -url $url]
#
#   This example demonstrates obtaining a localisation token:
#
#   set response_record \
#     [send_request \
#      -resource Common/1.0/LocalisationToken
#      -body_params [list translationLang fr displayedChannel J]
#   set localisation_token \
#     [record_id -record \
#       [record_child -record $response_record -record_type localisationToken]]
#

core::args::register \
	-proc_name core::siteserver::send_request \
	-desc      {Send a request to SiteServer} \
	-returns   {An SSResponse record (as can be passed to the record_xxx procs), or throws an error if unable to retrieve and parse the response for any reason, or if the response contains one or more error records.} \
	-args      [list \
		[list -arg -method          -mand 0 -check ASCII    -default {} -desc {The HTTP method to use (either GET or POST).Defaults to GET unless one or more body parameters have been supplied, in which case it will default to POST.}] \
		[list -arg -url             -mand 0 -check URL      -default {} -desc {The URL to request.May be absolute or relative (in which case it is appended to the configured base_url). Must already be URL encoded.Cannot be used in conjuction with the resource arg, nor with the query_params arg.}] \
		[list -arg -resource        -mand 0 -check STR_ANY  -default {} -desc {The SiteServer resource to request (e.g. /Drilldown/1.0/Class).The resource may contain "~%<name>" strings wherever SiteServer record ids are expected - these will be substituted with the record-ids given in the resource_params arg.<name> is expected to consist of A-Za-z0-9_ characters. Cannot be used in conjuction with the url arg.}] \
		[list -arg -resource_params -mand 0 -check LIST_ANY -default {} -desc {List of param name, record-type and record-ids triplets, e.g. {x class {1 2 3}}. These will be used in place of the ~%<name> strings in the resource arg. The record-type is needed so that a SiteServer idset token can be created as required for large idsets (this is done automatically by the send_request proc). Can only be used in conjuction with the resource arg.}] \
		[list -arg -query_params    -mand 0 -check LIST_ANY -default {} -desc {List of names and values of parameters to pass in the query string part of the request URL. Can only be used in conjuction with the resource arg.}] \
		[list -arg -body_params     -mand 0 -check LIST_ANY -default {} -desc {List of names and values of parameters to pass in the body of the request (only valid for POST requests).}] \
		[list -arg -cache_time_secs -mand 0 -check UINT     -default 0  -desc {The length of time in seconds for which the response may be cached client-side so it can be re-used by subsequent requests for the same URL. This argument is also taken to mean that the client is willing to accept a cached response. Can only be used for GET method requests.}] \
		[list -arg -force           -mand 0 -check BOOL     -default 0  -desc {Whether this request is to force the query to go to SiteServer (0 or 1).}] \
	]

proc core::siteserver::send_request {args} {

	variable CFG
	variable INIT
	
	array set ARGS [core::args::check core::siteserver::send_request {*}$args]

	if {![info exists INIT] || !$INIT} {
		error "not initialised"
	}
	
	set force  $ARGS(-force)
	set url    $ARGS(-url)
	set method $ARGS(-method)

	# Determine method
	if {$method eq ""} {
		if {[llength $ARGS(-body_params)]} {
			set method POST
		} else {
			set method GET
		}
	}
	if {$method eq "GET"} {
		if {[llength $ARGS(-body_params)]} {
			error "GET method cannot have body params"
		}
	} elseif {$method eq "POST"} {
		if {[llength $ARGS(-query_params)]} {
			error "POST method cannot have query params"
		}
		if {$ARGS(-cache_time_secs) > 0} {
			error "POST method cannot have cache time"
		}
	} else {
		error "only GET and POST methods are supported"
	}

	# Construct request URL and cache_key (and return response from
	# cache if possible).
	# This is a little involved when resource_params are used since
	# it can require a call to SiteServer to create an IdSet token.

	set cache_key   ""
	set request_url ""
	if {$url ne ""} {
		# The caller has supplied a relative or absolute URL.
		if {$ARGS(-resource) ne "" || \
		    [llength $ARGS(-resource_params)] || \
		    [llength $ARGS(-query_params)]} {
			error "cannot use the -url arg with the -resource,\
			       -resource_params or -query_params args"
		}
		if {[string match "http://*" $url] || \
		    [string match "https://*" $url]} {
			set request_url $url
		} else {
			set base_api_url $CFG(base_api_url)
			if {$base_api_url eq "-"} {
				error "must set base_api_url to use relative url"
			}
			set request_url [string trimright $base_api_url /]
			if {[string index $url 0] ne "/"} {
				append request_url /
			}
			append request_url $url
		}
		if {$ARGS(-cache_time_secs) > 0} {
			set cache_key $request_url

			# if we aren't forcing our way to SS check the cache
			if {!$force} {
				set cache_lookup [_get_cached_response $cache_key]
				if {[lindex $cache_lookup 0]} {
					return [lindex $cache_lookup 1]
				}
			}
		}
	} elseif {$ARGS(-resource) ne ""} {
		# The caller has supplied a SiteServer resource and some
		# params from which we must construct a full URL.
		# Because resource param substitution can involve making
		# a call to get an id set token, we have to do the cache
		# lookup first.
		if {$ARGS(-cache_time_secs) > 0} {
			set cache_key [list \
				$ARGS(-resource) \
				$ARGS(-resource_params) \
				$ARGS(-query_params)]

			# if we aren't forcing our way to SS check the cache
			if {!$force} {
				set cache_lookup [_get_cached_response $cache_key]
				if {[lindex $cache_lookup 0]} {
					return [lindex $cache_lookup 1]
				}
			}
		}
		set base_api_url $CFG(base_api_url)
		if {$base_api_url eq "-"} {
			error "must set base_api_url to use resource"
		}
		set request_url [string trimright $base_api_url /]
		set resource $ARGS(-resource)
		set subst_resource \
		  [_subst_resource_params \
		    $ARGS(-resource) $ARGS(-resource_params)]
		if {[string index $subst_resource 0] ne "/"} {
			append request_url /
		}
		append request_url $subst_resource
		if {[llength $ARGS(-query_params)]} {
			set is_first 1
			foreach {name value} $ARGS(-query_params) {
				if {$is_first} {
					append request_url "?"
					set is_first 0
				} else {
					append request_url "&"
				}
				append request_url [urlencode -form 0 $name]
				append request_url "="
				append request_url [urlencode -form 0 $value]
			}
		}
	} else {
		error "must specify either -url or -resource arg"
	}

	# Abbreviate request URL for logging

	set req_abbrev $request_url
	regsub {^(\w+://)} $req_abbrev {} req_abbrev ;# remove the protocol
	regsub {^[^/]+}    $req_abbrev {} req_abbrev ;# remove the host
	regsub {\?.*$}     $req_abbrev {} req_abbrev ;# remove the query

	# Construct body

	if {$method eq "GET" || ![llength $ARGS(-body_params)]} {
		set body ""
	} else {
		set body ""
		set is_first 1
		foreach {name value} $ARGS(-body_params) {
			if {$is_first} {
				set is_first 0
			} else {
				append body "&"
			}
			append body [urlencode -form 1 $name]
			append body "="
			append body [urlencode -form 1 $value]
		}
	}

	set max_attempts                4
	set retry_delay_base_ms         1000
	set retry_delay_back_off_factor 2.0
	set retry_delay_max_ms          5000
	set retry_delay_next_ms         $retry_delay_base_ms

	for {set attempt 0} {$attempt < $max_attempts} {incr attempt} {

		set ok 0
		set err_msg "unknown"
		set err_code ""
		set err_info ""

		set t0 [OT_MicroTime]
		set time_taken ""

		if {[catch {

			set http_code ""
			set response_record ""

			# Get connection and make request

			set correlated_request_url [_correlate_request_url $request_url]

			set conn [_get_connection]
			if {$method eq "POST"} {
				core::log::write INFO {OBSS send_request: request=POST $correlated_request_url}
				core::log::write DEBUG {OBSS send_request: body=$body}
				set resp [ot::ssclient::send_request -method POST $conn $correlated_request_url $body]
			} else {
				core::log::write INFO {OBSS send_request: request=GET $correlated_request_url}
				set resp [ot::ssclient::send_request $conn $correlated_request_url]
			}

			set http_code [lindex $resp 0]
			set response_record [lindex $resp 1]

			if {$http_code ne "200"} {
				error "HTTP status-code not 200"
			}

			if {[_check_type_OBSSREC $response_record] && \
			    [llength [record_children -record $response_record -record_type error]]} {
				error "response contains error records"
			}

			set response_footer_record [record_child -record $response_record -record_type responseFooter]
			set response_footer_dict   [record_dict -record $response_footer_record -with_children 0]
			set response_footer_str    "\[$response_footer_dict\]"

			set time_taken [format %.3f [expr {[OT_MicroTime] - $t0}]]

		} err_msg]} {

			if {$time_taken eq ""} {
				set time_taken [format %.3f [expr {[OT_MicroTime] - $t0}]]
			}

			set err_code $::errorCode
			set err_info $::errorInfo

			# Add more detail to the error message

			if {$http_code != ""} {
				append err_msg " http_code=$http_code"
			}
			if {[_check_type_OBSSREC $response_record]} {
				foreach error_record [record_children -record $response_record -record_type error] {
					set error_dict [record_dict -record $error_record -with_children 0]
					append err_msg " api_error=\[$error_dict\]"
				}
			}

			core::log::write ERROR {OBSS send_request: failed; $req_abbrev $err_msg err_code=$err_code time_taken=$time_taken}

			# Retry if unable to connect or if it's a temporary problem

			if {$http_code == "" || $http_code == 503} {
				_close_connection
				core::log::write INFO {OBSS send_request: waiting $retry_delay_next_ms ms to retry}
				after [expr {int($retry_delay_next_ms)}]
				set retry_delay_next_ms [expr {$retry_delay_next_ms * $retry_delay_back_off_factor}]
				if {$retry_delay_next_ms > $retry_delay_max_ms} {
					set retry_delay_next_ms $retry_delay_max_ms
				}
				continue
			} else {
				break
			}

		} else {
			set ok 1
			break
		}
	}

	if {!$ok} {
		error $err_msg $err_code $err_info
	}

	core::log::write INFO {OBSS send_request: success; $req_abbrev time_taken=$time_taken response_footer=$response_footer_str}

	# Cache response

	if {$ARGS(-cache_time_secs) > 0} {
		_store_cached_response $cache_key $response_record $ARGS(-cache_time_secs)
	}

	return $response_record
}

#
# Examples:
#   _subst_resource_params \
#     "/Drilldown/1.0/NextNEventForClass/3/~%x" \
#     {x class {1 2 3}}
#   => /Drilldown/1.0/NextNEventForClass/3/1,2,3
# 
#   _subst_resource_params \
#     "/Drilldown/1.0/Event/~%myevents" \
#     {myevents events {1 2 3 4 5 6 7 8 9 10 11 12}}
#   => /Drilldown/1.0/Event/~ids-r5gh6Rui-348t8tQs
#
proc core::siteserver::_subst_resource_params {resource resource_params} {

	set max_idset_entries 10

	# Validate and decode the list of parameters we've been given

	array set PARAM [list]
	array set UNUSED_PARAM [list]
	foreach {name record_type record_ids} $resource_params {
		set PARAM($name) [list $record_type $record_ids]
		set UNUSED_PARAM($name) 1
	}

	# Find the parameter expressions in the resource string.

	set param_re {~%[A-Za-z0-9_]}
	set param_posns [regexp -all -inline -indices $param_re $resource]

	# Substitute the parameter expressions.

	set last_idx       0
	set subst_resource ""
	foreach param_posn $param_posns {
		lassign $param_posn start_idx end_idx
		append subst_resource [string range $resource $last_idx [expr {$start_idx-1}]]
		set param_expr [string range $resource $start_idx $end_idx]
		set param_name [string range $param_expr 2 end]
		if {![info exists PARAM($param_name)]} {
			error "no value given for resource param $param_expr"
		} else {
			lassign $PARAM($param_name) record_type record_ids
			if {[llength $record_ids] <= $max_idset_entries} {
				append subst_resource [_join_ids $record_ids]
			} else {
				append subst_resource \
				  [create_idset_token -record_type $record_type \
				    -record_ids $record_ids]
			}
			unset -nocomplain UNUSED_PARAM($param_name)
		}
		set last_idx [expr {$end_idx + 1}]
	}
	append subst_resource [string range $resource $last_idx end]

	if {[array size UNUSED_PARAM]} {
		error "unused resource_params: [array names UNUSED_PARAM]"
	}

	return $subst_resource
}

# Add a unique string to each request so that support can find them
# in the SiteServer logs.
proc core::siteserver::_correlate_request_url {request_url} {
	variable CFG
	
	if {[string first "?" $request_url] >= 0} {
		append request_url "&"
	} else {
		append request_url "?"
	}

	append request_url "correlationId=[urlencode $CFG(correlation_prefix)-[OT_UniqueId]]"

	return $request_url
}

proc core::siteserver::_mk_cache_key {request_cache_key} {
	# Some of the requests have rather a lot of params - possibly
	# too long to be a suitable cache key when using memcache, so
	# we take a digest of them.
	return "core::siteserver::response,[sha1 $request_cache_key]"
}

proc core::siteserver::_get_cached_response {request_cache_key} {
	variable CFG
	
	if {$CFG(cache_type) eq "none"} {
		return [list 0]
	}

	set actual_cache_key [_mk_cache_key $request_cache_key]
	
	if {[catch {
		if {$CFG(cache_type) eq "nodist"} {
			set response_record [asFindString -nodist $actual_cache_key]
		} else {
			set response_record [asFindString $actual_cache_key]
		}
	}]} {
		return [list 0]
	} else {
		core::log::write DEBUG {OBSS _get_cached_response: found cache entry}
		return [list 1 $response_record]
	}
}

proc core::siteserver::_store_cached_response {request_cache_key response_record cache_time_secs} {
	variable CFG
	if {$CFG(cache_type) eq "none"} {
		return
	}
	
	set actual_cache_key [_mk_cache_key $request_cache_key]
	
	if {[catch {
		if {$CFG(cache_type) eq "nodist"} {
			asStoreString -nodist $response_record $actual_cache_key $cache_time_secs
		} else {
			asStoreString $response_record $actual_cache_key $cache_time_secs
		}
	} msg]} {
		core::log::write ERROR {OBSS _store_cached_response: unable to store in response cache: $msg}
	}
}

proc core::siteserver::_get_connection {} {
	variable CONN
	variable SSL_OPTS
	
	if {![info exists CONN] || $CONN eq ""} {
		# TODO - we don't yet have a version of ot::ssclient that
		# supports the timeout options.
		set CONN [ot::ssclient::open_connexion]
		if {[llength $SSL_OPTS]} {
			ot::ssclient::set_ssl_options $CONN {*}$SSL_OPTS
		}
	}
	return $CONN
}

proc core::siteserver::_close_connection {} {
	variable CONN
	
	if {[info exists CONN] && $CONN ne ""} {
		if {[catch {
			ot::ssclient::close_connexion $CONN
		} msg]} {
			core::log::write INFO {OBSS _close_connection: unable to close connection: $msg}
		}
		set CONN ""
	}
}

core::args::register \
	-proc_name core::siteserver::create_idset_token \
	-desc      {Create a SiteServer idset token} \
	-returns   {The idset token string} \
	-args      [list \
		[list -arg -record_type -mand 1 -check STR_ANY  -desc {}] \
		[list -arg -record_ids  -mand 1 -check LIST_ANY -desc {}] \
	]

proc core::siteserver::create_idset_token {args} {
	array set ARGS [core::args::check core::siteserver::create_idset_token {*}$args]

	set num_record_ids [llength $ARGS(-record_ids)]
	set record_ids_str [_join_ids $ARGS(-record_ids)]

	set response_dict \
	  [send_request \
	    -resource /Common/1.0/IdSetToken \
	    -body_params [list recordType $ARGS(-record_type) \
	                       recordIds  $record_ids_str]]

	set idset_token_record \
	  [record_child -record $response_dict -record_type idSetToken]

	set idset_token [record_id -record $idset_token_record]

	core::log::write INFO \
	  {OBSS create_idset_token: created idset_token $idset_token containing\
	   $num_record_ids $ARGS(-record_type) ids}

	return $idset_token
}

proc core::siteserver::_join_ids {record_ids} {
	
	if {![llength $record_ids]} {
		return ""
	} else {
		set record_ids [lsort -dictionary -unique $record_ids]
		if {[regexp {[\\,]} $record_ids]} {
			# escape commas and backslashes
			set ids $record_ids
			set record_ids [list]
			foreach id $ids {
				lappend record_ids [string map {"," "\\," "\\" "\\\\"} $id]
			}
		}
		return "[join $record_ids ,],"
	}
}

core::args::register \
	-proc_name core::siteserver::cleanup \
	-desc      {Release transient resources used by this package (e.g. close connections, purge caches).} \
	-returns   {Nothing} \
	-args      [list]

proc core::siteserver::cleanup {args} {
	array set ARGS [core::args::check core::siteserver::cleanup {*}$args]

	_close_connection

	return
}

core::args::register \
	-proc_name core::siteserver::record_type \
	-desc      {Get the record-type of a given record.} \
	-returns   {The record-type name.} \
	-args      [list \
		[list -arg -record -mand 1 -check OBSSREC -desc {A record (as returned by send_request or record_children)}] \
	]

proc core::siteserver::record_type {args} {
	array set ARGS [core::args::check core::siteserver::record_type {*}$args]
	return [lindex $ARGS(-record) 0]
}

core::args::register \
	-proc_name core::siteserver::record_id \
	-desc      {Get the record-id of a given record.} \
	-returns   {The record id, or throws an error if the record has no id} \
	-args      [list \
		[list -arg -record -mand 1 -check OBSSREC -desc {A record (as returned by send_request or record_children)}] \
	]

proc core::siteserver::record_id {args} {
	array set ARGS [core::args::check core::siteserver::record_id {*}$args]
	return [dict get [lindex $ARGS(-record) 1] id]
}

# Examples:
#
#    Retrieve and bind up some fields of a class record:
#
#    set response_record \
#     [send_request -resource Drilldown/1.0/Class/1]
#    set class_record \
#      [record_child -record $response_record -record_type class]
#    set class_dict [record_dict -record $class_record]
#    tpBindString CLASS_ID [dict get $class_dict id]
#    tpBindString CLASS_NAME [dict get $class_dict name]
#    tpBindString CATEGORY [dict get $class_dict categoryCode]
#
#    Loop over the fields of a record: (ignoring any children entry)
#
#    set response_record \
#     [send_request -resource Drilldown/1.0/Class/1]
#    set class_record \
#      [record_child -record $response_record -record_type class]
#    set class_dict \
#      [record_dict -record $class_record -with_children false]
#    dict for {field_name field_value} $class_dict {
#      puts "$field_name => $field_value"
#    }
#

core::args::register \
	-proc_name core::siteserver::record_dict \
	-desc      {Get a dictionary of the fields of the given record.} \
	-returns   {A dictionary whose keys are the field names and whose values\
				are the field values (and possibly an additional children entry;\
				see -with_children arg)} \
	-args      [list \
		[list -arg -record        -mand 1 -check OBSSREC            -desc {A record (as returned by send_request or record_children)}] \
		[list -arg -with_children -mand 0 -check BOOL    -default 1 -desc {For records that contain other records, whether to include the "children" entry in the dict or not. The value of the children entry if present will be a list of child records as returned by the record_children proc. By default it is included since it is cheaper to include it than it is to remove it.}] \
	]

proc core::siteserver::record_dict {args} {
	
	array set ARGS [core::args::check core::siteserver::record_dict {*}$args]
	
	set raw_dict [lindex $ARGS(-record) 1]
	
	if {$ARGS(-with_children)} {
		return $raw_dict
	} else {
		return [dict remove $raw_dict children]
	}
}

core::args::register \
	-proc_name core::siteserver::record_children \
	-desc      {Get the child records of the given record (if any).}\
	-returns   {A list of zero or more records.} \
	-args      [list \
		[list -arg -record      -mand 1 -check OBSSREC             -desc {A record (as returned by send_request or record_children)}] \
		[list -arg -record_type -mand 0 -check STR_ANY -default {} -desc {If specified, only children of this record-type will be returned}] \
	]

proc core::siteserver::record_children {args} {
	
	array set ARGS [core::args::check core::siteserver::record_children {*}$args]
	
	set record_dict [lindex $ARGS(-record) 1]
	
	if {[catch {
		set children [dict get $record_dict children]
	}] || [llength $children] == 0} {
		return [list]
	}

	if {$ARGS(-record_type) eq ""} {
		return $children
	} else {
		set saved_children [list]
		set desired_record_type $ARGS(-record_type)
		foreach child_record $children {
			if {[lindex $child_record 0] eq $desired_record_type} {
				lappend saved_children $child_record
			}
		}
		return $saved_children
	}
}

core::args::register \
	-proc_name core::siteserver::record_child \
	-desc      {Get one child record of the given record.}\
	-returns   {A record, or throws an error if the record does not\
              contain exactly one record of the given record-type.} \
	-args      [list \
		[list -arg -record      -mand 1 -check OBSSREC  -desc {A record (as returned by send_request or record_children)}] \
		[list -arg -record_type -mand 1 -check STR_ANY  -desc {The record-type of the child to be returned}] \
	]

proc core::siteserver::record_child {args} {
	
	array set ARGS [core::args::check core::siteserver::record_child {*}$args]
	
	set children \
	  [record_children -record $ARGS(-record) \
	    -record_type $ARGS(-record_type)]

	if {[llength $children] != 1} {
		error "not exactly one child record of given record-type (got [llength $children])"
	} else {
		return [lindex $children 0]
	}
}
