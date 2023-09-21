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
# Synopsis:
#   package require core::db::failover ?1.0?
#
#

set pkgVersion 1.0

# Dependecies
package provide core::db::failover $pkgVersion
package require core::log    1.0
package require core::check  1.0
package require core::args   1.0

core::args::register_ns \
	-namespace core::db::failover \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args] \
	-docs      db/db-failover.xml

# Variables
namespace eval core::db::failover {

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

	# a list of database types
	set CFG(packages) [list informix postgresql mysql]
	set CFG(actions)  [list RESTART NOOP REPREP RECONN]

	# Initialize error codes list for all database types
	foreach package $CFG(packages) {
		set CFG($package,err_codes) [list]
	}

	# Default policy to implement
	set ACTIONS(default)            [list RESTART]
	set ACTIONS(informix,default)   [list RESTART]
	set ACTIONS(postgresql,default) [list RESTART]
	set ACTIONS(mysql,default)      [list RESTART]

	# ------------------------------------------------------------------------
	#                              INFORMIX
	# ------------------------------------------------------------------------

	# A list of informix error codes which doesn't behave as the default behav.
	set CFG(informix,err_codes) [list \
		-255    \
		-268    \
		-391    \
		-530    \
		-746    \
		-1213   \
		-1262   \
		-243    \
		-244    \
		-245    \
		-710    \
		-721    \
		-908    \
		-934    \
		-1803   \
		-25582  \
		-25580]

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
	set ACTIONS(informix,-1213) [list LOG]
	set ACTIONS(informix,-1262) [list LOG]

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
	set ACTIONS(informix,-243)  [list NOOP {core::db::failover::_log_locks $conn_name}]
	set ACTIONS(informix,-244)  [list NOOP {core::db::failover::_log_locks $conn_name}]
	set ACTIONS(informix,-245)  [list NOOP {core::db::failover::_log_locks $conn_name}]

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
	#   -934    Connection to remote site no longer valid.
	#   -1803   Connection does not exist.
	#   -25582  Network connection is broken.
	#   -25580  System error occurred in network function.
	#
	set ACTIONS(informix,-908)   [list RECONN]
	 set ACTIONS(informix,-934)   [list RECONN]
	set ACTIONS(informix,-1803)  [list RECONN]
	set ACTIONS(informix,-25582) [list RECONN]
	set ACTIONS(informix,-25580) [list RECONN]

	# Don't require restart for postgres FK constraint error
	set ACTIONS(postgresql,23503) [list NOOP]
}



#---------------------------------------------------------------------------
# Initialisation
#---------------------------------------------------------------------------

core::args::register \
	-proc_name core::db::failover::init \
	-args [list \
		[list -arg -log_locks -mand 0 -check BOOL -default 0 -desc {Log locks if an error has occured they occur}] \
	]

# Initialise.
# @param -log_locks  Log locks if an error has occured they occur
proc core::db::failover::init args {

	variable INIT
	variable CFG

	array set ARGS [core::args::check core::db::failover::init {*}$args]

	if {$INIT} {
		return
	}

	set INIT 1

	set CFG(log_locks) $ARGS(-log_locks)
}

core::args::register \
	-proc_name core::db::failover::handle_error \
	-args [list \
		[list -arg -conn_name -mand 1 -check ASCII -desc {Symbolic connection name}] \
		[list -arg -package   -mand 1 -check ASCII -desc {Flavour of database (Informix, PostgreSQL, MySql etc)}] \
		[list -arg -attempt   -mand 1 -check UINT  -desc {Index of the attempt (0 or 1)}] \
		[list -arg -msg       -mand 1 -check ANY   -desc {The error message, used for logging only}] \
	]
# Find out what to do when a certain error occurs.
#
# @param -conn_name Name of the database connection, often $::DB
# @param -package   Flavour of database (Informix, PostgreSQL, MySql etc)
# @param -attempt   Index of the attempt (0 or 1)
# @param -msg       The error message, used for logging only
# @return           Action to be handled by the callee
#
proc core::db::failover::handle_error args {

	variable ACTIONS

	array set ARGS [core::args::check core::db::failover::handle_error {*}$args]

	set conn_name $ARGS(-conn_name)
	set attempt   $ARGS(-attempt)
	set msg       $ARGS(-msg)

	# We may need these later, so store them now.
	set info $::errorInfo
	set code $::errorCode

	set num default

	# Some applications may be using a DB_PACKAGE in camelcase (OXi) - since
	# all the packages we're catching in here are in lowercase we do this to
	# be safe
	set package [string tolower $ARGS(-package)]

	# Find our from the message rather than using inf_last_err_msg, since this
	# will be zero if there has been database interaction since the error
	# occured.
	#
	switch -exact -- $package {
		"informix" {
			regexp -- {-[0-9]+} $msg num
		}
		"postgresql" {
			regexp -- {ERROR:  (\d+):} $msg -> num
		}
	}

	set error_tag "$package,$num"
	if {![info exists ACTIONS($error_tag)]} {
		set error_tag "$package,default"
		if {![info exists ACTIONS($error_tag)]} {
			set error_tag default
		}
	}

	core::log::write INFO {DB $conn_name: (failover) ($num): $msg}

	foreach action [lrange $ACTIONS($error_tag) 1 end] {
		eval $action
	}

	if {$attempt == 0} {
		set action [lindex $ACTIONS($error_tag) 0]
	} else {
		set action RESTART
	}

	if {$action != "NOOP"} {
		core::log::write INFO {DB $conn_name: (failover) Recommending $action for $msg}
	}

	return $action
}



# Log lock if they occur, but only if configured.
#
# @param -conn_name Unique name to identify the connection
#
proc core::db::failover::_log_locks {conn_name} {

	variable CFG

	if {!$CFG(log_locks)} {
		return
	}

	ob_db_multi::log_locks $conn_name
}

core::args::register \
	-proc_name core::db::failover::check_conn_status \
	-args [list \
		[list -arg -conn_name -mand 1 -check ASCII -desc {Symbolic connection name}] \
	]

# Check if a db connection is flagged in shared memory as ok
#
# @param -conn_name Unique name to identify the connection
#
proc core::db::failover::check_conn_status args {

	array set ARGS [core::args::check core::db::failover::check_conn_status {*}$args]

	set conn_name $ARGS(-conn_name)

	if {[catch { set conn_status [asFindString db_failover($conn_name,status)] } err]} {
		return 0
	}


	if {$conn_status == "A"} {
		return 1
	}

	core::log::write INFO {DB $conn_name: Status is $conn_status}

	return 0
}

core::args::register \
	-proc_name core::db::failover::set_conn_status \
	-args [list \
		[list -arg -conn_name -mand 1 -check ASCII -desc {Symbolic connection name}] \
		[list -arg -status    -mand 1 -check ASCII -desc {(A)ctive | (S)uspended}] \
	]

# Check if a db connection is flagged in shared memory as ok
#
# @param -conn_name Unique name to identify the connection
# @param -status    (A)ctive | (S)uspended
#
proc core::db::failover::set_conn_status args {

	array set ARGS [core::args::check core::db::failover::set_conn_status {*}$args]

	set conn_name $ARGS(-conn_name)
	set status    $ARGS(-status)

	core::log::write INFO {DB $conn_name: Setting status to $status}
	asStoreString $status db_failover($conn_name,status) 10000000
}


core::args::register \
	-proc_name core::db::failover::get_conn_delay \
	-args [list \
		[list -arg -conn_name -mand 1 -check ASCII -desc {Symbolic connection name}] \
	]

# Check if a db connection has a registerd delay against it
#
# @param -conn_name Unique name to identify the connection
#
proc core::db::failover::get_conn_delay args {

	variable CONN_DELAY

	array set ARGS [core::args::check core::db::failover::get_conn_delay {*}$args]

	set conn_name $ARGS(-conn_name)

	# Try and get it from cache
	if {[info exists CONN_DELAY($conn_name,[reqGetId])]} {
		return $CONN_DELAY($conn_name,[reqGetId])
	}

	catch {unset CONN_DELAY}

	set delay 10000000
	if {![catch { set delay_ts [asFindString db_failover($conn_name,delay)] } err]} {
		set delay [expr {[clock seconds] - $delay_ts}]
	}

	core::log::write INFO {DB $conn_name: Connection delay is $delay}

	set CONN_DELAY($conn_name,[reqGetId]) $delay
	return $CONN_DELAY($conn_name,[reqGetId])
}

core::args::register \
	-proc_name core::db::failover::set_conn_delay \
	-args [list \
		[list -arg -conn_name -mand 1 -check ASCII -desc {Symbolic connection name}] \
		[list -arg -delay     -mand 1 -check UINT  -desc {current delay in seconds}] \
	]

# Check if a db connection is flagged in shared memory as ok
#
# @param -conn_name Unique name to identify the connection
# @param -delay     Current delay in seconds
#
proc core::db::failover::set_conn_delay args {

	variable CONN_DELAY

	catch {unset CONN_DELAY}

	array set ARGS [core::args::check core::db::failover::set_conn_delay {*}$args]

	set conn_name $ARGS(-conn_name)
	set delay     $ARGS(-delay)

	set CONN_DELAY($conn_name,[reqGetId]) $delay

	core::log::write INFO {DB $conn_name: Setting connection delay is $delay}

	asStoreString [expr {[clock seconds] - $delay}] db_failover($conn_name,delay) 10000000
}

core::args::register \
	-proc_name core::db::failover::reconfig_action \
	-args [list \
		[list -arg -err_code -mand 1 -check ASCII                     -desc {A numeric database error code}] \
		[list -arg -action   -mand 1 -check ASCII                     -desc {Valid failover action (RESTART, NOOP, LOG, REPREP, RECONN etc)}] \
		[list -arg -command  -mand 0 -check ASCII -default {}         -desc {Let the user specify a custom follow-up command}] \
		[list -arg -package  -mand 0 -check ASCII -default {informix} -desc {Flavour of database (Informix, PostgreSQL, MySql etc)}] \
	]

# Allows runtime reconfiguration of actions
#
# @param -err_code  A numeric database error code
# @param -action    one of core::db::failover::$CFG(actions)
# @param -command   Let the user specify a custom follow-up command
# @param -package   Flavour of database (Informix, PostgreSQL, MySql etc)
#
# @return            0 for failure, 1 for success
#
proc core::db::failover::reconfig_action args {

	variable CFG
	variable ACTIONS

	array set ARGS [core::args::check core::db::failover::reconfig_action {*}$args]

	set err_code $ARGS(-err_code)
	set action   $ARGS(-action)
	set command  $ARGS(-command)
	set package  $ARGS(-package)

	# Is the DB one of the configured ones?
	if {[lsearch -exact $CFG(packages) $package] == -1 } {
		core::log::write ERROR {DB : cannot reconfig this database package}
		return 0
	}

	# Validate numeric error code
	if {![regexp {^[-|][0-9]+$} $err_code] } {
		core::log::write ERROR {DB : cannot reconfig - invalid error type type}
		return 0
	}

	# Validate the action
	if { [lsearch -exact $CFG(actions) $action] == -1 } {
		core::log::write ERROR {DB : cannot reconfig - invalid action}
		return 0
	}

	# Set / overwrite the new action
	set ACTIONS($package,$err_code) [list $action]

	# Have we specified a command, if so set it
	if {$command != ""} { lappend ACTIONS($package,$err_code) $command }

	core::log::write INFO \
		{DB : Have reconfigured ACTION($package,$err_code) -> $action}

	# Success
	return 1

}

# Mass Reconfiguration of a specific failover action to another
core::args::register \
	-proc_name core::db::failover::reconfigure_all_failover \
	-args [list \
		[list -arg -old_action -mand 1 -check ASCII -desc {Valid failover action (RESTART, NOOP, LOG, REPREP, RECONN etc)}] \
		[list -arg -new_action -mand 1 -check ASCII -desc {Valid failover action (RESTART, NOOP, LOG, REPREP, RECONN etc)}] \
	] \
	-body {
		variable CFG
		variable ACTIONS

		set old_action $ARGS(-old_action)
		set new_action $ARGS(-new_action)

		# Validate the action
		if { [lsearch -exact $CFG(actions) $old_action] == -1 ||
			[lsearch -exact $CFG(actions) $new_action] == -1 } {
			core::log::write ERROR {DB : cannot reconfig - invalid action}
			return 0
		}

		# For all database types
		foreach package $CFG(packages) {

			core::log::write INFO {DB : reconfiguring '$package' errors}

			# For all errors defined for this database
			foreach db_err $CFG($package,err_codes) {

				# Current error
				set act  [lindex $ACTIONS($package,$db_err) 0]

				# Is one of the desired actions? This will overwrite any custom
				# follow up function
				if {$act == $old_action} {
					set ACTIONS($package,$db_err) [list $new_action]
					core::log::write INFO {DB : Reconfigured $package - err $db_err \
										to $new_action (was $old_action)}

				}
			}
		}

		return 1
	}
