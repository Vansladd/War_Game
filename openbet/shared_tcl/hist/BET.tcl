# $Id: BET.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Sports Book history handler.
# Provides a listing for all ESB j_op_ref_keys or display the details for one
# particular bet.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_BET ?4.5?
#

package provide hist_BET 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5
package require util_price 4.5


# Variables
#
namespace eval ob_hist {

	variable BET_INIT

	set BET_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_BET_init args {

	variable BET_INIT

	# already initialised?
	if {$BET_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_price::init

	ob_log::write DEBUG {BET_HIST: init}

	# prepare queries
	_BET_prepare_qrys

	# successfully initialised
	set BET_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_BET_prepare_qrys args {
	variable CFG

	# get all BET stakes
	# - dont bother with the returns as each stake entry links to tBet
	if {$CFG(combine_sb_and_pools)} {
		# Store the version of the query that combines
		# sportsbook transactions with pools transactions
		ob_db::store_qry ob_hist::BET_get {
			select
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tBet b
			where
				j.cr_date >= ?
			and j.cr_date <= ?
			and j.acct_id = ?
			and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
			and j.j_op_ref_key = 'ESB'
			and j.j_op_ref_id = b.bet_id

			union

			select
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tPoolbet b
			where
				j.cr_date >= ?
				and j.cr_date <= ?
				and j.acct_id = ?
				and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
				and j.j_op_ref_key = 'TPB'
				and j.j_op_ref_id = b.pool_bet_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}
	} else {
		# Otherwise store the traditional version
		# - only ever return a maximum of 20 entries
		ob_db::store_qry ob_hist::BET_get {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tBet b
			where
				j.cr_date >= ?
			and j.cr_date <= ?
			and j.acct_id = ?
			and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
			and j.j_op_ref_key = 'ESB'
			and j.j_op_ref_id = b.bet_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}
	}

	# get all BET journal entries after a specific entry and before a date
	# - only ever returns a maximum of 20 entries
	# - dont bother with the returns as each stake entry links to tBet
	if {$CFG(combine_sb_and_pools)} {
		# Store the version of the query that combines
		# sportsbook transactions with pools transactions
		ob_db::store_qry ob_hist::BET_get_w_jrnl_id {
			select
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tBet b
			where
				j.cr_date >= ?
			and j.jrnl_id <= ?
			and j.acct_id = ?
			and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
			and j.j_op_ref_key = 'ESB'
			and j.j_op_ref_id = b.bet_id

			union

			select
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tPoolbet b
			where
				j.cr_date >= ?
				and j.jrnl_id <= ?
				and j.acct_id = ?
				and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
				and j.j_op_ref_key = 'TPB'
				and j.j_op_ref_id = b.pool_bet_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}
	} else {
		# Otherwise store the traditional version
		# - only ever return a maximum of 20 entries
		ob_db::store_qry ob_hist::BET_get_w_jrnl_id {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.j_op_type,
				j.amount,
				j.user_id,
				j.balance,
				j.acct_id,
				b.status
			from
				tJrnl j,
				tBet b
			where
				j.cr_date >= ?
			and j.jrnl_id <= ?
			and j.acct_id = ?
			and j.j_op_type in ('BSTK', 'BSTL','BWIN','BRFD', 'BREF', 'BCAN', 'BUST','BUWN','BURF')
			and j.j_op_ref_key = 'ESB'
			and j.j_op_ref_id = b.bet_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}
	}

	# get a particular bet and corresponding legs/parts etc..
	# - NB: maybe necessary to split the query into two (get the tBet, then
	#   based on the bet_type, get tOBet or tManOBet details), if the average
	#   number of rows is increasing - difficult to judge what the acceptable
	#   limit is...
	ob_db::store_qry ob_hist::BET_get_id {
		select
		    b.bet_id,
		    b.cr_date,
		    b.bet_type,
		    b.stake,
		    b.stake_per_line,
		    b.winnings,
		    b.refund,
		    b.status,
		    b.settled,
		    b.leg_type,
		    b.num_selns,
		    b.num_legs,
		    b.num_lines,
		    b.num_lines_void,
		    b.num_lines_win,
		    b.num_lines_lose,
		    b.receipt,
		    b.unique_id,
		    b.status,

		    c.name        as cl_name,
		    t.name        as type_name,
		    e.desc        as ev_name,
		    e.venue       as ev_venue,
		    e.country     as ev_country,
		    e.start_time  as ev_time,
		    e.result_conf as ev_result_conf,
		    m.name        as mkt_name,
		    s.desc        as oc_name,
		    s.result      as oc_result,
		    s.place       as oc_place,
		    s.fb_result   as oc_fb_result,
		    s.cs_home     as oc_cs_home,
		    s.cs_away     as oc_cs_away,

		    o.price_type,
		    o.o_num       as price_num,
		    o.o_den       as price_den,
		    o.leg_no,
		    o.leg_sort,
		    o.part_no,
		    o.hcap_value,
		    o.bir_index,
		    o.banker,
		    o.bets_per_seln,
		    o.in_running,

		    mb.to_settle_at as mb_settle_at,
		    mb.desc_1,
		    mb.desc_2,
		    mb.desc_3,
		    mb.desc_4
		from
		    tBet b,
		outer tManOBet mb,
		outer (tOBet o, tEvOc s, tEvMkt m, tEv e, tEvType t,
			   tEvClass c)
		where
		    b.bet_id = ?
		and b.acct_id = ?
		and o.bet_id = b.bet_id
		and s.ev_oc_id = o.ev_oc_id
		and m.ev_mkt_id = s.ev_mkt_id
		and e.ev_id = s.ev_id
		and t.ev_type_id = e.ev_type_id
		and c.ev_class_id = t.ev_class_id
		and mb.bet_id = b.bet_id
		order by
		    o.leg_no,
		    o.part_no
	}


	# get a particular bet and corresponding legs/parts etc..
	# - NB: maybe necessary to split the query into two (get the tBet, then
	#   based on the bet_type, get tOBet or tManOBet details), if the average
	#   number of rows is increasing - difficult to judge what the acceptable
	#   limit is...
	ob_db::store_qry ob_hist::BET_get_receipt {
		select
		    b.bet_id,
		    b.cr_date,
		    b.bet_type,
		    b.stake,
		    b.stake_per_line,
		    b.winnings,
		    b.refund,
		    b.status,
		    b.settled,
		    b.leg_type,
		    b.num_selns,
		    b.num_legs,
		    b.num_lines,
		    b.num_lines_void,
		    b.num_lines_win,
		    b.num_lines_lose,
		    b.receipt,
		    b.unique_id,

		    c.name        as cl_name,
		    t.name        as type_name,
		    e.desc        as ev_name,
		    e.venue       as ev_venue,
		    e.country     as ev_country,
		    e.start_time  as ev_time,
		    e.result_conf as ev_result_conf,
		    m.name        as mkt_name,
		    s.desc        as oc_name,
		    s.result      as oc_result,
		    s.place       as oc_place,
		    s.fb_result   as oc_fb_result,
		    s.cs_home     as oc_cs_home,
		    s.cs_away     as oc_cs_away,

		    o.price_type,
		    o.o_num       as price_num,
		    o.o_den       as price_den,
		    o.leg_no,
		    o.leg_sort,
		    o.part_no,
		    o.hcap_value,
		    o.bir_index,
		    o.banker,
		    o.bets_per_seln,
		    o.in_running,

		    mb.to_settle_at as mb_settle_at,
		    mb.desc_1,
		    mb.desc_2,
		    mb.desc_3,
		    mb.desc_4
		from
		    tBet b,
		outer tManOBet mb,
		outer (tOBet o, tEvOc s, tEvMkt m, tEv e, tEvType t,
			   tEvClass c)
		where
			b.acct_id = ?
		and b.receipt = ?
		and o.bet_id = b.bet_id
		and s.ev_oc_id = o.ev_oc_id
		and m.ev_mkt_id = s.ev_mkt_id
		and e.ev_id = s.ev_id
		and t.ev_type_id = e.ev_type_id
		and c.ev_class_id = t.ev_class_id
		and mb.bet_id = b.bet_id
		order by
		    o.leg_no,
		    o.part_no
	}
}



#--------------------------------------------------------------------------
# Sports Book History Handler
#--------------------------------------------------------------------------

# Private procedure to handle ESB type journal entries.
#
# The handler will either -
#     a) get all the bets between two dates
#     b) get all the bets between a journal identifier and a date
#     c) get one bet (including all the legs/parts etc..)
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_BET args {

	set bet_id  [get_param j_op_ref_id]
	set receipt [get_param receipt]

	if {$receipt != ""} {
		return [_BET_id "%" $receipt]
	} elseif {$bet_id != ""} {
		return [_BET_id $bet_id]
	} else {
		return [_journal_list BET\
		    ob_hist::BET_get\
		    ob_hist::BET_get_w_jrnl_id]
	}
}



# Private procedure to get the details for a particular bet
# (details stored within the history package cache).
#
#   bet_id  - bet identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_BET_id { bet_id {receipt ""} } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {BET_HIST: bet_id=$bet_id}
	ob_log::write_array DEV ob_hist::PARAM

	# execute the query
	if {$receipt == ""} {
		if {[catch {set rs [ob_db::exec_qry ob_hist::BET_get_id\
			        $bet_id\
			        $PARAM(acct_id)]} msg]} {
			ob_log::write ERROR {BET_HIST: $msg}
			return [add_err OB_ERR_HIST_BET_FAILED $msg]
		}
	} else {
		if {[catch {set rs [ob_db::exec_qry ob_hist::BET_get_receipt\
			        $PARAM(acct_id)\
					$receipt]} msg]} {
			ob_log::write ERROR {BET_HIST: $msg}
			return [add_err OB_ERR_HIST_BET_FAILED $msg]
		}
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# which columns are currency values
	set ccy_cols {^(stake|stake_per_line|refund|winnings)$}

	# which columns need to be translated
	set xl_cols {^([a-z]+_name|ev_venue|ev_country)$}

	# price type
	set price_type [get_param price_type]

	# store data
	set HIST(total) 0
	set nrows       [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		# first row, get tBet details
		# - always 1 tBet detail and 'n' tObet/tOManBet details
		if {$i == 0} {
			set HIST(total)       1
			set HIST(0,bet_total) 1

			# get tBet details
			foreach c {bet_id cr_date bet_type stake stake_per_line winnings\
				        refund status settled leg_type num_selns num_legs\
				        num_lines num_lines_void num_lines_win num_lines_lose\
			            receipt unique_id} {
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

		} else {
			incr HIST(0,bet_total)
		}

		# get tOBet/tOManBet details
		if {$HIST(0,bet_type) == "MAN"} {
			set cols {mb_settle_at desc_1 desc_2 desc_3 desc_4}
		} else {
			set cols {cl_name type_name ev_name ev_venue ev_country ev_time\
			        ev_result_conf mkt_name oc_name oc_result oc_place\
			        oc_fb_result oc_cs_home oc_cs_away\
			        price_type price_num price_den leg_no leg_sort\
			        part_no hcap_value bir_index banker bets_per_seln\
			        in_running}
		}
		foreach c $cols {
			set HIST(0,bet,$i,$c) [db_get_col $rs $i $c]

			# set to empty string if not defined
			if {$HIST(0,bet,$i,$c) == ""} {
				set HIST(0,bet,$i,$c) $empty_str
			}

			# translate columns
			if {$PARAM(xl_proc) != "" && [regexp $xl_cols $c]} {
				if {$HIST(0,bet,$i,$c) != $empty_str} {
					set HIST(0,bet,$i,xl_${c}) [_XL $HIST(0,bet,$i,$c)]
				} else {
					set HIST(0,bet,$i,xl_${c}) $empty_str
				}
			}
		}

		if {$HIST(0,bet_type) != "MAN"} {
			# format the price
			set HIST(0,bet,$i,price) [ob_price::mk_bet_str \
				$HIST(0,bet,$i,price_type)\
				$HIST(0,bet,$i,price_num)\
				$HIST(0,bet,$i,price_den)\
				$price_type]
		}
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_BET_init
