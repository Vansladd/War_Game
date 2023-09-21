# $Id: bet_perms.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

global BM_ILIST BET_LINES BETDEFN
#
# ----------------------------------------------------------------------------
# Generate permutations, well combinations actually
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
# This REALLY generates permutations
# BMreal_permgen 3 a b c d - will create the 24 different tuples
# from a, b, c and d
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
	global BM_ILIST
	set perms [eval BMreal_permgen [expr $m - $offset] [lrange $BM_ILIST [expr 1 + $offset] [expr $n + $offset]]]

	set new_perms [list]
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
# List of ints - the zeroth element is for padding - to make lrange
# do the right thing with 1-based indices
# ----------------------------------------------------------------------------
#
set BM_ILIST [list 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25]


#
# ----------------------------------------------------------------------------
# Generate all the m-perms from n
# ----------------------------------------------------------------------------
#
proc BMperm {m n} {
	global BM_ILIST
	return [eval BMpermgen $m [lrange $BM_ILIST 1 $n]]
}

#
# ----------------------------------------------------------------------------
# To be pedantic, BMperm actually generates combinations.
# This BMcomb will generate actual permutations (!) for n elements
# ----------------------------------------------------------------------------
#
proc BMcomb {n} {
	global BM_ILIST
	return [BMcombgen [lrange $BM_ILIST 1 $n]]
}

#
# ----------------------------------------------------------------------------
# Generate 'combinations'
# ----------------------------------------------------------------------------
#
proc BMcombgen {in} {

	set ret [list]
	set len [llength $in]

	if {$len==1} {
		return [lindex $in 0]
	}

	for {set i 0} {$i<$len} {incr i} {
		foreach tail [BMcombgen [lreplace $in $i $i]] {
			lappend ret [concat [lindex $in $i] $tail]
		}
	}
	return $ret
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
	global BET_LINES BETDEFN
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
# Returns the number of m-perms from n rather than the actual perms
# ----------------------------------------------------------------------------
#
proc BMnum_perms {m n {offset 0}} {
	incr m -$offset
	incr n -$offset

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
# Bets that will need to be settled manually...
# These definitions are not proper definitions but help in calculating
# bet lines. More structured information will be needed for automated
# bet settlement.
#-----------------------------------------------------------------------------
#

set BETDEFN(SS2)  {BMbetcomb {BMperm 2 2}}
set BETDEFN(SS3)  {BMbetcomb {BMperm 2 3}}
set BETDEFN(SS4)  {BMbetcomb {BMperm 2 4}}
set BETDEFN(SS5)  {BMbetcomb {BMperm 2 5}}
set BETDEFN(SS6)  {BMbetcomb {BMperm 2 6}}
set BETDEFN(SS7)  {BMbetcomb {BMperm 2 7}}
set BETDEFN(SS8)  {BMbetcomb {BMperm 2 8}}
set BETDEFN(SS9)  {BMbetcomb {BMperm 2 9}}
set BETDEFN(SS10) {BMbetcomb {BMperm 2 10}}
set BETDEFN(SS11) {BMbetcomb {BMperm 2 11}}
set BETDEFN(SS12) {BMbetcomb {BMperm 2 12}}
set BETDEFN(SS13) {BMbetcomb {BMperm 2 13}}
set BETDEFN(SS14) {BMbetcomb {BMperm 2 14}}
set BETDEFN(SS15) {BMbetcomb {BMperm 2 15}}

set BETDEFN(DS2)  {BMbetcomb {BMperm 2 2}}
set BETDEFN(DS3)  {BMbetcomb {BMperm 2 3}}
set BETDEFN(DS4)  {BMbetcomb {BMperm 2 4}}
set BETDEFN(DS5)  {BMbetcomb {BMperm 2 5}}
set BETDEFN(DS6)  {BMbetcomb {BMperm 2 6}}
set BETDEFN(DS7)  {BMbetcomb {BMperm 2 7}}
set BETDEFN(DS8)  {BMbetcomb {BMperm 2 8}}
set BETDEFN(DS9)  {BMbetcomb {BMperm 2 9}}
set BETDEFN(DS10) {BMbetcomb {BMperm 2 10}}
set BETDEFN(DS11) {BMbetcomb {BMperm 2 11}}
set BETDEFN(DS12) {BMbetcomb {BMperm 2 12}}
set BETDEFN(DS13) {BMbetcomb {BMperm 2 13}}
set BETDEFN(DS14) {BMbetcomb {BMperm 2 14}}
set BETDEFN(DS15) {BMbetcomb {BMperm 2 15}}

set BET_LINES(UJK) {{1 4 7} {2 5 8} {3 6 9} {1 2 3} {4 5 6} {7 8 9} {1 5 9} {3 5 7}}
set BET_LINES(L7B) {{1 2} {1 6} {1 7} {2 6} {2 7} {6 7} {3 4} {3 5} {4 5} {1 4 7} {2 4 6} {1 2 4 6 7} {1 2 3 4 5 6 7}}
set BET_LINES(UJT) {{1 4 7} {2 5 8} {3 6 9} {1 2 3} {4 5 6} {7 8 9} {1 5 9} {3 5 7} {1 4} {1 7} {7 4} {2 5} {5 8} {8 2} \
			{3 6} {6 9} {9 3} {1 2} {1 3} {2 3} {4 5} {5 6} {4 6} {7 8} {8 9} {7 9} {1 5} {5 9} {1 9} {3 5} {5 7} \
			{3 7}}
set BETDEFN(ROB)  {BMcomplex {BMperm 2 3} {BMbet TBL} {BMbet SS3}}
set BETDEFN(FLG)  {BMcomplex {BMperm 2 4} {BMperm 3 4} {BMbet ACC4} {BMbet SS4}}
set BETDEFN(MAG7) {BMcomplex {BMperm 1 7} {BMconsec 2 7} {BMconsec 3 7} {BMconsec 4 7} {BMconsec 5 7} {BMconsec 6 7} {BMbet ACC7}}
set BETDEFN(PON)  {BMcomplex {BMperm 1 6} {BMconsec 2 6} {BMconsec 3 6} {BMconsec 4 6} {BMconsec 5 6} {BMbet ACC6}}
set BETDEFN(FSP)  {BMcomplex {BMperm 1 5} {BMconsec 2 5} {BMconsec 3 5} {BMconsec 4 5} {BMbet ACC5}}

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
set BETDEFN(DLEG)  {BMperm 1 2}
set BETDEFN(TLEG)  {BMperm 1 3}


#
# ----------------------------------------------------------------------------
# Add a variable trace for (as-yet-undefined) BET_LINES elements, to arrange
# for them to be generated on demand - I *love* Tcl
# ----------------------------------------------------------------------------
#
foreach b [array names BETDEFN] {
	trace variable BET_LINES($b) r BMgen
}


#
# ----------------------------------------------------------------------------
# Trace procedure to generate BET_LINES entries if they don't exist
# ----------------------------------------------------------------------------
#
proc BMgen {a e o} {
	global $a BETDEFN
	if {![info exists ${a}($e)]} {
		# only need the trace called once...
		trace vdelete ${a}($e) r BMgen
		# do the business - I love Tcl
		set ${a}($e) [eval $BETDEFN($e)]
	}
}
