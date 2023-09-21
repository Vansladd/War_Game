# $Id: placebet-liabs.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================


#
# ----------------------------------------------------------------------------
# Liability Limiting and Automatic Price Changing (APC)
# ----------------------------------------------------------------------------
#

#
# ----------------------------------------------------------------------------
# The global variable DB, a database connection, is needed
# ----------------------------------------------------------------------------
#

#
# ----------------------------------------------------------------------------
# Whilst the algorithms aren't generic, the interface to them is - when
# someone concocts a suitable algorithm for manipulating prices across
# all markets, this is the place to plug it in.
#
# These routines use the following tables:
#  1) tEvMkt
#  2) tEvMktConstr
#  3) tEvOc
#  4) tEvOcConstr
# ----------------------------------------------------------------------------
#
set LBT_WARN_THRESHOLD [OT_CfgGet LBT_WARN_THRESHOLD 0.5]

# This isn't referring to handicap APC (which is done in the DB), but
# rather to W/D/W and H2H APC. These are rarely used.
set LBT_APC_ENABLED    [OT_CfgGet LBT_APC_ENABLED    0]


#
# ----------------------------------------------------------------------------
# Pair prices for hrad-to-head APC thingummy
# ----------------------------------------------------------------------------
#
set LBT_PAIR_PRICE [list\
	{9/1     1/20}\
	{17/2    1/18}\
	{8/1     1/16}\
	{15/2    1/14}\
	{7/1     1/12}\
	{13/2    1/10}\
	{6/1     1/9}\
	{11/2    2/17}\
	{5/1     1/8}\
	{9/2     2/15}\
	{4/1     1/7}\
	{7/2     1/6}\
	{10/3    1/5}\
	{3/1     2/9}\
	{11/4    1/4}\
	{5/2     2/7}\
	{9/4     1/3}\
	{2/1     4/11}\
	{7/4     2/5}\
	{13/8    4/9}\
	{6/4     1/2}\
	{11/8    8/15}\
	{5/4     4/7}\
	{6/5     8/13}\
	{11/10   4/6}\
	{1/1     8/11}\
	{5/6     5/6}\
	{8/11    1/1}\
	{4/6     11/10}\
	{8/13    6/5}\
	{4/7     5/4}\
	{8/15    11/8}\
	{1/2     6/4}\
	{4/9     13/8}\
	{2/5     7/4}\
	{4/11    2/1}\
	{1/3     9/4}\
	{2/7     5/2}\
	{1/4     11/4}\
	{2/9     3/1}\
	{1/5     10/3}\
	{1/6     7/2}\
	{1/7     4/1}\
	{2/15    9/2}\
	{1/8     5/1}\
	{2/17    11/2}\
	{1/9     6/1}\
	{1/10    13/2}\
	{1/12    7/1}\
	{1/14    15/2}\
	{1/16    8/1}\
	{1/18    17/2}\
	{1/20    9/1}]

set LBT_PAIR_PRICE_DEC [list]

foreach p $LBT_PAIR_PRICE {

	set p1 [lindex $p 0]
	set p2 [lindex $p 1]

	foreach {p1n p1d} [split $p1 /] { break }

	lappend LBT_PAIR_PRICE_DEC [expr {double($p1n)/double($p1d)}]
}


#
# ----------------------------------------------------------------------------
# queries used by this module
# ----------------------------------------------------------------------------
#
set LBT_QUERIES_PREPARED 0

proc lbt_prep_qrys {} {

	global LBT_QUERIES_PREPARED

	if {$LBT_QUERIES_PREPARED} {
		return
	}

	db_store_qry MKT_CONSTR_UPD {
		update tEvMktConstr set
			lp_bet_count = lp_bet_count + ?,
			lp_win_stake = lp_win_stake + ?,
			sp_bet_count = sp_bet_count + ?,
			sp_win_stake = sp_win_stake + ?
		where
			ev_mkt_id = ?
	}

	db_store_qry SELN_CONSTR_UPD {
		update tEvOcConstr set
			cur_total     = cur_total    + ?,
			lp_bet_count  = lp_bet_count + ?,
			lp_win_stake  = lp_win_stake + ?,
			lp_win_liab   = lp_win_liab  + ?,
			sp_bet_count  = sp_bet_count + ?,
			sp_win_stake  = sp_win_stake + ?,
			apc_total     = NVL(apc_total,0) + ?
		where
			ev_oc_id = ?
	}

	db_store_qry CONSTR_READ {
		select
			NVL(mc.liab_limit,-1.0) liab_limit,
			mc.apc_status,
			mc.apc_trigger,
			mc.apc_margin/100.0 apc_margin,
			mc.lp_bet_count mkt_lp_bet_count,
			mc.lp_win_stake mkt_lp_win_stake,
			mc.sp_bet_count mkt_sp_bet_count,
			mc.sp_win_stake mkt_sp_win_stake,
			NVL(sc.max_total,-1.0) max_total,
			sc.stk_or_lbt,
			sc.cur_total,
			sc.lp_bet_count,
			sc.lp_win_stake,
			sc.lp_win_liab,
			sc.sp_bet_count,
			sc.sp_win_stake,
			NVL(sc.apc_total,0) apc_total,
			NVL(sc.apc_last_move,0) apc_last_move,
			NVL(sc.apc_moves,0) apc_moves,
			sc.apc_start_num,
			sc.apc_start_den
		from
			tEvOcConstr  sc,
			tEvMktConstr mc
		where
			sc.ev_oc_id = ? and sc.ev_mkt_id = mc.ev_mkt_id
	}

	db_store_qry SELN_INFO {
		select
			s.ev_oc_id,
			s.lp_num,
			s.lp_den,
			1.0+(s.lp_num/s.lp_den) p_dec,
			s.fb_result
		from
			tEvOc s
		where
			ev_mkt_id = ?
			and s.fo_avail = 'Y'
	}

	db_store_qry PRICE_INFO {
		select
			p_dec,
			p_num,
			p_den
		from
			tPriceConv
		order by
			p_dec ASC
	}

	db_store_qry SELN_APC_CONSTR_UPD {
		update tEvOcConstr set
			apc_last_move = ?,
			apc_moves     = NVL(apc_moves,0) + 1,
			apc_start_num = ?,
			apc_start_den = ?
		where
			ev_oc_id = ?
	}

	db_store_qry SELN_UPD {
		execute procedure pQuickUpdEvOc (
			p_lp_num   = ?,
			p_lp_den   = ?,
			p_ev_oc_id = ?
		)
	}

	db_store_qry OBJ_SUSP [subst {
		execute procedure pLbtSuspObj(
			p_obj_type = ?,
			p_obj_id   = ?,
			p_allow_feed_upd = '[OT_CfgGet ALLOW_FEED_UPDATE "N"]'
		)
	}]

	db_store_qry NIGHTMODE_SUSP {
		execute procedure pLbtNightModeSusp(
			p_seln_id   = ?
		)
	}

	db_store_qry GET_EXCH_RATES {
		select
			ccy_code,
			exch_rate
		from
			tCCY
	}

	if {[OT_CfgGet OFFLINE_LIAB_ENG_SGL 0] || [OT_CfgGet OFFLINE_LIAB_ENG_RUM 0]} {
		db_store_qry QUEUE_BET {
			execute procedure pLEQBet (
				p_bet_type    = ?,
				p_bet_id      = ?,
				p_ev_mkt_id   = ?
			)
		}
	}

	if {[OT_CfgGet ALLOW_BET_HEDGING 0]} {

		db_store_qry EV_OC_MKT_STATUS {
			select
				em.status as mkt_status,
				eo.status as ev_oc_status
			from
				tEvMkt em,
				tEvOc eo
			where
				em.ev_mkt_id = eo.ev_mkt_id and
				eo.ev_oc_id = ?
		}

		db_store_qry GET_EV_OC_SP {
			select
				NVL(NVL(eo.sp_num_guide,eo.lp_num),5) sp_num_guide,
				NVL(NVL(eo.sp_den_guide,eo.lp_den),2) sp_den_guide
			from
				tEvOc eo
			where
				eo.ev_oc_id = ?
		}

		db_store_qry OBJ_REACTIVATE [subst {
			execute procedure pLbtReactivateObj(
				p_obj_type = ?,
				p_obj_id   = ?,
				p_allow_feed_upd = '[OT_CfgGet ALLOW_FEED_UPDATE "N"]'
			)
		}]

	}

	set LBT_QUERIES_PREPARED 1
}


#
# ----------------------------------------------------------------------------
# update a selection (in tEvOc)
# ----------------------------------------------------------------------------
#
proc lbt_read_exch_rates args {

	global EXCH_RATE

	if {[info exists EXCH_RATE]} {
		return
	}


	set res [db_exec_qry GET_EXCH_RATES]

	set n_rows [db_get_nrows $res]

	if {$n_rows <= 0} {
		error "failed to get exchange rate information"
	}

	for {set i 0} {$i < $n_rows} {incr i} {

		set ccy_code  [db_get_col $res $i ccy_code]
		set exch_rate [db_get_col $res $i exch_rate]

		set EXCH_RATE($ccy_code) $exch_rate
	}

	db_close $res
}



#
# ----------------------------------------------------------------------------
# update a selection (in tEvOc)
# ----------------------------------------------------------------------------
#
proc lbt_upd_seln {seln p_dec} {

	set p_frac [lbt_conv_price $p_dec]

	if {[lbt_night_mode_susp $seln]} {
		db_exec_qry SELN_UPD [lindex $p_frac 0] [lindex $p_frac 1] $seln
	}
}

proc lbt_upd_seln_frac {seln p_num p_den} {

	if {[lbt_night_mode_susp $seln]} {
		db_exec_qry SELN_UPD $p_num $p_den $seln
	}
}

proc lbt_night_mode_susp {seln} {
	# If there have been more than night_mode_max_apc price changes
	# since night mode has been turned on, then suspend all markets
	# belonging to the event that this selection occurs on.

	# If this function suspends any markets it will return 0
	# Else this function returns 1.

	set res [db_exec_qry NIGHTMODE_SUSP $seln]
	return [db_get_coln $res 0 0]
}

#
# ----------------------------------------------------------------------------
# update selection constraint after APC has done its stuff
# ----------------------------------------------------------------------------
#
proc lbt_upd_seln_constr {seln res lp_num lp_den apc_total} {

	# pull out the prices in results set $res - if they're null then
	# we put in lp_num, lp_den passed

	set cp_num [db_get_col $res apc_start_num]
	set cp_den [db_get_col $res apc_start_den]

	if {$cp_num == "" || $cp_den == ""} {
		set cp_num $lp_num
		set cp_den $lp_den
	}

	db_exec_qry SELN_APC_CONSTR_UPD $apc_total $cp_num $cp_den $seln
}


#
# ----------------------------------------------------------------------------
# Wrapper around lbt_bet_upd_real
# ----------------------------------------------------------------------------
#
proc lbt_bet_upd args {

	lbt_prep_qrys

	if [catch {set ret_actions [eval lbt_bet_upd_real $args]} msg] {
		global errorInfo
		OT_LogWrite 1 "LBT: lbt_bet_upd failed: $msg"
		set e [split $errorInfo \n]
		foreach m $e {
			OT_LogWrite 1 "    ==> $m"
		}
		error "abject failure in lbt_bet_upd - see logfile"
	}

	return $ret_actions
}


#
# ----------------------------------------------------------------------------
# Update the market and selection tables with the new bet information
#
# p_type is L or S (live price/starting price)
#
# lp_num,lp_den and sp_num, sp_den are the live and SP tissue prices
# (or some default for the SP if no genuine tissue price is available)
#
# We have a number of constraints, all optional:
#    Selection: Max total stake/Make total liability (determined by the
#               value of the stk_or_lbt flag (S/L)
#    Market:    Max total liability imbalance
#
# Either of these limits may be null (coerced to a value < 0 with NVL),
# in which case they are not applicable
#
# The interaction of the flags is complex:
#
# a) If there is a selection limiter, then the selection is not counted
#    in any market calculations (the "Watford"* problem).
#
# b) If the selection max_total is set to limit total stakes, then the
#    total stake for SGL bets on the selection needs to be calculated,
#    and if the bet takes the selection over its limit, the selection
#    must be suspended after the bet is placed.
#
# c) If the selection max_total is set to limit total liability, and the
#    total liability exceeds the stated amount after the bet is placed,
#    the selection must be suspended.
#
# d) If the market liability limiter is set and the selection max_total
#    is not set then if the net loss for the selection is over that allowed,
#    the market must be suspended.
#
# The "Watford" problem...
#
# In the 1999-2000 Fa Carling premiership market, Watford were initially
# offered at around 2000/1 to win. Bookmakers very quickly accrued staggering
# liabilities on what was, effectively, an outcome with probability
# vanishingly close to zero. This messes up the market net loss field which
# is very useful for other (more likely) outcomes such as Man Utd, Arsenal
# or Leeds.
#
# The solution is to limit (eg) max stakes for watford and to use the market
# limit for the smaller set of plausible outcomes...
# ----------------------------------------------------------------------------
#
proc lbt_bet_upd_real {
	ev_mkt_id
	ev_oc_id
	stake_uc
	ccy_code
	p_type
	lp_num
	lp_den
	sp_num
	sp_den
	reject
	mkt_limit
	stk_or_lbt
	seln_limit
	apc_status
} {
	global LBT_WARN_THRESHOLD LBT_APC_ENABLED EXCH_RATE

	set ACTIONS [list]

	lbt_read_exch_rates

	#
	# Before anything else, convert into base currency
	#
	set stake [expr {$stake_uc/$EXCH_RATE($ccy_code)}]
	set sp_rtn_dec [expr {1.0+double($sp_num)/$sp_den}]

	#
	# Different things are done, depending on whether the price is live or SP
	#
	if {$p_type == "L" || $p_type == "G"} {
		set lp_rtn_dec [expr {1.0+double($lp_num)/$lp_den}]

		# if it is a hedged bet, it's stake will be < 0.
		# don't inc bet count for hedged bets.
		if {$stake > 0} {
			set lp_count   1
		} else {
			set lp_count   0
		}
		set lp_stake   $stake
		set lp_liab    [expr {$stake*$lp_rtn_dec}]
		set sp_count   0
		set sp_stake   0.0
		set apc_total  $lp_liab
	} elseif {$p_type == "S"} {
		set lp_count   0
		set lp_stake   0.0
		set sp_count   1
		set sp_stake   $stake
		set lp_liab    0.0
		set apc_total  0.0
	} else {
		error "unexpected price type ($p_type)"
	}

	OT_LogWrite 1 "LBT: mkt        = $ev_mkt_id"
	OT_LogWrite 1 "LBT: seln       = $ev_oc_id"
	OT_LogWrite 1 "LBT: stake      = $stake_uc ($ccy_code) => $stake"
	OT_LogWrite 1 "LBT: price type = $p_type"
	OT_LogWrite 1 "LBT: LP         = $lp_num/$lp_den"
	OT_LogWrite 1 "LBT: LP liab    = $lp_liab"
	OT_LogWrite 1 "LBT: SP         = $sp_num/$sp_den"
	OT_LogWrite 1 "LBT: reject     = $reject"
	OT_LogWrite 1 "LBT: mkt limit  = $mkt_limit"
	OT_LogWrite 1 "LBT: seln limit = $seln_limit ($stk_or_lbt)"
	OT_LogWrite 1 "LBT: apc status = $apc_status"


	if {$seln_limit >= 0.0} {
		if {$mkt_limit >= 0.0} {
			OT_LogWrite 1 "LBT: turn mkt limit off (seln limit instead)"
			set mkt_limit -1.0
		}
	}


	if {[catch {

		#
		# Update the market constraint - this will lock the row until the
		# end of the transaction: no further bets can be placed on the market
		# until the transaction commits or rolls back. This is a *bad thing*,
		# which just goes to show that customers aren't always right...
		#
		db_exec_qry MKT_CONSTR_UPD\
			$lp_count $lp_stake\
			$sp_count $sp_stake\
			$ev_mkt_id


		#
		# Update the selection constraint - this locks the row until the
		# end of the transaction: no further bets can be placed on this
		# selection until the transaction commits or rolls back. This, too, is
		# a bad thing, but probably an order of magnitute less bad than the
		# previous bad thing (fan-out from market:selection is about 1:10).
		#
		db_exec_qry SELN_CONSTR_UPD\
			$stake\
			$lp_count $lp_stake $lp_liab\
			$sp_count $sp_stake\
			$apc_total\
			$ev_oc_id


		#
		# Retrieve the current values from the constraint tables - we will
		# take action based on what is read back
		#
		set res [db_exec_qry CONSTR_READ $ev_oc_id]
	} msg]} {

		#now have two options:
		#The Market Const tables may be locked by another bet - we either
		#go on and place the bet anyway or bail out here

		OT_LogWrite 1 "Problem accessing liab tables: $msg"
		if {[OT_CfgGet CONTINUE_ON_LIAB_FAILURE "N"] != "Y"} {
			error $msg
		} else {
			OT_LogWrite 1 "CONTINUE_ON_LIAB_FAILURE: has been set proceeding with bet placement"
		}
	}

	#
	# calculate payout and total stakes on this selection
	#
	set v_lp_stake [db_get_col $res lp_win_stake]
	set v_lp_liab  [db_get_col $res lp_win_liab]

	set v_sp_stake [db_get_col $res sp_win_stake]
	set v_sp_liab  [expr {$v_sp_stake*$sp_rtn_dec}]

	set seln_stakes [expr {$v_lp_stake+$v_sp_stake}]
	set seln_payout [expr {$v_lp_liab+$v_sp_liab}]

	OT_LogWrite 1 "LBT: seln lp_liab     = $v_lp_liab"
	OT_LogWrite 1 "LBT: seln lp_stake    = $v_lp_stake"
	OT_LogWrite 1 "LBT: seln sp_liab     = $v_sp_liab"
	OT_LogWrite 1 "LBT: seln sp_stake    = $v_sp_stake"
	OT_LogWrite 1 "LBT: seln seln_stakes = $seln_stakes"
	OT_LogWrite 1 "LBT: seln seln_payout = $seln_payout"


	#
	# market "book" is sum of fixed price and SP stakes
	#
	set v_mkt_lp_stake [db_get_col $res mkt_lp_win_stake]
	set v_mkt_sp_stake [db_get_col $res mkt_sp_win_stake]

	set mkt_book       [expr {$v_mkt_lp_stake+$v_mkt_sp_stake}]


	#
	# net win on a selection is what is taken, less what is paid out
	#
	set net_win [expr {$mkt_book-$seln_payout}]

	#
	# check whether market needs to be suspended - this happens when the
	# net loss for any selection reaches "liab_limit" (if it is >= 0.0)
	#
	if {$mkt_limit >= 0.0} {

		OT_LogWrite 1 "LBT: payout=$seln_payout, book=$mkt_book, net=$net_win"

		#
		# if net loss is above limits, give a market suspension order
		#
		if {$net_win+$mkt_limit < 0} {

			lappend ACTIONS [list SELN-SUSP $ev_mkt_id]

			OT_LogWrite 1 "LBT: selection needs suspending: net win=$net_win"
			db_exec_qry OBJ_SUSP S $ev_oc_id
		}
	}


	#
	# check whether selection needs to be suspended - this happens when
	# the cumulative stake level or liability for the selection reaches
	# "max_total" (if it is >= 0.0)
	#
	if {$seln_limit >= 0.0} {

		set v_stk_or_lbt [db_get_col $res stk_or_lbt]

		if {$v_stk_or_lbt != "L"} {

			if {$seln_stakes > $seln_limit} {

				lappend ACTIONS [list SELN-SUSP $ev_oc_id]

				OT_LogWrite 1 "LBT: selection suspension: total=$seln_limit"

				db_exec_qry OBJ_SUSP S $ev_oc_id

			} else {

				#
				# produce a warning if the selection is > x% of its suspend
				# threshold
				#
				set warn_limit [expr {$seln_limit*$LBT_WARN_THRESHOLD}]

				if {$seln_stakes >= $warn_limit} {
					lappend ACTIONS [list SELN-WARN $ev_oc_id]
					OT_LogWrite 1 "LBT: selection near suspension: $seln_payout"
				}
			}

		} else {


			if {[OT_CfgGet FUNC_PL_SELN_LIAB 0] == "1"} {

				#
				# use profit loss figure for calculations
				#

				if {$net_win + $seln_limit < 0} {
					lappend ACTIONS [list SELN-SUSP $ev_oc_id]

					OT_LogWrite 1 "LBT: selection suspension: total=$seln_limit net_win=$net_win"
					db_exec_qry OBJ_SUSP S $ev_oc_id

				} else {

					#
					# produce a warning if the selection is > x% of its suspend
					# threshold
					#
					set warn_limit [expr {$seln_limit*$LBT_WARN_THRESHOLD}]

					if {$seln_payout >= $warn_limit} {
						lappend ACTIONS [list SELN-WARN $ev_oc_id]
						OT_LogWrite 1 "LBT: selection near suspension: $seln_payout"
					}
				}

			} else {

				#
				# use liab win figure for calculations
				#

				if {$seln_payout > $seln_limit} {
					lappend ACTIONS [list SELN-SUSP $ev_oc_id]

					OT_LogWrite 1 "LBT: selection suspension: total=$seln_limit"

					db_exec_qry OBJ_SUSP S $ev_oc_id

				} else {

					#
					# produce a warning if the selection is > x% of its suspend
					# threshold
					#
					set warn_limit [expr {$seln_limit*$LBT_WARN_THRESHOLD}]

					if {$seln_payout >= $warn_limit} {
						lappend ACTIONS [list SELN-WARN $ev_oc_id]
						OT_LogWrite 1 "LBT: selection near suspension: $seln_payout"
					}
				}
			}
		}
	}


	#
	# If APC not enabled (the normal case), return now
	#
	if {!$LBT_APC_ENABLED} {

		OT_LogWrite 1 "LBT: APC not enabled : returning"

		foreach a $ACTIONS {
			OT_LogWrite 1 "LBT: ACTION: $a"
		}
		return $ACTIONS
	}


	#
	# now check whether to run an APC (only applicable for head-head or
	# football win/draw/win markets), and even then we only need to run the
	# check if the selection in question is a net loser...
	#
	if {$net_win < 0 && $apc_status == "A" && $p_type == "L"} {

		# get trigger value and net loss at which last move was made

		set v_apc_trigger   [db_get_col $res apc_trigger]
		set v_apc_last_move [db_get_col $res apc_last_move]

		OT_LogWrite 1 "LBT: APC net_win    = $net_win"
		OT_LogWrite 1 "LBT: APC apc_status = A"
		OT_LogWrite 1 "LBT: APC p_type     = L"
		OT_LogWrite 1 "LBT: APC trigger    = $v_apc_trigger"
		OT_LogWrite 1 "LBT: APC last_move  = $v_apc_last_move"

		if {$v_apc_last_move+$v_apc_trigger+$net_win < 0} {

			OT_LogWrite 1 "LBT: APC trigger limit breached (net win=$net_win)"

			lbt_run_apc $ev_mkt_id $ev_oc_id $res $lp_num $lp_den
		}

	} else {

		OT_LogWrite 1 "LBT: APC skipped (net_win=$net_win)"

	}

	return $ACTIONS
}



#
# ----------------------------------------------------------------------------
# Route to the appropriate APC implementation (H/H or W/D/W)
# ----------------------------------------------------------------------------
#
proc lbt_run_apc {ev_mkt_id ev_oc_id res lp_num lp_den} {

	#
	# need some information about the market and the selections
	#
	set seln [db_exec_qry SELN_INFO $ev_mkt_id]

	set rows [db_get_nrows $seln]

	if {$rows == 2} {
		OT_LogWrite 1 "APC: market is H/H (2 selns)"
		set type HH
	} elseif {$rows == 3} {
		OT_LogWrite 1 "APC: market is W/D/W (3 selns)"
		set type WDW
	} else {
		error "wrong number of rows for APC (got $rows, expected 2 or 3)"
	}

	lbt_run_apc_$type $ev_mkt_id $ev_oc_id $res $seln $lp_num $lp_den
}



#
# ----------------------------------------------------------------------------
# Head/Head APC
# ----------------------------------------------------------------------------
#
proc lbt_run_apc_HH {ev_mkt_id ev_oc_id res seln lp_num lp_den} {

	global LBT_PAIR_PRICE LBT_PAIR_PRICE_DEC

	#
	# Two selections are in rows 0 and 1
	#
	set r0_oc_id [db_get_col $seln 0 ev_oc_id]
	set r1_oc_id [db_get_col $seln 1 ev_oc_id]

	OT_LogWrite 1 "APC: (HH) seln ids: $r0_oc_id, $r1_oc_id"

	#
	# which selection triggered the move?
	#
	if {$ev_oc_id == $r0_oc_id} {
		set TRIGGER   0
		set OTHER     1
		OT_LogWrite 1 "APC: (HH) trigger is 1st seln"
	} else {
		set TRIGGER   1
		set OTHER     0
		OT_LogWrite 1 "APC: (HH) trigger is 2nd seln"
	}


	#
	# need to get price of selection which caused the move
	#
	set t_ev_oc_id [db_get_col $seln $TRIGGER ev_oc_id]
	set o_ev_oc_id [db_get_col $seln $OTHER   ev_oc_id]


	#
	# Now find the current price in the pairs lookup table, step forward
	# to get the new price, and pull the matching price for the other
	# selection
	#
	set tp_old [expr {1.0+double($lp_num)/$lp_den}]

	set i 0
	set s_index -1
	foreach p_dec $LBT_PAIR_PRICE_DEC {
		if {$tp_old >= $p_dec} {
			set s_index [expr {$i+1}]
			break
		}
		incr i
	}

	foreach {tp_new op_new} [lindex $LBT_PAIR_PRICE $i] { break }

	OT_LogWrite "APC: (HH) old price ($lp_num/$lp_den) matches $p_dec"
	OT_LogWrite "APC: (HH) new price pair is $tp_new, $op_new"


if 0 {
	#
	# now need to move the other price to keep the margin as specified
	# The margin for a HH market is calculated like this:
	#
	#    M = p1d/(p1n+p1d) + p2d/(p2n+p2d)
	#
	# or for decimal prices
	#
	#    M = 1/p1 + 1/p2
	#
	# so, if we have p1 and M, p2 can be calculated like this:
	#
	#    p2 = p1 / (p1*M-1)
	#
	set margin [db_get_col $res apc_margin]
	set op_new [expr $tp_new/($tp_new*$margin-1)]

	OT_LogWrite 1 "APC: (HH) margin      = $margin"
	OT_LogWrite 1 "APC: (HH) other price = $op_new"
}

	#
	# set the value for the last apc move - this is used to trigger the
	# next move: the value is the net loss at which the apc was triggered
	# since tEvOcConstr holds the value at the last move, we just need to
	# add the "apc_trigger" from tEvMktConstr
	#
	set v_apc_trigger   [db_get_col $res apc_trigger]
	set v_apc_last_move [db_get_col $res apc_last_move]
	set v_apc_next_move [expr {$v_apc_trigger+$v_apc_last_move}]

	OT_LogWrite 1 "apc_last_move = $v_apc_last_move"
	OT_LogWrite 1 "apc_next_move = $v_apc_next_move"

	lbt_upd_seln_constr $ev_oc_id $res $lp_num $lp_den $v_apc_next_move


	#
	# now update the prices in tEvOc for the two selections
	#
	foreach {pn pd} [split $tp_new /] { break }

	lbt_upd_seln_frac $t_ev_oc_id $tp_new

	foreach {pn pd} [split $op_new /] { break }

	lbt_upd_seln_frac $o_ev_oc_id $op_new
}



#
# ----------------------------------------------------------------------------
# Football WDW APC
# ----------------------------------------------------------------------------
#
proc lbt_run_apc_WDW {ev_mkt_id ev_oc_id res seln lp_num lp_den} {

	#
	# these will point to the row numbers (0/1/2) of the relevant
	# selection
	#
	set FAVOURITE -1
	set DRAW      -1
	set UNDERDOG  -1

	#
	# This is the row number of the selection which triggered the change
	#
	set TRIGGER   -1

	foreach i {0 1 2} {

		set PRICE($i) [db_get_col $seln $i p_dec]

		set type [db_get_col $seln $i fb_result]

		if {$type == "D"} {
			set DRAW $i
		} elseif {$FAVOURITE == -1} {
			set FAVOURITE $i
		} else {
			set UNDERDOG $i
		}

		if {[db_get_col $seln $i ev_oc_id] == $ev_oc_id} {
			set TRIGGER $i
		}
	}


	#
	# we've guessed favourite and underdog, now look at the prices and
	# see which is really which...
	#
	if {$PRICE($FAVOURITE) > $PRICE($UNDERDOG)} {
		set t         $FAVOURITE
		set FAVOURITE $UNDERDOG
		set UNDERDOG  $t
	}

	set P_FAVOURITE $PRICE($FAVOURITE)
	set P_DRAW      $PRICE($DRAW)
	set P_UNDERDOG  $PRICE($UNDERDOG)


	#
	# get the counter for how many moves have been made so far...
	#
	set n_moves [db_get_col $res apc_moves]

	OT_LogWrite 1 "APC: $n_moves moves so far"

	# bump up number of moves (bugfix, CJH, 2000-02-12)

	incr n_moves


	set init_price  [expr {1.0+double($lp_num)/$lp_den}]
	set price_delta -1
	set suspend     N

	if {$TRIGGER == $FAVOURITE} {

		OT_LogWrite 1 "APC: changing FAVOURITE (@$P_FAVOURITE)"

		if {$init_price >= 1.70} {
			set price_delta 0.10
		} else {
			set price_delta 0.05
		}
		if {$n_moves < 3} {
			set margin_dist [list $P_DRAW 0.00 $P_UNDERDOG 1.00]
		} elseif {$n_moves == 3} {
			set margin_dist [list $P_DRAW 0.50 $P_UNDERDOG 0.50]
		} else {
			set suspend Y
		}

	} elseif {$TRIGGER == $DRAW} {

		OT_LogWrite 1 "APC: changing DRAW (@$P_DRAW)"

		if {$init_price <= 3.30} {
			set price_delta 0.10
			if {$n_moves < 2} {
				set margin_dist [list $P_FAVOURITE 0.50 $P_UNDERDOG 0.50]
			} else {
				set suspend Y
			}
		} elseif {$init_price < 4.00} {
			set price_delta 0.20
			if {$n_moves < 2} {
				set margin_dist [list $P_FAVOURITE 1.00 $P_UNDERDOG 0.00]
			} else {
				set suspend Y
			}
		} else {
			set price_delta 0.50
			if {$n_moves == 0} {
				set margin_dist [list $P_FAVOURITE 1.00 $P_UNDERDOG 0.00]
			} else {
				set suspend Y
			}
		}

	} else {

		OT_LogWrite 1 "APC: changing UNDERDOG (@$P_UNDERDOG)"

		if {$init_price <= 3.00} {
			set max_moves   2
			set price_delta 0.10
		} elseif {$init_price < 3.60} {
			set max_moves   2
			set price_delta 0.20
		} elseif {$init_price <= 4.50} {
			set max_moves   2
			set price_delta 0.30
		} elseif {$init_price < 6.10} {
			set max_moves   2
			set price_delta 0.50
		} elseif {$init_price <= 7.50} {
			set max_moves   0
			set price_delta 1.00
		} elseif {$init_price < 10.00} {
			set max_moves   0
			set price_delta 1.50
		} else {
			set max_moves   0
			set price_delta 2.50
		}
		if {$n_moves > $max_moves} {
			set suspend Y
		} else {
			set margin_dist [list $P_FAVOURITE 1.00 $P_DRAW 0.00]
		}
	}

	if {$suspend == "Y"} {
		OT_LogWrite 1 "APC: this market will be suspended"
		return
	} else {
		OT_LogWrite 1 "APC: price delta = $price_delta"
		OT_LogWrite 1 "APC: margin dist = $margin_dist"
	}


	#
	# We know what is needed now - just need to move the trigger price, and
	# then distriblute the margin according to what is in the margin_dist
	# list
	#
	set apc_margin [db_get_col $res apc_margin]

	OT_LogWrite 1 "APC: target margin = $apc_margin"

	set adj_price  [expr {$init_price-$price_delta}]

	OT_LogWrite 1 "APC: adjust $init_price by $price_delta"

	set new_prices [eval [concat\
		lbt_calc_pair_price $apc_margin $adj_price $margin_dist]]

	if {$TRIGGER == $FAVOURITE} {
		set NP_FAVOURITE $adj_price
		set NP_DRAW      [lindex $new_prices 0]
		set NP_UNDERDOG  [lindex $new_prices 1]
	} elseif {$TRIGGER == $DRAW} {
		set NP_FAVOURITE [lindex $new_prices 0]
		set NP_DRAW      $adj_price
		set NP_UNDERDOG  [lindex $new_prices 1]
	} else {
		set NP_FAVOURITE [lindex $new_prices 0]
		set NP_DRAW      [lindex $new_prices 1]
		set NP_UNDERDOG  $adj_price
	}

	OT_LogWrite 1 "APC: new price favourite: $NP_FAVOURITE"
	OT_LogWrite 1 "APC: new price draw     : $NP_DRAW"
	OT_LogWrite 1 "APC: new price underdog : $NP_UNDERDOG"

	#
	# set the value for the last apc move - this is used to trigger the
	# next move: the value is the net loss at which the apc was triggered
	# since tEvOcConstr holds the value at the last move, we just need to
	# add the "apc_trigger" from tEvMktConstr
	#
	set v_apc_trigger   [db_get_col $res apc_trigger]
	set v_apc_last_move [db_get_col $res apc_last_move]
	set v_apc_next_move [expr {$v_apc_trigger+$v_apc_last_move}]

	OT_LogWrite 1 "APC: new state variables: last move : $v_apc_last_move"
	OT_LogWrite 1 "APC: new state variables: next move : $v_apc_next_move"


	# update the APC state information

	lbt_upd_seln_constr $ev_oc_id $res $lp_num $lp_den $v_apc_next_move


	#
	# have new prices, need to update selections with them...
	#
	foreach s {FAVOURITE DRAW UNDERDOG} {
		if {abs([set NP_$s]-[set P_$s]) > 0.0001} {
			lbt_upd_seln [db_get_col $seln [set $s] ev_oc_id] [set NP_$s]
		}
	}
}



#
# ----------------------------------------------------------------------------
# Convert a decimal price to its nearest (downward) fractional equivalent
#
# This isn't going to win any speed awards, but it doesn't get used often...
# ----------------------------------------------------------------------------
#
proc lbt_conv_price p_dec {

	global LBT_PRICES

	#
	# "Lazy" read the prices
	#
	if {[info exists LBR_PRICES] == 0} {
		set LBT_PRICES [db_exec_qry PRICE_INFO]
	}

	#
	# If the fractional price is > 20, then we just return a straightforward
	# fraction which is p_dec-1/1. This seems OK.
	#
	if {$p_dec > 20} {
		return [list [expr {round($p_dec)-1}] 1]
	}

	set nr [db_get_nrows $LBT_PRICES]

	#
	# Run through list of prices until we have one which is bigger than the
	# one we want - at this point we've gone one element too far, so back up
	# one place and return that fraction. If the fraction price is very small,
	# return 1/100.
	#
	for {set i 0} {$i < $nr} {incr i} {
		set p_hi [db_get_col $LBT_PRICES $i p_dec]
		if {$p_dec < $p_hi} {
			incr i -1
			if {$i < 0} {
				return [list 1 100]
			}
			set p_lo [db_get_col $LBT_PRICES $i p_dec]

			if {$p_dec-$p_lo > $p_hi-$p_dec} {
				incr i
			}
			set num [db_get_col $LBT_PRICES $i p_num]
			set den [db_get_col $LBT_PRICES $i p_den]

			OT_LogWrite 1 "APC: dec2frac: $p_dec => $num/$den"

			return [list $num $den]
		}
	}
	error "couldn't convert $p_dec to fractional price"
}



#
# ----------------------------------------------------------------------------
# Given a margin and a price, distribute the margin to the other prices
#
# margin is the target margin (normalised to 1.0). p1 is the price which has
# changed, p2 and p3 are the old prices, f1 and f2 are the relative amounts
# of margin difference which should be apportioned to p2 and p3. f1 and f2
# are both >= 0 and <= 1, and f1+f2 must total 1.0
# ----------------------------------------------------------------------------
#
proc lbt_calc_pair_price {margin p1 p2 f2 p3 f3} {

	#
	# calculate margin of three prices given (sum(1/price))
 	#
	set M [expr {(1.0/$p1)+(1.0/$p2)+(1.0/$p3)}]

	#
	# what is the difference between the calculated margin and the
	# target margin
	#
	set m_diff [expr {$M-$margin}]

	#
	# work out new prices by apportioning factors of the margin difference
	# to the two other prices, according to the fraction specified.
	#
	set p2_new [expr {1.0/((1.0/$p2)-($m_diff*$f2))}]
	set p3_new [expr {1.0/((1.0/$p3)-($m_diff*$f3))}]

	return [list $p2_new $p3_new]
}

proc lbt_queue_bet {bet_type bet_id {mkt_id ""}} {
	global BET_TYPE


	lbt_prep_qrys

	# We are not interested in bets with manual settlement
	if {$bet_type == "MAN" || [string equal $BET_TYPE($bet_type,bet_settlement) "Manual"]} {
		return
	}

	# Make sure that we have an engine enabled for the type of bet we
	# are dealing with
	if {($bet_type == "SGL" && [OT_CfgGet OFFLINE_LIAB_ENG_SGL 0]) ||
			($bet_type != "SGL" && [OT_CfgGet OFFLINE_LIAB_ENG_RUM 0])} {


		if {[catch {db_exec_qry QUEUE_BET $bet_type $bet_id $mkt_id} msg]} {
			OT_LogWrite 2 "Failed to queue bet for liabilities: $msg"
			error "Failed to queue bet for liabilities: $msg"
		}
	}
}


#
# ----------------------------------------------------------------------------
# HEDGING PROCS
# ----------------------------------------------------------------------------

#
# ----------------------------------------------------------------------------
# Procedures for use with hedging.
# When a hedged bet is placed, the liabilities are effectively reversed for
# that bet (ie a hedged bet on an outcome would have a positive liability if
# that outcome won).
#
# This means that if a market/selection has been suspended due to liabilities,
# placing a hedged bet could take it back below the threshold. This function
# determines for a market/selection whether or not the liabilities are now
# below the limit.
#
# We do not automatically re-open the market. That must be done separately.
#
# ----------------------------------------------------------------------------
#

#
# ----------------------------------------------------------------------------
# lbt_mkt_or_sel_susp
# This procedure returns the status (ie eiter active or suspended) of the
# specified selection and it's market.
#
# Returns 2 element list containing market and selection status.
# ----------------------------------------------------------------------------
#

proc lbt_mkt_or_sel_susp {ev_oc_id} {

	lbt_prep_qrys

	# get the current market and selection status
	if {[catch {set res [db_exec_qry EV_OC_MKT_STATUS $ev_oc_id]} msg]} {
		OT_LogWrite 1 "lbt_mkt_or_sel_sups -> unable to get status: $msg"
	}

	# get the status of the mkt and ev_oc
	set mkt_status   [db_get_col $res mkt_status]
	set ev_oc_status [db_get_col $res ev_oc_status]

	# return value is list containing market status and selection status
	return [list $mkt_status $ev_oc_status]

}


#
# ----------------------------------------------------------------------------
# lbt_check_liab_level
# This procedure looks at the current status of a market/selection, and at the
# current values in the constr tables to decide if a market has been liability
# suspended. The assumption here is that if a market/selection is suspended and
# the liability values in the constr tables are above the limits for that
# market/selection, it is liability suspended.
#
# Returns a 2 element list. The first element is 1 or 0 - 1 if the market/
# selection is liability suspended, 0 if not. The second element is a list
# containing what is liability suspended - either (M)arket, (S)election, both
# or neither.
# ----------------------------------------------------------------------------
#

proc lbt_check_liab_level {ev_oc_id mkt_susp sel_susp} {

	lbt_prep_qrys

	# get the current starting prices
	if {[catch {set res [db_exec_qry GET_EV_OC_SP $ev_oc_id]} msg]} {
		OT_LogWrite 1 "lbt_check_liab_level unable to get sp -> $msg"
	}

	# get the starting prices
	set sp_num_guide   [db_get_col $res sp_num_guide]
	set sp_den_guide   [db_get_col $res sp_den_guide]

	# either mkt, ev_oc or both are suspended. Try to work out if they are
	# liability suspended
	if {[catch {set res [db_exec_qry CONSTR_READ $ev_oc_id]} msg]} {

		#now have two options:
		#The Market Const tables may be locked by another bet - we either
		#go on  or bail out here

		OT_LogWrite 1 "Problem accessing liab tables: $msg"
		if {[OT_CfgGet CONTINUE_ON_LIAB_FAILURE "N"] != "Y"} {
			error $msg
		} else {
			OT_LogWrite 1 "CONTINUE_ON_LIAB_FAILURE: has been set proceeding with bet placement"
		}
	}

	# calculate the starting price
	set sp_rtn_dec     [expr {1.0 + double($sp_num_guide) / $sp_den_guide}]

	# ev_oc values
	set v_sp_stake     [db_get_col $res sp_win_stake]
	set v_lp_liab      [db_get_col $res lp_win_liab]
	set v_sp_liab      [expr {$v_sp_stake * $sp_rtn_dec}]
	set seln_payout    [expr {$v_lp_liab + $v_sp_liab}]

	set stk_or_lbt     [db_get_col $res stk_or_lbt]
	set max_total      [db_get_col $res max_total]

	# ev_mkt values
	set v_mkt_lp_stake [db_get_col $res mkt_lp_win_stake]
	set v_mkt_sp_stake [db_get_col $res mkt_sp_win_stake]
	set mkt_book       [expr {$v_mkt_lp_stake + $v_mkt_sp_stake}]

	set liab_limit     [db_get_col $res liab_limit]

	#
	# net win on a selection is what is taken, less what is paid out
	# ie mkt liability.
	#
	set net_win [expr {$mkt_book-$seln_payout}]

	set liab_level 0
	set liab_type [list]

	# selection
	if {$sel_susp == "S" &&
				$stk_or_lbt == "L" &&
				$max_total > 0.0 &&
				$seln_payout > $max_total} {
		# the ev_oc has probably been liability suspended
		lappend liab_type "S"
		set liab_level 1
	}

	# market
	if {$mkt_susp == "S" &&
				$liab_limit > 0.0 &&
				[expr $net_win + $liab_limit] < 0.0} {
		# the mkt has probably been liability suspended
		lappend liab_type "M"
		set liab_level 1
	}

	return [list $liab_level $liab_type]
}


#
# ----------------------------------------------------------------------------
# lbt_is_liab_susp
# This procedure checks whether a market/selection is liability suspended. It
# should be called before a hedged bet is placed.
#
# Returns a 2 element list - the first element is either Y (market and or
# selection is suspended) or N (neither are liability suspended). The second
# element is a list containing what is liability suspended - either (M)arket,
# (S)election, both or neither.
# ----------------------------------------------------------------------------
#

proc lbt_is_liab_susp {ev_oc_id} {

	# first of all, see if the market or selection is suspended at all
	set susp_res [lbt_mkt_or_sel_susp $ev_oc_id]
	set mkt_susp [lindex $susp_res 0]
	set sel_susp [lindex $susp_res 1]

	if {$mkt_susp == "A" && $sel_susp == "A"} {
		# nothing is suspended - return
		return [list "N" {}]
	}

	# now, check to see if it is likely to be a liability suspension
	set liab_res [lbt_check_liab_level $ev_oc_id $mkt_susp $sel_susp]
	set liab_type [lindex $liab_res 1]

	if {[lindex $liab_res 0] == 1} {
		# something has probably been liability suspended
		return [list "Y" $liab_type]
	} else {
		# nothing has been liability suspended
		return [list "N" $liab_type]
	}
}


#
# ----------------------------------------------------------------------------
# lbt_is_liab_limit_under
# This procedure checks whether a market that was suspended due to liabilities
# can now be reopened. It should be called after a hedged bet is placed, but ONLY
# for a market/selection that was previously flagged as having been liability
# suspended. If called on a market/selection that was not flagged as having been
# liability suspended, it could mark a suspended market as being eligible for
# being reopened when it should not be.
#
# Return
# Returns a 2 element list - the first element is either Y (market and or
# selection is below liability limit and can be reopened) or N (neither are
# below liability limit). The second element is a list containing what is below
# the liability level - either (M)arket, (S)election, both or neither.
# ----------------------------------------------------------------------------
#
proc lbt_is_liab_limit_under {ev_oc_id} {

	# first of all, see if the market or selection is suspended at all
	set susp_res [lbt_mkt_or_sel_susp $ev_oc_id]
	set mkt_susp [lindex $susp_res 0]
	set sel_susp [lindex $susp_res 1]

	if {$mkt_susp == "A" && $sel_susp == "A"} {
		# nothing is suspended - return
		return [list "N" {}]
	}

	# now, check to see if it is likely to be a liability suspension
	set liab_res [lbt_check_liab_level $ev_oc_id $mkt_susp $sel_susp]
	set liab_type [lindex $liab_res 1]
	set ret_list [list]

	if {[lindex $liab_res 0] == 1} {
		# at least 1 level is still over the threshold
		set num_susp [llength $liab_type]

		if {$num_susp == 2} {
			# both are liability suspended
			return [list "N" {}]
		}

		# only 1 of market or selection is liability suspended
		if {[lindex $liab_type 0] == "M" && $sel_susp == "S"} {
			# mkt is still over, but selection is not and is suspended
			lappend ret_list "S"
		}

		if {[lindex $liab_type 0] == "S" && $mkt_susp == "S"} {
			# selection is still over, but mkt is not and is suspended
			lappend ret_list "M"
		}

	} else {
		# Neither market or selection is liability suspended
		# need to check that neither is properly suspended either

		if {$mkt_susp == "S"} {
			lappend ret_list "M"
		}

		if {$sel_susp == "S"} {
			lappend ret_list "S"
		}

	}

	# return
	if {[lindex $ret_list 0] != ""} {
		return [list "Y" $ret_list]
	} else {
		return [list "N" {}]
	}
}


#
# ----------------------------------------------------------------------------
# lbt_reopen_mkt_or_selection
# Reopens a market or selection.
# ----------------------------------------------------------------------------
#
proc lbt_reopen_mkt_or_selection {ev_oc_id ev_mkt_id type} {

	if {$type == "M"} {
		db_exec_qry OBJ_REACTIVATE M $ev_mkt_id
	}

	if {$type == "S"} {
		db_exec_qry OBJ_REACTIVATE S $ev_oc_id
	}
}
