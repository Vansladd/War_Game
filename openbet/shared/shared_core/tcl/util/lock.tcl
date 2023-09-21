#
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Application Resilience
#
# Implements locking/failover functionality to enable applications to run on
# multiple servers in a resilient fashion.
#

set pkg_version 1.0
package provide core::lock $pkg_version

# Dependencies
#
package require core::log  1.0
package require core::args 1.0
package require core::db   1.0

core::args::register_ns \
	-namespace core::lock \
	-version   $pkg_version \
	-dependent [list core::log core::args core::db] \
	-docs      util/lock.xml

lassign [core::check::command_for_type FEED_NAME] check_exists check_cmd

if { ! ($check_exists && $check_cmd eq "core::lock::_is_feed_name") } {

	core::check::register FEED_NAME core::lock::_is_feed_name [list]

}

unset -nocomplain check_exists check_cmd

namespace eval core::lock {

	variable CFG

	set CFG(init) 0

	set CFG(stand_alone) [catch { package present OT_AppServ }]

}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Package one-time initialisation.
#
core::args::register \
	-proc_name core::lock::init \
	-args [list [list -arg         -name                      \
					  -mand        0                          \
					  -check       FEED_NAME                  \
					  -default_cfg FEED_NAME                  \
					  -desc        {Application name}]        \
				[list -arg         -hostname                  \
					  -mand        0                          \
					  -check       STRING                     \
					  -default_cfg FEED_HOSTNAME              \
					  -default     [info hostname]            \
					  -desc        {Instance host-name}]      \
				[list -arg         -lock_retry                \
					  -mand        0                          \
					  -check       UINT                       \
					  -default_cfg FEED_LOCK_RETRY            \
					  -default     60000                      \
					  -desc        {Lock retry time-out}]     \
				[list -arg         -lock_wait                 \
					  -mand        0                          \
					  -check       UINT                       \
					  -default_cfg FEED_LOCK_WAIT             \
					  -default     2000                       \
					  -desc        {Lock wait time-out}]      \
				[list -arg         -election_retry            \
					  -mand        0                          \
					  -check       UINT                       \
					  -default_cfg FEED_ELECTION_RETRY        \
					  -default     120000                     \
					  -desc        {Election retry time-out}] \
				[list -arg         -cache_host_qry            \
					  -mand        0                          \
					  -check       UINT                       \
					  -default_cfg FEED_CACHE_HOST_QRY        \
					  -default     60                         \
					  -desc        {Host query cache expiry}] \
	] \
	-body {

		variable CFG

		if {$CFG(init)} {
			return
		}

		variable HAS_LOCK 0

		foreach {n v} [array get ARGS] {
			set CFG([string trimleft $n -]) $v
		}

		core::db::store_qry \
			-name core::lock::ins_feedlock_interest \
			-qry  {
				execute procedure pInsFeedHostReg(
					p_feed     = ?,
					p_hostname = ?
				)
			}

		core::db::store_qry \
			-name core::lock::try_ins_feed_lock \
			-qry  {
				execute procedure pTryInsFeedLock(
					p_feed     = ?,
					p_hostname = ?
				)
			}

		core::db::store_qry \
			-name core::lock::remove \
			-qry  {
				delete from
					tFeedLock
				where
					feed     = ?
				and hostname = ?
			}

		core::db::store_qry \
			-name core::lock::get_priority \
			-qry  {
				select
					priority
				from
					tFeedHostPref
				where
					feed     = ?
				and hostname = ?
			}

		core::db::store_qry \
			-name core::lock::get_higher_priority \
			-qry  {
				select
					1
				from
					tFeedHostPref       p,
					tFeedHostReg        r,
					sysmaster:sysscblst s
				where
					r.sid       = s.sid
				and r.connected = s.connected
				and r.feed      = p.feed
				and r.hostname  = p.hostname
				and r.feed      = ?
				and p.priority  < ?
			}

		core::db::store_qry \
			-name  core::lock::get_lock_host \
			-cache $CFG(cache_host_qry) \
			-qry   {
				select
					hostname
				from
					tFeedLock
				where
					feed = ?
			}

		core::db::store_qry \
			-name  core::lock::get_active_lock_host \
			-qry   {
				select
					l.hostname
				from
					tFeedLock           l,
					sysmaster:sysscblst s
				where
					l.feed      = ?
				and l.sid       = s.sid
				and l.connected = s.connected
			}

		if { $CFG(stand_alone) } {

			set CFG(initial_startup) 1

		} else {

			set CFG(initial_startup) \
				[catch { asFindString -copy core::lock::started }]

		}

		set CFG(init) 1

	}


proc core::lock::_is_feed_name { str args } {

	return [core::check::is_string $str -min_str 1 -max_str 15 {*}$args]

}

#-------------------------------------------------------------------------------
# Startup functions
#
# An application implementing locking should call core::lock::start as part
# of initialisation. It then will not proceed further until the lock has
# been gained.
#
# When trying to acquire the lock, a stand-alone application will just call
# _try_lock periodically; an app-server application, however, after the initial
# attempt, will poll first and pause, in order to allow the active instance a
# chance to restart its lock-holding process without grabbing the lock.
#-------------------------------------------------------------------------------

# Try and get the lock, and remain in event handler until it has the lock
#
core::args::register \
	-proc_name core::lock::start \
	-body {

		variable CFG

		if {[catch {
			core::db::exec_qry \
				-name core::lock::ins_feedlock_interest \
				-args [list $CFG(name) $CFG(hostname)]
		} msg]} {

			core::log::write ERROR {Could not register interest: $msg}
			_exit

		} else {

			after 500 core::lock::_try_lock
			vwait core::lock::HAS_LOCK

		}

	}


# Private proc to attempt to gain the lock
#
proc core::lock::_try_lock {} {

	variable CFG

	core::log::write INFO {Attempting to gain lock}

	if {[catch {
		core::db::exec_qry  -name core::lock::try_ins_feed_lock \
							-args [list $CFG(name) $CFG(hostname)]
	} msg]} {

		if { $CFG(initial_startup) } {

			core::log::write INFO {Locked by another process, retrying ($msg)}

			if { $CFG(stand_alone) } {
				after $CFG(lock_retry) core::lock::_try_lock
			} else {
				after $CFG(lock_retry) core::lock::_poll_lock
			}

		} else {

			#
			# This is an app-server app, the lock-holding process has been
			# restarted, and another instance has grabbed the lock: exit.
			#

			core::log::write ERROR {Locked by another process, exiting ($msg)}

			set core::lock::HAS_LOCK 0
			_exit

		}

	} else {

		core::log::write INFO {Gained lock, starting application}

		set core::lock::HAS_LOCK 1

		if { !$CFG(stand_alone) } {

			if { [catch {
				asStoreString 1 core::lock::started 1000000000
			} err] } {
				core::log::write ERROR \
					{Could not write to shared memory, exiting ($err)}
				_exit
			}

		}

	}

}


# Private proc to check whether the lock is available
#
proc core::lock::_poll_lock {} {

	variable CFG

	core::log::write INFO {Checking whether lock is available}

	if { [catch {
		set rs [core::db::exec_qry  -name core::lock::get_active_lock_host \
									-args [list $CFG(name)]]
	} err] } {
		core::log::write INFO {Could not poll data-base, retrying ($err)}
		after $CFG(lock_retry) core::lock::_poll_lock
	}

	if { [db_get_nrows $rs] } {
		set lock_hostname [db_get_col $rs hostname]
	} else {
		set lock_hostname $CFG(hostname)
	}

	core::db::rs_close -rs $rs

	if { $lock_hostname eq $CFG(hostname) } {
		after $CFG(lock_wait) core::lock::_try_lock
	} else {
		core::log::write INFO \
			{Host $lock_hostname still holds $CFG(name) feed lock}
		after $CFG(lock_retry) core::lock::_poll_lock
	}

}


# Set up the exit callback function, allows applications to define their own
# exit strategies
#
core::args::register \
	-proc_name core::lock::set_exit_callback \
	-args [list [list -arg   -callback \
					  -mand  1 \
					  -check STRING \
					  -desc  {Call-back to execute on exit}] \
	] \
	-body {

		variable CFG

		set CFG(exit_callback) $ARGS(-callback)

	}


# Private function to handle fatal errors
#
proc core::lock::_exit {} {

	variable CFG

	if { [info exists CFG(exit_callback)] } {

		if {[catch {
			{*}$CFG(exit_callback)
		} msg]} {
			core::log::write ERROR {Exit callback error: $msg}
			exit
		}

	} else {
		exit
	}

}


#--------------------------------------------------------------------------
# Election functions
#--------------------------------------------------------------------------

# Is this instance currently elected?
#
core::args::register \
	-proc_name core::lock::am_i_elected \
	-body {
		return $core::lock::HAS_LOCK
	}


# Procedure to check if app has been elected
#
core::args::register \
	-proc_name core::lock::is_elected \
	-body {

		variable CFG

		#
		# Check that we still hold the lock
		#
		if { [catch {
			set rs [core::db::exec_qry  -name core::lock::get_active_lock_host \
										-args [list $CFG(name)]]
		} msg] } {
			core::log::write ERROR {Error retrieving priority: $msg}
			_exit
			return
		}

		if { [db_get_nrows $rs] } {
			set lock_hostname [db_get_col $rs hostname]
		} else {
			set lock_hostname ""
		}

		core::db::rs_close -rs $rs

		if { $lock_hostname ne $CFG(hostname) } {
			core::log::write CRITICAL \
				{This is not the active instance of $CFG(name)}
			_exit
			return
		}

		#
		# Get this instance's priority
		#
		if {[catch {
			set rs [core::db::exec_qry  -name core::lock::get_priority \
										-args [list $CFG(name) $CFG(hostname)]]
		} msg]} {
			core::log::write ERROR {Error retrieving priority: $msg}
			_exit
			return
		}

		if { [db_get_nrows $rs] } {
			set priority [db_get_col $rs priority]
		}

		core::db::rs_close -rs $rs

		if { ![info exists priority] } {
			core::log::write ERROR {No priority set for this instance, exiting}
			_exit
			return
		}

		#
		# Check if another instance has a higher priority
		#
		if {[catch {
			set rs [core::db::exec_qry  -name core::lock::get_higher_priority \
										-args [list $CFG(name) $priority]]
		} msg]} {
			core::log::write ERROR {Error checking higher priority: $msg}
			_exit
			return
		}

		set outranked [db_get_nrows $rs]

		core::db::rs_close -rs $rs

		if {$outranked} {
			core::log::write ERROR {Another instance has priority, exiting}
			_exit
			return
		}

		#
		# Still the current elected process, so just schedule another check
		#
		core::log::write INFO {Elected instance, continuing}

		if { $CFG(election_retry) } {
			after $CFG(election_retry) core::lock::is_elected
		}

	}


#--------------------------------------------------------------------------
# Accessor functions
# - these can be used by applications that are not implementing the
#   feed locking, but need to know where a feed is running
#--------------------------------------------------------------------------


# Return currently running instance
#
core::args::register \
	-proc_name core::lock::get_lock_host \
	-args [list [list -arg -name -mand 0 -check STRING -default ""]] \
	-body {

		variable CFG

		if { $ARGS(-name) eq "" } {
			set ARGS(-name) $CFG(name)
		}

		if {[catch {
			set rs [core::db::exec_qry  -name core::lock::get_lock_host \
										-args [list $ARGS(-name)]]
		} msg]} {
			core::log::write ERROR {db error core::lock::get_lock_host: $msg}
			return ""
		}

		if {![db_get_nrows $rs]} {
			set hostname ""
			core::log::write WARN \
				{No currently running instance for $ARGS(-name)}
		} else {
			set hostname [db_get_col $rs 0 hostname]
			core::log::write INFO \
				{$ARGS(-name) is currently running on $hostname}
		}

		core::db::rs_close -rs $rs

		return $hostname

	}

#--------------------------------------------------------------------------
# Utility functions
#--------------------------------------------------------------------------
# Proc to remove a feed lock
#
core::args::register \
	-proc_name core::lock::remove \
	-desc {Remove a named feed lock associated with a host} \
	-body {

		variable CFG

		if {[catch {core::db::exec_qry  \
							-name core::lock::remove \
							-args [list $CFG(name) \
							$CFG(hostname)]} msg]} {

			core::log::write ERROR {failed to remove lock: $msg}
			_exit
		}
}

