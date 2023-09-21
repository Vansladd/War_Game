# $Id: XGAME.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# XGame/Lotteries history handler.
# Provides a listing for all XGAME j_op_ref_keys or display the details for one
# particular subscription and bet[s].
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_XGAME ?4.5?
#

package provide hist_XGAME 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable XGAME_INIT

	# initialise flag
	set XGAME_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_XGAME_init args {

	variable XGAME_INIT

	# already initialised?
	if {$XGAME_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {XGAME_HIST: init}

	# prepare queries
	_XGAME_prepare_qrys

	# successfully initialised
	set XGAME_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_XGAME_prepare_qrys args {

	# get all XGAME subscription[s]
	# - dont bother with the bets as the subscriptions are linked to bets and
	#   will only confuse the listing
	ob_db::store_qry ob_hist::XGAME_get {
		select first 21
		    cr_date,
		    jrnl_id,
		    desc,
		    j_op_ref_key,
		    j_op_ref_id,
		    j_op_type,
		    amount,
		    user_id,
		    balance
		from
		    tJrnl
		where
		    cr_date >= ?
		and cr_date <= ?
		and acct_id = ?
		and j_op_type = 'BSTK'
		and j_op_ref_key = 'XGAM'
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get all XGAME journal entries after a specific entry and before a date
	# - dont bother with the bets as the subscriptions are linked to bets and
	#   will only confuse the listing
	ob_db::store_qry ob_hist::XGAME_get_w_jrnl_id {
		select first 21
		    cr_date,
		    jrnl_id,
		    desc,
		    j_op_ref_key,
		    j_op_ref_id,
		    j_op_type,
		    amount,
		    user_id,
		    balance
		from
		    tJrnl
		where
		    cr_date >= ?
		and jrnl_id <= ?
		and acct_id = ?
		and j_op_type = 'BSTK'
		and j_op_ref_key = 'XGAM'
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get a XGAME subscription (and associated bets)
	ob_db::store_qry ob_hist::XGAME_get_bstk {
		select
		    'sub' as type,
		    xgame_sub_id as id,
		    d.name as game_name,
		    s.cr_date,
		    s.stake_per_bet as stake,
		    s.draws,
		    s.picks,
		    s.num_subs,
		    s.free_subs,
		    s.status,
		    s.bet_type,
		    d.sort,
		    g.comp_no,
		    0 as refund,
		    0 as winnings,
		    '' as paymethod,
		    '' as cheque_payout_msg,
		    s.num_unsettled,
		    '-' as settled,
		    '' as results
		from
		    tXGameDef d,
		    tXGameSub s,
		    tXGame g
		where
		    s.xgame_sub_id = ?
		and s.acct_id = ?
		and g.xgame_id = s.xgame_id
		and d.sort = g.sort

		union

		select
		    'bet' as type,
		    b.xgame_bet_id as id,
		    d.name as game_name,
		    b.cr_date,
		    b.stake_per_line as stake,
		    '' as draws,
		    b.picks,
		    s.num_subs,
		    s.free_subs,
		    b.status,
		    b.bet_type,
		    d.sort,
		    g.comp_no,
		    b.refund,
		    b.winnings,
		    b.paymethod,
		    d.cheque_payout_msg,
		    s.num_unsettled,
		    b.settled,
		    g.results
		from
		    tXGameBet b,
		    tXGameSub s,
		    tXGame g,
		    tXGameDef d
		where
		    s.xgame_sub_id = ?
		and b.xgame_sub_id = s.xgame_sub_id
		and s.acct_id = ?
		and g.xgame_id = b.xgame_id
		and d.sort = g.sort
		order by
		    4 desc
	}

	# get a XGAME bet (and associated subscription)
	ob_db::store_qry ob_hist::XGAME_get_bstl {
		select
		    'sub' as type,
		    s.xgame_sub_id as id,
		    d.name as game_name,
		    s.cr_date,
		    s.stake_per_bet as stake,
		    s.draws,
		    s.picks,
		    s.num_subs,
		    s.free_subs,
		    s.status,
		    s.bet_type,
		    d.sort,
		    g.comp_no,
		    0 as refund,
		    0 as winnings,
		    '' as paymethod,
		    '' as cheque_payout_msg,
		    s.num_unsettled,
		    '-' as settled,
		    '' as results
		from
		    tXGameDef d,
		    tXGameSub s,
		    tXGameBet b,
		    tXGame g
		where
		    b.xgame_bet_id = ?
		and s.xgame_sub_id = b.xgame_sub_id
		and s.acct_id = ?
		and g.xgame_id = s.xgame_id
		and d.sort = g.sort

		union

		select
		    'bet' as type,
		    b.xgame_bet_id as id,
		    d.name as game_name,
		    b.cr_date,
		    b.stake_per_line as stake,
		    '' as draws,
		    b.picks,
		    s.num_subs,
		    s.free_subs,
		    b.status,
		    b.bet_type,
		    d.sort,
		    g.comp_no,
		    b.refund,
		    b.winnings,
		    b.paymethod,
		    d.cheque_payout_msg,
		    s.num_unsettled,
		    b.settled,
		    g.results
		from
		    tXGameBet b,
		    tXGameSub s,
		    tXGame g,
		    tXGameDef d
		where
		    b.xgame_bet_id = ?
		and s.xgame_sub_id = b.xgame_sub_id
		and s.acct_id = ?
		and g.xgame_id = b.xgame_id
		and d.sort = g.sort
		order by
		    4 desc
	}
}



#--------------------------------------------------------------------------
# XGame History Handler
#--------------------------------------------------------------------------

# Private procedure to handle XGame type journal entries.
#
# The handler will either -
#     a) get all the game subscriptions between two dates
#     b) get all the game subscriptions between a journal identifier and a date
#     c) get one subscription & bet details
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_XGAME args {

	set id [get_param j_op_ref_id]
	if {$id != ""} {
		return [_XGAME_id $id]
	} else {
		return [_journal_list XGAME\
		        ob_hist::XGAME_get\
		        ob_hist::XGAME_get_w_jrnl_id]
	}
}



# Private procedure to get the XGAME details for a particular subscription or
# bet (details stored within the history package cache).
#
#   id      - bet or subscription identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_XGAME_id { id } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {XGAME_HIST: id=$id}
	ob_log::write_array DEV ob_hist::PARAM

	# is the identifier a xgame_sub_id or xgame_bet_id
	set j_op_type [get_param j_op_type [get_param txn_type]]
	if {$j_op_type == "BSTK"} {
		set qry ob_hist::XGAME_get_bstk
	} elseif {$j_op_type == "BSTL"} {
		set qry ob_hist::XGAME_get_bstl
	} else {
		return [add_err OB_HIST_BAD_J_OP_TYPE]
	}

	# set bet and subscription totals
	set bet_total   0
	set HIST(total) 0

	# execute the query
	if {[catch {set rs [ob_db::exec_qry $qry $id\
		        $PARAM(acct_id)\
		        $id\
		        $PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {XGAME_HIST: $msg}
		return [add_err OB_ERR_HIST_XGAME_FAILED $msg]
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currency symbols
	set fmt_ccy_proc [get_param fmt_ccy_proc]

	set nrows [db_get_nrows $rs]
	set cols  [db_get_colnames $rs]
	set exp   {^(stake|refund|winnings)$}

	for {set i 0} {$i < $nrows} {incr i} {

		# subscription or bet
		set type  [db_get_col $rs $i type]
		if {$type == "sub"} {
			set index 0
			set HIST(total) 1
		} else {
			set index "0,bet,${bet_total}"
			incr bet_total
		}

		foreach c $cols {
			set HIST($index,$c) [db_get_col $rs $i $c]

			# set to empty string if not defined
			if {$HIST($index,$c) == ""} {
				set HIST($index,$c) $empty_str
			}

			# format currency amounts
			if {$fmt_ccy_proc != "" && [regexp $exp $c]} {
				if {$HIST($index,$c) == $empty_str} {
					set value $empty_str
				} else {
					set value [_fmt_ccy_amount $HIST($index,$c)]
				}
				set HIST($index,fmt_${c}) $value
			}
		}
	}

	# set bet total
	if {$HIST(total) == 1} {
		set HIST(0,bet_total) $bet_total
	}


	ob_db::rs_close $rs
	return $HIST(err,status)
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_XGAME_init
