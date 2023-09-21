#
#
# Timezones
# =================
# The functions herein utilize TZ Database which is a collaborative compilation
# of world's timezones. It includes most kind of time zone transitions such
# as daylight saving time.
# http://en.wikipedia.org/wiki/Tz_database
#
# The list of timezone names have been ported in ttimezone table and rest of 
# information is available from Tz database through appserv interface. Functions
# defined in this file will perform as an interface to all timezone relation
# information. 
#
#
# Configuration:
#
# Synopsis:
#     package require core::timezone ?1.0?
#
# Public Procedures:
#    core::timezone::init    one time initialisation
#    core::timezone::get_cust_timezone
#    core::timezone::set_cust_timezone
#    core::timezone::get_timezone_list
#    core::timezone::check_timezone_status
#    core::timezone::get_tz_timezone
#    core::timezone::format_time
#    core::timezone::get_italy_timezone
#    core::timezone::is_italy
#    core::timezone::upd_timezone
#    core::timezone::get_default_timezone_id
#    core::timezone::add_timezone
#    core::timezone::get_timezone

set pkg_version 1.0
package provide core::timezone $pkg_version

package require core::log 1.0
package require core::db  1.0
package require core::control  1.0

core::args::register_ns \
	-namespace core::timezone \
	-version   $pkg_version \
	-dependent [list core::check core::log core::db] \
	-docs      util/timezone.xml

namespace eval core::timezone {

	variable CFG

	set CFG(init) 0
}

#------------------------------------------------------------------------------
# Initialisation
#------------------------------------------------------------------------------
core::args::register \
	-proc_name core::timezone::init \
	-args [list \
			[list -arg -default_time_zone -mand 0 -check ASCII -default_cfg DEFAULT_TIME_ZONE  -default "Europe/London" -desc {Configure the default time zone}] \
			[list -arg -func_time_zone    -mand 0 -check BOOL  -default_cfg FUNC_TIME_ZONE     -default 0               -desc {Configure to use the timezone conversion or just format the time}] \
			[list -arg -italy_time_zone   -mand 0 -check ASCII -default_cfg ITALY_TIME_ZONE    -default "Europe/Rome"   -desc {Configure the italian time zone}] \
			[list -arg -cust_mode         -mand 0 -check ASCII -default_cfg CUST_MODE          -default "DEFAULT"       -desc {Configure the cust mode e.g. ITALY)}] \
			[list -arg -func_italy        -mand 0 -check BOOL  -default_cfg FUNC_ITALY         -default 0               -desc {Configure the italian system is active}] \
			[list -arg -tz_cache_vlong    -mand 0 -check UINT  -default_cfg TZ_CACHE_VLONG     -default 300             -desc {Configure the query caching time}] \
		] \
	-body {
		variable CFG
		# already initialised
		if {$CFG(init)} {
			return
		}
		core::log::write DEBUG {core::timezone init}

		if {[catch {ot::timezone::load} msg]} {
			core::log::write WARNING {Could not load Tz Database.}
			set CFG(ot_timezone_not_load) 1
		} else {
			set CFG(ot_timezone_not_load) 0
		}

		# get configuration
		set CFG(default_time_zone)   $ARGS(-default_time_zone)
		set CFG(func_time_zone)      $ARGS(-func_time_zone)

		#
		# Italian Specific Config settings. Italian project was developed before
		# this library was modified to use Tz Database. Italian apps use timezone
		# codes as compared to timezone names. So these settings will be used to
		# assign the right timezone name for Italian customers.
		# This should be a temporary solution and Italian apps should be updated to
		# use new Tz Database timezone names.
		#
		set CFG(italy_time_zone)    $ARGS(-italy_time_zone)
		set CFG(cust_mode)          $ARGS(-cust_mode)
		set CFG(func_italy)         $ARGS(-func_italy)
		set CFG(tz_cache_vlong)     $ARGS(-tz_cache_vlong)

		_prep_qrys

		set CFG(init) 1
	}

proc core::timezone::_prep_qrys {} {
	variable CFG

	core::db::store_qry \
		-name  core::timezone::get_tzone_all \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				timezone_id,
				name,
				status,
				display
			from
				tTimeZone
			order by
				name
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				timezone_id,
				name,
				status,
				display
			from
				tTimeZone
			where
				name = ?
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_details \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				tz.timezone_id,
				tz.name,
				tzo.offset_id,
				tzo.code,
				tzo.offset,
				tzo.utc_start,
				tzo.is_dst,
				tzo.offset_year,
				tz.status,
				tz.display
			from
				tTimezone tz,
				tTimezoneOffset tzo
			where
				tz.timezone_id = tzo.timezone_id and
				tzo.offset_year = ? and
				tzo.code = ?
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_details_by_name \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				tz.timezone_id,
				tz.name,
				tzo.offset_id,
				tzo.code,
				tzo.offset,
				tzo.utc_start,
				tzo.is_dst,
				tzo.offset_year,
				tz.status,
				tz.display
			from
				tTimezone tz,
				tTimezoneOffset tzo
			where
				tz.timezone_id = tzo.timezone_id and
				tzo.offset_year = ? and
				tz.name = ?
			}

	core::db::store_qry \
		-name  core::timezone::ins_time_zone \
		-qry {
			insert into tTimezone (name) values (?)
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_by_status_disp \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				timezone_id,
				name,
				status,
				display
			from
				tTimeZone
			where
				status = ?
				and display = ?
			order by
				name
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_by_off_dbl \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select distinct
				tz.timezone_id,
				tz.name,
				tz.status,
				tz.display
			from
				tTimezone tz,
				tTimezoneOffset tzo1,
				tTimezoneOffset tzo2
			where
				tz.timezone_id = tzo1.timezone_id
				and tz.timezone_id = tzo2.timezone_id
				and tz.status = ?
				and tz.display = ?
				and tzo1.is_dst <> tzo2.is_dst
				and
				(
					(
						tzo1.offset = ?
						and tzo2.offset = ?
					)
					or
					(
						tzo1.offset = ?
						and tzo2.offset = ?
					)
				)
				and tzo1.offset_year = ?
				and tzo2.offset_year = tzo1.offset_year
			order by
				tz.name
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_by_off_sgl \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				tz.timezone_id,
				tz.name,
				tz.status,
				tz.display
			from
				tTimezone tz,
				tTimezoneOffset tzo
			where
				tz.timezone_id = tzo.timezone_id
				and tz.status = ?
				and tz.display = ?
				and tzo.offset_year = ?
				and tzo.offset = ?
				and (
					select
						count(*)
					from
						ttimezoneoffset tzo2
					where
						tzo2.timezone_id = tz.timezone_id
						and tzo2.offset_year = tzo.offset_year
					) = 1;
			}

	core::db::store_qry \
		-name  core::timezone::get_tzone_by_id \
		-cache $CFG(tz_cache_vlong) \
		-qry {
			select
				timezone_id,
				name,
				status,
				display
			from
				tTimeZone
			where
				timezone_id = ?
			}

	# un-cached. Should only be called on secure login.
	core::db::store_qry \
		-name core::timezone::get_cust_timezone \
		-qry {
			select
				tz.timezone_id
			from
				tTimeZone tz,
				tcustomerreg cr
			where
				cr.cust_id = ? and
				tz.timezone_id = cr.timezone_id
			}

	core::db::store_qry \
		-name core::timezone::ins_time_zone_offset \
		-qry {
			insert into tTimeZoneOffset (
				timezone_id,
				code,
				offset,
				utc_start,
				is_dst,
				offset_year
				)
			values (?, ?, ?, ?, ?, ?)
			}

	core::db::store_qry \
		-name core::timezone::upd_zone_status_by_name \
		-qry {
			update
				tTimeZone
			set
				status = ?,
				display = ?
			where
				name = ?
			}

	core::db::store_qry \
		-name core::timezone::upd_zone_status_by_id \
		-qry {
			update
				tTimeZone
			set
				status = ?,
				display = ?
			where
				timezone_id = ?
			}

	core::db::store_qry \
		-name core::timezone::upd_cust_time_zone \
		-qry {
			update
				tCustomerReg
			set
				timezone_id = ?
			where
				cust_id = ?
			}
}

#------------------------------------------------------------------------------
# proc:  _format_time
# desc:  Converts given time into specified timezone value using Tz database.
#        Using the details from Tz database about a timezone it calculates if
#        the given time falls into summer or winter time and then it offsets
#        the time with right value.
#  
proc core::timezone::_format_time {
	{utc ""}
	{timeZone ""}
	{timeFormat "%Y-%m-%d %H:%M:%S"}
	{direction "to"}
	{seconds 0}
	{zone_details_by_name 0}
} {

	set fn "core::timezone::_format_time"

	if {$timeZone == ""} {
		set timeZone [get_default_timezone_id]
	}

	# if from then multiply by -1
	set dir_type [expr {$direction == "from" ? -1 : 1}]

	if {$utc == ""} {
		set time_sec [clock seconds]
	} else {
		if {$direction == "from"} {
			set time_sec [clock scan $utc -gmt 1]
		} else {
			# Time in DB is stored in GMT/BST so we don't need -gmt flag
			set time_sec [clock scan $utc]
		}
	}

	#Get the year and find out the time zone details in that year.
	set year [clock format $time_sec -format %Y]

	set db_timezone_data [get_timezone \
		-zone_name $timeZone \
		-zone_details_by_name $zone_details_by_name \
		-year $year]

	set num_zones [dict get $db_timezone_data num_zones]

	# Return default (UK) time if no data found for a given time zone in a specific year. We
	# synchronise only limited no of years data (based on configs).
	if {$num_zones == 0} {
		core::log::write ERROR {$fn: Error. No data found for year $year and timezone $timeZone. Returning UK time}
		set new_time $time_sec
	} else {
		set start_date ""
		set end_date   ""

		set list_utc_start [dict get $db_timezone_data 0 $year utc_start]

		foreach utc_start $list_utc_start {

			set is_dst [dict get $db_timezone_data 0 $year $utc_start is_dst]
			set offset [dict get $db_timezone_data 0 $year $utc_start offset]

			if {$is_dst} {
				set dst_offset        [expr {$offset * $dir_type}]
				set start_date        $utc_start

			} else {
				set standard_offset   [expr {$offset * $dir_type}]
				set end_date          $utc_start

			}
		}

		# Find if the date we want to format is in the future or in the past
		if {$start_date != "" && (($start_date < $end_date && $time_sec > $start_date \
			&& $time_sec < $end_date) || ($start_date > $end_date && ($time_sec > $start_date \
			|| $time_sec < $end_date)))} {
			set new_time [expr {$time_sec + $dst_offset}]
		} else {
			set new_time [expr {$time_sec + $standard_offset}]
		}
	}

	if {$seconds} {
		return $new_time
	}

	if {$direction == "from"} {
		set new_time [clock format $new_time -format "$timeFormat"]
	} else {
		set new_time [clock format $new_time -format "$timeFormat" -gmt 1]
	}

	return $new_time
}

#------------------------------------------------------------------------------
# proc:  get_cust_timezone
# desc:  Public proc which retrieves the current user's time zone.  Checks the
#        user's registration date for associated timezone.  If none exists,
#        then default (server) time is used.
#
core::args::register \
	-proc_name core::timezone::get_cust_timezone \
	-desc {Retrieve the timezone associate to a specific customer} \
	-args [list \
		[list -arg -cust_id  -mand 0 -check UINT -desc {customer id}] \
	] \
	-body {
		set cust_id $ARGS(-cust_id)
		set fn "core::timezone::get_cust_timezone"

		if {$cust_id == ""} {
			return ""
		}

		set timezone_id [list]

		if {[catch {set rs [core::db::exec_qry -name core::timezone::get_cust_timezone -args [list $cust_id]]} msg]} {
			core::log::write ERROR {$fn: Error executing query core::timezone::get_cust_time_zone - $msg}
			return $timezone_id
		}

		if {[db_get_nrows $rs] == 1} {
			set timezone_id [db_get_col $rs 0 timezone_id]
		}
		core::db::rs_close -rs $rs

		return $timezone_id
	}

#------------------------------------------------------------------------------
# proc:  set_cust_timezone
# desc:  Public proc which sets the current user's time zone. tCustomerReg is
#        updated with new or default timezone.
#
core::args::register \
	-proc_name core::timezone::set_cust_timezone \
	-desc {Set the timezone associate to a specific customer} \
	-args [list \
		[list -arg -cust_id      -mand 1 -check UINT  -desc {customer id}] \
		[list -arg -timezone_id  -mand 1 -check UINT  -desc {timezone id to link}] \
	] \
	-body {
		set cust_id $ARGS(-cust_id)
		set timezone_id $ARGS(-timezone_id)

		set fn {core::timezone::set_cust_timezone}
		if {[catch {set rs [core::db::exec_qry -name core::timezone::upd_cust_time_zone -args [list $timezone_id $cust_id]]} msg]} {
			core::log::write ERROR {$fn: executing query core::timezone::upd_cust_time_zone - $msg}
			return 0
		}

		core::db::rs_close -rs $rs
		return 1
	}

#------------------------------------------------------------------------------
# proc:  get_timezone_list
# desc:  Public proc which retrieves a list of all timezones and their details
#        from Tz Database.
#
core::args::register \
	-proc_name core::timezone::get_timezone_list \
	-desc {Retrieve a list of all timezones for a specific year from the tz database with all their details.} \
	-args [list \
		[list -arg -year      -mand 1 -check {DIGITS -args {-min_str 4 -max_str 4}} -desc {Year}] \
	] \
	-body {

		variable CFG

		#initialization
		set db_timezone_data ""
		set tz_timezone_data ""

		set tz_list    [list] 
		set db_list    [list]
		set year $ARGS(-year)

		set fn "core::timezone::get_timezone_list"

		if {$CFG(ot_timezone_not_load)} {
			core::log::write WARNING {Could not load Tz Database in the initialization.}
		}
		set tz_name_list [lsort [ot::timezone::list]]
		set a 0
		set b 0

		foreach zone_name $tz_name_list {

			set zone_details [get_timezone -zone_name $zone_name -zone_details_by_name 1 -year $year]
			set num_zones [dict get $zone_details num_zones]

			if {$num_zones} {

				dict set db_timezone_data $a zone_id   [dict get $zone_details 0 zone_id]
				dict set db_timezone_data $a zone_name [dict get $zone_details 0 zone_name]
				dict set db_timezone_data $a status    [dict get $zone_details 0 status]
				dict set db_timezone_data $a display   [dict get $zone_details 0 display]

				# Initialize
				dict set db_timezone_data $a dst_code        -
				dict set db_timezone_data $a dst_offset      -
				dict set db_timezone_data $a dst_date        -
				dict set db_timezone_data $a standard_code   -
				dict set db_timezone_data $a standard_offset -
				dict set db_timezone_data $a standard_date   -

				set utc_starts [dict get $zone_details 0 $year utc_start]
				
				foreach utc_start $utc_starts {
					set is_dst [dict get $zone_details 0 $year $utc_start is_dst]

					if {$is_dst} {
						dict set db_timezone_data $a dst_code   [dict get $zone_details 0 $year $utc_start code]
						dict set db_timezone_data $a dst_offset [dict get $zone_details 0 $year $utc_start offset]
						dict set db_timezone_data $a dst_date   $utc_start

					} else {
						dict set db_timezone_data $a standard_code   [dict get $zone_details 0 $year $utc_start code]
						dict set db_timezone_data $a standard_offset [dict get $zone_details 0 $year $utc_start offset]
						dict set db_timezone_data $a standard_date   $utc_start

					}
				}
				incr a
			}

			if {[catch {set time_zone [ot::timezone::find $zone_name $year]} msg]} {
				core::log::write ERROR {$fn: Could not get timezone details for $zone_name $year}
			} else {
				if {[lindex [lindex $time_zone 0] 2]} {
					set DST_list [lindex $time_zone 0]
					set Std_list [lindex $time_zone 1]
				} else {
					set Std_list [lindex $time_zone 0]
					set DST_list [lindex $time_zone 1]
				}
				set std_start [lindex $Std_list 3]
				set dst_start [lindex $DST_list 3]

				dict set tz_timezone_data $b zone_name $zone_name

				# Initialize
				dict set tz_timezone_data $b dst_code        -
				dict set tz_timezone_data $b dst_offset      -
				dict set tz_timezone_data $b dst_date        -
				dict set tz_timezone_data $b standard_code   -
				dict set tz_timezone_data $b standard_offset -
				dict set tz_timezone_data $b standard_date   -


				if {$std_start != ""} {
					dict set tz_timezone_data $b dst_code   [lindex $DST_list 0]
					dict set tz_timezone_data $b dst_offset [lindex $DST_list 1]
					dict set tz_timezone_data $b dst_date   [lindex $DST_list 3]
				}

				if {$dst_start != ""} {
					dict set tz_timezone_data $b standard_code   [lindex $Std_list 0]
					dict set tz_timezone_data $b standard_offset [lindex $Std_list 1]
					dict set tz_timezone_data $b standard_date   [lindex $Std_list 3]
				}
			}
			incr b

		}

		dict set db_timezone_data num_records $a
		dict set tz_timezone_data num_records $b

		return [list 1 $db_timezone_data $tz_timezone_data]
	}

core::args::register \
	-proc_name core::timezone::check_timezone_status \
	-desc {Retrieve the status of a specific timezone} \
	-args [list \
		[list -arg -timezone_id  -mand 1 -check UINT -desc {timezone id}] \
	] \
	-body {
		set fn {core::timezone::check_timezone_status}
		set timezone_id $ARGS(-timezone_id)

		if {[catch {set rs [eval core::db::exec_qry -name core::timezone::get_tzone_by_id -args [list $timezone_id]]} msg]} {
			core::log::write ERROR {$fn: Error executing query $qry - $msg}
			return "A"
		}

		if {[db_get_nrows $rs] != "1"} {
			core::log::write WARNING {$fn found not only 1 timezone for $timezone_id}
			return "A"
		}

		set status [db_get_col $rs 0 status]

		core::db::rs_close -rs $rs

		return $status
	}


#------------------------------------------------------------------------------
# proc:  _get_timezone
# desc:  Private proc which retrieves the timezone details from tTimeZone.
# Argument
# zone_id   - default 0. If provide will get details of specified zone id.
# zone_name - default "". If provided and zone_id is 0 then it will return details
#             of zone with specified name.
# status    - default "" (return all) or A (Active)  or S (Suspended) or D (Deleted)
# offset    - default "". Timezone offset detected from customer browser
#
proc core::timezone::_get_timezone {
	year
	{zone_id   0 }
	{zone_name ""}
	{zone_details_by_name ""}
	{status    ""}
	{display   ""}
	{offset    ""}
} {

	set fn {core::timezone::_get_timezone}

	set details 1

	if {$zone_id != 0} {
		set qry    "core::timezone::get_tzone_by_id"
		set params  $zone_id
		set details 0
	} elseif {$zone_name != ""} {
		if {$zone_details_by_name} {
			set qry "core::timezone::get_tzone_details_by_name"
		} else {
			set qry "core::timezone::get_tzone_details"
		}
		set params  "$year $zone_name"
	} elseif {$offset != ""} {

		if {$status == ""} { 
			set status A
		}

		if {$display == ""} { 
			set display Y 
		}

		set std_offset [lindex $offset 0]
		set dst_offset [lindex $offset 1]
		set details 0

		if {$dst_offset == $std_offset} {
			set qry    "core::timezone::get_tzone_by_off_sgl"
			set params  [subst {$status $display $year $std_offset}]
		} else {
			set qry    "core::timezone::get_tzone_by_off_dbl"
			set params  [subst {$status $display $std_offset $dst_offset \
				$dst_offset $std_offset $year}]
		}

	} elseif {$status != "" && $display != ""} {
		set qry    "core::timezone::get_tzone_by_status_disp"
		set params  "$status $display"
		set details 0
	} else {
		set qry    "core::timezone::get_tzone_all"
		set params  ""
		set details 0
	}

	core::log::write INFO {$fn executing query $qry}

	if {[catch {set rs [core::db::exec_qry -name $qry -args [list $params]]} msg]} {
		core::log::write ERROR {$fn: Error executing query $qry - $msg}
		return [dict create {num_zones} 0]
	}

	set num_zones [db_get_nrows $rs]

	set j 0

	for {set a 0} {$a < $num_zones} {incr a} {

		if {$j >= $num_zones} {
			break
		}
		set zone_id [db_get_col $rs $j timezone_id]
		dict set zone_details $a zone_id   $zone_id
		dict set zone_details $a zone_name [db_get_col $rs $j name]
		dict set zone_details $a status    [db_get_col $rs $j status]
		dict set zone_details $a display   [db_get_col $rs $j display]

		#Only if query gets data from tTimeZoneOffset
		if {$details} {
			set year      [db_get_col $rs $j offset_year]
			set utc_start [db_get_col $rs $j utc_start]

			if {[dict exists $zone_details $a years]} {
				set current_years_list [dict get $zone_details $a years]
			} else {
				set current_years_list [list]
			}

			lappend current_years_list $year
			dict set zone_details $a years $current_years_list

			if {[dict exists $zone_details $a $year utc_start]} {
				set current_year_utc_start [dict get $zone_details $a $year utc_start]
			} else {
				set current_year_utc_start [list]
			}

			lappend current_year_utc_start $utc_start
			dict set zone_details $a $year utc_start $current_year_utc_start

			dict set zone_details $a $year $utc_start code  [db_get_col $rs $j code]
			dict set zone_details $a $year $utc_start offset [db_get_col $rs $j offset]
			dict set zone_details $a $year $utc_start is_dst [db_get_col $rs $j is_dst]

			incr j

			if {$j >= $num_zones} {
				break
			}

			set next_timezone_id [db_get_col $rs $j timezone_id]

			while {$zone_id == $next_timezone_id} {

				set offset_year [db_get_col $rs $j offset_year]
				if {$year != $offset_year } {
					set year $offset_year 
					set utc_start_loc [list]
					lappend utc_start_loc $utc_start
					dict set zone_details $a $year utc_start $utc_start_loc

					lappend current_years_list $year
				}

				set utc_start [db_get_col $rs $j utc_start]
				set current_year_utc_start [dict get $zone_details $a $year utc_start]
				lappend current_year_utc_start $utc_start
				dict set zone_details $a $year utc_start $current_year_utc_start

				dict set zone_details $a $year $utc_start code  [db_get_col $rs $j code]
				dict set zone_details $a $year $utc_start offset [db_get_col $rs $j offset]
				dict set zone_details $a $year $utc_start is_dst [db_get_col $rs $j is_dst]

				incr j

				if {$j >= $num_zones} {
					break
				}
				set next_timezone_id [db_get_col $rs $j timezone_id]
			}
		} else {
			incr j
		}
		
	}

	dict set zone_details num_zones $num_zones

	core::db::rs_close -rs $rs
	return $zone_details
}


#------------------------------------------------------------------------------
# proc:  get_tz_timezone
# desc:  Public proc which retrieves the timezone details from Tz database.
#
core::args::register \
	-proc_name core::timezone::get_tz_timezone \
	-desc {Retrieve all the information about a timezone from the tz database} \
	-args [list \
		[list -arg -timezone_id  -mand 1 -check UINT -desc {timezone id}] \
		[list -arg -year         -mand 0 -check {DIGITS -args {-min_str 4 -max_str 4}} -desc {year to find, in case it is not set, the proc will use the current year} -default {}] \
	] \
	-body {
		set fn "core::timezone: get_tz_timezone"
		set year        $ARGS(-year)
		set timezone_id $ARGS(-timezone_id)

		if {$year == ""} {
			set year [clock format [clock seconds] -format %Y]
		}

		if {[catch {set tz_details [ot::timezone::find $timezone_id $year]} msg]} {
			
			core::log::write ERROR {Error $timezone_id not found in Tz Database - $msg}
			return [upd_timezone -status D -timezone_id $timezone_id]
		}

		return $tz_details
	}


#------------------------------------------------------------------------------
# proc:  _add_timezone
# desc:  Private proc copy time zone details from Tz Database to Openbet Db.
#
proc core::timezone::_add_timezone {
	name
	standard_code
	standard_offset
	standard_start
	year
	status
	DST_code
	DST_offset
	DST_start
} {

	set fn "core::timezone::_add_timezone"

	if {[catch {set rs [core::db::exec_qry -name core::timezone::get_tzone -args [list $name]]} msg]} {
		core::log::write ERROR {$fn: Error executing query core::timezone::get_tzone - $msg}
		return 0
	}

	#If timezone already exists then get its id to insert the offset details otherwise
	#insert new timezone
	if {[db_get_nrows $rs] == 0} {
		if {[catch {core::db::exec_qry -name core::timezone::ins_time_zone -args [list $name]} msg]} {
			core::log::write ERROR {$fn: Error executing query core::timezone::ins_time_zone - $msg}
			core::db::rs_close -rs $rs
			return 0
		}
		set timezone_id [core::db::get_serial_number -name core::timezone::ins_time_zone]
	} else {
		set timezone_id [db_get_col $rs 0 timezone_id]
	}

	core::db::rs_close -rs $rs

	#Check if the timezone has already been added for a year.
	if {[catch {set rs [core::db::exec_qry -name core::timezone::get_tzone_details_by_name -args [list $year $name]]} msg]} {
		core::log::write ERROR {$fn: Error executing query core::timezone::get_tzone_details_by_name - $msg}
		return 0
	}

	if {[db_get_nrows $rs] == 0} {
		if {[catch {core::db::exec_qry -name core::timezone::ins_time_zone_offset \
			-args [list $timezone_id \
				$standard_code \
				$standard_offset \
				$standard_start \
				0 \
				$year] \
		} msg]} {
			core::log::write ERROR {$fn: Error executing query core::timezone::ins_time_zone_offset - $msg}
			core::db::rs_close -rs $rs
			return 0
		}

		#Insert DST data if required
		if {$DST_code != ""} {
			if {[catch {core::db::exec_qry -name core::timezone::ins_time_zone_offset \
				-args [list $timezone_id \
					$DST_code \
					$DST_offset \
					$DST_start \
					1 \
					$year] \
			} msg]} {
				core::log::write ERROR {$fn: Error executing query core::timezone::ins_time_zone_offset - $msg}
				core::db::rs_close -rs $rs
				return 0
			}
		}
	} else {
		core::log::write ERROR {$fn: Timezone $name already exists in Database for year $year.}
		core::db::rs_close -rs $rs
		return 0
	}

	core::db::rs_close -rs $rs
	return 1
}


#------------------------------------------------------------------------------
# proc: format_time
# desc: Converts a time (in a clock scan friendly format) between time zones
#       and returns the time in the specified format.  If time zone functions
#       are disabled by config, then no conversion takes place, but formatting
#       is still carried out.
#       To ensure consistent behaviour, this conversion is done independantly
#       of the timezone that tcl believes it is in, and instead works from the
#       time zone specified in the config.
#
# Input switches:-
# -time           - the time to be converted (current time if blank)
# -user_time_zone - the time zone the user is in (looks up for customer time
#                   zone if empty)
# -format         - the format in which to return the time
# -direction      - "to"   convert from server time zone to users time zone
#                 - "from" convert from users time zone to server time zone
# -seconds        - (0/1) take the input time as formatted (0) or seconds (1)
#                   and return either formatted or seconds, similarly.
# -cust_id        - Looks up for customer time zone (Defaults to Europe/London
#                   if cust_id is empty or timezone is not specified for user.)
#
core::args::register \
	-proc_name core::timezone::format_time \
	-desc {Converts a time between time zones and returns the time in the specified format} \
	-args [list \
			[list -arg -input_time            -mand 0 -check ANY                    -desc {time to be converted, if not specified the proc use the current time} -default {}] \
			[list -arg -user_time_zone        -mand 0 -check STRING                 -desc {timezone}                   -default {}] \
			[list -arg -time_format           -mand 0 -check ANY                    -desc {time format}               -default {%Y-%m-%d %H:%M:%S}] \
			[list -arg -direction             -mand 0 -check {ENUM -args {to from}} -desc {direction to or from}       -default {to}] \
			[list -arg -seconds               -mand 0 -check BOOL                   -desc {formatted or second}        -default 0] \
			[list -arg -cust_id               -mand 0 -check UINT                   -desc {customer id for the timezone (will take the associated one)} -default {}] \
			[list -arg -zone_details_by_name  -mand 0 -check BOOL                   -desc {search by code or by name} -default 0] \
	] \
	-body {
		variable CFG

		set fn "core::timezone::format_time"

		set input_time     $ARGS(-input_time)
		set user_time_zone $ARGS(-user_time_zone)
		set time_format    $ARGS(-time_format)
		set direction      $ARGS(-direction)
		set seconds        $ARGS(-seconds)
		set cust_id        $ARGS(-cust_id)

		# only used from admin
		set zone_details_by_name $ARGS(-zone_details_by_name)

		if {$input_time == ""} {
			# If input time not specified, then get the time now
			set input_time [clock format [clock seconds]]
		} else {
			# If the time was specified in seconds, format it
			if {$seconds} {
				set input_time [clock format $input_time]
			}
		}

		# If timezone functions are disabled, just format the time
		if {!$CFG(func_time_zone)} {
			core::log::write DEBUG {$fn: Time zone conversion disabled, nothing to do}

			if {$seconds} {
				return [clock scan $input_time]
			} else {
				return [clock format [clock scan $input_time] -format $time_format]
			}
		}

		core::log::write DEBUG {$fn: '$input_time' '$user_time_zone' '$time_format' '$direction'}

		# If functioning as the Italia site, then force time zone to Italian
		if {[is_italy]} {
			set user_time_zone [get_italy_timezone]
			core::log::write INFO {$fn: Italy mode, users time zone set to $user_time_zone}
		} elseif {$user_time_zone == "" && $cust_id != ""} {
			set user_time_zone [get_cust_timezone -cust_id $cust_id]
		}

		core::log::write DEBUG {$fn: Converting '$input_time' to $user_time_zone}

		# Now perform conversion to desired timezone
		set ret_time [_format_time \
			$input_time \
			$user_time_zone \
			$time_format \
			$direction \
			$seconds \
			$zone_details_by_name]

		return $ret_time
	
	}

core::args::register \
	-proc_name core::timezone::get_italy_timezone \
	-desc {Retrieve the italian timezone} \
	-body {
		variable CFG

		set db_timezone_data [get_timezone \
			-zone_details_by_name 1 \
			-zone_name $CFG(italy_time_zone)]

		set num_zones [dict get $db_timezone_data num_zones]

		if {$num_zones != 0} {
			set timezone_id [dict get $db_timezone_data 0 zone_id]
		} else {
			# we should never not have the italian timezone but in case we're on test...
			set timezone_id [get_default_timezone_id]
		}

		return $timezone_id
	}

core::args::register \
	-proc_name core::timezone::is_italy \
	-desc {Check if the Italian cust mode is active and activateable} \
	-body {
		variable CFG

		if {($CFG(cust_mode) == "ITALY") && $CFG(func_italy)} {
			return 1
		} else {
			return 0
		}
	}

#------------------------------------------------------------------------------
# Update timezone status and display in tTimeZone provided ID or zone name.
# If this proc is called to update status using tZoneName, then the second
# parameter should be empty with third one as zone name.
core::args::register \
	-proc_name core::timezone::upd_timezone \
	-desc {Update the status and/or display informations of a specific timezone by id or name} \
	-args [list \
			[list -arg -timezone_id    -mand 1 -check UINT                 -desc {timezone id}] \
			[list -arg -status         -mand 0 -check {ENUM -args {A S D}} -desc {status} -default {}] \
			[list -arg -display        -mand 0 -check {ENUM -args {Y N}}   -desc {display} -default {}] \
			[list -arg -timezone_name  -mand 0 -check ASCII                -desc {timezone name} -default {}] \
	] \
	-body {
		set fn {core::timezone::upd_timezone}

		set status        $ARGS(-status)
		set display       $ARGS(-display)
		set timezone_id   $ARGS(-timezone_id)
		set timezone_name $ARGS(-timezone_name)

		if {$timezone_name == ""} {
			set qry    "core::timezone::upd_zone_status_by_id"
			set params "$status $display $timezone_id"
		} else {
			set qry    "core::timezone::upd_zone_status_by_name"
			set params "$status $display $timezone_name"
		}

		if {[catch {set rs [core::db::exec_qry -name $qry -args $params]} msg]} {
			core::log::write ERROR {$fn: Error executing query $qry - $msg}
			return 0
		}

		core::db::rs_close -rs $rs
		core::log::write INFO {$fn: Successfully updated status and display for zone $timezone_id $timezone_name.}

		return 1
	}

core::args::register \
	-proc_name core::timezone::get_default_timezone_id \
	-desc {Retrieve the default timezone of system} \
	-body {
		return [core::control::get -name default_timezone]
	}


#------------------------------------------------------------------------------
# Public wrapper proc for _add_timezone
core::args::register \
	-proc_name core::timezone::add_timezone \
	-desc {Add in the system a new timezone entry} \
	-args [list \
			[list -arg -name               -mand 1 -check ASCII                                  -desc {timezone name}] \
			[list -arg -standard_code      -mand 1 -check ASCII                                  -desc {code}] \
			[list -arg -standard_offset    -mand 1 -check UINT                                   -desc {offset}] \
			[list -arg -standard_start     -mand 1 -check UINT                                  -desc {start}] \
			[list -arg -year               -mand 1 -check {DIGITS -args {-min_str 4 -max_str 4}} -desc {year}] \
			[list -arg -status             -mand 0 -check {ENUM -args {A S D}}                   -desc {status}      -default {A}] \
			[list -arg -DST_code           -mand 0 -check ASCII                                  -desc {DST code}    -default {}] \
			[list -arg -DST_offset         -mand 0 -check UINT                                   -desc {DST offset}  -default {}] \
			[list -arg -DST_start          -mand 0 -check UINT                                   -desc {DST start}   -default {}] \
	] \
	-body {
		return [_add_timezone \
			$ARGS(-name) \
			$ARGS(-standard_code) \
			$ARGS(-standard_offset) \
			$ARGS(-standard_start) \
			$ARGS(-year) \
			$ARGS(-status) \
			$ARGS(-DST_code) \
			$ARGS(-DST_offset) \
			$ARGS(-DST_start)]
	}

#------------------------------------------------------------------------------
# Public wrapper proc for _get_timezone
#
core::args::register \
	-proc_name core::timezone::get_timezone \
	-desc {Retrieve all the information about a timezone by id, code or name} \
	-args [list \
			[list -arg -zone_id               -mand 0 -check UINT                                   -desc {timezone id}           -default 0] \
			[list -arg -zone_name             -mand 0 -check ASCII                                  -desc {timezone name: it has a double meaning: code or name depending on the zone_details_by_name} -default {}] \
			[list -arg -status                -mand 0 -check {ENUM -args {A S D}}                   -desc {status}                -default {}] \
			[list -arg -display               -mand 0 -check {ENUM -args {Y N}}                     -desc {display}               -default {}] \
			[list -arg -offset                -mand 0 -check STRING                                 -desc {offset}                -default {}] \
			[list -arg -year                  -mand 0 -check {DIGITS -args {-min_str 4 -max_str 4}} -desc {year}                  -default {}] \
			[list -arg -zone_details_by_name  -mand 0 -check BOOL                                   -desc {search timezone by code or by name when the zone id is not set} -default 0] \
	] \
	-body {
		set fn "core::timezone: get_timezone"
		set zone_id   $ARGS(-zone_id)
		set zone_name $ARGS(-zone_name)
		set status    $ARGS(-status)
		set display   $ARGS(-display)
		set offset    $ARGS(-offset)
		set year      $ARGS(-year)

		set zone_details_by_name $ARGS(-zone_details_by_name)

		if {$ARGS(-year) == ""} {
			set year [clock format [clock seconds] -format %Y]
		}

		return [_get_timezone \
			$year \
			$zone_id \
			$zone_name \
			$zone_details_by_name \
			$status \
			$display \
			$offset]
	}
