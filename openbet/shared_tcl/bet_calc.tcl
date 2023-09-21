# $Id: bet_calc.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# How much could you win ?
#
# Parameters are
#    bet_type - a 3/4 letter bet type code (SGL/DBL/TRX/...)
#    spl      - stake per line
#    prices   - list of seln prices as decimals (3/1 => 4.0)
#
# Requires bet_perms.tcl
#
proc could_win {bet_type spl leg_type prices {ew_terms ""} {AH_hcap ""}} {

	if {$leg_type == "E" || $leg_type == "P"} {
		if {[llength $prices] != [llength $ew_terms]} {
			error "prices and each-way terms don't match"
		}
	}
	set R [list]
	set E [list]
	set H [list]

	foreach p $prices e $ew_terms h $AH_hcap {
		lappend R [expr {1.0+double([lindex $p 0])/double([lindex $p 1])}]
		if {$e == "" || $e == {{} {}} } {
			set e [list 1 1]
		}
		lappend E [expr {double([lindex $e 0])/double([lindex $e 1])}]
		if {$h != "" && $h != {{}} && [expr {$h/2.0}] != [expr {int($h/2.0)}]} {
			lappend H 2.0
		} else {
			lappend H 1.0
		}
	}

	return [could_win_d $bet_type $spl $leg_type $R $E $H]

}

proc could_win_d {bet_type spl leg_type prices ew_terms AH_hcap} {

	global BET_LINES

	set j 0
	foreach p $prices e $ew_terms h $AH_hcap {
		incr j
		set R(W,$j) [expr {$p * $h}]
		set R(P,$j) [expr {1.0+($R(W,$j)-1.0)*$e}]
	}
	set unit_rtn 0.0
	foreach type [expr {$leg_type=="E"?[list W P]:[list $leg_type]}] {
		foreach l $BET_LINES($bet_type) {
			set r 1.0
			foreach s $l {
				set r [expr {$r*$R($type,$s)}]
			}
			set unit_rtn [expr {$unit_rtn+$r}]
		}
	}
	return [expr {$unit_rtn*$spl}]
}

#
# How many lines in a bet ?
#
proc bet_lines {bet_type legs} {

	global BET_LINES

	array set E [list\
		SF 1 RF 2 CF {($n)*($n-1)} TC 1 CT {($n)*($n-1)*($n-2)} SC 1 -- 1]

	for {set i 0} {$i < [llength $legs]} {} {
		foreach {t n} [lindex $legs $i] { break }
		set L([incr i]) [expr $E($t)]
	}
	set lines 0
	foreach l $BET_LINES($bet_type) {
		set ll 1
		foreach s $l {
			set ll [expr {$ll*$L($s)}]
		}
		incr lines $ll
	}
	return $lines
}
