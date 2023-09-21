##
# Copyright (c) 2010 OpenBet Ltd. All rights reserved.
# $Id: dec.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
#
# "Fuzzy" comparison and rounding procedures, intended for
# use when operating on decimal quantities such as money.
#
# Out of convenience, we tend to store decimal amounts
# as regular variables and use expr on them. This is bad
# since Tcl (like most languages) uses binary floating
# point which cannot exactly represent decimal fractions -
# there is no such number as 0.1 in binary floating point!
#
# [To see why this is, consider trying to represent the
# number 1/3 in decimal - an infinite number of threes
# would be required. The same problem occurs with 1/10 in
# binary. So the best the computer can do is store an
# approximation to 0.1 - e.g. 0.100000000000000125.]
#
# This leads to really strange errors where two variables
# look the same when printed, but whose internal floating
# point representation is just different enough to appear
# unequal when using the comparison operators in expr (and
# in "if" and "while", by extension).
#
# For example, on some architectures, the calculations below
# lead to very slightly different values stored in a and b -
# one just above 1.005 and one just below it:
#
#   % set a [expr {1.000 * 1.0050}]
#   % set b [expr {0.001 * 1005.0}]
#   % if {$a == b} {puts same} else {puts different}
#   different
#
# You can see their values in tclsh by asking Tcl to print
# values to their maxium precision:
#
#   % set tcl_precision 17
#   % set a
#   1.0049999999999999
#   % set b
#   1.0050000000000001
#
# This package provides a bunch of comparison and rounding
# procedures which are designed to ignore these tiny errors.
#
# For example, unlike "==", [::ob_dec::eq $a $b] will return
# true since the values are within an "epsilon" of each other.
# By default, the epsilon used is 10^-6, which seems to works
# quite well for the arithmetic we do.
#
# And ::ob_dec::round_nearest will round both a and b to 1.01,
# rather than rounding one to 1.00 and the other to 1.01.
#
# EXAMPLE USAGE:
#
#  package require util_dec
#  if {[ob_dec::lt $balance $stake]} {
#     error "Insufficient funds: your balance is
#            [ob_dec::round_down $balance]"
#  }
#
##

package provide util_dec 4.5

namespace eval ::ob_dec {}

# In Tcl 8.5+, this will make the procedures available for use as
# functions in expr and friends - allowing one to do things like:
#
#  if { ob_dec_lt($x * 2, $y * 3) } { ... }
# 
if {![catch {package require Tcl 8.5}]} {
	interp alias {} ::tcl::mathfunc::ob_dec_eq  {} ::ob_dec::eq
	interp alias {} ::tcl::mathfunc::ob_dec_ne  {} ::ob_dec::ne
	interp alias {} ::tcl::mathfunc::ob_dec_lt  {} ::ob_dec::lt
	interp alias {} ::tcl::mathfunc::ob_dec_gt  {} ::ob_dec::gt
	interp alias {} ::tcl::mathfunc::ob_dec_lte {} ::ob_dec::lte
	interp alias {} ::tcl::mathfunc::ob_dec_gte {} ::ob_dec::gte
	interp alias {} ::tcl::mathfunc::ob_dec_cmp {} ::ob_dec::cmp
}

# Are A and B fairly equal?
# Specifically, are they within an epsilon of each other?
proc ::ob_dec::eq {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] == 0}]
}

# Are A and B pretty different?
# Specifically, do they differ by more than an epsilon?
proc ::ob_dec::ne {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] != 0}]
}

# Is A roughly less than or equal to B?
# Specfically, is A less than B plus an epsilon?
proc ::ob_dec::lte {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] <= 0}]
}

# Is A roughly greater than or equal to B?
# Specfically, is A greater than B minus an epsilon?
proc ::ob_dec::gte {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] >= 0}]
}

# Is A appreciably less than B?
# Specfically, is A at least an epsilon below B?
proc ::ob_dec::lt {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] < 0}]
}

# Is A appreciably greater than B?
# Specfically, is A at least an epsilon above B?
proc ::ob_dec::gt {a b {eps 1e-6}} {
	return [expr {[::ob_dec::cmp $a $b $eps] > 0}]
}

# Compare A and B, and return 0 if they are fairly equal, a negative
# integer if A is appreciably less than B, and a positive integer if
# A is appreciably greater than B.
#
# Specifically, A and B are considered fairly equal if they are within
# and epsilon of each other.
proc ::ob_dec::cmp {a b {eps 1e-6}} {
	set d [expr {double($a) - double($b)}]
	if {$d < (0.0 - $eps)} {
		return -1
	} elseif {$d > $eps} {
		return 1
	} else {
		return 0
	}
}

# Convert V to NDP decimal places, rounding down.
# Specfically, round towards negative infinity -
# unless V is within an epsilon of the next number
# above, in which case choose that.
proc ::ob_dec::round_down {v {ndp 2} {eps 1e-6}} {
	return [format "%.${ndp}f" \
	  [expr {floor (($v + $eps) * pow(10.0,$ndp)) \
	        / pow(10.0,$ndp)}]]
}

# Convert V to NDP decimal places, rounding up.
# Specfically, round towards positive infinity -
# unless V is within an epsilon of the next number
# below, in which case choose that.
proc ::ob_dec::round_up {v {ndp 2} {eps 1e-6}} {
	return [format "%.${ndp}f" \
	  [expr {ceil (($v - $eps) * pow(10.0,$ndp)) \
	        / pow(10.0,$ndp)}]]
}

# Convert V to NDP decimal places, rounding to nearest.
# Specifically, round to which ever is closer of the
# numbers above and below V - unless V is within an
# epsilon of the midpoint, in which case we round up
# for positive V and down for negative V.
proc ::ob_dec::round_nearest {v {ndp 2} {eps 1e-6}} {
	return [::ob_dec::round_down \
	  [expr {$v + 0.5 / pow(10.0,$ndp)}] \
	  $ndp $eps]
}
