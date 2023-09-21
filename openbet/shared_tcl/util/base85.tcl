##
# $Id: base85.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# Copyright (C) 2009 Orbis Technology Ltd. All rights reserved.
#
# Support for base 85 numbers.
#
# Synopsis:
#
#   package require util_base85 ?4.5?
#
# Procedures:
#
#   base85::dec_to_b85 - convert integer decimal string to base 85
#   base85::pad        - pad base 85 string with leading "zeroes"
#   base85::validate   - check string appears to be in base 85
#   base85::succ       - get base 85 no. which follows given base 85 no.
#
##

package provide util_base85 4.5

namespace eval base85 {

variable _powers
variable _chars

set _powers \
  [list \
    "1" \
    "85" \
    "7225" \
    "614125" \
    "52200625" \
    "4437053125" \
    "377149515625" \
    "32057708828125" \
    "2724905250390625" \
    "231616946283203125" \
    "19687440434072265625" \
  ]

set _chars [list]
for {set i 0} {$i < 85} {incr i} {
  lappend _chars [format %c [expr {[scan ! %c] + $i}]]
}

}

proc base85::pad {b85 width} {
  variable _chars
  set zero [string index $_chars 0]
  while {[string length $b85] < $width} {
    set b85 ${zero}${b85}
  }
  return $b85
}

proc base85::dec_to_b85 {dec} {
  variable _powers
  variable _chars
  set dec [_slow_dec::normalise $dec]
  # Without big integer support (added in Tcl 8.5) we can only do
  # the fast + simple conversion for numbers below 2^31.
  if {$::tcl_version >= 8.5 || [_slow_dec::cmp $dec 2147483647] <= 0} {
    return [_fast_to_dec $dec $_chars]
  } else {
    return [_slow_dec::convert $dec $_powers $_chars]
  }
}

proc base85::validate {b85} {
	return [regexp {^[!-u]+$} $b85]
}

proc base85::succ {b85} {
  variable _chars
  for {set i [expr {[string length $b85] - 1}]} {$i >= 0} {incr i -1} {
    set c [string index $b85 $i]
    set head [string range $b85 0 [expr {$i - 1}]]
    set tail [string range $b85 [expr {$i + 1}] end]
    if {$c != [lindex $_chars end]} {
      set next [format %c [expr {1 + [scan $c %c]}]]
      set b85 ${head}${next}${tail}
      break
    } else {
      set b85 ${head}[lindex $_chars 0]${tail}
    }
  }
  if {$i == -1} {
    set b85 [lindex $_chars 1]$b85
  }
  return $b85
}

proc base85::_fast_to_dec {n chars} {
  set s ""
  set base [llength $chars]
  while {$n} {
    set rem [expr {$n % $base}]
    set n [expr {$n / $base}]
    set s [lindex $chars $rem]${s}
  }
  if {$s == ""} {
    set s [lindex $chars 0]
  }
  return $s
}

namespace eval base85::_slow_dec {

# remove leading zeroes
proc normalise {a} {
  set a [string trimleft $a [list "0"]]
  if {![string length $a]} {
    set a "0"
  }
  return $a
}

# compare value of normalised decimal strings; returns -1, 0, or +1.
proc cmp {a b} {
  set d [expr {[string length $a] - [string length $b]}]
  if {$d} {
    return $d
  }
  return [string compare $a $b]
}

# subtract b from a; throws error if b > a
# (horribly slow!)
proc sub {a b} {
  set d [cmp $a $b]
  if {$d < 0} {
    error "underflow"
  } elseif {$d == 0} {
    return "0"
  }
  for {set i 1} {$i <= [string length $b]} {incr i} {
    set da [string index $a [expr {[string length $a] - $i}]]
    set db [string index $b [expr {[string length $b] - $i}]]
    set dc [expr {$da - $db}]
    if {$dc >= 0} {
      set head [string range $a 0 [expr {[string length $a] - $i - 1}]]
      set tail [string range $a [expr {[string length $a] - $i + 1}] end]
      set a ${head}${dc}${tail}
    } else {
      set dc [expr {10 + $dc}]
      set head [string range $a 0 [expr {[string length $a] - $i - 1}]]
      set tail [string range $a [expr {[string length $a] - $i + 1}] end]
      set a [sub $head "1"]${dc}${tail}
    }
  }
  return [normalise $a]
}

# find biggest power of base that is not greater than a
# (using look up table of powers)
proc mag {a base_powers} {
  for {set e 0} {$e < [llength $base_powers]} {incr e} {
    set p [lindex $base_powers $e]
    if {[cmp $p $a] > 0} {
      if {$e} {
        incr e -1
      }
      return [list $e [lindex $base_powers $e]]
    }
  }
  error "overflow"
}

# used by base conversion to get next digit
proc next_dig {a base_powers} {
  foreach {e p} [mag $a $base_powers] {break}
  set d 0
  while {![catch {set a [sub $a $p]}]} {incr d}
  return [list $e $d $a]
}

# convert a to different base
# (using look up table of powers and digit chars)
proc convert {a base_powers base_chars} {
  set max_exp 0
  while {1} {
    foreach {e d a} [next_dig $a $base_powers] {break}
    set D($e) $d
    if {$e > $max_exp} {
      set max_exp $e
    }
    if {$e == 0} {
      break
    }
  }
  set s ""
  for {set i $max_exp} {$i >= 0} {incr i -1} {
    if {[info exists D($i)]} {
      set d $D($i)
    } else {
      set d 0
    }
    append s [lindex $base_chars $d]
  }
  return $s
}

}
