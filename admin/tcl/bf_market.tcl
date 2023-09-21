# ==============================================================
# $Id: bf_market.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_MKT {
	
	asSetAct ADMIN::BETFAIR_MKT::GoBFSelnDepth         [namespace code go_bf_seln_depth]

#
# ----------------------------------------------------------------------------
# Bind the betfair related details for the openbet market. 
# Also retrive all the betfair markets under the mapped betfair event
# ----------------------------------------------------------------------------
#
proc bind_bf_mkt {ev_id mkt_id} {

	global DB BF_MTCH_MKT BF_MTCH

	#
	# Get current market setup
	#
	set sql [subst {
		select
			a.bf_map_id,
			i.bf_ev_items_id,
			i.bf_desc,
			i.bf_id,
			b.bf_monitor_id,
			b.status as bf_status,
			b.auto_price_chng as bf_auto_prc_chng,
			b.poll_time as bf_poll_time,
			b.price_adj_fac as bf_prc_adj_fac,
			b.auto_lay as bf_auto_lay,
			b.auto_pass as bf_auto_pass,
			b.reduce_risk as bf_reduce_risk,
			b.mkt_bk_per as bf_mkt_bk_per,
			NVL(b.min_vwap_vol,g.min_vwap_vol) as bf_min_vwap_vol,
			b.bir_activate_delay
		from
			tEvMkt       m,
			outer tBFOcGrpMap  g,
			outer tBFMonitor b,
 			outer (tBFMap a,
 			outer tBFEvItems i)
		where
			m.ev_mkt_id    = $mkt_id        and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
 			m.ev_mkt_id    = a.ob_id        and
 			a.ob_type      = 'EM'           and
 			a.bf_ev_items_id    = i.bf_ev_items_id    and
 			m.ev_mkt_id    = b.ob_id        and
 			b.type         = 'EM'
	}]
	
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	
	if {[OT_CfgGet BF_MANUAL_MATCH 0]} {
		set sql [subst {
			select
				i.bf_id
			from
				tBFMap m,
				tBFEvItems i
			where
				m.ob_id = ?
				and m.bf_ev_items_id = i.bf_ev_items_id
				and m.ob_type = 'EV'
		}]
	
		set stmt  [inf_prep_sql $::DB $sql]
		set res_ev   [inf_exec_stmt $stmt $ev_id]
		inf_close_stmt $stmt
	
		if {[db_get_nrows $res_ev] > 0} {
			set bf_parent_id [db_get_col $res_ev 0 bf_id]
			db_close $res_ev
	
			set sql [subst {
				select
					bf_ev_items_id,
					bf_desc,
					bf_id
				from
					tBFEvItems
				where
					bf_type = 'EM'
				and
					bf_parent_id = ?
			}]
	
			set stmt  [inf_prep_sql $::DB $sql]
			set res_mkt   [inf_exec_stmt $stmt $bf_parent_id]
			inf_close_stmt $stmt
	
			set BF_MTCH_MKT(nrows) [db_get_nrows $res_mkt]
			
			for {set i 0} {$i < $BF_MTCH_MKT(nrows)} {incr i} {
				set BF_MTCH_MKT($i,bf_ev_items_id) [db_get_col $res_mkt $i bf_ev_items_id]
				set BF_MTCH_MKT($i,bf_desc)        [db_get_col $res_mkt $i bf_desc]
			}
	
			db_close $res_mkt
	
			tpBindVar BFMktIds        BF_MTCH_MKT bf_ev_items_id bf_mkt_idx
			tpBindVar BFMktDesc       BF_MTCH_MKT bf_desc        bf_mkt_idx
			tpSetVar  BFNumMkts    	  $BF_MTCH_MKT(nrows)
		}
	}

	if {[db_get_col $res 0 bir_activate_delay] == ""} { 
		set bir_activation_delay [OT_CfgGet BF_DEFAULT_BIR_DELAY "40"] 
	} else { 
		set bir_activation_delay [db_get_col $res 0 bir_activate_delay]
	} 

	#
	# Determine BetFair default settings
	#
	tpBindString MktBFStatus        [db_get_col $res 0 bf_status]
	tpBindString MktBFDefEvItemsId  [db_get_col $res 0 bf_ev_items_id]
	tpBindString MktBFDefMapId      [db_get_col $res 0 bf_map_id]
	tpBindString MktBFDefDesc       [db_get_col $res 0 bf_desc]
	tpBindString MktBFMktBKPer    [db_get_col $res 0 bf_mkt_bk_per]
	tpBindString MktBFBIRDelay    $bir_activation_delay
	tpBindString MktBFAutoPrcChng [db_get_col $res 0 bf_auto_prc_chng]
	tpBindString MktBFPollTime    [db_get_col $res 0 bf_poll_time]
	tpBindString MktBFPrcAdjFac   [db_get_col $res 0 bf_prc_adj_fac]
	tpBindString MktBFAutoLay     [db_get_col $res 0 bf_auto_lay]
	tpBindString MktBFAutoPass    [db_get_col $res 0 bf_auto_pass]
	tpBindString MktBFReduceRisk  [db_get_col $res 0 bf_reduce_risk]
	tpBindString MktBFMonitorId   [db_get_col $res 0 bf_monitor_id]
	tpBindString MktBFMinVWAPVol  [db_get_col $res 0 bf_min_vwap_vol]
	
	db_close $res
}


#
# Get selections for the market
#
#    order_by - each implementation may order this info differently               
#
proc bind_bf_seln_det {mkt_id {order_by ""}} {

	global DB SELN
	
	if {[info exists SELN]} {
		unset SELN
	}
	
	if {$order_by == ""} { 
		set order_by " o.disporder asc, mr_order asc, prc_ord, o.desc "
	} 
	
	set bf_parent_id ""
	set bf_margin 0.0
	#
	# Get selections for the market
	#
	set sql [subst {
		select
			o.ev_oc_id,
			o.desc,
			o.disporder,
			o.runner_num,
			b.bf_exch_id,
			b.bf_parent_id,
			b.bf_id,
			b.bf_asian_id,
			p.back_prices,
			p.lay_prices,
			p.back_liquid,
			NVL(p.calc_price,0) as calc_price,
			case fb_result
 				when 'H' then 0
 				when 'D' then 1
 				when 'A' then 2
 			end mr_order,
 			case when (o.lp_num is not null and o.lp_den is not null) then
 				o.lp_num/o.lp_den
 					when (o.sp_num is not null and o.sp_den is not null) then
 				o.sp_num/o.sp_den
 					when (o.sp_num_guide is not null and o.sp_den_guide is not null) then
 				o.sp_num_guide/o.sp_den_guide
 					else
 				0
 			end prc_ord,
			a.bf_map_id,
			b.check_bf_liquidity,
			b.auto_price_chng,
			b.price_adj_fac,
			b.reduce_risk,
			b.auto_lay,
			a.bf_ev_items_id
		from
			tEvOc    o,
			tEvMkt   m,
			tEv      e,
			outer (tBFMonitor b,
			outer tBFPrices p),
			outer tBFMap a
		where
			o.ev_mkt_id = $mkt_id and
			m.ev_mkt_id = o.ev_mkt_id and
			e.ev_id     = m.ev_id and
			o.ev_oc_id = b.ob_id and
			b.type = 'OC' and
			b.bf_monitor_id = p.bf_monitor_id and
			a.ob_type = 'OC' and
			a.ob_id = o.ev_oc_id
		order by
			$order_by
	}]

	set stmt     [inf_prep_sql $DB $sql]
	
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res_seln]
	
	for {set r 0} {$r < $nrows} {incr r} {
		set SELN($r,js_oc_desc)   [escape_javascript [db_get_col $res_seln $r desc]]
		set SELN($r,ev_oc_id)     [db_get_col $res_seln $r ev_oc_id]
		set SELN($r,bf_exch_id)   [db_get_col $res_seln $r bf_exch_id]
		set SELN($r,bf_parent_id) [db_get_col $res_seln $r bf_parent_id]
		set bf_parent_id [expr {$bf_parent_id != "" ? $bf_parent_id : $SELN($r,bf_parent_id)}]

		set SELN($r,bf_map_id)	 [db_get_col $res_seln $r bf_map_id]
		set SELN($r,bf_id)       [db_get_col $res_seln $r bf_id]
		set SELN($r,bf_asian_id) [db_get_col $res_seln $r bf_asian_id]
		set calc_price           [db_get_col $res_seln $r calc_price]
		set SELN($r,calc_price)  $calc_price
		
		if {$calc_price > 0} {
			set bf_margin [expr {$bf_margin+(1/double($calc_price))}]
		}

		set bf_back                 [db_get_col $res_seln $r back_prices]
		set bf_lay                  [db_get_col $res_seln $r lay_prices]

		set SELN($r,bf_back_liquid) [db_get_col $res_seln $r back_liquid]
		set SELN($r,check_bf_liquidity)   [db_get_col $res_seln $r check_bf_liquidity]
		set SELN($r,bf_ev_items_id) [db_get_col $res_seln $r bf_ev_items_id]

		if {[db_get_col $res_seln $r check_bf_liquidity] == "N"} {
			set SELN($r,bf_liquidity_checked)       checked
		} else {
			set SELN($r,bf_liquidity_checked)       ""
		}
		
		set SELN($r,auto_price_chng) [db_get_col $res_seln $r auto_price_chng]
		set SELN($r,price_adj_fac) 	 [db_get_col $res_seln $r price_adj_fac]		
		set SELN($r,reduce_risk) 	 [db_get_col $res_seln $r reduce_risk]
		set SELN($r,auto_lay) 	 	 [db_get_col $res_seln $r auto_lay]
				
		#
		# Format the BetFair back/lay prices
		#
		if {$bf_back != ""} {
			set SELN($r,bf_back) ""
			foreach i $bf_back {
				append SELN($r,bf_back) "&pound;${i}<br>"
			}
		} else {
			set SELN($r,bf_back) ""
		}

		if {$bf_lay != ""} {
			set SELN($r,bf_lay) ""
			foreach i $bf_lay {
				append SELN($r,bf_lay) "&pound;${i}<br>"
			}
		} else {
			set SELN($r,bf_lay) ""
		}
	}
	
	db_close $res_seln
	
	#
	# Pull out a BetFair order count for each selection
	#
	
	if {[info exists bf_parent_id] && $bf_parent_id != ""} {
		set sql {
			select
				count(*) as num_orders,
				ev_oc_id,
				bf_ev_oc_id,
				type
			from
				tBFOrder
			where
				bf_ev_mkt_id = ?
			group by
				ev_oc_id, bf_ev_oc_id, type
		}

		set stmt   [inf_prep_sql $DB $sql]
		set res_bf [inf_exec_stmt $stmt $bf_parent_id]
		inf_close_stmt $stmt

		set nrows_bf [db_get_nrows $res_bf]
		
		for {set l 0} {$l < $nrows_bf} {incr l} {
			set ev_oc_id      [db_get_col $res_bf $l ev_oc_id]
			set type          [db_get_col $res_bf $l type]
			set num_orders    [db_get_col $res_bf $l num_orders]

			#
			# Horrid....
			#
			for {set m 0} {$m < $nrows} {incr m} {
				if {$SELN($m,ev_oc_id) == $ev_oc_id} {
					set SELN($m,bf_num_orders_${type}) $num_orders
					if {![info exists SELN($m,bf_num_orders_tot)]} { 				
						set SELN($m,bf_num_orders_tot) $num_orders
					} else {
						set SELN($m,bf_num_orders_tot) [expr {$num_orders + $SELN($m,bf_num_orders_tot)}]
					} 
					break
				}
			}
		}
		
		db_close $res_bf
				
		tpBindVar BFJSOcDesc         SELN js_oc_desc           seln_idx
		tpBindVar BFPrice            SELN calc_price           seln_idx
		tpBindVar BFBack             SELN bf_back              seln_idx
		tpBindVar BFLay              SELN bf_lay               seln_idx
		tpBindVar BFBackLiquid       SELN bf_back_liquid       seln_idx
		tpBindVar BFExchId           SELN bf_exch_id           seln_idx
		tpBindVar BFEvOcId           SELN bf_id                seln_idx
		tpBindVar BFAsianId          SELN bf_asian_id          seln_idx
		tpBindVar BFNumOrdersB       SELN bf_num_orders_B      seln_idx
		tpBindVar BFNumOrdersL       SELN bf_num_orders_L      seln_idx
		tpBindVar BFNumOrdersT       SELN bf_num_orders_tot    seln_idx
		tpBindVar BFOcMapId		     SELN bf_map_id	           seln_idx
		tpBindVar BFLiquidity        SELN check_bf_liquidity   seln_idx
		tpBindVar BFLiquidityChecked SELN bf_liquidity_checked seln_idx
		tpBindVar BFOCEvItemsId      SELN bf_ev_items_id       seln_idx
		tpBindVar BFOCAPC            SELN auto_price_chng      seln_idx
		tpBindVar BFOCPrcAdjFac      SELN price_adj_fac        seln_idx
		tpBindVar BFOCReduceRisk     SELN reduce_risk          seln_idx
		tpBindVar BFOCAutoLay        SELN auto_lay             seln_idx

		if {$bf_margin != 0.0} {
			tpBindString BFMktMargin [format %0.2f [expr {$bf_margin*100.0}]]
		} else {
			tpBindString BFMktMargin ---
		}
		tpBindString BFEvMktId $bf_parent_id
	}
}


# -------------------------------------------------------------------------------
# update the betfair related details for the openbet market
# -------------------------------------------------------------------------------
proc do_bf_mkt_upd {mkt_id} {

   	global DB BF_MKT BF_PB_CAN USERNAME
 
 	set bad 0
 
   	set bf_ev_items_id      [reqGetArg BFEvItemsId]
	set orig_bf_ev_items_id [reqGetArg hidden_BFEvItemsId]

    if {[OT_CfgGet BF_ACTIVE 0] && ($bf_ev_items_id != "" || $orig_bf_ev_items_id != "")} {

		if {$bf_ev_items_id != $orig_bf_ev_items_id && $bf_ev_items_id==""} {
		   set del_mon 1
		} else {
		   set del_mon 0
		}

		set auto_lay  [reqGetArg BFAutoLay]
		set auto_pass [reqGetArg BFAutoPass]
		set red_risk  [reqGetArg BFReduceRisk]
		set bir_delay [reqGetArg BFMktBIRDelay]
		set auto_price_change [reqGetArg BFAutoPrcChng]
		
		if {$auto_pass == "Y" && $red_risk == "Y"} { 
			set msg "Auto-Pass and Reduce-Risk can't be active at the same time!"
			err_bind $msg
			ob::log::write ERROR {do_bf_mkt_upd: $msg}
			return 1
		} 

		if {$auto_price_change == "Y" && $auto_lay == "Y"} { 
			set msg "Auto-Price-Change and Auto-Lay can't be active at the same time!"
			err_bind $msg
			ob::log::write ERROR {do_bf_mkt_upd: $msg}
			return 1		
		} 

		# Selection level checks (dont allow an auto-lay market level setting 
		# to Y if e.g. a selections APC=Y)
		if {(([OT_CfgGet BF_SELN_APC 0] == 1) || ([OT_CfgGet BF_SELN_AUTO_LAY 0] == 1)) && 
			($auto_price_change == "Y" || $auto_lay == "Y")} {
		
			# retrieve openbet selections mapped to betfair selections
			set sql [subst {
				select
					o.ev_oc_id,
					m.auto_lay,
					m.auto_price_chng
				from
					tEvOc o,
					tBFMonitor m
				where
					o.ev_mkt_id = ?
				and
					m.ob_id = o.ev_oc_id
				and
					m.type = 'OC'
			}]
		
			set stmt [inf_prep_sql $DB $sql]
			
			set res  [inf_exec_stmt $stmt $mkt_id]
			
			inf_close_stmt $stmt
			
			set n_rows [db_get_nrows $res]
			
			set l_apc [list] 
			set l_al  [list] 
			
			for {set i 0} {$i < $n_rows} {incr i} { 
				set ev_oc_id [db_get_col $res $i ev_oc_id]
				set al [db_get_col $res $i auto_lay]
				set apc [db_get_col $res $i auto_price_chng]
				lappend l_al "$ev_oc_id" "$al"
				lappend l_apc "$ev_oc_id" "$apc" 				
			} 

			db_close $res

			set update_ok [BETFAIR::UTILS::check_APC_autolay_constraint $auto_price_change $auto_lay $l_apc $l_al]			
			
			if {$update_ok != "OK"} { 
				set msg "Auto-Price-Change and Auto-Lay can't be active at the same time!"
				err_bind $msg
				ob::log::write ERROR {do_bf_mkt_upd: $msg}
				return 1		
			} 			
						
		} 

		incr bad [upd_mkt_map [reqGetArg BFMapId]\
						  $bf_ev_items_id\
						  $mkt_id\
						  [reqGetArg BFMonStatus]\
						  [reqGetArg BFAutoPrcChng]\
						  [reqGetArg BFPollTime]\
						  [reqGetArg BFPriceAdjFac]\
						  [reqGetArg BFMktBKPer]\
						  [reqGetArg BFReduceRisk]\
						  [reqGetArg BFAutoLay]\
						  [reqGetArg BFAutoPass]\
						  [expr {[reqGetArg BFMinVWAPVol] != "" ?\
						  	[reqGetArg BFMinVWAPVol] : 0}]\
						  $del_mon \
						  $orig_bf_ev_items_id\
						  $bir_delay
		]

		if {([reqGetArg BFAutoLay] != "Y") &&\
			([reqGetArg OriginalBFAutoLay] != [reqGetArg BFAutoLay]) } {

			#
			# Cancel auto-lay orders placed by the trade-daemon if auto-lay
			# is turned off
			#
			set ev_mkt_id [reqGetArg MktId]

			set sql {
				select
					ev_oc_id
				from
				   tEvOc
				where
				   ev_mkt_id = ?
			}

			set stmt_sel   	[inf_prep_sql $DB $sql]
			set res_bf 		[inf_exec_stmt $stmt_sel $ev_mkt_id]
			inf_close_stmt 	$stmt_sel

			set nrows_bf [db_get_nrows $res_bf]

			for {set i 0} { $i < $nrows_bf } { incr i} {

				set ev_oc_id [db_get_col $res_bf $i ev_oc_id]

				set sql {
					select 
					   o.bf_order_id,
					   o.bf_bet_id,
					   o.status,
					   o.price,
					   o.avg_price,
					   o.size,
					   o.size_matched,
					   o.type,
					   o.bf_exch_id
					from
					   tBFOrder o
					where
					   o.ev_oc_id = ?
					   and o.type = 'L'
					   and o.status in ('U','P')
					   and o.source = 'T' 
				}

				set stmt_ord   	[inf_prep_sql $DB $sql]
				set res_ord 	[inf_exec_stmt $stmt_ord $ev_oc_id]
				inf_close_stmt 	$stmt_ord

				set nrows_ord [db_get_nrows $res_ord]

				for {set j 0} { $j < $nrows_ord } { incr j} {

					set bf_order_id 	[db_get_col $res_ord $j bf_order_id]
					set bf_exch_id 		[db_get_col $res_ord $j bf_exch_id]
					set bf_bet_id 		[db_get_col $res_ord $j bf_bet_id]
					set bf_status 		[db_get_col $res_ord $j status]
					set size_matched 	[db_get_col $res_ord $j size_matched]
					set bf_price 		[db_get_col $res_ord $j price]
					set bf_size 		[db_get_col $res_ord $j size]

					set service [BETFAIR::INT::get_service $bf_exch_id]

					if {[BETFAIR::SESSION::create_session] == -1 } {
						set msg "Error creating Session"
						err_bind $msg
						ob::log::write ERROR {do_bf_mkt_upd: $msg}
						return 1
					}

					BETFAIR::INT::cancel_bets $service 1 "M,$bf_order_id,$bf_bet_id" ""

					if {[info exists BF_PB_CAN($bf_bet_id,num_orders_can)] &&
						$BF_PB_CAN($bf_bet_id,num_orders_can) &&
						$BF_PB_CAN($bf_bet_id,success) == "true"} {

						#
						# Update the db with the status and matched amount of the bet
						#
						set sql [subst {
							execute procedure pBFUpdOrderDetails(
								p_adminuser    = ?,
								p_order_id     = ?,
								p_status       = ?,
								p_size_matched = ?,
								p_prev_status  = ?,
								p_prev_matched = ?,
								p_transactional = ? 								
							)
						}]

						set stmt [inf_prep_sql $DB $sql]

						inf_begin_tran $DB

						if {[catch {inf_exec_stmt $stmt\
								  $USERNAME\
								  $bf_order_id\
								  "C"\
								  $BF_PB_CAN($bf_bet_id,size_matched)\
								  $bf_status\
								  $size_matched\
								  "N"} msg]} {
							
							inf_close_stmt $stmt
							inf_rollback_tran $DB
							err_bind "Error unwinding cancelled orders liabilities order_id=$bf_order_id $msg"
							ob::log::write ERROR {do_bf_mkt_upd: $msg}
						
						} else { 

							inf_close_stmt $stmt

							# unwind the liabs 
							set liab_ok [BETFAIR::LIAB::cancel_lay_order $bf_order_id $BF_PB_CAN($bf_bet_id,size_cancelled)]

							if {!$liab_ok==1} { 
								inf_rollback_tran $DB
								err_bind "Error unwinding cancelled orders liabilities order_id=$bf_order_id" 
								ob::log::write ERROR {do_bf_mkt_upd - Error unwinding cancelled orders liabilities}							
							} else { 
								inf_commit_tran $DB
							} 
						}						

					} else {
						ob::log::write ERROR {do_bf_mkt_upd -"Error canceling BetFair order"}				
						err_bind "Error canceling BetFair order bf_order_id=$bf_order_id"
					}
				}
				db_close $res_ord
			}
			db_close $res_bf
		}
	}
	if {$bad} {
		return 1
	}
	return 0
}


# ------------------------------------------------------------------------------
# Turns off the betafir APC value 
# ------------------------------------------------------------------------------
proc upd_mkt_apc {mkt_id} {
	
	global DB
	
	# Turn off the APC if the market status has changed from Active to Suspended
	if {[reqGetArg MktStatusOld] == "A" && [reqGetArg MktStatus] == "S" } {
		
		set sql [subst {
			update
				tBFMonitor
			set
				auto_price_chng = 'N'
			where
				ob_id = ?
				and type = 'EM'
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch [inf_exec_stmt $stmt	$mkt_id] msg]} {
			inf_close_stmt $stmt			
			err_bind $msg
			ob::log::write ERROR {upd_mkt_apc - Error updating the APC - $msg}
		}

		inf_close_stmt $stmt
	}
}

#
# ----------------------------------------------------------------------------
# Ascertain the BetFair selection ids and call the API
# for the market depth data
# ----------------------------------------------------------------------------
#
proc go_bf_seln_depth args {

	global BF_MKT_DEPTH

	set bf_ev_mkt_id [reqGetArg BFEvMktId]
	set bf_ev_oc_id  [reqGetArg BFEvOcId]
	set bf_asian_id  [reqGetArg BFAsianId]
	set oc_desc      [reqGetArg OcDesc]
	set service      [BETFAIR::INT::get_service [reqGetArg BFExchId]]

	#
	# Login to BetFair and request market depth for the selection
	#
	if { [BETFAIR::SESSION::create_session] == -1 } {
		set msg "Error creating session. Try again later"
		err_bind $msg
		ob::log::write ERROR {go_bf_seln_depth - $msg}
	} else {
		BETFAIR::INT::get_detail_available_mkt_depth $service "1" $bf_ev_mkt_id $bf_ev_oc_id $bf_asian_id

		if {[info exists BF_MKT_DEPTH(depth)]} {

			tpSetVar  BFDepth    $BF_MKT_DEPTH(depth)
			tpBindString OcDesc  $oc_desc

			tpBindVar BFPrice    BF_MKT_DEPTH odds                        depth_idx
			tpBindVar BFBackAmt  BF_MKT_DEPTH total_available_back_amount depth_idx
			tpBindVar BFLayAmt   BF_MKT_DEPTH total_available_lay_amount  depth_idx
		}
	}

	asPlayFile -nocache bf_selection_depth.html
}


#
# ----------------------------------------------------------------------------
# Match up to a BetFair Market
# ----------------------------------------------------------------------------
#
proc upd_mkt_map {bf_map_id
					bf_ev_items_id
					ob_id
					bf_mon_status
					bf_auto_prc_chng
					bf_poll_time
					bf_prc_adj_fac
					bf_mkt_bk_per
					reduce_risk
					auto_lay
					auto_pass
					min_vwap_vol
					del_mon
					orig_bf_ev_items_id
					bir_delay
					{do_tran "Y"}} {

	global DB USERNAME
	
	if {$del_mon} {
		set sql [subst {
			execute procedure pBFDelMonitor(
					p_adminuser      = ?,
					p_ob_id          = ?,
					p_type           = ?,
					p_transactional  = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]
		
		if {[catch {inf_exec_stmt $stmt $USERNAME $ob_id "EM" $do_tran} msg]} {
			ob::log::write ERROR {upd_mkt_map - $msg}
			inf_close_stmt $stmt
			err_bind $msg
			return 1
		}

		return 0
	}
	
	
	inf_begin_tran $DB
	
	if {$bf_ev_items_id != $orig_bf_ev_items_id} {
		# Update the mapping in tBFMap table
		if {[catch {BETFAIR::UTILS::_set_map "EM" $ob_id $bf_ev_items_id "M"}]} {
			inf_rollback_tran $DB
			return 1
		}
	}

	#
	# Update the BetFair monitoring details
	#
	set sql [subst {
		execute procedure pBFUpdMonitor(
					p_adminuser        = ?,
					p_ob_id            = ?,
					p_status           = ?,
					p_type             = ?,
					p_bf_ev_items_id   = ?,
					p_auto_price_chng  = ?,
					p_poll_time        = ?,
					p_price_adj_fac    = ?,
					p_mkt_bk_per       = ?,
					p_upd_overround    = ?,
					p_reduce_risk      = ?,
					p_auto_pass        = ?,
					p_auto_lay         = ?,
					p_min_vwap_vol     = ?,
					p_transactional    = ?,
					p_bir_delay        = ?
		)
	}]

	if {$bf_prc_adj_fac == "-" || $bf_prc_adj_fac == ""} {
		set bf_prc_adj_fac "0"
	}

	set bf_upd_overround ""
	
	if {$bf_mkt_bk_per == "-"} {
		set bf_mkt_bk_per ""
	} else {
		set bf_upd_overround "Y"
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch [inf_exec_stmt $stmt $USERNAME\
					$ob_id\
					$bf_mon_status\
					"EM"\
					$bf_ev_items_id\
					$bf_auto_prc_chng\
					$bf_poll_time\
					$bf_prc_adj_fac\
					$bf_mkt_bk_per\
					$bf_upd_overround\
					$reduce_risk\
					$auto_pass\
					$auto_lay\
					$min_vwap_vol\
				    "N"\
				    $bir_delay] msg]} {
		ob::log::write ERROR {upd_mkt_map - $msg}
		inf_rollback_tran $DB
		inf_close_stmt $stmt
		return 1
	}
	
	inf_commit_tran $DB
	inf_close_stmt $stmt
	
	set bad 0
	
	if {($bf_ev_items_id != $orig_bf_ev_items_id) && ($orig_bf_ev_items_id != "")} {
		# delete mappings for all the selections under this market
		# while doing a manual matching at the market level, all the selections
		# are unmatched, but not re-matched, since it would result in larger complicacies
		# for ex. a current 'Match Odds' market has 3 selns. if it is now manual matched to
		# a 'Correct Score', then the selns totally differentiate
		incr bad [do_del_bf_seln_matches $ob_id]
	}
	
	if {$bad > 0 } {
		return 1
	}
	return 0
}

#---------------------------------------------------------------------------------------------------
# delete mappings for all the selections under a market while manually changing the market mapping
#----------------------------------------------------------------------------------------------------
proc do_del_bf_seln_matches {ev_mkt_id} {
	global DB USERNAME

	set sql [subst {
		select
			o.ev_oc_id
		from
			tEvOc o,
			tBFMonitor m
		where
			o.ev_mkt_id = ?
		and
			o.ev_oc_id= m.ob_id
		and
			m.type= 'OC'
	}]
	
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
					ob::log::write ERROR {do_del_bf_seln_matches - $msg}
					err_bind "$msg"
					return 1
	}
	
	set nrows  [db_get_nrows $rs]
	inf_close_stmt $stmt
	
	for {set i 0} {$i < $nrows} {incr i} {
		set ev_oc_id [db_get_col $rs $i ev_oc_id]
		
		set sql [subst {
			execute procedure pBFDelMonitor(
					p_adminuser      = ?,
					p_ob_id          = ?,
					p_type           = ?,
					p_transactional  = ?
			)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt $USERNAME $ev_oc_id "OC" "Y"} msg]} {
			ob::log::write ERROR {do_del_bf_seln_matches - $msg}
			inf_close_stmt $stmt
			err_bind "ev_oc_id : $ev_oc_id $msg"
			db_close $rs
			return 1
		}
		inf_close_stmt $stmt
	}
	
	db_close $rs
	return 0
}







}
