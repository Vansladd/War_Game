# ==============================================================
# $Id: export_BET247.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc populate_xgame_export_queries args {
    global xgaQry

    set xgaQry(create_export_file) {execute
	procedure pCreateXGameExFile (
				      p_filename = ?
				      )
    }
    set xgaQry(get_export_files) {
	select xgame_ex_file_id,
	filename,
	type,
	cr_date
	from tXGameExFile
	order by xgame_ex_file_id desc
    }

    set xgaQry(get_bets_from_file) {
	select b.xgame_bet_id, 
	g.sort, 
	to_char(g.draw_at, "%d-%b-%Y %H:%M:%S") as draw_at,
	to_char(s.cr_date, "%d-%b-%Y %H:%M:%S") as cr_date, 
	comp_no,
	cust_id,
	b.picks
	from tXGameExFile ef,
	tXGameExBet  eb,
	tXGameBet b,
	tXGameSub s,
	tXGame g,
	tAcct a
	
	where ef.xgame_ex_file_id = eb.xgame_ex_file_id
	and eb.xgame_bet_id = b.xgame_bet_id
	and b.xgame_sub_id = s.xgame_sub_id
	and b.xgame_id = g.xgame_id
	and s.acct_id = a.acct_id
	and ef.xgame_ex_file_id = ?
    }

    set xgaQry(get_file_details) {
	select
	cr_date,
	filename,
	type
	from tXGameExFile
	where xgame_ex_file_id = ?
    }
}


proc create_export_file args {

    global xgaQry

    set filename [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

    if [catch {set rs [xg_exec_qry $xgaQry(create_export_file) $filename]} msg] {
	return [handle_err "create_export_file"\
		    "error: $msg"]        
    }
    db_close $rs
    
    X_play_file filecreated.html
}

proc export_file args {
    global xgaQry
    
    set xgame_ex_file_id [reqGetArg xgame_ex_file_id]
    
    set count_tc 0
    set count_sp 0
	set count_cp3 0
    set count_p3 0
    set count_p4 0
    set count_eff 0
    set count_essd 0
    set count_embs 0

    ## Generate records
    set record ""
    
    if [catch {set rs [xg_exec_qry $xgaQry(get_bets_from_file) $xgame_ex_file_id]} msg] {
	return [handle_err "get_bets_from_file"\
		    "error: $msg"]        
    }

    set nrows [db_get_nrows $rs]
    
    for {set r 0} {$r < $nrows} {incr r} {

	set sort [db_get_col $rs $r sort]
	set draw_at [db_get_col $rs $r draw_at]
	set cr_date [db_get_col $rs $r cr_date]
	set xgame_bet_id [db_get_col $rs $r xgame_bet_id]
	set comp_no [db_get_col $rs $r comp_no]
	set cust_id [db_get_col $rs $r cust_id]
	set picks [db_get_col $rs $r picks]

	# Bet_id
	append record [format {%-13d} $xgame_bet_id]
	
	set charity_field " "

	# Event Name
	set name "Unknown"
	switch -- $sort {
	    MONTHPOOL {
		set name "Treble Chance"
		incr count_tc
	    }
	    SATPOOL {
		set name "Treble Chance"
		incr count_tc
	    }
	    BIGMATCH {
		set name "Spread Pool"
		incr count_sp
	    }
	    PBUST3 {
		set name "Prizebuster 3"
		incr count_p3
		set charity_field "1"
	    }
	    PBUST4 {
		set name "Prizebuster 4"
		incr count_p4
		set charity_field "1"
	    }
	    EFINAL4 {
		set name "Euro 2000 FF"
		incr count_eff
	    }		
	    ESIXSD {
		set name "Euro 2000 SSD"
		incr count_essd
	    }
	    EBIGMATCH {
		set name "Euro 2000 BMS"
		incr count_embs
	    }
            CPBUST3 {
                set name "Celtic Prizebuster"
                incr count_cp3
                set charity_field "3"
            }
	}
	append record [format {%-20s} $name]

	## Competition date/time
	set date "-----------"
	set time "--------"
	regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $draw_at date
	regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $draw_at time
	append record [string tolower $date]
	append record $time

	## Bet date/time
	set date "-----------"
	set time "--------"
	regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $cr_date date
	regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $cr_date time
	append record [string tolower $date]
	append record $time
	
	## Comp no
	regexp {[0-9]{4,4}} $draw_at temp
	append temp [format {%02d} $comp_no]
	append record [format {%-8d} $temp]
	
	# Game Version
	append record [format {%-10s} $charity_field]
	
	# Cust ID (actually the account ID)
	append record [format {%-13d} $cust_id]

	# Selections
	set selections ""
	foreach p [split $picks "|"] {
	    append selections [format {%02d} $p]
	}
	append record [format {%-20s} $selections]

	# Final line break
	append record "\n"
    }
    db_close $rs

    if [catch {set rs [xg_exec_qry $xgaQry(get_file_details) $xgame_ex_file_id]} msg] {
	return [handle_err "get_file_details"\
		    "error: $msg"]        
    }
    set cr_date [db_get_col $rs 0 cr_date]
    db_close $rs

    # Write header
    set header ""
    # Bet_id = 0 in header
    append header [format %013d 0] 
    # Transmission no
    append header [format {%-10d} $xgame_ex_file_id]
    # Event Name
    append header [format {%-20s} Control]

    # Sent Date/Time
    set date "-----------"
    set time "--------"
    regexp {[0-9][0-9]-[a-zA-Z]{3,3}-[0-9]{4,4}} $cr_date date
    regexp {[0-9]{2,2}:[0-9]{2,2}:[0-9]{2,2}} $cr_date time
    append header $date
    append header $time

    # number of each event
    set prizebuster5 0
    foreach i {count_tc count_sp count_p3 count_p4 prizebuster5 count_embs count_eff count_essd count_cp3 } {
	append header [format {%-6d} [set $i]]
    }
    # Final line break
    append header "\n"
    

    tpBufAddHdr "Pragma" "no-cache"
    tpBufAddHdr "Content-Type" "text/plain"

    tpBufWrite $header
    tpBufWrite $record
    return
}
