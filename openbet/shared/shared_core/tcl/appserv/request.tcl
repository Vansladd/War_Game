# (C) 2011 Orbis Technology Ltd. All rights reserved.
#
# Request  Model
#

set pkg_version 1.0
package provide core::request $pkg_version


# Dependencies
#
package require core::log   1.0
package require core::check 1.0
package require core::args  1.0
package require core::safe  1.0

core::args::register_ns \
	-namespace core::request \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args] \
	-docs      xml/appserv/request.xml

namespace eval core::request {

	variable CFG
	variable INIT
	variable PROCS
	variable INPUTS
	variable ERRORS

	set INIT 0
}


# "-charset_for_check encoding" must be included if:-
# 1: your Tcl strings are loaded into Tcl byte array objects,
#     (e.g. using reqGetArg without "-encoding",
#           and you do not have AS_CHARSET env var set to "UTF-8")
# 2: you use chars above ASCII code 127, where binary and string
#     encodings will be treated differently by Tcl comparison routines.
#
# (default is no charset conversion)
#
# If included, core API will "encoding convertfrom <encoding>"
#  to set the value to be used in the validation procs.
#
# Example:  core::request::init -charset_for_check utf-8
#
core::args::register \
	-proc_name core::request::init \
	-args [list \
		[list -arg -strict_mode       -mand 1 -check BOOL              -desc {Enable Strict Mode.}] \
		[list -arg -log_request_args  -mand 0 -check BOOL  -default 0  -desc {Enable logging of request arguments}] \
		[list -arg -charset_for_check -mand 0 -check ASCII -default {} -desc {Charset to Convert to for validation checks.}] \
		[list -arg -force_init        -mand 0 -check BOOL  -default 0  -desc {Force re-initialisation of request}] \
		[list -arg -x_forwarded_for   -mand 0 -check ASCII -default_cfg NET_HTTP_XFORWARDEDFOR_HEADER -default {HTTP_X_FORWARDED_FOR} -desc {X-Forwarded-for header name}]\
		[list -arg -check_local       -mand 0 -check BOOL  -default_cfg CHECK_LOCAL_ADDR -default {1} -desc {should private scope addresses be excluded from X-Forwarded-for}]\
		[list -arg -options_default_action -mand 0 -check STRING -default_cfg OPTIONS_DEFAULT_ACTION -default {} -desc {Default action handler for OPTIONS request}]\
	]

proc core::request::init args {

	variable CFG
	variable PROCS
	variable INIT

	array set my_args [core::args::check core::request::init {*}$args]

	if {$INIT == 1 && !$my_args(-force_init)} {
		return
	}

	set CFG(strict_mode)      $my_args(-strict_mode)
	set CFG(log_request_args) $my_args(-log_request_args)
	set CFG(-x_forwarded_for) $my_args(-x_forwarded_for)
	set CFG(-check_local)     $my_args(-check_local)
	set CFG(-options_default_action) $my_args(-options_default_action)

	# if charset_for_check non-empty, convert encoding to passed value before running
	# argument validation functions
	set CFG(charset_for_check) $my_args(-charset_for_check)
	if { $CFG(charset_for_check) eq "" } {
		core::log::write INFO {core::request::init - No charset conversion for validation checks}
	} else {
		core::log::write INFO {core::request::init - Using charset <$CFG(charset_for_check)> for all validation checks}
	}

	set CFG(allowed_env_names) [list HTTP_COOKIE REQUEST_METHOD HTTPS SERVER_PORT]

	set proc_names {
		reqGetArg
		reqSetArg
		reqGetArgs
		reqGetNumVals
		reqGetNthName
		reqGetNthVal
		reqGetNthArg
		reqGetEnv
		reqSetEnv
		reqGetEnvNames
	}

	foreach proc_name $proc_names {
		# First rename the old proc so as to hide it.
		set new_proc_name "::__${proc_name}__[clock clicks]"
		rename $proc_name $new_proc_name
		set PROCS($proc_name) $new_proc_name
	}
	_create_wrapper_procs

	set INIT 1
}


core::args::register \
	-proc_name core::request::req_init \
	-args      [list \
		[list -arg -inputs -mand 0 -check ASCII -default 0 -desc {A list of the inputs.}] \
	] \
	-body {
		reset
		populate -inputs $ARGS(-inputs)
		check_missing_args
	}

# Retrieve the mandatory errors
core::args::register \
	-proc_name core::request::get_mandatory_errors \
	-desc      {Retrieve the mandatory parameters that failed validation} \
	-body      {
		variable ERRORS

		set err_list {}

		foreach arg_err $ERRORS(mandatory,args) {
			lappend err_list {*}$ERRORS(mandatory,$arg_err)
		}

		return $err_list
	}

# Retrieve the optional errors
core::args::register \
	-proc_name core::request::get_optional_errors \
	-desc      {Retrieve the optional parameters that failed validation} \
	-args      [list \
		[list -arg -arg_list -mand 0 -check ASCII -default {} -desc {A list optional arguments}] \
	] \
	-body      {
		variable ERRORS

		set arg_list $ARGS(-arg_list)
		set err_list {}

		foreach arg_err $ERRORS(optional,args) {
			if {$arg_list != {} && ($arg_err ni $arg_list)} {
				continue
			}

			lappend err_list {*}$ERRORS(optional,$arg_err)
		}

		return $err_list
	}

# Retrieve the valid args
core::args::register \
	-proc_name core::request::get_valid_input \
	-desc      {Retrieve all valid inputs, args, cookies and env variables} \
	-body      {
		variable INPUTS
		return $INPUTS(valid_list)
	}

# Retrieve the valid env variables
core::args::register \
	-proc_name core::request::get_valid_args \
	-desc      {Retrieve the arguments that passed validation} \
	-body      {
		variable INPUTS
		return $INPUTS(arg_list)
	}

# Retrieve the valid env variables
core::args::register \
	-proc_name core::request::get_valid_envs \
	-desc      {Retrieve the env variables that passed validation} \
	-body      {
		variable INPUTS
		return $INPUTS(env_list)
	}

proc core::request::get_action {} {

	variable PROCS

	set action [$PROCS(reqGetArg) [asGetActivatorName]]

	# If the action is blank, then try the default_action.
	if {$action != {}} {
		return $action
	}

	return [core::controller::get_cfg -config default_action]
}

proc core::request::reset args {

	variable INPUTS
	variable CFG
	variable PATTERNED_ARGS
	variable REQ_ARG_NAMES
	variable REQ_ENV_NAMES
	variable REQ_COOKIES
	variable ERRORS
	variable LOG

	array set INPUTS        [array unset INPUTS]
	array set REQ_ARG_NAMES [array unset REQ_ARG_NAMES]
	array set REQ_ENV_NAMES [array unset REQ_ENV_NAMES]
	array set REQ_COOKIES   [array unset REQ_COOKIES]
	array set ERRORS        [array unset ERRORS]
	array set LOG           [array unset LOG]

	set INPUTS(valid_list) {}
	set INPUTS(arg_list)   {}
	set INPUTS(env_list)   {}

	set LOG(mask_list)     {}

	set ERRORS(optional,args)  [list]
	set ERRORS(mandatory,args) [list]

	set PATTERNED_ARGS [list]
}

core::args::register \
	-proc_name core::request::populate \
	-args      [list \
		[list -arg -inputs -mand 1 -check STRING -desc {The list of inputs.}] \
	]

proc core::request::populate args {

	variable INPUTS
	variable ERRORS
	variable LOG

	core::gc::add core::request::INPUTS
	core::gc::add core::request::ERRORS
	core::gc::add core::request::LOG

	# Setup log masking
	_enable_log_masking

	core::log::write DEBUG {core::request::populate $args}

	array set my_args [core::args::check core::request::populate {*}$args]

	set inputs $my_args(-inputs)

	foreach input $inputs {
		foreach dict [validate_and_get {*}$input] {
			set local_name [dict get $dict -local_name]

			set INPUTS($local_name,arg_dict) $dict

			# We should only add the params if they are valid
			if {[dict get $dict -valid]} {
				switch -- [dict get $dict -type] {
					arg    {lappend INPUTS(arg_list) $local_name}
					header {lappend INPUTS(env_list) $local_name}
				}

				lappend INPUTS(valid_list) $local_name
			} else {
				core::log::write WARNING {core::request::populate: $local_name is invalid}
			}
		}
	}
}

# Input validation has been parsed. We should now add any log masking
proc core::request::_enable_log_masking args {

	variable LOG


	# Ensure the log procedure is in the correct state
	if {[info commands ::_OT_LogWrite_orig] != {}} {

		rename ::OT_LogWrite       {}
		rename ::_OT_LogWrite_orig ::OT_LogWrite
	}

	if {![llength $LOG(mask_list)]} {
		return
	}

	# Create the mask definitions
	set mask_values [list]
	foreach arg $LOG(mask_list) {

		set value [get -name $arg]

		if {[string trim $value] eq ""} {
			continue
		}

		set type  $LOG($arg,mask_type)
		set mask  [core::util::mask_string -mask_type $type -value $value]

		lappend mask_values \
			[list $arg $value $type $mask [string length $value]]
	}

	set mask_def [list]

	# OBCORE-553 sort values in descending order of length to ensure that the
	# whole value is masked.
	foreach mask_value [lsort -integer -decreasing -index 4 $mask_values] {

		lassign $mask_value arg value type mask length
		# Make sure we escape the RegExp value
		set mask_regexp [core::safe::escape_tcl_regexp -str $value]

		set mask_code [subst {
			if {\[regsub -all \{$mask_regexp\} \$msg $mask msg\]} {
				append msg " (masked $arg $type)"
			}
		}]

		lappend mask_def $mask_code
	}

	# Move the original log package out of the way
	rename ::OT_LogWrite ::_OT_LogWrite_orig

	# Create the new proc
	proc ::OT_LogWrite args [subst {

		set msg \[lindex \$args end\]

		[join $mask_def \n]

		# Call the renamed log procedure
		if {\[llength \$args\] == 2} {
			set level \[lindex \$args 0\]
			::_OT_LogWrite_orig \$level \$msg
		} else {
			set fd    \[lindex \$args 0\]
			set level \[lindex \$args 1\]
			::_OT_LogWrite_orig \$fd \$level \$msg
		}
	}]
}

# Add an error for a mandatory or optional argument
# Mandatory arguments will error at req_init stage
# Optional arguments will error at core::request::get stage
#
# @param -mand Optionality of argument
# @param -status Status code
# @param -local_name Name of the argument (internal reference due to patterned args)
# @param -request_name Name of the argument passed in
# @param -error_code Error code to return
core::args::register \
	-proc_name core::request::_add_validation_error \
	-args      [list \
		[list -arg -mand         -mand 1 -check ASCII -desc {Optionality}] \
		[list -arg -status       -mand 1 -check ASCII -desc {Status code}] \
		[list -arg -local_name   -mand 1 -check ASCII -desc {Argument local name}] \
		[list -arg -request_name -mand 1 -check ASCII -desc {Argument request name}] \
		[list -arg -error_code   -mand 1 -check ASCII -desc {The error code to return}] \
	] \
	-body {
		variable ERRORS

		set name        $ARGS(-local_name)
		set optionality [expr {$ARGS(-mand) ? "mandatory" : "optional"}]
		set error_list  [list \
			status       $ARGS(-status) \
			request_name $ARGS(-request_name) \
			local_name   $name \
			error_code   $ARGS(-error_code)]

		lappend ERRORS($optionality,args)  $name

		if {[info exists ERRORS($optionality,$name)]} {
			lappend ERRORS($optionality,$name) $error_list
		} else {
			set ERRORS($optionality,$name) [list $error_list]
		}
	}

# proc:	_get_charset_converted
#
# inputs:  value - incoming value needing validation
# returns: converted_value - <value> converted from embedded charset
#                            ready for validation
#
# Example: set converted_value [_get_charset_converted $value]
proc core::request::_get_charset_converted { value } {

	variable CFG

	if {$CFG(charset_for_check) == ""} {
		# no conversion needed
		return $value
	}

	# convert to supplied encoding
	return [encoding convertfrom $CFG(charset_for_check) $value]
}


core::args::register \
	-proc_name core::request::validate_and_get \
	-args      [list \
		[list -arg -name            -mand 1 -check ASCII                       -desc {The name of the argument.}] \
		[list -arg -name_type       -mand 0 -check ALNUM      -default {exact} -desc {Whether this name is exact (one) or a pattern.}] \
		[list -arg -check_type      -mand 0 -check ALNUM      -default {OR}    -desc {Whether all the checks should pass or just one. Set to AND if all checks must pass, otherwise defaults to OR where at least one check must pass.}] \
		[list -arg -check           -mand 1 -check STRING     -default {}      -desc {A different check type.}] \
		[list -arg -type            -mand 0 -check ASCII      -default {arg}   -desc {The type of input.}] \
		[list -arg -mandatory       -mand 0 -check BOOL       -default 0       -desc {Whether this argument is mandatory.}] \
		[list -arg -default         -mand 0 -check ASCII      -default {}      -desc {The default value for the argument. (If none given.)}] \
		[list -arg -on_err          -mand 0 -check DEPRECATED -default ERR_ARG_VALIDATION -desc {Deprecated - Please use err_msg}] \
		[list -arg -err_msg         -mand 0 -check ASCII      -default ERR_ARG_VALIDATION -desc {The error code to return if this fails validation.}] \
		[list -arg -unsafe_tcl      -mand 0 -check BOOL       -default 0       -desc {Whether to allow unsafe TCL characters. This affects reqGetArg -safe | -unsafe}] \
		[list -arg -unsafe_html     -mand 0 -check BOOL       -default 0       -desc {Whether to allow unsafe HTML characters '<' and '>'.. These will be stripped by default}] \
		[list -arg -max_occurrences -mand 0 -check INT        -default 1       -desc {The maximum number of occurences allowed.}] \
		[list -arg -pp              -mand 0 -check ASCII      -default {}      -desc {A pre-processor script.}] \
		[list -arg -known_as        -mand 0 -check ASCII      -default {}      -desc {The local name of the variable.}] \
		[list -arg -log_mask_type   -mand 0 -check \
			{ENUM -args {CC FULL}}                            -default {}      -desc {Type of mask to apply when logging the argument. Credit cards have a partial mask}] \
	]

proc core::request::validate_and_get args {

	variable PATTERNED_ARGS
	variable LOG

	core::gc::add core::request::PATTERNED_ARGS

	core::log::write DEV {core::request::validate_and_get $args}

	# core::args::check won't allow multiple instances of the same args.
	# However, each input can have multiple -check args.
	set checks     [list]
	set check_list [list]
	set other_args [list]
	foreach {n v} $args {
		if {$n == "-check"} {
			lappend checks $v
			lappend check_list [list $n $v]
		} else {
			lappend other_args $n $v
		}
	}

	# Add the last check to satisfy the mandatory validate_and_get check
	lappend other_args {*}[lindex $check_list end]

	array set my_args [core::args::check core::request::validate_and_get {*}$other_args]

	set name            $my_args(-name)
	set name_type       $my_args(-name_type)
	set check_type      $my_args(-check_type)
	set type            $my_args(-type)
	set default         $my_args(-default)
	set has_default     [dict exists $args -default]
	set unsafe_tcl      $my_args(-unsafe_tcl)
	set unsafe_html     $my_args(-unsafe_html)
	set mandatory       $my_args(-mandatory)
	set max_occurrences $my_args(-max_occurrences)
	set preprocessor    $my_args(-pp)
	set known_as        $my_args(-known_as)
	set is_missing      0
	set err_msg         $my_args(-err_msg)
	set on_err          $my_args(-on_err)

	if {$on_err != {ERR_ARG_VALIDATION}} {
		core::log::write DEBUG {WARNING -on_err is deprecated in favour of -err_msg}
		set err_msg $on_err
	}

	if {$known_as == ""} {
		set known_as $name
	} else {
		if {$name_type != "exact"} {
			# We've specified some kind of pattern matching (i.e. a range of request args) but also specified a known_as.
			# This doesn't make sense, we can't map all the request args to one known_as var.
			# Hence we throw an erroe.
			error "Can't have a known_as if name_type is not exact" {} INVALID_TYPE
		}
	}

	# Add the log mask if not blank
	if {$my_args(-log_mask_type) != {}} {
		set LOG($name,mask_type) $my_args(-log_mask_type)
		lappend LOG(mask_list) $name
	}

	# To save time, we pre-populate the INPUT array based on the args.
	# This is fine for exactly named arguments (if they aren't passed in the
	# request then they get set to the default).
	# But we can't set the defaults for every possible match of a pattern!
	# Thus, if we register a pattern, but an arg that matches it isn't passed
	# in, then it won't be in the INPUT array. This is why we store all the
	# patterns. This way afterwards, we can tell which were registered.
	if {$name_type != "exact"} {
		lappend PATTERNED_ARGS [dict create \
			-request_name    $name \
			-valid           0 \
			-is_missing      $is_missing \
			-local_name      {} \
			-checks          $checks \
			-check_type      $check_type \
			-type            $type \
			-default         $default \
			-has_default     $has_default \
			-name_type       $name_type \
			-mandatory       $mandatory \
			-unsafe_tcl      $unsafe_tcl \
			-unsafe_html     $unsafe_html \
			-value_type      [expr {$max_occurrences > 1 ? {LIST} : {SINGLE}}] \
			-max_occurrences $max_occurrences \
			-err_msg         $err_msg]
	}

	# Now get a list of the value(s).
	set results [list]

	# get_request_value simply returns the actual values from the raw request.
	# It is up to validate_and_get (i.e. this proc) to actually do the validation.
	set items [_get_request_values \
		$name \
		$name_type \
		$type \
		$default \
		$unsafe_tcl \
		$max_occurrences \
	]

	foreach item $items {
		# Remember that name could be different (because of the pattern matching).
		# TODO: an example.
		set local_name  [lindex $item 0]
		set value_type  [lindex $item 1]
		set value       [lindex $item 2]
		set valid       0

		# We return one value on error, even if there was a pattern style name.
		# I think this is a good move, because we want to discourage the use of pattern style req args.
		# Otherwise, there is no disincentive to simply specify one arg for each request: i.e. -name {^.*$}.
		# This way, if you use pattern style names, and one fails, then you get one erroe.

		# Also, remember that this returns a list of elements, and each element is 'array set'ed.
		# So it has to be [list [list ...]]
		set ret [_validate_arg \
			$name \
			$value \
			$value_type \
			$check_type \
			$checks \
			$mandatory \
			$max_occurrences]

		switch -- $ret {
			OK {
				incr valid

				# Right, do we need to do any pre-processing?
				if {$preprocessor != ""} {
					set old_value $value

					switch -- $value_type {
						"SINGLE" {
							set value [$preprocessor $old_value]
						}
						"LIST" {
							set value [list]
							foreach item $old_value {
								lappend value [$preprocessor $item]
							}
						}
					}
				}
			}
			MISSING_OPTIONAL {
				incr valid
				incr is_missing
			}
			INVALID_TYPE {
				error "Invalid type $value_type"
			}
			default {
				_add_validation_error \
					-mand         $mandatory \
					-status       $ret \
					-request_name $name \
					-local_name   $local_name \
					-error_code   $err_msg

				# Override the value since it has failed
				# validation
				set value FAILED_VALIDATION
			}
		}

		lappend results [dict create \
			-request_name    $name \
			-valid           $valid \
			-is_missing      $is_missing \
			-local_name      $local_name \
			-checks          $checks \
			-check_type      $check_type \
			-type            $type \
			-default         $default \
			-has_default     $has_default \
			-name_type       $name_type \
			-mandatory       $mandatory \
			-unsafe_tcl      $unsafe_tcl \
			-unsafe_html     $unsafe_html \
			-value_type      [expr {$max_occurrences > 1 ? {LIST} : {SINGLE}}] \
			-max_occurrences $max_occurrences \
			-err_msg         $err_msg]
	}

	return $results
}



#################################################################
# core::request::_validate_arg
#
# Private procedure to check that an arguments value(s) are valid
#################################################################
#
# @param name             ASCII  Argument name, may be different to registered name due to pattern matching
# @param value            ANY    Value to validate
# @param value_type       ASCII  Type of value
# @param check_type       ALNUM  Whether all the checks should pass or just one. Set to AND if all checks must pass, otherwise defaults to OR where at least one check must pass.
# @param checks           ASCII  List of checks to apply
# @param mandatory        BOOL   Whether this argument is mandatory.
# @param max_occurrences  INT    The maximum number of occurences allowed.
#
proc core::request::_validate_arg {name value value_type check_type checks mandatory max_occurrences} {

	variable PROCS

	# Validate the parameters
	switch -- $value_type {
		"SINGLE" {
			set converted_value [_get_charset_converted $value]
			if {![core::check::check_value $converted_value $check_type $checks $name]} {
				return INVALID_VALUE
			}

			# Validate that more than 1 argument with the
			# this name hasnt been passed in
			if {[llength [$PROCS(reqGetArgs) $name]] > 1} {
				return TOO_MANY_VALUES
			}
		}
		"LIST" {
			# Check we don't have too many
			if {$max_occurrences > 0 && [llength $value] > $max_occurrences} {
				return TOO_MANY_VALUES
			}

			foreach item $value {
				set converted_item [_get_charset_converted $item]
				if {![core::check::check_value $converted_item $check_type $checks $name]} {
					return INVALID_VALUE
				}
			}

		}
		"NOT_FOUND" {
			if {$mandatory} {
				return MISSING_MANDATORY
			} else {
				return MISSING_OPTIONAL
			}
		}
		default {
			return INVALID_TYPE
		}
	}

	return OK
}

# Check an argument name against the list of registered args for that
# handler and then validate that its value is correct against the different check types
#
# 1. We need to establish the registered arg that this value matches
#   * Pull out the registered args for the called handler
#   * Loop over all exact arguments and see if it matches
#   * If no match loop over regexp args and check if it matches
#
# 2. Once we have a match we pull back the checks
#   *
#
core::args::register \
	-proc_name core::request::check_arg \
	-args      [list \
		[list -arg -name  -mand 1 -check ASCII -desc {The name of the argument.}] \
		[list -arg -value -mand 1 -check ANY   -desc {The value of the arg to set.}] \
	] \
	-body {
		set name  $ARGS(-name)
		set value $ARGS(-value)

		set exact_args   [list]
		set pattern_args [list]
		set ret          UNKNOWN_ARG
		set action       [get_action]
		set arg_list     [core::controller::get_action_args $action]
		set found        0

		# Check the argument list to see if we have a direct match
		if {$name in $arg_list} {
			incr found
		} else {
			# We don't have a direct match so we should check patterned args
			if {[_get_non_exact_arg_details $name] != {}} {
				incr found
			}
		}

		if {!$found} {
			return UNKNOWN_ARG
		}

		return [_validate_arg \
			$name \
			$value \
			[_get_arg_cfg $name -value_type] \
			[_get_arg_cfg $name -check_type] \
			[_get_arg_cfg $name -checks] \
			[_get_arg_cfg $name -mandatory] \
			[_get_arg_cfg $name -max_occurrences]]
	}



#########################################
# core::request::_get_request_values
#
# Private procedure to get request values
#########################################
#
# @param name             ASCII  The name of the argument.
# @param name_type        ASCII  Whether we are using a pattern or not.
# @param type             ASCII  The type of input.
# @param default          ASCII  The default value for the argument.
# @param unsafe_tcl       BOOL   Whether to allow unsafe characters.
# @param max_occurrences  INT    Whether this is a max_occurrencesable arg.
#
proc core::request::_get_request_values {name name_type type default unsafe_tcl max_occurrences} {
	variable PROCS
	variable REQ_ARG_NAMES
	variable REQ_ENV_NAMES
	variable REQ_COOKIES

	set names [list]

	# Right, based on name_type, we need to do some expanding.
	if {$name_type == "exact"} {
		# Nice and simple!
		lappend names $name
	} else {
		# Oh no. We have a pattern, and want any value that has a name that matches the pattern :(
		# So, we fetch the list of names, and parse them all.
		set all_names [list]
		switch -- $type {
			"arg" {
				_fetch_req_arg_names
				set all_names $REQ_ARG_NAMES(names)
			}
			"env" {
				_fetch_req_env_names
				set all_names $REQ_ENV_NAMES(names)
			}
			"cookie" {
				_parse_cookies
				set all_names $REQ_COOKIES(cookie_list)
			}
		}

		core::log::write DEV {$name_type all_names=$all_names}

		# If name_type is not exact, then name is the pattern.
		foreach input_name $all_names {
			switch -- $name_type {
				glob {
					if {[string match $name $input_name]} {
						lappend names $input_name
					}
				}
				regexp {
					if {[regexp -- $name $input_name]} {
						lappend names $input_name
					}
				}
				default {
					error "Invalid name_type $name_type"
				}
			}
		}
	}

	core::log::write DEV {names=$names}
	set results [list]

	foreach input_name $names {
		set result [_get_request_value \
			$input_name \
			$type \
			$default \
			$unsafe_tcl \
			$max_occurrences \
		]

		lappend results $result
	}

	return $results
}

core::args::register \
	-proc_name core::request::check_missing_args \
	-desc {check and log if the request has some arguments not expected in the handler} \
	-body {
		variable INPUTS
		variable REQ_ARG_NAMES
		set missing_params [list]

		_fetch_req_arg_names

		core::log::write DEBUG {core::request::check_missing_args expected: $INPUTS(arg_list), received: $REQ_ARG_NAMES(names) }

		foreach param $REQ_ARG_NAMES(names) {
			if {$param != "action" &&  !($param in $INPUTS(arg_list)) } {
				lappend missing_params $param
				core::log::write WARNING {core::request::check_missing_args the argument $param was not defined in the handler}
			}
		}

		return $missing_params
	}



##########################################
# core::request::_get_request_value
#
# Private procedure to get a request value
##########################################
#
# @param name             ASCII  The name of the argument.
# @param type             ASCII  The type of input.
# @param default          ASCII  The default value for the argument.
# @param unsafe_tcl       BOOL   Whether to allow unsafe characters.
# @param max_occurrences  INT    Whether this is a max_occurrencesable arg.
#
proc core::request::_get_request_value {name type default unsafe_tcl max_occurrences} {

	variable PROCS
	variable REQ_ARG_NAMES
	variable REQ_COOKIES
	variable REQ_ENV_NAMES

	set allowed_types   [list cookie header arg]

	# Most of the raw appserv procs simply return "" if the string wasn't found.
	# We might need to be able to distinguish between an input not being passed in, and it being passed in as "".
	set found_value 0

	# If we don't find a value, then fall back to the default.
	set value      $default
	set value_type SINGLE

	# max_occurrences is only relevant for request args.
	# E.g. &user_id=13&user_id=14&user_id=44 should return a list: [list 13 14 55].
	# If max_occurrences is 1, we only look for one value though.
	# So even if made sense to have a max_occurrences value that wasn't 1 for cookie or headers (and it doesn't),
	# I simply don't have the will to implement such a thing.
	if {$max_occurrences > 1 && $type != {arg}} {
		error "max_occurrences can only be greater than 1 if the type is arg."
	}

	switch -- $type {
		arg {
			_fetch_req_arg_names

			if {$name in $REQ_ARG_NAMES(names)} {
				set found_value 1
			}

			if {$found_value} {
				if {$max_occurrences == 1} {
					if {$unsafe_tcl} {
						set value [$PROCS(reqGetArg) -unsafe $name]
					} else {
						set value [$PROCS(reqGetArg) $name]
					}
				} else {
					# Eep! we are expecting a list (i.e. max_occurrences isn't exactly 1).
					set value_type LIST
					if {$unsafe_tcl} {
						set value [$PROCS(reqGetArgs) -unsafe $name]
					} else {
						set value [$PROCS(reqGetArgs) $name]
					}
				}
			}
		}
		cookie {
			_parse_cookies

			if {[info exists REQ_COOKIES(cookie,$name)]} {
				set value       $REQ_COOKIES(cookie,$name)
				set found_value 1
			}
		}
		header {
			_fetch_req_env_names

			set found_value 0
			if {$name in $REQ_ENV_NAMES(names)} {
				set found_value 1
				set value [$PROCS(reqGetEnv) $name]
			}
		}
		default {
			error "Invalid type: must be one of [join $allowed_types ,]"
		}
	}

	# Whether it was a list, single value etc count for nothing if we didn't find anything!
	if {!$found_value} {
		set value_type NOT_FOUND
	}

	return [list $name $value_type $value]
}

proc core::request::_fetch_req_arg_names { {force 0} } {

	variable PROCS
	variable REQ_ARG_NAMES
	# Make sure that this is cleaned up!
	core::gc::add core::request::REQ_ARG_NAMES

	# Return if we've already fetched them.
	if {[info exists REQ_ARG_NAMES(fetched)] && !$force} {
		return
	}

	set REQ_ARG_NAMES(names) [list]
	for {set i 0} {$i < [$PROCS(reqGetNumVals)]} {incr i} {
		lappend REQ_ARG_NAMES(names) [$PROCS(reqGetNthName) $i]
	}

	set REQ_ARG_NAMES(fetched) 1
}



proc core::request::_fetch_req_env_names args {

	variable PROCS
	variable REQ_ENV_NAMES
	# Make sure that this is cleaned up!
	core::gc::add core::request::REQ_ENV_NAMES

	# Return if we've already fetched them.
	if {[info exists REQ_ENV_NAMES(fetched)]} {
		return
	}

	set REQ_ENV_NAMES(names) [$PROCS(reqGetEnvNames)]
	set REQ_ENV_NAMES(fetched) 1
}


proc core::request::_parse_cookies args {

	variable PROCS
	variable REQ_COOKIES

	core::gc::add core::request::REQ_COOKIES

	# Return if we have already parsed the cookies this request
	if {[info exists REQ_COOKIES(parsed)]} {
		return
	}

	set cookie_string [$PROCS(reqGetEnv) HTTP_COOKIE]

	# Make sure this always exists - note this variable is garbage collected
	# so will get reset on each request.
	if {![info exists REQ_COOKIES(cookie_list)]} {
		set REQ_COOKIES(cookie_list) [list]
	}

	foreach component [split $cookie_string ";"] {

		set component [string trim $component]
		if {![string length $component]} {
			continue
		}

		set idx [string first "=" $component]
		if {$idx == -1} {
			error "Problem parsing cookie in $cookie_string"
		}

		set name  [string range $component 0 [expr {$idx - 1}]]
		set value [string range $component [expr {$idx + 1}] end]

		set REQ_COOKIES(cookie,$name) $value
		lappend REQ_COOKIES(cookie_list) $name
	}

	set REQ_COOKIES(parsed) 1

	return
}



# Retrieve a parsed cookie
proc core::request::_get_cookie { name } {

	_parse_cookies

	variable REQ_COOKIES

	if {[info exists REQ_COOKIES(cookie,$name)]} {
		return $REQ_COOKIES(cookie,$name)
	}

	error "Unable to find cookie $name" {} MISSING_COOKIE
}

# Public interface to core::request::_get_arg_cfg
core::args::register \
	-proc_name core::request::get_arg_cfg \
	-args      [list \
		[list -arg -name -mand 1 -check ASCII -desc {The name of the arg}] \
		[list -arg -key  -mand 1 -check ASCII -desc {The argument property}] \
	] \
	-body {
		return [_get_arg_cfg $ARGS(-name) $ARGS(-key)]
	}

# Private procedure to retrieve an argument definition
proc core::request::_get_arg_cfg {name key} {

	variable INPUTS

	if {![info exists INPUTS($name,arg_dict)]} {

		# See if we are looking at a pattern instead of an exact argument
		set dict [_get_non_exact_arg_details $name]

		if {$dict == {}} {
			error "Argument dictionary not defined for $name" {} UNKNOWN_DICT
		}
	} else {
		set dict $INPUTS($name,arg_dict)
	}

	if {![dict exists $dict $key]} {
		error "Key $key missing for argument dictionary $name" {} UNKNOWN_KEY
	}

	return [dict get $dict $key]
}



core::args::register \
	-proc_name core::request::get \
	-args      [list \
		[list -arg -name   -mand 1 -check ASCII -desc {The name of the arg to fetch.}] \
		[list -arg -type   -mand 0 \
			-check   {ENUM -args {arg args header cookie}} \
			-default arg \
			-desc    {The type of object(s) to fetch.}] \
		[list -arg -on_err -mand 0 \
			-check   {ENUM -args {THROW DEFAULT ON_VALID_ERR}} \
			-default UNSET \
			-desc    {What to do if the argument doesn't pass validation}] \
	] \
	-body {
		variable PROCS
		variable ERRORS

		set name         $ARGS(-name)
		set type         $ARGS(-type)
		set on_err       $ARGS(-on_err)

		if {$on_err == {UNSET}} {
			set on_err [core::controller::get_cfg -config opt_arg_error_handling -default THROW]
		}

		# If the action has not be registered then we should just
		# use the original reqGetArg
		if {![core::controller::is_action_registered -action [get_action]]} {

			switch -- $type {
				arg {
					return [$PROCS(reqGetArg) $name]
				}
				args {
					return [$PROCS(reqGetArgs) $name]
				}
				cookie {
					return [core::request::_get_cookie $name]
				}
				header {
					return [$PROCS(reqGetEnv) $name]
				}
			}
		}

		# Check if there have been any errors with this argument
		if {[info exists ERRORS(optional,$name)]} {
			return [_handle_optional_arg_error \
				$name \
				$on_err \
				"REQUEST: ERROR Validation of $name failed $ERRORS(optional,$name) ($on_err)" \
				$ERRORS(optional,$name)]
		}

		if {$name in [core::request::get_valid_input]} {

			set registered_type [_get_arg_cfg $name -type]
			set mismatch        0

			switch -- $type {
				arg -
				args {
					if {$registered_type != {arg}} {
						incr mismatch
					}
				}
				default {
					if {$registered_type != $type} {
						incr mismatch
					}
				}
			}

			if {$mismatch} {
				return [_handle_optional_arg_error \
					$name \
					$on_err \
					"REQUEST: ERROR mismatched type $type, $name is $registered_type"]
			}

			if {![_get_arg_cfg $name -is_missing]} {

				# If the argument is defined as expecting unsafe data we
				# should pass this through to the appserver command.
				# Registering this means that the usage can be audited from
				# the action handler
				set flags {}
				if {[_get_arg_cfg $name -unsafe_tcl]} {
					set flags {-unsafe}
				}

				switch -- $type {
					arg    {set value [$PROCS(reqGetArg)  {*}$flags $name]}
					args   {set value [$PROCS(reqGetArgs) {*}$flags $name]}
					header {set value [$PROCS(reqGetEnv) $name]}
					cookie {
						# If the cookie is not available we should throw an error
						if {[catch {set value [core::request::_get_cookie $name]} err]} {
							return [_handle_optional_arg_error \
								$name \
								$on_err \
								$err]
						}
					}
				}
			} else {

				set value [_get_arg_cfg $name -default]
			}

			# Strip unsafe html characters if defined
			if {![_get_arg_cfg $name -unsafe_html] && [set count [regsub -all {[<>]} $value {} value]]} {
				core::log::write WARNING {Stripped $count unsafe html characters from $name (<>)}
			}

			return $value
		}

		# Right, there was no value in the INPUTS array for the name.
		# But that doesn't mean that it wasn't registered.
		# E.g. we could have a glob arg NAME_*, but NAME_1 wasn't passed
		# in the request. Thus NAME_1 won't be in the INPUT array.
		# So we check if it was registered (and check defaults).
		set res [_get_non_exact_arg_details $name]

		if {[llength $res] != 0} {
			array set ARG $res

			# Arg was registered!
			if {[info exists ARG(-default)]} {
				return $ARG(-default)
			} else {
				return [_handle_optional_arg_error \
					$name \
					$on_err \
					"REQUEST: ERROR $name does not have a default value"]
			}
		}

		# We haven't found a value, this means that the arg wasn't registered with the Request API.
		return [_handle_optional_arg_error \
			$name \
			$on_err \
			"REQUEST: ERROR $name has not been registered"]
	}

# Handle an error on an optional argument
proc core::request::_handle_optional_arg_error {name on_err msg {err_list {}}} {

	switch -- $on_err {
		THROW {
			core::log::write_stack DEV
			error $msg {} $on_err

		}
		DEFAULT {
			# On validation error return the default. If there is no default value then throw
			if {[_get_arg_cfg $name -has_default]} {
				return [_get_arg_cfg $name -default]
			} else {
				core::log::write_stack DEV
				error $msg {} $on_err
			}
		}
		ON_VALID_ERR {
			# Throw the handlers on_valid_err handler
			array set ACTIONS [core::controller::get_action [get_action]]

			set on_valid_err $ACTIONS(err_INPUT)

			# Call the registered proc
			$on_valid_err {*}$err_list

			# Throw an error so we don't continue with the rest of the handler
			error $msg {} $on_err
		}
	}
}

# We should be allowed to set request args that have been defined by the controller
# handler. The new value should be matched against the registered arg and validated
# Then we are safe to use the standard appserver reqSetArg
core::args::register \
	-proc_name core::request::set_arg \
	-args      [list \
		[list -arg -name     -mand 1 -check ASCII           -desc {The name of the arg to set.}] \
		[list -arg -value    -mand 1 -check ANY             -desc {The value of the arg to set.}] \
		[list -arg -type     -mand 0 \
			-check   {ENUM -args {arg header}} \
			-default arg \
			-desc    {The type of object to set.}] \
		[list -arg -validate -mand 0 -check BOOL -default 1 -is_public 0 \
			-desc {Validate the setting of an argument. This should never be skipped unless when setting the action pre-hander}] \
		[list -arg -on_err -mand 0 \
			-check   {ENUM -args {THROW DEFAULT ON_VALID_ERR}} \
			-default UNSET \
			-desc    {What to do if the argument doesn't pass validation}] \
	] \
	-body {
		variable CFG
		variable INPUTS
		variable ERRORS
		variable PROCS

		set name   $ARGS(-name)
		set value  $ARGS(-value)
		set type   $ARGS(-type)
		set on_err $ARGS(-on_err)

		if {$on_err == {UNSET}} {
			set on_err [core::controller::get_cfg -config opt_arg_error_handling -default THROW]
		}

		# The action is registered so it needs to be treated as strict
		if {$name != {action} && $ARGS(-validate)} {
			set ret [check_arg -name  $name -value $value]
			if {$ret != {OK}} {
				_add_validation_error \
					-mand         [_get_arg_cfg $name -mandatory] \
					-status       $ret \
					-request_name $name \
					-local_name   [_get_arg_cfg $name -local_name] \
					-error_code   [_get_arg_cfg $name -err_msg]

				return [_handle_optional_arg_error \
					$name \
					$on_err \
					$ret]
			}

			# Update the argument dictionary to indicate that the
			if {[info exists INPUTS($name,arg_dict)]} {
				dict set INPUTS($name,arg_dict) -is_missing 0
			} else {

				# The default key will not be there if it is mandatory
				# Would not have been populated. We should now populate
				# For the specific argument
				set pattern_dict [_get_non_exact_arg_details $name]
				if {$pattern_dict != {}} {
					set INPUTS($name,arg_dict) $pattern_dict

					dict set INPUTS($name,arg_dict) -request_name $name
				}
			}
		}

		# Set the argument via the original proc
		switch -- $type {
			arg {
				$PROCS(reqSetArg) $name $value

				lappend INPUTS(arg_list) $name
			}
			header {
				$PROCS(reqSetEnv) $name $value

				lappend INPUTS(env_list) $name
			}
		}

		lappend INPUTS(valid_list) $name

		# Unset any previous error on the argument
		array unset ERRORS "optional,$name"

		set ERRORS(optional,args) [core::util::ldelete $ERRORS(optional,args) $name]
	}

# Return whether an argument exists in raw request
core::args::register \
	-proc_name core::request::arg_exists \
	-desc      {Return whether argument exists in request} \
	-args      [list \
		[list -arg -name -mand 1 -check ASCII -desc {The name of the arg to check}] \
	] \
	-body {
		variable REQ_ARG_NAMES

		core::log::write DEV {core::request::arg_exists $args}

		if {![info exists REQ_ARG_NAMES(names)] || ($ARGS(-name) ni $REQ_ARG_NAMES(names))} {
			return 0
		}

		return 1
	}

core::args::register \
	-proc_name core::request::get_args \
	-args      [list \
		[list -arg -name -mand 1 -check ASCII -desc {DEPRECATED use core::request::get -type args}] \
	] \
	-body {
		return [get -type args -name $ARGS(-name)]
	}

core::args::register \
	-proc_name core::request::get_num_vals \
	-body {
		return [llength [core::request::get_valid_args]]
	}

core::args::register \
	-proc_name core::request::get_nth_name \
	-args      [list \
		[list -arg -n -mand 1 -check UINT -desc {The index of the name to fetch.}] \
	] \
	-body {
		return [lindex [core::request::get_valid_args] $ARGS(-n)]
	}

core::args::register \
	-proc_name core::request::get_nth_value \
	-args      [list \
		[list -arg -n -mand 1 -check UINT -desc {The index of the value to fetch.}] \
	] \
	-body {
		variable PROCS

		set name [lindex [core::request::get_valid_args] $ARGS(-n)]

		return [$PROCS(reqGetArg) $name]
	}

core::args::register \
	-proc_name core::request::get_nth_arg \
	-args      [list \
		[list -arg -name  -mand 1 -check ASCII -desc {The name of the arg to set.}] \
		[list -arg -n     -mand 1 -check UINT  -desc {The index of the value to fetch.}] \
	] \
	-body {
		variable PROCS

		set arg_list [::core::request::get -type args -name $ARGS(-name)]

		return [lindex $arg_list $ARGS(-n)]
	}

# Return valid env names
core::args::register \
	-proc_name core::request::get_env_names \
	-body {
		variable PROCS

		if {![core::controller::is_action_registered -action [get_action]]} {
			return [$PROCS(reqGetEnvNames)]
		}

		return [core::request::get_valid_envs]

	}

# Match argument name against list of patterned arguments.
# These are arguments registered using a name_type of regexp or glob
proc core::request::_get_non_exact_arg_details {name} {

	variable PATTERNED_ARGS

	foreach pattern_dict $PATTERNED_ARGS {

		set pattern_name [dict get $pattern_dict -request_name]
		set name_type    [dict get $pattern_dict -name_type]

		if {
			($name_type == "glob"   && [string match $pattern_name $name]) ||
			($name_type == "regexp" && [regexp -- $pattern_name $name])
		} {
			return $pattern_dict
		}
	}

	return [list]
}

# Internal proc to retrieve user agent
core::args::register \
	-proc_name core::request::_get_http_user_agent \
	-is_public 0 \
	-desc      {Parse and return the HTTP_USER_AGENT env value} \
	-body {
		variable PROCS

		set user_agent [$PROCS(reqGetEnv) HTTP_USER_AGENT]

		if {![core::check::ascii $user_agent]} {
			error "Invalid non-ASCII User-Agent"
		}

		return $user_agent
	}

# Internal proc to retrieve accept encoding
core::args::register \
	-proc_name core::request::_get_http_accept_encoding \
	-is_public 0 \
	-desc      {Parse and return the HTTP_ACCEPT_ENCODING env value} \
	-body {
		variable PROCS

		set accept [$PROCS(reqGetEnv) HTTP_ACCEPT_ENCODING]

		if {![core::check::ascii $accept]} {
			error "Invalid non-ASCII Accept-Encoding"
		}

		return $accept
	}

core::args::register \
	-proc_name core::request::get_client_ip \
	-desc      {Returns IP of request origin based on REMOTE_ADDR and HTTP_X_FORWARDED_FOR values. Only trust this value if you know the operator is stripping the corresponding HTTP headers and then setting them} \
	-args      [list \
		[list -arg -check_local -mand 0 -check BOOL -default_cfg CHECK_LOCAL_ADDR -default 1 -desc {should private scope addresses be excluded}]\
	] \
	-body {
		variable PROCS
		variable CFG

		set remote_addr [$PROCS(reqGetEnv) REMOTE_ADDR]
		set xhead       $CFG(-x_forwarded_for)
		set check_local $ARGS(-check_local)

		# try to get X-Forwarded-for. On failure (not declared?) return REMOTE_ADDR
		if {[catch {
			set xforward [$PROCS(reqGetEnv) $xhead]
		} msg]} {
			if {[core::check::ip $remote_addr] } {
				core::log::write WARNING {core::request::get_client_ip: Unable to get $xhead header. Returning REMOTE_ADDR}
				return $remote_addr
			} else {
				core::log::write ERROR {core::request::get_client_ip: $xhead not found and REMOTE_ADDR ($remote_addr) is invalid}
				error {Invalid REMOTE_ADDR}
			}
		}

		return [core::request::_determine_client_ip \
			-remote_addr $remote_addr \
			-xforward    $xforward \
			-check_local $check_local]
	}

core::args::register \
	-proc_name core::request::_determine_client_ip \
	-desc      {Returns IP of request origin based on REMOTE_ADDR and HTTP_X_FORWARDEF_FOR values} \
	-args      [list \
		[list -arg -remote_addr -mand 1 -check IPADDR             -desc {REMOTE_ADDR value from HTTP header}] \
		[list -arg -xforward    -mand 0 -check ASCII -default {}  -desc {HTTP_X_FORWARDED_FOR value from HTTP header}] \
		[list -arg -check_local -mand 0 -check BOOL  -default {1} -desc {should private scope addresses be excluded}]\
	] \
	-body {
		set ip_addr       $ARGS(-remote_addr)
		set check_local   $ARGS(-check_local)
		set forwarded_ips [split $ARGS(-xforward) ","]

		for {set i 0} {$i < [llength $forwarded_ips]} {incr i} {
			set fwd_ip [string map {" " ""} [lindex $forwarded_ips $i]]

			if {[core::check::ipv4 $fwd_ip]} {

				if {[core::check::is_ipv4_localhost $fwd_ip]} {
					core::log::write WARNING {core::request::_determine_client_ip: ignoring xforward IPv4 localhost IP $fwd_ip}
					continue
				}
				if {$check_local && [core::check::is_ipv4_private $fwd_ip]} {
					core::log::write WARNING {core::request::_determine_client_ip: ignoring xforward IPv4 private IP $fwd_ip}
					continue
				}

				return $fwd_ip

			} elseif {[core::check::ipv6 $fwd_ip]} {

				if {[core::check::is_ipv6_localhost $fwd_ip]} {
					core::log::write WARNING {core::request::_determine_client_ip: ignoring xforward IPv6 localhost IP $fwd_ip}
					continue
				}

				return $fwd_ip

			} else {
				core::log::write ERROR {core::request::_determine_client_ip: Invalid value in X-Forwarded-For header: $fwd_ip}
				error {Invalid X-Forwarded-For Header}
			}
		}

		core::log::write DEBUG {core::request::_determine_client_ip: returns $ip_addr based on REMOTE_ADDR: $ip_addr AND X-Forwarded For $ARGS(-xforward)}
		return $ip_addr
	}


#-------------------------------------------------------------------------------
# URI Handling
#-------------------------------------------------------------------------------
core::args::register \
	-proc_name core::request::register_uri \
	-desc      "Registers a URI with the address parser." \
	-args [list \
		[list -arg -context -mand 0 -check LIST  -default [list] -desc "The HTTP request types allowed for this URI binding."] \
		[list -arg -path    -mand 1 -check ASCII                 -desc "The URI path to match."] \
		[list -arg -action  -mand 1 -check ASCII                 -desc "The action to be used when this path is encountered."] \
		[list -arg -args    -mand 0 -check LIST  -default [list] -desc "The names of request arguments that should be set by any wildcards encountered in the path."] \
	] \
	-body {
		variable CFG

		set fn {core::request::register_uri}
		core::log::write DEBUG {$fn}

		# Retrieve our arguments.

		set context $ARGS(-context)
		set path    $ARGS(-path)
		set action  $ARGS(-action)
		set args    $ARGS(-args)

		set path    [string trim $path]
		set action  [string trim $action]

		# Validate the provided contexts.

		foreach method $context {
			if {[lsearch {POST GET PUT DELETE PATCH OPTIONS} $method] == -1} {
				core::log::write WARNING {$fn - Unknown HTTP request type: $method - $path}
				return
			}
		}

		if {![llength $context]} {
			set context [list "ALL"]
		}

		# Split the path into parts, and remove any empty sections.

		set parts [list]

		foreach part [split $path {/}] {
			if {$part != {}} {
				lappend parts $part
			}
		}

		if {[llength $parts] == 0} {
			core::log::write WARNING {$fn - Ignoring blank path: $path}
			return
		}

		# Check that the path has not already been registered for the given
		# contexts.

		set path [join $parts "/"]

		foreach method $context {
			if {[info exists CFG(URI,PATH,$method,$path)]} {
				core::log::write WARNING {$fn - Overriding existing path: $path ($method)}
			}
		}

		# Now we reverse the elements in our path. The reason for this is that
		# we do not know how many leading parts an incoming URI will contain, so
		# we use the final element as our 'point zero', rather than the start.

		set parts [lreverse $parts]
		set args  [lreverse $args]

		# Iterate through and determine which parts are static and which are
		# wildcards.

		set static    [list]
		set wildcards [list]

		for {set i 0} {$i < [llength $parts]} {incr i} {
			if {[lindex $parts $i] == "*"} {
				lappend wildcards $i
			} else {
				lappend static    $i
			}
		}

		if {[llength $static] == 0} {
			core::log::write WARNING {$fn - Ignoring all wildcard path: $path}
			return
		}

		if {[llength $wildcards] != [llength $args]} {
			core::log::write WARNING {$fn - Wildcard count does not match arguments list: $path - $args}
			return
		}

		# Calculate a weighting for this path. Effectively we want the left most
		# (pre-reversal) non-wildcard part of the path to add more to the
		# weighting, so that longer paths have a higher precedence, and static
		# sections beat a wildcard. Finally, anything where a context was
		# provided should have a higher weighting than the 'ALL' context.

		set weight 0

		foreach position $static {
			incr weight [expr {2 << $position}]
		}

		if {[lindex $context 0] != "ALL"} {
			incr weight
		}

		# Build a lookup entry that will allow us to match the URI to an action
		# efficiently. This uses the left most (pre-reversal) non-wildcard part
		# of the path as an initial key to narrow the search scope.

		set position [lindex $static end      ]
		set key      [lindex $parts  $position]
		set id       [OT_UniqueId]

		foreach method $context {
			lappend CFG(URI,LOOKUP,$method,$position,$key) $id
		}

		# Now add details of the path elements, along with the action, to the
		# entry.

		set CFG(URI,$id,ACTION) $action
		set CFG(URI,$id,WEIGHT) $weight
		set CFG(URI,$id,STATIC) [list]
		set CFG(URI,$id,ARGS)   [list]

		for {set i 0} {$i < [llength $static]} {incr i} {
			set position [lindex $static $i]
			set item     [lindex $parts  $position]
			lappend CFG(URI,$id,STATIC) [list $position $item]
		}

		for {set i 0} {$i < [llength $wildcards]} {incr i} {
			set position [lindex $wildcards $i]
			set arg      [lindex $args      $i]
			lappend CFG(URI,$id,ARGS) [list $position $arg]
		}

		# Store a record of each path/method, and log the successful addition.

		foreach method $context {
			set CFG(URI,PATH,$method,$path) $id
			core::log::write INFO {$fn - Registered URI: $path ($method) -> $action}
		}

		return
	}


core::args::register \
	-proc_name core::request::handle_uri \
	-is_public 0 \
	-desc      "Parses an incoming URI to determine the request action to take." \
	-returns   "The request action to be performed." \
	-body {
		variable CFG
		variable REQUEST

		set fn {core::request::handle_uri}
		core::log::write DEBUG {$fn}

		# Retrieve the URI and request method.

		set request_uri          [core::request::get -type header -name REQUEST_URI                ]
		set request_method       [core::request::get -type header -name REQUEST_METHOD             ]
		set request_override     [core::request::get -type header -name HTTP_X_HTTP_METHOD_OVERRIDE]
		set request_content_type [core::request::get -type header -name CONTENT_TYPE               ]
		set request_protocol     [core::request::get -type header -name SERVER_PROTOCOL            ]
		set request_unique_id    [core::request::get -type header -name UNIQUE_ID                  ]
		set request_user_agent   [core::request::get -type header -name HTTP_USER_AGENT            ]

		if {$request_override != {}} {
			set request_method $request_override
		}

		# Remove any GET arguments and fragment identifiers.

		set position [string first "?" $request_uri]

		if {$position != -1} {
			set request_uri [string range $request_uri 0 [expr {$position -1}]]
		}

		set position [string first "#" $request_uri]

		if {$position != -1} {
			set request_uri [string range $request_uri 0 [expr {$position -1}]]
		}

		# Break the URI down into its individual parts, removing any blank
		# sections.

		set parts [list]

		foreach part [split $request_uri {/}] {
			if {$part != {}} {
				lappend parts $part
			}
		}

		# Now we reverse the elements in our path. The reason for this is that
		# we do not know how many leading parts an incoming URI will contain, so
		# we use the final element as our 'point zero', rather than the start.

		set parts [lreverse $parts]

		# Iterate through from the left (pre-reversal) and use the lookup table
		# to find matches.

		set matches [list]

		for {set i 0} {$i < [llength $parts]} {incr i} {
			if {[info exists CFG(URI,LOOKUP,$request_method,$i,[lindex $parts $i])]} {
				set matches [concat $matches $CFG(URI,LOOKUP,$request_method,$i,[lindex $parts $i])]
			}
			if {[info exists CFG(URI,LOOKUP,ALL,$i,[lindex $parts $i])]} {
				set matches [concat $matches $CFG(URI,LOOKUP,ALL,$i,[lindex $parts $i])]
			}
		}

		# Because we matched from 'point zero', and our lookups are weighted to
		# longer paths, reversing the list of matches will put longer potential
		# matches first, creating a small perfomance improvement.
		set matches [lreverse $matches]
		# Iterate through our potential matches, finding the one that matches
		# all static parts with the highest weighting.

		set weight -1
		set id     {}

		foreach match $matches {
			if {$CFG(URI,$match,WEIGHT) < $weight} {
				continue
			}

			set fail 0

			foreach static $CFG(URI,$match,STATIC) {
				set position [lindex $static 0]
				set item     [lindex $static 1]
				if {[lindex $parts $position] != $item} {
					set fail 1
					break
				}
			}

			if {$fail} {
				continue
			}

			set id     $match
			set weight $CFG(URI,$match,WEIGHT)
		}

		# If we have a match, set the action and any arguments, otherwise use
		# the action argument itself.
		if {$id != {}} {
			set routing "URI"
			set action  $CFG(URI,$id,ACTION)
			set outcome [list action $action]
			foreach arg $CFG(URI,$match,ARGS) {
				set position [lindex $arg 0]
				set arg      [lindex $arg 1]
				lappend outcome $arg
				lappend outcome [lindex $parts $position]
			}
		} else {

			set routing "ACTION"
			set action  [core::request::get -name [asGetActivatorName]]

			if {$request_method == "OPTIONS" && $CFG(-options_default_action) != ""} {

				set routing "DEFAULT"
				set action  $CFG(-options_default_action)
			} elseif {![core::controller::is_action_registered -action $action]} {

				set routing "DEFAULT"
				set action [core::controller::get_cfg -config default_action]
			}

			set outcome [list action $action]
		}

		# Log the determined action and request details.

		set ip [core::request::get_client_ip]
		core::log::write INFO {\[request\] $ip "$request_method $request_uri $request_protocol" "$routing" "$action" "$request_unique_id" "$request_user_agent"}

		# Return the determined action.

		return $outcome
	}



# Log request handler and arguments.
#
#   @action  the action to log
#   @handler the handler to log
#
proc core::request::_log_request {action handler} {

	variable CFG

	if {!$CFG(log_request_args)} {
		return
	}

	# The following code uses the appserv reqGet* procs rather than
	# core::request::* so that the logging works for non-registered handlers
	set log_args [list]
	set n        [reqGetNumVals]
	for {set i 0} {$i < $n} {incr i} {

		set name [reqGetNthName $i]

		if {$name eq "action"} {
			continue
		}

		set value [reqGetNthVal $i]

		if {$value eq ""} {
			continue
		}

		lappend log_args [list $name $value]
	}

	set br {---------------------------------------------------------------------------------------}
	core::log::write INFO {$br}
	core::log::write INFO {[format "| %-20s | %-60s |" action "$action -> $handler"]}
	core::log::write INFO {$br}

	if {[llength $log_args] > 0} {
		foreach input [lsort -index 0 $log_args] {
			lassign $input n v
			core::log::write INFO {[format "| %-20s | %-60s |" $n $v]}
		}
		core::log::write INFO {$br}
	}
}

# Wrap the appserver commands
proc core::request::_create_wrapper_procs args {

	proc ::reqGetArg args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetArg called with args: $args}

		# If the action has not be registered then we should just
		# use the original reqGetArg
		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetArg) {*}$args]
		}

		# We need to go through the args to get the name.
		foreach arg $args {
			switch -- $arg {
				-unsafe -
				-safe {
					# These arguments aren't relevant anymore.
				}
				default {
					set name $arg
					break
				}
			}
		}

		if {![info exists name]} {
			# No name was passed in. How odd.
			error "Usage: reqGetArg <name>"
		}

		return [::core::request::get -name $name -type arg]
	}

	proc ::reqSetArg args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqSetArg called with args $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqSetArg) {*}$args]
		}

		return [::core::request::set_arg \
			-name  [lindex $args end-1] \
			-value [lindex $args end]]
	}

	proc ::reqGetArgs args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetArgs called with args: $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetArgs) {*}$args]
		}

		return [::core::request::get -type args -name [lindex $args end]]
	}

	proc ::reqGetNumVals args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetNumVals called with}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetNumVals)]
		}

		return [core::request::get_num_vals]
	}

	proc ::reqGetNthName args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetNthName called with args: $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetNthName) {*}$args]
		}

		return [core::request::get_nth_name -n {*}$args]
	}

	proc ::reqGetNthVal args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetNthVal called with args: $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetNthVal) {*}$args]
		}

		return [core::request::get_nth_value -n {*}$args]
	}

	proc ::reqGetEnv {env} {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetEnv called with args: $env}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetEnv) $env]
		}

		return [core::request::get -name $env -type header]
	}

	proc ::reqSetEnv {name value} {
		core::log::write DEV {REQUEST: reqSetEnv called with args: name='$name' value='$value'}
		return [::core::request::set_arg -type header -name $name -value $value]
	}

	proc ::reqGetEnvNames args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetEnvNames called with args: $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetEnvNames)]
		}

		return [::core::request::get_env_names]
	}

	# reqGetNthArg ?-safe|-unsafe? ?-meta? name n
	proc ::reqGetNthArg args {
		variable ::core::request::PROCS

		core::log::write DEV {REQUEST: reqGetNthArg called with args: $args}

		if {![core::controller::is_action_registered -action [core::request::get_action]]} {
			return [$PROCS(reqGetNthArg) {*}$args]
		}

		set name     [lindex $args end-1]
		set position [lindex $args end]
		return       [::core::request::get_nth_arg \
			-name $name \
			-n    $position]
	}
}
