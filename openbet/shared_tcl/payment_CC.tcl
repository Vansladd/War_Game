# $Id: payment_CC.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# Openbet
#
#
# Copyright (C) 2000 Orbis Technology Ltd. All rights reserved.
#
# ----------------------------------------------------------------------

#
# WARNING: file will be initialised at the end of the source
#

#
# requires payment_gateway.tcl
#

if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {
	package require fbets_fbets
	ob_fbets::init
}

package require pmt_validate
package require util_appcontrol

namespace eval payment_CC {

namespace export cc_pmt_init
namespace export cc_pmt_make_payment
namespace export cc_pmt_auth_payment
namespace export cc_pmt_3ds_auth

namespace export cc_pmt_get_data
namespace export cc_pmt_verify_and_record
namespace export cc_pmt_do_transaction
namespace export cc_pmt_auth_user
namespace export send_payment_ticker_msg

namespace export cc_pmt_mark_referred
namespace export cc_pmt_mark_later
namespace export cc_pmt_proc_auth

variable TW_CHECK

variable PMT_FLAGS
#  List of payment flags and default values if not present on the customer

set PMT_CUST_FLAGS {
	Skip3DSecure N
}


proc cc_pmt_init args {

	variable CFG
	variable TW_CHECK
	global SHARED_SQL
	variable 3DS_CFG
	variable PMT_CUST_FLAGS

	# grab a few configs
	set CFG(verbose_3ds_codes)      [OT_CfgGet PMT_STORE_VERBOSE_3DS_CODES 0]
	set CFG(3ds_policy_codes)       [OT_CfgGet 3DSECURE_RESUBMIT_POLICY_CODES 0]
	set CFG(3ds_resubmit_allowed)   [OT_CfgGet 3DSECURE_RESUBMIT_ALLOWED 0]
	set CFG(3ds_resubmit_conditions) [OT_CfgGet 3DSECURE_RESUBMIT_CONDITIONS {}]

	#  We need a key for 3D Secure transactions
	if {[set v [OT_CfgGet 3D_SECURE_CRYPT_KEY_HEX ""]] != ""} {
		set 3DS_CFG(key,val) $v
		set 3DS_CFG(key,type) hex
	} elseif {[set v [OT_CfgGet 3D_SECURE_CRYPT_KEY_BIN ""]] != ""} {
		set 3DS_CFG(key,val) $v
		set 3DS_CFG(key,type) bin
	} else {
		OT_LogWrite 3 "payment_CC::cc_pmt_init: Warning 3D_SECURE_CRYPT_KEY_HEX/BIN not specified"
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set CFG(pmt_receipt_format) 0
		set CFG(pmt_receipt_tag)    ""
	}

	#
	# Traceware checking enabled?
	#
	set TW_CHECK [OT_CfgGetTrue TW_CHECK]
	OT_LogWrite 5 "TW_CHECK enabled = $TW_CHECK"

	if {$TW_CHECK} {
		OT_LogWrite 5 "Initialising OB::country_check::init"
		OB::country_check::init
	}

	# BlueSquare now check tCardSchemeInfo
	if {[OT_CfgGet CHECK_SCHEME_ALLOWED 0]} {
		set SHARED_SQL(cc_chk_scheme_allowed) {
			select
				i.dep_allowed,
				i.wtd_allowed
			from
				tCardSchemeInfo i,
				tCardScheme s
			where
				s.bin_lo <= ? and
				s.bin_hi >= ? and
			s.scheme = i.scheme
		}
	}


	#
	# store queries
	#
	set SHARED_SQL(cc_pmt_insert_pmt) {
		execute procedure pPmtInsCC (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_extra_info = ?,
			p_transactional = ?,
			p_min_amt = ?,
			p_max_amt = ?,
			p_call_id = ?,
			p_j_op_type = ?,
			p_ref_no_offset = ?,
			p_speed_check = ?,
			p_locale = ?,
			p_prev_pmt_id = ?,
			p_receipt_format = ?,
			p_receipt_tag = ?,
			p_overide_min_wtd = ?
		)
	}

	set SHARED_SQL(cc_pmt_upd_pmt) {
		execute procedure pPmtUpdCC (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_j_op_type = ?,
			p_transactional = ?,
			p_auth_code = ?,
			p_gw_auth_code = ?,
			p_gw_uid = ?,
			p_gw_ret_code = ?,
			p_gw_ret_msg = ?,
			p_no_settle = ?,
			p_wtd_do_auth = ?,
			p_extra_info = ?,
			p_auto_fulfil = ?,
			p_fulfil_status = ?,
			p_gw_acq_bank = ?
		)
	}

	set SHARED_SQL(cc_pmt_upd_3ds) {
		execute procedure pPmtUpd3ds (
			p_pmt_id = ?,
			p_status = ?,
			p_gw_uid = ?,
			p_auth_type = ?
		)
	}

	set SHARED_SQL(cc_verify_3ds_cust) {
		select
			cpm.cust_id,
			pmt.payment_sort,
			pmt.amount,
			pmt.source,
			pmt.acct_id,
			a.ccy_code,
			ccpmt.auth_type,
			c.country_code,
			l.pmt_id as prev_pmt_id,
			ccpmt.enrol_3d_resp
		from
			tCpmCC cpm,
			tPmt pmt,
			outer tPmtRetryLink l,
			tAcct a,
			tPmtCC ccpmt,
			tCustomer c
		where
			pmt.cpm_id = cpm.cpm_id and
			pmt.acct_id = a.acct_id and
			pmt.pmt_id = ccpmt.pmt_id and
			pmt.pmt_id = ? and
			pmt.pmt_id = l.retry_pmt_id and
			cpm.cust_id = ? and
			a.cust_id = c.cust_id
	}

	set SHARED_SQL(cc_upd_3ds_stat) {
		update
			tPmt
		set
			status = ?
		where
			pmt_id = ?
	}

	#
	# get cust id for firing freebet triggers from referred payments
	#

	set SHARED_SQL(cc_pmt_get_cust_id) {
		select
			a.cust_id
		from
			tacct a,
			tpmt p
		where
			a.acct_id = p.acct_id and
			p.pmt_id = ?
	}

	#
	# to retrieve details of this card
	#
	set SHARED_SQL(cc_pmt_get_card) {
		select
			c.cpm_id,
			c.card_bin,
			c.enc_card_no,
			c.ivec,
			c.data_key_id,
			c.start,
			c.expiry,
			c.issue_no,
			c.enc_with_bin,
			m.type,
			c.hldr_name,
			a.acct_type
		from
			tcpmcc c,
			tcustpaymthd m,
			tacct a
		where
			m.cpm_id = c.cpm_id and
			m.cpm_id = ? and
			m.cust_id = a.cust_id

	}

	#
	# to retrieve cust_id
	#
	set SHARED_SQL(cc_pmt_acct_info) {
		select
			a.cust_id,
			a.ccy_code,
		    a.cr_date reg_date,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_postcode,
			r.addr_city,
			r.addr_country,
			r.email,
			r.telephone,
			c.country_code
		from
			tAcct a,
			tCustomerReg r,
			tCustomer c
		where
			  a.acct_id = ?
		  and a.cust_id = r.cust_id
		  and a.cust_id = c.cust_id
	}

	#
	# to retrieve postcode
	#
	set SHARED_SQL(cc_pmt_cust_pc) {
		select
			addr_postcode
		from
			tCustomerReg
		where
			cust_id = ?
	}

	#
	# to retrieve account no
	#
	set SHARED_SQL(cc_pmt_cust_acctno) {
		select
			c.acct_no
		from
			tCustomer c,
			tAcct a
		where
			a.cust_id = c.cust_id and
			a.acct_id = ?
	}


	#
	# retrieve the just stored apacs ref no
	#
	set SHARED_SQL(cc_pmt_get_apacs_ref) {
		execute procedure pPmtGetRefNo (
			p_pmt_id = ?
		);
	}

	#
	# card checking queries
	#
	set SHARED_SQL(cc_pmt_cust_card_allowed) {
		select
			allow_card
		from
			tCustomer
		where
			cust_id = ?
	}

	set SHARED_SQL(cc_pmt_card_block) {
		execute procedure pChkCardBlock (
			p_card_hash = ?,
			p_bin = ?
		)
	}


	set SHARED_SQL(cc_pmt_card_allowed) {
		execute procedure pChkCardAllowed (
			p_cust_id = ?,
			p_card_bin = ?,
			p_payment_sort = ?
		)
	}

	set SHARED_SQL(cc_pmt_vrfy_user) {
		select c.cust_id,
			   r.addr_postcode
		from   tCustomer c,
			   tCustomerReg r
		where  c.cust_id = r.cust_id and
			   c.cust_id = ? and (c.password = ? or c.bib_pin = ?)
	}

	set SHARED_SQL(cc_pmt_refer_allow) {
		execute procedure pPmtReferAllow (
			p_pmt_id        = ?,
			p_oper_id       = ?,
			p_transactional = ?,
			p_mode          = ?
		)
	}

	set SHARED_SQL(cc_pmt_no_response_allow) {
		execute procedure pPmtNoRespAllow (
			p_pmt_id        = ?,
			p_oper_id       = ?,
			p_transactional = ?,
			p_status        = ?
		)
	}

	#only allow an update to payment if it hasn't already been
	#marked as good or bad or settled
	set SHARED_SQL(cc_update_pmt_status) {
		execute procedure pPmtUpdStatus(
		   p_pmt_id = ?,
		   p_status = ?
		)
	}

	set SHARED_SQL(cc_update_enrol_3d_resp) {
		update tPmtCC set
			enrol_3d_resp = ?
		where
			pmt_id = ?
	}

	set SHARED_SQL(cc_update_auth_3d_resp) {
		update tPmtCC set
			auth_3d_resp = ?
		where
			pmt_id = ?
	}

	set SHARED_SQL(cc_update_pmtcc_info) {
		update tPmtCC set
			gw_auth_code = ?,
			gw_uid       = ?,
			gw_ret_code  = ?,
			gw_ret_msg   = ?,
			pg_host_id   = ?
		where
			pmt_id = ?
	}

	set SHARED_SQL(cc_pmt_update_pg_info) {
		update tPmtCC set
			pg_host_id = ?,
			pg_acct_id = ?,
			cp_flag = ?
		where
			pmt_id = ?
	}

	set SHARED_SQL(cc_pmt_update_fulfilled_at) {
		update tPmtCC set
			fulfilled_at = current
		where
			pmt_id = ?
	}

	# query used to get data to send to the deposit ticker
	set SHARED_SQL(cc_get_payment_ticker_data) {
		select
			c.cust_id,
			c.cr_date as cust_reg_date,
			c.country_code,
			c.username,
			c.notifyable,
			cr.fname,
			cr.lname,
			cr.email,
			cr.telephone,
			cr.code,
			c.acct_no,
			a.balance,
			a.ccy_code,
			cc.exch_rate,
			c.liab_group
		from
			tcustomer c,
			tcustomerreg cr,
			tacct a,
			tccy cc
		where
			c.cust_id = cr.cust_id and
			c.cust_id = a.cust_id and
			a.ccy_code = cc.ccy_code and
			a.acct_id = ?
	}

	# query to get number of failed deposits within last 24hours
	set SHARED_SQL(cc_get_fail_count) {
		select
			count(pmt_id) as count
		from
			tpmt p
		where
			p.cr_date > (current - interval (24) hour to hour) and
			p.status = 'N' and
			p.payment_sort = ? and
			p.acct_id = ?
	}

	# query to get number of credit cards used within last 24hours
	set SHARED_SQL(cc_get_card_count) {
		select
			count(distinct cpm_id) as count
		from
			tpmt p
		where
			p.cr_date > (current - interval (24) hour to hour) and
			p.ref_key = 'CC' and
			p.payment_sort = ? and
			p.acct_id = ?
	}
	# Count number of deposits made by a user
	set SHARED_SQL(pmt_dep_count) {
		select
			count(*) as total
		from
			tPmt p,
			tAcct a
		where
			p.acct_id = a.acct_id and
			p.payment_sort = 'D' and
			p.status = 'Y' and
			a.cust_id = ?
			and p.cr_date >= a.cr_date
	}

	if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
		set SHARED_SQL(payment_alert_mail) {
			insert into tAlertMail(alert_mail_type, alert_mail_subject, alert_mail_text)
			values (?,?,?)
		}
	}

	# Bring back any payment intercept
	if {[OT_CfgGet INTERCEPT_PMTS 0]} {
		set SHARED_SQL(pmt_intcpt_criteria) {
			select
				1
			from
				tPmtIntcptCcy ccy
			where
				ccy.status   = 'Y' and
				ccy.ccy_code = ?   and
				(
					ccy.int_all IN ('A',?) or
					exists
					(
						select
							1
						from
							tPmtIntcptBank  b,
							tPmtIntcptCntry cy,
							tPmtIntcptDefn  d,
							tCardInfo       c
						where
							d.ccy_code       =    ccy.ccy_code             and
							d.int_bank_id    =    b.int_bank_id            and
							d.int_country_id =    cy.int_country_id        and
							d.int_type       IN   ('A',?)                  and
							b.status         =    'Y'                      and
							cy.status        =    'Y'                      and
							c.card_bin       =    ?                        and
							c.bank           LIKE b.bank_string || '%'     and
							c.country        LIKE cy.country_string || '%'
					)
				)
		}
	}

	set SHARED_SQL(cc_pmt_mthd_has_resp_by_pmt_id) {
		select
			case when c.cvv2_resp is null or cvv2_resp = '' then
				0
			else
				1
			end as has_resp,
			c.cpm_id,
			c.type
		from
			tCPMCC c,
			tPmt p
		where
			c.cpm_id = p.cpm_id and
			p.pmt_id = ?
	}

	set SHARED_SQL(cc_update_cpm_cc_cvv2_resp) {
		update
			tCPMCC
		set
			cvv2_resp = ?
		where
			cpm_id = ?
	}

	# update cvv2 resp for each credit card payment
	# if it is configured on. Previous query just does so
	# for customer payment method registration.
	set SHARED_SQL(cc_update_pmt_cvv2_resp) {
		update
			tPmtCC
		set
			cvv2_resp = ?
		where
			pmt_id = ?
	}

	#
	#  Obtain information for a payment ID
	#
	#
	set SHARED_SQL(cc_pmt_get_pmt_info_sql) {
		select
			p.payment_sort,
			p.amount,
			p.commission,
			pcc.auth_type
		from
			tPmt p,
			tPmtCC pcc
		where
			p.pmt_id = pcc.pmt_id
			and p.pmt_id = ?
	}

	set SHARED_SQL(cc_update_pmt_cvv2_fraud) {
			update
				tPmtCC
			set
				cvv2_resp = ?,
				fraud_score = ?,
				fraud_score_source = ?
			where
				pmt_id = ?
	}

	#
	#  Obtain information for a payment ID
	#
	#
	set SHARED_SQL(cc_pmt_get_pmt_info_sql) {
		select
			p.payment_sort,
			p.amount,
			p.commission,
			pcc.auth_type
		from
			tPmt p,
			tPmtCC pcc
		where
			p.pmt_id = pcc.pmt_id
			and p.pmt_id = ?
	}

	set SHARED_SQL(cc_update_extra_info) {
		update
			tPmtCC
		set
			extra_info = ?
		where
			pmt_id = ?
	}

	#
	#  Get relevant customer flags
	#  that we might be interested in
	#  We specify the flags we are interested in
	#  here to avoid pulling back loads of data

	foreach {n def} $PMT_CUST_FLAGS {
		append sql_flags {'} $n {',}
	}

	set sql_flags [string range $sql_flags 0 end-1]

	set SHARED_SQL(cc_pmt_get_cust_flags) [subst {
		select
			flag_name,
			flag_value
		from
			tCustomerFlag
		where
			flag_name in ($sql_flags)
			and cust_id = ?
	}]

	set SHARED_SQL(cc_get_card_type) {
		select
			type
		from
			tCardSchemeInfo
		where
			scheme = ?
	}

	set SHARED_SQL(cc_get_pmt_3ds_codes) {
		select
			gw_ret_code,
			enrol_3d_resp,
			auth_3d_resp,
			gw_ret_msg
		from
			tPmtCC
		where
			pmt_id = ?
	}

}

proc cc_pmt_insert_payment {
	acct_id
	cpm_id
	pay_sort
	amount
	commission
	ip
	source
	oper_id
	unique_id
	extra_info
	transactional
	min_amt
	max_amt
	call_id
	j_op_type
	prev_pmt_id
	min_overide
} {

	#
	# The number returned by pGenApacsUID is padded with zeroes and prefixed
	# with a number from the config file.  This ensure that systems that use
	# different databases but talk to the same payment gateway don't overlap
	# payment reference numbers.
	#

	global _ref_no_offset
	variable CFG

	if {![info exists _ref_no_offset]} {
		set _ref_no_offset [OT_CfgGet REF_NO_PREFIX 1]
		#we'll make sure not to exceed the INT precision
		if {$_ref_no_offset == 1} {
			set offset_length 10
		} else {
			set offset_length 9
		}

		set pad_len [expr { $offset_length - [string length $_ref_no_offset] }]
		for {set i 0} {$i < $pad_len} {incr i} {
			append _ref_no_offset "0"
		}

		if {[string length $_ref_no_offset] > 10} {
			ob_log::write ERROR \
				{PMT Error generating ref_no_offset - too long $ref_no_offset}
			unset _ref_no_offset
			return [list 0 ""]
		}
	}

	#
	# Useful during debugging to be able to do lots of payments.
	#
	if { [OT_CfgGetTrue DISABLE_PMT_SPEED_CHECK] } {
		set speed_check N
	} else {
		set speed_check Y
	}

	# Is the locale configured.
	if {[lsearch [OT_CfgGet LOCALE_INCLUSION] PMT] > -1} {
		set locale [app_control::get_val locale]
	} else {
		set locale ""
	}

	if { [catch {
		set rs [tb_db::tb_exec_qry cc_pmt_insert_pmt \
			$acct_id \
			$cpm_id \
			$pay_sort \
			$amount \
			$commission \
			$ip \
			$source \
			$oper_id \
			$unique_id \
			$extra_info \
			$transactional \
			$min_amt \
			$max_amt \
			$call_id \
			$j_op_type \
			$_ref_no_offset\
			$speed_check\
			$locale \
			$prev_pmt_id \
			$CFG(pmt_receipt_format) \
			$CFG(pmt_receipt_tag) \

		]
	} msg] } {
		ob_log::write ERROR {PMT Error inserting payment record; $msg}
		return [list 0 $msg]
	}

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $rs 0 0]

	db_close $rs

	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] && $pay_sort == "D" } {

		if {[catch {
			set rs [tb_db::tb_exec_qry cc_pmt_get_cust_id $pmt_id]
		} msg]} {
			ob_log::write ERROR {PMT Error retrieving cust_id for payment: $msg}
		} else {
			set cust_id [db_get_col $rs 0 cust_id]
			db_close $rs
		}

		ob_camp_track::record_camp_action $cust_id DEP OB $pmt_id

	}

	return [list 1 $pmt_id]

}

proc cc_pmt_upd_3ds {
	pmt_id
	status
	gw_uid
	auth_type
} {

	if [catch {set 3drs [tb_db::tb_exec_qry cc_pmt_upd_3ds \
									$pmt_id \
									$status \
									$gw_uid \
									$auth_type \
									[OT_CfgGet DCASH_WTD_DO_AUTH N]]} msg] {

		ob_log::write ERROR {>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
		ob_log::write ERROR {Error updating 3ds payment record; $msg}
		ob_log::write ERROR {>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

		return [list 0 $msg PMT_ERR]
	}
	catch {db_close $3drs}

	return [list 1]
}


proc cc_pmt_auth_payment {
	pmt_id
	status
	oper_id
	transactional
	auth_code
	gw_auth_code
	gw_uid
	gw_ret_code
	gw_ret_msg
	ref_no
	j_op_type
	{no_settle 0}
	{extra_info ""}
	{payment_sort ""}
	{auto_fulfil ""}
	{fulfil_status "Y"}
	{gw_acq_bank ""}
} {

	set do_auth [OT_CfgGet DCASH_WTD_DO_AUTH N]

	if {$payment_sort == "E"} {
		set do_auth "Y"
	}

	if {[catch {
		tb_db::tb_exec_qry cc_pmt_upd_pmt \
			$pmt_id \
			$status \
			$oper_id \
			$j_op_type \
			$transactional \
			$auth_code \
			$gw_auth_code \
			$gw_uid \
			$gw_ret_code \
			$gw_ret_msg \
			$no_settle \
			$do_auth\
			$extra_info\
			$auto_fulfil\
			$fulfil_status\
			$gw_acq_bank
	} msg]} {

		ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}
		ob_log::write ERROR {PMT Error updating payment record; $msg}
		ob_log::write ERROR {PMT >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>}

		return [list 0 $msg PMT_ERR]
	}

	return [list 1]
}

#=================================================================
# Retrieve the card and account details from the database
#=================================================================
proc cc_pmt_get_data {ARRAY} {

	variable PMT_CUST_FLAGS

	upvar 1 $ARRAY DATA

	set DATA(ip) [reqGetEnv REMOTE_ADDR]

	#
	# retrieve the card details
	#
	if [catch {set rs [tb_db::tb_exec_qry cc_pmt_get_card $DATA(cpm_id)]} msg] {
		ob_log::write ERROR {PMT Error retrieving card details; $msg}
		return [list 0 "Could not retrieve card details: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_NOCARD] PMT_NOCARD]
	}

	set DATA(cpm_id)       [db_get_col $rs 0 cpm_id]
	set DATA(enc_card_no)  [db_get_col $rs 0 enc_card_no]
	set DATA(ivec)         [db_get_col $rs 0 ivec]
	set DATA(data_key_id)  [db_get_col $rs 0 data_key_id]
	set DATA(start)        [db_get_col $rs 0 start]
	set DATA(expiry)       [db_get_col $rs 0 expiry]
	set DATA(issue_no)     [db_get_col $rs 0 issue_no]
	set DATA(card_bin)     [db_get_col $rs 0 card_bin]
	set DATA(type)         [db_get_col $rs 0 type]

	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set DATA(hldr_name)  [ob_cust::normalise_unicode [db_get_col $rs 0 hldr_name]]
	} else {
		set DATA(hldr_name)  [db_get_col $rs 0 hldr_name]
	}

	set DATA(enc_with_bin) [db_get_col $rs 0 enc_with_bin]
	set DATA(acct_type)    [db_get_col $rs 0 acct_type]

	db_close $rs

	# Deal with card number
	set card_dec_rs [card_util::card_decrypt $DATA(enc_card_no) $DATA(ivec) $DATA(data_key_id)]

	if {[lindex $card_dec_rs 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db
		if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
			update_data_enc_status "tCPMCC" $DATA(cpm_id) [lindex $card_dec_rs 2]
		}

		ob_log::write ERROR {Error decrypting card details; [lindex $card_dec_rs 1]}
		return [list 0 "Error decrypting card details; [lindex $card_dec_rs 1]" PMT_ERR]
	} else {
		set dec_card [lindex $card_dec_rs 1]
		set DATA(card_no) [card_util::format_card_no $dec_card $DATA(card_bin) $DATA(enc_with_bin)]
	}

	set CARD_DATA [list]

	card_util::cd_get_req_fields $DATA(card_bin) CARD_DATA

	set DATA(card_scheme)       $CARD_DATA(scheme)
	set DATA(card_type)         $CARD_DATA(type)
	set DATA(country)           $CARD_DATA(country)
	set DATA(bank)              $CARD_DATA(bank)
	set DATA(card_bin)          $CARD_DATA(first_6)
	set DATA(threed_secure_pol) $CARD_DATA(threed_secure_pol)

	#
	# Account information
	#
	if [catch {set rs [tb_db::tb_exec_qry cc_pmt_acct_info $DATA(acct_id)]} msg] {
		ob_log::write ERROR {PMT Error retrieving account information; $msg}
		return [list 0 "Could not retrieve account information: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_NOCCY] PMT_NOCCY]
	}

	set DATA(ccy_code) [db_get_col $rs 0 ccy_code]
	set DATA(cust_id)  [db_get_col $rs 0 cust_id]

	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set DATA(fname)          [ob_cust::normalise_unicode [db_get_col $rs 0 fname] 0 0]
		set DATA(lname)          [ob_cust::normalise_unicode [db_get_col $rs 0 lname] 0 0]

		set DATA(addr_1)         [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_1] 0 0]
		set DATA(addr_2)         [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_2] 0 0]

		set DATA(addr_4)         [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_4] 0 0]
		set DATA(city)           [ob_cust::normalise_unicode [db_get_col $rs 0 addr_city] 0 0]
	} else {
		set DATA(fname)             [db_get_col $rs 0 fname]
		set DATA(lname)             [db_get_col $rs 0 lname]

		set DATA(addr_1)            [db_get_col $rs 0 addr_street_1]
		set DATA(addr_2)            [db_get_col $rs 0 addr_street_2]
		set DATA(addr_4)            [db_get_col $rs 0 addr_street_4]

		set DATA(city)              [db_get_col $rs 0 addr_city]
	}

	set DATA(reg_date)            [db_get_col $rs 0 reg_date]

	set DATA(addr_3)              [db_get_col $rs 0 addr_street_3]
	set DATA(postcode)            [db_get_col $rs 0 addr_postcode]
	set DATA(cntry)               [db_get_col $rs 0 addr_country]
	set DATA(telephone)           [db_get_col $rs 0 telephone]
	set DATA(email)               [db_get_col $rs 0 email]
	set DATA(cntry_code)          [db_get_col $rs 0 country_code]

	db_close $rs

	#  We need to pick up some customer flags
	#  mainly for 3D Secure but also for other stuff.
	#
	if [catch {set rs [tb_db::tb_exec_qry cc_pmt_get_cust_flags $DATA(cust_id)]} msg] {
		ob_log::write ERROR {Error retrieving account information; $msg}
		return [list 0 "Could not retrieve cust flags information: $msg" PMT_ERR]
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set name [db_get_col $rs $i flag_name]
		set value [db_get_col $rs $i flag_value]

		set cust_flags($name) $value
	}

	#  Now step through the required flags and fill out the defaults if flags aren't
	#  present
	foreach {name def} $PMT_CUST_FLAGS {
		if {[info exists cust_flags($name)]} {
			set DATA(cust_flag,$name) $cust_flags($name)
		} else {
			set DATA(cust_flag,$name) $def
		}
	}
	return [list 1]
}

proc cc_pmt_verify_and_record {ARRAY} {

	global DB
	variable TW_CHECK

	upvar 1 $ARRAY DATA

	set fn {cc_pmt_verify_and_record}

	ob_log::write DEBUG { => $fn}

	if {![info exists DATA(min_overide)]} {
		set DATA(min_overide) N
	}

	#
	# check this card is ok
	#
	if {$DATA(pay_sort) == "D" || $DATA(pay_sort) == "W"} {

		if {![cc_pmt_card_not_blocked $DATA(card_no) $DATA(cust_id)]} {

			ob_log::write ERROR {$fn Card not allowed (PMT_CC_BLOCKED)}
			set xl [payment_gateway::pmt_gtwy_xlate_err_code PMT_CC_BLOCKED]

			ob_log::write DEBUG { <= $fn}
			return [list 0 $xl PMT_CC_BLOCKED]
		}

		# Only do Traceware checking on deposits
		if {$TW_CHECK && $DATA(pay_sort) == "D"} {

			#
			# Postcode
			#
			if { [catch {
				set rs [tb_db::tb_exec_qry cc_pmt_cust_pc $DATA(cust_id)]
			} msg] } {
				ob_log::write ERROR \
					{$fn Error retrieving from tCustomerReg; $msg}

				ob_log::write DEBUG { <= $fn}
				return [list 0 \
					"Could not retrieve customer information: $msg" PMT_ERR]
			}

			if {[db_get_nrows $rs] != 1} {
				db_close $rs
				set xl [payment_gateway::pmt_gtwy_xlate_err_code PMT_NOCCY]

				ob_log::write DEBUG { <= $fn}
				return [list 0 $xl PMT_NOCCY]
			}

			set DATA(postcode) [db_get_col $rs 0 addr_postcode]
			db_close $rs

			set region_cookie [OB::AUTHENTICATE::retrieve_region_cookie]
			set cc [OB::AUTHENTICATE::authenticate \
				default \
				$DATA(source) \
				$DATA(cust_id) \
				update_cookie \
				0 \
				[reqGetEnv REMOTE_ADDR] \
				$region_cookie]
			OB::AUTHENTICATE::store_region_cookie [lindex $cc 2]

			if {[lindex $cc 0] != "S"} {
				ob_log::write ERROR {$fn Failed country check}
				set xl \
					[payment_gateway::pmt_gtwy_xlate_err_code PMT_CC_LOCATION]

				ob_log::write DEBUG { <= $fn}
				return [list 0 $xl PMT_CC_LOCATION]
			}

		}

		#
		# check whether card is allowed
		#
		if {!
			[cc_pmt_card_allowed $DATA(card_no) $DATA(cust_id) $DATA(pay_sort)]
		} {
			set xl [payment_gateway::pmt_gtwy_xlate_err_code PMT_CC_BLOCKED]

			ob_log::write DEBUG { <= $fn}
			return [list 0 $xl PMT_CC_BLOCKED]
		}

	} else {

		ob_log::write DEBUG { <= $fn}
		return [list 0 \
			[payment_gateway::pmt_gtwy_xlate_err_code PMT_TYPE] PMT_TYPE]
	}

	# Check if this pmt is a retry of another, provide a default if its not
	if {[info exists DATA(prev_pmt_id)] == 0} {
		set DATA(prev_pmt_id) ""
	}

	#
	# RiskGuardian
	#
	# Check if we should be sending payments to risk guardian on resubmits
	#
	if {$DATA(prev_pmt_id) == "" || [OT_CfgGet PMT_SEND_RESUBMITS_TO_RG 0]} {

		# check if enabled in config file and we have a deposit

		if {[OT_CfgGetTrue ENABLE_RISKGUARDIAN] && $DATA(pay_sort) == "D"} {

			set allow_txn [riskGuardian::do_check DATA]

			# get rid of the flag telling us we were doing a Risk Guardian request
			if {[info exists DATA(risk_guardian)]} {
				unset DATA(risk_guardian)
			}

			if {![OT_CfgGetTrue IGNORE_RISKGUARDIAN_REJECTS] && !$allow_txn} {
				ob_log::write DEBUG { <= $fn}
				return [list 0 \
					[riskGuardian::xlate_err_code PMT_RG_REFUSED] PMT_RG_REFUSED]
			}
		}
	} else {
		ob_log::write DEBUG {$fn skip risk guardian - payment is a resubmit}
	}

	#
	# insert the payment record
	#
	set result [cc_pmt_insert_payment $DATA(acct_id) \
	                                  $DATA(cpm_id) \
	                                  $DATA(pay_sort) \
	                                  $DATA(tPmt_amount) \
	                                  $DATA(commission) \
	                                  $DATA(ip) \
	                                  $DATA(source) \
	                                  $DATA(oper_id) \
	                                  $DATA(unique_id) \
	                                  $DATA(extra_info) \
	                                  $DATA(transactional) \
	                                  $DATA(min_amt) \
	                                  $DATA(max_amt) \
	                                  $DATA(call_id) \
	                                  $DATA(j_op_type) \
	                                  $DATA(prev_pmt_id) \
                                      $DATA(min_overide) \
	]

	if {![lindex $result 0]} {
		set code [payment_gateway::cc_pmt_get_sp_err_code [lindex $result 1]]

		ob_log::write DEBUG { <= $fn}
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
	}

	set DATA(pmt_id) [lindex $result 1]

	ob_log::write DEBUG { <= $fn}
	return [list 1]

}

##################################################################################
# Stores the cvv2 and fraud score responses against the payment. The cvv2 response
# also gets stored against the payment method, but only if this is the first time
# the card has been used
##################################################################################

proc update_pmt_fraud_cvv2 {pmt_id cvv2_resp fraud_score fraud_score_source} {

	# Firstly handle the cvv2 response for the CPM

	# Count the number of payments made with this payment method

	if {[catch {set rs [tb_db::tb_exec_qry cc_pmt_mthd_has_resp_by_pmt_id $pmt_id]} msg]} {
		ob_log::write ERROR {PMT Error getting ccv2 require; $msg}
		return
	}

	if {[db_get_nrows $rs] == 1} {
		set has_resp [db_get_col $rs 0 has_resp]
		set cpm_id   [db_get_col $rs 0 cpm_id]
		set type     [db_get_col $rs 0 type]

		if {!$has_resp && $type != "EN" && $type != "OP"} {
			if {[catch {set rs [tb_db::tb_exec_qry cc_update_cpm_cc_cvv2_resp $cvv2_resp $cpm_id]} msg]} {
				ob_log::write ERROR {PMT Error recording payment method cvv2 resp; $msg}
				return
			}
			if {[OT_CfgGet DCASH_XML 0]} {
				ob::DCASH::set_require_cvv2 0
			}
		}
	}

	db_close $rs

	# Now update the payment record with the cvv2 response and the fraud score
	if {[catch {
		tb_db::tb_exec_qry cc_update_pmt_cvv2_fraud \
			$cvv2_resp \
			$fraud_score \
			$fraud_score_source \
			$pmt_id
	} msg]} {
		ob_log::write ERROR {PMT Error recording payment cvv2 resp and fraud score: $msg}
		return
	}

	return
}

##################################################################################
# Procedure created to replace procedure now called cc_pmt_do_transaction_work
# Acts as a buffer between the app and cc_pmt_do_transaction_work to build payment
# ticker message.
# 3ds_auth (0|1) - Indicates whether this is being called to handle a customer who has been redirected
#                  off by 3D Secure to complete their authentication and has returned to the main site
#                  Basically we need to run the second half of the procedure that handles the
#                  return values as the business logic required is the same as if 3D Secure
#                  wasn;t used at all.
#
# Added for ladbrokes/bluesq by Justin Hayes 22/11/2001
##################################################################################
proc cc_pmt_do_transaction {ARRAY {3ds_pmt 0}} {

	upvar 1 $ARRAY DATA

	# call to the original cc_pmt_do_transaction procedure
	set resultList [cc_pmt_do_transaction_work DATA $3ds_pmt]

	if {![info exists DATA(REF_NO)]} {
		set DATA(REF_NO) ""
	}

	#
	# check if deposit ticker messages are to be sent
	#

	if {[OT_CfgGet PAYMENT_TICKER 0]} {

		send_payment_ticker_msg \
					$DATA(pmt_id) \
					$DATA(source) \
					$DATA(acct_id) \
					$DATA(amount) \
					$DATA(status) \
					$DATA(pay_sort) \
					$DATA(payment_date) \
					$DATA(payment_time) \
					$DATA(auth_date) \
					$DATA(auth_time) \
					$DATA(gw_auth_code) \
					$DATA(gw_ret_code) \
					$DATA(gw_ret_msg) \
					$DATA(REF_NO) \
					$DATA(hldr_name) \
					$DATA(cv2avs_status)
	}

	return $resultList
}

#
# Procedure previously named cc_pmt_do_transaction
proc cc_pmt_do_transaction_work {ARRAY 3ds_pmt} {

	variable CFG
	global FBDATA

	upvar 1 $ARRAY DATA

	set fn {cc_pmt_do_transaction_work}

	ob_log::write DEBUG { => $fn}

	# get the time payment started
	set time        [clock seconds]
	set DATA(payment_date) [clock format $time -format "%Y-%m-%d"]
	set DATA(payment_time) [clock format $time -format "%H:%M:%S"]

	#
	# set array variables to blanks for cases where payment exits before they
	# are created
	#
	set DATA(status)            " "
	set DATA(auth_date)         " "
	set DATA(auth_time)         " "
	set DATA(gw_auth_code)      " "
	set DATA(gw_ret_code)       " "
	set DATA(gw_ret_msg)        " "
	set DATA(gw_acq_bank)       " "
	set DATA(gw_redirect_url)   ""
	set DATA(auto_fulfil)		""
	set DATA(fulfil_status)		""

	#
	# for gateways who dont use cvv2 or fraud scoring
	#
	set DATA(cv2avs_status) ""
	set DATA(fraud_score)  ""
	set DATA(fraud_score_source) ""

	#
	# For gateways that may need to provide extra info for a response
	#
	set DATA(extra_info) ""

	if {![info exists DATA(fraud_score)]} {
		set DATA(fraud_score)  ""
	}
	if {![info exists DATA(fraud_score_source)]} {
		set DATA(fraud_score_source) ""
	}

	#
	# if the proc is called from cc_pmt_3ds_auth proc, only part of the proc
	# will be executed
	#
	if {$3ds_pmt == 0} {
		#
		# Get the correct payment gateway details for this payment
		#
		set pg_result [payment_gateway::pmt_gtwy_get_msg_param DATA]


		if {[lindex $pg_result 0] == 0} {
			set msg [lindex $pg_result 1]
			ob_log::write ERROR {$fn Payment Rules Failed ; $msg}
			set DATA(status) N
			#
			# update the payment table as failed payment
			#
			cc_pmt_auth_payment $DATA(pmt_id) \
								$DATA(status) \
								$DATA(oper_id) \
								$DATA(transactional) \
								$DATA(auth_code) \
								"" \
								"" \
								"" \
								"Payment Rules Failed : $msg" \
								"" \
								$DATA(j_op_type)

			return [list 0 "Payment Rules Failed : $msg" PMT_ERR $DATA(pmt_id)]
		}

		#
		# Withdrawal Delay gets applied if the payment is a withdrawal over a
		# gateway-specific threshold.
		# Gets used in customer screens (where cfg item WTD_DELAY is set).
		# Withdrawals via the admin screens won't be using delays and pass straight
		# through.
		#
		if {
			[OT_CfgGetTrue WTD_DELAY]
			&& $DATA(pay_sort) == "W"
			&& $DATA(delay_threshold) != ""
		} {
			#
			# Convert delay threshold into user's currency.
			#
			set rate [::OB_ccy::rate $DATA(ccy_code)]
			set threshold [format {%.2f} [expr {$DATA(delay_threshold) * $rate}]]

			if {$DATA(amount) > $threshold} {
				#
				# We will contact the payment gateway later (through a cron job) to
				# complete the payment and actually credit the users cc
				#
				ob::log::write INFO {$fn Withdrawal delay:\
					$DATA(ccy_code) $DATA(amount) > threshold $threshold}
				return [list 1 \
					[payment_gateway::pmt_gtwy_xlate_err_code PMT_DELAYED] \
					PMT_DELAYED]
			}

		}

		#
		# Withdrawal Delay gets applied if the payment is a wtd, scheme is MC and they have just played poker
		# Visa wtd's are delayed using ERP payments
		if {$DATA(pay_sort) == "W" && [OT_CfgGet USE_DCASH_XML 0] == 1 && [OT_CfgGet POKER_DELAY_WTD_ERP 0] == 1 && [lindex [card_util::get_card_scheme $DATA(card_bin)] 0] == "MC"} {

			# Check to see if the customer has played poker within the set time
			# frame and leave the payment as pending if so.
			# The pending MC payments are picked up later by a cron job

			# We need to checl if we have come from the cron job, if we have don't bother
			# trying to set the delay time again

			if {[payment_gateway::is_poker_delay $DATA(pmt_id)]} {
				ob::log::write INFO {$fn Withdrawal delay: MC poker delay: $DATA(pmt_id)}
				return [list 1 [payment_gateway::pmt_gtwy_xlate_err_code PMT_DELAYED] PMT_DELAYED]
			}

		}


		# now we have the pg_type we can determine the cvv2/avs policy to be
		# used with this transaction
		# note : Commidea, doesn't send a policy in the transaction, cvv2/avs
		# policy behaviour is handled after the transaction, however this check
		# is used to ensure the csc value is supplied when necessary

		if {[lsearch [list DCASHXML TMARQUE COMMIDEA] $DATA(pg_type)] > -1} {
			if {$DATA(pay_sort) == "D"} {

				set cvv2_list [payment_gateway::get_cvv2_policy\
					$DATA(cpm_id)\
					$DATA(amount)\
					$DATA(gateway_policy)\
				]

				ob::log::write DEBUG {$fn cvv2_list = $cvv2_list}

				if {[lindex $cvv2_list 0] == "OK"} {
					#no error
					set DATA(cvv2_needed) [lindex $cvv2_list 1]
					set cvv2_length       [lindex $cvv2_list 2]
					set DATA(policy_no)   [lindex $cvv2_list 3]
					set DATA(avs_needed)  [lindex $cvv2_list 4]

					if {$DATA(pg_type) == "TMARQUE" && $DATA(avs_needed) && !$DATA(cvv2_needed)} {
						# Trustmarque requires the cvv2 number to initiate the CVV2AVS check
						set DATA(cvv2_needed) 1
					}

					if {$DATA(cvv2_needed)} {
						if {$DATA(cvv2) == ""} {
							cc_pmt_auth_payment $DATA(pmt_id) \
												"N" \
												$DATA(oper_id) \
												$DATA(transactional) \
												$DATA(auth_code) \
												"" \
												"" \
												"" \
												"Cvv2 needed but not supplied" \
												"" \
												$DATA(j_op_type) \
												0 \
												"Failed before request was sent"
							return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_MISSING_CVV2] PMT_MISSING_CVV2 $DATA(pmt_id)]
						}
						if {![regexp "^\[0-9]\{$cvv2_length\}\$" $DATA(cvv2)]} {
							cc_pmt_auth_payment $DATA(pmt_id) \
												"N" \
												$DATA(oper_id) \
												$DATA(transactional) \
												$DATA(auth_code) \
												"" \
												"" \
												"" \
												"Invalid CVV2" \
												"" \
												$DATA(j_op_type) \
												0 \
												"Failed before request was sent"
							return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_ERR_CVV2] PMT_ERR_CVV2 $DATA(pmt_id)]
						}
					}
				} else {
					cc_pmt_auth_payment $DATA(pmt_id) \
										"N" \
										$DATA(oper_id) \
										$DATA(transactional) \
										$DATA(auth_code) \
										"" \
										"" \
										"" \
										"Error retrieving cvv2 details" \
										"" \
										$DATA(j_op_type) \
										0 \
										"Failed before request was sent"
					return [list 0 [lindex $cvv2_list 0] PMT_ERR_CVV2AVS $DATA(pmt_id)]
				}
			} else {
				# cvv2/avs check not performed for withdrawals
				set DATA(cvv2_needed) 0
				set DATA(avs_needed) 0
				set DATA(policy_no) ""
			}
		}


		#
		# Set the pg_host_id, pg_acct_id and cp_flag just prior to making the
		# payment
		#
		if { [catch {
			tb_db::tb_exec_qry cc_pmt_update_pg_info \
						$DATA(pg_host_id) \
						$DATA(pg_acct_id) \
						$DATA(cp_flag) \
						$DATA(pmt_id)
		} msg] } {

			ob_log::write ERROR \
				{$fn Error recording payment gateway parameters; $msg}

			return [list 0 "Could not record payment gateway parameters: $msg" \
				PMT_ERR $DATA(pmt_id)]

		}

		#
		# grab the apacs ref_no (generated during insert pmt)
		# and mark payment status as unknown
		#
		if { [catch {
			set rs [tb_db::tb_exec_qry cc_pmt_get_apacs_ref $DATA(pmt_id)]
		} msg] } {
			ob_log::write ERROR {$fn Error retrieving apacs ref; $msg}
			return [list 0 "Could not retrieve apacs ref: $msg" \
				PMT_ERR $DATA(pmt_id)]
		}

		set DATA(apacs_ref) [db_get_coln $rs 0 0]

		db_close $rs

		#
		# contact payment gateway
		#
		set result [payment_gateway::pmt_gtwy_do_payment DATA]

		# if we made an enrolment call, there will be an gateway specific return
		# code set, store it
		if {$CFG(verbose_3ds_codes) && [info exists DATA(enrol_3d_resp)]} {
			if { [catch {
				set rs [tb_db::tb_exec_qry cc_update_enrol_3d_resp \
				                           $DATA(enrol_3d_resp) \
				                           $DATA(pmt_id)\
				]
			} msg] } {
				ob_log::write ERROR {$fn Error updating enrolment resp; $msg}
				return [list 0 "Could not update enrolment response: $msg" \
				PMT_ERR $DATA(pmt_id)]
			}

			db_close $rs
		}

		#  Some code to handle 3D Secure follows.
		#  Some 3D secure responses indicate that we do not need to do a redirect
		#  and can submit the payment for authorisation immediatly.
		#  This is the responsability of the code block that follows - all it does is see if it
		#  can submit an suthorisation request immediately and  if so submits the request.
		#  It leaves the handling of the result of this second sumbission to the code that handles non-3d secure
		#  auhorisations as the business logic is almost identical.
		#
		#
		if {$result == "PMT_3DS_NO_SUPPORT" } {
			#  Note if we get this response it means that we won't benefit from 3D Secure protection
			#  so it is a business policy decision on whether we continue submitting the request or
			#  bail out. This policy is set in the array and can be set at a global level with a config
			#  setting and can also be overriden on a per-call basis.

			if {$DATA(3d_secure,policy,require_liab_prot)} {

				set DATA(auth_type) -
				set DATA(status) N
				set DATA(auth_date) ""
				set DATA(auth_time) ""

				#  Leave this to be handled further down

			} else {
				set DATA(auth_type) -

				#  Update the Payment record with various information

				cc_pmt_upd_3ds 	$DATA(pmt_id) \
								U \
								$DATA(gw_uid) \
								$DATA(auth_type)

				#  Submit the 3D Secure authorisation
				set result [payment_gateway::pmt_gtwy_3ds_auth DATA]
				#  We handle the result of this further down
			}

		} elseif {$result == "PMT_3DS_OK_DIRECT_AUTH" } {

			# Customer isn't enrolled hence the transaction will benefit from
			# 3D Secure protection
			set DATA(auth_type) N

			#  Update the Payment record with various information
			cc_pmt_upd_3ds 	$DATA(pmt_id) \
							U \
							$DATA(gw_uid) \
							$DATA(auth_type)

			#  Submit the 3D Secure authorisation
			set result [payment_gateway::pmt_gtwy_3ds_auth DATA]
			#  We handle the result of this further down
		} elseif {$result == "PMT_3DS_BYPASS" } {
			#  This indicates that we have bypassed the 3D Secure authorisation
			#  by specifying a parameter in the enrolment check call
			#  If we have manually bypassed the check then we must want to continue
			set DATA(auth_type) -

			#  Update the Payment record with various information
			cc_pmt_upd_3ds 	$DATA(pmt_id) \
							U \
							$DATA(gw_uid) \
							$DATA(auth_type)

			set result [payment_gateway::pmt_gtwy_3ds_auth DATA]
			#  We handle the result of this further down
		}

	} else {

			# grab the apacs ref_no (generated during insert pmt)
			# and mark payment status as unknown
			#
			if [catch {set rs [tb_db::tb_exec_qry cc_pmt_get_apacs_ref $DATA(pmt_id)]} msg] {
				ob_log::write ERROR {$fn Error retrieving apacs ref/updating payment status; $msg}
				return [list 0 "Could not retrieve apacs ref/update payment status: $msg" PMT_ERR $DATA(pmt_id)]
			}

			set apacs_ref                [db_get_coln $rs 0 0]
			set DATA(apacs_ref)          $apacs_ref

			db_close $rs
			#  Do the Auth call for 3D Secure here. Results should be handled using same
			#  code as non-3D secure auhorisations as business logic is similar.
			#  e.g. Intercepts etc...
			set result [payment_gateway::pmt_gtwy_3ds_auth DATA]
	}

	# if we made a seperate 3ds auth call, there will be an gateway specific
	# return code set, store it
	if {$CFG(verbose_3ds_codes) && [info exists DATA(auth_3d_resp)]} {
		if { [catch {
			set rs [tb_db::tb_exec_qry cc_update_auth_3d_resp \
										$DATA(auth_3d_resp) \
										$DATA(pmt_id)\
			]
		} msg] } {
			ob_log::write ERROR {$fn Error updating 3d auth resp; $msg}
			return [list 0 "Could not updating 3d auth response: $msg" \
			PMT_ERR $DATA(pmt_id)]
		}

		db_close $rs
	}

	ob_log::write INFO {$fn result: $result}
	set time [clock seconds]
	#
	# process the result
	#

	if {[OT_CfgGetTrue FUNC_LOG_CVV2_RESP]} {
		#
		# Update the payment method with the cvv2 response and fraud score.
		#
		update_pmt_fraud_cvv2 $DATA(pmt_id) \
							  $DATA(cv2avs_status) \
							  $DATA(fraud_score) \
							  $DATA(fraud_score_source)
	}

	set DATA(message) ""

	if {$result == "PMT_RESP" || $result == "ERR_SC_UNKNOWN"} {

		#
		# send alert email for bluesq
		#
		if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
				send_U_trans_alert DATA
		}

		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $result] \
			$result $DATA(pmt_id)]

	} elseif {$result == "OK"} {

		#
		# For certain OpenBet Customers, a CV2 code check failure should result
		# in the relevant deposit being cancelled. (Banks will authorise
		# deposits with incorrect CV2 code). Certain Customers may also want
		# AVS (Address Verification Service) failures to result in the
		# transaction being declined
		#

		if {
			$DATA(pay_sort) == "D" && $DATA(pg_type) != "DCASHXML" &&
			(([OT_CfgGetTrue CANCEL_DEP_ON_CV2_FAIL] && [_cv2_code_failure $DATA(cv2avs_status)]) ||
			([OT_CfgGetTrue CANCEL_DEP_ON_AVS_FAIL] && [_avs_code_failure $DATA(cv2avs_status)]))
		} {

			if {$DATA(pg_type) == "COMMIDEA"} {
				#
				# Commidea special case - don't bother with the cancellation
				# attempt. Simply mark the payment as BAD.

				ob_log::write INFO {$fn : Deposit cancelled}

				#
				# Deposit cancelled, so set status to Bad
				#
				set DATA(status) N
				set DATA(auth_date) " "
				set DATA(auth_time) " "
				set DATA(extra_info) {Customer's deposit has been cancelled\
					due to failed CV2/AVS check}

				# Notice we DONT set auto fulfilment to Y, the payment confirmer
				# must pick up this payment and cancel it

				set result PMT_DECL
			} else {
				set DATA(pay_sort) "X"

				ob_log::write INFO {$fn : Cancelling deposit because of failed CV2AVS check}

				#
				# The payment gateway interfaces will need to implement a cancel
				# method in response to the pay_sort X. If not, this will fail and
				# the status of the transaction will remain as U.
				#
				set result [payment_gateway::pmt_gtwy_do_payment DATA]

				if {$result != "PMT_DECL"} {

					#
					# Failed to cancel the deposit, so return relevant error code
					#
					ob_log::write INFO {$fn result of cancellation attempt: $result}
					set extra_info {Failed to cancel payment after deposit failed\
						CV2/AVS check,this payment needs to be handled manually}

					#
					# Inform administrator that this payment will need to manual
					# settled as failed to cancel payment
					#
					if { [catch {
						set rs [tb_db::tb_exec_qry \
							cc_update_extra_info $extra_info $DATA(pmt_id)]
					} msg] } {
						ob_log::write ERROR {$fn failed to update_extra_info: $msg}
					}

					return [list \
						0 \
						[payment_gateway::pmt_gtwy_xlate_err_code $result] \
						$result \
						$DATA(pmt_id)]

				} else {

					ob_log::write INFO {$fn : Deposit successfully cancelled}

					#
					# Deposit successfully cancelled, so set status to Bad
					#
					set DATA(status) N
					set DATA(auth_date) " "
					set DATA(auth_time) " "
					set DATA(extra_info) {Customer's deposit has been cancelled\
						due to failed CV2/AVS check}
					set result PMT_DECL
				}
			}
		} elseif {$DATA(pg_type) == "COMMIDEA"} {
			# if it's a withdrawal through commidea, auto fulfil it
			# so that it gets processed and authed automatically
			if {[OT_CfgGet COMMIDEA_OFFLINE_WTD 0] && $DATA(pay_sort) == "W"} {
				set DATA(auto_fulfil)   {Y}
				set DATA(fulfil_status) {N}
			} else {
				set DATA(auto_fulfil)   {N}
				set DATA(fulfil_status) {Y}
			}

			set DATA(status) Y
			set DATA(auth_date) [clock format $time -format "%Y-%m-%d"]
			set DATA(auth_time) [clock format $time -format "%H:%M:%S"]
		} elseif {[info exists DATA(leave_pending)]} {
			ob_log::write DEBUG {$fn Bibit Withdrawal - leave status as pending}
			ob_log::write DEBUG {<= $fn}
			set DATA(status) U

		} else {

			set DATA(status) Y
			set DATA(auth_date) [clock format $time -format "%Y-%m-%d"]
			set DATA(auth_time) [clock format $time -format "%H:%M:%S"]

		}

	} elseif {$result == "PMT_NO_PAYBACK_ACC"} {

		#
		# Special case for trustmarque - txn ok but more info about card type
		# needed
		#
		set DATA(status) Y
		set DATA(auth_date) [clock format $time -format "%Y-%m-%d"]
		set DATA(auth_time) [clock format $time -format "%H:%M:%S"]
		set DATA(message) "PMT_NO_PAYBACK_ACC"

	} elseif { $result == "PMT_URL_REDIRECT" } {

		#
		# Special case for Ventmear and Bibit - need to perform redirect.
		# Ventmear and Bibit will deal with updating the pmt appropriately.
		#
		return [list 1 [list PMT_URL_REDIRECT $DATA(gw_redirect_url)] ]
	} elseif {$result == "PMT_3DS_OK_REDIRECT" } {

		# Indicate that the customer is enrolled
		set DATA(auth_type) Y
		set DATA(status)    W
		set DATA(auth_date) ""
		set DATA(auth_time) ""

		# update status and auth type
		cc_pmt_upd_3ds  $DATA(pmt_id) \
						$DATA(status) \
						$DATA(gw_uid) \
						$DATA(auth_type)

		3ds_arr_copy_from ret_3ds DATA
		3ds_arr_set_pmt_info ret_3ds $DATA(pmt_id) $DATA(cust_id)

		ob::log::write INFO {$fn returning ret_3ds Array}

		return [list 0 $ret_3ds(pmt_id) PMT_3DS_OK_REDIRECT [array get ret_3ds]]

	} else {
		# Transaction is bad
		set DATA(status)    N
		set DATA(auth_date) " "
		set DATA(auth_time) " "

		if {$DATA(pg_type) == "COMMIDEA" && $result != "PMT_REFER"} {
			# work around to handle Commidea's payment confirmer
			# automatically fulfil bad payments in the db as long as they aren't
			# refers, these have to be picked up by the payment confirmer
			set DATA(auto_fulfil) {Y}
		}
	}

	if {($DATA(status) != "Y" && $result == "PMT_REFER" && $DATA(admin)) || [info exists DATA(leave_pending)]} {
		set no_settle 1
	} else {
		set no_settle 0
	}

	#
	# update the payment table whatever the response
	#
	cc_pmt_auth_payment \
		$DATA(pmt_id) \
		$DATA(status) \
		$DATA(oper_id) \
		$DATA(transactional) \
		$DATA(auth_code) \
		$DATA(gw_auth_code) \
		$DATA(gw_uid) \
		$DATA(gw_ret_code) \
		$DATA(gw_ret_msg) \
		$DATA(apacs_ref) \
		$DATA(j_op_type) \
		$no_settle\
		$DATA(extra_info)\
		$DATA(pg_trans_type)\
		$DATA(auto_fulfil)\
		$DATA(fulfil_status)\
		$DATA(gw_acq_bank)

	if {[info exists DATA(cv2avs_status)] && $DATA(cv2avs_status) != ""} {
		if {[catch {
			tb_db::tb_exec_qry cc_update_pmt_cvv2_resp \
					$DATA(cv2avs_status) \
					$DATA(pmt_id)
		} msg]} {
			ob_log::write ERROR {Error updating cvv2_resp for CC Pmt $DATA(pmt_id) : $msg}
		}
	}

	if {$DATA(status) != "Y" && ![info exists DATA(leave_pending)]} {

		# 3DSecure Resubmission Detection
		if {[cc_pmt_resubmission_detection $DATA(pmt_id) \
			                               $DATA(prev_pmt_id) \
			                               $DATA(status) \
			                               $DATA(pg_type) \
			                               $DATA(threed_secure_pol)]} {
			# Resubmit! attempt the payment again bypassing 3dsecure
			ob_log::write INFO {$fn resubmit without 3D Secure required}

			# cc_pmt_make_payment or cc_pmt_3ds_auth will pick up a 2 as a
			# resubmit
			return [list 2 $DATA(pmt_id)]
		}

		ob_log::write INFO {$fn resubmit not required}

		#
		# Some declined or referred payments are due to the banks refusing
		# transactions from online gambling sources
		#
		if {[OT_CfgGetTrue INTERCEPT_PMTS] && $result!="PMT_3DS_VERIFY_FAIL"} {

			set failure ""

			#
			# Pull out the failure condition and card info
			#
			if {$result == "PMT_DECL"} {
				set failure D
			} elseif {$result == "PMT_REFER"} {
				set failure R
			} else {
				ob::log::write INFO {$fn result is neither PMT_DECL nor\
					PMT_REFER ($result): failure code will not be set}
			}

			set ccy      $DATA(ccy_code)
			set card_bin [string range $DATA(card_no) 0 5]

			#
			# Perform intercept query
			#
			if {[catch {
				set rs [tb_db::tb_exec_qry pmt_intcpt_criteria \
					$ccy \
					$failure \
					$failure \
					$card_bin]
			} msg]} {
				#
				# Proceed as if no intercept
				#
				ob_log::write ERROR \
					{$fn Error retrieving payment intercept info : $msg}
			} else {
				#
				# See if we have found an intercept definition.
				#
				if {[db_get_nrows $rs] > 0} {
					#
					# Return intercept data
					#
					ob_log::write INFO {$fn Payment eligible for intercept.}
					return [list 0 \
						"Payment intercepted - offer to process offline" \
						PMT_INTERCEPT $DATA(pmt_id) $failure]
				} else {
					ob_log::write DEBUG {$fn Intercept query returned no rows -\
						treat as normal payment failure.}
				}
			}
		}

		#
		# Not an intercept condition - just a regular failure
		#
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $result] \
			$result $DATA(pmt_id)]

	} elseif {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		## For some reason check_action has aff_id as an optional
		## parameter followed by a mandatory parameter
		## so must pass aff_id in always

		set aff_id [get_cookie AFF_ID]

		## Fire Payment Triggers only if payment was successful ie. status = Y
		if {$DATA(pay_sort) == "D"} {

			set check_action_fn "OB_freebets::check_action"

			if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

				catch {unset FBDATA}

				set check_action_fn "::ob_fbets::go_check_action_fast"

				# Unfortunately this data is not readily available,
				# check_action_fast will have to retreive it
				set FBDATA(lang)           ""
				set FBDATA(ccy_code)       ""
				set FBDATA(country_code)   ""
			}

			# source must be passed in, as you can select your source in admin
			# for card payments

			${check_action_fn} \
				[list DEP DEP1] \
				$DATA(cust_id) \
				$aff_id \
				$DATA(amount) \
				"" \
				"" \
				"" \
				"" \
				$DATA(pmt_id) \
				"PMT"\
				"" \
				0 \
				$DATA(source)

			if {[OT_CfgGet USE_CUST_STATS 0] == 0} {
				#
				# Update flags indicating the channels deposited through
				#
				set chan_dep_thru \
					[OB_prefs::get_cust_flag $DATA(cust_id) chan_dep_thru]
				ob::log::write DEV \
					{$fn for cust: $DATA(cust_id) chan_bet_thru: $DATA(source)}

				if {[string first $DATA(source) $chan_dep_thru] == -1} {
					OB_prefs::set_cust_flag \
						$DATA(cust_id) \
						chan_dep_thru \
						"$DATA(source)$chan_dep_thru"
					ob::log::write DEV \
						{$fn for cust: $DATA(cust_id) ADDING channel: $DATA(source)}
				}
			}

		}

	}

	ob_log::write DEBUG {PMT <= cc_pmt_do_transaction_work}

	return [list 1 [payment_gateway::pmt_gtwy_xlate_err_code $DATA(message)]]

}

#---------------------------------------------------------------------------------------
# cc_pmt_make_payment
#
# This is the main function called by all applications for performing standard deposits
# and withdrawals from an openbet account to an active credit or debit card.
#
# ARGS:
#    acct_id       - the tAcct.acct_id for the transaction
#    oper_id       - the tAdminUser.user_id making the transaction
#    unique_id     - a numeric code that uniquely identifies the transaction initiation,
#                    this prevents the same request being processed twice.
#    pay_sort      - 'D' for Deposit, 'W' for Withdraw
#    amount        - a decimal amount for the transaction, numeric format is dependent on
#                    the currency for the account (tAcct.ccy)
#                    this is the amount by which the account balance should change
#    cpm_id        - the tCPMCC.cpm_id for the chosen card payment method for the
#                    transaction, must have status 'active'
#    source        - the channel code initiating the transaction
#    auth_code     - (optional) a general customer authorisation code which is stored against the
#                    payment in the database.  Used for customer specific purposes and not
#                    to be confused with a bank auth code (see gw_auth_code below).
#    extra_info    - (optional) misc free text (up to 166 chars) which will be recorded against the
#                    payment when stored in the database
#    j_op_type     - (optional) the code to use (must be one from table tJrnlOp) which will be
#                    recorded against the transaction in the journal tJrnl.  This indicates why
#                    or how the transaction was made.
#    min_amt       - (optional) the minimum allowable currency amount for this transaction. Will
#                    return an error if amount < min_amt.
#    max_amt       - (optional) the maximum allowable currency amount for this transaction.
#    call_id       - (optional) if this is a telebetting transaction, the tCall.call_id for this
#                    transaction
#    gw_auth_code  - (optional) a four-digit numeric code supplied by the bank which may be required
#                    for processing 'referred' payments.
#    admin         - (optional) flag indicating whether this transaction has been initiated through
#                    the admin screens (there is no channel for admin screens)
#    comm_list     - (optional) list of commission amounts
#                    3 element list containing (commission, payment_amount, tPmt_amount)
#                    commission is the amount of commission to be paid on this payment
#                    payment_amount is the amount to go through the payment gateway
#                    tPmt_amount is the amount to be inserted into tPmt
#    min_overide   - whether this payment is allowed to overide the minimum withdrawal limits
#
# RETURNS:
#    on success a list with the format {1 pmt_id}
#       1      - indicates a successful transaction
#       pmt_id - is the tPmt.pmd_id of the successfully recorded transaction
#
#    on failure a list with the following format {0 msg pmt_err_code}
#       0             - indicates failure to perform the transaction in full
#       msg           - is a free text description of the problem, which may be suitable
#                       to display to the user depending on pmt_err_code
#       pmt_err_code  - one of the standard payment error codes in ::payment_gateway::PMT_ERR_CODES,
#                       if the error is unexpected or non-routine (eg TCL or SQL error) the general
#                       error code PMT_ERR will be used with 'msg' giving more specific information
#---------------------------------------------------------------------------------------
proc cc_pmt_make_payment {
	acct_id
	oper_id
	unique_id
	pay_sort
	amount
	cpm_id
	source
	{auth_code ""}
	{extra_info ""}
	{j_op_type ""}
	{min_amt ""}
	{max_amt ""}
	{call_id ""}
	{gw_auth_code ""}
	{admin "0"}
	{cvv2 ""}
	{comm_list {}}
	{country_code ""}
	{3d_secure_arr ""}
	{min_overide "N"}
} {

	set fn {cc_pmt_make_payment}

	ob_log::write DEBUG {$fn =>}

	set result [_cc_pmt_make_payment $acct_id \
	                                 $oper_id \
	                                 $unique_id \
	                                 $pay_sort \
	                                 $amount \
	                                 $cpm_id \
	                                 $source \
	                                 $auth_code \
	                                 $extra_info \
	                                 $j_op_type \
	                                 $min_amt \
	                                 $max_amt \
	                                 $call_id \
	                                 $gw_auth_code \
	                                 $admin \
	                                 $cvv2 \
	                                 $comm_list \
	                                 $country_code \
	                                 $3d_secure_arr\
	                                 "N" \
	                                 "" \
	                                 $min_overide]

	if {[lindex $result 0] == 2} {

		# resubmit required
		set prev_pmt_id      [lindex $result 1]
		set force_3ds_bypass "Y"
		set unique_id        [OT_UniqueId]

		set result [_cc_pmt_make_payment $acct_id \
		                                 $oper_id \
		                                 $unique_id \
		                                 $pay_sort \
		                                 $amount \
		                                 $cpm_id \
		                                 $source \
		                                 $auth_code \
		                                 $extra_info \
		                                 $j_op_type \
		                                 $min_amt \
		                                 $max_amt \
		                                 $call_id \
		                                 $gw_auth_code \
		                                 $admin \
		                                 $cvv2 \
		                                 $comm_list \
		                                 $country_code \
		                                 $3d_secure_arr \
		                                 $force_3ds_bypass \
		                                 $prev_pmt_id \
		                                 $min_overide]
	}

	return $result
}

proc _cc_pmt_make_payment {
	acct_id
	oper_id
	unique_id
	pay_sort
	amount
	cpm_id
	source
	auth_code
	extra_info
	j_op_type
	min_amt
	max_amt
	call_id
	gw_auth_code
	admin
	cvv2
	comm_list
	country_code
	3d_secure_arr
	{force_3ds_bypass "N"}
	{prev_pmt_id ""}
	{min_overide "N"}
} {

	variable CFG

	set fn {_cc_pmt_make_payment}

	ob_log::write DEBUG {$fn =>}

	#
	# check the payment sort and grab the ip address
	#
	if {$pay_sort != "D" && $pay_sort != "W"} {
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_TYPE] PMT_TYPE]
	}

	set DATA(acct_id)       $acct_id
	set DATA(oper_id)       $oper_id
	set DATA(unique_id)     $unique_id
	set DATA(pay_sort)      $pay_sort
	set DATA(cpm_id)        $cpm_id
	set DATA(source)        $source
	set DATA(auth_code)     $auth_code
	set DATA(gw_auth_code)  $gw_auth_code
	set DATA(extra_info)    $extra_info
	set DATA(j_op_type)     $j_op_type
	set DATA(min_amt)       $min_amt
	set DATA(max_amt)       $max_amt
	set DATA(call_id)       $call_id
	set DATA(transactional) "Y"
	set DATA(admin)         $admin
	set DATA(cvv2)          $cvv2
	set DATA(bank)          ""
	set DATA(pay_mthd)      "CC"
	set DATA(prev_pmt_id)   $prev_pmt_id
	set DATA(min_overide)   $min_overide

	if {[OT_CfgGet DCASH_XML 0] && $pay_sort == "W"} {
		ob::DCASH::set_require_cvv2 0
	}

	#
	# Get customer and card details from db
	#
	set result [cc_pmt_get_data DATA]

	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	# Check the customer account and the card's bin policy to see if a 3dsecure
	# bypass is required

	# Note: customer level 3dsecure bypass overrides card level 3dsecure policy

	ob_log::write DEBUG {$fn Skip 3Ds flag = $DATA(cust_flag,Skip3DSecure)}
	ob_log::write DEBUG {$fn Allow Policy Codes = $CFG(3ds_policy_codes)}
	ob_log::write DEBUG {$fn 3Ds Card Policy = $DATA(threed_secure_pol)}
	ob_log::write DEBUG {$fn Force 3Ds Bypass = $force_3ds_bypass}

	if {$pay_sort=="D" &&
	    $3d_secure_arr != "" &&
	    $DATA(cust_flag,Skip3DSecure) != "Y" &&
	    $force_3ds_bypass == "N" &&
	    (($CFG(3ds_policy_codes) && $DATA(threed_secure_pol) != 2) ||
	     !$CFG(3ds_policy_codes))} {
		# prepare payment for 3d secure
		ob_log::write DEBUG {$fn Bypass 3d secure? No}
		foreach {nam val} $3d_secure_arr {
			set DATA(3d_secure,$nam) $val
		}
		set DATA(3d_secure) 1
	} else {
		#  Set up datacash for a payment bypass and copy to the array.
		#  This is because eventually Datacash will require all payment through
		#  accounts that are 3DS enabled to make an enrolment_check even if they
		#  are 3DS enabled.
		#  So if we have a call that does not specify a 3d secure array
		#  (i.e. The call cannot handle redirects) we must create the 3d_secure
		#  array here and specify a bypass
		ob_log::write DEBUG {$fn Bypass 3d secure? Yes}
		3ds_arr_enrol_init_bypass 3ds
		3ds_arr_copy_to 3ds DATA
		set DATA(3d_secure) 1

	}

	# if commission list is empty then initialize it with 0 commission
	if {$comm_list == {}} {
		set comm_list [list 0 $amount $amount]
	}

	#
	# get the commission, payment amount and tPmt amount from the list
	#
	set DATA(commission)  [lindex $comm_list 0]
	set DATA(amount)      [lindex $comm_list 1]
	set DATA(tPmt_amount) [lindex $comm_list 2]

	#
	# Get the card type (debit/credit).
	#
	if {[catch {set rs [tb_db::tb_exec_qry cc_get_card_type $DATA(card_scheme)]} msg]} {
		ob_log::write ERROR {Error retrieving card_type for card_scheme: $DATA(card_scheme), msg: $msg}
		return [list 0 "Error retrieving card_type for card_scheme" PMT_ERR]
	}

	if {![db_get_nrows $rs]} {
		ob_log::write ERROR {Error retrieving card_type for card_scheme: $DATA(card_scheme), msg: $msg}
		return [list 0 "Error retrieving card_type for card_scheme" PMT_ERR]
	}

	set card_type [db_get_col $rs 0 type]

	db_close $rs

	# OVS - Checks if the customer's age has been verified and whether withdrawal is allowed
	# for the customer.
	if {[OT_CfgGet FUNC_OVS 0] && [OT_CfgGet FUNC_OVS_VERF_CC_CHK 1]} {
		set chk_resp [verification_check::do_verf_check \
			"CC" \
			$DATA(pay_sort) \
			$DATA(acct_id)  \
			$DATA(card_no)  \
			$card_type      \
			$DATA(expiry) \
			$DATA(cpm_id)]

		if {![lindex $chk_resp 0]} {
			return [list 0 "Error with OVS" [lindex $chk_resp 2]]
		}
	}

	#
	# verify data and record
	#
	set result [cc_pmt_verify_and_record DATA]

	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	#
	# Should there be a delay or and fraud related reasons why we shouldn't send the payment
	# to the gateway straight away.
	#
	set process_pmt 1

	if {$pay_sort=="W"} {
		set process_pmt [ob_pmt_validate::chk_wtd_all\
			$DATA(acct_id)\
			$DATA(pmt_id)\
			"CC"\
			$DATA(card_scheme)\
			$DATA(amount)\
			$DATA(ccy_code)\
			$DATA(expiry)]

	}

	if {!$process_pmt} {
		set pmt_id $DATA(pmt_id)
		array unset DATA
		return [list 1 $pmt_id ""]
	}

	#
	# do transaction
	#
	set result [cc_pmt_do_transaction DATA 0]

	if {[lindex $result 0] == 2} {
		# resubmit required just return
		unset DATA
		return $result
	}

	if {[lindex $result 0] == 0} {
		lappend result $DATA(cv2avs_status)
		unset DATA
		return $result
	}

	set pmt_id $DATA(pmt_id)
	set msg [lindex $result 1]

	unset DATA

	ob_log::write DEBUG { <= $fn}

	#
	# return the payment id
	#
	return [list 1 $pmt_id $msg]
}

#----------------------cc_pmt_3ds_auth-----------------------------------------
#  Function to handle the authentication of a payment that has been through 3D Secure
#  authentication
#  basically takes in a 3d Secure Array that has been set up with a
#  3ds_arr_auth_set_pares call with an MD and PaRes, obtained from a redirect back
#  to the customer.
proc cc_pmt_3ds_auth {
	3d_secure_arr
} {
	# Extensible...
	foreach v {apacs_ref
				acct_id
				oper_id
				amount
				unique_id
				pay_sort
				source
				auth_code
				gw_auth_code
				extra_info
				j_op_type
				min_amt
				max_amt
				call_id
				transactional
				admin
				bank
				outlet } {
		set DATA($v) ""
	}
	set DATA(pay_mthd)      "CC"
	set DATA(transactional) "Y"
	set DATA(admin)         0
	set DATA(cvv2)          0
	set DATA(bank)          ""


	ob_log::write DEBUG {=> cc_pmt_3ds_auth}
	ob_log::write DEBUG {cc_pmt_3ds_auth:CALL:3d_secure_arr=$3d_secure_arr}

	foreach {nam val} $3d_secure_arr {
		set DATA(3d_secure,$nam) $val
	}
	set DATA(3d_secure) 1
	set pmt_id $DATA(3d_secure,pmt_id)
	set DATA(pmt_id) $pmt_id

	# Sanity check to ensure payment has not already been settled
	# (i.e. been marked as 'good/bad')
	set res [payment_gateway::chk_pmt_not_settled $DATA(pmt_id)]

	if {$res != "OK"} {
		set res_desc [payment_gateway::pmt_gtwy_xlate_err_code $res]
		return [list 0 "Payment has already been settled" $res_desc]
	}

	set result [payment_gateway::pmt_gtwy_get_pmt_pg_params DATA $pmt_id]

	if {![lindex $result 0]} {
		return [list 0 "Unable to obtain payment gateway parameters" PMT_ERR]
	}

	set cust_id $DATA(3d_secure,cust_id)
	set DATA(cust_id) $cust_id

	#
	#verify the customer_id from the payment_id we have to check whether
	#
	if {[catch {set rs [tb_db::tb_exec_qry cc_verify_3ds_cust $pmt_id $cust_id]} msg]} {
		ob_log::write ERROR {Error retrieving cust_id for payment: $msg}
		return [list 0 "Error retrieving cust_id for payment" PMT_ERR]
	}
	set n_rows [db_get_nrows $rs]

	if {$n_rows == 0} {
		return [list 0 "Inconsistancy between payment ID $pmt_id and customer ID $cust_id" PMT_ERR]
	}

	set DATA(pay_sort)      [db_get_col $rs 0 payment_sort]
	set DATA(amount)        [db_get_col $rs 0 amount]
	set DATA(source)        [db_get_col $rs 0 source]
	set DATA(acct_id)       [db_get_col $rs 0 acct_id]
	set DATA(ccy_code)      [db_get_col $rs 0 ccy_code]
	set DATA(auth_type)     [db_get_col $rs 0 auth_type]
	set DATA(country_code)  [db_get_col $rs 0 country_code]
	set DATA(enrol_3d_resp) [db_get_col $rs 0 enrol_3d_resp]

	# retrieve the previous pmt id for consistency, its not really possible
	# for a payment returning from 3ds auth to have a previous payment but its
	# nice to have this value set when checking if we should resubmit
	set DATA(prev_pmt_id)  [db_get_col $rs 0 prev_pmt_id]

	db_close $rs

	#  Pull out the card details
	#
	card_util::cd_get_from_pmt_id $pmt_id CARD

	set DATA(cpm_id)            $CARD(cpm_id)
	set DATA(enc_card_no)       $CARD(enc_card_no)
	set DATA(card_no)           $CARD(card_no)
	set DATA(start)             $CARD(start)
	set DATA(expiry)            $CARD(expiry)
	set DATA(issue_no)          $CARD(issue_no)
	set DATA(card_bin)          $CARD(card_bin)
	set DATA(hldr_name)         $CARD(hldr_name)
	set DATA(threed_secure_pol) $CARD(threed_secure_pol)

	#
	# do transaction
	#
	set result [cc_pmt_do_transaction DATA 1]

	if {[lindex $result 0] == 2} {
		# resubmit required
		set acct_id     $DATA(acct_id)
		set pay_sort    $DATA(pay_sort)
		set amount      $DATA(amount)
		set cpm_id      $DATA(cpm_id)
		set source      $DATA(source)
		set cvv2        $DATA(3d_secure,cvv2)
		set prev_pmt_id $DATA(pmt_id)

		# clear the DATA array, to make sure we have no leaks
		unset DATA

		set result [_cc_pmt_make_payment $acct_id \
		                                 "" \
		                                 [OT_UniqueId] \
		                                 $pay_sort \
		                                 $amount \
		                                 $cpm_id \
		                                 $source \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 {0} \
		                                 $cvv2 \
		                                 {} \
		                                 {} \
		                                 {} \
		                                 "Y" \
		                                 $prev_pmt_id]
		return $result
	}

	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	set pmt_id $DATA(pmt_id)
	set msg [lindex $result 1]

	unset DATA

	ob_log::write DEBUG {<= cc_pmt_3ds_auth}

	#
	# return the payment id
	#
	return [list 1 $pmt_id $msg]
}


#
# card checking functions
#
#
# Has the card been blocked?
#
proc cc_pmt_card_not_blocked {card_no cust_id} {

	#
	# if cust_id is specified then check to see if this card is
	# allowed (tCustomer.allow_card)
	#
	if [catch {set rs [tb_db::tb_exec_qry cc_pmt_cust_card_allowed $cust_id]} msg] {
		ob_log::write WARNING {PMT Failed to execute cust card allowed qry $msg}
		return 0
	}
	if {[db_get_nrows $rs] == 1 && [db_get_coln $rs 0] == "Y"} {
		db_close $rs
		return 1
	}
	db_close $rs

	# First encrypt the card number
	set card_hash [md5 $card_no]
	set bin [string range $card_no 0 5]

	#
	# check tCardBlock table to see if this card is allowed
	#
	if [catch {set rs [tb_db::tb_exec_qry cc_pmt_card_block $card_hash $bin]} msg] {
		ob_log::write WARNING {PMT Failed to execute pChkCardAllowed: $msg}
		return 0
	}

	if {[db_get_nrows $rs] == 1 && [db_get_coln $rs 0] == "Y"} {
		db_close $rs
		return 1
	}

	db_close $rs
	return 0
}


proc cc_pmt_card_allowed {card_no cust_id pay_sort} {

	set card_bin [string range $card_no 0 5]

	if {[catch {set rs [tb_db::tb_exec_qry cc_pmt_card_allowed $cust_id $card_bin $pay_sort]} msg]} {
		ob_log::write WARNING {PMT Failed to execute pChkCardAllowed: $msg}
		return 0
	}

	if {([db_get_nrows $rs] == 1) && ([db_get_coln $rs 0] == "Y")} {
		db_close $rs

		# BlueSquare now check tCardSchemeInfo
		if {[OT_CfgGet CHECK_SCHEME_ALLOWED 0]} {
			if {[catch {set rs [tb_db::tb_exec_qry cc_chk_scheme_allowed $card_bin $card_bin]} msg]} {
				ob_log::write WARNING {PMT Failed to execute cc_chk_scheme_allowed: $msg}
				return 0
			}

			if {[db_get_nrows $rs] == 1} {
				if {$pay_sort == "D"} {
					set allow [db_get_col $rs 0 dep_allowed]
				} else {
					set allow [db_get_col $rs 0 wtd_allowed]
				}
				if {$allow == "Y"} {
					db_close $rs
					return 1
				}
			}
		} else {

		 return 1
		}
	}

	db_close $rs
	return 0
}


# ----------------------------------------------------------------------
# double check the users password or pin against the database
# ----------------------------------------------------------------------

proc cc_pmt_auth_user {cust_id login_type val} {

	global LOGIN_DETAILS

	set     lqry tb_db::tb_exec_qry
	lappend lqry cc_pmt_vrfy_user $cust_id

	set ret 0
	switch -- $login_type {
		"PASSWD" {lappend lqry [encrypt_password $val $LOGIN_DETAILS(PASSWORD_SALT)] ""}
		"PIN"    {lappend lqry "" [encrypt_pin $val]}
		"NONE"   {return 1}
		default  {return 0}
	}
	if [catch {set rs [eval $lqry]} msg] {
		ob_log::write WARNING {PMT failed to exec vrfy qry: $msg}
		return $ret
	}

	if {[db_get_nrows $rs] == 1} {
		#set PMT(postcode) [db_get_col $rs 0 addr_postcode]
		set ret 1
	}
	db_close $rs
	return $ret
}


proc cc_pmt_mark_referral_complete {pmt_id oper_id {transactional "Y"} args} {
	# Makes the payment and update the status from I to Y
	if [catch {tb_db::tb_exec_qry cc_pmt_refer_allow $pmt_id \
													$oper_id \
													$transactional \
													1} msg] {

		ob_log::write WARNING {PMT Failed to mark payment as having completed referral: $msg}
		return [list 0 "Failed to mark payment as having completed referral: $msg"]
	}
	return [list 1]
}

proc cc_pmt_mark_referred {pmt_id oper_id {transactional "Y"} {mode 2} args} {

	#
	# switch this payment to a referral
	#

	if [catch {tb_db::tb_exec_qry cc_pmt_refer_allow $pmt_id \
													$oper_id \
													$transactional \
													$mode} msg] {

		ob_log::write WARNING {PMT Failed to mark payment as referred: $msg}
		return [list 0 "Failed to mark payment as referred: $msg"]
	}
	return [list 1]
}

proc cc_pmt_mark_later {pmt_id oper_id {transactional "Y"} {status "N"}} {

	#
	# switch this payment to be processed later
	#
	if [catch {tb_db::tb_exec_qry cc_pmt_no_response_allow $pmt_id \
														   $oper_id \
														   $transactional\
														   $status} msg] {
		ob_log::write WARNING {PMT Failed to mark payment as later: $msg}
		return [list 0 "Failed to mark payment as later: $msg"]
	}

	return [list 1]
}

# -----------------------------------------------------------------
# Send a previously referred payment through again with an
# authorisation code
# -----------------------------------------------------------------
proc cc_pmt_proc_auth {
	pmt_id
	ref_no
	auth_code
	amount
	payment_sort
	card_no
	start
	expiry
	issue_no
	status
	ccy_code
	{reason ""}
} {

	global FBDATA

	#
	# Validate Authorisation Code (Referrals only)
	#
	if {$status=="R" || $status=="I"} {
		if {[OT_CfgGet VALIDATE_PMT_AUTH_CODE_LOCALLY 1] && ![regexp {^[0-9][0-9][0-9][0-9]+$} $auth_code]} {
			set err_msg "Auth code must be numeric and at least 4 digits long"
			err_bind $err_msg
			return [list 0 $err_msg PMT_AUTH]
		}
	} else {
		set auth_code ""
	}

	# this comment forces the dynamic load of payment_gateway...
	ob_log::write INFO {PMT Send auth code to payment gateway}


	#
	# PG Acct paramters were used when sending the original payment.
	# Use these to along with the current pmt gateway host to send
	# the auth code.
	#
	set result [payment_gateway::pmt_gtwy_get_pmt_pg_params DATA $pmt_id]

	if {![lindex $result 0]} {
		return [list 0 "Unable to obtain payment gateway parameters" PMT_ERR]
	}

	#
	# get the data sorted out
	#
	set DATA(gw_auth_code)  $auth_code
	set DATA(apacs_ref)     $ref_no
	set DATA(amount)        [format {%0.2f} $amount]
	set DATA(card_no)       $card_no
	set DATA(card_bin)      [string range $card_no 0 5]
	set DATA(start)         $start
	set DATA(expiry)        $expiry
	set DATA(issue_no)      $issue_no
	set DATA(pay_sort)      $payment_sort
	set DATA(ccy_code)      $ccy_code
	set DATA(reason)        $reason
	set DATA(is_referral)   1
	set DATA(policy_no)     ""
	set DATA(cvv2_needed)   0

	## Needed by DCASH XML
	set DATA(addr_1)        ""
	set DATA(addr_2)        ""
	set DATA(addr_3)        ""
	set DATA(addr_4)        ""
	set DATA(postcode)      ""
	set DATA(cntry_code)    ""
	set DATA(cvv2)          ""
	set DATA(bank)          ""

	# Authorisations should only come via admin/telebet so source will be P
	set DATA(source) P

	#
	# call the payment with the auth code
	#
	set result [payment_gateway::pmt_gtwy_do_payment DATA]
	if {$result == "OK"} {
		set DATA(status) "Y"
	} else {
		# Leave the status as it were previously
		set DATA(status) $status
	}

	#
	# Update the return codes and transfer funds if status was I and referral
	# was successful
	#
	set c [catch {

		tb_db::tb_exec_qry cc_update_pmt_status $pmt_id $DATA(status)

		tb_db::tb_exec_qry cc_update_pmtcc_info $DATA(gw_auth_code) \
												$DATA(gw_uid) \
												$DATA(gw_ret_code) \
												$DATA(gw_ret_msg) \
												$DATA(pg_host_id) \
												$pmt_id
	} msg]

	if {$c} {
		ob_log::write ERROR {PMT Failed to update return codes in database: $msg}
		return [list 0 "Failed to update return codes in database" PMT_ERR]
	}

	if {$result != "OK"} {
		ob_log::write ERROR {PMT Error getting/setting auth code ($pmt_id ($DATA(status), $DATA(gw_ret_code), $DATA(gw_auth_code))}
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $result] $result]
	}


	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		## Fire Payment Triggers only if payment was successful ie. status = Y
		if {$DATA(pay_sort) == "D"} {

			set aff_id [get_cookie AFF_ID]

			if {[catch {set rs [tb_db::tb_exec_qry cc_pmt_get_cust_id $pmt_id]} msg]} {
				ob_log::write ERROR {PMT Error retrieving cust_id for payment: $msg}
			} else {
				set cust_id [db_get_col $rs 0 cust_id]
				db_close $rs
			}


			## Grab number of deposits in tJrnl for this user

			set num_deps 0
			if {[catch {set rs [tb_db::tb_exec_qry pmt_dep_count $cust_id]} msg]} {
				ob_log::write ERROR {PMT Error retrieving deposits from tJrnl: $msg}
			} else {
				set num_deps [db_get_col $rs 0 total]
				db_close $rs
			}

			set check_action_fn "OB_freebets::check_action"

			if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

				catch {unset FBDATA}

				set check_action_fn "::ob_fbets::go_check_action_fast"

				# Unfortunately this data is not readily available,
				# check_action_fast will have to retreive it
				set FBDATA(lang)           ""
				set FBDATA(ccy_code)       ""
				set FBDATA(country_code)   ""
			}

			${check_action_fn} \
				[list DEP DEP1] \
				$cust_id \
				$aff_id \
				$DATA(amount) \
				"" \
				"" \
				"" \
				"" \
				$pmt_id \
				"PMT"\
				"" \
				0 \
				$DATA(source)
		}
	}
	return [list 1 $pmt_id $DATA(status)]
}

# =====================================================================
# Procedure to send alert email to BlueSq for U status transaction
# Added for BlueSq by Justin Hayes 28/11/02
# =====================================================================

proc send_U_trans_alert {ARRAY} {

	upvar 1 $ARRAY DATA

	ob_log::write DEBUG {PMT Sending U transaction alert email.}

	if [catch {set acct_id $DATA(acct_id)}] {
		ob_log::write DEBUG {PMT acct_id missing from DATA}
		set acct_id "Not known"
	} else {
		if {[catch {set rs [tb_db::tb_exec_qry cc_pmt_cust_acctno $acct_id]} msg]} {
			ob_log::write ERROR {PMT cc_pmt_cust_acctno query failed : $msg}
			return
		}
		set acct_no [db_get_col $rs acct_no]
		db_close $rs
	}

	set subject "U transaction"
	set type    "PAYMENT"

	set alert   "Account Number: $acct_no\n"
	foreach {name val} {"Transaction Id" cpm_id "Gateway" pg_type "Currency" ccy_code "Amount" amount} {
		if [catch {append alert "$name : $DATA($val)"}] {
			ob_log::write DEBUG {PMT $name missing from DATA}
		}
	}

	ob_log::write ERROR {PMT $alert}

	if {[catch {set rs [tb_db::tb_exec_qry payment_alert_mail $type $subject $alert]} msg]} {
		ob_log::write ERROR {PMT payment_alert_mail query failed : $msg}
		return
	}
	db_close $rs
}


# =====================================================================
# Procedure to send message to the payment ticker via router
# Added for BlueSQ by Justin Hayes 12/10/01
# Amended for Ladbrokes by Justin Hayes 22/11/01
# =====================================================================
proc send_payment_ticker_msg {
	pmt_id
	depSource
	acct_id
	amount
	status
	pay_sort
	payment_date
	payment_time
	auth_date
	auth_time
	gw_auth_code
	gw_ret_code
	gw_ret_msg
	ref_no
	hldr_name
	cv2avs_status
} {

	# grab some stuff

	set amount      [format "%.2f" $amount]


	# retrieve customers data from db
	if [catch {set rs [tb_db::tb_exec_qry cc_get_payment_ticker_data $acct_id]} msg] {
		ob_log::write ERROR {PMT failed to get data for ticker: $msg}
		return
	}

	# retrieve data from results set
	set cust_id    [db_get_col $rs cust_id]
	set username   [db_get_col $rs username]
	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set fname      [ob_cust::normalise_unicode [db_get_col $rs fname] 0 0]
		set lname      [ob_cust::normalise_unicode [db_get_col $rs lname] 0 0]

	} else  {
		set fname      [db_get_col $rs fname]
		set lname      [db_get_col $rs lname]
	}
	set country_code [db_get_col $rs country_code]
	set cust_reg_date [db_get_col $rs cust_reg_date]
	set notifiable [db_get_col $rs notifyable]
	set telephone  [db_get_col $rs telephone]
	set email      [db_get_col $rs email]
	set acct_no    [db_get_col $rs acct_no]
	set balance    [db_get_col $rs balance]
	set ccy_code   [db_get_col $rs ccy_code]
	set exch_rate  [db_get_col $rs exch_rate]
	set m_code     [db_get_col $rs code]
	set customername "$fname $lname"
	set liab_group [db_get_col $rs liab_group]


	set convertedAmount [expr {$amount / $exch_rate}]
	set convertedAmount [format "%.2f" $convertedAmount]

	# check for some empty strings that cant be checked elsewhere
	if {$telephone == ""} {
		set telephone " "
	}
	if {$email == ""} {
		set email " "
	}
	if {$ref_no == ""} {
		set ref_no " "
	}

	# close results set
	db_close $rs

	# retrieve customers fail count from db
	if [catch {set rs [tb_db::tb_exec_qry cc_get_fail_count $pay_sort $acct_id]} msg] {
		ob_log::write ERROR {PMT failed to get fail count data for ticker: $msg}
		return
	}

	# retrieve fail count from results set
	set failcount [db_get_col $rs 0 count]

	# close results set
	db_close $rs

	# retrieve customers card count from db
	if [catch {set rs [tb_db::tb_exec_qry cc_get_card_count $pay_sort $acct_id]} msg] {
		ob_log::write ERROR {PMT failed to get card count data for ticker: $msg}
		return
	}

	# retrieve fail count from results set
	set cardcount [db_get_col $rs 0 count]

	# close results set
	db_close $rs

	# send message to router
	if {[OT_CfgGet MONITOR 0]} {
		# send to monitor
		set m_cust_id       $cust_id
		set m_cust_uname    $username
		set m_cust_fname    $fname
		set m_cust_lname    $lname
		set m_country_code  $country_code
		set m_cust_reg_date $cust_reg_date
		set m_cust_notifiable $notifiable
		set m_cust_acctno   $acct_no
		set m_acct_balance  $balance
		set m_amount_usr    $amount
		set m_amount_sys    $convertedAmount
		set m_ccy_code      $ccy_code
		set m_pmt_id        $pmt_id
		set m_pmt_date      "$payment_date $payment_time"
		set m_pmt_status    $status
		set m_pmt_sort      $pay_sort
		set m_channel       $depSource
		set m_gw_auth_date  [string trim "$auth_date $auth_time"]
		set m_gw_auth_code  $gw_auth_code
		set m_gw_ret_code   $gw_ret_code
		set m_gw_ret_msg    $gw_ret_msg
		set m_gw_ret_no     $ref_no
		set m_hldr_name    $hldr_name
		set m_liab_group   $liab_group
		set m_cv2avs_status $cv2avs_status

		MONITOR::send_payment \
			$m_cust_id \
			$m_cust_uname \
			$m_cust_fname \
			$m_cust_lname \
			$m_country_code\
			$m_cust_reg_date\
			$m_cust_notifiable \
			$m_cust_acctno \
			$m_code \
			$m_acct_balance \
			$m_amount_usr \
			$m_amount_sys \
			$m_ccy_code \
			$m_pmt_id \
			$m_pmt_date \
			$m_pmt_status \
			$m_pmt_sort \
			$m_channel \
			$m_gw_auth_date \
			$m_gw_auth_code \
			$m_gw_ret_code \
			$m_gw_ret_msg \
			$m_gw_ret_no \
			$m_hldr_name \
			$m_liab_group \
			$m_cv2avs_status
	}

	if {[OT_CfgGet MSG_SVC_ENABLE 1]} {
		# send to legacy ticker
		eval [concat MsgSvcNotify payment \
			DcashRefNo     "{$ref_no}" \
			GwRetCode      "{$gw_ret_code}" \
			GwRetMsg       "{$gw_ret_msg}" \
			UserName       "{$username}" \
			CustomerName   "{$customername}" \
			CountryCode    "{$country_code}" \
			CustRegDate    "{$cust_reg_date}" \
			AccountNumber  "{$acct_no}" \
			PhoneNo        "{$telephone}" \
			Email          "{$email}" \
			PaymentAmount  "{$amount}" \
			DefaultAmount  "{$convertedAmount}" \
			AccountBalance "{$balance}" \
			Currency       "{$ccy_code}" \
			PaymentDate    "{$payment_date}" \
			PaymentTime    "{$payment_time}" \
			AuthTime       "{$auth_time}" \
			AuthCode       "{$gw_auth_code}" \
			Status         "{$status}" \
			FailCount      "{$failcount}" \
			CardCount      "{$cardcount}" \
			Channel        "{$depSource}" \
			Sort           "{$pay_sort}"]
	}

}

########################################################################
#
#  Procedure to get information for a CC payment given the pmt_id
#  Used for 3D Secure because we need to find out the amount and other info
#########################################################################
proc cc_pmt_get_pmt_info {OUT pmt_id} {
	upvar 1 $OUT U_OUT

	set rs [tb_db::tb_exec_qry cc_pmt_get_pmt_info_sql $pmt_id]
	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob_log::write ERROR {cc_pmt_get_pmt_info : Returned $nrows instead of 1}
		return 0
	}

	set U_OUT(payment_sort) [db_get_col $rs 0 payment_sort]
	set U_OUT(amount) [db_get_col $rs 0 amount]
	set U_OUT(commission) [db_get_col $rs 0 commission]
	set U_OUT(auth_type) [db_get_col $rs 0 auth_type]

	db_close $rs
	return 1
}



########################################################################
#  In order to avoid an explosion in parameters as a result of
#  3D Secure the 3D Secure parameters are going to be stored in an
#  array. Clients should not build the array up themselves but should
#  call functions to build up the array.
#
#  This array will be passed flattened into calls as
#  3d_secure_arr
#
#
#  Array format:
#  [] Indicated default value
#
#
#    call_type  - 'enrol' or 'auth'
#
#  For enrol:
#
#    merchant_url              -  URL that customer will be returned to
#    purchase_desc             -  Purchase description, required for 3D Secure
#    extra_info                -  Freeform text field that will be embedded in the MD, and passed back to us
#
#  Browser information of the user
#    browser,category          -  0 = Internet browser, 1 = mobile
#    browser,accept_headers    -  The accept headers HTTP header of the customer
#    browser,user_agent        -  The user agent of the customer
#
#  Policy Infomation: Used to determine policy
#    policy,require_liab_prot [0]  - Whether to refuse transactions if liability
#                                    protection is not available. Used so the shared
#                                    code knows whether to proceed with a transaction
#                                    if the code is not set.
#
#    On making the call it populates:
#
#    ref_no                        - Reference number, used when authorising this 3DS transaction
#    ?mcs_url                       - URL for redirect
#    ?pareq                         - pareq for redirect
#
#
#    For the auth call:
#
#    ref_no                         - Reference number returned from enrol call
#    pares?                         - PaRes message passed back after customer completes their browsing
#
##############################################################################################

proc 3ds_arr_enrol_init {ARR merchant_url purchase_desc {extra_info ""}} {
	upvar 1 $ARR U_ARR
	if {[info exists U_ARR]} {unset U_ARR}

	set U_ARR(call_type) "enrol"
	#  Initialise Policy
	set U_ARR(policy,require_liab_prot) [OT_CfgGet PMT_3DS_REQUIRE_LIAB_PROT 0]
	set U_ARR(policy,bypass_verify) 0

	set U_ARR(merchant_url) $merchant_url
	set U_ARR(purchase_desc) $purchase_desc
	set U_ARR(extra_info) $extra_info
}

proc 3ds_arr_enrol_init_bypass {ARR} {
	upvar 1 $ARR U_ARR
	if {[info exists U_ARR]} {unset U_ARR}

	set U_ARR(call_type) "enrol"
	#  Initialise Policy
	set U_ARR(policy,require_liab_prot) [OT_CfgGet PMT_3DS_REQUIRE_LIAB_PROT 0]
	set U_ARR(policy,bypass_verify) 1

	set U_ARR(merchant_url) ""
	set U_ARR(purchase_desc) ""
	set U_ARR(extra_info) ""
}

proc 3ds_arr_enrol_set_browser {ARR category accept_headers user_agent} {
	upvar 1 $ARR U_ARR

	set U_ARR(browser,device_category) $category
	set U_ARR(browser,accept_headers) $accept_headers
	set U_ARR(browser,user_agent) $user_agent
}

# Overides default policy on liability protection
#
proc 3ds_arr_enrol_set_require_liab_prot {ARR val} {
	upvar 1 $ARR U_ARR
	set U_ARR(policy,require_liab_prot) $val
}

#  For setting / resetting the extra_info field
#
proc 3ds_arr_set_extra_info {ARR extra_info} {
	upvar 1 $ARR U_ARR
	set U_ARR(extra_info) $extra_info
}


# Returns either OK or {ERR err1 err2 ...}, a list of the errors
proc 3ds_arr_enrol_check {ARR} {
	upvar 1 $ARR U_ARR
	set lerr [list]
#  Check compulsary elements
	foreach k {call_type
			merchant_url
			purchase_desc
			browser,device_category
			browser,accept_headers
			browser,user_agent
			policy,require_liab_prot
			policy,bypass_verify} {

		if {![info exists DCASH_DATA($k)]} {
			lappend lerr "Element $k must be present"
		}
	}
	if {![regexp {^[01]$} $DCASH_DATA(browser,device_category)]} {
		lappend lerr "Browser device_category must be 0 or 1"
	}
	if {![regexp {^[01]$} $DCASH_DATA(policy,require_liab_prot)]} {
		lappend lerr "Browser require_liab_prot must be 0 or 1"
	}
	if {![regexp {^[01]$} $DCASH_DATA(policy,bypass_verify)]} {
		lappend lerr "Browser bypass_verify must be 0 or 1"
	}

	if {[llength $lerr] == 0} {
		return OK
	} else {
		return [concat ERR lerr]
	}
}


#
#  Returns a list of name value pairs for redirecting
#  Note these are NOT escaped
#  Must be called after a redirect palm
proc 3ds_arr_enrol_get_redirect_params {ARR} {
	upvar 1 $ARR U_ARR
	IF {[info exists U_ARR]} {unset U_ARR}

	foreach i {ref param} {
			set U_ARR($i) ""
	}

	set U_ARR(pareq) $pareq
	set U_ARR(acs_url) $acs_url
	set U_ARR(ref) $ref
}

#  Init for the authorisation array
#  must pass in the datacash reference
proc 3ds_arr_auth_init {ARR} {
	upvar 1 $ARR U_ARR
	if {[info exists U_ARR]} {unset U_ARR}

	foreach k {ref_no pares} {
		set U_ARR($k) ""
	}
	set U_ARR(ref_no) $ref_no
}


#  Sets the pares, MD from the reply
proc 3ds_arr_auth_set_pares {ARR pares MD} {

	upvar 1 $ARR U_ARR
	set U_ARR(pares) $pares
	set U_ARR(MD) $MD
	set MD_upack_value [3ds_MD_unpack $MD]
	if {[lindex $MD_upack_value 0] == "OK"} {
		set U_ARR(pmt_id) [lindex $MD_upack_value 1]
		set U_ARR(cust_id) [lindex $MD_upack_value 2]
		set U_ARR(ref) [lindex $MD_upack_value 3]
		set U_ARR(extra_info) [lindex $MD_upack_value 4]
		return "OK"
	} else {
		return "ERR"
	}
}

##
#  Helper functions used to copy the 3d_secure array to and from
#  the PMT array. Also used in data cash call
#  just copies all elements, no checking performed

proc 3ds_arr_copy_to {ARR PMT} {
	upvar 1 $ARR U_ARR
	upvar 1 $PMT U_PMT
	set prefix "3d_secure"
	set U_PMT($prefix) 1
	foreach {n v} [array get U_ARR] {
		set U_PMT($prefix,$n) $v
	}
}


#  Copies 3d_secure information from the PMT array to the ARR
#  Assumes in the PMT array it is prefixed by
#  3d_secure,
# If removes the prefix in the array
proc 3ds_arr_copy_from {ARR PMT} {
	upvar 1 $ARR U_ARR
	upvar 1 $PMT U_PMT
	set prefix "3d_secure,"
	set prefix_len [string length $prefix]
	foreach {n v} [array get U_PMT "${prefix}*"] {
		set name [string range $n $prefix_len end]
		set U_ARR($name) $v
	}
}



proc 3ds_arr_set_pmt_info {ARR pmt_id cust_id} {
	upvar 1 $ARR U_ARR

	if {[info exists U_ARR(extra_info)]} {
		set extra_info $U_ARR(extra_info)
	} else {
		set extra_info ""
	}
	set U_ARR(pmt_id) $pmt_id
	set U_ARR(cust_id) $cust_id
}

proc 3ds_arr_get_MD {ARR} {
	upvar 1 $ARR U_ARR

	if {[info exists U_ARR(extra_info)]} {
		set extra_info $U_ARR(extra_info)
	} else {
		set extra_info ""
	}
	return [3ds_MD_pack $U_ARR(pmt_id) $U_ARR(cust_id) $U_ARR(ref) $extra_info]
}

#  Creates an encrypted string to pass through.
#  Basically it is of the format
#  Encryption is basically to stop people
#  manually submitting random calls
#
#  Format is <pmt_id>,<cust_id>,<3d_secure_ref>,<extra_info>
#  Extra info is any information that needs to be passed back to the
#  Calling process and will be customer screen dependant.
proc 3ds_MD_pack {pmt_id cust_id ref {extra_info ""}} {
	set str "$pmt_id,$cust_id,[urlencode $ref],[urlencode $extra_info]"
	set en_hex [3ds_crypt encrypt $str]

	return $en_hex
}

#  Unpacks MD value
#  returns a list {pmt_id cust_id 3d_secure_ref}
#  or an empty string if the format isn't valid
#
proc 3ds_MD_unpack {enc} {
	if {[catch {
		set str [3ds_crypt decrypt $enc]
		if {![regexp {(^[0-9]+),([0-9]+),([^,]+),(.*$)} $str _junk_ pmt_id cust_id ref_enc extra_info_enc]} {
			error "String $str is of the wrong format"
		}
	} msg]} {
		return [list ERR $msg]
	}
	set ref [urldecode $ref_enc]
	set extra_info [urldecode $extra_info_enc]

	return [list OK $pmt_id $cust_id $ref $extra_info]
}

#
#  Function to encrypt / decrypt a string
#   mode  "encrypt"|"decrypt"
#   str   string to encrypt / decrypt
proc 3ds_crypt {mode str} {
	variable 3DS_CFG
	set key $3DS_CFG(key,val)
	set type $3DS_CFG(key,type)
	#  padding to make cypher more secure
	set pad_len 8

	if {$mode == "encrypt"} {
	#  to increase security of the stream cipher we pad with
	#  random bytes
		set pad ""
		for {set i 0} {$i < $pad_len} {incr i} {
		#  We need to pad with printable characters [32 - 126] or we get into trouble
			append pad [binary format c [expr {32 + round(rand()*94)}]]
		}
		set ret [blowfish encrypt -$type $key -bin $pad$str]
	} elseif {$mode == "decrypt"} {
		set pad_hex [blowfish decrypt -$type $key -hex $str]
		set pad_ret [hextobin $pad_hex]
		set ret [string range $pad_ret $pad_len end]
	} else {
		error "3ds_crypt: invalid mode $mode supplied"
	}
	return $ret
}



# =====================================================================
# Utility procedure to identify actual CV2 code failures, based on the
# Datacash standard for coding CV2 and AVS responses.
#
# (If the check isn't performed, or the response does not specifically
# indicate so, it is not considered a failure.)
# =====================================================================
proc _cv2_code_failure cv2avs_status {

	if {$cv2avs_status == "NO DATA MATCHES" || \
		$cv2avs_status == "ADDRESS MATCH ONLY"} {
		return 1
	} else {
		return 0
	}
}

proc _avs_code_failure cv2avs_status {

	if {$cv2avs_status == "NO DATA MATCHES" || \
		$cv2avs_status == "SECURITY CODE MATCH ONLY"} {
		return 1
	} else {
		return 0
	}
}

# cc_pmt_resubmission_detection
# pmt_id - id of the payment in question
# prev_pmt_id - id of the payment previous to this one in the same request (if
#               one exists)
# status - status of the payment in question
# pg_type - payment gateway provider for payment
# threed_secure_pol - card bin 3d secure policy
#
# Check if the pmt_id supplied satifies the conditions to resubmit the payment
# without 3d secure
#
# returns 1 if resubmission required, else 0

proc cc_pmt_resubmission_detection { pmt_id
                                     prev_pmt_id
                                     status
                                     pg_type
                                     threed_secure_pol
} {

	variable CFG

	set fn {cc_pmt_resubmission_detection}

	# we can only perform this if we have :
	# policy codes switched on, 3ds gateway codes verbosely recorded,
	# application allows resubmissions, the card bin 3d secure policy allows
	# resubmits and the payment hasn't already been resubmitted

	ob_log::write INFO { => $fn '$pmt_id' \
	                            '$prev_pmt_id' \
	                            '$status' \
	                            '$pg_type' \
	                            '$threed_secure_pol'}

	if {$CFG(3ds_policy_codes) &&
	    $CFG(verbose_3ds_codes) &&
	    $CFG(3ds_resubmit_allowed) &&
	    $status == "N" &&
	    $threed_secure_pol == 0 &&
	    $prev_pmt_id == "" } {

		ob_log::write INFO {$fn detected failed payment with 3dsecure policy \
		                    allowing resubmits}

		# need to retreive all the codes as we might have redirected and not
		# be on the same request
		if { [catch {
			set rs [tb_db::tb_exec_qry cc_get_pmt_3ds_codes $pmt_id]
		} msg] } {
			ob_log::write ERROR {$fn Error retrieving 3ds codes resubmission \
			                     detection failed; $msg}
			ob_log::write INFO { <= $fn }
			return 0
		}

		if {[db_get_nrows $rs] != 1} {
			ob_log::write ERROR {$fn Error expected 1row (cc_get_pmt_3ds_codes)\
		                         resubmission detection failed}
			ob_log::write INFO { <= $fn }
			return 0
		}

		set enrol_3d_resp [db_get_col $rs 0 enrol_3d_resp]
		set auth_3d_resp  [db_get_col $rs 0 auth_3d_resp]
		set gw_ret_code   [db_get_col $rs 0 gw_ret_code]
		set gw_ret_msg    [db_get_col $rs 0 gw_ret_msg]

		db_close $rs

		ob_log::write INFO {$fn checking payment against resubmit conditions :\
		                    $pg_type|$enrol_3d_resp|$auth_3d_resp|$gw_ret_code}

		# loop through the conditions
		foreach condition $CFG(3ds_resubmit_conditions) {

			set c0 [lindex $condition 0]
			set c1 [lindex $condition 1]
			set c2 [lindex $condition 2]
			set c3 [lindex $condition 3]
			set c4 [lindex $condition 4]

			if {($pg_type == $c0 || $c0 == "*" ) &&
			    ($enrol_3d_resp == $c1 || $c1 == "*" ) &&
			    ($auth_3d_resp == $c2 || $c2 == "*" ) &&
			    ($gw_ret_code == $c3 || $c3 == "*" ) &&
				($gw_ret_msg == $c4 || $c4 == "*" )} {

				ob_log::write INFO { <= $fn }

				return 1
			}
		}
	}

	ob_log::write INFO { <= $fn }

	return 0
}

cc_pmt_init

# close namespace
}

