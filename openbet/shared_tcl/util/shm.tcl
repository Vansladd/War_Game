#
# $Id: shm.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
#
# Copyright (c) 2010 Openbet Ltd. All rights reserved.
#
# Provides a set of utilities to use shared memory and semaphores. Based
# on the one in the crypto_server folder
#
# Must be initialized using ::shm::init after sourcing
#
#   Synopsis
#
#     ::shm::init
#     ::shm::lock
#     ::shm::lockNoWait
#     ::shm::unlock
#     ::shm::shmGet
#     ::shm::shmSet
#     ::shm::shmGetRS
#     ::shm::shmSetRS
#

package provide shm 1.0

package require util_log

namespace eval ::shm {
	variable SHM
	variable CFG
	variable INIT 0
}



#
#  Initialization function
proc ::shm::init {} {

	variable SHM
	variable CFG
	variable INIT

	if {$INIT} return

	foreach {cfg dflt} {
		ports           0
		shm_cache_time  100000000
	} {
		set CFG($cfg) [OT_CfgGet [string toupper $cfg] $dflt]
	}
	set SHM(sem)       [ipc_sem_create $CFG(ports)]
	set SHM(enabled)   [expr {[info commands asFindRs] == "asFindRs" ? 1 : 0}]

	set INIT 1
}


# Lock using a semaphore based on the port number
#
proc ::shm::lock {} {
	variable SHM
	variable CFG
	set fn {::shm::lock}

	set ret [ipc_sem_lock $SHM(sem)]

	return $ret
}


# Lock using a semaphore based on the port number (non blocking)
#
proc ::shm::lockNoWait {} {
	variable SHM
	variable CFG
	set fn {::shm::lock_no_wait}

	set ret [ipc_sem_lock -nowait $SHM(sem)]

	return $ret


}


# Unlock a semaphore
#
proc ::shm::unlock {} {
	variable SHM
	variable CFG
	set fn {::shm::unlock}

	set ret [ipc_sem_unlock $SHM(sem)]
	return $ret
}


# Retrieve a string from SHM
#
proc ::shm::shmGet {name {default {}}} {
	upvar 1 $name value
	if {[catch {set value [asFindString $name]} msg]} {
		set value $default
	}
	
	return $value
}


# Set a string in shared memory
#
proc ::shm::shmSet {name value {cache_time {}} } {
	
	variable CFG
	set fn {::shm::shmSet}

	set cache_time [expr {$cache_time == {} ? $CFG(shm_cache_time) : $cache_time}]
	if {[catch {asStoreString $value $name $cache_time} msg]} {
		ob_log::write ERROR {$fn - ERROR: $msg}
	}
}

# Unset a value by assigning "" value and marking as expired
#
proc ::shm::shmUnset {name} {
	set fn {::shm::shmUnset}

	if {[catch {asStoreString "" $name 0} msg]} {
		ob_log::write ERROR {$fn - ERROR: $msg}
	}

}


# Set a RS in shared memory
#
proc ::shm::shmSetRS {name rs {cache_time {}} } {

	variable CFG
	set fn {::shm::shmSetRS}

	set cache_time [expr {$cache_time == {} ? $CFG(shm_cache_time) : $cache_time}]
	if {[catch {asStoreRs $rs $name $cache_time} msg]} {
		ob_log::write ERROR {$fn - ERROR: $msg}
	}
}


# Retrieve an RS from shared memory
#
proc ::shm::shmGetRS {name {default {}} } {
	set fn {::shm::shmGetRS}

	if {[catch {set rs [asFindRs $name]} msg]} {
		set rs $default
	}
	return $rs
}

# Unsets an RS in shared memory by assigning "" value and marking as expired
#
proc ::shm::shmUnsetRS {name} {
	set fn {::shm::shmUnsetRS}

	if {[catch {asStoreRs "" $name 0} msg]} {
		ob_log::write ERROR {$fn - ERROR: $msg}
	}
	return $rs
}
