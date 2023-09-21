# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Backwards compatibility code for internal core::db usage
#
set pkgVersion 1.0
package provide core::db $pkgVersion

# Variables
namespace eval core::db {
	variable CFG

	# Set this outside init so other packages can use it
	# without initialising core::db
	if {[info exists ::admin_screens]} {
		set CFG(admin) $::admin_screens
	} else {
		set CFG(admin) 0
	}
}

# Init and connect are combined in the old packages
# therefore we should only init when we connect
proc core::db::init args {

	variable CFG

	# Dependencies
	package require util_db

	if {[lindex [info args ob_db::store_qry] end] == {args}} {
		set CFG(store_qry_nv_params) 1
	} else {
		set CFG(store_qry_nv_params) 0
	}
}

# Initialise the connection
proc core::db::connect args {
	ob_db::init

	core::log::write DEBUG {Connected using ob_db::init}
}

# Provide all calls internally used by core only
proc core::db::store_qry args {

	variable CFG

	array set ARGS $args

	# Check and Set mandatory parameters
	if {![info exists ARGS(-name)] || ![info exists ARGS(-qry)]} {
		core::log::write ERROR {Failed to validate store_qry args - $args}
		error {Failed to validate store_qry args}
	}

	set name $ARGS(-name)
	set qry  $ARGS(-qry)

	# Check and set optional args
	set cache          0
	set connections    {}
	set nv_params      [list]

	foreach {n v} $args {
		switch -exact -- $n {
			-cache -
			-connections {
				set n [string trimleft $n {-}]
				set $n $v
			}
			-force -
			-allow_expired -
			-extend_expired {
				lappend nv_params $n $v
			}
		}
	}

	if {$CFG(admin)} {
		set params [list $name $qry $cache]
	} else {

		set params [list $name $qry $cache $connections]

		# Only append the nv_params if implementation of ob_db::store_qry
		# has 'args' param and there are nv_params to append
		if {$CFG(store_qry_nv_params) && $nv_params != {}} {
			lappend params {*}$nv_params
		}

	}

	ob_db::store_qry {*}$params

	core::log::write DEBUG {Stored $name}
}

proc core::db::exec_qry args {

	variable CFG

	array set ARGS $args

	set arg_list {}
	if {[info exists ARGS(-args)]} {
		set arg_list $ARGS(-args)
	}

	return [ob_db::exec_qry \
		$ARGS(-name) \
		{*}$arg_list]
}

proc core::db::rs_close args {

	variable CFG

	array set ARGS $args

	set conn_name {}
	set params    [list $ARGS(-rs)]

	if {[info exists ARGS(-conn_name)]} {
		set conn_name $ARGS(-conn_name)
	}

	if {!$CFG(admin)} {
		lappend params $conn_name
	}

	ob_db::rs_close {*}$params
}

# Get the number of rows affected by the last statement
#
# @param -conn_name  Unique name which identifies the connection
# @param -name       Named SQL query
# @return            Number of rows affected by the last statement
#
proc core::db::garc args {
	variable CFG

	array set ARGS $args

	set params    [list $ARGS(-name)]

	if {!$CFG(admin) && [info exists ARGS(-conn_name)]} {
		lappend params $ARGS(-conn_name)
	}

	return [ob_db::garc {*}$params]
}

proc core::db::begin_tran args {
	variable IN_TRAN

	array set ARGS $args

	set conn_name [expr {[info exists ARGS(-conn_name)] ? $ARGS(-conn_name) : {}}]

	ob_db::begin_tran $conn_name

	set IN_TRAN($conn_name) 1
}

proc core::db::rollback_tran args {
	variable IN_TRAN

	array set ARGS $args

	set conn_name [expr {[info exists ARGS(-conn_name)] ? $ARGS(-conn_name) : {}}]

	ob_db::rollback_tran $conn_name

	catch {unset IN_TRAN($conn_name)}
}

proc core::db::commit_tran args {
    variable IN_TRAN

    array set ARGS $args

    set conn_name [expr {[info exists ARGS(-conn_name)] ? $ARGS(-conn_name) : {}}]

    ob_db::commit_tran $conn_name

    catch {unset IN_TRAN($conn_name)}
}

proc core::db::in_tran args {
    variable IN_TRAN

    array set ARGS $args

    set conn_name [expr {[info exists ARGS(-conn_name)] ? $ARGS(-conn_name) : {}}]

    if {[info exists IN_TRAN($conn_name)]} {
		return 1
	}

	return 0
}

proc core::db::invalidate_cached_rs args {
	array set ARGS $args

	ob_db::invalidate_cached_rs $ARGS(-name) {*}$ARGS(-args)
}

proc core::db::req_end args {
	ob_db::req_end {*}$args
}

proc core::db::get_serial_number args {
	array set ARGS $args

	ob_db::get_serial_number $ARGS(-name)
}
