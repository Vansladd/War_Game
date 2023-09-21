# ==============================================================
# $Id: shortcut.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Copyright (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================
 
namespace eval ADMIN::AUTOGEN::SHORTCUT {

proc shortcut {mkt_sort args} {

	switch -- $mkt_sort {
		CS {
			set result [lindex $args 0]
			set sort   [lindex $args 1]
			set cs_h   [lindex $args 2]
			set cs_a   [lindex $args 3]

			return [shortcut_CS $result $sort $cs_h $cs_a]
		}
		HF {
			return [shortcut_HF [lindex $args 0]]
		}
		OU {
			return [shortcut_OU [lindex $args 0]]
		}
		MR {
		}
	}
	return ""
}

proc shortcut_CS {result sort cs_h cs_a} {

	if {$sort == "S"} {

		set s "$cs_h$cs_a"

		switch -- $s {
			10 { return "01" }
			20 { return "02" }
			21 { return "03" }
			21 { return "04" }
			31 { return "05" }
			32 { return "06" }
			40 { return "07" }
			41 { return "08" }
			42 { return "09" }
			43 { return "10" }

			01 { return "11" }
			02 { return "12" }
			12 { return "13" }
			03 { return "14" }
			13 { return "15" }
			23 { return "16" }
			04 { return "17" }
			14 { return "18" }
			24 { return "19" }
			34 { return "20" }

			00 { return "21" }
			11 { return "22" }
			22 { return "23" }
			33 { return "24" }
			44 { return "25" }
		}

	} elseif {$sort == "N"} {

		if {$result == "H"} {
			if {$cs_h == "3"} { return "26" }
			if {$cs_h == "4"} { return "27" }
			if {$cs_h == "5"} { return "28" }
		} elseif {$result == "A"} {
			if {$cs_h == "3"} { return "29" }
			if {$cs_h == "4"} { return "30" }
			if {$cs_h == "5"} { return "31" }
		}

	}

	return ""
}

proc shortcut_HF {result} {

	switch -- $result {
		1 { return "32" }
		2 { return "33" }
		3 { return "34" }
		4 { return "35" }
		5 { return "36" }
		6 { return "37" }
		7 { return "38" }
		8 { return "39" }
		9 { return "40" }
	}
	return ""
}

proc shortcut_OU {result} {

	switch -- $result {
		O { return "41" }
		U { return "42" }
		H { return "43" }
		A { return "44" }
		h { return "45" }
		a { return "46" }
	}
}

}
