# ==============================================================
# $Id: cust_status_flags.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

namespace eval OB::STATUS_FLAGS {

	variable STATUS_FLAG
	set STATUS_FLAG(req_no) ""

	variable INITIALIZED 0
}

##
## prepare the queries
##
proc OB::STATUS_FLAGS::_prep_queries {} {
	global SHARED_SQL

	db_store_qry get_cust_status_flags {
		select
			idx.cust_flag_id,
			sf.status_flag_tag,
			sf.override,
			sf.desc,
			sf.type,
			csf.set_flag_reason as reason
		from
			tCustStatusFlag csf,
			tStatusFlag sf,
			tCSFlagIdx idx
		where  idx.cust_id         = ?
		and    idx.cust_flag_id    = csf.cust_flag_id
		and    idx.cust_id         = csf.cust_id
		and    csf.status_flag_tag = sf.status_flag_tag
	}

	db_store_qry get_cust_status {
		select
			status
		from
			tCustomer
		where
			cust_id = ?
	}
}


## using the reqId works out if it necessary to reload the status flags from the db or use the ones stored in the variable
proc OB::STATUS_FLAGS::_auto_reset args {

	variable STATUS_FLAG

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$STATUS_FLAG(req_no) != $id} {
		catch {unset STATUS_FLAG}
		set STATUS_FLAG(req_no) $id
		ob::log::write DEV {STATUS_FLAG: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}


##
## loads the status flags in to the variable.
## to be used with _auto_reset to allow us to cache the flags for the duration of the request
##
proc OB::STATUS_FLAGS::_load {cust_id} {

	variable STATUS_FLAG
	variable INITIALIZED

	if {!$INITIALIZED} {
		_prep_queries
		set INITIALIZED 1
	}

	set rs  [db_exec_qry get_cust_status_flags $cust_id]
	set nrows [db_get_nrows $rs]

	# store all cust status flags flags
	for {set i 0} {$i < $nrows} {incr i} {

		set status_flag_tag [db_get_col $rs $i status_flag_tag]
		set override [db_get_col $rs $i override]
		set desc [db_get_col $rs $i desc]
		set type [db_get_col $rs $i type]
		set cust_flag_id [db_get_col $rs $i cust_flag_id]
		set reason [db_get_col $rs $i reason]

		set STATUS_FLAG($status_flag_tag,cust_flag_id) $cust_flag_id
		set STATUS_FLAG($status_flag_tag,override) $override
		set STATUS_FLAG($status_flag_tag,type) $type
		set STATUS_FLAG($status_flag_tag,desc) $desc
		set STATUS_FLAG($status_flag_tag,reason) $reason

		lappend STATUS_FLAG(names) $status_flag_tag

	}

	db_close $rs

	# store the customers status also
	set rs  [db_exec_qry get_cust_status $cust_id]

	if {[db_get_nrows $rs] == 1} {
		set STATUS_FLAG(status) [db_get_col $rs 0 status]
	}

	db_close $rs
}

proc OB::STATUS_FLAGS::set_all_status_flag_array {cust_id} {

	variable STATUS_FLAG

	# re-load the preferences
	if {[_auto_reset]} {
		_load $cust_id
	}

	return [array get STATUS_FLAG]
}

## pulls top level customer status (Active Suspended Locked) from the variable
## uses _auto_reset to alow us to cache the flags for the duration of the request
proc OB::STATUS_FLAGS::get_status {cust_id} {

	variable STATUS_FLAG

	# re-load the preferences
	if {[_auto_reset]} {
		_load $cust_id
	}

	if {[info exists STATUS_FLAG(status)]} {
		return $STATUS_FLAG(status)
	}

	return ""
}



## retrieves overides for a paticualt flag on the customer account from the variable
## uses _auto_reset to alow us to cache the flags for the duration of the request
proc OB::STATUS_FLAGS::get_override {name cust_id} {

	variable STATUS_FLAG

	# re-load the preferences
	if {[_auto_reset]} {
		_load $cust_id
	}

	if {[info exists STATUS_FLAG($name,override)]} {
		return $STATUS_FLAG($name,override)
	}

	return ""
}



## retrieves the names of all of the status flags on this account
## uses _auto_reset to alow us to cache the flags for the duration of the request
proc OB::STATUS_FLAGS::get_names {cust_id} {

	variable STATUS_FLAG

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get flag names
	if {[info exists STATUS_FLAG(names)]} {
		return $STATUS_FLAG(names)
	}

	return [list]
}



## retrieves cust_flag_id for a particular cust flag tag
## uses _auto_reset to alow us to cache the flags for the duration of the request
proc OB::STATUS_FLAGS::get_name_id {cust_id name} {

	variable STATUS_FLAG

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get cust_flag_id
	if {[info exists STATUS_FLAG($name,cust_flag_id)]} {
		return $STATUS_FLAG($name,cust_flag_id)
	}

	return 0
}




