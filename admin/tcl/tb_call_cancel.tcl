# ==============================================================
# $Id: tb_call_cancel.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TB_CALL {

asSetAct ADMIN::TB_CALL::GoCallCancel          [namespace code go_call_cancel]
asSetAct ADMIN::TB_CALL::DoCallCancel          [namespace code do_call_cancel]
asSetAct ADMIN::TB_CALL::GoCallCancelDetails   [namespace code go_call_cancel_details]
asSetAct ADMIN::TB_CALL::GoCallCancelAdd       [namespace code go_call_cancel_add]

#
# ----------------------------------------------------------------------------
# Displays list of cancel call descriptions
# ----------------------------------------------------------------------------
#
proc go_call_cancel args {

	global DB CALL

	if {![op_allowed ManageCallCancel]} {
		err_bind "You don't have permission to set call cancel descriptions"
		asPlayFile -nocache call_cancel_list.html
		return
	}

	set sql [subst {
		select
			cancel_code,
			cancel_desc,
			disporder,
			status
		from
			tCallCancel
		order by
			disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumCallCancel    [db_get_nrows $res]

	tpBindTcl CancelCode      sb_res_data $res callcancel_idx cancel_code
	tpBindTcl CancelDesc      sb_res_data $res callcancel_idx cancel_desc
	tpBindTcl CancelStatus    sb_res_data $res callcancel_idx status
	tpBindTcl CancelDisporder sb_res_data $res callcancel_idx disporder

	asPlayFile -nocache call_cancel_list.html

	db_close $res
}

#
# ----------------------------------------------------------------------------
# Bring back details of given call cancel
# ----------------------------------------------------------------------------
#
proc do_call_cancel args {

	global DB

	if {![op_allowed ManageCallCancel]} {
		err_bind "You don't have permission to set call cancel descriptions"
		asPlayFile -nocache call_cancel_list.html
		return
	}

	set submit [reqGetArg SubmitName]
	set cancel [reqGetArg CancelCode]
	if {$submit == "CancelMod"} {
		set sql [subst {
			update
				 tCallCancel
			set
				 cancel_desc = ?,
				 status      = ?,
				 disporder   = ?
			where
				 cancel_code = ?
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [reqGetArg Description] [reqGetArg CancelStatus] [reqGetArg CancelDisporder] [reqGetArg CancelCode]]
		inf_close_stmt $stmt
		go_call_cancel
		return
	} elseif {$submit == "CancelDel"} {
		set sql [subst {
			delete from
				tCallCancel
			where
				cancel_code = ?
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [reqGetArg CancelCode]]
		inf_close_stmt $stmt
		go_call_cancel
		return
	} elseif {$submit == "CancelAdd"} {
		do_call_cancel_add
		return
	} elseif {$submit == "Back"} {
		go_call_cancel
		return
	}
}


#
# ----------------------------------------------------------------------------
# Bring back details of given call cancel
# ----------------------------------------------------------------------------
#
proc go_call_cancel_details args {

	global DB

	set cancel [reqGetArg Cancel]
	set sql [subst {
		select
			cancel_code,
			cancel_desc,
			disporder,
			status
		from
			tCallCancel
		where
			cancel_code = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cancel]
	inf_close_stmt $stmt

	tpBindString CancelCode      [db_get_col $res 0 cancel_code]
	tpBindString CancelDesc      [db_get_col $res 0 cancel_desc]
	tpBindString CancelStatus    [db_get_col $res 0 status]
	tpBindString CancelDisporder [db_get_col $res 0 disporder]

	db_close $res

	asPlayFile -nocache call_cancel.html
}

#
# ----------------------------------------------------------------------------
# Adds Call Cancel entry
# ----------------------------------------------------------------------------
#
proc do_call_cancel_add args {

	global DB USERNAME

	# create pInsCallCancel.sql
	set sql [subst {
		execute procedure pInsCallCancel(
			p_adminuser = ?,
			p_cancel_code = ?,
			p_cancel_desc = ?,
			p_status = ?,
			p_disporder = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CancelCode]\
			[reqGetArg Description]\
			[reqGetArg CancelStatus]\
			[reqGetArg CancelDisporder]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_call_cancel
}



#
# ----------------------------------------------------------------------------
# Display call cancel addition
# ----------------------------------------------------------------------------
#
proc go_call_cancel_add args {

	tpSetVar opAdd 1

	asPlayFile -nocache call_cancel.html
}

}
