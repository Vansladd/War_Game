#==============================================================
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/appserv/messageboard.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#==============================================================

#==============================================================
# SYNOPSIS:
#   Provides message board functionality between appserver
#   children
#
#	::init              : Setup access to a message board (this does not subscribe)
#	::broadcast         : Publish a message to all listeners
#	::post              : Post to a specific listener
#	::has_messages      : Check if messages are available without removing them
#	::messages          : return the outstanding messages
#	::subscribe         : register as a listener on a message board
#	::unsubscribe       : de-register as a listener on a message board
#
#==============================================================


package provide appserv_messageboard 4.5

package require util_log


namespace eval ob_messageboard {
	variable CFG
	variable SEM
}


#-----------------------------------------------
# Initialise module
#-----------------------------------------------
proc ob_messageboard::init args {

	variable SEM
	variable MSG_BOARD
	variable CFG

	# Setup a name for this queue group
	if {[set id [lsearch $args "-name"]] >= 0} {
		set message_type [lindex $args [expr {$id + 1}]]
		set CFG($message_type,name)  $message_type
	} else {
		set message_type DFLT
		set CFG($message_type,name)  $message_type
	}

	if {[info exists MSG_BOARD($message_type,last_msg_id)]} {
		return
	}

	set MSG_BOARD($message_type,last_msg_id)   0
	set MSG_BOARD($message_type,subscriptions) [list]

	set SEM($message_type,init) 0

	# Setup defaults
	set CFG($message_type,semaphore_port)       [OT_CfgGet PORTS]
	set CFG($message_type,cache_time)           36000
	set CFG($message_type,ttl)                  3600


	# override with supplied arguements
	foreach {n v} $args {
		set cfg_name [string tolower [string range $n 1 end]]
		if {![info exists CFG($message_type,$cfg_name)] || $v == ""} {
			error "Invalid argument '$n'"
		}
		set CFG($message_type,$cfg_name) $v
	}

}


#------------------------------------
# Publish a message to all listeners
#------------------------------------
proc ob_messageboard::broadcast {msg {message_type DFLT}} {
	ob_messageboard::_send_message [ob_messageboard::_get_listeners $message_type] $msg $message_type
}


#-------------------------------------------------
# Publish a message a particular list of listeners
# all listeners of the tag will get the message
#-------------------------------------------------
proc ob_messageboard::post {to msg {message_type DFLT}} {

	ob_log::write DEBUG {MSGBOARD: ==> ob_messageboard::post $to $msg $message_type}

	set listeners [_get_listeners $message_type]

	# Scan through listeners to see who this applies to
	set to_list [list]

	foreach listener $listeners {
		foreach tag $to {
			ob_log::write DEBUG {MSGBOARD: "^${tag}\.\d+$" matched  $listener}
			if {[regexp "^${tag}\\.\\d+$" $listener]} {
				lappend to_list $listener
			}
		}
	}

	# Scan through listeners to see who this applies to
	if {[llength $to_list] > 0} {
		_send_message $to_list $msg $message_type
	}
	ob_log::write DEBUG {MSGBOARD: <== ob_messageboard::post sent to $to_list}
}


#------------------------------------------
# Check if messages are available for the listener
# without actually removing them
#------------------------------------------
proc ob_messageboard::has_messages {{message_type DFLT}} {

	variable MSG_BOARD

	ob_log::write DEBUG {MSGBOARD: ==> ob_messageboard::has_messages $message_type}

	set max_msg [_get_latest_message $message_type]
	if {$max_msg <= $MSG_BOARD($message_type,last_msg_id)} {return 0}
	return 1
}



#------------------------------------------
# Return all pending messages since messages
# were last retrieved. Messages will be removed
# from the message board if they have expired
# or if all listeners have retrieved them
#------------------------------------------
proc ob_messageboard::messages {{message_type DFLT}} {

	variable MSG_BOARD

	ob_log::write DEBUG {MSGBOARD: ==> ob_messageboard::messages $message_type}

	set max_msg [_get_latest_message $message_type]
	set messages [list]

	ob_log::write DEBUG {MSGBOARD: last message = $MSG_BOARD($message_type,last_msg_id) latest message = $max_msg}

	if {$max_msg > $MSG_BOARD($message_type,last_msg_id)} {
		set messages [_get_messages_from $MSG_BOARD($message_type,last_msg_id) $message_type]
	}
	ob_log::write DEBUG {MSGBOARD: <== ob_messageboard::messages returning [llength $messages] messages}
	return $messages

}



#----------------------------------
# subscribe to a given message list
#
# tag 
# ---
#	this allows differentiation of listener groups. You can post messages
#   to a particular tag and only those children registering on the tag will
#   receive them, the defaults is ASCHILD, this is the simplest usage and means
#   that every child will receive every message
#
# message_type 
# ------------
#   The message board to which you want to subscribe, this should be used
#   if you are using multiple message boards
#
#----------------------------------
proc ob_messageboard::subscribe {{tag ASCHILD} {message_type DFLT}} {

	variable CFG
	variable MSG_BOARD

	ob_log::write DEBUG {MSGBOARD: ==> ob_messageboard::subscribe $tag $message_type}

	if {[info exists MSG_BOARD($message_type,subscription_tag)]} {
		ob_log::write DEBUG {MSGBOARD: already subscribed}
		return
	}

	ob_messageboard::_lock $message_type

	# Find a clear subscription index on this tag
	#--------------------------------------------
	set shm_queue [ob_messageboard::_shm_get MSG_BOARD($message_type,listeners)]



	# Add subscription to the list of registered listeners
	#-----------------------------------------------------
	set MSG_BOARD($message_type,subscription_tag) "${tag}.[asGetId]"

	while {[lsearch $shm_queue $MSG_BOARD($message_type,subscription_tag)] < 0} {
		ob_log::write DEBUG {MSGBOARD: subscribing with tag  $MSG_BOARD($message_type,subscription_tag)}
		ob_messageboard::_shm_set MSG_BOARD($message_type,listeners)  [lappend shm_queue $MSG_BOARD($message_type,subscription_tag)]
		set MSG_BOARD($message_type,last_msg_id) [ob_messageboard::_shm_get MSG_BOARD($message_type,max_msg_id) 0]
	}

	ob_messageboard::_unlock $message_type
}


#------------------------------------
# unsubscribe to a given message list
#------------------------------------
proc ob_messageboard::unsubscribe {{message_type DFLT}} {

	variable CFG
	variable MSG_BOARD

	ob_messageboard::_lock $message_type

	set shm_queue [ob_messageboard::_shm_get \
		MSG_BOARD($message_type,listeners)]

	if {[set my_idx [lsearch $shm_queue $MSG_BOARD(subscription_tag)]] >= 0} {
		ob_messageboard::_shm_set MSG_BOARD($message_type,listeners)  \
									[concat \
										[lrange $shm_queue 0  [expr {$my_idx - 1}]] \
										[lrange $shm_queue [expr {$my_idx + 1}] end] \
									]
	}
	catch {unset MSG_BOARD($message_type,subscription_tag)}

	ob_messageboard::_unlock $message_type
}




#----------------------------------------------------------------- PRIVATE


#----------------------------------------------------
# Clean up the message queue returning a list of all
# messages greater than the given id
#----------------------------------------------------
proc ob_messageboard::_get_messages_from {last_msg_id message_type} {

	variable CFG
	variable MSG_BOARD

	ob_log::write DEBUG {MSGBOARD: ==> ob_messageboard::_get_messages_from $last_msg_id $message_type}

	ob_messageboard::_lock
	
	set msg_queue [ob_messageboard::_shm_get MSG_BOARD($message_type,messages)]

	set new_msg_board [list]
	set my_messages   [list]
	set now  [clock seconds]

	ob_log::write DEBUG {MSGBOARD: messages on board = [llength $msg_queue]}

	set msg_id $last_msg_id

	foreach msg_packet $msg_queue {


		foreach {msg_id recipients ttl msg} $msg_packet {}

		ob_log::write DEBUG {MSGBOARD: message $msg_id | $recipients | $ttl | $msg }
		
		# delete old messages
		if {$ttl < $now} {
			ob_log::write INFO {MSGBOARD: message expired : $msg}
			continue
		}
		
		# check if the message is pertinent
		if {$msg_id > $last_msg_id} {

			if {[set idx [lsearch $recipients $MSG_BOARD($message_type,subscription_tag)]] >= 0} {
				lappend my_messages $msg

				# If I am the last recipient then remove message
				if {[llength $recipients] < 2} {continue}

				# Remove myself from the recipients list
				set recipients  [concat \
									[lrange $recipients 0  [expr {$idx - 1}]] \
									[lrange $recipients [expr {$idx + 1}] end]]
			}
		}

		lappend new_msg_board [list $msg_id $recipients $ttl $msg]
	}

	set MSG_BOARD(last_msg_id) [_get_latest_message $message_type]

	# Reset the message board
	ob_messageboard::_shm_set MSG_BOARD($message_type,messages) $new_msg_board

	ob_messageboard::_unlock

	ob_log::write DEBUG {MSGBOARD: <== ob_messageboard::_get_messages_from returning [llength $my_messages] messages}
	return $my_messages
}



#----------------------------------------------------
# Send a message to a particular set of listeners
#----------------------------------------------------
proc ob_messageboard::_send_message {to msg message_type} {
	
	variable CFG

	ob_messageboard::_lock
	
	set shm_queue [ob_messageboard::_shm_get \
		MSG_BOARD($message_type,messages)]

	set max_msg [ob_messageboard::_get_latest_message $message_type]
	incr max_msg

	set ttl [expr {[clock scan seconds] + $CFG($message_type,ttl)}]

	ob_messageboard::_shm_set \
		MSG_BOARD($message_type,messages) \
		[lappend shm_queue [list $max_msg $to $ttl $msg]]

	ob_messageboard::_shm_set \
		MSG_BOARD($message_type,max_msg_id) \
		$max_msg

	ob_messageboard::_unlock

}

#---------------------------------------
# Find the id of the last posted message
#---------------------------------------
proc ob_messageboard::_get_latest_message {message_type} {

	variable CFG
	variable MSG_BOARD

	return [ob_messageboard::_shm_get  MSG_BOARD($message_type,max_msg_id) 0]
}



#----------------------------------------------------
# Return a list of all listeners subscribed to the given
# message board
#----------------------------------------------------
proc ob_messageboard::_get_listeners {message_type} {

	set listeners [ob_messageboard::_shm_get \
					MSG_BOARD($message_type,listeners)]
	return [eval list $listeners]
}










#
# Lock a queue, not that if you lock a queue twice you
# will need to unlock it twice, this is to prevent a
# process blocking on its own lock
#
proc ob_messageboard::_lock {{message_type DFLT}} {

	variable CFG
	variable SEM

	if {$SEM($message_type,init) == 0} {
		set SEM($message_type,sem_id) [ipc_sem_create $CFG($message_type,semaphore_port)]
		set SEM($message_type,locks)  0
		set SEM($message_type,init)   1
	}

	if {$SEM($message_type,locks) < 1} {
		ipc_sem_lock $SEM($message_type,sem_id)
	}
	incr SEM($message_type,locks)
}



#
# Unlock a message queue
#
proc ob_messageboard::_unlock {{message_type DFLT}} {
	variable CFG
	variable SEM

	incr SEM($message_type,locks) -1
	if {$SEM($message_type,locks) < 1} {
		catch { ipc_sem_unlock $SEM($message_type,sem_id)}
	}
}




#
# Pop a value into shared memory
#
proc ob_messageboard::_shm_set {shm_key value {message_type DFLT}} {
	variable CFG

	#  It seems that asStoreString can truncate the value if 
	#  the string is TCL unicode (I think this happens if the low byte of the 
	#  codepoint is 00, which is intepreted as a string termination character) 
	set value [encoding convertto utf-8 $value] 

	if {[catch { asStoreString $value $shm_key $CFG($message_type,cache_time) } msg]} {
		ob_log::write CRITICAL {MSGBOARD: CRITICAL: failed to update shared memory: $msg}
	}
}



#
# pull a value from shared memory
#
proc ob_messageboard::_shm_get {shm_key {default {}}} {
	variable CFG
	if {[catch {set value [asFindString $shm_key]}]} {
		return $default
	}

	# See _shm_set comment
	set value [encoding convertfrom utf-8 $value]
	return $value
}



