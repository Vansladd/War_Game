#
# $Id: kyc.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
#
# Know Your Customer
#
#
#
# Synopsis:
#     package require cust_kyc ?4.5?
#
# Procedures:
#

package provide cust_kyc 4.5


# Dependencies
#
package require util_log
package require util_db
package require util_exchange

namespace eval ob_kyc {
	variable INIT
	variable CFG
	set INIT 0
}

#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One time initialisation
#
proc ob_kyc::init {} {
	variable INIT
	variable CFG

	if {$INIT} { return }

	ob_log::write INFO {Initialising ob_kyc}

	foreach {c dflt} [list \
		valid_cvv2_resps      [list "ALL MATCH"] \
		get_limits_cache      600 \
		auth_pro_pass         1 \
		auth_pro_max_age_days 180 \
		auth_pro_chk          "AGE" \
		auth_pro_chk_type     "AUTH_PRO_DOB" \
		auth_pro_countries    [list UK] \
		cvv2_pass             1\
		exchange_cache        600\
	] {
		set CFG($c) [OT_CfgGet "KYC_[string toupper $c]" $dflt]
	}

	ob_kyc::_prep_qrys

	# Source the packages we may need
	if {$CFG(auth_pro_pass)} {
		package require ovs_auth_pro
		ob_ovs_auth_pro::init
	}

	set INIT 1

}



# Perpare queries
#
proc ob_kyc::_prep_qrys {} {

	variable CFG

	# get the current KYC limits
	ob_db::store_qry ob_kyc::get_kyc_limits {
		select
			k.group_id,
			k.cash_out_thresh,
			k.stake_thresh,
			k.ccy_code
		from
			tKYCXSysCfg    k,
			tXSysHostGrpLk l,
			tXSysHostGrp   g
		where
			g.type      = 'KYC'       and
			g.group_id  =  l.group_id and
			l.system_id =  ?          and
			l.group_id  = k.group_id
	} $CFG(get_limits_cache)

	# get a customers current KYC status
	ob_db::store_qry ob_kyc::get_kyc_status {
		select
			status
		from
			tKYCCust
		where
			cust_id = ?
	}

	# get total of customers xfers on a given KYC group
	ob_db::store_qry ob_kyc::get_xfers {
		select {+ORDERED}
			sum(s.xfers_out)          as total_out,
			sum(s.stakes - s.refunds) as total_stake
		from
			tAcct            a,
			tXSysHostGrpLk   l,
			tXSysXferSumm    s
		where
			a.cust_id    = ?                            and
			a.acct_id    = s.acct_id                    and
			s.start_date = extend(current, year to day) and
			s.period     = 'D'                          and
			s.system_id  = l.system_id                  and
			l.group_id   = ?
	}

	# has the customer made a payment on which we got a good CVV2/AVS response
	ob_db::store_qry ob_kyc::has_cvv2_avs [subst {
		select
			first 1 c.pmt_id
		from
			tPmtCC       c,
			tPmt         p,
			tCustPayMthd cpm
		where
			cpm.cust_id = ?         and
			cpm.cpm_id  = p.cpm_id  and
			p.pmt_id    = c.pmt_id  and
			c.cvv2_resp in ('[join $CFG(valid_cvv2_resps) "','"]')

	}]

	# set the kyc status of a customer
	ob_db::store_qry ob_kyc::set_kyc_status {
		insert into tKYCCust (
			status,
			cust_id
		) values (
			?,
			?
		)
	}

	# set the kyc status of a customer
	ob_db::store_qry ob_kyc::has_kyc_status {
		select
			1
		from
			tKYCCust
		where
			cust_id = ?
	}

	# update the kyc status of a customer
	ob_db::store_qry ob_kyc::update_kyc_status {
		update
			tKYCCust
		set
			status  = ?
		where
			cust_id = ?
	}


	# get a customers country code
	ob_db::store_qry ob_kyc::get_country_code {
		select
			country_code
		from
			tCustomer
		where
			cust_id = ?
	}

	# get a customers ccy code
	ob_db::store_qry ob_kyc::get_ccy_code {
		select
			ccy_code
		from
			tAcct
		where
			cust_id = ?
	}

	# does a system have p2p games on it?
	ob_db::store_qry ob_kyc::system_has_p2p {
		select
			has_p2p
		from
			tXSysHost
		where
			system_id = ?
	}

	# Add incident for sync with RightNow.
	ob_db::store_qry ob_kyc::add_incident_sync {
		execute procedure pXSysSyncInc
		(
			p_cust_id  = ?,
			p_subject  = ?,
			p_type     = ?,
			p_desc     = ?
		)
	}
}



#-------------------------------------------------------------------------------
# Utilities
#-------------------------------------------------------------------------------

# Check whether a customer has now exceeded their kyc limits
#
#    cust_id      - customer identifier
#    system_id    - system identifier
#    returns      - list
#                  1/0    - 1 if successful checked, 0 f not
#                  status - the customers kyc status following the check
#
proc ob_kyc::check_kyc_limits {
	cust_id
	system_id
} {

	set fn "ob_kyc::check_kyc_limits"

	# has the customer already passed kyc?
	foreach {success kyc_status} [get_kyc_status $cust_id] {}

	# failed to check status
	if {!$success} {
		ob_log::write ERROR {$fn Failed to get status}
		return [list 0 {}]
	} else {

		# if the customer already has a KYC status (be it passed or failed) no
		# point in continuing

		if {[lsearch [list "" "AR" "AF"] $kyc_status] < 0} {

			ob_log::write INFO {$fn KYC already checked. Status: $kyc_status}
			return [list 1 $kyc_status]
		}
	}

	# the customer hasn't been kyc'ed - need to check whether they've exceeded
	# any limits

	# load the limits
	foreach {success cash_out_thresh stake_thresh group_id} [_load_limits $system_id] {}

	if {!$success} {
		ob_log::write INFO {$fn Failed to obtain limits}
		return [list 0 $kyc_status]
	}

	if {$cash_out_thresh == "" && $stake_thresh == ""} {
		ob_log::write INFO {$fn system has no limits set}
		return [list 1 $kyc_status]
	}

	# get the total of customers transfers
	foreach {success total_out total_stake} [_load_xfers $cust_id $group_id] {}

	if {!$success} {
		ob_log::write INFO {$fn Failed to load trasnfers}
		return [list 0 $kyc_status]
	}

	ob_log::write INFO {$fn Total out: $total_out. Threshold: $cash_out_thresh}
	ob_log::write INFO {$fn Total stake: $total_stake. Threshold: $stake_thresh}

	# have we exceeded any of the limits?
	if {
		($cash_out_thresh == "" || $cash_out_thresh < $total_out) &&
		($stake_thresh   == "" || $stake_thresh   < $total_stake)
	} {
		ob_log::write INFO {$fn KYC limits exceeded. Doing KYC check}

		# we need to KYC this customer
		foreach {success kyc_status} [do_check $cust_id] {}

	}

	return [list 1 $kyc_status]

}



# Get a customer's kyc status
#
#    cust_id - customer identifier
#
#    returns - list
#                1/0    - 1 if successful, 0 if not
#                status - if successful, the kyc status
#
proc ob_kyc::get_kyc_status { cust_id } {

	if {[catch {set rs [ob_db::exec_qry ob_kyc::get_kyc_status $cust_id]} msg]} {

		ob_log::write ERROR {ob_kyc::get_kyc_status Failed to get status - $msg}
		return [list 0 {}]

	} else {

		if {![db_get_nrows $rs]} {
			ob_db::rs_close $rs
			return [list 1 {}]
		}

		set status [db_get_col $rs 0 status]
		ob_db::rs_close $rs
		return [list 1 $status]
	}

}



# Is the customer KYC blocked from using a system?
#
#    cust_id       - customer identifier
#    is_withdrawal - is it a withdrawal?
#    system_id     - system identifier
#
#    returns - list
#       status - OK if successful, error code if not
#       1/0 - if OK, whether customer is blocked or not
#
proc ob_kyc::cust_is_blocked { cust_id {is_withdrawal 1} {system_id ""} } {

	set fn "ob_kyc::cust_is_blocked"

	# if not a withdrawal the customer might not be blocked if its a none-p2p
	# exernal system they are accessing
	if {!$is_withdrawal && $system_id != ""} {

		if {[catch {
			set rs [ob_db::exec_qry ob_kyc::system_has_p2p $system_id]
		} msg]} {

			ob_log::write ERROR {$fn Failed to get system - $msg}
			return [list ERR_KYC_GET_SYSTEM {}]
		}

		if {![db_get_nrows $rs]} {
			ob_db::rs_close $rs
			return [list ERR_KYC_HOST_NOT_FOUND {}]
		}

		set has_p2p [db_get_col $rs 0 has_p2p]
		ob_db::rs_close $rs

		# if system doesn't have p2p games, not blocked
		if {$has_p2p == "N"} {
			return [list OK 0]
		}
	}

	#  Check the kyc status
	foreach {res kyc_status} [get_kyc_status $cust_id] {}

	if {!$res} {
		return [list ERR_KYC_GET_STATUS {}]
	}

	# are they restricted?
	if {$kyc_status == "R" || $kyc_status == "F"} {
		return [list OK 1]
	} else {
		return [list OK 0]
	}
}



#  Get a config value
#
#    cfg -the config item to get
#
#    Returns the value of the config item
#
proc ob_kyc::get_cfg { cfg } {

	variable CFG
	return $CFG($cfg)

}


# ------------------------------------------------------------------------------
#  Private Procedures
# ------------------------------------------------------------------------------

# Load the KYC limits for a given system's group/jurisdiction
#
#    system_id - system to load limits for
#
#    returns - list
#                1/0    - 1 if successful, 0 if not
#                then if successful:
#                 cash_out_thresh_sys - cash out threshold (in system currency)
#                 stake_thresh_sys   - stake threshold (in system currency}
#                 group_id           - id of group system belongs to
#
proc ob_kyc::_load_limits { system_id } {

	set fn "ob_kyc::_load_limits"

	if {[catch {set rs [ob_db::exec_qry ob_kyc::get_kyc_limits $system_id]} msg]} {
		ob_log::write ERROR {$fn Failed to get limits - $msg}
		return [list 0 {} {} {}]
	}

	set nrows [db_get_nrows $rs]

	if {!$nrows} {
		ob_log::write INFO {$fn System: $system_id has no limits set}
		ob_db::rs_close $rs
		return [list 1 {} {} {}]
	}

	# we should only have one row
	if {$nrows > 1} {
		ob_log::write ERROR {$fn System: $system_id has multiple limits}
		ob_db::rs_close $rs
		return [list 0 {} {} {}]
	}

	foreach col [list group_id cash_out_thresh stake_thresh ccy_code] {
		set $col [db_get_col $rs 0 $col]
	}

	ob_db::rs_close $rs

	if {$cash_out_thresh == "" && $stake_thresh == ""} {
		ob_log::write INFO {$fn System: $system_id has no limits set}
		ob_db::rs_close $rs
		return [list 1 {} {} {}]
	}

	# convert to system currency
	foreach {status cash_out_thresh_sys exch_rate} \
		[ob_exchange::to_sys_amount $ccy_code $cash_out_thresh] {}

	if {$status != "OK"} {
		ob_log::write ERROR \
			{$fn Can't convert currency, $cash_out_thresh $ccy_code}
		return [list 0 {} {} {}]
	}

	foreach {status stake_thresh_sys exch_rate} \
		[ob_exchange::to_sys_amount $ccy_code $stake_thresh] {}

	if {$status != "OK"} {
		ob_log::write ERROR \
			{$fn Can't convert currency, $stake_thresh $ccy_code}
		return [list 0 {} {} {}]
	}

	return [list 1 $cash_out_thresh_sys $stake_thresh_sys $group_id]

}



# Load the xfers a customer has made on a given group
#
#    cust_id  - customer identifier
#    group_id - id of group to load transfers for
#
#    returns - list
#                1/0    - 1 if successful, 0 if not
#                then if successful:
#                 total_out_sys    - total cash in (in system currency)
#                 total_stake_sys  - total stake (in system currency}
#
proc ob_kyc::_load_xfers { cust_id group_id } {

	set fn "ob_kyc::_load_xfers"

	# grab the total of a customers transfers
	if {[catch {set rs [ob_db::exec_qry ob_kyc::get_xfers $cust_id $group_id]} msg]} {
		ob_log::write ERROR {$fn Failed to get xfers - $msg}
		return [list 0 {} {}]
	}

	set total_out    [db_get_col $rs 0 total_out]
	set total_stake  [db_get_col $rs 0 total_stake]
	ob_db::rs_close $rs

	if {$total_out == ""} {
		ob_log::write INFO {$fn Customer yet to transfer funds}
		return [list 1 0.00 0.00]
	}

	# get customers currency
	foreach {res ccy_code} [_get_ccy_code $cust_id] {}

	if {!$res} {
		ob_log::write ERROR {$fn Failed to get currency code - $msg}
		return [list 0 {} {}]
	}

	# convert to system currency
	foreach {status total_out_sys exch_rate} \
		[ob_exchange::to_sys_amount $ccy_code $total_out] {}

	if {$status != "OK"} {
		ob_log::write ERROR {$fn Can't convert currency, $total_out $ccy_code}
		return [list 0 {} {}]
	}

	foreach {status total_stake_sys exch_rate} \
		[ob_exchange::to_sys_amount $ccy_code $total_stake] {}

	if {$status != "OK"} {
		ob_log::write ERROR {$fn Can't convert currency, $total_stake $ccy_code}
		return [list 0 {} {}]
	}

	return [list 1 $total_out_sys $total_stake]

}



# Carry out a KYC check
#
#    cust_id      - customer identifier
#
#    returns - list
#                1/0    - 1 if successful, 0 if not
#                then if successful:
#                 kyc_status  - the customers kyc status following the check
#                 is_av       - are we doing an AV check, if so this option adds
#                               AV prefixes to the statuses.
#
proc ob_kyc::do_check {cust_id {is_av 0}} {

	variable CFG

	set fn "ob_kyc::do_check"

	# If we are comming from AV then we need to set different non functional
	# flags for failure, beacuse we don't want it to stop them from playing
	# until they exceed a certian limit in which
	set av_prefix {}
	if {$is_av} {
		set av_prefix {A}
	}

	# default status is restricted
	set kyc_status "${av_prefix}R"

	# can we use authenticate pro to pass?
	if {$CFG(auth_pro_pass)} {

		foreach {res country_code} [_get_country_code $cust_id] {}

		if {!$res} {
			ob_log::write ERROR {$fn Failed to get country code}
			set kyc_status "${av_prefix}F"

		} elseif {[lsearch $CFG(auth_pro_countries) $country_code] != -1} {

			# get details of customer check

			# first see if we have an existing up to date athenticate pro check
			# we can use
			foreach {succ high_risk_count primary_count secondary_count} \
				[_get_auth_pro_check $cust_id] {}

			if {!$succ} {
				set kyc_status "${av_prefix}F"
			} else {

				if {$high_risk_count == 0} {

					if {$primary_count > 1} {
						set kyc_status "A"
					} elseif {$primary_count == 1 && $secondary_count > 0} {
						set kyc_status "A"
					} elseif {$primary_count > 0 || $secondary_count > 1} {

						# does the customer have a valid card response?
						if {[catch {set rs [ob_db::exec_qry ob_kyc::has_cvv2_avs $cust_id]} msg]} {
							ob_log::write ERROR {$fn Failed to check cvs status - $msg}
							set kyc_status "${av_prefix}F"
						} else {
							set nrows [db_get_nrows $rs]
							ob_db::rs_close $rs
							if {$nrows > 0} {
								ob_log::write INFO {$fn KYC pass on cvv2 response}
								set kyc_status "C"
							}
						}
					}
				}
			}
		}
	}

	ob_log::write INFO {$fn Setting kyc_status to: $kyc_status}

	# set the customers status
	if {![ob_kyc::set_kyc_status $cust_id $kyc_status]} {
		return [list 0 {}]
	}

	if {!$is_av} {
		# Add incident for sync with RightNow.
		if {[OT_CfgGet RIGHT_NOW_ENABLE 0]} {
			set rn_action_flag [list ${av_prefix}R ${av_prefix}F]
			if {[lsearch $rn_action_flag $kyc_status] > -1} {
				set subject [OT_CfgGet RIGHT_NOW_KYC_SUBJECT "KYC"]
				set desc    [OT_CfgGet RIGHT_NOW_KYC_DESC ""]

				if {[catch {
					ob_db::exec_qry ob_kyc::add_incident_sync -inc-type \
								$cust_id   STRING \
								$subject   STRING \
								"KYC"      STRING \
								$desc      TEXT
				} msg]} {
					ob_log::write ERROR {$fn Failed to exec ob_kyc::add_incident_sync: $msg}
				}
			}
		}
	}

	return [list 1 $kyc_status]

}



proc ob_kyc::set_kyc_status {cust_id status} {
	set fn {ob_kyc::set_kyc_status}

	#Does KYC status exist?
	if {[catch {set rs [ob_db::exec_qry ob_kyc::has_kyc_status $cust_id]} msg]} {
		ob_log::write ERROR {$fn ob_kyc:has_kyc_status failed - $msg}
		return 0
	}

	set has_kyc_status 0
	if {[db_get_nrows $rs]} {
		set has_kyc_status 1
	}


	if {$has_kyc_status} {
		if {[catch {ob_db::exec_qry ob_kyc::update_kyc_status $status $cust_id} msg]} {
			ob_log::write ERROR {$fn Failed to update status - $msg}
			return 0
		}
	} else {
		if {[catch {ob_db::exec_qry ob_kyc::set_kyc_status $status $cust_id} msg]} {
			ob_log::write ERROR {$fn Failed to update status - $msg}
			return 0
		}
	}

	return 1
}



# Get details of an auth_pro check
#
#  cust_id      - customer identifier
#
#  returns - list
#   1/0    - 1 if successful obtained, 0 if not
#   then if successful:
#     number_hr_policy_rules                  - number high risk rules
#     number_primary_sources                  - number primary sources
#     number_secondary_id_and_address_sources - number secondary sources
#
#
proc ob_kyc::_get_auth_pro_check { cust_id} {

	variable CFG

	set fn {ob_kyc::_get_auth_pro_check}

	# first see if we have an existing up to date athenticate pro check
	# we can use
	foreach {succ cr_date checks} [ob_ovs_auth_pro::get_cust_check \
		$cust_id $CFG(auth_pro_chk_type)] {}

	if {!$succ} {
		return [list 0 {} {} {}]
	}

	set chk_valid 0

	if {$cr_date != ""} {
		set max_secs \
			[expr {[clock seconds] - ($CFG(auth_pro_max_age_days) * 86400)}]

		# is the check recent enough to be user?
		if {$max_secs < [clock scan $cr_date]} {
			set chk_valid 1
		}
	}

	# do we have a usuable check - if not, make a new call to
	# authenticate pro and use the result of that
	if {!$chk_valid} {
		set result [verification_check::send_cust_details_to_server \
			$cust_id $CFG(auth_pro_chk) {} 0]

		if {!$result} {
			return [list 0 {} {} {}]
		}

		# load result of latest check
		foreach {succ cr_date checks} [ob_ovs_auth_pro::get_cust_check \
			$cust_id $CFG(auth_pro_chk_type)] {}

		if {!$succ} {
			return [list 0 {} {} {}]
		}
	}

	array set CHECK $checks

	# check we have the expected information in the check
	if {
		![info exists CHECK(number_hr_policy_rules)] ||
		![info exists CHECK(number_primary_sources)] ||
		![info exists CHECK(number_secondary_id_and_address_sources)]
	} {
		ob_log::write INFO {$fn data missing from check. Marking as failed}
		return [list 0 {} {} {}]
	}

	return [list \
		1 \
		$CHECK(number_hr_policy_rules)\
		$CHECK(number_primary_sources)\
		$CHECK(number_secondary_id_and_address_sources)]

}



# Get a customers country code
#
#    cust_id - customer identifier
#
#    returns - list
#                1/0          - 1 if successful, 0 if not
#                country_code - if successful, the country code
#
proc ob_kyc::_get_country_code { cust_id } {

	if {[catch {
		set rs [ob_db::exec_qry ob_kyc::get_country_code $cust_id]
	} msg]} {

		ob_log::write ERROR \
			{ob_kyc::_get_country_code error getting country code - $msg}
		return [list 0 {}]

	} else {

		if {![db_get_nrows $rs]} {
			ob_log::write ERROR \
				{ob_kyc::_get_country_code failed to find country code - $msg}
			ob_db::rs_close $rs
			return [list 0 {}]
		}

		set country_code [db_get_col $rs 0 country_code]
		ob_db::rs_close $rs
		return [list 1 $country_code]
	}
}



# Get a customers currency code
#
#    cust_id - customer identifier
#
#    returns - list
#                1/0        - 1 if successful, 0 if not
#                ccy_code   - if successful, the ccy code
#
proc ob_kyc::_get_ccy_code { cust_id } {

	if {[catch {
		set rs [ob_db::exec_qry ob_kyc::get_ccy_code $cust_id]
	} msg]} {

		ob_log::write ERROR \
			{ob_kyc::_get_ccy_code error getting ccy code - $msg}
		return [list 0 {}]

	} else {

		if {[db_get_nrows $rs] != 1} {
			ob_log::write ERROR \
				{ob_kyc::_get_ccy_code failed to find ccy code - $msg}
			ob_db::rs_close $rs
			return [list 0 {}]
		}

		set ccy_code [db_get_col $rs 0 ccy_code]
		ob_db::rs_close $rs
		return [list 1 $ccy_code]
	}
}
