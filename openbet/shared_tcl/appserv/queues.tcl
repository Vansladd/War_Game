#============================================================
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/appserv/queues.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
#============================================================
#
# Provides functionality to assign elements to a collection of queues in
# shared memory, the package support both FIFO and FILO queue types
#
# multiple queue groups can be initialised using different name
# parameters, for effiecieny you should use a different semaphore id for each
# queue group, however this is not strictly necessary. When using muliple queue
# groups the queue group name should be passed in as the final (optinal)
# parameter to each of the calls.
#
# Advertising allow random information about queues to be placed in shared
# memory. This information is not considered to be very important and so by
# default no semaphore locking is applied. If locking is requred then the
# lock and unlock queue functions should be used within the calling code
#
#	Configuration:
#      Although these values can be defaulted in the configuration it is advisable
#      to initialise using init parameters especially when using multiple queue
#      types
#
#      -name             [default] : Name for the queue group you are using
#      -type             [fifo]    : operate as a fifo or lifo queue
#      -buffering (0|1)  [1]       : should messages be buffered before writting to shared
#                                    memory, (strongly recommended for high throughput)
#      -count ([0-9]+)   [1]       : number of queues required
#      -semaphore_id     [123456]  : value to use for semaphore locking, differnent queue types
#                                    should have a different semaphore id
#
#	Public funtions
#	-------------------------
#	Adding to queues:
#		random_push   : Adds to the end of a random queue of the given type
#		balanced_push : Adds to the end of the shortest queue
#		push          : Adds an element to the end of a queue
#		flush         : flushs queue buffers to shared memory
#
#	Reading from queues:
#		pop      : removes and returns last element on a queue
#		clear    : returns the full queue, emptying it
#		view     : returns the queue without altering it
#
#	Advertising about queues:
#		set_advert  : advertise some information about a queue
#		get_advert  : read advertised information
#		num_queues  : get number of active queues
#		length      : get number of data elements on a queue
#
#
#	!!! USE THESE WITH CARE !!!
#	-------------------------
#	locking queues:
#		lock    : Prevent update occuring to a queue or any of its adverts
#		unlock  : Remove previouse queue lock

package provide appserv_queues 4.5


package require util_log


namespace eval ob_queues {
	variable CFG
	variable BUFFER
	variable SEM
	variable INIT 0
}


#
# Initialiase the queues
#
proc ob_queues::init args {

	variable CFG
	variable BUFFER
	variable SEM
	variable INIT

	if {$INIT} {return}

	# Setup a name for this queue group
	if {[set id [lsearch $args "-name"]] >= 0} {
		set queue_name [lindex $args [expr {$id + 1}]]
		set CFG($queue_name,name)  $queue_name
	} else {
		set queue_name DFLTQ
		set CFG($queue_name,name)  $queue_name
	}
	ob_log::write DEBUG {QUEUES: initialising queue $queue_name}

	set SEM($queue_name,init) 0

	# Setup defaults
	array set OPT [list \
		semaphore_id         123456 \
		semaphore_port       [OT_CfgGet PORTS] \
		count                1 \
		cache_time           36000 \
		buffering            1 \
		type                 fifo \
	]

	# Read in configs
	foreach c [array names OPT] {
		set CFG($queue_name,$c) [OT_CfgGet "QUEUES_[string toupper $c]" $OPT($c)]
	}


	# override with supplied arguements
	foreach {n v} $args {
		set cfg_name [string tolower [string range $n 1 end]]
		if {![info exists CFG($queue_name,$cfg_name)] || $v == ""} {
			error "Invalid argument '$n'"
		}
		set CFG($queue_name,$cfg_name) $v
	}

	# Initialise queue buffers
	if {$CFG($queue_name,buffering)} {
		for {set i 0} {$i < $CFG($queue_name,count)} {incr i} {
			set BUFFER($queue_name,$i) [list]
		}
	}

}




#------------------------------
# Adding Procs
#------------------------------

# Public
#
#  Add an item to a queue buffer
#
# If buffering is enabled these items will not actually end up on the
# queue until flush is called
#
proc ob_queues::push {q_idx value {queue_name DFLTQ}} {

	variable CFG
	variable BUFFER

	if {$CFG($queue_name,buffering)} {
		lappend BUFFER($queue_name,$q_idx) $value
		return [list 0 OK]
	}


	ob_queues::lock $q_idx $queue_name
	set shm_queue [ob_queues::_get_queue $q_idx $queue_name]

	set ret [ob_queues::_set_queue \
		$q_idx \
		[lappend $shm_queue $value] \
		$queue_name]

	ob_queues::unlock $q_idx $queue_name
	return $ret
}


# Public:
# 
# Add data to the end of a random queue of the given type
#
proc ob_queues::random_push {value {queue_name DFLTQ}} {
	set q_idx   [expr { int(rand() * [ob_queues::num_queues $queue_name]) }]
	ob_queues::push $q_idx $value $queue_name
	return $q_idx
}


# Public:
# 
# Add data to the end of the shortest queue
#
proc ob_queues::balanced_push {value {queue_name DFLTQ}} {

	set q_idx 0	
	set q_len [ob_queues::length 0 $queue_name]

	for {set i 0} {$i < [ob_queues::num_queues $queue_name]} {incr i} {
		if {[ob_queues::length $i $queue_name] < $q_len} {
			set q_idx $i
		}
	}
	ob_queues::push $q_idx $value $queue_name
	return $q_idx
}



# Public
#
# Clear the contents of the queue buffers onto the shared
# memory queues
#
proc ob_queues::flush { {queue_name DFLTQ}} {

	variable CFG
	variable BUFFER

	# Pass each queue locking the message and appending it to the correct queue
	for {set i 0} {$i < $CFG($queue_name,count)} {incr i} {
		if {[llength $BUFFER($queue_name,$i)] > 0} {
			ob_log::write DEBUG {QUEUES: flushing buffer $i ([llength $BUFFER($queue_name,$i)] elements)}
			ob_queues::lock $i $queue_name

			set shm_queue [ob_queues::_get_queue $i $queue_name]

			ob_queues::_set_queue \
				$i \
				[concat $shm_queue $BUFFER($queue_name,$i)] \
				$queue_name

			ob_queues::unlock $i $queue_name
			set BUFFER($queue_name,$i) [list]
		}
	}
	ob_log::write DEBUG {QUEUES $queue_name: flush completed}

	return [list 0 OK]
}






#------------------------------
# Retrieval Procs
#------------------------------


#
# Return the contents of a shared memory queue clearing its contents
#
proc ob_queues::clear {q_idx {queue_name DFLTQ}} {

	variable CFG

	ob_queues::lock $q_idx $queue_name

	set queue [ob_queues::_get_queue $q_idx $queue_name]

	if {[llength $queue] > 0} {
		set ret [ob_queues::_set_queue \
			$q_idx \
			[list] \
			$queue_name]

		if {[lindex $ret 0] != 0} {
			ob_queues::unlock $q_idx $queue_name
			ob_log::write DEBUG {QUEUES: $queue_name ERROR [lindex $ret 1]}
			return $ret
		}
	}


	ob_queues::unlock $q_idx $queue_name
	ob_log::write DEBUG {QUEUES: cleared $queue_name $q_idx ([llength $queue] elements)}
	return [list 0 $queue]
}


#
# Return the entire contents of a shared memory leaving it intact
#
# No locking is done during this read
#
proc ob_queues::view {q_idx {queue_name DFLTQ}} {

	variable CFG
	return [ob_queues::_get_queue $q_idx $queue_name]
}



#
# Return and remove the element at the head of the queue
#
# Clear is more efficient if only one process is operating on this
# queue
#
proc ob_queues::pop {q_idx {queue_name DFLTQ}} {

	variable CFG

	ob_queues::lock $q_idx $queue_name

	set queue [ob_queues::_get_queue $q_idx $queue_name]

	switch -- $CFG($queue_name,type) {
		"fifo" {
			if {[llength $queue] > 0} {
				set ret [ob_queues::_set_queue \
					$q_idx \
					[lrange $queue 1 end] \
					$queue_name]

				if {[lindex $ret 0]} {
					ob_queues::unlock $q_idx $queue_name
					ob_log::write DEBUG {QUEUES: $queue_name ERROR [lindex $ret 1]}
					return $ret
				}
			}
			ob_queues::unlock $q_idx $queue_name
			ob_log::write DEBUG {QUEUES: $queue_name poped element}
			return [list 0 [lindex $queue 0]]
		}
		"lifo" {
			if {[llength $queue] > 0} {
				set ret [ob_queues::_set_queue \
					$q_idx \
					[lrange $queue 0 end-1] \
					$queue_name]

				if {[lindex $ret 0]} {
					ob_queues::unlock $q_idx $queue_name
					ob_log::write DEBUG {QUEUES: $queue_name ERROR [lindex $ret 1]}
					return $ret
				}
			}
			ob_queues::unlock $q_idx $queue_name
			ob_log::write DEBUG {QUEUES: $queue_name poped element}
			return [list 0 [lindex $queue end]]
		}
	}
}



#----------------------------------
# Advertising
#----------------------------------

#
# Publish infomation about a queue
#
proc ob_queues::set_advert {q_idx name value {queue_name DFLTQ} {cache_time -1}} {

	variable CFG
	return [ob_queues::_shm_set \
		QUEUES($queue_name,$q_idx,advert,$name) \
		$value \
		$queue_name \
		$cache_time]
}


#
# Publish infomation about a queue
#
proc ob_queues::get_advert {q_idx name {queue_name DFLTQ} {default {}}} {

	variable CFG
	return [ob_queues::_shm_get \
		QUEUES($queue_name,$q_idx,advert,$name) \
		$default]
}

#
# Publish infomation about a queue
#
proc ob_queues::num_queues {{queue_name DFLTQ}} {
	variable CFG
	return $CFG($queue_name,count)
}


#
# Get the length of a queue
#
proc ob_queues::length {q_idx {queue_name DFLTQ}} {
	return [ob_queues::_get_queue_length $q_idx $queue_name]
}


#----------------------------------
# Public but a bit dangerous to use
#----------------------------------


#
# Lock a queue, not that if you lock a queue twice you
# will need to unlock it twice, this is to prevent a
# process blocking on its own lock
#
proc ob_queues::lock {q_idx {queue_name DFLTQ}} {
	variable CFG
	variable SEM

	set parentNamespace "[uplevel [list namespace current]]"
	set callingProc     [lindex [split [lindex [info level -1] 0] ":"] end]

	if {$SEM($queue_name,init) == 0} {
		#set SEM($queue_name,sem_id) [ipc_sem_create -nsems $CFG($queue_name,count) $CFG($queue_name,semaphore_port)]
		set SEM($queue_name,sem_id) [ipc_sem_create $CFG($queue_name,semaphore_port)]
		set SEM($queue_name,locks)  0
		set SEM($queue_name,init)   1
	}

	if {$SEM($queue_name,locks) < 1} {
		ob_log::write DEBUG {${parentNamespace}::$callingProc Locking $queue_name ($SEM($queue_name,sem_id))}

		ipc_sem_lock $SEM($queue_name,sem_id)
	}
	incr SEM($queue_name,locks)
}



#
# Unlock a queue
#
proc ob_queues::unlock {q_idx {queue_name DFLTQ}} {
	variable CFG
	variable SEM

	set parentNamespace "[uplevel [list namespace current]]"
	set callingProc     [lindex [split [lindex [info level -1] 0] ":"] end]

	incr SEM($queue_name,locks) -1
	if {$SEM($queue_name,locks) < 1} {
		ob_log::write DEBUG {${parentNamespace}::$callingProc Unlocking $queue_name ($SEM($queue_name,sem_id))}
		catch { ipc_sem_unlock $SEM($queue_name,sem_id)}
	}
}



#--------------------------------------------------- Private Functions

#
# Get the contents of a queue
#
proc ob_queues::_get_queue {queue_idx {queue_name DFLTQ}} {
	_shm_get QUEUES($queue_name,$queue_idx,queue) [list]
}


#
# Get the length of a queue
#
proc ob_queues::_get_queue_length {queue_idx {queue_name DFLTQ}} {
	variable BUFFER
	set shm_len [_shm_get QUEUES($queue_name,$queue_idx,length) 0]
	set buf_len [llength $BUFFER($queue_name,$queue_idx)]
	return [expr {$shm_len + $buf_len}]
}


#
# Set the contents of a queue
#
proc ob_queues::_set_queue {queue_idx queue {queue_name DFLTQ}} {

	ob_queues::lock $queue_idx $queue_name

	if {[lindex [set ret [ob_queues::_shm_set \
					QUEUES($queue_name,$queue_idx,queue) \
					$queue \
					$queue_name]] 0] == 0} {

		set ret [ob_queues::_shm_set \
						QUEUES($queue_name,$queue_idx,length) \
						[llength $queue] \
						$queue_name]


	}

	ob_queues::unlock $queue_idx $queue_name

	return $ret
}





#
# Pop a value into shared memory
#
proc ob_queues::_shm_set {shm_key value {queue_name DFLTQ} {cache_time -1}} {
	variable CFG

	# If no cache time is passed we should default to the queues cache_time
	if {$cache_time == -1} {
		set cache_time $CFG($queue_name,cache_time)
	}

	#  It seems that asStoreString can truncate the value if
	#  the string is TCL unicode (I think this happens if the low byte of the
	#  codepoint is 00, which is intepreted as a string termination character)
	set value [encoding convertto utf-8 $value]

	if {[catch { asStoreString $value $shm_key $cache_time} msg]} {
		ob_log::write CRITICAL {CRITICAL: failed to update shared memory: $msg}
		return [list 1 $msg]
	}

	return [list 0 OK]
}



#
# pull a value from shared memory
#
proc ob_queues::_shm_get {shm_key {default {}}} {
	variable CFG
	if {[catch {set value [asFindString $shm_key]}]} {
		return $default
	}

	# See _shm_set comment
	set value [encoding convertfrom utf-8 $value]
	return $value
}
