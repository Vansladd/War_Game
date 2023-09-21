# Copyright (C) 2012 Orbis Technology Ltd. All Rights Reserved.
#
# Experian QAS interface
#
# Synopsis:
#   QAS is an XML/SOAP service that provides address lookups
#
set pkg_version 1.0
package provide core::api::qas $pkg_version

# Dependencies
package require tdom

package require core::log      1.0
package require core::xml      1.0
package require core::args     1.0
package require core::check    1.0
package require core::socket   1.0

core::args::register_ns \
	-namespace core::api::qas \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::xml \
		core::args \
		core::check \
		core::socket] \
	-docs xml/api/qas.xml

namespace eval core::api::qas {
	variable CORE_DEF

	set CORE_DEF(addr_str)    [list -arg -addr_str    -mand 1 -check ASCII             -desc {The address string to search for}]
	set CORE_DEF(qas_country) [list -arg -qas_country -mand 0 -check ASCII -default {} -desc {The three letter country code used for the QAS search}]
	set CORE_DEF(layout)      [list -arg -layout      -mand 0 -check ASCII -default {} -desc {The layout mode for results}]
	set CORE_DEF(moniker)     [list -arg -moniker     -mand 1 -check ASCII             -desc {id for QAS to identify a point in the search process}]
}

# Register qas interface.
core::args::register \
	-interface core::api::qas::init



core::args::register \
	-interface core::api::qas::do_singleline_search \
	-desc      {Do a QAS singleline search for address completion} \
	-returns   ASCII \
	-args      [list \
			$::core::api::qas::CORE_DEF(addr_str) \
			$::core::api::qas::CORE_DEF(qas_country) \
			$::core::api::qas::CORE_DEF(layout) \
	]



core::args::register \
	-interface core::api::qas::do_intuitive_search \
	-desc      {Do a QAS intuitive search for address completion} \
	-returns   ASCII \
	-args      [list \
			$::core::api::qas::CORE_DEF(addr_str) \
			$::core::api::qas::CORE_DEF(qas_country) \
			$::core::api::qas::CORE_DEF(layout) \
	]



core::args::register \
	-interface core::api::qas::do_verification_search \
	-desc      {Do a QAS search for address completion using Experian address format} \
	-returns   ASCII \
	-args      [list \
			$::core::api::qas::CORE_DEF(addr_str) \
			$::core::api::qas::CORE_DEF(qas_country) \
			$::core::api::qas::CORE_DEF(layout) \
	]



core::args::register \
	-interface core::api::qas::do_search_authenticate \
	-desc      {Do a QAS authenticate search} \
	-returns   ASCII \
	-args      [list \
			[list -arg -addr_list   -mand 1 -check ASCII             -desc {address array}] \
			[list -arg -field_list  -mand 0 -check ASCII -default {} -desc {field list to limit what array items get used}] \
			$::core::api::qas::CORE_DEF(qas_country) \
	]



core::args::register \
	-interface core::api::qas::do_refine \
	-desc      {Refine search, picked from partial addresses returned by initial search} \
	-returns   ASCII \
	-args      [list \
			$::core::api::qas::CORE_DEF(moniker) \
			[list -arg -level   -mand 0 -check UINT -default 0 -desc {id for recursion level}]\
	]



core::args::register \
	-interface core::api::qas::do_get_address \
	-desc      {Get the final, formatted address} \
	-returns   ASCII \
	-args      [list \
			$::core::api::qas::CORE_DEF(moniker) \
			$::core::api::qas::CORE_DEF(layout) \
	]

