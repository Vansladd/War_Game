# $Id: date.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Date/Time utilities
#
# Synopsis:
#     package require util_date ?4.5?
#
# If not using the package within appserv, then load libOT_Tcl.so
#
# Procedures:
#    ob_date::days_in_month   total number of days in a month
#    ob_date::get_ifmx_date   get an Informix formatted date
#    ob_date::get_calendar    get a simple calendar
#    ob_date::xl_month        translate month
#    ob_date::xl_day_of_week  translate day-of-week
#    ob_date::utc2cet         Converts a UTC time to CET
#    ob_date::xl_html_date    produce a full date string
#    ob_date::day_sfx         get the correct two letter suffix for a month day

package provide util_date 4.5



# Dependencies
#
package require util_log 4.5
package require util_xl  4.5



# Variables
#
namespace eval ob_date {

	variable INIT
	variable CALENDAR
	variable XL_MONTH
	variable XL_DAYOFWEEK
	variable XL_DAYSFX
	variable MONTH_DAYS
	variable CFG
	variable XL_DAYSFX

	set MONTH_DAYS [list 0 31 28 31 30 31 30 31 31 30 31 30 31]

	set XL_MONTH [list\
	        OB_MONTH_JAN\
	        OB_MONTH_FEB\
	        OB_MONTH_MAR\
	        OB_MONTH_APR\
	        OB_MONTH_MAY\
	        OB_MONTH_JUN\
	        OB_MONTH_JUL\
	        OB_MONTH_AUG\
	        OB_MONTH_SEP\
	        OB_MONTH_OCT\
	        OB_MONTH_NOV\
	        OB_MONTH_DEC]

	set XL_DAYOFWEEK [list\
	        OB_DAYOFWEEK_SUNDAY\
	        OB_DAYOFWEEK_MONDAY\
	        OB_DAYOFWEEK_TUESDAY\
	        OB_DAYOFWEEK_WEDNESDAY\
	        OB_DAYOFWEEK_THURSDAY\
	        OB_DAYOFWEEK_FRIDAY\
	        OB_DAYOFWEEK_SATURDAY]

	set XL_DAYSFX [list\
	        OB_DAYSFX_ST\
	        OB_DAYSFX_ND\
	        OB_DAYSFX_RD\
	        OB_DAYSFX_TH]

	set CFG(date_base_year) [OT_CfgGet DATE_BASE_YEAR 1998]
	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time-initialisation
#
proc ob_date::init args {

	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_xl::init

	ob_log::write DEBUG {DATE: init}

	# successfully initialised
	set INIT 1
}



# Private procedure to initialise the simple calendar.
#
proc ob_date::_init_calendar args {

	variable XL_MONTH
	variable CALENDAR
	variable MONTH_DAYS

	for {set i 0} {$i < 31} {incr i} {
		set CALENDAR($i,day) [expr {$i + 1}]
	}
	for {set i 0} {$i < 12} {incr i} {
		set m [lindex $XL_MONTH $i]
		foreach {ob month name} [split $m _] { }
		set CALENDAR($i,month_num)  [expr {$i + 1}]
		set CALENDAR($i,month)      $m
		set CALENDAR($i,long_month) "OB_LONG_MONTH_$name"
	}
	set CALENDAR(day,total)   31
	set CALENDAR(month,total) 12
}


#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Get the total number of days in a month
#
#   month   - requested month
#   year    - requested year
#   returns - total number of days in a month, or zero if invalid month/year
#
proc ob_date::days_in_month { month year } {

	variable MONTH_DAYS

	set month [string trimleft $month 0]

	if {$month == 2 && $year % 4 == 0} {
		return 29
	} elseif {$month <= 0 || $month > 12 || $year <= 0} {
		return 0
	}

	return [lindex $MONTH_DAYS $month]
}



# Get an Informix formatted date.
#
#   seconds - date and time as a system-dependent integer value
#             (value is usually defined as total elapsed time from an 'epoch')
#             BOT - beginning time
#             EOT - end time
#   returns - Informix formatted date - yyyy-mm-dd hh:mm:ss
#
proc ob_date::get_ifmx_date { seconds } {

	switch -- $seconds {
		"BOT" {
			return "0001-01-01 00:00:00"
		}
		"EOT" {
			return "9999-12-31 23:59:59"
		}
		default {
			return [clock format $seconds -format "%Y-%m-%d %H:%M:%S"]
		}
	}
}



# Get the simple calendar (all months have 31 days). The calendar selects two
# dates, 'now' and a supplied integer-value date/time.
#
#   seconds - date and time as a system-dependent integer value
#             (value is usually defined as total elapsed time from an 'epoch')
#   returns  - simple calendar array
#
proc ob_date::get_calendar { seconds } {

	variable CALENDAR
	variable CFG

	if {![info exists CALENDAR]} {
		_init_calendar
	}

	# construct the years
	set now       [clock seconds]
	set this_year [clock format $now -format "%Y"]
	for {set i $CFG(date_base_year)} {$i <= $this_year} {incr i} {
		set CALENDAR([expr {$i - $CFG(date_base_year)}],year) $i
	}
	set CALENDAR(year,total) [expr {$i - $CFG(date_base_year)}]

	_get_calendar now $now
	_get_calendar selected $seconds

	return [array get CALENDAR]
}



# Private procedure to select a date within the simple calendar.
#
#   selected - (selected|now)
#   seconds  - time/date integer-value
#
proc ob_date::_get_calendar { selected seconds } {

	variable XL_MONTH
	variable CALENDAR

	foreach {y m d} [split [clock format $seconds -format "%Y-%m-%d"] -] {
		set m [string trimleft $m 0]
		set d [string trimleft $d 0]
	}

	set CALENDAR(day,$selected)   $d
	set CALENDAR(month,$selected) $m
	set CALENDAR(year,$selected)  $y
}



#--------------------------------------------------------------------------
# Multi-Lingual
#--------------------------------------------------------------------------

# Translate a month.
#
#    lang    - language code
#    m       - month number (1 - Jan,..., 12 - Dec)
#    style   - unused
#    returns - translated month, or 'm' if invalid
#
proc ob_date::xl_month { lang m {style ""}} {

	variable XL_MONTH

	set mm [string trimleft $m 0]
	if {$mm >= 1 && $mm <= 12} {
		return [ob_xl::sprintf $lang [lindex $XL_MONTH [expr {$mm - 1}]]]
	}

	ob_log::write WARNING {DATE: invalid month number, $m, not translating}
	return $m
}



# Translate a day-of-week
#
#    lang    - language code
#    d       - day-of-week (0 - Sun,..., 6 - Sat)
#    returns - translated day-of-week, or 'd' if invalid
#
proc ob_date::xl_day_of_week { lang d } {

	variable XL_DAYOFWEEK

	if {[string length $d] >= 2} {
		set dd [string trimleft $d 0]
	} else {
		set dd $d
	}
	if {$dd >= 0 && $dd <= 6} {
		return [ob_xl::sprintf $lang [lindex $XL_DAYOFWEEK $dd]]
	}

	ob_log::write WARNING\
	    {DATE: invalid day-of-week number, $d, not translating}
	return $d
}

# Converts a UTC time to CET
#
#	utcTime  - The time in UTC
#	returns  - The time in CET

proc ob_date::utc2cet { utcTime } {

	#if {![regexp {^((?:[01]\d)|(?:2[0-3])):([0-5]\d):([0-5]\d)$} $time] } {
	#	return ""
	#}

	return [clock format [expr {[clock scan $utcTime] + 3600}] -format "%Y-%m-%d %H:%M:%S"]
}

# Translate a day-of-week
#
#    lang          - language code
#    informix_date - YYYY-MM-DD
#    returns - translated verbose date, e.g. Monday 4 January 2009
#
proc ob_date::xl_informix_to_verbose { lang informix_date } {

	set verbose_date [clock format [clock scan $informix_date] -format {%A %d %B %Y}]

	set day_string [ob_xl::sprintf $lang OB_DAYOFWEEK_[string toupper [lindex $verbose_date 0]]]
	set day_integer  [lindex $verbose_date 1]
	set month_string [ob_xl::sprintf $lang OB_MONTH_[string toupper [lindex $verbose_date 2]]]
	set year_integer [lindex $verbose_date 3]

	return [list $day_string $day_integer $month_string $year_integer]
}

# Produce a full date string
#
#   date    - informix date, YYYY-MM-DD HH:MM:SS
#   lang    - language code
#   style   - how to format the date -
#              - time                 "D MM Y HH:MM"
#              - longtime             "DD D MM Y, HH:MM"
#              - abbrevday            "D MM Y"
#              - shrttime             "HH:MM D/M/Y"
#              - day                  "D MM Y"
#              - longday              "D MM Y"
#              - longdayshortmonth    "D MM Y" where month is the shortened version eg Apr
#              - daymonth             "DD D MM"
#              - shrtday              "D/M/Y"
#              - shrtday2digityear    "D/M/Y" where Y is 2 digits
#              - fullday              "DD D MM Y"
#              - dayofweek            "D"
#              - dayofmonth           "D"
#              - month                "M"
#              - year                 "Y"
#              - pp_rcpt              "D M Y @ HH.MM"
#              - hr_min               "HH:MM"
#              - 12hr_min             "HH:MM"
#   returns - translated date (if required) for the given style
proc ob_date::xl_html_date { date lang {style time}} {

	variable XL_MONTH
	variable XL_MONTH_FULL
	variable XL_DAYOFWEEK

	ob_log::write DEBUG {ob_date::xl_html_date date: $date - lang $lang - style $style}

	switch $style {
		"time" {
			# Format "D MM Y HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				set 12hr_min [xl_html_date $date $lang "12hr_min"]

				switch $lang {
					"en" {
						set d  [string trimleft $d  0]
						return "$d[day_sfx $lang $d] of [xl_month $lang $m] $y \
						        $12hr_min"
					}
					default {
						return "$d [xl_month $lang $m] $y $12hr_min"
					}
				}
			}
		}
		"longtime" {
			# Format "DD D MM Y, HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				set m   [string trimleft $m  0]
				set d   [string trimleft $d  0]
				set hh  [string trimleft $hh 0]
				set dow [xl_html_date $date $lang dayofweek]

				# Only add date suffix for some language
				switch $lang {
					"en" {
						return "[xl_day_of_week $lang $dow] $d[day_sfx $lang $d] \
						[xl_month $lang $m] $y, $hh:$mm"
					}
					default {
						return "[xl_day_of_week $lang $dow] $d \
						[xl_month $lang $m] $y, $hh:$mm"
					}
				}
			}
		}
		"abbrevday" {
			# Format  "D MM Y"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
				set d  [string trimleft $d  0]
				# Only add date suffix for some language
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] [xl_month $lang $m] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"shrttime" {
			# Format "HH:MM D/M/Y"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				return "${hh}:${mm} $d/$m/$y"
			}
		}
		"day"
		{
			# Format "D MM Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set m [string trimleft $m 0]
				set d [string trimleft $d 0]

				return "$d [xl_month $lang $m] $y"
			}
		}
		"longday" {
			# Format "D MM Y HH:MM"
			# e.g. 5th April 2008
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d [string trimleft $d 0]
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] of [xl_month $lang $m full] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"longdayshortmonth" {
			# Format "D MM Y HH:MM"
			# e.g. 5th April 2008
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d [string trimleft $d 0]
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] of [xl_month $lang $m] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"daymonth" {
			# Format "DD D MM"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set m    [string trimleft $m 0]
				set d    [string trimleft $d 0]
				set dow  [xl_html_date $date $lang dayofweek]

				switch $lang {
					"en" {
						return "[xl_day_of_week $lang $dow] $d[day_sfx $lang $d] \
						        [xl_month $lang $m]"
					}
					default {
						return "[xl_day_of_week $lang $dow] $d \
						        [xl_month $lang $m]"
					}
				}
			}
		}
		"shrtday" {
			# Format "D/M/Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				return "$d/$m/$y"
			}
		}
		"shrtday2digityear" {
			# Format "D/M/Y"
			if [regexp {^..(..)-(..)-(..)} $date all y m d] {
					return "$d/$m/$y"
			}
		}
		"fullday" {
			# Format "DD D MM Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				set dow  [xl_html_date $date $lang dayofweek]
				set m    [string trimleft $m 0]
				set secs [super_clock_scan "$d/$m/$y" date]
				set day  [clock format $secs -format %A -gmt 1]

				switch $lang {
					"en" {
						return   "[xl_day_of_week $lang $dow], $d[day_sfx $lang $d] \
						          [xl_month $lang $m full] $y"
					}
					"fr" {
						return   "[xl_day_of_week $lang $dow] $d \
						          [xl_month $lang $m full] $y"
					}
					default {
						return   "[xl_day_of_week $lang $dow], $d \
						          [xl_month $lang $m full] $y"
					}
				}
			}
		}
		"dayofweek" {
			# Format "D"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				set m    [string trimleft $m 0]
				set secs [super_clock_scan "$d/$m/$y" date]
				set dow  [clock format $secs -format %w -gmt false]

				return   $dow
			}
		}
		"dayofmonth" {
			# Format "D"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				return   $d
			}
		}
		"month" {
			# Format "MM"
			if [regexp {^(....)-(..)} $date all y m] {
				set m   [string trimleft $m 0]
				return  [xl_month $lang $m]
			}
		}
		"year" {
			# Format "YY"
			if [regexp {^(....)} $date all y] {
				return "$y"
			}
		}
		"pp_rcpt" {
			# Format  "D MM Y @ HH.MM"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
				set secs [super_clock_scan "$d/$m/$y" date]
				set mon  [xl_month $lang $m]
				return "$d $mon $y @ $hh.$mm"
			}
		}
		"hr_min" {
			# Format "HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				switch $lang {
					"fr" {
						return "${hh}h${mm}"
					}
					default {
						return "$hh:$mm"
					}
				}
			}
		}
		"12hr_min" {
			# Format "HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
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

				return "$hh:$mm $hsfx"

			}
		}
		default {
			ob_log::write ERROR\
				{DATE: invalid style: $style not defined}
			return $date
		}
	}

	ob_log::write ERROR\
		{DATE: invalid date: $date wrong format}
}

# Get the correct two letter suffix for a month day
#   day    - day of the month
#   lang    - language code
#
proc ob_date::day_sfx {lang day} {

	variable XL_DAYSFX

	set rem [expr $day % 10]
	set quot [expr $day / 10]
	if { $quot != 1 && $rem > 0 && $rem < 4 } {
		set day $rem
	} else {
		set day 4
	}

	set day [expr $day - 1]

	return [ob_xl::sprintf $lang [lindex $XL_DAYSFX $day]]
}

# Replace the uses of "clock scan" due to it's incompatability with dates
# after 2037.
#    - date,     'DD/MM/YYYY HH:MM:SS' or 'MM/DD/YYYY HH:MM:SS' if american date
#    - american  1 if date is in the american format
#    - returns date in seconds since 01/01/1970 00:00:00
#
proc ob_date::super_clock_scan {date type} {

	ob_log::write DEBUG {ob_date::super_clock_scan date $date - type $type}

	switch $type {
		date {
			regexp {(.*)\/(.*)\/(.*)} $date date_part dd mm yy
			set h 0
			set m 0
			set s 0
		}
		datetime {
			regexp {(.*)\/(.*)\/(.*) (.*):(.*):(.*)} $date all dd mm yy h m s
		}
		default {
			ob_log::write ERROR {ob_date::super_clock_scan wrong type}
			return -1
		}
	}

	if {[catch {set secs [clock scan "$mm/$dd/$yy $h:$m:$s"]} msg]} {
		set secs [expr {($h * 3600) + ($m * 60) + $s}]
		set secs [expr {[_date_secs "$dd/$mm/$yy"] + $secs}]
	}

	return $secs
}



# Replace the uses of "clock scan" due to it's incompatability with dates
# after 2037.
#    - date,     'DD-MM-YYYY HH:MM:SS'
#    - returns date in seconds since 01/01/1970 00:00:00
#
proc ob_date::_date_secs { date } {
	regexp {(.*)\/(.*)\/(.*)} $date all d m y

	# Years
	set days [expr ($y-1970)*365]

	# Leap years
	for {set i 1972} {$i<$y} {incr i 4} {
		if {$i%100!=0 || $i%400==0} {
			incr days
		}
	}

	# Months
	if {$m>1} {incr days 31}
	if {$m>2} {
		incr days 28
		if {$y%4==0 && ($y%100!=0 || $y%400==0)} {incr days}
	}
	if {$m>3} {incr days 31}
	if {$m>4} {incr days 30}
	if {$m>5} {incr days 31}
	if {$m>6} {incr days 30}
	if {$m>7} {incr days 31}
	if {$m>8} {incr days 31}
	if {$m>9} {incr days 30}
	if {$m>10} {incr days 31}
	if {$m>11} {incr days 30}

	# Days
	incr days [expr $d-1]

	return [expr {$days * 86400}]
}



# Produce a full date string
#
#   date    - informix date, YYYY-MM-DD HH:MM:SS
#   lang    - language code
#   style   - how to format the date -
#              - time                 "D MM Y HH:MM"
#              - longtime             "DD D MM Y, HH:MM"
#              - abbrevday            "D MM Y"
#              - shrttime             "HH:MM D/M/Y"
#              - day                  "D MM Y"
#              - longday              "D MM Y"
#              - longdayshortmonth    "D MM Y" where month is the shortened version eg Apr
#              - daymonth             "DD D MM"
#              - shrtday              "D/M/Y"
#              - shrtday2digityear    "D/M/Y" where Y is 2 digits
#              - fullday              "DD D MM Y"
#              - dayofweek            "D"
#              - dayofmonth           "D"
#              - month                "M"
#              - year                 "Y"
#              - pp_rcpt              "D M Y @@ HH.MM"
#              - hr_min               "HH:MM"
#              - 12hr_min             "HH:MM"
#   returns - translated date (if required) for the given style
proc ob_date::xl_html_date { date lang {style time}} {

	variable XL_MONTH
	variable XL_MONTH_FULL
	variable XL_DAYOFWEEK

	ob_log::write DEBUG {ob_date::xl_html_date date: $date - lang $lang - style $style}

	switch $style {
		"time" {
			# Format "D MM Y HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				set 12hr_min [xl_html_date $date $lang "12hr_min"]

				switch $lang {
					"en" {
						set d  [string trimleft $d  0]
						return "$d[day_sfx $lang $d] of [xl_month $lang $m] $y \
                                                        $12hr_min"
					}
					default {
						return "$d [xl_month $lang $m] $y $12hr_min"
					}
				}
			}
		}
		"longtime" {
			# Format "DD D MM Y, HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				set m   [string trimleft $m  0]
				set d   [string trimleft $d  0]
				set hh  [string trimleft $hh 0]
				set dow [xl_html_date $date $lang dayofweek]

				# Only add date suffix for some language
				switch $lang {
					"en" {
						return "[xl_day_of_week $lang $dow] $d[day_sfx $lang $d] \
                                                [xl_month $lang $m] $y, $hh:$mm"
					}
					default {
						return "[xl_day_of_week $lang $dow] $d \
                                                [xl_month $lang $m] $y, $hh:$mm"
					}
				}
			}
		}
		"abbrevday" {
			# Format  "D MM Y"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
				set d  [string trimleft $d  0]
				# Only add date suffix for some language
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] [xl_month $lang $m] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"shrttime" {
			# Format "HH:MM D/M/Y"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				return "${hh}:${mm} $d/$m/$y"
			}
		}
		"day"
		{
			# Format "D MM Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set m [string trimleft $m 0]
				set d [string trimleft $d 0]

				return "$d [xl_month $lang $m] $y"
			}
		}
		"longday" {
			# Format "D MM Y HH:MM"
			# e.g. 5th April 2008
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d [string trimleft $d 0]
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] of [xl_month $lang $m full] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"longdayshortmonth" {
			# Format "D MM Y HH:MM"
			# e.g. 5th April 2008
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d [string trimleft $d 0]
				switch $lang {
					"en" {
						return "$d[day_sfx $lang $d] of [xl_month $lang $m] $y"
					}
					default {
						return "$d [xl_month $lang $m] $y"
					}
				}
			}
		}
		"daymonth" {
			# Format "DD D MM"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set m    [string trimleft $m 0]
				set d    [string trimleft $d 0]
				set dow  [xl_html_date $date $lang dayofweek]

				switch $lang {
					"en" {
						return "[xl_day_of_week $lang $dow] $d[day_sfx $lang $d] \
                                                        [xl_month $lang $m]"
					}
					default {
						return "[xl_day_of_week $lang $dow] $d \
                                                        [xl_month $lang $m]"
					}
				}
			}
		}
		"shrtday" {
			# Format "D/M/Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				return "$d/$m/$y"
			}
		}
		"shrtday2digityear" {
			# Format "D/M/Y"
			if [regexp {^..(..)-(..)-(..)} $date all y m d] {
				return "$d/$m/$y"
			}
		}
		"fullday" {
			# Format "DD D MM Y"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				set dow  [xl_html_date $date $lang dayofweek]
				set m    [string trimleft $m 0]
				set secs [super_clock_scan "$d/$m/$y" date]
				set day  [clock format $secs -format %A -gmt 1]

				switch $lang {
					"en" {
						return   "[xl_day_of_week $lang $dow], $d[day_sfx $lang $d] \
                                                          [xl_month $lang $m full] $y"
					}
					"fr" {
						return   "[xl_day_of_week $lang $dow] $d \
                                                          [xl_month $lang $m full] $y"
					}
					default {
						return   "[xl_day_of_week $lang $dow], $d \
                                                          [xl_month $lang $m full] $y"
					}
				}
			}
		}
		"dayofweek" {
			# Format "D"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				set m    [string trimleft $m 0]
				set secs [super_clock_scan "$d/$m/$y" date]
				set dow  [clock format $secs -format %w -gmt false]

				return   $dow
			}
		}
		"dayofmonth" {
			# Format "D"
			if [regexp {^(....)-(..)-(..)} $date all y m d] {
				set d    [string trimleft $d 0]
				return   $d
			}
		}
		"month" {
			# Format "MM"
			if [regexp {^(....)-(..)} $date all y m] {
				set m   [string trimleft $m 0]
				return  [xl_month $lang $m]
			}
		}
		"year" {
			# Format "YY"
			if [regexp {^(....)} $date all y] {
				return "$y"
			}
		}
		"pp_rcpt" {
			# Format  "D MM Y @@ HH.MM"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
				set secs [super_clock_scan "$d/$m/$y" date]
				set mon  [xl_month $lang $m]
				return "$d $mon $y @@ $hh.$mm"
			}
		}
		"hr_min" {
			# Format "HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..):..$} $date all y m d hh mm] {
				switch $lang {
					"fr" {
						return "${hh}h${mm}"
					}
					default {
						return "$hh:$mm"
					}
				}
			}
		}
		"12hr_min" {
			# Format "HH:MM"
			if [regexp {^(....)-(..)-(..) (..):(..)} $date all y m d hh mm] {
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

				return "$hh:$mm $hsfx"

			}
		}
		default {
			ob_log::write ERROR\
				{DATE: invalid style: $style not defined}
			return $date
		}
	}

	ob_log::write ERROR\
		{DATE: invalid date: $date wrong format}
}



#
# Get the correct two letter suffix for a month day
#   day    - day of the month
#   lang    - language code
#
proc ob_date::day_sfx {lang day} {

        variable XL_DAYSFX

        set rem [expr $day % 10]
        set quot [expr $day / 10]
        if { $quot != 1 && $rem > 0 && $rem < 4 } {
                set day $rem
        } else {
                set day 4
        }

        set day [expr $day - 1]

        return [ob_xl::sprintf $lang [lindex $XL_DAYSFX $day]]
}
