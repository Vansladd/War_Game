# ==============================================================
# $Id: cust_txn.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUST_TXN {

asSetAct ADMIN::CUST_TXN::DoTxnQuery   [namespace code do_txn_query]

#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_txn_query args {

	global DB JTYPE

	set CustId [reqGetArg CustId]

	set sql {
		select
			c.username,
			c.acct_no,
			a.ccy_code,
			a.balance + a.sum_ap as balance,
			a.acct_id
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id = ? and
			c.cust_id = a.cust_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $CustId]

	inf_close_stmt $stmt

	tpBindString CustId     $CustId
	tpBindString Username   [db_get_col $res 0 username]
	tpBindString AcctNo     [db_get_col $res 0 acct_no]
	tpBindString CCYcode    [db_get_col $res 0 ccy_code]
	tpBindString Balance    [db_get_col $res 0 balance]
	tpBindString AcctId     [db_get_col $res 0 acct_id]

	db_close $res

	get_jrnl_descs

	tpBindVar JOpType JTYPE op_type op_type_idx
	tpBindVar JOpName JTYPE op_name op_type_idx

	asPlayFile -nocache cust_txn_query.html
}

#
# ----------------------------------------------------------------------------
# Get journal tag descriptions
# ----------------------------------------------------------------------------
#
proc get_jrnl_descs args {

	global DB JTYPE JREFKEY

	set sql {
		select
			j_op_type,
			j_op_name
		from
			tJrnlOp
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {
		set t [db_get_col $res $r j_op_type]
		set n [db_get_col $res $r j_op_name]

		set JTYPE($t) $n

		set JTYPE($r,op_type) $t
		set JTYPE($r,op_name) $n
	}

	tpSetVar NumOpTypes $n_rows

	set sql {
		select
			j_op_type,
			j_op_ref_key,
			j_op_name
		from
			tJrnlRefKey
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {

		set t [db_get_col $res $r j_op_type]
		set k [db_get_col $res $r j_op_ref_key]
		set n [db_get_col $res $r j_op_name]

		set JREFKEY($t,$k) $n
	}

	db_close $res
}

#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc do_txn_query {{cpm_id -1} {is_pmb 0}} {

	global DB JTYPE JRNL JREFKEY

	if {[set TxnsPerPage [reqGetArg TxnsPerPage]] == ""} {
		set TxnsPerPage 25
	}

	if {$cpm_id == -1} {
		set cpm_id [reqGetArg CpmId]
	}

	tpBindString AcctId      [set AcctId      [reqGetArg AcctId]]
	tpBindString CustId      [set CustId      [reqGetArg CustId]]
	tpBindString Username    [set Username    [reqGetArg Username]]
	tpBindString AcctNo      [set AcctNo      [reqGetArg AcctNo]]
	tpBindString TxnsPerPage $TxnsPerPage
	tpBindString HiCrDate    [set HiCrDate    [reqGetArg HiCrDate]]
	tpBindString LoCrDate    [set LoCrDate    [reqGetArg LoCrDate]]
	tpBindString NextPMB     [set NextPMB     [reqGetArg NextPMB]]
	tpBindString PrevPMB     [set PrevPMB     [reqGetArg PrevPMB]]
	tpBindString JrnlOpType  [set JrnlOpType  [reqGetArg JrnlOpType]]
	tpBindString StartBal    [set StartBal    [reqGetArg StartBal]]
	tpBindString PrevBal     [set PrevBal    [reqGetArg PrevBal]]
	tpBindString CpmId       $cpm_id

	set sort [reqGetArg SubmitName]

	if {$sort == "NewSearch"} {
		go_txn_query
		return
	}
	if {$sort == "Customer" || $sort == "Back"} {
		ADMIN::CUST::go_cust cust_id $CustId
		return
	}

	if {$sort == "GoCustSimpleTotals"} {
		tpBindString back "TxnQuery"
		ADMIN::CUST_TOTALS::go_cust_simple_totals
		return
	}

	set where_dt ""
	set where_jt ""

	if {$sort == "First"} {
		set dt1 [reqGetArg TxnDate1]
		set dt2 [reqGetArg TxnDate2]

		if {($dt1 != "") || ($dt2 != "")} {
			set where_dt " and [mk_between_clause j.cr_date date $dt1 $dt2]"
			if {$cpm_id > 0} {
				set where_pmt_dt " and [mk_between_clause p.cr_date date $dt1 $dt2]"
			}
		}
		set order desc
	} elseif {$sort == "Next"} {
		set where_dt " and j.cr_date < '$LoCrDate'"
		set order desc
		if {$cpm_id > 0} {
			set where_pmt_dt " and p.cr_date  < '$LoCrDate'"
		}
	} else {
		set where_dt " and j.cr_date > '$HiCrDate'"
		set order asc
		if {$cpm_id > 0} {
			set where_pmt_dt " and p.cr_date  > '$HiCrDate'"
		}
	}

	if {$JrnlOpType != ""} {
		set where_jt " and j.j_op_type = '$JrnlOpType'"
	} else {
		set where_jt ""
	}

	if {$is_pmb} {
		set where_status " and ( \
				(p.payment_sort = 'D' and p.status = 'Y') \
				or \
				(p.payment_sort = 'W' and p.status in ('Y', 'P')) \
			)"

		set where_man_adj_status " and ( \
				(p.payment_sort = 'D' and p.status in ('Y', 'N')) \
				or \
				(p.payment_sort = 'W' and p.status in ('Y', 'P', 'N')) \
			)"

	} else {
		set where_status " and p.status in ('Y', 'P')"
		set where_man_adj_status " and p.status in ('Y', 'P', 'N')"
	}

	array set JRNL [list]

	get_jrnl_descs

	#
	# Some customers have *lots* of bets, so we need to be very careful
	# to make sure that the queries examine *exactly* the minimum set
	# of rows in the journal. Any naivete in the queries will be
	# punished...
	#
	# tJrnl is indexes (acct_id,cr_date), and this is the only index
	# which involves acct_id, so we will take a circuitous route which
	# forces queries to use this index...
	#

	#
	# First: given whatever criteria we have, get the first N rows
	# back, ordered by date. We just want the dates, because we will
	# plug these back into the next query to get the actual data -
	# we need to do this because there can be multiple rows per
	# date and we don't want to miss any...
	#
	if {$cpm_id > 0} {
		set sql [subst {
			select first $TxnsPerPage
				$AcctId as acct_id,
				p.cr_date
			from
				tCustPayMthd cpm,
				tCPMGroupLink l1,
				tCPMGroupLink l2,
				tPmt p
			where
				cpm.cpm_id  = ?
				and cpm.cust_id = ?
				and l1.cpm_id = cpm.cpm_id
				and l2.cpm_grp_id = l1.cpm_grp_id
				and p.cpm_id = l2.cpm_id
				$where_pmt_dt
				$where_status
			order by
				acct_id $order, cr_date $order
		}]

		# need to merge with manual adjustments that also may be contributing
		# to the balance
		set sql2 [subst {
			select first $TxnsPerPage
				$AcctId as acct_id,
				p.cr_date
			from
				tCustPayMthd  cpm,
				tCPMGroupLink l1,
				tCPMGroupLink l2,
				tPmt          p,
				tManAdj       m
			where
				cpm.cpm_id     = ?             and
				cpm.cust_id    = ?             and
				l1.cpm_id      = cpm.cpm_id    and
				l2.cpm_grp_id  = l1.cpm_grp_id and
				p.cpm_id       = l2.cpm_id     and
				m.ref_id       = p.pmt_id      and
				m.ref_key      = 'PMT'         and
				m.pending      = 'P'           and
				m.acct_id      = $AcctId
				$where_pmt_dt
				$where_man_adj_status
			order by
				acct_id $order, cr_date $order
		}]

	} else {
		set sql [subst {
			select first $TxnsPerPage
				j.acct_id,
				j.cr_date
			from
				tjrnl j
			where
				acct_id = $AcctId $where_dt $where_jt
			order by
				j.acct_id $order, j.cr_date $order
		}]
	}

	if {$cpm_id > 0} {
		set stmt_pmt [inf_prep_sql $DB $sql]
		set stmt_man [inf_prep_sql $DB $sql2]
		set res_pmt  [inf_exec_stmt $stmt_pmt $cpm_id $CustId]
		set res_man  [inf_exec_stmt $stmt_man $cpm_id $CustId]
		inf_close_stmt $stmt_pmt
		inf_close_stmt $stmt_man

		set res [db_create [list acct_id cr_date]]

		# add payment rows
		set nrows [db_get_nrows $res_pmt]
		for {set i 0} {$i < $nrows} {incr i} {
			set row [list]
			foreach c [list acct_id cr_date] {
				lappend row [db_get_col $res_pmt $i $c]
			}
			db_add_row $res $row
		}

		# add manual adjustment rows
		set nrows [db_get_nrows $res_man]
		for {set i 0} {$i < $nrows} {incr i} {
			set row [list]
			foreach c [list acct_id cr_date] {
				lappend row [db_get_col $res_man $i $c]
			}
			db_add_row $res $row
		}

		# now sort them
		db_sort [list cr_date string $order] $res

	} else {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $AcctId]
		inf_close_stmt $stmt
	}

	set n_rows [db_get_nrows $res]

	# may have more than maximum rows if cpm_id, so bump back to txns per page
	# if necessary
	set n_rows [expr {$n_rows > $TxnsPerPage ? $TxnsPerPage : $n_rows}]

	if {$n_rows > 0} {

		#
		# dates must be strictly ordered for "between" clause
		#
		if {$order == "asc"} {
			set dt_0 [db_get_col $res 0                  cr_date]
			set dt_1 [db_get_col $res [expr {$n_rows-1}] cr_date]
		} else {
			set dt_0 [db_get_col $res [expr {$n_rows-1}] cr_date]
			set dt_1 [db_get_col $res 0                  cr_date]
		}

		tpBindString LoCrDate $dt_0
		tpBindString HiCrDate $dt_1

		db_close $res

		if {$cpm_id > 0} {
			set sql [subst {
				select
					j.acct_id,
					j.cr_date,
					j.jrnl_id,
					j.j_op_type,
					j.j_op_ref_key,
					j.j_op_ref_id,
					j.amount,
					substr(j.desc,0,60) as desc,
					j.balance,
					'' as retro_date
				from
					tCustPayMthd cpm,
					tCPMGroupLink l1,
					tCPMGroupLink l2,
					tJrnl j,
					tPmt p
				where
					cpm.cpm_id  = ?
					and cpm.cust_id = ?
					and p.status in ('Y', 'P')
					and l1.cpm_id = cpm.cpm_id
					and l2.cpm_grp_id = l1.cpm_grp_id
					and p.cpm_id = l2.cpm_id
					and j.j_op_ref_key = 'GPMT'
					and j.j_op_ref_id = p.pmt_id
					and j.acct_id = $AcctId
					and p.cr_date between '$dt_0' and '$dt_1'

				union

				select
					$AcctId as acct_id,
					p.cr_date,
					-1 as jrnl_id,
					case
					when p.payment_sort = 'D'
						then 'Deposit'
					else
						'Withdrawal'
					end as j_op_type,
					'' as j_op_ref_key,
					p.pmt_id as j_op_ref_id,
					p.amount,
					'' as desc,
					0 as balance,
					'' as retro_date
				from
					tCustPayMthd cpm,
					tCPMGroupLink l1,
					tCPMGroupLink l2,
					tPmt p
				where
					cpm.cpm_id  = ?
					and cpm.cust_id = ?
					and p.status in ('Y', 'P')
					and l1.cpm_id = cpm.cpm_id
					and l2.cpm_grp_id = l1.cpm_grp_id
					and p.cpm_id = l2.cpm_id
					and p.cr_date between '$dt_0' and '$dt_1'
					and not exists (
						select
							j.j_op_ref_id
						from
							tJrnl j
						where
							j.j_op_ref_key = 'GPMT'
							 and j.j_op_ref_id = p.pmt_id)
				union

				select
					$AcctId as acct_id,
					j.cr_date,
					j.jrnl_id,
					j.j_op_type,
					j.j_op_ref_key,
					j.j_op_ref_id,
					j.amount,
					substr(j.desc,0,60) as desc,
					j.balance,
					'' as retro_date
				from
					tJrnl         j,
					tManAdj       m,
					tPmt          p,
					tCPMGroupLink l1,
					tCPMGroupLink l2,
					tCustPayMthd  cpm
				where
					j.acct_id      = $AcctId       and
					j.j_op_ref_key = 'MADJ'        and
					j.j_op_ref_id  = m.madj_id     and
					m.pending      = 'P'           and
					m.ref_key      = 'PMT'         and
					m.ref_id       = p.pmt_id      and
					p.cpm_id       = l2.cpm_id     and
					p.cr_date between '$dt_0' and '$dt_1' and
					l1.cpm_id      = cpm.cpm_id    and
					l1.cpm_grp_id  = l2.cpm_grp_id and
					cpm.cpm_id     = ?             and
					cpm.cust_id    = ?
				order by
					acct_id $order, cr_date $order
			}]

		} else {
			set sql [subst {
				select
					j.acct_id,
					j.cr_date,
					j.jrnl_id,
					j.j_op_type,
					j.j_op_ref_key,
					j.j_op_ref_id,
					j.amount,
					substr(j.desc,0,60) as desc,
					j.balance,
					nvl(case when (j.j_op_type = 'BSTK' or j.j_op_type = 'HSTK')
								and j.j_op_ref_key = 'ESB' then
						(select l.retro_date
							from
								tCall l,
								tBet  b
							where
								b.call_id= l.call_id and
								b.bet_id = j.j_op_ref_id
						)
					end, '') as retro_date

				from
					tjrnl j
				where
					j.cr_date between '$dt_0' and '$dt_1' and
					acct_id = $AcctId $where_jt
				order by
					j.acct_id $order, j.cr_date $order
			}]
		}

		set stmt [inf_prep_sql $DB $sql]
		if {$cpm_id > 0} {
			set res  [inf_exec_stmt $stmt $cpm_id $CustId $cpm_id $CustId $cpm_id $CustId]
		} else {
			set res  [inf_exec_stmt $stmt]
		}
		inf_close_stmt $stmt

		set n_rows [db_get_nrows $res]
	}

	tpSetVar NumTxns $n_rows

	if {$n_rows > 0} {

		set dt_0 [db_get_col $res [expr {$n_rows-1}]  cr_date]
		set dt_1 [db_get_col $res 0 cr_date]

		if {$order == "desc"} {

			#
			# We now work out balances not from the balance field in
			# tJrnl but by keeping a running total. Due to this, we always
			# pull the data out of the result set earliest item first
			# and then make sure the items are put in to the array in
			# the correct order (via row_inc and row) we have to work out
			# balances using a running total in order to make the correct
			# calculations for credit cstomers and antepost bets...
			#

			set l_start 0
			set l_op    <=
			set l_end   [expr {$n_rows-1}]
			set l_inc   1

			set date_to_use $dt_1

		} else {


			set l_start [expr {$n_rows-1}]
			set l_op    >=
			set l_end   0
			set l_inc   -1

			set date_to_use $dt_0

		}

		set running_balance [get_balance $AcctId $date_to_use]
		set acct_type       [get_account_type $AcctId]

		if {$acct_type == "CDT"} {
			set sum_ap          [get_sum_ap $AcctId $date_to_use]
			set running_balance [format %.2f [expr {$running_balance+$sum_ap}]]
		}

		# If this is the list of transactions that contribute to a PMB, set the initial balance
		if {$is_pmb} {

			set total_pmb [payment_multi::calc_cpm_pmb $CustId $cpm_id]
			if {[lindex $total_pmb 0] == 1} {
				set running_balance [format %.2f [lindex $total_pmb 1]]

			}

		} else {
			# TB2:QC 595: Ensure NextPMB is initialised
			if {$NextPMB == ""} {
				set NextPMB 0
			} else {

			set running_balance $NextPMB
			}
		}

		if {$sort == "Prev"} {
			set running_balance      $PrevPMB
			tpBindString StartBal    $PrevPMB
			tpBindString PrevPMB     [set PrevPMB [lindex $PrevBal end]]
			tpBindString PrevBal     [lrange $PrevBal 0 [expr [llength $PrevBal]-2]]

		} else {
			tpBindString PrevBal     [concat $PrevBal $PrevPMB]
			tpBindString PrevPMB     [set PrevPMB $StartBal]
			tpBindString StartBal    $running_balance
		}

		if {$PrevPMB == "" || $PrevPMB == 0.00} {
			tpBindString PrevDisable disabled
		}

		set row 0

		for {set r $l_start} {[expr "$r $l_op $l_end"]} {incr r $l_inc} {

			set JRNL($row,date)       [db_get_col $res $r cr_date]

			set t [db_get_col $res $r j_op_type]
			set k [db_get_col $res $r j_op_ref_key]

			set JRNL($row,op_type_code) $t

			if {[info exists JTYPE($t)]} {
				set JRNL($row,op_type) $JTYPE($t)
			} else {
				set JRNL($row,op_type) $t
			}
			if {[info exists JREFKEY($t,$k)]} {
				append JRNL($row,op_type) " ($JREFKEY($t,$k))"
			}
			set JRNL($row,op_ref_key) [string trim [string trim $k "-"] "+"]
			set JRNL($row,op_ref_id)  [db_get_col $res $r j_op_ref_id]
			set JRNL($row,amount)     [db_get_col $res $r amount]
			set JRNL($row,desc)       [ob_xl::XL en [db_get_col $res $r desc]]
			set JRNL($row,retrodate)  [db_get_col $res $r retro_date]
			set JRNL($row,manual) ""

			set adjustment $JRNL($row,amount)

			if {$t == "BSTK" && $JRNL($row,op_ref_key) == "ESB"} {
				#
				# Check if its an antepost stake.  If so adjust the amount,
				# so that is is reflected appropriately in the running balance.
				#
				set ap [check_ap_bet $t $JRNL($row,op_ref_key) $JRNL($row,op_ref_id)]

				if {[lindex $ap 0] > 0} {
					set adjustment  0
					append JRNL($row,desc) " AP Bet"
				}

			} elseif {($t == "BSTK" && $JRNL($row,op_ref_key) == "APAY")} {
				set ap [check_ap_bet $t $JRNL($row,op_ref_key) $JRNL($row,op_ref_id)]
				if {[lindex $ap 0] > 0} {
					set ap_stake   [lindex $ap 1]
					set adjustment  [expr {0 - $ap_stake}]
				}
				# Call 16661.  Show the AP amount deducted in the amount column
				set JRNL($row,amount) [format "%.2f" [expr {0 - $ap_stake}]]
			}

			ob_log::write DEV {$t - $JRNL($row,op_ref_key) - $JRNL($row,amount)\
			                                         - adjustment = $adjustment}

			if {$JRNL($row,op_ref_key) == "APAY"} {

				set sql {
					select
						bet_id
					from
						tAPPmt
					where
						appmt_id = ?
				}

				set stmt  [inf_prep_sql $DB $sql]
				set res2  [inf_exec_stmt $stmt $JRNL($row,op_ref_id)]

				inf_close_stmt $stmt

				set nrows2 [db_get_nrows $res2]

				set JRNL($row,op_ref_id)  [db_get_col $res2 0 bet_id]
				set JRNL($row,op_ref_key) "ESB"

				db_close $res2

			}

			if { $JRNL($row,op_ref_key) == "PMT"} {

				# legacy journal entry - should now be GPMT

				set JRNL($row,op_ref_key) "GPMT"

			}

			if { $t == "BSTK" || $t == "BSTL" || $t == "BWIN" || $t == "BRFD"} {

				set sql {
					select
						b.bet_id
					from
						tBet b,
						tManOBet o
					where
						b.bet_id = ? and
						b.bet_id = o.bet_id
				}

				set stmt  [inf_prep_sql $DB $sql]
				set res2  [inf_exec_stmt $stmt $JRNL($row,op_ref_id)]

				inf_close_stmt $stmt

				set nrows2 [db_get_nrows $res2]

				db_close $res2

				if {$nrows2 > 0} {
					set JRNL($row,manual) 1
				}
			}

			#
			# If the transaction is for an IGF (external) game
			# we need to query the IGF tables to get the game name.
			#
			if {$JRNL($row,op_ref_key) == "IGF"} {

				set sql {
					select
						tCgGame.display_name
					from
						tCgGame,
						tCgGameSummary
					where
						tCgGameSummary.cg_game_id = ? and
						tCgGameSummary.cg_id      = tCgGame.cg_id
				}

				set stmt [inf_prep_sql $DB $sql]
				set res2 [inf_exec_stmt $stmt $JRNL($row,op_ref_id)]

				inf_close_stmt $stmt

				set nrows2 [db_get_nrows $res2]

				if {$nrows2 > 0} {
					set op_type $JRNL($row,op_type)
					set display_name [db_get_col $res2 0 display_name]
					if {$display_name != ""} {
						set JRNL($row,op_type) "${op_type} \(${display_name}\)"
					}
				}
				db_close $res2
			}
			
			if {$JRNL($row,op_ref_key) == "IGFL"} {
				set sql {
					select
						name
					from
						tCGLeague,
						tCGLeagueResult
					where
						tCGLeagueResult.cg_league_result_id = ? and
						tCGLeagueResult.cg_league_id      = tCGLeague.cg_league_id
				}

				set stmt [inf_prep_sql $DB $sql]
				set res2 [inf_exec_stmt $stmt $JRNL($row,op_ref_id)]

				inf_close_stmt $stmt

				set nrows2 [db_get_nrows $res2]
				
				if {$nrows2 > 0} {
					set op_type $JRNL($row,op_type)
					set league_name [db_get_col $res2 0 name]
					if {$league_name != ""} {
						set JRNL($row,op_type) "${op_type} \(${league_name}\)"
					}
				}
				db_close $res2
			}


			# Get extra details for bet stakes and winnings.
			if {[db_get_col $res $r j_op_type] == "BSTK" || [db_get_col $res $r j_op_type] == "BWIN"} {

				# Change this to alter the max number of characters displayed for the bet details
				set max_info_length [OT_CfgGet CUST_TRANS_DETAILS_MAX_MENGTH 25]

				set returned_stake_details [_get_bet_type_and_seln_name [db_get_col $res $r j_op_ref_id] [db_get_col $res $r j_op_ref_key] [db_get_col $res $r j_op_type]]
				set stake_details [join $returned_stake_details]

				# Bind the details, but limit the length of the string if needed.
				if {[string length $stake_details] > $max_info_length} {
					set JRNL($row,detail) [string range $stake_details 0 $max_info_length]
				} else {
					set JRNL($row,detail) $stake_details
				}

				# Otherwise no extra details are required.
			} else {

				set JRNL($row,detail) ""

			}

			set JRNL($row,balance) $running_balance

			set running_balance [format "%0.2f" [expr {$running_balance-$adjustment}]]

			tpBindString NextPMB [format "%0.2f" $running_balance]

			#Disable the Next Button if there are no further records
			if {$running_balance == 0.00} {
					tpBindString NextDisable disabled
			}

			incr row 1
		}
	} elseif {$sort == "Prev" && $cpm_id == "" } {
		ob::log::write ERROR {No previous transactions found, redirecting to First}
		reqSetArg SubmitName "First"
		do_txn_query
		return
	} else {
		tpBindString NextDisable disabled
		tpBindString PrevDisable disabled
	}

	db_close $res

	#find the currency of the customer's account
	set sql {
		select
			c.ccy_name
		from
			tacct t,
			tccy c
		where
			t.acct_id = ? and
			t.ccy_code = c.ccy_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $AcctId]
	inf_close_stmt $stmt
	if {[db_get_nrows $res] > 0} {
		tpBindString Currency [db_get_col $res 0 ccy_name]
	} else {
		ob::log::write ERROR {Can't find currency for account_id:$AcctId}
		tpBindString Currency "Not found"
	}
	db_close $res

	tpBindVar TxDate        JRNL date       txn_idx
	tpBindVar TxOpType      JRNL op_type    txn_idx
	tpBindVar TxOpTypeCode  JRNL op_type_code txn_idx
	tpBindVar TxOpRefKey    JRNL op_ref_key txn_idx
	tpBindVar TxOpRefId     JRNL op_ref_id  txn_idx
	tpBindVar TxAmount      JRNL amount     txn_idx
	tpBindVar TxDesc        JRNL desc       txn_idx
	tpBindVar TxBalance     JRNL balance    txn_idx
	tpBindVar TxDetails     JRNL detail     txn_idx
	tpBindVar Manual        JRNL manual     txn_idx
	tpBindVar TxRetroDate	JRNL retrodate	txn_idx

	asPlayFile -nocache cust_txn_list.html

	catch {unset JRNL JTYPE JREFKEY}
}

proc get_sum_ap {acct_id at} {

	global DB

	#
	# Check the tAPPmt time to get the correct balance at that time
	#
	set sql {
		select first 1
			ap_balance,
			cr_date,
			appmt_id
		from
			tAPPmt
		where
			acct_id = ? and
			cr_date < ?
		order by cr_date desc, appmt_id desc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $acct_id $at]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] < 1} {
		set sum_ap 0.00
	} else {
		set sum_ap [db_get_col $rs 0 ap_balance]
	}

	db_close $rs

	return $sum_ap
}

proc get_balance {acct_id at} {

	global DB

	#
	# gets the account balance at a given time
	#
	set sql {
		select first 1
			balance,
			cr_date,
			jrnl_id
		from
			tJrnl
		where
			cr_date = (select max(cr_date) from tjrnl where acct_id = ? and cr_date <= ?) and
			acct_id = ?
		order by
			jrnl_id desc
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs2  [inf_exec_stmt $stmt $acct_id $at $acct_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs2] == 0} {
		set balance "0.00"
	} else {
		set balance [db_get_col $rs2 0 balance]
	}

	# Call 15564
	# Stanley's tJrnl entries pre 2001/09/10 can have a
	# balance of NULL. Return a value showing that we
	# can't calculate the running balance from this entry
	if {$balance == ""} {
		set balance "-"
	}

	db_close $rs2

	return $balance
}



proc check_ap_bet {op_type op_ref_key op_ref_id} {

	global DB

	set rows 0
	set ap_stake 0
	set returns  0

	set sql {
		select
			b.bet_id,
			case
			when b.tax_type = 'W' then
				abs(ap.ap_amount)
			when b.tax_type = 'S' and abs(ap.ap_amount) > 0 then
				abs(ap.ap_amount) + b.tax
			else
				abs(ap.ap_amount)
			end as bet_stake_total,
			(b.winnings + b.refund) as bet_returns_total
		from
			tBet b,
			tAPPmt ap
		where
			ap.bet_id = b.bet_id
		and
			b.paid <> 'Y'
	}

	if {$op_type == "BSTK" && $op_ref_key == "ESB"} {
		append sql [subst {
			and
				b.bet_id = $op_ref_id
			and
				ap.ap_op_type = 'APLC'
		}]
	} elseif {$op_type == "BSTK" && $op_ref_key == "APAY"} {
		append sql [subst {
			and
				ap.appmt_id = $op_ref_id
			and
				ap.ap_op_type in ('ASTL', 'APMT')
		}]
	} elseif {($op_type == "BSTL" || $op_type == "BWIN" || $op_type == "BRFD") &&
	          $op_ref_key == "ESB" ||
	          $op_type == "BCAN" && $op_ref_key == "ESB"} {
		append sql [subst {
			and
				b.bet_id = $op_ref_id
			and
				ap.ap_op_type = 'ASTL'
		}]
	} else {
		# unexpected reference key
		return [list $rows $ap_stake $returns]
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows > 0} {
		set ap_stake [db_get_col $res 0 bet_stake_total]

		if {$op_type == "BSTK" && $op_ref_key == "APAY"} {
			set returns 0
		} else {
			set returns  [db_get_col $res 0 bet_returns_total]
		}
	}

	db_close $res

	return [list $rows $ap_stake $returns]
}



proc get_account_type {acct_id} {

	global DB

	set sql {
		select
			acct_type
		from
			tAcct
		where
			acct_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt

	set acct_type [db_get_col $res 0 acct_type]

	db_close $res

	return $acct_type
}

#
# ----------------------------------------------------------------------------
# Get the bet stakes and winnings
# ----------------------------------------------------------------------------
#
proc _get_bet_type_and_seln_name {ref_id ref_type op_type} {

	global DB LANG

	# This will contain the results of our query.
	set details            [list]

	# If we're dealing with a standard bet or a pool bet.
	if {$ref_type == "ESB" || $ref_type == "TPB"} {

		# Standard bet.
		if {$ref_type == "ESB"} {

			# Get the bet type (ie; SGL, DBL, etc.)
			set sql {
				SELECT
					b.bet_type AS bet_type,
					s.desc AS selection_name
				FROM
					tBet                b,
					tOBet               o,
					tEvOc               s
				WHERE
					o.bet_id       = ?              AND
					o.bet_id       = b.bet_id       AND
					o.ev_oc_id     = s.ev_oc_id
			}

		# Pool bet.
		} else {

			set sql {
				SELECT
					p.bet_type AS bet_type,
					o.desc AS selection_name
				FROM
					tpoolbet            p,
					tPBet               pb,
					tEvOc               o
				WHERE
					pb.pool_bet_id  = ?              AND
					pb.pool_bet_id  = p.pool_bet_id  AND
					pb.ev_oc_id     = o.ev_oc_id
			}

		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ref_id]
		inf_close_stmt $stmt

		# Add each of the results to the list.
		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

			set     bet_type       [db_get_col $res $i bet_type]
			set     selection_name [string map {| {}} [db_get_col $res $i selection_name]]

			# Only display the bet type on the first iteration.
			if {$i == 0} {
				lappend details "$bet_type; $selection_name"
			} else {
				lappend details "- $selection_name"
			}

		}

		db_close $res

		# If we're dealing with xgame
	} elseif {$ref_type == "XGAM"} {

		# Bet Stake
		if {$op_type == "BSTK"} {

			set sql {
				SELECT
					bet_type
				FROM
					txgamesub
				WHERE
					xgame_sub_id = ?
			}

		# Bet settlement
		} elseif {$op_type == "BSTL" || $op_type == "BWIN" || $op_type == "BRFD"} {

			set sql {
				SELECT
					bet_type
				FROM
					txgamebet
				WHERE
					xgame_bet_id = ?
			}

		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ref_id]
		inf_close_stmt $stmt

		set     bet_type       [db_get_col $res 0 bet_type]
		lappend details "$bet_type "

		db_close $res

	}

	return $details

}

# close namespace
}
