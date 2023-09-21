# $Id: session.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# API for session management
#
# Configuration:
#    CUST_SESSION_TYPE session type (OB|IGF)   - (OB)
#
# Synopsis:
#    package require cust_session ?4.5?
#
# Procedures:
#    ob_session::init             one time init
#    ob_session::start            start a session
#    ob_session::check            check if a session is valid
#    ob_session::end              end a session
#    ob_session::cancel           cancel a session
#    ob_session::get              get a session
#    ob_session::clear            clear a session
#

package provide cust_session 4.5



# Dependencies
#
package require util_log     4.5
package require util_db      4.5



# Variables
#
namespace eval ob_session {

	variable INIT
	variable SESSION

	set INIT 0
	set SESSION(req_no) ""
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_session::init {} {

	variable INIT

	if {$INIT} {
		return
	}

	# dependencies
	ob_db::init
	ob_log::init

	ob_log::write DEBUG {SESSION: init}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "LOGIN: reqGetId not available for auto reset"
	}

	variable SESSION_TYPE [OT_CfgGet CUST_SESSION_TYPE OB]

	_prepare_qrys

	set INIT 1
}



# Private procedure to prepare queries
#
proc ob_session::_prepare_qrys {} {

	variable SESSION_TYPE

	if { $SESSION_TYPE eq "OB" } {

		ob_db::store_qry ob_session::start {

			execute procedure pSessionStart (
				p_cust_id      = ?,
				p_user_id      = ?,
				p_term_code    = ?,
				p_source       = ?,
				p_aff_id       = ?,
				p_ipaddr       = ?,
				p_session_type = ?,
				p_expire_mins  = ?,
				p_do_tran      = ?
			);

		}

		ob_db::store_qry ob_session::check {

			execute procedure pSessionCheck (
				p_session_id = ?,
				p_ipaddr     = ?
			);

		}

		ob_db::store_qry ob_session::end {

			execute procedure pSessionEnd (
				p_session_id = ?
			);

		}

		ob_db::store_qry ob_session::cancel {

			execute procedure pSessionCancel (
				p_session_id  = ?,
				p_cancel_code = ?,
				p_cancel_txt  = ?
			);

		}

	} else {

		ob_db::store_qry ob_session::start {

			execute procedure pCgSessionStart (
				p_cust_id      = ?,
				p_user_id      = ?,
				p_term_code    = ?,
				p_source       = ?,
				p_aff_id       = ?,
				p_ipaddr       = ?,
				p_session_type = ?,
				p_expire_mins  = ?,
				p_do_tran      = ?
			);

		}

		ob_db::store_qry ob_session::check {

			execute procedure pCgSessionCheck (
				p_session_id = ?,
				p_ipaddr     = ?
			);

		}

		ob_db::store_qry ob_session::end {

			execute procedure pCGSessionEnd (
				p_session_id = ?,
				p_end_reason = ?
			);

		}

		ob_db::store_qry ob_session::cancel {

			execute procedure pCgSessionCancel (
				p_session_id  = ?,
				p_cancel_code = ?,
				p_cancel_txt  = ?
			);

		}

	}

	ob_db::store_qry ob_session::get {

		select
			session_id,
			cust_id,
			user_id,
			term_code,
			start_time,
			end_time,
			session_type,
			aff_id,
			source,
			ipaddr,
			status,
			start_balance,
			first_bet,
			session_ack_due,
			stakes,
			winnings
		from
			tCustSession
		where
			session_id = ?;

	}

}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_session::_auto_reset args {

	variable SESSION

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$SESSION(req_no) != $id} {
		catch {unset SESSION}
		set SESSION(req_no) $id

		ob_log::write DEV {LOGIN: auto reset cache, req_no=$id}
		return 1
	}

	# already loaded
	return 0
}



#-------------------------------------------------------------------------------
# Session
#-------------------------------------------------------------------------------

# Start a customer session.
#
# Before attempting to create a session, any active sessions for the customer
# will be terminated if they have:
# - a specified expiry time that has passed
# - no expiry, but have not recorded an action within the login_keepalive (as
#   specified in tChannel)
#
# For session type 'M', multiple sessions, a new session is created provided
# there are no active exclusive sessions for the customer.
#
# For session type 'X', exclusive session, a new session cannot be created
# unless the old sessions are terminated.
#
#    cust_id       - customer identifier
#    user_id       - user identifier (default: "")
#    term_code     - teminal code (default: "")
#    source        - source/channel (default: I)
#    session type  - session type (default: M)
#    aff_id        - affiliate identifier (default: "")
#    expire_mins   - expire time, minutes (default: "")
#    in_tran       - Whether we are already in a transacton (default: 0)
#    returns       - status string (OB_OK denotes success)
#
proc ob_session::start {
	  cust_id
	{ user_id      "" }
	{ term_code    "" }
	{ source        I }
	{ session_type  M }
	{ aff_id       "" }
	{ expire_mins  "" }
	{ in_tran       0 }
} {
	variable SESSION

	set ipaddr [reqGetEnv REMOTE_ADDR]

	if { [catch {
		set rs [ob_db::exec_qry ob_session::start \
			$cust_id\
			$user_id\
			$term_code\
			$source\
			$aff_id\
			$ipaddr\
			$session_type\
			$expire_mins\
			[expr { $in_tran ? "N" : "Y" }]\
		]
	} msg] } {

		if { [regexp {ERR:\w+:IGF:SQL:\w+} $msg] } {
			return $msg
		} else {
			error "query ob_session::start : $msg"
		}

	}

	_auto_reset

	set SESSION(session_id) [db_get_coln $rs 0]

	ob_db::rs_close $rs

	ob_log::write INFO {SESSION: opened session $SESSION(session_id)}
	return OB_OK
}



# Check if there is an active session for this session id.
# A row in tActiveSession should exists for the check to succeed.
#
#    session_id    - session identifier
#    ipaddr        - IP address (default: "" - which case get from env.)
#    returns       - status string (OB_OK denotes success)
#
#
proc ob_session::check { session_id {ipaddr ""} } {

	variable SESSION

	if {$ipaddr == ""} {
		set ipaddr [reqGetEnv REMOTE_ADDR]
	}

	_auto_reset

	if {[catch {
		set rs [ob_db::exec_qry ob_session::check $session_id $ipaddr]
	} msg]} {

		ob_log::write ERROR {SESSION: check failed : $msg}

		if { [regexp {ERR:\w+:IGF:SQL:\w+} $msg] } {
			return $msg
		} else {
			error "query ob_session::check failed : $msg"
		}

	}

	set check_flg [db_get_coln $rs 0 0]

	ob_db::rs_close $rs

	if {$check_flg == 0} {
		return OB_ERR_SESSION_CHK
	}

	set SESSION(session_id) $session_id

	get

	return OB_OK

}



# Ends session for customer currently logged in.
#
#   session_id     - session identifier
#   end_reason     - reason that the session was ended
#   (e.g. L - Logout, T - Timeout, P - Single Session Time Limit
#         C - Cummulative Session Time Limit)
#   returns        - status string (OB_OK denotes success)
#
proc ob_session::end { session_id { end_reason L } } {

	if {[catch {
		set rs [ob_db::exec_qry ob_session::end $session_id $end_reason]
	} msg]} {

		ob_log::write ERROR {SESSION: end failed : $msg}

		if { [regexp {ERR:\w+:IGF:SQL:\w+} $msg] } {
			return $msg
		} else {
			error "query ob_session::end failed : $msg"
		}

	}

	ob_db::rs_close $rs

	return OB_OK
}



# Cancels a session for customer. Ends the session and and records a reason as
# to why the session was ended.
#
#   session_id     - session identifier
#   cancel_code    - cancel code
#   cancel_txt     - cancel text
#   returns        - status string (OB_OK denotes success)
#
proc ob_session::cancel {session_id cancel_code cancel_txt} {

	if {[catch {
		set rs [ob_db::exec_qry ob_session::cancel\
	            $session_id\
	            $cancel_code\
	            $cancel_txt\
	]} msg]} {

		ob_log::write ERROR {SESSION: cancel failed : $msg}

		if { [regexp {ERR:\w+:IGF:SQL:\w+} $msg] } {
			return $msg
		} else {
			error "query ob_session::cancel failed : $msg"
		}

	}

	ob_db::rs_close $rs

	return OB_OK

}



# Retrieve session details
#
#    name          - session detail name
#    dflt          - default value (default: "")
#    returns       - session detail, or 'dflt' if not defined
#
proc ob_session::get {{name ""} {dflt ""}} {

	variable SESSION

	if {[_auto_reset]
			|| ![info exists SESSION(session_id)]
			|| $SESSION(session_id) == ""
	} {
		return $dflt
	}

	#
	# info already exists
	#
	if {[info exists SESSION($name)]} {
		return $SESSION($name)
	}

	#
	# Run the query if the information doesn't exist
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_session::get $SESSION(session_id)]
	} msg]} {
		ob_log::write ERROR {SESSION :get failed : $msg}
		error "ob_session::get failed : $msg"
	}

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		error "ob_session::get num_rows != 1"
	}

	foreach c [db_get_colnames $rs] {
		set SESSION($c) [db_get_col $rs 0 $c]
	}
	ob_db::rs_close $rs

	if {$name == ""} {
		return $dflt
	}

	if {![info exists SESSION($name)]} {
		error "can't read SESSION($name): no such variable"
	}

	return $SESSION($name)
}


# Clear session cache.
#
proc ob_session::clear {} {

	variable SESSION

	unset SESSION
	set SESSION(req_no) -1
}
