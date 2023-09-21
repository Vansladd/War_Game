# (C) 2015 Orbis Technology Ltd. All rights reserved.
#
# Dynatrace API wrapper
#
# Configuration:
#
# Synopsis:
#     package require core::dynatrace ?1.0?
#
set pkg_version 1.0
package provide core::dynatrace $pkg_version

# Dependencies
package require core::check      1.0
package require core::args       1.0

core::args::register_ns \
	-namespace core::dynatrace \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args] \
	-docs      util/dynatrace.xml

namespace eval core::dynatrace {

	variable CFG

	set CFG(init)      0
	set CFG(available) 0
}

core::args::register \
	-proc_name core::dynatrace::init \
	-body {
		variable CFG

		# already initialised
		if {$CFG(init)} {
			return
		}

		set CFG(available) [expr {
			![catch { package present OT_Dynatrace }]
		}]

		set CFG(init) 1
	}

# Are the dynatrace libraries available
core::args::register \
	-proc_name core::dynatrace::is_available \
	-body {
		variable CFG
		return $CFG(available)
	}

# Register entering a procedure
core::args::register \
	-proc_name core::dynatrace::enter \
	-desc {Register entering a procedure} \
	-args [list \
		[list -arg -args  -mand 1 -check ANY             -desc {List of arguments passed to the calling procedure}] \
		[list -arg -frame -mand 0 -check INT -default -1 -desc {Frame in the stack to get the proc name from}] \
	] \
	-body {
		variable CFG

		if (!$CFG(available)) {
			return
		}

		set frame $ARGS(-frame)
		set cmd   [dict get [info frame $frame] cmd]

		set serial_no [ot::dynatrace::enter \
			$cmd \
			[namespace qualifiers $cmd] \
			[dict get [info frame $frame] line] \
			{*}$ARGS(-args)]

		return $serial_no
	}

# Register an exit exception
core::args::register \
	-proc_name core::dynatrace::exit_exception \
	-desc {Register an exit exception} \
	-args [list \
		[list -arg -msg       -mand 1 -check ANY             -desc {Exception message}] \
		[list -arg -serial_no -mand 1 -check UINT            -desc {Serial number associated with enter invocation}] \
		[list -arg -frame     -mand 0 -check INT -default -1 -desc {Frame in the stack to get the proc name from}] \
	] \
	-body {
		variable CFG

		if (!$CFG(available)) {
			return
		}

		set frame $ARGS(-frame)
		set cmd   [dict get [info frame $frame] cmd]

		ot::dynatrace::exit_exception \
			$cmd \
			$serial_no
			$ARGS(-msg)
	}

# Register exiting a procedure
core::args::register \
	-proc_name core::dynatrace::exit \
	-desc {Register an exit} \
	-args [list \
		[list -arg -serial_no -mand 1 -check UINT            -desc {Serial number associated with enter invocation}] \
		[list -arg -result    -mand 0 -check ANY             -desc {Procedure return information}] \
		[list -arg -frame     -mand 0 -check INT -default -1 -desc {Frame in the stack to get the proc name from}] \
	] \
	-body {
		variable CFG

		if (!$CFG(available)) {
			return
		}

		set frame $ARGS(-frame)
		set cmd   [dict get [info frame $frame] cmd]

		ot::dynatrace::exit \
			$cmd \
			$serial_no
			$ARGS(-result)
	}
