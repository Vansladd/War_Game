# $Id: log.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
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
# Synopsis:
#    package require util_log ?4.5?
#
# If not using the package within appserv, then load libOT_Tcl.so.
#
# Procedures:
#    ob_log::init            one time initialisation (uses config file)
#    ob_log::sl_init         standalone one-time initialisation
#    ob_log::sl_stdout       standalone one-time init to stdout
#    ob_log::get_sym_level   get symbolic level name
#    ob_log::set_sym_level   set symbolic level name
#    ob_log::get_prefix      get log prefix
#    ob_log::set_prefix      set a log prefix
#    ob_log::set_mask        set a log mask
#    ob_log::write           write message
#    ob_log::write_array     write array contents
#    ob_log::write_stack     write stack trace
#    ob_log::write_qry       write a SQL query
#    ob_log::write_rs        write a SQL result set
#    ob_log::write_req_args  write HTML/WML request arguments
#    ob_log::write_ts        write timestamp and log file to a separate file
#


package provide util_log 4.5


# Dependencies
#
package require Tcl       8.4
package require util_util 4.5



# Variables
#
namespace eval ob_log {

	variable INIT   0
	variable LOG_FD "default"
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One-time initialisation on a log file descriptor.
# Sets the symbolic log level names and the symbolic log level, taking the
# information from a configuration file.
#
#   log_fd  - log file descriptor
#
proc ob_log::init { {log_fd default} } {

	variable INIT
	variable LOG_FD
	variable CFG

	# package initialised?
	if {$INIT} {
		return
	}

	# init log file descriptor
	if {$log_fd != "default"} {
		set LOG_FD $log_fd
	}

	set CFG(mask)      [OT_CfgGet LOG_MASK {}]
	set CFG(file)      [file join [OT_CfgGet LOG_DIR            .] \
								  [OT_CfgGet LOG_FILE logfile.log]]

	set CFG(override)  [OT_CfgGet LOG_OVERRIDE 0]
	set CFG(overrides) [OT_CfgGet LOG_OVERRIDES [list]]
	
	set CFG(ts_file)   [OT_CfgGet LOG_TS_FILE ""]
	set CFG(ts_dir)    [OT_CfgGet LOG_TS_DIR ""]

	# default sym levels
	array set SYM_LEVEL [list\
		CRITICAL 1\
		ERROR    2\
		WARNING  4\
		INFO     8\
		DEBUG    10\
		DEV      15]

	# set log name
	foreach s [array names SYM_LEVEL] {
		set SYM_LEVEL($s) [OT_CfgGet LOG_LEVEL_$s $SYM_LEVEL($s)]
		OT_LogSetLevelName $log_fd $s $SYM_LEVEL($s)
	}

	# set the symbolic log level
	if {![set_sym_level [OT_CfgGet LOG_SYMLEVEL INFO]]} {
		set_sym_level INFO
	}
	
	# set the level for unknown symbolic names to zero:
	OT_LogSetLevelUnknown $LOG_FD 0

	_init_overrides

	set INIT 1
}



# One-time initialisation on a log file.
# Initialise the package and open a log file. The information is taken from a
# series of arguments, allowing 'standalone' applications which do not support,
# or use, configuration files to use the package.
#
#   dir   - log directory
#   file  - log file
#           if filename == <<stdout>>, then logged to stdout
#   args  - series of name value pairs which define the optional
#           configuration
#           the name is any of the package configuration names where LOG_
#           is replaced by -, e.g. LOG_ROTATION is -log_rotation
#
proc ob_log::sl_init { dir file args } {

	variable INIT
	variable LOG_FD
	variable CFG

	# Package initialised?
	if {$INIT} {
		return
	}
	
	set CFG(file) [file join $dir $file]

	# set optional cfg from supplied arguments (overwrite defaults)
	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	# set optional cfg default values
	foreach {n v} {
		rotation       DAY
		level          100
		mode           APPEND
		level_critical 1
		level_error    2
		level_warning  4
		level_info     8
		level_debug    10
		level_dev      15
		symlevel       INFO
		autoflush      1
		mask           {}
		override       0
		overrides      {}
		ts_file        ""
		ts_dir         ""
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet LOG_[string toupper $n] $v]
		}
	}

	# open the log file
	if {$file == "<<stdout>>"} {
		set LOG_FD [OT_LogAttach\
						-level $CFG(level)\
						-dup stdout]
	} else {
		set LOG_FD [OT_LogOpen\
						-rotation [string toupper $CFG(rotation)]\
						-level $CFG(level)\
						-mode [string tolower $CFG(mode)]\
						[file join $dir $file]]
	}

	# set log names
	foreach s [array names CFG level_*] {
		OT_LogSetLevelName $LOG_FD\
		    [string toupper [string range $s 6 end]] $CFG($s)
	}

	# set the symbolic log level
	if {![set_sym_level [string toupper $CFG(symlevel)]]} {
		set_sym_level INFO
	}

	# set autoflush
	OT_LogSetAutoFlush $LOG_FD $CFG(autoflush)

	_init_overrides

	set INIT 1
}



# Standalone one-time initialisation on a log file which is attached to stdout
#
#   args  - series of name value pairs which define the optional
#           configuration
#           the name is any of the package configuration names where LOG_
#           is replaced by -, e.g. LOG_ROTATION is -log_rotation
#
proc ob_log::sl_stdout { args } {

	eval {sl_init "" "<<stdout>>"} $args
}



# Initialise overrides.
#
proc ob_log::_init_overrides {} {

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

# Get the symbolic log level (see ob_log::set_sym_level).
#
#   returns - lowest symbolic level name which is <= current numeric level
#
proc ob_log::get_sym_level args {

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
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, then the level will be set to 99999
#
#   returns zero on error, non-zero on success
#
proc ob_log::set_sym_level { sym_level } {

	variable LOG_FD

	if {[catch {
		OT_LogSetLevel $LOG_FD [OT_LogGetLevelName $LOG_FD $sym_level]
	} msg]} {
		return 0
	}

	return 1
}



# Gets the symbolic level that the calling procedure (which may be in ob_log!),
# should be logged at. Should always be called using 'uplevel 1'.
#
#   returns the symbolic level that the caller should be logged at
#
proc ob_log::get_my_max_sym_level {} {

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
#    mask - arg/element mask
#
proc ob_log::set_mask { mask } {

	variable CFG

	set CFG(mask) $mask
}


#--------------------------------------------------------------------------
# Get/Set Log Prefix
#--------------------------------------------------------------------------

# Get the log prefix.
#
#   returns - log prefix
#
proc ob_log::get_prefix args {

	variable LOG_FD

	return [OT_LogGetPrefix $LOG_FD]
}



# Set the log prefix.
#
#   prefix - new log prefix
#
proc ob_log::set_prefix { prefix } {

	variable LOG_FD

	OT_LogSetPrefix $LOG_FD $prefix
}



#--------------------------------------------------------------------------
# Write messages
#--------------------------------------------------------------------------

# Write a log message.
# The message will not be written if the numeric log level < symbolic level
#
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the message will be written
#   msg       - log message (should be enclosed in braces, instead of quotes)
#
proc ob_log::write { sym_level msg } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		OT_LogWrite $LOG_FD $level [uplevel 1 [list subst $msg]]
	}
}



# Write the contents of an array.
# The array contents will not be written if the numeric log level < symbolic
# level
#
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the array contents will be written
#   arr       - array to write
#   pattern   - pattern matching on the array to log, if omitted then all the
#               array elements will be logged (default - *)
#   mask      - list of arguments which are masked (value replaced with '****')
#               if not supplied then uses global mask
#
proc ob_log::write_array { sym_level arr {pattern *} {mask ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		upvar 1 $arr MSG
		foreach name [lsort -dictionary [array names MSG $pattern]] {

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

			OT_LogWrite $LOG_FD $sym_level "${arr}($name)=$v"
		}
	}
}



# Write the contents of the stack (excluding this proc call).
# The stack trace will not be written if the numeric log level < symbolic
# level
# NB: If the proc is called via the log_compat API, then this proc is ignored
#     within the stack list
#
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the stack trace will be written
#
proc ob_log::write_stack { sym_level } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		set stack_level [info level]
		for {set i 1} {$i < $stack_level} {incr i} {
			set p [info level $i]
			if {$p != "ob::log::write_stack $sym_level"} {
				OT_LogWrite $LOG_FD $level "Level $i: $p"
			}
		}
	}
}



# Write a SQL query.
# The query will not be written if the numeric log level < symbolic
# level. The query will have all tabs converted to 4 characters and
# all query arguments (?) are resolved.
#
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the query will be written
#   prefix    - prefix added to each logged message (not a context prefix)
#   msg       - message associated with the query
#   qry       - SQL query
#   arglist   - query arguments (? substitutes)
#
proc ob_log::write_qry { sym_level prefix msg qry {arglist ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
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
			lappend ll [ob_util::untabify $l]
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
		set s_range [ob_util::lead_space_count $ll]
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
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the result-set will be written
#   rs        - result set
#   mask      - list of arguments which are masked (value replaced with '****')
#               if not supplied then uses global mask
#
proc ob_log::write_rs { sym_level rs {mask ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
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
#   sym_level - symbolic level name
#               (CRITICAL | ERROR | WARNING | INFO | DEBUG | DEV)
#               If an unknown sym name, the result-set will be written
#   mask      - list of arguments which are masked (value replaced with '****')
#               if not supplied then uses global mask
#
proc ob_log::write_req_args { sym_level {mask ""} } {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		set n [reqGetNumVals]
		for {set i 0} {$i < $n} {incr i} {
			set name [reqGetNthName $i]

			if {[lsearch $mask $name] != -1} {
				set value "****"
			} else {
				set value [reqGetNthVal $i]
			}

			OT_LogWrite $LOG_FD $level "$name=$value"
		}
	}
}



# Write a timestamp and the current log file to a
# separate file for later analysis
#
proc ob_log::write_ts {} {

	variable CFG

	set fn {ob_log::write_ts:}

	if {$CFG(ts_dir) eq ""} {
		ob_log::write DEBUG {$fn no timestamp dir defined}
		return
	}

	if {$CFG(ts_file) eq ""} {
		ob_log::write DEBUG {$fn no timestamp file defined}
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
		ob_log::write ERROR {$fn failed to open file $f: $msg}
	} else {
		puts $fd "$filename $fields"
		close $fd
	}

}

##
# Internal - escape a totally arbitrary string into a nice printable
# string, replacing any control, special or non-ASCII characters with
# escape sequences. In the case of _esc_tcl_unprintable, the resulting
# string could safely be used inside a quoted string within Tcl source
# code.
#
# Usage:
#
#   _esc_tcl_unprintable <str>
#   _esc_unprintable <str> ?<specials>?
#
# where:
#
#   <str>      = String to be escaped.
#   <specials> = String containing set of printable characters
#                that should also be escaped. Not a list.
#
# ESCAPE SEQUENCES
#
#   \t      = tab
#   \r      = carriage return
#   \n      = line-feed
#   \xNN    = Unicode codepoint NN hex
#   \uNNNN  = Unicode codepoint NNNN hex
#   \\      = backslash
#   \S      = special printable character S
#             (for Tcl, specials are: [ ] { } $ ")
#
# EXAMPLE OUTPUT
#
#   hello
#   hello\nworld
#   Euro: \u20AC
#   Pound: \xa3
#   ni hao ma: \u4F60\u597D\u5417
#   back-slash: \\
#
# MAINTENANCE NOTES
#
# I don't really see why these procedures should ever need
# to change. But if they do, then ...
#
# * Don't mess with any of this unless you are really, really
#   sure you understand Tcl quoting rules within braces, quotes,
#   regexps and source code. The best references are:
#   http://www.tcl.tk/man/tcl8.5/TclCmd/Tcl.htm
#   http://www.tcl.tk/man/tcl8.5/TclCmd/re_syntax.htm
#
# * Be careful to maintain performance - generally easiest to
#   achieve by avoiding any Tcl code inside loops - let regsub,
#   string map, subst, format, etc. do the work, and pre-build
#   as much as possible (but don't use /too/ much memory!).
#
# * Run the unit test (follows the procs) after making any changes.
#
# KNOWN ISSUES
#
# * Should probably be in util_esc.
#
##

proc ob_log::_esc_tcl_unprintable {str} {
	return [_esc_unprintable $str "\[\]\{\}\$\""]
}

proc ob_log::_esc_unprintable {str {specials ""}} {

	# Cached mapping list for previously-seen special sets.

	variable _esc_unprintable_maps
	if {![info exists _esc_unprintable_maps($specials)]} {
		set b \\
		set map [list]
		# Backslash always needs escaping.
		lappend map $b $b$b
		# Printable characters in "specials" must have some
		# special meaning and therefore also need escaping
		# by prefixing with a backslash.
		foreach c [split $specials {}] {
			lappend map $c $b$c
		}
		# These are more readable escapes than \xNN.
		foreach {c s} [list \t t \r r \n n] {
			lappend map $c $b$s
		}
		set _esc_unprintable_maps($specials) $map
	} else {
		set map $_esc_unprintable_maps($specials)
	}

	set str [string map $map $str]

	# Find the location of each run of non-printable-ASCII chars
	# that need turning into \xNN escapes.
	# We limit the length of each match for better efficiency in
	# the escaping step; this allows us to use cached scan and
	# format strings of the appropriate length (e.g. %c%c%c for
	# a match of length 3).
	
	set max_match_len 16
	set base_re {[\x00-\x1F\x7F-\xFF]}
	set re "${base_re}{1,$max_match_len}"
	set matches [regexp -all -indices -inline -- $re $str]
	if {[llength $matches]} {
		variable _esc_unprintable_scans
		if {![info exists _esc_unprintable_scans]} {
			set scan_str ""
			for {set i 0} {$i <= $max_match_len} {incr i} {
				set _esc_unprintable_scans($i) $scan_str
				append scan_str "%c"
			}
		}
		variable _esc_unprintable_short_fmts
		if {![info exists _esc_unprintable_short_fmts]} {
			set scan_str ""
			for {set i 0} {$i <= $max_match_len} {incr i} {
				set _esc_unprintable_short_fmts($i) $scan_str
				append scan_str {\x%02x}
			}
		}
		# Construct a new string from the bits inbetween the
		# matches interleaved with the escaped matches.
		set i 0
		set new ""
		foreach match $matches {
			set s [lindex $match 0]
			set e [lindex $match 1]
			append new [string range $str $i [expr {$s - 1}]]
			set chars [string range $str $s $e]
			set len [string length $chars]
			set scan_str $_esc_unprintable_scans($len)
			set codepoints [scan $chars $scan_str]
			set fmt_str $_esc_unprintable_short_fmts($len)
			set esc_str [eval [list format $fmt_str] $codepoints]
			append new $esc_str
			set i [expr {$e + 1}]
		}
		append new [string range $str $i end]
		set str $new
	}

	# Same again, but for \uNNNN escapes.

	set max_match_len 16
	set base_re {[\u0100-\uFFFF]}
	set re "${base_re}{1,$max_match_len}"
	set matches [regexp -all -indices -inline -- $re $str]
	if {[llength $matches]} {
		variable _esc_unprintable_scans
		if {![info exists _esc_unprintable_scans]} {
			set scan_str ""
			for {set i 0} {$i <= $max_match_len} {incr i} {
				set _esc_unprintable_scans($i) $scan_str
				append scan_str "%c"
			}
		}
		variable _esc_unprintable_long_fmts
		if {![info exists _esc_unprintable_long_fmts]} {
			set scan_str ""
			for {set i 0} {$i <= $max_match_len} {incr i} {
				set _esc_unprintable_long_fmts($i) $scan_str
				append scan_str {\u%04X}
			}
		}
		set i 0
		set new ""
		foreach match $matches {
			set s [lindex $match 0]
			set e [lindex $match 1]
			append new [string range $str $i [expr {$s - 1}]]
			set chars [string range $str $s $e]
			set len [string length $chars]
			set scan_str $_esc_unprintable_scans($len)
			set codepoints [scan $chars $scan_str]
			set fmt_str $_esc_unprintable_long_fmts($len)
			set esc_str [eval [list format $fmt_str] $codepoints]
			append new $esc_str
			set i [expr {$e + 1}]
		}
		append new [string range $str $i end]
		set str $new
	}
	
	return $str
}

##
# Unit / performance regression test script for the above procs.
# Example result:
#
#   all-chars safe round trip:
#     ok (63575 microseconds per iteration)
#   no-subst timings:
#     len 0 11.0 microseconds per iteration
#     len 10 7.6 microseconds per iteration
#     len 100 10.6 microseconds per iteration
#     len 1000 48.0 microseconds per iteration
#     len 10000 424.0 microseconds per iteration
#     len 100000 4387.8 microseconds per iteration
#   easy-subst timings:
#     len 10 10.4 microseconds per iteration
#     len 100 11.8 microseconds per iteration
#     len 1000 62.8 microseconds per iteration
#     len 10000 551.4 microseconds per iteration
#     len 100000 5949.4 microseconds per iteration
#   nasty-subst timings:
#     len 10 41.0 microseconds per iteration
#     len 100 196.0 microseconds per iteration
#     len 1000 2159.8 microseconds per iteration
#     len 10000 18661.6 microseconds per iteration
#     len 100000 184205.0 microseconds per iteration
#
##

if {0} {
	proc ob_log::_time_esc_tcl_unprintable {s upto} {
		while {[string length $s] <= $upto} {
			set t [time {_esc_tcl_unprintable $s} 5]
			puts "  len [string length $s] $t"
			if {![string length $s]} {
				break
			} else {
				set s [string repeat $s 10]
			}
		}
	}
	proc ob_log::_test_esc_tcl_unprintable {} {
		_esc_tcl_unprintable "warm-up"
		puts "all-chars safe round trip:"
		set all_chars ""
		for {set i 0} {$i < 65536} {incr i} {
			append all_chars [format %c $i]
		}
		set t [time {
			set escaped [_esc_tcl_unprintable $all_chars]
		}]
		# result should be safe to use inside a string:
		if {[catch {
			eval "set back_again \"$escaped\""
		} msg]} {
			puts "  FAILED - NOT SAFE ($msg)"
		} elseif {![string equal $all_chars $back_again]} {
			puts "  FAILED - NOT EQUAL"
		} else {
			puts "  ok ($t)"
		}
		puts "no-subst timings:"
		_time_esc_tcl_unprintable "" 0
		_time_esc_tcl_unprintable "zzzzzzzzzz" 100000
		puts "easy-subst timings:"
		_time_esc_tcl_unprintable "zzzzz\nzzzz" 100000
		puts "nasty-subst timings:"
		_time_esc_tcl_unprintable \
		  "\u4F60\u597D\u0000\"\$\[\uFFFF\{\}\\" 100000
	}
	ob_log::_test_esc_tcl_unprintable
	error "you've left unit test code enabled"
}

##
# Write a log message that might contain lengthy or unprintable text.
#
# USAGE
#
#   ob_log::write_nasty <sym_level> <braced_msg>
#   ob_log::write_nasty_lines <sym_level> <braced_msg>
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
# not to use them for everything; eventually ob_log::write might be
# modified to follow the behaviour of ob_log::write_nasty_lines ...
#
##

proc ob_log::write_nasty {sym_level braced_msg} {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		# Substitute variables and commands within the message
		# (hopefully the caller used braces not quotes).
		set actual_msg [uplevel 1 [list subst $braced_msg]]
		return [_really_write_nasty $level $actual_msg 1]
	}
}

proc ob_log::write_nasty_lines {sym_level braced_msg} {

	variable LOG_FD
	variable CFG

	if {$CFG(override)} {
		set max_level [OT_LogGetLevelName $LOG_FD \
			[uplevel 1 ob_log::get_my_max_sym_level]]
	} else {
		set max_level [OT_LogGetLevel $LOG_FD]
	}

	set level [OT_LogGetLevelName $LOG_FD $sym_level]

	if {$level <= $max_level} {
		# Substitute variables and commands within the message
		# (hopefully the caller used braces not quotes).
		set actual_msg [uplevel 1 [list subst $braced_msg]]
		return [_really_write_nasty $level $actual_msg 1]
	}
}

proc ob_log::_really_write_nasty {level actual_msg keep_newlines} {
	
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
