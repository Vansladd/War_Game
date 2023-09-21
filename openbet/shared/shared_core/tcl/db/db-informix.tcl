# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for informix C API, implements a common interface to allow
# the main db packages to be used with any database provider
#

set pkgVersion 1.0
package provide core::db::informix $pkgVersion


# Dependencies
package require core::log          1.0
package require core::check        1.0
package require core::args         1.0
package require core::db           1.0
package require core::db::failover 1.0

core::args::register_ns \
	-namespace core::db::informix \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::db core::db::failover] \
	-docs      db/db-informix.xml

if {[catch {package present Infsql}]} {
	if {[catch {load libOT_InfTcl.so} err]} {
		error "Unable to load informix library libOT_InfTcl.so : $err"
	}
}

namespace eval core::db::informix {}

core::args::register \
	-proc_name core::db::informix::open_conn \
	-args [list \
		[list -arg -db_name   -mand 1 -check ASCII            -desc {Database name}] \
		[list -arg -db_server -mand 1 -check ASCII            -desc {Database server}] \
		[list -arg -db_port   -mand 0 -check UINT  -default 0 -desc {Database port}] \
		[list -arg -username  -mand 0 -check ASCII -default 0 -desc {Database username}] \
		[list -arg -password  -mand 0 -check ASCII -default 0 -desc {Database password}] \
	]

# Open a connection
# @param -db_name Database name
# @param -db_server Database server name
# @param -db_port Database port
# @param -username Database username
# @param -password Database password
proc core::db::informix::open_conn args {

	array set ARGS [core::args::check core::db::informix::open_conn {*}$args]

	set db       $ARGS(-db_name)
	set server   $ARGS(-db_server)
	set username $ARGS(-username)
	set password $ARGS(-password)

	if {[catch {
		if {$username != 0 && $password != 0} {
			set rtn [inf_open_conn ${db}@${server} $username $password]
		} else {
			set rtn [inf_open_conn ${db}@${server}]
		}
	} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rtn
}

core::args::register \
	-proc_name core::db::informix::close_conn \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Close the database connection
# @param -conn_name Unique name to identify the connection
proc core::db::informix::close_conn args {

	array set ARGS [core::args::check core::db::informix::close_conn {*}$args]

	return [inf_close_conn $ARGS(-conn_name)]
}


core::args::register \
	-proc_name core::db::informix::conn_list

# return a list of connections
proc core::db::informix::conn_list  {} {
	return [inf_get_conn_list]
}

core::args::register \
	-proc_name core::db::informix::prep_sql \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(qry)\
	]
#
# prepare a query
# @param -conn_name Unique name to identify the connection
# @param -qry Query to prepare
proc core::db::informix::prep_sql args {

	array set ARGS [core::args::check core::db::informix::prep_sql {*}$args]

	return [inf_prep_sql $ARGS(-conn_name) [_rewrite_qry $ARGS(-qry)]]
}


core::args::register \
	-proc_name core::db::informix::stmt_list

# get a list of all prepared statements
proc core::db::informix::stmt_list {} {
	return [inf_get_stmt_list]
}

core::args::register \
	-proc_name core::db::informix::exec_stmt \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(args) \
		[list -arg -inc_type  -mand 1 -check BOOL -desc {Handle blobs}] \
	]
#
# Run a query
# @param -conn_name Unique name to identify the connection
# @param -inc_type Handle blobs
# @param -stmt Prepared statement to execute
# @param -args Arguments to substitute into placeholders
proc core::db::informix::exec_stmt args {

	array set ARGS [core::args::check core::db::informix::exec_stmt {*}$args]

	set inc_type_str ""
	if {$ARGS(-inc_type) == 1} {
		set inc_type_str "-inc-type"
	}

	if {[catch {set rs [eval inf_exec_stmt $inc_type_str $ARGS(-stmt) $ARGS(-args)]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rs
}

core::args::register \
	-proc_name core::db::informix::close_stmt \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	]

# Close a statement
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to execute to close
proc core::db::informix::close_stmt args {

	array set ARGS [core::args::check core::db::informix::close_stmt {*}$args]

	inf_close_stmt $ARGS(-stmt)
}

core::args::register \
	-proc_name core::db::informix::last_err_num

# Get the last error code
proc core::db::informix::last_err_num args {
	return [inf_last_err_num]
}

core::args::register \
	-proc_name core::db::informix::begin_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Begin a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::informix::begin_tran args {

	array set ARGS [core::args::check core::db::informix::begin_tran {*}$args]

	return [inf_begin_tran $ARGS(-conn_name)]
}

core::args::register \
	-proc_name core::db::informix::commit_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Commit a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::informix::commit_tran args {

	array set ARGS [core::args::check core::db::informix::commit_tran {*}$args]

	return [inf_commit_tran $ARGS(-conn_name)]
}

core::args::register \
	-proc_name core::db::informix::rollback_tran \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Rollback a transaction
# @param -conn_name Unique name to identify the connection
proc core::db::informix::rollback_tran args {

	array set ARGS [core::args::check core::db::informix::rollback_tran {*}$args]

	return [inf_rollback_tran $ARGS(-conn_name)]
}

core::args::register \
	-proc_name core::db::informix::get_row_count \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	]

# get the row count from the last executed stmt
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to execute to close
proc core::db::informix::get_row_count args {

	array set ARGS [core::args::check core::db::informix::get_row_count {*}$args]

	return [inf_get_row_count $ARGS(-stmt)]
}

# get the serial id of last inserted row
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to execute to close_conn
# @parem -serial_type data type of the serial to retrieve
core::args::register \
	-proc_name core::db::informix::get_serial \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(opt,serial_type) \
	] \
	-body {
		switch -- $ARGS(-serial_type) {
			serial -
			{} {
				return [inf_get_serial $ARGS(-stmt)]
			}
			serial8 {
				return [inf_get_serial -serial8 $ARGS(-stmt)]
			}
			bigserial {
				return [inf_get_serial -bigserial $ARGS(-stmt)]
			}
		}
	}

core::args::register \
	-proc_name core::db::informix::rs_close \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		[list -arg -rs -mand 1 -check ASCII -desc {Result set reference}] \
	]

# Close a result set
# @param -conn_name Unique name to identify the connection
# @param -rs Result set
proc core::db::informix::rs_close args {

	array set ARGS [core::args::check core::db::informix::rs_close {*}$args]

	return [db_rs_close $ARGS(-rs)]
}

core::args::register \
	-proc_name core::db::informix::exec_stmt_for_fetch \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
		$::core::db::CORE_DEF(args) \
		[list -arg -inc_type  -mand 1 -check BOOL -desc {Handle blobs}] \
	]

# Execute a statement for cursor based parsing
# @param -conn_name Unique name to identify the connection
# @param -inc_type Handle blobs
# @param -stmt Prepared statement to execute
# @param -args Arguments to substitute into placeholders
proc core::db::informix::exec_stmt_for_fetch args {

	array set ARGS [core::args::check core::db::informix::exec_stmt_for_fetch {*}$args]

	set inc_type_str ""
	if {$ARGS(-inc_type)} {
		set inc_type_str "-inc-type"
	}

	if {[catch {set rs [eval inf_exec_stmt_for_fetch $inc_type_str $ARGS(-stmt) $ARGS(-args)]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rs
}

core::args::register \
	-proc_name core::db::informix::fetch_done \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
		$::core::db::CORE_DEF(stmt) \
	]

# Close cursor
# @param -conn_name Unique name to identify the connection
# @param -stmt Prepared statement to fetch
proc core::db::informix::fetch_done args {

	array set ARGS [core::args::check core::db::informix::fetch_done {*}$args]

	return [inf_fetch_done $ARGS(-stmt)]
}

core::args::register \
	-proc_name core::db::informix::get_sessionid \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Return the session id of this connection
# @param -conn_name Unique name to identify the connection
proc core::db::informix::get_sessionid args {

	array set ARGS [core::args::check core::db::informix::get_sessionid {*}$args]

	set conn_name $ARGS(-conn_name)
	set sessionid ""

	if {[catch {
		set stmt [inf_prep_sql $conn_name "select DBINFO('sessionid') from systables where tabid=1"]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		set sessionid [db_get_coln $rs 0 0]
		rs_close -conn_name $conn_name -rs $rs
	} msg]} {
		core::log::write ERROR {DB: Failed to get session id. $msg}
	}

	return $sessionid
}

core::args::register \
	-proc_name core::db::informix::log_locks \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Log current database locks.
#
# @param -conn_name Unique name to identify the connection
proc core::db::informix::log_locks args {

	variable CFG

	array set ARGS [core::args::check core::db::informix::get_sessionid {*}$args]

	set conn_name $ARGS(-conn_name)

	core::log::write WARNING {DB: locks: [format \
		{%-18s %-18s %4s %6s %5s %-16s %6s} \
		database \
		table \
		lock \
		sid \
		pid \
		hostname \
		age(s)]}

	core::log::write WARNING {DB: locks: [format \
		{%-18s %-18s %4s %6s %5s %-16s %6s} \
		------------------ \
		------------------ \
		---- \
		------ \
		----- \
		---------------- \
		------]}


	# 64-bit servers have slightly different sysmaster tables.
	# Note that we log all locks, since they are shared across databases
	# and the problem may not be with a lock on our database.
	#
	set sql [subst {
		select
			l.partnum,
			p.dbsname,
			p.tabname,
			l.rowidr,
			l.keynum,
			l.grtime,
			DECODE(l.type,
				 0, 'NONE',
				 1, 'BYTE',
				 2, 'IS',
				 3, 'S',
				 4, 'SR',
				 5, 'U',
				 6, 'UR',
				 7, 'IX',
				 8, 'SIX',
				 9, 'X',
				10, 'XR') type,
			r.sid,
			s.pid,
			s.hostname
		from
			sysmaster:syslcktab l,
			sysmaster:systabnames p,
			sysmaster:systxptab x,
			sysmaster:sysrstcb r,
			sysmaster:sysscblst s
		where
			l.partnum  <> 1048578
		and l.partnum  = p.partnum
		and l.owner    = x.address
		and x.owner    = r.address
		and r.sid      = s.sid
		order by
			l.grtime desc
	}]

	set now [clock seconds]

	set stmt [inf_prep_sql $conn_name $sql]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {

		set dbsname  [db_get_col $rs $r dbsname]
		set tabname  [db_get_col $rs $r tabname]
		set type     [db_get_col $rs $r type]
		set sid      [db_get_col $rs $r sid]
		set pid      [db_get_col $rs $r pid]
		set hostname [db_get_col $rs $r hostname]
		set grtime   [db_get_col $rs $r grtime]

		set line [format {%-18s %-18s %4s %6d %5d %-16s %6d}\
			$dbsname \
			$tabname \
			$type \
			$sid \
			$pid \
			$hostname \
			[expr {$now - $grtime}]]

		core::log::write WARNING {DB: locks: $line}
	}

	core::db::informix::rs_close -conn_name $conn_name -rs $rs
}


# Set timeout for queries on this connection
#
#   conn - name of the database
#
proc core::db::informix::set_timeout args {
	# TODO: write something in this
	return 0
}


# Dump an explain plan in the logs. Not supported on Informix.
#
proc core::db::informix::explain args {
	return
}


# Private procedure to rewrite a query so that it can be
# supported by PostgreSQL.
#
proc core::db::informix::_rewrite_qry {qry} {

	variable ::core::db::CFG

	if {!$CFG(rewrite_qry)} {
		return $qry
	}

	set str_map [list]

	lappend str_map "<MATCHES>" "matches"
	lappend str_map "<NVL>"     "nvl"
	lappend str_map "<CURRENT>" "current"
	lappend str_map "<MAT_ARG>" "'*\[?\]*'"

	set qry_map [string map $str_map $qry]

	# Deal with the "first" informix syntax and the others "limit" syntax
	regsub -all {<LIMIT[[:space:]]+([0-9]*)>} $qry_map {}         qry_map
	regsub -all {<FIRST[[:space:]]+([0-9]*)>} $qry_map {FIRST \1} qry_map

	# Deal with converting a datetime field to a date
	regsub -all {<DATE ([^>]*)>} $qry_map {extend(\1, year to day)} qry_map

	if {$qry != $qry_map} {
		core::log::write_qry DEBUG {DB} {Rewrote incompatible parts of query} $qry_map
		set qry $qry_map
	}

	return $qry
}

core::args::register \
	-proc_name core::db::informix::buf_reads \
	-args [list \
		$::core::db::CORE_DEF(conn_name) \
	]

# Retrieve the stats for buf_reads from the database
#
# http://publib.boulder.ibm.com/infocenter/idshelp/v10/index.jsp?topic=/com.ibm.adref.doc/adref216.htm
# The syssesprof table lists cumulative counts of the number
# of occurrences of user actions such as writes, deletes, or commits.
#
# @param -conn_name Connection name
proc core::db::informix::buf_reads args {

	variable CFG

	array set ARGS [core::args::check core::db::informix::buf_reads {*}$args]

	set conn_name $ARGS(-conn_name)

	if {![info exists CFG(buf_reads_stmt)]} {
		set sql "select bufreads from sysmaster:syssesprof where sid=DBINFO('sessionid')"
		set CFG(buf_reads_stmt) \
			[core::db::informix::prep_sql -conn_name $conn_name -qry $sql]
	}

	if {[catch {
		set rs       [inf_exec_stmt $CFG(buf_reads_stmt)]
		set bufreads [db_get_col $rs 0 bufreads]
		core::db::informix::rs_close -conn_name $conn_name -rs $rs
	}]} {
		set bufreads -1
	}
	return $bufreads
}

core::args::register \
	-proc_name core::db::informix::get_ins_active_sess_sql

# Return sql needed to record active session record
proc core::db::informix::get_ins_active_sess_sql args {

	set sql {
		execute procedure pInsObDbActiveSess(
			p_application = ?,
			p_group_no    = ?,
			p_child_no    = ?
		)
	}

	return $sql
}

core::args::register \
	-proc_name core::db::informix::get_del_active_sess_sql

# Return sql needed to delete active session record
proc core::db::informix::get_del_active_sess_sql args {

	set sql {delete from tObDbActiveSess where sid = DBINFO('sessionid')}

	return $sql
}

core::args::register \
	-proc_name core::db::informix::get_store_sess_sql

# Return sql needed to store record of work done by session
proc core::db::informix::get_store_sess_sql {} {

	set sql {
		execute procedure pInsObDbSessSummary(
			p_application = ?,
			p_group_no    = ?,
			p_child_no    = ?
		)
	}

	return $sql

}
