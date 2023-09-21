#============================================================
#============================================================
#
# Provides functionality to assign elements to a collection of queues in
# shared memory, the package supports both FIFO and FILO queue types
#
# multiple queue groups can be initialised using different name
# parameters, for effiecieny you should use a different semaphore id for each
# queue group, however this is not strictly necessary. When using muliple queue
# groups the queue group name should be passed in as parameter to each of the
# calls.
#
# Extra information about queues can be placed in shared
# memory. This information is not considered to be very important and so by
# default no semaphore locking is applied.
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
#		set_extra_info  : Store extra info about the queue in shared memory
#		get_extra_info  : Get extra info about the queue from shared_memory
#		num_queues  : get number of active queues
#		length      : get number of data elements on a queue
#
#

set pkg_version 1.0
package provide core::queue $pkg_version


package require core::log  1.0
package require core::args 1.1

core::args::register_ns \
	-namespace core::queue \
	-version   $pkg_version \
	-dependent [list core::log core::args] \
	-docs      util/queue.xml

namespace eval core::queue {
	variable CFG
	variable BUFFER
	variable SEM
	variable CORE_DEF

	set CORE_DEF(queue_index) [list -arg -queue_index -mand 1 -check INT    -desc {Index of the sub queue within the group to push/pop the value to}]
	set CORE_DEF(value)       [list -arg -value       -mand 1 -check NONE   -desc {Value to push/pop onto the queue}]
	set CORE_DEF(info_name)   [list -arg -info_name   -mand 1 -check ASCII  -desc {Name for extra information stored for queue}]
	set CORE_DEF(info_value)  [list -arg -info_value  -mand 1 -check NONE   -desc {Value of extra information stored for the queue}]

	set CORE_DEF(queue_name,opt) [list -arg -queue_name -mand 0 -check ASCII -default DFLTQ -desc {Name of the queue to use}]
	set CORE_DEF(cache_time,opt) [list -arg -cache_time -mand 0 -check INT   -default -1    -desc {Time to store the advert in shared memory}]
}


#
# Initialiase the queues
#
core::args::register \
	-proc_name core::queue::init \
	-desc      {Initialiase the queues} \
	-args [list \
		$::core::queue::CORE_DEF(queue_name,opt) \
		[list -arg -semaphore_id     -mand 0 -check INT                      -default_cfg QUEUES_SEMAPHORE_ID   -default 123456            -desc {Semaphore ID to create for locking the queue}] \
		[list -arg -count            -mand 0 -check INT                      -default_cfg QUEUES_COUNT          -default 1                 -desc {Number of queues in this queue group}] \
		[list -arg -cache_time       -mand 0 -check INT                      -default_cfg QUEUES_CACHE_TIME     -default 36000             -desc {Cache time of the queue}] \
		[list -arg -enable_buffering -mand 0 -check INT                      -default_cfg QUEUES_BUFFERING      -default 1                 -desc {Should buffering be enabled for this queue}] \
		[list -arg -type             -mand 0 -check {ENUM -args {fifo lifo}} -default_cfg QUEUES_TYPE           -default fifo              -desc {Type of data structure, Last in first out/first in first out}] \
		[list -arg -init_data        -mand 0 -check LIST                                                        -default {}                -desc {Initial queue data to load into the queue}] \
		[list -arg -init_method      -mand 0 -check {ENUM -args {BALANCED RANDOM MAPPED}}                       -default BALANCED          -desc {How to assign elements to different sub queues}] \
		[list -arg -queue_index_map  -mand 0 -check LIST                                                        -default {}                -desc {List of indexes to use for mapping initial data load to sub queues}] \
	] \
	-body {
		variable CFG
		variable BUFFER
		variable SEM

		set queue_name $ARGS(-queue_name)

		# If this queue has already been initialised,
		# don't initialise it again
		if {[info exists CFG($queue_name,name)]} {
			return
		}

		core::log::write DEBUG {QUEUES: initialising queue $queue_name}

		foreach param [array names ARGS] {
			set elem [string trimleft $param "-"]
			set CFG($queue_name,$elem) $ARGS($param)
		}

		# Initialise queue buffers
		if {$CFG($queue_name,enable_buffering)} {
			for {set i 0} {$i < $CFG($queue_name,count)} {incr i} {
				set BUFFER($queue_name,$i) [list]
			}
		}

		set SEM($queue_name,sem_id) [ipc_sem_create -nsems $CFG($queue_name,count) $CFG($queue_name,semaphore_id)]
		set SEM($queue_name,locks)  0

		# Regardless of whether there is data to load, all children must go through
		# this code to make sure that we do not start pushing to the queue before
		# data is loaded
		core::queue::_init_data \
			$queue_name \
			$ARGS(-init_method) \
			$ARGS(-init_data) \
			$ARGS(-queue_index_map)

		# Sets this queue as initialised
		set CFG($queue_name,name) $queue_name

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
core::args::register \
	-proc_name core::queue::push \
	-desc      {Add an item to a queue buffer. If buffering is enabled these items will not actually end up on the queue until flush is called} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(value) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		variable CFG
		variable BUFFER

		if {$CFG($ARGS(-queue_name),enable_buffering)} {
			lappend BUFFER($ARGS(-queue_name),$ARGS(-queue_index)) $ARGS(-value)
			return 1
		}


		core::queue::_lock $ARGS(-queue_index) $ARGS(-queue_name)
		set shm_queue [core::queue::_get_queue $ARGS(-queue_index) $ARGS(-queue_name)]

		set ret [core::queue::_set_queue \
			$ARGS(-queue_index) \
			[lappend shm_queue $ARGS(-value)] \
			$ARGS(-queue_name)]

		core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
		return $ret
	}


# Public:
#
# Add data to the end of a random queue of the given type
#
core::args::register \
	-proc_name core::queue::random_push \
	-desc      {Add data to the end of a random queue of the given type} \
	-args      [list \
		$::core::queue::CORE_DEF(value) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		set q_idx   [expr { int(rand() * [core::queue::num_queues -queue_name $ARGS(-queue_name)]) }]
		core::queue::push -queue_index $q_idx -value $ARGS(-value) -queue_name $ARGS(-queue_name)
		return $q_idx
	}


# Public:
#
# Add data to the end of the shortest queue
#
core::args::register \
	-proc_name core::queue::balanced_push \
	-desc      {Add data to the end of the shortest queue} \
	-args      [list \
		$::core::queue::CORE_DEF(value) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		set q_idx 0
		set q_len [core::queue::length -queue_index 0 -queue_name $ARGS(-queue_name)]

		for {set i 0} {$i < [core::queue::num_queues -queue_name $ARGS(-queue_name)]} {incr i} {
			if {[core::queue::length -queue_index $i -queue_name $ARGS(-queue_name)] < $q_len} {
				set q_idx $i
			}
		}
		core::queue::push -queue_index $q_idx -value $ARGS(-value) -queue_name $ARGS(-queue_name)
		return $q_idx
	}



# Public
#
# Clear the contents of the queue buffers onto the shared
# memory queues
#
core::args::register \
	-proc_name core::queue::flush \
	-desc      {Clear the contents of the queue buffers onto the shared memory queues} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		variable CFG
		variable BUFFER

		set queue_name $ARGS(-queue_name)

		if {!$CFG($queue_name,enable_buffering)} {
			return 1
		}

		# Pass each queue locking the message and appending it to the correct queue
		for {set i 0} {$i < $CFG($queue_name,count)} {incr i} {
			set q_buf_len [llength $BUFFER($queue_name,$i)]
			if {$q_buf_len > 0} {
				core::log::write DEBUG {QUEUES: flushing buffer $i ($q_buf_len elements)}
				core::queue::_lock $i $queue_name

				set shm_queue [core::queue::_get_queue $i $queue_name]

				if {[catch {
					set ret [core::queue::_set_queue \
						$i \
						[concat $shm_queue $BUFFER($queue_name,$i)] \
						$queue_name]
				} msg]} {
					set remaining_buffers [expr {$CFG($queue_name,count) - $i - 1}]
					core::log::write DEBUG {QUEUES: Failed to flush buffer $i, skipping\
						$remaining_buffers remaining buffers}
					core::queue::_unlock $i $queue_name
					error $msg $::errorInfo $::errorCode
				}

				core::queue::_unlock $i $queue_name
				set BUFFER($queue_name,$i) [list]
			}
		}
		core::log::write DEBUG {QUEUES $queue_name: flush completed}

		return 1
	}

#------------------------------
# Retrieval Procs
#------------------------------


#
# Return the contents of a shared memory queue clearing its contents
#
core::args::register \
	-proc_name core::queue::clear \
	-desc      {Return the contents of a shared memory queue clearing its contents} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(queue_name,opt) \
		[list -arg -entry_index -mand 0 -check INT -default -1  -desc {Index of the entry you want to clear}] \
	] \
	-body {
		variable CFG

		core::queue::_lock $ARGS(-queue_index) $ARGS(-queue_name)

		set entry_index $ARGS(-entry_index)

		set queue_name   $ARGS(-queue_name)
		set queue        [core::queue::_get_queue $ARGS(-queue_index) $queue_name]
		set queue_length [llength $queue]
		set selected     [list]
		set cleared      0

		if {$queue_length > 0} {

			if {$entry_index == -1} {
				set selected  $queue
				set remaining [list]
				set cleared   $queue_length
			} else {
				set selected  [lindex   $queue $entry_index]
				set remaining [lreplace $queue $entry_index $entry_index]
				set cleared   1
			}

			if {[catch {
				set ret [core::queue::_set_queue \
					$ARGS(-queue_index) \
					$remaining \
					$queue_name]
			} msg]} {
				core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
				error $msg $::errorInfo $::errorCode
			}
		}

		core::queue::_unlock $ARGS(-queue_index) $queue_name
		core::log::write DEBUG {QUEUES: cleared $queue_name $ARGS(-queue_index) ($cleared elements)}
		return $selected
	}


#
# Return the entire contents of a shared memory leaving it intact
#
# No locking is done during this read
#
core::args::register \
	-proc_name core::queue::view \
	-desc      {Return the entire contents of a shared memory leaving it intact. No locking is done during this read} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		return [core::queue::_get_queue $ARGS(-queue_index) $ARGS(-queue_name)]
	}


#
# Return and remove the element at the head of the queue
#
# Clear is more efficient if only one process is operating on this
# queue
#
core::args::register \
	-proc_name core::queue::pop \
	-desc      {Return and remove the element at the head of the queue. Clear is more efficient if only one process is operating on this queue} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		variable CFG

		core::queue::_lock $ARGS(-queue_index) $ARGS(-queue_name)

		set queue [core::queue::_get_queue $ARGS(-queue_index) $ARGS(-queue_name)]
		set queue_length [llength $queue]

		switch -- $CFG($ARGS(-queue_name),type) {
			"fifo" {
				if {$queue_length > 0} {
					if {[catch {
						set ret [core::queue::_set_queue \
							$ARGS(-queue_index) \
							[lrange $queue 1 end] \
							$ARGS(-queue_name)]
					} msg]} {
						core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
						error $msg $::errorInfo $::errorCode
					}
				}
				core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
				core::log::write DEBUG {QUEUES: $ARGS(-queue_name) poped element}
				return [lindex $queue 0]
			}
			"lifo" {
				if {$queue_length > 0} {
					if {[catch {
						set ret [core::queue::_set_queue \
							$ARGS(-queue_index) \
							[lrange $queue 0 end-1] \
							$ARGS(-queue_name)]
					} msg]} {
						core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
						error $msg $::errorInfo $::errorCode
					}
				}
				core::queue::_unlock $ARGS(-queue_index) $ARGS(-queue_name)
				core::log::write DEBUG {QUEUES: $ARGS(-queue_name) poped element}
				return [lindex $queue end]
			}
		}
	}



#----------------------------------
# Advertising
#----------------------------------

#
# Set infomation about a queue
#
core::args::register \
	-proc_name core::queue::set_extra_info \
	-desc      {Set extra infomation about a queue} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(info_name) \
		$::core::queue::CORE_DEF(info_value) \
		$::core::queue::CORE_DEF(queue_name,opt) \
		$::core::queue::CORE_DEF(cache_time,opt) \
	] \
	-body {
		return [core::queue::_shm_set \
			QUEUES($ARGS(-queue_name),$ARGS(-queue_index),info,$ARGS(-info_name)) \
			$ARGS(-info_value) \
			$ARGS(-queue_name) \
			$ARGS(-cache_time)]
	}


#
# Get infomation about a queue
#
core::args::register \
	-proc_name core::queue::get_extra_info \
	-desc      {Get extra infomation about a queue} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(info_name) \
		$::core::queue::CORE_DEF(queue_name,opt) \
		[list -arg -default_value -mand 0 -check STRING -default {} -desc {Get infomation about a queue}] \
	] \
	-body {
		return [core::queue::_shm_get \
			QUEUES($ARGS(-queue_name),$ARGS(-queue_index),info,$ARGS(-info_name)) \
			$ARGS(-default_value)]
	}

#
# Get the number of sub queues within this group of queues
#
core::args::register \
	-proc_name core::queue::num_queues \
	-desc      {Get the number of sub queues within this group of queues} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		variable CFG
		return $CFG($ARGS(-queue_name),count)
	}


#
# Get the length of a queue
#
core::args::register \
	-proc_name core::queue::length \
	-desc      {Get the length of a queue} \
	-args      [list \
		$::core::queue::CORE_DEF(queue_index) \
		$::core::queue::CORE_DEF(queue_name,opt) \
	] \
	-body {
		return [core::queue::_get_queue_length $ARGS(-queue_index) $ARGS(-queue_name)]
	}


#----------------------------------
# Private Locking Procedure
#----------------------------------


#
# Lock a queue, note that if you lock a queue twice you
# will need to unlock it twice, this is to prevent a
# process blocking on its own lock
#
proc core::queue::_lock {q_idx {queue_name DFLTQ}} {
	variable CFG
	variable SEM

	if {$SEM($queue_name,locks) < 1} {
		set parentNamespace [uplevel 1 [list namespace current]]
		set callingProc     [lindex [split [lindex [info level -1] 0] ":"] end]
		core::log::write DEBUG {${parentNamespace}::$callingProc Locking $queue_name ($SEM($queue_name,sem_id))}

		ipc_sem_lock $SEM($queue_name,sem_id) $q_idx
	}
	incr SEM($queue_name,locks)
}



#
# Unlock a queue
#
proc core::queue::_unlock {q_idx {queue_name DFLTQ}} {
	variable CFG
	variable SEM

	incr SEM($queue_name,locks) -1
	if {$SEM($queue_name,locks) < 1} {
		set parentNamespace [uplevel 1 [list namespace current]]
		set callingProc     [lindex [split [lindex [info level -1] 0] ":"] end]
		core::log::write DEBUG {${parentNamespace}::$callingProc Unlocking $queue_name ($SEM($queue_name,sem_id))}
		catch { ipc_sem_unlock $SEM($queue_name,sem_id) $q_idx}
	}
}



#--------------------------------------------------- Private Functions

#
# Get the contents of a queue
#
proc core::queue::_get_queue {queue_idx {queue_name DFLTQ}} {
	_shm_get QUEUES($queue_name,$queue_idx,queue) [list]
}


#
# Get the length of a queue
#
proc core::queue::_get_queue_length {queue_idx {queue_name DFLTQ}} {
	variable BUFFER
	variable CFG

	set buf_len 0
	set shm_len [_shm_get QUEUES($queue_name,$queue_idx,length) 0]

	if {$CFG($queue_name,enable_buffering)} {
		set buf_len [llength $BUFFER($queue_name,$queue_idx)]
	}

	return [expr {$shm_len + $buf_len}]
}


#
# Set the contents of a queue
#
proc core::queue::_set_queue {queue_idx queue {queue_name DFLTQ}} {

	core::queue::_lock $queue_idx $queue_name

	if {[catch {
		if {[core::queue::_shm_set \
				QUEUES($queue_name,$queue_idx,queue) \
				$queue \
				$queue_name]} {

			set ret [core::queue::_shm_set \
				QUEUES($queue_name,$queue_idx,length) \
				[llength $queue] \
				$queue_name]
		}
	} msg]} {
		core::queue::_unlock $queue_idx $queue_name
		error $msg $::errorInfo $::errorCode
	}

	core::queue::_unlock $queue_idx $queue_name

	return $ret
}





#
# Pop a value into shared memory
#
proc core::queue::_shm_set {shm_key value {queue_name DFLTQ} {cache_time -1}} {
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
		core::log::write CRITICAL {CRITICAL: failed to update shared memory: $msg}
		error $msg $::errorInfo $::errorCode
	}

	return 1
}



#
# pull a value from shared memory
#
proc core::queue::_shm_get {shm_key {default {}}} {
	variable CFG

	if {[catch {set value [asFindString -copy $shm_key]}]} {
		return $default
	}

	# See _shm_set comment
	set value [encoding convertfrom utf-8 $value]

	return $value
}


#
# Initialise the queue with the provided data
#
proc core::queue::_init_data {queue_name init_method init_data {queue_index_map {}}} {
	variable CFG

	set num_queues [core::queue::num_queues -queue_name $queue_name]

	core::queue::_lock 0 $queue_name

	# If we catch an ERROR (i.e. catch returns 1) then the data has
	# not yet been initialised
	set uninit [catch {asFindString -copy QUEUES($queue_name,initialised)}]

	if {$init_data != {} && $uninit == 1} {
		switch -exact -- $init_method {
			BALANCED {
				# There will be no data in the queue(s) so
				# we can just round robin
				set index 0
				foreach item $init_data {
					if {$index == $num_queues} {
						set index 0
					}

					lappend INIT($index) $item

					incr index
				}
			}
			RANDOM {
				# Randomly assign an index for each
				# queue item
				foreach item $init_data {
					set index [expr { int(rand() * $num_queues) }]
					lappend INIT($index) $item
				}
			}
			MAPPED {
				# Use a list of indexes to map each queue
				# item to a specific queue index

				if {[llength $queue_index_map] != [llength $init_data]} {
					error "Init data and index map lists are not of equal length" {} QUEUE_INIT_INVALID_MAPPING_DATA
				}

				foreach item $init_data index $queue_index_map {
					if {$index >= $num_queues} {
						error "Cannot map item - index is greater than number of queues" {} QUEUE_INIT_INVALID_INDEX
					}

					lappend INIT($index) $item
				}
			}
		}

		for {set index 0} {$index < $num_queues} {incr index} {

			# It is possible that not all indexes had any queue
			# items mapped to them so only set the queue if there
			# is something to set
			if {[info exists INIT($index)]} {

				core::log::write INFO {Init Method : $init_method : Loading [llength $INIT($index)] item(s)\
					to queue $queue_name with index $index}
				core::log::write DEV  {Initial Data $INIT($index) loaded to queue $queue_name with index $index}

				if {[catch {
					core::queue::_set_queue \
						$index \
						$INIT($index) \
						$queue_name
				} msg]} {
					core::queue::_unlock 0 $queue_name
					error $msg $::errorInfo $::errorCode
				}
			}
		}
	}

	# All children must run this to ensure the first child to hit this
	# code is the only one to run it. This avoids initial data being
	# loaded after other children have started pushing to the queue
	if {[catch {
		core::queue::_shm_set \
			QUEUES($queue_name,initialised) \
			1 \
			$queue_name
	} msg]} {
		core::queue::_unlock 0 $queue_name
		error $msg $::errorInfo $::errorCode
	}

	core::queue::_unlock 0 $queue_name
}
