# $Id: settle.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

#
#	Initial versions of xgames use the tXGameDividends
#   table, each having their own wee way of interpreting those fields..
#	See below....
#
proc settle_with_game_dividends {sort results xgame_id} {

	global xgaQry
	global DIVIDEND

	foreach p [split $results "|"] {
	    set result($p) 1

	    ## Keep a tally of how many of the myth & PREMIER10 matches have void result
	    ## 3 = void (MYTH)
	    ## V = void (PREMIER10)
		## V = void (GOALRUSH)
	    if {$sort=="MYTH" && [string range $p 1 1] == 3} {
			incr void_count
	    } elseif {$sort == "PREMIER10" && [string range $p 0 0] == "V"} {
			incr void_count
	    } elseif {$sort == "GOALRUSH" && [string range $p 1 1] == "V"} {
			incr void_count
		}
	}


	## if premier10 game, get all the dividends (stored in global array DIVIDEND)
	if {$sort == "PREMIER10"} {
	    if [catch {set rs [xg_exec_qry $xgaQry(get_dividends) $xgame_id]} msg] {
		return [handle_err "get_dividends" "error: $msg"]
	    }
	    set DIVIDEND(total) [db_get_nrows $rs]
	    if {$DIVIDEND(total) == 0} {
		db_close $rs
		return [handle_err "No dividends" "There are no dividends for this game"]
	    }
	    for {set i 0} {$i < 10} {incr i} {
		set DIVIDEND($i,prizes) 0
	    }
	    for {set i 0} {$i < $DIVIDEND(total)} {incr i} {
		set DIVIDEND([db_get_col $rs $i points],prizes) [db_get_col $rs $i prizes]
	    }
	    db_close $rs
	}


	## Get the unsettled bets
	if [catch {set rs [xg_exec_qry $xgaQry(get_unsettled) $xgame_id]} msg] {
		return [handle_err "get_unsettled"\
				"error: $msg"]
	}
	set nrows [db_get_nrows $rs]
	if {$nrows==0} {
		return [handle_err "No bets" "There are no unsettled bets for this game"]
	}


	for {set r 0} {$r < $nrows} {incr r} {
		set bet_id	[db_get_col $rs $r xgame_bet_id]
		set picks	[db_get_col $rs $r picks]
		set stake	[db_get_col $rs $r stake]
		if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
			## Max card payout and max payout are in GBP
			## Winnings will by in customers registered currency
			## Convert max payouts to customer's currency
			set ccy_code    [db_get_col $rs $r ccy_code]
			set max_card_payout [db_get_col $rs $r max_card_payout]
			set max_payout  [db_get_col $rs $r max_payout]
			set exch_rate   [db_get_col $rs $r exch_rate]
			if {$max_card_payout > 0} {
				set max_card_payout_converted [expr {$max_card_payout * $exch_rate}]
			}
			if {$max_payout > 0} {
				set max_payout_converted [expr {$max_payout * $exch_rate}]
			}
		}

		set num_picks [llength [split $picks "|"]]


		set ball_count 0
		foreach p [split $picks "|"] {
			if {[info exists result($p)]} {
				incr ball_count
			}
		}

		# get_dividend to return mulitpier, not to take in stake
		set dividend_multiplier [get_dividend $sort $ball_count $void_count]

		# calculate winnings by multiplying stake by dividend_multipier
		if {$dividend_multiplier!="REFUND"} {
			set winnings [expr {$dividend_multiplier * $stake}]
		} else {
			set winnings "REFUND"
		}
		OT_LogWrite 3 "$sort: Winnings for bet id $bet_id are $winnings"

		set refund   0
		if {$winnings=="REFUND"} {
		    set winnings 0
		    # premier 10 games may have a stake of 1, 2, 5 or 10
		    if {$sort == "PREMIER10"} {
			set refund [db_get_col $rs $r stake]
		    } else {
			set refund "1.00"
		    }
		}
		if {([OT_CfgGet OPENBET_CUST ""] == "BlueSQ") && ($max_card_payout > 0) && ($winnings > $max_card_payout_converted)} {
			##If a bluesq user wins more than max_card_payout
			##they will be paid by cheque.
			##Do not credit winnings back to account
			set paymethod "C"
		} else {
			# Pay back into account
			set paymethod "O"
		  }
		## If customer has won more than max_payout settle the bet
		## with max_payout as the amount of winnings
		if {([OT_CfgGet OPENBET_CUST ""] == "BlueSQ") && ($max_payout > 0) && ($winnings > $max_payout_converted)} {
			set winnings $max_payout_converted
		}

		if [catch [xg_exec_qry $xgaQry(settle_bet) $bet_id $winnings $refund $paymethod] msg ] {
			lappend errors $msg
		}
	}

	db_close $rs
	return $nrows
}

proc get_dividend {sort ball_count void_count {stake ""}} {

    global DIVIDEND

    switch -- $sort {
	L400 {
	    if {$ball_count == "3"} {
		return 400
	    }
	}
	L4000 {
	    if {$ball_count == "4"} {
		return 4000
	    }
	}
	TOPSPOT {
	    if {$ball_count == "4"} {
		return 1000
	    }
	    if {$ball_count == "3"} {
		return 25
	    }
	}
	BIGMATCH {
	    if {$ball_count == "5"} {
		return 1000
	    }
	    if {$ball_count == "4"} {
		return 20
	    }
	}
	MYTH {
	    set possibility "$ball_count|$void_count"
	    switch -- $possibility {
		"8|0" { return 1000 }
		"7|0" { return 25 }
		"7|1" { return 250 }
		"6|2" { return 100 }
		"5|3" { return 40 }
		"4|4" { return 20 }
		"3|5" { return 10 }
	    }
	    if {$void_count > 5 } {
		return "REFUND"
	    }
	}
	GOALRUSH {

		if {$void_count >= 4} {
			return "REFUND"
		}
		set possibility "$ball_count|$void_count"
		switch -- $possibility {
			"6|0" { return 1000 }
			"5|0" { return 50 }
			"4|0" { return 5 }
			"5|1" { return 200 }
			"4|1" { return 10 }
			"4|2" { return 25 }
			"3|3" { return 5 }
		}
	}
	PREMIER10 {
	    if {$void_count >= 5 } {
		return "REFUND"
	    }
	    set possibility "$ball_count|$void_count"
	    switch -- $possibility {
		"10|0" { return [expr {$DIVIDEND(10,prizes) / 10.00}] }
		"9|0"  { return [expr {$DIVIDEND(9,prizes) / 10.00}] }
		"8|0"  { return [expr {$DIVIDEND(8,prizes) / 10.00}] }
		"9|1"  { return [expr {($DIVIDEND(10,prizes)/ 10.00) * 0.5}] }
		"8|1"  { return [expr {($DIVIDEND(9,prizes) / 10.00) * 0.5}] }
		"8|2"  { return [expr {($DIVIDEND(10,prizes) / 10.00) * 0.25}] }
		"7|3"  { return [expr {($DIVIDEND(10,prizes) / 10.00) * 0.1}] }
		"6|4"  { return [expr {($DIVIDEND(10,prizes) / 10.00) * 0.05}] }
	    }
	}

  	PP1IR6 {
		if {$ball_count == "1"} {
			return 6
	    }
	}
	PP2IR6 {
		if {$ball_count == "2"} {
			return 46
	    }
	}
	PP3IR6 {
		if {$ball_count == "3"} {
			return 451
	    }
	}
	PP4IR6 {
		if {$ball_count == "4"} {
			return 4001
	    }
	}
	PP5IR6 {
		if {$ball_count == "5"} {
			return 45001
	    }
	}
	PP1IR7 {
		if {$ball_count == "1"} {
			return 5
	    }
	}
	PP2IR7 {
		if {$ball_count == "2"} {
			return 33
	    }
	}
	PP3IR7 {
		if {$ball_count == "3"} {
			return 251
	    }
	}
	PP4IR7 {
		if {$ball_count == "4"} {
			return 2251
	    }
	}
	PP5IR7 {
		if {$ball_count == "5"} {
			return 22001
	    }
	}
	PP1UK6 {
		if {$ball_count == "1"} {
			return 7
	    }
	}
	PP2UK6 {
		if {$ball_count == "2"} {
			return 61
	    }
	}
	PP3UK6 {
		if {$ball_count == "3"} {
			return 651
	    }
	}
	PP4UK6 {
		if {$ball_count == "4"} {
			return 7201
	    }
	}
	PP5UK6 {
		if {$ball_count == "5"} {
			return 111111
	    }
	}
	PP1UK7 {
		if {$ball_count == "1"} {
			return 6
	    }
	}
	PP2UK7 {
		if {$ball_count == "2"} {
			return 41
	    }
	}
	PP3UK7 {
		if {$ball_count == "3"} {
			return 351
	    }
	}
	PP4UK7 {
		if {$ball_count == "4"} {
			return 3001
	    }
	}
	PP5UK7 {
		if {$ball_count == "5"} {
			return 30001
	    }
	}

  }
  return 0
}

proc global_insert_outstanding_subs {{errout "HTML"}} {

	global DB ERROUT

	set ERROUT $errout

	# For each open active game place subscriptions into it

	set sql [subst {
		select xgame_id, sort, open_at from tXGame
		where status = 'A'
		and shut_at > CURRENT
		and open_at <= CURRENT
		order by sort, open_at
	}]

	if {[catch {set rs [xg_exec_qry $sql]} msg]} {
		unset ERROUT
		return [handle_err "Error getting open active games" "error: $msg"]
	}

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r<$nrows} {incr r} {
		OT_LogWrite 3 "Placing subs from [db_get_col $rs $r sort], xgame_id = [db_get_col $rs $r xgame_id]"
		process_subs_for_xgame [db_get_col $rs $r xgame_id]
	}
	db_close $rs

	unset ERROUT
}

proc setup_sub_warning_mails {warning_subs} {
        global EMAIL_TYPES xgaQry

	set cust_mail_type "XWAR"

        if [catch {set users [xg_exec_qry $xgaQry(get_users_with_outstanding_pbust_subs)]} msg ] {
                return [handle_err "get_users_with_outstanding_subs"\
                                "error: $msg"]
        }
        set sub_id_list [list]
        set num_users [db_get_nrows $users]
        for {set u 0} {$u < $num_users} {incr u} {
		set qry "select xgame_sub_id\
			from   tXGameSub\
			where  acct_id = [db_get_col $users $u acct_id]\
			and    xgame_sub_id in $warning_subs"
		db_store_qry get_subs_for_user $qry
                if [catch {set sub_ids [db_exec_qry get_subs_for_user]} msg] {
                        return [handle_err "get_subs_for_user"\
                                "error: $msg"]
                }
                set num_subs [db_get_nrows $sub_ids]
                for {set s 0} {$s < $num_subs} {incr s} {
                        lappend sub_id_list [db_get_col $sub_ids $s xgame_sub_id]
                }
		set ref_id [join $sub_id_list "|"]

		if {$ref_id != ""} {
			if [catch {set rs [xg_exec_qry $xgaQry(get_cust_id_for_user) [db_get_col $users $u acct_id]]} msg] {
				return [handle_err "get_cust_id_for_user"\
					"error: $msg"]
			}
			set cust_id [db_get_col $rs 0 cust_id]

			ins_cust_mail $cust_mail_type $cust_id $ref_id
		}
        }

}

proc setup_sub_expired_mails {expired_subs} {
	global EMAIL_TYPES xgaQry

	set cust_mail_type "XEXP"

	if [catch {set users [xg_exec_qry $xgaQry(get_users_with_outstanding_pbust_subs)]} msg ] {
		return [handle_err "get_users_with_outstanding_subs"\
				"error: $msg"]
	}
	set sub_id_list [list]
	set num_users [db_get_nrows $users]
	for {set u 0} {$u < $num_users} {incr u} {
	        set qry "select xgame_sub_id\
                         from   tXGameSub\
                         where  acct_id = [db_get_col $users $u acct_id]\
                         and    xgame_sub_id in $expired_subs"
		db_store_qry get_subs_for_user $qry
                if [catch {set sub_ids [db_exec_qry get_subs_for_user]} msg] {
			 return [handle_err "get_subs_for_user"\
				"error: $msg"]
		}
		set num_subs [db_get_nrows $sub_ids]
		for {set s 0} {$s < $num_subs} {incr s} {
			lappend sub_id_list [db_get_col $sub_ids $s xgame_sub_id]
		}
		set ref_id [join $sub_id_list "|"]

		OT_LogWrite 1 "Expired Subs for user [db_get_col $users $u acct_id] = $sub_id_list"

		if {$ref_id != ""} {
                	if [catch {set rs [xg_exec_qry $xgaQry(get_cust_id_for_user) [db_get_col $users $u acct_id]]} msg] {
                        	return [handle_err "get_cust_id_for_user"\
                                        "error: $msg"]
                	}
                	set cust_id [db_get_col $rs 0 cust_id]

			ins_cust_mail $cust_mail_type $cust_id $ref_id
		}
	}

}

proc SendMessages {custdata} {

	global xgaQry
	upvar $custdata cdata

	foreach {id} $cdata(ids) {

		set authorized_rows {}
		set unauthorized_rows {}

		foreach {row no_funds_email sub_id auth} $cdata($id,subtext) {


			if {$auth==1} {
				# row has been authorised
				lappend authorized_rows $row

			} else {
				# row not authorised check if email already sent for this row
				if {$no_funds_email=="N"} {
					lappend unauthorized_rows $row

					# record email has been sent
					if [catch [xg_exec_qry $xgaQry(no_funds_email_sent) $sub_id] msg] {
						#return [handle_err "VoidSelectedBets blurb" "error: $msg"]
					}
				}
			}
		}

		if {$cdata($id,email)!=""} {
			# email customer
			if {[llength $authorized_rows]>0} {
				email_on_sub_authorize $cdata($id,email) $cdata($id,fname) $cdata($id,lname) $authorized_rows
			}
			if {[llength $unauthorized_rows]>0} {
				email_on_sub_error $cdata($id,email) $cdata($id,fname) $cdata($id,lname) $unauthorized_rows "insufficient funds in your account"
			}

		} elseif {$cdata($id,mobile)!=""} {
			# sms customer
			if {[llength $authorized_rows]>0} {
				sms_on_sub_authorize $cdata($id,mobile) $authorized_rows
			}
			if {[llength $unauthorized_rows]>0} {
				sms_on_sub_error $cdata($id,mobile) $unauthorized_rows "insufficient funds in your account"
			}
		}
    }
}

proc VoidSelectedBets {} {

	global xgaQry

	set x_game_sub_ids [reqGetArgs void]

    OT_LogWrite 5 "Voiding bets $x_game_sub_ids"

	foreach sub_id $x_game_sub_ids {

		OT_LogWrite 7 "Voiding subscription with xgame_sub_id = $sub_id"

		if [catch [xg_exec_qry $xgaQry(void) $sub_id] msg] {
			return [handle_err "VoidSelectedBets blurb"\
				"error: $msg"]
		}
	}

	H_GoManualAuthorize
}
