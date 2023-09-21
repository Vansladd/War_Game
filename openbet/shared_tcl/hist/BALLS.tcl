# $Id: BALLS.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Balls history handler.
# Provides a listing for all LB--, IB--, LB++ and IB++ j_op_types or display the
# details for one particular subscription/payout.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_BALLS ?4.5?
#

package provide hist_BALLS 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5
package require util_price 4.5



# Variables
#
namespace eval ob_hist {

	variable BALLS_INIT

	set BALLS_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_BALLS_init args {

	variable BALLS_INIT

	# already initialised?
	if {$BALLS_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_price::init

	ob_log::write DEBUG {BALLS_HIST: init}

	# prepare queries
	_BALLS_prepare_qrys

	# initialised
	set BALLS_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_BALLS_prepare_qrys args {

	# get all BALLS subscription[s]
	# - only ever return a maximum of 20 entries
	# - dont bother with the payouts as the subscriptions are linked to payouts
	ob_db::store_qry ob_hist::BALLS_get {
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
		and j_op_type in ('LB--', 'IB--')
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get all Balls journal entries after a specific entry and before a date
	# - only ever returns a maximum of 20 entries
	# - dont bother with the payouts as the subscriptions are linked to payouts
	ob_db::store_qry ob_hist::BALLS_get_w_jrnl_id {
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
		and j_op_type in ('LB--', 'IB--')
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get a BALLS subscription (and associated payouts/draws)
	ob_db::store_qry ob_hist::BALLS_get_sub {
		select
		    s.sub_id,
		    s.cr_date as sub_date,
		    s.type_id,
		    s.seln,
		    s.firstdrw_id,
		    s.lastdrw_id,
		    s.ndrw,
		    s.stake,
		    s.returns,
		    s.selcode,
		    s.oddsnum,
		    s.oddsden,
		    s.payout as sub_payout,

		    p.payout_id,
		    p.payout,
		    p.cr_date as payout_date,

		    d.drw_id,
		    d.ball1,
		    d.ball2,
		    d.ball3,
		    d.ball4,
		    d.ball5,
		    d.ball6,
		    d.status,
		    d.settled_at

		from
		    tBallsSub s,
		outer (tBallsPayout p, tBallsDrw d)

		where
		    s.sub_id = ?
		and s.acct_id = ?
		and p.sub_id = s.sub_id
		and d.drw_id = p.drw_id

		order by
		    drw_id
	}

	# get a BALLS payout and associated subscription and draw
	ob_db::store_qry ob_hist::BALLS_get_payout {
		select
		    s.sub_id,
		    s.cr_date as sub_date,
		    s.type_id,
		    s.seln,
		    s.firstdrw_id,
		    s.lastdrw_id,
		    s.ndrw,
		    s.stake,
		    s.returns,
		    s.selcode,
		    s.oddsnum,
		    s.oddsden,
		    s.payout as sub_payout,

		    p.payout_id,
		    p.payout,
		    p.cr_date as payout_date,

		    d.drw_id,
		    d.ball1,
		    d.ball2,
		    d.ball3,
		    d.ball4,
		    d.ball5,
		    d.ball6,
		    d.status,
		    d.settled_at

		from
		    tBallsSub s,
		    tBallsPayout p,
		    tBallsDrw d

		where
		    p.payout_id = ?
		and s.sub_id = p.sub_id
		and s.acct_id = ?
		and d.drw_id = p.drw_id
	}
}



#--------------------------------------------------------------------------
# BALLS History Handler
#--------------------------------------------------------------------------

# Private procedure to handle Balls type journal entries.
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
proc ob_hist::_BALLS args {

	set id [get_param j_op_ref_id]
	if {$id != ""} {
		return [_BALLS_id $id]
	}
	return [_journal_list BALLS\
	    ob_hist::BALLS_get\
	    ob_hist::BALLS_get_w_jrnl_id]
}



# Private procedure to get the BALLS details for a particular subscription or
# payout (details stored within the history package cache).
#
#   id      - payout or subscription identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_BALLS_id { id } {

	variable HIST
	variable PARAM

	set j_op_type [get_param j_op_type [get_param txn_type]]
	ob_log::write DEBUG {BALLS_HIST: id=$id j_op_type=$j_op_type}

	ob_log::write_array DEV ob_hist::PARAM

	# is the identifier a balls subscription or payout
	if {[regexp {^[IL]B--$} $j_op_type]} {
		set qry ob_hist::BALLS_get_sub
	} elseif {[regexp {^[IL]B\+\+$} $j_op_type]} {
		set qry ob_hist::BALLS_get_payout
	} else {
		return [add_err OB_HIST_BAD_J_OP_TYPE]
	}

	# set payout and subscription totals
	set HIST(total)          0
	set HIST(0,payout_total) 0

	# execute the query
	if {[catch {set rs [ob_db::exec_qry $qry $id\
		        $PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {BALLS_HIST: $msg}
		return [add_err OB_ERR_HIST_BALLS_HIST_FAILED $msg]
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currency symbols
	set fmt_ccy_proc [get_param fmt_ccy_proc]

	# which columns are currency values
	set ccy_cols {^(stake|returns|sub_payout|payout)$}

	# store data
	set nrows [db_get_nrows $rs]
	for {set i 0} {$i < $nrows} {incr i} {

		# first row, get tBallsSub details
		# - always 1 tBallsSub detail and 0..n tBallsPayout
		# NB: There maybe loads of payout rows returned, may consider to
		#     page the result!?
		if {$i == 0} {
			set HIST(total) 1

			# get sub details
			foreach c {sub_id sub_date type_id seln firstdrw_id lastdrw_id ndrw\
				        stake returns selcode oddsnum oddsden sub_payout} {
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

			# format the price
			set HIST(0,price) [ob_price::mk \
			    $HIST(0,oddsnum)\
			    $HIST(0,oddsden)\
			    [get_param price_type]]
		}

		# payout?
		set payout_id [db_get_col $rs $i payout_id]
		if {$payout_id != ""} {

			incr HIST(0,payout_total)
			set HIST(0,payout,$i,payout_id) $payout_id

			foreach c { payout payout_date drw_id ball1 ball2 ball3 ball4 ball5\
				        ball6 status settled_at} {
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
ob_hist::_BALLS_init
