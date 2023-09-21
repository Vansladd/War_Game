# (C) 2011 Orbis Technology Ltd. All rights reserved.
#
# Safe API Model
#

load libOT_Tcl.so
set pkgVersion 1.0
package provide core::safe $pkgVersion

package require core::check 1.0
package require core::args  1.0


core::args::register_ns \
	-namespace core::safe \
	-version   $pkgVersion \
	-docs      util/safe.xml

namespace eval core::safe {}

core::args::register \
	-proc_name core::safe::exec \
	-args      [list \
		[list -arg -scope   -mand 1 -check ASCII -desc {The scope in which to run this. Must be one of global|caller|current|<N>. If <N> then it must be an integer specifying a level relative to whatever called the exec proc.}] \
		[list -arg -command -mand 1 -check ASCII -desc {The name of the command to run.}] \
		[list -arg -args    -mand 1 -check LIST  -desc {The arguments to be passed.}] \
	]

proc core::safe::exec { args } {

	array set my_args [core::args::check core::safe::exec {*}$args]

	if {$my_args(-scope) == "global"} {
		return [uplevel #0 $my_args(-command) $my_args(-args)]

	} elseif {$my_args(-scope) == "current"} {
		return [uplevel 1 $my_args(-command) $my_args(-args)]

	} elseif {$my_args(-scope) == "caller" || [string is integer -strict $my_args(-scope)]} {
		# Remember we want to go up one level from the level specified.
		# This is because the numeric level is relative to whatever called this proc.
		# And this proc is one removed from that.
		#
		if {$my_args(-scope) == "caller"} {
			set n 2
		} else {
			# If not 'caller', then it must be an int.
			set n [expr {1 + $my_args(-scope)}]
		}

		if {[info level] < $n} {
			error "Invalid scope: Not enough info levels for $my_args(-scope)"
		}

		return [uplevel $n $my_args(-command) $my_args(-args)]

	} else {
		error "Invalid scope: $my_args(-scope)"

	}
}


core::args::register \
	-proc_name core::safe::escape_tcl_regexp \
	-desc      {Escape a string so that it can be used within a Tcl regular expression without any special meaning.} \
	-args [list \
		[list -arg -str -mand 1 -check ANY -desc {String to be escaped.}] \
	] \
	-body {
		set str $ARGS(-str)
		set map {* {\*} + {\+} ? {\?} \{ {\{} \} {\}} ( {\(} ) {\)} {[} {\[} {]} {\]} . {\.} \\ {\\} ^ {\^} \$ {\$}}
		return [string map $map $str]
	}
