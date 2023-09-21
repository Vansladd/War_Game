#-----------------------------------------------------------------------------
#
# $Id: casino_queue.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# $Name: RC_Training $
#
# Casino Queue
#
# Copyright (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# -----------------------------------------------------------------------------
namespace eval ADMIN::CASINOQUEUE {


asSetAct ADMIN::CASINOQUEUE::Query   [namespace code query]
asSetAct ADMIN::CASINOQUEUE::Requery [namespace code requery]
asSetAct ADMIN::CASINOQUEUE::Go      [namespace code go]
asSetAct ADMIN::CASINOQUEUE::Requeue [namespace code requeue]
asSetAct ADMIN::CASINOQUEUE::Delete  [namespace code delete]


variable TYPES
variable STATUSES

set TYPES(R) Registration
set TYPES(U) Update
set TYPES(P) Password
set TYPES(N) Username

set STATUSES(G) Good
set STATUSES(B) Bad
set STATUSES(U) Unknown
set STATUSES(P) Queued

# play the query/filter options page
proc query {} {

	if {![op_allowed ViewCasinoQueue]} {
		error {permissions denied}
	}

	# set some defaults
	foreach checkbox {
		type_R
		type_U
		type_B
		status_B
		status_U
	} {
		tpBindString [string toupper $checkbox] checked
	}

	tpBindString date_high "[clock format [clock scan today] -format {%Y-%m-%d}]"
	tpBindString date_low  "[clock format [clock scan yesterday] -format {%Y-%m-%d}]"

	bind_synced_systems

	asPlayFile -nocache casino_queue_query.html
}

# re-play the query/filter options page maintaining existing parameters
proc requery {} {

	if {![op_allowed ViewCasinoQueue]} {
		error {permissions denied}
	}

	set n [reqGetNumVals]
	for {set i 0} {$i < $n} {incr i} {
		tpBindString [string toupper [reqGetNthName $i]] [reqGetNthVal $i]
	}

	foreach checkbox {
		type_R
		type_U
		type_B
		status_G
		status_B
		status_U
		show_requeued
		show_deleted
	} {
		if {[reqGetArg $checkbox] != ""} {
			tpBindString [string toupper $checkbox] checked
		}
	}

	if {[reqGetArg type_R] == ""
	 && [reqGetArg type_U] == ""
	 && [reqGetArg type_B] == ""} {
		# all off means all on
		foreach type {R U B} {
			tpBindString TYPE_${type} checked
		}
	}

	if {[reqGetArg status_G] == ""
	 && [reqGetArg status_B] == ""
	 && [reqGetArg status_U] == ""} {
		# all off means all on
		foreach status {G B U} {
			tpBindString STATUS_${status} checked
		}
	}

	bind_synced_systems

	asPlayFile -nocache casino_queue_query.html
}

# show the queue according to input filter parameters
proc go args {
	global DB

	if {![op_allowed ViewCasinoQueue]} {
		error {permissions denied}
	}

	variable REQ
	catch {unset REQ}

	set n [reqGetNumVals]
	for {set i 0} {$i < $n} {incr i} {
		set REQ([reqGetNthName $i]) [reqGetNthVal $i]
	}

	foreach {n v} $args {
		set REQ($n) $v
	}

	# rebind args for paging etc
	tpBindTcl REQ_ARG eval tpBufWrite \[tpGetVar req_arg\]
	tpBindTcl REQ_VAL eval tpBufWrite \$::ADMIN::CASINOQUEUE::REQ(\[tpGetVar req_arg\])

	foreach idx [array names REQ -regexp {type_[RUPN]}] {
		regexp {type_([RUPN])} $idx -> type
		lappend types $type
	}

	foreach idx [array names REQ -regexp {status_[UBG]}] {
		regexp {status_([UBG])} $idx -> status
		lappend statuses $status
	}

	set date_filter {}
	if  {
		   ([info exists REQ(date_low)]  && [string length $REQ(date_low)])
		&& ([info exists REQ(date_high)] && [string length $REQ(date_high)])
	} {
		set date_filter "and [mk_between_clause q.cr_date date $REQ(date_low) $REQ(date_high)]"
	}

	# Please note this query only supports the case where ref_id links to
	# tCustomer.cust_id (ie types of R, U, B). Further extension would be
	# required to support use of other types
	#
	set sql [subst {
		-- queued items that dont have a response
		select
			q.sync_id,
			q.cr_date,
			q.type,
			-1 as response_id,
			extend(current, year to second) as response_date,
			'N' as requeued,
			'N' as deleted,
			'P' as status,
			'' as code,
			h.name as system,
			c.username,
			c.cust_id,
			'' as admin_user
		from
			tCustomer c,
			tXSysHost h,
			tXSysSyncQueue q
		where
			q.ref_id = c.cust_id
		and q.processed = 'N'
		and h.synchronise = 'Y'
		and h.system_id = q.system_id
		and not exists (
			select 1 from tXSysSyncResponse r
			where r.sync_id = q.sync_id
			and r.system_id = h.system_id
			and r.requeued = 'N'
		)
		[expr {[info exists REQ(system)] && $REQ(system) != "" ? "
			and h.name = '$REQ(system)'
		" : ""}]
		[expr {[info exists REQ(cust_id)] && $REQ(cust_id) != "" ? "
			and c.cust_id = '$REQ(cust_id)'
		" : ""}]
		[expr {[info exists REQ(username)] && $REQ(username) != "" ? "
			and c.username = '$REQ(username)'
		" : ""}]
		$date_filter
		union
		-- queued items that already have a response
		select
			q.sync_id,
			q.cr_date,
			q.type,
			r.response_id,
			r.cr_date,
			r.requeued,
			r.deleted,
			r.status,
			r.code,
			h.name as system,
			c.username,
			c.cust_id,
			u.username
		from
			tCustomer c,
			tXSysHost h,
			tXSysSyncQueue q,
			tXSysSyncResponse r,
			outer tAdminUser u
		where
			q.ref_id = c.cust_id
		and r.sync_id = q.sync_id
		and r.system_id = h.system_id
		and h.system_id = q.system_id
		and u.user_id = r.user_id
		and h.system_id = q.system_id
		and h.synchronise = 'Y'
		[expr {[info exists REQ(system)] && $REQ(system) != "" ? "
			and h.name = '$REQ(system)'
		" : ""}]
		[expr {[info exists REQ(cust_id)] && $REQ(cust_id) != "" ? "
			and c.cust_id = '$REQ(cust_id)'
		" : ""}]
		[expr {[info exists REQ(username)] && $REQ(username) != "" ? "
			and c.username = '$REQ(username)'
		" : ""}]
		$date_filter
		[expr {[info exists types] ? "
			and q.type in ('[join $types ',']')
		" : ""}]
		[expr {[info exists statuses] ? "
			and r.status in ('[join $statuses ',']')
		" : ""}]
		[expr {![info exists REQ(show_requeued)] ? "
			and r.requeued = 'N'
		" : ""}]
		[expr {![info exists REQ(show_deleted)] ? "
			and r.deleted = 'N'
		" : ""}]
		order by 1 desc, 5 desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	set columns [db_get_colnames $rs]
	foreach col $columns {
		tpBindTcl [string toupper $col] eval tpBufWrite \[db_get_col $rs \[tpGetVar row_idx\] $col\]
	}
	tpBindTcl TYPE eval tpBufWrite \$::ADMIN::CASINOQUEUE::TYPES(\[db_get_col $rs \[tpGetVar row_idx\] type\])
	tpBindTcl STATUS eval tpBufWrite \$::ADMIN::CASINOQUEUE::STATUSES(\[db_get_col $rs \[tpGetVar row_idx\] status\])
	tpSetVar nrows [db_get_nrows $rs]

	set REQ(search_args) [array names REQ -regexp {(?!^action$)}]

	asPlayFile -nocache casino_queue.html

	db_close $rs
}


# mark a response as requeued and the corresponding queue row as not processed
# so that the casino queue sends the request again and inserts another response
proc requeue args {
	global DB USERID

	if {![op_allowed ModifyCasinoQueue]} {
		error {permissions denied}
	}

	set response_id [reqGetArg response_id]

	if {![op_allowed ModifyCasinoQueue]} {
		error {permission denied}
	}

	inf_begin_tran $DB

	set sql {
		update
			tXSysSyncResponse
		set
			requeued = 'Y',
			user_id = ?
		where
			response_id = ?
		and requeued != 'Y'
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERID $response_id

	if {[inf_get_row_count $stmt] == 0} {
		inf_rollback_tran $DB
		error {no rows updated for the response_id passed to ADMIN::CASINOQUEUE::Resend}
	}

	inf_close_stmt $stmt

	set sql {
		update
			tXSysSyncQueue
		set
			processed = 'N'
		where
			sync_id = (
				select sync_id from tXSysSyncResponse
				where response_id = ?
			)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $response_id
	inf_close_stmt $stmt

	inf_commit_tran $DB

	go
}


# mark a bad/unknown response as deleted
proc delete args {
	global DB USERID

	if {![op_allowed ModifyCasinoQueue]} {
		error {permissions denied}
	}

	set response_id [reqGetArg response_id]

	set sql {
		update
			tXSysSyncResponse
		set
			deleted = 'Y',
			user_id = ?
		where
			response_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERID $response_id
	inf_close_stmt $stmt

	go
}


# Binds up systems with sync_types
proc bind_synced_systems {} {

	global DB
	variable SYNCED_SYS

	set sql {
		select
			name
		from
			tXsysHost
		where
			     synchronise = 'Y'
			and  sync_types <> ''
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set SYNCED_SYS($i,name) [db_get_col $rs $i name]
	}

	db_close $rs

	set cns [namespace current]

	# Bind for template player
	tpSetVar   num_synced_sys $nrows
	tpBindVar  sys_name ${cns}::SYNCED_SYS name sys_idx

}


}
