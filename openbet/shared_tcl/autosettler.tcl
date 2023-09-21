#==============================================================
# $Id: autosettler.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#==============================================================

#--------------------------------------------------------------------------
# Synopsis
# Provide accessor methods to query and alter states in the autosettler app
#--------------------------------------------------------------------------

#####################################
namespace eval ::OB_auto_settle {
#####################################


	variable ERR_DEFN
	array set ERR_DEFN [list]
	set ERR_DEFN(test)  "test"

	set ERR_DEFN(ERROR)                          "An Error Occured"
	set ERR_DEFN(ERR_BLOCK_NOT_FOUND)            "Specified Block was not found"
	set ERR_DEFN(ERR_CANT_REMOVE_FROM_QUEUE)     "Unable to remove item from queue"
	set ERR_DEFN(ERR_EMPTY_REQUEST)              "Null request passed"
	set ERR_DEFN(ERR_EOF)                        "End of file encountered"
	set ERR_DEFN(ERR_EXPIRED_TIMESTAMP)          "Queue has expired"
	set ERR_DEFN(ERR_FAILED_TO_GET_SETTLE_DATA)  "Failed to get application data"
	set ERR_DEFN(ERR_GETS_FAILED)                "Could not read from socket"
	set ERR_DEFN(ERR_INVALID_CRITERIA)           "Invalid criteria supplied"
	set ERR_DEFN(ERR_INVALID_DATA_ITEM)          "Invalid data item"
	set ERR_DEFN(ERR_INVALID_QUEUE)              "Specified queue is not recognied"
	set ERR_DEFN(ERR_NO_ACTION_SPECIFIED)        "No action was specified"
	set ERR_DEFN(ERR_UNABLE_TO_STORE_BLOCK)      "Unable to store block"
	set ERR_DEFN(ERR_UNKNOWN_ACTION)             "Unrecognised request"
	set ERR_DEFN(ERR_UNRECOGNISED_ITEM)          "Unrecognised item"
}

##########################################
proc ::OB_auto_settle::get_err_desc {id} {
##########################################

	variable ERR_DEFN

	if {[info exists ERR_DEFN($id)]} {
		return $ERR_DEFN($id)
	} else {
		return "An Error Occured contacting Autosettler $id"
	}

}


###############################################
proc ::OB_auto_settle::renew_block {id {delay ""}} {
###############################################
#--------------------------------------------------
# Block a market given the markets queue identifier
#--------------------------------------------------

	set response [eval "list [_send_msg [list action RENEW_BLOCK id $id delay $delay]]"]
	if {[lindex $response 0] == 1} {return [list 1 $id]}
	return $response

}

###############################################
proc ::OB_auto_settle::unblock {id} {
###############################################
#--------------------------------------------------
# Block a market given the markets queue identifier
#--------------------------------------------------

	set response [eval "list [_send_msg [list action UNBLOCK id $id]]"]
	if {[lindex $response 0] == 1} {return [list 1 $id]}
	return $response

}



###############################################
proc ::OB_auto_settle::get_status {} {
###############################################
#--------------------------------------------------
# Block a market given the markets queue identifier
#--------------------------------------------------

	set response [eval "list [_send_msg [list action GET_STATUS]]"]
	if {[lindex $response 0] == 0} {
		return "OFF"
	} elseif {[lindex $response 1] == 1} {
		return "ACTIVE"
	} elseif {[lindex $response 0] == 1} {
		return "SUSPENDED"
	} else {
		return "UNKNOWN"
	}
}


###################################
proc ::OB_auto_settle::turn_off {} {
###################################
#--------------------------------------------------
# Turn off the app
#--------------------------------------------------
	set response [eval "list [_send_msg [list action STOP]]"]
	if {[lindex $response 0] == 1} {return [list 1 OFF]}
	return $response
}



###################################
proc ::OB_auto_settle::turn_on {} {
###################################
#--------------------------------------------------
# Turn off the app
#--------------------------------------------------
	set response [eval "list [_send_msg [list action START]]"]
	if {[lindex $response 0] == 1} {return [list 1 ON]}
	return $response
}



###################################
proc ::OB_auto_settle::reset {} {
###################################
#--------------------------------------------------
# Turn off the app
#--------------------------------------------------
	set response [eval "list [_send_msg [list action RESET]]"]
	if {[lindex $response 0] == 1} {return [list 1 RESET]}
	return $response
}


###################################################
proc ::OB_auto_settle::block {what id {delay ""}} {
###################################################
#--------------------------------------------------
# Block a market given the markets queue identifier
#--------------------------------------------------

	set response [eval "list [_send_msg [list action BLOCK what $what id $id delay $delay]]"]
	if {[lindex $response 0] == 1} {return [list 1 $id]}
	return $response
}




###############################################
proc ::OB_auto_settle::get_queues {array_name} {
###############################################
#----------------------------------------------------------------
# Get the queue from the autosettler and load it into given array
#----------------------------------------------------------------


	upvar $array_name Q

	set events_present 0

	# Get the Queue Data
	#----------------------
	set response [eval "list [_send_msg [list action GET_QUEUES]]"]

	if {[lindex $response 0] != 0} {

		set queue_data [eval "list [lindex $response 1]"]

		set q_idx 0
		foreach queue $queue_data {
			set queue [eval "list $queue"]

			# Register the new queue
			#-----------------------
			set Q($q_idx,ref)              [lindex $queue 0]
			set Q($q_idx,expires)          [lindex $queue 1]
			set Q($q_idx,categories)       [lindex $queue 2]
			set Q($q_idx,num_classes)     0

			# Check if Event information is present
			if {[llength [lindex $queue 3]] > 0} {
				set events_present 1
			}

			set class_idx 0
			foreach class [eval "list [lindex $queue 3]"] {


				set class      [eval "list $class"]
				set Q($q_idx,$class_idx,id)    [lindex $class 0]
				set Q($q_idx,$class_idx,name)  [lindex $class 1]

				set type_idx 0
				foreach type [lindex $class 2] {

					set type      [eval "list $type"]
					set Q($q_idx,$class_idx,$type_idx,id)    [lindex $type 0]
					set Q($q_idx,$class_idx,$type_idx,name)  [lindex $type 1]

					set event_idx 0
					foreach event [lindex $type 2] {

						set event [eval "list $event"]
						set Q($q_idx,$class_idx,$type_idx,$event_idx,id)         [lindex $event 0]
						set Q($q_idx,$class_idx,$type_idx,$event_idx,name)       [lindex $event 1]
						set Q($q_idx,$class_idx,$type_idx,$event_idx,start_time) [lindex $event 2]

						set mkt_idx 0
						foreach market [lindex $event 3] {

							set market [eval "list $market"]
							set Q($q_idx,$class_idx,$type_idx,$event_idx,$mkt_idx,id)   [lindex $market 0]
							set Q($q_idx,$class_idx,$type_idx,$event_idx,$mkt_idx,name) [lindex $market 1]
							set Q($q_idx,$class_idx,$type_idx,$event_idx,$mkt_idx,ref)  [lindex $market 2]
							incr mkt_idx
						}
						set Q($q_idx,$class_idx,$type_idx,$event_idx,num_markets)  $mkt_idx
						incr event_idx
					}
					set Q($q_idx,$class_idx,$type_idx,num_events)  $event_idx
					incr type_idx
				}
				set Q($q_idx,$class_idx,num_types)  $type_idx
				incr class_idx
			}
			set Q($q_idx,num_classes)  $class_idx
			incr q_idx
		}
		set Q(num_queues)  $q_idx

		if {$events_present} {
			set Q(events_avail) 1
		} else {
			set Q(events_avail) 0
		}

		return [list 1 QUEUES_FOUND]
	}

	OT_LogWrite 2 "unable to get queues : $response)"

	return $response
}


###############################################
proc ::OB_auto_settle::get_blocks {array_name block_type {descriptive 1}} {
###############################################
#----------------------------------------------------------------
# Get the queue from the autosettler and load it into given array
#----------------------------------------------------------------

	upvar $array_name B

	# Query the AutoSettler
	#----------------------
	set response [eval "list [_send_msg [list action GET_BLOCKS descriptive $descriptive block_type $block_type]]"]

	set B(num_blocks) 0

	if {[lindex $response 0] != 0} {

		set block_data [eval "list [lindex $response 1]"]

		foreach block $block_data {

			# Extract block info
			#-------------------
			set block [eval "list $block"]

			# Register the new block
			#-----------------------
			set b_id $B(num_blocks)
			set B($b_id,block_id)    [lindex $block 0]
			set block_details        [eval "list [lindex $block 1]"]
			set B($b_id,type)        [lindex $block_details 0]
			set B($b_id,type_id)     [lindex $block_details 1]
			set B($b_id,valid_until) [lindex $block_details 2]

			if {[string index $B($b_id,valid_until) 0] > 2} {
				set B($b_id,valid_until) "PERMANENT"
			}

			incr B(num_blocks)
		}
		return [list 1 BLOCKS_FOUND]
	}
	return $response
}


#------------------------------------------------------------ Private utility functions



#######################################
proc ::OB_auto_settle::_send_msg {msg} {
#######################################

	ob::log::write DEBUG {OB_auto_settle : _send_msg  ===>  $msg}

	set port [OT_CfgGet AUTOSETTLE_PORT "18805"]

	if {[OT_CfgGet AUTOSETTLE_USE_FEED_LOCK 0] == 1} {
		set feed_name [OT_CfgGet AUTOSETTLE_FEED_NAME "AutoSettler"]

		set host [OB_feedlock::get_lock_host $feed_name]
	} else {
		set host [OT_CfgGet AUTOSETTLE_HOST "localhost"]
	}

	OT_LogWrite 1 "OB_auto_settle : _send_msg Connecting to $host on port $port"

	# Establish socket connection
	#----------------------------
	if {[lindex [set sock [_socket_timeout $host $port 20000]] 0] == 0} {
		OT_LogWrite 3 "Failed to connect to autosettler $sock"
		return $sock
	}

	set sock [lindex $sock 1]

	if {[catch {

		# Pass in our message
		#--------------------
		puts $sock $msg

		# Wait for reply
		#---------------
		set ret_list [_gets_timeout $sock [OT_CfgGet AUTOSETTLE_TIMEOUT 20000]]

	} err]} {
		ob::log::write DEBUG {OB_auto_settle : _send_msg : failed connect : $err }
		set ret_list [list 0 FAILED_CONNECT]
	}

	catch {close $sock}
	ob::log::write DEBUG {OB_auto_settle : _send_msg  <===  }

	return $ret_list
}



#####################################################
proc ::OB_auto_settle::_gets_timeout {sock timeout} {
#####################################################
#----------------------------------------------------
# Attempt to read from the given socket with a timeout
#----------------------------------------------------

	global msg_recieved

	# Set up socket for non blocking
	#-------------------------------
	set msg_recieved ""
	fconfigure $sock -blocking 1 -buffering line

	fileevent $sock r {set msg_recieved "OK"}
	set id [after $timeout {set msg_recieved "TIMED_OUT"}]

	# Enter event loop and wait
	#--------------------------
	vwait msg_recieved
	after cancel $id

	if { $msg_recieved == "TIMED_OUT" } {
		return [list 0 ERR_TIMEOUT]
	}

	# Gather the result
	#------------------
	return [gets $sock]
}


############################################################
proc ::OB_auto_settle::_socket_timeout {host port timeout} {
############################################################
#----------------------------------------------------
# Establish a socket connection with the given timout
#----------------------------------------------------

	global connected

	# Establish Socket, waiting for given timout
	#--------------------------------------------
	set id [after $timeout {set connected "TIMED_OUT"}]
	if {[catch {set sock [socket -async $host $port]} msg]} {
		catch {close $sock}
		OT_LogWrite 2 "Connection attempt failed : unable to open socket"
		return [list 0 ERR_DEAD_LINE]
	}

	fileevent $sock w {set connected "OK"}
	after cancel $id
	vwait connected

	# Clear file event
	#-----------------
	fileevent $sock w {}

	# Check for timeout
	#------------------
	if {$connected == "TIMED_OUT"} {
		catch {close $sock}
		OT_LogWrite 2 "Connection attempt timed out after $timeout ms"
		return [list 0 ERR_TIMEOUT]
	}

	# Test the connection
	#--------------------
	fconfigure $sock -blocking 0
	if [catch {gets $sock null_variable}] {
		catch {close $sock}
		OT_LogWrite 2 "Connection attempt failed : unable to read from socket"
		return [list 0 ERR_DEAD_LINE]
	}

	# Setup socket for line buffering
	#--------------------------------
	fconfigure $sock -blocking 1 -buffering line
	return [list 1 $sock]
}
