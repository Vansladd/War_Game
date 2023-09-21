# ==============================================================
# $Id: bet_perms.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval BETPERM {

variable BM_ILIST
variable BETDEFN
variable BET_LINES

#
# ----------------------------------------------------------------------------
# List of ints - the zeroth element is for padding - to make lrange
# do the right thing with 1-based indices
# ----------------------------------------------------------------------------
#
set BM_ILIST [list]

for {set BM_LISI_IX 0} {$BM_LISI_IX <= 25} {incr BM_LISI_IX} {
	lappend BM_ILIST $BM_LISI_IX
}
unset BM_LISI_IX

#
# ----------------------------------------------------------------------------
# Generate permutations...
# ----------------------------------------------------------------------------
#
proc BMpermgen {n args} {

	if {$n == 1} {
		return $args
	} elseif {$n == [llength $args]} {
		return [list $args]
	} else {
		set trail [lrange $args 1 end]
		set a0 [lindex $args 0]
		set l [list]
		foreach li [eval BMpermgen [expr $n-1] $trail] {
			lappend l [concat $a0 $li]
		}
		foreach li [eval BMpermgen $n $trail] {
			lappend l $li
		}
		return $l
	}
}

#
# ----------------------------------------------------------------------------
# Generate combinations...
# ----------------------------------------------------------------------------
#
proc BMcombgen {n args} {

	if {$n == 1} {
		return $args
	}

	set idx 0
	foreach e $args {
		set next_comb  [eval BMcombgen [expr {$n - 1}] [lreplace $args $idx $idx]]
		foreach c $next_comb {
			lappend l [concat $e $c]
		}
		incr idx
	}

	return $l

}

#
# ----------------------------------------------------------------------------
# This REALLY generates permutations
# BMreal_permgen 3 a b c d - will create the 24 different tuples from a, b, c and d
# ----------------------------------------------------------------------------
#
proc BMreal_permgen {n args} {
	if {$n == 1} {
		return $args
	}
	set len [llength $args]
	set l [list]
	for {set idx 0} {$idx < $len} {incr idx} {
		set tail [lreplace $args $idx $idx]
		set init [lindex $args $idx]

		foreach li [eval BMreal_permgen [expr $n - 1] $tail] {
			lappend l [concat $init $li]
			}
	}

	return $l
}

#
# ----------------------------------------------------------------------------
# Generate all the REAL m-perms from n
# Offset's used to shift right for bankers
# ----------------------------------------------------------------------------
#
proc BMreal_perm {m n {offset 0}} {
	variable BM_ILIST
	set perms [eval BMreal_permgen [expr $m - $offset] [lrange $BM_ILIST [expr 1 + $offset] [expr $n + $offset]]]

	set new_perms {}
	if {$offset > 0} {
		set pref [lrange $BM_ILIST 1 $offset]
		foreach p $perms {
			lappend new_perms [concat $pref $p]
		}
		return $new_perms
	}
	return $perms
}

#
# ----------------------------------------------------------------------------
# Generate all the m-perms from n
# ----------------------------------------------------------------------------
#
proc BMperm {m n} {
	variable BM_ILIST
	return [eval BMpermgen $m [lrange $BM_ILIST 1 $n]]
}

#
# ----------------------------------------------------------------------------
# Generate all the m-combinations from n
# ----------------------------------------------------------------------------
#
proc BMcomb {m n} {
	variable BM_ILIST
	return [eval BMcombgen $m [lrange $BM_ILIST 1 $n]]

}

#
# ----------------------------------------------------------------------------
# Given a list of combinations, aggregate all the permutations
# ----------------------------------------------------------------------------
#
proc BMbetcomb args {
	set r [list]
	foreach a $args {
		set aa [eval $a]
		foreach b $aa {
			set r [concat $r [eval BMcombgen [list $b]]]
		}
	}
	return $r
}

#
# ----------------------------------------------------------------------------
# Generate consecutive m-folds from n
# ----------------------------------------------------------------------------
#
proc BMconsec {m n} {
	set r [list]
	set full [BMperm 1 $n]

	if {$m==1} {
		return $full
	}

	set len [expr $n - $m + 1]
	for {set i 0} {$i < $len} {incr i} {
		lappend r [lrange $full $i [expr $i + $m - 1]]
	}
	return $r
}

#
# ----------------------------------------------------------------------------
# Given a list of bets, aggregate all the perms together
# ----------------------------------------------------------------------------
#
proc BMbet args {
	variable BET_LINES
	variable BETDEFN
	set r [list]
	foreach a $args {
		if ![info exists BET_LINES($a)] {
			set BET_LINES($a) [eval $BETDEFN($a)]
		}
		set r [concat $r $BET_LINES($a)]
	}
	return $r
}


#
# ----------------------------------------------------------------------------
# Build a list of selections from a combination of commands
# ----------------------------------------------------------------------------
#
proc BMcomplex args {
	set r [list]
	foreach a $args {
		set r [concat $r [eval $a]]
	}
	return $r
}

#
# ----------------------------------------------------------------------------
# Build a list of the supplied element e repeated n number of times
# ----------------------------------------------------------------------------
#
proc BMrepeat {e n} {
	set r [list]
	for {set i 0} {$i < $n} {incr i} {
		lappend r $e
	}
	return $r
}

#
# ----------------------------------------------------------------------------
# Returns the number of m-perms from n rather than the actual perms
# ----------------------------------------------------------------------------
#
proc BMnum_perms {m n} {
	set selns $n
	set accum 1
	for {set count 0} {$count < $m} {incr count} {
		set accum [expr $accum * $selns]
		incr selns -1
	}
	return $accum
}

#
# ----------------------------------------------------------------------------
# simple N-fold accumulators - for N up to 25
# ----------------------------------------------------------------------------
#
set BETDEFN(SGL) {BMperm 1 1}
set BETDEFN(DBL) {BMperm 2 2}
set BETDEFN(TBL) {BMperm 3 3}

for {set n 4} {$n <= 25} {incr n} {
	if {[string length $n] == 1} {

		# ACC4 through ACC9

		set bet_type "ACC$n"
	} else {

		# AC10 through AC25

		set bet_type "AC$n"
	}
	set BETDEFN($bet_type) "BMperm $n $n"
}



#
# ----------------------------------------------------------------------------
# pairs through (N-1)folds from N - for N up to 15
# ----------------------------------------------------------------------------
#
for {set n 3} {$n <= 15} {incr n} {
	for {set m 2} {$m < $n} {incr m} {
		if {[string length $n] == 1 && [string length $m] == 1} {

			# P-23 through P-89

			set bet_type "P-$m$n"
		} else {

			# P210 through P1415

			set bet_type "P$m$n"
		}
		set BETDEFN($bet_type) "BMperm $m $n"
	}
}



#
# ----------------------------------------------------------------------------
# pairs, (N-2)folds and (N-1)folds from N - for N from 16 to 25
# ----------------------------------------------------------------------------
#
for {set n 16} {$n <= 25} {incr n} {

	# P216 through P225

	set bet_type "P2$n"
	set BETDEFN($bet_type) "BMperm 2 $n"

	# P1416 through P2325

	set m [expr {$n - 2}]
	set bet_type "P$m$n"
	set BETDEFN($bet_type) "BMperm $m $n"

	# P1516 through P2425

	set m [expr {$n - 1}]
	set bet_type "P$m$n"
	set BETDEFN($bet_type) "BMperm $m $n"
}


#
# ----------------------------------------------------------------------------
# these are aggregates of perms ...
# ----------------------------------------------------------------------------
#
set BETDEFN(TRX)  {BMbet P-23 TBL}
set BETDEFN(PAT)  {BMcomplex {BMperm 1 3} {BMbet TRX}}
set BETDEFN(YAN)  {BMbet P-24 P-34 ACC4}
set BETDEFN(YAN+) {BMbet YAN}
set BETDEFN(CAN)  {BMbet P-25 P-35 P-45 ACC5}
set BETDEFN(CAN+) {BMbet CAN}
set BETDEFN(HNZ)  {BMbet P-26 P-36 P-46 P-56 ACC6}
set BETDEFN(SHNZ) {BMbet P-27 P-37 P-47 P-57 P-67 ACC7}
set BETDEFN(GOL)  {BMbet P-28 P-38 P-48 P-58 P-68 P-78 ACC8}
set BETDEFN(YAP)  {BMcomplex {BMperm 1 4} {BMbet YAN}}
set BETDEFN(L15)  {BMcomplex {BMperm 1 4} {BMbet YAN}}
set BETDEFN(L31)  {BMcomplex {BMperm 1 5} {BMbet CAN}}
set BETDEFN(L63)  {BMcomplex {BMperm 1 6} {BMbet HNZ}}
set BETDEFN(3BY4) {BMbet TRX}
set BETDEFN(4BY5) {BMbet P-34 ACC4}
set BETDEFN(LY6)  {BMbet P-24}
set BETDEFN(LY10) {BMbet P-24 P-34}
set BETDEFN(LY11) {BMbet YAN}

#
#-----------------------------------------------------------------------------
# Single and Double Stakes About
#
# Notice here we use Combinations instead of Permutations, this is because for
# Any-to-come bets the ordering of the legs within a line is all important.
#
#-----------------------------------------------------------------------------
#
set BETDEFN(SS2)  {BMcomb 2 2}
set BETDEFN(SS3)  {BMcomb 2 3}
set BETDEFN(SS4)  {BMcomb 2 4}
set BETDEFN(SS5)  {BMcomb 2 5}
set BETDEFN(SS6)  {BMcomb 2 6}
set BETDEFN(SS7)  {BMcomb 2 7}
set BETDEFN(SS8)  {BMcomb 2 8}
set BETDEFN(SS9)  {BMcomb 2 9}
set BETDEFN(SS10) {BMcomb 2 10}
set BETDEFN(SS11) {BMcomb 2 11}
set BETDEFN(SS12) {BMcomb 2 12}
set BETDEFN(SS13) {BMcomb 2 13}
set BETDEFN(SS14) {BMcomb 2 14}
set BETDEFN(SS15) {BMcomb 2 15}
set BETDEFN(DS2)  {BMcomb 2 2}
set BETDEFN(DS3)  {BMcomb 2 3}
set BETDEFN(DS4)  {BMcomb 2 4}
set BETDEFN(DS5)  {BMcomb 2 5}
set BETDEFN(DS6)  {BMcomb 2 6}
set BETDEFN(DS7)  {BMcomb 2 7}
set BETDEFN(DS8)  {BMcomb 2 8}
set BETDEFN(DS9)  {BMcomb 2 9}
set BETDEFN(DS10) {BMcomb 2 10}
set BETDEFN(DS11) {BMcomb 2 11}
set BETDEFN(DS12) {BMcomb 2 12}
set BETDEFN(DS13) {BMcomb 2 13}
set BETDEFN(DS14) {BMcomb 2 14}
set BETDEFN(DS15) {BMcomb 2 15}

set BETDEFN(ROB)  {BMbet P-23 TBL SS3}
set BETDEFN(FLG)  {BMbet P-24 P-34 ACC4 SS4}

#
#-----------------------------------------------------------------------------
# Bets that will need to be settled manually
#-----------------------------------------------------------------------------
#
set BETDEFN(UJK)  {BMperm 1 8}
set BETDEFN(L7B)  {BMperm 1 13}
set BETDEFN(MAG7) {BMperm 1 28}
set BETDEFN(PON)  {BMperm 1 21}
set BETDEFN(FSP)  {BMperm 1 15}

#
# ----------------------------------------------------------------------------
# Line type information for special bet types.
#
# These specify how each line for special bet types should be settled. These
# are bets where each line cannot be treated as a straight accumulation.
# ----------------------------------------------------------------------------
#
set BET_LINE_TYPES(SS2)  [BMrepeat S 2]
set BET_LINE_TYPES(SS3)  [BMrepeat S 6]
set BET_LINE_TYPES(SS4)  [BMrepeat S 12]
set BET_LINE_TYPES(SS5)  [BMrepeat S 20]
set BET_LINE_TYPES(SS6)  [BMrepeat S 30]
set BET_LINE_TYPES(SS7)  [BMrepeat S 42]
set BET_LINE_TYPES(SS8)  [BMrepeat S 56]
set BET_LINE_TYPES(SS9)  [BMrepeat S 72]
set BET_LINE_TYPES(SS10) [BMrepeat S 90]
set BET_LINE_TYPES(SS11) [BMrepeat S 110]
set BET_LINE_TYPES(SS12) [BMrepeat S 132]
set BET_LINE_TYPES(SS13) [BMrepeat S 156]
set BET_LINE_TYPES(SS14) [BMrepeat S 182]
set BET_LINE_TYPES(SS15) [BMrepeat S 210]
set BET_LINE_TYPES(DS2)  [BMrepeat D 2]
set BET_LINE_TYPES(DS3)  [BMrepeat D 6]
set BET_LINE_TYPES(DS4)  [BMrepeat D 12]
set BET_LINE_TYPES(DS5)  [BMrepeat D 20]
set BET_LINE_TYPES(DS6)  [BMrepeat D 30]
set BET_LINE_TYPES(DS7)  [BMrepeat D 42]
set BET_LINE_TYPES(DS8)  [BMrepeat D 56]
set BET_LINE_TYPES(DS9)  [BMrepeat D 72]
set BET_LINE_TYPES(DS10) [BMrepeat D 90]
set BET_LINE_TYPES(DS11) [BMrepeat D 110]
set BET_LINE_TYPES(DS12) [BMrepeat D 132]
set BET_LINE_TYPES(DS13) [BMrepeat D 156]
set BET_LINE_TYPES(DS14) [BMrepeat D 182]
set BET_LINE_TYPES(DS15) [BMrepeat D 210]

set BET_LINE_TYPES(ROB)  [concat [BMrepeat A 4] [BMrepeat S 6]]
set BET_LINE_TYPES(FLG)  [concat [BMrepeat A 11] [BMrepeat S 12]]





#
# ----------------------------------------------------------------------------
# All UP
# ----------------------------------------------------------------------------
#
set BETDEFN(AU2X1) {BMbet DBL}
set BETDEFN(AU3X1) {BMbet TBL}
set BETDEFN(AU2X3) {BMcomplex {BMperm 1 2} {BMbet DBL}}
set BETDEFN(AU3X7) {BMcomplex {BMperm 1 3} {BMbet P-23 TBL}}
set BETDEFN(AU3X3) {BMbet P-23}
set BETDEFN(AU3X4) {BMbet P-23 TBL}
set BETDEFN(DLEG) {BMperm 1 2}
set BETDEFN(TLEG) {BMperm 1 3}

#
# ----------------------------------------------------------------------------
# Add a variable trace for (as-yet-undefined) BET_LINES elements, to arrange
# for them to be generated on demand - I *love* Tcl
# ----------------------------------------------------------------------------
#
foreach b [array names BETDEFN] {
	trace variable BET_LINES($b) r [namespace code BMgen]
}


#
# ----------------------------------------------------------------------------
# Trace procedure to generate BET_LINES entries if they don't exist
# ----------------------------------------------------------------------------
#
proc BMgen {a e o} {
	global $a
	variable BETDEFN
	if {![info exists ${a}($e)]} {
		# only need the trace called once...
		trace vdelete ${a}($e) r BMgen
		# do the business - I love Tcl
		set ${a}($e) [eval $BETDEFN($e)]
	}
}

proc bet_lines b {
	variable BET_LINES
	return $BETPERM::BET_LINES($b)
}

#
# ----------------------------------------------------------------------------
# Returns a value which indicates how a line should be settled for a given
# bet type.
#
# Returns
#   'A' - Treat the line as a standard accumulator
#   'S' - Line needs to be settled as a 'Single Any-to-come' (SSA bets).
#   'D' - Line needs to be settled as a 'Double Any-to-come' (DSA bets).
#
#
# (Can't figure out CJH's lazy evaluation scheme so just eval them here..)
#
# ----------------------------------------------------------------------------
#
proc bet_line_type {bet_type line_no} {
	variable BET_LINE_TYPES

	#
	# Set line_no to correspond to list idx
	#
	set line_no [expr {$line_no - 1}]

	if {[info exists BET_LINE_TYPES($bet_type)]} {
		if {[llength $BET_LINE_TYPES($bet_type)] > $line_no} {
			return [lindex $BET_LINE_TYPES($bet_type) $line_no]
		}
		return A
	}
	return A
}

#
# Will combine a list of groups into allowable combinations
# ie:  legs  0 & 1 can't be combined
#      legs  3,4 & 5 can't be combined
#      combine_grps {{0 1} 2 {3 4 5}}
#      => {0 2 3} {0 2 4} {0 2 5} {1 2 3} {1 2 4} {1 2 5}
#
proc combine_grps {grps {prefix {}}} {
	set combis [list]
	foreach g [lindex $grps 0] {
		set new_prefix [eval list $prefix $g]
		if {[llength $grps] == 1} {
			lappend combis $new_prefix
		} else {
			set l [combine_grps [lrange $grps 1 end] $new_prefix]
			eval lappend combis $l
		}
	}
	return $combis
}

}
