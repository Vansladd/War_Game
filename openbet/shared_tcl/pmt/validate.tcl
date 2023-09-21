# $Id: validate.tcl,v 1.1 2011/10/04 12:27:27 xbourgui Exp $
#
package provide pmt_validate   4.5

# Dependencies
#
package require util_log     4.5
package require util_db      4.5


namespace eval ob_pmt_validate {

	variable INIT 0

	variable FRAUD_LIMIT_CACHE_TIME 600
	variable fraud_limit_last_lookup

	variable wtd_limits
	array set wtd_limits [list]

	variable EXCH_RATES_CACHE_TIME 600
	variable exch_rates_last_lookup

	variable exch_rates
	array set exch_rates [list]

	variable MULT_PMT_CHK_RES
	array set MULT_PMT_CHK_RES [list]
	variable USE_MULT_PMT_CHK_RES

	set USE_MULT_PMT_CHK_RES [OT_CfgGet USE_MULT_PMT_CHK_RES 0]

	variable CARD_EXPIRY_YEARS
	set CARD_EXPIRY_YEARS [OT_CfgGet CARD_EXPIRY_YEARS 15]
}


proc ob_pmt_validate::chk_wtd_all {acct_id pmt_id pay_mthd scheme amount ccy_code {expiry -1}} {

	variable exch_rates
	_add_mult_pmt_id $acct_id $pmt_id

	_load_exch_rates
	if {![info exists exch_rates($ccy_code)]} {
		error "Cannot find ccy: $ccy_code"
	}
	set exch_rate $exch_rates($ccy_code)

	set sys_amount [expr {$amount / $exch_rate}]

	set process_pmt 1

	chk_wtd_notify $pmt_id $pay_mthd $scheme $acct_id $sys_amount

	set ret_delay [chk_wtd_delay $acct_id $pay_mthd $sys_amount $expiry]

	if {$ret_delay != "OB_OK"} {
		set process_time [lindex $ret_delay 1]
		set_wtd_delay $pmt_id $process_time
		set process_pmt 0
		_add_mult_pmt_chk_res $pmt_id "chk_wtd_delay" $process_time
	} else {
		_add_mult_pmt_chk_res $pmt_id "chk_wtd_delay" \
		    [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	}

	set ret_fraud [chk_fraud_wtd_limit $pmt_id $pay_mthd $scheme $acct_id $sys_amount]
	if {$ret_fraud != "OB_OK"} {
		set process_pmt 0
		_add_mult_pmt_chk_res $pmt_id "chk_fraud_wtd_limit" $ret_fraud
	}

	set ret_status [chk_wtd_status_flags $acct_id $pmt_id]
	if {$ret_status != "OB_OK"} {
		set process_pmt 0
		_add_mult_pmt_chk_res $pmt_id "chk_wtd_status_flags" $ret_status
	}

	return $process_pmt
}

proc ob_pmt_validate::chk_wtd_notify {pmt_id pay_mthd scheme acct_id sys_amount} {

	set email ""
	set max_wtd ""

	# There are so few payment methods it's more efficient to scan
	# the list rather than storing as a hash table.
	if {[catch {ob_db::exec_qry ob_pmt_validate::get_notify_limits} rs]} {
		ob_log::write ERROR {ob_pmt_validate::get_notify_limits: $rs}
		error $rs
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		if {$pay_mthd == [db_get_col $rs $i pay_mthd] &&
		    $scheme   == [db_get_col $rs $i scheme] } {
			set email   [db_get_col $rs $i email]
			set max_wtd [db_get_col $rs $i max_wtd]
			break
		}
	}

	# max_wtd has not been set see if there is a pay method with no scheme defined
	if {$max_wtd == ""} {
		set scheme "----"

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			if {$pay_mthd == [db_get_col $rs $i pay_mthd] &&
				$scheme   == [db_get_col $rs $i scheme] } {
				set email   [db_get_col $rs $i email]
				set max_wtd [db_get_col $rs $i max_wtd]
				break
			}
		}
	}

	if {$max_wtd != "" && $sys_amount > $max_wtd} {
		set reason "Account Id: $acct_id Payment ID: $pmt_id is over limits: amount : $sys_amount max: $max_wtd pay method: $pay_mthd"
		# Send email
		if {[catch {ob_db::exec_qry ob_pmt_validate::insert_email_queue \
			$reason $email} \
		msg]} {
			ob_log::write ERROR {ob_pmt_validate::_do ERROR: insert_email_queue, $msg}
		}

		ob_log::write INFO {Email WTD warning to $email for pmt_id $pmt_id}
	}

	ob_db::rs_close $rs
}

#
# Check whether an individual pmt should be delayed
#
# Returns 'OB_OK' if no delay or [list PMT_DELAYED <process_time>] if it should
# be delayed.
#
proc ob_pmt_validate::chk_wtd_delay {acct_id pay_mthd sys_amount {expiry -1}} {

	ob_log::write DEBUG {ob_pmt_validate::chk_wtd_delay: \
		$acct_id, $pay_mthd, $sys_amount}

	if {![OT_CfgGet FUNC_REVERSE_WITHDRAWALS 0]} {
		# Old way of calculating delay
		if {[catch {
			set rs [ob_db::exec_qry ob_pmt_validate::wtd_delay $pay_mthd]
		} msg]} {
			error $msg
		}

		if {[db_get_nrows $rs] != 1} {
			error "Expected 1 rows to be returned"
		}

		set wtd_delay_mins       [db_get_col $rs 0 wtd_delay_mins]
		set wtd_delay_threshold  [db_get_col $rs 0 wtd_delay_threshold]
		set wtd_batch_time       [db_get_col $rs 0 wtd_batch_time]
		set wtd_we_batch_time    [db_get_col $rs 0 wtd_we_batch_time]
		set wtd_deferred_to      [db_get_col $rs 0 wtd_deferred_to]

		ob_db::rs_close $rs

		if {$wtd_delay_threshold != "" && $sys_amount < $wtd_delay_threshold} {
			return "OB_OK"
		}

		if {$wtd_delay_mins == 0} {
			return "OB_OK"
		}

		set process_time [expr {[clock seconds] + ($wtd_delay_mins * 60)}]
		set process_time [clock format $process_time -format "%Y-%m-%d %H:%M:%S"]
		set status "PMT_DELAYED"

	} else {

		set status "OB_OK"

		set override_flag_set 0
		set now      [clock seconds]
		set min_date $now

		if {[catch {ob_db::exec_qry ob_pmt_validate::get_no_reverse_flag $acct_id} rs]} {
			ob_log::write ERROR {ob_pmt_validate::get_customer_flag: $rs}
			error $rs
		}

		if {[db_get_nrows $rs] == 1 && [db_get_col $rs 0 flag_value] == "Y"} {
			set override_flag_set 1
		}

		ob_db::rs_close $rs

		if {[catch {ob_db::exec_qry ob_pmt_validate::get_acct_type $acct_id} rs]} {
			ob_log::write ERROR {ob_pmt_validate::get_acct_type: $rs}
			error $rs
		}

		set acct_type [db_get_col $rs 0 acct_type]
		ob_db::rs_close $rs

		# Withdrawal process_date is calculated according to the week day batch time and the week end batch time
		# Need to push it until batch time tomorrow?
		if {!$override_flag_set && $acct_type == "DEP"} {

			foreach {is_batch process_date} [calc_process_time $pay_mthd] {}

			if {$process_date != "" && \
			    $process_date > [clock format [clock seconds] -format "%Y-%m-%d %T"]} {
				set min_date [clock scan $process_date]
				set status "PMT_DELAYED"
			}
		}

		if {$status == "OB_OK"} {
			return "OB_OK"
		}

		set process_time [clock format $min_date -format "%Y-%m-%d %H:%M:%S"]
	}

	# check expiry time for cards. We don't want to delay withdrawals if it's
	# going to mean that the card will be expired by then.
	if {$expiry != -1} {
		if {![_check_card_expiry_for_date $expiry [clock scan $process_time]]} {
			ob_log::write INFO {ob_pmt_validate: Card is expired. ($expiry) Payment will not be delayed}
			return "OB_OK"
		}
	}

	return [list $status $process_time]
}


#
# Set the process date for a list of payments
#
proc ob_pmt_validate::set_wtd_delay {pmt_ids process_time} {

	foreach pmt_id $pmt_ids {
		# Update the payment processing time
		if {[catch {
			ob_db::exec_qry ob_pmt_validate::set_wtd_delay $process_time $pmt_id
		} msg]} {
			ob_log::write ERROR {ob_pmt_validate::wtd_delay - failed to set\
			   process time to $process_time for pmt_id $pmt_id - $msg}
		}

		ob_log::write INFO {ob_pmt_validate::set_wtd_delay - Payment $pmt_id\
		   delayed for processing until $process_time}

	}
}


#
# Calculates the payment process time. Withdrawals can be reversed
# up to this point.
#
proc ob_pmt_validate::calc_process_time { pay_mthd {sys_amount -1} } {

	set now [clock seconds]

	if {[catch {
		set rs [ob_db::exec_qry ob_pmt_validate::wtd_delay $pay_mthd]
	} msg]} {
		ob_log::write ERROR {ob_pmt_validate::wtd_delay: \
			Failed to exec qry ob_pmt_validate::wtd_delay - $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR {ob_pmt_validate::wtd_delay - Query should \
			have returned 1 row, [db_get_nrows $rs] returned instead}

		ob_db::rs_close $rs
		return 0
	}

	set wtd_delay_mins       [db_get_col $rs 0 wtd_delay_mins]
	set wtd_delay_threshold  [db_get_col $rs 0 wtd_delay_threshold]
	set wtd_batch_time       [db_get_col $rs 0 wtd_batch_time]
	set wtd_we_batch_time    [db_get_col $rs 0 wtd_we_batch_time]
	set wtd_deferred_to      [db_get_col $rs 0 wtd_deferred_to]

	# minimum date is the current date + wtd_delay_mins. The payment should be processed
	# no sooner than that.
	set min_date [expr {$now + ($wtd_delay_mins * 60)}]

	# work out if it is the week end or not
	set is_week_end    0
	set force_week_day 0
	set is_batch       0

	if {[lsearch [OT_CfgGet WEEK_END_DAYS [list Friday Saturday Sunday]] [clock format $min_date -format %A]] != -1} {
		set is_week_end 1
	}

	# This is already the weekend
	if {$is_week_end} {

		ob_log::write DEBUG {ob_pmt_validate::wtd_delay: Week end treatment}

		# look at the we_batch_time
		if {$wtd_we_batch_time != ""} {
			# Get the batch time on the sunday.
			set we_min_date [clock scan "$wtd_we_batch_time sunday" -base $min_date]

			if {$we_min_date >= $min_date} {
				set min_date $we_min_date
			} else {
				if {$wtd_batch_time != ""} {
					set min_date [clock scan "$wtd_batch_time tomorrow"]
				} else {
					set min_date [clock scan "$wtd_we_batch_time next sunday" -base $min_date]
					ob_log::write DEBUG {ob_pmt_validate::wtd_delay: \
						Week end treatment. Pushing until next sunday}
					# pushing it until next sunday
				}
			}
			set is_batch 1
		} else {
			set force_week_day 1
		}
	}

	if {!$is_week_end || $force_week_day} {

		# This is a week day
		if {$wtd_batch_time != ""} {
			if {$min_date > [clock scan $wtd_batch_time]} {
				set min_date [clock scan "$wtd_batch_time tomorrow"]
			} else {
				set min_date [clock scan "$wtd_batch_time"]
			}
			set is_batch 1
		}

		# case where it's thursday and the payment is pushed to friday.
		if {$wtd_we_batch_time != "" && [lsearch [OT_CfgGet WEEK_END_DAYS [list Friday Saturday Sunday]] [clock format $min_date -format %A]] != -1} {

			# Get the batch time on the sunday.
			set we_min_date [clock scan "$wtd_we_batch_time sunday" -base $min_date]

			if {$we_min_date >= $min_date} {
				set min_date $we_min_date
				set is_batch 1
			}
		}
	}

	# Need to push it until the deferred_to date?
	if {$wtd_deferred_to != "" && $min_date < [clock scan $wtd_deferred_to] } {
		set min_date [clock scan [clock format $min_date -format "%H:%M:%S"] -base [clock scan "$wtd_deferred_to"]]
	}

	if {$sys_amount != -1 && $wtd_delay_threshold != "" && \
	    $sys_amount < $wtd_delay_threshold} {
		set min_date [clock format $now -format "%Y-%m-%d %T"]

	} else {
		set min_date [clock format $min_date -format "%Y-%m-%d %T"]
	}

	return [list $is_batch $min_date]
}


#
# Sets the withdraw delay for a group of payments that form a single
# withdrawal in the multiple payment methods system.
#
# acct_id   - The acct_id of the customer making the payments
# pay_mthds - A list of pay_mthd pmt_id pairs that the form the withdrawal
# process_time - the pmt process time, if available. If not provided then it is
#                calculated as described below.
#
proc ob_pmt_validate::set_group_wtd_delay {acct_id pay_mthds} {

	variable MULT_PMT_CHK_RES
	variable USE_MULT_PMT_CHK_RES

	set fn {ob_pmt_validate::set_group_wtd_delay}

	ob_log::write DEBUG {$fn - \
	   setting process time for acct_id $acct_id $pay_mthds}

	# The withdrawal time for all payments in a group is:
	#
	# 1) The withdrawal time of any pending payment that is
	#    not part of this group and is in the future
	# 2) The maximum withdrawal time of the individual payments
	#    in this group if none have a batch time. Otherwise,
	#    we need to take the lowest batch time
	# 3) If any of the payments are done straight away (eg UKASH)
	#    then we force through (set process_date to now) all of
	#    the customer's pending pmts, including pre-existing ones


	if {!$USE_MULT_PMT_CHK_RES} {
		ob_log::write ERROR {$fn - in order to use this proc config item\
		   USE_MULT_PMT_CHK_RES needs to be set and init_mult_pmt_res needs\
		   to be used correctly}
		return ERROR
	}

	set wtd_time ""
	set pmt_ids [list]
	set pending_pmts [get_pending_wtd $acct_id]

	if {[clock scan $MULT_PMT_CHK_RES(process_date)] <= [clock seconds]} {
		ob_log::write INFO {$fn - non reversable payment method used - setting\
		   process_date to $MULT_PMT_CHK_RES(process_date) for all customer's\
		   pending payemnts}

		foreach {pay_mthd pmt_id process_date} $pending_pmts {
			lappend pmt_ids $pmt_id
		}
		set wtd_time $MULT_PMT_CHK_RES(process_date)

	# So it is reversible - need to work out what payment date to use
	} else {
		foreach {pay_mthd pmt_id} $pay_mthds {
			lappend pmt_ids $pmt_id
		}

		# pending_pmts contains all the customer's pending pmt, irrespective of
		# when they were added. Check if any exist that weren't added in the
		# current withdrawal.
		foreach {pay_mthd pmt_id process_date} $pending_pmts {
			if {[lsearch $pmt_ids $pmt_id] == -1} {
				set wtd_time [min $wtd_time $process_date]
			}
		}

		# No existing payment date to use - work out the pmt date based on the
		# new set of payments
		if {$wtd_time == ""} {

			# Check the payment reversal times in the current group of payments
			set lowest_batch_time -1
			set highest_wtd_time  -1

			foreach {pay_mthd pmt_id} $pay_mthds {

				foreach {is_batch process_date} [calc_process_time $pay_mthd] {}

				if {$process_date != ""} {
					if {$is_batch} {
						# We have a batch time so all payments should
						# be set to the lowest batch time.
						if {$lowest_batch_time == -1 || \
						    [clock scan $process_date] < $lowest_batch_time} {
							set lowest_batch_time [clock scan $process_date]
						}
					} else {
						if {[clock scan $process_date] > $highest_wtd_time} {
							set highest_wtd_time [clock scan $process_date]
						}
					}
				}
			}

			if {$lowest_batch_time != -1} {
				set wtd_time \
				     [clock format $lowest_batch_time -format "%Y-%m-%d %T"]
			} elseif {$highest_wtd_time != -1} {
				set wtd_time \
				     [clock format $highest_wtd_time -format "%Y-%m-%d %T"]
			}
		}
	}

	if {$wtd_time != ""} {
		ob_log::write INFO {$fn: Updating payments $pmt_ids \
		   process_date to $wtd_time}

		set_wtd_delay $pmt_ids $wtd_time
	}

	if {$MULT_PMT_CHK_RES(fraud_chk) || $MULT_PMT_CHK_RES(large_ret)} {
		ob_log::write INFO {$fn: setting fraud_chk and large_ret\
		   for all pending pmts}

		foreach {pay_mthd pmt_id process_time} $pending_pmts {
			_fraud_flag_pmt \
				$acct_id \
				$pmt_id \
				[expr {$MULT_PMT_CHK_RES(fraud_chk) ? "Y" : "N"}] \
				[expr {$MULT_PMT_CHK_RES(large_ret) ? "Y" : "N"}]
		}
	}

	return $wtd_time
}


#
# Get all the pending payments for this customers
#
proc ob_pmt_validate::get_pending_wtd {acct_id} {

	set pending_pmts [list]

	# Get all the pending wtd for this customer.
	if {[catch {
		set rs [ob_db::exec_qry ob_pmt_validate::get_pending_wtd $acct_id]
	} msg]} {
		# Can't check if there are any prexisting wtd, but hopefully we can at
		# least make sure that the current pmts go in with the same wtd time.
		# We'll continue and do that.
		ob_log::write ERROR {ob_pmt_validate::get_pending_wtd: \
			Failed to exec qry get_pending_wtd - $msg}
		return

	} else {
		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			lappend pending_pmts \
				[db_get_col $rs $i ref_key] \
				[db_get_col $rs $i pmt_id] \
				[db_get_col $rs $i process_date]
		}
	}

	ob_db::rs_close $rs

	return $pending_pmts
}


proc ob_pmt_validate::chk_fraud_wtd_limit {pmt_id pay_mthd scheme acct_id sys_amount} {

	variable wtd_limits

	# If a scheme is not set try the pay method scheme
	set pay_mthd_scheme "----"

	set fraud_check 0

	if {[OT_CfgGet CUST_WTD_LIMITS 0]} {
		# Fetch the current customer specific withdrawal limit, if it exists.
		if {[catch {ob_db::exec_qry ob_pmt_validate::chk_cust_fraud_limit $acct_id $pay_mthd} rs]} {
			ob_log::write ERROR {ob_pmt_validate::chk_fraud_wtd_limit: $rs}
			error $rs
		}

		if {[db_get_nrows $rs] > 0} {
			array set cust_wtd_limits [list]
			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				set scheme         [db_get_col $rs $i scheme]
				set num_days       [db_get_col $rs $i days_since_dep_1]
				set days_since_wtd [db_get_col $rs $i days_since_wtd]
				set max_wtd        [db_get_col $rs $i max_wtd]
				lappend cust_wtd_limits($scheme,days) $num_days
				set cust_wtd_limits($scheme,$num_days) [list $days_since_wtd $max_wtd]
			}
		}

		ob_db::rs_close $rs

		_load_wtd_limits

		set days_since_dep1 [_days_since_dep1 $acct_id]

		set days_since_wtd ""
		set max_wtd        ""
		set custlimit      ""
		set limit          ""

		if {[info exists cust_wtd_limits($scheme,days)]} {
			foreach day $cust_wtd_limits($scheme,days) {
				if {$days_since_dep1 <= $day} {
					set custlimit $day
					break
				}
			}
		} elseif {[info exists cust_wtd_limits($pay_mthd_scheme,days)]} {
			set scheme $pay_mthd_scheme
			foreach day $cust_wtd_limits($pay_mthd_scheme,days) {
				if {$days_since_dep1 <= $day} {
					set custlimit $day
					break
				}
			}
		} elseif {[info exists wtd_limits($pay_mthd,$scheme,days)]} {
			foreach day $wtd_limits($pay_mthd,$scheme,days) {
				if {$days_since_dep1 <= $day} {
					set limit $day
					break
				}
			}
		} elseif {[info exists wtd_limits($pay_mthd_scheme,$scheme,days)]} {
			set scheme $pay_mthd_scheme
			foreach day $wtd_limits($pay_mthd_scheme,$scheme,days) {
				if {$days_since_dep1 <= $day} {
					set limit $day
					break
				}
			}
		}

		if {$custlimit != ""} {
			foreach {days_since_wtd max_wtd}\
				$cust_wtd_limits($scheme,$custlimit) {break}
		} elseif {$limit != ""} {
			foreach {days_since_wtd max_wtd}\
				$wtd_limits($pay_mthd,$scheme,$limit) {break}
		}

		array unset cust_wtd_limits

	} else {
		_load_wtd_limits

		set days_since_dep1 [_days_since_dep1 $acct_id]

		set days_since_wtd ""
		set max_wtd        ""
		set limit          ""

		if {[info exists wtd_limits($pay_mthd,$scheme,days)]} {
			foreach day $wtd_limits($pay_mthd,$scheme,days) {
				if {$days_since_dep1 <= $day} {
					set limit $day
					break
				}
			}
		} elseif {[info exists wtd_limits($pay_mthd_scheme,$scheme,days)]} {
			set scheme $pay_mthd_scheme
			foreach day $wtd_limits($pay_mthd_scheme,$scheme,days) {
				if {$days_since_dep1 <= $day} {
					set limit $day
					break
				}
			}
		}

		if {$limit != ""} {
			foreach {days_since_wtd max_wtd}\
				$wtd_limits($pay_mthd,$scheme,$limit) {break}
		}

	}

	if {$max_wtd != "" && $max_wtd < $sys_amount} {
		set fraud_check 1
	} elseif {$days_since_wtd != ""} {

		set dt [expr {[clock seconds] - $days_since_wtd * 86400}]
		set dt [clock format $dt -format "%Y-%m-%d 00:00:00"]

		if {[catch {ob_db::exec_qry ob_pmt_validate::chk_recent_wtds $acct_id $dt $pmt_id} rs]} {
			ob_log::write ERROR {ob_pmt_validate::chk_fraud_wtd_limit: $rs}
			error $rs
		}

		if {[db_get_nrows $rs]} {
			set fraud_check 1
		}

		ob_db::rs_close $rs
	}

	if {$fraud_check} {
		#Put a flag on the account
		_fraud_flag_acct $acct_id "Triggered by Fraud Wtd limits"
		ob_log::write INFO {ob_pmt_validate: Payment $pmt_id must be fraud checked}
		return "FRAUD_CHECK"
	} else {
		return "OB_OK"
	}
}

proc ob_pmt_validate::chk_wtd_status_flags {acct_id pmt_id} {

	set is_fc "N"
	set is_lr "N"

	if {[catch {ob_db::exec_qry ob_pmt_validate::get_cust_status_flags $acct_id} rs]} {
		ob_log::write ERROR {ob_pmt_validate::chk_wtd_status_flags: $rs}
		error $rs
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		if {[db_get_col $rs $i status_flag_tag] == "FRAUD_CHK"} {
			set is_fc "Y"
		} else {
			set is_lr "Y"
		}
	}

	ob_db::rs_close $rs

	if {$is_fc == "Y" || $is_lr == "Y"} {
		_fraud_flag_pmt $acct_id $pmt_id $is_fc $is_lr
		ob_log::write INFO {ob_pmt_validate: Payment $pmt_id staying as pending fraud flags on account}
		return [list "FRAUD_CHECK" $is_fc $is_lr]
	} else {
		return "OB_OK"
	}
}


#
# Storing locally as the most popular payment methods may not have
# limits set so can do a quick look from the hash table
#
proc ob_pmt_validate::_load_wtd_limits {} {

	variable FRAUD_LIMIT_CACHE_TIME
	variable fraud_limit_last_lookup
	variable wtd_limits

	# Are we still in the cache period
	if {[info exists fraud_limit_last_lookup] &&
	    [expr {[clock seconds] - $fraud_limit_last_lookup}] < $FRAUD_LIMIT_CACHE_TIME} {
		# The current withdraw limits are within the cache time
		return
	}

	array unset wtd_limits
	array set wtd_limits [list]

	if {[catch {ob_db::exec_qry ob_pmt_validate::fraud_wtd_limits} rs]} {
		ob_log::write ERROR {ob_pmt_validate::wtd_delay: $rs}
		error $rs
	}

	set prev_ps ""
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set ps             "[db_get_col $rs $i pay_mthd],[db_get_col $rs $i scheme]"
		set num_days       [db_get_col $rs $i days_since_dep_1]
		set days_since_wtd [db_get_col $rs $i days_since_wtd]
		set max_wtd        [db_get_col $rs $i max_wtd]

		lappend wtd_limits($ps,days) $num_days
		set wtd_limits($ps,$num_days) [list $days_since_wtd $max_wtd]
	}

	ob_db::rs_close $rs

	set fraud_limit_last_lookup [clock seconds]
}

#
# This proc prob. doesn't belong in here.
# Will move when this package gets built up
#
proc ob_pmt_validate::_load_exch_rates {} {

	variable EXCH_RATES_CACHE_TIME
	variable exch_rates_last_lookup
	variable exch_rates

	# Are we still in the cache period
	if {[info exists exch_rates_last_lookup] &&
	    [expr {[clock seconds] - $exch_rates_last_lookup}] < $EXCH_RATES_CACHE_TIME} {
		# The current exchange rates are within the cache time
		return
	}

	array unset exch_rates
	array set exch_rates [list]

	if {[catch {ob_db::exec_qry ob_pmt_validate::get_exch_rates} rs]} {
		ob_log::write ERROR {ob_pmt_validate::exch_rates: $rs}
		error $rs
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set ccy_code  [db_get_col $rs $i ccy_code]
		set exch_rate [db_get_col $rs $i exch_rate]

		set exch_rates($ccy_code) $exch_rate
	}

	ob_db::rs_close $rs

	set exch_rates_last_lookup [clock seconds]
}

proc ob_pmt_validate::_days_since_dep1 {acct_id} {

	if {[catch {ob_db::exec_qry ob_pmt_validate::days_since_dep_1 $acct_id} rs]} {
		ob_log::write ERROR {ob_pmt_validate::_days_since_dep1: $rs}
		error $rs
	}

	if {[db_get_nrows $rs] == 1} {
		set days [db_get_col $rs 0 days_since_dep_1]
		ob_db::rs_close $rs
		return $days
	}

	# Some customers may have funds on the account by means of a manual adjustment
	# or freebet.  For these we will take the date of the account creation
	if {[catch {ob_db::exec_qry ob_pmt_validate::acct_cr_date $acct_id} rs]} {
		ob_log::write ERROR {ob_pmt_validate::_days_since_dep1: $rs}
		error $rs
	}

	if {[db_get_nrows $rs] != 1} {
		set err {ob_pmt_validate::_days_since_dep1: Cannot find account: $acct_id}
		ob_log::write ERROR {$err}
		ob_db::rs_close $rs
		error $err
	}

	set days [db_get_col $rs 0 days_since_dep_1]
	ob_db::rs_close $rs
	return $days
}



proc ob_pmt_validate::_fraud_flag_acct {acct_id reason {in_tran "N"}} {

	if {$in_tran eq "N"} {
		set transactional "Y"
	} else {
		set transactional "N"
	}

	if {[catch {
		ob_db::exec_qry ob_pmt_validate::fraud_flag_acct $acct_id $reason $transactional
	} rs]} {
		ob_log::write ERROR {ob_pmt_validate::_fraud_flag_acct: $rs}
		error $rs
	}
	ob_db::rs_close $rs
}

proc ob_pmt_validate::_fraud_flag_pmt {acct_id pmt_id is_fc is_lr} {

	if {[catch {
		ob_db::exec_qry ob_pmt_validate::fraud_flag_pmt $pmt_id $acct_id $is_fc $is_lr
	} rs]} {
		ob_log::write ERROR {ob_pmt_validate::_fraud_flag_pmt: $rs}
		error $rs
	}
	ob_db::rs_close $rs
}

proc ob_pmt_validate::_check_card_expiry_for_date {expiry date_to_compare} {

	variable CARD_EXPIRY_YEARS

	if {![regexp {^([01][0-9])\/([0-9][0-9])$} \
			$expiry junk expiry_month expiry_year]} {
		return 0
	}

	set mnth_cmp [string trimleft $expiry_month 0]
	set year_cmp [string trimleft $expiry_year 0]
	set year_cmp [_expand_yr $year_cmp]

	if {$mnth_cmp == "" || [expr $mnth_cmp < 1 || $mnth_cmp > 12]} {
		return 0
	}
	set mnth [string trimleft [clock format $date_to_compare -format "%m"] 0]
	set year [string trimleft [clock format $date_to_compare -format "%Y"] 0]

	if {$year_cmp > [expr {$year + $CARD_EXPIRY_YEARS}] || \
		[expr $year > $year_cmp] || \
		([expr $year == $year_cmp] && [expr $mnth > $mnth_cmp])} {
		return 0
	}

	return 1
}


# converts 1 and 2 digit year to 4
#
proc ob_pmt_validate::_expand_yr {yr} {

	if {$yr < 10} {
		return "200$yr"
	}

	if {$yr < 50} {
		return "20$yr"
	}

	return "19$yr"
}


#
# Reset the MULT_PMT_CHK_RES array for a new request
#
proc ob_pmt_validate::init_mult_pmt_res {acct_id} {

	variable MULT_PMT_CHK_RES
	variable USE_MULT_PMT_CHK_RES

	if {!$USE_MULT_PMT_CHK_RES} {
		ob_log::write ERROR {ob_pmt_validate::init_mult_pmt_res - in order to\
		   use this proc config item USE_MULT_PMT_CHK_RES needs to be set}
		return ERROR
	}

	clear_mult_pmt_res

	set MULT_PMT_CHK_RES(acct_id)      $acct_id
	set MULT_PMT_CHK_RES(pmt_ids)      [list]
	set MULT_PMT_CHK_RES(process_date) ""
	set MULT_PMT_CHK_RES(fraud_chk)    0
	set MULT_PMT_CHK_RES(large_ret)    0
}


#
# Clear MULT_PMT_CHK_RES. This should be done after each request.
#
proc ob_pmt_validate::clear_mult_pmt_res {} {

	variable MULT_PMT_CHK_RES

	array unset MULT_PMT_CHK_RES
	array set MULT_PMT_CHK_RES [list]
}


#
# Add a pmt_id to MULT_PMT_CHK_RES with default values
#
proc ob_pmt_validate::_add_mult_pmt_id {acct_id pmt_id} {

	variable MULT_PMT_CHK_RES
	variable USE_MULT_PMT_CHK_RES

	if {!$USE_MULT_PMT_CHK_RES} {
		return
	}

	if {$MULT_PMT_CHK_RES(acct_id) != $acct_id} {
		ob_log::write ERROR {ob_pmt_validate::_add_mult_pmt_id -\
		   attempting to add a pmt_id for the wrong acct_id - clearing all data}
		init_mult_pmt_res $acct_id
	}

	if {[lsearch $MULT_PMT_CHK_RES(pmt_ids) $pmt_id] == -1} {
		lappend MULT_PMT_CHK_RES(pmt_ids) $pmt_id
	}

	set MULT_PMT_CHK_RES($pmt_id,process_date) ""
	set MULT_PMT_CHK_RES($pmt_id,fraud_chk) 0
	set MULT_PMT_CHK_RES($pmt_id,large_ret) 0
}


#
# Add the result of a check against a specific pmt_id to MULT_PMT_CHK_RES
#
proc ob_pmt_validate::_add_mult_pmt_chk_res {pmt_id chk_type {chk_res ""}} {

	variable MULT_PMT_CHK_RES
	variable USE_MULT_PMT_CHK_RES

	if {!$USE_MULT_PMT_CHK_RES} {
		return
	}

	switch -exact -- $chk_type {
		chk_wtd_delay {
			set MULT_PMT_CHK_RES($pmt_id,process_date) $chk_res
			set MULT_PMT_CHK_RES(process_date) \
			       [min $MULT_PMT_CHK_RES(process_date) $chk_res]
		}
		chk_fraud_wtd_limit {
			set MULT_PMT_CHK_RES($pmt_id,fraud_chk) 1
		}
		chk_wtd_status_flags {
			if {[lindex $chk_res 1] == "Y"} {
				set MULT_PMT_CHK_RES($pmt_id,fraud_chk) 1
				set MULT_PMT_CHK_RES(fraud_chk) 1
			}
			if {[lindex $chk_res 2] == "Y"} {
				set MULT_PMT_CHK_RES($pmt_id,large_ret) 1
				set MULT_PMT_CHK_RES(large_ret) 1
			}
		}
	}
}



proc ob_pmt_validate::_init {} {

	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	_prepare_qrys

	set INIT 1
}

proc ob_pmt_validate::_prepare_qrys {} {

	ob_db::store_qry ob_pmt_validate::wtd_delay {
		select
			NVL(wtd_delay_mins,0) as wtd_delay_mins,
			wtd_delay_threshold,
			wtd_batch_time,
			wtd_we_batch_time,
			wtd_deferred_to
		from
			tPayMthd
		where
			pay_mthd = ?
	} 600

	ob_db::store_qry ob_pmt_validate::fraud_wtd_limits {
		select
			pay_mthd,
			scheme,
			days_since_dep_1,
			days_since_wtd,
			max_wtd
		from
			tFraudLimitWtd
		order by 1,2,3
	} 30

	ob_db::store_qry ob_pmt_validate::days_since_dep_1 {
		select
			extend(current, year to day) - extend(s.first_date, year to day) days_since_dep_1
		from
			tCustStats s,
			tCustStatsAction a
		where
			    s.acct_id     = ?
		and     a.action_name = 'DEPOSIT'
		and     s.action_id   = a.action_id
	}

	ob_db::store_qry ob_pmt_validate::acct_cr_date {
		select extend(current, year to day) - extend(cr_date, year to day) days_since_dep_1
		from tacct
		where acct_id = ?
	}

	ob_db::store_qry ob_pmt_validate::chk_recent_wtds {
		select first 1
			pmt_id
		from
			tPmt p
		where
			p.acct_id      = ?
		and p.payment_sort = 'W'
		and p.status      not in ('N', 'X', 'B')
		and cr_date       >= ?
		and p.pmt_id      != ?
	}

	ob_db::store_qry ob_pmt_validate::fraud_flag_acct {
		execute procedure pInsCustStatusFlag (
			p_cust_id         = (select cust_id from tAcct where acct_id = ?),
			p_status_flag_tag = 'FRAUD_CHK',
			p_reason          = ?,
			p_transactional   = ?
		)
	}

	ob_db::store_qry ob_pmt_validate::fraud_flag_pmt {
		execute procedure pPmtInsPendStatus (
			p_pmt_id         = ?,
			p_acct_id        = ?,
			fraud_check_flag = ?,
			large_ret_flag   = ?
		)
	}

	ob_db::store_qry ob_pmt_validate::get_cust_status_flags {
		select
			status_flag_tag
		from
			tAcct a,
			tCSFlagIdx csi,
			tCustStatusFlag csf
		where
			a.acct_id        = ? and
			a.cust_id        = csi.cust_id and
			csi.cust_flag_id = csf.cust_flag_id and
			csf.status_flag_tag in ('LARGE_RET','FRAUD_CHK') and
			csf.status       = 'A'
	}

	ob_db::store_qry ob_pmt_validate::get_notify_limits {
		select
			pay_mthd,
			scheme,
			email,
			max_wtd
		from
			tFraudLimitNotify
	} 300

	ob_db::store_qry ob_pmt_validate::get_exch_rates {
		select
			ccy_code,
			exch_rate
		from tCcy
	} 300

	ob_db::store_qry ob_pmt_validate::insert_email_queue {
		execute procedure pInsEmailQueue (
			p_email_type = "PMT_LIMITS_NOTIFY",
			p_reason     = ?,
			p_email_addr = ?
		)
	}

	# Due to the way the payment code is structured, this could be called
	# multiple times within the same request. We'll cache it long enough so that
	# it doesn't actually hit the DB
	ob_db::store_qry ob_pmt_validate::get_no_reverse_flag {
		select
			f.flag_value
		from
			tCustomerFlag f,
			tAcct a
		where
			f.flag_name = 'no_reverse_wtd'
		and a.acct_id   = ?
		and a.cust_id   = f.cust_id
	} 30

	# See comment above
	ob_db::store_qry ob_pmt_validate::get_acct_type {
		select
			acct_type
		from
			tAcct
		where
			acct_id = ?
	} 30

	ob_db::store_qry ob_pmt_validate::get_pending_wtd {
		select{+INDEX(tPmtPending iPmtPending_x3)}
			p.pmt_id,
			p.ref_key,
			pp.process_date
		from
			tPmt p,
			tPmtPending pp
		where
			    pp.acct_id      = ?
			and pp.process_date > current
			and pp.pmt_id       = p.pmt_id
			and p.payment_sort  = 'W'
			and p.status        = 'P'
	}

	ob_db::store_qry ob_pmt_validate::set_wtd_delay {
		update
			tPmtPending
		set
			process_date = ?
		where
			pmt_id       = ?
	}

	ob_db::store_qry ob_pmt_validate::chk_cust_fraud_limit {
		select
		  scheme,
		  days_since_dep_1,
		  days_since_wtd,
		  max_wtd
		from
		  tFraudLimitWtdAcc
		where
		  acct_id = ?
		  and pay_mthd = ?
	} 600
}

ob_pmt_validate::_init





