# ==============================================================
# $Id: bf_order.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::BETFAIR_ORDER {

asSetAct ADMIN::BETFAIR_ORDER::GoBFPlaceOrder        [namespace code go_bf_place_order]
asSetAct ADMIN::BETFAIR_ORDER::DoBFPlaceOrder        [namespace code place_bf_seln_order]
asSetAct ADMIN::BETFAIR_ORDER::GoBFSelnOrderDetails  [namespace code go_bf_seln_order_details]
asSetAct ADMIN::BETFAIR_ORDER::GoBFOrderUpd          [namespace code go_bf_seln_order_upd]
asSetAct ADMIN::BETFAIR_ORDER::DoBFOrderUpd          [namespace code do_bf_seln_order_upd]
asSetAct ADMIN::BETFAIR_ORDER::DoOBOrderUpd          [namespace code do_ob_seln_order_upd]
asSetAct ADMIN::BETFAIR_ORDER::GoSearchOrders        [namespace code go_search_orders]
asSetAct ADMIN::BETFAIR_ORDER::DoSearchOrders	     [namespace code do_search_orders]


#
# ----------------------------------------------------------------------------
# Play the order screen
# ----------------------------------------------------------------------------
#
proc go_bf_place_order args {
	
	global DB
	global BF_PRC_LAD
	
	if {[OT_CfgGet BF_ACTIVE 0] == 0} {
			set msg "Betfair Feature is not enabled in Admin. \
				Set BF_ACTIVE to 1 to enable this feature"
			err_bind $msg
			ob::log::write ERROR {go_bf_place_order - $msg}
			asPlayFile -nocache bf_order.html
			return
	}

	set ev_class_id  [reqGetArg ClassId]
	set ev_oc_id     [reqGetArg OcId]
	set oc_desc      [reqGetArg OcDesc]
	set bf_exch_id   [reqGetArg BFExchId]
	set bf_ev_mkt_id [reqGetArg BFEvMktId]
	set bf_ev_oc_id  [reqGetArg BFEvOcId]
	set bf_asian_id  [reqGetArg BFAsianId]
	set type         [reqGetArg BFOrderType]

	tpBindString  ClassId      $ev_class_id
	tpBindString  OcId         $ev_oc_id
	tpBindString  OcDesc       $oc_desc
	tpBindString  BFExchId     $bf_exch_id
	tpBindString  BFEvMktId    $bf_ev_mkt_id
	tpBindString  BFEvOcId     $bf_ev_oc_id
	tpBindString  BFAsianId    $bf_asian_id
	tpBindString  BFOrderType  $type
	tpSetVar      BFOrderTypeV $type

	if {![info exists BF_PRC_LAD]} {

		#
		# Store the order details
		#
		set sql {
			select
				dec_price
			from
				tBFPriceLadder
			order by
				dec_price
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
			err_bind $msg
			ob::log::write ERROR {go_bf_place_order - $msg}
		}

		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set BF_PRC_LAD($i,dec_price) [db_get_col $rs $i dec_price]
		}

		db_close $rs

		set BF_PRC_LAD(nrows) $nrows
		set BF_PRC_LAD(max_back) $BF_PRC_LAD([expr {$i-1}],dec_price)
		set BF_PRC_LAD(min_lay)  $BF_PRC_LAD(0,dec_price)
		set BF_PRC_LAD(bf_large_order) [OT_CfgGet BF_LARGE_ORDER 1000]
		set BF_PRC_LAD(bf_small_order) [OT_CfgGet BF_SMALL_ORDER 10]
	}

	if {$type == "B"} {
		tpBindString BFDefPrice $BF_PRC_LAD(max_back)
	} else {
		tpBindString BFDefPrice $BF_PRC_LAD(min_lay)
	}

	tpSetVar BFNumPrices $BF_PRC_LAD(nrows)

	tpBindString BFLargeOrder $BF_PRC_LAD(bf_large_order)
	tpBindString BFSmallOrder $BF_PRC_LAD(bf_small_order)

	tpBindVar 	 BFPrice    	BF_PRC_LAD dec_price  bf_price_idx

	asPlayFile -nocache bf_order.html
}

#
# ----------------------------------------------------------------------------
# Place the order on Betfair:- 
#	i) Create a Betfair session
#  ii) Register order in tbforder - update liabilities
# iii) Make API call to betfair
#  iv) Update order in OpenBet - update liabilities depending on response
# ----------------------------------------------------------------------------
#
proc place_bf_seln_order args {

	global DB
	global USERNAME
	global BF_PB

	if {[info exists BF_PB]} {
		unset BF_PB
	}

	set ev_oc_id     [reqGetArg OcId]
	set oc_desc      [reqGetArg OcDesc]
	set bf_exch_id   [reqGetArg BFExchId]
	set bf_ev_mkt_id [reqGetArg BFEvMktId]
	set bf_ev_oc_id  [reqGetArg BFEvOcId]
	set bf_asian_id  [reqGetArg BFAsianId]
	set order_type   [reqGetArg BFOrderType]
	set bf_price     [reqGetArg BFPrice]
	set bf_size      [reqGetArg BFSize]
	set ev_class_id  [reqGetArg ClassId]
	
	tpBindString ClassId     	$ev_class_id

	set BF_LARGE [OT_CfgGet BF_LARGE_ORDER 1000]
	set BF_SMALL [OT_CfgGet BF_SMALL_ORDER 10]

	if {$bf_size > $BF_LARGE} {
		error "Order larger than maximum allowed ($BF_LARGE)"
		go_bf_seln_order_details
		return
	}

	if {($bf_size > $BF_SMALL) && (![op_allowed BFLargeOrder])} {
		error "You do not have permissions to place an Betfair order of this size."
		go_bf_seln_order_details
		return
	}

	if {$bf_size <= $BF_SMALL && !([op_allowed BFLargeOrder] || [op_allowed BFSmallOrder])} {
		error "You do not have permissions to place an Betfair order"
		go_bf_seln_order_details
		return
	}

	ob::log::write INFO {BETFAIR PLACE ORDER ------------- START ------------------}
	ob::log::write INFO {BETFAIR PLACE ORDER - ev_oc_id: $ev_oc_id}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_ev_mkt_id: $bf_ev_mkt_id}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_ev_oc_id: $bf_ev_oc_id}
	ob::log::write INFO {BETFAIR PLACE ORDER - order_type: $order_type}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_price: $bf_price}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_size: $bf_size}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_asian_id: $bf_asian_id}
	ob::log::write INFO {BETFAIR PLACE ORDER - bf_exch_id: $bf_exch_id}

	if {[catch {
		set sql [subst {
			select
				e.ev_class_id,
				e.ev_id,
				e.desc,
				m.ev_mkt_id,
				g.name
			from
				tEv e,
				tEvMkt m,
				tEvOc o,
				tEvOcGrp g
			where
				e.ev_id = m.ev_id and
				o.ev_mkt_id = m.ev_mkt_id and
				m.ev_oc_grp_id = g.ev_oc_grp_id and
				o.ev_oc_id = ?
		}]
	} msg]} {
		err_bind $msg
		ob::log::write ERROR {place_bf_seln_order - $msg}
		go_bf_seln_order_details
		return
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $ev_oc_id]

	set nrows  [db_get_nrows $rs]

	if {$nrows} {
		set ev_class_id [db_get_col $rs 0 ev_class_id]
		set ev_id     [db_get_col $rs 0 ev_id]
		set ev_name   [db_get_col $rs 0 desc]
		set mkt_id    [db_get_col $rs 0 ev_mkt_id]
		set mkt_name  [db_get_col $rs 0 name]
	} else {
		set msg "EvOc Details not found"
		err_bind $msg
		ob::log::write ERROR {place_bf_seln_order - $msg}
		go_bf_seln_order_details
		return
	}

	set bf_acct_id [ADMIN::BETFAIR_ACCT::get_active_bf_account $ev_class_id]

	if {$bf_acct_id == "" } {
		go_bf_place_order
		return
	}

	tpBindString BFAcctId $bf_acct_id

	#
	# Create a Betfair session
	#
	set service [BETFAIR::INT::get_service $bf_exch_id]

	if {[BETFAIR::SESSION::create_session "" $bf_acct_id] == -1} {					
		set msg "Error creating session. Try again later"
        ob::log::write ERROR {place_bf_seln_order - $msg}
		err_bind "Could not place Betfair order. Error creating session. Try again later."
		go_bf_place_order
		return 
	} 

	ob::log::write INFO {BETFAIR PLACE ORDER - Insert into OpenBet}

	#
	# Store the order details
	#
	set sql [subst {
		execute procedure pBFInsOrder(
			p_adminuser    = ?,
			p_source       = ?,
			p_ev_oc_id     = ?,
			p_bf_ev_mkt_id = ?,
			p_bf_ev_oc_id  = ?,
			p_bf_asian_id  = ?,
			p_bf_exch_id   = ?,
			p_type         = ?,
			p_price        = ?,
			p_size         = ?,
			p_bf_acct_id   = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	#----------------- Start Transaction --------------------------

	inf_begin_tran $DB

	if {[catch {set rs [inf_exec_stmt $stmt\
							$USERNAME\
							"M"\
							$ev_oc_id\
							$bf_ev_mkt_id\
							$bf_ev_oc_id\
							$bf_asian_id\
							$bf_exch_id\
							$order_type\
							$bf_price\
							$bf_size\
							$bf_acct_id]
	} msg]} {
		inf_rollback_tran $DB
		inf_close_stmt $stmt
		err_bind $msg
		ob::log::write ERROR {place_bf_seln_order - $msg}
		return
	}

	inf_close_stmt $stmt

	set bf_order_id [db_get_coln $rs 0 0]

	db_close $rs

	ob::log::write INFO {BETFAIR PLACE ORDER - Successfully inserted into OpenBet bf_order_id=$bf_order_id}

	set lp_liab    [expr {double($bf_size)*$bf_price}]
	set lp_count   1
	set lp_stake   $bf_size
	set apc_total  $lp_liab

	#
	# Update liabs
	#	
	if {$order_type == "B"} {
		set liab_ok [BETFAIR::LIAB::add_back_order $bf_order_id $bf_size $bf_price]
	} else {
		set liab_ok [BETFAIR::LIAB::add_lay_order $bf_order_id $bf_size $bf_price]
	}

	if {!$liab_ok==1} { 
		inf_rollback_tran $DB
		err_bind "Error updating liabilities"
		ob::log::write ERROR {place_bf_seln_order - ERROR updating liabilities}
		go_bf_place_order 
		return
	} 

	inf_commit_tran $DB

	#
	# ----------------- End transaction - Order Stored In OpenBet -----------
	#

	#
	# Place the order on BetFair
	#
		
	BETFAIR::INT::place_bets $service 1 $bf_ev_mkt_id $bf_ev_oc_id $bf_asian_id $order_type\
		$bf_price $bf_size $bf_order_id "order" ""

	if {[info exists BF_PB(num_orders)] || [info exists BF_PB(err_code)]} {

		#
		# Handle Failure/Success
		#

		ob_log::write_array INFO BF_PB

		#			
		# Determine order status based on the BF success code and size matched
		#
		if {[info exists BF_PB(0,result_code)] && $BF_PB(0,result_code) == "OK" \
			&& $BF_PB(0,success) == "true" && $BF_PB(num_orders)==1} {
			
			if {$BF_PB(0,size_matched) == $bf_size} {
				set status "M"
			} elseif {$BF_PB(0,size_matched) != "0"} {
				set status "P"
			} else {
				set status "U"
			}

		} else {
			
			set status "X"						
			
			set BF_PB(0,average_price_matched) 	"0"
			set BF_PB(0,size_matched) 			"0"
			set BF_PB(0,bet_id) 				""
			set BF_PB(0,success) 				"false"
			
			if {[info exists BF_PB(err_code)]} {
				set err_bind "Unknown Bet Placement Failure"
				set BF_PB(0,result_code) $BF_PB(err_code)
			} else { 
				set err_bind "Unknown Bet Placement Failure"
				set BF_PB(0,result_code) "UNKNOWN_FAIL"
			} 
		}

		#
		# update order details and lock the row
		#
		set sql [subst {
			execute procedure pBFUpdOrderDetails(
											 p_adminuser     = ?,
											 p_order_id      = ?,
											 p_status        = ?,
											 p_avg_price     = ?,
											 p_size_matched  = ?,
											 p_bf_bet_id     = ?,
											 p_prev_status   = ?,
											 p_prev_matched  = ?,
											 p_transactional = ?
											 )
		}]

		inf_begin_tran $DB

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			inf_exec_stmt $stmt\
				$USERNAME\
				$bf_order_id\
				$status\
				$BF_PB(0,average_price_matched)\
				$BF_PB(0,size_matched)\
				$BF_PB(0,bet_id)\
				"N"\
				"0"\
				"N"} msg]} {
			ob::log::write ERROR {place_bf_seln_order - ERROR UPDATING BET $msg}
			inf_rollback_tran $DB
			inf_close_stmt $stmt
			err_bind "Error updating bet $msg"	
			go_bf_place_order
			catch {unset BF_PB}
			return 
		}

		inf_close_stmt $stmt

		#
		# Update the Liabilities 
		#

		set liab_ok 1

		if {$status == "X"} {
			if {$order_type == "L"} {
				set liab_ok [BETFAIR::LIAB::cancel_lay_order $bf_order_id]
			} elseif {$order_type == "B"} {
				set liab_ok [BETFAIR::LIAB::cancel_back_order $bf_order_id]
			} 
		} 

		if {$order_type == "B" && ($status == "M" || $status == "P")} {
			set liab_ok [BETFAIR::LIAB::match_back_order $bf_order_id \
						$BF_PB(0,size_matched) $BF_PB(0,average_price_matched) "0" "0.0"]
		} 
		
		if {$order_type == "L" && ($status == "M" || $status == "P")} {
			set liab_ok [BETFAIR::LIAB::match_lay_order $bf_order_id $BF_PB(0,size_matched) 0]
		}

		if {!$liab_ok==1} { 
			inf_rollback_tran $DB
			err_bind "Error updating liabilities"
			ob::log::write ERROR {place_bf_seln_order - ERROR updating liabilities}
			go_bf_place_order
			catch {unset BF_PB}
			return 
		} 

		inf_commit_tran $DB

		tpBindString BFExchId    $bf_exch_id
		tpBindString BFSize      $bf_size
		tpBindString BFPrice     $bf_price
		tpBindString OcId        $ev_oc_id
		tpBindString OcDesc      $oc_desc
		tpBindString BFOrderType $order_type
		tpBindString BFOrderId   $bf_order_id 

		tpSetVar  BFOrderTypeV 	 $order_type

		tpBindString BFBetId      $BF_PB(0,bet_id)
		tpBindString BFResCode    $BF_PB(0,result_code)
		tpBindString BFSuccess    $BF_PB(0,success)
		tpBindString BFAvgPrcMat  $BF_PB(0,average_price_matched)
		tpBindString BFSizeMat    $BF_PB(0,size_matched)

		#
		# send message to router 
		#
		if {[catch {MONITOR::send_bf_order \
					"Manually Placed Orders" \
					$ev_id \
					$ev_name \
					$mkt_id \
					$mkt_name \
					$ev_oc_id \
					$oc_desc \
					$BF_PB(0,bet_id) \
					$status \
					$BF_PB(0,average_price_matched) \
					$BF_PB(0,size_matched)\
					$bf_size\
					$bf_order_id} msg]} {
			ob_log::write ERROR {place_bf_seln_order - ERROR sending monitor msg: $msg}		
		}

	} else {
		#
		# Probable timeout so don't roll back liabilities. 
		#				
		err_bind "TIMEOUT (check on Betfair to see if order was placed)."
		
		#
		# send message to router 
		#
		if {[catch {MONITOR::send_bf_order \
					"Manually Placed Orders" \
					$ev_id \
					$ev_name \
					$mkt_id \
					$mkt_name \
					$ev_oc_id \
					$oc_desc \
					"" \
					"B" \
					"" \
					""\
					$bf_size\
					$bf_order_id} msg]} {
			ob_log::write ERROR {place_bf_seln_order - ERROR sending monitor msg: $msg}		
		}	
		
		go_bf_seln_order_upd $bf_order_id
		catch {unset BF_PB}
		return
	} 
	
	asPlayFile -nocache bf_order_placed.html
	
	catch {unset BF_PB}
}


#
# ----------------------------------------------------------------------------
# Retrieve order details from db for given selection
# ----------------------------------------------------------------------------
#
proc go_bf_seln_order_details {} {

	global DB
	global BF_ORDERS

	if {[info exists BF_ORDERS]} {
		unset BF_ORDERS
	}

	set ev_oc_id     [reqGetArg OcId]

	set sql [subst {
			select
		        bf_order_id,
				o.cr_date,
				o.status,
				o.type,
				o.price,
				o.avg_price,
				o.size,
				o.size_matched,
				o.bf_bet_id,
				o.settled,
				o.bf_profit,
				a.name,
				a.bf_acct_id,
				a.status acct_status,
				e.ev_class_id,
				s.desc				
			from
				tBFOrder o,
				tBFAccount a,
				tEvOc s,
				tEv e
			where
				o.bf_acct_id = a.bf_acct_id
			and o.ev_oc_id = ? 
			and o.ev_oc_id = s.ev_oc_id
			and s.ev_id = e.ev_id 
	}]

	set stmt 	[inf_prep_sql $DB $sql]
	set rs 		[inf_exec_stmt $stmt $ev_oc_id]

	inf_close_stmt $stmt

	set nrows  [db_get_nrows $rs]
	set fields [db_get_colnames $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach j $fields {
			set BF_ORDERS($i,$j) [db_get_col $rs $i $j]
		}
		if {$i== 0} { 
			tpBindString OcDesc   [db_get_col $rs 0 desc]
			tpBindString ClassId  [db_get_col $rs 0 ev_class_id]
		}
	}

	db_close $rs

	tpSetVar     BFNumOrders  $nrows
	tpBindString OcId         $ev_oc_id
	
	tpBindVar BFOrderId    BF_ORDERS bf_order_id            order_idx
	tpBindVar BFCrDate     BF_ORDERS cr_date                order_idx
	tpBindVar BFStatus     BF_ORDERS status                 order_idx
	tpBindVar BFType       BF_ORDERS type                   order_idx
	tpBindVar BFPrice      BF_ORDERS price                  order_idx
	tpBindVar BFAvgPrice   BF_ORDERS avg_price              order_idx
	tpBindVar BFSize       BF_ORDERS size                   order_idx
	tpBindVar BFSettled    BF_ORDERS settled                order_idx
	tpBindVar BFProfit     BF_ORDERS bf_profit              order_idx
	tpBindVar BFSizeMat    BF_ORDERS size_matched           order_idx
	tpBindVar BFBetId      BF_ORDERS bf_bet_id              order_idx
	tpBindVar BFAcctName   BF_ORDERS name              		order_idx
	tpBindVar BFAcctId     BF_ORDERS bf_acct_id             order_idx
	tpBindVar BFAcctStatus BF_ORDERS acct_status            order_idx

	asPlayFile -nocache bf_orders.html
}



#
# ----------------------------------------------------------------------------
# Display the order details. From this screen allow updates or cancellation of
# orders. 
# ----------------------------------------------------------------------------
#
proc go_bf_seln_order_upd {{bf_order_id -1}} {

	global DB
	global BF_ORDERS

	if {[info exists BF_ORDERS]} {
		unset BF_ORDERS
	}
	
	if {$bf_order_id == -1} { 
		set bf_order_id [reqGetArg BFOrderId]
	} 
		
	if {$bf_order_id == -1 || $bf_order_id == ""} { 
		tpSetVar NoBFOrder 1
		asPlayFile -nocache bf_order_upd.html
		return
	} 
	
	set sql [subst {
			select
				o.bf_order_id,
				o.cr_date,
				o.status,
				o.type,
				o.price,
				o.avg_price,
				o.size,
				o.size_matched,
				o.bf_bet_id,
				o.ev_oc_id,
				o.bf_profit,
				o.settled,
				s.desc
			from
				tBFOrder o,
				tBFAccount a,
				tEvOc s,
				tEv e
			where
				o.bf_acct_id = a.bf_acct_id
			and o.bf_order_id = ? 
			and o.ev_oc_id = s.ev_oc_id
			and s.ev_id = e.ev_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_order_id]
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

	tpSetVar     BFNumOrders  $nrows
	
	if {$nrows > 0} {
		tpBindString BFOrderId    $BF_ORDERS(0,bf_order_id)
		tpBindString BFCrDate     $BF_ORDERS(0,cr_date)
		tpBindString BFStatus     $BF_ORDERS(0,status)
		tpBindString BFSettled    $BF_ORDERS(0,settled)
		tpBindString BFProfit     $BF_ORDERS(0,bf_profit)
		tpBindString BFType       $BF_ORDERS(0,type)
		tpBindString BFPrice      $BF_ORDERS(0,price)
		tpBindString BFAvgPrice   $BF_ORDERS(0,avg_price)
		tpBindString BFSize       $BF_ORDERS(0,size)
		tpBindString BFSizeMat    $BF_ORDERS(0,size_matched)
		tpBindString BFBetId      $BF_ORDERS(0,bf_bet_id)		
	}

	asPlayFile -nocache bf_order_upd.html
}


#
# ----------------------------------------------------------------------------
# Wrapper for updating or cancelling of the order
# ----------------------------------------------------------------------------
#
proc do_bf_seln_order_upd {} {

	set act [reqGetArg SubmitName]

	if {$act == "BFUpdOrder"} {
		do_bf_order_replace
	} elseif {$act == "BFUpdOrderBasic"} { 
		do_ob_seln_order_upd
	} elseif {$act == "BFCanOrder"} {
		do_bf_order_can
    } elseif {$act == "BFOrdersList"} {
        # To display all the orders for that particular selection
	 	go_bf_seln_order_details
	}
}


#
# ----------------------------------------------------------------------------
# Replace existing BetFair order with a new order.
# 
# An update bet call can result in the following options:- 
#
# i)   Price Change :- cancellation of original bet, creation of new one
# ii)  Size Increase:- keep original bet, create new one
# iii) Size Decrease:- update original bet
#
# *** DEPRECATING THIS FUNCTIONALITY DUE TO PROBLEMS WITH HOW WE HANDLE TIMEOUTS
# If we consider the situation in which a timeout occurs, we are faced with a 
# number of possible scenarios. A new bet could be created, the current bet could
# be cancelled or the old bet could be updated which creates so many possible
# unknowns. For example, if a new bet is created in Betfair this fact wouldn’t 
# be recorded in OpenBet so an admin user would never be able to check on Betfair 
# and set the liabilities correctly. If we did create a dummy bet, we’d also have
# to give the admin the ability to change the size of an order WITHOUT this being
# reflected in Betfair so the liability & this process would be unwieldy. 
# *** USER SHOULD CANCEL OLD ORDER AND PLACE A NEW ONE
# ----------------------------------------------------------------------------
#
proc do_bf_order_replace {} {

	global DB
	global USERNAME
	global BF_PB

	#
	# orig_bf_acct_id stores the bf_acct_id which was used to place this order
	#
	set orig_bf_order_id [reqGetArg BFOrderId]
	set bf_bet_id        [reqGetArg BFBetId]
	set bf_price         [reqGetArg BFPrice]
	set bf_size          [reqGetArg BFSize]
	set bf_status        [reqGetArg BFStatus]
	set bf_price_orig    [reqGetArg BFPriceOrig]
	set bf_size_orig     [reqGetArg BFSizeOrig]
	set bf_size_match    [reqGetArg BFSizeMat]
	set ev_oc_id         [reqGetArg OcId]
	
	#
	# Check that we actually need to do this update. Also only allow
	# updating of size or price, not both as Betfair don't handle both being
	# changed.
	#

	set BF_LARGE [OT_CfgGet BF_LARGE_ORDER 1000]
	set BF_SMALL [OT_CfgGet BF_SMALL_ORDER 10]

	if {$bf_size > $BF_LARGE} {
		error "Order larger than maximum allowed ($BF_LARGE)"
		go_bf_seln_order_details
		return
	}

	if {($bf_size > $BF_SMALL) && (![op_allowed BFLargeOrder])} {
		error "You do not have permissions to update an Betfair order with a size larger than $bf_size"
		go_bf_seln_order_details
		return
	}

	if {$bf_size <= $BF_SMALL && !([op_allowed BFLargeOrder] || [op_allowed BFSmallOrder])} {
		error "You do not have permissions to update an Betfair order with a size larger than $bf_size"
		return
	}

	if {$bf_size == $bf_size_orig && $bf_price == $bf_price_orig} {
		OT_LogWrite 1 "No update required for order bf_bet_id=$bf_bet_id"
		err_bind "No update required for order bf_bet_id=$bf_bet_id"
		go_bf_seln_order_details
		return
	} elseif {$bf_size != $bf_size_orig && $bf_price != $bf_price_orig} {
		err_bind "Can only update price or stake, not both"
		go_bf_seln_order_details
		return
	}

	#
	# Load the order details
	#
	set is_ok [load_bf_order_details $orig_bf_order_id ORDER] 

	if {!$is_ok} { 
		error "Order Not Found"
		go_bf_seln_order_details
		return
	} 

	set bf_exch_id 		$ORDER(bf_exch_id) 
	set bf_acct_status 	$ORDER(bf_acct_status) 
	set orig_bf_acct_id $ORDER(bf_acct_id) 
	set order_type   	$ORDER(order_type) 
	set ev_class_id   	$ORDER(ev_class_id) 

	#
	# Get the current bf_acct_id
	#
	set bf_acct_id [ADMIN::BETFAIR_ACCT::get_active_bf_account $ev_class_id]

	if {$bf_acct_id == "" } {
		go_bf_seln_order_details
		return
	}
	
	#
	# Was it a price or size change?
	#
	set price_or_size [expr {$bf_size != $bf_size_orig ? "S" : "P"}]

	#
	# Work out the original and new liabilities remembering to deduct anything
	# that we know has matched
	#

	ob_log::write INFO {do_bf_order_replace - bf_bet_id=$bf_bet_id}
	ob_log::write INFO {do_bf_order_replace - price_or_size=$price_or_size}

	#
	# Update the order on BetFair
	#
	set service [BETFAIR::INT::get_service $bf_exch_id]

	if { [BETFAIR::SESSION::create_session "" $bf_acct_id] == -1 } {
		set msg "Error creating session"
		err_bind $msg
		ob::log::write ERROR {do_bf_order_replace - $msg}
		go_bf_seln_order_details
		return
	}
	
	ob_log::write INFO {BETFAIR UPDATE_BETS service=$service bf_bet_id=$bf_bet_id }
	ob_log::write INFO {BETFAIR UPDATE_BETS bf_price=$bf_price bf_price_orig=$bf_price_orig bf_size_orig=$bf_size_orig}

	after 10000

	if {[catch {
		BETFAIR::INT::update_bets $service $bf_bet_id $bf_price $bf_size $bf_price_orig $bf_size_orig
		set is_ok 1
	} msg]} {
		ob::log::write ERROR {do_bf_order_replace ERROR $msg}
		set is_ok 0
	}

	#
	# Handle results
	#
	if {[info exists BF_PB(num_orders_upd)] \
		&& $BF_PB(num_orders_upd) > 0 \
		&& $BF_PB(0,success) == "true" \
		&& $is_ok==1} {

		ob_log::write_array INFO BF_PB
		
		# This now uses string comparison which will be unaffected by large integer issues (see comment at top of file) 
		if {![string equal $BF_PB(0,new_bet_id) "0"]} {
			set bf_bet_id $BF_PB(0,new_bet_id)
		}

		#
		# If the new_bet_id is not 0 then we have a new order 
		# so lets replicate the old one and add the new_bet_id
		#
		if {![string equal $BF_PB(0,new_bet_id) "0"]} {

			ob::log::write INFO {New Order Created - store the new order details bf_bet_id=$bf_bet_id}

			set sql [subst {
				execute procedure pBFRepOrder(
						p_adminuser    = ?,
						p_bf_order_id  = ?,
						p_bf_bet_id    = ?,
						p_price        = ?,
						p_size         = ?,
						p_bf_acct_id   = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {set rs [inf_exec_stmt $stmt\
									$USERNAME\
									$orig_bf_order_id\
									$bf_bet_id\
									$BF_PB(0,new_price)\
									$BF_PB(0,new_size)\
									$bf_acct_id]} msg]} {
				inf_close_stmt $stmt
				err_bind $msg
				ob::log::write ERROR {do_bf_order_replace - $msg}
				go_bf_seln_order_details
				return
			}

			inf_close_stmt $stmt

			set new_bf_order_id [db_get_coln $rs 0 0]
			db_close $rs
			
			ob::log::write INFO {New bf_order_id=$new_bf_order_id}

			#
			# Move the new liabilities for the new order 
			#
			if {$order_type == "B"} {
				set liab_ok [BETFAIR::LIAB::add_back_order $new_bf_order_id $BF_PB(0,new_size) $BF_PB(0,new_price)]
			} else {
				set liab_ok [BETFAIR::LIAB::add_lay_order $new_bf_order_id $BF_PB(0,new_size) $BF_PB(0,new_price)]
			}
			
			if {!$liab_ok==1} { 		
				# log error but we've still got work to do 
				err_bind "Error updating liabilities for new order"
				ob::log::write ERROR {do_bf_order_replace - ERROR updating liabilities for new order}			
			} 
	
			#
			# Set the status as cancelled only if the remaining part was cancelled
			#			
			set bf_size_can $BF_PB(0,size_cancelled)

			ob::log::write INFO {Result code=OK_REMAINING_CANCELLED - Size Cancelled=$bf_size_can}

			if {$BF_PB(0,result_code) == "OK_REMAINING_CANCELLED" & $bf_size_can > 0} {

				set status "C"

				ob::log::write INFO {Attempt to cancel old order bf_order_id=$orig_bf_order_id}			

				inf_begin_tran $DB

				#
				# Update the db with the status and matched amount of the bet
				#
				set sql [subst {
					execute procedure pBFUpdOrderDetails(
							p_adminuser       = ?,
							p_order_id        = ?,
							p_status          = ?,
							p_size_matched	  = ?,
							p_prev_status     = ?,
							p_prev_matched    = ?,
							p_transactional   = ?
							)
				}]

				set stmt [inf_prep_sql $DB $sql]

				if {[catch {
					inf_exec_stmt $stmt\
						$USERNAME\
						$orig_bf_order_id\
						$status\
						$BF_PB(0,size_matched)\
						$bf_status\
						$bf_size_match\
						"N"
				} msg]} {
					inf_rollback_work $DB
					inf_close_stmt $stmt
					err_bind $msg
					ob::log::write ERROR {do_bf_order_replace ERROR cancelling order - $msg}
				} else { 

					inf_close_stmt $stmt
					
					#
					# Handle liabilities from an old cancelled order
					#
					set liab_ok 1

					if {$bf_size_can > 0} { 		
						if {$order_type == "B"} {
							set liab_ok [BETFAIR::LIAB::cancel_back_order $orig_bf_order_id $bf_size_can $BF_PB(0,size_matched) $bf_size_match]
						} else {
							set liab_ok [BETFAIR::LIAB::cancel_lay_order $orig_bf_order_id $bf_size_can]
						}				
					} 

					if {!$liab_ok==1} { 		
						# log error, rollback 
						inf_rollback_work $DB
						err_bind "Error cancelling liabilities for old order - Rolling back cancellation"
						ob::log::write ERROR {do_bf_order_replace - ERROR updating liabilities for old order}			
					} else { 
						inf_commit_tran $DB
					} 
				}
			}
			
		} else { 
	
			#
			# If we didn't create new order then just update the existing order
			#
			
			ob::log::write INFO {Update old order bf_order_id=$orig_bf_order_id size=$bf_size price=$bf_price}			

			inf_begin_tran $DB

			set sql [subst {
				update
					tBFOrder
				set
					size = ?,
					price = ?
				where
					bf_order_id = ?
			}]

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {inf_exec_stmt $stmt $bf_size $bf_price $orig_bf_order_id} msg]} {
				inf_close_stmt $stmt
				ob::log::write ERROR {do_bf_order_replace - ERROR $msg}
			}
		
			if {$price_or_size == "P"} {
				if {$order_type == "B"} {
					set liab_ok [BETFAIR::LIAB::change_price_back_order $orig_bf_order_id $bf_price $bf_price_orig]
				} else {
					set liab_ok [BETFAIR::LIAB::change_price_lay_order $orig_bf_order_id $bf_price $bf_price_orig]
				}							
			} else { 
				if {$order_type == "B"} {
					set liab_ok [BETFAIR::LIAB::change_size_back_order $orig_bf_order_id $bf_size $bf_size_orig]
				} else {
					set liab_ok [BETFAIR::LIAB::change_size_lay_order $orig_bf_order_id $bf_size $bf_size_orig]
				}										
			}
			
			if {!$liab_ok==1} { 						
				inf_rollback_work $DB
				err_bind "Error cancelling liabilities for old order updates"
				ob::log::write ERROR {do_bf_order_replace - ERROR updating liabilities for old order updates}			
			} else { 			
				inf_commit_tran $DB
			}
		} 	
				
	} else {	
		#
		# Failure/Timeout
		#
		set result_code ""
		set err_code "" 
		
		if {[info exists BF_PB(0,result_code)]} { 
			set result_code $BF_PB(0,result_code)
		} 
		
		if {[info exists BF_PB(0,err_code)]} { 
			set err_code $BF_PB(0,err_code)
		} 		
		
		if {$result_code == "" && $err_code == ""} { 
			set err_code " - TIMEOUT - please check order on Betfair" 
		} 
		
		err_bind "Could not update order: Error/Timeout $result_code $err_code "
	}

	go_bf_seln_order_details
}


#
# ----------------------------------------------------------------------------
#  Update the betfair order with a status / betfair ID. This happens if updating 
#  a pending order later on with details. If the order hasn't been placed 
#  cancel the liabs. Else we assume its an order status "U" and let the order 
#  daemon process any updates. 
# ----------------------------------------------------------------------------
#
proc do_ob_seln_order_upd {} {

	global DB

	set bf_order_id [reqGetArg BFOrderId]
	set bf_bet_id   [reqGetArg NewBFBetId]
	set status      [reqGetArg Status]
	set type        [reqGetArg BFOrderType] 

	if {$status == "U" && $bf_bet_id == ""} {
		err_bind "Cannot set order to placed without corresponding Betfair bet id"
		go_bf_seln_order_details
		return
	}

	set sql [subst {
		update
			tBFOrder
		set
			bf_bet_id = ?,
			status    = ?
		where
			bf_order_id = ?
		and status in ('B','N')
	}]

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {		
		set rs   [inf_exec_stmt $stmt $bf_bet_id $status $bf_order_id]	
	} msg]} {
		inf_rollback_tran $DB
		catch {db_close $rs} 
		inf_close_stmt $stmt		
		err_bind $msg
		ob::log::write ERROR {do_ob_seln_order_upd:ERROR $msg}
		go_bf_seln_order_details
		return
	}

	inf_close_stmt $stmt
	db_close $rs
	
	if {$status == "X"} { 
		# If the order didn't get placed, cancel the liabs
		if {$type == "B"} {
			set liab_ok [BETFAIR::LIAB::cancel_back_order $bf_order_id]
		} elseif {$type == "L"} {
			set liab_ok [BETFAIR::LIAB::cancel_lay_order $bf_order_id]
		} else {
			set liab_ok 0 
		} 

		if {!$liab_ok==1} { 
			inf_rollback_tran $DB
			err_bind "Liability update error"
			ob_log::write ERROR {do_ob_seln_order_upd ERROR Liability Error}
			go_bf_seln_order_details
			return
		}
	} 
		
	inf_commit_tran $DB	

	go_bf_seln_order_details
}

#
# Load the current order details into an array 
#
proc load_bf_order_details {bf_ob_id ARRAY {type "order"}} { 

	global DB 
	upvar $ARRAY ORDER_DETAILS

	array set ORDER_DETAILS [list] 
	
	if {$type == "order"} { 	
	
		set sql [subst {
			select 
				o.ev_oc_id,
				bfo.bf_ev_oc_id as bf_id,								
				bfo.bf_exch_id,
				bfo.bf_asian_id,
				a.bf_acct_id,
				a.status as bf_acct_status,			
				e.ev_class_id,
				bfo.bf_ev_mkt_id,
				bfo.type as order_type,
				bfo.size_matched,
				bfo.status,
				bfo.bf_bet_id
			from 
				tevoc o,
				tev e,
				tbforder bfo,
				tbfaccount a
			where 
				bfo.bf_order_id = ? 				
			and o.ev_oc_id = bfo.ev_oc_id			
			and bfo.bf_acct_id = a.bf_acct_id
			and o.ev_id = e.ev_id
		}]
		
	} else { 
	
		set sql [subst {
				select 
					o.ev_oc_id,
					bfo.bf_ev_oc_id as bf_id,			
					bfo.bf_exch_id,
					bfo.bf_asian_id,
					a.bf_acct_id,
					a.status as bf_acct_status,			
					e.ev_class_id,
					bfo.bf_ev_mkt_id,
					'B' as order_type,
					bfo.size_matched,
					bfo.status,
					bfo.bf_bet_id
				from 
					tevoc o,
					tev e,
					tbfpassbet bfo,
					tbfaccount a
				where 
				    bfo.bf_pass_bet_id = ? 
				and o.ev_oc_id = bfo.ev_oc_id				
				and bfo.bf_acct_id = a.bf_acct_id
				and o.ev_id = e.ev_id
		}]
		
	} 

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bf_ob_id]
	inf_close_stmt $stmt
	
	set nrows [db_get_nrows $rs] 
	
	if {$nrows > 0} { 
		set ORDER_DETAILS(ev_oc_id) 		[db_get_col $rs 0 ev_oc_id]
		set ORDER_DETAILS(bf_id) 			[db_get_col $rs 0 bf_id]
		set ORDER_DETAILS(bf_ev_mkt_id) 	[db_get_col $rs 0 bf_ev_mkt_id]
		set ORDER_DETAILS(bf_exch_id) 		[db_get_col $rs 0 bf_exch_id]
		set ORDER_DETAILS(bf_acct_id) 		[db_get_col $rs 0 bf_acct_id]
		set ORDER_DETAILS(bf_acct_status) 	[db_get_col $rs 0 bf_acct_status]		
		set ORDER_DETAILS(ev_class_id) 		[db_get_col $rs 0 ev_class_id]		
		set ORDER_DETAILS(status)  			[db_get_col $rs 0 status]		
		set ORDER_DETAILS(size_matched) 	[db_get_col $rs 0 size_matched]		
		set ORDER_DETAILS(bf_bet_id)	 	[db_get_col $rs 0 bf_bet_id]		
		set ORDER_DETAILS(order_type)	 	[db_get_col $rs 0 order_type]		
	} 
	
	db_close $rs
	
	return $nrows
} 


#
# ----------------------------------------------------------------------------
# Cancel a BetFair order. Unwind any liabilities
#
# type - order/passbet
# ----------------------------------------------------------------------------
#
proc do_bf_order_can { {type "order"} } {

	global DB
	global USERNAME
	global BF_PB_CAN

	if {$type == "order"} { 
		set ob_id_desc "bf_order_id"
		set bf_ob_id      [reqGetArg BFOrderId]
	} else { 
		set ob_id_desc "bf_pass_bet_id"
		set bf_ob_id      [reqGetArg BFPassBetId]
	} 

	ob_log::write INFO {CANCELLING ORDER $ob_id_desc=$bf_ob_id} 

	if {![op_allowed BFCancelOrder]} {
		error "You do not have permissions to cancel a Betfair order."
		go_bf_seln_order_details
		return
	}

	#
	# Loaded the order details
	#
	set is_ok [load_bf_order_details $bf_ob_id ORDER $type] 

	if {!$is_ok} { 
		error "Order Not Found"
		if {$type=="order"} {go_bf_seln_order_details} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet} 
		return
	} 

	set bf_exch_id 			$ORDER(bf_exch_id) 
	set bf_acct_status 		$ORDER(bf_acct_status) 
	set bf_acct_id 			$ORDER(bf_acct_id) 
	set bf_order_type   	$ORDER(order_type) 
	set bf_prev_status  	$ORDER(status) 
	set bf_prev_smatched 	$ORDER(size_matched) 
	set bf_bet_id			$ORDER(bf_bet_id) 
	
	if {$bf_acct_status == "S"} {
		err_bind "Cannot cancel order - Betfair account used to place this order is Suspended."
		if {$type=="order"} {go_bf_seln_order_details} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet} 
		return
	}

	if {$bf_prev_status != "U" && $bf_prev_status != "P"} { 
		err_bind "Cannot cancel order as status $bf_prev_status."
		if {$type=="order"} {go_bf_seln_order_details} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet} 
		return
	} 

	ob_log::write_array INFO ORDER

	#
	# Update the order on BetFair
	#
	set service [BETFAIR::INT::get_service $bf_exch_id]

	if { [BETFAIR::SESSION::create_session "" $bf_acct_id] == -1 } {
		set msg "Error creating session"
		err_bind $msg
		ob::log::write ERROR {db_bf_order_can: $msg}
		if {$type=="order"} {go_bf_seln_order_upd} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet}
		return
	}

	ob_log::write INFO {CANCELLING ORDER ON BETFAIR $ob_id_desc=$bf_ob_id} 

	BETFAIR::INT::cancel_bets $service 1 "M,$bf_ob_id,$bf_bet_id" ""

	if {[info exists BF_PB_CAN($bf_bet_id,num_orders_can)] &&
		$BF_PB_CAN($bf_bet_id,num_orders_can) &&
		$BF_PB_CAN($bf_bet_id,success) == "true"} {

		ob_log::write INFO {ORDER CANCELLED OK - Updating OpenBet} 

		#
		# Update the db with the status and matched amount of the bet
		# * note that the update won't happen if the bet has been updated
		# in openbet in the interim period (e.g. increased matched amount in order handler) * 
		#
		
		if {$type == "order"} { 		
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
		} else { 				
			set sql [subst {
				execute procedure pBFUpdPassBet(
						p_adminuser    = ?,
						p_bf_pass_bet_id = ?,
						p_status       = ?,
						p_size_matched = ?,
						p_prev_status  = ?,
						p_prev_matched = ?
				)
			}]		
		} 

		set stmt [inf_prep_sql $DB $sql]

		inf_begin_tran $DB

		if {[catch {		
			if {$type == "order"} { 
				inf_exec_stmt $stmt\
						  $USERNAME\
						  $bf_ob_id\
						  "C"\
						  $BF_PB_CAN($bf_bet_id,size_matched)\
						  $bf_prev_status\
						  $bf_prev_smatched\
						  N
			} else { 
				inf_exec_stmt $stmt\
						  $USERNAME\
						  $bf_ob_id\
						  "C"\
						  $BF_PB_CAN($bf_bet_id,size_matched)\
						  $bf_prev_status\
						  $bf_prev_smatched
			} 						  								  
		} msg]} {
			inf_close_stmt $stmt
			inf_rollback_tran $DB
			err_bind $msg
			ob::log::write ERROR {db_bf_order_can: $msg}
			if {$type=="order"} {go_bf_seln_order_upd} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet}
			return
		}

		inf_close_stmt $stmt

		#
		# unwind the liabs 
		#			
		set liab_ok 1
		
		if {$bf_order_type == "L"} {
			set liab_ok [BETFAIR::LIAB::cancel_lay_order $bf_ob_id $BF_PB_CAN($bf_bet_id,size_cancelled)]
		} elseif {$bf_order_type == "B" && ($bf_prev_status == "P" || $bf_prev_status == "U")} {
			if {$type == "order"} {
				set liab_ok [BETFAIR::LIAB::cancel_back_order $bf_ob_id $BF_PB_CAN($bf_bet_id,size_cancelled) $BF_PB_CAN($bf_bet_id,size_matched) $bf_prev_smatched]
			} else { 
				set liab_ok [BETFAIR::LIAB::cancel_passbet $bf_ob_id $BF_PB_CAN($bf_bet_id,size_cancelled) $BF_PB_CAN($bf_bet_id,size_matched) $bf_prev_smatched]
			} 
		}

		if {!$liab_ok==1} {
			inf_rollback_tran $DB
			err_bind "Liability update error"
			ob_log::write ERROR {do_bf_order_can ERROR Liability Error}
			if {$type=="order"} {go_bf_seln_order_upd} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet}
			return
		}
		
		inf_commit_tran $DB

	} else {
		if {[info exists BF_PB_CAN($bf_bet_id,result_code)]} { 
			set result "Error attempting to cancel order: $BF_PB_CAN($bf_bet_id,result_code)"
		} else { 
			set result "Unknown Error/Timeout occurred when attempting to cancel order"
		} 
		err_bind "$result"
		if {$type=="order"} {go_bf_seln_order_upd} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet}
		return
	}

	if {$type=="order"} {go_bf_seln_order_details} else {ADMIN::BETFAIR_PASSBET::go_bf_passbet}	

	catch {unset BF_PB_CAN}
}



#
# ----------------------------------------------------------------------------
# Go to orders search Criteria page
# ----------------------------------------------------------------------------
#
proc go_search_orders args {

	set act [reqGetArg SubmitName]

	if {$act == "Refresh"} {
		do_search_orders
	} else {
		asPlayFile -nocache bf_orders_query.html
	}
}


#
# ----------------------------------------------------------------------------
# List all the orders that match the criteria
# ----------------------------------------------------------------------------
#
proc do_search_orders args {

	global DB
	global BF_ORDERS

	set order_id		[reqGetArg OrderId]
	set bf_bet_id		[reqGetArg BFBetId]
	set status			[reqGetArg Status]
	set placed_from 	[string trim [reqGetArg PlacedDate1]]
	set placed_to	 	[string trim [reqGetArg PlacedDate2]]
	set settled_from 	[string trim [reqGetArg SettledDate1]]
	set settled_to	 	[string trim [reqGetArg SettledDate2]]
	set price_from 		[string trim [reqGetArg Price1]]
	set price_to	 	[string trim [reqGetArg Price2]]
	set avg_price_from  [string trim [reqGetArg AvgPriceMatch1]]
	set avg_price_to    [string trim [reqGetArg AvgPriceMatch2]]
	set size_from 		[string trim [reqGetArg Size1]]
	set size_to 		[string trim [reqGetArg Size2]]
	set size_match_from [string trim [reqGetArg SizeMatch1]]
	set size_match_to   [string trim [reqGetArg SizeMatch2]]
	set order_type		[reqGetArg OrderType]
	set is_settled		[reqGetArg IsSettled]
	set username		[reqGetArg Username]
	set period 			[reqGetArg OrderPlacedFrom]
	set settled_period  [reqGetArg OrderSettledAt]

	tpBindString OrderId 	    $order_id
	tpBindString BFBetId 	    $bf_bet_id
	tpBindString Status 	    $status
	tpBindString PlacedDate1    $placed_from
	tpBindString PlacedDate2    $placed_to
	tpBindString SettledDate1   $settled_from
	tpBindString SettledDate2   $settled_to
	tpBindString Price1	    	$price_from
	tpBindString Price2 	    $price_to
	tpBindString AvgPriceMatch1 $avg_price_from
	tpBindString AvgPriceMatch2 $avg_price_to
	tpBindString Size1 	    	$size_from
	tpBindString Size2 	    	$size_to
	tpBindString SizeMatch1     $size_match_from
	tpBindString SizeMatch2     $size_match_to
	tpBindString OrderType      $order_type
	tpBindString Username 	    $username
	tpBindString OrderPlacedFrom $period
	tpBindString OrderSettledAt $settled_period	
	tpBindString IsSettled      $is_settled

	set where [list]
	set from  [list]
	set order_by "o.bf_order_id"

	if {[string length $order_id] > 0} {

		lappend where "o.bf_order_id = $order_id"

	} elseif {[string length $bf_bet_id] > 0} {

		lappend where "o.bf_bet_id = $bf_bet_id"

	} else {

		if {[string length $status] > 0 } {
			lappend where "o.status = '${status}'"
		}

		if {[string length $order_type] > 0} {
			lappend where "o.type = '${order_type}'"
		}

		if {[string length $is_settled] > 0} {
			lappend where "o.settled = '${is_settled}'"
		}

		if {([string length $placed_from] > 0) || ([string length $placed_to] > 0)} {
				lappend where [mk_between_clause o.cr_date date $placed_from $placed_to]
		} else {

			#
			# Orders date in fixed periods
			#
			if {[string length $period] > 0 && $period > 0} {

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
					lappend where [mk_between_clause o.cr_date date $lo $hi]
				}
	        }
		}

		if {([string length $settled_from] > 0) || ([string length $settled_to] > 0)} {
			lappend where [mk_between_clause o.settled_at date $settled_from $settled_to]
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
					lappend where [mk_between_clause o.settled_at date $lo $hi]
				}
	        }
		}

		if {([string length $price_from] > 0) || ([string length $price_to] > 0)} {
			lappend where [mk_between_clause o.price number $price_from $price_to]
		}

		if {([string length $avg_price_from] > 0) || ([string length $avg_price_to] > 0)} {
			lappend where [mk_between_clause o.avg_price number $avg_price_from $avg_price_to]
		}

		if {([string length $size_from] > 0) || ([string length $size_to] > 0)} {
			lappend where [mk_between_clause o.size number $size_from $size_to]
		}

		if {([string length $size_match_from] > 0) || ([string length $size_match_to] > 0)} {
        	lappend where [mk_between_clause o.size_matched number $size_match_from $size_match_to]
		}

		if {[string length $username] > 0} {
			if {[reqGetArg ExactName] == "Y"} {
				set op =
			} else {
				set op like
				set username "%$username%"
			}
			if {[reqGetArg UpperName] == "Y"} {
				lappend where "upper(au.username) ${op} '[string toupper ${username}]'"
			} else {
				lappend where "au.username ${op} '${username}'"
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
			o.bf_order_id,
			o.ev_oc_id,
			o.bf_bet_id,
			o.status,
			o.source,
			o.cr_date,
			o.user_id,
			o.bf_acct_id,
			o.type,
			o.size,
			o.size_matched,
			o.price,
			o.avg_price,
			o.bet_id,
			o.settled_at,
			o.bf_profit,
			oc.desc as seln,
			m.ev_mkt_id,
			g.name as mkt,
			e.ev_id,
			e.desc as event,
			cl.ev_class_id,
			cl.name as class,
			t.ev_type_id,
			t.name	as evtype,
			a.status as acctstatus,
			au.username,
			b.receipt
		from
			tBFOrder o,			
			tEvOc oc,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvClass cl,
			tEvType t,
			tBFAccount a,
			tAdminUser au,
			outer tBet b
			$from
		where			
			o.ev_oc_id = oc.ev_oc_id and
			oc.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			oc.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id  and
			e.ev_class_id = cl.ev_class_id and
			a.bf_acct_id = o.bf_acct_id and			
			au.user_id = o.user_id and 
			o.bet_id = b.bet_id 
			$where
		order by
			$order_by

	}]

	ob::log::write DEBUG "SEARCH SQL: $sql"

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows  [db_get_nrows $res]

	if {$nrows == 0} {
		tpBindString NoOrders  "No Orders found with this criteria "
		db_close $res
        go_search_orders
		return
    }

	if {[info exists BF_ORDERS]} {
		unset BF_ORDERS
	}

	for {set r 0} {$r < $nrows} {incr r} {
		set BF_ORDERS($r,bf_order_id)	[db_get_col $res $r bf_order_id]
		set BF_ORDERS($r,ev_oc_id)		[db_get_col $res $r ev_oc_id]
		set BF_ORDERS($r,seln)			[db_get_col $res $r seln]
		set BF_ORDERS($r,ev_mkt_id)     [db_get_col $res $r ev_mkt_id]
		set BF_ORDERS($r,mkt)   		[db_get_col $res $r mkt]
		set BF_ORDERS($r,ev_class_id)   [db_get_col $res $r ev_class_id]
		set BF_ORDERS($r,class)      	[db_get_col $res $r class]
		set BF_ORDERS($r,ev_id)    		[db_get_col $res $r ev_id]
		set BF_ORDERS($r,event)      	[db_get_col $res $r event]
		set BF_ORDERS($r,ev_type_id)    [db_get_col $res $r ev_type_id]
		set BF_ORDERS($r,evtype)        [db_get_col $res $r evtype]
		set BF_ORDERS($r,status)		[db_get_col $res $r status]
		set BF_ORDERS($r,source)		[db_get_col $res $r source]
		set BF_ORDERS($r,type)			[db_get_col $res $r type]
		set BF_ORDERS($r,bf_bet_id)		[db_get_col $res $r bf_bet_id]
		set BF_ORDERS($r,cr_date)		[db_get_col $res $r cr_date]
		set BF_ORDERS($r,size)			[db_get_col $res $r size]
		set BF_ORDERS($r,size_matched)	[db_get_col $res $r size_matched]
		set BF_ORDERS($r,price)			[db_get_col $res $r price]
		set BF_ORDERS($r,avg_price)		[db_get_col $res $r avg_price]
		set BF_ORDERS($r,settled_at)	[db_get_col $res $r settled_at]
		set BF_ORDERS($r,bf_acct_id) 	[db_get_col $res $r bf_acct_id]
		set BF_ORDERS($r,acctstatus)	[db_get_col $res $r acctstatus]
		set BF_ORDERS($r,username)		[db_get_col $res $r username]
		set BF_ORDERS($r,openbet_id)	[db_get_col $res $r bet_id]
		set BF_ORDERS($r,receipt)		[db_get_col $res $r receipt]
		set BF_ORDERS($r,bf_profit)		[db_get_col $res $r bf_profit]		
	}

	db_close $res

	tpSetVar NumOrder $nrows

	tpBindVar BFOrderId BF_ORDERS bf_order_id 	order_idx
	tpBindVar EvOcId 	BF_ORDERS ev_oc_id 		order_idx
	tpBindVar OCDesc    BF_ORDERS seln			order_idx
	tpBindVar Mkt		BF_ORDERS mkt			order_idx
	tpBindVar MktId 	BF_ORDERS ev_mkt_id		order_idx
	tpBindVar Event		BF_ORDERS event			order_idx
	tpBindVar EvId		BF_ORDERS ev_id			order_idx
	tpBindVar TypeName	BF_ORDERS evtype		order_idx
	tpBindVar EvTypeId	BF_ORDERS ev_type_id	order_idx
	tpBindVar Class		BF_ORDERS class			order_idx
	tpBindVar EvClassId	BF_ORDERS ev_class_id	order_idx
	tpBindVar BFStatus	BF_ORDERS status 		order_idx
	tpBindVar Source	BF_ORDERS source 		order_idx
	tpBindVar Type		BF_ORDERS type 			order_idx
	tpBindVar BF_Bet_Id BF_ORDERS bf_bet_id		order_idx	
	tpBindVar CrDate	BF_ORDERS cr_date		order_idx
	tpBindVar Size		BF_ORDERS size			order_idx
	tpBindVar Receipt	BF_ORDERS receipt		order_idx
	tpBindVar SettledAt	BF_ORDERS settled_at	order_idx
	tpBindVar BF_Profit	BF_ORDERS bf_profit		order_idx
	tpBindVar Openbet_Bet_Id BF_ORDERS openbet_id   order_idx
	tpBindVar SizeMatched	BF_ORDERS size_matched	order_idx
	tpBindVar Price			BF_ORDERS price			order_idx
	tpBindVar AvgPrice		BF_ORDERS avg_price		order_idx
	tpBindVar BF_Acct_Id 	BF_ORDERS bf_acct_id 	order_idx
	tpBindVar BFAcctStatus  BF_ORDERS acctstatus 	order_idx
	
	tpBindVar UserName	BF_ORDERS username	order_idx
	
	
	asPlayFile -nocache bf_search_orders.html
}

}
