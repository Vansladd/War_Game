# $Id: err.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# © 2004 Orbis Technology Ltd. All Rights Reserved.
#
# This package provide a common interface for logging errors.
# An error is assumed to consist of the following.
#
#   timestamp
#   level (CRITICAL, ERROR, WARNING)
#   message
#   information
#
# This package has to deal with the possibility of errors being both front
# end and backend. If it is unable to find reqGetId it assumes it's a front end
# (possibly a back office) application, rather than, say, a cron job.
#
# Synposis:
#   package require util_err ?4.5?
#
# Configration:
#   none
#
# Procedures:
#   ob_err::init      - initialise
#   ob_err::clean_up  - clear all errors
#   ob_err::add       - add an error
#   ob_err::get       - get the error list
#   ob_err::send_mail - send an email about the errors
#

package provide util_err 4.5



# Dependencies
#
package require util_log
package require util_email



# Variables
#
namespace eval ob_err {

	# list of errors
	#
	variable errors [list]
	variable last_req_id -1
	variable INIT 0
	variable CFG
}



#--------------------------------------------------------------------------
# Initialise
#--------------------------------------------------------------------------

# Initialise error handelling.
#
proc ob_err::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	set INIT 1

	ob_log::init
	ob_email::init

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} [list \
		from [pwd]@[info hostname] \
		to   "" \
	] {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet ERR_[string toupper $n] $v]
		}
	}
}



#--------------------------------------------------------------------------
# Procedures
#--------------------------------------------------------------------------

# Reset the namespace
#
proc ob_err::_auto_reset {} {

	variable last_req_id

	# if this is not an appserver, then don't even try to reset
	if {[info commands reqGetId] == "" || $last_req_id == [reqGetId]} {
		return
	}

	set last_req_id [reqGetId]

	clean_up
}



# Add an error to the system.
#
#   level - error level
#   msg   - error message
#   info  - error info
#
proc ob_err::add {level msg {info ""}} {

	variable errors

	_auto_reset

	ob_log::write $level {err: $msg}

	if {$info != ""} {
		ob_log::write $level {err: $info}
	}

	set timestamp [clock format [clock scan now] -format {%Y-%m-%d %H:%M:%S}]

	lappend errors $timestamp $level $msg $info
}



# Cleans up the errors. Should be called before the begining of any process.
#
proc ob_err::clean_up {} {

	variable errors [list]
}



# Get a list of errors
#
#   returns - a list of errors
#
proc ob_err::get {} {

	variable errors

	_auto_reset

	return $errors
}



# Email the errors to the supplied person. Will only email if there are errors.
#
#   from    - email from address (config)
#   to      - email to address (config)
#   subject - email subject (config)
#   throws  - email server communcation errors
#
proc ob_err::send_email {{from ""} {to ""} {subject ""}} {

	variable CFG
	variable errors

	_auto_reset

	if {[llength $errors] == 0} {
		return
	}

	if {$from == ""} {
		set from $CFG(from)
	}

	if {$to == ""} {
		set to $CFG(to)
	}

	if {$subject == ""} {
		set subject "Error occured on job/server: [info hostname]:[pwd]"
	}

	set plain "Errors occured on job/server:\n"
	append plain \n
	append plain "[info hostname]:[pwd]\n"
	append plain \n
	append plain "Errors occured while proccessing.\n"
	append plain \n

	set html "Errors occured on job/server:<br>\n"
	append html "<br>\n"
	append html "<b>[info hostname]:[pwd]</b><br>\n"
	append html "<br>\n"
	append html "Errors occured while proccessing:<br>\n"
	append html "<br>\n"

	# add each error to the email, we try to order them by date and then severity
	foreach {date lev msg info} $errors {

		append plain "$lev $msg\n"

		set map {CRITICAL #990 ERROR #900 WARNING #930 INFO #090 DEBUG #009}
		set c [string map $map $lev]
		append html "<b>$date</b> <b style='color: $c'> $lev</b> $msg<br>\n"

		if {$info != ""} {
			append plain "$info\n"
			append html  "<pre>$info</pre>\n"
		}
	}

	ob_email::send \
		-from    $from \
		-to      $to \
		-subject $subject \
		-plain   $plain \
		-html    $html
}
