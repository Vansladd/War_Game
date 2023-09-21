#
# $Id: util.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1997 Orbis Technology Ltd. All rights reserved.
# ==============================================================

global ACCT_KEY
global BF_DECRYPT_KEY_HEX
global PRICE_TYPE PRICE_ADD_ONE

#
# Load config stuff
#
set PRICE_TYPE          [OT_CfgGet PRICE_TYPE FRACTION]
set PRICE_ADD_ONE       [OT_CfgGet PRICE_ADD_ONE 1]
set ACCT_KEY            [OT_CfgGet ACCT_KEY -]

if {[set BF_DECRYPT_KEY [OT_CfgGet DECRYPT_KEY ""]] != ""} {
	set BF_DECRYPT_KEY_HEX  [bintohex $BF_DECRYPT_KEY]
} else {
	set BF_DECRYPT_KEY_HEX  [OT_CfgGet DECRYPT_KEY_HEX]
}


#
# ----------------------------------------------------------------------------
# Simple assertion
# ----------------------------------------------------------------------------
#
proc assert {e} {
	if {[catch {uplevel [list expr $e]} n] || $n == "" || $n == 0} {
		error "assertion ($e) failed (result $n)"
	}
}

#
# ----------------------------------------------------------------------------
# Price type descriptions
# ----------------------------------------------------------------------------
#
array set PriceTypes [list S SP B BP N NP 1 FS 2 SS]

proc get_price_type_desc {prc_type} {
	global PriceTypes

	if [info exists PriceTypes($prc_type)] {
		return $PriceTypes($prc_type)
	}
	return "-"
}

#
# Boring date stuff
#
set Months    [list xxx Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
set MonthDays [list   0  31  28  31  30  31  30  31  31  30  31  30  31]

#
# ----------------------------------------------------------------------------
# Get number of days in a month
# ----------------------------------------------------------------------------
#
proc days_in_month {m y} {
	global MonthDays
	# is year a leap year ? (sloppy, but good for a century or so)
	if {($m == 2) && ($y % 4 == 0)} {
		return 29
	}
	return [lindex $MonthDays $m]
}


#
# ---------------------------------------------------------------------------
# Check if date is valid informix date
# ---------------------------------------------------------------------------
#
proc valid_informix_date {date} {

	if {[regexp {^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$} $date match]} {

		return 1
	} else {

		return 0
	}
}

#
# ----------------------------------------------------------------------------
# Given an informix date, YYYY-MM-DD HH:MM:SS, produce a full date string
# ----------------------------------------------------------------------------
#
proc html_date {dt {style time}} {
	global FullMonths
	if {$style == "time"} {
		if [regexp {^(....)-(..)-(..) (..):(..):..$} $dt all y m d hh mm] {
			set m  [string trimleft $m  0]
			set d  [string trimleft $d  0]
			set hh [string trimleft $hh 0]

			if {$hh >= 12} {
				set hsfx pm
				set hh [expr $hh - 12]
				if {$hh == "0"} {
					set hh "12"
				}
			} else {
				set hsfx am
			}
			return "$d[day_sfx $d] [lindex $FullMonths $m] $y $hh:$mm$hsfx"
		}
		return $dt
	}

	if {$style == "day"} {
		if [regexp {^(....)-(..)-(..)} $dt all y m d] {
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
			return "$d[day_sfx $d] [lindex $FullMonths $m] $y"
		}
		return $dt
	}

	if {$style == "fullday"} {
		if [regexp {^(....)-(..)-(..)} $dt all y m d] {
			set d    [string trimleft $d 0]
			set m    [string trimleft $m 0]
			set secs [clock scan $m/$d/$y]
			set day  [clock format $secs -format %A]
			return   "$day $d[day_sfx $d] [lindex $FullMonths $m], $y"
		}
		return $dt
	}

	if {$style == "month"} {
		if [regexp {^(....)-(..)} $dt all y m] {
			set m [string trimleft $m 0]
			return "[lindex $FullMonths $m] $y"
		}
		return $dt
	}

	if {$style == "year"} {
		if [regexp {^(....)} $dt all y] {
			return "$y"
		}
		return $dt
	}

	return $dt
}


#
# ----------------------------------------------------------------------------
# Calculate date N days ago
# ----------------------------------------------------------------------------
#
proc date_days_ago {Y M D delta} {

	set M [string trimleft $M 0]
	set D [string trimleft $D 0]

	set D [expr {$D-$delta}]

	while {$D <= 0} {
		if {[incr M -1] == 0} {
			incr Y -1
			set M 12
		}
		incr D [days_in_month $M $Y]
	}
	return [format %04d-%02d-%02d $Y $M $D]
}

proc julian_day {y m d} {
	set tm [expr {(12*$y+$m-3)}]
	set ty [expr {$tm/12}]
	return [expr {(734*$tm+15)/24-2*$ty+$ty/4-$ty/100+$ty/400+$d+1721119}]
}

proc days_between {dt1 dt0} {

	foreach {y1 m1 d1} [split $dt1 -] { break }
	foreach {y0 m0 d0} [split $dt0 -] { break }

	foreach v {m1 d1 m0 d0} { set $v [string trimleft [set $v] 0] }

	set j1 [julian_day $y1 $m1 $d1]
	set j0 [julian_day $y0 $m0 $d0]

	return [expr {$j1-$j0}]
}

#
# ----------------------------------------------------------------------------
# Bind up a bunch of date ranges
# ----------------------------------------------------------------------------
#
#
# Bind various date ranges, value is pipe separated from|to
#
proc bind_date_ranges {} {

	global DATE_RANGES

	catch {unset DATE_RANGES}

	set DATE_RANGES(0,desc)      "Today"
	set from [clock format [clock scan "today"] -format "%Y-%m-%d 00:00:00"]
	set to   [clock format [clock scan "today"] -format "%Y-%m-%d 23:59:59"]
	set DATE_RANGES(0,value)     "$from|$to"
	set DATE_RANGES(0,selected)   ""

	set DATE_RANGES(1,desc)      "Yesterday"
	set from [clock format [clock scan "yesterday"] -format "%Y-%m-%d 00:00:00"]
	set to   [clock format [clock scan "yesterday"] -format "%Y-%m-%d 23:59:59"]
	set DATE_RANGES(1,value)     "$from|$to"
	set DATE_RANGES(1,selected)   ""

	set DATE_RANGES(2,desc)      "Last 3 days"
	set from [clock format [clock scan "3 days ago"] -format "%Y-%m-%d 00:00:00"]
	set to   [clock format [clock scan "today"] -format "%Y-%m-%d 23:59:59"]
	set DATE_RANGES(2,value)     "$from|$to"
	set DATE_RANGES(2,selected)   ""

	set DATE_RANGES(3,desc)      "Last 7 days"
	set from [clock format [clock scan "7 days ago"] -format "%Y-%m-%d 00:00:00"]
	set to   [clock format [clock scan "today"] -format "%Y-%m-%d 23:59:59"]
	set DATE_RANGES(3,value)     "$from|$to"
	set DATE_RANGES(3,selected)   "selected"

	set DATE_RANGES(4,desc)      "Current month"
	set from [clock format [clock seconds] -format "%Y-%m-01 00:00:00"]
	set start_next_month [clock format [clock scan "next month"] -format "%Y-%m-01 00:00:00"]
	set to   [clock format [expr {[clock scan $start_next_month] - 1}] -format "%Y-%m-%d 23:59:59"]
	set DATE_RANGES(4,value)     "$from|$to"
	set DATE_RANGES(4,selected)   ""


	tpSetVar num_date_ranges 5
	tpBindVar DateRangeDesc      DATE_RANGES desc     date_idx
	tpBindVar DateRangeValue     DATE_RANGES value    date_idx
	tpBindVar DateRangeSelected  DATE_RANGES selected  date_idx

}


#
# ----------------------------------------------------------------------------
# Make a price string given odds numerator and denominator
# ----------------------------------------------------------------------------
#
proc mk_price {n d} {
	global PRICE_TYPE PRICE_ADD_ONE
	if {$n == ""} {
		return ""
	}
	if {$d == 1000} {
		switch -- $PRICE_TYPE {
			DEC_3 -
			FRAC_DEC_3 {
				set res [format %0.3f [expr {double($n)/$d+$PRICE_ADD_ONE}]]
			}
			DEC_2 -
			FRAC_DEC_2 -
			FRAC -
			default {
				set res [format %0.2f [expr {double($n)/$d+$PRICE_ADD_ONE}]]
			}
		}
	} else {
		switch -- $PRICE_TYPE {
			DEC_3 {
				set res [format %0.3f [expr {double($n)/$d+$PRICE_ADD_ONE}]]
			}
			DEC_2 {
				set res [format %0.2f [expr {double($n)/$d+$PRICE_ADD_ONE}]]
			}
			FRAC_DEC_2 -
			FRAC_DEC_3 -
			FRAC -
			default {
				if {$n == $d} {
					set res evens
				}
				set res "$n/$d"
			}
		}
	}

	return $res
}


#
# ----------------------------------------------------------------------------
# Return numerator/denominator for a price, either decimal or fractional
# ----------------------------------------------------------------------------
#
proc get_price_parts prc {

	global PRICE_ADD_ONE

	set prc [string trim $prc]

	set RX_FRAC {^([0-9]+)/([0-9]+)$}
	set RX_DEC  {^([0-9]+)(\.[0-9]*)?$}

	# call conversion algorithm
	if {[regexp $RX_DEC $prc all]} {
		if {[OT_CfgGet PRICE_KEEP_1000_DEN "N"] == "Y"} {
			return [list [expr {int($prc*1000.0+0.5)-$PRICE_ADD_ONE*1000}] 1000]
		} else {
			return [dec2frac [expr {$prc - $PRICE_ADD_ONE}]]
		}
	}
	if {[regexp $RX_FRAC $prc all n d]} {
		return [list $n $d]
	}

	if {$prc != ""} {
		error "\'$prc\' is not a valid price"
	}

	return [list "" ""]
}


#
# ----------------------------------------------------------------------------
# Return numerator/denominator for a reduction, either decimal or fractional
# ----------------------------------------------------------------------------
#
proc get_reduction_parts redn {

	set redn [string trim $redn]

	set RX_FRAC {^([0-9]+)/([0-9]+)$}
	set RX_DEC  {^([0-9]+)(\.[0-9]*)?$}

	# call conversion algorithm
	if {[regexp $RX_DEC $redn all]} {
		return [dec2frac $redn 0]
	}
	if {[regexp $RX_FRAC $redn all n d]} {
		return [list $n $d]
	}

	if {$redn != ""} {
		error "\'$redn\' is not a valid reduction"
	}

	return [list "" ""]
}



# dec2frac -- takes a decimal and returns it as a fraction
# be warned, it's pretty accurate, so give it at least 6dp
# if you've got a repeating decimal
# i.e. 0.1428 yields 357/2500 (spot on), and 0.142857 is 1/7
proc dec2frac { decimal {do_bm_prices 1}} {

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

	if {$do_bm_prices && [info exists BM_PRICES($num/$den)]} {
		set frac [split $BM_PRICES($num/$den) "/"]
		set num [lindex $frac 0]
		set den [lindex $frac 1]
	}

	return [list $num $den]
}

#
# ----------------------------------------------------------------------------
# Make a short price and handicap summary string
# ----------------------------------------------------------------------------
#
proc mk_price_info {price_type leg_sort mkt_type fb_result hcap_value o_num o_den sp_num sp_den} {

	switch -- $price_type {
		S {
			set p_str "SP"
			switch -- $leg_sort {
				A2 -
				AH -
				hl {
					append p_str " ([ah_string $hcap_value])"
				}
				WH -
				OU -
				HL -
				MH {
					set hcap_str [mk_hcap_str $mkt_type $fb_result $hcap_value]
					append p_str " (${hcap_str})"
				}
			}
		}
		L {
			set p_str [mk_price $o_num $o_den]
			switch -- $leg_sort {
				A2 -
				AH -
				hl {
					append p_str " ([ah_string $hcap_value])"
				}
				WH -
				OU -
				HL -
				MH {
					set hcap_str [mk_hcap_str $mkt_type $fb_result $hcap_value]
					append p_str " (${hcap_str})"
				}
			}
		}
		G {
			# we show a good guess of the GP
			# set p_str GP

			if {$sp_num != "" && $sp_den != "" && [expr $o_num * $sp_den < $o_den * $sp_num] } {
				set p_str "[mk_price $sp_num $sp_den] (GP)"
			} else {
				set p_str "[mk_price $o_num $o_den] (GP)"
			}
		}
		D {
			set p_str "DIV ($leg_sort)"
		}
		P {
			set p_str PMU
		}
		B {
			set p_str BP
		}
		N {
			set p_str NP
		}
		1 {
			set p_str FS
		}
		2 {
			set p_str SS
		}
		default {
			error "unknown price type ($price_type)"
		}
	}

	return $p_str
}



#
# ----------------------------------------------------------------------------
# Get a cookie value
# ----------------------------------------------------------------------------
#
proc get_cookie {name} {
	global env
	set nl [string length $name]
	if [catch {set str [reqGetEnv HTTP_COOKIE]} msg] {
		return ""
	}
	set cl [split $str \;]
	foreach c $cl {
		set ct [string trim $c]
		if {$ct != ""} {
			set eq_pos [string first = $ct]
			if {$eq_pos >= 0} {
				set n [string range $ct 0 [expr {$eq_pos-1}]]
				if {$n == $name} {
					set v [string range $ct [expr {$eq_pos+1}] end]
					return [string trim $v]
				}
			}
		}
	}
	return ""
}


#
# ----------------------------------------------------------------------------
# Check permission
# ----------------------------------------------------------------------------
#
proc op_allowed args {

	foreach op $args {
		if {[tpGetVar PERM_$op] == "1"} {
			return 1
		}
	}
	return 0
}


#
# ----------------------------------------------------------------------------
# Channel information procedures
# ----------------------------------------------------------------------------
#
proc read_channel_info {{site_operator 0}} {

	#Retrieves channel information for the current database into global variables.

	global DB CHANNEL_MAP

	if {[info exists CHANNEL_MAP]} {
		return
	}

	if {$site_operator == 1} {
		set cust_id [reqGetArg CustId]

		set get_site_operator_id {
			select
				site_operator_id
			from
				tchannel channel,
				tcustomer cust
			where
				cust.cust_id = ? and
				cust.source = channel.channel_id
		}

		set stmt [inf_prep_sql $DB $get_site_operator_id]
		set res  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res] > 0} {
			set site_operator_id [db_get_coln $res 0 0]
		} else {
			set site_operator_id ""
		}

		if {$site_operator_id != ""} {
			set sql {
				select
					channel_id,
					desc
				from
					tChannel
				where
					site_operator_id = ?
			}
		} else {
			set sql {
				select
					channel_id,
					desc
				from
					tChannel
			}
		}
	} else {
		set sql {
			select
				channel_id,
				desc
			from
				tChannel
		}
	}


	set stmt [inf_prep_sql $DB $sql]
	if {$site_operator == 1} {
		set res  [inf_exec_stmt $stmt $site_operator_id]
	} else {
		set res  [inf_exec_stmt $stmt]
	}
	inf_close_stmt $stmt

	set CHANNEL_MAP(num_channels) [db_get_nrows $res]

	for {set i 0} {$i <  $CHANNEL_MAP(num_channels)} {incr i} {
		set code [db_get_col $res $i channel_id]
		set name [db_get_col $res $i desc]
		set CHANNEL_MAP($i,code)    $code
		set CHANNEL_MAP($i,name)    $name
		set CHANNEL_MAP(code,$code) $name
	}

	db_close $res

	GC::mark CHANNEL_MAP
}


proc make_channel_binds {{str ""} {mask ""} {add 0} {enable 1} {site_operator 0}} {

	# Str denotes which channels will be selected (checked)
	# The mask denotes which channels will be shown by adding the channel if it
	# exists in the mask.
	# Add enables you to turn on the checking/selecting feature.
	# Enable allows you to disable the check box array (when set to 0).
	# site_operator allows you to switch on site_operator checking (when set to 1).

	global CHANNEL_MAP USE_CHAN_MAP

	if {$site_operator == 1} {
		read_channel_info 1
	} else {
		read_channel_info
	}

	set c 0

	array set USE_CHAN_MAP [list]

	for {set i 0} {$i < $CHANNEL_MAP(num_channels)} {incr i} {

		set code $CHANNEL_MAP($i,code)

		#
		# if channel code is masked off (i.e. not present in mask), skip it
		#
		if {$mask != "-" && $mask != ""} {
			if {[string first $code $mask]<0} {
				continue
			}
		}

		set USE_CHAN_MAP($c,code) $code
		set USE_CHAN_MAP($c,name) $CHANNEL_MAP($i,name)
              
		#
		# Select the channel if it is in str, or we're adding a new entity
		#
		if {([string first $code $str] >= 0) || ($add == 1)} {
			set USE_CHAN_MAP($c,selected) CHECKED
		} else {
			set USE_CHAN_MAP($c,selected) ""
		}

		incr c
	}


	tpSetVar NumChannels $c

	tpBindVar ChanName USE_CHAN_MAP name     chan_idx
	tpBindVar ChanCode USE_CHAN_MAP code     chan_idx
	tpBindVar ChanSel  USE_CHAN_MAP selected chan_idx
	if {$enable} {
		tpBindString ChanEnable ""
	} else {
		tpBindString ChanEnable "disabled"
	}
	tpBindString ChanString $str
}


proc make_channel_str {{prefix CN_} {id ""}} {

	# This function is used in conjunction with the previous, it enables you to
	# retrieve the channels selected from the webpage, returning a string of all
	# the channels selects.

	global CHANNEL_MAP

	read_channel_info

	set result ""

	for {set i 0} {$i < $CHANNEL_MAP(num_channels)} {incr i} {
		set code $CHANNEL_MAP($i,code)
		if {[reqGetArg ${prefix}${code}$id] != ""} {
			append result $code
		}
	}
	return $result
}

proc make_formatted_channel_string {{channels ""}} {

	# This function is used in conjunction with the previous, it enables you to    
	# format a sting of channels as it would appear in the database

	global CHANNEL_MAP

	read_channel_info

	set result ""

	for {set i 0} {$i < $CHANNEL_MAP(num_channels)} {incr i} {
		set code $CHANNEL_MAP($i,code)
		if {[regexp $code $channels]} {
			append result $code
		}
	}
	return $result

}

#
# ----------------------------------------------------------------------------
# Layout map
# ----------------------------------------------------------------------------
#
proc read_layout_info args {

	global LAYOUT_MAP

	if {[info exists LAYOUT_MAP(done)]} {
		return
	} elseif {[info exists LAYOUT_MAP]} {
		unset LAYOUT_MAP
	}

	set tmp [OT_CfgGet LAYOUT_MAP ""]
	set i 0

	foreach d $tmp {
		set code [lindex $d 0]
		set name [lindex $d 1]
		set LAYOUT_MAP($i,code)    $code
		set LAYOUT_MAP($i,name)    $name
		set LAYOUT_MAP(code,$code) $name
		incr i
	}

	set LAYOUT_MAP(num_layouts) $i
	set LAYOUT_MAP(done) 1
}
#
# ----------------------------------------------------------------------------
# HiLo market Layout map
# ----------------------------------------------------------------------------
#
proc read_hilo_layout_info args {

	global LAYOUT_MAP

	if {[info exists LAYOUT_MAP(hilo_done)]} {
		return
	} elseif {[info exists LAYOUT_MAP]} {
		unset LAYOUT_MAP
	}

	set tmp [OT_CfgGet HILO_LAYOUT_MAP ""]
	set i 0

	foreach d $tmp {
		set code [lindex $d 0]
		set name [lindex $d 1]
		set LAYOUT_MAP($i,code)    $code
		set LAYOUT_MAP($i,name)    $name
		set LAYOUT_MAP(code,$code) $name
		incr i
	}

	set LAYOUT_MAP(num_layouts) $i
	set LAYOUT_MAP(hilo_done) 1
}


proc make_layout_binds {{str ""} {isHilo "N"}} {

	global LAYOUT_MAP USE_LAYOUT_MAP

	if {$isHilo == "Y"} {
		read_hilo_layout_info
		if {$str=="" && $LAYOUT_MAP(num_layouts) > 0} {
			set str $LAYOUT_MAP(0,code)
		}
	} else {
		read_layout_info
	}
	array set USE_LAYOUT_MAP [list]

	set have_tags [split $str ,]

	for {set i 0} {$i < $LAYOUT_MAP(num_layouts)} {incr i} {

		set code $LAYOUT_MAP($i,code)

		set USE_LAYOUT_MAP($i,code) $code
		set USE_LAYOUT_MAP($i,name) $LAYOUT_MAP($i,name)

		if {"$str" == "$code"} {
			set USE_LAYOUT_MAP($i,selected) CHECKED
		} else {
			set USE_LAYOUT_MAP($i,selected) ""
		}
	}

	tpSetVar NumLayouts $i

	tpBindVar LayoutName USE_LAYOUT_MAP name     layout_idx
	tpBindVar LayoutCode USE_LAYOUT_MAP code     layout_idx
	tpBindVar LayoutSel  USE_LAYOUT_MAP selected layout_idx
}

#
# ----------------------------------------------------------------------------
# Procedure: read_quick_update_flags
# Author: swalker 20/6/02
# Read in the flags to be included on the quick event update screen
# ----------------------------------------------------------------------------
#
proc read_quick_update_flags args {

	global QUICK_UPD_FLAG_MAP

	if {[info exists QUICK_UPD_FLAG_MAP(done)]} {
		return
	}

	set tmp [OT_CfgGet QUICK_EVENT_UPD_TAGS ""]
	set i 0

	foreach d $tmp {
		set code [lindex $d 0]
		set name [lindex $d 1]
		set QUICK_UPD_FLAG_MAP($i,code)    $code
		set QUICK_UPD_FLAG_MAP($i,name)    $name
		incr i
	}

	set QUICK_UPD_FLAG_MAP(num_flags) $i
	set QUICK_UPD_FLAG_MAP(done) 1
}

#
# ----------------------------------------------------------------------------
# Procedure: update_flags_list
# Author: swalker 20/6/02
# Makes a list of quick update flags.
# Takes in the origional list of flags for the customer before quick event update
# was called. Checks if each flag in QUICK_EVENT_UPD_TAGS has changed and changes
# the list if it has. Returns the new list of flags
# ----------------------------------------------------------------------------
#
proc update_flags_list {{o_flags_list ""} {prefix FL_} {id ""}} {

	global QUICK_UPD_FLAG_MAP

	read_quick_update_flags

	set result_list $o_flags_list
	for {set i 0} {$i < $QUICK_UPD_FLAG_MAP(num_flags)} {incr i} {
		set code $QUICK_UPD_FLAG_MAP($i,code)

		if {[lsearch -exact $result_list $code] >= 0} {
			if {[reqGetArg ${prefix}${code}$id]  == ""} {
				set result_list [lreplace $result_list [lsearch -exact $result_list $code] [lsearch -exact $result_list $code] ]
				# Removing a flag
			}
		} else {
			if {[reqGetArg ${prefix}${code}$id]  != ""} {
				lappend result_list $code
				# Adding a flag
			}
		}
	}
	return $result_list
}
#
# ----------------------------------------------------------------------------
# Language information procedures
# ----------------------------------------------------------------------------
#
proc read_language_info args {

	global DB LANG_MAP

	if {[info exists LANG_MAP]} {
		return
	}

	set lang_sql {
		select
			lang lang_id,
			name lang_name,
			disporder
		from
			tLang
		where
			status = 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $lang_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set lang_id   [db_get_col $res $i lang_id]
		set lang_name [db_get_col $res $i lang_name]
		set LANG_MAP($i,code) $lang_id
		set LANG_MAP($i,name) $lang_name
	}

	db_close $res

	set LANG_MAP(num_langs) $n_rows
}

# ----------------------------------------------------------------------------
# Procedure :   read_views_info
# Description : bind up all the
# Input :
# Output :
# Author :      JDM, 6/17/2002
# ----------------------------------------------------------------------------
proc read_view_info args {

	global DB VIEW_MAP

	if {[info exists VIEW_MAP]} {return}

	set view_sql {
		select
			view view_id,
			name view_name,
			disporder
		from
			tViewType
		where
			status = 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $view_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set view_id   [db_get_col $res $i view_id]
		set view_name [db_get_col $res $i view_name]
		set VIEW_MAP($i,code) $view_id
		set VIEW_MAP($i,name) $view_name
	}

	db_close $res
	set VIEW_MAP(num_views) $n_rows
}

# ----------------------------------------------------------------------------
# Procedure :   read_station_info
# Description : Read all active TV stations into STATION_MAP
# Input :       none
# Output :      Returns number of stations,
#               plus STATION_MAP will contain entries:
#                 STATION_MAP(num_stations)
#                 STATION_MAP($i,code)
#                 STATION_MAP($i,name)
#               where 0 <= i < num_stations
# ----------------------------------------------------------------------------
proc read_station_info {} {

	global DB STATION_MAP

	catch {unset STATION_MAP}

    set station_sql {
        select
            station_id,
            name station_name,
            disporder
        from
            tStation
        where
            status = 'A'
        order by
            disporder
    }

    set stmt [inf_prep_sql $DB $station_sql]
    set res  [inf_exec_stmt $stmt]
    inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set STATION_MAP($i,code) [db_get_col $res $i station_id]
		set STATION_MAP($i,name) [db_get_col $res $i station_name]
	}

	db_close $res
	set STATION_MAP(num_stations) $n_rows
	return $n_rows
}

#
# ----------------------------------------------------------------------------
# Type information procedures
# ----------------------------------------------------------------------------
#
proc read_type_info args {

	global DB TYPE_MAP

	if {[info exists TYPE_MAP]} {
		return
	}

	set type_sql {
		select
			code type_id,
			name type_name,
			desc type_desc
		from
			tNewsType
	}

	set stmt [inf_prep_sql $DB $type_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set type_id   [db_get_col $res $i type_id]
		set type_name [db_get_col $res $i type_name]
		set type_desc [db_get_col $res $i type_desc]
		set TYPE_MAP($i,code) $type_id
		set TYPE_MAP($i,name) $type_name
		set TYPE_MAP($i,desc) $type_desc
	}

	db_close $res

	set TYPE_MAP(num_types) $n_rows
}



proc make_language_binds {{str ""} {mask ""} {add 0} {selected CHECKED}} {

	global LANG_MAP USE_LANG_MAP

	# the selected option allows either checkboxes or dropdowns to be bound

	read_language_info

	array set USE_LANG_MAP [list]

	set c 0

	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {

		set code $LANG_MAP($i,code)

		if {$mask != "-"} {
			if {[string first $code $mask] < 0} {
				continue
			}
		}
		set USE_LANG_MAP($c,code) $code
		set USE_LANG_MAP($c,name) $LANG_MAP($i,name)

		if {([string first $code $str] >= 0) || ($add==1)} {
			set USE_LANG_MAP($c,selected) $selected
		} else {
			set USE_LANG_MAP($c,selected) ""
		}
		incr c
	}
	tpSetVar NumLangs $c

	tpBindVar LangName USE_LANG_MAP name     lang_idx
	tpBindVar LangCode USE_LANG_MAP code     lang_idx
	tpBindVar LangSel  USE_LANG_MAP selected lang_idx
}


# ----------------------------------------------------------------------------
# Procedure :   make_view_binds
# Description : bind up all the
# Input :
# Output :
# Author :      JDM, 6/17/2002
# ----------------------------------------------------------------------------
proc make_view_binds {{str ""} {mask ""} {add 0}} {

	global VIEW_MAP USE_VIEW_MAP

	read_view_info

	array set USE_VIEW_MAP [list]

	set c 0

	for {set i 0} {$i < $VIEW_MAP(num_views)} {incr i} {

		set code $VIEW_MAP($i,code)

		if {$mask != "-"} {
			if {[string first $code $mask] < 0} {
				continue
			}
		}
		set USE_VIEW_MAP($c,code) $code
		set USE_VIEW_MAP($c,name) $VIEW_MAP($i,name)

		if {[lsearch -exact $str $code] != -1 || ($add==1)} {
			set USE_VIEW_MAP($c,selected) CHECKED
		} else {
			set USE_VIEW_MAP($c,selected) ""
		}
		incr c
	}

	tpSetVar NumViews $c

	tpBindVar ViewName USE_VIEW_MAP name     view_idx
	tpBindVar ViewCode USE_VIEW_MAP code     view_idx
	tpBindVar ViewSel  USE_VIEW_MAP selected view_idx
}



# make_station_binds
#
# Input:
#   selected   - List of station codes to mark as selected
#   include    - List of station codes to include (or - for all)
#   select_all - If 1, mark all stations as selected regardless of
#                the value of selected.
# Output:
#   Returns the number of stations bound plus binds a number
#   of datasites and sets template player variable(s).
#
# Notes:
#   Based on make_language_binds etc.
#
proc make_station_binds {{selected {}} {include "-"} {select_all 0}} {

	global STATION_MAP USE_STATION_MAP

	read_station_info

	catch {unset USE_STATION_MAP}
	array set USE_STATION_MAP [list]

	set c 0

	for {set i 0} {$i < $STATION_MAP(num_stations)} {incr i} {

		set code $STATION_MAP($i,code)

		if {[lindex $include 0] != "-"} {
			if {[lsearch -exact $include $code] < 0} {
				continue
			}
		}
		set USE_STATION_MAP($c,code) $code
		set USE_STATION_MAP($c,name) $STATION_MAP($i,name)

		if {($select_all) || ([lsearch -exact $selected $code] >= 0)} {
			set USE_STATION_MAP($c,selected) CHECKED
		} else {
			set USE_STATION_MAP($c,selected) ""
		}
		incr c
	}

	tpSetVar NumStations $c

	tpBindVar StationName USE_STATION_MAP name     station_idx
	tpBindVar StationCode USE_STATION_MAP code     station_idx
	tpBindVar StationSel  USE_STATION_MAP selected station_idx

	return $c
}


proc make_language_str {{prefix LG_} {id ""}} {

	global LANG_MAP

	read_language_info

	set result ""

	set num 0

	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {
		set code $LANG_MAP($i,code)
		if {$num > 0} {
		  append result ","
		}
		append result $code
		incr num
	}
	return $result
}

# ----------------------------------------------------------------------------
# Procedure :   make_station_str
# Input :       Request Args named STATION_xxx, or, if prefix is supplied then
#               looks at Request Args named $prefix_xxx.
# Output :      List of station codes
# Notes :       Analagous to make_language_str, make_view_str etc.
# ----------------------------------------------------------------------------
proc make_station_str {{prefix STATION_}} {

	global STATION_MAP

	read_station_info

	set result [list]

	for {set i 0} {$i < $STATION_MAP(num_stations)} {incr i} {
		set code $STATION_MAP($i,code)
		if {[reqGetArg ${prefix}${code}] != ""} {
			lappend result $code
		}
	}

	return $result
}

# ----------------------------------------------------------------------------
# Procedure :   make_special_langs_list
# Input :       Request Args named SpecLang_xx, or if prefix is supplied then
#               Request Args named $prefix_xx where xx is a lang code.
# Output :      List of language codes
# Notes :       Analagous to make_language_str, make_view_str etc.
# ----------------------------------------------------------------------------
proc make_special_langs_list {{prefix MBS_LANG_}} {

	global LANG_MAP

	read_language_info

	set result [list]


	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {
		ob_log::write ERROR {MAKE LANG LIST: $LANG_MAP($i,code)}
		set code $LANG_MAP($i,code)
		if {[reqGetArg ${prefix}${code}] != ""} {
			lappend result $code
		}
	}

	ob_log::write ERROR {MAKE LANG LIST RESULT: $result}

	return $result
}

# ----------------------------------------------------------------------------
# Procedure :   make_view_str
# Input :
# Output :      views string
# Author :      JDM, 6/17/2002
# ----------------------------------------------------------------------------
proc make_view_str {{prefix V_} {id ""}} {

	global VIEW_MAP

	read_view_info

		set result [list]

		for {set i 0} {$i < $VIEW_MAP(num_views)} {incr i} {
	   		set code $VIEW_MAP($i,code)
			if {[reqGetArg ${prefix}${code}$id] != ""} {
					lappend result $code
			}
		}
		return $result
}


#
# ----------------------------------------------------------------------------
# Account/PIN number manipulation
# ----------------------------------------------------------------------------
#
proc pin_no_enc {pin} {

	if {[OT_CfgGet FUNC_ENCRYPT_PIN 1] == 0} {
		return $pin
	}

	set e [md5 $pin]
	set r ""

	foreach p {4 6 10 12 16 18 22 28} {
		append r [string index $e $p]
	}
	return $r
}


proc acct_no_enc {acct_no} {

	global ACCT_KEY


	if {$ACCT_KEY == "-" || $acct_no == ""} {
		return $acct_no
	}

	if {[string length $acct_no] == 0 || $acct_no > 16777216} {
		error "acct_no ($acct_no) out of range 1..16777216"
	}

	# dec-to-hex, swap bytes 0,2
	set h [format %06x $acct_no]
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# encrypt, hex-to-dec to get decimal account number
	scan [blowfish encrypt -hex $ACCT_KEY -hex $a] %x acct_no

	return $acct_no
}


proc acct_no_dec {acct_no} {

	global ACCT_KEY

	if {$ACCT_KEY == "-" || $acct_no == ""} {
		return $acct_no
	}

	set acct_no [string trimleft $acct_no 0]

	if {[string length $acct_no] == 0 || $acct_no > 16777216} {
		error "acct_no ($acct_no) out of range 1..16777216"
	}

	# Decrypt, return value is a hex string
	set h [blowfish decrypt -hex $ACCT_KEY -hex [format %06x $acct_no]]

	# reverse bytes 0,2
	set a [string range $h 4 5][string range $h 2 3][string range $h 0 1]

	# hex to dec
	scan $a %x acct_no

	return $acct_no
}

#
# Produces where clause string which keys on the indexed table
#
proc get_indexed_sql_query {data type {column ""} } {

	global CUST

	if {$column != "" && [info exists CUST(CUST_SEARCH_NOUPPER)]} {

		set str "$column like '$data%'"

	} else {

		set index [ob_cust::normalise_unicode $data]
		regsub -all { } $index "" index
		set index [string range $index 0 9]

		# The indexed item length is 10 so if our search string is 10 chars long, use
		# = instead of like% for performance gains. IP address also exact match .
		if {[string length $index] > 9 || $type == "ipaddr"} {
			set str "c.cust_id in (select i.cust_id from tCustIndexedId i where i.type = '$type' and i.identifier = '$index')"
		} else {
			set str "c.cust_id in (select i.cust_id from tCustIndexedId i where i.type = '$type' and i.identifier like '$index%')"
		}
	}

	OT_LogWrite 9 "get_indexed_sql_query returns:\n $str"

	return $str
}


#
# ----------------------------------------------------------------------------
# Little fiddle - don't always want to uppercase fields, especially if they
# are not in standard character sets...
# ----------------------------------------------------------------------------
#
proc upper_q v {
	global CUST
	if {[info exists CUST(CUST_SEARCH_NOUPPER)]} {
		return $v
	}
	return "upper($v)"
}


#
# ----------------------------------------------------------------------------
# Produce AH string - value should be what comes from the database
# ----------------------------------------------------------------------------
#
proc ah_string v {
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


#
# ----------------------------------------------------------------------------
# Make a handicap description for an A/H/U/L market, given the market type,
# the tag of the selection bet on, and the handicap value
# ----------------------------------------------------------------------------
#
proc mk_hcap_str {mkt_type side hcap} {
	if {$mkt_type == "A" || $mkt_type == "H" || $mkt_type == "M"} {
		if {$side == "A"} {
			set hcap [expr {0.0-$hcap}]
		}
	}
	switch -- $mkt_type {
		A -
		l {
			return [ah_string $hcap]
		}
		H -
		L -
		M -
		U {
			return $hcap
		}
	}
}


#
# ----------------------------------------------------------------------------
# parse hcap string and return a numer which should be inserted into the
# database
# ----------------------------------------------------------------------------
#
proc parse_hcap_str {hcap_str} {
	set pp [split [string trim $hcap_str] /]
	set np [llength $pp]
	if {$np < 1 || $np > 2} {
		error "$hcap_str is not a valid handicap string"
	}
	foreach p $pp {
		if {![regexp {^[+-]?[0-9]+((\.[05])?|)$} [string trim $p]]} {
			error "$hcap_str is not a valid handicap string"
		}
	}
	scan [lindex $pp 0] %f p0
	if {$np == 2} {
		scan [lindex $pp 1] %f p1
		#
		# if this was a split line, check that the 2 numbers are "next to"
		# each other
		#
		set a [expr {abs($p0-$p1)}]
		if {$a > 0.5000001 || $a < 0.4999999} {
			error "$hcap_str is not a valid handicap string"
		}
	} else {
		set p1 0.0
	}
	return [expr {(($p0+$p1)*4.0)/double($np)}]
}


#
# ----------------------------------------------------------------------------
# Generate a range-based "where" clause
# ----------------------------------------------------------------------------
#
proc mk_between_clause {col sort lo hi} {

	if {$sort == "date"} {
		if {$lo != "" && !([regexp {^(....)-(..)-(..) (..):(..):(..)$} $lo] || $lo == "CURRENT")} {
			set lo "'$lo 00:00:00'"
		} elseif {$lo != ""} {
			if {$lo == "CURRENT"} {
				set lo "$lo"
			} else {
				set lo "'$lo'"
			}
		}
		if {$hi != "" && !([regexp {^(....)-(..)-(..) (..):(..):(..)$} $hi] || $hi == "CURRENT")} {
			set hi "'$hi 23:59:59'"
		} elseif {$hi != ""} {
			if {$hi == "CURRENT"} {
				set hi "$lo"
			} else {
				set hi "'$hi'"
			}

		}
	}

	if {$lo != "" && $hi != ""} {
		return "$col between $lo and $hi"
	} elseif {$lo != ""} {
		return "$col >= $lo"
	} elseif {$hi != ""} {
		return "$col <= $hi"
	} else {
		return ""
	}
}


#
# ----------------------------------------------------------------------------
# Generic "population callback" to print a db_res row/col value
#   $res is a db_res object
#   $row is the name of a tpVar (use [tpGetVar $row] to get a row number
#   $col is the name of the column to get
# ----------------------------------------------------------------------------
#
proc sb_res_data {res row col} {
	tpBufWrite [db_get_col $res [tpGetVar $row] $col]
}

#
# ----------------------------------------------------------------------------
# Generic "null" binding
#   $html is the name of a template to play
# ----------------------------------------------------------------------------
#
proc sb_null_bind {html} {

	if {[string last ".css" $html] != -1} {
		tpBufAddHdr "Content-Type" "text/css"
	}
	asPlayFile -nocache $html
}

#
# ----------------------------------------------------------------------------
# HTML-escape a string
# ----------------------------------------------------------------------------
#
proc html_encode {value} {
	regsub -all {&} $value {\&amp;} value
	regsub -all {"} $value {\&#34;} value
	regsub -all {'} $value {\&#39;} value
	regsub -all {<} $value {\&lt;} value
	regsub -all {>} $value {\&gt;} value
	return $value
}

proc html_decode {value} {
	regsub -all {\&gt;} $value {>} value
	regsub -all {\&lt;} $value {<} value
	regsub -all {\&\#39;} $value {'} value
	regsub -all {\&\#34;} $value {"} value
	regsub -all {\&amp;} $value {&} value

	return $value
}

#
# Convert IP address to hex
#
proc ip_to_hex {ipaddr} {
	set b [split [string trim $ipaddr] .]

	foreach item $b {
		append hex [format "%02X" $item]
	}
	return $hex
}


# parray:
# Print the contents of a global array on stdout.
#
# Copyright (c) 1991-1993 The Regents of the University of California.
# Copyright (c) 1994 Sun Microsystems, Inc.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#

proc parray {a {pattern *}} {
	upvar 1 $a array
	if {![array exists array]} {
		error "\"$a\" isn't an array"
	}
	set maxl 0
	foreach name [lsort [array names array $pattern]] {
		if {[string length $name] > $maxl} {
			set maxl [string length $name]
		}
	}
	set maxl [expr {$maxl + [string length $a] + 2}]
	foreach name [lsort [array names array $pattern]] {
		set nameString [format %s(%s) $a $name]
		OT_LogWrite 1 [format "%-*s = %s" $maxl $nameString $array($name)]
	}
}


proc back_action_forward {this_action {ba_start 0}} {
	ob::log::write DEV {==>back_action_forward}
	set back_action [list]
	set prev_back_action [reqGetArg back_action]
	set prev_this_action [reqGetArg this_action]

	tpBindString this_action [list $this_action]
	ob::log::write DEV {>back_action_forward \nprev_back_action=$prev_back_action \nprev_this_action=$prev_this_action}

	if {!$ba_start} {
		if {$prev_back_action != ""} {
			set back_action $prev_back_action
		}

		if {$prev_this_action != ""} {
			lappend back_action $prev_this_action
		}
	}

	tpBindString back_action $back_action

	ob::log::write DEV {<==back_action_forward}
}

proc back_action_backward {} {
	ob::log::write DEV {==>back_action_backward}

	#
	# get the back action
	#
	set back_action [reqGetArg back_action]
	ob::log::write DEV {>back_action_backward back_action=$back_action}


	#
	# If we have a back action then carry it out!
	#
	if {$back_action != ""} {

		set this_action [lindex $back_action e]

		tpBindString this_action $this_action
		tpBindString back_action [lreplace $back_action e e]

		set this_action [lindex $this_action 0]

		set action [lindex $this_action 0]

		foreach { name value } [lrange $this_action 1 e] {
			reqSetArg $name $value
		}

		eval $action

		return [list 1]

	} else {
		return [list 0]
	}


	return [list 1]
	ob::log::write DEV {<==back_action_backward}
}

proc back_action_refresh {{new_this_action ""}} {

	if {$new_this_action == ""} {
		tpBindString back_action [reqGetArg back_action]
		tpBindString this_action [reqGetArg this_action]
	} else {
		tpBindString back_action [reqGetArg back_action]
		tpBindString this_action [list $new_this_action]
	}
}

# ========================================================================
# Print array
# ========================================================================

proc array_print { array_name } {

    upvar 1 $array_name array_name_local

    set datalist [lsort [array names array_name_local]]

    OT_LogWrite 1 "======================"
    OT_LogWrite 1 "Printing contents of $array_name:"

    for {set i 0} {$i < [llength $datalist]} {incr i 1} {
     OT_LogWrite 1 "          ${array_name}([lindex $datalist $i]) = $array_name_local([lindex $datalist $i])"
    }

    OT_LogWrite 1 "======================"
}

# =====================================================================
# generate a CSV from a results set

# Robbed from campaign_manager/cm/tcl/utilities.tcl (rev 1.42)
# =====================================================================
proc build_csv_from_rs { header_names column_names rs {filename "report"}} {

	tpBufDelHdr Content-Type
	tpBufAddHdr Content-Type        "text/comma-separated-values"
	tpBufAddHdr Content-Disposition "attachment; filename=${filename}.csv"

	# first check for an error
	if {[tpGetVar IsError 0]} {
		tpBufWrite [tpBindGet ErrMsg]\n
		return
	}

	# write the header names
	tpBufWrite [csv::join $header_names]\n

	# write the data rows
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i<$nrows} {incr i} {
		set row [list ]

		foreach col $column_names {
			lappend row [db_get_col $rs $i $col]
		}

		tpBufWrite [csv::join $row]\n
	}
}

# ============================================================================
# generate a CSV file from an array.
# Robbed from campaign_manager/cm/tcl/utilities.tcl (rev 1.42)

# a simple utility to write a csv http response given an array
#
# First line is a comma sep. lines of header names
# Subsequent lines are comma sep. lines of column values
#
# It *does* set the http headers and an optional arg can specify the filename
# ============================================================================
proc build_csv_from_array {header_names column_names array_name nrows {filename "report"}} {
	upvar $array_name RESULTS

	# change the html headers
	tpBufDelHdr Content-Type
	tpBufAddHdr Content-Type        "text/comma-separated-values"
	tpBufAddHdr Content-Disposition "attachment; filename=${filename}.csv;"

	# first check for an error
	if {[tpGetVar IsError 0]} {
		tpBufWrite [tpBindGet ErrMsg]\n
		return
	}

	# write the header names
	tpBufWrite [csv::join $header_names]\n

	for {set i 0} {$i < $nrows} {incr i} {
		set row [list ]

		foreach col $column_names {
			lappend row $RESULTS($i,$col)
		}

		tpBufWrite [csv::join $row]\n
	}
}


#binds all categories from tEvCategory
# is mix is used to break the category into smaller categories
# brk_list provides the alternatives to use.
# ex { RACING {GR Dogs HR Horses  } }
proc make_category_binds {{ is_mix 0 } { brk_list } {order_by_disp ""}} {

	global DB CATGR_MAP

	set order_by ""

	if {$order_by_disp != 0} {
		set order_by "order by disporder"
	}

	set sql [subst {
		select
			category
		from
			tEvCategory
		$order_by
	}]


	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set idx 0

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		if { $is_mix } {
			set catIndx [lsearch $brk_list [db_get_col $res $i category]]
			if {$catIndx != -1} {
				foreach {c v} [lindex $brk_list [expr {$catIndx + 1}]] {
					set CATGR_MAP($idx,category_name) $v
					set CATGR_MAP($idx,category_code) $c
					incr idx
				}
			} else {
				set CATGR_MAP($idx,category_name) [db_get_col $res $i category]
				set CATGR_MAP($idx,category_code) [db_get_col $res $i category]
				incr idx
			}
		} else {
			set CATGR_MAP($idx,category_name) [db_get_col $res $i category]
			set CATGR_MAP($idx,category_code) [db_get_col $res $i category]
			incr idx
		}
	}

	tpSetVar NumCategories $idx
	tpBindVar CategoryName CATGR_MAP category_name cat_idx
	tpBindVar CategoryCode CATGR_MAP category_code cat_idx

	GC::mark CATGR_MAP
}


proc make_region_binds args {

	global REGIONS
	global DB

	GC::mark REGIONS

	set sql {
		select
			region_id,
			name
		from
			tRegion
		where
			status = 'A'
	}

	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows } {incr i} {
		set REGIONS($i,region_id) [db_get_col $res $i region_id]
		set REGIONS($i,name)      [string map {' \\'} [db_get_col $res $i name]]
	}

	tpSetVar NumRegions $nrows

	tpBindVar RegionId    REGIONS region_id reg_idx
	tpBindVar RegionName  REGIONS name      reg_idx

	catch {db_close $res}

}

proc make_class_type_sort_binds args {

	global DB CLASS TYPE SORT
	catch {unset CLASS}
	catch {unset TYPE}
	catch {unset SORT}

	set sql [subst {
		select
			c.ev_class_id,
			c.name cname,
			c.sort,
			c.displayed cdisp,
			c.disporder cdispo,
			t.ev_type_id,
			t.name tname,
			t.displayed tdisp,
			t.disporder tdispo,
			upper(c.name) as upcname,
			upper(t.name) as uptname
		from
			tEvClass c,
			tEvType t
		where
			c.ev_class_id = t.ev_class_id
		order by
			c.displayed desc,
			upcname asc,
			c.ev_class_id,
			t.displayed desc,
			tdispo asc,
			uptname asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set c_ix       -1
	set c_class_id -1

	for {set r 0} {$r < $rows} {incr r} {

		set class_id [db_get_col $res $r ev_class_id]
		set type_id  [db_get_col $res $r ev_type_id]
		set cname    [db_get_col $res $r cname]
		set tname    [db_get_col $res $r tname]
		set sort     [db_get_col $res $r sort]

		if {$class_id != $c_class_id} {
			incr c_ix
			set CLASS($c_ix,id)    $class_id
			set CLASS($c_ix,name)  [remove_tran_bars $cname]
			set CLASS($c_ix,sort)  $sort
			set CLASS($c_ix,types) 0
			set c_class_id $class_id
		}

		set t_ix $CLASS($c_ix,types)

		set TYPE($c_ix,$t_ix,id)   $type_id
		set TYPE($c_ix,$t_ix,name) [remove_tran_bars $tname]
		set SORT($r,type)          $type_id
		set SORT($r,sort)          $sort

		incr CLASS($c_ix,types)
	}

	tpSetVar NumClasses [expr {$c_ix+1}]
	tpSetVar NumSorts   $rows

	tpBindVar ClassId   CLASS id   class_idx
	tpBindVar ClassName CLASS name class_idx
	tpBindVar ClassSort CLASS sort class_idx
	tpBindVar Types     CLASS types class_idx
	tpBindVar TypeId    TYPE  id   class_idx type_idx
	tpBindVar TypeName  TYPE  name class_idx type_idx
	tpBindVar SortType  SORT  type sort_idx
	tpBindVar TypeSort  SORT  sort sort_idx

	db_close $res

}



# Bind up details of all active currencies
#
proc make_ccy_binds {} {

	global DB
	global CCY

	GC::mark CCY

	# load active currencies
	set stmt [inf_prep_sql $DB {
		select
			ccy_code,
			ccy_name,
			disporder
		from
			tCcy
		where
			status = 'A'
		order by
			disporder
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set CCY($i,ccy_code)   [db_get_col $res $i ccy_code]
		set CCY($i,ccy_name)   [db_get_col $res $i ccy_name]
	}

	tpSetVar NumCCYs $nrows

	tpBindVar CCYCode    CCY      ccy_code  ccy_idx
	tpBindVar CCYName    CCY      ccy_name  ccy_idx

	db_close $res

}



# Bind the complete list of available BIR templates
#	- template id
#		ID of template to have SELECTED value
#
proc make_template_binds {{template_id ""}} {
	global DB TEMPL

	set sql [subst {

	select
		template_id,
		name
	from
		tBirTemplate
	order by
		name desc

	}]

	if {$template_id == ""} {
		if {[reqGetArg SelTemplate] == ""} {
			set sel_templ_id "--"
		} else {
			set sel_templ_id [reqGetArg SelTemplate]
		}
	} else {
		set sel_templ_id $template_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	array set TMPL [list]

	set index 0
	for {set r 0} { $r < [db_get_nrows $rs]} {incr r} {
		set TEMPL($index,template_id) [db_get_col $rs $r template_id]
		set TEMPL($index,name) [db_get_col $rs $r name]


		if {$TEMPL($index,template_id) == $sel_templ_id} {
			set TEMPL($index,selected) "SELECTED"
		} else {
			set TEMPL($index,selected) ""
		}

		incr index
	}

	tpBindVar   templ_Id        TEMPL  template_id   templ_idx
	tpBindVar   templ_Name      TEMPL  name          templ_idx
	tpBindVar   templ_DispOrder TEMPL  display_order templ_idx
	tpBindVar   templ_Selected  TEMPL  selected      templ_idx

	tpSetVar NumberTemplates $index

}

proc make_stmt_prod_filter_bind {} {

	global PROD_FILTER

	set products [OT_CfgGet STATEMENTS_PROD_FILTERS [list]]

	set i 0
	foreach {code name} $products {
		set PROD_FILTER($i,code) $code
		set PROD_FILTER($i,desc) $name
		incr i
	}

	tpBindVar prod_code PROD_FILTER code prod_idx
	tpBindVar prod_desc PROD_FILTER desc prod_idx

	tpSetVar num_product_filters $i
}



proc play_pdf {pdf_filename} {

	# Delete the content-type header if it exists
	catch {tpBufDelHdr "Content-Type"}

	set pdf [open $pdf_filename r]

	fconfigure $pdf -translation binary
	set f [read $pdf]

	tpBufAddHdr "Content-Type" "application/pdf;charset=utf-8"
	tpBufAddHdr "Content-Disposition" "attachment;filename=$pdf_filename;"

	tpBufWrite $f

	close $pdf
}

proc get_current_db_time {} {

        global DB

        set sql {
                select
                        extend(CURRENT,year to second) curr_dt
                from
                        tControl
        }
        set stmt [inf_prep_sql $DB $sql]
        set rs [inf_exec_stmt $stmt]
        inf_close_stmt $stmt

        if {[db_get_nrows $rs] == 0} {
                db_close $rs
                error "Failed to get current db time"
        }

        set curr_dt [db_get_col $rs 0 curr_dt]

        db_close $rs

        return $curr_dt
}


# remove any "|" characters that may surround words, indicating
# that they're translatable.  This does it properly, removing
# all such bars, rather than just the first and the last.
proc remove_tran_bars {tran} {

	if {[OT_CfgGet RMV_PIPES_FROM_EV_SEL 0]} {
		set map  [list "|" ""]
		set tran [string map $map $tran]
	}

	return $tran
}


#
# make_channel_mask: makes a mask to be passed into make_channel_binds below.
# The mask contains the channels that WILL be bound.  exclude is a string
# containing all the channels (space seperated) that are not to be bound up.
# include is a string containing any channels that must be bound.  This is a
# little redundant though as all the channels except those in exclude will be bound.
#
proc make_channel_mask { {exclude ""} {include ""} } {

	global CHANNEL_MAP

	read_channel_info

	set mask [list]

	for {set i 0} {$i < $CHANNEL_MAP(num_channels)} {incr i} {
		if {[lsearch $exclude $CHANNEL_MAP($i,code)] == -1} {
			lappend mask $CHANNEL_MAP($i,code)
		}
	}

	for {set i 0} {$i < [llength $include]} {incr i} {
		lappend mask [lindex $include $i]
	}

	return $mask
}




#
# ----------------------------------------------------------------------------
# Private procedure to bind language list for dropdown
# ----------------------------------------------------------------------------
#
proc _bind_lang_dropdown { {def_lang ""} } {

	variable SPLANG

	set lang_sql {
		select
			lang lang_id,
			name lang_name,
			locale lang_locale
		from
			tLang
		where
			status = 'A'
		order by
			lang
	}

	set stmt [inf_prep_sql $::DB $lang_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumLangs [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set lang_id                 [db_get_col $res $r lang_id]
		set SPLANG($r,lang_id)      $lang_id
		set SPLANG($r,lang_name)    [db_get_col $res $r lang_name]
		set SPLANG($r,lang_locale)  [db_get_col $res $r lang_locale]
		if { $lang_id == $def_lang } {
			set SPLANG($r,lang_sel) {selected="selected"}
		}
	}

	tpBindVar LangId     SPLANG lang_id     lang_idx
	tpBindVar LangName   SPLANG lang_name   lang_idx
	tpBindVar LangLocale SPLANG lang_locale lang_idx
	tpBindVar LangSel    SPLANG lang_sel    lang_idx

	GC::mark SPLANG

	db_close $res

}

#
# ----------------------------------------------------------------------------
# Private procedure to bind view list for dropdown
# ----------------------------------------------------------------------------
#
proc _bind_view_dropdown { {def_view ""} } {

	variable SPVIEW

	set view_sql {
		select
			view,
			name
		from
			tViewType
		where
			status = 'A'
		order by
			name
	}

	set stmt [inf_prep_sql $::DB $view_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumViews [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set view_id               [db_get_col $res $r view]
		set SPVIEW($r,view_id)    $view_id
		set SPVIEW($r,view_name)  [db_get_col $res $r name]
		if { $view_id == $def_view } {
			set SPVIEW($r,view_sel) {selected="selected"}
		}
	}

	tpBindVar ViewId   SPVIEW view_id   view_idx
	tpBindVar ViewName SPVIEW view_name view_idx
	tpBindVar ViewSel  SPVIEW view_sel  view_idx

	GC::mark SPVIEW

	db_close $res

}


#
# ----------------------------------------------------------------------------
# Private procedure to bind locale list for dropdown
# ----------------------------------------------------------------------------
#
proc _bind_locale_dropdown { {def_locale ""} } {

	variable SPLOCALE

	set locale_sql {
		select
			locale locale_code,
			name locale_name
		from
			tLangMenu
		where
			status = 'A'
		order by
			name
	}

	set stmt [inf_prep_sql $::DB $locale_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumLocales [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set locale_code              [db_get_col $res $r locale_code]
		set SPLOCALE($r,locale_code) $locale_code
		set SPLOCALE($r,locale_name) [db_get_col $res $r locale_name]
		if { $locale_code == $def_locale } {
			set SPLOCALE($r,locale_sel) {selected="selected"}
		}
	}

	tpBindVar LocaleCode SPLOCALE locale_code locale_idx
	tpBindVar LocaleName SPLOCALE locale_name locale_idx
	tpBindVar LocaleSel  SPLOCALE locale_sel  locale_idx

	GC::mark SPLOCALE

	db_close $res

}


#
# Bind Customer codes for dropdowns
#
proc _bind_customer_codes {} {

	variable CUST_CODES
	# Preload Customer codes
	set stmt [inf_prep_sql $::DB {
		select
			cust_code,
			desc
		from
			tCustCode
		order by
			cust_code
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCCode [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set CUST_CODES($r,cust_code) [db_get_col $res $r cust_code]
		set CUST_CODES($r,desc)      [db_get_col $res $r desc]
	}

	tpBindVar CCCode CUST_CODES cust_code ccc_idx
	tpBindVar CCDesc CUST_CODES desc ccc_idx

	GC::mark CUST_CODES
	db_close $res
}






#
# Set the special that applies to an event hierachy object.
#
# Takes:
#
#   level
#     The level of the event hierarchy object (must be TYPE, GROUP or EVENT).
#
#   id
#     The ev_type_id, ev_oc_grp_id or ev_id of the object depending on level.
#
#   special_type
#     The type of special that applies, or "" for none.
#
#   special_langs
#     The list of language codes in which the special is available.
#     Ignored if special_type is "".
#
#   no_existing_special
#     Set to 1 if you are sure the event hierarchy object has no existing
#     special (e.g. if you've just created the object).
#
#   do_transaction
#     Set to 0 if the caller has already started a transaction, otherwise
#     set to 1 in which case this function may use its own transaction.
#
#   recurse
#     Set to 0 if we don't want to filter changes up/down (see below for the
#       associate rules that apply) between event and market level
#     Set to 1 if we want so.
#
# Returns:
#
#   1 on success, throws an error otherwise (e.g. DB error).
#
# Notes:
#
#   * Does not currently attempt to guard against race conditions with other
#     entities attempting to update the special on the same object. This
#     should not be a problem provided this function is called immediately
#     after inserting or updating the object in the same transaction, since
#     the object will act as a lock.
#
#   * There can only be one special per object - you cannot have e.g. an MBS
#     special for English customers and an EP special for Germans.
#
proc update_special_type {level id special_type special_langs\
			 {no_existing_special 0} {do_transaction 1}\
			 {recurse 1} } {

	global DB

	if {$level == "MARKET" && $recurse} {

		set sql {
			select
				ev_id
			from
				tEvMkt
			where
				ev_mkt_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $id]
		# there must be only one ev_id
		set ev_id [db_get_col $rs 0 ev_id]

		# if the associated event hasn't got the same special type selected,
		# need to update it to have so.
		foreach {ev_special_type ev_special_langs} [find_special EVENT $ev_id] {}

		if {$ev_special_type != $special_type && $special_type != ""} {
			update_special_type EVENT $ev_id $special_type $special_langs 0 0 0
		}

		inf_close_stmt $stmt
		db_close $rs
	}

	if {$level == "EVENT" && $recurse} {
		# If EVENT special type is MBS and changes to None or EPS, then
		# update all markets that have the MBS special type to None.
		if {$special_type != "MBS"} {
			set sql {
				select
					ev_mkt_id
				from
					tEvMkt
				where
					ev_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set rs  [inf_exec_stmt $stmt $id]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				set mkt_id [db_get_col $rs $i ev_mkt_id]
				update_special_type MARKET $mkt_id "" $special_langs 0 0 0
			}

			inf_close_stmt $stmt
			db_close $rs
		}
	}


	if {$special_type == ""} {
		if {$no_existing_special} {
			ob_log::write WARNING {update_special_type: no special and no existing special; doing nothing.}
			return 1
		} else {
			ob_log::write WARNING {update_special_type: no special but might be an existing special; deleting entries.}

			set sql {
				select
					lang,
					special_type
				from
					tSpecialOffer
				where
						level = ?
					and id    = ?
			}
			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $level $id]


			if {[db_get_nrows $rs] > 0} {
				# Checks if the user has MBS permisions
				if {![op_allowed ManageMBS 0]} {
					ob_log::write INFO "Failed MBS permisions"
					err_bind "You don't have permission to update Moneyback Specials"
					return 0
				}
			}
			set sql {
				delete
				from
					tSpecialOffer
				where
					level = ? and
					id    = ?
			}
			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt $level $id
			inf_close_stmt $stmt
			return 1
		}
	} else {
		# Compute the set of languages for which we must insert this special,
		# the set of languages which need their special type updating, and
		# the set of languages for which we must remove the special.
		if {$no_existing_special} {
			set ins_langs $special_langs
			set upd_langs [list]
			set del_langs [list]
		} else {
			foreach lang $special_langs {
				set SpecialLangs($lang) 1
			}
			set ins_langs [list]
			set upd_langs [list]
			set del_langs [list]
			ob_log::write WARNING {update_special_type: checking for existing special ($special_langs)}
			set sql {
				select
					lang,
					special_type
				from
					tSpecialOffer
				where
						level = ?
					and id    = ?
			}
			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $level $id]
			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				set exist_lang [db_get_col $rs $i lang]
				set exist_type [db_get_col $rs $i special_type]
				set ExistingSpecialLangs($exist_lang) 1
				if {[info exists SpecialLangs($exist_lang)]} {
					if {$special_type != $exist_type} {
						lappend upd_langs $exist_lang
					}
				} else {
					lappend del_langs $exist_lang
				}
			}
			inf_close_stmt $stmt
			db_close $rs
			foreach lang $special_langs {
				if {![info exists ExistingSpecialLangs($lang)]} {
					lappend ins_langs $lang
				}
			}
		}
		# Count the changes needed
		set num_ops [expr {
			[llength $ins_langs] + \
			[llength $upd_langs] + \
			[llength $del_langs] }]
		if {$num_ops == 0} {
			ob_log::write WARNING {update_special_type: no changes required}
			return 1
		}
		# Checks if the user has MBS permisions
		if {![op_allowed ManageMBS 0]} {
			ob_log::write INFO "Failed MBS permisions"
			err_bind "You don't have permission to update Moneyback Specials"
			return 0
		}


		ob_log::write WARNING {update_special_type: inserting special for langs ([join $ins_langs ,]), updating special for langs ([join $upd_langs ,]) and deleting special for langs ([join $del_langs ,]).}
		# No point doing a transaction if only one change
		if {$num_ops > 1 && $do_transaction} {
			set began_transaction 1
			inf_begin_tran $DB
		} else {
			set began_transaction 0
		}
		# Apply the change(s)
		if {[catch {
			if {[llength $ins_langs]} {
				set sql {
					insert into tSpecialOffer (
						level,
						id,
						lang,
						special_type
					) values (?,?,?,?)
				}
				set ins_stmt [inf_prep_sql $DB $sql]
				foreach lang $ins_langs {
					inf_exec_stmt $ins_stmt $level $id $lang $special_type
				}
				inf_close_stmt $ins_stmt
			}
			if {[llength $upd_langs]} {
				set sql {
					update tSpecialOffer set
						special_type = ?
					where
						    level = ?
						and id    = ?
						and lang  = ?
				}
				set upd_stmt [inf_prep_sql $DB $sql]
				foreach lang $upd_langs {
					inf_exec_stmt $upd_stmt $special_type $level $id $lang
				}
				inf_close_stmt $upd_stmt
			}
			if {[llength $del_langs]} {
				set sql {
					delete from tSpecialOffer
					where
						    level = ?
						and id    = ?
						and lang  = ?
				}
				set del_stmt [inf_prep_sql $DB $sql]
				foreach lang $del_langs {
					inf_exec_stmt $del_stmt $level $id $lang
				}
				inf_close_stmt $del_stmt
			}
		} msg]} {
			ob_log::write ERROR {update_special_type: Failed to update special for $level #$id to special type '$special_type' in langs ([join $special_langs ,]): $msg}
			if {$began_transaction} {
				inf_rollback_tran $DB
			}
			# Re-throw error
			error "update_special_type: $msg"
		}
		if {$began_transaction} {
			inf_commit_tran $DB
		}
		ob_log::write INFO {update_special_type: $level #$id now has special type '$special_type' in langs ([join $special_langs ,])}
		return 1
	}
}



# Check for a special offer on an event hierarchy object, and if there is one,
# see what type it is and enumerate the languages in which it is available.
#
# Takes the level of the event hierarchy object (must be TYPE, GROUP or EVENT)
# and the ev_type_id, ev_oc_grp_id or ev_id of the object depending on level.
#
# Returns a list of the form {special_type special_langs} where special_langs
# is a list of language codes. If there is no special available on the given
# event hierarchy object, special_type will be the empty string.
#
proc find_special {level id} {

	global DB

	# Assume none
	set special_type ""
	set special_langs [list]

	set sql {
		select
			s.lang,
			s.special_type
		from
			tSpecialOffer s
		where
			    s.level = ?
			and s.id    = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt $level $id]
	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		if {$special_type == ""} {
			set special_type [db_get_col $rs $i special_type]
		} else {
			# The special type is expected to be the same for all languages
			# in which the special is available.
			if {$special_type != [db_get_col $rs $i special_type]} {
				ob_log::write WARNING {find_special: WARNING - multiple special types found for $level #$id; ignoring this special}
				return [list "" [list]]
			}
		}
		lappend special_langs [db_get_col $rs $i lang]
	}
	db_close $rs

	return [list $special_type $special_langs]
}


#
# Split <str> into one or more pieces, with the length of each
# piece no greater than <piecelen> when measured in bytes.
#
# If <max_pieces> is non-blank then at most <max_pieces> pieces
# will be returned. If this is not possible (i.e. <str> is too long)
# then an error will be returned.
#
# The <trailing_spaces> argument controls whether the piece(s) may
# end in space (ASCII 0x20) characters. This is important if the
# piece(s) will be stored in Informix CHAR fields since subsequent
# retrieval is likely to remove any trailing space.
#
# It may take the following values:
#
# <trailing_space>   Meaning
#
# Y                  The piece(s) may end in spaces.
#
# N                  The piece(s) may never end in spaces. An error
#                    will be returned if this is unavoidable.
#
# M                  The piece(s) will end in spaces only if <str>
#                    could not otherwise be accomodated in <max_pieces>
#                    pieces or fewer.
#
# Note that if <trailing_space> is N or M, trailing spaces will be
# stripped from <str> prior to splitting.
#
proc split_to_pieces {piecelen str max_pieces trailing_space} {

	# Sanity checks

	if {$max_pieces != "" && \
		(![string is integer -strict $max_pieces] || $max_pieces < 1)} {
		error "max_pieces must be blank or at least 1"
	}

	if {[lsearch [list Y M N] $trailing_space] == -1} {
		error "trailing_space must be one of Y,M or N"
	}

	# Quick check on length first.
	# Note that we can still run out of room later since a piece
	# will be less than <piecelen> bytes if:
	#  a) we cannot fit a multibyte character in at the end of the piece
	# or
	#  b) we have had to move spaces to the start of the
	#     next piece to meet the <trailing_space> requirement.

	if {$max_pieces != ""} {
		if {[string bytelength $str] > ($piecelen * $max_pieces)} {
			error "string too long ([string bytelength $str] bytes)"
		}
	}

	# If <trailing_space> is M, recurse with a <trailing_space> of N
	# first, and if that fails try again with a <trailing_space> of Y.

	if {$trailing_space == "M"} {

		if {[catch {
			set pieces [split_to_pieces $piecelen $str $max_pieces N]
		}]} {
			set str [string trimright $str " "]
			set pieces [split_to_pieces $piecelen $str $max_pieces Y]
		}

		return $pieces

	}

	# If we have restrictions on trailing space in output
	# then strip any trailing space in input.

	if {$trailing_space == "N"} {

		set str [string trimright $str " "]
	}

	# List of pieces to return

	set pieces [list]

	# Current piece we are building up

	set piece ""

	# Whether we had to move spaces to prevent
	# them trailing

	set moved_spaces 0

	# Loop over characters in <str>

	foreach c [split $str {}] {

		set c_b [string bytelength $c]
		set p_b [string bytelength $piece]

		# Is there room to add this character?

		if {$p_b + $c_b <= $piecelen} {

			append piece $c

		} else {

			# No more room, so start new piece.

			# Check first whether we've hit <max_pieces> yet

			if {$max_pieces != "" && [llength $pieces] == $max_pieces} {
				set msg "unable to fit string into $max_pieces \
					   of length $piecelen bytes"
				if {$moved_spaces} {
					append msg " without leaving trailing spaces"
				}
				error $msg
			}

			if {$trailing_space == "Y"} {

				lappend pieces $piece
				set piece $c

			} else {

				# We must not leave spaces at the end of our current piece
				# since they will get stripped on retrieval.

				if {[regexp {^[ ]*$} $piece]} {

					# However, in this case there's not much we can do since the
					# whole piece consists of space.
					error "unable to split string without creating pieces with trailing space"

				} else {

					# Move trailing space into start of new piece

					set spaces {}
					while {[string index $piece end] == " "} {
						append spaces [string index $piece end]
						set piece [string range $piece 0 end-1]
					}

					if {[string length $spaces] > 0} {
						set moved_spaces 1
					}

					lappend pieces $piece
					set piece $spaces
					append piece $c

				}

			}

		}
	}

	# Need not check for trailing space in the last piece
	# since if <trailing_space> was N, we removed any
	# trailing space from the input earlier.

	if {[string length $piece] > 0} {
		lappend pieces $piece
	}

	# However, we should check if we've exceeded <max_pieces>.

	if {$max_pieces != "" && [llength $pieces] > $max_pieces} {
		set msg "unable to fit string into $max_pieces \
			   of length $piecelen bytes"
		if {$moved_spaces} {
			append msg " without leaving trailing spaces"
		}
		error $msg
	}


	return $pieces
}

