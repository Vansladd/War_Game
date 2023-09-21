# $Id: feed_resilience.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
namespace eval fr {

	namespace export fr_db_init
	namespace export fr_db_exec_qry

	variable ERRS_OK
	variable ERRS_REPREP

	set      ERRS_OK     {-746 -268 -530 -1213}
	set      ERRS_REPREP {-710 -721 -908}
}

proc fr::fr_db_init {} {

	OT_LogWrite 32 "fr::fr_db_init: Started"
	db_init
	fr_try_ins_feed_lock
}

proc fr::fr_try_ins_feed_lock {} {

	OT_LogWrite 32 "fr::fr_try_ins_feed_lock: Started"
	db_store_qry try_ins_feed_lock {
					execute procedure pTryInsFeedLock(
							p_feed = ?,
							p_hostname = ?
					)
	}

	set feed [OT_CfgGet FEED_NAME]
	set hostname [info hostname]

	while {1} {
		if {[catch {db_exec_qry try_ins_feed_lock $feed $hostname} msg]} {
			OT_LogWrite 2 "Feed has been locked by another $feed process"
		} else {
			OT_LogWrite 2 "Got exclusive $feed access"
			break
		  }
		after 60000
	}
}

proc fr::fr_db_exec_qry {name args} {

	variable ERRS_OK

	if {[catch {set rs [eval {db_exec_qry $name} $args]} msg]} {
		set err_code [db_get_err_code $msg]

		if {[lsearch $ERRS_OK $err_code] >= 0} {

			# let through these exceptions
			# to be handled by the client
			error $msg
		} elseif {!$::standalone_db::IN_REPREP && !$::standalone_db::in_tran} {

			return [fr_try_handle_err $err_code $name $args $msg]
		} else {
			OT_LogWrite 3 "unable to handle error: IN_REPREP $::standalone_db::IN_REPREP, in_tran $::standalone_db::in_tran"
			OT_LogWrite 3 "err_code $err_code ... $name $args $msg"
			asRestart
			error $msg
		}

	}

	return $rs
}

proc fr::fr_try_handle_err {err_code name vals {msg ""}} {

	variable ERRS_REPREP

	if {[lsearch $ERRS_REPREP $err_code] >= 0} {


		# we can reprepare queries after table
		# and stored procedure changes

		OT_LogWrite 2 "DB: table changed, re-preping qry"
		db_new_prep_qry $name
		set ::standalone_db::IN_REPREP 1
		return [db_exec_stmt $name $vals]

	} else {
		OT_LogWrite 2 "DB: unhandled exception code $err_code"
		asRestart
		error $msg
	}

}

