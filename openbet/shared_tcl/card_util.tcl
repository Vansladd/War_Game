# ==============================================================
# $Id: card_util.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================


#
# WARNING: file will be initialised at the end of the source
#


namespace eval card_util {


#
# initialisation
#
namespace export init_card_util


#
# Verification
#
namespace export verify_cust_card_all
namespace export verify_cust_card_update
namespace export verify_cust_card_card_no
namespace export verify_cust_card_start
namespace export verify_cust_card_expiry
namespace export verify_cust_card_issue_no
namespace export verify_card_not_used
namespace export verify_cust_card_ok_to_delete
namespace export verify_card_cvv2
namespace export payment_has_resp

#
# date checking
#
namespace export check_card_start
namespace export check_card_expiry


#
# returns the required fields based on bin range
#
namespace export cd_get_req_fields


#
# registering/updating/removing customer cards
#
namespace export store_reg_attempt
namespace export cd_reg_card
namespace export cd_reg_card_new
namespace export cd_delete_card
namespace export cd_reactivate_card


#
# decrypt and encrypt cards
#
namespace export card_decrypt
namespace export card_encrypt


namespace export cd_get_active
namespace export cd_get_card_data
namespace export cd_is_1pay

namespace export cd_check_prev_pmt
namespace export cd_check_if_cust_made_prev_pmt

#Retrieve card scheme
namespace export get_card_scheme

#
# store the necessary queries
#
proc init_card_util args {


	global SHARED_SQL
	global BF_DECRYPT_KEY
	global BF_DECRYPT_KEY_HEX

	# Initialise crypto settings (if necessary)
	if {![OT_CfgGet DISABLE_CRYPTO_API_INIT 0]} {
		if {![OT_CfgGet ENCRYPT_FROM_CONF 0]} {
			::cryptoAPI::init
		}
	}

	# required even if PCI switched on, some paymethds use this to do simple
	# encryptions (C2p)
	if {[set BF_DECRYPT_KEY [OT_CfgGet DECRYPT_KEY ""]] != ""} {
		set BF_DECRYPT_KEY_HEX  [bintohex $BF_DECRYPT_KEY]
	} else {
		set BF_DECRYPT_KEY_HEX  [OT_CfgGet DECRYPT_KEY_HEX]
	}

	set SHARED_SQL(get_cpm_details) {
		select
			cpm.cust_id,
			cpm.cpm_id,
			cpm.status,
			cc.start,
			cc.expiry,
			cc.issue_no,
			cc.hldr_name
		from
			tCpmCC cc,
			tCustPayMthd cpm
		where
			cc.cpm_id = ? and
			cc.cpm_id = cpm.cpm_id
	}

	set SHARED_SQL(cd_get_req_fields) {

		select
			i.scheme,
			i.scheme_name,
			s.num_digits,
			s.issue_length,
			s.start_date as start,
			s.expiry_date as expiry,
			case i.type
				when 'D' then 'DBT'
				when 'C' then 'CDT'
			end as type,
			s.threed_secure_pol
		from
			tCardScheme s,
			tCardSchemeInfo i
		where
			s.scheme=i.scheme
		and s.bin_lo = (select max(c.bin_lo) from tCardScheme c where c.bin_lo <= ?)
		and s.bin_hi >= ?
	}
	set SHARED_SQL(cache,cd_get_req_fields) 600


	set SHARED_SQL(cd_get_card_info) {
		select
			bank,
			country,
			allow_dep,
			allow_wtd
		from
			tCardInfo
		where
			card_bin = ?
	}
	set SHARED_SQL(cache,cd_get_card_info) 600

	set SHARED_SQL(cd_cpm_ins_cc) {
		execute procedure pCPMInsCC (
			p_cust_id=?,
			p_oper_id=?,
			p_oper_notes=?,
			p_enc_card_no=?,
			p_ivec=?,
			p_data_key_id=?,
			p_card_bin=?,
			p_start=?,
			p_expiry=?,
			p_issue_no=?,
			p_type=?,
			p_desc=?,
			p_auth_dep=?,
			p_auth_wtd=?,
			p_transactional=?,
			p_allow_duplicates=?,
			p_hldr_name=?,
			p_allow_multiple=?,
			p_site_operator_id=?,
			p_acct_type_dups=?,
			p_cpm_id=?,
			p_enc_with_bin=?,
			p_status=?
		)
	}

	set SHARED_SQL(cd_hash_ins_cc) {
		execute procedure pCPMInsCCHash (
			p_cc_hash = ?,
			p_enc_cpm_id = ?,
			p_ivec = ?,
			p_data_key_id = ?,
			p_rand = ?,
			p_transactional = ?
		)
	}

	set SHARED_SQL(cd_cpm_remove) {
		update tCustPayMthd
		set
			status = 'X'
		where
			cpm_id = ?

	}

	set SHARED_SQL(cd_cpm_reactivate) {
		update tCustPayMthd
		set
			status = 'A'
		where
			cust_id = ? and
			cpm_id = ?
	}

	set SHARED_SQL(cd_cust_card_allowed) {
		select
			allow_card
		from
			tCustomer
		where
			cust_id = ?
	}

	set SHARED_SQL(cd_card_block) {
		execute procedure pChkCardBlock (
			p_card_hash = ?,
			p_bin = ?
		)
	}

	if {[OT_CfgGet FUNC_SITE_CARD_REGISTERED 0]} {
		# check if there is a conflict only on this site operator
		set SHARED_SQL(cd_card_used_and_active) {
			select
				cc.cust_id,
				cc.cpm_id,
				cpm.status,
				cc.start,
				cc.expiry,
				cc.issue_no,
				cc.hldr_name
			from
				tCpmCC cc,
				tCustPayMthd cpm,
				tCustomer cust,
				tAcct a,
				tChannel channel
			where
				cpm.cpm_id      = ? and
				cpm.pay_mthd    = 'CC' and
				cpm.cpm_id      = cc.cpm_id and
				cust.cust_id    = cpm.cust_id and
				cust.cust_id    = a.cust_id and
				a.owner         <> 'D' and
				cust.source     = channel.channel_id and
				channel.site_operator_id = ?
		}
	} elseif {[OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]} {
		# check if there is a conflict only if the acct types match
		set SHARED_SQL(cd_card_used_and_active) {
			select
				cc.cust_id,
				cpm.cpm_id,
				cpm.status,
				cc.start,
				cc.expiry,
				cc.issue_no,
				cc.hldr_name
			from
				tCpmCC cc,
				tCustPayMthd cpm,
				tAcct a
			where
				cpm.cpm_id = ? and
				cpm.pay_mthd = 'CC' and
				cpm.cpm_id = cc.cpm_id and
				cpm.cust_id = a.cust_id and
				a.acct_type = ? and
				a.owner <> 'D'
		}
	} else {
		set SHARED_SQL(cd_card_used_and_active) {
			select
				cc.cust_id,
				cpm.cpm_id,
				cpm.status,
				cc.start,
				cc.expiry,
				cc.issue_no,
				cc.hldr_name
			from
				tCpmCC cc,
				tCustPayMthd cpm,
				tAcct a
			where
				cpm.cpm_id      =  ? and
				cpm.pay_mthd    =  'CC' and
				cpm.cpm_id      = cc.cpm_id and
				cpm.cust_id     = a.cust_id and
				a.owner         <> 'D'
		}
	}

	set SHARED_SQL(cd_cpm_details) {
		select
			cc.cpm_id,
			cc.start,
			cc.expiry,
			cc.issue_no,
			cc.hldr_name
		from
			tCpmCC cc,
			tCustPayMthd cpm
		where
			cc.cpm_id       = cpm.cpm_id and
			cpm.status      = 'A' and
			cpm.cpm_id      = ?
	}

	set SHARED_SQL(get_site_operator_id) {
		select
			site_operator_id
		from
			tchannel
		where
			channel_id = ?
	}

	set SHARED_SQL(get_cust_source_channel) {
		select
			source
		from
			tcustomer
		where
			cust_id = ?
	}

	set SHARED_SQL(get_cust_acct_type) {
		select
			acct_type
		from
			tacct
		where
			cust_id = ?
	}

	set SHARED_SQL(cd_active_cust_card) {
		select
			m.cpm_id,
			m.status,
			m.cr_date,
			cpm.enc_card_no,
			cpm.ivec,
			cpm.data_key_id,
			cpm.start,
			cpm.expiry,
			cpm.issue_no,
			cpm.card_bin,
			cpm.hldr_name,
			cpm.enc_with_bin,
			i.country,
			i.scheme,
			i.bank,
			m.status_wtd,
			m.status_dep,
			m.auth_dep,
			si.scheme_name,
			case si.type
				when 'D' then 'DBT'
				when 'C' then 'CDT'
			end as type
		from
			tCustPayMthd m,
			tCpmCC       cpm,
			tCardInfo    i,
			tCardSchemeInfo si,
			tCardScheme s
		where
			cpm.cpm_id   = m.cpm_id
			and cpm.card_bin = i.card_bin
			and s.bin_lo = (
				select
					max(c.bin_lo)
				from
					tCardScheme c
				 where
					c.bin_lo <= cpm.card_bin
			)
			and s.bin_hi >= cpm.card_bin
			and i.scheme = si.scheme
			and m.status     = 'A'
			and m.cust_id    = ?
	}

	set SHARED_SQL(cd_get_cards_expiry) {
		select
			cc.expiry
		from
			tCustPayMthd m,
			tCPMCC cc
		where
			m.cust_id = ?
			and cc.cpm_id = m.cpm_id
			and m.status = 'A'
	}

	set SHARED_SQL(cd_get_last_successfully_used_cpm) {
		select
			p.cr_date,
			m.cpm_id
		from
			tCustPayMthd m,
			tCpmCC cpm,
			tPmt p
		where
			m.cust_id = ?
			and m.status = 'A'
			and m.cpm_id = cpm.cpm_id
			and m.cpm_id = p.cpm_id
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

	set SHARED_SQL(cd_card_data) {
		select
			m.cpm_id,
			m.status,
			m.cr_date,
			cpm.enc_card_no,
			cpm.ivec,
			cpm.data_key_id,
			cpm.start,
			cpm.expiry,
			cpm.issue_no,
			cpm.card_bin,
			cpm.hldr_name,
			cpm.enc_with_bin,
			i.country,
			i.scheme,
			i.bank,
			m.status_wtd,
			m.status_dep,
			m.auth_dep,
			si.scheme_name,
			case si.type
				when 'D' then 'DBT'
				when 'C' then 'CDT'
			end as type
		from
			tCustPayMthd m,
			tCpmCC       cpm,
			tCardInfo    i,
			tCardSchemeInfo si,
			tCardScheme s
		where
			cpm.cpm_id   = m.cpm_id
			and cpm.card_bin = i.card_bin
			and s.bin_lo = (
				select
					max(c.bin_lo)
				from
					tCardScheme c
				 where
					c.bin_lo <= cpm.card_bin
			)
			and s.bin_hi >= cpm.card_bin
			and i.scheme = si.scheme
			and m.status     = 'A'
			and m.cpm_id     = ?
			and m.cust_id    = ?
	}

	set SHARED_SQL(cd_card_data_all) {
	select
			m.cpm_id,
			m.status,
			m.cr_date,
			cpm.enc_card_no,
			cpm.ivec,
			cpm.data_key_id,
			cpm.start,
			cpm.expiry,
			cpm.issue_no,
			cpm.card_bin,
			cpm.hldr_name,
			cpm.enc_with_bin,
			i.country,
			i.scheme,
			i.bank,
			m.status_wtd,
			m.status_dep,
			m.auth_dep,
			si.scheme_name,
			case si.type
				when 'D' then 'DBT'
				when 'C' then 'CDT'
			end as type
		from
			tCustPayMthd m,
			tCpmCC       cpm,
			tCardInfo    i,
			tCardSchemeInfo si,
			tCardScheme s
		where
			cpm.cpm_id   = m.cpm_id
			and cpm.card_bin = i.card_bin
			and s.bin_lo = (
				select
					max(c.bin_lo)
				from
					tCardScheme c
				 where
					c.bin_lo <= cpm.card_bin
			)
			and s.bin_hi >= cpm.card_bin
			and i.scheme = si.scheme
			and m.cpm_id     = ?
			and m.cust_id    = ?
	}

	set SHARED_SQL(cd_active_and_suspended_cust_card) {
		select
			m.cpm_id,
			m.status,
			m.cr_date,
			cpm.enc_card_no,
			cpm.ivec,
			cpm.data_key_id,
			cpm.start,
			cpm.expiry,
			cpm.issue_no,
			cpm.card_bin,
			cpm.hldr_name,
			cpm.enc_with_bin,
			i.country,
			i.scheme,
			i.bank,
			m.status_wtd,
			m.status_dep,
			si.scheme_name,
			m.auth_dep,
			case si.type
				when 'D' then 'DBT'
				when 'C' then 'CDT'
			end as type
		from
			tCustPayMthd m,
			tCpmCC       cpm,
			tCardInfo i,
			tCardSchemeInfo si,
			tCardScheme s
		where
			cpm.cpm_id   = m.cpm_id
			and cpm.card_bin = i.card_bin
			and s.bin_lo = (
				select
					max(c.bin_lo)
				from
					tCardScheme c
				 where
					c.bin_lo <= cpm.card_bin
			)
			and s.bin_hi >= cpm.card_bin
			and i.scheme = si.scheme
			and m.status     in ('A', 'S')
			and m.cust_id    = ?
	}

	set SHARED_SQL(cd_card_for_pmt_id) {
		select
			m.cpm_id,
			m.status,
			m.cr_date,
			cpm.enc_card_no,
			cpm.ivec,
			cpm.data_key_id,
			cpm.start,
			cpm.expiry,
			cpm.issue_no,
			cpm.card_bin,
			cpm.hldr_name,
			cpm.enc_with_bin,
			i.country,
			i.scheme,
			m.status_wtd,
			m.status_dep,
			s.threed_secure_pol
		from
			tCustPayMthd m,
			tCpmCC cpm,
		    outer tCardInfo i,
			outer tCardScheme s,
		    tPmt p
		where
			cpm.cpm_id = m.cpm_id and
			cpm.card_bin = i.card_bin and
			(select max(c.bin_lo) from tCardScheme c where c.bin_lo <= cpm.card_bin) = s.bin_lo and
			cpm.card_bin <= s.bin_hi and
			m.pay_mthd = 'CC' and
			p.cpm_id = cpm.cpm_id
			and p.pmt_id =?
	}

	set SHARED_SQL(cd_check_prev_pmt) {
		select first 1
			p.pmt_id
		from
			tpmt p,
			tcpmcc c
		where
			p.cpm_id  = c.cpm_id and
			c.cpm_id  = ? and
			c.cust_id = ? and
			p.status <> 'N'
	}


	set SHARED_SQL(cd_check_if_cust_made_prev_pmt) {
		select
			min(p.pmt_id)
		from
			tpmt p,
			tcpmcc c
		where
			p.cpm_id = c.cpm_id and
			c.cust_id = ? and
			p.status <> 'N'
	}

	set SHARED_SQL(get_card_scheme) {

		select first 1
			scheme,
			issue_length,
			start_date
		from
			tcardscheme s
		where
			s.bin_lo = (select max(c.bin_lo) from tCardScheme c where c.bin_lo <= ?)
		and s.bin_hi >= ?
	}
	set SHARED_SQL(cache,get_card_scheme) 600

	set SHARED_SQL(cd_get_issuer) {
		select
			bank,
			country
		from
			tCardInfo t
		where
			t.card_bin = ?
	}
	set SHARED_SQL(cache,cd_get_issuer) 600

	set SHARED_SQL(store_reg_attempt) {
		execute procedure pInsCardReg (
			p_cust_id = ? ,
			p_enc_card_no = ?,
			p_ivec = ?,
			p_data_key_id = ?,
			p_card_bin = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_source = ?,
			p_ipaddr = ?,
			p_enc_with_bin = ?
		)
	}

	set SHARED_SQL(store_reg_attempt_hash) {
		execute procedure pInsCardRegHash (
			p_reg_hash = ?,
			p_enc_reg_id = ?,
			p_ivec = ?,
			p_data_key_id = ?,
			p_rand = ?
		)
	}

	set SHARED_SQL(cd_cust_acct_detail) {
		select
			c.username,
			a.balance,
			a.ccy_code,
			c.password,
			a.acct_id
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id = a.cust_id and
			c.cust_id = ?
	}

	set SHARED_SQL(cd_check_prev_xfers) {
		select first 1
			x.tx_id
		from
			tXferStatus x,
			tAcct a
		where
			x.acct_id = a.acct_id and
			a.cust_id = ?
	}

	set SHARED_SQL(cd_check_unsettled_bets) {
		select
			a.acct_id
		from
			tAcct a
		where
			a.cust_id = ? and
			(
			exists (select
					bu.bet_id
				from
					tBetUnstl bu
				where
					bu.acct_id = a.acct_id)
			or
			exists (select
					x.xgame_bet_id
				from
					tXGameSub s,
					tXGameBet x
				where
					x.settled_at is null and
					s.xgame_sub_id = x.xgame_sub_id and
					s.acct_id = a.acct_id)
			or
			exists (select
					pu.pool_bet_id
				from
					tPoolBetUnstl pu
				where
					pu.acct_id = a.acct_id)
			)
	}

	# all transactions since date X with status Y, Z ...
	set SHARED_SQL(last_transactions_by_status) {
		select first 1
			p.pmt_id
		from
			tPmt p
		where
			p.acct_id = ? and
			p.cr_date between ? and CURRENT and
			p.status in (?,?,?,?)
	}

	# Are there any open multi-state FOG games?
	set SHARED_SQL(cd_check_multi_state_games) {
		select
			gs.cg_game_id,
			jc.status_table
		from
			tAcct a,
			tCGAcct ga,
			tCGGameSummary gs,
			tCGGame g,
			tCGJavaClass jc
		where
			a.cust_id = ? and
			ga.acct_id = a.acct_id and
			gs.cg_acct_id = ga.cg_acct_id and
			gs.state = 'O' and
			gs.cg_id = g.cg_id and
			g.java_class = jc.java_class and
			jc.multi_state = 'Y'
	}

	# Are there any Netballs subs in the last 3 months that aren't settled?
	set SHARED_SQL(cd_check_unsettled_netballs) {
		select first 1
			s.cust_id
		from
			tNmbrSub s
		where
			s.cust_id = ? and
			s.cr_date > CURRENT - interval(92) day to day and
			s.status <> 'S'
	}

	set SHARED_SQL(pmt_mthd_has_resp_by_cpm_id) {

		select
			case when cvv2_resp is null or cvv2_resp = '' then
				0
			else
				1
			end as has_resp,
			type
		from
			tCPMCC
		where
			cpm_id = ?
	}

	set SHARED_SQL(recent_goldenguineas_stake) {

		select first 1
			x.xfer_id,
			x.cr_date
		from
			tXSysXfer x,
			tXSysHost h
		where
			h.name = 'Golden Guineas' and
			h.system_id = x.system_id and
			x.acct_id = ? and
			x.cr_date > current - ? units hour
	}

	if {[OT_CfgGet FUNC_CARD_CHANGE_CTXM_GAME 0]} {
		set ctxm_games [OT_CfgGet CTXM_GAME_NAMES [list ""]]
		set ctxm_string ""
		for {set j 0} {$j < [llength $ctxm_games]} {incr j} {
			append ctxm_string "'[lindex $ctxm_games $j]'"
			if {$j != [expr [llength $ctxm_games] - 1]} {
				append ctxm_string ","
			}
		}

		set SHARED_SQL(has_played_ctxm) [subst {

			select
				first 1
					x.xfer_id
			from
				tXSysXfer x,
				tXSysHost h
			where
				h.name in ($ctxm_string) and
			h.system_id = x.system_id and
			x.acct_id = ?
		}]
	}

	if {[OT_CfgGet FUNC_CARD_CHANGE_UNKNOWN_XFER 0]} {
		set known_host [OT_CfgGet VALID_CARD_CHANGE_XSYSHOST [list ""]]
		set host_string ""
		for {set i 0} {$i < [llength $known_host]} {incr i} {
			append host_string "'[lindex $known_host $i]'"
			if {$i != [expr [llength $known_host] - 1]} {
				append host_string ","
			}
		}

		set SHARED_SQL(chk_unknown_host_xfer) [subst {
			select first 1
				h.name
			from
				tXSysXfer x,
				tXSysHost h
			where
				x.acct_id = ? and
				h.system_id = x.system_id and
				h.name not in ($host_string)
		}]
	}

	set SHARED_SQL(get_cards_with_hash) {
		select
			cc_hash_id,
			enc_cpm_id,
			ivec,
			data_key_id
		from
			tCpmCCHash
		where
			cc_hash = ?
	}

	# Encryption/decryption monitor messages require the username of the adminuser
	# making the request, however the particular function in here may instead have
	# the user_id instead, use this to get the username
	set SHARED_SQL(get_admin_username) {
		select
			username
		from
			tAdminUser
		where
			user_id = ?
	}

	# Various update queries to be performed in the (hopefully unlikely) event that we have
	# discovered some corrupted encrypted data in the db
	set SHARED_SQL(update_pmt_gate_acct_enc_fail) {
		update tPmtGateAcct set
			enc_status = ?,
			enc_date   = CURRENT
		where
			pg_acct_id = ?
	}

	set SHARED_SQL(update_card_block_enc_fail) {
		update tCardBlock set
			enc_status = ?,
			enc_date   = CURRENT
		where
			card_block_id = ?
	}

	set SHARED_SQL(update_cpm_cc_enc_fail) {
		update tCPMCC set
			enc_status = ?,
			enc_date   = CURRENT
		where
			cpm_id = ?
	}

	set SHARED_SQL(update_cpm_cc_hash_enc_fail) {
		update tCPMCCHash set
			enc_status = ?,
			enc_date   = CURRENT
		where
			cc_hash_id = ?
	}

	set SHARED_SQL(update_card_reg_enc_fail) {
		update tCardReg set
			enc_status = ?,
			enc_date   = CURRENT
		where
			card_reg_id = ?
	}

	set SHARED_SQL(update_card_reg_hash_enc_fail) {
		update tCardRegHash set
			enc_status = ?,
			enc_date   = CURRENT
		where
			reg_hash_id = ?
	}

	set SHARED_SQL(update_risk_guard_acct_enc_fail) {
		update tRGHost set
			enc_status = ?,
			enc_date   = CURRENT
		where
			rg_host_id = ?
	}

	set SHARED_SQL(update_c3_call_enc_fail) {
		update tC3Call set
			enc_status = ?,
			enc_date   = CURRENT
		where
			call_id = ?
	}

	set SHARED_SQL(update_cust_ident_enc_fail) {
		update tCustIdent set
			enc_status = ?,
			enc_date   = CURRENT
		where
			cust_id = ?
	}

	set SHARED_SQL(update_rg_host_enc_fail) {
		update tRGHost set
			enc_status = ?,
			enc_date   = CURRENT
		where
			rg_host_id = ?
	}

	# Check to see if the account as a certain type of manual adjustment.
	# This is used for Rio Bay and friends.
	#
	set SHARED_SQL(cd_has_man_adj) {
		select
			first 1 *
		from
			tManAdj m,
			tAcct   a
		where
			m.acct_id = a.acct_id
		and a.cust_id = ?
		and	m.type    = ?
	}

	# Used for Cantor financials.
	# Could this be better written?
	#
	set SHARED_SQL(cd_get_acct_by_xfer) {
		select
			a.acct_id
		from
			tAcct a
		where
			a.cust_id = ?
		and exists (
			select
				x.xfer_id
			from
				tXSysXfer x,
				tXSysHost h
			where
				x.acct_id   = a.acct_id
			and x.system_id = h.system_id
			and h.name      = ?
		)
	}

	# Get the customer's username.
	#
	set SHARED_SQL(cd_get_cust_username) {
		select
			username
		from
			tCustomer
		where
			cust_id = ?
	}

	set SHARED_SQL(insert_status_flag) {
		execute procedure pInsCustStatusFlag (
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_reason = ?,
			p_transactional = ?
		)
	}

	set SHARED_SQL(insert_replacement_card) {
		execute procedure pInsCPMReplacementLink (
			p_orig_cpm_id = ?,
			p_new_cpm_id  = ?
		)
	}

	set SHARED_SQL(update_deposit_check) {
		update tCustPayMthd set deposit_check = 'N' where cpm_id = ?
	}

}


#
# Which fields are valid for a particular card?
#
proc cd_get_req_fields {first_6 arry {use_dummy_scheme 0} } {

	upvar 1 $arry CARDDATA

	#
	# Make sure the data storage array is empty
	#
	catch {unset CARDDATA}
	set CARDDATA(first_6)       $first_6
	set CARDDATA(bank)          ""
	set CARDDATA(country)       ""
	set CARDDATA(type)          ""
	set CARDDATA(name)          ""
	set CARDDATA(allow_dep)     "Y"
	set CARDDATA(allow_wtd)     "Y"
	set CARDDATA(num_digits)    ""
	set CARDDATA(issue_length)  ""
	set CARDDATA(start)         ""
	set CARDDATA(expiry)        ""
	set CARDDATA(scheme)        ""
	set CARDDATA(scheme_name)	"unknown"


	ob::log::write INFO {cd_get_req_fields bin num is $first_6}
	if {$use_dummy_scheme || [OT_CfgGet FORCE_DUMMY_SCHEME 0]} {
		#
		# Using a dummy scheme for verification. Card does not have a
		# bin range listed in tCardcheme but we still want to register the card.
		#
		ob::log::write INFO {Using a Dummy scheme for registering card}

		set CARDDATA(type)          [reqGetArg card_type]
		set CARDDATA(allow_dep)     "Y"
		set CARDDATA(allow_wtd)     "N"
		set CARDDATA(start)         "Y"
		set CARDDATA(expiry)        "Y"

		return 1
	}


	#
	# tCardInfo check
	#
	if {[catch {set rs [tb_db::tb_exec_qry cd_get_card_info $first_6]} msg]} {
		ob::log::write ERROR {failed to get_card_info: $msg}
		return 0
	}

	if {[db_get_nrows $rs] == 1} {
		# otherwise store the information
		foreach f [db_get_colnames $rs] {
		set CARDDATA($f) [db_get_col $rs 0 $f]
		}
	}

	# if there is no row in tcardinfo then presume not allowed
	if {[db_get_nrows $rs] == 0} {
		   ob::log::write INFO {No entry in tCardInfo}
		   db_close $rs
		   return 0
	}

	db_close $rs

	#
	# Required fields check - this is fatal if card not in db
	#
	if {[catch {
		set rs [tb_db::tb_exec_qry cd_get_req_fields $first_6 $first_6]
	} msg]} {
		ob::log::write ERROR {failed to cd_get_req_fields: $msg}
		return 0
	}

	#
	# store the required fields information if available
	#
	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR \
			{incorrect num rows for cd_get_req_fields: [db_get_nrows $rs]}
		return 0
	}

	foreach f [db_get_colnames $rs] {
		set CARDDATA($f) [db_get_col $rs 0 $f]
	}

	db_close $rs

	return 1
}


#
# Store attempts to register a credit card
# for fraud screening purposes
# This now starts a transaction for the insert into tCardReg, unless already in one (admin)
#
proc store_reg_attempt {
	cust_id card_no channel {type ""} {amount 0} {ipaddr "N/A"} {in_tran "N"}
} {

	set card_bin  [string range $card_no 0 5]
	set card_rem  [string range $card_no 6 end]
	set card_hash [md5 $card_no]

	if {![OT_CfgGet ENCRYPT_WITH_BIN 0]} {
		set enc_rs [card_util::card_encrypt $card_rem "Storing card registration attempt" $cust_id]
		set enc_with_bin "N"
	} else {
		set enc_rs [card_util::card_encrypt  [string range $card_no 8 end][string range $card_no 0 7] "Storing card registration attempt" $cust_id]
		set enc_with_bin "Y"
	}

	if {[lindex $enc_rs 0] == 0} {
		ob::log::write ERROR {Failed to encrypt card number: [lindex $enc_rs 1]}
		return
	}

	set enc_card_no [lindex [lindex $enc_rs 1] 0]
	set ivec        [lindex [lindex $enc_rs 1] 1]
	set data_key_id [lindex [lindex $enc_rs 1] 2]

	set payment_sort "-"
	if {$type == "DEP"} {
		set payment_sort "D"
	} elseif {$type == "WTD"} {
		set payment_sort "W"
	}

	if {$channel == "I" && $ipaddr == "N/A"} {
		set ipaddr [reqGetEnv "REMOTE_ADDR"]
	}

	# Do the whole insert process in a transaction, so we can rollback if either
	# query fails
	if {$in_tran == "N"} {
		tb_db::tb_begin_tran
	}

	# First we store the card number / pmt details in tCardReg
	if {[catch {
		set res [tb_db::tb_exec_qry store_reg_attempt \
			$cust_id \
			$enc_card_no \
			$ivec \
			$data_key_id \
			$card_bin \
			$payment_sort \
			$amount \
			$channel \
			$ipaddr \
			$enc_with_bin]
	} msg]} {
		ob::log::write ERROR {Failed to insert card registration attempt: $msg}
		tb_db::tb_rollback_tran
		return
	}
	set reg_id [db_get_coln $res 0]
	db_close $res

	# Now we encrypt the card number and select a random number to use to store
	# and entry for this attempt in tCardRegHash
	set reg_enc_rs [encrypt_cpmid $reg_id "Encrypting card_reg_id for tCardRegHash" $cust_id]

	if {[lindex $reg_enc_rs 0] == 0} {
		ob::log::write ERROR {Failed to encrypt id: [lindex $reg_enc_rs 1]}
		if {$in_tran == "N"} {
			tb_db::tb_rollback_tran
		}
		return
	}

	# Extract the encrypted cpm id and data_key_id from the result
	set enc_reg_id  [lindex [lindex $reg_enc_rs 1] 0]
	set ivec        [lindex [lindex $reg_enc_rs 1] 1]
	set data_key_id [lindex [lindex $reg_enc_rs 1] 2]

	# Generate a random number between 0 and 1 (used to determine where in the table
	# to insert the new data
	set rand [format %.4f [expr rand()]]

	# We've now got an id, now to insert a hash table entry for this card
	if {[catch {set rs [tb_db::tb_exec_qry store_reg_attempt_hash\
		$card_hash \
		$enc_reg_id \
		$ivec \
		$data_key_id \
		$rand]} msg]
	} {
		ob::log::write ERROR {Failed to insert customers hashed card details: $msg}
		if {$in_tran == "N"} {
			tb_db::tb_rollback_tran
		}
		return
	}

	# Inserted both required entries successfully, so commit transaction
	if {$in_tran == "N"} {
		tb_db::tb_commit_tran
	}
}


#
# verifies credit card details (without calling payment gateway)
#
proc verify_cust_card_all {
	{do_length "Y"}
	{debit_acct "Y"}
	{cust_id -1}
	{override_allow_duplicate_card 0}
	{use_dummy_scheme 0}
	{acct_type -1}
	{site_operator_id -1}
	{check_for_duplicate_card 1}
} {

	#
	# Retrieve some parameters
	#
	set card_no      [reqGetArg card_no]
	set start        [reqGetArg start]
	set expiry       [reqGetArg expiry]
	set issue_no     [reqGetArg issue_no]
	set hldr_name    [reqGetArg hldr_name]
	set has_resp     [reqGetArg has_resp]
	set cvv2         [reqGetArg cvv2]
	set depwtd       [reqGetArg depwtd]
	set acct_type    [reqGetArg acct_type]

	# strip spaces from card number
	regsub -all {[^0-9]} $card_no "" card_no

	array set CARDDATA ""
	if {[OT_CfgGet ENTROPAY 0]} {
		set entropy_id [entropay::identify $card_no]
		if {[lindex $entropy_id 0]} {
			#The card number was a 24 digit encrypted number
			#Set the card_no to be the decrypted to 16 char
			set card_no [lindex $entropy_id 1]
		}
	}

	#
	# grab data from tCardScheme to check against
	#
	if {
		[cd_get_req_fields \
			[string range $card_no 0 5] CARDDATA $use_dummy_scheme] == 0
	} {
		ob::log::write INFO {verify_cust_card_all:\
			returning from cd_get_req_fields: PMT_CARD_UNKNWN}
		return [list 0 "Unknown card type" PMT_CARD_UNKNWN]
	}

	# check the card no.
	set card_no_result \
		[verify_cust_card_card_no $card_no CARDDATA $do_length $debit_acct]
	if {[lindex $card_no_result 0] != 1 && [lindex $card_no_result 0] != "OK"} {
		ob::log::write INFO {verify_cust_card_all:\
			returning from verify_cust_card_card_no:\
			card_no_result=$card_no_result}
		return $card_no_result
	}

	#
	# check the start date
	#
	set start_result [verify_cust_card_start $start CARDDATA]

	if {![lindex $start_result 0]} {
		ob::log::write INFO {verify_cust_card_all:\
			returning from verify_cust_card_start: start_result=$start_result}
		return $start_result
	}

	if {[lindex $start_result 1] == "OK_BLANK"} {
		reqSetArg start [set start ""]
	}

	#
	# check the expiry
	#
	set expiry_result [verify_cust_card_expiry $expiry CARDDATA]
	if {![lindex $expiry_result 0]} {
		ob::log::write INFO {verify_cust_card_all:\
			returning from verify_cust_card_expiry: expiry_result=$expiry_result}
		return $expiry_result
	}

	#
	# Issue no.
	#
	if {!($use_dummy_scheme || [OT_CfgGet FORCE_DUMMY_SCHEME 0])} {
		set issue_result [verify_cust_card_issue_no $issue_no CARDDATA]
		if {![lindex $issue_result 0]} {
			ob::log::write INFO {verify_cust_card_all:\
				returning from verify_cust_card_issue_no:\
				issue_result=$issue_result}
			return $issue_result
		}

		if {[lindex $issue_result 1] == "OK_BLANK"} {
			reqSetArg issue_no [set issue_no ""]
		}
	}

	#
	# Check the CardHolder name
	#
	if {[regexp {[][${}\\]} $hldr_name]} {
		return [list 0 "invalid txt in cardholder's field" CUST_VAL_HLDR_NAME_1]
	}

	#
	# Check cvv2 number, only if firts time usage
	#
	if {$has_resp==0 && $depwtd == "DEP" && $CARDDATA(scheme) != "LASR"} {
		if {![verify_card_cvv2 $cvv2]} {
			return [list 0 "invalid CSC number" CUST_VAL_NO_CSC]
		}
	}

	#
	# now we know that the args are in the correct format, check against
	# items in the db
	#

	# check card has not been explicitly unblocked
	if {![verify_card_not_blocked $card_no -1]} {
		ob::log::write INFO {verify_cust_card_all: returning from\
			verify_card_not_blocked: card not allowed (1)}
		return [list 0 "card not allowed (1)" PMT_CC_BLOCKED]
	}

	if {$check_for_duplicate_card} {
		# check card registered against another customer
		if {![verify_card_not_used $card_no $cust_id $acct_type $site_operator_id]} {

			if {$override_allow_duplicate_card==1} {
				ob::log::write INFO {verify_cust_card_all:\
					returning from verify_card_not_used:\
					card already active on another account: allowing override}
			} else {
				if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {
					set msg "card already registered on another account"
				} else {
					set msg "card already active on another account"
				}
				ob::log::write INFO {verify_cust_card_all:\
					returning from verify_card_not_used:$msg}
				return [list -1 $msg PMT_USED]
			}
		}
	}
	return [list 1]
}

#
# verifies credit card number
#
proc verify_cust_card_card_no {
	card_no info_array {do_length Y} {force_db "Y"}
} {

	upvar 1 $info_array card_info

	regsub -all {[^0-9]} $card_no "" card_no

	if {$card_no == ""} {
		return [list 0 "invalid card no." PMT_CARD]
	}

	# check for invalid card number
	if {(![regexp {^[0-9]+$} $card_no all dummy])} {
		return [list 0 "invalid card no." PMT_CARD]
	}

	# if neither deposit or withdrawal are not allowed then bail
	if {$card_info(allow_dep) == "N" && $card_info(allow_wtd) == "N"} {
		ob::log::write INFO {Rejecting card with PMT_RX}
		return [list 0 "card not allowed" PMT_RX]
	}

	# if debit account then enforce debit card and dep/wtd method
	if {$force_db == "Y"} {

		# check we have a debit card
		if {$card_info(type) != "DBT"} {
			return [list 0 "not a debit card" PMT_NO_DEBIT]
		}

		# card must support deposit and withdrawal methods
		if {$card_info(allow_dep) == "N"} {
			return [list 0 "deposits not allowed from this card" PMT_NODEP]
		}
		if {$card_info(allow_wtd) == "N"} {
			return [list 0 "withdrawals not allowed to this card" PMT_NOWITH]
		}
	}

	# do the checksum test
	if {![do_checksum $card_no]} {
		return [list 0 "card number incorrect (failed checksum)" PMT_CARD]
	}


	# check between 13 and 19 digits long
	if {([string length $card_no] < 13 || [string length $card_no] > 19)} {
		ob::log::write DEBUG {"Checking card_ no"--$card_no }
		return [list 0 "wrong number of digits in card no." PMT_CARD]
	}


	if {$do_length != "Y"} {
		return OK
	}

	# also check
	if {$card_info(num_digits) > 0} {
		ob::log::write DEBUG {"Checking Card no : $card_no "  $card_info(num_digits) -- [string length $card_no] }
		if {[string length $card_no] != $card_info(num_digits)} {
			return [list \
				0 \
				"wrong number of digits ($card_info(num_digits))" \
				PMT_CARD]
		}
	}

	return [list 1]
}


#
# Does a rather complicated check to see if the card number is ok
#
proc do_checksum {card_no} {

	regsub -all {[^0-9]} $card_no "" card_no
	set even [expr {!([string length $card_no]%2)}]

	foreach i  [split $card_no ""] {
		if $even {incr i $i}
		append t $i
		set even [expr !$even]
	}
	expr ([join [split $t ""] +])%10==0
}


#
# verify a cards start date
#
proc verify_cust_card_start {start info_array} {

	upvar 1 $info_array card_info

	#
	# check start date in correct format (if required)
	#
	if {$card_info(start) == "Y"} {

		if {![check_card_start $start]} {
			return [list 0 "check start date" PMT_STRT]
		}

	} elseif {$card_info(start) == "N"} {

		if {$start != ""} {
			return [list 1 OK_BLANK]
		}
	}

	return [list 1 OK]
}


#
# check card start date
#
proc check_card_start {start} {

	# split the date
	if { ![regexp {^([01][0-9])\/([0-9][0-9])$} \
			$start junk start_month start_year] } {
		return 0
	}


	#
	# remove any preceding zeros
	#
	set mnth_cmp [string trimleft $start_month 0]
	set year_cmp [string trimleft $start_year 0]
	set year_cmp [expand_yr $year_cmp]

	#
	# check month in range 1-12
	#
	if {$mnth_cmp == "" || [expr $mnth_cmp < 1 || $mnth_cmp > 12]} {
		return 0
	}

	#
	# get current date
	#
	set mnth [string trimleft [clock format [clock seconds] -format "%m"] 0]
	set year [string trimleft [clock format [clock seconds] -format "%Y"] 0]


	#
	# check card has started
	#
	if {[expr $year < $year_cmp] || \
		[expr $year == $year_cmp] && [expr $mnth < $mnth_cmp]} {

		return 0
	}

	return 1
}


#
# verify a cards expiry date
#
proc verify_cust_card_expiry {expiry info_array} {

	upvar 1 $info_array card_info

	#
	# check expiry date in correct format (if required)
	#
	if {$card_info(expiry) == "Y"} {

		if {![check_card_expiry $expiry]} {
			return [list 0 "check expiry date" PMT_EXPR]
		}

	} elseif {$card_info(expiry) == "N"} {

		if {$expiry != ""} {
			return [list 0 "card should not have an expiry date" PMT_EXPR]
		}
	}

	return [list 1]
}


#
# check card expiry date
# returns 0 if expired
# 1 if not expired
proc check_card_expiry {expiry} {

	# split the date
	if {![regexp {^([01][0-9])\/([0-9][0-9])$} \
			$expiry junk expiry_month expiry_year]} {
		return 0
	}

	#
	# remove any preceding zeros
	#
	set mnth_cmp [string trimleft $expiry_month 0]
	set year_cmp [string trimleft $expiry_year 0]
	set year_cmp [expand_yr $year_cmp]

	#
	# check month in range 1-12
	#
	if {$mnth_cmp == "" || [expr $mnth_cmp < 1 || $mnth_cmp > 12]} {
		return 0
	}


	#
	# get current date
	#
	set mnth [string trimleft [clock format [clock seconds] -format "%m"] 0]
	set year [string trimleft [clock format [clock seconds] -format "%Y"] 0]


	#
	# test
	#
	if {[expr $year > $year_cmp] || \
		[expr $year == $year_cmp] && [expr $mnth > $mnth_cmp]} {
		return 0
	}

	return 1
}


#
# verify a cards issue no
#
proc verify_cust_card_issue_no {issue_no info_array} {

	upvar 1 $info_array card_info

	# If issue number length is 0, ignore it as it's not required
	if {$card_info(issue_length) == 0 && [string length $issue_no] > 0} {
		return [list 1 OK_BLANK]
	}

	#
	# check issue in correct format (if required)
	#
	if {[string length $issue_no] != $card_info(issue_length)} {
		return [list 0 "issue no. wrong length" PMT_ISSUE]

	} else {
		if {$card_info(issue_length) != 0 && [string length $issue_no] != 0} {
			if {![regexp {^[0-9]+$} $issue_no]}  {
				return [list 0 "invalid issue no." PMT_ISSUE]
			}
		}
	}

	return [list 1]
}

##################################################################################
# makes sure the cvv2 number is of the correct form
##################################################################################
proc verify_card_cvv2 {cvv2} {
	if {[OT_CfgGet DCASH_REQUIRE_CV2 0]} {
		# The standard is to allow 3 chars in the cvv2
		set RX_CVV2_3CHAR {^([0-9][0-9][0-9])$}

		# Cfg driver to allow 4 chars in addition to 3 for cvv2
		if {[OT_CfgGet CVV2_ALLOW_4_CHARS 0]} {
			set RX_CVV2_4CHAR {^([0-9][0-9][0-9][0-9])$}

			return [expr {
				[regexp $RX_CVV2_3CHAR $cvv2] || [regexp $RX_CVV2_4CHAR $cvv2]
			}]
		}

		return [regexp $RX_CVV2_3CHAR $cvv2]
	} else {
		## dont care
		return 1
	}
}


#
# converts 1 and 2 digit year to 4
#
proc expand_yr {yr} {

	if {$yr < 10} {
		return "200$yr"
	}

	if {$yr < 50} {
		return "20$yr"
	}

	return "19$yr"
}


#
# marks a card as deleted in the db
#
proc cd_delete_card {cust_id card_no} {

	# Locate the cpm id associated with this customer's active card matching this
	# card number
	set cpm_id_rs [get_cpm_id_for_card $cust_id $card_no]

	if {[lindex $cpm_id_rs 0] == 0} {
		return [list 0 PMT_ERR]
	} elseif {[lindex $cpm_id_rs 1] > -1} {

		# We have the card we want to remove, so remove it
		if {[catch {set rs [tb_db::tb_exec_qry cd_cpm_remove [lindex $cpm_id_rs 1]]} msg]} {
			ob::log::write ERROR {Failed to remove existing card: $msg}
			return [list 0 "Failed to remove existing card: $msg" PMT_ERR]
		}

		return [list 1]
	} else {
		# Failed to find any active cards with this number for this customer
		return [list 0 "Failed to locate existing card payment method" PMT_ERR]
	}
}

#
# DESCRIPTION :
#        Is a specific card a 1Pay card ?
#        i.e. is the tCustPayMthd.type equal to "OP" ?
#
# RETURNS :
#        {1 <cpm_type>} is successfull
#        {0 <english err message> <DB Message>}
#
proc cd_is_1pay {cust_id card_no} {

	set cpm_id_rs [get_cpm_id_for_card $cust_id $card_no]

	if {[lindex $cpm_id_rs 0] == 0} {
		return [list 0 PMT_ERR]
	} elseif {[lindex $cpm_id_rs 1] > -1} {
		# We've found the card we're looking for, check it's 1-pay status
		set ret [ventmear::get_1pay_status [lindex $cpm_id_rs 1]]

		ob::log::write DEBUG {<== cd_is_1pay [list 1 $ret]}
		return [list 1 $ret]
	} else {
		# Failed to find any active cards with this number for this customer
		return [list 0 "Failed to locate existing card payment method" PMT_ERR]
	}
}



#
# Retrieves values from reqGetArg (blech!) and passes them through
# to cd_reg_card_new
#
proc cd_reg_card {
	cust_id {transactional "Y"} {allow_duplicates "N"} {use_dummy_scheme 0} {reissue "N"} {cpm_id 0}
} {

	if {$reissue == "Y" && $cpm_id > 0} {
		if {[card_util::cd_get_active $cust_id CARD_DETAILS $cpm_id 1]} {
			set card_no      $CARD_DETAILS($cpm_id,card_no)
			set old_auth_dep $CARD_DETAILS($cpm_id,auth_dep)
		} else {
			return [list 0 "invalid_cpm_id" PMT_ERR]
		}
	} else {
		set card_no     [reqGetArg card_no]
		set old_auth_dep 0
	}

	set start       [reqGetArg start]
	set expiry      [reqGetArg expiry]
	set issue_no    [reqGetArg issue_no]
	set hldr_name   [reqGetArg hldr_name]


	regsub -all {[^0-9]} $card_no "" card_no

	set oper_id     [reqGetArg oper_id]

	if {[regexp {\D} $oper_id]} {
		# Possible hack attempt
		OT_LogWrite 2 "oper_id: $oper_id is invalid"
		return [list 0 "invalid oper_id" PMT_ERR]
	}

	set oper_notes  [reqGetArg oper_notes]

	return [cd_reg_card_new \
		$cust_id \
		$card_no \
		$expiry \
		$transactional \
		$allow_duplicates \
		$use_dummy_scheme \
		$start \
		$issue_no \
		$hldr_name \
		$oper_id \
		$oper_notes \
		"N" \
		$reissue \
		$cpm_id \
		$old_auth_dep]
}



#
# Stores the customers card details
# NB card should have already passed verify_card check
#
proc cd_reg_card_new {
	cust_id
	card_no
	expiry
	{transactional "Y"}
	{allow_duplicates "N"}
	{use_dummy_scheme 0}
	{start ""}
	{issue_no ""}
	{hldr_name ""}
	{oper_id ""}
	{oper_notes ""}
	{allow_multiple_cpm "N"}
	{reissue "N"}
	{old_cpm_id 0}
	{old_auth_dep 0}
} {


	# get rid of any spaces in the card no
	regsub -all {[^0-9]} $card_no "" card_no

	set hash_card_no [md5 $card_no]
	set card_bin     [string range $card_no 0 5]
	set card_no_bin  [string range $card_no 6 end]

	if {[lsearch {Y N} $reissue] == -1} {
		return [list 0 "reissue must be Y, N" PMT_ERR]
	}

	if {![OT_CfgGet ENCRYPT_WITH_BIN 0]} {
		set enc_rs [card_encrypt $card_no_bin "Encrypting card no. for tCPMCC" $cust_id [get_admin_username $oper_id]]
		set enc_with_bin "N"
	} else {
		set enc_rs [card_encrypt  [string range $card_no 8 end][string range $card_no 0 7] "Encrypting card no. for tCPMCC" $cust_id [get_admin_username $oper_id]]
		set enc_with_bin "Y"
	}

	if {[lindex $enc_rs 0] == 0} {
		return [list 0 "Failed to encrypt card number: [lindex $enc_rs 1]" PMT_ERR]
	}

	set enc_card_no [lindex [lindex $enc_rs 1] 0]
	set ivec        [lindex [lindex $enc_rs 1] 1]
	set data_key_id [lindex [lindex $enc_rs 1] 2]

	#
	# get extended card information (type, name)
	#
	array set CARDDATA ""
	if {[cd_get_req_fields $card_bin CARDDATA $use_dummy_scheme] == 0} {
		return [list 0 "unknown card type" PMT_CARD_UNKNWN]
	}
	set type $CARDDATA(type)
	set desc $CARDDATA(name)

	#
	# check card whether card is allowed for dep/wtd
	#
	set allow_dep    $CARDDATA(allow_dep)
	set allow_wtd    $CARDDATA(allow_wtd)

	if {$allow_dep == "Y"} {
		set allow_dep "P"
	}
	if {$allow_wtd == "Y"} {
		set allow_wtd "P"
	}

	if {$CARDDATA(start) == "N"} {
		set start ""
	}

	# Check if we're allowed to register this card (previously these checks were performed
	# within pCPMInsCCCheck, but now we need to make decryption calls, so it has been moved out
	# of the stored proc
	set card_ins_chk_rs [cc_ins_check \
		$cust_id \
		$allow_dep \
		$allow_wtd \
		$card_bin \
		$card_no \
		$start \
		$expiry \
		$issue_no \
		$hldr_name \
		$oper_id \
		$allow_duplicates\
		$reissue]

	if {[lindex $card_ins_chk_rs 0] == 0} {
		set code [payment_gateway::cc_pmt_get_sp_err_code [lindex $card_ins_chk_rs 1]]
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
	} else {
		set existing_match [lindex $card_ins_chk_rs 1]

		if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0] && [lindex $card_ins_chk_rs 2] == "CARD_REGISTERED_BEFORE"} {
			# We have found a duplicate card registered on another account, we
			# must suspend the card and either add fraud check flag to the account
			# or disable deposits/withdrawals on the account

			set cpm_status "S"

			set oper_notes "Duplicate Debit/Credit card found on another account"

			if {[catch {
				if {$transactional == "Y"} {
					ob_db::begin_tran
				}

				if {[OT_CfgGet CPM_FRAUD_CHK_ON_DUPL_CARD 1]} {
					tb_db::tb_exec_qry insert_status_flag $cust_id "FRAUD_CHK" $oper_notes "N"
				} else {
					tb_db::tb_exec_qry insert_status_flag $cust_id "DEP" $oper_notes "N"
					tb_db::tb_exec_qry insert_status_flag $cust_id "WTD" $oper_notes "N"
				}

			} msg]} {
				if {$transactional == "Y"} {
					ob_db::rollback_tran
				}
				ob::log::write ERROR {Failed to insert customer status flag: $msg}
				return [list 0 $oper_notes PMT_ERR]
			}
			if {$transactional == "Y"} {
				catch {ob_db::commit_tran}
			}
		} else {
			set cpm_status "A"
		}
	}

	set site_operator_id ""

	if {[OT_CfgGet FUNC_SITE_CARD_REGISTERED 0]} {

		set cust_channel ""

		if {[catch {
			set rs [tb_db::tb_exec_qry \
			get_cust_source_channel $cust_id]
		} msg]} {
			ob::log::write ERROR {Failed to execute get_cust_source_channel: $msg}
		}

		if {[db_get_nrows $rs] > 0} {
			set cust_channel [db_get_coln $rs 0 0]
		}

		set site_operator_id [get_chan_site_operator_id $cust_channel]

		if {$site_operator_id == -1} {
			return [list 0 "Failed to retrieve site_operator_id" PMT_ERR]
		}
	}

	set acct_type_dups "N"

	if {[OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]} {
	# Allow a card to be registered to multiple accounts, as long
	# as they have different account types
		set acct_type_dups "Y"
	}

	# stores the details
	if {[catch {set rs [tb_db::tb_exec_qry cd_cpm_ins_cc \
		$cust_id \
		$oper_id \
		$oper_notes \
		$enc_card_no \
		$ivec \
		$data_key_id \
		$card_bin \
		$start \
		$expiry \
		$issue_no \
		$type \
		$desc \
		$allow_dep \
		$allow_wtd \
		$transactional \
		$allow_duplicates \
		$hldr_name \
		$allow_multiple_cpm\
		$site_operator_id\
		$acct_type_dups\
		$existing_match \
		$enc_with_bin \
		$cpm_status\
	]} msg]} {
		ob::log::write ERROR {Failed to insert customers card details: $msg}
		set code [payment_gateway::cc_pmt_get_sp_err_code $msg]
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
	}

	set cpm_id [db_get_coln $rs 0]

	if {$reissue == "Y" && $old_cpm_id > 0} {

		set rs_linkupdate [tb_db::tb_exec_qry \
			insert_replacement_card $old_cpm_id $cpm_id]
		db_close $rs_linkupdate

		if {$old_auth_dep == "0"} {
			if {[card_util::cd_get_active $cust_id CARD_DETAILS $old_cpm_id 1]} {
				set old_auth_dep $CARD_DETAILS($old_cpm_id,auth_dep)
			} else {
				return [list 0 PMT_ERR]
			}
		}

		## Update deposit check flag if original has been deposited by
		if {$old_auth_dep == "Y"} {
			if {[catch {
				tb_db::tb_exec_qry update_deposit_check $cpm_id
			} msg]} {
				ob::log::write ERROR {$fn: Failed to update CPM links - $msg}
				return [list 0 PMT_ERR]
			}
		}
	}



	set result [list 1 $cpm_id $cpm_status]
	db_close $rs

	if {$existing_match == -1} {
		# We have inserted a new card, insert a hash, dont insert a hash if we
		# just switched on an old hash

		# Now we encrypt the card number and select a random number to use to store
		# and entry for this attempt in tCardRegHash
		set cpm_enc_rs [encrypt_cpmid $cpm_id "Encrypting CPM Id for tCPMCCHash" $cust_id [get_admin_username $oper_id]]

		if {[lindex $cpm_enc_rs 0] == 0} {
			ob::log::write ERROR {Failed to encrypt id: [lindex $cpm_enc_rs 1]}
			return [list 0 PMT_ERR]
		}

		# Extract the encrypted cpm id and data_key_id from the result
		set enc_cpm_id  [lindex [lindex $cpm_enc_rs 1] 0]
		set ivec        [lindex [lindex $cpm_enc_rs 1] 1]
		set data_key_id [lindex [lindex $cpm_enc_rs 1] 2]

		# Generate a random number between 0 and 1 (used to determine where in the table
		# to insert the new data
		set rand [format %.4f [expr rand()]]

		# We've now got a cpm id, now to insert a hash table entry for this card
		if {[catch {set rs [tb_db::tb_exec_qry cd_hash_ins_cc \
			$hash_card_no \
			$enc_cpm_id \
			$ivec \
			$data_key_id \
			$rand \
			$transactional]} msg]
		} {
			ob::log::write ERROR {Failed to insert customers hashed card details: $msg}
			set code [payment_gateway::cc_pmt_get_sp_err_code $msg]
			return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
		}

	}

	return $result
}

# Since we now require calls to decrypt cpm ids in order to search on customer's
# existing payment methods, the functionality of pCPMInsCCCheck is now performed
# in here rather than a stored procedure call
proc cc_ins_check {
	cust_id
	auth_dep
	auth_wtd
	card_bin
	card_no
	start
	expiry
	issue_no
	hldr_name
	oper_id
	{allow_duplicates "N"}
	{reissue "N"}
} {

	# Search for instances of this card number
	set cpm_dec_rs [get_cards_with_hash $card_no "Decrypting CPM id for new card insertion validation" $cust_id $oper_id]

	if {[lindex $cpm_dec_rs 0] == 0} {
		ob::log::write ERROR {cpm id decryption failed in proc card_util::cc_ins_check: [lindex $cpm_dec_rs 1]}
		return [list 0 PMT_ERR]
	} else {
		set dec_cpm_ids [lindex $cpm_dec_rs 1]
	}

	# We will need to remove and active cpms with this number which don't match the provided
	# issue_no, start, expiry and hldr_name
	set cpm_ids_to_remove [list]

	# We also need to record if the customer already has a tCPMCC entry matching exactly the
	# card number/start/expiry/issue_no/holder name combination as the card we're trying to
	# register, so that tCPMCC can update the details instead of inserting new details
	set existing_cpm_match -1

	if {[OT_CfgGet FUNC_SITE_CARD_REGISTERED 0]} {
		# retrieve customers site operator id
		set site_operator_id [get_cust_site_operator_id $cust_id]

		if {$site_operator_id == -1} {
			ob::log::write ERROR {Failed to retrieve site_operator_id}
			return [list 0 PMT_ERR]
		}
	}

	if {[OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]} {
		# retrieve customers acct type
		set acct_type [get_cust_acct_type $cust_id]

		if {$acct_type == 0} {
			ob::log::write ERROR {Failed to retrieve site_operator_id}
			return [list 0 PMT_ERR]
		}
	}

	set card_already_registered 0

	foreach cpm_id $dec_cpm_ids {
		if {[OT_CfgGet FUNC_SITE_CARD_REGISTERED 0]} {
			# retrieve all instances of this card on this site operator id
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id $site_operator_id]} msg]} {
				ob::log::write ERROR {chk_duplicate_cards failed in proc card_util::cc_ins_check: $msg}
				return [list 0 PMT_ERR]
			}
		} elseif {[OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]} {
			# retrieve all instances of this card on accounts of the same type
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id $acct_type]} msg]} {
				ob::log::write ERROR {chk_duplicate_cards failed in proc card_util::cc_ins_check: $msg}
				return [list 0 PMT_ERR]
			}
		} else {
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id]} msg]} {
				ob::log::write ERROR {chk_duplicate_cards failed in proc card_util::cc_ins_check: $msg}
				return [list 0 PMT_ERR]
			}
		}

		if {[db_get_nrows $cpm_rs] == 0} {
			# no collision with this cpm_id
			continue
		}

		set cpm_cust_id [db_get_col $cpm_rs 0 cust_id]
		set cpm_status  [db_get_col $cpm_rs 0 status]

		if {$cpm_cust_id != $cust_id && $allow_duplicates == "N" && [OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {
			# This card has registered on another account
			set card_already_registered 1
			continue
		}

		if {$cpm_cust_id != $cust_id && $cpm_status != "X" && $allow_duplicates == "N"} {
			# This card is currently active on a different customer
			db_close $cpm_rs
			return [list 0 "AX5008: Card registered to another account"]
		} elseif {$cpm_cust_id == $cust_id && $cpm_status == "S"} {
			# This card is already existing and suspended on this customer's account
			db_close $cpm_rs
			return [list 0 "AX50071: Card is registered on this account but suspended"]
		} elseif {$cpm_cust_id == $cust_id} {
			# This is another instance of this card number for this customer.
			# Check if start,expiry,hldr_name and issue_no match. If not then we
			# may have an old out of date instance to remove...
			if {[db_get_col $cpm_rs 0 start]     != $start || \
			    [db_get_col $cpm_rs 0 expiry]    != $expiry || \
			    [db_get_col $cpm_rs 0 issue_no]  != $issue_no || \
			    [db_get_col $cpm_rs 0 hldr_name] != $hldr_name} {

				if {$cpm_status == "A"} {
					# Old active instance of this card
					lappend cpm_ids_to_remove $cpm_id
				}
			} else {
				# Customer already has card registered with exactly the same details, in
				# which case pCPMInsCC may update the entry for this cpm id rather than
				# inserting a new row
				if {[lsearch [list A S X] $cpm_status] > -1} {
					set existing_cpm_match $cpm_id
				}
			}
		}
	}

	# We also need to check that the customer has any different cards registered and active on their account
	if {[catch {set rs [tb_db::tb_exec_qry cd_active_cust_card $cust_id]} msg]} {
		ob::log::write ERROR {failed to retrieve customers active card details: $msg}
		return [list 0 PMT_ERR]
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		# For each of this customer's active cards, reconstruct the card number
		# using the bin and decrypted enc_card_no values from tcpmcc, and compare
		# with the card number we're attempting to register
		set cpm_id       [db_get_col $rs $i cpm_id]
		set card_bin     [db_get_col $rs $i card_bin]
		set enc_card_no  [db_get_col $rs $i enc_card_no]
		set ivec         [db_get_col $rs $i ivec]
		set data_key_id  [db_get_col $rs $i data_key_id]
		set enc_with_bin [db_get_col $rs $i enc_with_bin]

		# Deal with card number
		set card_dec_rs [card_decrypt $enc_card_no $ivec $data_key_id "Card Insert Validation" $cust_id [get_admin_username $oper_id]]

		if {[lindex $card_dec_rs 0] == 0} {
			# Check on the reason decryption failed, if we encountered corrupt data we should also
			# record this fact in the db
			if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
				update_data_enc_status "tCPMCC" $cpm_id [lindex $card_dec_rs 2]
			}

			ob::log::write ERROR {failed to decrypt customers card details: [lindex $card_dec_rs 1]}
			db_close $rs
			return [list 0 PMT_ERR]
		} else {
			set dec_card_no [lindex $card_dec_rs 1]
		}

		set whole_card_no [format_card_no $dec_card_no $card_bin $enc_with_bin]

		#if {$whole_card_no != $card_no} {
		#	return [list 0 "AX5007: Different card registered on account"]
		#}
	}

	# Now set status of the cards we need to remove to 'X'
	foreach id $cpm_ids_to_remove {
		if {[catch {set rs [tb_db::tb_exec_qry cd_cpm_remove $id]} msg]} {
			ob::log::write ERROR {Failed to remove existing card: $msg}
			return [list 0 PMT_ERR]
		}
	}

	if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {
		if {$card_already_registered && $reissue != "Y"} {
			return [list 1 $existing_cpm_match CARD_REGISTERED_BEFORE]
		}
	}

	return [list 1 $existing_cpm_match]
}

#
# Used to reactivate a card of status 'removed'
# Originally used to reactivate their old card when a customer is changing
# their card and the payment failed
#
# The cust_id is used purely for verification
#
proc cd_reactivate_card {cust_id cpm_id} {
	if {[catch {set rs [tb_db::tb_exec_qry cd_cpm_reactivate \
				$cust_id \
				$cpm_id]} msg]} {
		ob::log::write ERROR {failed to run query cd_cpm_reactivate: $msg}
		return 0
	}
	return 1
}


proc cd_replace_card {cust_id card_no} {

	OT_LogWrite 5 "==> cd_replace_card"

	if [catch {db_begin_tran} msg] {
		OT_LogWrite 1 $msg
		return [list 0 "Failed to start Transaction: $msg" PMT_ERR]
	}

	set result [card_util::cd_delete_card $cust_id $card_no]

	if {[lindex $result 0] == 0} {
		catch {db_rollback_tran}
		OT_LogWrite 5 "could not delete card method [lindex $result 2]"
		return $result
	}

	# Call with N for non transactional
	set result [card_util::cd_reg_card $cust_id N]

	if {[lindex $result 0] == 0} {
		catch {db_rollback_tran}
		OT_LogWrite 5 "register card error [lindex $result 2]"
		return $result
	}
	db_commit_tran
	return $result
}

#
# Verifies the issue/expiry/start before updating these values
# Card MUST already exist as this customers active card
#
proc verify_cust_card_update {cust_id} {

	#
	# grab the parameters
	#
	set card_no     [reqGetArg card_no]
	set start       [reqGetArg start]
	set expiry      [reqGetArg expiry]
	set issue_no    [reqGetArg issue_no]
	set has_resp [reqGetArg has_resp]
	set cvv2         [reqGetArg cvv2]
	set depwtd       [reqGetArg depwtd]

	# Attempt to find an active cpm for this cust_id/card_no combination
	set cpm_id_rs [get_cpm_id_for_card $cust_id $card_no]

	if {[lindex $cpm_id_rs 0] == 0} {
		return [list 0 [lindex $cpm_id_rs 1]]
	}

	set cpm_id [lindex $cpm_id_rs 1]

	if {$cpm_id < 0} {
		return [list \
			0 \
			"Could not update card details: Card is not active on this account"\
			PMT_CARD_ACTIVE]
	}

	#
	# We've found the relevant card, get it's details
	if {[catch {set rs [tb_db::tb_exec_qry cd_cpm_details $cpm_id]} msg]} {
		ob::log::write ERROR {failed to run query cd_card_exists: $msg}
		return [list 0 "Could not update card details: $msg" PMT_ERR]
	}

	# get card details for cvv2 laser check
	array set CARDDATA ""
	set carddata_result [cd_get_req_fields [string range $card_no 0 5] CARDDATA]

	#
	# Check cvv2 number, only if first time usage and card is not laser
	#
	if {$has_resp==0 && $depwtd == "DEP" && $CARDDATA(scheme) != "LASR"} {
		if {![verify_card_cvv2 $cvv2]} {
			return [list 0 "invalid cvv2 number" CUST_VAL_NO_CSC]
		}
	}

	#
	# check if the card details have changed
	#
	set changed    0
	set start_chg  0
	set expiry_chg 0
	set issue_chg  0

	# Need to establish what parts of the card need checking.
	# Only check start if it's required for this card, otherwise it will be null.
	if {$CARDDATA(start) == "Y" && $start != [db_get_col $rs 0 start]}           {set start_chg  1}
	if {$expiry != [db_get_col $rs 0 expiry]}                                    {set expiry_chg 1}
	# Only check issue_no if it's required for this card
	if {$CARDDATA(issue_length) > 0 && $issue_no != [db_get_col $rs 0 issue_no]} {set issue_chg  1}
	if {$start_chg || $expiry_chg || $issue_chg}                                 {set changed    1}

	if {!$changed} {
		# card details have not changed
		return [list 2 "card details not changed" OK]
	}

	db_close $rs

	ob::log::write INFO {verify_cust_card_update: changed - start $start_chg,\
		expiry $expiry_chg, issue $issue_chg}

	# If start date has changed, validate
	if {$start_chg} {
		if {![check_card_start $start]} {
			return [list 0 \
				"failed to update card: start date is invalid"  PMT_STRT]
		}
	}
	# If expiry date has changed, validate
	if {$expiry_chg} {
		if {![check_card_expiry $expiry]} {
			return [list 0 \
				"failed to update card: expiry date is invalid" PMT_EXPR]
		}
	}

	#
	# verify the new start/expiry/issue
	# However, if we support OnePay, and it's a OnePay Card, which will not be
	# in the BIN range, we can't validate, so we skip this check.
	#
	if {
		[OT_CfgGet VENTMEAR 0] == 1 &&
		[lindex [cd_is_1pay $cust_id $card_no] 1] == {OP}
	} {
		return [list 1]
	}

	if {$carddata_result == 0} {
		return [list 0 "unknown card type" PMT_CARD_UNKNWN]
	}

	# check the start date
	set start_result [verify_cust_card_start $start CARDDATA]

	if {[lindex $start_result 0] != 1} {
		return $start_result
	}

	if {[lindex $start_result 1] == "OK_BLANK"} {
	   set start ""
	}

	# check the expiry date
	set expiry_result [verify_cust_card_expiry $expiry CARDDATA]
	if {![lindex $expiry_result 0]} {
		return $expiry_result
	}

	# check the issue no.
	set issue_result [verify_cust_card_issue_no $issue_no CARDDATA]

	if {![lindex $issue_result 0]} {
		return $issue_result
	}

	if {[lindex $issue_result 1] == "OK_BLANK"} {
		set issue_no ""
	}

	return [list 1]
}

#
# Has the card been blocked?
#
proc verify_card_not_blocked {card_no {cust_id ""}} {

	#
	# if cust_id is specified then check to see if this card is
	# allowed (tCustomer.allow_card)
	#
	if {$cust_id != ""} {
		if {[catch {
			set rs [tb_db::tb_exec_qry cd_cust_card_allowed $cust_id]
		} msg]} {
			ob::log::write ERROR {Failed to execute cust card allowed qry $msg}
			return 0
		}
		if {[db_get_nrows $rs] == 1 && [db_get_coln $rs 0] == "Y"} {
			db_close $rs
			return 1
		}
		db_close $rs
	}

	# First encrypt the card number
	set hash_card_no [md5 $card_no]
	set bin [string range $card_no 0 5]
	#
	# check tCardBlock table to see if this card is allowed
	#
	if {[catch {set rs [tb_db::tb_exec_qry cd_card_block $hash_card_no $bin]} msg]} {
		ob::log::write ERROR {Failed to execute pChkCardAllowed: $msg}
		return 0
	}

	if {[db_get_nrows $rs] == 1} {

		set flag [db_get_coln $rs 0]
		db_close $rs

		switch -- $flag {
			Y { return 1 }
			N { return 0 }
		}

	}

	catch {db_close $rs}
	return 0
}

#
# Is the card used on another account?
# This might be called before we are registered ie telebet, therefore
# you need to be able to pass in details of the account to be potentially
# registered if you dont have the cust_id
#
proc verify_card_not_used {card_no cust_id {acct_type "-1"} {site_operator_id "-1"}} {

	ob::log::write INFO {=> verify_card_not_used :  '$cust_id' \
	                                                '$acct_type' \
	                                                '$site_operator_id'}

	# validation
	if {$card_no == ""} {
		ob::log::write ERROR {verify_card_not_used failed card_no empty}
		return 0
	}

	if {$cust_id == ""} {
		ob::log::write ERROR {verify_card_not_used failed cust_id empty}
		return 0
	}

	# cust id specified, find out the site operator and account type
	if {([OT_CfgGet FUNC_SITE_CARD_REGISTERED 0] || [OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0])
		&& $cust_id != -1} {

		set site_operator_id [get_cust_site_operator_id $cust_id]

		if {$site_operator_id == -1} {
			ob::log::write ERROR {Failed to retrieve site_operator_id}
			return 0
		}

		set acct_type [get_cust_acct_type $cust_id]

		if {$acct_type == 0} {
			ob::log::write ERROR {Failed to retrieve site_operator_id}
			return 0
		}

	}

	# further validation
	if {([OT_CfgGet FUNC_SITE_CARD_REGISTERED 0] || [OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]) && ($site_operator_id == "-1" || $acct_type == "-1")} {
		ob::log::write ERROR {card_util::verify_card_not_used \
		                      ERROR required fields unspecified \
		                      site_operator_id: '$site_operator_id' \
		                      acct_type: '$acct_type'}
		return 0
	}

	# Deal with card number
	set cpm_dec_rs [get_cards_with_hash $card_no "Checking card not used elsewhere" $cust_id]

	if {[lindex $cpm_dec_rs 0] == 0} {
		ob::log::write ERROR {get_cards_with_hash failed in proc card_util::verify_card_not_used: [lindex $cpm_dec_rs 1]}
		return 0
	} else {
		set dec_cpm_ids [lindex $cpm_dec_rs 1]
	}

	set unique_card 1

	foreach cpm_id $dec_cpm_ids {

		if {[OT_CfgGet FUNC_SITE_CARD_REGISTERED 0]} {
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id $site_operator_id]} msg]} {
				ob::log::write ERROR {cd_card_used_and_active failed in proc card_util::verify_card_not_used: $msg}
				return 0
			}
		} elseif {[OT_CfgGet FUNC_ACCT_TYPE_CARD_REGISTERED 0]} {
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id $acct_type]} msg]} {
				ob::log::write ERROR {cd_card_used_and_active failed in proc card_util::verify_card_not_used: $msg}
				return 0
			}
		} else {
			if {[catch {set cpm_rs [tb_db::tb_exec_qry cd_card_used_and_active $cpm_id]} msg]} {
				ob::log::write ERROR {cd_card_used_and_active failed in proc card_util::verify_card_not_used: $msg}
				return 0
			}
		}

		if {[db_get_nrows $cpm_rs] == 0} {
			# no collision found with this cpm_id
			continue
		}

		set cpm_cust_id [db_get_col $cpm_rs 0 cust_id]
		set cpm_status  [db_get_col $cpm_rs 0 status]

		if {$cpm_cust_id != $cust_id && [OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {
			# This card has been registered on another account
			set unique_card 0
		}

		if {$cpm_cust_id != $cust_id && $cpm_status != "X"} {
			# This card is currently active on a different customer
			set unique_card 0
		}

		db_close $cpm_rs

		if {$unique_card == 0} {
			# We've found a case of this card being active on another account, no
			# need to make any more checks on our results
			break
		}
	}

	ob::log::write INFO {<= verify_card_not_used returning '$unique_card'}

	return $unique_card
}

#
# Run checks to determine if the card can be deleted
# Checks if user has:
#   - ever made any external system transfers (eg Microgaming and Poker Million
#     casinos)
#   - got any unsettled bets
#
#   - various config items determine what is being checked
#   - if nothing is checked  1 success with list elements of code 3.
#     will be returned
#   - if FUNC_CARD_CHANGE_ALLOWED is off 0 success and list elements of code 3
#     will be returned
#
# PARAMS
#    partial - specifies whether to perform a partial or full check:
#            - it is no longer used
#         partial:
#            balance = 0
#            no unsettled sportsbook bets
#            no unsettled pool bets
#            no unsettled lottery bets/subscriptions
#            no unsettled balls subscriptions
#            no outstanding FOG balance
#            no pending payments
#
#         full:
#            all partial checks
#            zero MCS poker balance and no chips held on game tables
#            zero MCS casino balance and no chips in play
#            zero Live Dealer balance and no chips in play
#            no outstanding Cantor FOF bets
#            zero external CTXM game balance (external oxi games)
#            no entries in txsyxfer for external games we're not handling in this proc
#
#
# RETURN
#
#    {<success> {<balance_code> <msg>}
#               {<casino_code>  <msg>}
#               {<poker_code>  <msg>}
#               {<unsettled_code>  <msg>}
#               {<state_games_code>  <msg>}
#               {<balls_code> <msg>}
#               {<cwc_code> <msg>}}
#
#    <success>           - 1:success   0:failure
#
#    <balance_code>      >
#    <casino_code>       >
#    <poker_code>        >   1 : check succeeded
#    <unsettled_code>    >   0 : check failed
#    <state_games_code>  >   2 : check failed - unable to carry out
#    <balls_code>        >   3 : configged off, check was never made.
#    <cwc_code>          >
#
#    <msg>               - English text to say why the code is what it is (for Admin)
#
proc verify_cust_card_ok_to_delete {cust_id {partial 0}} {

	global SHARED_SQL

	# If we're not switched on in the config, just return a 0
	if {![OT_CfgGet FUNC_CARD_CHANGE_ALLOWED 0]} {
		return [list \
			0 \
			[list 3 "" "CARD_CHANGE_BALANCE"        ] \
			[list 3 "" "CARD_CHANGE_MCS_CASINO"     ] \
			[list 3 "" "CARD_CHANGE_MCS_RIOBAY"     ] \
			[list 3 "" "CARD_CHANGE_MCS_VIP"        ] \
			[list 3 "" "CARD_CHANGE_MCS_POKER"      ] \
			[list 3 "" "CARD_CHANGE_UNSETTLEDBETS"  ] \
			[list 3 "" "CARD_CHANGE_GAMESMULTISTATE"] \
			[list 3 "" "CARD_CHANGE_BALLSSUB"       ] \
			[list 3 "" "CARD_CHANGE_LIVEDEALER"     ] \
			[list 3 "" "CARD_CHANGE_PENDINGPAYMENTS"] \
			[list 3 "" "CARD_CHANGE_CANTORFOF"      ] \
			[list 3 "" "CARD_CHANGE_GGRECENTSTAKE"  ]\
			[list 3 "" "CARD_CHANGE_CTXM_GAME" ]\
			[list 3 "" "CARD_CHANGE_UNKNOWN_XFER"]]
	}

	#
	# Initialise local vars. Need to keep track of whats failed
	# so an operator can find out via the admin screens. Assume
	# everything ok unless proved otherwise.
	#
	set ret [list]
	set OK_INFO(overall_success) 1
	foreach item {
		CARD_CHANGE_BALANCE
		CARD_CHANGE_MCS_CASINO
		CARD_CHANGE_MCS_RIOBAY
		CARD_CHANGE_MCS_VIP
		CARD_CHANGE_MCS_POKER
		CARD_CHANGE_UNSETTLEDBETS
		CARD_CHANGE_GAMESMULTISTATE
		CARD_CHANGE_BALLSSUB
		CARD_CHANGE_LIVEDEALER
		CARD_CHANGE_PENDINGPAYMENTS
		CARD_CHANGE_CANTORFOF
		CARD_CHANGE_GGRECENTSTAKE
		CARD_CHANGE_CTXM_GAME
		CARD_CHANGE_UNKNOWN_XFER
	} {
		set OK_INFO($item,success) 1
		set OK_INFO($item,msg)     ""
	}

	#
	# Get some details about the customer first.
	#
	set username ""
	set balance  ""
	set ccy_code ""
	if {[catch {
		set rs [tb_db::tb_exec_qry cd_cust_acct_detail $cust_id]
	} msg]} {
		ob::log::write ERROR {verify_cust_card_ok_to_delete:\
			Failed to retrieve customer details.}
		return [list \
			0 \
			[list 2 "" "CARD_CHANGE_BALANCE"        ] \
			[list 2 "" "CARD_CHANGE_MCS_CASINO"     ] \
			[list 2 "" "CARD_CHANGE_MCS_RIOBAY"     ] \
			[list 2 "" "CARD_CHANGE_MCS_VIP"        ] \
			[list 2 "" "CARD_CHANGE_MCS_POKER"      ] \
			[list 2 "" "CARD_CHANGE_UNSETTLEDBETS"  ] \
			[list 2 "" "CARD_CHANGE_GAMESMULTISTATE"] \
			[list 2 "" "CARD_CHANGE_BALLSSUB"       ] \
			[list 2 "" "CARD_CHANGE_LIVEDEALER"     ] \
			[list 2 "" "CARD_CHANGE_PENDINGPAYMENTS"] \
			[list 2 "" "CARD_CHANGE_CANTORFOF"      ] \
			[list 2 "" "CARD_CHANGE_GGRECENTSTAKE"  ]\
			[list 2 "" "CARD_CHANGE_CTXM_GAME" ]\
			[list 2 "" "CARD_CHANGE_UNKNOWN_XFER"]]
	}
	if {[db_get_nrows $rs] != 0} {
		set username [db_get_col $rs 0 username]
		set balance  [db_get_col $rs 0 balance]
		set ccy_code [db_get_col $rs 0 ccy_code]
		set acct_id  [db_get_col $rs 0 acct_id]
	}
	db_close $rs


	#
	# Check that they have a zero balance
	#
	if {[OT_CfgGet FUNC_CARD_CHANGE_BALANCE 0]} {
		if {$balance != 0} {
			ob::log::write ERROR \
				{verify_cust_card_ok_to_delete: balance is non-zero}
			set OK_INFO(CARD_CHANGE_BALANCE,success) 0
			set OK_INFO(CARD_CHANGE_BALANCE,msg) \
				"The customer's account balance is : $balance $ccy_code."
		}
	} else {
		set OK_INFO(CARD_CHANGE_BALANCE,success) 3
	}

	#
	# check if the person has unsettled bets
	# this query includes sportsbook, xgame and pool bets
	#
	if {[OT_CfgGet FUNC_CARD_CHANGE_UNSETTLEDBETS 0]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry cd_check_unsettled_bets $cust_id]
		} msg]} {
			ob::log::write ERROR {Failed to execute cd_check_unsettled_bets: $msg}
			set OK_INFO(CARD_CHANGE_UNSETTLEDBETS,success)    2
			set OK_INFO(CARD_CHANGE_UNSETTLEDBETS,msg) \
				"Failed to determine if the customer has unsettled bets."
		}

		if {[db_get_nrows $rs] != 0} {
			ob::log::write INFO {verify_cust_card_ok_to_delete: \
				cd_check_unsettled_bets > 0}
			set OK_INFO(CARD_CHANGE_UNSETTLEDBETS,success)    0
			set OK_INFO(CARD_CHANGE_UNSETTLEDBETS,msg)        "Customer has unsettled bets."
		}
		db_close $rs
	} else {
		set OK_INFO(CARD_CHANGE_UNSETTLEDBETS,success) 3
	}

	#
	# have they have no active balls subscriptions
	#
	if {[OT_CfgGet FUNC_CARD_CHANGE_BALLSSUB 0]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry cd_check_unsettled_netballs $cust_id]
		} msg]} {
			ob::log::write ERROR \
				{Failed to execute cd_check_unsettled_netballs: $msg}
			set OK_INFO(CARD_CHANGE_BALLSSUB,success) 2
			set OK_INFO(CARD_CHANGE_BALLSSUB,msg) \
				"Failed to determine if the customer has open Balls subscriptions."
		}

		if {[db_get_nrows $rs] != 0} {
			ob::log::write INFO {verify_cust_card_ok_to_delete: \
				cd_check_unsettled_netballs > 0}
			set OK_INFO(CARD_CHANGE_BALLSSUB,success) 0
			set OK_INFO(CARD_CHANGE_BALLSSUB,msg) "Customer has open Balls subscriptions."
		}
		db_close $rs
	} else {
		set OK_INFO(CARD_CHANGE_BALLSSUB,success) 3
	}

	#
	# check if they have open multi state games
	#
	if {[OT_CfgGet FUNC_CARD_CHANGE_GAMESMULTISTATE 0]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry cd_check_multi_state_games $cust_id]
		} msg]} {
			ob::log::write ERROR {Failed to execute cd_check_multi_state_games: $msg}
			set OK_INFO(CARD_CHANGE_GAMESMULTISTATE,success) 2
			set OK_INFO(CARD_CHANGE_GAMESMULTISTATE,msg) \
				"Failed to determine if the customer has open multi-state games."
		}

		ob::log::write INFO {Customer has [db_get_nrows $rs] open game(s)}

		if {[db_get_nrows $rs] != 0} {
			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				set status_table [db_get_col $rs $i status_table]
				set cg_game_id   [db_get_col $rs $i cg_game_id]

				catch {tb_unprep_qry cd_get_game_status}
				# now we check each game individually
				set SHARED_SQL(cd_get_game_status) [subst {
					select game_status
					from $status_table
					where cg_game_id = $cg_game_id
				}]
				set res   [tb_db::tb_exec_qry cd_get_game_status]
				set nrows [db_get_nrows $res]

				set game_status  [db_get_col $res 0 game_status]

				db_close $res

				if {$game_status == "B" || $game_status == "P"} {
					ob::log::write INFO {verify_cust_card_ok_to_delete: \
						cd_check_multi_state_games > 0}
					set OK_INFO(CARD_CHANGE_GAMESMULTISTATE,success) 0
					set OK_INFO(CARD_CHANGE_GAMESMULTISTATE,msg) \
						"Customer has open multi-state games."
					break;
				}
			}
		}
		db_close $rs
	} else {
		set OK_INFO(CARD_CHANGE_GAMESMULTISTATE,success) 3
	}

	#
	# check that there are no pending payments:
	#  * no payments of status 'U' exist against the acct in the last 3 days (259200 secs)
	#  * no payments of status "L','I' or 'P' exist against the acct in the last week (604800 secs)
	#
	if {[OT_CfgGet FUNC_CARD_CHANGE_PENDINGPAYMENTS 0]} {
		set start1    "[clock format [expr [clock seconds] - 259200] -format %Y-%m-%d] 00:00:00"
		set start2    "[clock format [expr [clock seconds] - 604800] -format %Y-%m-%d] 00:00:00"
		if {[catch {
			set rs  [tb_db::tb_exec_qry last_transactions_by_status $acct_id $start1 "U" ""  ""  ""]
			set rs2 [tb_db::tb_exec_qry last_transactions_by_status $acct_id $start2 "L" "I" "P" ""]
		} msg]} {
			ob::log::write ERROR {Failed to execute last_transactions_by_status: $msg}
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,success)    2
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,msg) \
				"Failed to determine if the customer has pending payments."
		}

		if {[db_get_nrows $rs] != 0 || [db_get_nrows $rs2] != 0} {
			ob::log::write INFO {verify_cust_card_ok_to_delete: \
				last_transactions_by_status > 0}
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,success)    0
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,msg)        "Customer has pending payments."
		}
		db_close $rs
		db_close $rs2
	} else {
		set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,success) 3
	}

	# Check that they've made no golden guineas bets recently
	if {[OT_CfgGet FUNC_CARD_CHANGE_GGRECENTSTAKE 0]} {
		# Get the time we need to wait before we allow the card to be changed
		set waittime [OT_CfgGet CARD_CHANGE_GGRECENTSTAKE_WAIT 24]

		if {[catch {
			set rs  [tb_db::tb_exec_qry recent_goldenguineas_stake $acct_id $waittime]
		} msg]} {
			ob::log::write ERROR {Failed to execute last_goldenguineas_stake: $msg}
			set OK_INFO(CARD_CHANGE_GGRECENTSTAKE,success)    2
			set OK_INFO(CARD_CHANGE_GGRECENTSTAKE,msg) \
				"Failed to determine if the customer has made a golden guineas stake."
		}

		if {[db_get_nrows $rs] > 0} {
			ob::log::write INFO {verify_cust_card_ok_to_delete: \
				recent_goldenguineas_stake > 0}
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,success)    0
			set OK_INFO(CARD_CHANGE_PENDINGPAYMENTS,msg)        "Customer has golden guineas stake in the last $waittime hours."
		}
		db_close $rs
	} else {
		set OK_INFO(CARD_CHANGE_GGRECENTSTAKE,success) 3
	}

	#########################
	# This is the end of the 'partial check' section - checks from here on will
	# only be performed if a full check is requested.
	#########################

	if {!$partial} {

		#
		# check casino transfers / balances
		#
		if {
			[OT_CfgGet FUNC_CARD_CHANGE_MCS_CASINO 0] ||
			[OT_CfgGet FUNC_CARD_CHANGE_MCS_RIOBAY 0] ||
			[OT_CfgGet FUNC_CARD_CHANGE_MCS_VIP 0]    ||
			[OT_CfgGet FUNC_CARD_CHANGE_MCS_POKER 0]
		} {
			if {[catch {set rs [tb_db::tb_exec_qry cd_check_prev_xfers $cust_id]} msg]} {
				ob::log::write ERROR {Failed to execute cd_check_prev_xfers: $msg}
				set OK_INFO(CARD_CHANGE_MCS_CASINO,success)      2
				set OK_INFO(CARD_CHANGE_MCS_RIOBAY,success)   2
				set OK_INFO(CARD_CHANGE_MCS_VIP,success)  2
				set OK_INFO(CARD_CHANGE_MCS_POKER,success)    2
				set OK_INFO(CARD_CHANGE_MCS_CASINO,msg) \
					"Unable to verify if the customer ever made a casino transfer."
				set OK_INFO(CARD_CHANGE_MCS_RIOBAY,msg) \
					"Unable to verify if the customer ever made a casino transfer."
				set OK_INFO(CARD_CHANGE_MCS_VIP,msg) \
					"Unable to verify if the customer ever made a casino transfer."
				set OK_INFO(CARD_CHANGE_MCS_POKER,msg) \
					"Unable to verify if the customer ever made a casino transfer."
			}

			if {[db_get_nrows $rs] != 0} {
				ob::log::write INFO {verify_cust_card_ok_to_delete: \
					cd_check_prev_xfers > 0. Checking MCS balance ...}

				# Checks if a user has made any transactions for a specific
				# MCS casino

				# get casino balance
				if {[OT_CfgGet FUNC_CARD_CHANGE_MCS_CASINO 0]} {
					set res_played_casino [tb_db::tb_exec_qry cd_has_man_adj \
						$cust_id "MCSC"]
					if {[db_get_nrows $res_played_casino] > 0} {
						set bal [mcs_api::get_mcs_balance $cust_id $username "casino" "default"]
						ob::log::write INFO {Casino balance (default) result : $bal}
						if {$bal == "FAILED" || $bal == "NOALIAS"} {
							set OK_INFO(CARD_CHANGE_MCS_CASINO,success) 2
							set OK_INFO(CARD_CHANGE_MCS_CASINO,msg) \
								"Failed to retrieve customer's MCS casino balance."
						} elseif {$bal > 0} {
							ob::log::write INFO {verify_cust_card_ok_to_delete: \
								casino: cd_check_prev_xfers > 0 and casino (default) balance > 0}
							set OK_INFO(CARD_CHANGE_MCS_CASINO,success) 0
							set OK_INFO(CARD_CHANGE_MCS_CASINO,msg) \
								"Customer's MCS casino balance is : $bal."
						}
					}
					db_close $res_played_casino
				} else {
					set OK_INFO(CARD_CHANGE_MCS_CASINO,success) 3
				}

				#get the rio bay casino balance
				if {[OT_CfgGet FUNC_CARD_CHANGE_MCS_RIOBAY 0]} {
					set res_played_riocasino [tb_db::tb_exec_qry \
						cd_has_man_adj $cust_id "RIOC"]
					if {[db_get_nrows $res_played_riocasino] > 0} {
						set bal [mcs_api::get_mcs_balance $cust_id $username "casino" "RIO"]
						ob::log::write INFO {Casino balance (rio) result : $bal}
						if {$bal == "FAILED" || $bal == "NOALIAS"} {
							set OK_INFO(CARD_CHANGE_MCS_RIOBAY,success) 2
							set OK_INFO(CARD_CHANGE_MCS_RIOBAY,msg) \
								"Failed to retrieve customer's MCS Rio-Bay casino balance."
						} elseif {$bal > 0} {
							ob::log::write INFO {verify_cust_card_ok_to_delete: \
								casino: cd_check_prev_xfers > 0 and casino (rio) balance > 0}
							set OK_INFO(CARD_CHANGE_MCS_RIOBAY,success) 0
							set OK_INFO(CARD_CHANGE_MCS_RIOBAY,msg) \
								"Customer's MCS Rio-Bay casino balance is : $bal."
						}
					}
					db_close $res_played_riocasino
				} else {
					set OK_INFO(CARD_CHANGE_MCS_RIOBAY,success) 3
				}

				#get the vip casino balance
				if {[OT_CfgGet FUNC_CARD_CHANGE_MCS_VIP 0]} {
					set res_played_viper [tb_db::tb_exec_qry cd_has_man_adj \
						$cust_id "VIPC"]
					if {[db_get_nrows $res_played_viper] > 0} {
						set bal [mcs_api::get_mcs_balance $cust_id $username "casino" "VIP"]
						ob::log::write INFO {Casino balance (vip) result : $bal}
						if {$bal == "FAILED" || $bal == "NOALIAS"} {
							set OK_INFO(CARD_CHANGE_MCS_VIP,success) 2
							set OK_INFO(CARD_CHANGE_MCS_VIP,msg) \
								"Failed to retrieve customer's MCS Viper casino balance."
						} elseif {$bal > 0} {
							ob::log::write INFO {verify_cust_card_ok_to_delete: \
								casino: cd_check_prev_xfers > 0 and casino (viper) balance > 0}
							set OK_INFO(CARD_CHANGE_MCS_VIP,success) 0
							set OK_INFO(CARD_CHANGE_MCS_VIP,msg) \
								"Customer's MCS Viper casino balance is : $bal."
						}
					}
					db_close $res_played_viper
				} else {
					set OK_INFO(CARD_CHANGE_MCS_VIP,success) 3
				}

				#get poker balance
				if {[OT_CfgGet FUNC_CARD_CHANGE_MCS_POKER 0]} {
					set res_played_poker [tb_db::tb_exec_qry cd_has_man_adj \
						$cust_id "MCSP"]
					if {[db_get_nrows $res_played_poker] > 0} {
						set bal [mcs_api::get_mcs_balance $cust_id $username "poker"]
						ob::log::write INFO {Poker balance (rio) result : $bal}
						if {$bal == "FAILED" || $bal == "NOALIAS"} {
							set OK_INFO(CARD_CHANGE_MCS_POKER,success)    2
							set OK_INFO(CARD_CHANGE_MCS_POKER,msg) \
								"Failed to retrieve customer's MCS Poker balance."
						} elseif {$bal > 0} {
							ob::log::write INFO {verify_cust_card_ok_to_delete: \
								poker: cd_check_prev_xfers > 0 and MCS balance > 0}
							set OK_INFO(CARD_CHANGE_MCS_POKER,success)    0
							set OK_INFO(CARD_CHANGE_MCS_POKER,msg) \
								"Customer's MCS Poker balance is : $bal."
						}
					}
					db_close $res_played_poker
				} else {
					set OK_INFO(CARD_CHANGE_MCS_POKER,success) 3
				}
			}
			db_close $rs
		} else {
			set OK_INFO(CARD_CHANGE_MCS_CASINO,success)     3
			set OK_INFO(CARD_CHANGE_MCS_RIOBAY,success)  3
			set OK_INFO(CARD_CHANGE_MCS_VIP,success) 3
			set OK_INFO(CARD_CHANGE_MCS_POKER,success)   3
		}

		#
		# check Live Dealer balance is zero and no chips held on game tables
		# these are both the same call
		# OK_INFO(cwc_bal,success) defaults to 1 in case HAS_LIVE_DEALER == 0
		#
		if {[OT_CfgGet FUNC_CARD_CHANGE_LIVEDEALER 0]} {

			# Check customer flag to see if user has played CWC Live Dealer
			if {[OB_prefs::get_cust_flag $cust_id played_livedeal] == "Y"} {
				global CWC_DETAILS

				# login call sets balance in CWC_DETAILS(balance)
				OB_CWC_interface::login $alias 0
				if {[info exists CWC_DETAILS(balance)]} {
					if {$CWC_DETAILS(balance) != 0} {
						ob::log::write INFO {verify_cust_card_ok_to_delete: \
							cwc: balance > 0}
						set OK_INFO(CARD_CHANGE_LIVEDEALER,success)    0
						set OK_INFO(CARD_CHANGE_LIVEDEALER,msg) \
							"Customer's Live Dealer balance is : $CWC_DETAILS(balance)."
					}
				} else {
						set OK_INFO(CARD_CHANGE_LIVEDEALER,success)    2
						set OK_INFO(CARD_CHANGE_LIVEDEALER,msg) \
							"Problem getting Live Dealer balance"
				}
			}
		} else {
			set OK_INFO(CARD_CHANGE_LIVEDEALER,success)   3
		}

		#
		# check Cantor Fixed Odd Financials
		#
		if {[OT_CfgGet FUNC_CARD_CHANGE_CANTORFOF 0]} {
			 set cantor_balance [get_cantor_unsettled_bets $cust_id [OT_CfgGet CANTOR_TIMEOUT 10000]]
			 if {$cantor_balance == "FAILED"} {
			 	set OK_INFO(CARD_CHANGE_CANTORFOF,success)    2
				set OK_INFO(CARD_CHANGE_CANTORFOF,msg) \
				"Problem getting Fixed Odds Financials balance"
			 } elseif {$cantor_balance > 0} {
			 	ob::log::write INFO {verify_cust_card_ok_to_delete: \
				cantor financial: balance > 0}
			 	set OK_INFO(CARD_CHANGE_CANTORFOF,success)    0
				set OK_INFO(CARD_CHANGE_CANTORFOF,msg) \
				"Customer's Fixed Odds Financials balance is: $cantor_balance."
			 }
		} else {
			set OK_INFO(CARD_CHANGE_CANTORFOF,success)   3
		}

		#
		# check whether there is any balance on external games at  CTXM
		#
		if {[OT_CfgGet FUNC_CARD_CHANGE_CTXM_GAME 0]} {
			set ctxm_results [get_ctxm_game_balance $username $acct_id]
			if {![lindex $ctxm_results 0]} {
				set OK_INFO(CARD_CHANGE_CTXM_GAME,success)    2
				set OK_INFO(CARD_CHANGE_CTXM_GAME,msg) \
				"Problem getting CTXM game balance"
			} elseif {[lindex $ctxm_results 1] > 0} {
				ob::log::write INFO {verify_cust_card_ok_to_delete: \
				ctxm game: balance > 0}
				set result_string ""
				for {set i 2} {$i < [llength $ctxm_results]} {incr i} {
					set game_info [lindex $ctxm_results $i]
					if {[lindex $game_info 1] > 0} {
						append result_string "[lindex $game_info 0] balance:[lindex $game_info 1]   "
					}
				}
				ob::log::write INFO {verify_cust_card_ok_to_delete: \
				Results - $result_string}
			 	set OK_INFO(CARD_CHANGE_CTXM_GAME,success)    0
				set OK_INFO(CARD_CHANGE_CTXM_GAME,msg) \
				"$result_string"
			}
		} else {
			set OK_INFO(CARD_CHANGE_CTXM_GAME,success)   3
		}

		#
		# there is a danger that external games get added but we don't check for hidden funds - make sure all the system_id's
		# of a customers entries in txsysxfer are known about by ok_to_delete - we may not care but need to explicitly
		# state don't care to prevent  problems - CONFIG variable VALID_CARD_CHANGE_XSYSHOST stores all the valid
		# game names (name in txsyshost)
		#
		if {[OT_CfgGet FUNC_CARD_CHANGE_UNKNOWN_XFER 0]} {
			set unknown_xfers_res [chk_no_unknown_xfers $acct_id]
			if {![lindex $unknown_xfers_res 0]} {
				set OK_INFO(CARD_CHANGE_UNKNOWN_XFER,success)    2
				set OK_INFO(CARD_CHANGE_UNKNOWN_XFER,msg) \
				"Unable to check that all externally transferred funds are valid."
			} elseif {[lindex $unknown_xfers_res 1]} {
				ob::log::write INFO {verify_cust_card_ok_to_delete: \
				customer has xfers not known about by ok_to_delete. Names: [lindex $unknown_xfers_res 2]}
				set OK_INFO(CARD_CHANGE_UNKNOWN_XFER,success)    0
				set OK_INFO(CARD_CHANGE_UNKNOWN_XFER,msg) \
				"Customer has transfered funds externally but transfers\
				have not been checked properly. System name/s: [lindex $unknown_xfers_res 2]. \
				Please go through your helpdesk process"
			}
		} else {
			set OK_INFO(CARD_CHANGE_UNKNOWN_XFER,success)   3
		}
	}

	#
	# Tidy up and return
	#
	set OK_INFO(overall_success) 1
	foreach item {
		CARD_CHANGE_BALANCE
		CARD_CHANGE_MCS_CASINO
		CARD_CHANGE_MCS_RIOBAY
		CARD_CHANGE_MCS_VIP
		CARD_CHANGE_MCS_POKER
		CARD_CHANGE_UNSETTLEDBETS
		CARD_CHANGE_GAMESMULTISTATE
		CARD_CHANGE_BALLSSUB
		CARD_CHANGE_LIVEDEALER
		CARD_CHANGE_PENDINGPAYMENTS
		CARD_CHANGE_CANTORFOF
		CARD_CHANGE_GGRECENTSTAKE
		CARD_CHANGE_CTXM_GAME
		CARD_CHANGE_UNKNOWN_XFER
	} {
		lappend ret [list $OK_INFO($item,success) $OK_INFO($item,msg) $item]
		if {$OK_INFO($item,success) == 0 || $OK_INFO($item,success) == 2} {
			set OK_INFO(overall_success) 0
		}
	}

	set ret [linsert $ret 0 $OK_INFO(overall_success)]
	ob::log::write INFO {verify_cust_card_ok_to_delete returning $ret}

	return $ret
}

#
# Gets the active card on an account. If there is more than one active card,
# gets the most recently used card.
#
# NOTE: this will only work if there is 1 or more cards active - if < 1 then
# returns nothing
#
proc cd_get_active {cust_id OUT {cpm 0} {and_suspended 0}} {

	upvar 1 $OUT DATA

	set DATA(card_available) "N"
	set DATA($cpm,card_available) "N"
	set DATA(cpm_id) [list]
	set DATA(has_resp)      0

	if {$cpm} {
		if {$and_suspended} {
			set qry cd_card_data_all
		} else {
			set qry cd_card_data
		}

		if {[catch {set rs [tb_db::tb_exec_qry $qry $cpm $cust_id]} msg]} {
			ob::log::write ERROR \
				{failed to retrieve customers active card details: $msg}
			return 0
		}
	} else {
		if {$and_suspended} {
			set qry cd_active_and_suspended_cust_card
		} else {
			set qry cd_active_cust_card
		}

		if {[catch {set rs [tb_db::tb_exec_qry $qry $cust_id]} msg]} {
			ob::log::write ERROR \
				{failed to retrieve customers active card details: $msg}
			return 0
		}
	}

	set enc_db_vals [list]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set DATA(card_available) "Y"
		set DATA($cpm,card_available) "Y"

		set cpm_id [db_get_col $rs $i cpm_id]
		lappend DATA(cpm_id) $cpm_id

		set DATA($cpm_id,cpm_id)        [db_get_col $rs $i cpm_id]
		set DATA($cpm_id,enc_card_no)   [db_get_col $rs $i enc_card_no]
		set DATA($cpm_id,ivec)          [db_get_col $rs $i ivec]
		set DATA($cpm_id,data_key_id)   [db_get_col $rs $i data_key_id]
		set DATA($cpm_id,start)         [db_get_col $rs $i start]
		set DATA($cpm_id,expiry)        [db_get_col $rs $i expiry]
		set DATA($cpm_id,issue_no)      [db_get_col $rs $i issue_no]
		set DATA($cpm_id,card_bin)      [db_get_col $rs $i card_bin]
		set DATA($cpm_id,status)        [db_get_col $rs $i status]
		set DATA($cpm_id,cr_date)       [db_get_col $rs $i cr_date]
		set DATA($cpm_id,hldr_name)     [db_get_col $rs $i hldr_name]
		set DATA($cpm_id,country)       [db_get_col $rs $i country]
		set DATA($cpm_id,scheme)        [db_get_col $rs $i scheme]
		set DATA($cpm_id,bank)          [db_get_col $rs $i bank]
		set DATA($cpm_id,has_resp)      [payment_has_resp $cpm_id]
		set DATA($cpm_id,status_dep)    [db_get_col $rs $i status_dep]
		set DATA($cpm_id,status_wtd)    [db_get_col $rs $i status_wtd]
		set DATA($cpm_id,type)          [db_get_col $rs $i type]
		set DATA($cpm_id,enc_with_bin)  [db_get_col $rs $i enc_with_bin]
		set DATA($cpm_id,scheme_name)   [db_get_col $rs $i scheme_name]
		set DATA($cpm_id,auth_dep)   [db_get_col $rs $i auth_dep]

		if {[check_card_expiry $DATA($cpm_id,expiry)]} {
			set DATA($cpm_id,expired) 0
		} else {
			set DATA($cpm_id,expired) 1
		}

		# now check to see if the tcardinfo table data is wrong
		if {$DATA($cpm_id,country) == "" && $DATA($cpm_id,bank) == ""} {
			ob::log::write ERROR {tcardinfo data missing for card bin $DATA($cpm_id,card_bin)}
			return 0
		}

		set DATA($cpm_id,card_no) ""
		set DATA($cpm_id,card_no_XXX) ""

		lappend enc_db_vals [list \
			$DATA($cpm_id,enc_card_no)\
			$DATA($cpm_id,ivec)\
			$DATA($cpm_id,data_key_id)]

	}

	db_close $rs

	set card_dec_rs [card_decrypt_batch $enc_db_vals \
		"Retrieving customer's active cards"\
		$cust_id]

	if {[lindex $card_dec_rs 0] == 0} {
		ob::log::write ERROR {Error Decrypting card details}

		if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
			# NEED TO CHECK THIS!
			card_util::update_data_enc_status \
				tCPMCC [lindex $DATA(cpm_id) 0] [lindex $card_dec_rs 2]
		}

		return 0
	} else {
		set decrypted_vals [lindex $card_dec_rs 1]
	}

	set i 0

	foreach cpm_id $DATA(cpm_id) {
		set card_plain [format_card_no [lindex $decrypted_vals $i] \
			$DATA($cpm_id,card_bin) \
			$DATA($cpm_id,enc_with_bin)]

		set DATA($cpm_id,card_no) $card_plain
		set DATA($cpm_id,card_no_XXX) [card_replace_midrange $card_plain]
		incr i
	}

	return 1
}



# Returns
# - 0 if a customer has no active cards
# - 1 if a customer has active cards
# - Active means status active and not expired
proc cd_cust_has_active_card {cust_id} {

	if {[catch {set rs [tb_db::tb_exec_qry cd_get_cards_expiry $cust_id]} msg]} {
		ob::log::write ERROR \
			{failed to retrieve customers expired card details: $msg}
		return 0
	}

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set expiry [db_get_col $rs $i expiry]

		if {[check_card_expiry $expiry]} {
			db_close $rs
			return 1
		}
	}

	db_close $rs

	return 0
}


#
# gets the card data for the given cpm
#
proc cd_get_card_data {cpm_id cust_id OUT } {

	upvar 1 $OUT DATA

	set DATA(card_available) "N"
	set DATA(has_resp)      0

	if {[catch {set rs [tb_db::tb_exec_qry cd_card_data $cpm_id]} msg]} {
		ob::log::write ERROR \
			{failed to retrieve card details for $cpm_id: $msg}
		return 0
	}

	if {[db_get_nrows $rs] > 0} {
		set DATA(card_available) "Y"
		set DATA(cpm_id)        [db_get_col $rs 0 cpm_id]
		set DATA(enc_card_no)   [db_get_col $rs 0 enc_card_no]
		set DATA(ivec)          [db_get_col $rs 0 ivec]
		set DATA(data_key_id)   [db_get_col $rs 0 data_key_id]
		set DATA(start)         [db_get_col $rs 0 start]
		set DATA(expiry)        [db_get_col $rs 0 expiry]
		set DATA(issue_no)      [db_get_col $rs 0 issue_no]
		set DATA(card_bin)      [db_get_col $rs 0 card_bin]
		set DATA(status)        [db_get_col $rs 0 status]
		set DATA(cr_date)       [db_get_col $rs 0 cr_date]
		set DATA(hldr_name)     [db_get_col $rs 0 hldr_name]
		set DATA(country)       [db_get_col $rs 0 country]
		set DATA(scheme)        [db_get_col $rs 0 scheme]
		set DATA(bank)          [db_get_col $rs 0 bank]
		set DATA(has_resp)      [payment_has_resp $DATA(cpm_id)]
		set DATA(status_dep)    [db_get_col $rs 0 status_dep]
		set DATA(status_wtd)    [db_get_col $rs 0 status_wtd]
		set DATA(type)          [db_get_col $rs 0 type]
		set DATA(enc_with_bin)  [db_get_col $rs 0 enc_with_bin]
		set DATA(scheme_name)   [db_get_col $rs 0 scheme_name]

		# now check to see if the tcardinfo table data is wrong
		if {$DATA(country) == "" && $DATA(bank) == ""} {
			ob::log::write ERROR {tcardinfo data missing for card bin $DATA(card_bin)}
			return 0
		}

		set DATA(card_no) ""
		set DATA(card_no_XXX) ""

		# Deal with card number
		set card_dec_rs [card_decrypt $DATA(enc_card_no) $DATA(ivec) $DATA(data_key_id) "Retrieving customer's active card" $cust_id]

		if {[lindex $card_dec_rs 0] == 0} {
			# Check on the reason decryption failed, if we encountered corrupt data we should also
			# record this fact in the db
			if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
				card_util::update_data_enc_status "tCPMCC" $DATA(cpm_id) [lindex $card_dec_rs 2]
			}

			ob::log::write ERROR \
				{failed to retrieve customers card details: [lindex $card_dec_rs 1]}
			db_close $rs
			return 0
		} else {
			set dec_card [lindex $card_dec_rs 1]
			set card_plain [format_card_no $dec_card $DATA(card_bin) $DATA(enc_with_bin)]
		}

		set DATA(card_no)     $card_plain
		set DATA(card_no_XXX) [card_replace_midrange $card_plain]
	}

	db_close $rs
	return 1

}




#
# gets a card for a pmt_id
#
# returns nothing if not found
#
proc cd_get_from_pmt_id {pmt_id OUT} {

	upvar 1 $OUT DATA

	set DATA(card_available) "N"
	set DATA(has_resp)      0


	if {[catch {set rs [tb_db::tb_exec_qry cd_card_for_pmt_id $pmt_id]} msg]} {
		ob::log::write ERROR \
			{failed to retrieve customers statement details for pmt_id $pmt_id : $msg}
		return 0
	}

	if {[db_get_nrows $rs] == 1} {
		set DATA(card_available) "Y"
		set DATA(cpm_id)            [db_get_col $rs 0 cpm_id]
		set DATA(enc_card_no)       [db_get_col $rs 0 enc_card_no]
		set DATA(ivec)              [db_get_col $rs 0 ivec]
		set DATA(data_key_id)       [db_get_col $rs 0 data_key_id]
		set DATA(start)             [db_get_col $rs 0 start]
		set DATA(expiry)            [db_get_col $rs 0 expiry]
		set DATA(issue_no)          [db_get_col $rs 0 issue_no]
		set DATA(card_bin)          [db_get_col $rs 0 card_bin]
		set DATA(status)            [db_get_col $rs 0 status]
		set DATA(cr_date)           [db_get_col $rs 0 cr_date]
		set DATA(hldr_name)         [db_get_col $rs 0 hldr_name]
		set DATA(country)           [db_get_col $rs 0 country]
		set DATA(scheme)            [db_get_col $rs 0 scheme]
		set DATA(has_resp)          [payment_has_resp $DATA(cpm_id)]
		set DATA(status_dep)        [db_get_col $rs 0 status_dep]
		set DATA(status_wtd)        [db_get_col $rs 0 status_wtd]
		set DATA(enc_with_bin)      [db_get_col $rs 0 enc_with_bin]
		set DATA(threed_secure_pol) [db_get_col $rs 0 threed_secure_pol]

		# Deal with card number
		set card_dec_rs [card_decrypt $DATA(enc_card_no) $DATA(ivec) $DATA(data_key_id) "Card details for pmt"]

		if {[lindex $card_dec_rs 0] == 0} {
			# Check on the reason decryption failed, if we encountered corrupt data we should also
			# record this fact in the db
			if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
				card_util::update_data_enc_status "tCPMCC" $DATA(cpm_id) [lindex $card_dec_rs 2]
			}

			ob::log::write ERROR \
				{failed to retrieve customers card details: [lindex $card_dec_rs 0]}
			db_close $rs
			return 0
		} else {
			set dec_card [lindex $card_dec_rs 1]
			set card_plain [format_card_no $dec_card $DATA(card_bin) $DATA(enc_with_bin)]
		}

		set DATA(card_no)     $card_plain
		set DATA(card_no_XXX) [card_replace_midrange $card_plain]
	}

	db_close $rs
	return 1
}

proc payment_has_resp {cpm_id} {
	if {[catch {
		set rs [tb_db::tb_exec_qry pmt_mthd_has_resp_by_cpm_id $cpm_id]
	} msg]} {
		ob::log::write ERROR {Error getting ccv2 require $msg}
		return 0
	}

	set has_resp  [db_get_col $rs 0 has_resp]
	set type  [db_get_col $rs 0 type]

	if {[OT_CfgGet DCASH_XML  0]} {
		if {$has_resp > 0 || $type == "EN" || $type == "OP"} {
			ob::DCASH::set_require_cvv2 0
		} else {
			if {![OT_CfgGetTrue IS_CLEARDOWN]} {
				ob::DCASH::set_require_cvv2 1
			} else {
				ob::DCASH::set_require_cvv2 0
			}
		}
	}

	db_close $rs

	return $has_resp
}

proc card_decrypt {enc_card_no ivec data_key_id {crypt_reason ""} {cust_id ""} {oper_name ""}} {

	# First things first - are we actually trying to decrypt any value at all?
	if {$enc_card_no == "" || $enc_card_no == "-"} {
		return [list 1 $enc_card_no]
	}

	if {[OT_CfgGet CRYPT_MONITOR 1]} {
		set req_start [clock format [clock scan now] -format "%Y-%m-%d %H:%M:%S"]

		# Need to calculate the time spent on the request
		set t0 [OT_MicroTime -micro]
		set req_duration ""
	}

	if {[OT_CfgGet ENCRYPT_FROM_CONF 0]} {
		set resp_desc "OK"
		set ret_args [card_decrypt_from_conf $enc_card_no]
	} else {

		# have we already grabbed it this request?
		foreach {found card_unenc} \
			[cryptoAPI::decryptGet $enc_card_no $ivec $data_key_id] {}

		if {$found} {
			set resp_desc "OK"
			set ret_args [list 1 $card_unenc]
		} else {

			set num_retries 0

			while 1 {
				# Initialise the request
				set ret [::cryptoAPI::initRequest]
				if {[lindex $ret 0] != {OK}} {
					ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
					return [list 0 [lindex $ret 0]]
				}

				set ret [::cryptoAPI::addDataRequest 0 \
					[::cryptoAPI::createDataRequest "decrypt" \
						-data       $enc_card_no \
						-ivec       $ivec \
						-keyVersion $data_key_id]]

				if {[lindex $ret 0] != {OK}} {
					ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
					return [list 0 [lindex $ret 0]]
				}

				# Make a Decryption request
				set ret [::cryptoAPI::makeRequest]
				set resp_status [lindex $ret 0]

				# For certain errors we may want to try to initialise/send the request again
				set retry_err 0

				foreach err_exp [OT_CfgGet CRYPTO_RETRY_ERRS [list]] {
					if {[regexp $err_exp $resp_status]} {
						set retry_err 1
					}
				}

				if {$retry_err && $num_retries < [OT_CfgGet CRYPTO_MAX_RETRIES 1]} {
					incr num_retries
				} else {
					break
				}
			}

			if {[lindex $ret 0] != {OK}} {
				# Something went wrong even after potentially multiple attempts. We need to check the response
				# to check what went wrong - if it was a problem with the data we record this fact in the appropriate
				# db table later
				set resp_code [lindex $ret 1]
				ob::log::write ERROR {Error in decryption: $ret}
				if {[lsearch [OT_CfgGet CRYPTO_CORRUPT_DATA_CODES [list]] $resp_code] > -1} {
					# Problem was specifically with badly encrypted data, the calling proc may want to
					# know about this...
					set resp_desc [lindex $ret 2]
					ob::log::write ERROR "Badly encrypted data: Code $resp_code : Desc $resp_desc"
					set ret_args  [list 0 CORRUPT_DATA $resp_code]
				} else {
					# Returned value will have either been 2 (status/desc) or 3 (status/code/desc) values long.
					# We want to use desc in our response to the monitors as it'll be a bit clearer to the users
					if {[llength $ret] == 3} {
						set resp_desc [lindex $ret 2]
					} else {
						set resp_desc $resp_code
					}
					set ret_args [list 0 $resp_desc]
				}
			} else {

				set dec_card [::cryptoAPI::getResponseData 0 data]

				# store the value for later in request
				cryptoAPI::decryptSet $enc_card_no $ivec $data_key_id $dec_card

				set resp_desc "OK"
				set ret_args [list 1 $dec_card]

			}
		}
	}

	if {[OT_CfgGet CRYPT_MONITOR 1]} {
		if {[catch {
			set t1 [OT_MicroTime -micro]
			set tt [expr {$t1-$t0}]
			set req_duration [format %0.4f $tt]
		} msg]} {
			ob::log::write INFO {ignoring floating-point error: t1 ${t1}, t0 ${t0}}
			catch {
				set req_duration [format %0.4f [expr {$t1-$t0}]]
			}
		}

		# Attempting to retrieve ip via reqGetEnv will fail on scripts using standalone
		if {[catch {set ipaddr [reqGetEnv REMOTE_ADDR]}]} {
			set ipaddr ""
		}

		MONITOR::send_crypt \
			"DEC" \
			$data_key_id \
			$cust_id \
			$oper_name \
			[OT_CfgGet APP_TAG ""] \
			$ipaddr \
			$req_start \
			$req_duration \
			$resp_desc \
			$crypt_reason
	}

	return $ret_args
}

# card_decrypt_batch - Functions in essentially the same manner as card_decrypt, but instead of
# requiring a single set of value/ivec/key id values takes a list of triples and returns all
# the necessary decrypted data
proc card_decrypt_batch {enc_data {crypt_reason ""} {cust_id ""} {oper_name ""}} {

	# Before we go any further, have we actually tried to decrypt anything? If we have an empty list
	# we needn't waste any more time
	if {[llength $enc_data] == 0} {
		return [list 1 [list]]
	}

	set dec_data_vals [list]

	if {[OT_CfgGet CRYPT_MONITOR 1]} {
		set req_start [clock format [clock scan now] -format "%Y-%m-%d %H:%M:%S"]

		# Need to calculate the time spent on the request
		set t0 [OT_MicroTime -micro]
		set req_duration ""
	}

	if {[OT_CfgGet ENCRYPT_FROM_CONF 0]} {

		foreach data $enc_data {
			set resp_desc "OK"
			set ret [card_decrypt_from_conf [lindex $data 0]]
			lappend dec_data_vals [lindex $ret 1]
		}

		set ret_args [list 1 $dec_data_vals]
	} else {
		set num_retries 0

		while 1 {
			# Initialise the request
			set ret [::cryptoAPI::initRequest]
			if {[lindex $ret 0] != {OK}} {
				ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
				return [list 0 [lindex $ret 0]]
			}

			# For each set of encrypted values we have, add a node to our decryption request
			set num_decrypts 0
			foreach data $enc_data {
				set ret [::cryptoAPI::addDataRequest $num_decrypts \
					[::cryptoAPI::createDataRequest "decrypt" \
						-data       [lindex $data 0] \
						-ivec       [lindex $data 1] \
						-keyVersion [lindex $data 2]]]

				incr num_decrypts

				if {[lindex $ret 0] != {OK}} {
					ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
					return [list 0 [lindex $ret 0]]
				}
			}

			# Make a Decryption request
			set ret [::cryptoAPI::makeRequest]
			set resp_status [lindex $ret 0]

			# For certain errors we may want to try to initialise/send the request again
			set retry_err 0

			foreach err_exp [OT_CfgGet CRYPTO_RETRY_ERRS [list]] {
				if {[regexp $err_exp $resp_status]} {
					set retry_err 1
				}
			}

			if {$retry_err && $num_retries < [OT_CfgGet CRYPTO_MAX_RETRIES 1]} {
				incr num_retries
			} else {
				break
			}
		}

		if {[lindex $ret 0] != {OK}} {
			# Something went wrong even after potentially multiple attempts. We need to check the response
			# to check what went wrong - if it was a problem with the data we record this fact in the appropriate
			# db table later
			set resp_code [lindex $ret 1]
			ob::log::write ERROR {Error in decryption: $ret}
			if {[lsearch [OT_CfgGet CRYPTO_CORRUPT_DATA_CODES [list]] $resp_code] > -1} {
				# Problem was specifically with badly encrypted data, the calling proc may want to
				# know about this...
				set resp_desc [lindex $ret 2]
				ob::log::write ERROR "Badly encrypted data: Code $resp_code : Desc $resp_desc"
				set ret_args  [list 0 CORRUPT_DATA $resp_code]
			} else {
				# Returned value will have either been 2 (status/desc) or 3 (status/code/desc) values long.
				# We want to use desc in our response to the monitors as it'll be a bit clearer to the users
				if {[llength $ret] == 3} {
					set resp_desc [lindex $ret 2]
				} else {
					set resp_desc $resp_code
				}
				set ret_args [list 0 $resp_desc]
			}
		} else {
			set resp_desc "OK"

			for {set i 0} {$i < $num_decrypts} {incr i} {
				lappend dec_data_vals [::cryptoAPI::getResponseData $i data]
			}
			set ret_args [list 1 $dec_data_vals]
		}
	}

	if {[OT_CfgGet CRYPT_MONITOR 1]} {
		if {[catch {
			set t1 [OT_MicroTime -micro]
			set tt [expr {$t1-$t0}]
			set req_duration [format %0.4f $tt]
		} msg]} {
			ob::log::write INFO {ignoring floating-point error: t1 ${t1}, t0 ${t0}}
			catch {
				set req_duration [format %0.4f [expr {$t1-$t0}]]
			}
		}

		# Attempting to retrieve ip via reqGetEnv will fail on scripts using standalone
		if {[catch {set ipaddr [reqGetEnv REMOTE_ADDR]}]} {
			set ipaddr ""
		}

		MONITOR::send_crypt \
			"DEC" \
			$data_key_id \
			$cust_id \
			$oper_name \
			[OT_CfgGet APP_TAG ""] \
			$ipaddr \
			$req_start \
			$req_duration \
			$resp_desc \
			$crypt_reason
	}

	return $ret_args
}

#-------------------------------------------------------
# card_util::batch_decrypt_db_row
#
# Decrypts a database row of encrypted parameters using batch decryption
#
# values      - list of encrypted value & ivec pairs
# data_key_id - data key id of the encrypted row
# primary_key - primary key serial of the database row being decrypted
# tabname     - table name (just incase we get an error)
#
# Currently takes in a list of encrypted values and decrypts each
# separately with card_util::card_decrypt_batch
# primary_key for the row in question is also passed in to handle the
# event that we encounter corrupted data, in which case we store
# this fact in tabname.enc_status/enc_date
#-------------------------------------------------------
proc batch_decrypt_db_row {values data_key_id primary_key tabname} {

	ob::log::write INFO {card_util::batch_decrypt_db_row \
	                     tabname: '$tabname' \
	                     primary_key : '$primary_key'}

	set enc_data      [list]
	set empty_indexes [list]
	set decrypted     [list]

	for {set i 0} {$i < [llength $values]} {incr i} {
		set val [lindex $values $i]
		set enc_val [lindex $val 0]

		if {$enc_val != ""} {
			set ivec    [lindex $val 1]
			lappend enc_data [list $enc_val $ivec $data_key_id]
		} else {
			# Some values in tPmtGateAcct are empty, and decrypting these will fail,
			# so remove them from the list of things to process, we'll then need to
			# put the empty strings back in the return list later in the correct place
			lappend empty_indexes $i
		}
	}

	set dec_rs [card_util::card_decrypt_batch $enc_data]

	if {[lindex $dec_rs 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db
		if {[lindex $dec_rs 1] == "CORRUPT_DATA"} {
			card_util::update_data_enc_status $tabname $primary_key [lindex $dec_rs 2]
		}
		return $dec_rs
	} else {
		# Payment gateway values are encrypted using the old method of moving
		# the first 8 characters to the end pre-encryption, so need to put it
		# all back
		foreach dec_val [lindex $dec_rs 1] {
			lappend decrypted $dec_val
		}
	}

	# We may have some empty elements to put back in our decrypted values list...
	foreach idx $empty_indexes {
		set decrypted [linsert $decrypted $idx ""]
	}

	return [list 1 $decrypted]
}

proc card_decrypt_from_conf {enc_card_no} {

	global BF_DECRYPT_KEY_HEX
	global BF_DECRYPT_KEY

	if {[string length $enc_card_no] == 0} {
		return ""
	}

	set card_unenc  [blowfish decrypt -hex $BF_DECRYPT_KEY_HEX -hex $enc_card_no]
	set card_unenc  [hextobin $card_unenc]

	return [list 1 $card_unenc]
}

# XXX out the mid section of a card
proc card_replace_midrange {card_unenc {bin_range_decrypted 0} {num_end_digits_decrypted 4}} {
	set l            [string length $card_unenc]
	set replace_str  [OT_CfgGet CARD_DECRYPT_MASK "XXXXXXXXXXXXXXXXXXXX"]

	if {[OT_CfgGet REPLACE_CARD_NO_LONG 0]} {
		set num_end_digits_decrypted [OT_CfgGet NUMBER_END_DIGITS_VISIBLE 4]
		set start_length [OT_CfgGet NUMBER_START_DIGITS_VISIBLE 6]
	} else {
		set start_length [OT_CfgGet NUMBER_START_DIGITS_VISIBLE 6]
	}

	if {$bin_range_decrypted} {
		set disp_0       [string range $card_unenc  0 [expr {$start_length - 1}]]
		set disp_1       [string range $replace_str 6 [expr {$l-[expr {$num_end_digits_decrypted + 1}]}]]
		set disp_2       [string range $card_unenc    [expr {$l-$num_end_digits_decrypted}] end]

		set card_masked $disp_0$disp_1$disp_2
	} else {
		set disp_0 [string range $replace_str 0 [expr {$l-[expr {$num_end_digits_decrypted + 1}]}]]
		set disp_1 [string range $card_unenc [expr {$l-$num_end_digits_decrypted}] end]

		set card_masked $disp_0$disp_1
	}

	return $card_masked
}

proc card_encrypt {card_no {crypt_reason ""} {cust_id ""} {oper_name ""}} {

	if {[OT_CfgGet CRYPT_MONITOR 1]} {
		set req_start [clock format [clock scan now] -format "%Y-%m-%d %H:%M:%S"]

		# Need to calculate the time spent on the request
		set t0 [OT_MicroTime -micro]
		set req_duration ""
	}

	if {[OT_CfgGet ENCRYPT_FROM_CONF 0]} {
		set resp_status "OK"
		set ret_args [card_encrypt_from_conf $card_no]
	} else {
		set num_retries 0

		while 1 {
			# Initialise the request
			set ret [::cryptoAPI::initRequest]
			if {[lindex $ret 0] != {OK}} {
				ob::log::write ERROR "Encryption error: [lindex $ret 1]"
				return [list 0 [lindex $ret 1]]
			}

			# Add the request
			set ret [::cryptoAPI::addDataRequest 0 [::cryptoAPI::createDataRequest "encrypt" -data $card_no]]
			if {[lindex $ret 0] != {OK}} {
				ob::log::write ERROR "Encryption error: [lindex $ret 1]"
				return [list 0 [lindex $ret 1]]
			}

			# Make an Encryption request
			set ret [::cryptoAPI::makeRequest]
			set resp_status [lindex $ret 0]

			# For certain errors we may want to try to initialise/send the request again
			set retry_err 0
			foreach err_exp [OT_CfgGet CRYPTO_RETRY_ERRS [list]] {
				if {[regexp $err_exp $resp_status]} {
					set retry_err 1
				}
			}

			if {$retry_err && $num_retries < [OT_CfgGet CRYPTO_MAX_RETRIES 1]} {
				incr num_retries
			} else {
				break
			}
		}

		if {[lindex $ret 0] != {OK}} {
			set resp_desc [lindex $ret 1]
			ob::log::write ERROR "Encryption error: $resp_desc"
			set ret_args [list 0 $resp_desc]
		} else {
			set enc_card_no  [::cryptoAPI::getResponseData 0 data]
			set ivec         [::cryptoAPI::getResponseData 0 ivec]
			set data_key_id  [::cryptoAPI::getResponseData 0 keyVersion]

			set ret_args [list 1 [list $enc_card_no $ivec $data_key_id]]
		}
	}

	if {[OT_CfgGet CRYPT_MONITOR 1]} {

		if {[catch {
			set t1 [OT_MicroTime -micro]
			set tt [expr {$t1-$t0}]
			set req_duration [format %0.4f $tt]
		} msg]} {
			ob::log::write INFO {ignoring floating-point error: t1 ${t1}, t0 ${t0}}
			catch {
				set req_duration [format %0.4f [expr {$t1-$t0}]]
			}
		}

		set data_key_id [lindex [lindex $ret_args 1] 1]

		# Attempting to retrieve ip via reqGetEnv will fail on scripts using standalone
		if {[catch {set ipaddr [reqGetEnv REMOTE_ADDR]}]} {
			set ipaddr ""
		}

		MONITOR::send_crypt \
			"ENC" \
			$data_key_id \
			$cust_id \
			$oper_name \
			[OT_CfgGet APP_TAG ""] \
			$ipaddr \
			$req_start \
			$req_duration \
			$resp_status \
			$crypt_reason
	}

	return $ret_args
}

proc card_encrypt_from_conf {card_no} {

	global BF_DECRYPT_KEY_HEX

	regsub -all {[^0-9]} $card_no "" card_no

	if {[string length $card_no] == 0} {
		return ""
	}
	#set fx_num [string range $card_no 8 end][string range $card_no 0 7]

	set card_enc [blowfish encrypt -hex $BF_DECRYPT_KEY_HEX -bin $card_no]

	# you can only decrypt from config using a migration key
	set mig_data_key_id [OT_CfgGet MIGRATION_KEY -1]

	return [list 1 [list $card_enc "0000000000000000" $mig_data_key_id]]
}


proc cd_check_prev_pmt {cust_id card_no} {

	# Deal with card number
	set cpm_dec_rs [get_cards_with_hash $card_no "Checking previous payments on a card" $cust_id]

	if {[lindex $cpm_dec_rs 0] == 0} {
		ob::log::write ERROR {Failed to decrypt cpm ids in cd_check_prev_pmt: [lindex $cpm_dec_rs 1]}
		return 1
	} else {
		set dec_cpm_ids [lindex $cpm_dec_rs 1]
	}

	set pmts_found 0

	foreach cpm_id $dec_cpm_ids {
		if {[catch {
			set pmt_rs [tb_db::tb_exec_qry cd_check_prev_pmt $cpm_id $cust_id]
		} msg]} {
			ob::log::write ERROR {failed to check prev pmts on card: $msg}
			return 1
		}

		if {[db_get_nrows $pmt_rs] > 0} {
			db_close $pmt_rs
			set pmts_found 1
			break
		}

		db_close $pmt_rs
	}

	return $pmts_found
}


# Checks if the customer has ever made a payment
proc cd_check_if_cust_made_prev_pmt {cust_id} {

	#
	# search for previous successfuly payments made by the customer
	#
	if {[catch {
		set rs [tb_db::tb_exec_qry cd_check_if_cust_made_prev_pmt $cust_id]
	} msg]} {
		ob::log::write ERROR {failed to check prev pmts made by customer: $msg}
		return 1
	}

	if {[db_get_nrows $rs] > 0} {
		set result 1

	} else {
		set result 0
	}

	db_close $rs

	return $result
}

#
# Retrieves the card type (VISA, AMEX etc.) for a passed card number
# Arguments: card number
#
proc get_card_scheme {card_no} {

	if {[string length $card_no] < 6} {
		return ""
	}

	set card_bin [string range $card_no 0 5]

	if {[catch {
		set rs [tb_db::tb_exec_qry get_card_scheme $card_bin $card_bin]
	} msg]} {
		ob::log::write ERROR {failed to retrieve card scheme: $msg}
		return ""
	}

	if {[db_get_nrows $rs] == 1} {
		set card_info [list [db_get_col $rs 0 scheme]\
							[db_get_col $rs 0 start_date]\
							[db_get_col $rs 0 issue_length]]
	} else {
		ob::log::write ERROR {card scheme query returned [db_get_nrows $rs] rows}
		set card_info ""
	}

	db_close $rs
	return $card_info
}

#
# Retrieves the name of the issuing bank for a passed card bin no.
#
proc cd_get_issuer {card_bin} {

	#
	# search for previous successfuly payments
	#
	if {[catch {set rs [tb_db::tb_exec_qry cd_get_issuer $card_bin]} msg]} {
		ob::log::write ERROR {Failed to retrieve card issuer: $msg}
		return ""
	}

	if {[db_get_nrows $rs] == 1} {
		set card_info [list [db_get_col $rs 0 bank] [db_get_col $rs 0 country]]
	} else {
		ob::log::write DEV {card issuer query returned [db_get_nrows $rs] rows}
		set card_info ""
	}

	db_close $rs
	return $card_info
}

#
# Checks to see if a customer has unsettled bets at cantor
# returns balance of unsettled bet if successful, 0 if no unsettled bets
# or they haven't ever placed cantor bets.
# returns FAILED if the check is unsuccessful eg if there is a timeout
#
proc get_cantor_unsettled_bets {cust_id timeout} {

	variable connected
	variable reply_available
	variable xml_response
	variable sock

	# first check to see if played cantor financials
	if {[catch {
		set rs [tb_db::tb_exec_qry cd_get_acct_by_xfer $cust_id \
			[OT_CfgGet CANTOR_SYS_NAME "Cantor Financial"]]
	} msg]} {
		ob::log::write ERROR { get_cantor_unsettled_bets ->\
		has played cantor query failed: $msg}
		return "FAILED"
	}


	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		ob::log::write INFO {get_cantor_unsettled_bets ->\
		Customer: $cust_id has not played cantor financials}
		return 0
	}
	db_close $rs
	set card_util::connected ""
	if {[catch {
		set rs [tb_exec_qry tb_db::cd_get_cust_username $cust_id]
	} msg]} {
		ob::log::write ERROR { get_cantor_unsettled_bets ->\
		username query failed: $msg}
		return "FAILED"
	}
	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR { get_cantor_unsettled_bets ->\
		wrong number of rows returned for username query}
		db_close $rs
		return "FAILED"
	}
	set username [db_get_col $rs 0 username]
	db_close $rs

	set id [after $timeout {set card_util::connected "TIMED_OUT"}]
	if [catch {set sock [socket -async [OT_CfgGet CANTOR_API_IP] [OT_CfgGet CANTOR_API_PORT]]}] {
		ob::log::write ERROR {failed to connect to server [OT_CfgGet CANTOR_API_IP]:[OT_CfgGet CANTOR_API_PORT]}
		return "FAILED"
	}
	fileevent $sock w {set card_util::connected "OK"}
	vwait card_util::connected
	fileevent $sock w {}
	after cancel $id

	if {$card_util::connected == "TIMED_OUT"} {
			catch {close $sock}
		ob::log::write ERROR "get_cantor_unsettled_bets -> \
		Cantor connection attempt timed out after $timeout ms"
		return "FAILED"
	} else {
		fconfigure $sock -blocking 0 -buffering line -encoding iso8859-1

		# flush out the initial response - we're not interested in this
		 while {![fblocked $sock]} {
			set s [gets $sock]
		}

		# now build the request xml - needs to be terminated with a zero byte
		set request_string "<CustomerOpenBetsSummaryReq customerId=\"$cust_id\"\
		customerUsername=\"$username\"/>[binary format "B8" 00000000]"

		set id [after $timeout { set card_util::reply_available "TIMED_OUT" }]
		puts $sock $request_string
		flush $sock

		fileevent $sock readable {
								set card_util::xml_response [gets $card_util::sock]
								if {$card_util::xml_response != ""} {
									set card_util::reply_available "OK"
								}
							}

		vwait card_util::reply_available
		after cancel $id


		if {$card_util::reply_available == "TIMED_OUT" } {
			catch {close $sock}
			ob::log::write ERROR "get_cantor_unsettled_bets -> \
			Failed to obtain response from cantor after $timeout ms"
			return "FAILED"
		} else {
			ob::log::write DEBUG "get_cantor_unsettled_bets -> \
			Response:$xml_response"
			close $sock

			if {[catch {dom parse -simple $xml_response doc} msg]} {
			 	ob::log::write ERROR {get_cantor_unsettled_bets ->Error parsing Cantor response XML: $msg}
				return "FAILED"
			}

			set element [$doc getElementsByTagName {CustomerOpenBetsSummaryReply}]
			if {[llength $element] != 1} {
				ob::log::write ERROR "get_cantor_unsettled_bets -> \
				XML Response is invalid"
				return "FAILED"
			}

			set single_element [lindex $element 0]
			set status [$single_element getAttribute "status" ""]

			if {$status == "Failed"} {
				ob::log::write ERROR "get_cantor_unsettled_bets -> \
				Cantor returned status: Failed"
				return "FAILED"
			} elseif {$status == "Success"} {
				set customerId [$single_element getAttribute "customerId" ""]
				set customerUsername [$single_element getAttribute "customerUsername" ""]
				set numOpenBets [$single_element getAttribute "numOpenBets" ""]
				set totalOpenStake [$single_element getAttribute "totalOpenStake" ""]
				if {$customerId == "" || $customerUsername == "" || $numOpenBets == "" || $totalOpenStake == ""} {
					ob::log::write ERROR "get_cantor_unsettled_bets -> \
					Required parameters missing from XML response"
					return "FAILED"
				}

				if {$customerId == $cust_id && $customerUsername == $username} {

					if {$numOpenBets > 0 } {
						if {$totalOpenStake > 0} {
							ob::log::write INFO {get_cantor_unsettled_bets ->\
							Customer: $username has an open stake of: $totalOpenStake}
							return $totalOpenStake
						} else {
							ob::log::write ERROR "get_cantor_unsettled_bets -> \
							Response says there are unsettled bets for customer: $username\
							but stake is not > 0. Error."
							return "FAILED"
						}
					} else {
						ob::log::write INFO {get_cantor_unsettled_bets ->\
						Customer: $username has no unsettled bets}
						return 0
					}
				} else {
					ob::log::write ERROR "get_cantor_unsettled_bets -> \
					Username or cust_id in Cantor XML response invalid."
					return "FAILED"
				}
			} else {
				ob::log::write ERROR "get_cantor_unsettled_bets -> \
				Unable to parse Cantor XML response."
				return "FAILED"
			}
		}
	}
}

#
# checks whether a customer has a balance on a ctxm game
# checks all ctxm games
#
# RETURNS
# <success (1 for success, 0 failure)> <total_balance> {<game1_name> <game1_balance> <game1_num_open>} {<game2_name>, <game2_bal......etc }
#
proc get_ctxm_game_balance {username acct_id} {

	if {[catch { set rs  [tb_db::tb_exec_qry has_played_ctxm $acct_id ]} msg]} {
		ob::log::write ERROR {Failed to execute recent_ctxm_stake: $msg}
		return [list 0]
	}
	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		ob::log::write INFO {get_ctxm_game_balance ->\
		Customer: $username has not played any ctxm games. Not checking.}
		return [list 1]
	}
	db_close $rs

	dom setResultEncoding "UTF-8"
	set dom_msg   [dom createDocument "CustomerBalanceReq"]
	set root_node [$dom_msg documentElement]

	# please note that all the attribute name is customerId this is in fact the openbet username
	$root_node setAttribute "customerId" "$username"

	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$dom_msg asXML]"
	$dom_msg delete

	if {[catch {set http_response\
		[http::geturl "[OT_CfgGet CTXM_BAL_CHECK_URL "/"]"\
			 -timeout [OT_CfgGet CTXM_TIMEOUT 10000]\
			 -query $xml_msg]} msg]} {
		catch {http::cleanup $http_response}
		ob::log::write WARNING {get_ctxm_game_balance: Failed to contact [OT_CfgGet CTXM_BAL_CHECK_URL "/"] - xml=$xml_msg - msg: $msg}
		return [list 0]
	}

	# check the response is valid
	set response [OB_MCS_utils::validateResponse $http_response]
	if {$response != "OK"} {
		catch {http::cleanup $http_response}
		ob::log::write WARNING {get_ctxm_game_balance: Problem with HTTP response code from [OT_CfgGet CTXM_BAL_CHECK_URL "/"]  - xml=$xml_msg - response: $response}
		return [list 0]
	}

	#obtained a valid response. Parse it
	set xml_response [http::data $http_response]
	http::cleanup $http_response


	if {[catch {dom parse -simple $xml_response doc} msg]} {
		ob::log::write ERROR {get_ctxm_game_balance ->Error parsing CTXM response XML: $msg}
		return [list 0]
	}

	set element [$doc getElementsByTagName {CustomerBalanceResp}]
	if {[llength $element] != 1} {
		ob::log::write ERROR "get_ctxm_game_balance -> \
		XML Response is invalid: $xml_response"
		return [list 0]
	}

	set single_element [lindex $element 0]
	set totalStake [$single_element getAttribute "totalOpenStake" ""]
	set customerId [$single_element getAttribute "customerId" ""]
	set return_list [list]
	lappend return_list 1
	lappend return_list $totalStake

	# first check that the sent customer_id is recognised by ctxm - if not return failed as something has gone wrong
	if {$customerId == "unknown_username"} {
		ob::log::write ERROR "get_ctxm_game_balance -> \
		Customer not recognised by ctxm. Check failed"
		return [list 0]
	}

	if {$totalStake == ""} {
		ob::log::write ERROR "get_ctxm_game_balance -> \
		XML Response is invalid: $xml_response"
		return [list 0]
	} elseif {$totalStake == 0} {
		#no open stake, don't record the individual stakes
		ob::log::write INFO "get_ctxm_game_balance -> \
		Customer:$username has ctxm balance of 0"
		return $return_list
	} else {
		# customer has open stake get the stakes for each individual game
		set element [$doc getElementsByTagName {GameBalanceDetail}]
		if {[llength $element] == 0} {
			ob::log::write ERROR "get_ctxm_game_balance -> \
			XML Response is invalid: $xml_response"
			return [list 0]
		}

		for {set i 0} {$i < [llength $element]} {incr i} {
			set single_element [lindex $element $i]
			set gameStake [$single_element getAttribute "openStake" ""]
			set gameName [$single_element getAttribute "game" ""]
			set gameNoOpen [$single_element getAttribute "openGames" ""]
			if {$gameStake == "" || $gameName == "" || $gameNoOpen == ""} {
				ob::log::write ERROR "get_ctxm_game_balance -> \
				XML Response is invalid: $xml_response"
				return [list 0]
			}
			lappend return_list [list $gameName $gameStake $gameNoOpen]
		}
	}
	return $return_list
}

#
# checks that a customers xsysxfers are all of types known about to the
# ok_to_delete proc - prevents new games being added but openbet
# not checking for the hidden funds
#
# RETURNS
# <success (1 for success, 0 failure)> <unknown_xfers (1 for yes/0 for no)> <unknown_game_names>
#
proc chk_no_unknown_xfers {acct_id} {

	if {[catch { set rs  [tb_db::tb_exec_qry chk_unknown_host_xfer $acct_id]} msg]} {
		ob::log::write ERROR {Failed to execute chk_unknown_host_xfers: $msg}
		return [list 0]
	}

	if {[db_get_nrows $rs] > 0} {
		set game_names ""
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			append game_names "[db_get_col $rs $i name] "
		}
		db_close $rs
		ob::log::write INFO {chk_no_unknown_xfers ->\
		Found customer xsysxfer entries for customer that are\
		not known about by ok_to_delete}
		return [list 1 1 $game_names]
	} else {
		db_close $rs
		return [list 1 0]
	}
}

#
# Checks if a customer has a particular credit card number registered as an active CPM on their account
#
# Returns - [list 0 <error>]  on failure
#           [list 1 <cpm_id>] on success, where cpm_id is the customer's active instance
#                             of the card number, or -1 if one is not available
#
proc get_cpm_id_for_card {cust_id card_no} {

	if {[catch {set active_rs [tb_db::tb_exec_qry cd_active_cust_card $cust_id]} msg]} {
		ob::log::write ERROR {cd_active_cust_card failed in proc card_util::get_cpm_id_for_card: $msg}
		return [list 0 {cd_active_cust_card failed in proc card_util::get_cpm_id_for_card: $msg}]
	}

	set matching_cpm_id -1

	for {set i 0} {$i < [db_get_nrows $active_rs]} {incr i} {
		# For each of this customer's active cards, reconstruct the card number
		# using the bin and decrypted enc_card_no values from tcpmcc, and compare
		# with the card number we're looking for
		set cpm_id       [db_get_col $active_rs $i cpm_id]
		set card_bin     [db_get_col $active_rs $i card_bin]
		set enc_card_no  [db_get_col $active_rs $i enc_card_no]
		set ivec         [db_get_col $active_rs $i ivec]
		set data_key_id  [db_get_col $active_rs $i data_key_id]
		set enc_with_bin [db_get_col $active_rs $i enc_with_bin]

		# Deal with card number
		set card_dec_rs [card_decrypt $enc_card_no $ivec $data_key_id "Card Insert Validation" $cust_id]

		if {[lindex $card_dec_rs 0] == 0} {
			# Check on the reason decryption failed, if we encountered corrupt data we should also
			# record this fact in the db
			if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
				update_data_enc_status "tCPMCC" $cpm_id [lindex $card_dec_rs 2]
			}

			ob::log::write ERROR {failed to decrypt customers card details: [lindex $card_dec_rs 1]}
			db_close $active_rs
			return [list 0 [lindex $card_dec_rs 0]]
		} else {
			set dec_card_no [lindex $card_dec_rs 1]
		}

		set whole_card_no [format_card_no $dec_card_no $card_bin $enc_with_bin]

		if {$whole_card_no == $card_no} {
			# We've found what we're looking for so we can stop searching the rest of the customer's active cpm ids
			set matching_cpm_id [db_get_col $active_rs $i cpm_id]
			break
		}
	}

	db_close $active_rs
	return [list 1 $matching_cpm_id]
}

# encrypt_cpm_id/decrypt_cpm_id - called whenever encrypting/decrypting cpm_ids for tCPMCCHash
# Currently just wrappers for card_encrypt
proc encrypt_cpmid {cpm_id {crypt_reason ""} {cust_id ""} {oper_name ""}} {

	set ret [card_encrypt $cpm_id $crypt_reason $cust_id $oper_name]

	if {[lindex $ret 0] == 0} {
		return [list 0 [lindex $ret 1]]
	}

	return [list 1 [lindex $ret 1]]
}

proc decrypt_cpmid {cpm_id_info {crypt_reason ""} {cust_id ""} {oper_name ""} {tabname "tCPMCCHash"}} {

	set enc_data [list]
	set hash_ids [list]

	foreach val $cpm_id_info {
		lappend hash_ids [lindex $val 0]
		set enc_id       [lindex $val 1]
		set ivec         [lindex $val 2]
		set data_key_id  [lindex $val 3]
		lappend enc_data [list $enc_id $ivec $data_key_id]
	}

	set ret [card_decrypt_batch $enc_data $crypt_reason $cust_id $oper_name]
	if {[lindex $ret 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db. Since we've no way of identifying which member of the batch
		# failed we mark them all
		if {[lindex $ret 1] == "CORRUPT_DATA"} {
			foreach hash_id $hash_ids {
				update_data_enc_status $tabname $hash_id [lindex $ret 2]
			}
		}

		return [list 0 [lindex $ret 1]]
	}

	return [list 1 [lindex $ret 1]]
}

proc format_card_no {card_no bin with_bin {replace_uprange 0} {show_bin 0}} {

	if {$with_bin == "Y"} {

		# Bin encrypted with the card indicates that it was encrypted with the 'old'
		# decryption method ie moving the first 8 digits of the whole card number to
		# the end and encrypting the whole thing, so need to reshuffle the digits into
		# the right order
		set l           [string length $card_no]

		set bit_0       [string range $card_no   [expr {$l-8}] end]
		set bit_1       [string range $card_no 0 [expr {$l-9}]]
		set card_plain  $bit_0$bit_1

		set complete_card_no $card_plain
	} else {
		set complete_card_no "${bin}${card_no}"
	}

	if {$replace_uprange} {
		set complete_card_no [card_replace_midrange $complete_card_no $show_bin]
	}
	return $complete_card_no
}

# Encryption/decryption monitor messages require the username of the adminuser
# making the request, however the particular function in here may instead have
# the user_id instead, use this to get the username
proc get_admin_username {user_id} {

	if {[catch {set rs [tb_db::tb_exec_qry get_admin_username $user_id]} msg]} {
		ob::log::write ERROR {failed qry get_admin_username : $msg}
		return ""
	}

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		return ""
	}

	set username [db_get_col $rs 0 username]
	db_close $rs
	return $username
}

# Returns the cpm ids of all cards in tCPMCCHash with a specific card number
# The other arguments here are optional and dictate what information will be sent
# to the monitor when we attempt to decrypt the CPM ids in tCPMCCHash
proc get_cards_with_hash {card_no {mon_rsn ""} {cust_id ""} {oper_id ""}} {

	# First hash the card number to use in a search on tCPMCCHash
	set card_hash [md5 $card_no]

	# We obtain the (encrypted) cpm ids of any instances of this card number that
	# already exist in the db (this may be other customers already using the same
	# card number, or previous instances of this card registered to this customers
	if {[catch {set dup_rs [tb_db::tb_exec_qry get_cards_with_hash $card_hash]} msg]} {
		set msg "get_cards_with_hash failed in proc card_util::get_cards_with_hash: $msg"
		ob::log::write ERROR {$msg}
		return [list 0 $msg]
	}
	set found_ids [list]

	for {set i 0} {$i < [db_get_nrows $dup_rs]} {incr i} {
		set cc_hash_id  [db_get_col $dup_rs $i cc_hash_id]
		set enc_cpm_id  [db_get_col $dup_rs $i enc_cpm_id]
		set ivec        [db_get_col $dup_rs $i ivec]
		set data_key_id [db_get_col $dup_rs $i data_key_id]

		lappend found_ids [list $cc_hash_id $enc_cpm_id $ivec $data_key_id]
	}

	db_close $dup_rs

	# Deal with card number
	set cpm_dec_rs [decrypt_cpmid $found_ids $mon_rsn $cust_id [get_admin_username $oper_id]]

	if {[lindex $cpm_dec_rs 0] == 0} {
		ob::log::write ERROR {cpm id decryption failed in proc card_util::get_cards_with_hash: [lindex $cpm_dec_rs 1]}
		return [list 0 [lindex $cpm_dec_rs 1]]
	} else {
		return [list 1 [lindex $cpm_dec_rs 1]]
	}
}

# Records a failure to decrypt data due to it having become corrupted somehow. With any luck we
# won't ever need to come here as it implies that something's gone wrong with the new encryption/
# decryption mechanism. This allows the various tables to be queried for rows with values in
# enc_status and a useful timestamp of when we discovered a problem with the data to help trace it
proc update_data_enc_status {tabname id enc_status} {

	ob::log::write INFO {UPDATING STATUS OF BADLY ENCRYPTED DATA IN table $tabname ID $id : STATUS $enc_status}

	# Decide based on the tabname provided which update we're going to do
	switch -- $tabname {
		tPmtGateAcct {
			set upd_qry "update_pmt_gate_acct_enc_fail"
		}
		tCardBlock {
			set upd_qry "update_card_block_enc_fail"
		}
		tCPMCC {
			set upd_qry "update_cpm_cc_enc_fail"
		}
		tCPMCCHash {
			set upd_qry "update_cpm_cc_hash_enc_fail"
		}
		tCardReg {
			set upd_qry "update_card_reg_enc_fail"
		}
		tCardRegHash {
			set upd_qry "update_card_reg_hash_enc_fail"
		}
		tC3Call {
			set upd_qry "update_c3_call_enc_fail"
		}
		tPmtGateAcct {
			set upd_qry "update_risk_guard_acct_enc_fail"
		}
		tCustIdent {
			set upd_qry "update_cust_ident_enc_fail"
		}
		tRGHost {
			set upd_qry "update_rg_host_enc_fail"
		}
		default {
			ob::log::write ERROR {Failed to update status of bad encrypted data: invalid table $tabname}
			return 0
		}
	}

	# Update the appropriate table's status
	if {[catch {set res [tb_db::tb_exec_qry $upd_qry $enc_status $id]} msg]} {
		ob::log::write ERROR {Error getting $tabname entries for re-encryption: $msg}
		return 0
	}

	return 1
}

# Given an encrypted value, the initialisation vector used when encrypting and the data key id it's
# encrypted with, attempt to make a reEncrypt call to the server and return information on the newly
# encrypted data
proc re_encrypt_data {enc_data} {

	if {[OT_CfgGet ENCRYPT_FROM_CONF 0]} {
		# If we're still using configs then there's very little value doing anything here,
		# since we're still on the migration key, so just return what we had before
		return [list OK $enc_data]
	} else {
		set num_retries 0

		while 1 {
			# Initialise the request
			set ret [::cryptoAPI::initRequest]
			if {[lindex $ret 0] != {OK}} {
				ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
				return [list 0 [lindex $ret 0]]
			}

			set num_re_encrypts 0
			foreach data $enc_data {
				set ret [::cryptoAPI::addDataRequest $num_re_encrypts \
					[::cryptoAPI::createDataRequest "reEncrypt" \
						-data       [lindex $data 0] \
						-ivec       [lindex $data 1] \
						-keyVersion [lindex $data 2]]]

				incr num_re_encrypts

				if {[lindex $ret 0] != {OK}} {
					ob::log::write ERROR {Error in decryption: [lindex $ret 0]}
					return [list 0 [lindex $ret 0]]
				}
			}

			# Make a Decryption request
			set ret [::cryptoAPI::makeRequest]
			set resp_status [lindex $ret 0]
			# For certain errors we may want to try to initialise/send the request again
			set retry_err 0
			foreach err_exp [OT_CfgGet CRYPTO_RETRY_ERRS [list]] {
				if {[regexp $err_exp $resp_status]} {
					set retry_err 1
				}
			}

			if {$retry_err && $num_retries < [OT_CfgGet CRYPTO_MAX_RETRIES 1]} {
				incr num_retries
			} else {
				break
			}
		}

		if {[lindex $ret 0] != {OK}} {
			# Something went wrong even after potentially multiple attempts. We need to check the response
			# to check what went wrong - if it was a problem with the data we record this fact in the appropriate
			# db table later
			set resp_code [lindex $ret 1]
			ob::log::write ERROR {Error in decryption: $ret}
			if {[lsearch [OT_CfgGet CRYPTO_CORRUPT_DATA_CODES [list]] $resp_code] > -1} {
				# Problem was specifically with badly encrypted data, the calling proc may want to
				# know about this...
				set resp_desc [lindex $ret 2]
				ob::log::write ERROR "Badly encrypted data: Code $resp_code : Desc $resp_desc"
				return [list 0 CORRUPT_DATA $resp_code]
			} else {
				# Returned value will have either been 2 (status/desc) or 3 (status/code/desc) values long.
				# We want to use desc in our response to the monitors as it'll be a bit clearer to the users
				if {[llength $ret] == 3} {
					set resp_desc [lindex $ret 2]
				} else {
					set resp_desc $resp_code
				}
				return [list 0 $resp_desc]
			}
		}

		set re_encrypted_data [list]

		for {set i 0} {$i < $num_re_encrypts} {incr i} {
			set new_enc_val     [::cryptoAPI::getResponseData $i data]
			set new_ivec        [::cryptoAPI::getResponseData $i ivec]
			set new_data_key_id [::cryptoAPI::getResponseData $i keyVersion]

			lappend re_encrypted_data [list $new_enc_val $new_ivec $new_data_key_id]
		}
	}

	return [list OK $re_encrypted_data]
}

proc get_chan_site_operator_id {cust_channel} {

	if {[catch {
		set rs [tb_db::tb_exec_qry \
		get_site_operator_id $cust_channel]
	} msg]} {
		ob::log::write ERROR {Failed to execute get_site_operator_id: $msg}
		return -1
	}

	if {[db_get_nrows $rs] > 0} {
		set site_operator_id [db_get_coln $rs 0 0]
	} else {
		ob::log::write ERROR {get_site_operator_id unexpected number of rows returned}
		db_close $rs
		return -1
	}

	db_close $rs

	return $site_operator_id
}

proc get_cust_site_operator_id {cust_id} {

	if {[catch {
		set rs [tb_db::tb_exec_qry \
		get_cust_source_channel $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute get_cust_source_channel: $msg}
		return 0
	}
	if {[db_get_nrows $rs] > 0} {
		set cust_channel [db_get_coln $rs 0 0]
	} else {
		ob::log::write ERROR {Unexpected number of rows returned from get_cust_source_channel}
		db_close $rs
		return 0
	}

	db_close $rs

	set site_operator_id [get_chan_site_operator_id $cust_channel]

	return $site_operator_id
}

proc get_cust_acct_type {cust_id} {

	if {[catch {
		set rs [tb_db::tb_exec_qry \
		get_cust_acct_type $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute get_cust_acct_type: $msg}
		return 0
	}
	if {[db_get_nrows $rs] > 0} {
		set acct_type [db_get_coln $rs 0 0]
	} else {
		ob::log::write ERROR {Unexpected number of rows returned from get_cust_acct_type}
		db_close $rs
		return 0
	}

	db_close $rs

	return $acct_type
}


#
# initialise this file
#
init_card_util

# close namespace
}
