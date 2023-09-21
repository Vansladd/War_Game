# $Id: GAM.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Provides a listing for all configured game types j_op_types or display the details for
# one game summary.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_GAM ?4.5?
#

package provide hist_GAM 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable GAM_INIT

	# initialise flag
	set GAM_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_GAM_init args {

	variable GAM_INIT

	# already initialised?
	if {$GAM_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {GAM_HIST: init}

	# prepare queries
	_GAM_prepare_qrys

	# successfully initialised
	set GAM_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_GAM_prepare_qrys args {

	set qry [subst {
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
		    tJrnl j
		where
		    cr_date >= ?
		and %s
		and acct_id = ?
		and j_op_type in ('[join [OT_CfgGet GAME_HIST_OP_TYPES "CGSK"] "','"]')
		and j_op_ref_key in ('[join [OT_CfgGet GAME_HIST_OP_REF_KEYS "IGF"] "','"]')
		order by
		    cr_date desc,
		    jrnl_id desc
	}]

	# get all games stakes
	# - dont bother with the returns as each stake entry links to the same table
	ob_db::store_qry ob_hist::GAM_get\
	[format $qry "j.cr_date <= ?"]

	# get all games journal entries after a specific entry and before a date
	# - dont bother with the returns as each stake entry links to the same table
	ob_db::store_qry ob_hist::GAM_get_w_jrnl_id\
	[format $qry "j.jrnl_id <= ?"]
}



#--------------------------------------------------------------------------
# GAM History Handler
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
proc ob_hist::_GAM args {

	set qry_get "ob_hist::GAM_get"
	set qry_get_w_jrnl_id "ob_hist::GAM_get_w_jrnl_id"

	return [_journal_list GAM\
		    $qry_get\
		    $qry_get_w_jrnl_id]
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_GAM_init
