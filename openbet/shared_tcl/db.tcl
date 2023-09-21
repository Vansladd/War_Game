# ==============================================================
#
# $Id: db.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# --------------------------------------------------------------
#
# Wrappers around the informix C API.
#
# Statements are prepared and cached.
# Result sets can be cached for a specified number of seconds
#
#
# USE:
# you must import the namespace with:
# namespace import OB_db::*
#
# before using any of the other procedures you must call:
# db_init
#
#
# Required config values.
#
# DB_SERVER
# DB_DATABASE
# DB_USERNAME
# DB_PASSWORD
#
# optional config values.
#
# DB_PREP_ONDEMAND     - prepare statements on first use
# DB_NO_CACHE          - globally disable result set cache
# DB_NO_PREPARED_QRYS  - don't keep prepared statments
# DB_LOG_QRY_TIME      - log query time
#
# DB_WAIT_TIME         - set lock wait time
# DB_ISOLATION_LEVEL   - set isolation level
#
# DB_DEFAULT_PDQ       - the default pdq priority to use
# DB_MAX_PDQ           - the maximum pdq priorites that can be
#                      - that can be set through the interfaces here
# ==============================================================


namespace eval OB_db {

	namespace export db_init

	namespace export db_store_qry
	namespace export db_exec_qry
	namespace export db_exec_qry_force
	namespace export db_unprep_qry
	namespace export db_close
	namespace export db_invalidate_stmt

	namespace export db_begin_tran
	namespace export db_commit_tran
	namespace export db_rollback_tran

	namespace export db_push_pdq
	namespace export db_pop_pdq

	namespace export db_garc
	namespace export db_get_serial

	namespace export req_end

	variable  db_data


	#
	# result set cache/expire time lists kept in expirey time order
	#

	set db_data(rs_list) [list]
	set db_data(rs_exp)  [list]


	#
	# PDQ stack
	#

	set pdq_list         [list]


	#
	# db.tcl config values
	#

	variable  db_cfg
	array set db_cfg  [list]

	variable in_tran
	set      in_tran 0

	variable tran_start

	variable ERRS_OK
	variable ERRS_REPREP
	variable ERRS_RECONN

	set      ERRS_OK     {-746 -268 -530 -1213}
	set      ERRS_REPREP {-710 -721 -908}
	set      ERRS_RECONN {-1803 -25582 -25580}
}


#
# the exported database connection
#

global DB


#
# initialise the module and connect to the specified database
#

proc OB_db::db_init {} {

	global DB
	variable db_cfg
	variable db_data

	package require OB_Log

	if { [catch {
		package present Infsql
	}] } {
		if { [catch {
			load libOT_InfTcl.so
		} err] } {
			error "failed to load Informix TCL library: $err"
		}
	}

	read_config

	db_connect

	set db_data(rss) {}
}


#
# Internal function.
#
# Config values are read once at startup and stored in the
# db_cfg array for future use
#
proc OB_db::read_config {} {

	variable db_cfg

	if {[info exists db_cfg(config_read)]} {
		return
	}

	set db_cfg(DB_SERVER)     [OT_CfgGet DB_SERVER]
	set db_cfg(DB_DATABASE)   [OT_CfgGet DB_DATABASE]
	set db_cfg(DB_USER)       [OT_CfgGet DB_USERNAME 0]
	set db_cfg(DB_PASSWORD)   [OT_CfgGet DB_PASSWORD 0]
	set db_cfg(prep_ondemand) [OT_CfgGetTrue DB_PREP_ONDEMAND]
	set db_cfg(no_cache)      [OT_CfgGetTrue DB_NO_CACHE]
	set db_cfg(no_prep_qrys)  [OT_CfgGet DB_NO_PREPARED_QRYS 0]
	set db_cfg(wait)          [OT_CfgGet DB_WAIT_TIME 20]
	set db_cfg(iso)           [OT_CfgGet DB_ISOLATION_LEVEL 0]
	set db_cfg(log_time)      [OT_CfgGet DB_LOG_QRY_TIME 1]
	set db_cfg(pdq)           [OT_CfgGet DB_DEFAULT_PDQ 0]
	set db_cfg(max_pdq)       [OT_CfgGet DB_MAX_PDQ 0]

	# application server has shm_cache support
	if {[info commands asFindRs] == "asFindRs"} {
		set db_cfg(shm_cache) 1
	} else {
		set db_cfg(shm_cache) 0
	}

	# application server has status string support
	if {[info commands asSetStatus] == "asSetStatus"} {
		set db_cfg(set_status) 1
	} else {
		set db_cfg(set_status) 0
	}

	# application server can report current status
	if {[info commands asGetStatus] == "asGetStatus"} {
		set db_cfg(get_status) 1
	} else {
		set db_cfg(get_status) 0
	}

	# application server supports concept of requests (not in standalone)
	if {[info commands reqGetId] == "reqGetId"} {
		set db_cfg(has_reqs) 1
	} else {
		set db_cfg(has_reqs) 0
	}
}


#
# Internal function.
#
# connect to a server using values read from the config file, it
# is used either at startup or in situations where the database
# connection has gone away for some reason.
#
proc OB_db::db_connect {} {

	global DB
	variable db_cfg
	variable db_data
	variable pdq_list

	set serv  $db_cfg(DB_SERVER)
	set dbase $db_cfg(DB_DATABASE)
	set user  $db_cfg(DB_USER)
	set pass  $db_cfg(DB_PASSWORD)

	ob::log::write INFO {db_connect:connecting to db}

	if {[catch {
		if {$user == 0} {
			set DB [inf_open_conn ${dbase}@${serv} ]
		} else {
			set DB [inf_open_conn ${dbase}@${serv} $user $pass]
		}
	} msg]} {
		asRestart
 		error "failed to open connection to database server $msg"
		return 0
	}

	#
	# set lock mode & isolation level based on config file
	#
	if {$db_cfg(wait) != 0} {
		set s1 [inf_prep_sql $DB "set lock mode to wait $db_cfg(wait)"]
		inf_exec_stmt $s1
		inf_close_stmt $s1
	}

	if {$db_cfg(iso) != 0} {
		set s1 [inf_prep_sql $DB "set isolation to $db_cfg(iso)"]
		inf_exec_stmt $s1
		inf_close_stmt $s1
	}

	set pdq_list $db_cfg(pdq)

	if {$db_cfg(pdq) > 0}  {
		set_pdq $db_cfg(pdq)
	}

	#
	# unset previously prepared statements
	#

	foreach stmt [array names db_data "*,stmt"] {
		unset db_data($stmt)
	}


	return 1
}



#
# store a named query, cache is the number of seconds to cache
# any result sets associated with this query
#

proc OB_db::db_store_qry {name qry {cache 0} {qry_cache -1}} {

	variable db_cfg
	variable db_data

	if {[info exists db_data($name,qry_string)]} {
		# There was a long-standing bug in this code
		# where this check didn't work. To stop things
		# breaking too badly now it's fixed,
		# I'll let the user off with a warning if he tries
		# to prepare the same sql with the same cache time

		if {$db_data($name,qry_string) == $qry &&
			$db_data($name,cache_time) == $cache &&
			$db_data($name,qry_cache) == $qry_cache} {
			ob::log::write CRITICAL {***********************************}
			ob::log::write CRITICAL {* WARNING! Trying to reprepare qry:}
			ob::log::write CRITICAL {* $name}
			ob::log::write CRITICAL {* Future versions of db.tcl may throw an error here!}
			ob::log::write CRITICAL {* Check your code!}
			ob::log::write CRITICAL {***********************************}
			return
		}
		error "Query named $name already exists and your sql or cache_time is different"
	}

	if {$name == "rs" || [regexp {,} $name]} {
		error "Query cannot be named $name"
	}

	if {$db_cfg(no_cache)} {
		set cache 0
	}

	array set db_data [list \
				   $name,name       $name\
				   $name,qry_string $qry\
				   $name,cache_time $cache\
				   $name,qry_cache  $qry_cache]

	db_reset_stats $name

	if {!$db_cfg(prep_ondemand)} {
		if {[catch {db_new_prep_qry $name} msg]} {
			ob::log::write WARNING {Failed to prepare query: $msg}
			asRestart
			error $msg
		}
	}

}

proc OB_db::db_reset_stats {name} {
	variable db_data

	set db_data($name,exec_count) 0
	set db_data($name,prep_count) 0
	set db_data($name,cache_hits) 0
	set db_data($name,min_time)   999999
	set db_data($name,max_time)   0
	set db_data($name,tot_time)   0
}



#
# Internal function.
#
# prepare a named query, called from db_store_qry or when required
# if DB_PREP_ONDEMAND is set
#

proc OB_db::db_new_prep_qry {name} {

	global DB

	variable db_data

	ob::log::write DEBUG {DB: Preparing query $name}

	if {[info exists db_data($name,stmt)]} {
		inf_close_stmt $db_data($name,stmt)
	}

	set  now [clock seconds]
	if {[catch {set stmt [try_prep_qry $db_data($name,qry_string)]} msg]} {
		db_print_qry $msg $name
		error $msg
	}

	set  db_data($name,stmt)       $stmt
	set  db_data($name,prep_time)  $now
	set  db_data($name,rs_valid)   $now
	incr db_data($name,prep_count)

	if {[info exists db_data($name,stmt_invalid)]} {
		unset db_data($name,stmt_invalid)
	}

}

#
# Unprepare a query previously stored with db_store_qry.
#

proc OB_db::db_unprep_qry {name} {

	global DB

	variable db_data

	ob::log::write DEBUG {DB: Unpreparing statement $name}

	if {[info exists db_data($name,stmt)]} {
		inf_close_stmt $db_data($name,stmt)
	}

	foreach key [array names db_data "$name,*"] {
		unset db_data($key)
	}

	return
}

#
# Internal function.
#
# Try to prepare a sql query, handle connection errors
# if possible
#
proc OB_db::try_prep_qry {qry {IN_REPREP 0}} {

	global DB
	variable ERRS_RECONN

	if {[catch {set stmt [inf_prep_sql $DB $qry]} msg]} {
		set err_code [db_get_err_code $msg]

		if {[lsearch $ERRS_RECONN $err_code] >= 0 || $IN_REPREP} {
			ob::log::write WARNING {DB: in prep, attempting reconnection}
			db_connect
			return [try_prep_qry $qry 1]
		} else {
			error $msg
		}
	}

	return $stmt
}


#
# mark a statement as invalid
#
proc OB_db::db_invalidate_stmt {name} {

	variable db_data

	ob::log::write DEBUG {DB: Marking stmt $name invalid}
	set db_data($name,stmt_invalid) [clock seconds]
}


#
# execute a query and return the result set (if any)
# may return a cached result set if possible
#
proc OB_db::db_exec_qry {name args} {
	return [eval {db_exec_qry_ $name 0} $args]
}


#
# Same as db_exec_qry, except that the query is run even if there
# is a suitable cached result set. Use with care.
#
proc OB_db::db_exec_qry_force {name args} {
	return [eval {db_exec_qry_ $name 1} $args]
}


#
# Internal function.
#
# Same as db_exec_qry, except that the query is run even if there
# is a suitable cached result set. Use with care.
#
proc OB_db::db_exec_qry_ {name force args} {

	variable db_data
	variable db_cfg

	if {![info exists db_data($name,qry_string)]} {
		error "DB: statement $name does not exist"
	}

	ob::log::write INFO {DB: executing -$name- with args: $args}

	if {$db_cfg(shm_cache)} {
		return [db_exec_qry_shm    $name $force $args]
	} else {
		return [db_exec_qry_no_shm $name $args]
	}
}


#
# Internal function.
#
# this is called if the application has detected shared memory
#

proc OB_db::db_exec_qry_shm {name force arglist} {

	variable db_data
	variable db_cfg

	set cache $db_data($name,cache_time)

	set rs_key [db_mk_rs_key $name $arglist]
	# check if we have a cached rs
	set argkey [join $arglist ","]

	if {$cache} {

		# A result set can be reused within the same request as it
		# wont be cleaned up by the appserver until req_end. But
		# we can't store it if the query is cached during main_init
		# (which we identify with a request id of 0) as it will be
		# cleared by the appserver when main_init is finished.
		if {$db_cfg(has_reqs) && [reqGetId] == 0} {
			ob::log::write INFO {Not reusing cached rs}
			set reuse_cached_rs 0
		} else {
			set reuse_cached_rs 1
		}

		if {!$force && [info exists db_data($rs_key,rs)]} {

			set rs $db_data($name,$argkey,rs)

		} elseif {!$force && ![catch {set rs [asFindRs $rs_key]}]} {

			if {$reuse_cached_rs} {
				set db_data($name,$argkey,rs) $rs

				lappend db_data(rss) $rs_key,rs
			}

		} else {

			set rs [db_run_qry $name $arglist]

			if {[catch {asStoreRs $rs $rs_key $cache} msg]} {
				ob::log::write WARNING {asStoreRs failed: $msg}
			}

			if {$reuse_cached_rs} {
				set db_data($rs_key,rs) $rs

				lappend db_data(rss) $rs_key,rs
			}

		}

	} else {

		set rs [db_run_qry $name $arglist]

	}

	return $rs
}


#
# Generate the key to identify a qry result set in shared memory
#
proc OB_db::db_mk_rs_key {name arglist} {
	return "$name,[join $arglist ,]"
}

#
# Internal function.
#

proc OB_db::db_run_qry {name vals} {

	variable db_data
	variable db_cfg

	if {![info exists db_data($name,stmt)] ||
		[info exists db_data($name,stmt_invalid)]} {
		db_new_prep_qry $name
	}

	set now [clock seconds]

	# set the status string if supported
	if {$db_cfg(get_status)} {
		set status_str [asGetStatus]
	}
	if {$db_cfg(set_status)} {
		asSetStatus "db: [clock format $now -format "%T"] - $name"
	}

	if {[catch {set rs [db_exec_stmt $name $vals]} msg]} {
		db_print_qry $msg $name $vals
		error $msg
	}

	if {$db_cfg(get_status)} {
		asSetStatus $status_str
	} else {
		asSetStatus ""
	}

	set qry_time [expr {[clock seconds] - $now}]

	incr db_data($name,exec_count)
	set  db_data($name,min_time) [min $qry_time $db_data($name,min_time)]
	set  db_data($name,max_time) [max $qry_time $db_data($name,max_time)]
	incr db_data($name,tot_time) $qry_time

	return $rs
}


#
# Internal function.
#
# execute a query in application servers that do not
# have shared memory caching support
#

proc OB_db::db_exec_qry_no_shm {name arglist} {

	variable db_data
	variable db_cfg

	if {![info exists db_data($name,qry_string)]} {
		error "statement $name does not exist"
	}



	set cache $db_data($name,cache_time)


	# check if we have a cached rs
	set argkey [join $arglist ","]
	set now [clock seconds]
	if {$cache && [info exists db_data($name,$argkey,rs)]} {

		set valid_time $db_data($name,rs_valid)

		set exec_time  $db_data($name,$argkey,time)

		if {$exec_time >= $valid_time &&
			[expr {$exec_time + $cache}] >= $now} {

			ob::log::write DEBUG {DB: using cache}
			incr    db_data($name,cache_hits)
			return $db_data($name,$argkey,rs)
		}


	}

	if {![info exists db_data($name,stmt)] ||
		[info exists db_data($name,stmt_invalid)]} {
		ob::log::write WARNING {preparing statement $name on demand}
		db_new_prep_qry $name
	}

	if {[catch {set rs [db_exec_stmt $name $arglist]} msg]} {
		db_print_qry $msg $name $arglist
		error $msg
	}

	set qry_time [expr {[clock seconds] - $now}]

	incr db_data($name,exec_count)
	set  db_data($name,min_time) [min $qry_time $db_data($name,min_time)]
	set  db_data($name,max_time) [max $qry_time $db_data($name,max_time)]
	incr db_data($name,tot_time) $qry_time

	if {$db_cfg(no_prep_qrys) == 1} {
		db_unprep_qry $name
	}

	# store the rs in cache if desired
	if {$cache && ($rs != "")} {

		# purge any previously cached rs

		if {[info exists db_data($name,$argkey,rs)]} {
			purge_rs
		}
		set now [clock seconds]

		ob::log::write DEBUG {DB: storing result set in cache}
		set db_data($name,$argkey,rs) $rs
		set db_data($name,$argkey,time) $now

		# store the reverse lookup key
		set db_data(rs,$rs,argkey)   $argkey
		set db_data(rs,$rs,qry_name) $name

		# store the result set and expiry time
		# sorted in exp time order

		set exp [expr {$now + $cache}]

		set rs_exp  $db_data(rs_exp)
		set llength [llength $rs_exp]

		for {set i 0} {$i < $llength} {incr i} {
			if {[lindex $rs_exp $i] > $exp} {
				if {$i > 0} {incr i -1}
				break
			}
		}


		set db_data(rs_exp)  [linsert $rs_exp $i $exp]
		set db_data(rs_list) [linsert $db_data(rs_list) $i $rs]
	}

	return $rs
}

#
# Internal function.
#
# function that actually executes the query, again this is
# only for internal use within db.tcl

proc OB_db::db_exec_stmt {name vals {IN_REPREP 0}} {

	variable db_data
	variable db_cfg
	variable ERRS_OK
	variable in_tran

	set exec_stmt [list inf_exec_stmt $db_data($name,stmt)]
	foreach arg $vals {
		lappend exec_stmt $arg
	}

	ob::log::write INFO {DB: executing -$name- with args: $vals}
	ob::log::write DEBUG {DB: evalstr: $exec_stmt}

#	set exec_stmt [concat inf_exec_stmt $db_data($name,stmt) $exec_stmt]

	if {$db_cfg(log_time)} {
		set t0 [OT_MicroTime -micro]
	}

	if {[catch {set rs [eval $exec_stmt]} msg]} {
		set err_code [db_get_err_code $msg]

		if {[lsearch $ERRS_OK $err_code] >= 0} {

			# let through these exceptions
			# to be handled by the client
			error $msg
		} elseif {!$IN_REPREP && !$in_tran} {

			return [try_handle_err $err_code $name $vals $msg]
		} else {
			ob::log::write WARNING {unable to handle error: IN_REPREP $IN_REPREP, in_tran $in_tran}
			ob::log::write WARNING {err_code $err_code ... $name $vals $msg}
			asRestart
			error $msg
		}
	}

	ob::log::write DEBUG {DB: [db_garc $name] rows Probably affected}
	if {$db_cfg(log_time)} {
		if {[catch {
			set t1 [OT_MicroTime -micro]
			set tt [expr {$t1-$t0}]
			ob::log::write INFO {DB::EXEC $name [format %0.4f $tt]}
		} msg]} {
			ob::log::write INFO {ignoring floating-point error: t1 ${t1}, t0 ${t0}}
			catch {
				ob::log::write INFO {DB::EXEC $name [format %0.4f [expr {$t1-$t0}]]}
			}
		}
	}
	return $rs
}

#
# Internal function.
#
# In the event of an error in preparing or executing a statement
# this function prints out nicely formatted version of the sql
# showing intended parameters next to placeholders
#


proc OB_db::db_print_qry {msg name {qry_args ""}} {

	variable db_data
	set next_arg 0
	set exp {([^\?]*)\?(.*)}


	ob::log::write INFO {DB:$msg}
 	ob::log::write INFO {DB:********************************************}
	foreach line [split $db_data($name,qry_string) "\n"] {
		for {set str ""} {[regexp $exp $line z head line]} {} {
			append str "${head}? ([lindex $qry_args $next_arg]) "
			incr next_arg
		}
		append str $line
		ob::log::write INFO {DB:-> $str}
	}

	ob::log::write INFO {DB:********************************************}
}


#
# Internal function.
#
# Decide on the appropriate action following a database error
# In some situations this may mean that the statement will be
# executed again.
#
proc OB_db::try_handle_err {err_code name vals {msg ""}} {

	variable ERRS_REPREP
	variable ERRS_RECONN

	if {[lsearch $ERRS_REPREP $err_code] >= 0} {


		# we can reprepare queries after table
		# and stored procedure changes

		ob::log::write INFO {DB: table changed, re-preping qry}
		db_new_prep_qry $name
		return [db_exec_stmt $name $vals 1]

	} elseif {[lsearch $ERRS_RECONN $err_code] >= 0} {

		ob::log::write INFO {DB: connection gone away, attempting reconn}
		db_connect
		ob::log::write INFO {DB: called db_connect}
		db_new_prep_qry $name
		return [db_exec_stmt $name $vals 1]
	} else {
		ob::log::write INFO {DB: unhandled exception code $err_code}
		asRestart
		error $msg
	}

}


# override the inf_tcl db_close to keep result sets that need to be cached

rename db_close inf_rs_close

proc OB_db::db_close rs {

	variable db_data
	variable db_cfg

	if {$db_cfg(shm_cache)} {
		return
	}

	if { ![info exists db_data(rs,$rs,qry_name)] } {
		ob::log::write DEV {DB: closing un-cached rs $rs}
		if {[catch {inf_rs_close $rs} msg]} {
			ob::log::write DEV {DB: (db_close) IS THIS HAPPENING}
		}
	} else {
		ob::log::write DEV {DB: rs $rs is cached, ignoring close request}
	}
}



#
# retrieve the last informix error code
#

proc OB_db::db_get_err_code msg {
	return [inf_last_err_num]
}


#
# Begin a transaction
#
# It's reasonably likely that this statement will encounter
# a broken database connection as it's often the first to be
# called at the start of a request. Some attempt is made to
# handle that situation here.
#
proc OB_db::db_begin_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start
	variable ERRS_RECONN

	if {[catch {

		inf_begin_tran $DB

	} msg]} {

		ob::log::write ERROR {DB: error in begin_tran: $msg}

		set err_code [db_get_err_code $msg]

		if {[lsearch $ERRS_RECONN $err_code] >= 0} {
			if {[catch {
				db_connect
				inf_begin_tran $DB
			} msg]} {
				ob::log::write ERROR {DB: failed to reconnect}
				asRestart
				error $msg
			}

		} else {
			ob::log::write ERROR {DB: unhandled exception code $err_code}
			asRestart
			error $msg
		}
	}

	if {$db_cfg(log_time)} {
		ob::log::write WARNING {DB begin tran}
		set tran_start [OT_MicroTime -micro]
	}

	set in_tran 1
}

proc OB_db::db_commit_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start

	inf_commit_tran $DB

	set in_tran 0

	if {$db_cfg(log_time)} {
		set tt [expr {[OT_MicroTime -micro] - $tran_start}]
		ob::log::write WARNING {DB::EXEC commit [format %0.4f $tt]}
	}
}

proc OB_db::db_rollback_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start

	inf_rollback_tran $DB

	set in_tran 0

	if {$db_cfg(log_time)} {
		set tt [expr {[OT_MicroTime -micro] - $tran_start}]
		ob::log::write WARNING {DB::EXEC rollback [format %0.4f $tt]}
	}
}


#
# Change the current pdq priority. The old level is saved and
# should be restored with a call to db_pop_pdq
#
proc OB_db::db_push_pdq {new_pdq} {

	variable db_cfg
	variable pdq_list

	if {$db_cfg(max_pdq) == 0} {
		ob::log::write INFO {DB: pdq disabled, not setting to $new_pdq}
		return
	}

	if {$db_cfg(max_pdq) < $new_pdq} {
		ob::log::write INFO {DB: limiting request to set pdq to $new_pdq, max is $db_cfg(max_pdq)}
		set new_pdq $db_cfg(max_pdq)
	}

	lappend pdq_list $new_pdq
	set_pdq $new_pdq
}


#
# Restore the previous pdq priority
#
proc OB_db::db_pop_pdq {} {

	variable db_cfg
	variable pdq_list

	if {$db_cfg(max_pdq) == 0} {
		return
	}

	if {[llength $pdq_list] < 2} {
		ob::log::write INFO {DB: popped off end of pdq_list}
		return
	}

	set pdq_list [lreplace $pdq_list end end]
	set new_pdq [lindex $pdq_list end]

	set_pdq $new_pdq
}


#
# Internal function.
#
# Change the pdq prioritya on the connection
# application should use db_push_pdq and db_pop_pdq
#
proc OB_db::set_pdq  pdq {

	global DB

	ob::log::write DEBUG {DB: setting pdq to $pdq}

	set s1 [inf_prep_sql $DB "set pdqpriority $pdq"]
	inf_exec_stmt $s1
	inf_close_stmt $s1
}


#
# get the number of rows affected by the last staement
#
proc OB_db::db_garc name {

	variable db_data
	return [inf_get_row_count $db_data($name,stmt)]
}


#
# return any serial number created by the last insert
#
proc OB_db::db_get_serial name {

	variable db_data
	return [inf_get_serial $db_data($name,stmt)]
}


#
# this req_end function __MUST__ be called at the end of
# every request, it performs important cleanup of the result set
# cache
#
proc OB_db::req_end {} {

	variable in_tran
	variable db_data
	variable db_cfg

	if {![catch {db_rollback_tran}]} {
		ob::log::write WARNING {*********************************************}
		ob::log::write WARNING {Rollback Suceeded in req_end !!!!!!!}
		ob::log::write WARNING {This means there is a problem, check your code}
		ob::log::write WARNING {*********************************************}
	}

	if {$db_cfg(shm_cache)} {
		ob::log::write DEV {deleting rss $db_data(rss)}
		foreach rs $db_data(rss) {catch {unset db_data($rs)}}
		set db_data(rss) {}
	} else {
		purge_rs
	}
}


#
# Internal function
#
# Clean expired result sets from the cache
#
proc OB_db::purge_rs {} {

	variable db_data

	# clean up any expired result sets

	set now [clock seconds]
	set rs_exp  $db_data(rs_exp)
	set rs_list $db_data(rs_list)

	set purge_count 0
	while {[llength $rs_exp] && ($now > [lindex $rs_exp 0])} {
		set rs [lindex $rs_list 0]

		set name   $db_data(rs,$rs,qry_name)
		set argkey $db_data(rs,$rs,argkey)

		ob::log::write DEV {DB: purging rs $rs from cache, qry $name, args $argkey}

		if {[catch {inf_rs_close $rs} msg]} {
			ob::log::write ERROR {DB: (purge_rs) IS THIS HAPPENING $msg}
		}

		ob::log::write DEV {DB: array names [array names db_data \"rs*\"]}

		catch {unset db_data($name,$argkey,rs)}
		catch {unset db_data($name,$argkey,time)}
		catch {unset db_data(rs,$rs,qry_name)}
		catch {unset db_data(rs,$rs,argkey)}

		set rs_exp  [lrange $rs_exp  1 end]
		set rs_list [lrange $rs_list 1 end]
		incr purge_count
	}

	set db_data(rs_exp)  $rs_exp
	set db_data(rs_list) $rs_list


	ob::log::write DEV {DB: purged $purge_count items successfully}
}
