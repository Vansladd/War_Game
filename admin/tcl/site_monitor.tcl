# $Id: site_monitor.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# $Name: RC_Training $

##
# The feeds that are connected to the database can be monitored, both the active feeds and 
# those waiting to take over should the active feed fail. The active feed is determined
# by a priority system so if the feed is running on two boxes, app1 and app2, the one with
# the highest priority will be 'active' and the other one will be waiting, ready to take over
# should the active feed fail. 
#
# This package monitors the registered feeds and allows you to set up new feeds and assign
# priorities. 
# 
# tFeedLock, tFeedHostReg, tFeedHostPref  - active, registered, priority table
#
##
namespace eval ADMIN::SITE_MONITOR {

	asSetAct ADMIN::SITE_MONITOR::GoHome    		[namespace code go_site_monitor_home]
	asSetAct ADMIN::SITE_MONITOR::addPriority   	[namespace code add_to_priority_queue]
	asSetAct ADMIN::SITE_MONITOR::goPriority    	[namespace code go_priority]	
	asSetAct ADMIN::SITE_MONITOR::modifyPriority    [namespace code modify_priority]	
	asSetAct ADMIN::SITE_MONITOR::deletePriority    [namespace code delete_priority]	
}

#-----------------------------------------------------------------------

##
# Show the active feed sessions, those registered to failover & the priority list
#
##
proc ADMIN::SITE_MONITOR::go_site_monitor_home {} {

	global FEEDREG
	global FEEDPRIORITY

	if {[catch {

		#if {![op_allowed MonitorFeed]} {
		#	error "You do not have access priviliges."
		#}

		set sql {
			select
				r.feed,
				p.priority,
				r.sid,
				r.connected,
				r.hostname,
				l.sid as active,
				l.started
			from
				tFeedHostPref p,
				tFeedHostReg r,
				sysmaster:syssessions s,
			outer tFeedLock l 
			where
				r.sid = s.sid 
			and	r.connected = s.connected 
			and	r.feed = p.feed 
			and r.hostname = p.hostname 
			and l.sid = r.sid
			order by 
				1,2 asc
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]
		set nrows	[db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {feed priority sid connected hostname active started} {
				set FEEDREG($r,$col) [db_get_col $rs $r $col]
   			}
   			
		}
		
		tpSetVar REG_ROWS $nrows
		
		db_close $rs
		unset sql stmt rs nrows

		tpBindVar REG_FEED			FEEDREG feed		reg_idx
		tpBindVar REG_SID			FEEDREG sid			reg_idx
		tpBindVar REG_CONNECTED		FEEDREG connected	reg_idx
		tpBindVar REG_HOSTNAME		FEEDREG hostname	reg_idx
		tpBindVar REG_PRIORITY		FEEDREG priority	reg_idx
		tpBindVar REG_ACTIVE		FEEDREG active 		reg_idx
		tpBindVar REG_STARTED		FEEDREG started 	reg_idx
	
	} msg]} {
		err_bind $msg
	}


	# 
	# Priority List
	#
	if {[catch {

		#if {![op_allowed MonitorFeed]} {
		#	error "You do not have access priviliges."
		#}

		set sql {
			select
				p.feed,
				p.hostname,
				p.priority
			from
				tFeedHostPref p
			order by 
				1,2,3 asc
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt]
		set nrows	[db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			foreach col {feed priority hostname} {
				set FEEDPRIORITY($r,$col) [db_get_col $rs $r $col]
   			}
   			
		}
		
		tpSetVar PR_ROWS $nrows
		
		db_close $rs
		unset sql stmt rs nrows

		tpBindVar PR_FEED			FEEDPRIORITY feed		pr_idx
		tpBindVar PR_HOSTNAME		FEEDPRIORITY hostname	pr_idx
		tpBindVar PR_PRIORITY		FEEDPRIORITY priority	pr_idx
	
	} msg]} {
		err_bind $msg
	}
	
	asPlayFile "site_monitor.html"
}


##
#	Add a feed-host combination to the priority queue
##
proc ADMIN::SITE_MONITOR::add_to_priority_queue {} {

	global DB

	#if {![op_allowed MonitorFeed]} {
	#	error "You do not have access priviliges."
	#   return
	#}

	set stmt_1 [inf_prep_sql $DB {
		insert into
			tFeedHostPref (feed, hostname, priority)
		values
			(?, ?, ?)
	}]

	inf_begin_tran $DB

	set feed 		[reqGetArg feedname]
	set hostname 	[reqGetArg hostname]
	set priority    [reqGetArg priority]
	
	if {($priority < 1) || ($priority > 99)} { 
		tpSetVar FEEDNAME $feed
		tpSetVar HOSTNAME $hostname
		err_bind "Priority should be between 1 and 99"
		go_site_monitor_home
		return
	}
	
	set c [catch {

		set rs_1 [inf_exec_stmt $stmt_1\
			$feed\
			$hostname\
			$priority]
	} msg]

	catch {db_close $rs_1}
	catch {inf_close_stmt $stmt_1}

	if {$c} {
		inf_rollback_tran $DB
		error $msg
	} else {
		inf_commit_tran $DB
	}
	
	go_site_monitor_home
}


##
# Navigate to the priority page for a feed-hostname combination.
#	
##
proc ADMIN::SITE_MONITOR::go_priority {} {

	set feed 		[reqGetArg feed] 
	set hostname 	[reqGetArg hostname]

	if {[catch {

		#if {![op_allowed MonitorFeed]} {
		#	error "You do not have access priviliges."
		#   return
		#}

		set sql {
			select
				p.feed,
				p.hostname,
				p.priority
			from
				tFeedHostPref p
			where 
				feed = ? 
			and hostname = ? 
				
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt $feed $hostname]
		set nrows	[db_get_nrows $rs]

		if {$nrows != 1} { 
			err_bind "Error - host not found for feed"
			go_site_monitor_home
			return
		} 

		set feed 	 [db_get_col $rs 0 feed]
		set hostname [db_get_col $rs 0 hostname]
		set priority [db_get_col $rs 0 priority]
		
		tpBindString FEED 		$feed
		tpBindString HOSTNAME 	$hostname
		tpBindString PRIORITY 	$priority
		
		db_close $rs
		
		unset sql stmt rs nrows
		
	} msg]} {
		err_bind $msg
	}

	asPlayFile "site_mod_priority.html"
}


##
#  Modify a particular feed-hostname's priority details 	
##
proc ADMIN::SITE_MONITOR::modify_priority {} {

	set feed 		[reqGetArg feed] 
	set hostname 	[reqGetArg hostname]
	set priority    [reqGetArg priority]
	set oldfeed     [reqGetArg oldfeed] 
	set oldhost 	[reqGetArg oldhost]
	
	if {($priority < 1) || ($priority > 99)} { 
		tpSetVar FEEDNAME $feed
		tpSetVar HOSTNAME $hostname
		err_bind "Priority should be between 1 and 99"
		go_site_monitor_home
		return
	}
	
	if {[catch {

		#if {![op_allowed MonitorFeed]} {
		#	error "You do not have access priviliges."
		#   return 
		#}

		set sql {
			update 
				tFeedHostPref
			set 
				feed = ?, 
			    hostname = ?,
			    priority = ? 
			where 
				feed = ? 
			and hostname = ? 
			   
				
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt $feed $hostname $priority $oldfeed $oldhost]

		db_close $rs
		unset sql stmt rs
		
	} msg]} {
		err_bind $msg
	}

	go_site_monitor_home
}


##
# Remove a feed priority from the tFeedHostPref table. 
#	
##
proc ADMIN::SITE_MONITOR::delete_priority {} {

	set feed 		[reqGetArg feed] 
	set hostname 	[reqGetArg hostname]

	# 
	# Priority List
	#
	if {[catch {

		#if {![op_allowed MonitorFeed]} {
		#	error "You do not have access priviliges."
		#   return 
		#}

		set sql {
			delete from
				tFeedHostPref 
			where
				feed = ?
			and hostname = ?
				
		}

		set stmt	[inf_prep_sql $::DB $sql]
		set rs		[inf_exec_stmt $stmt $feed $hostname]
	
	} msg]} {
		err_bind $msg
	}

	go_site_monitor_home
}
