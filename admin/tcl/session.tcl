# ==============================================================
# $Id: session.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SESSION {

	asSetAct ADMIN::SESSION::DoSessQry       [namespace code do_sess_qry]
	asSetAct ADMIN::SESSION::DoUpdSession    [namespace code do_upd_sess]

	asSetAct ADMIN::SESSION::GoSess          [namespace code go_sess]
	asSetAct ADMIN::SESSION::DoSess          [namespace code do_sess]
	asSetAct ADMIN::SESSION::GoSessionSearch {sb_null_bind session_search.html}
}

proc ADMIN::SESSION::do_sess_qry {} {

	global DB

	set where   [list]
	set orderby "s.start_time desc"

	# Region to get the username details from the session_search.html.
	set is_case_sensitive [reqGetArg FILT_UpperName] 
	set username [reqGetArg FILT_Username] 

	# get the session id details from the html page.
	set session_id [reqGetArg FILT_Sessionid]
	
	# build the where clause for searching based on user name.
	if {$username != ""} {
		if {$is_case_sensitive == "N"} {
			lappend where "UPPER (c.username) = UPPER ('$username')"
		} else {
			lappend where "c.username = '$username'"
		}
	}

	# adding the session_id search to the where clause.
	if {$session_id != ""} {
		lappend where "s.session_id = $session_id"
	}

	
	if {[string length [set cust_id [reqGetArg FILT_CustId]]] > 0} {
		lappend where "s.cust_id = $cust_id"

		tpBindString FILT_CustId $cust_id
	}

	if {[string length [set status [reqGetArg FILT_Status]]] > 0} {
		lappend where "s.status = '$status'"

		tpBindString FILT_Status $status
	}

	if {[string length [set source [reqGetArg FILT_Source]]] > 0} {
		lappend where "s.source = '$source'"

		tpBindString FILT_Source $source
	}

	if {[string length [set start_op [reqGetArg FILT_StartOp]]] > 0} {
		set start [reqGetArg FILT_StartTime]
		lappend where "s.start_time $start_op '$start'"

		tpBindString FILT_StartTime $start
		tpBindString FILT_StartOp   $start_op
	}

	if {[string length [set end_op [reqGetArg FILT_EndOp]]] > 0} {
		set end [reqGetArg FILT_EndTime]
		lappend where "s.end_time $end_op '$end'"

		tpBindString FILT_EndTime $end
		tpBindString FILT_EndOp   $end_op
	}


	if {[llength $where] > 0} {
		set where "and [join $where { and }]"
	}
	
	set sql  [subst {
		select first 101
			   s.session_id,
			   c.username,
			   s.cust_id,
			   u.username admin_user,
			   s.start_time,
			   s.end_time,
			   s.session_type,
			   s.source,
			   s.status
		from
			   tCustSession  s,
			   tCustomer     c,
			   tAdminUser    u,
			   outer (tCustSessCancel  n)
		where s.cust_id = c.cust_id
		  and s.user_id = u.user_id
		  and s.session_id = n.session_id
		  $where
		order by
			   $orderby
	}]
	
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] > 100} {
		tpSetVar NumSess 100
		tpBindString Warning "More than 100 rows would be returned"

	} else {
		tpSetVar NumSess [db_get_nrows $res]
	}

	if {[db_get_nrows $res] > 0} {
		tpBindTcl CustId        sb_res_data $res sess_idx cust_id
		tpBindTcl SessionId     sb_res_data $res sess_idx session_id
		tpBindTcl Username      sb_res_data $res sess_idx username
		tpBindTcl AdminUser     sb_res_data $res sess_idx admin_user
		tpBindTcl SessStart     sb_res_data $res sess_idx start_time
		tpBindTcl SessEnd       sb_res_data $res sess_idx end_time
		tpBindTcl Source        sb_res_data $res sess_idx source
		tpBindTcl Status        sb_res_data $res sess_idx status
	}

	asPlayFile -nocache session_list.html

	db_close $res
}


proc ADMIN::SESSION::do_upd_sess {} {

	terminate_session [reqGetArg SessionId]

	do_sess_qry
}

proc ADMIN::SESSION::terminate_session sess_id {

	global DB

	if { [OT_CfgGetTrue IGF_PLAYER_PROTECTION] } {

		set stmt [inf_prep_sql $DB {

			execute procedure pCgSessionEnd (
				p_session_id =  ?,
				p_end_reason = 'S'
			);

		}]

	} else {

		set stmt [inf_prep_sql $DB {

			execute procedure pSessionEnd (
				p_session_id =  ?,
				p_end_reason = 'S'
			);

		}]

	}

	inf_exec_stmt  $stmt $sess_id
	inf_close_stmt $stmt

}

proc ADMIN::SESSION::go_sess {} {

	global DB

	set sess_id [reqGetArg sess_id]
	tpSetVar sess_id $sess_id


	# first rebind the request data
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		tpBindString [reqGetNthName $i] [reqGetNthVal $i]
	}

	set sql {
		select
			c.username,
			s.cust_id,
			a.username admin_user,
			s.term_code,
			s.start_time,
			s.end_time,
			s.status,
			s.session_type,
			s.aff_id,
			aff.aff_name,
			t.desc channel_name,
			s.ipaddr,
			s.start_balance,
			ac.ccy_code
		from
			tcustsession s,
			tchannel t,
			tadminuser a,
			tcustomer c,
			outer (taffiliate aff),
			tacct ac
		where t.channel_id = s.source
		  and s.user_id    = a.user_id
		  and s.cust_id    = c.cust_id
		  and aff.aff_id   = s.aff_id
		  and ac.cust_id   = s.cust_id
		  and s.session_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $sess_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $rs] {
		tpBindString $f [db_get_col $rs 0 $f]
	}

	db_close $rs

	asPlayFile -nocache session.html
}

proc ADMIN::SESSION::do_sess {} {

	switch -- [reqGetArg SubmitName] {

		"Terminate" {
			terminate_session [reqGetArg sess_id]
			go_sess
			return
		}
	}
}
