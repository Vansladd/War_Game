# ==============================================================
# $Id: import_VERNONS.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc xgame_import_file {} {
	global DB
    global xgaQry
    global sort_codes

	global USERID

    set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]
    set filename "$UPLOAD_DIR/xgame/[reqGetArg FullName]"

    if {[catch {set file [open $filename r]} fileId]} {
		return [handle_err "File Error" "$fileId"]
    }
    
    set header [gets $file]
    set line 1
    set total_winnings 0.00
	
    foreach s [array names sort_codes] {
		set count($sort_codes($s)) 0
		set win($sort_codes($s))   0.00
    }
	
	# Process the header. For Vernons this is a simply an integer
	# counting the number of bets settled by this file.
	
	set header_bet_count [string trim $header]
	if {![string is integer $header_bet_count]} {
		return [handle_err "Failed to parse header" "Header is not an integer"]
	}
	if {$header_bet_count<=0.0} {
		return [handle_err "Failed to parse header" "Header claims that there are no records in this file. Giving up now."]
	}
	
	
    set header_info "Processing file containing $header_bet_count bets"
    
	
	set bet_count 0

	# Paranoia. Don't want tainted data from last run.
	foreach x {a_xgame_bet_id\
			a_winner\
			a_winnings\
			a_paymethod\
			a_acct_id\
			a_comp_no} {
		if {[info exists $x]} {
			unset $x
		}
	}

	set bet_detail_sql {
		select
		    a.ccy_code,
            c.exch_rate,
            g.sort,
            b.stake
        from
            tCcy c,
            tAcct a,
            tXGameBet b,
            tXGameSub s,
            tXGame    g
        where   a.ccy_code = c.ccy_code
        and     b.xgame_id = g.xgame_id
        and     b.xgame_sub_id = s.xgame_sub_id
        and     s.acct_id = a.acct_id
        and     a.acct_id = ?
        and     b.xgame_bet_id = ?
		and     s.xgame_sub_id = ?
		and     g.comp_no      = ?
	}

	set bet_detail_stmt [inf_prep_sql $DB $bet_detail_sql]
	

    while {1} {
		
		set record [gets $file]
		
		if {$record=="" && [eof $file]} {
			break
		}

		incr line
		
		if {$record==""} {
			return [handle_err "Unexpected end of file"\
					"Found empty line (line $line)"]
		}
		
		set reclist [split $record ","]
		
		# Check right number of records in line
		if {[llength $reclist]!=7} {
			return [handle_err "Bad data record"\
					"Data record contains wrong number of elements at line $line"]
		}
		
		foreach {idx nm} {0 xgame_bet_id\
				1 xgame_sub_id\
				2 comp_no\
				3 acct_id\
				4 winner\
				5 winnings\
				6 paymethod} {
			set $nm [lindex $reclist $idx]
		}
		
		# Cursory glance to check for obvious mismatching of records
		foreach x {xgame_bet_id xgame_sub_id comp_no acct_id winnings} {
			if {![string is integer [set $x]]} {
				return [handle_err "Bad record"\
						"$x at line $line is not an integer"]
			}
		}
		

		if {$paymethod!="" && $paymethod!="C" && $paymethod!="O"} {
			return [handle_err "Bad record"\
					"Undefined payment method at line $line"]
		}
		
		# Hack - The database refers to cheques as code 'L' for historical reasons.
		if {$paymethod=="C"} {
			set paymethod L
		}


		if {$winner!="W" && $winner!="L"} {
			return [handle_err "Bad record"\
					"Undefined winner field at line $line"]
		}
		

		# If the bet is a loser then there is no paymethod
		if {$winner=="L"} {
			set paymethod O
		}

		

		set a_xgame_bet_id($line) $xgame_bet_id
		set a_xgame_sub_id($line) $xgame_sub_id
		set a_winner($line)       $winner
		set a_winnings($line)     $winnings
		set a_paymethod($line)    $paymethod
		set a_acct_id($line)      $acct_id
		set a_comp_no($line)      $comp_no
		incr bet_count

	# end while loop reading data records	
	} 
	
	# Check everything adds up to what it says in the header
	
	if {$bet_count != $header_bet_count} {
		return [handle_err "Number of records mismatch"\
				"There are $bet_count bets in this file yet the header claims there are $header_bet_count"]
    }
	

	#
    # Seems safe to start processing
	#

    
    tpBufAddHdr "Content-Type" "text/plain"
    tpBufWrite "$header_info\n"
	
    # Line 1 is the header
    for {set r 2} {$r <= $line} {incr r} {
		OT_LogWrite 1 "Settling bet_id $a_xgame_bet_id($r) which is a $a_winner($r) with winnings $a_winnings($r) by method $a_paymethod($r)"
		
		if {$a_winner($r)=="L"} {
			set amount 0.00
			set refund 0.00
		} else {
			switch -- $a_paymethod($r) {
				L { 
					set amount 0.00
					set refund 0.00
				}
				O {
					set amount $a_winnings($r)
					set refund 0.00
				}
				default {
					return [handle_error "Internal error"\
							"Undefined paymethod at line $r"]
				}
			}
		}
		
		
		# Convert amount/refund to user's currency
		
		# If it's a Pools type game, returned an amount of winnings
		# Vernons used to tell us the game sort for this bet in the file,
		# but now we need to do a DB qry for it. Will perhaps be
		# performance bottleneck in the long run.

		if {[catch {set rs [inf_exec_stmt $bet_detail_stmt $a_acct_id($r) $a_xgame_bet_id($r) $a_xgame_sub_id($r) $a_comp_no($r)]} msg]} {
			OT_LogWrite 1 "failed to retrieve bet_and__exch_rate:$msg"
			tpBufWrite "Unable to settle bet_id $a_xgame_bet_id($r). This bet remains unsettled: $msg\n"
			continue
		}
		
		if {[db_get_nrows $rs]!=1} {
			return [handle_err "Serious error"\
					"No record of acct_id $a_acct_id($r) placing xgame bet $a_xgame_bet_id($r) with sub_id $a_xgame_sub_id($r) in comp_no $a_comp_no($r) at line $r. Aborting execution. No further bets in this file will be processed."]
		}
		
		set sort [db_get_col $rs sort]
		set exch_rate [db_get_col $rs 0 exch_rate]
		set bet_stk [db_get_col $rs stake]
		set ccy_code [db_get_col $rs ccy_code]
		
		db_close $rs
		
		if {$sort=="VPOOLSM" || $sort=="VPOOLS11" || $sort=="VPOOLS10" } {
			# Pools type game, so need to convert winnings into punter's
			# local currency. Vernons pass us the amount in pence (sterling)
			# so it's quite important here to divide by 100.
			set amount [expr "double($amount)*double($exch_rate)/100.00"]
			set refund 0.00
		} else {
			# Otherwise for Lottery games returns a stake multiplier	
			set amount [expr "double($bet_stk)*double($amount)"]
			set refund 0.00
		}
		
		if {[catch {xg_exec_qry $xgaQry(settle_bet) $a_xgame_bet_id($r) $amount $refund $a_paymethod($r) $USERID} msg]} {
			tpBufWrite "Unable to settle bet_id $a_xgame_bet_id($r): $msg\n"
		} else {
			tpBufWrite "Settled bet_id $a_xgame_bet_id($r) with winnings ${ccy_code}[format %0.2f $amount]\n"
		}
		
    }
	
	inf_close_stmt $bet_detail_stmt

    tpBufWrite "\n\nExternal Settlement complete\n"
	tpBufWrite "$bet_count bets processed.\n"

}
