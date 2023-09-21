# $Id: memo.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# ==============================================================
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::MEMO {

asSetAct ADMIN::MEMO::GoMemoList [namespace code go_memo_list]
asSetAct ADMIN::MEMO::GoMemo     [namespace code go_memo]
asSetAct ADMIN::MEMO::DoMemo     [namespace code do_memo]

#
# ----------------------------------------------------------------------------
# Go to memo list
# ----------------------------------------------------------------------------
#
proc go_memo_list args {

	global DB

	set sql [subst {
		select
			request_type,
			disporder
		from
			tMemoRequest
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumMemo [db_get_nrows $res]

	tpBindTcl MemoRequest					sb_res_data $res memo_idx request_type
	tpBindTcl MemoDisporder					sb_res_data $res memo_idx disporder

	asPlayFile -nocache memo_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to memo add/update
# ----------------------------------------------------------------------------
#
proc go_memo args {

	global DB

	set memo_code [reqGetArg MemoCode]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString HearAboutCode $memo_code

	if {$memo_code == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get Memo information
		#
		set sql [subst {
			select
				request_type,
				disporder
			from
				tMemoRequest
			where
				request_type = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $memo_code]
		inf_close_stmt $stmt

		tpBindString MemoCode			[db_get_col $res 0 request_type]
		tpBindString MemoDisporder		[db_get_col $res 0 disporder]

		db_close $res
	}

	asPlayFile -nocache memo.html
}


#
# ----------------------------------------------------------------------------
# Do memo insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_memo args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_memo_list
		return
	}

	if {$act == "MemoAdd"} {
		do_memo_add
	} elseif {$act == "MemoMod"} {
		do_memo_upd
	} elseif {$act == "MemoDel"} {
		do_memo_del
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_memo_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsMemo(
			p_adminuser = ?,
			p_request_type = ?,
			p_disporder = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set disp_order [reqGetArg MemoDisporder]
	if {$disp_order == ""} {
		set disp_order 0
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MemoCode]\
			$disp_order]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}
	go_memo
}

proc do_memo_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdMemo(
			p_adminuser = ?,
			p_request_type = ?,
			p_disporder = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set disp_order [reqGetArg MemoDisporder]
	if {$disp_order == ""} {
		set disp_order 0
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MemoCode]\
			$disp_order]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_memo
		return
	}
	go_memo_list
}

proc do_memo_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelMemo(
			p_adminuser = ?,
			p_request_type = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MemoCode]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_memo
		return
	}

	go_memo_list
}

}
