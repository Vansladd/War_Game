# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# Handicap utilities
#

set pkgVersion 1.0
package provide core::handicap $pkgVersion

# Dependencies
package require core::args 1.0

core::args::register_ns \
	-namespace core::handicap \
	-version   $pkgVersion \
	-dependent [list core::args] \
	-docs      util/handicap.xml

namespace eval core::handicap {
	variable CFG
	variable INIT 0
}

core::args::register \
	-proc_name core::handicap::init \
	-args [list \
		[list -arg -market_handicap_delimiter -mand 0 -check STRING -default_cfg MARKET.HANDICAP_DELIMITER -default {.}   -desc {Market Handicap Delimiter}] \
		[list -arg -market_handicap_format    -mand 0 -check STRING -default_cfg MARKET.HANDICAP_FORMAT    -default { & } -desc {Market Handicap Format}] \
		[list -arg -market_A_handicap_format  -mand 0 -check STRING -default_cfg MARKET.A.HANDICAP_FORMAT  -default {}    -desc {Market Type A Handicap Format}] \
		[list -arg -market_H_handicap_format  -mand 0 -check STRING -default_cfg MARKET.H.HANDICAP_FORMAT  -default {}    -desc {Market Type H Handicap Format}] \
		[list -arg -market_C_handicap_format  -mand 0 -check STRING -default_cfg MARKET.C.HANDICAP_FORMAT  -default {}    -desc {Market Type C Handicap Format}] \
		[list -arg -market_L_handicap_format  -mand 0 -check STRING -default_cfg MARKET.L.HANDICAP_FORMAT  -default {}    -desc {Market Type L Handicap Format}] \
		[list -arg -market_M_handicap_format  -mand 0 -check STRING -default_cfg MARKET.M.HANDICAP_FORMAT  -default {}    -desc {Market Type M Handicap Format}] \
		[list -arg -market_N_handicap_format  -mand 0 -check STRING -default_cfg MARKET.N.HANDICAP_FORMAT  -default {}    -desc {Market Type N Handicap Format}] \
		[list -arg -market_S_handicap_format  -mand 0 -check STRING -default_cfg MARKET.S.HANDICAP_FORMAT  -default {}    -desc {Market Type S Handicap Format}] \
		[list -arg -market_U_handicap_format  -mand 0 -check STRING -default_cfg MARKET.U.HANDICAP_FORMAT  -default {}    -desc {Market Type U Handicap Format}] \
		[list -arg -market_l_handicap_format  -mand 0 -check STRING -default_cfg MARKET.l.HANDICAP_FORMAT  -default {}    -desc {Market Type l Handicap Format}] \
		[list -arg -market_P_handicap_format  -mand 0 -check STRING -default_cfg MARKET.P.HANDICAP_FORMAT  -default {}    -desc {Market Type P Handicap Format}] \
		[list -arg -invert_variant_hcap       -mand 0 -check BOOL   -default_cfg INVERT_VARIANT_HCAP       -default 1     -desc {Decides if we invert variant handicaps}] \
	]

proc core::handicap::init args {
	variable CFG
	variable INIT

	array set ARGS [core::args::check core::handicap::init {*}$args]

	if {$INIT} {
		return
	}

	foreach {n v} [core::args::check core::handicap::init {*}$args] {
		set n [string trimleft $n -]
		set CFG($n) $v
	}

	set CFG(availableMarketTypes) [list A H C L M N S U l P]

	set INIT 1
}

core::args::register \
	-interface     core::handicap::get_hcap_result \
	-desc          {Calculate actual handicap selection result} \
	-errors        [list \
	] \
	-return_data   [list \
		 [list -arg -hcap_result   -mand 0 -check {EXACT -args {W L U -}} -desc {Result Type e.g. W Win, L Lose, U Unknown, Unresulted}]
	] \
	-args          [list \
		[list -arg -sort         -mand 0 -check STRING  -default {--} -desc {Market Sort}] \
		[list -arg -fb_result    -mand 1 -check STRING  -desc  {Additional result information used to determine actual result.}] \
		[list -arg -hcap_value   -mand 1 -check DECIMAL -desc  {Handicap Value}] \
		[list -arg -hcap_makeup  -mand 1 -check DECIMAL -desc  {Is the value to settle handicap markets against. See tEvMkt.hcap_makeup.}] \
	]

core::args::register \
	-proc_name core::handicap::format_market_handicap \
	-args [list \
		[list -arg -type -mand 1 -check STRING  -desc {Market Type}] \
		[list -arg -hcap -mand 1 -check DECIMAL -desc {Handicap Value}] \
	]

proc core::handicap::format_market_handicap args {
	variable CFG

	array set ARGS [core::args::check core::handicap::format_market_handicap {*}$args]

	if {[lsearch $CFG(availableMarketTypes) $ARGS(-type)] == -1} {
		return {}
	}

	set delimiter $CFG(market_handicap_delimiter)
	set divider   $CFG(market_handicap_format)
	if {$CFG(market_$ARGS(-type)_handicap_format) != {}} {
		set divider $CFG(market_$ARGS(-type)_handicap_format)
	}

	set handicap $ARGS(-hcap)

	switch -- $ARGS(-type) {
		A -
		l {
			set handicap [_format_ahstring  $handicap  $ARGS(-type) $divider]
		}
		H -
		M -
		P {
			if {$handicap > 0} {
				set handicap "+$handicap"
			}
		}
	}

	if {$delimiter != {.}} {
		while {[string match {*\.*} $handicap]} {
			regsub {\.} $handicap $delimiter handicap
		}
	}

	return $handicap
}


core::args::register \
	-proc_name core::handicap::format_outcome_handicap \
	-args [list \
		[list -arg -type         -mand 1 -check STRING  -desc {Market Type}] \
		[list -arg -hcap         -mand 1 -check DECIMAL -desc {Handicap Value}] \
		[list -arg -fb_result    -mand 1 -check STRING  -desc {FbResult}] \
		[list -arg -sort         -mand 0 -check STRING  -default {--} -desc {Market Sort}] \
		[list -arg -outcome_hcap -mand 0 -check DECIMAL -default {}   -desc {Outcome Handicap}] \
		[list -arg -is_variant   -mand 0 -check BOOL    -default 0    -desc {Variant Flag}] \
	]

proc core::handicap::format_outcome_handicap args {
	variable CFG

	array set ARGS [core::args::check core::handicap::format_outcome_handicap {*}$args]

	set hcap $ARGS(-hcap)
	# For variants we store the "true" hcap value so
	# no need to flip the sign
	if {$ARGS(-is_variant) && !$CFG(invert_variant_hcap)} {
		return [core::handicap::format_market_handicap -type $ARGS(-type) -hcap $hcap]
	}

	# Flip sign for away teams
	switch -- $ARGS(-fb_result) {
		A {
			set hcap [expr {$hcap * -1}]
		}
	}

	# Points markets have a different handicap for each outcome,
	# whereas other markets use the value of tevmkt.hcap_value
	# In either case, we use the market level configs to decide how
	# to format the value.
	switch -- $ARGS(-type).$ARGS(-sort) {
		P.PM {
			if {$ARGS(-outcome_hcap) == {}} {
				return {}
			} else {
				return [core::handicap::format_market_handicap -type $ARGS(-type) -hcap $ARGS(-outcome_hcap)]
			}
		}
		default {
			return [core::handicap::format_market_handicap -type $ARGS(-type) -hcap $hcap]
		}
	}
}



# Handles the formatting for market Type A and l
#
proc core::handicap::_format_ahstring {hcap type divider} {

	set h1 [expr {int($hcap) % 2 ? (int($hcap) - 1) / 4.0 : int($hcap) / 4.0}]
	set h2 [expr {int($hcap) % 2 ? (int($hcap) + 1) / 4.0 : int($hcap) / 4.0}]

	if {abs($h1) > abs($h2)} {
		foreach {h1 h2} [list $h2 $h1] {}
	}

	set hcapformat [expr {$type == "A" ? "%+0.1f" : "%0.1f"}]
	set zeroformat "%0.1f"

	if {$h1 == $h2} {
		return [format [expr {$h1 == 0.0 ? $zeroformat : $hcapformat}] $h1]
	} else {
		set h1 [format [expr {$h1 == 0.0 ? $zeroformat : $hcapformat}] $h1]
		set h2 [format [expr {$h2 == 0.0 ? $zeroformat : $hcapformat}] $h2]
		return "${h1}${divider}${h2}"
	}
}


