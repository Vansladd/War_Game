# $Id: gc.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
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
#   package require util_gc ?4.5?
#
# Configuration:
#	GC_COLLECT   - collect garbage, rather than just report it; provided as a
#	               short-term fix if garbage collection
#                  causes any problem and should always be one (1)
#	GC_AUTOMATIC - attempt to automatically collect global variables; this
#	               should not be used, unless you are 100% sure that none of
#	               your application code, or shared code relies on persistent
#	               global variables (0)
#
# Procedures:
#	ob_gc::init     - Initialise
#	ob_gc::mark     - Must be called at the end or during req_init
#	ob_gc::add      - Add a variable to be garbage collected
#	ob_gc::ignore   - Ignore a variable, do not clean it up
#	ob_gc::clean_up - Must be called at the beginning or during req_end
#

package provide util_gc 4.5



# Dependencies
#
package require util_log



# Variables
#
namespace eval ob_gc {

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



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Add one or more variables to be garbage collected at the end of the request.
# Variable names should be fully qualifed WRT namespaces, if not they will be
# assumed to be global.
#
proc ob_gc::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		collect   1
		automatic 0
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet "GC_[string toupper $n]" $v]
		}
	}

	if {$CFG(automatic)} {
		ob_log::write WARNING \
			{GC: automatically collecting globals at the end of each request}
	}

	set INIT 1
}



# Mark a variable to be ignored, if it's already cleaned up or is persistent.
#
# e.g. ob_gc::ignore PERSISTENT
#
#   varname - the name of the variable to ignore
#
proc ob_gc::ignore {varname} {

	variable ignored

	init

	if {[string first "::" $varname] != 0} {
		set varname "::$varname"
	}

	lappend ignored $varname
}



# Add one or more variables to be garbage collected at the end of the request.
#
#   args - the names of the variables
#
proc ob_gc::add args {

	variable marked

	init

	foreach varname $args {

		if { [string first :: $varname] != 0 } {
			set varname ::$varname
		}

		if {[lsearch $marked $varname] == -1} {
			ob_log::write DEV {GC: adding $varname}
			lappend marked $varname
		}
	}
}



# Stores what variables are currently in the global scope.
# These will be cleaned at the end of the request.
#
proc ob_gc::mark {} {

	variable CFG
	variable varz

	init

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
#   ob_gc::mark
#
proc ob_gc::clean_up {} {

	variable CFG
	variable varz
	variable marked
	variable ignored

	init

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

	ob_log::write DEV {GC: uncollected: $uncollected}

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
