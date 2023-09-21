# ==============================================================
# $Id: stl-void.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
package require util_db

namespace eval ob_settle {
	variable INIT 0
}


#------------------------------------------------------------------------------
# One time initialisation
#------------------------------------------------------------------------------
proc ob_settle::init {} {

	variable INIT

	if {$INIT} {
		ob_log::write WARNING {ob_settle already initalised}
		return
	}

	ob_log::write DEBUG {ob_settle: Initialising...}

	ob_db::init
	_prep_sql

	set INIT 1

}


#------------------------------------------------------------------------------
# Prepare DB queries
#------------------------------------------------------------------------------
proc ob_settle::_prep_sql {} {

	ob_db::store_qry ob_settle::settle_bet {
		execute procedure pSettleBet (
			p_adminuser          = ?,
                        p_op                 = ?,
                        p_bet_id             = ?,
                        p_num_lines_win      = ?,
                        p_num_lines_lose     = ?,
                        p_num_lines_void     = ?,
                        p_winnings           = ?,
                        p_tax                = ?,
                        p_refund             = ?,
                        p_settled_how        = ?,
                        p_settle_info        = ?,
                        p_park_by_winnings   = ?,
                        p_lose_token_value   = ?,
                        p_freebets_enabled   = ?,
                        p_return_freebet     = ?,
                        p_rtn_freebet_can    = ?,
                        p_no_token_on_void   = ?,
                        p_r4_limit           = ?,
                        p_man_bet_in_summary = ?
                )
	}

	ob_db::store_qry ob_settle::settle_leg {
		execute procedure pLEQBetStl (
                	p_bet_type = ?,
                	p_bet_id   = ?
                )
	}

	ob_db::store_qry ob_settle::settle_pool_bet {
		execute procedure pSettlePoolBet (
                        p_adminuser      = ?,
                        p_op             = ?,
                        p_pool_bet_id    = ?,
                        p_num_lines_win  = ?,
                        p_num_lines_lose = ?,
                        p_num_lines_void = ?,
                        p_winnings       = ?,
                        p_refund         = ?,
                        p_settled_how    = ?,
                        p_settle_info    = ?
                )
	}

	ob_db::store_qry ob_settle::settle_xgame_bet {
		execute procedure pSettleXGameBet (
                        p_xgame_bet_id     = ?,
                        p_winnings         = ?,
                        p_refund           = ?,
                        p_paymethod        = ?,
                        p_freebets_enabled = ?,
                        p_op               = ?,
                        p_settle_info      = ?,
                        p_settled_how      = ?,
                        p_settled_by       = ?
                )
	}

	ob_db::store_qry ob_settle::unsettle_bet {
		execute procedure pUnsettleBet (
			p_bet_id = ?,
			p_user_id = ?
		)
	}
	
	ob_db::store_qry ob_settle::get_account_type {
		select
                        a.owner,
                        a.owner_type
                from
                        tBet b,
                        tAcct a
                where
                            b.acct_id = a.acct_id
                	and a.owner = 'F'
	                and a.owner_type in ('STR','VAR','OCC','REG','LOG')
	                and b.bet_id = ?
	}

	ob_db::store_qry ob_settle::get_ticker_details {
		select
			c.cust_id,
			c.acct_no,
			a.ccy_code,
			b.ipaddr,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			e.desc ev_name,
			m.name mkt_name,
			s.desc seln_name,
			s.result,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			b.bet_id,
			o.leg_no,
			o.part_no,
			o.leg_sort,
			o.price_type,
			o.o_num o_num,
			o.o_den o_den
		from
			tBetStlPending p,
			tBet b,
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			outer (
				tOBet o,
				tEvOc s,
				tEvMkt m,
				tEvOcGrp g,
				tEv e
			)
		where
			p.bet_id = ? and
			p.bet_id = b.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id and
			b.bet_id = o.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id
		order by
			b.bet_id desc,
			o.leg_no asc,
			o.part_no asc
	}


}

#
# ----------------------------------------------------------------------------
# Manually settle a bet - the stored procedure does all the work...
# ----------------------------------------------------------------------------
#
proc ob_settle::do_settle_bet {username \
		user_id \
		op_name \
		bet_id \
		bet_type \
		bet_win_lines \
		bet_lose_lines \
		bet_void_lines \
		bet_winnings \
		bet_winnings_tax \
		bet_refund \
		bet_comment } {

	set fn {ob_settle::do_settle_bet: }

	 ob_log::write DEBUG {$fn '$op_name' '$bet_id' '$bet_type' \
		'$bet_win_lines' '$bet_lose_lines' '$bet_void_lines' \
		'$bet_winnings' '$bet_winnings_tax' '$bet_refund $bet_comment'}

	set PARK_ON_WINNINGS_ONLY [OT_CfgGet PARK_ON_WINNINGS_ONLY "0"]
	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	if {[string length $bet_comment] == 0} {
		set bet_comment "<no comment entered>"
	}

	if {$op_name == "StlBet"} {
		set op S
	} elseif {$op_name == "CancelBet"} {
		set op X
	} elseif {$op_name == "CancelSettledBet"} {
		if {![_is_shop_fielding_bet $bet_id]} {
			return [list 1 ""]
		}

		if {[catch {
			ob_db::exec_qry ob_settle::unsettle_bet $bet_id $user_id
		} msg]} {
			ob_log::write ERROR {$fn ERROR executing UnsettleBet stored procedure: $msg}
			return [list 0 $msg]
		}

		set op X
	} else {
		return [list 0 "unknown operation: $op_name"]
	}


	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE" || [OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set freebets_enabled Y
	} else {
		set freebets_enabled N
	}

	ob_log::write DEBUG {$fn freebets_enabled: $freebets_enabled}

	if {[OT_CfgGet RETURN_FREEBETS_VOID "FALSE"] == "TRUE"} {
		set return_freebets_void Y
	} else {
		set return_freebets_void N
	}

	if {[OT_CfgGet RETURN_FREEBETS_CANCEL "FALSE"] == "TRUE"} {
		set return_freebets_cancel Y
	} else {
		set return_freebets_cancel N
	}

	# if we want to reclaim token value from winnings then pass this in
	if {[OT_CfgGet LOSE_FREEBET_TOKEN_VALUE "FALSE"]} {
		set lose_token_value Y
	} else {
		set lose_token_value N
	}

	# If the bet has been voided do we still want to trigger
	# the activation of Freebet tokens (if tOffer.on_settle = 'Y')
	if {[OT_CfgGet FREEBETS_NO_TOKEN_ON_VOID 0]} {
		set no_token_on_void Y
	} else {
		set no_token_on_void N
	}

	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

	ob_log::write INFO {Manually settling bet with bet_id $bet_id}
	ob_log::write INFO "WinLines = $bet_win_lines | LoseLines = $bet_lose_lines] | VoidLines = $bet_void_lines"
	ob_log::write INFO "BetWinnings = $bet_winnings | BetWinningsTax = $bet_winnings_tax | BetRefund = $bet_refund"

	if {[catch {

		set rs [ob_db::exec_qry ob_settle::settle_bet \
			$username \
			$op \
			$bet_id \
			$bet_win_lines \
			$bet_lose_lines \
                        $bet_void_lines \
                        $bet_winnings \
                        $bet_winnings_tax \
                        $bet_refund \
                        M \
                        $bet_comment \
                        $park_limit_on_winnings \
			$lose_token_value \
			$freebets_enabled \
			$return_freebets_void \
			$return_freebets_cancel \
			$no_token_on_void \
			$r4_limit \
			[OT_CfgGet FUNC_SUMMARIZE_MANUAL_BETS N] \
		]

	} msg]} {
		ob_log::write ERROR {$fn ERROR executing pSettleBet: $msg}

		if {$op_name == "CancelSettledBet"} {
			return [list 1 "Bet successfully unsettled."]
		}

		return [list 0 $msg]
	}

	# Get value returned from SP pSettleBet indicating whether it is a parked bet
	set stl_bet_pnd [db_get_coln $rs 0]
	ob_db::rs_close $rs
	
	ob_log::write INFO {Settle bet pending : $stl_bet_pnd}

	if {[OT_CfgGet MONITOR 0] && $stl_bet_pnd == 1} {
		if {[catch {
			set fraud_monitor_detail [send_parked_bet_ticker \
				$bet_id \
				$USERNAME \
				$bet_winnings \
				$bet_refund\
			]
		} msg ]} {

			if {$op_name == "CancelSettledBet"} {
				return [list 1 "Bet successfully unsettled"]
			}

			ob_log::write ERROR {$fn cannot complete fraud check on parked bet - $msg}
			return [list 0 "Cannot complete fraud check on parked bet: $msg"]
		}
	}


	#
	# We may want to queue a message for liabilities
	# (depending on the bet and whether the settlement was successful)
	#

	if { $bet_type != "MAN" && \
		(($bet_type == "SGL" && [OT_CfgGet OFFLINE_LIAB_ENG_SGL 0]) || \
		($bet_type != "SGL" && [OT_CfgGet OFFLINE_LIAB_ENG_RUM 0]))} {

		if {[catch {
			ob_db::exec_qry ob_settle::settle_leg $bet_type $bet_id
		} msg]} {

			if {$op_name == "CancelSettledBet"} {
				return [list 1 "Bet successfully unsettled."]
			}

			ob_log::write ERROR {$fn Failed to queue bet for liabillities: $msg}
			return [list 0 "Failed to queue bet for liabilities :$msg"]
		}

	}

}


#
# ----------------------------------------------------------------------------
# Manually settle a pools bet - the stored procedure does all the work.. I hope
# ----------------------------------------------------------------------------
#

proc ob_settle::do_settle_pools_bet {\
		username \
		op_name \
		bet_id \
		bet_win_lines \
		bet_lose_lines \
		bet_void_lines \
		bet_winnings \
		bet_refund \
		bet_comment} {

	set fn {ob_settle::do_settle_pools_bet: }

	ob_log::write DEBUG {$fn '$op_name' '$bet_id' '$bet_win_lines' \
		'$bet_lose_lines' '$bet_void_lines' '$bet_winnings' '$bet_refund'}

	set PARK_ON_WINNINGS_ONLY [OT_CfgGet PARK_ON_WINNINGS_ONLY "0"]

	if {$PARK_ON_WINNINGS_ONLY} {
		set park_limit_on_winnings "Y"
	} else {
		set park_limit_on_winnings "N"
	}

	if {[string length $bet_comment] == 0} {
		set bet_comment "<no comment entered>"
	}


	if {$op_name == "StlBet"} {
		set op S
	} elseif {$op_name == "CancelBet"} {
		set op X
	} else {
		return [list 0 "unknown operation: $op_name"]
	}


	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE" || [OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set freebets_enabled Y
	} else {
		set freebets_enabled N
	}

	ob_log::write DEBUG {$fn freebets_enabled: $freebets_enabled}

	# if we want to reclaim token value from winnings then pass this in
	if {[OT_CfgGet LOSE_FREEBET_TOKEN_VALUE "FALSE"]} {
		set lose_token_value Y
	} else {
		set lose_token_value N
	}

	if {[catch {
		ob_db::exec_qry ob_settle::settle_pool_bet \
			$username \
			$op \
			$bet_id \
			$bet_win_lines \
			$bet_lose_lines \
			$bet_void_lines \
			$bet_winnings \
			$bet_refund \
			M \
			$bet_comment
	} msg]} {
		ob_log::write ERROR {$fn Failed to settle pools bet - $msg}
		return [list 0 $msg]
	}

	# No errors so carry on
	return [list 1 ""]
}


#
# ----------------------------------------------------------------------------
# Manually settle an xgame bet - the stored procedure does all the work...
# ----------------------------------------------------------------------------
#

proc ob_settle::do_settle_xgame_bet {\
		username \
		user_id \
		bet_id \
		op_name \
		bet_winnings \
		bet_refund \
		bet_comment } {

	set fn {ob_settle::do_settle_xgame_bet: }

	ob_log::write DEBUG {$fn '$username' '$user_id' '$bet_id' '$op_name' \
		'$bet_winnings' '$bet_refund' '$bet_comment'}

	set paymethod "O"

	if {$op_name == "StlBet"} {
		set op S
	} elseif {$op_name == "CancelBet"} {
		set op X
	} else {
		return [list 0 "unknown operation: $op_name"]
	}

	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE" || [OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set freebets_enabled Y
	} else {
		set freebets_enabled N
	}

	if {$bet_winnings == ""} {
		set bet_winnings 0
	}

	if {$bet_refund == ""} {
		set bet_refund 0
	}

	if {[catch {
		ob_db::exec_qry ob_settle::settle_xgame_bet \
			$bet_id \
			$bet_winnings \
			$bet_refund \
			$paymethod \
			$freebets_enabled \
			$op \
			$bet_comment \
			M \
			$user_id	
	} msg]} {
		ob_log::write ERROR {$fn Failed to settle xgame bet}
		return [list 0 $msg]
	}

	# All good.
	return [list 1 ""]
}


proc ob_settle::_is_shop_fielding_bet {bet_id} {

	set fn {ob_settle::_is_shop_fielding_bet}


        if {[catch {
		set rs [inf_exec_stmt $stmt $bet_id]
		set rs [ob_db::exec_qry ob_settle::get_account_type $bet_id]
	} msg]} {
                ob_log::write ERROR {$fn ERROR getting account information: $msg}
                return 0
        }

        if {[db_get_nrows $rs] == 0} {
                ob_db::rs_close $rs
		ob_log::write ERROR {$fn: Bet $bet_id not in database}
                return 0
        }

        set owner      [db_get_col $rs 0 owner]
        set owner_type [db_get_col $rs 0 owner_type]

        ob_db::rs_close $rs

        if {$owner == "F" && [regexp {^(STR|VAR|OCC|REG|LOG)$} $owner_type]} {
                return 1
        } else {
		ob_log::write ERROR {$fn this bet was not placed by a shop fielding account}
                return 0
        }
}


proc ob_settle::send_parked_bet_ticker {bet_id username winnings refund} {

	set fn {ob_settle::send_parked_bet_ticker}

	foreach v {receipt cust_id acct_no cr_date settled bet_type leg_type ccy_code stake cust_uname bet_winnings bet_refund} {
		set $v {}
	}


	if {[catch {
		set rs [ob_db::exec_qry ob_settle::get_ticker_details $bet_id]
	} msg]} {
		ob_log::write ERROR {$fn failed to get ticker information on parked bet (bet_id => $bet_id): $msg}
		return
	}

	set limit [expr {[db_get_nrows $res] - 1}]

	for {set r $limit} {$r >= 0} {incr r -1} {
		# If multiple selections, display repeated fields only once
		if {$r == 0} {
			foreach v {receipt cust_id acct_no cr_date settled bet_type leg_type ccy_code stake} {
				set $v [db_get_col $rs $r $v]
			}
			set cust_uname   $username
			set bet_winnings $winnings
			set bet_refund   $refund
		}

		if {$r == $limit} {
			set bet_type [db_get_col $rs $r bet_type]

			if {$bet_type=="MAN"} {
				set man_bet 1
			} else {
				set man_bet 0
			}

			# Display repeated fields once only
			if {$limit != 0} {
				set bet_type {}
			}
		}

		foreach v {leg_no leg_sort mkt_name seln_name price_type result} {
			set $v [db_get_col $rs $r $v]
		}
		set ev_name [string trim [db_get_col $rs $r ev_name]]

		if {[string first $price_type "LSBN12"] >= 0} {
			set o_num [db_get_col $rs $r o_num]
			set o_den [db_get_col $rs $r o_den]
			if {$o_num=="" || $o_den==""} {
				set p_str [get_price_type_desc $price_type]
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str [get_price_type_desc $price_type]
				}
			}
		} else {
			if {$man_bet} {
				set p_str "MAN"
			} else {
				set p_str "DIV"
			}
		}

		# send details to monitor
		MONITOR::send_parked_bet \
			$receipt \
			$cust_uname \
			$acct_no \
			$cr_date \
			$settled \
			$bet_type \
			$leg_no \
			$leg_type \
			$ccy_code \
			$stake \
			$bet_winnings \
			$bet_refund \
			$leg_sort \
			$ev_name \
			$mkt_name \
			$seln_name \
			$p_str \
			$result

		# Unset the variables for reuse
		unset leg_sort ev_name mkt_name seln_name price_type result o_num o_den p_str

	}
	ob_db::rs_close $rs
}


# Self initialising
ob_settle::init

