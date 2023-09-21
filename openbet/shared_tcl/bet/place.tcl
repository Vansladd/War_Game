###############################################################################
# $Id: place.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle the bet placement process - in summary:
#   ::ob_bet::init - call on application startup
#   ::ob_bet::add_leg -leg_param_name1 -leg_param_val1
#                     -leg_param_name2 -leg_param_val2
#                     ...
#
#   ie: add a starting price single, make it a banker and the bet
#   set leg1 [::ob_bet::add_leg -leg_sort S
#                               -price_type S
#                               -banker Y
#                               -selns {301}]
#
#   ie: add a scorecast of outcomes 150 and 165:
#   set leg2 [::ob_bet::add_leg -leg_sort SC
#                               -price_type L
#                               -lp_num 14
#                               -lp_den 1
#                               -banker N
#                               -selns {150 165}]
#
#   ie: add a combination forecast of 4 selections
#   set leg3 [::ob_bet::add_leg -leg_sort CF
#                               -price_type D
#                               -banker N
#                               -selns {201 202 203 204}]
#
#   ie  add a WDW leg
#   set leg4 [::ob_bet::add_leg -price_type L
#                               -banker N
#                               -selns {1}]
#
# Note: In "real life" scenarios, we only pass the leg sort for non *cast legs
#
# Once we've added all the legs we need to group the selections
# lets say we want to place a single on the scorecast and a permed
# double with the the first leg as a banker.
# First we group the selections
#
#   ie: set grp1 [::ob_bet::add_group $leg2]
#       set grp2 [::ob_bet::add_group $leg1 [list $leg4 $leg3]]
#   selections placed in the same list will not be combined
#
# Next add the bets
#   ::ob_bet::add_bet group_id
#                     bet_type
#                     stake_per_line
#                     stake
#                     leg_type
#                     freebet tokens
#                     max payout
#                     slip id
#
#   ::ob_bet::add_bet $grp1 SGL 1 1  W {} {} {}
#   ::ob_bet::add_bet $grp2 DBL 1 13 W {} {} {}
#
# And then once all the bets have been added
#   ::ob_bet::place_bets uid ip_addr call_id transactional
#   ::ob_bet::place_bets as23432f3432 127.0.0.1
#
# For those of you using the external bet feature to place pools bets via
# the bet packages, you will need to call complete_bets to send these bets
# through to Tote and TRNI. Note that this call should be made only if
# bet placement succeeded and the transactions have been committed.
#
#   ::ob_bet::complete_bets
#
# This will return a list of the bet_ids that failed to place.
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
#    ob_bet::add_leg        Add selections to a leg
#    ob_bet::add_group      Group legs together
#    ob_bet::add_bet        Associate a bet type and stake with a group
#    ob_bet::add_bet_external Add an external (non-sports) bet
#    ob_bet::place_bets     Place added bets
#    ob_bet::check_bets     Check if overrides required for bet
#    ob_bet::get_leg        Get details for leg
#    ob_bet::get_oc         Get details for a selection
#    ob_bet::get_group      Get details for a group of legs
#    ob_bet::get_bet        Get details for a bet
#    ob_bet::complete_bets  Complete external bets after bet placement
#
################################################################################

namespace eval ob_bet {

	namespace export add_leg
	namespace export add_group
	namespace export add_bet
	namespace export complete_bets
	namespace export place_bets
	namespace export check_bets
	namespace export get_leg
	namespace export get_oc
	namespace export get_group
	namespace export get_bet

	variable LEG_NUM_SELNS
	# Note (Support 45355) : those lists are non exhaustive. To avoid the packages
	# rejecting a leg of a "rare" or new sort (h2 for instance), we only pass the
	# leg sort for *cast bets (SC SF RF CF TC CT) as those are the ones for which
	# those checks are really relevant.
	set LEG_NUM_SELNS(1)  [list "" -- CW AH A2 WH OU HL hl MH]
	set LEG_NUM_SELNS(2)  [list SC SF RF]
	set LEG_NUM_SELNS(3)  [list TC CF CT]
	set LEG_NUM_SELNS(4+) [list CT CF]

	# LEG_MAX_COMBI: max_combi max_number_of_total_selns
	# ie we may wish to only FC trebles from a max of 5 selections
	#   [list "Y" 3 5]
	#
	# We may be dealing with permed singles too - in the case of AH
	# we would want to exclude these due to the problems with the split
	# line.  The first item on the list indicates whether thay can be
	# permed at all
	# ie for AH - [list N 1 1]
	# these may be set by ob_bet::config_set
	variable LEG_MAX_COMBI

	# set LEG_MAX_COMBI(AH) [list N 1 1]
	set LEG_MAX_COMBI(SC) [list N 1 1]
	set LEG_MAX_COMBI(CT) [list N 1 1]
	set LEG_MAX_COMBI(TC) [list N 1 1]
	# set LEG_MAX_COMBI(CW) [list N 1 1]
	# Continuos win restriction removed at request of pmu - ARS ticket 33855
}



#API:add_leg - Add a leg
# Usage
# ::ob_bet::add_leg leg_param_list
#
# Add legs for bet placement.
# Note: this is decoupled from the combination of legs - this is determined
#       later when we add groups
#
# Parameters:
# leg_param_list: FORMAT: LIST  DESC: name value list containing the leg parameters.
#
# RETURNS:
# leg number INT
#
# The leg_param_list can be modified by the caller, except for the following pairs:
#     ?-leg_sort <leg_sort>?
#     ?-price_type <price-type>?
#     ?-lp_num <lp_num>?
#     ?-lp_den <lp_den>?
#     ?-hcap_value <hcap_value>?
#     ?-bir_index <bir_index>?
#     ?-banker <banker>?
#     -selns <selns>
#
# See ob_bet::add_leg_param, ob_bet::get_leg_param_names & ob_bet::get_leg_format
# for the management of the add_leg interface
#
# EXAMPLE:
#   add a scorecast of outcomes 150 and 165:
#   set leg2 [::ob_bet::add_leg -leg_sort SC
#                               -price_type L
#                               -lp_num 14
#                               -lp_den 1
#                               -banker N
#                               -selns {150 165}]
#
proc ::ob_bet::add_leg { args } {

	variable LEG_FORMAT

	_log INFO "API(add_leg): $args"

	# check input arguments
	if {[llength $args] % 2 != 0} {
		error "The added leg is not in the correct format"\
			""\
			BET_WRONG_LEG_FORMAT
	}

	array set ARG [list]
	foreach {n v} $args {
		set n [string trimleft $n -]

		if {![info exists LEG_FORMAT($n,type)]} {
			error "Unknown leg parameter -$n"\
				""\
				BET_WRONG_LEG_FORMAT
		}

		_check_arg $n $v\
			$LEG_FORMAT($n,type)\
			$LEG_FORMAT($n,optional)\
			$LEG_FORMAT($n,min)\
			$LEG_FORMAT($n,max)

		set ARG($n) $v
	}

	# -apply defaults
	foreach n $LEG_FORMAT(names) {
		if {![info exists ARG($n)]} {
			if {$LEG_FORMAT($n,optional) == 0 && $LEG_FORMAT($n,def) == ""} {
				error "Missing leg parameter -$n"\
					""\
					BET_WRONG_LEG_FORMAT
			}
			if {$LEG_FORMAT($n,optional) == 0 && $LEG_FORMAT($n,def) != ""} {
				set ARG($n) $LEG_FORMAT($n,def)
			} else {
				set ARG($n) ""
			}
		}
	}


	# add leg
	if {[catch {
		set ret [_add_leg ARG]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:add_group - Group legs into a group
# Usage:
# ::ob_bet::add_group args
#
# The group will determine which legs can and which legs can't be combined
# ie: permed. Legs that can't be combined should be placed in a list.
# The legs are also validated at this point.
#
# Parameters:
# args: a list of legs
#
# RETURNS group id INT
#
# EXAMPLE:
#    We have added Arsenal to Draw to leg 0
#                  Arsenal to Win  to leg 1
#                  RedRum  to Win  to leg 2
#    legs 1 and 2 can't be combined so we want to perm them with leg 2
#    set group [::ob_bet::add_group {0 1} 2]
#
proc ::ob_bet::add_group args {

	# log input params
	_log INFO "API(add_group): $args"

	if {[catch {
		set ret [eval _add_group $args]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:add_bet - Create a bet from a group of legs and a bet type
# Usage:
# ::ob_bet::add_bet group_id
#                   bet_type
#                   stake_per_line
#                   stake
#                   leg_type
#                   tokens
#                   max_payout
#                   slip_id
#
# Adds bets and validates group in bet and correct stake etc ...
# n.b. The bets is NOT placed until place_bets is called so that all
# bets may be placed in one transaction.
#
# Parameters:
# group_id:       FORMAT: INT     DESC: group id returned from add_group
# bet_type:       FORMAT: VARCHAR DESC: tBetType.bet_type ie SGL DBL etc ...
# stake_per_line: FORMAT: NUMERIC DESC: Stake on each line in customers ccy
# stake:          FORMAT: NUMERIC DESC: Total Stake in customers ccy
# leg_type:       FORMAT: W|E|P|Q DESC: tBet.leg_type ie Win Each Way etc...
# tokens:         FORMAT  LIST of INTS
#                 DESC: cust_token_ids to take against this bet
#                 DEFAULT: ""
# max_payout:     FORMAT: NUMERIC DESC: Max payout displayed to customer for
#                                       validation purposes. In the customer's CCY
#                 DEFAULT: ""
# slip_id:        FORMAT: INT
#                 DESC: tslip.slip_id if bet is part of a shop slip
#                 DEFAULT: ""
#
# RETURNS bet number INT
#
proc ::ob_bet::add_bet {
	group_id
	bet_type
	stake_per_line
	stake
	leg_type
	{tokens ""}
	{max_payout ""}
	{slip_id ""}
	{pay_for_ap "Y"}
	{bet_group_id ""}
} {

	# log the input parameters
	set log_msg "API(add_bet): $group_id,$bet_type,$stake_per_line,"
	append log_msg "$stake,$leg_type,$tokens,$max_payout,$slip_id,$bet_group_id"
	_log INFO $log_msg


	# check input arguments
	#          name           value           type      nullable min max
	_check_arg group_id       $group_id       INT       0        0
	_check_arg bet_type       $bet_type       CHAR      0        3   5
	_check_arg stake_per_line $stake_per_line CCY       0
	_check_arg stake          $stake          CCY       0
	_check_arg leg_type       $leg_type       CHAR      0        1   1
	_check_arg tokens         $tokens         LIST_INTS 1
	_check_arg max_payout     $max_payout     CCY       1
	_check_arg slip_id        $slip_id        INT       1
	_check_arg pay_for_ap     $pay_for_ap     YN        0
	_check_arg bet_group_id   $bet_group_id   INT       1        0

	if {[catch {
		set ret [eval _add_bet\
		             {$group_id}\
		             {$bet_type}\
		             {$stake_per_line}\
		             {$stake}\
		             {$leg_type}\
		             {$tokens}\
		             {$max_payout}\
		             {$slip_id}\
		             {$pay_for_ap}\
		             {$bet_group_id}]
	} msg]} {
		_err $msg
	}
	return $ret
}

#API:add_bet_external - Add an external bet.
#
# Parameters:
#
#   externalFlavour - What kind of external bet (see ob_bet::reg_external).
#   externalRef     - Some unique means by which the code which knows how to
#                     handle this flavour of bet can identify this bet, or ""
#                     if not required.
#   slip_id         - Something to do with retail. Optional.
#
# Returns:
#
#   bet number      - INT
#
# Notes:
#
#   Sometimes non-sports bets such as xgame or pools bets need to be placed
#   at the same time as regular sports bets. These non-sports bets are known
#   as "external bets" from the point-of-view of the bet packages.
#
#   It's useful to add the external bets to the bet packages so that the bet
#   packages can handle funds checks and overrides for them, and also so that
#   they can be placed in the same transaction as the sports bets.
#
#   *ob_bet::reg_external* can be used to register a particular "flavour" of
#   external bet (e.g. MAN or XGAMES). This involves supplying procs that the
#   bet packages can call to check & place external bets of that flavour.
#
#   *ob_bet::add_bet_external* can then be used to add external bets to the
#   packages. These will be checked and placed along with the other bets when
#   *ob_bet::check_bets* and *ob_bet::place_bets* are called.
#
proc ::ob_bet::add_bet_external {externalFlavour externalRef {slip_id ""}} {

	if {[catch {
		set ret \
		  [_add_bet_external $externalFlavour $externalRef $slip_id]
	} msg]} {
		_err $msg
	}

	return $ret
}


#API:place_bets Place all the bets added by add_bet
#
#Usage
#  ::ob_bet::place_bets uid ip_addr
#
# Will place all bets added by add_bet in a transaction.
# If at least one bets has a bet_delay, then the ALL the bets will be added to
# then bet_delay rquest queue. The bet_delay application will place these bets
# in 'bet_delay' seconds.
#
# Parameters:
# uid:      FORMAT: VARCHAR DESC: unique id on betslip to make sure not
#                                 submitted twice
# ip_addr:  FORMAT: IPADDR  DESC: IP address from which the request originated
# call_id:  FORMAT: INT     DESC: tbet.call_id
# term_code FORMAT: VARCHAR DESC: tAdminTerm.term_code
# placed_by FORMAT: INT     DESC: adminUser placing bet tAdminUser.user_id
# trans     FORMAT: 1|0     DESC  1 - deal with transaction within module
#                                 0 - transaction handling dealt with externally
# topup_pmt_id
#           FORMAT: INT     DESC: pmt_id from topup/quickdeposit
#
# RETURNS:
#   non-zero number of bets placed successfully
#   if 0 then:
#    - all bets where added to bet_delay request queue
#      call ::ob_bet::bir_get_bet_delay and ::ob_bet::bir_get_req_id to detemine
#      if added to the queue
#    - 1 or more items need to be overriden
#
proc ::ob_bet::place_bets {
	uid
	ip_addr
	{call_id {}}
	{term_code {}}
	{placed_by {}}
	{trans 1}
	{aff_id {}}
	{locale {}}
	{topup_pmt_id {}}
} {

	# log the input parameters
	_log INFO "API(place_bets): $uid,$ip_addr"

	# check input arguments
	#          name       value       type      nullable min max
	_check_arg uid        $uid        CHAR      1
	_check_arg ip_addr    $ip_addr    IPADDR    0
	_check_arg call_id    $call_id    INT       1        0
	_check_arg term_code  $term_code  CHAR      1        1   16
	_check_arg placed_by  $placed_by  INT       1        0
	_check_arg trans      $trans      INT       0        0   1

	if {[catch {
		_check_arg aff_id    $aff_id    INT       1
	} msg]} {
		# bet placement should stop just because of a duff aff_id
		set aff_id ""
	}

	if {[catch {
		set ret [eval _place_bets\
		             {$uid}\
		             {$ip_addr}\
		             {$call_id}\
		             {$term_code}\
		             {$placed_by}\
		             {$trans}\
		             {$aff_id}\
		             {$locale}\
		             {$topup_pmt_id}]
	} msg]} {
		_err $msg
	}
	return $ret
}


#API:complete_bets Complete all the external bets
#
#Usage
#  ::ob_bet::complete_bets
#
# Complete any external bets. This is specifically for pools bets that
# have to be placed outside of the main transaction as they call 3rd parties
# to complete their bet placement.
# Note that this means it is possible for all sports bets to have placed
# and been committed successfully, but pools bets to subsequently fail.
# Unfortunately, there's not much we can do about that.
# Note that it is also possible for the sports bets to be delayed due to
# BIR bets, but the pools bets will be completed immediately, regardless
# of the delays.
# Note that if place_bet returns ret == 0, the transaction will have been
# rolled back so no completing will be required.
#
# RETURNS:
#   number of external bets that _failed_ to place
#
proc ::ob_bet::complete_bets {} {

	# log the input parameters
	_log INFO "API(complete_bets)"

	return [_complete_bets]
}



#API:check_bets Validate enough funds for bets, correct stk etc ...
#
#Usage:
#  ::ob_bet::check_bets
#
# Checks the correct stake, customer details and available funds
#
# RETURNS:
#    list {tot_stk: required funds to place the bet,
#	  total_bets: total number of bets.}
#
proc ::ob_bet::check_bets {} {

	# log the input parameters
	_log INFO "API(check_bets)"

	if {[catch {
		set ret [eval _check_bets]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_leg Get details of a leg.
# Usage
# ::ob_bet::get_leg leg_no param
#
# Parameters:
# leg_no:  FORMAT: INT     DESC: Leg number to investigate
# param:   FORMAT: VARCHAR
#          DESC: price_type, min_combi, max_combi, hcap_value
#                num_lines_per_seln, num_lines, banker, lp_num
#                lp_den,num_selns,bir_index,selns,leg_sort
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_leg 0 selns
# 1 {145 148}
# > ::ob_bet::get_leg 5 lp_num
# 0 "" # not found
proc ::ob_bet::get_leg {leg_no param} {

	# log input params
	_log INFO "API(get_leg): $leg_no,$param"

	if {[catch {
		set ret [eval _get_leg {$leg_no} {$param}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_oc Get selection details
# Usage
# ::ob_bet::get_oc ev_oc_id param
#
# Parameters:
# ev_oc_id FORMAT: INT     DESC: tevoc.ev_oc_id
# param:   FORMAT: VARCHAR
#          DESC: acc_max, acc_min ,bir_index,class_sort,cs_away
#                cs_home,ev_class_id,ev_desc,ev_id,ev_mkt_id
#                ev_mult_key,ev_oc_id,ev_started,ev_suspended,ev_type_id
#                ew_avail,fb_result,fc_avail,hcap_value,in_running,is_off
#                lp_avail,lp_den,lp_num,max_bet,max_sp_bet,min_bet
#                mkt_desc,mult_key,oc_desc,pl_avail,sp_avail,start_time
#                tc_avail status
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_oc 341 lp_avail
# 1 Y
# > ::ob_bet::get_oc 1   oc_desc
# 0 "" # not found
proc ::ob_bet::get_oc {ev_oc_id param} {

	# log input params
	_log INFO "API(get_oc): $ev_oc_id,$param"

	if {[catch {
		set ret [eval _get_oc {$ev_oc_id} {$param}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_group Get information on group of legs
# Usage
# ::ob_bet::get_group group_id param
#
# Parameters:
# group_id FORMAT: INT     DESC: group formed by calling ob_bet::add_group
# param:   FORMAT: VARCHAR DESC: TO DO
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_group 0 max_combi
# 1 20
# > ::ob_bet::get_group 13 ew_avail
# 0 "" # not found
proc ::ob_bet::get_group {group_id param} {

	# log input params
	_log INFO "API(get_group): $group_id,$param"

	if {[catch {
		set ret [eval _get_group {$group_id} {$param}]
	} msg]} {
		_err $msg
	}
	return $ret
}





#API:get_bet Get information on bets added
# Usage
# ::ob_bet::get_bet bet_id param
#
# Parameters:
# bet_id   FORMAT: INT     DESC: id returned from ob_bet::add_bet
# param:   FORMAT: VARCHAR DESC: TO DO
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_bet 0 receipt
# 1 O/0004209/0000004
# > ::ob_bet::get_bet 3 stake
# 0 "" # not found
proc ::ob_bet::get_bet {bet_id param}  {

	# log input params
	_log INFO "API(get_bet): $bet_id,$param"

	if {[catch {
		set ret [eval _get_bet {$bet_id} {$param}]
	} msg]} {
		_err $msg
	}
	return $ret
}

#API:get_bets_added Get list of bets added with ob_bet::add_bet.
# Usage:
#   ::ob_bet::get_bets_added
#
# Parameters:
#   None.
#
# RETURNS:
#   List of bet numbers (as returned by ob_bet::add_bet).
#
proc ::ob_bet::get_bets_added {}  {

	#log input params
	#_log INFO "API(gets_bets_added)"

	if {[catch {
		set ret [_get_bets_added]
	} msg]} {
		_err $msg
	}
	return $ret
}

#END OF API..... private procedures



# Prepare place DB queries
#
proc ob_bet::_prepare_place_qrys {} {

	ob_db::store_qry ob_bet::ins_bet {
		execute procedure pInsOBet(
		  p_tax_type       = 'S',
		  p_do_liab        = 'N',
		  p_tax            = 0.0,
		  p_tax_rate       = 0,
		  p_bir_req_id     = ?,
		  p_placed_by      = ?,
		  p_source         = ?,
		  p_max_payout     = ?,
		  p_unique_id      = ?,
		  p_ipaddr         = ?,
		  p_cust_id        = ?,
		  p_acct_id        = ?,
		  p_bet_type       = ?,
		  p_num_nocombi    = ?,
		  p_num_selns      = ?,
		  p_num_legs       = ?,
		  p_num_lines      = ?,
		  p_stake          = ?,
		  p_stake_per_line = ?,
		  p_token_value    = ?,
		  p_no_combi       = ?,
		  p_leg_no         = ?,
		  p_leg_sort       = ?,
		  p_part_no        = ?,
		  p_ev_oc_id       = ?,
		  p_ev_id          = ?,
		  p_ev_mkt_id      = ?,
		  p_price_type     = ?,
		  p_o_num          = ?,
		  p_o_den          = ?,
		  p_hcap_value     = ?,
		  p_bir_index      = ?,
		  p_leg_type       = ?,
		  p_bets_per_seln  = ?,
		  p_banker         = ?,
		  p_ep_active      = ?,
		  p_ew_fac_num     = ?,
		  p_ew_fac_den     = ?,
		  p_ew_places      = ?,
		  p_term_code      = ?,
		  p_receipt_format = ?,
		  p_receipt_tag    = ?,
		  p_slip_id        = ?,
		  p_bet_id         = ?,
		  p_aff_id         = ?,
		  p_in_running     = ?,
		  p_call_id        = ?,
		  p_pay_now        = ?,
		  p_async_park     = ?,
		  p_park_reason    = ?,
		  p_locale         = ?,
		  p_bet_count      = ?,
		  p_potential_payout = ?,
		  p_max_bet        = ?,
		  p_stake_factor   = ?,
		  p_async_timeout    = ?
		)
	}

	ob_db::store_qry ob_bet::ins_bet_group {

		execute procedure pInsBetSlipBet(
		  p_betslip_id  = ?,
		  p_bet_id      = ?
		)

	}

	ob_db::store_qry ob_bet::remove_bet_from_queue {
		delete from
			tBetAsync
		where
			bet_id = ?
	}

}



# Add the leg
#
proc ::ob_bet::_add_leg { arg } {

	variable LEG
	_smart_reset LEG

	variable LEG_NUM_SELNS
	variable LEG_FORMAT

	# parameters
	upvar 1 $arg ARG

	# make sure we're not added the same selection multiple times to the leg
	set num_selns [llength $ARG(selns)]
	if {$num_selns > 1} {
		for {set i 0} {$i < $num_selns} {incr i} {
			set this_seln [lindex $ARG(selns) $i]
			for {set j [expr {$i+1}]} {$j < $num_selns} {incr j} {
				if {$this_seln == [lindex $ARG(selns) $j]} {
					error\
					    "Duplicate selection in leg: $this_seln"\
					    ""\
					    PLACE_DUP_SELN_IN_LEG
				}
			}
		}
	}

	# make sure we are supplying the price type for comlex legs
	# This should never be ambiguous so should never not be supplyed
	if {$num_selns > 1 && $ARG(price_type) == ""} {
		error\
			"No price type for complex leg"\
			""\
			PLACE_NO_COMPLEX_PRICE_TYPE
	}
	if {$num_selns == 0} {
		error\
			"no selections added"\
			""\
			PLACE_NO_SELNS
	} elseif {
		$num_selns < 4 &&
		[lsearch $LEG_NUM_SELNS($num_selns) $ARG(leg_sort)] == -1
	} {
		error\
			"Wrong number of selections for leg sort $ARG(leg_sort)"\
			""\
			PLACE_WRONG_NUM_SELNS
	} elseif {
		$num_selns >= 4 &&
		[lsearch $LEG_NUM_SELNS(4+) $ARG(leg_sort)] == -1
	} {
		error\
			"Wrong number of selections for leg sort $ARG(leg_sort)"\
			""\
			PLACE_WRONG_NUM_SELNS
	}

	switch -- $ARG(leg_sort) {
		"RF" {
			set num_lines 2
			set num_lines_per_seln 2
		}
		"CF" {
			# multiply by 2 to give the reverse legs too
			# ie with three horses a,b,c
			# ab ac bc and
			# ba ca cb
			set num_lines [expr {[ot::countCombis 2 $num_selns] * 2}]

			# given n selections one of which being x - x will be combined
			# with n-1 selns
			set num_lines_per_seln [expr {($num_selns-1) * 2}]
		}
		"CT" {
			# multiply by 6 to give all the combinations of the tricast
			# abc acb bac bca cab cba
			set num_lines [expr {[ot::countCombis 3 $num_selns] * 6}]
			set combis [ot::countCombis 2 [expr {$num_selns-1}]]
			set num_lines_per_seln [expr {$combis * 6}]
		}
		default {
			set num_lines 1
			set num_lines_per_seln 1
		}
	}

	_log INFO "adding leg outcomes: $ARG(selns) to leg $LEG(num) ..."

	set leg_num $LEG(num)

	set num_selns 0
	foreach s $ARG(selns) {
		lappend LEG(selns) $s
		incr num_selns
	}

	foreach f {
		leg_sort
		price_type
		lp_num
		lp_den
		hcap_value
		bir_index
		banker
		ew_fac_num
		ew_fac_den
		ew_places
		prev_lp_num
		prev_lp_den
		prev_hcap_value
	} {
		set LEG($leg_num,$f) $ARG($f)
	}
	set LEG($leg_num,selns) $ARG(selns)
	set LEG($leg_num,num_lines) $num_lines
	set LEG($leg_num,num_lines_per_seln) $num_lines_per_seln
	set LEG($leg_num,num_selns) $num_selns

	# adding selections we will need to reretrieve info from DB
	_clear 1

	incr LEG(num)
	return $leg_num
}

# Add legs to a group
#
proc ::ob_bet::_add_group args {

	variable GROUP
	variable LEG
	variable SELN
	variable COMBI
	variable CONFIG
	variable CUST_DETAILS

	set max_payout 9999999

	# assume we're finished adding selections
	_verify_selns
	_get_combis

	_smart_reset GROUP

	::ob_bet::_log INFO "adding legs $args to group $GROUP(num) ..."
	set group_id $GROUP(num)

	# mult key indicates selections that cannot be combined
	set sg 0
	set num_sgs   0
	set num_legs  0
	set num_selns 0
	set mult_key  0

	set banker_sgs [list]
	set non_banker_sgs [list]
	set legs [list]
	set num_bankers 0
	set max_combi [_get_config max_mult_selns]
	set max_selns [_get_config max_mult_selns]
	set min_combi 1
	set ah_split_line "N"
	set is_ap "Y"

	# going to define for future bets per selection purposes
	# a group is simple if it doesn't have any multi-part legs
	# nor any selections that can't be combined
	set simple 1
	set price_avail "Y"
	set all_ew_avail [expr {1 == 1}]
	set any_ew_avail [expr {0 == 1}]

	foreach sub_grp $args {
		set num_legs_in_sg [llength $sub_grp]
		incr num_legs $num_legs_in_sg
		set num_lines 0
		set sg_price 0
		array set sg_prices [list]
		set pot_return_place 0
		catch {unset pot_returns_place}
		array set pot_returns_place [list]
		set banker "N"
		set pl_avail "Y"

		foreach l $sub_grp {
			# for AH split_line we need to frig the number of lines
			if {[info exists LEG($l,ah_split_line)]} {
				set ah_split_line "Y"
			}

			# check leg can be combined with other legs
			# that aren't in this sub group
			# also make sure it is not being combined with itself
			# only need to check subgroups to come as legs being allowed
			# to be combined is reciprical and would have already been
			# checked in the earlier groups
			for {set i [expr {$sg + 1}]} {$i < [llength $args]} {incr i} {
				foreach l2 [lindex $args $i] {
					_log DEV "checking $l can be combined with $l2"
					if {[lsearch $COMBI($l,no_combi_legs) $l2] != -1} {
						error\
							"Cannot combine leg $l and leg $l2"\
							""\
							PLACE_INVALID_LEG_COMBI
					}
				}
			}

			incr num_lines $LEG($l,num_lines)
			if {$LEG($l,num_lines) != 1} {
				set simple 0
			}
			incr num_selns $LEG($l,num_selns)

			if {$banker == "N"} {
				set banker $LEG($l,banker)
			}
			lappend GROUP($group_id,$sg,legs) $l
			lappend legs $l

			#max payout
			foreach seln $LEG($l,selns) {
				set max_payout [expr {$max_payout < $SELN($seln,max_payout)
				                      ? $max_payout
				                      : $SELN($seln,max_payout)}]

				if {$SELN($seln,is_ap_mkt) == "N"} {
					set is_ap "N"
				}
			}

			# max min combi
			set min_combi\
				[expr {$min_combi > $LEG($l,min_combi)
				       ? $min_combi
				       : $LEG($l,min_combi)}]
			set max_combi\
				[expr {$max_combi < $LEG($l,max_combi)
				       ? $max_combi
				       : $LEG($l,max_combi)}]
			set max_selns\
				[expr {$max_selns < $LEG($l,max_selns)
				       ? $max_selns
				       : $LEG($l,max_selns)}]

			#ew/place available?
			set leg_ew_avail [expr {$LEG($l,ew_avail) == "Y"}]
			set all_ew_avail [expr {$all_ew_avail && $leg_ew_avail}]
			set any_ew_avail [expr {$any_ew_avail || $leg_ew_avail}]

			if {$LEG($l,pl_avail) == "N"} {
				set pl_avail "N"
			}

			# Effective price of the sub group for calculating
			# potential winnings.
			if { [info exists LEG($l,pot_lp_num)] && \
			     $LEG($l,pot_lp_num) != "" } {

				set potential_win [expr {
					$LEG($l,pot_lp_num) / double($LEG($l,pot_lp_den))
				}]

				set leg_price [expr {
					$potential_win + 1.0
				}]

				if {
					[info exists LEG($l,ew_fac_num)] &&
					[info exists LEG($l,ew_fac_den)] &&
					$LEG($l,ew_fac_num) > 0          &&
					$LEG($l,ew_fac_den) > 0
				} {
					set ew_factor [expr {
						double($LEG($l,ew_fac_num)) /
						$LEG($l,ew_fac_den)
					}]
					set ret_place [expr {
						$potential_win * $ew_factor + 1.0
					}]
				} else {
					set ret_place 0
				}

			} else {
				set price_avail "N"
			}

			# Potential Winnings - why we (sometimes) over-estimate.
			#
			# We know that the caller doesn't want legs in the same
			# sub-group to be combined in the same line. However, we
			# don't know /why/ these legs shouldn't be combined -
			# in particular, we can't always distinguish between:
			#
			#  A) One leg winning would make another leg more likely
			#     to win (and hence multiplying their prices together
			#     would be dangerous for the bookmaker).
			#     [e.g. "Arsenal to beat Man Utd", and "the correct
			#     score to be 1 - 0 to Arsenal".]
			#   B) Two of the legs are mutually exclusive - if one
			#      wins, the other cannot (and hence no sensible
			#      person would want them in the same line).
			#     [e.g. "Arsenal to beat Man Utd", and "the correct
			#     score to be 1 - 0 to Man Utd".]
			#   C) The punter doesn't want the legs combined for his
			#      own personal reasons.
			#
			# This is a problem when it comes to calculating potential
			# winnings for the bet as a whole, since if we have one line
			# that contains a leg that is mutually exclusive with a leg
			# in another line, then we should not add together the
			# potential winnings of the two lines (since the lines can't
			# both happen). Instead, we should take the greater of the
			# two lines' potential winnings. But to do this correctly
			# requires us to identify pairs of legs that shouldn't be
			# combined specifically because they are mutually exclusive
			# (as in case B above) - and as we've said, we don't have
			# enough information to do that.
			#
			# What we'll do (for now, at least) is apply a simple rule -
			# if (and only if) two legs are in the same market will we
			# assume that they are mutually exclusive. This will cover
			# the common case of two horses from the same race - we won't
			# make the mistake of thinking they can both win, and if we
			# have a line with one of those horses, and another line with
			# the other horse, then we'll use the winnings from whichever
			# of the two lines has the higher price. But we will over-
			# estimate the potential winnings if (for example) we have
			# one line with "Arsenal to beat Man Utd" and another line
			# with "Arsenal to lose by two goals (against Man Utd)" -
			# the potential winnings calculations will mistakenly include
			# the winnings from both those lines.
			#
			# Unfortunately, actually calculating them correctly would
			# seem to be an impossible task without holding an awfully
			# large amount of information about the underlying real-world
			# meaning of the various selections.

			if {$price_avail != "N"} {
				set ev_mkt_id $SELN([lindex $LEG($l,selns) 0],ev_mkt_id)
				if {(![info exists sg_prices($ev_mkt_id)])
				    || $leg_price > $sg_prices($ev_mkt_id)} {
					set sg_prices($ev_mkt_id) $leg_price
				}

				if { ![info exists pot_returns_place($ev_mkt_id)] ||
					 $ret_place > $pot_returns_place($ev_mkt_id)
				} {
					set pot_returns_place($ev_mkt_id) $ret_place
				}

			}
		}

		# work out sub-group price for potential winnings
		foreach ev_mkt_id [array names sg_prices] {
			set sg_price [expr {$sg_price + $sg_prices($ev_mkt_id)}]
		}
		unset sg_prices

		foreach ev_mkt_id [array names pot_returns_place] {
			set pot_return_place [expr {
				$pot_return_place + $pot_returns_place($ev_mkt_id)
			}]
		}
		unset pot_returns_place

		if {$banker == "Y"} {
			#check there are no bankers in a non combinable group
			if {$num_legs_in_sg != 1} {
				error\
					"Cannot have a banker not combinable with all: $l"\
					""\
					PLACE_BANKER_IN_COMBI
			}
			lappend banker_sgs $sg
			incr num_bankers
		} else {
			lappend non_banker_sgs $sg
		}

		if {$num_legs_in_sg == 1} {
			set GROUP($group_id,$sg,mult_key) ""
		} else {
			set GROUP($group_id,$sg,mult_key) $mult_key
			set simple 0
			incr mult_key
		}

		if {$price_avail != "N"} {
			set GROUP($group_id,$sg,price)     $sg_price
			set GROUP($group_id,$sg,pot_return_place) $pot_return_place
		}

		set GROUP($group_id,$sg,banker)    $banker
		set GROUP($group_id,$sg,num_legs)  $num_legs_in_sg
		set GROUP($group_id,$sg,num_lines) $num_lines

		incr num_sgs
		incr sg
	}

	if {[_get_config ew_mixed_multiple] == "Y"} {
		set ew_avail [expr {$any_ew_avail ? "Y" : "N"}]
	} else {
		set ew_avail [expr {$all_ew_avail ? "Y" : "N"}]
	}

	set GROUP($group_id,num) $num_sgs
	set GROUP($group_id,num_legs) $num_legs
	set GROUP($group_id,legs) $legs
	set GROUP($group_id,num_selns) $num_selns
	set GROUP($group_id,num_nocombi) $mult_key
	set GROUP($group_id,banker_sgs) $banker_sgs
	set GROUP($group_id,non_banker_sgs) $non_banker_sgs
	set GROUP($group_id,num_bankers) $num_bankers
	set GROUP($group_id,simple) $simple
	set GROUP($group_id,ew_avail) $ew_avail
	set GROUP($group_id,pl_avail) $pl_avail
	set GROUP($group_id,ah_split_line) $ah_split_line
	set GROUP($group_id,price_avail) $price_avail
	set GROUP($group_id,is_ap) $is_ap
	set GROUP($group_id,max_payout) $max_payout
	set GROUP($group_id,max_combi) $max_combi
	set GROUP($group_id,min_combi) $min_combi
	set GROUP($group_id,max_selns) $max_selns
	set GROUP($group_id,bets) [list]

	incr GROUP(num)

	return $group_id
}



# Add group to a bet
#
proc ::ob_bet::_add_bet {
	group_id
	bet_type
	stake_per_line
	stake
	leg_type
	tokens
	max_payout
	slip_id
	pay_for_ap
	bet_group_id
} {
	variable GROUP
	variable BET
	variable CUST_DETAILS

	_smart_reset BET

	if {![info exists GROUP($group_id,num_legs)]} {
		error\
			"group $group_id not described"\
			""\
			PLACE_NO_GROUP
	}

	# check the leg type
	set line_factor 1
	if {$leg_type == "P" && !($GROUP($group_id,pl_avail) == "Y" ||
	    ([_get_config allow_pl_on_ew] == "Y" && $GROUP($group_id,ew_avail) == "Y"))} {
		error\
			"place not available"\
			""\
			PLACE_PLACE_NOT_AVAIL
	}

	if {$leg_type == "E"} {
		if {$GROUP($group_id,ew_avail) != "Y"} {
			error\
				"each way not available"\
				""\
				PLACE_EW_NOT_AVAIL
		}
		set line_factor 2
	}

	# OTHER: check other leg types inc. Q

	# For AH bets - we need to check if it's split line bet
	# we will place the bet as two lines stake_per_line will
	# need to be divisable by 2
	if {$GROUP($group_id,ah_split_line) == "Y"} {
		if {round($stake_per_line * 100) % 2 != 0} {
			error\
				"AH split line bets need an even stake"\
				""\
				AH_SPLIT_LINE_ODD_STAKE
		}
		# if we're allowing AH multiples, we don't want to have two legs
		if {[_get_config "ah_split_line_two_legs"] == "Y"} {
			set line_factor 2
			set stake_per_line [expr {$stake_per_line / 2.0}]
		}
	}

	set bet_id                      $BET(num)
	set BET($bet_id,flavour)        "SPORTS"
	set BET($bet_id,group_id)       $group_id
	set BET($bet_id,bet_type)       $bet_type
	set BET($bet_id,stake_per_line) $stake_per_line
	set BET($bet_id,stake)          [format %.2f $stake]
	set BET($bet_id,leg_type)       $leg_type
	set BET($bet_id,line_factor)    $line_factor
	set BET($bet_id,tokens)         $tokens
	set BET($bet_id,max_payout)     $max_payout
	set BET($bet_id,slip_id)        $slip_id
	set BET($bet_id,pay_for_ap)     $pay_for_ap
	set BET($bet_id,bet_group_id)   $bet_group_id

	# should the bet be added to bet_delay request queue, i.e. has at least 1
	# selection with a bir_delay
	if {[_get_config server_bet_delay] == "Y"} {
		_bir_set_bet_delay $bet_id
	}

	# e/w leg type, then check if e/w terms have changed
	if {$BET($bet_id,leg_type) == "E"} {
		_check_ew [lsort -unique -integer $GROUP($group_id,legs)]
	}

	lappend GROUP($group_id,bets) $bet_id

	incr BET(num)

	return $bet_id
}

# Add an external bet.
proc ::ob_bet::_add_bet_external {externalFlavour externalRef slip_id} {

	variable BET
	variable CONFIG

	_smart_reset BET

	if {![info exists CONFIG(ext,$externalFlavour,placeCmd)]} {
		error "Unknown externalFlavour \"$externalFlavour\",\
			did you call ob_bet::reg_external?"
	}

	set bet_id $BET(num)

	if {$externalRef != ""} {
		if {[info exists BET(ext,$externalRef)]} {
			error "Already added a \"$externalFlavour\" external bet\
				with ref \"$externalRef\""
		}
		set BET(ext,$externalRef) $bet_id
	}

	set BET($bet_id,flavour)     $externalFlavour
	set BET($bet_id,externalRef) $externalRef
	set BET($bet_id,slip_id)     $slip_id
	set BET($bet_id,tokens)      ""

	incr BET(num)

	return $bet_id
}

# Place the bets.
#
proc ::ob_bet::_place_bets {
	uid
	ip_addr
	call_id
	term_code
	placed_by
	trans
	aff_id
	locale
	topup_pmt_id
} {
	variable BET
	variable CUST

	variable LEG
	variable SELN
	variable GROUP

	if {[_smart_reset BET] || $BET(num) == 0} {
		error\
			"No bets have been added call ::ob_bet::add_bet"\
			""\
			PLACE_NO_BETS
	}
	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			PLACE_NO_CUST
	}

	# are we going to initiate the transaction here
	# or elsewhere
	set BET(trans) $trans

	# make sure betting available in the control table
	if {[ob_control::get bets_allowed] != "Y"} {
		error\
			"Control table - betting not allowed"\
			""\
			PLACE_CONTROL_NO_BETTING
	}



	# if we're retrieving all event data over it's dangerous to accept bets if the oxi
	# feed is down as the event may have started and we haven't received the status/is_off
	# change. Clearly betting in running is also dangerous.
	if {[OT_CfgGet REPL_ALLOW_PANIC_MODE 0] && [check_panic_mode]} {
		# if we're in panic mode we loop over all events and check the start time
		# and if it's in the past or has a BIR market we error
		# clock scan "2037-12-31 23:59:59" --> 2145916799

		set start_time_min 2145916799
		set is_bir "N"

		for {set b 0} {$b < $BET(num)} {incr b} {
			set group_id $BET($b,group_id)
			for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
				foreach leg $GROUP($group_id,$sg,legs) {
					foreach seln $LEG($leg,selns) {
						set start_time_secs [clock scan $SELN($seln,start_time)]

						if {$start_time_secs < $start_time_min} {
							set start_time_min $start_time_secs
						}

						if {$SELN($seln,in_running) == "Y" &&  \
							($SELN($seln,is_off) == "Y" || \
							($SELN($seln,is_off) == "-" && $start_time_secs < [clock seconds]))} {
							set is_bir "Y"
						}
					}
				}
			}
		}

		if {[clock seconds] > $start_time_min} {
			error\
			"Replication slow down : Failed to place bet after event start time"\
			""\
			PANIC_MODE_PANIC_TIME
		}

		if {$is_bir} {
			error\
			"Replication slow down : Failed to place bet in running bet"\
			""\
			PANIC_MODE_PANIC_BIR
		}

	}

	# placebet transaction
	if {[catch {set ret [_place_bets_tran\
							 $uid\
							 $ip_addr\
							 $placed_by\
							 $term_code\
							 $call_id\
							 $aff_id\
							 $locale\
							 $topup_pmt_id]} msg]} {
		_abort

		if {$::errorCode != "NONE"} {
			set code $::errorCode
		} else {
			set code PLACE_BET_ABORT
		}

		error\
			"Bet placement aborted: $msg"\
			""\
			$code
	}

	for {set b 0} {$b < $BET(num)} {incr b} {
		if {$BET($b,flavour) == "SPORTS"} {
			if { $BET($b,async_park) == "Y" } {
				_log WARNING\
					"bets not placed - async referred to trader"
			}
		}
	}

	if {$BET(bet_delay) && $BET(bir_req_id) != ""} {
		_log WARNING\
			"bets not placed - $BET(num) bets added to bet_delay queue (bir_req_id=$BET(bir_req_id))"
		set ret [list -1 $BET(bir_req_id) $BET(bet_delay)]
	} elseif {$ret} {
		_log INFO "$BET(num) bets placed successfully"
		set ret $BET(num)
	} else {
		_log ERROR "bets not placed - overrides exist"
		set ret 0
	}

	return $ret
}

proc ::ob_bet::_complete_bets {} {
	variable BET
	variable CONFIG

	set failed_bets [list]
	for {set b 0} {$b < $BET(num)} {incr b} {
		if {$BET($b,flavour) == "SPORTS"} {
			continue
		}

		set completeCmd $CONFIG(ext,$BET($b,flavour),completeCmd)
		if {$completeCmd == ""} {
			continue
		}

		if {[catch {eval $completeCmd $BET($b,ext_bet_id)} msg]} {
			_log ERROR "Failed to complete bet: $msg"
			lappend failed_bets $b
		}
	}

	if {[llength $failed_bets] > 0} {
		_log ERROR "There were [llength $failed_bets] problem(s) completing external bets"
	}

	return $failed_bets
}

# Transactional side of bet placement
#
proc ::ob_bet::_place_bets_tran {
	uid
	ip_addr
	placed_by
	term_code
	call_id
	aff_id
	locale
	topup_pmt_id
} {
	variable LEG
	variable SELN
	variable GROUP
	variable TYPE
	variable BET
	variable CUST
	variable CUST_DETAILS
	variable CONFIG

	# start the transactions
	_start

	# lock the account
	_lock_acct

	# make sure we retrieve the customer details in the transaction
	# we shouldn't get them twice as during a placebet transaction
	# the only thing that should trigger customer details retrieval
	# will be _get_types_for_group retrieving the max/min
	# stake for that cust.  This is called down below.
	array unset CUST_DETAILS
	foreach {tot_stk bet_num} [_check_bets] { break }

	# check overrides
	if {[_get_overrides] != {}} {
		# some overrides have not yet been overriden safe to commit the trasaction
		# rather than rollback as no bets have been updated yet
		_abort
		return 0
	}

	# should these bets be added to the bet_delay request queue.
	# - will be placed by the bet_delay application in 'bet_delay' seconds
	if {$BET(bet_delay)} {
		_bir_ins_req $ip_addr $tot_stk $topup_pmt_id
	}

	set freebet_ev_ocs [list]

	set bet_count 1
	set external_bet_count 1
	for {set b 0} {$b < $BET(num)} {incr b} {

		# Call the registered handler for any "external" bets.

		set flavour $BET($b,flavour)
		if {$flavour != "SPORTS"} {

			set placeCmd $CONFIG(ext,$flavour,placeCmd)
			set externalRef $BET($b,externalRef)

			_log INFO "**************************************"
			_log INFO "placing $flavour bet"
			_log INFO "externalRef $externalRef"
			_log INFO "placed_by   $placed_by"
			_log INFO "cust_id     $CUST(cust_id)"
			_log INFO "uid         $uid"
			_log INFO "cost        $BET($b,ext_cost)"

			set ret [eval $placeCmd \
				[list $b $externalRef \
					[list \
						cust_id    $CUST(cust_id) \
						uid        $uid \
						ip_addr    $ip_addr \
						placed_by  $placed_by \
						term_code  $term_code \
						call_id    $call_id \
						slip_id    $BET($b,slip_id) \
						aff_id     $aff_id \
						bet_count  $external_bet_count]]]

			set BET($b,ext_bet_id) [lindex $ret 0]
			set BET($b,receipt)    [lindex $ret 1]

			_log INFO "placed $flavour bet $BET($b,ext_bet_id) $BET($b,receipt)"
			_log INFO "**************************************"

			# NB - We don't call freebets for external bets.
			incr external_bet_count

			continue
		}

		set freebet_ev_ocs [list]

		set group_id $BET($b,group_id)
		set bet_id ""
		set leg_no 1

		if {
			$CUST_DETAILS(acct_type) == "CDT" &&
		    $BET($b,pay_for_ap)      == "N" &&
		    ($GROUP($group_id,is_ap) == "Y" || [_get_config credit_pay_stake_later] == "Y")
		} {
			set pay_now "N"
		} else {
			set pay_now "Y"
		}

		_log INFO "**************************************"
		_log INFO "placing bet"
		_log INFO "placed_by     $placed_by"
		_log INFO "bet type      $BET($b,bet_type)"
		_log INFO "cust_id       $CUST(cust_id)"
		_log INFO "uid           $uid"
		_log INFO "stake pl      $BET($b,stake_per_line)"
		_log INFO "num lines     $BET($b,num_lines)"
		_log INFO "token val     $BET($b,token_val)"
		_log INFO "stake         $BET($b,stake)"
		_log INFO "leg type      $BET($b,leg_type)"
		_log INFO "max p'out     $BET($b,max_payout)"
		_log INFO "num_selns     $GROUP($group_id,num_selns)"
		_log INFO "num_legs      $GROUP($group_id,num_legs)"
		_log INFO "aff_id        $aff_id"
		_log INFO "pay_for_ap    $BET($b,pay_for_ap)"
		_log INFO "pay_now       $pay_now"
		_log INFO "async_park    $BET($b,async_park)"
		_log INFO "async_already_parked  $BET($b,async_already_parked)"
		_log INFO "bir_req_id    $BET(bir_req_id)"
		_log INFO "bet_count     $bet_count"
		_log INFO "bet_group_id  $BET($b,bet_group_id)"

		for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {

			foreach leg $GROUP($group_id,$sg,legs) {
				set part_no 1

				# need to work out bets per seln here as can be
				# asymetric and will be needed for cumulative
				# stake calculations
				foreach {ign bets_per_seln} [_get_lines_per_seln\
				                                 $group_id\
				                                 $sg\
				                                 $leg\
				                                 $BET($b,bet_type)] {break}

				foreach seln $LEG($leg,selns) {

					# Adding selection (not checking if it already exists)
					lappend freebet_ev_ocs $seln
					set leg_type $BET($b,leg_type)

					# ew details
					if {
						($leg_type == "E" || $leg_type == "P") &&
						$SELN($seln,ew_with_bet) == "Y"
					} {
						set ew_fac_num $SELN($seln,ew_fac_num)
						set ew_fac_den $SELN($seln,ew_fac_den)
						set ew_places  $SELN($seln,ew_places)
					} else {
						set ew_fac_num ""
						set ew_fac_den ""
						set ew_places  ""
					}

					# note event_id if its a single in-running bet - will use info
					# to add to cookie holding 'my favourites'
					if {$BET($b,bet_type) == "SGL"\
						&& [info exists LEG($leg,has_bir_seln)]\
						&& $LEG($leg,has_bir_seln) == "Y"} {
						set BET($b,my_event_id) $SELN($seln,ev_id)
					}

					# banker
					# only consider bankers if it's not a single and every leg
					# isn't a banker
					if {
						$BET($b,bet_type) == "SGL" ||
					    $GROUP($group_id,num_bankers) ==
					    $GROUP($group_id,num_legs)
					} {
						set banker "N"
					} else {
						set banker $LEG($leg,banker)
					}

					# anon or account betting
					set receipt_format [_get_config bet_receipt_format]
					set receipt_tag    [_get_config bet_receipt_tag]

					if {$CUST(anon)} {
						set term_code $CUST(term_code)
					} else {
						set term_code $term_code
					}

					# Early Prices Active?  Only applies for Garenteed and Live Prices
					if {$LEG($leg,price_type)=="G"
					    || $LEG($leg,price_type)=="L"} {
						set ep_active $SELN($seln,ep_active)
					} else {
						set ep_active "N"
					}

					# Should all LP/SPs be treated as GP if available?
					set leg_price_type $LEG($leg,price_type)
					set leg_lp_num     $LEG($leg,lp_num)
					set leg_lp_den     $LEG($leg,lp_den)
					if {[OT_CfgGet AUTO_GP 0]} {
						set leg_lp_avail   $SELN($seln,lp_avail)
						set leg_gp_avail   $SELN($seln,gp_avail)
						if {($leg_price_type == "L" || $leg_price_type == "S") && \
								$leg_lp_avail && $leg_gp_avail == "Y"} {
							set leg_price_type "G"
							if {$leg_lp_num == "" && $leg_lp_den == ""} {
								set leg_lp_num  $SELN($seln,lp_num)
								set leg_lp_den  $SELN($seln,lp_den)
							}
						}
					}

					# add the part
					set mult_key $GROUP($group_id,$sg,mult_key)
					set part_ident "$leg_no,$part_no,$mult_key"
					_log INFO "$part_ident: leg_sort   $LEG($leg,leg_sort)"
					_log INFO "$part_ident: ev_desc    $SELN($seln,ev_desc)"
					_log INFO "$part_ident: oc_desc    $SELN($seln,oc_desc)"
					_log INFO "$part_ident: ev_oc_id   $seln"
					_log INFO "$part_ident: price_type $leg_price_type"
					_log INFO "$part_ident: lp_num     $leg_lp_num"
					_log INFO "$part_ident: lp_den     $leg_lp_den"
					_log INFO "$part_ident: ep_active  $ep_active"
					_log INFO "$part_ident: banker     $banker"

					# If the locale is not overidden get this now.
					if {$locale == {} && [_get_config locale_inclusion] == "Y"} {
						set locale [app_control::get_val locale]
					}

					set rs [ob_db::exec_qry ob_bet::ins_bet\
								$BET(bir_req_id)\
					            $placed_by\
					            [_get_config source]\
					            $BET($b,max_payout)\
					            $uid\
					            $ip_addr\
					            $CUST(cust_id)\
					            $CUST(acct_id)\
					            $BET($b,bet_type)\
					            $GROUP($group_id,num_nocombi)\
					            $GROUP($group_id,num_selns)\
					            $GROUP($group_id,num_legs)\
					            $BET($b,num_lines)\
					            $BET($b,stake)\
					            $BET($b,stake_per_line)\
					            $BET($b,token_val)\
					            $mult_key\
					            $leg_no\
					            $LEG($leg,leg_sort)\
					            $part_no\
					            $seln\
					            $SELN($seln,ev_id)\
					            $SELN($seln,ev_mkt_id)\
					            $leg_price_type\
					            $leg_lp_num\
					            $leg_lp_den\
					            $LEG($leg,hcap_value)\
					            $LEG($leg,bir_index)\
					            $BET($b,leg_type)\
					            [expr {$bets_per_seln
					                   * $BET($b,line_factor)}]\
					            $banker\
					            $ep_active\
					            $ew_fac_num\
					            $ew_fac_den\
					            $ew_places\
					            $term_code\
					            $receipt_format\
					            $receipt_tag\
					            $BET($b,slip_id)\
					            $bet_id\
					            $aff_id\
					            $SELN($seln,in_running)\
					            $call_id\
					            $pay_now\
					            $BET($b,async_park)\
								$BET($b,async_park_reason)\
								$locale\
								$bet_count\
								$BET($b,potential_payout)\
							    $BET($b,max_bet_allowed_per_line)\
								$BET($b,stake_factor)\
								$BET(async_timeout)\
							]

					set bet_id [db_get_coln $rs 0 0]
					ob_db::rs_close $rs

					incr bet_count

					if {[_get_config keep_uid] == "N" && $uid != ""} {
						set uid ""
					}

					if {!$BET(bet_delay)} {
						# insert bet and customer overrides
						if {$leg_no == 1 && $part_no == 1} {
							_log DEV "Adding bet and cust overrides if applicable"
							_ins_override\
								$call_id\
								$bet_id\
								""\
								""\
								"BET"\
								$b

							_ins_override\
								$call_id\
								$bet_id\
								""\
								""\
								"CUST"\
								$CUST(cust_id)
						}

						# insert any leg overrides
						_log DEV "Adding leg overrides if applicable"
						_ins_override\
							$call_id\
							$bet_id\
							$leg_no\
							$part_no\
							"LEG"\
							$leg


						# if it's a single with one selection - we will
						# update the liabilities.
						# the actual liabilities are updated right at the
						# end of the trasaction so as to hold update locks
						# for the minimum amount of time
						#
						# If there is a singles engine running
						# then add it to that queue. Otherwise add it to the
						# list to be picked up at the end
						#
						# Note: the sytem may be setup to perm 'single' bets
						# ie: place many single bets in one bet in which case
						# we will update the rows on each simple leg
						if {
							$BET($b,bet_type) == "SGL" &&
							[llength $LEG($leg,selns)] == 1 &&
							[_get_config offline_liab_eng_sgl] == "N"
						} {
							_add_liab $seln $leg $b
						}
					}
					incr part_no
				}
				# end of part loop
				incr leg_no
			}
			# end of leg loop
		}
		# end of subgroup loop


		# if bet_delay, then bet_id is tBIRBet.bir_bet_id, else tBet.bet_id
		set BET($b,bet_id) $bet_id

		# if bet group id is not null then associate bet id with bet group id
		if { $BET($b,bet_group_id) != "" } {
			set rs [ob_db::exec_qry ob_bet::ins_bet_group\
				$BET($b,bet_group_id)\
				$bet_id ]

			ob_db::rs_close $rs
		}

		# If this bet is referred because of group membership only, then add
		# an "accept" offer for it already.  We must also remove from the async
		# queue to avoid errors in later stages
		if { $BET($b,async_park_reason) == "GROUP_REFERRAL" } {
			set channel [_get_config source]
			if { [OT_CfgGet FUNC_ASYNC_FINE_GRAINED 0] } {
				set off_tout    [ob_control::get async_off_timeout $channel $BET(in_running) $CUST_DETAILS(cust_code)]
			} else {
				set off_tout    [ob_control::get async_off_timeout]
			}
			set expiry_date [clock format [expr {[clock seconds] + $off_tout}] -format "%Y-%m-%d %H:%M:%S"]
			set ret [ob_bet::cust_ins_async_bet_offer\
								""\
								$BET($b,bet_id)\
								$expiry_date\
								"A"\
								$BET($b,stake_per_line)\
								$BET($b,leg_type)]

			db_exec_qry ob_bet::remove_bet_from_queue $BET($b,bet_id)
		}

		# get receipt and handle freebets
		if {!$BET(bet_delay)} {

			set BET($b,receipt) [_get_receipt $bet_id]
			_log INFO "placed $BET($b,receipt)"

			# don't add a check if the bet has been parked
			if {$BET($b,async_park) == "N"} {
				if {[OT_CfgGet TOKENS_CONTRIBUTE_TO_FREEBETS 1]} {
					_add_freebet_check $bet_id $freebet_ev_ocs $BET($b,stake)
				} else {
					_add_freebet_check $bet_id $freebet_ev_ocs [expr {$BET($b,stake) - $BET($b,token_val)}]
				}
			}
		}

		# redeem tokens
		# -on bet delay these will be held within the queue
		_redeem_tokens $b

		if {[_get_config offline_liab_eng_rum] == "Y" && !$BET(bet_delay) && $BET($b,async_park) == "N"} {
			_queue_bet_rum $BET($b,bet_type) $BET($b,bet_id) $SELN($seln,ev_mkt_id)
		}


		_log INFO "**************************************"

	}
	# end of bet loop

	if {!$BET(bet_delay)} {
		_upd_liabs
	}

	# intercept bets that need to be async parked
	# after liability updates
	_async_intercept

	_end
	return 1
}


#
# This procedure sets the in_running value of BET if any one of the selections is in_running state
#
proc ::ob_bet::_get_in_running {} {

	variable BET
	variable GROUP
	variable SELN
	variable LEG

	set BET(in_running) ""
	set do_break 0

	for {set b 0} {$b < $BET(num)} {incr b} {
		# Skip external bets!
		if {$BET($b,flavour) != "SPORTS"} {
			continue
		}

		set group_id $BET($b,group_id)
		for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {
			foreach leg $GROUP($group_id,$sg,legs) {
				foreach seln $LEG($leg,selns) {
					if {$SELN($seln,in_running) == "Y"} {
						set BET(in_running) "Y"
						set do_break 1
						break
					}
				}
				if {$do_break == 1} {
					break
				}
			}
			if {$do_break == 1} {
				break
			}
		}
		if {$do_break == 1} {
			break
		}
	}

	return $BET(in_running)
}


# Validate the bets
#
proc ::ob_bet::_check_bets {} {

	variable BET
	variable GROUP
	variable CUST
	variable CUST_DETAILS
	variable TOKEN
	variable SELN
	variable LEG
	variable CONFIG

	if {[_smart_reset BET] || $BET(num) == 0} {
		error\
			"No bets have been added call ::ob_bet::add_bet"\
			""\
			PLACE_NO_BETS
	}
	if {[_smart_reset CUST] || $CUST(num) == 0} {
		error\
			"No customer has been added call ::ob_bet::set_cust"\
			""\
			PLACE_NO_CUST
	}

	_get_cust_details

	# get maximum bet_delay
	# -if non zero, then the bets will be added to the bet_delay request queue
	# -async park will reset to zero as the delay imposed by the negotiations should
	#  be sufficient
	set BET(bet_delay)  [_bir_get_max_bet_delay]
	set BET(bir_req_id) ""
	_log INFO "Maximum bet delay $BET(bet_delay)"

	#Also need to check if the flavour is Sports so that we can ignore the async
	#checks for external bet offers
	if {[OT_CfgGet FUNC_ASYNC_FINE_GRAINED 0]} {
		set channel [_get_config source]
		set BET(async_timeout) [ob_control::get async_timeout $channel [_get_in_running] $CUST_DETAILS(cust_code)]
	} else {
		set BET(async_timeout) ""
		set BET(in_running) ""
		set channel ""
	}

	# is the asynchronous betting system turned on?
	if {[_async_enabled] == "Y"} {
		set BET(async_bet) Y

		if {[_get_config async_bet_rules] == "Y"} {
			set BET(async_bet_rules)  Y

			set BET(async_rule_stk1)  [ob_control::get async_rule_stk1 $channel $BET(in_running)]
			set BET(async_rule_stk2)  [ob_control::get async_rule_stk2 $channel $BET(in_running)]
			set BET(async_rule_liab)  [ob_control::get async_rule_liab $channel $BET(in_running)]

		} else {
			set BET(async_bet_rules)  N
		}
		set BET(async_max_payout) [ob_control::get async_max_payout $channel]

	} else {
		set BET(async_bet_rules) N
		set BET(async_bet) N
	}

	# check limits and number of lines
	# we do this outside the placebet loop so as to not
	# incurr an expensive rollback if the last bet has an
	# incorrect number of lines or is placed over the bet limit
	# we get the type in the transaction as we will get the max
	# min stake limits at the same time.
	#
	set tot_stk      0.0
	set used_tokens [list]

	for {set b 0} {$b < $BET(num)} {incr b} {

		# Call the registered handler for any "external" bets.

		set flavour $BET($b,flavour)
		if {$flavour != "SPORTS"} {

			set checkCmd $CONFIG(ext,$flavour,checkCmd)
			set externalRef $BET($b,externalRef)

			_log INFO "checking $flavour bet $externalRef (using $checkCmd)"

			set BET($b,ext_cost) [eval $checkCmd [list $b $externalRef]]

			set tot_stk [expr {$tot_stk + $BET($b,ext_cost)}]
			_check_bet_balance $tot_stk $b

			continue
		}

		set group_id $BET($b,group_id)
		set bet_type $BET($b,bet_type)

		if {![info exists BET($b,async_park)]} {
			set BET($b,async_park) "N"
		}

		set BET($b,async_already_parked) "N"

		if {![info exists BET($b,async_park_reason)]} {
			set BET($b,async_park_reason) ""
		}

		# check the event hierarchy for async being turned on
		if {$BET(async_bet) == "Y"} {
			set BET(async_bet) [_async_enabled_hier $b]
		}

		# The leg_sort variable is only for checking FC/TC bets,
		# so we don't look at it if this bet has more than one leg
		set leg_id   $GROUP($group_id,legs)
		if {[llength $leg_id] == 1} {
			set leg_sort $LEG($leg_id,leg_sort)
		} else {
			set leg_sort -1
		}

		# check max payout is not greater than we've stored for this bet
		# NOTE BET($b,max_payout) would have been passed through from the customer
		# screens and should be in the customer's ccy
		set bet_max_payout [expr {$GROUP($group_id,max_payout) * $CUST_DETAILS(exch_rate)}]

		# Do not throw max_payout error for a notification because the bet was
		# already placed somewhere in the shop and money changed hands.
		if {[_get_config shop_bet_notification] == "N" &&\
			$BET($b,max_payout) != "" && $BET($b,max_payout) > $bet_max_payout} {
			error\
				"max_payout $BET($b,max_payout) > mp $bet_max_payout"\
				""\
				PLACE_MAX_PAYOUT_HIGH
		}
		set BET($b,max_payout) $bet_max_payout

		# e/w leg type, then check if e/w terms have changed
		if {$BET($b,leg_type) == "E"} {
			_check_ew [lsort -unique -integer $leg_id]
		}

		set details {}
		foreach {
			t
			details
		} [_get_types_for_group $group_id $bet_type] {break}

		if {$details == {}} {
			error\
				"could not retrieve number of lines for $bet_type"\
				""\
				PLACE_INVALID_NUM_LINES
		}

		foreach {
			num_lines
			max_bet_W
			max_bet_P
			max_bet_L_W
			max_bet_L_P
			max_bet_S_W
			max_bet_S_P
			max_bet_F
			max_bet_T
			min_bet
			pot_rtn_win
			max_bet_SGL
			max_bt
			grp_sf
			bet_type_sf
			leg_lines
			pot_rtn_plc
		} $details {break}

		set BET($b,stake_factor) [_get_cust_scale_factor $group_id]
		set BET($b,num_lines) [expr {$num_lines * $BET($b,line_factor)}]
		set BET($b,max_bet_W) $max_bet_W
		set BET($b,max_bet_P) $max_bet_P
		set BET($b,max_bet_F) $max_bet_F
		set BET($b,max_bet_T) $max_bet_T
		set BET($b,min_bet)   $min_bet

		# Check the stake
		set stk [expr {$BET($b,stake_per_line) *
		               $BET($b,num_lines)}]
		if {$BET($b,stake) != [format %.2f $stk]} {
			error\
				"Stake $BET($b,stake): Should be $stk,$BET($b,stake_per_line)"\
				""\
				PLACE_INVALID_STAKE
		}

		# check max min stake
		set stk_too_high 0

		_log DEBUG "Bet Type : $BET($b,bet_type)  Leg Type : $BET($b,leg_type)  Leg Sort : $leg_sort"

		if {$BET($b,leg_type) == "W"} {
			if {$BET($b,stake_per_line) > $max_bet_W} {
				set stk_too_high 1
				set max_bet $max_bet_W
			}
			set BET($b,max_bet_allowed_per_line) $max_bet_W
		}
		if {$BET($b,leg_type) == "P"} {
			if {$BET($b,stake_per_line) > $max_bet_P} {
				set stk_too_high 1
				set max_bet $max_bet_P
			}
			set BET($b,max_bet_allowed_per_line) $max_bet_P
		}
		if {$BET($b,leg_type) == "E"} {

			if {$max_bet_P < $max_bet_W} {
				set max_bet_E $max_bet_P
			} else {
				set max_bet_E $max_bet_W
			}

			if {$BET($b,stake_per_line) > $max_bet_E} {
				set stk_too_high 1
				set max_bet $max_bet_E
			}
			set BET($b,max_bet_allowed_per_line) $max_bet_E
		}

		if { $leg_sort == "SF" } {

			if {$BET($b,stake_per_line) > $max_bet_F} {
				set stk_too_high 1
				set max_bet $max_bet_F
			}

			if { $BET($b,max_bet_allowed_per_line) > $max_bet_F }  {

				set BET($b,max_bet_allowed_per_line) $max_bet_F
			}
		}
		if { $leg_sort == "TC" } {
			if {$BET($b,stake_per_line) > $max_bet_T} {
				set stk_too_high 1
				set max_bet $max_bet_T
			}

			if { $BET($b,max_bet_allowed_per_line) > $max_bet_T }  {

				set BET($b,max_bet_allowed_per_line) $max_bet_T
			}
		}

		# check if we need to go async, or use STK_HIGH override
		if {$BET(async_bet) == "Y" && $stk_too_high} {

			# check if someone has already tried to submit this bet
			if {[_async_resub_check $b] != "OK"} {
				# customer has already had this bet rejected
				# don't refer it again, let them have max bet only
				_need_override BET $b STK_HIGH
				set BET(async_bet) "N"
			} else {
				ob_log::write INFO {BET - BET INTERCEPTED:}
				ob_log::write INFO {      Stake per line $BET($b,stake_per_line) > max bet $max_bet}
				set BET($b,async_park) "Y"
				# Stake per line exceeds customer max bet
				set BET($b,async_park_reason) ASYNC_PARK_SPL_GT_CUST_MAX_BET

				# Note that this doesn't actually park the bets, it just marks all
				# bets in the group as requiring async parking.
				_async_park_bet_group $BET($b,bet_group_id)
			}

		} elseif {$stk_too_high && [_get_config shop_bet_notification] == "N"} {
			_need_override BET $b STK_HIGH
		}

		if {[_get_config shop_bet_notification] == "N" && $BET($b,stake_per_line) < $min_bet} {
			_need_override BET $b STK_LOW
		}

		# check for other asynchronous betting triggers
		if {$BET(async_bet) == "Y" && $BET($b,async_park) == "N"} {
			_async_park_checks $b $group_id $BET($b,bet_group_id)
		} else {
			_log INFO "Asynchronous betting disabled"
		}

		# Systematically put into asynchronous state if it's a shop bet referral
		if {$BET(async_bet) == "Y" && [_get_config shop_bet_referral]} {
			# Will be called systematically for each bet submitted
			set BET($b,async_park) "Y"
			set BET($b,async_park_reason) ASYNC_PARK_SHOP_REFERRAL

			_async_park_bet_group $BET($b,bet_group_id) 0

			_log INFO "Bet $b marked parked because of ASYNC_PARK_SHOP_REFERRAL"
		}

		# record the potential payout
		set BET($b,potential_payout) [_get_pot_payout $BET($b,stake_per_line) $group_id $BET($b,bet_type) $BET($b,leg_type)]

		# Check the freebet tokens
		set tot_token_val 0.0
		set stake_remaining $BET($b,stake)

		if {$BET($b,tokens) != ""} {
			set t_ids [list]
			set token_list [_get_tokens_for_group $group_id]

			set BET($b,redeemed_tokens) [list]

			foreach {token_id token_cust_id} $token_list {
				lappend t_ids $token_cust_id
			}
			foreach token $BET($b,tokens) {
				# check valid
				if {[lsearch $t_ids $token] == -1} {
					error\
						"Bet token $token cannot be used on bet: $b"\
						""\
						PLACE_INVALID_TOKEN
				}

				# check hasn't been used on any other bet.
				if {[lsearch used_tokens $token] != -1} {
					error\
						"Bet token $token has been used on another bet"\
						""\
						PLACE_USED_TOKEN
				}
				lappend used_tokens $token

				set token_val $TOKEN($token,value)

				if {$token_val > $stake_remaining} {
					set token_val $stake_remaining
				}
				lappend BET($b,redeemed_tokens) $token $token_val

				set stake_remaining [expr {$stake_remaining - $token_val}]
				set tot_token_val [expr {$tot_token_val + $token_val}]

				if {$stake_remaining == 0.0} {
					# we don't need to use any more tokens
					break
				}
			}
		}
		set BET($b,token_val) $tot_token_val


		set tot_stk [format %.2f [expr {$tot_stk + $BET($b,stake) - $tot_token_val}]]

		_check_bet_balance $tot_stk $b
	}

	return [list $tot_stk $BET(num)]
}

# Check customer can afford to pay tot_stk, and request override
# on bet b if not.
proc ::ob_bet::_check_bet_balance {tot_stk b} {

	variable BET
	variable CUST
	variable CUST_DETAILS

	# check balance - if we check the customer and if the credit limit
	# isn't null
	#
	# TODO - take into account tax

	# Don't need to check if:
	# 1. Limitless credit limit
	# 2. Explicitly turn checking off
	# 3. It is a slip bet (money already taken out of account)
	if {$CUST_DETAILS(credit_limit) != "" &&
	    $CUST(check) &&
	    $BET($b,slip_id) == "" && [_get_config low_funds_override] == "Y"} {
		# only need to take into account credit limits
		# for credit customers
		if {$CUST_DETAILS(acct_type)=="CDT"} {

			set available [expr {$CUST_DETAILS(balance) + $CUST_DETAILS(credit_limit)}]

			if {$available < $tot_stk} {
				_need_override BET $b CREDIT
			}
		} else {
			set available $CUST_DETAILS(balance)

			if {$available < $tot_stk} {
				# No override necessary if async and not taking the money yet.
				if {
					$BET($b,flavour) == "SPORTS" &&
					![OT_CfgGet ASYNC_PAY_NOW 0] &&
					$BET($b,async_park) == "Y"
				} {
				} else {
					_need_override BET $b LOW_FUNDS
				}
			}
		}
	}
}

# Check leg E/W terms against the selection's
#
proc ::ob_bet::_check_ew { legs } {

	variable LEG
	variable SELN

	_log INFO "checking each/way terms for $legs...."

	foreach leg_no $legs {

		# E/W terms not added to leg
		if {
			$LEG($leg_no,ew_places) == "" &&
			($LEG($leg_no,ew_fac_num) == "" ||
			 $LEG($leg_no,ew_fac_den) == "")
		} {
			continue
		}

		foreach ev_oc_id $LEG($leg_no,selns) {

			# place change
			if {
				$LEG($leg_no,ew_places) != "" &&
				$LEG($leg_no,ew_places) != $SELN($ev_oc_id,ew_places)
			} {
				set LEG($leg_no,expected_ew_places) $SELN($ev_oc_id,ew_places)
				if {[_get_config shop_bet_notification] == "N"} {
					_need_override LEG $leg_no EW_PLC_CHG
				}
			}

			# price change
			if {
				$LEG($leg_no,ew_fac_num) != "" &&
				$LEG($leg_no,ew_fac_den) != "" &&
				($LEG($leg_no,ew_fac_num) != $SELN($ev_oc_id,ew_fac_num) ||
				 $LEG($leg_no,ew_fac_den) != $SELN($ev_oc_id,ew_fac_den))
			} {
				set LEG($leg_no,expected_ew_fac_num) $SELN($ev_oc_id,ew_fac_num)
				set LEG($leg_no,expected_ew_fac_den) $SELN($ev_oc_id,ew_fac_den)
				if {[_get_config shop_bet_notification] == "N"} {
					_need_override LEG $leg_no EW_PRC_CHG
				}
			}
		}
	}
}

#
# This proc checks if something is wrong with the feed and returns 1 if so.
#
proc ::ob_bet::check_panic_mode {} {

	set OXiRepClientMainName [OT_CfgGet PANIC_MODE_REP_CLIENTNAME "OXiDBSyncClient"]

	if {[catch {set rs [db_exec_qry ob_bet::pb_check_panic_mode $OXiRepClientMainName]} msg]} {
		_log ERROR "unable to run ::ob_bet::check_panic_mode:$msg"
		return 0
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		# no row in tOXiRepClientSess so we're not getting data via a feed,
		# so no need to panic
		ob_db::rs_close $rs
		return 0
	} elseif {$nrows > 1} {
		_log ERROR "::ob_bet::check_panic_mode received $nrows rows expected 1"
		ob_db::rs_close $rs
		return 0
	}

	set repl_check_mode [db_get_col $rs 0 repl_check_mode]
	set repl_max_wait   [db_get_col $rs 0 repl_max_wait]
	set repl_max_lag    [db_get_col $rs 0 repl_max_lag]
	set last_msg_time   [db_get_col $rs 0 last_msg_time]
	set last_ping_time  [db_get_col $rs 0 last_ping_time]
	set current_lag     [db_get_col $rs 0 current_lag]

	set last_msg_id     [db_get_col $rs 0 last_msg_id]
	set head_msg_id     [db_get_col $rs 0 head_msg_id]

	set current_time [clock seconds]

	set last_msg_time_secs   [clock scan $last_msg_time]
	set last_ping_time_secs  [clock scan $last_ping_time]

	_log DEV "last_msg_time_secs = $last_msg_time_secs last_ping_time_secs = $last_ping_time_secs"

	set lag_triggered  [expr {$current_lag > $repl_max_lag}]
	set msg_triggered  [expr {$current_time - $last_msg_time_secs > $repl_max_wait }]
	set ping_triggered [expr {$current_time - $last_ping_time_secs > $repl_max_wait }]

	# repl_check_mode == "Y" means we're for sure in panic mode
	# and "-" means that we're only in panic mode if the feed
	# is running behind or stopped working
	if {$repl_check_mode == "Y" ||
		($repl_check_mode == "-" &&
		($lag_triggered ||
		($ping_triggered && ($last_msg_id == $head_msg_id)) ||
		 $msg_triggered))} {
		_log WARNING "We are in panic mode"
		set ret 1
	} else {
		_log DEV "We are not in panic mode"
		set ret 0
	}
	_log DEV "Panic mode check params: repl_check_mode = $repl_check_mode\
			repl_max_wait = $repl_max_wait\
			repl_max_lag = $repl_max_lag\
			last_msg_time = $last_msg_time\
			last_msg_id = $last_msg_id \
			head_msg_id = $head_msg_id \
			last_ping_time = $last_ping_time\
			current_lag = $current_lag\
			lag_triggered = $lag_triggered\
			ping_triggered = $ping_triggered\
			msg_triggered = $msg_triggered"
	ob_db::rs_close $rs
	return $ret
}

# Start the bet transaction
#
proc ::ob_bet::_start {} {

	variable BET

	if {$BET(trans)} {
		_log INFO "Starting bet transaction"
		ob_db::begin_tran
	} else {
		_log WARN "_start: Not handling transaction in module"
	}
}



# Commit the bet transaction
#
proc ::ob_bet::_end {} {

	variable BET

	if {$BET(trans)} {
		ob_db::commit_tran
	} else {
		_log WARN "_end: Not handling transaction in module"
	}


	if {!$BET(bet_delay)} {
		_log INFO "**************************************"
		_log INFO "Bet summary:"
		for {set b 0} {$b < $BET(num)} {incr b} {
			_log INFO "flavour:  $BET($b,flavour)"
			_log INFO "receipt:  $BET($b,receipt)"
			if {$BET($b,flavour) == "SPORTS"} {
				_log INFO "bet type: $BET($b,bet_type)"
				_log INFO "stake:    $BET($b,stake)"
				_log INFO "stake pl: $BET($b,stake_per_line)"
				_log INFO "parked:   $BET($b,async_park)"
			} else {
				_log INFO "ext_bet_id: $BET($b,ext_bet_id)"
				_log INFO "cost:       $BET($b,ext_cost)"
			}
			_log INFO "--------------------------------------"
		}
		_log INFO "**************************************"
	}
}



# we will commit if no DB work has been done
#
proc ::ob_bet::_abort {{commit 0}} {

	variable BET

	_log WARN "Placebet aborted"
	if {$BET(trans)} {
		if {$commit} {
			ob_db::commit_tran
		} else {
			ob_db::rollback_tran
		}
	} else {
		_log WARN "_abort: Not handling transaction in module"
	}
}



# Get the leg details
#
proc ::ob_bet::_get_leg {leg_no param} {

	variable LEG

	if {[_smart_reset LEG] || ![info exists LEG($leg_no,$param)]} {
		return [list 0 ""]
	} else {
		return [list 1 $LEG($leg_no,$param)]
	}
}



# Get the selection details
#
proc ::ob_bet::_get_oc {ev_oc_id param} {

	variable SELN

	if {[_smart_reset SELN] || ![info exists SELN($ev_oc_id,$param)]} {
		return [list 0 ""]
	} else {
		return [list 1 $SELN($ev_oc_id,$param)]
	}
}



# Get the group details
#
proc ::ob_bet::_get_group {group_id param} {

	variable GROUP

	if {[_smart_reset GROUP] || ![info exists GROUP($group_id,$param)]} {
		return [list 0 ""]
	} else {
		return [list 1 $GROUP($group_id,$param)]
	}
}



# Get the bet details
#
proc ::ob_bet::_get_bet {bet_id param} {

	variable BET

	if {[_smart_reset BET] || ![info exists BET($bet_id,$param)]} {
		return [list 0 ""]
	} else {
		return [list 1 $BET($bet_id,$param)]
	}
}

#Get list of bets added with ob_bet::add_bet.
proc ::ob_bet::_get_bets_added {} {

	variable BET

	if {[_smart_reset BET] || ![info exists BET(num)] || $BET(num) == 0} {
		return [list]
	}

	set bet_nums [list]
	for {set b 0} {$b < $BET(num)} {incr b} {
		lappend bet_nums $b
	}
	return $bet_nums
}


# Determine comparison odds for a leg given its leg type
#
# Returns odds
#
proc ::ob_bet::_get_leg_comparison_price {l leg_type} {
	variable LEG
	variable SELN

	switch -- $leg_type {
		"W" -
		"E" -
		"I" {
			# use win prices
			set lp_num $LEG($l,lp_num)
			set lp_den $LEG($l,lp_den)

			if {[llength [set o $LEG($l,selns)]] == 1} {
				set sp_num_guide $SELN($o,sp_num_guide)
				set sp_den_guide $SELN($o,sp_den_guide)
			} else {
				set sp_num_guide ""
				set sp_den_guide ""
			}
		}
		"P" {
			# use each way factor scaled win prices
			if {[llength [set o $LEG($l,selns)]] == 1} {
				set ew_n $SELN($o,ew_fac_num)
				set ew_d $SELN($o,ew_fac_den)
				set lp_num [expr {(double($ew_n)/$ew_d)*$LEG($l,lp_num)}]
				set lp_den $LEG($l,lp_den)
				set sp_num_guide [expr {(double($ew_n)/$ew_d)*$SELN($o,sp_num_guide)}]
				set sp_den_guide $SELN($o,sp_den_guide)
			} else {
				set lp_num $LEG($l,lp_num)
				set lp_den $LEG($l,lp_den)
				set sp_num_guide ""
				set sp_den_guide ""
			}
		}
		"L" {
			# use place prices
			set lp_num $LEG($l,lp_plc_num)
			set lp_den $LEG($l,lp_plc_den)
			set sp_num_guide ""
			set sp_den_guide ""
		}
		default {
			error "unknown leg type \"$leg_type\""
		}
	}

	return [ob_price::get_comparison_price \
			$LEG($l,price_type) \
			$lp_num \
			$lp_den \
			$sp_num_guide \
			$sp_den_guide]
}

::ob_bet::_log INFO "sourced place.tcl"
