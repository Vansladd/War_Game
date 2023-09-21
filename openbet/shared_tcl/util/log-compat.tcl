# $Id: log-compat.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle compatibility with shared_pkg/util/log package OB_Log v1.0
#
# The package provides wrapper for each of OB_Log APIs which are potentially
# still been used within other shared_tcl files or the calling application.
# Avoid calling the wrapper APIs within your applications, always use the
# util_log package (ob_log namespace).
#
# If the package OB_Log is required, the util pkgIndex will require this
# package instead. Always set the auto_path of the packages before shared_pkg,
# to avoid loading the original OB_Log.
#
# The package should always be loaded when using util_log 4.5 package.
#
# Uses the configuration of util_log package.
#
# Synopsis
#     package require util_log_compat 4.5
#
# Procedures
#     ob::log::init              one time initialisation (does nothing)
#     ob::log::set_default_log   set the default log descriptor (does nothing)
#     ob::log::write             write a message
#     ob::log::write_array       write the contents of an array
#     ob::log::write_stack       write the contents of the stack
#


package provide OB_Log 1.0
package provide util_log_compat 4.5


# Dependencies
#
package require util_log



# Variables
#
namespace eval ob::log {
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialise
# - does nothing, use ob_log::init or ob_log::sl_init instead
#
proc ob::log::init args {
	ob_log::init $args
}



#--------------------------------------------------------------------------
# Set
#--------------------------------------------------------------------------

# Set the default log descriptor.
# Not supported.
#
proc ob::log::set_default_log { {name default} } {
}



#--------------------------------------------------------------------------
# Write messages
#--------------------------------------------------------------------------

# Write a log message
#
#   ?log? level message
#
#   log     - log file descriptor (always ignored)
#   level   - symbolic level name
#   message - log message (should be enclosed in braces, instead of quotes)
#
proc ob::log::write args {

	switch -- [llength $args] {
		2 {
			foreach {level msg} $args {}
			set msg [uplevel subst [list $msg]]
			ob_log::write $level {$msg}
		}
		3 {
			foreach {log_fd level msg} $args {}
			set msg [uplevel subst [list $msg]]
			ob_log::write $level {$msg}
		}
		default {
			error "Usage: ob::log::write ?log? level message"
		}
	}
}



# Write the contents of an array
#
#   level - symbolic level name
#   arr   - array to log
#
proc ob::log::write_array { level arr } {

	uplevel 1 [list ob_log::write_array $level $arr]
}



# Write the contents of the stack (excluding this proc call)
#
#   level - symbolic level name
#
proc ob::log::write_stack { level } {

	uplevel 1 [list ob_log::write_stack $level]
}
