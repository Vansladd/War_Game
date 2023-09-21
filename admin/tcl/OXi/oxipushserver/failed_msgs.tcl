# $Id: failed_msgs.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Manage the failed messages in tOXiPushMsgFail
#

namespace eval ADMIN::OXiPUSH {

# For future usage
#asSetAct ADMIN::OXiPUSH::DoRemoveItems          [namespace code do_remove_items]

asSetAct ADMIN::OXiPUSH::DoReQueueItems         [namespace code do_requeue_items]
asSetAct ADMIN::OXiPUSH::GoFailedItems          [namespace code go_failed_items]


#
# Template proc for future usage
#
proc do_remove_items {} {

	ob_log::write DEV { --> do_remove_items}
	set key_id_list [split [string trim [reqGetArg keyIdList]]]
	ob_log::write DEBUG {  key_id_list = $key_id_list}

	#
	# Add code to delete messages from tOXiPushMsgFail here
	#

	tpBindString BindMsg {Items deleted}
	tpSetVar IsBindMsg 1

	ob_log::write DEV { <-- do_remove_items}
	go_failed_items
}


#
# Move seleted items from tOXiPushMsgFail to tOXiPusMsg
#
proc do_requeue_items {} {
	ob_log::write DEV { --> do_requeue_items}

	set key_id_list [split [string trim [reqGetArg keyIdList]]]
	ob_log::write INFO {  do_requeue_items: key_id_list = $key_id_list}

	set num_msgs 0
	foreach key $key_id_list {
		set success [_requeue_item $key]
		if {!$success} {
			break
		}
		incr num_msgs
	}

	tpBindString BindMsg "$num_msgs messages successfully requeued"
	tpSetVar IsBindMsg 1

	ob_log::write DEV { <-- do_requeue_items}
	go_failed_items
}


#
# Display a list of all items in tOXiPusMsgFail
#
proc go_failed_items {} {

	global DB FAILEDMSG
	ob_log::write DEV { --> go_failed_items}

	#
	# Which apps should be displayed?
	#
	set FAILED_OXI_PUSH_APPS [OT_CfgGet FAILED_OXI_PUSH_APPS [list]]
	set len [llength $FAILED_OXI_PUSH_APPS]
	set sql_where {}
	if {$len==1} {
		set sql_where "and a.name = '$FAILED_OXI_PUSH_APPS'"
	} elseif {$len>1} {
		set sql_where "and a.name in ('[join $FAILED_OXI_PUSH_APPS {','}]')"
	}

	#
	# Get failed messages
	#
	set sql [subst {
		select
			a.name,
			f.msg_id,
			f.base_id,
			f.msg_date,
			f.cr_date
		from
			tOXiPushApp     a,
			tOXiPushMsgFail f
		where
			a.app_id=f.app_id
		$sql_where
		order by
			f.msg_id
	}]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt]
    inf_close_stmt $stmt

    set nrows [db_get_nrows $res]
	ob_log::write INFO {  go_failed_items: found $nrows msgs in tOXiPushMsgFail}

	set FAILEDMSG(nrows) $nrows
	for {set i 0} {$i<$nrows} {incr i} {
		set FAILEDMSG($i,name)     [db_get_col $res $i name]
		set FAILEDMSG($i,msg_id)   [db_get_col $res $i msg_id]
		set FAILEDMSG($i,base_id)  [db_get_col $res $i base_id]
		set FAILEDMSG($i,msg_date) [db_get_col $res $i msg_date]
		set FAILEDMSG($i,cr_date)  [db_get_col $res $i cr_date]
	}

	tpSetVar NumFail $nrows

	#
	# Bind up details
	#
	tpBindVar app_name       FAILEDMSG name     fail_idx
	tpBindVar msg_id         FAILEDMSG msg_id   fail_idx
	tpBindVar msg_base_id    FAILEDMSG base_id  fail_idx
	tpBindVar msg_cr_date    FAILEDMSG msg_date fail_idx
	tpBindVar msg_fail_date  FAILEDMSG cr_date  fail_idx

	asPlayFile OXi/oxipushserver/failed_msgs.html

	ob_log::write DEV { <-- go_failed_items}
}

#
# Auxiliary proc for requeuing a single message
#
proc _requeue_item {msg_id} {

	ob_log::write DEV { --> _requeue_item ($msg_id)}
	global DB

	#
	# Step 1 of 3: Retreive the msg to be moved
	#
	ob_log::write DEV {  _requeue_item: RETRIEVING msg from tOXiPushMsgFail}
	set sql {
		select
			app_id,
			base_id,
			msg_date,
			cr_date
		from
			tOXiPushMsgFail
		where
			msg_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $msg_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	if {$nrows!=1} {
		ob_log::write ERROR {  _requeue_item: 0 rows found for msg_id ($msg_id)}
		return 0
	}
	
	set cols [list app_id   \
	               base_id  \
	               msg_date \
	               cr_date]
	foreach c $cols {
		set $c [db_get_col $res 0 $c]
	}

	ob_log::write INFO {  _requeue_item: Requeuing msg_id=$msg_id, app_id=$app_id, base_id=$base_id}
	ob_log::write INFO {  _requeue_item: msg_date=$msg_date, cr_date=$cr_date}

	#
	# Step 2 of 3: Re queue message
	#
	ob_log::write DEV {  _requeue_item: REQUEUING msg to tOXiPushMsg}
	set sql {
		execute procedure pInsOxiPushMsg (
			p_app_id  = ?,
			p_base_id = ?
		)
	}
	set stmt [inf_prep_sql $DB $sql]

	set success 1
	if {[catch {
		inf_exec_stmt $stmt $app_id $base_id
	} msg]} {
		set temp "Failed to requeue msg_id=($msg_id) app_id=($app_id) base_id=($base_id)"
		err_bind $temp
		ob_log::write ERROR {  _requeue_item: $temp}
		set success 0
	}
	inf_close_stmt $stmt

	if {!$success} {
		return 0
	}

	#
	# Step 3 of 3: Delete item from tOXiPushMsgFail
	#
	ob_log::write DEV {  _requeue_item: DELETING msg from tOXiPushMsgFail}
	set sql  {delete from tOXiPushMsgFail where msg_id = ?}
	set stmt [inf_prep_sql $DB $sql]

	set success 1
	if {[catch {
		inf_exec_stmt $stmt $msg_id
	} msg]} {
		set temp "Failed to delete msg_id=($msg_id) app_id=($app_id) base_id=($base_id)"
		err_bind $temp
		ob_log::write ERROR {  _requeue_item: $temp}
		set success 0
	}
	inf_close_stmt $stmt

	ob_log::write DEV { <-- _requeue_item}
	return $success
}

}
