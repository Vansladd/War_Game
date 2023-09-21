# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Date/Time utilities
#
set pkgVersion 1.0
package provide core::date $pkgVersion
package require core::log 1.0

core::args::register_ns \
	-namespace core::date \
	-version $pkgVersion \
	-dependent [list core::args core::log core::xl] \
	-desc {Date/Time utilities} \
	-docs util/date.xml

namespace eval core::date {}

# Get an Informix formatted date.
#
#   returns - Informix formatted date - yyyy-mm-dd hh:mm:ss
#
# TODO: Add proper error handling
core::args::register \
	-proc_name core::date::get_informix_date \
	-desc {
		seconds - date and time as a system-dependent integer value
			(value is usually defined as total elapsed time from an 'epoch')
		BOT - beginning time
		EOT - end time
	} \
	-args [list \
		[list -arg -seconds -mand 1 -check {RE -args {^BOT|EOT|\d+$}} -desc {Seconds}] \
	] \
	-body {
		set seconds $ARGS(-seconds)

		switch -- $seconds {
			"BOT" {
				# Temporarily changed from 0001-01-01 due to
				# problems with ot::command::check_args
				return "1970-01-01 00:00:00"
			}
			"EOT" {
				return "9999-12-31 23:59:59"
			}
			default {
				return [clock format $seconds -format "%Y-%m-%d %H:%M:%S"]
			}
		}
	}

# Get xml Datetime DATA Type
# http://www.w3schools.com/schema/schema_dtypes_date.asp
core::args::register \
	-proc_name core::date::datetime_to_xml_date \
	-args [list \
		[list -arg -datetime -mand 1 -check DATETIME -desc {date time to format}] \
	] \
	-body {
		set time_to_convert $ARGS(-datetime)
		return [clock format [clock scan $time_to_convert] -format "%Y-%m-%dT%H:%M:%S"]
	}

core::args::register \
	-proc_name core::date::format_xml_date \
	-args [list \
		[list -arg -date   -mand 1 -check STRING -desc {date time to format}] \
		[list -arg -format -mand 0 -check STRING -desc {return time format} -default {%Y-%m-%d %H:%M:%S}] \
	] \
	-body {
		set date $ARGS(-date)
		set return_date_format $ARGS(-format)
		return [clock format [clock scan $date -format "%Y-%m-%dT%H:%M:%S"] -format $return_date_format]
	}

core::args::register \
	-proc_name core::date::datetime_to_iso8601 \
	-desc {Format a date into the ISO-8601 format}\
	-args [list \
		[list -arg -datetime -mand 1 -check DATETIME -desc {Date time to format (in server timezone)}] \
		[list -arg -utc      -mand 0 -check BOOL     -default 0 -desc {Convert into UTC}] \
	] \
	-body {
		set local $ARGS(-datetime)

		if {$ARGS(-utc)} {
			return [clock format [clock scan $local]\
				-timezone UTC\
				-format   "%Y-%m-%dT%H:%M:%S.000Z"\
			]
		} else {
			set scan_result [clock scan $ARGS(-datetime)]
			# We will get something in the format of "+0200" or "+0000" or "-0300"
			# and we want to convert it into the format of "+02:00"
			set timezone [clock format $scan_result -format "%z"]
			set tz_hours   [string range $timezone 0 2]
			set tz_minutes [string range $timezone 3 4]
			set timezone "${tz_hours}:${tz_minutes}"

			set datetime [clock format $scan_result -format "%Y-%m-%dT%H:%M:%S"]
			return "${datetime}${timezone}"
		}
	}

core::args::register \
	-proc_name core::date::add \
	-args [list \
		[list -arg -date   	-mand 1 -check DATETIME -desc {date time to format}] \
		[list -arg -format 	-mand 0 -check STRING -desc {return time format} -default {%Y-%m-%d %H:%M:%S}] \
		[list -arg -days 	-mand 0 -check ASCII -desc {days to add} -default 0] \
		[list -arg -hours 	-mand 0 -check ASCII -desc {hours to add} -default 0] \
		[list -arg -minutes -mand 0 -check ASCII -desc {minutes to add} -default 0] \
		[list -arg -seconds -mand 0 -check ASCII -desc {seconds to add} -default 0] \
	] \
	-body {
		set date [clock scan $ARGS(-date)]

		set future [expr {$date 	+ $ARGS(-days) * 24 * 60 * 60}]
		set future [expr {$future 	+ $ARGS(-hours) * 60 * 60}]
		set future [expr {$future 	+ $ARGS(-minutes) * 60}]
		set future [expr {$future 	+ $ARGS(-seconds)}]
		
		set return_date_format $ARGS(-format)
		return [clock format $future -format $return_date_format]
	}
