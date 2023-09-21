#
#
#     JSON Library.
#
#     Provies a nested structure for storing the data and type of
#     data in a JSON structure, as well as an interface to yajltcl for parsing and genersting JSON
#
#     See https://wiki.openbet.com/display/core/JSON+Package+-+core%3A%3Ajson for more info
#
#     Internal data representation
#     ================================
#
#     NOTE: It is not intended that people access the representations directly - they should 
#           manipulate nodes using core::json:: functions. 
#           This is purely for understanding this file.
#
#     JSON nodes are represented in TCL using a mix of nested dicts and lists.
#     using native TCL structures means we do not need to worry about memory management
#
#     Each node represents a data value in a JSON document
#     In TCL this is a TCL dict with two keys 
#     type - The type of the node
#     val  - The value of the node, the format depending on the type.
#
#     Types:
#     ------
#     Referring to http://www.json.org/
#
#     dict - This in JSON terminology is a JSON Object, and is name value pairs.
#            e.g. { "Name" : "Monish", Id : 3}
#            'val' contains a dict of the keys (which are strings) and the values which nested JSON nodes  
#     list - In JSON Terminology is an Array, and is a list of values.
#            'val' contails a TCL list of JSON Nodes.
#     null - This is the JSON null type. 'val' in the dict should always be present and be the empty string
#     str  - This is a JSON String. val is the unescaped string. Escaping of newlines and other chaarcters is handled by
#            yajl
#     bool - This are the JSON true/false values. 'val' is a TCL boolean value.
#     num  - This is a JSON number. JSON does not distinguish between ints and floating point numbers.
#            'val' must be a TCL int or  double and cannot be empty
#
#
#
#   e.g The following JSON
#
#    {
#       "Name": Monish,
#       "Id"  : 3,
#       "Roles" : [ 1,2,"www people",null]
#    }
#
#
#    is stored internally as this
#
#    dict create \
#             Name    [dict create type str val Monish]  \
#             Id      [dict create type num val 3]       \
#           Roles     [dict create type list val [list \
#                                                     [dict create type num val 1] \
#                                                     [dict create type num val 2] \
#                                                     [dict create type str val "www people" ] \
#                                                     [dict create type null val {}] \
#                                                 ]
#                      ]
#
#     NOTE: It is not intended that people access the representations directly - they should
#           manipulate nodes using core::json:: functions, as the representaion may change in the future.


package require core::log           1.0
package require core::util          1.0
package require core::args          1.0

namespace eval core::json {} {
	variable CFG
	variable PKG_VERSION

	set PKG_VERSION 1.0
	core::args::register_ns \
		-namespace core::json \
		-version   $PKG_VERSION \
		-docs      util/json.xml

	set CFG(initalised)   0
	set CFG(yajltcl_err)  {}
	set CFG(yajltcl_ver)  {}

	array set YAJL_INSTANCE_CREATED [list]

	package provide core::json $PKG_VERSION

}

# Initialise the API
core::args::register \
	-proc_name core::json::init \
	-body {
		variable CFG
		if {$CFG(initalised)} {
			return
		}

		# The following packages may not be available
		# so we should disable parse / generate if not available
		if {[catch {
			#  We need >= 1.3 as it has parsing in it.
			#  Latest Openbet TCL build should have this in.	
			set CFG(yajltcl_ver) [core::util::load_package -package yajltcl -version 1.3]
		} err]} {
			core::log::write WARN {core::json: *******************************************************}
			core::log::write WARN {core::json: yajltcl not initalised - $err}
			core::log::write WARN {core::json: json::parse & json::generate disabled }
			core::log::write WARN {core::json: *******************************************************}
			set CFG(yajltcl_err) $err
		} else {
			core::log::write INFO {core::json: yajltcl version $CFG(yajltcl_ver) loaded} 
		}
		core::log::write INFO {core::json: Initalised} 
		set CFG(initalised) 1
	}


core::args::register \
	-proc_name core::json::parse \
	-desc {Parses a JSON string using yajl} \
	-returns {Returns a JSON node} \
	-args [list \
		[list -arg -json -mand 1 -check ANY -desc {The JSON string, in TCL native unicode}] \
    ] \
-body {
	variable CFG
	init
	if {$CFG(yajltcl_err) != ""} {
		core::log::write ERROR {core::json::parse: yajltcl package did not initalise: $CFG(yajltcl_err)}
		error "core::json::parse: yajltcl package did not initalise: $CFG(yajltcl_err)"
	}
	#  Auto creates a unique name for the object
	set json_str  $ARGS(-json)

	if {[string trim $json_str] == ""} {
		core::log::write ERROR {core::json::parse: JSON string is blank - length [string length $json_str]}
		error "core::json::parse: JSON string is blank - length [string length $json_str])"
	}

	set j [_get_yajl_instance]
	set err {}
	if {[catch {
		set lcmd [$j parse $json_str]
		$j parse_complete
		$j reset
		set i 0
		set node [_parse_yajl_val $lcmd i]		
	} msg]} {
		core::log::write ERROR {core::json::parse: Error parsing JSON}
		core::log::write_error_info ERROR
		$j reset
		error "core::json::parse: Error parsing JSON: $msg"
	}
	return $node
}

core::args::register \
	-proc_name core::json::generate \
	-desc {
		Given a JSON Node outputs a JSON string representing it.
} \
-returns {
The JSON Structure
	} \
	-args [list \
		[list -arg -node     -mand 1 -check ANY             -desc {JSON node to be output as a string}] \
		[list -arg -pretty   -mand 0 -check BOOL -default 0 -desc {Whether to pretty print the JSON String, or print it on one line}] \
	] \
-body {
	variable CFG
	init
	if {$CFG(yajltcl_err) != ""} {
		error "core::json::parse: yajltcl package did not initalise: $CFG(yajltcl_err)"
	}

	set node $ARGS(-node)
	set beautify $ARGS(-pretty)
	
	set lcmd [_generate_yajl $node]
	set yajl [_get_yajl_instance $beautify]
	$yajl {*}$lcmd
	set json_str [$yajl get]
	$yajl reset
	return $json_str
}


core::args::register \
	-proc_name core::json::new_val \
	-desc {
		Returns a new JSON Node containing a single atomic value of the specified type
	} \
	-args {
		{-arg -type -mand 1 -check {ENUM -args {num str bool node null}} -desc {Type of value}}
		{-arg -val  -mand 1 -check ANY  -desc {The Value of the node}}
	} \
	-body {
		set _fname "core::json::new_val"

		set type  $ARGS(-type)
		set val   $ARGS(-val)

		#  nulls need to have val=""
		#  or it will error
		if {$type == "null"} {
			set val {}
		}
		foreach {ret node} [_new_json_node $type $val] {break}

		if {$ret == "OK"} {
			return $node
		} elseif {$ret == "BAD_DATA"} {
			error "$_fname: Invalid -val for $type: $node"
		} else {
			error "$_fname: $node"
		}
	}

core::args::register \
	-proc_name core::json::new_dict \
	-desc {
		Returns a JSON node for a dict (JSON name/value pairs)
	} \
	-args {
		{-arg -type -mand 1 -check {ENUM -args {empty num str bool null node stream}}  -desc {Specifies the type of each element in the object}}
		{-arg -val      -mand 1 -check ANY                                             -desc {A TCL dict containg the node / value pairs. }}
		{-arg -nullable -mand 0 -check BOOL -default 0                                 -desc {Whether to interpret the empty string as null. Ignored for -type node}}
	} \
	-body {
		set _fname "core::json::new_dict"

		set type  $ARGS(-type)
		set val   $ARGS(-val)

		set ret_node [dict create type dict val [dict create]]

		switch -exact -- $type {
			empty {
				if {$val != {}} {
					error "$_fname: -val must be empty string"
				}
			}
			null {
				if {$val != {}} {
					error "$_fname: -val must be empty string"
				}
				set val null
			}
			node {
				# Param val is be a dictionary
				if {[llength $val] % 2} {
					return [list BAD_DATA "Expecting a $type"]
				}

				dict for {k v} $val {
					if {[node_type $v] == {bad}} {
						error "$_fname: key '$k' Expecting a node but got '$val'"
					} else {
						dict set ret_node val $k $v
					}
				}
			}
			stream {
				lassign [ _new_from_stream "dict" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
				set ret_node $node
			}
			num -
			str -
			bool {
				# Param val is be a dictionary
				if {[llength $val] % 2} {
					error "Invalid input: Expecting dict of $type"
				}

				if {$ARGS(-nullable)} {
					dict set ret_node val $k null
				}

				dict for {k v} $val {
					lassign [_new_json_node $type $v] retCode retVal
					if {$retCode == "OK"} {

						dict set ret_node val $k $retVal
					} elseif {$retCode == "BAD_DATA"} {
						error "$_fname: Invalid -val for $type ($retVal)"
					} else {
						error "$_fname: $retVal"
					}
				}

			}
			default {
				error "$_fname: Unknown type"
			}
		}
		return $ret_node
	}


core::args::register \
	-proc_name core::json::new_list \
	-desc {
		Returns a JSON node representing a list (JSON array)
	} \
	-args {
		{-arg -type     -mand 1 -check {EXACT -args {num str bool node stream}}   -desc {Specifies the type of each element in the object}}
		{-arg -val      -mand 1 -check ANY                                        -desc {A TCL list containing the list of elements}}
		{-arg -nullable -mand 0 -check BOOL -default 0                            -desc {Whether to interpret the empty string as null. Ignored for -type node}}
	} \
	-body {
		set _fname "core::json::new_list"

		set type  $ARGS(-type)
		set val   $ARGS(-val)

		set ret_node [dict create type list val [list]]

		# Expecting a list. Empty string as imput is allowed if -nullable
		if {![string is list -strict $val]} {
			if {$ARGS(-nullable)} {
				dict set $ret_node val null
			} else {
				error "Wrong input: expecting a list"
			}
		}

		switch -exact -- $type {
			num -
			str -
			bool {
				foreach v $val {
					# Check item first
					lassign [_new_json_node $type $v] retCode retVal

					# Add it to the list
					if {$retCode == "OK"} {

						dict lappend ret_node val $retVal

					} elseif {$retCode == "BAD_DATA"} {
						error "$_fname: Invalid -val for $type ($retVal)"
					} else {
						error "$_fname: $retVal"
					}
				}
			}
			node {
				# Param val is be a dictionary
				if {![string is list -strict $val]} {
					return [list BAD_DATA "Expecting a $type"]
				}

				set valList [list]

				foreach v $val {
					if {[node_type $v] == {bad}} {
						error "Expecting a node but got \"$val\""
					} else {
						dict lappend ret_node val $v
					}
				}
			}
			stream {
				lassign [ _new_from_stream "list" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
				set ret_node $node
			}
			default {
				error "$_fname: Unknown type"
			}
		}

		return $ret_node
	}

#   This is replaced by core::json::set_val
#   Included here for backward compatibility
#
proc core::json::dict_set args {
	return [uplevel 1 core::json::set_val $args]
}


core::args::register \
	-proc_name core::json::set_val \
	-desc {
		Sets the key value of a TCL
	} \
	-args {
		{-arg -node_var -mand 1 -check {ASCII}                                                        -desc {Node Variable}}
		{-arg -type     -mand 1 -check {EXACT -args {num str bool null node dict_stream list_stream}} -desc {Specifies the type of each element in the object}}
		{-arg -val      -mand 1 -check ANY                                                            -desc {The value being created}}
		{-arg -lpath    -mand 1 -check LIST                                                           -desc {The path of keys (list indexes or dict ketys) to set}}
		{-arg -require  -mand 0 -check ANY -default {end-1}                                           -desc {The portion of -lpath that must exist.}}
	} -body {
		set _fname   "core::json::set_val"

		set node_var   $ARGS(-node_var)
		set type       $ARGS(-type)
		set val        $ARGS(-val)
		set lpath      $ARGS(-lpath)
		set require    $ARGS(-require)

		upvar $node_var u_node
		if {![info exists u_node]} {
			error "$_fname: Variable -node_var $node_var does not exist"
		}

		#  First check the path exists
		if {$require != "-"} {
			set lrequired_path [lrange $lpath 0 $require]
			set ret [_get $u_node {} $lrequired_path]
			lassign $ret status ret1 ret2
			if {$status == "NOT_FOUND"} {
				error "$_fname: keys [join $lrequired_path /] must exist" "" "core::json::$status"
			}
			#  This reduces the reference counts for the object in the node
			#  which means that when necessary this will avoid an expensive copy of the object
			unset ret
			unset ret1
			unset ret2
		}

		switch -- $type {
			num     -
			str     -
			bool    -
			null    {
				#  Prepare the node
				lassign [_new_json_node $type $val] ret node
				if {$ret != "OK"} {
					error "$_fname: $node"
				}
			}
			node {
				if {[node_type $val] == {bad}} {
					error "Expected a node but got $val"
				}
				set node $val
			}
			dict_stream {
				lassign [ _new_from_stream "dict" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
			}
			list_stream {
				lassign [ _new_from_stream "list" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
			}
			default {
				error "$_fname: should not be reached"
			}
		}
		#  OK - set the node
		lassign [_node_action u_node $lpath [list set $node]] status lpath msg
		if {$status != "OK"} {
			error "$_fname: $msg at path [join $lpath /]"
		}
	}

core::args::register \
	-proc_name core::json::unset_val \
	-desc {
		!!Unsets the node referenced by -lpath fron the node in -node_var
		!!Note all but the final element of -lpath must exists, or an exception will be thrown
		!!Unsetting a list key or dict element that does not exist will leave the node unchanged but suceed silently.
		!!If the penultimite element of lpath is not a list or dict an error is thrown.
	} \
	-args {
		{-arg -node_var -mand 1 -check {ASCII}                                                        -desc {Node Variable}}
		{-arg -lpath    -mand 1 -check LIST                                                           -desc {The path (list indexes or dict keys). All but the last element must exist}}
	} -body {
		set _fname   "core::json::unset_val"

		set node_var   $ARGS(-node_var)
		set lpath      $ARGS(-lpath)

		upvar $node_var u_node
		if {![info exists u_node]} {
			error "$_fname: Variable -node_var $node_var does not exist"
		}

		#  We require the -lpath to have at least 1 item
		if {[llength $lpath] == 0} {
			error "$_fname: -lpath must have one element"
		}
		
		set unset_key [lindex $lpath end]
		set lpath     [lrange $lpath 0 end-1]
		
		#  First check the path exists
		if {[llength $lpath] > 0} {
			lassign [_get $u_node {} $lpath] status
			if {$status == "NOT_FOUND"} {
				error "$_fname: keys '/[join $lpath /]' must exist" "" "core::json::$status"
			}
		}

		#  OK - unset the node
		lassign [_node_action u_node $lpath [list unset $unset_key]] status lret_path msg
		if {$status != "OK"} {
			error "$_fname: $msg at path [join $lret_path /]"
		}
	}


core::args::register \
	-proc_name core::json::dict_lappend \
	-desc {
		Lappends the supplied value to the key value of a JSON object.
		Can automatically create intermediary dict elements
		see -require option
	} \
	-args {
		{-arg -node_var -mand 1 -check {ASCII} -desc {Node Variable}}
		{-arg -type     -mand 1 -check {EXACT -args {num str bool null node dict_stream list_stream}} -desc {Specifies the type of each element in the object}}
		{-arg -val      -mand 1 -check ANY        -desc {The value being created}}
		{-arg -lpath    -mand 0 -check LIST       -desc {The path of keys to set}}
		{-arg -require  -mand 0 -check ANY -default {end-1}                                           -desc {The portion of -lpath that must exist.}}
	} \
	-body {
		set _fname   "core::json::dict_lappend"

		set node_var   $ARGS(-node_var)
		set type       $ARGS(-type)
		set val        $ARGS(-val)
		set lpath      $ARGS(-lpath)
		set require    $ARGS(-require)

		upvar $node_var u_node

		if {![info exists u_node]} {
			error "$_fname: Variable -node_var $node_var does not exist"
		}

		#  First check the path exists
		#
		if {$require != "-"} {
			set lrequired_path [lrange $lpath 0 $require]
			set ret [_get $u_node {} $lrequired_path]
			lassign $ret status ret1 ret2
			if {$status == "NOT_FOUND"} {
				error "$_fname: keys [join $lrequired_path /] must exist"  "" "core::json::$status"
			}
			#  This reduces the reference counts for the object in the node
			#  which means that when necessary this will avoid an expensive copy of the object
			unset ret
			unset ret1
			unset ret2
		}

		switch -- $type {
			num     -
			str     -
			bool    -
			null    {
				#  Prepare the node
				#
				lassign [_new_json_node $type $val] ret node
				if {$ret != "OK"} {
					error "$_fname: $node"
				}
			}
			node {
				if {![_is_valid_node $val]} {
					error "$_fname: Invalid node passed in via -node"
				}
				set node $val
			}
			dict_stream {
				lassign [ _new_from_stream "dict" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
			}
			list_stream {
				lassign [ _new_from_stream "list" $val] status node
				if {$status != "OK"} {
					error "Invalid input: $node"
				}
			}
			default {
				error "$_fname: should not be reached"
			}
		}

		#  OK - set the node
		lassign [_node_action u_node $lpath [list lappend $node]] status lpath msg
		if {$status != "OK"} {
			error "$_fname: $msg at path [join $lpath /]"
		}
	}

core::args::register \
	-proc_name core::json::get_val \
	-desc {
		Returns a the value pointed to by the argument or list of arguments
		Either returns a JSON object corresponding to the portion of the
		JSON document, or the value is not an array or list.
	} \
	-args {
		{-arg -type     -mand 0 -check {ENUM -args {node val}} -default val      -desc {The type of value retuned}}
		{-arg -node     -mand 1 -check ANY                                       -desc {The JSON Node we are traversing}}
		{-arg -lpath    -mand 0 -check LIST                                      -desc {Path to element - for nested list is a list of Disct keys or list positions}}
		{-arg -default  -mand 0 -check ANY                     -default __NONE__ -desc {Default value to return if not found, rather than returning an error}}
	} \
	-body {
		set _fname {core::json::get_val}
		set is_def 0

		if {$ARGS(-default)!= "__NONE__"} {
			set is_def 1
			set default $ARGS(-default)
		}

		set ret_type $ARGS(-type)
		set lpath    $ARGS(-lpath)
		set node     $ARGS(-node)

		set ret    [_get $node {} $lpath]
		set status [lindex $ret 0]

		if {$status == "OK"} {
			set node  [lindex $ret 1]
			set type [dict get $node type]
			set val  [dict get $node val]

			switch -- $ret_type {
				node {
					return $node
				}
				val {
					return [_strip_node $node]
				}
			}
		} elseif {$status in {NOT_FOUND BAD_INDEX BAD_TYPE} && $is_def} {
			return $default
		} else {
			set lerror_pos [lindex $ret 1]
			set msg        [lindex $ret 2]
			error "$_fname: $msg - at JSON path '/[join $lerror_pos /]'" "" "core::json::$status"
		}
	}

core::args::register \
	-proc_name core::json::get_llength \
	-desc {
		Returns the list length of the
		list references by the -lpath attribute
	} -returns {
	!! Length of list for a list node_type
	!! 0 if the node is null
	!! If the -lpath does not exist in the node, then -default if specified, otherwise throws an exeption.
	!! If the -lpath does exist, but is not of type list or null, throws an exception 
	}\
	-args {
		{-arg -node      -mand 1 -check ANY                     -desc {The JSON Node we are traversing}}
		{-arg -lpath     -mand 0 -check LIST                    -desc {Path to element - for nested list is a list of Disct keys or list positions}}
		{-arg -default   -mand 0 -check ANY   -default __NONE__ -desc {Default value to return if not found, rather than returning an error}}
	} \
	-body {
		set _fname {core::json::get_llength}
		set is_def 0
		set default $ARGS(-default)
		if {$ARGS(-default)!= "__NONE__"} {
			set is_def 1
		}

		set lpath       $ARGS(-lpath)
		set input_node  $ARGS(-node)

		set ret [_get $input_node {} $lpath]
		lassign $ret status node

		if {$status == "OK"} {
			set type [node_type $node]

			switch -- $type {
				list {
					return [llength [dict get $node val]]
				}
				null {
					return 0
				}
				default {
					error "$_fname: expecting node of type 'list', got '$type'"
				}
			}
		} elseif {$is_def && $status in {NOT_FOUND BAD_INDEX BAD_TYPE}} {
			return $default
		} else {
			set lerror_pos [lindex $ret 1]
			set msg        [lindex $ret 2]
			error "$_fname: $msg - at JSON path '/[join $lerror_pos /]'"
		}
	}

core::args::register \
	-proc_name core::json::get_keys \
	-desc {
		Returns the keys of the
		dict references by the -lpath attribute
		Throws exception if node referenced is neither a dict nor null
	} \
	-args {
		{-arg -node        -mand 1 -check ANY   -desc {The JSON Node we are traversing}}
		{-arg -lpath       -mand 0 -check LIST  -desc {Path to element - for nested list is a list of Dict keys or list positions}}
		{-arg -of_type     -mand 0 -check LIST  -desc {Filter keys by type - List of types list, dict, str, num, bool, null, val=all except dict and list}}
		{-arg -default   -mand 0 -check ANY   -default __NONE__ -desc {Default value to return if not found, rather than returning an error}}
	} \
	-body {
		set fn {core::json::get_keys}
		set is_def 0
		set default $ARGS(-default)
		if {$default != "__NONE__"} {
			set is_def 1
		}

		set lpath       $ARGS(-lpath)
		set input_node  $ARGS(-node)
		set of_type     $ARGS(-of_type)

		if {[llength $of_type] > 0} {
			set type_filter 1
		} else {
			set type_filter 0
		}

		set dtype [dict create]
		foreach t $of_type {
			switch -- $t {
				list -
				dict -
				str  -
				num  -
				bool -
				null {
					dict set dtype $t   1
				}
				val {
					dict set dtype str   1
					dict set dtype num   1
					dict set dtype bool  1
					dict set dtype null  1
				}
			}
		}

		set ret [_get $input_node {} $lpath]
		lassign $ret status node

		if {$is_def && $status in {NOT_FOUND BAD_INDEX BAD_TYPE}} {
			return $default
		} elseif {$status != "OK"} {
			set lerror_pos [lindex $ret 1]
			set msg        [lindex $ret 2]
			error "$fn : $msg - at JSON path '/[join $lerror_pos /]'" "" "core::json::$status"
		}

		set type [node_type $node]

		switch -- $type {
			dict {
				set dval [dict get $node val]
				set lkey [dict keys $dval]
				
				if {!$type_filter} {
					return $lkey
				}
				set lret [list]
				foreach k $lkey {
					set choose_it 0
					set type [node_type [dict get $dval $k]]
					
					if {[dict exists $dtype $type]} {
						set choose_it 1
					}
					
					if {$choose_it} {
						lappend lret $k
					}
				}
				return $lret
			}
			null {
				return [list]
			}
			default {
				if {$is_def} {
					return $default
				} else {
				error "$fn: expecting node of type 'dict', got '$type'" "" core::json::BAD_TYPE
				}
			}
		}
	}

core::args::register \
	-proc_name core::json::get_type \
	-desc {
		Returns the type of the node referenced by the -lpath attribute
	} \
	-returns {
		type of node, or the empty string if it is not found
		!! 'str','num','null','dict','list' or ''
	} \
	-args {
		{-arg -node      -mand 1 -check ANY   -desc {The JSON Node we are traversing}}
		{-arg -lpath     -mand 0 -check LIST  -desc {Path to element - for nested list is a list of Dict keys or list positions}}
	} \
	-body {
		set fn {core::json::get_type}

		set lpath       $ARGS(-lpath)
		set input_node  $ARGS(-node)

		set ret [_get $input_node {} $lpath]
		lassign $ret status node

		if {$status in {NOT_FOUND BAD_INDEX} } {
			return ""
		} elseif {$status != "OK"} {
			set lerror_pos [lindex $ret 1]
			set msg        [lindex $ret 2]
			error "$fn: $msg - at JSON path '/[join $lerror_pos /]/"
		}

		set type [node_type $node]

		switch -- $type {
			bad {
				error "$fn: Node is corrupt" 
			}
			default {
				return $type 
			}
		}
	}

core::args::register \
	-proc_name core::json::dump \
	-desc {Returns a string represntation of the string - mainly for debugging} \
	-args {
		{-arg -node -mand 1 -check ANY -desc {The JSON Node we are outputting}}
	} \
	-body {
		set node $ARGS(-node)

		set out [_dump_node $node 0]
		return $out
	}

core::args::register \
	-proc_name core::json::rs_to_json \
	-desc {
		Takes a result set, and converts to a JSON document
	} -returns {The JSON node generated from the result set} \
	-args [list \
		[list -arg -rs        -mand 1 -check  NONE                       -desc {The result set to parse} ]\
		[list -arg -format    -mand 1 -check {EXACT -args {flat nest}}   -desc {Output format - flat (list of rows, dict of cols), nest (Nested JSON, requires -nest_spec)} ] \
		[list -arg -nest_spec -mand 0 -check  LIST -default [list]       -desc {
=c=
!!The specification to split json into nested, only when -format = nest
!!Format is a list of 'levels' in the hierarchy, that define the different levels in the hierarchy
!!e.g. event, market and selection
!!
!![list <level_0_spec> <level_1_spec> ....]
!!
!!Where <level_n_spec> is a list of name value pairs defining the 
!!patameters for the level:
!!*=mandatory
!!-level*     - Level name
!!-lkey_col*  - PK col (or cols) for this level - used to determine if a row in
!!            - this level has changed. e.g. ev_mkt_id for Market level.
!!-lcol*      - Defines the columns output in the JSON
!!            - [list <opt> <val>]
!!              Where opts are 
!!              -colname* - Name of column in results set
!!              -coltype  - Overrides the type of the JSON node.
!!                          If not specified the type on the JSON is based on the 
!!                          column type in the results set
!!              -colalias - Use this name instead of -colname in the JSON
!!              -colcmd   - Proc for filtering values. Note the return value must
!!                          be the same JSON type.
!!                          The val is added to the end of the command and the val returned
!!                          in the JSON
=c=
		} ] \
		[list -arg -lcol      -mand 0 -check  LIST -default [list]       -desc {The cols to output, for when -format flat. Blank is all columns} ] \
	] -body {
		set fn {core::json::rs_to_json}

		switch -exact $ARGS(-format) {
			"nest" {
				set lspec [list]
				foreach l $ARGS(-nest_spec) {
					set level {}
					set dspec [dict create]
					foreach {n v} $l {
						switch -exact -- $n {
							{-level}     {set level $v}
							{-lkey_col}  {dict set dspec lkey_col $v}
							{-lcol}      {dict set dspec lcol     $v}
							{-out_type}  {
									if {$v ni {list dict}} {
										error "$fn: Expecting -out_type of list dict, got $v"
									}
									dict set dspec out_type $v
							}
							default      {error "$fn: option $n is not understood"}
						}
					}
					lappend lspec $level $dspec
					
				}
				set ret [core::json::_rs_to_hierarchy $ARGS(-rs) $lspec]
			}
			"flat" {
				set ret [core::json::_rs_to_flat $ARGS(-rs) $ARGS(-lcol)]
			}
			default {
				error "$fn: Should not be reached"
			}
		}

		return $ret
	}
#
#
#   Helper function to create complex
#   JSON Nodes from a list passed in
#   Designed as asyntatic sugar to avoid loads of
#   calls to new_node
#
#   For type=list, val is a list like this
#                     type  val   ....
#
#   For type=dict, val is a list of
#                     key_val  type val ...
#   For type=node, val is an existing JSON node
#
#  returns
#  "OK"   node
#  or
#  <err_code> err_msg

#  err_code is as of _new_json_node,
#  and adds
#  BAD_FORMAT  - Data is incorrect format (e.g. wrong number of elements)
proc core::json::_new_from_stream {type val} {

	#  Treat list and dict as special cases
	#  All other types can be deferred to _new_json_node
	switch -- $type {
		list {
			#  List - iteratre through the list
			#  And recuse into each element
			set lret [list]
			if {[llength $val] % 2 != 0} {
				return [list BAD_FORMAT " :List must have an even no of elements"]
			}
			set i -1
			foreach {t v} $val {
				incr i

				lassign  [_new_from_stream $t $v] status node
				if {$status != "OK"} {
					return [list $status "${i}/${node}]"]
				}
				lappend lret $node
			}
			lassign [_new_json_node "list" $lret] status ret
			if {$status != "OK"} {
				return [list $status $ret]
			}
			return [list "OK" $ret]
		}
		dict {
			if {[llength $val] % 3 != 0} {
				return [list BAD_FORMAT " :Dict must a list whose size is divisable by three"]
			}
			set dret [dict create]
			#  Dict - Step throught the
			#  key value pairs
			#  and recurse into each value
			foreach {k t v} $val {
				lassign  [_new_from_stream $t $v] status node
				if {$status != "OK"} {
					return [list $status "${k}/${node}"]
				}
				dict set dret $k $node
			}
			lassign [_new_json_node "dict" $dret] status ret
			if {$status != "OK"} {
				#  Put a space at the beginning to ensure that the
				#  we can prepend path elements as the error is
				#  recursed up the call stack
				return [list $status $ret]
			}

			return [list OK $ret]
		}
		node {
			if {[_is_valid_node $val]} {
				return [list OK $val]
			} else {
				return [list INVALID_NODE "Invalid node passed in for stream type 'node'"]
			}
		}
		default {
			lassign [_new_json_node $type $val] status node
			if {$status != "OK"} {
				return [list $status " :$node"]
			}
			return [list OK $node]
		}
	}
}

#  Helper funstion to create a node
#  given the spec
#
#
#  type:
#
#	num           Number
#	str           String
#	bool          Boolean values
#	null          Null value
#   list          List - Val must be a list of JSON nodes
#   dict          Dict - Val must be a dict of JSON node pairs, keyed on the string
#
#  returns:
#    [list OK $node]
#
#  or in case of error
#   [list <err_code> msg
#
#  where err_code is BAD_TYPE - type not known
#                    BAD_DATA - data not suitable for type
#                    ERR      - Other error
proc core::json::_new_json_node {type val} {

	set ret_node {}

	switch -- $type {
		num {
			#  Need to handle integers separately to
			#  strip leading 0
			#  to avoid being treated as an octal
			#  i.e.
			#  % expr {int(010)}
			#  8
			regexp  {^0*(\d+)$} $val --> val

			if {[string is integer -strict $val]} {
				set ret_node [dict create type num val $val]
			} elseif {[string is double -strict $val]} {
				#  No stripping needed for doubles
				#  as 09.00 is 9
				#  e.g
				# 	% expr {int(010.)}
				#	% 10
				set ret_node [dict create type num val $val]
			} else {
				return [list BAD_DATA "Expecting a $type but got \"$val\""]
			}
		}
		str {
			set ret_node [dict create type str val $val]
		}
		bool {
			if {[string is bool -strict $val]} {
				set ret_node [dict create type bool val $val]
			} else {
				return [list BAD_DATA "Expecting a $type but got \"$val\""]
			}
		}
		null {
			if {$val == ""} {
				set ret_node [dict create type null val {}]
			} else {
				return [list BAD_DATA "Expecting a $type but got \"$val\""]
			}
		}
		list {
			#
			#  $val needs to be a list of vals
			if {[string is list -strict $val]} {
				set ret_node [dict create type list val [list]]
			}
			foreach l $val {
				if {[node_type $l] == "bad"} {
					return [list BAD_DATA "Expecting a node but got \"$val\""]
				} else {
					dict lappend ret_node val $l
				}
			}
		}
		dict {
			# TODO: Check this is a dict more gracefully
			set ret_node [dict create type dict val [list]]

			dict for {k v} $val {
				if {[node_type $v] == "bad"} {
					return [list BAD_DATA "Expecting a node for key \"$k\" but got \"$val\""]
				}
				dict set ret_node val $k $v
			}
		}
		default {
			return [list ERR "Unknown type $type"]
		}
	}
	return [list OK $ret_node]
}

#
#  Helper function
#
#
proc core::json::_is_valid_node {node} {

	return [expr {[node_type $node] != "bad"}]
}


#  Proc to return whether a node is valid, and the type
#
#
#  returns:
#
#   bad - Invalid node
#   Type of node :
#   num              - Numeric
#   str
#   bool
#   null
#   list
#   dict

proc core::json::node_type {node} {
	if {[llength $node] % 2 != 0} {
		return bad
	}

	if {![dict exists $node type] || ![dict exists $node val]} {
		return {bad}
	}
	set type [dict get $node type]
	set val [dict get $node val]

	#  Note I want this to be quick
	#  so the checks below should avoid shimmering
	#  (conversion between types)
	#  http://wiki.tcl.tk/3033
	#  Thats why, for example, I wont run a regexp
	#  on a number
	#  Of course I am asuming the command [string is ...]
	#  won't shimmer
	switch -- $type {
		str {
			return "str"
		}
		num {
			if {[string is double -strict $val]} {
				return "num"
			} else {
				return "bad"
			}
		}
		bool {
			if {[string is bool -strict $val]} {
				return "bool"
			} else {
				return "bad"
			}
		}
		null {
			if {$val == ""} {
				return "null"
			} else {
				return "bad"
			}
		}
		list {
			if {[string is list -strict $val]} {
				return "list"
			} else {
				return "bad"
			}
		}
		dict {
			#  hmm - ideally there would be a [string is dict] command
			#  I could use [string is list] and llength % 2
			#  but that will be slow as it'll shimmer between a
			#  list and dict represenation
			if {[catch {
				#  This will error if $d is not a dict
				dict size $val
			 } msg]} {
				if {$msg == "missing value to go with key"} {
					return bad
				} else {
					#  Any other error should be propagated
					error $msg $::errorInfo
				}
			}
			return "dict"
		}
		default {
			return "bad"
		}
	}
}

#   Fast version of the above proc with little to no 
#   error checking
#
proc core::json::_node_type_fast {node} {
	return [dict get $node type]

}


#   Recursive function that returns
#   All elements and parent
#   elements leading up to the path
#   that you obtain by following the patch specified.
#   B)
#   Returns a list
#  [list OK node]
#  or
#  [list <err_code> path msg]
#  where err_code is
#   NOT_FOUND - Not found
#   ERR       - Other Error
#
#  lhead    - Where we have been
#  ltail    - Where we have to go
proc core::json::_get {node lhead ltail} {

	set type [dict get $node type]
	set val  [dict get $node val ]

	if {[llength $ltail] == 0} {
		#  OK we have got to the last element
		#  in the path - just
		#  return this value
		#  whatever it is
		return [list OK $node]
	} else {
		#  Move one down in the path
		#  and recurse
		set path [lindex $ltail 0]

		switch -- $type {
			dict {
				if {[dict exists $val $path]} {
					return [_get [dict get $val $path] [concat $lhead [list $path]] [lrange $ltail 1 end]]
				} else {
					return [list NOT_FOUND $lhead "Dict element \"$path\" does not exist"]
				}
			}
			list {
				set len [llength $val]
				if {[catch {
					set ret [lindex $val $path]
				} msg]} {
					if {[regexp -- {^bad index} $msg]} {
						#  Catch the case where someone is trying to traverse a node of type index
						#  but is suppling an invalid 
						return [list BAD_INDEX $lhead "Node is a list, therefore path item must be  integer?\[+-\]integer? or end?\[+-\]integer?, got '$path'"]
					} else {
						return [list ERR $lhead $msg]
					}
				}
				if {$ret == {}} {
					return [list NOT_FOUND $lhead "List index \"$path\" out of range" ]
				} else {
					return [_get $ret [concat $lhead [list $path]] [lrange $ltail 1 end]]
				}
			}
			default {
				return [list BAD_TYPE $lhead "Cannot travel past this node type $type"]
			}
		}
	}
}

#   Generic proc to perform a write action on a node
#   included in another node.
#   Will perform the action on the node,
#   which is located by following the chain of dict keys or list indexes.
#
#   If any dict does not exists then it will be created, and lists will be
#   padded with nulls to the length specified.
#
#  node_var - Variable name of node
#  ltail    - Path to set
#
#
#  lcmd     - Command to perform on target node
#  where lcmd is
#
#  set      <node>       - Node to add
#  lappend  <node>       - Append node to list pointed to (assumes destination is a list)
#  unset    <index/key>  - Deletes the node pointed to by  list index or dict key
#
#  Returns:
#
#  OK                          - Dict keys(s) and value added sucessfully
#  [list ERR lpath <err_msg>]  - Where the first error happened.
#
proc core::json::_node_action {node_var ltail lcmd} {
	set fn {core::json::_node_action}
	upvar $node_var u_node

	#  Pre validation
	#  Look up the command
	lassign $lcmd cmd

	switch -- $cmd {
		set {
			if {[node_type [lindex $lcmd 1]] == "bad"} {
				return [list ERR {} "Node is not valid"]
			}
		}
		lappend {
			foreach l [lrange $lcmd 1 end] {
				if {[node_type $l] == "bad"} {
					return [list ERR {} "Node is not valid"]
				}
			}
		}
		unset {
			if {[llength $lcmd] != 2} {
				return [list ERR {} "wrong no of parameters - unset <key>"]
			}
		}
		default {
			error "$fn: unknown action '$cmd'"
		}
	}

	#  Currently all cmds take the node as the second arg


	#  Walk through the dict keys,
	#  Checking them if they exist, and creating them if they don't
	#  If we come up to a list item we cannot handle this within one
	#  situation via a single dict set / lset or similar function call.
	#  Instead we do a recursive call to this function and replace the node.

	#  Current key, basically the path interspaced with "val"
	set lcurrent_key  [list]
	#  The current path without the "val" elements - for error reporting mainly
	set lcurrent_path [list]

	set current_node {}
	foreach path $ltail {
		set current_node      [dict get $u_node {*}$lcurrent_key]
		set current_node_type [_node_type_fast $current_node]
		if {$current_node_type == "dict"} {
			#  Note current_node is a dict - Does the key exists?
			if {![dict exists $current_node val $path]} {
				#  Create a new node according to spec.
				foreach {status created_node } [_new_json_node dict [dict create]] {break}
				if {$status != "OK"} {
					# Should never be thrown
					error "core::json::_node_action: Unexpected error $created_node"
				}
				#  Create the dict key here
				dict set u_node {*}$lcurrent_key val $path $created_node
			}
			lappend lcurrent_key  val $path
			lappend lcurrent_path $path
		} elseif {$current_node_type == "list"} {
			# Break out of loop - we'll deal with this situation below.
			break
		} else {
			#  Bail out - we don't support anything else
			return [list ERR $lcurrent_path "Expecting a dict or list but found type $current_node_type"]
		}

	}
	#  Make sure we unset this to ensure the u_node
	#  is not shared, which would incurr an expensive copy
	#  operation when we copy it later on
	unset current_node

	#  If we get here we may have broken out of the foreach because we came across a node that was not a
	#  dict, or that we naturally finished the foreach
	#  We check for the latter case, and if a list we use recursion to replace the list item.
	set ltail_remaining [lrange $ltail [llength $lcurrent_path] end]

	if {[llength $ltail_remaining] != 0} {
		if {$current_node_type == "list"} {
			#  This is a list - therefore we can't set the value
			#  in-place using dict set
			#
			#  Instead we need to build a new list with the list item
			#  referenced by an index in ltail replaced by a recursive call to
			#  this proc

			set lval_path [list {*}$lcurrent_key val]

			set new_list [dict get $u_node {*}$lval_path]
			dict set u_node {*}$lval_path {}
			set index_exists 1
			#  Check we have a valid list index
			#  lindex returns "" if index does not exist :-(
			#  but lset throws an error
			if {[catch {
				set list_val [lindex $new_list $path]
				#  Replace the node we are going to change  in the list
				#  with a blank string. This will ensure this node
				#  only has one reference, so any modification would not incur an
				#  expensive copy operation
				lset new_list $path {}
			} msg]} {
				if {[regexp -- {^list index out of range} $msg]} {
					set index_exists 0
				} elseif {[regexp -- {^bad index} $msg]} {
					#  Catch the case where someone is trying to traverse a node of type index
					#  but is suppling an invalid 
					return [list BAD_INDEX $lcurrent_path "Node is a list, therefore path item must be  integer?\[+-\]integer? or end?\[+-\]integer?, got '$path'"]
				} else {
					return [list ERR $lcurrent_path "$msg"]
				}
			}

			#  What we are checking here is that the index $path in [lindex $new_list $path]
			#  is valid. If not lindex returns an empty string
			#
			#  Perf point
			#
			#  This condition used to be
			#  if {$list_val == {}}
			#
			#  But this was expensive if $list_val was a large node
			#  as it would be a dict and be converted into a string
			#  Replacing this with something that uses the native dict representation
			#  is mush quicker as it avoids the shimmering
			if {!$index_exists} {
				#  If we have a numerical index (i.e. not end-2)
				#  Then pad out to length using nulls
				if {[string is integer -strict $path]} {
					if {[llength $ltail_remaining] == 1} {
						#  We only add pad the list if this is the last
						#  index in the list - otherwise we
						#  error
						set list_length [llength $new_list]
						for {set i $list_length} {$i <= $path} {incr i} {
							lappend new_list [lindex [_new_json_node null {}] 1]
						}
						set list_val [lindex $new_list $path]
					} else {
						return [list ERR $lcurrent_path "List index $path is not at the end of a path and is out of bounds for the list length [llength $new_list]"]
					}
				} else {
					#  We can't pad to list indexes like end-1
					return [list ERR $lcurrent_path "List index $path is out of bound for the list length [llength $new_list]"]
				}
			}

			#  ltail_remaining includes the current list index
			#  so we exclude from the path we pass into the recursive call

			set lret [_node_action list_val [lrange $ltail_remaining 1 end] $lcmd]
			lassign $lret status err_path msg
			if {$status != "OK"} {
				return [list $status [concat $lcurrent_path $err_path] $msg]
			}
			#  Blank the reference to the list for the existing node
			#  before amending new_list
			#  This should reduce the reference count and  hopefully
			#  avoid TCL copying the list
			lset new_list $path $list_val
			dict set u_node {*}$lval_path $new_list
		} else {
			#  Should not get here
			error "current_node_type $current_node_type should be list"
		}
	} else {
		#  OK - we should now have a path
		#  DO the operation
		set current_key_len [llength $lcurrent_key]

		switch -- $cmd {
			set {
				lassign $lcmd cmd set_node
				if {[llength $lcurrent_key] == 0} {
					set u_node $set_node
				} else {
					dict set u_node {*}$lcurrent_key $set_node
				}
			}
			lappend {
				#  Check the target node is a list
				if {$current_key_len > 0} {
					set target_node      [dict get $u_node {*}$lcurrent_key]
					dict set u_node    {*}$lcurrent_key {}
				} else {
					set target_node      $u_node
					set u_node {}
				}
				set type             [_node_type_fast $target_node]

				if {$type != "list"} {
					return [list ERR $lcurrent_path "Target node for lappend needs to be a list, found $type"]
				}
				unset type
				set the_val [dict get $target_node val]
				dict set target_node val {}
				lappend the_val {*}[lrange $lcmd 1 end]
				dict set target_node val $the_val

				#  Now attach the node back
				if {$current_key_len > 0} {
					dict set u_node {*}$lcurrent_key $target_node
				} else {
					set u_node $target_node
				}
			}
			unset {
				#  unset takes 1 parameter - key
				lassign $lcmd cmd unset_key
				#  Check the target node is a list
				if { $current_key_len > 0} {
					set target_node      [dict get $u_node {*}$lcurrent_key]
				} else {
					set target_node       $u_node
				}
				set type             [_node_type_fast $target_node]

				switch -- $type {
					list {
						#  We need to unset the list index specified unset_key
						set the_list [dict get $target_node val]
						#  Replace the value in the dict to ensure the ref_count to $the_list
						#  remains at 1 and therefore avoids an expensive copy
						dict set u_node {*}$lcurrent_key val {}
						#  First check the list index is valid
						#  and the list index exists
						if {[catch {
							set list_element [lindex $the_list $unset_key ]
						} msg]} {
							if {[regexp -- {^bad index} $msg]} {
								#  Catch the case where someone is trying to traverse a node of type index
								#  but is suppling an invalid 
								return [list BAD_INDEX $lcurrent_path "Node is a list, therefore path item must be integer?\[+-\]integer? or end?\[+-\]integer?, got '$unset_key'"]
							} else {
								return [list ERR $lcurrent_path "$msg"]
							}
						}
						
						#  If list index is out of bounds, leave node unchanged and
						#  do not return an error.
						if {$list_element != ""} {
							#  Now delete the element
							set the_list [lreplace $the_list $unset_key $unset_key]
						}
						dict set u_node {*}$lcurrent_key val $the_list
						
					}
					dict {
						dict unset u_node {*}$lcurrent_key val $unset_key
					}
					default {
						return [list BAD_TYPE $lcurrent_path "Target node for unset needs to be a list, found $type"]
					}
				}
			}
		}
	}
	return [list "OK"]
}

#   Dumps a node to a string
#
#   Outputs a node -
#
#   prefix a string to prefix to each line
#
#  [list ERR lpath <err_msg>]  - Where the first error happened.
#
proc core::json::_dump_node {node indent} {

	set type [dict get $node type]
	set val  [dict get $node val]

	switch -- $type {
		num  {
			set out " \[num\] $val"
		}
		null {
			return "\[null\] null"
		}
		bool {
			return "\[bool\] [expr {$val ? true : false}]"
		}
		str {
			return " \[str\] \"$val\""
		}
		list {
			set i -1
			set out "\[list\]"
			set max_len [string length [expr {[llength $val] - 1}]]
			foreach l $val {
				incr i
				append out "\n"
				append out [format "%s%0${max_len}d %s" [string repeat " " $indent] $i [_dump_node $l [expr {$indent + $max_len + 1}]]]
			}
		}
		dict {
			set out "\[dict\]"
			set max_len 0
			foreach k [dict keys $val] {
				set len [string length $k]
				if {$len > $max_len} {set max_len $len}
			}
			foreach {k v} $val {
				append out "\n"
				append out [format "%s%${max_len}s: %s" [string repeat " " $indent] $k [_dump_node $v [expr {$indent + $max_len + 1}] ]]
			}
		}
		default {
			append out "\[...other $type ...\]\n"
			append out $val
		}
	}
	return $out
}


# Converts a node to a natural TCL representation:
# a TCL list or dict or simple var representing the node value
# without any type information
proc core::json::_strip_node {node} {

	set type [dict get $node type]
	set val  [dict get $node val]

	switch -- $type {
		bool {
			set out [expr {$val ? 1 : 0}]
		}
		str -
		num {
			set out $val
		}
		list {
			set out [list]
			foreach list_item $val {
				lappend out [_strip_node $list_item]
			}
		}
		dict {
			set out [dict create]
			foreach {k v} $val {
				dict set out $k [_strip_node $v]
			}
		}
		null -
		default {
			return {}
		}
	}

	return $out
}

############################################################################################################################################
#
#     YAJL private funcitona - yajl and tcl yajl libraries for parsing and generating JSON Strings
#
############################################################################################################################################


#  Returns the current instance of yajl, creating it
 #  if this is the first call.
 #
 #  This is needed as the current version of yajltcl 1.3 has a bug where
 #  <jajl> free
 #  seems to be a no-op (??), so we need to reuse
 #  the current instance rather than repeadly calling yajl create
 #  to avoid memory leaks
 #  We need different instances for beuatified and non-beautified
 #  ones
 proc core::json::_get_yajl_instance {{beautify 0}} {
	variable YAJL_INSTANCE_CREATED

	if {$beautify} {
		set yajl_proc_name YAJL_INSTANCE_BEAUTIFY
	} else {
		set yajl_proc_name YAJL_INSTANCE
	}

	set ns [namespace current]

	if {[info exists YAJL_INSTANCE_CREATED($yajl_proc_name)]} {
		$yajl_proc_name reset
	} else {
		yajl create ${ns}::${yajl_proc_name} -beautify $beautify
		set YAJL_INSTANCE_CREATED($yajl_proc_name) 1
	}
	return $yajl_proc_name
 }
		 

#  POS point to the array_open element
#  returns to the list iten after the array_close
#  element
proc core::json::_parse_yajl_list  {lcmd pos_var} {
	upvar pos $pos_var
	if {[lindex $lcmd $pos] != "array_open"} {
		error "Not an array"
	}
	set lret [list]
	incr pos

	while {true} {
		set val [lindex $lcmd $pos]
		if {$val == "array_close"} {
			incr pos
			break
		}
		set val [_parse_yajl_val $lcmd pos]
		lappend lret $val
	}
	return $lret
}



#  POS point to the array_open element
#  when function returns it points to the 
#  list element after the array_close.
#
proc core::json::_parse_yajl_dict {lcmd pos_var} {
	upvar pos $pos_var

	if {[lindex $lcmd $pos] != "map_open"} {
		error "Not a map"
	}

	incr pos
	set dret [dict create]
	while {true} {
	
		set cmd [lindex $lcmd $pos]
		incr pos

		if {$cmd == "map_close"} { 
			break
		} elseif {$cmd != "map_key"} {
			error "core::json::_parse_yajl_dict: Expecting map_key, got $cmd"
		}

		set key [lindex $lcmd $pos]
		incr pos 
		#  Val should leave pos pointing at the element
		#  after array close
		set val [_parse_yajl_val $lcmd pos]
		dict set dret $key $val
	}
	return $dret
}



#  Processes a node in the json token list
#  returned from the yajltcl command
#  <yajldoc> parse <json_str>
#  
#  This should be called first or whenever a JSON value is
#  expected in the document (e.g. a list item, or the value in an dict (JSON obj)
#  Returns a JSON Node, see the top of the file for the structure.
#
proc core::json::_parse_yajl_val {lcmd pos_var} {
	upvar $pos_var pos

	#  Will make use of recursion
	#  For speed we build the JSON node directly 
	#  rather than calling json::new_dict etc.....
	#  See top of file for the JSON Node data structure
	#
	set val [lindex $lcmd $pos]
	switch -- $val {
		null {
			incr pos
			set type null
			set val {}
		}
		string {
			incr pos
			set val [lindex $lcmd $pos]
			incr pos
			set type str
			set val  $val
		}
		integer  -
		double   -
		number {
			incr pos
			set val [lindex $lcmd $pos]
			incr pos
			set type num
			set val $val
		}
		bool {
			incr pos
			set val [lindex $lcmd $pos]
			incr pos
			set type bool
			set val $val
		}
		map_open {
			#  map_open = start of JSON dict/obj
			set type dict
			set val [_parse_yajl_dict $lcmd pos]
		}
		array_open {
			#  array_open = start of JSON list/array
			set type list
			set val [_parse_yajl_list  $lcmd pos]
		}
		default {
			error "Not expecting $val"
		}
	}
	return [dict create type $type val $val] 
}


#   Generates the yajl commands
#   for passing to yalg generate
#   for a dict
# 
#   data - Dict of JSON nodes
#
#   Returns:
#    list of yajl commands 
proc core::json::_generate_yajl_dict {data} {
	set lret [list]
	lappend lret map_open

	foreach  {key val} $data {
		lappend lret map_key $key
		lappend lret {*}[_generate_yajl $val]
	}
	lappend lret map_close

	return $lret
}

#   Generates the yajl commands
#   for passing to yajl generate
#   for all JSON nodes in the 
#   list
# 
#   dval - Dict of JSON nodes
#
#   Returns:
#    list of yajl commands
#
proc core::json::_generate_yajl_list  {dval} {

	lappend lret array_open
	
	foreach val $dval {
		lappend lret {*}[_generate_yajl ${val}]
	}
	lappend lret array_close

	return $lret
}


#   Generates the yajl commands
#   for passing to [yall generate]
#   for a JSON node
#
#   data   - JSON node
#
#   Returns:
#    list of yajl commands
#
proc core::json::_generate_yajl {data} {

	set type [dict get $data type]
	set val  [dict get $data val]

	set indent_delta "  "

	switch -- $type {
		dict {
			return     [_generate_yajl_dict $val]
		}
		list {
			return     [_generate_yajl_list  $val]
		}
		null {
			return [list null]
		}
		str {
			return [list string $val]
		}
		bool {
			return [list bool $val]
		}
		num {
			return [list number $val]
		}
		default {
			error "Invalid type $type"
		}
	}
}

proc core::json::_rs2json_type {type is_null} {

	if {$is_null} {
		return null
	}
	set ret ""

	switch -- $type {
		int     -
		numeric {set ret num}
		bool    {set ret bool}
		string  -
		default {set ret str} 
	}
	return $ret
}

#  Wrapper proc as there is a bug in this call
#
#
proc get_llength {} {
	

}

#   Private proc to output an rs as 
#   a JSON
#   If no key_col, then a list of dicts, 
#   IF a key_col is specified, then a dict of dicts
#
#   The list being the 
#
#   rs      -  Results set
#   lcol    -  Cols to output - blank means all cols
#   key_col -  Specifies a key to key the output JSON. This key must not be duplicated
#              or there will be an error
proc core::json::_rs_to_flat {rs lcol {key_col {}}} {
	set fn {core::json::_rs_to_flat}
	set nrow [db_get_nrows $rs]
	set ncol [db_get_ncols $rs]

	#  Note we iterate up to nrows + q
	#  This is intentional - so we can handle the 
	#  last row more elegantly
	
	set lcol_name [list]
	set lcol_type [list]

	array set db_cols [list]
	for {set col 0} {$col < $ncol} {incr col} {
		lappend lcol_name [db_get_colname $rs $col]
		lappend lcol_type [db_get_coltype $rs $col]
		set db_cols([db_get_colname $rs $col]) [db_get_coltype $rs $col]
	}

	set colnames [list]

	if {$lcol != {}} {
		foreach {c t} $lcol {
			if {$c ni $lcol_name} {
				error "$fn: $col not found in results set $lcol_name"
			}
			lappend colnames $c
			set db_cols($c) $t
		}
	}

	if {$lcol == {}} {
		foreach c $lcol_name t $lcol_type {
			lappend lcol $c $t
			lappend colnames $c
			set db_cols($c) $t
		}
	}

	set lnode [list]
	for {set row 0} {$row < $nrow} {incr row} {
		set drow_node [dict create]
		for {set col 0} {$col < $ncol} {incr col} {
			set col_name [lindex $lcol_name $col]
			set col_type $db_cols($col_name)


			set node {}
			if {$col_name in $colnames} {
				lassign [db_get_col $rs -nullind $row $col_name] val null
				set type [_rs2json_type $col_type $null]
				lassign [_new_json_node $type $val] status node
				if {$status != "OK"} {
					error "$fn: Error $status creating node $node"
				}
				dict set drow_node $col_name $node
			}
		}
		lassign [_new_json_node dict $drow_node] status row_node
		if {$status != "OK"} {
			error "$fn: Error $status creating row $row_node"
		}
		
		lappend lnode $row_node
	}
	lassign [_new_json_node list $lnode] status ret_node
	if {$status != "OK"} {
		error "$fn: Error $status creating row $ret_node"
	}
	return $ret_node
}


#  Private proc to do the heavy lifting
#
#   spec     - The List of key column(s) and rows to return
#             for this results set
#              
#                   name  dspec 
#                   name  dspec
#       where dspec has keys
#
#            lkey_col - This is the list of key_columns that are watched 
#                       and determine whether the level has changed for this
#                       row
#            lcol     - The list of columns output - note this does not automatically
#                       include any cols from lkey_col unless explicitly specified
#            out_type - list|dict 
#                       output type, List or Dict
#                       Dicts are keyed on the key_cols
#
#
proc core::json::_rs_to_hierarchy {rs spec} {
	set fn {core::json::_rs_to_hierarchy}
	# We are passed in the spec, which is list of levels.
	# Each level has a list of key columns, and a list of output columns. 
	# 
	# The general strategy is that we 
	#  a) Store the current values of the key column(s) for each level  
	#  b) Accumulate a list of all values at each level in variables.
	#
	#  If at a specified level we identify that the key column changes, then we
	#  stash the current values at this level and accumulated values at lower levels
	set i -1
	
	array set avals [list]

	set ncol [db_get_ncols $rs]

	array set db_cols [list]
	for {set col 0} {$col < $ncol} {incr col} {
		set db_cols([db_get_colname $rs $col]) [db_get_coltype $rs $col]
	}
	
	# Convert list to dict for speed
	set ddspec [dict create]
	set j -1
	foreach {name dlevel_spec} $spec {
		incr j
		
		#  Holds the previous id,
		#  to check whether they change
		
		dict set ddspec $j $dlevel_spec
		dict set ddspec $j name $name

		
		#  Initalise the array that 
		#  holds the previous accumulated
		#  hierarchy at this level
		switch -exact -- [dict get $dlevel_spec out_type] {
			{list}	{
				set a_prev($j)  [list]
			}
			{dict}	{
				set a_prev($j)  [dict create]
			}
			default {
				error "$fn: out_type must be list of dict"
			}
		}
	}

	set nlevel_minus_1 $j
	set nlevel [expr {$j + 1}]

	set nrows [db_get_nrows $rs]
	
	
	
	#  Note, the level here are the 'wrong way' round from what you would expect:
	#  starts at index 0 for the highest level in the hierarchy
	#  and increases for each level.
	#  e.g. for a query joining from event to market and selection, the levels are 
	#  0 - Event      - Highest Level
	#  1 - Market
	#  2 - Selection  - Lowest Level

	#  Note we iterate up to nrows + 1
	#  This is intentional - so we can handle the 
	#  last row more elegantly
	for {set i 0} {$i < $nrows + 1} {incr i} {

		if {$i > 0} {
		
			# Works work out the highest level that has changed
			
			# if they have then add the accumulated rows from the 
			# lower levels to this level

			if {$i >= $nrows} {
				#  This catches when we pass the end of the results set
				#  Assume we have a change at the first/highest level
				#  To ensure the remaining data is added to the return set
				set change_level 0
			} else {
				set change_level ""
				for {set j 0} {$j < $nlevel} {incr j} {
					set lid_col    [dict get $ddspec $j lkey_col]
					set diff       0
					foreach id_col $lid_col {
						set curr_val   [db_get_col $rs $i              $id_col]
						set prev_val   [db_get_col $rs [expr {$i - 1}] $id_col]
						if {$curr_val != $prev_val} {
							set diff 1
						}
					}
					if {$diff} {
						set change_level $j
						break
					}
				}
			}
			if {$change_level != ""} {
				#  Now work down from the lowest level (highest index)
				#  to the level that has changed 
				#  and lappend each level to the
				#  level above
				#  and blank the current level
				#  Note we add the previous rows values
				#  This is OK as we know i > 0
				for {set k $nlevel_minus_1} {$k >= $change_level} {incr k -1} {
					
					set drow_node [dict create]
					set empty_level 1

					#  Also build up the key values for out_type = dict
					set lkey_val [list]
					foreach c [dict get $ddspec $k lkey_col] {
						lassign [db_get_col $rs -nullind [expr {$i - 1}] $c] key_val key_null
						lappend lkey_val $key_val
						if {!$key_null} {set empty_level 0}
					}

					if {!$empty_level} {
						# Expecting the lcol spec to be a list in the form
						# {-colname e_desc -colalias desc}
						# {-colname ev_id -coltype int}
						# where only -colname is mandatory, the rest is optional
						foreach c [dict get $ddspec $k lcol] {
							array unset colopt
							array set colopt $c
							set colname  $colopt(-colname)
							set coltype  $db_cols($colname)
							set colalias $colname
							set colcmd   [list]
							if {[info exists colopt(-coltype)]}  {set coltype  $colopt(-coltype)}
							if {[info exists colopt(-colalias)]} {set colalias $colopt(-colalias)}
							if {[info exists colopt(-colcmd)]}   {set colcmd   $colopt(-colcmd)}
							lassign [db_get_col $rs -nullind [expr {$i - 1}] $colname] val null
							if {[llength $colcmd]} {
								set val [eval [lappend colcmd $val]]
							}
							set jsontype [_rs2json_type $coltype $null]
							lassign [_new_json_node $jsontype $val] status col_node
							if {$status != "OK"} {error "$fn: Error $status creating node $col_node"}
							dict set drow_node $colalias $col_node
						}
					}

					#  This checks for the lowest level 
					if {$k == $nlevel_minus_1} {
						#  If all the values AND keys are null, we do not add a row at all, as this 
						#  results from an outer join and we do not want include any rows for this 
						if {!$empty_level} {
							lassign [_new_json_node dict $drow_node] status row_node
							if {$status != "OK"} {error "$fn: Error $status creating row_node $row_node"}
							switch -exact -- [dict get $ddspec $k out_type] {
								{list} {
									lappend a_prev($k) $row_node
								}
								{dict} {
									#  Define the key - join by commas for > 1 lkey
									dict set a_prev($k) [join $lkey_val {,}]  $row_node
								}
								default {error {Should never be reached}}
							}
						}
					} else {
						#  Pull all the values from the row below
						#  and blank that row
						set k_plus [expr {$k + 1}]
						set child_name   [dict get $ddspec $k_plus name]

						#  add the lower levels as a dict element to this level
						lassign [_new_json_node [dict get $ddspec $k_plus out_type] $a_prev($k_plus)] status child_node
						if {$status != "OK"} {error "$fn: Error $status creating child_node $child_node"}
						dict set drow_node $child_name $child_node
						lassign [_new_json_node dict $drow_node] status row_node
						if {$status != "OK"} {error "$fn: Error $status creating row_node $row_node"}

						switch -exact -- [dict get $ddspec $k out_type] {
							{list} {
								if {!$empty_level} {
									lappend a_prev($k) $row_node
								}
								set a_prev($k_plus)  [list]
							}
							{dict} {
								#  Define the key - join by commas for > 1 lkey
								if {!$empty_level} {
									dict set a_prev($k) [join $lkey_val {,}] $row_node
								}
								set a_prev($k_plus)  [dict create]
							}
						}
						
					}
				}
			}
		}
	}

	set root_out_type [dict get $ddspec 0 out_type]
	set ret [_new_json_node $root_out_type $a_prev(0)]

	return [lindex $ret 1]
}




