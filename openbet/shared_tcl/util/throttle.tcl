#
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/util/throttle.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

# Certain actions should not be executed if a proportion of appserver children
# are already performing the action. This is to prevent the entire application
# locking up making third party requests.
#
# Each action has a threshold which is either the total number of children or
# a percentage of all the children that are allowed to make the action. If this
# is exceeded the reserve funtion returns a 0, it is up the the calling
# procedure to display an appropriate error message, or to proceed.
#
package provide util_throttle 4.5

package require util_log 4.5


namespace eval ob_throttle {
	variable THROTTLE
	variable INIT

	set INIT 0
	set THROTTLE(enabled)   0
}


#
# Initialise the module
#
proc ob_throttle::init {} {

	variable THROTTLE
	variable INIT

	if {$INIT} {return}

	# Determine if we are enabled and functional
	set THROTTLE(enabled)   0
	if {[OT_CfgGet THROTTLE_ENABLED 0] && [expr {[info commands asFindRs] == "asFindRs" ? 1 :0}]} {
		set THROTTLE(enabled)   1
	}


	# Build up our throttling arrays calculating the maximum children allowed
	# per action. These are specified in the config and can be a percentage or
	# an absolute value for the number of children
	if {$THROTTLE(enabled)} {

		# Read in configs here to ensure consistent defaults
		set THROTTLE(cache_time)  [OT_CfgGet THROTTLE_CACHE_TIME 1000000]
		set THROTTLE(child_count) [OT_CfgGet PROCS_PER_PORT 0]

		# Set default max number of children.  If PROCS_PER_USER does not exist,
		# set to 50% of the total number of children
		if {![info exists THROTTLE(default,max_children)]} {
			set THROTTLE(default,max_children) [OT_CfgGet PROCS_PER_USER [expr {int($THROTTLE(child_count) / 2)}]]
		}

		# if we are initialising we assume that the child can free its lock
		ob_throttle::release
	}
	set INIT 1
}


#
# Try and get a lock for the child
#
proc ob_throttle::reserve {action} {

	variable THROTTLE

	# Check that shared memory is enabled
	if {!$THROTTLE(enabled)} { return 1 }


	# Calculate max child count for this action
	if {![info exists THROTTLE($action,max_children)]} {
		set THROTTLE($action,max_children) $THROTTLE(default,max_children)
	}


	# Retrieve a count of the number of children performing this action
	set action_count 0
	for {set child_idx 0} {$child_idx < $THROTTLE(child_count)} {incr child_idx} {
		if {[lsearch [_get_child_actions $child_idx] $action] >= 0} {
			incr action_count
		}
	}
	OT_LogWrite 1 "Number of child processes: $action_count"

	# Update shared memory including the new action, even if this fails
	# we should not block as this could kill a whole app
	if {[lindex [_add_child_action $action] 0] != {OK}} {
		ob_log::write CRITICAL {THROTTLE: CRITICAL ERROR: throttle failed to update shared memory, protection will not work}
	}
	asSetStatus "PROTECTED $action"


	# Check we have not overloaded the appserver for this action
	if {$action_count >= $THROTTLE($action,max_children)} {
		ob_log::write CRITICAL {TROTTLE: CRITICAL ERROR: throttle threshold exceeded  $action_count of $THROTTLE(child_count) ( Threshold $THROTTLE($action,max_children) )}

		return 0
	}

	return 1
}



#
# Release the child from a protected action
#
# if no action is passed the entire stack will be cleared
#
proc ob_throttle::release {{action "default"}} {

	variable THROTTLE

	# Check that shared memory is enabled
	if {!$THROTTLE(enabled)} { return 1 }


	# Unset the child action information
	if {[lindex [_clear_child_action $action] 0] != {OK}} {
		ob_log::write CRITICAL {THROTTLE: CRITICAL ERROR: throttle unset failed, we could start leaking children}
		return 0
	}

	return 1
}



#------------------------------- Private functions


#
# Retrieve child action stack from shared memory
#
proc ob_throttle::_get_child_actions {child} {

	variable THROTTLE

	# Get the action list
	if {[catch {set action_stack [asFindString THROTTLE($child,actions)]} err]} {
		ob_log::write DEBUG {THROTTLE: action stack not found for child $child}
		return [list]
	}
	return $action_stack
}



#
# Remove the last instance of an action from the child stack
#
proc ob_throttle::_clear_child_action {{clear_action "default"}} {

	variable THROTTLE

	set my_child_id [asGetId]

	# If no action supplied we clear the entire list
	if {$clear_action == "default"} {
		if {[catch { asStoreString [list] THROTTLE([asGetId],actions) $THROTTLE(cache_time) } err]} {
			ob_log::write ERROR {THROTTLE: ERROR: throttle failed to clear child actions: $err}
		}

		# Clear the appserver status
		asSetStatus {}
		return [list OK]
	}

	# Get the current action stack
	if {[catch { set action_list [asFindString THROTTLE($my_child_id,actions)] } err]} {
		return [list OK]
	}

	# Delete all instances of the action (should really only be one)
	set new_action_list [list]
	foreach action $action_list {
		if {$clear_action != $action} {
			lappend new_action_list $action
		}
	}

	# Update shared memory with the new action stack
	if {[catch {
		asStoreString $new_action_list   THROTTLE($my_child_id,actions) $THROTTLE(cache_time)
		asSetStatus [lindex $new_action_list 0]
	} err]} {
		ob_log::write INFO {ob_throttle:: error settting child action : $err}
		return [list shm.error $err]
	}
	return [list OK]
}



#
# Set the child action in shared memory
#
proc ob_throttle::_add_child_action {new_action} {

	variable THROTTLE

	set my_child_id [asGetId]
	set my_req_id   [reqGetId]


	# Get the current action list
	if {[catch { set action_list [asFindString THROTTLE($my_child_id,actions)] } err]} {
		set action_list [list]
	}


	# Check that we have not leaked any actions from previous requests
	if {[OT_CfgGetTrue THROTTLE_LEAK_TEST]} {
		foreach action $action_list {

			if {[catch { set action_req [asFindString THROTTLE($my_child_id,$action)] } err]} {
				ob_log::write ERROR {THROTTLE: ERROR - throttle request id not set for action $action}
				continue
			}

			if {$action_req != $my_req_id} {
				ob_log:write ERROR {******************* WARNING **************************}
				ob_log:write ERROR {throttle action $lastAction has leaked from request $lastReqId}
				ob_log:write ERROR {call throttle::release in req_end}
				ob_log:write ERROR {******************************************************}
			} else {
				lappend real_action_list [list $action]
				catch {asStoreString $my_req_id  THROTTLE($my_child_id,$action) $THROTTLE(cache_time)}
			}
		}
		set action_list
	} else {
		set real_action_list $action_list
	}

	# Flag up the new request
	set real_action_list [concat [list $new_action] $real_action_list]


	# Store the action list against the child
	if {[catch {
		ob_log::write DEBUG {ob_throttle:: setting child action list: < $real_action_list >}
		asStoreString $real_action_list   THROTTLE($my_child_id,actions) $THROTTLE(cache_time)
		asStoreString $my_req_id          THROTTLE($my_child_id,$new_action) $THROTTLE(cache_time)
		asSetStatus   [lindex $real_action_list 0]
	} err]} {
		ob_log::write INFO {ob_throttle:: error setting child action : $err}
		return [list shm.error $err]
	}

	return [list OK]
}
