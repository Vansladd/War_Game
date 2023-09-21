# Copyright (C) 2013 Openbet Technology Ltd. All Rights Reserved.
#
# Mock Result Set builder
#
# Given a valid JSON string the builder will produce a result set, that
# can be used for unit / functional testing.
#
# The following JSON string:
#	[
#		{
#			"offer_id": "1",
#			"max_claims": "5",
#			"unlimited_claims": "N",
#			"triggers": [
#				{
#					"trigger_id": "1",
#					"type_code": "STLWIN",
#					"rank": "0",
#					"bet_types": [
#						{
#							"bnr_bet_type": "DBL",
#							"percentage_amount": "25.00",
#							"max_losing_legs": ""
#						},
#						{
#							"bnr_bet_type": "TBL",
#							"percentage_amount": "25.00",
#							"max_losing_legs": "2"
#						}
#					]
#				},
#				{
#					"trigger_id": "2",
#					"type_code": "STLWIN",
#					"rank": "1",
#					"bet_types": [
#						{
#							"bnr_bet_type": "DBL",
#							"percentage_amount": "25.00",
#							"max_losing_legs": ""
#						}
#					]
#				}
#			]
#		}
#	]
#
# Will be converted to a result set with columns:
# offer_id max_claims unlimited_claims trigger_id type_code rank bet_type percentage_amount max_losing_legs
#
# And rows:
# 1 5 N 1 STLWIN 0 DBL 25.00 {}
# 1 5 N 1 STLWIN 0 TBL 25.00 2
# 1 5 N 2 STLWIN 1 DBL 25.00 {}
#
# The JSON string is converted into an intermediate Tcl Dict. We
# traverse the dict in a depth first way.
# The data structure has the following properties:
#
# * If we follow a single leaf, we can retrieve all the rs columns.
# * Every leaf represents a row in the result set.
#
# CAUTION! When providing numbers, still wrap them in double quotes. Tcl's JSON parser
# seems to have a bug when the last atrribute of an object is a number and there's some
# whitespace formating involved.
#
# E.g. json::json2dict {{"a": "foo", "b": 5     }} will set the value of b to "5     "
#
# Synopsis:
#   package require core::stub::db ?1.0?
#
# Procedures:
#	core::stub::db::build_rs
#	core::stub::db::get_rs
#	get_empty_rs
#
#
set pkg_version 1.0
package provide core::stub::db $pkg_version


# Dependencies
package require json        1.0
package require core::log   1.0
package require core::args  1.0


# Variables
namespace eval core::stub::db {

	variable DATA
}


core::args::register_ns \
	-namespace core::stub::db \
	-version   $pkg_version \
	-dependent [list core::log core::args] \
	-docs      slap/db.xml


#-------------------------------------------------------------------------------
# Public
#-------------------------------------------------------------------------------

#
# Build a result set from a JSON string. The RS is initially stored
# in a dict structure.
#
#	@param name	The name of the stub::db result set
#	@param json	JSON string that will be used to create the result set
#
core::args::register \
	-proc_name core::stub::db::build_rs \
	-args [list \
		[list -arg -name  -mand 1 -check STRING -desc {The name of the stub::db result set}] \
		[list -arg -json -mand 1 -check ASCII -desc {JSON string that will be used to create the result set}] \
	] \
	-body {
		variable DATA

		set name $ARGS(-name)
		set str $ARGS(-json)

		dict set DATA $name [json::json2dict $str]
	}



#
# Retrieve a mock result set
#
# 	@param name	The result set to be retrieved
#	@return	The mock result set
#
core::args::register \
	-proc_name core::stub::db::get_rs \
	-args [list \
		[list -arg -name -mand 1 -check STRING -desc {The result set to be retrieved.}] \
	] \
	-body {
		variable DATA

		set name $ARGS(-name)
		set rs [db_create [_get_columns [lindex [dict get $DATA $name] 0]]]

		foreach obj [dict get $DATA $name] {
			_get_rows $rs $obj [list]
		}

		return $rs
	}



#
# Retrieve a result set with no rows.
#
#	@param name	The name of the result set
#	@return		The empty result set
#
core::args::register \
	-proc_name core::stub::db::get_empty_rs \
	-args [list \
		[list -arg -name -mand 1 -check STRING -desc {The name of the result set}] \
	] \
	-body {
		variable DATA
		set name $ARGS(-name)

		return [db_create [_get_columns [lindex [dict get $DATA $name] 0]]]
	}



#-------------------------------------------------------------------------------
# Private
#-------------------------------------------------------------------------------

#
# Parse the intemediary dict structure and add the rows to the
# provided result set.
#
#	@param rs	The result set where the rows will be added
#	@param	d	The dict data structure that holds the stub::db data
#	@param vals	A list of the values that we've already found for this row
#
proc core::stub::db::_get_rows {rs d vals} {

	lappend vals {*}[dict values $d]

	set ret [_has_dict [dict values $d]]
	if {[lindex $ret 0]} {
		foreach val [lindex $ret 1] {
			# Remove the value since it require further processing and recurse
			# for each found dict in a new loop.
			set idx [lsearch $vals $val]
			set vals [lreplace $vals $idx $idx]
		}

		foreach val [lindex $ret 1] {
			foreach d $val {
				_get_rows $rs $d $vals
			}

		}
	} else {
		db_add_row $rs $vals
	}
}



#
# Checks if the provided list contains a dict.
#	@param l	The list
#	@return 	A list where the first element denotes if
#				dict(s) have been found and the second element is
#				the list of found dicts.
#
proc core::stub::db::_has_dict {l} {
	set ret [list]
	set found 0
	foreach val $l {
		if {[string is list $val]} {
			if {[_is_dict [lindex $val 0]]} {
				lappend ret $val
				set found 1
			}
		}
	}

	return [list $found $ret]
}



#
# Retrieve the list of columns of a result set.
#
#	@param r	The intermediaty dict data structure
#	@return		A list of the columns found
#
proc core::stub::db::_get_columns {r} {

	set columns [list]
	lappend columns {*}[dict keys $r]

	foreach col $columns {
		set val [dict get $r $col]
		if {[string is list $val]} {
			if {[_is_dict [lindex $val 0]]} {
				# Remove the column
				set idx [lsearch $columns $col]
				set columns [lreplace $columns $idx $idx]

				lappend columns {*}[_get_columns [lindex $val 0]]
			}
		}
	}

	return $columns
}

#
# Checks if a variable is a dict.
# Caution! Both empty dicts and empty strings return a size of 0!
# In the context of this package we consider both false
#
#	@param d	The variable we want to check.
#	@return		0|1 depending on whether the variable is a dict or not
#
proc core::stub::db::_is_dict {d} {
	if {[catch {set size [dict size $d]}]} {
		return 0
	} else {
		return [expr {$size > 0}]
	}
}
