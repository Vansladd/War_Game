# ==============================================================
#
# $Id: standalone_db.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# --------------------------------------------------------------
#
# Wrappers around the informix C API.
#
#
#
# USE:
# you must import the namespace with:
# namespace import standalone_db::*
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


namespace eval standalone_db {

	namespace export db_init

	namespace export db_store_qry
	namespace export db_exec_qry
	namespace export db_exec_qry_force
	namespace export db_unprep_qry
	namespace export db_close
	namespace export db_get_err_code
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

	set pdq_list         [list]

	variable  db_cfg
	array set db_cfg  [list]

	variable in_tran
	set      in_tran 0

	variable IN_REPREP
	set      IN_REPREP 0

	variable tran_start

}


#
# the database connection
#


global DB

#
# initialise the module
#

proc standalone_db::db_init {} {

	global DB
	variable db_cfg
	variable db_data

	read_config

	db_connect

	set db_data(rss) {}
}

proc standalone_db::read_config {} {

	variable db_cfg

	if {[info exists db_cfg(config_read)]} {
		return
	}

	set db_cfg(DB_SERVER)     [OT_CfgGet DB_SERVER]
	set db_cfg(DB_DATABASE)   [OT_CfgGet DB_DATABASE]
	set db_cfg(DB_USER)       [OT_CfgGet DB_USERNAME 0]
	set db_cfg(DB_PASSWORD)   [OT_CfgGet DB_PASSWORD 0]
	set db_cfg(prep_ondemand) [OT_CfgGetTrue DB_PREP_ONDEMAND]
	set db_cfg(no_prep_qrys)  [OT_CfgGet DB_NO_PREPARED_QRYS 0]
	set db_cfg(wait)          [OT_CfgGet DB_WAIT_TIME 20]
	set db_cfg(iso)           [OT_CfgGet DB_ISOLATION_LEVEL 0]
	set db_cfg(log_time)      [OT_CfgGetTrue DB_LOG_QRY_TIME]
	set db_cfg(pdq)           [OT_CfgGet DB_DEFAULT_PDQ 0]
	set db_cfg(max_pdq)       [OT_CfgGet DB_MAX_PDQ 0]


}


#
# connect to a server
#

proc standalone_db::db_connect {} {

	global DB
	variable db_cfg
	variable db_data
	variable pdq_list

	set serv  $db_cfg(DB_SERVER)
	set dbase $db_cfg(DB_DATABASE)
	set user  $db_cfg(DB_USER)
	set pass  $db_cfg(DB_PASSWORD)

	OT_LogWrite 5 "connecting to db"

	if {[catch {
		if {$user == 0} {
			set DB [inf_open_conn ${dbase}@${serv} ]
		} else {
			set DB [inf_open_conn ${dbase}@${serv} $user $pass]
		}
	} msg]} {
		OT_LogWrite 5 "failed to open connection to database server $msg"
		asRestart
 		error "failed to open connection to database server $msg"
		return 0
	}

	OT_LogWrite 5 "connection to $dbase@$serv established"

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

proc standalone_db::db_store_qry {name qry} {

	variable db_cfg
	variable db_data

	if {[info exists db_data($name,qry)]} {
		error "Query named $name already exists"
	}

	if {$name == "rs"} {
		error "Query named $name invalid"
	}


	array set db_data [list \
				   $name,name       $name\
				   $name,qry_string $qry]

	db_reset_stats $name

	if {!$db_cfg(prep_ondemand)} {
		if {[catch {db_new_prep_qry $name} msg]} {
			OT_LogWrite 2 "Failed to prepare query: $msg"
			asRestart
			error $msg
		}
	}

}

proc standalone_db::db_reset_stats {name} {
	variable db_data

	set db_data($name,exec_count) 0
	set db_data($name,prep_count) 0
	set db_data($name,min_time)   999999
	set db_data($name,max_time)   0
	set db_data($name,tot_time)   0
}



#
# prepare a named query
#

proc standalone_db::db_new_prep_qry {name} {

	global DB

	variable db_data

	OT_LogWrite 15 "DB: Preparing query $name"

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


proc standalone_db::db_unprep_qry {name} {

	global DB

	variable db_data

	OT_LogWrite 15 "DB: Unpreparing statement $name"

	inf_close_stmt $db_data($name,stmt)
	unset db_data($name,stmt)

	return
}


proc standalone_db::try_prep_qry {qry} {

	global DB

	if {[catch {set stmt [inf_prep_sql $DB $qry]} msg]} {
		set err_code [db_get_err_code $msg]
		error $msg
	}

	return $stmt
}



#
# mark a statement as invalid
#

proc standalone_db::db_invalidate_stmt {name} {

	variable db_data

	OT_LogWrite 15 "DB: Marking stmt $name invalid"
	set db_data($name,stmt_invalid) [clock seconds]
}


#
# execute a query and return the result set (if any)
#
proc standalone_db::db_exec_qry {name args} {
	return [eval {db_exec_qry_ $name} $args]
}



#
# Same as db_exec_qry, except that the query is run even if there
# is a suitable cached result set. Use with care.
#
proc standalone_db::db_exec_qry_ {name args} {

	variable db_data
	variable db_cfg

	if {![info exists db_data($name,qry_string)]} {
		error "DB: statement $name does not exist"
	}

	return [db_exec_qry_no_shm $name $args]
}


proc standalone_db::db_run_qry {name vals} {

	variable db_data

	if {![info exists db_data($name,stmt)] ||
		[info exists db_data($name,stmt_invalid)]} {
		db_new_prep_qry $name
	}

	set now [clock seconds]

	if {[catch {set rs [db_exec_stmt $name $vals]} msg]} {
		db_print_qry $msg $name $vals
		error $msg
	}

	set qry_time [expr {[clock seconds] - $now}]

	incr db_data($name,exec_count)
	set  db_data($name,min_time) [min $qry_time $db_data($name,min_time)]
	set  db_data($name,max_time) [max $qry_time $db_data($name,max_time)]
	incr db_data($name,tot_time) $qry_time

	return $rs
}



proc standalone_db::db_exec_qry_no_shm {name arglist} {

	variable db_data
	variable db_cfg

	if {![info exists db_data($name,qry_string)]} {
		error "statement $name does not exist"
	}

	if {![info exists db_data($name,stmt)] ||
		[info exists db_data($name,stmt_invalid)]} {
		OT_LogWrite 2 "preparing statement $name on demand"
		db_new_prep_qry $name
	}

	if {[catch {set rs [db_exec_stmt $name $arglist]} msg]} {
		db_print_qry $msg $name $arglist
		error $msg
	}

	if {$db_cfg(no_prep_qrys) == 1} {
		db_unprep_qry $name
	}

	return $rs
}

#
# actually execute the query
#

proc standalone_db::db_exec_stmt {name vals} {

	variable db_data
	variable db_cfg
	variable in_tran
	variable IN_REPREP

	set exec_stmt [list inf_exec_stmt $db_data($name,stmt)]
	foreach arg $vals {
		lappend exec_stmt $arg
	}

	OT_LogWrite 8 "DB: executing -$name- with args: $vals"
	OT_LogWrite 8 "DB: evalstr: $exec_stmt"

#	set exec_stmt [concat inf_exec_stmt $db_data($name,stmt) $exec_stmt]

	if {$db_cfg(log_time)} {
		set t0 [OT_MicroTime -micro]
	}

	if {[catch {set rs [eval $exec_stmt]} msg]} {
		set err_code [db_get_err_code $msg]

		error $msg
	}

	OT_LogWrite 8 "DB: [db_garc $name] rows Probably affected"
	if {$db_cfg(log_time)} {
		set t1 [OT_MicroTime -micro]
		set rc [expr {[string length $rs] > 0 ? [db_get_nrows $rs] : 0}]
		set tt [expr {$t1-$t0}]
		OT_LogWrite 3 "DB::EXEC $name [format %0.4f $tt]"
	}
	set IN_REPREP 0
	return $rs
}




proc standalone_db::db_print_qry {msg name {qry_args ""}} {

	variable db_data
	set next_arg 0
	set exp {([^\?]*)\?(.*)}


	OT_LogWrite 2 "DB:$msg"
 	OT_LogWrite 2 "DB:********************************************"
	foreach line [split $db_data($name,qry_string) "\n"] {
		for {set str ""} {[regexp $exp $line z head line]} {} {
			append str "${head}? ([lindex $qry_args $next_arg]) "
			incr next_arg
		}
		append str $line
		OT_LogWrite 2 "DB:-> $str"
	}

	OT_LogWrite 2 "DB:********************************************"
}



rename db_close inf_rs_close

proc standalone_db::db_close rs {

	variable db_data
	variable db_cfg

	if {[catch {inf_rs_close $rs} msg]} {
		OT_LogWrite 20 "DB: (db_close) IS THIS HAPPENING"
	}
}

#
# retrieve the last informix error code
#

proc standalone_db::db_get_err_code msg {
	return [inf_last_err_num]
}





proc standalone_db::db_begin_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start

	if {[catch {

		inf_begin_tran $DB

	} msg]} {

		OT_LogWrite 2 "DB: error in begin_tran: $msg"

		set err_code [db_get_err_code $msg]

		error $msg
	}

	if {$db_cfg(log_time)} {
		set tran_start [OT_MicroTime -micro]
	}

	set in_tran 1
}

proc standalone_db::db_commit_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start

	inf_commit_tran $DB

	set in_tran 0

	if {$db_cfg(log_time)} {
		set tt [expr {[OT_MicroTime -micro] - $tran_start}]
		OT_LogWrite 3 "DB::EXEC commit [format %0.4f $tt]"
	}
}

proc standalone_db::db_rollback_tran args {

	global DB
	variable db_cfg
	variable in_tran
	variable tran_start

	inf_rollback_tran $DB

	set in_tran 0

	if {$db_cfg(log_time)} {
		set tt [expr {[OT_MicroTime -micro] - $tran_start}]
		OT_LogWrite 3 "DB::EXEC rollback [format %0.4f $tt]"
	}
}


proc standalone_db::db_push_pdq {new_pdq} {

	variable db_cfg
	variable pdq_list

	if {$db_cfg(max_pdq) == 0} {
		OT_LogWrite 6 "DB: pdq disabled, not setting to $new_pdq"
		return
	}

	if {$db_cfg(max_pdq) < $new_pdq} {
		OT_LogWrite 4 "DB: limiting request to set pdq to $new_pdq, max is $db_cfg(max_pdq)"
		set new_pdq $db_cfg(max_pdq)
	}


	set_pdq $new_pdq
}



proc standalone_db::db_pop_pdq {} {

	variable db_cfg
	variable pdq_list

	if {$db_cfg(max_pdq) == 0} {
		return
	}

	if {[llength $pdq_list] < 2} {
		OT_LogWrite 4 "DB: popped off end of pdq_list"
		return
	}

	lreplace $pdq_list end end
	set new_pdq [lindex $pdq_list end]

	set_pdq $new_pdq
}


proc standalone_db::set_pdq  pdq {

	global DB


	OT_LogWrite 6 "DB: setting pdq to $pdq"

	set s1 [inf_prep_sql $DB "set pdqpriority $pdq"]
	inf_exec_stmt $s1
	inf_close_stmt $s1
}


#
# get the number of rows affected by the last staement
#
proc standalone_db::db_garc name {

	variable db_data
	return [inf_get_row_count $db_data($name,stmt)]
}


#
# return any serial number created by the last insert
#

proc standalone_db::db_get_serial name {

	variable db_data
	return [inf_get_serial $db_data($name,stmt)]
}


proc standalone_db::req_end {} {

	variable in_tran
	variable db_data
	variable db_cfg

	if {![catch {db_rollback_tran}]} {
		OT_LogWrite 2 "*********************************************"
		OT_LogWrite 2 "Rollback Suceeded in req_end !!!!!!!"
		OT_LogWrite 2 "This means there is a problem, check your code"
		OT_LogWrite 2 "*********************************************"
	}

}

