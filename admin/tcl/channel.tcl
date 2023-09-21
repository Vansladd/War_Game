# ==============================================================
# $Id: channel.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::CHANNEL {

asSetAct ADMIN::CHANNEL::GoChannelList [namespace code go_channel_list]
asSetAct ADMIN::CHANNEL::GoChannel     [namespace code go_channel]
asSetAct ADMIN::CHANNEL::DoChannel     [namespace code do_channel]
asSetAct ADMIN::CHANNEL::GoCBL         [namespace code go_cbl]
asSetAct ADMIN::CHANNEL::DoCBL         [namespace code do_cbl]

#
# ----------------------------------------------------------------------------
# Go to channel list
# ----------------------------------------------------------------------------
#
proc go_channel_list args {

	global DB

	set sql {
		select
			channel_id,
			desc,
			tax_rate,
			max_stake_mul,
			stl_pay_limit,
			fraud_screen
		from
			tChannel
		order by
			channel_id asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumChannels [db_get_nrows $res]

	tpBindTcl ChannelId          sb_res_data $res channel_idx channel_id
	tpBindTcl ChannelName        sb_res_data $res channel_idx desc
	tpBindTcl ChannelTaxRate     sb_res_data $res channel_idx tax_rate
	tpBindTcl ChannelMaxStakeMul sb_res_data $res channel_idx max_stake_mul
	tpBindTcl ChannelStlPayLimit sb_res_data $res channel_idx stl_pay_limit
	tpBindTcl FraudSetting		 sb_res_data $res channel_idx fraud_screen

	asPlayFile -nocache channel_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to single channel add/update
# ----------------------------------------------------------------------------
#
proc go_channel args {

	global DB

	set channel_id [reqGetArg ChannelId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ChannelId $channel_id

	if {$channel_id == ""} {

		if {![op_allowed ManageChannel]} {
			err_bind "You do not have permission to update channel information"
			go_channel_list
			return
		}

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get channel information
		#
		set sql {
			select
				channel_id,
				desc,
				tax_rate,
				max_stake_mul,
				stl_pay_limit,
				fraud_screen,
				async_betting
			from
				tChannel
			where
				channel_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $channel_id]
		inf_close_stmt $stmt

		tpBindString ChannelId          [db_get_col $res 0 channel_id]
		tpBindString ChannelName        [db_get_col $res 0 desc]
		tpBindString ChannelTaxRate     [db_get_col $res 0 tax_rate]
		tpBindString ChannelMaxStakeMul [db_get_col $res 0 max_stake_mul]
		tpBindString ChannelStlPayLimit [db_get_col $res 0 stl_pay_limit]
		tpBindString FraudSetting		[db_get_col $res 0 fraud_screen]
		tpBindString AsyncBetting       [db_get_col $res 0 async_betting]

		db_close $res

		if {[OT_CfgGet FUNC_CHAN_TIME_BET_LIMITS 0]} {

			global CBL

			set sql {
				select
					cbl_id,
					time_from,
					time_to,
					min_bet
				from
					tChanBetLimit
				where
					channel_id = ?
				order by
					time_from
			}

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $channel_id]
			inf_close_stmt $stmt

			tpSetVar NumCBL [set nrows [db_get_nrows $res]]

			for {set r 0} {$r < $nrows} {incr r} {
				set CBL($r,cbl_id)     [db_get_col $res $r cbl_id]
				set CBL($r,time_from)  [db_get_col $res $r time_from]
				set CBL($r,time_to)    [db_get_col $res $r time_to]
				set CBL($r,min_bet)    [db_get_col $res $r min_bet]
			}

			tpBindVar CBLId       CBL cbl_id    cbl_idx
			tpBindVar CBLTimeFrom CBL time_from cbl_idx
			tpBindVar CBLTimeTo   CBL time_to   cbl_idx
			tpBindVar CBLMinBet   CBL min_bet   cbl_idx
		}
	}

	asPlayFile -nocache channel.html

	if {[info exists CBL]} {
		unset CBL
	}
}


#
# ----------------------------------------------------------------------------
# Do currency insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_channel args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_channel_list
		return
	}

	if {![op_allowed ManageChannel]} {
		err_bind "You do not have permission to update channel information"
		go_channel_list
		return
	}

	if {$act == "ChanAdd"} {
		do_channel_add
	} elseif {$act == "ChanMod"} {
		do_channel_upd
	} elseif {$act == "ChanDel"} {
		do_channel_del
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_channel_add args {

	global DB USERNAME

	set sql {

		execute procedure pInsChannel(
			p_username        = ?,
			p_channel_id    = ?,
			p_desc          = ?,
			p_tax_rate      = ?,
			p_max_stake_mul = ?,
			p_stl_pay_limit = ?,
			p_fraud_screen  = ?,
			p_async_betting = ?
		);
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg ChannelId]\
			[reqGetArg ChannelName]\
			[reqGetArg ChannelTaxRate]\
			[reqGetArg ChannelMaxStakeMul]\
			[reqGetArg ChannelStlPayLimit]\
			[reqGetArg FraudSetting]\
			[reqGetArg AsyncBetting]]} msg]} {
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
	go_channel
}

proc do_channel_upd args {

	global DB USERNAME
	
	ob_log::write DEV "username=$USERNAME"

	set sql {	
		execute procedure pUpdChannel(
			p_username = ?,
			p_desc = ?,
			p_tax_rate = ?,
			p_max_stake_mul = ?,
			p_stl_pay_limit = ?,
			p_fraud_screen = ?,
			p_async_betting = ?,
			p_channel_id = ?
		);
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg ChannelName]\
			[reqGetArg ChannelTaxRate]\
			[reqGetArg ChannelMaxStakeMul]\
			[reqGetArg ChannelStlPayLimit]\
			[reqGetArg FraudSetting]\
			[reqGetArg AsyncBetting]\
			[reqGetArg ChannelId]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_channel
		return
	}
	go_channel_list
}

proc do_channel_del args {

	global DB USERNAME

	set sql {
		execute procedure pDelChannel(
			p_username   = ?,
			p_channel_id = ?
		);
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg ChannelId]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_channel
		return
	}

	go_channel_list
}


proc go_cbl args {

	global DB

	set channel_id [reqGetArg ChannelId]
	set cbl_id     [reqGetArg CBLId]

	tpBindString ChannelId $channel_id
	tpBindString CBLId     $cbl_id

	if {$cbl_id == ""} {

		tpSetVar opAdd 1

	} else {

		set sql {
			select
				channel_id,
				time_from,
				time_to,
				min_bet
			from
				tChanBetLimit
			where
				cbl_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cbl_id]
		inf_close_stmt $stmt

		tpBindString ChannelId   [db_get_col $res 0 channel_id]
		tpBindString CBLTimeFrom [db_get_col $res 0 time_from]
		tpBindString CBLTimeTo   [db_get_col $res 0 time_to]
		tpBindString CBLMinBet   [db_get_col $res 0 min_bet]

		db_close $res
	}

	asPlayFile -nocache chan_bet_limit.html
}

proc do_cbl args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_channel
		return
	}

	if {![op_allowed ManageChannel]} {
		err_bind "You do not have permission to update channel information"
		go_channel
		return
	}

	if {$act == "CBLAdd"} {

		set sql {
			insert into tChanBetLimit (
				channel_id, time_from, time_to, min_bet
			) values (
				?, ?, ?, ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt\
			[reqGetArg ChannelId]\
			[reqGetArg CBLTimeFrom]\
			[reqGetArg CBLTimeTo]\
			[reqGetArg CBLMinBet]]
		inf_close_stmt $stmt
		db_close $res

	} elseif {$act == "CBLMod"} {

		set sql {
			update tChanBetLimit set
				time_from = ?,
				time_to   = ?,
				min_bet   = ?
			where
				cbl_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt\
			[reqGetArg CBLTimeFrom]\
			[reqGetArg CBLTimeTo]\
			[reqGetArg CBLMinBet]\
			[reqGetArg CBLId]]
		inf_close_stmt $stmt
		db_close $res

	} elseif {$act == "CBLDel"} {

		set sql {
			delete from tChanBetLimit where cbl_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [reqGetArg CBLId]]
		inf_close_stmt $stmt
		db_close $res

	}

	go_channel
}
}
