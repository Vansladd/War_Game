# ============================================================================
# $Id: db.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ============================================================================

#
# ------------------------------------------------------------------------------
# Make sure libOT_InfTcl is loaded ...
# ------------------------------------------------------------------------------
#
if { [catch {
	package present Infsql
}] } {
	if { [catch {
		load libOT_InfTcl.so
	} err] } {
		error "failed to load Informix TCL library: $err"
	}
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


#
# These are the errors we handle "gracefully" - all others are presumed to
# be symptomatic of some disastrous event, and cause the application
# server to restart
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
# list out all the db server's locks when this happens and restart the
# app server
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

set ::INF_ERR_ACTION(-243)  [list inf_err_list_locks inf_err_fatal]
set ::INF_ERR_ACTION(-244)  [list inf_err_list_locks inf_err_fatal]
set ::INF_ERR_ACTION(-245)  [list inf_err_list_locks inf_err_fatal]


#
# If DB_LOG_QRY_TIME is true, then we'll log DB::EXEC lines for each
# query involcation
#
set INF_LOG_TIME [OT_CfgGet DB_LOG_QRY_TIME 0]

#
# If DB_LOG_QRY_TEXT is true, then we'll log each query
#
set INF_LOG_SQL [OT_CfgGet DB_LOG_QRY_TEXT 0]

#
# If DB_LOG_LOCKS is true we will print out the database server's lock
# table when we get 243/244/245 errors
#
set INF_LOG_LOCKS [OT_CfgGet DB_LOG_LOCKS 0]

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
		set name "<proc [lindex [info level -1] 0]>"
		set text [lindex $args 0]
	} elseif {[llength $args] == 2} {
		set name [lindex $args 0]
		set text [lindex $args 1]
	} else {
		error "Usage: inf_prep_sql db ?name? sql"
	}

	set c [catch {
		set stmt [w__inf_prep_sql $db $text]
	} msg]

	if {$c == 0} {
		set ::INF_STMT($stmt,text) $text
		set ::INF_STMT($stmt,name) [string trim $name]
		set ::INF_STMT($stmt,conn) $db
		return $stmt
	}

	inf_err default inf_prep_sql $db $text
}


#
# ----------------------------------------------------------------------------
# inf_exec_stmt with timing and logging possibilities
# ----------------------------------------------------------------------------
#
proc inf_exec_stmt args {

	if { [lindex $args 0] == "-inc-type" } {

		set flag [lindex $args 0]
		set stmt [lindex $args 1]
		set args [lrange $args 2 e]

	} else {

		set flag ""
		set stmt [lindex $args 0]
		set args [lrange $args 1 e]

	}

	set c [catch {
		set t0 [OT_MicroTime -micro]
		set res [eval w__inf_exec_stmt $flag $stmt $args]
		set t1 [OT_MicroTime -micro]
	} msg]

	if {$c == 0} {
		if {$::INF_LOG_TIME} {
			set tt [expr {$t1-$t0}]
			set sn $::INF_STMT($stmt,name)
			OT_LogWrite 3 "DB::EXEC $sn [format %0.4f $tt]"
			if {$tt > $::INF_LOG_LONGQ} {
				OT_LogWrite 3 "DB::LONGQ $sn [format %0.4f $tt]"
				set rc [inf_get_row_count $stmt]
				eval {inf_log default LONGQ [inf_stmt_txt $stmt] $rc} $args
			}
		}
		if {$::INF_LOG_SQL} {
			set rc [inf_get_row_count $stmt]
			set qt [inf_stmt_txt $stmt]
			eval {inf_log default inf_exec_stmt $qt $rc} $args
		}
		return $res
	}

	set db  $::INF_STMT($stmt,conn)
	set txt [inf_stmt_txt $stmt]

	eval {inf_err default inf_exec_stmt $db $txt} $args
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
		catch {unset ::INF_STMT($stmt,text)}
		catch {unset ::INF_STMT($stmt,name)}
		catch {unset ::INF_STMT($stmt,conn)}
		return
	}

	inf_err default inf_close_stmt $::INF_STMT($stmt,conn) "<close stmt>"
}


#
# ----------------------------------------------------------------------------
# inf_begin_tran
# ----------------------------------------------------------------------------
#
proc inf_begin_tran {db} {

	set c [catch {
		w__inf_begin_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err default inf_begin_tran $db "<begin work>"
}


#
# ----------------------------------------------------------------------------
# inf_commit_tran
# ----------------------------------------------------------------------------
#
proc inf_commit_tran {db} {

	set c [catch {
		w__inf_commit_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err default inf_commit_tran $db "<commit work>"
}


#
# ----------------------------------------------------------------------------
# inf_rollback_tran
# ----------------------------------------------------------------------------
#
proc inf_rollback_tran {db} {

	set c [catch {
		w__inf_rollback_tran $db
	} msg]

	if {$c == 0} {
		return
	}

	inf_err default inf_rollback_tran $db "<rollback work>"
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
proc inf_log {log proc qry_txt rowcount args} {

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
		OT_LogWrite $log 2 "$proc : [string range $l $s_range end]"
	}
	if {$rowcount >= 0} {
		OT_LogWrite $log 2 "$proc : rowcount = $rowcount"
	}
}


#
# ----------------------------------------------------------------------------
# Handle an error. We log the query and the error numbers, then perform
# a sequence of actions which depends on the error number
# ----------------------------------------------------------------------------
#
proc inf_err {log proc db qry_txt args} {

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
	OT_LogWrite $log 2 [string repeat * 80]
	OT_LogWrite $log 2 "$proc : error ($e_str) $e_msg"
	eval {inf_log $log $proc $qry_txt -1} $args
	OT_LogWrite $log 2 [string repeat * 80]


	#
	# Now perform the error-dependent actions
	#
	if {![info exists ::INF_ERR_ACTION($e_num)]} {
		set err_actions [list inf_err_fatal]
	} else {
		set err_actions $::INF_ERR_ACTION($e_num)
	}

	foreach a $err_actions {
		switch -- $a {
			inf_err_fatal {
				OT_LogWrite $log 1 "$proc : fatal error ($e_str) ==> asRestart"
			}
			default {
				# nothing to add
			}
		}
		catch {
			eval {$a} {$db}
		}
	}

	err_bind $e_msg

	error $e_msg
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
	asRestart
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
	set sql_version {
		select DBINFO('version','os')
		from   systables
		where  tabid=1
	}

	set stmt [inf_prep_sql $db $sql_version]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	switch -- [db_get_coln $res 0 0] {
		F {
			set 64bit 1
		}
		T -
		U -
		H {
			set 64bit 0
		}
	}

	db_close $res

	set informix_version {
		select DBINFO('version','major')
		from systables
		where tabid=1
	}

	set stmt [inf_prep_sql $db $informix_version]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set inf_version [db_get_coln $res 0 0]
	db_close $res


	if {$64bit && $inf_version < 9} {
		set extra_where {
			and l.ownerpad = x.addresspad
			and x.ownerpad = r.addresspad
		}
	} else {
		set extra_where { }
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

	OT_LogWrite 3 "LOCKDIAG: $h1"
	OT_LogWrite 3 "LOCKDIAG: $h2"

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

		OT_LogWrite 3 "LOCKDIAG: $line"
	}

	db_close $res_l
}
