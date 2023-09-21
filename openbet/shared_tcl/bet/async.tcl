################################################################################
# $Id: async.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to asynchronous bets
################################################################################
namespace eval ob_bet {

	variable  ASYNC_APPLY_OFFER_ERRS
	array set ASYNC_APPLY_OFFER_ERRS [list\
		AS001 ASYNC_OFF_NOT_FOUND\
		AS002 ASYNC_BET_OFFER_USED\
		AS003 ASYNC_OFF_EXPIRED\
		AS004 ASYNC_OFF_BAD\
		AS005 ASYNC_OFF_FAIL\
		AS006 ASYNC_BAD_DECLINE_STATUS]
}



proc ob_bet::get_cust_async_bets {acct_id} {

	# Log input params
	ob_log::write INFO {BET - API(get_cust_async_bets): $acct_id}

	if {[catch {
		set ret [_get_cust_async_bets $acct_id]
	} msg]} {
		_err $msg
	}
	return $ret
}



proc ob_bet::get_async_offer {bet_id {full_details N}} {

	# Log input params
	ob_log::write INFO {BET - API(get_async_offer): $bet_id $full_details}

	if {[catch {
		set ret [_get_async_offer $bet_id $full_details]
	} msg]} {
		_err $msg
	}
	return $ret
}

proc ob_bet::cust_override_async_bet {
	bet_id
	leg_type
	stake_per_line
	{transactional Y}
} {

	# Log input params
	ob_log::write INFO {BET - API(cust_override_async_bet): $bet_id $leg_type $stake_per_line}

	if {[catch {
		set ret [_override_async_bet \
			$bet_id \
			$leg_type \
			$stake_per_line \
			$transactional]
	} msg]} {
		_err $msg
	}
	return $ret
}

proc ob_bet::cust_override_async_leg {
	bet_id
	leg_no
	part_no
	price_type
	p_num
	p_den
	{transactional Y}
} {

	# Log input params
	ob_log::write INFO {BET - API(cust_override_async_leg): \
		$bet_id \
		$leg_no \
		$part_no \
		$price_type \
		$p_num \
		$p_den}

	if {[catch {
		set ret [_override_async_leg \
			$bet_id \
			$leg_no \
			$part_no \
			$price_type \
			$p_num \
			$p_den \
			$transactional]
	} msg]} {
		_err $msg
	}
	return $ret
}

proc ob_bet::cust_accept_async_offer {
	bet_id
	{ignore_offer_time 0}
	{expiry_tolerance 0}
	{transactional Y}
	{token_value 0}
} {

	# Log input params
	ob_log::write INFO {BET - API(cust_accept_async_offer): $bet_id $ignore_offer_time}

	if {[catch {
		set ret [_accept_async_offer $bet_id $ignore_offer_time $expiry_tolerance \
				$transactional $token_value]
	} msg]} {
		_err $msg
	}
	return $ret
}



proc ob_bet::cust_decline_async_offer {bet_id {ignore_offer_time 0} {expiry_tolerance 0}} {

	# Log input params
	ob_log::write INFO {BET - API(cust_decline_async_offer): $bet_id}

	if {[catch {
		set ret [_decline_async_offer $bet_id $ignore_offer_time $expiry_tolerance]
	} msg]} {
		_err $msg
	}
	return $ret
}



proc ob_bet::cust_cancel_async_bet {bet_id has_offer {ignore_offer_time 0}} {

	# Log input params
	ob_log::write INFO {BET - API(cust_cancel_async_bet): $bet_id}

	if {[catch {
		set ret [_cancel_async_bet $bet_id $has_offer $ignore_offer_time]
	} msg]} {
		_err $msg
	}
	return $ret
}



# Create an offer from bet packages. It is the responsibility of the caller to enforce
# permissions
#   adminuser - username of operator
#   bet_id    - as in tBet.bet_id
#   expiry    - ifx expiry date of offer
#   stake_per_line - Offer Stake per line (as in tBet.stake_per_line) (2dp)
#   leg_type       - Offer leg type (W|P|E)
#
proc ob_bet::cust_ins_async_bet_offer {
	adminuser
	bet_id
	expiry
	status
	stake_per_line
	leg_type
} {
	ob_log::write INFO {BET - API(cust_ins_async_bet_offer): $bet_id $stake_per_line}

	if {[catch {
		set ret [_cust_ins_async_bet_offer\
						$adminuser\
						$bet_id\
						$expiry\
						$status\
						$stake_per_line\
						$leg_type]
	} msg]} {
		_err $msg
	}
	return $ret
}


# Temporarily disable async betting.
# After attempting to place bets, having some of them parked and getting offers
# back from traders, when you want to accept the offers and place the remaining
# bets, you don't want one of them to trigger async again.
# To prevent this from happening, use ob_bet::disable_async which will disable
# async for the current betslip.
proc ob_bet::disable_async {} {
	variable BET

	set BET(async_disabled) Y
}


#END OF API..... private procedures



# Prepare async DB queries
proc ob_bet::_prepare_async_qrys {} {

	# Get currently-parked bets
	ob_db::store_qry ob_bet::get_cust_async_bets {
		select
			a.bet_id
		from
			tBetAsync a,
			tBet b
		where
			a.acct_id = ?        and
			a.bet_id  = b.bet_id and
			b.status  = 'P'
		order by bet_id
	}

	# Get recent async bets which have been declined/canceled
	ob_db::store_qry ob_bet::get_cust_recent_dec_async_bets [subst {
		select
			b.bet_id,
			o.o_num,
			o.o_den,
			o.ev_oc_id,
			o.price_type,
			b.bet_type,
			t.num_selns
		from
			tAsyncBetOff a,
			tOBet o,
			tBet b,
			tBetType t
		where
			a.bet_id      = b.bet_id
		and o.bet_id      = b.bet_id
		and b.bet_type    = t.bet_type
		and b.acct_id     = ?
		and a.status in ('D','C')
		and b.cr_date >= CURRENT - INTERVAL([_get_config async_bet_recent_time]) hour to hour
	}]

	# Get async offer for a bet
	ob_db::store_qry ob_bet::get_async_offer {
		select
			bo.cr_date,
			bo.expiry_date,
			bo.status,
			bo.off_stake_per_line,
			bo.org_stake_per_line,
			bo.reason_code,
			bo.accept_status,
			bo.leg_type,
			bo.org_leg_type,
			bo.reason_text,
			bo.park_reason,
			ua.username as trader_uname,
			lo.leg_no,
			lo.part_no,
			lo.off_p_num,
			lo.off_p_den,
			lo.org_p_num,
			lo.org_p_den,
			lo.off_price_type
		from
			tAsyncBetOff bo,
			tAdminUser ua,
			outer tAsyncBetLegOff lo
		where
			bo.bet_id = ? and
			lo.bet_id = bo.bet_id and
			bo.user_id = ua.user_id
		order by lo.leg_no, lo.part_no
	}

	# Get async offer for a bet
	ob_db::store_qry ob_bet::get_async_offer_full {
		select
			bo.cr_date,
			bo.expiry_date,
			bo.status,
			bo.accept_status,
			bo.park_reason,
			bo.reason_text,
			ua.username as trader_uname,
			xc.code as reason_code,
			nvl(bo.off_stake_per_line, b.stake_per_line) as off_stake_per_line,
			nvl(bo.org_stake_per_line, b.stake_per_line) as org_stake_per_line,
			nvl(bo.leg_type, b.leg_type)                 as leg_type,
			nvl(bo.org_leg_type, b.leg_type)             as org_leg_type,
			oc.ev_oc_id,
			oc.ev_mkt_id,
			oc.desc,
			o.leg_no,
			o.part_no,
			nvl(lo.off_p_num,o.o_num)           as off_p_num,
			nvl(lo.off_p_den,o.o_den)           as off_p_den,
			nvl(lo.org_p_num,o.o_num)           as org_p_num,
			nvl(lo.org_p_den,o.o_den)           as org_p_den,
			nvl(lo.off_price_type,o.price_type) as off_price_type,
			nvl(lo.org_price_type,o.price_type) as org_price_type
		from
			tAsyncBetOff bo,
			tAdminUser ua,
			tOBet o,
			tBet b,
			tEvOc oc,
			outer tAsyncBetLegOff lo,
			outer tXlateCode xc
		where
			bo.bet_id = ? and
			b.bet_id  = bo.bet_id and
			bo.bet_id = o.bet_id and
			bo.bet_id = lo.bet_id and
			o.leg_no = lo.leg_no and
			o.part_no = lo.part_no and
			o.ev_oc_id = oc.ev_oc_id and
			xc.code_id = bo.reason_code and
			bo.user_id = ua.user_id
		order by o.leg_no, o.part_no
	}

	ob_db::store_qry ob_bet::async_apply_offer {
		execute procedure pAsyncApplyOffer (
			p_bet_id            = ?,
			p_acct_id           = ?,
			p_r4_limit          = ?,
			p_ignore_offer_time = ?,
			p_expiry_tolerance  = ?,
			p_transactional     = ?,
			p_token_value       = ?
		)
	}

	ob_db::store_qry ob_bet::async_decline_offer {
		execute procedure pAsyncDeclineOffer (
			p_bet_id            = ?,
			p_acct_id           = ?,
			p_r4_limit          = ?,
			p_rtn_freebet_can   = ?,
			p_return_freebet    = ?,
			p_ignore_offer_time = ?,
			p_expiry_tolerance  = ?,
			p_manual_cancel     = 'Y'
		)
	}

	ob_db::store_qry ob_bet::async_cancel_bet {
		execute procedure pAsyncCancelBet (
			p_bet_id            = ?,
			p_acct_id           = ?,
			p_has_offer         = ?,
			p_r4_limit          = ?,
			p_ignore_offer_time = ?,
			p_manual_cancel     = 'Y'
		)
	}

	ob_db::store_qry ob_bet::async_park_bet {
		execute procedure pAsyncParkBet (
			p_bet_id        = ?,
			p_park_reason   = ?,
			p_async_timeout = ?
		)
	}

	ob_db::store_qry ob_bet::async_override_bet {
		execute procedure pAsyncOverrideBet (
			p_bet_id         = ?,
			p_acct_id        = ?,
			p_leg_type       = ?,
			p_stake_per_line = ?,
			p_transactional  = ?
		)
	}

	ob_db::store_qry ob_bet::async_override_leg {
		execute procedure pAsyncOverrideLeg (
			p_bet_id         = ?,
			p_acct_id        = ?,
			p_leg_no         = ?,
			p_part_no        = ?,
			p_price_type     = ?,
			p_p_num          = ?,
			p_p_den          = ?,
			p_transactional  = ?
		)
	}

	# This is a variant XL method, so cache for 10 minutes
	ob_db::store_qry ob_bet::get_async_reason_code {
		select  c.code,
				x.xlation_1,
				x.xlation_2,
				x.xlation_3,
				x.xlation_4
		from    tXlateCode c,
		outer	tXlateVal x
		where   c.code_id = ?
		and     x.code_id = c.code_id
		and     x.lang = ?
	} 600

	ob_db::store_qry ob_bet::get_async_channel_enabled {
		select
			1
		from
			tChannel
		where
			async_betting = 'Y' and
			channel_id = ?
	} 600

	ob_db::store_qry ob_bet::get_async_selns_enabled {
		select
		  s.ev_oc_id,
		  decode(c.async_betting||t.async_betting,'YY', 'Y', 'N') async_betting
		from
		  tevoc 	s,
		  tev 		e,
		  tevtype 	t,
		  tevclass 	c
		where
		  s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
		  s.ev_id = e.ev_id and
		  e.ev_type_id = t.ev_type_id and
		  t.ev_class_id = c.ev_class_id
	}

	ob_db::store_qry ob_bet::ins_async_offer {
		execute procedure pInsAsyncBetOff(
			p_adminuser    = ?,
			p_bet_id       = ?,
			p_expiry_date  = ?,
			p_status       = ?,
			p_off_stake    = ?,
			p_off_leg_type = ?
		)
	}

	ob_db::store_qry ob_bet::chk_bet_intercept {
		execute procedure pChkBetIntercept(
			p_ev_oc_id        = ?,
			p_ev_mkt_id       = ?,
			p_price_type      = ?,
			p_lp_num          = ?,
			p_lp_den          = ?,
			p_sp_num          = ?,
			p_sp_den          = ?,
			p_stake           = ?
		)
	}
}

proc ob_bet::_async_enabled {} {

	variable BET

	if {[info exists BET(async_disabled)] && $BET(async_disabled)} {
		ob_log::write INFO {Async is temporarily disabled}
		return N
	}

	if {[_get_config async_bet] == "Y" && [ob_control::get async_bet] == "Y"} {

		# If this is a bet-in-running bet and bir_async_bet is globally disabled,
		# the systems should not go async for this bet.

		if {$BET(bet_delay) != 0 && [ob_control::get bir_async_bet] == "N"} {
			return N
		}

		# if the number of bets on the slip is greater
		# than the traders want, turn async off
		if {[_get_config async_num_bet] != -1} {
			if {$BET(num) > [_get_config async_num_bet]} {
				return N
			}
		}

		# is it on this channel
		if {[catch {
			set rs [ob_db::exec_qry ob_bet::get_async_channel_enabled [_get_config source]]
		} msg]} {
			error\
				"Unable to retrieve async channel enabled from db: $msg"\
				""\
				"ASYNC_DB_ERROR"
		}

		set n_rows [db_get_nrows $rs]
		ob_db::rs_close $rs

		if {$n_rows == 0} {
			return N
		}

	} else {
		return N
	}

	return Y
}

proc ob_bet::_async_enabled_hier {bet_num} {

	variable BET
	variable GROUP
	variable SELN
	variable LEG
	variable MAX_SELN_PLACEHOLDERS

	set selns [list]

	set group_id $BET($bet_num,group_id)
	for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
		foreach leg $GROUP($group_id,$sg,legs) {
			set i [lindex $leg 0]
			set ev_oc_ids [lindex [_get_leg $i selns] 1]
			foreach ev_oc_id $ev_oc_ids {
				if {[lsearch $selns $ev_oc_id] == -1} {
					lappend selns $ev_oc_id
				}
			}
		}
	}

	# now we have a unique list of selections for the whole bet
	# lets see if they are valid

	# can only get up to MAX_SELN_PLACEHOLDERS selections at a time
	# So may need to call this query a number of times
	set num_selns   [llength $selns]
	set num_places  $MAX_SELN_PLACEHOLDERS
	set num_fillers [expr {$num_places - ($num_selns % $num_places)}]

	# Pad out selns and ocv_ids so that it has enough to fill up
	# the placeholders in the query
	set padded_selns   $selns
	for {set i 0} {$i < $num_fillers} {incr i} {
		lappend padded_selns -1
	}

	for {set l 0} {$l < $num_selns} {incr l $num_places} {

		# build up the query string
		set seln_subset [lrange $padded_selns $l   [expr {$l + $num_places - 1}]]
		set qry "ob_db::exec_qry ob_bet::get_async_selns_enabled $seln_subset"

		# execute the selns query and retrieve the results
		if {[catch {set rs [eval $qry]} msg]} {
			error\
				"Unable to retrieve async selection info from db: $msg"\
				""\
				"ASYNC_DB_ERROR"
		}
		set n_rows [db_get_nrows $rs]

		for {set r 0} {$r < $n_rows} {incr r} {
			# as soon as one of the selections has a N
			# we can bomb out
			set ev_oc_id      [db_get_col $rs $r ev_oc_id]
			set async_betting [db_get_col $rs $r async_betting]

			if {$async_betting == "N"} {
				ob_db::rs_close $rs
				ob_log::write ERROR {BET - ev_oc_id $ev_oc_id suspended for async betting}
				return N
			}
		}

		ob_db::rs_close $rs

	}

	if {[_get_config async_no_intercept_grp] != ""} {
		# now check the liab group at this level
		# certain liab group we never referrer
		set group_id        $BET($bet_num,group_id)
		set liab_group      [lindex [_get_cust_ev_lvl_limits $group_id] 2]

		ob_log::write ERROR {BET - Checking no intercept grp [_get_config async_no_intercept_grp] against $liab_group}

		if {$liab_group != "" && $liab_group == [_get_config async_no_intercept_grp]} {
			ob_log::write ERROR {BET - group $BET($bet_num,group_id) - liab group $liab_group never referred}
			return N
		}
	}

	return Y

}



proc ob_bet::_get_cust_async_bets {acct_id} {

	if {[catch {
		set rs [ob_db::exec_qry ob_bet::get_cust_async_bets $acct_id]
	} msg]} {
		error\
			"Unable to retrieve parked bets from db: $msg"\
			""\
			"ASYNC_DB_ERROR"
	}

	set n_rows [db_get_nrows $rs]
	set bet_ids [list]
	for {set r 0} {$r < $n_rows} {incr r} {
		set bet_id [db_get_col $rs $r bet_id]
		lappend bet_ids $bet_id
	}
	ob_db::rs_close $rs

	return $bet_ids
}



proc ob_bet::_get_async_offer {bet_id {full_details N}} {
	if {$full_details} {
		# Get details for all legs rather than just the ones that have changed
		set query ob_bet::get_async_offer_full
	} else {
		# Get details for legs that have changed
		set query ob_bet::get_async_offer
	}

	if {[catch {
		set rs [ob_db::exec_qry $query $bet_id]
	} msg]} {
		error\
			"Unable to retrieve parked bet offer from db: $msg"\
			""\
			"ASYNC_DB_ERROR"
	}

	set n_rows [db_get_nrows $rs]

	if {$n_rows > 0} {
		set ASYNC_OFF(offer_found) Y
		foreach c {
			cr_date
			expiry_date
			status
			off_stake_per_line
			org_stake_per_line
			reason_code
			accept_status
			leg_type
			org_leg_type
			park_reason
			reason_text
			trader_uname
		} {
			set $c [db_get_col $rs 0 $c]
			set ASYNC_OFF($c) [db_get_col $rs 0 $c]
		}
		if {$full_details || [lsearch [list P B F G] $status] > -1} {
			set cols {
				leg_no
				part_no
				off_p_num
				off_p_den
				org_p_num
				org_p_den
				off_price_type}

			if {$full_details} {
				lappend cols org_price_type ev_oc_id ev_mkt_id desc
			}

			for {set r 0} {$r < $n_rows} {incr r} {
				foreach c $cols {
					set $c [db_get_col $rs $r $c]
				}
				foreach c $cols {
					set ASYNC_OFF(leg,$leg_no,part,$part_no,$c)\
						[db_get_col $rs $r $c]
				}
				lappend ASYNC_OFF(legs) $leg_no
				lappend ASYNC_OFF(leg,$leg_no,parts) $part_no
			}
		}
		if {[clock seconds] > [clock scan $expiry_date]} {
			set ASYNC_OFF(expired) Y
			set ASYNC_OFF(seconds_to_expiry) 0
		} else {
			set ASYNC_OFF(expired) N
			set ASYNC_OFF(seconds_to_expiry)\
			    [expr {[clock scan $expiry_date] - [clock seconds]}]
		}
	} else {
		set ASYNC_OFF(offer_found) N
	}
	ob_db::rs_close $rs

	return [array get ASYNC_OFF]
}



proc ob_bet::_accept_async_offer {
	bet_id
	{ignore_offer_time 0}
	{expiry_tolerance 0}
	{transactional Y}
	{token_value 0}
} {

	variable CUST

	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			ASYNC_NO_CUST
	}

	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

	if {[catch {
		set rs [ob_db::exec_qry ob_bet::async_apply_offer $bet_id $CUST(acct_id) \
				$r4_limit $ignore_offer_time $expiry_tolerance $transactional \
				$token_value]
	} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to apply async offer: $msg"\
			""\
			$err_code
	}

	set type    [db_get_coln $rs 0 0]
	set status  [db_get_coln $rs 0 1]
	set level   [db_get_coln $rs 0 2]

	ob_db::rs_close $rs

	return [list 1 [list $type $status $level]]
}



proc ob_bet::_decline_async_offer {bet_id {ignore_offer_time 0} {expiry_tolerance 0}} {

	variable CUST

	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			ASYNC_NO_CUST
	}
	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

	if {[OT_CfgGet RETURN_FREEBETS_VOID "TRUE"] == "TRUE"} {
		set return_freebets Y
	} else {
		set return_freebets N
	}

	if {[OT_CfgGet RETURN_FREEBETS_CANCEL "TRUE"] == "TRUE"} {
		set return_freebets_cancel Y
	} else {
		set return_freebets_cancel N
	}

	if {[catch {ob_db::exec_qry ob_bet::async_decline_offer $bet_id \
			$CUST(acct_id) $r4_limit $return_freebets_cancel $return_freebets \
				$ignore_offer_time $expiry_tolerance} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to decline async offer: $msg"\
			""\
			$err_code
	}

	return 1
}



proc ob_bet::_cancel_async_bet {bet_id has_offer {ignore_offer_time 0} } {
	variable CUST

	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			ASYNC_NO_CUST
	}

	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

	if {[catch {ob_db::exec_qry ob_bet::async_cancel_bet $bet_id $CUST(acct_id) \
		$has_offer $r4_limit $ignore_offer_time} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to cancel async bet: $msg"\
			""\
			$err_code
	}

	return 1
}


proc ob_bet::cancel_async_bet_group { bet_group_id has_offer ignore_offer_time } {

	variable BET

	for {set b 0} {$b < $BET(num)} {incr b} {

		if { $BET($b,bet_group_id) == $bet_group_id } {

			if {[catch {
				set ret [_cancel_async_bet $BET($b,bet_id) $has_offer $ignore_offer_time]
			} msg]} {
				_err $msg
			}
		}
	}
}


proc ob_bet::_cust_ins_async_bet_offer {
	adminuser
	bet_id
	expiry
	status
	stake_per_line
	leg_type
} {
	if {$stake_per_line == "" && $leg_type == ""} {
		return 1
	}

	if {[catch {
		ob_db::exec_qry ob_bet::ins_async_offer\
			$adminuser \
			$bet_id \
			$expiry \
			$status \
			$stake_per_line \
			$leg_type \
	} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to insert offer : $msg"\
			""\
			$err_code
	}

	return 1
}

proc ob_bet::_override_async_leg {
	bet_id
	leg_no
	part_no
	price_type
	p_num
	p_den
	{transactional Y}
} {
	variable CUST

	# Don't bother doing anything if they don't want anything overriden
	if {$price_type == ""} {
		return 1
	}

	if {[catch {
		ob_db::exec_qry ob_bet::async_override_leg \
			$bet_id \
			$CUST(acct_id) \
			$leg_no \
			$part_no \
			$price_type \
			$p_num \
			$p_den \
			$transactional \
	} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to override async bet: $msg"\
			""\
			$err_code
	}

	return 1
}

proc ob_bet::_override_async_bet {
	bet_id
	leg_type
	stake_per_line
	{transactional Y}
} {
	variable CUST

	# Don't bother doing anything if they don't want anything overriden
	if {$leg_type == "" && $stake_per_line == ""} {
		return 1
	}

	# Check if the operator has permission

	if {[catch {
		ob_db::exec_qry ob_bet::async_override_bet \
			$bet_id \
			$CUST(acct_id) \
			$leg_type \
			$stake_per_line \
			$transactional
	} msg]} {
		set err_code [_get_async_err $msg]
		error\
			"Failed to override async bet: $msg"\
			""\
			$err_code
	}

	return 1
}

proc ob_bet::_async_intercept {} {
	variable BET
	variable FREEBET_CHECKS
	variable LEG
	variable SELN
	variable GROUP

	set fn {_async_intercept }
	for {set b 0} {$b < $BET(num)} {incr b} {

		# check to see if this bet has been flagged
		# for interception by _upd_liabs
		if {[info exists BET($b,liab)]} {

			set status [lindex $BET($b,liab) 1]

			if {$status == 5} {
				set BET($b,async_park) "Y"
				ob_log::write INFO \
					{BET - Asynchronous bet parked}
				ob_log::write INFO \
					{	due to liability limit being exceeded}

				if { $BET($b,async_already_parked) == "N" } {

					if { $BET($b,bet_group_id) == "" } {
						_async_park_bet \
							$BET($b,bet_id) \
							$BET($b,async_park_reason) \
							$b
					} else {
						_async_park_bet_group $BET($b,bet_group_id) 1
					}
				}

				# Remove from freebet checklist
				set group_id $BET($b,group_id)
				set num_ev_ocs 0

				# Need the total number of ev ocs
				for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
					foreach leg $GROUP($group_id,$sg,legs) {
						set num_ev_ocs [expr $num_ev_ocs + [llength $LEG($leg,selns)]]
					}
				}

				ob_log::write INFO {$fn: freebet_checklist=$FREEBET_CHECKS(checks)}

				# FREEBET_CHECKS(checks) list is [bet_id ev_ocs stake] so need +1 for stake
				set fb_end_idx   [expr $num_ev_ocs + 1]
				set fb_start_idx [lsearch $FREEBET_CHECKS(checks) $BET($b,bet_id)]
				ob_log::write DEV {$fn: num_ev_ocs=$num_ev_ocs,fb_end_idx=$fb_end_idx,fb_start_idx=$fb_start_idx}

				# Sanity check
				if {$fb_start_idx >= 0 && $fb_end_idx > $fb_start_idx} {
					set FREEBET_CHECKS(checks) [lreplace $FREEBET_CHECKS(checks) $fb_start_idx $fb_end_idx]
					ob_log::write INFO {$fn: freebet_checklist is now $FREEBET_CHECKS(checks)}
				}
			}
		}
	}
}

proc ob_bet::_async_park_bet {bet_id park_reason bet_num} {

	variable BET

	set BET($bet_num,async_already_parked) "Y"

	if {[catch {
		ob_db::exec_qry ob_bet::async_park_bet \
			$bet_id \
			$park_reason \
			$BET(async_timeout)
	} msg]} {

		set BET($bet_num,async_already_parked) "N"
		set err_code [_get_async_err $msg]
		error\
			"Failed to update bet to an async parked bet: $msg"\
			""\
			$err_code
	}
}


proc ob_bet::_async_park_bet_group { bet_group_id  {do_park 0} } {

	variable BET

	# Only mark group if the bet_group_id is not empty
	if {$bet_group_id == ""} {
		return
	}

	for {set b 0} {$b < $BET(num)} {incr b} {

		if {![info exists BET($b,bet_group_id)]} {
			continue
		}

		if { $BET($b,bet_group_id) == $bet_group_id } {

			set BET($b,async_park) "Y"

			# If there is no reason, this bet is referred because
			# it's part of group only, so set a blank reason to avoid errors
			if {![info exists BET($b,async_park_reason)]} {
				set BET($b,async_park_reason) "GROUP_REFERRAL"

			}

			if { $do_park && $BET($b,async_already_parked) == "N" } {
				_async_park_bet \
					$BET($b,bet_id) \
					$BET($b,async_park_reason) \
					$b 
			}
		}
	}
}

# Parse exception to see what error code we should raise
#
proc ob_bet::_get_async_err {msg} {

	variable ASYNC_APPLY_OFFER_ERRS

	if {[regexp {(AS\d\d\d):} $msg -> as_code]} {

		if {[info exists ASYNC_APPLY_OFFER_ERRS($as_code)]} {
			set err_code $ASYNC_APPLY_OFFER_ERRS($as_code)
		} else {
			set err_code ASYNC_OFF_FAIL
		}
	} else {
		set err_code ASYNC_OFF_FAIL
	}

	return $err_code
}

#
# It checks whether the user has placed a similar bet to the current one
# in the last hour.
#
proc ob_bet::_async_resub_check {bet_num} {

	variable BET
	variable GROUP
	variable SELN
	variable LEG
	variable CUST

	# check that we can actually check something
	if {[_get_config async_bet_recent_time] == 0} {
		return "OK"
	}

	set group_id $BET($bet_num,group_id)
	set bet_type $BET($bet_num,bet_type)

	if {[catch {
		set rs [ob_db::exec_qry ob_bet::get_cust_recent_dec_async_bets $CUST(acct_id)]
	} msg]} {
		error\
			"Unable to retrieve recent async bets from db: $msg"\
			""\
			"ASYNC_DB_ERROR"
	}

	set n_rows [db_get_nrows $rs]
	set checked_bet_id -1
	for {set r 0} {$r < $n_rows} {incr r} {

		set r_bet_type   [db_get_col $rs $r bet_type]
		set r_ev_oc_id   [db_get_col $rs $r ev_oc_id]
		set r_price_type [db_get_col $rs $r price_type]
		set r_lp_num     [db_get_col $rs $r o_num]
		set r_lp_den     [db_get_col $rs $r o_den]
		set r_num_selns  [db_get_col $rs $r num_selns]
		set r_bet_id     [db_get_col $rs $r bet_id]

		if {$checked_bet_id != $r_bet_id} {

			# keep track of how many selns match up
			# if this equals the no selns in the bet
			# then the customer is trying to resubmit the bet
			set num_selns_matched 0

			set checked_bet_id $r_bet_id
		}

		ob_log::write DEV {BET - ASYNC trying to match $checked_bet_id}

		# If the bet types don't match, then carry on now
		if {$r_bet_type != $bet_type} {
			continue
		}

		for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
			foreach leg $GROUP($group_id,$sg,legs) {
				set i [lindex $leg 0]
				set ev_oc_ids [lindex [_get_leg $i selns] 1]

				foreach ev_oc_id $ev_oc_ids {

					# Is the customer trying to bet on the same selection again
					if {$r_ev_oc_id != $ev_oc_id} {
						continue
					}

					ob_log::write DEV {BET - ASYNC ev_oc_id match $r_ev_oc_id = $ev_oc_id}

					set price_type [lindex [_get_leg $i price_type] 1]

					if {$r_price_type != $price_type} {
						continue
					}

					ob_log::write DEV {BET - ASYNC price_type match $r_price_type = $price_type}

					# if the bet is SP then no need to check any further
					if {[lsearch {L G} $price_type] == -1} {
						ob_log::write DEV {BET - ASYNC SP bet}
						incr num_selns_matched
					} else {
						set lp_den [lindex [_get_leg $i lp_den] 1]
						set lp_num [lindex [_get_leg $i lp_num] 1]

						ob_log::write DEV {BET - ASYNC price match $r_lp_num == $lp_num && $r_lp_den == $lp_den}

						if {$r_lp_num == $lp_num && $r_lp_den == $lp_den} {

							incr num_selns_matched
						}
					}
				}
			}
		}

		ob_log::write DEV {BET - ASYNC matched selns $r_num_selns  == $num_selns_matched}

		if {$r_num_selns  == $num_selns_matched} {
			# found a matching bet, so return
			ob_db::rs_close $rs
			ob_log::write ERROR {BET - Bet matches previous Async attempt $r_bet_id}
			return "MATCHED"
		}
	}

	ob_db::rs_close $rs

	# if we get to here we haven't matched anything
	return "OK"

}

proc ob_bet::_async_park_checks {b group_id bet_group_id} {

	variable BET
	variable GROUP
	variable CUST_DETAILS

	# check bet stake rule
	set system_ccy_stake [expr {
		$BET($b,stake) / $CUST_DETAILS(exch_rate)
	}]

	if {$BET(async_bet_rules) == "Y"} {

		if {$system_ccy_stake > $BET(async_rule_stk1)} {
			set BET($b,async_park) "Y"
			# Stake exceeds async rule 1 stake
			set BET($b,async_park_reason) ASYNC_PARK_STK_GT_ASYNC_RULE1
			ob_log::write INFO \
				{BET - BET INTERCEPTED:}
			ob_log::write INFO \
				{	stake $BET($b,stake) greater than...}
			ob_log::write INFO \
				{	async_rule_stk1 $BET(async_rule_stk1)}

		}

		ob_log::write INFO {BET - ASYNC checking liab rule $system_ccy_stake > $BET(async_rule_stk2)}

		# check liab rule (but only if bet is a single)
		if {$BET($b,async_park) == "N" &&
			$BET($b,bet_type) == "SGL" &&
			$GROUP($group_id,num_legs) == 1 &&
			$system_ccy_stake > $BET(async_rule_stk2)
		} {
			# Check liab rule (but only if bet is a single)

			# Get the ev_oc_id via the bet's group and leg
			set legs [lindex [_get_group $group_id legs] 1]
			set leg  [lindex $legs 0]
			set ev_oc_ids [lindex [_get_leg $leg selns] 1]
			set ev_oc_id  [lindex $ev_oc_ids 0]

			set event_liability [_get_ev_sgl_liab $ev_oc_id M]

			if {$event_liability > $BET(async_rule_liab)} {
				set BET($b,async_park) "Y"
				# Market liability exceeds async rule liability threshold
				set BET($b,async_park_reason) ASYNC_PARK_MKT_LIAB_GT_ASYNC_RULE_LIAB
				ob_log::write INFO \
					{BET - BET INTERCEPTED}
				ob_log::write INFO \
					{BET - Asynchronous bet park liab rule: stake}
				ob_log::write INFO \
					{	$BET($b,stake) greater than async_rule_stk2}
				ob_log::write INFO \
					{	$BET(async_rule_stk2) and event liab}
				ob_log::write INFO \
					{	$event_liability greater than async_rule_liab}
				ob_log::write INFO \
					{	$BET(async_rule_liab)}

			}
		}
	}

	# potential payout
	set system_ccy_spl [expr {$BET($b,stake_per_line) / $CUST_DETAILS(exch_rate)}]

	ob_log::write INFO {BET - ASYNC checking payout with $system_ccy_spl $group_id $BET($b,bet_type) $BET($b,leg_type)}

	set pot_payout [_get_pot_payout $system_ccy_spl $group_id $BET($b,bet_type) $BET($b,leg_type)]

	if {$BET($b,async_park) == "N" && $BET(async_max_payout) > 0 && $pot_payout > $BET(async_max_payout)} {
		set BET($b,async_park) "Y"
		# Estimated winnings exceed async max payout
		set BET($b,async_park_reason) ASYNC_PARK_BET_PAYOUT_GT_ASYNC_MAX_PAYOUT
		ob_log::write INFO {BET - BET INTERCEPTED:}
		ob_log::write INFO {      Estimated Payout $pot_payout > Async max payout $BET(async_max_payout)}

	}

	# check multiples risky bet limits
	if {$BET($b,async_park) == "N" &&
		$BET($b,bet_type) != "SGL" &&
		![_check_mul_stake_win_limits $b]} {
		set BET($b,async_park) "Y"
		ob_log::write INFO {BET - BET INTERCEPTED}
	}

	if {[_get_config async_enable_intercept] == "Y"} {
		set intercept_value [lindex [_get_cust_ev_lvl_limits $group_id] 1]
	} else {
		set intercept_value ""
	}

	# liability grp intercept value
	if {$BET($b,async_park) == "N" &&
		$intercept_value != "" &&
		$BET($b,stake) > $intercept_value
	} {
		set BET($b,async_park) "Y"
		# Stake exceeds customer liability group intercept value
		set BET($b,async_park_reason) ASYNC_PARK_STK_GT_LIAB_GRP_INTERCEPT
		ob_log::write INFO \
			{BET - BET INTERCEPTED:}
		ob_log::write INFO \
			{	bet stake $BET($b,stake) greater than...}
		ob_log::write INFO \
			{	customer liab group intercept value $intercept_value}
	}

	# parked bet will override bet delay
	if {$BET($b,async_park) == "Y" && $BET(bet_delay)} {
		set BET(bet_delay) 0
		_log WARNING "Asynchronous bet park disabled bet_delay"
	}

	# check whether we need to intercept based on liability
	if {[lindex [_get_bet $b async_park] 1] == "N" &&
		[lindex [_get_bet $b bet_type] 1] == "SGL" &&
		[llength [set leg [lindex [_get_group $group_id legs] 1]]] == 1 &&
		[llength [set ev_oc_id [lindex [_get_leg $leg selns] 1]]] == 1 &&
		[_get_config async_enable_liab] == "Y" &&
		[_get_config async_do_liab_on_check] == "Y"} {

		set stk [expr {[lindex [_get_bet $b stake] 1] / $CUST_DETAILS(exch_rate)}]
		if {[_get_config inc_plc_in_constr_liab] != "Y"} {
			set leg_type [lindex [_get_bet $b leg_type] 1]
			if {$leg_type == "E"} {
				set stk [expr { $stk / 2.0 }]
			} elseif {$leg_type == "P"} {
				set stk 0.0
			}
		}

		set intercept [_intercept_bet_liab \
				$ev_oc_id \
				[lindex [_get_oc $ev_oc_id ev_mkt_id] 1] \
				[lindex [_get_leg $leg price_type] 1] \
				[lindex [_get_leg $leg lp_num] 1] \
				[lindex [_get_leg $leg lp_den] 1] \
				[lindex [_get_oc $ev_oc_id sp_num_guide] 1] \
				[lindex [_get_oc $ev_oc_id sp_den_guide] 1] \
				$stk \
		]

		if {$intercept} {
			set reason ASYNC_PARK_BET_EXCEEDS_LIAB_LIMIT
			set BET($b,async_park) "Y"
			set BET($b,async_park_reason) $reason
			ob_log::write INFO {BET - BET INTERCEPTED: $reason}
		}
	}

	# if we parked, attempt to park entire group (proc will handle
	# case where group not set)
	if {$BET($b,async_park) == "Y"} {
		_async_park_bet_group $BET($b,bet_group_id) 0
	}

}

# Bet interception logic:
# 1) Determine how many bet legs are considered 'risky'. If any selection
#    within a leg is 'risky' then the whole leg is 'risky'.
# 2) A selection is 'risky' if the selection max bet (NOT the customer max bet
#    for the selection) is less than tControl.risky_max_bet
# 3) Depending on the number of legs in the bet and the number of risky legs,
#    look up the bet limit and win limit from tMulRiskLimit.
# 4) For each bet line inside the Multiple bet, if either the bet limit
#    or the win limit is exceeded, then intercept the bet.
#
#
# Returns 1 if OK
#         0 if not ok
proc ::ob_bet::_check_mul_stake_win_limits {bet_num} {

	variable BET
	variable CUST_DETAILS
	variable GROUP
	variable SELN
	variable LEG

	set group_id $BET($bet_num,group_id)
	set legs     [lindex [_get_group $group_id legs] 1]
	set leg_type $BET($bet_num,leg_type)

	set risky_max_bet [ob_control::get risky_max_bet]
	set bet_type $BET($bet_num,bet_type)
	set min_combi [lindex [_get_type $bet_type min_combi] 1]
	set max_combi [lindex [_get_type $bet_type max_combi] 1]
	set stake_per_line [expr {$BET($bet_num,stake_per_line)/$CUST_DETAILS(exch_rate)}]

	ob_log::write DEBUG {_check_mul_stake_win_limits: risky_max_bet=$risky_max_bet}
	ob_log::write DEBUG {                             bet_type=$bet_type}
	ob_log::write DEBUG {                             min_combi=$min_combi}
	ob_log::write DEBUG {                             max_combi=$max_combi}
	ob_log::write DEBUG {                             stake_per_line=$stake_per_line}

	set num_legs [lindex [_get_type $bet_type num_selns] 1]

	if {$min_combi == $max_combi} {

		#
		# Work out how many risky legs we have in the bet. If the risky max
		# value has not been set, we assume there will have no risky legs
		#
		set num_legs_risky 0
		set price_list [list]

		for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
			foreach leg $GROUP($group_id,$sg,legs) {
				set i [lindex $leg 0]
				set ev_oc_ids [lindex [_get_leg $i selns] 1]

				foreach ev_oc_id $ev_oc_ids {
					if {$risky_max_bet != "" &&
						$SELN($ev_oc_id,max_bet) <= $risky_max_bet} {
						incr num_legs_risky
						break
					}
				}

				set lp_den       [lindex [_get_leg $i lp_den] 1]
				set lp_num       [lindex [_get_leg $i lp_num] 1]
				set price_type   [lindex [_get_leg $i price_type] 1]
				set sp_num_guide [lindex [_get_leg $i sp_num_guide] 1]
				set sp_den_guide [lindex [_get_leg $i sp_den_guide] 1]

				set price [_get_leg_comparison_price $i $leg_type]

				lappend price_list $price
			}
		}
		ob_log::write DEBUG {             num_legs_risky=$num_legs_risky}
		ob_log::write DEBUG {             num_legs=$num_legs}

		#
		# Here we are assuming that we are dealing with simple combinations, e.g.
		# doubles from 3 selections, trebles from 10 selections, and NOT
		# complex bets like Patience or Lucky 15. All the bet lines will have
		# the same number of legs. Otherwise we will have to go through every
		# bet line and work out the number of risky legs in each bet line.
		#

		# What are the Win Limit and Bet Limit we need to consider?
		#
		if {$num_legs_risky > $num_legs} {
			#
			# We may have counted more risky legs than we need to consider
			#
			set num_legs_risky $num_legs
		}

		foreach {win_limit bet_limit} \
						[_get_mul_risk_limits $num_legs $num_legs_risky] {break}

		ob_log::write DEBUG {win_limit=$win_limit   bet_limit=$bet_limit}

		if {$bet_limit != "" && $stake_per_line >= $bet_limit} {
			ob_log::write INFO \
				{::ob_bet::_check_mul_stake_win_limits BET stake_per_line $stake_per_line > BET_LIMIT $bet_limit (num_legs $num_legs, num_legs_risky $num_legs_risky)}
			# Stake per line exceeds risky leg bet limit
			set BET($bet_num,async_park_reason) ASYNC_PARK_SPL_GT_RISKY_LEG_BET_LMT
			return 0
		}

		# Consider the worst case scenario. Get the highest odds for legs
		#
		if {$win_limit == ""} {
			return 1
		}
		set price_list [lsort -decreasing -real $price_list]

		set price_list [lrange $price_list 0 [expr {$num_legs-1}]]

		set price_product [eval expr [join $price_list "*"]]

		set win [expr {($price_product * $stake_per_line) - $stake_per_line}]

		if {$win >= $win_limit} {
			ob_log::write INFO \
				{::ob_bet::_check_mul_stake_win_limits WIN win $win > WIN_LIMIT $win_limit (num_legs $num_legs, num_legs_risky $num_legs_risky)}
			# Win exceeds risky leg win limit
			set BET($bet_num,async_park_reason) ASYNC_PARK_BET_WIN_GT_RISKY_LEG_WIN_LMT
			return 0
		}
	} else {

		#
		# Go through each bet line
		#
		set bet_lines [_bet_type_lines $bet_type]
		foreach bet_line $bet_lines {

			set num_legs_risky 0

			set price_list [list]

			foreach i $bet_line {

				set leg_num [lindex $legs $i]

				foreach v {lp_num lp_den price_type sp_num_guide sp_den_guide} {
					set $v [lindex [_get_leg $leg_num $v] 1]
				}

				set price [_get_leg_comparison_price $leg_num $leg_type]

				lappend price_list $price

				if {$risky_max_bet != ""} {
					set ev_oc_ids [lindex [_get_leg $leg_num selns] 1]
					foreach ev_oc_id $ev_oc_ids {
						if {$SELN($ev_oc_id,max_bet) <= $risky_max_bet} {
							incr num_legs_risky
							break
						}
					}
				}
			}

			set num_legs [llength $bet_line]

			foreach {win_limit bet_limit} \
				[_get_mul_risk_limits $num_legs $num_legs_risky] {break}

			ob_log::write DEBUG {win_limit=$win_limit   bet_limit=$bet_limit}

			if {$bet_limit != "" && $stake_per_line >= $bet_limit} {
				ob_log::write INFO \
					{::ob_bet::_check_mul_stake_win_limits BET stake_per_line $stake_per_line > BET_LIMIT $bet_limit (num_legs $num_legs, num_legs_risky $num_legs_risky)}
				# Stake per line exceeds risky leg bet limit
				set BET($bet_num,async_park_reason) ASYNC_PARK_SPL_GT_RISKY_LEG_BET_LMT
				return 0
			}

			if {$win_limit == ""} {
				continue
			}
			set price_product [eval expr [join $price_list "*"]]

			set win [expr {($price_product * $stake_per_line) - $stake_per_line}]

			if {$win >= $win_limit} {
				ob_log::write INFO \
				{::ob_bet::_check_mul_stake_win_limits WIN win $win > WIN_LIMIT $win_limit (num_legs $num_legs, num_legs_risky $num_legs_risky)}
				# Win exceeds risky leg win limit
				set BET($b,async_park_reason) ASYNC_PARK_BET_WIN_GT_RISKY_LEG_WIN_LMT
				return 0
			}
		}
	}

	return 1
}



# Checks whether to intercept bet based on liabilties. This uses the same logic
# as pUpdConstr but without the constr table updates
#
# Returns 1 if should intercept
#         0 if not
proc ::ob_bet::_intercept_bet_liab {
	ev_oc_id
	ev_mkt_id
	price_type
	lp_num
	lp_den
	sp_num
	sp_den
	stake
} {

	set ret 1

	if {[catch {
			set rs [ob_db::exec_qry ob_bet::chk_bet_intercept\
					$ev_oc_id \
					$ev_mkt_id \
					$price_type \
					$lp_num \
					$lp_den \
					$sp_num \
					$sp_den \
					$stake]

			set intercept [db_get_coln $rs 0 0]
			ob_db::rs_close $rs

			if {$intercept == "Y"} {
				set ret 1
			} else {
				set ret 0
			}
	} msg]} {
		ob_log::write ERROR {Unable to execute ob_bet::chk_bet_intercept - $msg}
	}

	return $ret
}

::ob_bet::_log INFO "sourced async.tcl"
