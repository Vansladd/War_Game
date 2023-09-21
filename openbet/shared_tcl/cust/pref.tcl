# $Id: pref.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle customer/user preferences.
#
# Synopsis:
#     package require cust_pref ?4.5?
#
# Procedures:
#    ob_cpref::init            one time initialisation
#    ob_cpref::get             get a customer preference value
#    ob_cpref::get_pos         get a customer preference position
#    ob_cpref::get_type        get a customer preference type
#    ob_cpref::get_names       get customer preference names
#    ob_cpref::set_value       set a customer preference
#    ob_cpref::insert          insert a new customer preference
#    ob_cpref::update          update a customer preference
#    ob_cpref::delete          delete a customer preference
#    ob_cpref::delete_all      delete all customer preferences
#

package provide cust_pref 4.5



# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_cpref {

	variable PREF
	variable INIT

	set PREF(req_no) ""
	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Prepare queries.
#
proc ob_cpref::init args {

	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CPREF: init}

	# can auto reset the preferences?
	if {[info commands reqGetId] != "reqGetId"} {
		error "CPREF: reqGetId not available for auto reset"
	}

	_prepare_qrys
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_cpref::_prepare_qrys args {

	# get all customer prefs
	ob_db::store_qry ob_cpref::get {
		select
		    pref_name as name,
		    NVL(pref_cvalue, pref_ivalue) as value,
		    case
		        when pref_cvalue is not null then 'C'
		        else 'I'
		    end type,
		    pref_pos as pos
		from
		    tCustomerPref
		where
		    cust_id = ?
		order by
		    name,
		    pos
	}

	# insert a customer pref
	ob_db::store_qry ob_cpref::insert {
		insert into
		    tCustomerPref(cust_id,
		                  pref_name,
		                  pref_ivalue,
		                  pref_cvalue,
		                  pref_pos)
		values(?, ?, ?, ?, ?)
	}

	# update a customer pref
	ob_db::store_qry ob_cpref::update {
		update
		    tCustomerPref
		set
		    pref_ivalue = ?,
		    pref_cvalue = ?
		where
		    cust_id     = ?
		and pref_name   = ?
		and pref_pos    = ?
	}

	# delete a customer pref
	ob_db::store_qry ob_cpref::delete {
		delete from
		    tCustomerPref
		where
		    cust_id     = ?
		and pref_name   = ?
		and pref_pos    = ?
	}

	# delete all customer prefs
	ob_db::store_qry ob_cpref::delete_all {
		delete from
		    tCustomerPref
		where
		    cust_id = ?
	}
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_cpref::_auto_reset args {

	variable PREF

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$PREF(req_no) != $id} {
		catch {unset PREF}
		set PREF(req_no) $id
		ob_log::write DEV {CPREF: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}



#--------------------------------------------------------------------------
# Get Preferences
#--------------------------------------------------------------------------


# Get a customer preference value.
# If the customer preferences have been previously loaded, then retrieve
# the preference from a cache, else take from database (copies all the customer
# preferences to the cache). The preferences are always re-loaded on each
# request.
# A customer preference can have 1..n sets of values, ordered by preference
# position.
#
#   name     - preference name
#   cust_id  - customer id
#   def      - default value if name/cust_id are not found (default: "")
#   returns  - tcl list of values,
#              or an empty list if name/cust_id not found and def not supplied
#
proc ob_cpref::get { name cust_id {def ""} } {

	variable PREF

	# what to return if name/cust_id not found
	if {$def != ""} {
		set r [list $def]
	} else {
		set r [list]
	}

	# if cust_id is not supplied, do not reset the cache and attempt to reload
	if {$cust_id == ""} {
		return $r
	}

	# re-load the preferences
	if {[_auto_reset]} {
		_load $cust_id
	}

	# get pref value[s]
	if {[info exists PREF($name,value)]} {
		return $PREF($name,value)
	}

	return $r
}



# Get a customer preference position.
# If the customer preferences positions have been previously loaded, then
# retrieve the positions from a cache, else take from database (copies all
# the positions to the cache).  The preferences are always re-loaded on each
# request.
# Each position corresponds to a value returned by ::get
#
#   name     - preference name
#   cust_id  - customer id
#   returns  - tcl list of preference positions,
#              or an empty list if name/cust_id are not found
#
proc ob_cpref::get_pos { name cust_id } {

	variable PREF

	# if cust_id is not supplied, do not reset the cache and attempt to reload
	if {$cust_id == ""} {
		return [list]
	}

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get pref position[s]
	if {[info exists PREF($name,pos)]} {
		return $PREF($name,pos)
	}

	return [list]
}



# Get a customer preference type.
# If the customer preferences types have been previously loaded, then
# retrieve the type from a cache, else take from database (copies all
# the types to the cache).  The preferences are always re-loaded on each
# request.
# Each type corresponds to a value returned by ::get
#
#   name     - preference name
#   cust_id  - customer id
#   returns  - tcl list of types ('C'haracter, 'I'nteger)
#              or an empty list if name/cust_id are not found
#
proc ob_cpref::get_type { name cust_id } {

	variable PREF

	# if cust_id is not supplied, do not reset the cache and attempt to reload
	if {$cust_id == ""} {
		return [list]
	}

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get pref position[s]
	if {[info exists PREF($name,type)]} {
		return $PREF($name,type)
	}

	return [list]
}




# Get all the customers preference names.
# If the customer preferences names have been previously loaded, then retrieve
# the names from a cache, else take from database (copies all the names to the
# cache). The preferences are always re-loaded on each request.
#
#   cust_id  - customer id
#   returns  - tcl list of preference names,
#              or an empty list if cust_id is not found
#
proc ob_cpref::get_names { cust_id } {

	variable PREF

	# if cust_id is not supplied, do not reset the cache and attempt to reload
	if {$cust_id == ""} {
		return [list]
	}

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get pref names
	if {[info exists PREF(names)]} {
		return $PREF(names)
	}

	return [list]
}



# Private procedure to load the customer preferences from the database and
# store within a cache (PREF array)
#
#   cust_id  - customer id
#
proc ob_cpref::_load { cust_id } {

	variable PREF

	# denote package reset if query fails
	if {[catch {set rs [ob_db::exec_qry ob_cpref::get $cust_id]} msg]} {
		set PREF(req_no) ""
		error $msg
	}
	set nrows [db_get_nrows $rs]

	# store all the cust' prefs
	set PREF(names) [list]
	for {set i 0} {$i < $nrows} {incr i} {
		set name [db_get_col $rs $i name]
		if {[lsearch $PREF(names) $name] == -1} {
			lappend PREF(names) $name
		}
		lappend PREF($name,type)  [db_get_col $rs $i type]
		lappend PREF($name,value) [db_get_col $rs $i value]
		lappend PREF($name,pos)   [db_get_col $rs $i pos]
	}

	ob_db::rs_close $rs
}


#--------------------------------------------------------------------------
# Set Preferences
#--------------------------------------------------------------------------


# Set a customer preference value.
# The procedure will call either ::insert, ::update or ::delete, depending
# on the positioned named value -
# Insert  - named positioned value does not exist
# Update  - named positioned value exists but currently has a different value
# Delete  - supplied value is empty
# Nothing - named position value exists but it's the same as current value
#
#   name      - preference name
#   value     - preference value
#   cust_id   - customer identifier
#   type      - preference value type - 'C'haracter, 'I'nteger (default: C)
#   pos       - preference position (default: 0)
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the set
#
proc ob_cpref::set_value { name value cust_id {type C} {pos 0} {in_tran 0} } {

	variable PREF

	# is cust_id supplied
	if {$cust_id == ""} {
		return 0
	}

	# blank value, delete the preference
	if {$value == ""} {
		return [delete $name $cust_id $pos $in_tran]
	}

	# is the positioned value same as current positioned value?
	set current [get $name $cust_id]
	set i [lsearch $current $value]
	if {$i != -1 && [lindex $PREF($name,pos) $i] == $pos} {
		return 0
	}

	# add the positioned value if not already present
	if {![info exists PREF($name,value)] || \
		        ($i == -1 && [lsearch $PREF($name,pos) $pos] == -1) || \
		        ($i != -1 && [lindex $PREF($name,pos) $i] != $pos)} {
		return [insert $name $value $cust_id $type $pos $in_tran]
	}

	# update the positioned value
	return [update $name $value $cust_id $type $pos $in_tran]
}



#--------------------------------------------------------------------------
# Insert Preferences
#--------------------------------------------------------------------------


# Insert a new customer preference.
# The customer's preference cache is reset.
#
#   name      - preference name
#   value     - preference value
#   cust_id   - customer identifier
#   type      - preference value type -  'C'haracter, 'I'nteger (default: C)
#   pos       - preference position (default: 0)
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the insert
#
proc ob_cpref::insert { name value cust_id {type C} {pos 0} {in_tran 0} } {

	variable PREF

	# is cust_id supplied
	if {$cust_id == ""} {
		return 0
	}

	# set value, either character or integer
	switch -- $type {
		C {
			set ivalue ""
			set cvalue $value
		}
		I {
			set ivalue $value
			set cvalue ""
		}
		default {
			error "Unknown value type ($type)"
		}
	}

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# insert preference
	if {[catch {ob_db::exec_qry ob_cpref::insert $cust_id \
		        $name \
		        $ivalue \
		        $cvalue \
		        $pos} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cpref::insert]

	# reset all customer prefs to force re-load
	set PREF(req_no) ""

	return $nrows
}


#--------------------------------------------------------------------------
# Update Preferences
#--------------------------------------------------------------------------


# Update a customer preference.
# The customer's preference cache is reset.
#
#   name      - preference name
#   value     - preference value
#   cust_id   - customer identifier
#   type      - preference value type -  'C'haracter, 'I'nteger (default: C)
#   pos       - preference position (default: 0)
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the update
#
proc ob_cpref::update { name value cust_id {type C} {pos 0} {in_tran 0} } {

	variable PREF

	# is cust_id supplied
	if {$cust_id == ""} {
		return 0
	}

	# set value, either character or integer
	switch -- $type {
		C {
			set ivalue ""
			set cvalue $value
		}
		I {
			set ivalue $value
			set cvalue ""
		}
		default {
			error "Unknown value type ($type)"
		}
	}

	ob_log::write DEV {CPREF: type=$type ivalue=$ivalue cvalue=$cvalue}

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# update preference
	if {[catch {ob_db::exec_qry ob_cpref::update \
		        $ivalue \
		        $cvalue \
		        $cust_id \
		        $name \
		        $pos} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cpref::update]

	# reset all customer prefs to force re-load
	set PREF(req_no) ""

	return $nrows
}


#--------------------------------------------------------------------------
# Delete Preferences
#--------------------------------------------------------------------------


# Delete a customer preference.
# The customer's preference cache is reset.
#
#   name      - preference name
#   cust_id   - customer identifier
#   pos       - preference position (default: 0)
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the delete
#
proc ob_cpref::delete { name cust_id {pos 0} {in_tran 0} } {

	variable PREF

	# is cust_id supplied
	if {$cust_id == ""} {
		return 0
	}

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# delete preference
	if {[catch {ob_db::exec_qry ob_cpref::delete \
		        $cust_id \
		        $name \
		        $pos} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cpref::delete]

	# reset all customer prefs to force re-load
	set PREF(req_no) ""

	return $nrows
}



# Delete all of a requested customer's preferences.
# The customer's preference cache is reset.
#
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the delete
#
proc ob_cpref::delete_all { cust_id {in_tran 0} } {

	variable PREF

	# is cust_id supplied
	if {$cust_id == ""} {
		return 0
	}

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# delete preferences
	if {[catch {ob_db::exec_qry ob_cpref::delete_all $cust_id} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cpref::delete_all]

	# reset all customer prefs to force re-load
	set PREF(req_no) ""

	return $nrows
}
