# $Id: fulfill.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# Copyright (c) 2008 Orbis Technology Ltd. All rights reserved.
#
# Faster, shinier (but somewhat limited) version of Freebets fulfilment code
# Used for the check_action_fast
#
#
#
#

namespace eval ob_fbets {

}



proc ::ob_fbets::_fulfill_trigger {offer_id trigger_id cust_id rank value} {

	global TRIGGER_FULFILLED

	ob_log::write INFO {[info level 0]}

	# create a called trigger for this customer
	#
	ob_db::exec_qry ob_fbets::call_trigger $offer_id  $trigger_id  $cust_id $rank $value

	set TRIGGER_FULFILLED 1
}



proc ::ob_fbets::_claim_offer {cust_id offer_id bet_id bet_type value trigger_id redeem_list} {

	ob_log::write INFO {_claim_offer cust_id     = $cust_id      }
	ob_log::write INFO {_claim_offer offer_id    = $offer_id     }
	ob_log::write INFO {_claim_offer bet_id      = $bet_id       }
	ob_log::write INFO {_claim_offer bet_type    = $bet_type     }
	ob_log::write INFO {_claim_offer value       = $value        }
	ob_log::write INFO {_claim_offer trigger_id  = $trigger_id   }
	ob_log::write INFO {_claim_offer redeem_list = $redeem_list  }

	variable OFFERS
	variable TRIGGER

	ob_db::exec_qry ob_fbets::claim_offer $offer_id $cust_id
	ob_db::exec_qry ob_fbets::claim_called_triggers $offer_id $cust_id


	# Create tokens for customer, though this needs to be done differently
	# for (pre-redeemed) matched bet tokens.
	#
	set is_matched_bet  0
	set has_matched_bet 0
	set redeemed_ids    [list]
	array set Redeemed_vals [array unset Redeemed_vals]

	foreach item $redeem_list {
		if {[llength $item] < 4} {
			ob_log::write ERROR {can't parse $item as a redeemed item (fewer than 4 items}
			continue
		}
		set val [lindex $item 1]
		set id  [lindex $item 3]
		lappend redeemed_ids $id
		set Redeemed_vals($id) $val

		if {$id < 0} {
			set has_matched_bet 1
		}
	}

	set minus_offer_id [expr {$offer_id * -1}]
	if {[lsearch $redeemed_ids $minus_offer_id] != -1} {
		set is_matched_bet 1
	} elseif {$has_matched_bet} {
		# Claiming another offer triggered by a bet which contains at least one
		# Matchedbet offer(s). Here we need to adjust the stake to its original
		# values
		foreach id $redeemed_ids {
			if {$id < 0} {
				set value [expr {$value - $Redeemed_vals($id)}]
			}
		}
	}

	if [catch {set rs [ob_db::exec_qry ob_fbets::create_cust_token \
				$offer_id \
				$cust_id \
				$bet_id \
				$bet_type \
				]} msg] {
		ob_log::write DEBUG {Could not create customer tokens for offer $offer_id: $msg}
		return 0
	}

	ob_db::rs_close
	# Send completion message
	if [catch {set rs [ob_db::exec_qry ob_fbets::check_offer_completion_msg \
						   $offer_id]} msg] {
		ob_log::write DEBUG {Could not retrieve offer completion message for offer $offer_id: $msg}
		return 0
	} elseif {[set completion_msg_id [db_get_coln $rs 0]] != ""} {
		ob_db::rs_close $rs
		if [catch {set rs [ob_db::exec_qry ob_fbets::insert_offer_completion_msg_for_cust \
				$completion_msg_id \
				$cust_id]} msg] {
			ob_log::write DEBUG {Could not insert offer completion message id: $completion_msg_id into the queue of customer $cust_id : $msg}
			return 0
		}
 		ob_db::rs_close $rs
	}
}

#
# Check if the offer has a referee
#
# TODO: this proc should not call any of the old freebet code or stored proc
# once we can handle the REFERRAL trigger with the new code.
#
proc ::ob_fbets::_check_offer_referral {cust_id offer_id} {

	variable ACTION

	if [catch {set rs [ob_db::exec_qry ob_fbets::check_for_referee $offer_id]} msg] {
		ob_log::write DEBUG {Could not check for referee triggers for offer $offer_id: $msg}
		return 0
	}

	set nrows [db_get_nrows $rs]
	db_close $rs

	if {$nrows == 0} {
		# no referral, quit
		return 0
	}

	# we have a referee trigger on the offer
	ob_log::write DEBUG {Referee trigger on the offer so claim matching referral offer....}

	# need to retrieve the cust_id and aff_id of the user who referred this customer
	if [catch {set rs [ob_db::exec_qry ob_fbets::get_referral_cust $cust_id ]} msg] {
		ob_log::write DEBUG {Could not get referral cust_id for user $user_id: $msg}
		return 0
	}

	set ref_user_id [db_get_col $rs flag_value]
	db_close $rs

	if {$ref_user_id == ""} {
		ob_log::write INFO {No referral cust id could be retrieved. aborting referral claim attempt...}
		return 0
	}

	if [catch {set rs [ob_db::exec_qry ob_fbets::get_referral_aff $ref_user_id ]} msg] {
		ob_log::write INFO {Could not get referral aff for user $ref_user_id: $msg}
		return 0
	}

	set ref_aff_id [db_get_col $rs aff_id]
	db_close $rs


	if [catch {set rs [ob_db::exec_qry ob_fbets::get_referral_offer $offer_id ]} msg] {
		ob_log::write INFO {Could not get referral offer for offer $offer_id: $msg}
		return 0
	}

	set ref_offer_id   [db_get_col $rs offer_id]
	set ref_trigger_id [db_get_col $rs trigger_id]
	db_close $rs

	if {$ref_offer_id == "" || $ref_trigger_id != ""} {
		ob_log::write INFO {Problem with ref_offer_id=$ref_offer_id or ref_trigger_id=$ref_trigger_id being null}
		return 0
	}

	# check the max claims for the offer of which the referral trigger is a part
	if [catch {set rs [ob_db::exec_qry ob_fbets::get_max_claims $ref_offer_id]} msg] {
		ob_log::write INFO {Could not get max claims for offer with referral trigger $ref_trigger_id: $msg}
		return 0
	}
	set referral_max_claims [db_get_col $rs max_claims]
	db_close $rs

	# now get the number of times this user
	if [catch {set rs [ob_db::exec_qry ob_fbets::num_referral_claims $ref_offer_id $ref_user_id]} msg] {
		ob_log::write INFO {Could not get max claims for offer with referral trigger $ref_trigger_id: $msg}
		return 0
	}

	set num_referral_claims [db_get_col $rs count]
	db_close $rs

	# check if referrer hasnt claimed referral offer too many times
	ob_log::write DEBUG "num_referral_claims = $num_referral_claims | referral_max_claims = $referral_max_claims"

	if {$num_referral_claims < $referral_max_claims} {
		set action_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		set ret [OB_freebets::get_check_action_data "REFERRAL" $ref_user_id $ACTION(channel) $action_date 0]
		if {$ret == 0} {
			return 0
		}

		# now try and try to claim the referral offer for this other user
		if {[OB_freebets::check_trigger $ref_user_id "REFERRAL" $ref_trigger_id $ref_aff_id 0 -1 "" "" "" $ACTION(channel)]} {
			# Fulfill trigger, and claim offer
			if {! [OB_freebets::fulfill_trigger $ref_trigger_id $ref_offer_id $ref_user_id "" "" "" $action_date 0 $ACTION(channel)]} {
				ob_log::write INFO {Action did not fulfill referral trigger $ref_trigger_id}
			}
			ob_log::write INFO {Referral Trigger ID: $ref_trigger_id fulfilled}
		}
	}

}


#
#
proc ::ob_fbets::_prepare_fulfill_queries {} {

	ob_db::store_qry ob_fbets::call_trigger {
		execute procedure pInsCalledTrigger (
			p_offer_id = ?,
			p_trigger_id = ?,
			p_cust_id = ?,
			p_rank = ?,
			p_called_date = CURRENT,
			p_value = ?
		)
	}

	ob_db::store_qry ob_fbets::claim_offer {
		execute procedure pInsClaimedOffer (
			p_offer_id     = ?,
			p_cust_id      = ?,
			p_claim_date   = CURRENT
		)
	}

	ob_db::store_qry ob_fbets::claim_called_triggers {
		execute procedure pClmCalledTriggers (
			p_offer_id     = ?,
			p_cust_id      = ?
		)
	}

	ob_db::store_qry ob_fbets::get_bet_stake {
		select
			stake
		from
			tBet
		where
			bet_id = ?
	}

	ob_db::store_qry ob_fbets::get_cust_tokens_for_offer {
		select
			ct.cust_token_id,
			ct.value,
			ct.avg_stk_fb_counter,
			nvl(ta.amount_max,0) as amount_max
		from
			tCustomerToken ct,
			tToken t,
			tAcct a,
			outer tTokenAmount ta
		where
			ct.token_id           = t.token_id
		and ct.cust_id            = ?
		and t.offer_id            = ?
		and ct.status             = ?
		and ct.avg_stk_fb_counter < ?
		and a.cust_id             = ct.cust_id
		and a.ccy_code            = ta.ccy_code
		and ta.token_id           = t.token_id
	}

	ob_db::store_qry ob_fbets::update_cust_token {
		execute procedure pUpdCustomerToken (
			p_cust_token_id      = ?,
			p_status             = ?,
			p_value              = ?,
			p_avg_stk_fb_counter = ?,
			p_update_interval    = ?
		)
	}

	ob_db::store_qry ob_fbets::create_cust_token {
		execute procedure pCreateCustTokens (
			p_claimed_offer = ?,
			p_cust_id       = ?,
			p_ref_id        = ?,
			p_ref_type      = ?
			);
	}

	ob_db::store_qry ob_fbets::check_for_referee {
		select
			type_code
		from
			ttrigger
		where
			offer_id = ? and
			type_code = 'REFEREE'
	}

	ob_db::store_qry ob_fbets::get_referral_cust {
		select
			flag_value
		from
			tcustomerflag
		where
			cust_id = ? and
			flag_name = 'REF_CUST_ID'
	}

	ob_db::store_qry ob_fbets::get_referral_aff {
		select
			aff_id
		from
			tcustomer
		where
			cust_id =?
	}

	ob_db::store_qry ob_fbets::get_referral_offer {
		select
			offer_id,
			trigger_id
		from
			ttrigger
		where
			type_code = 'REFERRAL' and
			offer_id in (
				select
					ref_offer_id
				from
					ttrigger
				where
					type_code = 'REFEREE' and
					offer_id = ?
				)
	}

	ob_db::store_qry ob_fbets::get_max_claims {
		select
			o.max_claims
		from
			toffer o
		where
			o.offer_id = ?
	}

	ob_db::store_qry ob_fbets::num_referral_claims {
		select
			count(claimed_offer_id) as count
		from
			tclaimedoffer
		where
			offer_id = ?
		and
			cust_id = ?
	}

	# check the existence of a completion message in an offer
	ob_db::store_qry ob_fbets::check_offer_completion_msg {
		select
			o.completion_msg_id
		from
			tOffer o
		where
			o.offer_id = ?
	} 300

		# insert the completion message in the customer's message queue
	ob_db::store_qry ob_fbets:insert_offer_completion_msg_for_cust {
		insert into tCMMsgCust (
			msg_id,
			cust_id
		) values (
			?,
			?
		)
	} 300


}
