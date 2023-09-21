# $Id: AFFP.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Payments history handler.
# Provides a listing for all DEP & WTD j_op_types or display the details for
# one particular withdrawal/deposit.
# This package provdies a gateway from the customer hist package to the
# affiliate package.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_AFFP ?4.5?
#
# See also:
#  aff/pmt.tcl
#
package provide hist_AFFP 0.1



# Dependencies
#
package require util_log   4.5
package require util_db    4.5



# Variables
#
namespace eval ob_hist {

	variable AFFP_INIT

	# initialise flag
	set AFFP_INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_AFFP_init args {

	variable AFFP_INIT

	# already initialised?
	if {$AFFP_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {AFFP_HIST: init}

	# prepare queries
	_AFFP_prepare_qrys

	# successfully initialised
	set AFFP_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_AFFP_prepare_qrys args {

	# get all DEP & WTD journal entries between two dates
	# - only ever return a maximum of 20 entries
	ob_db::store_qry ob_hist::AFFP_get {
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
		    cr_date between ? and ?
		and acct_id = ?
		and j_op_type = 'AFFP'
		order by
		    cr_date,
		    jrnl_id
	}

	# get all DEP & WTD journal entries after a specific entry before a date
	# - only ever returns a maximum of 20 entries
	ob_db::store_qry ob_hist::AFFP_get_w_jrnl_id {
		select first 20
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
		    jrnl_id > ?
		and cr_date < ?
		and acct_id = ?
		and j_op_type = 'AFFP'
		order by
		    cr_date,
		    jrnl_id
	}

	# get a particular payment detail
	ob_db::store_qry ob_hist::AFFP_get_id {
		select
		   pmt_period_start,
		   pmt_period_end
		from
			tAffPmt
		where
			aff_pmt_id = ?
	}
}



#--------------------------------------------------------------------------
# Payment History Handler
#--------------------------------------------------------------------------

# Private procedure to handle payment type journal entries (WTD | DEP).
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
proc ob_hist::_AFFP args {

	set pmt_id [get_param j_op_ref_id]
	if {$pmt_id != ""} {
		return [_AFFP_id $pmt_id]
	} else {
		return [_journal_list AFFP ob_hist::AFFP_get \
			ob_hist::AFFP_get_w_jrnl_id]
	}
}



# Private procedure to get the payment details for a particular payment
# (details stored within the history package cache).
#
#   pmt_id  - payment identifier
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_AFFP_id { pmt_id } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {AFFP_HIST: pmt_id=$pmt_id}
	ob_log::write_array DEV ob_hist::PARAM

	# execute the query
	if {[catch {
		set rs [ob_db::exec_qry ob_hist::AFFP_get_id $pmt_id]
	} msg]} {
		ob_log::write ERROR {AFFP_HIST: $msg}
		return [add_err OB_ERR_HIST_AFFP_FAILED $msg]
	}

	# store data
	if {[db_get_nrows $rs] == 1} {

		# add history details
		set status [add_hist $rs 0 AFFP "" "" {amount}]
		if {$status == "OB_OK"} {

			if {[catch {

				# translate text?
				# NB: differs to add_hist method of translating text!
				if {$PARAM(xl_proc) != ""} {
					foreach c {payment_sort ref_key} {
						set HIST(0,xl_${c})\
						    [_XL "OB_AFFP_[string toupper $c]_$HIST(0,$c)"]
					}
				}

				set HIST(total) 1

			} msg]} {
				ob_log::write ERROR {AFFP_HIST: $msg}
				set status [add_err OB_ERR_HIST_AFFP_FAILED $msg]
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
ob_hist::_AFFP_init
