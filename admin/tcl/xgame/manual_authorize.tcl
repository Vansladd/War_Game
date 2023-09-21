# ==============================================================
# $Id: manual_authorize.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc H_GoManualAuthorize {} {
    
    global xgaQry

    if [catch {set rs [xg_exec_qry $xgaQry(get_unauthorized)]} msg ] {
	return [handle_err "get_unauthorized"\
		"error: $msg"]
    }
    set cols {xgame_sub_id cr_date username balance picks\
	    sort num_subs stake_per_bet}
    xg_bind_rs $rs "" $cols
    db_close $rs
    X_play_file "manual_auth.html"
}

proc DoManualAuthorize {} {
    global xgaQry DB
    
    # Work out the next draws for each game

    foreach s "CPBUST3 PBUST3 PBUST4" {
	
	if [catch {set rs [xg_exec_qry $xgaQry(get_xgame_for_sort) $s]} msg ] {
	    return [handle_err "get_xgame_for_sort"\
		    "error: $msg"]
	}

	if {[db_get_nrows $rs]==0} {
	    set draw_at($s) "next week"
	} else {
	    set draw_at($s) [db_get_col $rs 0 draw_at]
	}
	db_close $rs
    }


    # Get the unauthorized subs

    if [catch {set rs [xg_exec_qry $xgaQry(get_unauthorized)]} msg ] {
	return [handle_err "get_unauthorized"\
		"error: $msg"]
    }

    set nrows [db_get_nrows $rs]
    set custdata(ids) ""

    for {set r 0} {$r < $nrows} {incr r} {
	
	#inf_begin_tran $DB

	set rb 0
	set bet_id 		[db_get_col $rs $r xgame_sub_id]
	set cust_id 		[db_get_col $rs $r cust_id]
	#set cust_acct_id 	[db_get_col $rs $r acct_id]
	set token_value 	[db_get_col $rs $r token_value]
	set stake 		[expr "(([db_get_col $rs $r stake_per_bet]*([db_get_col $rs $r num_subs] - [db_get_col $rs $r free_subs])) - $token_value)"]

	if {$stake < 0} {
		set stake 0
	}

	# Create a description for pStakeDebit if we are using FreeBet tokens
	if { $token_value != 0} {
		set desc "$token_value value token(s) used"
	} else {
		set desc ""
	}
	
	if [catch [xg_exec_qry $xgaQry(authorise) $bet_id $stake $desc] msg] {
	    set authorised 0
	} else {
	    set authorised 1
	}
	
	if {[lsearch $custdata(ids) $cust_id]==-1} {

	    foreach x "email fname lname mobile" {
		set custdata($cust_id,$x) [db_get_col $rs $r $x]
	    }
	    
	    lappend custdata(ids) $cust_id
	}

	set id 				[db_get_col $rs $r xgame_sub_id]
	set picks 			[join [split [db_get_col $rs $r picks] "|"] ","]
	set game_name 		[db_get_col $rs $r game_name]
	set num_subs 		[db_get_col $rs $r num_subs]
	set sort 			[db_get_col $rs $r sort]
	set no_funds_email 	[db_get_col $rs $r no_funds_email]
	set xgame_sub_id	[db_get_col $rs $r xgame_sub_id]
	
	# Bung it all into a text string for email.tcl to process
	if [info exists draw_at($sort)] {
	    set this_draw_at $draw_at($sort)
	} else {
	    set this_draw_at "unknown date"
	}
	lappend custdata($cust_id,subtext) "$id|$picks|$game_name|$num_subs|$sort|$draw_at($sort)"
	lappend custdata($cust_id,subtext) $no_funds_email $xgame_sub_id $authorised
    }
    
    db_close $rs
    
    # Now actually send out the SMS/emails
    SendMessages custdata
    
    H_GoManualAuthorize

}


proc H_GoManualAuthorizeForm {} {
    
    set submitName [reqGetArg submitName]
    
    if {$submitName == "Authorise these subscriptions"} {
	DoManualAuthorize
    }
    if {$submitName == "Void Selected Bets"} {
	VoidSelectedBets
    }
    if {$submitName == "Refresh"} {
	H_GoManualAuthorize
    }
}
