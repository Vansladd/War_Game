# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Provide symbolic level logging.
# The OT_LogWrite log level is replaced by a symbolic name which provides a
# consistent set of leg levels throughout an application.
#
# Symbolic levels:
#
#    CRITICAL (1)          Critical application failure (highest level)
#    ERROR    (2)          Transaction/Request error
#    WARNING  (4)          Warning notification
#    INFO     (8)          Information notification
#    DEBUG    (10)         Debug message.
#    DEV      (15)         Development message (lowest level)
#
# Each symbolic level is associated with a log level number, as denoted in
# brackets above, however, can be altered via a configuration value.
#
# Log level overrides allow you to override the default logging levels. You
# can specify in two ways, firstly you can use LOG_LEVEL_OVERRIDES to
# set a list of overrides, or you can specify each override separately.
# Overrides are applied sequentially, later item in the list override earlier
# ones.
#
#    LOG_OVERRIDES = ?pattern symbolic_level match_type...?
#    match_type may be
#      ANY   -> any part of the call stack is matched
#      EXACT -> only the procedure is matched
#
#  Examples:
#    Have procedures in ob_db which logging at at DEBUG level.
#
#    LOG_OVERRIDES = * INFO ANY ob_db::* DEBUG EXACT
#
#    Have procedures both in and called by ob_admin_login logged at DEBUG level.
#
#    LOG_OVERRIDES = * INFO ANY ob_admin_login::* DEBUG ANY
#
# For the following you appserver must support 'OT_CfgGetNames'.
#
#    Log anything in req_init at INFO level.
#
#    LOG_OVERRIDE.req_init = INFO
#
#    Log anything in and called by procedures in ob_admin_login.
#
#    LOG_OVERRIDE.ob_admin_login::* = DEV ANY
#
# Note:
#    To utilise overrides, you must ensure that LOG_SYMLEVEL and LOG_LEVEL are
#    set to all the levels you are interested in (e.g. DEV and 15).
# Configuration:
#    LOG_DIR                 log directory
#    LOG_FILE                log filename
#    LOG_ROTATION            log rotation frequency
#    LOG_MODE                log mode
#    LOG_SYMLEVEL            symbolic log level (INFO)
#    LOG_LEVEL_CRITICAL      critical log level  (1)
#    LOG_LEVEL_ERROR         error log level    (2)
#    LOG_LEVEL_WARNING       warning log level  (4)
#    LOG_LEVEL_INFO          info log level     (8)
#    LOG_LEVEL_DEBUG         debug log level    (10)
#    LOG_LEVEL_DEV           dev log level      (15)
#    LOG_OVERRIDE            allow level overriding (0)
#    LOG_OVERRIDES           list of level overrides if the format
#                            '?pattern level match_type...?'
#    LOG_OVERRIDE_.*         specific override 'level ?match_type?'
#    LOG_MASK                log mask ("")
#    LOG_TS_DIR              timestamp log directory
#    LOG_TS_FILE             timestamp log file
#
#

set pkg_version 1.0

package provide core::log $pkg_version

# Dependencies
package require Tcl         8.4
package require core::args  1.0
package require core::check 1.0

namespace eval core::log {
	variable CFG
	variable LOG_FD "default"
	variable TERM

	set TERM(white)  "1;37;40"
	set TERM(red)    "1;31"
	set TERM(green)  "1;32"
	set TERM(yellow) "1;33"
	set TERM(blue)   "1;34"
	set TERM(purple) "1;35"
	set TERM(cyan)   "1;36"

	set CFG(init)     0
	set CFG(override) 0
	set CFG(colour)   0
	set CFG(log_file) stdout
}

core::args::register_ns \
	-namespace core::log \
	-version   $pkg_version \
	-dependent [list core::check core::args] \
	-docs      foundation/log.xml


# One-time initialisation on a log file descriptor.
# Sets the symbolic log level names and the symbolic log level, taking the
# information from a configuration file.
#
# @param -log_fd  log file descriptor
#
# @return nothing
#

core::args::register \
	-proc_name core::log::init \
	-args [list \
		[list -arg -log_fd     -mand 0 -check ASCII                            -default {default}     -desc {Log file descriptor}] \
		[list -arg -log_dir    -mand 0 -check STRING -default_cfg LOG_DIR      -default {.}           -desc {Log directory}] \
		[list -arg -log_file   -mand 0 -check STRING -default_cfg LOG_FILE     -default {logfile.log} -desc {Log filename}] \
		[list -arg -strict     -mand 0 -check BOOL   -default_cfg LOG_STRICT   -default 0             -desc {Don't allow command substitution within a log line}] \
		[list -arg -standalone -mand 0 -check BOOL                             -default 0             -desc {Allows applications which do not support, or use, configuration files to use this package. This is a replacement for the old sl_init procedure which has been deprecated.}] \
		[list -arg -rotation   -mand 0 -check ASCII  -default_cfg LOG_ROTATION -default DAY           -desc {Log rotation}] \
		[list -arg -mode       -mand 0 -check ASCII  -default_cfg LOG_MODE     -default APPEND        -desc {Log mode}] \
		[list -arg -level      -mand 0 -check ASCII  -default_cfg LOG_LEVEL    -default 100           -desc {Log level}] \
		[list -arg -symlevel   -mand 0 -check ASCII  -default_cfg LOG_SYMLEVEL -default INFO          -desc {Symbolic Log level}] \
		[list -arg -level_map  -mand 0 -check ASCII                            -default { \
			CRITICAL 1 \
			ERROR    2 \
			WARNING  4 \
			INFO     8 \
			DEBUG    10 \
			DEV      15 \
		} -desc {List of symbolic levels and their corresponding numerical level}] \
		[list -arg -autoflush        -mand 0 -check BOOL                              -default 1   -desc {Auto flush the logs}] \
		[list -arg -mask             -mand 0 -check STRING -default_cfg LOG_MASK      -default {}  -desc {list of arguments which are masked (value replaced with '****')}] \
		[list -arg -override         -mand 0 -check BOOL   -default_cfg LOG_OVERRIDE  -default 0   -desc {}] \
		[list -arg -overrides        -mand 0 -check STRING -default_cfg LOG_OVERRIDES -default {}  -desc {}] \
		[list -arg -ts_file          -mand 0 -check STRING -default_cfg LOG_TS_FILE   -default {}  -desc {Log timestamp and the current log file to a separate file for later analysis}] \
		[list -arg -ts_dir           -mand 0 -check STRING -default_cfg LOG_TS_DIR    -default {}  -desc {Log timestamp directory}] \
		[list -arg -colour_override  -mand 0 -check ASCII                             -default {}  -desc {List of colour name and escape codes}] \
	]

proc core::log::init args {

	variable LOG_FD
	variable CFG
	variable TERM

	array set ARGS [core::args::check core::log::init {*}$args]

	set log_fd $ARGS(-log_fd)

	# package initialised?
	if {$CFG(init)} {
		return
	}

	# init log file descriptor
	if {$log_fd != {default}} {
		set LOG_FD $log_fd
	}

	set standalone     $ARGS(-standalone)
	set CFG(autoflush) $ARGS(-autoflush)
	set CFG(mask)      $ARGS(-mask)
	set CFG(strict)    $ARGS(-strict)
	set CFG(level)     $ARGS(-level)
	set CFG(symlevel)  $ARGS(-symlevel)
	set CFG(rotation)  $ARGS(-rotation)
	set CFG(mode)      $ARGS(-mode)
	set CFG(log_file)  $ARGS(-log_file)
	set CFG(file)      [file join $ARGS(-log_dir) $CFG(log_file)]
	set CFG(override)  $ARGS(-override)
	set CFG(overrides) $ARGS(-overrides)
	set CFG(ts_file)   $ARGS(-ts_file)
	set CFG(ts_dir)    $ARGS(-ts_dir)
	set CFG(colour)    0

	# Check if we are using the appserver
	if {[catch {package present OT_AppServ} msg]} {
		incr standalone
	}

	# Handle standalone behaviour (old sl_init functionality)
	if {$standalone && $ARGS(-log_fd) == {default}} {

		# open the log file
		if {[regexp {(?:<<)?(stdout|stderr)(?:>>)?} $CFG(log_file) all log_file]} {
			set LOG_FD [OT_LogAttach\
				-default \
				-level $CFG(level)\
				-dup   $log_file]
		} else {
			set LOG_FD [OT_LogOpen\
				-default \
				-rotation [string toupper $CFG(rotation)]\
				-level    $CFG(level)\
				-mode     [string tolower $CFG(mode)] \
				$CFG(file)]
		}
	}

	# If we are logging to standard out/err we can add colourised logging
	# via core::log::xwrite
	if {[regexp {(?:<<)?(stdout|stderr)(?:>>)?} $CFG(log_file) all]} {

		# Detect if we are running inside Jenkins. We shouldn't add colourised logging
		# if we are as it won't get displayed properly
		if {[info exists ::env(JOB_NAME)] && [info exists ::env(EXECUTOR_NUMBER)]} {
			set CFG(colour) 0
		} else {
			set CFG(colour) 1
		}

		# Override default terminal colours
		foreach {colour escape_code} $ARGS(-colour_override) {
			set TERM($colour) $escape_code
		}
	}

	# default sym levels
	foreach {name value} $ARGS(-level_map) {
		set SYM_LEVEL($name) [OT_CfgGet LOG_LEVEL_$name $value]
		OT_LogSetLevelName $LOG_FD $name $value
	}

	# set the symbolic log level
	if {![set_sym_level $CFG(symlevel)]} {
		set_sym_level INFO
	}

	# set the level for unknown symbolic names to zero:
	OT_LogSetLevelUnknown $LOG_FD 0

	_init_overrides

	incr CFG(init)

	write DEBUG {Using core/tcl/util/log.tcl ($LOG_FD)}
}

# Retrieve a log config value
#
# @param name config name
# @param default default value
# @return config value

core::args::register \
	-proc_name core::log::get_config \
	-desc {Retrieve a log config value}

proc core::log::get_config {name {default {}}} {

	variable CFG

	if {[info exists CFG($name)]} {
		return $CFG($name)
	}

	return $default
}

# Initialise overrides.
proc core::log::_init_overrides {} {

	variable LOG_FD
	variable CFG

	# don't do any checking if this isn't turned on
	if {!$CFG(override)} {
		return
	}

	# check that overriders are correctly formatted
	if {[llength $CFG(overrides)] % 3 != 0} {
		error \
			"Config item LOG_OVERRIDE_LEVELS must be a list of triples"
	}

	# this command is only available in more recent builds
	if {[info commands OT_CfgGetNames] != ""} {
		# do not add in any particulate order
		foreach n [OT_CfgGetNames] {
			if {![string match LOG_OVERRIDE.* $n]} {
				continue
			}

			# format: LOG_OVERRIDE.pattern
			foreach {{} pattern} [split $n .] {break}

			# format: level ?match_type?
			set v [OT_CfgGet $n]

			set level      [lindex $v 0]
			# this may be empty
			set match_type [lindex $v 1]

			# default
			if {$match_type == ""} {
				set match_type EXACT
			}

			lappend CFG(overrides) $pattern $level $match_type
		}
	}

	foreach {pattern level match_type} $CFG(overrides) {

		if {[lsearch {CRITICAL ERROR WARNING INFO DEBUG DEV} $level] == -1} {
			error "Symbolic logging override level '$level' is non-standard"
		}

		if {[OT_LogGetLevelName $LOG_FD $level] > [OT_LogGetLevel $LOG_FD]} {
			error "Logging overrides configured such that some will not log"
		}

		if {[lsearch {ANY EXACT} $match_type] == -1} {
			error "Match type is not valid"
		}
	}
}



#--------------------------------------------------------------------------
# Get/Set Symbolic Level
#--------------------------------------------------------------------------

# Get the symbolic log level (see core::log::set_sym_level).
#
# @return lowest symbolic level name which is <= current numeric level
#

core::args::register \
	-proc_name core::log::get_sym_level \
	-desc {Get the symbolic log level (see core::log::set_sym_level).} \
	-returns ASCII

proc core::log::get_sym_level args {

	variable LOG_FD

	set level [OT_LogGetLevel $LOG_FD]
	foreach sym { DEV DEBUG INFO WARNING ERROR CRITICAL } {
		if {$level >= [OT_LogGetLevelName $LOG_FD $sym]} {
			return $sym
		}
	}

	return UNKNOWN
}



# Set the numeric log level to a symbolic level.
#
# @param sym_level - symbolic level name
#   (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#   If an unknown sym name, then the level will be set to 99999
#
# @return zero on error, non-zero on success
#

core::args::register \
	-proc_name core::log::set_sym_level \
	-desc {Set the numeric log level to a symbolic level.} \
	-returns BOOL

proc core::log::set_sym_level { sym_level } {

	variable LOG_FD

	if {[catch {
		OT_LogSetLevel $LOG_FD [OT_LogGetLevelName $LOG_FD $sym_level]
	} msg]} {
		return 0
	}

	return 1
}



# Gets the symbolic level that the calling procedure (which may be in core::log!),
# should be logged at. Should always be called using 'uplevel 1'.
#
# @return the symbolic level that the caller should be logged at
#

core::args::register \
	-proc_name core::log::get_my_max_sym_level \
	-desc {Gets the symbolic level that the calling procedure} \
	-returns ASCII

proc core::log::get_my_max_sym_level {} {

	variable CFG

	# Note: this procedure is optimised for speed.

	# logging level, or course, defaults to the default level
	# we then check for overides
	set sym_level [get_sym_level]

	if {!$CFG(override)} {
		return $sym_level
	}

	# note that level zero returns this procedure, i don't expect this normally,
	# i would expect it to be the global script, this may differ between
	# appservs and tcl shells
	#
	# note that the order means that higher level override lower levels
	for {set l 0} {$l < [info level]} {incr l} {
		set ns [string trimleft [uplevel #$l {namespace current}] ::]
		set pr [lindex [info level $l] 0]

		# ensure that if the procedure is called without being fully qualified
		# that we are using the full version
		if {$ns != "" && [string  first :: $pr] == 0} {
			set pr ${ns}::$pr
		}

		# is this level is the calling one?
		set is_exact [expr {$l == [info level] - 1}]

		# EXACT -> exact caller match
		# ANY -> any stack match
		foreach {pattern new_sym_level match_type} $CFG(overrides) {
			if {
				[string match $pattern $pr] &&
				($match_type == "ANY" || $is_exact)
			} {
				set sym_level $new_sym_level
			}
		}
	}

	return $sym_level
}


# Set a log mask.
# The mask is a list of arguments which are masked (value replaced with '****').
# Only applicable to write_array, write_rs and write_req_args
#
#  @param mask - arg/element mask
#

core::args::register \
	-proc_name core::log::set_mask \
	-desc {Set a log mask.} \
	-returns NONE

proc core::log::set_mask { mask } {

	variable CFG

	set CFG(mask) $mask
}


#--------------------------------------------------------------------------
# Get/Set Log Prefix
#--------------------------------------------------------------------------

# Get the log prefix.
#
# @return log prefix
#

core::args::register \
	-proc_name core::log::get_prefix \
	-desc {Get the log prefix.}

proc core::log::get_prefix args {

	variable LOG_FD

	return [OT_LogGetPrefix $LOG_FD]
}



# Set the log prefix.
#
# @param prefix - new log prefix
#

core::args::register \
	-proc_name core::log::set_prefix \
	-desc {Set the log prefix.} \
	-returns NONE

proc core::log::set_prefix { prefix } {

	variable LOG_FD

	OT_LogSetPrefix $LOG_FD $prefix
}



#--------------------------------------------------------------------------
# Write messages
#--------------------------------------------------------------------------

# Write a log message. Substitute variables if they exist in the message. Do
# not substitute commands contained in the log line. The message will not be
# written if the numeric log level < symbolic level
#
# @param sym_level - symbolic level name
#   (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#   If an unknown sym name, the message will be written
#
# @param msg log message (should be enclosed in braces, instead of quotes)

core::args::register \
	-proc_name core::log::write \
	-desc {Write a log message.} \
	-args [list \
			[list -arg -log_fd -mand 0 -check ANY -default {}    -desc {Send the message to an alternative fd}] \
		] \
	-returns NONE

proc core::log::write { sym_level msg args} {

	variable LOG_FD
	variable CFG

	set log_fd $LOG_FD
	if {[llength $args] >0} {
		array set ARGS [core::args::check core::log::write {*}$args]
		if {$ARGS(-log_fd) != {}} {
			set log_fd $ARGS(-log_fd)
		}
	}

	if {!$CFG(init)} {
		puts stdout "WARNING: Initialise logging - [uplevel subst [list $msg]]"
		return
	}

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $log_fd \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $log_fd]
	}

	set level [OT_LogGetLevelName $log_fd $sym_level]

	if {$level <= $max_level} {

		if {$CFG(strict)} {
			set cmd [list subst -nocommands $msg]
		} else {
			set cmd [list subst $msg]
		}

		if {[catch {OT_LogWrite $log_fd $level [uplevel 1 $cmd]} err]} {
			OT_LogWrite $log_fd $level "LOG ERROR, unable to evaluate: $err while evaluating '$msg'"
		}
	}
}

# Extended version of core::log::write
# This should not be used in any customer facing code as extra functionality
# increases the execution time of the proc
core::args::register \
	-proc_name core::log::xwrite \
	-args [list \
		[list -arg -msg       -mand 1 -check ANY                 -desc {Log message}] \
		[list -arg -sym_level -mand 0 -check ASCII -default INFO -desc {Symbolic level name}] \
		[list -arg -ns_prefix -mand 0 -check BOOL  -default 1    -desc {Add namespace prefix}] \
		[list -arg -colour    -mand 0 -check ASCII -default {}   -desc {Colourise the log line}] \
		[list -arg -trace     -mand 0 -check BOOL  -default 0    -desc {Add a stack trace}] \
		[list -arg -log_fd        -mand 0 -check ASCII -default {}    -desc {Send the message to an alternative fd}] \
		[list -arg -custom_prefix -mand 0 -check ANY   -default {}    -desc {Add a custom prefix to the current message}] \
	] \
	-body {
		variable CFG
		variable TERM

		set prefix {}
		set trace  $ARGS(-trace)
		set colour $ARGS(-colour)
		set level  $ARGS(-sym_level)
		set msg    $ARGS(-msg)

		if {$ARGS(-ns_prefix) && [uplevel [list info level]] > 0} {
			set parent_ns    "[uplevel [list namespace current]]"
			set calling_proc [lindex [split [lindex [info level -1] 0] ":"] end]
			set prefix       [string trimleft "${parent_ns}::${calling_proc}: " ::]
		}

		if {$ARGS(-custom_prefix) != {}} {
			set prefix "$prefix $ARGS(-custom_prefix): "
		}

		set msg [uplevel subst [list [colourise -msg $msg -colour $colour]]]

		eval {core::log::write $level {${prefix}$msg} -log_fd $ARGS(-log_fd)}

		# Add stack trace
		if {$trace} {
			write_stack $level
		}
	}

# Colourise a string. Can be used to build up a string of multiple colours
core::args::register \
	-proc_name core::log::colourise \
	-desc {Colourise a string} \
	-args [list \
		[list -arg -msg    -mand 1 -check ANY   -desc {Log message}] \
		[list -arg -colour -mand 1 -check ASCII -desc {Colour}] \
	] \
	-body {
		variable CFG
		variable TERM

		set colour $ARGS(-colour)

		if {!$CFG(colour) || ![info exists TERM($colour)]} {
			return $ARGS(-msg)
		}

		return [join [list {\x1b\[} $TERM($colour) {m} $ARGS(-msg) {\x1b\[0m}] {}]
	}

# Write the contents of an array.
# The array contents will not be written if the numeric log level < symbolic
# level
#
# @param sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the array contents will be written
# @param arr       - array to write
# @param pattern   - pattern matching on the array to log, if omitted then all the
#               array elements will be logged (default - *)
# @param mask      - list of arguments which are masked (value replaced with '****')
#               if not supplied then uses global mask
# @param mode      - pattern match mode -exact, -glob, or -regexp
#               (-glob)
#

core::args::register \
	-proc_name core::log::write_array \
	-desc {Write the contents of an array.} \
	-args [list \
		[list -arg -prefix -mand 0 -check ASCII -default {} -desc {Log line prefix}] \
	] \
	-returns NONE

proc core::log::write_array { sym_level arr {pattern *} {mask ""} {mode -glob} args} {

	variable LOG_FD
	variable CFG

	array set ARGS [core::args::check core::log::write_array {*}$args]

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {

		# use default mask if one not specified
		if {$mask == ""} {
			set mask $CFG(mask)
		}

		upvar 1 $arr MSG
		foreach name [lsort -dictionary [array names MSG $mode $pattern]] {

			set m 0
			if {[llength $mask]} {
				set idx [string last "," $name]
				if {[lsearch $mask [string range $name [expr {$idx == -1 ? 0 : $idx + 1}] end]] != -1} {
					set m 1
				}
			}

			if {$m} {
				set v "****"
			} else {
				set v $MSG($name)
			}

			OT_LogWrite $LOG_FD $sym_level "${ARGS(-prefix)}${arr}($name)=$v"
		}
	}
}



# Write the contents of the stack (excluding this proc call).
# The stack trace will not be written if the numeric log level < symbolic
# level
# NB: If the proc is called via the log_compat API, then this proc is ignored
#     within the stack list
#
# @param sym_level - symbolic level name
#   (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#   If an unknown sym name, the stack trace will be written
#

core::args::register \
	-proc_name core::log::write_stack \
	-desc {Write the contents of the stack (excluding this proc call).} \
	-returns NONE

proc core::log::write_stack { sym_level } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		for {set i 1} {$i < [info level]} {incr i} {
			set p [info level $i]
			if {$p != "ob::log::write_stack $sym_level"} {
				OT_LogWrite $LOG_FD $level "\tLevel $i: $p"
			}
		}
	}
}



# Write a SQL query.
# The query will not be written if the numeric log level < symbolic
# level. The query will have all tabs converted to 4 characters and
# all query arguments (?) are resolved.
#
# @param sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the query will be written
# @param prefix    - prefix added to each logged message (not a context prefix)
# @param msg       - message associated with the query
# @param qry       - SQL query
# @param arglist   - query arguments (? substitutes)
#

core::args::register \
	-proc_name core::log::write_qry \
	-desc {Write a SQL query.} \
	-returns NONE

proc core::log::write_qry { sym_level prefix msg qry {arglist ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {

		# replace ? with associated arguments
		if {$arglist != ""} {

			# if the args include the types then we don't want to show them
			if {[lindex $arglist 0] == "-inc-type"} {
				foreach {a t} [lrange $arglist 1 end] {
					lappend narglist $a
				}
				set arglist $narglist
			}

			set q [split $qry ?]
			set p [list [lindex $q 0]]
			foreach pp [lrange $q 1 end] aa $arglist {
				lappend p \"[string map {\" \"\"} $aa]\"
				lappend p $pp
			}
			set qry [join $p ""]
		}

		# untabify qry and get each line of the query
		set ll [list]
		foreach l [split $qry "\n"] {
			if {[string length [string trim $l]] == 0} {
				continue
			}
			lappend ll [_untabify $l]
		}

		if {$prefix != ""} {
			set prefix "$prefix: "
		}
		set header "$prefix******************************************"
		OT_LogWrite $LOG_FD $level $header

		# write message
		if {$msg != ""} {
			OT_LogWrite $LOG_FD $level [format "%s%s" $prefix $msg]
		}

		# write query
		set s_range [_lead_space_count $ll]
		foreach l $ll {
			OT_LogWrite $LOG_FD $level \
			    "$prefix[string range $l $s_range end]"
		}

		OT_LogWrite $LOG_FD $level $header
	}
}



# Write a result set.
# The result-set will not be written if the numeric log level < symbolic
# level.
#
# @param sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the result-set will be written
# @param rs        - result set
# @param mask      - list of arguments which are masked (value replaced with '****')
#               if not supplied then uses global mask
#

core::args::register \
	-proc_name core::log::write_rs \
	-desc {Write a result set.} \
	-returns NONE

proc core::log::write_rs { sym_level rs {mask ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {

		# use default mask if one not specified
		if {$mask == ""} {
			set mask $CFG(mask)
		}

		set nrows [db_get_nrows $rs]
		set cols  [db_get_colnames $rs]

		OT_LogWrite $LOG_FD $level "nrows=$nrows"

		for {set r 0} {$r < $nrows} {incr r} {
			foreach c $cols {

				if {[lsearch $mask $c] != -1} {
					set v "****"
				} else {
					set v [db_get_col $rs $r $c]
				}

				OT_LogWrite $LOG_FD $level "($r,$c)=$v"
			}
		}
	}
}



# Write HTML/WML request arguments.
# The arguments will not be written if the numeric log level < symbolic
# level.
#
# @param sym_level symbolic level name
#   (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#   If an unknown sym name, the result-set will be written
#
# @param mask list of arguments which are masked (value replaced with '****')
#   if not supplied then uses global mask
#
# @param one_line If true, then log all the name=value pairs on a single line

core::args::register \
	-proc_name core::log::write_req_args \
	-desc {Write HTML/WML request arguments.} \
	-returns NONE

proc core::log::write_req_args { sym_level {mask ""} {one_line 0}} {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level > $max_level} {
		return
	}

	# use default mask if one not specified
	if {$mask == ""} {
		set mask $CFG(mask)
	}

	set items {}
	set n     [reqGetNumVals]
	for {set i 0} {$i < $n} {incr i} {
		set name [reqGetNthName $i]
		set n_vals_for_name [reqGetNumArgs $name]

		# loop through all name/value pairs for this unique name
		for {set j 0} {$j < $n_vals_for_name} {incr j} {

			if {[lsearch $mask $name] != -1} {
				set value "****"
			} else {
				set value [reqGetNthArg $name $j]
			}

			lappend items "$name=$value"
		}
	}

	if {$one_line} {
		set line "Req args: [join $items {, }]"
		OT_LogWrite $LOG_FD $level $line
	} else {
		foreach item $items {
			OT_LogWrite $LOG_FD $level $item
		}
	}
}



# Returns an integer that represents the log level of a particular
# sym_level e.g log level 8 is equivalent to INFO
#
# @param level  - symbolic level name
# @param log_fd - log file descriptor
#
# @return integer that represents the log level of a particular

core::args::register \
	-proc_name core::log::get_log_level \
	-desc {Returns the log level of a sym_level.} \
	-returns INT

proc core::log::get_log_level {level log_fd} {

	variable SYM_LEVEL

	if {[info exists SYM_LEVEL($level)]} {
		set level $SYM_LEVEL($level)
	}

	if {$level <= [OT_LogGetLevel $log_fd]} {
		return $level
	}
	return 0
}



# Write a timestamp and the current log file to a
# separate file for later analysis
#

core::args::register \
	-proc_name core::log::write_ts \
	-desc {Write a timestamp and the current log file to a separate file} \
	-returns NONE

proc core::log::write_ts {} {

	variable CFG

	set fn {core::log::write_ts:}

	if {$CFG(ts_dir) eq ""} {
		write DEBUG {$fn no timestamp dir defined}
		return
	}

	if {$CFG(ts_file) eq ""} {
		write DEBUG {$fn no timestamp file defined}
		return
	}

	set now [clock seconds]

	set filename [clock format $now -format $CFG(file)]
	set fields   [clock format $now -format "%m %d %H %M %S"]

	if { ![catch {
		set asId  [asGetId]
		set reqId [reqGetId]
	}] } {
		lappend fields $asId $reqId
	}

	set f [file join $CFG(ts_dir) $CFG(ts_file)]
	if {[catch {
		set fd [open $f a+]
	} msg]} {
		write ERROR {$fn failed to open file $f: $msg}
	} else {
		puts $fd "$filename $fields"
		close $fd
	}

}


# Write contents of the errorInfo global variable.
#
# @param sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#

core::args::register \
	-proc_name core::log::write_error_info \
	-desc {Write contents of the errorInfo global variable.} \
	-returns NONE

proc core::log::write_error_info { sym_level } {

	global errorInfo

	variable CFG
	variable LOG_FD

	if {![info exists errorInfo]} {
		return
	}

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		set i 1
		foreach l [split $errorInfo "\n"] {
			OT_LogWrite $LOG_FD $level [format {  (%02i) ==> %s} $i $l]
			incr i
		}
	}
}



##
# Write a log message that might contain lengthy or unprintable text.
#
# USAGE
#
#   core::log::write_nasty <sym_level> <braced_msg>
#   core::log::write_nasty_lines <sym_level> <braced_msg>
#
# where:
#
#   sym_level  - symbolic level name
#                (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#
#   braced_msg - log message (will be subst-ed in the caller's scope,
#                so should be enclosed in braces not quotes)
#
# DETAILS
#
# Any non-printable characters, any non-7bit-ASCII characters and any
# backslash or double-quote characters within the subst-ed log message
# will be replaced with escape sequences in a reversible and readable
# fashion before being written to the log file, and excessively long
# messages will be split across multiple log lines (with a trailing
# backslash at the end of lines to indicate this has happened).
#
# The difference between write_nasty and write_nasty_lines is how
# they handle newlines within the message; both escape newlines to
# the "\n" sequence but write_nasty_lines will also split the message
# at newlines and write each line seperately.
#
# To summarise, log lines produced by write_nasty / write_nasty_lines
# will contain the following escape sequences:
#
#   \t                 = tab
#   \r                 = carriage return
#   \n                 = newline
#   \xNN               = Unicode codepoint NN hex
#   \uNNNN             = Unicode codepoint NNNN hex
#   \\                 = backslash
#   \"                 = double-quote
#   \ (at end of line) = message will be continued on next log line
#
# PURPOSE
#
# These procedures should be particularly useful for possibly-lengthy
# data received from a third party, for data that might be in a peculiar
# chracter encoding, in any situation where we need an accurate and
# easily readable record of exactly what characters were in a string,
# and for data that might contain newlines (which otherwise cause
# problems when collating log files).
#
# However, there's no good reason (other than a tiny performance hit)
# not to use them for everything; eventually core::log::write might be
# modified to follow the behaviour of core::log::write_nasty_lines ...
#
##

core::args::register \
	-proc_name core::log::write_nasty \
	-desc {Write a log message that might contain lengthy or unprintable text.}

proc core::log::write_nasty {sym_level braced_msg} {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		# Substitute variables within the message
		# (hopefully the caller used braces not quotes).
		set actual_msg [uplevel 1 [list subst -nocommands $braced_msg]]
		return [_really_write_nasty $level $actual_msg 1]
	}
}

core::args::register \
	-proc_name core::log::write_nasty_lines \
	-desc {}

proc core::log::write_nasty_lines {sym_level braced_msg} {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 core::log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		# Substitute variables within the message
		# (hopefully the caller used braces not quotes).
		set actual_msg [uplevel 1 [list subst -nocommands $braced_msg]]
		return [_really_write_nasty $level $actual_msg 1]
	}
}

proc core::log::_really_write_nasty {level actual_msg keep_newlines} {

	variable LOG_FD
	variable CFG

	# If we need to respect newlines, split the message on them,
	# but add the newlines back in so we can distinguish between
	# a real new line and a line split for being too long.

	if {$keep_newlines} {
		set lines [split $actual_msg "\n"]
		if {[llength $lines] > 1} {
			set unchomped_lines [list]
			for {set i 0} {$i < [llength $lines]} {incr i} {
				set line [lindex $lines $i]
				if {$i < [llength $lines] - 1} {
					append line "\n"
				}
				lappend unchomped_lines $line
			}
			set lines $unchomped_lines
		}
	} else {
		set lines [list $actual_msg]
	}

	# Avoid absurdly long lines in the logs by splitting
	# them up before escaping them.

	set max_len 500
	if { [llength $lines] > 1 || \
		 [string length [lindex $lines 0]] > $max_len } {
		set short_lines [list]
		foreach line $lines {
			set len [string length $line]
			if {$len <= $max_len} {
				lappend short_lines $line
			} else {
				for {set i 0} {$i < $len} {incr i $max_len} {
					lappend short_lines \
					  [string range $line $i [expr {$i + $max_len - 1}]]
				}
			}
		}
		set lines $short_lines
	}

	# Escape each line using a compact, familiar and lossless format.
	# We escape the double-quote to make it easier for people to log
	# messages such as {foo="$foo"} without any ambiguity.

	set esc_lines [list]
	foreach line $lines {
		lappend esc_lines [_esc_unprintable $line "\""]
	}
	set lines $esc_lines

	# Finally, write the lines to the log file using a seperate
	# call for each log line to ensure the log prefix appears on
	# each. All lines apart from the last one will be terminated
	# by a line-continuation backslash.

	for {set i 0} {$i < [llength $lines]} {incr i} {
		set line [lindex $lines $i]
		if {$i < [llength $lines] - 1} {
			append line \\
		}
		OT_LogWrite $LOG_FD $level $line
	}

	return
}

# Untabify a string.
# Replaces all tabs with spaces
#
# @param str string to untabify
# @param tablen - tab length; determines the number of space characters per tab
#             (default: 4)
#
# @return string with tabs replaced by spaces
#
# TODO - Replace with package require textutil::tabify  ? 0.7 ?
proc core::log::_untabify { str {tablen 4} } {

	set out ""
	while {[set i [string first "\t" $str]] != -1} {
		set j [expr {$tablen - ($i % $tablen)}]
		append out [string range $str 0 [incr i -1]][format %*s $j " "]
		set str [string range $str [incr i 2] end]
	}
	return $out$str
}

# Count how many leading spaces that can be stripped from each string in a list
#
# @param str string list
#
# @return number of leading spaces
#
proc core::log::_lead_space_count { str } {

	set min -1
	foreach s $str {
		regsub {^\s+} $s {} n
		set c [expr {[string length $s] - [string length $n]}]
		if {$min == -1} {
			set min $c
		} elseif {$c < $min} {
			set min $c
		}
	}
	return [expr {($min < 0) ? 0 : $min}]
}
