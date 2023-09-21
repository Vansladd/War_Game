# ==============================================================
# $Id: bet_transfer.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BET_TRANSFER {

asSetAct ADMIN::BET_TRANSFER::DoBetTransferSearch [namespace code do_bet_transfer_search]

}

#
# ----------------------------------------------------------------------------
# Generate bet transfer search page
# ----------------------------------------------------------------------------
#
proc ADMIN::BET_TRANSFER::go_bet_transfer_search args {

	global DB

	set CustId [reqGetArg CustId]

	set sql {
		select
			c.username,
			c.acct_no,
			a.acct_id,
			y.ccy_name
		from
			tCustomer c,
			tAcct a,
			tccy y
		where
			c.cust_id = ? and
			c.cust_id = a.cust_id and
			a.ccy_code = y.ccy_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $CustId]

	inf_close_stmt $stmt

	tpBindString CustId     $CustId
	tpBindString Username   [db_get_col $res 0 username]
	tpBindString AcctNo     [db_get_col $res 0 acct_no]
	tpBindString AcctId     [db_get_col $res 0 acct_id]
	tpBindString Currency   [db_get_col $res 0 ccy_name]

	db_close $res

	asPlayFile -nocache bet_transfer_search.html
}

#
# ----------------------------------------------------------------------------
# Handle request from the bet transfer search page
# ----------------------------------------------------------------------------
#
proc ADMIN::BET_TRANSFER::do_bet_transfer_search args {

	global DB BET
	
	tpBindString CustId      [set cust_id  [reqGetArg CustId]]
	tpBindString Username    [set username [reqGetArg Username]]
	tpBindString AcctNo      [set acct_no  [reqGetArg AcctNo]]
	tpBindString AcctId      [set acct_id  [reqGetArg AcctId]]
	tpBindString Currency    [reqGetArg Currency]
	
	set submit_action [reqGetArg SubmitName]
	
	if {$submit_action == "NewSearch"} {
		go_bet_transfer_search
		return
	}
	if {$submit_action == "Customer" || $submit_action == "Back"} {
		ADMIN::CUST::go_cust cust_id $cust_id
		return
	}
	if {$submit_action == "TransferBets"} {
		# All shop fielding account usernames begin with a space
		set transfer_username " [string trimleft [reqGetArg TransferUsername]]"
		
		if {[catch {
			set to_acct_id [_get_shop_fielding_acct $transfer_username]
		} msg]} {
			err_bind $msg
		} else {
			_transfer_bets $acct_id $to_acct_id
		}
	}

	_bind_bet_list $acct_id
	
	asPlayFile -nocache bet_transfer_list.html
}


#
# ----------------------------------------------------------------------------
# Create appropriate bindings for results of bet transfer search
# ----------------------------------------------------------------------------
#
proc _bind_bet_list {acct_id} {

	global DB BET
	#
	# Bet date fields:
	#
	set bd1 [reqGetArg BetDate1]
	set bd2 [reqGetArg BetDate2]
	
	set where_dates ""

	if {([string length $bd1] > 0) || ([string length $bd2] > 0)} {
		set where_dates "and [mk_between_clause b.cr_date date $bd1 $bd2]"
	}
	
	set sql [subst {
		select
			b.receipt,
			b.cr_date,
			b.stake,
			b.bet_type,
			e.desc ev_name,
			m.name mkt_name,
			s.desc seln_name,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			o.bet_id,
			o.leg_no,
			o.price_type,
			NVL(o.no_combi,'') no_combi,
			o.banker,
			""||o.o_num o_num,
			""||o.o_den o_den
		from
			tBet b,
			tOBet o,
			tEvOc s,
			tEvMkt m,
			tEv e
		where
			b.bet_id = o.bet_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			s.ev_id = e.ev_id and
			b.status <> 'X' and
			b.acct_id = $acct_id
			$where_dates
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	set cur_id 0
	set bet -1

	array set BET [list]

	for {set r 0} {$r < $n_rows} {incr r} {

		set bet_id [db_get_col $res $r bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set leg 0
			incr bet
			set BET($bet,num_legs) 0
		}
		
		incr BET($bet,num_legs)

		if {$leg == 0} {
			set bet_type [db_get_col $res $r bet_type]

			if {$bet_type == "MAN"} {
				set man_bet 1
				tpSetVar ManBet 1
			} else {
				set man_bet 0
			}
			
			set BET($bet,bet_id)    [db_get_col $res $r bet_id]
			set BET($bet,receipt)   [db_get_col $res $r receipt]
			set BET($bet,bet_time)  [db_get_col $res $r cr_date]
			set BET($bet,manual)    $man_bet
			set BET($bet,bet_type)  $bet_type
			set BET($bet,stake)     [db_get_col $res $r stake]
		}

		set price_type [db_get_col $res $r price_type]

		if {[string first $price_type "LSBN12"] >= 0} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			if {$o_num == "" || $o_den == ""} {
				set p_str [get_price_type_desc $price_type]
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str [get_price_type_desc $price_type]
				}
			}
		} else {
			if {$man_bet} {
				set p_str "MAN"
			} else {
				set p_str "DIV"
			}
		}

		set BET($bet,$leg,price)     $p_str
		set BET($bet,$leg,leg_no)    [db_get_col $res $r leg_no]

		#how are the legs combined
		if {[catch {
			set no_combi  [db_get_col $res $r no_combi]
			set banker    [db_get_col $res $r banker]
		} msg]} {
			set combi "All"
			set banker "N"
			ob_log::write WARN   {The results set passed to bet_transfer.tcl:bind_sports_bet_list does not contain no_combi or banker fields}
			ob_log::write WARN   "Using defaults - combi=$combi; banker=$banker"
		} else {
			if {$banker == "Y"} {
				set combi "Banker"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != "" && $no_combi % 2 == 0} {
				set combi "Even"
				tpSetVar ShowCombiKey 1
			} elseif {$no_combi != ""} {
				set combi "Odd"
				tpSetVar ShowCombiKey 1
			} else {
				set combi "All"
			}
		}
		set BET($bet,$leg,combi)   $combi
		set BET($bet,$leg,man_bet) $man_bet
		
		set ev_name [string trim [db_get_col $res $r ev_name]]

		if {$man_bet == 0} {
			set BET($bet,$leg,event)     $ev_name
			set BET($bet,$leg,mkt)       [db_get_col $res $r mkt_name]
			set BET($bet,$leg,seln)      [db_get_col $res $r seln_name]
			set BET($bet,$leg,ev_id)     [db_get_col $res $r ev_id]
			set BET($bet,$leg,ev_mkt_id) [db_get_col $res $r ev_mkt_id]
			set BET($bet,$leg,ev_oc_id)  [db_get_col $res $r ev_oc_id]
		} else {
			set BET($bet,$leg,event)     [string range $ev_name 0 25]
			set BET($bet,$leg,mkt)       [string range $ev_name 26 51]
			set BET($bet,$leg,seln)      [string range $ev_name 52 77]
		}
		
		incr leg
	}
	
	tpSetVar NumBets [expr {$bet+1}]
	tpBindVar BetId       BET bet_id    bet_idx
	tpBindVar BetReceipt  BET receipt   bet_idx
	tpBindVar BetTime     BET bet_time  bet_idx
	tpBindVar Manual      BET manual    bet_idx
	tpBindVar BetType     BET bet_type  bet_idx
	tpBindVar BetStake    BET stake     bet_idx
	tpBindVar BetLegNo    BET leg_no    bet_idx seln_idx
	tpBindVar BetCombi    BET combi     bet_idx seln_idx
	tpBindVar EvDesc      BET event     bet_idx seln_idx
	tpBindVar MktDesc     BET mkt       bet_idx seln_idx
	tpBindVar SelnDesc    BET seln      bet_idx seln_idx
	tpBindVar Price       BET price     bet_idx seln_idx
	tpBindVar EvId        BET ev_id     bet_idx seln_idx
	tpBindVar EvMktId     BET ev_mkt_id bet_idx seln_idx
	tpBindVar EvOcId      BET ev_oc_id  bet_idx seln_idx
	
	tpBindString BetDate1 [reqGetArg BetDate1]
	tpBindString BetDate2 [reqGetArg BetDate2]
	
	db_close $res
}

#
# ----------------------------------------------------------------------------
# Loops through each bet calling the the transfer proc and handling errors
# ----------------------------------------------------------------------------
#
proc _transfer_bets {from_acct_id to_acct_id} {
	
	set user_id  [reqGetArg UserId]
	set num_bets [reqGetArg NumBets]
	
	set attempt_list [list]
	set error_list   [list]
	
	for {set i 0} {$i < $num_bets} {incr i} {
		set bet_id [reqGetArg T_$i]
		
		if {$bet_id != ""} {
			lappend attempt_list $bet_id
			
			if {[catch {
				_transfer_bet $bet_id $from_acct_id $to_acct_id $user_id
			} msg]} {
				lappend error_list $bet_id
				ob_log::write ERROR $msg
				ob_log::write ERROR {Could not transfer bet $bet_id from acct $from_acct_id to $to_acct_id}
			}
		}
	}
	
	if {[llength $error_list] == 0} {
		msg_bind "Bets transferred"
	} elseif {[llength $error_list] == [llength $attempt_list]} {
		err_bind "Transfer of bets failed"
	} else {
		set bet_ids [join $error_list ", "]
		msg_bind "Some bets transferred"
		err_bind "Transfer of bets with following ids failed: $bet_ids"
	}
}

#
# ----------------------------------------------------------------------------
# Transfer a bet from one shop fielding account to another
# ----------------------------------------------------------------------------
#
proc _transfer_bet {bet_id from_acct_id to_acct_id user_id} {

	global DB
	
	set sql {
		execute procedure pTransferBet(
			p_bet_id = ?,
			p_from_acct_id = ?,
			p_to_acct_id = ?,
			p_user_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_exec_stmt $stmt\
			$bet_id\
			$from_acct_id\
			$to_acct_id\
			$user_id
			
	inf_close_stmt $stmt
}

#
# ----------------------------------------------------------------------------
# Return the acct_id of a shop fielding account
# ----------------------------------------------------------------------------
#
proc _get_shop_fielding_acct {username} {

	global DB
	
	set sql [subst {
		select
			a.acct_id
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id = a.cust_id
		and
			c.username = '$username'
		and
			a.owner = 'F'
		and
			a.owner_type in ('STR','VAR','OCC','REG','LOG')
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]
	
	if {$n_rows == 1} {
		set acct_id [db_get_col $res 0 acct_id]
	} else {
		db_close $res
		error "Invalid username entered, the account must be a fielding account linked to a shop"
	}
	
	db_close $res
	
	return $acct_id
}
