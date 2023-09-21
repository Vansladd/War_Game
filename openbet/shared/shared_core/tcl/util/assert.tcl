# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Assertions
#
set pkgVersion 1.0
package provide core::assert $pkgVersion
package require core::args  1.0
# lives in TCLLib
package require struct::list

core::args::register_ns \
	-namespace core::assert \
	-version   $pkgVersion \
	-dependent [list core::check core::args] \
	-docs      util/assert.xml


package provide core::assert 1.0

namespace eval core::assert {
	namespace export assert

	variable EXECUTION
}

core::args::register -proc_name core::assert::assert

# Assert something.
#
# There are several usage patterns to check for specific things, e.g.
# assert {$foo == $bar}
# assert {func $a $b $c} raises "^Invalid"
# assert {func $a $b $c} calls "another_func $a"
# See the documentation for a complete list of examples.
proc core::assert::assert {expression {subcommand {}} args} {
	if {$subcommand == {}} {
		uplevel [list if "!($expression)" [list error "Assertion failed: $expression"]]
	} else {
		switch -- $subcommand {
			raises -
			raises_code -
			calls {
				uplevel core::assert::_assert_$subcommand [list $expression] $args
			}
			default {error "Invalid subcommand to core::assert::assert $subcommand"}
		}
	}
}

core::args::register \
	-proc_name core::assert::assert_true \
	-desc      {Assert that an expression evaluates true} \
	-args      [list \
		[list -arg -expression -mand 1 -check ANY    -desc {expression to evaluate}] \
		[list -arg -msg        -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			uplevel [list "core::assert::assert" $ARGS(-expression)]
		} msg]} {
			error "Assertion failed: $ARGS(-expression) is not true${user_msg}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_false \
	-desc      {Assert that an expression evaluates false} \
	-args      [list \
		[list -arg -expression -mand 1 -check ANY    -desc {expression to evaluate}] \
		[list -arg -msg        -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			uplevel [list "core::assert::assert" "!$ARGS(-expression)"]
		} msg]} {
			error "Assertion failed: $ARGS(-expression) is not false${user_msg}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_null \
	-desc      {Assert a value is empty} \
	-args      [list \
		[list -arg -value -mand 1 -check ANY    -desc {value to check}] \
		[list -arg -msg   -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {$ARGS(-value) == {}}
		} msg]} {
			error "Assertion failed: \{$ARGS(-value)\} is not null/empty${user_msg}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_not_null \
	-desc      {Assert a value is not empty} \
	-args      [list \
		[list -arg -value -mand 1 -check ANY    -desc {value to check}] \
		[list -arg -msg   -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {$ARGS(-value) != {}}
		} msg]} {
			error "Assertion failed: \{$ARGS(-value)\} is null/empty${user_msg}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_equals \
	-desc      {Assert one value is equal to another} \
	-args      [list \
		[list -arg -value1 -mand 1 -check ANY    -desc {first value}] \
		[list -arg -value2 -mand 1 -check ANY    -desc {second value}] \
		[list -arg -msg    -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {$ARGS(-value1) == $ARGS(-value2)}
		} msg]} {
			set errorInfo $::errorInfo
			set errorCode $::errorCode

			# Only log the differences if core::log exists.
			if {[package versions core::log] ne {}} {
				set good_str ""

				set str_idx 0
				foreach c1 [split $ARGS(-value1) ""] c2 [split $ARGS(-value2) ""] {
					if {$c1 eq $c2} {
						append good_str $c1
					} else {
						break
					}

					incr str_idx
				}

				#core::log::xwrite \
				#	-msg      {MATCHED: $good_str} \
				#	-colour   green

				set bad1 [string range $ARGS(-value1) $str_idx end]
				core::log::xwrite \
					-msg       {NOT MATCHED (-value1): '$ARGS(-value1)' (trailing part mismatching='$bad1')} \
					-colour    red

				set bad2 [string range $ARGS(-value2) $str_idx end]
				core::log::xwrite \
					-msg       {NOT MATCHED (-value2): '$ARGS(-value2)' (trailing part mismatching='$bad2')} \
					-colour    red
			}

			error "Assertion failed${user_msg}: \{$ARGS(-value1)\} does not equal \{$ARGS(-value2)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_not_equals \
	-desc      {Assert one value is not equal to another} \
	-args      [list \
		[list -arg -value1 -mand 1 -check ANY    -desc {first value}] \
		[list -arg -value2 -mand 1 -check ANY    -desc {second value}] \
		[list -arg -msg    -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {$ARGS(-value1) != $ARGS(-value2)}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-value1)\} equals \{$ARGS(-value2)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_contains \
	-desc      {Assert a list contains a specific value} \
	-args      [list \
		[list -arg -list  -mand 1 -check ANY    -desc {List to check}] \
		[list -arg -value -mand 1 -check ANY    -desc {Value to check for}] \
		[list -arg -msg   -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {[lsearch $ARGS(-list) $ARGS(-value)] != -1}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-list)\} does not contain \{$ARGS(-value)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_not_contains \
	-desc      {Assert a list does not contain a specific value} \
	-args      [list \
		[list -arg -list  -mand 1 -check ANY    -desc {List to check}] \
		[list -arg -value -mand 1 -check ANY    -desc {Value to check for}] \
		[list -arg -msg   -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {[lsearch $ARGS(-list) $ARGS(-value)] == -1}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-list)\} contains \{$ARGS(-value)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_regexp_match \
	-desc      {Assert a value matches a regular expression} \
	-args      [list \
		[list -arg -regexp -mand 1 -check ANY    -desc {Regular expression to use for the match}] \
		[list -arg -value  -mand 1 -check ANY    -desc {Value to check}] \
		[list -arg -msg    -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {[regexp $ARGS(-regexp) $ARGS(-value)]}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-regexp)\} does not match \{$ARGS(-value)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_regexp_not_match \
	-desc      {Assert a value does not matcha regular expression} \
	-args      [list \
		[list -arg -regexp -mand 1 -check ANY    -desc {Regular expression to use for match}] \
		[list -arg -value  -mand 1 -check ANY    -desc {Value to check}] \
		[list -arg -msg    -mand 0 -check STRING -desc {message to be displayed if assertion fails} -default {}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {![regexp $ARGS(-regexp) $ARGS(-value)]}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-regexp)\} matches \{$ARGS(-value)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_type \
	-desc      {Assert a value passes certain type checks} \
	-args      [list \
		[list -arg -value        -mand 1 -check ANY                                 -desc {Value to check}] \
		[list -arg -checks       -mand 1 -check ASCII                               -desc {List of type checks to perform}] \
		[list -arg -combine_type -mand 0 -check {ENUM -args {AND OR}} -default {OR} -desc {Logical operator for combining checks}] \
		[list -arg -msg          -mand 0 -check STRING                -default {}   -desc {message to be displayed if assertion fails}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {[core::check::check_value $ARGS(-value) $ARGS(-combine_type) $ARGS(-checks)]}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-value)\} does not pass checks \{$ARGS(-checks)\} with combine type of \{$ARGS(-combine_type)\}" $::errorInfo $::errorCode
		}
	}

core::args::register \
	-proc_name core::assert::assert_not_type \
	-desc      {Assert a value does not pass certain type checks} \
	-args      [list \
		[list -arg -value        -mand 1 -check ANY                                 -desc {Value to check}] \
		[list -arg -checks       -mand 1 -check ASCII                               -desc {List of type checks to perform}] \
		[list -arg -combine_type -mand 0 -check {ENUM -args {AND OR}} -default {OR} -desc {Logical operator for combining checks}] \
		[list -arg -msg          -mand 0 -check STRING                -default {}   -desc {message to be displayed if assertion fails}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {![core::check::check_value $ARGS(-value) $ARGS(-combine_type) $ARGS(-checks)]}
		} msg]} {
			error "Assertion failed${user_msg}: \{$ARGS(-value)\} passes checks \{$ARGS(-checks)\} with combine type of \{$ARGS(-combine_type)\}" $::errorInfo $::errorCode
		}
	}

# Set the expected sequence of calls to be assert later
#
# Provide a list of calls that are expected, in the order they are expected.
# calls must be provided with fully qualified proc names and all arguments must
# match. Only a partial call sequence need be provided if we do not want to
# check all calls made, this is acheived by simply not adding the procs you
# want to ignore to the sequence. Be aware, however that once you have
# specified a proc once in the sequence you must catch all calls of that proc
# name.
# call_sequence syntax [list [list full_proc_name arg1 arg2 ...]... ]
#                      e.g. [list \
#                               [list ::core::db::exec_qry -name qry1 -args [list 1]] \
#                               [list ::some_ns::some_proc -arg1 1] \
#                               [list ::core::db::exec_qry -name qry2 -args [list 2]] \
#                           ]
core::args::register \
	-proc_name core::assert::set_call_seq \
	-desc      {Set an expected call sequence} \
	-args      [list \
		[list -arg -call_sequence -mand 1 -check ANY   -desc {Expected sequence of calls}] \
	] \
	-body {
		variable EXECUTION

		set EXECUTION(call_seq)              $ARGS(-call_sequence)
		set EXECUTION(call_seq_total)        0
		set EXECUTION(call_seq_traced_procs) [list]
		set EXECUTION(call_seq_actual)       [list]

		foreach {call_details} $ARGS(-call_sequence) {
			if {[lsearch $EXECUTION(call_seq_traced_procs) [lindex $call_details 0]] == -1} {
				trace add execution [lindex $call_details 0] enter core::assert::_assert_call_seq_tracer
				lappend EXECUTION(call_seq_traced_procs) [lindex $call_details 0]
			}
			incr EXECUTION(call_seq_total)
		}
	}


# Assert the previously expected sequence of calls was observed
#
# This can fail in two different ways
#   1. Not all defined calls in the call sequence were encountered
#   2. There was a mismatch in the call sequence and an unexpected call was
#      made
#
# Only the first mismatch will be reported, since if one mismatch is found
# it is likely to cause others
core::args::register \
	-proc_name core::assert::assert_call_seq \
	-desc      {Assert the previously expected sequence of calls was observed} \
	-body {
		variable EXECUTION

		set msg {}

		if {[llength $EXECUTION(call_seq_actual)] != [llength $EXECUTION(call_seq)]} {
			set msg "Assertion failed: Actual call sequence different length than expected call sequence"
		} else {
			set i 0
			foreach call $EXECUTION(call_seq_actual) {
				if {$i < $EXECUTION(call_seq_total)} {
					set exp_call [lindex $EXECUTION(call_seq) $i]
					set exp_func [lindex $exp_call 0]
					set exp_args [lrange $exp_call 1 end]

					set act_func [lindex $call 0]
					set act_args [lrange $call 1 end]

					if {$exp_func != $act_func} {
						set msg "Assertion failed: Function name mismatch on call number $i. Expected $exp_func got $act_func"
						break
					}

					if {$exp_args != $act_args} {
						set msg "Assertion failed: Function arguments mismatch on call number $i - $exp_func. Expected $exp_args got $act_args"
						break
					}

				}
				incr i
			}
		}

		if {$msg != {}} {
			append msg "\nExpected Call sequence:\n\t"
			append msg [join $EXECUTION(call_seq) "\n\t"]
			append msg "\nActual Call sequence:\n\t"
			append msg [join $EXECUTION(call_seq_actual) "\n\t"]
		}

		foreach {traced_proc} $EXECUTION(call_seq_traced_procs) {
			trace remove execution $traced_proc enter core::assert::_assert_call_seq_tracer
		}

		set EXECUTION(call_seq)              [list]
		set EXECUTION(call_seq_traced_procs) [list]
		set EXECUTION(call_seq_total)        0
		set EXECUTION(call_seq_actual)       [list]

		if {$msg != {}} {
			error $msg
		}
	}


core::args::register \
	-proc_name core::assert::assert_list_equals \
	-desc      {Assert that two lists are identical} \
	-args      [list \
		[list -arg -list1 -mand 1 -check LIST               -desc {First list}] \
		[list -arg -list2 -mand 1 -check LIST               -desc {Second list}] \
		[list -arg -msg   -mand 0 -check STRING -default {} -desc {Message to be displayed if assertion fails}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert {[::struct::list equal $ARGS(-list1) $ARGS(-list2)] == 1}
		} msg]} {
			error \
				"Assertion failed${user_msg}: \{$ARGS(-list1)\} does not equal \{$ARGS(-list2)\}"\
				$::errorInfo\
				$::errorCode
		}
	}


core::args::register \
	-proc_name core::assert::assert_dict_equals \
	-desc      {Assert that two dictionaries are identical} \
	-args      [list \
		[list -arg -dict1 -mand 1 -check ANY                -desc {First dictionary}] \
		[list -arg -dict2 -mand 1 -check ANY                -desc {Second dictionary}] \
		[list -arg -msg   -mand 0 -check STRING -default {} -desc {Message to be displayed if assertion fails}] \
	] \
	-body {
		set user_msg [expr {$ARGS(-msg) == "" ? {} : " ($ARGS(-msg)) "}]

		if {[catch {
			core::assert::assert_list_equals\
				-list1 [dict get $ARGS(-dict1)]\
				-list2 [dict get $ARGS(-dict2)]
		} msg]} {
			error \
				"Assertion failed${user_msg}: \{$ARGS(-dict1)\} does not equal \{$ARGS(-dict2)\}"\
				$::errorInfo\
				$::errorCode
		}
	}


core::args::register \
	-proc_name core::assert::assert_raises \
	-desc      {Assert that an expression raises a specific exception} \
	-args      [list \
		[list -arg -expression -mand 1 -check  ANY    -desc {expression to evaluate}] \
		[list -arg -error      -mand 1 -check  STRING -desc {the error expected to be raised}] \
	] \
	-body {
		assert $ARGS(-expression) raises $ARGS(-error)
	}


core::args::register \
	-proc_name core::assert::assert_raises_code \
	-desc      {Assert that an expression raises a specific exception} \
	-args      [list \
		[list -arg -expression -mand 1 -check  ANY    -desc {expression to evaluate}] \
		[list -arg -error_code  -mand 1 -check  STRING -desc {the error expected to be raised}] \
	] \
	-body {
		assert $ARGS(-expression) raises_code $ARGS(-error_code)
	}
#
# Private helper procs
#

# Tracer proc called on enter of a call expected as part of a sequence. Checks
# whether the called proc matches the next expected proc in the sequence
proc core::assert::_assert_call_seq_tracer {command_string op} {
	variable EXECUTION

	set act_func [uplevel namespace origin [lindex $command_string 0]]
	set act_args [lrange $command_string 1 end]

	lappend EXECUTION(call_seq_actual) "$act_func $act_args"
}


# Handle assert raises commands
proc core::assert::_assert_raises {body re} {
	if {[catch {uplevel eval [list $body]} err opts]} {
		if {[regexp -- $re $err]} {
			return
		} else {
			error "Assertion failed: expected error matching {$re}, got {$err}" [dict get $opts -errorinfo]
		}
	}

	error "Assertion failed: expected error matching {$re}"
}

# Handle assert raises_code commands
proc core::assert::_assert_raises_code {body code} {
	if {[catch {uplevel eval [list $body]} err opts]} {
		set actual_code [dict get $opts -errorcode]
		set errorinfo   [dict get $opts -errorinfo]
		if {$actual_code == $code} {
			return
		} else {
			error "Assertion failed: expected error code $code, got $actual_code: $err" $errorinfo
		}
	}

	error "Assertion failed: expected error code $code"
}

# Handle assert calls commands. This uses trace functions to check whether
# a function is called.
# WARNING: This should not be called with any code that itself runs assertions,
# as it relies on namespace variables to store state
proc core::assert::_assert_calls {body args} {
	_reset

	set func [lindex $args 0]
	if {[llength $func] > 1} {
		_set_expected_args [lrange $func 1 end]
		set func [lindex $func 0]
	}

	set resolved_func [uplevel namespace origin [list $func]]

	# Handle "with" syntax for name/value pairs
	set num_args [llength $args]
	if {$num_args > 1} {
		if {$num_args % 2 != 1 && [lindex $args 1] == {with}} {
			_set_expected_args [lrange $args 2 end] 1
		} elseif {$num_args == 3 && [lindex $args 1] == {with_precondition}} {
			_set_precondition [lindex $args 2] [info args $resolved_func]
		} else {
			error "Syntax error: [lrange $args 1 end]"
		}
	}

	# All tracing is done in the calling scope, with fully qualified function names
	# anything else leads to weird behaviour
	uplevel trace add execution $resolved_func {enter} core::assert::_assert_calls_tracer

	if {[catch {uplevel eval [list $body]} err opts]} {
		if {![_was_called]} {
			uplevel trace remove execution $resolved_func {enter} core::assert::_assert_calls_tracer
			error "Assertion failed: $resolved_func not called as expected, got error $err" [dict get $opts -errorinfo]
		}
	}

	uplevel trace remove execution $resolved_func {enter} core::assert::_assert_calls_tracer
	if {![_was_called]} {
		error "Assertion failed: $resolved_func not called as expected[_msg]"
	}
}

#
# Helper functions for _assert_calls
#

# Trace command that is run when the function being asserted is called.
# The result of the check is stored in the EXECUTION array.
proc core::assert::_assert_calls_tracer {command_string op} {
	variable EXECUTION

	set expected $EXECUTION(arglist)
	set actual [lrange $command_string 1 end]

	# Check that name value pairs were used
	if {$EXECUTION(check_args_nv)} {
		foreach {name value} $expected {
			if {[dict get $actual $name] != $value} {
				return
			}
		}
	}

	# Check exact args were used
	if {$EXECUTION(check_args)} {
		if {[llength $actual] != [llength $expected]} {
			return
		}
		for {set i 0} {$i < [llength $actual]} {incr i} {
			if {[lindex $actual $i] != [lindex $expected $i]} {
				return
			}
		}
	}

	if {$EXECUTION(precondition) != {}} {
		# Run precondition expression in its own scope, emulating the actual function
		proc __precondition {precondition arglist argnames} {
			array set ARGS {}

			set l [llength $argnames]

			for {set i 0} {$i < $l} {incr i} {
				set name  [lindex $argnames $i]
				set value [lindex $arglist $i]

				# If we have flag arguments, then store them in an array, as core::args does
				if {$i == ($l - 1) && $name == {args} && [llength [lrange $arglist $i end]] % 2 == 0} {
					array set ARGS [lrange $arglist $i end]
				} else {
					set $name $value
				}
			}

			return [expr $precondition]
		}

		if {[catch {set passed [__precondition $EXECUTION(precondition) $actual $EXECUTION(argnames)]} err]} {
			set EXECUTION(msg) ", precondition failed {$EXECUTION(precondition)} ($err)"
			return
		}

		# Fail if result is not boolean
		if {$passed != 1} {
			set EXECUTION(msg) ", precondition failed {$EXECUTION(precondition)}"
			return
		}
	}

	incr EXECUTION(called)
}

# Private proc to determine if the function was called and all checks passed
proc core::assert::_was_called {} {
	variable EXECUTION
	return $EXECUTION(called)
}

# Private proc to retrieve an error message if set
proc core::assert::_msg {} {
	variable EXECUTION
	return $EXECUTION(msg)
}

# Reset internal array before running an assert calls command
proc core::assert::_reset {} {
	variable EXECUTION
	set EXECUTION(called) 0
	set EXECUTION(check_args) 0
	set EXECUTION(check_args_nv) 0
	set EXECUTION(arglist) {}
	set EXECUTION(argnames) {}
	set EXECUTION(precondition) {}
	set EXECUTION(msg) {}
}

# Set exact args that must be passed to a function
proc core::assert::_set_expected_args {arglist {is_name_value 0}} {
	variable EXECUTION
	if {$is_name_value} {
		incr EXECUTION(check_args_nv)
	} else {
		incr EXECUTION(check_args)
	}
	set EXECUTION(arglist) $arglist
}

# Set a precondition that must be true when a function is called
proc core::assert::_set_precondition {precondition argnames} {
	variable EXECUTION
	set EXECUTION(precondition) $precondition
	set EXECUTION(argnames) $argnames
}
