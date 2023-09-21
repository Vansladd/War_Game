#
# $Id: stl-main.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ============================================================================
#
# ----------------------------------------------------------------------------
#
# Bet settlement
#
# These settlement routines are optimised for clarity rather than performance
#
# ----------------------------------------------------------------------------
#
# ----------------------------------------------------------------------------
#
#  Several things remain "unfinished" or "improperly implemented"
#
#  1) Handling of "Equally Divided" remains to be properly done, pending the
#     response to some questions (and a possible modification to the
#     database).
#
#  2) It is possible that scorecasts will need to be settled differently -
#     at present, if the first scorer is void (because he wasn't on the
#     pitch before the first goal was scored), the scorecast is void. A
#     different way of settling this is to settle it as a correct score
#     single. There are additional complications relating to own goals
#     and abandoned matches (See Ladbrokes rules, 7.6; Bet Direct rules,
#     16.2,16.3,16.4). This might not be too much of a problem because
#     the first goalscorer market is settled in the same way as scorecast
#     with regard to own goals.
#   FIXED (I believe)
#
#  3) It remains to be seen how cleanly the notion of "bonuses" and
#     "consolations" can be encapsulated. Some of the things which might be
#     implemented are:
#         - Yankee Plus consolation single
#         - Canadian Plus consolation single
#         - L15/31/63 one single only settled at N*price, bonus for all M
#         - X% bonuses for correct FC/TC bets
#     It appears as if there's a potentially endless list of these sorts
#     of tweaks, and (at the time of writing) there's no simple model which
#     caters for all of them.
#
#  4) It appears that we're not handling place results properly: in a race
#     which allows tricasts, but only pays out on the first two places for
#     an each-way bet, there will be three places declared (for settling
#     the tricast), but we must only settle each-way bets as wins on the
#     first two places. Hmmmm - need to take the ew-places figure a bit more
#     seriously, along with the place result...
#   FIXED (I believe)
#
#
#   ADMENDMENTS (9/6/2006) by Byoung:
#
#	Added greyhound non-runner/SP Settlement rules based on the implementation
#	used by Ladbrooks team.
#
# ----------------------------------------------------------------------------

namespace eval ADMIN::SETTLE {

variable STL_LOG_ONLY
variable MAX_PAY_SORT
variable FC_DIV_FACTOR
variable TC_DIV_FACTOR
variable USE_RULE4
variable USE_DIVIDENDS
variable CT_BONUS

variable CHANNELS_TO_ENABLE_PARKING
variable PARK_ON_WINNINGS_ONLY

variable FUNC_AUTO_DH

#
# If this flag is set, the settler will just log its intentions
#
set STL_LOG_ONLY 1

#
# Maximum payout can be by bet or by bet line (SLOT)
# bet_stake added to include stake in max payout!
#
set MAX_PAY_SORT [OT_CfgGet STL_MAX_PAY_SORT BET_STAKE]

#
# Customers who have taxable/and tax-free operations might want to skew
# FC/TC dividends (which notionally include pre-paid tax)
#
set FC_DIV_FACTOR [OT_CfgGet STL_FC_DIV_FACTOR 1.00]
set TC_DIV_FACTOR [OT_CfgGet STL_TC_DIV_FACTOR 1.00]

#
# Tweak (for SLOT, mainly) to totally ignore rule 4 stuff and dividends
#
set USE_RULE4     [OT_CfgGet USE_RULE4     1]
set USE_DIVIDENDS [OT_CfgGet USE_DIVIDENDS 1]

set CHANNELS_TO_ENABLE_PARKING [split [OT_CfgGet CFG_CHANNELS_TO_ENABLE_PARKING ""] ,]

#
# If Yes will the park bet limit (tControl.stl_pay_limit) will be applied
# to winnings only rather than refund + winnings
#
set PARK_ON_WINNINGS_ONLY [OT_CfgGet PARK_ON_WINNINGS_ONLY "0"]


#
# Per class/type bonus specs are in STL_CLASS_TYPE_BONUS
#
set CT_BONUS(enabled) 0

foreach {c v b} [OT_CfgGet STL_CLASS_TYPE_BONUS [list]] {
	set CT_BONUS(enabled) 1
	set CT_BONUS($c,$v) $b

	OT_LogWrite 1 "Add class/type bonus : $c\($v\) -> $b"
}

set FUNC_AUTO_DH  [OT_CfgGet FUNC_AUTO_DH 0]

#
# ----------------------------------------------------------------------------
# settle
# ----------------------------------------------------------------------------
#
proc stl_settle {what id do_it {req_guid {}}} {

	variable STL_LOG_ONLY
	variable STL_BET_STATUS
	variable REQ_GUID

	set STL_BET_STATUS "N"

	catch {unset REQ_GUID}
	set REQ_GUID $req_guid

	if {$do_it == "Y"} {
		set STL_LOG_ONLY 0
	} else {
		set STL_LOG_ONLY 1
	}

	stl_get_control
	stl_get_bet_types

	switch -- $what {
		event {
			stl_check E $id
			stl_settle_event $id
		}
		market {
			stl_check M $id
			stl_settle_mkt $id
		}
		bir {
			stl_check B $id
			stl_settle_bir $id
		}
		index {
			ADMIN::IXMARKET::stl_settle_index $id
		}
		spread_market {
			stl_check M $id
			stl_settle_spread_mkt $id
		}
		selection {
			stl_check S $id
			stl_settle_seln $id
		}
		bet {
			stl_settle_bet $id
		}
		poolBet {
			ADMIN::SETTLE::POOLS::stl_settle_bet_pool $id
		}
		pool {
			ADMIN::SETTLE::POOLS::stl_settle_pool $id
		}
		evt_pools {
			ADMIN::SETTLE::POOLS::stl_settle_evt_pools $id
		}
		allpools {
			ADMIN::SETTLE::POOLS::stl_settle_all_pools
		}

		default {
			error "unexpected object to settle: $what ($id)"
		}
	}
}


#
# ----------------------------------------------------------------------------
# Check that an event/market/selection can be settled
# ----------------------------------------------------------------------------
#
proc stl_check {what id} {

	set stmt [stl_qry_prepare CHK_CAN_SETTLE]
	set res  [inf_exec_stmt $stmt $what $id]

	set r 0

	if {[db_get_nrows $res] == 1} {
		if {[db_get_coln $res 0 0] == 1} {
			set r 1
		}
	}

	db_close $res

	if {!$r} {
		error "Cannot settle - results not confirmed"
	}
}


#
# ----------------------------------------------------------------------------
# Settle an event
# ----------------------------------------------------------------------------
#
proc stl_settle_event {ev_id} {

	global USERNAME

	variable SELN
	variable DHEAT
	variable MKT
	variable STL_LOG_ONLY
	variable REQ_GUID

	catch {unset SELN}
	catch {unset DHEAT}
	catch {unset MKT}

	log 1 "settling event #$ev_id"


	set stmt [stl_qry_prepare GET_EVENT_MKTS]

	set args [list $ev_id]

	if {[OT_CfgGet FUNC_INDEX_TRADE 0]} {
		lappend args $ev_id
	}

	set res [eval {inf_exec_stmt $stmt} $args]

	set n_mkts [db_get_nrows $res]

	set n_errors 0

	#
	# Settle each market...
	#
	for {set m 0} {$m < $n_mkts} {incr m} {

		set market_cat [db_get_col $res $m market_cat]
		set market_id  [db_get_col $res $m market_id]

		if {$market_cat == "M"} {

			set sort [db_get_col $res $m market_sort]

			#
			# Spread bets don't have any selections and are
			# consequently treated differently.
			#
			if {$sort == "SB"} {
			    set settle_proc stl_settle_spread_mkt
			} else {
				set settle_proc stl_settle_mkt
			}

			#
			# call the procedure for settling a selection, but make it not
			# clobber any selection/market information which has been cached
			#
			if [catch {$settle_proc $market_id 0} msg] {

				log 1 "failed to settle all standard market #$market_id"
				incr n_errors
			}
		}

		if {$market_cat == "X"} {

			set c [catch {ADMIN::IXMARKET::stl_settle_index $market_id} msg]

			if {$c} {
				log 1 "failed to settle index market #$market_id"
				incr n_errors
			}
		}
	}

	db_close $res

	if {$n_errors == 0} {

		if {$STL_LOG_ONLY} {

			log 1 "STL_LOG_ONLY true : not marking event settled"

		} else {

			set stmt [stl_qry_prepare SET_SETTLED]

			if [catch {inf_exec_stmt $stmt $USERNAME E $ev_id $REQ_GUID} msg] {
				log 1 "failed to mark event #$ev_id as settled"
				error "failed to mark event #$ev_id as settled"
			}

		}

	} else {

		log 1 "$n_errors markets not settled"
		error "$n_errors markets not settled"

	}

	return 0
}


#
# ----------------------------------------------------------------------------
# Settle a market
# ----------------------------------------------------------------------------
#
proc stl_settle_mkt {ev_mkt_id {clobber 1}} {

	global USERNAME
	global errorInfo

	variable SELN
	variable DHEAT
	variable MKT
	variable STL_LOG_ONLY
	variable FUNC_AUTO_DH
	variable REQ_GUID

	if {$clobber != 0} {
		catch {unset SELN}
		catch {unset DHEAT}
		catch {unset MKT}
	}

	set n_errors 0
	set p_error  0

	log 1 "settling market #$ev_mkt_id"

	log 1 "settle pools - start"

	#
	# Settle any pools
	#
	if {[ADMIN::SETTLE::POOLS::stl_settle_mkt_pools $ev_mkt_id] == "NO"} {
		set p_error 1
	}

	log 1 "settle pools - end"


	#
	# Auto Generation of Dead Heat Reductions
	#
	if {$FUNC_AUTO_DH} {

		if {[stl_mkt_can_auto_dh $ev_mkt_id]} {

			log 1 "market #$ev_mkt_id: generating dead heat reductions"

			if {![ob_dh_redn::insert_auto "M" $ev_mkt_id]} {
				error [ob_dh_redn::get_err]
			}

		} else {
			log 1 "market #$ev_mkt_id: opted out of dead heat reduction generation"
		}
	}

	set MKT($ev_mkt_id,auto_calc) 1

	#
	# Check all selections have confirmed results
	#
	set stmt [stl_qry_prepare GET_MKT_SELNS]

	set res [inf_exec_stmt $stmt $ev_mkt_id]

	set n_selns [db_get_nrows $res]


	for {set s 0} {$s < $n_selns} {incr s} {

		set ev_oc_id [db_get_col $res $s ev_oc_id]
		set result   [db_get_col $res $s result]

		if {$result == "-"} {
			log 1 "market #$ev_mkt_id: selection #$ev_oc_id has no confirmed result"
			incr n_errors
		}
	}

	set err_str ""

	if {$p_error == 1} {
		log 1 "problem trying to settle market pools"
		# dont let pools settlement stop the rest of the market settling
		# append err_str "problem trying to settle market pools\n"
	}
	if {$n_errors > 0} {
		log 1 "$n_errors selections have no confirmed result"
		append err_str "$n_errors selections have no confirmed result"
	}
	if {$err_str != ""} {
		db_close $res
		error $err_str
	}

	#
	# Settle each selection...
	#
	for {set s 0} {$s < $n_selns} {incr s} {

		set ev_oc_id [db_get_col $res $s ev_oc_id]

		#
		# call the procedure for settling a selection, but make it not
		# clobber any selection/market information which has been cached
		#
		if [catch {stl_settle_seln $ev_oc_id 0} msg] {

			log 1 "failed to settle all bets for selection #$ev_oc_id"
			foreach m [split $errorInfo "\n"] {
				log 1 $m
			}
			incr n_errors
		}
	}

	db_close $res

	if {$n_errors == 0} {

		if {$STL_LOG_ONLY} {

			log 1 "STL_LOG_ONLY true : not marking market settled"

		} else {

			set stmt [stl_qry_prepare SET_SETTLED]

			if [catch {inf_exec_stmt $stmt $USERNAME M $ev_mkt_id $REQ_GUID} msg] {
				log 1 "failed to mark seln #$ev_oc_id as settled"
				error "failed to mark seln #$ev_oc_id as settled"
			}

		}

	} else {

		log 1 "$n_errors selections not settled"
		error "$n_errors selections not settled"

	}

	return 0
}



#
# ----------------------------------------------------------------------------
# Settle a spread bet market
# ----------------------------------------------------------------------------
#
proc stl_settle_spread_mkt {ev_mkt_id {clobber 1}} {

	global USERNAME DB errorInfo

	variable SELN
	variable MKT
	variable STL_LOG_ONLY
	variable REQ_GUID

	if {$clobber != 0} {
		catch {unset SELN}
		catch {unset MKT}
	}

	log 1 "settling market #$ev_mkt_id"

	#
	# There's a stored procedure to settle an individual spread
	# bet. To deal with early settlement (Chiffon) it's necessary
	# to settle all bets on a per customer per market basis in one
	# transaction.
	#
	set stmt  [stl_qry_prepare GET_SPREAD_BETS]
	set stmt2 [stl_qry_prepare SETTLE_SPREAD_BET]
	set stmt3 [stl_qry_prepare REPAY_EARLY_SETTLE]

	set rs [inf_exec_stmt $stmt $ev_mkt_id]

	set n_bets [db_get_nrows $rs]

	set anythingbad 0

	if {$n_bets > 0} {

		inf_begin_tran $DB

		for {set r 0} {$r < $n_bets} {} {

			set bad 0

			set cur_acct_id [db_get_col $rs $r acct_id]

			for {set s $r} {$s < $n_bets &&
				[db_get_col $rs $r acct_id]==$cur_acct_id  && !$bad} {incr s} {

			    set spread_bet_id [db_get_col $rs $s spread_bet_id]
				if {[catch {
					inf_exec_stmt $stmt2 $spread_bet_id
				} msg]} {
					set bad 1
					set myerr\
						"Failed to settle spread bet id $spread_bet_id: $msg"
					log 1 $myerr
					error $myerr
					break
				}

			}

			if {!$bad} {
				inf_commit_tran $DB
				log 1 "Settled all bets for acct $cur_acct_id in mkt $ev_mkt_id"
			} else {
				#
				# Can't settle this user's bets in this market
				#
				inf_rollback_tran $DB
				set anythingbad 1
				set myerr "Failed to settle all bets for acct $curr_acct_id. "
				append myerr "They all remain unsettled."
				log 1 $myerr
				error $myerr
			}
			set r $s
		}
	}

	db_close $rs

	if {$anythingbad == 0} {

		if {$STL_LOG_ONLY} {

			log 1 "STL_LOG_ONLY true : not marking market settled"

		} else {

			set stmt [stl_qry_prepare SET_SETTLED]

			if [catch {inf_exec_stmt $stmt $USERNAME M $ev_mkt_id $REQ_GUID} msg] {
				log 1 "failed to mark $ev_mkt_id as settled"
				error "failed to mark $ev_mkt_id as settled"
			}

		}

	} else {

		log 1 "$n_errors selections not settled"
		error "$n_errors selections not settled"

	}

	return 0
}


#
# ----------------------------------------------------------------------------
# Settle a selection
# ----------------------------------------------------------------------------
#
proc stl_settle_seln {ev_oc_id {clobber 1} {cr_after {}} {stl_after {}}} {

	global USERNAME errorInfo DB

	variable SELN
	variable DHEAT
	variable MKT
	variable STL_LOG_ONLY
	variable STL_BET_STATUS
	variable REQ_GUID

	if {$clobber != 0} {
		catch {unset SELN}
		catch {unset DHEAT}
		catch {unset MKT}
	}

	if {![OT_CfgGet LOG_DESC_ONLY 0]} {
		log 1 "settling selection #$ev_oc_id"
	}

	#
	# Get selection info
	#
	stl_get_seln_info $ev_oc_id

	if {[OT_CfgGet LOG_DESC_ONLY 0]} {
		log 1 "settling selection $SELN($ev_oc_id,desc)"
	}

#	log_seln_info $ev_oc_id 1

	if {$SELN($ev_oc_id,result) == "-"} {
		log 1 "selection #$ev_oc_id does not have a result : cannot settle"
		error "selection #$ev_oc_id does not have a result : cannot settle"
	}

	#
	# Get bet settlement candidates
	#

	# we may be running this to check/resettle bets
	switch -- $STL_BET_STATUS {
		"Y" {
			set status1 "Y"
			set status2 "Y"
		}
		"N" {
			set status1 "N"
			set status2 "N"
		}
		"-" {
			set status1 "Y"
			set status2 "N"
		}
	}

	if {!$STL_LOG_ONLY} {
	    set stmt [stl_qry_prepare GET_SELN_BETS]
	} else {
	    set cr_where ""
	    set stl_where ""

	    if {$cr_after != {}} {
		set cr_where "and b.cr_date > '${cr_after}' "
	    }
	    if {$stl_after != {}} {
		set stl_where "and b.settled_at > '${stl_after}' "
	    }

		#
		# Don't settled hedged bets
		#
		# find out from site operator/channel tables what the hedging channel is
		set sql {
			select
				c.channel_id
			from
				tChannel c,
				tChanGrpLink cgl
			where
				c.channel_id = cgl.channel_id and
				cgl.channel_grp = 'HEDG'
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		# there could be many hedging channels if there are multiple sites
		# being run off the single app
		if {$rows > 0} {
			# initialise list
			set hedge_channels {}

			# put all hedging channels in a list
			for {set i 0} {$i < $rows} {incr i 1} {
				lappend hedge_channels [db_get_col $res $i channel_id]
			}

			# form the where clause eg "not matches [Y]"
			set hedge_where "and b.source not matches '\[[join $hedge_channels {}]\]'"
		} else {
			# no hedging channel
			set hedge_where {}
		}

	    set sql [subst {
		select distinct
		        o.bet_id
	        from
		        tOBet o,
		        tBet  b,
		        tBetType t
	        where
		        o.ev_oc_id = ? and
		        o.bet_id   = b.bet_id and
		        b.bet_type = t.bet_type and
		        b.settled  in (?,?) and
		        b.status   <> 'S' and
		        b.bet_type <> 'MAN' and
		        t.bet_settlement <> 'Manual'
				$hedge_where
		        $cr_where
		        $stl_where
	    }]

	    set stmt [inf_prep_sql $DB $sql]
	}

	set res [inf_exec_stmt $stmt $ev_oc_id $status1 $status2]

	set n_bets [db_get_nrows $res]

	set n_errors 0

	log 1 "n_bets=$n_bets"

	#
	# Settle each bet
	#
	for {set b 0} {$b < $n_bets} {incr b} {

		set bet_id [db_get_col $res $b bet_id]
		if [catch {set status [stl_settle_bet $bet_id 0]} msg] {
			log 1 "**Error** $bet_id : $msg"
			foreach l [split $errorInfo "\n"] {
				log 1 "     ==> $l"
			}
			incr n_errors
		} else {
			log 1 "$bet_id ==> $status"
		}
	}

	db_close $res



	if {$n_errors == 0} {

		if {$STL_LOG_ONLY} {

			log 1 "STL_LOG_ONLY true : not marking selection settled"

		} else {

			set stmt [stl_qry_prepare SET_SETTLED]

			if [catch {inf_exec_stmt $stmt $USERNAME S $ev_oc_id $REQ_GUID} msg] {
				log 1 "failed to mark seln #$ev_oc_id as settled"
				error "failed to mark seln #$ev_oc_id as settled"
			}

		}

	} else {

		log 1 "$n_errors selections not settled"
		error "$n_errors selections not settled"

	}

	return 0
}

#
# ----------------------------------------------------------------------------
# Settle a betting in running index
# ----------------------------------------------------------------------------
#
proc stl_settle_bir {mkt_bir_idx} {

	global USERNAME
	global errorInfo

	variable STL_LOG_ONLY
	variable REQ_GUID

	log 1 "settling bir index #$mkt_bir_idx"

	#
	# Get bet settlement candidates
	#
	set stmt [stl_qry_prepare GET_BIR_BETS]

	set res [inf_exec_stmt $stmt $mkt_bir_idx]

	set n_bets [db_get_nrows $res]

	set n_errors 0

	log 1 "n_bets=$n_bets"

	#
	# Settle each bet
	#
	for {set b 0} {$b < $n_bets} {incr b} {

		set bet_id [db_get_col $res $b bet_id]

		if [catch {set status [stl_settle_bet $bet_id 0]} msg] {
			log 1 "**Error** $bet_id : $msg"
			foreach l [split $errorInfo "\n"] {
				log 1 "     ==> $l"
			}
			incr n_errors
		} else {
			log 1 "$bet_id ==> $status"
		}
	}

	db_close $res

	if {$n_errors == 0} {

		if {$STL_LOG_ONLY} {

			log 1 "STL_LOG_ONLY true : not marking selection settled"

		} else {

			set stmt [stl_qry_prepare SET_SETTLED]

			if [catch {inf_exec_stmt $stmt $USERNAME B $mkt_bir_idx $REQ_GUID} msg] {
				log 1 "failed to mark bir index #$mkt_bir_idx as settled"
				error "failed to mark bir index #$mkt_bir_idx as settled"
			}

		}

	} else {

		log 1 "$n_errors bir indices not settled"
		error "$n_errors bir indices not settled"

	}

	return 0

}


#
# ----------------------------------------------------------------------------
# Settle the indicated bet
#
# One of two status values is returned:
#   NO      - the bet cannot be settled
#   SETTLED - the bet has been settled
#
# If an error occurs (there are lots of things that can go wrong), it
# needs to be causght by the caller
# ----------------------------------------------------------------------------
#
proc stl_settle_bet {bet_id {clobber 1}} {

	variable BET

	variable SELN
	variable DHEAT
	variable MKT

	log 1 "Attempting to settle bet #$bet_id"

	if {$clobber != 0} {
		catch {unset SELN}
		catch {unset DHEAT}
		catch {unset MKT}
	}

	#
	# Force loading of bet information
	#
	stl_get_bet_info $bet_id

	log 2 "  bet type:  $BET(bet_type)"
	log 2 "  leg type:  $BET(leg_type)"
	log 2 "  num legs:  $BET(num_legs)"
	log 2 "  num selns: $BET(num_selns)"
	log 2 "  num lines: $BET(num_lines)"

	#
	# Try to settle the bet using the simple settler (for simple bets,
	# where the result is available, we expect this to cover about 80%
	# of bets
	#
	log 3 "attempting simple settlement"

	set status [stl_settle_bet_simple $bet_id]

	#
	# The simple settler reckons it's not up to the job, so crank up the
	# full-blooded version
	#
	if {$status == "COMPLEX"} {

		log 3 "attempting complex settlement"

		set status [stl_settle_bet_complex $bet_id]
	}

	log 1 "Settlement for bet #$bet_id returning $status"

	catch {unset BET}

	return $status
}


#
# ----------------------------------------------------------------------------
# Attempt simple settlement of a bet
#
# A bet can be settled by this procedure if
#   - it is a single and there is a result for the selection
#   - it is a "to-win" accumulator and there is a 'Lose' or 'Place'
#     result for the selection
#
# This procedure returns one of three status codes:
#   NO      - the bet cannot be settled yet (by implication, the bet is
#             one which could ordinarily be settled simply). This status
#             is returned when the bet is simple, but there is no selection
#             result. Note that complex bets can be settled, even in the
#             absence of some results (for example, a win double can be
#             settled as soon as either leg is a loser).
#   SETTLED - the bet has been settled, no further action is required.
#   COMPLEX - the bet must be given to the full settler (it is not amenable
#             to simple settlement).
# ----------------------------------------------------------------------------
#
proc stl_settle_bet_simple {bet_id} {

	variable SELN
	variable MKT
	variable BTYPE
	variable BET

	#
	# Pull some key information from the BET array
	#
	set bet_type $BET(bet_type)
	set leg_type $BET(leg_type)
	set leg_sort $BET(1,leg_sort)
	set ev_oc_id $BET(1,1,ev_oc_id)

	#we may have a permed single for example
	if {$BET(num_lines) > 1} {
		return COMPLEX
	}

	if {$leg_sort != "--"} {
		return COMPLEX
	}

	log 3 "leg sort is $leg_sort"

	#
	# Force loading of this selection's information
	#
	stl_get_seln_info $ev_oc_id

	set result $SELN($ev_oc_id,result)

	#
	# If the bet is a single leg simple single (i.e. it is a stright fixed-
	# odds single bet on a single selection, not a forecast/tricast/scorecast),
	# then there are several shortcuts we can make in settling:
	#
	#   1) If the selection result is Lose, or the result is place and
	#      the leg type is "To Win", the bet can be immediately
	#      settled as a loser (55% of bets according to BlueSQ's data)
	#
	#   2) If the selection is a Void the bet can be settled instantly
	#      as a refund (another 1.5% of bets)
	#
	#   3) If the selection is Win or the selection is Place and the leg type
	#      is each-way or place, we can settle it easily because it is a
	#      simple single (18% of bets)
	#   4) If the bet has been placed after the no more bet time of the event, and
	#      the operation in tev.over_bet_time_op is void, then the bet can be automatically voided,
	#      no matter what the result of the selection is
	#
	# It's worth putting in this "optimisation" because it tackles about
	# 75% of bets for very little effort
	#
	if {$bet_type == "SGL"} {

		log 2 "simple settlement: bet type is SGL"

		if {[OT_CfgGet ENABLE_LATE_BET_TOL_RULE 0 ]} {
			if { [ stl_is_after_bet_time_void $bet_id 1 $ev_oc_id ] } {
				log 1 "bet placed after no more bet time ==> void"
				stl_bet_void $bet_id "Selection $SELN($ev_oc_id,desc) ($ev_oc_id) voided because the bet was stuck too late."
				return SETTLED
			}
		}


		if {$result == "-"} {
			log 1 "can't settle bet - selection result is '-'"
			return NO
		}

		if {$result == "L" || ($result == "P" && $leg_type == "W")} {
			log 1 "result = $result, leg_type = $leg_type ==> lose"
			stl_bet_lose $bet_id
			return SETTLED
		}

		if {$result == "V"} {
			log 1 "result = $result ==> void"
			stl_bet_void $bet_id
			return SETTLED
		}

		if {$result == "W" || $result == "U" ||
				($result == "P" && ($leg_type == "E" || $leg_type == "P"))} {

			log 1 "result = $result, leg_type == $leg_type ==> win"

#			log_seln_info $ev_oc_id 1

			stl_bet_win_sgl $bet_id $ev_oc_id

			return SETTLED
		}

		error "unexpected bet state..."
	}

	# Rebind BTYPE array for check resettlement operation
	if {![info exists BTYPE($bet_type,stl_sort)]} {
	    stl_get_bet_types
	}

	#
	# If the bet is a straight accumulator, and the selection is a
	# loser, or the result is place and the leg type is "to win"
	# then it can be settled immediately (this accounts
	# for another 12% of bets
	#
	if {$BTYPE($bet_type,stl_sort) == "A" &&
			($result == "L" || ($result == "P" && $leg_type == "W"))} {

		log 1 "$bet_type, result=$result, leg_type=$leg_type ==> lose"
		stl_bet_lose $bet_id
		return SETTLED
	}

	#
	# That's all the easy cases taken care of - all the rest have to
	# be crunched longhand
	#
	return COMPLEX
}


#
# --------------------------------------------------------------------------
# Try to settle a complex bet - this is a bet which could not be settled
# by the simple settler, so the full monty is required
# --------------------------------------------------------------------------
#
proc stl_settle_bet_complex {bet_id} {

	variable BET
	variable SELN
	variable MKT
	variable BTYPE
	variable MAX_PAY_SORT
	variable CT_BONUS
	variable BCONTROL

	# Make sure BCONTROL is up to date
	stl_get_control

	#
	# First, check whether the bet can be settled - this is complex -
	# we need to examine the bet and the selections against which it
	# was placed
	#
	set status [stl_bet_can_be_settled $bet_id]

	if {$status == "NO"} {

		#
		# Can't be settled (yet)
		#
		return NO

	} elseif {$status == "LOSE"} {

		#
		# It's a loser, so settle it as such
		#
		stl_bet_lose $bet_id
		return SETTLED

	} elseif {$status == "VOID"} {

		#
		# It's a full void - refund everything
		#
		stl_settle_bet_do_db\
			$bet_id\
			0\
			0\
			$BET(num_lines)\
			0

		return SETTLED

	} elseif {$status != "YES"} {

		error "unexpected status ($status) from stl_bet_can_be_settled"

	}

	log 1 "bet can be settled: begin settlement of bet #$bet_id"

	#
	# Need to calculate the following information:
	#   - return for the bet
	#   - number of win lines
	#   - number of lose lines
	#   - number of void lines
	#
	set num_lines_win  0
	set num_lines_lose 0
	set num_lines_void 0
	set bet_return     0.0
	set bet_payout     0.0

	#
	# Get the list of line combinations for the bet
	#
	# For an each-way bet, the number of lines stored in the database is
	# twice the number of lines generated by BMbet, because each line
	# appears twice, once for the win part, once for the place
	#
	# Also, note that the number of lines stored in tBet (as num_lines)
	# will not be the same as the number of perms returned by BMbet - for
	# example, a reverse forecast treble will have one leg perm (from BMbet:
	# {1 2 3} but 8 lines generated by all the combinations
	#
		set bet_type $BET(bet_type)
	if {$BTYPE($bet_type,is_perm) != "Y"} {
		set line_perms [BETPERM::bet_lines $bet_type]
	} else {
		log 1 "producing line perms"

		#bankers have to be in every leg so we'll just look at combinations
		#of the remaining legs
		set num_selns [expr {$BTYPE($bet_type,num_selns) -
							 $BET(num_bankers)}]

		log 1 "num selns : $num_selns"

		set bankers             [list]
		set legs_combi          [list]
		array set legs_no_combi [list]

		log 1 "number of legs $BET(num_legs)"
		for {set l 1} {$l <= $BET(num_legs)} {incr l} {
			set no_combi $BET($l,no_combi)

			if {$BET($l,banker) == "Y"} {
				lappend bankers $l
				continue
			} elseif {[lsearch $BET(leg_losers) $l] != -1} {
				#leg is a loser

				#we won't be considering combinations of these lines
				#when perming so we rack up the losing lines now
				OT_LogWrite 1 "eliminating leg $l as loser"
				continue
			}

			if {$no_combi == ""} {
				log 1 "adding to legs_combi: $l"
				lappend legs_combi $l
			} else {
				log 1 "adding to legs_no_combi: $l"
				lappend legs_no_combi($no_combi) $l
			}
		}

		foreach n [array names legs_no_combi] {
			lappend legs_combi $legs_no_combi($n)
		}

		OT_LogWrite 1 "legs_combi = $legs_combi"

		#because we have only just eliminated losers it may well be that
		#the number of selections left is less than the number that need
		#to be combined
		if {$num_selns > [llength $legs_combi]} {
			OT_LogWrite 1 "not enough winners"
			stl_bet_lose $bet_id
			return SETTLED
		}

		# This nasty bit maps each part whether single or group to
		# a single element and the original part saved in gmap
		# i.e. {a} {b c} {d e f} becomes 0 1 2 which is then
		# permed and then the real values substituted back in after
		# we've done the perm.
		array set gmap [list]
		set glist [list]
		for {set i 0} {$i < [llength $legs_combi]} {incr i} {
			set gmap($i) [lindex $legs_combi $i]
			lappend glist $i
		}

		#so what we have now is a list of all the permutations of
		#non banker groups - now we work out the lines for each of
		# these group combinations
		# ie for DBLS from 4 where legs 2 and 3 can't be combined
		#group_perms = {0 1} {0 {2 3}} {1 {2 3}}
		#we just need to break this out into legs that can be combined
		#and add in the bankers
		set line_perms [list]
		foreach combi [eval BETPERM::BMpermgen $num_selns $glist] {
			set perms [list]
			foreach item $combi {
				lappend perms $gmap($item)
			}
			set line_perms [concat\
							    $line_perms\
							    [BETPERM::combine_grps $perms $bankers]]
		}
	}

	log 1 "bet has [llength $line_perms] basic lines"

	#
	# Leg type (W/P/E) has a bearing on lots of stuff we do below
	#
	switch -- $BET(leg_type) {
		W {
			set leg_types [list W]
		}
		P {
			set leg_types [list P]
		}
		E {
			set leg_types [list W P]
		}
		default {
			error "unexpected leg type $BET(leg_type)"
		}
	}

	#
	# Process each requested leg type separately
	#
	foreach leg_type $leg_types {

		#
		# Settling a multiple is just settling each line (which is an
		# accumulator) and then adding up the returns and the number of
		# each sort of line at the end - it's easy...
		#
		# ...but there are some complications when forecasts/tricasts are
		# involved, because we have an extra level of looping, over the perms
		# in the forecast
		#
		set line_no 0

		foreach line $line_perms {

			incr line_no

			#
			# If the line cannot be handled as a straight accumulator, continue.
			# Any other line type should be handled by stl_settle_bet_ATC (below)
			#
			set line_type [BETPERM::bet_line_type $BET(bet_type) $line_no]
			if {$line_type != "A"} {
				continue;
			}

			#
			# calculate how many bets there are in this leg
			#
			set num_line_bets 1
			set num_line_legs [llength $line]

			foreach leg $line {
				set num_line_bets [expr {$num_line_bets*$BET($leg,num_bets)}]
			}

			log 3 "line $line_no ($leg_type): $num_line_bets"\
				"bets in [llength $line] legs ($line)"

			set line_result -
			set line_voids  [list]

			set returns [list 1.0]

			set num_line_legs_void 0

			foreach leg $line {

				lappend line_voids 0

				log 9 "line: $line_no, leg : $leg result = $BET($leg,leg_result)"

				if {$BET($leg,leg_result) == "L"} {

					set line_result L

					log 7 "  leg $leg result=L => line loses"

					#
					# once a leg is a loser, the line is a loser: there's no
					# need to evauluate the other legs - this overrides all
					# other consideratons, such as whether subsequent legs
					# are void, etc
					#
					break

				} elseif {$BET($leg,leg_result) == "V"} {

					log 7 "  leg $leg result=V"

					#
					# This leg is void - we count how many void legs there are
					# in the line - if all the legs are void, the line is void
					# We also need to store how many bets there were in the
					# leg, so we can calculate how many voids lines there were
					# in total
					#
					set line_voids [lreplace\
						$line_voids end end $BET($leg,num_bets)]

					incr num_line_legs_void

					#
					# If the leg wasn't --/SC, need to do the combinations
					# explosion to increase the number of lines with a
					# return (see below)
					#
					set t_returns [list]

					foreach v $returns {
						for {set c 1} {$c <= $BET($leg,num_bets)} {incr c} {
							lappend t_returns $v
						}
					}

					set returns $t_returns

				} elseif {$BET($leg,leg_result) == "W" ||
								$BET($leg,leg_result) == "U"} {

					#
					# This leg has been marked as a "W" - for the default (--)
					# and scorecast leg types, this means that the leg
					# produces a return and has no void or lose elements to
					# it. For the SF/TC/RF/CF/CT cases, the leg produces a
					# return, but there may also be a number of lose and
					# void combinations, all of which need counting...
					#
					set leg_sort $BET($leg,leg_sort)

					if {$leg_sort == "--"} {

						set r $BET($leg,leg_return,$leg_type)

						#
						#Check for "Lucky X" odds-based consolations
						# (eg, double odds settlement for the one winning single bet).
						#
						if {[lsearch [stl_get_bet_names LuckyX] $BET(bet_type)] >= 0} {
							if {[OT_CfgGet STL_LUCKYX_NEW_CALC "N"] == "Y"} {

								# use shiny new Lucky X calculation
								set r [stl_luckyx_leg_return $bet_id $leg $leg_type]

							} elseif {$BET(bonus,num_win_selns) == 1 &&
								$BET(bonus,num_void_selns) == 0 &&
								$leg_type == "W"} {

									# use legacy hardcoded Lucky X calculation
									set r_new [stl_simple_leg_return $bet_id $leg W 2]
									log 2 "  leg $leg consolation takes return from $r to $r_new"
									set r $r_new
							}
						}

						#
						# Even though the leg is marked as a win, there
						# might still be a unit return of 0.0, in which case
						# it's a loser... and the line's a loser...
						#
						if {$r == 0.0} {

							set line_result L

							log 7 "  leg $leg result=$BET($leg,leg_result),rtn=$r => line loses"

							break

						}

						set t_returns [list]

						foreach v $returns {
							lappend t_returns [expr {$v*$r}]
						}

						set returns $t_returns

						log 7 "  leg $leg (standard) ($leg_type) return = $r"

					} elseif {[string first $leg_sort "SC/WH/MH/OU/HL/hl/CW/AH/A2"] >= 0} {

						#
						# For now (call me naive), we are working on the
						# assumption that there can be no each-way legs
						# in a multiple with ordinary "to-win" legs such as this
						#
						set r $BET($leg,leg_return)

						set t_returns [list]

						foreach v $returns {
							lappend t_returns [expr {$v*$r}]
						}

						set returns $t_returns

						log 7 "  leg $leg ($leg_sort) return is $r"

					} else {

						set line_voids [lreplace\
							$line_voids end end $BET($leg,leg_voids)]

						#
						# This is a combination line - there might be a large
						# number of bets here. We need to take the existing
						# win lines and "combine" them with each of the
						# combination returns for this leg. If a combination
						# is void, make its return "1.0"
						#
						set t_returns [list]

						foreach v $returns {

							#
							# "explode" all the combinations for this leg
							# Each win/void combination will grow the number
							# of legs with returns. For example, if the
							# first leg of a double is a straight fixed odds
							# single which has won, there will be one win return
							# in $returns. If the next leg is a combination
							# forecast from 5 selections (20 bets), of which
							# 2 win, 8 are void, 10 lose, then we will have
							# 10 lines with a return after, and 10 losing lines
							# (the 10 lines with a return are the 2 win and the
							# 8 void)
							#
							for {set c 1} {$c <= $BET($leg,num_bets)} {incr c} {

								set c_ret $BET($leg,combi,$c)

								#
								# A leg with a void just carries through
								# with an unchanged return
								#
								if {$c_ret == "V"} {
									set c_ret 1.0
								}

								#
								# we can prune any line from the wins list if
								# the return is 0 - a return of 0 => lose
								#
								if {$c_ret != 0} {

									set n_ret [expr {$v*$c_ret}]

									log 7 "  leg $leg, combi $c"\
										"return is $n_ret"

									lappend t_returns $n_ret
								}
							}
						}

						set returns $t_returns
					}

				} else {
					error "unexpected result $BET($leg,leg_result) in bet line"

				}
			}

			#
			# We now know the outcome of this bet line. Lose and Void are
			# straightforward. For a return, we need to add it to the total
			# return for this bet so far, and bump the number of win lines
			# (and, if this is an each way bet, possibly bump the number of
			# lose lines too).
			#
			if {$line_result == "L"} {

				incr num_lines_lose $num_line_bets

				log 7 "line $line_no loses ($num_line_bets) bets"

			} elseif {$num_line_legs_void == $num_line_legs} {

				incr num_lines_void $num_line_bets

				log 7 "line $line_no void ($num_line_bets) bets"

			} else {

				#
				# line wasn't void or lose, so it must be a "winner". However,
				# just because a line is a "winner" doesn't mean that all of the
				# bets associated with the line won. For example, a line which
				# is a reverse forecast treble will have 0, 1, 2, 4 or 8 win
				# lines (AB,BA)(CD,DC)(EF,FE). The "0" case is taken care of
				# above (the whole line was a loser), but we need to deal with
				# the other cases here.
				#
				set num_leg_lines_void [expr [join $line_voids *]]
				set num_leg_lines_win  [llength $returns]

				#
				# Careful now:
				#
				# Void lines have accrued thus far as "win" lines with a return
				# of 1.0. We must subtract the number of void lines from the
				# number of "win" lines to get the real number of win lines,
				# and adjust the return appropriately
				#
				set num_leg_lines_win [expr\
					{$num_leg_lines_win-$num_leg_lines_void}]

				#
				# Each line has to be win/lose/void, so number of losers
				# drops out like this:
				#
				set num_leg_lines_lose [expr\
					{$num_line_bets-$num_leg_lines_win-$num_leg_lines_void}]

				log 1 "line $line_no: num_leg_lines_win  = $num_leg_lines_win"
				log 1 "line $line_no: num_leg_lines_lose = $num_leg_lines_lose"
				log 1 "line $line_no: num_leg_lines_void = $num_leg_lines_void"

				incr num_lines_win  $num_leg_lines_win
				incr num_lines_void $num_leg_lines_void
				incr num_lines_lose $num_leg_lines_lose

				#
				# Return for all the bets in the leg is the sum of all the
				# combination returns in the returns list
				#
				if {[llength $returns]} {
					set line_return [expr [join $returns +]]

					if {$num_leg_lines_void > 0} {
						set line_return [expr\
							{$line_return-$num_leg_lines_void}]
						log 7 "adjusted returns (voids) = $line_return"
					}
				} else {
					set line_return 0.0
				}

				log 1 "line $line_no ($leg_type) return = $line_return"

				#
				# Check for "Lucky X" returns-based bonuses
				# (eg, 10% bonus if all selections were winners)
				#
				if {[lsearch [stl_get_bet_names LuckyX] $BET(bet_type)] >= 0} {
					if {[OT_CfgGet STL_LUCKYX_NEW_CALC "N"] == "Y"} {

						# use shiny new Lucky X calculation
						set line_return [stl_luckyx_return $bet_id $leg_type $line_return]
					}
				}
				set line_payout [expr {$line_return*$BET(stake_per_line)}]

				#
				# If MAX_PAY_SORT is LINE (rather than BET), we must clip
				# the line winnings to max_payout (SLOT)
				#
				if {$MAX_PAY_SORT == "LINE"} {
					if {$line_payout > $BET(max_payout)} {
      						if {$BCONTROL(max_payout_parking) == "Y"} {
							log 1 "Max payout exceeded - parking bet for manual settlement"
							send_max_payout_notification $BET(acct_id) $BET(bet_id)
						} else {
							set line_payout $BET(max_payout)
						}
					}
				}

				#
				# Account for Stake when getting bet_payout:
				# If the winnings (payout minus stake) are more than the max payout,
				# we pay out the max payout plus the stake!
				#
				if {$MAX_PAY_SORT == "LINE_STAKE"} {
					if {[expr $line_payout - $BET(stake_per_line)] > $BET(max_payout)} {
      						if {$BCONTROL(max_payout_parking) == "Y"} {
							log 1 "Max payout exceeded - parking bet for manual settlement"
							send_max_payout_notification $BET(acct_id) $BET(bet_id)
						} else {
							set line_payout [expr $BET(max_payout) + $BET(stake_per_line)]
						}
					}
				}

				set bet_return [expr {$bet_return+$line_return}]
				set bet_payout [expr {$bet_payout+$line_payout}]
			}

		}

	}

	#
	# Any-to-come (ATC) bets also need special treatment.  This is because
	# the lines within the bets cannot be handled as straight accumulators.
	# Since some bet types consist of both ATC lines and normal
	# accumulator lines (eg Round Robin bets), it would make more sense to
	# do this check at the line by line level within stl_settle_bet_complex,
	# using BETPERM::get_line_type to do this.
	#
	# To be cautious however, we branch this point off a lot later so we
	# can keep the two sets of code fairly seperate for now...
	#
	if {[lsearch [stl_get_bet_names ATC] $BET(bet_type)] >= 0} {

		array set ATC_Lines ""

		stl_settle_bet_ATC $bet_id ATC_Lines

		set num_lines_win  [expr {$num_lines_win + $ATC_Lines(num_lines_win)}]
		set num_lines_lose [expr {$num_lines_lose + $ATC_Lines(num_lines_lose)}]
		set num_lines_void [expr {$num_lines_void + $ATC_Lines(num_lines_void)}]
		set bet_payout     [expr {$bet_payout + $ATC_Lines(bet_payout)}]

	}


	#
	# Check if a LuckyX bonus is due for all selections correct
	#
	if {[lsearch [stl_get_bet_names LuckyX] $BET(bet_type)] >= 0 &&
                [OT_CfgGet STL_LUCKYX_NEW_CALC "N"] != "Y"} {
		set all_correct 0
		switch -- $BET(bet_type) {
	    	L15 {
				if {$BET(bonus,num_win_selns) == 4} {
					set all_correct 1
				}
			}
			L31 {
				if {$BET(bonus,num_win_selns) == 5} {
					set all_correct 1
				}
			}
			L63 {
				if {$BET(bonus,num_win_selns) == 6} {
					set all_correct 1
				}
			}
		}
		if {$all_correct} {
			array set STL_LUCKYX_BONUS [OT_CfgGet STL_LUCKYX_BONUS "L15 1.0 L31 1.0 L63 1.0"]
			if {[info exists STL_LUCKYX_BONUS($BET(bet_type))]} {
				set extra $STL_LUCKYX_BONUS($BET(bet_type))
			} else {
				set extra 1.0
			}
			log 2 "bet return increased by $extra (LuckyX bonus)"
			set bet_payout [expr {$bet_payout*double($extra)}]
		}
	}
	if {$num_lines_win > 0 && $CT_BONUS(enabled)} {
		#
		# Check if a per-class or per-type bonus is applicable
		#
		set lc [list]
		set lt [list]

		for {set l 1} {$l < $BET(num_legs)} {incr l} {

			set s $BET($l,1,ev_oc_id)

			lappend lc $SELN($s,ev_class_id)
			lappend lt $SELN($s,ev_type_id)
		}

		set lc [lsort -unique -integer $lc]
		set lt [lsort -unique -integer $lt]

		set bonus_rate 0.0

		if {$bonus_rate == 0.0} {
			if {[llength $lt] == 1} {
				set t [lindex $lt 0]
				if {[info exists CT_BONUS(type,$t)]} {
					set bonus_rate $CT_BONUS(type,$t)
					log 1 "Applying per-type bonus ($c) of $bonus_rate"
				}
			}
		}
		if {$bonus_rate == 0.0} {
			if {[llength $lc] == 1} {
				set c [lindex $lc 0]
				if {[info exists CT_BONUS(class,$c)]} {
					set bonus_rate $CT_BONUS(class,$c)
					log 1 "Applying per-class bonus ($c) of $bonus_rate"
				}
			}
		}
		set bet_payout [expr {$bet_payout*(1.0+($bonus_rate/100.0))}]
	}

	# Check whether this bet is a blockbuster.
	set is_blockbuster [list]
	set is_blockbuster [check_is_blockbuster $bet_id]

	if {[lindex $is_blockbuster 0] && $BET(bonus,num_void_selns) == 0} {

		# This is a blockbuster bet

		set blockbuster_bonus_per  [lindex $is_blockbuster 1]

		# Apply bonus only to winnings (so remove stake from bonus calculation)

		set bb_bonus   [expr {($bet_payout - $BET(stake_per_line))*($blockbuster_bonus_per/100.0)}]
		set bet_payout [expr {$bet_payout + $bb_bonus}]

		log 1 "* bet_id $bet_id is blockbuster bet -> $blockbuster_bonus_per % applies -> winnings increased by $bb_bonus to $bet_payout"

	}

	if {$MAX_PAY_SORT == "BET"} {
		if {$bet_payout > $BET(max_payout)} {
   			if {$BCONTROL(max_payout_parking) == "Y"} {
				log 1 "Max payout exceeded - parking bet for manual settlement"
				send_max_payout_notification $BET(acct_id) $BET(bet_id)
			} else {
				set bet_payout $BET(max_payout)
				log 1 "max_payout reached -> winnings set to $bet_payout"
			}
		}
	}

	#
	# Account for Stake when getting bet_payout:
	# If the winnings (payout minus stake) are more than the max payout,
	# we pay out the max payout plus the stake!
	#
	if {$MAX_PAY_SORT == "BET_STAKE"} {
		if {[expr $bet_payout - [expr $BET(stake_per_line) * $num_lines_win]] > $BET(max_payout)} {
   			if {$BCONTROL(max_payout_parking) == "Y"} {
				log 1 "Max payout exceeded - parking bet for manual settlement"
				send_max_payout_notification $BET(acct_id) $BET(bet_id)
			} else {
				set bet_payout [expr $BET(max_payout) + [expr $BET(stake_per_line) * $num_lines_win]]
			}
		}
	}

	if {$BTYPE($bet_type,is_perm) == "Y"} {
		#now for the permed bets in order to reduce the number of
		#combinations we didn't consider perms of losers - hence
		#we have not been adding up all the losing legs
		log 3 "working out permed losers"
		set num_lines_lose\
			[expr {$BET(num_lines) - $num_lines_win - $num_lines_void}]
	}

	log 1 "bet winnings = $bet_payout"
	log 1 "    bet has  win lines = $num_lines_win"
	log 1 "    bet has lose lines = $num_lines_lose"
	log 1 "    bet has void lines = $num_lines_void"

	stl_settle_bet_do_db\
		$bet_id\
		$num_lines_win\
		$num_lines_lose\
		$num_lines_void\
		$bet_payout

	return SETTLED
}


#
# ----------------------------------------------------------------------------
# Determine whether a bet can be settled or not. This is an "aggressive"
# settler - it tries to determine, at the earliest possible point, when
# a bet can be settled. In many cases, this will be before all the selection
# results on which the bet depends have been posted.
#
# A bet can be settled when:
#
#    - It is known to be a loser - sufficient selections have lost for the
#      bet to be known to have lost. For example, if the bet is "trebles from
#      four", then there must be 3 winning selections for there to be any
#      payout. So, if two selections have lost, the bet must be a loser.
#      For multiples, this information is in the database (in tBetType).
#
#    - It is known to be a void (all legs must be void)
#
#    - All selection/market results are available for the bet.
#
# Selection results *must* be confirmed before they can be used to settle
# with - either by having the event-level or the selection-level confirmation
# flag set - this is to stop settlement occurring on results which may be
# being edited by an administrator. The selection information query
# (GET_SELN_INFO) handles this for us - any result which is not '-' will have
# been confirmed.
#
# This procedure carefully modifies the contents of the BET array to
# include some of the information which it has carefully worked out as
# part of the process of determining whether the bet is settleable:
#
#    - a status (W/L/V) for each leg (W => there is a non-zero return)
#    - the number of void lines for forecast/tricast legs
#    - the return for any leg which is a winner
#
# Clearly, putting the return information into BET is a waste of time if the
# bet isn't subsequently settled, but since we have all the information to
# hand here, we'll do it anyway... as was mentioned previously, this is tuned
# for clarity, not performance.
#
# This procedure will return one of:
#
#    - NO   : the bet cannot be settled
#    - LOSE : if the bet is a loser
#    - VOID : if the bet is void
#    - YES  : run the settlement calculations
# ----------------------------------------------------------------------------
#
proc stl_bet_can_be_settled {bet_id} {

	variable BET
	variable BTYPE
	variable SELN
	variable MKT


	set bet_type   $BET(bet_type)
	set num_legs   $BET(num_legs)
	set leg_type   $BET(leg_type)
	set banker_loser "N"

	# Bind BTYPE array for Resettlement check in the admin screens
	if {![info exist BTYPE($bet_type,max_losers)]} {
	    stl_get_bet_types
	}

	# for permed bets max losers can vary according to number
	# of selections
	if {$BTYPE($bet_type,is_perm) == "Y"} {
		set max_losers [expr {$BET(num_nocombi)
							  + $BET(num_combi)
							  - $BTYPE($bet_type,num_selns)}]
		log 3 "Permed bet type: $BET(num_nocombi),$BET(num_combi),$BTYPE($bet_type,num_selns)"
	} else {
		set max_losers $BTYPE($bet_type,max_losers)
		log 3 "Non Permed bet type: max losers $BTYPE($bet_type,max_losers)"
	}

	log 3 "complex settlement: determining if bet can be settled"
	log 3 "complex settlement: bet is $bet_type (legs=$num_legs)"\
			": max lose legs=$max_losers"


	#
	# Count how many winning selections (needed for bonus bets)
	#
	set BET(bonus,num_win_selns)  0
	set BET(bonus,num_lose_selns) 0
	set BET(bonus,num_void_selns) 0

	#
	# First pass: check how many legs are known to be losers - if we
	# exceed max_losers, we can finish with this bet now...
	#
	set num_losers 0
	set num_voids  0
	set settleable 1
	set BET(leg_losers) [list]

	#
	# Check all leg sorts for Any-to-come bets.
	# Too hard to settle complex leg types for ATC bets
	#
	if {[lsearch [stl_get_bet_names ATC] $bet_type] >= 0} {
		for {set leg 1} {$leg <= $num_legs} {incr leg} {
			if {$BET($leg,leg_sort) != "--"} {
				log 4 "leg $leg: cannot settle $BET($leg,leg_sort) leg sorts for $bet_type bets"
				return NO
			}
		}
	}

	for {set leg 1} {$leg <= $num_legs} {incr leg} {

		set leg_sort $BET($leg,leg_sort)
		set no_combi $BET($leg,no_combi)

		set ev_oc_id $BET($leg,1,ev_oc_id)
		stl_get_seln_info $ev_oc_id

		#check no more bet time rule.
		#whatever the sort of the leg and the results,
		#if the bet was struck after the late bet tolerance, the
		#leg will be voided. we need to make sure though that
		#BET array is updated correctly
		if {[OT_CfgGet ENABLE_LATE_BET_TOL_RULE 0 ]} {

			if {[stl_is_after_bet_time_void $bet_id $leg $ev_oc_id]} {

				if { [lsearch { "--" "WH" "MH" "HL" "hl" "AH" "A2" "OU" "SC" "CW"} $leg_sort ] != -1 } {
					set BET($leg,num_bets)   1
				} else {
					#force load info for Xcast leg
					set leg_info [stl_fcast_leg_info $leg_sort $BET($leg,num_parts)]

					foreach {num_bets max_leg_voids max_leg_losers poi} $leg_info {
						break
					}

					set BET($leg,num_bets) $num_bets
				}

				log 1 "Standard leg voided because of no more bet time rule"
				set BET($leg,leg_result) "V"
				incr num_voids
				if { $leg_sort == "CW" } {
					set BET($leg,leg_return) 1.0
				}
				continue
			}
		}




		if {$leg_sort == "--"} {

			#
			# This is a simple selection leg - check the result and
			# mark the leg as a lose if possible
			#
			set ev_oc_id $BET($leg,1,ev_oc_id)

			#
			# force load of selection info
			#
			stl_get_seln_info $ev_oc_id

			#
			# Get the selection result (W/P/L/V/-)
			#
			set part_result $SELN($ev_oc_id,result)
			set part_place  $SELN($ev_oc_id,place)

			set BET($leg,num_bets)   1
			set BET($leg,leg_result) $part_result


			if {$part_result == "L"} {
				log 4 "leg $leg: loses"
				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}
				continue
			}
			if {$part_result == "-"} {
				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue
			}
			if {$part_result == "V"} {
				log 4 "leg $leg: leg is void"
				incr num_voids
				continue
			}

			set rtn_w 0.0
			set rtn_p 0.0

			if {$leg_type == "W" || $leg_type == "E"} {
				set rtn_w [stl_simple_leg_return $bet_id $leg W]
				if {$rtn_w > 0.0} {
					set BET($leg,leg_return,W) $rtn_w
					log 4 "leg $leg: (to win) return=$rtn_w"
					incr BET(bonus,num_win_selns) 1
				} else {
					set BET($leg,leg_return,W) 0.0
					log 9 "leg $leg: (to win) leg loses"
				}
			}
			if {$leg_type == "P" || $leg_type == "E"} {
				set rtn_p [stl_simple_leg_return $bet_id $leg P]
				if {$rtn_p > 0.0} {
					set BET($leg,leg_return,P) $rtn_p
					log 4 "leg $leg: (to place) return=$rtn_p"
				} else {
					set BET($leg,leg_return,P) 0.0
					log 9 "leg $leg: (to place) leg loses"
				}
			}

			if {$rtn_w+$rtn_p > 0.0} {
				set BET($leg,leg_result) W
			} else {
				set BET($leg,leg_result) L
				lappend BET(leg_losers) $leg
				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}
			}

		} elseif {$leg_sort == "WH" || $leg_sort == "MH"} {
			#MH is a western handicap bet where you can bet on the line
			#aswell as home or away

			set BET($leg,num_bets)   1


			#
			# this is an western handicap leg
			#
			set rtn [stl_WH_leg_return $bet_id $leg $leg_sort]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L

				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (Straight Hcap) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}

		} elseif {$leg_sort == "HL"} {

			set BET($leg,num_bets)   1


			#
			# this is an western handicap leg
			#
			set rtn [stl_HL_leg_return $bet_id $leg]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L

				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (Hi/Lo) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}

		} elseif {$leg_sort == "hl"} {

			set BET($leg,num_bets)   1


			#
			# this is an western handicap leg
			#
			set rtn [stl_hl_leg_return $bet_id $leg]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L

				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (Hi/Lo) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}
		} elseif {$leg_sort == "AH"} {
			## asian handicap

			set BET($leg,num_bets)   1


			#
			# this is an asian handicap leg
			#
			set rtn [stl_AH_leg_return $bet_id $leg]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L

				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (AH) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}

		} elseif {$leg_sort == "A2"} {
			## asian handicap (halftime score)

			set BET($leg,num_bets)   1

			set rtn [stl_AH_leg_return $bet_id $leg]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (A2) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}
		} elseif {$leg_sort == "OU"} {

			set BET($leg,num_bets)   1

			set rtn [stl_OU_leg_return $bet_id $leg]

			if {$rtn == "-"} {

				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue

			} elseif {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (Over/Under) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}

		} elseif {$leg_sort == "SC"} {

			set BET($leg,num_bets) 1


			#
			# this is a scorecast leg - if either of the results from
			# the correct score/first scorer parts is 'L' then
			#
			set ev_oc_id_1 $BET($leg,1,ev_oc_id)
			set ev_oc_id_2 $BET($leg,2,ev_oc_id)

			stl_get_seln_info $ev_oc_id_1
			stl_get_seln_info $ev_oc_id_2



			#
			# this is a scorecast leg - it loses if either of the selection's
			# results is 'L' (P is not a valid result for either of the
			# selections which make a scorecast)
			#
			set res_1 $SELN($ev_oc_id_1,result)
			set res_2 $SELN($ev_oc_id_2,result)

			log 4 "leg $leg: (SC) result 1=$res_1, result 2=$res_2"

			if {$res_1 == "-" || $res_2 == "-"} {
				log 4 "leg $leg: mark bet as non-settleable"
				set settleable 0
				continue
			}

# Support # 35750 - 'Place' in First Goalscorer is 'Lose' in Scorecast
# 			if {$res_1 == "P" || $res_2 == "P"} {
# 				error "Have 'P' result for SC selection (bet #$bet_id)"
# 			}

			set rtn [stl_scast_leg_return $bet_id $leg]

			if {$rtn == "VOID"} {

				set BET($leg,leg_result) V
				log 4 "leg $leg: mark leg as void"
				incr num_voids

			} elseif {$rtn == 0.0} {

				set BET($leg,leg_result) L

				if {$BET($leg,banker) == "Y"} {
					log 4 "leg $leg: A losing banker - bet loses"
					set banker_loser "Y"
					break
				}
				lappend BET(leg_losers) $leg

				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}

			} else {

				log 4 "leg $leg: (scorecast) return=$rtn"
				set BET($leg,leg_return) $rtn
				set BET($leg,leg_result) W

			}

		} elseif {$leg_sort == "CW"} {
			#
			# this is a betting in running bet where the result will
			# depend on the goal that somebody bet on as well as the
			# ev_oc_id
			#

			set BET($leg,num_bets) 1

			stl_CW_leg_return $bet_id $leg
		} else {
			#
			# remaining leg sorts are all forecast/tricast types. We check to
			# see that a result is available for every selection mentioned.
			# For each of these legs, there will be 2+ horses/dogs (runners).
			# We *must* have at least one of the runners marked as being in
			# first place, or the leg loses (however, this isn't sufficient
			# to make the leg a winner - see below)
			#
			set n_lose_parts  0
			set n_void_parts  0
			set n_place_parts 0
			set n_win_parts   0
			set n_no_result   0

			set leg_info [stl_fcast_leg_info $leg_sort $BET($leg,num_parts)]

			foreach {num_bets max_leg_voids max_leg_losers poi} $leg_info {
				break
			}

			set BET($leg,num_bets) $num_bets


			log 4 "leg $leg: forecast/tricast statistics ($leg_sort)"
			log 4 "leg $leg:     num bets   = $num_bets"
			log 4 "leg $leg:     max voids  = $max_leg_voids"
			log 4 "leg $leg:     max losers = $max_leg_losers"
			log 4 "leg $leg:     places     = $poi"
			log 4 "leg $leg:     selections = $BET($leg,num_parts)"

			#
			# check all selections have a result
			#
			for {set part 1} {$part <= $BET($leg,num_parts)} {incr part} {

				set ev_oc_id $BET($leg,$part,ev_oc_id)

				#
				# force loading of the selection's details
				#
				stl_get_seln_info $ev_oc_id

				#
				# force loading of the market information for the
				# selections in this leg (just do it once, since all the
				# selections are in the same market)
				#
				if {$part == 1} {
					stl_get_mkt_info $SELN($ev_oc_id,ev_mkt_id)
				}

				#
				# given the result and the place, comput a "net result"
				# (one of -,L,V,place no) for this selection
				#
				set result $SELN($ev_oc_id,result)
				set place  $SELN($ev_oc_id,place)

				set net_result [stl_fcast_part_result $result $place $poi]

				if {$net_result == "-"} {
					incr n_no_result
				} elseif {$net_result == "L"} {
					incr n_lose_parts
				} elseif {$net_result == "V"} {
					incr n_void_parts
				} else {
					if {$net_result == 1} {
						incr n_win_parts
					} else {
						incr n_place_parts
					}
				}
			}

			log 5 "leg $leg: selection statistics:"
			log 5 "leg $leg:     no result = $n_no_result"
			log 5 "leg $leg:     lose      = $n_lose_parts"
			log 5 "leg $leg:     void      = $n_void_parts"
			log 5 "leg $leg:     win       = $n_win_parts"
			log 5 "leg $leg:     place     = $n_place_parts"

			#
			# If the bet cannot be settled now, move to the next leg
			# (the next leg might make it a loser if max_leg_losers is hit, so
			# it's worth carrying on)
			#
			if {$n_no_result > 0} {
				set settleable 0
				log 4 "leg $leg: mark bet as non-settleable"
				continue
			}

			#
			# if the leg is a loser, then if this makes the whole bet a
			# loser, move on, otherwise continue to the next leg
			#
			if {$n_win_parts == 0 && $n_void_parts == 0} {
				log 4 "leg $leg: no winning/void selections (leg loses)"
				set BET($leg,leg_result) L
				if {$no_combi == "" && ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose lines"
					break
				}
				continue
			}

			#
			# If the leg is void, move on to the next leg - note that the
			# test is "all parts void" - this is because there are different
			# bookmaker rules about what constitutes a void *-cast
			#
			if {$n_void_parts == $BET($leg,num_parts)} {
				log 4 "leg $leg: more than $max_leg_voids void => leg void"
				set BET($leg,leg_result) V
				incr num_voids
				continue
			}

			#
			# Time to take stock:
			#
			# At this point we know several things about the leg:
			#      1) All selections have a result
			#      2) Not all selections are losers
			#      3) Not all selections are void
			#
			# However, the leg might still be a void or a lose leg - we
			# need to evaluate all the forecast/tricast combinations
			# to see exactly what's what.
			#
			# So, now get all the selection perms which are needed to settle
			# this leg (this is just the same as the perm calculation for
			# settling standard multiples, except that RF,CF and CT are full
			# order-dependent combinations (we need to take each perm and
			# then pull out all the possible permutations: the two-way perms
			# from {1 2 3} are {1 2} {1 3} amd {2 3}, but the combination
			# forecasts from {1 2 3} are {1 2} {2 1} {1 3} {3 1} {2 3} {3 2}.
			#
			set combis [stl_fcast_combis $leg_sort $BET($leg,num_parts)]

			set BET($leg,combis) $combis

			#
			# sanity check (because this code is making me insane)
			#
			if {[llength $combis] != $num_bets} {
				error "num combis different from num bets"
			}

			#
			# call one of two functions to calculate line return
			#
			if {$leg_sort == "SF" || $leg_sort == "RF" || $leg_sort == "CF"} {
				set func stl_fcast_leg_return
			} else {
				set func stl_tcast_leg_return
			}

			#
			# loop over each line, get the return. The possible responses are
			# NO_DIVS, V or a return (which may be 0 - a lose line)
			#
			set leg_losers 0
			set leg_voids  0
			set leg_wins   0
			set leg_return 0.0

			set comb_num 0

			foreach c $combis {

				incr comb_num

				#
				# convert list of part nos ($c) to a list of selections...
				#
				set s [list]

				foreach p $c {
					lappend s $BET($leg,$p,ev_oc_id)
				}

				#
				# ...and get the return (yuk)
				#
				set rtn [eval $func $s]

				log 7 "leg $leg (combi $c): return is $rtn"

				set BET($leg,combi,$comb_num) $rtn

				if {$rtn == "NO_DIVS" } {
					# We don't have dividends information for this leg - do not settle the bet
					log 4 "leg $leg: mark bet as non-settleable - NO_DIVS"
					return NO
				}

				if {$rtn == "V"} {
					incr leg_voids
				} elseif {$rtn == 0} {
					incr leg_losers
				} else {
					set leg_return [expr {double($leg_return)+$rtn}]
					incr leg_wins
				}
			}

			if {$leg_voids == $num_bets} {
				set BET($leg,leg_result) V
				log 4 "leg $leg: all combis are void => mark leg as void"
				incr num_voids
				continue
			}

			if {$leg_return == 0 && $leg_voids == 0} {
				set BET($leg,leg_result) L
				log 4 "leg $leg: net return is 0, no voids => leg loses"
				if {$no_combi == "" &&  ([incr num_losers] > $max_losers)} {
					log 4 "leg $leg: more than $max_losers lose legs"
					break
				}
				continue
			}

			#
			# Mark leg as W - even if it is just void parts
			#
			set BET($leg,leg_result) W

			#
			# Set these as well - might as well save the bother of
			# recalculation - they can be used by other settlement routines
			#
			set BET($leg,leg_wins)   $leg_wins
			set BET($leg,leg_voids)  $leg_voids
			set BET($leg,leg_losers) $leg_losers
			set BET($leg,leg_return) $leg_return

			log 4 "leg $leg: combination statistics"
			log 4 "leg $leg:     wins = $leg_wins"
			log 4 "leg $leg:     void = $leg_voids"
			log 4 "leg $leg:     lose = $leg_losers"
		}
	}

	set BET(bonus,num_lose_selns) $num_losers
	set BET(bonus,num_void_selns) $num_voids

	#
	# Determine the outcome of these tests - each check must be carried out
	# in the order listed below
	#    1) too many losers    => LOSE
	#    2) settleable = false => NO
	#    3) all legs void      => VOID
	# otherwise needs to be settled with complex settlement
	#
	if {$banker_loser == "Y" || $num_losers > $max_losers} {
		return LOSE
	}

	if {!$settleable} {
		return NO
	}

	if {$num_voids == $num_legs} {
		return VOID
	}

	return YES
}


#
# --------------------------------------------------------------------------
# Calculate return for a forecast. The caller must make sure that the
# appropriate SELN elements are defined.
#
# The parameters are:
#    - selection 1
#    - selection 2
#
# If either seleciton is void, the return is "V". NB this rule might need
# to be changed for BetDirect who seem to want to settle a forecast
# as a win single when one selection is void
#
# If either selection is a loser, the return is 0
#
# If a dividend exists, return it, otherwise 0
#
# Note (and do not alter) the order in which these tests are made.
#
# I believe this is an appropriate place to tinker with any rules about
# forecast bonuses or non-runner settlement (paddy power/bet direct)
# --------------------------------------------------------------------------
#
proc stl_fcast_leg_return {s1 s2} {

	variable MKT
	variable SELN
	variable STL_FCAST_VOID
	variable FC_DIV_FACTOR

	set p1 [stl_fcast_part_result $SELN($s1,result) $SELN($s1,place) 2]
	set p2 [stl_fcast_part_result $SELN($s2,result) $SELN($s2,place) 2]

	#
	# If either result is '-' the result is '-'
	#
	if {$p1 == "-" || $p2 == "-"} {
		return -
	}

	#
	# If both selections are void, the forecast is void...
	#
	if {$p1 == "V" && $p2 == "V"} {
		return V
	}

	#
	# Extreme ugliness here... this is one of the points where the
	# rules for different bookmakers diverge:
	#
	# If one selection in a forecast is void,
	#    Ladbrokes  settle as a void forecast
	#    Bet Direct settle as a (tax on winnings) SP win single
	#
	if {$p1 == "V" || $p2 == "V"} {

		if {$STL_FCAST_VOID == "VOID"} {

			return V

		} elseif {$STL_FCAST_VOID == "SP_SGL"} {

			set s NONE

			if {$p1 == "V" && $p2 == "1"} {
				set s $s2
			} elseif {$p1 == "1" && $p2 == "V"} {
				set s $s1
			} else {
				return 0.0
			}

			if {$s != "NONE"} {

				log 4 "settling forecast line with 1 void as SP win single"

				set sp_num $SELN($s,sp_num)
				set sp_den $SELN($s,sp_den)

				# check for a win reduction
				set dh [stl_get_deadheat "W" $s]

				set dh_num [lindex $dh 0]
				set dh_den [lindex $dh 1]

				#
				# Get the straight SP return to unit stake
				#
				set sp_rtn [stl_simple_return\
					$sp_num $sp_den $dh_num $dh_den 1 1 0.0]

				return $sp_rtn
			}

		} else {

			return V

		}
	}

	#
	# both must be placed somehow - just get the dividend due. If the
	# placing are 2, 3 then there will be no foreacast dividend for these
	# selections, so this code "does the right thing".
	#
	set div [stl_get_dividend $SELN($s1,ev_mkt_id) FC $s1 $s2]

	if { $div == "NO_DIVS" } {
		return NO_DIVS
	}

	return [expr {$div*$FC_DIV_FACTOR}]
}


#
# --------------------------------------------------------------------------
# Calculate return for a tricast. The caller must make sure that the
# appropriate SELN elements are defined.
#
# The parameters are:
#    - selection 1
#    - selection 2
#    - selection 3
#
# If either selection is a loser, the return is 0
#
# If a single selection is void, the return is the forecast return for the
# remaining two selections (which may be void, if another selection is void).
# If a dividend exists, return it, otherwise 0
#
# I believe this is an appropriate place to tinker with any rules about
# tricast bonuses or non-runner settlement (paddy power/bet direct)
# --------------------------------------------------------------------------
#
proc stl_tcast_leg_return {s1 s2 s3} {

	variable SELN
	variable TC_DIV_FACTOR
	variable STL_TCAST_VOID

	set p1 [stl_fcast_part_result $SELN($s1,result) $SELN($s1,place) 3]
	set p2 [stl_fcast_part_result $SELN($s2,result) $SELN($s2,place) 3]
	set p3 [stl_fcast_part_result $SELN($s3,result) $SELN($s3,place) 3]

	#
	# non-runners need careful treatment - if there are 2 or more, the
	# tricast is void, otherwise it is settled as a forecast on the two
	# remaining runners
	#
	if {$p1 == "V" || $p2 == "V" || $p3 == "V"} {
		set nv 0
		if {$p1 == "V"} { incr nv }
		if {$p2 == "V"} { incr nv }
		if {$p3 == "V"} { incr nv }

		#
		# Allow two voids - this covers all the current settlement
		# scenarios
		#
		if {$nv >= 2} {
			if {$STL_TCAST_VOID == "VOID"} {
				return V
			} elseif {$STL_TCAST_VOID == "SP_SGL"} {
				if {$nv == 2} {
					# Tote want a tricast with 2 voided selections to be settled at SP SGL
					set s NONE

					if {$p1 == "1"} {
						set s $s1
					} elseif {$p2 == "1"} {
						set s $s2
					} elseif {$p3 == "1"} {
						set s $s3
					} else {
						return 0.0
					}

					if {$s != "NONE"} {

						log 4 "settling tricast line with 2 voids as SP win single"

						set sp_num $SELN($s,sp_num)
						set sp_den $SELN($s,sp_den)

						# check for a win reduction
						set dh [stl_get_deadheat "W" $s]

						set dh_num [lindex $dh 0]
						set dh_den [lindex $dh 1]

						#
						# Get the straight SP return to unit stake
						#
						set sp_rtn [stl_simple_return\
							$sp_num $sp_den $dh_num $dh_den 1 1 0.0]

						return $sp_rtn

					}

				} else {
					return V
				}
			}
		}
		if {$p1 == "V"} {
			return [stl_fcast_leg_return $s2 $s3]
		} elseif {$p2 == "V"} {
			return [stl_fcast_leg_return $s1 $s3]
		} else {
			return [stl_fcast_leg_return $s1 $s2]
		}
	}

	#
	# All 3 must be placed somehow - just get the dividend due. If the
	# placing are 2, 3, 4 then there will be no tricast dividend for these
	# selections, so this code "does the right thing".
	#
	set div [stl_get_dividend $SELN($s1,ev_mkt_id) TC $s1 $s2 $s3]

	if { $div == "NO_DIVS" } {
		return NO_DIVS
	}

	#
	# Dividend may need to be rounded up before using for settlement (WH)
	#
	if {[OT_CfgGet FUNC_ROUND_TC_UP 0]} {
		set intval [expr int($div)]
		if {$intval < $div} {
			set div [expr $intval + 1].00
		}
	}

	return [expr {$div*$TC_DIV_FACTOR}]
}


#
# --------------------------------------------------------------------------
# Return a list of all the permutations of leg lines for a particular
# SF/RF/CF/TC/CT leg
#
# Input is the leg type and the numer of parts to the leg (this isn't
# checked for validity)
#
# Return is a list of all the combinations of par numbers which need to
# be examined to settle the leg
# --------------------------------------------------------------------------
#
proc stl_fcast_combis {leg_type num_parts} {

	switch -- $leg_type {
		SF {
			return [list [list 1 2]]
		}
		RF {
			return [list [list 1 2] [list 2 1]]
		}
		CF {
			#
			# get all the perms for this number of selections, then turn them
			# into combis - this is not quick...
			#
			set perms [BETPERM::BMperm 2 $num_parts]
			foreach p $perms {
				foreach {a b} $p {
					lappend combis [list $a $b]
					lappend combis [list $b $a]
				}
			}
			return $combis
		}
		TC {
			return [list [list 1 2 3]]
		}
		CT {
			#
			# get all the perms for this number of selections, then turn them
			# into combis - this is not quick...
			#
			set perms [BETPERM::BMperm 3 $num_parts]
			foreach p $perms {
				foreach {a b c} $p {
					lappend combis [list $a $b $c]
					lappend combis [list $a $c $b]
					lappend combis [list $b $a $c]
					lappend combis [list $b $c $a]
					lappend combis [list $c $a $b]
					lappend combis [list $c $b $a]
				}
			}
			return $combis
		}
		default {
			error "unexpected leg type ($leg_type)"
		}
	}
}


#
# --------------------------------------------------------------------------
# Settle an asian handicap bet
# --------------------------------------------------------------------------
#
proc stl_settle_bet_AH bet_id {

	global USERNAME
	global SELN_RESETTLE
	variable STL_LOG_ONLY
	variable BET
	variable SELN
	variable MKT
	variable BCONTROL
	variable SELN_CHECK

	variable CHANNELS_TO_ENABLE_PARKING
	variable PARK_ON_WINNINGS_ONLY

	if {$BET(1,num_parts) != 1} {
		error "expected 1 part for AH leg"
	}

	set ev_oc_id $BET(1,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for an
	# AH selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {

		return NO

	} elseif {$result == "V"} {

		#
		# Void the whole bet - this is different from a refund if the
		# result (with the handicap) is a draw - it is a full refund because
		# (presumably) the match was abandoned
		#
		stl_bet_void $bet_id

		return SETTLED

	} elseif {$result != "H"} {
		error "unexpected result ($result) for OU selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	set num_lines_win   0
	set num_lines_lose  0
	set num_lines_void  0

	#
	# Get bet handicap value and market handicap makeup value
	#
	set hcap_value  $BET(1,1,hcap_value)
	set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)

	set fb_result $SELN($ev_oc_id,fb_result)

	if {$fb_result == "H"} {
		# do nothing
		log 3 "(H side) market makeup = $hcap_makeup"
	} elseif {$fb_result == "A"} {
		log 3 "selection fb_result is A : invert hcap and makeup"
		set hcap_value  [expr {0.0-$hcap_value}]
		set hcap_makeup [expr {0.0-$hcap_makeup}]
		log 3 "(A side) market makeup = $hcap_makeup (inverted)"
	} else {
		error "unexpected fb_result ($fb_result) for AH selection #$ev_oc_id"
	}

	if {$BET(num_lines) == 1} {

		set hcap_goals [expr {$hcap_value/4.0}]

		log 3 "single offer @ $hcap_goals goals"

		if {($hcap_makeup+$hcap_goals) == 0.0} {
			incr num_lines_void
			log 7 "makeup+handicap = 0 --> line void"
		} elseif {($hcap_makeup+$hcap_goals) > 0.0} {
			incr num_lines_win
			log 7 "makeup+handicap > 0 --> line wins"
		} else {
			incr num_lines_lose
			log 7 "makeup+handicap < 0 --> line loses"
		}

	} else {

		if {$hcap_value > 0.0} {
			set hcap_goals [expr {($hcap_value-1.0)/4.0}]
		} else {
			set hcap_goals [expr {($hcap_value+1.0)/4.0}]
		}

		log 3 " twin offer part 1 @ $hcap_goals goals"

		if {($hcap_makeup+$hcap_goals) == 0.0} {
			incr num_lines_void
			log 7 "makeup+handicap = 0 --> line void"
		} elseif {($hcap_makeup+$hcap_goals) > 0.0} {
			incr num_lines_win
			log 7 "makeup+handicap > 0 --> line wins"
		} else {
			incr num_lines_lose
			log 7 "makeup+handicap < 0 --> line loses"
		}

		if {$hcap_value > 0.0} {
			set hcap_goals [expr {$hcap_goals+0.5}]
		} else {
			set hcap_goals [expr {$hcap_goals-0.5}]
		}

		log 3 " twin offer part 2 @ $hcap_goals goals"

		if {($hcap_makeup+$hcap_goals) == 0.0} {
			incr num_lines_void
			log 7 "makeup+handicap = 0 --> line void"
		} elseif {($hcap_makeup+$hcap_goals) > 0.0} {
			incr num_lines_win
			log 7 "makeup+handicap > 0 --> line wins"
		} else {
			incr num_lines_lose
			log 7 "makeup+handicap < 0 --> line loses"
		}
	}

	set winnings  0.0
	set refund    0.0
	set spl       $BET(stake_per_line)

	if {$num_lines_win > 0} {
		set o_num $BET(1,1,o_num)
		set o_den $BET(1,1,o_den)
		set rtn [expr {double($o_num+$o_den)/double($o_den)}]
		set winnings [expr {$rtn*$spl*$num_lines_win}]
	}

	if {$num_lines_void > 0} {
		set refund [expr {$spl*$num_lines_void}]

		set nick $MKT($ev_mkt_id,hcap_steal)

		set refund [expr {((100.0-$nick)/100.0)*$refund}]
	}

	log 1 "winnings: [format %.2f [expr floor(round($winnings * 100))/100]]"
	log 1 "refund  : [format %.2f [expr floor(round($refund * 100))/100]]"

	if {$STL_LOG_ONLY} {
		# Round winnings & refunds
		set winnings [format %.2f [expr floor(round($winnings * 100))/100]]
		set refund   [format %.2f [expr floor(round($refund * 100))/100]]

	    log 1 "Old returns : $BET(winnings)"
	    log 1 "Old refund : $BET(refund)"

		#if the bet has been previously settled
		#this will show the discrepancy with the
		#new result
		if {$winnings != [format %.2f $BET(winnings)] ||
			$refund != [format %.2f $BET(refund)]} {

	                set winnings_dif \
				[expr {$winnings - [format %.2f $BET(winnings)]}]
	                set refund_dif   \
				[expr {$refund - [format %.2f $BET(refund)]}]

			set res [subst {Resettling outcome ${SELN_CHECK},$BET(bet_id),\
				$BET(acct_id),\
				$BET(num_lines_win),\
				$BET(num_lines_lose),\
				$BET(num_lines_void),\
				$BET(winnings),\
				$BET(refund),\
				$num_lines_win,\
				$num_lines_lose,\
			        $num_lines_void,\
				$winnings,\
				$refund,\
				$winnings_dif,\
				$refund_dif,\
				[expr {$winnings_dif + $refund_dif}]}]

			set SELN_RESETTLE($BET(bet_id)) $res
		}
		log 1 "\$STL_LOG_ONLY set : not updating database"
		return SETTLED
	}

	#
	# call the stored procedure to settle the bet
	#
	set stmt [stl_qry_prepare BET_WIN_REFUND]

	# if the bet from a channel with parking enabled, make sure
	# that the correct parking enabled value is send to the query
	if {[lsearch -exact $CHANNELS_TO_ENABLE_PARKING $BET(source)]!=-1} {
	    set enable_parking "Y"
	} else {
	    set enable_parking "N"
	}

	# if this option is enabled the bet park limit is applied
	# to the winnings rather than the winnings + refund
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	# if we want to reclaim token value from winnings then pass this in
	if {[OT_CfgGet LOSE_FREEBET_TOKEN_VALUE "FALSE"]} {
	    set lose_token_value "Y"
	} else {
	    set lose_token_value "N"
	}

	OT_LogWrite 5 "bet source: $BET(source), parking enabled: $enable_parking, park on winnings: $park_limit_on_winnings, lose_token_value: $lose_token_value"

	# Set it to include the bet in the summary table if
	# the config is set, and it's a manual on-course bet
	# the other config is set and it's any manual bet
	set force_summarize "N"
	if {$BET(bet_type) == "MAN" &&
		([OT_CfgGet FUNC_SUMMARIZE_MANUAL_BETS N] == "Y" ||
		([OT_CfgGet FUNC_SUMMARIZE_ONCOURSE_BETS 0] == 1 && $BET(source) == "C"))} {
		set force_summarize "Y"
	}

	set res [inf_exec_stmt $stmt\
		$USERNAME\
		$bet_id\
		$num_lines_win\
		$num_lines_lose\
		$num_lines_void\
		$winnings\
		0.0\
		$refund\
		""\
		$enable_parking\
		$park_limit_on_winnings\
		$lose_token_value\
		$force_summarize]

	if {[catch {
		set stl_bet_pnd [db_get_coln $res 0]
		ob::log::write INFO {Settle bet pending : $stl_bet_pnd}
		if {[OT_CfgGet MONITOR 0] && $stl_bet_pnd == 1} {
			ADMIN::BET::send_parked_bet_ticker $bet_id $USERNAME $winnings $refund
		}
	} msg]} {
		ob::log::write ERR {Could not send parked bet ticker for bet #$bet_id : $msg}
	}

	return SETTLED
}


#
# --------------------------------------------------------------------------
# Settle 'Any to Come' lines in a bet. These need to be handled seperately.
#
# In an any-to-come bet (SSA, DSA etc), if a leg is a loss it does not necessary
# mean the entire line is a loss, ie lines cannot be treated as straight
# accumulators as with most multi-part bets.
#
# There are also special rules for each-way bets, which means that lines can
# no longer be handled as seperate Win and Place cases.
# --------------------------------------------------------------------------
#
proc stl_settle_bet_ATC {bet_id arry} {
	variable BET
	variable MAX_PAY_SORT
	variable BCONTROL

	# Make sure BCONTROL is up to date
	stl_get_control

	upvar 1 $arry ATC_Lines

	#
	# Make sure the data storage array is empty
	#
	catch {unset ATC_Lines}

	set ATC_Lines(num_lines_win) 0
	set ATC_Lines(num_lines_lose) 0
	set ATC_Lines(num_lines_void) 0
	set ATC_Lines(bet_payout) 0.0


	#
	# Need to calculate the following information:
	#   - return for the bet
	#   - number of win lines
	#   - number of lose lines
	#   - number of void lines
	#   - if any legs lose (affects the num of stake units paid back)
	#
	# The logic for counting the num_lines/win/void/lose is different than for
	# the usual straight accumulator line bets.  See below.
	#
	set num_lines_win  0
	set num_lines_lose 0
	set num_lines_void 0
	set bet_payout     0.0

	set exists_legs_lose 0

	#
	# Get the list of line combinations for the bet
	#
	# For ATC bets, the each line has 2 legs, and each bet has all
	# combinations for any 2 legs from all selections.
	#
	# For an each-way bet, the number of lines stored in the database is
	# twice the number of lines generated here, because each line
	# appears twice, once for the win part, once for the place
	#
	set line_perms [BETPERM::bet_lines $BET(bet_type)]

	switch -- $BET(leg_type) {
		W {
			set leg_types [list W]
		}
		P {
			set leg_types [list P]
		}
		E {
			set leg_types [list W P]
		}
		default {
			error "unexpected leg type $BET(leg_type)"
		}
	}

	#
	# Cost of line for Win is spl, but EW bets its 2*spl
	#
	set spl               $BET(stake_per_line)
	set stakes_per_leg    [llength $leg_types]
	set line_cost         [expr {$stakes_per_leg*$spl}]

	set line_no 0

	#
	# $line is a list of the legs which are used in this line...
	#
	foreach line $line_perms {

			incr line_no

			set line_type [BETPERM::bet_line_type $BET(bet_type) $line_no]

			#
			# Any-to-come takes the stake(s) for the next leg in a line
			# from the return of the previous leg, so set the initial line_return
			# equal to the stake(s).
			#
			set line_payout $line_cost

			#
			# req_leg_stake holds the value of the required stake to be applied to
			# each leg in the line (this will double each time for DSA bets).  For
			# each-way bets, the actual stake applied may be less than this (see below).
			#
			set req_leg_stake $line_cost

			if {$line_type == "S" || $line_type == "D"} {

				set leg_no 0
				set last_leg [llength $line]

				foreach leg $line {

						incr leg_no

						log 9 "line: $line_no, leg : $leg result = $BET($leg,leg_result)"

						if {$BET($leg,leg_sort) != "--"} {
							error "leg_sort $BET($leg,leg_sort) does not apply for ATC bet types"
						}

						#
						# The stake mulitiplier is the amount the winnings of the first
						# leg are to be multiplied by to calculate the stake for the next
						# 'Any-to-go' leg.
						#
						# Double for DSA lines, Single for SSA lines
						#
						if {$line_type == "D" && $leg_no > 1} {
							set stk_mult 2
						} else {
							set stk_mult 1
						}

						#
						# First up, determine if we have enough winnings from the last
						# leg to cover the stake for this leg.
						#

						set req_leg_stake [expr {$stk_mult*$req_leg_stake}]

						set unequal_leg_stakes 0

						if {$req_leg_stake > $line_payout} {

							#
							# The last leg has returned less that the required cost.
							# In this case we put all the winnings into this leg at a reduced stake.
							#
							# However this only applies if it is not an EW bet.  If it is, we must
							# put as much as possible towards the original stake onto the Win part
							# of the EW, and the rest, if any remains, onto the Place part.
							#
							if {$BET(leg_type) != "E"} {
								set leg_stake $line_payout
							} else {
								log 16 "unequal stakes on legs required"
								set unequal_leg_stakes 1
								set req_part_stake [expr {$req_leg_stake / 2.0}]
								log 32 "req_part_stake is $req_part_stake"
								log 32 "line_payout is $line_payout"
								if {$req_part_stake < $line_payout} {
									set win_leg_stake $req_part_stake
									set plc_leg_stake [expr {$line_payout - $req_part_stake}]
								} else {
									set win_leg_stake $line_payout
									set plc_leg_stake 0.0
								}

								log 8 "win_leg_stake calculated at $win_leg_stake"
								log 8 "plc_leg_stake calculated at $plc_leg_stake"
							}
							set line_payout 0.0

						} else {

							#
							# Deduct the required stake from the cumulated return for the line.
							#

							set leg_stake $req_leg_stake

							set line_payout [expr {$line_payout - $leg_stake}]
						}

						#
						# Now handle each case for Lose, Void or Win.
						#
						if {$BET($leg,leg_result) == "L"} {

							#
							# This leg is a lose,
							#
							# If this is the first leg, the entire line is treated as a lose
							# and no further legs are evaluated.  If this is not the first leg
							# we retain the winnings from the previous legs and the line is
							# treated as a win.
							#
							if {$leg_no == 1 || $line_payout == 0.0} {
								foreach leg_type $leg_types {
									incr num_lines_lose
								}

								log 7 "  leg $leg result=L => line loses"

								set prev_leg_result "L"

							} else {
								foreach leg_type $leg_types {
									incr num_lines_win
								}
								log 7 "  leg $leg result=L,line payout=$line_payout =>  line wins"
							}

							set exists_legs_lose 1

							#
							# Line is lose, end of story - go on to next line...
							#
							break

						} elseif {$BET($leg,leg_result) == "V"} {

							#
							# This leg is void.
							#
							# If this is the first leg, we continue and put
							# the refunded stake into the next leg.
							#
							# If this is the second leg, we result of the
							# whole line depends on what the result for the
							# first leg was.
							#
							# - if the first leg was void, the whole line
							#   is void
							#
							# - if the first leg was a win with return > stake
							#   the line is a win
							#
							# - if the first leg was a win with return < stake
							#   the line is a void
							#

							if {$leg_no == $last_leg} {

								if {$prev_leg_result == "W" || $prev_leg_result == "U"} {

									log 7 "  leg $leg result=V"

									#
									# This won't be a void line, since the last selection
									# was a win, but we still need to refund the stake
									# from this void back into the line total.
									#
									if {$unequal_leg_stakes} {
										log 8 "calculating void returns with unequal leg stakes"
										set line_payout [expr {$line_payout + $win_leg_stake + $plc_leg_stake}]
									} else {
										set line_payout [expr {$line_payout + $leg_stake}]
									}

									foreach leg_type $leg_types {
										incr num_lines_win
									}
								} elseif {$prev_leg_result == "V"} {
									log 7 "  leg $leg result=V => line void"

									foreach leg_type $leg_types {
										incr num_lines_void
									}
								} else {
									error "previous leg result $prev_leg_result, should not be evaluating next leg"
								}

								#
								# Go on to next line...
								#
								break

							} else {
								log 7 "  leg $leg result=V"
								set prev_leg_result "V"

								#
								# Add the stake for this leg back into the line total
								# (this will be taken for the stake for the next leg)
								#
								if {$unequal_leg_stakes} {
									log 8 "calculating void returns with unequal leg stakes"
										set line_payout [expr {$line_payout + $win_leg_stake + $plc_leg_stake}]
								} else {
									set line_payout [expr {$line_payout + $leg_stake}]
								}

								#
								# Retain stake, go on to next leg...
								#
								continue
							}

						} elseif {$BET($leg,leg_result) == "W" ||
										$BET($leg,leg_result) == "U"} {

							foreach leg_type $leg_types {

								set rtn [stl_simple_leg_return $bet_id $leg $leg_type]

								log 7 "  leg $leg (standard) ($leg_type) return = $rtn"

								#
								# Stake will be halved for EW bets, if stakes are not unequal
								#
								if {$unequal_leg_stakes} {
									# This will only be set if it an EW bet
									log 8 "calculating return with unequal leg stakes"
									if {$leg_type == "W"} {
										log 32 "Win leg type, payout is $line_payout + ($rtn * $win_leg_stake)"
										set line_payout [expr {$line_payout + ($rtn*$win_leg_stake)}]
									} elseif {$leg_type == "P"} {
										log 32 "Place leg type, payout is $line_payout + ($rtn * $plc_leg_stake)"
										set line_payout [expr {$line_payout + ($rtn*$plc_leg_stake)}]
									} else {
										error "Unknown leg type $leg_type"
									}
								} else {
									set stk  [expr {$leg_stake / $stakes_per_leg}]
									set line_payout [expr {$line_payout + $rtn*$stk}]
								}

								#
								# If the last leg in the line is a winner, the whole line
								# will be considered a winner (since remaining payouts are always
								# kept for each leg).
								#
								if {$leg_no == $last_leg} {
									if {$rtn > 0.0} {
										incr num_lines_win
									} else {
										incr num_lines_lose
									}
									log 7 "  leg $leg result=W,line payout=$line_payout =>  line wins"
								}

							}

							#
							# Go onto next leg...
							#
							set prev_leg_result "W"

						} else {

							error "unexpected result $BET($leg,leg_result) in bet line"

						}

						# End leg loop
					}

					#
					# If MAX_PAY_SORT is LINE (rather than BET), we must clip
					# the line winnings to max_payout (SLOT)
					#
					if {$MAX_PAY_SORT == "LINE"} {
						if {$line_payout > $BET(max_payout)} {
							if {$BCONTROL(max_payout_parking) == "Y"} {
								log 1 "Max payout exceeded - parking bet for manual settlement"
								send_max_payout_notification $BET(acct_id) $BET(bet_id)
							} else {
								set line_payout $BET(max_payout)
							}
						}
					}

					if {$MAX_PAY_SORT == "LINE_STAKE"} {
						if {[expr $line_payout - $spl]> $BET(max_payout)} {
      							if {$BCONTROL(max_payout_parking) == "Y"} {
								log 1 "Max payout exceeded - parking bet for manual settlement"
								send_max_payout_notification $BET(acct_id) $BET(bet_id)
							} else {
								set line_payout [expr $BET(max_payout) + $spl]
							}
						}
					}

					#
					# Add the total for this line to the total return for the bet
					#

					set bet_payout [expr {$bet_payout+$line_payout}]

				} elseif {$line_type == "A"} {

					#
					# Straight Accumulator,
					# this should have been handled earlier so ignore..
					#

				} else {
					error "unexpected line_type $line_type for bet line"
				}

				# End line loop
			}

		#
		# Account for Stake when getting bet_payout:
		# If the winnings (payout minus stake) are more than the max payout,
		# we pay out the max payout plus the stake!
		#
		#
		# For ATC bets, the amount of stake added back can vary.
		# Basically, 0 stake is added if a leg loses, otherwise
		# spl * num_lines_win is added back!
		#
		if {$MAX_PAY_SORT == "BET_STAKE"} {
			if {$exists_legs_lose} {
				if {$bet_payout > $BET(max_payout)} {
     					if {$BCONTROL(max_payout_parking) == "Y"} {
						log 1 "Max payout exceeded - parking bet for manual settlement"
						send_max_payout_notification $BET(acct_id) $BET(bet_id)
					} else {
						set bet_payout $BET(max_payout)
					}
				}
			} else {
				if {[expr $bet_payout - [expr $spl * $num_lines_win]] > $BET(max_payout)} {
    					if {$BCONTROL(max_payout_parking) == "Y"} {
						log 1 "Max payout exceeded - parking bet for manual settlement"
						send_max_payout_notification $BET(acct_id) $BET(bet_id)
					} else {
						set bet_payout [expr $BET(max_payout) + [expr $spl * $num_lines_win]]
					}
				}
			}
		}

		#
		# Pass the data into the array for the calling function
		#
		set ATC_Lines(bet_payout) $bet_payout
		set ATC_Lines(num_lines_win) $num_lines_win
		set ATC_Lines(num_lines_lose) $num_lines_lose
		set ATC_Lines(num_lines_void) $num_lines_void

}

#
# --------------------------------------------------------------------------
# Calculate return for an straight hanidcap bet leg - this is a leg whose
# leg_sort is 'WH'.
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_WH_leg_return {bet_id leg_no {leg_sort "WH"}} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for over/under leg"
	}

	set ev_oc_id $BET($leg_no,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for a
	# straight handicap selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {
		return -
	} elseif {$result == "V"} {
		return VOID
	} elseif {$result != "H"} {
		error "unexpected result ($result) for WH selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	#
	# Extract relevant settlement data
	#
	set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)
	set hcap_value  $BET($leg_no,1,hcap_value)
	set p_num       $BET($leg_no,1,o_num)
	set p_den       $BET($leg_no,1,o_den)
	set fb_result   $SELN($ev_oc_id,fb_result)

	OT_LogWrite 3 "Handicap: makeup = $hcap_makeup (H-A)"
	OT_LogWrite 3 "Handicap: bet    = $fb_result side"

	#
	# Add the handicap value to the makeup. Remember: a positive value
	# means that the home team is given a head-start, a negative value means
	# that the away team is given the head-start
	#
	set hcap_makeup [expr {$hcap_makeup+$hcap_value}]

	OT_LogWrite 3 "Handicap: adjusted makeup = $hcap_makeup"

	if {[expr {abs($hcap_makeup)}] < 0.00001} {
		#this market has line betting available so falling
		#on the line loses unless fb_result = L
		if {$leg_sort == "MH"} {
			if {$fb_result == "L"} {
				# a bet bang on the line
				return [expr {($p_num+$p_den)/double($p_den)}]
			}
			return 0.0
		} else {
			set steal $MKT($ev_mkt_id,hcap_steal)
			return [expr {(100.0-$steal)/100.0}]
		}
	}

	switch -- $fb_result {
		H {
			if {$hcap_makeup > 0} {
				return [expr {($p_num+$p_den)/double($p_den)}]
			}
			return 0.0
		}
		A {
			if {$hcap_makeup < 0} {
				return [expr {($p_num+$p_den)/double($p_den)}]
			}
			return 0.0
		}
		# not on line so loses
		L {
			return 0.0
		}
		default {
			error "unexpected fb_result ($fb_result)"
		}
	}
}


#
# --------------------------------------------------------------------------
# Calculate return for an higher/lower bet leg - this is a leg whose
# leg_sort is 'HL'.
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_HL_leg_return {bet_id leg_no} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for over/under leg"
	}

	set ev_oc_id $BET($leg_no,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for a
	# straight handicap selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {
		return -
	} elseif {$result == "V"} {
		return VOID
	} elseif {$result != "H"} {
		error "unexpected result ($result) for HL selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed,, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	#
	# Extract relevant settlement data
	#
	set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)
	set hcap_value  $BET($leg_no,1,hcap_value)
	set p_num       $BET($leg_no,1,o_num)
	set p_den       $BET($leg_no,1,o_den)
	set fb_result   $SELN($ev_oc_id,fb_result)

	OT_LogWrite 3 "Handicap: makeup = $hcap_makeup (H-A)"
	OT_LogWrite 3 "Handicap: bet    = $fb_result side"

	#
	# Check for refund
	#
	if {[expr {abs($hcap_makeup-$hcap_value)}] < 0.00001} {
		set steal $MKT($ev_mkt_id,hcap_steal)
		return [expr {(100.0-$steal)/100.0}]
	}

	#
	# Check the higher/lower value
	#
	switch -- $fb_result {
		H {
			if {$hcap_value < $hcap_makeup} {
				return [expr {($p_num+$p_den)/double($p_den)}]
			}
			return 0.0
		}
		L {
			if {$hcap_value > $hcap_makeup} {
				return [expr {($p_num+$p_den)/double($p_den)}]
			}
			return 0.0
		}
		default {
			error "unexpected fb_result ($fb_result)"
		}
	}
}

#
# --------------------------------------------------------------------------
# Calculate return for an asian handicap bet leg - this is a leg whose
# leg_sort is 'AH' or 'A2'
#
# IMPORTANT: This function has been copied into the DBV (liab-main.tcl)
#            If you make any changes here, please make them there too
#                         - RH
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_AH_leg_return {bet_id leg_no} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for AH leg"
	}

	set ev_oc_id $BET($leg_no,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for a
	# straight handicap selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	#
	# There is only a limited range of selection results possible for a
	# straight handicap selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {
		return -
	} elseif {$result == "V"} {
		return VOID
	} elseif {$result != "H"} {
		error "unexpected result ($result) for AH selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed,, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	#
	# Extract relevant settlement data
	#
	set hcap_value  $BET($leg_no,1,hcap_value)
	set p_num       $BET($leg_no,1,o_num)
	set p_den       $BET($leg_no,1,o_den)
	set fb_result   $SELN($ev_oc_id,fb_result)

	OT_LogWrite 3 "Handicap: makeup = $MKT($ev_mkt_id,hcap_makeup) (H-A)"
	OT_LogWrite 3 "Handicap: bet    = $fb_result side"

	set hv [expr {int($hcap_value+($hcap_value>0.0 ? 0.1:-0.1))}]

	if {$hv % 2 == 0} {
		set hcaps [list [expr {$hcap_value/4.0}]]
	} else {
		set     hcaps [list [expr {($hcap_value-1.0)/4.0}]]
		lappend hcaps       [expr {($hcap_value+1.0)/4.0}]
	}

	set ret 0.0

	foreach hcap $hcaps {
		set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)

		if {$fb_result == "A"} {
			log 3 "selection fb_result is A : invert hcap and makeup"
			set hcap  [expr {0.0-$hcap}]
			set hcap_makeup [expr {0.0-$hcap_makeup}]
		}

		if {abs($hcap + $hcap_makeup) < 0.000001} {
			set steal $MKT($ev_mkt_id,hcap_steal)

			set ret [expr {$ret+((100.0-$steal)/100.0)}]

		} elseif {($hcap + $hcap_makeup) > 0.0} {
			set ret [expr {$ret+(double($p_num+$p_den)/$p_den)}]
		}
	}

	if {[llength $hcaps] == 2} {
		set ret [expr {$ret/2.0}]
	}

	return $ret
}

#
# --------------------------------------------------------------------------
# Calculate return for an higher/lower (split) bet leg - this is a leg whose
# leg_sort is 'hl'.
#
# IMPORTANT: This function has been copied into the DBV (liab-main.tcl)
#            If you make any changes here, please make them there too
#                         - RH
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_hl_leg_return {bet_id leg_no} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for over/under leg"
	}

	set ev_oc_id $BET($leg_no,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for a
	# straight handicap selection: -/V/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {
		return -
	} elseif {$result == "V"} {
		return VOID
	} elseif {$result != "H"} {
		error "unexpected result ($result) for HL selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed,, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	#
	# Extract relevant settlement data
	#
	set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)
	set hcap_value  $BET($leg_no,1,hcap_value)
	set p_num       $BET($leg_no,1,o_num)
	set p_den       $BET($leg_no,1,o_den)
	set fb_result   $SELN($ev_oc_id,fb_result)

	OT_LogWrite 3 "Handicap: makeup = $hcap_makeup (H-A)"
	OT_LogWrite 3 "Handicap: bet    = $fb_result side"

	set hv [expr {int($hcap_value+($hcap_value>0.0 ? 0.1:-0.1))}]

	if {$hv % 2 == 0} {
		set scores [list [expr {$hcap_value/4.0}]]
	} else {
		set     scores [list [expr {($hcap_value-1.0)/4.0}]]
		lappend scores       [expr {($hcap_value+1.0)/4.0}]
	}

	set ret 0.0

	foreach s $scores {
		if {abs($s-$hcap_makeup) < 0.000001} {
			set steal $MKT($ev_mkt_id,hcap_steal)
			set ret [expr {$ret+((100.0-$steal)/100.0)}]

		} else {
			switch -- $fb_result {
				H {
					if {$s < $hcap_makeup} {
						set ret [expr {$ret+(double($p_num+$p_den)/$p_den)}]
					}
				}
				L {
					if {$s > $hcap_makeup} {
						set ret [expr {$ret+(double($p_num+$p_den)/$p_den)}]
					}
				}
			}
		}
	}

	if {[llength $scores] == 2} {
		set ret [expr {$ret/2.0}]
	}

	return $ret
}


#
# --------------------------------------------------------------------------
# Calculate return for an over/under bet leg - this is a leg whose leg_sort
# is 'OU'.
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_OU_leg_return {bet_id leg_no} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for over/under leg"
	}

	set ev_oc_id $BET($leg_no,1,ev_oc_id)

	#
	# Force loading of selection information
	#
	stl_get_seln_info $ev_oc_id

	#
	# There is only a limited range of selection results possible for an
	# over/under selection: -/V/L/H
	#
	set result $SELN($ev_oc_id,result)

	if {$result == "-"} {
		return -
	} elseif {$result == "L"} {
		return 0.0
	} elseif {$result == "V"} {
		return VOID
	} elseif {$result != "H"} {
		error "unexpected result ($result) for OU selection"
	}

	#
	# Force loading of market info
	#
	set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

	stl_get_mkt_info $ev_mkt_id

	#
	# Cannot settle if market result isn't confirmed,, because we need
	# the handicap makeup value from the market
	#
	if {$MKT($ev_mkt_id,result_conf) != "Y"} {
		return "-"
	}

	#
	# result is "H" so we now need to compare the bet handicap with
	# the market handicap makeup to see what's going on...
	#
	set hcap_makeup $MKT($ev_mkt_id,hcap_makeup)
	set hcap_value  $BET($leg_no,1,hcap_value)
	set p_num       $BET($leg_no,1,o_num)
	set p_den       $BET($leg_no,1,o_den)

	set fb_result $SELN($ev_oc_id,fb_result)

	set p_ret [expr {($p_num+$p_den)/double($p_den)}]

	if {[string first $fb_result "OHA"] >= 0} {
		if {$hcap_makeup == $hcap_value} {
			set p_ret VOID
		}
		if {$hcap_makeup < $hcap_value} {
			set p_ret 0.0
		}
	} elseif {[string first $fb_result "Uha"] >= 0} {
		if {$hcap_makeup == $hcap_value} {
			set p_ret VOID
		}
		if {$hcap_makeup > $hcap_value} {
			set p_ret 0.0
		}
	} else {
		error "unexpected fb_result ($fb_result) for OU selection"
	}

	return $p_ret
}


#
# --------------------------------------------------------------------------
# Calculate return for a scorecast bet leg - this is a leg whose leg_sort
# is 'SC'. Caller must guarantee that SELN elements are defined for the
# selections in question, and that this is a wining scorecast (or be
# prepared to 'catch' the error
#
# The parameters are:
#    - bet id
#    - leg number
# --------------------------------------------------------------------------
#
proc stl_scast_leg_return {bet_id leg_no} {

	variable BET
	variable SELN
	variable MKT

	if {$BET($leg_no,num_parts) != 2} {
		error "expected 2 parts for scorecast leg"
	}

	set ev_oc_id_1 $BET($leg_no,1,ev_oc_id)
	set ev_oc_id_2 $BET($leg_no,2,ev_oc_id)

	#
	# Force loading of market info so we can get the tEvMkt.sort
	# value for each market
	#
	stl_get_mkt_info [set mkt_1 $SELN($ev_oc_id_1,ev_mkt_id)]
	stl_get_mkt_info [set mkt_2 $SELN($ev_oc_id_2,ev_mkt_id)]

	#
	# Find which market is FS and which is CS - there's no ordering
	# imposed on the two selections in tOBet
	#
	if {$MKT($mkt_1,sort) == "CS" && $MKT($mkt_2,sort) == "FS"} {
		set seln_cs $ev_oc_id_1
		set seln_fs $ev_oc_id_2
	} elseif {$MKT($mkt_1,sort) == "FS" && $MKT($mkt_2,sort) == "CS"} {
		set seln_cs $ev_oc_id_2
		set seln_fs $ev_oc_id_1
	} else {
		error "Couldn't find CS/FS markets (#$mkt_1,#$mkt_2)"
	}

	set mkt_fs $SELN($seln_fs,ev_mkt_id)
	set res_cs $SELN($seln_cs,result)
	set res_fs $SELN($seln_fs,result)

	set o_num ""
	set o_den ""

	#
	# A nasty special case exists where the first goal scored was an
	# own goal - in which case the first goalscorer is 'None' but
	# the correct score is not 0-0. Given you can't actually select
	# this combination as a scorecast - we treat the FS half of the
	# bet as void and settle as a CS single.
	#
	stl_get_mkt_sc_fs_info $mkt_fs

	if {$MKT($mkt_fs,sc_fs_none) == "W" &&
		$SELN($seln_cs,cs_home)+$SELN($seln_cs,cs_away) != 0} {

		log 4 "SC bet: #$bet_id: First goal was an own goal - settling with FS assumed VOID"
		set res_fs "V"
	}

	if {$res_cs == "L"} {

		return 0.0

	} elseif {$res_cs == "V"} {

		if {$res_fs == "W"} {

			#
			# Correct score selection is void (for some bizarre reason)
			# so let's settle this as a first-scorer bet at the
			# appropriate odds
			#
			set stmt [stl_qry_prepare GET_HIST_SELN_PRICE]
			set res  [inf_exec_stmt $stmt $seln_fs $BET(cr_date)]

			if {[db_get_nrows $res] == 1} {
				set o_num [db_get_col $res 0 p_num]
				set o_den [db_get_col $res 0 p_den]
			} else {
				error "Couldn't retrieve historical price for FS #$seln_fs on $BET(cr_date)"
			}

			db_close $res

		} elseif {$res_fs == "V"} {

			#
			# Definitely void
			#
			return VOID

		} elseif {$res_fs == "L" || $res_fs == "P" } {

			return 0.0

		} else {

			error "Unexpected FS selection result ($res_fs) seln #$seln_fs"

		}

	} elseif {$res_cs == "W"} {

		if {$res_fs == "W"} {

			#
			# Standard case - settlement price is stored with the bet
			#
			set o_num $BET($leg_no,1,o_num)
			set o_den $BET($leg_no,1,o_den)

		} elseif {$res_fs == "V"} {

			#
			# First scorer selection is void : settle as
			# a correct score single
			#
			set stmt [stl_qry_prepare GET_HIST_SELN_PRICE]
			set res  [inf_exec_stmt $stmt $seln_cs $BET(cr_date)]

			if {[db_get_nrows $res] == 1} {
				set o_num [db_get_col $res 0 p_num]
				set o_den [db_get_col $res 0 p_den]
			} else {
				error "Couldn't retrieve historical price for CS #$seln_cs on $BET(cr_date)"
			}

			db_close $res

		} elseif {$res_fs == "L" || $res_fs == "P"} {

			return 0.0

		} else {

			error "Unexpected FS selection result ($res_fs) seln #$seln_fs"

		}

	} else {

		error "Unexpected CS selection result ($res_cs) seln #$seln_cs"

	}

	if {$o_num == "" || $o_den == ""} {
		error "bad price for scorecast"
	}

	#
	# There are no dead-heat/rule 4 considerations for scorecast
	#
	return [expr {1.0+double($o_num)/double($o_den)}]
}


#--------------------------------------------------------------
# Settle a continuous win bet
#--------------------------------------------------------------

proc stl_CW_leg_return {bet_id leg_no} {

        variable BET
        variable SELN

        if {$BET($leg_no,num_parts) != 1} {
                error "expected 1 part for continuous win leg"
        }

        set BET($leg_no,leg_return) 0.0

        #bet info
        set ev_oc_id $BET($leg_no,1,ev_oc_id)
        set p_num    $BET($leg_no,1,o_num)
        set p_den    $BET($leg_no,1,o_den)

        set p_ret [expr {($p_num+$p_den)/double($p_den)}]

        #
        # Force loading of selection information
        #
        stl_get_seln_info $ev_oc_id

        set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)

        set stmt [stl_qry_prepare GET_BIR_SELN_INFO]
        set res  [inf_exec_stmt $stmt $ev_mkt_id $BET($leg_no,1,bir_index) $ev_oc_id]

        if {[db_get_nrows $res] == 0} {
                error "No results provided for this index"
        }

        if {[db_get_nrows $res] > 1} {
                error "Multiple results returned for this index"
        }

        set result [db_get_col $res 0 result]

        db_close $res

        if {$result == "W"} {
                set BET($leg_no,leg_return) $p_ret
                set BET($leg_no,leg_result) "W"
        } elseif {$result == "V"} {
                set BET($leg_no,leg_return) 1.0
                set BET($leg_no,leg_result) "V"
        } elseif {$result == "L"} {
                set BET($leg_no,leg_return) 0.0
                set BET($leg_no,leg_result) "L"
		} elseif {$result == "U"} {
				set BET($leg_no,leg_return) 1.0
                set BET($leg_no,leg_result) "U"
        } else {
                error "Unexpected leg result for CW leg sort: $result"
        }

        set BET($leg_no,num_bets)   1
}

#
# --------------------------------------------------------------------------
# Calculate return for a simple bet leg - this is a leg whose leg_sort
# is '--'. Caller must guarantee that SELN elements are defined for the
# selection in question, and that the result is one of Win or Place (or
# be prepared to 'catch' the error)
#
# The parameters are:
#    - bet id
#    - leg number
#    - return type (win or place)
#    - odds multiplier (for consolation bonuses)
# --------------------------------------------------------------------------
#
proc stl_simple_leg_return {bet_id leg_no type {multiplier 1}} {

	variable BET
	variable SELN
	variable MKT
	variable USE_RULE4
	variable DHEAT

	if {$BET($leg_no,num_parts) != 1} {
		error "expected 1 part for simple leg"
	}

	set ev_oc_id   $BET($leg_no,1,ev_oc_id)
	set result     $SELN($ev_oc_id,result)

	if {$result == "L"} {
		return 0.0
	}
	if {$result == "V"} {
		return VOID
	}

	# Push (return stake as winnings)
	if {$result == "U"} { return 1.0 }

	set ev_mkt_id  $SELN($ev_oc_id,ev_mkt_id)
	set price_type $BET($leg_no,1,price_type)

	#
	# If this is a P price (pari-mutuel) get a tote return from the
	# dividend info
	#
	if {$price_type == "P"} {
		if {$result == "W"} {
			set div_type TW
		} elseif {$result == "P"} {
			set div_type TP
		} else {
			error "unexpected result ($result) : expected W/P"
		}

		if {![info exists MKT($ev_mkt_id,DIV,$div_type,$ev_oc_id)]} {
			error "W/P result for P price, but no dividend"
		}

		#
		# XXX Do we need to worry about ew_places or ew_with_bet ? XXX
		#
		set div $MKT($ev_mkt_id,DIV,$div_type,$ev_oc_id)

		return $div
	}


	#
	# Get the rule 4 deduction (if any)
	# For GP (aka BOG) bets, we look up both the LP and SP rule 4s and will
	# later decide which to apply.
	#
	if {$USE_RULE4} {

		if {$price_type == "G"} {

			set lp_rule4 [stl_get_rule4 $ev_mkt_id $BET(cr_date) "L"]
			set sp_rule4 [stl_get_rule4 $ev_mkt_id $BET(cr_date) "S"]

		} else {

			set rule4 [stl_get_rule4 $ev_mkt_id $BET(cr_date) $price_type]

			if {$rule4 != 0.0} {
				log 1 "leg $leg_no: rule 4 deduction of $rule4 applies"
			}

		}

	} else {

		if {$price_type == "G"} {
			set lp_rule4 0.0
			set sp_rule4 0.0
		} else {
			set rule4 0.0
		}

	}

	#
	# Get the price to settle at
	#
	switch -- $price_type {
		L {
			set o_num $BET($leg_no,1,o_num)
			set o_den $BET($leg_no,1,o_den)
			log 1 "leg $leg_no: fixed-odds price is $o_num/$o_den"
		}
		S {
			set o_num $SELN($ev_oc_id,sp_num)
			set o_den $SELN($ev_oc_id,sp_den)
			log 1 "leg $leg_no: starting price is $o_num/$o_den"
		}
		1 -
		2 -
		N -
		B {
			set price [stl_get_seln_price\
				$ev_oc_id\
				$price_type\
				$BET(cr_date)]

			set o_num [lindex $price 0]
			set o_den [lindex $price 1]
			log 1 "leg $leg_no: $price_type price is $o_num/$o_den"
		}
		G {
			if {
				   ![info exists BET($leg_no,1,o_num)]
				|| ![info exists BET($leg_no,1,o_den)]
				|| $BET($leg_no,1,o_num) == ""
				|| $BET($leg_no,1,o_den) == ""
			} {
				error "Guaranteed price bet with no live price!"
			}

			if {
				   ![info exists SELN($ev_oc_id,sp_num)]
				|| ![info exists SELN($ev_oc_id,sp_den)]
				|| $SELN($ev_oc_id,sp_num) == ""
				|| $SELN($ev_oc_id,sp_den) == ""
			} {
				error "Guaranteed price bet with no starting price!"
			}

			set lp_num $BET($leg_no,1,o_num)
			set lp_den $BET($leg_no,1,o_den)
			set sp_num $SELN($ev_oc_id,sp_num)
			set sp_den $SELN($ev_oc_id,sp_den)

			# See whether the LP or SP will give us better returns after
			# taking the Rule 4s into account.

			if { [stl_simple_return $lp_num $lp_den 1 1 1 1 $lp_rule4] >
			     [stl_simple_return $sp_num $sp_den 1 1 1 1 $sp_rule4] } {
				set o_num $lp_num
				set o_den $lp_den
				set rule4 $lp_rule4
			} else {
				set o_num $sp_num
				set o_den $sp_den
				set rule4 $sp_rule4
			}

			if {$rule4 != 0.0} {
				log 1 "leg $leg_no: rule 4 deduction of $rule4 applies"
			}

		}
		default {
			error "unknown price type: $price_type"
		}
	}






	# make sure we have mkt info loaded
	stl_get_mkt_info $ev_mkt_id


	# TTE037 Code
	# (See Amendment Note At Top Of Page)
	# But Wait! If it's greyhounds and there is an sp_allbets_from - sp_allbets_to
	# window and this bet was placed within that period, we settle at SP.
	# In addition, if only sp_allbets_to is set, all bets placed before it are settled at SP
	#
	#  NOTE:  23/6/06  Fixed the broken ladbrooks version with Bruce's new code after being caught in QA.
	  if {
     	      [OT_CfgGet FUNC_DOGS_SETTLE_VOID_SP 0] &&
     	      (
       		$MKT($ev_mkt_id,sp_allbets_from) == "" ||
       		$BET(cr_date) >= $MKT($ev_mkt_id,sp_allbets_from)
     	      ) &&
	      (
     		$MKT($ev_mkt_id,sp_allbets_to) != "" &&
    	        $BET(cr_date) < $MKT($ev_mkt_id,sp_allbets_to)
	      )
	} {
		set o_num $SELN($ev_oc_id,sp_num)
		set o_den $SELN($ev_oc_id,sp_den)
		log 1 "leg $leg_no: greyhound race with void runner: settling with starting price of $o_num/$o_den instead"
	}


	if {$o_num == "" || $o_den == ""} {
		error "have a null price"
	}

	#
	# Now factor in the multiplier - this really is a "hack" to make
	# it possible to calculate "bonuses" for L15/L31/L63 bets where
	# the bonus is one leg settled at (e.g.) double odds - set multiplier
	# to 2 in this case
	#
	set o_num [expr {$o_num*$multiplier}]

	#
	# Get the win return if needed
	#  - note that the return is 0 unless the result is Win
	#
	if {$type == "W"} {
		if {$result == "W"} {

			foreach {dh_num dh_den} [stl_get_deadheat "W" $ev_oc_id] {}

			log 1 "leg $leg_no: win dead heat reduction of $dh_num/$dh_den"

			set rtn [stl_simple_return $o_num $o_den\
				$dh_num $dh_den 1 1 $rule4]

			return $rtn
		}

		return 0.0
	}

	#
	# Get the place return - note that we will always have a place return
	# since we know the result is either Win or Place (checked above)
	#
	if {$type == "P"} {
		#
		# Extract appropriate each-way terms
		#
		set ew_places $BET($leg_no,1,ew_places)
		set ew_num    $BET($leg_no,1,ew_fac_num)
		set ew_den    $BET($leg_no,1,ew_fac_den)

		# are the terms associated with the bet?
		set terms_with_bet 0

		if {$ew_places == "" || $ew_num == "" || $ew_den == ""} {
			log 1 "leg $leg_no: no valid EW terms with bet"

			set ew_places $MKT($ev_mkt_id,ew_places)
			set ew_num    $MKT($ev_mkt_id,ew_fac_num)
			set ew_den    $MKT($ev_mkt_id,ew_fac_den)

			if {$ew_places == "" || $ew_num == "" || $ew_den == ""} {
				log 1 "leg $leg_no: no valid EW terms from market either"

				if {$MKT($ev_mkt_id,ew_avail) != "Y" && $MKT($ev_mkt_id,pl_avail) != "Y"} {
					log 1 "leg $leg_no: market isn't even an EW market - settle place part as a win part"

					set ew_places 1
					set ew_num    1
					set ew_den    1

					log 1 "leg $leg_no: EW $ew_places @ $ew_num/$ew_den (win only)"
				} else {
					error "bad each-way terms"
				}
			} else {
				log 1 "leg $leg_no: EW $ew_places @ $ew_num/$ew_den (from market)"
			}
		} else {
			set terms_with_bet 1
			log 1 "leg $leg_no: EW $ew_places @ $ew_num/$ew_den (with bet)"
		}

		if {$SELN($ev_oc_id,place) > $ew_places} {
			return 0.0
		}

		if {$BET($leg_no,1,ew_fac_num)!="" && $BET($leg_no,1,ew_fac_den)!="" \
			 && $MKT($ev_mkt_id,ew_with_bet)=="Y"} {

			set ew_key "$ew_num,$ew_den,$ew_places"

			if {[catch {
				set ew_id $MKT($ev_mkt_id,EW,$ew_key)
			} msg]} {
				log 1 "each way terms do not exist in market. Using main place reductions"
				set ew_id 0
			}
		} else {
			set ew_id 0
		}

		foreach {dh_num dh_den} [stl_get_deadheat "P" $ev_oc_id $ew_id] {}

		log 1 "leg $leg_no: place dead heat reduction of $dh_num/$dh_den"

		set rtn [stl_simple_return $o_num $o_den\
			$dh_num $dh_den $ew_num $ew_den $rule4]

        log 1 "o_num=$o_num o_den=$o_den dh_num=$dh_num dh_den=$dh_den ew_num=$ew_num ew_den=$ew_den rule4=$rule4 rtn=$rtn"

		return $rtn
	}

	return 0.0
}
#
#--------------------------------------------------------------------------
# Calculate return for a LuckyX bet leg - this is a leg belonging to a
# Lucky X style bet. These bets have complex bonus/consolation rules and
# we can only calculate an individual lines' payout once we've established
# all the leg results. Caller must guarantee that SELN elements are defined
# for the selection in question, that the result is one of Win or Place and
# that the BET bet_type and leg_results are set (or be prepared to 'catch'
# the error)
#
# This function should be used per line, per leg to allow for odds-based
# consolations and is used by stl_lucky_return for per line returns-
# based bonuses.
#
# The parameters are:
#    - bet id
#    - leg number
#    - return type (win or place)
#
# stl_lucky_return passes:
#    - bet id
#    - "-" to indicate a line-based return
#    - return type (win or place)
#    - current line return
# --------------------------------------------------------------------------
#
proc stl_luckyx_leg_return {bet_id leg_no type {rtn 1.0}} {

	variable BET
	variable SELN
	variable MKT

	if {$leg_no != "-"} {
		# get original leg return
		set rtn [stl_simple_leg_return $bet_id $leg_no $type]
	}

	if {$rtn == 0.0} {
		# leg/line lost - bonuses are moot
		return $rtn
	}

	if {[lsearch [stl_get_bet_names LuckyX] $BET(bet_type)] == -1} {
		# not a LuckyX bet - no bonus
		return $rtn
	}

	if {$type == "P" && [OT_CfgGet STL_LUCKYX_PLACE_BONUS "N"] != "Y"} {
		# we're not paying bonuses on place parts
		return $rtn
	}

	if {$leg_no != "-"} {
		if {[lsearch [list W V U] $BET($leg_no,leg_result)] == -1} {
			# we don't pay bonuses on losing legs
			return $rtn
		}

		if {$BET($leg_no,leg_result) == "V" && [OT_CfgGet STL_LUCKYX_VOID_BONUS "N"] != "Y"} {
			# we're not paying bonuses on void legs either
			return $rtn
		}
	}

	# retrieve class sort restrictions
	array set ALLOWED_SORTS [OT_CfgGet STL_LUCKYX_BONUS_SORTS ""]

	# count wins and voids
	set num_win 0
	set num_void 0
	foreach key [array names BET *,leg_result] {
		if {[regexp {^(\d+),leg_result$} $key all l]} {

			if {[llength [array names ALLOWED_SORTS]] ||
				[OT_CfgGet STL_LUCKYX_DIFFERENT_ODDS_BONUS_HR_AND_GR 0]} {

				# we have class sort restrictions
				# retrieve selections class and market sorts
				set ev_oc_id $BET($l,1,ev_oc_id)
				# Support Fix: 46900
				if { ![info exists SELN($ev_oc_id,ev_mkt_id)] } {
					# force loading of selection information
				    stl_get_seln_info $ev_oc_id
				}
				set ev_mkt_id $SELN($ev_oc_id,ev_mkt_id)
				if {![info exists MKT($ev_mkt_id,class_sort)] || ![info exists MKT($ev_mkt_id,sort)]} {
					# force loading of market information
					stl_get_mkt_info $ev_mkt_id
				}
				set class_sort $MKT($ev_mkt_id,class_sort)
				set mkt_sort $MKT($ev_mkt_id,sort)
					if {[lsearch [array names ALLOWED_SORTS] $class_sort] == -1} {
						# we're not paying bonuses on bets with legs from invalid class sorts
						return $rtn
					} elseif {[llength $ALLOWED_SORTS($class_sort)]} {
						# this class sort has market sort restrictions

						if {[lsearch $ALLOWED_SORTS($class_sort) $mkt_sort] == -1} {
							# we're not paying bonuses on bets with legs from invalid market sorts either
							return $rtn
						}
					}
			}
			if {$BET($l,leg_result) == "W" || $BET($l,leg_result) == "U"} {
				if {[OT_CfgGet STL_LUCKYX_COUNT_PLACES "N"] == "Y"} {
					if {[stl_simple_leg_return $bet_id $l P] > 0.0} {
						incr num_win
					}
				} else {
					if {[stl_simple_leg_return $bet_id $l W] > 0.0} {
						incr num_win
					}
				}
			}
			if {$BET($l,leg_result) == "V"} {
				incr num_void
			}
		}
	}

	if {$num_void > 0 && [OT_CfgGet STL_LUCKYX_ALLOW_VOIDS "N"] != "Y"} {
		# we're not paying bonuses on bets that have -any- void legs
		return $rtn
	}

	if {[OT_CfgGet STL_LUCKYX_COUNT_VOIDS "N"] == "Y"} {
		# add void legs to winning legs for calculating bonus
		incr num_win $num_void
	}

	if {$leg_no == "-"} {

		# look for per-line returns bonuses
		if {[regexp {^(\d+(\.\d*)?|\.\d+)$} [OT_CfgGet STL_LUCKYX_$BET(bet_type)_${num_win}_RETURNS "N"] bonus]} {
			# found a returns bonus
			set rtn_new [expr {$rtn * $bonus}]
			log 2 "  line bonus (returns x $bonus) takes return from $rtn to $rtn_new"
			set rtn $rtn_new
		}

	} else {

		# look for per-leg odds-based bonuses
		if {[regexp {^(\d+(\.\d*)?|\.\d+)$} [OT_CfgGet STL_LUCKYX_$BET(bet_type)_${num_win}_ODDS "N"] bonus]} {
			# found an odds bonus
			set rtn_new [stl_simple_leg_return $bet_id $leg_no $type $bonus]
			log 2 "  leg $leg_no bonus (odds x $bonus) takes return from $rtn to $rtn_new"
			set rtn $rtn_new
		}
	}
	return $rtn
}


#
# --------------------------------------------------------------------------
# Calculate return for a LuckyX bet line - this is a wrapper for
# stl_luckyx_leg_return which takes the existing line return and multiplies
# it by whatever bonuses are relevant.
#
# See the comment for stl_luckyx_leg_return.
#
# The parameters are:
#    - bet id
#    - return type (win or place)
#    - line return
# --------------------------------------------------------------------------
#
proc stl_luckyx_return {bet_id type leg_return} {
	return [stl_luckyx_leg_return $bet_id - $type $leg_return]
}

#
# --------------------------------------------------------------------------
# Calculate a simple return based on
#    - a fractional price (p_num/p_den)      => p
#    - a dead-heat reduction (dh_num/dh_den) => dh
#    - each-way reduction (ew_num/ew_den)    => ew
#    - rule 4 deduction (pence in the pound) => r4
#
# The basic return to unit stake is then
#    rtn = dh + dh*p*ew*(1-r4/100)
#
# This is made up as follows:
#    1 dead-heat reduction applies to the stake
#    2 each-way reduction applies to the price
#    3 rule 4 deduction applies to winnings (not the stake)
#
# A normal return for a stake s is
#     rtn = s + s.p
#
# If each-way terms affect the price,
#     rtn = s + s.p.ew
#
# If dead heats are in play,
#     rtn = s.dh + s.p.ew.dh
#
# If a rule 4 deduction is applicable,
#     rtn = s.dh + s.p.ew.dh.(1-r4/100)
#
# Factoring out the stake to get a simple unit return for the selection,
#     rtn/unit = dh + p.ew.dh.(1-r4/100)
# --------------------------------------------------------------------------
#
proc stl_simple_return {p_num p_den dh_num dh_den ew_num ew_den r4} {

	if { $r4 < [OT_CfgGet STL_MIN_R4 0] } {
		log 1 "Ignoring rule4 $r4: less than minimum rule4 [OT_CfgGet STL_MIN_R4 0]"
		set r4 0
	}

	set p  [expr {double($p_num)/$p_den}]
	set dh [expr {double($dh_num)/$dh_den}]
	set ew [expr {double($ew_num)/$ew_den}]

	return [expr {$dh+$dh*$p*$ew*(1.0-$r4/100.0)}]
}


#
# --------------------------------------------------------------------------
# For a forecast/tricast selection, return a place for the selection
#   - if placed and within the number of places required return the place
#   - if placed and too low, or the result is 'L' return 'L'
#   - if a non-runner, return V
#   - if there is no result, return '-'
#
# There are three inputs:
#   result - the declared result (W/P/L/V/-)
#   place  - the declared place  (1,2,3,4,...)
#   poi    - the number of places of interest
# --------------------------------------------------------------------------
#
proc stl_fcast_part_result {result place poi} {
	if {$result == "-" || $result == "L" || $result == "V"} {
		return $result
	}
	if {$result == "W" || ($result == "P" && $place <= $poi)} {
		return $place
	}
	return L
}


#
# --------------------------------------------------------------------------
# For a forecast/tricast selection, return some stats about how many
# voids, losers etc there can be
#
# A list containing 4 elements is returned:
#   - number of bets
#   - maximum number of voids before the leg is void
#   - maximum number of "losers" before the leg is a loser
#   - highest place of interest
# --------------------------------------------------------------------------
#
proc stl_fcast_leg_info {leg_sort num_parts} {

	#
	# validate the leg sort and the selections (this is belt & braces: the
	# bet placement routines should have ensured that the bet was placed
	# correctly)
	#
	switch -- $leg_sort {
		SF {
			if {$num_parts != 2} {
				error "expected two parts for a $leg_sort leg"
			}
			return [list 1 0 0 2]
		}
		RF {
			if {$num_parts != 2} {
				error "expected two parts for a $leg_sort leg"
			}
			return [list 2 0 0 2]
		}
		CF {
			if {$num_parts < 3} {
				error "expected at least 3 parts for a $leg_sort leg"
			}
			return [list\
				[expr {$num_parts*($num_parts-1)}]\
				[expr {$num_parts-2}]\
				[expr {$num_parts-2}]\
				2]
		}
		TC {
			if {$num_parts != 3} {
				error "expected 3 parts for a $leg_sort leg"
			}
			return [list 1 0 0 3]
		}
		CT {
			if {$num_parts < 3} {
				error "expected at least 3 parts for a $leg_sort leg"
			}
			return [list\
				[expr {$num_parts*($num_parts-1)*($num_parts-2)}]\
				[expr {$num_parts-3}]\
				[expr {$num_parts-3}]\
				3]
		}
		default {
			error "unexpected leg_sort ($leg_sort)"
		}
	}
}


#
# --------------------------------------------------------------------------
# Special short-cut procedures for settling simple single bets - these form
# the majority of the bets placed, so a simple settlement routine to cater
# for them makes things a lot easier...
# --------------------------------------------------------------------------
#

#
# --------------------------------------------------------------------------
# Settle a bet as a loser - this is a simple update of the bet table,
# because it doesn't cause any account balances to change (so we don't need
# to write journal entries and the like).
# --------------------------------------------------------------------------
#
proc stl_bet_lose {bet_id} {

	variable BET

	stl_settle_bet_do_db\
		$bet_id\
		0\
		$BET(num_lines)\
		0\
		0
}


#
# --------------------------------------------------------------------------
# Settle a simple single bet as a void
# --------------------------------------------------------------------------
#
proc stl_bet_void {bet_id {settle_info ""}} {

	variable BET

	stl_settle_bet_do_db\
		$bet_id\
		0\
		0\
		$BET(num_lines)\
		0\
		$settle_info
}


#
# --------------------------------------------------------------------------
# Settle a simple single bet as a winner
# --------------------------------------------------------------------------
#
proc stl_bet_win_sgl {bet_id ev_oc_id} {

	variable BET
	variable SELN
	variable MKT
	variable MAX_PAY_SORT
	variable BCONTROL

	# Make sure BCONTROL is up to date
	stl_get_control

	#
	# Get all relevant market information
	#
	stl_get_mkt_info $SELN($ev_oc_id,ev_mkt_id)

	#
	# Check that using this settlement procedure is OK
	#
	if {$BET(num_selns) != 1} {
		log 1 "stl_bet_win_sgl: cannot settle (num_selns=$BET(num_selns))"
		error "inappropriate bet type"
	}
	if {$BET(num_legs) != 1} {
		log 1 "stl_bet_win_sgl: cannot settle (num_legs=$BET(num_legs))"
		error "inappropriate bet type"
	}

	set spl $BET(stake_per_line)
	set stk $BET(stake)
	set leg $BET(leg_type)

	set winnings    0.0
	set win_lines   0
	set lose_lines  0
	set settle_info ""

	set legs [list]

	if {$leg != "P"} { lappend legs W }
	if {$leg != "W"} { lappend legs P }

	foreach leg $legs {
		set rtn [stl_simple_leg_return $bet_id 1 $leg]
		if {$rtn == 0.0} {
			incr lose_lines 1
		} else {
			incr win_lines 1
			set line_payout [expr {$rtn*$spl}]
			if {$MAX_PAY_SORT == "LINE"} {
				if {$line_payout > $BET(max_payout)} {
     					if {$BCONTROL(max_payout_parking) == "Y"} {
						log 1 "Max payout exceeded - parking bet for manual settlement"
						send_max_payout_notification $BET(acct_id) $BET(bet_id)
					} else {
						set line_payout $BET(max_payout)
					}
				}
			}

			if {$MAX_PAY_SORT == "LINE_STAKE"} {
				if {[expr $line_payout - $spl]> $BET(max_payout)} {
					if {$BCONTROL(max_payout_parking) == "Y"} {
						log 1 "Max payout exceeded - parking bet for manual settlement"
						send_max_payout_notification $BET(acct_id) $BET(bet_id)
					} else {
						set line_payout [expr $BET(max_payout) + $spl]
					}
				}
			}

			set winnings [expr {$winnings+$line_payout}]
		}
	}

	if {$MAX_PAY_SORT == "BET"} {
		if {$winnings > $BET(max_payout)} {
  			if {$BCONTROL(max_payout_parking) == "Y"} {
				log 1 "Max payout exceeded - parking bet for manual settlement"
				send_max_payout_notification $BET(acct_id) $BET(bet_id)
			} else {
				set winnings $BET(max_payout)
			}
		}
	}

	if {$MAX_PAY_SORT == "BET_STAKE"} {
		if {[expr $winnings - $stk] > $BET(max_payout)} {
			if {$BCONTROL(max_payout_parking) == "Y"} {
				log 1 "Max payout exceeded - parking bet for manual settlement"
				send_max_payout_notification $BET(acct_id) $BET(bet_id)
			} else {
				set winnings [expr $BET(max_payout) + [expr $spl * $win_lines]]
			}
		}
	}

	stl_settle_bet_do_db\
		$bet_id\
		$win_lines\
		$lose_lines\
		0\
		$winnings
}


#
# --------------------------------------------------------------------------
# Settle a bet in the database
# --------------------------------------------------------------------------
#
proc stl_settle_bet_do_db {bet_id nw nl nv winnings {settle_info ""}} {

	global USERNAME
	global SELN_RESETTLE

	variable BET
	variable STL_LOG_ONLY
	variable SELN_CHECK

	variable CHANNELS_TO_ENABLE_PARKING
	variable PARK_ON_WINNINGS_ONLY

	set tax_type   $BET(tax_type)
	set tax        $BET(tax)
	set tax_rate   $BET(tax_rate)
	set num_lines  $BET(num_lines)

	if {$nw+$nv+$nl != $num_lines} {
		error "lines mismatch"
	}

	#
	# Deduct winnings tax
	#
	if {$winnings > 0.0 && $tax_type == "W"} {
		set n_tax    [expr {$winnings*(double($tax_rate)/100.0)}]
		set winnings [expr {$winnings-$n_tax}]
	} else {
		set n_tax $tax
	}

	#
	# Calculate any refunds (just based on number of void lines)
	#
	set refund 0.0

	if {$nv == $num_lines} {
		#
		# whole bet is void - refund all the money plus any stake tax
		#
		if {$tax_type == "S"} {
			set refund [expr {$BET(stake)+$tax}]
		} else {
			set refund [expr {$BET(stake)}]
		}
	} elseif {$nv > 0} {
		#
		# Bet is a partial void - refund a portion of stake plus any stake tax
		#
		set refund [expr {$nv*$BET(stake_per_line)}]

		if {$tax_type == "S"} {
			set refund [expr {$refund+(double($nv)/double($num_lines))*$tax}]
		}
	}

	log 1 "returns: [format %.2f [expr floor(round($winnings * 100))/100]]"
	log 1 "refund : [format %.2f [expr floor(round($refund * 100))/100]]"
	log 1 "    ($nw win lines $nl lose lines, $nv void lines)"

	if {$STL_LOG_ONLY} {
		# Round winnings & refunds
		set winnings [format %.2f [expr floor(round($winnings * 100))/100]]
		set refund   [format %.2f [expr floor(round($refund * 100))/100]]

	    log 1 "Old returns : $BET(winnings)"
	    log 1 "Old refund : $BET(refund)"

		#if the bet has been previously settled
		#this will show the discrepancy with the
		#new result
		if {$winnings != [format %.2f $BET(winnings)] ||
			$refund != [format %.2f $BET(refund)]} {

			set winnings_dif [expr {$winnings - [format %.2f $BET(winnings)]}]
			set refund_dif   [expr {$refund - [format %.2f $BET(refund)]}]

			set res [subst {Resettling outcome ${SELN_CHECK},$BET(bet_id),\
				$BET(acct_id),\
				$BET(num_lines_win),\
				$BET(num_lines_lose),\
				$BET(num_lines_void),\
				$BET(winnings),\
				$BET(refund),\
				$nw,$nl,$nv,\
				$winnings,\
				$refund,\
				$winnings_dif,\
				$refund_dif,\
				[expr {$winnings_dif + $refund_dif}]}]

			set SELN_RESETTLE($BET(bet_id)) $res
		}

		log 1 "\$STL_LOG_ONLY set : not updating database"
		return
	}

	#
	# call the stored procedure to settle the bet
	#
	set stmt [stl_qry_prepare BET_WIN_REFUND]

	# if the bet from a channel with parking enabled, make sure
	# that the correct parking enabled value is send to the query
	if {[lsearch -exact $CHANNELS_TO_ENABLE_PARKING $BET(source)]!=-1} {
	    set enable_parking "Y"
	} else {
	    set enable_parking "N"
	}

	# if this option is enabled the bet park limit is applied
	# to the winnings rather than the winnings + refund
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	# if we want to reclaim token value from winnings then pass this in
	if {[OT_CfgGet LOSE_FREEBET_TOKEN_VALUE "FALSE"]} {
	    set lose_token_value "Y"
	} else {
	    set lose_token_value "N"
	}

	OT_LogWrite 5 "bet source: $BET(source), parking enabled: $enable_parking, park on winnings: $park_limit_on_winnings"

	# Set it to include the bet in the summary table if
	# the config is set, and it's a manual on-course bet
	set force_summarize "N"
	if {$BET(bet_type) == "MAN" &&
		([OT_CfgGet FUNC_SUMMARIZE_MANUAL_BETS N] == "Y" ||
		([OT_CfgGet FUNC_SUMMARIZE_ONCOURSE_BETS 0] == 1 && $BET(source) == "C"))} {
		set force_summarize "Y"
	}

	set res [inf_exec_stmt $stmt\
		$USERNAME\
		$bet_id\
		$nw\
		$nl\
		$nv\
		$winnings\
		$n_tax\
		$refund\
		$settle_info\
		$enable_parking\
		$park_limit_on_winnings\
		$lose_token_value \
		$force_summarize]

	if {[catch {
		set stl_bet_pnd [db_get_coln $res 0]
		ob::log::write INFO {Settle bet pending : $stl_bet_pnd}
		if {[OT_CfgGet MONITOR 0] && $stl_bet_pnd == 1} {
			ADMIN::BET::send_parked_bet_ticker $bet_id $USERNAME $winnings $refund
		}
	} msg]} {
		ob::log::write ERR {Could not send parked bet ticker for bet #$bet_id : $msg}
	}
}


#
# --------------------------------------------------------------------------
# Pretty-print some information about the selection
# --------------------------------------------------------------------------
#
proc log_seln_info {ev_oc_id lev} {

	variable SELN

	set result        $SELN($ev_oc_id,result)
	set sp_num        $SELN($ev_oc_id,sp_num)
	set sp_den        $SELN($ev_oc_id,sp_den)
    set place         $SELN($ev_oc_id,place)

	set w_dh     [stl_get_deadheat "W" $ev_oc_id]
	set w_dh_num [lindex $dh 0]
	set w_dh_den [lindex $dh 1]

	log $lev "selection information:"
	log $lev "     event     : $SELN($ev_oc_id,event_name)"
	log $lev "     market    : $SELN($ev_oc_id,market_name)"
	log $lev "     selection : $SELN($ev_oc_id,desc)"
	log $lev "               : result = $result"

	if {$place != ""} {
		log $lev "               : place  = $place"
	}
	if {$sp_num != ""} {
		log $lev "               : sp     = $sp_num/$sp_den"
	}
	if {$w_dh_num != $w_dh_den} {
		log $lev "               : w redn = $w_dh_num/$w_dh_den"
	}


}


proc check_is_blockbuster {bet_id} {

    set stmt [stl_qry_prepare CHK_BLOCKBUSTER]
    set res  [inf_exec_stmt $stmt $bet_id]

    if {[db_get_nrows $res] == 0} {
        log 3 "this bet is not a blockbuster"
		return [list 0]
    }

    set bb_bonus [db_get_col $res 0 bonus_percentage]

    db_close $res

	return [list 1 $bb_bonus]

}

}

