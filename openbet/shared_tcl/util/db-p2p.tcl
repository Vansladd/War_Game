# ============================================================================
#
# Orbis Poker
#
# $Id: db-p2p.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
#
# ============================================================================

package provide util_db 4.5


# Dependencies
#
package require util_log 4.5




# Variables
#
namespace eval ob_db {

	variable SQL
	variable INIT

	set INIT 0
}
set ::DB ""



# ----------------------------------------------------------------------------
# Init
# ----------------------------------------------------------------------------

# One time initialisation
#
proc ob_db::init args {

	variable INIT

	if {!$INIT} {
		ob_db::db_conn_open
	}
}



#
# ----------------------------------------------------------------------------
# Callback from lower-level code invoked when a database error occurs
# ----------------------------------------------------------------------------
#
proc ob_db::connection_state_cb {
	op
	err
	isam
	con_action
} {

	ob_log::write WARNING {connection_state_cb $op $err $isam $con_action}

	switch -- $con_action {
		reconnect {
			catch {
				ob_db::db_conn_close
			}
		}
		do-nothing {
		}
	}
}



#
# ----------------------------------------------------------------------------
# Open a connection to the database server
# ----------------------------------------------------------------------------
#
proc ob_db::db_conn_open args {

	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	set server    [OT_CfgGet DB_SERVER    ""]
	set database  [OT_CfgGet DB_DATABASE  ""]
	set username  [OT_CfgGet DB_USERNAME  ""]
	set password  [OT_CfgGet DB_PASSWORD  ""]
	set lockmode  [OT_CfgGet DB_LOCKMODE  "wait 23"]
	set isolation [OT_CfgGet DB_ISOLATION "committed read"]

	if {$server == "" || $database == ""} {
		#
		# Utterly fatal...
		#
		ob_log::write ERROR {DB_SERVER/DB_DATABASE must be specified}
		exit 1
	}

	if {[catch {

		if {$username == "" || $password == ""} {
			set ::DB [inf_open_conn $database@$server]
		} else {
			set ::DB [inf_open_conn $database@$server $username $password]
		}

		ob_log::write INFO {Connected to $database@$server}

		#
		# Set lock mode
		#
		set stmt [inf_prep_sql\
			$::DB set_lockmode "set lock mode to $lockmode"]
		inf_exec_stmt $stmt
		inf_close_stmt $stmt

		#
		# Set isolation
		#
		set stmt [inf_prep_sql\
			$::DB set_isolation "set isolation to $isolation"]
		inf_exec_stmt $stmt
		inf_close_stmt $stmt

		#
		# Set callback for connection errors
		#
		inf_set_err_callback ob_db::connection_state_cb

	} msg]} {

		ob_log::write ERROR {Failed to initialise to ${database}@${server}: ${msg}}

		if {$::DB ne ""} {
			catch {inf_close_conn $::DB}
			set ::DB ""
		}

		inf_set_err_callback

		return 0
	}

	set INIT 1

	return 1
}



#
# ----------------------------------------------------------------------------
# Close a database server connection
#   - try to free all prepared statements
#   - reset the global DB variable
# ----------------------------------------------------------------------------
#
proc ob_db::db_conn_close {} {

	variable SQL

	#
	# Close all prepared queries...
	#
	foreach e [array get SQL *,sql] {
		ob_db::qry_close [string range $e 0 end-4]
	}

	catch {inf_close_conn $::DB}

	set ::DB ""
}



#
# ----------------------------------------------------------------------------
# Store a query string
# ----------------------------------------------------------------------------
#
proc ob_db::store_qry {args} {

	variable SQL

	if {[llength $args] < 2} {
		error "Usage: store_qry ?arg? ?...? name sql"
	}

	for {set i 0} {$i < [llength $args]} {incr i} {
		if {![string match {--*} [lindex $args $i]]} {
			break
		}
	}

	set name [lindex $args $i]
	set sql  [lindex $args [expr {$i + 1}]]

	set SQL($name,sql)          $sql
	set SQL($name,stmt)         ""
	set SQL($name,pdq)          0
	set SQL($name,close)        0
	set SQL($name,rows)         0

	foreach a [lrange $args 0 end-2] {
		set v [join [lrange [split $a =] 1 end] =]
		switch -glob -- $a {
			--pdq=*   { set SQL($name,pdq)   $v }
			--close=* { set SQL($name,close) $v }
		}
	}
}



#
# ----------------------------------------------------------------------------
# Close a prepared statement
# ----------------------------------------------------------------------------
#
proc ob_db::qry_close {name} {

	variable SQL

	if {![info exists SQL($name,stmt)]} {
		return
	}

	if {$SQL($name,stmt) ne ""} {

		catch {inf_close_stmt $SQL($name,stmt)}

		set SQL($name,stmt) ""
	}
}



#
# ----------------------------------------------------------------------------
# Delete a stored query, closing prepared statement if necessary
# ----------------------------------------------------------------------------
#
proc ob_db::qry_delete {name} {

	variable SQL

	qry_close $name

	unset -nocomplain SQL($name,sql)
	unset -nocomplain SQL($name,stmt)
	unset -nocomplain SQL($name,pdq)
	unset -nocomplain SQL($name,close)
	unset -nocomplain SQL($name,rows)
}



#
# ----------------------------------------------------------------------------
# Begin/Commit/Rollback
#
# For 'begin', we attempt to connect to the database if there is no current
# connection. We *must NOT* do this for 'commit' or 'rollback'...
# ----------------------------------------------------------------------------
#
proc ob_db::begin_tran {} {

	#
	# If not connected, try to connect...
	#
	if {$::DB eq ""} {
		set ob_db::INIT 0
		ob_db::db_conn_open
	}

	inf_begin_tran $::DB
}

proc ob_db::commit_tran {} {

	inf_commit_tran $::DB
}

proc ob_db::rollback_tran {} {
	inf_rollback_tran $::DB
}



#
# ----------------------------------------------------------------------------
# Run a query...
# ----------------------------------------------------------------------------
#
proc ob_db::_qry_exec {name args} {

	variable SQL

	if {![info exists SQL($name,sql)]} {
		error "Unknown query: $name"
	}

	set SQL($name,rows) 0

	#
	# If not connected, try to connect...
	#
	if {$::DB eq ""} {
		set ob_db::INIT 0
		ob_db::db_conn_open
	}

	#
	# If not prepared, try to prepare...
	#
	if {$SQL($name,stmt) == ""} {

		if {$SQL($name,pdq) > 0} {
			pdq_set $SQL($name,pdq)
		}

		set stmt [inf_prep_sql $::DB $name $SQL($name,sql)]

		set SQL($name,stmt) $stmt

		if {$SQL($name,pdq) > 0} {
			pdq_set
		}
	}

	set res [eval {inf_exec_stmt $SQL($name,stmt)} $args]
	set SQL($name,rows) [inf_get_row_count $SQL($name,stmt)]

	if {$SQL($name,close)} {
		qry_close $name
	}

	return $res
}

proc ob_db::exec_qry {name args} {
	return [eval {ob_db::_qry_exec $name} $args]
}


proc ob_db::qry_row_count {name} {
	variable SQL
	return $SQL($name,rows)
}

proc ob_db::pdq_set {{pdq 0}} {
	catch {
		set stmt [inf_prep_sql $::DB pdq-set-$pdq "set pdqpriority $pdq"]
		catch {
			inf_exec_stmt $stmt
		}
		inf_close_stmt $stmt
	}
}

proc ob_db::garc {name} {

	variable SQL

	if {![info exists SQL($name,stmt)]} {
		return 0
	}

	return [inf_get_row_count $SQL($name,stmt)]
}

proc ob_db::rs_close {rs} {

	db_close $rs
}




#
# ----------------------------------------------------------------------------
# Wrappers for inf_ statements
#
# These wrappers hide the standard inf_ database access functions, and
# provide a consistent error handling and reporting interface
# ----------------------------------------------------------------------------
#
rename inf_prep_sql      w__inf_prep_sql
rename inf_exec_stmt     w__inf_exec_stmt
rename inf_close_stmt    w__inf_close_stmt
rename inf_begin_tran    w__inf_begin_tran
rename inf_commit_tran   w__inf_commit_tran
rename inf_rollback_tran w__inf_rollback_tran

rename db_close          w__db_close

#
# These are the errors we handle "gracefully" - all others are presumed to
# be symptomatic of some disastrous event, and cause the database connection
# to be closed and re-opened
#
#   -255    Not in transaction.
#   -268    Unique constraint constraint-name violated.
#   -391    Integrity constraint violation.
#   -530    Integrity constraint violation.
#   -746    User defined exception.
#   -1213   Character to numeric conversion error.
#   -1262   Non-numeric character in datetime or interval.
#
# These are (normally) caused by locking problems -- we'll optionally
# list out all the db server's locks when this happens
#
#   -243    Could not position within a table table-name.
#   -244    Could not do a physical-order read to fetch next row.
#   -245    Could not position within a file via an index.
#
# Might want to try to handle this one as well:
#
#   -710 Table table-name has been dropped, altered, or renamed
#
set ::INF_ERR_ACTION(-255)  [list inf_err_noop]
set ::INF_ERR_ACTION(-268)  [list inf_err_noop]
set ::INF_ERR_ACTION(-391)  [list inf_err_noop]
set ::INF_ERR_ACTION(-530)  [list inf_err_noop]
set ::INF_ERR_ACTION(-746)  [list inf_err_noop]
set ::INF_ERR_ACTION(-1213) [list inf_err_noop]
set ::INF_ERR_ACTION(-1262) [list inf_err_noop]

set ::INF_ERR_ACTION(-243)  [list inf_err_list_locks]
set ::INF_ERR_ACTION(-244)  [list inf_err_list_locks]
set ::INF_ERR_ACTION(-245)  [list inf_err_list_locks]

set ::INF_ERR_CALLBACK      inf_err_callback_null

#
# If DB_LOG_QRY_TIME is true, then we'll log DB::EXEC lines for each
# query involcation
#
set INF_LOG_TIME [OT_CfgGet DB_LOG_QRY_TIME 0]

#
# If DB_LOG_QRY_TEXT is true, log each SQL statment (if it's ok) along
# with its affected row count
#
set INF_LOG_SQL [OT_CfgGet DB_LOG_QRY_TEXT 0]

#
# Don't log some statements
#
array set INF_NO_LOG_SQL [list]

foreach q [split [OT_CfgGet DB_NO_LOG_QRY [list]]] {
	set INF_NO_LOG_SQL([string trim $q]) 1
}

unset -nocomplain q

#
# If DB_LOG_TXN is set, begin/commit/rollback statements will be logged
#
set INF_LOG_TXN [OT_CfgGet DB_LOG_TXN 0]

#
# If DB_LOG_LOCKS is true we will print out the database server's lock
# table when we get 243/244/245 errors
#
set INF_LOG_LOCKS             [OT_CfgGet DB_LOG_LOCKS 0]
set INF_LOG_LOCKS_64BIT_CHECK [OT_CfgGet DB_LOG_LOCKS_64BIT_CHECK 1]

#
# If DB_LOG_LONG_QRY is set then we will log all queries with a running time
# longer than the specified value
#
set INF_LOG_LONGQ [OT_CfgGet DB_LOG_LONG_QRY 99999999.9]

#
# Ancient app servers can't retrieve ISAM error codes...
#
if {![llength [info commands inf_last_isam_num]]} {
	proc inf_last_isam_num {} { return 0 }
}


#
# We store the text of queries as they are prepared - when the prepared
# statement is closed, the associcated text is binned too
#
array set ::INF_STMT [list]


#
# ----------------------------------------------------------------------------
# Safe db_close
# ----------------------------------------------------------------------------
#
proc db_close {res} {
	if {[string length $res] > 0} {
		w__db_close $res
	}
}


#
# ----------------------------------------------------------------------------
# Retrieve text associated with prepared statement
# ----------------------------------------------------------------------------
#
proc inf_stmt_txt stmt {

	if {[info exists ::INF_STMT($stmt,text)]} {
		return $::INF_STMT($stmt,text)
	} else {
		return ""
	}
}


#
# ----------------------------------------------------------------------------
# inf_prep_sql with optional query naming - if you don't pass a query name,
# info level is used to get the calling proc's name
# ----------------------------------------------------------------------------
#
proc inf_prep_sql {db args} {

	if {[llength $args] == 1} {
		if {[info level] > 1} {
			set name "<proc-[lindex [info level -1] 0]>"
		} else {
			set name "<toplevel>"
		}
		set text [lindex $args 0]
	} elseif {[llength $args] == 2} {
		set name [lindex $args 0]
		set text [lindex $args 1]
	} else {
		error "Usage: inf_prep_sql db ?name? sql"
	}

	set name [string trim $name]

	set c [catch {
		set stmt [w__inf_prep_sql $db $text]
	} msg]

	if {$c == 0} {
		set ::INF_STMT($stmt,text)  $text
		set ::INF_STMT($stmt,name)  $name
		set ::INF_STMT($stmt,conn)  $db
		set ::INF_STMT($stmt,nolog) [info exists ::INF_NO_LOG_SQL($name)]
		return $stmt
	}

	inf_err inf_prep_sql $db $text
}


#
# ----------------------------------------------------------------------------
# inf_exec_stmt with timing and logging possibilities
# ----------------------------------------------------------------------------
#
proc inf_exec_stmt {stmt args} {

	set c [catch {
		set t0 [OT_MicroTime -micro]
		set res [eval {w__inf_exec_stmt $stmt} $args]
		set t1 [OT_MicroTime -micro]
	} msg]

	if {$c == 0} {
		if {$::INF_LOG_TIME} {
			set tt [expr {$t1-$t0}]
			set sn $::INF_STMT($stmt,name)
			ob_log::write INFO {DB::EXEC $sn [format %0.6f $tt] $args}
			if {$tt > $::INF_LOG_LONGQ} {
				ob_log::write WARNING {DB::LONGQ $sn [format %0.6f $tt]}
				set rc [inf_get_row_count $stmt]
				eval {inf_log LONGQ [inf_stmt_txt $stmt] $rc} $args
			}
		}
		if {$::INF_LOG_SQL && !$::INF_STMT($stmt,nolog)} {
			set rc [inf_get_row_count $stmt]
			set qt [inf_stmt_txt $stmt]
			eval {inf_log inf_exec_stmt $qt $rc} $args
		}
		return $res
	}

	set db  $::INF_STMT($stmt,conn)
	set txt [inf_stmt_txt $stmt]

	eval {inf_err inf_exec_stmt $db $txt} $args
}


#
# ----------------------------------------------------------------------------
# inf_close_stmt
# ----------------------------------------------------------------------------
#
proc inf_close_stmt {stmt} {

	set c [catch {
		w__inf_close_stmt $stmt
	} msg]

	if {$c == 0} {
		unset -nocomplain ::INF_STMT($stmt,text)
		unset -nocomplain ::INF_STMT($stmt,name)
		unset -nocomplain ::INF_STMT($stmt,conn)
		unset -nocomplain ::INF_STMT($stmt,nolog)
		return
	}

	inf_err inf_close_stmt $::INF_STMT($stmt,conn) "<close stmt>"
}


#
# ----------------------------------------------------------------------------
# inf_begin_tran
# ----------------------------------------------------------------------------
#
proc inf_begin_tran {db} {

	if {$::INF_LOG_TXN} {
		inf_log inf_begin_tran "begin work" -1
	}

	set c [catch {
		w__inf_begin_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err inf_begin_tran $db "<begin work>"
}


#
# ----------------------------------------------------------------------------
# inf_commit_tran
# ----------------------------------------------------------------------------
#
proc inf_commit_tran {db} {

	if {$::INF_LOG_TXN} {
		inf_log inf_commit_tran "commit work" -1
	}

	set c [catch {
		w__inf_commit_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err inf_commit_tran $db "<commit work>"
}


#
# ----------------------------------------------------------------------------
# inf_rollback_tran
# ----------------------------------------------------------------------------
#
proc inf_rollback_tran {db} {

	if {$::INF_LOG_TXN} {
		inf_log inf_rollback_tran "rollback work" -1
	}

	set c [catch {
		w__inf_rollback_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err inf_rollback_tran $db "<rollback work>"
}


#
# ----------------------------------------------------------------------------
# Set callback for database errors
# ----------------------------------------------------------------------------
#
proc inf_set_err_callback {{cb ""}} {
	if {$cb ne ""} {
		set ::INF_ERR_CALLBACK $cb
	} else {
		set ::INF_ERR_CALLBACK inf_err_callback_null
	}
}


#
# ----------------------------------------------------------------------------
# default (no-op) callback for database errors
# ----------------------------------------------------------------------------
#
proc inf_err_callback_null {op err isam action} {
	ob_log::write ERROR { <default db err handler> $op ($err,$isam) --> $action}
}


#
# ----------------------------------------------------------------------------
# Expand tabs in a string
# ----------------------------------------------------------------------------
#
proc inf_txt_expand {str {tablen 4}} {
	set out {}
	while {[set i [string first "\t" $str]] != -1} {
		set j [expr {$tablen-($i%$tablen)}]
		append out [string range $str 0 [incr i -1]][format %*s $j { }]
		set str [string range $str [incr i 2] end]
	}
	return $out$str
}


#
# ----------------------------------------------------------------------------
# count how many leading spaces we can strip from each string in the list
# ----------------------------------------------------------------------------
#
proc inf_lead_space_count {ll} {
	set min -1
	foreach s $ll {
		regsub {^\s+} $s {} n
		set c [expr {[string length $s]-[string length $n]}]
		if {$min == -1} {
			set min $c
		} elseif {$c < $min} {
			set min $c
		}
	}
	return [expr {($min < 0) ? 0 : $min}]
}


#
# ----------------------------------------------------------------------------
# Log a query, substituting arguments (in args) for '?' placeholders. We
# strip as many leading spaces as possible and skip blank lines
# ----------------------------------------------------------------------------
#
proc inf_log {proc qry_txt rowcount args} {

	set qp [split $qry_txt ?]
	set p  [list [lindex $qp 0]]
	foreach pp [lrange $qp 1 end] aa $args {
		lappend p \"[string map {\" \"\"} $aa]\"
		lappend p $pp
	}
	set qry_txt [join $p ""]
	set ll [list]
	foreach l [split $qry_txt "\n"] {
		if {[string length [string trim $l]] == 0} {
			continue
		}
		lappend ll [inf_txt_expand $l]
	}
	set s_range [inf_lead_space_count $ll]
	foreach l $ll {
		ob_log::write INFO {$proc : [string range $l $s_range end]}
	}
	if {$rowcount >= 0} {
		ob_log::write INFO {$proc : rowcount = $rowcount}
	}
}


#
# ----------------------------------------------------------------------------
# Handle an error. We log the query and the error numbers, then perform
# a sequence of actions which depends on the error number
# ----------------------------------------------------------------------------
#
proc inf_err {proc db qry_txt args} {

	set e_num  [inf_last_err_num]
	set e_isam [inf_last_isam_num]
	set e_msg  [string trim [inf_last_err_msg]]

	if {$e_isam == 0} {
		set e_str $e_num
	} else {
		set e_str ${e_num},${e_isam}
	}

	#
	# Log the error numbers and message, and the substituted query text
	#
	ob_log::write ERROR {[string repeat * 80]}
	ob_log::write ERROR {$proc : error ($e_str) $e_msg}
	eval {inf_log $proc $qry_txt -1} $args
	ob_log::write ERROR {[string repeat * 80]}


	#
	# If we don't explicitly trap the error, we treat it as a reconnect...
	#
	if {![info exists ::INF_ERR_ACTION($e_num)]} {
		set err_actions [list inf_err_reconnect]
	} else {
		set err_actions $::INF_ERR_ACTION($e_num)
	}

	#
	# What to do to the connection
	#
	set con_action do-nothing

	#
	# Perform each action...
	#
	foreach a $err_actions {
		switch -- $a {
			inf_err_reconnect {
				ob_log::write ERROR {$proc : error ($e_str) ==> reconnect}
				set con_action reconnect
			}
			default {
				# nothing to add
			}
		}
		catch {
			eval {$a} {$db}
		}
	}

	$::INF_ERR_CALLBACK $proc $e_num $e_isam $con_action

	error "error ($e_num) $e_msg"
}


#
# ----------------------------------------------------------------------------
# Stub procedure to do nothing (used for errors we think we can handle)
# ----------------------------------------------------------------------------
#
proc inf_err_noop {args} {
}


#
# ----------------------------------------------------------------------------
# Procedure for "fatal" errors -- make the app server restart
# ----------------------------------------------------------------------------
#
proc inf_err_fatal {args} {
	exit
}


#
# ----------------------------------------------------------------------------
# Procedure for errors which are locking related -- we show the
# current locks -- probably most useful after an error number in the
# range 243/244/245 with an ISAM code of 107,113,143,144,154:
#
# -243	Could not position within a table table-name.
# -244	Could not do a physical-order read to fetch next row.
# -245	Could not position within a file via an index.
#
# -107	ISAM error: record is locked.
# -113	ISAM error: the file is locked.
# -143	ISAM error: deadlock detected.
# -144	ISAM error: key value locked.
# -154	ISAM error: lock Timeout Expired.
# ----------------------------------------------------------------------------
#
proc inf_err_list_locks {args} {

	if {!$::INF_LOG_LOCKS} {
		return
	}

	set db [lindex $args 0]

	#
	# 64-bit servers have slightly different sysmaster tables...
	#
	set extra_where { }
	if {$::INF_LOG_LOCKS_64BIT_CHECK} {
		set sql_version {
			select c.colname
			from   sysmaster:syscolumns c,
				sysmaster:systables t
			where  t.tabname = 'syslcktab' and
				t.tabid   = c.tabid     and
				c.colname = 'ownerpad'
		}

		set stmt [inf_prep_sql $db $sql_version]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if {[db_get_nrows $res] > 0} {
			set extra_where {
				and l.ownerpad = x.addresspad and
				x.ownerpad = r.addresspad and
			}
		} else {
			set extra_where { }
		}

		db_close $res
	}

	set sql_lock [subst {
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
			l.partnum  <> 1048578  and
			l.partnum  = p.partnum and
			l.owner    = x.address and
			x.owner    = r.address and
			r.sid      = s.sid
			$extra_where
		order by
			l.grtime desc
	}]

	set h1 [format "%-18s %-18s %4s %6s %5s %-16s %6s"\
			database\
			table\
			lock\
			sid\
			pid\
			hostname\
			age(s)]
	set h2 [format "%-18s %-18s %4s %6s %5s %-16s %6s"\
			------------------\
			------------------\
			----\
			------\
			-----\
			----------------\
			------]

	set stmt_lock [inf_prep_sql $db $sql_lock]

	set res_l [inf_exec_stmt $stmt_lock]

	inf_close_stmt $stmt_lock

	set nl [db_get_nrows $res_l]

	ob_log::write INFO {LOCKDIAG: $h1}
	ob_log::write INFO {LOCKDIAG: $h2}

	set t_now [clock seconds]

	for {set l 0} {$l < $nl} {incr l} {

		set dbsname  [db_get_col $res_l $l dbsname]
		set tabname  [db_get_col $res_l $l tabname]
		set type     [db_get_col $res_l $l type]
		set sid      [db_get_col $res_l $l sid]
		set pid      [db_get_col $res_l $l pid]
		set hostname [db_get_col $res_l $l hostname]
		set grtime   [db_get_col $res_l $l grtime]

		set line [format "%-18s %-18s %4s %6d %5d %-16s %6d"\
			$dbsname\
			$tabname\
			$type\
			$sid\
			$pid\
			$hostname\
			[expr {$t_now-$grtime}]]

		ob_log::write INFO {LOCKDIAG: $line}
	}

	db_close $res_l
}
