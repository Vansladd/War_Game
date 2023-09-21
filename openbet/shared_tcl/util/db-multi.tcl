# $Id: db-multi.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for Informix C API.
# Package allows multi-connections to an Informix database.
# All the other shared_tcl packages use a single connection model, by util_db
# opening connection via this package with the connection name 'PRIMARY'.
# Secondary connection cannot be supported within the shared_tcl packages,
# as all interface via util_db. Therefore, only use secondary connections
# directly.
#
# Required Configuration:
#     none; configuration via init parameters
#
# Synopsis:
#     package require util_db_multi ?4.5?
#
# If not using the package within appserv, then load libOT_InfTcl.so and
# libOT_Tcl.so.
#
# Procedures:
#    ob_db_multi::init               one time connection initialisation
#                                    create a connection
#    ob_db_multi::disconnect         disconnect from a named database connection
#    ob_db_multi::store_qry          store a named query
#    ob_db_multi::unprep_qry         unprepare stored named query
#    ob_db_multi::invalidate_qry     invalidate a query
#    ob_db_multi::exec_qry           execute a named query
#    ob_db_multi::exec_qry_force     execute a forced named query
#    ob_db_multi::foreachrow         foreach row procedure
#    ob_db_multi::rs_close           close a result set
#    ob_db_multi::garc               get number of rows effect by last stmt
#    ob_db_multi::get_serial_number  get serial number created by last insert
#    ob_db_multi::begin_tran         begin transaction
#    ob_db_multi::commit_tran        commit transaction
#    ob_db_multi::rollback_tran      rollback transaction
#    ob_db_multi::req_end            end a request
#    ob_db_multi::push_pdq           push PDQ
#    ob_db_multi::pop_pdq            pop PDQ
#    ob_db_multi::get_err_code       get last Informix error code
#

package provide util_db_multi 4.5


# Dependencies
#
package require util_log         4.5
package require util_db_failover 4.5



# Variables
#
namespace eval ob_db_multi {

	variable CFG
	variable CONN
	variable PDQ_LIST
	variable DB_DATA
	variable IN_TRAN
	variable TRAN_START

	# configuration
	array set CFG [list]

	# connections
	array set CONN [list]

	# PDQ stack
	array set PDQ_LIST [list]

	# in a transaction
	array set IN_TRAN [list]
	array set TRAN_START [list]
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time connection initialisation.
# Create a 'named' connection (all other API calls will use this name to
# identify the connection).
#
#   conn_name - unique name to identify the connection
#   servers   - database server name (a list can be supplied and one will be
#               randomly chosen)
#   database  - database name
#   args      - series of name value paris which define optional configuration -
#               -db_port (""|port)       default: ""
#               -username (0|username)   default: 0
#               -password (0|password)   default: 0
#               -prep_ondemand (1|0)     default: 1
#               -no_cache (1|0)          default: 0
#               -log_qry_time (1|0)      default: 1
#               -log_longq (seconds)     default: 99999999.9
#               -log_bufreads (1|0)      default: 0
#               -log_explain             default: 0
#               -wait_time (seconds)     default: 20
#               -isolation_level (value) default: 0
#               -default_pdq (value)     default: 0
#               -max_pdq (value)         default: 0
#               -use_fetch (1|0)         default: 1
#
proc ob_db_multi::init { conn_name servers database args } {

	variable CFG
	variable INIT
	variable CONN
	variable DB_DATA

	# initialised the connection
	if {[info exists CONN($conn_name)]} {
		ob_log::write WARNING {DB $conn_name: already initialised connection}
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db_failover::init

	ob_log::write INFO {DB $conn_name: init}

	# required cfg
	set CFG($conn_name,servers)  $servers
	set CFG($conn_name,database) $database

	# set optional cfg default values
	set CFG($conn_name,username)          0
	set CFG($conn_name,password)          0
	set CFG($conn_name,prep_ondemand)     1
	set CFG($conn_name,no_cache)          0

	set CFG($conn_name,log_qry_params)    1
	set CFG($conn_name,log_qry_time)      1
	set CFG($conn_name,log_qry_nrows)     1
	set CFG($conn_name,log_longq)         99999999.9
	set CFG($conn_name,log_explain)       0
	set CFG($conn_name,log_on_error)      1
	set CFG($conn_name,log_bufreads)      0
	set CFG($conn_name,log_err)           1

	set CFG($conn_name,wait_time)         20
	set CFG($conn_name,isolation_level)   0
	set CFG($conn_name,default_pdq)       0
	set CFG($conn_name,max_pdq)           0
	set CFG($conn_name,use_fetch)         1
	set CFG($conn_name,package)          "informix"

	# Postgres specific
	set CFG($conn_name,statement_timeout) 0    ;

	set CFG($conn_name,restart_on_error)  1    ;# Should failure on a connections restart process

	set CFG($conn_name,failover)          0    ;# Should this db failover
	set CFG($conn_name,delayed)           0    ;# Is the db delayed
	set CFG($conn_name,reduce_cache)      0    ;# Reduce cache times by current db delay

	set CFG($conn_name,failover,min_cache) 5   ;# Min resultant cache time for a query
	set CFG($conn_name,failover,max_delay) 30  ;# Delay on a replicated db before failover

	set CFG($conn_name,db_port)           ""   ;# Which port to connect on

	# These configs are switchable by the calling code
	set CFG($conn_name,log_qry_params,switchable)    1
	set CFG($conn_name,log_qry_time,switchable)      1
	set CFG($conn_name,log_qry_nrows,switchable)     1
	set CFG($conn_name,log_longq,switchable)         1
	set CFG($conn_name,log_explain,switchable)       1
	set CFG($conn_name,log_on_error,switchable)      1

	# set optional cfg from supplied arguments (overwrite defaults)
	foreach {n v} $args {
		set cfg_name [string tolower [string range $n 1 end]]
		if {![info exists CFG($conn_name,$cfg_name)]} {
			error "Invalid argument '$n'"
		}
		set CFG($conn_name,$cfg_name) $v
	}

	# Setup failover db
	if {$CFG($conn_name,failover) != 0} {
		set CFG($conn_name,failover,db) $CFG($conn_name,failover)
		set CFG($conn_name,failover) 1
	}

	# application server have shm_cache support
	if {[info commands asFindRs] == "asFindRs"} {
		set CFG($conn_name,shm_cache) 1
	} else {
		set CFG($conn_name,shm_cache) 0
	}

	# application server have status string support
	if {[info commands asSetStatus] == "asSetStatus"} {
		set CFG($conn_name,set_status) 1
	} else {
		set CFG($conn_name,set_status) 0
	}

	# application server can report current status
	if {[info commands asGetStatus] == "asGetStatus"} {
		set CFG($conn_name,get_status) 1
	} else {
		set CFG($conn_name,get_status) 0
	}

	# Ensure we have the correct db package available
	# and configure capabilities for different providers
	switch -- [string toupper $CFG($conn_name,package)] {
		INFORMIX   {
			package require util_db_informix
			set CFG($conn_name,namespace) db_informix
		}
		INFSQL   {
			package require util_db_informix
			set CFG($conn_name,namespace) db_informix
		}
		POSTGRESQL {
			package require util_db_postgreSQL
			set CFG($conn_name,namespace) db_postgreSQL
			set CFG($conn_name,use_fetch) 0
			set CFG($conn_name,wait_time) 0
		}
		MYSQL {
			package require util_db_mySQL
			set CFG($conn_name,namespace) db_mySQL
			set CFG($conn_name,use_fetch) 0
		}
		default    {error "Unrecognised db package"}
	}

	# bufreadss query prepared stmt
	set DB_DATA($conn_name,bufreads) ""

	# If we have been passed multiple servers then randomnly choose one,
	# this is used to load balance across multiple services preventing
	# a single port becoming overloaded
	set len [llength $CFG($conn_name,servers)]
	if {$len > 1} {
		set CFG($conn_name,server) [lindex $CFG($conn_name,servers) [expr {int(rand() * $len)}]]
	} else {
		set CFG($conn_name,server) $CFG($conn_name,servers)
	}

	# connect to the db server
	_connect $conn_name

	# result set cache/expire time (lists kept in expiry time order)
	set DB_DATA($conn_name,rs_list) [list]
	set DB_DATA($conn_name,rs_exp)  [list]

	# init result-set cache
	set DB_DATA($conn_name,rss) {}

	$CFG($conn_name,namespace)::set_timeout $CONN($conn_name) $CFG($conn_name,statement_timeout)
}



# Private procedure to connect to the database server using cfg values.
# If the connection fails, asRestart will be called. Standalone scripts
# must supply asRestart procedure.
#
#   conn_name - unique name to identify the connection
#
proc ob_db_multi::_connect { conn_name } {

	variable CFG
	variable CONN
	variable PDQ_LIST
	variable DB_LIST
	variable DB_DATA
	variable BUFREADS

	set serv  $CFG($conn_name,server)
	set dbase $CFG($conn_name,database)
	set port  $CFG($conn_name,db_port)

	ob_log::write INFO {DB $conn_name: running ${dbase}@${serv}:$port  $CFG($conn_name,username) $CFG($conn_name,password)}

	# connect
	if {[catch {
		# for postgress, let's pass the port too
		if {$CFG($conn_name,namespace) == "db_postgreSQL"} {
			set CONN($conn_name) [$CFG($conn_name,namespace)::open_conn ${dbase} ${serv} ${port} $CFG($conn_name,username) $CFG($conn_name,password)]
		} else {
			set CONN($conn_name) [$CFG($conn_name,namespace)::open_conn ${dbase} ${serv} $CFG($conn_name,username) $CFG($conn_name,password)]
		}
	} msg]} {
		set msg "DB $conn_name: Failed to open connection to DB server $msg"
		ob_log::write CRITICAL {$msg}
		ob_db_multi::restart $conn_name
		error $msg
	}

	# backward compliance
	if {$conn_name == "PRIMARY"} {
		ob_log::write INFO {DB $conn_name: resetting global DB}
		set ::DB $ob_db_multi::CONN($conn_name)
	}

	# set lock mode (seconds)
	if {$CFG($conn_name,wait_time) != 0} {
		ob_log::write DEBUG\
		    {DB $conn_name: set lock mode to $CFG($conn_name,wait_time)}

		if {$CFG($conn_name,wait_time) == "zero"} {
			set stmt [$CFG($conn_name,namespace)::prep_sql $CONN($conn_name)\
			    "set lock mode to not wait"]
		} else {
			set stmt [$CFG($conn_name,namespace)::prep_sql $CONN($conn_name)\
			    "set lock mode to wait $CFG($conn_name,wait_time)"]
		}
		$CFG($conn_name,namespace)::exec_stmt $CONN($conn_name) 0 $stmt
		$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $stmt
	}

	# set isolation level?
	if {$CFG($conn_name,isolation_level) != 0} {
		ob_log::write DEBUG\
		    {DB $conn_name: set iso level to $CFG($conn_name,isolation_level)}

		set stmt [$CFG($conn_name,namespace)::prep_sql $CONN($conn_name)\
		    "set isolation to $CFG($conn_name,isolation_level)"]
		$CFG($conn_name,namespace)::exec_stmt $CONN($conn_name) 0 $stmt
		$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $stmt
	}

	# set default PDQ
	set PDQ_LIST($conn_name) $CFG($conn_name,default_pdq)
	if {$CFG($conn_name,default_pdq)} {
		_set_pdq $conn_name $CFG($conn_name,default_pdq)
	}

	set sessionid ""

	if {[catch {
		set stmt [inf_prep_sql $CONN($conn_name) "select DBINFO('sessionid') from systables where tabid=1"]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		set sessionid [db_get_coln $rs 0 0]
		rs_close $rs
	} msg]} {
		ob_log::write ERROR {Failed to get db sessionid - $msg}
	} else {
		ob_log::write ERROR {DB $conn_name: sessionid is $sessionid}
	}

	# unset previously prepared statements
	foreach stmt [array names DB_DATA "$conn_name,*,stmt"] {
		unset DB_DATA($stmt)
	}

	if {$CFG($conn_name,log_bufreads) == 1} {
		set BUFREADS($conn_name,buf_reads) [$CFG($conn_name,namespace)::buf_reads $CONN($conn_name)]
	}

}

# Public function to disconnect from a named connection
#   conn_name - unique name to identify the connection
proc ob_db_multi::disconnect { conn_name } {

	variable CFG
	variable CONN
	variable DB_DATA

	if {[catch {
		$CFG($conn_name,namespace)::close_conn $CONN($conn_name)
		unset CONN($conn_name)
		array set CFG [array unset CFG ${conn_name}*]

		# backward compliance
		if {$conn_name == "PRIMARY"} {
			ob_log::write INFO {DB $conn_name: unsetting global DB}
			unset ::DB
		}

		# unset previously prepared statements
		foreach stmt [array names DB_DATA "$conn_name,*,stmt"] {
			unset DB_DATA($stmt)
		}
	} msg]} {
		set msg "DB $conn_name: Failed to disconnect from DB server $msg"
		ob_log::write CRITICAL {$msg}
		error $msg
	}
}

#--------------------------------------------------------------------------
# Prepare Queries
#--------------------------------------------------------------------------

# Store a named query.
# If DB_PREP_ONDEMAND cfg value is set to zero, then the named query will
# be prepared. If value is set to non-zero, the query will be prepared
# the 1st time it's used.
#
#   conn_name - unique name which identifies the connection
#   name      - query name
#   qry       - SQL query
#   cache     - result set cache time (seconds)
#               disabled if DB_NO_CACHE cfg value is non-zero
#   force     - If another query exists with this name then force this one
#               into this place
#
proc ob_db_multi::store_qry { connections name qry {cache 0} {force 0}} {

	variable CFG
	variable DB_DATA

	# Ensure that the qry exists against the specified connection
	#
	foreach conn_name $connections {

		ob_log::write INFO {DB $conn_name: store_qry $name}

		if {[info exists DB_DATA($conn_name,$name,qry_string)]} {

			# Backwards compatibilty: If the queries are identical
			#   then allow them through
			if {$DB_DATA($conn_name,$name,name)       != $name || \
				$DB_DATA($conn_name,$name,qry_string) != $qry  || \
				$DB_DATA($conn_name,$name,cache_time) != $cache } {

				if {$DB_DATA($conn_name,$name,name) != $name} {
					ob_log::write CRITICAL {DB $conn_name: name differs $DB_DATA($conn_name,$name,name) != $name}
				}
				if {$DB_DATA($conn_name,$name,qry_string) != $qry} {
					regsub -all {\s} $DB_DATA($conn_name,$name,qry_string) {} q1
					regsub -all {\s} $qry {} q2
					if {$q1 == $q2 } {
						ob_log::write CRITICAL {***********************************}
						ob_log::write CRITICAL {* WARNING! Trying to reprepare qry: $name}
						ob_log::write CRITICAL {* WARNING! query text is different }
						ob_log::write CRITICAL {* WARNING! fix this! }
						ob_log::write CRITICAL {***********************************}
						ob_log::write CRITICAL {DB $conn_name: string differs $DB_DATA($conn_name,$name,qry_string) != $qry}
						return
					}
				}
				if {$DB_DATA($conn_name,$name,cache_time) != $cache } {
					ob_log::write CRITICAL {DB $conn_name: cache differs $DB_DATA($conn_name,$name,cache_time) != $cache}
				}

				error "Query $name already exists with different parameters"

			} elseif {!$force} {


				ob_log::write CRITICAL {***********************************}
				ob_log::write CRITICAL {* WARNING! Trying to reprepare qry: $name}
				ob_log::write CRITICAL {***********************************}
				return
			}
		}

		if {$name == "rs" || [regexp {,} $name]} {
			error "Illegal query name - $name"
		}


		# caching enabled?
		if {$CFG($conn_name,no_cache) && $cache} {
			ob_log::write WARNING {DB $conn_name: $name caching is disabled}
			set cache 0
		}


		# add query to list
		lappend   DB_DATA($name,connections) $conn_name
		array set DB_DATA [list \
			$conn_name,$name,name        $name\
			$conn_name,$name,qry_string  $qry\
			$conn_name,$name,cache_time  $cache]


		# prepare the query?
		if {!$CFG($conn_name,prep_ondemand)} {
			if {[catch {_new_prep_qry $conn_name $name} msg]} {
				ob_db_multi::restart $conn_name
				error $msg
			}
		}
	}

}



# Set the cache-time for a named query.
#
#   conn_name - unique name which identifies the connection
#               if omitted applied to all connections
#   name      - query name
#   cache     - result set cache time (seconds)
#               disabled if DB_NO_CACHE cfg value is non-zero
#
proc ob_db_multi::cache_qry { name cache {connections 0}} {

	variable CFG
	variable DB_DATA

	if {!$connections} {
		if {![info exists DB_DATA($name,connections)]} {
			error "No connection found for query $name"
		}
		set connections $DB_DATA($name,connections)
	}


	# validate
	foreach conn_name $connections {

		ob_log::write DEV {DB $conn_name: cache_qry $name}

		if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
			error "No such query $name exists"
		}
		if {$name == "rs" || [regexp {,} $name]} {
			error "Illegal query name - $name"
		}

		# caching enabled?
		if {$CFG($conn_name,no_cache) && $cache} {
			ob_log::write WARNING {DB $conn_name: $name caching is disabled}
			set cache 0
		}

		# set cache time
		set DB_DATA($conn_name,$name,cache_time) $cache
	}

}




# Check if a named query has already been prepared
#
#   conn_name - unique name which identifies the connection
#               if not supplied the pimary connection is checked
#	name      - query name
#
#	returns 1 if query has already been prepared else 0
#
proc ob_db_multi::check_qry { name {conn_name 0}} {

	variable DB_DATA

	ob_log::write DEBUG {DB $conn_name: Checking statement $name}
	if {$conn_name == 0} {
		if {![info exists DB_DATA($name,connections)]} {
			return 0
		}
		set conn_name [lindex $DB_DATA($name,connections) 0]
	}

	if {[info exists DB_DATA($name,connections)] && [info exists DB_DATA($conn_name,$name,stmt)]} {
		return 1
	}
	return 0
}



# Unprepare a stored name query.
#
#   conn_name - unique name which identifies the connection
#               If this is not passed stmt is closed on all
#               open connections
#   name      - query name
#
proc ob_db_multi::unprep_qry { name {connections 0}} {

	variable DB_DATA
	variable CFG
	variable CONN

	ob_log::write DEBUG {DB Unpreparing statement $name}

	# If no connection is passed, close on all connections
	if {$connections == 0} {
		if {[info exists DB_DATA($name,connections)]} {
			set connections $DB_DATA($name,connections)
		} else {
			set connections [list]
		}
	}

	# Close on all outstanding connections
	foreach conn_name $connections {
		if {[info exists DB_DATA($conn_name,$name,stmt)]} {
			$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $DB_DATA($conn_name,$name,stmt)
		}
		foreach k [array names DB_DATA "$conn_name,$name,*"] {
			unset DB_DATA($k)
		}
	}
	set remaining_conns [list]
	foreach connection $DB_DATA($name,connections) {
		if {[lsearch -exact $connections $connection] < 0} {
			lappend remaining_conns $connection
		}
	}
	set DB_DATA($name,connections) $remaining_conns
}



# Invalidated a named query.
#
#   conn_name - unique name which identifies the connection
#   name      - query name
#
proc ob_db_multi::invalidate_qry { name {connections 0} } {

	variable DB_DATA

	if {!$connections} {
		if {![info exists DB_DATA($name,connections)]} {
			set connections $DB_DATA($name,connections)
		} else {
			set connections [list]
		}
	}

	foreach conn_name $connections {
		ob_log::write DEBUG {DB $conn_name: invalidating query $name}
		set DB_DATA($conn_name,$name,stmt_invalid) [clock seconds]
	}
}



# Private procedure to prepare and add a new SQL query name.
#
#   conn_name - unique name which identifies the connection
#   name      - query name
#
proc ob_db_multi::_new_prep_qry { conn_name name } {

	variable DB_DATA
	variable CONN
	variable CFG

	ob_log::write DEBUG {DB $conn_name: invalidating query $name}


	# close previous invalid statement?
	if {[info exists DB_DATA($conn_name,$name,stmt)]} {
		$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $DB_DATA($conn_name,$name,stmt)
		unset DB_DATA($conn_name,$name,stmt)
	}

	# prepare query
	set now [clock seconds]
	if {[catch {set stmt [_try_prep_qry $conn_name\
	                      $DB_DATA($conn_name,$name,qry_string)]} msg]} {
		set msg "failed to prepare $name $msg"
		if {$CFG($conn_name,log_on_error) == 1} {
			ob_log::write_qry CRITICAL "DB $conn_name" $msg $DB_DATA($conn_name,$name,qry_string)
		}
		error $msg
	}

	set  DB_DATA($conn_name,$name,stmt)      $stmt
	set  DB_DATA($conn_name,$name,prep_time) $now
	set  DB_DATA($conn_name,$name,rs_valid)  $now

	if {[info exists DB_DATA($conn_name,$name,stmt_invalid)]} {
		unset DB_DATA($conn_name,$name,stmt_invalid)
	}
}



# Private procedure to prepare a SQL query.
# If the prep' fails and we need to re-prepare, or
# $in_reprep is non-zero,then establish a new DB connection and re-attempt the
# connection.
#
#   conn_name  - unique name which identifies the connection
#   qry        - query to prepare
#   in_reprep  - denote the proc is within a recursive loop
#                (default: 0)
#
proc ob_db_multi::_try_prep_qry { conn_name qry {in_reprep 0} } {

	variable CONN
	variable CFG

	if {[catch {set stmt [$CFG($conn_name,namespace)::prep_sql $CONN($conn_name) $qry]} msg]} {

		# if error code in reconn list, or allow re-prep, then establish a new
		# db connection and re-attempt the prep
		switch [ob_db_failover::handle_error $CONN($conn_name) \
			$CFG($conn_name,package) \
			$in_reprep \
			$msg] {

			REPREP {
				return [_try_prep_qry $conn_name $qry 1]
			}

			RECONN {
				_connect $conn_name
				return [_try_prep_qry $conn_name $qry 1]
			}

			RESTART {
				ob_db_multi::restart $conn_name
				error $msg $::errorInfo $::errorCode
			}

			NOOP    -
			REPREP  -
			default {
				_try_handle_err $conn_name
				error $msg $::errorInfo $::errorCode
			}

		}

	}

	return $stmt
}



#--------------------------------------------------------------------------
# Execute Queries
#--------------------------------------------------------------------------

# Execute a named query.
# The first 'arg' may include the -inc-type specifier which identifies the
# parameter types for CLOB/BLOB support.
# A specific connection can be specified with -connection <connection>
# this must appear before an -inc-type arguement, the defaults it so use
# the primary connection for the query
#
#   name       - SQL query name
#   args       - query arguments
#   returns    - query [cached] result set
#
proc ob_db_multi::exec_qry { name args } {

	variable DB_DATA

	if {[lindex $args 0] == "-connection"} {
		set conn_name [lindex $args 1]
		set args [lrange $args 2 end]
	} else {
		if {[info exists DB_DATA($name,connections)]} {
			set conn_name [lindex $DB_DATA($name,connections) 0]
		} else {
			error "no connection found for query $name"
		}
	}
	return [eval {_exec_qry $conn_name $name 0} $args]
}



# Execute a named query, except that the query is run even if there
# is a suitable cached result set. Use with care.
# The first 'arg' may include the -inc-type specifier which identifies the
# parameter types for CLOB/BLOB support.
# A specific connection can be specified with -connection <connection>
# this must appear before an -inc-type arguement, the defaults it so use
# the primary connection for the query
#
#   name       - SQL query name
#   args       - query arguments
#   returns    - query [cached] result set
#
proc ob_db_multi::exec_qry_force { name args } {

	variable DB_DATA

	if {[lindex $args 0] == "-connection"} {
		set conn_name [lindex $args 1]
		set args [lrange $args 2 end]
	} else {
		if {[info exists DB_DATA($name,connections)]} {
			set conn_name [lindex $DB_DATA($name,connections) 0]
		} else {
			error "no connection found for query $name"
		}
	}

	return [eval {_exec_qry $conn_name $name 1} $args]
}



# Private procedure to execute a named query.
# Please use ob_db_multi::exec_qry or ob_db_multi::exec_qry_force.
#
#   conn_name  - unique name which identifies the connection
#   name       - SQL query name
#   force      - run the query even if a suitable cached result set is
#                available (use with care; only available if shared
#                memory is enabled)
#   args       - query arguments
#   returns    - query [cached] result set
#
proc ob_db_multi::_exec_qry { conn_name name force args } {

	variable CFG
	variable DB_DATA

	# Establish the connection
	if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
		error "DB $conn_name: statement $name does not exist for con $conn_name"
	}

	# use shared memory?
	if {$CFG($conn_name,shm_cache)} {
		return [_exec_qry_shm $conn_name $name $force $args]
	} else {
		return [_exec_qry_no_shm $conn_name $name $force $args]
	}
}



# Private procedure to execute a query where the package has detected
# shared memory capabilities (appserv).
# Cached result sets are removed from the local store via ob_db_multi::req_end,
# the shared memory will handle cache expire time.
# Please use ob_db_multi::exec_qry or ob_db_multi::exec_qry_force.
#
#   conn_name  - unique name which identifies the connection
#   name       - SQL query name
#   force      - run the query even if a suitable cached result set is
#                available (use with care)
#   arglist    - query arguments
#   returns    - query [cached] result set
#
proc ob_db_multi::_exec_qry_shm { conn_name name force arglist } {

	variable DB_DATA
	variable CFG
	variable CONN

	if {$force} {
		ob_log::write WARNING\
		    {DB $conn_name: exec forced -$name- with args: $arglist}
	} else {
		ob_log::write DEV\
		    {DB $conn_name: _exec_qry_shm -$name- with args: $arglist}
	}

	# is result-set cached?
	if {$DB_DATA($conn_name,$name,cache_time)} {

		set argkey [join $arglist ","]

		# A result set can be reused within the same request as it wont be
		# cleaned up by the appserver until req_end. But we can't store it if
		# the query is cached during main_init (which we identify with a request
		# id of 0) as it will be cleared by the appserver when main_init is
		# finished.
		if {[reqGetId] == 0} {
			set reuse_cached_rs 0
		} else {
			set reuse_cached_rs 1
		}

		# rs cached and previously seen by this request
		if {!$force && [info exists DB_DATA($conn_name,$name,$argkey,rs)]} {

			ob_log::write DEBUG {DB $conn_name: (shm) using cached rs}
			set rs $DB_DATA($conn_name,$name,$argkey,rs)

		# rs cached, but not seen by current request
		} elseif {!$force &&\
		        ![catch {set rs [asFindRs $conn_name,$name,$argkey]}]} {

			set DB_DATA($rs,connection) $conn_name
			if {$reuse_cached_rs} {
				ob_log::write DEBUG\
				    {DB $conn_name: (shm) using shared memory cached rs}
				set DB_DATA($conn_name,$name,$argkey,rs) $rs
				lappend DB_DATA($conn_name,rss) $conn_name,$name,$argkey,rs
			}

		# rs cached and previously seen by this request on the failover connection
		} elseif {!$force && \
				$CFG($conn_name,failover) && \
				[info exists DB_DATA($CFG($conn_name,failover,db),$name,$argkey,rs)]} {

			ob_log::write INFO {DB $CFG($conn_name,failover,db): (failover): (shm) using cached rs}
			set rs $DB_DATA($CFG($conn_name,failover,db),$name,$argkey,rs)

		# rs cached on the failover, but not seen by current request
		} elseif {!$force && \
				$CFG($conn_name,failover) && \
		        ![catch {set rs [asFindRs $CFG($conn_name,failover,db),$name,$argkey]}]} {

			set DB_DATA($rs,connection) $CFG($conn_name,failover,db)
			if {$reuse_cached_rs} {
				ob_log::write INFO {DB $CFG($conn_name,failover,db): (failover): (shm) using shared memory cached rs}
				set DB_DATA($CFG($conn_name,failover,db),$name,$argkey,rs) $rs
				lappend DB_DATA($CFG($conn_name,failover,db),rss) $CFG($conn_name,failover,db),$name,$argkey,rs
			}

		# no cached rs available, or forced query
		} else {

			# Failover the connetion if necessary
			set conn_name [ob_db_multi::_failover_connection $conn_name $name]

			# if we are running a delayed db (replicated) then we decrease the cache time
			# by the current repserver delay if that is set in shared memory, if we fall
			# too far behind we will initiate a failover for the query, this assumes that
			# the failover db is not replicated and that the full cache time can be applied
			set cache_time [_calculate_cache $conn_name $DB_DATA($conn_name,$name,cache_time)]

			set rs [_run_qry $conn_name $name $arglist]

			if {$rs != {} && [catch {asStoreRs \
				        $rs $conn_name,$name,$argkey \
				        $cache_time} msg]} {
				ob_log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
			}

			if {$reuse_cached_rs} {
				set DB_DATA($conn_name,$name,$argkey,rs) $rs
				lappend DB_DATA($conn_name,rss) $conn_name,$name,$argkey,rs
			}
		}

	# not cached
	} else {
		set rs [_run_qry $conn_name $name $arglist]
	}

	return $rs
}



# Private procedure to execute a query where the package has detected
# that shared memory capabilities (appserv) are not available.
# If the query is cached, then the result set will be added to an internal store
# (DB_DATA array).
# Please use ob_db_multi::exec_qry or ob_db_multi::exec_qry_force.
#
#   conn_name  - unique name which identifies the connection
#   name       - SQL query name
#   force      - run the query even if a suitable cached result set is
#                available (use with care)
#   arglist    - query arguments
#   returns    - query [cached] result set
#
proc ob_db_multi::_exec_qry_no_shm { conn_name name force arglist } {

	variable CFG
	variable DB_DATA

	if {$force} {
		ob_log::write WARNING\
		    {DB $conn_name: exec forced -$name- with args: $arglist}
	} else {
		ob_log::write DEV\
		    {DB $conn_name: _exec_qry_no_shm -$name- with args: $arglist}
	}

	set cache   $DB_DATA($conn_name,$name,cache_time)
	set argkey  [join $arglist ","]
	set now     [clock seconds]

	# disable caching if a forced query
	if {$force} {
		set cache 0
	}

	# cached rs?
	if {$cache && [info exists DB_DATA($conn_name,$name,$argkey,rs)]} {

		set valid_time $DB_DATA($conn_name,$name,rs_valid)
		set exec_time  $DB_DATA($conn_name,$name,$argkey,time)

		# can we use the cached rs?
		if {$exec_time >= $valid_time && [expr {$exec_time + $cache}] >= $now} {

			ob_log::write DEBUG {DB $conn_name: (no shm) using cached rs}
			return $DB_DATA($conn_name,$name,$argkey,rs)
		}

	# Perhaps we have one against the failover db
	} elseif {$cache && $CFG($conn_name,failover) != 0 && \
				[info exists DB_DATA($CFG(conn_name,failover,db),$name,$argkey,rs)]} {

		set valid_time $DB_DATA($CFG(conn_name,failover,db),$name,rs_valid)
		set exec_time  $DB_DATA($CFG(conn_name,failover,db),$name,$argkey,time)

		# can we use the cached rs?
		if {$exec_time >= $valid_time && [expr {$exec_time + $cache}] >= $now} {

			ob_log::write DEBUG {DB $CFG(conn_name,failover,db) (failover): (no shm) using cached rs}
			return $DB_DATA($CFG($conn_name,failover,db),$name,$argkey,rs)
		}
	}

	# Failover checks
	set conn_name [ob_db_multi::_failover_connection $conn_name $name]

	# Offset the cache time by any delay on the database
	set cache [_calculate_cache $conn_name $cache]

	# no/expired cache
	set rs [_run_qry $conn_name $name $arglist]

	# store rs in a cache?
	if {$cache && $rs != ""} {

		# purge any existing cached rs
		if {[info exists DB_DATA($conn_name,$name,$argkey,rs)]} {
			_purge_rs $conn_name
		}

		set now [clock seconds]
		ob_log::write DEBUG {DB $conn_name: storing $rs in cache}

		# store rs within the cache
		set DB_DATA($conn_name,$name,$argkey,rs)   $rs
		set DB_DATA($conn_name,$name,$argkey,time) $now

		# store the reverse lookup key
		set DB_DATA($conn_name,rs,$rs,argkey)   $argkey
		set DB_DATA($conn_name,rs,$rs,qry_name) $name

		# store the rs and expiry time sorted in exp time order
		set exp     [expr {$now + $cache}]
		set rs_exp  $DB_DATA($conn_name,rs_exp)
		set llength [llength $rs_exp]

		for {set i 0} {$i < $llength} {incr i} {
			if {[lindex $rs_exp $i] > $exp} {
				if {$i > 0} {incr i -1}
				break
			}
		}

		set DB_DATA($conn_name,rs_exp)  [linsert $rs_exp $i $exp]
		set DB_DATA($conn_name,rs_list)\
		    [linsert $DB_DATA($conn_name,rs_list) $i $rs]
	}

	return $rs
}



# Private procedure to run a named query.
# Please use ob_db_multi::exec_qry or ob_db_multi::exec_qry_force.
#
#   conn_name  - unique name which identifies the connection
#   name       - SQL query name
#   vals       - query arguments
#   returns    - result set
#
proc ob_db_multi::_run_qry { conn_name name vals } {

	variable CFG
	variable DB_DATA

	# prepare the query?
	if {![info exists DB_DATA($conn_name,$name,stmt)]
		|| [info exists DB_DATA($conn_name,$name,stmt_invalid)]} {

		ob_log::write WARNING {DB $conn_name: preparing $name on demand}
		_new_prep_qry $conn_name $name
	}

	set now [clock seconds]

	# get the status string if supported
	if {$CFG($conn_name,get_status)} {
		set status_str [asGetStatus]
	} else {
		set status_str ""
	}

	# set the status string if supported
	if {$CFG($conn_name,set_status)} {
		asSetStatus "db: [clock format $now -format "%T"] - $name"
	}

	# execute statement
	set rs [_exec_stmt $conn_name $name $vals]

	# set the status string if supported
	if {$CFG($conn_name,set_status)} {
		asSetStatus $status_str
	}

	return $rs
}



# Private procedure to pick a connection to use
#
#   conn_name  - unique name which identifies the connection
#   name       - named query
#
proc ob_db_multi::_calculate_cache {conn_name cache} {
	variable CFG
	if {$CFG($conn_name,delayed) && $CFG($conn_name,reduce_cache)} {
		set delay [ob_db_failover::get_conn_delay $conn_name]
		return [expr {$cache > $delay ? $cache - $delay : 1}]
	} else {
		return $cache
	}
}



# Private procedure to pick a connection to use
#
#   conn_name  - unique name which identifies the connection
#   name       - named query
#
proc ob_db_multi::_failover_connection {conn_name {name ""}} {

	variable CFG
	variable DB_DATA

	if {!$CFG($conn_name,failover)} {
		return $conn_name
	}

	set failover 0

	# Is the database available
	if {![ob_db_failover::check_conn_status $conn_name]} {
		ob_log::write ERROR {DB $conn_name (failover): bad db connection status}
		set failover 1
	}

	if {!$failover && $name != "" && $CFG($conn_name,delayed)} {
		set delay [ob_db_failover::get_conn_delay $conn_name]

		# Failover if greater than max delay
		if {$delay > $CFG($conn_name,failover,max_delay)} {
			ob_log::write ERROR {DB $conn_name (failover): excessive delay on database: $delay}
			set failover 1

		# Failover if specific query would not have a large enough cache time
		} elseif { [expr {$DB_DATA($conn_name,$name,cache_time) - $delay}] < $CFG($conn_name,failover,min_cache)} {
			ob_log::write ERROR {DB $conn_name (failover): remaining cache too small with delay $delay for $name}
			set failover 1
		}
	}

	# If we are failing over try to prep the query
	if {$failover && $name != ""} {
		if {![ob_db_multi::check_qry $name $CFG($conn_name,failover,db)]} {
			_new_prep_qry $CFG($conn_name,failover,db) $name
		}
	}

	if {$failover} {
		ob_log::write ERROR {DB $conn_name (failover): failing over to $CFG($conn_name,failover,db) for $name}
		set conn_name $CFG($conn_name,failover,db)
	}
	return $conn_name
}




# Private procedure to execute the statement.
# Please use ob_db_multi::exec_qry or ob_db_multi::exec_qry_force.
#
#   conn_name  - unique name which identifies the connection
#   name       - named query
#   vals       - query arguments
#   in_reprep  - flag to denote if the procedure has been called recursively
#               (default: 0)
#   returns    - result set
#
proc ob_db_multi::_exec_stmt { conn_name name vals {in_reprep 0} } {

	variable DB_DATA
	variable CONN
	variable CFG


	# build SQL query (supports the -inc-type specifier for CLOB/BLOB insert)
	if {[lindex $vals 0] == "-inc-type"} {
		set inc_type 1
	} else {
		set inc_type 0
	}

	set qry_args [list]
	foreach a $vals {
		if {$a != "-inc-type"} {
			lappend qry_args $a
		}
	}

	# Failover connection if required
	set conn_name [ob_db_multi::_failover_connection $conn_name $name]

	if {$CFG($conn_name,log_qry_params)} {
		ob_log::write INFO {DB $conn_name: executing -$name- with args: $vals}
	}

	# logging query time?
	set t0 [OT_MicroTime -micro]

	# execute query
	set DB_DATA($name,last_connection) $conn_name
	if {[catch {set rs [eval [list $CFG($conn_name,namespace)::exec_stmt \
								$CONN($conn_name) \
								$inc_type \
								$DB_DATA($conn_name,$name,stmt)]\
								$qry_args]} msg]} {

		variable IN_TRAN

		switch [ob_db_failover::handle_error $conn_name \
											 $CFG($conn_name,package) \
											 $in_reprep \
											 $msg] {

			REPREP {
				if {![info exists IN_TRAN($conn_name)]} {
					_new_prep_qry $conn_name $name
					return [_exec_stmt $conn_name $name $vals 1]
				} else {
					_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
					ob_db_multi::restart $conn_name
					error $msg $::errorInfo $::errorCode
				}
			}

			RECONN {
				_connect $conn_name
				_new_prep_qry $conn_name $name
				return [_exec_stmt $conn_name $name $vals 1]
			}

			RESTART {
				# don't try to sort it out again
				if {$CFG($conn_name,log_on_error) == 1} {
					ob_log::write_qry CRITICAL "DB $conn_name" $msg $DB_DATA($conn_name,$name,qry_string)
				}
				_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
				ob_db_multi::restart $conn_name
				error $msg $::errorInfo $::errorCode
			}

			NOOP    -
			default {
				_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
				error $msg $::errorInfo $::errorCode
			}

		}

	}

	# Record the connection against the result set
	if {$rs != ""} {set DB_DATA($rs,connection) $conn_name}

	if {$CFG($conn_name,log_qry_nrows)} {
		ob_log::write DEBUG {DB $conn_name: [garc $name $conn_name] rows Probably affected}
	}

	_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]

	_log_buf_reads $conn_name $name

	return $rs
}



proc ob_db_multi::_log_buf_reads {conn_name name} {

	variable CONN
	variable CFG
	variable BUFREADS

	if {$CFG($conn_name,log_bufreads) == 1} {
		set buf_reads [$CFG($conn_name,namespace)::buf_reads $CONN($conn_name)]
		ob_log::write INFO {DB::BUFREADS $conn_name: $name [expr {$buf_reads - $BUFREADS($conn_name,buf_reads)}]}
		set BUFREADS($conn_name,buf_reads) $buf_reads
	}
}



# Attempt to log the query time, and warn of any long queries
#
#   conn_name - connection name
#   name      - query name
#   vals      - argument to the query
#   t0        - query start time
#   t1        - query end time
#
proc ob_db_multi::_log_qry_time {prefix conn_name name vals t0 t1} {

	variable CONN
	variable DB_DATA
	variable CFG

	set tt [expr {$t1 - $t0}]
	set ft [format {%0.4f} $tt]

	# log the query which exceeds CFG(log_longq)
	if {$tt > $CFG($conn_name,log_longq)} {
		ob_log::write_qry INFO \
			"DB::LONGQ" \
			"$name $ft rowcount = [garc $name $conn_name]" \
			$DB_DATA($conn_name,$name,qry_string) \
			$vals

		# log the explain plan
		if {$CFG($conn_name,log_explain) == 1} {
			$CFG($conn_name,namespace)::explain \
				$CONN($conn_name) \
				$name \
				$DB_DATA($conn_name,$name,qry_string) \
				$vals
		}

	}
	if {$CFG($conn_name,log_qry_time)} {
		ob_log::write INFO {DB::$prefix ${conn_name} $name $ft}
	}
}



# Execute a query using each row methodology.
# See db-admin.tcl for detailed arguments.
#
# foreachrow ?-fetch? ?-force? ?-colnamesvar colnames? ?-rowvar r?
#   ?-nrowsvar nrows? ?-connection qry ?arg...? tcl
#
proc ob_db_multi::foreachrow {args} {

	global DB

	variable CFG
	variable CONN
	variable DB_DATA
	variable IN_TRAN

	#
	# parse the arguments
	#
	set is_reprep 0
	set fetch 0
	set force 0
	set conn_name 0

	for {set i 1} {$i < [llength $args]} {incr i} {
		set arg [lindex $args $i]
		switch -- $arg {
			-is_reprep {
				set is_reprep 1
			}
			-fetch {
				set fetch 1
			}
			-connection {
				incr i
				set conn_name [lindex $args $i]
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

	# Establish the correct connection for this query
	if {$conn_name == 0} {
		if {[info exists DB_DATA($name,connections)]} {
			set conn_name [lindex $DB_DATA($name,connections) 0]
		} else {
			error "Query connection not found"
		}
	}

	unset i args

	# Failover connection if necessary
	set conn_name [ob_db_multi::_failover_connection $conn_name $name]

	# check the query exists
	if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
		error "Query not found"
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
	if {$fetch && $CFG($conn_name,use_fetch)} {

		ob_log::write DEV {DB: foreachrow fetching $name $argz}

		if {![info exists DB_DATA($conn_name,$name,stmt)]
			|| [info exists DB_DATA($conn_name,$name,stmt_invalid)]} {

			ob_log::write WARNING {DB $conn_name: preparing $name on demand}
			_new_prep_qry $conn_name $name
		}

		set stmt $DB_DATA($conn_name,$name,stmt)

		set t0 [OT_MicroTime -micro]

		if {[catch {
			set DB_DATA($name,last_connection) $conn_name
			if {[lindex $argz 0] == "-inc-type"} {
				set colnames [eval {$CFG($conn_name,namespace)::exec_stmt_for_fetch \
							$CONN($conn_name)\
							1 \
							$stmt}\
							[lrange $argz 1 end]]
			} else {
				set colnames [eval {$CFG($conn_name,namespace)::exec_stmt_for_fetch \
							$CONN($conn_name)\
							0 \
							$stmt}\
							$argz]
			}
		} msg]} {

			switch [ob_db_failover::handle_error $conn_name \
												 $CFG($conn_name,package) \
												 $is_reprep \
												 $msg] {

				REPREP {
					# we shouldn't be in a transaction if we are doing
					# a fetch at all, but just in case we follow the exact
					# some procedure as if we have done and exec_stmt
					if {[info exists IN_TRAN($conn_name)]} {
						_new_prep_qry $conn_name $name
						return [uplevel 1 {ob_db::foreachrow $conn_name \
							-is_reprep} $args]
					} else {
						error $msg $::errorInfo $::errorCode
					}
				}

				RECONN {
					_connect $conn_name
					_new_prep_qry $conn_name $name
					return [uplevel 1 {ob_db::foreachrow $conn_name \
						-is_reprep} $args]
				}

				RESTART {
					ob_db_multi::restart $conn_name
					error $msg$::errorInfo $::errorCode
				}

				NOOP -
				default {
					_try_handle_err $conn_name
					error $msg$::errorInfo $::errorCode
				}

			}

		}

		# this may be an underestimate, the database may still be doing the
		# query while we are doing work this side
		_log_qry_time FOREACHROW $conn_name $name $argz $t0 \
			[OT_MicroTime -micro]

		# check that the variables do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists $n]]} {
					$CFG($conn_name,namespace)::fetch_done $CONN($conn_name) $stmt
					$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $stmt

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
		$CFG($conn_name,namespace)::fetch_done $CONN($conn_name) $stmt
		$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $stmt

		ob_log::write DEV {DB: $nrows rows fetched}

	} else {

		set rs [eval {exec_qry $name -connection $conn_name} $argz]

		set nrows    [db_get_nrows $rs]
		set colnames [db_get_colnames $rs]

		# check that the variable do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists $n]]} {
					rs_close $conn_name $rs

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
		rs_close $rs $conn_name

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



# Try handling exec errors for DB
#
#   conn_name - Connection Name
#
proc ob_db_multi::_try_handle_err { conn_name } {
	variable CFG

	if {[lsearch $CFG($conn_name,log_err) [get_err_code $conn_name]] >= 0} {
		ob_log::write_ts
	}
}


#--------------------------------------------------------------------------
# Transactions
#--------------------------------------------------------------------------

# Begin a transaction.
# If a connection related error occurs, the procedure will establish a new
# connection and re-attempt the begin transaction. If this fails, then
# asRestart (appserv restart command) is called.
# Any other failure, will result in calling asRestart!
#
# When calling this procedure, make sure that either ob_db_multi::commit_tran
# or ob_db_multi::rollback_tran is called.
#
#   conn_name  - unique name which identifies the connection
#
proc ob_db_multi::begin_tran { conn_name } {

	variable CFG
	variable CONN
	variable IN_TRAN
	variable TRAN_START

	# begin transaction
	# - on connection error, re-connect and re-attempt transaction start
	ob_log::write WARNING {DB::TRANS ($conn_name) beginning transaction }
	if {[catch {$CFG($conn_name,namespace)::begin_tran $CONN($conn_name)} msg]} {
		switch [ob_db_failover::handle_error $conn_name \
											$CFG($conn_name,package) \
											0 \
											$msg] {

			RECONN {
				_connect $conn_name
				$CFG($conn_name,namespace)::begin_tran $CONN($conn_name)
			}
			NOOP {
				error $msg $::errorInfo $::errorCode
			}
			REPREP -
			RESTART {
				ob_db_multi::restart $conn_name
				error $msg $::errorInfo $::errorCode
			}
		}
	}

	# log execution time
	if {$CFG($conn_name,log_qry_time)} {
		set TRAN_START($conn_name) [OT_MicroTime -micro]
	}

	set IN_TRAN($conn_name) 1
}



# Commit a transaction.
# ob_db_multi::begin_tran must have been called to allow a transaction to be
# committed. Make sure commit_tran is called if the transaction is wanted,
# else call ob_db_multi::rollback_tran.
#
#   conn_name  - unique name which identifies the connection
#
proc ob_db_multi::commit_tran { conn_name } {

	variable CFG
	variable CONN
	variable IN_TRAN
	variable TRAN_START

	ob_log::write WARNING {DB::TRANS ($conn_name) committing transaction }
	if {[catch {$CFG($conn_name,namespace)::commit_tran $CONN($conn_name)} msg]} {
		error $msg
	}

	unset IN_TRAN($conn_name)

	if {$CFG($conn_name,log_qry_time)} {
		set tt [expr {[OT_MicroTime -micro] - $TRAN_START($conn_name)}]
		ob_log::write WARNING {DB::EXEC ($conn_name) commit [format %0.4f $tt]}
	}
}



# Rollback a transaction.
# ob_db_multi::begin_tran must have been called to allow a transaction to be
# rolled back. Make sure that rollback_tran is called if the transaction
# is not wanted, else call ob_db_multi::commit_tran
#
#   conn_name  - unique name which identifies the connection
#
proc ob_db_multi::rollback_tran { conn_name } {

	variable CFG
	variable CONN
	variable IN_TRAN
	variable TRAN_START

	# rollback transaction
	if {[catch {$CFG($conn_name,namespace)::rollback_tran $CONN($conn_name)} msg]} {
		error $msg
	}

	ob_log::write WARNING {DB::TRANS ($conn_name) rollback transaction}

	unset IN_TRAN($conn_name)

	# log execution time
	if {$CFG($conn_name,log_qry_time)} {
		set tt [expr {[OT_MicroTime -micro] - $TRAN_START($conn_name)}]
		ob_log::write WARNING {DB::EXEC ($conn_name) rollback [format %0.4f $tt]}
	}
}



#--------------------------------------------------------------------------
# Request
#--------------------------------------------------------------------------

# Denote an appserv request has ended on *all* connections.
# This procedure MUST be called at the end of every request. Performs important
# cleanup of the result set cache.
# Attempts to rollback a transaction, if this succeeds, the procedure will
# raise an error.
#
proc ob_db_multi::req_end args {

	variable CFG
	variable CONN
	variable DB_DATA

	foreach conn_name [array names CONN] {

		# rollback
		if {![catch {rollback_tran $conn_name}]} {
			ob_log::write ERROR\
			    {DB $conn_name: ERROR ============================}
			ob_log::write ERROR\
			    {DB $conn_name: ERROR rollback succeeded in req_end}
			ob_log::write ERROR\
			    {DB $conn_name: ERROR ============================}
		}

		# purge cached result sets
		if {$CFG($conn_name,shm_cache)} {
			ob_log::write DEV\
			    {DB $conn_name: deleting rss $DB_DATA($conn_name,rss)}
			foreach rs $DB_DATA($conn_name,rss) {
				catch {unset DB_DATA($rs)}
			}
			set DB_DATA($conn_name,rss) {}
		} else {
			_purge_rs $conn_name
		}
	}
}



#--------------------------------------------------------------------------
# Result Sets
#--------------------------------------------------------------------------

# override the inf_tcl db_close to keep result sets that need to be cached
if {[catch {rename db_close db_rs_close}]} {
	puts "WARNING: unable to rename db_close"
}



# Close an un-cached result set.
#
#   conn_name  - unique name which identifies the connection
#                if ommited will be applied to connection of the rs
#   rs         - result set to close
#
proc ob_db_multi::rs_close { rs {conn_name 0} } {

	variable CFG
	variable DB_DATA
	variable CONN

	# Determine which connection this rs was performed against
	if {$conn_name == 0} {
		if {[info exists DB_DATA($rs,connection)]} {
			set conn_name $DB_DATA($rs,connection)
		} else {
			ob_log::write INFO {DB : unable to find rs connection $rs}
			return
		}
	}

	# ignore is using shared memory
	if {$CFG($conn_name,shm_cache)} {
		return
	}

	# close non-cached result set
	if {![info exists DB_DATA($conn_name,rs,$rs,qry_name)]} {

		ob_log::write DEV {DB $conn_name: closing un-cached rs $rs}
		if {[catch {$CFG($conn_name,namespace)::rs_close $CONN($conn_name) $rs} msg]} {
			ob_log::write WARNING\
			    {DB $conn_name: _purge_rs, unable to close $rs $msg}
		}

	} else {
		ob_log::write DEV\
		    {DB $conn_name: rs $rs is cached, ignoring close request}
	}
}



# Get the number of rows affected by the last statement
#
#   conn_name  - unique name which identifies the connection
#   name       - named SQL query
#   returns    - number of rows affected by the last statement
#
proc ob_db_multi::garc { name {conn_name 0} } {

	variable DB_DATA
	variable CONN
	variable CFG

	# determine which connection the query was run against so that we
	# get the correct details back
	if {$conn_name == 0} {
		if {[info exists DB_DATA($name,last_connection)]} {
			set conn_name $DB_DATA($name,last_connection)
		} else {
			error "could not find connection for qry $name"
		}
	}

	set garc [$CFG($conn_name,namespace)::get_row_count $CONN($conn_name) $DB_DATA($conn_name,$name,stmt)]

	if {$CFG($conn_name,log_qry_nrows)} {
		ob_log::write INFO {DB $conn_name: garc :: $name $garc}
	}

	return $garc
}



# Get serial number created by the last insert
#
#   conn_name  - unique name which identifies the connection
#   name       - stored query name
#   returns    - serial number (maybe an empty string if no serial
#                number was associated with the last insert)
#
proc ob_db_multi::get_serial_number { name {conn_name 0}} {

	variable DB_DATA
	variable CONN
	variable CFG

	# If no connection is passed, close on all connections
	if {$conn_name == 0} {
		if {[info exists DB_DATA($name,last_connection)]} {
			set conn_name $DB_DATA($name,last_connection)
		} else {
			error "could not find connection for qry $name"
		}
	}

	if {[catch {set serial [$CFG($conn_name,namespace)::get_serial $CONN($conn_name) $DB_DATA($conn_name,$name,stmt)]}\
	        msg]} {
		ob_log::write ERROR {DB - $msg}
		error $msg
	}

	return $serial
}



# Private procedure to purge any expired result sets.
#
#   conn_name  - unique name which identifies the connection
#
proc ob_db_multi::_purge_rs { conn_name } {

	variable CFG
	variable DB_DATA
	variable CONN

	ob_log::write DEV {DB $conn_name: purge expired result sets}

	set now [clock seconds]

	# clean up any expired rs
	set rs_exp  $DB_DATA($conn_name,rs_exp)
	set rs_list $DB_DATA($conn_name,rs_list)

	set purge_count 0
	while {[llength $rs_exp] && $now > [lindex $rs_exp 0]} {

		set rs     [lindex $rs_list 0]
		set name   $DB_DATA($conn_name,rs,$rs,qry_name)
		set argkey $DB_DATA($conn_name,rs,$rs,argkey)

		ob_log::write DEV\
		    {DB $conn_name: purging $rs from cache, qry $name, args $argkey}

		if {[catch {$CFG($conn_name,namespace)::rs_close $CONN($conn_name) $rs} msg]} {
			ob_log::write WARNING\
			    {DB $conn_name: _purge_rs, unable to close $rs $msg}
		}

		catch {unset DB_DATA($rs,connection)}
		catch {unset DB_DATA($conn_name,$name,$argkey,rs)}
		catch {unset DB_DATA($conn_name,$name,$argkey,time)}
		catch {unset DB_DATA($conn_name,rs,$rs,qry_name)}
		catch {unset DB_DATA($conn_name,rs,$rs,argkey)}

		set rs_exp  [lrange $rs_exp  1 end]
		set rs_list [lrange $rs_list 1 end]
		incr purge_count
	}

	set DB_DATA($conn_name,rs_exp)  $rs_exp
	set DB_DATA($conn_name,rs_list) $rs_list

	ob_log::write DEV {DB $conn_name: purged $purge_count items successfully}
}



#--------------------------------------------------------------------------
# PDQ
#--------------------------------------------------------------------------

# Set a PDQ priority.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0. The priority will be limited
# to DB_MAX_PDQ cfg value.
# The PDQ is pushed onto an internal stack, use ob_log::pop_pdq to remove the
# PDQ from the list and reset to the previous priority.
#
#   conn_name  - unique name which identifies the connection
#   pdq        - PDQ priority
#   returns    - PDQ value set, or zero if setting of PDQs is disabled
#
proc ob_db_multi::push_pdq { pdq conn_name } {

	variable CFG
	variable PDQ_LIST

	if {!$CFG($conn_name,max_pdq)} {
		ob_log::write INFO {DB $conn_name: setting pdq priority disabled}
		return 0
	} elseif {$pdq > $CFG($conn_name,max_pdq)} {
		ob_log::write INFO\
		    {DB $conn_name: limiting pdq priority to $CFG($conn_name,max_pdq)}
		set pdq $CFG($conn_name,max_pdq)
	}

	lappend PDQ_LIST($conn_name) $pdq
	_set_pdq $conn_name $pdq

	return $pdq
}



# Reset the PDQ priority to previous setting.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0, and the PDQ stack is
# not exhausted.
#
#   conn_name - unique name which identifies the connection
#   returns   - PDQ value set, or zero if setting of PDQs is disabled, or the
#               list is exhausted
#
proc ob_db_multi::pop_pdq { conn_name } {

	variable CFG
	variable PDQ_LIST

	if {!$CFG($conn_name,max_pdq)} {
		ob_log::write INFO {DB $conn_name: setting pdq priority disabled}
		return 0
	} elseif {[llength $PDQ_LIST($conn_name)] < 2} {
		ob_log::write INFO {DB $conn_name: exhausted PDQ stack}
		return 0
	}

	set PDQ_LIST($conn_name) [lreplace $PDQ_LIST($conn_name) end end]
	set pdq [lindex $PDQ_LIST($conn_name) end]
	_set_pdq $conn_name $pdq

	return $pdq
}



# Private procedure to set the PDQ priority.
# Use ob_db_multi::push_pdq to set the PDQ and ob_db_multi::pop_pdq to reset the
# PDQ.
#
#   conn_name - unique name which identifies the connection
#   pdq       - PDQ priority
#
proc ob_db_multi::_set_pdq { conn_name pdq } {

	variable CFG
	variable CONN

	ob_log::write DEBUG {DB $conn_name: set pdqpriority $pdq}

	set stmt [$CFG($conn_name,namespace)::prep_sql $CONN($conn_name) "set pdqpriority $pdq"]
	$CFG($conn_name,namespace)::exec_stmt $CONN($conn_name) 0 $stmt
	$CFG($conn_name,namespace)::close_stmt $CONN($conn_name) $stmt
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Gets the last Informix error code
#
#   returns - last Informix error code
#
proc ob_db_multi::get_err_code {conn_name} {

	variable CFG
	variable CONN

	return [$CFG($conn_name,namespace)::last_err_num $CONN($conn_name)]
}



#
# Conditional restart, this may be overriden in the config
#
proc ob_db_multi::restart {conn_name} {
	variable CFG

	_try_handle_err $conn_name

	if {$CFG($conn_name,restart_on_error)} {
		asRestart
	} else {
		ob_log::write ERROR {DB $conn_name: asRestart not called due to config override}
	}
}


#
# Log the locks from the for the given database
#
proc ob_db_multi::log_locks {conn_name} {
	variable CFG
	variable CONN
	$CFG($conn_name,namespace)::log_locks $CONN($conn_name)
}

#
# Log the locks from the for the given database
#
proc ob_db_multi::get_column_info {conn_name table column} {
	variable CFG
	variable CONN
	$CFG($conn_name,namespace)::column_info $CONN($conn_name) $table $column
}


#
# Provide interface to change configuration items
#
proc ob_db_multi::reconfigure { conn_name cfg_name cfg_value } {
	variable CFG

	if {[info exists CFG($conn_name,$cfg_name,switchable)]} {
		set CFG($conn_name,$cfg_name) $cfg_value
	} else {
		ob_log::write ERROR {DB $conn_name: failed to reconfigure $cfg_name, configuration item does not exist}
	}
}


