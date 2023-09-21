# $Id: db-failover.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# Provide interface independent database failover support.
#
# When an database error occurs, we may find that we wish to do something
# about it, and then if this fails, we may wish to bounce the
# process. While this package won't do anything about the problem, it will
# recommend a suitable action for the calling package to take.
#
# The reasons are two fold. Firsly, is doens't know the correct set of
# procedures to use to access the database. Secondly, the callee might wish to
# do something differently to other systems.
#
# Configuration:
#    DB_FAILOVER_LOG_LOCKS - log locks if an error has occured they occur (0)
#
# Synopsis:
#   package require util_db_failover ?4.5?
#
# Procedures:
#    ob_db_failover::init         - initilaise
#    ob_db_failover::handle_error - find out how to handle an error
#



# Dependecies
#
package provide util_db_failover 4.5
package require util_log



# Variables
#
namespace eval ob_db_failover {

	variable INIT 0
	variable CFG


	# Format of array.
	#
	# The first element is what the callee should do, either re-prepare the
	# query, re-connect to the database, or if noop then do nothing.
	#
	# The rest of the elements are commands to call.
	#
	variable ACTIONS

	# Default policy to implement
	set ACTIONS(default)            [list RESTART]
	set ACTIONS(informix,default)   [list RESTART]
	set ACTIONS(postgresql,default) [list RESTART]
	set ACTIONS(mysql,default)      [list RESTART]

	# Expected and easily managed errors.
	#
	#   -255    Not in transaction.
	#   -268    Unique constraint <constraint-name> violated.
	#   -391    Cannot insert a null into column column-name.
	#   -530    Check constraint constraint-name failed.
	#   -746    User defined exception.
	#   -1213   A character to numeric conversion process failed.
	#   -1262   Non-numeric character in datetime or interval.
	#
	set ACTIONS(informix,-255)  [list NOOP]
	set ACTIONS(informix,-268)  [list NOOP]
	set ACTIONS(informix,-391)  [list NOOP]
	set ACTIONS(informix,-530)  [list NOOP]
	set ACTIONS(informix,-746)  [list NOOP]
	set ACTIONS(informix,-1213) [list NOOP]
	set ACTIONS(informix,-1262) [list NOOP]

	# These are (normally) caused by locking problems: we'll optionally
	# list out all the db server's locks when this happens and restart the
	# app server
	#
	#   -243   Could not position within a table table-name.
	#   -244   Could not do a physical-order read to fetch next row.
	#   -245   Could not position within a file via an index.
	#
	# Related ISAM error codes:
	#   -107   Record is locked.
	#   -113   The file is locked.
	#   -143   Deadlock detected.
	#   -144   Key value locked.
	#   -154   Lock Timeout Expired.
	#
	set ACTIONS(informix,-243)  [list NOOP {ob_db_failover::_log_locks $conn_name}]
	set ACTIONS(informix,-244)  [list NOOP {ob_db_failover::_log_locks $conn_name}]
	set ACTIONS(informix,-245)  [list NOOP {ob_db_failover::_log_locks $conn_name}]

	# These error require the queries to be re-prepared.
	#
	#   -710   Table table-name has been dropped, altered, or renamed.
	#   -721   SPL routine (<routine-name>) is no longer valid.
	#
	set ACTIONS(informix,-710)  [list REPREP]
	set ACTIONS(informix,-721)  [list REPREP]

	# These errors require the database connection to be recreated.
	#
	#   -908    Attempt to connect to database server (servername) failed.
	#   -1803   Connection does not exist.
	#   -25582  Network connection is broken.
	#   -25580  System error occurred in network function.
	#
	set ACTIONS(informix,-908)   [list RECONN]
	set ACTIONS(informix,-1803)  [list RECONN]
	set ACTIONS(informix,-25582) [list RECONN]
	set ACTIONS(informix,-25580) [list RECONN]
}



#---------------------------------------------------------------------------
# Initialisation
#---------------------------------------------------------------------------

# Initialise.
#
proc ob_db_failover::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	set INIT 1

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		log_locks       0
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet DB_FAILOVER_[string toupper $n] $v]
		}
	}
}



#---------------------------------------------------------------------------
# Procedures
#---------------------------------------------------------------------------

# Find out what to do when a certain error occurs.
#
#   conn    - name of the database connection, often $::DB
#   attempt - index of the attempt (0 or 1)
#   msg     - the error message, used for logging only
#   returns - a recommendation for the callee
#
proc ob_db_failover::handle_error {conn_name dbtype attempt msg} {

	variable ACTIONS

	# We may need these later, so store them now.
	#
	set info $::errorInfo
	set code $::errorCode
	# Convert the dbtype to lower case to match the Actions tag
	set dbtype [string tolower $dbtype]

	set num default

	# Find our from the message rather than using inf_last_err_msg, since this
	# will be zero if there has been database interaction since the error
	# occured.
	#
	regexp -- {-[0-9]+} $msg num

	set error_tag "$dbtype,$num"
	if {![info exists ACTIONS($error_tag)]} {
		set error_tag "$dbtype,default"
		if {![info exists ACTIONS($error_tag)]} {
			set error_tag default
		}
	}

	ob_log::write INFO {DB $conn_name: (failover) ($num): $msg}

	foreach action [lrange $ACTIONS($error_tag) 1 end] {
		eval $action
	}

	if {$attempt == 0} {
		set action [lindex $ACTIONS($error_tag) 0]
	} else {
		set action RESTART
	}

	if {$action != "NOOP"} {
		ob_log::write INFO {DB $conn_name: (failover) Recommending $action for $msg}
	}

	return $action
}



# Log lock if they occur, but only if configured.
#
#   conn - connection
#
proc ob_db_failover::_log_locks {conn_name} {

	variable CFG

	if {!$CFG(log_locks)} {
		return
	}

	ob_db_multi::log_locks $conn_name
}



# Check if a db connection is flagged in shared memory as ok
#
#   conn - connection
#
proc ob_db_failover::check_conn_status {conn_name} {

	if {[catch { set conn_status [asFindString db_failover($conn_name,status)] } err]} {
		return 0
	}


	if {$conn_status == "A"} {
		return 1
	}

	ob_log::write INFO {DB $conn_name: Status is $conn_status}

	return 0
}


# Check if a db connection is flagged in shared memory as ok
#   conn   - connection
#   status - (A)ctive | (S)uspended
#
proc ob_db_failover::set_conn_status {conn_name status} {
	ob_log::write INFO {DB $conn_name: Setting status to $status}
	asStoreString $status db_failover($conn_name,status) 10000000
}




# Check if a db connection has a registerd delay against it
#
#   conn - connection
#
proc ob_db_failover::get_conn_delay {conn_name} {

	variable CONN_DELAY

	# Try and get it from cache
	if {[info exists CONN_DELAY($conn_name,[reqGetId])]} {
		return $CONN_DELAY($conn_name,[reqGetId])
	}

	catch {unset CONN_DELAY}

	set delay 10000000
	if {![catch { set delay_ts [asFindString db_failover($conn_name,delay)] } err]} {
		set delay [expr {[clock seconds] - $delay_ts}]
	}

	ob_log::write INFO {DB $conn_name: Connection delay is $delay}

	set CONN_DELAY($conn_name,[reqGetId]) $delay
	return $CONN_DELAY($conn_name,[reqGetId])
}


# Check if a db connection is flagged in shared memory as ok
#   conn   - connection
#   delay  - current delay in seconds
#
proc ob_db_failover::set_conn_delay {conn_name delay} {

	variable CONN_DELAY

	catch {unset CONN_DELAY}

	set CONN_DELAY($conn_name,[reqGetId]) $delay

	ob_log::write INFO {DB $conn_name: Setting connection delay is $delay}

	asStoreString [expr {[clock seconds] - $delay}] db_failover($conn_name,delay) 10000000
}



