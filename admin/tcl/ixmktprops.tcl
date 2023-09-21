# ==============================================================
# $Id: ixmktprops.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IXMKTPROPS {


#
# ----------------------------------------------------------------------------
# Access functions to get market information
# ----------------------------------------------------------------------------
#
proc mkt_class_sort_idx {class_sort} {

	if {[info exists ::MKT_IX(class_sort,$class_sort)]} {
		return $::MKT_IX(class_sort,$class_sort)
	}
	return -1
}

proc mkt_sorts {class_sort} {

	global MKT_IX

	if {[set ci [mkt_class_sort_idx $class_sort]] >= 0} {
		return $MKT_IX($ci,sorts)
	}
	return [list]
}

proc mkt_flag {class_sort mkt_sort flag {dflt ""}} {

	global MKT_IX

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return $dflt
	}
	if {[set mi [lsearch $MKT_IX($ci,sorts) $mkt_sort]] < 0} {
		return $dflt
	}

	array set X [mkt_sort_info $class_sort $mkt_sort]

	if {[info exists X($flag)]} {
		return $X($flag)
	}
	return $dflt
}

proc mkt_sort_info {class_sort mkt_sort} {

	global MKT_IX

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return [list]
	}
	if {[set mi [lsearch $MKT_IX($ci,sorts) $mkt_sort]] < 0} {
		return [list]
	}

	set l [list]

	lappend l sort $MKT_IX($ci,$mi,sort)

	foreach f $MKT_IX(fields) {
		lappend l $f $MKT_IX($ci,$mi,$f)
	}

	return $l
}

proc mkt_type {class_sort mkt_sort} {

	global MKT_IX

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return [list]
	}
	if {[set mi [lsearch $MKT_IX($ci,sorts) $mkt_sort]] < 0} {
		return [list]
	}

	return $MKT_IX($ci,$mi,type)
}

proc make_mkt_binds {class_sort} {

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		tpSetVar NumMIxMkts 0
		return
	}

	tpSetVar mixcs_idx $ci

	tpBindVar MIxMktSort ::MKT_IX sort mixcs_idx mix_idx
	tpBindVar MIxMktName ::MKT_IX name mixcs_idx mix_idx

	tpSetVar NumMIxMkts $::MKT_IX($ci,num_mkts)
}



#
# ----------------------------------------------------------------------------
# Read standard market properties
# ----------------------------------------------------------------------------
#
proc read_index_market_props {} {

	global MKT_IX

	if {[info exists MKT_IX(fields)]} {
		return
	}

	set fields [string map {" " ""} [OT_CfgGet index.fields]]

	set MKT_IX(fields)     [split $fields ,]
	set MKT_IX(class_sort) [list]

	set ci 0

	foreach c [split [OT_CfgGet index.classes [list]] ,] {

		lappend MKT_IX(class_sort) $c

		set MKT_IX(class_sort,$c) $ci
		set MKT_IX($ci,num_mkts)  0
		set MKT_IX($ci,sorts)     [list]

		set mi 0

		foreach m [split [OT_CfgGet index.$c.sorts [list]] ,] {

			set MKT_IX($ci,$m) $mi

			lappend MKT_IX($ci,sorts) [set MKT_IX($ci,$mi,sort) $m]

			foreach f $MKT_IX(fields) {
				set MKT_IX($ci,$mi,$f) [OT_CfgGet index.$c.$m.$f ""]
			}

			incr MKT_IX($ci,num_mkts)

			incr mi
		}

		incr ci
	}

	set MKT_IX(done) 1
}

read_index_market_props

}
