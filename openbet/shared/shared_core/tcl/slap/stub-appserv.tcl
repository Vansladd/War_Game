# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Stub utilities
#

set pkgVersion 1.0
package provide core::stub::appserv $pkgVersion

# Dependencies
package require core::log   1.0
package require core::check 1.0
package require core::args  1.0
package require core::stub  1.0

core::args::register_ns \
	-namespace core::stub::appserv \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::stub] \
	-docs      slap/stub-appserv.xml

# This package should not rely on a config file
namespace eval core::stub::appserv {

	variable  CFG
	array set CFG       [list \
							 init       0 \
							 child_id   0 \
							 req_id     1 \
							 group_id   0 \
							 group_name default]
	variable  SHM
	array set SHM       [list]

	variable  REQ_ENV
	array set REQ_ENV   [list]

	variable  REQ_ARGS
	array set REQ_ARGS  [list]

	variable  REQ_NAMES [list]

}

# ------------------------------------------------------------------------------

core::args::register \
	-proc_name core::stub::appserv::init \
	-args [list \
		[list -arg -force_init  -mand 0 -check BOOL  -default 0  -desc {Force initialisation}] \
		[list -arg -child_id    -mand 0 -check UINT  -default 0  -desc {Child id for asGetId}] \
		[list -arg -req_id      -mand 0 -check UINT  -default 1  -desc {Initial request id}] \
	]

proc core::stub::appserv::init args {

	variable CFG

	array set ARGS [core::args::check core::stub::appserv::init {*}$args]

	if {$CFG(init) && !$ARGS(-force_init)} {
		return
	}

	set CFG(child_id) $ARGS(-child_id)
	set CFG(req_id)   $ARGS(-req_id)
	set CFG(init) 1

	core::log::xwrite -msg {Initialising Appserver Stubbing} -colour green

	_set_overrides

}

core::args::register \
	-proc_name core::stub::appserv::set_req_id \
	-args [list \
		[list -arg -req_id -mand 1 -check BOOL -desc {Set the request id}] \
	]

proc core::stub::appserv::set_req_id args {

	variable CFG

	array set ARGS [core::args::check core::stub::appserv::init {*}$args]

	set CFG(req_id) $ARGS(-req_id)

}


core::args::register \
	-proc_name core::stub::appserv::clear_shm \
	-args      [list]\
	-desc      {Clear our stubbed SHM}\
	-body      {
		variable SHM
		unset -nocomplain SHM
	}

# ------------------------------------------------------------------------------
# Replacements for the missing appserv procs
#

proc ::core::stub::appserv::_set_overrides {} {

	core::stub::define_procs -proc_definition \
		[list \
			:: asSetAct             \
			:: asRestart            \
			:: asGetGroupId         \
			:: asGetGroupName       \
			:: asGetId              \
			:: asStoreRs            \
			:: asFindRs             \
			:: asStoreString        \
			:: asFindString         \
			:: asSetReqAccept       \
			:: asSetDefaultAction   \
			:: asSetTimeoutProc     \
			:: asSetTimeoutInterval \
			:: reqGetNumVals        \
			:: reqGetNthName        \
			:: reqGetNthVal         \
			:: reqGetNumArgs        \
			:: reqGetNthArg         \
			:: reqGetArg            \
			:: reqSetArg            \
			:: reqGetArgs           \
			:: reqGetEnvNames       \
			:: reqGetEnv            \
			:: reqSetEnv            \
			:: reqGetId             \
			:: tpBufFlush           \
			:: tpBufAddHdr          \
			:: tpBufCompress        \
			:: asPlayFile           \
		]

	core::stub::set_override \
		-proc_name ::asRestart \
		-body {
			core::log::write INFO {asRestart}
		}

	core::stub::set_override \
		-proc_name ::asGetGroupId \
		-body {
			return [core::stub::appserv::_asGetGroupId]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::asGetGroupName \
		-body {
			return [core::stub::appserv::_asGetGroupName]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::asGetId \
		-body {
			return [core::stub::appserv::_asGetId]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::asStoreRs \
		-body {
			core::stub::appserv::_asStoreRs {*}$args
		}

	core::stub::set_override \
		-proc_name ::asFindRs \
		-body {
			return [core::stub::appserv::_asFindRs {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::asStoreString \
		-body {
			core::stub::appserv::_asStoreString {*}$args
		}

	core::stub::set_override \
		-proc_name ::asFindString \
		-body {
			return [core::stub::appserv::_asFindString {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetNumVals \
		-body {
			return [core::stub::appserv::_reqGetNumVals {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetNthName \
		-body {
			return [core::stub::appserv::_reqGetNthName {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetNthVal \
		-body {
			return [core::stub::appserv::_reqGetNthVal {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetNumArgs \
		-body {
			return [core::stub::appserv::_reqGetNumArgs {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetNthArg \
		-body {
			return [core::stub::appserv::_reqGetNthArg {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetArg \
		-body {
			return [core::stub::appserv::_reqGetArg {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqSetArg \
		-body {
			core::stub::appserv::_reqSetArg {*}$args
		}

	core::stub::set_override \
		-proc_name ::reqGetArgs \
		-body {
			return [core::stub::appserv::_reqGetArgs {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetEnvNames \
		-body {
			return [core::stub::appserv::_reqGetEnvNames]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqGetEnv \
		-body {
			return [core::stub::appserv::_reqGetEnv {*}$args]
		} \
		-use_body_return 1

	core::stub::set_override \
		-proc_name ::reqSetEnv \
		-body {
			core::stub::appserv::_reqSetEnv {*}$args
		}

	core::stub::set_override \
		-proc_name ::reqGetId \
		-body {
			return [core::stub::appserv::_reqGetId]
		} \
		-use_body_return 1

}

#
# Get the Group Id - Always return 0
#
proc core::stub::appserv::_asGetGroupId args {

	if { [llength $args] != 0 } {
		error "Usage: asGetGroupId"
	}

	variable CFG

	array set OVERRIDE [core::stub::_get_override {} {}]

	if {$OVERRIDE(-found)} {
		core::log::write INFO {Handling Override}
	}

	return $CFG(group_id)
}

# Get the group name
proc core::stub::appserv::_asGetGroupName args {

	if { [llength $args] != 0 } {
		error "Usage: asGetGroupName"
	}

	variable CFG

	array set OVERRIDE [core::stub::_get_override {} {}]

	if {$OVERRIDE(-found)} {
		core::log::write INFO {Handling Override}
	}

	return $CFG(group_name)
}

#
# Get the Child Id - Always return 0
#
proc core::stub::appserv::_asGetId args {

	if { [llength $args] != 0 } {
		error "Usage: asGetId"
	}

	variable CFG

	array set OVERRIDE [core::stub::_get_override {} {}]

	if {$OVERRIDE(-found)} {
		core::log::write INFO {Handling Override}
	}

	return $CFG(child_id)
}

# Store a result-set in SHM
#
# @param str   - The string value
# @param name  - The name of the string
# @param cache - The cache time in seconds to keep the string in SHM
#
proc core::stub::appserv::_asStoreRs args {

	set nr_args [llength $args]

	if { $nr_args < 3 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 3 } { incr i } {

			switch -- [lindex $args $i] {

				-nodist {
				}

				-grace_time {
					incr i
				}

				default {
					break
				}

			}

		}

		if { $i != $nr_args - 3 } {

			set ok 0

		} else {

			lassign [lrange $args $i e] rs name expiry

			set ok [string is integer -strict $expiry]

		}

	}

	if { !$ok } {
		error "Usage: asStoreRs ?-nodist? ?-grace_time grace_time?\
			res_name cache_name cache_time"
	}

	variable SHM

	set SHM($name,value)  [db_flatten -string $rs]
	set SHM($name,expiry) [expr { [clock millis] + $expiry * 1000 }]

}

# Find a string in SHM
#
# @param name - The name of the result-set
#
proc core::stub::appserv::_asFindRs args {

	set nr_args   [llength $args]
	set with_info 0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			switch -- [lindex $args $i] {

				-expired -
				-copy    -
				-nodist  {
				}

				-alloc-sem {
					set sem_var    [lindex $args [incr i]]
				}
				-dist-status {
					set status_var [lindex $args [incr i]]
				}
				-with-info {
					set with_info 1
				}

				default {
					break
				}

			}

		}

		if { $i != $nr_args - 1 } {

			set ok 0

		} else {

			set ok 1

			lassign [lrange $args $i e] name

		}

	}

	if { !$ok } {
		error "Usage: asFindRs ?-expired? ?-copy? ?-with-info?\
			?-alloc-sem semVar? ?-nodist? ?-dist-status statusVar? name"
	}

	variable SHM

	if { [info exists SHM($name,value)] } {

		if { [clock millis] < $SHM($name,expiry) } {
			set value [db_unflatten $SHM($name,value)]
		} else {
			array unset SHM $name,*
		}

	}

	if { [info exists sem_var] } {
		set $sem_var 0
	}

	if { [info exists status_var] } {
		set $status_var NOT_CHECKED
	}

	if { ![info exists value] } {
		error "Could not find result-set $name" {} PURGED
	} else {

		if { $with_info } {
			lappend value OK 0
		}
		return $value

	}

}

# Store a string in SHM
#
# @param str   - The string value
# @param name  - The name of the string
# @param cache - The cache time in seconds to keep the string in SHM
#
proc core::stub::appserv::_asStoreString args {

	set nr_args [llength $args]

	if { $nr_args < 3 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 3 } { incr i } {

			switch -- [lindex $args $i] {

				-bin    -
				-utf8   -
				-nodist {
				}

				-grace_time {
					incr i
				}

				default {
					break
				}

			}

		}

		if { $i != $nr_args - 3 } {

			set ok 0

		} else {

			lassign [lrange $args $i e] value name expiry

			set ok [string is integer -strict $expiry]

		}

	}

	if { !$ok } {
		error "Usage: asStoreString ?-bin|-utf8? ?-nodist?\
			?-grace_time grace_time? string cache_name cache_time"
	}

	variable SHM

	set SHM($name,value)  $value
	set SHM($name,expiry) [expr { [clock millis] + $expiry * 1000 }]]

}

# Find a string in SHM
#
# @param name - The name of the string
#
proc core::stub::appserv::_asFindString args {

	set nr_args   [llength $args]
	set with_info 0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			switch -- [lindex $args $i] {

			    -bin     -
				-utf8    -
				-expired -
				-copy    -
				-nodist  {
				}

				-alloc-sem {
					set sem_var    [lindex $args [incr i]]
				}
				-dist-status {
					set status_var [lindex $args [incr i]]
				}
				-with-info {
					set with_info 1
				}

				default {
					break
				}

			}

		}

		if { $i != $nr_args - 1 } {

			set ok 0

		} else {

			set ok 1

			lassign [lrange $args $i e] name

		}

	}

	if { !$ok } {
		error "Usage: asFindString ?-bin|-utf8? ?-copy? ?-expired? ?-with-info?\
			?-alloc-sem semVar? ?-nodist? ?-dist-status statusVar? name"
	}

	variable SHM

	if { [info exists SHM($name,value)] } {

		if { [clock millis] < $SHM($name,expiry) } {
			set value $SHM($name,value)
		} else {
			array unset SHM $name,*
		}

	}

	if { [info exists sem_var] } {
		set $sem_var 0
	}

	if { [info exists status_var] } {
		set $status_var NOT_CHECKED
	}

	if { ![info exists value] } {
		error "Could not find string $name" {} PURGED
	} else {

		if { $with_info } {
			lappend value OK 0
		}
		return $value

	}

}

# Get no. of request keys
#
proc core::stub::appserv::_reqGetNumVals args {

	if { [llength $args] != 0 } {
		error "Usage: reqGetNumVals"
	}

	variable REQ_NAMES
	return [llength $REQ_NAMES]

}

# Get a request argument name
#
# @param -unsafe - The raw value should be returned (optional)
# @param -safe   - The safe value should be returned (optional)
# @param num     - The request name index
#
proc core::stub::appserv::_reqGetNthName args {

	set nr_args [llength $args]
	set meta    0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			switch -- [lindex $args $i] {

				-unsafe -
				-safe   {
				}
				default {
					break
				}

			}

		}

		if { $i != $nr_args - 1 } {
			set ok 0
		} else {
			set index [lindex $args $i]
			set ok [string is integer -strict $index]
		}

	}

	if { !$ok } {
		error "Usage: reqGetNthName ?-safe|-unsafe? num"
	}

	variable REQ_NAMES

	if { $index < [llength $REQ_NAMES] } {
		set name [lindex $REQ_NAMES $index]
	} else {
		set name ""
	}

	return $name

}

# Get a request argument
#
# @param -unsafe - The raw value should be returned (optional)
# @param -safe   - The safe value should be returned (optional)
# @param -meta   - The content-type and file-name (if any) should also be
#                  returned (optional)
# @param num     - The request name index
#
proc core::stub::appserv::_reqGetNthVal args {

	set nr_args [llength $args]
	set meta    0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			switch -- [lindex $args $i] {

				-unsafe -
				-safe   {
				}
				-meta {
					set meta 1
				}
				default {
					break
				}

			}

		}

		if { $i != $nr_args - 1 } {
			set ok 0
		} else {
			set index [lindex $args $i]
			set ok [string is integer -strict $index]
		}

	}

	if { !$ok } {
		error "Usage: reqGetNthVal ?-safe|-unsafe? ?-meta? num"
	}

	variable REQ_NAMES

	if { $index < [llength $REQ_NAMES] } {
		set name [lindex $REQ_NAMES $index]
	} else {
		set name ""
	}

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {
		set value [lindex $REQ_ARGS($name) 0]
	} else {
		set value ""
	}

	if { $meta } {
		lappend value "" ""
	}

	return $value

}

# Get no. of request arguments
#
# @param name - The request variable name
#
proc core::stub::appserv::_reqGetNumArgs args {

	if { [llength $args] != 1 } {
		error "Usage: reqGetNumArgs element"
	} else {
		lassign $args name
	}

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {
		set nr_args [llength $REQ_ARGS($name)]
	} else {
		set nr_args 0
	}

	return $nr_args

}

# Get a request argument
#
# @param -unsafe - The raw value should be returned (optional)
# @param -safe   - The safe value should be returned (optional)
# @param -meta   - The content-type and file-name (if any) should also be
#                  returned (optional)
# @param element - The request name
# @param num     - The request value index
#
proc core::stub::appserv::_reqGetNthArg args {

	set nr_args [llength $args]
	set meta    0

	if { $nr_args < 2 } {

		set ok 0

	} else {

		set ok 1

		for { set i 0 } { $i < $nr_args - 2 } { incr i } {

			switch -- [lindex $args $i] {

				-unsafe -
				-safe   {
				}
				-meta {
					set meta 1
				}
				default {
					break
				}

			}

		}

		if { $i != $nr_args - 2 } {
			set ok 0
		} else {
			lassign [lrange $args $i e] name index
			set ok [string is integer -strict $index]
		}

	}

	if { !$ok } {
		error "Usage: reqGetNthArg ?-safe|-unsafe? ?-meta? element num"
	}

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {
		set values $REQ_ARGS($name)
	} else {
		set values [list]
	}

	if { $index < [llength $values] } {
		set value [lindex $$values $index]
	} else {
		set value ""
	}

	if { $meta } {
		lappend value "" ""
	}

	return $value

}

# Get a request argument
#
# @param -unsafe       - The raw value should be returned (optional)
# @param -safe         - The safe value should be returned (optional)
# @param -encoding enc - The encoding from which the value should be converted
#                        (optional)
# @param -meta         - The content-type and file-name (if any) should also be
#                        returned (optional)
# @param name          - The request variable name
# @param default       - The default value to be returned if the variable does
#                        not exist (optional)
#
proc core::stub::appserv::_reqGetArg args {

	set nr_args [llength $args]
	set meta    0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		set ok 1

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			switch -- [lindex $args $i] {

				-unsafe -
				-safe   {
				}
				-encoding {

					if { $i == $argc - 2 } {
						set ok 0
						break
					} else {
						incr i
					}

				}
				-meta {
					set meta 1
				}
				default {
					break
				}

			}

			break

		}

		if { $i < $nr_args - 2 } {
			set ok 0
		} else {
			lassign [lrange $args $i e] name default
		}

	}

	if { !$ok } {
		error "Usage: reqGetArg ?-safe|-unsafe? ?-encoding encoding?\
			?-meta? element ?default?"
	}

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {
		set value [lindex $REQ_ARGS($name) 0]
	} else {
		set value $default
	}

	if { $meta } {
		lappend value "" ""
	}

	return $value

}

# Set a request argument.  By default, if one or more values have previously
# been set, the first will be overwritten.
#
# @param -insert n - The new value should overwrite the value at the give index.
# @param -append   - The new value should be appended.
# @param name      - The request parameter name
# @param val       - The new value
#
proc core::stub::appserv::_reqSetArg args {

	set ok     0
	set append 0
	set index  0

	switch -- [llength $args] {

		2 {
			set ok 1
		}

		3 {
			if { [lindex $args 0] eq "-append" } {

				set ok     1
				set append 1
				set args   [lrange $args 1 e]

			}
		}

		4 {
			if { [lindex $args 0] eq "-insert" } {

				set index [lindex $args 1]

				if { [string is integer -strict $index] } {

					set ok 1
					set args [lrange $args 2 e]

				}

			}
		}

	}

	if {!$ok} {
		error "Usage: reqSetArg ?-insert n | -append? name value"
	}

	lassign $args name value

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {

		set len [llength $REQ_ARGS($name)]

	} else {

		set len 0

		variable REQ_NAMES
		lappend  REQ_NAMES $name

	}

	if { $append } {
		set index $len
	}

	if { $index < $len } {
		lset REQ_ARGS($name) $index $value
	} else {
		lappend REQ_ARGS($name) $value
	}

}

# Get a request argument
#
# @param -unsafe       - The raw value should be returned (optional)
# @param -safe         - The safe value should be returned (optional)
# @param -meta         - The content-type and file-name (if any) should also be
#                        returned (optional)
# @param name          - The request variable name
#
proc core::stub::appserv::_reqGetArgs args {

	set nr_args [llength $args]
	set meta    0

	if { $nr_args < 1 } {

		set ok 0

	} else {

		set ok 1

		for { set i 0 } { $i < $nr_args - 1 } { incr i } {

			set arg [lindex $args $i]

			if { $arg eq "-unsafe" } {
				continue
			}

			if { $arg eq "-safe" } {
				continue
			}

			if { $arg eq "-meta" } {
				set meta 1
				continue
			}

			break

		}

		if { $i != $nr_args - 1 } {
			set ok 0
		} else {
			lassign [lrange $args $i e] name
		}

	}

	if { !$ok } {
		error "Usage: reqGetArgs ?-safe|-unsafe? ?-meta? element"
	}

	variable REQ_ARGS

	if { [info exists REQ_ARGS($name)] } {

		if { $meta } {

			foreach arg $REQ_ARGS($name) {
				lappend args [list $arg "" ""]
			}

		} else {
			set args $REQ_ARGS($name)
		}

	} else {
		set args [list]
	}

	return $args

}

# Get request environment variable names
#
proc core::stub::appserv::_reqGetEnvNames args {

	if { [llength $args] != 0 } {
		error "Usage: reqGetEnvNames"
	}

	variable REQ_ENV

	return [lsort [array names REQ_ENV]]

}

# Get a request environment variable
#
# @param name - The name of the environment parameter
#
proc core::stub::appserv::_reqGetEnv args {

	if { [llength $args] != 1 } {
		error "Usage: reqGetEnv env_name"
	} else {
		lassign $args name
	}

	variable REQ_ENV

	if { [info exists REQ_ENV($name)] } {
		return $REQ_ENV($name)
	} else {
		return ""
	}

}

# Set the request environment
#
# @param name - The name of the environment parameter
# @param val  - The new value
#
proc core::stub::appserv::_reqSetEnv args {

	if { [llength $args] != 2 } {
		error "Usage: reqSetEnv env_name env_value"
	} else {
		lassign $args name value
	}

	variable REQ_ENV

	if { $name ne "" } {
		set REQ_ENV($name) $value
	}

}

#
# Get the request Id - Always return 1
#
proc core::stub::appserv::_reqGetId args {

	if { [llength $args] != 0 } {
		error "Usage: reqGetId"
	}

	variable CFG
	return $CFG(req_id)
}
