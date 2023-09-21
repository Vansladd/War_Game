# $Id: PMT.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Payments history handler.
# Provides a listing for all DEP, WTD and RWTD j_op_types or display the
# details for one particular transaction.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_PMT ?4.5?
#

package provide hist_PMT 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable PMT_INIT

	# initialise flag
	set PMT_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_PMT_init args {

	variable PMT_INIT

	# already initialised?
	if {$PMT_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {PMT_HIST: init}

	# prepare queries
	_PMT_prepare_qrys

	# successfully initialised
	set PMT_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_PMT_prepare_qrys args {

	# get all DEP, WTD and RWTD journal entries between two dates
	ob_db::store_qry ob_hist::PMT_get {
		select first 21
		    cr_date,
		    jrnl_id,
		    desc,
		    j_op_ref_key,
		    j_op_ref_id,
		    j_op_type,
		    amount,
		    user_id,
		    balance,
		    acct_id
		from
		    tJrnl
		where
		    cr_date >= ?
		and cr_date <= ?
		and acct_id = ?
		and j_op_type in ('DEP', 'WTD', 'RWTD')
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get all DEP, WTD and RWTD journal entries after a specific entry before a
	# date
	ob_db::store_qry ob_hist::PMT_get_w_jrnl_id {
		select first 21
		    cr_date,
		    jrnl_id,
		    desc,
		    j_op_ref_key,
		    j_op_ref_id,
		    j_op_type,
		    amount,
		    user_id,
		    balance,
		    acct_id
		from
		    tJrnl
		where
		    cr_date >= ?
		and jrnl_id <= ?
		and acct_id = ?
		and j_op_type in ('DEP', 'WTD', 'RWTD')
		order by
		    cr_date desc,
		    jrnl_id desc
	}

	# get a particular payment detail
	ob_db::store_qry ob_hist::PMT_get_id {
		select
		    pmt_id,
		    cr_date,
		    payment_sort,
		    ref_key,
		    amount,
		    commission,
		    settled_at,
		    processed_at,
		    source
		from
			tPmt
		where
			pmt_id = ?
		and acct_id = ?
	}
}



#--------------------------------------------------------------------------
# Payment History Handler
#--------------------------------------------------------------------------

# Private procedure to handle payment type journal entries (WTD | DEP | RWTD).
#
# The handler will either -
#     a) get all the payments between two dates
#     b) get all the payments between a journal identifier and a date
#     c) get one payment detail
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_PMT args {

	set pmt_id [get_param j_op_ref_id]
	if {$pmt_id != ""} {
		return [_PMT_id $pmt_id]
	} else {
		return [_journal_list PMT ob_hist::PMT_get ob_hist::PMT_get_w_jrnl_id]
	}
}



# Private procedure to get the payment details for a particular payment
# (details stored within the history package cache).
#
#   pmt_id  - payment identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_PMT_id { pmt_id } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {PMT_HIST: pmt_id=$pmt_id}
	ob_log::write_array DEV ob_hist::PARAM

	# execute the query
	if {[catch {set rs [ob_db::exec_qry ob_hist::PMT_get_id\
		        $pmt_id\
		        $PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {PMT_HIST: $msg}
		return [add_err OB_ERR_HIST_PMT_FAILED $msg]
	}

	# store data
	if {[db_get_nrows $rs] == 1} {

		# add history details
		set status [add_hist $rs 0 PMT "" "" {amount commission}]
		if {$status == "OB_OK"} {

			if {[catch {

				# translate text?
				# NB: differs to add_hist method of translating text!
				if {$PARAM(xl_proc) != ""} {
					foreach c {payment_sort ref_key} {
						set HIST(0,xl_${c})\
						    [_XL "OB_PMT_[string toupper $c]_$HIST(0,$c)"]
					}
				}

				set HIST(total) 1

			} msg]} {
				ob_log::write ERROR {PMT_HIST: $msg}
				set status [add_err OB_ERR_HIST_PMT_FAILED $msg]
			}
		}
	} else {
		set HIST(total) 0
		set status [add_err OB_OK]
	}

	ob_db::rs_close $rs

	return $HIST(err,status)
}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_PMT_init
