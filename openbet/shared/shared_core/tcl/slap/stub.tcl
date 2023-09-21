# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Stub utilities
#

set pkgVersion 1.0
package provide core::stub $pkgVersion

# Dependencies
package require core::log    1.0
package require core::check  1.0
package require core::args   1.0
package require core::unit   1.0

load libOT_Tcl.so

core::args::register_ns \
	-namespace core::stub \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args] \
	-docs      slap/stub.xml

# This package should not rely on a config file
namespace eval core::stub {

	variable CFG
	variable OVERRIDE
	variable PROC_MAP
	variable SCOPE
	variable CORE_DEF

	set CFG(init)          0
	set CFG(default_scope) global

	# Optional arguments
	set CORE_DEF(return_data,opt) [list -arg -return_data     -mand 0 -check ANY                                    -default {} -desc {Data to return}]
	set CORE_DEF(scope,opt)       [list -arg -scope           -mand 0 -check {ENUM -args  {global suite test proc}} -default {} -desc {Type of Scope for stub/override}]
	set CORE_DEF(scope_key,opt)   [list -arg -scope_key       -mand 0 -check ASCII                                  -default {} -desc {Identifying key for the stub/override}]
	set CORE_DEF(proc_name)       [list -arg -proc_name       -mand 1 -check STRING                                             -desc {Name of the proc}]
	set CORE_DEF(arg_list,opt)    [list -arg -arg_list        -mand 0 -check ANY                                    -default {} -desc {Argument name value pairs to apply pre_handler and return data to}]

	# Mandatory arguments
	set CORE_DEF(proc_name)       [list -arg -proc_name       -mand 1 -check STRING -desc {Name of the proc}]
}

core::args::register \
	-proc_name core::stub::init \
	-args [list \
		[list -arg -force_init    -mand 0 -check BOOL  -default 0  -desc {Force initialisation}] \
		[list -arg -default_scope -mand 0 \
			-check {ENUM -args  {global suite test}} -default {global} -desc {Scope level of the stubbed proc}] \
		[list -arg -strict        -mand 0 -check BOOL  -default 0  -desc {Enforce strict usage of core::stub}] \
	]

proc core::stub::init args {

	variable CFG
	variable PROC_MAP

	array set ARGS [core::args::check core::stub::init {*}$args]

	if {$CFG(init) && !$ARGS(-force_init)} {
		return
	}

	array set PROC_MAP [array unset PROC_MAP]

	set CFG(default_scope) $ARGS(-default_scope)
	set CFG(strict)        $ARGS(-strict)
	set CFG(init)          1
}

# proc       - core::stub::define_procs
#
# Purpose    - Setup stub overrides for all the procs listed
#
# Parameters - '-proc_definition <list of pairs: <namespace> <procname>>'
#              '-pass_through {0|1}' - if =1, then if no override
#                                      proc exists and the args match exactly,
#                                      then call the real thing
#
#              Note: for <procname> in -proc_definition list,
#              '*' is permitted if the namespace exists, whereby
#              this means all procs currently defined in the namespace
#              So if you want to override a proc not currently
#              defined in the namespace, this must be specified explicitly.
#
#              <namespace> should not have any leading or trailing '::'
#
# Returns    - nothing
#
# Notes      - if some procs need: -pass_through=1,
#              and others need:    -pass_through=0,
#              then call this proc twice
#
core::args::register \
	-proc_name core::stub::define_procs \
	-args [list \
		[list -arg -proc_definition -mand 1 -check ANY                 -desc {List of namespace and procs to stub}] \
		[list -arg -pass_through    -mand 0 -check BOOL   -default 0   -desc {Call the original proc if no overrides found}] \
		$::core::stub::CORE_DEF(return_data,opt) \
		$::core::stub::CORE_DEF(scope,opt) \
		$::core::stub::CORE_DEF(scope_key,opt) \
	]

proc core::stub::define_procs args {

	variable CFG
	variable PROC_MAP
	variable SCOPE

	array set ARGS [core::args::check core::stub::define_procs {*}$args]

	set pass_through $ARGS(-pass_through)
	set return_data  $ARGS(-return_data)
	set scope        $ARGS(-scope)
	set scope_key    $ARGS(-scope_key)

	if {$scope != {} && $scope != {proc}} {
		set scope_key [core::unit::get_key -scope $scope]
	}

	if {$scope_key == {}} {
		set scope_key [core::unit::get_key -scope $CFG(default_scope)]
	}

	# Define blacklist of procs that should not be overridden
	set blacklist [list \
		::OT_LogWrite \
		core::log::write \
		core::args::check \
		core::args::dump_ns \
		core::args::get_arg_list \
		core::args::register]

	foreach {ns proc_list} $ARGS(-proc_definition) {

		set ns_prefix [string map {:: _} $ns]

		# Check if all procs should be stubbed for a namespace
		if {$proc_list == {*}} {
			set proc_list [list]
			set commands_in_namespace [info commands ::${ns}::*]
			set num_commands_in_namespace [llength $commands_in_namespace]
			foreach proc $commands_in_namespace {
				lappend proc_list [namespace tail $proc]
			}

			# Ensure that user has not tried to use '*' for a namespace
			# where no procs are currently defined.
			# (User will expect all to be overridden, but this is not supported.)
			# Instead, if no namespace defined, each proc must be listed separately.
			if {$num_commands_in_namespace == 0} {
				core::log::xwrite \
					-msg {ERROR - No existing procs found in namespace '$ns' \
						- You cannot use '*' in 'core::stub::define_procs',\
						but must override each proc explicitly,\
						because this namespace doesn't have any existing procs in} \
					-colour red
				if {$CFG(strict)} {
					error { Error - core::stub::define_procs for namespace '$ns' proc '*'.  You cannot use wildcard '*' unless namespace is defined (whereby all defined procs in it, and no others, will be overridden.)  Specific each proc separately to override instead.} {} INVALID_OVERRIDE
				}
			}
			core::log::write INFO {Overridden $num_commands_in_namespace procs in '$ns'}
		}

		foreach proc $proc_list {

			if {[lsearch $blacklist "${ns}::$proc"] > -1} {
				core::log::write INFO {Skipping black listed file ${ns}::$proc}
				continue
			}

			# We don't want to stub already stubbed files
			if {[regexp {^_stubbed_.*} $proc]} {
				core::log::write DEBUG {Skipping stubbed file ${ns}::$proc}
				continue
			}

			switch -- $proc {
				default {
					set ret $return_data
				}
			}

			set moved_proc [format "::%s::_stubbed_%s_%s" \
				$ns \
				$proc \
				[OT_MicroTime -micro]]

			# We need to move the original proc out the way but will
			# need to reference it again
			if {[info exists PROC_MAP($ns,$proc,$scope_key)]} {
				core::log::xwrite \
					-msg {${ns}::${proc} has already been stubbed for scope_key $scope_key.\
						Is define procs being called multiple times?} \
					-colour red
				set original_proc $PROC_MAP($ns,$proc,$scope_key)
			} else {
				set original_proc                  $moved_proc
				set PROC_MAP($ns,$proc,$scope_key) $moved_proc
			}

			# If we set -pass_through the code should call the original proc
			if {$pass_through} {
				set ret [subst {\[uplevel ::$original_proc \$args\]}]
			}

			set strict_mode $CFG(strict)

			# Build the body of the proc, if custom code needs to be added
			# please add it to the switch above most procs should just have
			# a pass through handled by the override
			set body [subst {
				variable CFG

				if {{$scope} == {proc}} {
					set scope_key \[lindex \[info level -1\] 0\]

					for {set i \[info frame\]} {\$i > 0} {incr i -1} {
						set frame_info \[info frame \$i\]
						foreach {name value} \$frame_info {
							if {\$name == {proc}} {
								lappend scope_key \$value
							}
						}
					}

				} else {
					set scope_key $scope_key
				}

				array set RESULT \[core::stub::_get_override "$scope" \$scope_key\]

				core::log::write DEV {Scope is $scope_key}

				if {\$RESULT(-found)} {

					# Execute any pre-handlers that have been setup
					if {\$RESULT(-pre_handler) != {}} {
						eval \$RESULT(-pre_handler)
					}

					# Execute the overridden body
					if {\$RESULT(-body) != {}} {

						set catch_code \[catch {
							set body_ret \[eval \$RESULT(-body) \]
						} msg options \]

						if { $strict_mode } {
							# catch_code == 2 means there was a return in the body
							# see the tcl catch documentation
							if { \$catch_code == 2 && \$RESULT(-return_data) != {UNSET} } {
								error { Error when stubbing ${ns}::${proc} : You cannot use a return in the body if you use -return_data flag} {} INVALID_OVERRIDE
							}

							if { \$catch_code == 2 && \$RESULT(-use_body_return) == 0 } {
								error { Error when stubbing ${ns}::${proc} : You cannot use a return in the body if you do not set -use_body_return to 1 } {} INVALID_OVERRIDE
							}
						}

						# return body return value
						if { \$catch_code == 2 } {
							set body_ret \$msg
						}

						# rethrow error as is
						# catch_code == 1 means there was an error in the body
						if { \$catch_code == 1 } {
							set errcode \[dict get \$options -errorcode\]
							error \$msg {} \$errcode
						}
					}

					# Throw an error if configured
					if {\$RESULT(-error) != {}} {
						error \$RESULT(-error)
					}

					# If we use want to use the return value
					# of the evaluated override body, return
					# that, otherwise return the set data
					if {\$RESULT(-use_body_return)} {

						# Execute any post-handlers that have been setup
						if {\$RESULT(-post_handler) != {}} {
							eval \$RESULT(-post_handler)
						}

						return \$body_ret
					} elseif {\$RESULT(-return_data) != {UNSET}} {

						# Execute any post-handlers that have been setup
						if {\$RESULT(-post_handler) != {}} {
							eval \$RESULT(-post_handler)
						}

						# Return the overridden data
						return \$RESULT(-return_data)
					}

					# We want the post handler to fire after the body
					set pass_through_ret "$ret"

					# Execute any post-handlers that have been setup
					if {\$RESULT(-post_handler) != {}} {
						eval \$RESULT(-post_handler)
					}

					return \$pass_through_ret
				}

				return $ret
			}]

			proc ::core::stub::${ns_prefix}_$proc args $body

			core::log::write DEV {Stubbed ::${ns}::$proc ->  $moved_proc (Pass Through $pass_through)}

			# Handle unknown namespace or proc
			if {![namespace exists $ns]} {
				namespace eval ::$ns {
					package require core::log 1.0
				}
			}

			# Handle unknown proc
			if {![llength [info commands ::${ns}::$proc]]} {
				namespace eval ::$ns [subst -nocommands {
					proc $proc args {
						core::log::write DEBUG {Handling Undefined proc: args \$args}
					}
				}]
			}

			# Add a scope reference so we can tidy up
			if {[info exists SCOPE($scope_key)] } {
				if {[lsearch $SCOPE($scope_key) "${ns}::$proc"] == -1} {
					lappend SCOPE($scope_key) "${ns}::$proc"
				}
			} else {
				set SCOPE($scope_key) [list "${ns}::$proc"]
			}

			# Rename commands
			rename ::${ns}::$proc                   $moved_proc
			rename ::core::stub::${ns_prefix}_$proc ::${ns}::$proc
		}
	}
}

# Return the mapped proc name given the current proc information
#
# @param ns_name Original namespace name
# @param proc_name Original proc name
# @return Mapped proc name
# Example given ::core::db::exec_qry returns ::core::db::_exec_qry_1345651194.348654
core::args::register \
	-proc_name core::stub::get_mapped_proc \
	-args [list \
		[list -arg -ns_name   -mand 1 -check STRING  -desc {Namespace of original proc}] \
		$::core::stub::CORE_DEF(proc_name) \
		$::core::stub::CORE_DEF(scope_key,opt) \
	] \
	-body {
		variable PROC_MAP

		set ns        $ARGS(-ns_name)
		set proc      $ARGS(-proc_name)
		set scope_key $ARGS(-scope_key)

		if {[info exists PROC_MAP($ns,$proc,$scope_key)]} {
			return $PROC_MAP($ns,$proc,$scope_key)
		}

		return {}
	}

core::args::register \
	-proc_name core::stub::set_override \
	-args [list \
		$::core::stub::CORE_DEF(proc_name) \
		$::core::stub::CORE_DEF(arg_list,opt) \
		[list -arg -force_regexp    -mand 0 -check BOOL   -default 0     -desc {Force the use of non-core style matching even for core procs and interfaces}] \
		[list -arg -strict_regexp   -mand 0 -check BOOL   -default 0     -desc {Use the regexp to match the whole set of arguments, non a subset.}] \
		[list -arg -body            -mand 0 -check ANY    -default {}    -desc {Stub out the body of the proc}] \
		[list -arg -return_data     -mand 0 -check ANY    -default UNSET -desc {Data to return}] \
		[list -arg -use_body_return -mand 0 -check BOOL   -default 0     -desc {Use return value from evaluation of the override body instead of static return_data}] \
		[list -arg -error           -mand 0 -check STRING -default {}    -desc {Error string}] \
		$::core::stub::CORE_DEF(scope,opt) \
		$::core::stub::CORE_DEF(scope_key,opt) \
		[list -arg -pre_handler     -mand 0 -check ANY    -default {}    -desc {Pre-handler body definition}] \
		[list -arg -post_handler    -mand 0 -check ANY    -default {}    -desc {Post-handler body definition}] \
	] \
	-body {
		variable CFG
		variable OVERRIDE
		variable SCOPE

		set proc_name       $ARGS(-proc_name)
		set arg_list        $ARGS(-arg_list)
		set body            $ARGS(-body)
		set return_data     $ARGS(-return_data)
		set use_body_return $ARGS(-use_body_return)
		set error           $ARGS(-error)
		set scope           $ARGS(-scope)
		set scope_key       $ARGS(-scope_key)
		set force_regexp    $ARGS(-force_regexp)
		set strict_regexp   $ARGS(-strict_regexp)
		set pre_handler     $ARGS(-pre_handler)
		set post_handler    $ARGS(-post_handler)

		#
		# check core::stub::set_override is used properly
		if { $CFG(strict) } {
			if { $use_body_return == 1 && $return_data != {UNSET} } {
				error "core::stub::set_override ($proc_name) should not be used with both -use_body_return and -return_data, specify where the return comes from" {} INVALID_OVERRIDE
			}
			if { $body != {} && $error != {} } {
				error "core::stub::set_override ($proc_name) should not be used with both -body and -error, if you need both please raise the error from the body" {} INVALID_OVERRIDE
			}
		}

		if {$scope != {} && $scope != {proc}} {
			set scope_key [core::unit::get_key -scope $scope]
		}

		if {$scope_key == {}} {
			set scope_key [core::unit::get_key -scope $CFG(default_scope)]
		}

		# TODO - Escape comma so we don't clash with
		# possible commas in the param values
		set key [join $arg_list ,]

		core::log::write DEBUG {Setting $proc_name override in scope $scope_key}

		# Strip :: from the beginning of the key
		regexp {^:+(.*)} $key all key

		# Strip leading namespace qualifier
		regexp {^::(.+)$} $proc_name all proc_name

		if {$scope == {proc}} {
			set proc_name "$scope_key,$proc_name"
		}

		if {[llength $arg_list]} {
			set OVERRIDE($proc_name,$key,error)           $error
			set OVERRIDE($proc_name,$key,body)            $body
			set OVERRIDE($proc_name,$key,return_data)     $return_data
			set OVERRIDE($proc_name,$key,use_body_return) $use_body_return
			set OVERRIDE($proc_name,$key,scope_key)       $scope_key
			set OVERRIDE($proc_name,$key,force_regexp)    $force_regexp
			set OVERRIDE($proc_name,$key,strict_regexp)   $strict_regexp
			set OVERRIDE($proc_name,$key,pre_handler)     $pre_handler
			set OVERRIDE($proc_name,$key,post_handler)    $post_handler
			lappend OVERRIDE($proc_name,keys) $key
		} else {
			set OVERRIDE($proc_name,error)           $error
			set OVERRIDE($proc_name,body)            $body
			set OVERRIDE($proc_name,return_data)     $return_data
			set OVERRIDE($proc_name,use_body_return) $use_body_return
			set OVERRIDE($proc_name,scope_key)       $scope_key
			set OVERRIDE($proc_name,pre_handler)     $pre_handler
			set OVERRIDE($proc_name,post_handler)    $post_handler
		}

		# Add a scope reference so we can tidy up
		if {[info exists SCOPE($scope_key)] } {
			if {[lsearch $SCOPE($scope_key) $proc_name] == -1} {
				lappend SCOPE($scope_key) $proc_name
			}
		} else {
			set SCOPE($scope_key) [list $proc_name]
		}

		core::log::write DEBUG {Set $proc_name override}
	}


# proc       - _get_override
#
# Purpose    - Retrieve proc specific override information
#
# Parameters - scope
#              scope_key
#
# Returns    - Name/value pair list (suitable for 'array set')
#              of the following items:
#
#              Name    :  Value              (Info)
#              -found  :  0 or 1    (If 1, rest name/value returned)
#              -body   :  special body to run
#              -return_data : data to return
#              -use_body_return: 0 or 1   (If 1, return value from -body
#                                         instead of -return_data)
#              -pre_handler : procname
#              -post_handler
#              -error
#
proc core::stub::_get_override {scope scope_key} {

	variable OVERRIDE

	set calling_proc         [lindex [split [info level -1] { }] 0]
	set calling_ns           [namespace which $calling_proc]
	set calling_args         [lrange [info level -1] 1 end]
	set fully_qualified_proc $calling_proc

	set key          [join $calling_args ,]
	set match_key    {}

	# Handle the possibly that the namespace may not be available info level
	if {$calling_ns == {}} {
		set calling_proc [format "%s::%s" [uplevel [list namespace current]] $calling_proc]
	}

	# Strip leading namespace qualifier
	regexp {^::(.+)$} $calling_proc all calling_proc

	core::log:::write DEBUG {Checking $calling_proc in scope $scope_key ($calling_args)}

	# Strip :: from the beginning of the key
	regexp {^:+(.*)} $key all key

	# Loop through the arguments and check combinations against the
	# override hash. Start with all arguments and remove until hit a match
	if {$scope == {proc}} {
		foreach stack_proc $scope_key {
			lappend pattern ${stack_proc},${calling_proc}
		}
		set pattern [join $pattern {|}]

		set names [array names OVERRIDE -regexp $pattern]

		if {[llength $names]} {
			set scope_key [lindex [split [lindex $names 0] {,}] 0]
			set calling_proc "$scope_key,$calling_proc"
		}
	}

	# Check to see if there are any arg specific overrides
	if {[info exists OVERRIDE($calling_proc,$key,return_data)]} {
		set match_key "$calling_proc,$key"
	}

	# Loop over all the stored keys and see if they partially match the string
	if {$match_key == {} && [info exists OVERRIDE($calling_proc,keys)]} {
		foreach stored_key [sort_length -wordlist [list {*}$OVERRIDE($calling_proc,keys)]] {

			set force_regexp  $OVERRIDE($calling_proc,$stored_key,force_regexp)
			set strict_regexp $OVERRIDE($calling_proc,$stored_key,strict_regexp)

			if {!$force_regexp && [core::args::is_registered $fully_qualified_proc]} {

				core::log::write DEBUG {Looking for override match for registered proc $calling_proc}

				set part_match 1
				foreach {n v} [split $stored_key ,] {
					if {![regexp "$n,$v" $key]} {
						set part_match 0
						break
					}
				}

				if {$part_match} {
					core::log::write DEBUG {$stored_key matches keys $key ($OVERRIDE($calling_proc,$stored_key,return_data))}
					set match_key "$calling_proc,$stored_key"
					break
				}
			} else {
				core::log::write DEBUG {Looking for override match for unregistered proc $calling_proc}

				if { $strict_regexp } {
					core::log::write DEBUG {Using strict regexp matching with $stored_key for $calling_proc}
					set match_regexp ^$stored_key$
				} else {
					set match_regexp $stored_key
				}

				if {[regexp $match_regexp $key]} {
					core::log::write DEBUG {$stored_key matches keys $key ($OVERRIDE($calling_proc,$stored_key,return_data))}
					set match_key "$calling_proc,$stored_key"
					break
				}
			}
		}
	}

	if {$match_key == {} && [info exists OVERRIDE($calling_proc,return_data)]} {
		core::log::write DEBUG {Found default $calling_proc override}
		set match_key $calling_proc
	}

	# If we have found a matching override return the information
	if {$match_key != {}} {
		set override_scope $OVERRIDE($match_key,scope_key)
		set found     0

		# The scope of the proc is set when the proc is defined.
		# Overrides that are set at the test and suite level are descoped after
		# each test or suite so they shouldn't leak between the tests. This is
		# handled within unit.tcl

		# Check if there is a scope defined on the proc
		if {$scope_key == {global}} {
			incr found
		} else {
			if {[regexp $scope_key $override_scope]} {
				core::log:::write DEBUG {Matching scope $override_scope <- $scope_key}
				incr found
			}
		}

		if {$found} {
			core::log::write DEBUG {Found $match_key specific $scope_key override}
			return [list \
				-found           1 \
				-body            $OVERRIDE($match_key,body) \
				-return_data     $OVERRIDE($match_key,return_data) \
				-use_body_return $OVERRIDE($match_key,use_body_return) \
				-pre_handler     $OVERRIDE($match_key,pre_handler) \
				-post_handler    $OVERRIDE($match_key,post_handler) \
				-error           $OVERRIDE($match_key,error)]
		}
	}

	return [list -found 0]
}

# Unset an override
core::args::register \
	-proc_name core::stub::unset_override \
	-args [list \
		$::core::stub::CORE_DEF(proc_name) \
		$::core::stub::CORE_DEF(arg_list,opt) \
	] \
	-body {
		variable OVERRIDE

		set proc_name $ARGS(-proc_name)
		set arg_list  $ARGS(-arg_list)
		set key       [join $arg_list ,]

		# Strip :: from the beginning of the key
		regexp {^:+(.*)} $key all key

		if {[llength $arg_list]} {
			array unset OVERRIDE "$proc_name,$key*"
			set OVERRIDE($proc_name,keys) [core::util::ldelete $OVERRIDE($proc_name,keys) $key]
		} else {
			array unset OVERRIDE "$proc_name*"
		}

		core::log::write INFO {Unset $proc_name override}
	}

# Unset based on scope
core::args::register \
	-proc_name core::stub::unset_scope \
	-args [list \
		$::core::stub::CORE_DEF(scope_key,opt) \
	] \
	-body {
		variable OVERRIDE
		variable SCOPE

		set scope_key $ARGS(-scope_key)

		if {![info exists SCOPE($scope_key)]} {
			return
		}

		foreach proc_name $SCOPE($scope_key) {

			set current_ns   [namespace qualifiers $proc_name]
			set current_proc [namespace tail $proc_name]

			# Reset the proc back to the original
			set mapped_proc [get_mapped_proc \
				-ns_name   $current_ns \
				-proc_name $current_proc \
				-scope_key $scope_key]

			if {[info commands $mapped_proc] != {}} {

				if {[catch {
					core::log::write DEV {Renaming $mapped_proc -> ::$proc_name ($scope_key)}
					rename ::$proc_name ""
					rename $mapped_proc ::$proc_name
				} err]} {
					core::log::write INFO {ERROR $err}
				}
			}

			array unset OVERRIDE "$proc_name*"
		}

		array unset SCOPE $scope_key

		core::log::write INFO {Unset scope $scope_key}
	}

# Sort by length
# http://wiki.tcl.tk/4021 (sortlength2)
core::args::register \
	-proc_name core::stub::sort_length \
	-args [list \
		[list -arg -wordlist -mand 1 -check ANY -desc {List to sort}] \
	] \
	-body {
		set wordlist $ARGS(-wordlist)
		set words {}
		foreach word $wordlist {
			lappend words [list [string length $word] $word]
		}
		set result {}
		foreach pair [lsort -decreasing -integer -index 0 [lsort -ascii -index 1 $words]] {
			lappend result [lindex $pair 1]
		}
		return $result
	}
