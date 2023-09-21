# $Id: payment_multi.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $


package require util_db

namespace eval payment_multi {
	variable INIT 0
}


# Initialisation
#
proc payment_multi::init {} {

	variable INIT

	if {$INIT} {
		ob_log::write WARNING {payment_multi::init - Already initialised}
		return
	}

	ob_log::write DEBUG {payment_multi::init: Initialising}

	ob_db::init
	payment_multi::_prep_sql

	set INIT 1
}



#
# Initialise the DB queries
#
proc payment_multi::_prep_sql {} {

	ob_db::store_qry payment_multi::get_max_multi_combine {
		select
			c.pay_mthd,
			c.pmt_scheme,
			NVL(m.max_combine,c.max_combine) as max_combine
		from
			tCPMMultiControl c,
			outer tCustMaxPmtMthd m
		where
			c.pay_mthd = m.pay_mthd
			and m.cust_id = ?
			and m.pmt_scheme = c.pmt_scheme
	}

	ob_db::store_qry payment_multi::get_cust_multi_settings {
		select
			max_pmt_mthds,
			max_pmb_period,
			max_cards
		from
			tCustMultiLimits
		where
			cust_id = ?
	}

	ob_db::store_qry payment_multi::get_payment_global_limits {
		select
			max_pmt_mthds,
			max_cards
		from
			tPmtMultiControl
	} 600

	ob_db::store_qry payment_multi::get_cust_mthds {
		select
			count(*) as number,
			pay_mthd,
			'----' as scheme
		from
			tCustPayMthd
		where
			cust_id = ?
			and status = 'A'
			and pay_mthd <> 'CC'
		group by
			2,3
		union
		select
			count(*) as number,
			m.pay_mthd,
			s.scheme
		from
			tCustPayMthd m,
			tCPMCC c,
			tCardScheme s
		where
			m.cust_id = ?
			and m.pay_mthd = 'CC'
			and m.status = 'A'
			and m.status_dep = 'A'
			and m.cpm_id = c.cpm_id
			and s.bin_lo = (
				select max(s2.bin_lo) from tCardScheme s2 where s2.bin_lo <= c.card_bin
			)
			and c.card_bin <= s.bin_hi
		group by
			2,3
	}


	# Get the maximum number of payment methods that can be combined with
	# the given cpm
	ob_db::store_qry payment_multi::get_max_pay_mthds {
		select
			NVL(m.max_combine, NVL(mc.max_combine, c.max_pmt_mthds)) as max_combine
		from
			tControl c,
			tCustPayMthd cpm,
			tCPMMultiControl mc,
			outer tCustMaxPmtMthd m
		where
			    cpm.cpm_id = ?
			and m.cust_id = cpm.cust_id
			and cpm.pay_mthd != 'CC'
			and mc.pmt_scheme = '----'
			and mc.pay_mthd = cpm.pay_mthd
			and m.pmt_scheme = '----'
			and m.pay_mthd = cpm.pay_mthd

		union all

		select
			NVL(m.max_combine, NVL(mc.max_combine, c.max_pmt_mthds)) as max_combine
		from
			tControl c,
			tCustPayMthd cpm,
			tCpmCC cc,
			tCardScheme s,
			tCPMMultiControl mc,
			outer tCustMaxPmtMthd m
		where
			cpm.cpm_id = ?
			and cc.cpm_id = cpm.cpm_id
			and s.bin_lo = (
				select max(s2.bin_lo) from tCardScheme s2 where s2.bin_lo <= cc.card_bin
			)
			and cc.card_bin <= s.bin_hi
			and m.cust_id = cpm.cust_id
			and cpm.pay_mthd = 'CC'
			and mc.pay_mthd = cpm.pay_mthd
			and mc.pmt_scheme = s.scheme
			and m.pay_mthd = cpm.pay_mthd
			and m.pmt_scheme = s.scheme
	}

	#
	# Work out the withdraw CPMs for a customer
	#
	set ignore_cash ""
	if {[OT_CfgGet IGNORE_WTD_CASH 0]} {
		set ignore_cash {and cpm.pay_mthd != 'CSH'}
	}

	ob_db::store_qry payment_multi::get_dep_cpms {
		select
			m.cpm_id,
			m.pay_mthd,
			m.deposit_check
		from
			tCustPayMthd m,
			tCPMGroupLink l1
		where
			m.cust_id = ? and
			m.status = 'A' and
			l1.cpm_id = m.cpm_id and
			l1.type = 'D' and
			1 > (
				select
					count(*)
				from
					tCPMGroupLink l2
				where
					l1.cpm_grp_id = l2.cpm_grp_id and
					l2.type in ('B','W')
			)
	}

	ob_db::store_qry payment_multi::get_wtd_cpms [subst {
		select {+ORDERED}
			cpm.cpm_id,
			cpm.pay_mthd,
			cpm.deposit_check,
			cpm.cr_date,
			c.pmb_priority,
			"NON_CC" as expiry
		from
			tCustPayMthd cpm,
			tCPMMultiControl c
		where
			    cpm.cust_id = ?
			and cpm.status = 'A'
			and cpm.status_wtd = 'A'
			$ignore_cash
			and cpm.auth_wtd in ('Y', 'P')
			and c.pay_mthd = cpm.pay_mthd
			and c.pmt_scheme = '----'
			and (
				   cpm.deposit_check = 'N'
				or (
					    cpm.deposit_check = 'Y'
					and cpm.auth_dep = 'Y'
				)
			)

		union all

		select {+ORDERED}
			cpm.cpm_id,
			cpm.pay_mthd,
			cpm.deposit_check,
			cpm.cr_date,
			c.pmb_priority,
			cc.expiry
		from
			tCustPayMthd cpm,
			tCPMCC cc,
			tCardScheme s,
			tCPMMultiControl c
		where
			    cpm.cust_id = ?
			and cpm.status = 'A'
			and cpm.status_wtd = 'A'
			and cpm.auth_wtd in ('Y', 'P')
			and cpm.pay_mthd = 'CC'
			and cc.cpm_id = cpm.cpm_id
			and s.bin_lo = (
				select max(s2.bin_lo) from tCardScheme s2 where s2.bin_lo <= cc.card_bin
			)
			and s.bin_hi >= cc.card_bin
			and c.pay_mthd = cpm.pay_mthd
			and c.pmt_scheme = s.scheme
			and (
					cpm.deposit_check = 'N'
				or (
					cpm.deposit_check = 'Y'
					and cpm.auth_dep = 'Y'
				)
			)
	}]

	#
	# Calculate the PMB period to use. For linked methods
	# this should be the largest period for any method
	#
	ob_db::store_qry payment_multi::get_cpm_period {
		select {+ORDERED}
			NVL(cpm.pmb_period, NVL(pmb.pmb_period, NVL(cml.max_pmb_period, c.pmb_period))) as period
		from
			tCustPayMthd cpm,
			tCPMCC cc,
			tCardScheme s,
			tCPMMultiControl c,
			outer tCustPmbPeriod pmb,
			outer tCustMultiLimits cml
		where
				cpm.cpm_id = ?
			and cpm.pay_mthd = 'CC'
			and cc.cpm_id = cpm.cpm_id
			and s.bin_lo = (
				select max(s2.bin_lo) from tCardScheme s2 where s2.bin_lo <= cc.card_bin
			)
			and cc.card_bin <= s.bin_hi
			and c.pay_mthd = cpm.pay_mthd
			and c.pmt_scheme = s.scheme
			and pmb.pay_mthd = cpm.pay_mthd
			and pmb.pmt_scheme = s.scheme
			and pmb.cust_id = cpm.cust_id
			and cpm.cust_id = cml.cust_id

		union all

		select {+ORDERED}
			NVL(cpm.pmb_period, NVL(pmb.pmb_period, NVL(cml.max_pmb_period, c.pmb_period))) as period
		from
			tCustPayMthd cpm,
			tCPMMultiControl c,
			outer tCustPmbPeriod pmb,
			outer tCustMultiLimits cml
		where
				cpm.cpm_id = ?
			and cpm.pay_mthd != 'CC'
			and c.pay_mthd = cpm.pay_mthd
			and c.pmt_scheme = '----'
			and pmb.pay_mthd = cpm.pay_mthd
			and pmb.pmt_scheme = '----'
			and pmb.cust_id = cpm.cust_id
			and cpm.cust_id = cml.cust_id
	}

	ob_db::store_qry payment_multi::get_acct_type {
		select
			acct_type
		from
			tAcct
		where
			cust_id = ?
	}

	#
	# Calculate the PMB value of a CPM
	#
	ob_db::store_qry payment_multi::calc_cpm_pmb {
		select
			SUM(NVL(DECODE(p.payment_sort,'D',p.amount,'W',-p.amount),0)) as pmb_value
		from
			tCustPayMthd cpm,
			outer (
				tCPMGroupLink l1,
				tCPMGroupLink l2,
				tPmt p
			)
		where
			cpm.cpm_id      = ?
			and cpm.cust_id = ?
			and l1.cpm_id = cpm.cpm_id
			and l2.cpm_grp_id = l1.cpm_grp_id
			and p.cpm_id = l2.cpm_id
			and (
				(p.payment_sort = 'D' and p.status = 'Y')
				or
				(p.payment_sort = 'W' and p.status in ('Y', 'P'))
			)
			and p.cr_date < current
			and extend (p.cr_date, year to day) > extend(current, year to day) - ? units day
	}

	ob_db::store_qry payment_multi::get_linked_mthds {
		select
			l2.cpm_id
		from
			tCPMGroupLink l1,
			tCPMGroupLink l2,
			tCustPayMthd m,
			tCPMGroup g
		where
			l1.cpm_id = ?
			and l1.cpm_grp_id = g.cpm_grp_id
			and l2.cpm_grp_id = g.cpm_grp_id
			and l2.cpm_id = m.cpm_id
			and l2.cpm_id <> l1.cpm_id
			and l2.type <> 'W'
			and m.status = 'A'
	}

	# Fetch any manual adjustmets associated with a payment method
	# These should time out on the PMB when the associated payment does
	# Note that we include adjustments on failed payments
	ob_db::store_qry payment_multi::calc_man_adj_pmb {
		select
			SUM(NVL(mj.amount,0)) as pmb_value
		from
			tCustPayMthd  cpm,
			outer (
				tCPMGroupLink l1,
				tCPMGroupLink l2,
				tPmt          p,
				tManAdj       mj
			)
		where
			cpm.cpm_id  = ?
			and cpm.cust_id = ?
			and l1.cpm_id = cpm.cpm_id
			and l2.cpm_grp_id = l1.cpm_grp_id
			and p.cpm_id = l2.cpm_id
			and (
				(p.payment_sort = 'D' and p.status in ('Y', 'N'))
				or
				(p.payment_sort = 'W' and p.status in ('Y', 'P', 'N'))
			)
			and p.cr_date < current
			and extend (p.cr_date,year to day) > extend(current, year to day) - ? units day
			and mj.ref_id = p.pmt_id
			and mj.ref_key = 'PMT'
			and mj.pending = 'P'
	}

	ob_db::store_qry payment_multi::get_max_pmb_remove {
		select
			max_pmb_remove
		from
			tPmtChangeChk
	} 600

}


#
# Get the Payment Mathod Balance (PMB) values for all active
# cpms associated with a customer
#
# Returns an array (in list form) containing the pmt mthds and the relevant data
# The array also contains a list of ordered cpm_ids (ordered_cpm_ids) and a list
# of cpm_ids with a positive PMB (mthds_with_pmb)
proc payment_multi::get_cust_pmbs {cust_id} {

	set fn {payment_multi::get_cust_pmbs}

	ob_log::write DEBUG {$fn - cust_id=$cust_id}

	# We need to create an empty result set so we can
	# bulid up our list of PMBs
	set rs_pmb [db_create [list \
		cpm_id \
		pay_mthd \
		deposit_check \
		pmb_priority \
		pmb_value \
		cr_date] \
	]

	# Get the withdraw CPMs for this customer
	if {[catch {
		set rs [ob_db::exec_qry payment_multi::get_wtd_cpms \
			$cust_id \
			$cust_id \
		]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cust_pmbs: \
			Failed to exec qry payment_multi::get_wtd_cpms}
		return ERROR
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		ob_log::write ERROR {$fn - didn't find any wtd\
		   mthds for cust_id $cust_id}
		return NO_WTD_MTHDS
	} else {
		ob_log::write DEBUG {$fn - Found $nrows wtd CPMs}
	}

	for {set i 0} {$i < $nrows} {incr i} {

		set cpm_id   [db_get_col $rs $i cpm_id]
		set pay_mthd [db_get_col $rs $i pay_mthd]
		set cr_date  [db_get_col $rs $i cr_date]
		set card_expiry [db_get_col $rs $i expiry]

		foreach {code pmb_value pmb_period} [calc_cpm_pmb $cust_id $cpm_id] {}

		# Do not offer withdrawals to expired cards
		if {$pay_mthd == "CC" && ![card_util::check_card_expiry $card_expiry]} {
			continue
		}

		if {!$code} {
			ob_log::write ERROR {$fn -\
			   Failed to calculate PMB for cpm_id=$cpm_id - $msg}

			# Skip to the next cpm. We will not offer this one
			# to the customer
			continue
		} else {

			db_add_row $rs_pmb [list \
				$cpm_id \
				$pay_mthd \
				[db_get_col $rs $i deposit_check] \
				[db_get_col $rs $i pmb_priority] \
				$pmb_value   \
				[clock scan $cr_date] \
			]
		}
	}
	ob_db::rs_close $rs

	# Sort the PMB result set based on pmb_priority, pmb_value and
	# cr_date of the CPM
	set sort_order [list \
		pmb_priority int ascending   \
		pmb_value numeric descending \
		cr_date int descending       \
	]
	db_sort $sort_order $rs_pmb

	set MTHDS(ordered_cpm_ids) [list]
	set MTHDS(mthds_with_pmb)  [list]

	set nrows [db_get_nrows $rs_pmb]

	if {$nrows == 0} {
		ob_log::write ERROR {$fn - couldn't retrieve\
		   pmb for any mthds for cust_id $cust_id}
		return NO_WTD_MTHDS
	}

	for {set i 0} {$i < $nrows} {incr i} {
		set cpm_id [db_get_col $rs_pmb $i cpm_id]
		lappend MTHDS(ordered_cpm_ids) $cpm_id

		set MTHDS($cpm_id,pay_mthd)      [db_get_col $rs_pmb $i pay_mthd]
		set MTHDS($cpm_id,pmb_value)     [db_get_col $rs_pmb $i pmb_value]
		set MTHDS($cpm_id,deposit_check) [db_get_col $rs_pmb $i deposit_check]
		set MTHDS($cpm_id,wtd_mthd)      1

		if {$MTHDS($cpm_id,pmb_value) > 0} {
			lappend MTHDS(mthds_with_pmb) $cpm_id
		}

		ob_log::write INFO {$fn -\
		   cpm_id $cpm_id\
		   pay_mthd $MTHDS($cpm_id,pay_mthd)\
		   pmb_value $MTHDS($cpm_id,pmb_value)\
		   deposit_check $MTHDS($cpm_id,deposit_check)}
	}
	ob_db::rs_close $rs_pmb

		# We need to add in any unlinked deposit only methods with their wtd set
	# to No
	if {[catch {
		set rs_dep_cpm [ob_db::exec_qry payment_multi::get_dep_cpms \
			$cust_id \
		]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cust_pmbs: \
			Failed to exec qry payment_multi::get_dep_cpms}
		return ERROR
	}

	set nrows [db_get_nrows $rs_dep_cpm]

	for {set i 0} {$i < $nrows} {incr i} {
		set cpm_id [db_get_col $rs_dep_cpm $i cpm_id]
		lappend MTHDS(ordered_cpm_ids) $cpm_id

		foreach {code pmb_value pmb_period} [calc_cpm_pmb $cust_id $cpm_id] {}

		set MTHDS($cpm_id,pay_mthd)      [db_get_col $rs_dep_cpm $i pay_mthd]
		set MTHDS($cpm_id,pmb_value)     $pmb_value
		set MTHDS($cpm_id,deposit_check) [db_get_col $rs_dep_cpm $i deposit_check]
		set MTHDS($cpm_id,wtd_mthd)      0

		if {$MTHDS($cpm_id,pmb_value) > 0} {
			lappend MTHDS(mthds_with_pmb) $cpm_id
		}

		ob_log::write INFO {$fn -\
		   cpm_id $cpm_id\
		   pay_mthd $MTHDS($cpm_id,pay_mthd)\
		   pmb_value $MTHDS($cpm_id,pmb_value)\
		   deposit_check $MTHDS($cpm_id,deposit_check)\
		   wtd_mthd $MTHDS($cpm_id,wtd_mthd)}
	}

	ob_db::rs_close $rs_dep_cpm

	return [array get MTHDS]
}


#
# Calculates the Payment Method Balance (PMB) for the given CPM.
# Returns [1 pmb_value days] if successful, 0 otherwise
#
proc payment_multi::calc_cpm_pmb { cust_id cpm_id } {

	ob_log::write DEBUG {payment_multi::get_cpm_pmb: \
		cust_id=$cust_id, cpm_id=$cpm_id}

	# Get Account type
	if {[catch {
		set acct_rs [ob_db::exec_qry payment_multi::get_acct_type $cust_id]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_acct_type: \
			Failed to exec qry get_acct_type - $msg}

		return [list ERROR]
	}

	set acct_type [db_get_coln $acct_rs 0 0]
	ob_db::rs_close $acct_rs

	if {$acct_type != "DEP"} {
		return [list 1 0 0]
	} else {

		foreach {success period} [payment_multi::get_cpm_period $cpm_id] {}

		if {!$success} {
			ob_log::write ERROR {Failed to find period to check}
			return 0
		}

		ob_log::write DEBUG {payment_multi::calc_cpm_pmb: \
			Calculating PMB for the last $period days}

		# No point in running the query if the pmb_period is 0
		if {$period == 0} {
			return [list 1 0 0]
		}

		if {[catch {

			set rs_pmb [ob_db::exec_qry payment_multi::calc_cpm_pmb \
				$cpm_id  \
				$cust_id \
				$period  \
			]

			set pmb [format %.2f [db_get_col $rs_pmb 0 pmb_value]]
			ob_db::rs_close $rs_pmb

		} msg]} {
			ob_log::write ERROR {payment_multi::calc_cpm_pmb: \
				Failed to calculate PMB for cpm $cpm_id - $msg}

			return 0
		}

		if {[catch {

			set rs_man_pmb [ob_db::exec_qry payment_multi::calc_man_adj_pmb \
				$cpm_id  \
				$cust_id \
				$period  \
			]

			set pmb [expr {$pmb + [format %.2f [db_get_col $rs_man_pmb 0 pmb_value]]}]
			ob_db::rs_close $rs_man_pmb

		} msg]} {
			ob_log::write ERROR {payment_multi::calc_man_adj_pmb: \
				Failed to calculate MAN PMB for cpm $cpm_id - $msg}

			return 0
		}

		return [list 1 $pmb $period]
	}
}



#
# Determine the period of time we should look at for a given CPM
#
#    cpm_id - the id of the payment method to find the period
#
#    returns list
#            success - 1 if successful, 0 if not
#            period  - period to use (in days)
#
proc payment_multi::get_cpm_period { cpm_id } {

	if {[catch {
		set rs_period [ob_db::exec_qry payment_multi::get_cpm_period \
			$cpm_id \
			$cpm_id \
		]
	} msg]} {
		ob_log::write ERROR \
			{payment_multi::get_linked_mthds: Failed to get period - $msg}
		return [list 0 {}]
	}

	set period [db_get_col $rs_period 0 period]
	ob_db::rs_close $rs_period


	# Get all the methods
	if {[catch {
		set rs_linked [ob_db::exec_qry payment_multi::get_linked_mthds $cpm_id]
	} msg]} {
		ob_log::write ERROR \
			{payment_multi::get_linked_mthds: Failed to get linked mthds - $msg}
		return [list 0 {}]
	}

	set nrows [db_get_nrows $rs_linked]

	# Loop through methods and choose the largest expiry to use
	for {set i 0} {$i < $nrows} {incr i} {
		set linked_cpm [db_get_col $rs_linked $i cpm_id]

		# Work out what period of time we should be looking at payments
		# for. This is the maximum PMB period for an linked CPMs
		if {[catch {
			set rs_period [ob_db::exec_qry payment_multi::get_cpm_period \
				$linked_cpm \
				$linked_cpm \
			]

			set cpm_period [db_get_col $rs_period 0 period]

			if {$cpm_period > $period} {
				set period $cpm_period
			}

			ob_db::rs_close $rs_period

		} msg]} {
			ob_db::rs_close $rs_linked
			ob_log::write ERROR \
				{payment_multi::get_cpm_period: Failed to calculate PMB payment period - $msg}
			return [list 0 {}]
		}
	}

	ob_db::rs_close $rs_linked

	return [list 1 $period]
}



#
# Get the number of additional CPMs we are allowed to combine with
# the given cpm
#
proc payment_multi::get_cpm_combis {cpm_id} {

	ob_log::write DEBUG {payment_multi::get_cpm_combis: cpm_id=$cpm_id}

	if {[catch {
		set rs [ob_db::exec_qry payment_multi::get_max_pay_mthds \
			$cpm_id \
			$cpm_id \
		]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cpm_combis: \
			Failed to exec qry get_max_pay_mthds - $msg}
		return ERROR
	}

	set ret [db_get_col $rs 0 max_combine]
	ob_db::rs_close $rs

	return $ret

}



#-------------------------------------------------------------------------------
# Works out the methods that a customer can still register
#
# Returns a list of available payment methods
#   - first item is a success or failure code OK or ERROR
#   - list of lists {PAY_MTHD SCHEME} that can be added by the
#   - customer
#
#  return examples:-  OK {{BANK ----} {CC VISA} {CHQ ----}}
#
#-------------------------------------------------------------------------------
proc payment_multi::get_avail_mthds {cust_id} {

	set avail_cpms [list]

	# Get Account type
	if {[catch {
		set acct_rs [ob_db::exec_qry payment_multi::get_acct_type $cust_id]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_acct_type: \
			Failed to exec qry get_acct_type - $msg}

		return [list ERROR]
	}

	set acct_type [db_get_coln $acct_rs 0 0]
	ob_db::rs_close $acct_rs


	## Get the number of each method a customer currently has
	if {[catch {
		set mthds_rs [ob_db::exec_qry payment_multi::get_cust_mthds \
			$cust_id $cust_id]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cust_mthds: \
			Failed to exec qry get_cust_mthds - $msg}
		return [list ERROR]
	}

	set methods(CC) 0
	set methods(total) 0

	for {set i 0} {$i < [db_get_nrows $mthds_rs]} {incr i} {
		set number [db_get_col $mthds_rs $i number]
		set pay_mthd [db_get_col $mthds_rs $i pay_mthd]
		set scheme [db_get_col $mthds_rs $i scheme]

		if {$pay_mthd == "CHQ" || $pay_mthd == "BANK"} {
			continue
		} else {
			set methods($pay_mthd,$scheme) $number
			set methods(total) [expr {$number + $methods(total)}]

			if {$pay_mthd == "CC"} {
				set methods(CC) [expr {$number + $methods(CC)}]
			}
		}
	}

	ob_db::rs_close $mthds_rs

	# DBT and CDT customers should never have more than 1 card
	if {$acct_type == "DBT" || $acct_type == "CDT"} {
		if {$methods(CC)} {
			return [list OK {}]
		} else {
            return [list OK {CC AMEX CC ELTN CC JCB CC LASR CC MC CC SOLO CC SWCH CC VC CC VD CC EP CC G2P CC DC CC MCD CC 4BE6 CC KAPO}]
		}
	}

	## Check whether a customer has a maximum set (flagged) at account level
	if {[catch {
		set rs_cust [ob_db::exec_qry payment_multi::get_cust_multi_settings \
			$cust_id]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cust_multi_settings: \
			Failed to exec qry get_cust_multi_settings - $msg}
		return [list ERROR]
	}

	if {[db_get_nrows $rs_cust]} {
		set temp_max_overall_methods [db_get_col $rs_cust 0 max_pmt_mthds]
		set temp_max_cards [db_get_col $rs_cust 0 max_cards]

		if {$temp_max_overall_methods != ""} {
			set max_overall_methods $temp_max_overall_methods
		}
		if {$temp_max_cards != ""} {
			set max_cards $temp_max_cards
		}
	}

	ob_db::rs_close $rs_cust

	if {[catch {
		set global_rs [ob_db::exec_qry \
			payment_multi::get_payment_global_limits]
	} msg]} {
		ob_log::write ERROR {payment_multi::get_cpm_combis: \
			Failed to exec qry get_payment_global_limits - $msg}
		return [list ERROR]
	}

	if {![info exists max_overall_methods]} {
		set max_overall_methods [db_get_col $global_rs 0 max_pmt_mthds]
	}

	if {![info exists max_cards]} {
		set max_cards [db_get_col $global_rs 0 max_cards]
	}

	ob_db::rs_close $global_rs

	if {$methods(total) >= $max_overall_methods} {
		# Cannot register anymore methods lets not proceed
		return [list OK]
	}

	if {[catch {
		set max_mthds_rs [ob_db::exec_qry payment_multi::get_max_multi_combine\
			$cust_id]
	} msg ]} {
		ob_log::write ERROR {payment_multi::get_max_multi_combine: \
			Failed to exec qry get_max_multi_combine - $msg}
		return ERROR
	}

	for {set i 0} {$i < [db_get_nrows $max_mthds_rs]} {incr i} {
		set pay_mthd [db_get_col $max_mthds_rs $i pay_mthd]
		set scheme [db_get_col $max_mthds_rs $i pmt_scheme]
		set max_combine [db_get_col $max_mthds_rs $i max_combine]

		if {$max_combine} {
			# max combine is not zero
			if {$pay_mthd == "CC" && $methods(CC) >= $max_cards} {
				## Don't add more cards available if max has been hit
			} else {
				if {[info exists methods($pay_mthd,$scheme)]} {
					# customer has already got this method
					if {$methods($pay_mthd,$scheme) < $max_combine} {
						lappend avail_cpms $pay_mthd $scheme
					}
				} else {
					lappend avail_cpms $pay_mthd $scheme
				}
			}
		} else {
			# The max combine for a method is 0 so can only be added once,
			# add to available methods if customers # methods is 0
			if {!$methods(total)} {
				lappend avail_cpms $pay_mthd $scheme
			} else {
				if {[info exists methods($pay_mthd,$scheme)]} {
					# Customer already has this method and its combine is 0
					# they should not be adding anymore methods
					ob_db::rs_close $max_mthds_rs
					return [list OK]
				}
			}
		}
	}
	ob_db::rs_close $max_mthds_rs

	return [list OK $avail_cpms]
}



#
# Stub - given a customer return whether they can register more of a payment
# method
#    - successs 1 or 0
#    - whether the method can be registered
proc payment_multi::get_mthd_can_register {cust_id pay_mthd {scheme "----"}} {

	set avail_mthds [payment_multi::get_avail_mthds $cust_id]

	if {[lindex $avail_mthds 0] == "OK"} {
		set mthds [join [lindex $avail_mthds 1]]
	} else {
		ob_log::write ERROR {get_mthd_can_register: Failed get_avail_mthds}
		return [list 0 0]
	}

	if {$scheme == "----"} {
		if {[lsearch $mthds $pay_mthd] == -1} {
			ob_log::write INFO {get_mthd_can_register: pay_mthd $pay_mthd not \
				allowed to be registered for cust_id: $cust_id}
			return [list 1 0]
		} else {
			ob_log::write INFO {get_mthd_can_register: pay_mthd $pay_mthd \
				allowed to registered for cust_id: $cust_id}
			return [list 1 1]
		}
	} else {
		foreach {avail_mthd avail_scheme} [lindex $avail_mthds 1] {
			if {$avail_mthd == $pay_mthd && $avail_scheme == $scheme} {
				return [list 1 1]
			}
		}
		return [list 1 0]
	}
}



#-------------------------------------------------------------------------------
# Works out what the customer is allowed to withdraw and where to, based on PMBs
# and customer limits.
#
# Three outcomes possible:
# - Customer is told where they money is going
# - Customer is told where some of the money is going and how much they cannot
#   withdraw
# - Customer is told where some of the money is going and given a choice of
#   where the rest goes
#
# Returns a list: <ret code> <wtd amount> <remaining amount> <list of pmt mthds>
# - ret code: ERROR, NONE, EXACT, LESS, MORE, CHOICE
#      ERROR:  An error occurred. The second element of the list will be an
#              error message, if available.
#      NONE:   Cannot wtd anything. The second element of the list will be an
#              explanation, if available.
#      EXACT:  Getting the requested amount
#      LESS:   Can only withdraw part of what they asked for
#      CHOICE: The customer can choose where they wtd part or all of the amount
#
# - wtd amount: how much the wtd totals (so far)
# - remaining amount = amount requested - wtd amount
#              Note that this will be negative for ret code MORE.
# - list of pmt mthds: a list of lists. Each pmt mthd will be:
#      <cpm_id> <pmt_mthd> <amount> <can_wtd_more> <min_wtd> <max_wtd>
#
#        cpm_id
#        pmt_mthd
#        amount: 0 or more
#        can wtd more: 0 or 1
#        min_wtd: does not take into account the forced wtd amount
#        max_wtd: does not take into account the forced wtd amount
#
# - total wtd : number of total WTD methods associated to this customer
#
#-------------------------------------------------------------------------------
proc payment_multi::get_allowed_wtd {
	cust_id
	wtd_amount
	{cust_balance ""}
	{channel I}
	{force_all 0}} {

	set fn {payment_multi::get_allowed_wtd}

	set wtd_amount [format %0.2f $wtd_amount]

	ob_log::write DEBUG {$fn - wtd_amount $wtd_amount}

	if {$cust_balance == ""} {
		set cust_balance [pmt_util::get_balance $cust_id]
	}

	# This should have been checked by the calling procedure
	if {$cust_balance < $wtd_amount} {
		ob_log::write ERROR {$fn - Failing wtd: wtd_amount $wtd_amount is\
		   bigger than cust balance $cust_balance.}
		return [list ERROR "INSUFFICIENT_BALANCE"]
	}

	set rem_amount $wtd_amount
	set cur_total  0
	set cur_amount 0

	# Retrieve the PMBs for all withdrawal methods for this customer
	set ret [get_cust_pmbs $cust_id]
	set tot_wtd_mthd 0

	if {$ret == "ERROR"} {
		return [list ERROR ""]
	} elseif {$ret == "NO_WTD_MTHDS"} {
		return [list "ERROR" "NO_WTD_MTHDS"]
	} else {
		array set MTHDS $ret
		# This stores the total number of WTD methods associated to the customer
		set tot_wtd_mthd [llength $MTHDS(ordered_cpm_ids)]
	}

	# Does cust have any PMBs to clear?
	if {[llength $MTHDS(mthds_with_pmb)] > 0} {
		ob_log::write INFO {$fn - methods with pmb $MTHDS(mthds_with_pmb)}
		set uncleared_pmbs $MTHDS(mthds_with_pmb)
		set max_pmb_remove [get_max_pmb_remove]

	# No PMBs to clear - cust can choose any pmt mthd
	} else {
		ob_log::write INFO {$fn - no PMBs to clear - user can choose pmt mthd}
		set uncleared_pmbs [list]
	}

	# If the cust is wtd full balance we might override min wtd limits
	if {$wtd_amount == $cust_balance} {
		set full_balance 1
	} else {
		set full_balance 0
	}

	set first_wtd_cpm_id -1
	set last_cpm_with_pmb [lindex \
	       $MTHDS(mthds_with_pmb) [expr {[llength $MTHDS(mthds_with_pmb)] - 1}]]


	#########
	# If the cust has PMBs to clear loop through them and work out
	# how much they have to wtd to each pmt mthd.
	#########

	foreach cpm_id $MTHDS(mthds_with_pmb) {

		set add_to_wtd 0

		if {$MTHDS($cpm_id,wtd_mthd)} {
			set limits [pmt_util::get_cpm_limits $cpm_id WTD]

			set MTHDS($cpm_id,allow_txn)  [lindex $limits 0]
			set MTHDS($cpm_id,min_wtd)    [lindex $limits 1]
			set MTHDS($cpm_id,max_wtd)    [lindex $limits 2]
			set MTHDS($cpm_id,wtd_amount) 0
		} else {
			set MTHDS($cpm_id,allow_txn)  0
			set MTHDS($cpm_id,min_wtd)    0
			set MTHDS($cpm_id,max_wtd)    0
			set MTHDS($cpm_id,wtd_amount) 0
		}

		# If we have hit any pmt mthd limits then we can't use this method
		if {!$MTHDS($cpm_id,allow_txn) || $MTHDS($cpm_id,max_wtd) <= 0} {
			ob_log::write INFO {$fn - cpm_id $cpm_id has reached limit -\
			   cannot be used to withdraw - allow_txn =\
			   $MTHDS($cpm_id,allow_txn) max_wtd = $MTHDS($cpm_id,max_wtd)}

			set MTHDS($cpm_id,allow_txn)  0
			set MTHDS($cpm_id,max_wtd)    0
			continue
		}

		# We haven't hit any pmt mthd limits, have to use this mthd first

		# The amount to wtd to this mthd will be the smallest out of PMB,
		# remaining limit for the mthd and the max_wtd for the mthd.
		set cur_amount [min $MTHDS($cpm_id,pmb_value) \
		                    $MTHDS($cpm_id,max_wtd) \
		                    $rem_amount]

		# Is the current amount to withdraw smaller than the min_wtd for
		# the pmt mthd?
		if {$cur_amount < $MTHDS($cpm_id,min_wtd)} {
			# Can we bump the cur_amount up without breaching any limits?
			# Check the cust is wtd enough and that the min_wtd isn't bigger
			# than the the max_wtd
			if {[format %0.2f [expr {$cur_total + $MTHDS($cpm_id,min_wtd)}]] <= \
			    $wtd_amount && \
			    $MTHDS($cpm_id,min_wtd) <= $MTHDS($cpm_id,max_wtd)} {

				ob_log::write DEBUG {$fn - Setting wtd amount to min wtd\
				   ($MTHDS($cpm_id,min_wtd)) for cpm_id $cpm_id}

				set cur_amount $MTHDS($cpm_id,min_wtd)
				set add_to_wtd 1

			# We can't increase the wtd amount without breaking a limit
			} else {

				# Are we already making another withdrawal?
				if {$first_wtd_cpm_id != -1} {

					# Are there any other pmt mthds left to try?
					if {$cpm_id == $last_cpm_with_pmb} {

						# Amnt less than min_wtd, no other pmt mthds left,
						# already making a wtd.
						# If the amount is less than the max_pmb_remove and it
						# won't push that wtd over the limit then we add it to
						# that one.
						if {$rem_amount <= $max_pmb_remove && [format %0.2f \
						   [expr {$MTHDS($first_wtd_cpm_id,wtd_amount) + $rem_amount}]] <= \
						   $MTHDS($first_wtd_cpm_id,max_wtd)} {
							# Won't push it over the limit - add it on
							ob_log::write INFO {$fn - Adding $cur_amount to\
							   highest priority pmt mthd ($first_wtd_cpm_id)}

							set MTHDS($first_wtd_cpm_id,wtd_amount) [format %0.2f \
							     [expr {$MTHDS($first_wtd_cpm_id,wtd_amount) + $rem_amount}]]
							set cur_total  [format %0.2f [expr {$cur_total + $rem_amount}]]
							set rem_amount 0

							# Are we clearing the PMB on this pmt mthd?
							if {$MTHDS($first_wtd_cpm_id,wtd_amount) >= \
							    $MTHDS($first_wtd_cpm_id,pmb_value)} {
								# Have we already cleared the PMB on the mthd?
								# In theory we should have, but best check
								set idx [lsearch $uncleared_pmbs $first_wtd_cpm_id]
								if {$idx != -1} {
									set uncleared_pmbs [lreplace $cpm_id $uncleared_pmbs $idx $idx]
								}
							}

						# Amnt less than min_wtd, no other pmt mthds left,
						# can't add to prev wtd without breaching limit.
						# Can't break min wtd on UKSH/IKSH
						} elseif {($full_balance || \
						          $rem_amount > $max_pmb_remove) && \
						          $rem_amount <= $MTHDS($cpm_id,max_wtd) && \
						          [lsearch -exact {UKSH IKSH} $MTHDS($cpm_id,pay_mthd)] == -1 \
						} {
							set cur_amount $rem_amount

							ob_log::write INFO {$fn - Allowing wtd of less than min wtd for\
							   cpm_id $cpm_id (full_balance $full_balance ||\
							   rem_amount $rem_amount > $max_pmb_remove max_pmb_remove)}
							set add_to_wtd 1

						# Customer isn't getting the full amount.
						} else {
							ob_log::write INFO {$fn - not wtd full amount.\
							   full_balance $full_balance rem_amount $rem_amount}
						}

					# There are other pmt mthds to try, we'll try them
					}

				} else {
					# Amnt less than min_wtd, no other wtd yet.
					# Is cust trying to withdraw full balance?
					if {$full_balance && \
						[lsearch -exact {UKSH IKSH} $MTHDS($cpm_id,pay_mthd)] == -1 \
					} {
						ob_log::write INFO {$fn - cust is wtd full balance -\
						   overriding pmt mthd min_wtd on cpm_id $cpm_id}
						set add_to_wtd 1

					# No other wtd yet - are there any other pmt mthds left to
					# try?
					} elseif {$cpm_id == $last_cpm_with_pmb} {
						ob_log::write INFO {$fn - cannot withdraw $cur_amount.\
						   Amount is below min wtd of all pmt mthds and cust\
						   not withdrawing full balance.}

					# Can't increase the amount to meet the min_wtd for this
					# mthd, but there are more mthds, so lets try one of them
					}
				}
			}

		# Current amount to wtd is more than the min wtd.
		# Add this wtd to the list and continue
		} else {
			set add_to_wtd 1
		}

		if {$add_to_wtd} {
			ob_log::write DEBUG {$fn - wtd amount $cur_amount for cpm_id $cpm_id}
			set MTHDS($cpm_id,wtd_amount) $cur_amount
			set cur_total  [format %0.2f [expr {$cur_total + $cur_amount}]]
			set rem_amount [format %0.2f [expr {$rem_amount - $cur_amount}]]

			# Are we clearing the PMB on this pmt mthd?
			if {$cur_amount >= $MTHDS($cpm_id,pmb_value)} {
				set idx [lsearch $uncleared_pmbs $cpm_id]
				# Remove the pmt mthd from the list
				set uncleared_pmbs [lreplace $uncleared_pmbs $idx $idx]
			}

			if {$first_wtd_cpm_id == -1} {
				set first_wtd_cpm_id $cpm_id
			}
		}

		# Still money to withdraw?
		# If not, break out and show the cust what the wtd is going to
		# look like
		if {$rem_amount <= 0} {
			break
		}
	}


	#########
	# What has happened? Are we taking out the amount requested by cust?
	#########

	if {$cur_total == $wtd_amount} {
		ob_log::write INFO {$fn - wtd cust requested amount}
		set ret_code EXACT

	} elseif {$cur_total > $wtd_amount} {
		ob_log::write ERROR {$fn - cur_total is more than cust asked for \
		   ($cur_total > $wtd_amount)}
		return [list ERROR "INVALID_RETURN_AMOUNT"]

	} else {
		ob_log::write INFO {$fn - forced amount is less than cust asked for\
		   ($cur_total instead of $wtd_amount)}

		if {[llength $uncleared_pmbs] > 0} {
			if {$cur_total == 0} {
				ob_log::write INFO {$fn - cust cannot withdraw any of the\
				   requested amount}
				return [list NONE "MIN_WTD_BREACH"]

			} else {
				ob_log::write INFO {$fn - cust has uncleared pmbs (cpm_ids\
				   $uncleared_pmbs) - they cannot wtd the remaining amount}
				set ret_code LESS
			}

		} else {
			ob_log::write INFO {$fn - cust has no remaining pmbs to clear -\
			   they can choose where to wtd the remaining amount to}
			set ret_code CHOICE
		}
	}


	#########
	# Now work out the transaction limits for the cpms
	#########

	# No point in getting the limits for all the mthds if we can't use them
	# (unless we want to force loading of all for display purposes)
	if {$ret_code == "CHOICE" || $force_all} {
		set loop_list $MTHDS(ordered_cpm_ids)
	} else {
		set loop_list $MTHDS(mthds_with_pmb)
	}

	set mthd_list [list]
	foreach cpm_id $loop_list {
		# We already got the limits for some of the methods above.
		if {![info exists MTHDS($cpm_id,allow_txn)]} {
			set limits [pmt_util::get_cpm_limits $cpm_id WTD]

			set MTHDS($cpm_id,allow_txn) [lindex $limits 0]
			set MTHDS($cpm_id,min_wtd)   [lindex $limits 1]
			set MTHDS($cpm_id,max_wtd)   [lindex $limits 2]

			if {!$MTHDS($cpm_id,allow_txn) || $MTHDS($cpm_id,max_wtd) <= 0} {
				set MTHDS($cpm_id,allow_txn) 0
				set MTHDS($cpm_id,max_wtd)   0
			}

			set MTHDS($cpm_id,wtd_amount) 0
		}

		if {$ret_code != "CHOICE" || !$MTHDS($cpm_id,allow_txn) || \
		    $MTHDS($cpm_id,wtd_amount) >= $MTHDS($cpm_id,max_wtd)} {
			set MTHDS($cpm_id,can_wtd_more) 0
		} else {
			set MTHDS($cpm_id,can_wtd_more) 1
		}

		lappend mthd_list [list \
		            $cpm_id \
		            $MTHDS($cpm_id,pay_mthd) \
		            $MTHDS($cpm_id,wtd_amount) \
		            $MTHDS($cpm_id,can_wtd_more) \
		            $MTHDS($cpm_id,min_wtd) \
		            $MTHDS($cpm_id,max_wtd)]

	}

	set ret_val [list $ret_code $cur_total $rem_amount $mthd_list $tot_wtd_mthd]
	ob_log::write INFO {$fn - ret_val $ret_val}

	return $ret_val
}



#-------------------------------------------------------------------------------
# Checks whether the amounts being wtd to each pmt method provided conform to
# transaction limits and the PMB checks. This proc should be used when the
# customer is given a choice of where they want to wtd their money to.
#
#    cust_id
#    wtd_amount: total wtd amount
#    pmt_list: list of lists: <cpm_id> <wtd_amount>
#    cust_balance
#    channel
#
# Returns: <all_good> <error_code> <min_breach> <max_breach>
#
#    ret_code:
#
#        OK: if all the wtd are correct
#        ERROR: an unspecified error has ocurred
#        INSUFFICIENT_BALANCE: cust doesn't have enough money
#        INVALID_WTD_AMOUNT: wtd_amount is different to the sum of the amounts
#                        on each mthd
#        INVALID_CPM_ID: cpm_id passed in is not allowed for the wtd. The cpm_id
#                        is checked against the cpms returned by get_allowed_wtd
#        INVALID_RET_CODE: unknown returned code from get_allowed_wtd
#        FORCED_WTD_MISMATCH: the wtds passed in do not cover the wtds that
#                        get_allowed_wtd forces the customer to carry out
#        LIMIT_BREACH: The amount wtd to one or more pmt mthd is under the
#                        min_wtd or over the max_wtd for the mthd
#
#    if ret_code is LIMIT_BREACH then these two are returned as well:
#
#    min_breach: list of cpm_ids that are under the min_wtd
#    max_breach: list of cpm_ids that are over the max_wtd
#
#-------------------------------------------------------------------------------
proc payment_multi::validate_chosen_wtd {
	cust_id
	wtd_amount
	pmt_list
	{cust_balance ""}
	{channel I}} {

	set fn {payment_multi::validate_chosen_wtd}

	ob_log::write INFO {$fn - cust requested wtd: wtd_amount $wtd_amount\
	   pmt_list $pmt_list cust_balance $cust_balance channel $channel}

	set wtd_amount [format %0.2f $wtd_amount]

	if {$cust_balance == ""} {
		set cust_balance [pmt_util::get_balance $cust_id]
	}

	if {$wtd_amount > $cust_balance} {
		ob_log::write ERROR {$fn - attempting to wtd more than\
		   balance ($wtd_amount > $cust_balance)}
		return INSUFFICIENT_BALANCE
	} elseif {$wtd_amount == $cust_balance} {
		set full_balance 1
	} else {
		set full_balance 0
	}

	set chosen_cpms  [list]
	set chosen_amnts [list]
	set chosen_total 0

	foreach pmt_mthd $pmt_list {
		lappend chosen_cpms  [lindex $pmt_mthd 0]
		lappend chosen_amnts [format %0.2f [lindex $pmt_mthd 1]]
		set chosen_total [format %0.2f \
		                 [expr {$chosen_total + [lindex $pmt_mthd 1]}]]
	}

	if {$chosen_total != $wtd_amount} {
		ob_log::write ERROR {$fn - wtd_amount passed in is different to the\
		   total sum from the pmt_list ($pmt_list) ($chosen_total != $wtd_amount)}
		return INVALID_WTD_AMOUNT
	}

	# First get the allowed withdrawals
	set ret [get_allowed_wtd $cust_id $wtd_amount $cust_balance $channel]

	set ret_code [lindex $ret 0]

	if {$ret_code == "ERROR"} {
		ob_log::write ERROR {$fn - get_allowed_wtd returned an error}
		return ERROR
	} elseif {$ret_code == "NONE"} {
		ob_log::write ERROR {$fn - Cust not allowed to withdraw}
		return FORCED_WTD_MISMATCH
	}

	set forced_wtd_amount [lindex $ret 1]
	set remaining_amount  [lindex $ret 2]
	set wtd_mthds         [lindex $ret 3]

	set MTHDS(avail_wtd_mthds) [list]

	set forced_cpms  [list]
	foreach wtd_mthd $wtd_mthds {
		foreach {cpm_id pay_mthd amount can_wtd_more min_wtd max_wtd}\
		         $wtd_mthd {}

		lappend MTHDS(avail_wtd_mthds) $cpm_id

		set MTHDS($cpm_id,pay_mthd)     $pay_mthd
		set MTHDS($cpm_id,forced_amnt)  $amount
		set MTHDS($cpm_id,can_wtd_more) $can_wtd_more
		set MTHDS($cpm_id,min_wtd)      $min_wtd
		set MTHDS($cpm_id,max_wtd)      $max_wtd

		if {$amount > 0} {
			lappend forced_cpms  $cpm_id
		}
	}

	# Check that the chosen cpm_ids are available to the customer
	foreach chosen_cpm $chosen_cpms {
		if {[lsearch $MTHDS(avail_wtd_mthds) $chosen_cpm] == -1} {
			ob_log::write ERROR {$fn - cust attempting to use a cpm_id\
			   ($chosen_cpm) that isn't available to them}
			return INVALID_CPM_ID
		}
	}

	# The amounts passed in should be the same as the amounts
	# that we get back from get_allowed_wtd
	if {$ret_code == "EXACT" || $ret_code == "LESS"} {

		# Customer doesn't have a choice, so the num of wtd should be the same
		if {[llength $forced_cpms] != [llength $chosen_cpms]} {
			ob_log::write ERROR {$fn - Cust doesn't have a choice but num of\
			   forced wtds and chosen wtds does not match}
			return FORCED_WTD_MISMATCH
		}

		for {set forced_idx 0} {$forced_idx < [llength $forced_cpms]} \
		    {incr forced_idx} {

			set forced_cpm [lindex $forced_cpms $forced_idx]
			set chosen_idx [lsearch $chosen_cpms $forced_cpm]

			if {$chosen_idx == -1} {
				ob_log::write ERROR {$fn - cpm_id $forced_cpm missing from\
				   chosen wtds}
				return FORCED_WTD_MISMATCH
			}

			set chosen_amnt [lindex $chosen_amnts $chosen_idx]

			if {$MTHDS($forced_cpm,forced_amnt) != $chosen_amnt} {
				ob_log::write ERROR {$fn - cpm_id $forced_cpm forced amount\
				    different from chosen amnt\
				    ($MTHDS($forced_cpm,forced_amnt) != $chosen_amnt)}
				return FORCED_WTD_MISMATCH
			}
		}

		ob_log::write INFO {$fn - wtd allowed: $pmt_list}
		return OK

	} elseif {$ret_code == "CHOICE"} {
		# Have to make at least as many wtd as we are forced to
		if {[llength $chosen_cpms] < [llength $forced_cpms]} {
			ob_log::write ERROR {$fn - Cust attempting to make less wtds than\
			   there are forced wtds}
			return FORCED_WTD_MISMATCH
		}

		# Check that we are withdrawing at least as much as we have to to each
		# of the forced wtd methods
		for {set forced_idx 0} {$forced_idx < [llength $forced_cpms]} \
		    {incr forced_idx} {

			set forced_cpm [lindex $forced_cpms $forced_idx]
			set chosen_idx [lsearch $chosen_cpms $forced_cpm]

			if {$chosen_idx == -1} {
				ob_log::write ERROR {$fn - cpm_id $forced_cpm missing from \
				   chosen wtds}
				return FORCED_WTD_MISMATCH
			}

			set chosen_amnt [lindex $chosen_amnts $chosen_idx]

			if {$MTHDS($forced_cpm,forced_amnt) > $chosen_amnt} {
				ob_log::write ERROR {$fn - cpm_id $forced_cpm forced amount\
				   bigger than chosen amnt\
				   ($MTHDS($forced_cpm,forced_amnt) > $chosen_amnt)}
				return FORCED_WTD_MISMATCH
			}
		}

		set max_breach [list]
		set min_breach [list]
		set limit_breach 0

		# Check that we are not going under or over any of the limits and
		# that the wtd mthd allows wtds
		for {set chosen_idx 0} {$chosen_idx < [llength $chosen_cpms]} \
		    {incr chosen_idx} {

			set chosen_cpm  [lindex $chosen_cpms $chosen_idx]
			set chosen_amnt [lindex $chosen_amnts $chosen_idx]

			if {$chosen_amnt > $MTHDS($chosen_cpm,forced_amnt) && \
			    !$MTHDS($chosen_cpm,can_wtd_more)} {
				ob_log::write ERROR {$fn - cust trying to wtd more than the\
				   forced amnt to a mthd which won't allow it}
				lappend max_breach $chosen_cpm
				set limit_breach 1
			} elseif {$chosen_amnt > $MTHDS($chosen_cpm,max_wtd)} {
				ob_log::write INFO {$fn - chosen_amnt is above the max_wtd for\
				   cpm_id $chosen_cpm\
				   ($chosen_amnt > $MTHDS($chosen_cpm,max_wtd))}
				lappend max_breach $chosen_cpm
				set limit_breach 1
			} elseif {$chosen_amnt < $MTHDS($chosen_cpm,min_wtd)} {
				if {!$full_balance || \
					[lsearch -exact {UKSH IKSH} $MTHDS($chosen_cpm,pay_mthd)] != -1 \
				} {
					ob_log::write INFO {$fn - chosen_amnt is below the min_wtd\
					   for cpm_id $chosen_cpm\
					   ($chosen_amnt < $MTHDS($chosen_cpm,min_wtd))}
					lappend min_breach $chosen_cpm
					set limit_breach 1
				} else {
					ob_log::write INFO {$fn - chosen_amnt is below the min_wtd\
					   for cpm_id $chosen_cpm but cust is wtd full balance\
					   ($chosen_amnt < $MTHDS($chosen_cpm,min_wtd))}
				}
			}
		}

		if {$limit_breach} {
			return [list LIMIT_BREACH $min_breach $max_breach]
		}

		ob_log::write INFO {$fn - chosen wtd allowed: $pmt_list}
		return OK
	}

	ob_log::write ERROR {$fn - Invalid ret_code $ret_code from get_allowed_wtd}
	return INVALID_RET_CODE
}



#-------------------------------------------------------------------------------
# Returns tPmtChangeChk.max_pmb_remove
#-------------------------------------------------------------------------------
proc payment_multi::get_max_pmb_remove {} {

	if {[catch {
		set rs [ob_db::exec_qry payment_multi::get_max_pmb_remove ]} msg]} {

		ob_log::write ERROR {payment_multi::get_max_pmb_remove: \
		   Failed to exec qry payment_multi::get_max_pmb_remove}
		return 0
	}

	set max_pmb_remove [db_get_col $rs 0 max_pmb_remove]

	ob_db::rs_close $rs

	return $max_pmb_remove
}

