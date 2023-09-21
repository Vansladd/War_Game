#
# $Id: feed_lock.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# $Name:  $
#

namespace eval OB_feedlock {

	variable ERRS_RECONN
	set      ERRS_RECONN {}

	variable QRYS_PREPARED
	set QRYS_PREPARED 0
}

proc OB_feedlock::prepare_queries {} {
	variable QRYS_PREPARED

	if {$QRYS_PREPARED} {
		return
	}

	OT_LogWrite 2 "Preparing feedlock queries..."
	db_store_qry ins_feedlock_interest {
		execute procedure pInsFeedHostReg(
			p_feed     = ?,
			p_hostname = ?
		)
	}

	db_store_qry try_ins_feed_lock {
		execute procedure pTryInsFeedLock(
			p_feed = ?,
			p_hostname = ?
		)
	}

	db_store_qry get_priority {
		select
			priority
		from
			tFeedHostPref
		where
			hostname = ? and
			feed = ?
	}

	db_store_qry get_higher_priority {
		select
			p.hostname
		from
			tFeedHostPref p,
			tFeedHostReg r,
			sysmaster:sysscblst s
		where
			r.sid = s.sid and
			r.connected = s.connected and
			r.feed = p.feed and
			r.hostname = p.hostname and
			r.feed = ? and
			p.priority < ?
	}

	if {[info exists OB_db::store_qry]} {
		db_store_qry get_lock_host_60 {
			select
				hostname
			from
				tFeedLock
			where
				feed = ?
		} 60
	}

	db_store_qry get_lock_host {
		select
			hostname
		from
			tFeedLock
		where
			feed = ?
	}

	set QRYS_PREPARED 1
	OT_LogWrite 2 "Successfully prepared feedlock queries"
}

# Get hostname with lock for specified feed.
proc OB_feedlock::get_lock_host {feed {cached 0}} {

	prepare_queries

	if {$cached} {
		set qry get_lock_host_60
	} else {
		set qry get_lock_host
	}
	if {
		[catch {
			set rs [db_exec_qry $qry $feed]
		} msg] ||
		[db_get_nrows $rs] == 0
	} {
		OT_LogWrite 2 "Unable to detect running feed $msg"
		return
	}

	set hostname [db_get_coln $rs 0 0]
	OT_LogWrite 5 "Using host $hostname for app $feed"
	db_close $rs
	return $hostname

}

proc OB_feedlock::db_connect {} {
	::OB_db::orig_db_connect
	OT_LogWrite 2 "Successfully called old db_connect"
	OB_feedlock::prepare_queries

	set feed [OT_CfgGet FEED_NAME]
	set host [info hostname]
}

proc OB_feedlock::try_ins_feed_lock {} {

	variable has_lock

	set hostname [info hostname]
	set feed [OT_CfgGet FEED_NAME]


	if {[catch {db_exec_qry try_ins_feed_lock $feed $hostname} msg]} {
		OT_LogWrite 2 "Feed has been locked by another $feed process"
		set after_id [after [OT_CfgGet FEED_LOCK_RETRY 60000] OB_feedlock::try_ins_feed_lock]
		OT_LogWrite 1 "$after_id ========"
	} else {

		OT_LogWrite 2 "Got exclusive $feed access"
		set OB_feedlock::has_lock 1
	}
#	if {!$OB_feedlock::has_lock} {
#		after [OT_CfgGet FEED_LOCK_RETRY 60000] OB_feedlock::try_ins_feed_lock
#	}
}

#
# Returns 1 if it is the current active process
#
proc OB_feedlock::am_i_elected {} {
	variable has_lock

	return $has_lock

}

proc OB_feedlock::is_elected {} {

	variable is_elected

	OT_LogWrite 5 "==> is_elected"

	set hostname [info hostname]
	set feed [OT_CfgGet FEED_NAME]

	if {
		[catch {
			set rs [db_exec_qry get_priority $hostname $feed]
			set priority [db_get_coln $rs 0 0]
		} msg]
	} {
		OT_LogWrite 2 "Unable to retrieve my own priority"
		OT_LogWrite 1 $msg
		exit
	}
	OT_LogWrite 5 "My priority is $priority"
	if {[catch {
		set rs [db_exec_qry get_higher_priority $feed $priority]
	} msg]} {
		OT_LogWrite 1 $msg
		exit
	} else {
		set nrows [db_get_nrows $rs]
	}
	if {$nrows == 0} {
		after [OT_CfgGet ELECTION_RETRY 120000] OB_feedlock::is_elected
	} else {
		OT_LogWrite 1 "Another feed has higher priority. Exiting"
		exit
	}
}

# =========================================================
# feed lock initialisation for all feeds.
# =========================================================
proc OB_feedlock::init {} {

	variable has_lock
	variable is_elected

	OT_CfgSet EXIT_ON_ERROR 0

	OT_LogWrite 2 "Initialising OB_feedlock"

	catch {
		rename ::OB_db::db_connect         ::OB_db::orig_db_connect
		rename db_connect                  ::OB_db::db_connect
		rename ::standalone_db::db_connect ::standalone_db::orig_db_connect
		rename db_connect                  ::standalone_db::db_connect
	}

	prepare_queries

	set hostname [info hostname]
	set feed [OT_CfgGet FEED_NAME]

	if {[catch {
		db_exec_qry ins_feedlock_interest $feed $hostname
	} msg]} {
		OT_LogWrite 1 $msg
	}

	# Try to get the lock the first time with asap.
	after 500 OB_feedlock::try_ins_feed_lock
	vwait OB_feedlock::has_lock
#	after [OT_CfgGet ELECTION_RETRY  120000] is_elected
#	vwait is_elected
}