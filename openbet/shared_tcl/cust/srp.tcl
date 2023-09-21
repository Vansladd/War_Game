# $Id: srp.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle social responsibility programmes for customers
#
#
# Synopsis:
#     package require cust_srp ?4.5?
#
# Procedures:
#

package provide cust_srp 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5



# Variables
#
namespace eval ob_srp {

	variable INIT
	set INIT 0

	variable CFG
	variable DEP_LIMITS
}



#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One time initialisation
#
proc ob_srp::init {} {

	variable INIT
	variable CFG
	variable DEP_LIMITS

	if {$INIT} {
		return
	}

	# initialise the dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {ob_srp: init}

	# now get the cfg items
	foreach {item dflt} {
		daily_wtd_limit                  0.00
		overnight_wtd_limit              0.00
		allow_full_balance_wtd           0
		day_dep_limit_chng_period        -1
		week_dep_limit_chng_period       -1
		month_dep_limit_chng_period      -1
	} {
		set CFG($item) [OT_CfgGet [string toupper $item] $dflt]
	}

	_prepare_qrys

	set DEP_LIMITS(loaded) 0
	get_all_avail_dep_limits
	set INIT 1
}



# Prepare database queries
#
proc ob_srp::_prepare_qrys {} {

	variable CFG

	# what is the maximum deposit allowed for this user's currency
	ob_db::store_qry ob_srp::get_ccy_txn_limits {
		select
			c.min_deposit,
			c.max_deposit,
			c.min_withdrawal,
			c.max_withdrawal
		from
			tCcy c,
			tAcct a
		where
			a.cust_id  = ?
		and a.ccy_code = c.ccy_code
	}

	# get the limits that the user has defined (there could be none)
	ob_db::store_qry ob_srp::get_deposit_limits {
		select
			limit_type,
			limit_value,
			from_date,
			cr_date
		from
			tCustLimits
		where
		    cust_id        = ?
		and to_date        >= CURRENT
		and from_date      <= CURRENT
		and (tm_date        is null or
		tm_date > CURRENT)
		and limit_type     in ('max_dep_day_amt', 'max_dep_week_amt',
		                       'max_dep_month_amt')
	}

	# how much has the customer deposited since a given time
	ob_db::store_qry ob_srp::get_sum_deposits_since [subst {
		select
			NVL(count(*), 0) as depcount,
			NVL(sum(p.amount), 0.00) as amount
		from
			tPmt p,
			tAcct a
		where
			p.cr_date > ?
		and a.cust_id = ?
		and p.acct_id = a.acct_id
		and p.payment_sort = 'D'
		and p.status not in ([OT_CfgGet SRP_DEP_STATUS_IGNORE "'X','N'"])

		UNION ALL

		select
			NVL(count(*), 0) as depcount,
			NVL(sum(ma.amount), 0.00) as amount
		from
			tAcct a,
			tManAdj ma
		where
			ma.cr_date > ?
		and a.cust_id = ?
		and a.acct_id = ma.acct_id
		and ma.type   = "CSH"
	}]

	# clear current limits
	ob_db::store_qry ob_srp::clear_deposit_limits {
		update tCustLimits set
			tm_date        = ?,
			to_date        = ?
		where
		    cust_id        = ?
		and to_date        >= CURRENT
		and from_date      <= ?
		and (tm_date        is null
		or tm_date > CURRENT)
		and limit_type     in ('max_dep_day_amt', 'max_dep_week_amt',
		                       'max_dep_month_amt')
	}


	# set a limit!
	ob_db::store_qry ob_srp::set_deposit_limit {
		insert into tCustLimits (
			cust_id,
			limit_type,
			limit_value,
			from_date,
			to_date,
			cr_date,
			oper_id
		) values (
			?,
			?,
			?,
			?,
			'9999-12-31 23:59:59',
			CURRENT,
			?
		);
	}

	# apply some self exclusion
	ob_db::store_qry ob_srp::apply_self_excl {
		insert into tCustLimits (
			cust_id,
			limit_type,
			limit_value,
			from_date,
			to_date,
			cr_date,
			oper_id
		) values (
			?,
			'self_excl',
			?,
			CURRENT,
			CURRENT + ? units day,
			CURRENT,
			?
		);
	}

	ob_db::store_qry ob_srp::get_self_excl_info {
		select
			from_date,
			to_date
		from
			tCustLimits
		where
			cust_id            = ?
		and limit_type         = 'self_excl'
		and from_date          <= CURRENT
		and to_date            >= CURRENT
		and tm_date            is null
	}

	ob_db::store_qry ob_srp::self_excl_clearable {
		select
			from_date,
			to_date
		from
			tCustLimits
		where
			cust_id            = ?
		and limit_type         = 'self_excl'
		and to_date            <= CURRENT
		and tm_date            is null
	}

	ob_db::store_qry ob_srp::clear_self_excl {
		update tCustLimits set
			tm_date            = CURRENT,
			to_date            = CURRENT
		where
			cust_id            = ?
		and limit_type         = 'self_excl'
		and tm_date            is null
	}

	ob_db::store_qry ob_srp::set_no_contact {
		update tCustomerReg set
			contact_ok         = 'N',
			ptnr_contact_ok    = 'N',
			mkt_contact_ok     = 'N'
		where
			cust_id            = ?
	}

	ob_db::store_qry ob_srp::get_acct_details {
		select
			acct_id,
			ccy_code,
			balance
		from
			tAcct
		where
			cust_id        = ?
	}

	ob_db::store_qry ob_srp::get_exch_rate_qry {
		select
			exch_rate
		from
			tCCY
		where
			ccy_code = ?
	}

	ob_db::store_qry ob_srp::get_wtd_limit {
		select
			NVL(limit_value, -1) as wtd_lmt
		from
			tCustLimits
		where
			cust_id = ?
		and limit_type = 'cust_wtd_lmt'
			and from_date <= CURRENT
			and to_date >= CURRENT
			and tm_date is null
	}

	ob_db::store_qry ob_srp::get_withdrawn_amount {
		select
			NVL(sum(amount),0.00) as amount
		from
			tpmt
		where
			acct_id = ?
		and payment_sort = 'W'
		and status in ('Y','R','L','P')
		and cr_date > ?
		and cr_date < ?
	}

	# get all the available dep limits (all ccys)
	ob_db::store_qry ob_srp::get_all_avail_dep_limits {
		select
			trunc(setting_value * 1, 2) as dep_limit,
			setting_name as ccy_code
		from
			tSiteCustomVal
		order by
			ccy_code,
			dep_limit
	}
}



# Check a deposit against the limits specified
#
#   cust_id - the customer id
#   amount  - the amount (in the user's ccy) that they wish to deposit.
#             amount can be zero (useful to see if any deposit at all is allowed)
#   dep_lim_25 - are we checking if the customer is within 25% of their deposit limit?
#                if so, we don't want to consider currency deposit limits
#
proc ob_srp::check_deposit {cust_id amount {dep_lim_25 0}} {

	# TODO: check cust_id and amount are valid

	#
	# get the deposit limit for the user's currency
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_ccy_txn_limits $cust_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_ccy_txn_limits: $msg}
		return [list 0 0 0 SYSTEM_ERROR]
	}

	if {[db_get_nrows $rs] == 1} {
		# the ccy limit is the only thing that applies a lower bound to the deposit
		set min_deposit     [db_get_col $rs 0 min_deposit]
		set max_dep_ccy_amt [db_get_col $rs 0 max_deposit]

		ob_db::rs_close $rs
	} else {
		ob_db::rs_close $rs
		ob_log::write ERROR {num rows was not 1 for get_ccy_txn_limit $cust_id}
		return [list 0 0 0 SYSTEM_ERROR]
	}

	#
	# Want to ignore min dep limits for some channels (eg Telebet)
	#
	if {[OT_CfgGet DEP_LIM_IGNORE_MIN 0]} {
		set min_deposit 0
	}


	#
	# now get any deposit limits that the customer themselves have set
	#
	set cur_dep_limit [get_deposit_limit $cust_id]
	if {[lindex $cur_dep_limit 0] != 1} {
		ob_log::write ERROR {get_dep_limits returned $cur_dep_limit}
		return [list 0 0 0 SYSTEM_ERROR]
	}

	set max_dep_day_amt   ""
	set max_dep_week_amt  ""
	set max_dep_month_amt ""
	set cur_type [lindex $cur_dep_limit 1]
	switch -- $cur_type {
		day   {set max_dep_day_amt   [lindex $cur_dep_limit 2]}
		week  {set max_dep_week_amt  [lindex $cur_dep_limit 2]}
		month {set max_dep_month_amt [lindex $cur_dep_limit 2]}
		none  {}
	}
	ob_log::write INFO {check_deposit: max_dep_day_amt   = $max_dep_day_amt}
	ob_log::write INFO {check_deposit: max_dep_week_amt  = $max_dep_week_amt}
	ob_log::write INFO {check_deposit: max_dep_month_amt = $max_dep_month_amt}

	set inf_date_format {%Y-%m-%d %H:%M:%S}


	#
	# now work out the max deposit allowed without violating any of the srp limits
	# or the ccy limit
	#
	set max_deposit ""
	set exceeded_dep_limit 0

	if {[info tclversion] >= 8.5} {
		set max_limits_list [list\
		$max_dep_day_amt   [clock add [clock seconds] -1 day]\
		$max_dep_week_amt  [clock add [clock seconds] -1 week]\
		$max_dep_month_amt [clock add [clock seconds] -1 month]\
		]
	} else {
		set max_limits_list [list\
		$max_dep_day_amt   [clock scan {-1 day}   -base [clock seconds]]\
		$max_dep_week_amt  [clock scan {-1 week}  -base [clock seconds]]\
		$max_dep_month_amt [clock scan {-1 month} -base [clock seconds]]\
		]
	}

	# check the customer srp limits
	foreach {max_dep_amt start_date} $max_limits_list {
		# if the limit hasn't been set, no need to check!
		if {$max_dep_amt == ""} {
			continue
		}

		# how much has the user deposited since the start time?
		set start_time  [clock format $start_date -format $inf_date_format]
		set cur_dep_amt [lindex [_get_sum_deposits_since $cust_id $start_time] 0]

		set allowed_dep_amt [dec_round [expr {$max_dep_amt - $cur_dep_amt}]]

		ob_log::write 5 {cust $cust_id has deposited $cur_dep_amt \
			since $start_time allowed_amt $allowed_dep_amt}

		if {$allowed_dep_amt <= 0} {
			# customer has already exceeded the limit
			set max_deposit 0
			set exceeded_dep_limit 1
			break
		}

		if {$allowed_dep_amt < $amount} {
			# customer hasn't exceeded limit yet, but this deposit isn't allowed
			# don't break out of loop yet, because we still want to calc max_deposit
			set exceeded_dep_limit 1
		}

		if {$max_deposit == "" || $allowed_dep_amt < $max_deposit} {
			set max_deposit $allowed_dep_amt
		}
	}

	# now check the ccy limits
	if {!$dep_lim_25 && ($amount > $max_dep_ccy_amt)} {
		set exceeded_dep_limit 1
	}
	if {!$dep_lim_25 && ($max_deposit == "" || $max_dep_ccy_amt < $max_deposit)} {
		set max_deposit $max_dep_ccy_amt
	}

	# if they can't even cover the min deposit, then they can't do a deposit!
	if {$min_deposit > $max_deposit && $max_deposit !=""} {
		OT_LogWrite 5 "Cust $cust_id Can't cover deposit limit. \
			Min: $min_deposit Max: $max_deposit"
		return [list 0 0 0 NO_DEPOSIT_ALLOWED]
	}

	if {$exceeded_dep_limit} {
		OT_LogWrite 5 "Cust $cust_id Deposit limit exceeded. \
			min:: $min_deposit max:: $max_deposit"
		return [list 0 $min_deposit $max_deposit EXCEEDED_DEP_LIMIT]
	}

	if {$amount > 0 && $amount < $min_deposit} {
		OT_LogWrite 5 "Cust $cust_id Amount of $amount is under deposit \
			limit of $min_deposit."

		return [list 0 $min_deposit $max_deposit UNDER_MIN_DEP_LIMIT]
	}


	# all ok!
	OT_LogWrite 5 "Deposit limit check sucessful min: $min_deposit max: $max_deposit"
	return [list 1 $min_deposit $max_deposit OK]
}



proc ob_srp::check_withdrawal {cust_id amount {no_wtd_to_card 1}} {

	variable CFG

	ob_log::write DEBUG {check_withdrawal cust_id=$cust_id amount=$amount no_wtd_to_card=$no_wtd_to_card}

	set max_wtd_limit 0.00
	set min_wtd_limit 0.00
	set limit_type "WTD_CCY"

	set acct_details [_get_acct_details $cust_id]
	if {[lindex $acct_details 0] != 1} {
		ob_log::write ERROR {invalid acct details for cust $cust_id. Got $acct_details instead}
		return [list 0 0 0 SYSTEM_ERROR]
	}
	set acct_id  [lindex $acct_details 1]
	set ccy_code [lindex $acct_details 2]
	set balance  [lindex $acct_details 3]


	#
	# get the withdrawal limit for the user's currency
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_ccy_txn_limits $cust_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_ccy_txn_limits: $msg}
		return [list 0 0 0 SYSTEM_ERROR]
	}
	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set min_wtd_limit [db_get_col $rs 0 min_withdrawal]
		set max_wtd_limit [db_get_col $rs 0 max_withdrawal]
	} else {
		ob_log::write ERROR {num rows was not 1 (it was $nrows) instead}
		return [list 0 0 0 SYSTEM_ERROR]
	}
	ob_db::rs_close $rs

	#
	# Get the customer specific limits
	#
	set exch_rate 1
	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_exch_rate $ccy_code]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_exch_rate}
	} else {
		set nrows [db_get_nrows $rs]
		if {$nrows} {
			set exch_rate [db_get_col $rs 0 exch_rate]
		} else {
			ob_log::write ERROR {no rows returned for get_exch_rate}
			return [list 0 0 0 SYSTEM_ERROR]
		}
	}
	set daily_wtd_limit     [expr {$exch_rate * $CFG(daily_wtd_limit)}]
	set overnight_wtd_limit [expr {$exch_rate * $CFG(overnight_wtd_limit)}]


	#
	# Get any customer set limit
	#
	set cust_wtd_limit -1
	if [catch {
		set rs [ob_db::exec_qry ob_srp::get_wtd_limit $cust_id]
	} msg] {
		ob::log::write ERROR "DB: get_wtd_limit: $msg"
	} else {
		if {[db_get_nrows $rs]} {
			set cust_wtd_limit [db_get_col $rs 0 wtd_lmt]
		}
		ob_db::rs_close $rs
	}


	#
	# Get amount currently withdrawn today and overnight
	#
	set    overnight_start [clock format [expr {[clock seconds] - (60 * 60 * 24)}] -format "%Y-%m-%d"]
	append overnight_start " 23:00:00"
	set    overnight_end   [clock format [clock seconds] -format "%Y-%m-%d"]
	append overnight_end   " 09:00:00"
	set    begin_today     [clock format [clock seconds] -format "%Y-%m-%d"]
	append begin_today     " 00:00:00"
	set    now             [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	set is_overnight [expr {$now > $overnight_start && $now < $overnight_end ? 1 : 0}]
	set overnight_total 0.00
	set daily_total 0.00

	if {$is_overnight} {
		if [catch {
			set rs [ob_db::exec_qry ob_srp::get_withdrawn_amount $acct_id $overnight_start $overnight_end]
		} msg] {
			ob::log::write ERROR "DB: get_withdrawn_amount: $msg"
		} else {
			set overnight_total [db_get_col $rs 0 amount]
			ob_db::rs_close $rs
		}
	}

	if [catch {
		set rs [ob_db::exec_qry ob_srp::get_withdrawn_amount $acct_id $begin_today $now]
	} msg] {
		ob::log::write ERROR "DB: get_withdrawn_amount: $msg"
	} else {
		set daily_total [db_get_col $rs 0 amount]
		ob_db::rs_close $rs
	}

	#
	# Choose which limit
	#
	if {$cust_wtd_limit > 0 && $cust_wtd_limit < $max_wtd_limit} {
		set max_wtd_limit [expr {$cust_wtd_limit - $daily_total}]
		set max_wtd_limit [expr {$max_wtd_limit > 0 ? $max_wtd_limit : 0.00}]
		set limit_type "WTD_CUST"
	}

	if {$cust_wtd_limit == -1 && $limit_type != "WTD_CUST" && $is_overnight && [expr {$overnight_wtd_limit - $overnight_total}] < $max_wtd_limit} {
		set max_wtd_limit [expr {$overnight_wtd_limit - $overnight_total}]
		set max_wtd_limit [expr {$max_wtd_limit > 0 ? $max_wtd_limit : 0.00}]
		set limit_type "WTD_NIGHT"
	}

	if {$cust_wtd_limit == -1 && $limit_type != "WTD_CUST" && [expr {$daily_wtd_limit - $daily_total}] < $max_wtd_limit} {
		set max_wtd_limit [expr {$daily_wtd_limit - $daily_total}]
		set cust_daily_wtd_limit $daily_wtd_limit
		set max_wtd_limit [expr {$max_wtd_limit > 0 ? $max_wtd_limit : 0.00}]
		set limit_type "WTD_DAILY"
	}

	# Check balance again
	if {$max_wtd_limit > $balance} {
		set max_wtd_limit $balance
		set limit_type "WTD_BALANCE"
	}

	# Allow full balance withdrawal if less than minimum (within a reasonable limit...)
	if {$CFG(allow_full_balance_wtd) && $balance > 0 && $balance < $min_wtd_limit} {
		set min_wtd_limit $balance
	}

	set min_wtd_limit [format "%.2f" $min_wtd_limit]
	set max_wtd_limit [format "%.2f" $max_wtd_limit]

	if {$amount != ""} {
		#
		# Check the amount against limits
		#
		if [catch {set amount [format "%.2f" $amount]}] {
			return [list 0 0.00 0.00 AMOUNT_INVALID]
		} elseif {$amount < $min_wtd_limit} {
			return [list 0 $min_wtd_limit $max_wtd_limit AMT_WTD_MIN]
		} elseif {$amount > $max_wtd_limit} {
			return [list 0 $min_wtd_limit $max_wtd_limit AMT_${limit_type}]
		} else {
			return [list 1 $min_wtd_limit $max_wtd_limit ""]
		}

	} else {
		#
		# Check that the max allowed > min
		#
		if {$min_wtd_limit > $max_wtd_limit} {
			return [list 0 $min_wtd_limit $max_wtd_limit LMT_${limit_type}]
		} else {
			return [list 1 $min_wtd_limit $max_wtd_limit ""]
		}
	}
}



# Get the currently set deposit limit for a customer.
#
#  Returns a list of
#     [0 err_msg] - if an error occurred
#     [1 none] - if no limit set
#     [1 type amount allow_incr] if a limit is set
#         type = day|week|month
#         amount = a number
#         allow_incr = 0|1 (whether the user can increase the limit)
#
proc ob_srp::get_deposit_limit {cust_id} {

	set max_dep_day_amt     ""
	set max_dep_day_start   ""
	set max_dep_week_amt    ""
	set max_dep_week_start  ""
	set max_dep_month_amt   ""
	set max_dep_month_start ""

	if {[catch {
		set rs [ob_db::exec_qry_force ob_srp::get_deposit_limits $cust_id]
	} msg]} {
		ob::log::write ERROR "couldn't exec ob_srp::get_deposit_limits: $msg"
		return [list 0 SYSTEM_ERROR]
	}

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		set limit_type  [db_get_col $rs $i limit_type]
		set limit_value [db_get_col $rs $i limit_value]
		set limit_start [db_get_col $rs $i from_date]

		switch -- $limit_type {
			max_dep_day_amt {
				set max_dep_day_amt   $limit_value
				set max_dep_day_start $limit_start
			}
			max_dep_week_amt {
				set max_dep_week_amt   $limit_value
				set max_dep_week_start $limit_start
			}
			max_dep_month_amt {
				set max_dep_month_amt   $limit_value
				set max_dep_month_start $limit_start
			}
		}
	}
	# there shouldn't be more than one limit, but if there is, just return
	# the daily one (or the weekly one if no daily)

	if {$max_dep_day_amt != ""} {
		set allow_incr [allow_incr_dep_limit day $max_dep_day_start]
		return [list 1 day $max_dep_day_amt $allow_incr]
	}

	if {$max_dep_week_amt != ""} {
		set allow_incr [allow_incr_dep_limit week $max_dep_week_start]
		return [list 1 week $max_dep_week_amt $allow_incr]
	}

	if {$max_dep_month_amt != ""} {
		set allow_incr [allow_incr_dep_limit month $max_dep_month_start]
		return [list 1 month $max_dep_month_amt $allow_incr]
	}
	# no dep limits!
	return [list 1 none]
}



# Set the customers deposit limit
#
proc ob_srp::set_deposit_limit {cust_id type amount args} {

	ob_log::write DEBUG {set_deposit_limits cust_id=$cust_id type=$type amount=$amount args=$args}

	set force             0
	set do_tran           1
	set oper_id           ""

	foreach {name value} $args {
		switch -- $name {
			-oper_id           {set oper_id           $value}
			-force             {set force             $value}
			-do_tran           {set do_tran           $value}
		}
	}

	set allowed_types [list "" none day week month]
	if {[lsearch $allowed_types $type] == -1} {
		return [list 0 [string toupper INVALID_TYPE_$type]]
	}

	if {$type == "" || $type == "none" || $amount == ""} {
		ob_log::write INFO {type=$type amount=$amount cust is trying to clear dep limit}
		set amount ""
		set type   none
	}

	# get the existing limit
	set cur_dep_limit [get_deposit_limit $cust_id]

	if {[lindex $cur_dep_limit 0] != 1} {
		ob_log::write ERROR {Couldn't get existing dep limit : $cur_dep_limit}
		return $cur_dep_limit
	}

	set cur_type [lindex $cur_dep_limit 1]
	if {$cur_type != "none"} {
		set cur_amount [lindex $cur_dep_limit 2]
		set allow_incr [lindex $cur_dep_limit 3]
	} else {
		set cur_amount 0
		set allow_incr 1
	}

	set allow_change 1
	# if FUNC_DEPOSIT_LIMIT_DAILY_ONLY==1, apply the change after 24hours
	# only if we are raising the limit, not lowering or creating a new one
	set update_later 0


	if {$cur_type == "none"} {
		ob_log::write DEBUG {no current deposit limit, anything is allowed!}
		set allow_change 1

	} elseif {$cur_type == $type} {
		# both the types are the same, we can just compare the amounts
		if {($amount > $cur_amount || $amount == "")} {
			if {!$allow_incr && !$force} {
				set allow_change 0
			}
			if {!$force} {
				set update_later 1
			}
		}

	} else {
		# customer has an existing limit but it's not the same type
		# we'll have to do some annoying calculations
		set new_ave [_ave_limit_per_day $type $amount]
		set cur_ave [_ave_limit_per_day $cur_type $cur_amount]

		if {($type == "none" || $new_ave > $cur_ave) && !$allow_incr && !$force} {
			ob_log::write DEV {new limit is 'more' than old, disallowing}
			set allow_change 0
		} elseif {$type == "none" || $new_ave > $cur_ave} {
			if {$force} {
				set update_later 0
			} else {
				set update_later 1
			}
		}

	}

	if {!$allow_change} {
		return [list 0 DEP_LIMIT_CANT_CHANGE]
	}

	if {$do_tran} {
		ob_db::begin_tran
	}

	if {[OT_CfgGet FUNC_DEPOSIT_LIMIT_DAILY_ONLY 0] == 1 &&
		$update_later == 1} {
		# {+1 day} doesn't work in tcl 8.5 and [clock add] in 8.4
		set limit_from [clock scan {+86400 seconds} -base [clock seconds]]
	} else {
		set limit_from [clock seconds]
	}
	set limit_from [clock format $limit_from -format "%Y-%m-%d %H:%M:%S"]

	# now clear the existing limits
	if {[catch {
		ob_db::exec_qry ob_srp::clear_deposit_limits $limit_from\
			$limit_from $cust_id $limit_from
	} msg]} {
		if {$do_tran} {
			ob_db::rollback_tran
		}
		ob_log::write ERROR {Couldn't exec clear_deposit_limits: $msg}
		return [list 0 SYSTEM_ERROR]
	}

	set db_type max_dep_${type}_amt

	# add a new limit if specified
	if {$type != "none"} {
		if {[catch {
			ob_db::exec_qry ob_srp::set_deposit_limit $cust_id\
			 $db_type $amount $limit_from $oper_id
		} msg]} {
			if {$do_tran} {
				ob_db::rollback_tran
			}
			ob_log::write ERROR {Couldn't exec set_deposit_limit: $msg}
			return [list 0 SYSTEM_ERROR]
		}
	}

	if {$do_tran} {
		ob_db::commit_tran
	}
	return [list 1]
}



# Based on the time that the limit was set, is the limit allowed to be increased?
# (or cleared)
#
#   type = day|week|month
#

proc ob_srp::allow_incr_dep_limit {type time_set} {
	variable CFG

	switch -- $type {
		day {
			if {$CFG(day_dep_limit_chng_period) > -1} {
				set num_days $CFG(day_dep_limit_chng_period)
				set allowed_time [clock scan "-$num_days days"\
				 -base [clock seconds]]
			} else {
				set allowed_time [clock scan {-1 week}\
				 -base [clock seconds]]
			}
		}

		week {
			if {$CFG(week_dep_limit_chng_period) > -1} {
				set num_days $CFG(week_dep_limit_chng_period)
				set allowed_time [clock scan "-$num_days days"\
				 -base [clock seconds]]
			} else {
				set allowed_time [clock scan {-2 weeks}\
				 -base [clock seconds]]
			}
		}

		month {
			if {$CFG(month_dep_limit_chng_period) > -1} {
				set num_days $CFG(month_dep_limit_chng_period)
				set allowed_time [clock scan "-$num_days days"\
				 -base [clock seconds]]
			} else {
				set allowed_time [clock scan {-1 month}\
				 -base [clock seconds]]
			}
		}

		default {
			return 0
		}
	}

	# do some formatting otherwise the comparison won't work
	set allowed_time [clock format $allowed_time -format {%Y-%m-%d %H:%M:%S}]

	# if the limit was set after the earliest allowed time, disallow
	return [expr {$time_set < $allowed_time}]
}



# Apply self exclusion for a customer to the date specified
#
proc ob_srp::apply_self_excl_until {cust_id to_date {oper_id ""} {override "N"}} {
	# compute num_days here and pass to apply_self_excl
	set num_days [expr ([clock scan $to_date] - [clock seconds]) / 86400]
	set min_days [OT_CfgGet SRP_SELF_EXCL_MIN_DAYS 180]
	incr num_days
	if {$num_days < 0} {
		set num_days 0
	}
	if {$override == "Y" ||
	    $num_days >= $min_days
	} {
		if {[OT_CfgGet USE_SELF_EXCL_MAX 0]} {
			set max_days [expr ([OT_CfgGet SELF_EXCL_MAX_YEARS 5] * 365)]
			if {$num_days > $max_days} {
				ob_log::write ERROR {Error self exclusion less more than max days or date wrong: $to_date}
				return [list 0 SYSTEM_ERROR]
			} else {
				return [apply_self_excl $cust_id $num_days $oper_id $override]
			}
		} else {
			return [apply_self_excl $cust_id $num_days $oper_id $override]
		}
	} else {
		ob_log::write ERROR {Error self exclusion less than $min_days days or date wrong: $to_date}
		return [list 0 EXCL_TO_SMALL]
	}
}



# Apply self excusion for a customer
# can use override = Y to set a period shorter than current period.
#
proc ob_srp::apply_self_excl {cust_id num_days {oper_id ""} {override "N"}} {

	# get active self exclusion and ensure number of days remaining on this
	# is not more than the number of days for the new exclusion
	foreach {ok from_date to_date} [check_self_excl $cust_id] {}

	if {!$ok} {
		ob_log::write ERROR {couldn't retrieve exclusion info}
		return [list 0 SYSTEM_ERROR]
	}

	if {$override != "Y" &&
	    $to_date != ""
	} {
		set expiry_num_days [expr {([clock scan $to_date] - [clock seconds]) / (60 * 60 * 24)}]
		if {$expiry_num_days > $num_days} {
			# trying to decrease exclusion period
			return [list 0 REDUCE_EXCL]
		}
	}

	ob_db::begin_tran

	# clear existing exclusions (force as we know we're not decreasing it)
	foreach {ok msg} [clear_self_excl $cust_id -force 1 -do_tran 0] {}

	if {!$ok} {
		ob_db::rollback_tran
		ob_log::write ERROR {couldn't clear self exclusion : $msg}
		return [list 0 $msg]
	}

	if {[catch {
		ob_db::exec_qry ob_srp::apply_self_excl $cust_id $num_days $num_days $oper_id
	} msg]} {
		ob_db::rollback_tran
		ob_log::write ERROR {couldn't exec apply_self_excl : $msg}
		return [list 0 SYSTEM_ERROR]
	}

	if {[catch {
		ob_db::exec_qry ob_srp::set_no_contact $cust_id
	} msg]} {
		ob_db::rollback_tran
		ob_log::write ERROR {couldn't exec set_no_contact : $msg}
		return [list 0 SYSTEM_ERROR]
	}

	ob_db::commit_tran

	return [list 1 OK]
}



# Clear self-exclusion if active
#
proc ob_srp::clear_self_excl {cust_id args} {

	ob_log::write DEBUG {clear_self_excl cust_id=$cust_id args=$args}

	# optional args
	set force   0
	set do_tran 1

	foreach {name value} $args {
		switch -- $name {
			-force      {set force   $value}
			-do_tran    {set do_tran $value}
		}
	}

	# is the self exclusion still active?
	foreach {ok from_date to_date} [check_self_excl $cust_id] {}

	if {!$ok} {
		ob_log::write ERROR {Error retrieving self exclusion status}
		return [list 0 SYSTEM_ERROR]
	}

	if {$to_date != "" && !$force} {
		ob_log::write WARNING {Customer has an active self exclusion}
		return [list 0 SELF_EXCL_ACTIVE]
	}

	if {$do_tran} {
		ob_db::begin_tran
	}

	# remove the existing self exclusion
	if {[catch {
		ob_db::exec_qry ob_srp::clear_self_excl $cust_id
	} msg]} {

		if {$do_tran} {
			ob_db::rollback_tran
		}
		ob_log::write ERROR {Couldn't clear self_excl $msg}
		return [list 0 SYSTEM_ERROR]
	} else {

		if {$do_tran} {
			ob_db::commit_tran
		}
		ob_log::write INFO {Successfully cleared any self exclusions}
	}

	return [list 1 OK]
}



# Check if a customer is self-excluded
#
# returns list {<ok> <from_date> ?<to_date>?}
# from_date will be error msg and to_date will be "" if not ok
#
proc ob_srp::check_self_excl {cust_id} {

	ob_log::write DEBUG {check_self_excl cust_id=$cust_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_self_excl_info $cust_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_self_excl_info : $msg}
		return [list 0 SYSTEM_ERROR ""]
	}

	# no rows indicates no self-exclusion!
	if  {[db_get_nrows $rs] == 0} {
		ob_log::write DEBUG {no rows found!}
		ob_db::rs_close $rs
		return [list 1 "" ""]
	}

	# the customer has set self-exclusion
	set to_date     [db_get_col $rs 0 to_date]
	set from_date   [db_get_col $rs 0 from_date]
	ob_db::rs_close $rs

	ob_log::write DEBUG {from_date=$from_date to_date=$to_date}

	return [list 1 $from_date $to_date]
}



# Does the self excluded customer need clearing?
#
# returns list {<ok>  <from_date> ?<to_date>?}
# returns list {<err> <error_msg> ""}
#
proc ob_srp::check_self_excl_clear_req {cust_id} {

	ob_log::write DEBUG {check_self_excl_termination cust_id=$cust_id}

	if {[catch {
		set rs [ob_db::exec_qry ob_srp::self_excl_clearable $cust_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec self_excl_clearable : $msg}
		return [list 0 SYSTEM_ERROR ""]
	}

	set is_clearable 0
	set from_date {}
	set to_date   {}

	# no rows indicates no self-exclusion!
	if  {[db_get_nrows $rs] == 1} {
		set is_clearable 1
		set from_date [db_get_col $rs 0 from_date]
		set to_date   [db_get_col $rs 0 to_date]
	}

	ob_db::rs_close $rs
	return [list $is_clearable $from_date $to_date]
}



# get a list of all available deposit limits
#
proc ob_srp::get_all_avail_dep_limits args {

	set ccy_code_filter ""
	set no_cache 0
	foreach {name value} $args {
		switch -- $name {
			-ccy_code {set ccy_code_filter $value}
			-no_cache {set no_cache $value}
		}
	}

	variable DEP_LIMITS

	# do we actually need to run the query?
	if {$no_cache || !$DEP_LIMITS(loaded)} {
		set rs [ob_db::exec_qry ob_srp::get_all_avail_dep_limits]

		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {
			set ccy_code  [db_get_col $rs $i ccy_code]
			set dep_limit [db_get_col $rs $i dep_limit]

			if [info exists DEP_LIMITS(${ccy_code}_total)] {
				incr DEP_LIMITS(${ccy_code}_total)
			} else {
				set DEP_LIMITS(${ccy_code}_total) 1
			}

			set idx [expr {$DEP_LIMITS(${ccy_code}_total) - 1}]
			set DEP_LIMITS($ccy_code,$idx) [format %.2f $dep_limit]
		}

		ob_db::rs_close $rs
		set DEP_LIMITS(loaded) 1
	}

	if {$ccy_code_filter != ""} {
		return [array get DEP_LIMITS ${ccy_code_filter}*]
	}

	return [array get DEP_LIMITS]
}


# Get the sum total of all deposits by a customer in the deposit limit period
#
proc ob_srp::get_cust_dep_totals {cust_id period} {

	# Translate period from string to number of days
	switch -- $period {
		"day"   {set num_days 1}
		"week"  {set num_days 7}
		"month"  {set num_days 30}
		default {
			ob_log::write ERROR {get_cust_dep_totals failed : \
				You must supply a valid limit period (day|week|month)}
			return [list -1]
		}
	}

	set inf_date_format {%Y-%m-%d %H:%M:%S}

	if {[info tclversion] >= 8.5} {
		set start_time [clock add [clock seconds] -${num_days} day]
	} else {
		set start_time [clock scan "-${num_days} day" -base [clock seconds]]
	}

	set start_time  [clock format $start_time -format $inf_date_format]
	set res         [_get_sum_deposits_since $cust_id $start_time]
	set cur_dep_amt [lindex $res 0]
	set dep_count   [lindex $res 1]

	ob_log::write 5 {cust $cust_id has deposited $cur_dep_amt \
		since $start_time. dep_count: $dep_count}

	return [list $cur_dep_amt $dep_count]
}


# Get the sum total of all deposits by a customer since a specific time
#
proc ob_srp::_get_sum_deposits_since {cust_id start_time} {

	# how much has this customer deposited since start time
	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_sum_deposits_since \
			$start_time $cust_id $start_time $cust_id]
	} msg]} {
		ob_log::write ERROR {get_sum_deposits_since couldn't be execd: $msg}
		error $msg
	}

	if {![db_get_nrows $rs]} {
		ob_log::write ERROR {get_sum_deposits returned no rows}
		error NO_ROWS_RETURNED
	}

	set current_dep_amt [db_get_col $rs 0 amount]
	set current_dep_cnt [db_get_col $rs 0 depcount]

	if {[OT_CfgGet DEP_LIM_INCLUDE_MAN_ADJ 0]} {
		set current_dep_amt [expr $current_dep_amt + [db_get_col $rs 1 amount]]
		set current_dep_cnt [expr $current_dep_cnt + [db_get_col $rs 1 depcount]]
	}

	ob_db::rs_close $rs

	return [list $current_dep_amt $current_dep_cnt]
}


# Get the max deposit limit for a customer
#
proc ob_srp::get_cust_max_deposit {cust_id} {

    if {[catch {set rs [ob_db::exec_qry ob_srp::get_ccy_txn_limits $cust_id]} msg]} {
        ob_log::write ERROR {ob_srp::get_cust_max_deposit: query failed: $msg}
        catch {db_close $rs}
        return [list 0]
    }

    if {[db_get_nrows $rs] == 0} {
        ob_log::write ERROR {get_cust_max_deposit -> Failed to get stored ccy max deposit details}
        db_close $rs
        return [list 0]
    }

    set max_deposit [db_get_col $rs 0 max_deposit]
    db_close $rs

    return [list 1 $max_deposit]
}

proc ob_srp::_get_acct_details {cust_id} {

	if {[catch {
		set rs [ob_db::exec_qry ob_srp::get_acct_details $cust_id]
	} msg]} {
		ob_log::write ERROR {couldn't exec get_acct_details: $msg}
		return [list 0 err_exec_get_acct_details]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		ob_db::rs_close $rs
		ob_log::write ERROR {num rows returned was $nrows but we were expecting 1}
		return [list 0 err_nrows_not_1]
	}

	set acct_id  [db_get_col $rs 0 acct_id]
	set ccy_code [db_get_col $rs 0 ccy_code]
	set balance  [db_get_col $rs 0 balance]

	ob_db::rs_close $rs
	return [list 1 $acct_id $ccy_code $balance]
}



proc ob_srp::_ave_limit_per_day {type amount} {

	switch -- $type {
		day        {return $amount}
		week       {return [expr {$amount / 7}]}
		month      {return [expr {$amount / 30}]}
		default    {return ""}
	}

}

##############################################################################
# Procedure:    cust_below_dep_limit_factor
# Description:  checks if the customer is below the factor specified of the
#               deposit limit
# Input:        cust id, factor to test against
# Returns:      list : either -1 (error), 0 (over factor), 1 (below factor)
##############################################################################
proc ob_srp::below_dep_limit_factor {cust_id factor} {

    set max_dep_allowed_res [ob_srp::get_deposit_limit $cust_id]

    if {[lindex $max_dep_allowed_res 0]} {
		if {[lindex $max_dep_allowed_res 1] == "none"} {
			set max_deposit [ob_srp::get_cust_max_deposit $cust_id]
			if {[lindex $max_deposit 0]} {
				set max_amount [lindex $max_deposit 1]
			} else {
				return [list -1]
			}
		} else {
	        set max_amount [lindex $max_dep_allowed_res 2]
		}
    } else {
        return [list -1]
    }

    set amount [expr {(1 - $factor) * $max_amount}]
    return [ob_srp::check_deposit $cust_id $amount 1]
}

# initialise
ob_srp::init
