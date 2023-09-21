# $Id: dates.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#  ==============================================================
#
# (c) 2000 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

set Months(en) [list xxx Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]
set Months(tv) [list xxx Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

set Months(th) [list xxx {&#3617;.&#3588;.} {&#3585;.&#3614;.} {&#3617;&#3637;.&#3588;.} {&#3648;&#3617;.&#3618;.} {&#3614;.&#3588;.} {&#3617;&#3636;.&#3618;.} {&#3585;.&#3588;.} {&#3626;.&#3588;.} {&#3585;.&#3618;.} {&#3605;.&#3588;.} {&#3614;.&#3618;.} {&#3608;.&#3588;.}]
set Months(cn) [list xxx {一月} {二月} {三月} {四月} {五月} {六月} {七月} {八月} {九月} {十月} {十一月} {十二月}]
set Months(sw) [list xxx jan feb mar apr maj jun jul aug sep okt nov dec]
set Months(es) [list xxx Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic]
set Months(it) [list xxx Gen Feb Mar Apr Mag Giu Lug Ago Set Ott Nov Dic]

set MonthDays  [list   0  31  28  31  30  31  30  31  31  30  31  30  31]

set FullMonths(en) [list\
	xxx\
	January\
	February\
	March\
	April\
	May\
	June\
	July\
	August\
	September\
	October\
	November\
	December]

set FullMonths(tv) [list\
	xxx\
	January\
	February\
	March\
	April\
	May\
	June\
	July\
	August\
	September\
	October\
	November\
	December]

set FullMonths(th) [list\
	xxx\
	{&#3617;&#3585;&#3619;&#3634;&#3588;&#3617;}\
	{&#3585;&#3640;&#3617;&#3616;&#3634;&#3614;&#3633;&#3609;&#3608;&#3660;}\
	{&#3617;&#3637;&#3609;&#3634;&#3588;&#3617;}\
	{&#3648;&#3617;&#3625;&#3634;&#3618;&#3609;}\
	{&#3614;&#3620;&#3625;&#3616;&#3634;&#3588;&#3617;}\
	{&#3617;&#3636;&#3606;&#3640;&#3609;&#3634;&#3618;&#3609;}\
	{&#3585;&#3619;&#3585;&#3598;&#3634;&#3588;&#3617;}\
	{&#3626;&#3636;&#3591;&#3627;&#3634;&#3588;&#3617;}\
	{&#3585;&#3633;&#3609;&#3618;&#3634;&#3618;&#3609;}\
	{&#3605;&#3640;&#3621;&#3634;&#3588;&#3617;}\
	{&#3614;&#3620;&#3624;&#3592;&#3636;&#3585;&#3634;&#3618;&#3609;}\
	{&#3608;&#3633;&#3609;&#3623;&#3634;&#3588;&#3617;}]

set FullMonths(sw) [list\
	xxx\
	januari\
	februari\
	mars\
	april\
	maj\
	juni\
	juli\
	augusti\
	september\
	oktober\
	november\
	december]

set FullMonths(cn) [list\
	xxx\
	一月\
	二月\
	三月\
	四月\
	五月\
	六月\
	七月\
	八月\
	九月\
	十月\
	十一月\
	十二月]

set FullMonths(es) [list\
	xxx\
	Enero\
	Febrero\
	Marzo\
	Abril\
	Mayo\
	Junio\
	Julio\
	Agosto\
	Septiembre\
	Octubre\
	Noviembre\
	Diciembre]

set FullMonths(it) [list\
	xxx\
	Gennaio\
	Febbraio\
	Marzo\
	Aprile\
	Maggio\
	Giugno\
	Luglio\
	Agosto\
	Settembre\
	Ottobre\
	Novembre\
	Dicembre]

set FullDays(it,Monday) 	"Lunedi"
set FullDays(it,Tuesday) 	"Martedi"
set FullDays(it,Wednesday) 	"Mercoledi"
set FullDays(it,Thursday) 	"Giovedi"
set FullDays(it,Friday) 	"Venerdi"
set FullDays(it,Saturday) 	"Sabato"
set FullDays(it,Sunday) 	"Domenica"

set FullDays(es,Monday) 	"Lunes"
set FullDays(es,Tuesday) 	"Martes"
set FullDays(es,Wednesday) 	"Miercoles"
set FullDays(es,Thursday) 	"Jueves"
set FullDays(es,Friday) 	"Viernes"
set FullDays(es,Saturday) 	"Sabado"
set FullDays(es,Sunday) 	"Domingo"

set FullDays(sw,Monday) 	"M幩dag"
set FullDays(sw,Tuesday) 	"Tisdag"
set FullDays(sw,Wednesday) 	"Onsdag"
set FullDays(sw,Thursday) 	"Torsdag"
set FullDays(sw,Friday) 	"Fredag"
set FullDays(sw,Saturday) 	"L顤dag"
set FullDays(sw,Sunday) 	"S霵dag"

set FullDays(th,Monday) 	"&#3623;&#3633;&#3609;&#3592;&#3633;&#3609;&#3607;&#3619;&#3660;"
set FullDays(th,Tuesday)    "&#3623;&#3633;&#3609;&#3629;&#3633;&#3591;&#3588;&#3634;&#3619;"
set FullDays(th,Wednesday)  "&#3623;&#3633;&#3609;&#3614;&#3640;&#3608;"
set FullDays(th,Thursday)   "&#3623;&#3633;&#3609;&#3614;&#3620;&#3627;&#3633;&#3626;&#3610;&#3604;&#3637;"
set FullDays(th,Friday)   "&#3623;&#3633;&#3609;&#3624;&#3640;&#3585;&#3619;&#3660;"
set FullDays(th,Saturday) "&#3623;&#3633;&#3609;&#3648;&#3626;&#3634;&#3619;&#3660;"
set FullDays(th,Sunday)   "&#3623;&#3633;&#3609;&#3629;&#3634;&#3607;&#3636;&#3605;&#3618;&#3660;"

#======================================================================
# Generate <option> tags for select lists for date drop-downs
#

proc openbet_func_pop_date_menus {type} {

	set secs [clock seconds]

	if {[string range $type end end] == "1"} {
		set secs [expr $secs - (7*24*60)]
	}

	openbet_func_pop_date_menus_at_time [string toupper \
		[string range $type 2 [expr [string length $type] -1]]] \
		$secs
}

proc openbet_func_pop_date_menus_at_time {type secs {year_begin 1998}} {
	global Months
	global LANG

	if {![info exists LANG]} {
		set LANG en
	}

	set dt [clock format $secs -format "%Y-%m-%d"]

	foreach {y m d} [split $dt -] {

		set y [string trimleft $y 0]
		set m [string trimleft $m 0]
		set d [string trimleft $d 0]

		set this_year [clock format [clock seconds] -format "%Y"]
	}

	if {$type == "DAY"} {
		for {set i 1} {$i <= 31} {incr i} {
			if {$i == $d} {
				tpBufWrite "<option value=$i selected>$i</option>\n"
			} else {
				tpBufWrite "<option value=$i>$i</option>\n"
			}
		}
	}
	if {$type == "MONTH"} {
		for {set i 1} {$i <= 12} {incr i} {

			# either use the arrays above or dig the translation out of the db?
			if [OT_CfgGet DATES_USE_MONTH_MSG_XL 0] {
				# get the english translation to build up the msg code...
				set name [string toupper [lindex $Months(en) $i]]
				set mon  [OB_mlang::ml_printf "OB_MONTH_$name"]

			} else {
				if {[info exists $Months($LANG)]} {
					set mon [lindex $Months($LANG) $i]
				} else {
					set mon [lindex $Months(en) $i]
				}
			}

			if {$i == $m} {
				tpBufWrite "<option value=$i selected>$mon</option>\n"
			} else {
				tpBufWrite "<option value=$i>$mon</option>\n"
			}
		}
	}
	if {$type == "YEAR"} {
		for {set i $year_begin} {$i <= $this_year} {incr i} {
			if {$i == $y} {
				tpBufWrite "<option value=$i selected>$y</option>\n"
			} else {
				tpBufWrite "<option value=$i>$i</option>\n"
			}
		}
	}
}

#
# Get the correct two letter suffix for a month day
#
proc day_sfx day {
	switch -- $day {
		1       -
		21      -
		31      {set sfx st}
		2       -
		22      {set sfx nd}
		3       -
		23      {set sfx rd}
		default {set sfx th}
	}
	return $sfx
}

#
# Get number of days in a month
#
proc days_in_month {m y} {
	global MonthDays

	regsub {^0+(\d)} $m {\1} m

	# is year a leap year ? (sloppy, but good for a century or so)
	if {($m == 2) && ($y % 4 == 0)} {
		return 29
	}
	return [lindex $MonthDays $m]
}

#
# Given an informix date, YYYY-MM-DD HH:MM:SS, produce a full date string
#
proc html_date {dt {style time}} {

	global FullMonths LANG FullDays

	if {![info exists LANG]} {
		set LANG en
	}

	if {$style == "time"} {
		if {[regexp {^(....)-(..)-(..) (..):(..):..$} $dt all y m d hh mm]} {
			set m  [string trimleft $m  0]
			set d  [string trimleft $d  0]
			set HH $hh
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

			if {$hh==""} {
				# Midnight
				set hh "12"
			}

			switch -- $LANG {
				"cn" {
					return "${y}年${m}月${d}日 $hh:$mm$hsfx"
				}

				"es" {
					return "$d [lindex $FullMonths($LANG) $m] $y $HH:$mm"
				}

				"it" {
					return "$d [lindex $FullMonths($LANG) $m] $y $HH:$mm"
				}

				"sw" {
					return "$d [lindex $FullMonths($LANG) $m] $y $HH:$mm"
				}

				"th" {
					return "$d [lindex $FullMonths($LANG) $m] $y $HH:$mm"
				}

				default {
					if {[info exists FullMonths($LANG)]} {
						return "$d[day_sfx $d] of [lindex $FullMonths($LANG) $m] $y $hh:$mm$hsfx"
					} else {
						return "$d[day_sfx $d] of [lindex $FullMonths(en) $m] $y $hh:$mm$hsfx"
					}
				}
			}
		}
		return $dt
	}

	if {$style == "shrttime"} {
		if {[regexp {^(....)-(..)-(..) (..):(..):..$} $dt all y m d hh mm]} {
			if {$LANG=="cn"} {
				return "${hh}:${mm} ${y}年${m}月${d}日"
			} else {
				return "${hh}:${mm} $d/$m/$y"
			}
		}
		return $dt
	}

	if {$style == "day"} {
		if {[regexp {^(....)-(..)-(..)} $dt all y m d]} {
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
			switch -- $LANG {
				"cn" {
					return "${y}年${m}月${d}日"
				}

				"es" {
					return "$d [lindex $FullMonths($LANG) $m] $y"
				}

				"it" {
					return "$d [lindex $FullMonths($LANG) $m] $y"
				}

				"sw" {
					return "$d [lindex $FullMonths($LANG) $m] $y"
				}

				"th" {
					return "$d [lindex $FullMonths($LANG) $m] $y"
				}

				default {
					if {[info exists FullMonths($LANG)]} {
						return "$d[day_sfx $d] of [lindex $FullMonths($LANG) $m] $y"
					} else {
						return "$d[day_sfx $d] of [lindex $FullMonths(en) $m] $y"
					}
				}
			}
		}
		return $dt
	}

	if {$style == "shrtday"} {
		if {[regexp {^(....)-(..)-(..)} $dt all y m d]} {
			if {$LANG=="cn"} {
				return "${y}年${m}月${d}日"
			} else {
				return "$d/$m/$y"
			}
		}
		return $dt
	}

	if {$style == "shrtday2digityear"} {
		if {[regexp {^..(..)-(..)-(..)} $dt all y m d]} {
			if {$LANG=="cn"} {
				return "${y}年${m}月${d}日"
			} else {
				return "$d/$m/$y"
			}
		}
		return $dt
	}

	if {$style == "fullday"} {
		if {[regexp {^(....)-(..)-(..)} $dt all y m d]} {
			set d    [string trimleft $d 0]
			set m    [string trimleft $m 0]
			set secs [clock scan $m/$d/$y -gmt 1]
			set day  [clock format $secs -format %A -gmt 1]

			switch -- $LANG {
				"cn" {
					return "${y}年${m}月${d}日"
				}

				"es" {
					return "$FullDays($LANG,$day), $d [lindex $FullMonths($LANG) $m] $y"
				}

				"it" {
					return "$FullDays($LANG,$day), $d [lindex $FullMonths($LANG) $m] $y"
				}

				"sw" {
					return "$FullDays($LANG,$day), $d [lindex $FullMonths($LANG) $m] $y"
				}

				"th" {
					return "$FullDays($LANG,$day), $d [lindex $FullMonths($LANG) $m] $y"
				}

				default {
					if {[info exists FullMonths($LANG)]} {
						return "$day $d[day_sfx $d] of [lindex $FullMonths($LANG) $m], $y"
					} else {
						return "$day $d[day_sfx $d] of [lindex $FullMonths(en) $m], $y"
					}
				}
			}
		}
		return $dt
	}

	if {$style == "dayofweek"} {
		if {[regexp {^(....)-(..)-(..)} $dt all y m d]} {
			set d    [string trimleft $d 0]
			set m    [string trimleft $m 0]
			set secs [clock scan $m/$d/$y -gmt 1]
			set dow  [clock format $secs -format %w -gmt 1]

			return $dow
		}
		return 0
	}

	if {$style == "dayofmonth"} {
		if {[regexp {^(....)-(..)-(..)} $dt all y m d]} {
			set d    [string trimleft $d 0]
			set m    [string trimleft $m 0]
			set secs [clock scan $m/$d/$y -gmt 1]
			set dow  [clock format $secs -format %w -gmt 1]

			return $d
		}
		return 0
	}
	if {$style == "month"} {
		if {[regexp {^(....)-(..)} $dt all y m]} {
			set m [string trimleft $m 0]
			return "[lindex $FullMonths($LANG) $m] $y"
		}
		return $dt
	}

	if {$style == "year"} {
		if {[regexp {^(....)} $dt all y]} {
			return "$y"
		}
		return $dt
	}

	if {$style == "pp_rcpt"} {
		if {[regexp {^(....)-(..)-(..) (..):(..)} $dt all y m d hh mm]} {
			set secs [clock scan $m/$d/$y -gmt 1]
			set mon  [clock format $secs -format %b -gmt 1]
			return "$d $mon $y @ $hh.$mm"
		}
	}

	if {$style == "hr_min"} {
		if {[regexp {^(....)-(..)-(..) (..):(..)} $dt all y m d hh mm]} {
			return "$hh:$mm"
		}
	}

	if {$style == "12hr_min"} {
		if {[regexp {^(....)-(..)-(..) (..):(..):..$} $dt all y m d hh mm]} {
			set m  [string trimleft $m  0]
			set d  [string trimleft $d  0]
			set HH $hh
			set hh [string trimleft $hh 0]

			if {$hh == 24} {
				set hsfx am
				set hh "00"
			} elseif {$hh >= 12} {
				set hsfx pm
				set hh [expr $hh - 12]
				if {$hh == "0"} {
					set hh "12"
				}
			} else {
				set hsfx am
			}

			if {$hh==""} {
				# Midnight
				set hh "12"
			}

			switch -- $LANG {
				"cn" {
					return "$hh:$mm$hsfx"
				}

				"es" {
					return "$$HH:$mm"
				}

				"it" {
					return "$HH:$mm"
				}

				"sw" {
					return "$HH:$mm"
				}

				"th" {
					return "$hh:$mm$hsfx"
				}

				default {
					return "$hh:$mm$hsfx"
				}
			}
		}
	}
	return $dt
}

#======================================================================
# Account transaction drill down
#
################################################################
proc openbet_process_qry_dates {type months d1 m1 y1 d2 m2 y2} {
################################################################

# This function reurns a tcl list containing 3 elements
# The first two elements are strings containing valid Informix dates that can be put
# straight into a query
# the 3rd element is a description tag
#
# This function specifically written for the account query box on bluesquare
# but can be generally used to return two informix date (dt1,dt2)
# given d1,d2 - the day numbers (1-31)
# m1,m2 - the month numbers (1-12)
# y1,y2 - the year numbers
# uses the utility function days_in_month to make sure that the days argument is valid (takes account of leap years sloppily - see above)

	if {$type == "L"} {

		set dt [clock format [clock seconds] -format "%Y-%m-%d"]

		foreach {y m d} [split $dt -] {
			set y [string trimleft $y 0]
			set m [string trimleft $m 0]
			set d [string trimleft $d 0]
		}

		set m [expr $m - $months]

		if {$m < 1} {
			set m [expr 12 + $m]
			incr y -1
		}

		set dd [days_in_month $m $y]

		if {$d > $dd} {
			set d $dd
		}

		set dt1 "$y-[format %02d $m]-[format %02d $d] 00:00:00"
		set dt2 "$dt 23:59:59"

		set desc "for the last $months months"

	} else {

		set md1 [days_in_month $m1 $y1]
		set md2 [days_in_month $m2 $y2]

		if {$d1 > $md1} {set d1 $md1}
		if {$d2 > $md2} {set d2 $md2}

		set dt1 "$y1-[format %02d $m1]-[format %02d $d1]"
		set dt2 "$y2-[format %02d $m2]-[format %02d $d2]"

		# swap dates if wrong way round
		if {[string compare $dt1 $dt2] == 1} {
			set d   $dt1
			set dt1 $dt2
			set dt2 $d
		}

		set dt1 "$dt1 00:00:00"
		set dt2 "$dt2 23:59:59"

		set hdt1 [html_date $dt1 day]
		set hdt2 [html_date $dt2 day]

		set desc "between $hdt1 and $hdt2"
	}

	set dt1 "datetime ($dt1) year to second"
	set dt2 "datetime ($dt2) year to second"

	return [list $dt1 $dt2 $desc]
}

# ----------------------------------------
# return an informix date for secs seconds
# or the beginning/end of time if passed BOT/EOT
# ----------------------------------------

proc get_ifmx_date secs {
	switch -- $secs {
		"BOT" {return "0001-01-01 00:00:00"}
		"EOT" {return "9999-12-31 23:59:59"}
		default {
			return [clock format $secs -format "%Y-%m-%d %H:%M:%S"]
		}
	}
}

proc ifmx_date_to_secs date {
	if {[regexp {^(....)-(..)-(..) (..):(..):(..)$} $date all y m d hh mm ss]} {
		set american_date "$m/$d/$y $hh:$mm:$ss"
		return [clock scan $american_date]
	}
}

# ---------------------------------------------------
# given day-number (1-31), month_number (1-12), year
# returns a string containing an Informix style date
# days in month check only valid for a few centuries
# so only recent dates please!!!
# ---------------------------------------------------

proc openbet_gen_informix_date {hrs mins secs day_num month_num year_num} {

	set days_in_month [days_in_month $month_num $year_num]

	if {$day_num > $days_in_month} {set day_num $days_in_month}

	set inf_date "$year_num-[format %02d $month_num]-[format %02d $day_num]"
	append  inf_date " [format %02d $hrs]:[format %02d $mins]:[format %02d $secs]"
	return $inf_date
}
