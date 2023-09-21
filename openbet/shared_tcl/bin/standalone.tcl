# $Id: standalone.tcl,v 1.1 2011/10/04 12:27:04 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Standalone.
# Provides 'standalone' implementation of appserv functions which are used by
# the packages.
#
# Use this version only if you do not have access to libOT_Tcl.so
#
# Configuration:
#
# Synopsis:
#    package require bin_standalone ?4.5?
#
# Procedures:
#    asRestart
#    reqGetId
#    reqGetArg
#    reqSetArg
#    asStoreString
#    asFindString
#
#    ob_sl::init   one time initialisation

package provide bin_standalone 4.5


# Variables
#
namespace eval ob_sl {
	variable CFG
	variable INIT
	set CFG(logs,rotation)       "DAILY"
	set CFG(logs,mode)           "append"
	set CFG(logs,level)          "4"
	set CFG(logs,prefix)         ""
	set CFG(logs,prefixstr)      ""
	set CFG(logs,fd)             stdout
	set CFG(logs,next_rotation)  0 ;# Default no rotation
	set INIT 0
}


# Define the appserver functionality provided by this package
proc asRestart     {args} {return [eval ob_sl::_asRestart     $args]}
proc asGetId       {args} {return [eval ob_sl::_asGetId       $args]}
proc reqGetId      {args} {return [eval ob_sl::_reqGetId      $args]}
proc reqGetArg     {args} {return [eval ob_sl::_reqGetArg     $args]}
proc reqSetArg     {args} {return [eval ob_sl::_reqSetArg     $args]}
proc reqGetEnv     {args} {return [eval ob_sl::_reqGetEnv     $args]}
proc reqSetEnv     {args} {return [eval ob_sl::_reqSetEnv     $args]}
proc asStoreString {args} {return [eval ob_sl::_asStoreString $args]}
proc asFindString  {args} {return [eval ob_sl::_asFindString  $args]}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Package one-time initialisation.
#
# NB: Caller should initialise the log file prior to using the package, as
#     standalone log-file initialisation requires parameters which are not
#     supported in this proc.
#
#   args  - series of name value pairs which define the optional
#           configuration
#           -as_restart_exit (1|0)
#
proc ob_sl::init {args} {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# Attempt to load the shared object, if this fails then we define
	# all of the global functions that are provided via a tcl implementations
	if {[catch {load "libOT_Tcl.so"}]} {
		proc ::OT_CfgRead            {args} {return [eval ob_sl::_cfg_read      $args]}
		proc ::OT_CfgSet             {args} {return [eval ob_sl::_cfg_set       $args]}
		proc ::OT_CfgGet             {args} {return [eval ob_sl::_cfg_get       $args]}
		proc ::OT_CfgGetTrue         {args} {return [eval ob_sl::_cfg_get_true  $args]}
		proc ::OT_CfgGetNames        {args} {return [eval ob_sl::_cfg_get_names $args]}

		# Logging
		proc ::OT_LogOpen            {args} {return [eval ob_sl::_log_open $args]}
		proc ::OT_LogWrite           {args} {return [eval ob_sl::_log_write $args]}
		proc ::OT_LogClose           {args} {return [eval ob_sl::_log_close $args]}
		proc ::OT_LogLevel           {args} {return [eval ob_sl::_log_set_level $args]}
		proc ::OT_LogSetLevel        {args} {return [eval ob_sl::_log_set_level $args]}
		proc ::OT_LogGetLevel        {args} {return [eval ob_sl::_log_get_level $args]}
		proc ::OT_LogSetTiming       {args} {return}
		proc ::OT_LogGetPrefix       {args} {return [eval ob_sl::_log_get_prefix]}
		proc ::OT_LogSetPrefix       {args} {return [eval ob_sl::_log_set_prefix $args]}
		proc ::OT_LogSetAutoFlush    {args} {return}
		proc ::OT_LogGetAutoFlush    {args} {return 0}
		proc ::OT_LogGetLevelName    {args} {return [eval ob_sl::_log_get_level_name $args]}
		proc ::OT_LogSetLevelName    {args} {return [eval ob_sl::_log_set_level_name $args]}
		proc ::OT_LogDelLevelName    {args} {return [eval ob_sl::_log_delete_level_name $args]}
		proc ::OT_LogGetLevelNames   {args} {return [eval ob_sl::_log_get_level_names $args]}
		proc ::OT_LogSetLevelUnknown {args} {return [eval ob_sl::_log_set_level_unknown $args]}

		# Semaphore locking: These are all noops
		proc ::ipc_sem_create        {args} {return 1}
		proc ::ipc_sem_lock          {args} {return 1}
		proc ::ipc_sem_unlock        {args} {return}
	} else {

		# Need to ensure calls to OT_LogWrite are backwards compatible
		package require util_log
		rename OT_LogWrite ::__OT_LogWrite
		proc ::OT_LogWrite args {
			if {[llength $args] != 3} {
				set args [concat $ob_log::LOG_FD $args]
			}
			eval __OT_LogWrite $args
		}
	}

	# set optional cfg default values
	set CFG(as_restart_exit) 0
	set CFG(logs,create_on_write) 0


	# set optional cfg from supplied arguments (overwrite defaults)
	# argument names may begin with a '-'
	foreach {n v} $args {
		if {$n != "" && [string index $n 0] == "-"} {
			set n [string range $n 1 end]
		}
		set name [string tolower $n]
		if {![info exists CFG($name)] || $v == ""} {
			error "Invalid argument '$n'"
		}
		set CFG($name) $v
	}


	# initialised
	set INIT 1
}




#--------------------------------------------------------------------------
# Appserv functions
#--------------------------------------------------------------------------

# Capture restart
#
proc ob_sl::_asRestart args {
	variable CFG
	if {[info exists CFG(as_restart_exit)] &&\
		        $CFG(as_restart_exit)} {
		OT_LogWrite 1 "CRITICAL {asRestart}"
		exit
	}
}



# Get the current appserver child process
#
#   returns - current appserv child (0)
#
proc ob_sl::_asGetId args {
	return 0
}



# Get the current request number.
#
#   returns - current request number
#
proc ob_sl::_reqGetId args {
	variable REQ_ID
	if {![info exists REQ_ID]} {
		set REQ_ID 1
	}
	return $REQ_ID
}




# Replaces appserver reqSetArg
#
#	var - variable name
#	val - variable value
#
#	returns variable value
#
proc ob_sl::_reqSetArg {var val} {

	variable RARGS
	set RARGS($var) $val
	return $val
}



# Replaces appserver reqGetArg
#
#	var - variable name
#
#	returns variable value
#
proc ob_sl::_reqGetArg {var} {

	variable RARGS

	if {[info exists RARGS($var)]} {
		return $RARGS($var)
	}

	return ""
}



# Replaces appserver reqSetEnv
#
#   var - variable name
#
#   returns variable value
#
proc ob_sl::_reqSetEnv {var val} {

	variable ENV
	set ENV($var) $val
    return $val
}



# Replaces appserver reqGetEnv
#
#   var - variable name
#
#   returns variable value
#
proc ob_sl::_reqGetEnv {var} {

 	variable ENV

   if {[info exists ENV($var)]} {
        return $ENV($var)
    }

    return ""
}



#
# Replacement asStoreString
# Note: this does not incluse the first optional parameter
#
proc ob_sl::_asStoreString {str name cache} {

	variable STR

	if {[info exist STR($name)]} {
		unset STR($name)
	}

	set STR($name) $str
	set expiry [expr [clock second] + $cache]
	set STR($name,expiry) $expiry
}

#
# Replacement asFindString
#
proc ob_sl::_asFindString {name} {
	variable STR

	if {![info exist STR($name)]} {
		error "No String match for $name"
	} else {
		set now [clock second]
		if { $now > $STR($name,expiry)} {
			catch {unset STR($name)}
			error "Cache time expired for String $name"
		} else {
			return $STR($name)
		}
	}
}


#--------------------------------------------------------------------------
# OT_Cfg
#--------------------------------------------------------------------------

#
# Open and read the indicated filename
#
proc ::ob_sl::_cfg_read args {
	variable CONFIG

	# Recursive parse of the config files
	parseFile [lindex $args 0]

	# Set environment variables
	foreach env_var [OT_CfgGet ENV_VARS [list]] {
		set ::env($env_var) [OT_CfgGet $env_var {}]
	}
}


#
# Set the configuration item name to the given value. Replaces any current
# value of name. This is persistent for the duration of child process
#
proc ::ob_sl::_cfg_set {name value} {
	variable CONFIG
	set CONFIG($name) $value
}


#
# Return the value of name, or default if it is not found, and default was given.
# If it's not found, and no default is specified, then an error is thrown.
#
proc ::ob_sl::_cfg_get {name {val "empty"}} {
	variable CONFIG
	if [catch {set retval $CONFIG(${name})} msg] {
		if {$val != "empty"} {
			set retval $val
		} else {
			puts stderr "No value for mandatory config item \[$name\] $msg"
			error "No value for mandatory config item \[$name\]"
		}
	}
	return $retval
}

#
# Return true or false depending on whether the item name is an non-zero integer or
# not. If there is no item called name, then false is returned.
#
proc ::ob_sl::_cfg_get_true name {
	variable CONFIG
	if [catch {set cfgval $CONFIG(${name})} msg] {
		return 0
	} elseif {[string tolower [string index $cfgval 0]] == "y" || $cfgval == "1"} {
		return 1
	} else {
		return 0
	}
}


#
# Returns a Tcl list of all the currently defined configuration items.
#
proc ::ob_sl::_cfg_get_names args {
	variable CONFIG
	return [array names CONFIG]
}





#
# Gets config entries from file and puts them in variable CONFIG.
# Makes a recursive call on encountering an include.
#
proc ::ob_sl::cfg_parseFile {fname} {

	global env
	variable CONFIG

	if [catch {set fileid [open $fname "r"]} msg] {
		puts stderr "Cannot open file for reading: $fname, msg: $msg"
		exit 1
	}

	fconfigure $fileid -buffering line

	set prev_line ""

	while {![eof $fileid]} {
		gets $fileid line

		# cope with trailing backslashes by joining such lines with space.
		if {[regexp {\\$} $line]} {
			append prev_line "[string range $line 0 end-1] "
			continue
		} else {
			if {[string length $prev_line]} {
				set line "$prev_line $line"
			}
			set prev_line ""
		}

		# ignore comment lines beginning with # or empty lines
		if {[string index $line 0] == "#" || [regexp -- {^\s*$} $line]} {
			continue
		}

		# Support substenv
		if {[info exists SETTINGS(substenv)] && $SETTINGS(substenv) == 1} {
			catch {
				regsub -all {\$\((\S+)\)} $line {$env(\1)} unsubstval
				set line [subst -nobackslashes -nocommands $unsubstval]
			}
		}

		# Support substconf
		if {[info exists SETTINGS(substconf)] && $SETTINGS(substconf) == 1} {
			catch {
				regsub -all {\$\((\S+)\)} $line {$CONFIG(\1)} unsubstval
				set line [subst -nobackslashes -nocommands $unsubstval]
			}
		}

		# Match [spaces]arg[spaces]=[spaces]val[spaces] (val may contain spaces)
		if {[regexp {^\s*(\S*)\s*\=\s*(.*)\s*$} $line all arg val]} {
			set arg [string trim $arg]
			set val [string trim $val]
			set CONFIG(${arg}) $val
			continue
		}

		# Match !include[spaces]val[spaces]
		if {[regexp {^!pragma\s+substenv\s*$} $line all]} {
			set SETTINGS(substenv) 1
			continue
		}

		# Match !include[spaces]val[spaces]
		if {[regexp {^!pragma\s+substconf\s*$} $line all]} {
			set SETTINGS(substconf) 1
			continue
		}

		# Match !include[spaces]val[spaces]
		if {[regexp {^!include\s+(\S+)\s*$} $line all subfile]} {
			parseFile $subfile
		} else {
			puts "Ignoring rogue line in config file: \[$line\]"
		}
	}
	close $fileid
}


#--------------------------------------------------------------------------
# OT_Log
#--------------------------------------------------------------------------
#
#    log_fd - optional log file descriptor
#             if not supplied, then the util_log package descriptor is used
#    level  - log level
#    msg    - log message
#
proc ::ob_sl::_log_write {args} {

	variable CFG

	if {[llength $args] == 3} {
		set level [lindex $args 1]
		if {$CFG(logs,level) <= [ob_sl::_log_get_level_name {} $level]} {return}
		set fd    [lindex $args 0]
		set msg   [lindex $args 2]
	} elseif {[llength $args] == 2} {
		set level [lindex $args 0]
		if {$CFG(logs,level) <= [ob_sl::_log_get_level_name {} $level]} {return}
		set fd    ""
		set msg   [lindex $args 1]
	} else {
		error "usage OT_LogWrite ?log_fd? level msg"
	}

	# Pick up a new log file
	_log_rotate
	if {$fd == ""} {set fd $CFG(logs,fd)}

	puts $fd "[clock format [clock seconds] -format {%m/%d-%H:%M:%S.000}] \[${level}\] $CFG(logs,prefixstr) $msg"
	flush $fd
}


#
# Close the current log file
#
proc ::ob_sl::_log_close {args} {
	variable CFG
	# Closing stdout causes it to pause for
	# a long time.
	if {[info exists CFG(logs,fd)] && $CFG(logs,fd) != "stdout"} {
		catch {
			close $CFG(logs,fd)
		}
	}
	# Also unset incase we go from
	# stdout to a file.
	catch {unset CFG(logs,fd)}
	set CFG(logs,next_rotation) 0
}


#
# Open a new log file
#
proc ::ob_sl::_log_open {args} {
	variable CFG

	::ob_sl::_log_close

	# Read in setup
	foreach {n v} $args {
		if {$v == ""} {continue}
		set cfg_name [string tolower [string range $n 1 end]]

		if {![info exists CFG(logs,$cfg_name)] || $v == ""} {
			error "Invalid argument '$cfg_name'"
		}

		set CFG(logs,$cfg_name) $v
	}

	# Open the log file, no point catching as we want an error anyway
	set CFG(logs,file) [lindex $args end]

	# Allow log files to only be created if they are written to
	if {$CFG(logs,create_on_write) == 1} { return }

	set CFG(logs,fd)   [open [clock format [clock seconds] -format $CFG(logs,file)] a+]
	ob_sl::_set_rotation

}


#
# Rotate to the next log file if required
#
proc ::ob_sl::_log_rotate {} {
	variable LOG
	variable CFG


	if {[clock seconds] <= $CFG(logs,next_rotation)} {return}
	ob_sl::_set_rotation

	if {[info exists CFG(logs,fd)]} {
		# Special handling for stdout, dont rotate logs
		if {$CFG(logs,fd) == "stdout"} {
			return
		}
		# Close current log
		close $CFG(logs,fd)
	}
	# Open the new log
	set CFG(logs,fd) [open [clock format [clock seconds] -format $CFG(logs,file)] a+]
}


proc ::ob_sl::_set_rotation {} {
	variable CFG
	switch -- $CFG(logs,rotation) {
		"DAILY"   { set CFG(logs,next_rotation)   [expr {[clock seconds] + 86400}] }
		"HOURLY"  { set CFG(logs,next_rotation)   [expr {[clock seconds] + 3600}] }
		"default" { set CFG(logs,next_rotation)   [expr {[clock seconds] + 3600}] }
	}
}



#
# Set the log prefix
#
proc ::ob_sl::_log_set_prefix {{prefix ""}} {
	variable CFG
	if {$prefix == ""} {
		set CFG(logs,prefix) ""
		set CFG(logs,prefixstr) "$prefix"
	} else {
		set CFG(logs,prefix) "$prefix"
		set CFG(logs,prefixstr) "<$prefix>"
	}
}



#
# Return the current log prefix
#
proc ::ob_sl::_log_get_prefix {} {
	variable CFG
	return $CFG(logs,prefix)
}



#
# set the current log level
#
proc ::ob_sl::_log_set_level {level} {
	variable CFG

	set CFG(logs,level) $level
}



#
# Return the current log level
#
proc ::ob_sl::_log_get_level {args} {
	variable CFG
	return $CFG(logs,level)
}


#
# Sets the logging level for the named logging level name to value for the given log. value must be an integer.
#
proc ::ob_sl::_log_set_level_name {args} {
	variable CFG
	variable LOG_LEVELS
	if {[llength $args] > 2} {
		set name  [lindex $args 1]
		set value [lindex $args 2]
	} else {
		set name  [lindex $args 0]
		set value [lindex $args 1]
	}
	set LOG_LEVELS($name) $value
}


#
# Returns the loggig level number associated with the symbolic logging level name for the given log.
#
proc ::ob_sl::_log_get_level_name {args} {
	variable CFG
	variable LOG_LEVELS
	set name [lindex $args 1]
	if {[info exists LOG_LEVELS($name)]} {
		return $LOG_LEVELS($name)
	} else {
		return $name
	}
}


#
# Deletes the named logging level name from the given log.
#
proc ::ob_sl::_log_delete_level_name {name} {
	variable LOG_LEVELS
	catch {unset LOG_LEVELS($name)}
}


#
# returns a Tcl list consisting of all the named logging levels and their associated numbers for log.
# The list is flat (it doesn't contain sublists)
#
proc ::ob_sl::_log_get_level_names {args} {
	variable LOG_LEVELS
	return [array names LOG_LEVELS]
}



#------------------------------------------------------
# Helper Functions
#------------------------------------------------------


# Increment the current request number.
# NB: Not an appserv function
#
#   returns - current request number
#
proc ob_sl::_reqIncrId args {
	variable REQ_ID
	if {![info exists REQ_ID]} {
		set REQ_ID 1
	} else {
		incr REQ_ID
	}

	return $REQ_ID
}


