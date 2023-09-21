# ==============================================================
# $Id: bf_passthru.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_PASSBET {

asSetAct ADMIN::BETFAIR_PASSBET::GoBFPassbet           		[namespace code go_bf_passbet]
asSetAct ADMIN::BETFAIR_PASSBET::DoBFPassbetUpd        		[namespace code do_bf_passbet]
asSetAct ADMIN::BETFAIR_PASSBET::GoSearchPassThruBets		[namespace code go_search_passthrubets]
asSetAct ADMIN::BETFAIR_PASSBET::DoSearchPassThruBets		[namespace code do_search_passthrubets]



#
#-------------------------------------------------------------------------------
# Go to Betfair Pass Through Bets Search Criteria Page
#-------------------------------------------------------------------------------
#
proc go_search_passthrubets args {

	set act [reqGetArg SubmitName]

	if {$act == "Refresh"} {
		do_search_passthrubets
	} else {
		asPlayFile -nocache bf_passthru_query.html
	}
}



#
#-------------------------------------------------------------------------------
# List all the Pass Through Bets that match the criteria
#-------------------------------------------------------------------------------
#
proc do_search_passthrubets args {

	global DB
	global BF_PASSTHRU_BETS

	set bf_pass_bet_id	[reqGetArg PassThruBetId]
	set bf_bet_id		[reqGetArg BFBetId]
	set status			[reqGetArg Status]
	set placed_from 	[string trim [reqGetArg PlacedDateFrom]]
	set placed_to	 	[string trim [reqGetArg PlacedDateTo]]
	set settled_from 	[string trim [reqGetArg SettledDate1]]
	set settled_to	 	[string trim [reqGetArg SettledDate2]]
	set period 			[reqGetArg PlacedFrom]
	set price_from 		[string trim [reqGetArg PriceFrom]]
	set price_to	 	[string trim [reqGetArg PriceTo]]
	set avg_price_from	[string trim [reqGetArg AvgPriceMatchFrom]]
	set avg_price_to	[string trim [reqGetArg AvgPriceMatchTo]]
	set size_from 		[string trim [reqGetArg SizeFrom]]
	set size_to 		[string trim [reqGetArg SizeTo]]
	set size_match_from	[string trim [reqGetArg SizeMatchFrom]]
	set size_match_to	[string trim [reqGetArg SizeMatchTo]]
	set profit_from		[string trim [reqGetArg ProfitFrom]]
	set profit_to 		[string trim [reqGetArg ProfitTo]]
	set username		[string trim [reqGetArg Username]]
	set is_settled		[reqGetArg IsSettled]	
	set settled_period  [reqGetArg OrderSettledAt]

	tpBindString PassThruBetId	$bf_pass_bet_id
	tpBindString BFBetId		$bf_bet_id
	tpBindString Status			$status
	tpBindString PlacedFrom		$period
	tpBindString PlacedDateFrom	$placed_from
	tpBindString PlacedDateTo	$placed_to
	tpBindString PriceFrom		$price_from
	tpBindString PriceTo		$price_to
	tpBindString SettledDate1   $settled_from
	tpBindString SettledDate2   $settled_to	
	tpBindString AvgPriceMatchFrom	$avg_price_from
	tpBindString AvgPriceMatchTo	$avg_price_to
	tpBindString SizeFrom		$size_from
	tpBindString SizeTo			$size_to
	tpBindString SizeMatchFrom	$size_match_from
	tpBindString SizeMatchTo	$size_match_to
	tpBindString ProfitFrom		$profit_from
	tpBindString ProfitTo		$profit_to
	tpBindString Username		$username
	tpBindString ExactName		[reqGetArg ExactName]
	tpBindString UpperName		[reqGetArg UpperName]
	tpBindString OrderSettledAt $settled_period	
	tpBindString IsSettled      $is_settled

	set where [list]
	set from [list]
	set order_by "pb.bf_pass_bet_id"

	# For calculating Profit
	set profit "(pb.size_matched * (pb.avg_price - pb.ob_price))"

	if {[string length $bf_pass_bet_id] > 0} {

		lappend where "pb.bf_pass_bet_id = $bf_pass_bet_id"

	} elseif {[string length $bf_bet_id] > 0} {

		lappend where "pb.bf_bet_id = $bf_bet_id"

	} else {
		if {[string length $status] > 0 } {
			lappend where "pb.status = '${status}'"
		}

		if {[string length $is_settled] > 0} {
			lappend where "pb.settled = '${is_settled}'"
		}

		if {([string length $placed_from] > 0) || ([string length $placed_to] > 0)} {
				lappend where [mk_between_clause pb.cr_date date $placed_from $placed_to]
		} else {

			#
			# Pass Through bets date in fixed periods
			#
			if {$period > 0} {

				set now [clock seconds]

				switch -exact -- $period {
					1 {
						# today
						set lo [clock format $now -format {%Y-%m-%d 00:00:00}]
						set hi [clock format $now -format {%Y-%m-%d 23:59:59}]
					}
					2 {
						# yesterday
						set yday [expr {$now-60*60*24}]
						set lo   [clock format $yday -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $yday -format {%Y-%m-%d 23:59:59}]
					}
					3 {
						# last 3 days
						set 3day [expr {$now-3*60*60*24}]
						set lo   [clock format $3day -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
					4 {
						# last 7 days
						set 7day [expr {$now-7*60*60*24}]
						set lo   [clock format $7day -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
					5 {
						#  last month
						set lo [clock format [clock scan "-1 month"] -format {%Y-%m-%d %H:%M:%S}]
						set hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
				}

				if {$lo != ""} {
					lappend where [mk_between_clause pb.cr_date date $lo $hi]
				}
			}
		}

		if {([string length $settled_from] > 0) || ([string length $settled_to] > 0)} {
			lappend where [mk_between_clause pb.settled_at date $settled_from $settled_to]
		} else {

			#
			# Orders date in fixed periods
			#
			if {[string length $settled_period] > 0 && $settled_period > 0} {

				set now [clock seconds]

				switch -exact -- $settled_period {
					1 {
						# today
						set lo [clock format $now -format {%Y-%m-%d 00:00:00}]
						set hi [clock format $now -format {%Y-%m-%d 23:59:59}]
					}
					2 {
						# yesterday
						set yday [expr {$now-60*60*24}]
						set lo   [clock format $yday -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $yday -format {%Y-%m-%d 23:59:59}]
					}
					3 {
						# last 3 days
						set 3day [expr {$now-3*60*60*24}]
						set lo   [clock format $3day -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
					4 {
						# last 7 days
						set 7day [expr {$now-7*60*60*24}]
						set lo   [clock format $7day -format {%Y-%m-%d 00:00:00}]
						set hi   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
					5 {
						#  last month
						set lo [clock format [clock scan "-1 month"] -format {%Y-%m-%d %H:%M:%S}]
						set hi [clock format $now -format {%Y-%m-%d %H:%M:%S}]
					}
				}

				if {$lo != ""} {
					lappend where [mk_between_clause pb.settled_at date $lo $hi]
				}
	        }
		}

		if {([string length $price_from] > 0) || ([string length $price_to] > 0)} {
			lappend where [mk_between_clause pb.price number $price_from $price_to]
		}

		if {([string length $avg_price_from] > 0) || ([string length $avg_price_to] > 0)} {
			lappend where [mk_between_clause pb.avg_price number $avg_price_from $avg_price_to]
		}

		if {([string length $size_from] > 0) || ([string length $size_to] > 0)} {
			lappend where [mk_between_clause pb.size number $size_from $size_to]
		}

		if {([string length $size_match_from] > 0) || ([string length $size_match_to] > 0)} {
			lappend where [mk_between_clause pb.size_matched number $size_match_from $size_match_to]
		}

		if {([string length $profit_from] > 0) || ([string length $profit_to] > 0)} {
			lappend where [mk_between_clause $profit number $profit_from $profit_to]
		}

		if {[string length $username] > 0} {
			if {[reqGetArg ExactName] == "Y"} {
				set op =
			} else {
				set op like
				set username "%$username%"
			}
			if {[reqGetArg UpperName] == "Y"} {
				lappend where "upper(c.username) ${op} '[string toupper ${username}]'"
			} else {
				lappend where "c.username ${op} '${username}'"
			}
		}
	}

	if {$where != "" } {
		set where "and [join $where { and }]"
	}

	set from "[join $from {, }]"

	if {$from != ""} {
		set from ",${from}"
	}

	set sql [subst {
		select
			pb.bf_pass_bet_id,
			pb.acct_id,
			pb.cr_date,
			pb.status,
			pb.bet_id,
			pb.bf_bet_id,
			pb.ev_oc_id,
			pb.price,
			pb.avg_price,
			pb.size,
			pb.size_matched,
			pb.ob_price,
			pb.settled_at,
			pb.bf_profit,
			round($profit,2) profit,
			b.receipt,
			b.stake,
			oc.desc as seln,
			m.ev_mkt_id,
			g.name as mkt,
			e.ev_id,
			e.desc as event,
			cl.ev_class_id,
			cl.name as class,
			t.ev_type_id,
			t.name as evtype,
			c.cust_id,
			c.username,
			c.acct_no,
			a.ccy_code
		from
			tBFPassbet pb,
			tEvOc oc,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvClass cl,
			tEvType t,
			outer (tBet b,			
			tCustomer c,
			tAcct a)
		where
			pb.bet_id = b.bet_id and
			pb.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			pb.ev_oc_id = oc.ev_oc_id and
			oc.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			oc.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			e.ev_class_id = cl.ev_class_id
			$where
		order by
			$order_by
	}]

	ob::log::write DEBUG "SEARCH PASS THROUGH BETS SQL: $sql"

	set stmt [inf_prep_sql $DB $sql]

	if {[catch { set res  [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		ob::log::write ERROR {do_search_passthrubets - $msg}
		inf_close_stmt $stmt
		go_search_passthrubets
		return
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	ob::log::write DEBUG "Number Of bets found = $nrows"

	if {$nrows == 0} {
		tpBindString NoPassThruBets "No bets found with this criteria"
		db_close $res
		go_search_passthrubets
		return
	}

	if {[info exists BF_PASSTHRU_BETS]} {
		ob::log::write DEBUG " Unseting BF_PASSTHRU_BETS"
		unset BF_PASSTHRU_BETS
	}

	for {set r 0} {$r < $nrows} {incr r} {
		set BF_PASSTHRU_BETS($r,bf_pass_bet_id)	 [db_get_col $res $r bf_pass_bet_id]
		set BF_PASSTHRU_BETS($r,acct_id)	 [db_get_col $res $r acct_id]
		set BF_PASSTHRU_BETS($r,cr_date)	 [db_get_col $res $r cr_date]
		set BF_PASSTHRU_BETS($r,status)		 [db_get_col $res $r status]
		set BF_PASSTHRU_BETS($r,bet_id)		 [db_get_col $res $r bet_id]
		set BF_PASSTHRU_BETS($r,bf_bet_id)	 [db_get_col $res $r bf_bet_id]
		set BF_PASSTHRU_BETS($r,ev_oc_id) 	 [db_get_col $res $r ev_oc_id]
		set BF_PASSTHRU_BETS($r,seln)		 [db_get_col $res $r seln]
		set BF_PASSTHRU_BETS($r,ev_mkt_id)	 [db_get_col $res $r ev_mkt_id]
		set BF_PASSTHRU_BETS($r,mkt)		 [db_get_col $res $r mkt]
		set BF_PASSTHRU_BETS($r,ev_class_id) [db_get_col $res $r ev_class_id]
		set BF_PASSTHRU_BETS($r,class)		 [db_get_col $res $r class]
		set BF_PASSTHRU_BETS($r,ev_id)		 [db_get_col $res $r ev_id]
		set BF_PASSTHRU_BETS($r,event)		 [db_get_col $res $r event]
		set BF_PASSTHRU_BETS($r,ev_type_id)	 [db_get_col $res $r ev_type_id]
		set BF_PASSTHRU_BETS($r,evtype)		 [db_get_col $res $r evtype]
		set BF_PASSTHRU_BETS($r,price)		 [db_get_col $res $r price]
		set BF_PASSTHRU_BETS($r,avg_price)	 [db_get_col $res $r avg_price]
		set BF_PASSTHRU_BETS($r,size)		 [db_get_col $res $r size]
		set BF_PASSTHRU_BETS($r,size_matched) [db_get_col $res $r size_matched]
		set BF_PASSTHRU_BETS($r,settled_at)	 [db_get_col $res $r settled_at]
		set BF_PASSTHRU_BETS($r,bf_profit)	 [db_get_col $res $r bf_profit]

		# Voided/Cancelled bets shouldn't have any profit, hence setting profit to 0.00
		if {$BF_PASSTHRU_BETS($r,status) != "V" && $BF_PASSTHRU_BETS($r,status) != "X"} {
			set BF_PASSTHRU_BETS($r,profit)	[db_get_col $res $r profit]
		} else {
			set BF_PASSTHRU_BETS($r,profit)	0.00
		}
		set BF_PASSTHRU_BETS($r,ob_price)	 [db_get_col $res $r ob_price]
		set BF_PASSTHRU_BETS($r,receipt)	 [db_get_col $res $r receipt]
		set BF_PASSTHRU_BETS($r,cust_id)	 [db_get_col $res $r cust_id]
		set BF_PASSTHRU_BETS($r,username)	 [db_get_col $res $r username]
		set BF_PASSTHRU_BETS($r,acct_no)	 [db_get_col $res $r acct_no]
		set BF_PASSTHRU_BETS($r,stake)		 [db_get_col $res $r stake]
		set BF_PASSTHRU_BETS($r,ccy_code)	 [db_get_col $res $r ccy_code]
	}

	db_close $res

	tpSetVar NumBet	$nrows

	tpBindVar BFPassBetId	BF_PASSTHRU_BETS bf_pass_bet_id  passthru_idx
	tpBindVar AcctId	BF_PASSTHRU_BETS acct_id 	 passthru_idx
	tpBindVar CrDate 	BF_PASSTHRU_BETS cr_date	 passthru_idx
	tpBindVar BFStatus	BF_PASSTHRU_BETS status		 passthru_idx
	tpBindVar BetId		BF_PASSTHRU_BETS bet_id		 passthru_idx
	tpBindVar BFBetId	BF_PASSTHRU_BETS bf_bet_id	 passthru_idx
	tpBindVar EvOcId 	BF_PASSTHRU_BETS ev_oc_id	 passthru_idx
	tpBindVar OCDesc	BF_PASSTHRU_BETS seln		 passthru_idx
	tpBindVar Mkt		BF_PASSTHRU_BETS mkt		 passthru_idx
	tpBindVar MktId 	BF_PASSTHRU_BETS ev_mkt_id	 passthru_idx
	tpBindVar Event		BF_PASSTHRU_BETS event		 passthru_idx
	tpBindVar EvId		BF_PASSTHRU_BETS ev_id		 passthru_idx
	tpBindVar TypeName	BF_PASSTHRU_BETS evtype		 passthru_idx
	tpBindVar EvTypeId	BF_PASSTHRU_BETS ev_type_id	 passthru_idx
	tpBindVar Class		BF_PASSTHRU_BETS class		 passthru_idx
	tpBindVar EvClassId	BF_PASSTHRU_BETS ev_class_id passthru_idx
	tpBindVar Price		BF_PASSTHRU_BETS price		 passthru_idx
	tpBindVar AvgPrice	BF_PASSTHRU_BETS avg_price	 passthru_idx
	tpBindVar Size		BF_PASSTHRU_BETS size		 passthru_idx
	tpBindVar SizeMatched 	BF_PASSTHRU_BETS size_matched	 passthru_idx
	tpBindVar Profit	BF_PASSTHRU_BETS profit		 passthru_idx
	tpBindVar BetReceipt BF_PASSTHRU_BETS receipt 	 passthru_idx
	tpBindVar Username	BF_PASSTHRU_BETS username	 passthru_idx
	tpBindVar CustId	BF_PASSTHRU_BETS cust_id	 passthru_idx
	tpBindVar OBPrice	BF_PASSTHRU_BETS ob_price 	 passthru_idx
	tpBindVar Stake		BF_PASSTHRU_BETS stake		 passthru_idx
	tpBindVar CcyCode	BF_PASSTHRU_BETS ccy_code	 passthru_idx
	tpBindVar SettledAt	BF_PASSTHRU_BETS settled_at	 passthru_idx
	tpBindVar BF_Profit	BF_PASSTHRU_BETS bf_profit	 passthru_idx
	

	asPlayFile -nocache bf_passthru_bets.html
}

#
# ----------------------------------------------------------------------------
# Display the pass-through bet details. 
# ----------------------------------------------------------------------------
#
proc go_bf_passbet {{bf_pass_bet_id -1}} {

	global DB
	global BF_ORDERS

	if {[info exists BF_ORDERS]} {
		unset BF_ORDERS
	}
	
	if {$bf_pass_bet_id == -1} { 
		set bf_pass_bet_id [reqGetArg BFPassBetId]
	} 
		
	if {$bf_pass_bet_id == -1 || $bf_pass_bet_id == ""} { 
		tpSetVar NoBFOrder 1
		asPlayFile -nocache bf_passbet.html
		return
	} 
	
	set sql [subst {
			select
				o.bf_pass_bet_id,
				o.cr_date,
				o.status,
				'B' as type,
				o.price,
				o.avg_price,
				o.size,
				o.size_matched,
				o.bf_bet_id,
				o.ev_oc_id,
				o.ob_price,
				o.bet_id,
				o.settled,
				o.bf_profit,
				s.desc,
				b.receipt
			from
				tBFPassBet o,				
				tBFAccount a,
				tEvOc s,
				tEv e,
				outer tBet b
			where
				o.bf_acct_id = a.bf_acct_id
			and o.bf_pass_bet_id = ? 
			and o.ev_oc_id = s.ev_oc_id
			and s.ev_id = e.ev_id
			and o.bet_id = b.bet_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_pass_bet_id]
	inf_close_stmt $stmt

	set nrows  [db_get_nrows $rs]
	set fields [db_get_colnames $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach j $fields {
			set BF_ORDERS($i,$j) [db_get_col $rs $i $j]
		}
		if {$i==0} { 
			tpBindString OcDesc   [db_get_col $rs 0 desc]			
			tpSetVar BFOrderType  [db_get_col $rs 0 type]
			tpBindString OcId     [db_get_col $rs 0 ev_oc_id]
		}
	}

	db_close $rs

	if {$BF_ORDERS(0,avg_price) != "" || $BF_ORDERS(0,avg_price) == 0} { 
		set price $BF_ORDERS(0,price)
	} else { 
		set price $BF_ORDERS(0,avg_price)
	} 

	tpSetVar     BFNumOrders  $nrows
		
	if {$nrows > 0} {
		tpBindString BFPassBetId  $BF_ORDERS(0,bf_pass_bet_id)
		tpBindString BFCrDate     $BF_ORDERS(0,cr_date)
		tpBindString BFStatus     $BF_ORDERS(0,status)
		tpBindString BFSettled    $BF_ORDERS(0,settled)
		tpBindString BFType       $BF_ORDERS(0,type)
		tpBindString BFPrice      $BF_ORDERS(0,price)
		tpBindString BFAvgPrice   $BF_ORDERS(0,avg_price)
		tpBindString BFObPrice    $BF_ORDERS(0,ob_price)
		tpBindString BFSize       $BF_ORDERS(0,size)
		tpBindString BFSizeMat    $BF_ORDERS(0,size_matched)
		tpBindString BFBetId      $BF_ORDERS(0,bf_bet_id)		
		tpBindString BFObBetId    $BF_ORDERS(0,bet_id)
		tpBindString BFProfit     $BF_ORDERS(0,bf_profit)
		tpBindString BFObReceipt  $BF_ORDERS(0,receipt)
	}

	asPlayFile -nocache bf_passbet.html
}

proc do_bf_passbet args { 

	set act [reqGetArg SubmitName]

	if {$act == "BFUpdPassbet"} {
		do_passbet_upd
	} elseif {$act == "BFCanOrder"} {
		ADMIN::BETFAIR_ORDER::do_bf_order_can "passbet"
	} 

} 

#
# ----------------------------------------------------------------------------
#  Update the passbet betfair order with a status / betfair ID. This happens if
#  updating a pending order later on with details. If the order hasn't been placed 
#  cancel the liabs. Else we assume its an order status "U" and let the order 
#  daemon process any updates. 
# ----------------------------------------------------------------------------
#
proc do_passbet_upd {} {

	global DB

	set bf_pass_bet_id 	[reqGetArg BFPassBetId]
	set bf_bet_id   	[reqGetArg NewBFBetId]
	set status      	[reqGetArg Status]
	set type        	[reqGetArg BFOrderType] 

	if {$status == "U" && $bf_bet_id == ""} {
		err_bind "Cannot set order to placed without corresponding Betfair bet id"
		go_bf_passbet
		return
	}

	set sql [subst {
		update
			tBFPassBet
		set
			bf_bet_id = ?,
			status    = ?
		where
			bf_pass_bet_id = ?
		and
			status = 'B'
	}]

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {		
		set rs [inf_exec_stmt $stmt $bf_bet_id $status $bf_pass_bet_id]	
	} msg]} {
		inf_rollback_tran $DB
		catch {db_close $rs} 
		inf_close_stmt $stmt		
		err_bind $msg
		ob::log::write ERROR {do_passbet_upd:ERROR $msg}
		go_bf_passbet
		return
	}

	inf_close_stmt $stmt
	db_close $rs
	
	if {$status == "X"} { 
		# If the order didn't get placed, cancel the liabs		
		set liab_ok [BETFAIR::LIAB::cancel_passbet $bf_pass_bet_id]

		if {!$liab_ok==1} { 
			inf_rollback_tran $DB
			err_bind "Liability update error"
			ob_log::write ERROR {do_passbet_upd ERROR Liability Error}
			go_bf_passbet $bf_pass_bet_id
			return
		}
	} 
		
	inf_commit_tran $DB	

	go_bf_passbet $bf_pass_bet_id
}

}

