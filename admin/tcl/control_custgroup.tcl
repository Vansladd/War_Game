# ==============================================================
# $Id: control_custgroup.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CONTROL {

asSetAct ADMIN::CONTROL::GoControlCustGrp [namespace code go_control_custgrp]
asSetAct ADMIN::CONTROL::DoControlCustGrp [namespace code do_control_custgrp]

#
# ----------------------------------------------------------------------------
# Go to the control per customer group page
#
# This query assumes that tControlCustGrp has been properly filled for
# every channel.
# ----------------------------------------------------------------------------
#
proc go_control_custgrp args {
	global DB CONTROL
	
	if {![op_allowed AsyncPerCustGrp]} {
		err_bind "You do not have permissions to view this page"
		asPlayFile error_rpt.html
		return
	}
	
	#
	# Get channel data
	#
	
	set sql {
		select
			c.cust_code,
			c.desc,
			async_bet,
			async_timeout,
			async_off_ir_timeout,
			async_off_pre_timeout,
			bir_async_bet
		from
			tControlCustGrp p,
			tCustCode c
		where
			p.cust_code = c.cust_code
	}
	
	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st]
	set nrows [db_get_nrows $rs]
	
	for {set i 0} {$i < $nrows} {incr i} {
		foreach col [db_get_colnames $rs] {
			set CONTROL($i,$col) [db_get_col $rs $i $col]
		}
	}
	
	tpSetVar NumCustGrp $nrows
	foreach col [db_get_colnames $rs] {
		tpBindVar ctrl_$col CONTROL $col ctrl_idx
	}
	
	db_close $rs
	
	asPlayFile -nocache control_custgrp.html
	
	catch {unset CONTROL}
}


#
# ----------------------------------------------------------------------------
# Update control per customer group information
# ----------------------------------------------------------------------------
#
proc do_control_custgrp args {

	global DB
	
	if {![op_allowed AsyncPerCustGrp]} {
		err_bind "You do not have permissions to view this page"
		asPlayFile error_rpt.html
		return
	}
	
	if {[reqGetArg SubmitName] == "GoAudit"} {
		return [ADMIN::AUDIT::go_audit]
	}

	set sql {
		execute procedure pUpdControlCustGrp (
			p_async_bet        = ?,
			p_bir_async_bet    = ?,
			p_async_timeout    = ?,
			p_async_off_ir_timeout  = ?,
			p_async_off_pre_timeout = ?,
			p_cust_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	
	inf_begin_tran $DB
	
	if {[catch {
		foreach c [reqGetArgs groups] {
			inf_exec_stmt $stmt \
				[reqGetArg ${c}_async_bet]\
				[reqGetArg ${c}_bir_async_bet]\
				[reqGetArg ${c}_async_timeout]\
				[reqGetArg ${c}_async_off_ir_timeout]\
				[reqGetArg ${c}_async_off_pre_timeout]\
				$c
		}
		
	} msg]} {
		inf_rollback_tran $DB
		
		err_bind "Error updating settings: $msg"
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt
	go_control_custgrp
}

}
