# ==============================================================
# $Id: man_adjustments.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::ADJ {

asSetAct ADMIN::ADJ::GoAdjQry     [namespace code go_adj_query]
asSetAct ADMIN::ADJ::do_adj_query [namespace code do_adj_query]
asSetAct ADMIN::ADJ::do_adj_auth  [namespace code do_adj_auth]
asSetAct ADMIN::ADJ::GoManAdj     [namespace code go_man_adj]
asSetAct ADMIN::ADJ::DoManAdj     [namespace code do_man_adj]

#
# ----------------------------------------------------------------------------
# Generate customer selection criteria
# ----------------------------------------------------------------------------
#
proc go_adj_query args {

	global DB

	#
	# Manual adjustment types
	#
	set sql [subst {
		select
			type,
			desc
		from
			tManAdjType
	}]

	set stmt   [inf_prep_sql $DB $sql]
	set res_at [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumAdustments [db_get_nrows $res_at]

	tpBindTcl adj_type      sb_res_data $res_at adj_idx type
	tpBindTcl adj_type_desc sb_res_data $res_at adj_idx desc


	# Get admin users for the drop down list
	# Only include suspended ones if checkbox ticked
	set op_susp [reqGetArg op_susp]
	if {$op_susp == "Y"} {
		set status ""
	} else {
		set status "where status = 'A'"
	}

	set sql2 [subst {
		select
			username
		from
			tAdminUser
		$status
		order by
			username
	}]

	set stmt2 [inf_prep_sql $DB $sql2]
	set res2  [inf_exec_stmt $stmt2]

	inf_close_stmt $stmt2

	tpSetVar NumOperators [db_get_nrows $res2]
	tpBindTcl operator sb_res_data $res2 op_idx username
	tpSetVar OpSusp $op_susp


	#
	# Get list of manual adjustment types and subtypes for dropdowns
	#
	global MAN_ADJ_SUBTYPES
	set sql {
		select
			t.type,
			t.desc as typedesc,
			s.subtype,
			s.desc
		from
			tManAdjType t,
			outer tManAdjSubType s
		where
			t.type = s.type and
			t.status = 'A'
		order by t.type
	}
	set stmt [inf_prep_sql $DB $sql]
	set res_madj_subtypes [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set type ""
	set num_types -1
	set num_sub_types [db_get_nrows $res_madj_subtypes]

	for {set i 0} {$i < $num_sub_types} {incr i} {

		set type_i [db_get_col $res_madj_subtypes $i type]
		if {$type_i != $type} {
			set type $type_i
			incr num_types
			set sub_type_num 0
			set MAN_ADJ_SUBTYPES($num_types,type_id)  $num_types
			set MAN_ADJ_SUBTYPES($num_types,type)     $type
			set MAN_ADJ_SUBTYPES($num_types,desc)     [db_get_col $res_madj_subtypes $i typedesc]
		}

		set MAN_ADJ_SUBTYPES($num_types,$sub_type_num,sub_type) [db_get_col $res_madj_subtypes $i subtype]
		set MAN_ADJ_SUBTYPES($num_types,$sub_type_num,desc)     [db_get_col $res_madj_subtypes $i desc]
		set MAN_ADJ_SUBTYPES($num_types,num_subtypes)           [incr sub_type_num]
	}

	tpSetVar NumManAdjTypes [incr num_types]

	tpBindVar ManAdjType       MAN_ADJ_SUBTYPES  type      madj_type_idx
	tpBindVar ManAdjDesc       MAN_ADJ_SUBTYPES  desc      madj_type_idx
	tpBindVar ManAdjSelc       MAN_ADJ_SUBTYPES  selected  madj_type_idx
	tpBindVar MadjSubType      MAN_ADJ_SUBTYPES  sub_type  madj_type_idx   madj_subtype_idx
	tpBindVar MadjSubTypeDesc  MAN_ADJ_SUBTYPES  desc      madj_type_idx   madj_subtype_idx
	tpBindVar MadjNumSubTypes  MAN_ADJ_SUBTYPES  num_subtypes      madj_type_idx


	asPlayFile -nocache adj_search.html

	db_close $res_at



}


#
# ----------------------------------------------------------------------------
# Manual adjustments search
# ----------------------------------------------------------------------------
#
proc do_adj_query args {

	global DB

	if {![op_allowed DoManAdjSearch]} {
		err_bind "You do not have permission to search manual adjustments"
		ADMIN::ADJ::go_adj_query
		return
	}


	set action [reqGetArg SubmitName]

	#
	# rebind most of the posted variables
	#
	foreach f {SR_username SR_upper_username SR_fname SR_lname SR_email \
			   SR_acct_no_exact SR_acct_no SR_date_1 SR_date_2 \
			   SR_date_range SR_adj_type SR_status SR_batch_ref_id \
			   SR_operator SR_auth_operator SR_post_operator \
			   SR_adj_subtype op_susp \
			   } {
		tpBindString $f [reqGetArg $f]
	}

	set where [list]
	set from ""
	set pc_join "outer tPmtCC pc"

	#
	# Customer fields
	#
	set SR_username       [reqGetArg SR_username]
	set SR_upper_username [reqGetArg SR_upper_username]
	if {[string length $SR_username] > 0} {
		if {$SR_upper_username == "Y"} {
			lappend where "[upper_q c.username] like [upper_q '${SR_username}%']"
		} else {
			lappend where "c.username like \"${SR_username}%\""
		}
	}

	set SR_fname [reqGetArg SR_fname]
	if {[string length $SR_fname] > 0} {
		lappend where "[upper_q r.fname] = [upper_q '$SR_fname']"
	}

	set SR_lname [reqGetArg SR_lname]
	if {[string length $SR_lname] > 0} {
		lappend where [get_indexed_sql_query $SR_lname lname]
	}

	set SR_email [reqGetArg SR_email]
	if {[string length $SR_email] > 0} {
		lappend where [get_indexed_sql_query "%$SR_email" email]
	}


	set SR_acct_no       [reqGetArg SR_acct_no]
	set SR_acct_no_exact [reqGetArg SR_acct_no_exact]
	if {[string length $SR_acct_no] > 0} {
		if {$SR_acct_no_exact == "Y"} {
			lappend where "c.acct_no = '$SR_acct_no'"
		} else {
			lappend where "c.acct_no like '$SR_acct_no%'"
		}
	}

	set SR_date_1     [reqGetArg SR_date_1]
	set SR_date_2     [reqGetArg SR_date_2]
	set SR_date_range [reqGetArg SR_date_range]

	if {$SR_date_range != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set SR_date_2 "$Y-$M-$D"
		if {$SR_date_range == "TD"} {
			set SR_date_1 "$Y-$M-$D"
		} elseif {$SR_date_range == "CM"} {
			set SR_date_1 "$Y-$M-01"
		} elseif {$SR_date_range == "YD"} {
			set SR_date_1 [date_days_ago $Y $M $D 1]
			set SR_date_2 $SR_date_1
		} elseif {$SR_date_range == "L3"} {
			set SR_date_1 [date_days_ago $Y $M $D 3]
		} elseif {$SR_date_range == "L7"} {
			set SR_date_1 [date_days_ago $Y $M $D 7]
		}
		append SR_date_1 " 00:00:00"
		append SR_date_2 " 23:59:59"
	}

	set SR_operator [reqGetArg SR_operator]
	if {$SR_operator != ""} {
		#operators may have apostrophe in name so using double quotes
		lappend where "u.username = \"$SR_operator\" and m.user_id = u.user_id"
		set from "$from, tAdminUser u"
	}

	set SR_auth_operator [reqGetArg SR_auth_operator]
	if {$SR_auth_operator != ""} {
		#operators may have apostrophe in name so using double quotes
		lappend where "u1.username = \"$SR_auth_operator\" and m.auth_by = u1.user_id"
		set from "$from, tAdminUser u1"
	}

	set SR_post_operator [reqGetArg SR_post_operator]
	if {$SR_post_operator != ""} {
		#operators may have apostrophe in name so using double quotes
		lappend where "u2.username = \"$SR_post_operator\" and m.post_by = u2.user_id"
		set from "$from, tAdminUser u2"
	}

	set SR_adj_type [reqGetArg SR_adj_type]
	if {[string length $SR_adj_type] > 0} {
		lappend where "m.type = '$SR_adj_type'"
	}

	set SR_adj_subtype [reqGetArg SR_adj_subtype]
	if {[string length $SR_adj_subtype] > 0} {
		lappend where "m.subtype = '$SR_adj_subtype'"

	}

	set SR_status [reqGetArg SR_status]
	if {[string length $SR_status] > 0} {
		lappend where "m.pending = '$SR_status'"
	}

	if {$SR_date_1 != ""} {
		lappend where "m.cr_date >= '$SR_date_1'"
	}
	if {$SR_date_2 != ""} {
		lappend where "m.cr_date <= '$SR_date_2'"
	}

	set SR_batch_ref_id [reqGetArg SR_batch_ref_id]
	if {$SR_batch_ref_id != ""} {
		lappend where "m.batch_ref_id = '$SR_batch_ref_id'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	#going to limit this to 1000 at a time otherwise the table
	#will not render in most browsers
	set sql [subst {
		select first 1000
			c.username,
			c.acct_no,
			c.cust_id,
			c.elite,
			a.acct_id,
			a.ccy_code,
			m.madj_id,
			m.cr_date,
			m.type,
			m.desc,
			m.amount,
			m.pending,
			m.ref_key,
			m.ref_id,
			mt.desc  as type_desc,
			mst.desc as subtype_desc,
			u3.username raised_by
		from
			tManAdj m,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tManAdjType mt,
			outer tManAdjSubType mst,
			outer tAdminUser u3
		    $from
		where
			m.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			mst.type  = m.type    and
			m.type    = mt.type   and
			m.subtype = mst.subtype and
			m.user_id = u3.user_id and
			a.owner   <> 'D'
			$where
		order by
			m.madj_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumAdjs [set NumAdjs [db_get_nrows $res]]

	if {$NumAdjs == 1000} {
		tpSetVar MaxDisplayAdj 1
	} else {
		tpSetVar MaxDisplayAdj 0
	}

	global DATA

	array set DATA [list]

	for {set r 0} {$r < $NumAdjs} {incr r} {
		set DATA($r,acct_no) [acct_no_enc  [db_get_col $res $r acct_no]]
		set DATA($r,elite)   [db_get_col $res $r elite]
		set DATA($r,ref_key) [db_get_col $res $r ref_key]
		set DATA($r,ref_id)  [db_get_col $res $r ref_id]
	}

	tpBindVar Elite   DATA elite   adj_idx
	tpBindVar RefKey  DATA ref_key adj_idx
	tpBindVar RefId   DATA ref_id  adj_idx

	tpBindTcl CustId      sb_res_data $res adj_idx cust_id
	tpBindTcl Username    sb_res_data $res adj_idx username
	tpBindTcl Date        sb_res_data $res adj_idx cr_date
	tpBindTcl CCYCode     sb_res_data $res adj_idx ccy_code
	tpBindTcl Amount      sb_res_data $res adj_idx amount
	tpBindTcl status      sb_res_data $res adj_idx pending
	tpBindTcl Desc        sb_res_data $res adj_idx desc
	tpBindTcl TypeDesc    sb_res_data $res adj_idx type_desc
	tpBindTcl SubTypeDesc sb_res_data $res adj_idx subtype_desc
	tpBindTcl madj_id     sb_res_data $res adj_idx madj_id
	tpBindTcl AcctNo      sb_res_data $res adj_idx acct_no
	tpBindTcl RaisedBy    sb_res_data $res adj_idx raised_by


	#
	# now calculate some totals
	#
	set sql [subst {
		select
			sum(m.amount) as amount,
			m.pending,
			a.ccy_code
		from
			tManAdj m,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tManAdjType mt
		    $from
		where
			m.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			r.cust_id = c.cust_id and
			m.type = mt.type
			$where
		group by
			3,2
	}]

	set stmt   [inf_prep_sql $DB $sql]
	set rs_sum [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs_sum]

	tpSetVar SUM_nrows $nrows
	tpBindTcl SUM_total sb_res_data $rs_sum s_idx amount
	tpBindTcl SUM_ccy   sb_res_data $rs_sum s_idx ccy_code
	tpBindTcl SUM_status sb_res_data $rs_sum s_idx pending

	asPlayFile -nocache adj_qry_list.html

	unset DATA

	db_close $res
}

#
# R - Authorise (check against user_id)
# A - Post (check against auth_by)
#
proc _has_processed_manadj {manj_id stage user_id} {
	set fn {ADMIN::ADJ::_get_prev_manj_users}
	global DB

	switch $stage {
		R { set where "and user_id = $user_id "}
		A { set where "and (auth_by = $user_id or user_id = $user_id)" }
	}

	set manj_users [subst {
		select
			count (*)
		from
		    tManAdj
		where
		    madj_id = ?
		$where
	}]
	set stmt [inf_prep_sql $DB $manj_users]
	set rs [inf_exec_stmt $stmt $manj_id]

	set count [db_get_coln $rs 0 0]
	db_close $rs

	if {$count > 0} {
		return 1
	} else {
		return 0
	}
}

#
# ----------------------------------------------------------------------------
# Manual adjustments auth / decline
# ----------------------------------------------------------------------------
#
proc do_adj_auth {} {

	global USERID DB USERNAME

	if {![OT_CfgGet FUNC_MANADJ_PERM_BY_TYPE 0]} {
		if {![op_allowed ManAdjAuth] && ![op_allowed ManAdjPost] && ![op_allowed ManAdjDecline]} {
			err_bind "You do not have permission to update manual adjustment status"
			rebind_request_data
			ADMIN::ADJ::do_adj_query
			return
		}
	}

	set mark_action [reqGetArg MarkAction]
	if {[reqGetArg SubmitName] == "UpdMarks"} {

		if {$mark_action == "A"} {
			tpBindString auth_check "checked"
		} elseif {$mark_action == "P"} {
			tpBindString post_check "checked"
		} elseif {$mark_action == "D"} {
			tpBindString decl_check "checked"
		}

		ADMIN::ADJ::do_adj_query
		return
	}

	switch [reqGetArg SubmitName] {
		"Authorise" {
			set levels [split [OT_CfgGet MAN_ADJ_AUTH_THRESHOLD_LEVELS] ","]
			set prefix "A"
		}
		"Post" {
			set levels [split [OT_CfgGet MAN_ADJ_POST_THRESHOLD_LEVELS] ","]
			set prefix "P"
		}
		"Decline" {
			set prefix "D"
		} default {
			set levels [list]
		}
	}

	set num_adjustments [reqGetArg NumAdjs]
	set auth_code    [reqGetArg auth_code]

	set output ""

	set details_sql [subst {
		select
		    m.amount,
		    a.ccy_code
		from
		    tManAdj m,
		    tAcct a
		where
		    m.acct_id = a.acct_id and
		    m.madj_id = ?
	}]
	set details_stmt [inf_prep_sql $DB $details_sql]

	set auth_sql [subst {
		execute procedure pAuthManAdj (p_adminuser = ?,
									   p_madj_id = ?,
									   p_pending = ?)
	}]
	set auth_stmt [inf_prep_sql $DB $auth_sql]

	for {set i 0} {$i < $num_adjustments} {incr i} {

		set madj_id    [reqGetArg "row_${i}"]

		if {[reqGetArg "${prefix}_${madj_id}"] == "Y"} {

			# Check the permission controls.
			switch -- [reqGetArg SubmitName] {
				"Authorise" {
					# if same as user_id then error.
					if {![op_allowed ManAdjRtoA]} {
						if {[_has_processed_manadj $madj_id "R" $USERID] == 1} {
							lappend output "Couldn't process Manual Adjustment, manj_id: $madj_id current user processed previous stage."
							continue
						}
					}
				}
				"Post" {
					# if same as auth_by then error.
					if {![op_allowed ManAdjAtoP]} {
						if {[_has_processed_manadj $madj_id "A" $USERID] == 1} {
							lappend output "Couldn't process Manual Adjustment, manj_id: $madj_id current user processed previous stage."
							continue
						}
					}
				}
			}

			if {[OT_CfgGet FUNC_MANADJ_PERM_BY_TYPE 0]} {
				# Check we have the correct permissions.
				if {[lsearch {A P} $prefix] > -1} {
					set rslt_perm [check_type_perm $prefix "" $madj_id]
					set succ      [lindex $rslt_perm 0]
					set msg       [lindex $rslt_perm 1]

					if {$succ != "OB_OK"} {
						lappend output "Couldn't process Manual Adjustment in correct permissions, manj_id: $madj_id"
						continue
					}
				}
			}

			# if we're authing or posting, check the admin user has the level required
			if {$prefix == "A" || $prefix == "P"} {
				if [catch {set rs [inf_exec_stmt $details_stmt $madj_id]} msg] {
					lappend output $msg
					continue
				}
				if {[db_get_nrows $rs] != 1} {
					lappend output "Couldn't get details for manual adjustment $madj_id"
					db_close $rs
					continue
				}
				set amount [db_get_col $rs 0 amount]
				set ccy_code [db_get_col $rs 0 ccy_code]
				db_close $rs

				if {[lsearch {A P} $prefix] > -1} {
					if {![ADMIN::CUST::check_threshold $amount $levels $ccy_code $prefix]} {
						lappend output "You don't have permission to
						[expr {$prefix == "A" ? "authorise" : "post"}] manual adjustments of $amount"
						continue
					}
				}
			}

			if [catch {set rs [inf_exec_stmt $auth_stmt $USERNAME $madj_id $prefix]} msg] {
				lappend output $msg
			}
			db_close $rs

			check_and_send_monitor_msg   $madj_id $prefix
		}
	}

	inf_close_stmt $auth_stmt
	inf_close_stmt $details_stmt

	if {$output != ""} {
		#need to do something to get to here
		rebind_request_data
		err_bind [join $output "<br>\n"]
	} else {
		if {[reqGetArg SubmitName] == "Authorise"} {
			  msg_bind "Payments successfully authorised"
		} elseif {[reqGetArg SubmitName] == "Post"} {
			  msg_bind "Payments successfully posted"
		} elseif {[reqGetArg SubmitName] == "Decline"} {
			  msg_bind "Payments successfully declined"
		}
	 }
	do_adj_query
}


# Check whether a
#
# params:
#   stage   - Stage in the ManAdj process, either:
#               - (R)aise
#               - (A)uthorise
#               - (P)ost
#   type    - Man Adj type.
#   manj_id - Man Adj id.
# returns, either:
#   OB_OK
#   OB_ERROR <<err_msg>>
#
proc check_type_perm {stage {type ""} {manj_id ""}} {
	global DB

	set fn {ADMIN::ADJ::check_type_perm}

	# Accepts either type or manj_id
	if {$type == {} && $manj_id == {}} {
		ob_log::write ERROR {${fn}: Neither type or madj_id specified!}
		return [list OB_ERROR "check_type_perm, internal error"]
	} elseif {$type != {} && $manj_id != {}} {
		ob_log::write ERROR {${fn}: Both type or madj_id specified! Must only specify one.}
		return [list OB_ERROR "check_type_perm, internal error"]
	}

	# If we have the manj_id go and grab the type.
	if {$manj_id != {}} {
		set sql {
			select
				type
			from
				tManAdj
			where
				madj_id = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $manj_id]
		inf_close_stmt $stmt

		if {![db_get_nrows $rs]} {
			return [list OB_ERROR "check_type_perm, internal error"]
		}

		set type [db_get_col $rs 0 type]
		db_close $rs
	}

	# Check
	if {$stage == "N"} {
		# We are doing an instant manual adjustment
		set action_name AdHocFundsXfer_${type}
	} else {
		set stage_str [string map {"R" "Raise" "A" "Auth" "P" "Post"} $stage]
		set action_name ManAdj${stage_str}_${type}
	}
	if {![op_allowed $action_name]} {
		set sql {
			select
				desc
			from
				tManAdjType
			where
				type = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $type]

		set type_desc [db_get_col $res 0 desc]

		db_close $res
		inf_close_stmt $stmt

		return [list OB_ERROR "You don't have permission to raise adjustments of type $type_desc"]
	}

	return [list OB_OK]
}



#
# ----------------------------------------------------------------------------
# Do a manual adjustment
# ----------------------------------------------------------------------------
#
proc do_cust_man_adj args {

	global DB USERNAME

	if {[OT_CfgGet FUNC_MANADJ_IMMEDIATE 0]} {
		set action_name AdHocFundsXfer
		set stage "N"
	} else {
		set action_name ManAdjRaise
		set stage "R"
	}

	if {[OT_CfgGet FUNC_MANADJ_PERM_BY_TYPE 0]} {
		# Do we have permissions to do this.
		foreach {succ msg} [check_type_perm $stage [reqGetArg Type]] {
			if {$succ != "OB_OK"} {
				rebind_request_data
				OT_LogWrite 1 $msg
				err_bind $msg
				return OB_ERROR
			}
		}
	} else {
		if {![op_allowed $action_name]} {
			rebind_request_data
			OT_LogWrite 1 "missing permission $action_name"
			err_bind "missing permission $action_name"
			return OB_ERROR
		}
	}

	if {[OT_CfgGet CUST_MAN_ADJ_NEED_DESC 0] == 1} {
		if {[reqGetArg Description] == ""} {
			rebind_request_data
			err_bind "You must fill in Description"
			return OB_ERROR
		}
	}

	if {[OT_CfgGet FUNC_MAN_ADJ_THRESHOLDS 0] == 1} {
		if {![ADMIN::CUST::check_threshold \
				  [reqGetArg Amount] \
				  [split [OT_CfgGet MAN_ADJ_RAISE_THRESHOLD_LEVELS] ","] \
				  [reqGetArg AcctCCY] \
				  "R" \
		]} {
			rebind_request_data
			OT_LogWrite 1 "Admin user doesn't have permission required for a manual adjustment of size [reqGetArg Amount]"
			err_bind "You don't have permission to raise manual adjustments this large"
			return OB_ERROR
		}
	}

	set last_adj_uid [get_cookie manadjuid]
	set current_uid [reqGetArg current_uid]

	if {$last_adj_uid == $current_uid} {
		rebind_request_data
		err_bind "You have already submitted this manual adjustment"
		return OB_ERROR
	}
	tpBufAddHdr "Set-Cookie" "manadjuid=$current_uid; path=/"

	# Grab the ManAdj link.
	set ref_key [reqGetArg ManAdj_ref_key]
	switch -- $ref_key {
		BET -
		POOL -
		XBET -
		PMT {
			# Grab the ref_id
			set ref_id [reqGetArg ManAdj_ref_id]
		}
		default {
			# Null both the ref_key and the ref_id.
			set ref_key {}
			set ref_id  {}
		}
	}

	# Is desc mandatory?
	set desc [reqGetArg Description]
	if {[OT_CfgGet MAN_ADJ_DESC_MANDATORY 0] && ![string length $desc]} {
		rebind_request_data
		OT_LogWrite 1 "Manual Adjustment description is mandatory."
		err_bind "Manual Adjustment description is mandatory."
		return OB_ERROR
	}


	set type    [reqGetArg Type]
	set subtype [reqGetArg SubType]

	# If we don't have a subtype check one is not required for the type.
	if {![string length $subtype]} {
		set sql {
			select
				count(*) as num_subtypes
			from
				tManAdjSubType
			where
				type = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $type]
		inf_close_stmt $stmt

		set num_subtypes [db_get_col $res 0 num_subtypes]

		db_close $res

		if {$num_subtypes > 0} {
			rebind_request_data
			OT_LogWrite 1 "Failed to create manual adjustment, subtype required."
			err_bind "Failed to create manual adjustment, subtype required."
			return OB_ERROR
		}
	}

	if {[set wtd [reqGetArg Withdrawable]] != "Y"} {
		set wtd "N"
	}

	set oper_notes [reqGetArg MadjOperNotes]

	if {![string length $oper_notes]} {
		rebind_request_data
		OT_LogWrite 1 "Operator notes cannot be blank."
		err_bind "You must enter a value in operator notes!"
		return OB_ERROR
	}

	# Should we check if there is sufficient ballance?
	if {[OT_CfgGet FUNC_MAN_ADJ_BALANCE_CHK 1]} {
		set check_balance "Y"
	} else {
		set check_balance "N"
	}


	set sql {
		execute procedure pCustFundsXfer(
			p_adminuser     = ?,
			p_type          = ?,
			p_subtype       = ?,
			p_desc          = ?,
			p_ccy_code      = ?,
			p_bm_acct_type  = ?,
			p_cust_id       = ?,
			p_amount        = ?,
			p_withdrawable  = ?,
			p_pending       = ?,
			p_ref_key       = ?,
			p_ref_id        = ?,
			p_oper_notes    = ?,
			p_check_balance = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	# all manual adjustments start in status (R)aised unless
	# we have FUNC_MANADJ_IMMEDIATE in which case they have
	# status N
	set c [catch {
		set res [inf_exec_stmt $stmt\
					 $USERNAME\
					 $type\
					 $subtype\
					 [reqGetArg Description]\
					 [reqGetArg AcctCCY]\
					 [reqGetArg BMAcctType]\
					 [reqGetArg CustId]\
					 [reqGetArg Amount]\
					 $wtd\
					 $stage\
					 $ref_key\
					 $ref_id\
					 $oper_notes\
					 $check_balance]
	} msg]

	if {$c} {
		rebind_request_data
		OT_LogWrite 1 "Failed to create manual adjustment: $msg"
		err_bind $msg
		return OB_ERROR
	}


	# get the serial id of the last transaction
	set man_adj_id [db_get_coln $res 0 0]

	catch {db_close $res}

	inf_close_stmt $stmt

	# Sending monitor message
	check_and_send_monitor_msg  $man_adj_id $stage

	# If emailing is enabled and the manadj is of a certain type
	# then queue the email
	if {$c == 0 && [OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1
			&& [lsearch [OT_CfgGet CUST_EMAIL_MANADJ_TYPES {}] [reqGetArg Type]] > -1} {
		set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC "queue_email"]
		set params [list PROMO_PAYMENT [reqGetArg CustId] E MADJ $man_adj_id]

		# send email to customer
		if {[catch {set res [eval $queue_email_func $params]} msg]} {
			OT_LogWrite 2 "Failed to queue change of details email, $msg"
		}
	}


	if {[OT_CfgGet FUNC_MANADJ_IMMEDIATE 0]} {
		# Success! display result.
		if {[string length $ref_key]} {
			msg_bind "Successfully performed manual adjustment with, ref_key:$ref_key , ref_id:$ref_id"
		} else {
			msg_bind "Successfully performed manual adjustment"
		}
	} else {
		# Success! display result.
		if {[string length $ref_key]} {
			msg_bind "Successfully submitted manual adjustment for approval with, ref_key:$ref_key , ref_id:$ref_id"
		} else {
			msg_bind "Successfully submitted manual adjustment for approval"
		}
	}

	return OB_OK
}


#
# ----------------------------------------------------------------------------
# View manual adjustments
# ----------------------------------------------------------------------------
#
proc go_view_cust_man_adj args {

	global DB USERNAME

	set where [list]

	set SR_date_1     [reqGetArg SR_date_1]
	set SR_date_2     [reqGetArg SR_date_2]
	set SR_date_range [reqGetArg SR_date_range]

	if {$SR_date_range != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set SR_date_2 "$Y-$M-$D"

		switch -- $SR_date_range {
			"TD" {
				set SR_date_1 "$Y-$M-$D"
			}
			"CM" {
				set SR_date_1 "$Y-$M-01"
			}
			"YD" {
				set SR_date_1 [date_days_ago $Y $M $D 1]
				set SR_date_2 $SR_date_1
			}
			"L3" {
				set SR_date_1 [date_days_ago $Y $M $D 3]
			}
			"L7" {
				set SR_date_1 [date_days_ago $Y $M $D 7]
			}
		}
		append SR_date_1 " 00:00:00"
		append SR_date_2 " 23:59:59"
	}

	if {$SR_date_1 != ""} {
		lappend where "j.cr_date >= '$SR_date_1'"
	}
	if {$SR_date_2 != ""} {
		lappend where "j.cr_date <= '$SR_date_2'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			j.jrnl_id,
			j.cr_date,
			j.amount,
			j.desc,
			a.username,
			tmt.desc as type,
			tmst.desc as subtype,
			b.bet_id
		from
			tJrnl j,
			tManAdjType tmt,
			outer tManAdjSubType tmst,
			tManAdj tm,
			outer tAdminUser a,
			outer tBet b
		where
			j.acct_id = ? and
			j.j_op_type = 'MAN' and
			j.j_op_ref_id = tm.madj_id and
			tm.type = tmt.type and
			tm.subtype = tmst.subtype and
			tm.type    = tmst.type and
			j.user_id = a.user_id and
			tm.desc like 'Resettlement Adjustment for bet: '||b.bet_id
			$where
		order by
			jrnl_id asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt [reqGetArg AcctId]]
	inf_close_stmt $stmt

	tpSetVar NumManAdjs [db_get_nrows $res]

	tpBindTcl Date     sb_res_data $res ma_idx cr_date
	tpBindTcl Amount   sb_res_data $res ma_idx amount
	tpBindTcl Desc     sb_res_data $res ma_idx desc
	tpBindTcl User     sb_res_data $res ma_idx username
	tpBindTcl Type     sb_res_data $res ma_idx type
	tpBindTcl SubType  sb_res_data $res ma_idx subtype
	tpBindTcl BetId    sb_res_data $res ma_idx bet_id


	tpBindString CustId [reqGetArg CustId]
	tpBindString AcctId [reqGetArg AcctId]

	asPlayFile -nocache cust_man_adj_hist.html

	db_close $res
}

proc go_man_adj {} {
	set ref_key  [reqGetArg ManAdj_ref_key]
	set ref_id   [reqGetArg ManAdj_ref_id]
	set group    [reqGetArg ManAdj_group]

	bind_man_adj "MAN_ADJ" $group $ref_key $ref_id

# 	tpBindString ManAdj_ref_key $ref_key
# 	tpBindString ManAdj_ref_id  $ref_id
# 	tpBindString ManAdj_group   $group

	asPlayFile -nocache man_adj.html
}

proc bind_man_adj {
	{ret "CUST"}
	{group "CUST"}
	{type ""}
	{id ""}
} {
	global DB MAN_ADJ_SUBTYPES

	set fn {ADMIN::CUST::go_man_adj}

	# Set the return location
	tpBindString ReturnLoc $ret
	tpBindString ManAdj_group    $group

	# Check if can pre-populate
	if {$type != "" && $id != ""} {
		set invalid_type 0

		switch -- $type {
			BET {
				# Grab bet details and pre-populate.
				ob_log::write ERROR {$fn: Associating ManAdj with bet, bet_id:$id.}

				# Get details for prepopulation.
				set sql {
					select
						b.stake,
						a.cust_id,
						a.acct_id,
						a.ccy_code
					from
						tBet  b,
						tAcct a
					where
						    b.acct_id = a.acct_id
						and b.bet_id  = ?
				}

				set stmt       [inf_prep_sql $DB $sql]
				set rs         [inf_exec_stmt $stmt $id]
				inf_close_stmt  $stmt

				# Ignore current stake not required.
				set cur_amt  0
				set cust_id  [db_get_col $rs 0 cust_id]
				set acct_id  [db_get_col $rs 0 acct_id]
				set ccy_code [db_get_col $rs 0 ccy_code]
				db_close $rs
			}
			XBET {
				# Grab bet details and pre-populate.
				ob_log::write ERROR {$fn: Associating ManAdj with bet, bet_id:$id.}

				# Get details for prepopulation.
				set sql {
					select
						b.stake,
						a.cust_id,
						a.acct_id,
						a.ccy_code
					from
						tXGameBet b,
						tXGameSub s,
						tAcct     a
					where
							b.xgame_sub_id = s.xgame_sub_id
						and s.acct_id      = a.acct_id
						and b.xgame_bet_id = ?
				}

				set stmt       [inf_prep_sql $DB $sql]
				set rs         [inf_exec_stmt $stmt $id]
				inf_close_stmt  $stmt

				# Ignore current stake not required.
				set cur_amt  0
				set cust_id  [db_get_col $rs 0 cust_id]
				set acct_id  [db_get_col $rs 0 acct_id]
				set ccy_code [db_get_col $rs 0 ccy_code]
				db_close $rs
			}
			PMT {
				# Grab pmt details and pre-populate.
				ob_log::write ERROR {$fn: Associating ManAdj with pmt, pmt_id:$id.}

				# Get details for prepopulation.
				set sql {
					select
						p.amount,
						a.cust_id,
						a.acct_id,
						a.ccy_code
					from
						tPmt  p,
						tAcct a
					where
						    p.acct_id = a.acct_id
						and p.pmt_id  = ?
				}

				set stmt       [inf_prep_sql $DB $sql]
				set rs         [inf_exec_stmt $stmt $id]
				inf_close_stmt  $stmt

				set cur_amt [db_get_col $rs 0 amount]
				set cust_id [db_get_col $rs 0 cust_id]
				set acct_id  [db_get_col $rs 0 acct_id]
				set ccy_code [db_get_col $rs 0 ccy_code]
				db_close $rs
			}
			default {
				set invalid_type 1
				ob_log::write ERROR {$fn: Invalid type: $type, not pre-populating.}
			}
		}

		# Bind up!
		if {!$invalid_type} {
			tpBindString ManAdj_ref_key  $type
			tpBindString ManAdj_ref_id   $id
			if {$cur_amt>0} {
				tpBindString Amount  $cur_amt
			}
			tpBindString CustId  $cust_id
			tpBindString AcctCCY $ccy_code
			tpBindString AcctId  $acct_id
		}
	} else {
		ob_log::write ERROR {$fn: Not associating ManAdj with a ref_key.}
	}

	#
	# Get types/subtypes for that group.
	#
	set sql {
		select
			t.type,
			t.desc as typedesc,
			s.subtype,
			s.desc
		from
			tManAdjType    t,
			tManAdjGrp     g,
			tManAdjGrpItem i,
			outer tManAdjSubType s
		where
				t.type   = s.type
			and t.type   = i.type
			and i.group  = g.group
			and g.group  = ?
			and t.status = 'A'
		order by t.type
	}
	set stmt [inf_prep_sql $DB $sql]
	set res_madj_subtypes [inf_exec_stmt $stmt $group]

	inf_close_stmt $stmt

	set type ""
	set num_types -1
	set num_sub_types [db_get_nrows $res_madj_subtypes]

	for {set i 0} {$i < $num_sub_types} {incr i} {

		set type_i [db_get_col $res_madj_subtypes $i type]
		if {$type_i != $type} {
			set type $type_i
			incr num_types
			set sub_type_num 0
			set MAN_ADJ_SUBTYPES($num_types,type_id)  $num_types
			set MAN_ADJ_SUBTYPES($num_types,type)     $type
			set MAN_ADJ_SUBTYPES($num_types,desc)     [db_get_col $res_madj_subtypes $i typedesc]
			set MAN_ADJ_SUBTYPES($num_types,xl_code)  MADJ_TYPE_DESC_$type
			set MAN_ADJ_SUBTYPES($num_types,xl)       [ob_xl::sprintf [ob_xl_compat::get_lang] $MAN_ADJ_SUBTYPES($num_types,xl_code)]
		}

		set MAN_ADJ_SUBTYPES($num_types,$sub_type_num,sub_type) [db_get_col $res_madj_subtypes $i subtype]
		set MAN_ADJ_SUBTYPES($num_types,$sub_type_num,desc)     [db_get_col $res_madj_subtypes $i desc]
		set MAN_ADJ_SUBTYPES($num_types,num_subtypes)           [incr sub_type_num]
	}

	db_close $res_madj_subtypes

	tpSetVar NumManAdjTypes [incr num_types]

	tpBindVar ManAdjType       MAN_ADJ_SUBTYPES  type      madj_type_idx
	tpBindVar ManAdjDesc       MAN_ADJ_SUBTYPES  desc      madj_type_idx
	tpBindVar ManAdjSelc       MAN_ADJ_SUBTYPES  selected  madj_type_idx
	tpBindVar ManAdjText       MAN_ADJ_SUBTYPES  xl        madj_type_idx
	tpBindVar MadjSubType      MAN_ADJ_SUBTYPES  sub_type  madj_type_idx   madj_subtype_idx
	tpBindVar MadjSubTypeDesc  MAN_ADJ_SUBTYPES  desc      madj_type_idx   madj_subtype_idx
	tpBindVar MadjNumSubTypes  MAN_ADJ_SUBTYPES  num_subtypes      madj_type_idx

	tpBindString madjuid [OT_UniqueId]
}

proc do_man_adj {} {

	set act [reqGetArg SubmitName]

	switch -- $act {
		"DoManAdj" {
			set ret [do_cust_man_adj]
			if {$ret == "OB_ERROR" && [reqGetArg ReturnLoc] == "MAN_ADJ"} {
				go_man_adj
				return
			}

			ADMIN::CUST::go_cust
		}
		"ViewManAdj" {
			go_view_cust_man_adj
			return
		}
	}
}

# Rebind data sent in the request.
#   For playback of original page.
proc rebind_request_data {} {

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[reqGetNthName $i] != ""} {
			reqSetArg [reqGetNthName $i] [reqGetNthVal $i]
		}
	}

	# Rebind all the sent data.
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
		tpBindString [reqGetNthName $n] [reqGetNthVal $n]
	}

}


#   Proc to send  monitor messages , if  configured to send .
#
proc check_and_send_monitor_msg {madj_id status} {

	global DB

	if {[OT_CfgGet MONITOR 0]} {

		if {[catch {
			set madj_details_sql {
				select
					a.cust_id,
					m.amount,
					m.type,
					a.ccy_code
				from
					tManAdj m,
					tAcct a
				where
					m.acct_id = a.acct_id and
					m.madj_id = ?
			}

			set stmt [inf_prep_sql $DB $madj_details_sql]
			set res  [inf_exec_stmt $stmt $madj_id]

			set cust_id     [db_get_col $res cust_id]
			set ccy_code    [db_get_col $res ccy_code]
			set amount_usr  [db_get_col $res amount]
							set madj_code   [db_get_col $res type]
			inf_close_stmt $stmt
			db_close $res

			# Retrieve customer details needed for manual adjustment monitor
			set sql_cust [subst {
				select
					c.username,
					c.notifyable,
					c.liab_group,
					r.fname,
					r.lname,
					r.code
				from
					tCustomer c,
					tCustomerReg r
				where
					c.cust_id = r.cust_id and
					c.cust_id = ?
			}]

			set stmt_cust [inf_prep_sql $DB $sql_cust]
			set rs_cust [inf_exec_stmt $stmt_cust $cust_id]

			inf_close_stmt $stmt_cust

			# Retrieve exch rate
			set sql_ccy [subst {
				select
					($amount_usr / exch_rate) amount_sys
				from
					tCcy
				where
					ccy_code = ?
			}]

			set stmt_ccy [inf_prep_sql $DB $sql_ccy]
			set rs_ccy [inf_exec_stmt $stmt_ccy $ccy_code]

			inf_close_stmt $stmt_ccy

			# Sending Monitor Messgae for Manual adjustments
			set cust_uname            [db_get_col $rs_cust 0 username]
			set cust_fname            [db_get_col $rs_cust 0 fname]
			set cust_lname            [db_get_col $rs_cust 0 lname]
			set cust_is_notifyable    [db_get_col $rs_cust 0 notifyable]
			set cust_reg_code         [db_get_col $rs_cust 0 code]
			set amount_sys            [db_get_col $rs_ccy 0 amount_sys]
			set madj_status           $status
			set madj_date             [clock format [clock seconds] -format "%Y-%m-%d %k:%M:%S"]
			set liab_group            [db_get_col $rs_cust 0 liab_group]

			db_close $rs_cust
			db_close $rs_ccy

			MONITOR::send_manual_adjustment \
					$cust_id \
					$cust_uname \
					$cust_fname \
					$cust_lname \
					$cust_is_notifyable \
					$cust_reg_code \
					$amount_usr \
					$amount_sys \
					$ccy_code \
					$madj_status \
					$madj_code \
					$madj_date \
					$liab_group
		} msg]} {

			ob_log::write ERROR "Unable to send man adj monitor message - $msg"
		}
	}
}



}
