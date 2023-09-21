# $Id: price-compat.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle price utilities compatibility with non-package APIs.
#
# The package provides wrappers for each of the older APIs which are potentially
# still been used within other shared_tcl files or the calling application.
# Avoid calling the wrapper APIs within your applications, always use the
# util_price package (ob_price namespace).
#
# The package should always be loaded when using util_price 4.5 package.
# Do not source prc_util.tcl when using the price packages.
#
# Configuration:
#    PRICE_TYPE_DEFAULT         price type default      (ODDS)
#    PRICE_DPS_DEFAULT          decimal places default  (2)
#    PRICE_ROUNDING_DEFAULT     rounding default        (NEAREST)
#
# Synopsis:
#    package require util_price_compat ?4.5?
#
# Procedures:
#    init_prc_util       one time initialisation
#    mk_price            make a formatted price string (fractional arg)
#    mk_price_dec        make a formatted price string (decimal arg)
#    mk_price_str        make a formatted price string (live & starting arg)
#    mk_bet_price_str    make a formatted price string (bet arg)
#    format_dec_price    format a decimal number
#    frac_price_to_dec   fraction to decimal conversion
#    dec_price_to_frac   decimal to fraction conversion
#


package provide util_price_compat 4.5


# Dependencies
# - auto initialise
#
package require util_log   4.5
package require util_price 4.5
package require cust_pref  4.5
package require cust_login 4.5

ob_log::init
ob_price::init
ob_cpref::init
ob_login::init



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc init_prc_util args {
}



#--------------------------------------------------------------------------
# Price Formatting
#--------------------------------------------------------------------------

# Make a formatted price string (as used on an end-device) when supplied a
# numerator and denominator (fractional).
#
# The format of the price is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The procedure will get the price_type from the customer preferences if not
# defined (this is not performed by ob_price::mk). This breaks the rules of
# cross package communication, however, since the original performed this
# functionality we must provide backward compatibility.
#
#    num        - numerator
#    den        - denominator
#    price_type - price format type (DECIMAL|ODDS)
#    returns    - formatted price
#
proc mk_price { num den {price_type ""} } {

	# get the price type from the customer preference
	# NB: - if not defined, then use default type
	if {$price_type == ""} {

		ob_log::write WARNING {PRICE-COMPAT: using customer pref PRICE_TYPE}
		set p [ob_cpref::get PRICE_TYPE [ob_login::get cust_id]]

		if {[llength $p] > 0} {
			set price_type [lindex $p 0]
		}
		ob_log::write DEBUG	{PRICE-COMPAT: cust pref PRICE_TYPE=$price_type}
	}

	return [ob_price::mk $num $den $price_type]
}



# Make a formatted price string (as used on an end-device) when supplied a
# decimal.
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The procedure will get the price_type from the customer preferences (this is
# not performed by ob_price::mk). This breaks the rules of cross package
# communication, however, since the original performed this functionality we
# must provide backward compatibility.
#
#   dec         - decimal to format
#   invert      - invert the price
#   returns     - formatted price, or "ERROR" on error
#
proc mk_price_dec { dec {invert 0} } {

	set price_type ""

	ob_log::write WARNING {PRICE-COMPAT: using customer pref PRICE_TYPE}
	set p [ob_cpref::get PRICE_TYPE [ob_login::get cust_id]]

	if {[llength $p] > 0} {
		set price_type [lindex $p 0]
	}
	ob_log::write DEBUG	{PRICE-COMPAT: cust pref PRICE_TYPE=$price_type}

	return [ob_price::mk_dec $dec $price_type $invert]
}



# Make a formatted price string (as used on an end-device) when supplied either
# live price or starting price
#
# The format of the result is dependent on the price-type and if decimal,
# dependent on the default number of decimal places and rounding type.
#
# The procedure will get the price_type from the customer preferences if not
# defined (this is not performed by ob_price::mk). This breaks the rules of
# cross package communication, however, since the original performed this
# functionality we must provide backward compatibility.
#
#   is_lp       - is a live price?
#   is_sp       - is a starting price?
#   lpn         - live price numerator
#   lpd         - live price denominator
#   spn         - starting price numerator, default ""
#   spd         - starting price denominator, default ""
#   price_type  - price type (DECIMAL|ODDS)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#   returns     - formatted price, or "" if starting & live price is not
#                 supplied
#
proc mk_price_str { is_lp is_sp lpn lpd \
	                {spn ""} {spd ""} {price_type ""} } {

	# get the price type from the customer preference
	# NB: - if not defined, then use default type
	if {$price_type == ""} {

		ob_log::write WARNING {PRICE-COMPAT: using customer pref PRICE_TYPE}
		set p [ob_cpref::get PRICE_TYPE [ob_login::get cust_id]]

		if {[llength $p] > 0} {
			set price_type [lindex $p 0]
		}
		ob_log::write DEBUG	{PRICE-COMPAT: cust pref PRICE_TYPE=$price_type}
	}

	return [ob_price::mk_str $is_lp $is_sp $lpn $lpd $spn $spd $price_type]
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
#   spn         - starting price numerator (ignored)
#   spd         - starting price denominator (ignored)
#   price_type  - formatted price type (DECIMAL|ODDS)
#                 default "", which case use the cfg value PRICE_TYPE_DEFAULT
#   returns     - formatted price, or "" if starting & live price is not
#                 supplied
#
proc mk_bet_price_str { bet_price_type lpn lpd {spn ""} {spd ""}\
	                    {price_type ""} } {

	# get the price type from the customer preference
	# NB: - if not defined, then use default type
	if {$price_type == ""} {

		ob_log::write WARNING {PRICE-COMPAT: using customer pref PRICE_TYPE}
		set p [ob_cpref::get PRICE_TYPE [ob_login::get cust_id]]

		if {[llength $p] > 0} {
			set price_type [lindex $p 0]
		}
		ob_log::write DEBUG	{PRICE-COMPAT: cust pref PRICE_TYPE=$price_type}
	}

	return [ob_price::mk_bet_str $bet_price_type $lpn $lpd $price_type]
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
proc format_dec_price { dec {dps ""} {rounding ""} } {
	ob_price::format_dec $dec $dps $rounding
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
proc frac_price_to_dec { num den } {
	return [ob_price::frac_to_dec $num $den]
}



# Decimal to fraction price conversion.
#
#   dec     - decimal to convert
#   returns - list of numerator and denominator, or an empty list on error
#
proc dec_price_to_frac { dec } {
	return [ob_price::dec_to_frac $dec]
}
