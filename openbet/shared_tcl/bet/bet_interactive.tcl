################################################################################
# $Id: bet_interactive.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Initialise bet placement to work interactively from the command line
################################################################################

package provide bet_interactive 4.5

#load libraries
if {[catch {load libOT_InfTcl.so} msg]} {
	error "Make sure libOT_InfTcl.so is in the LD_LIBRARY_PATH: $msg"
}
if {[catch {load libOT_Addons.so} msg]} {
	error "Make sure libOT_Addons.so is in the LD_LIBRARY_PATH: $msg"
}


# logging functions
namespace eval ob_bet {
	namespace export _log
}


proc ::ob_bet::_log {level msg} {
	puts "$level BET $msg"
}


# override DB functions
#
namespace eval ob_db {
	variable STORED
	array set STORED [list]
	namespace export store_qry
	namespace export exec_qry
}


proc ob_db::store_qry {name sql {cache ignored}} {
	variable STORED

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: store_qry $name $sql $cache"
		return
	}

	set STORED($name) $sql
}


proc ob_db::exec_qry {name args} {

	global DB
	variable STORED

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: exec_qry $name $args"
		return
	}

	if {![info exists DB]} {
		set err "global DB must be set to db_conn:\n"
		append err "set DB \[inf_open_conn db username password\]"
		error $err
	}

	set stmt [inf_prep_sql $DB $STORED($name)]
	set rs  [eval "inf_exec_stmt $stmt $args"]
	inf_close_stmt $stmt
	return $rs
}



proc ob_db::begin_tran {} {
	global DB

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: begin_tran"
		return
	}

	inf_begin_tran $DB
}


proc ob_db::rollback_tran {} {
	global DB

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: rollback_tran"
		return
	}

	inf_rollback_tran $DB
}


proc ob_db::commit_tran {} {
	global DB

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: commit_tran"
		return
	}

	inf_commit_tran $DB
}


proc ob_db::rs_close {rs} {

	if {$::ob_bet::OFFLINE} {
		_log WARN "OFFLINE: rs_close"
		return
	}

	db_close $rs
}



#
# Override request fuctions
#
set REQ_ID 1

proc reqGetId {} {
	global REQ_ID
	return $REQ_ID
}

proc next_req {} {
	global REQ_ID
	incr REQ_ID
}

proc req_set_id {req_id} {
	global REQ_ID
	set REQ_ID $req_id
}



#
# Override child functions
#
proc asGetId {} {
	return 1
}



#
# Override control functions
#
namespace eval ob_control {
	namespace export get
}


proc ob_control::get {name} {

	global DB

	if {![info exists DB]} {
		set err "global DB must be set to db_conn:\n"
		append err "set DB \[inf_open_conn db username password\]"
		error $err
	}

	set sql {
		select * from tControl
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	#if not configured in return an empty string
	if {[catch {
		set res [db_get_col $rs 0 $name]
		ob_db::rs_close $rs
	}]} {
		return ""
	} else {
		return $res
	}
}


::ob_bet::_log INFO "sourced bet_interactive.tcl"

