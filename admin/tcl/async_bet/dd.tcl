# $Id: dd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Admin
# Asynchronous Betting - Handle the update of a leg's Drill-Down
#
# Configuration:
#
# Procedures:
#   ::ADMIN::ASYNC_BET::H_upd_dd_ev      update event
#   ::ADMIN::ASYNC_BET::H_upd_dd_mkt     update event-market
#   ::ADMIN::ASYNC_BET::H_upd_dd_oc      update event-outcome
#


# Namespace
#
namespace eval ::ADMIN::ASYNC_BET {

	asSetAct ADMIN::ASYNC_BET::DoUpdDDEv    ::ADMIN::ASYNC_BET::H_upd_dd_ev
	asSetAct ADMIN::ASYNC_BET::DoUpdDDMkt   ::ADMIN::ASYNC_BET::H_upd_dd_mkt
	asSetAct ADMIN::ASYNC_BET::DoUpdDDOc    ::ADMIN::ASYNC_BET::H_upd_dd_oc
}


#
# Check if the current bet has been overridden
#
proc ::ADMIN::ASYNC_BET::_check_bet_overriden {} {
	global DB
	
	set bet_id [reqGetArg bet_id]
	
	if {$bet_id == ""} {
		err_bind "Trying to process bet, but no bet id given."
		return 1
	}
	
	set sql {
		select
			accept_status
		from
			tAsyncBetOff
		where
			bet_id = ?
	}
	
	set st [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $st $bet_id]
	inf_close_stmt $st
	
	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		return 0
	}
	
	set status [db_get_col $rs 0 accept_status]
	db_close $rs
	
	if {$status == "0"} {
		return 1
	} else {
		return 0
	}
}

#--------------------------------------------------------------------------
# Action Handlers
#--------------------------------------------------------------------------

# Update a drill-down event
#
proc ::ADMIN::ASYNC_BET::H_upd_dd_ev args {

	global DB
	
	if {[_check_bet_overriden]} {
		return [ADMIN::ASYNC_BET::H_bet]
	}

	set ev_id [reqGetArg ev_id]

	# get existing event details which we are not changing
	set sql [subst {
		select
		    desc,
		    country,
		    venue,
		    ext_key,
		    shortcut,
		    close_time,
		    sort,
		    flags,
		    url,
		    tax_rate,
		    feed_updateable,
		    mult_key,
		    sp_max_bet,
		    t_bet_cutoff,
		    fb_dom_int,
		    channels,
		    fastkey,
		    blurb,
		    result,
		    calendar,
		    notes,
		    allow_stl,
		    max_pot_win,
		    ew_factor
		from
		    tEv
		where
		    ev_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $ev_id]

	if {[db_get_nrows $rs] != 1} {
		_err_bind "Cannot find event details for ev_id $ev_id"
		inf_close_stmt $stmt
		db_close $rs

	} else {

		# copy the event details
		set cols [db_get_colnames $rs]
		foreach c $cols {
			set $c [db_get_col $rs 0 $c]
		}
		db_close $rs
		inf_close_stmt $stmt

		# update the event
		set sql [subst {
			execute procedure pUpdEv(
			    p_adminuser = ?,
			    p_ev_id = ?,
			    p_desc = ?,
			    p_country = ?,
			    p_venue = ?,
			    p_ext_key = ?,
			    p_shortcut = ?,
			    p_start_time = ?,
			    p_is_off = ?,
			    p_close_time = ?,
			    p_sort = ?,
			    p_flags = ?,
			    p_displayed = ?,
			    p_disporder = ?,
			    p_url = ?,
			    p_status = ?,
			    p_tax_rate = ?,
			    p_feed_updateable = ?,
			    p_mult_key = ?,
			    p_min_bet = ?,
			    p_max_bet = ?,
			    p_sp_max_bet = ?,
			    p_t_bet_cutoff = ?,
			    p_suspend_at = ?,
			    p_fb_dom_int = ?,
			    p_channels = ?,
			    p_fastkey = ?,
			    p_blurb = ?,
			    p_result = ?,
			    p_calendar = ?,
			    p_notes = ?,
			    p_allow_stl = ?,
			    p_max_pot_win = ?,
			    p_max_multiple_bet = ?,
			    p_ew_factor = ?,
			    p_do_tran = 'Y'
			)
		}]
		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt\
		            $::USERNAME\
		            $ev_id\
		            $desc\
		            $country\
		            $venue\
		            $ext_key\
		            $shortcut\
		            [reqGetArg start_time]\
		            [reqGetArg is_off]\
		            $close_time\
		            $sort\
		            $flags\
		            [reqGetArg displayed]\
		            [reqGetArg disporder]\
		            $url\
		            [reqGetArg status]\
		            $tax_rate\
		            $feed_updateable\
		            $mult_key\
		            [reqGetArg ev_min_bet]\
		            [reqGetArg ev_max_bet]\
		            $sp_max_bet\
		            $t_bet_cutoff\
		            [reqGetArg suspend_at]\
		            $fb_dom_int\
		            $channels\
		            $fastkey\
		            $blurb\
		            $result\
		            $calendar\
		            $notes\
		            $allow_stl\
		            $max_pot_win\
		            [reqGetArg ev_max_mult_bet]\
		            $ew_factor} msg]} {
			_err_bind $msg 1
		} else {
			# Updating of Liability Limit and Lay To Lose
			reqSetArg EvId $ev_id
			tpSetVar DD_EV_ID $ev_id
			# Calling do_liab_upd and do_ltl_upd without call back functions
			if {[catch {ADMIN::EVENT::do_liab_upd ""} msg]} {
				_err_bind $msg 1
			} elseif {[OT_CfgGet FUNC_LAY_TO_LOSE 0] && [OT_CfgGet FUNC_LAY_TO_LOSE_EV 0]} {
				if {[catch {ADMIN::EVENT::do_ltl_upd "-" {}} msg]} {
					_err_bind $msg 1
				}
			}
		}
	}

	# re-display the bet-details (re-fresh this updated event)
	tpSetVar DD_EV_ID $ev_id
	H_bet
}


# Update a drill-down market
#
proc ::ADMIN::ASYNC_BET::H_upd_dd_mkt args {

	global DB
	
	if {[_check_bet_overriden]} {
		return [ADMIN::ASYNC_BET::H_bet]
	}

	set ev_mkt_id [reqGetArg ev_mkt_id]

	# get existing market details which we are not changing
	set sql [subst {
		select
		    m.ext_key,
		    m.sort,
		    m.tax_rate,
		    m.ew_avail,
		    m.pl_avail,
		    m.ew_places,
		    m.ew_fac_num,
		    m.ew_fac_den,
		    m.ew_with_bet,
		    m.lp_avail,
		    m.sp_avail,
		    m.pm_avail,
		    m.fc_avail,
		    m.tc_avail,
		    z.apc_status,
		    z.apc_margin,
		    z.apc_trigger,
		    m.hcap_value,
		    m.hcap_step,
		    m.hcap_steal,
		    m.hcap_makeup,
		    z.ah_prc_chng_amt,
		    z.ah_prc_lo,
		    z.ah_prc_hi,
		    m.spread_lower,
		    m.spread_upper,
		    m.spread_makeup,
		    m.min_spread_cap,
		    m.max_spread_cap,
		    m.channels,
		    m.blurb,
		    m.is_ap_mkt,
		    m.sp_max_bet,
		    m.max_pot_win,
		    m.ew_factor
		from
		    tEvMkt m,
		    tEvMktConstr z
		where
		    m.ev_mkt_id = ?
		and z.ev_mkt_id = m.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $ev_mkt_id]

	if {[db_get_nrows $rs] != 1} {
		_err_bind "Cannot find market details for ev_mkt_id $ev_mkt_id"
		inf_close_stmt $stmt
		db_close $rs

	} else {

		# copy the event details
		set cols [db_get_colnames $rs]
		foreach c $cols {
			set $c [db_get_col $rs 0 $c]
		}
		db_close $rs
		inf_close_stmt $stmt

		# update the market
		set sql [subst {
			execute procedure pUpdEvMkt(
			    p_adminuser = ?,
			    p_ev_mkt_id = ?,
			    p_ext_key = ?,
			    p_status = ?,
			    p_sort = ?,
			    p_xmul = ?,
			    p_displayed = ?,
			    p_tax_rate = ?,
			    p_ew_avail = ?,
			    p_pl_avail = ?,
			    p_ew_places = ?,
			    p_ew_fac_num = ?,
			    p_ew_fac_den = ?,
			    p_ew_with_bet = ?,
			    p_lp_avail = ?,
			    p_sp_avail = ?,
			    p_pm_avail = ?,
			    p_fc_avail = ?,
			    p_tc_avail = ?,
			    p_acc_min = ?,
			    p_acc_max = ?,
			    p_liab_limit = ?,
			    p_apc_status = ?,
			    p_apc_margin = ?,
			    p_apc_trigger = ?,
			    p_hcap_value = ?,
			    p_hcap_step = ?,
			    p_hcap_steal = ?,
			    p_hcap_makeup = ?,
			    p_ah_prc_chng_amt = ?,
			    p_ah_prc_lo = ?,
			    p_ah_prc_hi = ?,
			    p_spread_lower = ?,
			    p_spread_upper = ?,
			    p_spread_makeup = ?,
			    p_min_spread_cap = ?,
			    p_max_spread_cap = ?,
			    p_channels = ?,
			    p_blurb = ?,
			    p_is_ap_mkt = ?,
			    p_bir_index = ?,
			    p_bir_delay = ?,
			    p_min_bet = ?,
			    p_max_bet = ?,
			    p_sp_max_bet = ?,
			    p_max_pot_win = ?,
				p_max_multiple_bet = ?,
			    p_ew_factor = ?,
			    p_bet_in_run = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		inf_begin_tran $DB
		if {[catch {inf_exec_stmt $stmt\
	            $::USERNAME\
	            $ev_mkt_id\
	            $ext_key\
	            [reqGetArg status]\
	            $sort\
	            [reqGetArg xmul]\
	            [reqGetArg displayed]\
	            $tax_rate\
	            $ew_avail\
	            $pl_avail\
	            $ew_places\
	            $ew_fac_num\
	            $ew_fac_den\
	            $ew_with_bet\
	            $lp_avail\
	            $sp_avail\
	            $pm_avail\
	            $fc_avail\
	            $tc_avail\
	            [reqGetArg acc_min]\
	            [reqGetArg acc_max]\
	            [reqGetArg liab_limit]\
	            $apc_status\
	            $apc_margin\
	            $apc_trigger\
	            $hcap_value\
	            $hcap_step\
	            $hcap_steal\
	            $hcap_makeup\
	            $ah_prc_chng_amt\
	            $ah_prc_lo\
	            $ah_prc_hi\
	            $spread_lower\
	            $spread_upper\
	            $spread_makeup\
	            $min_spread_cap\
	            $max_spread_cap\
	            $channels\
	            $blurb\
	            $is_ap_mkt\
	            [reqGetArg bir_index]\
	            [reqGetArg bir_delay]\
	            [reqGetArg min_bet]\
	            [reqGetArg max_bet]\
	            $sp_max_bet\
	            $max_pot_win\
	            [reqGetArg max_mult_bet]\
	            $ew_factor\
	            [reqGetArg bet_in_run]} msg]} {
			inf_rollback_tran $DB
			_err_bind $msg 1
		} else {
			inf_commit_tran $DB
		}
		inf_close_stmt $stmt

		# Updating Lay to Lose values 
		reqSetArg MktId $ev_mkt_id
		ADMIN::MARKET::do_laytolose
	}

	# re-display the bet-details (re-fresh this updated market)
	tpSetVar DD_EV_MKT_ID $ev_mkt_id
	H_bet
}



# Update a drill-down outcome
#
proc ::ADMIN::ASYNC_BET::H_upd_dd_oc args {

	global DB
	
	if {[_check_bet_overriden]} {
		return [ADMIN::ASYNC_BET::H_bet]
	}

	set ev_oc_id [reqGetArg ev_oc_id]

	#determine what stake locking should be applied
	set lock_win_stake_limits [reqGetArg lock_win_stk_lmt];
	set lock_place_stake_limits [reqGetArg lock_place_stk_lmt];

	if {$lock_win_stake_limits == "on" && $lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "Y";
	} elseif {$lock_win_stake_limits == "on"} {
		set lock_stake_limits_code "W";
	} elseif {$lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "P";
	} else {
		set lock_stake_limits_code "N";
	}

	OT_LogWrite 5 "record locked = $lock_stake_limits_code";


	# get existing outcome details which we are not changing
	set sql [subst {
		select
		    desc,
		    ext_key,
		    shortcut,
		    ext_id,
		    mult_key,
		    runner_num,
		    channels,
		    risk_info,
		    feed_updateable,
		    max_pot_win,
		    ew_factor,
		    code,
		    fb_result,
		    cs_home,
		    cs_away
		from
		    tEvOc
		where
		    ev_oc_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $ev_oc_id]

	if {[db_get_nrows $rs] != 1} {
		_err_bind "Cannot find outcome details for ev_id $ev_id"
		inf_close_stmt $stmt
		db_close $rs

	} else {

		# copy the event details
		set cols [db_get_colnames $rs]
		foreach c $cols {
			set $c [db_get_col $rs 0 $c]
		}
		db_close $rs
		inf_close_stmt $stmt

		# get the prices
		foreach {lp_num lp_den} [get_price_parts [reqGetArg lp]] {}
		foreach {sp_num_guide sp_den_guide} [get_price_parts [reqGetArg sp]] {}

		# update the outcome
		set sql [subst {
			execute procedure pUpdEvOc(
			    p_adminuser = ?,
			    p_ev_oc_id = ?,
			    p_desc = ?,
			    p_displayed = ?,
			    p_status = ?,
			    p_ext_key = ?,
			    p_shortcut = ?,
			    p_ext_id = ?,
			    p_min_bet = ?,
			    p_max_bet = ?,
			    p_sp_max_bet = ?,
			    p_ep_max_bet = ?,
			    p_max_place_lp = ?,
			    p_max_place_sp = ?,
			    p_max_place_ep = ?,
			    p_max_total = ?,
			    p_mult_key = ?,
			    p_fb_result = ?,
			    p_cs_home = ?,
			    p_cs_away = ?,
			    p_lp_num = ?,
			    p_lp_den = ?,
			    p_sp_num_guide = ?,
			    p_sp_den_guide = ?,
			    p_runner_num = ?,
			    p_channels = ?,
			    p_risk_info = ?,
			    p_allow_feed_upd = ?,
			    p_max_pot_win = ?,
			    p_ew_factor = ?,
			    p_code = ?,
			    p_fc_stk_limit = ?,
			    p_tc_stk_limit = ?,
			    p_lock_stake_lmt = ?,
			    p_max_multiple_bet = ?,
			    p_do_tran = 'Y'
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt\
		            $::USERNAME\
		            $ev_oc_id\
		            $desc\
		            [reqGetArg displayed]\
		            [reqGetArg status]\
		            $ext_key\
		            $shortcut\
		            $ext_id\
		            [reqGetArg min_bet]\
		            [reqGetArg lp_max_bet]\
		            [reqGetArg sp_max_bet]\
			    [reqGetArg ep_max_bet]\
		            [reqGetArg lp_max_place]\
		            [reqGetArg sp_max_place]\
			    [reqGetArg ep_max_place]\
		            [reqGetArg max_total]\
		            $mult_key\
		            $fb_result\
		            $cs_home\
		            $cs_away\
		            $lp_num\
		            $lp_den\
		            $sp_num_guide\
		            $sp_den_guide\
		            $runner_num\
		            $channels\
		            $risk_info\
		            $feed_updateable\
		            $max_pot_win\
		            $ew_factor\
		            $code\
		            [reqGetArg fc_stk_limit]\
		            [reqGetArg tc_stk_limit]\
			    $lock_stake_limits_code\
		            [reqGetArg max_mult_bet]} msg]} {
			_err_bind $msg 1
		}
	}

	# re-display the bet-details (re-fresh this updated outcome)
	tpSetVar DD_EV_OC_ID $ev_oc_id
	H_bet
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Private procedure to determine if a drill-down can be updated
# i.e. has not got a result set, result confirmed or settled.
# If result-set or settled, we can only cancel the bet
#
#   leg - leg number
#   dd  - drill-down
#
proc ::ADMIN::ASYNC_BET::_dd_can_update { leg dd } {

	global ASYNC

	if {$ASYNC(leg,$leg,${dd}_settled) == "Y"\
	    || $ASYNC(leg,$leg,${dd}_result_conf) == "Y"\
	    || ($dd == "oc" && $ASYNC(leg,$leg,oc_result) != "-")} {

		set ASYNC(action,cancel)         1
		set ASYNC(leg,$leg,${dd}_update) 0

		# set a cancel-bet message
		if {$dd == "oc"} {
			set ASYNC(action,cancel,comment) "Asynchronous Bet Cancelled, "
			if {$ASYNC(leg,$leg,oc_settled) == "Y"} {
				append ASYNC(action,cancel,comment) "settled"
			} elseif {$ASYNC(leg,$leg,oc_result_conf) == "Y"} {
				append ASYNC(action,cancel,comment) "result confirmed"
			} else {
				append ASYNC(action,cancel,comment) "result-set"
			}
		}

	} else {
		set ASYNC(leg,$leg,${dd}_update) 1
	}
}
