#-----------------------------------------------------
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/standalone.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Standalone tcl shared functions
# (c) Orbis Technology 2008Z
#
# This is a compatibility module for bin_standalone
# if you are writting new code do not use this file
#
# use:
#	package require bin_standalone
#	ob_sl::init -appserv
#-----------------------------------------------------

catch {load libOT_Tcl.so}

# Hack to ensure support of shared_tcl in the autopath
lappend auto_path shared_tcl tcl/shared_tcl
package require bin_standalone 4.5


# legacy support
#----------------------------------
proc readConfigs {} {return [readConfig]}

proc readConfig {}  {
	global LOG
	global LOG_PREFIX
	global CONFIG

	ob_sl::init

	# Read the config file
	if {[info exists ::argv] && [lindex $::argv 0] != ""} {
		OT_CfgRead [lindex $::argv 0]
	}

	# Initialise the log file
	package require util_log
	ob_log::sl_init [OT_CfgGet LOG_DIR] [OT_CfgGet LOG_FILE]


	# Set up legacy globals (DO NOT USE THESE)
	foreach cfg [OT_CfgGetNames] { set CONFIG($cfg) [OT_CfgGet $cfg] }
	set LOG(fd)       [get_log_fd]
	set LOG(logLevel) [OT_CfgGet LOG_LEVEL NULL]
	set LOG_PREFIX    ""
	return 1
}

rename OT_LogWrite _local_OT_LogWrite
proc OT_LogWrite args {
	global LOG
	global LOG_PREFIX

	set prefix ""
	if {$LOG_PREFIX != ""} {
		set prefix "<$LOG_PREFIX> "
	}

	if {[llength $args] > 2} {
		_local_OT_LogWrite [lindex $args 0] [lindex $args 1] "$prefix[lindex $args 2]"
	} else {
		_local_OT_LogWrite $LOG(fd) [lindex $args 0] "$prefix[lindex $args 1]"
	}
}

# Hacks to handle the old standalone.tcl's ability to maintain multiple logfiles.
# This is at the moment purely for the benefit of the PAFeed. If we need to do
# this again in future it should be done 'properly' (giving ob_log the ability
# to maintain multiple logfiles)
# Changed for Ladbrokes Italia as it was causing problems on IPN settler
rename OT_LogSetPrefix _local_OT_LogSetPrefix
proc OT_LogSetPrefix args {
		set prefix [lindex $args end]
        global LOG_PREFIX
        set LOG_PREFIX $prefix
}

# Return our current fd, if we've switched away from the default
proc get_log_fd {} {
	global LOG
	if {[info exists LOG(active_fds)]} {
		return [lindex $LOG(active_fds) end]
	} else {
		return $ob_log::LOG_FD
	}
}

# Add new logfile to the stack
proc set_log_fd {name} {
	global LOG
	lappend LOG(active_fds) $name
	set LOG(fd) [get_log_fd]
}

# Remove a logfile from the remaining stack
proc unset_log_fd {name} {
	global LOG
	set index [lsearch $LOG(active_fds) $name]
	if {$index > -1} {
		set LOG(active_fds) [lreplace $LOG(active_fds) $index end]
	}

	# Have we removed all our additional logs? If so we unset completely and go back
	# to using the level defined in ob_log
	if {[llength $LOG(active_fds)] == 0} {
		unset LOG(active_fds)
	}

	set LOG(fd) [get_log_fd]
}
