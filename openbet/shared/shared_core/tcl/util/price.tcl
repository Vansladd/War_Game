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
#    package require core::price ?1.0?
#
# Procedures:
#    core::price::init         one time initialisation
#    core::price::mk           make a formatted price string (fractional arg)
#    core::price::mk_dec       make a formatted price string (decimal arg)
#    core::price::mk_str       make a formatted price string (live & starting arg)
#

set pkg_version 1.0
package provide core::price $pkg_version
package require core::log 1.0
package require core::check 1.0
package require core::args 1.0
package require core::db 1.0


# Variables
#
core::args::register_ns \
	-namespace core::price \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::db] \
	-docs      util/price.xml

namespace eval core::price {

	variable CFG
	variable INIT
	variable SPECIAL
	variable CORE_DEF

	# special prices
	array set SPECIAL [list \
		13/8 2.62\
		15/8 2.87\
		11/8 2.37\
		8/13 1.61\
		2/7  1.28\
		1/8  1.12]

	set CORE_DEF(num,opt)            [list -arg -num            -mand 0 -check UINT                                         -default {} -desc {Price numerator}]
	set CORE_DEF(den,opt)            [list -arg -den            -mand 0 -check UINT                                         -default {} -desc {Price denominator}]
	set CORE_DEF(price_type,opt)     [list -arg -price_type     -mand 0 -check {ENUM -args {DECIMAL AMERICAN ITALIAN ODDS}} -default {} -desc {Price type to use}]
	set CORE_DEF(market_sort,opt)    [list -arg -market_sort    -mand 0 -check ASCII                                        -default {} -desc {Market sort}]
	set CORE_DEF(enable_legacy,opt)  [list -arg -enable_legacy  -mand 0 -check BOOL                                         -default 0  -desc {Flag to enable legacy handling of price conversions}]
	set CORE_DEF(decimal_places,opt) [list -arg -decimal_places -mand 0 -check {UINT -max_num 4}                            -default {} -desc {Number of decimal places to display}]

	# package initialisation
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration.
#
core::args::register \
	-proc_name core::price::init \
	-desc      {Initialise the core::price package} \
	-args      [list \
		[list -arg -default_price_type        -mand 0 -check {ENUM -args {ODDS DECIMAL AMERICAN ITALIAN}}    -default_cfg PRICE_TYPE_DEFAULT     -default ODDS    -desc {Default price type}] \
		[list -arg -default_decimal_places    -mand 0 -check {INT -min_num 0 -max_num 3}             -default_cfg PRICE_DPS_DEFAULT      -default 2       -desc {Default decimal places for prices}] \
		[list -arg -default_rounding_method   -mand 0 -check {ENUM -args {UP DOWN HALFEVEN NEAREST}} -default_cfg PRICE_ROUNDING_DEFAULT -default NEAREST -desc {Default rounding method}] \
		[list -arg -decimal_on_asian_handicap -mand 0 -check BOOL                                    -default_cfg FUNC_FORCE_DEC_ON_AH   -default 0       -desc {Force decimal price type on asian handicap}] \
		[list -arg -dec2frac_query            -mand 0 -check BOOL                                    -default_cfg FUNC_DEC2FRAC_QUERY    -default 0       -desc {Force algebraic price conversion}] \
		[list -arg -decimal_separator         -mand 0 -check ASCII                                    -default_cfg PRICE_DECIMAL_SEPARATOR -default .     -desc {Force decimal separator change}] \

	] \
	-body {
		variable CFG
		variable INIT

		# already initialised?
		if {$INIT} {
			return
		}

		core::log::write DEBUG {PRICE: init}

		# set configuration
		foreach name [array names ARGS] {
			set key [string trimleft $name "-"]
			set CFG($key) $ARGS($name)
		}

		# prepare queries
		_prepare_qrys

		set INIT 1
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
#    returns        - formatted price
#
core::args::register \
	-proc_name core::price::mk \
	-desc      {Make a formatted price string when supplied a numerator and denominator (fractional).} \
	-args      [list \
		$::core::price::CORE_DEF(num,opt) \
		$::core::price::CORE_DEF(den,opt) \
		$::core::price::CORE_DEF(price_type,opt) \
		$::core::price::CORE_DEF(enable_legacy,opt) \
		$::core::price::CORE_DEF(decimal_places,opt) \
		$::core::price::CORE_DEF(market_sort,opt) \
	] \
	-body {
		return [_mk \
			$ARGS(-num) \
			$ARGS(-den) \
			$ARGS(-price_type) \
			$ARGS(-enable_legacy) \
			$ARGS(-decimal_places) \
			$ARGS(-market_sort)]
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
#   returns     - formatted price
#
core::args::register \
	-proc_name core::price::mk_dec \
	-desc      {Make a formatted price string when supplied a decimal.} \
	-args      [list \
		[list -arg -decimal_price -mand 1 -check DECIMAL -desc {Decimal price for conversion}] \
		$::core::price::CORE_DEF(price_type,opt) \
		[list -arg -invert_price -mand 0 -check BOOL -default 0 -desc {Should the decimal price be inverted}] \
		$::core::price::CORE_DEF(market_sort,opt) \
		$::core::price::CORE_DEF(decimal_places,opt) \
	] \
	-body {
		variable CFG

		set dec        $ARGS(-decimal_price)
		set price_type $ARGS(-price_type)
		set invert     $ARGS(-invert_price)
		set dp         $ARGS(-decimal_places)

		if {$dp == {}} {
			set dp $CFG(default_decimal_places)
		}

		# use DECIMAL if Asian Handicap and cfg set
		# use the default price type if not supplied
		if {$price_type == ""} {
			if {$ARGS(-market_sort) == "AH" && $CFG(decimal_on_asian_handicap)} {
				set price_type "DECIMAL"
			} else {
				set price_type $CFG(default_price_type)
			}
		}

		switch -exact -- $price_type {
			DECIMAL {
				if {$invert} {
					if {$dec > 1.0} {
						set dec [expr {(1.0 / (double($dec) - 1.0)) + 1.0}]
					}
				}

				return [_format_dec $dec $dp]
			}
			AMERICAN {
				set frac [_dec_to_frac $dec $dp]

				if {$invert} {
					set frac [list [lindex $frac 1] [lindex $frac 0]]
				}

				set num [lindex $frac 0]
				set den [lindex $frac 1]
				set prc [_format_dec [_frac_to_american $num $den] 0]

				if {$prc >= 0} {
					return "+$prc"
				} else {
					return $prc
				}
			}
			ITALIAN {
				set frac [_dec_to_frac $dec $dp]
				return [_format_dec [_frac_to_italiano [lindex $frac 0] [lindex $frac 1]] 0]
			}
			ODDS -
			default {
				set frac [_dec_to_frac $dec $dp]

				if {$invert} {
					set frac [list [lindex $frac 1] [lindex $frac 0]]
				}

				if {[lindex $frac 0] == [lindex $frac 1]} {
					return "evens"
				}

				return [join $frac "/"]
			}
		}
	}



# Decimal to fractional price conversion.
#
# Calls either database query to convert prices,
# or algebraic conversion
#
#  dec_price - decimal price to convert
#  
core::args::register \
	-proc_name core::price::dec_to_frac \
	-desc      {Return a formatted fractional price when supplied with a decimal price} \
	-args      [list \
		[list -arg -decimal_price -mand 1 -check DECIMAL -desc {Decimal price for conversion}] \
		$::core::price::CORE_DEF(decimal_places,opt) \
		] \
	-body {
		set dec_price $ARGS(-decimal_price)
		set dec_places $ARGS(-decimal_places)

		variable CFG

		if {$dec_places ni [list 2 3 4]} {
			set dec_places 3
		}

		if {$CFG(dec2frac_query) == 0} {
			return [dec2frac -decimal $dec_price]
		} else {
			return [_dec_to_frac $dec_price $dec_places]
		}
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
# returns - formatted price string
#
core::args::register \
	-proc_name core::price::mk_str \
	-desc      {Make a formatted price string when supplied either live price, dividend or starting price.} \
	-args      [list \
		[list -arg -bet_price_type    -mand 1 -check {ASCII -max_str 2} -desc {The type of the bet price (Live, Dividend or Starting price)}] \
		$::core::price::CORE_DEF(num,opt) \
		$::core::price::CORE_DEF(den,opt) \
		$::core::price::CORE_DEF(price_type,opt) \
		$::core::price::CORE_DEF(enable_legacy,opt) \
		$::core::price::CORE_DEF(decimal_places,opt) \
		$::core::price::CORE_DEF(market_sort,opt) \
	] \
	-body {
		# This switch statement could be re-factored but written this way makes
		# it very obvious what happens in each case
		switch -exact -- $ARGS(-bet_price_type) {
			L {
				if {$ARGS(-num) != {} && $ARGS(-den) != {}} {
					return [_mk \
						$ARGS(-num) \
						$ARGS(-den) \
						$ARGS(-price_type) \
						$ARGS(-enable_legacy) \
						$ARGS(-decimal_places) \
						$ARGS(-market_sort)]
				}
				return ""
			}
			D {
				return {Dividend}
			}
			G -
			S {
				if {$ARGS(-num) != {} && $ARGS(-den) != {}} {
					return [_mk \
						$ARGS(-num) \
						$ARGS(-den) \
						$ARGS(-price_type) \
						$ARGS(-enable_legacy) \
						$ARGS(-decimal_places) \
						$ARGS(-market_sort)]
				}
				if {$ARGS(-bet_price_type) == {S}} {
					return {SP}
				} {
					return {GP}
				}
			}
			default {
				# If unrecognised bet price type return formatted price anyway
				return [_mk \
						$ARGS(-num) \
						$ARGS(-den) \
						$ARGS(-price_type) \
						$ARGS(-enable_legacy) \
						$ARGS(-decimal_places) \
						$ARGS(-market_sort)]
			}
		}
	}


# Return the probability of an outcome based on its price.
# The probability that the bookmaker associates with an outcome is the reciprocal of its decimal
# price, however because the bookmaker wants to keep its book profitable, the sum of the probabilities will not
# equal 100%. This proc provides the ability to weigh the probability of an outcome to make the sum equal 100%
#
# Returns - dict of outcome/probability
#
core::args::register \
	-proc_name core::price::probability \
	-desc      {Calculate the probability of an outcome based on its price} \
	-args      [list\
		[list -arg -outcomes          -mand 1 -check ANY   -desc {A dictionary containing the outcome prices}]\
		[list -arg -weighted          -mand 0 -check BOOL  -desc {Whether to weigh using the overround or not} -default 0] \
		[list -arg -decimal_separator -mand 0 -check ASCII -desc {Force decimal separator change}] \
		$::core::price::CORE_DEF(decimal_places,opt) \
	] \
	-body {

		variable CFG

		set ds $ARGS(-decimal_separator)

		if {$ds == ""} {
			# Use the one on initialisation
			set ds $CFG(decimal_separator)
		}

		# -Validate outcomes
		#
		set outcomes $ARGS(-outcomes)

		# Must have at least one
		if {![dict size $outcomes]} {
			error "Cannot calculate probabilities for empty outcomes" {} MISSING_OUTCOMES
		}

		foreach ev_oc_id [dict keys $outcomes] {
			set price [dict get $outcomes $ev_oc_id]

			if {![core::check::decimal $price] || $price < 1.0} {
				error "Invalid price for outcome $ev_oc_id" {} INVALID_PRICE
			}
		}

		# Return result will be in the form key/value | ev_oc_id/probability
		set ret [dict create]

		set overround 1

		# Get true overround if we want to weigh the probabilities
		if {$ARGS(-weighted)} {
			set overround 0
			foreach ev_oc_id [dict keys $outcomes] {
				set price [dict get $outcomes $ev_oc_id]
				set overround [expr {$overround + (1 / $price)}]
			}
		}

		# Do the actual calculation
		set oc_idx    1
		set sum_probs 0
		foreach ev_oc_id [dict keys $outcomes] {

			set price       [dict get $outcomes $ev_oc_id]
			set probability [expr {100 * (1 / $price) / $overround}]

			# If we're weighting and this is the last outcome, we use the diff to 100
			if {$ARGS(-weighted) && $oc_idx == [dict size $outcomes]} {
				set formatted [_format_dec [expr {100 - $sum_probs}] $ARGS(-decimal_places) NEAREST $ds]
			} else {
				set formatted [_format_dec $probability $ARGS(-decimal_places) NEAREST $ds]
			}

			dict set ret $ev_oc_id $formatted

			set sum_probs [expr {$sum_probs + $probability}]

			incr oc_idx
		}

		return $ret
	}



# ===================================
# Private functions
# ===================================
proc core::price::_mk {num den {price_type {}} {legacy 0} {dps {}} {market_sort {}}} {
	variable CFG

	# num & den not supplied
	if {$num == "" && $den == ""} {
		return "-"
	}

	# use the default price type if not supplied and
	# force to DECIMAL on Asian Handicaps if required
	if {$price_type == ""} {
		if {$market_sort == "AH" && $CFG(decimal_on_asian_handicap)} {
			set price_type "DECIMAL"
		} else {
			set price_type $CFG(default_price_type)
		}
	}

	# format the price, dependent on price_type
	switch -exact -- $price_type {
		DECIMAL {
			return [_format_dec [_frac_to_dec $num $den] $dps]
		}
		AMERICAN {
			set prc [_format_dec [_frac_to_american $num $den] 0]
			if {$prc >= 0} {
				return "+$prc"
			} else {
				return $prc
			}
		}
		ITALIAN {
			return [_format_dec [_frac_to_italiano $num $den] 0]
		}
		ODDS -
		default {
			if {$num == $den} {
				return evens
			} elseif {$den == 1000} {
				# denominator of 1000 denotes decimal price
				if {$legacy} {
					return [_format_dec [_frac_to_dec $num $den] $dps]
				} else {
					set fraction [dec2frac -decimal [_frac_to_dec $num $den]]
					return "[lindex $fraction 0]/[lindex $fraction 1]"
				}
			}

			# Return in ODDS format
			return "[expr {int($num)}]/[expr {int($den)}]"
		}
	}
}

# Private procedure to prepare the package queries.
#
proc core::price::_prepare_qrys args {

	foreach {dp col} {2 p_dec2dp 3 p_dec3dp 4 p_dec} {

		core::db::store_qry \
			-name [subst {core::price::get_frac_price_$dp}] \
			-qry [subst {
				select
					p_num,
					p_den
				from
					tPriceConv
				where
					$col = (
						select max($col) from tPriceConv where $col <= ?
					)
			}]
	}
}

#--------------------------------------------------------------------------
# Price Conversions
#--------------------------------------------------------------------------

# Decimal to fraction price conversion.
#
#   dec     - decimal to convert
#   dp      - Number of decimal places to use
#   returns - list of numerator and denominator, or an empty list on error
#
proc core::price::_dec_to_frac { dec {dp 3} } {

	if {$dp == ""} {
		set dp 3
	}

	if {[catch {set rs [core::db::exec_qry -name core::price::get_frac_price_$dp -args $dec]} msg]} {
		core::log::write ERROR {PRICE: unable to obtain fractional odds: $msg}
		return [list]
	}

	if {[db_get_nrows $rs] != 1} {
		core::log::write ERROR\
		    {PRICE: unable to obtain fractional odds: invalid nrows returned}
		set frac [list]
	} else {
		set frac [list [db_get_col $rs 0 p_num] [db_get_col $rs 0 p_den]]
	}

	core::db::rs_close -rs $rs
	return $frac
}

# Fractional to italiano price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - italiano price (not rounded or set to 'n' dps)
#
proc core::price::_frac_to_italiano { num den } {
	return [format %.15g [expr {(double($num) / double($den)) * 100}]]
}

# Fractional to decimal price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - decimal price (not rounded or set to 'n' dps)
#
proc core::price::_frac_to_dec { num den } {

	variable SPECIAL

	if {[info exists SPECIAL($num/$den)]} {
		return $SPECIAL($num/$den)
	}

	# QC30285:
	#
	# % puts [expr {0.57 + 1.0}]
	# 1.5699999999999998
	#
	# because 0.57 doesn't have an exact representation as an IEEE double precision
	# floating point number (which is base-2); in fact, it's representation
	# is a little bit lower than exactly 0.57 
	# Forcing a fixed number of decimal places with format %.15g seems to fix the problem 

	return [format %.15g [expr {(double($num) / double($den)) + 1.0}]]
}

# Decimal to fractional price conversion
#
# When '-simple 0' (default behaviour) it's pretty accurate, so give
# it at least 6dp if you've got a repeating decimal
# i.e. 1.1428 yields 357/2500 (spot on), and 1.142857 is 1/7
#
# When '-simple 1' we just round the price to 3 significant
# figures and use a denominator of 1000
#
core::args::register \
	-proc_name core::price::dec2frac \
	-desc      {Takes a decimal price and returns it as a fraction} \
	-args      [list \
		[list -arg -decimal -mand 1 -check DECIMAL -desc {Decimal price for conversion}] \
		[list -arg -simple  -mand 0 -check BOOL    -desc {Do simple conversion i.e. denominator = 1000} -default 0] \
	] \
	-body {
		set decimal [expr {$ARGS(-decimal) - 1}]

		if {$ARGS(-simple) == 1} {

			set den 1000
			set num [expr {round(($decimal) * $den)}]

		} else {

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
		}

		return [list $num $den]
	}

# Fractional to american price conversion.
#
#    num     - numerator
#    den     - denominator
#    returns - american price (not rounded or set to 'n' dps)
#
proc core::price::_frac_to_american { num den } {

	if {$num >= $den} {
		return [format %.15g [expr {(double($num) / double($den)) * 100}]]
	} elseif {$den > $num} {
		return [format %.15g [expr {(double($den) / double($num)) * -100}]]
	}
}

# =======================================
# Fraction utilities
# =======================================

# Returns the greatest common denominator of 2 numbers
# Used for the above simplification proc
#
#    num     - numerator
#    den     - denominator
#
#
proc core::price::_get_greatest_common_divisor {num den} {
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

# Simplify a price to its lowest terms
# e.g. 12/2 --> 6/1
#
#    num     - numerator
#    den     - denominator
#
proc core::price::_simplify_price {num den} {

	set gcd [get_greatest_common_divisor $num $den]

	set num [expr {$num / $gcd}]
	set den [expr {$den / $gcd}]

	return [list $num $den]
}

# ======================
# Decimal Utilities
# ======================
# Format a decimal number.
# Sets the number of decimal places (dps) and what sort of rounding
#
#   dec       - decimal to format
#   dps       - decimal places (0..3)
#               if not supplied, then use default dps
#   rounding  - type of rounding (UP|DOWN|HALFEVEN|NEAREST)
#               if not supplied, then use default rounding
#   separator - decimal separator (. or ,)
#               if not supplied, then use the current one
#   returns   - formatted decimal number
#
proc core::price::_format_dec { dec {dps ""} {rounding ""} {separator ""}} {

	variable CFG

	# check dps
	if {$dps == ""} {
		set dps $CFG(default_decimal_places)
	}

	# check rounding
	if {$rounding != ""} {
		set rounding [string toupper $rounding]
	} else {
		set rounding $CFG(default_rounding_method)
	}

	# check decimal separator
	if {$separator == ""} {
		set separator $CFG(decimal_separator)
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
			set tmp [format %0.15f [format %.15g [expr {double($dec) * $scale}]]]
			set l   [expr {[string first "." $tmp] - 1}]
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
		regsub {[^0-9]+} $fdec $separator fdec
	} else {
		set fdec $dec
	}

	return $fdec
}

# ======================
# Handicap Utilities
# ======================
# Make a handicap description for an A/H/U/L market, given the market type,
# the tag of the selection bet on, and the handicap value
#
# mkt_type  - The market sort
# fb_result - Home/Draw/Away
# hcap      - Handicap Value
#
# returns - 'hcap', the translated handicap string
#
proc core::price::_mk_hcap_str {mkt_type fb_result hcap} {

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
proc core::price::_ah_string {v} {

	set v [expr {int(($v>0)?($v+0.25):($v-0.25))}]

	if {$v % 2 == 0} {
		return [format %0.1f [expr {($v%4==0)?$v/4:$v/4.0}]]
	}
	incr v -1
	set h1 [expr {($v%4==0)?$v/4:$v/4.0}]
	incr v 2
	set h2 [expr {($v%4==0)?$v/4:$v/4.0}]

	return [format %0.1f/%0.1f $h1 $h2]

}
