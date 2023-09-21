# $Header: /cvsroot-openbet/training/openbet/shared_tcl/payment_ENVO.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Defines the standard procedures for handling a OnClick payment by envoy
# Payments currently implemented within OneClick:
#
# *   ->   one_click_gen.tcl
#
#  Procedures:
#  payment_ENVO::init
#  payment_ENVO::notify_payin
#  payment_ENVO::notify_confirm
#  payment_ENVO::get_pmt_id_from_reference
#  payment_ENVO::b10_to_b27                - compute the envoy base 27
#                                            algorithm for the reference code
#  payment_ENVO::b27_to_b10                - same as above, way round
#
#  payment_ENVO::do_wtd
#  payment_ENVO::get_envo_ewallet_detail   - from config
#  payment_ENVO::update_cpm
#
#  payment_ENVO::_prep_qrys

#
# Dependancies (standard packages)
#
package require net_socket
package require tdom


namespace eval payment_ENVO {
	variable INIT 0
	variable SQL
}


#-------------------------------------------------------------------------------
# Init function
#-------------------------------------------------------------------------------
proc payment_ENVO::init args {

	variable INIT

	set fn {payment_ENVO::init:}

	ob_log::write INFO {$fn Initialising payment_ENVO}

	if {$INIT} {
		return
	}

	_prep_qrys

	ob_log::write INFO {$fn payment_ENVO initialised}

	set INIT 1
}


#-------------------------------------------------------------------------------
# Prepare DB queries
#-------------------------------------------------------------------------------
proc payment_ENVO::_prep_qrys {} {

	global SHARED_SQL

	set fn {ob_one_click::_prep_qrys:}

	# Insert a new Envoy payment method
	set SHARED_SQL(payment_ENVO::insert_cpm) {
		execute procedure pCPMInsEnvoy (
			p_cust_id          = ?,
			p_oper_id          = ?,
			p_auth_dep         = ?,
			p_status_dep       = ?,
			p_disallow_dep_rsn = ?,
			p_auth_wtd         = ?,
			p_status_wtd       = ?,
			p_disallow_wtd_rsn = ?,
			p_envoy_key        = ?,
			p_additional_info1 = ?,
			p_transactional    = ?
		)
	}

	# Update an existing Envoy payment method
	set SHARED_SQL(payment_ENVO::update_cpm) {
		execute procedure pCPMUpdEnvoy (
			p_cpm_id           = ?,
			p_oper_id          = ?,
			p_auth_dep         = ?,
			p_status_dep       = ?,
			p_disallow_dep_rsn = ?,
			p_auth_wtd         = ?,
			p_status_wtd       = ?,
			p_disallow_wtd_rsn = ?,
			p_additional_info1 = ?,
			p_remote_ccy       = ?,
			p_transactional    = ?
		)
	}

	set SHARED_SQL(payment_ENVO::insert_sub_mthd) {
		execute procedure pCPMInsExtSubLink (
			p_cpm_id        = ?,
			p_sub_type_code = ?,
			p_transactional = ?
		)
	}

	# Insert a Envoy payment
	set SHARED_SQL(payment_ENVO::insert_pmt) {
		execute procedure pPmtInsEnvoy (
			p_acct_id         = ?,
			p_cpm_id          = ?,
			p_payment_sort    = ?,
			p_amount          = ?,
			p_status          = ?,
			p_ipaddr          = ?,
			p_source          = ?,
			p_oper_id         = ?,
			p_unique_id       = ?,
			p_transactional   = ?,
			p_ext_sub_link_id = ?,
			p_epacs_ref       = ?,
			p_pg_acct_id      = ?,
			p_pg_host_id      = ?,
			p_speed_check     = ?,
			p_receipt_format  = ?,
			p_receipt_tag     = ?,
			p_overide_min_wtd = ?,
			p_call_id         = ?
		)
	}

	# query used to get data to send to the payment non-card ticker
	set SHARED_SQL(payment_ENVO::get_payment_ticker_data) {
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
			ccy.exch_rate
		from
			tcustomer     c,
			tcustomerreg  cr,
			tacct         a,
			tCcy          ccy
		where
			a.acct_id   = ?            and
			a.cust_id   = cr.cust_id   and
			cr.cust_id  = c.cust_id    and
			a.ccy_code  = ccy.ccy_code
	}

	set SHARED_SQL(payment_ENVO::get_cpm_info) {
		select
			c.cust_id,
			a.acct_id,
			l.ext_sub_link_id,
			l.sub_type_code,
			cpm.cpm_id,
			cpm.status cpm_status,
			cpm.status_dep,
			c.cust_id,
			c.status cust_status,
			c.country_code,
			a.ccy_code,
			a.status as acct_status,
			cpm.auth_dep,
			cpm.auth_wtd
		from
			tExtSubCPMLink l,
			tCustPayMthd cpm,
			tCustomer c,
			tAcct a
		where
			l.ext_sub_link_id = ?
		and l.cpm_id          = cpm.cpm_id
		and cpm.cust_id       = c.cust_id
		and cpm.cust_id       = a.cust_id
	}

	set envoy_types_country_ccy_sql {
		select
			sp.desc,
			sp.sub_type_code
		from
			tExtPayMthd p,
			tExtSubPayMthd sp,
			tExtPayCountry c,
			tExtSubPayCCY  ccy
		where
			c.country_code         = ?
		and c.sub_type_code        = sp.sub_type_code
		and ccy.ccy_code           = ?
		and ccy.sub_type_code      = sp.sub_type_code
		and sp.ext_pay_mthd_id     = p.ext_pay_mthd_id
		and p.pay_mthd             = 'ENVO'
		and %s
	}

	set SHARED_SQL(payment_ENVO::get_envoy_types_allowed_for_country_ccy_DEP) \
		[format $envoy_types_country_ccy_sql "p.dep_allowed = 'Y' and sp.dep_allowed = 'Y'"]

	set SHARED_SQL(payment_ENVO::get_envoy_types_allowed_for_country_ccy_WTD) \
		[format $envoy_types_country_ccy_sql "p.wtd_allowed = 'Y' and sp.wtd_allowed = 'Y'"]

	set SHARED_SQL(payment_ENVO::update_pmt) {
		execute procedure pPmtUpdEnvoy (
			p_pmt_id = ?,
			p_status = ?
		)
	}

	set SHARED_SQL(payment_ENVO::update_pmt_with_epacs) {
		update
			tPmtEnvoy
		set
			epacs_ref = ?
		where
			pmt_id = ?
	}

	set SHARED_SQL(payment_ENVO::update_pmt_status) {
		execute procedure pPmtUpdStatus (
			p_pmt_id = ?,
			p_status = ?
		)
	}

	set SHARED_SQL(payment_ENVO::get_sub_mthd_info) {
		select
			xs.dep_allowed,
			xs.wtd_allowed
		from
			tExtSubPayMthd xs
		where
			xs.sub_type_code = ?
	}

	set SHARED_SQL(payment_ENVO::get_pmt_info) {
		select
			pe.ext_sub_link_id,
			l.sub_type_code,
			e.envoy_key,
			e.additional_info1,
			s.native_ccy,
			e.remote_ccy
		from
			tPmt p,
			tPmtEnvoy pe,
			tExtSubCPMLink l,
			tExtSubPayMthd s,
			tCPMEnvoy e
		where
			p.pmt_id           = ?                 and
			p.pmt_id           = pe.pmt_id         and
			pe.ext_sub_link_id = l.ext_sub_link_id and
			l.sub_type_code    = s.sub_type_code   and
			l.cpm_id           = e.cpm_id
	}

	set SHARED_SQL(payment_ENVO::get_envo_pmt_info) {
		select
			a.ccy_code as acct_ccy,
			c.acct_no
		from
			tPmt p,
			tAcct a,
			tCustomer c
		where
			p.pmt_id = ? and
			p.acct_id = a.acct_id and
			a.cust_id = c.cust_id
	}

	set SHARED_SQL(payment_ENVO::get_bank_pmt_info) {
		select
			a.ccy_code as acct_ccy,
			c.acct_no,
			c.country_code,
			NVL(b.bank_acct_name,'NA')    as bank_acct_name,
			NVL(b.ccy_code,a.ccy_code)    as bank_ccy,
			NVL(b.bank_acct_no,'NA')      as bank_acct_no,
			NVL(b.bank_name,'NA')         as bank_name,
			NVL(b.bank_sort_code,'NA')    as bank_sort_code,
			NVL(b.bank_branch_code,'NA')  as bank_branch_code,
			b.bank_addr_1,
			b.bank_addr_2,
			b.bank_addr_3,
			b.bank_addr_4,
			b.bank_addr_city,
			b.bank_addr_postcode,
			NVL(b.bank_acct_type,'NA')    as bank_acct_type,
			NVL(b.check_digits,'0')       as check_digits,
			NVL(b.iban_code,'0')          as iban_code,
			NVL(b.swift_code,'00000000')  as swift_code,
			NVL(b.additional_info1,'NA')  as additional_info1,
			NVL(b.additional_info2,'NA')  as additional_info2,
			NVL(b.additional_info3,'NA')  as additional_info3
		from
			tPmt p,
			tAcct a,
			tCustomer c,
			tCPMBank b
		where
			p.pmt_id = ? and
			p.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			p.cpm_id = b.cpm_id
	}
}


#-------------------------------------------------------------------------------
# Get details on a specific sub method
#-------------------------------------------------------------------------------
proc payment_ENVO::get_sub_mthd_info {
	sub_type
} {
	set fn "payment_ENVO::get_sub_mthd_info:"

	if {[catch {
		set rs [tb_db::tb_exec_qry payment_ENVO::get_sub_mthd_info \
			$sub_type]
	} err_msg]} {
		ob_log::write ERROR {$fn Failed to run get_sub_meth_info: $err_msg}
		return [list 0 $err_msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		set msg "Expected single row but found $nrows for $sub_type"
		ob_log::write ERROR {$fn $msg}
		db_close $rs
		return [list 0 $msg]
	}

	set dep_allowed     [db_get_col $rs 0 dep_allowed]
	set wtd_allowed     [db_get_col $rs 0 wtd_allowed]
	db_close $rs

	ob_log::write DEV {$fn Sucessfully got details on sub method -\
	   sub_type_code: $sub_type}

	return [list 1 $dep_allowed $wtd_allowed]
}


#-------------------------------------------------------------------------------
# Insert an Envoy CPM
#-------------------------------------------------------------------------------
proc payment_ENVO::insert_cpm {
	cust_id
	{dep_allowed N}
	{wtd_allowed N}
	{envoy_key ""}
	{additional_info1 ""}
	{oper_id ""}
	{transactional Y}
} {
	set fn "payment_ENVO::insert_cpm:"

	# set dep/wtd status
	switch -- $dep_allowed {
		Y {
			set auth_dep   "P"
			set dep_status "A"
			set dep_rsn    ""
		}
		N -
		default {
			set auth_dep   "N"
			set dep_status "S"
			set dep_rsn    "Envoy submethod doesn't allow deposits"
		}
	}

	switch -- $wtd_allowed {
		Y {
			set auth_wtd   "P"
			set wtd_status "A"
			set wtd_rsn    ""
		}
		N -
		default {
			set auth_wtd   "N"
			set wtd_status "S"
			set wtd_rsn    "Envoy submethod doesn't allow withdrawals"
		}
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry payment_ENVO::insert_cpm \
			$cust_id $oper_id $auth_dep $dep_status $dep_rsn $auth_wtd $wtd_status $wtd_rsn $envoy_key $additional_info1 $transactional]
	} err_msg]} {
		ob_log::write ERROR {$fn Failed to run insert_cpm: $err_msg}
		return [list 0 $err_msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		set msg "Expected single row but found $nrows for $cust_id"
		ob_log::write ERROR {$fn $msg}
		db_close $rs
		return [list 0 $msg]
	}

	set cpm_id     [db_get_coln $rs 0 0]
	set cpm_status [db_get_coln $rs 0 1]
	db_close $rs

	if {$cpm_status == "S"} {
		set msg "Inserted a Envoy method with cpm_id = $cpm_id, but it was immmediately suspended"
		ob_log::write INFO {$fn: $msg}
		return [list 2 $cpm_id]
	}

	ob_log::write INFO {$fn Sucessfully added new Envoy payment method -\
	   cpm_id: $cpm_id}

	return [list 1 $cpm_id]
}



#-------------------------------------------------------------------------------
# Update an Envoy CPM
#-------------------------------------------------------------------------------
proc payment_ENVO::update_cpm {
	cpm_id
	{dep_allowed ""}
	{wtd_allowed ""}
	{additional_info1 ""}
	{remote_ccy ""}
	{oper_id ""}
	{transactional Y}
} {
	set fn "payment_ENVO::update_cpm:"

	# set dep/wtd status
	# default settings preserve existing values
	switch -- $dep_allowed {
		Y {
			set auth_dep   "P"
			set dep_status "A"
			set dep_rsn    ""
		}
		N {
			set auth_dep   "N"
			set dep_status "S"
			set dep_rsn    "Deposits not allowed for this CPM"
		}
		default {
			set auth_dep   ""
			set dep_status ""
			set dep_rsn    "--"
		}
	}

	switch -- $wtd_allowed {
		Y {
			set auth_wtd   "P"
			set wtd_status "A"
			set wtd_rsn    ""
		}
		N {
			set auth_wtd   "N"
			set wtd_status "S"
			set wtd_rsn    "Withdrawals not allowed for this CPM"
		}
		default {
			set auth_wtd   ""
			set wtd_status ""
			set wtd_rsn    "--"
		}
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry payment_ENVO::update_cpm \
			$cpm_id $oper_id $auth_dep $dep_status $dep_rsn $auth_wtd $wtd_status $wtd_rsn $additional_info1 $remote_ccy $transactional]
	} err_msg]} {
		ob_log::write ERROR {$fn Failed to run update_cpm: $err_msg}
		return [list 0 $err_msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		set msg "Expected single row but found $nrows for $cpm_id"
		ob_log::write ERROR {$fn $msg}
		db_close $rs
		return [list 0 $msg]
	}

	set cpm_status [db_get_coln $rs 0 0]
	db_close $rs

	if {$cpm_status == "S"} {
		set msg "Updated Envoy method with cpm_id = $cpm_id, but it was suspended"
		ob_log::write INFO {$fn: $msg}
		return [list 2 $cpm_id]
	}

	ob_log::write INFO {$fn Sucessfully updated Envoy payment method, cpm_id: $cpm_id}

	return [list 1 $cpm_id]
}



#-------------------------------------------------------------------------------
# Insert a link between an Envoy cpm and a submethod
#-------------------------------------------------------------------------------
proc payment_ENVO::insert_sub_mthd {cpm_id sub_type_code {transactional "Y"}} {

	set fn "payment_ENVO::insert_sub_mthd:"

	if {[catch {set rs [tb_db::tb_exec_qry payment_ENVO::insert_sub_mthd \
	       $cpm_id $sub_type_code $transactional \
	]} err_msg]} {
		return [list 0 $err_msg]
	}

	set ext_sub_link_id [db_get_coln $rs 0 0]
	db_close $rs

	ob_log::write INFO {Sucessfully added new Envoy sub method,\
	   ext_sub_link_id: $ext_sub_link_id}

	return [list 1 $ext_sub_link_id]
}


#-------------------------------------------------------------------------------
# Insert an Envoy payment
#-------------------------------------------------------------------------------
proc payment_ENVO::insert_pmt {
	acct_id
	cpm_id
	ext_sub_link_id
	sub_type_code
	payment_sort
	amount
	epacs_ref
	ipaddr
	source
	unique_id
	ccy_code
	{pmt_status U}
	{transactional Y}
	{oper_id {}}
	{override_min_wtd N}
	{call_id ""}
} {
	set fn "payment_ENVO::insert_envoy_payment:"

	ob_log::write INFO {$fn ($acct_id,$cpm_id,$ext_sub_link_id,$payment_sort,\
	   $amount,$epacs_ref,$ipaddr,$source,$unique_id,$ccy_code,$pmt_status,\
	   $transactional,$oper_id,$override_min_wtd,$call_id)}

	variable PMT_DATA

	catch {array unset PMT_DATA}

	set PMT_DATA(pay_sort) $payment_sort
	set PMT_DATA(ccy_code) $ccy_code
	set PMT_DATA(pay_mthd) "ENVO"


	# Get the Envoy Payment Gateway Account details so we
	# know which Envoy merchant account the payment is affecting.
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]

	if {[lindex $pg_result 0] == 0} {
		set msg [lindex $pg_result 1]
		ob_log::write ERROR {$fn PMT Payment Rules Failed ; $msg}
		return [list 0 "ENVOY_FAILED_PMG_RULES"]
	}

	# Useful during debugging to be able to do lots of payments.
	if {[OT_CfgGetTrue DISABLE_PMT_SPEED_CHECK]} {
		set speed_check N
	} else {
		set speed_check Y
	}

	# Attempt to insert the payment
	if {[catch {set rs [tb_db::tb_exec_qry payment_ENVO::insert_pmt \
				$acct_id \
				$cpm_id \
				$payment_sort \
				$amount \
				$pmt_status \
				$ipaddr \
				$source \
				$oper_id \
				$unique_id \
				$transactional \
				$ext_sub_link_id \
				$epacs_ref \
				$PMT_DATA(pg_acct_id) \
				$PMT_DATA(pg_host_id) \
				$speed_check \
				[OT_CfgGet PMT_RECEIPT_FORMAT 0] \
				[OT_CfgGet PMT_RECEIPT_TAG   ""] \
				$override_min_wtd \
				$call_id \
	]} msg]} {
		ob_log::write ERROR {$fn Payment failed to insert - $msg}

		# Use PMG code to transform error into human readable form
		set err [payment_gateway::cc_pmt_get_sp_err_code $msg "PMT_ERR_INSERT_ENVO"]
		return [list 0 $err]
	} else {
		set pmt_id [db_get_coln $rs 0 0]
		db_close $rs

		# Send monitor message if monitors are configured on
		if {[OT_CfgGet MONITOR 0]} {

			set pmt_date [clock format [clock seconds] -format {%Y-%m-%d %T}]

			# Send the payment info to the Router
			_send_pmt_ticker $acct_id $pmt_id $sub_type_code $epacs_ref \
			                 $pmt_date $payment_sort $ccy_code $amount $source \
			                 $pmt_status $ipaddr

		}
		return [list \
			1 \
			$pmt_id \
			$PMT_DATA(client) \
			$PMT_DATA(password) \
			$PMT_DATA(host) \
			$PMT_DATA(conn_timeout) \
		]
	}
}


#-------------------------------------------------------------------------------
#  Updates an Envoy payment
#
#  pmt_id    - the ID of the payment
#  status    - the status of the payment
#  epacs_ref - envoy epacs reference
#
#  returns - 1 on successful update, [list 0 <err_msg] otherwise
#-------------------------------------------------------------------------------
proc payment_ENVO::update_pmt {pmt_id status {epacs_ref 0}} {

	set fn "payment_ENVO::update_pmt:"

	ob_log::write INFO {$fn ($pmt_id,$status,$epacs_ref)}

	if {$epacs_ref == 0} {
		if {[catch {
			tb_db::tb_exec_qry payment_ENVO::update_pmt $pmt_id $status
		} msg]} {
			ob_log::write ERROR {$fn Failed executing update_pmt - $msg}
			return [list 0 $msg]
		}
	} else {
		# We are just updating the epacs ref here!
		if {[catch {
			tb_db::tb_exec_qry payment_ENVO::update_pmt_with_epacs $epacs_ref $pmt_id
		} msg]} {
			ob_log::write ERROR {$fn Failed executing update_pmt_with_epacs - $msg}
			return [list 0 $msg]
		}
	}

	ob_log::write INFO {$fn payment $pmt_id update to $status successfully}

	return 1
}


#-------------------------------------------------------------------------------
#  Updates an Envoy payment status
#
#  Used to update payments to 'U' before performing withdrawals
#
#  returns - 1 on successful update, [list 0 <err_msg] otherwise
#-------------------------------------------------------------------------------
proc payment_ENVO::update_pmt_status {pmt_id status} {

	set fn "payment_ENVO::update_pmt_status:"

	ob_log::write INFO {$fn ($pmt_id,$status)}

	if {[catch {
		tb_db::tb_exec_qry payment_ENVO::update_pmt_status $pmt_id $status
	} msg]} {
		ob_log::write ERROR {$fn Failed executing update_pmt - $msg}
		return [list 0 $msg]
	}

	ob_log::write INFO {$fn payment $pmt_id update to $status successfully}

	return 1
}



#-------------------------------------------------------------------------------
#  Perform a eWallet or Bank Account withdrawal via Envoy
#
#  returns list, success state (1 for success) and message
#-------------------------------------------------------------------------------
proc payment_ENVO::do_wtd {
	acct_id
	pmt_id
	amount
	cpm_id
} {

	variable PMT_DATA
	variable VRFY

	catch {array unset PMT_DATA}
	catch {array unset VRFY}

	set fn "payment_ENVO::do_wtd:"

	ob_log::write INFO {$fn acct_id: $acct_id, pmt_id: $pmt_id}

	set PMT_DATA(pay_sort) "W"
	set PMT_DATA(pay_mthd) "ENVO"

	# Get the Envoy Payment Gateway Account details so we
	# know which Envoy merchant account the payment is affecting.
	set pg_result [payment_gateway::pmt_gtwy_get_msg_param PMT_DATA]

	if {[lindex $pg_result 0] == 0} {
		set msg [lindex $pg_result 1]
		ob_log::write ERROR {$fn PMT Payment Rules Failed: $msg}
		return [list 0 "ENVOY_FAILED_PMG_RULES"]
	}

	# What type of wtd is this? eWallets or Bank Xfer
	if {[catch {
		set rs [tb_db::tb_exec_qry payment_ENVO::get_pmt_info $pmt_id]
	} msg]} {
		ob_log::write ERROR {$fn Failed to run query get_pmt_info: $msg}
		return [list 0 "ENVOY_FAILED_PMT_INFO_1"]
	}

	set bank 0

	if {[db_get_nrows $rs] == 1} {
		set ext_sub_link_id   [db_get_col $rs 0 ext_sub_link_id]
		set sub_type_code     [db_get_col $rs 0 sub_type_code]
		set envoy_key         [db_get_col $rs 0 envoy_key]
		set envoy_login       [db_get_col $rs 0 additional_info1]
		set native_ccy        [db_get_col $rs 0 native_ccy]
		set remote_ccy        [db_get_col $rs 0 remote_ccy]
	} else {
		# No Envoy details where found for this payment
		# Treat this payment as a bank withdrawal
		set bank 1
	}

	db_close $rs


	# Depending on the sub_type_code, we need further details on this customer!
	if {!$bank} {

		if {[catch {
			set rs [tb_db::tb_exec_qry payment_ENVO::get_envo_pmt_info $pmt_id]
		} msg]} {
			ob_log::write ERROR {$fn Failed to run query get_envo_pmt_info: $msg}
			return [list 0 "ENVOY_FAILED_PMT_INFO_2A"]
		}

		if {[db_get_nrows $rs] == 0} {
			ob_log::write ERROR {$fn Failed to get required info on payment $pmt_id}
			return [list 0 "ENVOY_FAILED_PMT_INFO_2B"]
		}

		# Fast bank transfer doesn't have a native currency
		# This will never be called as FBT doesn't allow withdrawals,
		# but better to be safe than..
		if {$sub_type_code eq "ENFBT"} {
			set native_ccy [db_get_col $rs 0 acct_ccy]
		}

		# We'll send the unique ref across too
		set unique_ref [payment_ENVO::generate_cust_ref $ext_sub_link_id $native_ccy]


		# if add info type is REMOTE for this subpaymthd, we want to use the currency on tcpmenvoy instead
		set add_info_type [get_envo_ewallet_detail $sub_type_code add_info_type]
		if {$add_info_type == "REMOTE" && $remote_ccy != ""} {
			set target_ccy $remote_ccy
		} else {
			set target_ccy $native_ccy
		}

		set payment_details [list \
			countryCode       $envoy_key \
			payee             "NA" \
			sourceCurrency    [db_get_col $rs 0 acct_ccy] \
			sourceAmount      $amount \
			targetCurrency    $target_ccy \
			targetAmount      "0" \
			sourceOrTarget    "S" \
			merchantReference [db_get_col $rs 0 acct_no] \
			paymentReference  $pmt_id \
			uniqueReference   $unique_ref]

		set bank_details    [list \
			accountNumber     $envoy_login]

		# store response validation checks
		set VRFY(merch_ref) [db_get_col $rs 0 acct_no]
		set VRFY(pmt_ref)   $pmt_id

		db_close $rs

	} else {

		if {[catch {
			set rs [tb_db::tb_exec_qry payment_ENVO::get_bank_pmt_info $pmt_id]
		} msg]} {
			ob_log::write ERROR {$fn Failed to run query get_bank_pmt_info: $msg}
			return [list 0 "ENVOY_FAILED_PMT_INFO_2A"]
		}

		if {[db_get_nrows $rs] == 0} {
			ob_log::write ERROR {$fn Failed to get required info on payment $pmt_id}
			return [list 0 "ENVOY_FAILED_PMT_INFO_2B"]
		}

		set country_code  [db_get_col $rs 0 country_code]

		# We need to replace UK with GB for Envoy transactions
		if {$country_code == "UK"} {set country_code "GB"}

		set payment_details [list \
			countryCode       $country_code\
			payee             [db_get_col $rs 0 bank_acct_name] \
			sourceCurrency    [db_get_col $rs 0 acct_ccy] \
			sourceAmount      $amount \
			targetCurrency    [db_get_col $rs 0 acct_ccy] \
			targetAmount      "0" \
			sourceOrTarget    "S" \
			merchantReference [db_get_col $rs 0 acct_no] \
			paymentReference  $pmt_id \
			additionalInfo1   [db_get_col $rs 0 additional_info1] \
			additionalInfo2   [db_get_col $rs 0 additional_info2] \
			additionalInfo3   [db_get_col $rs 0 additional_info3]]

		set branch_address      "[db_get_col $rs 0 bank_addr_1],\
							[db_get_col $rs 0 bank_addr_2],\
							[db_get_col $rs 0 bank_addr_3],\
							[db_get_col $rs 0 bank_addr_4],\
							[db_get_col $rs 0 bank_addr_city]"

		# remove blank address fields
		set branch_address  [string map {" ," ""} $branch_address]

		set bank_details    [list \
			accountNumber     [db_get_col $rs 0 bank_acct_no] \
			bankName          [db_get_col $rs 0 bank_name] \
			bankCode          [db_get_col $rs 0 bank_sort_code] \
			branchCode        [db_get_col $rs 0 bank_branch_code] \
			branchAddress     $branch_address \
			accountType       [db_get_col $rs 0 bank_acct_type] \
			checkDigits       [db_get_col $rs 0 check_digits] \
			iban              [db_get_col $rs 0 iban_code] \
			swift             [db_get_col $rs 0 swift_code]]

		# store response validation checks
		set VRFY(merch_ref) [db_get_col $rs 0 acct_no]
		set VRFY(pmt_ref)   $pmt_id

		db_close $rs

	}


	# Now we got all the necessary info to send an Envoy request, let's
	# update the pmt status to 'U'
	set upd_status  [payment_ENVO::update_pmt_status $pmt_id "U"]
	if {[lindex $upd_status 0] == "0"} {
		return $upd_status
	}


	# Get all the details we need and buld the wtd XML request
	set authentication [list \
		username $PMT_DATA(client) \
		password $PMT_DATA(password)]

	set unique_ref  "${pmt_id}[clock scan now]"

	set request_ref [list \
		requestReference $unique_ref]

	set req_msg [list \
		authentication  $authentication \
		request_ref     $request_ref \
		payment_details $payment_details \
		bank_details    $bank_details]

	# Build the wtd XML - payToBankAccountV2
	set wtd_req [build_xml payToBankAccountV2 $req_msg]

	set parse_correct 0
	set doc ""

	# Try and contact envoy. If we get mangled XML back we will retry. We won't
	# retry for failed HTTP calls as that is dealt with by http_req
	for {set i 0} {$i < [OT_CfgGet HTTP_RETRY 3]} {incr i} {

		if {$i > 0} {
			ob_log::write INFO {$fn Retrying request to Envoy}
		}

		set res [payment_ENVO::http_req $wtd_req $PMT_DATA(host) $PMT_DATA(conn_timeout) "WTD"]

		if {[lindex $res 0] != "OK"} {
			ob_log::write ERROR {$fn Failed to contact Envoy to make\
				withdrawl pmt_id $pmt_id}

			# Change payment status back to 'P'
			set upd_status  [payment_ENVO::update_pmt_status $pmt_id "P"]
			if {[lindex $upd_status 0] == "0"} {
				return $upd_status
			}

			return [list 0 "CONTACT_TO_ENVOY_FAILED"]
		}

		# Attempt to parse the response
		if {[catch {set doc [dom parse [lindex $res 1]]} msg]} {
			ob_log::write ERROR {$fn error in response xml - $msg}
		} else {
			set parse_correct 1
			break
		}
	}

	if {!$parse_correct} {
		ob_log::write ERROR {$fn Failed to make withdrawal for pmt_id $pmt_id}

		# Change payment status back to 'P'
		set upd_status  [payment_ENVO::update_pmt_status $pmt_id "P"]
		if {[lindex $upd_status 0] == "0"} {
			return $upd_status
		}

		return [list 0 "ENVOY_RESPONSE_ERROR"]
	}

	# Verify the response XML
	set wtd_verification [_verify_wtd $doc]

	set success [lindex $wtd_verification 0]
	set msg     [lindex $wtd_verification 1]

	# If we got a successful response, update the epacs ref!
	# Note, we do not update the status to Y at this stage - only when
	# a notification from Envoy is returned from the Envoy App
	if {$success} {
		set response_epac "E1 - $VRFY(epacs_ref)"
		set res [payment_ENVO::update_pmt $VRFY(pmt_ref) U $response_epac]
	} else {
		set res [payment_ENVO::update_pmt_status $pmt_id N]
	}

	set success [lindex $res 0]

	# If the payment update failed..
	if {$success == 0} {

		# Change payment status back to 'P'
		set upd_status  [payment_ENVO::update_pmt_status $pmt_id "P"]
		if {[lindex $upd_status 0] == "0"} {
			return $upd_status
		}

		return [list 0 [lindex $res 1]]
	}

	return [list $success $msg]

}


#-------------------------------------------------------------------------------
# Verify the withdrawal response received
#-------------------------------------------------------------------------------
proc payment_ENVO::_verify_wtd {doc} {

	variable VRFY

	set fn "payment_ENVO::_verify_wtd:"

	set root [$doc documentElement]

	# First check the status
	if {[catch {
		set status_code [[[$root getElementsByTagName statusCode] firstChild] nodeValue]
		set status_msg  [[[$root getElementsByTagName statusMessage] firstChild] nodeValue]
	} msg] || $status_code eq "" || $status_msg eq ""} {
		ob_log::write ERROR {$fn Missing statusCode or statusMessage}
		return [list 0 "ENVOY_RESPONSE_ERROR_NO_STATUS"]
	}

	set first_child [_get_req_type [$root firstChild]]
	if {$first_child != "payToBankAccountV2Response"} {
		ob_log::write ERROR {$fn Invalid response received: $first_child}
		return [list 0 "ENVOY_RESPONSE_ERROR_INVALID_RESPONSE"]
	}

	# statusCode of 0 or more is a success
	if {$status_code < 0} {
		ob_log::write ERROR {$fn Received failure statusCode $status_code from\
		   Envoy. Status message: $status_msg}
		return [list 0 "ENVOY_RESPONSE_ERROR_ERROR_STATUS"]
	} else {
		ob_log::write INFO {$fn Received success statusCode $status_code from\
		   Envoy. Status message: $status_msg}
	}

	set missmatch [list]

	# Get the data from the request and compare it to the withdrawal data we
	# sent earlier
	foreach {node_name var_name} {
		epacsReference     epacs_ref
		merchantReference  merch_ref
		paymentReference   pmt_ref
	} {
		if {[catch {
			set node_vals  [$root getElementsByTagName $node_name]
			set node_val   [[[lindex $node_vals 0] firstChild] nodeValue]
		} msg] || $node_val eq ""} {
			ob_log::write ERROR {$fn Missing value for $node_name}
			return [list 0 "ENVOY_RESPONSE_NODE_NONEXISTENT"]
		}

		# Store the epacs ref for later use and
		# ensure the merch_ref and pmt_ref values match
		if {$var_name == "epacs_ref"} {
			set VRFY($var_name) $node_val
		} elseif {$VRFY($var_name) != $node_val} {
			lappend missmatch [list $var_name $VRFY($var_name) $node_val]
		}
	}

	if {[llength $missmatch] > 0} {
		ob_log::write ERROR {$fn field value missmatch found:\
		   [llength $missmatch] errors}
		foreach field_vals $missmatch {
			foreach {node_name old_val new_val} $field_vals {}
			ob_log::write ERROR {$fn Missmatch: $node_name: old_val $old_val\
			   new_val $new_val}
		}
		return [list 0 "ENVOY_RESPONSE_VERIFICATION_MISMATCH"]
	}

	ob_log::write INFO {$fn Withdrawal data verified correctly}
	return [list 1 "ENVOY_RESPONSE_SUCCESS"]

}


#-------------------------------------------------------------------------------
# Send a monitor message
#-------------------------------------------------------------------------------
proc payment_ENVO::_send_pmt_ticker {
	acct_id
	pmt_id
	sub_type_code
	epacs_ref
	pmt_date
	payment_sort
	ccy_code
	amount_user
	source
	pmt_status
	{ipaddr ""}
} {

	set fn "payment_ENVO::_send_pmt_ticker:"

	# Check if this message type is supported
	if {![string equal [OT_CfgGet MONITOR 0] 1] ||
	    ![string equal [OT_CfgGet PAYMENT_TICKER 0] 1]} {
		return 0
	}

	set pay_method "ENVO - $sub_type_code"

	if {[catch {set rs [tb_db::tb_exec_qry payment_ENVO::get_payment_ticker_data $acct_id]} msg]} {
		ob_log::write ERROR {$fn Failed to execute qry\
		   payment_ENVOY::get_payment_ticker_data : $msg}
		return 0
	}

	set cust_id       [db_get_col $rs cust_id]
	set username      [db_get_col $rs username]

	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set fname     [ob_cust::normalise_unicode [db_get_col $rs fname] 0 0]
		set lname     [ob_cust::normalise_unicode [db_get_col $rs lname] 0 0]
		set addr_city [ob_cust::normalise_unicode [db_get_col $rs addr_city] 0 0]
	} else {
		set fname     [db_get_col $rs fname]
		set lname     [db_get_col $rs lname]
		set addr_city [db_get_col $rs addr_city]
	}

	set postcode      [db_get_col $rs addr_postcode]
	set country_code  [db_get_col $rs country_code]
	set email         [db_get_col $rs email]
	set reg_date      [db_get_col $rs cust_reg_date]
	set reg_code      [db_get_col $rs code]
	set notifiable    [db_get_col $rs notifyable]
	set acct_balance  [db_get_col $rs balance]
	set addr_country  [db_get_col $rs addr_country]
	set exch_rate     [db_get_col $rs exch_rate]

	db_close $rs

	set bank_name "N/A"

	# convert user amount into system ccy
	set amount_sys [format "%.2f" [expr {$amount_user / $exch_rate}]]

	if {[catch {set result [MONITOR::send_pmt_non_card \
				$cust_id \
				$username \
				$fname \
				$lname \
				$postcode \
				$email \
				$country_code \
				$reg_date \
				$reg_code \
				$notifiable \
				$acct_id \
				$acct_balance \
				$addr_country \
				$addr_city \
				$pay_method \
				$ccy_code \
				$amount_user \
				$amount_sys \
				$pmt_id \
				$pmt_date \
				$payment_sort \
				$pmt_status \
				$epacs_ref \
				$bank_name \
				$source]} msg]} {
		ob_log::write ERROR {$fn Failed to send payment monitor message : $msg}
		return 0
	}

	return $result
}


#-------------------------------------------------------------------------------
# Retrieve all the info needed to validate and make a payment
#-------------------------------------------------------------------------------
proc payment_ENVO::get_cpm_info {ext_sub_link_id} {

	set fn "payment_ENVO::get_cpm_info:"

	if {[catch {
		set rs [tb_db::tb_exec_qry payment_ENVO::get_cpm_info $ext_sub_link_id]
	} msg]} {
		ob_log::write ERROR {$fn Failed to run query get_cpm_info: $msg}
		return [list ERROR "Invalid uniqueReference - customer query failed"]
	}

	if {[db_get_nrows $rs] == 0} {
		ob_log::write ERROR {$fn Could not find ext_sub_link_id $ext_sub_link_id}
		return [list ERROR "Invalid uniqueReference - customer not found"]
	}

	set cust_id      [db_get_col $rs 0 cust_id]
	set acct_id      [db_get_col $rs 0 acct_id]
	set cpm_id       [db_get_col $rs 0 cpm_id]
	set sub_type     [db_get_col $rs 0 sub_type_code]
	set cpm_status   [db_get_col $rs 0 cpm_status]
	set status_dep   [db_get_col $rs 0 status_dep]
	set cust_id      [db_get_col $rs 0 cust_id]
	set cust_status  [db_get_col $rs 0 cust_status]
	set country_code [db_get_col $rs 0 country_code]
	set acct_status  [db_get_col $rs 0 acct_status]
	set ccy_code     [db_get_col $rs 0 ccy_code]
	set ccy_code     [db_get_col $rs 0 ccy_code]
	set auth_dep     [db_get_col $rs 0 auth_dep]
	set auth_wtd     [db_get_col $rs 0 auth_wtd]

	db_close $rs

	return [list OK $cust_id $acct_id $cpm_id $sub_type $cpm_status $status_dep $auth_dep \
	$auth_wtd $cust_id $cust_status $country_code $acct_status $ccy_code]

}


#-------------------------------------------------------------------------------
# Returns a list of submethods allowed for a the customer's country and currency
# combination
#
# Returns: list of <sub_type_code> <desc>
#-------------------------------------------------------------------------------
proc payment_ENVO::get_envoy_types_allowed_for_country_ccy {txn_type ccy_code country_code} {

	if {[catch {
		set rs [ob_db::exec_qry payment_ENVO::get_envoy_types_allowed_for_country_ccy_${txn_type} $country_code $ccy_code]
	} msg]} {
		ob_log::write ERROR {Failed to run get_envoy_types_allowed_for_country_ccy_${txn_type}: $msg}
		return [list]
	}

	set nrows [db_get_nrows $rs]

	set ret [list]

	for {set i 0} {$i < $nrows} {incr i} {
		lappend ret [db_get_col $rs $i sub_type_code] [db_get_col $rs $i desc]
	}

	ob_db::rs_close $rs

	return $ret
}


#-------------------------------------------------------------------------------
# Check if the submethod can be used by the customer.
#
# Returns: 1 if so, 0 if not
#-------------------------------------------------------------------------------
proc payment_ENVO::check_sub_mthd_use_allowed {sub_type_code txn_type ccy_code country_code} {

	set avail_sub_types [get_envoy_types_allowed_for_country_ccy $txn_type $ccy_code $country_code]

	# Slightly paranoid way of doing this - an lsearch would work, but there is
	# a chance that it would match one of the descs... List is should be very
# 	# short anyway.
	foreach {sub_type desc} $avail_sub_types {
		if {$sub_type_code eq $sub_type} {
			return 1
		}
	}

	return 0

}


#-------------------------------------------------------------------------------
# Convert an integer into an Envoy base 27 number, using the Envoy algorithm
#
# code    - the code in base 10
#
# return  - number in base 27, envoy standards, padded with 0s to 7 char
#-------------------------------------------------------------------------------
proc payment_ENVO::b10_to_b27 {code} {
	set fn "payment_ENVO::b10_to_b27:"

	ob_log::write DEV {$fn The code is $code}
	set alphabet {0123456789ACEFGHJKMNPRTUWXY}
	set ret      ""
	while {$code > 0} {
		set  module  [expr {$code%27}]
		set  code    [expr {$code/27}]
		set  ret     [string index $alphabet $module]$ret
	}

	set ret [format "%07s" $ret]

	ob_log::write DEV {$fn returns $ret}

	return $ret
}


#-------------------------------------------------------------------------------
# Convert an Envoy base 27 number into an integer, using the Envoy algorithm
#
# code    - number in base 27, envoy standards
#
# return  - the code in base 10
#-------------------------------------------------------------------------------
proc payment_ENVO::b27_to_b10 {code} {

	set fn "payment_ENVO::b27_to_b10:"

	ob_log::write DEV {$fn The code is '$code'}

	set alphabet  {0123456789ACEFGHJKMNPRTUWXY}
	set ret       0
	set n_chars   [string length $code]
	for {set i 0} {$i < $n_chars} {incr i} {
		set  ret  [expr {
			round(
				$ret + \
				([string first [string index $code $i] $alphabet] * \
				pow(27,($n_chars - $i -1)))
			)}]
	}

	ob_log::write DEV {$fn returns $ret}
	return $ret
}


#-------------------------------------------------------------------------------
# Generate a Envoy customer reference
# A valid envoy reference (of ver. 1.5 of the doc) is :
# [3-char merchant ref][2-char ccy code][7-char ref to the user]
#
# The 7-char user ref is the ext_sub_link_id for the payment, encoded using the
# Envoy base 27 algorithm
#-------------------------------------------------------------------------------
proc payment_ENVO::generate_cust_ref {ext_sub_link_id ccy_code} {
	set fn "payment_ENVO::generate_cust_ref:"

	ob_log::write INFO {$fn link_id $ext_sub_link_id $ccy_code}

	# The ccy_code used as part of the cust ref is the first two characters of
	# the ISO alphabetic ccy code.
	set ccy_code [string range $ccy_code 0 1]

	set merchant_ref [OT_CfgGet ENVOY_MERCHANT_REF "WLH"]

	set cust_ref "${merchant_ref}${ccy_code}[b10_to_b27 $ext_sub_link_id]"

	tpBindString envoy_cust_ref $cust_ref

	ob_log::write DEV {$fn Generate Envoy Reference '$cust_ref'}

	return $cust_ref
}


#-------------------------------------------------------------------------------
# Build an xml string to send across. Quicker than using tdom.
#-------------------------------------------------------------------------------
proc payment_ENVO::build_xml {msg_type value_list} {

	set    header "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
	append header "<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
	append header " xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\""
	append header " xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">"
	append header "<soap:Body>"

	set    footer "</soap:Body>"
	append footer "</soap:Envelope>"

	switch -exact -- $msg_type {
		payInConfirmation {
			set    xml "$header"
			append xml "<payInConfirmation xmlns=\"http://merchantapi.envoyservices.com\">"
			append xml "<auth>"
			append xml "<username>[lindex $value_list 0]</username>"
			append xml "<password>[lindex $value_list 1]</password>"
			append xml "</auth>"
			append xml "<epacsReference>[lindex $value_list 2]</epacsReference>"
			append xml "</payInConfirmation>"
			append xml "$footer"
		}
		PaymentNotificationResponse {
			set    xml "$header"
			append xml "<PaymentNotificationResponse xmlns=\"http://apilistener.envoyservices.com\">"
			append xml "<PaymentNotificationResult>[lindex $value_list 0]</PaymentNotificationResult>"
			append xml "</PaymentNotificationResponse>"
			append xml "$footer"
		}
		PaymentOutNotificationResponse {
			set    xml "$header"
			append xml "<PaymentOutNotificationResponse xmlns=\"http://apilistener.envoyservices.com\">"
			append xml "<PaymentOutNotificationResult>[lindex $value_list 0]</PaymentOutNotificationResult>"
			append xml "</PaymentOutNotificationResponse>"
			append xml "$footer"
		}
		payToBankAccountV2 {
			foreach {param_type list} $value_list {
				set $param_type $list
			}

			set    xml "$header"
			append xml "<payToBankAccountV2 xmlns=\"http://merchantapi.envoyservices.com\">"
			append xml "<auth>"
			foreach {param value} $authentication {
				append xml "<${param}>${value}</${param}>"
			}
			append xml "</auth>"
			foreach {param value} $request_ref {
				append xml "<${param}>${value}</${param}>"
			}
			append xml "<paymentInstructions>"
			append xml "<paymentInstructionV2>"
			append xml "<paymentDetails>"
			foreach {param value} $payment_details {
				append xml "<${param}>${value}</${param}>"
			}
			append xml "</paymentDetails>"
			append xml "<bankDetails>"
			foreach {param value} $bank_details {
				append xml "<${param}>${value}</${param}>"
			}
			append xml "</bankDetails>"
			append xml "</paymentInstructionV2>"
			append xml "</paymentInstructions>"
			append xml "</payToBankAccountV2>"
			append xml "$footer"
		}
		InvalidRequest -
		default {
			set    xml "$header"
			append xml "<InvalidRequest>"
			append xml "<InvalidRequestMsg>[lindex $value_list 0]</InvalidRequestMsg>"
			append xml "</InvalidRequest>"
			append xml "$footer"
		}
	}

	return $xml
}


#-------------------------------------------------------------------------------
# Send an xml request
#
# Returns list, either "OK" or {"ERR" $err_code}
#-------------------------------------------------------------------------------
proc payment_ENVO::http_req {request url conn_timeout {req_type DEP}} {

	set fn "payment_ENVO::http_req:"

	ob_log::write INFO {$fn Attempting to send msg: \
	   [regsub {<password>.*</password>} $request "<password>*****</password>"]}

	ob_log::write INFO {$fn url = $url}

	set startTime [OT_MicroTime -micro]

	# Figure out where we need to connect to for this URL.
	if {[catch {
		foreach {api_scheme api_host api_port url_path junk junk} \
		  [ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn Badly formatted url: $msg}
		return [list ERR PMT_REQ_NOT_MADE]
	}

	if {$req_type == "DEP"} {
		set header_list [list \
			"Content-Type" "text/xml" \
			"SOAPAction"   "http://merchantapi.envoyservices.com/payInConfirmation" \
		]
	} else {
		set header_list [list \
			"Content-Type" "text/xml" \
			"SOAPAction"   "http://merchantapi.envoyservices.com/payToBankAccountV2" \
		]
	}

	# Construct the raw HTTP request.
	if {[catch {
		set http_req [ob_socket::format_http_req \
						-method     "POST" \
						-host       $api_host \
						-post_data  $request \
						-headers    $header_list \
						$url_path]
	} msg]} {
		ob_log::write ERROR {$fn Unable to build request: $msg}
		return [list ERR PMT_REQ_NOT_MADE]
	}

	# Cater for the unlikely case that we're not using HTTPS.
	set tls [expr {$api_scheme == "http" ? -1 : ""}]

	# Send the request to Envoy
	# NB: We're potentially doubling the timeout by using it as
	# both the connect and request timeout.
	if {[catch {
			foreach {req_id status complete} \
			[::ob_socket::send_req \
				-tls          $tls \
				-is_http      1 \
				-conn_timeout $conn_timeout \
				-req_timeout  $conn_timeout \
				$http_req \
				$api_host \
				$api_port] {break}
	} msg]} {
			# We can't be sure if anything reached the server or not.
			ob_log::write ERROR {$fn Request to Envoy failed: $msg}
			return [list ERR PMT_RESP]
	}

	set totalTime [format "%.2f" [expr {[OT_MicroTime -micro] - $startTime}]]
	ob_log::write INFO {$fn status=$status, Req Time=$totalTime seconds}

	if {$status != "OK"} {
		#
		# Distinguish between circumstances where req definitely wasn't made, and where it may have been.
		#
		if {[::ob_socket::server_processed $req_id] == 0} {
			# There's no way the server could have processed the request
			ob_log::write ERROR {$fn req status was $status, there's no way request reached Envoy}
			set ret [list ERR PMT_REQ_NOT_MADE]
		} else {
			# Request may or may not have reached Envoy, we don't know if it
			# was processed or not.  Return status so it can be handled appropriately
			ob_log::write ERROR {$fn req status was $status, the request may have reached Envoy}
			set ret [list ERR PMT_RESP]
		}

		# clean up
		::ob_socket::clear_req $req_id

		return $ret
	}

	# retrieve the XML response
	set xml_resp [::ob_socket::req_info $req_id http_body]
	set xml_resp [encoding convertfrom utf-8 $xml_resp]

	# clean up after ourselves
	::ob_socket::clear_req $req_id

	ob_log::write INFO {$fn RESPONSE: $xml_resp}

	return [list OK $xml_resp]
}


#-------------------------------------------------------------------------------
# Return the type of request
#-------------------------------------------------------------------------------
proc payment_ENVO::_get_req_type {root} {

	if {[$root getElementsByTagName "payToBankAccountV2Response"] != ""} {
		return "payToBankAccountV2Response"
	} else {
		return "UNKOWN_REQ"
	}

}


#-------------------------------------------------------------------------------
# Validate and return the ext_sub_link_id for a given unique ref
#
# Doesn't check that the ccy part of the code is valid - that would require a
# DB lookup on the customer.
#
# Returns:
#     [list OK ext_sub_link_id]
#  or
#     [list ERROR error_msg]
#-------------------------------------------------------------------------------
proc payment_ENVO::translate_cust_ref {cust_ref} {

	set fn "payment_ENVO::generate_cust_ref:"

	if {[string length $cust_ref] != 12} {
		ob_log::write ERROR {$fn Reference is invalid - wrong size}
		return [list ERROR "Invalid format"]
	}

	set merch_ref [string range $cust_ref 0 2]
	set b27_code  [string range $cust_ref 5 end]

	if {[OT_CfgGet ENVOY_VALIDATE_MERCHANT_REF 1]} {
		if {$merch_ref != [OT_CfgGet ENVOY_MERCHANT_REF WLH]} {
			ob_log::write ERROR {$fn Merchant reference $merch_ref is invalid}
			return [list ERROR "Merchant ref $merch_ref is invalid"]
		}
	}

	set re {^[0123456789ACEFGHJKMNPRTUWXY]+$}
	if {![regexp $re $b27_code]} {
		ob_log::write ERROR {$fn reference code $cust_ref failed regexp}
		return [list ERROR "Ref code $cust_ref failed regexp"]
	}

	return [list OK [b27_to_b10 $b27_code]]
}



#-------------------------------------------------------------------------------
# Returns the eWallet info for a given envoy sub pay method.
#
# Returns: <key> or <add_info>
#  e.g. "R1" for Moneta
#  or   "ACCT_NUM" for Moneta
#-------------------------------------------------------------------------------
proc payment_ENVO::get_envo_ewallet_detail {sub_type_code type} {

	set ewallet_info [OT_CfgGet ENVOY_EWALLET_INFO]

	foreach {code key add_info add_info_type add_info_regexp validation} $ewallet_info {
		if {$sub_type_code == $code} {
			switch -- $type {
				key             { return $key }
				add_info        { return $add_info }
				add_info_type   { return $add_info_type }
				add_info_regexp { return $add_info_regexp }
				validation      { return $validation }
				default         { return ""}
			}
		}
	}

	return ""
}
