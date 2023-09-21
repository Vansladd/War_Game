# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Arguments API
#
# Collate information about inputs to a procedure for automatic verification of data
#
# Synopsis:
#    package require core::args ?1.1?
#

set pkg_version 1.3
package provide core::args $pkg_version


# Dependencies
#
package require core::check 1.0

namespace eval core::args {

	variable CFG
	variable NS
	variable ARGS

	set CFG(init)         0
	set CFG(dynamic_args) 0

	if {[catch {
		set CFG(otcommand_version) [package present ot_command]
	} msg]} {
		set CFG(otcommand_version) 0
	}

	# This allows checks such as ENUM to be defined and have
	# the static args set at registration time
	if {[package vsatisfies $CFG(otcommand_version) 1.1]} {
		set CFG(dynamic_args) 1
	}
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

proc core::args::init args {

	variable CFG
	variable NS
	variable ARGS

	if {$CFG(init)} {
		return
	}

	# Initialise depdendencies
	core::check::init

	array unset NS
	array unset ARGS

	set NS(all) [list]
	set NS(pub) [list]

	incr CFG(init)
}



#----------------------------------------------------------------------------
# Registration
#----------------------------------------------------------------------------

proc core::args::register_ns { args } {

	variable NS

	array set my_args [core::args::check core::args::register_ns {*}$args]

	set ns $my_args(-namespace)

	if {[lsearch $NS(all) $ns] == -1} {
		lappend NS(all) $ns
	}
	if {$my_args(-is_public) && [lsearch $NS(pub) $ns] == -1} {
		lappend NS(pub) $ns
	}

	set NS($ns,name)        $ns
	set NS($ns,desc)        $my_args(-desc)
	set NS($ns,version)     $my_args(-version)
	set NS($ns,dependent)   $my_args(-dependent)
	set NS($ns,docs)        $my_args(-docs)
	set NS($ns,procs_all)   [list]
	set NS($ns,procs_pub)   [list]
	set NS($ns,procs_short) [list]
	set NS($ns,interfaces)  [list]

	return 1
}

#
# Test whether a proc or interface is registered with core::args.
# @param proc_name : the fully qualified name of the proc to test.
# @return          : 1 if registered, 0 otherwise.
#
proc core::args::is_registered { proc_name } {
	variable NS

	set ns [namespace qualifiers $proc_name]
	set proc_name_short [namespace tail $proc_name]

	#namespace not registered
	if {![info exists NS($ns,name)]} {
		return 0
	}

	#registered
	if {[lsearch $NS($ns,procs_short) $proc_name_short] != -1 } {
		return 1
	}

	return 0
}

# Register a procedure, define an interface or implement an interface
proc core::args::register { args } {

	variable CFG
	variable NS
	variable ARGS
	variable INTERFACE

	array set my_args [core::args::check core::args::register {*}$args]

	set p          $my_args(-proc_name)
	set body       $my_args(-body)
	set interface  $my_args(-interface)
	set implements $my_args(-implements)
	set clones     $my_args(-clones)
	set mand_impl  $my_args(-mand_impl)
	set allow_rpc  $my_args(-allow_rpc)
	set errors     $my_args(-errors)
	set error_data $my_args(-error_data)
	set dynatrace  $my_args(-dynatrace)

	# returns is populate in the input check
	set returns {}
	set is_return_data_type 0

	# input check --- Start
	# We need to be defining a proc or an interface
	if {$p == {}} {
		if {$interface == {}} {
			error "Must either define a proc or an interface" \
				{} MISSING_PROC
		}

		if {$implements != {} || $clones != {}} {
			error "Must define a procedure name when implementing or cloning an interface" \
				{} MISSING_NAME
		}

		set p $interface
	}

	if {[info exists my_args(-returns)] == 1 && [info exists my_args(-return_data)] == 1 && $my_args(-returns) != {} && $my_args(-return_data) != {}} {
		error "Must define only returns or return_data" \
			{} DOUBLE_RETURNS_DEFINITION
	} else {
		# returns type is defined as default
		if {[info exists my_args(-return_data)] == 1 && $my_args(-return_data) != {}} {
			set is_return_data_type 1
			set returns $my_args(-return_data)
		} else {
			if {[info exists my_args(-returns)]} {
				set returns $my_args(-returns)
			} else {
				set returns {}
			}

		}
	}

	# Handle dynatrace invocation
	set dt_enter          {}
	set dt_exit_exception {}
	set dt_exit           {}

	if {$dynatrace} {
		package require core::dynatrace
		::core::dynatrace::init

		if {[core::dynatrace::is_available]} {
			set dt_enter          {set dt_serial [core::dynatrace::enter -args $args]}
			set dt_exit_exception {core::dynatrace::exit_exception -msg $msg -serial_no $dt_serial}
			set dt_exit           {core::dynatrace::exit -result $result -serial_no $dt_serial }
		}
	}

	set ns [namespace qualifiers $p]

	if {![info exists NS($ns,name)]} {
		error \
			"ARGS: ERROR cannot find namespace $ns. Ignoring procedure." \
			{} INVALID_NS
	}

	if {[lsearch $NS($ns,procs_all) $p] == -1} {
		lappend NS($ns,procs_all)    $p
		lappend NS($ns,procs_short)  [namespace tail $p]
	}

	if {$interface != {}} {
		if {[lsearch $NS($ns,interfaces) $p] == -1} {
			lappend NS($ns,interfaces) $p
		}
	}

	if {$my_args(-is_public) && [lsearch $NS($ns,procs_pub) $p] == -1} {
		lappend NS($ns,procs_pub) $p
	} elseif {$allow_rpc} {
		error "ARGS: ERROR cannot allow RPC on private procs" {} RPC_NOT_ALLOWED
	}

	# we need this variable to register the return list in the appserv, in theory it could be wrap in a if depends on is_return_data_type
	set return_proc_name [_get_return_procedure_name $p]
	# input check --- END
	set define_errors [list]

	set code {}
	set desc {}
	set args {}

	if { $errors != {} } {
		set define_errors $errors
	} else {
		if { $error_data != {}} {
			foreach error_entry $error_data {
				array set my_largs [ot::command::check_args core::args::register_error {*}$error_entry]
				set code $my_largs(-code)
				set desc $my_largs(-desc)
				lappend define_errors $code

				set ARGS($ns,$p,errors,$code,desc)      $desc
			}
			if {$is_return_data_type && $returns != {}} {
				set error_proc_name [_get_error_procedure_name $p]
				set ARGS($ns,$error_proc_name,args)          [list]
				set ARGS($ns,$error_proc_name,optional_args) [list]

				set args $returns
				# default error arguments.
				lappend args [list -arg -errorcode -mand 0 -check STRING ]
				lappend args [list -arg -code      -mand 0 -check STRING ]
				lappend args [list -arg -level     -mand 0 -check STRING ]
				lappend args [list -arg -errorinfo -mand 0 -check STRING ]
				lappend args [list -arg -errorline -mand 0 -check STRING ]

				_register_params $args $ns $error_proc_name

			}
		}
	}

	#Defining procedure in the ARGS arrays
	set ARGS($ns,$p,interface)           $interface
	set ARGS($ns,$p,implements)          $implements
	set ARGS($ns,$p,allow_rpc)           $allow_rpc
	set ARGS($ns,$p,clones)              $clones
	set ARGS($ns,$p,name)                $p
	set ARGS($ns,$p,desc)                $my_args(-desc)
	set ARGS($ns,$p,is_return_data_type) $is_return_data_type
	set ARGS($ns,$p,errors,codes)        $define_errors
	set ARGS($ns,$p,args)                [list]
	set ARGS($ns,$p,optional_args)       [list]

	# Register the procedure with all the parameters in the appserv
	_register_params $my_args(-args) $ns $p

	if {$is_return_data_type} {
		#Mirroring args, register the params to the appserv with the return_proc_name
		set ARGS($ns,$return_proc_name,args)          [list]
		set ARGS($ns,$return_proc_name,optional_args) [list]

		_register_params $returns $ns $return_proc_name

		#update the concrete procedure with the returns args expected.
		set ARGS($ns,$p,returns)          $ARGS($ns,$return_proc_name,args)
		# Not sure about the role of option as it is not in used by args.
		set ARGS($ns,$p,optional_returns) $ARGS($ns,$return_proc_name,optional_args)
	} else {
		set ARGS($ns,$p,returns) $returns
	}

	# Define code to run dynamically when the proc is called.
	# Build an interface
	if {$interface != {}} {

		# Build RPC definition
		if {$allow_rpc &&
			[llength [info commands "::core::api::core_rpc::*"]] &&
			[core::api::core_rpc::get_config -name enabled -default 0]} {

			set rpc_def [subst -nocommands {

				# RPC available
				set ret [core::api::core_rpc::make_request \
					-proc_name $interface \
					-id        [clock milliseconds] \
					-arg_list  \$args]
			}]
		} else {
			set rpc_def {
				# RPC unavailable use local method invocation
				set ret [$proc_name {*}$args]
			}
		}

		# setting the allowed error code list to the interface, it will be check at runtime.
		set INTERFACE($interface,errors) $errors

		# Create a proc that checks for concrete implementations
		# Make sure the difference between the two sets of args contains
		# no mandatory args
		proc ::$p args [subst {

			# Add Dynatrace entry point
			$dt_enter

			# Execute initialisation body
			$body

			#validating... remove unsupported args defined in the implementation
			set ret \[core::args::_validate_implementation \
				$interface \
				$mand_impl \
				{*}\$args\]

			set proc_name \[lindex \$ret 0\]
			set args      \[lindex \$ret 1\]

			# If we have a valid implementation call it with the set of valid
			# arguments
			if {\$proc_name != {}} {
				if {\[catch {
					$rpc_def
				} msg options \]} {
					set _error_list \[core::args::_return_implementation_errors $interface \]

					# Add Dynatrace exit_exception
					$dt_exit_exception

					# If there are no error definitions for this proc or the error matches one of the defined errors then just re-throw the error.
					# Otherwise, throw an INVALID_ERROR
					if {\[llength \$_error_list\] == 0 || \$::errorCode in \$_error_list} {
						return -code error \
							-options \[core::args::_validate_option_error $p \$options\] \
							\$msg
					} else {
						core::log::write ERROR {\$::errorCode not expected -> msg: \$msg}
						core::log::write_error_info ERROR
						dict set options {-errorcode} INVALID_ERROR
						return -code error \
							-options \[core::args::_validate_option_error $p \$options\] \
							"Invalid errorCode \$::errorCode"

					}
				}
				set result \$ret

				# check the return value if declared.
				if {[llength $ARGS($ns,$p,returns)] !=0} {
					# Validate the return data, expand and return
					set ret \[core::args::_validate_return \
						$interface \
						\[list $returns\] \
						\$ret\]

					if {$is_return_data_type} {
						#validating... remove unsupported return value defined in the implementation
						set ret \[core::args::_validate_implementation \
							$return_proc_name \
							$mand_impl \
							{*}\$ret\]

						set proc_name \[lindex \$ret 0\]
						set result    \[lindex \$ret 1\]
					}
				}

				# Add Dynatrace exit point
				$dt_exit

				return \$result
			}
		}]
	} elseif {$clones != {}} {
		# interface cloned procedure definition
		if {$body == {}} {
			error "Must define a body when cloning an interface" \
				{} MISSING_BODY
		}

		# Validate the clone against the interface as its registered,  the return is also validate but only if the returns_date is populated.
		_validate_interface $clones $p $my_args(-args) $returns $errors 0

		# We need to validate that the return data from the cloned proc
		# is valid. We therefore need to call the new clone and validate
		# the return
		set clone_proc [format "%s.%s" $p [OT_MicroTime]]

		# Create the internal cloned proc that is called by the newly defined proc
		proc ::$clone_proc args [subst {
			array set ARGS \[core::args::check $p {*}\$args\]
			$body
		}]

		# Defined the external publicly accessible clone
		proc ::$p args [subst {
			array set ARGS \[core::args::check $p {*}\$args\]

			# Add Dynatrace entry point
			$dt_enter

			if {\[catch {set result \[$clone_proc {*}\$args\]} msg options \]} {

				# Add Dynatrace exit_exception
				$dt_exit_exception

				#if there are not errors code defined so throw the error, otherwise in order to throw the code need to be in the list defined in the interface
				if {[llength $errors] == 0 || \$::errorCode in \"$errors\"} {
					return -code error \
						-options \[core::args::_validate_option_error $clones \$options\] \
						\$msg
				} else {
					core::log::write ERROR {\$::errorCode not expected -> msg: \$msg}
					core::log::write_error_info ERROR
					dict set options {-errorcode} INVALID_ERROR
					return -code error \
						-options \[core::args::_validate_option_error $clones \$options\] \
						"Invalid errorCode \$::errorCode"
				}
			}
			if {[llength $ARGS($ns,$p,returns)] !=0} {
				# Validate the return data, expand and return
				set result \[core::args::_validate_return \
					$clones \
					\[list $returns\] \
					\$result\]
			}

			# Add Dynatrace exit point
			$dt_exit

			return \$result
		}]
	} elseif {$implements != {}} {
		# Validate the concrete implementation against the interface
		_validate_interface $implements $p $my_args(-args) $returns $errors 1
		# If there are no arguments then we shouldn't do a check
		set check_def {}
		if {[llength $ARGS($ns,$p,args)]} {
			set check_def "array set ARGS \[core::args::check $p {*}\$args\]"
		}

		# Build and define proc, this will be called by the interface procedure definition.
		if {$body != {}} {
			proc ::$p args [format "\n\t\t%s\n%s" $check_def $body]
		}
	} else {

		if {$body != {}} {
			# defining an internal procedure to check errors and return data
			set internal_proc [format "%s.%s" $p [OT_MicroTime]]

			# If there are no arguments then we shouldn't do a check
			proc ::$internal_proc args [subst {
				# work with previous stack frame, or the code with uplevel in the body will not work, using the external wrapper as level
				uplevel 1 {
					$body
				}
			}]
			# Defined the external publicly that wrap the internal one and verify errors and return data.
			proc ::$p args [subst {
				if {[llength $ARGS($ns,$p,args)] > 0} {
					array set ARGS \[core::args::check $p {*}\$args\]
				}

				# Add Dynatrace entry point
				$dt_enter

				if {\[catch { set result \[$internal_proc {*}\$args \] } msg options \]} {

					# Add Dynatrace exit_exception
					$dt_exit_exception

					#if there are not errors code defined so throw the error, otherwise in order to throw the code need to be in the list defined in the interface
					if {[llength $errors] == 0 || \$::errorCode in \"$errors\"} {
						return -code error \
							-options \[core::args::_validate_option_error $p \$options\] \
							\$msg
					} else {
						core::log::write ERROR {\$::errorCode not expected -> msg: \$msg}
						core::log::write_error_info ERROR
						dict set options {-errorcode} INVALID_ERROR
						return -code error \
        						-options \[core::args::_validate_option_error $p \$options\] \
        						"Invalid errorCode \$::errorCode"
					}
				}
				# validate the return only if using return_data, in the case is using returns it is just a description
				if {$ARGS($ns,$p,is_return_data_type)} {
					set result \[core::args::_validate_return $p {} \$result]
				}

				# Add Dynatrace exit point
				$dt_exit

				return \$result
			}]
		}
	}

}

# We need a return procedure name because i have registered the validation on ot_command against this name, as the proc_name is dedicated for args validation
proc core::args::_get_return_procedure_name procedure {
	return ${procedure}_return
}

proc core::args::_get_error_procedure_name {procedure} {
	return "${procedure}_error"
}

# register a procedure to the appserv
proc core::args::_register_params {arguments nspace procedure} {
	variable ARGS
	variable CFG

	set cmd_lists [list]

	foreach larg $arguments {

		array set my_largs [ot::command::check_args core::args::register_arg {*}$larg]

		set arg         $my_largs(-arg)
		set mand        $my_largs(-mand)
		set check       $my_largs(-check)
		set check_args  [lrange $check 1 end]
		set default_cfg $my_largs(-default_cfg)
		set default     $my_largs(-default)
		set desc        $my_largs(-desc)

		if {[lsearch $ARGS($nspace,$procedure,args) $arg] == -1} {
			lappend ARGS($nspace,$procedure,args) $arg

			if {!$mand} {
				lappend ARGS($nspace,$procedure,optional_args) $arg
			}
		}

		set ARGS($nspace,$procedure,$arg,mand)        $mand
		set ARGS($nspace,$procedure,$arg,check)       $check
		set ARGS($nspace,$procedure,$arg,check_args)  $check_args
		set ARGS($nspace,$procedure,$arg,default_cfg) $default_cfg
		set ARGS($nspace,$procedure,$arg,default)     $default
		set ARGS($nspace,$procedure,$arg,desc)        $desc
		set ARGS($nspace,$procedure,$arg,is_public)   $my_largs(-is_public)

		# Check the first argument of check. Subsequent arguments
		# should be passed with the validate command
		set ret [core::check::command_for_type [lindex $check 0]]
		if {[lindex $ret 0] != 1 || [llength $ret] < 2} {
			core::log::write ERROR {ARGS: ERROR cannot find data type [lindex $check 0]. Ignoring argument.}
			continue
		}

		set validate_command [lindex $ret 1]
		set static_args      [lindex $ret 2]

		# Check that we aren't registering a mandatory argument with a default
		if {$mand && $default != {}} {
			error \
				"Specifying $p $arg with a mandatory argument with a default ($default) is not allowed" \
				{} INVALID_ARGS
		}

		# TODO combine this logic with the code in check.tcl
		if {[llength $static_args] && ([llength $static_args] > 1 || $static_args != "")} {
			if {$CFG(dynamic_args)} {
				set lst [list $arg $mand [list $validate_command $static_args {*}$check_args]]
			} else {
				#core::log::write WARNING {WARNING: Dynamic args unavailable replacing $validate_command with core::check::ascii}
				set lst [list $arg $mand core::check::ascii]
			}
		} else {
			set lst [list $arg $mand $validate_command]
		}

		if {$default_cfg == ""} {
			lappend lst $default
		} elseif {$default_cfg != ""} {
			lappend lst [OT_CfgGet $default_cfg $default]
		}

		lappend cmd_lists $lst
	}

	ot::command::register_params $procedure {*}$cmd_lists
}

# Return whether there is an implementation for the interface
proc core::args::is_implemented args {
	variable INTERFACE

	array set my_args [core::args::check core::args::is_implemented {*}$args]

	if {[info exists INTERFACE($my_args(-interface),proc_name)]} {
		return 1
	}

	return 0
}

# Return whether there rpc is allowed
proc core::args::is_rpc_allowed args {
	variable ARGS

	array set my_args [core::args::check core::args::is_rpc_allowed {*}$args]

	set proc_name $my_args(-proc_name)

	set ns [namespace qualifiers $proc_name]

	if {[info exists ARGS($ns,$proc_name,allow_rpc)] && $ARGS($ns,$proc_name,allow_rpc)} {
		return 1
	}

	return 0
}

# Validate an implementation/clone against the interface
proc core::args::_validate_interface {interface proc_name proc_args proc_returns proc_errors {define_interface 0}} {
	variable INTERFACE

	set return_interface_name [_get_return_procedure_name $interface]
	set ret_args [_validate_interface_io $interface $proc_name $proc_args]

	# check if the interface is define the same return type.
	set interface_is_return_data_type [_is_return_data_type $interface]
	set proc_is_return_data_type [_is_return_data_type $proc_name]

	if {$proc_is_return_data_type != $interface_is_return_data_type} {
		error \
		"Proc $proc_name does not meet the interface $interface - Different definition return type" \
		{} \
		INVALID_ARGS
	}

	# Chcek if interface errors match proc errors definition
	set errors $INTERFACE($interface,errors)
	if {[llength $INTERFACE($interface,errors)] == 0} {
		# Override with proc error list if haven't defined on interface
		set errors $proc_errors
	} elseif {[llength $proc_errors] != 0} {
		# Check if proc errors is a sub-list of interface errors
		foreach errorcode $proc_errors {
			if {$errorcode ni $INTERFACE($interface,errors)} {
				error \
				"Proc $proc_name does not meet the interface $interface - Uknown errorCode $errorcode" \
				{} \
				INVALID_ARGS
			}
		}
	}

	# if the returns is a list, we also need to validate the returns (list) against the interface definition
	if {$interface_is_return_data_type} {
		# the return is validated against the interface only if the return check is with the list definition.
		set return_proc_name [_get_return_procedure_name $proc_name]
		set ret_return [_validate_interface_io $return_interface_name $return_proc_name $proc_returns]
	}

	if {$define_interface} {
		set INTERFACE($interface,proc_name)            [lindex $ret_args 0]
		set INTERFACE($interface,unsupported_opt_args) [lindex $ret_args 1]
		set INTERFACE($interface,errors)               $errors

		if {$interface_is_return_data_type} {
			set INTERFACE($return_interface_name,proc_name)            [lindex $ret_return 0]
			set INTERFACE($return_interface_name,unsupported_opt_args) [lindex $ret_return 1]
			set INTERFACE($return_interface_name,errors)               $errors
		}
	}
}

# validate the input/output of the interface
proc core::args::_validate_interface_io {interface proc_name proc_args} {
	variable INTERFACE

	core::log::write DEBUG {Validating $proc_name against interface $interface}

	# Check interface exists
	if {[catch {set interface_list [core::args::get_arg_list $interface]} err]} {
		core::log::write ERROR {Interface $interface does not exist: $err}
		error \
			"Interface $interface does not exist: $err" \
			$::errorInfo \
			INVALID_INTERFACE
	}

	# Make sure the difference between the two sets of args contains
	# no mandatory args. The optional args that aren't supported will be removed
	# when the implementation is invoked
	array set PROC_ARGS      [list]
	array set INTERFACE_ARGS [list]

	set unsupported_opt_args [list]

	foreach arg $proc_args {
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
			error \
				"Proc $proc_name does not meet the interface $interface - unknown required arg $arg" \
				{} \
				INVALID_ARGS
		}
	}

	foreach {arg required} [array get INTERFACE_ARGS] {
		if {$required} {
			core::log::write ERROR {Proc $proc_name does not meet the interface $interface - missing arg $arg}
			error \
				"Proc $proc_name does not meet the interface $interface - missing arg $arg" \
				{} \
				INVALID_ARGS
		} else {
			if {![info exists PROC_ARGS($arg)]} {
				lappend unsupported_opt_args $arg
			}
		}
	}

	return [list $proc_name [_luniq $unsupported_opt_args]]
}

# return at runtime the errors list defined in the interface implementation during the registration.
proc core::args::_return_implementation_errors interface {
	variable INTERFACE
	return  $INTERFACE($interface,errors)
}

# Validate that a cloned proc adheres to interface definition again input/output
proc core::args::_validate_implementation {interface mand_impl args} {

	variable INTERFACE

	set interface_args $args

	if {[info exists INTERFACE($interface,proc_name)]} {

		set proc_name   $INTERFACE($interface,proc_name)
		set unsupported $INTERFACE($interface,unsupported_opt_args)

		if {[catch {set impl_args [core::args::get_arg_list $proc_name]} err]} {
			core::log::write ERROR {$proc_name not registered? $err}
			error \
				"$proc_name not registered? $err" \
				$::errorInfo \
				INVALID_PROC
		}

		# Remove unsupported optional arguments
		set supported_args $interface_args
		foreach arg $unsupported {
			if {[dict exists $interface_args $arg]} {
				set supported_args [dict remove $supported_args $arg]
			}
		}

		return [list $proc_name $supported_args]
	} else {
		# If it is mandatory to have an implementation throw an error
		if {$mand_impl} {
			core::log::write ERROR {core::args Interface $interface has no implementation}
			error \
				"core::args Interface $interface has no implementation" \
				{} \
				NO_IMPLEMENTATION
		}
	}

	return {}
}

# Validate return value against the definition
# If you are in the case that are validating an implementation,
# the unsupported element defined during the registration in validate_interface will be removed after this proc
# type is not used if the return_data is specified in the proc registration, used only if returns.
proc core::args::_validate_return {procedure type arguments} {

	if {[_is_return_data_type $procedure]} {
		set return_proc_name [_get_return_procedure_name $procedure]
		if {[catch {
			set arguments [core::args::check $return_proc_name {*}$arguments]
		} err]} {
			core::log::write ERROR {Invalid return value for $procedure :$err}

			error \
				"Invalid return value for $procedure: $err" \
				$::errorInfo \
				INVALID_RETURN
		}
	} else {
		if {$type == {}} {
			return $arguments
		}

		if {[catch {
			set valid [core::check::check_value $arguments {AND} [list $type]]
		} err]} {
			core::log::write ERROR {Unable to validate return value for $procedure: $err}

			error \
				"Unable to validate return value for $procedure: $err" \
				$::errorInfo \
				INVALID_RETURN
		}

		if {!$valid} {
			core::log::write ERROR {Invalid return value for $procedure: expected $type}

			error \
				"Invalid return value for $procedure: expected $type" \
				{} \
				INVALID_RETURN
		}
	}

	return $arguments
}

proc core::args::_validate_option_error {procedure arguments} {
	variable ARGS

	set proc_name [_get_error_procedure_name $procedure]
	if {[info exist ARGS([namespace qualifiers $proc_name],$proc_name,args)]} {

		if {[catch {
			set arguments [core::args::check $proc_name {*}$arguments]
		} msg]} {
			dict set arguments {-errorcode} $::errorCode
		}
	}

	return $arguments
}

#----------------------------------------------------------------------------
# Validation proceedures
#----------------------------------------------------------------------------

proc core::args::check { args } {

	if {[catch {set lst [ot::command::check_args {*}$args]} msg]} {
		if {[info exists ::core::log::CFG(init)] && $::core::log::CFG(init)} {
			core::log::write ERROR {ARGS: Error checking $args arguments. $msg}
			core::log::write_stack DEV
		} else {
			puts stderr "ARGS: Error checking arguments $args $msg"
		}

		error "Error checking [lindex $args 0] $msg" $::errorInfo INVALID_ARGS
	}

	return $lst
}

#----------------------------------------------------------------------------
# Usage information
#----------------------------------------------------------------------------

# Produce usage information based on the proc name
proc core::args::proc_usage_info {ns proc} {

	variable ARGS

	set ret "USAGE:\n\n"

	if {![info exists ARGS($ns,$proc,args)]} {
		return "Unknown key $ns,$proc"
	}

	# Establish the longest args
	set arg_length 8
	foreach arg $ARGS($ns,$proc,args) {
		if {[string length $arg] > $arg_length} {
			set arg_length [expr {[string length $arg] + 2}]
		}
	}

	foreach arg $ARGS($ns,$proc,args) {
		append ret [format "\t%-2s%-${arg_length}s %s\n" \
			[expr {!$ARGS($ns,$proc,$arg,mand) ? {?} : {}}] \
			$arg \
			$ARGS($ns,$proc,$arg,desc)]
	}

	return $ret
}

proc core::args::get_ns args {

	variable ARGS
	variable NS

	return $NS(pub)
}

proc core::args::dump_ns {{pattern *}} {

	variable NS

	return [array get NS $pattern]
}

proc core::args::dump {{pattern *}} {

	variable ARGS

	return [array get ARGS $pattern]
}

# Retrieve a namespace object
proc core::args::get_ns_object {ns key {default {}}} {
	variable NS

	if {[info exists NS($ns,$key)]} {
		return $NS($ns,$key)
	}

	return $default
}

# Retrieve a proc object
proc core::args::get_proc_object {proc_name key {default {}}} {
	variable ARGS

	set ns [namespace qualifiers $proc_name]

	if {[info exists ARGS($ns,$proc_name,$key)]} {
		return $ARGS($ns,$proc_name,$key)
	}

	return $default
}

# Dump the argument list of a proc as defined by core::args
proc core::args::get_arg_list {proc_name} {

	variable ARGS

	set ns [namespace qualifiers $proc_name]
	set key "$ns,$proc_name"

	set args_list [list]

	foreach arg $ARGS($key,args) {
		set arg_list [list]
		lappend arg_list \
			-arg         $arg \
			-mand        $ARGS($key,$arg,mand) \
			-check       $ARGS($key,$arg,check)

		if {!$ARGS($key,$arg,mand)} {
			lappend arg_list \
				-default_cfg $ARGS($key,$arg,default_cfg) \
				-default     $ARGS($key,$arg,default)
		}

		lappend arg_list \
			-desc $ARGS($key,$arg,desc)

		lappend args_list $arg_list
	}

	return $args_list
}

# Return the is_return_data_type defined for the procedure name in input, registered in the registration.
proc core::args::_is_return_data_type {proc_name} {

	variable ARGS

	set ns [namespace qualifiers $proc_name]

	return $ARGS($ns,$proc_name,is_return_data_type)
}

# Removes duplicates without sorting the input list.
# Returns a new list.
#
# @paran l List that might contain duplicates.
#
# @return r List that has the elements of the original list minus any duplicates.
#
proc core::args::_luniq {l} {

	set r {}

	foreach i $l {
		if {[lsearch -exact $r $i] == -1} {
			lappend r $i
		}
	}

	return $r
}

# Self-initialise
core::args::init

# Unlike other packages, we need to use the ot::command::* API directly to
# bootstrap the procedures.
#
ot::command::register_params \
	core::args::register_ns \
		[list -namespace 1 core::check::ascii     {}] \
		[list -desc      0 core::check::ascii     {}] \
		[list -version   0 core::check::ascii     {}] \
		[list -dependent 0 core::check::ascii     {}] \
		[list -docs      0 core::check::is_string {}] \
		[list -is_public 0 core::check::bool      1]

ot::command::register_params \
	core::args::register \
		[list -proc_name  0 core::check::ascii {}] \
		[list -interface  0 core::check::ascii {}] \
		[list -implements 0 core::check::ascii {}] \
		[list -clones     0 core::check::ascii {}] \
		[list -mand_impl  0 core::check::bool  {}] \
		[list -desc       0 core::check::any   {}] \
		[list -body       0 core::check::any   {}] \
		[list -returns    0 core::check::ascii {}] \
		[list -args       0 core::check::ascii {}] \
		[list -is_public  0 core::check::bool  1] \
		[list -allow_rpc  0 core::check::bool  0] \
		[list -errors     0 core::check::ascii {}] \
		[list -dynatrace  0 core::check::bool  0] \
		[list -error_data 0 core::check::ascii {}] \

ot::command::register_params \
	core::args::register_arg \
		[list -arg          1 core::check::ascii  {}] \
		[list -mand         0 core::check::bool   0]  \
		[list -check        1 core::check::ascii  {}] \
		[list -default_cfg  0 core::check::ascii  {}] \
		[list -default      0 core::check::any    {}] \
		[list -desc         0 core::check::any    {}] \
		[list -is_public    0 core::check::bool   1]

ot::command::register_params \
		core::args::register_error \
			[list -code 0 core::check::any   {}] \
			[list -desc 0 core::check::any   {}] \

ot::command::register_params \
	core::args::is_implemented \
		[list -interface    1 core::check::ascii  {}]

ot::command::register_params \
	core::args::is_registered \
		[list -proc_name    1 core::check::ascii  {}]

ot::command::register_params \
	core::args::is_rpc_allowed \
		[list -proc_name    1 core::check::ascii  {}]


# Now call the procedures themselves to make sure this package has details of
# its own API, including all of the relevant descriptions, examples and
# dependencies.
#
core::args::register_ns \
	-namespace core::args \
	-desc      {Validated argument checking procedures} \
	-version   $pkg_version \
	-dependent [list core::log] \
	-docs      foundation/args.xml

core::args::register \
	-proc_name core::args::register_ns \
	-desc      {Define the namespace that procedures will be registered} \
	-returns   {BOOL} \
	-args      [list \
		[list -arg -namespace -mand 1 -check ASCII             -desc {Name of the namespace}] \
		[list -arg -desc      -mand 0 -check ANY   -default {} -desc {Description of the namespace}] \
		[list -arg -version   -mand 0 -check ASCII -default {} -desc {Version number of the namespace}] \
		[list -arg -dependent -mand 0 -check ASCII -default {} -desc {Other packages on which this package is dependent}] \
		[list -arg -docs      -mand 0 -check ASCII -default {} -desc {XML documentation file relative to core or absolute path}] \
		[list -arg -is_public -mand 0 -check BOOL  -default 1  -desc {Is this namespace publicly available?}] \
	]

core::args::register \
	-proc_name core::args::register \
	-desc      {Proc registration} \
	-returns   {NONE} \
	-args      [list \
		[list -arg -proc_name   -mand 0 -check ASCII             -desc {Name of the procedure}] \
		[list -arg -interface   -mand 0 -check ASCII -default {} -desc {Name of the Interface to define}] \
		[list -arg -implements  -mand 0 -check ASCII -default {} -desc {Name of the Interface the proc implements (must be a registered interface)}] \
		[list -arg -clones      -mand 0 -check ASCII -default {} -desc {Name of the Interface the proc clones (must be a registered interface)}] \
		[list -arg -mand_impl   -mand 0 -check BOOL  -default 1  -desc {Is it mandatory to have an implementation for the interface}] \
		[list -arg -desc        -mand 0 -check ANY   -default {} -desc {Description of the procedure}] \
		[list -arg -body        -mand 0 -check ANY   -default {} -desc {Proc body allowing proc to be registered and defined with one command}] \
		[list -arg -return_data -mand 0 -check ANY   -default {} -desc {List of lists containing details of all of the return arguments to this procedure. Each argument is a list of 6 elements; argument name, mandatory flag, data type, default config, default value, description}] \
		[list -arg -returns     -mand 0 -check ASCII -default {} -desc {Description of what the procedure returns}] \
		[list -arg -args        -mand 0 -check ANY   -default {} -desc {List of lists containing details of all of the arguments to this procedure. Each argument is a list of 6 elements; argument name, mandatory flag, data type, default config, default value, description}] \
		[list -arg -is_public   -mand 0 -check BOOL  -default 1  -desc {Is this procedure publicly available?}] \
		[list -arg -allow_rpc   -mand 0 -check BOOL  -default 0  -desc {Can this procedure utilise RPC}] \
		[list -arg -errors      -mand 0 -check ANY   -default {} -desc {list of potential error that the interface could raise.}] \
		[list -arg -error_data  -mand 0 -check ANY   -default {} -desc {List of lists containing details of all potential error that the interface could raise.}] \
		[list -arg -dynatrace   -mand 0 -check BOOL  -default 0  -desc {Add dynatrace binding}] \
	]

core::args::register \
	-proc_name core::args::check \
	-desc      {Invoke ot::command validation} \
	-returns   {}

core::args::register \
	-proc_name core::args::is_implemented \
	-desc      {Return whether an interface has an implementation} \
	-returns   {BOOL} \
	-args      [list \
		[list -arg -interface -mand 1 -check ASCII -desc {Name of the Interface to check}] \
	]

core::args::register \
	-proc_name core::args::is_registered \
	-desc      {Return whether a procedure or an interface is registered with core::args} \
	-returns   {BOOL} \
	-args      [list \
		[list -arg -proc_name -mand 1 -check ASCII -desc {Fully qualified proc name}] \
	]

core::args::register \
	-proc_name core::args::is_rpc_allowed \
	-desc      {Return whether a procedure is allowed to be invoked over RPC} \
	-returns   {BOOL} \
	-args      [list \
		[list -arg -proc_name -mand 1 -check ASCII -desc {Fully qualified proc name}] \
	]
