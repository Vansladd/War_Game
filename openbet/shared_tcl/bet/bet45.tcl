################################################################################
# $Id: bet45.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Initialise bet placement to wirk with Openbet 4.5 shared code
################################################################################

package provide bet_45 4.5

# logging functions
namespace eval ob_bet {
	namespace export _log
}

if {[catch {load libOT_Addons.so} msg]} {
	error "Make sure libOT_Addons.so is in the LD_LIBRARY_PATH: $msg"
}



proc ::ob_bet::_log {level msg} {
	switch -- $level {
		"ERROR" {
			set num_level 1
		}
		"WARN" {
			set num_level 2
		}
		"INFO" {
			set num_level 3
		}
		"DEBUG" {
			set num_level 4
		}
		"DEV" {
			set num_level 5
		}
		default {
			set num_level 3
		}
	}

	OT_LogWrite $num_level "BET $msg"
}



# override DB functions
#
namespace eval ob_db {
	namespace export store_qry
	namespace export exec_qry
}


proc ob_db::store_qry {name sql {cache 0}} {
	db_store_qry $name $sql $cache
}



proc ob_db::exec_qry {name args} {
	set rs  [eval "db_exec_qry $name $args"]
	return $rs
}



proc ob_db::begin_tran {} {
	db_begin_tran
}



proc ob_db::rollback_tran {} {
	db_rollback_tran
}



proc ob_db::commit_tran {} {
	db_commit_tran
}



proc ob_db::rs_close {rs} {
	db_close $rs
}



#
# Override control functions
#
db_store_qry ob_control::get_control {
	select * from tControl
}



namespace eval ob_control {
	variable CONTROL
	namespace export get

	set CONTROL(req_id) -1
}



proc ob_control::get {name} {

	variable CONTROL

	set curr_req [reqGetId]
	if {$CONTROL(req_id) != $curr_req} {
		#need to retrieve the information
		set rs [db_exec_qry ob_control::get_control]
		set cols [db_get_colnames $rs]

		if {[db_get_nrows $rs] == 1} {
			foreach c $cols {
				set CONTROL($c) [db_get_col $rs 0 $c]
			}
		}
		db_close $rs

		set CONTROL(req_id) $curr_req
	}
	if {[info exists CONTROL($name)]} {
		return $CONTROL($name)
	} else {
		return ""
	}
}

::ob_bet::_log INFO "sourced bet45.tcl"