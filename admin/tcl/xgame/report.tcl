# ==============================================================
# $Id: report.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc H_GoReport {} {

	tpBindString DEFAULT_DATE [clock format [clock seconds] -format "%Y-%m-%d"]
	X_play_file reports.html
}
proc H_DoReport {} {
    
    OT_LogWrite 1 "Generating Report"

    set sort [reqGetArg sort]
	set breakdown [reqGetArg breakdown]

	switch -- $sort {
	  "Generate Game Report" {
		game_report $breakdown
	  }
	  "Generate Subscriptions Report" {
		subscription_report $breakdown
	  }
	}
}

proc game_report {breakdown} {
	global xgaQry
	set qry_name "game_report"
	if {$breakdown==1} {
		tpSetVar BREAKDOWN 1
		append qry_name "_ca"
		set cols {draw_at sort comp_no source aff_id number_bets total_stake total_refunds total_winnings number_refunds number_paymethod_o number_paymethod_l number_paymethod_f number_paymethod_p open_at shut_at xgame_id}
	} else {
		tpSetVar BREAKDOWN 0
		set cols {draw_at sort comp_no number_bets total_stake total_refunds total_winnings number_refunds number_paymethod_o number_paymethod_l number_paymethod_f number_paymethod_p open_at shut_at xgame_id}
	} 

    DoGameReport "betreport.html" $xgaQry($qry_name) $cols

}

proc subscription_report {breakdown} {
	global xgaQry
	set qry_name "subs_qry"
	if {$breakdown==1} {
		tpSetVar BREAKDOWN 1
		append qry_name "_ca"
		set cols {sort source aff_id total_subs total_entries total_takings}
	} else {
		tpSetVar BREAKDOWN 0
		set cols  {sort total_subs total_entries total_takings}
	}
	
    DoGameReport "subsreport.html" $xgaQry($qry_name) $cols

}



proc DoGameReport {filename qry {columns}} {

    set startDate [reqGetArg fromDate]
    set endDate [reqGetArg toDate]
    set startTime [reqGetArg startTime]
    set endTime [reqGetArg endTime]

    # Strip out whitespace and all the other crap
    foreach x {startDate endDate startTime endTime} {
	regsub -all {[^0-9\:\-]} [set $x] "" $x
	if {[set $x]==""} {
	    handle_err "Field missing" "$x not specified"
	}
    }

    set start "$startDate $startTime"
    set end   "$endDate $endTime"

    OT_LogWrite 10 "startDate = $startDate"
    OT_LogWrite 10 "endTime = $endTime"



    tpBindString START $start
    tpBindString END $end

    if [catch {set rs [xg_exec_qry $qry $start $end]} msg] {
	return [handle_err "game_report"\
		    "error: $msg"]        
    }

    xg_bind_rs $rs "" $columns

   # Format appropriate rows to 2 decimal places 
   if {$filename == "betreport.html"} {
	xg_bind_rs_format $rs "" {total_stake total_refunds total_winnings}
   }
   if {$filename == "subsreport.html"} {
	xg_bind_rs_format $rs "" {total_takings}
   }
   
   Debug_Read_Rs $rs

  
    X_play_file $filename
}




#
#	Formats to 2 decimal places
#
proc xg_bind_rs_format {rs {key ""} {cols ""}} {

    global XG_RS

    # Prevent playing old data in case of failure.
    tpSetVar ${key}nrows 0

    set nrows [db_get_nrows $rs]

    if {$key!=""} {set key "${key}_"}

    tpSetVar ${key}nrows $nrows

    if {$cols==""} {set cols [db_get_colnames $rs]}

    for {set r 0} {$r<$nrows} {incr r} {
	foreach col $cols {
	    set XG_RS($r,${key}${col}) [format {%.2f} [db_get_col $rs $r $col]]
	    tpBindVar ${key}${col} XG_RS ${key}${col} idx
	}
    }
}



proc Debug_Read_Rs {rs {colnames {}}} {
	OT_LogWrite 10 "\n\n Debug_Read_Rs started >> "
	
	variable SCRIPT
	
	if {$colnames == {}} {
		set colnames [db_get_colnames $rs]
	} 


	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {

			for {set r 0} {$r<$nrows} {incr r} {
				foreach c $colnames {
					if [catch {set value  [db_get_col $rs $r $c]} msg] {
					    OT_LogWrite 10 " error retrieving values for column $c: $msg" 
					} else {
						OT_LogWrite 10 "colname<$c> = $value"
					}
				}
			}
	} 
	# else return nothing
	
	OT_LogWrite 10 "<< Debug_Read_Rs ended \n\n "
}


