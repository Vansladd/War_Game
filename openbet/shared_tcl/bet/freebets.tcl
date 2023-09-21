################################################################################
# $Id: freebets.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Place tokens against bet; check which tokens can be used against bets.
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
#    ob_bet::get_tokens_for_group   Get valid tokens for group
#
################################################################################

namespace eval ob_bet {
	namespace export get_tokens_for_group
	namespace export go_check_action_fast_bet_pkg

	variable TOKEN
	variable VALID_TOKENS
	variable FREEBET_CHECKS
}



#API:get_tokens_for_group - Get token ids that can be placed on group
# Usage
# ::ob_bet::get_tokens_for_group {}
#
# RETURNS:
#   list of valid tokens that can be used on that group
#
proc ::ob_bet::get_tokens_for_group {grp_id} {

	_log INFO "API(get_tokens_for_group)"

	if {[catch {
		set ret [_get_tokens_for_group $grp_id]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_tokens - Get all cust token ids that are available for the user
# Usage
# ::ob_bet::get_tokens
#
# RETURNS:
#    list of tokens
#
proc ::ob_bet::get_tokens args {

	variable TOKEN

	_log INFO "API(get_tokens)"

	_get_tokens

	if {$TOKEN(num) > 0} {
		return $TOKEN(tokens)
	} else {
		return [list]
	}
}



#API:get_token Get information on tokens
# Usage
# ::ob_bet::get_token cust_token_id param
#
# Parameters:
# cust_token_id: FORMAT: INT  DESC: id returned from ob_bet::get_tokens_for_group
#
# RETURNS:
#    {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_token 0 value
# 1 15.00
# > ::ob_bet::get_token 3 expiry_date
# 0 "" # not found
#
proc ::ob_bet::get_token {ct_id param}  {

	_log INFO "API(get_token): $ct_id,$param"

	if {[catch {
		set ret [eval _get_token {$ct_id} {$param}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_freebet_checklist Get freebet checklist
# Usage
# ::ob_bet::get_freebet_checklist
#
# Get a list of all the bets placed which can be used to check whether any
# fulfill a token trigger.
#
# RETURNS:
#    list {bet_id ev_oc_ids stake}
#
proc ::ob_bet::get_freebet_checklist {} {

	variable FREEBET_CHECKS

	_log DEBUG "API(get_freebet_checklist)"
	_smart_reset FREEBET_CHECKS

	# if the bet has gone async, this won't exist
	if {[info exists FREEBET_CHECKS(checks)]} {
		return $FREEBET_CHECKS(checks)
	} else {
		return [list]
	}
}

#END OF API..... private procedures



# Prepare DB queries
#
proc ob_bet::_prepare_fbet_qrys {} {

	ob_db::store_qry ob_bet::get_tokens {
		select
		  ct.cust_token_id,
		  ct.value,
		  ct.token_id,
		  ct.expiry_date,
		  o.name as offer_name,
		  rv.redemption_id,
		  rv.bet_type,
		  rv.bet_id,
		  rv.bet_level,
		  rv.name as redemption_name
		from
		  tCustomerToken  ct,
		  tToken          t,
		  tOffer          o,
		  tPossibleBet    pb,
		  tRedemptionVal  rv
		where
		  ct.cust_id       = ? and
		  ct.token_id      = t.token_id and
		  t.offer_id       = o.offer_id and
		  t.token_id      = pb.token_id and
		  pb.redemption_id = rv.redemption_id and
		  ct.redeemed      = 'N' and
		  ct.status        = 'A' and
		  ct.expiry_date   > CURRENT and
		  rv.bet_level in ('CLASS','TYPE','EVENT','MARKET','SELECTION','ANY')
		union
		select
		  ct.cust_token_id,
		  ct.value,
		  ct.token_id,
		  ct.expiry_date,
		  o.name as offer_name,
		  rv.redemption_id,
		  rv.bet_type,
		  rv.bet_id,
		  rv.bet_level,
		  rv.name as redemption_name
		from
		  tCustomerToken  ct,
		  tToken          t,
		  tOffer          o,
		  tRedemptionVal  rv
		where
		  ct.adhoc_redemp_id is not null and
		  ct.cust_id       = ? and
		  ct.token_id      = t.token_id and
		  t.offer_id       = o.offer_id and
		  ct.adhoc_redemp_id = rv.redemption_id and
		  ct.redeemed      = 'N' and
		  ct.status        = 'A' and
		  ct.expiry_date   > CURRENT and
		  rv.bet_level in ('CLASS','TYPE','EVENT','MARKET','SELECTION','ANY')
		order by 1;
	}

	ob_db::store_qry ob_bet::get_coupon_selns {
		select
		  ev_oc_id
		from
		  tEvOc oc,
		  tCouponMkt cmkt
		where
		  cmkt.coupon_id = ?
		and
		  cmkt.ev_mkt_id = oc.ev_mkt_id
	} 300

	ob_db::store_qry ob_bet::redeem_token {
		execute procedure pRedeemCustToken(
			p_cust_id=?,
			p_cust_token_id=?,
			p_redemption_type=?,
			p_redemption_id=?,
			p_redemption_amt=?,
			p_partial_redempt=?,
			p_do_transaction='N'
		)
	}
}



# get tokens that can be placed against this group of selections
#
proc ob_bet::_get_tokens_for_group {group_id} {

	variable VALID_TOKENS

	_get_tokens_for_groups

	if {[info exists VALID_TOKENS($group_id)]} {
		OT_LogWrite 5 "- returning valid tokens..."
		return $VALID_TOKENS($group_id)
	} else {
		OT_LogWrite 5 "no tokens"
		return [list]
	}
}



# get tokens for added groups
#
proc ob_bet::_get_tokens_for_groups {} {

	variable TOKEN
	variable VALID_TOKENS
	variable GROUP
	variable LEG
	variable SELN
	variable CUST

	if {![_smart_reset VALID_TOKENS]} {
		#already retrieved valid tokens
		return
	}

	if {[_smart_reset GROUP] || $GROUP(num) == 0} {
		error\
			"No groups have been added call ::ob_bet::add_group"\
			""\
			FREEBET_NO_GROUPS
	}

	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			FREEBETS_NO_CUST
	}

	if {![_get_tokens]} {
		return
	}


	foreach ct_id $TOKEN(tokens) {

		# loop over the token's redemption values (may now be > 1)
		for {set red 0} {$red < [llength $TOKEN($ct_id,ids)]} {incr red} {

			set bet_level  [lindex $TOKEN($ct_id,bet_level)  $red]
			set id_or_sort [lindex $TOKEN($ct_id,id_or_sort) $red]
			set ids        [lindex $TOKEN($ct_id,ids)        $red]

			for {set g 0} {$g < $GROUP(num)} {incr g} {

				set matched 0

				if {$bet_level == "ANY"} {
					lappend VALID_TOKENS($g) $TOKEN($ct_id,token_id) $TOKEN($ct_id,cust_token_id)
					continue
				}

				foreach l $GROUP($g,legs) {
					foreach seln $LEG($l,selns) {

						switch -- $bet_level {
							"SELECTION" {
								set id $seln
							}
							"MARKET" {
								set id\
									[expr {$id_or_sort == "ID" ?
									       $SELN($seln,ev_mkt_id) :
									       $SELN($seln,mkt_sort)}]
							}
							"EVENT" {
								set id\
									[expr {$id_or_sort == "ID" ?
									       $SELN($seln,ev_id) :
									       $SELN($seln,ev_sort)}]
							}
							"TYPE" {
								set id $SELN($seln,ev_type_id)
							}
							"CLASS" {
								set id\
									[expr {$id_or_sort == "ID" ?
									       $SELN($seln,ev_class_id) :
									       $SELN($seln,class_sort)}]
							}
							"COUPON" {
								set id $seln
							}
						}

						#we may have more than one id associated
						#with a token in the case of COUPON
						foreach bet_id $ids {
							if {$id == $bet_id} {
								lappend VALID_TOKENS($g)\
									$TOKEN($ct_id,token_id) $TOKEN($ct_id,cust_token_id)
								set matched 1
								break
							}
						}
						if {$matched} {break}
					}
					if {$matched} {break}
				}
			}
		}

	}
}



# Get valid tokens customer can use.
#
proc ob_bet::_get_tokens {} {

	variable CUST
	variable TOKEN

	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			FREEBETS_NO_CUST
	}

	if {![_smart_reset TOKEN]} {
		#already retrieved freebet tokens
		if {$TOKEN(num) == 0} {
			return 0
		} else {
			return 1
		}
	}

	set cust_id $CUST(cust_id)

	set rs [ob_db::exec_qry ob_bet::get_tokens $cust_id $cust_id]
	set TOKEN(num) [db_get_nrows $rs]

	if {$TOKEN(num) == 0} {
		return 0
	}

	set TOKEN(tokens) [list]

	for {set r 0} {$r < $TOKEN(num)} {incr r} {
		set ct_id [db_get_col $rs $r cust_token_id]

		if {[lsearch $TOKEN(tokens) $ct_id] == -1} {

			lappend TOKEN(tokens) $ct_id
			set TOKEN($ct_id,cust_token_id) $ct_id

			foreach col {value token_id expiry_date offer_name} {
				set TOKEN($ct_id,$col) [db_get_col $rs $r $col]
			}

			foreach col {redemption_id bet_type bet_id bet_level\
			             redemption_name id_or_sort ids} {
				set TOKEN($ct_id,$col) [list]
			}
		}

		foreach col {redemption_id bet_type bet_id bet_level redemption_name} {
			lappend TOKEN($ct_id,$col) [db_get_col $rs $r $col]
		}

		if {[db_get_col $rs $r bet_level] == "COUPON"} {
			set ids [list]
			set rs2 [ob_db::exec_qry\
						 ob_bet::get_coupon_selns [db_get_col $rs $r bet_id]]
			for {set r2 0} {$r2 < [db_get_nrows $rs2]} {incr r2} {
				lappend ids [db_get_col $rs2 $r2 ev_oc_id]
			}
			ob_db::rs_close $rs2
			set id_or_sort ID
		} else {
			if {[db_get_col $rs $r bet_id] == ""} {
				set ids [db_get_col $rs $r bet_type]
				set id_or_sort SORT
			} else {
				set ids [db_get_col $rs $r bet_id]
				set id_or_sort ID
			}
		}
		lappend TOKEN($ct_id,ids) $ids
		lappend TOKEN($ct_id,id_or_sort) $id_or_sort
	}
	ob_db::rs_close $rs

	return 1
}



# Redeem tokens for this bet.
#
proc ob_bet::_redeem_tokens { bet_num } {

	variable BET
	variable CUST

	if {![info exists BET($bet_num,redeemed_tokens)]} {
		return
	}

	foreach {token value} $BET($bet_num,redeemed_tokens) {

		# on delayed bet, add tokens to request queue
		if {$BET(bet_delay)} {
			ob_db::exec_qry ob_bet::bir_ins_token\
				$BET(bir_req_id)\
				$BET($bet_num,bet_id)\
				$token

		# redeem the token
		} else {
			ob_db::exec_qry ob_bet::redeem_token\
				$CUST(cust_id)\
				$token\
				"SPORTS"\
				$BET($bet_num,bet_id)\
				$value\
				"N"
		}
	}
}



# Get token details
#
proc ::ob_bet::_get_token {ct_id param} {
	variable TOKEN

	if {[_smart_reset TOKEN] || ![info exists TOKEN($ct_id,$param)]} {
		return [list 0 ""]
	} else {
		return [list 1 $TOKEN($ct_id,$param)]
	}
}



# Add a freebet check
#
proc ::ob_bet::_add_freebet_check { bet_id ev_oc_ids stake } {

	variable FREEBET_CHECKS

	_smart_reset FREEBET_CHECKS

	lappend FREEBET_CHECKS(checks) $bet_id $ev_oc_ids $stake
}

::ob_bet::_log INFO "sourced freebets.tcl"


#
# We need to collect the selection hierarchy information at this stage
# This proc populates information for the FBDATA array used by the
# free bet package. The FBDATA array is available whether you come 
# from the bet packages or placebet2.tcl
#
proc ::ob_bet::go_check_action_fast_bet_pkg {
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
	variable SELN
	variable BET

	set ev_mkt_ids   [list]
	set ev_ids       [list]
	set ev_type_ids  [list]
	set ev_class_ids [list]
	set selns        [list]
	set bind_min_price 0

	ob_gc::add bind_min_price

	# Do we need to bind min_price check data?
	if { [OT_CfgGetTrue FUNC_FREEBETS_MINPRICE] &&\
	  [lsearch -exact -regexp $action "BET|BET1|SPORTSBET|SPORTSBET1" ] >= 0 } {
		ob_log::write INFO {Action requires min_price check, binding FBDATA...}
		set bind_min_price 1
	}

	if { $bind_min_price } {
		# Set bet number
		for {set bet_num 0} {$bet_num < $BET(num)} {incr bet_num} {
			if {$BET($bet_num,bet_id) == $ref_id } { break ;}
		}
	# Set global bet values
	set FBDATA(stake)              [lindex [ob_bet::get_bet $bet_num stake] 1]
	set FBDATA(leg_type)           [lindex [ob_bet::get_bet $bet_num leg_type] 1]
	set FBDATA(bet_type)           [lindex [ob_bet::get_bet $bet_num bet_type] 1]

	set FBDATA(bet_ids)            $evocs
	}

	foreach seln $evocs {
		set FBDATA($seln,ev_mkt_id)    $SELN($seln,ev_mkt_id)
		set FBDATA($seln,ev_id)        $SELN($seln,ev_id)
		set FBDATA($seln,ev_type_id)   $SELN($seln,ev_type_id)
		set FBDATA($seln,ev_class_id)  $SELN($seln,ev_class_id)

		if { $bind_min_price } {
			set FBDATA($seln,seln_class)   [lindex [ob_bet::get_oc $seln class_desc] 1]

			# Set the leg related infos only if they were not set by previous iterations
			if { [info exists FBDATA($seln,price_type)] == 0 } {
				set FBDATA($seln,price_type)   [lindex [ob_bet::get_leg $bet_num price_type] 1]
			}
		
			if { [info exists FBDATA($seln,leg_sort)] == 0 } {
				set FBDATA($seln,leg_sort)    [lindex [ob_bet::get_leg $bet_num leg_sort] 1]
			}
			# Grab prices only if the leg is not complex and we re not using starting prices

			if { [lsearch -exact {AH MH WH OU hl HL --} $FBDATA($seln,leg_sort)] >= 0 \
			                             && $FBDATA($seln,price_type) != "S"} {
				if { [info exists FBDATA($seln,lp_num)] == 0 && [info exists FBDATA($seln,lp_den)] == 0} {
					set FBDATA($seln,lp_num)       [lindex [ob_bet::get_leg $bet_num lp_num] 1]
					set FBDATA($seln,lp_den)       [lindex [ob_bet::get_leg $bet_num lp_den] 1]
				}
			}
		}


		ob_log::write INFO {go_check_action_fast_bet_pkg - ev_oc_id    = $seln}
		ob_log::write INFO {                             - ev_mkt_ids  = $FBDATA($seln,ev_mkt_id)}
		ob_log::write INFO {                             - ev_id       = $FBDATA($seln,ev_id) }
		ob_log::write INFO {                             - ev_type_id  = $FBDATA($seln,ev_type_id)}
		ob_log::write INFO {                             - ev_class_id = $FBDATA($seln,ev_class_id)}
	}

	if { $bind_min_price } {
	# Calculate potential payout for this bet
	set FBDATA(potential_payout)  [lindex [ob_bet::get_bet $bet_num potential_payout] 1]
	}

	if {[::ob_fbets::go_check_action_fast \
			$action\
			$user_id\
			$aff_id\
			$value\
			$evocs\
			"" "" ""\
			$ref_id\
			$ref_type\
			""\
			1] != 1} {
		error "::ob_bet::go_check_action_fast_bet_pkg - Failed to check action against $bet_id $ev_oc_ids $stake"
		return 0
	}

	return 1
}
