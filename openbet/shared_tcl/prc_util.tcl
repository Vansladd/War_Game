# $Id: prc_util.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# Useful functions for manipulating prices
#
# ==============================================================

array set SPECIAL_PRICE [list 13/8 2.62 15/8 2.87 11/8 2.37 8/13 1.61 2/7 1.28 1/8 1.12]

set DEFAULT_PRICE_TYPE ODDS
set DEFAULT_PRICE_DPS 2
set DEFAULT_PRICE_ROUNDING NEAREST

proc init_prc_util {} {

	global DEFAULT_PRICE_TYPE DEFAULT_PRICE_DPS DEFAULT_PRICE_ROUNDING

	# DEFAULT_PRICE_TYPE should be one of DECIMAL or ODDS (default)
	# DEFAULT_PRICE_DPS sets the number of decimal places used in calculating decimal odds, from 0 to 3 (default 2)
	# DEFAULT_PRICE_ROUNDING should be one of UP, DOWN, NEAREST (default) or HALFEVEN

	prepare_prc_util_queries

	set DEFAULT_PRICE_TYPE [string toupper [OT_CfgGet DEFAULT_PRICE_TYPE ODDS]]

	set DEFAULT_PRICE_DPS [OT_CfgGet DEFAULT_PRICE_DPS 2]
	if {![string is integer -strict $DEFAULT_PRICE_DPS]} { set DEFAULT_PRICE_DPS 2 }
	if {$DEFAULT_PRICE_DPS < 0} { set DEFAULT_PRICE_DPS 0 }
	if {$DEFAULT_PRICE_DPS > 3} { set DEFAULT_PRICE_DPS 3 }

	set DEFAULT_PRICE_ROUNDING [string toupper [OT_CfgGet DEFAULT_PRICE_ROUNDING NEAREST]]
}

proc prepare_prc_util_queries {} {

	db_store_qry prc_util_get_fractional_price {
		select
			p_num, p_den
		from
			tpriceconv
		where
			p_dec3dp = (
				select max(p_dec3dp) from tpriceconv where p_dec3dp <= ?
			)
	}
}

proc mk_price {num den {price_type ""}} {

	global LOGIN_DETAILS DEFAULT_PRICE_TYPE

	if {!([string length $num] && [string length $den])} {
		return "-"
	}

	if {![string length $price_type]} {
		# Default price type to that specified in the config file..
		set price_type $DEFAULT_PRICE_TYPE
		# ..override it if there's a value in the login details..
		if {[info exists LOGIN_DETAILS(PRICE_TYPE)]} {
			set price_type $LOGIN_DETAILS(PRICE_TYPE)
		}
		# ..but ultimately allow customer preferences to take precedence
		if {![catch {
			set price_type_pref [OB_prefs::get_pref PRICE_TYPE]
		}] && [string length $price_type_pref]} {
			set price_type $price_type_pref
		}
	}

	switch -- $price_type {
		DECIMAL {
			return [format_dec_price [frac_price_to_dec $num $den]]
		}
		ODDS -
		default {
			if {$num == $den} {
				return "evens"
			} elseif {$den == 1000} {
				# we use a denominator of 1000 to store decimal odds, so return this as a decimal
				return [format_dec_price [frac_price_to_dec $num $den]]
			} else {
				return "[expr {int($num)}]/[expr {int($den)}]"
			}
		}
	}
}

proc mk_price_dec {dec {invert 0}} {

	global LOGIN_DETAILS DEFAULT_PRICE_TYPE

	# Default price type to that specified in the config file..
	set price_type $DEFAULT_PRICE_TYPE
	# ..override it if there's a value in the login details..
	if {[info exists LOGIN_DETAILS(PRICE_TYPE)]} {
		set price_type $LOGIN_DETAILS(PRICE_TYPE)
	}
	# ..but ultimately allow customer preferences to take precedence
	if {![catch {
		set price_type_pref [OB_prefs::get_pref PRICE_TYPE]
	}] && [string length $price_type_pref]} {
		set price_type $price_type_pref
	}

	switch -- $price_type {
		DECIMAL {
			if {$dec > 1.0} {
				if {$invert} {
					set dec [expr {(1.0 / (double($dec) - 1.0)) + 1.0}]
				}
				return [format_dec_price $dec]
			} else {
				ob::log::write DEV {Invalid decimal price '$dec'}
				return
			}
		}
		ODDS -
		default {
			set frac [dec_price_to_frac $dec]
			if {[llength $frac] == 2} {
				if {$invert} {
					set frac [list [lindex $frac 1] [lindex $frac 0]]
				}
				return [join $frac "/"]
			} else {
				return
			}
		}
	}
}

proc frac_price_to_dec {num den} {

	global SPECIAL_PRICE

	if {[info exists SPECIAL_PRICE($num/$den)]} {
		return $SPECIAL_PRICE($num/$den)
	} else {
		return [expr {(double($num) / double($den)) + 1.0}]
	}
}

proc dec_price_to_frac {dec} {

	if {[catch {
		set rs [db_exec_qry prc_util_get_fractional_price $dec]
	} msg]} {
		ob::log::write ERROR {Unable to obtain fractional odds: $msg}
		set frac [list]
	} elseif {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {Incorrect number of rows returned: obtaining fractional odds: $msg}
		set frac [list]
		db_close $rs
	} else {
		set frac [list [db_get_col $rs 0 p_num] [db_get_col $rs 0 p_den]]
		db_close $rs
	}

	return $frac
}

proc format_dec_price {dec {dps ""} {rounding ""}} {

	global DEFAULT_PRICE_DPS DEFAULT_PRICE_ROUNDING

	if {[string length $dps]} {
		if {![string is integer -strict $dps]} {
			set dps 2
		}
	} else {
		if {[string length DEFAULT_PRICE_DPS]} {
			set dps $DEFAULT_PRICE_DPS
		} else {
			set dps 2
		}
	}

	if {[string length $rounding]} {
		set rounding [string toupper $rounding]
	} else {
		if {[string length DEFAULT_PRICE_ROUNDING]} {
			set rounding $DEFAULT_PRICE_ROUNDING
		} else {
			set rounding NEAREST
		}
	}

	set scale 1.0
	for {set i 0} {$i < $dps} {incr i} {
		set scale [expr {$scale * 10.0}]
	}

	switch -- $rounding {
		UP {
			set dec [expr {int(ceil(double($dec) * $scale))}]
		}
		DOWN {
			set tmp [expr {double($dec) * $scale}]
			set l   [expr {[string first "." $tmp]-1}]
			set dec [string range $tmp 0 $l]
		}
		HALFEVEN {
			set dec [expr {int(round(double($dec) * $scale))}]
			if {$dec % 2 != 0} {
				set dec [expr {$dec + ($dec < 0 ? 1 : -1)}]
			}
		}
		NEAREST -
		default {
			set dec [expr {int(round(double($dec) * $scale))}]
		}
	}

	set formatted ""
	for {set i 0} {$i < $dps} {incr i} {
 		if {[string length $dec] > $i} {
			set formatted "[string index $dec end-$i]$formatted"
		} else {
			set formatted "0$formatted"
		}
	}
	if {[string length $dec] > $dps} {
		set formatted "[string range $dec 0 end-$dps].$formatted"
	} else {
		set formatted "0.$formatted"
	}

	return $formatted
}

# legacy function - left for compatibility purposes
#
proc display_best_price {decimal_price} {

	set price [mk_price_dec $decimal_price]

	if {[regexp {^(\d+)/(\d+)$} $price all num den]} {
		return [list $num $den]
	} else {
		return $price
	}
}

##########################################################
# Description : Make a price string given odds
#			   numerator and denominator
# Input:	is_lp:	  Is it live price
#		   is_sp:	  Is it Starting Price
#		   lpn:		Live Price Numerator
#		   lpd:		Live Price Demoninator
#		   spn:		Starting Price Numerator
#		   spd:		Starting Price Demoninator
#		   prc_typ:	Odds / Decimal
#########################################################
proc mk_price_str {is_lp is_sp lpn lpd {spn ""} {spd ""} {prc_typ ""}} {

	if {$is_lp == "Y" && $lpn != "" && $lpd != ""} {
		return [mk_price $lpn $lpd $prc_typ]
	}
	if {$is_sp == "Y"} {
		if {$spn != "" && $spd != ""} {
			return [mk_price $spn $spd $prc_typ]
		}
		return SP
	}
	return ""
}

proc mk_bet_price_str {type lpn lpd {spn ""} {spd ""} {prc_typ ""}} {
	if {$type == "L"} {
		return [mk_price $lpn $lpd $prc_typ]
	} elseif {$type == "D"} {
		return "Dividend"
	} else {
		return SP
	}
}

###########################################################
# Procedure :   mk_rcpt_prc_str
# Description : This function calculates how the price type
#			   should be displayed for the bet history /rcpt
# Input :	   type:	price type  L = Live Price
#									S = Starting Price
#									D = Dividend
#									B = Best Price   (exotic)
#									N = Next Price   (exotic)
#									1 = First Price  (exotic)
#									2 = Second Price (exotic)
#			   pn:	  price numerator
#			   pd:	  price denominator
#			   prc_type Odds / Decimal
# Output :	  football result depending on market sort
# Author :	  modified by JDM, 06-09-2001
##########################################################
proc mk_rcpt_prc_str {type pn pd {prc_typ ""}} {

	# If no numerator and denominator then return the type
	# This will then be appended to a message code
	if {$pn=="" && $pd==""} {
		if {$type =="L"} {return ""}
		return "[ml_printf DD_PRICETYPE_$type]"
	}
	# numerator and denominator exist therefore display price
	switch -- $type {
		"L"	 {   # Live Price
					return [mk_price_str Y N $pn $pd "" "" $prc_typ]
				}
		"S"	 {   # Starting Price
					return [mk_price_str N Y "" "" $pn $pd $prc_typ]
				}
		"D"	 {   # Dividend
					return [mk_price_str N Y "" "" $pn $pd $prc_typ]
				}
		default {   # Exotic Prices
					return [mk_price_str Y N $pn $pd "" "" $prc_typ]
				}
	}
}

#
# Make a each-way terms string
#
proc mk_ew_terms {ew_avail pl_avail pl ewn ewd} {

  global LANG

  set TT(EACHWAY,en)	"Each-way"
  set TT(EACHWAY,cn)	"&#23382;&#27880;"
  set TT(EACHWAY,es)	"Ganar y puesto"
  set TT(EACHWAY,it)	"Vincente o piazzato"

  set TT(AND,en)	" and "
  set TT(AND,cn)	" &#33267; "
  set TT(AND,es)	" y "
  set TT(AND,it)	" e "

  set TT(PLACE,en)	"Place"
  set TT(PLACE,cn)	"&#20301;&#32622;"
  set TT(PLACE,es)	"Efectuada"
  set TT(PLACE,it)	"Piazzato"

  set TT(ODDS,en)   "odds"
  set TT(ODDS,cn)   "&#21069;&#36064;&#29575;"
  set TT(ODDS,es)   "precios"
  set TT(ODDS,it)   "quote"

  set TT(BETS,en) " bets "
  set TT(BETS,cn) " &#25237;&#27880 "
  set TT(BETS,es) " apuestas "
  set TT(BETS,it) " scommesse "

  set TT(FIRST_A,en) "first"
  set TT(FIRST_A,cn) "&#21069"
  set TT(FIRST_A,es) "primeros"
  set TT(FIRST_A,it) "primi"

  set TT(FIRST_B,en) ""
  set TT(FIRST_B,cn) "&#21517"
  set TT(FIRST_B,es) ""
  set TT(FIRST_B,it) ""

  set term_str ""
  # en: each way bets %s odds first %s
  # cn: &#23382;&#27880; &#25237;&#27880 %s &#21069;&#36064;&#29575; &#21069 %s &#21517
  # es: Ganar y puesto apuestas %s precios primeros %s

  # ew and pl
  # cn: &#23382;&#27880; &#33267; &#20301;&#32622; &#25237;&#27880 %s &#21069;&#36064;&#29575; &#21069 %s &#21517
  # it: Vincente o piazzato e Piazzato scommesse %s quote primi %s
  # es: Ganar y puesto y Efectuada %s precios primeros %s


  if {$ew_avail == "Y"} {
	append term_str $TT(EACHWAY,$LANG)
  }

  if {$ew_avail == "Y" && $pl_avail == "Y"} {
	append term_str $TT(AND,$LANG)
  }

  if {$pl_avail == "Y"} {
	append term_str $TT(PLACE,$LANG)
  }

  if {[string length $term_str] != 0} {
	append term_str "$TT(BETS,$LANG) $ewn/$ewd $TT(ODDS,$LANG), $TT(FIRST_A,$LANG) $pl $TT(FIRST_B,$LANG)"
  }

  return $term_str

}

proc ml_mk_ew_terms {ew_avail pl_avail pl ewn ewd} {

	if {$pl != "1" || $ewn != "1" || $ewd != "1"} {

		if {$ew_avail == "Y" && $pl_avail == "Y"} {
			return [ml_printf BET_EW_TERMS_EW_AND_PL "$ewn/$ewd" $pl]

		} elseif {$ew_avail == "Y"} {
			return [ml_printf BET_EW_TERMS_EW "$ewn/$ewd" $pl]

		} elseif {$pl_avail == "Y"} {
			return [ml_printf BET_EW_TERMS_PL "$ewn/$ewd" $pl]
		}
	}
	return ""
}


#
# Spread bet formatting
#

proc mk_makeup {makeup} {

	if {$makeup==""} {
	return ""
	}

	## Print integers as integers
	set as_int [expr {int($makeup)}]
	if {$as_int==$makeup} {
	return $as_int
	}

	## Trim all the bloody trailng zeroes off the end
	return [expr {double($makeup)}]
}


#
# Familiar odds - given a decimal price return the largest
# price in tPriceConv less than or equal to the decimal price.
#
# N.B. decimal prices as parameters and returned values
# include the unit stake ('evens' is 2.00)
#
# If the price given is worse than the worst bookmakers price
# then the worst bookmaker's price will be returned
#
# Syntax:   familiar_price  price
# Returns:  {num den}

proc familiar_odds {price} {

	global FAMILIAR_ODDS

	# Do we have a TCL list of familiar odds in memory already?
	# If so, it will be sorted in ascending order
	if [info exists FAMILIAR_ODDS] {

		set price [expr "double($price)"]

		# Do linear search. The running time of this
		# could be improved from O(n) to O(log(n))
		# by implementing a binary search here.
		set best_dec [lindex $FAMILIAR_ODDS 0]
		set best_frac [lindex $FAMILIAR_ODDS 1]
		foreach {dec frac} $FAMILIAR_ODDS {
			if { $dec <= $price } {
				set best_dec $dec
				set best_frac $frac
			} else {
				return $best_frac
			}
		}
		return $best_frac
	}

	build_familiar_odds_list

	# And better luck next time.
	return [familiar_odds $price]

}

proc build_familiar_odds_list {} {

	global FAMILIAR_ODDS

	if {[info exists FAMILIAR_ODDS]} {
		return
	}

	db_store_qry familiar_odds_qry {
		select p_dec, p_num, p_den
		from tPriceConv
		order by p_dec asc
	}

	set rs [db_exec_qry familiar_odds_qry]
	set nrows [db_get_nrows $rs]

	for {set r 0} {$r<$nrows} {incr r} {
		lappend FAMILIAR_ODDS [db_get_col $rs $r p_dec]
		lappend FAMILIAR_ODDS [list\
				[db_get_col $rs $r p_num]\
				[db_get_col $rs $r p_den]]
	}

	db_close $rs

	if {[llength $FAMILIAR_ODDS]==0} {
		error "tPriceConv table is empty"
	}
}


# =================================================================
# Proc        : get_greatest_common_divisor
# Description : returns gcd for two numbers. Euclid's algorithm - copied from
#               pGCD.sql
# Author      : sluke
# =================================================================
proc get_greatest_common_divisor {num den} {
	if {$den > $num} {
		set r $den
		set den $num
		set num $r
	}

	while {1} {
		set r [expr {$num%$den}]
		if {$r==0} {return $den}

		set num $den
		set den $r
	}
}
