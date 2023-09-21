# $Id: lock.tcl,v 1.1 2011/10/04 12:27:04 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Application Resilience
#
# Implements locking/failover functionality for standalone applications
# to enable them to run on multiple servers in a resilient fashion
#
# Configuration:
#
# Synopsis:
#    package require bin_lock ?4.5?
#
# Procedures:
#

package provide bin_lock 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5


# Variables
#
namespace eval ob_lock {

	variable CFG
	variable INIT
	variable HAS_LOCK
	variable IS_ELECTED
	variable EXIT_CALLBACK

	set INIT 0
	set HAS_LOCK 0
	set IS_ELECTED 0
	set EXIT_CALLBACK ""
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Package one-time initialisation.
#
proc ob_lock::init {} {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_db::init
	ob_log::init

	# Application name
	set CFG(name) [OT_CfgGet "FEED_NAME"]

	# set the hostname either through config or from the hostname
	set CFG(hostname) [OT_CfgGet FEED_HOSTNAME [info hostname]]

	ob_log::write INFO {ob_lock - Application: $CFG(name)}
	ob_log::write INFO {ob_lock - Instance: $CFG(hostname)}

	# optional config
	array set OPT [list \
	                  lock_retry     60000\
	                  election_retry 120000\
	                  cache_host_qry 60]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "FEED_[string toupper $c]" $OPT($c)]
	}

	_prepare_qrys

	# initialised
	set INIT 1
}


# Private procedure to prepare the package queries
#
proc ob_lock::_prepare_qrys args {

	variable CFG

	ob_db::store_qry ob_lock::ins_feedlock_interest {
		execute procedure pInsFeedHostReg(
			p_feed     = ?,
			p_hostname = ?
		)
	}

	ob_db::store_qry ob_lock::try_ins_feed_lock {
		execute procedure pTryInsFeedLock(
			p_feed = ?,
			p_hostname = ?
		)
	}
	
	ob_db::store_qry ob_lock::remove {
		delete from
			tFeedLock
		where
			feed     = ?
		and	hostname = ?
	}


	ob_db::store_qry ob_lock::get_priority {
		select
			priority
		from
			tFeedHostPref
		where
			feed     = ? and
			hostname = ?
	}

	ob_db::store_qry ob_lock::get_higher_priority {
		select
			p.hostname
		from
			tFeedHostPref p,
			tFeedHostReg r,
			sysmaster:syssessions s
		where
			r.sid       = s.sid and
			r.connected = s.connected and
			r.feed      = p.feed and
			r.hostname  = p.hostname and
			r.feed      = ? and
			p.priority  < ?
	}

	ob_db::store_qry ob_lock::get_lock_host {
		select
			hostname
		from
			tFeedLock
		where
			feed = ?
	} $CFG(cache_host_qry)
}


#--------------------------------------------------------------------------
# Startup functions
#
# An application implementing locking should call ob_lock::start as part
# of initialisation. It then will not proceed further until the lock has
# been gained
#--------------------------------------------------------------------------

# Try and get the lock, and remain in event handler until it has the lock
#
proc ob_lock::start {} {

	# try and register interest
	_register

	# try and lock
	after 500 ob_lock::_try_lock
	vwait ob_lock::HAS_LOCK
}


# Private proc to register this instance of the feed
#
proc ob_lock::_register {} {

	variable CFG

	if {[catch {ob_db::exec_qry ob_lock::ins_feedlock_interest \
	                                $CFG(name) \
	                                $CFG(hostname)} msg]} {

		ob_log::write ERROR {Could not register interest: $msg}
		_exit
	}
}


# Private proc to attempt to gain the lock
#
proc ob_lock::_try_lock {} {

	variable CFG

	ob_log::write INFO {Attempting to gain lock}

	if {[catch {ob_db::exec_qry ob_lock::try_ins_feed_lock \
				$CFG(name) \
				$CFG(hostname)} msg]} {

		ob_log::write INFO  {Locked by another process, waiting}
		ob_log::write DEBUG {$msg}
		after $CFG(lock_retry) ob_lock::_try_lock

	} else {

		ob_log::write INFO {Gained lock, starting application}
		set ob_lock::HAS_LOCK 1

	}
}


# Proc to remove a feed lock
#
proc ob_lock::remove {} {

	variable CFG

	if {[catch {ob_db::exec_qry ob_lock::remove \
	            $CFG(name) \
	            $CFG(hostname)} msg]} {

		ob_log::write ERROR {failed to remove lock: $msg}
		exit
	}
}


# Set up the exit callback function, allows applications to define
# their own exit strategies
#
proc ob_lock::set_exit_callback {callback_proc} {

	variable EXIT_CALLBACK

	# we don't validate that the proc exists at this point
	# in case the app wants to source it later
	set EXIT_CALLBACK $callback_proc
}


# Private function to handle fatal errors
#
proc ob_lock::_exit {} {

	variable EXIT_CALLBACK

	if {$EXIT_CALLBACK != ""} {

		# !!! do some validation of the proc here???
		if {[catch {eval $EXIT_CALLBACK} msg]} {
			ob_log::write ERROR {Exit callback error: $msg}

			# default to exit
			exit
		}
	} else {
		# default to exit
		exit
	}
}


#--------------------------------------------------------------------------
# Election functions
#--------------------------------------------------------------------------

# Is this instance currently elected?
#
proc ob_lock::am_i_elected {} {

	return $ob_lock::HAS_LOCK

}


# Procedure to check if app has been elected
#
proc ob_lock::is_elected {} {

	variable CFG
	variable IS_ELECTED

	# Get this instance's priority
	if {[catch {set rs [ob_db::exec_qry ob_lock::get_priority \
						$CFG(name) \
						$CFG(hostname)]} msg]} {

		ob_log::write ERROR {Error retrieving priority: $msg}
		_exit
	}

	if {![db_get_nrows $rs]} {
		ob_log::write ERROR {No priority set for this instance, exiting}
		_exit
	}
	set priority [db_get_col $rs 0 priority]

	# Check if we have a higher priority
	if {[catch {set rs [ob_db::exec_qry ob_lock::get_higher_priority \
						$CFG(name) \
						$priority]} msg]} {

		ob_log::write ERROR {Error checking higher priority: $msg}
		_exit
	}
	set nrows [db_get_nrows $rs]
	ob_db::rs_close $rs

	if {$nrows} {
		ob_log::write ERROR {Another instance has priority, exiting}
		_exit
	} else {
		# still the current elected process, so just schedule
		# another check
		ob_log::write INFO {Elected instance, continuing}
		if {$CFG(election_retry)} {
			after $CFG(election_retry) ob_lock::is_elected
		}
	}
}


#--------------------------------------------------------------------------
# Accessor functions
# - these can be used by applications that are not implementing the
#   feed locking, but need to know where a feed is running
#--------------------------------------------------------------------------


# Return currently running instance
#
proc ob_lock::get_lock_host {{name ""}} {

	variable CFG

	# can use name from config, or override
	if {$name == ""} {
		set name $CFG(name)
	}

	if {[catch {set rs [ob_db::exec_qry ob_lock::get_lock_host \
						$name]} msg]} {

		ob_log::write ERROR {db error ob_lock::get_lock_host: $msg}
		return ""
	}

	if {![db_get_nrows $rs]} {
		set hostname ""
		ob_log::write WARN {No currently running instance for $name}
	} else {
		set hostname [db_get_col $rs 0 hostname]
		ob_log::write INFO {$name is currently running on $hostname}
	}

	ob_db::rs_close $rs

	return $hostname
}
