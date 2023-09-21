################################################################################
# $Id: liability.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle the bet placement liability
#            summary field book tables
#            Updates the APC for handicap markets
#            Suspends markets and selections when gone over liability limit
#            Alerts when certain liability limits are reached
#            Retrieves the liability of a market for singles only
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#
#    No public procedures
#
################################################################################

namespace eval ob_bet {
	variable LIAB
}

#Prepare the liability DB queries
proc ob_bet::_prepare_liab_qrys {} {

	ob_db::store_qry ob_bet::is_liab_set {
		select
			NVL(mc.liab_limit,-1.0) mkt_liab_limit,
			NVL(sc.max_total,-1.0) seln_max_limit
		from
			tEvOcConstr sc,
			tEvMktConstr mc
		where
			sc.ev_mkt_id = mc.ev_mkt_id and
			sc.ev_oc_id = ?
	} 20

	ob_db::store_qry ob_bet::ins_sgl_liab {
		execute procedure pLiabSGLBetIns(
		  p_bet_id         = ?,
		  p_num_selns      = ?,
		  p_num_lines      = ?,
		  p_acct_id        = ?,
		  p_channel        = ?,
		  p_stake_per_line = ?,
		  p_leg_type       = ?,
		  p_ev_oc_id       = ?,
		  p_leg_sort       = ?,
		  p_price_type     = ?,
		  p_ep_active      = ?,
		  p_o_num          = ?,
		  p_o_den          = ?,
		  p_hcap_value     = ?,
		  p_ew_fac_num     = ?,
		  p_ew_fac_den     = ?,
		  p_ew_places      = ?,
		  p_bir_index      = ?,
		  p_bet_in_run     = ?
		)
	}

	ob_db::store_qry ob_bet::upd_constr {
		execute procedure pConstrUpd (
		  p_price_type = ?,
		  p_leg_sort   = ?,
		  p_lp_num     = ?,
		  p_lp_den     = ?,
		  p_sp_num     = ?,
		  p_sp_den     = ?,
		  p_stake      = ?,
		  p_ev_mkt_id  = ?,
		  p_ev_oc_id   = ?,
		  p_only_apc   = ?,
		  p_data_chg_ok = ?,
		  p_intercept      = ?,
		  p_intercept_hcap = ?
		)
	}

	ob_db::store_qry ob_bet::get_sgl_liability {
		execute procedure pConstrUpdChk (
			p_ev_oc_id = ?,
			p_type = ?
		)
	}

	ob_db::store_qry ob_bet::nightmode_susp {
		execute procedure pLbtNightModeSusp(
			p_seln_id   = ?
		)
	}

	ob_db::store_qry ob_bet::rum_insert {
		execute procedure pLEQBet (
			p_bet_type    = ?,
			p_bet_id      = ?,
			p_ev_mkt_id   = ?
		)
	}

	ob_db::store_qry ob_bet::get_channel_switch {
		select
			c.channel_id
		from
			tChannel c,
			tChannel cc,
			tChanGrpLink cgl
		where
			c.site_operator_id = cc.site_operator_id and
			c.channel_id       = cgl.channel_id and
			cc.channel_id      = ? and
			cgl.channel_grp    = ?
	}

}

#mark this leg as needing liability to be added
proc ::ob_bet::_add_liab {ev_oc_id leg bet} {
	variable LIAB

	_smart_reset LIAB

	lappend LIAB(liabs) [list $ev_oc_id $leg $bet]

	incr LIAB(num)
}



proc ::ob_bet::_lbt_night_mode_susp {seln} {
	# If there have been more than night_mode_max_apc price changes
	# since night mode has been turned on, then suspend all markets
	# belonging to the event that this selection occurs on.

	# If this function suspends any markets it will return 0
	# Else this function returns 1.

	set res [ob_db::exec_qry ob_bet::nightmode_susp $seln]
	return [db_get_coln $res 0 0]
}



#Update the liabilities in the DB
proc ::ob_bet::_upd_liabs {} {

	variable LIAB
	variable SELN
	variable LEG
	variable BET
	variable CUST
	variable CUST_DETAILS

	#we may not have any liabilities to update
	if {![info exists LIAB(liabs)]} {
		_log INFO "No liabilities to update"
		return
	}

	#to avoid deadlocking we will add the liability details in
	#ev_oc_id order
	set liabs [lsort -index 0 $LIAB(liabs)]

	foreach liab $liabs {
		foreach {ev_oc_id leg bet} $liab {break}

		if {$BET($bet,async_park) == "Y"} {
			_log INFO "Bet $bet is async parked so won't update liabilities"
			continue
		}

		set bet_type $BET($bet,bet_type)
		set group_id $BET($bet,group_id)

		#ew details
		if {
			$SELN($ev_oc_id,ew_with_bet) == "Y"
				&& ($BET($bet,leg_type) == "E" || $BET($bet,leg_type) == "P")
		} {
			set ew_fac_num $SELN($ev_oc_id,ew_fac_num)
			set ew_fac_den $SELN($ev_oc_id,ew_fac_den)
			set ew_places  $SELN($ev_oc_id,ew_places)
		} else {
			set ew_fac_num ""
			set ew_fac_den ""
			set ew_places  ""
		}

		if {$LEG($leg,price_type)=="G"
			|| $LEG($leg,price_type)=="L"} {
			set ep_active $SELN($ev_oc_id,ep_active)
		} else {
			set ep_active "N"
		}

		#add in liab override switch into tControl
		if {[ob_control::get enable_liab] != "Y" || [_get_config liabs] != "Y"} {
			set only_apc "Y"
		} else {
			set only_apc "N"
		}

		# Check to see if liabilities are turned on for this market
		set rs [ob_db::exec_qry ob_bet::is_liab_set $ev_oc_id]
		set mkt_liab_limit [db_get_col $rs 0 mkt_liab_limit]
		set seln_max_limit [db_get_col $rs 0 seln_max_limit]
		ob_db::rs_close $rs

		if {$mkt_liab_limit <= 0.0 && $seln_max_limit <= 0.0} {
			set only_apc "Y"
		}

		if {
			$BET(async_bet)                        == "Y" &&
			[_get_config async_enable_liab]        == "Y" &&
			[_get_config async_intercept_on_place] == "Y"
		} {
			set intercept "Y"
		} else {
			set intercept "N"
		}

		if {
			[ob_control::get enable_hcap_async]             &&
			[_get_config async_enable_liab]        == "Y"   &&
			[_get_config async_intercept_on_place] == "Y"
		} {
			set intercept_hcap "Y"
		} else {
			set intercept_hcap "N"
		}

		# Update the apc and check liab constraints
		_log INFO "Updating liab constr for $ev_oc_id"

		# The stake used to update the constr tables should be in base ccy.
		set constr_stk [expr {$BET($bet,stake) / $CUST_DETAILS(exch_rate)}]

		# Unless we're configured to include place stake, only take win stake
		# into account.
		# XXX I suspect that we over-estimate the payout when configured to
		# take place stake into account - shouldn't we examine the EW terms?

		if { $BET($bet,leg_type) == "E" && \
			[_get_config inc_plc_in_constr_liab] != "Y" } {
				set constr_stk [expr { $constr_stk / 2.0 }]
		} elseif { $BET($bet,leg_type) == "P" && \
			[_get_config inc_plc_in_constr_liab] != "Y" } {
			set constr_stk 0.0
		}

		set rs [ob_db::exec_qry ob_bet::upd_constr\
					$LEG($leg,price_type)\
					$LEG($leg,leg_sort)\
					$LEG($leg,lp_num)\
					$LEG($leg,lp_den)\
					$SELN($ev_oc_id,sp_num_guide)\
					$SELN($ev_oc_id,sp_den_guide)\
					$constr_stk\
					$SELN($ev_oc_id,ev_mkt_id)\
					$ev_oc_id\
					$only_apc\
					"Y"\
					$intercept\
					$intercept_hcap]

		set type   [db_get_coln $rs 0 0]
		set status [db_get_coln $rs 0 1]
		set level  [db_get_coln $rs 0 2]
		ob_db::rs_close $rs

		if {$status == 5} {
			# mark bet as async so that a monitor message may be sent out
			# about it later
			set BET($bet,async_park) "Y"
			# Bet would cause liability limit to be exceeded
			set BET($bet,async_park_reason) ASYNC_PARK_BET_EXCEEDS_LIAB_LIMIT
		} else {

			# Support 42963 : only update the liability table if the bet is not going
			# to be parked.

			# If bet is from a fielding channel, get new channel_id based on
			# channel_switch SHFL
			set channel_id [_get_config source]
			if {$CUST_DETAILS(acct_owner) == "F" && $channel_id != "C" \
				&& [lsearch {LOG REG OCC VAR STR} $CUST_DETAILS(owner_type)] != -1} {
				set channel_switch "SHFL"
				set rs [ob_db::exec_qry ob_bet::get_channel_switch $channel_id $channel_switch]
				if {[db_get_nrows $rs] == 1} {
					set channel_id [db_get_col $rs 0 channel_id]
				}
				ob_db::rs_close $rs
			}

			#insert the summary table entry
			_log INFO "Updating liabilities for $ev_oc_id"
			ob_db::exec_qry ob_bet::ins_sgl_liab\
				$BET($bet,bet_id)\
				$LEG($leg,num_selns)\
				[expr {$BET($bet,num_lines)
								* $BET($bet,line_factor)}]\
				$CUST(acct_id)\
				$channel_id\
				$BET($bet,stake_per_line)\
				$BET($bet,leg_type)\
				$ev_oc_id\
				$LEG($leg,leg_sort)\
				$LEG($leg,price_type)\
				$ep_active\
				$LEG($leg,lp_num)\
				$LEG($leg,lp_den)\
				$LEG($leg,hcap_value)\
				$ew_fac_num\
				$ew_fac_den\
				$ew_places\
				$LEG($leg,bir_index)\
				$SELN($ev_oc_id,in_running)
		}

		set BET($bet,liab) [list $type $status $level]
		_lbt_night_mode_susp $ev_oc_id
	}

	_log INFO "Updated liabilities"
}



# Get the market/selection liability from the db
#
# Params
#      ev_oc_id - the selection which the bet is placed on
#      type     - the liability to retrieve:
#                                      'M' for market
#                                      'S' for selection
#
proc ::ob_bet::_get_ev_sgl_liab {ev_oc_id type} {

	#update the apc and chek liab constraints
	_log INFO "Retrieving total liab for type : $type; Seln:$ev_oc_id"
	set rs [ob_db::exec_qry ob_bet::get_sgl_liability\
				$ev_oc_id\
				$type]

	set total_liab [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	return $total_liab
}

# Add the bet to the RUME queue
#
# Params
#      bet_type
#      bet_id
#      ev_mkt_id
#
proc ::ob_bet::_queue_bet_rum {bet_type bet_id ev_mkt_id} {

	variable TYPE

	# We are not interested in bets with manual settlement
	if {$bet_type == "MAN" || [string equal $TYPE($bet_type,bet_settlement) "Manual"]} {
		return
	}

	if {$bet_type == "SGL" && [_get_config offline_liab_eng_sgl] == "N"} {
		# not turned on for singles
		return
	}

	_log INFO "Queueing bet for RUME $bet_id"
	set rs [ob_db::exec_qry ob_bet::rum_insert\
			$bet_type\
			$bet_id\
			$ev_mkt_id\
	]
	ob_db::rs_close $rs

}

::ob_bet::_log INFO "sourced liability.tcl"
