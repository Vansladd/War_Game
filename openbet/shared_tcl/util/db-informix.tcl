# $Id: db-informix.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for informix C API, implements a common interface to allow
# the main db packages to be used with any database provider
#
package provide util_db_informix 4.5

if {[catch {package present Infsql}]} {
	if {[catch {load libOT_InfTcl.so} err]} {
		error "Unable to load informix library libOT_InfTcl.so : $err"
	}
}


namespace eval db_informix { }


#
# Open a connection
#
proc db_informix::open_conn  {db server {username 0} {password 0}} {

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


#
# Close the database connection
#
proc db_informix::close_conn {conn} {
	return [inf_close_conn $conn]
}


#
# return a list of connections
#
proc db_informix::conn_list  {} {
	return [inf_get_conn_list]
}


#
# prepare a query
#
proc db_informix::prep_sql {conn qry} {
	return [inf_prep_sql $conn [_rewrite_qry $qry]]
}


#
# get a list of all prepared statements
#
proc db_informix::stmt_list {} {
	return [inf_get_stmt_list]
}


#
# Run a query
#
proc db_informix::exec_stmt {conn inc_type stmt args} {

	set inc_type_str ""
	if {$inc_type == 1} {
		set inc_type_str "-inc-type"
	}

	if {[catch {set rs [eval inf_exec_stmt $inc_type_str $stmt $args]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}

	return $rs
}


#
# Close a statement
#
proc db_informix::close_stmt {conn stmt} {
	inf_close_stmt $stmt
}


#
# Get the last error code
#
proc db_informix::last_err_num {conn} {
	return [inf_last_err_num]
}


#
# Begin a transaction
#
proc db_informix::begin_tran {conn} {
	return [inf_begin_tran $conn]
}


#
# Commit a transaction
#
proc db_informix::commit_tran {conn} {
	return [inf_commit_tran $conn]
}


#
# Rollback a transaction
#
proc db_informix::rollback_tran {conn} {
	return [inf_rollback_tran $conn]
}


#
# get the row count from the last executed stmt
#
proc db_informix::get_row_count {conn stmt} {
	return [inf_get_row_count $stmt]
}


#
# get the serial id of last inserted row
#
proc db_informix::get_serial {conn stmt} {
	return [inf_get_serial $stmt]
}


#
# Close a result set
#
proc db_informix::rs_close {conn rs} {
	return [db_rs_close $rs]
}


#
# Execute a statement for cursor based parsing
#
proc db_informix::exec_stmt_for_fetch {conn inc_type stmt args} {
	set inc_type ""
	if {$inc_type} {set inc_type "-inc-type"}

	if {[catch {set rs [eval inf_exec_stmt_for_fetch $inc_type $stmt $args]} msg]} {
		error $msg $::errorInfo $::errorCode
		return 0
	}
	return $rs
}


#
# Close cursor
#
proc db_informix::fetch_done {conn stmt} {
	return [inf_fetch_done $stmt]
}



#---------------------------------------------------------------------------
# Procedures
#---------------------------------------------------------------------------

# Determines if the Informix server is a 64bit server
#
#   conn    - name of the connection as returned by inf_open_conn
#   returns - 0 or 1
#
proc db_informix::_is_64bit_db {conn} {

	variable IS_64BIT_DB

	# We cache these results.
	#
	if {[info exists IS_64BIT_DB($conn)]} {
		return $IS_64BIT_DB($conn)
	}

	# Use the tabid trick to get database information.
	#
	set sql {
		select DBINFO('version','os') from sysTables where tabid = 1
	}

	set stmt [inf_prep_sql $conn $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	switch -- [db_get_coln $rs 0 0] {
		F {
			set IS_64BIT_DB($conn) 1
		}
		T -
		U -
		H {
			set IS_64BIT_DB($conn) 0
		}
		default {
			# this error is not expected
			error "Unknown database version/os"
		}
	}

	db_informix::rs_close $conn $rs

	return $IS_64BIT_DB($conn)
}


# Log current database locks.
#
#   conn - name of the database
#
proc db_informix::column_details {conn table column} {

	variable COLUMN_DETAILS

	if {![info exists COLUMN_DETAILS($conn,$table,$column,coltype)]} {
		set COLUMN_DETAILS($conn,$table,$column,coltype)   ""
		set COLUMN_DETAILS($conn,$table,$column,collength) ""
		set sql {
			select
				c.coltype,
				c.collength
			from
				systables t,
				syscolumns c
			where
				t.tabid   = c.tabid
			and t.tabname = ?
			and c.colname = ?
		}
		set stmt [inf_prep_sql $conn $sql]
		set rs [inf_exec_stmt $stmt $table $column]
		inf_close_stmt $stmt
		if {[db_get_nrows $rs] > 0} {
			set COLUMN_DETAILS($conn,$table,$column,coltype)   [db_get_col $res 0 coltype]
			set COLUMN_DETAILS($conn,$table,$column,collength) [db_get_col $res 0 collength]
		}
		db_informix::rs_close $conn $rs
	}
	return [list $COLUMN_DETAILS($conn,$table,$column,coltype) $COLUMN_DETAILS($conn,$table,$column,collength)]
}



# Log current database locks.
#
#   conn - name of the database
#
proc db_informix::log_locks {conn} {

	variable CFG

	ob_log::write WARNING {DB: locks: [format \
		{%-18s %-18s %4s %6s %5s %-16s %6s} \
		database \
		table \
		lock \
		sid \
		pid \
		hostname \
		age(s)]}

	ob_log::write WARNING {DB: locks: [format \
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

	set stmt [inf_prep_sql $conn $sql]

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

		ob_log::write WARNING {DB: locks: $line}
	}

	db_informix::rs_close $conn $rs
}


# Set timeout for queries on this connection
#
#   conn - name of the database
#
proc db_informix::set_timeout {conn timeout} {
	# TODO: write something in this
	return
}


# Dump an explain plan in the logs. Not supported on Informix.
#
proc db_informix::explain {conn name qry_string vals} {
	return
}


# Private procedure to rewrite a query so that it can be
# supported by PostgreSQL.
#
proc db_informix::_rewrite_qry {qry} {

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
		ob_log::write_qry DEBUG {DB} {Rewrote incompatible parts of query} $qry_map
		set qry $qry_map
	}

	return $qry
}


proc db_informix::buf_reads {conn} {

	variable CFG

	if {![info exists CFG(buf_reads_stmt)]} {
		set sql "select bufreads from sysmaster:syssesprof where sid=DBINFO('sessionid')"
		set CFG(buf_reads_stmt) [db_informix::prep_sql $conn $sql]
	}

	if {[catch {
			set rs [inf_exec_stmt $CFG(buf_reads_stmt)]
			set bufreads [db_get_col $rs 0 bufreads]
			db_informix::rs_close $conn $rs
	}]} {
			set bufreads -1
	}
	return $bufreads
}
