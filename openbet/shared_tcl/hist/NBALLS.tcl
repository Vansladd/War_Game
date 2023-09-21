# $Id: NBALLS.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# NetBalls history handler.
# Provides a listing for all NBST and NBWN j_op_types or display the details
# for one particular subscription/payout.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_NBALLS ?4.5?
#

package provide hist_NBALLS 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5
package require util_price 4.5



# Variables
#
namespace eval ob_hist {

	variable NBALLS_INIT

	# initialise flag
	set NBALLS_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_NBALLS_init args {

	variable NBALLS_INIT

	# already initialised?
	if {$NBALLS_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_price::init

	ob_log::write DEBUG {NBALLS_HIST: init}

	# prepare queries
	_NBALLS_prepare_qrys

	# successfully initialised
	set NBALLS_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_NBALLS_prepare_qrys args {

	# get all NetBalls subscription[s]
	# - dont bother with the payouts as the subscriptions are linked to payouts
	ob_db::store_qry ob_hist::NBALLS_get {
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
		and j_op_type = "NBST"
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get all NetBalls journal entries after a specific entry and before a date
	# - dont bother with the payouts as the subscriptions are linked to payouts
	ob_db::store_qry ob_hist::NBALLS_get_w_jrnl_id {
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
		and j_op_type = "NBST"
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get a NetBalls subscription + payouts
	ob_db::store_qry ob_hist::NBALLS_get_sub {
		select
		    s.client_sub_id,
		    s.server_sub_id,
		    s.client_name,
		    s.cr_date,
		    s.type_id,
		    s.seln,
		    s.firstdraw_id,
		    s.ndraws,
		    s.rdraws,
		    s.stake,
		    s.returns,
		    s.odds,
		    s.prg_m1_odds,
		    s.prg_m2_odds,
		    s.prg_m3_odds,
		    s.prg_m4_odds,

		    p.payout_id,
		    p.draw_id,
		    p.payout,
		    p.settled,
		    p.cr_date as pay_date,
		    p.num_prg1,
		    p.num_prg2,
		    p.num_prg3,
		    p.num_prg4,
		    p.num_jackpot
		from
		    tNmbrSub s,
		    outer tNmbrPayout p
		where
		    s.client_sub_id = ?
		and s.acct_id = ?
		and p.client_sub_id = s.client_sub_id
		order by
		    draw_id
	}

	# get a NetBalls payout + subscription
	ob_db::store_qry ob_hist::NBALLS_get_payout {
		select
		    s.client_sub_id,
		    s.server_sub_id,
		    s.client_name,
		    s.cr_date,
		    s.type_id,
		    s.seln,
		    s.firstdraw_id,
		    s.ndraws,
		    s.rdraws,
		    s.stake,
		    s.returns,
		    s.odds,
		    s.prg_m1_odds,
		    s.prg_m2_odds,
		    s.prg_m3_odds,
		    s.prg_m4_odds,

		    p.payout_id,
		    p.draw_id,
		    p.payout,
		    p.settled,
		    p.cr_date as pay_date,
		    p.num_prg1,
		    p.num_prg2,
		    p.num_prg3,
		    p.num_prg4,
		    p.num_jackpot
		from
		    tNmbrSub s,
		    tNmbrPayout p
		where
		    p.payout_id = ?
		and s.client_sub_id = p.client_sub_id
		and s.acct_id = ?
		order by
		    draw_id
	}
}



#--------------------------------------------------------------------------
# NetBalls History Handler
#--------------------------------------------------------------------------

# Private procedure to handle NetBalls type journal entries.
#
# The handler will either -
#     a) get all the game subscriptions between two dates
#     b) get all the game subscriptions between a journal identifier and a date
#     c) get one subscription & payout details
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_NBALLS args {

	set id [get_param j_op_ref_id]
	if {$id != ""} {
		return [_NBALLS_id $id]
	}
	return [_journal_list NBALLS\
	        ob_hist::NBALLS_get\
	        ob_hist::NBALLS_get_w_jrnl_id]
}



# Private procedure to get the NetBalls details for a particular subscription or
# payout (details stored within the history package cache).
#
#   id      - payout or subscription identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_NBALLS_id { id } {

	variable HIST
	variable PARAM

	set j_op_type [get_param j_op_type [get_param txn_type]]
	ob_log::write DEBUG {NBALLS_HIST: id=$id j_op_type=$j_op_type}

	ob_log::write_array DEV ob_hist::PARAM

	# is the identifier a balls subscription or payout
	if {$j_op_type == "NBST"} {
		set qry ob_hist::NBALLS_get_sub
	} elseif {$j_op_type == "NBWN"} {
		set qry ob_hist::NBALLS_get_payout
	} else {
		return [add_err OB_HIST_BAD_J_OP_TYPE]
	}

	# set payout and subscription totals
	set HIST(total)          0
	set HIST(0,payout_total) 0

	# execute the query
	if {[catch {set rs [ob_db::exec_qry $qry $id\
		        $PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {NBALLS_HIST: $msg}
		return [add_err OB_ERR_HIST_NBALLS_HIST_FAILED $msg]
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currency symbols
	set fmt_ccy_proc [get_param fmt_ccy_proc]

	# which columns are currency values
	set ccy_cols {^(stake|returns|payout)$}

	# store data
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {

		# first row, get subscription details
		# - always 1 sub detail and 0..n payouts
		# NB: There maybe loads of payout rows returned, may consider to
		#     page the result!?
		if {$i == 0} {
			set HIST(total) 1

			# get sub details
			foreach c {client_sub_id server_sub_id client_name cr_date type_id\
				        seln firstdraw_id ndraws rdraws stake returns odds\
				        prg_m1_odds prg_m2_odds prg_m3_odds prg_m4_odds} {
				set HIST(0,$c) [db_get_col $rs 0 $c]

				# set to empty string if not defined
				if {$HIST(0,$c) == ""} {
					set HIST(0,$c) $empty_str
				}

				# format currency amounts
				if {$PARAM(fmt_ccy_proc) != "" && [regexp $ccy_cols $c]} {
					if {$HIST(0,$c) == $empty_str} {
						set value $empty_str
					} else {
						set value [_fmt_ccy_amount $HIST(0,$c)]
					}
					set HIST(0,fmt_${c}) $value
				}
			}

			# format the prices
			set pce_type [get_param price_type]
			foreach p {odds prg_m1_odds prg_m2_odds prg_m3_odds prg_m4_odds} {
				set HIST(0,${p}_price) [ob_price::mk_dec $HIST(0,$p) $pce_type]
			}
		}

		# payout?
		set payout_id [db_get_col $rs $i payout_id]
		if {$payout_id != ""} {

			incr HIST(0,payout_total)
			set HIST(0,payout,$i,payout_id) $payout_id

			foreach c {payout_id draw_id payout settled pay_date num_prg1\
				        num_prg2 num_prg3 num_prg4 num_jackpot} {
				set HIST(0,payout,$i,$c) [db_get_col $rs $i $c]

				# set to empty string if not defined
				if {$HIST(0,payout,$i,$c) == ""} {
					set HIST(0,payout,$i,$c) $empty_str
				}

				# format currency amounts
				if {$PARAM(fmt_ccy_proc) != "" && [regexp $ccy_cols $c]} {
					if {$HIST(0,payout,$i,$c) == $empty_str} {
						set value $empty_str
					} else {
						set value [_fmt_ccy_amount $HIST(0,payout,$i,$c)]
					}
					set HIST(0,payout,$i,fmt_${c}) $value
				}
			}
		} else {
			break
		}
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_NBALLS_init
