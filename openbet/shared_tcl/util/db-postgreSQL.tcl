# $Id: db-postgreSQL.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for postgreSQL C API, implements a common interface to allow
# the main db packages to be used with any database provider
#
package provide util_db_postgreSQL 4.5

if {[catch {package present PgTcl}]} {
	if {[catch {load libOT_PgTcl.so} err]} {
		error "Unable to load postgres library libOT_PgTcl.so : $err"
	}
}


namespace eval db_postgreSQL { }


proc db_postgreSQL::open_conn  {db {server ""} {port ""} {username ""} {password ""}} {

	if {[catch {
		if {$username != 0 && $password != 0} {
			if { [package vcompare 1.1 [package present PostgreSQL]] <= 0} {
				if {[package present PostgreSQL] >= 1.2} {
					set db [pg::open_conn -host $server -port $port -user $username -pass $password $db]
				} else {
					set db [pg::open_conn -host $server -user $username -pass $password $db]
				}
			} else {
				set db [pg::open_conn $db $server $username $password]
			}
		} else {
			if { [package vcompare 1.1 [package present PostgreSQL]] <= 0 } {
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



#
# Close the database connection
#
proc db_postgreSQL::close_conn {conn} {
	return [pg::close_conn $conn]
}


#
# return a list of connections
#
proc db_postgreSQL::conn_list  {} {
	return [pg::conn_list]
}


#
# prepare a query
#
proc db_postgreSQL::prep_sql {conn qry} {
	return [pg::prep_sql $conn [_rewrite_qry $qry]]
}


#
# get a list of all prepared statements
#
proc db_postgreSQL::stmt_list {} {
	return [pg::stmt_list]
}


#
# Run a query
#
proc db_postgreSQL::exec_stmt {conn inc_type stmt args} {

	if {[catch {set rs [eval [list pg::exec_stmt $stmt] $args]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rs
}


#
# Close a statement
#
proc db_postgreSQL::close_stmt {conn stmt} {
	pg::close_stmt $stmt
}


#
# Get the last error code
#
proc db_postgreSQL::last_err_num {conn} {
	return [pg::last_err_code $conn]
}


#
# Begin a transaction
#
proc db_postgreSQL::begin_tran {conn} {
	pg::begin_tran $conn
}


#
# Commit a transaction
#
proc db_postgreSQL::commit_tran {conn} {
	pg::commit_tran $conn
}


#
# Rollback a transaction
#
proc db_postgreSQL::rollback_tran {conn} {
	pg::rollback_tran $conn
}


#
# get the row count from the last executed stmt
#
proc db_postgreSQL::get_row_count {conn stmt} {
	pg::get_row_count $stmt
}


#
# get the serial id of last inserted row
#
proc db_postgreSQL::get_serial {conn stmt} {
	# TODO: not supported?
	return -1
}


#
# Close a result set
#
proc db_postgreSQL::rs_close {conn rs} {
	return [db_rs_close $rs]
}


#
# Informix specific request included for compatibility
#
proc db_postgreSQL::is_64bit_db {conn} { return 0 }


# Log current database locks.
#
#   conn - name of the database
#
proc db_postgreSQL::column_details {conn table column} {
	# TODO: write something in this
	return
}


# Log current database locks.
#
#   conn - name of the database
#
proc db_postgreSQL::log_locks {conn} {
	# TODO: write something in this
	return
}


# Set timeout for queries on this connection
#
#   conn - name of the database
#
proc db_postgreSQL::set_timeout {conn timeout} {
	set sql  "set statement_timeout to $timeout"
	set stmt [pg::prep_sql  $conn $sql]
	set rs   [pg::exec_stmt $stmt]
	ob_log::write INFO {Statement timeout set to $timeout milliseconds}
	return
}


# Dump an explain plan in the logs.
#
proc db_postgreSQL::explain {conn name qry_string vals} {

	set sql      "explain [_rewrite_qry $qry_string]"
	set qry_name "explain_${name}"

	set stmt [prep_sql $conn $sql]

	if {[catch {set rs [eval [list exec_stmt $conn 0 $stmt] $vals]} msg]} {

		ob_log::write INFO {DB: could not get explain plan for $name. $msg}

	} else {

		set nrows [db_get_nrows $rs]

		set explain [list]
		for {set i 0} {$i < $nrows} {incr i} {
			lappend explain [db_get_coln $rs $i 0]
		}

		ob_log::write_qry INFO \
			"DB::EXPLAIN" \
			"Explain plan for $name" \
			[join $explain "\n"]

		rs_close $conn $rs
	}

	close_stmt $conn $stmt
}


# Private procedure to rewrite a query so that it can be
# supported by PostgreSQL.
#
proc db_postgreSQL::_rewrite_qry {qry} {

	if {![OT_CfgGet DB_PG_REWRITE 1]} {
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
		ob_log::write_qry DEBUG {DB} {Rewrote incompatible parts of query} $qry_map
		set qry $qry_map
	}

	if {[regsub -nocase {^[[:space:]]*execute[[:space:]]+procedure} $qry {select} qry] > 0} {
		ob_log::write_qry DEBUG {DB} {Rewrote execute procedure as select} $qry
	}

	return $qry
}
