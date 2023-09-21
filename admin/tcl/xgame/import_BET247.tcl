# ==============================================================
# $Id: import_BET247.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc xgame_import_file {} {
    
    global xgaQry

    set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]
    set filename "$UPLOAD_DIR/xgame/[reqGetArg FullName]"

    if [catch {set file [open $filename r]} fileId] {
	return [handle_err "File Error" "$fileId"]
    }
    
    set header [gets $file]
    set line 1

    foreach s {sp tc p3 p4 p5 ebms eff essd} {
	set count($s) 0
	set win($s) 0.00
    }

    regexp {^([0-9 ]{13,13})([0-9 ]{10,10})(.{20,20})([0-9][0-9]-[A-Za-z]{3,3}-[0-9]{4,4})([0-2][0-9]:[0-5][0-9]:[0-5][0-9])([0-9 ]{10,10})([0-9 .]{10,10})$} $header\
	junk bet_id ret_tran_no ev_name sent_date sent_time total_records total_winnings
    
    if {![info exists junk] || [string length $junk]!=82 || [string trim $ev_name " "]!="Control"} {
	return [handle_err "Control Record error" "Malformed control record, or no control record present on line 1"]
    }

    ## Trim off white space
    foreach c {ret_tran_no sent_date sent_time total_records total_winnings} {
	set $c [string trim [set $c] " "]
    }

    set header_info "Processing file with return transmission number $ret_tran_no, sent $sent_date $sent_time, containing $total_records records, with total winnings $total_winnings"

    while {1} {
	set record [gets $file]
	incr line
	if {$record==""} {
	    return [handle_err "Unexpected end of file" "Encountered a record which is neither a data record nor a trailer record at line $line"]
	}
	set bet_id ""
	regexp {^[0-9 ]{13,13}} $record bet_id
	if {$bet_id==""} {
	    return [handle_err "Malformed record at line $line" "This record does not contain a valid bet_id"]
	}
	if {$bet_id=="9999999999999"} {
	    # It's a trailer record
	    break
	}

	# Process data record
	regexp {^([0-9 ]{13,13})([0-9 ]{13,13})(.{20,20})([0-9 ]{8,8})([WL])([0-9 .]{10,10})([LOFP])$} $record junk bet_id cust_id ev_name comp_no win_ind winnings s_flag

	if {![info exists junk] || [string length $junk]!=66} {
	    return [handle_err "Malformed record at line $line" "Not a valid data record"]
	}
	
	## Trim off white space
	foreach c {bet_id win_ind winnings s_flag ev_name} {
	    set $c [string trim [set $c] " "]
	}
	
	set a_bet_id($line) $bet_id
	set a_win_ind($line) $win_ind
	set a_winnings($line) $winnings
	set a_s_flag($line) $s_flag
	
	if [info exists sort] {
	    unset sort
	}
	switch -- $ev_name {
	    "Treble Chance" {
		set sort tc
	    }
	    "Spread Pool" {
		set sort sp
	    }
	    "Prizebuster 3" {
		set sort p3
	    }
	    "Prizebuster 4" {
		set sort p4
	    }
	    "Prizebuster 5" {
		set sort p5
	    }
	    "Euro 2000 BMS" {
		set sort ebms
	    }
	    "Euro 2000 FF" {
		set sort eff
	    }
	    "Euro 2000 SSD" {
		set sort essd
	    }
	}
	
	if {![info exists sort]} {
	    return [handle_err "Unrecognized game type at line $line" ""]
	}


	incr count($sort)
	set win($sort) [expr "$win($sort)+$winnings"]
    }
    
    # Broken out, so should be on a trailer record
    
# Nasty regexp
    regexp {^(9{13,13})([ Trailer]{20,20})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})([0-9 ]{6,6})([0-9 .]{10,10})} $record junk bet_id ev_name count_tc win_tc count_sp win_sp count_p3 win_p3 count_p4 win_p4 count_p5 win_p5 count_ebms win_ebms count_eff win_eff count_essd win_essd
    
    if {![info exists junk] || [string length $junk]!=161} {
	return [handle_err "Malformed trailer at line $line" "The trailer record is badly formed"]
    }
    
    # Trim off white space
    foreach c {bet_id ev_name count_tc win_tc count_sp win_sp count_p3 win_p3 count_p4 win_p4 count_p5 win_p5 count_ebms win_ebms count_eff win_eff count_essd win_essd} {
	set $c [string trim [set $c] " "]
    }
    
    if {$ev_name!="Trailer"} {
	return [handle_err "Malformed trailer at line $line" "The event name for a trailer record should be 'Trailer'"]
    }

    
    # Check everything adds up
    foreach s {sp tc p3 p4 p5 ebms eff essd} {
	if {[format {%0.2f} $count($s).0] != [format {%0.2f} [set count_${s}]]} {
	    return [handle_err "Number of records mismatch" "There were $count($s) data records for game $s in the file, but the trailer record claims there are [set count_$s]"]
	}

	OT_LogWrite 1 "Game $s data: x[set win($s)]x (length [string length $win($s)]); trailer: x[set win_$s]x (length [string length [set win_$s]])"

	if {[format {%0.2f} $win($s)] != [format {%0.2f} [set win_$s]]} {
	    return [handle_err "Amount of winnings mismatch" "There were $win($s) winnings for game $s in the data records of the file, but the trailer record claims there were [set win_$s]"]
	}
    }

    # And check everything adds up to what it says in the header
    if {$total_records != $line} {
	return [handle_err "Number of records mismatch" "There are $line records in this file (including control and trailer records) and yet the header claims there are $total_records."]
    }

    # Seems safe to start processing

    #Line 1 is the control record, the last line is the trailer
    
    tpBufAddHdr "Content-Type" "text/plain"

    tpBufWrite "$header_info\n"

    set refund 0
    for {set r 2} {$r < $line} {incr r} {
	OT_LogWrite 1 "Settling bet_id $a_bet_id($r) which is a $a_win_ind($r) with winnings $a_winnings($r) by method $a_s_flag($r)"
	
	
	switch -- $a_s_flag($r) {
	    L { 
		set amount 0
	    }
	    O {
		set amount $a_winnings($r)
	    }
	    F {
		# Free bet, 1 pound
		set amount "1.00"
	    }
	    P {
		set amount 0
	    }
	}
	
	if [catch [xg_exec_qry $xgaQry(settle_bet) $a_bet_id($r) $amount $refund $a_s_flag($r)] msg] {
	    tpBufWrite "Unable to settle bet_id $a_bet_id($r). This bet remains unsettled: $msg\n"
	}
	
    }

    tpBufWrite "\n\nExternal Settlement complete\n"

} 
