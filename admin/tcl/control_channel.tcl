# ==============================================================
# $Id: control_channel.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CONTROL {

asSetAct ADMIN::CONTROL::GoControlChannel [namespace code go_control_channel]
asSetAct ADMIN::CONTROL::DoControlChannel [namespace code do_control_channel]

#
# ----------------------------------------------------------------------------
# Go to the control per channel page
#
# This query assumes that tControlChannel has been properly filled for
# every channel.
# ----------------------------------------------------------------------------
#
proc go_control_channel args {
	global DB CONTROL
	
	if {![op_allowed AsyncPerChannel]} {
		err_bind "You do not have permissions to view this page"
		asPlayFile error_rpt.html
		return
	}
	
	#
	# Get channel data
	#
	
	set sql {
		select
			c.channel_id,
			c.desc,
			c.async_betting,
			async_timeout,
			async_off_ir_timeout,
			async_off_pre_timeout,
			bir_async_bet,
	
			async_rule_stk1,
			async_rule_stk2,
			async_rule_liab,
			async_max_payout,
			async_auto_place
		from
			tControlChannel p,
			tChannel c
		where
			p.channel_id = c.channel_id
	}
	
	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st]
	set nrows [db_get_nrows $rs]
	
	for {set i 0} {$i < $nrows} {incr i} {
		foreach col [db_get_colnames $rs] {
			set CONTROL($i,$col) [db_get_col $rs $i $col]
		}
	}
	
	tpSetVar NumChannels $nrows
	foreach col [db_get_colnames $rs] {
		tpBindVar ctrl_$col CONTROL $col ctrl_idx
	}
	
	db_close $rs
	
	asPlayFile -nocache control_channel.html
	
	catch {unset CONTROL}
}


#
# ----------------------------------------------------------------------------
# Update control per channel information
# ----------------------------------------------------------------------------
#
proc do_control_channel args {

	global DB
	
	if {![op_allowed AsyncPerChannel]} {
		err_bind "You do not have permissions to view this page"
		asPlayFile error_rpt.html
		return
	}
	
	if {[reqGetArg SubmitName] == "GoAudit"} {
		return [ADMIN::AUDIT::go_audit]
	}

	set sql {
		execute procedure pUpdControlChannel(
			p_bir_async_bet    = ?,
			p_async_timeout    = ?,
			p_async_off_ir_timeout  = ?,
			p_async_off_pre_timeout = ?,
			p_async_rule_stk1  = ?,
			p_async_rule_stk2  = ?,
			p_async_rule_liab  = ?,
			p_async_max_payout = ?,
			p_async_auto_place = ?,
			p_channel_id = ?
		)
	}
	
	set channel_sql {
		update
			tChannel
		set
			async_betting = ?
		where
			channel_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set channel_stmt [inf_prep_sql $DB $channel_sql]
	
	inf_begin_tran $DB
	
	if {[catch {
		foreach c [reqGetArgs channels] {
			inf_exec_stmt $stmt \
				[reqGetArg ${c}_bir_async_bet]\
				[reqGetArg ${c}_async_timeout]\
				[reqGetArg ${c}_async_off_ir_timeout]\
				[reqGetArg ${c}_async_off_pre_timeout]\
				[reqGetArg ${c}_async_rule_stk1]\
				[reqGetArg ${c}_async_rule_stk2]\
				[reqGetArg ${c}_async_rule_liab]\
				[reqGetArg ${c}_async_max_payout]\
				[reqGetArg ${c}_async_auto_place]\
				$c
				
			# Async Bet setting is going to be kept in tChannel for now
			inf_exec_stmt $channel_stmt \
				[reqGetArg ${c}_async_bet]\
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
	inf_close_stmt $channel_stmt
	go_control_channel
}

}
