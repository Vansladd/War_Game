# ==============================================================
# $Id: tb_daily_msg.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2004 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TB_DMSG {

asSetAct ADMIN::TB_DMSG::GoDailyMsg          [namespace code go_daily_msg]
asSetAct ADMIN::TB_DMSG::DoDailyMsg          [namespace code do_daily_msg]
asSetAct ADMIN::TB_DMSG::GoDailyMsgDetails   [namespace code go_daily_msg_details]
asSetAct ADMIN::TB_DMSG::GoDailyMsgAdd       [namespace code go_daily_msg_add]
asSetAct ADMIN::TB_DMSG::GoDailyMsgList      [namespace code go_daily_msg_list]
asSetAct ADMIN::TB_DMSG::DoDailyMsgList      [namespace code do_daily_msg_list]

#
# ----------------------------------------------------------------------------
# Displays list of Daily Messages
# ----------------------------------------------------------------------------
#
proc go_daily_msg args {

	global DB DATA 

	if {![op_allowed ViewDailyMsg]} {
		err_bind "You don't have permission to view  Daily Trading Messages"
		asPlayFile -nocache daily_msg_list.html
		return
	}

	set sql [subst {
		select
			m.msg_id,
			m.msg_text,
			m.valid_from,
			m.valid_to,
			m.status,
			d.dept_name,
			l.loc_name
		from
			tDailyMsg m,
			outer tAdminDept d,
			outer tAdminLoc l
		where
			m.dept_code = d.dept_code
		and m.loc_code = l.loc_code
		order by
			m.valid_to
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumDailyMsg     [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set DATA($r,msg_id)     [db_get_col $res $r msg_id]
		set DATA($r,msg_txt)    [db_get_col $res $r msg_text]
		set DATA($r,valid_from) [db_get_col $res $r valid_from]
		set DATA($r,valid_to)   [db_get_col $res $r valid_to]
		set DATA($r,status)     [db_get_col $res $r status]
		set DATA($r,dept_name)  [db_get_col $res $r dept_name]
		set DATA($r,loc_name)   [db_get_col $res $r loc_name]
	}

	tpBindVar MsgId           DATA  msg_id dailymsg_idx
	tpBindVar MsgTxt          DATA  msg_txt dailymsg_idx
	tpBindVar ValidFrom       DATA  valid_from dailymsg_idx
	tpBindVar ValidTo         DATA  valid_to dailymsg_idx
	tpBindVar Status          DATA  status dailymsg_idx
	tpBindVar DeptName        DATA  dept_name dailymsg_idx
	tpBindVar LocName         DATA  loc_name dailymsg_idx

	asPlayFile -nocache daily_msg_list.html

	db_close $res
}

#
# ----------------------------------------------------------------------------
# Bring back details of given call cancel
# ----------------------------------------------------------------------------
#
proc do_daily_msg args {

	global DB

	if {![op_allowed EditDailyMsg]} {
		err_bind "You don't have permission to edit Daily Trading Messages"
		asPlayFile -nocache daily_msg_list.html
		return
	}

	set submit [reqGetArg SubmitName]
	set msg_id [reqGetArg MessageId]

	if {$submit == "DailyMsgMod"} {
		set msg_txt [reqGetArg MessageText]
	 	set valid_from [reqGetArg ValidFrom]
	 	set valid_to [reqGetArg ValidTo]
	 	set loc_code [reqGetArg locn]
	 	set dept_code [reqGetArg dept]
	 	set status [reqGetArg Status]

		set sql [subst {
			update
			     tDailyMsg
			set
				msg_text = ?,
				valid_from = ?,
				valid_to = ?,
				status = ?,
				dept_code = ?,
				loc_code = ?
			where
			     msg_id = ?
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $msg_txt $valid_from $valid_to \
			$status $dept_code $loc_code $msg_id]
		inf_close_stmt $stmt
		go_daily_msg
		db_close $res
		return
	} elseif {$submit == "DailyMsgDel"} {
		set sql [subst {
			delete from
			    tDailyMsg
			where
			    msg_id = ?
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $msg_id]
		inf_close_stmt $stmt
		go_daily_msg
		db_close $res
		return
	} elseif {$submit == "DailyMsgAdd"} {
		do_daily_msg_add
		return
	} elseif {$submit == "Back"} {
		go_daily_msg
		return
	}
}


#
# ----------------------------------------------------------------------------
# Bring back details of given Daily Message
# ----------------------------------------------------------------------------
#
proc go_daily_msg_details args {

	global DB DATA

	if {![op_allowed ViewDailyMsg]} {
		err_bind "You don't have permission to view Daily Trading Messages"
		asPlayFile -nocache daily_msg.html
		return
	}
	set msg_id [reqGetArg MsgId]
	set sql [subst {
		select
			m.msg_id,
			m.msg_text,
			m.valid_from,
			m.valid_to,
			m.status,
			d.dept_name,
			l.loc_name
		from
			tDailyMsg m,
			outer tAdminDept d,
			outer tAdminLoc l
		where
			m.msg_id = ?
		and m.dept_code = d.dept_code
		and m.loc_code = l.loc_code
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $msg_id]
	inf_close_stmt $stmt

	set loc_name [db_get_col $res 0 loc_name]
	set dept_name [db_get_col $res 0 dept_name]

	tpBindString MsgId           [db_get_col $res 0 msg_id]
	tpBindString MsgTxt          [db_get_col $res 0 msg_text]
	tpBindString ValidFrom       [db_get_col $res 0 valid_from]
	tpBindString ValidTo         [db_get_col $res 0 valid_to]
	tpBindString Status          [db_get_col $res 0 status]
	tpBindString DeptName        $dept_name
	tpBindString LocName         $loc_name

	get_locn_data $loc_name
	get_dept_data $dept_name

	asPlayFile -nocache daily_msg.html
	db_close $res
}

#
# ----------------------------------------------------------------------------
# Adds Daily Message
# ----------------------------------------------------------------------------
#
proc do_daily_msg_add args {

	global DB USERNAME

	if {![op_allowed EditDailyMsg]} {
		err_bind "You don't have permission to edit Daily Trading Messages"
		asPlayFile -nocache daily_msg.html
		return
	}
	set sql [subst {
		insert into tDailyMsg (
			msg_text,
			valid_from,
			valid_to,
			status,
			dept_code,
			loc_code ) 
		values (?,?,?,?,?,?)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg MessageText]\
		 	[reqGetArg ValidFrom]\
		 	[reqGetArg ValidTo]\
			[reqGetArg Status]\
		 	[reqGetArg dept]\
		 	[reqGetArg locn]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	go_daily_msg
	db_close $res
}


#
# ----------------------------------------------------------------------------
# Called from daily_msg_list.html
# add a new message 
# ----------------------------------------------------------------------------
#
proc go_daily_msg_add args {
	tpSetVar opAdd 1

	if {![op_allowed EditDailyMsg]} {
		err_bind "You don't have permission to edit Daily Trading Messages"
		asPlayFile -nocache daily_msg.html
		return
	}
	set now [clock format [clock seconds] -format %Y-%m-%d]
	tpBindString ValidFrom "$now 00:00:00"
	tpBindString ValidTo "$now 23:59:59"
	get_locn_data ""
	get_dept_data ""
	asPlayFile -nocache daily_msg.html
}

#
# ----------------------------------------------------------------------------
# Called from menu_bar.html
# display the query page for reporting on tDailyMsgOp
# ----------------------------------------------------------------------------
#
proc go_daily_msg_list args {

	global DB DATA

	if {![op_allowed ViewDailyMsg]} {
		err_bind "You don't have permission to view Daily Trading Messages"
		asPlayFile -nocache daily_msg_op_query.html
		return
	}
	#Get a list of the operators
	set sql [subst {
		select
			username,
			user_id
		from
			tAdminUser
		where
			status='A'
		order by
			username
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumUsers     [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,username) ""
	set DATA(0,user_id) ""
	set DATA(0,user_sel) SELECTED

	for {set r 0} {$r < $n_rows} {incr r} {
		set rr [expr {$r+1}]
		set DATA($rr,username)     [db_get_col $res $r username]
		set DATA($rr,user_id)      [db_get_col $res $r user_id]
		set DATA($rr,user_sel)     ""
	}

	tpBindVar UserName          DATA  username   dailymsg_idx
	tpBindVar UserId            DATA  user_id    dailymsg_idx
	tpBindVar UserSel           DATA  user_sel    dailymsg_idx
	db_close $res

	set sql [subst {
		select
			dept_code,
			dept_name
		from
			tAdminDept
		order by
			dept_name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumDept     [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,dept_name) ""
	set DATA(0,dept_code) ""
	set DATA(0,dept_sel) SELECTED

	for {set r 0} {$r < $n_rows} {incr r} {
		set rr [expr {$r+1}]
		set DATA($rr,dept_name)     [db_get_col $res $r dept_name]
		set DATA($rr,dept_code)     [db_get_col $res $r dept_code]
		set DATA($rr,dept_sel)     ""
	}

	tpBindVar DeptName          DATA  dept_name   dept_idx
	tpBindVar DeptCode          DATA  dept_code   dept_idx
	tpBindVar DeptSel           DATA  dept_sel    dept_idx
	db_close $res

	set sql [subst {
		select
			loc_code,
			loc_name
		from
			tAdminLoc
		order by
			loc_name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumLoc     [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,loc_name) ""
	set DATA(0,loc_code) ""
	set DATA(0,loc_sel) SELECTED

	for {set r 0} {$r < $n_rows} {incr r} {
		set rr [expr {$r+1}]
		set DATA($rr,loc_name)     [db_get_col $res $r loc_name]
		set DATA($rr,loc_code)     [db_get_col $res $r loc_code]
		set DATA($rr,loc_sel)     ""
	}

	tpBindVar LocName          DATA  loc_name   loc_idx
	tpBindVar LocCode          DATA  loc_code   loc_idx
	tpBindVar LocSel           DATA  loc_sel    loc_idx

	asPlayFile -nocache daily_msg_op_query.html
	db_close $res
}

#
# ----------------------------------------------------------------------------
# Called from daily_msg_op_query.html
# display the page for reporting on tDailyMsgOp
# ----------------------------------------------------------------------------
#
proc do_daily_msg_list args {

	global DB DATA

	get_locn_data ""
	get_dept_data ""

	if {![op_allowed ViewDailyMsg]} {
		err_bind "You don't have permission to view Daily Trading Messages"
		asPlayFile -nocache daily_msg_op.html
		return
	}

	set sub_name [reqGetArg SubmitName]

	set where [list]

	set user_id  [reqGetArg user_id]
	if {[string length $user_id] > 0} {
		lappend where "u.user_id = $user_id"
	}
	set date_from  [reqGetArg date_from]
	if {[string length $date_from] > 0} {
		lappend where "m.valid_from > '$date_from'"
	}
	set date_to  [reqGetArg  date_to]
	if {[string length $date_to] > 0} {
		lappend where "m.valid_to < '$date_to'"
	}
	set accepted [reqGetArg accepted]
	if {[string length $accepted] > 0} {
		lappend where "o.accepted = '$accepted'"
	}
	set status [reqGetArg status]
	if {[string length $status] > 0} {
		lappend where "m.status = '$status'"
	}
	set msg_text   [reqGetArg  msg_text]
	if {[string length $msg_text] > 0} {
		lappend where "m.msg_text like \"${msg_text}%\""
	}
	set dept_code  [reqGetArg dept_code]
	if {[string length $dept_code] > 0} {
		lappend where "m.dept_code = '$dept_code'"
	}
	set loc_code   [reqGetArg loc_code]
	if {[string length $loc_code] > 0} {
		lappend where "m.loc_code = '$loc_code'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	#limit this with a first 1000 ....
	set sql [subst {
		select
			first 1000
			o.msg_id,
			o.oper_id,
			o.cr_date,
			o.accepted,
			ma.msg_text,
			u.username
		from
			tDailyMsgOp o,
			tDailyMsg m,
			tAdminUser u,
			tDailyMsg_aud ma
		where
			o.oper_id = u.user_id
		and	o.msg_id = m.msg_id
		and ma.aud_order in (
			select max(aud_order)
			from tDailyMsg_aud aud
			where
				aud.msg_id=m.msg_id
			and o.cr_date > aud.valid_from
			and o.cr_date < aud.valid_to
		)
		and o.cr_date > ma.aud_time
			$where
		order by
			o.oper_id,
			o.cr_date
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumDailyMsgOp     [set n_rows [db_get_nrows $res]]

	if {$n_rows > 1000} {
		tpSetVar MaxDisplayMsg 1
	} else {
		tpSetVar MaxDisplayMsg 0
	}

	for {set r 0} {$r < $n_rows} {incr r} {
		set DATA($r,msg_id)     [db_get_col $res $r msg_id]
		set DATA($r,msg_txt)    [db_get_col $res $r msg_text]
		set DATA($r,date)       [db_get_col $res $r cr_date]
		set DATA($r,accepted)   [db_get_col $res $r accepted]
		set DATA($r,oper_id)    [db_get_col $res $r oper_id]
		set DATA($r,username)   [db_get_col $res $r username]
	}

	tpBindVar MsgId           DATA  msg_id   dailymsg_idx
	tpBindVar MsgTxt          DATA  msg_txt  dailymsg_idx
	tpBindVar Date            DATA  date     dailymsg_idx
	tpBindVar Accepted        DATA  accepted dailymsg_idx
	tpBindVar OpId            DATA  oper_id  dailymsg_idx
	tpBindVar Username        DATA  username dailymsg_idx
	
	asPlayFile -nocache daily_msg_op.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Get the list of locations for the drop down
# ----------------------------------------------------------------------------
#
proc get_locn_data {loc_name} {

	global DATA DB
	
	set locn_sql {
		select
			loc_code,
			loc_name
		from 
			tAdminLoc
		order by
			loc_code
	}

	set stmt [inf_prep_sql $DB $locn_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumLocn [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,loc_code) ""
	set DATA(0,loc_name) ""
	set DATA(0,loc_sel) SELECTED

	for {set r 0} {$r < $n_rows} {incr r} {
		set rr [expr {$r+1}]
		set DATA($rr,loc_code) [db_get_col $res $r loc_code]
		set DATA($rr,loc_name) [db_get_col $res $r loc_name]
		if {$loc_name == $DATA($rr,loc_name)} {
			set DATA($rr,loc_sel) SELECTED
		} else {
			set DATA($rr,loc_sel) ""
		}
	}

	tpBindVar LocCode DATA loc_code locn_idx
	tpBindVar LocName DATA loc_name locn_idx
	tpBindVar LocSel DATA loc_sel locn_idx

	db_close $res
}

#
# ----------------------------------------------------------------------------
# Get the list of departments for the drop down
# ----------------------------------------------------------------------------
#
proc get_dept_data {dept_name} {

	global DATA DB

	set dept_sql {
		select
			dept_code,
			dept_name
		from 
			tAdminDept
		order by
			dept_code
	}

	set stmt [inf_prep_sql $DB $dept_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumDept [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,dept_code) ""
	set DATA(0,dept_name) ""
	set DATA(0,dept_sel) SELECTED

	for {set r 0} {$r < $n_rows} {incr r} {
		set rr [expr {$r+1}]
		set DATA($rr,dept_code) [db_get_col $res $r dept_code]
		set DATA($rr,dept_name) [db_get_col $res $r dept_name]
		if {$dept_name == $DATA($rr,dept_name)} {
			set DATA($rr,dept_sel) SELECTED
		} else {
			set DATA($rr,dept_sel) ""
		}
	}

	tpBindVar DeptCode DATA dept_code dept_idx
	tpBindVar DeptName DATA dept_name dept_idx
	tpBindVar DeptSel DATA dept_sel dept_idx
	db_close $res

}
}
