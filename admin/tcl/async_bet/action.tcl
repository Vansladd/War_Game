# $Id: action.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Admin
# Asynchronous Betting - Handle the actions/offers
#
# Configuration:
#
# Procedures:
#

# Namespace
#
namespace eval ::ADMIN::ASYNC_BET {

	asSetAct ADMIN::ASYNC_BET::DoActAccept  {::ADMIN::ASYNC_BET::H_action "ACCEPT"}
	asSetAct ADMIN::ASYNC_BET::DoActDecline {::ADMIN::ASYNC_BET::H_action "DECLINE"}
	asSetAct ADMIN::ASYNC_BET::DoActCancel  {::ADMIN::ASYNC_BET::H_action "CANCEL"}
	asSetAct ADMIN::ASYNC_BET::DoActStkLP   {::ADMIN::ASYNC_BET::H_act_stk_lp}

	variable BET_MONITOR_WARN_THRESHOLD
	variable FUNC_ASYNC_BET_DETAILS
	variable BET

	set BET_MONITOR_WARN_THRESHOLD [OT_CfgGet BET_MONITOR_WARN_THRESHOLD ""]
	set FUNC_ASYNC_BET_DETAILS     [OT_CfgGet FUNC_ASYNC_BET_DETAILS 0]
	array set BET                  [list]
}


#--------------------------------------------------------------------------
# Action Handlers
#--------------------------------------------------------------------------
proc ::ADMIN::ASYNC_BET::H_action {type} {
	global   ASYNC_MULTI_RPT DB
	variable FUNC_ASYNC_BET_DETAILS
	variable BET

	if {$type == "ACCEPT"} {
		set rpt_info   "Bet Accepted"
		set error_info "You don't have permission to accept an Asynchronous Bet"
		set action     "A"
	} elseif {$type == "DECLINE"} {
		set rpt_info   "Bet Declined"
		set error_info "You don't have permission to decline an Asynchronous Bet"
		set action     "D"
	} elseif {$type == "CANCEL"} {
		set rpt_info   "Bet Cancelled"
		set error_info "You don't have permission to cancel an Asynchronous Bet"
		set action     "C"
	} else {
		_err_bind "Unrecognised action"
		return
	}

	set bet_ids       [split [reqGetArg bet_id] {|}]
	set bet_group_ids [split [reqGetArg bet_group_id] {|}]
	set multi_bet     [expr {([reqGetArg multi_bet])==""?0:[reqGetArg multi_bet]}]

	catch {array unset BET}
	array set BET [list]
	catch {array unset ASYNC_MULTI_RPT}
	array set ASYNC_MULTI_RPT [list]
	set ASYNC_MULTI_RPT(bet_ids) $bet_ids

	# have permission?
	if {![op_allowed ManageAsyncBets]} {
		_err_bind $error_info
	} else {

		if {([llength $bet_ids] != [llength $bet_group_ids]) && $multi_bet} {
			_err_bind "Error: Mismatch between number of bets and bet groups"
		} else {

			set BET(num) [llength $bet_ids]
			set BET(bet_ids)   $bet_ids

			if {$multi_bet == 0 && $bet_group_ids == ""} {
				lappend bet_group_ids  -1
			} 

			foreach bet_id $bet_ids bet_group_id $bet_group_ids {
					set BET($bet_id,bet_group_id) $bet_group_id
			}

			if {$action == "D"} {
				set reason_codes   [split [reqGetArg reason_code] {|}]

				foreach bet_id $bet_ids reason_code $reason_codes {
					set BET($bet_id,reason_code) $reason_code
				}
			} else {
				foreach bet_id $bet_ids {
					set BET($bet_id,reason_code) ""
				}

			}


			#Call a procedure to get all the other bets in related groups
			_inc_group_bets $bet_group_ids $multi_bet $action

			foreach bet_id $BET(bet_ids) {

				set ASYNC_MULTI_RPT($bet_id,bet_id) $bet_id
				set ASYNC_MULTI_RPT($bet_id,result) 0
				set ASYNC_MULTI_RPT($bet_id,info)   $rpt_info

				if {![info exists BET($bet_id,bet_id)]} {
					set ASYNC_MULTI_RPT($bet_id,info) "Sorry, but this action can not be \
									taken - this bet is no longer in the bet queue."
					continue
				}

				if {$BET($bet_id,ref_status) == "O"} {
					set ASYNC_MULTI_RPT($bet_id,info) "Sorry, but this action can not be \
									taken. This bet has been overridden by the Operator."
					continue
				}

				if {$FUNC_ASYNC_BET_DETAILS} {
					if {[catch {_check_lock $bet_id} msg]} {
						if {$multi_bet == 1} {
							set ASYNC_MULTI_RPT($bet_id,info) $msg
							continue
						} else {
							_err_bind $msg
							return [H_bet]
						}
					} elseif {$multi_bet == 1} {
						# In multi bet mode bets are locked before being accepted
						# This would avoid issues with various admin users trying to
						# accept/decline them at the same time.
						if {[catch {_update_lock $bet_id} msg]} {
							set ASYNC_MULTI_RPT($bet_id,info) $msg
							continue
						}
					}
				}

				if {[catch {
						if {$action == "C"} {
							_cancel_bet $bet_id $BET($bet_id,acct_id) $BET($bet_id,bet_reason)
						} else {
							_create_action $bet_id $BET($bet_id,acct_id) $BET($bet_id,bet_reason) $BET($bet_id,reason_code) $action
						}
				} msg]} {
					if {$multi_bet == 1} {
						set ASYNC_MULTI_RPT($bet_id,info) $msg
						continue
					} else {
					_err_bind $msg
					}
				} else {
					set ASYNC_MULTI_RPT($bet_id,result) 1
				}
			}
		}
	}

	# re-display details, will pickup the new offer
	if {$multi_bet != 1} {
		H_bet
	} else {
		_send_multi_rpt $ASYNC_MULTI_RPT(bet_ids)
	}
}

# Create a stake and/or price offer
#
proc ::ADMIN::ASYNC_BET::H_act_stk_lp args {

	global ASYNC_MULTI_RPT DB
	variable FUNC_ASYNC_BET_DETAILS
	variable BET

	set bet_ids         [split [reqGetArg bet_id] {|}]
	set bet_group_ids   [split [reqGetArg bet_group_id] {|}]
	set stakes_per_line [split [reqGetArg stake_per_line] {|}]

	set multi_bet     [expr {([reqGetArg multi_bet])==""?0:[reqGetArg multi_bet]}]

	if {$multi_bet == 0 && $bet_group_ids == ""} {
		lappend bet_group_ids  -1
	}

	catch {array unset BET}
	array set BET [list]
	catch {array unset ASYNC_MULTI_RPT}
	array set ASYNC_MULTI_RPT [list]
	set ASYNC_MULTI_RPT(bet_ids) $bet_ids

	# have permission?
	if {![op_allowed ManageAsyncBets]} {
		_err_bind "You don't have permission to decline an Asynchronous Bet"
		return [H_bet]
	}

	if {([llength $bet_ids] != [llength $bet_group_ids]) } {
		_err_bind "Error: Mismatch between number of bets and bet groups "
	} else {

		set BET(num) [llength $bet_ids]
		set BET(bet_ids)   $bet_ids

		if {$multi_bet == 0 && $bet_group_ids == ""} {
			lappend bet_group_ids  -1
		} 

		foreach bet_id $bet_ids bet_group_id $bet_group_ids stake_per_line $stakes_per_line {
				set BET($bet_id,bet_group_id)       $bet_group_id
				set BET($bet_id,stakes_per_line)    $stake_per_line
		}

		foreach bet_id $bet_ids {
					set BET($bet_id,reason_code) ""
		}

		#Call a procedure to get all the other bets in related groups
		_inc_group_bets $bet_group_ids $multi_bet "StkLP"

		foreach bet_id $BET(bet_ids) {

			set ASYNC_MULTI_RPT($bet_id,bet_id) $bet_id
			set ASYNC_MULTI_RPT($bet_id,result) 0
			set ASYNC_MULTI_RPT($bet_id,info) "Bet Offered at Max bet"

			if {![info exists BET($bet_id,bet_id)]} {
				set ASYNC_MULTI_RPT($bet_id,info) "Sorry, but this action can not be \
								taken - this bet is no longer in the bet queue."
				continue
			}

			if {$BET($bet_id,ref_status) == "O"} {
					set ASYNC_MULTI_RPT($bet_id,info) "Sorry, but this action can not be \
									taken. This bet has been overridden by the Operator."
					continue
			}

			if {$FUNC_ASYNC_BET_DETAILS} {

				if {[catch {_check_lock $bet_id} msg]} {
					if {$multi_bet == 1} {
						set ASYNC_MULTI_RPT($bet_id,info) $msg
						continue
					} else {
						_err_bind $msg
						return [H_bet]
					}
				} elseif {$multi_bet == 1} {
					# In multi bet mode bets are locked before being declined
					# This would avoid issues with various admin users trying to
					# accept/decline them at the same time.
					if {[catch {_update_lock $bet_id} msg]} {
						set ASYNC_MULTI_RPT($bet_id,info) $msg
						continue
					}
				}
			}

   			# create an 'Async Bet Action/Offer Instance'
    		if {[catch {_create_action $bet_id $BET($bet_id,acct_id) $BET($bet_id,bet_reason) $BET($bet_id,reason_code) StkLP $BET($bet_id,stakes_per_line) } msg]} {
    			if {$multi_bet == 1} {
    				set ASYNC_MULTI_RPT($bet_id,info) $msg
    					continue
    				} else {
    					_err_bind $msg
    				}
    			} else {
    				set ASYNC_MULTI_RPT($bet_id,result) 1
    			}
		}
	}

	# re-display details, will pickup the new offer
	if {$multi_bet != 1} {
		H_bet
	} else {
		_send_multi_rpt $ASYNC_MULTI_RPT(bet_ids)
	}
}


#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
#Procedure to get all the remaining bets in specified groups
#--------------------------------------------------------------------------

proc ::ADMIN::ASYNC_BET::_inc_group_bets {bet_group_ids multi_bet {action ""} } {

	global   DB
	variable BET
	set bet_reasons   [split [reqGetArg bet_reason] {|}]
	set prep_sql 0

	foreach bet_id $BET(bet_ids) bet_reason $bet_reasons {

		if { $action != "C" } {
			set where "y.park_reason <> \"GROUP_REFERRAL\" and"
		} else {
			set where ""
		}

		if {$BET($bet_id,bet_group_id) == -1 || ($multi_bet == 0 && $action == "StkLP")} {
			set from "outer tbetslipbet sb"
			set where "$where y.bet_id = ?"
			set arg $bet_id
		} else {
			set from "tbetslipbet sb"
			set where "$where sb.betslip_id = ?"
			set arg $BET($bet_id,bet_group_id)
		}

		# Get all bet ids & acc_ids that belong to this bet group id
		set sql [subst {
			select
				y.acct_id,
				y.bet_id,
				bo.status,
				b.max_bet 
			from
				tBet b,
				tBetAsync y,
				outer tAsyncBetOff bo,
				$from
			where
				y.bet_id = bo.bet_id and
				y.bet_id = b.bet_id and
				b.bet_id = sb.bet_id and
				$where
			}]

		set stmt [inf_prep_sql $DB $sql]

		set rs [inf_exec_stmt $stmt $arg]
		set nrows [db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			set r_bet_id                       [db_get_col $rs $r bet_id]
			set BET($r_bet_id,ref_status)      [db_get_col  $rs $r status]
			set BET($r_bet_id,bet_id)          $r_bet_id
			set BET($r_bet_id,acct_id)         [db_get_col $rs $r acct_id]
			set BET($r_bet_id,bet_group_id)    $BET($bet_id,bet_group_id)
			set BET($r_bet_id,bet_reason)      $bet_reason
			set BET($r_bet_id,reason_code)     $BET($bet_id,reason_code)
			if {$multi_bet} {
				set BET($r_bet_id,stakes_per_line) [db_get_col $rs $r max_bet]
			}

			if { [lsearch -exact $BET(bet_ids) $r_bet_id ] == -1 } {
				lappend BET(bet_ids)  $r_bet_id
			}
		}
	}

	if { $prep_sql } {
		inf_close_stmt $stmt
		db_close $rs
	}

}



# Private procedure to create an Asynchronous Bet Offer.
#
#   status - offer status
#
proc ::ADMIN::ASYNC_BET::_create_action { bet_id acct_id reason_text reason_code status {stake_per_line ""}} {

	global DB
	variable BET_MONITOR_WARN_THRESHOLD

	# get offer parameters (what we need depends on the status)
	set leg_type       ""
	switch -- $status {
		A -
		D {
			set apply_offer "Y"
		}
		StkLP {

			if {[OT_CfgGet ASYNC_BET_APPLY_OFFER_ALWAYS 1]} {
				set apply_offer "Y"
			} else {
				set apply_offer "N"
			}

			set leg_type [reqGetArg leg_type]

			ob_log::write DEV "_create_action: stake_per_line is $stake_per_line, leg_type is $leg_type"

			set LP(total) 0
			set num_vals  [reqGetNumVals]
			set exp       {^lp_([0-9]+)_([0-9]+)$}

			# find any price offers
			for {set i 0} {$i < $num_vals} {incr i} {

				set name  [reqGetNthName $i]
				set value [reqGetNthVal  $i]

				# is the argument a price offer?
				if {$value != "" && [regexp $exp $name all leg_no part_no]} {
					set LP($LP(total),leg_no)  $leg_no
					set LP($LP(total),part_no) $part_no

					if { [string compare "SP" [string toupper $value] ] == 0 } {
						set LP($LP(total),price_type) "S"
						set LP($LP(total),num) ""
						set LP($LP(total),den) ""
					} else {
						foreach {num den} [get_price_parts $value] {}
						set LP($LP(total),price_type) "L"
						set LP($LP(total),num) $num
						set LP($LP(total),den) $den
					}
					incr LP(total)
				}
			}

			# what is the offer-status, depending if we have some prices
			if { $leg_type == "" } {
				if {$stake_per_line == ""} {
					if {!$LP(total)} {
						error "No price and/or stake offer\[s\]"
					}
					set status P
				} else {
					if {!$LP(total)} {
						set status S
					} else {
						set status B
					}
				}
			} else {
				if {$stake_per_line == "" && !$LP(total)} {
					set status L
				} elseif { $stake_per_line == "" && $LP(total) } {
					set status F
				} elseif { $stake_per_line != "" && !$LP(total) } {
					set status E
				} else {
					set status G
				}
			}
		}
	}

	ob_log::write DEV "_create_action: Status is $status"

	#In order to get channel and group specific async values, we need customer's group and channel

	if { [OT_CfgGet FUNC_ASYNC_FINE_GRAINED 0] } {

		set sql {
				select
					b.source,
					o.in_running,
					r.code
				from
					tbet b,
					tobet o,
					tacct a,
					outer tCustomerReg r
				where
					b.bet_id = o.bet_id and
					b.acct_id = a.acct_id and
					a.cust_id = r.cust_id and
					b.bet_id = ?
			}

		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt $bet_id]
		inf_close_stmt $stmt

		set channel        [db_get_col $rs 0 source]
		set in_running     [db_get_col $rs 0 in_running]
		set cust_code      [db_get_col $rs 0 code]

		db_close $rs

		set off_tout    [ob_control::get async_off_timeout $channel $in_running $cust_code]

		if { [ob_control::get async_auto_place $channel] == "N" } {
			set apply_offer "N"
		}

	} else {
		set off_tout    [ob_control::get async_off_timeout]
	}

	set expiry_date [expr {[clock seconds] + $off_tout}]

	# offer expiry should be <= smallest start-time/suspend-at, unless we
	# have bet-in-runing market, then dont matter
	if {[OT_CfgGet ASYNC_BET_RESTRICT_OFFER_EXPIRY 1]} {

		set sql {
			select
				min(e.suspend_at) as suspend_at,
				min(e.start_time) as start_time
			from
				tEv e,
				tEvMkt m,
				tEvOc o,
				tOBet b
			where
				b.bet_id = ?
			and o.ev_oc_id = b.ev_oc_id
			and m.ev_mkt_id = o.ev_mkt_id
			and e.ev_id = m.ev_id
			and m.bet_in_run = 'N'
		}

		set stmt  [inf_prep_sql $DB $sql]
		set rs    [inf_exec_stmt $stmt $bet_id]
		inf_close_stmt $stmt

		set suspend_at [db_get_col $rs 0 suspend_at]
		set start_time [db_get_col $rs 0 start_time]
		if {$suspend_at != "" || $start_time != ""} {

			set start_time [clock scan $start_time]

			if {$suspend_at == ""} {
				set suspend_at $start_time
			} else {
				set suspend_at [clock scan $suspend_at]
			}
			if {$suspend_at > $start_time} {
				set tm $start_time
			} else {
				set tm $suspend_at
			}

			# start-time is earlier than expiry-date?
			if {$expiry_date > $tm && $status != "D"} {
				set expiry_date $tm
			}
		}
		db_close $rs
	}

	set expiry_date [clock format $expiry_date -format "%Y-%m-%d %H:%M:%S"]

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

	set sql [subst {
		execute procedure pInsAsyncBetOff(
		    p_adminuser    = ?,
		    p_bet_id       = ?,
		    p_expiry_date  = ?,
		    p_status       = ?,
		    p_off_stake    = ?,
		    p_reason_code  = ?,
		    p_off_leg_type = ?,
		    p_reason_text  = ?
		)
	}]
	set stmt_off [inf_prep_sql $DB $sql]

	set sql [subst {
		execute procedure pInsAsyncBetLegOff(
		    p_adminuser        = ?,
		    p_bet_id           = ?,
		    p_leg_no           = ?,
		    p_part_no          = ?,
		    p_off_num          = ?,
		    p_off_den          = ?,
		    p_off_price_type   = ?
		)
	}]
	set stmt_leg [inf_prep_sql $DB $sql]

	set sql [subst {
		execute procedure pAsyncApplyOffer(
		    p_adminuser     = ?,
		    p_bet_id        = ?,
		    p_acct_id       = ?,
		    p_transactional = 'N',
			p_rtn_freebet_can  = ?,
			p_return_freebet   = ?
		)
	}]
	set stmt_apply [inf_prep_sql $DB $sql]

	set sql [subst {
		select
			b.bet_type,
			m.ev_mkt_id,
			e.start_time
		from
			tBet b,
			tObet o,
			tEvMkt m,
			tEvOc oc,
			tEv e
		where
			b.bet_id = ? and
			b.bet_id = o.bet_id and
			o.ev_oc_id = oc.ev_oc_id and
			oc.ev_mkt_id = m.ev_mkt_id and
			m.ev_id = e.ev_id
		order by
			e.start_time
	}]

	set rum_stmt [inf_prep_sql $DB $sql]

	set sql [subst {
		execute procedure pLEQBet (
			p_bet_type    = ?,
			p_bet_id      = ?,
			p_ev_mkt_id   = ?
		)
	}]
	set rum_insert_stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	# create the offer
	if {[catch {set res [inf_exec_stmt $stmt_off\
				$::USERNAME\
				$bet_id\
				$expiry_date\
				$status\
				$stake_per_line\
				$reason_code \
				$leg_type\
				$reason_text\
				]} msg]} {
		inf_rollback_tran $DB
		inf_close_stmt $stmt_off
		inf_close_stmt $stmt_leg
		inf_close_stmt $stmt_apply
		OT_LogWrite 3 "_create_action: Failed to create async bet offer: $msg"
		error $msg
	}

	# If user needs to top up - do not apply the offer
	set accept_status [db_get_coln $res 0 1]
	if { $accept_status == "T" } {
		set apply_offer "N"
	}

	catch {db_close $res}

	ob_log::write DEV "_create_action: inserted offer with $::USERNAME $bet_id $expiry_date $status $stake_per_line $reason_code"

	# any price offers
	if { $status == "P" || $status == "B" || $status == "F" || $status == "G" } {
		for {set i 0} {$i < $LP(total)} {incr i} {

			ob_log::write DEV "_create_action: num is $LP($i,num), den is $LP($i,den)"
			if {[catch {inf_exec_stmt $stmt_leg\
			            $::USERNAME\
			            $bet_id\
			            $LP($i,leg_no)\
			            $LP($i,part_no)\
			            $LP($i,num)\
			            $LP($i,den)\
						$LP($i,price_type)} msg]} {
				inf_rollback_tran $DB
				inf_close_stmt $stmt_off
				inf_close_stmt $stmt_leg
				inf_close_stmt $stmt_apply
				OT_LogWrite 3 "_create_action: Failed to create async bet leg offer: $msg"
				error $msg
			}
		}
	}

	array set LIAB [list]
	set LIAB(alert_code) ""
	set LIAB(status) ""

	if {$apply_offer == "Y"} {
		if {[catch {
			set rs [inf_exec_stmt $stmt_apply\
					$::USERNAME\
					$bet_id\
					$acct_id\
					$return_freebets_cancel\
					$return_freebets]
		} msg]} {
			inf_rollback_tran $DB
			inf_close_stmt $stmt_off
			inf_close_stmt $stmt_leg
			inf_close_stmt $stmt_apply
			OT_LogWrite 3 "_create_action: failed to apply async bet offer: $msg"
			error $msg
		}

		set LIAB(type)        [db_get_coln $rs 0 0]
		set LIAB(status)      [db_get_coln $rs 0 1]
		set LIAB(level)       [db_get_coln $rs 0 2]

	}

	inf_commit_tran $DB

	inf_close_stmt $stmt_off
	inf_close_stmt $stmt_leg
	inf_close_stmt $stmt_apply

	if {$apply_offer == "Y"} {
		db_close $rs

		if { $status == "A" } {
			# Now possibly add to RUM
			if {[catch {
				set rum_rs   [inf_exec_stmt $rum_stmt $bet_id]
			} msg]} {
				inf_close_stmt $rum_stmt
				db_close $rum_rs
				ob_log::write ERROR "_create_action: failed to find the Async Bet \
										Details for bet_id=$bet_id"
			} else {

				if {[db_get_nrows $rum_rs] == 0} {
					ob_log::write ERROR "_create_action: failed to find the Async \
											Bet Details for bet_id=$bet_id"
				} else {

					# only need the first
					set bet_type  [db_get_col $rum_rs 0 bet_type]
					set ev_mkt_id [db_get_col $rum_rs 0 ev_mkt_id]

					if { $bet_type != "SGL" && [OT_CfgGet OFFLINE_LIAB_ENG_RUM 0] } {
						# Add to DBV RUM Queue
						ob_log::write INFO {_create_action: Queing bet_id=$bet_id\
											bet_type=$bet_type, ev_mkt_id=$ev_mkt_id for RUM }

						if {[catch {set res [inf_exec_stmt $rum_insert_stmt\
									$bet_type\
									$bet_id\
									$ev_mkt_id]
						} msg]} {
							ob_log::write ERROR {_create_action: failed to queue to rum\
												bet_id=$bet_id, $msg}
							inf_close_stmt $rum_insert_stmt
							db_close $res
						}
					}
				}
				inf_close_stmt $rum_stmt
				db_close $rum_rs
			}
		}
	}

	#
	# If we have just declined the offer we can stop now
	#
	if {$status == "D" || $accept_status == "T"  || ![OT_CfgGet MONITOR 0]} {
		return
	}

	set sql {
		select
			c.cust_id,
			c.username,
			r.fname,
			r.lname,
			r.code,
			c.elite,
			c.notifyable,
			c.country_code,
			r.addr_postcode,
			r.email,
			b.source,
			b.bet_type,
			b.stake,
			b.stake_per_line,
			b.ipaddr,
			a.ccy_code,
			c.max_stake_scale,
			b.num_selns,
			b.num_lines,
			case when a.owner = 'Y' then
				'Y'
			else
				'N'
			end as hedged,
			ec.category,
			ec.ev_class_id,
			ec.name class_name,
			et.ev_type_id,
			et.name type_name,
			ev.ev_id,
			ev.desc ev_name,
			ev.start_time,
			m.ev_mkt_id,
			m.hcap_value,
			m.sort mkt_sort,
			m.name mkt_name,
			m.ev_oc_grp_id,
			s.ev_oc_id,
			s.desc oc_name,
			o.o_num,
			o.o_den,
			o.price_type,
			b.leg_type,
			c.liab_group,
			o.leg_no,
			o.part_no,
			y.exch_rate,
			l.intercept_value,
			l.liab_desc,
			b.max_bet
		from
			tBet b,
			tOBet o,
			tEvOc s,
			tEvMkt m,
			tEv ev,
			tEvType et,
			tEvClass ec,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tCcy y,
			outer tLiabGroup l
		where
			b.bet_id = ?
		and b.bet_id = o.bet_id
		and o.ev_oc_id = s.ev_oc_id
		and m.ev_mkt_id = s.ev_mkt_id
		and ev.ev_id = m.ev_id
		and ev.ev_type_id = et.ev_type_id
		and ec.ev_class_id = et.ev_class_id
		and a.acct_id = b.acct_id
		and c.cust_id = a.cust_id
		and r.cust_id = c.cust_id
		and y.ccy_code = a.ccy_code
		and l.liab_group_id = c.liab_group
		order by
			o.bet_id,o.leg_no,o.part_no
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		OT_LogWrite 1 "_create_action: bet $bet_id not found"
		return
	}

	set seln_dets [list \
		category ev_class_id class_name ev_type_id type_name ev_id \
		ev_name start_time ev_mkt_id mkt_name ev_oc_id oc_name \
		hcap_value mkt_sort]

	for {set i 0} {$i < $nrows} {incr i} {
		if {$i == 0} {
			foreach v {
				cust_id username fname lname code elite notifyable country_code
				addr_postcode email source bet_type stake ccy_code
				max_stake_scale num_selns num_lines leg_type liab_group exch_rate
				ipaddr stake_per_line
			} {
				set $v [db_get_col $rs 0 $v]
			}
			set hedged [db_get_col $rs 0 hedged]
			if {$hedged == "Y"} {
				set stake [expr {0.0 - $stake}]
			}
			set stake_sys [expr {$stake / $exch_rate}]
			set stake_sys [format %.2f $stake_sys]

			foreach v $seln_dets {
				set $v [list]
			}
			set prices [list]

			set max_bet_allowed_per_line [expr {[db_get_col $rs $i max_bet] / $num_lines}]

			# Async bets may use 100%
			if {$max_bet_allowed_per_line == 0.00} {
				set max_stake_percentage_used 100.00
			} else {
				set max_stake_percentage_used [expr {($stake_per_line * 100.00) / $max_bet_allowed_per_line}]
				# make it have no more than two decimals
				regexp {^.*\.[0-9][0-9]?} $max_stake_percentage_used max_stake_percentage_used
			}

		}

		foreach v $seln_dets {
			lappend $v [db_get_col $rs $i $v]
		}
		set o_num [db_get_col $rs $i o_num]
		set o_den [db_get_col $rs $i o_den]
		set price_type [db_get_col $rs $i price_type]

		if {$price_type == "S"} {
			set this_price "SP"
		} else {
			set this_price [mk_price $o_num $o_den]
		}
		lappend prices $this_price

	}

	# get the proper stake scale
	foreach {max_stake_scale liab_group intercept_value} [_get_max_stake_scale $rs] {}

	lappend monitored  [expr {$max_stake_scale < 1 ? "Y" : "N"}]

	db_close $rs

	if {$status == "A"} {
		# trigger freebets now
		ob_log::write INFO "_create_action: freebets triggers with: $cust_id $bet_id $stake *${ev_oc_id}*"

		ob_db::begin_tran
		if {[catch {
			if {[OB_freebets::check_action \
						[list BET BET1 SPORTSBET SPORTSBET1]\
						$cust_id\
						""\
						$stake\
						$ev_oc_id\
						"" "" ""\
						$bet_id\
						SPORTS\
						""\
						1] != 1} {
				error "Failed to check action against $bet_id $ev_oc_ids $stake"
			}
			ob_db::commit_tran

		} msg]} {
			error "failed to fulfill freebet triggers, $msg"
			ob_db::rollback_tran
		}

		MONITOR::send_bet \
			$cust_id \
			$username \
			$fname \
			$lname \
			$code \
			$elite \
			$notifyable \
			$country_code \
			$addr_postcode \
			$email \
			$source \
			$bet_id \
			$bet_type \
			[MONITOR::datetime_now] \
			$stake \
			$stake_sys \
			$ccy_code \
			$max_stake_scale \
			$num_selns \
			$category \
			$ev_class_id \
			$class_name \
			$ev_type_id \
			$type_name \
			$ev_id \
			$ev_name \
			$start_time \
			$ev_mkt_id \
			$mkt_name \
			$ev_oc_id \
			$oc_name \
			$prices \
			$leg_type \
			$liab_group \
			$monitored\
			$max_bet_allowed_per_line\
			$max_stake_percentage_used

		#
		# Now for liability alert message
		#

		switch -- $LIAB(status) {
			0 {
				# no action
				# - send a warning?
				if {$LIAB(level) >= 1.0} {
					set LIAB(alert_code) "ALERT"
				} elseif {
					$BET_MONITOR_WARN_THRESHOLD != "" &&
					$LIAB(level) >= $BET_MONITOR_WARN_THRESHOLD
				} {
					if {
						($LIAB(type) == "S" || $LIAB(type) == "M") &&
						[OT_CfgGet BET_LBT_CAUTION_ALERT_ENABLED 0] == 0
					} {
						set LIAB(alert_code) "WARNING"
					} else {
						set LIAB(alert_code) "CAUTION"
					}
				}
			}
			1 -
			2 { }
			3 -
			4 {
				set LIAB(alert_code) "ALERT"
			}
			default {
				OT_LogWrite 3 "_create_action: unknown liability status: $LIAB(status)"
			}
		}

		if {$LIAB(alert_code) == ""} {
			return
		}

		set sql {
			select
				c.ev_class_id,
				c.name class_name,
				t.ev_type_id,
				t.name type_name,
				e.ev_id,
				e.desc event_name,
				m.ev_mkt_id,
				g.name mkt_name,
				s.ev_oc_id,
				s.desc oc_name
			from
				tOBet o,
				tEvOc s,
				tEvMkt m,
				tEvOcGrp g,
				tEv e,
				tEvType t,
				tEvClass c
			where
				o.bet_id = ?
			and o.leg_no = 1
			and o.part_no = 1
			and o.ev_oc_id = s.ev_oc_id
			and m.ev_mkt_id = s.ev_mkt_id
			and m.ev_oc_grp_id = g.ev_oc_grp_id
			and e.ev_id = m.ev_id
			and t.ev_type_id = e.ev_type_id
			and c.ev_class_id = t.ev_class_id
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $bet_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			OT_LogWrite 1 "_create_action: failed to send out monitor alert message - cannot find bet details for bet_id $bet_id"
			db_close $rs
			return
		}

		MONITOR::send_alert\
				[db_get_col $rs 0 ev_class_id]\
				[db_get_col $rs 0 class_name]\
				[db_get_col $rs 0 ev_type_id]\
				[db_get_col $rs 0 type_name]\
				[db_get_col $rs 0 ev_id]\
				[db_get_col $rs 0 event_name]\
				[db_get_col $rs 0 ev_mkt_id]\
				[db_get_col $rs 0 mkt_name]\
				[db_get_col $rs 0 ev_oc_id]\
				[db_get_col $rs 0 oc_name]\
				$LIAB(alert_code) \
				[MONITOR::datetime_now]

		db_close $rs

	}
}

proc ::ADMIN::ASYNC_BET::_get_max_stake_scale {bet_rs} {

	global DB

	# load up the limits array
	catch {unset CUST_DETAILS}

	set cust_id         [db_get_col $bet_rs 0 cust_id]
	set max_stake_scale [db_get_col $bet_rs 0 max_stake_scale]

	set CUST_DETAILS(max_stake_scale) [db_get_col $bet_rs 0 max_stake_scale]
	set CUST_DETAILS(liab_desc)       [db_get_col $bet_rs 0 liab_desc]
	if {[OT_CfgGet ASYNC_BET_USE_ASYNC_INTERCEPT_VALUE N] == "Y"} {
		set CUST_DETAILS(intercept_value) [db_get_col $bet_rs 0 intercept_value]
	} {
		set CUST_DETAILS(intercept_value) ""
	}

	set sql {
		select
			c.level,
			c.id,
			c.max_stake_scale,
			c.liab_group_id,
			l.intercept_value,
			l.liab_desc
		from
			tCustLimit c,
			outer tLiabGroup l
		where
			cust_id = ? and
			c.liab_group_id = l.liab_group_id
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		OT_LogWrite 1 "_get_max_stake_scale: failed to get stake scales for cust_id = $cust_id"
		db_close $rs
		return
	}

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set level            [db_get_col $rs $r level]
		set id               [db_get_col $rs $r id]
		set max_stake_scale  [db_get_col $rs $r max_stake_scale]
		set liab_group_id    [db_get_col $rs $r liab_group_id]
		set liab_desc        [db_get_col $rs $r liab_desc]
		set intercept_value  [db_get_col $rs $r intercept_value]

		if {$max_stake_scale != ""} {
			set CUST_DETAILS(stake_scale,$level,$id) $max_stake_scale
		}

		if {$liab_group_id != ""} {
			set CUST_DETAILS(liab_group,$level,$id)       $liab_group_id
			set CUST_DETAILS(liab_desc,$level,$id)        $liab_desc
                	if {[OT_CfgGet ASYNC_BET_USE_ASYNC_INTERCEPT_VALUE N] == "Y"} {
				set CUST_DETAILS(intercept_value,$level,$id)  $intercept_value
			} else {
				set CUST_DETAILS(intercept_value,$level,$id)  ""
			}
		} else {
			set CUST_DETAILS(liab_group,$level,$id)       ""
			set CUST_DETAILS(liab_desc,$level,$id)        ""
			set CUST_DETAILS(intercept_value,$level,$id)  ""
		}
	}

	db_close $rs

	set cust_iv ""
	set cust_lg ""
	set cust_sf 9999

	# loop through it setting it to the bet
	for {set r 0} {$r < [db_get_nrows $bet_rs]} {incr r} {
		set oc_grp_id  [db_get_col $bet_rs $r ev_oc_grp_id]
		set type_id    [db_get_col $bet_rs $r ev_type_id]
		set class_id   [db_get_col $bet_rs $r ev_class_id]

		# Check for the most specific stake factor
		if {[info exists CUST_DETAILS(stake_scale,EVOCGRP,$oc_grp_id)]} {
			set sf $CUST_DETAILS(stake_scale,EVOCGRP,$oc_grp_id)
			set lg $CUST_DETAILS(liab_desc,EVOCGRP,$oc_grp_id)
		} elseif {[info exists CUST_DETAILS(stake_scale,TYPE,$type_id)]} {
			set sf $CUST_DETAILS(stake_scale,TYPE,$type_id)
			set lg $CUST_DETAILS(liab_desc,TYPE,$type_id)
		} elseif {[info exists CUST_DETAILS(stake_scale,CLASS,$class_id)]} {
			set sf $CUST_DETAILS(stake_scale,CLASS,$class_id)
			set lg $CUST_DETAILS(liab_desc,CLASS,$class_id)
		} else {
			set sf $CUST_DETAILS(max_stake_scale)
			set lg $CUST_DETAILS(liab_desc)
		}

		if {$sf < $cust_sf} {
			set cust_sf $sf
			set cust_lg $lg
		}

		# Check for the most specific intercept value
		if {[OT_CfgGet ASYNC_BET_USE_ASYNC_INTERCEPT_VALUE N] == "Y"} {
			if {[info exists CUST_DETAILS(intercept_value,EVOCGRP,$oc_grp_id)]} {
				set iv $CUST_DETAILS(intercept_value,EVOCGRP,$oc_grp_id)
			} elseif {[info exists CUST_DETAILS(intercept_value,TYPE,$type_id)]} {
				set iv $CUST_DETAILS(intercept_value,TYPE,$type_id)
			} elseif {[info exists CUST_DETAILS(intercept_value,CLASS,$class_id)]} {
				set iv $CUST_DETAILS(intercept_value,CLASS,$class_id)
			} else {
				set iv $CUST_DETAILS(intercept_value)
			}
		} else {
			set iv ""
		}
		if {$iv != "" && $cust_iv != ""} {
			set cust_iv [expr {$iv < $cust_iv ? $iv : $cust_iv}]
		} else {
			set cust_iv [expr {$cust_iv == "" ? $iv : $cust_iv}]
		}
	}

	return [list $cust_sf $cust_lg $cust_iv]

}



# Private procedure to cancel an Asynchronous Bet that has no offer
#
proc ::ADMIN::ASYNC_BET::_cancel_bet {bet_id acct_id reason_text} {
	global DB

	set sql [subst {
		execute procedure pAsyncCancelBet(
		    p_adminuser     = ?,
		    p_bet_id        = ?,
		    p_acct_id       = ?,
		    p_has_offer     = '-',
			p_manual_cancel = 'Y',
			p_reason_text   = ?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt\
				$::USERNAME\
				$bet_id\
				$acct_id\
				$reason_text} msg]} {
		inf_close_stmt $stmt
		error $msg
	}

	inf_close_stmt $stmt
}



# Private procedure to checks whether the admin user has the
# lock for this Asynchronous Bet.
#
proc ::ADMIN::ASYNC_BET::_check_lock {bet_id} {

	if {[catch {set own_lock_res [_have_lock $bet_id]} msg]} {
		error $msg
	}

	set own_lock          [lindex $own_lock_res 0]

	if {!$own_lock} {
		set own_lock_username [lindex $own_lock_res 1]
		error "Sorry, but this action can not be taken. $own_lock_username has the lock on this bet."
	}

}



# Private procedure to checks whether the admin user has the
# lock for this Asynchronous Bet.
#
proc ::ADMIN::ASYNC_BET::_have_lock {bet_id} {

	global DB USERID

	set sql [subst {
		select
			b.lock_user_id,
			NVL(a.username,'') username
		from
			tBetAsync b,
			outer tAdminUser a
		where
			b.lock_user_id = a.user_id
		and bet_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob::log::write ERROR "::ADMIN::ASYNC_BET::_have_lock - Invalid amount of rows returned ($nrows)"
		catch {db_close $rs}
		error "Failed to find Asynchronous bet when checking for the lock owner"
	}

	set lock_user_id [db_get_col $rs 0 lock_user_id]
	set username     [db_get_col $rs 0 username]

	db_close $rs

	set own_lock [expr {$lock_user_id == $USERID ? 1:0 }]

	if {$own_lock || $lock_user_id == {}} {

		return [list 1]
	} else {
		return [list 0 $username]
	}

}



# Decline the pending bet with no offers
#
proc ::ADMIN::ASYNC_BET::_send_multi_rpt {bet_ids} {

	ob_log::write DEV "_send_multi_rpt: $bet_ids"

	global DB ASYNC_MULTI_RPT
	variable VIEW_PREF_COLS

	set ASYNC_MULTI_RPT(RPT_COL_NAMES) [list \
				"Time"                  cr_date\
				"Cust SF"               max_stake_scale\
				"Client Name"           cust_name\
				"Account No."           acct_no\
				"Stake"                 sys_stake\
				"Max bet"               max_bet\
				"Legs"                  num_legs\
				"No. Selns"             num_selns\
				"Perms"                 num_lines\
				"Payout"                sys_pot_payout\
				"Handicap"              hcap_value\
				"Liability Group"       liab_desc\
				"Freebet"               token_value\
				"Currency"              ccy_code]

	if {[llength $bet_ids] > 0} {
		# Querying extra bet information to populate the report
		set sql [subst {
			select
				a.ccy_code,
				a.acct_id,
				b.bet_id,
				b.cr_date,
				b.stake,
				b.bet_type,
				b.stake,
				b.token_value,
				b.stake_per_line,
				b.num_lines,
				b.num_legs,
				b.num_selns,
				NVL(b.potential_payout,'0.00') potential_payout,
				NVL(b.max_bet,'-') max_bet,
				c.max_stake_scale,
				c.acct_no,
				cr.fname,
				cr.lname,
				o.in_running,
				o.price_type,
				o.hcap_value,
				NVL(lg.liab_desc,'-') as liab_desc
			from
				tBet b,
				tOBet o,
				tAcct a,
				tCustomer c,
				tCustomerReg cr,
				outer tLiabGroup lg
			where
				b.bet_id in ([join $bet_ids {,}])
				and o.bet_id = b.bet_id
				and a.acct_id = b.acct_id
				and cr.cust_id = a.cust_id
				and c.cust_id = cr.cust_id
				and lg.liab_group_id = c.liab_group
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]

		# Get/Setup the viewing preferences from a cookie (stored in a cookie)
		_prep_view_pref_cookie

		# Put any information obtains from the query into the 'ASYNC_MULTI_RPT' array
		for {set i 0} {$i < $nrows} {incr i} {

			set bet_id   [db_get_col $rs $i bet_id]

			if {[lsearch $ASYNC_MULTI_RPT(bet_ids) $bet_id] != -1} {

				foreach {col_name db_col_name} $ASYNC_MULTI_RPT(RPT_COL_NAMES) {

					if {$db_col_name == "cust_name"} {
						# Customer name
						set ASYNC_MULTI_RPT($bet_id,cust_name) {}
						set fname [db_get_col $rs $i fname]
						set lname [db_get_col $rs $i lname]

						if {$fname != {}} {
							set ASYNC_MULTI_RPT($bet_id,cust_name) "$fname $lname"
						} else {
							set ASYNC_MULTI_RPT($bet_id,cust_name) $lname
						}
					} elseif {$db_col_name == "sys_stake"} {
						set stake    [db_get_col $rs $i stake]
						set ccy_code [db_get_col $rs $i ccy_code]
						set res_conv [ob_exchange::to_sys_amount $ccy_code $stake]
						if {[lindex $res_conv 0] == "OK"} {
							set ASYNC_MULTI_RPT($bet_id,sys_stake) [lindex $res_conv 1]
						} else {
							set ASYNC_MULTI_RPT($bet_id,sys_stake) $stake
						}
					} elseif {$db_col_name == "sys_pot_payout"} {
						set potential_payout [db_get_col $rs $i potential_payout]
						set ccy_code         [db_get_col $rs $i ccy_code]
						set res_conv         [ob_exchange::to_sys_amount $ccy_code $potential_payout]
						if {[lindex $res_conv 0] == "OK"} {
							set ASYNC_MULTI_RPT($bet_id,sys_pot_payout) [lindex $res_conv 1]
						} else {
							set ASYNC_MULTI_RPT($bet_id,sys_pot_payout) $potential_payout
						}
					} else {
						set ASYNC_MULTI_RPT($bet_id,$db_col_name) [db_get_col $rs $i $db_col_name]
					}
				}

				# Escaping special characters
				set ASYNC_MULTI_RPT($bet_id,cust_name) [escape_javascript $ASYNC_MULTI_RPT($bet_id,cust_name)]
				set ASYNC_MULTI_RPT($bet_id,liab_desc) [escape_javascript $ASYNC_MULTI_RPT($bet_id,liab_desc)]
				set ASYNC_MULTI_RPT($bet_id,info)      [escape_javascript $ASYNC_MULTI_RPT($bet_id,info)]
			}
		}
	}

	# Building the html response from the 'ASYNC_MULTI_RPT' array
	tpBufAddHdr "Content-Type" "text/html"

	if {[tpGetVar isError] == 1} {
		tpBufWrite "<p class=\"error\">[escape_javascript [tpBindGet ErrMsg]]</p>"
	} else {
		if {[llength $bet_ids] == 0} {
				tpBufWrite "<p class=\"info_no\">No action has been taken</p>"
		} else {
			tpBufWrite "<table><tr>"
			foreach {col_name db_col_name} $ASYNC_MULTI_RPT(RPT_COL_NAMES) {
				if {$VIEW_PREF_COLS($db_col_name) == "Y"} {
					tpBufWrite "<th>$col_name</th>"
				}
			}
			tpBufWrite "<th>Result</th>"
			tpBufWrite "<th>Info</th>"
			tpBufWrite "</tr>"
			foreach bet_id $ASYNC_MULTI_RPT(bet_ids) {
				tpBufWrite "<tr>"
				foreach {col_name db_col_name} $ASYNC_MULTI_RPT(RPT_COL_NAMES) {
					if {$VIEW_PREF_COLS($db_col_name) == "Y"} {
						tpBufWrite "<td>$ASYNC_MULTI_RPT($bet_id,$db_col_name)</td>"
					}
				}
				if {$ASYNC_MULTI_RPT($bet_id,result) == 1} {
					tpBufWrite "<td>Succesful</td>"
				} else {
					tpBufWrite "<td>Failed</td>"
				}
				if {$ASYNC_MULTI_RPT($bet_id,info) != ""} {
					tpBufWrite "<td>$ASYNC_MULTI_RPT($bet_id,info)</td>"
				} else {
					tpBufWrite "<td>--</td>"
				}
				tpBufWrite "</tr>"
			}
			tpBufWrite "</table>"
		}
	}
}
