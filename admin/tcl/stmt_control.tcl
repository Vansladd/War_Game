# $Id: stmt_control.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C)2006 Orbis Technology Ltd. All rights reserved.
#
# Control of statements via control table.
#
# Configuration:
#   FUNC_MENU_STMT_CONTROL = 0
#
# Permission:
#   ManageStmtControl


namespace eval ADMIN::STMT_CONTROL {

	asSetAct ADMIN::STMT_CONTROL::go_stmt_controls [namespace code go_stmt_controls]
	asSetAct ADMIN::STMT_CONTROL::go_stmt_control  [namespace code go_stmt_control]
	asSetAct ADMIN::STMT_CONTROL::do_stmt_control  [namespace code do_stmt_control]
	asSetAct ADMIN::STMT_CONTROL::go_stmt_verify   [namespace code go_stmt_verify]
	asSetAct ADMIN::STMT_CONTROL::go_verify_stmt   [namespace code go_verify_stmt]
}


# Show a list of all the statments controls.
#
proc ADMIN::STMT_CONTROL::go_stmt_controls {} {

	global STMT_CONTROLS

	array unset STMT_CONTROLS

	if {![op_allowed ManageStmtControl]} {
		error "You do not have permission to do this"
	}

	set sql {
		select
			*
		from
			tStmtControl
		order by
			acct_type
	}

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach n $colnames {
			set STMT_CONTROLS($r,$n) [db_get_col $rs $r $n]
		}
	}

	db_close $rs

	tpSetVar nrows $nrows

	foreach n $colnames {
		tpBindVar $n STMT_CONTROLS $n idx
	}

	set stmtRun {
		select
			stmt_run_id,
			cr_date,
			stmt_verified
		from
			tStmtRun
		where
			status = 'C'
		order by
			cr_date desc
	}

	set stmtTwo [inf_prep_sql $::DB $stmtRun]
	set res [inf_exec_stmt $stmtTwo]
	inf_close_stmt $stmtTwo

	set numRun [db_get_nrows $res]

	for {set r 0} {$r < $numRun} {incr r} {
		set STMT_CONTROLS($r,stmt_run_id)   [db_get_col $res $r stmt_run_id]
		set STMT_CONTROLS($r,cr_date)       [db_get_col $res $r cr_date]
		set STMT_CONTROLS($r,stmt_verified) [db_get_col $res $r stmt_verified]
	}

	tpBindVar stmtRunId    STMT_CONTROLS stmt_run_id   stmt_idx
	tpBindVar stmtDate     STMT_CONTROLS cr_date       stmt_idx
	tpBindVar stmtVerified STMT_CONTROLS stmt_verified stmt_idx
	tpSetVar  NumRun $numRun
	db_close $res

	asPlayFile -nocache stmt_controls.html
}


# Show one of the statments controls.
#
proc ADMIN::STMT_CONTROL::go_stmt_control {} {

	if {![op_allowed ManageStmtControl]} {
		error "You do not have permission to do this"
	}

	set acct_type [reqGetArg acct_type]

	if {$acct_type != ""} {
		set sql {select * from tStmtControl where acct_type = ?}
		set stmt [inf_prep_sql $::DB $sql]
		set rs [inf_exec_stmt $stmt $acct_type]
		inf_close_stmt $stmt

		set colnames [db_get_colnames $rs]
		
		foreach n $colnames {
				tpBindString $n [db_get_col $rs 0 $n]
			}

		db_close $rs
	} else {
		tpBindString sched_date [clock format [clock scan today] -format "%Y-%m-%d"]
	}

	asPlayFile -nocache stmt_control.html
}


# Update or insert a statment control.
#
proc ADMIN::STMT_CONTROL::do_stmt_control {} {

	if {![op_allowed ManageStmtControl]} {
		error "You do not have permission to do this"
	}

	set acct_type     [reqGetArg acct_type]
	set sched_date    [reqGetArg sched_date]
	set deferred_date [reqGetArg deferred_date]
	set freq_unit     [reqGetArg freq_unit]
	set freq_amt      [reqGetArg freq_amt]
	set submit        [reqGetArg submit]

	switch $submit {
		"Insert" {
			set sql {insert into tStmtControl(acct_type, sched_date,
				deferred_date, freq_unit, freq_amt) values (? ,?, ?, ?, ?)}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $acct_type $sched_date $deferred_date \
				$freq_unit $freq_amt
			inf_close_stmt $stmt
			msg_bind "Statement control inserted"
		}
		"Update" {
			set sql {update tStmtControl set sched_date = ?,
				deferred_date = ?, freq_unit = ?, freq_amt = ? where
				acct_type = ?}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $sched_date $deferred_date \
				$freq_unit $freq_amt $acct_type
			inf_close_stmt $stmt
			msg_bind "Statement control updated"

		}
		default {
			error "Unknown submit"
		}
	}

	go_stmt_control
}


#  go_stmt_verify
#  Display the Statement Run Verification Page
#
proc ADMIN::STMT_CONTROL::go_stmt_verify {} {
	set stmtRunId [reqGetArg runId]
	set sql {
		select
			*
		from
			tStmtRun
		where
			stmt_run_id = ?
	}

	set stmtRun [inf_prep_sql $::DB $sql]
	set res [inf_exec_stmt $stmtRun $stmtRunId]
	inf_close_stmt $stmtRun

	set verified [db_get_col $res 0 stmt_verified]
	tpSetVar Verified $verified

	if {$verified == "Y"} {
		tpBindString Verified_Date [db_get_col $res 0 stmt_ver_date]
	} else {
		tpBindString stmtRunId $stmtRunId
	}

	tpBindString Total_Value   [db_get_col $res 0 tot_value]
	tpBindString Cheques       [db_get_col $res 0 chq_no]
	tpBindString Cheque_Value  [db_get_col $res 0 chq_value]
	tpBindString Date          [db_get_col $res 0 cr_date]
	tpBindString Cheque_Min    [db_get_col $res 0 min_chq]
	tpBindString Cheque_Max    [db_get_col $res 0 max_chq]
	tpBindString Statements [expr [db_get_col $res 0 num_dep] \
		+ [db_get_col $res 0 num_cdt] + [db_get_col $res 0 num_dbt]]


	set numRun [db_get_nrows $res]

	asPlayFile -nocache stmt_verify.html
}



# verify_stmt
# Verify the stralfors statement response matches our info
#
proc ADMIN::STMT_CONTROL::go_verify_stmt {} {
	set stmtRunId [reqGetArg runId]

	set sql {
		update
			tStmtRun
		set
			stmt_verified = 'Y',
			stmt_ver_date = current
		where
			stmt_run_id = ?
	}

	set stmtRun [inf_prep_sql $::DB $sql]
	set res [inf_exec_stmt $stmtRun $stmtRunId]
	inf_close_stmt $stmtRun

	go_stmt_controls
}