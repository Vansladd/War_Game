# $Id: status_flag.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Manage customers status flags, very similar to shared_tcl/flags.tcl
#
# Configuration:
#   none
#
# Procedures:
#   ob_status_flag::init  - Initialise
#   ob_status_flag::has   - Find out if a customer has a certain status flag
#   ob_status_flag::get   - Get the value of a column for a status flag
#   ob_status_flag::names - Get a list of flag names.
#


# Dependecies
#
package provide cust_status_flag 4.5

package require util_log
package require util_db
package require cust_login



# Variables
#
namespace eval ob_status_flag {

	# stores the status flag, indexed by tag
	#
	variable FLAGS
	variable INIT 0
	variable last_req_id -1
}



#---------------------------------------------------------------------------
# Initialisation
#---------------------------------------------------------------------------

# Initialise
#
proc ob_status_flag::init args {

	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init
	ob_db::init

	if {[info commands reqGetId] == ""} {
		error "Must support reqGetId"
	}

	_prep_qrys

	set INIT 1
}



# Prepare the queries
#
proc ob_status_flag::_prep_qrys {} {

	# this loads only active status flags,
	# the index is very important for performance
	ob_db::store_qry ob_status_flag::sel {
		select
			sf.status_flag_tag,
			sf.override,
			sf.desc,
			sf.type,
			csf.set_flag_reason as reason,
			csf.status
		from
			tStatusFlag     sf,
			tCustStatusFlag csf,
			tCSFlagIdx      idx
		where
			idx.cust_id         = ?
		and idx.cust_flag_id    = csf.cust_flag_id
		and csf.status_flag_tag = sf.status_flag_tag
	}
}



#---------------------------------------------------------------------------
# Procedures
#---------------------------------------------------------------------------

# Use the reqGetId works out if it necessary to reload the status flags from
# the db or use the ones stored in the variable.
#
proc ob_status_flag::_auto_reset {} {

	variable last_req_id
	variable FLAGS

	# both the requst and customer id must be the same for the date to
	# be valid
	if {$last_req_id == [reqGetId]} {
		return
	}

	array unset FLAGS

	ob_db::foreachrow -colnamesvar cols ob_status_flag::sel [ob_login::get cust_id] {
		upvar #0 ob_status_flag::FLAGS flags

		set flags(colnames) $cols
		foreach n $cols {
			set flags($status_flag_tag,$n) [set $n]
		}
	}

	set last_req_id [reqGetId]
}



# Has the current value of the named flag
#
#   status_flag_tag - status flag tag
#
proc ob_status_flag::has {status_flag_tag} {

	variable FLAGS

	_auto_reset

	return [info exists FLAGS($status_flag_tag,status_flag_tag)]

}



# Gets the current value of the named flag
#
#   status_flag_tag - status flag tag
#   name            - name of the tag value, e.g. overide reason etc.
#
proc ob_status_flag::get {status_flag_tag name} {

	variable FLAGS

	_auto_reset

	if {[has $status_flag_tag]} {
		return $FLAGS($status_flag_tag,$name)
	} else {
		error "Status flag '$status_flag_tag' not found"
	}
}



# Get a list of flag names for the customer.
#
#   returns - list of flag names
#
proc ob_status_flag::names {} {

	variable FLAGS

	return [array names FLAGS]
}
