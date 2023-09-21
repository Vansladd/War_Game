# ==============================================================
# $Id: settle-new.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Settlement code for lotteries
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc process_subs_for_xgame {{xgame_id ""} {use_handle_err 1}} {
	global xgaQry DB

	set honour_subs_on_activate [OT_CfgGet XG_HONOUR_SUBS_ON_ACTIVATE "0"]

	set customer [OT_CfgGet OPENBET_CUST ""]

	if {$customer == "BlueSQ"} {
		# keep a list of the Prizebuster subs which have their last bet placed
		# need to send a Subscription expired email to these customers

		set expired_subs "("

		# keep a list of the Prizebuster subs which only one sub left
		# after a bet is placed
		# need to send a warning to these customers telling them that their
		# subscription is about to expire

		set warning_subs "("
	}

	if {$xgame_id==""} {
		set xgame_id [reqGetArg xgame_id]
	}
	OT_LogWrite 2 "Ready to start inserting subs for game <$xgame_id>...."

	## Pull in status
	if {[catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg]} {
		return [handle_err "game_detail" "error: $msg"]
	}
	set status  [db_get_col $rs 0 status]
	set sort    [db_get_col $rs 0 sort]
	set draw_at [db_get_col $rs 0 draw_at]
	db_close $rs

	if {$status=="S"} {
		OT_LogWrite 2 "Game $xgame_id suspended - no outstanding subscriptions"
		if {$use_handle_err} {
			return [handle_err "Game Closed" "No outstanding subscriptions as this game is of status suspended"]
		} else {
			msg_bind "No outstanding subscriptions as this game is of status suspended"
			return
		}
	}

	set rs [get_subs_for_game $xgame_id]

	set nrows [db_get_nrows $rs]

	if {$nrows==0} {
		db_close $rs

		if {$honour_subs_on_activate==0} {
			OT_LogWrite 2 "No outstanding subscriptions for game $xgame_id"
			return [handle_err "No outstanding subscriptions for game $xgame_id" "There are no outstanding subscriptions to add as bets for this game"]

		} else {
			err_bind "No outstanding subscriptions for game $xgame_id"
			OT_LogWrite 2 "No outstanding subscriptions for game $xgame_id"
			return
		}
	}

	set lock_sql [subst {
		update tXGameSub
		set status = status
		where xgame_sub_id = ?
	}]

	set sub_sql [subst {
		insert into tXGameBet (
			xgame_id,
			xgame_sub_id,
			stake,
			picks,
			bet_type,
			num_selns,
			stake_per_line,
			num_lines,
			status
		) values (?,?,?,?,?,?,?,?,?)
	}]

	set xg_sql [subst {
		select first 1
			xgame_bet_id
		from
			tXGameBet
		where
			xgame_sub_id = ?
		and xgame_id = ?
	}]

	set fill_sql [subst {
		update
			tXGameSub
		set
			status = 'F'
		where
			xgame_sub_id = ?
	}]

	set stats_sql {
		execute procedure pDoCustStats(
			p_acct_id      = ?,
			p_action_name  = 'XGAME_BET',
			p_ref_id       = ?,
			p_source       = ?
		)
	}

	OT_LogWrite 2 "Number of outstanding subs for game $xgame_id = $nrows"
	for {set r 0} {$r < $nrows} {incr r} {
		set xgame_sub_id    [db_get_col $rs $r xgame_sub_id]
		set stake           [db_get_col $rs $r stake_per_bet]
		set num_subs        [db_get_col $rs $r num_subs]
		set picks           [db_get_col $rs $r picks]
		set bet_type        [db_get_col $rs $r bet_type]
		set num_selns       [db_get_col $rs $r num_selns]
		set stake_per_line  [db_get_col $rs $r stake_per_line]
		set num_lines       [db_get_col $rs $r num_lines]
		set acct_id         [db_get_col $rs $r acct_id]
		set source          [db_get_col $rs $r source]
		set status  "A"

		inf_begin_tran $DB

		if {[catch {xg_exec_qry $lock_sql $xgame_sub_id} msg]} {
			lappend errors "Cannot lock xgame sub $xgame_sub_id: $msg"
			inf_rollback_tran $DB
			continue
		}

		if {[catch {set xg_rs [xg_exec_qry $xg_sql $xgame_sub_id $xgame_id]} msg]} {
			lappend errors "Could not read tXGameBet, sub $xgame_sub_id, xgame $xgame_id: $msg"
			inf_rollback_tran $DB
			continue
		}

		set nxg_rows [db_get_nrows $xg_rs]
		db_close $xg_rs

		if {$nxg_rows != 0} {
			lappend errors "XGameBet already placed from sub $xgame_sub_id for xgame $xgame_id"
			inf_rollback_tran $DB
			continue
		}

		set stmt [inf_prep_sql $DB $sub_sql]
		if {[catch {inf_exec_stmt $stmt $xgame_id $xgame_sub_id \
					$stake $picks $bet_type $num_selns $stake_per_line \
					$num_lines $status} msg]} {
			lappend errors "Error inserting tXGameBet for sub $xgame_sub_id: $msg"
			inf_rollback_tran $DB
			continue
		}
		set xgame_bet_id [inf_get_serial $stmt]
		inf_close_stmt $stmt

		OT_LogWrite 2 "Inserted bet for xgame <$xgame_id> from sub <$xgame_sub_id>"

		# update the stats
		if {[catch {xg_exec_qry $stats_sql $acct_id $xgame_bet_id $source} msg]} {
			lappend errors "Error inserting tXGameBet for sub $xgame_sub_id: $msg"
			inf_rollback_tran $DB
			continue
		}

		#
		# Has the required number of bets /all requested bets
		# in subscription been placed?
		#
		if {[catch {set rs_sub [xg_exec_qry $xgaQry(num_bets_placed_for_sub) $xgame_sub_id]} msg]} {
			lappend errors "Error checking sub $xgame_sub_id: $msg"
			inf_rollback_tran $DB
			continue
		}

		set num_bets_placed  [db_get_col $rs_sub 0 num_bets_placed]

		db_close $rs_sub

		if {$num_bets_placed == $num_subs} {

			OT_LogWrite 2 "Sub <$xgame_sub_id> now filled: setting status to 'F'"

			# update sub record status as 'Filled'
			if {[catch {xg_exec_qry $fill_sql $xgame_sub_id} msg]} {
				lappend errors "Error filling sub $xgame_sub_id: $msg"
				inf_rollback_tran $DB
				continue
			}

			if {($sort == "PBUST3" || $sort == "PBUST4") && ($customer == "BlueSQ") } {
				if {$expired_subs != "("} {
					append expired_subs ", "
				}
				append expired_subs "$xgame_sub_id"
			}
		} elseif {$num_bets_placed == [expr {$num_subs - 1}]} {
			if {($sort == "PBUST3" || $sort == "PBUST4") && ($customer == "BlueSQ")} {
				if {$warning_subs != "("} {
					append warning_subs ", "
				}
				append warning_subs "$xgame_sub_id"
			}
		}

		inf_commit_tran $DB
	}
	db_close $rs

	if {[info exists errors]} {
		foreach e $errors {
			handle_err "Error inserting bet" "$msg"
		}
	} else {

		if {$honour_subs_on_activate==0} {
			handle_success "Finished placing bets for subscriptions" "$nrows bets placed"
		} else {
			err_bind "Finished placing bets for subscriptions $nrows bets placed"
		}
	}

	if {$customer == "BlueSQ"} {
		append expired_subs ")"
		append warning_subs ")"

		if {$expired_subs != "()"} {
			setup_sub_expired_mails $expired_subs
		}
		if {$warning_subs != "()"} {
			setup_sub_warning_mails $warning_subs
		}
   }
}

proc get_subs_for_game {xgame_id} {
	global xgaQry

	## Pull in sort
	if {[catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg]} {
		return [handle_err "game_detail" "****NEW****error: $msg"]
	}
	set sort         [db_get_col $rs 0 sort]
	set draw_desc_id [db_get_col $rs 0 draw_desc_id]
	set status       [db_get_col $rs 0 status]
	db_close $rs


	if {[OT_CfgGet XG_DYNAMIC_DRAW_DESC "0"] == "0"} {
		if {[catch {set rs [xg_exec_qry $xgaQry(get_outstanding_subs) $sort $xgame_id $xgame_id]} msg]} {
			return [handle_err "get_outstanding_subs" "****NEW****error: $msg"]
		}
	} else {
		if {[catch {set rs [xg_exec_qry $xgaQry(get_outstanding_subs) $sort $xgame_id "%$draw_desc_id%" $xgame_id]} msg]} {
			return [handle_err "get_outstanding_subs" "****NEW****error: $msg"]
		}
	}
	return $rs
}

proc settle_bets_from_result_set {sort results xgame_id rs nrows} {

	global xgaQry DB USERID

	set bets_settled 0
	set parked_bets 0
	set failed_to_settle 0

	set CHANNELS_TO_ENABLE_PARKING [split [OT_CfgGet CFG_CHANNELS_TO_ENABLE_PARKING ""] ,]

	#
	# If Yes will the park bet limit (tControl.stl_pay_limit) will be applied
	# to winnings only rather than refund + winnings
	#
	set PARK_ON_WINNINGS_ONLY [OT_CfgGet PARK_ON_WINNINGS_ONLY "0"]

	# if this option is enabled the bet park limit is applied
	# to the winnings rather than the winnings + refund
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	for {set r 0} {$r < $nrows} {incr r} {

		set winnings 0
		set num_lines_win 0
		set num_lines_lose 0
		set num_lines_void 0
		set paymethod O
		set refund   0
		set okay "true"

		set bet_id	    [db_get_col $rs $r xgame_bet_id]
		set picks	    [db_get_col $rs $r picks]
		set stake	    [db_get_col $rs $r stake]
		set sub_cr_date [db_get_col $rs $r sub_cr_date]
		set bet_type    [db_get_col $rs $r bet_type]
		set stake_per_line    [db_get_col $rs $r stake_per_line]
		set prices [db_get_col $rs $r prices]
		set settled [db_get_col $rs $r settled]
		set status [db_get_col $rs $r status]
		set source [db_get_col $rs $r source]
		set external_settle [db_get_col $rs $r external_settle]

		if {$external_settle == "Y"} {
			handle_err "settle bets with bet type"  "error: this game uses external settlement xgame_id:$xgame_id"
			return -1
		}

		if {$bet_type == "EXT"} {
			handle_err "settle bets with bet type"  "error: this bet uses external settlement xgame_bet_id:$bet_id"
			return -1
		}

		set op S


		if {[OT_CfgGet FUNC_LOTTO_MAX_CARD_PAYOUT 0] || [OT_CfgGet FUNC_LOTTO_MAX_PAYOUT 0]} {
			## Max card payout and max payout are in GBP
			## Winnings will by in customers registered currency
			## Convert max payouts to customer's currency
			set ccy_code    [db_get_col $rs $r ccy_code]
			set exch_rate   [db_get_col $rs $r exch_rate]

			if {[OT_CfgGet FUNC_LOTTO_MAX_CARD_PAYOUT 0]} {
				set max_card_payout [db_get_col $rs $r max_card_payout]
				if {$max_card_payout > 0} {
					set max_card_payout_converted [expr {$max_card_payout * $exch_rate}]
				}
			}

			if {[OT_CfgGet FUNC_LOTTO_MAX_PAYOUT 0]} {
				set max_payout  [db_get_col $rs $r max_payout]
				if {$max_payout > 0} {
					set max_payout_converted [expr {$max_payout * $exch_rate}]
				}
			}
		}

		OT_LogWrite 10 "settled: $settled      status: $status      results: $results"

		if {$settled=="Y"} {

			set okay "false"
			err_bind "failed to settle: bet already settled: $bet_id"
			OT_LogWrite 10 "failed to settle: bet already settled: $bet_id"
		}

		if {$bet_type==""} {

			set okay "false"
			err_bind "failed to settle: bet type not stored in bet xgame_id:$xgame_id, bet_id:$bet_id"
			OT_LogWrite 10 "failed to settle: bet type not stored in bet xgame_id:$xgame_id, bet_id:$bet_id"
		}

		# if the bet from a channel with parking enabled, make sure
		# that the correct parking enabled value is send to the query
		if {[lsearch -exact $CHANNELS_TO_ENABLE_PARKING $source]!=-1} {
			set enable_parking "Y"
		} else {
			set enable_parking "N"
		}


		if {$status=="S"} {

			if {$results=="-" || [string length $results]==0} {

				set okay "false"
				err_bind "failed to settle: no results for xgame: $xgame_id, bet_id: $bet_id"
				OT_LogWrite 10 "failed to settle: no results for xgame: $xgame_id, bet_id: $bet_id"
			}

			if {[catch {set rs_bt [xg_exec_qry $xgaQry(get_bet_types_detail) $bet_type]} msg]} {

				handle_err "get_bet_types_detail"  "error: $msg"
				return -1
			}
			set bt_count [db_get_nrows $rs_bt]

			if {$bt_count>0} {
				set min_combi [db_get_col $rs_bt 0 min_combi]
				set expected_num_selns [db_get_col $rs_bt 0 num_selns]
			} else {
				set okay "false"
				err_bind "failed to settle: bet type does not exist - bet_type:$bet_type, xgame_id:$xgame_id, bet_id:$bet_id"
				OT_LogWrite 10 "failed to settle: bet type does not exist - bet_type:$bet_type, xgame_id:$xgame_id, bet_id:$bet_id"
			}

			db_close $rs_bt

			set price_count 0
			foreach price_elem [split $prices "|"] {
				set prices_array($price_count) $price_elem
				incr price_count
			}

			OT_LogWrite 10 "==================================================================="
			OT_LogWrite 10 "Settling bet: $bet_id, type: $bet_type picks: $picks results: $results stake: $stake_per_line prices: $prices"

			set pick_count 0
			foreach p [split $picks "|"] {
				set picksarray($pick_count) $p
				incr pick_count
			}

			if {$okay == "true"} {

				if {$pick_count != $expected_num_selns} {
					set okay "false"
					err_bind "failed to settle: number of selections does not match bet type - picks_count$pick_count,  bet_type:$bet_type, xgame_id:$xgame_id, bet_id:$bet_id"
					OT_LogWrite 10 "failed to settle: number of selections does not match bet type - picks_count$pick_count,  bet_type:$bet_type, xgame_id:$xgame_id, bet_id:$bet_id"
				}

				set line_perms [BETPERM::bet_lines $bet_type]

				foreach line $line_perms {

					set length [llength $line]
					set pick_perm ""
					set count 1

					OT_LogWrite 10 "-----------------------------------------------"

					set price_index [expr $length-$min_combi]

					if {[info exists prices_array($price_index)]} {
						set price $prices_array($price_index)
						OT_LogWrite 10 "price: $price"
					} else {

						set okay "false"
						err_bind "failed to settle: not enough prices supplied in the subscription xgame: $xgame_id, bet_id: $bet_id"
						OT_LogWrite 10 "failed to settle: not enough prices supplied in the subscription xgame: $xgame_id, bet_id: $bet_id"
					}

					if {$okay == "true"} {
						foreach leg $line {
							set pick_index [expr $leg-1]
							append pick_perm $picksarray($pick_index)
							if {$count<$length} {
								append pick_perm "|"
							}
							incr count
						}
						set result_for_line [calc_for_accumulator $pick_perm $results $length $stake_per_line $price]

						set line_outcome [lindex $result_for_line 0]

						set line_winnings [lindex $result_for_line 1]

						if {$line_outcome=="win"} {
							incr num_lines_win
						} else {
							incr num_lines_lose
						}

						set winnings [expr $winnings+$line_winnings]
					}
				}
			}
		} elseif {$status=="A"} {


			set okay "false"
			err_bind "failed to settle: xgame still active: $xgame_id, bet_id: $bet_id"
			OT_LogWrite 10 "failed to settle: xgame still active: $xgame_id, bet_id: $bet_id"


		} elseif {$status=="V"} {

			set op X

			if {[catch {set rs_bt [xg_exec_qry $xgaQry(get_bet_types_detail) $bet_type]} msg]} {

				handle_err "get_bet_types_detail"  "error: $msg"
				return -1
			}

			set num_lines_void [db_get_col $rs_bt 0 num_lines]
			db_close $rs_bt

			set refund $stake
		}

		OT_LogWrite 10 "Finished settling bet: $bet_id"
		OT_LogWrite 10 "Lines won: $num_lines_win Lines lost: $num_lines_lose Lines void: $num_lines_void"
		OT_LogWrite 10 "Winnings: $winnings"
		OT_LogWrite 10 "Refund: $refund"
		OT_LogWrite 10 "Parking: $enable_parking"
		OT_LogWrite 10 "Parking on winnings: $park_limit_on_winnings"
		OT_LogWrite 10 "==================================================================="

		set TRANSACTIONAL "Y"
		set UN_PARK_AUTH "N"
		set SETTLEMENT_HOW "S"
		set comment ""

		if {$okay == "false"} {
			incr failed_to_settle
		} else {

			if {([OT_CfgGet FUNC_LOTTO_MAX_CARD_PAYOUT 0]) && ($max_card_payout > 0) && ($winnings >= $max_card_payout_converted)} {
				##If a bluesq user wins more than max_card_payout
				##they will be paid by cheque.
				##Do not credit winnings back to account
				set paymethod "C"
			} else {
				# Pay back into account
				set paymethod "O"
			}

			if {([OT_CfgGet FUNC_LOTTO_MAX_PAYOUT 0]) && ($max_payout > 0) && ($winnings >= $max_payout_converted)} {
				set winnings $max_payout_converted
			}

			if {[catch {set settle_rs [xg_exec_qry $xgaQry(settle_bet_bt) $bet_id $winnings $refund $paymethod $num_lines_win $num_lines_lose $num_lines_void $SETTLEMENT_HOW $comment $TRANSACTIONAL $park_limit_on_winnings $enable_parking $UN_PARK_AUTH $op $USERID]} msg]} {
				OT_LogWrite 5 "Error: $msg"
				err_bind "failed to settle: $msg"
				incr failed_to_settle

			} else {
				set outcome [db_get_coln $settle_rs 0 0]

				if {$outcome=="P"} {

					incr parked_bets

				} elseif {$outcome=="S"} {

					incr bets_settled

				}
				db_close $settle_rs
			}
		}
	}

	return [list $bets_settled $parked_bets $failed_to_settle]
}


proc settle_game_with_bet_type {sort results xgame_id} {

	global xgaQry
	set void_count 0

	## Get the unsettled bets
	if {[catch {set rs [xg_exec_qry $xgaQry(get_unsettled) $xgame_id]} msg]} {
		handle_err "get_unsettled" "error: $msg"
		return -1
	}

	set nrows [db_get_nrows $rs]

	if {$nrows==0} {
		err_bind "No bets: There are no unsettled bets for this game"
		return 0
	}

	OT_LogWrite 10 "Number of unsettled bets for game <$xgame_id> is $nrows"
	OT_LogWrite 10 "Results: $results"

	set bets_settled [settle_bets_from_result_set $sort $results $xgame_id $rs $nrows]

	OT_LogWrite 10 "Settlement complete ...."

	db_close $rs

	return $bets_settled
}

proc settle_bet_with_bet_type {xgame_betid} {
	global xgaQry

	## Get the unsettled bet
	if {[catch {set rs [xg_exec_qry $xgaQry(get_bet_for_settlement) $xgame_betid]} msg]} {
		return [handle_err "get_bet_for_settlement" "error: $msg"]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows==0} {
		db_close $rs
		return [handle_err "No bets" "This bet does not exist in the db"]
	}

	set results     [db_get_col $rs 0 results]
	set sort        [db_get_col $rs 0 sort]
	set xgame_id    [db_get_col $rs 0 xgame_id]

	OT_LogWrite 10 "Results: $results"

	set bets_settled [settle_bets_from_result_set $sort $results $xgame_id $rs $nrows]

	OT_LogWrite 10 "Settlement complete ...."

	db_close $rs

	return $bets_settled
}

proc unpark_xgamebet args {

	global xgaQry USERID

	set winnings [reqGetArg BetWinnings]
	set refund [reqGetArg BetRefund]
	set num_lines_win [reqGetArg BetWinLines]
	set num_lines_lose [reqGetArg BetLoseLines]
	set num_lines_void [reqGetArg BetVoidLines]
	set comment [reqGetArg BetComment]
	set bet_id [reqGetArg BetId]

	set paymethod O

	set SETTLEMENT_HOW "M"
	set TRANSACTIONAL "N"
	set PARK_BY_WINNINGS "N"
	set ENABLE_PARKING "N"
	set UN_PARK_AUTH "Y"

	set op S

	if {[catch {set settle_rs [xg_exec_qry $xgaQry(settle_bet_bt) $bet_id $winnings $refund $paymethod $num_lines_win $num_lines_lose $num_lines_void $SETTLEMENT_HOW $comment $TRANSACTIONAL $PARK_BY_WINNINGS $ENABLE_PARKING $UN_PARK_AUTH $op $USERID]} msg]} {
		OT_LogWrite 5 "Error: $msg"
		handle_err "settle_bet_bt"  "error: $msg"
		return
	}

	db_close $settle_rs

	ADMIN::BET::go_xgame_receipt
}

proc calc_for_accumulator {picks results to_match stake_per_line price} {


	set price_elems [split $price "-"]

	set num [lindex $price_elems 0]
	set den [lindex $price_elems 1]

	set dividend_multiplier [expr {double($num) / double($den)}]

	OT_LogWrite 10 "Multiplier: $dividend_multiplier"

	#	set up array of results
	foreach p [split $results "|"] {
		set result($p) 1
	}

	set matched_count 0

	foreach p [split $picks "|"] {
		if {[info exists result($p)]} {
			incr matched_count
		}
	}

	OT_LogWrite 10 "picks: $picks matched: $matched_count required: $to_match"
	if {$matched_count<$to_match} {
		OT_LogWrite 10 "Line loses"
		return [list "lose" "0"]
	} else {
		set win [expr ($stake_per_line*$dividend_multiplier)+$stake_per_line]
		OT_LogWrite 10 "Line wins: $win"
		return [list "win" $win]
	}
}

proc internal_settle_with_bet_types {xgame_id} {

	global xgaQry
	global DIVIDEND

	OT_LogWrite 10 "internal_settle starting..."

	## Pull in results
	if {[catch {set rs [xg_exec_qry $xgaQry(game_detail) $xgame_id]} msg]} {
		return [handle_err "game_detail" "error: $msg"]
	}

	set results [db_get_col $rs 0 results]
	set sort    [db_get_col $rs 0 sort]
	db_close $rs

	set nrows_settled 0
	set nrows_parked 0
	set nrows_failed 0

	if {[OT_CfgGet XG_SETTLE_WITH_DIVIDENDS "1"] == "1"} {

		if {$results==""} {
			err_bind "No results: There are no results entered for this game"
		}

		set nrows_settled [settle_with_game_dividends $sort $results $xgame_id]
	} else {
		set settled_parked  [settle_game_with_bet_type $sort $results $xgame_id]

		if {$settled_parked!=-1} {
			set nrows_settled [lindex $settled_parked 0]
			set nrows_parked [lindex $settled_parked 1]
			set nrows_failed [lindex $settled_parked 2]
		}
	}

	tpBindString settled $nrows_settled
	tpBindString parked $nrows_parked
	tpBindString failed $nrows_failed

	X_play_file xgame_settlement_done.html
}
