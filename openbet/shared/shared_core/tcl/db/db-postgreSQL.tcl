# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for postgreSQL C API, implements a common interface to allow
# the main db packages to be used with any database provider
#
set pkgVersion 1.0
package provide core::db::postgreSQL $pkgVersion

# Dependencies
package require core::log          1.0
package require core::check        1.0
package require core::args         1.0
package require core::db           1.0
package require core::db::failover 1.0

if {[catch {package present PgTcl}]} {
	if {[catch {load libOT_PgTcl.so} err]} {
		error "Unable to load postgres library libOT_PgTcl.so : $err"
	}
}

core::args::register_ns \
	-namespace core::db::postgreSQL \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::db core::db::failover] \
	-docs      db/db-postgreSQL.xml

namespace eval core::db::postgreSQL {}

core::args::register \
	-proc_name core::db::postgreSQL::open_conn \
	-args [list \
		[list -arg -db_name   -mand 1 -check ASCII            -desc {Database name}] \
		[list -arg -db_server -mand 1 -check ASCII            -desc {Database server}] \
		[list -arg -db_port   -mand 1 -check UINT             -desc {Database port}] \
		[list -arg -username  -mand 0 -check ASCII -default 0 -desc {Database username}] \
		[list -arg -password  -mand 0 -check ASCII -default 0 -desc {Database password}] \
	]

# Open a connection
# @param -db_name Database name
# @param -db_server Database server name
# @param -db_port Database port
# @param -username Database username
# @param -password Database password

proc core::db::postgreSQL::open_conn args {

	array set ARGS [core::args::check core::db::postgreSQL::open_conn {*}$args]

	set db       $ARGS(-db_name)
	set server   $ARGS(-db_server)
	set port     $ARGS(-db_port)
	set username $ARGS(-username)
	set password $ARGS(-password)

	if {[catch {
		if {$username != 0 && $password != 0} {
			if {[package vcompare 1.1 [package present PostgreSQL]] <= 0} {
				if {[package present PostgreSQL] >= 1.2} {
					set db [pg::open_conn -host $server -port $port -user $username -pass $password $db]
				} else {
					set db [pg::open_conn -host $server -user $username -pass $password $db]
				}
			} else {
				set db [pg::open_conn $db $server $username $password]
			}
		} else {
			if {[package vcompare 1.1 [package present PostgreSQL]] <= 0 } {
				set db [pg::open_conn -host $server $db]
			} else {
				set db [pg::open_conn $db $server]
			}
		}
	} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $db
}

core::args::register \
	-proc_name core::db::postgreSQL::close_conn \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Close the database connection
proc core::db::postgreSQL::close_conn args {

	array set ARGS [core::args::check core::db::postgreSQL::close_conn {*}$args]

	return [pg::close_conn $ARGS(-conn_name)]
}

core::args::register \
	-proc_name core::db::postgreSQL::conn_list

# return a list of connections
proc core::db::postgreSQL::conn_list  {} {
	return [pg::conn_list]
}

core::args::register \
	-proc_name core::db::postgreSQL::prep_sql \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(qry) \
	]

# prepare a query
# @param -conn_name Unique name to identify the connection
# @param -qry Query to prepare
proc core::db::postgreSQL::prep_sql args {

	array set ARGS [core::args::check core::db::postgreSQL::prep_sql {*}$args]

	return [pg::prep_sql $ARGS(-conn_name) [_rewrite_qry $ARGS(-qry)]]
}

core::args::register \
	-proc_name core::db::postgreSQL::stmt_list

# get a list of all prepared statements
proc core::db::postgreSQL::stmt_list {} {
	return [pg::stmt_list]
}

core::args::register \
	-proc_name core::db::postgreSQL::exec_stmt \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(args) \
		[list -arg -inc_type  -mand 0 -check BOOL -default 0 -desc {Handle blobs}] \
	]

#
# Run a query
# @param -conn_name Unique name to identify the connection
# @param -inc_type Handle blobs
# @param -stmt Prepared statement to execute
# @param -args Arguments to substitute into placeholders
proc core::db::postgreSQL::exec_stmt args {

	array set ARGS [core::args::check core::db::postgreSQL::exec_stmt {*}$args]

	if {[catch {set rs [eval pg::exec_stmt $ARGS(-stmt) $ARGS(-args)]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rs
}


core::args::register \
	-proc_name core::db::postgreSQL::close_stmt \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	]

# Close a statement
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to execute to close
proc core::db::postgreSQL::close_stmt args {

	array set ARGS [core::args::check core::db::postgreSQL::close_stmt {*}$args]

	pg::close_stmt $ARGS(-stmt)
}


core::args::register \
	-proc_name core::db::postgreSQL::last_err_num \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Get the last error code
proc core::db::postgreSQL::last_err_num args {

	array set ARGS [core::args::check core::db::postgreSQL::last_err_num {*}$args]

	return [pg::last_err_code $ARGS(-conn_name)]
}


core::args::register \
	-proc_name core::db::postgreSQL::begin_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Begin a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::postgreSQL::begin_tran args {

	array set ARGS [core::args::check core::db::postgreSQL::begin_tran {*}$args]

	pg::begin_tran $ARGS(-conn_name)
}


core::args::register \
	-proc_name core::db::postgreSQL::commit_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Commit a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::postgreSQL::commit_tran args {

	array set ARGS [core::args::check core::db::postgreSQL::commit_tran {*}$args]

	pg::commit_tran $ARGS(-conn_name)
}


core::args::register \
	-proc_name core::db::postgreSQL::rollback_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Rollback a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::postgreSQL::rollback_tran args {

	array set ARGS [core::args::check core::db::postgreSQL::rollback_tran {*}$args]

	pg::rollback_tran $ARGS(-conn_name)
}


core::args::register \
	-proc_name core::db::postgreSQL::get_row_count \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	]

# get the row count from the last executed stmt
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to execute to close
proc core::db::postgreSQL::get_row_count args {

	array set ARGS [core::args::check core::db::postgreSQL::get_row_count {*}$args]

	set count [pg::get_row_count $ARGS(-stmt)]

	return $count
}

# get the serial id of last inserted row
core::args::register \
	-proc_name core::db::postgreSQL::get_serial \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(opt,serial_type) \
	] \
	-body {
		# TODO: not supported?
		return -1
	}


core::args::register \
	-proc_name core::db::postgreSQL::rs_close \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -rs -mand 1 -check ASCII -desc {Result set reference}] \
	]

# Close a result set
# @param -conn_name Unique name to identify the connection
# @param -rs Result set
proc core::db::postgreSQL::rs_close args {

	array set ARGS [core::args::check core::db::postgreSQL::rs_close {*}$args]

	return [db_rs_close $ARGS(-rs)]
}

core::args::register \
	-proc_name core::db::postgreSQL::get_sessionid \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Return the session id of this connection
# @param -conn_name Unique name to identify the connection
proc core::db::postgreSQL::get_sessionid args {

	array set ARGS [core::args::check core::db::postgreSQL::get_sessionid {*}$args]

	set conn      $ARGS(-conn_name)
	set sessionid ""

	if {[catch {
		set sql       "select pg_backend_pid()"
		set rs        [pg::exec_sql $conn $sql]
		set sessionid [db_get_coln $rs 0 0]
		rs_close -conn_name $conn -rs $rs
	} msg]} {
		core::log::write ERROR {DB: Failed to get session id. $msg}
	}

	return $sessionid
}

core::args::register \
	-proc_name core::db::postgreSQL::log_locks \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Log current database locks.
# @param -conn_name Unique name to identify the connection
proc core::db::postgreSQL::log_locks args {
	# TODO: write something in this
	return
}

core::args::register \
	-proc_name core::db::postgreSQL::set_timeout \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -timeout -mand 1 -check UINT -desc {Session timeout}] \
	]

# Set timeout for queries on this connection
#
# @param -conn_name Unique name to identify the connection
# @param -timeout Session timeout
proc core::db::postgreSQL::set_timeout args {

	array set ARGS [core::args::check core::db::postgreSQL::set_timeout {*}$args]

	set conn    $ARGS(-conn_name)
	set timeout $ARGS(-timeout)

	if {[catch {
		set sql "set statement_timeout to $timeout"
		set rs  [pg::exec_sql $conn $sql]
	} msg]} {
		ob_log::write INFO {DB: Failed to set statement timeout. $msg}
		return 0
	}

	return 1
}

# Dump an explain plan in the logs.
core::args::register \
	-proc_name core::db::postgreSQL::explain \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(qry) \
		$::core::db::CORE_DEF(args) \
	] \
	-body {
		set conn $ARGS(-conn_name)
		set name $ARGS(-name)
		set qry  $ARGS(-qry)

		set sql      "explain [_rewrite_qry $qry]"
		set qry_name "explain_${name}"

		set stmt [prep_sql -conn_name $conn -qry $sql]

		if {[catch {
			set rs [exec_stmt \
				-conn_name $conn \
				-inc_type  0 \
				-stmt      $stmt\
				-args      $ARGS(-args)] \
		} msg]} {
			core::log::write ERROR {DB: could not get explain plan for $name. $msg}
		} else {

			set nrows [db_get_nrows $rs]

			set explain [list]
			for {set i 0} {$i < $nrows} {incr i} {
				lappend explain [db_get_coln $rs $i 0]
			}

			core::log::write_qry INFO \
				"DB::EXPLAIN" \
				"Explain plan for $name" \
				[join $explain "\n"]

			rs_close -conn_name $conn -rs $rs
		}

		close_stmt -conn_name $conn -stmt $stmt
	}

# Private procedure to rewrite a query so that it can be
# supported by PostgreSQL.
#
proc core::db::postgreSQL::_rewrite_qry {qry} {

	variable ::core::db::CFG

	if {!$CFG(rewrite_qry)} {
		return $qry
	}

	set str_map [list]

	lappend str_map "<MATCHES>" "~"
	lappend str_map "<NVL>"     "coalesce"
	lappend str_map "<CURRENT>" "now()"
	lappend str_map "<MAT_ARG>" "'\[?\]'"

	set qry_map [string map $str_map $qry]

	# Deal with the "first" informix syntax and the others "limit" syntax
	regsub -all {<FIRST[[:space:]]+([0-9]*)>} $qry_map {}         qry_map
	regsub -all {<LIMIT[[:space:]]+([0-9]*)>} $qry_map {limit \1} qry_map

	# Deal with converting a datetime field to a date
	regsub -all {<DATE ([^>]*)>} $qry_map {date(\1)} qry_map

	if {$qry != $qry_map} {
		core::log::write_qry DEBUG {DB} {Rewrote incompatible parts of query} $qry_map
		set qry $qry_map
	}

	if {[regsub -nocase {^[[:space:]]*execute[[:space:]]+procedure} $qry {select} qry] > 0} {
		core::log::write_qry DEBUG {DB} {Rewrote execute procedure as select} $qry
	}

	return $qry
}

core::args::register \
	-proc_name core::db::postgreSQL::buf_reads \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Retrieve the stats for buf_reads from the database
# @param -conn_name Connection name
# Currently Unsupported
proc core::db::postgreSQL::buf_reads args {
	return 0
}
