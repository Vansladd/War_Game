# ==============================================================
# $Id: prices.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

# show price history search criteria...
proc H_GoPriceHistory {} {

	global XGAME_TYPES
    
    OT_LogWrite 1 "Generating Report of historical prices"

    set sort [reqGetArg sort]

    bind_game_type_dropdown

    X_play_file prices.html
}

proc H_DoPriceHistory {} {
    
    OT_LogWrite 1 "Generating Report"

    set sort	  [reqGetArg sort]
    set startDate [reqGetArg fromDate]
    set startTime [reqGetArg startTime]

    if {$startDate == ""} {
	# retrieve all price history
	Bind_Price_Report $sort

    } else {
		# Strip out whitespace and all the other crap
	       foreach x {startDate startTime } {
		regsub -all {[^0-9\:\-]} [set $x] "" $x
		 if {[set $x]==""} {
		     handle_err "Field missing" "$x not specified"
		 }
	        }
	    set start "$startDate $startTime"
	    Bind_Price_Report $sort $start
    }


    X_play_file pricehistory.html

}

proc H_DoPriceHistoryOld {} {
    
    OT_LogWrite 1 "Generating Report"


    set sort	  [reqGetArg sort]
    set startDate [reqGetArg fromDate]
    set startTime [reqGetArg startTime]

    if {$startDate == "" && $endDate == ""} {
	# retrieve all price history
	Bind_Price_Report $sort

    } elseif {$endDate != ""} {
	       # Strip out whitespace and all the other crap
	       foreach x {startDate endDate startTime endTime} {
		regsub -all {[^0-9\:\-]} [set $x] "" $x
		 if {[set $x]==""} {
		     handle_err "Field missing" "$x not specified"
		 }
	        }

	    set start "$startDate $startTime"
	    set end   "$endDate $endTime"
	    Bind_Price_Report $sort $start $end

    } else {
		# Strip out whitespace and all the other crap
	       foreach x {startDate startTime } {
		regsub -all {[^0-9\:\-]} [set $x] "" $x
		 if {[set $x]==""} {
		     handle_err "Field missing" "$x not specified"
		 }
	        }
	    set start "$startDate $startTime"
	    Bind_Price_Report $sort $start $start
    }


    X_play_file pricehistory.html

}

proc Bind_Price_Report {sort {valid_at ""}} {

    global xgaQry

    tpBindString SORT $sort

    if {$valid_at==""} {
	    # Retrieve all price history information
	    if [catch {set rs [xg_exec_qry $xgaQry(get_full_price_history) $sort]} msg ] {
			return [handle_err "get_full_price_history"\
					"error: $msg"]
	    }

    } else {
	    # Retrieve prices valid during given time period
	    if [catch {set rs [xg_exec_qry $xgaQry(get_snapshot_price_history) $sort $valid_at $valid_at]} msg ] {
			return [handle_err "get_snapshot_price_history"\
					"error: $msg"]
	    }

    }



   xg_bind_rs $rs
	
   db_close $rs

}



