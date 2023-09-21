# $Id: err.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# Error Handler
#
# Synopsis:
#    package require office ?1.0?
#
# Configuration:
#     XL_LANG                 language (en)
#
# Procedures:
#   office::err::add          add an error message
#   office::err::xl_add       add an error code and translate
#   office::err::db_add       add a DB exception message
#   office::err::get_total    get total number of error messages
#   office::err::get          get all error messages
#   office::err::clear        clear all error messages
#


# Namespace Variables
#
namespace eval ob_office::err {

	variable ERR
	variable CFG
	variable REQ_NO
}



#--------------------------------------------------------------------------
# Init
#--------------------------------------------------------------------------

# Private procedure to perform one time init
#
proc ob_office::err::_init args {

	variable CFG

	if {[info exists CFG]} {
		return
	}

	# dependencies
	package require util_xl
	ob_xl::init

	ob_log::write INFO {OFFICE: err init}

	set CFG(lang) [OT_CfgGet XL_LANG en]
}



# Private procedure to auto reset the error list.
# - If the request number has changed, then clear the error list.
#
proc ob_office::err::_auto_reset args {

	variable ERR
	variable REQ_NO

	set id [reqGetId]
	if {![info exists REQ_NO] || $REQ_NO != $id} {
		set REQ_NO $id
		catch {unset ERR}
	}
}



#--------------------------------------------------------------------------
# Add
#--------------------------------------------------------------------------

# Add a message to the internal error list.
#
#   msg       - error message
#   sym_level - symbolic log-level
#   action    - action which triggered the error
#
proc ob_office::err::add { msg sym_level action } {

	variable ERR
	variable CFG

	# if different request, reset
	_auto_reset

	ob_log::write $sym_level {OFFICE: err $action $msg}

	if {![info exists ERR($action)]} {
		set ERR($action) [list]
	}
	lappend ERR($action) $msg
}



# Add an XL code to the internal error list.
#
#   code      - XL code
#   sym_level - symbolic log-level
#   action    - action which triggered the error
#   args      - XL arguments (optional)
#
proc ob_office::err::xl_add { code sym_level action args } {

	variable CFG

	set msg [eval {ob_xl::sprintf $CFG(lang) $code} $args]
	add $msg $sym_level $action
}



# Add a DB exception to the internal error list.
#
#   exp       - exception message
#   sym_level - symbolic log-level
#   action    - action which triggered the error
#
proc ob_office::err::db_add { exp sym_level action } {

	if {![regexp {^(inf_exec_stmt: \(-746\) )(.+)$} $exp all crud msg]} {
		return [add $exp $sym_level $action]
	}
	add $msg $sym_level $action
}



#--------------------------------------------------------------------------
# Get
#--------------------------------------------------------------------------

# Get the total number of error message added within the scope of the current
# request.
#
#   action  - action which triggered the error
#   returns - total error messages
#
proc ob_office::err::get_total { action }  {

	variable ERR

	# if different request, reset
	_auto_reset

	if {[info exists ERR($action)]} {
		return [llength $ERR($action)]
	}

	return 0
}



# Get all the error messages added within the scope of this request.
#
#   action  - action which triggered the error
#   sep     - separator between each returned error message (default: <br>)
#   returns - tcl list of error messages, delimited by sep
#             or an empty list of no errors
#
proc ob_office::err::get { action {sep "<br/>"} } {

	variable ERR

	# if different request, reset
	_auto_reset

	ob_log::write DEV {OFFICE: err $ERR($action)}

	if {[info exists ERR($action)]} {
		return [join $ERR($action) $sep]
	}

	return [list]
}



#--------------------------------------------------------------------------
# Clear
#--------------------------------------------------------------------------

# Clear all the error messages added.
#
proc ob_office::err::clear args {

	variable ERR

	catch {unset ERR}
}
