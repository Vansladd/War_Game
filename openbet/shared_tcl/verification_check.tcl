# $Id: verification_check.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==========================================================================================
#
# Copyright (c) Orbis Technology 2000. All rights reserved.
#
# verification_check.tcl
#
# Provides a generic interface to the OVS server through Datacash.
# There are two implementations:
# proc do_verification_via_queue - Adds the verification request in a queue which is then
# processed by a cron_job.
# proc do_verification_via_server - Makes the verification request directly to the OVS
# server via datacash.
#
# A number of OVS configs are used in both implementations. They all start with
# FUNC_OVS_... see below:
#
# FUNC_OVS_USE_SERVER - sends verification request directly to the server, if set to 1
# FUNC_OVS_USE_QUEUE - sends verification request to the queue, if set to 1
# FUNC_OVS_CARD_VRF_PRFL_CODE - the name of the verification profile code for CARD checking
# FUNC_OVS_AGE_VRF_PRFL_CODE - the name of the verification profile code for AGE checking
# FUNC_OVS_CHK_ON_CHANGE_OF_CARD - set to 1 if OVS checking is to be done everytime the
#									the customer changes their credit card
# FUNC_OVS_CHK_DOB_EXISTS - set to 1 if DOB checking is required. Use only if the customer
#							does not have a DOB in the database
# FUNC_OVS_DO_AGE_CHECK - set to 1 if AGE checking is to be done. This will be the
#						  "Residency and DOB" check.
# FUNC_OVS_DO_CARD_CHECK - set to 1 if Credit Card checking is to be done.
# FUNC_OVS_CHK_ON_NTLR_PMT - set to 1 if checking is required when making a Neteller payment
# FUNC_OVS_DISALLOW_WTD - set to 1 if withdrawals are not allowed until customer has been
#						  verified
# FUNC_OVS_CHK_ON_FIRST_DEP_ONLY - set to 1 if verification check is to be done on first
#									deposit only.
# FUNC_OVS_DISPLAY_VRF_MENU - set to 1 to display the OVS verification menu on the left nav
#                             (admin screens).
# FUNC_OVS_CHK_CARD_TYPE - set to 1 to check the credit card type.
# FUNC_OVS_MANUAL_OVERRIDE - set to 1 if you want to use the status from
#                            from tVrfCustStatus to decide if the ovs check needs to be done.
# FUNC_OVS_CHK_ON_C2P_PMT - set to 1 if checking is required when making a Click2Pay payment.
#
# =============================================================================================

#
# Dependancies
#
package require util_log
package require util_db

namespace eval verification_check {

namespace export verification_init
namespace export chk_card_type
namespace export chk_cust_dob
namespace export do_cust_age_verify
namespace export bind_ovs_queue_details
namespace export check_cust_can_wtd
namespace export check_cust_prev_pmt
namespace export check_cust_prev_pmt_on_card
namespace export do_verification_via_queue
namespace export do_verification_via_server
namespace export chk_cust_dob_exists

variable INIT 0

proc verification_init {} {

	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init
	ob_db::init
	prep_qrys

	set INIT 1
}


proc prep_qrys {} {

	ob_db::store_qry verification_check::get_card_scheme_type {
		select
			cs.scheme
		from
			tcardscheme cs
		where
			? >= cs.bin_lo and
			? <= cs.bin_hi
	}

	ob_db::store_qry verification_check::get_cust_prev_pmt {
		select
			1
		from
				tAcct            a,
				tCustStats       s,
				tCustStatsAction c
		where
				a.cust_id         = ?
				and a.acct_id     = s.acct_id
				and s.action_id   = c.action_id
				and c.action_name = 'DEPOSIT'
		union
		select
			1
		from
				tAcct a,
				tPmt p
		where
				a.cust_id = ?
				and a.acct_id = p.acct_id

	}

	ob_db::store_qry verification_check::get_cust_dob {
			select
				cr.dob
			from
				tcustomerreg cr
			where
				cr.cust_id = ?
	}

	if {[OT_CfgGet FUNC_OVS_DISALLOW_WTD 0]} {
		ob_db::store_qry verification_check::upd_cust_no_wtd {
			execute procedure pUpdCustNoWtd
			(
				p_cust_id = ?
			)
		}
	}


	ob_db::store_qry verification_check::get_cust_reg_details {
		select
			country_code,
			source
		from
			tCustomer
		where
			cust_id = ?
	}


	ob_db::store_qry verification_check::get_customer_details {
		select
			r.fname         as forename,
			r.lname         as surname,
			r.gender,
			r.dob,
			r.addr_street_1 as building_no,
			r.addr_street_2 as street,
			r.addr_street_3 as sub_street,
			r.addr_street_4 as district,
			r.addr_city     as town,
			r.addr_postcode as postcode,
			r.telephone     as telephone,
			c.country_code  as country
		from
			tCustomerReg r,
			tCustomer c
		where
			c.cust_id = ?
			and c.cust_id = r.cust_id
	}

	ob_db::store_qry verification_check::get_prfl_defn_id {
		select
			vrf_prfl_def_id as profile_def_id
		from
			tVrfPrflDef
		where
			vrf_prfl_code = ?
	}


	ob_db::store_qry verification_check::get_cc_scheme_details {
		select
			si.scheme as scheme_code,
			si.scheme_name
		from
			tcardschemeinfo si,
			tcardscheme s
		where
			s.scheme = si.scheme and
			s.bin_lo <= ? and
			s.bin_hi >= ?
	}

	# Update tCustomerFlag Verification status, either Y or N
	  ob_db::store_qry verification_check::upd_cust_vrf_status [subst {
		execute procedure pUpdVrfCustStatus
		(
			p_adminuser     = ?,
			p_cust_id       = ?,
			p_status        = ?,
			p_reason_code   = ?,
			p_vrf_prfl_code = ?,
			p_prfl_model_id = ?,
			p_transactional = ?
		)
	}]

	# Get the verification action (Suspend,do Nothing,Alert admin user,Pending from OVS)
	  ob_db::store_qry verification_check::get_cust_ovs_action {
	  	select
			flag_value as action
		from
			tcustomerflag
		where
			cust_id = ? and
			flag_name = ?
	  }

	  # check if customer dob exists in the database
	  ob_db::store_qry verification_check::check_dob_exists {
		select
			dob
		from
			tcustomerreg
		where
			cust_id = ? and
			dob is not null
	  }

	ob_db::store_qry verification_check::check_pmt_map {
		select
			pm.vrf_prfl_model_id,
			pm.action,
			pm.status,
			pm.pmt_sort
		from
			tVrfPrflModel pm,
			tVrfPrflDef   pd
		where
			    pd.vrf_prfl_code   = ?
			and pm.pay_mthd        = ?
			and pm.country_code    = ?
			and pm.vrf_prfl_def_id = pd.vrf_prfl_def_id
	}

	ob_db::store_qry verification_check::check_pmt_map_cc {
		select
			pm.vrf_prfl_model_id,
			pm.action,
			pm.status,
			pm.pmt_sort
		from
			tVrfPrflModel   pm,
			tVrfPrflDef     pd,
			tCardSchemeInfo csi
		where
			    pd.vrf_prfl_code   = ?
			and pm.pay_mthd        = ?
			and pm.country_code    = ?
			and pm.vrf_prfl_def_id = pd.vrf_prfl_def_id
			and csi.scheme         = ?
			and csi.type           = pm.type
	}

	ob_db::store_qry verification_check::cc_upd_pay_mthd {
		update
			tCustPayMthd
		set
			status_wtd = ?
		where
			cust_id  = ?
	}

	# Insert Email for Queuing
	ob_db::store_qry verification_check::queue_email {
		execute procedure pInsEmailQueue(
			p_email_type = ?,
			p_cust_id = ?
			)
	}

	# Get the cust_id for a given acct_id.
	ob_db::store_qry verification_check::get_ovs_cust_details {
		select
			c.cust_id,
			c.country_code
		from
			tAcct     a,
			tCustomer c
		where
			    c.cust_id = a.cust_id
			and a.acct_id = ?
	}

	# Get the cust_id for a given acct_id.
	ob_db::store_qry verification_check::get_operation_mode {
		select
			ovs_mode
		from
			tcontrol
	}

	ob_db::store_qry ob_ovs::get_ovs_details [subst {
		select
			s.status
		from
			tVrfCustStatus s
		where
			    s.cust_id       = ?
			and s.vrf_prfl_code = ?
	}]

	ob_db::store_qry ob_ovs::get_ovs_status_grace {
		select
			s.status,
			CASE WHEN
				s.expiry_date > CURRENT
			THEN
				1
			ELSE
				0
			END as is_grace,
			s.expiry_date
		from
			tVrfCustStatus s
		where
			s.cust_id        = ?
		and     s.vrf_prfl_code  = ?
	}


	ob_db::store_qry ob_ovs::has_prev_ovs_check {
		select
			count(*)
		from
			tVrfCustStatus
		where
			    cust_id       = ?
			and vrf_prfl_code = ?
	}
}


# check if card is solo or electron, or switch and customer age <21
proc chk_card_type {cust_id} {

	card_util::cd_get_active $cust_id CARD_DETAILS
	if {$CARD_DETAILS(card_available) == "Y"} {
		set card_bin $CARD_DETAILS(card_bin)
	} else {
		set card_bin ""
	}

	if [catch {set rs [ob_db::exec_qry verification_check::get_card_scheme_type $card_bin $card_bin]} msg] {
		ob::log::write ERROR "get_card_scheme_type:failed to retrieve card type: $msg"
		return 1
	}
	set card_type [db_get_col $rs 0 scheme]
	ob_db::rs_close $rs

	if {$card_type == "SOLO" || $card_type == "ELTN" || $card_type == "VE" || ($card_type == "SWCH" && [chk_cust_dob $cust_id "21"])} {
		return 1
	} else {
		return 0
	}
}

# check if customer age is less than the passed in age
proc chk_cust_dob {cust_id age} {
	if [catch {set rs [ob_db::exec_qry verification_check::get_cust_dob $cust_id]} msg] {
		ob::log::write ERROR "get_cust_dob:failed to retrieve cust dob: $msg"
		return 0
	}

	set cust_dob [db_get_col $rs 0 dob]
	set dob_args [split $cust_dob -]
	set dob_year [lindex $dob_args 0]
	set dob_month [lindex $dob_args 1]
	set dob_day [lindex $dob_args 2]

	set dob_month [string trimleft $dob_month 0]
	set dob_day   [string trimleft $dob_day 0]

	# get current day,month,year
	set secs [clock seconds]
	set dt   [clock format $secs -format "%Y-%m-%d"]

	foreach {y m d} [split $dt -] {
		set curr_year  [string trimleft $y 0]
		set curr_month [string trimleft $m 0]
		set curr_day   [string trimleft $d 0]
	}

	set year_diff [expr $curr_year - $dob_year]

	ob_db::rs_close $rs

	if {($year_diff < $age) ||
		(($year_diff == $age) && ($curr_month < $dob_month)) ||
		(($year_diff == $age) && ($curr_month == $dob_month) && ($curr_day < $dob_day))
	} {
		return 1
	} else {
		return 0
	}
}


# Check if customer can withdraw
proc check_cust_can_wtd {cust_id check_type} {

	set ovs_action [get_ovs_status $cust_id $check_type]
	if {$ovs_action == "S"} {
		return [list 0 "Customer age cannot be verified suspending customer" ACCT_WTH_NOT_AGE_VRF]
	}

	return [list 1]
}

# Binds ovs queue details into a list
proc bind_ovs_queue_details {cust_id check_type} {

	set vrf_prfl_code [OT_CfgGet FUNC_OVS_${check_type}_VRF_PRFL_CODE ""]

	if [catch {set rs_def_id [ob_db::exec_qry verification_check::get_prfl_defn_id $vrf_prfl_code]} msg] {
				ob::log::write ERROR "get_prfl_defn_id: failed to get age vrf prfl def id: $msg"
	}
	set vrf_prfl_def_id [db_get_col $rs_def_id 0 profile_def_id]
	ob_db::rs_close $rs_def_id

	# get some customer registration details required by ovs
	if [catch {set rs_reg_details [ob_db::exec_qry verification_check::get_cust_reg_details $cust_id]} msg] {
		ob::log::write ERROR "get_cust_reg_details: failed to get customer reg details: $msg"
	}
	set cust_cntry_code [db_get_col $rs_reg_details 0 country_code]
	set cust_channel [db_get_col $rs_reg_details 0 source]
	ob_db::rs_close $rs_reg_details

	return [list $cust_id $vrf_prfl_def_id $vrf_prfl_code $cust_cntry_code $cust_channel $check_type]
}


# Check if customer has ever made any previous payments on the card they are making a payment with
proc check_cust_prev_pmt_on_card {cust_id {cpm_id 0}} {

	card_util::cd_get_active $cust_id CARD_DETAILS $cpm_id
	if {$CARD_DETAILS($cpm_id,card_available) == "Y"} {
		set prev_pmt_made [card_util::cd_check_prev_pmt $cust_id $CARD_DETAILS($cpm_id,enc_card_no)]
	} else {
		set prev_pmt_made 0
	}

	return $prev_pmt_made
}


# check if customer has ever made any previous payments
proc check_cust_prev_pmt {cust_id} {

	return [card_util::cd_check_if_cust_made_prev_pmt $cust_id]

}

#check if customer has made prev payment
proc check_cust_all_prev_pmt {cust_id} {

	if [catch {set rs [ob_db::exec_qry verification_check::get_cust_prev_pmt $cust_id $cust_id]} msg] {
		ob::log::write ERROR "check_cust_all_prev_pmt: failed to get customer payments details: $msg"
	} else {
		set nrows [db_get_nrows $rs]
		ob_db::rs_close $rs
		if {$nrows < 1 } {
			return 0
		}
	}
	return 1


}


# Check if customer's DOB exists in the database
proc chk_cust_dob_exists {cust_id} {
	# check if customer has dob in database as this is required for ovs
	if [catch {set rs [ob_db::exec_qry verification_check::check_dob_exists $cust_id]} msg] {
		ob::log::write ERROR {unable to retreive customer dob for ovs check $msg}
		return [list 0 "Unable to retrieve customer DOB" ACCT_NO_OVS_DOB_ERROR]
	}
	set nrows [db_get_nrows $rs]
	ob_db::rs_close $rs
	if {$nrows == 0} {
		# customer does not have a dob in the database, so we need to obtain it.
		tpSetVar OVSGetCustDOB 1
		return [list 0 "Customer does not have DOB in database" ACCT_NO_OVS_DOB]
	} else {
		return [list 1]
	}
}


proc update_vrf_status {
	cust_id
	status
	reason_code
	check_type
	prfl_model_id
	transactional
} {

	set succ 0
	if {[catch {set rs [ob_db::exec_qry verification_check::upd_cust_vrf_status \
											[OT_CfgGet OVS_ADMIN_USER] \
											$cust_id \
											$status \
											$reason_code \
											[OT_CfgGet FUNC_OVS_${check_type}_VRF_PRFL_CODE ""] \
											$prfl_model_id \
											$transactional
	]} msg]} {
		ob::log::write ERROR "verification_check::upd_cust_vrf_status - failed to update cust verf status: $msg"
	} else {
		ob::log::write INFO "verification_check::upd_cust_vrf_status - successfully updated customer verf status"
		ob_db::rs_close $rs
		set succ 1
	}

	return $succ
}

# ===========================================================================
# Adds customer to OVS verification queue which is then processed separately.
# Takes 1 parameter: a list containing the cust_id, verification profile definition id, verification profile code,
# country code of customer, channel customer registered from, and the check type which can be AGE, CARD, DRIVER, etc.
#
# ===========================================================================
proc do_verification_via_queue {queue_details type prfl_model_id {in_trans "N"}} {

	set cust_id         [lindex $queue_details 0]
	set vrf_prfl_def_id [lindex $queue_details 1]
	set vrf_prfl_code   [lindex $queue_details 2]
	set cust_cntry_code [lindex $queue_details 3]
	set cust_channel    [lindex $queue_details 4]
	set check_type      [lindex $queue_details 5]

	# Add customer to verification queue
	ob_ovs::queue_customer $cust_id $vrf_prfl_def_id $vrf_prfl_code $prfl_model_id $cust_cntry_code $cust_channel

	# Update status of wtd_auth column to N in tCustPayMthd so they can't withdraw
	if {[OT_CfgGet FUNC_OVS_DISALLOW_WTD 0]} {
		if [catch {set rs [ob_db::exec_qry verification_check::upd_cust_no_wtd $cust_id]} msg] {
			ob::log::write ERROR "upd_cust_no_wtd:failed to update customer withdrawal status: $msg"
		}
	}

	set transactional [expr {$in_trans == "Y" ? "N" : "Y"}]

	# Adds verification status set to No, and this will be updated once the
	# response is received from OVS

	if {[catch {update_vrf_status $cust_id [OT_CfgGet OVS_FAIL_STATUS "N"] "" "AGE" $prfl_model_id $transactional} msg]} {
		ob::log::write ERROR "upd_cust_vrf_status:failed to update customer verification status: $msg"
		return 0
	} else {
		return 1
	}
}


# ===========================================================================
# Sends Verification request directly to OVS
# We need to verify their personal details through OVS before continuing with the deposit.
# Takes 2 parameters - cust_id, check_type
# The check_type is what we are verifying, i.e. customers age (AGE) or their card details
# (CARD), etc
# ===========================================================================
proc do_verification_via_server {cust_id check_type {profile_model_id {}} args} {

	# Update Age Verification status,
	if {![update_vrf_status $cust_id [OT_CfgGet OVS_FAIL_STATUS "N"] "" "AGE" $profile_model_id {N}]} {
		ob::log::write ERROR {failed to update age verification status $msg}
		return [list 0 "Failed to update age verification status" ACCT_NO_OVS_ERROR]
	}

	# customer has dob in the database so make OVS request
	set ovs_result [eval [list send_cust_details_to_server $cust_id $check_type $profile_model_id] $args]
	ob::log::write INFO {verification_check::do_verification_via_server ovs_result = $ovs_result}

	if {$ovs_result} {
		set ovs_action [get_ovs_status $cust_id $check_type]
		switch -- $ovs_action {
			P {
				return [list 1]
			}
			S {
				return [list 0 "Customer age cannot be verified suspending customer" ACCT_WTH_NOT_AGE_VRF]
			}
			default {
				return [list 1]
			}
		}
	} else {
		return [list 0 "Error with OVS" ACCT_NO_OVS_ERROR]
	}
}


# Sends verification request to Datacash
# Takes 2 parameters - cust_id and check_type
# The check_type is what we are verifying, i.e. customers age (AGE) or their card details
# upd_status - option to disable chagne to customer account status as part of check
proc send_cust_details_to_server {cust_id check_type {profile_model_id {}} {upd_status 1} args} {

	catch {unset PROFILE}
	array set PROFILE [ob_ovs::get_empty]
	set card_no    ""
	set expiry_date ""

	set switches [list -card_no -expiry_date]
	foreach {switch value} $args {
		if {[lsearch $switches $switch] == -1} {
			error "bad switch \"$switch\": must be -card_no, or -expiry_date"
		}
		set name [string trimleft $switch -]
		set $name $value
	}

	set callback   [OT_CfgGet OVS_QUEUE_CALLBACK ""]
	set channel    [OT_CfgGet OVS_QUEUE_CHANNEL ""]
	set vrf_prfl_code [OT_CfgGet FUNC_OVS_${check_type}_VRF_PRFL_CODE ""]

	if [catch {set res [ob_db::exec_qry verification_check::get_prfl_defn_id $vrf_prfl_code]} msg] {
		ob_log::write CRITICAL {VERIFICATION_CHECK: failed to get age verification profile id: $msg}
		return 0
    }

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		ob_log::write CRITICAL {VERIFICATION_CHECK: failed to get age verification profile id. 1 row was not returned. Query returned $nrows}
		ob_db::rs_close $res
		return 0
	} else {
		set prfl_defn_id [db_get_col $res 0 profile_def_id]
	}
	set PROFILE(cust_id) $cust_id
	set PROFILE(profile_def_id) $prfl_defn_id

	if {[catch {
		set res2 [ob_db::exec_qry verification_check::get_customer_details $PROFILE(cust_id)]
	} msg]} {
		ob_log::write ERROR {VERIFICATION_CHECK: Failed to run get_customer_details: $msg}
		return 0
	}

	if {[db_get_nrows $res2] != 1} {
		ob_db::rs_close $res2
		ob_db::rs_close $res
		ob_log::write ERROR \
			{VERIFICATION_CHECK: get_customer_details returned wrong number of rows}
		return 0
	}

	foreach col [list \
		building_no \
		street \
		sub_street \
		district \
		town \
		postcode] {
		set PROFILE(address1,$col) [db_get_col $res2 0 $col]
	}

	# Also store the complete first two lines of the address, used for verification search
	set PROFILE(address1,addr_street_1) $PROFILE(address1,building_no)
	set PROFILE(address1,addr_street_2) $PROFILE(address1,street)

	set addr_1 $PROFILE(address1,building_no)
	set split_addr_1 $addr_1
	set building_no [lindex $split_addr_1 0]
	set addr_length [llength $split_addr_1]
	set addr_1 ""
	for {set i 1} {$i < $addr_length} {incr i} {
		append addr_1 [lindex $split_addr_1 $i]
		append addr_1 " "
	}


	# If the building number does not contain a number, ignore it and use the whole address line
	if {[regexp {[\d,]} $building_no match] == 1} {
		set PROFILE(address1,building_no) $building_no
		set PROFILE(address1,sub_street) $PROFILE(address1,street)
		set PROFILE(address1,street) $addr_1
	}

	foreach col [list \
		forename \
		surname \
		gender \
		country] {
		set PROFILE($col) [db_get_col $res2 0 $col]
	}

	# Gender must be in long format.
	#
	switch $PROFILE(gender) {
		M {
			set PROFILE(gender) "Male"
		}
		F {
			set PROFILE(gender) "Female"
		}
	}

	foreach [list \
		PROFILE(dob_year) \
		PROFILE(dob_month) \
		PROFILE(dob_day)] [split [db_get_col $res2 0 dob] "-"] {
		break
	}

	set PROFILE(telephone,number) [db_get_col $res2 0 telephone]
	set PROFILE(address_count) 1

	ob_db::rs_close $res2

	if {$check_type == "CARD" || $check_type == "SCHEME"} {
		# card details
		if {$card_no == ""} {
			set card_no  [reqGetArg card_no]
		}
		if {$expiry_date == ""} {
			set expiry_date [reqGetArg expiry_date]
		}
		foreach v {card_no expiry_date} {
			regsub -all " " [set $v] "" $v
		}
		set card_bin [string range $card_no 0 5]

		if {[catch {
			set res3 [ob_db::exec_qry verification_check::get_cc_scheme_details $card_bin $card_bin]
		} msg]} {
			ob_log::write ERROR {VERIFICATION_CHECK: Failed to run get_cc_scheme_details: $msg}
			return 0
		}

		if {[db_get_nrows $res3] > 0} {
			set scheme_code [db_get_col $res3 0 scheme_code]
			set scheme_name [string toupper [db_get_col $res3 0 scheme_name]]

			if {$scheme_code == "VC" || $scheme_code == "VD"} {
				set scheme_name "VISA"
			} elseif {$scheme_code == "AMEX"} {
				set scheme_name "AMEX"
			} elseif {$scheme_code == "DINE"} {
				set scheme_name "DINERS"
			}

			set expiry_date_split [split $expiry_date /]
			set expiry_month [lindex $expiry_date_split 0]
			set expiry_year [lindex $expiry_date_split 1]
			set expiry_date $expiry_month$expiry_year

			set PROFILE(card,type) $scheme_name
			set PROFILE(card,number) $card_no
			set PROFILE(card,expiry_date) $expiry_date
			set PROFILE(card,issue_number) [reqGetArg issue_no]
			set PROFILE(card,verification_code) [reqGetArg cvv2]
			set PROFILE(scheme,type) $scheme_code
		}
	}
	set PROFILE(callback)      $callback
	set PROFILE(channel)       $channel
	set PROFILE(prfl_model_id) $profile_model_id
	set PROFILE(upd_status)    $upd_status

	foreach path [lsort [array names PROFILE]] {
		ob_log::write DEV {VERIFICATION_CHECK: PROFILE($path) = $PROFILE($path)}
	}

	if {[catch {
		foreach {result data} [ob_ovs::run_profile [array get PROFILE]] {break}
	} msg]} {
		ob_db::rs_close $res
		ob_log::write ERROR {OVS: Critical error running verification: $msg}

		return 0
	}

	switch -- $result {
		OB_OK {
			return 1
		}
		OB_NO_CHK_REQ {
			# No check required for a customer from this country.
			return 1
		}
		OB_ERR_OVS_PRFL_INVALID {
			# No profile definition defined, we don't want to error here, else we wouldn't
			# be able to turn anything off!!
			return 1
		}
		default {
			return 0
		}
	}
}



#
# desc    : does a verification check.
# params  : pay_sort        : (W)ithdrawal/(D)eposit
#           pay_mthd        : CC NTLR WU etc...
#           acct_id         : -
#           card_no (opt)   : credit/debit card number
#           card_type (opt) : either (D)ebit or (C)redit.
#           expiry  (opt)   : expiry date
#           cpm_id          : cpm_id
# returns : 0/1
#
proc do_verf_check {
	pay_mthd
	pay_sort
	acct_id
	{card_no ""}
	{card_scheme ""}
	{expiry  ""}
	{cpm_id ""}
	{in_trans "N"}
} {
	set fn {verification_check::do_verf_check}

	if {!([OT_CfgGet OVS_VALIDATION 0] && [OT_CfgGet FUNC_OVS 0])} {
		# OVS switched off, should never get to this but just make sure.
		ob_log::write ERROR {${fn}: OVS is switched off.}
		return 1
	}

	# Bug Fix:
	# some pay methods pass through DEP/WTD, some pass through D/W
	# quick n dirty:
	switch -- $pay_sort {
		DEP -
		D {
			set pay_sort D
		}
		WTD -
		W {
			set pay_sort W
		}
		default {
			# not good
			error "verification_check:do_verf_check: invalid pay_sort: $pay_sort"
		}
	}

	#
	# Get the cust_id and country codes.
	#
	set ovs_vrf_rs [ob_db::exec_qry verification_check::get_ovs_cust_details $acct_id]

	if {[db_get_nrows $ovs_vrf_rs] == 1} {
		set cust_id      [db_get_col $ovs_vrf_rs 0 cust_id]
		set country_code [db_get_col $ovs_vrf_rs 0 country_code]
	} else {
		ob::log::write ERROR "Unable to retrieve cust_id for acct_id:$acct_id"
		return 0
	}

	db_close $ovs_vrf_rs


	#
	# Check if customer has been manually verified in the admin screens
	#
	set ovs_vrf_status [get_ovs_status $cust_id "AGE"]
	ob_log::write INFO {${fn}: OVS status=$ovs_vrf_status}


	#
	# Is age verifiction enabled for this country/payment method?
	#
	set age_verf_enabled 1
	set action        {C} ;# JBLTEST: need to rename prfl_*
	set profile_model_id {}
	# Need to change this to FUNC_OVS_PAYMENT_MODEL_CHK
	if {[OT_CfgGet FUNC_OVS_PAYMENT_MODEL_CHK 0]} {
		# CC has a type of either debit or credit.

		if {$card_scheme != "" && $card_scheme != "----"} {
			set ovs_vrf_rs [ob_db::exec_qry verification_check::check_pmt_map_cc \
						[OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""] \
						$pay_mthd \
						$country_code \
						$card_scheme]
		} else {
			set ovs_vrf_rs [ob_db::exec_qry verification_check::check_pmt_map \
						[OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""] \
						$pay_mthd \
						$country_code]
		}

		# We are only after a single row to establish that this is enabled
		set nrows [db_get_nrows $ovs_vrf_rs]
		if {$nrows == 0} {
			ob_log::write INFO {${fn}: Not enabled for payment type $pay_mthd}
			return 1
		} elseif {$nrows > 1} {
			ob_log::write ERROR {${fn}: More than one row returned. Not allowing payment.}
			return 0
		}

		ob_log::write ERROR {${fn}: Enabled for payment method: $pay_mthd, scheme: $card_scheme}

		# Grab the grace and status
		# JBLTEST: Move status.
		set action        [db_get_col $ovs_vrf_rs 0 action]
		set status        [db_get_col $ovs_vrf_rs 0 status]
		set prfl_pmt_sort [db_get_col $ovs_vrf_rs 0 pmt_sort]
		set profile_model_id [db_get_col $ovs_vrf_rs 0 vrf_prfl_model_id]
		db_close $ovs_vrf_rs
	}

	#
	# Can the customer withdrawal.
	#
	if {[OT_CfgGet FUNC_OVS_DISALLOW_WTD 0]} {
		if {$pay_sort == "W"} {
			set wtd_result [check_cust_can_wtd $cust_id "AGE"]
			if {[lindex $wtd_result 0] != 1} {
				return $wtd_result
			}
		}
	}

	# If the profile model is configured on, check that the pay_sort needs checking.
	if {
		   [OT_CfgGet FUNC_OVS_PAYMENT_MODEL_CHK 0]
		&& ($pay_sort != $prfl_pmt_sort)
	} {
		ob_log::write INFO {Processing pay_sort:$pay_sort, Model pay_sort:$prfl_pmt_sort, NOT continuing with check.}
		return 1
	}


	#
	# Check if customer DOB exists in the database
	#
	if {[OT_CfgGet FUNC_OVS_CHK_DOB_EXISTS 0]} {
		set dob_exists [chk_cust_dob_exists $cust_id]
		if {[lindex $dob_exists 0] == 0} {
			return $dob_exists
		}
	}

	#
	# Which mode is OVS in USE_SERVER or USE_QUEUE
	#
	if {[catch {set ovs_vrf_rs [ob_db::exec_qry verification_check::get_operation_mode]} msg]} {
		ob_log::write WARNING {${fn}: Error OVS Failed to execute get_operation_mode qry $msg}
		return 0
	}

	set ovs_mode "server"
	if {[db_get_nrows $ovs_vrf_rs]} {
		set ovs_mode [db_get_col $ovs_vrf_rs 0 ovs_mode]
	}
	db_close $ovs_vrf_rs

	set uru_country [list]
	set uru_country [split [OT_CfgGet FUNC_OVS_COUNTRIES ""] ","]

	#
	# OVS - Check if the UK customer has made any previous payments
	# If prev_pmt = 0, we will need to verify their details
	#
	if {[OT_CfgGet FUNC_DISABLE_OVS_COUNTRIES 0] || [lsearch $uru_country $country_code] != -1 } {

		if {$ovs_mode == "server"} {
			ob_log::write INFO {${fn}: Attempting verification via server}

			if {[OT_CfgGet FUNC_OVS_CHK_ON_FIRST_DEP_ONLY 0]} {
				set prev_pmt [check_cust_all_prev_pmt $cust_id]
			} elseif {[OT_CfgGet FUNC_OVS_CHK_ON_CHANGE_OF_CARD 0]} {
				set prev_pmt [check_cust_prev_pmt_on_card $cust_id $cpm_id]
			} else {
				# Although not strictly true, in order to avoid suspending withdrawal
				# methods for everyone if OVS is switched off, set prev_pmt to 1.
				set prev_pmt 1
			}

			if {[OT_CfgGet FUNC_OVS_CHK_ONLY_ONCE 0]} {
				# Only do the AV check once regardless of whether the txn was successful or not.
				if {[prev_ovs_check_exists $cust_id "AGE"]} {
					set prev_pmt 1
				}
			}

			# If we are not checking just set the status.
			ob_log::write ERROR {$prev_pmt == 0, $action != C, $ovs_vrf_status == \"\"}
			if {$prev_pmt == 0 || $ovs_vrf_status == ""} {
				if {$action != {C}} {
					# Update tVrfCustStatus and exit.
					if {[update_vrf_status $cust_id $status "" "AGE" $profile_model_id $in_trans]} {
						return 1
					} else {
						return 0
					}
				}
				set proceed_with_ovs_check 1
				if {[OT_CfgGet FUNC_OVS_MANUAL_OVERRIDE 0]} {
					if {$ovs_vrf_status == "A"} {
						set proceed_with_ovs_check 0
					}
				}

				if {$proceed_with_ovs_check && [OT_CfgGet FUNC_OVS_USE_SERVER 0]} {

					# Do card schema check.
					if {[OT_CfgGet FUNC_OVS_DO_SCHEME_CHECK 0]} {
						set ovs_card_scheme_result [do_verification_via_server $cust_id "SCHEME" $profile_model_id \
							-card_no $card_no -expiry_date $expiry]
						#Check if customer passed Card Scheme check. If they have, we do not want to
						#verify their age.
						if {[lindex $ovs_card_scheme_result 0] == 1} {
							set proceed_with_ovs_check 0
						}
					}

					# Do age verification check.
					if {[OT_CfgGet FUNC_OVS_DO_AGE_CHECK 0] && $proceed_with_ovs_check && $age_verf_enabled} {

						set ovs_age_result [do_verification_via_server $cust_id "AGE" $profile_model_id]

						if {[lindex $ovs_age_result 0] == 1} {
							if {[OT_CfgGet FUNC_OVS_DO_CARD_CHECK 0]} {
								set ovs_card_result [do_verification_via_server $cust_id "CARD" $profile_model_id \
									-card_no $card_no -expiry_date $expiry]
								if {[lindex $ovs_card_result 0] == 0} {
									return $ovs_card_result
								}
							}
						} else {
							return $ovs_age_result
						}
					}
				}
			} else {
				ob_log::write INFO {${fn}: Check already been done.}
			}
		} elseif {$ovs_mode == "queue"} {
			ob_log::write INFO {${fn}: Attempting verification via queue}

			# QUEUE...
			if {[OT_CfgGet FUNC_OVS_CHK_ON_FIRST_DEP_ONLY 0]} {
				set prev_pmt [check_cust_all_prev_pmt $cust_id]

				if {$prev_pmt == 0 || $ovs_vrf_status == ""} {
					set proceed_with_ovs_check 1
					if {[OT_CfgGet FUNC_OVS_MANUAL_OVERRIDE 0]} {
						if {$ovs_vrf_status == "A"} {
							set proceed_with_ovs_check 0
						}
					}

					if {$proceed_with_ovs_check} {
						# bind up the verification details
						set queue_details [bind_ovs_queue_details $cust_id "AGE"]

						# OVS - sends verification request via queue
						do_verification_via_queue $queue_details "AGE1" $profile_model_id $in_trans
					}

				} else {
					ob_log::write INFO {${fn}: Check already been done.}
				}
			}
		}
	}

	# Return success.
	return 1
}



#
# Has the customer had any previous OVS checks og <<type>>
# params:
#   cust_id	-
#   type	- OVS type
#
# returns:
#	1/0
#
proc prev_ovs_check_exists {cust_id type} {
	global DB

	set vrf_prfl_code [OT_CfgGet "FUNC_OVS_${type}_VRF_PRFL_CODE" ""]

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::has_prev_ovs_check $cust_id $vrf_prfl_code]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::has_prev_check: $msg}
		return 0
	}

	set prev_checks [db_get_coln $res 0 0]
	ob_db::rs_close $res

	if {$prev_checks} {
		return 1
	} else {
		return 0
	}
}


#
# Get the OVS status.
# params:
#   cust_id	-
#   type	- OVS type
#
# returns:
#	[list <status>]
#
proc get_ovs_status {cust_id type} {
	global DB

	set vrf_prfl_code [OT_CfgGet "FUNC_OVS_${type}_VRF_PRFL_CODE" ""]

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_ovs_details $cust_id $vrf_prfl_code]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ovs_details: $msg}
		return ""
	}

	if {![db_get_nrows $res]} {
		# Return (A)ctive if not found.
		return ""
	}

	set status [db_get_col $res 0 status]

	ob_db::rs_close $res

	return $status
}

#
# Find out if the customer's status will change
# automatically after a grace period
#
# params: cust_id   -
#         type      - OVS type
#
# returns: [list <whether is grace or not> <expiry date>]
#
proc get_ovs_status_grace {cust_id type} {

	global DB

	set vrf_prfl_code [OT_CfgGet "FUNC_OVS_${type}_VRF_PRFL_CODE" ""]

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_ovs_status_grace $cust_id $vrf_prfl_code]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ovs_status_grace: $msg}
		return [list]
	}

	if {![db_get_nrows $res]} {
		ob_db::rs_close $res
		return [list]
	}

	set status      [db_get_col $res 0 status]
	set is_grace    [db_get_col $res 0 is_grace]
	set expiry_date [db_get_col $res 0 expiry_date]

	ob_db::rs_close $res

	return [list $status $is_grace $expiry_date]
}

#close namespace
}
