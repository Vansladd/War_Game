# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Garbage Collection
#
# Clean up garbage created during requests.
#
# If configured to this will use interpreter introspection to analyse what
# global arrays and variables exist at the end of a request and then clean
# them up. This particularly picks up on globals used with tpBindVar.
#
# This package supports lazy initialisation.
#
# Synopsis:
#   package require core::gc ?1.0?
#
# Configuration:
#   GC_COLLECT   - collect garbage, rather than just report it; provided as a
#                  short-term fix if garbage collection
#                  causes any problem and should always be one (1)
#   GC_AUTOMATIC - attempt to automatically collect global variables; this
#                  should not be used, unless you are 100% sure that none of
#                  your application code, or shared code relies on persistent
#                  global variables (0)
#
# Procedures:
#   core::gc::init     - Initialise
#   core::gc::mark     - Must be called at the end or during req_init
#   core::gc::add      - Add a variable to be garbage collected
#   core::gc::ignore   - Ignore a variable, do not clean it up
#	core::gc::clean_up - Must be called at the beginning or during req_end
#
set pkg_version 1.0
package provide core::gc 1.0


# Dependencies
package require core::log


# Variables
namespace eval core::gc {

	variable CFG
	variable INIT 0

	# variables marked for collection
	#
	variable marked [list]

	# variables to ignore during collection
	#
	variable ignored [list]

	# variables that appeared at the beginning of a request
	#
	variable varz
}


core::args::register_ns \
	-namespace core::gc \
	-version   $pkg_version \
	-dependent [list core::log core::args] \
	-docs      util/gc.xml


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Add one or more variables to be garbage collected at the end of the request.
# Variable names should be fully qualifed WRT namespaces, if not they will be
# assumed to be global.
#

core::args::register \
	-proc_name core::gc::init \
	-desc {Add one or more variables to be garbage collected at the end of
		the request. Variable names should be fully qualifed WRT
		namespaces, if not they will be assumed to be global.} \
	-returns NONE \
	-args [list \
		[list -arg -collect   -mand 0 -check BOOL -default 1 -default_cfg GC_COLLECT   -desc {Clear up variables at the end of the request}] \
		[list -arg -automatic -mand 0 -check BOOL -default 0 -default_cfg GC_AUTOMATIC -desc {automatically collect globals at the end of each request}] \
	] \
	-body {
		variable CFG
		variable INIT

		set CFG(collect)   $ARGS(-collect)
		set CFG(automatic) $ARGS(-automatic)

		if {$INIT} {
			return
		}

		core::log::init

		if {$CFG(automatic)} {
			core::log::write WARNING {GC: automatically collecting globals at the end of each request}
		}

		set INIT 1
	}

# Mark a variable to be ignored, if it's already cleaned up or is persistent.
#
# e.g. core::gc::ignore PERSISTENT
#
#   varname - the name of the variable to ignore
#

core::args::register \
	-proc_name core::gc::ignore \
	-desc {Mark a variable to be ignored, if it is already cleaned up or is
		persistent} \
	-returns NONE

proc core::gc::ignore {varname} {

	variable INIT
	variable ignored

	if {!$INIT} {
		init
	}

	if {[string first "::" $varname] != 0} {
		set varname "::$varname"
	}

	lappend ignored $varname
}



# Add one or more variables to be garbage collected at the end of the request.
#
#   args - the names of the variables
#

core::args::register \
	-proc_name core::gc::add \
	-desc {Add one or more variables to be garbage collected at the end of
		the request} \
	-returns NONE

proc core::gc::add args {

	variable INIT
	variable marked

	if {!$INIT} {
		init
	}

	foreach varname $args {

		if { [string first :: $varname] != 0 } {
			set varname ::$varname
		}

		if {[lsearch $marked $varname] == -1} {
			core::log::write DEV {GC: adding $varname}
			lappend marked $varname
		}
	}
}



# Stores what variables are currently in the global scope.
# These will be cleaned at the end of the request.
#

core::args::register \
	-proc_name core::gc::mark \
	-desc {Stores what variables are currently in the global scope.
		These will be cleaned at the end of the request.} \
	-returns NONE

proc core::gc::mark {} {

	variable CFG
	variable INIT
	variable varz

	if {!$INIT} {
		init
	}

	if {!$CFG(automatic)} {
		return
	}

	foreach varname [info globals] {
		lappend varz "::$varname"
	}
}



# Clean up variables in the global scope that have appeared during the request.
#
# See also:
#   core::gc::mark
#

core::args::register \
	-proc_name core::gc::clean_up \
	-desc {Clean up variables in the global scope that have appeared during
		the request.} \
	-returns NONE

proc core::gc::clean_up {} {

	variable CFG
	variable INIT
	variable varz
	variable marked
	variable ignored

	if {!$INIT} {
		init
	}

	# A list of variable which exist, and should be collected
	set uncollected [list]

	foreach varname $marked {
		if {[info exists $varname] && [lsearch $ignored $varname] == -1} {
			lappend uncollected $varname
		}
	}

	# reset list of marked variables
	set marked [list]

	if {$CFG(automatic)} {
		foreach varname [info globals] {
			set varname "::$varname"
			# Variable did not exist at the beginning of the request
			if {[lsearch $varz $varname] == -1 && [info exists $varname] &&
				[lsearch $ignored $varname] == -1}  {
				lappend uncollected $varname
			}
		}
	}

	set varz [list]

	core::log::write DEV {GC: uncollected: $uncollected}

	# If we are not interested in clearing up the variable, then exit here
	if {!$CFG(collect)} {
		return
	}

	foreach varname $uncollected {
		if {[info exists $varname]} {
			unset $varname
		}
	}
}

