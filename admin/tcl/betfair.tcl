# ==============================================================
# $Id: betfair.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# Warning...in tcl 8.3 the betfair bet id may be too large an integer to be
# represented...don't do any expr (or if) operations on it or they will be incorrect...
#
# e.g
# set bf_bet_id [expr {$BF_PB(0,new_bet_id) == "0" ? $bf_bet_id : $BF_PB(0,new_bet_id)}]
# with values
# set bf_bet_id [expr {"3840607740" == "0" ? "3840607740" : "3840609248"}]
# will return -454358048 in tcl8.3 where it should be 3840609248
# ==============================================================

namespace eval ADMIN::BETFAIR {

asSetAct ADMIN::BETFAIR::GoBFControl           [namespace code go_bf_control]
asSetAct ADMIN::BETFAIR::DoBFControl           [namespace code do_bf_control]
asSetAct ADMIN::BETFAIR::ShowMonitored	       [namespace code show_monitored]

#
# ----------------------------------------------------------------------------
# Display BetFair control information
# ----------------------------------------------------------------------------
#
proc go_bf_control args {

	global DB

	set sql {
		select
			bc.apc_allowed,
			bc.feed_allowed,
			bc.settler_allowed,
			bc.risk_allowed,
			bc.order_allowed,
			bc.trade_allowed,
			bc.cleanser_allowed,
			bc.order_thold,
			bc.order_scale,
			bc.price_chng_thold,
			bc.price_min_change,
			bc.price_adj_fac_2,
			bc.price_adj_fac_3,
			bc.price_adj_fac_n,
			bc.bf_acct_id,
			bc.trade_liab_pct,
			ba.name,
			bc.passthru_liquidity,
			bc.pr_timeout_suspend
		from
			tBFConfig bc,
			tBFAccount ba
		where
			bc.bf_acct_id = ba.bf_acct_id
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		ob::log::write ERROR {go_bf_control - $msg}
	}

	inf_close_stmt $stmt
	set nrows  [db_get_nrows $rs]
	set fields [db_get_colnames $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach f $fields {
			set $f [db_get_col $rs $i $f]
		}
	}

	db_close $rs

	tpBindString APCAllowed      $apc_allowed
	tpBindString FeedAllowed     $feed_allowed
	tpBindString CleanserAllowed $cleanser_allowed
	tpBindString StlAllowed      $settler_allowed
	tpBindString RiskAllowed     $risk_allowed
	tpBindString OrderAllowed    $order_allowed
	tpBindString TradeAllowed    $trade_allowed
	tpBindString OrderThold      $order_thold
	tpBindString OrderScale      $order_scale
	tpBindString PriceChngThold  $price_chng_thold
	tpBindString PriceMinChange  $price_min_change 
	tpBindString PriceAdjFac2    $price_adj_fac_2
	tpBindString PriceAdjFac3    $price_adj_fac_3
	tpBindString PriceAdjFacN    $price_adj_fac_n
	tpBindString GlobalBFAcctId  $bf_acct_id
	tpBindString TradeLiabPct    $trade_liab_pct
	tpBindString GlobalBFAcctName $name
	tpBindString PassLiquidity   $passthru_liquidity
	tpBindString PriceTimeoutSuspend $pr_timeout_suspend

	ADMIN::BETFAIR_ACCT::bind_bf_accounts

	asPlayFile -nocache bf_control.html
}


#
# ----------------------------------------------------------------------------
# Update BetFair control information
# ----------------------------------------------------------------------------
#
proc do_bf_control args {

	global DB

	set apc_allowed       [reqGetArg APCAllowed]
	set feed_allowed      [reqGetArg FeedAllowed]
	set stl_allowed       [reqGetArg StlAllowed]
	set risk_allowed      [reqGetArg RiskAllowed]
	set order_allowed     [reqGetArg OrderAllowed]
	set trade_allowed     [reqGetArg TradeAllowed]
	set cleanser_allowed  [reqGetArg CleanserAllowed]
	set order_thold       [reqGetArg OrderThold]
	set order_scale       [reqGetArg OrderScale]
	set trade_liab_pct    [reqGetArg TradeLiabPct]
	set price_chng_thold  [reqGetArg PriceChngThold]
	set price_min_change  [reqGetArg PriceMinChange]
	set price_adj_fac_2   [reqGetArg PriceAdjFac2]
	set price_adj_fac_3   [reqGetArg PriceAdjFac3]
	set price_adj_fac_n   [reqGetArg PriceAdjFacN]
	set bf_acct_id	      [reqGetArg Global_BF_Account]
	set bf_acct_name	  [reqGetArg GlobalBFAcctName]
	set passthru_liquidity [reqGetArg PassLiquidity]
	set pr_timeout_suspend [reqGetArg PriceTimeoutSuspend] 

	set sql [subst {
		update
			tBFConfig
		set
			apc_allowed    		= ?,
			feed_allowed   		= ?,
			settler_allowed    	= ?,
			risk_allowed   		= ?,
			order_allowed  		= ?,
			trade_allowed  		= ?,
			order_thold    		= ?,
			order_scale    		= ?,
			price_chng_thold 	= ?,
			price_min_change    = ?,
			price_adj_fac_2  	= ?,
			price_adj_fac_3  	= ?,
			price_adj_fac_n  	= ?,
			bf_acct_id	 		= ?,
			trade_liab_pct 		= ?,
			passthru_liquidity 	= ?,
			cleanser_allowed    = ?,
			pr_timeout_suspend  = ? 
			

	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt\
					$apc_allowed \
					$feed_allowed \
					$stl_allowed \
					$risk_allowed \
					$order_allowed \
					$trade_allowed \
					$order_thold \
					$order_scale \
					$price_chng_thold \
					$price_min_change \
					$price_adj_fac_2 \
					$price_adj_fac_3 \
					$price_adj_fac_n \
					$bf_acct_id\
					$trade_liab_pct\
					$passthru_liquidity\
					$cleanser_allowed\
					$pr_timeout_suspend} msg]} {
		err_bind $msg
		ob::log::write ERROR {do_bf_control - $msg}
		inf_close_stmt $stmt
		asPlayFile -nocache bf_control.html
		return
	}

	inf_close_stmt $stmt

	tpSetVar     BFControlUpd   1
	tpBindString APCAllowed     $apc_allowed
	tpBindString FeedAllowed    $feed_allowed
	tpBindString StlAllowed     $stl_allowed
	tpBindString RiskAllowed    $risk_allowed
	tpBindString OrderAllowed   $order_allowed
	tpBindString TradeAllowed   $trade_allowed
	tpBindString CleanserAllowed $cleanser_allowed
	tpBindString OrderThold     $order_thold
	tpBindString OrderScale     $order_scale
	tpBindString PriceChngThold $price_chng_thold
	tpBindString PriceMinChange $price_min_change
	tpBindString PriceAdjFac2   $price_adj_fac_2
	tpBindString PriceAdjFac3   $price_adj_fac_3
	tpBindString PriceAdjFacN   $price_adj_fac_n
	tpBindString GlobalBFAcctId $bf_acct_id
	tpBindString GlobalBFAcctName $bf_acct_name
	tpBindString TradeLiabPct   $trade_liab_pct
	tpBindString PassLiquidity  $passthru_liquidity
	tpBindString PriceTimeoutSuspend $pr_timeout_suspend

	ADMIN::BETFAIR_ACCT::bind_bf_accounts

	asPlayFile -nocache bf_control.html
}


# remove any "|" characters that may surround words, indicating
# that they're translatable.  This does it properly, removing
# all such bars, rather than just the first and the last.
proc remove_tran_bars {tran} {

	if {[OT_CfgGet RMV_PIPES_FROM_EV_SEL 0]} {
		set map [list "|" ""]
		set tran [string map $map $tran]
	}

	return $tran
}


#
# ----------------------------------------------------------------------------
# List all the markets currently being monitored
# ----------------------------------------------------------------------------
#
proc show_monitored args {

	global DB
	global BF_SHOW_MON	

	set show_all [reqGetArg show_all] 

	if {$show_all == "Y"} { 
		set disp ""
	} else { 
		set disp " and (pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off,m.bet_in_run) == 'Y') "
	} 

	set sql [subst {
		select
			distinct
			NVL(bm.reduce_risk,'N') as reduce_risk,
			NVL(bm.auto_lay,'N') as auto_lay,
			NVL(bm.auto_pass,'N') as auto_pass,
			bm.min_vwap_vol,
			NVL(bm.auto_price_chng,'N') as auto_price_chng,
			bm.poll_time,
			bm.price_adj_fac,
			bm.bf_exch_id,
			m.ev_mkt_id,
			m.status,
			g.name as mkt,
			e.ev_id,
			e.desc as event,
			e.status,
			e.start_time,
			cl.ev_class_id,
			cl.name as class,
			t.ev_type_id,
			t.name	as evtype		
		from			
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvClass cl,
			tEvType t,
			tBFMonitor bm
		where			
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			e.ev_class_id = cl.ev_class_id and
			bm.type='EM' and
			bm.ob_id = m.ev_mkt_id and
			bm.status = 'A' 
			$disp
		order by
			e.start_time desc, ev_class_id, ev_type_id, ev_id 
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows  [db_get_nrows $res]

	if {$nrows == 0} {
		tpBindString Message  "No markets currently monitored on Betfair"
    } else { 

		for {set r 0} {$r < $nrows} {incr r} {
		
			set reduce_risk [db_get_col $res $r reduce_risk]
			set auto_pass [db_get_col $res $r auto_pass]			
			if {$reduce_risk == "-"} {set reduce_risk "N"} 
			if {$auto_pass == "-"} {set auto_pass "N"} 		
			set BF_SHOW_MON($r,reduce_risk)		$reduce_risk
			set BF_SHOW_MON($r,auto_pass)		$auto_pass
			set BF_SHOW_MON($r,auto_lay)		[db_get_col $res $r auto_lay]
			set BF_SHOW_MON($r,min_vwap_vol)	[db_get_col $res $r min_vwap_vol]
			set BF_SHOW_MON($r,auto_price_chng) [db_get_col $res $r auto_price_chng]
			set poll_time   [db_get_col $res $r poll_time]			
			if {$poll_time != ""} { 
				set BF_SHOW_MON($r,poll_time) [expr {round($poll_time / 1000)}] 
			} 	else { 
				set BF_SHOW_MON($r,poll_time) ""
			}				
			
			set BF_SHOW_MON($r,price_adj_fac)   [db_get_col $res $r price_adj_fac]
			set BF_SHOW_MON($r,bf_exch_id)      [db_get_col $res $r bf_exch_id]
			set BF_SHOW_MON($r,ev_mkt_id)     	[db_get_col $res $r ev_mkt_id]
			set BF_SHOW_MON($r,mkt)   			[db_get_col $res $r mkt]
			set BF_SHOW_MON($r,ev_class_id)   	[db_get_col $res $r ev_class_id]
			set BF_SHOW_MON($r,class)      		[db_get_col $res $r class]
			set BF_SHOW_MON($r,ev_id)    		[db_get_col $res $r ev_id]
			set BF_SHOW_MON($r,event)      		[db_get_col $res $r event]
			set BF_SHOW_MON($r,ev_type_id)    	[db_get_col $res $r ev_type_id]
			set BF_SHOW_MON($r,evtype)        	[db_get_col $res $r evtype]
			set BF_SHOW_MON($r,mkt)				[db_get_col $res $r mkt]
			set BF_SHOW_MON($r,start_time)		[db_get_col $res $r start_time]
		}

		db_close $res

		tpSetVar NumMon $nrows

		tpBindVar ReduceRisk 	BF_SHOW_MON reduce_risk 	mon_idx
		tpBindVar AutoPass 		BF_SHOW_MON auto_pass 		mon_idx
		tpBindVar AutoLay 		BF_SHOW_MON auto_lay 		mon_idx
		tpBindVar VWAP      	BF_SHOW_MON min_vwap_vol	mon_idx
		tpBindVar APC       	BF_SHOW_MON auto_price_chng	mon_idx
		tpBindVar PollTime  	BF_SHOW_MON poll_time		mon_idx
		tpBindVar PriceAdjFac 	BF_SHOW_MON price_adj_fac 	mon_idx	
		tpBindVar BFExchId	 	BF_SHOW_MON bf_exch_id 	 	mon_idx	
		tpBindVar Mkt			BF_SHOW_MON mkt				mon_idx
		tpBindVar MktId 		BF_SHOW_MON ev_mkt_id		mon_idx
		tpBindVar Event			BF_SHOW_MON event			mon_idx
		tpBindVar EvId			BF_SHOW_MON ev_id			mon_idx
		tpBindVar TypeName		BF_SHOW_MON evtype			mon_idx
		tpBindVar EvTypeId		BF_SHOW_MON ev_type_id		mon_idx
		tpBindVar Class			BF_SHOW_MON class			mon_idx
		tpBindVar EvClassId		BF_SHOW_MON ev_class_id		mon_idx
		tpBindVar Type			BF_SHOW_MON type 			mon_idx
		tpBindVar StartTime 	BF_SHOW_MON start_time		mon_idx

	} 	

	asPlayFile -nocache bf_monitor.html
}

proc bind_bet_receipt bet_id { 

	global DB

	# To retrieve the bet details from tBFOrder and tBFPassBet
	set sql_bf [subst {
		select
			b.bet_id,
			bo.bf_order_id,
			bo.size bf_size,
			bo.size_matched bf_size_matched,
			bo.price bf_price,
			bo.avg_price bf_avg_price,
			bo.status bf_status,
			bo.bf_bet_id bf_bet_id,
			bo.settled bf_settled,
			bo.bf_profit bf_bf_profit,
			pb.bf_pass_bet_id,
			pb.size pb_size,
			pb.size_matched pb_size_matched,
			pb.price pb_price,
			pb.avg_price pb_avg_price,
			pb.settled,
			pb.bf_profit,
			pb.status pb_status,
			pb.settled pb_settled,
			pb.bf_profit pb_bf_profit,
			pb.bf_bet_id pb_bf_bet_id,
			round((pb.size_matched * (pb.avg_price - pb.ob_price)),2) profit
		from
			tBet b,
			outer tBFOrder bo,
			outer tBFPassBet pb
		where
			b.bet_id = ?  and
			bo.bet_id = b.bet_id and
			pb.bet_id = b.bet_id
	}]

	set stmt [inf_prep_sql $DB $sql_bf]

	if {[catch { set rs  [inf_exec_stmt $stmt $bet_id]} msg]} {
		err_bind $msg
		ob::log::write ERROR {go_bet_reciept error when retrieving bf bets - $msg}
		inf_close_stmt $stmt
		asPlayFile -nocache bet_receipt.html
		return
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 0} {
		# if the bet is passed / reduced risk
		if {[db_get_col $rs 0 bf_order_id] != "" || [db_get_col $rs 0 bf_pass_bet_id] != ""} {

			tpSetVar HasBFBet YES

			# Binding all Order Details (reduced risk)
			tpBindString BFOrderId		[db_get_col $rs 0 bf_order_id]
			tpBindString BFSize			[db_get_col $rs 0 bf_size]
			tpBindString BFSizeMatched	[db_get_col $rs 0 bf_size_matched]
			tpBindString BFPrice		[db_get_col $rs 0 bf_price]
			tpBindString BFAvgPrice		[db_get_col $rs 0 bf_avg_price]
			tpBindString BFBetId		[db_get_col $rs 0 bf_bet_id]
			tpBindString BFStatus		[db_get_col $rs 0 bf_status]
			tpBindString BFSettled		[db_get_col $rs 0 bf_settled]
			tpBindString BFProfit		[db_get_col $rs 0 bf_bf_profit]

			# Binding all PassThrough bet Details
			tpBindString PassBetId      [db_get_col $rs 0 bf_pass_bet_id]
			tpBindString PBSize			[db_get_col $rs 0 pb_size]
			tpBindString PBSizeMatched	[db_get_col $rs 0 pb_size_matched]
			tpBindString PBPrice		[db_get_col $rs 0 pb_price]
			tpBindString PBAvgPrice		[db_get_col $rs 0 pb_avg_price]
			tpBindString PBBFBetId		[db_get_col $rs 0 pb_bf_bet_id]
			tpBindString PBStatus       [db_get_col $rs 0 pb_status]
			tpBindString PBSettled		[db_get_col $rs 0 pb_settled]
			
			# Any voided/bad bets should heve profit 0.00
			if {[db_get_col $rs 0 pb_status] != "V" && [db_get_col $rs 0 pb_status] != "X"} {
				tpBindString PBProfit	[db_get_col $rs 0 pb_bf_profit]
			} else {
				tpBindString PBProfit 0.00
			}
		} else {
			tpSetVar HasBFBet NO
		}
	} else {
		ob::log::write DEBUG {Bet is not passed to betfair}
	}

	db_close $rs

} 

}
