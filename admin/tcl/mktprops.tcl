# ==============================================================
# $Id: mktprops.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::MKTPROPS {


#
# ----------------------------------------------------------------------------
# Decode config file market type descriptions into char(1) values acceptable
# to tEvMkt.type
# ----------------------------------------------------------------------------
#
proc mkt_type_decode {type} {

	switch -- $type {
		handicap   { return H }
		asian      { return A }
		spread     { return S }
		scorecast  { return C }
		overunder  { return U }
		hilo       { return L }
		hilo-split { return l }
		bir        { return N }
		handicap3  { return M }
		standard   -
		default    { return - }
	}
}


#
# ----------------------------------------------------------------------------
# Access functions to get market information
# ----------------------------------------------------------------------------
#
proc mkt_class_sort_idx {class_sort} {

	global MKT_STD

	if {[info exists MKT_STD(class_sort,$class_sort)]} {
		return $MKT_STD(class_sort,$class_sort)
	}
	return -1
}

proc class_sorts {} {

	global MKT_STD

	set res [list]

	foreach cs $MKT_STD(class_sort) {

		set ci $MKT_STD(class_sort,$cs)

		lappend res $cs
		lappend res $MKT_STD($ci,sort_name)
	}

	return $res
}

proc class_flag {class_sort flag {dflt ""}} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return $dflt
	}

	array set X $MKT_STD($ci,nv)

	if {[info exists X($flag)]} {
		return $X($flag)
	}
	return $dflt
}

proc mkt_sorts {class_sort} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] >= 0} {
		return $MKT_STD($ci,sorts)
	}
	return [list]
}

proc mkt_flag {class_sort mkt_sort flag {dflt ""}} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return $dflt
	}
	if {[set mi [lsearch $MKT_STD($ci,sorts) $mkt_sort]] < 0} {
		return $dflt
	}

	array set X [mkt_sort_info $class_sort $mkt_sort]

	if {[info exists X($flag)]} {
		return $X($flag)
	}
	return $dflt
}

proc seln_flag {class_sort mkt_sort seln_sort flag {dflt ""}} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return $dflt
	}
	if {[set mi [lsearch $MKT_STD($ci,sorts) $mkt_sort]] < 0} {
		return $dflt
	}
	if {[set si [lsearch $MKT_STD($ci,$mi,fb_result) $seln_sort]] < 0} {
		return $dflt
	}

	set s [list]

	lappend s desc      $MKT_STD($ci,$mi,$si,desc)
	lappend s fb_result $MKT_STD($ci,$mi,$si,fb_result)

	foreach {n v} $MKT_STD($ci,$mi,$si,nv) {
		lappend s $n $v
	}

	array set X $s

	if {[info exists X($flag)]} {
		return $X($flag)
	}
	return $dflt
}

proc mkt_sort_info {class_sort mkt_sort} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return [list]
	}
	if {[set mi [lsearch $MKT_STD($ci,sorts) $mkt_sort]] < 0} {
		return [list]
	}

	set l [list]

	lappend l type $MKT_STD($ci,$mi,type)
	lappend l sort $MKT_STD($ci,$mi,sort)
	lappend l desc $MKT_STD($ci,$mi,desc)

	foreach {n v} $MKT_STD($ci,$mi,nv) {
		lappend l $n $v
	}

	return $l
}

proc mkt_type {class_sort mkt_sort} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return [list]
	}
	if {[set mi [lsearch $MKT_STD($ci,sorts) $mkt_sort]] < 0} {
		return [list]
	}

	return $MKT_STD($ci,$mi,type)
}

proc mkt_seln_info {class_sort mkt_sort} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		return [list]
	}
	if {[set mi [lsearch $MKT_STD($ci,sorts) $mkt_sort]] < 0} {
		return [list]
	}

	set l [list]

	for {set si 0} {$si < $MKT_STD($ci,$mi,num_selns)} {incr si} {

		set s [list]

		lappend s desc      $MKT_STD($ci,$mi,$si,desc)
		lappend s fb_result $MKT_STD($ci,$mi,$si,fb_result)

		foreach {n v} $MKT_STD($ci,$mi,$si,nv) {
			lappend s $n $v
		}

		lappend l $s
	}

	return $l
}

proc make_mkt_binds {class_sort} {

	global MKT_STD

	if {[set ci [mkt_class_sort_idx $class_sort]] < 0} {
		tpSetVar NumMMkts 0
		return
	}

	tpSetVar mmcs_idx $ci

	tpBindVar MMktCode MKT_STD sort mmcs_idx mmkt_idx
	tpBindVar MMktDesc MKT_STD desc mmcs_idx mmkt_idx

	tpSetVar NumMMkts $MKT_STD($ci,num_mkts)
}



#
# ----------------------------------------------------------------------------
# Read standard market properties
# ----------------------------------------------------------------------------
#
proc read_standard_market_props {} {

	global MKT_STD

	if {[info exists MKT_STD(done)]} {
		return
	}

	set MKT_STD(class_sort) [list]

	set ci 0

	foreach c [OT_CfgGet MARKET_PROPERTIES] {

		set c_info [lindex $c 0]

		set c_sort      [lindex $c_info 0]
		set c_sort_name [lindex $c_info 1]
		set c_sort_nv   [lrange $c_info 2 end]

		lappend MKT_STD(class_sort) $c_sort

		set MKT_STD(class_sort,$c_sort) $ci
		set MKT_STD($ci,sort_name)      $c_sort_name
		set MKT_STD($ci,num_mkts)       0
		set MKT_STD($ci,nv)             $c_sort_nv
		set MKT_STD($ci,sorts)          [list]

		set mi 0

		foreach m [lrange $c 1 end] {


			set mkt [lindex $m 0]

			set mkt_sort [lindex $mkt 0]
			set mkt_type [lindex $mkt 1]
			set mkt_name [lindex $mkt 2]
			set mkt_nv   [lrange $mkt 3 end]

			set MKT_STD($ci,$mkt_sort) $mi

			lappend MKT_STD($ci,sorts) $mkt_sort

			set MKT_STD($ci,$mi,sort)      $mkt_sort
			set MKT_STD($ci,$mi,type)      [mkt_type_decode $mkt_type]
			set MKT_STD($ci,$mi,desc)      $mkt_name
			set MKT_STD($ci,$mi,nv)        $mkt_nv
			set MKT_STD($ci,$mi,num_selns) 0
			set MKT_STD($ci,$mi,fb_result) [list]

			incr MKT_STD($ci,num_mkts)

			set si 0

			#
			# For each selection
			#
			foreach s [lrange $m 1 end] {

				set desc      [lindex $s 0]
				set fb_result [lindex $s 1]

				set MKT_STD($ci,$mi,$si,desc)      $desc
				set MKT_STD($ci,$mi,$si,fb_result) $fb_result

				lappend MKT_STD($ci,$mi,fb_result) $fb_result

				#
				# If there are any name/value pairs trailing, plonk them
				# into the array
				#
				set MKT_STD($ci,$mi,$si,nv) [lrange $s 2 end]

				incr MKT_STD($ci,$mi,num_selns)

				incr si
			}

			incr mi
		}

		incr ci
	}

	set MKT_STD(done) 1

}

read_standard_market_props

}
