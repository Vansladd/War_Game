# $Id: config.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================



namespace eval OB_config {

namespace export OT_CfgGet
namespace export OT_CfgGetTrue

variable  CFG
array set CFG [list]


proc OT_CfgSet {key val} {
	variable CFG

	set CFG($key) $val
}


# --------------------------------------------
# we overide the config functions in order
# to add local config specific to this project
# ---------------------------------------------

rename OT_CfgGet real_OT_CfgGet

proc OT_CfgGet {key {dflt __DEFAULT_STRING__}} {
	variable CFG


	if [info exists CFG($key)] {
		return $CFG($key)
	}

	if {$dflt == "__DEFAULT_STRING__"} {
		return [real_OT_CfgGet $key]
	} else {
		return [real_OT_CfgGet $key $dflt]
	}
}

rename OT_CfgGetTrue real_OT_CfgGetTrue

proc OT_CfgGetTrue {key} {

	variable CFG

	if {[info exists CFG($key)]} {
		if {$CFG($key) == 1} {
			return 1
		} else {
			return 0
		}
	}

	return [real_OT_CfgGetTrue $key]

}
}

