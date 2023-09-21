# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Mechanism for defining extendable interfaces.
#
# Any procedures that implement all the mandatory args for the interface
# can be run using run_proc.
#
# Optional args can be added without affecting existing consumers of the
# interface.

set pkg_version 1.0
package provide core::interface $pkg_version

# Dependencies
package require core::log            1.0
package require core::args           1.0
package require core::check          1.0

core::args::register_ns \
	-namespace core::interface \
	-version   $pkg_version \
	-dependent [list core::log core::args core::check]

namespace eval core::interface {
	variable INTERFACE
	array set INTERFACE {}
}

# Register an interface.
# This defines a mediator proc using core::args.
core::args::register \
	-proc_name core::interface::register \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Fully qualified interface name. This must use a namespace registered to core::args and must not be the same as any previously defined interfaces or procedures.}] \
		[list -arg -args -check ANY -mand 0 -desc {Full list of args the implementing procedure can define, in the same format as core::args::register}] \
		[list -arg -returns -check ANY -mand 0 -default ANY -desc {Type the return value must satisfy. An exception will be raised at runtime if the return value does not match.}] \
	]
proc core::interface::register args {
	variable INTERFACE
	array set ARGS [core::args::check core::interface::register {*}$args]

	set interface "[string trimleft $ARGS(-interface) {::}]"
	set return_type $ARGS(-returns)

	if {[uplevel info procs $interface] != {}} {
		core::log::write ERROR {Interface $interface already exists}
		error "Interface already exists"
	}

	if {![lindex [core::check::command_for_type $return_type] 0]} {
		core::log::write ERROR {Invalid type for return value $ARGS(-returns)}
		error "Invalid type for return value $ARGS(-returns)"
	}

	if {[catch {
			uplevel core::args::register -proc_name $interface -args [list $ARGS(-args)]
			uplevel proc $interface [list {args}] [list {
				core::log::write DEV {Cannot call $interface. Use core::interface::run_proc}
				error "Interface $interface cannot be called directly"
			}]
	} err]} {
		core::log::write ERROR {Unable to define interface: $err}
		error "Unable to define interface: $err" $::errorInfo
	}

	set INTERFACE($interface) $return_type
}

# Check that the callback matches its interface before it is called
core::args::register \
	-proc_name core::interface::check_proc \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Interface}] \
		[list -arg -proc_name -check ASCII -mand 1 -desc {Proc name}] \
	]
proc core::interface::check_proc args {
	array set ARGS [core::args::check core::interface::check_proc {*}$args]

	set proc_name $ARGS(-proc_name)
	set interface "[string trimleft $ARGS(-interface) {::}]"

	# Check interface exists
	if {[catch {set interface_list [core::args::get_arg_list $interface]} err]} {
		core::log::write ERROR {Interface $interface does not exist: $err}
		error INVALID_INTERFACE
	}

	# Check proc is registered with core::args
	if {[catch {set proc_list [core::args::get_arg_list $proc_name]} err]} {
		core::log::write ERROR {Proc $proc_name not registered with core::args: $err}
		error INVALID_PROC
	}

	# Make sure the difference between the two sets of args contains
	# no mandatory args
	array set PROC_ARGS      [list]
	array set INTERFACE_ARGS [list]

	foreach arg $proc_list {
		set PROC_ARGS([dict get $arg -arg]) [dict get $arg -mand]
	}
	foreach arg $interface_list {
		set INTERFACE_ARGS([dict get $arg -arg]) [dict get $arg -mand]
	}

	foreach {arg required} [array get PROC_ARGS] {
		if {[info exists INTERFACE_ARGS($arg)]} {
			unset INTERFACE_ARGS($arg)
		} elseif {$required} {
			core::log::write ERROR {Proc $proc_name does not meet the interface $interface - unknown required arg $arg}
			error INVALID_ARGS
		}
	}

	foreach {arg required} [array get INTERFACE_ARGS] {
		if {$required} {
			core::log::write ERROR {Proc $proc_name does not meet the interface $interface - missing arg $arg}
			error INVALID_ARGS
		}
	}
}

# Run -proc_name as an implementor of -interface.
# This ensures that all mandatory arguments are present but filters out
# any optional arguments that are not supported by -proc_name.
core::args::register \
	-proc_name core::interface::run_proc \
	-args [list \
		[list -arg -interface -check ASCII -mand 1 -desc {Interface defined by core::interface}] \
		[list -arg -proc_name -check ASCII -mand 0 -desc {Proc name defined by core::args, supporting all mandatory args of -interface.}] \
		[list -arg -args -check ANY -mand 0 -desc {Name value pairs to pass to -proc_name}] \
	]
proc core::interface::run_proc args {
	variable INTERFACE
	array set ARGS [core::args::check core::interface::run_proc {*}$args]

	set interface "[string trimleft $ARGS(-interface) {::}]"
	set proc_name $ARGS(-proc_name)
	set args      $ARGS(-args)

	if {![info exists INTERFACE($interface)]} {
		core::log::write ERROR {Interface $interface not registered}
		error INVALID_INTERFACE
	}

	# Get args supported by proc
	if {[catch {set arg_list [core::args::get_arg_list $proc_name]} err]} {
		core::log::write ERROR {$ARGS(-proc_name) not registered? $err}
		error INVALID_PROC
	}

	core::log::write INFO {Checking interface $interface}

	# Filter out args not supported by the proc
	set supported_args [dict create]
	foreach arg $arg_list {
		set arg [dict get $arg -arg]
		if {[dict exists $args $arg]} {
			dict set supported_args $arg [dict get $args $arg]
		}
	}

	# Check the remaining args match the interface.
	core::log::write DEBUG {Checking args $supported_args}
	if {[catch {
		set interface_args [core::args::check $interface {*}$supported_args]
	} err]} {
		core::log::write ERROR {Invalid args for $interface: $err}
		error INVALID_ARGS $::errorInfo
	}

	# The interface may have set default args,
	# but these should only be used if the proc supports it
	foreach arg $arg_list {
		set arg [dict get $arg -arg]
		if {[dict exists $interface_args $arg]} {
			dict set supported_args $arg [dict get $interface_args $arg]
		}
	}

	set ret [$ARGS(-proc_name) {*}$supported_args]

	# Validate return value
	set return_type $INTERFACE($interface)
	if {[catch {
		set valid [core::check::check_value $ret {AND} [list $return_type]]
	} err]} {
		core::log::write ERROR {Unable to validate return value for $interface: $err}
		error INVALID_RETURN $::errorInfo
	}

	if {!$valid} {
		core::log::write ERROR {Invalid return value for $interface: expected $return_type}
		error INVALID_RETURN
	}

	return $ret
}
