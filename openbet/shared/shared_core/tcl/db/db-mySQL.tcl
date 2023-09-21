# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for mySQL C API, implements a common interface to allow
# the main db packages to be used with any database provider
#
set pkg_version 1.0

package provide core::db::mySQL $pkg_version

# Dependencies
package require core::log          1.0
package require core::check        1.0
package require core::args         1.0
package require core::db           1.0
package require core::db::failover 1.0

if {[catch {package present MySQLTcl}]} {
	if {[catch {load libOT_MySQLTcl.so} err]} {
		error "Unable to load mysql library libOT_MySQLTcl.so : $err"
	}
}

core::args::register_ns \
	-namespace core::db::mySQL \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::db core::db::failover] \
	-docs      db/db_mySQL.xml

namespace eval core::db::mySQL {}

core::args::register \
	-proc_name core::db::mySQL::open_conn \
	-desc {Opens a connection.} \
	-args [list \
		[list -arg -db_name   -mand 1 -check ASCII            -desc {Database name}] \
		[list -arg -db_server -mand 1 -check ASCII            -desc {Database server}] \
		[list -arg -db_port   -mand 1 -check UINT             -desc {Database port}] \
		[list -arg -username  -mand 0 -check ASCII -default 0 -desc {Database username}] \
		[list -arg -password  -mand 0 -check ASCII -default 0 -desc {Database password}] \
	] \
	-returns {A connection handler.} \
	-body {
		if {[catch {
			if {$ARGS(-username) != 0 && $ARGS(-password) != 0} {
				set rtn [mysql::open_conn $ARGS(-db_server) $ARGS(-db_name) $ARGS(-username) $ARGS(-password)]
			} else {
				set rtn [mysql::open_conn $ARGS(-db_server) $ARGS(-db_name)]
			}
		} msg]} {
			error $msg $::errorInfo $::errorCode
			return 0
		}
		return $rtn
	}

#
# Close the database connection
#
core::args::register \
	-proc_name core::db::mySQL::close_conn \
	-desc {Close a connection} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {} \
	-body {
		return [mysql::close_conn $ARGS(-conn_name)]
	}


#
# return a list of connections
#
core::args::register \
	-proc_name core::db::mySQL::conn_list \
	-desc {List all connections.} \
	-returns {A list of all connections.} \
	-body {
		return [mysql::conn_list]
	}


#
# prepare a query
#
core::args::register \
	-proc_name core::db::mySQL::prep_sql \
	-desc {Prepares a query.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(qry) \
	] \
	-returns {} \
	-body {
		set rewritten_qry [_rewrite_qry $ARGS(-qry)]
		return [mysql::prep_sql $ARGS(-conn_name) $rewritten_qry]
	}


#
# get a list of all prepared statements
#
core::args::register \
	-proc_name core::db::mySQL::stmt_list \
	-desc {Get a list of all prepared statements} \
	-returns {A list of all prepared statements} \
	-body {
		return [mysql::stmt_list]
	}


#
# Run a query
#
core::args::register \
	-proc_name core::db::mySQL::exec_stmt \
	-desc {Executes a statement}\
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(args) \
		[list -arg -inc_type  -mand 0 -check BOOL -default 0 -desc {Handle blobs}] \
	] \
	-returns {A resultset.} \
	-body {

		if {[catch {set rs [eval [list mysql::exec_stmt $ARGS(-stmt)] $ARGS(-args)]} msg]} {
			error $msg $::errorInfo $::errorCode
			return 0
		}

		return $rs
	}


#
# Close a statement
#
core::args::register \
	-proc_name core::db::mySQL::close_stmt \
	-desc {Close a statement.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	] \
	-returns {Nothing} \
	-body {
		mysql::close_stmt $ARGS(-stmt)
	}


#
# Get the last error code
#
core::args::register \
	-proc_name core::db::mySQL::last_err_num \
	-desc {Get the last error code.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {The last error code} \
	-body {
		return [mysql::last_err_num -conn $ARGS(-conn_name)]
	}


#
# Begin a transaction
#
# Please ensure engine = InnoDB since for transactions to be enabled
core::args::register \
	-proc_name core::db::mySQL::begin_tran \
	-desc {Start a transaction.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {Nothing} \
	-body {
		mysql::begin_tran $ARGS(-conn_name)
	}


#
# Commit a transaction
#
core::args::register \
	-proc_name core::db::mySQL::commit_tran \
	-desc {Commit a transaction.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {Nothing} \
	-body {
		mysql::commit_tran $ARGS(-conn_name)
	}


#
# Rollback a transaction
#
core::args::register \
	-proc_name core::db::mySQL::rollback_tran \
	-desc {Rollback a transaction.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {Nothing} \
	-body {
		mysql::rollback_tran $ARGS(-conn_name)
	}


#
# get the row count from the last executed stmt
#
core::args::register \
	-proc_name core::db::mySQL::get_row_count \
	-desc {Get the row count from the last executed stmt.} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	] \
	-returns {The row count.} \
	-body {
		return [mysql::get_row_count $ARGS(-conn_name)]
	}


#
# get the serial id of last inserted row
#
# NOTE stmt and serial_type are not needed by MySQL
core::args::register \
	-proc_name core::db::mySQL::get_serial \
	-desc {NON IMPLEMENTED, get the serial id of last inserted row} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(opt,serial_type) \
	] \
	-returns {The last serial} \
	-body {
		return [mysql::get_serial $ARGS(-conn_name)]
	}


#
# close a result set
#
core::args::register \
	-proc_name core::db::mySQL::rs_close \
	-desc {close a result set} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -rs -mand 1 -check ASCII -desc {Result set reference}] \
	] \
	-returns {} \
	-body {
		return [db_rs_close $ARGS(-rs)]
	}

core::args::register \
	-proc_name core::db::mySQL::get_sessionid \
	-desc {Return the session id of this connection} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {The session id}

# Return the session id of this connection
# @param -conn_name Unique name to identify the connection
proc core::db::mySQL::get_sessionid args {

	array set ARGS [core::args::check core::db::mySQL::get_sessionid {*}$args]

	set conn      $ARGS(-conn_name)
	set sessionid ""

	if {[catch {
		set stmt [core::db::mySQL::prep_sql \
			-conn_name $ARGS(-conn_name) \
			-qry       "SELECT CONNECTION_ID();"]

		set rs        [eval [list mysql::exec_stmt $stmt]]
		set sessionid [db_get_coln $rs 0 0]
		db_rs_close $rs
	} msg]} {
		core::log::write ERROR {DB: Failed to get session id. $msg}
	}

	return $sessionid
}

# Log current database locks.
#
#   conn - name of the database
#
core::args::register \
	-proc_name core::db::mySQL::log_locks \
	-desc {Log current database locks} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {} \
	-body {
	# TODO: write something in this
		return
	}


# Set timeout for queries on this connection
#
#   conn - name of the database
#
core::args::register \
	-proc_name core::db::mySQL::set_timeout \
	-desc {Set timeout for queries on this connection} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -timeout -mand 1 -check UINT -desc {Session timeout}] \
	] \
	-returns {} \
	-body {
		# TODO: write something in this
		return 0
	}


# Dump an explain plan in the logs.
#
core::args::register \
	-proc_name core::db::mySQL::explain \
	-desc {Dump an explain plan in the logs} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(name) \
		$::core::db::CORE_DEF(qry) \
		$::core::db::CORE_DEF(args) \
	] \
	-returns {Nothing} \
	-body {
		set conn        $ARGS(-conn_name)
		set name        $ARGS(-name)
		set qry_string  $ARGS(-qry)
		set vals        $ARGS(-args)

		set sql      "explain [_rewrite_qry $qry_string]"
		set qry_name "explain_${name}"

		set stmt [mysql::prep_sql $conn $sql]

		if {[catch {set rs [eval [list mysql::exec_stmt $conn 0 $stmt] $vals]} msg]} {

			core::log::write INFO {DB: could not get explain plan for $name. $msg}

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

			rs_close $conn $rs
		}
		core::db::mySQL::close_stmt -conn_name $conn -stmt $stmt
	}


#
# Informix specific request included for compatibility
#
proc core::db::mySQL::is_64bit_db {conn} { return 0 }


# Log current database locks.
#
#   conn - name of the database
#
proc core::db::mySQL::column_details {conn table column} {
	# TODO: write something in this
	return
}


# Private procedure to rewrite a query so that it can be
# supported by MySQL.
#
proc core::db::mySQL::_rewrite_qry {qry} {

	set str_map [list]

	lappend str_map "<NVL>"     "coalesce"
	lappend str_map "<CURRENT>" "now()"
	lappend str_map "NVL"     "coalesce"
	lappend str_map "CURRENT" "now()"
	lappend str_map "current" "now()"
	lappend str_map "TODAY"   "curdate()"
	lappend str_map "trunc"   "truncate"
	lappend str_map "? units" "interval ?"

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

	return $qry
}


core::args::register \
	-proc_name core::db::mySQL::buf_reads \
	-desc {Retrieve the stats for buf_reads from the database} \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	] \
	-returns {}

# Retrieve the stats for buf_reads from the database
# @param -conn_name Connection name
# Currently Unsupported
proc core::db::mySQL::buf_reads args {
	return 0
}
