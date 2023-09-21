# $Id: TX.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# General Transaction history handler. Provides a listing for all j_op_types
# at level 0 within the history hierarchy.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_TX ?4.5?
#

package provide hist_TX 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable TX_INIT

	# initialise flag
	set TX_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_TX_init args {

	variable TX_INIT

	# already initialised?
	if {$TX_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {TX_HIST: init}

	# prepare queries
	_TX_prepare_qrys

	# successfully initialised
	set TX_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_TX_prepare_qrys args {

	if {[OT_CfgGet ACCT_HIST_GAMES 1]} {

		# get all journal entries between two dates
		ob_db::store_qry ob_hist::TX_get {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.line_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.amount,
				j.j_op_type,
				j.user_id,
				j.balance,
				case when j.j_op_ref_key in ('IGF','IGFP') then g.name else null end as game_name
			from
				tJrnl j,
				outer (tCgGameSummary cg, tCgGame g)
			where
				j.cr_date >= ?
			and j.cr_date <= ?
			and j.acct_id = ?
			and cg.cg_game_id = j.j_op_ref_id
			and cg.cg_id = g.cg_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}

		# get all journal entries after a specific entry and before a date
		ob_db::store_qry ob_hist::TX_get_w_jrnl_id {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.line_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.amount,
				j.j_op_type,
				j.user_id,
				j.balance,
				case when j.j_op_ref_key in ('IGF','IGFP') then g.name else null end as game_name
			from
				tJrnl j,
				outer (tCgGameSummary cg, tCgGame g)
			where
				j.cr_date >= ?
			and j.jrnl_id <= ?
			and j.acct_id = ?
			and cg.cg_game_id = j.j_op_ref_id
			and cg.cg_id = g.cg_id
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}

	} else {

		# get all journal entries between two dates
		ob_db::store_qry ob_hist::TX_get {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.line_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.amount,
				j.j_op_type,
				j.user_id,
				j.balance,
				'' as game_name
			from
				tJrnl j
			where
				j.cr_date >= ?
			and j.cr_date <= ?
			and j.acct_id = ?
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}

		# get all journal entries after a specific entry and before a date
		ob_db::store_qry ob_hist::TX_get_w_jrnl_id {
			select first 21
				j.cr_date,
				j.jrnl_id,
				j.line_id,
				j.desc,
				j.j_op_ref_key,
				j.j_op_ref_id,
				j.amount,
				j.j_op_type,
				j.user_id,
				j.balance,
				'' as game_name
			from
				tJrnl j
			where
				j.cr_date >= ?
			and j.jrnl_id <= ?
			and j.acct_id = ?
			order by
				j.cr_date desc,
				j.jrnl_id desc
		}
	}
}



#--------------------------------------------------------------------------
# Account History Handler
#--------------------------------------------------------------------------

# Private procedure to get the following journal entries -
#    a) get all entries between two dates
#    b) get all entries between a journal identifier and a date
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
proc ob_hist::_TX args {
	return [_journal_list TX ob_hist::TX_get ob_hist::TX_get_w_jrnl_id]
}



#--------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_TX_init
