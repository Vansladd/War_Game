################################################################################
# $Id: util.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Various supporting utility procedures
#
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#    ob_bet::get_types_for_group = get valid bet types for groups
#    ob_bet::get_combis            How can legs be combined
#    ob_bet::get_special_combis    How can selections be combined on complex
#                                  legs
#    ob_bet::get_receipt           Get the receipt for a given bet_id
################################################################################
namespace eval ob_bet {
	namespace export get_types_for_group
	namespace export get_combis
	namespace export get_special_combis
	namespace export get_receipt
	namespace export get_calculated_bet_type_limits
	variable XSTK
}



#API:get_types_for_group - get available bet types for group
#
#Usage
#  ob_bet::get_types_for_group group_id type
#
#  Will return available bet types and max and min bets for each type
#  If the type is supplied will only return max min bet for that type
#
# Parameters:
# group_id: FORMAT: INT     DESC: group id returned from add_group
# type:     FORMAT: VARCHAR
#           DESC:   tBetType.bet_type ie SGL DBL etc
#                   If not stated will return all the types for that bet
#           DEFAULT {}
#
# RETURNS: TO DO
#
proc ::ob_bet::get_types_for_group {group_id {type ""} {ignore_acc_min "N"}} {

	#log input params
	_log DEBUG "API(get_types_for_group): $group_id,$type"

	#check input arguments
	#          name      value      type nullable min max
	_check_arg group_id  $group_id  INT       0   0
	_check_arg type      $type      CHAR      1   3   5

	if {[catch {
		set ret [_get_types_for_group $group_id $type "" $ignore_acc_min]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_combis - get allowable combinations of legs
#
#Usage
#  ob_bet::get_combis
#
#  Will return a list of lists of legs - legs appearing in the same list
#  cannot  be combined in a multilple
#
# Parameters:
# legs: FORMAT: LIST_INTS DESC: null to give combinations of particular legs
#                               list of legs otherwise
#
# RETURNS: list of a list of legs
#
# EXAMPLE: We have added five legs
#          0 Arsenal to Win 1 Arsenal to Draw 2 Basketball bet
#          3 Henman to Win first match 4 Henman to win wimbledon
#          % set combis [ob_bet::get_combis]
#          % set combis
#          {0 1} 2 {3 4}
#
proc ::ob_bet::get_combis {{legs {}}} {

	#log input params
	_log INFO "API(get_combis) $legs"

	#check input arguments
	#          name      value  type      nullable min max
	_check_arg legs      $legs  LIST_INTS 1

	if {[catch {
		set ret [eval _get_combis {$legs}]
	} msg]} {
		_err $msg
	}
	return $ret
}


#API:get_special_combis - selections combinable in a complex leg.
#
#Usage
#  ob_bet::get_special_combis legs
#
#  Will return a list of selections that can be combined in complex legs
#
# Parameters:
# legs: FORMAT: LIST_INTS DESC: restricted list of legs which can be combined
#                               if empty list, then ALL legs will be used (default)
#
# NB: only those legs which can be combinable into a special leg will ever be used,
#     e.g. fc/tc_avail and all from the same market
#
#
# RETURNS: list of selections and valid leg sorts:
#          {seln1 seln2 ...} {leg_sort1 leg_sort2 ...} {selnA selnB} {leg_...}
#
# EXAMPLE: We select 4 horses from the same race 664 665 666 667
#          % set special_combis [ob_bet::_get_special_combis]
#          % set special_combis
#          {664 665 666 667} {SF RF TC CF CT}
#
proc ::ob_bet::get_special_combis { {legs {}} } {

	#log input params
	_log INFO "API(get_special_combis) $legs"

	#check input arguments
	#          name      value  type      nullable min max
	_check_arg legs      $legs  LIST_INTS 1

	if {[catch {
		set ret [eval _get_special_combis {$legs}]
	} msg]} {
		_err $msg
	}
	return $ret
}



#API:get_max_bet_details - Get some details of how max bets are arrived at.
#
# Usage:
#   get_max_bet_details arrName ?legs?
# where:
#   arrName = name of array in which to store the information
#             (will be created in caller's scope)
#   legs    = list of legs for which information is required
#             (or "" for all legs)
#
# Returns:
#   Nothing directly, but keys are created in the named array.
#
# Notes:
#
#   Some clients (well, the PPW sportbook betslip anyway) want to perform
#   dynamic max bet calculations client-side, treating stakes entered as more
#   cumulative stake to consider against the max bets.
#
#   In order to support this, the client is going to need some rather detailed
#   information about how the max bets are arrived at - namely the raw max bets
#   and cumulative stakes for max bet key for each selection on which legs have
#   been added.
#
#   This procedure will empty then create the following keys in the named array
#   in the caller's scope:
#
#     * mb_keys = List of keys (e.g. "L,W" for LP Win, "F" for Forecast).
#     * selns   = List of ev_oc_ids for selns on which legs have been added.
#     * $ev_oc_id,$mb_key,max = Seln max stake (customer's ccy, unrounded).
#     * $ev_oc_id,$mb_key,cum = Cumulative stake (customer's ccy, unrounded).
#
#   Obviously, this isn't all the info that the client will needed; he'll also
#   require at least the following: (available from get_types_for_group)
#
#     * Bet type scale factor
#     * Bet type max bet
#     * Group scale factor
#     * Num lines per leg
#
# Bugs / Warnings:
#
#   The pre-conditions for calling this procedure are unfortunately rather
#   ugly; you'll need to ensure that:
#
#     * You've finished adding legs with ob_bet::add_leg.
#     * You've done an ob_bet::set_cust.
#     * You've done an ::ob_bet::get_types_for_group for group(s) covering
#       all the given legs.
#
#   It will probably blow up horribly if you haven't. Sorry.
#
#   It's the caller's responsibility to check the sep_cum_max_stk config item
#   and therefore determine whether to treat LP and SP separately.
#
# Get some details of how max bets are arrived at.
proc ob_bet::get_max_bet_details {arrName {legs ""}} {

	#log input params
	_log INFO "API(get_max_bet_details \"$arrName\" {$legs})"

	if {[catch {
		# _get_max_bet_details needs to create things in the callers
		# scope, so our wrapper must uplevel it.
		set ret [uplevel 1 [list ob_bet::_get_max_bet_details $arrName $legs]]
	} msg]} {
		_err $::errorInfo
	}
	return $ret
}



#API:get_receipt
#
#Usage
#  ob_bet::get_receipt bet_id
#
#  Will return the receipt for a given bet
#
# RETURNS: a receipt
#
proc ::ob_bet::get_receipt {bet_id} {

	#log input params
	_log INFO "API(get_receipt) $bet_id"

	#check input arguments
	#          name      value   type      nullable min max
	_check_arg bet_id    $bet_id INT       0

	return [_get_receipt $bet_id]
}

#END OF API..... private procedures



#Prepare the util queries
proc ::ob_bet::_prepare_util_qrys {} {

	# We combine these queries as we need:
	#  The status of the scorecast market.
	#  The price of the MR mkt to work out the fscs price
	# We're not likely to pull out many rows we won't need as SC
	# markets have no selections and MR only have three
	# Order by disporder as we only take the first MR odds, as
	# assume this is the 90 minute market, as may have more.
	ob_db::store_qry ob_bet::fscs_details {
		select
		  o.lp_num,
		  o.lp_den,
		  o.fb_result,
		  m.sort,
		  m.status
		from
		  tEvMkt m,
		  outer tEvOc o
		where
		  m.ev_mkt_id = o.ev_mkt_id and
		  m.ev_id = ? and
		  m.sort in ('SC','MR')
		order by
		  m.disporder
	}

	ob_db::store_qry ob_bet::fscs_price {
		execute procedure pGetPriceSC (
		    p_type   = ?,
		    p_cs_num = ?,
		    p_cs_den = ?,
		    p_fg_num = ?,
		    p_fg_den = ?
		)
	}

	ob_db::store_qry ob_bet::get_receipt {
		select
			receipt
		from
			tBet
		where
			bet_id = ?
	}

	ob_db::store_qry ob_bet::pb_check_panic_mode {
		select
			c.repl_check_mode,
			c.repl_max_wait,
			c.repl_max_lag,
			s.last_msg_time,
			s.last_ping_time,
			s.current_lag,
			s.last_msg_id,
			s.head_msg_id
		from
			tControl c,
			tOXiRepClientSess s
		where
			s.name = ?
	}
}



#first scorer correct score validation and prices
proc ::ob_bet::_fscs_leg {oc_id1 oc_id2} {

	variable SELN

	set ev_id $SELN($oc_id1,ev_id)

	#check in same event
	if {$ev_id != $SELN($oc_id2,ev_id)} {
		_log DEBUG "FSCS not allowed different events $oc_id1 $oc_id2"
		return [list 0 "" "" ""]
	}

	#check leg_sorts
	if {$SELN($oc_id1,mkt_sort) == "FS" &&
	    $SELN($oc_id2,mkt_sort) == "CS"} {
		set fs_id $oc_id1
		set cs_id $oc_id2
	} elseif {$SELN($oc_id1,mkt_sort) == "CS" &&
	          $SELN($oc_id2,mkt_sort) == "FS"} {
		set fs_id $oc_id2
		set cs_id $oc_id1
	} else {
		#not a valid scorecast
		_log DEBUG "FSCS not allowed as not FS and CS: $oc_id1 $oc_id2"
		return [list 0 "" "" ""]
	}

	#is it valid FS/CS combination ie home scorer - home score != 0
	#                                 away scorer - away score != 0
	set fs_result $SELN($fs_id,fb_result)
	set cs_home   $SELN($cs_id,cs_home)
	set cs_away   $SELN($cs_id,cs_away)

	if {$fs_result != "H" && $fs_result != "A"} {
		_log DEBUG "FSCS not allowed for fb_result: $fs_result $fs_id"
		return [list 0 "" "" ""]
	}

	if {$cs_home > $cs_away} {
		set cs_res "H"
		set sc_type [expr {$fs_result == "H" ? "W" : "L"}]
	} elseif {$cs_away > $cs_home} {
		set cs_res "A"
		set sc_type [expr {$fs_result == "A" ? "W" : "L"}]
	} else {
		set cs_res "D"
		set sc_type "D"
	}

	if {($fs_result == "H" && $cs_home == 0) ||
	    ($fs_result == "A" && $cs_away == 0)} {
		_log DEBUG "Impossible fscs combination"
		return [list 0 "" "" ""]
	}

	#OK so we have a first scorer and a correct score
	#is the scorecast market available?
	set rs [ob_db::exec_qry ob_bet::fscs_details $ev_id]
	set n_rows [db_get_nrows $rs]
	if {$n_rows == 0} {
		_log DEBUG "No SC market for $ev_id"
		return [list 0 "" "" ""]
	}

	set lp_num_MR ""
	set lp_den_MR ""
	set SC_mkt_status ""
	set MR_done 0

	for {set i 0} {$i < $n_rows} {incr i} {
		set item "[db_get_col $rs $i sort][db_get_col $rs $i fb_result]"
		switch -- $item [subst {
			MR${fs_result} {
				# Only want to set this once, may have more than one MR market
				if {!$MR_done} {
					set lp_num_MR [db_get_col $rs $i lp_num]
					set lp_den_MR [db_get_col $rs $i lp_den]
					set MR_done 1
				}
			}
			SC {
				set SC_mkt_status [db_get_col $rs $i status]
			}
			default {
				continue
			}
		}]
	}

	if {$SC_mkt_status == ""} {
		_log DEBUG "No SC market for $ev_id"
		return [list 0 "" "" ""]
	}

	if {$lp_num_MR == "" || $lp_den_MR == ""} {
		_log WARN "No MR prices to generate SC price: $ev_id"
		return [list 0 "" "" ""]
	}

	#check status TODO

	#work out the price
	set lp_num_FS    $SELN($fs_id,lp_num)
	set lp_den_FS    $SELN($fs_id,lp_den)
	set lp_num_CS    $SELN($cs_id,lp_num)
	set lp_den_CS    $SELN($cs_id,lp_den)

	if {[catch {
		foreach {n d} [[_get_config fscs_price_proc]\
					$sc_type\
					$lp_num_CS\
					$lp_den_CS\
					$lp_num_FS\
					$lp_den_FS\
					$lp_num_MR\
					$lp_den_MR\
					$fs_result\
					$cs_home\
					$cs_away] {break}

	} msg]} {
		_log ERROR "Cannot get SC price from func - $msg"
		return [list 0 "" "" ""]
	}

	return [list 1 $SC_mkt_status $n $d]
}



#fscs price function - this can be overridden in ob_bet::init
proc ::ob_bet::_get_fscs_price {
	sc_type
	lp_num_CS
	lp_den_CS
	lp_num_FS
	lp_den_FS
	lp_num_MR
	lp_den_MR
	fs_result
	cs_home
	cs_away
} {
	_log DEBUG [subst {
		Finding FSCS price for
		SC: $sc_type
		CS: $lp_num_CS $lp_den_CS
		FS: $lp_num_FS $lp_den_FS
		MR: $lp_num_MR $lp_den_MR
		fs_result: $fs_result cs_home: $cs_home cs_away: $cs_away
	}]

	set rs [ob_db::exec_qry ob_bet::fscs_price \
	            $sc_type\
	            $lp_num_CS\
	            $lp_den_CS\
	            $lp_num_FS\
	            $lp_den_FS]

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		error\
			"Error getting SC price"\
			""\
			UTIL_SC_PRICE
	}

	set res [list [db_get_coln $rs 0] [db_get_coln $rs 1]]
	ob_db::rs_close $rs

	return $res
}

#   Calculates selection wise the contrubtion to all the bets in bet array
#   We dont need to calculate this every time , we calculate it once and return
#   the same Array.
#
#   This array will be cleared in _check_bets function in place.tcl
#
proc  ::ob_bet::_calculate_cross_bet_contributions { } {

	variable BET
	variable LEG
	variable XSTK
	variable GROUP
	variable CUST
	variable CUST_DETAILS
	variable CHANNEL

	# If info about this group exists already then dont calculate again
	if { [ info exists XSTK(calculated) ]  }  {

		_log DEBUG "Cross bet Stakes had been calculated already"
		return
	}

	for {set bet 0} {$bet < $BET(num)} {incr bet} {

		set bet_type $BET($bet,bet_type)
		set bet_group_id $BET($bet,group_id)

	    # get the scale factor, exchange rate and cust details
		set scale_factor 1
		set intercept_value ""
		set exch_rate 1

		if {![_smart_reset CUST] && $CUST(num) && $CUST(check)} {
			#get the customer details
			_get_cust_details
			set exch_rate $CUST_DETAILS(exch_rate)
			foreach {cust_scale_factor intercept_value lg} [_get_cust_ev_lvl_limits $bet_group_id] { break }
			set scale_factor [expr {$scale_factor * $cust_scale_factor}]
		}

		set scale_factor [expr {$scale_factor * $CHANNEL([_get_config source],max_stake_mul)}]
		_get_leg_limits $scale_factor $exch_rate $GROUP($bet_group_id,legs)

		set limits [_get_limits $bet_group_id $bet_type $scale_factor $exch_rate 0]

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
		} $limits {break }

		set leg_stake [expr {$BET($bet,stake_per_line) * $leg_lines}]

		foreach leg $GROUP($bet_group_id,legs) {

			set mb_keys [list]
			if { $LEG($leg,price_type) == "S"} {
				set prc_prefix "S"
			} else {
				set prc_prefix "L"
			}

			if { $BET($bet,leg_type) == "W" || $BET($bet,leg_type) == "E" } {

				lappend mb_keys "$prc_prefix,W"
			}

			if { $BET($bet,leg_type) == "P" || $BET($bet,leg_type) == "E" } {

				lappend mb_keys "$prc_prefix,P"
			}

			if { [lsearch [list SF RF CF] $LEG($leg,leg_sort)] != -1 } {

				lappend mb_keys "F"
			}

			if { [lsearch [list TC CT] $LEG($leg,leg_sort)] != -1 } {

				lappend mb_keys "T"
			}


			foreach ev_oc_id $LEG($leg,selns) {

				foreach mb_key $mb_keys {

					# Add this leg's stake to the total for this selection
					# under this "max bet key".
					if { [info exists XSTK($ev_oc_id,$mb_key,total)] } {

						set XSTK($ev_oc_id,$mb_key,total) [expr {$XSTK($ev_oc_id,$mb_key,total) + $leg_stake}]
					} else {

						set XSTK($ev_oc_id,$mb_key,total) $leg_stake
					}

					# Calculating only Multi Bet Stake, so we dont need worry about SGL bet type
					if { [info exists XSTK($ev_oc_id,$bet,multi_bet_stake,total)] && $BET($bet,bet_type) != "SGL" } {

						set XSTK($ev_oc_id,$bet,multi_bet_stake,total) [expr {$XSTK($ev_oc_id,$bet,multi_bet_stake,total) + $leg_stake}]
					} elseif { $BET($bet,bet_type) != "SGL"  } {

						set XSTK($ev_oc_id,$bet,multi_bet_stake,total) $leg_stake

					}

					if { [info exists XSTK($ev_oc_id,$mb_key,$bet)] } {

						set XSTK($ev_oc_id,$mb_key,$bet) [expr {$XSTK($ev_oc_id,$mb_key,$bet) + $leg_stake}]
					} else {

						set XSTK($ev_oc_id,$mb_key,$bet) $leg_stake
					}
				}
				# End of for each mb_key loop
			}
			# End of for each ev_oc_id loop
		}
		# End of  for each leg loop
    }
	# End of for loop

	# Marking as calculated
	set XSTK(calculated) 1
}

#
# Get valid bet types for a group of selections.
#
# When cross bet max multiple bet flag is enabled, this function calculates max
# multiple bet limit by incluing stakes in the bets on this group
# (Max_mult_bet_limit = stakes already placed in system + stakes in this group of selections)
#
# Stores the calculated limits for each type in BET_TYPE_LIMITS Array so that it can be retrieved , when information
# in other arrays like BET , LEG  had been cleaned
#
proc ::ob_bet::_get_types_for_group { group_id {type ""} {xstkArrayName ""} {ignore_acc_min "N"} } {

	variable GROUP
	variable TYPE
	variable CHANNEL
	variable CUST
	variable CUST_DETAILS
	variable BET
	variable XSTK
	variable BET_TYPE_LIMITS

	set got_xstk 0

	if { $type == "" } {

		_log INFO "Getting details of all bet types for group $group_id"
	} else {

		_log INFO "Getting details of bet type $type for group $group_id"
	}

	if { [_smart_reset TYPE] } {

		_load_bet_types
	}

	if { [_smart_reset GROUP] || ![info exists GROUP($group_id,num_legs)] } {
		error\
		"group $group_id not described"\
		""\
		UTIL_INVALID_GROUP
	}


	set got_xstk [expr {$xstkArrayName != ""}]

	if { $got_xstk } {

		upvar 1 $xstkArrayName xstArray
		# To add  supplied  cumulative stakes , other than this group.
		foreach index [array names xstArray] {

			set XSTK($index) $xstArray($index)

		}
	}

	#get the scale factor, exchange rate and cust details
	set scale_factor 1
	set intercept_value ""
	set exch_rate 1

	if { ![_smart_reset CUST] && $CUST(num) && $CUST(check) } {
		#get the customer details
		_get_cust_details
		set exch_rate $CUST_DETAILS(exch_rate)
		foreach {cust_scale_factor intercept_value lg} [_get_cust_ev_lvl_limits $group_id] { break }
		set scale_factor [expr {$scale_factor * $cust_scale_factor}]
	}

	set scale_factor [expr {$scale_factor * $CHANNEL([_get_config source],max_stake_mul)}]


	set check_cross_bet_maxima [expr {[_get_config cross_bet_maxima] == "Y" && [info exists BET(num)] &&  $BET(num) > 1}]

	_log DEBUG  "  Cross Bet Maxima Flag :  $check_cross_bet_maxima   "


	if { $check_cross_bet_maxima && $type != "" } {

		_calculate_cross_bet_contributions

		foreach bet  $GROUP($group_id,bets)  {

			set bet_type $BET($bet,bet_type)

			if { $bet_type == $type } {

				set XSTK(this_bet) $bet

			}
		}
		# End of for each bet loop
		set got_xstk 1
	}


	if {  $got_xstk == 1 } {

		_get_leg_limits $scale_factor $exch_rate $GROUP($group_id,legs) XSTK

	} else {

		_get_leg_limits $scale_factor $exch_rate $GROUP($group_id,legs)

	}


	if { $GROUP($group_id,num_legs) == 1 } {

		if { $type != "" && $type != "SGL" } {
			return [list]
		}

		if { $GROUP($group_id,min_combi) > 1 && $ignore_acc_min == "N" } {
			return [list]
		}

		set limits [_get_limits $group_id "SGL" $scale_factor $exch_rate $got_xstk]
		lappend limits $intercept_value

		set  BET_TYPE_LIMITS($type) $limits

		return [list "SGL" $limits]
	}

	set num_sub_groups $GROUP($group_id,num)

	if {![info exists TYPE([_get_config source],$num_sub_groups)]} {
		return [list]
	}

	set res [list]

	foreach bet_type $TYPE([_get_config source],$num_sub_groups) {
		set num_lines 0

		if {$type != "" && $type != $bet_type} {
			continue
		}
		_log DEV "Checking $bet_type"


		#max,min combi
		#if we have bankers we must look at the minimum that can be combined
		#for singles we ignore bankers so will ignore them here too
		set min_combi   $GROUP($group_id,min_combi)
		set num_bankers $GROUP($group_id,num_bankers)

		if {$bet_type != "SGL" && $min_combi<=$num_bankers} {
			if {$num_bankers == $GROUP($group_id,num_legs)} {
				#every leg is a banker - every leg must be in the bet
				set min_combi $num_bankers
			} else {
				#we need at least one other non banker
				#for these to be combined with
				set min_combi [expr {$num_bankers + 1}]
			}
		}

		if {$GROUP($group_id,max_combi) < $TYPE($bet_type,max_combi) ||
		    $min_combi > $TYPE($bet_type,min_combi)} {
			_log DEV "Bet type not valid: max min combi"
			continue
		}

		#only allow perm bet types for perm bets and groups with bankers
		set is_perm $TYPE($bet_type,is_perm)
		if { $GROUP($group_id,num_nocombi) != 0 && !$is_perm } {
			_log DEV "Bet type not valid:\
			  Cannot have non-combinables in a\
			  $bet_type since it is not permable."
			continue
		}
		if { $num_bankers != 0 && !$is_perm } {
			if { $TYPE($bet_type,num_selns) == $GROUP($group_id,num_legs) && \
			     $TYPE($bet_type,num_lines) == 1 } {
				_log DEV \
				  "Allowing bankers in a non-permable bet type\
				   since they'll only be one line anyway."
				# TODO: be nice to not record the legs as bankers in the DB tho
			} else {
				_log DEV "Bet type not valid:\
				  Cannot have bankers in a $bet_type\
				  since it is not permable (and will
				  have multiple lines in this case)."
				continue
			}
		}

		#if any of the groups contain any antepost selections do not offer any bet
		#types that are in DISALLOWED_AP_BETS [TTE078 / RFC 010]
		set is_ap 0
		for {set i 0} {$i<$GROUP(num)} {incr i} {
			if { ($GROUP($i,is_ap) == "Y") } {
				set is_ap 1
			}
		}

		if { $is_ap &&
			([lsearch -exact [OT_CfgGet DISALLOWED_AP_BETS {}] $bet_type] >= 0) } {
			_log DEV "Bet type not valid: $bet_type is in DISALLOWED_AP_BETS list"
			continue
		}

		#get limits for this bet type
		_log DEV "Bet type $bet_type valid - getting limits ..."

		set limits [_get_limits $group_id $bet_type $scale_factor $exch_rate $got_xstk]

		lappend limits $intercept_value

		set  BET_TYPE_LIMITS($type) $limits

		lappend res $bet_type $limits
	}

	return $res

}


# Get some details of how max bets are arrived at.
proc ob_bet::_get_max_bet_details {arrName {legs ""}} {

	variable CUST_DETAILS
	variable SELN
	variable LEG
	variable TYPE

	upvar 1 $arrName MB

	catch {unset MB} ; array set MB [list]

	set MB(mb_keys)   [list L,W S,W L,P S,P F T SGL]

	if { $legs == "" } {
		# All legs => all selns
		set MB(selns) $LEG(selns)
	} else {
		# List the lists of selns in each leg.
		set leg_selns [list]
		foreach leg $legs {
			lappend leg_selns $LEG($leg,selns)
		}
		# Flatten.
		set selns [eval [linsert $leg_selns 0 concat]]
		# Make unique.
		set selns [lsort -integer -unique $selns]
		set MB(selns) $selns
	}

	_get_cust_details

	set exch_rate $CUST_DETAILS(exch_rate)

	foreach seln $MB(selns) {

		# Convert to customer's currency.

		set MB($seln,L,W,max) [expr {$SELN($seln,max_bet)      * $exch_rate}]
		set MB($seln,S,W,max) [expr {$SELN($seln,max_sp_bet)   * $exch_rate}]
		set MB($seln,L,P,max) [expr {$SELN($seln,max_place_lp) * $exch_rate}]
		set MB($seln,S,P,max) [expr {$SELN($seln,max_place_sp) * $exch_rate}]
		set MB($seln,F,max)   [expr {$SELN($seln,fc_stk_limit) * $exch_rate}]
		set MB($seln,T,max)   [expr {$SELN($seln,tc_stk_limit) * $exch_rate}]
		set MB($seln,SGL,max) [expr {$TYPE(SGL,max_bet)        * $exch_rate}]

		# Already in customer's currency.

		foreach mb_key $MB(mb_keys) {
			set MB($seln,$mb_key,cum) $CUST_DETAILS(cum_stake,$seln,$mb_key)
		}

	}

	return 1
}


#Get valid combinations for entered legs
proc ::ob_bet::_get_combis {{legs ""}} {

	variable LEG
	variable SELN
	variable COMBI

	set combi_ident [join $legs ","]

	#TODO make sure the selected args have already been added
	if {![_smart_reset COMBI] && [info exists COMBI(${combi_ident},combis)]} {
		return $COMBI(${combi_ident},combis)
	}

	if {[catch _verify_selns msg]} {
		error\
			"Could not verify selections: $msg"\
			""\
			UTIL_UNABLE_TO_GET_SELNS
	}

	if {$legs == ""} {
		#get combinations for all legs added
		for {set i 0} {$i < $LEG(num)} {incr i} {
			lappend legs $i
		}
	}

	_log INFO "getting available combinations for legs: $legs"

	foreach leg $legs {

		#some leg sorts demand to not be permed with any other selections
		#ie AH split line bets
		if {$LEG($leg,can_combi) == "N"} {
			if {[llength $legs] == 1} {
				set no_combi $legs
			} else {
				set no_combi {}
			}

			#if we have an item that is not combinable we'll return early
			set COMBI(${combi_ident},combis) $no_combi
			return $no_combi
		}
	}

	#work out the buckets
	set buckets [_create_buckets $legs]

	#return the buckets, orderng them because the calling
	#app probably expects them in order
	set groups [list]
	foreach bucket $buckets {
		lappend groups [lsort -integer $bucket]
	}
	set COMBI(${combi_ident},combis) $groups

	return $groups
}



#
#
proc ::ob_bet::_create_buckets {legs} {

	set res [list]

	foreach l $legs {
		set pos [lsearch -exact $legs $l]
		if {$pos == -1} {
			#already eliminated from list
			continue
		}

		foreach {curr_bucket legs}\
			[_append_to_bucket {} $l $legs $pos] {break}
		lappend res $curr_bucket
	}

	return $res
}



#
#
proc ::ob_bet::_append_to_bucket {curr_bucket leg legs pos} {

	variable COMBI

	#remove the leg from the list
	set legs [lreplace $legs $pos $pos]

	lappend curr_bucket $leg

	foreach l $COMBI($leg,no_combi_legs) {
		set pos [lsearch -exact $legs $l]
		if {$pos == -1} {
			#already eliminated from list
			continue
		}

		foreach {curr_bucket legs}\
			[_append_to_bucket $curr_bucket $l $legs $pos] {break}
	}

	return [list $curr_bucket $legs]
}



# Will indicate whether there is a special combination
# available ie Forecast, tricast, Scorecast etc.
#
proc ::ob_bet::_get_special_combis { legs } {

	variable LEG
	variable SELN

	if {[catch _get_selns msg]} {
		error\
			"Could not get selections $msg"\
			""\
			UTIL_UNABLE_TO_GET_SELNS
	}


	# calculate combinations for all legs added
	if {$legs == ""} {
		for {set i 0} {$i < $LEG(num)} {incr i} {
			lappend legs $i
		}
	}

	# only calculate combinations for the following selections
	set selns [list]
	foreach leg_no $legs {
		foreach s $LEG($leg_no,selns) {
			if {[lsearch $selns $s] == -1} {
				lappend selns $s
			}
		}
	}

	set combis [list]

	# lets looks at selections with shared markets
	foreach mkt $SELN(repeated_mkts) {
		set leg_sorts [list]

		# only combine if selection is within our 'combinable list' and not an
		# unnamed favourite
		set selns_not_unnamed [list]
		foreach seln $SELN(mkt,$mkt,selns) {
			if {[lsearch $selns $seln] != -1 && $SELN($seln,fb_result) == "-"} {
				lappend selns_not_unnamed $seln
			}
		}
		if {[llength $selns_not_unnamed] < 2} {
			continue
		}

		set first_seln [lindex $selns_not_unnamed 0]
		set num_selns  [llength $selns_not_unnamed]

		set fc_avail $SELN($first_seln,fc_avail)
		set tc_avail $SELN($first_seln,tc_avail)

		if {$fc_avail == "Y"} {
			lappend leg_sorts "SF" "RF"
		}
		if {$num_selns >= 3} {
			if {$tc_avail == "Y"} {
				lappend leg_sorts "TC" "CT"
			}
			if {$fc_avail == "Y"} {
				lappend leg_sorts "CF"
			}
		}
		if {[llength $leg_sorts] > 0} {
			lappend combis $selns_not_unnamed $leg_sorts ""
		}
	}


	# now selections with shared event
	foreach ev $SELN(repeated_evs) {
		set FS_detected 0
		set CS_detected 0
		set fs_selns [list]
		set cs_selns [list]

		set num_selns [llength $SELN(ev,$ev,selns)]
		set sc_selns [list]
		foreach seln $SELN(ev,$ev,selns) {

			# ignore those selections which are not in our 'combinable list'
			if {[lsearch $selns $seln] == -1} {
				continue
			}
			set mkt_sort $SELN($seln,mkt_sort)
			if {$mkt_sort == "FS"} {
				set FS_detected 1
				lappend fs_selns $seln
			} elseif {$mkt_sort == "CS"} {
				set CS_detected 1
				lappend cs_selns $seln
			}
		}

		# quite a bit more to do here
		# -is the SC market present?
		# -is score compatible with the FS selection?
		if {$FS_detected && $CS_detected} {
			foreach cs_seln $cs_selns {
				foreach fs_seln $fs_selns {
					foreach {
						avail
						status
						num
						den
					} [_fscs_leg $cs_seln $fs_seln] {break}

					if {$avail} {
						lappend combis\
							[list $fs_seln $cs_seln]\
							"SC"\
							[list $num $den]
					}
				}
			}
			#lappend combis $sc_selns "SC"
		}
	}

	return $combis
}



#Check whether two legs can be combined
proc ::ob_bet::_can_combine_leg {leg1 leg2} {
	variable LEG

	if {$LEG($leg1,can_combi) == "N" ||
	    $LEG($leg2,can_combi) == "N"} {
		return 0
	}

	foreach seln1 $LEG($leg1,selns) {
		foreach seln2 $LEG($leg2,selns) {
			if {![_can_combine $seln1 $seln2]} {
				return 0
			}
		}
	}
	return 1
}



# Check whether two outcomes can be combined
# We can assume SELN has been completely set up
proc ::ob_bet::_can_combine {oc1 oc2} {
	variable SELN
	variable COMBI

	#selections cannot have the same mult_key
	if {$SELN($oc1,mult_key) != "" &&
	    $SELN($oc2,mult_key) != "" &&
	    $SELN($oc1,mult_key) == $SELN($oc2,mult_key)} {
		_log DEBUG "can't combine $oc1 and $oc2 - mult-key"
		return 0
	}
	if {$SELN($oc1,ev_mult_key) != "" &&
	    $SELN($oc2,ev_mult_key) != "" &&
	    $SELN($oc1,ev_mult_key) == $SELN($oc2,ev_mult_key)} {
		_log DEBUG "can't combine $oc1 and $oc2 - ev-mult-key"
		return 0
	}

	#xmul limits the outcomes to be in the same class or type
	if {($SELN($oc1,xmul) == "C" || $SELN($oc2,xmul) == "C") &&
	    $SELN($oc1,ev_class_id) != $SELN($oc2,ev_class_id)} {
		_log DEBUG "can't combine $oc1 and $oc2 - xmul C"
		return 0
	}
	if {($SELN($oc1,xmul) == "T" || $SELN($oc2,xmul) == "T") &&
	    $SELN($oc1,ev_type_id) != $SELN($oc2,ev_type_id)} {
		_log DEBUG "can't combine $oc1 and $oc2 - xmul T"
		return 0
	}

	#can't normally combine items under the same event
	if {$SELN($oc1,ev_id) == $SELN($oc2,ev_id)} {
		#never allowed outcomes from the same market
		if {$SELN($oc1,ev_mkt_id) == $SELN($oc2,ev_mkt_id)} {
			_log DEBUG "can't combine $oc1 and $oc2 - same mkt"
			return 0
		}
		#some markets under the same events can be combined
		#if they're deemed to be non-correlated ie:
		#an odds/even market and a win market
		#these are represented in the combi_mkts config param
		set combi1 0
		set combi2 0
		foreach {ev_class_id mkt_sorts} [_get_config combi_mkts] {
			if {$ev_class_id == $SELN($oc1,ev_class_id) &&
			    [lsearch $mkt_sorts $SELN($oc1,mkt_sort)] != -1} {
				set combi1 1
			}
			if {$ev_class_id == $SELN($oc2,ev_class_id) &&
			    [lsearch $mkt_sorts $SELN($oc2,mkt_sort)] != -1} {
				set combi2 1
			}

		}
		if {!($combi1 && $combi2)} {
			_log DEBUG "can't combine $oc1 and $oc2 - same event"
			return 0
		}
	}

	#can't combine dissimilar event sorts - this is to prevent
	#match being combined in a multiple with the tournament it's
	#in. Also, specifically can't combine Tournament selections
	#within an Event Type (for compatibility with placebet2
	#functionality)
	if {($SELN($oc1,ev_type_id) == $SELN($oc2,ev_type_id)) &&
	    (($SELN($oc1,ev_sort) != $SELN($oc2,ev_sort)) ||
	     ($SELN($oc1,ev_sort) == "TNMT"))} {
		_log DEBUG "can't combine $oc1 and $oc2 - ev_sort"
		return 0
	}

	return 1
}



# Get lines from bet that thisselection is in
proc ::ob_bet::_get_lines_per_seln {group_id sub_group leg bet_type} {

	variable TYPE
	variable LEG
	variable GROUP

	if {[_smart_reset TYPE]} {
		_load_bet_types
	}

	if {[info exists GROUP($group_id,$bet_type,$sub_group,$leg,lines)]} {
		return [list\
					$GROUP($group_id,$bet_type,num_lines)\
					$GROUP($group_id,$bet_type,$sub_group,$leg,lines)]
	}


	#are we going to look at potential winnings too
	if {[_get_config potential_winnings] == "Y" &&
		$GROUP($group_id,price_avail) == "Y"} {
		set calc_price 1
	} else {
		set calc_price 0
	}

	#shortcut for non permed bets
	if {$GROUP($group_id,num_bankers) == 0
	    && ($TYPE($bet_type,num_selns) == $GROUP($group_id,num_legs))} {

		if {$GROUP($group_id,simple) && !$calc_price} {
			#no complex legs - lets use the value on the DB
			return [list\
						$TYPE($bet_type,num_lines)\
						$TYPE($bet_type,num_bets_per_seln)]
		}

		set price            0.0
		set pot_return_place 0.0
		set num_lines        0

		set GROUP($group_id,$bet_type,lines) [_bet_type_lines $bet_type]
		foreach combi $GROUP($group_id,$bet_type,lines) {

			set combi_price 1
			set ret_place   1
			set combi_lines 1
			foreach sg $combi {
				if {![info exists GROUP($group_id,$sg,price)]} {
					set combi_price 0
				} else {
					set combi_price [expr {$combi_price * $GROUP($group_id,$sg,price)}]
				}

				set ret_place [expr {
					[info exists  GROUP($group_id,$sg,pot_return_place)] ?
					$ret_place * $GROUP($group_id,$sg,pot_return_place)  :
					0
				}]

				set combi_lines [expr {$combi_lines * $GROUP($group_id,$sg,num_lines)}]
			}
			foreach sg $combi {
				foreach l $GROUP($group_id,$sg,legs) {
					set leg_lines [expr {$combi_lines * $LEG($l,num_lines_per_seln) /
										 $GROUP($group_id,$sg,num_lines)}]

					if {![info exists GROUP($group_id,$bet_type,$sg,$l,lines)]} {
						set GROUP($group_id,$bet_type,$sg,$l,lines) $leg_lines
					} else {
						incr GROUP($group_id,$bet_type,$sg,$l,lines) $leg_lines
					}
				}
			}
			set price            [expr {$combi_price + $price}]
			set pot_return_place [expr {$ret_place   + $pot_return_place}]
			set num_lines        [expr {$combi_lines + $num_lines}]
		}

		if {[llength $combi] > 0 &&
			$TYPE($bet_type,line_type) != "S" &&
			$bet_type != "ROB" && $bet_type != "FLG"} {
			set GROUP($group_id,$bet_type,price) $price
			set GROUP($group_id,$bet_type,pot_return_place) $pot_return_place
		}

		set num_bets_per_seln 0
		if {[info exists GROUP($group_id,$bet_type,$sub_group,$leg,lines)]} {
			set num_bets_per_seln\
				$GROUP($group_id,$bet_type,$sub_group,$leg,lines)
		}
		set GROUP($group_id,$bet_type,num_lines) $num_lines
		return [list\
					$num_lines\
					$num_bets_per_seln]
	}

	#this is a permed bet-type
	set lines 0
	set leg_lines 0
	set price 0.0
	set pot_ret_plc 0.0
	set GROUP($group_id,$bet_type,lines) [list]

	set i $TYPE($bet_type,min_combi)
	for {} {$i <= $TYPE($bet_type,max_combi)} {incr i} {
		_pick_n_from_group $i $group_id
		incr lines $GROUP($group_id,pick,$i)
		set GROUP($group_id,$bet_type,lines) \
			[concat $GROUP($group_id,$bet_type,lines) $GROUP($group_id,pick,$i,lines)]
		incr leg_lines [expr {$GROUP($group_id,$sub_group,pick,$i)
							  * $LEG($leg,num_lines_per_seln)}]

		if {[_get_config potential_winnings] == "Y" &&
		    $GROUP($group_id,price_avail) == "Y"} {
			set price       [expr {$price + $GROUP($group_id,price,$i)}]
			set pot_ret_plc [expr {$pot_ret_plc + $GROUP($group_id,pot_return_place,$i)}]
		}
	}
	if {$calc_price &&
	    ![info exists GROUP($group_id,$bet_type,price)]} {
		set GROUP($group_id,$bet_type,price) $price
		set GROUP($group_id,$bet_type,pot_return_place) $pot_ret_plc
		ob_log::write DEBUG {GROUP($group_id,$bet_type,price) = $GROUP($group_id,$bet_type,price)}
		ob_log::write DEBUG {GROUP($group_id,$bet_type,prp)   = $GROUP($group_id,$bet_type,pot_return_place)}
	}

	return [list $lines $leg_lines]
}



#Combinatorial procedure
proc ::ob_bet::_pick_n_from_group {n group_id} {

	variable GROUP

	#have we already looked up the value?
	if {[info exists GROUP($group_id,pick,$n)]} {
		#already looked up
		return
	}

	#are we going to look at potential winnings too
	if {[_get_config potential_winnings] == "Y" &&
		$GROUP($group_id,price_avail) == "Y"} {
		set calc_price 1
	} else {
		set calc_price 0
	}

	set num_lines 0
	set GROUP($group_id,pick,$n,lines) [list]

	#lets first look at bankers
	#they are in every leg so don't need to consider
	#combinations of bankers
	#For singles we are going to ignore bankers
	if {$n > 1} {
		set pick [expr {$n - $GROUP($group_id,num_bankers)}]
	} else {
		set pick 1
	}

	#number of bankers must be less than the number of selections we're
	#trying to pick
	if {$pick < 0} {
		error\
			"picking $n selns with $GROUP($group_id,num_bankers) bankers"\
			""\
			UTIL_TOO_MANY_BANKERS
	}

	#singles
	if {$n == 1} {
		#shortcut as nothing is combined
		#we ignore bankers on permed singles
		set num_lines 0
		set price 0.0
		set pot_return_place 0.0
		foreach sg $GROUP($group_id,non_banker_sgs) {
			set l $GROUP($group_id,$sg,num_lines)

			if {$calc_price} {
				set price [expr {$price + $GROUP($group_id,$sg,price)}]
				set pot_return_place [expr {$pot_return_place + $GROUP($group_id,$sg,pot_return_place)}]
			}
			incr num_lines $l
			set GROUP($group_id,$sg,pick,1) 1
			lappend GROUP($group_id,pick,1,lines) $GROUP($group_id,$sg,legs)
		}
		foreach sg $GROUP($group_id,banker_sgs) {
			set l $GROUP($group_id,$sg,num_lines)
			incr num_lines $l
			if {$calc_price} {
				set price [expr {$price + $GROUP($group_id,$sg,price)}]
				set pot_return_place [expr {$pot_return_place + $GROUP($group_id,$sg,pot_return_place)}]
			}
			set GROUP($group_id,$sg,pick,1) 1
			lappend GROUP($group_id,pick,1,lines) $GROUP($group_id,$sg,legs)
		}
		set GROUP($group_id,pick,1) $num_lines

		if {$calc_price} {
			set GROUP($group_id,price,1) $price
			set GROUP($group_id,pot_return_place,1) $pot_return_place
		}
		return
	}

	#banker lines
	set num_banker_lines 1
	set banker_price 1.0
	set banker_pot_return_place 1.0
	foreach sg $GROUP($group_id,banker_sgs) {
		set num_banker_lines [expr {$num_banker_lines
									* $GROUP($group_id,$sg,num_lines)}]
		if {$calc_price} {
			set banker_price [expr {$banker_price
			                        * $GROUP($group_id,$sg,price)}]
			set banker_price [expr {$banker_pot_return_place * $GROUP($group_id,$sg,pot_return_place)}]
		}
	}

	if {$pick == 0} {
		#OK this may be a problem if we have non-bankers ie consider the case
		#where we are picking doubles from four with 2 bankers - the 2 non
		#banker selections would not be included.
		#However if we don't have any non banker selections in the group ie:
		#a double of two selections that happen to be marked as bankers then
		#this is fine as we will later ignore bankers
		#when the number of bankers =number of legs

		if {[llength $GROUP($group_id,non_banker_sgs)] != 0} {
			error\
				"picking $n selns with $GROUP($group_id,num_bankers) bankers"\
				""\
				UTIL_TOO_MANY_BANKERS
		}

		set num_lines $num_banker_lines

		foreach sg $GROUP($group_id,banker_sgs) {
			set GROUP($group_id,$sg,pick,$n)\
				[expr {$num_lines / $GROUP($group_id,$sg,num_lines)}]
		}

		set GROUP($group_id,pick,$n) $num_lines

		if {$calc_price} {
			set GROUP($group_id,price,$n) $banker_price
			set GROUP($group_id,pot_return_place,$n) $banker_pot_return_place
		}

		return
	}

	#now have to go through each combination
	if {[catch {
		set combis [ot::genCombis $pick $GROUP($group_id,non_banker_sgs)]
	} msg]} {
		error\
			"Unable to generate combinations $msg"\
			""\
			UTIL_CANT_GET_COMBIS
	}

	set price 0.0
	set pot_return_place 0.0
	foreach combi $combis {
		set combi_lines $num_banker_lines
		if {$calc_price} {
			set combi_price $banker_price
			set combi_pot_return_place $banker_pot_return_place
		}
		foreach sg $combi {
			if {$calc_price} {
				set combi_price [expr {$combi_price *
									   $GROUP($group_id,$sg,price)}]
				set combi_pot_return_place [expr {$combi_pot_return_place *
									   $GROUP($group_id,$sg,pot_return_place)}]
			}
			set combi_lines [expr {$combi_lines *
								   $GROUP($group_id,$sg,num_lines)}]
		}

		#now need to work out lines per sub group for non-bankers
		#this is basically all the above lines not generated by the
		#actual group
		#example:
		#four groups
		#a contributes Na lines
		#b contributes Nb lines
		#c contributes Nc lines
		#d contributes Nd lines
		#Taking subgroup a as a whole entity number of lines with subgroup a =
		#Nb * Nc * Nd = total lines / Na
		foreach sg $combi {
			if {[info exists GROUP($group_id,$sg,pick,$n)]} {
				incr GROUP($group_id,$sg,pick,$n)\
					[expr {$combi_lines/$GROUP($group_id,$sg,num_lines)}]
			} else {
				set GROUP($group_id,$sg,pick,$n)\
					[expr {$combi_lines/$GROUP($group_id,$sg,num_lines)}]
			}
		}
		incr num_lines $combi_lines
		if {$calc_price} {
			set price [expr {$combi_price + $price}]
			set pot_return_place [expr {$combi_pot_return_place + $pot_return_place}]
		}
	}

	#now work out lines per sub-group for bankers
	foreach sg $GROUP($group_id,banker_sgs) {
		set GROUP($group_id,$sg,pick,$n)\
			[expr {$num_lines / $GROUP($group_id,$sg,num_lines)}]
	}

	if {$calc_price} {
		set GROUP($group_id,price,$n) $price
		set GROUP($group_id,pot_return_place,$n) $pot_return_place
	}
	set GROUP($group_id,pick,$n) $num_lines

	# Build up a list of the lines
	foreach combi $combis {
		set combi_lines [list]

		# Add the banker subgroups to the combi
		set combi [concat $combi $GROUP($group_id,banker_sgs)]
		foreach sg $combi {
			set legs $GROUP($group_id,$sg,legs)

			if {[llength $combi_lines] == 0} {
				set combi_lines $legs
			} else {
				set new_lines [list]
				foreach leg $legs {
					foreach line $combi_lines {
						lappend new_lines [lsort [concat $line $leg]]
					}
				}
				set combi_lines $new_lines
			}
		}

		set GROUP($group_id,pick,$n,lines) \
			[concat $GROUP($group_id,pick,$n,lines) $combi_lines]
	}
}


#Check input arguments
proc ::ob_bet::_check_arg {name val type nullable {min ""} {max ""}} {

	set err 0
	if {!$nullable && $val == ""} {
		error\
			"value must be given for $name"\
			""\
			UTIL_CHECKARG_NULL
	}
	if {$nullable && $val == ""} {
		return
	}

	switch -- $type {
		"IPADDR" {
			#ie: 127.0.0.3
			if {[regexp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$} $val] == 0} {
				set err 1
			}
			set numeric 0
		}
		"INT" {
			#ie: 22 -9
			if {[regexp {^[\-]?[0-9]+$} $val] == 0} {
				set err 1
			}
			set numeric 1
		}
		"CCY" {
			#ie: 20.00 20
			if {[regexp {^[0-9]+(\.[0-9][0-9])?$} $val] == 0} {
				set err 1
			}
			set numeric 1
		}
		"NUMERIC" {
			#ie: -23.45 23 0.2345
			if {[regexp {^[\-]?[0-9]+(\.[0-9])?[0-9]*$} $val] == 0} {
				set err 1
			}
			set numeric 1
		}
		"CHAR" {
			#ie: ABCDE123
			set numeric 0
		}
		"YN" {
			#ie: Y N
			if {$val != "Y" && $val != "N"} {
				set err 1
			}
			set numeric 0
		}
		"LIST_INTS" {
			#ie 22 456 34
			if {[regexp {^[0-9\s]+$} $val] == 0} {
				set err 1
			}
		}
		default {
			error\
				"Invalid type $type"\
				""\
				UTIL_CHECKARG_INVALID_TYPE
		}
	}

	if {$err} {
		error\
			"Expected $type for $name got: $val"\
			""\
			UTIL_CHECKARG_INVALID_VAL
	}

	if {$max != ""} {
		if {$numeric && $val > $max} {
			error\
				"$name: $type greater than max $max"\
				""\
				UTIL_CHECKARG_GT_MAX_NUM
		}
		if {!$numeric && ([string length $val] > $max)} {
			error\
				"$name: $type greater than max $max"\
				""\
				UTIL_CHECKARG_GT_MAX_CHAR
		}
	}

	if {$min != ""} {
		if {$numeric && $val < $min} {
			error\
				"$name: $type less than min $min"\
				""\
				UTIL_CHECKARG_GT_MIN_NUM
		}
		if {!$numeric && ([string length $val] < $min)} {
			error\
				"$name: $type less than min $min"\
				""\
				UTIL_CHECKARG_GT_MIN_CHAR
		}
	}
}

# ***** This procedure is deprecated - use _get_receipt instead *****
#
# Default procedure for formating bet receipts -
# another procedure can be registered on ob_bet::init
proc ::ob_bet::_format_receipt {bet_num} {

	variable CUST_DETAILS
	variable CUST

	set cust_id   $CUST(cust_id)
	set bet_count [expr {$CUST_DETAILS(bet_count) + $bet_num + 1}]
	set receipt "O/[format %07s $cust_id]/[format %07s $bet_count]"
	return $receipt
}


proc ::ob_bet::_get_receipt {bet_id} {

	set rs [ob_db::exec_qry ob_bet::get_receipt $bet_id]
	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		_log ERROR "Warning: qry ob_bet::get_receipt did not return 1 row"
	}
	set receipt [db_get_col $rs 0 receipt]
	return $receipt
}


::ob_bet::_log INFO "sourced util.tcl"

#
# Checks to see whether the group limits are 'No stake factor, No bet type' dependent.
#
proc ::ob_bet::_chk_grp_no_sf_no_bt {group_id} {

	variable GROUP
	variable LEG
	variable SELN

	#caller has made sure that the above are initialised

	#does the group have more than one leg?
	if {$GROUP($group_id,num_legs) != 1} {
		return 0
	}

	#Get the leg in the group
	foreach leg $GROUP($group_id,0,legs) {break}

	#Does this leg have several selections?
	if {[llength $LEG($leg,selns)] != 1} {
		return 0
	}

	set seln [lindex $LEG($leg,selns) 0]

	if {$SELN($seln,fixed_stake_limits) == 1} {
		return 1
	}

	return 0
}

#
# Work out the potential prices for a given bet group and bet type
#

proc ::ob_bet::_get_pot_payout {stk group_id bet_type leg_type} {

	variable BET
	variable GROUP
	variable LEG
	variable SELN

	set ew_terms [list]
	set prices   [list]

	for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {

		foreach leg $GROUP($group_id,$sg,legs) {

			# if it is a leg_sort that we cannot work this out for then just return
			if {[lsearch {SF RF CF TC CT} $LEG($leg,leg_sort)] != -1} {
				return "0.00"
			}

			foreach seln $LEG($leg,selns) {

				# ew details
				if {
					($leg_type == "E" || $leg_type == "P")
				} {
					set ew_fac_num $SELN($seln,ew_fac_num)
					set ew_fac_den $SELN($seln,ew_fac_den)
				} else {
					set ew_fac_num "1.00"
					set ew_fac_den "1.00"
				}

				lappend ew_terms [list $ew_fac_num $ew_fac_den]

				# price
				# If Live prices are not set, we fall back on guide prices
				# This can happen on priced markets when selecting 'Favourite'
				if {$SELN($seln,lp_avail) == "Y" && $SELN($seln,lp_exists) == "Y" \
				    && [info exists SELN($seln,lp_num)] && [info exists SELN($seln,lp_den)] \
				    && $SELN($seln,lp_num) != "" && $SELN($seln,lp_num) != ""} {
					lappend prices [list $SELN($seln,lp_num) $SELN($seln,lp_den)]
				} else {
					lappend prices [list $SELN($seln,sp_num_guide) $SELN($seln,sp_den_guide)]
				}

			}
		}
	}

	set pot_win [_could_win_frac $bet_type $stk $leg_type $prices $ew_terms]

	return [format {%.2f} $pot_win]
}

#
# Parameters are
#    bet_type   - a 3/4 letter bet type code (SGL/DBL/TRX/...)
#    spl        - stake per line
#    prices     - list of lists seln prices [list lp_num lp_den]
#    ew_terms   - list of lists ew terms [list ew_num ew_den]
#
proc ::ob_bet::_could_win_frac {bet_type spl leg_type prices {ew_terms ""} {AH_hcap ""}} {


	if {$leg_type == "E" || $leg_type == "P"} {
		if {[llength $prices] != [llength $ew_terms]} {
			error "prices and each-way terms don't match"
		}
	}
	set PRICES   [list]
	set EW_TERMS [list]
	set HCAPS    [list]

	foreach price $prices ew_term $ew_terms hcap $AH_hcap {
		lappend PRICES [expr {1.0+double([lindex $price 0])/double([lindex $price 1])}]
		if {$ew_term == "" || $ew_term == {{} {}} } {
			set ew_term [list 1 1]
		}
		lappend EW_TERMS [expr {double([lindex $ew_term 0])/double([lindex $ew_term 1])}]

		if {$hcap != "" && [expr {$hcap/2.0}] != [expr {int($hcap/2.0)}]} {
			lappend HCAPS 2.0
		} else {
			lappend HCAPS 1.0
		}
	}

	return [_could_win_dec $bet_type $spl $leg_type $PRICES $EW_TERMS $HCAPS]

}

#
# Parameters are
#    bet_type   - a 3/4 letter bet type code (SGL/DBL/TRX/...)
#    spl        - stake per line
#    prices     - list of seln prices in decimal format
#    ew_terms   - list of ew terms in decimal format
#
proc ::ob_bet::_could_win_dec {bet_type stake_per_line leg_type prices ew_terms AH_hcap} {

	set i 0
	foreach price $prices ew_term $ew_terms hcap $AH_hcap {
		set RETURN(W,$i) [expr {$price * $hcap}]
		set RETURN(P,$i) [expr {1.0+($RETURN(W,$i)-1.0)*$ew_term}]
		incr i
	}

	set unit_rtn 0.0
	foreach type [expr {$leg_type=="E"?[list W P]:[list $leg_type]}] {
		foreach line [_bet_type_lines $bet_type] {
			set return 1.0
			foreach stake $line {
				set return [expr {$return*$RETURN($type,$stake)}]
			}
			set unit_rtn [expr {$unit_rtn+$return}]
		}
	}
	return [expr {$unit_rtn*$stake_per_line}]
}

#
# Return potential winnings for a bet type based on prices supplied.
#
# Use 1 as the stake to just return a potential winnings multiplier
#
# Parameters are
#    bet_type   - a 3/4 letter bet type code (SGL/DBL/TRX/...)
#    spl        - stake per line
#    leg_type   - W, E or P (win, each-way or place)
#    prices     - list of lists seln prices [list lp_num lp_den]
#    leg_sorts  - list of leg sorts (--, SF, etc.) associated with each seln
#                 price
#    ew_terms   - list of lists ew terms [list ew_num ew_den]
#
proc ::ob_bet::generic_pot_payout {bet_type spl leg_type prices leg_sorts {ew_terms ""} {AH_hcap ""}} {

	# check if it includes a leg sort that we cannot work this out for
	foreach sort [list SF RF CF TC CT] {
		if {[lsearch $leg_sorts $sort] > -1} {
			return "0.00"
		}
	}

	return [_could_win_frac $bet_type $spl $leg_type $prices $ew_terms]
}

#
#	Returns calcualted maximum bet limit for the given bet type .
# 	If there is no entry for the given bet type , it just returns an list with Maximum value.
#	This function should not be used , if bet types minimum limit is needed
#
proc ::ob_bet::get_calculated_bet_type_limits { type }  {

	variable    BET_TYPE_LIMITS

	if { [info exists BET_TYPE_LIMITS($type)  ] } {
		return $BET_TYPE_LIMITS($type)
	}

	# Returns a  list which contains maximum value
	return "999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 999999 "
}


::ob_bet::_log INFO "sourced util.tcl"


