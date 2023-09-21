# $Id: click_and_buy.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Payment Functions for Click and Buy payment method
#
# Public procedures:
#
#  ob_clickandbuy::init                              - Initialises queries etc
#  ob_clickandbuy::insert_cpm                        - Insert a Click and Buy CPM
#  ob_clickandbuy::update_cpm                        - Update a Click and Buy CPM
#  ob_clickandbuy::insert_pmt                        - Insert a Click and Buy payment
#  ob_clickandbuy::mark_pmt_complete                 - Mark a Click and Buy payment as status 'Y'
#  ob_clickandbuy::mark_pmt_unknown                  - Mark a Click and Buy payment as status 'U'
#  ob_clickandbuy::mark_pmt_failed                   - Mark a Click and Buy payment as status 'N'
#  ob_clickandbuy::check_dep_confirmation            - Make a SOAP call to the TMI checking a pmt has been committed
#  ob_clickandbuy::send_easy_collect_wtd             - Make a SOAP call making a credit request to a customers C & B account
#  ob_clickandbuy::enc_token                         - Encrypt a token for sending in GET params
#  ob_clickandbuy::dec_token                         - Decrypt a token received in a GET param
#  ob_clickandbuy::send_pmt_ticker                   - Send a payment ticker for monitoring
#

#
# Dependancies (standard packages)
#
package require net_socket
package require tdom



namespace eval ob_clickandbuy {
	variable INIT
	set INIT 0
	variable CB_CFG
	variable PMT_DATA
	variable OB_PMT
	variable CPM_DATA
}



#
# One-time Initialisation Procedure
#
proc ob_clickandbuy::init {} {
	variable INIT
	variable CB_CFG
	variable PMT_DATA
	variable OB_PMT

	if {$INIT} { return }

	ob_log::write INFO {click_and_buy::init - Initialising Click And Buy}

	# Optional config items
	set optional_configs [list \
				cb_ccy_codes [list GBP EUR USD SEK NOK DKK CHF AUD CAD HKD] \
				api_timeout 10000]

	foreach {item dflt} $optional_configs {
		set CB_CFG($item) [OT_CfgGet "[string toupper $item]" $dflt]
		ob_log::write DEV "set CB_CFG($item) $CB_CFG($item)"
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CB_CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CB_CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CB_CFG(pmt_receipt_format) 0
		set CB_CFG(pmt_receipt_tag)    ""
	}

	# Hold information about an OpenBet Click and Buy payment
	array set CB_PMT_DATA [list]

	ob_clickandbuy::_prepare_CB_qrys

	set INIT 1
}



#
# Prepare queries
#
proc ob_clickandbuy::_prepare_CB_qrys args {
	global SHARED_SQL

	# Insert a Click and Buy customer payment method
	ob_db::store_qry ob_clickandbuy::insert_cpm {
		execute procedure pCPMInsClickAndBuy (
			p_cust_id        = ?,
			p_auth_dep       = ?,
			p_auth_wtd       = ?,
			p_transactional  = ?,
			p_cb_crn         = ?,
			p_cb_email       = ?
		)
	}

	# Insert a Click and Buy payment
	ob_db::store_qry ob_clickandbuy::insert_pmt {
		execute procedure pPmtInsCB (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_ipaddr         = ?,
			p_unique_id      = ?,
			p_source         = ?,
			p_status         = ?,
			p_cb_bdr_id      = ?,
			p_pg_acct_id     = ?,
			p_pg_host_id     = ?,
			p_oper_id        = ?,
			p_transactional  = ?,
			p_speed_check    = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?,
			p_overide_min_wtd= ?,
			p_call_id        = ?
	)
	}

	# Update the Click and Buy payment
	ob_db::store_qry ob_clickandbuy::update_pmt {
		execute procedure pPmtUpdCB (
			p_pmt_id     = ?,
			p_status     = ?,
			p_transactional = ?
		)
	}

	# Get a few specific details about a pmt
	ob_db::store_qry ob_clickandbuy::get_pmt {
		select
			p.acct_id,
			p.ipaddr,
			p.cpm_id,
			p.payment_sort,
			p.source,
			p.amount,
			c.cb_crn
		from
			tPmt p,
			tCPMClickAndBuy c
		where
			p.cpm_id = c.cpm_id and
			p.pmt_id = ?
	}

	# Store the customers Click and Buy id (first transaction only)
	ob_db::store_qry ob_clickandbuy::update_cpm {
		update
			tCPMClickAndBuy
		set
			cb_crn = ?
		where
			cpm_id = ?
	}

	# Suspend a Customer Payment Method
	ob_db::store_qry ob_clickandbuy::suspend_cpm {
		update tCustPayMthd set
			status     = 'S',
			status_dep = 'S',
			status_wtd = 'S',
			auth_dep   = 'N',
			auth_wtd   = 'N',
			oper_notes = ?,
			disallow_dep_rsn = ?,
			disallow_wtd_rsn = ?
		where
			cpm_id = ?
	}

	# Update a Click and Buy Payment attempt
	ob_db::store_qry ob_clickandbuy::upd_cb_pmt {
		execute procedure pPmtUpdCB (
			p_pmt_id     = ?,
			p_status     = ?,
			p_cb_bdr_id  = ?,
			p_extra_info = ?
		)
	}

	# Update a pmt with the Click and Buy id
	ob_db::store_qry ob_clickandbuy::upd_cb_bdr_id {
		update tPmtClickAndBuy set
			cb_bdr_id = ?
		where
			pmt_id = ?
	}

	# Updates the status of a payment (generic?)
	ob_db::store_qry ob_clickandbuy::upd_pmt_status {
		execute procedure pPmtUpdStatus (
			p_pmt_id         = ?,
			p_status         = ?
		)
	}

	# Get the details for a payment, it should only be
	# a deposit payment with a status of 'Unknown' in
	# this case
	ob_db::store_qry ob_clickandbuy::get_pmt_data {
		select
			a.cust_id,
			a.ccy_code,
			cpm.cpm_id,
			cpm.auth_dep,
			cpm.auth_wtd,
			cb.cb_crn,
			p.amount,
			p.payment_sort,
			p.status,
			p.ipaddr,
			cbp.cb_bdr_id
		from
			tAcct a,
			tCustomer c,
			tCustPayMthd cpm,
			tCPMClickAndBuy cb,
			tPmt p,
			tPmtClickAndBuy cbp
		where
			cpm.cpm_id = p.cpm_id and
			cpm.cpm_id = cb.cpm_id and
			c.cust_id = a.cust_id and
			a.cust_id = cpm.cust_id and
			p.pmt_id = cbp.pmt_id and
			p.payment_sort = ? and
			p.pmt_id = ? and
			p.status = 'U' and
			cpm.status = 'A'
	}

	# Get the gateway details from a pmt_id of
	# a given status
	ob_db::store_qry ob_clickandbuy::get_pmt_details {
		select
			a.cust_id,
			a.ccy_code,
			cpm.cpm_id,
			cpm.auth_dep,
			cpm.auth_wtd,
			cb.cb_crn,
			p.acct_id,
			p.amount,
			p.payment_sort,
			p.status,
			p.ipaddr,
			p.source,
			cbp.cb_bdr_id,
			cbp.pg_acct_id,
			cbp.pg_host_id
		from
			tAcct a,
			tCustomer c,
			tCustPayMthd cpm,
			tCPMClickAndBuy cb,
			tPmt p,
			tPmtClickAndBuy cbp
		where
			cpm.cpm_id = p.cpm_id and
			cpm.cpm_id = cb.cpm_id and
			c.cust_id = a.cust_id and
			a.cust_id = cpm.cust_id and
			p.pmt_id = cbp.pmt_id and
			p.payment_sort = ? and
			p.pmt_id = ? and
			p.status = ? and
			cpm.status = 'A'
	}

	# Update a customer's Payment Method 'auth_dep' to 'Y'
	ob_db::store_qry ob_clickandbuy::upd_cpm_auth_dep {
		update tCustPayMthd set
			auth_dep = 'Y'
		where
			cpm_id = ?
	}

	# Update a customer's Payment Method 'auth_wtd' to 'Y'
	ob_db::store_qry ob_clickandbuy::upd_cpm_auth_wtd {
		update tCustPayMthd set
			auth_wtd = 'Y'
		where
			cpm_id = ?
	}

	# Get the amount of transactions
	ob_db::store_qry ob_clickandbuy::get_cb_txn_count {
		select
			count(pmt_id) as txn_count
		from
			tPmt p
		where
			cpm_id = ? and
			payment_sort = ? and
			status = 'Y'
	}

	# Information required for MONITORs
	ob_db::store_qry ob_clickandbuy::get_monitor_info {
		select
			c.cust_id,
			c.cr_date as cust_reg_date,
			c.username,
			c.notifyable,
			c.country_code,
			cr.fname,
			cr.lname,
			cr.email,
			cr.code,
			cr.addr_city,
			cr.addr_postcode,
			cr.addr_country,
			a.balance,
			a.ccy_code,
			ccy.exch_rate,
			ccy.max_deposit,
			ccy.max_withdrawal,
			f.flag_value
		from
			tcustomer    c,
			tcustomerreg cr,
			tacct        a,
			tCcy         ccy,
			outer tCustomerFlag f
		where
		    a.acct_id   = ?
		and a.cust_id   = cr.cust_id
		and cr.cust_id  = c.cust_id
		and a.ccy_code  = ccy.ccy_code
		and f.cust_id   = c.cust_id
		and f.flag_name = 'trading_note'
	}

	ob_db::store_qry ob_clickandbuy::insert_status_flag {
		execute procedure pInsCustStatusFlag (
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_reason = ?,
			p_transactional = ?
		)
	}
}



#
#  ob_clickandbuy::insert_cpm
#
#  Insert a new Click and Buy customer payment method
#
#  cust_id    - Openbet customer id
#  cb_crn     - Click and Buy customer reference number
#  auth_dep   - deposit allow status
#  cb_email   - ClickandBuy registered customer email address
#  returns    - the cpm_id of the newly created method
#
proc ob_clickandbuy::insert_cpm {cust_id cb_crn auth_dep auth_wtd cb_email {transactional Y}} {

	ob_log::write INFO "ob_clickandbuy::insert_cpm: $cust_id $cb_crn $auth_dep $auth_wtd $transactional"

	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::insert_cpm $cust_id $auth_dep $auth_wtd $transactional $cb_crn $cb_email]} msg]} {
		ob_log::write ERROR {Error executing query ob_clickandbuy::insert_cpm - $msg}
		return [list 0 $msg]
	} else {
		set cpm_id [db_get_coln $rs 0 0]
		catch { ob_db::rs_close $rs }
		return [list 1 $cpm_id]
	}

}



#
#  ob_clickandbuy::update_cpm
#
#  Updates a CPM with, storing a cb_crn
#
#  cpm_id  - Openbet cpm_id
#  cb_crn  - Click and Buy customer reference number
#
#  returns - 1 on successfully storing cb_crn, else 0
#
proc ob_clickandbuy::update_cpm {cpm_id cb_crn} {

	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::update_cpm $cb_crn $cpm_id]} msg]} {
		ob_log::write ERROR {CB: ob_clickandbuy::update_cpm: Failed to store cb_crn, $cb_crn: $msg}
		catch { ob_db::rs_close $rs }
		return 0
	}

	ob_log::write DEBUG {CB: ob_clickandbuy::update_cpm: Stored cb_crn, $cb_crn for cpm_id, $cpm_id}
	return 1
}



#
#  ob_clickandbuy::update_pmt
#
#  Calls upd_pmt
#
#  pmt_id  - Openbet pmt_id
#  status  - Y,N,X etc
#
#  returns - 1 on successfully updating status, else 0
#
proc ob_clickandbuy::update_pmt {pmt_id status {transactional Y}} {

	# attempt to update the status
	if {[catch { set rs [ob_db::exec_qry ob_clickandbuy::update_pmt \
		$pmt_id \
		$status \
		$transactional]} msg]} {
		ob_log::write ERROR {CB: ob_clickandbuy::update_pmt: \
			Failed to update Click and Buy payment $cb_pmt_id to status $status, $msg}
		catch {	ob_db::rs_close $rs }
		return 0
	}

	ob_log::write DEBUG {CB: ob_clickandbuy::update_pmt: Updated status to, $status for pmt_id, $pmt_id}
	return 1
}

#
#  ob_clickandbuy::update_pmt_status
#
#  Updates a pmt status to whatever necessary
#
#  pmt_id  - Openbet pmt_id
#  status  - Y,N,X etc
#
#  returns - 1 on successfully updating status, else 0
#
proc ob_clickandbuy::update_pmt_status {pmt_id status {transactional Y}} {

    # attempt to update the status
	    if {[catch { set rs [ob_db::exec_qry ob_clickandbuy::upd_pmt_status \
			$pmt_id \
			$status \
			$transactional]} msg]} {
		        ob_log::write ERROR {CB: ob_clickandbuy::update_pmt_status: \
					Failed to update Click and Buy payment $cb_pmt_id to status $status, $msg}
				catch { ob_db::rs_close $rs }
				return 0
			}
		ob_log::write DEBUG {CB: ob_clickandbuy::update_pmt_status: Updated status to, $status for pmt_id, $pmt_id}
		return 1
}


#
#  ob_clickandbuy::insert_pmt
#
#  Insert a new Click and Buy payment into tPmt with correct merchant account details.
#
#  acct_id       - the customers account ID
#  cpm_id        - the customers customer payment method ID
#  payment_sort  - either DEP/WTD
#  amount        - the payment amount
#  ipaddr        - the ipaddr of the user who made the payment
#  source        - the Channel source of the payment
#  unique_id     - a ID value that uniquely idenitifies an OpenBet payment
#  cb_bdr_id     - Click and Buy unique reference for the pmt
#  ccy_code      - The customers OpenBet Currency Code
#  transactional - determines if the execution of the stored procedure
#                  is transactional/not
#  oper_id       - The Admin operator ID (if admin user adds the payment)
#
# # min_overide            - overide the minimum withdrawal limit should only be used when
#                           multiple method withdrawal flow forces
#  call_id       - (optional) if this is a telebetting transaction, the tCall.call_id for this
#  returns       -  a list [0 error_msg] on failure on payment insertion,
#                   [1 pmt_id pg_acct_id] otherwise
#
proc ob_clickandbuy::insert_pmt {acct_id cpm_id payment_sort amount status ipaddr
									source unique_id cb_bdr_id ccy_code \
									{transactional N} {oper_id ""} {min_overide "N"} {call_id ""}} {

	variable PMT_DATA
	variable CB_CFG

	catch {array unset PMT_DATA}

	ob_log::write INFO {ob_clickandbuy::insert_pmt($acct_id,$cpm_id,$payment_sort,$amount,$status,$ipaddr,$unique_id,$source,$ccy_code,$transactional, $oper_id, $min_overide,$call_id)}

	# set some value for filters prior to evaluating the PMG rules
	set PMT_DATA(pay_sort) $payment_sort
	set PMT_DATA(ccy_code) $ccy_code
	set PMT_DATA(pay_mthd) "CB"
	set PMT_DATA(source)   $source
	set PMT_DATA(acct_id)  $acct_id
	set PMT_DATA(amount)   $amount

	# CC ones. set these as blank
	set PMT_DATA(country)        ""
	set PMT_DATA(card_type)      ""
	set PMT_DATA(card_scheme)    ""
	set PMT_DATA(bank)           ""
	set PMT_DATA(card_bin)       ""
	set PMT_DATA(hldr_name)      ""

	# get the Click and Buy payment gateway acct details based on currency.
	if {[ob_clickandbuy::_get_pmg_params $ccy_code] != 1} {
	 	return [list 0 "CB_FAILED_PMG_RULES"]
	}

	# Useful during debugging to be able to do lots of payments.
	if {[OT_CfgGet DISABLE_PMT_SPEED_CHECK 0] == "Y"} {
		set speed_check N
		ob_log::write INFO "DISABLING SPEED CHECK"
	} else {
		set speed_check Y
	}

	#
	# Attempt to insert the payment
	#
	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::insert_pmt \
				$acct_id \
				$cpm_id \
				$payment_sort \
				$amount \
				$ipaddr \
				$unique_id \
				$source \
				$status \
				$cb_bdr_id \
				$PMT_DATA(pg_acct_id) \
				$PMT_DATA(pg_host_id) \
				$oper_id \
				$transactional \
				$speed_check \
				$CB_CFG(pmt_receipt_format) \
				$CB_CFG(pmt_receipt_tag) \
				$min_overide \
				$call_id ]} msg]} {
		ob_log::write ERROR {ob_clickandbuy::insert_pmt Failed to insert ob_clickandbuy - $msg}

		# Use PMG code to transform error into human readable form
		set err [payment_gateway::cc_pmt_get_sp_err_code $msg]

		return [list 0 $err]
	} else {
		# Successful insertion of pmt
		set pmt_id [db_get_coln $rs 0 0]
		catch { ob_db::rs_close $rs }

		# Now that we've inserted the payment we may also have to record the payment's source
		if {[OT_CfgGet ADD_TXN_POINT 0] == 1} {
			if {[catch {set res [txn_point::insert_pmt_flag $pmt_id "point of deposit"]} msg]} {
				ob_log::write ERROR "ob_clickandbuy::insert_pmt: ERROR, Could not insert point of deposit $msg"
			}
		}

		# Send monitor message if monitors are configured on
		if {[OT_CfgGet MONITOR 0]} {
			array set PMT [list \
					   type         CB \
					   acct_id      $acct_id \
					   ipaddr       $ipaddr \
					   cpm_id       $cpm_id \
					   payment_sort $payment_sort \
					   source       $source \
					   amount       $amount
				       ]
			set pmt_date [clock format [clock seconds] -format {%Y-%m-%d %T}]
			ob_clickandbuy::_send_pmt_ticker $pmt_id $pmt_date $status PMT
		}
		return [list 1 $pmt_id $PMT_DATA(host)]
	}
}



#
#  ob_clickandbuy::mark_pmt_complete
#
#  Marks a payment as successful, updating status to 'Y'
#
#  type              - Sort of payment involved (Withdrawal/Deposit)
#  pmt_id            - OpenBet ID of the payment
#  enc_transfer_args - Blowfish encrypted details on which wallet to transfer to (only needed for deposits)
#
#  returns           - 1 if things went good, 0 if bad
#
proc ob_clickandbuy::mark_pmt_complete {type pmt_id {enc_transfer_args ""} {oper_id ""} {transactional N}} {

	ob_log::write DEBUG {CB: ob_clickandbuy::mark_pmt_complete: $type,$pmt_id, $enc_transfer_args, $oper_id, $transactional}

	variable CB_PMT_DATA

	ob_clickandbuy::_get_pmt_data $type $pmt_id "U"

	# sanity check, just in case it never got through the initial stage of OpenBet verification
	if {$CB_PMT_DATA(cb_bdr_id) == ""} {
		ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: No Click and Buy transaction id, not a valid payment.}
		return 0
	}

	# switch statement here caters for first time 'type' attempt on a particular CPM
	switch -exact $type {
		"D" {
			# if the customers auth_dep status is P(ending) update it
			if {$CB_PMT_DATA(auth_dep) == "P"} {

				# update customers Payment Method so deposits are authorised
				if {[catch [ob_db::exec_qry ob_clickandbuy::upd_cpm_auth_dep $CB_PMT_DATA(cpm_id)] msg]} {
					ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: Failed to update customers payment method auth_dep:  $msg}
					return 0
				}
			}
		}
		"W" {
			# attempting to finalise a withdrawal

			# if the customers auth_wtd status is pending ....
			if {$CB_PMT_DATA(auth_wtd) == "P"} {

				# get the number of successful withdrawal transactions with this CPM
				if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::get_cb_txn_count $CB_PMT_DATA(cpm_id) $CB_PMT_DATA(payment_sort)]} msg]} {
					ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: Failed to get txn count for cpm_id $CB_PMT_DATA(cpm_id): $msg}
					return 0
				}

				if {[db_get_nrows $rs] != 1} {
					ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: Invalid rows returned when getting txn count for cpm_id $CB_PMT_DATA(cpm_id)}
					catch { ob_db::rs_close $rs }
					return 0
				}

				set txn_count [db_get_col $rs 0 txn_count]
				catch { ob_db::rs_close $rs }

				# if the customer had no previously successful withdrawals on this CPM try and
				# update their auth_wtd status to 'Y'
				if {$txn_count == 0} {
					if {[catch [ob_db::exec_qry ob_clickandbuy::upd_cpm_auth_wtd $CB_PMT_DATA(cpm_id)] msg]} {
						ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: Failed to update customers payment method wtd_status, $msg}
						return 0
					}
				}
			}
		}
		default {
			ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: Unknown payment sort $payment_sort}
			return 0
		}
	}

	# attempt to update the transaction
	if { ![ob_clickandbuy::update_pmt $pmt_id Y] } {
		ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete: \
			Failed to update Click and Buy payment $pmt_id, $msg}
		return 0
	}

	# If we've just completed a deposit we may need to transfer the money to another
	# one of this customers accounts.
	if {$type == {D} && [OT_CfgGet CB_ACCT_TRANSFERS 0]} {

		# Decrypt the acct transfer parameter
		set token_ret [ob_clickandbuy::dec_token $enc_transfer_args]
		switch -- [lindex $token_ret 0] {
			OK {
				set param [lindex $token_ret 1]
				# check the format should be cust_id|password|acct to transfer to
				if {[regexp {^([0-9]+)\|(.+)\|(.+)$} $param all cust_id password acct]} {
					foreach p [list cust_id password acct] {
						set CB_PMT_DATA(transfer,$p) [set $p]
					}
					set CB_PMT_DATA(transfer,transfer_ok) 1

				} else {
					ob_log::write ERROR {ob_clickandbuy::mark_pmt_complete - enc_token failed format check}
					return 0
				}
			}
			ERROR -
			default {
				return 0
			}
		}

		foreach p [list cust_id password acct] {
			set $p $CB_PMT_DATA(transfer,$p)
		}

		# The account that the money is now in and
		# that we intend to transfer from
		set base_acct {SPORTS}

		if {$acct != $base_acct} {

			# Use some values from the db
			set ipaddr   $CB_PMT_DATA(ipaddr)
			set amount   $CB_PMT_DATA(amount)
			set ccy_code $CB_PMT_DATA(ccy_code)

			ob_log::write INFO {ob_clickandbuy::mark_pmt_complete: Attempting to transfer money for cust_id, $cust_id to acct, $acct}

			#
			# If the transfer fails its not the end of the world as the money has been
			# removed from the customers Click and Buy account and will still exist in
			# the 'base_acct'
			#
			if {[catch {

				# Unfortunately the following requires customer specific code...
				ob_amt::set_trans_amount $base_acct $amount $ccy_code

				set ret [ob_cashier::acct_transfer $cust_id $base_acct $acct $password $ipaddr]

				# Don't think we care much about the result of this transfer
				# If the money gets transfered then great, otherwise its just sitting
				# in the 'base_acct'.
				if {[lindex $ret 0]} {
					ob_log::write INFO {Successful transfer from $base_acct to $acct}
				} else {
					ob_log::write ERROR {Failed transfer from $base_acct to $acct}
				}

			} msg]} {

				ob_log::write ERROR {Failed transfer for cust_id=$cust_id from $base_acct to $acct (pmt_id, $pmt_id; cb_bdr_id, $CB_PMT_DATA(cb_bdr_id))}
				ob_log::write ERROR {$msg}

			}

		} else {
			ob_log::write INFO {No need to transfer from $base_acct to $acct}
		}
	}

	if {[OT_CfgGet MONITOR 0]} {
		ob_clickandbuy::send_pmt_ticker $pmt_id Y
	}

	return 1
}



#
#  ob_clickandbuy::mark_pmt_unknown
#
#  Marks a payment as unknown
#
#  payment_sort - Sort of payment involved (Withdrawal/Deposit)
#  pmt_id       - The ID of the payment
#  cb_bdr_id    - The Click and Buy Transaction ID (Only for deposits)
#
#  returns      - 1 if things went good, 0 if bad
#
proc ob_clickandbuy::mark_pmt_unknown {payment_sort pmt_id {cb_bdr_id ""}} {

	ob_log::write INFO {CB: ob_clickandbuy::mark_cb_pmt_unknown $payment_sort, $pmt_id, $cb_bdr_id}

	if {$payment_sort == "D"} {
		if {$cb_bdr_id != ""} {
			# Store the cb_bdr_id for the transaction
			if {[catch [ob_db::exec_qry ob_clickandbuy::upd_cb_bdr_id $cb_bdr_id $pmt_id ] msg]} {
				ob_log::write ERROR {CB: ob_clickandbuy::mark_cb_pmt_unknown: Failed to store cb_bdr_id, $cb_bdr_id for pmt_id, $cb_pmt_id, $msg}
				return 0
			}
		} else {
			ob_log::write ERROR {CB: ob_clickandbuy::mark_cb_pmt_unknown: Failed to store cb_bdr_id, cannot have blank cb_bdr_id for deposits!}
			return 0
		}
	}

	# attempt to update the status
	if {[ob_clickandbuy::update_pmt_status $pmt_id "U"] == 0} {
		return 0
	} else {
		return 1
	}

}



#
#  ob_clickandbuy::mark_pmt_failed
#
#  Marks a payment as bad and scratches the customers
#  Click and Buy customer payment method if it's their first deposit
#  attempt
#
#  payment_sort - Sort of payment involved (Withdrawal/Deposit)
#  pmt_id       - The ID of the payment
#  cb_crn       - Click and Buy unique id
#  extra_info   - reason the payment failed
#
#  returns      - 1 if things went good, 0 if bad
#
proc ob_clickandbuy::mark_pmt_failed {payment_sort pmt_id cb_crn {extra_info ""} {suspend_cpm 0} {cust_id {}}} {

	ob_log::write INFO {CB: ob_clickandbuy::mark_pmt_failed $payment_sort, $pmt_id, $cb_crn}

	# Double check we are being sensible and the pmt_id and the cb_crn match up
	# Get the cpm_id from the pmt_id
	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::get_pmt $pmt_id]} msg]} {
		ob_log::write ERROR {CB: ob_clickandbuy::mark_pmt_failed: Failed to get cpm_id from pmt_id $pmt_id, $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR {ob_clickandbuy::mark_pmt_failed: Invalid rows returned when getting details for pmt_id $pmt_id}
		catch {  ob_db::rs_close $rs }
		return 0
	}

	set cpm_id     [db_get_col $rs 0 cpm_id]
	set pmt_cb_crn [db_get_col $rs 0 cb_crn]

	if {$cb_crn != "" && $cb_crn != $pmt_cb_crn} {
		# If the cb_crn to cancel against isn't the same as the cb_crn the pmt was
		# inserted with we want to bail out
		ob_log::write ERROR {ob_clickandbuy::mark_pmt_failed: The cb_crn, $cb_crn doesnt match that for the pmt (cb_crn - $pmt_cb_crn)}
		return 0
	}

	catch { ob_db::rs_close $rs }

	if {$payment_sort == "D" && $suspend_cpm} {
		# Suspend customers Click and Buy Payment Method and put status flags on the account

		set suspend_reason "Duplicate Payer ID"
		set oper_notes "Duplicate Payer ID found on another account"

		if {[catch {
			ob_db::exec_qry ob_clickandbuy::insert_status_flag $cust_id "DEP" $oper_notes "N"
			ob_db::exec_qry ob_clickandbuy::insert_status_flag $cust_id "WTD" $oper_notes "N"

			ob_db::exec_qry ob_clickandbuy::suspend_cpm \
			                                $oper_notes \
			                                $suspend_reason \
			                                $suspend_reason \
			                                $cpm_id
		} msg]} {
			ob_log::write ERROR {CB: ob_clickandbuy::mark_pmt_failed: Failed to scratch users Click and Buy CPM $cpm_id, $msg}
			return 0
		}
	}

	# This was a bad pmt, we dont have a bdr_id to update with
	set cb_bdr_id ""
	# attempt to update the transaction if all went well in the previous code block
	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::upd_cb_pmt $pmt_id N $cb_bdr_id $extra_info]} msg]} {
		ob_log::write ERROR {CB: ob_clickandbuy::mark_pmt_failed: Failed to update Click and Buy payment $pmt_id, $msg}
		catch {	ob_db::rs_close $rs }
		return 0
	}

	if {[OT_CfgGet MONITOR 0]} {
		ob_clickandbuy::send_pmt_ticker $pmt_id N
	}

	return 1
}



#
#  ob_clickandbuy::mark_pmt_cancelled
#
#  Sets a payments status to 'X'. Called by the cb payment scratcher cron
#
#  pmt_id   - Openbet pmt_id to mark as cancelled
#
#  returns  - 1 if successful, else 0
proc ob_clickandbuy::mark_pmt_cancelled {pmt_id status {extra_info ""}} {

	ob_log::write INFO {CB: ob_clickandbuy::mark_pmt_cancelled $pmt_id, $status}

	# attempt to update the transaction if all went well in the previous code block
	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::upd_cb_pmt $pmt_id $status "" $extra_info]} msg]} {
		ob_log::write ERROR {CB: ob_clickandbuy::mark_pmt_cancelled: Failed to mark Click and Buy payment $pmt_id, $msg as cancelled}
		catch {	ob_db::rs_close $rs }
		return 0
	}
}



#
#  ob_clickandbuy::check_dep_confirmation
#
#  Sends a SOAP message to the Click and Buy TMI checking that the payment
#  has been committed at their end. Updates a payments status dependend on
#  the result of the call
#
#  pmt_id            - Openbet pmt_id from the payment redirect
#  cb_crn            - cb_crn from the payment redirect
#  enc_transfer_args - args for transfering to casino accounts etc
#
#  returns           - 1 if successful, [0 error] otherwise
#
proc ob_clickandbuy::check_dep_confirmation {pmt_id cb_crn {enc_transfer_args ""}} {

	ob_log::write INFO {ob_clickandbuy::check_dep_confirmation: pmt_id, $pmt_id, cb_crn, $cb_crn, enc_transfer_args, $enc_transfer_args}

	variable CB_PMT_DATA

	# Init things here as this gets called directly from crons
	ob_clickandbuy::init

	# Query the db via the pmt_id to get values to populate the PMT_DATA array
	if {[ob_clickandbuy::_get_pmt_data "D" $pmt_id "U"] == 0} {
		ob_log::write ERROR {ob_clickandbuy::check_dep_confirmation: Couldn't get payment details for pmt, $pmt_id}
		return [list 0 "CB_ERROR" "U"]
	}

	# Build up the isExternalBDRIDCommitted Click and Buy TMI request
	set soap_request [ob_clickandbuy::_build_isExternalBDRIDCommitted $CB_PMT_DATA(merchant_id) $CB_PMT_DATA(key) $pmt_id]

	# send the request to Click and Buy TMI URL
	ob_log::write DEBUG {ob_clickandbuy::check_dep_confirmation: sending request:\n\n $soap_request \n\nto: $CB_PMT_DATA(host_second)}
	set soap_response [ob_clickandbuy::_send_request $CB_PMT_DATA(host_second) $CB_PMT_DATA(conn_timeout) $soap_request]

	# get and check the outcome of the response
	set response_outcome [lindex $soap_response 0]
	set response_xml     [lindex $soap_response 1]
	if {$response_outcome == 0} {
		ob_log::write ERROR {ob_clickandbuy::check_dep_confirmation: Got an invalid response, $response_xml}
		return [list 0 "CB_ERROR" "U"]
	}

	# grab the info needed from the response, the result will be of the form {1 {isCommitted true}}
	set result [_parse_response $response_xml "isExternalBDRIDCommittedResponse" [list "return" "isCommitted"] "TransactionManager.Status.StatusException"]

	ob_log::write DEBUG {ob_clickandbuy::check_dep_confirmation: Result of parsing reply is $result}

	switch [lindex $result 0] {
		"1" {
			# SOAP call was made successfully, check if the reply is 'true' or '1'
			if {[string map {true 1} [lindex [lindex $result 1] 1]] == 1} {
				# Payment is good, update staus to good, 'Y'
				ob_clickandbuy::mark_pmt_complete D $pmt_id $enc_transfer_args

				return [list 1 "success" "Y"]
			} else {
				# Payment isn't committed at Click and Buy's end (but they recognise the pmt_id) mark bad
				ob_clickandbuy::mark_pmt_failed D $pmt_id $cb_crn

				return [list 0 "CB_ERROR" "N"]
			}
		}
		"0" {
			# There was an error somewhere in the process
			if {[lindex $result 2] == "BDRIDNotFound"} {
				# Click and Buy know nothing about the pmt_id
				ob_clickandbuy::mark_pmt_failed D $pmt_id $cb_crn

				return [list 0 "CB_ERROR" "N"]
			} else {
				# Leave this as Unknown, couldn't tell for sure it is not committed
				ob_log::write ERROR "ob_clickandbuy::check_dep_confirmation: parsing produced the error [lindex $result 1]"
				return [list 0 "CB_ERROR" "U"]
			}
		}
	}
}



#
#  ob_clickandbuy::send_easy_collect_wtd
#
#  Performs a withdrawal to a customers Click and Buy account from.
#
#  Sends a credit request SOAP message to the Click and Buy TMI with a customers
#  cb_crn details to transfer money from the merchant account into their Click and Buy
#  account.
#
#  pmt_id  - Openbet pmt_id
#  status  - the status of the payment, can be either H(eld) or U(nknown)
#
#  returns - 1 if success, [0 error] otherwise
#
proc ob_clickandbuy::send_easy_collect_wtd {pmt_id status {auth_pending_wtd "0"} } {
	variable CB_PMT_DATA

	ob_log::write DEBUG {ob_clickandbuy::send_easy_collect_wtd pmt_id, $pmt_id ,$auth_pending_wtd}
	# Init things here as this gets called directly from crons
	ob_clickandbuy::init

	# Get the payment details to work with
	if {![_get_pmt_data "W" $pmt_id $status]} {
		return [list 0 INVALID_PMT]
	}

	if {!$auth_pending_wtd} {
		set process_pmt [ob_pmt_validate::chk_wtd_all\
			$CB_PMT_DATA(acct_id)\
			$pmt_id\
			"CB"\
			"----"\
			$CB_PMT_DATA(amount)\
			$CB_PMT_DATA(ccy_code)]

		if {!$process_pmt} {
			# We will need to check the payment for potential fraud or dealy the
			# payment before it is processed
			# For now we will return that it was successful
			return [list 0 "OK"]
		}
	}

	# Update the amount to be in pence/cents
	set CB_PMT_DATA(amount) [expr int ([expr $CB_PMT_DATA(amount) * 100])]

	# We are now processing a payment, update the status if necessary
	set upd_pmt_res [ob_clickandbuy::mark_pmt_unknown "W" $pmt_id]

	if {!$upd_pmt_res} {
		return [list 0 "Failed to mark the payment as unknown"]
	} else {
		set CB_PMT_DATA(status) "U"
	}

	# Build up the request to send to Click and Buy
	set soap_request [ob_clickandbuy::_build_getEasyCollectSingle\
		$CB_PMT_DATA(merchant_id)\
		$CB_PMT_DATA(key)\
		$CB_PMT_DATA(cb_crn)\
		$CB_PMT_DATA(mid)\
		$pmt_id\
		$CB_PMT_DATA(amount)\
		$CB_PMT_DATA(ccy_code)]

	# send the request to Click and Buy TMI
	ob_log::write DEBUG {ob_clickandbuy::send_easy_collect_wtd: sending request:\n\n $soap_request \n\nto: $CB_PMT_DATA(host_second)}
	set soap_response [ob_clickandbuy::_send_request $CB_PMT_DATA(host_second) $CB_PMT_DATA(conn_timeout) $soap_request]

	# get and check the outcome of the response
	set response_outcome [lindex $soap_response 0]
	set response_xml     [lindex $soap_response 1]

	set ret [ob_clickandbuy::_parse_response $response_xml "getEasyCollectSingleResponse" [list "credResp" "BDRID"] "TransactionManager.Payment.PaymentException"]

	# A response_outcome of 0 is a socket connection failure, otherwise we have a error response from Click and Buy
	if {$response_outcome == 0 || [lindex $ret 0] == 0} {
		ob_log::write DEBUG {ob_clickandbuy::send_easy_collect_wtd: Got an invalid response, $response_xml}

		ob_clickandbuy::mark_pmt_failed "W" $pmt_id $CB_PMT_DATA(cb_crn)

		if {[OT_CfgGet CB_WTD_FAIL_EMAIL 0]} {
			# Send an email letting someone know this has failed
			set email_from    [ob_xl::sprintf "en" "CB_WTD_FAIL_EMAIL_FROM"]
			set email_to      [ob_xl::sprintf "en" "CB_WTD_FAIL_EMAIL_TO"]
			set email_subject [ob_xl::sprintf "en" "CB_WTD_FAIL_EMAIL_SUBJECT $pmt_id"]
			set email_body    [ob_xl::sprintf "en" "CB_WTD_FAIL_EMAIL_MSG" $pmt_id $CB_PMT_DATA(cpm_id) $CB_PMT_DATA(cb_crn) [lindex $ret 2]]
			if {[catch {ob_email::send_email $email_from $email_to $email_subject {} $email_body} msg]} {
				ob_log::write ERROR {ob_clickandbuy::send_easy_collect_wtd: Failed to send notification email for unsuccessful Click and Buy withdrawal, pmt_id, $pmt_id: $msg}
			} else {
				ob_log::write INFO {ob_clickandbuy::send_easy_collect_wtd: Email for failed Click and Buy withdrawal successfully sent}
			}
		}

		return [list 0 "[lindex $ret 2]"]
	}

	if {[lindex $ret 0] == 1 && [lindex $ret 1] != ""} {
		# Update tPmtClickAndBuy with the cb_bdr_id
		set cb_bdr_id [lindex [lindex $ret 1] 1]
		if {[catch [ob_db::exec_qry ob_clickandbuy::upd_cb_bdr_id $cb_bdr_id $pmt_id ] msg]} {
			ob_log::write ERROR {CB: ob_clickandbuy::send_easy_collect_wtd: Failed to store cb_bdr_id, $cb_bdr_id for pmt_id, $cb_pmt_id, $msg}
			return [list 0 "Withdrawal failed, couldn't store cb_bdrid"]
		}

		# Update the payment status to good
		ob_clickandbuy::mark_pmt_complete "W" $pmt_id

		return [list 1 "Withdrawal was successful"]

	} else {
		# We haven't been able to do anything useful with out response, leave things the way they are (payment_status 'U')
		ob_log::write ERROR {CB: ob_clickandbuy::send_easy_collect_wtd: Failed to parse response from SOAP call, payment status remains as 'U'}

		return [list 1 "Invalid response from Click and Buy, withdrawal remains unknown"]
	}

	return [list 1 ""]
}



#
#  ob_clickandbuy::enc_token
#
#  Encrypt a token for sending to Click and Buy in a URL
#
#  str     - plaintext string
#
#  returns - Blowfish encrypted str
#
proc ob_clickandbuy::enc_token { str } {
	if {[OT_CfgGet DECRYPT_KEY {}] != {}} {
		set key_encode -bin
		set key [OT_CfgGet DECRYPT_KEY]
	} else {
		set key_encode -hex
		set key [OT_CfgGet DECRYPT_KEY_HEX]
	}
	return [blowfish encrypt $key_encode $key -bin $str]
}



#
#  ob_clickandbuy::dec_token
#
#  Decrypt the token we get from a Click and Buy URL
#
#  token   - Blowfish encrypted string
#
#  returns - plaintext version of token
#
proc ob_clickandbuy::dec_token { str } {
	if {[OT_CfgGet DECRYPT_KEY {}] != {}} {
		set key_encode -bin
		set key [OT_CfgGet DECRYPT_KEY]
	} else {
		set key_encode -hex
		set key [OT_CfgGet DECRYPT_KEY_HEX]
	}

	return [hextobin [blowfish decrypt $key_encode $key -hex $str]]

}



#
#  ob_clickandbuy::get_cfg
#
#  Gets a Click and Buy configuration items details
#
#  cfg_item - the required Click and Buy config item
#
#  returns - the value of the Click and Buy config item
#
proc ob_clickandbuy::get_cfg { cfg_item } {
	variable CB_CFG
	return $CB_CFG($cfg_item)
}



#
#  ob_clickandbuy::send_pmt_ticker
#
#  Grab pmt details and send a payment ticker message.
#
#  pmt_id - the pmt to send details of
#  status - the status of the payment
#
proc ob_clickandbuy::send_pmt_ticker { pmt_id status } {
	ob_log::write DEBUG {ob_clickandbuy::send_monitor_msg($pmt_id,$status)}

	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::get_pmt $pmt_id]} msg]} {
		ob_log::write ERROR {Error executing ob_clickandbuy::get_pmt - $msg}
	} else {
		set nrows [db_get_nrows $rs]

		if {$nrows == 1} {

			set cols [db_get_colnames $rs]

			foreach c $cols {
				set PMT($c) [db_get_col $rs 0 $c]
			}
			set PMT(type) CB

			ob_clickandbuy::_send_pmt_ticker $pmt_id [clock format [clock seconds] -format {%Y-%m-%d %T}] $status PMT
		} else {
			ob_log::write ERROR {Can't find payment with pmt_id=$pmt_id}
		}

		catch { ob_db::rs_close $rs }
	}
}



########################################### PRIVATE PROCEDURES #######################################################


#
#  ob_clickandbuy::_get_pmt_data
#
#  Grabs OpenBet info on the payment attempt and stores
#  the collected data in 'CB_PMT_DATA'
#
#  type    - type of payment, D/W
#  pmt_id  - Openbet pmt_id to get details for
#  status  - status of the pmt
#
#  Returns - 1 on success, else 0 and an error code
#
proc ob_clickandbuy::_get_pmt_data {type pmt_id status} {

	variable CB_PMT_DATA

	if {[catch {set rs [ob_db::exec_qry ob_clickandbuy::get_pmt_details \
				$type \
				$pmt_id \
				$status]} msg]} {
		ob_log::write ERROR {ob_clickandbuy::_get_pmt_data: Failed to get payment details for pmt_id, $pmt_id: $msg}
		return 0
	}

	# Check if correct row amount is returned
	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_log::write ERROR {ob_clickandbuy::_get_pmt_data: Invalid number of rows returned while getting payment info on pmt_id, $pmt_id}
		return 0
	}

	# Fill the 'CB_PMT_DATA' variable with the data obtained from OpenBet on the payment
	set cols [db_get_colnames $rs]
	foreach col $cols {
		set CB_PMT_DATA($col) [db_get_col $rs 0 $col]
	}

	# Payment Gateway Details
	set ret [payment_gateway::pmt_gtwy_get_pmt_pg_params\
		CB_PMT_DATA\
		$pmt_id\
		$CB_PMT_DATA(pg_acct_id)\
		$CB_PMT_DATA(pg_host_id)]

	foreach {r err} $ret {break}
	if {$r == 0} {
		ob_log::write ERROR {ob_clickandbuy::_get_pmt_data: $err}
	}

	return $r

}

#
# Get pmt gateway parameters for a given request.
#
proc ob_clickandbuy::_get_pmt_gateway_params {} {

	variable CB_PMT_DATA


	ob_log::write INFO {ob_clickandbuy::get_pmt_gateway_params}

	# some value required by the pmt gateway code
	set CB_PMT_DATA(pay_mthd) {CB}

	# Get the correct payment gateway details for this payment
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param CB_PMT_DATA]

	# cater for PMG error
	if {![lindex $pg_result 0]} {
		ob_log::write ERROR {ob_clickandbuy::get_pmt_gateway_params: failed to get pmt gateway details - [lindex $pg_result 1]}
		return 0
	}

	return 1
}

#
#  ob_clickandbuy::_send_request
#
#  Send a Click and Buy SOAP request to Click and Buy's TMI
#
#  url          - URL to send the SOAP request to
#  conn_timeout - timeout for connecting
#  xml          - A string that contains the Click and Buy SOAP request
#
#  returns      - a list, on success : [1 clickandbuy_response],
#                 [0  CB_REQ_ERROR] otherwise
#
proc ob_clickandbuy::_send_request {url conn_timeout xml} {
	variable PMT_DATA
	variable CFG

	# Figure out the connection settings for this API.
	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {ob_clickandbuy::_send_request: Bad API URL, $msg}
		return [list 0 "CB_REQ_ERROR"]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "POST" \
		           -post_data  $xml \
		           -headers    [list "Content-Type" "text/xml"] \
		           $url]
	} msg]} {
		ob_log::write ERROR {ob_clickandbuy::_send_request: Bad request, $msg}
		return [list 0 "CB_REQ_ERROR"]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	if {$api_scheme == "http"} {
		set tls -1
	} else {
		set tls {}
	}

	# Send the request to the Click and Buy url.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $conn_timeout \
		    -req_timeout  $conn_timeout \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob_log::write ERROR {ob_clickandbuy::_send_request: send_req failed, $msg}
		return [list 0 "CB_REQ_ERROR"]
	}

	if {$status == "OK"} {

		# Request successful - get and return the response data.
		set xml_response [::ob_socket::req_info $req_id http_body]

		ob_log::write DEBUG {ob_clickandbuy::_send_request: Response is: $xml_response}

		::ob_socket::clear_req $req_id

		return [list 1 $xml_response]

	} else {

		::ob_socket::clear_req $req_id

		ob_log::write ERROR {ob_clickandbuy::_send_request: Got bad status response from request, $status}
		return [list 0 "CB_REQ_ERROR"]

	}

}



#
#  ob_clickandbuy::_parse_response
#
#  Parses and processes the response obtained from a Click and Buy request
#
#  response          - the response sent back from Click and Buy (in XML)
#  tmi_response_elem - The element to look for when processing the response
#                      that's specific to the request itself (and hence get specific
#                      info from)
#  required_data     - This contains a list of Parent Elements, Child Elements pairs that would
#                      be expected to get values for from a request. This varies according to the
#                      request type ('REQUIRED_TD_DATA' for TransactionDetails etc ...)
#  error_sort        - The element that will contain the useful error information if the request failed
#
#  returns           - a list, [1 response info] on a successful valid response, [0 error info] otherwise
#
proc ob_clickandbuy::_parse_response {response tmi_response_elem required_data error_sort} {
	variable response_data

	# attempt to pass the response into DOM
	if {[catch {set doc [dom parse $response]} msg]} {
		ob_log::write ERROR {Unable to parse XML response, $msg}
		catch {$doc delete}
		return [list 0 $msg]
	}

	# ok, we have the response
	set xml [$doc documentElement]

	# grab the Core response elements in the SOAP Body
	set response_node [[$xml selectNodes "/SOAP-ENV:Envelope/SOAP-ENV:Body"] firstChild]

	# check if the response element matches what we expect to get for this TMI call
	if {[string first $tmi_response_elem [$response_node nodeName]] == -1} {
		ob_log::write ERROR {ob_clickandbuy::_parse_response: Element mismatch, did not get $tmi_response_elem in response}
	}

	# look for any errors given in the response (defined within the 'Errors' node)
	set errors_node [$response_node getElementsByTagName "detail"]

	# if an error has been given, process that element and get
	# more info on the Error, then return the appropriate Error
	if {$errors_node != ""} {
		set ret [ob_clickandbuy::_get_response_error $errors_node $error_sort]
		ob_clickandbuy::_destroy_message $doc
		ob_log::write ERROR {ob_clickandbuy::_parse_response: SOAP call failed with reason - $ret}
		return [list 0 "CB_ERROR" $ret]
	}

	# Get the details from the response
	set response [ob_clickandbuy::_get_response_details $response_node $required_data]

	if {[llength $response] == 0} {
		ob_log::write ERROR {ob_clickandbuy::_parse_response: Invalid detailed response obtained, $response (length:[llength $response])}
		return [list 0 "CB_NO_DATA_FOUND"]
	}

	# We have a list of lists...
	foreach resp $response {

		set response_len [llength $resp]

		# Since we're expecting a list of Element name, Element value pairs
		# we must ensure that the list returned is in valid format
		if {$response_len == 0 || ($response_len % 2)} {
			ob_clickandbuy::_destroy_message $doc
			ob_log::write ERROR {ob_clickandbuy::_parse_response: Invalid detailed response obtained, $resp (length:$response_len)}
			return [list 0 "CB_INVALID_RESPONSE"]
		}
	}

	ob_clickandbuy::_destroy_message $doc

	# things look good, return the reponse data (concat to split 'response' into its component lists)
	return [concat 1 $response]
}



#
#  ob_clickandbuy::_get_response_details
#
#  This processes the details given in a valid response (no Errors) and
#  inserts the required elements (determined by 'required_data' ) from the
#   response into in to a list of the following format [Element_name Element_value ..]
#
#  response_node - the Node that contains the response info
#  required_data - A list that contains the Parent Response elements and the
#                  relevant child elements from each parent to get and put into
#                  the 'response_data' list.
#
#  returns       - a list 'response_data' that contains Element Name, Element Value pairs.
#
proc ob_clickandbuy::_get_response_details {response_node required_data} {
	set response_data [list]

	ob_log::write DEBUG {ob_clickandbuy::_get_response_details($response_node, $required_data)}

	#  go through each Parent Element and their list of Child Elements
	#  that are needed from the request made.
	foreach {parent_elem child_elems} $required_data {

		# Grab the Parent Element, if it somehow fails, just skip to the next Parent Element
		# This can end up being more than one parent node
		if {[catch {set parent_nodes [$response_node getElementsByTagName $parent_elem]} msg]} {
			ob_log::write ERROR {ob_clickandbuy::_get_response_details: Couldn't get Parent Element $parent_elem, msg: $msg}
			continue
		}

		ob_log::write DEBUG {ob_clickandbuy::_get_response_details - parent_nodes, $parent_nodes}

		# Go through each parent node (usually only one Parent Node)
		foreach parent_node $parent_nodes {

			# want to make sure each child produces its own list
			set child_response [list]

			# go through each child element that belongs to the list
			# of child elements within the Parent Node ('parent_elem')
			foreach child_elem $child_elems {

				# attempt to get the data from the child element and append
				# it to the 'response_data' list
				if {[catch {lappend child_response $child_elem \
								[[[$parent_node getElementsByTagName $child_elem] \
									  selectNodes text()] data]} msg]} {
					ob_log::write ERROR {ob_clickandbuy::_get_response_details:Could not get child element value for $child_elem (parent:$parent_node), msg: $msg}

					lappend child_response $child_elem {}
				}
			}

			ob_log::write DEBUG {ob_clickandbuy::_get_response_details - child_response, $child_response}

			lappend response_data $child_response
		}
	}
	ob_log::write DEBUG {ob_clickandbuy::_get_response_details - response_data, $response_data}
	return $response_data
}



#
#  ob_clickandbuy::_get_response_error
#
#  Extracts the error code from a a Click and Buy error response
#
#  error_node - The 'detail' node which info needs to be obtained from
#
#  returns    - The error_code obtained from the error
#
proc ob_clickandbuy::_get_response_error {error_node parent_node} {

	set message_node [$error_node selectNodes "$parent_node/message"]

	set error_msg [$message_node text]

	return $error_msg
}



#
#  ob_clickandbuy::_build_isExternalBDRIDCommitted
#
#  Builds a SOAP request for isExternalBDRIDCommitted Click and Buy TMI
#  call.
#
#
#  <?xml version="1.0" encoding="UTF-8"?>
#  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
#  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
#  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#      <soapenv:Body>
#           <isExternalBDRIDCommitted xmlns="TransactionManager.Status">
#                <sellerID>123456789</sellerID>
#                <tmPassword>yourpassword</tmPassword>
#                <slaveMerchantID>0</slaveMerchantID>
#                <ExternalBDRID>123456</ExternalBDRID>
#           </isExternalBDRIDCommitted>
#      </soapenv:Body>
#  </soapenv:Envelope>
#
#
#  seller_id - appropriate seller id for the merchant account and currency
#  password  - password associated with the seller id
#  pmt_id    - The OpenBet pmt_id to check for Click and Buy payment commit
#
#  returns   - the request as above
#
proc ob_clickandbuy::_build_isExternalBDRIDCommitted {seller_id password pmt_id} {

	# build up the SOAP header for this request
	set soap_req_header [ob_clickandbuy::_get_soap_header]
	append soap_req_header "\n<soapenv:Body>"

	# create the Request element
	set doc  [dom createDocument isExternalBDRIDCommitted]
	set root [$doc documentElement]
	$root setAttribute xmlns "TransactionManager.Status"

	set element_list [list \
				sellerID $seller_id \
				tmPassword $password \
				slaveMerchantID 0 \
				ExternalBDRID $pmt_id]

	foreach {elem value} $element_list {
		set node [$doc createElement $elem]
		$node appendChild [$doc createTextNode $value]
		$root appendChild $node
	}

	# convert the built up SOAP body into a string
	set soap_body_core [_serialise_message $root]
	set soap_req_footer "</soapenv:Body>\n</soapenv:Envelope>"

	# destroy the created DOM node
	ob_clickandbuy::_destroy_message $root

	# return the SOAP request for isExternalBDRIDCommitted
	return "$soap_req_header\n${soap_body_core}$soap_req_footer"
}



#
#  ob_clickandbuy::_build_getEasyCollectSingle
#
#  Builds a SOAP request for getEasyCollectSingle Click and Buy TMI
#  call.
#
#
#  <?xml version="1.0" encoding="UTF-8"?>
#  <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
#  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
#  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
#  <soapenv:Body>
#    <getEasyCollectSingle xmlns="TransactionManager.Payment">
#       <sRequest>
#           <sellerID>222333444</sellerID>
#           <tmPassword>yourpassword</tmPassword>
#           <extJobID>123</extJobID>
#           <request>
#              <discriminator>DEBIT</discriminator>
#              <debReq>
#                 <slaveMerchantID>0</slaveMerchantID>
#                 <crn>111555000</crn>
#                 <easyCollectID>12345</easyCollectID>
#                 <externalBDRID>abc1111111</externalBDRID>
#                 <amount>1</amount>
#                 <currency>GBP</currency>
#              </debReq>
#           </request>
#       </sRequest>
#    </getEasyCollectSingle>
#  </soapenv:Body>
#  </soapenv:Envelope>
#
#
#  seller_id     - Click and Buy merchant account number
#  password      - merchant account password
#  easyCollectID - corresponds to a offer in the Click and Buy system
#  pmt_id        - The OpenBet pmt_id
#
#  returns       - the request as above
#
proc ob_clickandbuy::_build_getEasyCollectSingle {seller_id password crn easyCollectID pmt_id amount currency} {
	variable CB_PMT_DATA

	# Get the pmt details from the pmt_id
	ob_clickandbuy::_get_pmt_data "W" $pmt_id "U"


	# build up the SOAP header for this request
	set soap_req_header [ob_clickandbuy::_get_soap_header]
	append soap_req_header "\n<soapenv:Body>"

	# create the root element
	set doc  [dom createDocument getEasyCollectSingle]
	set root [$doc documentElement]
	$root setAttribute xmlns "TransactionManager.Payment"

	# create the sRequest element
	set subnode [$doc createElement sRequest]
	$root appendChild $subnode

	# create the nodes inside 'sRequest'
	set node [$doc createElement sellerID]
	$node appendChild [$doc createTextNode $seller_id]
	$subnode appendChild $node

	set node [$doc createElement tmPassword]
	$node appendChild [$doc createTextNode $password]
	$subnode appendChild $node

	set node [$doc createElement extJobID]
	$node appendChild [$doc createTextNode ""]
	$subnode appendChild $node

	set request_node [$doc createElement request]
	$subnode appendChild $request_node

	# create the nodes inside 'request'
	set node [$doc createElement discriminator]
	$node appendChild [$doc createTextNode "CREDIT"]
	$request_node appendChild $node

	set credReq_node [$doc createElement credReq]
	$request_node appendChild $credReq_node

	# create the nodes inside credReq
	set node [$doc createElement slaveMerchantID]
	$node appendChild [$doc createTextNode "0"]
	$credReq_node appendChild $node

	set node [$doc createElement crn]
	$node appendChild [$doc createTextNode $crn]
	$credReq_node appendChild $node

	set node [$doc createElement easyCollectID]
	$node appendChild [$doc createTextNode $easyCollectID]
	$credReq_node appendChild $node

	set node [$doc createElement externalBDRID]
	$node appendChild [$doc createTextNode $pmt_id]
	$credReq_node appendChild $node

	set node [$doc createElement amount]
	$node appendChild [$doc createTextNode $amount]
	$credReq_node appendChild $node

	set node [$doc createElement currency]
	$node appendChild [$doc createTextNode $currency]
	$credReq_node appendChild $node

	set node [$doc createElement urlInfo]
	$node appendChild [$doc createTextNode ""]
	$credReq_node appendChild $node

	set node [$doc createElement internalContentDescription]
	$node appendChild [$doc createTextNode ""]
	$credReq_node appendChild $node

	# convert the built up SOAP body into a string
	set soap_body_core [_serialise_message $root]
	set soap_req_footer "</soapenv:Body>\n</soapenv:Envelope>"

	# destroy the created DOM node
	ob_clickandbuy::_destroy_message $root

	# return the SOAP request for getEasyCollectSingle
	return "$soap_req_header\n${soap_body_core}$soap_req_footer"
}



#
#  ob_clickandbuy::_get_soap_header
#
#  Provides the standard request header for a Click and Buy TMI call
#
#  returns - the standard Click and Buy request header
#
proc ob_clickandbuy::_get_soap_header {} {

	set soap_header [list]
	lappend soap_header {<?xml version="1.0" encoding="UTF-8"?>}
	lappend soap_header {<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"}
	lappend soap_header {xmlns:xsd="http://www.w3.org/2001/XMLSchema"}
	lappend soap_header {xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">}

	return [join $soap_header "\n"]
}



#
#  ob_clickandbuy::_serialise_message
#
#  Pass in any node in the DOM tree and return the XML string
#  representing the entire message.
#
#  node          - the DOM node that needs serialising
#  lineBuffering - determines whether white space characters need
#                  to be stripped at the begining of each line
#
#  returns       - 'xml', a string representation of the DOM message
#
proc ob_clickandbuy::_serialise_message {node {line_buffering 0}} {
	set od  [$node ownerDocument]
	set de  [$od documentElement]
	set xml [$de asXML]

	# If we are using line buffering  send as one line and
	# get rid of white space at the beginning of each line.
	if {$line_buffering} {

		regsub -line -all {^\s+} $xml {} xml
		regsub -all {\n} $xml "" xml
	}

	return $xml
}



#
#  ob_clickandbuy::_destroy_message
#
#  Remove all DOM tree memory associated with the passed in message.
#
#  node - any node in the DOM tree, the entire document will be freed
#
proc ob_clickandbuy::_destroy_message {node} {
	catch {
		set od [$node ownerDocument]
		$od delete
	}
}



#
#  ob_clickandbuy::_print_xml
#
#  Convenience function for debugging.
#
#  xml     - the XML that will be printed
#
#  returns - nicely formatted XML
#
proc ob_clickandbuy::_print_xml {xml} {

	dom parse $xml doc
	$doc documentElement root

	return [$root asXML]
}



#
#  Gets the PMG values based on the currency code
#
#  ccy_code  - currency code we want to get gateway details for
#
#  return    - 1 on successful colleciton of data, 0 otherwise
#
proc ob_clickandbuy::_get_pmg_params {ccy_code} {

	variable PMT_DATA

	# setup the ccy_code for the customer as this gets used
	# in the PMG rules tcl conditions stored in the DB
	set PMT_DATA(ccy_code) $ccy_code


	# Get the correct payment gateway details for this payment
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]

	# cater for PMG error
	if {[lindex $pg_result 0] == 0} {
		ob_log::write ERROR {ob_clickandbuy::_get_pmg_params:PMG Rules failed,[lindex $pg_result 1]}
		return 0
	}

	# all looks good, 'PMT_DATA' has been populated with the appropriate data
	return 1
}

#
# Send a payment message to the ticker
# (Copied from shared_tcl/gen_payment.tcl but removed num_payments check)
#
# pmt_id     - id of payment
# pmt_date   - date of payment
# pmt_status - payment status
# GEN_PMT_ARR - name of array containing payment details
#
proc ob_clickandbuy::_send_pmt_ticker {
				pmt_id
				pmt_date
				pmt_status
				GEN_PMT_ARR} {

	global DB
	variable GEN_MTHD

	upvar 1 $GEN_PMT_ARR GEN_PMT

	# Check if this message type is supported
	if {![string equal [OT_CfgGet MONITOR 0] 1] ||
	    ![string equal [OT_CfgGet PAYMENT_TICKER 0] 1]} {
		ob_log::write INFO {_send_pmt_ticker: MONITOR        = [OT_CfgGet MONITOR 0]}
		ob_log::write INFO {_send_pmt_ticker: PAYMENT_TICKER = [OT_CfgGet PAYMENT_TICKER 0]}
		return 0
	}

	set pay_method $GEN_PMT(type)

	set rs [ob_db::exec_qry ob_clickandbuy::get_monitor_info $GEN_PMT(acct_id)]

	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set cust_id        [db_get_col $rs cust_id]
		set username       [db_get_col $rs username]
		set fname          [db_get_col $rs fname]
		set lname          [db_get_col $rs lname]
		set postcode       [db_get_col $rs addr_postcode]
		set country_code   [db_get_col $rs country_code]
		set email          [db_get_col $rs email]
		set reg_date       [db_get_col $rs cust_reg_date]
		set reg_code       [db_get_col $rs code]
		set notifiable     [db_get_col $rs notifyable]
		set acct_balance   [db_get_col $rs balance]
		set addr_city      [db_get_col $rs addr_city]
		set addr_country   [db_get_col $rs addr_country]
		set exch_rate      [db_get_col $rs exch_rate]
		set ccy_code       [db_get_col $rs ccy_code]
		set trading_note   [db_get_col $rs flag_value]
		set max_deposit    [db_get_col $rs max_deposit]
		set max_withdrawal [db_get_col $rs max_withdrawal]
		ob_db::rs_close $rs
	} else {
		#
		# No information to send the monitor
		#
		ob_log::write INFO {_send_pmt_ticker: $nrows rows found. No data to send to monitor}
		ob_db::rs_close $rs
		return 0
	}


	set ext_unique_id [expr {[info exists GEN_PMT(ext_unique_id)]?"$GEN_PMT(ext_unique_id)":"N/A"}]

	if {[info exists GEN_PMT(bank_name)]} {
		set bank_name $GEN_PMT(bank_name)
	} elseif {[info exists GEN_MTHD(BANK_NAME)]} {
		set bank_name $GEN_MTHD(BANK_NAME)
	} else {
		set bank_name "N/A"
	}

	if {[info exist GEN_PMT(trading_note)]} {
		set trading_note $GEN_PMT(trading_note)
	}

	# Bank name is present for both bank transfer/bankline
	if {[string equal $bank_name "N/A"] &&
	    [string first $GEN_PMT(type) "BL/BANK"] > -1} {

		catch {ob_db::unprep_qry ob_clickandbuy::get_bank_name}
		ob_db::store_qry ob_clickandbuy::get_bank_name [subst {
			select
				bank_name
			from
				tCpm${GEN_PMT(type)}
			where
				cpm_id = ?
		}]

		set rs [ob_db::exec_qry ob_clickandbuy::get_bank_name $GEN_PMT(cpm_id)]

		if {[db_get_nrows $rs] > 0} {
			set bank_name [db_get_col $rs 0 bank_name]
		}
		ob_db::rs_close $rs
	}

	if {[info exists GEN_PMT(shop_id)]} {
		set shop_id $GEN_PMT(shop_id)
	} else {
		set shop_id "N/A"
	}

	if {[info exists GEN_PMT(rad_id)]} {
		set rad_id $GEN_PMT(rad_id)
	} else {
		set rad_id "N/A"
	}

	if {[string is double $exch_rate] && $exch_rate > 0} {
		# convert user amount into system ccy
		set amount_sys [format "%.2f" [expr {$GEN_PMT(amount) / $exch_rate}]]
	} else {
		ob_log::write ERROR "_send_pmt_ticker: ERROR bad exchange rate ($exch_rate)"
		return 0
	}

	set cum_wtd_usr ""
	set cum_wtd_sys ""
	set cum_dep_usr ""
	set cum_dep_sys ""
	set max_wtd_pc  ""
	set max_dep_pc  ""

	if {[catch {set result [MONITOR::send_pmt_non_card\
	                                 $cust_id\
	                                 $username\
	                                 $fname\
	                                 $lname\
	                                 $postcode\
	                                 $email\
	                                 $country_code\
	                                 $reg_date\
	                                 $reg_code\
	                                 $notifiable\
	                                 $GEN_PMT(acct_id)\
	                                 $acct_balance\
	                                 "$GEN_PMT(ipaddr)-${addr_country}"\
	                                 "$GEN_PMT(ipaddr)-${addr_city}"\
	                                 $pay_method\
	                                 $ccy_code\
	                                 $GEN_PMT(amount)\
	                                 $amount_sys\
	                                 $pmt_id\
	                                 $pmt_date\
	                                 $GEN_PMT(payment_sort)\
	                                 $pmt_status\
	                                 $ext_unique_id\
	                                 $bank_name\
	                                 $GEN_PMT(source)\
	                                 $trading_note\
	                                 $cum_wtd_usr\
	                                 $cum_wtd_sys\
	                                 $cum_dep_usr\
	                                 $cum_dep_sys\
	                                 $max_wtd_pc\
	                                 $max_dep_pc\
	                                 $shop_id\
	                                 $rad_id]} msg]} {
		ob::log::write ERROR {ob_clickandbuy::_send_pmt_ticker: Failed to send \
		    payment monitor message : $msg}
		return 0
	}
	return $result
}
