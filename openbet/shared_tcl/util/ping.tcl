# $Id: ping.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Openbet Web Ping utility.
# Used to test the internal state of an application
#

package provide util_ping 4.5

package require util_log
package require util_db

# Variables
#
namespace eval ob_ping {
	variable INIT
	variable PING

	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_ping::init args {

	variable INIT
	variable PING

	# initialised the package?
	if {$INIT} {
		return
	}

	ob_log::init
	ob_db::init

	# Install action handlers
	asSetAct ob_ping ob_ping::H_ping

	# Basic DB check
	add_check DB "ob_ping::db_check"

	# Prepare queries
	_prep_qry

	# initialised
	set INIT 1
}



# Internal proc to prepare queries
#
proc ob_ping::_prep_qry {} {

	ob_db::store_qry ob_ping::db_check {
		select
			*
		from
			tcontrol
	}
}



# Proc to add a check
#
#   check    - Code of the check
#   callback - Callback name for the check
#   returns  - status
#
proc ob_ping::add_check { check callback } {
	variable PING

	lappend PING(checks) $check
	set PING($check,callback) $callback
}



#--------------------------------------------------------------------------
# Request Handling
#--------------------------------------------------------------------------

# Action Handler for Ping
#
proc ob_ping::H_ping {} {
	variable PING

	foreach chk $PING(checks) {
		set PING($chk,status) [eval $PING($chk,callback)]
	}

	# Send the response
	_send_response
}



# DB Check
#
#   returns - status (OK|FAILED)
#
proc ob_ping::db_check {} {

	if {[catch {set rs [ob_db::exec_qry ob_ping::db_check]}]} {
		set status "FAILED"
	} else {
		ob_db::rs_close $rs
		set status "OK"
	}

	return $status
}



# Internal proc to send the response
#
proc ob_ping::_send_response {} {
	variable PING

	set response "APP: OK; "

	foreach n $PING(checks) {
		append response "$n: $PING($n,status); "
	}

	set ping_resp [subst {
			<html>
				<head><title>Web Ping</title></head>
					<body>
						<pre>
							$response
						</pre>
					</body>
			</html>
		}]

	tpBufWrite $ping_resp
}
