# $Id: price.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Price utilities
#
# Configuration:
#    PRICE_TYPE_DEFAULT         price type default      (ODDS)
#    PRICE_DPS_DEFAULT          decimal places default  (2)
#    PRICE_ROUNDING_DEFAULT     rounding default        (NEAREST)
#
# Synopsis:
#    package require util_price ?4.5?
#
# Procedures:
#    ob_price::init         one time initialisation
#    ob_price::mk           make a formatted price string (fractional arg)
#    ob_price::mk_dec       make a formatted price string (decimal arg)
#    ob_price::mk_str       make a formatted price string (live & starting arg)
#    ob_price::mk_bet_str   make a formatted price string (bet arg)
#    ob_price::format_dec   format a decimal number
#    ob_price::frac_to_dec  fraction to decimal conversion
#    ob_price::dec_to_frac  decimal to fraction conversion
#    ob_price::mk_hcap_str  make a formatted handicap string
#

package provide util_price 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_price {

	variable CFG
	variable INIT
	variable SPECIAL

	# special prices
	array set SPECIAL [list \
		13/8 2.62\
		15/8 2.87\
		11/8 2.37\
		8/13 1.61\
		2/7  1.28\
		1/8  1.12]

	# package initialisation
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
proc ob_price::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {PRICE: init}

	# get configuration
	array set OPT [list \
	        type_default     ODDS\
	        dps_default      2\
	        rounding_default NEAREST]

	foreach c [array names OPT] {
		set value [OT_CfgGet "PRICE_[string toupper $c]" $OPT($c)]

		# check price rounding (value between 0 and 3)
		if {$c == "dps_default"} {
			set CFG($c) [_check_dps $value]
		} else {
			set CFG($c) [string toupper $value]
		}
	}

	# prepare queries
	_prepare_qrys

	set INIT 1
}



# Private procedure to prepare the package queries.
#
proc ob_price::_prepare_qrys args {

	ob_db::store_qry ob_price::get_frac_price {
		select
		    p_num,
		    p_den
		from
		    tPriceConv
		where
		    p_dec3dp = (
				select max(p_dec3dp) from tPriceConv where p_dec3dp <= ?
			)
	}
}


# Private procedure to check the decimal places (dps).
# The supplied dps must be an integer between 0..3 inclusive. If the value
# is not an integer, return 2, if less than 0, then return 0, if larger
# than 3, return 3, else return the supplied value
#
#   dps     - dps value to check
#   returns - valid dps value.
#
proc ob_price::_check_dps { dps } {

	if {![string is integer -strict $dps]} {
		ob_log::write WARNING {PRICE: dps not an integer, setting to 2}
		return 2
	} elseif {$dps < 0} {
		ob_log::write WARNING {PRICE: dps less than zero, setting to 0}
		return 0
	} elseif {$dps > 3} {
		ob_log::write WARNING {PRICE: dps larger than 3, setting to 3}
		return 3
	}

	return $dps
}



#--------------------------------------------------------------------------
# Price Formatting
#--------------------------------------------------------------------------

# Make a formatted price string (as used on an end-device) when supplied a
# numerator and denominator (fractional).
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The method does not get the price_type from the customer's login details or
# preferences. It's the responsibility of the caller to supply the price type.
#
#    num        - numerator
#    den        - denominator
#    price_type - price format type (DECIMAL|ODDS)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#    legacy     - flag to enable legacy handling of price conversions, default 0
#    dps        - the number of decimal places to display, default "".
#    mkt_sort   - the market sort, default "".
#    returns    - formatted price
#
proc ob_price::mk { num den {price_type ""} {legacy 0} {dps ""} {mkt_sort ""} {rounding ""}} {

	variable CFG

	# num & den not supplied
	if {$num == "" && $den == ""} {
		return "-"
	}

	# use the default price type if not supplied and
	# force to DECIMAL on Asian Handicaps if required
	if {$price_type == ""} {
		if {($mkt_sort == "AH" && [OT_CfgGet FUNC_FORCE_DEC_ON_AH 0])} {
			set price_type "DECIMAL"
		} else {
			set price_type $CFG(type_default)
		}
	} else {
		set price_type [string toupper $price_type]
	}
	
	# format the price, dependent on price_type
	if {$price_type == "DECIMAL"} {
		return [format_dec [frac_to_dec $num $den] $dps $rounding]
	} elseif {$price_type == "AMERICAN"} {
		set prc [format_dec [frac_to_american $num $den] 0 $rounding]
		if {$prc >= 0} {
			return "+$prc"
		} else {
			return $prc
		}
	} elseif {$price_type == "ITALIAN"} {
		return [format_dec [frac_to_italiano $num $den] 0 $rounding]
	} elseif {$num == $den} {
		return "evens"
	} elseif {$den == 1000 && $legacy} {
		# denominator of 1000 denotes a decimal price!
		return [format_dec [frac_to_dec $num $den] "" $rounding]
	} elseif {$den == 1000} {
		return "[lindex [dec2frac [expr [frac_to_dec $num $den] - 1.0]] 0]/[lindex [dec2frac [expr [frac_to_dec $num $den] - 1.0]] 1]"
	}

	return "[expr {int($num)}]/[expr {int($den)}]"
}



# dec2frac -- takes a decimal and returns it as a fraction
# be warned, it's pretty accurate, so give it at least 6dp
# if you've got a repeating decimal
# i.e. 0.1428 yields 357/2500 (spot on), and 0.142857 is 1/7
proc dec2frac { decimal } {

	# bookmaker odds: not all fractions are in lowest terms
	# for bookmaker odds (e.g. 3/2 -> 6/4) so we keep a list
	# here to upgrade to if needed.
	# tPriceConv and shared_tcl/prc_util.tcl are the places to
	# check if you need more than this
	array set BM_PRICES [list "3/2" "6/4" "17/8" "85/40" "47/20" "95/40" \
							 "10/3" "100/30" "25/2" "100/8" "50/3" "100/6" \
							 "8/19" "40/95" "8/17" "40/85"]
	# safety check
	if { [expr {abs($decimal - int($decimal))}] <= 0.000001 } {
		return [list [expr int($decimal)] 1]
	}

	# initialise
	set z(1) $decimal
	set d(0) 0
	set d(1) 1
	set n(1) 1
	set i 1
	set epsilon 0.000001

	# iterate
	while {[expr {abs(double($n($i)/$d($i)) - $decimal)}] > $epsilon} {
		set j $i
		incr i

		set z($i) [expr { double(1.0)/( $z($j) - int($z($j))) }]
		set d($i) [expr { double($d($j) * int($z($i))) + $d([expr {$j-1}])}]
		set n($i) [expr { round($decimal * $d($i)) }]
	}

	# inform
	set num [expr int($n($i))]
	set den [expr int($d($i))]
	if {[info exists BM_PRICES("$num/$den")]} {
		set frac [split $BM_PRICES($num/$den) "/"]
		set num [lindex $frac 0]
		set den [lindex $frac 1]
	}
	return [list $num $den]
}



# Make a formatted price string (as used on an end-device) when supplied a
# decimal.
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The method does not get the price_type from the customer's login details or
# preferences. It's the responsibility of the caller to supply the price type.
#
#   dec         - decimal to format
#   price_type  - price format type (DECIMAL|ODDS|AMERICAN)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#   invert      - invert the price
#   mkt_sort    - the market sort, default "".
#   returns     - formatted price, or empty string on error
#
proc ob_price::mk_dec { dec {price_type ""} {invert 0} {mkt_sort ""}} {

	variable CFG

	# use DECIMAL if Asian Handicap and cfg set
	# use the default price type if not supplied
	if {$price_type == ""} {
		if {($mkt_sort == "AH" && [OT_CfgGet FUNC_FORCE_DEC_ON_AH 0])} {
			set price_type "DECIMAL"
		} else {
			set price_type $CFG(type_default)
		}
	} else {
		set price_type [string toupper $price_type]
	}

	# format the price dependent on price type
	if {$price_type == "DECIMAL"} {
		if {$dec > 1.0} {
			if {$invert} {
				set dec [expr {(1.0 / (double($dec) - 1.0)) + 1.0}]
			}
			return [format_dec $dec]
		}
	} elseif {$price_type == "ODDS"} {
		set frac [dec_to_frac $dec]
		if {[llength $frac] == 2} {
			if {$invert} {
				set frac [list [lindex $frac 1] [lindex $frac 0]]
			}
			if {[lindex $frac 0] == [lindex $frac 1]} {
				return "evens"
			}
			return [join $frac "/"]
		}
	} elseif {$price_type == "AMERICAN"} {
		set frac [dec_to_frac $dec]
		if {[llength $frac] == 2} {
			if {$invert} {
				set frac [list [lindex $frac 1] [lindex $frac 0]]
			}
			set num [lindex $frac 0]
			set den [lindex $frac 1]
			set prc [format_dec [frac_to_american $num $den] 0]
			if {$prc >= 0} {
				return "+$prc"
			} else {
				return $prc
			}
		}
	}

	ob_log::write ERROR {PRICE: invalid decimal price - $dec}
	return ""
}



# Make a formatted price string (as used on an end-device) when supplied either
# live price or starting price
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The method does not get the price_type from the customer's login details or
# preferences. It's the responsibility of the caller to supply the price type.
#
#   is_lp       - is a live price?
#   is_sp       - is a starting price?
#   lpn         - live price numerator
#   lpd         - live price denominator
#   spn         - starting price numerator, default ""
#   spd         - starting price denominator, default ""
#   price_type  - price type (DECIMAL|ODDS)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#   legacy      - flag to enable legacy handling of price conversions, default 0
#   dps         - number of dcimal places to display (if decimal)
#                 default "", in which case use the cfg value PRICE_DPS_DEFAULT
#   mkt_sort    - the market sort, default "".
#   returns     - formatted price, or "" if starting & live price is not
#                 supplied
#
proc ob_price::mk_str { is_lp is_sp lpn lpd \
	                    {spn ""} {spd ""} {price_type ""} \
						{legacy 0} {dps ""} {mkt_sort ""}} {

	# live price
	if {$is_lp == "Y" && $lpn != "" && $lpd != ""} {
		return [mk $lpn $lpd $price_type $legacy $dps $mkt_sort]

	# starting price
	} elseif {$is_sp == "Y"} {
		if {$spn != "" && $spd != ""} {
			return [mk $spn $spd $price_type $legacy $dps $mkt_sort]
		}
		return SP
	}
	return ""
}



# Make a formatted price string (as used on an end-device) when supplied live
# price and a bet price type.
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The method does not get the price_type from the customer's login details or
# preferences. It's the responsibility of the caller to supply the price type.
#
#   type        - bet price type (L|D|S)
#                 live, dividend or starting
#   lpn         - live price numerator
#   lpd         - live price denominator
#   price_type  - formatted price type (DECIMAL|ODDS)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#   returns     - formatted price, or "" if starting & live price is not
#                 supplied
#
proc ob_price::mk_bet_str { bet_price_type lpn lpd {price_type ""} {mkt_sort ""} {rounding ""}} {

	set str ""

	switch -- $bet_price_type {
		"L" -
		"G" {
			set str [mk $lpn $lpd $price_type 0 "" $mkt_sort $rounding]
		}
		"D" {
			set str "Dividend"
		}
		default {
			set str "SP"
		}
	}

	return $str
}


# Format a decimal number.
# Sets the number of decimal places (dps) and what sort of rounding
#
#   dec       - decimal to format
#   dps       - decimal places (0..3)
#               if not supplied, then use default dps
#   rounding  - type of rounding (UP|DOWN|HALFEVEN|NEAREST)
#               if not supplied, then use default rounding
#   returns   - formatted decimal number
#
proc ob_price::format_dec { dec {dps ""} {rounding ""}} {

	variable CFG
	if {![string is double -strict $dec]} {
		ob_log::write ERROR {Argument (dec: $dec) not a numeric value}
		return $dec
	}

	# check dps
	if {$dps != ""} {
		set dps [_check_dps $dps]
	} else {
		set dps $CFG(dps_default)
	}

	# check rounding
	if {$rounding != ""} {
		set rounding [string toupper $rounding]
	} else {
		set rounding $CFG(rounding_default)
	}

	# set the scale, dependent on dps
	set scale 1.0
	for {set i 0} {$i < $dps} {incr i} {
		set scale [expr {$scale * 10.0}]
	}

	# round up, down, halfeven or nearest
	switch -- $rounding {
		UP {
			set dec [expr {int(ceil(double($dec) * $scale))}]
		}
		DOWN {
			set dec [format "%.0f" [expr {double($dec) * $scale}]]
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

	# add decimal place
	if {$dps > 0} {
		if {[string length $dec] > $dps} {
			set d [expr {$dps - 1}]
			set fdec\
			    "[string range $dec 0 end-$dps].[string range $dec end-$d end]"
		} else {
			set fdec "0."
			for {set d 0} {$d < [expr {$dps - [string length $dec]}]} {incr d} {
				append fdec "0"
			}
			append fdec $dec
		}
	} else {
		set fdec $dec
	}
	 
	set fdec [ob_util::dec_to_foreign_dec $fdec]
	 
	return $fdec
}



# Get the comparison price
#
# price_type   - The price type (L(ive)/G(uarunteed) etc..)
# lp_num       - Live price numerator
# lp_den       - Live price denominator
# sp_num_guide - Starting price numerator
# sp_den_guide - Starting price denominator
#
# returns      - the comparison price
#
proc ob_price::get_comparison_price {price_type lp_num lp_den
                                     sp_num_guide sp_den_guide} {
	# If no price has been set, use placeholder price of 5/2
	set dflt_price 3.5

	if {$lp_num == "" || $lp_den == ""} {
		set live_price $dflt_price
	} else {
		set live_price [expr {$lp_num * 1.0 / $lp_den + 1.0}]
	}

	if {$sp_num_guide == "" || $sp_den_guide == ""} {
		set guide_price $dflt_price
	} else {
		set guide_price [expr {$sp_num_guide * 1.0 / $sp_den_guide + 1.0}]
	}

	if {$price_type == "L"} {
		set price $live_price
	} elseif {$price_type == "G"} {
		if {$live_price > $guide_price} {
			set price $live_price
		} else {
			set price $guide_price
		}
	} else {
		set price $guide_price
	}

	return $price
}


# Make a handicap description for an A/H/U/L market, given the market type,
# the tag of the selection bet on, and the handicap value
#
# mkt_type  - The market sort
# fb_result - Home/Draw/Away
# hcap      - Handicap Value
#
# returns - 'hcap', the translated handicap string
#
proc ob_price::mk_hcap_str {mkt_type fb_result hcap} {

	if {$mkt_type == "A" || $mkt_type == "H" || $mkt_type == "M"} {
		if {$fb_result == "A"} {
			set hcap [expr {0.0-$hcap}]
		}
	}
	switch -- $mkt_type {
		A {
			if {$hcap > 0} {
				return "+[_ah_string $hcap]"
			} else {
				return [_ah_string $hcap]
			}
		}
		l {
			return [ah_string $hcap]
		}
		H -
		M -
		P {
			if {$hcap > 0} {
				return "+$hcap"
			} else {
				return $hcap
			}
		}
		L -
		U {
			return $hcap
		}
	}

}



# Produce AH string - value should be what comes from the database
#
proc ob_price::_ah_string {v} {

	set v [expr {int(($v>0)?($v+0.25):($v-0.25))}]

	if {$v % 2 == 0} {
		return [format %0.1f [expr {($v%4==0)?$v/4:$v/4.0}]]
	}
	incr v -1
	set h1 [expr {($v%4==0)?$v/4:$v/4.0}]
	incr v 2
	set h2 [expr {($v%4==0)?$v/4:$v/4.0}]

	return "[format %0.1f $h1]/[format %0.1f $h2]"

}

#--------------------------------------------------------------------------
# Price Conversions
#--------------------------------------------------------------------------

# Fractional to decimal price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - decimal price (not rounded or set to 'n' dps)
#
proc ob_price::frac_to_dec { num den } {

	variable SPECIAL

	if {[info exists SPECIAL($num/$den)]} {
		return $SPECIAL($num/$den)
	}

	return [expr {(double($num) / double($den)) + 1.0}]
}



# Fractional to american price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - american price (not rounded or set to 'n' dps)
#
proc ob_price::frac_to_american { num den } {

	if {$num >= $den} {
		return [expr {(double($num) / double($den)) * 100}]
	} elseif {$den > $num} {
		return [expr {(double($den) / double($num)) * -100}]
	}
}



# Fractional to italiano price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - italiano price (not rounded or set to 'n' dps)
#
proc ob_price::frac_to_italiano { num den } {

		return [expr {(double($num) / double($den)) * 100}]
}


# Decimal to fraction price conversion.
#
#   dec     - decimal to convert
#   returns - list of numerator and denominator, or an empty list on error
#
proc ob_price::dec_to_frac { dec } {

	if {[catch {set rs [ob_db::exec_qry ob_price::get_frac_price $dec]} msg]} {
		ob_log::write ERROR {PRICE: unable to obtain fractional odds: $msg}
		return [list]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR\
		    {PRICE: unable to obtain fractional odds: invalid nrows returned}
		set frac [list]
	} else {
		set frac [list [db_get_col $rs 0 p_num] [db_get_col $rs 0 p_den]]
	}

	ob_db::rs_close $rs
	return $frac
}


# Simplify a price to its lowest terms
# e.g. 12/2 --> 6/1
#
#    num     - numerator
#    den     - denominator
#
proc ob_price::simplify_price {num den} {

	set gcd [get_greatest_common_divisor $num $den]

	set num [expr {$num / $gcd}]
	set den [expr {$den / $gcd}]

	return [list $num $den]
}

# Returns the greatest common denominator of 2 numbers
# Used for the above simplification proc
#
#    num     - numerator
#    den     - denominator
#
#
proc ob_price::get_greatest_common_divisor {num den} {
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
