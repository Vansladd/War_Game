# $Id: app_control.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
#
# ---------------------
# app_control
# ---------------------
# Desc:
#   ....
#
# Config Items:
#    CONTROL_DEFAULTS
#       - Defaults which you want to persists across multiple requests.
#
# Procs:
#    Public:
#      app_control::init
#      app_control::set_val
#      app_control::get_val
#      app_control::del_val
#        - Must be called before you can reset a value, this prevents
#          variables mistakingly being overidden.
#      app_control::clean_up
#        - Should be called at the end of every request.
#    Private:
#      app_control::_restore_defaults
#        - Restores the details as set in the cfg.
#
#
#

package provide util_appcontrol 1.0

namespace eval app_control {
	variable CONTROL
	variable CONTROL_DEFAULTS
}

# scope   : public
# params  : n/a
# returns : n/a
#
proc app_control::init args {

	variable CONTROL_DEFAULTS

	set c_default [OT_CfgGet CONTROL_DEFAULTS [list]]

	foreach item $c_default {
		set id      [lindex $item 0]
		set value   [lindex $item 1]
		set default [expr {[lindex $item 2] == 1 ? 1 : 0}]

		set CONTROL_DEFAULTS($id) $value
		set CONTROL_DEFAULTS($id,persistDefault) $default
	}


	_restore_defaults

}

#
# scope   : private
# params  : id - Id of the refering value
#           ignore_persistance - whether to treat a default value as a value.
# returns : (1) has value (0) no value
# desc    : returns a value if one exists.
#
proc app_control::_has_value {id {ignore_persistance 0}} {
	variable CONTROL

	if { \
		$ignore_persistance \
		&& ([info exists CONTROL($id)] && !$CONTROL($id,persistDefault)) \
	} {
		return 0
	} elseif {![info exists CONTROL($id)]} {
		return 0
	} else {
		return 1
	}
}

#
# scope   : private
# params  : n/a
# returns : n/a
# desc    : restore the default values.
#
proc app_control::_restore_defaults args {
	variable CONTROL
	variable CONTROL_DEFAULTS

	# Restore the array.
	array set CONTROL [array get CONTROL_DEFAULTS]
}

#
# scope   : public
# params  : id -
#           value - value to be associated with the id.
# returns : n/a
# desc    : sets a {name value} pair.
#
proc app_control::set_val {id value} {
	variable CONTROL

	if {[_has_value $id 1]} {
		error [subst {Id:$id already exists.}]
	} else {
		set CONTROL($id) $value
	}
}

#
# scope   : public
# params  : id -
# returns : value assosiated with the id.
# desc    : returns a value for a given name.
#
proc app_control::get_val {id} {
	variable CONTROL

	if {[_has_value $id]} {
		return $CONTROL($id)
	} else {
		error [subst {Id:$id doesn't exist.}]
	}
}

#
# scope   : public
# params  : id -
# returns : n/a
# desc    : deletes a {id value} pair.
#
proc app_control::del_val {id} {
	variable CONTROL

	if {[_has_value $id]} {
		unset CONTROL($id)
	}
}

#
# scope   : public
# params  : n/a
# returns : n/a
# desc    : to be called at the end of a request.
#
proc app_control::clean_up {} {
	variable CONTROL
	unset CONTROL
	_restore_defaults
}

app_control::init
