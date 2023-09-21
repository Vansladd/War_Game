# $Id: control.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle control table (tControl)
#
# Configuration:
#
# Synopsis:
#     package require util_control ?4.5?
#
# Procedures:
#    ob_control::init    one time initialisation
#    ob_control::get     get a control data value
#

package provide util_control 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_control {

	variable INIT
	variable CONTROL

	set INIT 0
	set CONTROL(req_no) ""
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_control::init args {

	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CONTROL: init}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "CONTROL: reqGetId not available for auto reset"
	}

	_prepare_qrys
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_control::_prepare_qrys args {

	# get control info (cached)
	ob_db::store_qry ob_control::get {
		select
		    *
		from
		    tControl
	} 600

	# get channel specific control info 
	ob_db::store_qry ob_channel_control::get {
		select
		    *
		from
		    tControlChannel
	} 600

	# get group specific control info 
	ob_db::store_qry ob_group_control::get {
		select
		    *
		from
		    tControlCustGrp
	} 600
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_control::_auto_reset args {

	variable CONTROL

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$CONTROL(req_no) != $id} {
		catch {unset CONTROL}
		set CONTROL(req_no) $id
		ob_log::write DEV {CONTROL: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}


#--------------------------------------------------------------------------
# Get Control
#--------------------------------------------------------------------------


# Get a control data value.
# If the control data have been previously loaded, then retrieve the value
# from a cache, else take from the database (copies all the data to the cache).
# The data is always re-loaded on each request.
#
#   col            - control column name
#   returns        - control column name data value,
#                    or an empty string if col is not found
#   channel        - channel of the customer who placed bet, to
#                    override channel specific controls
#   in_running     - status of the event when bet is placed
#   cust_code      - customer's group to overrive group specific controls
#
proc ob_control::get { col {channel ""} {in_running ""} {cust_code ""} } {

	variable CONTROL

	# re-load the control data?
	if {[_auto_reset]} {
		_load
	}
	
	# If we are not using fine grained controls, or have been passed no
	# channel or group value id, then use standard values
	if {![OT_CfgGet FUNC_ASYNC_FINE_GRAINED 0] || 
				($channel == "" && $cust_code == "")} {

		if {[info exists CONTROL($col)]} {
			return $CONTROL($col)
		} else {
			return ""	
		}

	} else {
		# At this point we have a channel or group override
		if {$cust_code != ""} {
			set prefix group_$cust_code
		} else {
			set prefix chan_$channel
		}
		
		# Check if col is async_off_timeout to switch on IR or pre-match
		if {$col == "async_off_timeout"} {
			if {$in_running == "Y" || $in_running == 1} {
				set col async_off_ir_timeout
			} else {
				set col async_off_pre_timeout
			}
		}
		
		if {[info exists CONTROL($prefix,$col)]} {
			return $CONTROL($prefix,$col)
		} else {
			return ""
		}
	}
}



# Private procedure to load the control data from the database and store
# within the package cache. The database result-set is cached.
#
proc ob_control::_load args {

	variable CONTROL

	# Global settings from tControl
	set rs   [ob_db::exec_qry ob_control::get]
	set cols [db_get_colnames $rs]

	if {[db_get_nrows $rs] == 1} {
		foreach c $cols {
			set CONTROL($c) [db_get_col $rs 0 $c]
		}
	}
	ob_db::rs_close $rs
	
	# If we're not using fine grained controls then don't bother
	# loading the overrides
	if {[OT_CfgGet FUNC_ASYNC_FINE_GRAINED 0]} {
		# Overrides from tControlChannel
		set rs   [ob_db::exec_qry  ob_channel_control::get]
		set cols [db_get_colnames $rs]
		
		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			set chan [db_get_col $rs $r channel_id]
		
			foreach c $cols {
				set CONTROL(chan_$chan,$c) [db_get_col $rs $r $c]
			}
		}
		ob_db::rs_close $rs
		
		# Overrides from tControlCustGrp
		set rs   [ob_db::exec_qry ob_group_control::get]
		set cols [db_get_colnames $rs]
		
		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			set group [db_get_col $rs $r cust_code]
		
			foreach c $cols {
				set CONTROL(group_$group,$c) [db_get_col $rs $r $c]
			}
		}
		ob_db::rs_close $rs
	}
}
