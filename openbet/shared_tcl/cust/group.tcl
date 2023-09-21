# $Id: group.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Customer Group Management
#
# Configuration: none
#
# Synopsis:
#    package require cust_group ?4.5?
#
# Procedures:
#   ob_cgroup::init           - one time initialisation
#   ob_cgroup::get            - get a list of group values for a customer
#   ob_cgroup::insert         - insert a group value and text for a customer
#   ob_cgroup::update         - update a group value and text for a customer
#   ob_cgroup::delete         - delete a group value for a cust customer
#   ob_cgroup::get_custs      - get all customer ids in a group
#   ob_cgroup::get_types      - get all group types
#   ob_cgroup::get_type_desc  - get description of a specific group type
#   ob_cgroup::insert_type    - insert a new group type
#   ob_cgroup::update_type    - update a group type
#   ob_cgroup::get_descs      - get all descriptions
#   ob_cgroup::get_desc       - get info for a specific description
#   ob_cgroup::insert_desc    - insert a new description
#   ob_cgroup::update_desc    - update a description
#   ob_cgroup::get_values     - get values for a group name
#   ob_cgroup::get_value      - get info about a specific group value
#   ob_cgroup::insert_value   - insert a new group value
#   ob_cgroup::update_value   - update a group value
#

package provide cust_group 4.5



# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_cgroup {

	variable INIT
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc ob_cgroup::init args {

	variable INIT 0

	if {$INIT} {
		return
	}

	ob_log::write DEBUG {ob_cgroup:init}

	_prepare_qrys
	set INIT 1
}



# prepare database queries (called from init)
#
proc ob_cgroup::_prepare_qrys {} {

	# get group values for a customer
	ob_db::store_qry ob_cgroup::get {
		select
			gv.group_value
		from
			tCustGroup         c,
			tGroupValue        gv
		where
			c.group_value_id   = gv.group_value_id
		and c.cust_id          = ?
		and gv.group_name      = ?
	}

	# insert group value for a customer
	ob_db::store_qry ob_cgroup::insert {
		execute procedure pInsCustGroup(
			p_cust_id          = ?,
			p_group_value_id   = ?,
			p_group_value_txt  = ?,
			p_group_name       = ?
		)
	}

	# delete a customer group value
	ob_db::store_qry ob_cgroup::delete {
		execute procedure pDelCustGroup(
			p_cust_id          = ?,
			p_group_value_id   = ?,
			p_group_name       = ?
		)
	}

	# update a customer group value
	ob_db::store_qry ob_cgroup::update {
		execute procedure pUpdCustGroup(
			p_cust_id          = ?,
			p_group_value_id   = ?,
			p_group_value_txt  = ?
		)
	}

	# select all customers in a group
	ob_db::store_qry ob_cgroup::get_custs {
		select
			cust_id
		from
			tCustGroup
		where
			group_value_id = ?
	}

	# get all group types
	ob_db::store_qry ob_cgroup::get_types {
		select
			group_type,
			type_desc
		from
			tGroupType
		order by
			1
	}

	# get desc for a group type
	ob_db::store_qry ob_cgroup::get_type_desc {
		select
			group_type,
			type_desc
		from
			tGroupType
		where
			group_type = ?
	}

	# insert a new group type
	ob_db::store_qry ob_cgroup::insert_type {
		execute procedure pInsGroupType (
			p_group_type = ?,
			p_type_desc  = ?
		)
	}

	# update a group type
	ob_db::store_qry ob_cgroup::update_type {
		execute procedure pUpdGroupType (
			p_group_type = ?,
			p_type_desc  = ?
		)
	}

	# get all group descriptions
	ob_db::store_qry ob_cgroup::get_descs {
		select
			group_name,
			group_desc,
			multi_value,
			dflt_grp_val_id
		from
			tGroupDesc
		where
			group_type = ?
		order by
			1
	}

	# get description for a group
	ob_db::store_qry ob_cgroup::get_desc {
		select
			group_type,
			group_name,
			group_desc,
			multi_value,
			dflt_grp_val_id
		from
			tGroupDesc
		where
			group_name = ?
	}

	# insert a new group description
	ob_db::store_qry ob_cgroup::insert_desc {
		execute procedure pInsGroupDesc (
			p_group_name      = ?,
			p_group_desc      = ?,
			p_group_type      = ?,
			p_multi_value     = ?,
			p_dflt_grp_val_id = ?
		)
	}

	# update an existing group description
	ob_db::store_qry ob_cgroup::update_desc {
		execute procedure pUpdGroupDesc (
			p_group_name      = ?,
			p_group_desc      = ?,
			p_group_type      = ?,
			p_multi_value     = ?,
			p_dflt_grp_val_id = ?
		)
	}

	# get all group values
	ob_db::store_qry ob_cgroup::get_values {
		select
			group_value_id,
			group_value,
			value_desc
		from
			tGroupValue
		where
			group_name = ?
		order by
			2
	}

	# get info about a specific group value
	ob_db::store_qry ob_cgroup::get_value {
		select
			group_value_id,
			group_name,
			group_value,
			value_desc
		from
			tGroupValue
		where
			group_value_id = ?
	}

	# insert a new group value
	ob_db::store_qry ob_cgroup::insert_value {
		execute procedure pInsGroupValue (
			p_group_name  = ?,
			p_group_value = ?,
			p_value_desc  = ?
		)
	}

	# update a group value
	ob_db::store_qry ob_cgroup::update_value {
		execute procedure pUpdGroupValue (
			p_group_value_id = ?,
			p_group_name     = ?,
			p_group_value    = ?,
			p_value_desc     = ?
		)
	}
}



#--------------------------------------------------------------------------
# Customer Group Procedures
#--------------------------------------------------------------------------

# Get a list of group values for specified customer and group
#
#   cust_id     - identifier for customer
#   group_name  - name of group
#   returns     - a list of group values
#
proc ob_cgroup::get { cust_id group_name } {

	ob_log::write DEBUG {ob_cgroup:get cust_id=$cust_id group_name=$group_name}

	# execute query
	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get $cust_id $group_name]
	} msg]} {
		ob_log::write ERROR {execing qry ob_cgroup::get  $msg}
		error $msg
	}

	# build up list to return
	set nrows   [db_get_nrows $rs]
	set group_vals [list]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend group_vals [db_get_col $rs $i group_value]
	}
	ob_db::rs_close $rs

	return $group_vals
}



# Sets the group value and text for the specified customer.
# If group value id is specified then it is used else the default group value
# for the specified group name is used
#
#   cust_id          - identifier for customer
#   group_value_id   - identifier of the group value
#   group_value_txt  - extra details regarding link
#   group_name       - name of group
#
proc ob_cgroup::insert {
	cust_id {group_value_id {}} {group_value_txt {}} {group_name {}}
} {

	ob_log::write DEBUG {ob_cgroup:insert cust_id=$cust_id\
		group_value_id=$group_value_id group_value_txt=$group_value_txt\
		group_name=$group_name}

	# execute query
	if {[catch {
		ob_db::exec_qry ob_cgroup::insert\
			$cust_id $group_value_id $group_value_txt $group_name
	} msg]} {
		ob_log::write ERROR {execing qry ob_cgroup::insert $msg}
		error $msg
	}
}



# Updates the group value text for the specified customer and group value;
# using -1 as the text will not change it, using "" will nullify it
#
#   cust_id         - identifier for customer
#   group_value_id  - identifier of the group value
#   group_value_txt -
#
proc ob_cgroup::update {
	cust_id group_value_id {group_value_txt -1}
} {

	ob_log::write DEBUG {ob_cgroup:update cust_id=$cust_id\
		group_value_id=$group_value_id group_value_txt=$group_value_txt}

	# execute query
	if {[catch {
		ob_db::exec_qry ob_cgroup::update\
			$cust_id $group_value_id $group_value_txt
	} msg]} {
		ob_log::write ERROR {execing qry ob_cgroup::update $msg}
		error $msg
	}
}



# Deletes the group value for the specified customer;
# if group value id is specified then it is used else all associations
# between the customer and group values of the specified group name are deleted
#
#   cust_id         - identifier for customer
#   group_value_id  - identifier of the group value
#   group_name      - name of the group
#
proc ob_cgroup::delete { cust_id {group_value_id {}} {group_name {}} } {

	ob_log::write DEBUG {ob_cgroup:delete cust_id=$cust_id\
		group_value_id=$group_value_id group_name=$group_name}

	# execute query
	if {[catch {
		ob_db::exec_qry ob_cgroup::delete\
			$cust_id $group_value_id $group_name
	} msg]} {
		ob_log::write ERROR {execing qry ob_cgroup::delete $msg}
		error $msg
	}
}



# Get a list of customer ids in a group
#
#   group_value_id - the id of the group value for which to search
#
proc ob_cgroup::get_custs { group_value_id } {

	ob_log::write DEBUG {ob_cgroup:get_custs group_value_id=$group_value_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get_custs $group_value_id]
	} msg]} {
		ob_log::write ERROR {execing qry ob_cgroup::get_custs $msg}
		error $msg
	}

	set result [list ]
	set $nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend [db_get_col $rs 0 cust_id]
	}
	ob_db::rs_close $rs

	return $result
}


#--------------------------------------------------------------------------
# Group Type Procedures
#--------------------------------------------------------------------------

# Get all group types
#
#   returns - an array as a list
#
proc ob_cgroup::get_types {} {

	array set TYPES [array unset TYPES]

	ob_log::write DEBUG {ob_cgroup:get_types}

	set rs [ob_db::exec_qry ob_cgroup::get_types]

	set TYPES(nrows)     [db_get_nrows $rs]
	set TYPES(colnames)  [db_get_colnames $rs]

	# populate the array with the rows from the result set
	for {set i 0} {$i < $TYPES(nrows)} {incr i} {
		foreach col $TYPES(colnames) {
			set TYPES($i,$col) [db_get_col $rs $i $col]
		}
	}
	ob_db::rs_close $rs

	return [array get TYPES]
}



# Get the type description for a group type
#
#   group_type  - the type of the group to get
#   returns     - the type description (type_desc)
#
proc ob_cgroup::get_type_desc { group_type } {

	ob_log::write DEBUG {ob_cgroup:get_type_desc group_type=$group_type}

	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get_type_desc $group_type]
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:get_type_desc failed: $msg}
		error $msg
	}

	set nrows [db_get_nrows $rs]

	# if the nrows is not 1, then something bad happened
	if {$nrows == 0} {
		error {ob_cgroup:get_type_desc returned 0 rows}
	}
	if {$nrows > 1} {
		error "ob_cgroup:get_type_desc returned $nrows rows"
	}

	set result [db_get_col $rs 0 type_desc]
	ob_db::rs_close $rs

	return $result
}



# Insert a group type
#
#   group_type  - the group type
#   type_desc   - the description
#
proc ob_cgroup::insert_type { group_type type_desc } {

	ob_log::write DEBUG {ob_cgroup:insert_type\
		group_type=$group_type type_desc=$type_desc}

	if {[catch {
		ob_db::exec_qry ob_cgroup::insert_type $group_type $type_desc
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:insert_type failed $msg}
		error $msg
	}
}



# Update a group type
#
#   group_type  - the group type
#   type_desc   - the description
#
proc ob_cgroup::update_type { group_type type_desc } {

	ob_log::write DEBUG {ob_cgroup:update_type\
		group_type=$group_type type_desc=$type_desc}

	if {[catch {
		ob_db::exec_qry ob_cgroup::update_type $group_type $type_desc
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:update_type failed $msg}
		error $msg
	}
}



#--------------------------------------------------------------------------
# Group Desc Procedures
#--------------------------------------------------------------------------

# Get all group descs
#
#   returns an array as a list
#
proc ob_cgroup::get_descs { group_type } {

	array set DESCS [array unset DESCS]

	ob_log::write DEBUG {ob_cgroup:get_descs group_type=$group_type}

	set rs [ob_db::exec_qry ob_cgroup::get_descs $group_type]

	set DESCS(nrows)     [db_get_nrows $rs]
	set DESCS(colnames)  [db_get_colnames $rs]

	# populate the array with the rows from the result set
	for {set i 0} {$i < $DESCS(nrows)} {incr i} {
		foreach col $DESCS(colnames) {
			set DESCS($i,$col) [db_get_col $rs $i $col]
		}
	}
	ob_db::rs_close $rs

	return [array get DESCS]
}


# Get details for a group desc
#
#   group_name - name of group for which result is required
#   return     - a list of values for
#                group_type
#                group_name
#                group_desc
#                multi_value
#                dflt_grp_val_id
#
proc ob_cgroup::get_desc { group_name } {

	ob_log::write DEBUG {ob_cgroup:get_desc group_name=$group_name}

	array set RESULT [array unset RESULT]

	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get_desc $group_name]
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:get_desc failed: $msg}
		error $msg
	}

	set nrows [db_get_nrows $rs]

	# if the nrows is not 1, then something bad happened
	if {$nrows == 0} {
		error {ob_cgroup:get_desc returned 0 rows}
	}
	if {$nrows > 1} {
		error "ob_cgroup:get_desc returned $nrows rows"
	}

	foreach col [db_get_colnames $rs] {
		set RESULT($col) [db_get_col $rs 0 $col]
	}
	ob_db::rs_close $rs

	return [array get RESULT]

}



# Insert a group desc
#
#   group_name
#   group_desc
#   group_type
#   multi_value
#   dflt_grp_val_id
#
proc ob_cgroup::insert_desc {
	group_name group_desc group_type multi_value dflt_grp_val_id
} {

	ob_log::write DEBUG {ob_cgroup::insert_desc\
		group_name=$group_name\
		group_desc=$group_desc\
		group_type=$group_type\
		multi_value=$multi_value\
		dflt_grp_val_id=$dflt_grp_val_id\
	}

	if {[catch {
		ob_db::exec_qry ob_cgroup::insert_desc\
			$group_name\
			$group_desc\
			$group_type\
			$multi_value\
			$dflt_grp_val_id
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:insert_type failed $msg}
		error $msg
	}
}



# Update a group desc
#
#   group_name
#   group_desc
#   group_type
#   multi_value
#   dflt_grp_val_id
#
proc ob_cgroup::update_desc {
	group_name group_desc group_type multi_value dflt_grp_val_id
} {

	ob_log::write DEBUG {ob_cgroup::update_desc\
		group_name=$group_name\
		group_desc=$group_desc\
		group_type=$group_type\
		multi_value=$multi_value\
		dflt_grp_val_id=$dflt_grp_val_id\
	}

	if {[catch {
		ob_db::exec_qry ob_cgroup::update_desc\
			$group_name\
			$group_desc\
			$group_type\
			$multi_value\
			$dflt_grp_val_id
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:update_type failed $msg}
		error $msg
	}
}



#--------------------------------------------------------------------------
# Group Value Procedures
#--------------------------------------------------------------------------

# Get all group values
#
#   group_name - name of group for which to get the value
#   returns an array as a list
#
proc ob_cgroup::get_values { group_name } {

	array set VALUES [array unset VALUES]

	ob_log::write DEBUG {ob_cgroup:get_values group_name=$group_name}

	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get_values $group_name]
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:get_values failed: $msg}
		error $msg
	}

	set VALUES(nrows)     [db_get_nrows $rs]
	set VALUES(colnames)  [db_get_colnames $rs]

	# populate the array with the rows from the result set
	for {set i 0} {$i < $VALUES(nrows)} {incr i} {
		foreach col $VALUES(colnames) {
			set VALUES($i,$col) [db_get_col $rs $i $col]
		}
	}
	ob_db::rs_close $rs

	return [array get VALUES]
}



# Get information for a specific group value
#
#   group_value_id - id of the specific group value
#
proc ob_cgroup::get_value { group_value_id } {

	array set RESULT [array unset RESULT]

	ob_log::write DEBUG {ob_cgroup:get_values group_value_id=$group_value_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_cgroup::get_value $group_value_id]
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup:get_value failed: $msg}
		error $msg
	}

	set nrows [db_get_nrows $rs]

	# if the nrows is not 1, then something bad happened
	if {$nrows == 0} {
		error {ob_cgroup:get_value returned 0 rows}
	}
	if {$nrows > 1} {
		error "ob_cgroup:get_type_desc returned $nrows rows"
	}

	# return a list of values
	foreach col [db_get_colnames $rs] {
		set RESULT($col) [db_get_col $rs 0 $col]
	}
	ob_db::rs_close $rs

	return [array get RESULT]
}



# Insert a group value
#
#   group_name     - group name (of the description)
#   group_value    - actual value
#   value_desc     - description
#
proc ob_cgroup::insert_value { group_name group_value value_desc} {

	ob_log::write DEBUG {ob_cgroup::insert_value\
		group_name=$group_name\
		group_value=$group_value\
		value_desc=$value_desc
	}

	if {[catch {
		ob_db::exec_qry ob_cgroup::insert_value $group_name $group_value\
			$value_desc
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup::insert_value failed $msg}
		error $msg
	}
}



# Update a group value
#
#   group_value_id - identifier for group value
#   group_name     - group name (of the description)
#   group_value    - actual value
#   value_desc     - description
#
proc ob_cgroup::update_value {
	group_value_id group_name group_value value_desc
} {

	ob_log::write DEBUG {ob_cgroup::update_value\
		group_value_id=$group_value_id
		group_name=$group_name\
		group_value=$group_value\
		value_desc=$value_desc
	}

	if {[catch {
		ob_db::exec_qry ob_cgroup::update_value $group_value_id $group_name\
			$group_value $value_desc
	} msg]} {
		ob_log::write ERROR {qry ob_cgroup::insert_value failed $msg}
		error $msg
	}
}
