################################################################################
# $Id: bet_delay.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Handle Betting-In-Running Bet Delay
# Any bet[s] made against a started BIR market that has a bir_delay, will be held
# in a queue and processed by the bet_delay application (this includes bets that part of
# combination). After 'n' seconds the application will attempt to place the bet.
# The caller must poll the DB every 'n' seconds and wait for bet_delay's outcome.
# Once the outcome is found, caller should display the bet-receipt or overrides.
# The delay will stop any advantage gained at being at the event, or viewing via a
# faster feed, e.g. terrestrial is quicker than satellite, etc.
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
################################################################################

namespace eval ob_bet {
}



#API:bir_get_bet_delay - Get the bet_delay
# Usage
# ::ob_bet::bir_get_bet_delay
#
# Get the bet delay time (seconds).
# If a bet_delay > 0. then all bets will be (or have been) added to the
# bet_delay request queue. these bets will be placed by an external application
# in 'bet_delay' seconds.
#
# The request queue identifier can be gained via ::ob_bet::bir_get_req_id, which
# the caller should use to determine the outcome of the bet_delay application's
# attempt to place the bet[s].
#
# This should only be called after either ::ob_bet::check_bet or ::ob_bet::place_bets
#
# Parameters:
# RETURNS bet_dalay INT
#
proc ::ob_bet::bir_get_bet_delay {} {

	variable BET

	_log DEBUG "API(bir_get_bet_delay)"

	if {[_get_config server_bet_delay] == "N"} {
		return 0
	}

	_smart_reset BET

	if {[info exists BET(bet_delay)]} {
		return $BET(bet_delay)
	}

	return 0
}



#API:bir_get_req_id - Get bet_delay request queue identifier
# Usage
# ::ob_bet::bir_get_req_id
#
# Get the bet_delay request queue identifier.
# The identifier is only set if the bets were added to the bet_delay queue to be placed
# by the bet_delay application server. If no bets were added to the queue, then
# the API will return an empty string.
#
# Place bet will return 0 if queued, therefore, use the API to determine if queued or
# overrides exist. The id should be used by the caller to poll the database to get
# the result of the applications's attempt to place the bets.
#
# This should only be called after either ::ob_bet::check_bet or ::ob_bet::place_bets
#
# Parameters:
# RETURNS bir_req_id INT
#
proc ::ob_bet::bir_get_req_id {} {

	variable BET

	_log DEBUG "API(bir_get_req_id)"

	if {[_get_config server_bet_delay] == "N"} {
		return ""
	}

	_smart_reset BET

	if {[info exists BET(bir_req_id)]} {
		return $BET(bir_req_id)
	}

	return ""
}



#API:bir_redeem_tokens - Redeem tokens used within a bet_delay request.
# Usage
# ::ob_bet::bir_redeem_tokens
#
# Redeem those tokens which were used within a bet_delay request. We update the
# the redeemed flag to Y within the BIRBetToken holding table, so that the bet_delay
# request originator will know which tokens were used within the request.
#
# The API should be called after bet-placement and only by the bet_delay application
# server.
#
# Parameters:
# bir_req_id    FORMAT: INT   DESC:    bet delay request identifier
# in_tran:      FORMAT: O|1   DESC:    should the API start a transaction
#                             DEFAULT: 1 (caller's responsibility)
#
proc ::ob_bet::bir_redeem_tokens { bir_req_id {in_tran 1} } {

	variable BET

	_log INFO "API(bir_redeem_tokens): $bir_req_id $in_tran"

	#          name        value       type  nullable min max
	_check_arg bir_req_id  $bir_req_id INT   0        0
	_check_arg in_tran     $in_tran    INT   0        0   1

	_smart_reset BET

	if {!$in_tran} {
		ob_db::begin_tran
	}

	for {set b 0} {$b < $BET(num)} {incr b} {

		if {![info exists BET($b,redeemed_tokens)]} {
			continue
		}

		foreach {token value} $BET($b,redeemed_tokens) {
			if {[catch {ob_db::exec_qry ob_bet::bir_redeem_token $bir_req_id $token} msg]} {
				if {!$in_tran} {
					ob_db::rollback_tran
				}
				error\
					"Failed to redeem bet delay freebet token $token, $msg"\
					""\
					BIR_REDEEM_TOKEN
			}
		}
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}
}



# END OF API..... private procedures



# Prepare customer queries
#
proc ob_bet::_prepare_bir_qrys {} {

	# redeem tokens used within a bet_delay request
	ob_db::store_qry ob_bet::bir_redeem_token {
		update tBIRBetToken set redeemed = 'Y' where bir_req_id = ? and cust_token_id = ?
	}

	if {[_get_config server_bet_delay] == "N"} {
		return
	}

	# insert a new bet_delay request
	ob_db::store_qry ob_bet::bir_ins_req {
		execute procedure pInsBIRReq(
			p_acct_id        = ?,
			p_ipaddr         = ?,
			p_funds_reserved = ?,
			p_bir_delay      = ?,
			p_topup_pmt_id   = ?
		)
	}

	# insert a bet_delay token
	ob_db::store_qry ob_bet::bir_ins_token {
		insert into tBIRBetToken (
			bir_req_id,
			bir_bet_id,
			cust_token_id,
			redeemed
		) values (
			?, ?, ?, 'N'
		)
	}

	# Get the status of a bir bet request from tBIRReq
	db_store_qry get_bir_req_status {
		select
			r.status,
			r.failure_reason,
			b.bet_id
		from
			tBIRReq r,
			tBIRBet b
		where
			    r.bir_req_id = ?
			AND r.bir_req_id = b.bir_req_id
	}

	# Get the status of a bir bet request from tBIRReq
	db_store_qry get_bir_overrides {
		select
			o.ev_oc_id,
			o.override as leg_override,
			b.override as bet_override,
			b.stake_per_line
		from
			tBIRReq  r,
			tBIRBet  b,
			tBIROBet o
		where
			b.bir_bet_id     = o.bir_bet_id AND
			(r.failure_reason = 'OVERRIDES' OR r.failure_reason = 'TIMEOUT')AND
			r.status         = 'F'          AND
			r.bir_req_id     = b.bir_req_id AND
			r.bir_req_id     = ?
	}

}



# Set a bet delay on a leg
# If leg has a delay, then any bet is placed against it will be added to bet_delay request
# queue.
#
#    leg_no      - leg number
#    bet_delay   - bet/bir delay
#                  if <= 0 then use the default BIR delay
#
proc ::ob_bet::_bir_set_leg_delay { leg_no bet_delay } {

	variable LEG
	variable CUST

	if {[_get_config server_bet_delay] == "N"} {
		return
	}

	if {$bet_delay <= 0 && [_get_config server_bet_def_delay]} {
		set bet_delay [_get_config server_bet_def_delay]
	}

	if {$bet_delay <= 0} {
		return
	}

	if {![info exist LEG($leg_no,bet_delay)] || $bet_delay > $LEG($leg_no,bet_delay)} {

		if {[info exist CUST(cust_id)]} {
			set cust_bir_delay_factor [ob_cflag::get "BIR_DELAY_FACTOR" $CUST(cust_id)]
			if {$cust_bir_delay_factor == ""} {
				set cust_bir_delay_factor 1
			}
		} else {
			set cust_bir_delay_factor 1
		}

		set LEG($leg_no,bet_delay) [expr {$bet_delay * $cust_bir_delay_factor}]

		_log INFO "LEG $leg_no - setting bet_delay $bet_delay"
	}
}



# Set a bet delay on a bet
# If bet has a delay, then bet will be added to the bet_delay request queue.
# NB: All other bets (on placement) will also be added to the queue, regardless if
# they have bet_delay
#
#   bet_id  - bet identifier
#
proc ::ob_bet::_bir_set_bet_delay { bet_id } {

	variable BET
	variable LEG
	variable GROUP

	if {[_get_config server_bet_delay] == "N"} {
		set BET($bet_id,bet_delay) 0
		return
	}

	set group_id $BET($bet_id,group_id)
	set legs $GROUP($group_id,legs)

	set bet_delay [list]
	foreach l $legs {
		if {[info exist LEG($l,bet_delay)]} {
			lappend bet_delay $LEG($l,bet_delay)
		}
	}

	if {[llength $bet_delay]} {
		set BET($bet_id,bet_delay) [lindex [lsort -real $bet_delay] end]
		_log INFO "bet $bet_id setting bet_delay $BET($bet_id,bet_delay)"
	} else {
		set BET($bet_id,bet_delay) 0
	}
}



# Get the maximum bet_delay of all bets to be placed. If > 0, then the bets
# should added to bet_delay request queue, to be placed by an external application
# in 'bet_delay' seconds.
# This call does not take into account if any of the bets are async parked, use
# ::ob_bet::bir_get_bet_delay
#
#   returns - maximum delay, or 0 if no delay
#
proc ::ob_bet::_bir_get_max_bet_delay {} {

	variable BET

	if {[_get_config server_bet_delay] == "N"} {
		return 0
	}

	_smart_reset BET

	set bet_delay [list]
	for {set bet_id 0} {$bet_id < $BET(num)} {incr bet_id} {
		lappend bet_delay $BET($bet_id,bet_delay)
	}

	if {[llength $bet_delay]} {
		return [lindex [lsort -real $bet_delay] end]
	}

	return 0
}



# Private procedure to insert a BIR pending request
#
#   ip_addr         - customer's ip-address
#   funds_reserved  - funds reserved to place the bet[s]
#   topup_pmt_id    - pmt_id from quickdeposit/topup
#
proc ::ob_bet::_bir_ins_req { ip_addr funds_reserved {topup_pmt_id {}} } {

	variable BET
	variable CUST

	_log INFO "**************************************"
	_log INFO "inserting bet delay"
	_log INFO "acct_id    $CUST(acct_id)"
	_log INFO "funds      $funds_reserved"
	_log INFO "bet_delay  $BET(bet_delay)"
	_log INFO "topup_pmt_id $topup_pmt_id"

	set rs [ob_db::exec_qry ob_bet::bir_ins_req $CUST(acct_id) $ip_addr $funds_reserved $BET(bet_delay) $topup_pmt_id]

	set BET(bir_req_id) [db_get_coln $rs 0 0]

	ob_db::rs_close $rs
}



#
# Get the status of a BIR bet.
#
# Args:
#      bir_req_id - reference in tBIRReq
#
# Return:
#     [list {status} ?{failure reason}? ?{bet ids}?]
#
#     Will only return failure reason on status F
#     Will only return bet ids on status A
#     Will return nothing else on status P. This indicates
#          the bet is still yet to be processed by the
#          bet_delay app.
#
proc ::ob_bet::get_bir_req_status {{bir_req_id ""}} {

	# Get the current status of a bir bet in the bet delay queue
	if {[catch {set rs [db_exec_qry get_bir_req_status $bir_req_id]} msg]} {
		return [list 0 "DB_ERROR"]
	} else {
		if {[db_get_nrows $rs] == 0} {
			# return P to force client to have another go.
			return "P"
		} else {
			# There will only be one set of these per bir_req_id
			set status         [db_get_col $rs 0 status]
			set failure_reason [db_get_col $rs 0 failure_reason]
			set bet_ids        [list]

			if {$status == "A"} {
				for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
					lappend bet_ids [db_get_col $rs $i bet_id]
				}
			}

			set ret [list $status $failure_reason $bet_ids]

			ob_log::write INFO {BIR REQ return = $ret from [db_get_nrows $rs] rows}
			return $ret
		}
	}
}


#
# Take a BIR bet with OVERRIDES and build the betslip alerts
#
#  the legArrayName upvars to the LEG array in the calling app.
#
# Returns:
#  list of overrides in the same form as if built during non BIR bet placement
#
proc ::ob_bet::parse_bir_overrides {legArrayName bir_req_id} {

	upvar 1 $legArrayName LEG

	variable BIR_OVERRIDES

	# Get the information from the BIR tables regarding the overrides
	if {[catch {set rs [db_exec_qry get_bir_overrides $bir_req_id]} msg]} {
		return [list 0 "DB_ERROR"]
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set BIR_OVERRIDES($i,ev_oc_id)       [db_get_col $rs $i ev_oc_id]
		set BIR_OVERRIDES($i,bet_override)   [db_get_col $rs $i bet_override]
		set BIR_OVERRIDES($i,leg_override)   [db_get_col $rs $i leg_override]
		set BIR_OVERRIDES($i,stake_per_line) [db_get_col $rs $i stake_per_line]

		if {$BIR_OVERRIDES($i,bet_override) != ""} {
			set BIR_OVERRIDES($i,type) BET
		} else {
			set BIR_OVERRIDES($i,type) LEG
		}

		foreach leg_num $LEG(legs) {
			if {$LEG($leg_num,selns) == $BIR_OVERRIDES($i,ev_oc_id)} {
				set BIR_OVERRIDES($i,leg_idx) $leg_num
			}
		}
	}

	set BIR_OVERRIDES(num_overrides) $i

	set overrides [list]

	# Now make the overrides string
	for {set i 0} {$i < $BIR_OVERRIDES(num_overrides)} {incr i} {
		set type $BIR_OVERRIDES($i,type)

		if {$type == "LEG"} {
			set idx  $BIR_OVERRIDES($i,leg_idx)
			set override [split $BIR_OVERRIDES($i,leg_override) "|"]
			set code     [lindex $override 0]

			switch $code {
				PRC_CHG {
					set ob_bet::LEG($idx,lp_num)          [lindex $override 1]
					set ob_bet::LEG($idx,lp_den)          [lindex $override 2]
					set ob_bet::LEG($idx,expected_lp_num) [lindex $override 3]
					set ob_bet::LEG($idx,expected_lp_den) [lindex $override 4]
				}

				HCAP_CHG {
					# current hcap + new hcap
					set ob_bet::LEG($idx,hcap_value)          [lindex $override 1]
					set ob_bet::LEG($idx,expected_hcap_value) [lindex $override 2]
				}

				BIR_CHG {
					# current bir + new bir
					set ob_bet::LEG($idx,bir_index)          [lindex $override 1]
					set ob_bet::LEG($idx,expected_bir_index) [lindex $override 2]
				}

				EW_PLC_CHG {
					# current E/W place + new place
					set ob_bet::LEG($idx,ew_places)          [lindex $override 1]
					set ob_bet::LEG($idx,expected_ew_places) [lindex $override 2]
				}

				EW_PRC_CHG {
					# current E/W price + new price
					set ob_bet::LEG($idx,ew_fac_num)          [lindex $override 1]
					set ob_bet::LEG($idx,ew_fac_den)          [lindex $override 2]
					set ob_bet::LEG($idx,expected_ew_fac_num) [lindex $override 3]
					set ob_bet::LEG($idx,expected_ew_fac_den) [lindex $override 4]
				}

				default {
				}
			}

		} else {
			set override [split $BIR_OVERRIDES($i,bet_override) "|"]
			set code     [lindex $override 0]
			set idx      0
		}

		lappend overrides [list $type $idx $code]
	}

	ob_log::write INFO {::ob_bet::parse_bir_overrides overrides = $overrides}

	return $overrides

}

