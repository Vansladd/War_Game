# $Id: check.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# Copyright (c) 2008 Orbis Technology Ltd. All rights reserved.
# Faster, shinier (but somewhat limited) version of Freebets.
# Used for the check_action_fast
#
# Procedures:
#   ob_fbets::init
#   ob_fbets::check_action_fast
#


namespace eval ob_fbets {
}

if {[OT_CfgGet ENABLE_FOG 0]} {
	package require games_gpm_triggers
	ob::games::triggers::init
}


#
# This proc receive the same number of values and in the same order as the classic
# check_action_http proc and so we can have one line of code to call the old style
# and new check action http.
#
proc ::ob_fbets::check_action_http_fast {xml_msg} {

	global CHANNEL

	ob_log::write INFO {::ob_fbets::check_action_http_fast}

	#Parse the xml message.
	set check_actions [OB_freebets::parse_check_action_xml $xml_msg]

	set action_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	foreach check_action $check_actions {
		foreach {action_list user_id aff_id value evocs sort vch_type vch_trigger_id ref_id ref_type source promo_code} $check_action {}
		# Start the transaction
		ob_db::begin_tran

		ob_log::write INFO  {go_check_action_fast called with: $action_list, $user_id, $aff_id, $value, $evocs, $sort, $vch_type, $vch_trigger_id, $ref_id, $ref_type, $action_date, $source, $promo_code}

		# Check the action.

		set ret_value [::ob_fbets::check_action_fast \
				-cust_id       $user_id \
				-channel       $source \
				-lang          "" \
				-ccy_code      "" \
				-aff_id        $aff_id \
				-country_code  "" \
				-actions       $action_list \
				-value         $value \
				-bet_id        $ref_id \
				-bet_type      $ref_type \
				-promo_code    $promo_code \
				-ev_oc_ids     $evocs ]

		ob_log::write INFO { check_action_http_fast ret_value: $ret_value }

		# End the transaction
		if {$ret_value == 0} {
			ob_db::rollback_tran
		} else {
			ob_db::commit_tran
		}
	}
}

#
# This proc collects the information from FBDATA array which is populated
# from bet packages or placebet2.tcl. It formats information and sends it
# to the check_action_fast proc
#
# This proc receive the same number of values and in the same order as the classic
# check_action proc and so we can have one line of code to call the old style
# and new check action.
#
proc ::ob_fbets::go_check_action_fast {
	  action
	  user_id
	{ aff_id          0 }
	{ value           0 }
	{ evocs          "" }
	{ sort           "" }
	{ vch_type       "" }
	{ vch_trigger_id "" }
	{ ref_id         "" }
	{ ref_type       "" }
	{ promo_code     "" }
	{ in_db_trans     0 }
	{ source         "" }
} {
	global CHANNEL
	global FBDATA

	set ev_mkt_ids   [list]
	set ev_ids       [list]
	set ev_type_ids  [list]
	set ev_class_ids [list]
	set selns        [list]

	if {[string length $source]} {
		set channel $source
	} else {
		if {![info exists CHANNEL]} {
			set channel [OT_CfgGet CHANNEL I]
	} else {
			set channel $CHANNEL
		}
	}

	ob_log::write INFO {go_check_action_fast - ref_type = $ref_type}

	foreach seln $evocs {
		lappend ev_mkt_ids    $FBDATA($seln,ev_mkt_id)
		lappend ev_ids        $FBDATA($seln,ev_id)
		lappend ev_type_ids   $FBDATA($seln,ev_type_id)
		lappend ev_class_ids  $FBDATA($seln,ev_class_id)
	}

	ob_log::write INFO {go_check_action_fast - evocs       = $evocs}
	ob_log::write INFO {                     - ev_mkt_ids  = $ev_mkt_ids}
	ob_log::write INFO {                     - ev_id       = $ev_ids }
	ob_log::write INFO {                     - ev_type_id  = $ev_type_ids}
	ob_log::write INFO {                     - ev_class_id = $ev_class_ids}

	if {[catch {
		set result [::ob_fbets::check_action_fast \
			-cust_id       $user_id \
			-channel       $channel \
			-lang          $FBDATA(lang) \
			-ccy_code      $FBDATA(ccy_code) \
			-aff_id        $aff_id \
			-country_code  $FBDATA(country_code) \
			-actions       $action \
			-value         $value \
			-bet_id        $ref_id \
			-bet_type      $ref_type \
			-promo_code    $promo_code \
			-ev_oc_ids     $evocs \
			-ev_mkt_ids    $ev_mkt_ids \
			-ev_ids        $ev_ids \
			-ev_type_ids   $ev_type_ids \
			-ev_class_ids  $ev_class_ids
		]
	} msg]} {
		ob_log::write ERROR {::ob_fbets::go_check_action_fast Error checking action: $msg $::errorInfo}
	}

	return 1
}



#
# This very similar to the classic redeem_promo do, however,
# it uses the check_action_fast function
#
proc ::ob_fbets::redeem_promo_fast {cust_id promo_code} {

	global   FBDATA
	global   TRIGGER_FULFILLED

	set aff_id [get_cookie [OT_CfgGet AFF_ID_COOKIE AFF_ID]]

	if {[::ob_fbets::go_check_action_fast PROMO $cust_id $aff_id "" "" "" "" "" "" "" \
		$promo_code ""] != 1} {
		ob_log::write ERROR "Check_action PROMO failed. Cust_id: ${cust_id}. Promo_code: ${promo_code}"
		return 0
	}
	if {!$TRIGGER_FULFILLED} {
		ob_log::write INFO "Promo code: ${promo_code} NOT triggered"
		return 0
	}

	ob_log::write INFO "Promo code: ${promo_code} triggered"
	return 1
}



# Check if an action calls any triggers in any offers, marking those triggers
# as called in the DB and claiming any offers as appropriate.
#
# Optimised for maximum performance when used at sports bet placement.
#
# Usage:
#  ob_fbets::check_action_fast -option1 -value1 .. -optionN -valueN
#  where options are:
#
#  Core options:
#     -cust_id        The customer performing the action.
#     -channel        The channel on which the action occurred.
#     -actions        List of actions; will be a subset of:
#                       BET
#                       BET1
#                       SPORTSBET
#                       SPORTSBET1
#                       FBET
#						DEP
#						DEP1
#						REG
#						PROMO
#						BUYMGETN
#						FIRSTGAME
#						GAMESSPEND
#
# Customer options :
#     -lang           The customer's registration language.
#     -ccy_code       The customer's account currency.
#     -reg_aff_id     The customer's registration affiliate.
#     -country_code   The customer's registration country.
#
#  Affiliate options:
#     -aff_id         Affiliate (defaults to none if not supplied).
#     -aff_grp_id     Affiliate Group (will be looked up in DB if
#                     the Affiliate is supplied but this is not).
#
#  Options mandatory for actions involving money (e.g. bet stake, deposit):
#     -value          Total amount in customer's account currency.
#
#  Options mandatory for all bet actions:
#     -bet_type       Always SPORTS for now.
#     -bet_id         tBet.bet_id for a SPORTS bet_type.
#
#  Options mandatory for all sports bet actions:
#     -ev_oc_ids      Selections in the bet.
#     -ev_mkt_ids     Markets from which the selections are drawn.
#     -ev_ids         Events from which the selections are drawn.
#     -ev_type_ids    Types from which the selections are drawn.
#     -ev_class_ids   Classes from which the selections are drawn.
#
# Other options:
#     -log_only       Don't actually change anything in the DB; just
#                     go through the motions.
#     -redeem_list    Used for pre-redeemed matched bet tokens
#
# Returns {0 <debug_info>} if no triggers were called,
#      or {1 <debug_info>} otherwise.
#
# Notes:
#
#
#   * The following actions are *not* (yet) supported; use the classic
#     freebets check_action for these actions:
#
#       REFERRAL
#       REFEREE
#       ADHOC
#       VOUCHER
#       EXTSTAKE
#       EXTSTAKE1
#       XGAMEBET
#       XGAMEBET1
#
#    * Do NOT interleave calls to this check_action_fast proc and the classic
#      check_action in the same request; that may break caching assumptions.
#
proc ::ob_fbets::check_action_fast args {

	variable OFFER
	variable ACTION
	variable CLAIMS
	variable CUST_OFFER
	variable TRIGGER
	variable PROMO
	global TRIGGER_FULFILLED

	# log the procedure call
	ob_log::write INFO {[info level 0]}

	# Populate the ACTION array
	array set ACTION [array unset ACTION]
	set good_opts [list \
		-cust_id \
		-actions \
		-channel \
		-lang \
		-ccy_code \
		-reg_aff_id \
		-country_code \
		-aff_id \
		-aff_grp_id \
		-value \
		-bet_type \
		-bet_id \
		-ev_oc_ids \
		-ev_mkt_ids \
		-ev_ids \
		-ev_type_ids \
		-ev_class_ids \
		-redeem_list \
		-promo_code \
		-log_only \
	]
	set need_opts [list cust_id actions channel lang ccy_code aff_id country_code]
	if {[llength $args]%2} {
		error "Usage: [lindex [info level 0] 0] -opt1 val1 ... -optN valN"
	}
	foreach {opt val} $args {
		if {[lsearch -exact $good_opts $opt] == -1} {
			error "Bad option \"$opt\"; must be one of [join $good_opts {, }]"
		}
		set ACTION([string range $opt 1 end]) $val
	}
	foreach opt $need_opts {
		if {![info exists ACTION($opt)]} {
			error "Option \"-$opt\" must be specified."
		}
	}

	# Look up any extra information we need (or set it to defaults).
	#
	if {! [info exists ACTION(reg_aff_id)]} {
		set ACTION(reg_aff_id)     0
		set ACTION(reg_aff_grp_id) ""
	} else {
		set rs [ob_db::exec_qry ob_fbets::get_aff_grp_id_for_aff $ACTION(reg_aff_id)]
		if {[db_get_nrows $rs]} {
			set ACTION(reg_aff_grp_id) [db_get_col $rs 0 aff_grp_id]
		} else {
			set ACTION(reg_aff_grp_id) ""
		}
		ob_db::rs_close $rs
	}

	if {! [info exists ACTION(aff_id)] } {
		set ACTION(aff_id)       0
		set ACTION(aff_grp_id)   ""
	} else {
		if { ![info exists ACTION(aff_grp_id)] } {
			set rs [ob_db::exec_qry  ob_fbets::get_aff_grp_id_for_aff $ACTION(aff_id)]
			if {[db_get_nrows $rs]} {
				set ACTION(aff_grp_id) [db_get_col $rs 0 aff_grp_id]
			} else {
				set ACTION(aff_grp_id) ""
			}
			ob_db::rs_close $rs
		}
	}

	# In the cases where the data was not not supplied, retreive it
	if { $ACTION(lang)         == "" &&
	     $ACTION(country_code) == "" &&
	     $ACTION(ccy_code)     == "" } {
		set rs [ob_db::exec_qry  ob_fbets::get_cust_info $ACTION(cust_id)]
		if {[db_get_nrows $rs]} {
			set ACTION(lang)         [db_get_col $rs 0 lang]
			set ACTION(country_code) [db_get_col $rs 0 country_code]
			set ACTION(ccy_code)     [db_get_col $rs 0 ccy_code]
		} else {
			ob_log::write ERROR {Error in retreiving customer $ACTION(cust_id) data}
		}
		ob_db::rs_close $rs
	}

	if {! [info exists ACTION(redeem_list)]} {
		set ACTION(redeem_list) [list]
	}

	if {! [info exists ACTION(log_only)]} {
		set ACTION(log_only) 0
	}

	if {! [info exists ACTION(bet_id)]} {
		set ACTION(bet_id) ""
	}

	if {! [info exists ACTION(bet_type)]} {
		set ACTION(bet_type) ""
	}

	if {! [info exists ACTION(value)]} {
		set ACTION(value) ""
	}

	# make sure that the offers array is populated (see cache.tcl)
	#
	_upd_active_offers

	# Do a brief first pass check (only check against the values in memory)
	#
	ob_log::write INFO {checking [llength $OFFER(offer_ids)] offers (first pass)}
	set offer_ids [list]

	set TRIGGER_FULFILLED 0
	set TRIGGER_OFFERS(triggers_list) [list]

	foreach offer_id $OFFER(offer_ids) {

		if { $ACTION(actions) == "PROMO" &&  \
			![info exists PROMO($ACTION(promo_code),$offer_id)] } {
			ob_log::write DEBUG {PROMO is not available for offer id $offer_id}
		} elseif {[_check_offer_first_pass $offer_id]} {
			lappend offer_ids $offer_id
		}
	}

	if {[llength $offer_ids] == 0} {
		ob_log::write INFO {No offers remain after global check}
		return [list 0 GLOBAL]
	}
	ob_log::write DEBUG {offers ids that passed the global check: $offer_ids}

	# make sure that the claims array is populated (see cache.tcl)
	#
	_upd_cust_claimed_offers $ACTION(cust_id)

	# Of the remaining offers, rule out the ones that the customer has already claimed
	#
	set unclaimed_offer_ids [list]
	ob_log::write INFO {[llength $offer_ids] remain after first pass}
	foreach offer_id $offer_ids {
		if {! [_has_claimed $ACTION(cust_id) $offer_id]} {
			lappend unclaimed_offer_ids $offer_id
		}
	}
	if {[llength $unclaimed_offer_ids] == 0} {
		ob_log::write INFO {No offers remain after claims check}
		return [list 0 [list CLAIMS $offer_ids]]
	}
	ob_log::write INFO {unclaimed_offer_ids= $unclaimed_offer_ids remain after claims check}

	# make sure that all called triggers array is populated
	#
	_upd_cust_called_triggers $ACTION(cust_id)

	# Now do a final pass over the offers, actually calling triggers and
	# claiming offers as appropriate
	#
	set any_offers_claimed 0
	set any_triggers_called 0

	set CLAIMS(claimed_offers) [list]

	foreach offer_id $unclaimed_offer_ids {
		set ret [_check_offer_final_pass $offer_id]
		if {[llength $ret] != 2} {
			ob_log::write ERROR {Invalid response for $offer_id: $ret}
			continue
		}

		set offer_claimed   [lindex $ret 0]
		set trigger_called  [lindex $ret 1]

		if {$offer_claimed} {
			set any_offers_claimed 1

			lappend CLAIMS(claimed_offers) $offer_id

			if {[OT_CfgGet ENABLE_FREEBET_REFERRALS "FALSE"] == "TRUE"} {
				# Check if offer claimed was a referee offer as this will fire a trigger for referee
				_check_offer_referral $ACTION(cust_id) $offer_id
			}
		}
		if {$any_triggers_called} {
			set any_triggers_called 1
		}
	}

	if {$any_offers_claimed} {

		set action_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		for {set j 0} {$j < [llength $CLAIMS(claimed_offers)]} {incr j} {
			set offer_id [lindex $CLAIMS(claimed_offers) $j]

			ob_log::write DEBUG {Getting possible chained offers for claimed offer_id = $offer_id}

			if [catch {set otrs [ob_db::exec_qry ob_fbets::find_offer_triggers_for_offer \
						$offer_id \
						$action_date \
						$action_date \
						$ACTION(cust_id)]} msg] {
				ob_log::write ERROR {Could not get offer triggers: $msg}
				return 0
			}

			set otnrows [db_get_nrows $otrs]

			ob_log::write DEBUG {otnrows = $otnrows}

			for {set i 0} {$i < $otnrows} {incr i} {

				set o_offer_id   [db_get_col $otrs $i offer_id]
				set o_trigger_id [db_get_col $otrs $i trigger_id]

				ob_log::write DEBUG {Attempting to fulfill o_trigger_id ($o_trigger_id) , o_offer_id ($o_offer_id)}

				if {[lsearch -exact $CUST_OFFER(offer_ids) $o_offer_id] == -1} {
					ob_log::write DEBUG {Cannot process offer $o_offer_id: Expired, not available in this customer list $CUST_OFFER(offer_ids)}
					continue
				}

				_fulfill_trigger $o_offer_id $o_trigger_id $ACTION(cust_id) $TRIGGER($o_trigger_id,rank) $ACTION(value)

				# Keep track of this in case we have multiple check_action_fast
				# in the same request, the DB values in CALLED are cached.
				if { ![info exists CALLED(called_trigger_ids,$o_trigger_id)] } {
					lappend CALLED(called_trigger_ids,$o_trigger_id) "FULFILLED"
					set CALLED(FULFILLED,stage) 0
				}
			}

			catch {ob_db::rs_close $otrs}

		}

		# we should update the array there. At the moment we just invalidate them
		array set CLAIMS [array unset CLAIMS]
	}
	if {$any_triggers_called} {
		# we should update the array there. At the moment we just invalidate them
		array set CALLED [array unset CALLED]
	}

	unset ACTION

	return [list $any_triggers_called [list FULL $offer_ids]]
}



# Check the details against the in-memory cached information of the offer
# (This assumes that the memory arrays - OFFER, TRIGGER are set (see cache.tcl)
#
proc ob_fbets::_check_offer_first_pass {offer_id} {

	variable ACTION
	variable OFFER
	variable TRIGGER
	variable CUST_OFFER

	ob_log::write DEBUG {Checking offer: $offer_id}


	# Check that the offer is available for this customer
	if {[lsearch -exact $CUST_OFFER(offer_ids) $offer_id] == -1} {
		ob_log::write DEBUG {Ruled out offer $offer_id: Not available for this customer, available offers list = $CUST_OFFER(offer_ids)}
		return 0
	}

	# check the ccy
	if {[lsearch -exact $OFFER($offer_id,ccy_codes) $ACTION(ccy_code)] == -1} {
		ob_log::write DEBUG {Ruled out offer $offer_id: $ACTION(ccy_code) not in $OFFER($offer_id,ccy_codes)}
		return 0
	}

	# check the language
	if {
		$OFFER($offer_id,lang) != "" &&
		$OFFER($offer_id,lang) != $ACTION(lang)
	} {
		ob_log::write DEBUG {Rules out offer $offer_id: $ACTION(lang) <> $OFFER($offer_id,lang)}
		return 0
	}

	# check the country
	if {
		$OFFER($offer_id,country_code) != "" &&
		[string first $ACTION(country_code) $OFFER($offer_id,country_code)] == -1
	} {
		ob_log::write DEBUG {Ruled out offer $offer_id: $ACTION(country_code) not in $OFFER($offer_id,country_code)}
		return 0
	}

	# check the channel (note: this is different from channel strictness set at trigger level)
	if {
		$OFFER($offer_id,channels) != "" &&
		[string first $ACTION(channel) $OFFER($offer_id,channels)] == -1
	} {
		ob_log::write DEBUG {Ruled out offer $offer_id: $ACTION(channel) not in $OFFER($offer_id,channels)}
		return 0
	}

	# Registration is always the first action a punter could possibly do.
	# Even though we don't yet know what triggers the user has called, we
	# do know that he must have registered - and what's more, we have the
	# affiliate through which he registered. If this offer contains a REG
	# trigger which doesn't match that affiliate, there's no possbility of
	# him ever claiming the offer - he cannot go back and register again!
	# Hopefully this check alone will rule out a fair few offers ...
	#
	# Note: we check the affiliate against each trigger elsewhere
	#
	foreach trigger_id $OFFER($offer_id,trigger_ids) {
		if {$TRIGGER($trigger_id,type_code) == "REG"} {

			if {![_check_affiliate \
					$TRIGGER($trigger_id,aff_level) \
					$TRIGGER($trigger_id,aff_id) \
					$TRIGGER($trigger_id,aff_grp_id) \
					$ACTION(reg_aff_id) \
					$ACTION(reg_aff_grp_id) \
			]} {
				ob_log::write DEBUG {Ruled out offer $offer_id (based on REG affiliate).}
				return 0
			} else {
				# We're not expecting multiple REG triggers.
				break
			}
		}
	}

	# Now check the triggers. Could any of the triggers be possibly called by this action?
	# (The check to see whether it actually has been called is done later.)
	#
	set found_poss_trigger 0
	foreach trigger_id $OFFER($offer_id,trigger_ids) {
		if {[_check_trigger_first_pass $offer_id $trigger_id]} {
			set found_poss_trigger 1
			break
		}
	}
	if {!$found_poss_trigger} {
		ob_log::write DEBUG {Ruled out offer $offer_id (no triggers possible)}
		return 0
	}

	ob_log::write DEBUG {offer $offer_id is a candidate after first pass}
	return 1
}



#
#
proc ::ob_fbets::_has_claimed {cust_id offer_id} {

	variable OFFER
	variable CLAIMS

	# If the offer is not in the CLAIMS array OR it's an unlimited claims offer ...
	if { ![info exists CLAIMS($offer_id)] || $OFFER($offer_id,unlimited_claims) == "Y" } {
		# then user has not claimed
		return 0
	} elseif { $CLAIMS($offer_id) < $OFFER($offer_id,max_claims) || $OFFER($offer_id,max_claims) < 0 } {
		# Else check if it has been claimed less than max_claims or if max_claims is < 0
		return 0
	}
	# ... finally it has been claimed.
	return 1
}



# Note that we don't know at this stage which triggers have already been
# called; what we want to know is whether this action would call this trigger
# assuming that the rank and qualification etc. are correct.
#
proc ob_fbets::_check_trigger_first_pass {offer_id trigger_id} {

	variable ACTION
	variable OFFER
	variable TRIGGER
	variable CALLED

	ob_log::write DEBUG {Checking trigger $trigger_id from offer $offer_id (first pass).}

	array unset TRIGGER_LEVELS

	# Check trigger type matches one of our actions.
	set type_code $TRIGGER($trigger_id,type_code)

	# Special checks to skip trigger type OFFER, as this can only be fulfilled
	# retrospectively if a claim has been made
	if { $TRIGGER($trigger_id,type_code) == "OFFER" } {
		return 0

	} elseif {[lsearch -exact $ACTION(actions) $type_code] == -1} {
		ob_log::write DEBUG {Ruled out trigger $trigger_id from offer $offer_id (based on trigger type).}
		return 0
	}

	 #check_channels {user_id channels_thru channel_strict source}

	 if {![_check_affiliate \
			$TRIGGER($trigger_id,aff_level) \
			$TRIGGER($trigger_id,aff_id) \
			$TRIGGER($trigger_id,aff_grp_id) \
			$ACTION(aff_id) \
			$ACTION(aff_grp_id) \
	]} {
		ob_log::write DEBUG {Ruled out trigger $offer_id (based on $type_code affiliate).}
		return 0
	}

	# Some triggers need the amount checking.
	set chk_amt_for {FBET BET BET1 SPORTSBET SPORTSBET1 DEP1 DEP}
	if {[lsearch $chk_amt_for $type_code] != -1} {
		set amount_key "amount,$ACTION(ccy_code)"

		set eps 1e-6
		if {$TRIGGER($trigger_id,$amount_key) > ($ACTION(value) + $eps)} {
			ob_log::write DEBUG {Ruled out trigger $trigger_id from offer $offer_id (based on value below trigger amount).}
			return 0
		}
	}

	# Some triggers need the bet level checking.
	set chk_bet_lvl_for {BET BET1}
	if {[lsearch $chk_bet_lvl_for $type_code] != -1} {

		set trigger_levels [list]

		if {[catch {
			set trigger_levels [OB_freebets::_get_trigger_levels $trigger_id]
		} msg]} {
			ob_log::write ERROR "Failed to get trigger levels for trigger $trigger_id: $msg"
			return 0
		}

		# if there are none, then we match all levels
		if {[llength $trigger_levels] == 0} {
			return 1
		}

		foreach {level id} $trigger_levels {
			lappend TRIGGER_LEVELS($level) $id
			ob_log::write INFO {TRIGGER_LEVELS - level = $level , id = $id }
		}

		foreach {level ids} [array get TRIGGER_LEVELS] {
			set obj_level $level

			foreach id $ids {
				ob_log::write INFO {Checking level = $level - id = $id }

				set obj_id    $id
				switch -exact -- $obj_level {
					"ALL" -
					"ANY" {
						set level_ok 1
					}
					"SELECTION" {
						set level_ok [expr {[lsearch -exact $ACTION(ev_oc_ids) $obj_id] != -1}]
					}
					"MARKET" {
						set level_ok [expr {[lsearch -exact $ACTION(ev_mkt_ids) $obj_id] != -1}]
					}
					"EVENT" {
						set level_ok [expr {[lsearch -exact $ACTION(ev_ids) $obj_id] != -1}]
					}
					"TYPE" {
						set level_ok [expr {[lsearch -exact $ACTION(ev_type_ids) $obj_id] != -1}]
					}
					"CLASS" {
						set level_ok [expr {[lsearch -exact $ACTION(ev_class_ids) $obj_id] != -1}]
					}
					default {
						ob_log::write WARNING {Unknown trigger bet level $obj_level}
						set level_ok 0
					}
				}

				if {$level_ok} {
					ob_log::write DEBUG  {Found bet level match }
					break
				}
			}

			if {$level_ok} {
				break
			}
		}

		if {!$level_ok} {
			ob_log::write DEBUG  {Ruled out trigger $trigger_id from offer $offer_id (based on bet level checks).}
			return 0
		}

	}

	set level_ok 0
	switch -exact -- $TRIGGER($trigger_id,type_code) {
		"DEP1" {
			set level_ok [check_first_strict $ACTION(cust_id) "chan_dep_thru" $TRIGGER($trigger_id,channel_strict) $ACTION(channel) "DEPOSIT" $ACTION(bet_id)]
		}
		"FBET" -
		"SPORTSBET1" -
		"BET1"	{
			set level_ok [check_first_strict $ACTION(cust_id) "chan_bet_thru" $TRIGGER($trigger_id,channel_strict) $ACTION(channel) "BET" $ACTION(bet_id)]
		}
		default {
			set level_ok 1
		}
	}

	if {!$level_ok} {
		ob_log::write DEBUG  {Ruled out trigger $trigger_id from offer $offer_id (based on bet check_first_strict ($TRIGGER($trigger_id,channel_strict) $ACTION(channel) BET  $ACTION(bet_id) ).}
		return 0
	}

	ob_log::write DEBUG {Trigger $trigger_id from offer $offer_id is a candidate after first pass.}

	return 1
}


# TODO - document
#
proc ob_fbets::_check_affiliate {t_level t_id t_grp_id a_id a_grp_id} {

	switch -exact -- $t_level {
		"" {
			# Unresticted.
			return 1
		}
		"All" {
			# Anything apart from the main site.
			return [expr { 0 != $a_id }]
		}
		"None" {
			# Only the main site.
			return [expr { 0 == $a_id }]
		}
		"Single" {
			# This particular affiliate.
			return [expr { $t_id == $a_id }]
		}
		"Group" {
			# This particular affiliate group.
			return [expr { $t_grp_id == $a_grp_id }]
		}
		default {
			error "Bad trigger affiliate level \"$t_level\""
		}
	}
}



# Peform final check if an action calls any triggers in an offer, marking
# those triggers as called in the DB and claiming the offer as appropriate.
#
# TODO - more docs
#
# Returns list of two booleans: {was_offer_claimed were_any_triggers_called}.
#
# Warning: assumes that _check_offer_first_pass has already returned true!
#
proc ob_fbets::_check_offer_final_pass {offer_id} {

	variable ACTION
	variable OFFER
	variable TRIGGER
	variable CALLED
	variable PROMO

	ob_log::write INFO {Checking offer $offer_id (final pass).}

	# Foreach trigger in the offer ...

	set called_trigger_ids [list]
	set claimed_offer 0

	# this relies on the trigger id being in rank order
	foreach trigger_id $OFFER($offer_id,trigger_ids) {

		# If we've called a trigger with a rank not equal to the current
		# trigger - break, because we loop in rank order we don't want
		# to fire any triggers with a higher rank than the one we've
		# just called, triggers must be looped in rank order
		if {[info exists last_fulfill_rank] && \
			$last_fulfill_rank != $TRIGGER($trigger_id,rank)} {
			break;
		}

		if { $ACTION(actions) == "PROMO" &&  \
			$PROMO($ACTION(promo_code),$offer_id) != $trigger_id } {
			ob_log::write INFO {PROMO is not available for trigger id $trigger_id}
			continue
		}

		if {![_check_trigger_final_pass $offer_id $trigger_id]} {
			continue
		}

		lappend called_trigger_ids $trigger_id

		if {$ACTION(log_only)} {
			ob_log::write INFO {Would call $trigger_id from offer $offer_id but not going to since in log only mode.}
		} else {
			_fulfill_trigger $offer_id $trigger_id $ACTION(cust_id) $TRIGGER($trigger_id,rank) $ACTION(value)

			# Keep track of this in case we have multiple check_action_fast calls in the same request because
			# the DB values in CALLED are cached.
			if { ![info exists CALLED(called_trigger_ids,$trigger_id)] } {
				lappend CALLED(called_trigger_ids,$trigger_id) "FULFILLED"

				# If it is fulfilled here, then it cannot have uncalled previous triggers
				set CALLED(FULFILLED,stage) 0
			}

			# Need to keep track of the last fulfilled rank, if the
			# next trigger we check is not of the same rank
			# we can bail as we don't want to call multiple
			# different ranked triggers in the same request
			set last_fulfill_rank $TRIGGER($trigger_id,rank)
		}
	}

	ob_log::write DEBUG { called_trigger_ids = $called_trigger_ids }

	if {[llength $called_trigger_ids]} {

		set has_uncalled_trigger 0
		foreach trigger_id $OFFER($offer_id,trigger_ids) {
			# had it been called earlier?
			if {
				[info exists CALLED(called_trigger_ids,$trigger_id)] &&
				[llength $CALLED(called_trigger_ids,$trigger_id)]
			} {
				continue
			}

			# has it *just* been called?
			if {[lsearch -exact $called_trigger_ids $trigger_id] != -1} {
				continue
			}

			# we've reached here, so the trigger has not been called
			set has_uncalled_trigger 1
			# also, we might as well break out of the loop
			break
		}

		ob_log::write DEBUG { has_uncalled_trigger = $has_uncalled_trigger }

		if {!$has_uncalled_trigger && !$ACTION(log_only)} {
			_claim_offer \
				$ACTION(cust_id) \
				$offer_id \
				$ACTION(bet_id) \
				$ACTION(bet_type) \
				$ACTION(value) \
				$trigger_id \
				$ACTION(redeem_list)

			set claimed_offer 1
		}
	}

	return [list $claimed_offer [llength $called_trigger_ids]]
}



# Perform final checks for whether an action calls a trigger.
#
# Returns 0 if the trigger should not be called or 1 if it should.
#
proc ob_fbets::_check_trigger_final_pass {offer_id trigger_id} {

	variable ACTION
	variable OFFER
	variable TRIGGER
	variable CALLED
	variable TRIGGER_LEVELS

	# Has this trigger already been called?
 	if {
		[info exists CALLED(called_trigger_ids,$trigger_id)] &&
		[llength $CALLED(called_trigger_ids,$trigger_id)]
	} {
		ob_log::write DEBUG {Ruled out trigger $trigger_id from offer $offer_id (already called).}
		return 0
	}

	# NB: I wonder what the best order is to do these checks;
	# obviously, we want the cheapest first ...

	# We MUST still do the first pass check since this will have been done for
	# at most one trigger in the _check_offer_first_pass proc - and it might
	# not be this one! It should be pretty cheap anyway (though I guess we
	# could keep a record of what we checked in the 1st pass to avoid it).

	if {! [_check_trigger_first_pass $offer_id $trigger_id]} {
		return 0
	}

	# We now need to check the rank and qualification settings have been met;
	# it might be that this trigger cannot be called until earlier triggers
	# have already been called.

	if {[_has_uncalled_earlier_trigger $offer_id $trigger_id]} {
		ob_log::write DEBUG {Ruled out trigger $trigger_id from offer #$offer_id (earlier trigger(s) not called).}
		return 0
	}

	# Add here any specific trigger checks
	set amount_key "amount,$ACTION(ccy_code)"
	switch -exact -- $TRIGGER($trigger_id,type_code) {
		"OFFER" -
		"REG"   -
		"REGAFF" -
		"DEP"   -
		"DEP1"  -
		"FBET" {
			ob_log::write INFO "Match for $TRIGGER($trigger_id,type_code)"
			return 1
		}
		"BET" -
		"BET1"  -
		"SPORTSBET" -
		"SPORTSBET1" {

			# Is minimum price checking functionality configured ?
			if { [OT_CfgGetTrue FUNC_FREEBETS_MINPRICE] } {
				ob_log::write INFO "Checking for minimum price..."
				if {[_check_min_price $TRIGGER($trigger_id,min_price_num) $TRIGGER($trigger_id,min_price_den) $ACTION(value) $TRIGGER($trigger_id,$amount_key)] == 0} {
					return 0
				}
			}

			ob_log::write INFO "Match for $TRIGGER($trigger_id,type_code)"
			return 1
		}
		"PROMO" {
			if {[string toupper $ACTION(promo_code)] == $TRIGGER($trigger_id,promo_code)} {
				ob_log::write INFO "PROMO matched , trigger $trigger_id"
				return 1
			} else {
				ob_log::write INFO "PROMO does not match, ruled out trigger $trigger_id"
				return 0
			}
		}
		"BUYMGETN" {

			set buymgetn_result [ob::games::triggers::check_buymgetn $ACTION(cust_id) \
						$trigger_id $ACTION(bet_type) \
						-reset_if_fulfilled 1]

			ob_log::write INFO "$TRIGGER($trigger_id,type_code) buymgetn_result = $buymgetn_result"

			if {[lindex $buymgetn_result 0] == 1} {
				set ACTION(value) [lindex $buymgetn_result 1]

				ob_log::write INFO "Match for $TRIGGER($trigger_id,type_code), using value = $ACTION(value)"

				return 1
			} else {
				ob_log::write INFO "BUYMGETN does not match, ruled out trigger $trigger_id"
				return 0
			}
		}
		"BBAR" {
			if {$ACTION(bet_type) == "FOG"} {
				ob_log::write INFO "matched BBAR"
				return 1
			} else {
				return 0
			}
		}
		"FIRSTGAME" {
			set check_trigger_result [_check_trigger_FIRSTGAME $ACTION(cust_id) \
									   $trigger_id \
									   $ACTION(bet_type) ]

			ob_log::write INFO "$TRIGGER($trigger_id,type_code) check_result = $check_trigger_result"

			if {[lindex $check_trigger_result 0]} {

				ob_log::write INFO "Match for $TRIGGER($trigger_id,type_code)"
				return 1
			} else {
				ob_log::write INFO "FIRSTGAME does not match, ruled out trigger $trigger_id"
				return 0
			}
		}
		"GAMESSPEND" {

			set check_trigger_result [ob::games::triggers::check_gamesspend \
							$ACTION(cust_id) \
							$trigger_id -reset_if_fulfilled 1]

			ob_log::write INFO "$TRIGGER($trigger_id,type_code) check_result = $check_trigger_result"

			if {[lindex $check_trigger_result 0]} {

				ob_log::write INFO "Match for $TRIGGER($trigger_id,type_code)"
				return 1
			} else {
				ob_log::write INFO "FIRSTGAME does not match, ruled out trigger $trigger_id"
				return 0
			}
		}
		default {
			ob_log::write INFO "Unknown trigger action $TRIGGER($trigger_id,type_code)"
			return 0
		}
	}

	ob_log::write DEBUG {Trigger $trigger_id from offer $offer_id is a candidate after final pass.}

	return 1
}


# Does a trigger have an earlier uncalled trigger in the same offer?
# Assumes the CALLED array is already populated.
# Returns 0 (no) or 1 (yes).
#
proc ob_fbets::_has_uncalled_earlier_trigger {offer_id trigger_id} {

	variable OFFER
	variable TRIGGER
	variable CALLED

	set rank $TRIGGER($trigger_id,rank)

	if {$rank == ""} {
		set stage_rank 9999
	} else {
		set stage_rank $rank
	}

	set qual $TRIGGER($trigger_id,qualification)


	# Foreach trigger in the same offer ...

	foreach other_trigger_id $OFFER($offer_id,trigger_ids) {
		if {$trigger_id == $other_trigger_id} {
			continue
		}
		# Is this an earlier trigger?
		set other_rank $TRIGGER($other_trigger_id,rank)
		set other_qual $TRIGGER($other_trigger_id,qualification)
		set is_earlier [expr {\
		     ($other_qual == "Y" && ($other_rank == "" || $other_rank != "" && ($rank == "" || $other_rank < $rank ))) || \
			 ($other_rank != "" && ($rank == "" || $other_rank < $rank )) \
		}]

		if {!$is_earlier} {
			continue
		}
		# Does it have a called trigger entry with an appropriate stage?
		if {![info exists CALLED(called_trigger_ids,$other_trigger_id)]} {
			set ct_ids [list]
		} else {
			set ct_ids $CALLED(called_trigger_ids,$other_trigger_id)
		}
		set found_entry 0
		foreach called_trigger_id $ct_ids {
			set other_stage $CALLED($called_trigger_id,stage)
			if {$other_stage == ""} {
				set other_stage 0
			}
			if {$other_stage <= $stage_rank} {
				set found_entry 1
				break
			}
		}
		if {!$found_entry} {
			ob_log::write DEBUG {Found uncalled earlier trigger $other_trigger_id.}
			return 1
		}
	}

	# Guess there weren't any then.

	return 0
}


# Check if we're doing a bet for the first time
#
# if channel_strict is set to Y we ensure that the channel we first bet/deposited to is the same as the one we're currently at
# Note: channel_strict can be set to Y only for "FBET" "BET1" "SPORTSBET1" (c.f. admin/html/trigger.html)
#
#
proc ob_fbets::check_first_strict {user_id channels_thru channel_strict source action_name ref_id} {

	variable CUST_FLAGS

	ob_log::write DEBUG "ob_fbets::check_first_strict on with: $user_id $channels_thru $channel_strict $source $action_name $ref_id"

	# check cache
	if {[info exists CUST_FLAGS(user_id)] && $CUST_FLAGS(user_id) == $user_id &&
		[info exists CUST_FLAGS(channels_thru)] && $CUST_FLAGS(channels_thru) == $channels_thru &&
		[info exists CUST_FLAGS(req_id)]  && $CUST_FLAGS(req_id)  == [reqGetId]
	} {
		set channels_thru $CUST_FLAGS(channels_thru)
	} else {
		# fetch from DB
		set channels_thru [OB_freebets::fb_get_cust_flag $user_id $channels_thru]
		set CUST_FLAGS(channels_thru) $channels_thru
	}

	set isFirst 0

	if {[OT_CfgGet USE_CUST_STATS 0]} {

		if {$channel_strict == "N"} {
			set source {%}
		}

		if {[catch {
			set rs [ob_db::exec_qry ob_fbets::check_for_first_action $user_id $source $ref_id $action_name]
		} msg]} {
			ob_log::write DEBUG "failed to execute check_for_first_action: $msg"
			return 0
		}

		set nrows [db_get_nrows $rs]

		if {$nrows > 0} {
			# action has already occured
			ob_log::write DEBUG "Action $action_name not first"
			ob_db::rs_close $rs
			return 0
		}

		# no previous action of this type found
		ob_log::write DEBUG "Action $action_name is first"

		set isFirst 1

		ob_db::rs_close $rs

	} else {
		if {$channel_strict == "Y"} {
			if {[string first $source $channels_thru] == -1} {
				set isFirst 1
			}
		} else {
			if {$channels_thru == ""} {
				set isFirst 1
			}
		}
	}

	ob_log::write DEBUG "ob_fbets::check_first_strict: returns $isFirst"

	return $isFirst
}


# Check if selections within bet satisfy the min selection price threshold
#
# For single bets we check that the bet odds are higher than the one defined in the trigger
# for complex bets we take the odds of the whole bet, we don't care about individual legs
# For each way we take only the win part into account and check that its amount is above
#     the minimum stake
# SP/GP will qualify regardless of a minimum price associated with the bet trigger
# FC/TC will qualify regardless of a minimum price associated with the bet trigger
#
# Output
#   1 - if selections satisfy the min selection threshold (or if it doesn't
#        exist)  OR
#   0  - Selections with bet failed to satisfy minimum threshold
#
proc ob_fbets::_check_min_price {min_seln_num min_seln_den stake trigger_min_stake} {

	global FBDATA

	set fn {ob_fbets::_check_min_price}

	ob_log::write INFO {$fn: min_num:$min_seln_num\
	                       - min_den:$min_seln_den\
	                       - stake:$stake\
	                       - trigger_min_stake: $trigger_min_stake}

	# no minium odds defined -> success
	if {$min_seln_num == "" && $min_seln_den == ""} {
		ob_log::write INFO {$fn: No minimum odds defined - ignoring min price check}
		return 1
	}

	# Grab config item for class exceptions
	set ignore_mul_classes  [OT_CfgGet FREEBETS_MINPRICE_MULCLASS_IGNORE_LIST {}]

	# Cycle on all selections to see if we want to do the check
	foreach ocid $FBDATA(bet_ids) {

		# Do we have any complex legs?
		if { [lsearch -exact {AH MH WH OU hl HL --} $FBDATA($ocid,leg_sort)] < 0 } {
			ob_log::write INFO {$fn: We have complex legs ($ocid :\
			                    $FBDATA($ocid,leg_sort)) -\
			                    ignoring min price check}
			return 1
		}

		# Do we have selections with LP prices?
		if {$FBDATA($ocid,price_type) != "L"} {
			ob_log::write INFO {$fn: Price type is not LP - Ignoring price check}
			return 1
		}

		# Is the bet a multiple bet ?
		if { $FBDATA(bet_type) != "SGL" } {
			# Is any selection within an exception class?
			foreach exception $ignore_mul_classes {
				if {[string equal $FBDATA($ocid,seln_class) $exception]} {
					ob_log::write INFO {$fn: Selection $ocid on exception \
					              class $exception - ignoring min price check}
					return 1
				}
			}
		}

	}

	# Looks like we will check out the price, go on
	# We will never reach this point if the SGL is a complex single (FC/TC) so
	# don't worry if FBDATA is not set up for that ...
	if {$FBDATA(bet_type) == "SGL"} {
		# The bet is a single, we take the price
		set num    $FBDATA($FBDATA(bet_ids),lp_num)
		set den    $FBDATA($FBDATA(bet_ids),lp_den)
		set correction 1.0
	} else {
		# The bet is not a single, we use potential_payout and stake which is
		# the "effective price"
		set num  $FBDATA(potential_payout)
		set den  $FBDATA(stake)
		set correction 0.0
	}

	ob_log::write DEBUG {$fn: Bet is $FBDATA(bet_type), setting num:$num \
						                                        den:$den \
						                                 correction:$correction}

	if {$FBDATA(leg_type) == "E"} {
		# for each way bets we only take the win part into account for the
		# trigger minimum stake
		set stake [expr $FBDATA(stake) / 2.0]
		if {$stake < $trigger_min_stake} {
			ob_log::write DEBUG {$fn: (EW) Stake halved, \
			            $stake is below $trigger_min_stake - Not firing trigger}
			return 0
		}
	}



	# Min Price will be done either on the single price or on the overall multiple
	# "price" which is calculated as POTENTIAL PAYOUT / STAKE

	set min_seln_price [expr {1.0+double($min_seln_num)/double($min_seln_den)}]

	set seln_price [expr {$correction+double($num)/double($den)}]

	# if the selection odds are less than the min threshold return failure
	if {$seln_price < $min_seln_price} {
		ob_log::write INFO {$fn: Min selection price threshold FAILURE -\
		                    $seln_price < $min_seln_price}
		return 0
	}

	ob_log::write INFO {$fn: Min selection price threshold SUCCESS -\
	                    $seln_price >= $min_seln_price}

	# success
	return 1

}


# Prepare database queries
#
proc ob_fbets::_prepare_check_queries {} {


	ob_db::store_qry ob_fbets::get_aff_grp_id_for_aff {
		select
			aff_grp_id
		from
			tAffiliate
		where
			aff_id = ?
	} 300

	# We'd rather not use this query, but it is used if the values are not passed in
	ob_db::store_qry ob_fbets::get_cust_info {
 		select
			c.country_code,
			c.lang,
			a.ccy_code
		from
			tCustomer      c,
			tAcct          a
		where
			c.cust_id = a.cust_id
			and c.cust_id = ?
	}


}



#
# This function essentially performs what the classic OB_freebets::check_trigger does for
# action FIRSTGAME
#
proc ob_fbets::_check_trigger_FIRSTGAME { user_id trigger_id ref_type } {

	ob::log::write INFO "_check_trigger_FIRSTGAME: user_id = $user_id, trigger_id = $trigger_id, ref_type = $ref_type "

	if {$ref_type == "FOG"} {
		# check that no other games have been played in this group
		if [catch {set res [ob_db::exec_qry ob_fbets::gp_has_game_group_been_played_before $user_id $trigger_id]} msg] {
			ob::log::write ERROR  "Failed to run fb_gp_has_game_group_been_played_before $msg"
			return [list 0]
		}

		set nrows [db_get_nrows $res]
		if {$nrows == 0} {
			ob_db::rs_close $res
			ob::log::write ERROR  "ERROR! Should have found at least one row for fb_gp_has_game_group_been_played_before"
			return [list 0]
		} elseif {$nrows >= 2} {
			ob::log::write INFO "Another game in the group has been played"
			ob_db::rs_close $res
		} else {
			set num_plays [db_get_col $res num_plays]
			if {$num_plays == 1} {
				ob::log::write INFO  "FIRSTGAME satisfied"
				ob_db::rs_close $res
				return [list 1]
			}
			ob::log::write INFO "FIRSTGAME not satisfied.  Game has been played $num_plays times"
			ob_db::rs_close $res
			return [list 0]
		}

		ob::log::write INFO "FIRSTGAME not satisfied"
		return [list 0]

	}
}
