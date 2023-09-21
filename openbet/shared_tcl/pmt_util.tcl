# $Id: pmt_util.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $

package require util_db

namespace eval pmt_util {
	variable INIT 0
}


#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------
proc pmt_util::init {} {

	variable INIT


	if {$INIT} {
		ob_log::write WARNING {pmt_util::init - Already initialised}
		return
	}

	ob_log::write DEBUG {pmt_util::init: Initialising}

	ob_db::init
	pmt_util::_prep_sql

	set INIT 1
}


#-------------------------------------------------------------------------------
# Initialise the DB queries
#-------------------------------------------------------------------------------
proc pmt_util::_prep_sql {} {

	ob_db::store_qry pmt_util::get_cpm_limit_settings {
		execute procedure pPmtControlAcct (
			p_cpm_id       = ?,
			p_payment_sort = ?
		)
	}

	ob_db::store_qry pmt_util::get_pay_mthd_limit_settings {
		execute procedure pPmtControlAcct (
			p_acct_id = ?,
			p_pay_mthd = ?,
			p_ccy_code = ?,
			p_scheme = ?,
			p_payment_sort =?
		)
	}

	ob_db::store_qry pmt_util::get_acct_details {
		select
			ccy_code
		from
			tAcct
		where
			acct_id = ?
	}

	ob_db::store_qry pmt_util::get_balance {
		select
			balance - balance_nowtd as bal_wtd
		from
			tAcct
		where
			cust_id = ?
	}

	ob_db::store_qry pmt_util::check_cpm_belongs_to_cust {
		select
			cpm_id
		from
			tCustPayMthd
		where
			cust_id = ?
	}

	ob_db::store_qry pmt_util::get_cust_txn_amt_for_period {
		select {+INDEX (tPmt iPmt_x8)}
			count(*) as count,
			nvl(sum(p.amount), 0.00) as total,
			nvl(sum(p.commission), 0.00) as commission
		from
			tCustPayMthd cpm,
			tAcct a,
			tPmt p
		where
		    cpm.cpm_id      = ?
		and cpm.cust_id     = a.cust_id
		and cpm.cpm_id      = p.cpm_id
		and a.acct_id       = p.acct_id
		and p.cr_date      >= extend (extend(current - ? units day, year to day), year to second)
		and p.payment_sort  = ?
		and p.status not in ('N','X','B')
	}

	ob_db::store_qry pmt_util::get_schemes {
		select
			scheme_name,
			scheme,
			type
		from
			tCardSchemeInfo
		where
			dep_allowed in (?,?) and
			wtd_allowed in (?,?)
	}

	ob_db::store_qry pmt_util::insert_wtd_link {
		execute procedure pInsCPMLink (
			p_cpm_id       = ?,
			p_force_wtd = 'Y'
		)
	}


	ob_db::store_qry pmt_util::get_last_successful_deposit_mthds {
		select
			p.cr_date,
			m.cpm_id,
			NVL(cc.expiry,"NON_CC") as expiry
		from
			tCustPayMthd m,
			tPmt         p,
			outer tCPMCC cc
		where
			p.cpm_id       = m.cpm_id   and
			m.status       = 'A'        and
			cc.cpm_id      = m.cpm_id   and
			p.status       = 'Y'        and
			p.payment_sort = 'D'        and
			p.pmt_id       =
				(select
					max(last_ref_id)
				from
					tAcct               a,
					tCustStats          cs,
					tCustStatsAction    ca
				where
					a.cust_id           = ?
					and a.acct_id       = cs.acct_id
					and cs.action_id    = ca.action_id
					and ca.action_name  ='DEPOSIT')
	}



	ob_db::store_qry pmt_util::get_last_successful_deposit_mthds_slow {
		select
			p.cr_date,
			m.cpm_id,
			NVL(cc.expiry,"NON_CC") as expiry
		from
			tCustPayMthd m,
			tPmt p,
			outer tCPMCC cc
		where
			m.cust_id = ?
			and m.status = 'A'
			and m.cpm_id = p.cpm_id
			and cc.cpm_id = m.cpm_id
			and p.pmt_id = (
				select max(pmt_id)
					from tPmt t
				where
					t.cpm_id = m.cpm_id
					and t.status = 'Y'
					and t.payment_sort = 'D'
				)
		order by
			p.cr_date desc
	}

	ob_db::store_qry pmt_util::get_active_cards {
		select
			cc.cpm_id,
			cc.expiry
		from
			tCpmCC cc,
			tCustPayMthd cpm
		where
			cpm.cust_id = ? and
			cpm.status = 'A' and
			cpm.cpm_id = cc.cpm_id
	}

	ob_db::store_qry pmt_util::get_last_successful_deposit_CC {
		select
			p.cr_date,
			m.cpm_id,
			cc.expiry
		from
			tCustPayMthd m,
			tPmt         p,
			tCPMCC cc
		where
			p.cpm_id       = m.cpm_id   and
			m.status       = 'A'        and
			cc.cpm_id      = m.cpm_id   and
			p.status       = 'Y'        and
			p.payment_sort = 'D'        and
			p.pmt_id       =
				(select
					max(last_ref_id)
				from
					tAcct               a,
					tCustStats          cs,
					tCustStatsAction    ca
				where
					a.cust_id           = ?
					and a.acct_id       = cs.acct_id
					and cs.action_id    = ca.action_id
					and ca.action_name  ='DEPOSIT')
	}

	ob_db::store_qry pmt_util::get_last_successful_deposit_CC_slow {
		select
			p.cr_date,
			m.cpm_id,
			cc.expiry
		from
			tCustPayMthd m,
			tPmt p,
			tCPMCC cc
		where
			m.cust_id = ?
			and m.status = 'A'
			and m.cpm_id = p.cpm_id
			and cc.cpm_id = m.cpm_id
			and p.pmt_id = (
				select max(pmt_id)
					from tPmt t
				where
					t.cpm_id = m.cpm_id
					and t.status = 'Y'
					and t.payment_sort = 'D'
				)
		order by
			p.cr_date desc
	}

}

proc pmt_util::fraud_check_expired_cards {cust_id} {

	if {[catch {
		set rs [ob_db::exec_qry pmt_util::get_active_cards $cust_id]
	} msg]} {
		ob_log::write ERROR {$fn: Failed to get active cards for cust_id $cust_id - $msg}
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set is_ok [card_util::check_card_expiry [db_get_col $rs $i expiry]]

		if {!$is_ok} {
			set pmb   [payment_multi::calc_cpm_pmb $cust_id [db_get_col $rs $i cpm_id]]
			if {[lindex $pmb 1] != 0} {
				ob_pmt_validate::_fraud_flag_acct [ob_login::get acct_id] "Customer has one or more active expired cards"
			}
		}
	}
	ob_db::rs_close $rs
}



proc pmt_util::get_last_successful_deposit_method {cust_id {methods "mthds"}} {
	foreach qry [list get_last_successful_deposit_${methods} \
					get_last_successful_deposit_${methods}_slow] {
		#The default query is fast, but will not return a result if the most recent payment is unconfirmed
		#In this case, it will run the second, slower query, which is guaranteed to work.
		if {[catch {set rs [ob_db::exec_qry pmt_util::${qry} $cust_id]} msg]} {
			ob_log::write ERROR \
				{failed to retrieve customers active $methods details: $msg}
			set nrows 0
		} else {
			set nrows [db_get_nrows $rs]
		}
		set last_success 0

		# this checks whether the quick query result is an expired credit card
		# if it is, it will be run again for the slow query to find the last payment that is not
		for {set j 0} {$j < $nrows} {incr j} {
			set success_cpm_id [db_get_col $rs $j cpm_id]
			set expiry_details [db_get_col $rs $j expiry]
			if {$expiry_details == "NON_CC"} {
				set last_success $success_cpm_id
				break
			} else {
				set not_expired [card_util::check_card_expiry $expiry_details]
				if {$not_expired} {
					set last_success $success_cpm_id
					break
				}
			}
		}
		ob_db::rs_close $rs
		if {$last_success != 0} {
			break
		}
		ob_log::write INFO {$qry nrows=0}
		ob_log::write INFO {executing $qry instead}
	}
	return $last_success
}



proc pmt_util::_get_schemes {txn_type} {

	global CARD_SCHEMES

	catch {unset CARD_SCHEMES}

	if {$txn_type == "DEP"} {
		set dep_1 "Y"
		set dep_2 "Y"
		set wtd_1 "Y"
		set wtd_2 "N"
	} elseif {$txn_type == "WTD"} {
		set dep_1 "N"
		set dep_2 "Y"
		set wtd_1 "Y"
		set wtd_2 "Y"
	} else {
		ob_log::write ERROR {Invalid txn_type: $txn_type}
		return
	}

	set rs [ob_db::exec_qry pmt_util::get_schemes \
		$dep_1 $dep_2 $wtd_1 $wtd_2]
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set scheme [db_get_col $rs $i scheme]
		set CARD_SCHEMES($scheme,scheme_name) [db_get_col $rs $i scheme_name]
		set CARD_SCHEMES($scheme,type) [db_get_col $rs $i type]
		set CARD_SCHEMES($i) $scheme
	}

	set CARD_SCHEMES(num_card_scheme) $nrows
	ob_db::rs_close $rs
}


#-------------------------------------------------------------------------------
# Get the deposit/withdrawal settings for a given mthd
#
#    acct_id
#    pay_mthd  - the payment method
#    txn_type  - WTD or DEP
#    ccy_code
#    scheme    - the scheme of payment method
#
#    returns list in format:
#          success (0 if fails, 1 if successful)
#          list of name value pairs for
#             allow_funds      - Y/N can the cpm be used to make the transaction
#             min_txn          - the minimum transaction
#             max_week_txn     - the max transaction
#
#-------------------------------------------------------------------------------
proc pmt_util::get_mthd_limits {acct_id pay_mthd txn_type {ccy_code -1} {scheme ----}} {

	set fn {pmt_util::get_mthd_limits}

	if {$txn_type == "DEP"} {
		set pay_sort D
	} elseif {$txn_type == "WTD"} {
		set pay_sort W
	} else {
		ob_log::write ERROR {$fn - Invalid txn_type $txn_type}
		return [list 0 0 0]
	}

	if {$ccy_code == -1} {
		if {[catch {set rs [ob_db::exec_qry pmt_util::get_acct_details $acct_id]} msg]} {
			ob_log::write ERROR \
			   {$fn - Failed to execute query get_acct_details: $msg}
			return [list 0 0 0]
		} else {
			set ccy_code [db_get_col $rs 0 ccy_code]
			ob_db::rs_close $rs
		}
	}

	if {[catch {set rs [eval {ob_db::exec_qry \
		pmt_util::get_pay_mthd_limit_settings $acct_id $pay_mthd \
			$ccy_code $scheme $pay_sort}]} msg]} {

		ob_log::write ERROR \
			{pmt_util:get_pay_mthd_limit_settings Failed to load cpm limits: $msg}
		return [list 0 0 0]
	}

	set allow_funds      [db_get_coln $rs 0]
	set max_day_txn      [db_get_coln $rs 1]
	set max_txn          [db_get_coln $rs 2]
	set max_num_day_txn  [db_get_coln $rs 3]
	set min_txn          [db_get_coln $rs 4]
	set max_week_txn     [db_get_coln $rs 5]
	set max_num_week_txn [db_get_coln $rs 6]

	ob_db::rs_close $rs
	if {$allow_funds == "Y"} {
		set txn_allowed [min $max_num_week_txn $max_num_day_txn]
		if {$txn_allowed == "" || $txn_allowed} {
			# If number per day and week not 0 set max_txn to min
			set max_txn [min $max_txn $max_day_txn $max_week_txn]
			ob_log::write INFO {$fn - pay_mthd $pay_mthd \
			   txn allowed - min $min_txn max $max_txn}
			return [list 1 $min_txn $max_txn]
		} else {
			ob_log::write ERROR {$fn - pay_mthd $pay_mthd txn not allowed}
			return [list 0 0 0]
		}
	} else {
		ob_log::write ERROR {$fn - pay_mthd $pay_mthd txn not allowed}
		return [list 0 0 0]
	}
}


#-------------------------------------------------------------------------------
# Return how much a cust can wtd/dep on a given cpm, based on the cpm settings
# and how much the cust has wtd/dep recently via the cpm.
# Returns: <allow_txn> <min_txn> <max_txn>
#    allow_txn: 0 or 1
#    min_txn
#    max_txn
#-------------------------------------------------------------------------------
proc pmt_util::get_cpm_limits {cpm_id txn_type} {

	set fn {pmt_util::get_cpm_limits}

	if {$txn_type == "DEP"} {
		set payment_sort "D"
	} elseif {$txn_type == "WTD"} {
		set payment_sort "W"
	}

	set ret [get_cpm_limit_settings $cpm_id $payment_sort]

	if {![lindex $ret 0]} {
		ob_log::write ERROR {$fn - cpm_id $cpm_id txn not allowed}
		return [list 0 0 0]
	}

	array set TXN [lindex $ret 1]

	if {$TXN(allow_funds) == "N"} {
		ob_log::write ERROR {$fn - cpm_id $cpm_id txn not allowed}
		return [list 0 0 0]
	}

	set min_txn    $TXN(min_txn)
	set daily_max  $TXN(max_txn)
	set weekly_max $TXN(max_txn)

	if { $TXN(max_day_txn) != "" || $TXN(max_num_day_txn) != ""} {
		set weekly 0
		set daily_max [get_cpm_max_txn \
		               $cpm_id \
		               $weekly \
		               $TXN(max_txn) \
		               $TXN(max_day_txn) \
		               $TXN(max_num_day_txn) \
		               $payment_sort]
	}

	if { $TXN(max_week_txn) != "" || $TXN(max_num_week_txn) != ""} {
		set weekly 1
		set weekly_max [get_cpm_max_txn \
		                $cpm_id \
		                $weekly \
		                $TXN(max_txn) \
		                $TXN(max_week_txn) \
		                $TXN(max_num_week_txn) \
		                $payment_sort]
	}

	set max [min $daily_max $weekly_max]

	ob_log::write INFO \
	      {$fn - limits for cpm_id $cpm_id min_txn $min_txn max_txn $max}

	return [list 1 $min_txn $max]
}



#-------------------------------------------------------------------------------
# Get the deposit/withdrawal settings for a given cpm
#
#    cpm_id       - id of customer payment method
#    payment_sort - sort of payment (DEP/WTD)
#
#    returns list in format:
#          success (0 if fails, 1 if successful)
#          list of name value pairs for
#             allow_funds      - Y/N can the cpm be used to make the transaction
#             max_day_txn      - maximum value of transactions in day
#             max_txn          - maximum individual transaction
#             max_num_day_txn  - maximum number of transactions in a day
#             min_txn          - the minimum transaction
#             max_week_txn     - the maximum value of transactions in a week
#             max_num_week_txn - the maximum number of transactions in a week
#
#-------------------------------------------------------------------------------
proc pmt_util::get_cpm_limit_settings {cpm_id payment_sort} {

	if {$payment_sort != "D" && $payment_sort != "W"} {
		ob_log::write ERROR {pmt_util::get_cpm_limit_settings\
		   Invalid payment sort: $payment_sort}
		return [list 0]
	}

	if {[catch {set rs [eval {ob_db::exec_qry pmt_util::get_cpm_limit_settings \
	        $cpm_id $payment_sort}]} msg]} {
		ob_log::write ERROR \
			{pmt_util::get_cpm_limit_settings Failed to load cpm limits: $msg}
		return [list 0]
	}

	lappend ret allow_funds      [db_get_coln $rs 0]
	lappend ret max_day_txn      [db_get_coln $rs 1]
	lappend ret max_txn          [db_get_coln $rs 2]
	lappend ret max_num_day_txn  [db_get_coln $rs 3]
	lappend ret min_txn          [db_get_coln $rs 4]
	lappend ret max_week_txn     [db_get_coln $rs 5]
	lappend ret max_num_week_txn [db_get_coln $rs 6]

	ob_db::rs_close $rs

	return [list 1 $ret]
}


#-------------------------------------------------------------------------------
# Determine the max txn for a given cpm_id, based on the limit settings and the
# transactions carried out already.
# Will return 0 if the max number of transactions has been exceeded.
#-------------------------------------------------------------------------------
proc pmt_util::get_cpm_max_txn {cpm_id weekly max_txn txn_period_max txn_num_max payment_sort} {

	if {$txn_period_max != "" || $txn_num_max != ""} {

		set current_total 0
		set txn_count     0

		set period [expr {$weekly ? 6 : 0}]

		if {[catch {set rs [ob_db::exec_qry pmt_util::get_cust_txn_amt_for_period $cpm_id $period $payment_sort]} msg]} {
			ob_log::write ERROR \
			{pmt_util::get_cpm_max_txn: Failed to execute query: $msg}
			return 0
		} else {
			set nrows [db_get_nrows $rs]
			if {$nrows != 1} {
				ob_log::write ERROR \
				{pmt_util::get_cpm_max_txn: Invalid number of rows returned, $nrows}
				return 0
			} else {
				set txn_count     [db_get_col $rs 0 count]
				set current_total [expr { \
				      [db_get_col $rs 0 total] + [db_get_col $rs 0 commission]}]

			}
			ob_db::rs_close $rs
		}

		if {$txn_period_max != "" && $current_total > 0 } {
			set txn_period_max [expr $txn_period_max - $current_total]
		}

		if {$txn_num_max != "" && $txn_count >= $txn_num_max} {
			set txn_period_max 0
		}
	}

	set max [min $max_txn $txn_period_max]
	return $max
}


#-------------------------------------------------------------------------------
# Return the customer withdrawable balance
#-------------------------------------------------------------------------------
proc pmt_util::get_balance {cust_id} {

	if {[catch {set rs [ob_db::exec_qry pmt_util::get_balance $cust_id]} msg]} {
		ob_log::write ERROR {pmt_util::get_balance -\
		   Failed to get customer balance: $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR {pmt_util::get_balance -\
		   Cust balance query returned too many rows ([db_get_nrows $rs])}
		return 0
	}

	set bal [db_get_col $rs bal_wtd]

	db_close $rs

	return $bal
}


#-------------------------------------------------------------------------------
# Checks that the cpm_ids passed in belong to the customer.
# Returns 1 if all belong, 0 if any don't.
#-------------------------------------------------------------------------------
proc pmt_util::check_cpm_belongs_to_cust {cust_id cpm_id_list} {

	if {[catch {set rs \
	      [ob_db::exec_qry pmt_util::check_cpm_belongs_to_cust $cust_id]} msg]} {
		ob_log::write ERROR \
			"pmt_util::check_cpm_belongs_to_cust Failed to get cpm_ids: $msg"
		return 0
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		ob_log::write ERROR "pmt_util::check_cpm_belongs_to_cust - no cpm_ids\
		   found for cust_id $cust_id"
		return 0
	}

	set ret_list [list]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend ret_list [db_get_col $rs $i cpm_id]
	}

	foreach cpm_id $cpm_id_list {
		if {[lsearch $ret_list $cpm_id] == -1} {
			ob_log::write ERROR "pmt_util::check_cpm_belongs_to_cust -\
			   cpm_id $cpm_id does not belong to $cust_id"
			return 0
		}
	}

	return 1
}

