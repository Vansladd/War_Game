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
# Synopsis:
#     package require core::db ?1.0?
#
# If not using the package within appserv, then load libOT_InfTcl.so and
# libOT_Tcl.so.
#
#
set pkg_version 1.0
package provide core::db $pkg_version


# Dependencies
package require core::log          1.0
package require core::util         1.0
package require core::check        1.0
package require core::args         1.0
package require core::db::failover 1.0

core::args::register_ns \
	-namespace core::db \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::db::failover] \
	-docs      db/db.xml

# Variables
namespace eval core::db {

	variable CFG
	variable CONN
	variable PDQ_LIST
	variable DB_DATA
	variable IN_TRAN
	variable TRAN_START
	variable CORE_DEF

	# configuration
	array set CFG [list]


	set CFG(init) 0

	# application server have shm_cache support
	set CFG(shm_cache) [string equal [info commands asFindRs] asFindRs]

	# application server have status string support
	set CFG(set_status) [string equal [info commands asSetStatus] asSetStatus]

	# application server can report current status
	set CFG(get_status) [string equal [info commands asGetStatus] asGetStatus]

	# application server can support query semaphores
	set CFG(supports_qry_sems) "UNKNOWN"

	# query semaphore set (shared amongst connections)
	set CFG(shared_qry_sems_id) ""
	set CFG(shared_qry_sems_key) ""
	set CFG(shared_qry_sems_conns) [list]

	# connections
	array set CONN [list]

	# PDQ stack
	array set PDQ_LIST [list]

	# in a transaction?
	array set IN_TRAN    [list]
	array set TRAN_START [list]

	# Set core arg definitions to avoid duplication
	set CORE_DEF(conn_name)       [list -arg -conn_name   -mand 0 -check ASCII -default {} -desc {Database connection name}]
	set CORE_DEF(connections)     [list -arg -connections -mand 0 -check ASCII -default {} -desc {List of connection names to prep the query against}]
	set CORE_DEF(stmt)            [list -arg -stmt        -mand 1 -check ASCII             -desc {Prepared statement to execute}]
	set CORE_DEF(name)            [list -arg -name        -mand 1 -check ASCII             -desc {Query name}]
	set CORE_DEF(qry)             [list -arg -qry         -mand 1 -check ANY               -desc {query definition}]
	set CORE_DEF(args)            [list -arg -args        -mand 0 -check ANY   -default {} -desc {Arguments to substitute into placeholders}]
	set CORE_DEF(rs)              [list -arg -rs          -mand 1 -check ASCII             -desc {Result set reference}]
	set CORE_DEF(opt,serial_type) [list -arg -serial_type -mand 0 \
		-check {ENUM -args {serial serial8 bigserial {}}} -default {} -desc {Serial data type}]
}

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::db::init \
	-args [list \
		[list -arg -force_init        -mand 0 -check BOOL                                    -default 0         -desc {Force initialisation}] \
		[list -arg -use_qry_sems      -mand 0 -check BOOL  -default_cfg DB_USE_QRY_SEMS      -default 0         -desc {Use query semaphores}] \
		[list -arg -qry_sems_key      -mand 0 -check ASCII -default_cfg DB_QRY_SEMS_KEY      -default "NOT_SET" -desc {Semaphore key}] \
		[list -arg -generate_sems_key -mand 0 -check BOOL  -default_cfg DB_GENERATE_SEMS_KEY -default 0         -desc {Auto generate the semaphore key (currently 10000 above PORTS)}] \
		[list -arg -allow_expired     -mand 0 -check BOOL  -default_cfg DB_ALLOW_EXPIRED     -default 1         -desc {Allow expired result sets to be returned, Must have -qry_sems_key enabled}] \
		[list -arg -extend_expired    -mand 0 -check BOOL  -default_cfg DB_EXTEND_EXPIRED    -default 1         -desc {Allow extending of expired result sets, Must have -allow_expired enabled}] \
		[list -arg -distrib_cache     -mand 0 -check BOOL  -default_cfg AS_USE_DIST_CACHE    -default 0         -desc {Enable distributed cache (memcached)}] \
		[list -arg -rewrite_qry       -mand 0 -check BOOL                                    -default 1         -desc {Re-write a query so placeholders are substituted according to database package}] \
		[list -arg -debug_qry_file    -mand 0 -check ASCII -default_cfg DB_DEBUG_FILE        -default {}        -desc {Write all prepared queries to file to aid debugging. Useful for dynamically built queries}] \
		[list -arg -debug_qry_child   -mand 0 -check INT   -default_cfg DB_DEBUG_CHILD       -default 0         -desc {Child that should write out the query so we don't have interleaving problems. Use -1 for scripts}] \
		[list -arg -conn_qry_map      -mand 0 -check ASCII                                   -default {}        -desc {A mapping controlling the connection against which named queries are stored}] \
	]

# Connection independent initialisation
proc core::db::init args {

	variable CFG
	variable CONN
	variable DB_DATA

	array set ARGS [core::args::check core::db::init {*}$args]

	# already initialised?
	if {$CFG(init) && !$ARGS(-force_init)} {
		return
	}

	array set DB_DATA [array unset DB_DATA]

	# initialise dependencies
	core::log::init
	core::db::failover::init

	core::log::write INFO {Initialising core::db}

	set CFG(use_qry_sems)      $ARGS(-use_qry_sems)
	set CFG(qry_sems_key)      $ARGS(-qry_sems_key)
	set CFG(generate_sems_key) $ARGS(-generate_sems_key)
	set CFG(allow_expired)     $ARGS(-allow_expired)
	set CFG(extend_expired)    $ARGS(-extend_expired)
	set CFG(distrib_cache)     $ARGS(-distrib_cache)
	set CFG(rewrite_qry)       $ARGS(-rewrite_qry)
	set CFG(debug_qry_file)    $ARGS(-debug_qry_file)
	set CFG(debug_qry_child)   $ARGS(-debug_qry_child)
	set CFG(debug_qry_fd)      {}

	# Reset the list of connections
	set DB_DATA(connections) {}

	# This is not ideal but if configured on for pratical reasons a
	# best guess key will be auto generated via a little 'bodge'
	# using the appserv PORTS value. This clearly doesn't work for
	# child group based applications or non-appserv processes.
	if {$CFG(use_qry_sems) && $CFG(qry_sems_key) == "NOT_SET" && $CFG(generate_sems_key)} {
		if {[set port [OT_CfgGet PORTS -1]] == "-1"} {
			error "sems key auto-gen not possible"
		}
		set CFG(qry_sems_key) [expr {$port + 10000}]
		core::log::write INFO {DB semaphore key auto-generated as $CFG(qry_sems_key)}
	}

	# Open and prepare the debug file. This will aid analysis when complicated
	# dynamic queries are prepped
	open_qry_debug_file

	# override the inf_tcl db_close to keep result sets that need to be cached
	if {[catch {
		uplevel #0 {rename db_close db_rs_close}
	}]} {
		core::log::write WARNING {WARNING: unable to rename db_close}
	}

	# Store the connection query mapping for use within core::db::store_qry.
	foreach {conn_name queries} $ARGS(-conn_qry_map) {
		foreach query $queries {
			lappend CFG(query,$query,conn_name) $conn_name
		}
	}

	set CFG(init) 1

	core::log::write INFO {DB Initialised}
}


core::args::register \
	-proc_name core::db::connect \
	-args [list \
		[list -arg -conn_name          -mand 0 -check ASCII    -default_cfg DB_CONN_NAME         -default "PRIMARY"  -desc {Database connection name}] \
		[list -arg -package            -mand 0 -check ASCII    -default_cfg DB_PACKAGE           -default "informix" -desc {Database type}] \
		[list -arg -servers            -mand 1 -check ASCII                                                          -desc {Database server name (a list can be supplied and one will be randomly chosen}] \
		[list -arg -database           -mand 1 -check ASCII                                                          -desc {Database name}] \
		[list -arg -db_port            -mand 0 -check UINT     -default_cfg DB_PORT              -default 0          -desc {Port used when connecting to Postgres}] \
		[list -arg -username           -mand 0 -check ASCII    -default_cfg DB_USERNAME          -default 0          -desc {Database username}] \
		[list -arg -password           -mand 0 -check ASCII    -default_cfg DB_PASSWORD          -default 0          -desc {Database password}] \
		[list -arg -prep_ondemand      -mand 0 -check BOOL     -default_cfg DB_PREP_ONDEMAND     -default 1          -desc {Prepare queries on demand}] \
		[list -arg -no_cache           -mand 0 -check BOOL     -default_cfg DB_NO_CACHE          -default 0          -desc {Disable caching of queries}] \
		[list -arg -log_qry_params     -mand 0 -check BOOL                                       -default 1          -desc {Log the query parameters}] \
		[list -arg -log_qry_nrows      -mand 0 -check BOOL                                       -default 1          -desc {Log the number of affected rows}] \
		[list -arg -log_qry_time       -mand 0 -check BOOL     -default_cfg DB_LOG_QRY_TIME      -default 1          -desc {Log the query time}] \
		[list -arg -log_lock_time      -mand 0 -check BOOL                                       -default 1          -desc {Log the lock time}] \
		[list -arg -log_longq          -mand 0 -check UDECIMAL -default_cfg DB_LONGQ             -default 99999999.9 -desc {Log long queries}] \
		[list -arg -log_bufreads       -mand 0 -check BOOL     -default_cfg DB_BUFREADS          -default 0          -desc {Log long buffer reads}] \
		[list -arg -log_explain        -mand 0 -check BOOL     -default_cfg DB_EXPLAIN           -default 0          -desc {Log the explain plan}] \
		[list -arg -log_on_error       -mand 0 -check BOOL     -default_cfg DB_LOG_ON_ERROR      -default 1          -desc {Log when an error occurs (OXi disables this for replication)}] \
		[list -arg -restart_on_error   -mand 0 -check BOOL     -default_cfg DB_RESTART_ON_ERROR  -default 1          -desc {Restart when an error occurs (OXi disables this for replication)}] \
		[list -arg -failover           -mand 0 -check ASCII                                      -default 0          -desc {Failover database connection name}] \
		[list -arg -failover_min_cache -mand 0 -check UINT                                       -default 5          -desc {Failover min resultant cache time for a query}] \
		[list -arg -failover_max_delay -mand 0 -check UINT                                       -default 30         -desc {Failover delay on a replicated db before failover}] \
		[list -arg -delayed            -mand 0 -check BOOL                                       -default 0          -desc {Is the database delayed (due to replication)}] \
		[list -arg -reduce_cache       -mand 0 -check UINT                                       -default 0          -desc {Reduce cache times by current db delay (sec)}] \
		[list -arg -wait_time          -mand 0 -check UINT     -default_cfg DB_WAIT_TIME         -default 20         -desc {Lock wait time (Informix only)}] \
		[list -arg -isolation_level    -mand 0 -check ASCII    -default_cfg DB_ISOLATION_LEVEL   -default 0          -desc {Database isolation mode}] \
		[list -arg -default_pdq        -mand 0 -check UINT     -default_cfg DB_DEFAULT_PDQ       -default 0          -desc {Default PDQ priority (parallelisation)}] \
		[list -arg -max_pdq            -mand 0 -check UINT     -default_cfg DB_MAX_PDQ           -default 0          -desc {Max PDQ priority}] \
		[list -arg -statement_timeout  -mand 0 -check BOOL     -default_cfg DB_STMT_TIMEOUT      -default 0          -desc {Should failure on a connections restart process}] \
		[list -arg -use_fetch          -mand 0 -check BOOL     -default_cfg DB_USE_FETCH         -default 1          -desc {Use fetch cursor}] \
		[list -arg -store_active_sess  -mand 0 -check BOOL     -default_cfg DB_STORE_ACTIVE_SESS -default 1          -desc {Record application/sid details on connection to db}] \
		[list -arg -store_sess_info    -mand 0 -check BOOL     -default_cfg DB_STORE_SESS_INFO   -default 1          -desc {On session termination store session info}] \
		[list -arg -sess_app_name      -mand 0 -check ASCII    -default_cfg APP_TAG              -default "default"  -desc {Application name for the session}] \
		[list -arg -sess_group_no      -mand 0 -check ASCII                                      -default {}         -desc {Appserver group number for the session}] \
		[list -arg -sess_child_no      -mand 0 -check ASCII                                      -default {}         -desc {Appserver child number for the session}] \
		[list -arg -conn_retries       -mand 0 -check UINT     -default_cfg DB_CONN_RETRIES      -default 0          -desc {Number of attempts to connect to be made}] \
		[list -arg -lazy_connect       -mand 0 -check BOOL     -default_cfg DB_LAZY_CONNECT      -default 1          -desc {Controls lazy reconnection}] \
		[list -arg -delete_active_sess -mand 0 -check BOOL                                       -default 1          -desc {Deletes the active session data}] \
		[list -arg -sql_mode           -mand 0 -check ASCII                                      -default {STRICT_ALL_TABLES} -desc {MySQL sql mode http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html}] \
	]

# Connect to the database server using cfg values.
# If the connection fails, asRestart will be called. Standalone scripts
# must supply asRestart procedure.
#
# @param conn_name Unique name to identify the connection
#
proc core::db::connect args {

	variable CFG
	variable CONN
	variable PDQ_LIST
	variable DB_LIST
	variable DB_DATA
	variable BUFREADS

	array set ARGS [core::args::check core::db::connect {*}$args]

	set conn_name $ARGS(-conn_name)

	if {!$CFG(init)} {
		error "Package not initialiased"
	}

	# initialised the connection
	if {[info exists CONN($conn_name)]} {
		core::log::write WARNING {DB $conn_name: already initialised connection}
		return
	}

	set CFG($conn_name,package)              $ARGS(-package)
	set CFG($conn_name,package_uc)           [string toupper $ARGS(-package)]
	set CFG($conn_name,servers)              $ARGS(-servers)
	set CFG($conn_name,database)             $ARGS(-database)
	set CFG($conn_name,db_port)              $ARGS(-db_port)
	set CFG($conn_name,username)             $ARGS(-username)
	set CFG($conn_name,password)             $ARGS(-password)
	set CFG($conn_name,prep_ondemand)        $ARGS(-prep_ondemand)
	set CFG($conn_name,no_cache)             $ARGS(-no_cache)

	# These configs are set for the lazy connection
	set CFG($conn_name,conn_retries)         $ARGS(-conn_retries)
	set CFG($conn_name,lazy_connect)         $ARGS(-lazy_connect)
	set CFG($conn_name,delete_active_sess)   $ARGS(-delete_active_sess) ;# remove application/sid details on disconnection from db

	set CFG($conn_name,log_qry_params)       $ARGS(-log_qry_params)
	set CFG($conn_name,log_qry_time)         $ARGS(-log_qry_time)
	set CFG($conn_name,log_lock_time)        $ARGS(-log_lock_time)
	set CFG($conn_name,log_qry_nrows)        $ARGS(-log_qry_nrows)
	set CFG($conn_name,log_longq)            $ARGS(-log_longq)
	set CFG($conn_name,log_explain)          $ARGS(-log_explain)
	set CFG($conn_name,log_on_error)         $ARGS(-log_on_error)
	set CFG($conn_name,log_bufreads)         $ARGS(-log_bufreads)
	set CFG($conn_name,log_err)              [list]

	# These configs are switchable by the calling code
	set CFG($conn_name,log_qry_params,switchable)    1
	set CFG($conn_name,log_qry_time,switchable)      1
	set CFG($conn_name,log_lock_time,switchable)     1
	set CFG($conn_name,log_qry_nrows,switchable)     1
	set CFG($conn_name,log_longq,switchable)         1
	set CFG($conn_name,log_explain,switchable)       1
	set CFG($conn_name,log_on_error,switchable)      1

	set CFG($conn_name,wait_time)            $ARGS(-wait_time)
	set CFG($conn_name,isolation_level)      $ARGS(-isolation_level)
	set CFG($conn_name,default_pdq)          $ARGS(-default_pdq)
	set CFG($conn_name,max_pdq)              $ARGS(-max_pdq)
	set CFG($conn_name,use_fetch)            $ARGS(-use_fetch)
	set CFG($conn_name,sql_mode)             $ARGS(-sql_mode)           ;# mySQL mode defines what SQL syntax MySQL should support and what kind of data validation checks it should perform

	# Postgres specific
	set CFG($conn_name,statement_timeout)    $ARGS(-statement_timeout)  ;# Should failure on a connections restart process?
	set CFG($conn_name,restart_on_error)     $ARGS(-restart_on_error)   ;# Should failure on a connections restart process?
	set CFG($conn_name,failover)             $ARGS(-failover)           ;# Database failover connection name?
	set CFG($conn_name,failover,min_cache)   $ARGS(-failover_min_cache) ;# Min resultant cache time for a query
	set CFG($conn_name,failover,max_delay)   $ARGS(-failover_max_delay) ;# Delay on a replicated db before failover
	set CFG($conn_name,delayed)              $ARGS(-delayed)            ;# Is the db delayed (replicated)?
	set CFG($conn_name,reduce_cache)         $ARGS(-reduce_cache)       ;# Reduce cache times by current db delay

	# Analytic information
	set CFG($conn_name,store_active_sess)    $ARGS(-store_active_sess) ;# record application/sid details on connection to db
	set CFG($conn_name,store_sess_info)      $ARGS(-store_sess_info)   ;# on session termination stored session info
	set CFG($conn_name,sess_app_name)        $ARGS(-sess_app_name)
	set CFG($conn_name,sess_group_no)        $ARGS(-sess_group_no)
	set CFG($conn_name,sess_child_no)        $ARGS(-sess_child_no)

	# set default sess_child_no
	if {[llength [info commands asGetId]] && $CFG($conn_name,sess_child_no) == {}} {
		set CFG($conn_name,sess_child_no) [asGetId]

	}

	# Set default sess_group_no
	if {[llength [info commands asGetGroupId]] && $CFG($conn_name,sess_group_no) == {}} {
		set CFG($conn_name,sess_group_no) [asGetGroupId]
	}

	set CFG($conn_name,adhoc_query_names) [list]

	# bufreads query prepared stmt
	set DB_DATA($conn_name,bufreads) ""

	# Setup failover db
	if {$CFG($conn_name,failover) != 0} {
		set CFG($conn_name,failover,db) $CFG($conn_name,failover)
		set CFG($conn_name,failover) 1
	}

	# Ensure we have the correct db package available
	# and configure capabilities for different providers
	switch -- $CFG($conn_name,package_uc) {
		INFORMIX   -
		INFSQL   {
			set CFG($conn_name,namespace) core::db::informix
		}
		POSTGRESQL {
			set CFG($conn_name,namespace) core::db::postgreSQL
			set CFG($conn_name,use_fetch) 0
			set CFG($conn_name,wait_time) 0
		}
		MYSQL {
			set CFG($conn_name,namespace) core::db::mySQL
			set CFG($conn_name,use_fetch) 0
			set CFG($conn_name,wait_time) 0
			set CFG($conn_name,store_active_sess) 0
		}
		default {
			error "Unrecognised db package $CFG($conn_name,package)"
		}
	}

	package require $CFG($conn_name,namespace)

	# If we have been passed multiple servers then randomnly choose one,
	# this is used to load balance across multiple services preventing
	# a single port becoming overloaded
	set len [llength $CFG($conn_name,servers)]
	if {$len > 1} {
		set CFG($conn_name,server) [lindex $CFG($conn_name,servers) [expr {int(rand() * $len)}]]
	} else {
		set CFG($conn_name,server) $CFG($conn_name,servers)
	}

	# result set cache/expire time (lists kept in expiry time order)
	set DB_DATA($conn_name,rs_list) [list]
	set DB_DATA($conn_name,rs_exp)  [list]

	# init result-set cache
	set DB_DATA($conn_name,rss) {}

	# Initialise query semaphores if required.
	_init_qry_sems $conn_name
	if {$CFG(allow_expired) && !$CFG(use_qry_sems)} {
		core::log::write WARNING {DB $conn_name: can only allow expired results if query semaphores are in use}
		set CFG(allow_expired) 0
	}
	if {$CFG(extend_expired) && !$CFG(allow_expired)} {
		core::log::write WARNING {DB $conn_name: can only extend expired results if expired results are allowed}
		set CFG(extend_expired) 0
	}

	# If we have a distributed cached turned on then make sure we have semaphores and expired rs
	# we need to be able to serve an expired rs if we don't get a hit
	# but if there is no hit at all then we only want one child per app running the query
	if {$CFG(distrib_cache)} {
		if {[llength [OT_CfgGet AS_DIST_CACHE_SERVERS [list]]] == 0} {
			error "distributed cache enabled but servers not defined"
		} elseif { !$CFG(use_qry_sems) } {
			error "distributed cache servers are defined but query-semaphores not enabled"
		} elseif { !$CFG(allow_expired) } {
			error "distributed cache servers are defined but expired result-sets not allowed"
		}
	}

	lappend DB_DATA(connections) $conn_name

	if {$CFG($conn_name,lazy_connect)} {
		core::log::write INFO {Connection to $conn_name will be lazily initialised.}
		set CONN($conn_name) ""
		trace add variable CONN($conn_name) read [list core::db::_connect $conn_name]
	} else {
		#Connect to the DB server
		_connect $conn_name
	}
	return
}

# Get configuration values
core::args::register \
	-proc_name core::db::get_config \
	-desc  {Retrieve database configuration} \
	-args [list \
		[list -arg -name      -mand 1 -check STRING             -desc {Configuration name}] \
		[list -arg -default   -mand 0 -check ANY    -default {} -desc {Configuration default value}] \
		[list -arg -conn_name -mand 0 -check ASCII  -default {} -desc {Database connection name}] \
	] \
	-body {
		variable CFG

		set name      $ARGS(-name)
		set conn_name $ARGS(-conn_name)

		if {$conn_name != {}} {
			set key "$conn_name,$name"
		} else {
			set key $name
		}

		if {[info exists CFG($key)]} {

			return $CFG($key)
		}

		return $ARGS(-default)
	}

# Connect to the database server given a configured connection name
proc core::db::_connect {conn_name args} {

	variable CFG
	variable CONN
	variable PDQ_LIST
	variable DB_LIST
	variable DB_DATA
	variable BUFREADS

	if {$CFG($conn_name,lazy_connect)} {
		trace remove variable CONN($conn_name) read [list core::db::_connect $conn_name]
	}

	if {[lsearch $DB_DATA(connections) $conn_name] == -1} {
		core::log::write ERROR {DB : unable to find connection $conn_name}
		error "unable to find connection $conn_name"
	}

	set serv  $CFG($conn_name,server)
	set dbase $CFG($conn_name,database)
	set port  $CFG($conn_name,db_port)

	core::log::write INFO {DB $conn_name: running ${dbase}@${serv}:$port $CFG($conn_name,username)}

	set conn_attempts 0

	#Attempt to connect
	while {$conn_attempts <= $CFG($conn_name,conn_retries)} {

		if {[catch {
			set CONN($conn_name) [$CFG($conn_name,namespace)::open_conn \
				-db_name   $dbase \
				-db_server $serv  \
				-db_port   $port  \
				-username  $CFG($conn_name,username) \
				-password  $CFG($conn_name,password)]
		} msg]} {
			set msg "DB $conn_name: Failed to open connection to DB server $msg"
			core::log::write CRITICAL {$msg}

			if {
				$CFG($conn_name,conn_retries) > 0 &&
				![info exists CFG($conn_name,connected)] &&
				$conn_attempts < $CFG($conn_name,conn_retries)
			} {
				set timeout [expr {(2 ** $conn_attempts) * 1000}]
				core::log::write ERROR {DB $conn_name: Will attempt to connect again in ${timeout}ms}
				after $timeout
			}

		} else {
			core::log::write ERROR {DB $conn_name: successfully connected}

			set CFG($conn_name,connected) [clock seconds]
			break
		}
		incr conn_attempts
	}

	if {![info exists CFG($conn_name,connected)]} {
		error "DB connection does not exist"
	}

	# set lock mode (seconds)
	if {$CFG($conn_name,wait_time) != 0} {
		core::log::write INFO\
		    {DB $conn_name: set lock mode to $CFG($conn_name,wait_time)}

		if {$CFG($conn_name,wait_time) == "zero"} {
			set stmt [$CFG($conn_name,namespace)::prep_sql \
				-conn_name $CONN($conn_name)\
			    -qry       "set lock mode to not wait"]
		} else {
			set stmt [$CFG($conn_name,namespace)::prep_sql \
				-conn_name $CONN($conn_name)\
			    -qry       "set lock mode to wait $CFG($conn_name,wait_time)"]
		}
		$CFG($conn_name,namespace)::exec_stmt \
			-conn_name $CONN($conn_name) \
			-inc_type  0 \
			-stmt      $stmt

		$CFG($conn_name,namespace)::close_stmt \
			-conn_name $CONN($conn_name) \
			-stmt      $stmt
	}

	# set isolation level?
	if {$CFG($conn_name,isolation_level) != 0} {
		core::log::write INFO\
		    {DB $conn_name: set iso level to $CFG($conn_name,isolation_level)}

		set stmt [$CFG($conn_name,namespace)::prep_sql \
			-conn_name $CONN($conn_name)\
		    -qry       "set isolation to $CFG($conn_name,isolation_level)"]

		$CFG($conn_name,namespace)::exec_stmt \
			-conn_name $CONN($conn_name) \
			-inc_type  0 \
			-stmt      $stmt

		$CFG($conn_name,namespace)::close_stmt \
			-conn_name $CONN($conn_name) \
			-stmt      $stmt
	}

	# set default PDQ
	set PDQ_LIST($conn_name) $CFG($conn_name,default_pdq)
	if {$CFG($conn_name,default_pdq)} {
		_set_pdq $conn_name $CFG($conn_name,default_pdq)
	}

	# TODO: SKY v1.9.22.8, CBT v1.2.34.23 -> log session id
	# (needs to move to informix/postgres specific files)

	set sessionid [$CFG($conn_name,namespace)::get_sessionid -conn_name $CONN($conn_name)]
	core::log::write ERROR {DB $conn_name: sessionid is $sessionid}

	# unset previously prepared statements
	foreach stmt [array names DB_DATA "$conn_name,*,stmt"] {
		unset DB_DATA($stmt)
	}

	if {$CFG($conn_name,log_bufreads) == 1} {
		set BUFREADS($conn_name,buf_reads) [$CFG($conn_name,namespace)::buf_reads -conn_name $CONN($conn_name)]
	}

	# Modes define what SQL syntax MySQL should support and what kind of data
	# validation checks it should perform.
	#
	# http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html#sqlmode_strict_all_tables
	if {$CFG($conn_name,package_uc) == {MYSQL} && $CFG($conn_name,sql_mode) != {}} {
		core::db::register_adhoc_query \
			-name        core::db::set_sql_mode \
			-connections [list $conn_name]

		core::db::run_adhoc_query \
			-name      core::db::set_sql_mode \
			-query     [format "set sql_mode='%s'" $CFG($conn_name,sql_mode)]\
			-conn_name $conn_name
	}

	# insert session record
	if {$CFG($conn_name,store_active_sess)} {
		insert_active_sess -conn_name $conn_name
	}

	if {[$CFG($conn_name,namespace)::set_timeout \
		-conn_name $CONN($conn_name) \
		-timeout   $CFG($conn_name,statement_timeout)]} {
			core::log::write INFO {DB $conn_name: Statement timeout set to $CFG($conn_name,statement_timeout) milliseconds}
		}
}

# Get query by name
core::args::register \
	-proc_name core::db::get_qry_string \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(name) \
	]

# get_qry_string
# @param -conn_name
# @param -qry
# Returns the list of defined SQL statements for the given DB connection

proc core::db::get_qry_string args {
	variable DB_DATA

	array set ARGS [core::args::check core::db::get_qry_string {*}$args]

	set conn_name $ARGS(-conn_name)
	set name $ARGS(-name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	return $DB_DATA($conn_name,$name,qry_string)
}

core::args::register \
	-proc_name core::db::get_statements \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# get_statements
# @param -conn_name
# Returns the list of defined SQL statements for the given DB connection

proc core::db::get_statements args {
	variable DB_DATA

	array set ARGS [core::args::check core::db::get_statements {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	set names [list]

	foreach name [array names DB_DATA "$conn_name,*,name"] {
		lappend names $DB_DATA($name)
	}

	return $names
}

core::args::register \
	-proc_name core::db::disconnect \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Public function to disconnect from a named connection
# @param -conn_name Unique name to identify the connection

proc core::db::disconnect args {

	variable CFG
	variable CONN
	variable DB_DATA

	array set ARGS [core::args::check core::db::disconnect {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {![info exists CFG($conn_name,connected)]} {
		core::log::write INFO {DB $conn_name: is not connected, returning.}
		return
	}

	# delete active session record into db
	if {$CFG($conn_name,delete_active_sess)} {
		core::db::delete_active_sess -conn_name $conn_name
	}

	# store session summary in db
	if {$CFG($conn_name,store_sess_info)} {
		core::db::store_sess_info -conn_name $conn_name
	}

	if {[catch {
		$CFG($conn_name,namespace)::close_conn -conn_name $CONN($conn_name)

		unset CONN($conn_name)

		set DB_DATA(connections) [core::util::ldelete $DB_DATA(connections) $conn_name]

		array set CFG [array unset CFG ${conn_name}*]

		# unset previously prepared statements
		foreach stmt [array names DB_DATA "$conn_name,*,stmt"] {
			unset DB_DATA($stmt)
		}
	} msg]} {
		set msg "DB $conn_name: Failed to disconnect from DB server $msg"
		core::log::write CRITICAL {$msg}
		error $msg $::errorInfo $::errorCode
	}
}

#--------------------------------------------------------------------------
# Prepare Queries
#--------------------------------------------------------------------------


core::args::register \
	-proc_name core::db::store_qry \
	-args [list \
		$::core::db::CORE_DEF(connections) \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(qry) \
		[list -arg -cache           -mand 0 -check UINT  -default 0  -desc {result set cache time (seconds) disabled if DB_NO_CACHE cfg value is non-zero}] \
		[list -arg -force           -mand 0 -check BOOL  -default 0  -desc {If another query exists with this name then force this one into this place}] \
		[list -arg -extend_expired  -mand 0 -check BOOL  -default 1  -desc {Allows DB_EXTEND_EXPIRED to be enabled/disabled on a per-query basis}] \
		[list -arg -allow_expired   -mand 0 -check BOOL  -default 1  -desc {Allows use of expired results to be disabled on a per-query basis}] \
		[list -arg -mask_qry_params -mand 0 -check BOOL  -default 0  -desc {Mask the query params when logging}] \
	]

# Store a named query.
# If DB_PREP_ONDEMAND cfg value is set to zero, then the named query will
# be prepared. If value is set to non-zero, the query will be prepared
# the 1st time it's used.
#
# @param -conn_name Unique name which identifies the connection
# @param -name Query name
# @qry   -SQL query
# @param -cache Result set cache time (seconds)
#    disabled if DB_NO_CACHE cfg value is non-zero
#
# @param -force If another query exists with this name then force this one
#   into this place (default 0)
#
# @param -extend_expired Allows DB_EXTEND_EXPIRED to be enabled/disabled on
#   a per-query basis (default 1).
#
proc core::db::store_qry args {

	variable CFG
	variable DB_DATA
	variable CONN

	array set ARGS [core::args::check core::db::store_qry {*}$args]

	set name            $ARGS(-name)
	set qry             $ARGS(-qry)
	set qry_hash        [md5 $qry]
	set cache           $ARGS(-cache)
	set force           $ARGS(-force)
	set extend_expired  $ARGS(-extend_expired)
	set allow_expired   $ARGS(-allow_expired)
	set connections     $ARGS(-connections)
	set mask_qry_params $ARGS(-mask_qry_params)

	if {!$CFG(init)} {
		error "Package not initialiased"
	}

	# If no connections have been passed we should use all registered
	if {![llength $connections]} {
		if {[info exists CFG(query,$name,conn_name)]} {
			set connections $CFG(query,$name,conn_name)
		} else {
			set connections $DB_DATA(connections)
		}
	}

	# Adding the query name to the SQL statement (query name will be in the explain plan too)
	set qry "-- stmt: $name\n$qry"

	# Ensure that the qry exists against the specified connection
	foreach conn_name $connections {

		core::log::write INFO {DB $conn_name: store_qry $name}

		if {[info exists DB_DATA($conn_name,$name,qry_string)]} {

			# Backwards compatibility: If the queries are identical
			#   then allow them through
			if {$DB_DATA($conn_name,$name,name)       != $name || \
				$DB_DATA($conn_name,$name,qry_string) != $qry  || \
				$DB_DATA($conn_name,$name,cache_time) != $cache } {

				if {$DB_DATA($conn_name,$name,name) != $name} {
					core::log::write CRITICAL {DB $conn_name: name differs $DB_DATA($conn_name,$name,name) != $name}
				}
				if {$DB_DATA($conn_name,$name,qry_string) != $qry} {
					regsub -all {\s} $DB_DATA($conn_name,$name,qry_string) {} q1
					regsub -all {\s} $qry {} q2
					if {$q1 == $q2 } {
						core::log::write CRITICAL {***********************************}
						core::log::write CRITICAL {* WARNING! Trying to reprepare qry: $name}
						core::log::write CRITICAL {* WARNING! query text is different }
						core::log::write CRITICAL {* WARNING! fix this! }
						core::log::write CRITICAL {***********************************}
						core::log::write CRITICAL {DB $conn_name: string differs $DB_DATA($conn_name,$name,qry_string) != $qry}
						return
					}
				}
				if {$DB_DATA($conn_name,$name,cache_time) != $cache } {
					core::log::write CRITICAL {DB $conn_name: cache differs $DB_DATA($conn_name,$name,cache_time) != $cache}
				}

				error "Query $name already exists with different parameters"

			} elseif {!$force} {


				core::log::write CRITICAL {***********************************}
				core::log::write CRITICAL {* WARNING! Trying to reprepare qry: $name}
				core::log::write CRITICAL {***********************************}
				return
			}
		}

		if {$name == "rs" || [regexp {,} $name]} {
			error "Illegal query name - $name"
		}

		if {$extend_expired && !$allow_expired} {
			core::log::write WARNING {DB $conn_name: $name can only extend expired results if expired results are allowed}
			set extend_expired 0
		}

		# caching enabled?
		if {$CFG($conn_name,no_cache) && $cache} {
			core::log::write WARNING {DB $conn_name: $name caching is disabled}
			set cache 0
		}

		# add query to list
		lappend   DB_DATA($name,connections) $conn_name
		array set DB_DATA [list \
			$conn_name,$name,name            $name \
			$conn_name,$name,qry_string      $qry \
			$conn_name,$name,qry_hash        $qry_hash \
			$conn_name,$name,cache_time      $cache \
			$conn_name,$name,extend_expired  $extend_expired \
			$conn_name,$name,allow_expired   $allow_expired \
			$conn_name,$name,mask_qry_params $mask_qry_params]

		# prepare the query?
		if {!$CFG($conn_name,prep_ondemand)} {
			if {[catch {_new_prep_qry $conn_name $name} msg]} {
				core::db::restart -conn_name $conn_name
				error $msg $::errorInfo $::errorCode
			}
		}
	}

	# Store the query to a debug file for analysis
	if {$CFG(debug_qry_file) != {}} {
		write_qry_debug \
			-connections $connections \
			-name        $name \
			-qry         $qry \
			-cache       $cache
	}
}

core::args::register \
	-proc_name core::db::register_adhoc_query \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(connections) \
	]

# Register a adhoc-query name. This name is later used by run_adhoc_query.
#
# @param -connections List of the connections for which to register this query.
# @param -name The name of the adhoc query.
#
proc core::db::register_adhoc_query args {

	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::register_adhoc_query {*}$args]

	set name        $ARGS(-name)
	set connections $ARGS(-connections)

	# If no connections have been passed we should use all registered
	if {![llength $connections]} {
		set connections $DB_DATA(connections)
	}

	foreach conn_name $connections {
		if {[lsearch $CFG($conn_name,adhoc_query_names) $name] > -1} {
			# The name is already registered for this connection.
			continue
		}
		lappend CFG($conn_name,adhoc_query_names) $name
	}
}


core::args::register \
	-proc_name core::db::cache_qry \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(connections) \
		[list -arg -cache -mand 1 -check ASCII -desc {Result set cache time (seconds)}] \
	]

# Set the cache-time for a named query.
#
# @param connections List of valid connections (defaulting to all)
# @param name      Query name
# @cache Result set cache time (seconds) disabled if -no_cache cfg value is non-zero
#
proc core::db::cache_qry args {

	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::cache_qry {*}$args]

	set name        $ARGS(-name)
	set cache       $ARGS(-cache)
	set connections $ARGS(-connections)

	if {![llength $connections]} {
		if {![info exists DB_DATA($name,connections)]} {
			error "no prepared statement found for query '$name' on any connection"
		}
		set connections $DB_DATA($name,connections)
	}

	# validate
	foreach conn_name $connections {

		core::log::write DEV {DB $conn_name: cache_qry $name}

		if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
			error "No such query $name exists"
		}
		if {$name == "rs" || [regexp {,} $name]} {
			error "Illegal query name - $name"
		}

		# caching enabled?
		if {$CFG($conn_name,no_cache) && $cache} {
			core::log::write WARNING {DB $conn_name: $name caching is disabled}
			set cache 0
		}

		# set cache time
		set DB_DATA($conn_name,$name,cache_time) $cache
	}

}

core::args::register \
	-proc_name core::db::check_qry \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(conn_name) \
	]

# Check if a named query has already been prepared
#
# @param -conn_name Unique name which identifies the connection
#   if not supplied the pimary connection is checked
# @param name Query name
#
# @return 1 if query has already been prepared else 0
#
proc core::db::check_qry args {

	variable DB_DATA

	array set ARGS [core::args::check core::db::check_qry {*}$args]

	set name      $ARGS(-name)
	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	core::log::write DEBUG {DB $conn_name: Checking statement $name}

	if {[info exists DB_DATA($name,connections)] && [info exists DB_DATA($conn_name,$name,stmt)]} {
		return 1
	}

	return 0
}

core::args::register \
	-proc_name core::db::unprep_qry \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(connections) \
	]

# Unprepare a stored name query.
#
# @param -connections Unique name which identifies the connection
#   If this is not passed stmt is closed on all open connections
# @param -name Query name
proc core::db::unprep_qry args {

	variable DB_DATA
	variable CFG
	variable CONN

	array set ARGS [core::args::check core::db::unprep_qry {*}$args]

	set name        $ARGS(-name)
	set connections $ARGS(-connections)

	core::log::write DEBUG {DB Unpreparing statement $name}

	# If no connection is passed, close on all connections
	if {![llength $connections]} {
		if {[info exists DB_DATA($name,connections)]} {
			set connections $DB_DATA($name,connections)
		} else {
			set connections [list]
		}
	}

	# Close on all outstanding connections
	foreach conn_name $connections {

		if {[info exists DB_DATA($conn_name,$name,stmt)]} {
			$CFG($conn_name,namespace)::close_stmt \
				-conn_name $CONN($conn_name) \
				-stmt      $DB_DATA($conn_name,$name,stmt)
		}

		foreach k [array names DB_DATA "$conn_name,$name,*"] {
			unset DB_DATA($k)
		}
	}

	set remaining_conns [list]
	if {[info exists DB_DATA($name,connections)]} {
		foreach connection $DB_DATA($name,connections) {
			if {[lsearch -exact $connections $connection] < 0} {
				lappend remaining_conns $connection
			}
		}
	}

	set DB_DATA($name,connections) $remaining_conns
}

# Invalidated a named query.
#
# @param -connections List of connections
# @param -name Query name
#
core::args::register \
	-proc_name core::db::invalidate_qry \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(connections) \
	] \
	-body {
		variable DB_DATA

		set name        $ARGS(-name)
		set connections $ARGS(-connections)

		if {![llength $connections]} {
			if {[info exists DB_DATA($name,connections)]} {
				set connections $DB_DATA($name,connections)
			} else {
				set connections [list]
			}
		}

		foreach conn_name $connections {
			core::log::write DEBUG {DB $conn_name: invalidating query $name}
			set DB_DATA($conn_name,$name,stmt_invalid) [clock seconds]
		}
	}

# Invalidate a result set.
#
# @param -connections List of connections
# @param -name Query name
# @param -args list of arguments to provide
#
core::args::register \
	-proc_name core::db::invalidate_cached_rs \
	-args [list \
		$::core::db::CORE_DEF(connections) \
		$::core::db::CORE_DEF(name) \
		[list -arg -args             -mand 0 -check ANY    -default {} -desc {Query arguments}] \
	] \
	-body {
		variable DB_DATA
		variable CFG

		set qry_name    $ARGS(-name)
		set argkey      [join $ARGS(-args) {,}]
		set connections $ARGS(-connections)

		# Validate Connection
		if {[llength $connections]} {
			set conn_name [lindex $connections 0]
		} else {
			if {[info exists DB_DATA($qry_name,connections)]} {
				set conn_name [lindex $DB_DATA($qry_name,connections) 0]
			} else {
				error "no prepared statement found for query '$qry_name' on any connection (check store_qry executed)"
			}
		}

		set qry_hash $DB_DATA($conn_name,$qry_name,qry_hash)
		set DB_DATA($conn_name,$qry_name,$qry_hash,$argkey,invalidated) 1

		if {$CFG(shm_cache)} {

			# If using qry semaphores we need to lock before clearing
			if {$CFG(use_qry_sems)} {
				set sem_id $CFG(shared_qry_sems_id)
				set rs_info [asFindRs -expired -alloc-sem sem_idx $conn_name,$qry_name,$qry_hash,$argkey]

				# Wait for a lock
				if {$sem_idx != -1} {
					ipc_sem_lock $sem_id $sem_idx
				}

				# Clear out the cached result set
				asStoreRs [lindex $rs_info 0] $conn_name,$qry_name,$qry_hash,$argkey 0

				# Unlock
				if {$sem_idx != -1} {
					ipc_sem_unlock $sem_id $sem_idx
				}
			} else {
				set rs_info [asFindRs -expired $conn_name,$qry_name,$qry_hash,$argkey]

				# Clear out the cached result set
				asStoreRs [lindex $rs_info 0] $conn_name,$qry_name,$qry_hash,$argkey 0
			}
		}

	}


# Private procedure to prepare and add a new SQL query name.
#
# @param conn_name Unique name which identifies the connection
# @param name      Query name
#
proc core::db::_new_prep_qry { conn_name name } {

	variable DB_DATA
	variable CONN
	variable CFG

	core::log::write DEBUG {DB $conn_name: preparing query $name}

	# close previous invalid statement?
	if {[info exists DB_DATA($conn_name,$name,stmt)]} {
		$CFG($conn_name,namespace)::close_stmt \
			-conn_name $CONN($conn_name) \
			-stmt      $DB_DATA($conn_name,$name,stmt)
		unset DB_DATA($conn_name,$name,stmt)
	}

	# prepare query
	set now [clock seconds]
	if {[catch {
		set stmt [_try_prep_qry \
			$conn_name \
			$DB_DATA($conn_name,$name,qry_string)]
	} msg]} {
		set msg "failed to prepare $name $msg"
		if {$CFG($conn_name,log_on_error) == 1} {
			set err_sql [_qry_error_annotate -sql $DB_DATA($conn_name,$name,qry_string) -msg $msg]
			core::log::write_qry CRITICAL "DB $conn_name" $msg $err_sql
		}
		error $msg $::errorInfo $::errorCode
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
# @param conn_name  Unique name which identifies the connection
# @param qry        Query to prepare
# @param in_reprep  denote the proc is within a recursive loop (default: 0)
#
proc core::db::_try_prep_qry { conn_name qry {in_reprep 0} } {

	variable CONN
	variable CFG

	if {[catch {
		set stmt [$CFG($conn_name,namespace)::prep_sql \
			-conn_name $CONN($conn_name) \
			-qry       $qry]
	} msg]} {

		# if error code in reconn list, or allow re-prep, then establish a new
		# db connection and re-attempt the prep
		set err_code [core::db::failover::handle_error \
			-conn_name $conn_name \
			-package   $CFG($conn_name,package) \
			-attempt   $in_reprep \
			-msg       $msg]

		switch -- $err_code {
			REPREP {
				return [_try_prep_qry $conn_name $qry 1]
			}
			RECONN {
				_connect $conn_name
				return [_try_prep_qry $conn_name $qry 1]
			}
			RESTART {
				core::db::restart -conn_name $conn_name
				error $msg $::errorInfo $::errorCode
			}
			NOOP    -
			LOG     -
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

core::args::register \
	-proc_name core::db::exec_qry \
	-args [list \
		$::core::db::CORE_DEF(connections) \
		$::core::db::CORE_DEF(name) \
		[list -arg -force            -mand 0 -check BOOL   -default 0  -desc {Force the execution of the query}] \
		[list -arg -append_cache_key -mand 0 -check STRING -default {} -desc {Append onto the query cache key (cache buster)}] \
		[list -arg -args             -mand 0 -check ANY    -default {} -desc {Query arguments}] \
	]

# Execute a named query.
# The first 'arg' may include the -inc-type specifier which identifies the
# parameter types for CLOB/BLOB support.
#
# @param -name        SQL query name
# @param -connections Database connections
# @param -args        query arguments
# @append_cache_key   Append onto the cache key (cache buster)
#
# @return Query [cached] result set
#
proc core::db::exec_qry args {

	variable DB_DATA
	variable CFG

	array set ARGS [core::args::check core::db::exec_qry {*}$args]

	set connections $ARGS(-connections)
	set name        $ARGS(-name)
	set force       $ARGS(-force)
	set argkey      [join $ARGS(-args) {,}]

	# Validate Connection
	if {[llength $connections]} {
		set conn_name [lindex $connections 0]
	} else {
		if {[info exists DB_DATA($name,connections)]} {
			set conn_name [lindex $DB_DATA($name,connections) 0]
		} else {
			error "no prepared statement found for query '$name' on any connection (check store_qry executed)"
		}
	}

	# Establish the connection
	if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
		error "DB $conn_name: statement $name does not exist for con $conn_name"
	}

	set qry_hash $DB_DATA($conn_name,$name,qry_hash)

	# Check whether to force the query as the cached result set has
	# been invalidated
	if {[info exists DB_DATA($conn_name,$name,$qry_hash,$argkey,invalidated)]} {
		set force 1
		unset DB_DATA($conn_name,$name,$qry_hash,$argkey,invalidated)
	}

	if {$CFG(shm_cache)} {
		return [_exec_qry_shm \
			$conn_name \
			$name \
			$force \
			$ARGS(-append_cache_key) \
			$ARGS(-args)]
	} else {
		return [_exec_qry_no_shm \
			$conn_name \
			$name \
			$force \
			$ARGS(-append_cache_key) \
			$ARGS(-args)]
	}
}

# Private procedure to execute a query where the package has detected
# shared memory capabilities (appserv).
# Cached result sets are removed from the local store via core::db::req_end,
# the shared memory will handle cache expire time.
# Please use core::db::exec_qry.
#
# @param conn_name  Unique name which identifies the connection
# @param name       SQL query name
# @param force      Run the query even if a suitable cached result set is
#    available (use with care)
# @append_cache_key Append onto the cache key (cache buster)
# @param arglist    Query arguments
# @return           Query [cached] result set
#
proc core::db::_exec_qry_shm { conn_name name force append_cache_key arglist } {

	variable DB_DATA
	variable CFG
	variable CONN
	variable IN_TRAN

	if {$force} {
		core::log::write WARNING\
		    {DB $conn_name: exec forced -$name- with args: $arglist}
	} else {
		core::log::write DEV\
		    {DB $conn_name: _exec_qry_shm -$name- with args: $arglist}
	}

	# is result-set cached?
	if {$DB_DATA($conn_name,$name,cache_time)} {

		set argkey [join $arglist ","]

		# Append the arglist to be the cache buster if passed
		if {$append_cache_key != {}} {
			append argkey $append_cache_key
		}

		# A result set can be reused within the same request as it wont be
		# cleaned up by the appserver until req_end. But we can't store it if
		# the query is cached during main_init as it will be cleared by the
		# appserver when main_init is finished
		if {$CFG(get_status)} {
			set reuse_cached_rs [expr {[lsearch { initialising main_init } [asGetState]] == -1}]
		} else {
			set reuse_cached_rs [expr {([asGetReqAccept] && [reqGetId] == 0)}]
		}

		# If we have a background child process, we want to make the result set cache
		# key unique per background child process. This is because if we have more than
		# one background child sharing a query with the same name, one could clear the
		# result set while another thinks it's still there and end up with a 'result
		# set not found' error
		if {$CFG(get_status)} {
			if {[asGetState] in {"time-out proc" "timeout proc"}} {
				set argkey ${argkey}[asGetId]
			}
		} else {
			if {![asGetReqAccept]} {
				set argkey ${argkey}[asGetId]
			}
		}

		set qry_hash $DB_DATA($conn_name,$name,qry_hash)

		# rs cached and previously seen by this request
		if {!$force && [info exists DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)]} {

			core::log::write DEBUG {DB $conn_name: (shm) using cached rs}
			set rs $DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)

		# criteria for using _exec_qry_sems are met
		# (in which case it effectively takes over this query)
		} elseif {![info exists IN_TRAN($conn_name)] && !$force && $CFG(use_qry_sems)} {

			set rs [_exec_qry_sems $conn_name $name $qry_hash $arglist $argkey \
				[expr {$CFG(allow_expired) && \
					$DB_DATA($conn_name,$name,allow_expired)}] \
			]

			if {$reuse_cached_rs} {
				set DB_DATA($conn_name,$name,$qry_hash,$argkey,rs) $rs
				lappend DB_DATA($conn_name,rss) $conn_name,$name,$qry_hash,$argkey,rs
			}

		# rs cached, but not seen by current request
		} elseif {!$force &&\
		        ![catch {set rs [asFindRs $conn_name,$name,$qry_hash,$argkey]}]} {

			if {$reuse_cached_rs} {
				core::log::write DEBUG\
				    {DB $conn_name: (shm) using shared memory cached rs}
				set DB_DATA($conn_name,$name,$qry_hash,$argkey,rs) $rs
				lappend DB_DATA($conn_name,rss) $conn_name,$name,$qry_hash,$argkey,rs
			}

		# rs cached and previously seen by this request on the failover connection
		} elseif {!$force && \
				$CFG($conn_name,failover) && \
				[info exists DB_DATA($CFG($conn_name,failover,db),$name,$qry_hash,$argkey,rs)]} {

			core::log::write INFO {DB $CFG($conn_name,failover,db): (failover): (shm) using cached rs}
			set rs $DB_DATA($CFG($conn_name,failover,db),$name,$qry_hash,$argkey,rs)

		# rs cached on the failover, but not seen by current request
		} elseif {!$force && \
				$CFG($conn_name,failover) && \
		        ![catch {set rs [asFindRs $CFG($conn_name,failover,db),$name,$qry_hash,$argkey]}]} {

			if {$reuse_cached_rs} {
				core::log::write INFO {DB $CFG($conn_name,failover,db): (failover): (shm) using shared memory cached rs}
				set DB_DATA($CFG($conn_name,failover,db),$name,$qry_hash,$argkey,rs) $rs
				lappend DB_DATA($CFG($conn_name,failover,db),rss) $CFG($conn_name,failover,db),$name,$qry_hash,$argkey,rs
			}

		# no cached rs available, or forced query
		} else {

			# Failover the connection if necessary
			set conn_name [core::db::_failover_connection $conn_name $name]

			# if we are running a delayed db (replicated) then we decrease the cache time
			# by the current repserver delay if that is set in shared memory, if we fall
			# too far behind we will initiate a failover for the query, this assumes that
			# the failover db is not replicated and that the full cache time can be applied
			set cache_time [_calculate_cache $conn_name $DB_DATA($conn_name,$name,cache_time)]

			set rs  [_run_qry $conn_name $name $arglist]
			set key $conn_name,$name,$qry_hash,$argkey

			_log_dist_cache_info $rs

			if {$rs != {} && [catch {
				asStoreRs \
					$rs \
					$key \
				    $cache_time
			} msg]} {
				core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
			}

			if {$reuse_cached_rs} {
				if {!$force || \
				    ($force && ![info exists DB_DATA($key,rs)])} {
					# Do not append multiple instances of the same rs if the forced
					# query is called multiple times within the same request
					lappend DB_DATA($conn_name,rss) $key,rs
				}
				set DB_DATA($key,rs) $rs
				lappend DB_DATA($conn_name,rss) $key,rs
			}

		}

	# not cached
	} else {
		set rs [_run_qry $conn_name $name $arglist]
	}

	return $rs
}


# Private procedure to execute a query where all of these are true:
#  - connection is configured to use shared memory
#  - connection is configured to use query protection semaphores
#  - connection is not configured to failover (hopefully implied by above)
#  - query has a cache time
#  - query is not being forced
#  - result set has not been seen on this request
#
# Used internally by _exec_qry_shm when appropriate - don't call directly.
#
# @param conn_name     Unique name which identifies the connection
# @param name          SQL query name
# @param qry_hash      md5 hash of the query string (for memcached purposes)
# @param arglist       Query arguments
# @param argkey        Query arguments in key form
# @param allow_expired Whether to allow use of expired result sets
#
# @return
#   The (shm cached) result set, or throws an error.
#   Caller is responsible for storing result in DB_DATA.
#
#
# Algorithm: (courtesy of Keith)
#
#   call asFindRs with -with-info and -alloc-sem switches
#   this gives us result set, status and semaphore to use
#   if status OK
#      use cached rs
#   else if PURGED (i.e. not found) or EXPIRED (and allow_expired = 0)
#      lock semaphore
#      call asFindRs again but with -with-info switch only
#      if status OK
#        use cached rs and unlock semaphore
#      else
#         run query, store rs and unlock semaphore
#   else if 80%/90% or EXPIRED (and allow_expired = 1)
#      lock semaphore only if not locked by someone else
#      if we managed to lock it
#        run query, store rs and unlock semaphore
#      else
#        return original rs
#
#
proc core::db::_exec_qry_sems { conn_name name qry_hash arglist argkey allow_expired } {

	variable DB_DATA
	variable CFG
	variable CONN

	set rs_key $conn_name,$name,$qry_hash,$argkey

	set sem_id $CFG(shared_qry_sems_id)

	set rs ""
	set sem_idx -1

	catch {
		set rs_info [asFindRs -expired -with-info -alloc-sem sem_idx -dist-status dist_status $rs_key]
		foreach {rs rs_status} $rs_info {break}
	}

	if {$rs != "" && $rs_status == "EXPIRED" && !$allow_expired} {
		set rs ""
	}


	# NB: there is the possiblity of a race condition occuring between
	# the asFindRs line above and the semaphore lock calls in two of
	# the branches below. Shouldn't matter (worst case is an unnecessary
	# query or shm re-check), but probably best to avoid doing any work
	# in between the two (e.g. logging).

	if {$rs != "" && $rs_status == "OK"} {
		# Normal cache hit.
		core::log::write DEBUG {DB $conn_name: (sems) using shared memory cached rs}
		return $rs
	} elseif {$sem_idx == -1} {
		# Not a normal cache hit and we can't use the semaphores.
		core::log::write WARNING {DB $conn_name: (sems) appserver failed to allocate sem_idx}
		set cache_time [_calculate_cache \
			$conn_name $DB_DATA($conn_name,$name,cache_time)]
		set rs [_run_qry $conn_name $name $arglist]

		_log_dist_cache_info $rs

		if {$rs != {} && \
			[catch {asStoreRs $rs $rs_key $cache_time} msg]} {
			core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
		}
		return $rs
	} elseif {$rs == ""} {
		# Complete cache miss (PURGED, or non-allowable EXPIRED).
		if {$CFG(get_status)} {
			set saved_status_str [asGetStatus]
			asSetStatus "qry_sem: $sem_idx ($rs_key)"
		}
		set t0 [OT_MicroTime -micro]

		# Always lock semaphore:
		ipc_sem_lock $sem_id $sem_idx
		if {$CFG(get_status)} {
			asSetStatus $saved_status_str
		}
		core::log::write DEBUG {DB $conn_name: (sems) $name locked ${sem_id}:${sem_idx} on PURGED}

		# We preserve the code from this catch and return or re-throw
		# accordingly after unlocking, so it's OK to return inside it:
		set result_code [catch {
			# This is where buggy appservers as mentioned in the
			# _detect_qry_sems_support procs cause problems - the
			# association between the key and the sem_idx is lost
			# on this asFindRs call even without the -alloc-sem.
			set rs ""
			catch {
				set rs_info [asFindRs -expired -with-info $rs_key]
				foreach {rs rs_status} $rs_info {break}
			}
			if {$rs != "" && $rs_status == "EXPIRED" && !$allow_expired} {
				set rs ""
			}
			if {$rs != "" && $rs_status == "OK"} {
				# someone else must have queried + stored while we were waiting for the lock
				core::log::write DEBUG {DB $conn_name: (sems) $name locked ${sem_id}:${sem_idx} on PURGED: \
					using shared memory cached rs (after recheck)}
				return $rs
			} else {
				set cache_time [_calculate_cache \
					$conn_name $DB_DATA($conn_name,$name,cache_time)]
				set rs [_run_qry $conn_name $name $arglist]

				if {$rs != {}} {

					set asStoreRs [list asStoreRs]

					# If we are using a distributed cache then check the dist_status
					if {$CFG(distrib_cache)} {
						if {$dist_status ne "UNLOCKED" } {
							# Do not push to memcache
							# Something else has locked this and will update memcache shortly
							# Prevents duplication of large memcache objects
							lappend asStoreRs -nodist
						} else {
							_log_dist_cache_info $rs
						}
					}

					if {[catch {
						{*}$asStoreRs $rs $rs_key $cache_time
					} msg] } {
						core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
					}
				}

				return $rs
			}
		} result_value options]
		core::log::write DEBUG {DB $conn_name: (sems) $name unlocking ${sem_id}:${sem_idx}}
		ipc_sem_unlock $sem_id $sem_idx
		_log_lock_time LOCK $conn_name "$name ${sem_id}:${sem_idx} on PURGED" $t0 [OT_MicroTime -micro]
		return -code $result_code -options $options $result_value
	} else {
		set t0 [OT_MicroTime -micro]
		# "Special" cache miss (80%, 90%, or allowable EXPIRED).
		# Lock semaphore only if not already locked.

		# If we are using a distributed cache then check the dist_status
		if {$CFG(distrib_cache)} {
			core::log::write DEBUG {DB $conn_name: (distrib_cache) $name dist_status = $dist_status}
			if {$rs != "" && ($dist_status == "NOT_CHECKED" || $dist_status == "LOCKED")} {
				# return the expired rs
				core::log::write DEBUG {DB $conn_name: (distrib_cache) $name using distrib cached rs ($dist_status)}
				return $rs
			}
		}

		set got_lock [ipc_sem_lock $sem_id $sem_idx -nowait]
		if {!$got_lock} {
			# Assume someone else did get the lock and is running the query.
			core::log::write DEBUG {DB $conn_name: (sems) using shared memory cached rs ($rs_status)}
			if {$CFG(extend_expired) && $DB_DATA($conn_name,$name,extend_expired) && $rs_status == "80PCT"} {
				# Store the existing result set again to extend the cache
				# time - presumably the holder of the lock has been running
				# his query for so long that even the stale one he stored
				# has now reached 80% of the cache time.
				set cache_time [_calculate_cache \
					$conn_name \
					$DB_DATA($conn_name,$name,cache_time)]

				_log_dist_cache_info $rs

				if {$rs != {} && \
						[catch {asStoreRs $rs $rs_key $cache_time} msg]} {
					core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
				}
				core::log::write INFO {DB $conn_name: (sems) $name refreshing extended cached rs}
			}
			return $rs
		} else {
			# We got the lock straight away; assume it's our job to run the query.
			core::log::write DEBUG {DB $conn_name: (sems) $name locked ${sem_id}:${sem_idx} on $rs_status}
			# We preserve the code from this catch and return or re-throw
			# accordingly after unlocking, so it's OK to return inside it:
			set result_code [catch {
				set cache_time [_calculate_cache \
					$conn_name \
					$DB_DATA($conn_name,$name,cache_time)]

				if {$CFG(extend_expired) && $DB_DATA($conn_name,$name,extend_expired)} {
					# Store the existing one result set to extend the cache time.

					_log_dist_cache_info $rs

					if {$rs != {} && \
						  [catch {asStoreRs $rs $rs_key $cache_time} msg]} {
						core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
					}
					core::log::write DEBUG {DB $conn_name: (sems) $name extending cached rs}
				}
				set rs [_run_qry $conn_name $name $arglist]

				_log_dist_cache_info $rs

				if {$rs != {} && \
				    [catch {asStoreRs $rs $rs_key $cache_time} msg]} {
					core::log::write WARNING {DB $conn_name: asStoreRs failed $rs $msg}
				}
				return $rs
			} result_value options]
			core::log::write DEBUG {DB $conn_name: (sems) $name unlocking ${sem_id}:${sem_idx}}
			ipc_sem_unlock $sem_id $sem_idx
			_log_lock_time LOCK $conn_name "$name ${sem_id}:${sem_idx} on $rs_status" $t0 [OT_MicroTime -micro]
			return -code $result_code -options $options $result_value
		}
	}

	error "unreachable reached"
}


# Private procedure to execute a query where the package has detected
# that shared memory capabilities (appserv) are not available.
# If the query is cached, then the result set will be added to an internal store
# (DB_DATA array).
# Please use core::db::exec_qry
#
#  @param conn_name  Unique name which identifies the connection
#  @param name       SQL query name
#  @param force      Run the query even if a suitable cached result set is
#     available (use with care)
#  @append_cache_key Append onto the cache key (cache buster)
#  @param arglist    Query arguments
#  @return           Query [cached] result set
#
proc core::db::_exec_qry_no_shm { conn_name name force append_cache_key arglist } {

	variable CFG
	variable DB_DATA

	if {$force} {
		core::log::write WARNING\
		    {DB $conn_name: exec forced -$name- with args: $arglist}
	} else {
		core::log::write DEV\
		    {DB $conn_name: _exec_qry_no_shm -$name- with args: $arglist}
	}

	set cache    $DB_DATA($conn_name,$name,cache_time)
	set argkey   [join $arglist ","]
	set qry_hash $DB_DATA($conn_name,$name,qry_hash)
	set now      [clock seconds]

	# Append onto the arglist to be the cache buster if passed
	if {$append_cache_key != {}} {
		append argkey $append_cache_key
	}

	# disable caching if a forced query
	if {$force} {
		set cache 0
	}

	# cached rs?
	if {$cache && [info exists DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)]} {

		set valid_time $DB_DATA($conn_name,$name,rs_valid)
		set exec_time  $DB_DATA($conn_name,$name,$qry_hash,$argkey,time)

		# can we use the cached rs?
		if {$exec_time >= $valid_time && [expr {$exec_time + $cache}] >= $now} {

			core::log::write DEBUG {DB $conn_name: (no shm) using cached rs}
			return $DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)
		}

	# Perhaps we have one against the failover db
	} elseif {$cache && $CFG($conn_name,failover) != 0 && \
				[info exists DB_DATA($CFG(conn_name,failover,db),$name,$qry_hash,$argkey,rs)]} {

		set valid_time $DB_DATA($CFG(conn_name,failover,db),$name,rs_valid)
		set exec_time  $DB_DATA($CFG(conn_name,failover,db),$name,$qry_hash,$argkey,time)

		# can we use the cached rs?
		if {$exec_time >= $valid_time && [expr {$exec_time + $cache}] >= $now} {

			core::log::write DEBUG {DB $CFG(conn_name,failover,db) (failover): (no shm) using cached rs}
			return $DB_DATA($CFG($conn_name,failover,db),$name,$qry_hash,$argkey,rs)
		}
	}

	# Failover checks
	set conn_name [core::db::_failover_connection $conn_name $name]

	# Offset the cache time by any delay on the database
	set cache [_calculate_cache $conn_name $cache]

	# no/expired cache
	set rs [_run_qry $conn_name $name $arglist]

	# store rs in a cache?
	if {$cache && $rs != ""} {

		# purge any existing cached rs
		if {[info exists DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)]} {
			_purge_rs $conn_name
		}

		set now [clock seconds]
		core::log::write DEBUG {DB $conn_name: storing $rs in cache}

		# store rs within the cache
		set DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)   $rs
		set DB_DATA($conn_name,$name,$qry_hash,$argkey,time) $now

		# store the reverse lookup key
		set DB_DATA($conn_name,rs,$rs,argkey)   $argkey
		set DB_DATA($conn_name,rs,$rs,qry_name) $name
		set DB_DATA($conn_name,rs,$rs,qry_hash) $qry_hash

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
# Please use core::db::exec_qry
#
#  @param conn_name Unique name which identifies the connection
#  @param name      SQL query name
#  @param vals      Query arguments
#  @return          Result set
#
proc core::db::_run_qry { conn_name name vals } {

	variable CFG
	variable DB_DATA

	# prepare the query?
	if {![info exists DB_DATA($conn_name,$name,stmt)]
		|| [info exists DB_DATA($conn_name,$name,stmt_invalid)]} {

		core::log::write WARNING {DB $conn_name: preparing $name on demand}
		_new_prep_qry $conn_name $name
	}

	set now [clock seconds]

	# get the status string if supported
	if {$CFG(get_status)} {
		set status_str [asGetStatus]
	} else {
		set status_str ""
	}

	# set the status string if supported
	if {$CFG(set_status)} {
		asSetStatus "db: [clock format $now -format "%T"] - $name"
	}

	# execute statement
	if {[catch {set rs [_exec_stmt $conn_name $name $vals]} msg]} {
		if {$CFG(set_status)} {
			asSetStatus $status_str
		}
		error $msg
	}

	# set the status string if supported
	if {$CFG(set_status)} {
		asSetStatus $status_str
	}

	return $rs
}



# Private procedure to calculate the cache time for a query. If we are running
# a delayed/replicated DB, then we decrease the cache time by the current
# replication server delay if its set in SHM. If replication falls too far
# behind, then failover to a different connection, presuming the failover DB
# is not replicated and we can use the full cache time.
#
# @param  conn_name Unique name which identifies the connection
# @param  cache     Time to cache a query result set in SHM
#
proc core::db::_calculate_cache {conn_name cache} {
	variable CFG
	if {$CFG($conn_name,delayed) && $CFG($conn_name,reduce_cache)} {
		set delay [core::db::failover::get_conn_delay -conn_name $conn_name]
		return [expr {$cache > $delay ? $cache - $delay : 1}]
	} else {
		return $cache
	}
}

# Given an adhoc query (one with named #### args in the sql):
#    prepare the sql and execute it with the named args (using the params arg).
#
# @param -conn_name The name of the connection to use.
# @param -name The name (as registered in register_adhoc_query).
# @param -query The SQL with named arg placeholders.
# @param -params Values for the named args.
# @param -ident An (optional) identifier for this version of the query.
# @param -return_extended : if 0, then return simply the rs.
#   However if 1, then return a list of named-values with
#     the result set (rs), the serial id inserted (serial) and the number of
#     rows affected (nrows).
#
core::args::register \
	-proc_name core::db::run_adhoc_query \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(opt,serial_type) \
		[list -arg -query           -mand 1 -check ANY                -desc {The SQL with named arg placeholders}] \
		[list -arg -params          -mand 0 -check ANY    -default {} -desc {Values for the named args}] \
		[list -arg -ident           -mand 0 -check ASCII  -default {} -desc {Ident An (optional) identifier for this version of the query}] \
		[list -arg -return_extended -mand 0 -check BOOL   -default 0  -desc {Return information about the executed query}] \
		[list -arg -mask_qry_params -mand 0 -check BOOL   -default 0  -desc {Mask the query params when logging}] \
	] \
	-body {
		global DB
		variable DB_DATA
		variable CONN
		variable CFG

		set name            $ARGS(-name)
		set conn_name       $ARGS(-conn_name)
		set query           $ARGS(-query)
		set params          $ARGS(-params)
		set ident           $ARGS(-ident)
		set return_extended $ARGS(-return_extended)
		set mask_qry_params $ARGS(-mask_qry_params)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		array set PARAMS $params

		if {[lsearch $CFG($conn_name,adhoc_query_names) $name] == -1} {
			error "Adhoc Query '$name' hasn't been registered."
		}

		set qry_name "ADHOC-${name}-${ident}"

		# Given an 'adhoc' query, we need to remove all the ##name## elements and
		# replace them with '?' strings, *and* keep a list of the all the new ##name##'s
		set ret          [_parse_adhoc $query]
		set sql_to_prep  [lindex $ret 0]
		set names        [lindex $ret 1]

		core::log::write DEV {SQL for $qry_name =\n$sql_to_prep}

		if {[catch {
			set stmt [$CFG($conn_name,namespace)::prep_sql \
				-conn_name $CONN($conn_name) \
				-qry       $sql_to_prep]
		} msg]} {
			core::log::write ERROR {ERROR $msg}
			core::db::failover::handle_error \
				-conn_name $conn_name \
				-package   $CFG($conn_name,package) \
				-attempt   0 \
				-msg       $msg

			error $msg $::errorInfo $::errorCode
		}

		set values [list]
		foreach ph_name $names {
			lappend values $PARAMS($ph_name)
		}

		set DB_DATA($conn_name,$qry_name,stmt)            $stmt
		set DB_DATA($conn_name,$qry_name,qry_string)      $sql_to_prep
		set DB_DATA($conn_name,$qry_name,mask_qry_params) $mask_qry_params

		set was_error 0
		set msg ""

		if {[catch {
			set rs [_exec_stmt $conn_name $qry_name $values 0]
		} msg]} {
			set was_error 1
		}

		# Read these before we close the stmt! But if there was an error when
		# executing the statement, then we don't need the values. Also, if there
		# was an error, then the inf_get... $stmt calls will probably error too.
		#
		if {!$was_error} {
			set serial [$CFG($conn_name,namespace)::get_serial \
				-conn_name   $CONN($conn_name) \
				-stmt        $stmt \
				-serial_type $ARGS(-serial_type)]

			set nrows  [$CFG($conn_name,namespace)::get_row_count \
				-conn_name $CONN($conn_name) \
				-stmt      $stmt]
		}

		# This is a one time use query. So we shouldn't re-use the statement.
		#
		$CFG($conn_name,namespace)::close_stmt \
			-conn_name $CONN($conn_name) \
			-stmt      $stmt

		unset DB_DATA($conn_name,$qry_name,stmt)
		unset DB_DATA($conn_name,$qry_name,qry_string)

		if {$was_error} {
			error $msg $::errorInfo $::errorCode
		}

		if {$return_extended} {
			return [list rs $rs serial $serial nrows $nrows]
		} else {
			return $rs
		}
	}



# The idea is to take an adhoc query (i.e. with named #### elements) and
#   1. Replace the #### elements with placeholders to get sql that can be
#      prepared.
#   2. Return a list of all the named #### elements.
#
proc core::db::_parse_adhoc { raw_sql } {

	# It's actually much simpler to split by '#' than '##'.
	set str [string map [list "##" "#"] $raw_sql]

	set prep_sql ""
	set arg_names [list]

	set buffer ""
	set in_arg_name 0
	set last [expr {[string length $str] - 1}]

	for {set i 0} {$i < [string length $str]} {incr i} {

		set c [string index $str $i]

		if {$c == "#" || $i == $last} {
			if {$in_arg_name} {
				lappend arg_names $buffer
				append prep_sql {?}
			} else {
				if {$i == $last} {
					append buffer $c
				}
				append prep_sql $buffer
			}

			set buffer ""
			set in_arg_name [expr {!$in_arg_name}]
		} else {
			append buffer $c
		}
	}

	return [list $prep_sql $arg_names]
}



# Private procedure to pick a connection to use
#
# @param conn_name  Unique name which identifies the connection
# @param name       Named query
#
proc core::db::_failover_connection {conn_name {name ""}} {

	variable CFG
	variable DB_DATA

	if {!$CFG($conn_name,failover)} {
		return $conn_name
	}

	set failover 0

	# Is the database available
	if {![core::db::failover::check_conn_status -conn_name $conn_name]} {
		core::log::write ERROR {DB $conn_name (failover): bad db connection status}
		set failover 1
	}

	if {!$failover && $name != "" && $CFG($conn_name,delayed)} {
		set delay [core::db::failover::get_conn_delay -conn_name $conn_name]

		# Failover if greater than max delay
		if {$delay > $CFG($conn_name,failover,max_delay)} {
			core::log::write ERROR {DB $conn_name (failover): excessive delay on database: $delay}
			set failover 1

		# Failover if specific query would not have a large enough cache time
		} elseif { [expr {$DB_DATA($conn_name,$name,cache_time) - $delay}] < $CFG($conn_name,failover,min_cache)} {
			core::log::write ERROR {DB $conn_name (failover): remaining cache too small with delay $delay for $name}
			set failover 1
		}
	}

	# If we are failing over try to prep the query
	if {$failover && $name != ""} {
		if {![core::db::check_qry -name $name -conn_name $CFG($conn_name,failover,db)]} {
			_new_prep_qry $CFG($conn_name,failover,db) $name
		}
	}

	if {$failover} {
		core::log::write ERROR {DB $conn_name (failover): failing over to $CFG($conn_name,failover,db) for $name}
		set conn_name $CFG($conn_name,failover,db)
	}
	return $conn_name
}




# Private procedure to execute the statement.
# Please use core::db::exec_qry
#
# @param conn_name  Unique name which identifies the connection
# @param name       Named query
# @param vals       Query arguments
# @param in_reprep  Flag to denote if the procedure has been called recursively
#     (default: 0)
# @return           Result set
#
proc core::db::_exec_stmt { conn_name name vals {in_reprep 0} } {

	variable DB_DATA
	variable CONN
	variable CFG
	variable IN_TRAN


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
	set conn_name [core::db::_failover_connection $conn_name $name]

	if {$CFG($conn_name,log_qry_params)} {
		if {$DB_DATA($conn_name,$name,mask_qry_params)} {
			set num_vals [llength $vals]
			core::log::write INFO {DB $conn_name: executing -$name- with args: *$num_vals arg(s) masked*}
		} else {
			core::log::write INFO {DB $conn_name: executing -$name- with args: $vals}
		}
	}

	# TODO: SKY -> configurable logging of query string

	# logging query time?
	set t0 [OT_MicroTime -micro]

	set IN_TRAN($conn_name,careful) 1

	if {[catch {set rs [eval [list $CFG($conn_name,namespace)::exec_stmt \
		-conn_name $CONN($conn_name) \
		-inc_type  $inc_type \
		-stmt      $DB_DATA($conn_name,$name,stmt)]\
		-args      [list $qry_args]] \
	} msg]} {
		set err_code [core::db::failover::handle_error \
			-conn_name $conn_name \
			-package   $CFG($conn_name,package) \
			-attempt   $in_reprep \
			-msg       $msg]

		switch -- $err_code {

			REPREP {
				if {![info exists IN_TRAN($conn_name)]} {
					_new_prep_qry $conn_name $name
					return [_exec_stmt $conn_name $name $vals 1]
				} else {
					_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
					core::db::restart -conn_name $conn_name
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
					core::log::write_qry CRITICAL "DB $conn_name" $msg $DB_DATA($conn_name,$name,qry_string)
				}
				_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
				core::db::restart -conn_name $conn_name
				error $msg $::errorInfo $::errorCode
			}

			LOG {
				# no action, but log the query to make debugging easier
				if {$CFG($conn_name,log_on_error) == 1} {
					core::log::write_qry CRITICAL "DB $conn_name" $msg \
						$DB_DATA($conn_name,$name,qry_string)
				}
				_log_qry_time EXEC $conn_name $name $vals $t0 \
					[OT_MicroTime -micro]
				error $msg $::errorInfo $::errorCode
			}

			NOOP    -
			default {
				_try_handle_err $conn_name
				_log_qry_time EXEC $conn_name $name $vals $t0 [OT_MicroTime -micro]
				error $msg $::errorInfo $::errorCode
			}
		}
	}

	# Record the connection against the result set
	if {$rs != "" && !$CFG(shm_cache)} {
		set DB_DATA($rs,connection)              $conn_name
	}

	_log_qry_time \
		EXEC \
		$conn_name \
		$name \
		$vals \
		$t0 \
		[OT_MicroTime -micro] \
		[garc -name $name -conn_name $conn_name]

	_log_buf_reads $conn_name $name

	return $rs
}

# Log buffer read statistics
proc core::db::_log_buf_reads {conn_name name} {

	variable CONN
	variable CFG
	variable BUFREADS

	if {$CFG($conn_name,log_bufreads) == 1} {
		set buf_reads [$CFG($conn_name,namespace)::buf_reads -conn_name $CONN($conn_name)]
		set delta     [expr {$buf_reads - $BUFREADS($conn_name,buf_reads)}]

		core::log::write INFO {DB::BUFREADS $conn_name: $name $delta}
		set BUFREADS($conn_name,buf_reads) $buf_reads
	}
}



# Attempt to log the query time, and warn of any long queries
#
# @param conn_name Connection name
# @param name      Query name
# @param vals      Argument to the query
# @param t0        Query start time
# @param t1        Query end time
# @param garc      Number of rows affected
#
proc core::db::_log_qry_time {prefix conn_name name vals t0 t1 {garc ""}} {

	variable CONN
	variable DB_DATA
	variable CFG

	set tt [expr {$t1 - $t0}]
	set ft [format {%0.4f} $tt]

	# log the query which exceeds CFG(log_longq)
	if {$tt > $CFG($conn_name,log_longq)} {
		core::log::write_qry INFO \
			"DB::LONGQ" \
			"$name $ft rowcount = [garc -name $name -conn_name $conn_name]" \
			$DB_DATA($conn_name,$name,qry_string) \
			$vals

		# log the explain plan
		if {$CFG($conn_name,log_explain) == 1} {
			$CFG($conn_name,namespace)::explain \
				-conn_name $CONN($conn_name) \
				-name      $name \
				-qry       $DB_DATA($conn_name,$name,qry_string) \
				-args      $vals
		}
	}

	set garc_str ""
	if {$CFG($conn_name,log_qry_nrows)} {
		set garc_str "garc:$garc"
	}

	if {$CFG($conn_name,log_qry_time)} {
		core::log::write INFO {DB::$prefix ${conn_name} $name $ft $garc_str}
	}
}


# Attempt to log the elapsed semaphore lock time.
#
# @param conn_name Connection name
# @param name      Query name
# @param t0        Lock start time
# @param t1        Lock end time
#
proc core::db::_log_lock_time {prefix conn_name name t0 t1} {

	variable CFG

	set tt [expr {$t1 - $t0}]
	set ft [format {%0.4f} $tt]

	if {$CFG($conn_name,log_lock_time)} {
		core::log::write INFO {DB::$prefix ${conn_name} $name $ft}
	}
}

core::args::register \
	-proc_name core::db::foreachrow \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(name) \
		[list -arg -tcl             -mand 1 -check ANY                -desc {TCL script to execute}] \
		[list -arg -fetch           -mand 0 -check BOOL   -default 0  -desc {Use fetch cursor}] \
		[list -arg -is_reprep       -mand 0 -check BOOL   -default 0  -desc {The attempt number for failover handling}] \
		[list -arg -inc_type        -mand 0 -check BOOL   -default 0  -desc {Handle blobs}] \
		[list -arg -force           -mand 0 -check BOOL   -default 0  -desc {Force the setting of variables in the calling namespace}] \
		[list -arg -var_prefix      -mand 0 -check ASCII  -default {} -desc {Prefix variables in calling scope}] \
		[list -arg -colnamesvar     -mand 0 -check ASCII  -default {} -desc {Set colname variable in calling scope}] \
		[list -arg -nrowsvar        -mand 0 -check ASCII  -default {} -desc {Set nrows variable in calling scope}] \
		[list -arg -rowvar          -mand 0 -check ASCII  -default {} -desc {Set row variable in calling scope}] \
		[list -arg -array_name      -mand 0 -check ASCII  -default {} -desc {Populate the array in the calling namespace}] \
		[list -arg -args            -mand 0 -check ANY    -default {} -desc {Optional arguments to pass to exec_stmt}] \
	]
# Execute a query using each row methodology.
# See db-admin.tcl for detailed arguments.
#
# foreachrow ?-fetch? ?-force? ?-colnamesvar colnames? ?-rowvar r?
#   ?-nrowsvar nrows? ?-connection qry ?arg...? tcl
#
proc core::db::foreachrow {args} {

	global DB

	variable CFG
	variable CONN
	variable DB_DATA
	variable IN_TRAN

	array set ARGS [core::args::check core::db::foreachrow {*}$args]

	set caught      0
	set msg         ""
	set conn_name   $ARGS(-conn_name)
	set name        $ARGS(-name)
	set tcl         $ARGS(-tcl)
	set fetch       $ARGS(-fetch)
	set is_reprep   $ARGS(-is_reprep)
	set inc_type    $ARGS(-inc_type)
	set force       $ARGS(-force)
	set var_prefix  $ARGS(-var_prefix)
	set colnamesvar $ARGS(-colnamesvar)
	set nrowsvar    $ARGS(-nrowsvar)
	set rowvar      $ARGS(-rowvar)
	set array_name  $ARGS(-array_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {$array_name != {}} {
		core::log::write INFO {Populating $array_name array}
	}

	# Validate connection for this query
	if {[lsearch $DB_DATA($name,connections) $conn_name] == -1} {
		error "no prepared statement found for query '$name' on connection $conn_name (check store_qry executed)"
	}

	# Failover connection if necessary
	set conn_name [core::db::_failover_connection $conn_name $name]

	# check the query exists
	if {![info exists DB_DATA($conn_name,$name,qry_string)]} {
		error "Query not found"
	}

	if {$array_name != {}} {
		upvar 1 $array_name RS
	}

	if {$colnamesvar != {}} {
		upvar 1 $colnamesvar colnames
	}

	if {$nrowsvar != {}} {
		upvar 1 $nrowsvar nrows
	}

	if {$rowvar != {}} {
		upvar 1 $rowvar row
	}

	# fetch version
	if {$fetch && $CFG($conn_name,use_fetch)} {

		core::log::write DEV {DB: foreachrow fetching $name $ARGS(-args)}

		if {![info exists DB_DATA($conn_name,$name,stmt)]
			|| [info exists DB_DATA($conn_name,$name,stmt_invalid)]} {

			core::log::write WARNING {DB $conn_name: preparing $name on demand}
			_new_prep_qry $conn_name $name
		}

		set stmt $DB_DATA($conn_name,$name,stmt)

		set t0 [OT_MicroTime -micro]

		if {[catch {
			set colnames [eval {$CFG($conn_name,namespace)::exec_stmt_for_fetch \
				-conn_name $CONN($conn_name)\
				-inc_type  $inc_type \
				-stmt      $stmt}\
				-args      [list $ARGS(-args)]]
		} msg]} {
			set err_code [core::db::failover::handle_error \
				-conn_name $conn_name \
				-package   $CFG($conn_name,package) \
				-attempt   $is_reprep \
				-msg       $msg]

			switch -- $err_code {
				REPREP {
					# we shouldn't be in a transaction if we are doing
					# a fetch at all, but just in case we follow the exact
					# some procedure as if we have done and exec_stmt
					if {[info exists IN_TRAN($conn_name)]} {
						_new_prep_qry $conn_name $name
						return [uplevel 1 {core::db::foreachrow -is_reprep 1 {*}$args}]
					} else {
						error $msg $::errorInfo $::errorCode
					}
				}

				RECONN {
					_connect $conn_name
					_new_prep_qry $conn_name $name
					return [uplevel 1 {core::db::foreachrow -is_reprep 1 {*}$args}]
				}

				RESTART {
					core::db::restart -conn_name $conn_name
					error $msg $::errorInfo $::errorCode
				}

				LOG  -
				NOOP -
				default {
					_try_handle_err $conn_name
					error $msg $::errorInfo $::errorCode
				}
			}
		}

		# this may be an underestimate, the database may still be doing the
		# query while we are doing work this side
		_log_qry_time FOREACHROW $conn_name $name $ARGS(-args) $t0 [OT_MicroTime -micro]

		# check that the variables do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists ${var_prefix}$n]]} {
					$CFG($conn_name,namespace)::fetch_done \
						-conn_name $CONN($conn_name) \
						-stmt      $stmt

					$CFG($conn_name,namespace)::close_stmt \
						-conn_name $CONN($conn_name) \
						-stmt      $stmt

					error "Variable ${var_prefix}$n already exists in calling scope"
				}
			}
		}

		set row 0
		while {[set colvalues [inf_fetch $stmt]] != ""} {

			if {$array_name != {}} {
				foreach n $colnames v $colvalues {
					set RS($n) $v
				}
			}

			# set the column variables
			foreach n $colnames v $colvalues {
				uplevel 1 [list set ${var_prefix}$n $v]
			}

			set caught [catch {uplevel 1 $tcl} msg]

			# error, return, break
			if {[lsearch {1 2 3} $caught] >= 0} {
				break
			}

			# unset the column variables
			if {!$force} {
				foreach n $colnames {
					uplevel 1 [list unset ${var_prefix}$n]
				}
			}

			incr row
		}

		set nrows $row

		unset row

		# clean up
		$CFG($conn_name,namespace)::fetch_done \
			-conn_name $CONN($conn_name) \
			-stmt      $stmt

		core::log::write DEV {DB: $nrows rows fetched}

	} else {
		set rs [exec_qry \
			-connections [list $conn_name] \
			-name        $name \
			-force       0 \
			-args        $ARGS(-args)]

		set nrows    [db_get_nrows $rs]
		set colnames [db_get_colnames $rs]

		# check that the variable do not exist in the calling scope
		if {!$force} {
			foreach n $colnames {
				if {[uplevel 1 [list info exists ${var_prefix}$n]]} {
					rs_close -conn_name $conn_name -rs $rs

					error "Variable ${var_prefix}$n already exists in calling scope"
				}
			}
		}

		for {set row 0} {$row < $nrows} {incr row} {

			if {$array_name != {}} {
				foreach n $colnames {
					set RS($n) [db_get_col $rs $row $n]
				}
			}

			# set the column variables
			foreach n $colnames {
				uplevel 1 [list set ${var_prefix}$n [db_get_col $rs $row $n]]
			}

			set caught [catch {uplevel 1 $tcl} msg]

			# error, return, break
			if {[lsearch {1 2 3} $caught] >= 0} {
				break
			}

			# unset the column variables
			if {!$force} {
				foreach n $colnames {
					uplevel 1 [list unset ${var_prefix}$n]
				}
			}
		}

		if {[info exists row]} {
			unset row
		}

		# clean up
		rs_close -conn_name $conn_name -rs $rs
	}

	# there are 'exceptional' returns, and is effective in the calling scope
	# see PP in TCL and TK, 3rd edition, Chapter 6, Page 80
	switch -- $caught {
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
# @param conn_name Connection Name
#
proc core::db::_try_handle_err { conn_name } {
	variable CFG

	if {[info exists CFG($conn_name,log_err)]} {
		if {[lsearch $CFG($conn_name,log_err) [get_err_code -conn_name $conn_name]] >= 0} {
			core::log::write_ts
		}
	} else {
		# Some applications do not define db error handling
		# in which case do not call write_ts
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
# When calling this procedure, make sure that either core::db::commit_tran
# or core::db::rollback_tran is called.
#
# @param -conn_name Unique name which identifies the connection
# @param -tran_name Unique name for the transaction
#
core::args::register \
	-proc_name core::db::begin_tran \
	-args [list \
		[list -arg -conn_name -mand 0 -check ASCII -default {} -desc {Database connection name}] \
		[list -arg -tran_name -mand 0 -check ASCII -default {} -desc {Symbolic transaction name}] \
	] \
	-body {
		variable CFG
		variable CONN
		variable IN_TRAN
		variable TRAN_START
		variable DB_DATA

		set conn_name $ARGS(-conn_name)
		set tran_name $ARGS(-tran_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		# begin transaction
		# - on connection error, re-connect and re-attempt transaction start
		core::log::write WARNING {DB::TRANS ($conn_name) beginning transaction }

		if {[catch {$CFG($conn_name,namespace)::begin_tran -conn_name $CONN($conn_name)} msg]} {

			set err_code [core::db::failover::handle_error \
				-conn_name $conn_name \
				-package   $CFG($conn_name,package) \
				-attempt   0 \
				-msg       $msg]

			switch -- $err_code {
				RECONN {
					_connect $conn_name
					$CFG($conn_name,namespace)::begin_tran -conn_name $CONN($conn_name)
				}
				LOG -
				NOOP {
					error $msg $::errorInfo $::errorCode
				}
				REPREP -
				RESTART {
					core::db::restart -conn_name $conn_name
					error $msg $::errorInfo $::errorCode
				}
			}
		}

		# log execution time
		if {$CFG($conn_name,log_qry_time)} {
			set TRAN_START($conn_name) [OT_MicroTime -micro]
		}
		set TRAN_START($conn_name,tran_name) $tran_name

		set IN_TRAN($conn_name) 1
	}

# Commit a transaction.
# core::db::begin_tran must have been called to allow a transaction to be
# committed. Make sure commit_tran is called if the transaction is wanted,
# else call core::db::rollback_tran.
#
# @param -conn_name Unique name which identifies the connection
#
core::args::register \
	-proc_name core::db::commit_tran \
	-args [list \
		[list -arg -conn_name -mand 0 -check ASCII -default {} -desc {Database connection name}] \
	] \
	-body {
		variable CFG
		variable CONN
		variable IN_TRAN
		variable TRAN_START
		variable DB_DATA

		set conn_name $ARGS(-conn_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		core::log::write WARNING {DB::TRANS ($conn_name) committing transaction }
		if {[catch {$CFG($conn_name,namespace)::commit_tran -conn_name $CONN($conn_name)} msg]} {
			error $msg $::errorInfo $::errorCode
		}

		unset IN_TRAN($conn_name)

		if {$CFG($conn_name,log_qry_time)} {
			set tt [expr {[OT_MicroTime -micro] - $TRAN_START($conn_name)}]
			set ft [format %0.4f $tt]
			core::log::write WARNING {DB::EXEC ($conn_name) commit $TRAN_START($conn_name,tran_name) $ft}
		}
	}

# Rollback a transaction.
# core::db::begin_tran must have been called to allow a transaction to be
# rolled back. Make sure that rollback_tran is called if the transaction
# is not wanted, else call core::db::commit_tran
#
# @param -conn_name  Unique name which identifies the connection
#
core::args::register \
	-proc_name core::db::rollback_tran \
	-args [list \
		[list -arg -conn_name -mand 0 -check ASCII -default {} -desc {Database connection name}] \
	] \
	-body {
		variable CFG
		variable CONN
		variable IN_TRAN
		variable TRAN_START
		variable DB_DATA

		set conn_name $ARGS(-conn_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		# rollback transaction
		if {[catch {$CFG($conn_name,namespace)::rollback_tran -conn_name $CONN($conn_name)} msg]} {
			error $msg $::errorInfo $::errorCode
		}

		core::log::write WARNING {DB::TRANS ($conn_name) rollback transaction}

		unset IN_TRAN($conn_name)

		# log execution time
		if {$CFG($conn_name,log_qry_time)} {
			set tt [expr {[OT_MicroTime -micro] - $TRAN_START($conn_name)}]
			set ft [format %0.4f $tt]
			core::log::write WARNING {DB::EXEC ($conn_name) rollback $TRAN_START($conn_name,tran_name) $ft}
		}
	}

# Are we in a transaction?
core::args::register \
	-proc_name core::db::in_tran \
	-args [list \
		[list -arg -conn_name -mand 0 -check ASCII -default {} -desc {Database connection name}] \
	] \
	-body {
		variable IN_TRAN
		variable DB_DATA

		set conn_name $ARGS(-conn_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		if {[info exists IN_TRAN($conn_name)]} {
			return 1
		}

		return 0
	}

#--------------------------------------------------------------------------
# Request
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::db::req_end \
	-args [list]

# Denote an appserv request has ended on *all* connections.
# This procedure MUST be called at the end of every request. Performs important
# cleanup of the result set cache.
# Attempts to rollback a transaction, if this succeeds, the procedure will
# raise an error.

proc core::db::req_end args {

	variable CFG
	variable CONN
	variable DB_DATA
	variable IN_TRAN

	foreach conn_name [array names CONN] {

		if {[info exists IN_TRAN($conn_name,careful)] || \
			[info exists IN_TRAN($conn_name)]} {

			# rollback
			if {![catch {rollback_tran -conn_name $conn_name}]} {
				core::log::write ERROR\
				    {DB $conn_name: ERROR ============================}
				core::log::write ERROR\
				    {DB $conn_name: ERROR rollback succeeded in req_end}
				core::log::write ERROR\
				    {DB $conn_name: ERROR ============================}
			}
			if {[info exists IN_TRAN($conn_name,careful)]} {
				unset IN_TRAN($conn_name,careful)
			}
		}

		# purge cached result sets
		if {$CFG(shm_cache)} {
			core::log::write DEV\
			    {DB $conn_name: deleting rss $DB_DATA($conn_name,rss)}
			foreach key $DB_DATA($conn_name,rss) {
				catch {unset DB_DATA($key)}
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

core::args::register \
	-proc_name core::db::rs_close \
	-args [list \
		$::core::db::CORE_DEF(rs) \
		$::core::db::CORE_DEF(conn_name) \
	]

# Close an un-cached result set.
#
# @param -conn_name  Unique name which identifies the connection
#    if omitted will be applied to connection of the rs
# @param -rs  Result set to close
#
proc core::db::rs_close args {

	variable CFG
	variable DB_DATA
	variable CONN

	# ignore if using shared memory
	if {$CFG(shm_cache)} {
		return
	}

	array set ARGS [core::args::check core::db::rs_close {*}$args]

	set rs        $ARGS(-rs)
	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	# Validate connection for this query
	if {[lsearch $DB_DATA(connections) $conn_name] == -1} {
		core::log::write ERROR {DB : unable to find rs connection $rs for connection $conn_name}
		return
	}

	# close non-cached result set
	if {![info exists DB_DATA($conn_name,rs,$rs,qry_name)]} {

		core::log::write DEV {DB $conn_name: closing un-cached rs $rs}
		if {[catch {$CFG($conn_name,namespace)::rs_close -conn_name $CONN($conn_name) -rs $rs} msg]} {
			core::log::write WARNING\
			    {DB $conn_name: rs_close, unable to close $rs $msg}
		}

		catch {unset DB_DATA($rs,connection)}

	} else {
		core::log::write DEV\
		    {DB $conn_name: rs $rs is cached, ignoring close request}
	}
}

core::args::register \
	-proc_name core::db::garc \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(conn_name) \
	]

# Get the number of rows affected by the last statement
#
# @param -conn_name  Unique name which identifies the connection
# @param -name  Named SQL query
# @return Number of rows affected by the last statement
#
proc core::db::garc args {

	variable DB_DATA
	variable CONN
	variable CFG

	array set ARGS [core::args::check core::db::garc {*}$args]

	set name      $ARGS(-name)
	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	# Validate connection name
	if {[lsearch $DB_DATA(connections) $conn_name] == -1} {
		error "no connection $conn_name found for query $name"
	}

	set garc [$CFG($conn_name,namespace)::get_row_count \
		-conn_name $CONN($conn_name) \
		-stmt      $DB_DATA($conn_name,$name,stmt)]

	return $garc
}

# Get serial number created by the last insert
#
# @param -conn_name Unique name which identifies the connection
# @param -name       - stored query name
#   returns    - serial number (maybe an empty string if no serial
#                number was associated with the last insert)
#
core::args::register \
	-proc_name core::db::get_serial_number \
	-args [list \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(opt,serial_type) \
	] \
	-body {
		variable DB_DATA
		variable CONN
		variable CFG

		set name      $ARGS(-name)
		set conn_name $ARGS(-conn_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		# Validate Connection
		if {[lsearch $DB_DATA($name,connections) $conn_name] == -1} {
			error "no prepared statement found for query '$name' on connection $conn_name (check store_qry executed)"
		}

		if {[catch {set serial [$CFG($conn_name,namespace)::get_serial \
			-conn_name   $CONN($conn_name) \
			-stmt        $DB_DATA($conn_name,$name,stmt) \
			-serial_type $ARGS(-serial_type)] \
		} msg]} {
			core::log::write ERROR {DB - $msg}
			error $msg $::errorInfo $::errorCode
		}

		return $serial
	}

# Retrieve the database session id
core::args::register \
	-proc_name core::db::get_sessionid \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-body {
		variable DB_DATA
		variable CFG
		variable CONN
		variable DB_DATA

		set conn_name $ARGS(-conn_name)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		return [$CFG($conn_name,namespace)::get_sessionid -conn_name $CONN($conn_name)]
	}

# Private procedure to purge any expired result sets.
#
# @param conn_name  Unique name which identifies the connection
#
proc core::db::_purge_rs { conn_name } {

	variable CFG
	variable DB_DATA
	variable CONN

	core::log::write DEV {DB $conn_name: purge expired result sets}

	set now [clock seconds]

	# clean up any expired rs
	set rs_exp  $DB_DATA($conn_name,rs_exp)
	set rs_list $DB_DATA($conn_name,rs_list)

	set purge_count 0

	foreach rs $rs_list exp $rs_exp {

		if { $now <= $exp } {
			break
		}

		set name     $DB_DATA($conn_name,rs,$rs,qry_name)
		set qry_hash $DB_DATA($conn_name,rs,$rs,qry_hash)
		set argkey   $DB_DATA($conn_name,rs,$rs,argkey)

		core::log::write DEV\
		    {DB $conn_name: purging $rs from cache, qry $name, hash $qry_hash, args $argkey}

		if {[catch {$CFG($conn_name,namespace)::rs_close -conn_name $CONN($conn_name) -rs $rs} msg]} {
			core::log::write WARNING\
			    {DB $conn_name: _purge_rs, unable to close $rs $msg}
		}

		catch {unset DB_DATA($rs,connection)}
		catch {unset DB_DATA($conn_name,$name,$qry_hash,$argkey,rs)}
		catch {unset DB_DATA($conn_name,$name,$qry_hash,$argkey,time)}
		catch {unset DB_DATA($conn_name,rs,$rs,qry_name)}
		catch {unset DB_DATA($conn_name,rs,$rs,qry_hash)}
		catch {unset DB_DATA($conn_name,rs,$rs,argkey)}

		incr purge_count
	}

	set DB_DATA($conn_name,rs_exp)  [lrange $rs_exp  $purge_count end]
	set DB_DATA($conn_name,rs_list) [lrange $rs_list $purge_count end]

	core::log::write DEV {DB $conn_name: purged $purge_count items successfully}
}



#--------------------------------------------------------------------------
# PDQ
#--------------------------------------------------------------------------
core::args::register \
	-proc_name core::db::push_pdq \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -pdq       -mand 1 -check ASCII -desc {PDQ priority}] \
	]

# Set a PDQ priority.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0. The priority will be limited
# to DB_MAX_PDQ cfg value.
# The PDQ is pushed onto an internal stack, use core::db::pop_pdq to remove the
# PDQ from the list and reset to the previous priority.
#
# @param -conn_name Unique name which identifies the connection
# @param -pdq PDQ priority
# @return PDQ value set, or zero if setting of PDQs is disabled
#
proc core::db::push_pdq args {

	variable CFG
	variable PDQ_LIST
	variable DB_DATA

	array set ARGS [core::args::check core::db::push_pdq {*}$args]

	set conn_name $ARGS(-conn_name)
	set pdq       $ARGS(-pdq)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {!$CFG($conn_name,max_pdq)} {
		core::log::write INFO {DB $conn_name: setting pdq priority disabled}
		return 0
	} elseif {$pdq > $CFG($conn_name,max_pdq)} {
		core::log::write INFO\
		    {DB $conn_name: limiting pdq priority to $CFG($conn_name,max_pdq)}
		set pdq $CFG($conn_name,max_pdq)
	}

	lappend PDQ_LIST($conn_name) $pdq

	# - on connection error, re-connect and re-attempt pdq push
	if {[catch {_set_pdq $conn_name $pdq} msg]} {
		set err_code [core::db::failover::handle_error \
			-conn_name $conn_name \
			-package   $CFG($conn_name,package) \
			-attempt   0 \
			-msg       $msg]

		switch -- $err_code {
			RECONN {
				_connect $conn_name
				_set_pdq $conn_name $pdq
			}
			NOOP {
				error $msg $::errorInfo $::errorCode
			}
			REPREP -
			RESTART {
				core::db::restart -conn_name $conn_name
				error $msg $::errorInfo $::errorCode
			}
		}
	}

	return $pdq
}

core::args::register \
	-proc_name core::db::pop_pdq \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Reset the PDQ priority to previous setting.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0, and the PDQ stack is
# not exhausted.
#
# @param -conn_name Unique name which identifies the connection
# @return PDQ value set, or zero if setting of PDQs is disabled, or the
#   list is exhausted
#
proc core::db::pop_pdq args {

	variable CFG
	variable PDQ_LIST
	variable DB_DATA

	array set ARGS [core::args::check core::db::pop_pdq {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {!$CFG($conn_name,max_pdq)} {
		core::log::write INFO {DB $conn_name: setting pdq priority disabled}
		return 0
	} elseif {[llength $PDQ_LIST($conn_name)] < 2} {
		core::log::write INFO {DB $conn_name: exhausted PDQ stack}
		return 0
	}

	set PDQ_LIST($conn_name) [lreplace $PDQ_LIST($conn_name) end end]
	set pdq [lindex $PDQ_LIST($conn_name) end]

	# - on connection error, re-connect and re-attempt pdq pop
	if {[catch {_set_pdq $conn_name $pdq} msg]} {
		set err_code [core::db::failover::handle_error \
			-conn_name $conn_name \
			-package   $CFG($conn_name,package) \
			-attempt   0 \
			-msg       $msg]

		switch -- $err_code {
			RECONN {
				_connect $conn_name
				_set_pdq $conn_name $pdq
			}
			NOOP {
				error $msg $::errorInfo $::errorCode
			}
			REPREP -
			RESTART {
				core::db::restart -conn_name $conn_name
				error $msg $::errorInfo $::errorCode
			}
		}
	}

	return $pdq
}



# Private procedure to set the PDQ priority.
# Use core::db::push_pdq to set the PDQ and core::db::pop_pdq to reset the
# PDQ.
#
# @param conn_name Unique name which identifies the connection
# @param pdq       PDQ priority
#
proc core::db::_set_pdq { conn_name pdq } {

	variable CFG
	variable CONN

	core::log::write DEBUG {DB $conn_name: set pdqpriority $pdq}

	set stmt [$CFG($conn_name,namespace)::prep_sql \
		-conn_name $CONN($conn_name) \
		-qry       "set pdqpriority $pdq"]

	$CFG($conn_name,namespace)::exec_stmt \
		-conn_name $CONN($conn_name) \
		-inc_type  0 \
		-stmt      $stmt

	$CFG($conn_name,namespace)::close_stmt \
		-conn_name $CONN($conn_name) \
		-stmt      $stmt
}

#--------------------------------------------------------------------------
# Query Semaphores
#--------------------------------------------------------------------------

# Initialise query semaphores for a connection (if required and available).
#
# This will examine the use_qry_sems and qry_sems_key "cfg" settings.
#
# Afterwards, use_qry_sems will only be true if we have managed to
# allocate a suitable set of semaphores - details can be found in
# the newly-created qry_sems_id and qry_sems_size "cfg" settings.
#
proc core::db::_init_qry_sems {conn_name} {

	variable CFG

	if {!$CFG(use_qry_sems)} {
		# not required
		return
	}

	set bad 0
	set qry_sems_err_msg "unknown error"

	if {!$bad && $CFG($conn_name,failover)} {
		set bad 1
		set qry_sems_err_msg "not supported when failover enabled"
	}

	# There's no point having a seperate set for each connection,
	# and SysV semaphores are a limited resource - so we actually
	# create a shared semaphore set used by all connections.

	if {!$bad && $CFG(shared_qry_sems_id) == ""} {
		if {$CFG(supports_qry_sems) == "UNKNOWN"} {
			set CFG(supports_qry_sems) [_detect_qry_sems_support]
		}
		if {!$CFG(supports_qry_sems)} {
			set bad 1
			set qry_sems_err_msg "not supported by appserver"
		} else {
			set key $CFG(qry_sems_key)

			if {[catch {
				set sem_id [_create_qry_sems_set $key]
			} err_msg]} {
				set bad 1
				set qry_sems_err_msg $err_msg
			} else {
				set CFG(shared_qry_sems_id) $sem_id
				set CFG(shared_qry_sems_key) $key
			}
		}
	}

	# Copy details of the shared sempahore set into this connection.

	if {!$bad && $CFG(shared_qry_sems_id) != ""} {
		if {$CFG(qry_sems_key) != $CFG(shared_qry_sems_key)} {
			set bad 1
			set qry_sems_err_msg \
			  "qry_sems_key of $CFG(qry_sems_key)\
			   does not match the key of $CFG(shared_qry_sems_key)\
			   used by the $CFG(shared_qry_sems_conns) connection(s)"
		} else {
			lappend CFG(shared_qry_sems_conns) $conn_name
		}
	}

	if {$CFG(shared_qry_sems_id) == ""} {
		set CFG(use_qry_sems) 0
		# We deliberately refuse to initialise if query semaphores
		# could not be initialised (unless use_qry_sems has been
		# explicitly disabled). Don't change this behaviour or the
		# default of 1 for use_qry_sems since the danger of a silent
		# performance regression occurring is too high (e.g. if the
		# semaphore set could not be created).
		set err_msg \
		  "DB $conn_name: refusing to start without\
		   query semaphores: $qry_sems_err_msg"
		core::log::write ERROR {$err_msg}
		error $err_msg
	} else {
		core::log::write INFO \
		  {DB $conn_name: using query semaphores (id=$CFG(shared_qry_sems_id))}
	}

	return
}

# Are we running inside an appserver that would support using a set
# of semaphores to protect queries, and that can not only allocate
# suggested indexes on asFindRs cache misses, but also give us more
# info about asFindRs lookups?
#
# Ideally we'd also check if the appserver has the buggy version of
# asFindRs that frees an allocated semaphore index when asFindRs is
# called without the -alloc-sem flag - but there's no way of testing
# this behaviour from within a single child process! If there was an
# asGetVersion call, we might use that, but instead, users must be
# careful to observe the list of buggy versions below and not enable
# query semaphores on those appserv versions ...
#
# Versions that work OK:
#
#   1.40.31+
#   1.40.30.2+
#   1.40.29.5+
#
# Versions where query semaphores are BUGGY in a nasty and
# hard-to-test-for-from-Tcl way:
#
#   1.40.30 and 1.40.30.1
#   1.40.29, 1.40.29.1 to 1.40.29.4
#   1.40.28, 1.40.28.1 to 1.40.28.5
#
# Versions where query semaphores aren't supported anyway:
#
#   1.40.27.* and below
#
#
proc core::db::_detect_qry_sems_support {} {

	if {![string equal [info commands asFindRs] asFindRs]} {
		return 0
	}

	set usage "" ; catch {ipc_sem_create} usage
	if {![string match "*-nsems*" $usage]} {
		return 0
	}

	set usage "" ; catch {asFindRs} usage
	if {![string match "*-with-info*" $usage]} {
		return 0
	}

	set usage "" ; catch {asFindRs} usage
	if {![string match "*-alloc-sem*" $usage]} {
		return 0
	}

	return 1
}

# Create a semaphore set to be used with the appserver's
# "asFindRs -alloc-sem" mechanism to protect queries.
proc core::db::_create_qry_sems_set {sem_key} {

	set sem_id ""
	set sems_allocated 0
	set err_msg "unknown error"

	# We want to allocate a semaphore set large enough that the
	# indexes returned from asFindRs -alloc-sem map directly onto
	# indexes within our semaphore set. Hopefully we can ask the
	# appserver how many we need:
	if {[catch {
		set sems_needed [asGetCacheNumSems]
	}]} {
		# Guess the appserver is too old to have this command.
		# However, we can reasonably assume that it it would have
		# returned the number of appserver child processes since
		# that's the basis of how -alloc-sem allocates its indexes.
		# Sadly, there isn't a command to get that either in older
		# versions, so try to figure it out from the config file:
		set nprocs [OT_CfgGet PROCS_PER_PORT 1]
		if {$nprocs == [asGetGroupSize]} {
			set sems_needed $nprocs
		} else {
			# When child groups are in use we have no way of figuring
			# out how many processes there are in total. Let's pick
			# a figure that's (hopefully) higher than any sane person
			# would use, but not so high as to be totally unreasonable
			# as a semaphore set size.

			set sems_needed [OT_CfgGet DEFAULT_SEMAPHORE_SET_SIZE 200]

			core::log::write WARNING \
			  {Unsure how many semaphores needed; guessed at $sems_needed}
		}
	}

	if {[catch {
		set sem_id [ipc_sem_create -nsems $sems_needed $sem_key]
	} err_msg]} {
		error "unable to allocate semaphore set\
		       of size $sems_needed with key $sem_key\
		       : $err_msg\
		       (perhaps size too large, key unsuitable,\
		        or key in use for an existing incompatible set?)"
	}

	return $sem_id
}

#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

core::args::register \
	-proc_name core::db::get_err_code \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]
# Gets the last Informix error code
#
# @param -conn_name Unique name which identifies the connection
# @return Last Informix error code
#
proc core::db::get_err_code args {

	variable CFG
	variable CONN
	variable DB_DATA

	array set ARGS [core::args::check core::db::get_err_code {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	return [$CFG($conn_name,namespace)::last_err_num -conn_name $CONN($conn_name)]
}

core::args::register \
	-proc_name core::db::get_buf_reads \
	-args [list \
		$::core::db::CORE_DEF(conn_name)
	]

# Gets the number of buffer reads
#
# @param -conn_name Unique name which identifies the connection
# @return Count of buffer reads
#
proc core::db::get_buf_reads args {

	variable CFG
	variable CONN
	variable BUFREADS
	variable DB_DATA

	array set ARGS [core::args::check core::db::get_buf_reads {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	return [$CFG($conn_name,namespace)::buf_reads -conn_name $CONN($conn_name)]
}

core::args::register \
	-proc_name core::db::restart \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]
# Conditional restart, this may be overriden in the config
# @param -conn_name Unique name which identifies the connection
#
proc core::db::restart args {
	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::restart {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {$CFG($conn_name,restart_on_error)} {
		asRestart
	} else {
		core::log::write ERROR {DB $conn_name: asRestart not called due to config override}
	}
}

core::args::register \
	-proc_name core::db::log_locks \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]
#
# Log the locks from the for the given database
# @param -conn_name Unique name which identifies the connection
#
proc core::db::log_locks args {

	variable CFG
	variable CONN
	variable DB_DATA

	array set ARGS [core::args::check core::db::log_locks {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	$CFG($conn_name,namespace)::log_locks -conn_name $CONN($conn_name)
}

# Provide mechanism to change configuration items
core::args::register \
	-proc_name core::db::reconfigure \
	-args [list \
		[list -arg -conn_name -mand 0 -check ASCII -default {} -desc {Database connection name}] \
		[list -arg -cfg_name  -mand 1 -check ASCII             -desc {Configuration name}] \
		[list -arg -cfg_value -mand 1 -check ASCII             -desc {Configuration value}] \
	] \
	-body {
		variable CFG
		variable DB_DATA

		array set ARGS [core::args::check core::db::reconfigure {*}$args]

		set conn_name $ARGS(-conn_name)
		set cfg_name  $ARGS(-cfg_name)
		set cfg_value $ARGS(-cfg_value)

		if {$conn_name == {}} {
			set conn_name [lindex $DB_DATA(connections) 0]
			core::log::write DEBUG {No connection specified. Using first connection $conn_name}
		}

		if {[info exists CFG($conn_name,$cfg_name,switchable)]} {
			set CFG($conn_name,$cfg_name) $cfg_value
		} else {
			core::log::write ERROR {DB $conn_name: failed to reconfigure $cfg_name, configuration item does not exist}
		}
	}

core::args::register \
	-proc_name core::db::insert_active_sess \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Record details of this session in the db for performance tracking etc
#
# @param -conn_name - Unique name to identify the connection
#
proc core::db::insert_active_sess args {

	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::insert_active_sess {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {[catch {
		# based on which db we are using this option may not be supported and or
		# will need to use different tables/schema etc. Getting sql from the
		# relevant package so we can use the db_multi logging to ensure we
		# have a record of this exec in case performance is bad for some reason
		switch -- [string toupper $CFG($conn_name,package)] {
			INFORMIX - INFSQL  {
				set sql [$CFG($conn_name,namespace)::get_ins_active_sess_sql]

				store_qry \
					-connections [list $conn_name] \
					-name        ins_active_sess_sql \
					-qry         $sql

				exec_qry \
					-name ins_active_sess_sql \
					-args [list \
						$CFG($conn_name,sess_app_name) \
						$CFG($conn_name,sess_group_no) \
						$CFG($conn_name,sess_child_no)]

				unprep_qry \
					-name        ins_active_sess_sql \
					-connections [list $conn_name]
			}
			default {
				core::log::write WARNING {DB $conn_name: Unsupported to insert active session with package: $CFG($conn_name,package)}
			}
		}
	} msg]} {
		# if fails just log warning as not critical
		core::log::write WARNING {DB $conn_name: Failed to insert active session: $msg}
	}
}

core::args::register \
	-proc_name core::db::delete_active_sess \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Delete details of session in the db
#
# @param -conn_name The connection to delete
#
proc core::db::delete_active_sess args {

	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::delete_active_sess {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {[catch {
		# based on which db we are using this option may not be supported and or
		# will need to use different tables/schema etc. Getting sql from the
		# relevant package so we can use the db_multi logging to ensure we
		# have a record of this exec in case performance is bad for some reason
		switch -- [string toupper $CFG($conn_name,package)] {
			INFORMIX - INFSQL  {
				set sql [$CFG($conn_name,namespace)::get_del_active_sess_sql]

				store_qry \
					-connections [list $conn_name] \
					-name        del_active_sess_sql \
					-qry         $sql

				exec_qry -name del_active_sess_sql
				unprep_qry \
					-name        del_active_sess_sql \
					-connections [list $conn_name]
			}
			default {
				core::log::write WARNING {DB $conn_name: Unsupported to delete active session with package: $CFG($conn_name,package)}
			}
		}
	} msg]} {
		# if fails just log warning as not critical
		core::log::write WARNING {DB $conn_name: Failed to delete active session: $msg}
	}

}

core::args::register \
	-proc_name core::db::store_sess_info \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Store a record of this database session
#
# @param -conn_name The connection to delete
#
proc core::db::store_sess_info args {

	variable CFG
	variable DB_DATA

	array set ARGS [core::args::check core::db::store_sess_info {*}$args]

	set conn_name $ARGS(-conn_name)

	if {$conn_name == {}} {
		set conn_name [lindex $DB_DATA(connections) 0]
		core::log::write DEBUG {No connection specified. Using first connection $conn_name}
	}

	if {[catch {
		# based on which db we are using this option may not be supported and or
		# will need to use different tables/schema etc. Getting sql from the
		# relevant package so we can use the db_multi logging to ensure we
		# have a record of this exec in case performance is bad for some reason
		switch -- [string toupper $CFG($conn_name,package)] {
			INFORMIX - INFSQL  {
				set sql [$CFG($conn_name,namespace)::get_store_sess_sql]

				store_qry \
					-connections [list $conn_name] \
					-name        store_sess_sql \
					-qry         $sql

				exec_qry \
					-name store_sess_sql \
					-args [list \
						$CFG($conn_name,sess_app_name) \
						$CFG($conn_name,sess_group_no) \
						$CFG($conn_name,sess_child_no)]

				unprep_qry \
					-name        store_sess_sql \
					-connections [list $conn_name]
			}
			default {
				core::log::write WARNING {DB $conn_name: Unsupported to store session with package: $CFG($conn_name,package)}
			}
		}
	} msg]} {
		# if fails just log warning as not critical
		core::log::write WARNING {DB $conn_name: Failed to store session: $msg}
	}
}

# Open the debug query file
core::args::register \
	-proc_name core::db::open_qry_debug_file \
	-body {
		variable CFG

		if {$CFG(debug_qry_file) == {}} {
			return
		}

		# We should only write out queries for the configured child
		# -1 indicates that this is a script and should be treated as always
		# write out
		if {$CFG(debug_qry_child) != -1 && $CFG(debug_qry_child) != [asGetId]} {
			return
		}

		set dir      [file dirname $CFG(debug_qry_file)]
		set new_file 0

		if {![file isdirectory $dir]} {
			file mkdir $dir
		}

		if {![file exists $CFG(debug_qry_file)]} {
			incr new_file
		}

		# Open the file
		if {[catch {
			set CFG(debug_qry_fd) [open $CFG(debug_qry_file) w]
			fconfigure $CFG(debug_qry_fd) \
				-translation auto \
				-buffering   none \
				-encoding    utf-8

			set debug_file [read $CFG(debug_qry_fd)]
		} err]} {
			core::log::write ERROR {ERROR $err}
			return
		}

		if {$new_file} {
			set header [format "--\n-- OpenBet Core debug sql generated %s\n" \
				[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]

			append header [format "-- Child %s\n--\n" $CFG(debug_qry_child)]

			if {[catch {
				puts $CFG(debug_qry_fd) $header
			} err]} {
				core::log::write ERROR {ERROR $err}
				return
			}
		}
	}

core::args::register \
	-proc_name core::db::write_qry_debug \
	-args [list \
		$::core::db::CORE_DEF(connections) \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(qry) \
		[list -arg -cache -mand 0 -check UINT  -default 0  -desc {result set cache time (seconds) disabled if DB_NO_CACHE cfg value is non-zero}] \
	] \
	-body {
		variable CFG

		if {$CFG(debug_qry_fd) == {}} {
			return
		}

		# We should only write out queries for the configured child
		# -1 indicates that this is a script and should be treated as always
		# write out
		if {$CFG(debug_qry_child) != -1 && $CFG(debug_qry_child) != [asGetId]} {
			return
		}

		set body \n
		append body [string repeat "-" 60]
		append body [format "\n-- %s\n"           $ARGS(-name) ]
		append body [format "-- Connections %s\n" $ARGS(-connections)]
		append body [format "-- Cache Time %ss\n" $ARGS(-cache)]
		append body $ARGS(-qry)

		if {[catch {
			puts $CFG(debug_qry_fd) $body
		} err]} {
			core::log::write ERROR {ERROR $err}
			return
		}
	}


#  Takes in an SQL and error message
#  and if the msg contains
core::args::register \
	-proc_name core::db::_qry_error_annotate \
	-is_public 0 \
	-args [list \
		[list -arg -sql  -mand 1 -check ANY               -desc {Query SQL}] \
		[list -arg -msg  -mand 1 -check ANY              -desc {Error message}] \
	] \
	-body {
		set sql $ARGS(-sql)
		set msg $ARGS(-msg)
		set out $sql
		if {[regexp -- {occurred on line ([0-9]+), near character ([0-9]+)} $msg -- row col]} {
			set out [_annotate_qry_pos -sql $sql -row $row -col $col]
		}
		return $out
	}


#   Prints a query, annotating the row and column
#   that is showing the error
#
#
core::args::register \
	-desc  {Prints a query, annotating the position} \
	-is_public 0 \
	-proc_name core::db::_annotate_qry_pos \
	-args [list \
		[list -arg -sql  -mand 1 -check ANY               -desc {query SQL}] \
		[list -arg -row  -mand 1 -check UINT              -desc {row we need to Highllight}] \
		[list -arg -col  -mand 1 -check UINT              -desc {column we need to Highllight}] \
	] \
	-body {
		set sql $ARGS(-sql)
		set row $ARGS(-row)
		set col $ARGS(-col)
		set tag {^}
		set ret {}

		set curr_row 0
		foreach row_str [split $sql "\n"] {
			incr curr_row
			append ret $row_str
			append ret "\n"
			if {$curr_row == $row} {
				set out_row ""
				set skip 0
				# As query may contain tabs we need to include them in the output
				for {set curr_col 0} {$curr_col < $col - 1} {incr curr_col} {
					set char [string index $row_str $curr_col]
					if {$char == {}} {
						# Index out of range - break
						set skip 1
						break
					} elseif {$char eq "\t"} {
						append out_row "\t"
					} else {
						append out_row " "
					}
				}
				if {!$skip} {
					append ret $out_row
					append ret $tag
					append ret "\n"
					append ret "########"
					append ret "\n"
				}
			}
		}
		return $ret
	}


# Checks whether an rs will need to be chunked by the appserver
# before being stored in distributed cache
#
proc core::db::_log_dist_cache_info {rs} {

	variable CFG

	if {$CFG(distrib_cache)} {
		set chunk_size [expr {[OT_CfgGet AS_DIST_CACHE_CHUNK_SIZE 768] * 1024}]
		if {[db_get_bytes $rs] > $chunk_size} {
			core::log::write INFO {Result set size is [db_get_bytes $rs] and will be stored in chunks}
		}
	}
}
