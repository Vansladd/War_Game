# $Id: flag.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle customer/user flags.
#
# Synopsis:
#     package require cust_flag ?4.5?
#
# Procedures:
#    ob_cflag::init            one time initialisation
#    ob_cflag::get             get a customer flag
#    ob_cflag::get_names       get customer flag names
#    ob_cflag::get_desc        get flag descriptions
#    ob_cflag::set_value       set a customer flag
#    ob_cflag::insert          insert a new customer flag
#    ob_cflag::update          update a customer flag
#    ob_cflag::delete          delete a customer flag
#    ob_cflag::delete_all      delete all customer flags
#

package provide cust_flag 4.5



# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_cflag {

	variable FLAG
	variable DESC
	variable INIT

	set FLAG(req_no) ""
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Prepare queries.
#
proc ob_cflag::init args {

	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CFLAG: init}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "CFLAG: reqGetId not available for auto reset"
	}

	_prepare_qrys
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_cflag::_prepare_qrys args {

	# get customer flags
	ob_db::store_qry ob_cflag::get {
		select
		    flag_name as name,
		    flag_value as value
		from
		    tCustomerFlag
		where
		    cust_id = ?
	}

	# get flag descriptions and default values
	ob_db::store_qry ob_cflag::get_desc {
		select
		    d.flag_name,
		    d.description,
		    d.note,
		    v.flag_value
		from
		    tCustFlagDesc d,
		    outer tCustFlagVal v
		where
		    d.flag_name = v.flag_name
		order by
		    d.flag_name
	}

	# insert customer flag
	ob_db::store_qry ob_cflag::insert {
		insert into
		    tCustomerFlag(cust_id,
		                  flag_name,
		                  flag_value)
		values(?, ?, ?)
	}

	# update a customer flag
	ob_db::store_qry ob_cflag::update {
		update
		    tCustomerFlag
		set
		    flag_value  = ?
		where
		    cust_id     = ?
		and flag_name   = ?
	}

	# delete a customer flag
	ob_db::store_qry ob_cflag::delete {
		delete from
		    tCustomerFlag
		where
		    cust_id     = ?
		and flag_name   = ?
	}

	# delete all customer flags
	ob_db::store_qry ob_cflag::delete_all {
		delete from
		    tCustomerFlag
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
proc ob_cflag::_auto_reset args {

	variable FLAG

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$FLAG(req_no) != $id} {
		catch {unset FLAG}
		set FLAG(req_no) $id
		ob_log::write DEV {CFLAG: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}


#--------------------------------------------------------------------------
# Get Flags
#--------------------------------------------------------------------------


# Get a customer flag.
# If the customer flags have been previously loaded, then retrieve the flag
# from a cache, else take from the database (copies all the customer flags to
# the cache). The flags are always re-loaded on each request.
#
#   name     - flag name
#   cust_id  - customer id
#   returns  - flag value, or an empty string if name/cust_id are not found
#
proc ob_cflag::get { name cust_id } {

	variable FLAG

	# re-load the preferences
	if {[_auto_reset]} {
		_load $cust_id
	}

	# already retrieved the flag?
	if {[info exists FLAG($name,value)]} {
		return $FLAG($name,value)
	}

	return ""
}



# Get customer flag names.
# If the customer flags names have been previously loaded, then retrieve
# the names from a cache, else take from database (copies all the names to the
# cache). The flags are always re-loaded on each request.
#
#   cust_id  - customer id
#   returns  - tcl list of flag names,
#              or an empty list if cust_id is not found
#
proc ob_cflag::get_names { cust_id } {

	variable FLAG

	if {[_auto_reset]} {
		_load $cust_id
	}

	# get flag names
	if {[info exists FLAG(names)]} {
		return $FLAG(names)
	}

	return [list]
}



# Get the flag descriptions and default flag values.
# If the descriptions have been previously loaded, then retrieve the names from
# a cache, else take from database (copies to cache). Once the descriptions
# have been stored in the cache, they cannot be reset/reloaded.
#
#   returns - array of flag descriptions
#	          DESC(names)             {name1 name2 ...}
#	          DESC(name1,value)       {value1 value2 ...}
#	          DESC(name1,description) desc1
#	          DESC(name1,note)        note1
#
proc ob_cflag::get_desc args {

	variable DESC

	# descriptions already loaded?
	if {![info exists DESC]} {
		_load_desc
	}

	return [array get DESC]
}



# Private procedure to load the customer flags from the database and store
# within a cache (FLAG array)
#
#   cust_id  - customer id
#
proc ob_cflag::_load { cust_id } {

	variable FLAG

	set rs    [ob_db::exec_qry ob_cflag::get $cust_id]
	set nrows [db_get_nrows $rs]

	# store all cust' flags
	for {set i 0} {$i < $nrows} {incr i} {
		set name              [db_get_col $rs $i name]
		set FLAG($name,value) [db_get_col $rs $i value]
		lappend FLAG(names)   $name
	}

	ob_db::rs_close $rs
}



# Private procedure to load all the flag descriptions and default values
#
proc ob_cflag::_load_desc args {

	variable DESC

	set rs    [ob_db::exec_qry ob_cflag::get_desc]
	set nrows [db_get_nrows $rs]
	set cols  [db_get_colnames $rs]

	set DESC(names) [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set name [db_get_col $rs $i flag_name]

		if {[lsearch $DESC(names) $name] == -1} {
			lappend DESC(names)         $name
			set DESC($name,value)       [list [db_get_col $rs $i flag_value]]
			set DESC($name,description) [db_get_col $rs $i description]
			set DESC($name,note)        [db_get_col $rs $i note]
		} else {
			lappend DESC($name,value)   [db_get_col $rs $i flag_value]
		}
	}

	ob_db::rs_close $rs
}



#--------------------------------------------------------------------------
# Set Flag
#--------------------------------------------------------------------------


# Set a customer flag.
# The procedure will call either ::insert, ::update or ::delete, depending
# on the positioned named value -
# Insert  - name does not exist
# Update  - name exists but currently has a different value
# Delete  - supplied value is empty
# Nothing - name exists and same value
#
#   name      - flag name
#   value     - flag value
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the set
#
proc ob_cflag::set_value { name value cust_id {in_tran 0} } {

	# blank value, then delete flag
	if {$value == ""} {
		return [delete $name $cust_id $in_tran]
	}

	# is the value same as current
	set current [get $name $cust_id]
	if {$current == $value} {
		return 0
	}

	# insert the flag if it don't exist
	if {$current == ""} {
		return [insert $name $value $cust_id $in_tran]
	}

	# update existing value
	return [update $name $value $cust_id $in_tran]
}



#--------------------------------------------------------------------------
# Insert Flags
#--------------------------------------------------------------------------


# Insert a new customer flag.
# The customer's flag cache is reset.
#
#   name      - flag name
#   value     - flag value
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the insert
#
proc ob_cflag::insert { name value cust_id {in_tran 0} } {

	variable FLAG

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# insert flag
	if {[catch {ob_db::exec_qry ob_cflag::insert $cust_id \
		        $name \
		        $value} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cflag::insert]

	# reset all customer flags to force re-load
	set FLAG(req_no) ""

	return $nrows
}


#--------------------------------------------------------------------------
# Update Flags
#--------------------------------------------------------------------------


# Update a customer flag.
# The customer's flag cache is reset.
#
#   name      - flag name
#   value     - flag value
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the update
#
proc ob_cflag::update { name value cust_id {in_tran 0} } {

	variable FLAG

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# update flag
	if {[catch {ob_db::exec_qry ob_cflag::update \
		        $value \
		        $cust_id \
		        $name} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cflag::update]

	# reset all customer flags to force re-load
	set FLAG(req_no) ""

	return $nrows
}


#--------------------------------------------------------------------------
# Delete Flags
#--------------------------------------------------------------------------


# Delete a customer flag.
# The customer's flag cache is reset.
#
#   name      - flag name
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the delete
#
proc ob_cflag::delete { name cust_id {in_tran 0} } {

	variable FLAG

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# delete flag
	if {[catch {ob_db::exec_qry ob_cflag::delete \
		        $cust_id \
		        $name} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cflag::delete]

	# reset all customer flags to force re-load
	set FLAG(req_no) ""

	return $nrows
}



# Delete all of a requested customer's flag.
# The customer's flag cache is reset.
#
#   cust_id   - customer identifier
#   in_tran   - in transaction flag (default: 0)
#               if non-zero, the caller must begin, rollback & commit
#               if zero, then must be called outside a transaction
#   returns   - number of rows effected by the delete
#
proc ob_cflag::delete_all { cust_id {in_tran 0} } {

	variable FLAG

	if {!$in_tran} {
		ob_db::begin_tran
	}

	# delete flag
	if {[catch {ob_db::exec_qry ob_cflag::delete_all $cust_id} msg]} {
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		error $msg
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}

	# number of effected rows
	set nrows [ob_db::garc ob_cflag::delete_all]

	# reset all customer flags to force re-load
	set FLAG(req_no) ""

	return $nrows
}
