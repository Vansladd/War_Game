################################################################################
# $Id: limits.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle customer specifics of bet placement
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
#    No public procedures
#
################################################################################
namespace eval ob_bet {
	#no API functions associated with customer limits
}

# Get the customer limits associated with this group and bet type.
# Set legs_have_xstk to true if the leg maxima include cross-bet stake; this
# will force us to avoid "caching" the maxima on the group (as we would
# normally do for simple, symmetric bets).
proc ::ob_bet::_get_limits {group_id bet_type sf exch_rate legs_have_xstk} {

	variable GROUP
	variable TYPE
	_log INFO "getting limits for $group_id - bet_type = $bet_type, exch_rate = $exch_rate, legs_have_xstk = $legs_have_xstk"

	#Does the group exist?
	if {[_smart_reset GROUP] || ![info exists GROUP($group_id,num_legs)]} {
		error\
		    "group $group_id not described"\
		    ""\
		    LIMITS_NO_GROUP
	}

	#Check whether the group limits are 'No stake factor, No bet type' dependent
	set no_sf_no_bt [_chk_grp_no_sf_no_bt $group_id]

	#get the limits
	#(win, place, forecast, tricast, )
	foreach {
		num_lines
		max_W
		max_P
		max_L_W
		max_L_P
		max_S_W
		max_S_P
		max_F
		max_T
		max_SGL
		min
		bet_type_sf
		leg_lines
	} [_get_bet_limits $group_id $bet_type $legs_have_xstk] {break}

	#bet_type max bet
	# MARTA TODO: this can be configurable
	# set max_bt [lindex [_get_type $bet_type max_bet] 1]
	set max_bt [expr {$TYPE($bet_type,max_bet) * $sf}]
	set min_bt $TYPE($bet_type,min_bet)

	# MARTA TODO: this can be configurable
	#if {[get_config scale_bet_type_max] != "N"} {
		#set max_bt [expr {$max_bt * $sf}]
	#}

	#Override limits with those of the bet_type. Ignore if no_sf_no_bt is set to 1
	if {!$no_sf_no_bt} {
		set max_W [expr {$max_W < $max_bt
					? $max_W : $max_bt}]

		set max_P [expr {$max_P < $max_bt
					? $max_P : $max_bt}]

		set max_L_W [expr {$max_L_W < $max_bt
					? $max_L_W : $max_bt}]

		set max_L_P [expr {$max_L_P < $max_bt
					? $max_L_P : $max_bt}]

		set max_S_W [expr {$max_S_W < $max_bt
					? $max_S_W : $max_bt}]

		set max_S_P [expr {$max_S_P < $max_bt
					? $max_S_P : $max_bt}]

		set max_F [expr {$max_F < $max_bt
					? $max_F : $max_bt}]

		set max_T [expr {$max_T < $max_bt
					? $max_T : $max_bt}]

		set max_SGL [expr {$max_bt < $max_SGL
					? $max_bt : $max_SGL}]

		#for bet types we will reduce the min if it is lower so as to
		#allow customers to place bets on bet types with a large
		#numbers of lines
		set min [expr {$min < $min_bt
					? $min : $min_bt}]
	}

	#make sure values are sensible
	set zero_min 0
	if {$max_W < 0.0 || $max_W < $min} {
		_log INFO "max_W limit $max_W min $min setting max_W to 0.0"
		set max_W 0.0
		incr zero_min
	}
	if {$max_P < 0.0 || $max_P < $min} {
		_log INFO "max_P limit $max_P min $min setting max_P to 0.0"
		set max_P 0.0
		incr zero_min
	}
	if {$zero_min == 2} {
		_log INFO "both max_W and max_P are bad, setting min to 0.0"
		set min 0.0
	}

	if {$max_L_W < 0.0 || $max_L_W < $min} {
		_log INFO "max_L_W limit $max_L_W min $min setting max_L_W to 0.0"
		set max_L_W 0.0
	}
	if {$max_L_P < 0.0 || $max_L_P < $min} {
		_log INFO "max_L_P limit $max_L_P min $min setting max_L_P to 0.0"
		set max_L_P 0.0
	}
	if {$max_S_W < 0.0 || $max_S_W < $min} {
		_log INFO "max_S_W limit $max_S_W min $min setting max_S_W to 0.0"
		set max_S_W 0.0
	}
	if {$max_S_P < 0.0 || $max_S_P < $min} {
		_log INFO "max_S_P limit $max_S_P min $min setting max_S_P to 0.0"
		set max_S_P 0.0
	}

	# ensure FC/TC limits are sensible
	if {$max_F < 0.0 || $max_F < $min} {
		_log INFO "max_F limit $max_F min $min setting max_F to 0.0"
		set max_F 0.0
	}
	if {$max_T < 0.0 || $max_T < $min} {
		_log INFO "max_T limit $max_T min $min setting max_T to 0.0"
		set max_T 0.0
	}

	if {$max_SGL < 0.0 || $max_SGL < $min} {
		_log INFO "max_SGL limit $max_SGL min $min setting max_SGL to 0.0"
		set max_SGL 0.0
	}

	#are we going to include the potential winnings?
	if {
		[_get_config potential_winnings] == "Y" &&
		$GROUP($group_id,price_avail) == "Y" &&
		[info exists GROUP($group_id,$bet_type,price)] &&
		[info exists GROUP($group_id,$bet_type,pot_return_place)]

	} {
		set pot_rtn_win $GROUP($group_id,$bet_type,price)
		set pot_rtn_plc $GROUP($group_id,$bet_type,pot_return_place)

	} else {
		set pot_rtn_win {}
		set pot_rtn_plc {}
	}

	_log DEV "num lines   = $num_lines"
	_log DEV "max_W       = $max_W"
	_log DEV "max_P       = $max_P"
	_log DEV "max_L_W     = $max_L_W"
	_log DEV "max_L_P     = $max_L_P"
	_log DEV "max_S_W     = $max_S_W"
	_log DEV "max_S_P     = $max_S_P"
	_log DEV "max_F       = $max_F"
	_log DEV "max_T       = $max_T"
	_log DEV "max_SGL     = $max_SGL"
	_log DEV "max_bt      = $max_bt"
	_log DEV "min         = $min"
	_log DEV "grp_sf      = $sf"
	_log DEV "bet_type_sf = $bet_type_sf"
	_log DEV "leg_lines   = $leg_lines"
	_log DEV "pot_rtn_win = $pot_rtn_win"
	_log DEV "pot_rtn_plc = $pot_rtn_plc"

	return [list\
		$num_lines\
		[format "%0.2f" [expr {$max_W * $exch_rate}]]\
		[format "%0.2f" [expr {$max_P * $exch_rate}]]\
		[format "%0.2f" [expr {$max_L_W * $exch_rate}]]\
		[format "%0.2f" [expr {$max_L_P * $exch_rate}]]\
		[format "%0.2f" [expr {$max_S_W * $exch_rate}]]\
		[format "%0.2f" [expr {$max_S_P * $exch_rate}]]\
		[format "%0.2f" [expr {$max_F * $exch_rate}]]\
		[format "%0.2f" [expr {$max_T * $exch_rate}]]\
		[format "%0.2f" [expr {$min   * $exch_rate}]]\
		$pot_rtn_win \
		[format "%0.2f" [expr {$max_SGL * $exch_rate}]]\
		[format "%0.2f" [expr {$max_bt * $exch_rate}]]\
		$sf \
		$bet_type_sf \
		$leg_lines \
		$pot_rtn_plc]
}

#Get limits associated with this bet
# Set legs_have_xstk to true if the leg maxima include cross-bet stake; this
# will force us to avoid "caching" the maxima on the group (as we would
# normally do for simple, symmetric bets).
proc ::ob_bet::_get_bet_limits {group_id bet_type legs_have_xstk} {
	variable GROUP
	variable LEG
	variable TYPE

	set max_W      999999
	set max_P      999999
	set max_L_W    999999
	set max_L_P    999999
	set max_S_W    999999
	set max_S_P    999999
	set max_F      999999
	set max_T      999999
	set max_SGL    999999
	set min        0
	foreach {info_exists bet_type_sf} [get_type $bet_type stake_factor] {
		break
	}

	if {$info_exists == 0 || $bet_type_sf == ""} {
		set bet_type_sf 1.0
	}

	#Is this a very simple group ie:
	#   No legs with multiple part lines like a reversed forecast.
	#   No legs which cannot be combined.
	#   No bankers
	if {$GROUP($group_id,simple) && $GROUP($group_id,num_bankers) == 0} {
		#This means that the bet is completely symmetric.
		#That is to say each selection is in the same number of lines.
		#We do not need to worry about working out the number
		#lines for each leg. We will also store the computed value
		#as may be needed for multiple bet types.
		set symmetric 1

		#get the first leg
		foreach leg $GROUP($group_id,0,legs) {break}

		foreach {
			num_lines
			num_lines_per_seln
		} [_get_lines_per_seln $group_id 0 $leg $bet_type] {
			break
		}

		if {!$legs_have_xstk && [info exists GROUP($group_id,simple_min)]} {

			set scale_factor [expr {$bet_type_sf / $num_lines_per_seln}]

			set max_W   [expr {$scale_factor * $GROUP($group_id,simple_max_W)  }]
			set max_P   [expr {$scale_factor * $GROUP($group_id,simple_max_P)  }]
			set max_L_W [expr {$scale_factor * $GROUP($group_id,simple_max_L_W)}]
			set max_L_P [expr {$scale_factor * $GROUP($group_id,simple_max_L_P)}]
			set max_S_W [expr {$scale_factor * $GROUP($group_id,simple_max_S_W)}]
			set max_S_P [expr {$scale_factor * $GROUP($group_id,simple_max_S_P)}]
			set max_F   [expr {$scale_factor * $GROUP($group_id,simple_max_F)  }]
			set max_T   [expr {$scale_factor * $GROUP($group_id,simple_max_T)  }]
			set max_SGL [expr {$scale_factor * $GROUP($group_id,simple_max_SGL)}]
			set min     $GROUP($group_id,simple_min)

			return [list $num_lines $max_W $max_P $max_L_W $max_L_P $max_S_W \
			             $max_S_P $max_F $max_T $max_SGL $min $bet_type_sf $num_lines_per_seln]

		}
	} else {
		set symmetric 0
	}

	# We'll provide the number of lines in which each leg appears -
	# the caller may need this to calculate betslip-wide maximum bets.
	# For a symmetric bet, we'll just return one value; otherwise there'll
	# be a value for each leg.
	set leg_lines [list]

	set sg_max_mult_bet 0
	set sg_has_max_mult_bet 0

	for {set sg 0} {$sg < $GROUP($group_id,num)} {incr sg} {

		foreach leg $GROUP($group_id,$sg,legs) {

			set leg_max_W      $LEG($leg,max_bet_W)
			set leg_max_P      $LEG($leg,max_bet_P)
			set leg_max_L_W    $LEG($leg,max_bet_L_W)
			set leg_max_L_P    $LEG($leg,max_bet_L_P)
			set leg_max_S_W    $LEG($leg,max_bet_S_W)
			set leg_max_S_P    $LEG($leg,max_bet_S_P)
			set leg_max_F      $LEG($leg,max_bet_F)
			set leg_max_T      $LEG($leg,max_bet_T)
			set leg_max_SGL    $LEG($leg,max_bet_SGL)
			set leg_min        $LEG($leg,min_bet)

			set has_max_mult_bet $LEG($leg,has_max_mult_bet)
			if {$has_max_mult_bet && [_get_config max_mult_bet]} {
				set max_mult_bet $LEG($leg,max_mult_bet)
			} else {
				set max_mult_bet 0
			}

			#do we need to work out the number of lines for each leg
			if {!$symmetric} {
				_log DEBUG "non symmetric bet ..."
				foreach {
					num_lines
					num_lines_per_seln
				} [_get_lines_per_seln $group_id $sg $leg $bet_type] {
					break
				}

				lappend leg_lines $num_lines_per_seln

				set scale_factor [expr {$bet_type_sf / $num_lines_per_seln}]

				set leg_max_W   [expr {$scale_factor * $leg_max_W  }]
				set leg_max_P   [expr {$scale_factor * $leg_max_P  }]
				set leg_max_L_W [expr {$scale_factor * $leg_max_L_W}]
				set leg_max_L_P [expr {$scale_factor * $leg_max_L_P}]
				set leg_max_S_W [expr {$scale_factor * $leg_max_S_W}]
				set leg_max_S_P [expr {$scale_factor * $leg_max_S_P}]
				set leg_max_F   [expr {$scale_factor * $leg_max_F  }]
				set leg_max_T   [expr {$scale_factor * $leg_max_T  }]
				set leg_max_SGL [expr {$scale_factor * $leg_max_SGL}]
				set max_mult_bet [expr {$scale_factor * $num_lines_per_seln }]

				_log DEBUG "Finished non symmetric bets."
			}

			if {$has_max_mult_bet && [_get_config max_mult_bet]} {

				if {$sg_has_max_mult_bet} {
					set sg_max_mult_bet [expr { $max_mult_bet < $sg_max_mult_bet
					? $max_mult_bet : $sg_max_mult_bet}]
				} else {
					set sg_max_mult_bet $max_mult_bet
				}

				set sg_has_max_mult_bet 1
			}

			set max_W  [expr {$leg_max_W < $max_W
			                ? $leg_max_W : $max_W}]
			set max_P  [expr {$leg_max_P < $max_P
			                ? $leg_max_P : $max_P}]
			set max_L_W  [expr {$leg_max_L_W < $max_L_W
			                ? $leg_max_L_W : $max_L_W}]
			set max_L_P  [expr {$leg_max_L_P < $max_L_P
			                ? $leg_max_L_P : $max_L_P}]
			set max_S_W  [expr {$leg_max_S_W < $max_S_W
			                ? $leg_max_S_W : $max_S_W}]
			set max_S_P  [expr {$leg_max_S_P < $max_S_P
			                ? $leg_max_S_P : $max_S_P}]
			set max_F  [expr {$leg_max_F < $max_F
			                ? $leg_max_F : $max_F}]
			set max_T  [expr {$leg_max_T < $max_T
			                ? $leg_max_T : $max_T}]
			set max_SGL [expr {$leg_max_SGL < $max_SGL
							? $leg_max_SGL  : $max_SGL}]
			set min    [expr {$leg_min   > $min
			                ? $leg_min   : $min}]
		}

		if {[_get_config max_mult_bet] && $sg_has_max_mult_bet
			&& $bet_type != "SGL"} {

			_log DEBUG "Maximum multiple bet limit: $sg_max_mult_bet"

			foreach limit {max_W max_P max_L_W max_L_P max_S_W max_S_P} {
				set $limit $sg_max_mult_bet
			}
			set max_F [expr {$max_F < $sg_max_mult_bet
				? $max_F : $sg_max_mult_bet}]
			set max_T [expr {$max_T < $sg_max_mult_bet
				? $max_T : $sg_max_mult_bet}]
		}

	}

	if {$symmetric} {

		# MARTA TODO: legs_have_xstk
		set GROUP($group_id,simple_max_W)       $max_W
		set GROUP($group_id,simple_max_P)       $max_P
		set GROUP($group_id,simple_max_L_W)     $max_L_W
		set GROUP($group_id,simple_max_L_P)     $max_L_P
		set GROUP($group_id,simple_max_S_W)     $max_S_W
		set GROUP($group_id,simple_max_S_P)     $max_S_P
		set GROUP($group_id,simple_max_F)       $max_F
		set GROUP($group_id,simple_max_T)       $max_T
		set GROUP($group_id,simple_max_SGL)     $max_SGL
		set GROUP($group_id,simple_min)         $min

		#we didn't take into account the number of lines per selection earlier
		_log DEBUG "Symmetric bet $num_lines_per_seln"
		set scale_factor [expr {$bet_type_sf / $num_lines_per_seln}]
		set leg_lines $num_lines_per_seln

		set max_W       [expr {$scale_factor * $max_W  }]
		set max_P       [expr {$scale_factor * $max_P  }]
		set max_L_W     [expr {$scale_factor * $max_L_W}]
		set max_L_P     [expr {$scale_factor * $max_L_P}]
		set max_S_W     [expr {$scale_factor * $max_S_W}]
		set max_S_P     [expr {$scale_factor * $max_S_P}]
		set max_F       [expr {$scale_factor * $max_F  }]
		set max_T       [expr {$scale_factor * $max_T  }]
		set max_SGL     [expr {$scale_factor * $max_SGL}]
		_log DEBUG "Symmetric bet finished"
	}
	return [list $num_lines $max_W $max_P $max_L_W $max_L_P $max_S_W \
			             $max_S_P $max_F $max_T $max_SGL $min $bet_type_sf $leg_lines]
}


# Work out and store the limits for the given legs
#
# Parameters:
#   sf             - scale factor for this customer and group.
#   exch_rate      - exch rate between system and customer currencies.
#   leg_num        - leg_nums (in LEG) for which to calculate limits.
#   xstkArrayName  - name of array in callers's scope containg information
#                    about extra cum stake from other bets to take into account
#                    when  calculating max bet limits. See _check_bets.
#
# XXX This is a bit hacky; we should probably return the limits to the caller
# rather than storing them on the legs because they depend on the scale factor
# - which is group specific, but a leg can be in several groups.
#
proc ::ob_bet::_get_leg_limits {sf exch_rate leg_nums {xstkArrayName ""}} {

	variable CUST
	variable CUST_DETAILS
	variable LEG
	variable SELN
	variable TYPE

	set got_xstk [expr {$xstkArrayName != ""}]
	_log DEBUG "Got _xstk : $got_xstk"

	if {$got_xstk} {
		# Bring named array containing extra cum stake from other bets
		# into our scope.
		upvar 1 $xstkArrayName XSTK
		if { ![info exists XSTK(this_bet)] } {
			error\
			  "Format of $xstkArrayName array is invalid."\
			   ""\
			   LIMITS_INVALID_ARGS
		}
		set xstk_this_bet $XSTK(this_bet)
	}

	set sep_cum_max_stk [expr {[get_config sep_cum_max_stk] != "N"}]

	# this list simply helps us to loop over the 4 price_type,leg_type combinations
	# (and forecast/tricasts) that we need to examine for each selection and leg.
	set MAXBET_KEYS [list L,W S,W L,P S,P F T SGL]

	foreach leg $leg_nums {

		foreach c $MAXBET_KEYS {
			set leg_max($c) 999999
		}
		set leg_min 0

		#call back function here to get selection stake factor
		#ie ladbrokes have time dependant stakes
		#TODO
		set base_seln_sf 1

		set base_seln_sf [expr {$sf * $base_seln_sf}]

		_log DEV "customer scale factor: $sf"
		_log DEV "base selection stake factor : $base_seln_sf"

		set LEG($leg,has_max_mult_bet) 0

		foreach seln $LEG($leg,selns) {

			#Hack! If the seln limits are 'no stake factor dependent', then set this to 1.
			if {$SELN($seln,fixed_stake_limits) == 1} {
				set seln_sf 1
			} else {
				# Apply selection-specific stake factors
				set seln_sf [expr $base_seln_sf * $SELN($seln,sf)]
			}

			#set to defaults
			if {$SELN($seln,max_bet) == ""} {
				set SELN($seln,max_bet) 999999
			}
			if {$SELN($seln,max_sp_bet) == ""} {
				set SELN($seln,max_sp_bet) $SELN($seln,max_bet)
			}
			if {$SELN($seln,max_ep_bet) == ""} {
				set SELN($seln,max_ep_bet) $SELN($seln,max_bet)
			}
			if {$SELN($seln,max_place_lp) == ""} {
				set SELN($seln,max_place_lp) [expr $SELN($seln,max_bet) * $SELN($seln,ew_factor)]
			}
			if {$SELN($seln,max_place_sp) == ""} {
				set SELN($seln,max_place_sp) [expr $SELN($seln,max_sp_bet) * $SELN($seln,ew_factor)]
			}
			if {$SELN($seln,max_place_ep) == ""} {
				set SELN($seln,max_place_ep) [expr $SELN($seln,max_ep_bet) * $SELN($seln,ew_factor)]
			}
			if {$SELN($seln,min_bet) == ""} {
				set SELN($seln,min_bet) 0.0
			}
			if {$SELN($seln,fc_stk_limit) == ""} {
				set SELN($seln,fc_stk_limit) $SELN($seln,max_bet)
			}
			if {$SELN($seln,tc_stk_limit) == ""} {
				set SELN($seln,tc_stk_limit) $SELN($seln,max_bet)
			}

			#the selection maximum bet taking into account the
			#scale factor. if the early price is enabled (ep_active)
			#overwrite the live prices with the appropriate early prices
			if { $SELN($seln,ep_active) == "Y" } {
				set seln_max(L,W) [expr {$SELN($seln,max_ep_bet)      * $seln_sf}]
			} else {
				set seln_max(L,W) [expr {$SELN($seln,max_bet)   * $seln_sf}]
			}
			set seln_max(S,W) [expr {$SELN($seln,max_sp_bet)   * $seln_sf}]
			set seln_max(E,W) [expr {$SELN($seln,max_ep_bet)   * $seln_sf}]
			if { $SELN($seln,ep_active) == "Y" } {
				set seln_max(L,P) [expr {$SELN($seln,max_place_ep) * $seln_sf}]
			} else {
				set seln_max(L,P) [expr {$SELN($seln,max_place_lp) * $seln_sf}]
			}
			set seln_max(S,P) [expr {$SELN($seln,max_place_sp) * $seln_sf}]
			set seln_max(F)   [expr {$SELN($seln,fc_stk_limit) * $seln_sf}]
			set seln_max(T)   [expr {$SELN($seln,tc_stk_limit) * $seln_sf}]
			# the seln_max(SGL) is a bet type maximum, so shouldn't by scaled
			# by the cust's max_stake_factor
			#
			set seln_max(SGL) $TYPE(SGL,max_bet)

			set seln_min      $SELN($seln,min_bet)

			# set max_multiple_bet if any
			if {[_get_config max_mult_bet] &&
				[info exists SELN($seln,max_multiple_bet)] &&
				$SELN($seln,max_multiple_bet) != "" } {

				# Apply the max stake scale to the bet limit
				set max_mult_bet [expr {$SELN($seln,max_multiple_bet)
				 * $seln_sf}]

				# Subtract cumulative multiple stakes for customer. Will only
				# exist if customer is logged in.
				if {[info exists CUST_DETAILS(cum_mult_stakes,$seln)]} {
					set max_mult_bet [expr {$max_mult_bet
					 - $CUST_DETAILS(cum_mult_stakes,$seln)}]
				}

				# Subtract cumulative multiple stakes, calculated from the current betslip, if supplied
				if { $got_xstk } {

					set  cumm_multi_bet_stake 0.0

					if { [info exists XSTK($seln,$xstk_this_bet,multi_bet_stake,total)] } {

						set current_bet  $xstk_this_bet
						set start_bet_index 0

						# Looping through the XSTK array to see whether any other bets placed before this bet
						# to calculate the cumulative stake
						while { $start_bet_index  < $current_bet  } {

							if {[info exists XSTK($seln,$start_bet_index,multi_bet_stake,total)]} {
								set cumm_multi_bet_stake [expr {$cumm_multi_bet_stake + $XSTK($seln,$start_bet_index,multi_bet_stake,total)}]
							}

							set start_bet_index [ expr { $start_bet_index + 1 } ]
						}

						_log DEBUG  "cumm_multi_bet_stake - $cumm_multi_bet_stake, exchange rate - $exch_rate"

						# Converting User currency to System currency , since the Limits will be in System currency
						set cumm_multi_bet_stake  [ expr { $cumm_multi_bet_stake / $exch_rate } ]
						_log DEBUG  "cumm_multi_bet_stake - $cumm_multi_bet_stake"

						# Subract the calculated cumm multi bet stake with already calculated Max_Mult_bet limit.
						set max_mult_bet [ expr {$max_mult_bet - $cumm_multi_bet_stake } ]
					}
				}

				set max_mult_bet [expr {$max_mult_bet > 0 ? $max_mult_bet : 0}]

				set LEG($leg,has_max_mult_bet) 1

				if {[info exists LEG($leg,max_mult_bet)]} {
					set LEG($leg,max_mult_bet)\
					 [expr {$max_mult_bet < $LEG($leg,max_mult_bet) ?
					 $max_mult_bet : $LEG($leg,max_mult_bet)}]
				} else {
					set LEG($leg,max_mult_bet) $max_mult_bet
				}
			}

			#work out cumulative stakes if we're checking the
			#customer
			set fixed_stake_limits [expr {$SELN($seln,fixed_stake_limits) == 1 ? 1 : 0}]

			if {![_smart_reset CUST] && $CUST(num) && $CUST(check) && $CUST_DETAILS(found_cum_stakes) && !$fixed_stake_limits} {

				# Currency convert cumulative stakes.
				foreach c $MAXBET_KEYS {
					set cum_stakes($c) [expr { $CUST_DETAILS(cum_stake,$seln,$c) / $exch_rate }]
				}

			} else {
				foreach c $MAXBET_KEYS {
					set cum_stakes($c) 0.0
				}
			}

			# Treat stakes from other bets as cumulative stake if we've
			# been given them.

			if {$got_xstk} {
				foreach c $MAXBET_KEYS {

					set x_tot   0.0
					if { [info exists XSTK($seln,$c,total) ]  } {
						set x_tot   $XSTK($seln,$c,total)
					}

					set current_bet  $xstk_this_bet
				    set start_bet_index 0
					set cumm_bet_stake 0

					# Adding previous_bets to calculate the total cumulative bet stake placed so far.
					# Starting from 0th bet for the given selection , we are looping  XSTK  array till
					# we reach the current bet . XSTK array  will have the bets arranged in the following way.
					#  For ex : SGL on  Selection a , BET(0)
					#           SGL on  Selection b , BET(1)
					#           SGL on  Selection c , BET (2)
					#           DBL on  ab , bc , ca  BET(3)
					#   So for calculating cumulative bet stake on BET(3) for selection a
					#   we need to traverse from 0th bet and add the stake for the given Selection till we reach current bet.
					while { $start_bet_index <  $current_bet  } {
						if { [info exists XSTK($seln,$c,$start_bet_index) ] } {
							set cumm_bet_stake [expr {$cumm_bet_stake +   $XSTK($seln,$c,$start_bet_index) } ]
						}
						set  start_bet_index  [ expr { $start_bet_index + 1 } ]
					}

					# Converting User currency to System currency , since the Limits will be in System currency
					set x_other [ expr { $cumm_bet_stake /  $exch_rate } ]

					if { $x_other > 0.0 } {
						_log DEBUG "Treating $x_other extra $c stake from\
						            other bets as cum stk on $seln"
						set cum_stakes($c) \
						  [expr { $cum_stakes($c) + $x_other }]
					}
				}
			}

			# If we're not treating LP and SLP cumulative stake separately,
			# add them together now.

			if {!$sep_cum_max_stk} {
				set cum_stake_W [expr {$cum_stakes(L,W) + $cum_stakes(S,W)}]
				set cum_stake_P [expr {$cum_stakes(L,P) + $cum_stakes(S,P)}]
				set cum_stakes(L,W) $cum_stake_W
				set cum_stakes(S,W) $cum_stake_W
				set cum_stakes(L,P) $cum_stake_P
				set cum_stakes(S,P) $cum_stake_P
			}

			foreach c $MAXBET_KEYS {
				_log DEBUG "seln_max($c) $seln_max($c) - cum_stakes($c) $cum_stakes($c)"
			}

			# take off cumulative stakes
			foreach c $MAXBET_KEYS {
				set seln_max($c) [expr {$seln_max($c) - $cum_stakes($c)}]
			}

			# For logged shop punters, offset the max bet values by the amount they may have
			# already staked from other shops
			if {[_get_config log_punter_total_bets] == "Y" && ![_smart_reset CUST] && $CUST(num) && $CUST_DETAILS(owner_type) == "LOG"} {
				set rs [ob_db::exec_qry ob_bet::get_shop_cust_stakes $CUST(cust_id) $seln]

				if {[db_get_nrows $rs] == 1} {
					set stake_total [db_get_col $rs 0 stake_total]
					if {$stake_total != ""} {
						# take off shop stakes
						foreach c $MAXBET_KEYS {
							set seln_max($c) [expr {$seln_max($c) - $stake_total}]
							if {$seln_max($c) < 0} {set seln_max($c) 0}
						}
					}
				}

				ob_db::rs_close $rs
			}


			#we want minimum max and maximum min
			foreach c $MAXBET_KEYS {
				set leg_max($c) [expr {$seln_max($c) < $leg_max($c)
				                     ? $seln_max($c) : $leg_max($c)}]
			}

			set leg_min [expr {$seln_min > $leg_min
			                 ? $seln_min : $leg_min}]
		}

		# if cannot have a place line on this leg, set the place line max to
		# half of the win line max (because any each-way bet on the leg will
		# actually be 2 win lines, constrain the max using max_bet_P)
		# - this should only have a bearing on mixed each-way multiples
		if {$LEG($leg,ew_avail) == "N" && $LEG($leg,pl_avail) == "N"} {
			set leg_max(L,P) [expr {$leg_max(L,W) / 2}]
			set leg_max(S,P) [expr {$leg_max(S,W) / 2}]
		}

		if {$LEG($leg,price_type) == "S"} {
			set price_type "S"
		} else {
			#considering all other exotic prices and dividends
			#as LP for bet limit purposes
			set price_type "L"
		}

		# If  the leg sort for this leg is  Single Forecast , Reverse Forcast or    Combination forcast then
		# we need to set the forcast limit , if it is lower than the  calculated max_bet limit

		set REPLACE_FORECAST_TRICAST_KEYS [list L,W S,W L,P S,P]
		if { [lsearch [list SF RF CF ] $LEG($leg,leg_sort) ] > -1 } {

			foreach key $REPLACE_FORECAST_TRICAST_KEYS {
				if { $leg_max($key) > $leg_max(F) } {
					  set leg_max($key)  $leg_max(F)
				}
			}
		}

		# If  the leg sort for this leg is  TriCast and    Combinational  Tricast  then
		# we need to set the Tricast  limit , if it is lower than the  calculated max_bet limit
		if { [lsearch [list TC CT ] $LEG($leg,leg_sort) ] > -1 } {

			foreach key $REPLACE_FORECAST_TRICAST_KEYS {
				if { $leg_max($key) > $leg_max(T) } {
					  set leg_max($key)  $leg_max(T)
				}
			}
		}

		# store the leg limits that ob_bet will use. These will
		# be based on the price type currently set for the
		# selections
		if {$price_type == "L"} {
			set LEG($leg,max_bet_W) $leg_max(L,W)
			set LEG($leg,max_bet_P) $leg_max(L,P)

		} else {
			set LEG($leg,max_bet_W) $leg_max(S,W)
			set LEG($leg,max_bet_P) $leg_max(S,P)
		}

		# customers are able to select price_type dynamically
		# on the betslip, so we need to store max bet for all
		# price/leg types.
		set LEG($leg,max_bet_L_W) $leg_max(L,W)
		set LEG($leg,max_bet_L_P) $leg_max(L,P)
		set LEG($leg,max_bet_S_W) $leg_max(S,W)
		set LEG($leg,max_bet_S_P) $leg_max(S,P)

		set LEG($leg,max_bet_F) $leg_max(F)
		set LEG($leg,max_bet_T) $leg_max(T)

		set LEG($leg,max_bet_SGL) $leg_max(SGL)

		set LEG($leg,min_bet)     $leg_min

		# store all the maxes in case the app wants them
		set max_bets [list]
		foreach c $MAXBET_KEYS {
			lappend max_bets $c \
			  [format "%0.2f" [expr {$leg_max($c) * $exch_rate}]]
		}
		set LEG($leg,max_bets) $max_bets

	}

}



#prepare customer queries
proc ob_bet::_prepare_limit_qrys {} {

	if {[_get_config log_punter_total_bets] == "Y"} {
		ob_db::store_qry ob_bet::get_shop_cust_stakes {
			select
				sum(b.stake) as stake_total
			from
				tExtCust e1,
				tExtCust e2,
				tAcct a,
				tBet b,
				tOBet ob,
				tEvOc oc
			where
					e1.ext_cust_id = e2.ext_cust_id
				and e2.cust_id     = a.cust_id
				and oc.ev_oc_id    = ob.ev_oc_id
				and ob.bet_id      = b.bet_id
				and b.acct_id      = a.acct_id
				and e1.cust_id     != e2.cust_id
				and e1.cust_id     = ?
				and oc.ev_oc_id    = ?
		}
	}

}

::ob_bet::_log INFO "sourced limits.tcl"
