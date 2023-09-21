# $Id: transfer_user.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#====================================================
#
# These two procedures import_user and export_user are provided to allow
# a user logged into a sportsbook to log into the casino directly
# by clicking on a link in the sportsbook. The technique requires that
# the user have the same username/password in both the sportsbook and the
# casino and that these are kept in sync somehow.
#
# For example, in the sportsbook there will be a link with the
# action export_user. When a customer logged into the sportsbook clicks this
# link the export_user function in the sportsbook will generate a link like
#
# https://www.our_casino.com?action=import_user&user_string=STRING
#
# The import_user action in the casino (below) will decrypt the string,
# log the user in, and then perform whichever action is specified by the
# import_action parameter variable.
#
# BASIC or STRICT MODE
#
# This process can run in one of two modes; basic or strict. The basis mode employs
# a user_string in the format
#
# 		username|enc_password|YYYY-MM-DD HH:MM:SS
#
# This was the initial technique used and it is weaker than the most recent
# (strict) technique set out in import_user_strict. The reason that both
# basic and strict versions are present in this file is because two
# communicating systems might have to upgrade from basic to strict mode by
# setting TRANSFER_STRICT_UID to 1 and bouncing.  The strict mode uses the
# user_string format
#
# 		salt|username|enc_password|uid|YYYY-MM-DD HH:MM:SS|from|to
#
# which contains also contains a salt, a uid and a from field. The salt is
# just a 4 digit random number and is used to help obliterate any pattern in
# the ciphertext - you can ignore it. The "from" indicates which system the
# customer is arriving from, and is used to establish which uid in the
# database (in the table tCustUIDExt) to compare the customer's to. The uid
# operates on the same principle as the standard login uid. It increments, or
# somehow increases, with every attempt to login.  Consequently the generated
# user_string in strict mode can never be reused because on second and subsequent
# attempts to post the same string the uid embedded in the encrypted user_string will
# be recognised as having been used previously and it abort the login attempt.
# This prevents hackers reusing other customer's user_stings if they somehow
# acquired them.
#
# All systems communicating must have an textual identification like "SPORTS"
# or "CASINO" and there must be a corresponding row in tExtSystem for that
# system.

# Default functions are supplied to handle the succes and failure of an export
# action and for login. These can be over-ridden by calling set_default_handler


# Tables required
#	tExtSystem holds the list of recognised external systems
#	tCustUIDExt holds the counter for each customer transfered
#
# Multilingual messages
#	LOGIN_TRANSFER_MISSING           - the user_string is missing an element.
#	LOGIN_TRANSFER_TIMEOUT           - the timestamp in the user_string is too old.
#	LOGIN_TRANSFER_SEQUENCE_MISMATCH - the uid in the user_string has been used before.
#	LOGIN_TRANSFER_NOT_LOGGED_IN     - attempted to transfer login but not logged
#		in/expired.
#	LOGIN_TRANSFER_NO_TARGET_CFG     - there is no TRANSFER_URL_"X" cfg entry for
#		the target "X".
#	LOGIN_TRANSFER_NO_TARGET         - attempted to do an export without giving a target.
#	LOGIN_TRANSFER_NO_UID            - the user_string lacks a uid value.
#	LOGIN_TRANSFER_NO_TARGET         - there was no target arg supplied for the
#	export_user request.
#	LOGIN_TRANSFER_INVALID_SYSTEM    - the system does not exist in tExtSystem.
#	LOGIN_TRANSFER_FAIL_CHECK_UID    - failure while trying to check the uid in an import
#	LOGIN_TRANSFER_FAIL_GEN_UID      - failed to generate uid for export.
#	LOGIN_TRANSFER_EXPORT_BASIC      - error building export user_string in basic mode.
#	LOGIN_TRANSFER_TARGET_NOT_IN_DB  - the target is not present in tExtSystem
#	LOGIN_TRANSFER_TARGET_INACTIVE   - the target in tExtSystem is set to inactive (!=Y)
#	LOGIN_TRANSFER_INCORRECT_TO      - import_user in strict mode but the to parameter
#		in the user_string does not match the identifier
#		as the value set in TRANSFER_LOCATION_NAME
#
# Configuration
#	TRANSFER_LOCATION_NAME  name of host app, as in tExtSystem
#   DEFAULT_ACTION Default action to be used if this application is screens.
#   TRANSFER_CGI_URL The URL of the customers screens (CGI_URL).
#	TRANSFER_DECRYPT_TYPE blowfish decryption type
#	TRANSFER_DECRYPT_KEY blowfish decryption key
#	TRANSFER_STRICT_UID forces strict transfer when set to 1
#	TRANSFER_TIMEOUT_SECS allowable delay between current time and timestamp
#   LOGIN_COOKIE The name of the login cookie (IBS_Login).
#   LOGIN_COOKIE_PATH The path of the cookie (/).
#   NONSECURE_COOKIE The name of the non-secure cookie ("").
#   NONSECURE_COOKIE_PATH Path of the non-secure cookie (/).
#	DEFAULT_ACTION action to be called when no import_action is specified
#   TRANSFER_STRING Format string (action=import_user&user_string=%e&import_action=%i&popup=%p).
#   TRANSFER_URL_FROM_DB  Get the URL from the database, rather than config (0).
#
# Procedures
#	OB_transfer_user::init
#   OB_transfer_user::set_default_handler
#	OB_transfer_user::import_user
#	OB_transfer_user::export_user
#	OB_transfer_user::trans_log

# Dependencies
#
package require util_crypt 4.5

# Variables
#
namespace eval OB_transfer_user {
	variable HANDLER
	variable CFG
}



#------------------------------------------------------------------------------
# Initialisation
#------------------------------------------------------------------------------

# One time initialisation. Read defaults and prepare queries.
#
proc OB_transfer_user::init args {
	variable HANDLER
	variable CFG

	catch { unset HANDLER }
	catch { unset CFG }

	trans_log INFO
	# Initialise Dependencies
	ob_crypt::init

	# Initialise Dependencies
	ob_crypt::init

	#Handlers
	set HANDLER(EXPORT_SUCCESS_COMMAND) _default_export_success
	set HANDLER(EXPORT_FAILURE_COMMAND) _default_export_failure
	set HANDLER(IMPORT_SUCCESS_COMMAND) ""
	set HANDLER(IMPORT_FAILURE_COMMAND) _default_import_failure
	set HANDLER(LOGIN_COMMAND) _default_login_function
	set HANDLER(valid) { EXPORT_SUCCESS_COMMAND EXPORT_SUCCESS_FAILURE \
		IMPORT_SUCCESS_COMMAND IMPORT_FAILURE_COMAND LOGIN_COMMAND}

	#Required CFG Items
	set CFG(LOCATION_NAME) [OT_CfgGet TRANSFER_LOCATION_NAME ""]
	set CFG(DEFAULT_ACTION) [OT_CfgGet DEFAULT_ACTION ""]
	set CFG(CGI_URL) [OT_CfgGet TRANSFER_CGI_URL [OT_CfgGet CGI_URL ""]]
	set CFG(TRANSFER_DECRYPT_TYPE) [OT_CfgGet TRANSFER_DECRYPT_TYPE ""]
	set CFG(TRANSFER_DECRYPT_KEY) [OT_CfgGet TRANSFER_DECRYPT_KEY ""]
	set CFG(LOGIN_COOKIE) [OT_CfgGet LOGIN_COOKIE "IBS_Login"]
	set CFG(LOGIN_COOKIE_PATH) [OT_CfgGet LOGIN_COOKIE_PATH "/"]
	set CFG(NONSECURE_COOKIE) [OT_CfgGet NONSECURE_COOKIE ""]
	set CFG(NONSECURE_COOKIE_PATH) [OT_CfgGet NONSECURE_COOKIE_PATH "/" ]

	#Defaulted CFG Items
	set CFG(TRANSFER_STRICT_UID) [OT_CfgGet TRANSFER_STRICT_UID 0]
	set CFG(TRANSFER_TIMEOUT_SECS) [ OT_CfgGet TRANSFER_TIMEOUT_SECS 60 ]
	set CFG(TRANSFER_STRING) [OT_CfgGet TRANSFER_STRING \
		"action=import_user&user_string=%e&import_action=%i&popup=%p"]
	set CFG(ALT_DECRYPT_KEY_SYSTEMS)     [split [OT_CfgGet ALT_DECRYPT_KEY_SYSTEMS "" ] ',']
	set CFG(TRANSFER_URL_FROM_DB) [OT_CfgGet TRANSFER_URL_FROM_DB 0]

	# If we are running in OXi a lot of the useful customer screen
	# funcionality becomes really problematic. Shared TCL should almost
	# contain customer screens related functinality.
	#
	set CFG(IS_SCREENS) [expr {[OT_CfgGet CGI_URL ""] != ""}]


	# Override the configuration.
	#
	foreach {o v} $args {
		set n [string toupper [string trimleft $o -]]
		if {![info exists CFG($n)]} {
			error "Unknown argument '$o'"
		}
		set CFG($n) $v
	}

	if {$CFG(IS_SCREENS) && $CFG(CGI_URL) == ""} {
		error "If these are customer screens, then there must be a CGI_URL"
	}

	db_store_qry cust_id_from_username {
		select
			cust_id
		from
			tCustomer
		where
			username = ?
	}

	db_store_qry check_ext_uid_qry {
		execute procedure pCheckUIDExt (
			p_cust_id = ?,
			p_from = ?,
			p_uid = ?
		)
	}

	db_store_qry target_url_from_name {
		select
			url,
			active
		from
			tExtSystem
		where
			name = ?
	}
}



#
# Name: set_default_handler
# Args: handler name and the func to handle it
# Returns: 1 for success, 0 for failure
# Synopsis: Sets the default handlers for success and failure
#
proc OB_transfer_user::set_default_handler { handler func } {
	variable HANDLER

	trans_log INFO "$handler $func"

	if {[lsearch $HANDLER(valid) $handler ] == "-1"} {
		trans_log INFO "Unknown handler argument $handler"
		trans_log INFO "Valid handlers are $HANDLERS(valid)"
		return 0
	} else {
		variable $handler
		set HANDLER($handler) $func
		trans_log INFO "Set $func to handle $handler"
		return 1
	}
}


#
# Name: set_argument
# Args: arg_list
# Returns: nothing
# Synopsis: does a reqSetArg on the user_string argument passed in the url to overcome
#           the problem of decoding the '&' symbol as '&amp;'
#
proc OB_transfer_user::set_argument {arg_list} {

	set arg_list_length [llength $arg_list]
	set import_action_args ""
	for {set i 0} {$i < $arg_list_length} {incr i} {
		set element [lindex $arg_list $i]
		set element_len [string length $element]
		#gets the index of the '=' character
		set char_equal_idx [string first = $element]
		set arg [string range $element 0 [expr $char_equal_idx - 1]]
		if {[expr $element_len - $char_equal_idx] == 1} {
			set arg_value ""
		} else {
			set arg_value [string range $element [expr $char_equal_idx + 1] $element_len]
		}
		if {$arg == "user_string"} {
			reqSetArg $arg $arg_value
		} elseif {$arg == "import_action"} {
			append import_action_args $arg_value
		} else {
			append import_action_args "&$arg=$arg_value"
		}
	}
	reqSetArg import_action $import_action_args
	return
}


#
# Name: import_user
# Args: none
# Returns: nothing
# Synopsis: Effects a login for a user transfered from another app. This
# occurs in either basic mode (through import_user_basic) or strict mode
# (import_user_strict). The difference between the two is that the strict
# mode contains a uid to prevent the string being reused, and both source
# and destination apps are specified.
#
proc OB_transfer_user::import_user {{enc_string FROM_REQ}} {
	variable CFG

	if {[OT_CfgGet FUNC_DECODE_AMPERSAND 0]} {
		set requestURL [reqGetEnv REQUEST_URI]
		regsub -all {\&amp;} $requestURL {\&} requestURL
		set string_len [string length $requestURL]
		#gets the index of the '&' character
		set char_ampersand_idx [string first & $requestURL]
		set newRequestURL [string range $requestURL [expr $char_ampersand_idx + 1] $string_len]
		set arg_list [split $newRequestURL &]
		OB_transfer_user::set_argument $arg_list
	}

	if {$enc_string == "FROM_REQ"} {
		set enc_string [reqGetArg user_string]
	}
	set from           [reqGetArg from]


	trans_log INFO

	if { $enc_string != "" } {
		set ivec [string range $enc_string end-7 end]
		set enc_string [string range $enc_string 0 end-8]
		if { [lsearch $CFG(ALT_DECRYPT_KEY_SYSTEMS) $from] >= 0 } {
			trans_log DEBUG "$from is in CFG(ALT_DECRYPT_KEY_SYSTEMS) ($CFG(ALT_DECRYPT_KEY_SYSTEMS))"
			set user_string [_blowfish_decrypt $enc_string "hex" $from $ivec]
		} else {
			set user_string [_blowfish_decrypt $enc_string "hex" "" $ivec]
		}
	} else {
		set user_string ""
	}

	trans_log INFO "decrypted user_string : $user_string"

	set num_elements [llength [split $user_string '|']]

	set import_success [_import_user_strict $user_string]

	#Call the import_success function
	if { $import_success && [ info exists CFG(IMPORT_SUCCESS_COMMAND)] } {
		eval $CFG(IMPORT_SUCCESS_COMMAND)
	}
}


#
# Name: export_user
# Args: none, target is expected in the post field
# Retuns: nothing
# Synopsis: Prepares the login string to transfer a user to another site.
# Logsout by default unless logout=N is set
#
proc OB_transfer_user::export_user {{target FROM_REQ} {logout FROM_REQ} {import_action FROM_REQ}} {

	variable HANDLER
	variable CFG

	if {$target == "FROM_REQ"} {
		set target [ reqGetArg target ]
	}

	if {$logout == "FROM_REQ"} {
		set logout [ reqGetArg logout ]
	}

	if {$import_action == "FROM_REQ"} {
		set import_action [ reqGetArg import_action ]
	}

	trans_log INFO "=============================="
	trans_log INFO "Attempting to export login"
	trans_log INFO "target: $target"
	trans_log INFO "=============================="

	# Step 1 Build the url
	set status_list [_get_target_url [string toupper $target]]

	if {[lindex $status_list 0] == "OK"} {
		set url [lindex $status_list 1]
	} else {
		eval $HANDLER(EXPORT_FAILURE_COMMAND) [lindex $status_list 0]
		return
	}

	#Step 2  build the string
	set status_list [_build_export_string_strict $target]

	trans_log INFO "status_list is $status_list"

	if {[lindex $status_list 0] == "OK"} {
		set user_string [lindex $status_list 1]
	} else {
		trans_log INFO "export_user - Could not build user_string"
		eval $HANDLER(EXPORT_FAILURE_COMMAND) [lindex $status_list 0]
		return
	}

	# Generate ivec to be used in blowfish encryption
	set ivec [ob_crypt::generate_ivec [OT_CfgGet TRANSFER_IVEC_LENGTH 8]]

	# Encrypt the string
	if { $user_string != "" } {
		if { [lsearch $CFG(ALT_DECRYPT_KEY_SYSTEMS) $target] >= 0 } {
			set enc_string [_blowfish_encrypt $user_string $target $ivec]
			append enc_string $ivec
		} else {
			set enc_string [_blowfish_encrypt $user_string "" $ivec]
			append enc_string $ivec
		}
	} else {
		set enc_string ""
	}

	trans_log INFO "user_string = $user_string"
	trans_log INFO "blowfished user_string $enc_string"

	#Logout by default
	if {$CFG(IS_SCREENS)} {
		if { $logout != "N"  } {
			trans_log INFO "logging out user"

			set logout_cookie [obtrans_login::logout ]

			if { [ info exists CFG(LOGIN_COOKIE) ]} {
				set_cookie "$CFG(LOGIN_COOKIE)=$logout_cookie" $CFG(LOGIN_COOKIE_PATH)
			}

			if {[ info exists CFG(NONSECURE_COOKIE) ]} {
				set_cookie "$CFG(NONSECURE_COOKIE)=$logout_cookie" $CFG(NONSECURE_COOKIE_PATH)
			}

		}
	}

	#And evaluate the succes command
	return [$HANDLER(EXPORT_SUCCESS_COMMAND) $url $enc_string $import_action]
}



#
# Name: trans_log
# Args: level, statement
#
proc OB_transfer_user::trans_log { level {stmt ""} } {
	set current [expr [info level] - 1]
	set caller toplevel
	catch {
		 set caller [lindex [info level $current] 0]
	}

	OT_LogWrite $level "$caller $stmt"
}




#
# Name: import_user_strict
# Args: user_string
# Returns: nothing
# Synopsis: Stronger method of importing a user. Source and destination apps are
# specified, a uid is used to prevent man-in-the-middle resending and the
# timestamp is verified as well before login is attempted.
#
proc OB_transfer_user::_import_user_strict { user_string } {
	trans_log INFO "Attempting STRICT login"
	trans_log INFO " user_string is $user_string"

	if { $user_string == "" } {
		# we've not been given any magic login string so skip the login
		_do_import_finish
		return 1
	}

	# 1 - Parse the user_string

	# Find index of bar separators
	set user_string_list [split $user_string '|']

	set user_string_list_length [llength $user_string_list]
	trans_log INFO "user_string has $user_string_list_length elements"

	if { $user_string_list_length == "6" } {
	foreach {arg idx } {username 0 md5_pwd 1 uid 2 timestamp 3 from 4 to 5 } {
		set $arg [ lindex $user_string_list $idx ]

		if { [ set $arg ] == "" } {
			trans_log ERROR "* ERROR invalid string format for strict login: $user_string"
			trans_log ERROR "- should be username|md5_password|uid|YYYY-MM-DD HH:MM:SS|from|to"
				trans_log ERROR "- or username|oxi-token|uid|YYYY-MM-DD HH:MM:SS|from|to"
			_display_login_failure "LOGIN_TRANSFER_MISSING"
				return 0
			}
		}

	} elseif { $user_string_list_length == "5" } {
		#if the user string has only 6 elements, then we're expecting cookie|uid|timestamp|from|to
		# But for convenience sake we'll refer to the cookie as "md5_pwd" for now
		foreach { arg idx } { md5_pwd 0 uid 1 timestamp 2 from 3 to 4 } {
			set $arg [ lindex $user_string_list $idx ]

			if { [ set $arg ] == "" } {
				trans_log ERROR "* ERROR invalid string format for strict login: $user_string"
				trans_log ERROR "- should be username|md5_password|uid|YYYY-MM-DD HH:MM:SS|from|to"
				trans_log ERROR "- or oxi-token|uid|YYYY-MM-DD HH:MM:SS|from|to"
				_display_login_failure "LOGIN_TRANSFER_MISSING"
				return 0
			}
		}
		if { [ lsearch $CFG(TRANSFER_STRICT_USE_COOKIES) $from ] == -1 } {
			trans_log ERROR "* ERROR : invalid string format: $user_string"
			trans_log ERROR "- sender should be in TRANSFER_STRICT_USE_COOKIES or"
			trans_log ERROR "- user_string should have more elements"
			_display_login_failure "LOGIN_TRANSFER_MISSING"
			return 0
		}

	} else {
		trans_log ERROR "* ERROR : import string has wrong number of elements : $user_string_list_length\nstring: $user_string"
		_display_login_failure "LOGIN_TRANSFER_MISSING"
		return 0
	}

	if { [lsearch $CFG(TRANSFER_STRICT_USE_COOKIES) $from ] != -1 } {
	# check if we're expecting the user_string to contain a cookie rather than a password
		trans_log INFO "DEBUG: Using standard crypt keys"
		set key_type $CFG(TRANSFER_DECRYPT_TYPE)
		set key $CFG(TRANSFER_DECRYPT_KEY)
		set crypt_base "b64"
		set logged_out_str $CFG(CUST_LOGGED_OUT_STR)
		set cookie_fmt $CFG(CUST_LOGIN_COOKIE_FMT)


		if [catch { array set COOKIE_RESULT [ob_cookie::decrypt \
							cookie $md5_pwd \
							key_type $key_type \
							key $key \
							crypt_base $crypt_base \
							logged_out_str $logged_out_str \
							cookie_fmt $cookie_fmt \
						] } msg ] {
			trans_log INFO "Decrypt of cookie failed : $msg"

		# if decryption of the cookie fails, go with login failure
		} elseif { $COOKIE_RESULT(status) != "OB_OK"} {

			trans_log INFO "Decryption of cookie failed: $COOKIE_RESULT(status)"
			_display_login_failure "$COOKIE_RESULT(status)"
			return 0

		} elseif { $COOKIE_RESULT(type) == "N" } {
			set md5_pwd $COOKIE_RESULT(pin)

		} elseif {$COOKIE_RESULT(type) == "W" } {
			set md5_pwd $COOKIE_RESULT(pwd)
		}

		# if we've only got 6 elements, we don't have the username yet
		if { $user_string_list_length == "5" } {
			set username [_get_username_for_cust_id $COOKIE_RESULT(cust_id)]
			if { $username == -1 } {
				trans_log ERROR "Invalid Cookie: Couldn't find username"
				_display_login_failure "LOGIN_TRANSFER_MISSING"
				return 0
			}
		}
	}

	trans_log INFO "====== strict mode ==========================="
	trans_log INFO "username     >$username<"
	trans_log INFO "enc_password >$md5_pwd<"
	trans_log INFO "timestamp    >$timestamp<"
	trans_log INFO "uid          >$uid<"
	trans_log INFO "from         >$from<"
	trans_log INFO "to           >$to<"
	trans_log INFO "=============================================="

	# 2 - Check uid
	trans_log INFO "_import_user_strict - check_ext_uid username : $username, uid : $uid, from $from ..."

	set status [_check_ext_uid $username $uid $from $to]

	if {$status != "OK"} {
		trans_log ERROR "- ERROR - Login uid check was failed with uid ($uid). status : $status"
		_display_login_failure "$status"
		return 0
	}

	# 3 - Check Timestamp
	set status [_check_timestamp $timestamp]

	if {$status != "OK" } {
		_display_login_failure "$status"
		return	 0
	}

	# 4 - Attempt login
	set login_status [ _do_transfer_login $username $md5_pwd ]

	if {$login_status != "OB_OK"} {
		_display_login_failure $login_status
		return 0
	} else {
		_do_import_finish
		return 1
	}
}



#
# Name: default_import_failure
# Args: error_code
# Returns: nothing
# Synopsis: Default function for import failure - plays the default action
#
proc OB_transfer_user::_default_import_failure { error_code } {
	variable CFG

	if {!$CFG(IS_SCREENS)} {
		error $error_code
	}

	tpSetVar ERROR "$error_code"
	trans_log INFO "Calling the default action"
	_play_redirect "$CFG(CGI_URL)?action=$CFG(DEFAULT_ACTION)"
}



#
# Name: _default_export_success
# Synopsis: Called by export_user on succesful string creation.
#	Can be replaced so it can be specifically tailored
#
# The default solution below will play a specified page in a popup window,
# or the default in a popup window, or just use the default action if it is
# called from the main window
#
proc OB_transfer_user::_default_export_success {url {enc_string ""} {import_action FROM_REQ} {transfer_page FROM_REQ} {popup FROM_REQ}} {
	variable CFG
	variable HANDLER

	trans_log INFO

	if {$import_action == "FROM_REQ"} {
		set import_action [ reqGetArg import_action]
	}

	if {$popup == "FROM_REQ"} {
		set popup [ reqGetArg popup ]
	}

	# %a = import action
	# %e = enc_string
	# %p = popup

	if {[string first ? $url] == -1} {
		append url ?
	}

	set transfer_string $url$CFG(TRANSFER_STRING)

	regsub -all {%i} $transfer_string ${import_action} transfer_string
	regsub -all {%e} $transfer_string ${enc_string} transfer_string
	regsub -all {%p} $transfer_string ${popup} transfer_string

	trans_log "transfer_string=$transfer_string"

	return $transfer_string
}




#
# Name: _default_export_failure
# Synopsis: Called by export_user on failure.
#	Can be replaced so it can be specifically tailored.
#
# Below just goes to the home page
#
proc OB_transfer_user::_default_export_failure {arg} {
	variable CFG

	if {!$CFG(IS_SCREENS)} {
		error $arg
	}

	trans_log INFO "Evaluating $CFG(DEFAULT_ACTION)"

	tpSetVar $arg 1
	eval $CFG(DEFAULT_ACTION)
}


#
# Name: _default_login_function
# Args: username and enc_pwd
# Returns: nothing
# Synospis: Default login function - this one is based on bsq
#
proc OB_transfer_user::_default_login_function { username enc_pwd } {
	global LOGIN_DETAILS

	trans_log INFO "username: $username enc_pwd $enc_pwd"

	reqSetArg tbUsername $username
	reqSetArg tbPassword $enc_pwd
	reqSetArg FormName "fmLogin"
	reqSetArg loginUID [OB_login::get_login_uid]
	reqSetArg pwd_encrypted "Y"

	# we must be sure that the cookie is set, in case the
	# user logs into BSQC, transfers to BSQ/MG then from
	# there immediately transfers to MG/BSQ.
	OB_login::ob_check_login -reset-cookie

	# we need to be sure that the login status is updated
	# this is set in init.tcl before import user is called...
	tpSetVar login_status $LOGIN_DETAILS(LOGIN_STATUS)
	return $LOGIN_DETAILS(LOGIN_STATUS)
}



#
# Name: _build_export_string_strict
# Args: destination site
# Returns: two element list, first is function success, second the string
# Synopsis: Creates the string to transfer a user using the strict method
# where source and dest are specified and a db lookup occurs.
#
proc OB_transfer_user::_build_export_string_strict { to  {guest_ok FROM_REQ}} {
	global LOGIN_DETAILS
	variable CFG

	if {$guest_ok == "FROM_REQ"} {
		set guest_ok [ reqGetArg guest_ok ]
	}

	trans_log INFO "to: $to"

	#Deal with guests
	if {[OB_login::ob_is_guest_user] } {
		trans_log INFO "Guest User"

		if { $guest_ok == "Y"} {
			return [list "OK" ""]
		} else {
			trans_log INFO "Guests Not Supported"
			return [list "LOGIN_TRANSFER_NOT_LOGGED_IN" ""]
		}
	}

	if [catch {
		set username $LOGIN_DETAILS(USERNAME)

		if { $LOGIN_DETAILS(LOGIN_TYPE) == "PASSWD" } {
			set enc_pwd $LOGIN_DETAILS(ENC_PASSWORD)
		} else {
			set enc_pwd $LOGIN_DETAILS(PIN)
		}

		set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S" -gmt 1]
	} msg ] {
		trans_log ERROR "* Error :$msg"
		return [list "LOGIN_TRANSFER_EXPORT_STRICT" ""]
	}

	# Generate a login uid for this system
	set status_list [_get_xfer_uid]

	if {[lindex $status_list 0] == "OK"} {
		set uid [lindex $status_list 1]
		trans_log INFO "got uid ok - $uid ."
	} else {
		# Pass the error back up to export_user
		trans_log INFO "failed to generate uid."
		return [list [lindex $status_list 0] ""]
	}

	# The name of this system
	set from $CFG(LOCATION_NAME)

	# Build the string
	trans_log INFO "built string successfully"

	return [list "OK" "$username|$enc_pwd|$uid|$timestamp|$from|$to"]
}



#
# Name: _do_transfer_login
# Args: username and enc_pwd
# Returns: Nothing
# Synopsis: takes a username, password and calls the login proc
#
proc OB_transfer_user::_do_transfer_login { username enc_pwd} {
	variable HANDLER

	trans_log INFO "username $username enc_pwd $enc_pwd"

	return [ eval  $HANDLER(LOGIN_COMMAND) $username $enc_pwd ]
}



#
# Name:_ do_import_finish
# Args: None
# Returns: Nothing
# Synopsis: Parses the import_action at the end of a succesful import
#
proc OB_transfer_user::_do_import_finish {} {
	set import_action [reqGetArg import_action]

	trans_log INFO "import_action = $import_action... (code [asGetAct $import_action])"

	_parse_import_action $import_action
}



#
# Name: display_login_failure
# Args: an error code
# Returns: Nothing
# Synopsis: Sets an error code and calls the default action handler when
# an attempt to import a user fails.
#
proc OB_transfer_user::_display_login_failure {error_code } {
	variable HANDLER

	trans_log INFO

	eval $HANDLER(IMPORT_FAILURE_COMMAND) $error_code
}



#
# Name: _blowfish_decrypt
# Args: string: the string to encrypted
#	encoding (optional; def "hex") : the encoding the string is in (ie hex | bin | b64)
#	alt_key_name (optional; def: "") : the name of the system which this is being encrypted
#		for, which is used to get the key and type from CFG
# returns: string, encrypted using the global key or the key specific to the system $alt_key_name
#
proc OB_transfer_user::_blowfish_decrypt { string { encoding "hex" } { alt_key_name "" } {ivec ""}} {

	variable CFG
	# may need to use an alternative crypt key/type if dealing with a 3rd party company

	trans_log DEBUG "alt_key_name = $alt_key_name ; string = $string ; \
			ivec = $ivec ; encoding = $encoding"

	if { $alt_key_name != "" } {
		set alt_key_name [string toupper $alt_key_name]
		set key_type $CFG(TRANSFER_DECRYPT_TYPE_$alt_key_name)
		set crypt_key $CFG(TRANSFER_DECRYPT_KEY_$alt_key_name)
	} else {
		set key_type $CFG(TRANSFER_DECRYPT_TYPE)
		set crypt_key $CFG(TRANSFER_DECRYPT_KEY)
	}

	if {$ivec == ""} {
		trans_log DEBUG "key = $crypt_key; key_type = $key_type; string = $string"
		if [catch {set user_string [blowfish decrypt -$key_type $crypt_key -$encoding $string]} msg] {
			trans_log ERROR "* ERROR - blowfish decrypt could not decrypt the string : $string : $msg."
			return ""
		}
	} else {
		trans_log DEBUG "key = $crypt_key; key_type = $key_type; string = $string; ivec = $ivec"
		if [catch {set user_string [blowfish decrypt -bin $ivec -$key_type $crypt_key -$encoding $string]} msg] {
			trans_log ERROR "* ERROR - blowfish decrypt could not decrypt the string : $string : $msg."
			return ""
		}
	}
	trans_log DEBUG "decrypted user_string : $user_string"

	if [catch {set user_string [hextobin $user_string] } msg] {
		trans_log ERROR "* ERROR - blowfish decrypt could not hextobin the string : $string : $msg."
		return ""
	}

	trans_log INFO "user_string = $user_string"
	return $user_string
}



#
#Name: _blowfish_encrypt
#
proc OB_transfer_user::_blowfish_encrypt {string { alt_key_name "" } { ivec ""} } {

	variable CFG

	# we need to check here the intended context of the encrypted string:
	# we may need to use a different encryption key if it's a 3rd party company
	# This key will be stored at CFG(TRANSFER_DECRYPT_KEY_<system>, and it's respective
	# type at CFG(TRANSFER_DECRYPT_TYPE_<system>
	#

	if { $alt_key_name != "" } {

		set alt_key_name [string toupper $alt_key_name]
		set key_type $CFG(TRANSFER_DECRYPT_TYPE_$alt_key_name)
		set crypt_key $CFG(TRANSFER_DECRYPT_KEY_$alt_key_name)
	} else {

		set key_type $CFG(TRANSFER_DECRYPT_TYPE)
		set crypt_key $CFG(TRANSFER_DECRYPT_KEY)
	}

	if {$ivec == ""} {
		trans_log DEBUG "key = $crypt_key; key_type = $key_type; string = $string"
		set user_string [blowfish encrypt -$key_type $crypt_key -bin $string]
	} else {
		trans_log DEBUG "key = $crypt_key; key_type = $key_type; string = $string; ivec = $ivec"

		set user_string [blowfish encrypt -bin $ivec -$key_type $crypt_key -bin $string]
	}

	trans_log DEBUG "encrypted string: $user_string"

	return $user_string
}



#
# Name: _check_timestamp
#
proc OB_transfer_user::_check_timestamp {in_timestamp} {
	variable CFG
	# Timestamp checking. The timestamp in the url must not be later than the
	# (time on the referring server + TRANSFER_TIMEOUT_SECS seconds)

	trans_log INFO "in_timestamp = $in_timestamp"

	# Check the date is in YYYY-MM-DD HH:MM:SS format.
	if {![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$} $in_timestamp]} {
		trans_log ERROR "* ERROR - imported timestamp ($in_timestamp) invalid format, should be YYYY-MM-DD HH:MM:SS."
		return "LOGIN_TRANSFER_TIMEOUT"
	}

	# Convert to clock seconds so we can compare against present time easily.
	if [catch {set timestamp_sec [clock scan "$in_timestamp" -gmt 1]} msg] {
		trans_log ERROR "* ERROR - imported timestamp ($in_timestamp) invalid format"
		return "LOGIN_TRANSFER_TIMEOUT"
	}

	set timeout_sec $CFG(TRANSFER_TIMEOUT_SECS)
	set now_sec [clock seconds]
	set now [clock format $now_sec -format "%Y-%m-%d %H:%M:%S" -gmt 1]
	set elapsed_sec [expr abs([expr $now_sec - $timestamp_sec])]

	if {$elapsed_sec < $timeout_sec } {
		# Timestamp OK - attempt login.
		trans_log INFO "timestamp OK"
		trans_log INFO "time at login     : $now"
		trans_log INFO "timestamp in url  : $in_timestamp"
		trans_log INFO "elapsed time      : $elapsed_sec"
		trans_log INFO "timeout limit     : $timeout_sec seconds"
		return "OK"
	} else {
		# Timestamp too old - display login screen.
		trans_log INFO "* WARNING timestamp in url too old"
		trans_log INFO "time at login     : $now"
		trans_log INFO "timestamp in url  : $in_timestamp"
		trans_log INFO "elapsed time      : $elapsed_sec seconds"
		trans_log INFO "timeout limit     : $timeout_sec seconds"
		return "LOGIN_TRANSFER_TIMEOUT"
	}
}



#
# Name: _check_ext_uid
#
proc OB_transfer_user::_check_ext_uid {in_username in_uid in_from in_to} {
	variable CFG

	# Get the customer_id
	trans_log INFO "in_username = $in_username in_uid = $in_uid"
	trans_log INFO "in_from = $in_from in_to = $in_to"

	if {$in_to != $CFG(LOCATION_NAME)} {
		trans_log ERROR "* ERROR string not intended for this site: to='$in_to'"
		return "LOGIN_TRANSFER_INVALID_SYSTEM"
	}

	set cust_id [_get_cust_id_for_username $in_username]

	# Using the cust_id see whether there is a uid in existence,
	# to test against.
	trans_log INFO "cust_id = $cust_id"

	if {$cust_id < 1} {
		trans_log ERROR "* ERROR invalid cust_id returned from get_cust_id_for_username : $cust_id"
		return "FAIL"
	} else {

		# Check the uid against the customer's row in tCustUIDExt
		if {[catch {db_exec_qry check_ext_uid_qry $cust_id $in_from $in_uid} msg]} {
			# Diagnose the error - probably either foreign key constraint
			# or login sequence error.
			trans_log ERROR "* ERROR Check uid unsuccessful - $msg"

			if {[string first "XFER_SEQUENCE" $msg]!=-1} {
				trans_log ERROR "* ERROR Login sequence error"
				return "LOGIN_TRANSFER_SEQUENCE_MISMATCH"
			} elseif {[string first "ccustuidxfer_f2" $msg]!=-1} {
				trans_log ERROR "* ERROR Unrecognised system - probably no row for $in_from in tExtSystem."
				return "LOGIN_TRANSFER_INVALID_SYSTEM"
			} else {
				trans_log ERROR "*ERROR in query check_ext_uid."
				return "LOGIN_TRANSFER_FAIL_CHECK_UID"
			}
		} else {
			trans_log INFO "Check uid ($in_uid) successful."
			return "OK"
		}
	}
}



#
# Name: _get_cust_id_for_username
# Args: username
# Returns: cust_id or -1
# Synopsis: Returns the cust_id associated with username or -1
#	if it doesnt exists or an error occurs.
#
proc OB_transfer_user::_get_cust_id_for_username {in_username} {
	trans_log INFO "in_username = $in_username"

	if [catch {set rs [db_exec_qry cust_id_from_username $in_username]} msg] {
		trans_log  ERROR "* ERROR Unable to retrieve cust_id :$msg"
		return -1
	}

	if { [ db_get_nrows $rs ] == 1 } {
		set cust_id [db_get_col $rs 0 cust_id]
		db_close $rs
		return $cust_id
	} else {
		db_close $rs
		trans_log ERROR "* ERROR Unable to retrieve cust_id for username $in_username - zero rows"
		return -1
	}
}



#
# Name: _parse_import_action
# Args: import_action
# Returns: nothing
# Synopsis: decodes an imported import action into argument/value pairs
# and then calls the action specified.
#
proc OB_transfer_user::_parse_import_action {import_action} {
	variable CFG

	trans_log INFO

	set redirect_url $CFG(CGI_URL)
	set pairs [split $import_action {@}]
	set pair_count 0

	foreach pair $pairs {

		set els [split $pair {~}]

		if { [llength $els] == 2 } {
			set arg [lindex $els 0]
			set val [lindex $els 1]
		} elseif { $pair_count == 0 && [llength $els] < 2 && [lindex $els 0] != "" } {
			set arg "action"
			set val [lindex $els 0]
		}

		if {$pair_count == 0} {
			append redirect_url "?"
		} else {
			append redirect_url "&"
		}

		append redirect_url "$arg=$val"
		incr pair_count
	}

	if { $redirect_url == $CFG(CGI_URL)} {
		append redirect_url "?action=$CFG(DEFAULT_ACTION)"
	}

	trans_log INFO "Parsed '$import_action'"

	if {$CFG(IS_SCREENS)} {
		_play_redirect $redirect_url
	}

	return $redirect_url
}



#
# Name: _play_redirect
# Args: redirect_url
# Returns: nothing
# Synopsis: Redirects the current page to redirect_url by creating
# a page that automatically changes to redirect_url
#
proc OB_transfer_user::_play_redirect {redirect_url } {

	trans_log INFO

	if { $redirect_url != "" } {
		trans_log INFO "Redirecting to $redirect_url"
	} else {
		trans_log INFO "Pllaying default error page"
	}

	#In order to avoid bundling an html file with this code
	#We just play out a basic html file to do the redirect
	tpBufAddHdr "Content-Type" "text/html"
	tpBufWrite "<html>\n"
	tpBufWrite "\t<head>\n"
	tpBufWrite "\t\t<script language='javascript'>\n"
	tpBufWrite "\t\t<!--\n"
	tpBufWrite "\t\t\t function reload() { \n"
	tpBufWrite "\t\t\t\t top.location.href='$redirect_url'\n"
	tpBufWrite "\t\t\t}\n"
	tpBufWrite "\t\t//-->\n"
	tpBufWrite "\t\t</script>\n"
	tpBufWrite "\t</head>\n"

	if { $redirect_url == "" } {
		tpBufWrite "\t<body>\n"
		tpBufWrite "\t\t An error occured. We were unable to transfer you.\n"
	} else {
		tpBufWrite "\t<body onload='reload()'>\n"
	}

	tpBufWrite "\t</body>\n"
	tpBufWrite "</html>\n"
}



#
# Name: _get_target_url
# Args: in_target
# Returns a two element list, the first indicates success, the 2nd the url
# Synopsis: Returns a url associated with in_target. In strict mode it takes
# the url from the db (tExtSystem), in basic mode it takes it from the
# config setting TRANSFER_URL_(in_target)
#
proc OB_transfer_user::_get_target_url {in_target} {
	variable CFG

	trans_log INFO "in_target = $in_target"

	if {$CFG(TRANSFER_URL_FROM_DB) || $CFG(TRANSFER_STRICT_UID)} {

		# STRICT mode - get target url from database
		if {[catch {set rs [db_exec_qry target_url_from_name $in_target]} msg]} {
			trans_log ERROR "* ERROR Query target_url_from_name failed : $msg."
			return [list "LOGIN_TRANSFER_TARGET_NOT_IN_DB" ""]
		} else {

			# Sanity check there is only a single row.
			set num_rows [db_get_nrows $rs]

			if {$num_rows!=1} {
				db_close $rs
				trans_log ERROR "* ERROR Unable to retrieve url for target $in_target - $num_rows rows."
				return [list "LOGIN_TRANSFER_TARGET_NOT_IN_DB" ""]
			}

			# Check that the system is active.
			set active [db_get_col $rs 0 active]

			if {$active != "Y"} {
				db_close $rs
				trans_log ERROR "* ERROR Target $in_target is not set to active (Y) in tExtSystem."
				return [list "LOGIN_TRANSFER_TARGET_INACTIVE" ""]
			}

			set url [db_get_col $rs 0 url]
			db_close $rs

			# Success - return the url
			trans_log INFO " Success  - url is $url"
			return [list "OK" $url]
		}
	} else {
		# BASIC mode : get target url from config file ...

		if {$in_target == ""} {
			trans_log ERROR "* WARNING - No target site parameter passed to export_user in url."
			return [list "LOGIN_TRANSFER_NO_TARGET" ""]
		} else {
			set target_cfg  TRANSFER_URL_[string toupper $in_target]
			set target_url [OT_CfgGet $target_cfg ""]

			if {$target_url == ""} {
				trans_log ERROR "* WARNING - no $target_cfg config setting available for target ($in_target)."
				return [list "LOGIN_TRANSFER_NO_TARGET_CFG" ""]
			} else {
				set url "$target_url"
				trans_log INFO "Success - setting target_url $target_url"

				# Success - return the url
				return [list "OK" $url]
			}
		}
	}
}



#
# Name: _get_xfer_uid
# Args: None
# Returns: 2 element list : OK/error_code & uid
# Synopsis: Procedure to generate a uid in include in the user_string when
# logging a customer into another site. This is called from export_user,
# when running in strict mode.
#
proc OB_transfer_user::_get_xfer_uid {} {

	# Get the customer_id
	trans_log INFO

	set uid [ OB_login::get_login_uid ]

	if {$uid <0} {
		trans_log INFO "Generated uid < 0"
		return [list "LOGIN_TRANSFER_NO_UID" ""]
	} else {
		trans_log INFO "uid successful - $uid"
		return [list "OK" $uid]
	}
}
