# $Id: POOLS.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
#
#
#
# (C) 2006 Orbis Technology Ltd. All rights reserved
#
# Sports Book Pools Betting Handler
#
# Provides a listing for all TPB j_op_ref_keys or displays
# the particular bet
#
# The package is self initialising
#
# Synopsis
#	package require hist_PBET ?4.5?
#


package provide hist_PBET 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5
package require util_price 4.5



# Variables
#
namespace eval ob_hist {
	variable PBET_INIT

	set PBET_INIT 0
}



# Private procedure to perform one time initialisation.
#
proc ob_hist::_PBET_init args {
	variable PBET_INIT

	# already initialised?
	if {$PBET_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_price::init

	ob_log::write DEBUG {BET_HIST: init}

	# prepare queries
	_PBET_prepare_qrys

	# successfully initialised
	set PBET_INIT 1
}



# Queries
#
proc ob_hist::_PBET_prepare_qrys args {
	variable PBET_INIT

	if {$PBET_INIT} {
		return
	}

	# get all BET stakes
	# - only ever return a maximum of 20 entries
	# - dont bother with the returns
	ob_db::store_qry ob_hist::PBET_get {
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
			b.status,
			b.source
		from
			tJrnl j,
			tPoolbet b
		where
			j.cr_date >= ?
			and j.cr_date <= ?
			and j.acct_id = ?
			and b.source matches ?
			and j.j_op_type = 'BSTK'
			and j.j_op_ref_key = 'TPB'
			and j.j_op_ref_id = b.pool_bet_id
		order by
			j.cr_date desc,
			j.jrnl_id desc
	}



	# get all BET journal entries after a specific entry and before a date
	# - only ever returns a maximum of 20 entries
	# - dont bother with the returns
	ob_db::store_qry ob_hist::PBET_get_w_jrnl_id {
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
			b.status,
			b.source
		from
			tJrnl j,
			tPoolbet b
		where
			j.cr_date >= ?
			and j.jrnl_id <= ?
			and j.acct_id = ?
			and b.source matches ?
			and j.j_op_type = 'BSTK'
			and j.j_op_ref_key = 'TPB'
			and j.j_op_ref_id = b.pool_bet_id
		order by
			j.cr_date desc,
			j.jrnl_id desc
	}


	ob_db::store_qry ob_hist::PBET_get_id {
		select
			pb.pool_bet_id as bet_id,
			pb.stake,
			pb.status,
			pb.ccy_stake,
			pb.ccy_stake_per_line as stake_per_line,
			pb.winnings,
			pb.refund,
			pb.cr_date,
			pb.source,
			pb.receipt,
			pb.num_lines,
			pb.num_lines_void,
			pb.num_lines_win,
			pb.num_lines_lose,
			pb.settled,
			pb.num_legs,
			pb.num_selns,
			pb.unique_id,
			b.leg_no,
			b.part_no,
			b.banker_info,
			oc.desc as oc_name,
			oc.result as oc_result,
			oc.place as oc_place,
			oc.runner_num,
			case
				when
					s.pool_source_id = 'U'
				then
				(
					select
						f.desc
					from
						tToteEvLink tl,
						tEv f
					where
						tl.ev_id_tote = e.ev_id
					and
						f.ev_id = tl.ev_id_norm
				)
				else
					e.desc
			end
			as ev_name,
			e.venue as ev_venue,
			e.start_time as ev_time,
			e.country as ev_country,
			e.result_conf as ev_result_conf,
			g.name as mkt_name,
			t.name as type_name,
			p.pool_type_id as bet_type,
			case
				when
					s.pool_source_id = 'U'
				then
					'TOTE'
				when
					s.pool_source_id = 'T'
				then
					'TRNI'
				else
					s.pool_source_id
				end
			as pool_source,
			s.ccy_code,
			'W' as leg_type,
			'W' as leg_sort,
			0.00 as hcap_value,
			0 as oc_fb_result,
			0.00 as fmt_token_value,
			1.00 as price,
			c.name as cl_name,
			'Pools' as mkt_name,
			'0' as bir_index,
			oc.result as oc_result
		from
			tpoolbet pb,
			tpbet b,
			tevoc oc,
			tev e,
			tevtype t,
			tEvMkt m,
			tEvOcGrp g,
			tpool p,
			tpooltype pt,
			tpoolsource s,
			tevclass c
		where
			b.pool_bet_id = ?
		and
		b.pool_bet_id = pb.pool_bet_id
		and
			oc.ev_oc_id =b.ev_oc_id
		and
			e.ev_id = oc.ev_id
		and
			t.ev_type_id = e.ev_type_id
		and
			c.ev_class_id = t.ev_class_id
		and	
			m.ev_mkt_id = oc.ev_mkt_id
		and	
			g.ev_oc_grp_id = m.ev_oc_grp_id
		and
			p.pool_id = b.pool_id
		and
			pt.pool_type_id = p.pool_type_id
		and
			s.pool_source_id = p.pool_source_id
		order by
			b.leg_no,b.part_no
	}

	ob_db::store_qry ob_hist::PBET_get_receipt {
		select
			pb.pool_bet_id as bet_id,
			pb.stake,
			pb.status,
			pb.ccy_stake,
			pb.ccy_stake_per_line as stake_per_line,
			pb.winnings,
			pb.refund,
			pb.cr_date,
			pb.source,
			pb.receipt,
			pb.num_lines,
			pb.num_lines_void,
			pb.num_lines_win,
			pb.num_lines_lose,
			pb.settled,
			pb.num_legs,
			pb.num_selns,
			pb.unique_id,
			b.leg_no,
			b.part_no ,
			b.banker_info,
			oc.desc as oc_name,
			oc.result as oc_result,
			oc.place as oc_place,
			oc.runner_num,
			e.desc as ev_name,
			e.venue as ev_venue,
			e.country as ev_country,
			e.start_time as ev_time,
			e.result_conf as ev_result_conf,
			t.name as type_name,
			p.pool_type_id as bet_type,
			case
				when
					s.pool_source_id = 'U'
				then
					'TOTE'
				when
					s.pool_source_id = 'T'
				then
					'TRNI'
				else
					s.pool_source_id
				end
			as pool_source,
			s.ccy_code,
			'W' as leg_type,
			'W' as leg_sort,
			0.00 as hcap_value,
			0 as oc_fb_result,
			0.00 as fmt_token_value,
			1.00 as price,
			c.name as cl_name,
			'Pools' as mkt_name,
			'0' as bir_index,
			oc.result as oc_result
		from
			tpoolbet pb,
			tpbet b,
			tevoc oc,
			tev e,
			tevtype t,
			tEvMkt m,
			tEvOcGrp g,
			tpool p,
			tpooltype pt,
			tpoolsource s,
			tevclass c
		where
			pb.acct_id = ?
		and
			pb.receipt = ?
		and
			b.pool_bet_id = pb.pool_bet_id
		and
			oc.ev_oc_id =b.ev_oc_id
		and
			e.ev_id = oc.ev_id
		and
			t.ev_type_id = e.ev_type_id
		and
			c.ev_class_id = t.ev_class_id
		and	
			m.ev_mkt_id = oc.ev_mkt_id
		and	
			g.ev_oc_grp_id = m.ev_oc_grp_id
		and
			p.pool_id = b.pool_id
		and
			pt.pool_type_id = p.pool_type_id
		and
			s.pool_source_id = p.pool_source_id
		order by
			b.leg_no,b.part_no
	}

}



# Private procedure to handle TPB type journal entries.
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



proc ob_hist::_PBET args {

	set bet_id  [get_param j_op_ref_id]
	set receipt [get_param receipt]

	if {$receipt != ""} {
		return [ob_hist::_PBET_id "%" $receipt]
	} elseif {$bet_id != ""} {
		return [ob_hist::_PBET_id $bet_id]
	} else {
		return [_journal_list PBET\
		    ob_hist::PBET_get\
		    ob_hist::PBET_get_w_jrnl_id]
	}
}



# Private procedure to get the details for a particular bet
# (details stored within the history package cache).
#
#   bet_id  - bet identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_PBET_id { bet_id {receipt ""}} {
	variable HIST
	variable PARAM

	ob_log::write DEBUG {POOL_BET_HIST: bet_id=$bet_id}

	# execute the query
	if {$receipt == ""} {
		if {[catch {set rs [ob_db::exec_qry ob_hist::PBET_get_id\
			$bet_id\
			$PARAM(acct_id)]} msg]} {
			ob_log::write ERROR {POOL_BET_HIST: $msg}
			return [add_err OB_ERR_HIST_BET_FAILED $msg]
		}
	} else {
		if {[catch {set rs [ob_db::exec_qry ob_hist::PBET_get_receipt\
			$PARAM(acct_id)\
			$receipt]} msg]} {
			ob_log::write ERROR {POOL_BET_HIST: $msg}
			return [add_err OB_ERR_HIST_BET_FAILED $msg]
		}
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# which columns are currency values
	set ccy_cols {^(stake|stake_per_line|refund|winnings|ccy_stake|ccy_stake_per_line)$}

	set HIST(total) 0
	set nrows [db_get_nrows $rs]
	set HIST(0,bet_total)  $nrows

	for {set a 0} {$nrows > $a} {incr a} {
		#Populate history with bet details

		if {$a == 0} {
			#get tpoolbet details
			set HIST(total) 1

			set pool_ccy_code [db_get_col $rs $a ccy_code]

			foreach c {bet_id stake status ccy_stake winnings refund ccy_code \
				cr_date receipt bet_type num_lines stake_per_line
				num_lines_win num_lines_lose num_lines_void num_legs num_selns
				settled pool_source leg_type fmt_token_value unique_id source} {

				set HIST(0,$c) [ob_hist::XL [SB_xl::get lang] "[db_get_col $rs $a $c]"]

				# format currency amounts
				if {$PARAM(fmt_ccy_proc) != "" && [regexp $ccy_cols $c]} {
					ob_hist::_PBET_format $c $pool_ccy_code
				}
			}

			#Append the pool_source to the bet_type
			set HIST(0,bet_type) "$HIST(0,pool_source)_$HIST(0,bet_type)"
		}

		set leg_num [expr [db_get_col $rs $a leg_no] - 1]

		if {![info exists HIST(0,$leg_num,num_selns)]} {
			set HIST(0,$leg_num,num_selns) 1
		} else {
			incr HIST(0,$leg_num,num_selns)
		}
		foreach field {oc_name ev_time type_name ev_name ev_venue ev_country\
			ev_result_conf leg_no num_legs pool_source bet_type banker_info leg_sort\
			hcap_value oc_fb_result price cl_name mkt_name bir_index oc_result} {
			set HIST(0,bet,$a,$field) [ob_hist::XL [SB_xl::get lang] "[db_get_col $rs $a $field]" ]
		}

		#Add the place to the name
		set banker_info [db_get_col $rs $a banker_info]

		if {$banker_info != ""} {
			set banker_info [string trimleft $banker_info "B"]
			set HIST(0,bet,$a,oc_name) "$banker_info - $HIST(0,bet,$a,oc_name)"
		}

		set HIST(0,bet,$leg_num,price) [db_get_col $rs $a price]
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



# Formats a ccy item, places dollar equivalent next to stakes
#
proc ob_hist::_PBET_format {field  pool_ccy_code} {
	variable HIST
	variable PARAM

	set user_ccy_code  $PARAM(ccy_code)
	set empty_str [get_param empty_str]

	if {$HIST(0,$field) == $empty_str} {
		set value $empty_str
	} elseif {($field == "ccy_stake" || $field == "stake_per_line") && \
		($user_ccy_code != $pool_ccy_code)} {
		#Display the currency the bet was placed in

		set PARAM(ccy_code) $pool_ccy_code
		set value [ _fmt_ccy_amount $HIST(0,$field) ]
		set PARAM(ccy_code) $user_ccy_code

		if {$field== "ccy_stake"} {
			set HIST(0,fmt_stake) "$HIST(0,fmt_stake) ($value)"
		}

	} else {
		set value [_fmt_ccy_amount $HIST(0,$field)]
	}

	set HIST(0,fmt_${field}) $value

	return $value
}



#Self initialise
ob_hist::_PBET_init