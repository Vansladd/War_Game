# $Id: alerts.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

#	Edit and manage alerts.
#
#	insert into tAdminOpType (type,desc) values ("ALERT", "Change alert settings");
#	insert into tAdminOp (action,desc,type) values ("ManageAlerts","Manage alerts and alert settings","ALERT");
#
#	SEE ALSO acct/lb_acct.tcl
#
namespace eval ADMIN::ALERTS {

asSetAct ADMIN::ALERTS::GoSettingList	[namespace code go_setting_list]
asSetAct ADMIN::ALERTS::GoSetting		[namespace code go_setting]
asSetAct ADMIN::ALERTS::DoSetting		[namespace code do_setting]
asSetAct ADMIN::ALERTS::GoAlert			[namespace code go_alert]
asSetAct ADMIN::ALERTS::GoAlertAcct		[namespace code go_alert_acct]
asSetAct ADMIN::ALERTS::DoAlertAcct		[namespace code do_alert_acct]

# common character to column maps
variable map
set map(medium) 	{S SMS M Email B Both}
set map(type)		{S Selection B "Bet outcome" P "Pool bet outcome" T Team E "Event outcome"}
set map(status)		{A Active S Suspended P Pending C Complete F Failed X Deleted}
set map(direction)	{L <= G >=}

proc chk_permission args {
	if {![op_allowed ManageAlerts]} {
		error "User does not have required permissions to add,update,delete or view alerts."
	}
}

### begin alert settings ###

#
# show the alert setting list
#
proc go_setting_list {} {
	global DB ALERT_SETTING
	variable map

	chk_permission

	array unset ALERT_SETTING

	set sql {select
		c.cust_code,
		nvl(c.desc,c.cust_code) cust_code_desc,
		s.free_count,
		s.total,
		s.cost
	from
		tAlertSetting	s,
		tCustCode		c
	where
		s.cust_code		= c.cust_code
	order by
		2,3;
	}
	set stmt	[inf_prep_sql $DB $sql]
	set rs		[inf_exec_stmt $stmt]
	set nrows	[db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set ALERT_SETTING($r,cust_code)			[db_get_col $rs $r cust_code]
		set ALERT_SETTING($r,cust_code_desc)	[db_get_col $rs $r cust_code_desc]
		set ALERT_SETTING($r,free_count)		[db_get_col $rs $r free_count]
		set ALERT_SETTING($r,total)				[db_get_col $rs $r total]
		set ALERT_SETTING($r,cost)				[db_get_col $rs $r cost]
	}

	db_close $rs
	inf_close_stmt $stmt

	tpBindVar CustCode		ALERT_SETTING cust_code			idx
	tpBindVar CustCodeDesc	ALERT_SETTING cust_code_desc	idx
	tpBindVar FreeCount		ALERT_SETTING free_count		idx
	tpBindVar Total			ALERT_SETTING total				idx
	tpBindVar Cost			ALERT_SETTING cost				idx

	tpSetVar Num $nrows

	asPlayFile -nocache "alert_setting_list.html"
}

#
# show an alert setting
#
proc go_setting {} {
	global DB

	chk_permission

	set cust_code	[reqGetArg CustCode]

	bind_cust_codes

	# if the arguments have been provided then we assume that it is an update form
	if {[reqGetArg SubmitName] != "Add"} {
		set sql		{select	cust_code, free_count, total, cost from tAlertSetting where cust_code=?}
		set stmt	[inf_prep_sql $DB $sql]
		set rs		[inf_exec_stmt $stmt $cust_code]

		set nrows	[db_get_nrows $rs]

		tpBindString CustCode	[db_get_col $rs 0 cust_code]
		tpBindString FreeCount	[db_get_col $rs 0 free_count]
		tpBindString Total		[db_get_col $rs 0 total]
		tpBindString Cost		[db_get_col $rs 0 cost]

		db_close $rs
		inf_close_stmt $stmt

	} else {
		tpSetVar opAdd 1

		tpBindString CustCode [reqGetArg CustCode]
		tpBindString FreeCount [reqGetArg FreeCount]
		tpBindString Total [reqGetArg Total]
		tpBindString Cost [reqGetArg Cost]
	}

	asPlayFile -nocache "alert_setting.html"
}

#
# Bind customer codes from the drop down list
#
proc bind_cust_codes {} {
	global DB CUST_CODE

	array unset CUST_CODE

	set sql		{select cust_code, desc from tCustCode order by desc;}
	set stmt	[inf_prep_sql $DB $sql]
	set rs		[inf_exec_stmt $stmt]

	set nrows	[db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set CUST_CODE($r,cust_code)	[db_get_col $rs $r cust_code]
		set CUST_CODE($r,desc)		[db_get_col $rs $r desc]
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar CustCodeCustCode CUST_CODE cust_code cust_code_idx
	tpBindVar CustCodeDesc CUST_CODE desc cust_code_idx

	tpSetVar NumCustCodes $nrows
}

#
# complete a do action on an alert setting
#
proc do_setting {} {
	switch [reqGetArg SubmitName] {
		Add		{ins_setting}
		Update	{upd_setting}
		Delete	{del_setting}
		Back	{go_setting_list}
		default {error "Submit name [reqGetArg SubmitName] is uknown."}
	}
}

#
# add a new alert setting
#
proc ins_setting {} {
	global DB

	chk_permission

	set cust_code	[reqGetArg CustCode]
	set medium		[reqGetArg Medium]
	set free_count	[reqGetArg FreeCount]
	set total		[reqGetArg Total]
	set cost		[reqGetArg Cost]

	set	sql		{insert into tAlertSetting (cust_code, free_count, total, cost) values (?, ?, ?, ?)}
	set stmt	[inf_prep_sql $DB $sql]
	set err		[catch {db_close [inf_exec_stmt $stmt $cust_code $free_count $total $cost]} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to add new alert setting: '$msg'."
		go_setting
	} else {
		msg_bind "Added new alert setting."
		go_setting_list
	}
}

#
# update the values of an alert setting
#
proc upd_setting {} {
	global DB

	chk_permission

	set cust_code	[reqGetArg CustCode]
	set free_count	[reqGetArg FreeCount]
	set total		[reqGetArg Total]
	set cost		[reqGetArg Cost]

	set	sql		{update tAlertSetting set free_count=?, total=?, cost=? where cust_code=?}
	set stmt	[inf_prep_sql $DB $sql]
	set err		[catch {db_close [inf_exec_stmt $stmt $free_count $total $cost $cust_code]} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to update alert setting: '$msg'."
		go_setting
	} else {
		msg_bind "Updated alert setting."
		go_setting_list
	}
}

#
# delete an alert setting
#
proc del_setting {} {
	global DB

	chk_permission

	set cust_code	[reqGetArg CustCode]

	set	sql		{delete from tAlertSetting where cust_code=?}
	set stmt	[inf_prep_sql $DB $sql]
	set err		[catch {db_close [inf_exec_stmt $stmt $cust_code]} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to delete alert setting: '$msg'."
		go_setting
	} else {
		msg_bind "Deleted alert setting."
		go_setting_list
	}
}

### end alert settings ##





## being alerts ###

#
# bind an alert list
#
proc bind_alerts {cust_id} {
	global DB ALERTS
	variable map

	chk_permission

	array unset ALERTS

	set sql {
		select
			a.alert_id,
			a.cr_date,
			a.acct_id,
			a.status,
			nvl(a.total,"-") total,
			nvl(a.expiry,"-") expiry,
			a.type,
			a.medium,
			nvl(a.email,"-") email,
			nvl(a.mobile,"-") mobile,
			a.source,
			count(m.alert_msg_id) sent
		from
			tAlert a,
		outer
			tAlertMessage m,
			tAcct  ac
		where
			a.acct_id = ac.acct_id
		and a.alert_id = m.alert_id
		and ac.cust_id = ?
		group by
			1,2,3,4,5,6,7,8,9,10,11
		order by
			a.cr_date
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $cust_id]
	set nrows [db_get_nrows $rs]

	# bind all the rows and columns
	for {set r 0} {$r < $nrows} {incr r} {
		set ALERTS($r,alert_id) [db_get_col $rs $r alert_id]
		set ALERTS($r,cr_date) [db_get_col $rs $r cr_date]
		set ALERTS($r,acct_id) [db_get_col $rs $r acct_id]
		set ALERTS($r,status) [string map $map(status) [db_get_col $rs $r status]]
		set ALERTS($r,total) [db_get_col $rs $r total]
		set ALERTS($r,expiry) [db_get_col $rs $r expiry]
		set ALERTS($r,type) [string map $map(type) [db_get_col $rs $r type]]
		set ALERTS($r,medium) [string map $map(medium) [db_get_col $rs $r medium]]
		set ALERTS($r,email) [db_get_col $rs $r email]
		set ALERTS($r,mobile) [db_get_col $rs $r mobile]
		set ALERTS($r,source) [db_get_col $rs $r source]
		set ALERTS($r,sent) [db_get_col $rs $r sent]
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar AlertAlertId ALERTS alert_id alert_idx
	tpBindVar AlertCrDate ALERTS cr_date alert_idx
	tpBindVar AlertAcctId ALERTS acct_id alert_idx
	tpBindVar AlertStatus ALERTS status alert_idx
	tpBindVar AlertSent ALERTS sent alert_idx
	tpBindVar AlertTotal ALERTS total alert_idx
	tpBindVar AlertExpiry ALERTS expiry alert_idx
	tpBindVar AlertType ALERTS type alert_idx
	tpBindVar AlertMedium ALERTS medium alert_idx
	tpBindVar AlertEmail ALERTS email alert_idx
	tpBindVar AlertMobile ALERTS mobile alert_idx
	tpBindVar AlertSource ALERTS source alert_idx

	tpSetVar NumAlerts $nrows
}

#
# show an alert and play the page, a lot of this is ripped from customer screens
#
proc go_alert {} {
	global DB ALERT SELECTION MESSAGE BET POOL_BET
	variable map

	chk_permission

	array unset ALERT
	array unset SELECTION
	array unset MESSAGE
	array unset BET
	array unset POOL_BET

	tpBindString AlertId [set alert_id [reqGetArg AlertId]]

	# get the main alert
	set sql(ALERT_get_alert) {
		select
			a.cr_date,
			a.acct_id,
			a.status,
			a.type,
			a.medium,
			nvl(a.total,"-") total,
			nvl(a.expiry,"-") expiry,
			nvl(a.mobile,"-") mobile,
			nvl(a.email,"-") email,
			ac.cust_id,
			a.source
		from
			tAlert a,
			tAcct ac,
			tCustomerReg r
		where
			a.alert_id	= ?
		and a.acct_id   = ac.acct_id
		and ac.cust_id  = r.cust_id
	}

	set sql(ALERT_get_messages) {
		select
			m.alert_msg_id,
			m.msg_num,
			m.cr_date,
			m.msg,
			nvl(j.amount,0) - nvl(j2.amount,0) amount,
			m.status
		from
			tAlert a,
			tAlertMessage m,
		outer
			tJrnl j,
		outer
			tJrnl j2
		where
			a.alert_id	    = ?
		and a.alert_id       = m.alert_id
		and j.j_op_type     = "ALRT"
		and j.j_op_ref_key  = "AMSG"
		and j.j_op_ref_id   = m.alert_msg_id
		and j.acct_id       = a.acct_id
		and j2.j_op_type     = "ALRT"
		and j2.j_op_ref_key  = "ARFD"
		and j2.j_op_ref_id   = m.alert_msg_id
		and j2.acct_id       = a.acct_id
		order by
			m.cr_date
	}


	set sql(ALERT_get_selections) {
		select
			s.id,
			s.direction,
			s.limit_num,
			s.limit_den
		from
			tAlertSelection	s
		where
			s.alert_id = ?
	}

	set sql(ALERT_get_team) {
		select
			name
		from
			tTeam
		where
			team_id = ?
	}

	set sql(ALERT_get_bets) {
		select distinct
			b.bet_id,
			b.receipt
		from
			tAlertSelection s,
			tEv e,
			tEvOc c,
			tOBet o,
			tBet b
		where
			b.acct_id = ?
		and	s.id = ?
		and s.id = e.ev_id
		and e.ev_id = c.ev_id
		and c.ev_oc_id = o.ev_oc_id
		and o.bet_id = b.bet_id
	}
	set sql(ALERT_get_pool_bets) {
		select distinct
			b.pool_bet_id,
			b.receipt
		from
			tAlertSelection s,
			tEv e,
			tEvOc c,
			tPBet o,
			tPoolBet b
		where
			b.acct_id = ?
		and	s.id = ?
		and s.id = e.ev_id
		and e.ev_id = c.ev_id
		and c.ev_oc_id = o.ev_oc_id
		and o.pool_bet_id = b.pool_bet_id
	}
	# get the main alert
	set stmt [inf_prep_sql $DB $sql(ALERT_get_alert)]
	set rs	[inf_exec_stmt $stmt $alert_id]

	tpBindString CrDate [db_get_col $rs 0 cr_date]
	tpBindString Acct_id [set acct_id [db_get_col $rs 0 acct_id]]
	tpBindString Status [string map $map(status) [set status [db_get_col $rs 0 status]]]
	tpBindString Type [string map $map(type) [set type [db_get_col $rs 0 type]]]
	tpBindString Medium [string map $map(medium) [set medium [db_get_col $rs 0 medium]]]
	tpBindString Total [db_get_col $rs 0 total]
	tpBindString Expiry [db_get_col $rs 0 expiry]
	tpBindString Mobile [db_get_col $rs 0 mobile]
	tpBindString Email [db_get_col $rs 0 email]
	tpBindString CustId [db_get_col $rs 0 cust_id]
	tpBindString Source  [db_get_col $rs 0 source]

	tpSetVar type $type
	tpSetVar status $status
	tpSetVar medium $medium

	db_close $rs
	inf_close_stmt $stmt

	# bind the selections
	set stmt [inf_prep_sql $DB $sql(ALERT_get_selections)]
	set rs	[inf_exec_stmt $stmt $alert_id]
	tpSetVar NumSelections  [set nrows	[db_get_nrows $rs]]

	for {set r 0} {$r < $nrows} {incr r} {
		set SELECTION($r,id) [db_get_col $rs $r id]
		set SELECTION($r,direction) [db_get_col $rs $r direction]
		set SELECTION($r,limit_num) [db_get_col $rs $r limit_num]
		set SELECTION($r,limit_den) [db_get_col $rs $r limit_den]
		if {$SELECTION($r,direction) != ""} {
			set SELECTION($r,condition) "[html_encode [string map $map(direction) $SELECTION($r,direction)]] [mk_price $SELECTION($r,limit_num) $SELECTION($r,limit_den)]"
		} else {
			set SELECTION($r,condition) "-"
		}
		switch $type {
			T {
				# since there is no team page in the admin screens, show the team name
				set team_stmt [inf_prep_sql $DB $sql(ALERT_get_team)]
				set team_rs [inf_exec_stmt $team_stmt $SELECTION($r,id)]
				set SELECTION($r,name) [db_get_col $team_rs 0 name]
				db_close $team_rs
				inf_close_stmt $team_stmt
			}
			E {
				# show the customers bets relating to this event
				set bet_stmt [inf_prep_sql $DB $sql(ALERT_get_bets)]
				set bet_rs [inf_exec_stmt $bet_stmt $acct_id $SELECTION($r,id)]
				set BET($r,nrows) [db_get_nrows $bet_rs]
				for {set b 0} {$b < $BET($r,nrows)} {incr b} {
					set BET($r,$b,bet_id) [db_get_col $bet_rs $b bet_id]
					set BET($r,$b,receipt) [db_get_col $bet_rs $b receipt]
				}
				db_close $bet_rs
				inf_close_stmt $bet_stmt

				# show the customers pool bets relating to this event
				set bet_stmt [inf_prep_sql $DB $sql(ALERT_get_pool_bets)]
				set bet_rs [inf_exec_stmt $bet_stmt $acct_id $SELECTION($r,id)]
				set POOL_BET($r,nrows) [db_get_nrows $bet_rs]
				for {set b 0} {$b < $POOL_BET($r,nrows)} {incr b} {
					set POOL_BET($r,$b,pool_bet_id) [db_get_col $bet_rs $b pool_bet_id]
					set POOL_BET($r,$b,receipt) [db_get_col $bet_rs $b receipt]
				}
				db_close $bet_rs
				inf_close_stmt $bet_stmt
			}
		}
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar SelectionId SELECTION id selection_idx
	tpBindVar SelectionName SELECTION name selection_idx
	tpBindVar SelectionCondition SELECTION condition selection_idx

	# only applies to event type alerts DOES NOT APPLY TO BET TYPE
	tpBindVar BetId BET bet_id selection_idx bet_idx
	tpBindVar BetReceipt BET receipt selection_idx bet_idx
	tpBindVar PoolBetId POOL_BET pool_bet_id selection_idx pool_bet_idx
	tpBindVar PoolBetReceipt POOL_BET receipt selection_idx pool_bet_idx

	# get the messages
	set stmt	[inf_prep_sql $DB $sql(ALERT_get_messages)]
	set rs		[inf_exec_stmt $stmt $alert_id]
	tpSetVar NumMessages [set nrows	[db_get_nrows $rs]]

	for {set r 0} {$r < $nrows} {incr r} {
		set MESSAGE($r,alert_msg_id) [db_get_col $rs $r alert_msg_id]
		set MESSAGE($r,msg_num) [db_get_col $rs $r msg_num]
		set MESSAGE($r,cr_date) [db_get_col $rs $r cr_date]
		set MESSAGE($r,msg) [db_get_col $rs $r msg]
		set MESSAGE($r,amount) [db_get_col $rs $r amount]
		set MESSAGE($r,status) [string map $map(status) [db_get_col $rs $r status]]
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar MessageAlertMsgId MESSAGE alert_msg_id message_idx
	tpBindVar MessageMsgNum MESSAGE msg_num message_idx
	tpBindVar MessageCrDate MESSAGE cr_date message_idx
	tpBindVar MessageMsg MESSAGE msg message_idx
	tpBindVar MessageAmount MESSAGE amount message_idx
	tpBindVar MessageStatus MESSAGE status message_idx

	asPlayFile -nocache alert.html
}

### end alerts ###





## begin alert accts ###

#
# bind all the alerts for a customer
#
proc bind_alert_accts {cust_id} {
	global DB ALERT_ACCT

	chk_permission

	array unset ALERT_ACCT

	set sql		{
		select
			aa.acct_id,
			nvl(aa.free_count,'-') free_count,
			nvl(aa.total,'-') total,
			nvl(aa.cost,'-') cost
		from
			tAlertAcct aa,
			tAcct a
		where
			aa.acct_id = a.acct_id
		and a.cust_id = ?
		order by
			aa.acct_id
	}
	set stmt	[inf_prep_sql $DB $sql]
	set rs		[inf_exec_stmt $stmt $cust_id]

	set nrows	[db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set ALERT_ACCT($r,acct_id) [db_get_col $rs $r acct_id]
		set ALERT_ACCT($r,free_count) [db_get_col $rs $r free_count]
		set ALERT_ACCT($r,total) [db_get_col $rs $r total]
		set ALERT_ACCT($r,cost) [db_get_col $rs $r cost]
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar AlertAcctAcctId		ALERT_ACCT acct_id		alert_acct_idx
	tpBindVar AlertAcctFreeCount	ALERT_ACCT free_count	alert_acct_idx
	tpBindVar AlertAcctTotal		ALERT_ACCT total		alert_acct_idx
	tpBindVar AlertAcctCost		ALERT_ACCT cost			alert_acct_idx

	tpSetVar NumAlertAccts $nrows

}

#
# bind an array of accounts
#
proc bind_accts {cust_id} {
	global DB ACCT

	array unset ACCT

	set sql {select acct_id from tAcct where cust_id = ? order by acct_id}
	set stmt [inf_prep_sql $DB $sql]

	set rs [inf_exec_stmt $stmt $cust_id]
	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set ACCT($r,acct_id) [db_get_col $rs $r acct_id]
	}
	db_close $rs
	inf_close_stmt $stmt

	tpBindVar AcctAcctId ACCT acct_id acct_idx

	tpSetVar NumAccts $nrows
}

#
# go to an alert
#
proc go_alert_acct {} {
	global DB

	chk_permission

	# assume that cust id is always in the post
	#
	# proc assumes that if acct_id is blank, then this is show the add alert page
	#
	tpBindString AcctId [set acct_id [reqGetArg AcctId]]
	tpBindString CustId [set cust_id [reqGetArg CustId]]

	bind_accts $cust_id

	if {[reqGetArg SubmitName] != "Add"} {
		# show alert
		set sql {select free_count, total, cost from tAlertAcct where acct_id = ?}
		set stmt [inf_prep_sql $DB $sql]

		set rs [inf_exec_stmt $stmt $acct_id]

		set nrows [db_get_nrows $rs]

		tpBindString FreeCount [db_get_col $rs 0 free_count]
		tpBindString Total [db_get_col $rs 0 total]
		tpBindString Cost [db_get_col $rs 0 cost]

		db_close $rs
		inf_close_stmt $stmt
	} else {
		# show add alert
		tpSetVar opAdd 1

		tpBindString FreeCount [reqGetArg FreeCount]
		tpBindString Total [reqGetArg Total]
		tpBindString Cost [reqGetArg Cost]
	}

	asPlayFile -nocache "alert_acct.html"
}

#
# do  (upd, ins, del) to a accounts alert setting
#
proc do_alert_acct {} {
	switch [reqGetArg SubmitName] {
		Add {ins_alert_acct}
		Delete {del_alert_acct}
		Update {upd_alert_acct}
		Back {ADMIN::CUST::go_cust}
		default {error "Submit name [reqGetArg SubmitName] is unknown."}
	}
}

#
# insert a new alert account setting
#
proc ins_alert_acct {} {
	global DB

	chk_permission

	set acct_id [reqGetArg AcctId]
	set free_count [reqGetArg FreeCount]
	set total [reqGetArg Total]
	set cost [reqGetArg Cost]

	set sql {insert into tAlertAcct (acct_id, free_count, total, cost) values (?, ?, ?, ?)}
	set stmt [inf_prep_sql $DB $sql]
	set err  [catch {db_close [inf_exec_stmt $stmt $acct_id $free_count $total $cost]} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to add alert account setting: '$msg'."
		go_alert_acct
	} else {
		msg_bind "Added alert account setting."
		ADMIN::CUST::go_cust
	}
}

#
# update an alert account setting
#
proc upd_alert_acct {} {
	global DB

	chk_permission

	set acct_id [reqGetArg AcctId]
	set free_count [reqGetArg FreeCount]
	set total [reqGetArg Total]
	set cost [reqGetArg Cost]

	set sql {update tAlertAcct set free_count = ?, total = ?, cost = ? where acct_id = ?}
	set stmt [inf_prep_sql $DB $sql]
	set err  [catch {db_close [inf_exec_stmt $stmt $free_count $total $cost $acct_id ]} msg]
	catch {inf_close_stmt $stmt}
	if {$err} {
		err_bind "Failed to update alert account setting: '$msg'."
		go_alert_acct
	} else {
		msg_bind "Updated alert account setting."
		ADMIN::CUST::go_cust
	}
}

#
# delete an alert account setting
#
proc del_alert_acct {} {
	global DB

	chk_permission

	set acct_id [reqGetArg AcctId]

	set sql {delete from tAlertAcct where acct_id = ?}
	set stmt [inf_prep_sql $DB $sql]
	set err [catch {db_close [inf_exec_stmt $stmt $acct_id]} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to delete alert account setting: '$msg'."
		go_alert_acct
	} else {
		msg_bind "Deleted alert account setting."
		ADMIN::CUST::go_cust
	}
}

proc go_alert_message {} {
	global DB

	chk_permission

	set alert_msg_id [reqGetArg AlertMsgId]

	set sql {select alert_id from tAlertMessage where alert_msg_id = ?}
	set stmt [inf_prep_sql $DB $sql]
	set err [catch {
		set rs [inf_exec_stmt $stmt $alert_msg_id]
		set alert_id [db_get_col $rs 0 alert_id]
	} msg]
	catch {inf_close_stmt $stmt}

	if {$err} {
		err_bind "Failed to find alert message: '$msg'."
		asPlayFile -nocache "error.html"
	} else {
		reqSetArg AlertId $alert_id
		msg_bind "Alert message $alert_msg_id is part of alert $alert_id"
		go_alert
	}
}

### end alert accts ###

# end namespace
}
