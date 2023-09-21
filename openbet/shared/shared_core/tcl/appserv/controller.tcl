# (C) 2011 Orbis Technology Ltd. All rights reserved.
#
# Request Security Model
#

set pkg_version 1.0
package provide core::controller $pkg_version


# Dependencies
#
package require core::gc      1.0
package require core::log     1.0
package require core::check   1.0
package require core::args    1.0
package require core::random  1.0
package require core::view    1.0
package require core::request 1.0

core::args::register_ns \
	-namespace core::controller \
	-version   $pkg_version \
	-dependent [list core::args core::request core::check core::log core::gc] \
	-docs      xml/appserv/controller.xml

namespace eval core::controller {

	variable CFG
	variable REQUEST
	variable REQ_ACTION
	variable SET_ACTION
	variable ERRORS

	variable PROCS
	variable REQ_TYPE_MATRIX

	variable ACTIONS
	set ACTIONS(actions) [list]

	variable PRE_HANDLERS
	set PRE_HANDLERS(handlers) [list]
	set PRE_HANDLERS(system)   [list]

	variable POST_HANDLERS
	set POST_HANDLERS(handlers) [list]

	set CFG(init) 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::controller::init \
	-args      [list \
		[list -arg -strict_mode            -mand 1 -check BOOL                         -desc {Enable Strict Mode.}] \
		[list -arg -tidy_db                -mand 0 -check BOOL  -default 1             -desc {Whether to tidy up open the database package (i.e. result-sets, etc.) during req_end}] \
		[list -arg -default_action         -mand 0 -check ASCII -default {}            -desc {The default action to call (if no 'action' arg).}] \
		[list -arg -default_handler        -mand 0 -check ASCII -default_cfg {DEFAULT_ACTION} -default {} -desc {Deprecated. Legacy tcl handler to run when there isnt an action.}] \
		[list -arg -csrf_check_type        -mand 0 -check ASCII -default_cfg {CSRF_CHECK_TYPE}  -default {DOUBLE_SUBMIT} -desc {The type of check you are after to prevernt csrf.}] \
		[list -arg -csrf_allowed_origins   -mand 0 -check ASCII -default_cfg {CSRF_ALLOWED_ORIGINS}  -default {} -desc {Allow origins list to validate csrf.}] \
		[list -arg -csrf_cookie            -mand 0 -check ASCII -default {OB_REQ}      -desc {The name of the cookie that will contain the CSRF token.}] \
		[list -arg -csrf_domain            -mand 0 -check ASCII -default {}            -desc {The domain used for the CSRF cookie. Used when the CSRF cookie has to be accessed on multiple domains.}] \
		[list -arg -csrf_path              -mand 0 -check ASCII -default {/}           -desc {The path used for the CSRF cookie.}] \
		[list -arg -csrf_form              -mand 0 -check ASCII -default {OB_REQ_FORM} -desc {The name of the hidden field in the form that contains the CSRF token.}] \
		[list -arg -ssl_port               -mand 0 -check UINT  -default 443           -desc {The SSL port}] \
		[list -arg -opt_arg_error_handling -mand 0 \
			-check   {EXACT -args {THROW DEFAULT ON_VALID_ERR}} \
			-default THROW \
			-desc    {What to do if a request argument doesn't pass validation}] \
		[list -arg -get_action_mode        -mand 0 \
			-check   {EXACT -args {URI_PARSE ACTION_ARG}}\
			-default ACTION_ARG \
			-desc    {The logic to use to determine what action handler will be executed.
				URI_PARSE makes req_init operate as a RESTful parser
				ACTION_ARG expects the action activator parameter to be set, either explicitly in the request, or artificially by the -is_action pre-handler
			}\
		] \
		[list -arg -uri_mappings            -mand 0 \
			-check       ANY \
			-default     {}  \
			-default_cfg URI.Mapping \
			-desc        {Only read, parsed and validated if the -get_action_mode option is set to URI_PARSE}  \
		]\
		[list -arg -default_pre_handlers    -mand 0 -check ASCII -default {}                               -desc {Default list of the names of the pre-handlers that the action needs to be executed during req_init}] \
		[list -arg -default_post_handlers   -mand 0 -check ASCII -default {}                               -desc {Default list of the names of the post-handlers that the action needs to be executed during req_end}] \
		[list -arg -default_on_trans_err    -mand 0 -check ASCII -default {core::controller::trans_err}    -desc {Default Name of the callback procedure to call when there is an error with the requests transport mechanism}] \
		[list -arg -default_on_auth_err     -mand 0 -check ASCII -default {core::controller::auth_err}     -desc {Default Name of the callback procedure to call when there is an error with the requests authorisation mechanism}] \
		[list -arg -default_on_valid_err    -mand 0 -check ASCII -default {core::controller::valid_err}    -desc {Default Name of the callback procedure to call when there is an error with the validity of the input to the request}] \
		[list -arg -default_on_csrf_err     -mand 0 -check ASCII -default {core::controller::csrf_err}     -desc {Default Name of the callback procedure to call when there is an error with the validity of the CSRF cookie}] \
		[list -arg -default_on_sys_err      -mand 0 -check ASCII -default {core::controller::sys_err}      -desc {Default Name of the callback procedure to call when there is a system level error}] \
	] \
	-body {
		variable CFG
		variable PROCS
		variable PRE_HANDLERS
		variable REQ_TYPE_MATRIX

		if {$CFG(init)} {
			return
		}

		core::log::write INFO {CONTROLLER: init args=$args}

		# init dependencies
		core::log::init
		core::check::init
		core::random::init -block_size 2048

		# Initialise configuration
		set CFG(strict_mode)            $ARGS(-strict_mode)
		set CFG(tidy_db)                $ARGS(-tidy_db)
		set CFG(csrf_check_type)        $ARGS(-csrf_check_type)
		set CFG(csrf_allowed_origins)   $ARGS(-csrf_allowed_origins)
		set CFG(csrf_cookie)            $ARGS(-csrf_cookie)
		set CFG(csrf_domain)            $ARGS(-csrf_domain)
		set CFG(csrf_path)              $ARGS(-csrf_path)
		set CFG(csrf_form)              $ARGS(-csrf_form)
		set CFG(ssl_port)               $ARGS(-ssl_port)
		set CFG(opt_arg_error_handling) $ARGS(-opt_arg_error_handling)
		set CFG(get_action_mode)        $ARGS(-get_action_mode)

		set CFG(default_pre_handlers)    $ARGS(-default_pre_handlers)
		set CFG(default_post_handlers)   $ARGS(-default_post_handlers)
		set CFG(default_on_trans_err)    $ARGS(-default_on_trans_err)
		set CFG(default_on_auth_err)     $ARGS(-default_on_auth_err)
		set CFG(default_on_valid_err)    $ARGS(-default_on_valid_err)
		set CFG(default_on_csrf_err)     $ARGS(-default_on_csrf_err)
		set CFG(default_on_sys_err)      $ARGS(-default_on_sys_err)

		# Default action name and handler
		set CFG(default_action)  $ARGS(-default_action)
		set CFG(default_handler) $ARGS(-default_handler)

		# Source any packages that we might need.
		if {$CFG(tidy_db)} {
			package require core::db 1.0
		}
		set appserv_procs [list \
			asGetAct           \
			asGetDefaultAction \
			asGetReqInitProc   \
			asGetReqEndProc    \
			asSetAct           \
			asSetDefaultAction \
			asSetReqInitProc   \
			asSetReqEndProc    \
			asSetAction        \
		]

		# Procedures that we can override if strict mode is turned on. We default
		# to the names of the procedures themselves so that when it isnt an
		# application does not notice the difference.
		foreach p $appserv_procs {
			set PROCS($p) $p
		}

		# A matrix of request types that we can accept when an application
		# registers their action handlers.
		#
		#   REQ_TYPE               SESS         TRANS  HTTP  RESOURCE    X-Frame default
		array set REQ_TYPE_MATRIX [list \
			GLOBAL           [list NONE         NONE   NONE  VIEW        sameorigin] \
			LOGIN            [list START        SSL    POST  AUTH_UPDATE deny] \
			LOGOUT           [list END          SSL    NONE  VIEW        sameorigin] \
			PERSONALISE_VIEW [list PERSONALISE  NONE   NONE  VIEW        sameorigin] \
			LOCAL_UPDATE     [list PERSONALISE  NONE   POST  UPDATE      sameorigin] \
			SENSITIVE_VIEW   [list SENSITIVE    SSL    NONE  VIEW        sameorigin] \
			SENSITIVE_UPDATE [list SENSITIVE    SSL    POST  UPDATE      deny] \
			PASSWORD_UPDATE  [list START        SSL    POST  AUTH_UPDATE deny] \
		]
		#   REQ_TYPE               SESS        TRANS  HTTP  RESOURCE

		# appserv_pkg_version will contain what ASVERSION was
		# set to when appserv was compiled (if in appserv)
		set CFG(appserv_pkg_version) 0
		if {[catch {
			set CFG(appserv_pkg_version) [package present OT_AppServ]
		} msg]} {
			core::log::write ERROR {CONTROLLER: We are not within an appserv, no need to rename procs.}
		}

		if {$CFG(appserv_pkg_version) == 0} {
			# not within appserv
			core::log::write INFO {CONTROLLER: Not within appserv}
			incr CFG(init)
			return
		}

		core::log::write INFO {CONTROLLER: Running in appserv version: $CFG(appserv_pkg_version)}

		# Keep track of the applications req_init and req_end procedures just in case.
		set CFG(legacy_req_init) [asGetReqInitProc]
		set CFG(legacy_req_end)  [asGetReqEndProc]

		# We need to claim req_init and req_end so that we run *our* procedures before
		# the application gets a change.
		asSetReqInitProc core::controller::_req_init
		asSetReqEndProc  core::controller::_req_end

		# We need move the procs out of the way.
		foreach p $appserv_procs {
			rename ::$p ::[core::controller::set_cfg -proc $p -value "__${p}__[clock clicks]"]
		}

		# If we're are in strict mode, then the old appserv procs don't exist.
		# So we provide wrappers that will ultimately call this module.
		_create_wrapper_procs

		# Now setup the system pre-handlers
		set PRE_HANDLERS(handlers) [list TRANS AUTH CSRF]
		set PRE_HANDLERS(system)   [list TRANS AUTH CSRF]

		set PRE_HANDLERS(system,TRANS)  TRANS
		set PRE_HANDLERS(TRANS,name)    TRANS
		set PRE_HANDLERS(TRANS,handler) core::controller::_validate_transport
		set PRE_HANDLERS(TRANS,args)    [list \
			[list -type header -name HTTPS          -default   {} -check Az] \
			[list -type header -name SERVER_PORT    -mandatory 1  -check UINT] \
			[list -type header -name REQUEST_METHOD -mandatory 1  -check AZ] \
		]

		set CFG(trans_fwd_header) ""
		if {[set trans_header [OT_CfgGet CORE_FORWARDED_HEADER ""]] != ""} {
			set CFG(trans_fwd_header)       $trans_header
			set CFG(trans_fwd_header_value) [OT_CfgGet CORE_FORWARDED_HEADER_VALUE ""]
			lappend PRE_HANDLERS(TRANS,args)\
				[list -type header -name $trans_header -default {} -check ASCII]
		}

		set csrf_cookie [list -type cookie -name $CFG(csrf_cookie) -check HEX]
		set csrf_form   [list -type arg    -name $CFG(csrf_form)   -check HEX]
		set csrf_origin_header [list -type header -name HTTP_ORIGIN -check HTTP_HOST]

		set PRE_HANDLERS(system,AUTH)   AUTH
		set PRE_HANDLERS(AUTH,name)     AUTH
		set PRE_HANDLERS(AUTH,handler)  core::controller::_validate_auth
		set PRE_HANDLERS(AUTH,args)     [list \
			$csrf_cookie \
		]

		set PRE_HANDLERS(system,CSRF)   CSRF
		set PRE_HANDLERS(CSRF,name)     CSRF
		set PRE_HANDLERS(CSRF,handler)  core::controller::_validate_csrf
		set PRE_HANDLERS(CSRF,args)     [list \
			$csrf_cookie $csrf_form $csrf_origin_header \
		]

		# Where to get the "action" parameter from in req_init. This defines which
		# action handler should run.
		# There are 3 ways an application can choose to handle this:
		#    - do nothing in particular. In this case the action is retrieved by [core::request::get_action]
		#    - Override this logic by declaring their own ACTION prehandler by passing the -is_action flag to
		#      core::controller::add_handler, in which case the task of working out the action handler
		#      relies entirely on this pre-handler
		#    - Rely on the RestFul URI parsing logic in core::controller and core::request.
		#      In this case the application need to initialise core::controller with the -get_action_mode flag
		#      set to URI_PARSE and declare the URI mappings either in the URI.Mapping config or by passing the patterns
		#      to core::controller::init. Note that this is incompatible with declaring an -is_action pre-handler
		#
		set PRE_HANDLERS(ACTION,name)    ACTION

		set CFG(uri_patterns) [dict create]
		switch -exact $CFG(get_action_mode) {
			"ACTION_ARG" {
				set PRE_HANDLERS(ACTION,handler) "core::controller::_get_action"
				set PRE_HANDLERS(ACTION,args)    [list]
			}
			"URI_PARSE" {
				set PRE_HANDLERS(ACTION,handler) "core::request::handle_uri"
				set PRE_HANDLERS(ACTION,args)    [list\
					[list -type header -name REQUEST_URI                 -check ASCII ] \
					[list -type header -name REQUEST_METHOD              -check ASCII ] \
					[list -type header -name CONTENT_TYPE                -check STRING] \
					[list -type header -name HTTP_X_HTTP_METHOD_OVERRIDE -check ASCII ] \
					[list -type header -name SERVER_PROTOCOL             -check STRING] \
					[list -type header -name UNIQUE_ID                   -check STRING] \
					[list -type header -name HTTP_USER_AGENT             -check STRING] \
					[list -type header -name HTTP_X_CSRF_TOKEN           -check ASCII ] \
					[list -type header -name HTTP_ORIGIN                 -check STRING] \
					[list -type arg    -name [asGetActivatorName]        -check ASCII ] \
				]

				# Build up a mapping between the declared action handlers and their URI patterns
				# from the passed list.
				# Expecting a list of items with the format
				#   - http_method        - uri pattern   - action handler   - arguments
				# Note that the action handlers are sensitive to leading namespace colons and
				# should match exactly what is subsequently declared in core::controller::add_handler
				foreach mapping $ARGS(-uri_mappings) {
					lassign $mapping context path action args
					if {![dict exists $CFG(uri_patterns) $action]} {
						dict set CFG(uri_patterns) $action [list]
					}
					dict lappend CFG(uri_patterns) $action [list $context $path $args]
				}
				# We end up with a dict in the format
				# {action1 \
				#     {GET      /somethings/*    {something_id}} \
				#     {POST     /somethings      {}} \
				# } ...etc...
			}
		}

		incr CFG(init)
	}

#--------------------------------------------------------------------------
# Error Handling
#--------------------------------------------------------------------------


# Handle handler and general errors
proc core::controller::_handle_error {type handler msg {set_action 1}} {
	variable ERRORS
	variable REQ_ACTION

	lappend ERRORS($type) $msg

	core::log::write ERROR {CONTROLLER: ERROR $handler action $REQ_ACTION. $msg}

	if {$set_action} {
		asSetAction $handler
	}
}

# Return any pre-handler errors
proc core::controller::get_pre_handler_errors {} {
	variable ERRORS
	return $ERRORS(pre_handler)
}

# Return any post-handler errors
proc core::controller::get_post_handler_errors {} {
	variable ERRORS
	return $ERRORS(post_handler)
}

# Get system level errors that aren't covered by auth, input etc
proc core::controller::get_sys_errors {} {

	variable ERRORS

	if {![info exists ERRORS(sys)]} {
		return {}
	}

	return $ERRORS(sys)
}

#--------------------------------------------------------------------------
# Configuration
#--------------------------------------------------------------------------
core::args::register \
	-proc_name core::controller::get_cfg \
	-is_public 0 \
	-args      [list \
		[list -arg -config  -mand 0 -check ASCII -default {} -desc {Name of the configuration item to retrieve}] \
		[list -arg -proc    -mand 0 -check ASCII -default {} -desc {Name of the procedure to retreieve}] \
		[list -arg -default -mand 0 -check ASCII -default {} -desc {Default value to return if the config cannot be found}] \
	] \
	-body {
		variable CFG
		variable PROCS

		set config $ARGS(-config)
		set prc    $ARGS(-proc)

		if {$config != ""} {
			if {[info exists CFG($config)]} {
				return $CFG($config)
			}
		}

		if {$prc != ""} {
			if {[info exists PROCS($prc)]} {
				return $PROCS($prc)
			}
		}

		return $ARGS(-default)
	}

# TODO: Do we allow strict_mode to be changed? If we do then we would need to make
#       sure we declare/re-declare all of the global procedures. We would also
#       need to keep track of how many times we have declared/re-declared
#       these procedures.
core::args::register \
	-proc_name core::controller::set_cfg \
	-is_public 0 \
	-args      [list \
		[list -arg -config -mand 0 -check ASCII -default {} -desc {Name of the configuration item to set.}] \
		[list -arg -proc   -mand 0 -check ASCII -default {} -desc {Name of the procedure to retreieve.}] \
		[list -arg -value  -mand 1 -check ASCII             -desc {Default value to return if the config cannot be found.}] \
	] \
	-body {
		set config $ARGS(-config)
		set prc    $ARGS(-proc)

		if {$config != ""} {
			variable CFG
			if {[info exists CFG($config)]} {
				set CFG($config) $ARGS(-value)

				if {$config == "default_handler"} {
					[get_cfg -proc asSetDefaultAction] $ARGS(-value)
				}

				return $CFG($config)
			}
		}

		if {$prc != ""} {
			variable PROCS
			if {[info exists PROCS($prc)]} {
				set PROCS($prc) $ARGS(-value)
				return $PROCS($prc)
			}
		}
	}

core::args::register \
	-proc_name core::controller::get_req_cfg \
	-is_public 0 \
	-args      [list \
		[list -arg -config  -mand 0 -check ASCII -default {} -desc {Name of the request configuration item to retrieve}] \
		[list -arg -default -mand 0 -check ASCII -default {} -desc {Default value to return if the config cannot be found}] \
	] \
	-body {
		variable REQUEST

		set config $ARGS(-config)

		if {[info exists REQUEST($config)]} {
			return $REQUEST($config)
		}

		return $ARGS(-default)
	}

#--------------------------------------------------------------------------
# Request Initialisation and Termination
#--------------------------------------------------------------------------

proc core::controller::_req_init args {

	variable CFG
	variable REQ_ACTION
	variable SET_ACTION
	variable ACTIONS
	variable PRE_HANDLERS
	variable REQUEST
	variable ERRORS
	variable REQ_TYPE_MATRIX

	core::log::set_prefix [format {%03d:%05d} [asGetId] [reqGetId]]

	# Call Garbage Collector mark proc
	core::gc::mark

	core::gc::add core::controller::REQUEST
	core::gc::add core::controller::REQ_ACTION
	core::gc::add core::controller::SET_ACTION
	core::gc::add core::controller::ERRORS

	array set ERROR [array unset ERRORS]

	set REQ_ACTION        {}
	set SET_ACTION        {}
	set REQUEST(is_https) 0
	set REQUEST(is_post)  0

	set ERRORS(pre_handler)  [list]
	set ERRORS(post_handler) [list]

	# Now we need to figure out what action to run. By default this retrieves a
	# request parameter called "action". However, an application can override
	# this if they wish by defining a special pre-handler with the -is_action
	# parameter set to true.
	set ph_handler $PRE_HANDLERS(ACTION,name)

	if {[catch {
		core::log::write DEBUG {Executing ACTION pre-handler in $CFG(get_action_mode) mode}
		array set ACTION [_execute_req_handler \
			$ph_handler \
			$PRE_HANDLERS($ph_handler,handler) \
			$PRE_HANDLERS($ph_handler,args)]

		set names [array names ACTION]

		# The handler must return at least one parameter called "action"
		if {[lsearch $names action] == -1} {
			_handle_error \
				sys \
				$CFG(default_on_sys_err) \
				"Cannot find action parameter from $ph_handler using procedure $PRE_HANDLERS($ph_handler,handler)"

			return
		}

		# This is the action we want to execute
		set REQ_ACTION $ACTION(action)

		foreach n $names {
			core::request::set_arg -name $n -value $ACTION($n) -validate 0
		}

		core::request::_fetch_req_arg_names 1
	} msg]} {
		core::log::write_error_info ERROR
		core::log::write ERROR {CONTROLLER: ERROR $ph_handler pre-handler failed. $msg}

		_handle_error \
			pre_handler \
			core::controller::pre_handler_err \
			[list pre_handler $ph_handler error_msg $msg]

		return
	}

	core::log::write DEBUG {CONTROLLER: _req_init - action=$REQ_ACTION}

	# Two scenarios, firstly we have an action that hasnt been registered.
	# Secondly, we have a blank action and the application hasnt registered
	# a -default_action. We know there isnt a -default_action because the
	# ACTION pre-handler above will substitute that in if there is one. This
	# is done via core::controller::_get_action and core::request::get_action.
	#
	# If either of these are true and the strict mode is disable, run the legacy req_init and set the handler
	#
	if {[get_cfg -config strict_mode -default 0] == 0 && (
			($REQ_ACTION != "" && [lsearch $ACTIONS(actions) $REQ_ACTION] == -1) ||
			$REQ_ACTION == ""
	)} {

		core::log::write WARNING {CONTROLLER: using legacy handler $CFG(legacy_req_init) for action=$REQ_ACTION}
		# Just make sure that the request is set up, but we don't specify
		# any args to validate because this action hasn't been registered!
		core::request::reset

		# Allow the legacy req_init proc to be called so the basic handler
		# can run.
		set legacy_req_init $CFG(legacy_req_init)

		# Some quick sanity checks to make sure that we have a proc to run
		# and we don't enter an infinite loop.
		if {$legacy_req_init != "" && $legacy_req_init != "core::controller::_req_init"} {
			core::log::write WARNING {CONTROLLER: calling: '$legacy_req_init'}
			$legacy_req_init
		}

		# the handler is already defined externally.
		# for example in admin there are some cases where
		# the handler is defined in the legacy init and does not depends on the action.
		if {$SET_ACTION != ""} {

			core::log::write INFO {CONTROLLER: Handler already defined: $SET_ACTION}
			core::request::_log_request $REQ_ACTION $SET_ACTION
			return
		}

		# If we have a blank action, then we know our only other option is to run the
		# default handler (i.e. api=asSetDefaultAction or config=DEFAULT_ACTION). As
		# the default handler is only a tcl procedure, we cant validate anything as
		# all validation is driven off the name of the action rather than its tcl proc.
		if {$REQ_ACTION == ""} {

			set action  "DEFAULT"
			set handler [get_cfg -config default_handler]
			core::log::write WARNING {CONTROLLER: warning using default handler $handler.}

			if {$handler == ""} {
				# the default handler has not been registered to the appserv, need to throw an error
				_handle_error \
					sys \
					$CFG(default_on_sys_err) \
					"CONTROLLER: Cannot find handler for action $action"
			}

		} else {

			set action  $REQ_ACTION
			set handler [asGetAct $REQ_ACTION]
		}

		# Log the request arguments. Note that if the action is registered
		# then only the valid arguments will be logged
		core::request::_log_request $action $handler

		# We have an action name, but it hasnt been registered. So we can log nicely
		# but we cant validate any input.
		#
		# For Admin, the file may not be sourced yet due to tclUnknown and the
		# NAMESPACE_MAP, so we may not get an action handler back. In this
		# scenario we want to leave running the action to the appserv and
		# NAMESPACE_MAP, so that the file is sourced first.
		#

		if {$handler != {}} {
			# Tell the appserv what to execute.
			asSetAction $handler
		}
		return
	}

	# We have received a request argument to identify the action handler.
	# Validate this argument against the criteria that was defined when
	# the application registered the action.
	if {[lsearch $ACTIONS(actions) $REQ_ACTION] == -1} {
		_handle_error \
			sys \
			$CFG(default_on_sys_err) \
			"CONTROLLER: Cannot find action $REQ_ACTION"

		return
	}

	set req_type $ACTIONS($REQ_ACTION,req_type)
	lassign $REQ_TYPE_MATRIX($req_type) sess trans http res default_x_frame_opt

	# Run all of the system pre-handlers.
	foreach sys $PRE_HANDLERS(system) {

		# Determine if the pre handler can be skipped based on the request type.
		switch -exact -- $sys {
			"TRANS" {
				if {$trans eq "NONE" && $http eq "NONE"} {
					continue
				}
			}
			"AUTH" {
				if {$sess eq "NONE"} {
					continue
				}
			}
			"CSRF" {
				if {$res ne "UPDATE"} {
					continue
				}
			}
		}

		if {[catch {_execute_req_handler \
			$sys \
			$PRE_HANDLERS($sys,handler) \
			$PRE_HANDLERS($sys,args) \
			$REQ_ACTION \
		} msg]} {

			_handle_error \
				pre_handler \
				$ACTIONS($REQ_ACTION,err,$sys) \
				[list pre_handler $sys error_msg $msg]
			return
		}
	}

	# Add x-frame options
	_set_xframe_option $REQ_ACTION

	# Now run all of the pre-handlers that the application has registered.
	foreach ph $ACTIONS($REQ_ACTION,pre_handlers) {

		set ph_handler [lindex $ph 0]
		set ph_error   [lindex $ph 1]

		if {[catch {_execute_req_handler \
			$ph_handler \
			$PRE_HANDLERS($ph_handler,handler) \
			$PRE_HANDLERS($ph_handler,args)
		} msg]} {
			if {$ph_error == ""} {
				set handler core::controller::pre_handler_err
			} else {
				set handler $ph_error
			}

			_handle_error \
				pre_handler \
				$handler \
				[list pre_handler $ph_handler error_msg $msg]

			return
		}
	}

	# Now run the input validation, which if successful means we can run the
	# proper action handler. This also means the request arguments will be
	# available to the request.
	core::request::reset
	if {[catch {core::request::populate -inputs $ACTIONS($REQ_ACTION,args)} msg]} {
		_handle_error \
			input \
			$ACTIONS($REQ_ACTION,err,INPUT) \
			"CONTROLLER: ERROR validating $REQ_ACTION. $msg"

		return
	}
	core::request::check_missing_args

	set v_errors [core::request::get_mandatory_errors]
	if {[llength $v_errors] > 0} {
		_handle_error \
			input \
			$ACTIONS($REQ_ACTION,err,INPUT) \
			"CONTROLLER: ERROR validating arguments for action $REQ_ACTION. $v_errors"

		return
	}

	core::log::write DEBUG {CONTROLLER: using handler $ACTIONS($REQ_ACTION,handler) for action $REQ_ACTION}

	# Log the request arguments. Note that if the action is registered
	# then only the valid arguments will be logged
	core::request::_log_request $REQ_ACTION $ACTIONS($REQ_ACTION,handler)

	# Validation succeeded so tell the appserv what to execute.
	asSetAction $ACTIONS($REQ_ACTION,handler)
}

proc core::controller::_req_end args {

	variable CFG
	variable ACTIONS
	variable REQ_ACTION
	variable POST_HANDLERS

	core::log::write DEBUG {CONTROLLER: _req_end}

	set strict_mode [get_cfg -config strict_mode -default 0]

	if {$REQ_ACTION in $ACTIONS(actions)} {

		# Now run all of the post-handlers that the application has registered.
		foreach ph $ACTIONS($REQ_ACTION,post_handlers) {

			set ph_handler [lindex $ph 0]
			set ph_error   [lindex $ph 1]

			if {[catch {_execute_req_handler \
				$ph_handler \
				$POST_HANDLERS($ph_handler,handler) \
				$POST_HANDLERS($ph_handler,args)
			} msg]} {
				_handle_error \
					post_handler \
					{} \
					[list post_handler $ph_handler error_msg $msg] \
					0
			}
		}

	} elseif {$strict_mode == 0} {

		core::log::write WARNING {CONTROLLER: using legacy post handler for action=$REQ_ACTION}

		# Just make sure that the request is set up, but we don't specify
		# any args to validate because this action hasn't been registered!
		core::request::reset

		# Allow the legacy req_init proc to be called so the basic handler
		# can run.
		set legacy_req_end $CFG(legacy_req_end)

		# Some quick sanity checks to make sure that we have a proc to run
		# and we don't enter an infinite loop.
		if {$legacy_req_end != "" && $legacy_req_end != "core::controller::_req_end"} {
			core::log::write WARNING {CONTROLLER: calling: '$CFG(legacy_req_end)'}
			$CFG(legacy_req_end)
		}
	}

	if {[get_cfg -config tidy_db -default 1]} {
		# Cleanup any outstanding DB queries and result sets
		core::db::req_end
	}

	core::log::set_prefix {}

	# Have we played out any headers to the buffer
	# OBCORE-142
	if {$strict_mode && ![core::view::has_played_headers]} {
		core::log::write ERROR {CONTROLLER: No headers have been written to the buffer}
		core::gc::clean_up
		error "No Headers have been written to buffer"
	}

	# Cleanup the garbage collector
	core::gc::clean_up
}

#--------------------------------------------------------------------------
# Registration Procedures
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::controller::add_handler \
	-args      [list \
		[list -arg -action         -mand 1 -check ASCII              -desc {Name of the action}] \
		[list -arg -handler        -mand 1 -check ASCII              -desc {Procedure name to execute for a given action}] \
		[list -arg -req_type       -mand 1 -check ASCII              -desc {What does the action do? Does it update customer details?}] \
		[list -arg -validate       -mand 0 -check ASCII  -default {} -desc {Name of validation procedure to call for this action}] \
		[list -arg -default_action -mand 0 -check BOOL   -default 0  -desc {Is this action the default action?}] \
		[list -arg -pre_handlers   -mand 0 -check ASCII  -default {} -desc {A list of the names of the pre-handlers that the action needs to be executed during req_init}] \
		[list -arg -post_handlers  -mand 0 -check ASCII  -default {} -desc {A list of the names of the post-handlers that the action needs to be executed during req_end}] \
		[list -arg -x_frame_opt    -mand 0 -check ASCII  -default {} -desc {Clickjacking protection: "deny" - no rendering within a frame, "sameorigin" - no rendering if origin mismatch, "none" - Omit header}] \
		[list -arg -args           -mand 0 -check STRING -default 0  -desc {The request arguments required. See core::request::validate_and_get for details of what parameters are valid. Takes a list of lists.}] \
		[list -arg -on_trans_err   -mand 0 -check ASCII  -default {} -desc {Name of the callback procedure to call when there is error with the requests transport mechanism}] \
		[list -arg -on_auth_err    -mand 0 -check ASCII  -default {} -desc {Name of the callback procedure to call when there is an error with the requests authorisation mechanism}] \
		[list -arg -on_valid_err   -mand 0 -check ASCII  -default {} -desc {Name of the callback procedure to call when there is an error with the validity of the input to the request}] \
		[list -arg -on_csrf_err    -mand 0 -check ASCII  -default {} -desc {Name of the callback procedure to call when there is an error with the validity of the CSRF cookie}] \
		[list -arg -on_sys_err     -mand 0 -check ASCII  -default {} -desc {Name of the callback procedure to call when there is a system level error}] \
	] \
	-body {
		variable CFG
		variable ACTIONS
		variable REQ_TYPE_MATRIX

		# Until we allow a default of a list, we need this.
		if {$ARGS(-args) == 0} {
			set ARGS(-args) [list]
		}

		set action $ARGS(-action)

		core::log::write INFO {CONTROLLER: add_handler action=$action handler=$ARGS(-handler) req_type=$ARGS(-req_type)}
		core::log::write DEV {CONTROLLER: add_handler $args}

		# Set up defaults not explicitly passed in this request
		if {$ARGS(-pre_handlers) == {}} {
			set ARGS(-pre_handlers) $CFG(default_pre_handlers)
		}

		if {$ARGS(-post_handlers) == {}} {
			set ARGS(-post_handlers) $CFG(default_post_handlers)
		}

		if {$ARGS(-on_trans_err) == {}} {
			set ARGS(-on_trans_err) $CFG(default_on_trans_err)
		}

		if {$ARGS(-on_auth_err) == {}} {
			set ARGS(-on_auth_err) $CFG(default_on_auth_err)
		}

		if {$ARGS(-on_valid_err) == {}} {
			set ARGS(-on_valid_err) $CFG(default_on_valid_err)
		}

		if {$ARGS(-on_csrf_err) == {}} {
			set ARGS(-on_csrf_err) $CFG(default_on_csrf_err)
		}

		if {$ARGS(-on_sys_err) == {}} {
			set ARGS(-on_sys_err) $CFG(default_on_sys_err)
		}

		# Additional validation
		if {![info exists REQ_TYPE_MATRIX($ARGS(-req_type))]} {
			return [list 0 "Invalid request type of $ARGS(-req_type)"]
		}

		# Keep a list of all the possible actions
		if {[lsearch ACTIONS(actions) $action] == -1} {
			lappend ACTIONS(actions) $action
		}

		if {$ARGS(-default_action)} {
			if {$CFG(default_action) != "" && $CFG(default_action) != $action} {
				core::log::write WARNING {CONTROLLER: WARNING changing default action from $CFG(default_action) to $action}
			}
			set CFG(default_action) $action
		}

		set ACTIONS($action,action)        $action
		set ACTIONS($action,handler)       $ARGS(-handler)
		set ACTIONS($action,req_type)      $ARGS(-req_type)
		set ACTIONS($action,validate)      $ARGS(-validate)
		set ACTIONS($action,pre_handlers)  $ARGS(-pre_handlers)
		set ACTIONS($action,post_handlers) $ARGS(-post_handlers)
		set ACTIONS($action,err,TRANS)     $ARGS(-on_trans_err)
		set ACTIONS($action,err,AUTH)      $ARGS(-on_auth_err)
		set ACTIONS($action,err,INPUT)     $ARGS(-on_valid_err)
		set ACTIONS($action,err,CSRF)      $ARGS(-on_csrf_err)
		set ACTIONS($action,err,SYS)       $ARGS(-on_sys_err)
		set ACTIONS($action,x_frame_opt)   $ARGS(-x_frame_opt)
		set ACTIONS($action,args)          $ARGS(-args)

		# If RESTful URI parsing is used to direct the request to this action handler,
		# then we expect the URI pattern to be set, unless it's the default action
		if {$CFG(get_action_mode) == "URI_PARSE" && !$ARGS(-default_action)} {
			if {![dict exists $CFG(uri_patterns) $action]} {
				error "Must have a URI mapping for $action" {} URI_PATTERN_NOT_DECLARED
			}

			foreach mapping [dict get $CFG(uri_patterns) $action] {
				lassign $mapping context path args
				core::request::register_uri\
					-context $context\
					-path    $path\
					-action  $action\
					-args    $args
			}
		}

		# Validate and each argument list
		set ret [_validate_handler_args $ACTIONS($action,args)]
		if {![lindex $ret 0]} {
			return $ret
		}

		set ACTIONS($action,arg_names) [lindex $ret 1]

		# Tell the application server the action name and handler if we are in an appserv
		if {$CFG(appserv_pkg_version) != ""} {
			[get_cfg -proc asSetAct] $action $ARGS(-handler)
		}

		return [list 1]
	}

core::args::register \
	-proc_name core::controller::add_pre_handler \
	-args      [list \
		[list -arg -name       -mand 1 -check ASCII             -desc {Name of the pre-handler}] \
		[list -arg -handler    -mand 1 -check ASCII             -desc {Tcl procedure to execute for this pre-handler}] \
		[list -arg -is_auth    -mand 0 -check BOOL  -default 0  -desc {Does this pre-handler perform user authentication? There can only be one of these.}] \
		[list -arg -is_action  -mand 0 -check BOOL  -default 0  -desc {Does this pre-handler define which handler to execute? There can only be one of these.}] \
		[list -arg -args       -mand 0 -check ASCII -default {} -desc {List of request arguments used in this pre-handler.}] \
	] \
	-body {
		variable CFG
		variable PRE_HANDLERS

		set name    $ARGS(-name)
		set handler $ARGS(-handler)

		core::log::write INFO {CONTROLLER: add_pre_handler name=$name handler=$handler}

		# Make sure a pre-handler doesnt already exist.
		if {[lsearch PRE_HANDLERS(handlers) $name] != -1} {
			return [list 0 "Pre-handler $name already exists"]
		}

		lappend PRE_HANDLERS(handlers) $name

		if {$ARGS(-is_auth)} {

			if {[info exists PRE_HANDLERS(AUTH,app_handler)]} {
				core::log::write WARNING {CONTROLLER: WARNING changing authentication pre-handler from $PRE_HANDLERS(AUTH,app_handler) to $name}
			}

			set PRE_HANDLERS(AUTH,app_handler) $name
		}

		if {$ARGS(-is_action)} {
			# If using the built-in restful parsing, overriding the ACTION pre-handler is
			# pointless. Throw an error to avoid unexpected behaviour
			if {$CFG(get_action_mode) == "URI_PARSE"} {
				error "URI_PARSE mode is incompatible with overriding the ACTION pre-handler" {} INCOMPATIBLE_ACTION_MODE
			}
			core::log::write WARNING {CONTROLLER: WARNING changing action pre-handler from $PRE_HANDLERS(ACTION,name) to $name}
			set PRE_HANDLERS(ACTION,name) $name
		}

		set PRE_HANDLERS($name,handler) $handler
		set PRE_HANDLERS($name,args)    $ARGS(-args)

		# Validate and each argument list
		set ret [_validate_handler_args $PRE_HANDLERS($name,args)]
		if {![lindex $ret 0]} {
			return $ret
		}

		set ACTIONS($name,arg_names) [lindex $ret 1]

		return [list 1]
	}

core::args::register \
	-proc_name core::controller::add_post_handler \
	-args      [list \
		[list -arg -name    -mand 1 -check ASCII             -desc {Name of the post-handler}] \
		[list -arg -handler -mand 1 -check ASCII             -desc {Tcl procedure to execute for this post-handler}] \
		[list -arg -args    -mand 0 -check ASCII -default {} -desc {List of request arguments used in this post-handler.}] \
	] \
	-body {
		variable CFG
		variable POST_HANDLERS

		set name    $ARGS(-name)
		set handler $ARGS(-handler)

		core::log::write INFO {CONTROLLER: add_post_handler name=$name handler=$handler}

		# Make sure a pre-handler doesnt already exist.
		if {[lsearch POST_HANDLERS(handlers) $name] != -1} {
			return [list 0 "Post-handler $name already exists"]
		}

		lappend POST_HANDLERS(handlers) $name

		set POST_HANDLERS($name,handler) $handler
		set POST_HANDLERS($name,args)    $ARGS(-args)

		# Validate and each argument list
		set ret [_validate_handler_args $POST_HANDLERS($name,args)]
		if {![lindex $ret 0]} {
			return $ret
		}

		set POST_HANDLERS($name,arg_names) [lindex $ret 1]

		return [list 1]
	}

# Validate a list of pre/post/main handler args
proc core::controller::_validate_handler_args {handler_args} {

	set arg_names [list]

	# build up lists of argument names by each type
	# duplicate detection uses these
	foreach arg_type {arg header cookie} {
		foreach name_type {exact glob regexp} {
			set ARGS_BY_TYPE($arg_type,$name_type) [list]
		}
	}

	foreach arg_list $handler_args {
		set checks     [list]
		set check_list [list]
		set other_args [list]

		foreach {n v} $arg_list {
			if {$n == "-check"} {
				lappend checks $v
				lappend check_list [list $n $v]
			} else {
				lappend other_args $n $v
			}
		}

		# Add the last check to satisfy the mandatory validate_and_get check
		lappend other_args {*}[lindex $check_list end]

		# Validate the arguments
		if {[catch {set args_dict [core::args::check core::request::validate_and_get {*}$other_args]} err]} {
			return [list 0 "Invalid argument list ($arg_list) : $err"]
		}

		set name [dict get $arg_list -name]

		set name_type [dict get $args_dict -name_type]
		set arg_type  [dict get $args_dict -type]

		lappend ARGS_BY_TYPE($arg_type,$name_type) $name

		lappend arg_names $name
	}

	# verify that there are no duplicates in the 'arg','header' and 'cookie' names,
	# i.e. - check that no 2 arg names are the same (e.g. 'pmb_Index' not repeated)
	#      - check that the glob+regexp arg names don't match any exact are name
	#        (e.g. so if 'pmb_Index' is an exact name, and 'pmb_*' is a glob,
	#         then we detect that pmb_* matches pmb_Index and we error.)
	_detect_duplicate_args arg    ARGS_BY_TYPE
	_detect_duplicate_args header ARGS_BY_TYPE
	_detect_duplicate_args cookie ARGS_BY_TYPE

	array set ARGS_BY_TYPE [array unset ARGS_BY_TYPE]

	return [list 1 $arg_names]
}

# proc:  _detect_duplicate_args
#
# Purpose:    add_handler args names are of 3 '-name_type' types:
#             - exact
#             - glob
#             - regexp
#
#             (Trouble is caused if 1 request argument matches
#             more than 1 argument name.)
#             Therefore, detect if there are any duplicates,
#             ie - if 2 arg names are the same
#                - if any 'glob' name also matches an exact name
#                - if any 'regexp' name also matches an exact name
#
#             Print out all duplicates found at ERROR to logfile,
#             and then 'error' if any duplicates found (so programmer must fix)
#
# Parameters:  type - one of 'arg', 'header' or 'cookie' (ie. the -type add_handler arg options)
#                     This says which arg_type we will check for duplicates in the
#                     <array_name>.
#              array_name - name of the array that has 3 items for supplied <type>:
#                  array_name($type,exact)  - list of all the '-name_type exact' arg names
#                  array_name($type,glob)   - list of all the '-name_type glob' arg names
#                  array_name($type,regexp) - list of all the '-name_type regexp' arg names
#              action - name of the action (for log error message)
#
# Returns:    if no duplicates found: void
#             if duplicates found: it throws a TCL_ERROR
#
# Notes:      having ARGS_BY_TYPE(arg,exact) {one two}
#                and ARGS_BY_TYPE(header,exact) {one two}
#                and ARGS_BY_TYPE(cookie,exact) {one two}
#             is ok, because reqGetArg + reqGetEnv + reqGetEnv HTTP_COOKIE
#             are fully independent.
#
proc core::controller::_detect_duplicate_args {type array_name} {

	upvar 1 $array_name ARGS_BY_TYPE
	set dups_found 0

	set prev_name {}

	# first check no names the same, go through in sorted order
	foreach name [lsort [concat $ARGS_BY_TYPE($type,exact) $ARGS_BY_TYPE($type,glob) $ARGS_BY_TYPE($type,regexp)]] {
		if {$name == $prev_name} {
			core::log::write ERROR {CONTROLLER: add_handler DUPLICATE_ARG ERROR - name='$name' is repeated.}
			incr dups_found
		}
		set prev_name $name
	}

	# now go through the glob names, and see if they match any exact name
	foreach glob_name $ARGS_BY_TYPE($type,glob) {

		# I choose not to use 'lsearch -glob $ARGS_BY_TYPE($type,exact) $glob_name'
		# so that I find every match, to help the user
		foreach exact_name $ARGS_BY_TYPE($type,exact) {
			# globs are matched with 'string match'
			if {[string match $glob_name $exact_name]} {
				core::log::write ERROR \
					{CONTROLLER: add_handler DUPLICATE_ARG ERROR - glob arg='$glob_name' matches exact arg '$exact_name'.}
				incr dups_found
			}
		}
	}

	# now go through the regexp names, and see if they match any exact name
	foreach regexp_name $ARGS_BY_TYPE($type,regexp) {

		# I choose not to use 'lsearch -regexp $ARGS_BY_TYPE($type,exact) $regexp_name'
		# so that I find every match, to help the user
		foreach exact_name $ARGS_BY_TYPE($type,exact) {
			# regexps are matched with 'regexp'
			if {[regexp -- $regexp_name $exact_name]} {
				core::log::write ERROR \
					{CONTROLLER: add_handler DUPLICATE_ARG ERROR - regexp arg='$regexp_name' matches exact arg '$exact_name'.}
				incr dups_found
			}
		}
	}

	if {$dups_found > 0} {
		core::log::write ERROR {CONTROLLER: add_handler DUPLICATE_ARG ERROR: $dups_found duplicate args of type '$type' detected.}
		error "CONTROLLER: add_handler ERROR $dups_found duplicate args of type '$type' detected. Aborting." {} DUPLICATE_ARG
	}
}


#--------------------------------------------------------------------------
# CSRF Procedure Exposure
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::controller::generate_csrf \
	-args [list] \
	-body {
		return [_generate_csrf]
	}


#--------------------------------------------------------------------------
# Pre-handler/Post-handler/Action retrieval
#--------------------------------------------------------------------------

proc core::controller::get_pre_handlers args {

	variable PRE_HANDLERS

	return $PRE_HANDLERS(handlers)
}

proc core::controller::get_pre_handler {handler} {

	variable PRE_HANDLERS

	if {[lsearch $PRE_HANDLERS(handlers) $handler] == -1} {
		core::log::write ERROR {CONTROLLER: ERROR Cannot find pre-handler $handler}
		return [list]
	}

	return [list \
		args    $PRE_HANDLERS($handler,args)\
		handler $PRE_HANDLERS($handler,handler)
	]
}

proc core::controller::get_post_handlers args {

	variable POST_HANDLERS

	return $POST_HANDLERS(handlers)
}

proc core::controller::get_post_handler {handler} {

	variable POST_HANDLERS

	if {[lsearch $POST_HANDLERS(handlers) $handler] == -1} {
		core::log::write ERROR {CONTROLLER: ERROR Cannot find post-handler $handler}
		return [list]
	}

	return [list \
		args $POST_HANDLERS($handler,args)
	]
}

proc core::controller::get_actions args {

	variable ACTIONS

	return $ACTIONS(actions)
}

core::args::register \
	-proc_name core::controller::is_action_registered \
	-desc      {Has the action been registered with controller} \
	-args      [list \
		[list -arg -action -mand 1 -check ASCII -desc {Name of the action}] \
	] \
	-body {
		variable ACTIONS

		if {[lsearch $ACTIONS(actions) $ARGS(-action)] == -1} {
			return 0
		}

		return 1
	}

proc core::controller::get_action {action} {

	variable ACTIONS

	if {[lsearch $ACTIONS(actions) $action] == -1} {
		core::log::write ERROR {CONTROLLER: ERROR Cannot find action $action}
		return [list]
	}

	return [list \
		handler       $ACTIONS($action,handler) \
		req_type      $ACTIONS($action,req_type) \
		validate      $ACTIONS($action,validate) \
		pre_handlers  $ACTIONS($action,pre_handlers) \
		post_handlers $ACTIONS($action,post_handlers) \
		err_SYS       $ACTIONS($action,err,SYS) \
		err_TRANS     $ACTIONS($action,err,TRANS) \
		err_AUTH      $ACTIONS($action,err,AUTH) \
		err_INPUT     $ACTIONS($action,err,INPUT) \
		err_CSRF      $ACTIONS($action,err,CSRF) \
		x_frame_opt   $ACTIONS($action,x_frame_opt) \
		args          $ACTIONS($action,args) \
	]
}

# Return registered action arguments
proc core::controller::get_action_args {action} {
	variable ACTIONS

	if {[info exists ACTIONS($action,arg_names)]} {
		return $ACTIONS($action,arg_names)
	}

	return {}
}

#--------------------------------------------------------------------------
# Error Handling
#--------------------------------------------------------------------------

proc core::controller::trans_err args {
	error "CONTROLLER: transport error $args"
}

proc core::controller::auth_err args {
	error "CONTROLLER: authorisation error $args"
}

proc core::controller::valid_err args {
	error "CONTROLLER: validation error $args"
}

proc core::controller::csrf_err args {
	error "CONTROLLER: CSRF error $args"
}

proc core::controller::pre_handler_err args {
	error "CONTROLLER: pre handler error $args"
}

proc core::controller::sys_err args {
	error "CONTROLLER: server internal error $args"
}


# Set the HTTP x-frame option  based on the request type
# and possibly overridden in the add_handler
# Ref - OBCORE-11
# @param action Request action
proc core::controller::_set_xframe_option {action} {

	variable ACTIONS
	variable REQ_TYPE_MATRIX

	set req_type $ACTIONS($action,req_type)
	lassign $REQ_TYPE_MATRIX($req_type) sess trans http res default_x_frame_opt

	set x_frame_opt $ACTIONS($action,x_frame_opt)

	if {$x_frame_opt == {}} {
		set x_frame_opt $default_x_frame_opt
	}

	if {[string toupper $x_frame_opt] == {NONE}} {
		core::log::write WARN {CONTROLLER: Omitting x-frame-options header}
		return
	}

	core::view::add_header -name X-Frame-Options -value $x_frame_opt
}

#--------------------------------------------------------------------------
# Private Procedures - Pre-Handlers
#--------------------------------------------------------------------------

# Transport Pre-Handler. This takes one parameter of action, like the
# other system pre-handlers. We need to make sure the request has been
# made on a suitable transport mechanism, i.e. SSL/HTTP POST?
#
proc core::controller::_validate_transport {action} {

	variable ACTIONS
	variable REQ_TYPE_MATRIX
	variable REQUEST

	set req_type $ACTIONS($action,req_type)
	lassign $REQ_TYPE_MATRIX($req_type) sess trans http res default_x_frame_opt

	core::log::write DEBUG {CONTROLLER: _validate_transport action=$action req_type=$req_type session=$sess transport=$trans http=$http resource=$res}

	set REQUEST(is_https) [_is_https]
	set REQUEST(is_post)  [_is_post]

	# SSL Connection?
	if {$trans == "SSL" && !$REQUEST(is_https)} {
		error "Not using SSL for action $action"
	}

	# HTTP Post?
	if {$http == "POST" && !$REQUEST(is_post)} {
		error "Not using a POST form method for action $action"
	}

	return
}

# Authentication Pre-Handler. This takes one parameter of action, like the
# other system pre-handlers, but it itself calls the pre-handler that the
# application has registered. This will be the case until we can merge all
# of the authentication mechanisms together from all branches, i.e. merge
# ob_login & ob_admin_login.
#
proc core::controller::_validate_auth {action} {

	variable CFG
	variable ACTIONS
	variable REQ_TYPE_MATRIX

	# Now try and figure out whether we need run authentication for this request
	# This is dependent on the action handlers session condition
	set req_type $ACTIONS($action,req_type)
	lassign $REQ_TYPE_MATRIX($req_type) sess trans http res default_x_frame_opt

	# Nothing to do if session type is NONE. This is for requests like PlayJS,
	# where we do not need to worry whether the customer is logged in or not.
	if {$sess == "NONE"} {
		return
	}

	# Start of a session, i.e. the request is probably a form login of some
	# variety. We always want to set the CSRF cookie, but dont need to check
	# the authentication mechanism, the customer probably doesnt have a login
	# cookie.
	if {$sess == "START"} {
		_set_csrf_cookie [_generate_csrf]
		return
	}

	# End of a session, i.e. the request is probably to log the customer out.
	# OBCORE-158 We should expire the cookie so it is still valid
	if {$sess == "END"} {
		_set_csrf_cookie [_generate_csrf] "Thu, 01-Jan-1970 00:00:01 GMT"
		return
	}

	# We should just have PERSONALISE and SENSITIVE left. These decide whether
	# we want to check the insecure or secure cookie respectively. Of course
	# for Admin apps and some customer teams' apps dont have two cookies.
	set mode NONE
	if {$sess == "PERSONALISE"} {
		set mode INSECURE
	} elseif {$sess == "SENSITIVE"} {
		set mode SECURE
	} else {
		error "Unknown session type of $sess"
	}

	variable PRE_HANDLERS

	if {![info exists PRE_HANDLERS(AUTH,app_handler)]} {
		error "Cannot find authentication mechanism."
	}

	# Store the CSRF cookie before we execute the external Auth pre-handler so
	# that we dont lose the reference to it.
	set csrf_token [core::request::get -type cookie -name $CFG(csrf_cookie)]

	# We then call _execute_req_handler again, this time with the application
	# specific arguments and the mode to check against.
	set auth $PRE_HANDLERS(AUTH,app_handler)
	array set out [_execute_req_handler \
		$auth \
		$PRE_HANDLERS($auth,handler) \
		$PRE_HANDLERS($auth,args) \
		$mode]

	core::log::write INFO {CONTROLLER: AUTH status is $out(login_status)}

	# Personalise allows the developer to state that the request doesn't involve sensitive
	# data but they _may_ want to personalise the content returned if the details of the user are known
	if {$out(login_status) != "OB_OK" && $mode == {SECURE}} {
		error "Failed to authenticate user $out(login_status)"
	}

	# If the login is successful and the CSRF token hasnt already been set then
	# we want to set the CSRF token.
	if {$csrf_token == ""} {
		_set_csrf_cookie [_generate_csrf]
	}

	return
}

# CSRF Pre-Handler. This takes one parameter of action, like the other system
# pre-handlers. This is only valid when the request type has a session
# condition of UPDATE.
#
proc core::controller::_validate_csrf {action} {

	variable CFG
	variable ACTIONS
	variable REQ_TYPE_MATRIX

	# Now try and figure out whether we need run authentication for this request.
	# This is dependent on the action handlers resource condition
	set req_type $ACTIONS($action,req_type)
	lassign $REQ_TYPE_MATRIX($req_type) sess trans http res default_x_frame_opt

	if {$res != "UPDATE"} {
		return
	}

	# CSRF is to ensure integrity of the request ORIGIN. The existing double submit check method
	# may not be a best fit approach to integrate with some crossdomain apps. So added ORIGIN_CHECK.
	if {$CFG(csrf_check_type) == "ORIGIN_CHECK"} {
		_validate_csrf_origin_check
	} else {
		_validate_csrf_double_submit
	}

	return
}


# For application those are not relying on cookies for authentication/ authorization
# and for those who integrate with cross domain applications ...
# Instead we can try to ensure integrity by checking ORIGIN http header.
proc core::controller::_validate_csrf_origin_check {} {

	variable CFG

	set http_origin            [core::request::get -type header -name HTTP_ORIGIN]
	set csrf_allowed_origins   $CFG(csrf_allowed_origins)

	core::log::write INFO {CONTROLLER: _validate_csrf_origin_check http_origin=$http_origin csrf_allowed_origins=$csrf_allowed_origins}

	if {$http_origin != "" && [lsearch $csrf_allowed_origins $http_origin] != -1} {
		core::view::add_header\
			-name  "Access-Control-Allow-Origin"\
			-value $http_origin
	} else {
		error "Failed to verify ORIGIN; therefore not allowed"
	}

	return
}



# Ok we intend to update something in the Database, so therefore we must pass
# the CSRF check. This means a request argument must exist in a form POST, and
# the OB_REQ cookie must also be present. Both these values should be
# identical to each other, and when decrypted must contain the string CSRF in
# a specific position in the string.
proc core::controller::_validate_csrf_double_submit {} {

	variable CFG

	set cookie [core::request::get -type cookie -name $CFG(csrf_cookie)]
	set form   [core::request::get -type arg    -name $CFG(csrf_form)]

	# Cookie & Form fields need to be identical
	if {[string length $cookie] == 0} {
		error "CSRF Cookie is blank"
	}

	# By implication of the check just above, this makes sure that the form value
	# is also not blank
	if {$cookie != $form} {
		error "CSRF Cookie ($cookie) is not the same as CSRF Form value ($form)"
	}

	# The CSRF cookie is a 16 byte string.
	if {[string length $cookie] != 20} {
		error "CSRF Cookie ($cookie) is not of the correct length."
	}

	# The CSRF cookie is constructed of two elements, the first is an 8 byte or
	# 64-bit random number that has been base64 encoded so is 12 bytes in length
	# The second is a 4 byte or 32-bit CRC. We have a CRC to make it harder for a
	# third-party to generate a valid CSRF token. Of course they could guess this
	# (very) simple algorithm.
	set rnd [string range $cookie  0 15]
	set crc [string range $cookie 16 19]

	set calc_crc [_get_csrf_crc $rnd]

	if {$crc != $calc_crc} {
		error "CSRF Cookie fails CSRF check"
	}

	return
}

proc core::controller::_generate_csrf args {

	# We need to get a number of random bytes from /dev/urandom and then convert
	# the byte string to base64. We will get 8 bytes, which when convert to base64
	# will be 12 bytes long.
	set rnd [core::random::get_rand_hex -num_bytes 8]
	set crc [_get_csrf_crc $rnd]

	# The CSRF token is just the CRC appended to the random number. For now we
	# will take the first four bytes of a sha1 hash of the random number.
	return "${rnd}${crc}"
}

proc core::controller::_get_csrf_crc {rnd} {
	return [string range [sha1 $rnd] 0 3]
}



# Execute a specific pre-handler, post-handler or request handler. Setup its inputs,
# execute the handler and reset any inputs.
#
proc core::controller::_execute_req_handler {name handler handler_args args} {

	core::log::write DEBUG {CONTROLLER: _execute_req_handler name=$name handler=$handler}

	# Reset the Request API so other pre-handlers cannot see these arguments.
	core::request::reset

	# Populate the Request API with this pre-handlers arguments and then validate.
	core::request::populate -inputs $handler_args

	set v_errors [core::request::get_mandatory_errors]

	if {[llength $v_errors] > 0} {
		error "Error validating arguments for pre-handler $name. $v_errors"
	}

	# We now have validated all of the input for the pre-handler, so execute it.
	# Capture the output so that we can store it in the Request API for the
	# action handler to use.
	array set out [$handler {*}$args]

	# Reset the Request API so other pre-handlers cannot see these arguments.
	core::request::reset

	return [array get out]
}

#----------------------------------------------------------------------------
# Private Procedures
#----------------------------------------------------------------------------

proc core::controller::_validate_req_type {req_type} {

	variable REQ_TYPE_MATRIX

	# Req Type
	if {![info exists REQ_TYPE_MATRIX($req_type)]} {
		return 0
	}

	return 1
}

proc core::controller::_is_https args {

	variable CFG

	set https [core::request::get -type header -name HTTPS]
	set port  [core::request::get -type header -name SERVER_PORT]

	set x_header $CFG(trans_fwd_header)

	core::log::write DEBUG {CONTROLLER: _is_https https=$https port=$port x_header=$x_header}

	# Match using regular headers
	if {$https == "on" || [string match $CFG(ssl_port) $port]} {
		return 1
	}

	# Regular and X Headers aren't available so we aren't over https
	if {$x_header == ""} {
		return 0
	}

	# If the x headers are available and match we are over https
	if {[core::request::get -type header -name $x_header] == $CFG(trans_fwd_header_value)} {
		return 1
	}

	# All https checks have failed. We must be http
	return 0
}

proc core::controller::_is_post args {

	set mthd [core::request::get -type header -name REQUEST_METHOD]

	core::log::write DEV {CONTROLLER: _is_post mthd=$mthd}

	if {$mthd != "POST"} {
		return 0
	}

	return 1
}

# Default pre-handler for determining the action to execute for this request.
proc core::controller::_get_action args {
	set action [core::request::get_action]
	return [list action $action]
}

proc core::controller::_set_csrf_cookie {val {expires {}}} {

	variable CFG

	core::view::set_cookie \
		-name      $CFG(csrf_cookie) \
		-value     $val \
		-path      $CFG(csrf_path) \
		-expires   $expires \
		-domain    $CFG(csrf_domain) \
		-http_only 0
}

proc core::controller::check_strict_mode {} {

	variable CFG
	if {[get_cfg -config strict_mode -default 0]} {
		error "This proc is not allowed in strict mode"
	}
}

# Creates replacements for base appserv procedures that should have already
# been renamed out of the way.
#
proc core::controller::_create_wrapper_procs {} {

	proc ::asGetAct args {
		::core::controller::check_strict_mode
		return [[core::controller::get_cfg -proc asGetAct] {*}$args]
	}

	proc ::asGetDefaultAction args {
		return [core::controller::get_cfg -config default_handler]
	}

	proc ::asGetReqInitProc args {
		::core::controller::check_strict_mode
		return [[core::controller::get_cfg -proc asGetReqInitProc] {*}$args]
	}

	proc ::asGetReqEndProc args {
		::core::controller::check_strict_mode
		return [[core::controller::get_cfg -proc asGetReqEndProc] {*}$args]
	}

	proc ::asSetAct args {
		::core::controller::check_strict_mode
		return [[core::controller::get_cfg -proc asSetAct] {*}$args]
	}

	proc ::asSetDefaultAction {name} {
		return [core::controller::set_cfg -config default_handler -value $name]
	}

	proc ::asSetReqInitProc {name} {
		error "CONTROLLER: asSetReqInitProc is disabled."
	}

	proc ::asSetReqEndProc {name} {
		error "CONTROLLER: asSetReqEndProc is disabled."
	}

	proc ::asSetAction args {
		variable core::controller::SET_ACTION

		set SET_ACTION $args

		return [[core::controller::get_cfg -proc asSetAction] {*}$args]
	}
}
