# ==============================================================
# $Id: ob_srp.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

# SRP - Social Responsibility Programme
namespace eval OB_srp {

namespace export init_srp
namespace export check_limit_exceeded
namespace export insert_update_cust_dep_limit
namespace export insert_update_cust_self_excl
namespace export get_deposit_details
namespace export get_currency_limits
namespace export get_all_currency_limits
namespace export get_cust_ccy_max_deposit
namespace export get_total_poker
namespace export get_cust_limit
namespace export get_cust_deposit_totals
namespace export get_min_poker_transaction
namespace export get_poker_txn_limit
namespace export get_max_poker_txn_amt
namespace export get_poker_level
namespace export bind_available_ccy_limits
namespace export update_cust_poker_limit
namespace export bind_all_max_dep_info
namespace export get_cust_self_excl


##############################################################################
# Procedure :   ob_init args
# Description : initialise all the queries for the social responsibity programme
# Input :
# Output :
# Author :      JDM, 26-03-2001
##############################################################################
proc init_srp args {
	ob_prep_qrys
}


##############################################################################
# Procedure :   ob_prep_qrys
# Description : Prepares Queries
# Input :
# Output :
# Author :      JDM, 26-03-2001
##############################################################################
proc ob_prep_qrys args {
	global SHARED_SQL

	ob::log::write DEV {Preparing SRP Queries...}

	#
	# srp currency related queries
	#
	set SHARED_SQL(get_ccy_max_deposit) {
		select
			a.ccy_code,
			y.max_deposit
		from
			tccy y,
			tcustomer c,
			tacct a
		where
			c.cust_id=?
			and a.ccy_code = y.ccy_code
			and c.cust_id = a.cust_id
		order by    1

	}

	set SHARED_SQL(get_ccy_max_deposit_cpm) {
		execute procedure pPmtControlAcct (
			p_cpm_id = ?,
			p_payment_sort = 'D'
		)
	}

	set SHARED_SQL(get_ccy_deposit_limits) {
		select
			trunc(v.setting_value,0) as limit_value
		from
			tsitecustomval v
		where
			v.setting_name = ?
		order by 1
	}

	set SHARED_SQL(get_all_ccy_deposit_limits) {
		select
			v.setting_name as ccy_name,
			trunc(v.setting_value,0) as limit_value
		from
			tsitecustomval v,
			tccy c
		where
			c.ccy_code = v.setting_name and
			c.status = 'A'
		order by 1,2
	}

	set SHARED_SQL(get_rounded_ccy) {
		select
			round_exch_rate
		from
			txgameroundccy
		where
			ccy_code = ?
		and
			status = 'A'
	}

	#
	# customer specific srp queries
	#

	set SHARED_SQL(update_limit) {
		execute procedure pInsCustLimits
		(
			p_cust_id         =?,
			p_limit_type      =?,
			p_limit_value     =?,
			p_limit_period    =?,
			p_delay_hrs	      =?,
			p_oper_id         =?,
			p_terminate_all   =?,
			p_do_tran         =?
		)
	}

	set SHARED_SQL(update_self_excl) {
		execute procedure pInsSelfExcl
		(
			p_cust_id         =?,
			p_limit_type      =?,
			p_limit_value     =?,
			p_limit_period    =?,
			p_delay_hrs	      =?,
			p_oper_id         =?,
			p_terminate_all   =?
		)
	}

	set SHARED_SQL(get_cust_limit) {
		select
			trunc(limit_value, 0) as limit_value,
			limit_period
		from
			tcustlimits
		where
			cust_id = ?
			and     limit_type = ?
			and     to_date    > CURRENT
			and     from_date  <=  CURRENT
			and     tm_date    is null
	}

	set SHARED_SQL(get_self_excl) {
		select
			*
		from
			tCustLimits
		where
			cust_id = ?
			and limit_type = ?
			and limit_period > 0
			and from_date <= CURRENT
			and tm_date is null
	}

	set SHARED_SQL(get_stored_max_withdrawal) {
		select      a.ccy_code,
					y.max_withdrawal,
					y.min_withdrawal
		from        tccy y,
					tcustomer c,
					tacct a
		where       c.cust_id=?
		and         a.ccy_code = y.ccy_code
		and         c.cust_id = a.cust_id
		order by    1
	}

	set SHARED_SQL(get_stored_max_withdrawal_cpm) {
		execute procedure pPmtControlAcct (
			p_cpm_id = ?,
			p_payment_sort = 'W'
		)
	}

	set SHARED_SQL(get_withdrawn_amount_qry) {
		select
			NVL(sum(p.amount),0.00) as amount
		from
			tpmt p, tacct a
		where
			a.cust_id = ? and
			a.acct_id = p.acct_id and
			p.payment_sort = 'W' and
			p.status in ('Y','R','L','P') and
			p.cr_date > ? and
			p.cr_date < ?
	}


	# This query has been taken from acct_qry for
	# OXi as we dont want to source acct_qry.tcl
	if {[OT_CfgGet SRP_WTD_LIM_CHK 0]} {
		# query to get the balance of a customer's account
		set SHARED_SQL(srp_get_acct_balance_qry) {
			SELECT
				balance,
				balance_nowtd
			FROM
				tAcct
			WHERE
				cust_id = ?
		}
	}
	# end of srp_get_acct_balance_qry

	set get_dep_txn_sum {
		select
			count(*) depcount,
			$dep_amount_sum
		from
			tpmt
		where
			acct_id = (
				select  acct_id
				from    tacct
				where   cust_id = ?
			)
			and     payment_sort=?
			and     cr_date > CURRENT - ? units day
			and     status not in ([OT_CfgGet SRP_DEP_STATUS_IGNORE "'X','N'"])
			and     source not in ('L')
	}
	set dep_amount_sum "sum(amount) depamount"
	set SHARED_SQL(get_dep_txn_sum) [subst $get_dep_txn_sum]
	set dep_amount_sum "sum(amount + commission) depamount"
	set SHARED_SQL(get_dep_txn_sum_comm) [subst $get_dep_txn_sum]


	#
	# poker specific  srp queries
	#

	set SHARED_SQL(get_poker_limit_change_time) {
		select  from_date
		from    tcustlimits
		where   cust_id    =  ?
		and     limit_type =  ?
		and     to_date    >= CURRENT
		and     from_date  <  CURRENT
		and     tm_date    is null
	}

	set SHARED_SQL(get_poker_dep_sum) {
		select
			sum(-m.amount) depamount
		from
			tmanadj     m,
		        txferstatus x
		where
			m.acct_id = (
				select acct_id
				from   tacct
				where  cust_id = ?
			)
			and     m.madj_id = x.man_adj_id
			and     m.type    = "MCSP"
			and     m.cr_date > ?
			and     m.amount  < 0
			and     x.status  = "S"
	}

	set SHARED_SQL(get_poker_wtd_sum) {
		select
			sum(m.amount) wtdamount
		from
			tmanadj     m,
		        txferstatus x
		where
			m.acct_id = (
				select acct_id
				from   tacct
				where  cust_id = ?
			)
			and     m.madj_id = x.man_adj_id
			and     m.type    = "MCSP"
			and     m.cr_date > ?
			and     m.amount  > 0
			and     x.status  = "S"
	}

	set SHARED_SQL(OB_srp::get_poker_level) {
		select
			flag_value
		from
			tCustomerFlag
		where
			cust_id   = ?
		and flag_name = "poker_srp_level"
	}

	set SHARED_SQL(OB_srp::upd_poker_level) {
		update
			tcustomerflag
		set
			flag_value = ?
		where
			cust_id    = ?
		and flag_name  = "poker_srp_level"
	}

	set SHARED_SQL(OB_srp::ins_poker_level) {
		insert into tCustomerFlag (
			cust_id,
			flag_name,
			flag_value
		) values (
			?,
			"poker_srp_level",
			?
		)
	}
}

##########################################################################
#
# Procedure: check_limit_exceeded
# Descrption: checks whether a customer is allowed to deposit/withdraw the amount requested
# Input: cust_id, amount
# Output: {<limit_exceeded> <reason>}
#               limit_exceeded - 1 if not exceeded, 0 if exceeded, -1 if error
#               reason - FRQ_FAILURE if not allowed to deposit due to exceeding frequency
#                               AMT_FAILURE if not allowed as deposited too much
#
##########################################################################
proc check_limit_exceeded {cust_id amount sort {inc_comm false} {cpm ""}} {

	switch -- $sort {
	"W" {
		if {[OT_CfgGet SRP_WTD_LIM_CHK 0]} {
				# Do the withdrawal limit check
			if {[catch {set response [check_max_withdrawal $amount $cust_id $cpm]} msg]} {
				OT_LogWrite 1 "Error calling OB_srp::check_max_deposit \[$msg\]"
				error $msg
			}
			# returns 0 - exceeded , 1 - not exceeded
			return $response
		} else {

			# no limit checking required so allow the transaction to proceed
			return [list 1]
		}
		# end of withdraw limit check code
	}
	"D" {
		if {[OT_CfgGet SRP_DEP_LIM_CHK 0]} {
			# first obtain the customers deposit limits
			set cust_limits [get_deposit_details $cust_id $cpm]
			if {[lindex $cust_limits 0] == -1} {
				ob::log::write ERROR "Unable to check if customer: $cust_id can deposit"
				return [list -1]
			}

			set max_amount [lindex $cust_limits 0]
			set period [lindex $cust_limits 1]

			# obtain info about the number and total amount of deposits
			# made during their set srp period (ie day or week)
			set deposit_info [OB_srp::get_cust_deposit_totals $cust_id $period true]
			if {[lindex $deposit_info 0] == -1} {
				ob::log::write ERROR "Unable to check if customer: $cust_id can deposit"
				return [list -1]
			}

			# check whether the amount has exceeded the limit
			set previous_deposit_total [lindex $deposit_info 0]
			if {[expr {$previous_deposit_total + $amount}] > $max_amount} {
				return [list 0 "AMT_FAILURE"]
			}

			if {[OT_CfgGet FUNC_CUST_DEP_LIMITS_MAX_FRQ 0]} {
				set frequency [lindex $cust_limits 3]
				set number_deposits [lindex $deposit_info 1]
				if {$number_deposits >= $frequency} {
					return [list 0 "FRQ_FAILURE"]
				}
			}

			# successfully checked with no errors and no limits exceeded
			return [list 1]
		} else {

			# no limit checking required so allow the transaction to proceed
			return [list 1]
		}
	}
	default {
		ob::log::write ERROR "Invalid payment sort \[$sort\]"
		return [list 0]
	}
	}
}


##############################################################################
# Procedure :   check_max_withdrawal
# Description : check inputted amount against max withdrawal
# Input :       iNewAmount - amount to check, and cust_id
# Output :      1 exceeded or 0 not exceeded
# Author :      Gavin 18-02-2005
##############################################################################
proc check_max_withdrawal {iNewAmount cust_id {cpm ""}} {
	set    begin_period     [clock format [expr [clock seconds] - 60 * [OT_CfgGet MAX_WTD_MINS 1440]] -format "%Y-%m-%d %H:%M:%S"]
	set    now              [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	set rsStored 		[::OB_srp::get_stored_max_withdrawal $cust_id $cpm]

	set rsPmt			[::OB_srp::get_withdrawn_amount_qry $begin_period $now $cust_id]
	set StoredRows 		[db_get_nrows $rsStored]
	set PmtRows			[db_get_nrows $rsPmt]

	if {$StoredRows == 0} {
		ob::log::write ERROR {SRP: Failed to get stored max withdrawal details}
		error "SRP: Failed to get stored max withdrawal details"
	}

	if {$PmtRows == 0} {
		ob::log::write ERROR {SRP: Failed to get payments}
		error "SRP: Failed to get payments"
	}

	set max_withdrawal 	[db_get_col $rsStored 0 max_withdrawal]
	set min_withdrawal  [db_get_col $rsStored 0 min_withdrawal]
	set daily_total [db_get_col $rsPmt 0 amount]
	db_close $rsStored
	db_close $rsPmt

	#
	# Format the limits
	#
	set min_withdrawal [format "%.2f" $min_withdrawal]
	set max_withdrawal [expr $max_withdrawal - $daily_total]


 	set wtd_balance [::OB_srp::srp_get_acct_balance nowtd $cust_id]

	if {$wtd_balance > $max_withdrawal} {
		set max_wtd_limit [format "%.2f" $max_withdrawal]
	} else {
		set max_wtd_limit [format "%.2f" $wtd_balance]
	}

	if {$wtd_balance > $min_withdrawal} {
		set min_wtd_limit [format "%.2f" $min_withdrawal]
	} else {
		set min_wtd_limit [format "%.2f" $wtd_balance]
	}


	if {$iNewAmount < $min_wtd_limit || $iNewAmount > $max_wtd_limit || $min_wtd_limit > $max_wtd_limit} {
		return 0
	} else {
		return 1
	}
}
# end of check_max_withdrawl


##############################################################################
# Procedure :   srp_get_balance
# Description : return the balance for the current customer, ported from acct_qry.tcl
#               for OXi so we don't have to source acct_qry.tcl
# Input :       if passed nowtd the balance returned is the non withdrawable, cust_id
#               balance
# Output :      balance
# Author :      Gavin 22-02-2005
##############################################################################
proc srp_get_acct_balance {{type wtd} cust_id} {

	set rsBalance 		[::OB_srp::srp_get_acct_balance_qry $cust_id]
	set balRows 		[db_get_nrows $rsBalance]

	if {$balRows != 1} {
		ob::log::write ERROR {SRP: Failed to get account balance details}
		error "SRP: Failed to get account balance details"
	}

	if {$type == "wtd"} {
		set amnt [db_get_col $rsBalance balance]
	} elseif {$type == "nowtd"} {
		set amnt [expr {[db_get_col $rsBalance balance] - [db_get_col $rsBalance balance_nowtd]}]
	} else {
		set amnt 0
	}

	db_close $rsBalance

	return $amnt
}
# end of srp_get_acct_balance


##############################################################################
# Procedure :   get_stored_max_withdrawal args
# Description : binds up the currency types and the stored max withdrawal
# Input :       cust_id cpm
# Output :      result set
# Author :      Gavin, 18-02-2005
##############################################################################
proc get_stored_max_withdrawal {cust_id {cpm ""}} {

	if {$cpm == ""} {
		if {[catch {set rs [tb_db::tb_exec_qry get_stored_max_withdrawal $cust_id]} msg]} {
			ob::log::write ERROR {get_stored_max_withdrawal: query failed: $msg}
			return 0
		}
	} else {
		if {[catch {set rs [tb_db::tb_exec_qry get_stored_max_withdrawal_cpm $cpm]} msg]} {
			ob::log::write ERROR {get_stored_max_withdrawal_cpm: query failed: $msg}
			return 0
		}
	}

	return $rs
}
# end of get_stored_max_withdrawal


##############################################################################
# Procedure :  	get_withdrawn_amount_qry begin_period now cust_id
# Description : returns the withdrawn amounts in a given time
# Input :       none
# Output :      result set
# Author :      Gavin, 18-02-2005
##############################################################################
proc get_withdrawn_amount_qry {begin_period now cust_id} {

	if {[catch {set rs [tb_db::tb_exec_qry get_withdrawn_amount_qry $cust_id $begin_period $now]} msg]} {
		ob::log::write ERROR {get_withdrawn_amount_qry: query failed: $msg}
		return 0
	}

	return $rs
}
# end of get_withdrawn_amount_qry


##############################################################################
# Procedure :   srp_get_acct_balance_qry
# Description : returns the current balance for a customer
# Input :       cust_id
# Output :      result set
# Author :      Gavin, 22-02-2005
##############################################################################
proc srp_get_acct_balance_qry {cust_id} {

	if {[catch {set rs [tb_db::tb_exec_qry srp_get_acct_balance_qry $cust_id]} msg]} {
		ob::log::write ERROR {srp_get_acct_balance_qry: query failed: $msg}
		return 0
	}

	return $rs
}
# end of srp_get_acct_balance_qry


##########################################################################
#
# Procedure: cust_deposit_allowed
# Descrption: checks whether a customer is allowed to deposit the amount requested
# Input: cust_id, amount
# Output: {<dep_allowed> <reason>}
#               dep_allowed - 1 if deposit allowed, 0 if not, -1 if error
#               reason - FRQ_FAILURE if not allowed to deposit due to exceeding frequency
#                               AMT_FAILURE if not allowed as deposited too much
#
##########################################################################
proc cust_deposit_allowed {cust_id amount} {
	
	# first obtain the customers deposit limits	
	set cust_limits [get_deposit_details $cust_id]
	if {[lindex $cust_limits 0] == -1} {
		ob::log::write ERROR "Unable to check if customer: $cust_id can deposit"
		return [list -1]
	}

	set max_amount [lindex $cust_limits 0]
	set period [lindex $cust_limits 1]

	# obtain info about the number and total amount of deposits
	# made during their set srp period (ie day or week)
	set deposit_info [OB_srp::get_cust_deposit_totals $cust_id $period true]
	if {[lindex $deposit_info 0] == -1} {
		ob::log::write ERROR "Unable to check if customer: $cust_id can deposit"
		return [list -1]
	}

	# check whether the amount has exceeded the limit
	set previous_deposit_total [lindex $deposit_info 0]
	if {[expr {$previous_deposit_total + $amount}] > $max_amount} {
		return [list 0 "AMT_FAILURE"]
	}

	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS_MAX_FRQ 0]} {
		set frequency [lindex $cust_limits 3]
		set number_deposits [lindex $deposit_info 1]
		if {$number_deposits >= $frequency} {
			return [list 0 "FRQ_FAILURE"]
		}
	}

	# successfully checked with no errors and no limits exceeded
	return [list 1]
}

##########################################################################
#
# Procedure: insert_update_cust_dep_limit
# Descrption: insert/update a customer's deposit limits - uses stored values if not passed
#                      eg if only pass an amount but no period uses the existing period and just updates the amount
# Input: cust_id, amount, period, frequency, operator_id, terminate_all_old (required by admin screens to allow overwriting of all limits)
#
# Output: 1 - if success, 0 if error
#
##########################################################################
proc insert_update_cust_dep_limit {cust_id {amount ""} {period ""} {frequency ""} {delay ""} {operator_id ""} {terminate_all_old 0} {cpm ""} {do_tran Y} {insert_new_limit 1}} {

	# first obtain the customers stored deposit details
	set cust_limits [get_deposit_details $cust_id $cpm]
	if {[lindex $cust_limits 0] == -1} {
		ob::log::write ERROR "Unable to update cust limits. Cust_id: $cust_id"
		return 0
	}

	# first update the amount limit (if necessary)
	set stored_max_amount [lindex $cust_limits 0]
	set stored_period [lindex $cust_limits 1]
	set def_amt [lindex $cust_limits 2]

	if {$amount != "" || $period != ""} {
		if {$amount == ""} {set amount $stored_max_amount}
		if {$period == ""} {set period $stored_period}

		# only update if new values have been submitted or if there is no limit previously inserted for the customer (ie def_amt = 1)
		if {$amount != $stored_max_amount || $period != $stored_period || $def_amt == 1} {
			set success [OB_srp::store_cust_limit $cust_id "max_dep_amt" $amount $period $delay $operator_id $terminate_all_old $do_tran]
			if {!$success} {
				ob::log::write ERROR "Unable to insert/update cust srp amount/period. Cust_id: $cust_id"
				return 0
			}
		}
	}
	
	if {$insert_new_limit == 0} {
		# We want to terminate ALL limits for a customer and do not want to 
		# insert a new limit. so pass in null value as the amount and 1 to
		# indicate that we want all limits terminated
		set success [OB_srp::store_cust_limit $cust_id "max_dep_amt" "" "" $delay $operator_id 1]
		if {!$success} {
			ob::log::write ERROR "Unable to insert/update cust srp amount/period. Cust_id: $cust_id"
			return 0	
		}
	}

	# now update frequency if required
	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS_MAX_FRQ 0] && $frequency != ""} {
		set stored_frequency [lindex $cust_limits 3]
		set def_frq [lindex $cust_limits 4]

		if {$frequency != $stored_frequency || $def_frq == 1} {
			set success [OB_srp::store_cust_limit $cust_id "max_dep_frq"  $frequency "" $delay $operator_id $terminate_all_old $do_tran]
			if {!$success} {
				ob::log::write ERROR "Unable to insert/update cust srp frequency. Cust_id: $cust_id"
				return 0
			}
		}
	}
	return 1
}


##########################################################################
#
# Procedure: insert_update_cust_self_excl
# Descrption: insert/update a customer's self-exclusion status
# Input: cust_id, amount, period, frequency, operator_id, terminate_all_old (required by admin screens to allow overwriting of all limits). (period is passed in as number of days).
#
# Output: 1 - if success, 0 if error
#
##########################################################################
proc insert_update_cust_self_excl {cust_id {amount ""} {period ""} {frequency ""} {delay ""} {operator_id ""} {terminate_all_old 0}} {

	set success [OB_srp::store_cust_self_excl $cust_id "self_excl" $amount $period $delay $operator_id $terminate_all_old]
	if {!$success} {
		ob::log::write ERROR "Unable to insert/update cust self exclusion. Cust_id: $cust_id"
		return 0
	}
	return 1
}


##########################################################################
#
# Procedure: get_cust_self_excl
# Description: gets a customer's self exclusion status
#
# Input: cust_id
# Output: 1 - if customer had selected self exclusion, 0 if not
#
##########################################################################
proc get_cust_self_excl {cust_id} {

	set self_excl_limit_type "self_excl"

	if {[catch {set rs [tb_db::tb_exec_qry get_self_excl \
						$cust_id \
						$self_excl_limit_type \
						]} msg]} {
		ob::log::write ERROR {get_cust_self_excl: Failed update: $msg}
		catch {db_close $rs}
		tpSetVar cust_selected_self_excl "0"
		return 0
	}
	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		#Determines whether the admin user is allowed to update the self exclusion according to the to and from dates
		tpSetVar cust_selected_self_excl "0"
		tpSetVar self_excl_upd_allowed "1"
		return 1
	} else {
		set cust_to_date [db_get_col $rs 0 to_date]
		set curr_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
		tpBindString self_excl_started [db_get_col $rs 0 from_date]
		tpBindString self_excl_ends $cust_to_date
		tpSetVar cust_selected_self_excl "1"
		if {$cust_to_date <= $curr_date} {
			tpSetVar self_excl_upd_allowed "1"
			db_close $rs
			return 1
		} else {
			if {[OT_CfgGet FUNC_ALLOW_SELF_EXCL_UPD_WITHIN_TIME 0] == 1} {
				tpSetVar self_excl_upd_allowed "1"
			} else {
				tpSetVar self_excl_upd_allowed "0"
			}
			db_close $rs
			return 0
		}
	}
}



##########################################################################
#
# Procedure: get_deposit_details
# Description: gets a customer's limits
#                       Returns a customers srp amount, period and frequency
#                        If no limit found returns the default values
#
# Input: cust_id
#
# Output: list of the form {<amount> <amount_period> <amount/period default>
#               **AND IF FREQUENCY FUNC IS ON** <frequency>  <frequency default>}
#               <amount> - amount they are allowed to deposit
#               <amount_period>  - the period this limit is set for (in days)
#               <amount/period default> - 1 if a default was returned, 0 if not
#               <frequency> - the number of deposits allowed for the period
#              <frequency default> - 1 if a default was returned, 0 if not
#
#                Returns -1 if there is an error
#
##########################################################################
proc get_deposit_details {cust_id {cpm ""}} {

	set dep_limit_details [OB_srp::get_cust_limit "max_dep_amt" $cust_id]

	# if there was an error
	if {[lindex $dep_limit_details 0] == -1} {
		return [list -1]
	} else {

		if {[lindex $dep_limit_details 0] == 0} {
			# get the default limits
			set default_limits [OB_srp::get_cust_dep_limit_defaults $cust_id $cpm]
			if {[lindex $default_limits 0] == -1} {
				return [list -1]
			} else {
				set amount [lindex $default_limits 0]
				set period [lindex $default_limits 1]
				set amt_default 1
			}
		} else {
			set amount [lindex $dep_limit_details 0]
			set period [lindex $dep_limit_details 1]
			set amt_default 0
		}
	}

	# if frequency functionality is turned on, also returned the customers frequency limit
	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS_MAX_FRQ 0]} {
		set freq_limit_details [OB_srp::get_cust_limit "max_dep_frq" $cust_id]
		if {[lindex $freq_limit_details 0] == -1} {
			return [list -1]
		} else {
			if {[lindex $freq_limit_details 0] == 0} {
				# get the default limits
				set frequency [OT_CfgGet CUST_SRP_FREQ_DEFAULT 25]
				set frq_default 1
			} else {
				# nb - no need to get the period for the frequency
				# must be the same as that for the amount limit so use that
				set frequency [lindex $freq_limit_details 0]
				set frq_default 0
			}
		}
		return [list $amount $period $amt_default $frequency $frq_default]
	} else {
		return [list $amount $period $amt_default "" ""]
	}
}


##############################################################################
# Procedure :   get_currency_limits
# Description : binds up the available deposit limits for user's ccy
# Input :       none
# Output :      result set
# Author :      JDM, 26-03-2001
##############################################################################
proc get_currency_limits {ccy_code} {

	if {[catch {set rs [tb_db::tb_exec_qry get_ccy_deposit_limits $ccy_code]} msg]} {
		ob::log::write ERROR  {get_currency_limits: query failed: $msg}
		return 0
	}

	return $rs
}

##############################################################################
# Procedure :   get_all_currency_limits
# Description : gets the available deposit limits for all ccys
# Input :       none
# Output :      result set
# Author :      aroser 17-10-2003
##############################################################################
proc get_all_currency_limits {} {

	if {[catch {set rs [tb_db::tb_exec_qry get_all_ccy_deposit_limits]} msg]} {
		ob::log::write ERROR  {get_all_currency_limits: query failed: $msg}
		return 0
	}

	return $rs
}

################################################################################
# Procedure:    get_cust_limit
# Description:  returns details of the limit specified, retrieved from tcustlimits.
# Input:          limit_type, cust_id
# Output:       a list containing the value and period of the limit for the given user.
#                    -1 if error, 0 if no relevant limit found
# Author:       sluke, 06-03-2002
################################################################################
proc get_cust_limit {limit_type cust_id} {

	if {[catch {set rs [tb_db::tb_exec_qry get_cust_limit $cust_id $limit_type]} msg]} {
		ob::log::write ERROR {get_cust_limit: query failed: $msg}
		return [list -1]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		db_close $rs
		return [list 0]
	} else {
		set val [db_get_col $rs 0 limit_value]
		set period [db_get_col $rs 0 limit_period]
		db_close $rs
		return [list $val $period]
	}
}

########################################
# Procedure :   get_cust_dep_limit_defaults
# Description : gets the default amount and period for a customer
# Input :       cust_id
# Output :     -1 if error
#                    else a list of the form:
#                    {<amount> <period>}
#                    <amount> - default amount they are allowed to deposit
#                    <period>  -  default period (ie day or week)
#########################################
proc get_cust_dep_limit_defaults {cust_id {cpm ""}} {

	set ccy_details [OB_srp::get_cust_ccy_max_deposit $cust_id $cpm]
	if {[lindex $ccy_details 0] == 0} {
		return [list -1]
	}

	set default_amount [lindex $ccy_details 1]
	# default period comes from a config setting
	set default_period [OT_CfgGet CUST_SRP_PERIOD_DEFAULT "1"]

	return [list $default_amount $default_period]
}

######################################
#Procedure :   get_cust_deposit_totals
# Description : gets the sum and number of deposits for a customer
#                         over a defined period
# Input :       cust_id, period (in days), is_comm_inc (true or false)
# Output :     -1 if error
#                    else a list of the form:
#                    {<amount> <number}
#                    <amount>  - amount deposited
#                    <number>  -  number of deposits
#########################################
proc get_cust_deposit_totals {cust_id {period "1"} {is_comm_inc false}} {

	set txn_qry_name get_dep_txn_sum

	if {$is_comm_inc} {
		append txn_qry_name _comm
	}

	if {[catch {set rs [tb_db::tb_exec_qry $txn_qry_name $cust_id "D" $period]} msg]} {
		ob::log::write ERROR {get_cust_deposit_totals failed : $msg}
		catch {db_close $rs}
		return [list -1]
	}

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		return [list 0 0]
	} else {
		set amount [db_get_col $rs 0 depamount]
		if {![string length $amount]} {
			set amount 0
		}
		set dep_count [db_get_col $rs 0 depcount]
		if {![string length $dep_count]} {
			set dep_count 0
		}
		db_close $rs
		return [list $amount $dep_count]
	}

}

##############################################################################
# Procedure :   store_cust_limit
# Description : Updates a given limit
# Output :      1 if successfully updated, 0 if fails
# Author :      JDM, 26-03-2001
##############################################################################
proc store_cust_limit {cust_id limit_type limit_value {limit_period ""} {delay ""} {oper_id ""} {terminate_all 0} {do_tran Y}} {

	if {[catch {set rs [tb_db::tb_exec_qry update_limit \
						$cust_id \
						$limit_type \
						$limit_value \
						$limit_period \
						$delay \
						$oper_id \
						$terminate_all \
						$do_tran \
						]} msg]} {
		ob::log::write ERROR {store_cust_limit: Failed update: $msg}
		catch {db_close $rs}
		return 0
	}
	db_close $rs
	return 1
}



##############################################################################
# Procedure :   store_cust_self_excl
# Description : Updates a given limit
# Output :      1 if successfully updated, 0 if fails
# Author :      pshah, 01-09-2005
##############################################################################
proc store_cust_self_excl {cust_id limit_type limit_value {limit_period ""} {delay ""} {oper_id ""} {terminate_all 0}} {
	if {[catch {set rs [tb_db::tb_exec_qry update_self_excl \
						$cust_id \
						$limit_type \
						$limit_value \
						$limit_period \
						$delay \
						$oper_id \
						$terminate_all \
						]} msg]} {
		ob::log::write ERROR {store_cust_self_excl: Failed update: $msg}
		catch {db_close $rs}
		return 0
	}
	db_close $rs
	return 1
}


##############################################################################
# Procedure :   get_cust_ccy_max_deposit args
# Description : binds up the currency and its max deposit for a given customer
# Input :       none apart from cust_id
# Output :      list of form {<ccy_code> <ccy_max_deposit>}
# Author :      JDM, 26-03-2001
##############################################################################
proc get_cust_ccy_max_deposit {cust_id {cpm ""}} {

	if {[catch {set rs [tb_db::tb_exec_qry get_ccy_max_deposit $cust_id]} msg]} {
		ob::log::write ERROR {get_cust_ccy_max_deposit: query failed: $msg}
		catch {db_close $rs}
		return [list 0]
	}

	if {[db_get_nrows $rs] == 0} {
		ob::log::write ERROR {get_cust_ccy_max_deposit -> Failed to get stored ccy max deposit details}
		db_close $rs
		return [list 0]
	}

	set ccy_code    [db_get_col $rs 0 ccy_code]
	set max_deposit [db_get_col $rs 0 max_deposit]
	db_close $rs

	if {$cpm != ""} {
		if {[catch {set rs [tb_db::tb_exec_qry get_ccy_max_deposit_cpm $cpm]} msg]} {
			ob::log::write ERROR {get_ccy_max_deposit_cpm: query failed: $msg}
			catch {db_close $rs}
			return [list 0]
		}

		set max_deposit [db_get_coln $rs 0 1]
		db_close $rs
	}

	return [list $ccy_code $max_deposit]
}


###############################################
# Procedure :   get_cust_ccy_max_deposit args
# Description : binds up the limits for all currencies
###############################################
proc bind_all_max_dep_info args {
	ob::log::write INFO {==>bind_all_max_dep_info}

	global DEP_LIMITS

	set limits [list]

	#
	# Get all available max_deposit ccy values
	#
	set result_set [OB_srp::get_all_currency_limits]
	set nrows [db_get_nrows $result_set]

	#
	# Populate the DEP_LIMITS array
	#
	for {set i 0} {$i < $nrows} {incr i} {
		set DEP_LIMITS($i,dep_ccy) [db_get_col $result_set $i ccy_name]
		set DEP_LIMITS($i,dep_val) [db_get_col $result_set $i limit_value]
	}

	#
	# Bind up the necessary vars
	#
	set  DEP_LIMITS(num_limits) $nrows
	tpBindVar dep_ccy DEP_LIMITS dep_ccy    dep_limit_idx
	tpBindVar dep_val DEP_LIMITS dep_val    dep_limit_idx


	#
	# Close the result set
	#
	db_close $result_set
}

##############################################################################
# Procedure :   bind_limit_details
# Description : binds details of a customers srp limits and also sets up
#               the allowed deposit limits for their currency
# Input :       cust_id
# Output :      1 if successful , 0 if fails
##############################################################################
proc bind_limit_details {cust_id {cpm ""}} {


	# first get the default limits for the customer's ccy
	set ccy_details [OB_srp::get_cust_ccy_max_deposit $cust_id $cpm]
	if {[lindex $ccy_details 0] == 0} {
		return 0
	}
	set ccy_code [lindex $ccy_details 0]
	tpBindString ccy_max_dep [lindex $ccy_details 1]

	# now get the customer's details and bind them up
	set limit_details [OB_srp::get_deposit_details $cust_id $cpm]

	if {[lindex $limit_details 0] == -1} {
		ob::log::write ERROR "bind_limit_details failed. Could not get customers limits"
		return 0
	}

	set limit_amount           [lindex $limit_details 0]
	set limit_period             [lindex $limit_details 1]
	set no_amt_limit           [lindex $limit_details 2]

	if {$limit_period == "1"} {
		tpSetVar SRP_DEP_TIME 0
		tpBindString srp_frq 0
	} else {
		tpSetVar SRP_DEP_TIME 1
		tpBindString srp_frq 1
	}
	tpBindString MAX_DEPOSIT      $limit_amount
	tpBindString P_CCY_CODE $ccy_code
	tpBindString MAX_DEPOSIT_EXISTS [expr {$no_amt_limit == 0}]

	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS_MAX_FRQ 0]} {
		set limit_frequency   [lindex $limit_details 3]
		set no_frq_limit      [lindex $limit_details 4]
		tpBindString MAX_FRQ_DEPOSIT_EXISTS   [expr {$no_frq_limit ==0}]
		tpBindString FRQ_DEPOSIT              $limit_frequency
	}

	#
	# then bind up the currency specific limit information
	#
	if {$no_amt_limit} {
		set cust_limit 0
	} else {
		set cust_limit $limit_amount
	}

	tpSetVar cust_selected_max_dep $cust_limit

	# now bind up the available limits for the customers currency
	if {[bind_available_ccy_limits $ccy_code $cust_limit] == 0} {
		# error - limits not bound
		return 0
	}

	return 1
}

#############################################################################
# Procedure :   bind_available_ccy_limits
# Description : binds details of the available limits for a given currency. Also adds in details of the
#                        customers limit if provided
# Input :            ccy_code , cust_limit
# Output :         1 if successful , 0 if fails
##############################################################################
proc bind_available_ccy_limits {ccy_code {cust_limit 0}} {

	global DEP_LIMITS

	if {[info exists DEP_LIMITS]} {
		unset DEP_LIMITS
	}

	set limits [list]

	# Get ccy's limit values
	set result_set [OB_srp::get_currency_limits $ccy_code]
	if {$result_set == 0} {
		ob::log::write ERROR "bind_limit_details failed. Could not get currency limits"
		return 0
	}
	set nrows [db_get_nrows $result_set]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend limits [db_get_col $result_set $i limit_value]
	}
	db_close $result_set

	# Add customer's preferred limit if not already added
	if {$cust_limit != 0 && [lsearch $limits $cust_limit] < 0} {
		lappend limits $cust_limit
	}
	set limits [lsort -integer $limits]

	# Build up a list of limit values
	set num_limits [llength $limits]
	for {set i 0} {$i < $num_limits} {incr i} {
		set limit [lindex $limits $i]
		set DEP_LIMITS($i,dep_limit) $limit
		if {$limit == $cust_limit} {
			set DEP_LIMITS($i,dep_selected) "1"
		} else {
			set DEP_LIMITS($i,dep_selected) ""
		}
	}

	tpBindString ccy_code $ccy_code
	tpSetVar dep_limit_num $num_limits
	tpBindVar dep_limit    DEP_LIMITS dep_limit    dep_limit_idx
	tpBindVar dep_selected DEP_LIMITS dep_selected dep_limit_idx

	# everything successfully bound
	return 1
}

##############################################################################
# Procedure:    get_max_poker_txn_amt
# Description:  gets maximum amount user can deposit or withdraw into their
#               poker account.
#               Difference between allowable over 10 days or last limit change
#               and amount already deposited, or withdrawn.
#               Replaces get_max_amt_to_withdraw and get_max_amt_to_deposit.
# Input         String "dep" or "wtd" for deposit or withdrawal respectively
# Output        Numerical representation of above.
# Author        jrennison, 28-04-2002
##############################################################################
proc get_max_poker_txn_amt {txn cust_id ccy_code country_code {level ""}} {

	#Find out maximum deposit and withdrawal allowd.
	#Find out total deposit or withdrawal amount over last 6 days, or since
	#last limit change, if more recent.
	#Subtract total from maximum and return.

	set txn_limit    [get_poker_txn_limit $txn $cust_id $ccy_code $country_code $level]
	set total_return [OB_srp::get_total_poker $txn $cust_id]
	if {[lindex $total_return 0] == 1} {

		set max_txn_amt  [expr {[lindex $txn_limit 1] - [lindex $total_return 1]}]

	} else {

		return 0

	}

	if {$max_txn_amt < 0 } {

		return 0

	} else {

		return $max_txn_amt
	}
}

##############################################################################
# Procedure:    get_poker_txn_limit
# Description:  Gets transaction limit for Poker account.
#               Replaces get_max_deposit and get_max_withdrawal
# Input:        String "wtd" or "dep" denoting transaction type.,the currency and
#               country code of the customer. Optionally the poker level
#               (if already known) to save looking it up again
# Output:       list containing customers poker level and txn limit
# Author:       jrennison, 28-04-02
##############################################################################
proc get_poker_txn_limit {txn cust_id ccy_code country_code {level ""} } {

	if {$level == ""} {
		#level is 0,1,2 or 3 - default is 1
		set level [get_poker_level $cust_id]
	}

	#get txn limit
	switch $level {

		3 {return [list $level [lindex [OB_srp::get_cust_limit poker_max_$txn $cust_id] 0]]}

		2 -
		1 {
			if {$ccy_code == "GBP" && $country_code == "UK" && $txn == "dep"} {
				set txn_limit_pounds [OT_CfgGet MCS_POKER_MAX_DEP_UK_LEV_$level [OT_CfgGet MCS_POKER_MAX_DEP_LEV_$level]]
			} else {
				set txn_limit_pounds [OT_CfgGet MCS_POKER_MAX_[string toupper $txn]_LEV_$level]
			}
			return [list $level [convert_to_rounded_ccy $txn_limit_pounds $ccy_code]]
		}

		default {return [list 0 0]}
	}
}


##############################################################################
# Procedure:    get_min_poker_transaction
# Description:  returns minimum values for depositing or withdrawing from poker
#               account.  Retrieved from config file
# Input:        global LOGIN_DETAILS, type - either "wtd" or "dep"
# Output:       minimum allowable wtd or dep.
# Author:       sluke, 07-03-2002
##############################################################################
proc get_min_poker_transaction {type} {

	global LOGIN_DETAILS

	if {$type == "wtd"} {
		set amt [OT_CfgGet MCS_POKER_MIN_WTD]
	} else {
		set amt [OT_CfgGet MCS_POKER_MIN_DEP]
	}
	set amt [convert_to_rounded_ccy $amt ]
	return $amt
}


##############################################################################
# Procedure:    get_poker_level
# Description:  returns users poker level, which determines the amount they can
#               transfer to from their poker account.
# Input:        cust_id
# Output:       users level, as recorded in tcustomerflag.  If there is no entry
#               for the user in the table, the default value of 1 is used.
##############################################################################
proc get_poker_level {cust_id} {

	global DB

	if {[catch {
		set rs [tb_db::tb_exec_qry OB_srp::get_poker_level $cust_id]
	} msg]} {
		ob::log::write ERROR {get_poker_level query failed: $msg}
		return 1
	}

	if {[db_get_nrows $rs] > 0} {
		set level [db_get_col $rs 0 flag_value]
		db_close $rs
		return $level
	} else {
		ob::log::write DEV {user has no flag - setting level to 1}
		db_close $rs
		return 1
	}
}

################################################################################
# Procedure:    get_total_poker
# Description:  returns the amount deposited or withdrawn into poker account
#               over the past ten days or since the limit was last changed, if
#               more recent.
# Input:        USER_ID as a global variable
#               Either wtd or dep for withdrawal and deposit respectively.
# Output:       List of 0 for failure and 1 for success and number representing
#               total txns.
# Author:       jrennison, 28-04-2002
################################################################################
proc get_total_poker {txn cust_id} {

	set from_date 0

	if {[catch {
		set rs [tb_db::tb_exec_qry get_poker_limit_change_time $cust_id poker_max_$txn]
		if {[db_get_nrows $rs] > 0} {
			set from_date [db_get_col $rs 0 from_date]
		}

		db_close $rs

	} msg]} {
		ob::log::write INFO {get_total_poker: query failed: $msg}
		return [list 0 0]
	}

	set ndays [OT_CfgGet MCS_POKER_SRP_DAYS 6]
	set ndays_ago_sec [expr {[clock seconds] - $ndays * 24 * 60 * 60}]

	if {$from_date != 0 && $from_date != "1900-01-01 00:00:00"} {

		set from_date_sec [ifmx_date_to_secs $from_date]

		if {$from_date_sec < $ndays_ago_sec} {

			set from_date [get_ifmx_date $ndays_ago_sec]
		}

	} else {
		set from_date [get_ifmx_date $ndays_ago_sec]
	}

	if {[catch {

		set result_set [tb_db::tb_exec_qry get_poker_${txn}_sum $cust_id $from_date]
		set amount     [db_get_col $result_set 0 ${txn}amount]
		if {[string trim $amount] == ""} {
			set amount 0
		}
		db_close $result_set

	} msg]} {

		return [list 0 0]
	}
	return [list 1 $amount]
}


#############################################################################
# Procedure:    update_cust_poker_limit
# Description:  Updates a customers poker level and limit
# Input:        cust_id, level, ccy_code, old_level
# Output:       1 if successfully updated, 0 if fails
##############################################################################
proc update_cust_poker_limit {cust_id level ccy_code {old_level ""}} {

	global DB USERID

	if {$old_level == ""} {
		set old_level [get_poker_level $cust_id]
	}

	if {$level != $old_level} {
		#insert/update flag
		set res_poker_srp [tb_db::tb_exec_qry OB_srp::get_poker_level $cust_id]

		if {[db_get_nrows $res_poker_srp] == 1} {
			if {[catch {
				tb_db::tb_exec_qry OB_srp::upd_poker_level $level $cust_id
			} msg]} {
				ob::log::write ERROR {update_cust_poker_limit: \
				failed to update poker level: $msg}
				return 0
			}
		} else {
			if {[catch {
				tb_db::tb_exec_qry OB_srp::ins_poker_level $cust_id $level
			} msg]} {
				ob::log::write ERROR {update_cust_poker_limit: \
				failed to update poker level: $msg}
				return 0
			}
		}
		db_close $res_poker_srp
	}
	# Level is 0,1,2 or 3 - default is 1
	# Get max allowable deposit over 10 days
	# Txn limits may have changed even if level remains same.
	switch $level {

		3 {

			set max_dep [reqGetArg poker_max_dep]
			set max_wtd [reqGetArg poker_max_wtd]
		}

		2 -
		1 {

			set max_dep [convert_to_rounded_ccy [OT_CfgGet MCS_POKER_MAX_DEP_LEV_$level] $ccy_code]
			set max_wtd [convert_to_rounded_ccy [OT_CfgGet MCS_POKER_MAX_WTD_LEV_$level] $ccy_code]

		}

		default {

			set max_dep 0
			set max_wtd 0
		}
	}

	if {![OB_srp::store_cust_limit $cust_id poker_max_dep $max_dep "" "" $USERID 1]} {
		return 0
	}

	if {![OB_srp::store_cust_limit $cust_id poker_max_wtd $max_wtd "" "" $USERID 1]} {
		return 0
	}

	return 1
}

################################################################################
# Procedure:   get_rounded_exchange_rate
# Description: retrieves rounded exchange rate from txgameroundccy.
# Input:       currency code
# Output:      the rounded exchange rate, or 0 in the case of an error.
# Author:      sluke, 06-03-2002
################################################################################
proc get_rounded_exchange_rate {ccy_code} {

	if {[catch {set rs [tb_db::tb_exec_qry get_rounded_ccy $ccy_code]} msg]} {
		ob::log::write INFO {get_rounded_exchange_rate: query failed: $msg}
		return 0
	}

	if {[db_get_nrows $rs]} {
		set val [db_get_col $rs 0 round_exch_rate]
	} else {
		set val 0
	}

	db_close $rs
	return $val
}

##############################################################################
# Procedure:    convert_to_rounded_ccy
# Description:  converts currencies using txgameroundccy table
# Input:        LOGIN_DETAILS as a global var, and amt (in pounds) to be converted.
# Output:       amount in users local currency.
##############################################################################
proc convert_to_rounded_ccy {amt {currency ""}} {

	if {$currency == ""} {
		global LOGIN_DETAILS
		set currency $LOGIN_DETAILS(CCY_CODE)
	}

	set exch_rate [OB_srp::get_rounded_exchange_rate $currency]
	set conv_amt [format "%.2f" [expr {$amt * $exch_rate}]]
	return $conv_amt
}

##############################################################################
# Procedure:	cust_below_dep_limit_factor
# Description:	checks if the customer is below the factor specified of the
#               deposit limit
# Input:		cust id, factor to test against
# Returns:		list : either -1 (error), 0 (over factor), 1 (below factor)
##############################################################################
proc below_dep_limit_factor {cust_id factor} {

	set max_dep_allowed_res [OB_srp::get_deposit_details $cust_id]

	if {[lindex $max_dep_allowed_res 0] != -1} {
		set max_amount [lindex $max_dep_allowed_res 0]
	} else {
		return [list -1]
	}

	set amount [expr {(1 - $factor) * $max_amount}]
	return [OB_srp::cust_deposit_allowed $cust_id $amount]
}



init_srp args
# Close Namespace
}

