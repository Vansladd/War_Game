# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Iovation functionality and interfaces
#
set pkg_version 1.0
package provide core::verification::iovation $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0

core::args::register_ns \
	-namespace core::verification::iovation \
	-version   $pkg_version \
	-desc      {API for Iovation Check} \
	-dependent [list \
		core::log \
		core::args \
		core::check] \
	-docs xml/verification/iovation.xml

namespace eval core::verification::iovation {

}

# Initialize Iovation Framework
core::args::register \
	-interface core::verification::iovation::init

core::args::register \
	-interface core::verification::iovation::process_result \
	-desc      {Processes results retrieved from iovation check} \
	-returns   ASCII \
	-args [list \
		[list -arg -results_list -mand 1 -check ANY -desc {Result list from iovation check}] \
	]



core::args::register \
	-proc_name core::verification::iovation::gen_rest_url \
	-desc {This will return the RESTful URLs for iovation administrative screens} \
	-args [list \
		[list -arg -call_alias -mand 1 -check STRING -desc {the alias which identifies which url needs to return}] \
		[list -arg -value_list -mand 0 -check ANY -default {} -desc {List of values which will be used to create the url}] \
	] \
	-body {

		set rest_url {}
		array set REST_URLS [OT_CfgGet IOV_REST_URLS ""]

		if {[info exists REST_URLS($ARGS(-call_alias))]} {

			set rest_url $REST_URLS($ARGS(-call_alias))

			# Check and substitute values from the value_list
			# for %s place holders
			if {[llength $ARGS(-value_list)] > 0} {
				set idx 0
				while {[regexp {%s} $rest_url] && [llength $ARGS(-value_list)] > $idx} {
					regsub {%s} $rest_url [lindex $ARGS(-value_list) $idx] rest_url
					incr idx
				}
			}
		}

		return $rest_url
	}


