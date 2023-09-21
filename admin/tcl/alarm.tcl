# ==============================================================
# $Id: alarm.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::ALARM {

asSetAct ADMIN::ALARM::GoAlarms [namespace code go_alarms]
asSetAct ADMIN::ALARM::GoSearchAlarms [namespace code go_search_alarms]
asSetAct ADMIN::ALARM::DoAlarms [namespace code do_alarms]


#
# ----------------------------------------------------------------------------
# Alarm details
# ----------------------------------------------------------------------------
#
proc go_alarms args {

	global DB

	set sql1 {
		select
			a.event_id,
			a.event_time,
			a.event_type,
			a.event_ref_id,
			a.event_desc,
			a.closed_time,
			u.username,
			m.name detail_1,
			e.desc detail_2,
			e.ev_type_id id_1,
			e.ev_id      id_2,
			"Mkt" sort,
			m.status
		from
			tSysEvent a,
			tEvMkt    m,
			tEv       e,
			outer tAdminUser u
		where
			a.event_type   = 'MS' and
			a.event_ref_id = m.ev_mkt_id and
			a.user_id      = u.user_id and
			m.ev_id        = e.ev_id
		}

	set sql2 {

		select
			a.event_id,
			a.event_time,
			a.event_type,
			a.event_ref_id,
			a.event_desc,
			a.closed_time,
			u.username,
			s.desc detail_1,
			e.desc detail_2,
			0 id_1,
			s.ev_mkt_id id_2,
			"Oc" sort,
			s.status
		from
			tSysEvent a,
			tEv       e,
			tEvOc     s,
			outer tAdminUser u
		where
			a.event_type   = 'SS' and
			a.event_ref_id = s.ev_oc_id and
			a.user_id      = u.user_id and
			s.ev_id        = e.ev_id
	}

	#Add the where clauses
	set where [list]
	set startDateFilter [reqGetArg deleted_start_date]
	set endDateFilter   [reqGetArg deleted_end_date]
	set deletionUser    [reqGetArg deleted_by]

	if {$startDateFilter != ""} {
		lappend where "a.closed_time > '$startDateFilter 00:00:00' "
	}
	if {$endDateFilter   != ""} {
		lappend where "a.closed_time < extend('$endDateFilter 00:00:00',year to second) + (interval(1) day to day)"
	}
	if {$deletionUser    != "" } {
		regsub -all "'" $deletionUser "''" deletionUser
		if {$deletionUser    != "0"} {
		  lappend where "a.user_id = $deletionUser"
		} else {
		  lappend where "a.user_id is not null"
		}
	}

	#If no clauses have been added then add the clause to show current msgs
	if {[llength $where] == 0} {
		lappend where "a.closed_time is null"
		tpSetVar filtered 0
	} else {
		tpSetVar filtered 1
	}

	#Form the sql
	set sql $sql1
	foreach clause $where {
		set sql [subst {
			$sql
			and $clause
		}]
	}
	set sql [subst {
		$sql
		union all
		$sql2
	}]
	foreach clause $where {
		set sql [subst {
			$sql
			and $clause
		}]
	}
	set sql [subst {
		$sql
		order by
		1 desc;
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar alarm_rows [set n_rows [db_get_nrows $res]]

	global RES

	for {set i 0} {$i < $n_rows} {incr i} {

		set a [db_get_col $res $i sort]

		set RES($i,sort) $a

		if {$a == "Mkt"} {
			set RES($i,TypeId) [db_get_col $res $i id_1]
			set RES($i,EvId)   [db_get_col $res $i id_2]
			set RES($i,MktId)  [db_get_col $res $i event_ref_id]
		} else {
			set RES($i,MktId)  [db_get_col $res $i id_2]
			set RES($i,OcId)   [db_get_col $res $i event_ref_id]
		}

		set RES($i,Closed)   [db_get_col $res $i closed_time]
		set RES($i,ClosedBy) [db_get_col $res $i username]
		set RES($i,AlarmId)  [db_get_col $res $i event_id]
		set RES($i,Date)     [db_get_col $res $i event_time]
		set RES($i,Desc)     [db_get_col $res $i event_desc]
		set RES($i,Detail1)  [db_get_col $res $i detail_1]
		set RES($i,Detail2)  [db_get_col $res $i detail_2]
		set RES($i,Status)   [db_get_col $res $i status]

	}

	db_close $res

	tpBindVar AlarmId  RES AlarmId  alarm_idx
	tpBindVar Date     RES Date     alarm_idx
	tpBindVar Sort     RES Sort     alarm_idx
	tpBindVar Desc     RES Desc     alarm_idx
	tpBindVar Detail1  RES Detail1  alarm_idx
	tpBindVar Detail2  RES Detail2  alarm_idx
	tpBindVar TypeId   RES TypeId   alarm_idx
	tpBindVar EvId     RES EvId     alarm_idx
	tpBindVar MktId    RES MktId    alarm_idx
	tpBindVar OcId     RES OcId     alarm_idx
	tpBindVar Closed   RES Closed   alarm_idx
	tpBindVar ClosedBy RES ClosedBy alarm_idx
	tpBindVar Status   RES Status   alarm_idx

	asPlayFile -nocache alarms.html

	catch {unset RES}
}

proc go_search_alarms {} {

	global OPERATORS DB

	#
	# Retrieve the operator usernames for filter screen
	#
	set op_sql {
		select
			user_id,
			username
		from
			tAdminUser
		order by
			username
	}

	set op_stmt [inf_prep_sql $DB $op_sql]
	set op_res  [inf_exec_stmt $op_stmt]

	inf_close_stmt $op_stmt

	#Store the operator info
	for {set i 0} {$i < [db_get_nrows $op_res]} {incr i} {
		set OPERATORS($i,username)  [db_get_col $op_res $i username]
		set OPERATORS($i,user_id)   [db_get_col $op_res $i user_id]
	}
	tpSetVar  NumOperators [db_get_nrows $op_res]
	tpBindVar operator    OPERATORS username  op_idx
	tpBindVar operator_id OPERATORS user_id   op_idx

	asPlayFile -nocache alarm_search.html

	db_close $op_res
}

proc do_alarms args {

	global DB USERID

	if {![op_allowed ClearAlarm]} {
		err_bind "You don't have permission to delete alarms"
		go_alarms
		return
	}

	set sql [subst {
			 update
				 tSysEvent
			 set
				 closed_time = current,
				 user_id     = ?
			 where
				 event_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	set c [catch {
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			set a [reqGetNthName $i]
			if {[string range $a 0 4] == "ALRM_"} {
				set res [inf_exec_stmt $stmt $USERID [string range $a 5 end]]
				catch {db_close $res}
			}
		}
	} msg]

	if {$c == 0} {
		inf_commit_tran $DB
	} else {
		catch {inf_rollback_tran $DB}
		err_bind $msg
	}

	inf_close_stmt $stmt

	go_alarms
}

}
