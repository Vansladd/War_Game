# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Mechanism for defining plugins to extend the core packages.
# This works in conjunction with core::args and core::interface.
#
# Packages should define interfaces using core::interface::register
# core::plugin::set_proc defines a callback defined using core::args
# core::plugin::run_proc runs the callback defined using core::args

set pkg_version 1.0
package provide core::plugin $pkg_version

# Dependencies
package require core::interface      1.0
package require core::log            1.0
package require core::args           1.0

core::args::register_ns \
	-namespace core::plugin \
	-version   $pkg_version \
	-dependent [list core::log core::args core::interface]

namespace eval core::plugin {}

# Set a callback that matches an interface
core::args::register \
	-proc_name core::plugin::set_proc \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Interface defined by core::interface}] \
		[list -arg -proc_name -check ASCII -mand 1 -desc {Proc defined by core::args}] \
	]
proc core::plugin::set_proc args {
	variable CALLBACKS

	array set ARGS [core::args::check core::plugin::set_proc {*}$args]

	core::interface::check_proc {*}$args

	set interface [string trimleft [uplevel namespace origin $ARGS(-interface)] {::}]
	set proc_name [string trimleft [uplevel namespace origin $ARGS(-proc_name)] {::}]

	set CALLBACKS($interface) $proc_name
}

# Get the callback that has been set for an interface
core::args::register \
	-proc_name core::plugin::get_proc \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Interface}] \
	]
proc core::plugin::get_proc args {
	variable CALLBACKS

	array set ARGS [core::args::check core::plugin::get_proc {*}$args]

	set interface [string trimleft [uplevel namespace origin $ARGS(-interface)] {::}]

	if {![info exists CALLBACKS($interface)]} {
		return {}
	}

	return $CALLBACKS($interface)
}

# Run the procedure that implements the interface if one has been set
core::args::register \
	-proc_name core::plugin::run_proc \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Interface}] \
		[list -arg -args      -check ANY -mand 1 -desc {List of args for the proc}] \
	]
proc core::plugin::run_proc args {
	array set ARGS [core::args::check core::plugin::run_proc {*}$args]

	set interface [string trimleft [uplevel namespace origin $ARGS(-interface)] {::}]

	set proc_name [get_proc -interface $interface]

	if {$proc_name == {}} {
		return {}
	}

	return [core::interface::run_proc -interface $interface -proc_name $proc_name -args $ARGS(-args)]
}
