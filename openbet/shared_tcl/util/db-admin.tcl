# $Id: db-admin.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for openbet/admin/tcl/db.tcl
# Admin screens uses it's own database API, e.g. does not store query plans or
# uses cached result-sets, etc., therefore, to provide support for shared_tcl in
# Admin, the wrapper utilies the same package API interface but calls admin
# APIs.
#
# Not all the util/db.tcl APIs are used, therefore, if a caller attempts to
# use these within the Admin screens, a tcl error will be generated (caller
# should not be using the API!)
#
# pkgIndex will load the correct file, depending on the setting of admin_screens
# global. If set to 0 (default), then util/db.tcl will be loaded, else this file
# will be loaded. The APIs will be transparent to the caller.
#
# Note, you can use this will the admin screens (or any other application
# which creates it's own database connection, this will use an existing
# connection if it finds it.
#
# This version supports 'format specified queries' in a simliar way to OXi.
# By using any of the specifers used by format (e.g. %s, %u), the query
# automatically becomes identified as 'specified'. This means that this first
# n arguments are taken to fulfill the specifiers.
#
# Configuration:
#    DB_SERVER            database server
#    DB_DATABASE          database
#    DB_USERNAME          username                              - (0)
#    DB_PASSWORD          password                              - (0)
#    DB_WAIT_TIME         set lock wait time                    - (20)
#    DB_ISOLATION_LEVEL   set isolation level                   - (0)
#    DB_USE_FETCH         use fetch when requested              - (1)
#    DB_LOG_QRY_TEXT      log each query                        - (0)
#    DB_LOG_LOCKS         print out the database server's lock when we get
#                         log each query errors                 - (0)
#    DB_LOG_QRY_TIME      enable log query times                - (0)
#    DB_LOG_LONGQ         log all queries with exe time > value - (99999999.9)
#    DB_LOG_QRY_PARAMS    whether to log the query arguments    - (0)
#
# Synopsis:
#     package require util_db ?4.5?
#
# Procedures:
#    ob_db::init                   dummy one time init
#    ob_db::store_qry              stored a named query
#    ob_db::unprep_qry             unprepare a named query
#    ob_db::exec_qry               execute a named query
#    ob_db::rs_close               close a result set
#    ob_db::garc                   get number of rows effect by last stmt
#    ob_db::get_serial_number      get serial number created by last insert
#    ob_db::begin_tran             begin transaction
#    ob_db::commit_tran            commit transaction
#    ob_db::rollback_tran          rollback transaction
#    ob_db::req_end                clean up request
#    ob_db::get_err_code           get last Informix error code
#    ob_db::foreachrow             loop over a recordset
#

package provide util_db 4.5
package require util_db_failover


# Variables
#
namespace eval ob_db {
	global DB
	variable CFG
	variable DB_DATA
	variable INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_db::init args {

	global DB
	variable CFG
	variable DB_DATA
	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init
	ob_db_failover::init

	ob_log::write DEBUG {DB: (admin) init}

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		server   openbet
		database openbet
		username ""
		password ""
		wait_time       0
		isolation_level 0
		use_fetch       1
		log_qry_text    0
		log_locks       0
		log_qry_time    0
		log_longq       99999999.9
		log_qry_params  0
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet DB_[string toupper $n] $v]
		}
	}

	ob_db_failover::init -log_locks $CFG(log_locks)

	# Load the Informix C libraries
	if { [catch {
		package present Infsql
	}] } {

		if { [catch {
			load libOT_InfTcl.so
		} err] } {
			error "failed to load Informix TCL library: $err"
		}

	}

	if {$CFG(server) == "" || $CFG(database) == ""} {
		error "The sever or database is blank"
	}

	_connect

	set DB_DATA(rs_list) [list]

	set INIT 1
}



# Attempt to connect to the database as specifed by the configuration.
# If this fails, we re-start the appserv process.
#
#    force   - force warning if already connected
#
proc ob_db::_connect { {force 0} } {

	global DB
	variable CFG

	# this may be used as part of a legacy application, if so then
	# it shouldn't try to create a new connection, just use the
	# existing one. In face the lock modes and wait times are important
	# for the legacy application, then we won't make any attempt to change the.
	if {!$force && [info exists DB]} {
		ob_log::write WARNING {DB: already connected, aborting new connection}
		return
	}

	ob_log::write INFO {DB: connecting to $CFG(database)@$CFG(server)}

	if {[catch {
		if {$CFG(username) == ""} {
			set DB [inf_open_conn $CFG(database)@$CFG(server)]
		} else {
			set DB [inf_open_conn $CFG(database)@$CFG(server) $CFG(username) \
				$CFG(password)]
		}
	} msg]} {
		asRestart
		error "DB: failed to open connection $msg"
	}

	# set lock mode (seconds)
	if {$CFG(wait_time) != 0} {
		ob_log::write DEBUG {DB: set lock mode to $CFG(wait_time)}

		set stmt [inf_prep_sql $DB "set lock mode to wait $CFG(wait_time)"]

		inf_exec_stmt $stmt
		inf_close_stmt $stmt
	}

	# set isolation level
	if {$CFG(isolation_level) != 0} {
		ob_log::write DEBUG {DB: set iso level to $CFG(isolation_level)}

		set stmt [inf_prep_sql $DB "set isolation to $CFG(isolation_level)"]

		inf_exec_stmt $stmt
		inf_close_stmt $stmt
	}
}





#--------------------------------------------------------------------------
# Prepare Queries
#--------------------------------------------------------------------------

# Store a query.
# Admin does not support this functionality, therefore, store the query within
# a package array to be referenced on execution or preparation.
#
#   name  - query name
#   qry   - SQL query
#   cache - result set cache time (seconds)
#           result-cache is not supported by Admin
#
proc ob_db::store_qry { name qry {cache 0} } {

	variable DB_DATA

	# validate
	if {[info exists DB_DATA($name)]} {
		error "Query $name already exists"
	}
	if {$name == "rs" || [regexp {,} $name]} {
		error "Illegal query name - $name"
	}

	# add query to list
	set DB_DATA($name) $qry
}



# Unprepare a stored name query.
#
#   name - query name
#
proc ob_db::unprep_qry { name } {
	variable DB_DATA

	ob_log::write DEBUG {DB: Unpreparing statement $name}

	if {![info exists DB_DATA($name)]} {
		error "Query $name does not exists"
	}

	unset DB_DATA($name)

	array unset DB_DATA $name,*
}



# Prepares a query, and updates the arguments.
#
#   name    - SQL query name
#   argsvar - the name of the variable in the calling scope which contains the
#             query arguments, this may contain fewer variables after calling
#   returns - stmt
#
proc ob_db::_prep_sql {name argsvar} {

	global DB
	variable CFG
	variable DB_DATA

	# upvar, so any changes to args here, effects args in the calling scope
	upvar 1 $argsvar args

	# count the number of specfiers in the sql using a regular expression
	set num_specifiers [regsub -all {%[duixXcsfeEgG]} $DB_DATA($name) {} {}]

	if {$num_specifiers > 0} {
		ob_log::write DEBUG \
			{DB: Preparing statement with $num_specifiers specifiers}

		set specifiers [lrange $args 0 [expr {$num_specifiers - 1}]]
		set args       [lrange $args $num_specifiers end]

		set sql [eval [list format $DB_DATA($name)] $specifiers]

	} else {
		set sql $DB_DATA($name)
	}

	if {$CFG(log_qry_text)} {
		ob_log::write INFO {DB: $name=$sql}
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
	} msg]} {
		ob_db_failover::handle_error $DB $CFG(server) 0 $msg
		asRestart
		error $msg $::errorInfo $::errorCode
	}

	return $stmt
}



# No need to force as admin doesn't use any caching - just execute as normal
#
#   name    - SQL query name
#   args    - query arguments
#   returns - query [cached] result set
#
proc ob_db::exec_qry_force {name args} {

	return [eval {exec_qry $name} $args]

}



# Execute a named query.
# Admin does not prepare queries, therefore, after the statement is executed,
# it's always closed (even on error). Supports format specifiers in SQL.
#
#   name    - SQL query name
#   args    - query arguments
#   returns - query [cached] result set
#
proc ob_db::exec_qry {name args} {

	global DB
	variable CFG
	variable DB_DATA

	if {![info exists DB_DATA($name)]} {
		error "DB: statement $name does not exist"
	}

	# execute the name'd query (always close the statement)
	set stmt [_prep_sql $name args]

	set t0 [OT_MicroTime -micro]

	if {[catch {
		# support the -inc-type specifier for CLOB/BLOB insert
		if {[lindex $args 0] == "-inc-type"} {

			# call exec_stmt with all but the first item in args (-inc-type)
			set _args [lreplace $args 0 0]
			set rs [eval [list inf_exec_stmt -inc-type $stmt] $_args]
		} else {
			set rs [eval [list inf_exec_stmt $stmt] $args]
		}
	} msg]} {
		inf_close_stmt $stmt

		if {[ob_db_failover::handle_error $DB $CFG(server) 0 $msg] != "NOOP"} {
			asRestart
		}
		error $msg $::errorInfo $::errorCode
	}

	# store the serial and nrow before we close the stmt, this
	# way we can return information about them
	set DB_DATA($name,serial) [inf_get_serial $stmt]
	set DB_DATA($name,nrows)  [inf_get_row_count $stmt]

	_log_qry_time EXEC $name $args $t0 [OT_MicroTime -micro]

	inf_close_stmt $stmt

	# lets store the rs so we can make sure that it is cleaned up at the end
	if {$rs != ""} {
		lappend DB_DATA(rs_list) $rs
	}

	return $rs
}



# Log the query time if needs be
#
#   conn_name - connection name
#   name      - query name
#   vals      - argument to the query
#   t0        - query start time
#   t1        - query end time
#
proc ob_db::_log_qry_time {prefix name vals t0 t1} {

	variable CFG

	set tt [expr {$t1 - $t0}]
	set ft [format {%0.4f} $tt]

	# log the query which exceeds CFG(log_longq)
	if {$tt > $CFG(log_longq)} {
		ob_log::write_qry INFO \
			"DB::LONGQ" \
			"$name $ft rowcount = [garc $name]" \
			$name \
			$vals
	} elseif {$CFG(log_qry_time) || $CFG(log_qry_params)} {
		ob_log::write INFO {DB: ::$prefix $name took $ft args were: $vals}
	}
}



#--------------------------------------------------------------------------
# Transactions
#--------------------------------------------------------------------------

# Begin a transaction.
#
proc ob_db::begin_tran args {

	global DB
	inf_begin_tran $DB
}



# Commit a transaction
#
proc ob_db::commit_tran args {

	global DB
	inf_commit_tran $DB
}



# Rollback a transaction
#
proc ob_db::rollback_tran args {

	global DB
	inf_rollback_tran $DB
}



#--------------------------------------------------------------------------
# Request
#--------------------------------------------------------------------------

# Denote an appserv request has ended.
# This procedure MUST be called at the end of every request.
# Clean up accidently left open recordsets, and attempt to rollback
# any open transactions. Clear any request specific data that might be
# lying around. We expect this to be successful, if not there is a
# (very small) chance that the nrows and serial will be carried over.
# However, you would expect in all normal situations (those not picked
# up by debugging) that this would never happen.
#
proc ob_db::req_end {} {

	variable DB_DATA

	if {[llength $DB_DATA(rs_list)]} {
		ob_log::write ERROR \
			{DB: unclosed result sets ($DB_DATA(rs_list)) at end of request}
	}

	foreach rs $DB_DATA(rs_list) {
		catch {rs_close $rs}
	}

	# emtpy the recordset list
	set DB_DATA(rs_list) [list]

	# clear all old nrows and serial numbers
	array unset DB_DATA *,serial
	array unset DB_DATA *,nrows

	if {![catch {rollback_tran}]} {
		ob_log::write ERROR {DB: rollback of transaction succeeded}
	}
}



#--------------------------------------------------------------------------
# Result Sets
#--------------------------------------------------------------------------

# Close a result set.
#
#   rs - result set to close
#
proc ob_db::rs_close rs {

	variable DB_DATA

	# remove the recordset for the list
	set i [lsearch $DB_DATA(rs_list) $rs]

	if {$i >= 0} {
		set DB_DATA(rs_list) [lreplace $DB_DATA(rs_list) $i $i]
	}

	db_close $rs
}



# Get the number of rows affected by the last statement
#
#  name    - named SQL query
#  returns - the number of rows effected by the specfied statement,
#            or throws an error if not known
#
proc ob_db::garc name {

	variable DB_DATA

	if {[info exists DB_DATA($name,nrows)]} {
		return $DB_DATA($name,nrows)
	} else {
		ob_log::write WARNING {DB: number of rows unknown}
		return 0
	}
}



# Get serial number created by the last insert
#
#   name    - stored query name
#   returns - the serial number of the last insert,
#             or throws an error if not known
#
proc ob_db::get_serial_number { name } {

	variable DB_DATA

	if {[info exists DB_DATA($name,serial)]} {
		return $DB_DATA($name,serial)
	} else {
		error "Serial unknown"
	}
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Gets the last Informix error code
#
#   returns - last Informix error code
#
proc ob_db::get_err_code args {

	return [inf_last_err_num]
}



# Repeatedly calls the tcl code for each row. For each of the columns the
# the variable with the same in the calling scope is set to the value
# of the column. Supports format specifiers in SQL.
#
# foreachrow ?-fetch? ?-force? ?-colnamesvar colnames? ?-rowvar r?
#   ?-nrowsvar nrows? qry ?arg...? tcl
#
#
#   -fetch               - use informix fetch if available (may not be honored).
#                          fetch should be used very sparingly, it is sutiable
#                          for cron jobs, when it will reduce memory load, and
#                          for unordered queries be somewhat faster.
#                          there are two problems with it.
#
#                          firstly, fetch cannot be used within a transaction,
#                          nor can transaction occur during a fetch.
#
#                          both of these cases will throw errors.
#
#   -force               - disable variable name conflict checking, use this if
#                          you execute a query which has a column which will
#                          conflict with a variable in the calling scope
#
#   -colnamesvar varname - stmt of a variable to populate with a list of
#                          columns names
#   -rowvar      varname - name of a variable to populate with the row number,
#                          this is only visible during the execution of the qry
#   -nrowsvar    varname - a variable to be populate with the number of rows,
#                          this may only visible after completion
#   stmt                 - query stmt
#   arg                  - query arguments
#   tcl                  - tcl to execute for each row
#   returns              - last value returned by tcl
#   throws               - any errors due to tcl (recordset is cleaned up)
#
proc ob_db::foreachrow args {

	global DB

	variable CFG
	variable DB_DATA

	#
	# parse the arguments
	#
	set fetch 0
	set force 0

	for {set i 0} {$i < [llength $args]} {incr i} {
		set arg [lindex $args $i]
		switch -- $arg {
			-fetch {
				set fetch 1
			}
			-force {
				set force 1
			}
			-colnamesvar {
				set colnamesvar ""
			}
			-nrowsvar {
				set nrowsvar ""
			}
			-rowvar {
				set rowvar ""
			}
			default {
				if {[info exists colnamesvar] && $colnamesvar == ""} {
					set colnamesvar $arg
				} elseif {[info exists nrowsvar] && $nrowsvar == ""} {
					set nrowsvar $arg
				} elseif {[info exists rowvar] && $rowvar == ""} {
					set rowvar $arg
				} else {
					break
				}
			}
		}
	}

	set name  [lindex $args $i]
	set argz  [lrange $args [incr i] end-1]
	set tcl   [lindex $args end]

	unset i args

	# check the query exists
	if {![info exists DB_DATA($name)]} {
		error "Query $name not found"
	}

	set caught 0
	set msg    ""

	if {[info exists colnamesvar]} {
		upvar 1 $colnamesvar colnames
	}

	if {[info exists nrowsvar]} {
		upvar 1 $nrowsvar nrows
	}

	if {[info exists rowvar]} {
		upvar 1 $rowvar row
	}

	# fetch version
	if {$fetch && $CFG(use_fetch)} {

		ob_log::write DEV {DB: foreachrow fetching $name $argz}

		set stmt [_prep_sql $name argz]

		set t0 [OT_MicroTime -micro]

		if {[catch {
			if {[lindex $argz 0] == "-inc-type"} {
				set colnames [eval {inf_exec_stmt_for_fetch -inc-type $stmt} \
					[lrange $argz 1 end]]
			} else {
				set colnames [eval {inf_exec_stmt_for_fetch $stmt} $argz]
			}
		} msg]} {
			ob_db_failover::handle_error $DB $CFG(server) 0 $msg
			asRestart
			error $msg $::errorInfo $::errorCode
		}

		# this may be an underestimate, the database may still be doing the
		# query while we are doing work this side
		_log_qry_time FOREACHROW $name $argz $t0 [OT_MicroTime -micro]


		# check that the variables do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists $n]]} {
					inf_fetch_done $stmt
					inf_close_stmt $stmt

					error "Variable $n already exists in calling scope"
				}
			}
		}

		set row 0
		while {[set colvalues [inf_fetch $stmt]] != ""} {

			# set the column variables
			foreach n $colnames v $colvalues {
				uplevel 1 [list set $n $v]
			}

			set caught [catch {uplevel 1 $tcl} msg]

			# error, return, break
			if {[lsearch {1 2 3} $caught] >= 0} {
				break
			}

			# unset the column variables
			if {!$force} {
				foreach n $colnames {
					uplevel 1 [list unset $n]
				}
			}

			incr row
		}

		set nrows $row

		unset row

		# clean up
		inf_fetch_done $stmt
		inf_close_stmt $stmt

		ob_log::write DEV {DB: $nrows rows fetched}

	} else {

		set rs [eval exec_qry $name $argz]

		set nrows    [db_get_nrows $rs]
		set colnames [db_get_colnames $rs]

		# check that the variable do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists $n]]} {
					rs_close $rs

					error "Variable $n already exists in calling scope"
				}
			}
		}

		for {set row 0} {$row < $nrows} {incr row} {

			# set the column variables
			foreach n $colnames {
				uplevel 1 [list set $n [db_get_col $rs $row $n]]
			}

			set caught [catch {uplevel 1 $tcl} msg]

			# error, return, break
			if {[lsearch {1 2 3} $caught] >= 0} {
				break
			}

			# unset the column variables
			if {!$force} {
				foreach n $colnames {
					uplevel 1 [list unset $n]
				}
			}
		}

		if {[info exists row]} {
			unset row
		}

		# clean up
		rs_close $rs

	}

	# there are 'exceptional' returns, and is effective in the calling scope
	# see PP in TCL and TK, 3rd edition, Chapter 6, Page 80
	switch $caught {
		1 {
			return -code error -errorinfo $::errorInfo -errorcode $::errorCode \
				$msg
		}
		2 {
			return -code return $msg
		}
		default {
			return $msg
		}
	}
}
