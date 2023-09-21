#! /usr/bin/tclsh

# $Id: queue.tcl,v 1.1 2011/10/04 12:40:37 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Checks for queued customer verification requests and makes them
#



# Command usage
#
set usage "usage: [info script]: ?-h|--help? cfg

  -h, --help    - this help
  cfg           - the configuration file"

if {[llength $argv] == 0
	|| [lindex $argv 0] == "--help"
	|| [lindex $argv 0] == "-h"} {
	puts stderr $usage
	exit 1
}



# Libraries
#
if {[catch {
	foreach lib {
		libOT_InfTcl.so
		libOT_Tcl.so
	} {
		load $lib
	}
}]} {
	puts stderr "[info script]: no $lib on \$LD_LIBRARY_PATH"
	exit 1
}



# Configuration
#
set cfg_file [lindex $argv 0]

puts -nonewline "Reading config $cfg_file"
OT_CfgRead $cfg_file
puts "done"

lappend auto_path [OT_CfgGet TCL_SHARED_PKG_DIR]
set xtn        [OT_CfgGet TCL_APP_XTN tcl]
set callback   [OT_CfgGet OVS_QUEUE_CALLBACK]
set max_checks [OT_CfgGet OVS_QUEUE_MAX_CHECKS]
set channel    [OT_CfgGet OVS_QUEUE_CHANNEL]


source [OT_CfgGet OVS_QUEUE_CALLBACK_PATH]

# Dependencies
#
package require bin_standalone
package require util_log
package require util_db

package require cust_kyc
package require ovs_ovs
package require [OT_CfgGet OVS_QUEUE_PKG]



# Initialisation
#
ob_log::sl_init \
	[OT_CfgGet LOG_DIR .] \
	[OT_CfgGet LOG_FILE cron.log.%Y-%m-%d] \
	-symlevel [OT_CfgGet LOG_SYMLEVEL INFO]

ob_sl::init -as_restart_exit 1

ob_db::sl_init \
	[OT_CfgGet DB_SERVER] \
	[OT_CfgGet DB_DATABASE] \
	-username [OT_CfgGet DB_USERNAME 0] \
	-password [OT_CfgGet DB_PASSWORD 0] \
	-prep_ondemand [OT_CfgGet DB_PREP_ONDEMAND 0] \
	-no_cache [OT_CfgGet DB_NO_CACHE 0]

ob_kyc::init

# source shared_tcl
foreach f {
	qas
} {
	source [file join [OT_CfgGet TCL_SHARED_PKG_DIR tcl] \
		$f.$xtn]
}

# DB Queries
ob_db::store_qry get_queue_entries [subst {
	select first $max_checks
		cust_id,
		vrf_prfl_def_id profile_def_id
	from
		tVrfCustQueue
}]

ob_db::store_qry get_queue_count {
	select
		count(*) as count
	from
		tVrfCustQueue
}

ob_db::store_qry delete_queue_entry {
	delete from
		tVrfCustQueue
	where
		cust_id = ?
	and vrf_prfl_def_id = ?
}

ob_db::store_qry get_customer_details {
	select
		r.fname         as forename,
		r.lname         as surname,
		r.gender,
		r.dob,
		r.addr_street_1 as building_no,
		r.addr_street_2 as street,
		r.addr_street_3 as sub_street,
		r.addr_street_4 as town,
		r.addr_city     as district,
		r.addr_postcode as postcode,
		r.telephone     as telephone,
		c.country_code  as country
	from
		tCustomerReg r,
		tCustomer c
	where c.cust_id = ?
	and c.cust_id = r.cust_id
	and c.type <> 'D'
}



# Start processing queue
set res   [ob_db::exec_qry get_queue_entries]
set nrows [db_get_nrows $res]

ob_log::write DEBUG {OVS_QUEUE: Processing $nrows checks}

for {set n 0} {$n < $nrows} {incr n} {
	catch {unset PROFILE}
	array set PROFILE [ob_ovs::get_empty]

	foreach col [db_get_colnames $res] {
		set PROFILE($col) [db_get_col $res $n $col]
	}

	ob_log::write INFO \
		{OVS_QUEUE: Verifying $PROFILE(cust_id) against $PROFILE(profile_def_id)}

	if {[catch {
		set res2 [ob_db::exec_qry get_customer_details $PROFILE(cust_id)]
	} msg]} {
		ob_db::rs_close $res
		ob_log::write ERROR {OVS_QUEUE: Failed to run get_customer_details: $msg}
		exit 1
	}

	if {[db_get_nrows $res2] != 1} {
		ob_db::rs_close $res2
		ob_db::rs_close $res
		ob_log::write ERROR \
			{OVS_QUEUE: get_customer_details returned wrong number of rows}
		exit 1
	}

	foreach col [list \
		building_no \
		street \
		sub_street \
		town \
		district \
		postcode] {
		set PROFILE(address1,$col) [db_get_col $res2 0 $col]
	}

	# oh, the filth!
	# this is hardcoded in the server code too -- would be nice if we had a more generic way of
	# coping with this... but ovs/shared_tcl/auth_pro.tcl *requires* these fields
	set PROFILE(address1,addr_street_1) $PROFILE(address1,building_no)
	set PROFILE(address1,addr_street_2) $PROFILE(address1,street)

	foreach col [list \
		forename \
		surname \
		gender \
		country] {
		set PROFILE($col) [db_get_col $res2 0 $col]
	}

	foreach [list \
		PROFILE(dob_year) \
		PROFILE(dob_month) \
		PROFILE(dob_day)] [split [db_get_col $res2 0 dob] "-"] {
		break
	}

	set PROFILE(telephone,number) [db_get_col $res2 0 telephone]

	ob_db::rs_close $res2

	set PROFILE(callback) $callback
	set PROFILE(channel)  $channel

	foreach path [lsort [array names PROFILE]] {
		ob_log::write DEV {OVS_QUEUE: PROFILE($path) = $PROFILE($path)}
	}

	if {[catch {
		foreach {result data} [ob_ovs::run_profile [array get PROFILE]] {break}
	} msg]} {
		ob_db::rs_close $res
		ob_log::write ERROR {OVS_QUEUE: Critical error running verification: $msg}
		exit 1
	}

	if {$result == "OB_OK"} {

		set cust_id $PROFILE(cust_id)
		set pd_id   $PROFILE(profile_def_id)
		# Delete the entry from the queue
		ob_db::exec_qry delete_queue_entry $cust_id $pd_id

		# Check the number left
		set res2     [ob_db::exec_qry get_queue_count]
		set q_length [db_get_col $res2 count]

		ob_log::write INFO \
			{OVS_QUEUE: Completed $pd_id for $cust_id and removed from queue.}
		ob_log::write INFO \
			{OVS_QUEUE: $q_length queries remaining}

		ob_db::rs_close $res2
	}
}

ob_db::rs_close $res

ob_db::req_end

exit 0
