# $Id: SNG.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Universal Game/Scheduled Number Games (SNG).
# Provides a listing for all UGSK & UGWN j_op_types or display the details for
# one SNG game summary.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_SNG ?4.5?
#

package provide hist_SNG 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable SNG_INIT

	# initialise flag
	set SNG_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_SNG_init args {

	variable SNG_INIT

	# already initialised?
	if {$SNG_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {SNG_HIST: init}

	# prepare queries
	_SNG_prepare_qrys

	# successfully initialised
	set SNG_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_SNG_prepare_qrys args {

	# get all SNG stakes
	# - dont bother with the returns as each stake entry links to the same table
	ob_db::store_qry ob_hist::SNG_get {
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
		and j_op_type = 'UGSK'
		and j_op_ref_key = 'UGAM'
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get all SNG journal entries after a specific entry and before a date
	# - dont bother with the returns as each stake entry links to the same table
	ob_db::store_qry ob_hist::SNG_get_w_jrnl_id {
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
		and j_op_type = 'UGSK'
		and j_op_ref_key = 'UGAM'
		order by
			cr_date desc,
			jrnl_id desc
	}

	# get a game summary and associated subscription
	ob_db::store_qry ob_hist::SNG_get_summary {
		select
		    y.ug_summary_id,
		    y.version,
		    y.total_stake,
		    y.stake_per_game,
		    y.winnings,
		    y.refund,
		    y.status,
		    y.started,
		    y.finished,
		    y.receipt,

		    s.ug_draw_sub_id,
		    s.num_draws,
		    s.num_placed,
		    s.stake_per_draw,
		    s.selection_1,
		    s.selection_2,
		    s.selection_3,

		    t.ug_type_desc,
		    t.ug_type_code,
		    g.ug_type_grp_desc,
		    g.ug_type_grp_code,
		    c.ug_class_desc,
		    c.ug_class_code

		from
		    tUGGameSummary y,
		    tUGDrawSub s,
		    tUGGameType t,
		    tUGGameTypeGrp g,
		    tUGGameClass c

		where
		    y.ug_summary_id = ?
		and y.acct_id = ?
		and s.ug_summary_id = y.ug_summary_id
		and t.ug_type_code = y.ug_type_code
		and g.ug_type_grp_code = t.ug_type_grp_code
		and c.ug_class_code = g.ug_class_code
	}

	# get a subscription outcomes
	ob_db::store_qry ob_hist::SNG_get_sub_oc {
		select
		    o.ug_draw_sub_oc_id,
		    o.ug_draw_sub_id,
		    o.cr_date,
		    o.winnings,
		    o.status,
		    o.settled_at,
		    o.num_correct,

		    d.ug_draw_id,
		    d.outcome_1,
		    d.outcome_2,
		    d.outcome_3,
		    d.drawing_started,
		    d.drawing_finished,

		    p.jackpot_base,
		    p.jackpot_user

		from
		    tUGDrawSubOc o,
		    tUGDraw d,
		outer tUGProgWin p

		where
		    o.ug_draw_sub_id = ?
		and d.ug_draw_id = o.ug_draw_id
		and p.ug_ref_id = o.ug_draw_sub_oc_id

		order by
		    ug_draw_sub_oc_id
	}
}



#--------------------------------------------------------------------------
# SNG History Handler
#--------------------------------------------------------------------------

# Private procedure to handle UGAM type journal entries.
#
# The handler will either -
#     a) get all the summaries between two dates
#     b) get all the summaries between a journal identifier and a date
#     c) get a single game-summary
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_SNG args {

	set summary_id [get_param j_op_ref_id]
	if {$summary_id != ""} {
		return [_SNG_id $summary_id]
	} else {
		return [_journal_list SNG\
		        ob_hist::SNG_get\
		        ob_hist::SNG_get_w_jrnl_id]
	}
}



# Private procedure to get the details for a particular SNG game summary
# (details stored within the history package cache).
#
#   summary_id  - summary identifier
#   returns     - status (OB_OK denotes success)
#                 the status is always added to HIST(err,status)
#
proc ob_hist::_SNG_id { summary_id } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {SNG_HIST: summary_id=$summary_id}
	ob_log::write_array DEV ob_hist::PARAM

	# get the game summary
	if {[catch {set rs [ob_db::exec_qry ob_hist::SNG_get_summary\
		        $summary_id\
		        $PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {SNG_HIST: $msg}
		return [add_err OB_ERR_HIST_SNG_HIST_FAILED]
	}

	# store data
	if {[db_get_nrows $rs] == 1} {

		# add history details
		set status [add_hist $rs 0 SNG "" ""\
		            {total_stake stake_per_game refund winnings stake_per_draw}]

		# get sub outcomes
		if {$status == "OB_OK" && [_SNG_outcome] == "OB_OK"} {
			set HIST(total) 1
		}

	} else {
		set HIST(total)      0
		set HIST(0,oc_total) 0
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



# Private procedure to get SNG subscription outcomes].
# (details stored within the history package cache).
#
#   returns     - status (OB_OK denotes success)
#                 the status is always added to HIST(err,status)
#
proc ob_hist::_SNG_outcome args {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {SNG_HIST: outcomes, sub_id=$HIST(0,ug_draw_sub_id)}

	# get outcomes
	if {[catch {set rs [ob_db::exec_qry ob_hist::SNG_get_sub_oc\
		        $HIST(0,ug_draw_sub_id)]} msg]} {
		ob_log::write ERROR {SNG_HIST: $msg}
		return [add_err OB_ERR_HIST_SNG_HIST_FAILED]
	}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# which columns are currency values
	set ccy_cols {^(winnings|jackpot_user)$}

	# store data
	set HIST(0,oc_total) [db_get_nrows $rs]
	set colnames         [db_get_colnames $rs]

	for {set i 0} {$i < $HIST(0,oc_total)} {incr i} {

		foreach c $colnames {
			set index "0,oc,$i,$c"
			set HIST($index) [db_get_col $rs $i $c]

			if {$HIST($index) == ""} {
				set HIST($index) $empty_str
			}

			# format currency amounts
			if {$PARAM(fmt_ccy_proc) != "" && [regexp $ccy_cols $c]} {
				if {$HIST($index) == $empty_str} {
					set value $empty_str
				} else {
					set value [_fmt_ccy_amount $HIST($index)]
				}
				set HIST(0,oc,$i,fmt_${c}) $value
			}
		}
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_SNG_init
