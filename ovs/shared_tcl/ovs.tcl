# $Id: ovs.tcl,v 1.1 2011/10/04 12:40:40 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to the verication system.
#
# Provides a wrapper to all verification methods e.g. ProveURU & Geopoint
# Uses profile definitions to store and score individual user verification
# results.
#
# Configuration:
#	OVS_GEOPOINT     enable geopoint IP           - (1)
#	OVS_DATACASH     enable datacash ProveURU API - (1)
#	OVS_GENERIC      enable generic test harness  - (1)
#	OVS_CARD         enable card schema test      - (1)
#	OVS_ENABLE       enable OVS checks            - (1)
#	OVS_URU_SCORE    use score from URU           - (1)
#	OVS_SCORE_WEIGHT starting score               - (0)
#
# Synopsis:
#    package require ovs_ovs ?4.5?
#
# Procedures:
#	ob_ovs::init        one time initialisation
#	ob_ovs::get_empty   returns empty array of values to be checked
#	ob_ovs::run_profile runs a verification profile
#	ob_ovs::get_uru_log retrieves details of a prior verification from
#                        ProveURU
#
# Return Status:
#	OB_OK                   - Completed successfully
#	OB_ERR_OVS_QRY_FAIL     - Failed to run DB query
#	OB_ERR_OVS_PRFL_INVALID - Invalid data passed to procedure
#	OB_ERR_OVS_NO_CHKS      - No applicable checks
#	OB_ERR_OVS_INVALID_DATA - Unexpected value returned from DB query
#	OB_ERR_OVS_CHK_ERR      - Error running check
#	OB_ERR_OVS_QRY_FAIL     - DB query failed
#	OB_ERR_OVS_LOG_FAIL     - Log retrieval failed
#	OB_ERR_OVS_UNKNOWN_RESP - Unknown response for verification check
#
package provide ovs_ovs 4.5



# Dependencies
#
package require util_db
package require util_log



# Variables
#
namespace eval ob_ovs {

	variable INITIALISED
	variable CLASSES
	variable PROVIDERS

	set INITIALISED 0
	set CLASSES   [list URU GEN CARD IP AUTH_PRO]
	set PROVIDERS [list DATACASH PROVEURU GEOPOINT CAPSCAN OPENBET GENERIC AUTH_PRO]

	variable FIELDS
	array set FIELDS [list]

	set FIELDS(common) [list \
		cust_id \
		address_count \
		channel \
		profile_code \
		profile_def_id \
		callback \
		ext_profile_def_id \
		provider_code \
		provider_uname \
		provider_passwd \
		provider_action \
		provider_uri \
		title \
		forename \
		middle_initial \
		surname \
		dob_year \
		dob_month \
		dob_day \
		country \
		gender \
		email]

	set FIELDS(checks) [list]

	if {[OT_CfgGetTrue OVS_DATACASH] || [OT_CfgGetTrue OVS_PROVEURU] ||
		[OT_CfgGetTrue OVS_GENERIC] || [OT_CfgGetTrue OVS_AUTH_PRO]} {
		for {set i 1} {$i <= 4} {incr i} {
			lappend FIELDS(checks) address${i}
			set FIELDS(address${i}) [list \
				postcode \
				building_name \
				building_no \
				sub_building \
				organisation \
				street \
				sub_street \
				town \
				district \
				first_year_of_residence \
				last_year_of_residence]
		}
	}

	if {[OT_CfgGetTrue OVS_DATACASH] || [OT_CfgGetTrue OVS_PROVEURU]} {
		lappend FIELDS(checks) telephone
		set FIELDS(telephone) [list \
			number \
			active_year \
			active_month \
			exdirectory]

		lappend FIELDS(checks) passport
		set FIELDS(passport) [list \
			number1 \
			number2 \
			number3 \
			number4 \
			number5 \
			number6 \
			expiry_year \
			expiry_month \
			expiry_day]

		lappend FIELDS(checks) passport_int
		set FIELDS(passport_int) [list \
			number1 \
			number2 \
			number3 \
			number4 \
			number5 \
			number6 \
			number7 \
			number8 \
			number9 \
			expiry_year \
			expiry_month \
			expiry_day \
			country_of_origin]

		lappend FIELDS(checks) electric
		set FIELDS(electric) [list \
			number1 \
			number2 \
			number3 \
			number4 \
			mail_sort \
			postcode]

		lappend FIELDS(checks) driver
		set FIELDS(driver) [list \
			number1 \
			number2 \
			number3 \
			number4 \
			mail_sort \
			postcode \
			microfiche \
			issue_day \
			issue_month \
			issue_year]

		lappend FIELDS(checks) card
		set FIELDS(card) [list \
			number \
			expiry_date \
			issue_number \
			verification_code\
			type]
	}

	if {[OT_CfgGetTrue OVS_GEOPOINT]} {
		lappend FIELDS(checks) ip
		set FIELDS(ip) address
	}

	if {[OT_CfgGetTrue OVS_OPENBET]} {
		lappend FIELDS(checks) scheme
		set FIELDS(scheme) type
		lappend FIELDS(checks) card_bin
		set FIELDS(card_bin) bin
	}
}


# One time initialisation
# Initialise geopoint and verification modules
# Call proc to prepare queries
#
proc ob_ovs::init {} {

	variable INITIALISED
	variable SCORE
	variable CLASSES

	if {$INITIALISED} {
		return
	}

	if {[OT_CfgGet OVS_QUEUE_CALLBACK_PATH ""] != ""} {
		source [OT_CfgGet OVS_QUEUE_CALLBACK_PATH ""]
	}

	ob_log::write INFO {ob_ovs: Initialising OVS}
	ob_db::init
	_prep_ovs_queries

	if {[OT_CfgGetTrue OVS_GEOPOINT]} {
		package require security_geopoint
		ob_geopoint::init

		_prep_ip_queries
	}

	if {[OT_CfgGetTrue OVS_DATACASH]} {
		package require ovs_datacash
		ob_ovs_dcash::init
	}

	if {[OT_CfgGetTrue OVS_PROVEURU]} {
		package require ovs_proveuru
		ob_ovs_proveuru::init
	}

	if {[OT_CfgGetTrue OVS_AUTH_PRO]} {
		package require ovs_auth_pro
		ob_ovs_auth_pro::init

		_prep_auth_pro_queries
	}

	if {[OT_CfgGetTrue OVS_DATACASH] || [OT_CfgGetTrue OVS_PROVEURU]} {
		_prep_uru_queries
	}

	if {[OT_CfgGetTrue OVS_OPENBET]} {
		package require ovs_openbet
		ob_ovs_openbet::init
		_prep_card_queries
	}

	if {[OT_CfgGetTrue OVS_GENERIC]} {
		package require ovs_generic
		ob_ovs_generic::init
		_prep_generic_queries
	}

	foreach class $CLASSES {
		set SCORE(override,$class) [OT_CfgGet OVS_${class}_SCORE 0]
	}
	set SCORE(weight) [OT_CfgGet OVS_SCORE_WEIGHT 0]

	set INITIALISED 1
}



# Returns an array of data fields to be populated and passed back for checks
# Calling code fills out the fields data is available for and others are left
# empty
#
proc ob_ovs::get_empty {} {

	variable FIELDS
	variable INITIALISED

	if {!$INITIALISED} {
		init
	}

	foreach field $FIELDS(common) {
		set DATA($field) ""
	}

	foreach check $FIELDS(checks) {
		foreach field $FIELDS($check) {
			set DATA($check,$field) ""
		}
	}

	return [array get DATA]
}



# Prepares general stored queries
#
proc ob_ovs::_prep_ovs_queries {} {

	ob_log::write DEV {OVS: Initialisng OVS queries}

	# Get valid profile definition using a unique code
	ob_db::store_qry ob_ovs::get_profile_code {

		select
			d.vrf_prfl_def_id as profile_def_id,
			c.status
		from
			tVrfPrflDef d,
			tVrfPrflCty c
		where
			d.vrf_prfl_code = ?
		and d.vrf_prfl_def_id = c.vrf_prfl_def_id
		and d.status =  'A'
		and c.status != 'S'
		and d.channels like ?
		and c.country_code = ?

	}

	# Get profile definition using an ID
	ob_db::store_qry ob_ovs::get_profile_def_id {

		select
			d.vrf_prfl_def_id as profile_def_id,
			c.status
		from
			tVrfPrflDef d,
			tVrfPrflCty c
		where
			d.vrf_prfl_def_id = ?
		and d.vrf_prfl_def_id = c.vrf_prfl_def_id
		and d.status =  'A'
		and c.status != 'S'
		and d.channels like ?
		and c.country_code = ?
	}

	# get profile model using a profile ID, country code and profile model ID
	ob_db::store_qry ob_ovs::get_profile_by_model_and_code {
		select
			d.vrf_prfl_def_id as profile_def_id,
			c.status
		from
			tVrfPrflDef d,
			tVrfPrflCty c,
			tVrfPrflModel m
		where
			d.vrf_prfl_code = ?
		and     d.vrf_prfl_def_id = c.vrf_prfl_def_id
		and     d.vrf_prfl_def_id = m.vrf_prfl_def_id
		and     d.status  = 'A'
		and     c.status != 'S'
		and     d.channels   like ?
		and     c.country_code  = ?
		and     m.vrf_prfl_model_id = ?
	}

	# get profile model using a profile ID, country code and profile model ID
	ob_db::store_qry ob_ovs::get_profile_by_model {
		select
			d.vrf_prfl_def_id as profile_def_id,
			c.status
		from
			tVrfPrflDef d,
			tVrfPrflCty c,
			tVrfPrflModel m
		where
			d.vrf_prfl_def_id = ?
		and     d.vrf_prfl_def_id = c.vrf_prfl_def_id
		and     d.vrf_prfl_def_id = m.vrf_prfl_def_id
		and     d.status  = 'A'
		and     c.status != 'S'
		and     d.channels   like ?
		and     c.country_code  = ?
		and     m.vrf_prfl_model_id = ?
	}

	# Get profile definition actions
	ob_db::store_qry ob_ovs::get_action {

		select
			action,
			high_score
		from
			tVrfPrflAct
		where
			vrf_prfl_def_id = ?
		order by
			high_score
	}

	# Get profile definition actions
	ob_db::store_qry ob_ovs::get_action_exceptions {
		select
			action,
			score
		from
			tVrfPrflEx
		where
			vrf_prfl_def_id = ?
		order by
			score
	}

	# Get profile definition check definitions
	ob_db::store_qry ob_ovs::get_check_def {
		select
			c.vrf_chk_def_id as check_def_id,
			c.vrf_chk_type   as check_type,
			t.vrf_chk_class  as check_class,
			c.channels,
			c.check_no
		from
			tVrfChkDef c,
			tVrfChkType t,
			tVrfPrflDef p
		where
			c.vrf_prfl_def_id = ?
		and c.vrf_chk_type = t.vrf_chk_type
		and c.vrf_prfl_def_id = p.vrf_prfl_def_id
		and c.channels like ?
		and c.status = 'A'
		order by
			c.check_no
	}

	# Insert verification profile
	ob_db::store_qry ob_ovs::store_profile {

		insert into tVrfPrfl (
			vrf_prfl_def_id,
			cust_id,
			check_type
		) values (?, ?, ?)

	}

	# Insert new verification check
	ob_db::store_qry ob_ovs::store_check {

		insert into
			tVrfChk
		(
			vrf_prfl_id,
			vrf_chk_def_id,
			vrf_chk_type,
			check_no,
			vrf_ext_cdef_id,
			vrf_prfl_model_id
		)
		values
			(?, ?, ?, ?, ?, ?)
	}

	# Insert verification profile
	ob_db::store_qry ob_ovs::confirm_profile_action {

		update
			tVrfPrfl
		set
			action      = ?,
			action_desc = ?,
			user_id     = ?
		where
			vrf_prfl_id = ?
	}

	# Queue customer for verification
	ob_db::store_qry ob_ovs::queue_customer {

		insert into
			tVrfCustQueue
		(
			cust_id,
			vrf_prfl_def_id,
			vrf_prfl_model_id
		)
		values
			(?, ?, ?)
	}

	# Get details of external profiles, and their providers
	# for all profiles that can perform a specific check
	ob_db::store_qry ob_ovs::get_ext_profiles {
		select
			p.vrf_ext_pdef_id  pdef_id,
			p.prov_prf_id      pdef_ext_id,
			pr.vrf_ext_prov_id prov_id,
			pr.priority        prov_priority
		from
			tVrfExtChkDef  c,
			tVrfExtPrflDef p,
			tVrfExtProv    pr
		where
			p.vrf_ext_pdef_id = c.vrf_ext_pdef_id and
			p.vrf_ext_prov_id = pr.vrf_ext_prov_id and

			pr.status = 'A' and
			p.status  = 'A' and
			c.status  = 'A' and

			vrf_chk_type = ?
	}

	# Get all the external checks for an external profile
	ob_db::store_qry ob_ovs::get_ext_checks {
		select
			vrf_chk_type
		from
			tVrfExtChkDef
		where
			status = 'A' and

			vrf_ext_pdef_id = ?
	}

	# Get the details of an external provider
	ob_db::store_qry ob_ovs::get_ext_prov_conn {
		select
			p.code,
			c.uri,
			c.action,
			c.uname,
			c.password
		from
			tVrfExtProv p,
			tVrfExtProvConn c
		where
			p.vrf_ext_prov_id = c.vrf_ext_prov_id and

			p.status = 'A' and
			c.status = 'A' and

			p.vrf_ext_prov_id = ? and
			c.type = ?
	}

	# Get profile definition check definitions
	ob_db::store_qry ob_ovs::get_ext_check_def {

		select
			e.vrf_ext_cdef_id as ext_check_def_id,
			c.check_no
		from
			tVrfExtChkDef e,
			tVrfChkDef c
		where
			e.vrf_chk_type = c.vrf_chk_type and

			e.vrf_ext_pdef_id = ? and
			c.vrf_prfl_def_id = ? and

			e.status = 'A' and
			c.status = 'A'
		order by
			c.check_no
	}

	# Get the external provider for a profile that has
	# been executed.
	ob_db::store_qry ob_ovs::get_ext_prov {
		select
			distinct
			epc.vrf_ext_prov_id
		from
			tVrfChk        c,
			tVrfExtChkDef  edc,
			tVrfExtPrflDef epc
		where
			c.vrf_ext_cdef_id   = edc.vrf_ext_cdef_id and
			edc.vrf_ext_pdef_id = epc.vrf_ext_pdef_id and
			c.vrf_prfl_id       = ?
	}
}



# Prepares ProveURU specific stored queries
#
proc ob_ovs::_prep_uru_queries {} {
	# get URU check definition
	ob_db::store_qry ob_ovs::get_uru_check_def {

		select
			vrf_uru_def_id as id,
			response_no as lookup,
			score
		from
			tVrfURUDef
		where
			vrf_chk_def_id = ?
		order by
			response_no
	}

	# get URU checks
	ob_db::store_qry ob_ovs::get_uru_check {

		select
			p.vrf_prfl_def_id as profile_def_id,
			c.vrf_chk_type as type,
			ud.score,
			ud.response_no,
			ud.description
		from
			tVrfChk c,
			tVrfPrfl p,
			tVrfURUChk uc,
			tVrfURUDef ud
		where
			c.vrf_prfl_id = ?
		and c.vrf_prfl_id = p.vrf_prfl_id
		and c.vrf_check_id = uc.vrf_check_id
		and uc.vrf_uru_def_id = ud.vrf_uru_def_id
	}

	# insert URU verification check
	ob_db::store_qry ob_ovs::store_uru_check {

		insert into
			tVrfURUChk
		(
			vrf_check_id,
			vrf_uru_def_id,
			score,
			uru_reference
		)
		values
			(?, ?, ?, ?)
	}
}


proc ob_ovs::_prep_auth_pro_queries {} {
	# get AUTH_PRO check definition
	ob_db::store_qry ob_ovs::get_auth_pro_check_def {
		select
			vrf_auth_pro_def_id as id,
			response_no as lookup,
			score
		from
			tVrfAuthProDef
		where
			vrf_chk_def_id = ?
		order by
			response_no
	}

	ob_db::store_qry ob_ovs::get_auth_pro_check {
		select
			p.vrf_prfl_def_id as profile_def_id,
			c.vrf_chk_type as type,
			ud.score,
			ud.response_no,
			ud.description
		from
			tVrfChk c,
			tVrfPrfl p,
			tVrfAuthProChk uc,
			tVrfAuthProDef ud
		where
			c.vrf_prfl_id = ?
		and c.vrf_prfl_id = p.vrf_prfl_id
		and c.vrf_check_id = uc.vrf_check_id
		and uc.vrf_auth_pro_def_id = ud.vrf_auth_pro_def_id
	}

	# insert URU verification check
	ob_db::store_qry ob_ovs::store_auth_pro_check {

		insert into
			tVrfAuthProChk
		(
			vrf_check_id,
			vrf_auth_pro_def_id,
			score,
			resp_value
		)
		values
			(?, ?, ?, ?)
	}
}


# Prepares GeoPoint specific stored queries
#
proc ob_ovs::_prep_ip_queries {} {
	# get IP check definition
	ob_db::store_qry ob_ovs::get_ip_check_def {

		select
			vrf_ip_def_id as id,
			score,
			country_code || "," || response_type as lookup
		from
			tVrfIPDef
		where
			vrf_chk_def_id = ?
		order by
			lookup
	}

	# insert IP verification check
	ob_db::store_qry ob_ovs::store_ip_check {

		insert into
			tVrfIPChk
		(
			vrf_check_id,
			vrf_ip_def_id,
			score,
			expected_ctry,
			ip_ctry
		)
		values
			(?, ?, ?, ?, ?)
	}
}



# Prepares Card Schema specific stored queries
#
proc ob_ovs::_prep_card_queries {} {
	# get card check definition
	ob_db::store_qry ob_ovs::get_card_check_def {

		select
			vrf_card_def_id as id,
			scheme as lookup,
			score
		from
			tVrfCardDef
		where
			vrf_chk_def_id = ?
		order by
			scheme
	}

	# insert card verification check
	ob_db::store_qry ob_ovs::store_card_check {

		insert into
			tVrfCardChk
		(
			vrf_check_id,
			vrf_card_def_id,
			score
		)
		values
			(?, ?, ?)
	}


	# get card Bin check definition
	ob_db::store_qry ob_ovs::get_card_bin_check_def {

		select
			vrf_cbin_def_id as id,
			vrf_chk_def_id as check_id,
			bin_lo,
			bin_hi,
			score
		from
			tVrfCardBinDef
		where
			vrf_chk_def_id = ?
		order by
			bin_lo
	}

	# insert card Bin verification check
	ob_db::store_qry ob_ovs::store_card_bin_check {

		insert into
			tVrfCardBinChk
		(
			vrf_check_id,
			vrf_cbin_def_id,
			card_bin,
			score
		)
		values
			(?, ?, ?, ?)
	}
}


# Prepares Generic harness specific stored queries
#
proc ob_ovs::_prep_generic_queries {} {
	# get generic check definition
	ob_db::store_qry ob_ovs::get_gen_check_def {

		select
			vrf_gen_def_id as id,
			response_no as lookup,
			score
		from
			tVrfGenDef
		where
			vrf_chk_def_id = ?
		order by
			response_no
	}

	# get generic checks
	ob_db::store_qry ob_ovs::get_gen_check {

		select
			p.vrf_prfl_def_id as profile_def_id,
			c.vrf_chk_type as type,
			gd.score,
			gd.response_no,
			gd.description
		from
			tVrfChk c,
			tVrfPrfl p,
			tVrfGenChk gc,
			tVrfGenDef gd
		where
			c.vrf_prfl_id = ?
		and c.vrf_prfl_id = p.vrf_prfl_id
		and c.vrf_check_id = gc.vrf_check_id
		and gc.vrf_gen_def_id = gd.vrf_gen_def_id
	}

	# Insert generic verification check
	ob_db::store_qry ob_ovs::store_gen_check {

		insert into
			tVrfGenChk
		(
			vrf_check_id,
			vrf_gen_def_id,
			score
		)
		values
			(?, ?, ?)
	}
}



# Queues a customer for later verification against a profile
# NB. When calling the proc either profile definition ID or code must be
# provided
#
#	cust_id       - customer ID
#	prfl_def_id   - profile definition ID
#	prfl_def_code - profile definition code
#	country       - customer's country code
#	channel       - channel
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::queue_customer {cust_id prfl_def_id prfl_def_code prfl_model_id country channel} {

	variable INITIALISED

	if {!$INITIALISED} {
		init
	}

	# Check there is a valid profile definition
	foreach {status prfl_def_id} [_check_profile_def \
		$prfl_def_id \
		$prfl_def_code \
		$prfl_model_id \
		$country \
		$channel] {
		break
	}
	if {$status != "OB_OK"} {
		return $status
	}

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::queue_customer $cust_id $prfl_def_id $prfl_model_id]
	} msg]} {
		ob_log::write ERROR \
			{OVS: Failed to run query ob_ovs::queue_customer: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	ob_db::rs_close $res

	return OB_OK
}



# Uses list of customer details and profile definition details passed in
# array to run a verification against a customer. If required it then scores
# the results and updates the customer status accordingly.
#
# NOTE: Please call ob_ovs::get_empty to retrieve template array to be
# populated and passed to this procedure
#
#	array_list - populated list of fields for verification
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::run_profile { array_list {in_tran 0} {manual_chk "OB_AUTOMATIC_CHECK"}} {

	variable INITIALISED
	variable PROFILE

	if {!$INITIALISED} {
		init
	}

	catch {unset PROFILE}
	array set PROFILE $array_list

	# Default the prfl_model_id to null.
	if {![info exists PROFILE(prfl_model_id)]} {
		set PROFILE(prfl_model_id) {}
	}

	# Should we use the callback? - Default is 1!
	if {[info exists PROFILE(upd_status)]} {
		set upd_status $PROFILE(upd_status)
	} else {
		set upd_status 1
	}

	# Check there is a valid profile definition
	foreach {
		status
		PROFILE(profile_def_id)
	} [_check_profile_def \
		$PROFILE(profile_def_id) \
		$PROFILE(profile_code) \
		$PROFILE(prfl_model_id) \
		$PROFILE(country) \
		$PROFILE(channel)\
	] {
		break
	}

	if {$status != "OB_OK"} {
		return $status
	}

	# Retrieve the associated profile actions
	set status [_get_profile_actions]
	if {$status != "OB_OK"} {
		return $status
	}

	# Retrieve the associated check definitions
	set status [_get_profile_checks]
	if {$status != "OB_OK"} {
		return $status
	}

	# Retrieve the provider for the checks
	set status [_get_profile_provider]
	if {$status != "OB_OK"} {
		return $status
	}

	# Check if any ProveURU queries are required
	if {$PROFILE(DATACASH)} {

		foreach {status data} [ob_ovs_dcash::run_check [array get PROFILE]] {
			break
		}

		if {$status != "OB_OK"} {
			return $status
		} else {
			array set PROFILE $data
		}
	}

	if {$PROFILE(PROVEURU)} {

		set PROFILE(URU) 1

		foreach {status data} [ob_ovs_proveuru::run_check [array get PROFILE]] {
			break
		}

		if {$status != "OB_OK"} {
			return $status
		} else {
			array set PROFILE $data
		}
	}

	if {$PROFILE(AUTH_PRO)} {

		foreach {status data} [ob_ovs_auth_pro::run_check [array get PROFILE]] {
			break
		}

		if {$status != "OB_OK"} {
			if {[OT_CfgGet FUNC_ACTION_ON_ERROR 0]} {
				if {[catch {
					$PROFILE(callback) \
						[OT_CfgGet OVS_ACTION_ON_ERROR_STATUS "P"] \
						$PROFILE(profile_def_id) \
						$PROFILE(cust_id) \
						$PROFILE(prfl_model_id)
				} msg]} {
					ob_log::write ERROR {OVS: Error in callback function :$msg}
				}
			}

			return $status
		} else {
			array set PROFILE $data
		}
	}

	# Check if any IP queries are required
	if {$PROFILE(GEOPOINT)} {

		if {$PROFILE(ip,address) != ""} {
			set fields [list \
				ip_country \
				ip_is_aol \
				ip_city \
				ip_routing \
				country_cf]

			if {[OT_CfgGetTrue OVS_GEOPOINT]} {
				foreach $fields [ob_geopoint::ip_to_cc $PROFILE(ip,address)] {
					break
				}
			} else {
				foreach field $fields {set $field "??"}
			}
			foreach field $fields {
				set PROFILE(IP,$field) [set $field]
			}

			if {$ip_country == "??"} {
				# IP unknown
				set PROFILE(GEO_IP_LOCATION,responses) "$PROFILE(country),U"

			} elseif {$ip_country == $PROFILE(country)} {
				# IP match
				set PROFILE(GEO_IP_LOCATION,responses) "$PROFILE(country),M"

			} else {
				# IP mismatch
				set PROFILE(GEO_IP_LOCATION,responses) "$PROFILE(country),N"
			}
		} else {
			set PROFILE(GEO_IP_LOCATION,responses) "$PROFILE(country),U"
		}
	}

	# Check if any Card Scheme queries are required
	if {$PROFILE(OPENBET)} {

		ob_log::write DEV {Running card checks using the openbet card supplier}
		foreach {status data} [ob_ovs_openbet::run_check [array get PROFILE]] {
			break
		}

		if {$status != "OB_OK"} {
			return $status
		} else {
			array set PROFILE $data
		}
	}

	# Check if any generic harness queries are required
	if {$PROFILE(GENERIC)} {

		foreach {status data} [ob_ovs_generic::run_check [array get PROFILE]] {
			break
		}

		if {$status != "OB_OK"} {
			return $status
		} else {
			array set PROFILE $data
		}
	}

	# Score the check
	set status [_score_check]
	if {$status != "OB_OK"} {
		return $status
	}

	# If there is a cust_id supplied, store the check
	if {$PROFILE(cust_id) != ""} {

		if { !$in_tran } {
			ob_db::begin_tran
		}

		set status [_store_check $status $manual_chk "Y" $upd_status]

		if {$status != "OB_OK"} {

			if { !$in_tran } {
				ob_db::rollback_tran
			}

			return $status
		}

		if { !$in_tran } {
			ob_db::commit_tran
		}

	}

	return [list OB_OK [array get PROFILE]]
}



# Confirms profile definition ID and checks it is active and applies to
# customer being verified based on channel, country etc.
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_check_profile_def {pd_id code prfl_model_id country channel} {

	variable PROFILE

	set channel "%$channel%"

	if {$code == "" && $pd_id == ""} {
		ob_log::write ERROR \
			{OVS: Must specify valid profile code or ID}
		return OB_ERR_OVS_PRFL_INVALID
	}

	if {$code != ""} {
		
		# use the prfl_model_id if it's been provided
		if {$prfl_model_id != "" && [catch {
			set res [ob_db::exec_qry ob_ovs::get_profile_by_model_and_code \
				$code $channel $country $prfl_model_id]
		} msg]} {
				
			ob_log::write ERROR \
				{OVS: Failed to run query ob_ovs::get_profile_by_model_and_code: $msg}
			return OB_ERR_OVS_QRY_FAIL

		} elseif {[catch {
			set res [ob_db::exec_qry ob_ovs::get_profile_code \
				$code $channel $country]
		} msg]} {
			ob_log::write ERROR \
				{OVS: Failed to run query ob_ovs::get_profile_code: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

	} else {
		# use the prfl_model_id if it's been provided
		if {$prfl_model_id != "" && [catch {
			set res [ob_db::exec_qry ob_ovs::get_profile_by_model \
				$pd_id $channel $country $prfl_model_id]
		} msg]} {
			
			ob_log::write ERROR \
				{OVS: Failed to run query ob_ovs::get_profile_def_id: $msg}
			return OB_ERR_OVS_QRY_FAIL

		} elseif {[catch {
			set res [ob_db::exec_qry ob_ovs::get_profile_def_id \
				$pd_id $channel $country]
		} msg]} {
			ob_log::write ERROR \
				{OVS: Failed to run query ob_ovs::get_profile_def_id: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}
	}

	# Grab the status of "" if none.
	set status ""
	if {[db_get_nrows $res] == 1} {
		set status [db_get_col $res 0 status]
	}

	switch -- $status {
		G {
			# Set the grace period, and return OB_NO_CHK_REQ (No check required).
			if {[catch {
				$PROFILE(callback) \
					[OT_CfgGet OVS_ACTION_ON_GRACE "P"] \
					$PROFILE(profile_def_id) \
					$PROFILE(cust_id) \
					$PROFILE(prfl_model_id)
			} msg]} {
				ob_log::write ERROR {OVS: Error in callback function :$msg}
			}

			ob_db::rs_close $res
			return OB_NO_CHK_REQ
		}
		A {
			# Do nothing proceed as normal...
		}
		default {
			ob_db::rs_close $res
			ob_log::write ERROR \
				{OVS: Failed to find valid profile definition}
			return OB_ERR_OVS_PRFL_INVALID
		}
	}

	if {$pd_id == ""} {

		set pd_id [db_get_col $res 0 profile_def_id]
		set PROFILE(profile_def_id) $pd_id

	} else {
		# Check existing profile id matches one returned from DB
		if {$pd_id != [db_get_col $res 0 profile_def_id]} {

			ob_db::rs_close $res

			ob_log::write ERROR \
				{OVS: Code does not correlate to profile def ID}
			return OB_ERR_OVS_PRFL_INVALID
		}
	}

	ob_db::rs_close $res

	return [list OB_OK $pd_id]
}



# Retrieves profile definition actions
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_get_profile_actions {} {

	variable PROFILE

	set pd_id $PROFILE(profile_def_id)

	# Get Scores.
	if {[catch {set res [ob_db::exec_qry ob_ovs::get_action $pd_id]} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_action: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set PROFILE(action_count) [db_get_nrows $res]

	for {set n 0} {$n < $PROFILE(action_count)} {incr n} {

		set PROFILE($n,action)     [db_get_col $res $n "action"]
		set PROFILE($n,high_score) [db_get_col $res $n "high_score"]
	}

	ob_db::rs_close $res


	# Get exceptions.
	if {[catch {set res [ob_db::exec_qry ob_ovs::get_action_exceptions $pd_id]} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_action_exceptions: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set PROFILE(exception_count) [db_get_nrows $res]

	for {set n 0} {$n < $PROFILE(exception_count)} {incr n} {
		set PROFILE($n,exception,action)     [db_get_col $res $n "action"]
		set PROFILE($n,exception,score)      [db_get_col $res $n "score"]
	}

	ob_db::rs_close $res

	return OB_OK
}



# Retrieves profile definition checks that apply to customer based on channel
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_get_profile_checks {} {

	variable PROFILE
	variable CLASSES

	set pd_id $PROFILE(profile_def_id)

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_check_def $pd_id "%${PROFILE(channel)}%"]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_check_def: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set PROFILE(check_count) [db_get_nrows $res]

	# Make sure valid checks apply
	if {$PROFILE(check_count) == 0} {

		ob_db::rs_close $res

		ob_log::write ERROR \
			{OVS: No valid checks found for profile $pd_id: $msg}
		return OB_ERR_OVS_NO_CHKS
	}

	foreach class $CLASSES {
		set PROFILE($class)  0
	}

	for {set n 0} {$n < $PROFILE(check_count)} {incr n} {

		foreach field [db_get_colnames $res] {

			set PROFILE($n,$field) [db_get_col $res $n $field]
			ob_log::write DEV {OVS: Check $n $field = $PROFILE($n,$field)}
		}

		set check_type $PROFILE($n,check_type)

		# Append to a list of checks
		lappend PROFILE(checks) $check_type

		switch $PROFILE($n,check_class) {
			URU     {
				set PROFILE(URU) 1
				lappend PROFILE(URU,checks) $check_type

				if {[catch {
					set res2 [ob_db::exec_qry ob_ovs::get_uru_check_def \
						$PROFILE($n,check_def_id)]
				} msg]} {
					ob_db::rs_close $res
					ob_log::write ERROR \
						{OVS: Failed to run query ob_ovs::get_uru_check_def: $msg}
					return OB_ERR_OVS_QRY_FAIL
				}
			}
			IP      {
				set PROFILE(IP) 1
				lappend PROFILE(IP,checks) $check_type

				if {[catch {
					set res2 [ob_db::exec_qry ob_ovs::get_ip_check_def \
						$PROFILE($n,check_def_id)]
				} msg]} {
					ob_db::rs_close $res
					ob_log::write ERROR \
						{OVS: Failed to run query ob_ovs::get_ip_check_def: $msg}
					return OB_ERR_OVS_QRY_FAIL
				}
			}
			CARD    {
				set PROFILE(CARD) 1
				lappend PROFILE(CARD,checks) $check_type
				if { $check_type == "OB_CARD_BIN"} {
					#CARD BIN
					if {[catch {
						set res2 [ob_db::exec_qry ob_ovs::get_card_bin_check_def \
									$PROFILE($n,check_def_id)]
					} msg]} {
						ob_db::rs_close $res
						ob_log::write ERROR \
							{OVS: Failed to run query ob_ovs::get_card_bin_check_def: $msg}
						return OB_ERR_OVS_QRY_FAIL
					}

				} else {
					#CARD SCHEME
					if {[catch {
						set res2 [ob_db::exec_qry ob_ovs::get_card_check_def \
									$PROFILE($n,check_def_id)]
					} msg]} {
						ob_db::rs_close $res
						ob_log::write ERROR \
							{OVS: Failed to run query ob_ovs::get_card_check_def: $msg}
						return OB_ERR_OVS_QRY_FAIL
					}
				}
			}
			GEN     {
				set PROFILE(GEN) 1
				lappend PROFILE(GEN,checks) $check_type

				if {[catch {
					set res2 [ob_db::exec_qry ob_ovs::get_gen_check_def \
						                      $PROFILE($n,check_def_id)]
				} msg]} {
					ob_db::rs_close $res
					ob_log::write ERROR \
						{OVS: Failed to run query ob_ovs::get_gen_check_def: $msg}
					return OB_ERR_OVS_QRY_FAIL
				}
			}
			AUTH_PRO {
				set PROFILE(AUTH_PRO) 1
				lappend PROFILE(AUTH_PRO,checks) $check_type

				if {[catch {
					set res2 [ob_db::exec_qry ob_ovs::get_auth_pro_check_def \
						$PROFILE($n,check_def_id)]
				} msg]} {
					ob_db::rs_close $res
					ob_log::write ERROR \
						{OVS: Failed to run query ob_ovs::get_auth_pro_check_def: $msg}
					return OB_ERR_OVS_QRY_FAIL
				}
			}
			default {
				ob_db::rs_close $res

				ob_log::write ERROR \
					{OVS: Unknown check class: $PROFILE($n,check_class)}
				return OB_ERR_OVS_INVALID_DATA
			}
		}

		set PROFILE($n,resp_count) [db_get_nrows $res2]
		ob_log::write DEBUG {OVS: Found $PROFILE($n,resp_count) check...}
		ob_log::write DEBUG {...responses for check $PROFILE($n,check_def_id)}

		for {set m 0} {$m < $PROFILE($n,resp_count)} {incr m} {

			if { $check_type == "OB_CARD_BIN"} {
				set bin_lo [db_get_col $res2 $m bin_lo]
				set bin_hi [db_get_col $res2 $m bin_hi]
				set lookup "${bin_lo}-${bin_hi}"

				#Initialise incase the passed ID is needed
				set PROFILE(OB_CARD_BIN,$PROFILE(card_bin,bin),id) [db_get_col $res2 $m id]
				set PROFILE(OB_CARD_BIN,$PROFILE(card_bin,bin),vrf_chk_def_id) [db_get_col $res2 $m check_id]
			} else {
				set lookup [db_get_col $res2 $m lookup]
			}

			
			foreach field {id score} {
				set PROFILE($check_type,$lookup,$field) \
					[db_get_col $res2 $m $field]
			}
		}
		ob_db::rs_close $res2
	}

	ob_db::rs_close $res

	return OB_OK
}



# Retrieves details of the provider to run the profile against. This
# is decided by the external provider definition tables (tVrfExt*)
# and not by the class of the check type.
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_get_profile_provider {} {

	variable PROFILE
	variable PROVIDERS

	foreach prov $PROVIDERS {
		set PROFILE($prov) 0
	}

	array set PROVIDER [list]

	set PROVIDER(profiles) [list]

	ob_log::write DEBUG {OVS: Required checks are $PROFILE(checks)}

	foreach chk $PROFILE(checks) {

		# Retrieve all the available external profiles that can
		# perform this check
		if {[catch {
			set res [ob_db::exec_qry ob_ovs::get_ext_profiles $chk]
		} msg]} {
			ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ext_profiles: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		set prfl_count [db_get_nrows $res]

		if {$prfl_count == 0} {
			ob_db::rs_close $res

			ob_log::write ERROR \
				{OVS: Found $prfl_count external profiles for check $chk: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		for {set i 0} {$i < $prfl_count} {incr i} {

			set pdef_id [db_get_col $res $i pdef_id]

			set PROVIDER($pdef_id,prfl_ext_id) \
				[db_get_col $res $i pdef_ext_id]
			set PROVIDER($pdef_id,prov_id) \
				[db_get_col $res $i prov_id]
			set PROVIDER($pdef_id,prov_priority) \
				[db_get_col $res $i prov_priority]

			if {[lsearch $PROVIDER(profiles) $pdef_id] == -1} {
				lappend PROVIDER(profiles) $pdef_id
			}
		}

		ob_db::rs_close $res
	}

	ob_log::write DEBUG {OVS: Available profiles are $PROVIDER(profiles)}

	set PROVIDER(multiple) [list]
	set PROVIDER(exact)    [list]
	set PROVIDER(partial)  [list]

	# Loop through all the profiles and get a list of all of their checks
	foreach pdef_id $PROVIDER(profiles) {

		if {[catch {
			set res [ob_db::exec_qry ob_ovs::get_ext_checks $pdef_id]
		} msg]} {
			ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ext_checks: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		set chk_count [db_get_nrows $res]

		if {$chk_count == 0} {
			ob_db::rs_close $res

			ob_log::write ERROR \
				{OVS: Found $chk_count external checks for profile $pdef_id: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		set PROVIDER($pdef_id,checks) [list]

		for {set i 0} {$i < $chk_count} {incr i} {
			lappend PROVIDER($pdef_id,checks) [db_get_col $res $i vrf_chk_type]
		}

		ob_db::rs_close $res

		# Scan the list of checks and see if we have any matches
		set req_matches [llength $PROFILE(checks)]
		set num_matches 0

		foreach chk $PROFILE(checks) {
			if {[lsearch $PROVIDER($pdef_id,checks) $chk] != -1} {
				incr num_matches
			}
		}

		if {$num_matches < $req_matches} {
			# We have matched less checks than the checks that we need
			# to run, so we would have to run multiple external profiles
			lappend PROVIDER(multiple) $pdef_id
		}

		if {$num_matches == $req_matches} {
			if {$num_matches == [llength $PROVIDER($pdef_id,checks)]} {
				# We have matched exactly the same number of external
				# as the number of checks we need to run, so we can use
				# this external profile.
				lappend PROVIDER(exact) $pdef_id
			} else {
				# We have matched all the checks, but there are more
				# checks in this profile, so we could use this profile
				# but some external checks are not required
				lappend PROVIDER(partial) $pdef_id
			}
		}
	}


	if {[llength $PROVIDER(exact)] > 0} {
		ob_log::write INFO {OVS: Exact external profiles are $PROVIDER(exact)}
	}
	if {[llength $PROVIDER(partial)] > 0} {
		ob_log::write INFO {OVS: Partial external profiles are $PROVIDER(partial)}
	}
	if {[llength $PROVIDER(multiple)] > 0} {
		ob_log::write INFO {OVS: Incomplete external profiles are $PROVIDER(multiple)}
	}

	# If we dont have exact matches then we want to throw an
	# error. We may have either partial or multiple matches.
	# We dont support either at the moment.
	if {[llength $PROVIDER(exact)] == 0} {
		if {[llength $PROVIDER(partial)] > 0} {
			return OB_ERR_OVS_PROV_PARTIAL
		} elseif {[llength $PROVIDER(multiple)] > 0} {
			return OB_ERR_OVS_PROV_MULTIPLE
		} else {
			return OB_ERR_OVS_PROV_NONE
		}
	}

	# Now figure out which of the exact matches has the
	# highest provider priority
	set best_pdef_id  -1
	set best_priority 1000

	foreach pdef_id $PROVIDER(exact) {
		if {$PROVIDER($pdef_id,prov_priority) < $best_priority} {
			set best_pdef_id  $pdef_id
			set best_priority $PROVIDER($pdef_id,prov_priority)
		}
	}

	if {$best_pdef_id == -1} {
		return OB_ERR_OVS_PROV_NONE
	}

	ob_log::write INFO {OVS: Using profile $best_pdef_id}

	set PROFILE(ext_profile_def_id) $best_pdef_id
	set PROFILE(ext_profile_id)     $PROVIDER($pdef_id,prfl_ext_id)

	set status [_set_ext_provider_connection $PROVIDER($best_pdef_id,prov_id) A]
	if {$status != "OB_OK"} {
		return $status
	}

	# Set the external check details for each check that
	# needs to be done. These are then recorded in tVrfChk.
	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_ext_check_def \
			$PROFILE(ext_profile_def_id) $PROFILE(profile_def_id)]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ext_chk_def: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set chk_count [db_get_nrows $res]

	for {set n 0} {$n < $chk_count} {incr n} {
		set PROFILE($n,ext_check_def_id) [db_get_col $res $n ext_check_def_id]
	}

	return OB_OK
}



# Given a profile that has already been run, retrieve the
# details of the provider it has been run against.
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_get_profile_provider_log {} {

	variable PROFILE

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_ext_prov $PROFILE(profile_id)]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_uru_check: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set prov_count [db_get_nrows $res]

	if {$prov_count != 1} {
		ob_db::rs_close $res

		ob_log::write ERROR \
			{OVS: Found $prov_count providers for profile $profile_id: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set prov_id [db_get_col $res 0 vrf_ext_prov_id]

	set status [_set_ext_provider_connection $prov_id L]
	if {$status != "OB_OK"} {
		return $status
	}

	return OB_OK
}



# Given a provider id and connection type (A = Authentication,
# L = Log) fill in the provider details in the PROFILE array
#
proc ob_ovs::_set_ext_provider_connection { prov_id conn_type } {

	variable PROFILE

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_ext_prov_conn $prov_id $conn_type]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_ext_prov_conn: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	if {[db_get_nrows $res] == 0} {
		ob_db::rs_close $res

		ob_log::write ERROR \
			{OVS: No valid connection parameters for provider $prov_id}
		return OB_ERR_OVS_QRY_FAIL
	}

	set PROFILE(provider_code)   [db_get_col $res 0 code]
	set PROFILE(provider_uname)  [db_get_col $res 0 uname]
	set PROFILE(provider_passwd) [db_get_col $res 0 password]
	set PROFILE(provider_action) [db_get_col $res 0 action]
	set PROFILE(provider_uri)    [db_get_col $res 0 uri]

	if {[string length $PROFILE(provider_passwd)]} {
		#decrypt the provider password
		set hex [OT_CfgGet OVS_DECRYPT_KEY_HEX]
		set pass_unenc [blowfish decrypt -hex $hex -hex $PROFILE(provider_passwd)]
		set pass_unenc [hextobin $pass_unenc]
		set PROFILE(provider_passwd) $pass_unenc
	}

	# Set the provider that will be executing this check
	set PROFILE($PROFILE(provider_code)) 1

	ob_db::rs_close $res

	return OB_OK
}



# Retrieves details of a prior verification from ProveURU
#
#	profile_id    - ID of profile to retrieve details for
#	uru_reference - Unique ID for verification at ProveURU
#
#	returns - {OB_OK data}|status
#		data - Array containing details of log response
#
proc ob_ovs::get_uru_log {profile_id uru_reference} {

	variable INITIALISED
	variable PROFILE
	variable PROVIDERS

	if {!$INITIALISED} {
		init
	}

	catch {unset PROFILE}
	array set PROFILE [get_empty]

	# Initialise all of the providers
	foreach prov $PROVIDERS {
		set PROFILE($prov) 0
	}

	if {[catch {
		set res [ob_db::exec_qry ob_ovs::get_uru_check $profile_id]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run query ob_ovs::get_uru_check: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set chk_count [db_get_nrows $res]

	if {$chk_count == 0} {
		ob_db::rs_close $res

		ob_log::write ERROR \
			{OVS: Found $chk_count URU checks for profile $profile_id: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	set PROFILE(profile_id)     $profile_id
	set PROFILE(profile_def_id) [db_get_col $res 0 profile_def_id]
	set PROFILE(query_ref)      $uru_reference
	set PROFILE(URU)            1
	set PROFILE(URU,checks)     [list]
	set PROFILE(check_count)    $chk_count
	set PROFILE(authentication_id) $uru_reference

	# Get the provider information
	# Retrieve the provider for the checks
	set status [_get_profile_provider_log]
	if {$status != "OB_OK"} {
		return $status
	}

	for {set i 0} {$i < $chk_count} {incr i} {
		set type  [db_get_col $res $i type]
		set code  [db_get_col $res $i response_no]
		set score [db_get_col $res $i score]
		if {[lsearch $PROFILE(URU,checks) $type] == -1} {
			lappend PROFILE(URU,checks) $type
		}
		set PROFILE($type,$code,score) $score
	}

	ob_db::rs_close $res

	if {$PROFILE(DATACASH)} {
		foreach {status data} [ob_ovs_dcash::run_log [array get PROFILE]] {
			break
		}
	}

	if {$PROFILE(PROVEURU)} {
		foreach {status data} [ob_ovs_proveuru::run_log [array get PROFILE]] {
			break
		}
	}

	if {$status != "OB_OK"} {
		return $status
	}

	array set PROFILE $data

	foreach element [lsort [array name PROFILE]] {
		ob_log::write DEV {OVS: **** $element = $PROFILE($element)}
	}

	return [list OB_OK $data]
}



# Totals the verification score and returns a corresponding result
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_score_check {} {

	variable PROFILE
	variable SCORE
	variable CLASSES

	# Scoring
	
	# Set weight
	set PROFILE(score)  $SCORE(weight)
	set PROFILE(weight) $SCORE(weight)

	# If any class score has been overridden increment the score
	foreach class $CLASSES {
		if {$SCORE(override,$class) && [info exists PROFILE($class,score)]} {

			incr PROFILE(score) $PROFILE($class,score)

			set PROFILE(override,$class) $PROFILE($class,score)

			ob_log::write DEBUG \
				{OVS: PROFILE($class,score) = $PROFILE($class,score)}
			ob_log::write DEBUG \
				{OVS: PROFILE(score) = $PROFILE(score)}
		}
	}

	# Loop through the checks
	for {set n 0} {$n < $PROFILE(check_count)} {incr n} {
		# If we didn't override this check total the score
		if {!$SCORE(override,$PROFILE($n,check_class))} {
			
			set check_type $PROFILE($n,check_type)
			set PROFILE($n,check_score) 0

			foreach response $PROFILE($check_type,responses) {

				if {[info exists PROFILE($check_type,$response,score)]} {
					incr PROFILE($n,check_score) \
						$PROFILE($check_type,$response,score)
				} else {
					ob_log::write ERROR \
						{OVS: Unknown response: $check_type $response}
					return OB_ERR_OVS_UNKNOWN_RESP
				}
			}

			incr PROFILE(score) $PROFILE($n,check_score)

		}
	}

	# Now check the actions to find out the result
	# Default is do nothing
	if {$PROFILE(action_count) == 0} {
		set PROFILE(result) N
	} else {
		for {set i 0} {$i < $PROFILE(action_count)} {incr i} {
			if {$PROFILE(score) > $PROFILE($i,high_score)} {
				set PROFILE(result) $PROFILE($i,action)
			} else {
				break
			}
		}
	}

	# Exceptions to the above rules, these must be exact score matches.
	for {set i 0} {$i < $PROFILE(exception_count)} {incr i} {
		if {$PROFILE(score) == $PROFILE($i,exception,score)} {
			set PROFILE(result) $PROFILE($i,exception,action)
		} else {
			break
		}
	}

	return OB_OK
}



# Stores details of complete verification in database
#
#	returns - status (OB_OK denotes success)
#
proc ob_ovs::_store_check {status manual_check {in_tran "N"} {upd_status 1}} {

	variable PROFILE

	if {[catch {
		# Store check profile
		ob_db::exec_qry ob_ovs::store_profile \
			$PROFILE(profile_def_id) \
			$PROFILE(cust_id) \
			[expr {$manual_check == "OB_MANUAL_CHECK" ? "M" : "A"}]

		set PROFILE(profile_id) [ob_db::get_serial_number "ob_ovs::store_profile"]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to run ob_ovs::store_profile: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}

	if {$PROFILE(profile_id) == ""} {
		ob_log::write ERROR \
			{OVS: Failed to retrieve profile ID from ob_ovs::store_profile}
		return OB_ERR_OVS_QRY_FAIL
	}

	# Store checks
	for {set n 0} {$n < $PROFILE(check_count)} {incr n} {

		set check_type $PROFILE($n,check_type)

		if {[catch {
			# Store check
			ob_db::exec_qry ob_ovs::store_check \
				$PROFILE(profile_id) \
				$PROFILE($n,check_def_id) \
				$check_type \
				$PROFILE($n,check_no) \
				$PROFILE($n,ext_check_def_id) \
				$PROFILE(prfl_model_id)

			set PROFILE($n,check_id) \
				[ob_db::get_serial_number "ob_ovs::store_check"]

		} msg]} {
			ob_log::write ERROR {OVS: Failed to run ob_ovs::store_check: $msg}
			return OB_ERR_OVS_QRY_FAIL
		}

		if {$PROFILE($n,check_id) == ""} {
			ob_log::write ERROR \
				{OVS: Failed to retrieve $n check ID from ob_ovs::store_check}
			return OB_ERR_OVS_QRY_FAIL
		}

		ob_log::write_array DEBUG PROFILE

		# Store the responses and their score
		foreach response $PROFILE($check_type,responses) {

			# Continue the check
			if {[info exists PROFILE($check_type,$response,score)]} {

				switch $PROFILE($n,check_class) {

					URU     {
						set qry "store_uru_check"
						set c [catch {
							ob_db::exec_qry ob_ovs::store_uru_check \
								$PROFILE($n,check_id) \
								$PROFILE($check_type,$response,id) \
								$PROFILE($check_type,$response,score) \
								$PROFILE(URU,reference)
						} msg]
					}

					IP      {
						set qry "store_ip_check"
						set c [catch {
							ob_db::exec_qry ob_ovs::store_ip_check \
								$PROFILE($n,check_id) \
								$PROFILE($check_type,$response,id) \
								$PROFILE($check_type,$response,score) \
								$PROFILE(IP,ip_country) \
								$PROFILE(country)
						} msg]
					}

					CARD    {
						if {$check_type == "OB_CARD_BIN"} {
							set qry "store_card_bin_check"
							set c [catch {
								ob_db::exec_qry ob_ovs::store_card_bin_check \
									$PROFILE($n,check_id) \
									$PROFILE($check_type,$response,id) \
									$PROFILE(card_bin,bin) \
									$PROFILE($check_type,$response,score)
							} msg]
						} else {
							set qry "store_card_check"
							set c [catch {
								ob_db::exec_qry ob_ovs::store_card_check \
									$PROFILE($n,check_id) \
									$PROFILE($check_type,$response,id) \
									$PROFILE($check_type,$response,score)
							} msg]
						}
					}

					GEN     {
						set qry "store_gen_check"
						set c [catch {
							ob_db::exec_qry ob_ovs::store_gen_check \
								$PROFILE($n,check_id) \
								$PROFILE($check_type,$response,id) \
								$PROFILE($check_type,$response,score)
						} msg]
					}

					AUTH_PRO {
						# Convert blank values to n/a
						set r_value $PROFILE($check_type,$response,value)
						if {![string length $r_value]} {
							set r_value "n/a"
						}

						set qry "store_auth_pro_check"
						set c [catch {
							ob_db::exec_qry ob_ovs::store_auth_pro_check \
								$PROFILE($n,check_id) \
								$PROFILE($check_type,$response,id) \
								$PROFILE($check_type,$response,score) \
								$r_value
						} msg]
					}

					default {
						ob_log::write ERROR \
							{OVS: Unknown class: $PROFILE($n,check_class)}
						return OB_ERR_OVS_INVALID_DATA
					}
				}

				if {$c} {
					ob_log::write ERROR {OVS: Failed to run query $qry: $msg}
					return OB_ERR_OVS_QRY_FAIL
				}
			} else {
				ob_log::write ERROR \
					{OVS: Unknown response: $check_type $response}
				return OB_ERR_OVS_UNKNOWN_RESP
			}
		}
	}

	# Pass the result through to the call back function that processes results
	# NB. Need to wrap the whole thing in a catch as we're still in a
	# transaction so need to be careful!

	if {$upd_status} {
		if {[catch {
			$PROFILE(callback) \
				$PROFILE(result) \
				$PROFILE(profile_id) \
				$PROFILE(cust_id) \
				$PROFILE(prfl_model_id) \
				$in_tran
		} msg]} {
			ob_log::write ERROR \
				{OVS: Error in callback function :$msg}
			return OB_ERR_OVS_CALLBACK
		}
	}

	if {![info exists PROFILE(user_id)]} {
		set PROFILE(user_id) {}
	}

	# Confirm the action taken
	if {[catch {
		# Store check
		ob_db::exec_qry ob_ovs::confirm_profile_action \
			$PROFILE(result) \
			{Action taken automatically}\
			$PROFILE(user_id)\
			$PROFILE(profile_id)
	} msg]} {

		ob_log::write ERROR \
			{OVS: Failed to run ob_ovs::confirm_profile_action: $msg}
		return OB_ERR_OVS_QRY_FAIL
	}
	return OB_OK
}
