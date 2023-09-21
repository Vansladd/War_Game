# ==============================================================
# $Id: bf_seln.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_SELN {

asSetAct ADMIN::BETFAIR_SELN::GoBFUpdSeln    	[namespace code do_bf_upd_seln]

#
# ----------------------------------------------------------------------------
# Bind the betfair related details for the openbet selection 
# Also retrieve all the betfair selections under the mapped betfair market
# ----------------------------------------------------------------------------
#
proc go_bf_oc_upd {oc_id mkt_id} {

	global DB BF_MTCH

	#
	# Get selection information
	#
	set sql [subst {
		select
			m.auto_price_chng as bf_auto_prc_chng,
 			m.price_adj_fac as bf_prc_adj_fac,
 			m.auto_lay as bf_auto_lay,
 			m.auto_pass as bf_auto_pass,
			m.reduce_risk as bf_reduce_risk,
 			a.bf_map_id,
 			i.bf_ev_items_id,
 			i.bf_desc,
 			i.bf_id
		from
			tEvOc       o,			
			outer tEvOc o2,
			outer tBFMonitor m,
 			outer (tBFMap a,
 			outer tBFEvItems i)
		where
			o.ev_oc_id = $oc_id and			
			o.ev_mkt_id = o2.ev_mkt_id and
			((o.fb_result != '-' and
			  o.ev_oc_id = o2.ev_oc_id) or
			 (o.fb_result = '-' and
			  o.runner_num = o2.runner_num and
			  o2.runner_num is not null and
			  o2.fb_result != '-')) and
			o.ev_oc_id =  a.ob_id and
 			a.ob_type = 'OC' and
 			a.bf_ev_items_id = i.bf_ev_items_id and
 			o.ev_oc_id = m.ob_id and
 			m.type = 'OC'
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set autoPrcChng [db_get_col $res_seln 0 bf_auto_prc_chng]
	
	if {$autoPrcChng == ""} { 
		set autoPrcChng "-"
	} 

	tpBindString OcBFDefEvItemsId   [db_get_col $res_seln 0 bf_ev_items_id]
	tpBindString OcBFDefMapId       [db_get_col $res_seln 0 bf_map_id]
	tpBindString OcBFDefDesc        [db_get_col $res_seln 0 bf_desc]
	tpBindString OcBFAutoPrcChng    $autoPrcChng
	tpBindString OcBFAutoLay        [db_get_col $res_seln 0 bf_auto_lay]
	tpBindString OcBFAutoPass       [db_get_col $res_seln 0 bf_auto_pass]
	tpBindString OcBFPrcAdj         [db_get_col $res_seln 0 bf_prc_adj_fac]
	tpBindString OcBFReduceRisk     [db_get_col $res_seln 0 bf_reduce_risk]
	
	db_close $res_seln
	
	#
	# Get market bf_id and sort to get betfair selections under this betfair market
	#
	set sql [subst {
		select
			i.bf_id,
			bm.name as mkt_name
		from
			tBFMap m,
			tBFEvItems i,
			tBFMarket bm
		where
			m.ob_type = 'EM'
		and m.ob_id = ?
		and m.bf_ev_items_id = i.bf_ev_items_id
		and bm.bf_ev_items_id = i.bf_ev_items_id
	}]

	set stmt  [inf_prep_sql $::DB $sql]
	set res   [inf_exec_stmt $stmt $mkt_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] > 0} {
		set bf_parent_id [db_get_col $res 0 bf_id]
		set mkt_name	 [string toupper [db_get_col $res 0 mkt_name]]
		
		db_close $res
		
		#
		# Get betfair selections details under the betfair market
		#
		set sql [subst {
			select
				i.bf_ev_items_id,
				i.bf_desc,
				o.handicap
			from
				tBFEvItems i,
				tBFEvoc o
			where
				i.bf_type = 'OC'
			and 	i.bf_ev_items_id = o.bf_ev_items_id
			and i.bf_parent_id = ?
		}]

		set stmt  [inf_prep_sql $::DB $sql]
		set res   [inf_exec_stmt $stmt $bf_parent_id]
		inf_close_stmt $stmt

		set BF_MTCH(nrows) [db_get_nrows $res]
		for {set i 0 } {$i < $BF_MTCH(nrows)} {incr i} {
			set BF_MTCH($i,bf_ev_items_id) [db_get_col $res $i bf_ev_items_id]
			
			#
			# If market is mapped to AH market then selection dropdown
			# will show handicap values along with the selection desc
			#
			if {$mkt_name == "ASIAN HANDICAP"} {
				set BF_MTCH($i,bf_desc)        "[db_get_col $res $i bf_desc] [db_get_col $res $i handicap]"
			} else {
				set BF_MTCH($i,bf_desc)        [db_get_col $res $i bf_desc]
			}
		}

		db_close $res

		tpBindVar BFIds        BF_MTCH bf_ev_items_id bf_mtch_idx
		tpBindVar BFDesc       BF_MTCH bf_desc        bf_mtch_idx
		tpSetVar  BFNumOcs     $BF_MTCH(nrows)
	}
}


# -------------------------------------------------------------------------------
# update the betfair related details for the openbet selection
# -------------------------------------------------------------------------------
proc do_bf_oc_upd args {

	#
	# Assign BetFair ev_oc details
	#
	set bf_ev_items_id      [reqGetArg BFEvItemsId]
	set orig_bf_ev_items_id [reqGetArg hidden_BFEvItemsId]

	if {$bf_ev_items_id != "" || $orig_bf_ev_items_id != ""} {

		set bad [do_bf_upd_ev_oc [reqGetArg OcId]]
		
		if {$bad} {

			#
			# Something went wrong : go back to the selection screen
			#
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			ADMIN::SELN::go_oc_upd
			return $bad
		}
	}
	return
}


#
# ----------------------------------------------------------------------------
# Match up to a BetFair Selection
# ----------------------------------------------------------------------------
#
proc do_bf_upd_ev_oc {ev_oc_id} {

	global DB USERNAME

	set auto_pass           "-"

	set bf_map_id           [reqGetArg BFMapId]
	set bf_ev_items_id      [reqGetArg BFEvItemsId]
	set orig_bf_ev_items_id [reqGetArg hidden_BFEvItemsId]
	set price_adj_fac       [reqGetArg BFPriceAdjFac]
	set auto_price_chng     [reqGetArg BFAutoPrcChng]
	set auto_lay 			[reqGetArg BFAutoLay]
	set reduce_risk 		[reqGetArg BFReduceRisk]

	#
	# If we need to delete the BF selection then let's do it here
	#
	if {$orig_bf_ev_items_id != "" &&
		$orig_bf_ev_items_id != $bf_ev_items_id} {

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
			inf_close_stmt $stmt
			err_bind $msg
			return 1
		}
	}

	if {$bf_ev_items_id != ""} {

		# Update the tBFMap table for the mapping
		set sql [subst {
			execute procedure pBFUpdMap (
				p_adminuser         = ?,
				p_status 	        = ?,
				p_ob_type           = ?,
				p_ob_id             = ?,
				p_bf_ev_items_id	= ?
				)
		}]

		set stmt [inf_prep_sql $DB $sql]

		inf_begin_tran $DB

		if {[catch {set rs [inf_exec_stmt $stmt	$USERNAME "A" "OC" $ev_oc_id $bf_ev_items_id]} msg]} {
						ob::log::write ERROR {do_bf_upd_ev_oc - $msg}
						inf_rollback_tran $DB
						inf_close_stmt $stmt
						err_bind $msg
						return 1
		}

		inf_close_stmt $stmt
		db_close $rs

		#
		# retrieve market monitor info 		
		#
		set sql [subst {
			select
				*
			from			
				tBFMonitor 
			where
				type = 'EM'
			and ob_id in (select ev_mkt_id from tevoc where ev_oc_id = ?) 
		}]

		set stmt [inf_prep_sql $DB $sql]

		set res  [inf_exec_stmt $stmt $ev_oc_id]

		inf_close_stmt $stmt

		set nrows [db_get_nrows $res] 
		
		if {$nrows > 0} { 		
			#
			# check that auto_lay and APC aren't set at the same time
			#
			set mkt_apc [db_get_col $res 0 auto_price_chng] 
			set mkt_al  [db_get_col $res 0 auto_lay] 			
			if {([OT_CfgGet BF_SELN_APC 0] == 1) || ([OT_CfgGet BF_SELN_AUTO_LAY 0] == 1)} { 
				set l_apc [list "$ev_oc_id" "[reqGetArg BFAutoPrcChng]"]
				set l_al  [list "$ev_oc_id" "[reqGetArg BFAutoLay]"]

				set update_ok [BETFAIR::UTILS::check_APC_autolay_constraint $mkt_apc $mkt_al $l_apc $l_al]		

				if {$update_ok != "OK"} { 					
					err_bind "Can't have APC and Auto-Lay both set to YES for markets or selections" 			
					db_close $res
					return 0
				} 
			} 	
		} 

		db_close $res

		#
		# Update the BetFair monitoring details
		#
		set sql [subst {
			execute procedure pBFUpdMonitor(
											p_adminuser       = ?,
											p_ob_id           = ?,
											p_type            = ?,
											p_bf_ev_items_id  = ?,
											p_auto_price_chng = ?,
											p_poll_time       = ?,
											p_price_adj_fac   = ?,
											p_reduce_risk     = ?,
											p_auto_lay        = ?,
											p_auto_pass       = ?,
											p_transactional   = ?
											)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch [inf_exec_stmt $stmt\
						$USERNAME\
						$ev_oc_id\
						"OC"\
						$bf_ev_items_id\
						$auto_price_chng\
						"60000"\
						$price_adj_fac\
						$reduce_risk\
						$auto_lay\
						$auto_pass\
						"N"] msg]} {
			inf_rollback_tran $DB
			inf_close_stmt $stmt
			err_bind $msg
			return 1
		}

		inf_commit_tran $DB
		inf_close_stmt $stmt

		return 0
	}

	return 0
}



#--------------------------------------------------------------
# To update selection betfair liquidity check
#--------------------------------------------------------------
proc do_bf_upd_liquidity {} {
	
	global DB USERNAME
	
	set ev_mkt_id [reqGetArg EvMkt]
	
	# retrive openbet selections mapped to betfair selections
	set sql [subst {
		select
			o.ev_oc_id
		from
			tEvOc o,
			tBFMonitor m
		where
			o.ev_mkt_id =  ?
		and
			m.ob_id = o.ev_oc_id
		and
			m.type = 'OC'
	}]

	set stmt [inf_prep_sql $DB $sql]
	
	set res  [inf_exec_stmt $stmt $ev_mkt_id]
	
	inf_close_stmt $stmt
	
	set n_rows [db_get_nrows $res]
	
	for {set i 0} {$i < $n_rows} {incr i} {
		set oc_id 		[db_get_col $res $i ev_oc_id]
		
		set check_bf_liquidity     [reqGetArg BFLiquidityVal_$oc_id]
		set check_bf_liquidity_old [reqGetArg old_BFLiquidityVal_$oc_id]
		set bf_ev_items_id         [reqGetArg BFOCEvItemsId_$oc_id]
		
		if {$check_bf_liquidity_old != $check_bf_liquidity} {
			#
			# Update the tBFMonitor details with the new value of bf_liquidity
			#			
			if {[OT_CfgGet BF_INF731_COMPLIANT 0]} { 
				set param_check_liquid " ,p_check_bf_liquid = ? "
			} else { 
				set param_check_liquid " ,p_check_bf_liquidity = ? "
			} 
			
			set sql [subst {
				execute procedure pBFUpdMonitor(
						p_adminuser          = ?,
						p_ob_id              = ?,
						p_type               = ?,
						p_bf_ev_items_id     = ?
						$param_check_liquid
						)
			}]
		
			set stmt [inf_prep_sql $DB $sql]
		
			if {[catch [inf_exec_stmt $stmt\
							$USERNAME\
							$oc_id\
							"OC"\
							$bf_ev_items_id\
							$check_bf_liquidity] msg]} {
				inf_close_stmt $stmt
				err_bind $msg
			}
			
			inf_close_stmt $stmt
		}
	}
	
	db_close $res
	
	#
	# go back to the market screen
	#
	ADMIN::MARKET::go_mkt
}



#--------------------------------------------------------------
# To update selection level Price/Trade/Reduce Risk information 
#--------------------------------------------------------------
proc do_bf_upd_seln {} {
	
	global DB USERNAME
	
	set ev_mkt_id [reqGetArg EvMkt]
	set mkt_mon_id [reqGetArg MktBFMonitorId] 
	
	# retrieve market monitor info 
	set sql [subst {
		select
			*
		from			
			tBFMonitor 
		where
			bf_monitor_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	
	set res  [inf_exec_stmt $stmt $mkt_mon_id]
	
	inf_close_stmt $stmt
	
	set mkt_apc [db_get_col $res 0 auto_price_chng] 
	set mkt_al  [db_get_col $res 0 auto_lay] 
	
	db_close $res
	
	# retrieve openbet selections mapped to betfair selections
	set sql [subst {
		select
			o.ev_oc_id
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
	
	set res  [inf_exec_stmt $stmt $ev_mkt_id]
	
	inf_close_stmt $stmt
	
	set n_rows [db_get_nrows $res]
		
	# first need to check that auto_lay and APC aren't set at the same time
	if {([OT_CfgGet BF_SELN_APC 0] == 1) || ([OT_CfgGet BF_SELN_AUTO_LAY 0] == 1)} { 
	
		set l_apc [list] 
		set l_al  [list]
	
		for {set i 0} {$i < $n_rows} {incr i} {
			set oc_id 			[db_get_col $res $i ev_oc_id]			
			set BFOCAPC     	[reqGetArg BFOCAPC_$oc_id]
			set BFOCAutoLay     [reqGetArg BFOCAutoLay_$oc_id]			
			lappend l_apc "$oc_id" "$BFOCAPC"
			lappend l_al "$oc_id" "$BFOCAutoLay" 			
		}
			
		set update_ok [BETFAIR::UTILS::check_APC_autolay_constraint $mkt_apc $mkt_al $l_apc $l_al]		
	} else { 	
		set update_ok [BETFAIR::UTILS::check_APC_autolay_constraint $mkt_apc $mkt_al]	
	} 	
	
	if {$update_ok != "OK"} { 		
		db_close $res
		err_bind "Can't have APC and Auto-Lay both set to YES for markets or selections" 
		ADMIN::MARKET::go_mkt
		return 
	} 
	
	for {set i 0} {$i < $n_rows} {incr i} {
		set oc_id 			[db_get_col $res $i ev_oc_id]
		
		set bf_ev_items_id  [reqGetArg BFOCEvItemsId_$oc_id]
				
		set BFOCAPC     		[reqGetArg BFOCAPC_$oc_id]
		set BFOCAPC_old 		[reqGetArg old_BFOCAPC_$oc_id]
		set BFOCPrcAdjFac     	[reqGetArg BFOCPrcAdjFac_$oc_id]
		set BFOCPrcAdjFac_old 	[reqGetArg old_BFOCPrcAdjFac_$oc_id]
		set BFOCReduceRisk     	[reqGetArg BFOCReduceRisk_$oc_id]
		set BFOCReduceRisk_old 	[reqGetArg old_BFOCReduceRisk_$oc_id]
		set BFOCAutoLay     	[reqGetArg BFOCAutoLay_$oc_id]
		set BFOCAutoLay_old 	[reqGetArg old_BFOCAutoLay_$oc_id]
		set BFOCLiquidity       [reqGetArg BFLiquidityVal_$oc_id]
		set BFOCLiquidity_old   [reqGetArg old_BFLiquidityVal_$oc_id]

		ob_log::write INFO {Checking monitor changes for selection ev_oc_id=$oc_id}

		ob_log::write INFO {APC($oc_id) old=$BFOCAPC_old new=$BFOCAPC} 
		ob_log::write INFO {PRICE FAC($oc_id) old=$BFOCPrcAdjFac_old new=$BFOCPrcAdjFac} 
		ob_log::write INFO {RISKREDUCE($oc_id) old=$BFOCReduceRisk_old new=$BFOCReduceRisk} 
		ob_log::write INFO {A-LAY($oc_id) old=$BFOCAutoLay_old new=$BFOCAutoLay} 
		ob_log::write INFO {LIQ($oc_id) old=$BFOCLiquidity_old new=$BFOCLiquidity} 
		
		if {$BFOCAPC != $BFOCAPC_old || $BFOCPrcAdjFac != $BFOCPrcAdjFac_old \
			|| $BFOCReduceRisk != $BFOCReduceRisk_old || $BFOCAutoLay != $BFOCAutoLay_old \
			|| $BFOCLiquidity_old != $BFOCLiquidity} {
			
			ob_log::write INFO {*** Updating Monitor for ev_oc_id=$oc_id} 
			
			#
			# Update the tBFMonitor details with the new values 
			#			
			if {[OT_CfgGet BF_INF731_COMPLIANT 0]} { 
				set param_check_liquid " ,p_check_bf_liquid = ? "
			} else { 
				set param_check_liquid " ,p_check_bf_liquidity = ? "
			} 
			
			set sql [subst {
				execute procedure pBFUpdMonitor(
						p_adminuser          = ?,
						p_ob_id              = ?,
						p_type               = ?,
						p_bf_ev_items_id     = ?,
						p_auto_price_chng    = ?,
						p_price_adj_fac      = ?,
						p_reduce_risk        = ?,
						p_auto_lay           = ?
						$param_check_liquid
				)
			}]
		
			set stmt [inf_prep_sql $DB $sql]
		
			if {[catch [inf_exec_stmt $stmt\
							$USERNAME\
							$oc_id\
							"OC"\
							$bf_ev_items_id\
							$BFOCAPC\
							$BFOCPrcAdjFac\
							$BFOCReduceRisk\
							$BFOCAutoLay\
							$BFOCLiquidity] msg]} {
				inf_close_stmt $stmt
				err_bind $msg
			}
			
			inf_close_stmt $stmt
		} else { 
			ob_log::write INFO {*** No changes required for ev_oc_id=$oc_id} 
		} 
	}
	
	db_close $res
	
	#
	# go back to the market screen
	#
	ADMIN::MARKET::go_mkt
}



}
