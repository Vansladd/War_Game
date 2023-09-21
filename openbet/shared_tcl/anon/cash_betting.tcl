# $Header: /cvsroot-openbet/training/openbet/shared_tcl/anon/cash_betting.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
# ==============================================================
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

package require util_db

package provide OB_CASH_BET 0.1

namespace eval OB_CASH_BET {
	variable INIT 0
}

# Initialisation
#
proc OB_CASH_BET::init {} {

	variable INIT

	if {$INIT} {
		ob_log::Write WARNING {OB_CASH_BET::init - Already initialised}
		return
	}

	ob_log::write DEBUG {OB_CASH_BET::init: Initialising}

	ob_db::init
	OB_CASH_BET::_prep_sql

	set INIT 1
}

proc OB_CASH_BET::_prep_sql {} {

	ob_db::store_qry OB_CASH_BET::open_session {
		execute procedure pInsSession
		(
			p_term_code          = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::get_shop_session {
		select
			ss.shop_session_id,
			ss.start_time
		from
			tshopsession ss
		where
			(ss.loc_code = ? or (ss.loc_code = (
				select loc_code from tadminterm where term_code = ?))
			)
			and ss.end_time is null
	}

	ob_db::store_qry OB_CASH_BET::open_shop_session {
		execute procedure pInsShopSession(
			p_loc_code = ?
		)
	}
	ob_db::store_qry OB_CASH_BET::ins_shop_session_ccy {
		execute procedure pInsShopSessionCcy
		(
			p_shop_session_id    = ?,
			p_ccy_code           = ?,
			p_sod_sys_float      = ?,
			p_sod_dec_float      = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::upd_shop_session_ccy {
		execute procedure pUpdShopSessionCcy
		(
			p_eod_sys_float      = ?,
			p_eod_dec_float      = ?,
			p_shop_session_id    = ?,
			p_ccy_code           = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::close_shop_session {
		execute procedure pCloseShopSession
		(
			p_loc_code        = ?,
			p_eod_user_id     = ?,
			p_safe_count      = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::set_shop_session_safe_count {
		update
			tShopSession
		set
			safe_count = ?
		where
			loc_code = ?
			and end_time is null
	}

	ob_db::store_qry OB_CASH_BET::assign_shop_session {
		execute procedure pAssignShopSession(
			p_session_id = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::ins_session_ccy {
		execute procedure pInsSessionCcy
		(
			p_session_id       = ?,
			p_ccy_code         = ?,
			p_float            = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::end_session {
		update
			tSession
		set
			end_time           = current
		where
			session_id         = ?

	}

	ob_db::store_qry OB_CASH_BET::get_open_session {
		select
			unique s.session_id,
			s.start_time
		from
			tSession s
		where
			s.end_time is null
		and s.term_code = ?
		order by
			s.start_time
	}

	ob_db::store_qry OB_CASH_BET::get_most_recent_closed_session {
		select first 1
			session_id,
			s.start_time,
			end_time
		from
			tsession s
		where
				s.term_code = ?
			and s.shop_session_id is not null
			and s.end_time is not null
		order by
			s.end_time desc
	}

	ob_db::store_qry OB_CASH_BET::check_is_session_open {
		select
			sc.float,
			sc.ccy_code,
			s.start_time,
			s.end_time
		from
			tSession s,
			tSessionCcy sc
		where
			s.session_id = ?
			and s.session_id = sc.session_id
	}

	ob_db::store_qry OB_CASH_BET::get_session_ccys {
		select
			session_ccy_id,
			ccy_code,
			float,
			NVL(num_bets,0) as num_bets,
			NVL(stake_total,0) as stake_total,
			NVL(num_paid_out,0) as num_paid_out,
			NVL(paid_out_total,0) as paid_out_total,
			NVL(num_paid_in,0) as num_paid_in,
			NVL(paid_in_total,0) as paid_in_total,
			NVL(num_canc_bets,0) as num_canc_bets,
			NVL(canc_stake,0) as canc_stake,
			NVL(num_void_payout,0) as num_void_payout,
			NVL(void_payout,0) as void_payout
		from
			tSessionCcy
		where session_id = ?
	}

	ob_db::store_qry OB_CASH_BET::get_session_ccy_id {
		select
			session_ccy_id,
			float
		from
			tSessionCcy
		where
			session_id = ?
			and ccy_code = ?
	}

	ob_db::store_qry OB_CASH_BET::get_term_acct_ccys {
		select
			a.ccy_code
		from
			tacct a,
			ttermacct t
		where
			t.acct_id = a.acct_id and
			a.acct_type = "PUB" and
			t.term_code = ?
	}

	ob_db::store_qry OB_CASH_BET::do_cash_payment {
		execute procedure pQuickCashPmt
		(
			p_acct_id       = ?,
			p_amount        = ?,
			p_payment_sort  = ?,
			p_term_code     = ?,
			p_ipaddr        = ?,
			p_source        = ?,
			p_oper_id       = ?,
			p_j_op_type     = ?,
			p_transactional = 'N',
			p_cpm_id        = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::upd_session_ccy_float {
		execute procedure pUpdSessionCcy
		(
			p_session_ccy_id = ?,
			p_amount = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::make_sess_jrnl_entry {
		execute procedure pInsCashJrnl
		(
			p_sess_j_op_type = ?,
			p_session_ccy_id = ?,
			p_amount = ?,
			p_oper_id = ?,
			p_j_op_ref_key = ?,
			p_j_op_ref_id = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::transfer_funds {
		execute procedure pTermTransfer
		(
			p_from_acct_id  =       ?,
			p_to_acct_id    =       ?,
			p_user_id       =       ?,
			p_txn_type      =       ?,
			p_amount        =       ?,
			p_transactional =      "Y"
		)
	}

	ob_db::store_qry OB_CASH_BET::get_anon_acct_details {
		select
			a.cust_id,
			a.acct_id,
			a.acct_type,
			a.balance,
			c.acct_no
		from
			tacct a,
			ttermacct t,
			tCustomer c
		where
			t.term_code = ? and
			t.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			a.ccy_code = ?
	}

	ob_db::store_qry OB_CASH_BET::receipt_payout {
		execute procedure pAnonCollect(
			p_ref_key = ?,
			p_ref_id = ?,
			p_term_code = ?,
			p_user_id = ?,
			p_transactional = ?)
	}

	ob_db::store_qry OB_CASH_BET::get_acct_term_code {
		select
			term_code
		from
			ttermacct
		where
			acct_id = ?
	}

	ob_db::store_qry OB_CASH_BET::get_ccy_code {
		select
			ccy_code
		from
			tAcct
		where
			acct_id = ?
	}

	ob_db::store_qry OB_CASH_BET::get_pub_acct_id {
		select
			t.acct_id
		from
			tAcct a,
			tTermAcct t
		where
			t.term_code = ? and
			t.acct_id = a.acct_id and
			a.acct_type = 'PUB' and
			a.ccy_code = ?
	}

	# Transfer float may take a transfer type
	if {[OT_CfgGet ENABLE_TRANSFER_TYPES 0]} {
		set extra_parameters {
			,p_transfer_type_id = ?
		}
	} else {
		set extra_parameters ""
	}

	ob_db::store_qry OB_CASH_BET::transfer_float [subst {
		execute procedure pXferFloat
		(
			p_to_sess_ccy_id   = ?,
			p_from_sess_ccy_id = ?,
			p_amount           = ?,
			p_transactional    = ?,
			p_oper_id          = ?,
			p_term_code        = ?
			$extra_parameters
		)
	}]

	ob_db::store_qry OB_CASH_BET::transfer_session_float {
		execute procedure pXferSessFloat
		(
			p_to_sess_ccy_id          = ?,
			p_from_sess_ccy_id        = ?,
			p_amount                  = ?,
			p_transactional           = ?,
			p_oper_id                 = ?,
			p_term_code               = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::create_credit_slip {
		execute procedure pCreditSlip
		(
			p_term_code = ?,
			p_amount    = ?,
			p_ccy_code  = ?,
			p_call_id   = ?,
			p_transactional = 'N'
		)
	}

	ob_db::store_qry OB_CASH_BET::barcode_bet {
		select
		  b.bet_id id,
		  a.cust_id cust_id,
		  to_char(b.cr_date,'%d %b %Y %R') cr_date,
		  b.receipt,
		  b.stake,
		  b.settled,
		  (b.winnings + b.refund) as returns,
		  b.num_lines,
		  b.bet_type,
		  b.leg_type,
		  b.bet_id,
		  ad.username as operator,
		  b.source,
		  a.acct_id,
		  a.ccy_code,
		  a.owner
		from
		  tBet b,
		  tAcct a,
		  outer (tCall ca, tAdminUser ad)
		where
		  b.acct_id = a.acct_id and
		  b.call_id = ca.call_id and
		  ca.oper_id  = ad.user_id and
		  b.bet_type <> 'MAN' and
		  a.owner = 'H' and
		  b.bet_id = ?

		union all

		select
		  b.bet_id id,
		  a.cust_id,
		  to_char(b.cr_date,'%d %b %Y %R') cr_date,
		  b.receipt,
		  b.stake,
		  b.settled,
		  (b.winnings + b.refund) as returns,
		  b.num_lines,
		  b.bet_type,
		  b.leg_type,
		  b.bet_id,
		  ad.username as operator,
		  b.source,
		  a.acct_id,
		  a.ccy_code,
		  a.owner
		from
		  tBet b,
		  tAcct a,
		  tCall ca,
		  tAdminUser ad
		where
		  b.acct_id = a.acct_id and
		  b.call_id = ca.call_id and
		  ca.oper_id = ad.user_id and
		  b.bet_type = 'MAN' and
		  a.owner = 'H' and
		  b.bet_id = ?

		order by 10 desc
	}

	ob_db::store_qry OB_CASH_BET::barcode_pools {
		select
			b.pool_bet_id id,
			b.pool_bet_id bet_id,
			b.settled,
			b.receipt,
			-- Account currency
			a.ccy_code,
			b.stake,
			-- Pool currency
			ps.ccy_code as pool_ccy_code,
			b.ccy_stake,
			b.ccy_stake_per_line as ccy_spl,
			to_char(b.cr_date,'%d %b %Y %R') cr_date,
			b.cr_date as cr_date_no_format,
			(b.winnings + b.refund) as returns,
			b.acct_id,
			b.bet_type,
			b.leg_type,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			n.name as pool_name,
			b.source,
			c.cust_id,
			ca.telephone            as line_no,
			ad.username            as operator,
			a.owner,
			e.ev_id,
			e.desc as ev_name,
			to_char(e.start_time,'%d %b %Y %R') as ev_time,
			o.desc as oc_name,
			o.runner_num

		from
			tCustomer c,
			tPoolBet b,
			tAcct a,
			tPbet p,
			tEvoc o,
			tEv e,
			tPoolSource ps,
			tPool n,
			outer (tCall ca, tAdminUser ad)
		where
			a.cust_id = c.cust_id and
			b.acct_id = a.acct_id and
			b.pool_bet_id = p.pool_bet_id and
			p.ev_oc_id = o.ev_oc_id and
			o.ev_id = e.ev_id and
			p.pool_id = n.pool_id and
			n.pool_source_id = ps.pool_source_id and
			b.call_id = ca.call_id and
			ca.oper_id  = ad.user_id and
			a.owner = 'H' and
			b.pool_bet_id = ?
		order by 1 desc
	}

	ob_db::store_qry OB_CASH_BET::barcode_xgame {
		select
			s.xgame_sub_id id,
			to_char(s.cr_date,'%d %b %Y %R') cr_date,
			s.cr_date as cr_date_no_format,
			s.xgame_sub_id as receipt,
			a.ccy_code,
			au.username as operator,
			d.name as game,
			d.desc,
			s.picks,
			s.num_subs,
			s.stake_per_bet,
			s.status,
			s.source,
			s.bet_type,
			g.draw_at,
			dd.desc as draw_desc,
			nvl(sum(b.winnings),0) as winnings,
			round(s.num_subs - count(b.settled)) as num_subs_remaining,
			a.owner
		from
			txgamesub s,
			txgame g,
			txgamedef d,
			txgamedrawdesc dd,
			tacct a,
			outer (txgamebet b),
			outer (tCall c, tAdminUser au)
		where
			s.acct_id = a.acct_id
			and s.xgame_id = g.xgame_id
			and g.draw_desc_id = dd.desc_id
			and g.sort = d.sort
			and s.xgame_sub_id = b.xgame_sub_id
			and s.call_id = c.call_id
			and au.user_id = c.oper_id
			and a.owner = 'H'
			and s.xgame_sub_id = ?
		group by
			s.cr_date,
			s.xgame_sub_id,
			a.ccy_code,
			au.username,
			d.name,
			d.desc,
			g.draw_at,
			s.picks,
			dd.desc,
			s.num_subs,
			s.stake_per_bet,
			s.status,
			s.source,
			s.bet_type,
			a.owner
		order by 2
	}

	ob_db::store_qry OB_CASH_BET::barcode_credit {
		select
		  s.credit_slip_id id,
		  s.credit_slip_id receipt,
		  s.cr_date,
		  s.credit_slip_id,
		  s.amount,
		  s.acct_id,
		  a.owner,
		  a.ccy_code
		from
		  tCreditSlip s,
		  tAcct a
		where
		  s.acct_id = a.acct_id and
		  a.owner = 'H' and
		  s.credit_slip_id = ?
	}

	ob_db::store_qry OB_CASH_BET::ins_pos_slip {
		execute procedure pInsPOSSlip
		(
			p_adminuser = ?,
			p_barcode = ?,
			p_sort = ?,
			p_id = ?,
			p_nif = ?,
			p_fname = ?,
			p_lname = ?
		)
	}

	ob_db::store_qry OB_CASH_BET::upd_pos_slip {
		execute procedure pUpdPOSSlip
		(
			p_adminuser = ?,
			p_pos_slip_id = ?,
			p_nif = ?,
			p_fname = ?,
			p_lname = ?
		)
	}
	ob_db::store_qry OB_CASH_BET::get_session_floats {
		select
			c.session_ccy_id,
			c.ccy_code,
			c.float
		from
			tsessionccy c,
			tsession s
		where
			s.term_code = ?
			and s.end_time is null
			and c.session_id = s.session_id
	}

	if {[OT_CfgGet SETTLE_NIF_NUMBER_REQ 0]} {
		ob_db::store_qry OB_CASH_BET::get_pos_slip_id {
			select
				pos_slip_id,
				nif,
				fname,
				lname
			from
				tPOSSlip
			where
				id   = ?
			and sort = ?
		}
	}
}

#
# Get number of open shop sessions for this location
# returns list: {1 shop_session_id start_time}
#
proc OB_CASH_BET::get_shop_session {loc_code {term_code ""}} {
	ob_log::write INFO "==> OB_CASH_BET::get_shop_session"
	ob_log::write INFO "==  loc_code: $loc_code"
	ob_log::write INFO "==  term_code: $term_code"

	if {$loc_code != "" || $term_code != ""} {
		if [catch {set rs [ob_db::exec_qry OB_CASH_BET::get_shop_session $loc_code $term_code]} msg] {
			ob_log::write ERROR {failed to get_shop_session: $msg}
			return [list 0 $msg]
		}
	} else {
		return [list 0 INVALID_ARGS]
	}
	set nr_rows [db_get_nrows $rs]

	ob_log::write INFO "==  Found $nr_rows shop sessions"

	if {$nr_rows == "1"} {
		set shop_session_id [db_get_col $rs 0 shop_session_id]
		set start_time      [db_get_col $rs 0 start_time]
		ob_db::rs_close $rs
		return [list 1 $shop_session_id $start_time]
	} elseif {$nr_rows == "0"} {
		ob_db::rs_close $rs
		return [list 1 0 ""]
	}

	ob_db::rs_close $rs

	ob_log::write INFO "<== OB_CASH_BET::get_shop_session"

	return [list 0 "found $nr_rows shop sessions"]
}

#
# Open shop session
#
proc OB_CASH_BET::open_shop_session {loc_code} {

	ob_log::write INFO {==> open_shop_session $loc_code}

	if [catch {set rs [ob_db::exec_qry OB_CASH_BET::get_shop_session $loc_code]} msg] {
		ob_log::write ERROR "failed to get_shop_session: $msg"
		return [list 0 $msg]
	}
	if {[db_get_nrows $rs] > 0} {
		return [list 0 "Shop session is already open for this location"]
	}
	ob_db::rs_close $rs

	# start shop session
	if [catch {set rs [ob_db::exec_qry OB_CASH_BET::open_shop_session $loc_code]} msg] {
		ob_log::write ERROR {failed to open_shop_session: $msg}
		return [list 0 $msg]
	}
	set shop_session_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs

	ob_log::write INFO "Shop session started for |$loc_code|"
	ob_log::write INFO {<== open_shop_session $loc_code}
	return [list 1 $shop_session_id]
}

#
# Close current open shop session for location
# We need to be strict and not allow shops to be closed
# with open sessions
#
proc OB_CASH_BET::close_shop_session {loc_code counted eod_user_id} {

	ob_log::write DEBUG {==> close_shop_session $loc_code $counted $eod_user_id}

	# Close shop session
	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::close_shop_session \
			$loc_code $eod_user_id $counted]} msg]} {
		ob_log::write ERROR {failed to close_shop_session: $msg}
		return [list 0 $msg]
	}

	ob_log::write DEBUG {<== close_shop_session [list 1]}
	return [list 1 OK]
}

# Open a session for a terminal
#
proc OB_CASH_BET::open_session {term_code float_list {oper_id ""} \
	{update_shop_session_id 0} {transactional "Y"}} {

	ob_log::write DEBUG {==> open_session $term_code $float_list $oper_id}

	# Make sure there is no session currently open for this terminal
	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::get_open_session $term_code]} msg]} {
		ob_log::write ERROR {failed to get_open_session: $msg}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {

		# If the flag is active all existing sessions for the specified term_code
		# will be closed before opening a new session
		if {[OT_CfgGet CLOSE_EXISTING_SESSIONS 0]} {

			ob_log::write DEBUG {CLOSE_EXISTING_SESSIONS flag active, closing all existing sessions}
			for {set i 0} {$i < $nrows} {incr i} {

				# Get the session_id
				set session_id [db_get_col $rs $i session_id]

				# Close the existing session
				set ret_msg [end_session $session_id]
				if {[lindex $ret_msg 0] == 0} {
					ob_db::rs_close $rs
					return $ret_msg
				}
			}
		} else {
			set msg "There is already a session open for this terminal"
			ob_db::rs_close $rs
			ob_log::write ERROR {$msg}
			return [list 0 $msg]
		}
	}

	ob_db::rs_close $rs

	#
	# Begin our own transaction
	#
	if {$transactional == "Y"} {
		ob_db::begin_tran
	}

	if [catch {set rs [ob_db::exec_qry OB_CASH_BET::open_session $term_code]} msg] {
		ob_log::write ERROR {failed to open_session: $msg}
		if {$transactional == "Y"} {
			catch {ob_db::rollback_tran}
		}
			ob_db::rs_close $rs
			return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		ob_log::write ERROR "open_session:0 rows returned expected 1"
		ob_log::write ERROR "Failed to run open_session with args: $term_code"
		if {$transactional == "Y"} {
			catch {ob_db::rollback_tran}
		}
		ob_db::rs_close $rs
		return [list 0 "Unable to create new session"]
	} else {
		set session_id [db_get_coln $rs 0 0]

		if {$session_id == 0} {
			ob_log::write ERROR "Failed to run open_session with args: $term_code"
			if {$transactional == "Y"} {
				catch {ob_db::rollback_tran}
			}
			ob_db::rs_close $rs
			return [list 0 "Unable to get session id"]
		}

		ob_db::rs_close $rs

		if {$update_shop_session_id || [OT_CfgGet CASH_REPORTING 0]} {
			ob_log::write INFO "Assigning shop session for this terminal session"
			if [catch {set rs [ob_db::exec_qry OB_CASH_BET::assign_shop_session $session_id]} msg] {
				ob_log::write ERROR {failed to assign_shop_session: $msg}
				if {$transactional == "Y"} {
					catch {ob_db::rollback_tran}
				}
				ob_db::rs_close $rs
				return [list 0 $msg]
			}
			ob_log::write INFO "Shop session assigned"
		}

		ob_db::rs_close $rs

		# Insert an entry into tSessionCcy for each float passed in
		foreach {ccy_code float} $float_list {
			set ccy_result [open_session_ccy \
				$session_id $ccy_code $float $oper_id $transactional]
			if {[lindex $ccy_result 0] == 0} {
				return [list 0 [lindex $ccy_result 1]]
			} else {
				lappend session_ccy_list [lindex $ccy_result 1]
			}
		}

		if {$transactional == "Y"} {
			ob_db::commit_tran
		}

		ob_log::write DEBUG {<== open_session [list 1 $session_id]}
		return [list 1 $session_id $session_ccy_list]
	}
}

# open a session currency given the float and session id
#
proc OB_CASH_BET::open_session_ccy {session_id ccy_code float oper_id {transactional "Y"}} {
	ob_log::write ERROR "==> OB_CASH_BET::open_session_ccy"
	ob_log::write ERROR "==  session_id: $session_id"
	ob_log::write ERROR "==  ccy_code: $ccy_code"
	ob_log::write ERROR "==  float: $float"
	ob_log::write ERROR "==  oper_id: $oper_id"
	ob_log::write ERROR "==  transactional: $transactional"

	if [catch {set rs [ob_db::exec_qry OB_CASH_BET::ins_session_ccy $session_id \
		$ccy_code $float]} msg] {

		# Close the session that has been started
		end_session $session_id

		ob_log::write ERROR {failed to ins_session_ccy: $msg}
		if {$transactional == "Y"} {
			catch {ob_db::rollback_tran}
		}
		ob_db::rs_close $rs
		return [list 0 $msg]
	}

	# get the session_ccy_id that has just been inserted
	set session_ccy_id [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	set make_jrnl_entry_res [make_sess_jrnl_entry \
		FLOA $session_ccy_id $float $oper_id]
	if {[lindex $make_jrnl_entry_res 0] == 0} {
		if {$transactional == "Y"} {
			catch {ob_db::rollback_tran}
		}
		return [list 0 "Could not make create journal entry : \
		[lindex $make_jrnl_entry_res 1]"]
	}

	return [list 1 $session_ccy_id]
}

# Close a session for a terminal
#
proc OB_CASH_BET::end_session {session_id} {

	ob_log::write DEBUG {==> end_session $session_id}

	# First check the state of the session
	set session_state_res [check_session_state $session_id]
	if {[lindex $session_state_res 0] == 0} {
		set err [lindex $session_state_res 1]
		ob_log::write ERROR "$err"
		return [list 0 $err]
	}

	if [catch {set rs [ob_db::exec_qry OB_CASH_BET::end_session $session_id]} msg] {
		ob_log::write ERROR {failed to end_session: $msg}
		return [list 0 $msg]
	}

	ob_log::write DEBUG {<== end_session [list 1]}
	ob_db::rs_close $rs
	return [list 1]
}


# Check if there is an open session for a terminal.
#
proc OB_CASH_BET::get_open_session {term_code {ignore_closed 0}} {

	ob_log::write DEBUG {==> OB_CASH_BET::get_open_session}
	ob_log::write DEBUG {==  term_code:$term_code}
	ob_log::write DEBUG {==  ignore_closed:$ignore_closed}

	if {$ignore_closed} {
		if {[catch {set rs [ob_db::exec_qry \
			OB_CASH_BET::get_most_recent_closed_session $term_code "Y"]} msg]} {
			ob_log::write ERROR {failed to get_most_recent_closed_session: $msg}
			return [list 0 $msg]
		}
	} else {
		if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::get_open_session $term_code]} msg]} {
			ob_log::write ERROR {failed to get_open_session: $msg}
			return [list 0 $msg]
		}
	}

	set nrows [db_get_nrows $rs]

	# There should be at most 1 open session per terminal
	if {$nrows > 1} {
		ob_db::rs_close $rs
		return [list 0 "There is more than one open session for terminal\
			$term_code"]
		}

	set RESULTS(ccy_list) [list]

	if {$nrows == 1} {
		set RESULTS(session_id) [db_get_col $rs 0 session_id]
		set RESULTS(start_time) [db_get_col $rs 0 start_time]
		get_session_ccys $RESULTS(session_id) RESULTS
	}

	ob_db::rs_close $rs

	ob_log::write DEBUG {<== get_open_session [list 1 [array get RESULTS]] }
	return [list 1 [array get RESULTS]]
}


#
# Get the currencies and floats defined for the session
proc OB_CASH_BET::get_session_ccys {session_id SESSION} {

	ob_log::write DEBUG {==> get_session_ccys $session_id}

	upvar 1 $SESSION RESULTS

	if {[catch {set ccys_rs [ob_db::exec_qry OB_CASH_BET::get_session_ccys \
		$session_id]} msg]} {
		ob_log::write ERROR {failed to get_session_ccys: $msg}
		return [list 0 $msg]
	}

	set num_rows [db_get_nrows $ccys_rs]

	if {$num_rows == 0} {
		# We have an open session but no entries in tSessionCcy for this
		# session. Close the session.
		end_session $session_id

		unset RESULTS(session_id)
		unset RESULTS(start_time)
	} else {
		for {set i 0} {$i < $num_rows} {incr i} {
			set ccy                           [db_get_col $ccys_rs $i ccy_code]
			set RESULTS($ccy)                 [db_get_col $ccys_rs $i float]
			set RESULTS($ccy,session_ccy_id)  [db_get_col $ccys_rs $i session_ccy_id]
			set RESULTS($ccy,num_bets)        [db_get_col $ccys_rs $i num_bets]
			set RESULTS($ccy,stake_total)     [db_get_col $ccys_rs $i stake_total]
			set RESULTS($ccy,num_paid_out)    [db_get_col $ccys_rs $i num_paid_out]
			set RESULTS($ccy,paid_out_total)  [db_get_col $ccys_rs $i paid_out_total]
			set RESULTS($ccy,num_paid_in)     [db_get_col $ccys_rs $i num_paid_in]
			set RESULTS($ccy,paid_in_total)   [db_get_col $ccys_rs $i paid_in_total]
			set RESULTS($ccy,num_canc_bets)   [db_get_col $ccys_rs $i num_canc_bets]
			set RESULTS($ccy,canc_stake)      [db_get_col $ccys_rs $i canc_stake]
			set RESULTS($ccy,num_void_payout) [db_get_col $ccys_rs $i num_void_payout]
			set RESULTS($ccy,void_payout)     [db_get_col $ccys_rs $i void_payout]
			lappend RESULTS(ccy_list) $ccy
		}
	}
	ob_db::rs_close $ccys_rs
	ob_log::write DEBUG {<==  get_session_ccys}
}

#
# Get the currencies defined for a terminal
proc OB_CASH_BET::get_term_ccys {term_code} {

	ob_log::write DEBUG {==> get_term_ccys $term_code}

	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::get_term_acct_ccys \
		$term_code]} msg]} {
		ob_log::write ERROR {failed to get_term_acct_ccys: $msg}
		return [list 0 $msg]
	}

	set ccy_list [list]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		lappend ccy_list [db_get_col $rs $i ccy_code]
	}
	ob_db::rs_close $rs

	ob_log::write DEBUG {<== get_term_ccys [list 1 $ccy_list]}
	return [list 1 $ccy_list]
}


#
# Make a cash payment into the specified account
proc OB_CASH_BET::do_cash_payment {acct_id amount payment_sort term_code \
	ip_addr source {oper_id ""} {j_op_type ""} {sess_op_type ""} \
	{session_id ""} {ccy_code ""} {transactional 1} {cancel 0} {cpm_id ""}} {

	ob_log::write DEBUG {==> do_cash_payment $acct_id $amount $payment_sort \
		$term_code $ip_addr $source $oper_id $cpm_id}

	#
	# Begin our own transaction
	#
	if {$transactional} {
		ob_db::begin_tran
	}

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::do_cash_payment $acct_id $amount \
		$payment_sort $term_code $ip_addr $source $oper_id $j_op_type $cancel $cpm_id]
	} msg]} {
		ob_log::write ERROR {failed to do_cash_payment: $msg}
		if {$transactional} {
			catch {ob_db::rollback_tran}
		}
		return [list 0 $msg]
	}

	if {$sess_op_type != ""} {
		# Update row in tSessionCcy and make a journal entry

		if {$sess_op_type == "WTD" || \
			$sess_op_type == "TREF" || \
			$sess_op_type == "TPAY"} {
			# Set the amount to negative as the float is being reduced by this
			# amount
			set amount [expr {-1.0 * $amount}]
		}

		set change_ccy_float_res [change_ccy_float $session_id $ccy_code \
			$amount $sess_op_type 0 $oper_id]
		if {[lindex $change_ccy_float_res 0] == 0} {
			if {$transactional} {
				catch {ob_db::rollback_tran}
			}
			ob_db::rs_close $rs
			return [list 0 [lindex $change_ccy_float_res 1]]
		}
	}

	if {$transactional} {
		ob_db::commit_tran
	}

	ob_db::rs_close $rs
	ob_log::write DEBUG {<== do_cash_payment $rs}
	return [list 1 $rs]
}


#
# Update row in tSessionCcy and make a journal entry
# The amount passed in should be negative if it is a withdrawal
#
proc OB_CASH_BET::change_ccy_float {session_id ccy_code amount sess_op_type \
		{start_trans 0} {oper_id ""}} {

	ob_log::write DEBUG {==> change_ccy_float $session_id $ccy_code $amount \
		$sess_op_type $start_trans $oper_id}

	# First check the state of the session
	set session_state_res [check_session_state $session_id]
	if {[lindex $session_state_res 0] == 0} {
		return [list 0 [lindex $session_state_res 1]]
	}

	# Get the currency session id from the passed in session id and ccy code
	set sess_ccy_id_res [get_session_ccy_id $session_id $ccy_code]
	if {[lindex $sess_ccy_id_res 0] == 0} {
		return [list 0 [lindex $sess_ccy_id_res 1]]
	}
	set session_ccy_id [lindex $sess_ccy_id_res 1]

	if {$start_trans == 1} {
		#
		# Begin our own transaction
		#
		ob_db::begin_tran
	}

	# Update the entry in tSessionCcy
	if {[catch {
		set ccy_rs [ob_db::exec_qry OB_CASH_BET::upd_session_ccy_float \
		$session_ccy_id $amount]
	} msg]} {
		ob_log::write ERROR {failed to do upd_session_ccy_float: $msg}

		if {$start_trans == 1} {
			catch {ob_db::rollback_tran}
		}
		return [list 0 $msg]
	}

	ob_db::rs_close $ccy_rs

	set make_jrnl_entry_res [make_sess_jrnl_entry $sess_op_type \
		$session_ccy_id $amount $oper_id]
	if {[lindex $make_jrnl_entry_res 0] == 0} {
		if {$start_trans == 1} {
			catch {ob_db::rollback_tran}
		}

		return [list 0 "Could not make create journal entry : \
			[lindex $make_jrnl_entry_res 1]"]
	}

	if {$start_trans == 1} {
		ob_db::commit_tran
	}

	ob_log::write DEBUG {<== change_ccy_float [list 1]}
	return [list 1]
}


#
# Checks for the existence of a session and if the session is open
#
proc check_session_state {session_id} {

	ob_log::write DEBUG {==> check_session_state $session_id}

	# Make sure that the session is actually open
	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::check_is_session_open \
		$session_id]
	} msg]} {
		ob_log::write ERROR {failed to check_is_session_open: $msg}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		set msg "There is no session with session id $session_id"
		return [list 0 $msg]
	}

	set sess_end_time [db_get_col $rs 0 end_time]
	if {$sess_end_time != ""} {
		set msg "This session (session id = $session_id) is closed"
		ob_db::rs_close $rs
		return [list 0 $msg]
	}

	ob_db::rs_close $rs
	ob_log::write DEBUG {<== check_session_state [list 1]}
	return [list 1]
}


proc OB_CASH_BET::get_session_ccy_id {session_id ccy_code} {
	# Get the currency session id from the passed in session id and ccy code
	if {[catch {
		set ccy_rs [ob_db::exec_qry OB_CASH_BET::get_session_ccy_id \
		$session_id $ccy_code]
	} msg]} {
		ob_log::write ERROR {failed to get_session_ccy_id: $msg}
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $ccy_rs]

	if {$nrows == 0} {
		ob_db::rs_close $ccy_rs
		ob_log::write ERROR "get_session_ccy_id:0 rows returned expected 1"
		ob_log::write ERROR "Failed to run get_session_ccy_id with args: $session_id $ccy_code"
		return [list 0 "Unable to create new session"]
	} else {
		set session_ccy_id [db_get_col $ccy_rs 0 session_ccy_id]
		ob_log::write ERROR "\n session_ccy_id = $session_ccy_id"
		set session_float [db_get_col $ccy_rs 0 float]

		if {$session_id == 0} {
			ob_log::write ERROR "Failed to run get_session_ccy_id with args: $user_id"
			ob_db::rs_close $ccy_rs
			return [list 0 "Unable to get get session_ccy_id"]
		}

		ob_db::rs_close $ccy_rs
	}
	return [list 1 $session_ccy_id $session_float]
}


proc OB_CASH_BET::make_sess_jrnl_entry {sess_op_type sess_ccy_id amount \
		{oper_id ""} {j_op_ref_key ""} {j_op_ref_id ""}} {

	ob_log::write DEBUG {==> make_sess_jrnl_entry $sess_op_type $sess_ccy_id \
		$amount $oper_id $j_op_ref_key $j_op_ref_id}

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::make_sess_jrnl_entry $sess_op_type \
		$sess_ccy_id $amount $oper_id $j_op_ref_key $j_op_ref_id]
	} msg]} {
		ob_log::write ERROR {failed to do make_sess_jrnl_entry: $msg}
		return [list 0 $msg]
	}

	ob_db::rs_close $rs
	ob_log::write DEBUG {<== make_sess_jrnl_entry [list 1]}
	return [list 1]
}

proc OB_CASH_BET::transfer_funds {from_acct_id to_acct_id oper_id amount {txn_type "TFR"} } {

	ob_log::write DEBUG {==> transfer_funds $from_acct_id $to_acct_id $oper_id $amount $txn_type}

	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::transfer_funds \
				$from_acct_id \
				$to_acct_id \
				$oper_id \
				$txn_type \
				$amount]
	} msg]} {
		set msg "failed to do transfer_funds: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	ob_db::rs_close $rs
	ob_log::write DEBUG {<== transfer_funds [list 1 $rs]}
	return [list 1 $rs]
}


proc OB_CASH_BET::get_anon_acct_details {term_code ccy_code {session_id ""}} {

	ob_log::write DEBUG {==> get_anon_acct_details $term_code $ccy_code \
		$session_id}

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::get_anon_acct_details $term_code \
		$ccy_code]
	} msg]} {
		ob_log::write ERROR {failed to do get_anon_acct_details: $msg}
		return [list 0 "Could not retrieve anon details : $msg"]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 2} {
		ob_db::rs_close $rs
		return [list 0 "Could not retrieve anon details"]
	}

	for {set i 0} {$i<$nrows} {incr i} {
		set acct_type [db_get_col $rs $i acct_type]

		if {$acct_type == "PUB"} {
			set DATA(pub_acct_id) [db_get_col $rs $i acct_id]
			set DATA(pub_cust_id) [db_get_col $rs $i cust_id]
			set DATA(pub_balance) [db_get_col $rs $i balance]
			set DATA(pub_acct_no) [db_get_col $rs $i acct_no]
		} else {
			set DATA(priv_acct_id) [db_get_col $rs $i acct_id]
			set DATA(priv_cust_id) [db_get_col $rs $i cust_id]
			set DATA(priv_balance) [db_get_col $rs $i balance]
			set DATA(priv_acct_no) [db_get_col $rs $i acct_no]
		}
	}

	ob_db::rs_close $rs

	# If a session id is passed in, then retrieve the currency float balance
	# and return this also.
	if {$session_id != ""} {
		# Get the currency session float from the passed in session id and ccy code
		set sess_ccy_float_res [get_session_ccy_id $session_id $ccy_code]
		if {[lindex $sess_ccy_float_res 0] == 0} {
			return [list 0 [lindex $sess_ccy_float_res 1]]
		}
		set DATA(float) [lindex $sess_ccy_float_res 2]
	}

	ob_log::write DEBUG {<== get_anon_acct_details [list 1 [array get DATA]]}
	return [list 1 [array get DATA]]
}

# redeems a voucher, requires a voucher id, oper id and a terminal code
# refering to the terminal where the money will be paid out
proc OB_CASH_BET::redeem_voucher {voucher_id oper_id term_code} {

	ob_log::write DEBUG {==> redeem_voucher: $voucher_id $oper_id}

	# read_barcode
	set rs [OB_CASH_BET::read_barcode $voucher_id]

	if {[lindex $rs 0] == 0} {
		set msg "unable to read voucher($voucher_id): [lindex $rs 1]"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}
	set rs      [lindex $rs 2]
	set ref_id  [db_get_col $rs 0 credit_slip_id]
	set acct_id [db_get_col $rs 0 acct_id]

	# get the term_code of the account
	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::get_acct_term_code $acct_id]
	} msg]} {
		set msg "unable to get term_code for acct_id = $acct_id: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}
	set term_code   [db_get_col $rs 0 term_code]
	ob_db::rs_close $rs

	# redeem the voucher
	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::receipt_payout \
		        "CSLP" \
		        $ref_id \
		        $term_code \
		        $oper_id \
		        "Y"]
	} msg]} {
		set msg "unable to redeem voucher: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	set amount [db_get_coln $rs 0 0]
	set ipAddr      [reqGetEnv REMOTE_ADDR]
	set j_op_type   "VRED"

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::get_ccy_code $acct_id]
	} msg]} {
		set msg "unable to get ccy_code: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	set ccy_code [db_get_col $rs 0 ccy_code]

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::get_pub_acct_id $term_code $ccy_code]
	} msg]} {
		set msg "unable to get pub acct_id: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	set pub_acct_id [db_get_col $rs 0 acct_id]
	ob_db::rs_close $rs

	# do the cash payment
	if {[catch {
		set result [OB_CASH_BET::do_cash_payment \
			"$pub_acct_id" \
			"$amount" \
			"W" \
			"$term_code" \
			"$ipAddr" \
			"P" \
			"$oper_id" \
			"$j_op_type"\
			0]
	} msg]} {
		# catch the errors
		set result [list 0 $msg]
	}

	# error handling for cash payment
	if {[lindex $result 0] == 0 } {
		set msg "unable to redeem voucher (NOTE: the money have been\
			transferred to the public account): [lindex $result 1]"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	# return a response
	ob_log::write DEBUG {<== redeem_voucher: $amount}
	return [list 1 "Voucher redemption successful for amount: ${amount}${ccy_code}"]
}

# This proc is a wrapper for cancelling anonymous bets.
# As well as cancelling the bet, it handles moving the funds
# to and from the private accounts, as well as the session float.
#
# Returns the amount that should be given back to the customer.
proc OB_CASH_BET::anon_cancel {
	user_id
	bet_id
	reason
	term_code
	{update_float 0}
	{source P}
	{auto_wtd 1}
	{transactional Y}
	{call_id ""}
} {
	ob_log::write DEBUG {==> OB_CASH_BET::anon_cancel:\
		$user_id $bet_id $reason $term_code}

	# Get operator's username
	if {[catch {
		set res [ob_db::exec_qry OB_CASH_BET::get_admin_user $user_id]
	} msg]} {
		set msg "unable to cancel bet: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	if {[db_get_nrows $res] == 0} {
		ob_db::rs_close $res
		return [list 0 "unable to cancel bet: no user details"]
	}

	set username    [db_get_col $res 0 username]
	ob_db::rs_close $res

	# Get bet details
	if {[catch {
		set res [ob_db::exec_qry OB_CASH_BET::get_bet_details $bet_id]
	} msg]} {
		set msg "unable to cancel bet: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	if {[db_get_nrows $res] == 0} {
		ob_db::rs_close $res
		return [list 0 "unable to cancel bet: no bet details"]
	}

	set bet_type     [db_get_col $res 0 bet_type]
	set token_value  [db_get_col $res 0 token_value]
	set num_lines    [db_get_col $res 0 num_lines]
	set stake        [db_get_col $res 0 stake]
	set from_acct_id [db_get_col $res 0 acct_id]
	set ccy_code     [db_get_col $res 0 ccy_code]
	ob_db::rs_close $res

	# Get the acct_id of the public account of the terminal that is cancelling
	# the bet. Make sure we use the account for the currency that the bet was
	# placed in
	if {[catch {
		set res [ob_db::exec_qry OB_CASH_BET::get_pub_acct_id $term_code $ccy_code]
	} msg]} {
		set msg "unable to cancel bet: $msg"
		ob_log::write ERROR {$msg}
		return [list 0 $msg]
	}

	if {[db_get_nrows $res] == 0} {
		ob_db::rs_close $res
		return [list 0 "unable to cancel bet: no terminal details"]
	}

	set to_acct_id    [db_get_col $res 0 acct_id]
	ob_db::rs_close $res

	# Do everything in a transaction
	if {$transactional == "Y"} {
		ob_db::begin_tran
	}

	# Void the bet
	set res [SETTLE::do_settle_bet \
		$username \
		$reason \
		CancelBet \
		$token_value \
		$bet_id \
		0 \
		0 \
		$num_lines \
		0 \
		0 \
		$stake \
		$bet_type \
		N]

	if {[lindex $res 0] == 0} {
		# Failed to cancel the bet
		if {$transactional == "Y"} {
			ob_db::rollback_tran
		}
		return $res
	}

	# Cancelling the bet refunded the money to the private account of the
	# terminal that placed the bet. Move the funds to the public account
	# of the terminal that's cancelling the bet.
	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::anon_collect \
			ESB \
			$bet_id \
			$term_code \
			$user_id \
			"" \
			$call_id \
			N]
	} msg]} {
		set msg "unable to collect: $msg"
		ob_log::write ERROR {$msg}
		if {$transactional == "Y"} {
			ob_db::rollback_tran
		}
		return [list 0 $msg]
	}

	if {$auto_wtd} {
		if {$update_float} {
			# Get the open session details for the terminal
			if {[catch {
				set res [ob_db::exec_qry OB_CASH_BET::get_open_session $term_code]
			} msg]} {
				set msg "unable to get session details: $msg"
				ob_log::write ERROR {$msg}
				return [list 0 $msg]
			}

			if {[db_get_nrows $res] != 1} {
				set msg "no open session found for $term_code"
				ob_log::write ERROR {$msg}
				ob_db::rs_close $res
				return [list 0 $msg]
			}

			set sess_op_type TREF
			set session_id   [db_get_col $res 0 session_id]
			ob_db::rs_close $res
		} else {
			set sess_op_type ""
			set session_id   ""
		}

		# Withdraw the funds from the public account of the terminal that's
		# cancelling the bet.
		# Note we are passing cancel = 1, this will force the payment through, even
		# if it does not pass the minimum requirements
		set res [OB_CASH_BET::do_cash_payment \
			$to_acct_id \
			$stake \
			W \
			$term_code \
			[reqGetEnv REMOTE_ADDR] \
			$source \
			$user_id \
			TREF \
			$sess_op_type \
			$session_id \
			$ccy_code \
			0\
			1]

		if {[lindex $res 0] == 0} {
			# Failed to transfer the funds
			if {$transactional == "Y"} {
				ob_db::rollback_tran
			}
			return $res
		}
	}

	if {$transactional == "Y"} {
		ob_db::commit_tran
	}

	return [list 1 $stake $ccy_code]
}

# Anon Payout
# the id is the bet or credit slip id
# the type can be ESB, CSLP, etc. It is a reference to ref_key in tBet
# term code current term code - used for payout limits and TermActivity
# ccy_code used to retrieve the PUB acct_id for the payout account
# 
# in_trans - are we already in a transaction or not? If we are not (0), 
#            then the proc will start one for you.
# transactional - whether to tell the sp to start a transaction or not.
proc OB_CASH_BET::anon_payout {
	id
	type
	oper_id
	term_code
	ccy_code
	{update_float 0}
	{source P}
	{auto_wtd 1}
	{nif ""}
	{call_id ""}
	{in_trans 0}
	{transactional "Y"}
} {

	ob_log::write DEBUG {==> anon_payout:\
		$id $type $oper_id $term_code $ccy_code $update_float \
	    $source $auto_wtd $nif $call_id $in_trans $transactional}

	# Do everything in a transaction
	if {!$in_trans} {
		ob_db::begin_tran
		set transactional "N"
	}

	# payout
	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::receipt_payout \
			$type \
			$id \
			$term_code \
			$oper_id \
			$transactional]
	} msg]} {
		set msg "unable to do payout: $msg"
		ob_log::write ERROR {$msg}
		if {!$in_trans} {
			ob_db::rollback_tran
		}
		return [list 0 $msg]
	}

	set amount     [db_get_coln $rs 0 0]
	set ipAddr     [reqGetEnv REMOTE_ADDR]
	set j_op_type  "SPAY"
	ob_db::rs_close $rs

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::get_pub_acct_id $term_code $ccy_code]
	} msg]} {
		set msg "unable to get pub acct_id: $msg"
		ob_log::write ERROR {$msg}
		if {!$in_trans} {
			ob_db::rollback_tran
		}
		return [list 0 $msg]
	}

	set pub_acct_id [db_get_col $rs 0 acct_id]
	ob_db::rs_close $rs

	if {$auto_wtd} {
		if {$update_float} {
			if {[catch {
				set rs [ob_db::exec_qry OB_CASH_BET::get_open_session $term_code]
			} msg]} {
				set msg "unable to get open session for $term_code: $msg"
				ob_log::write ERROR {$msg}
				if {!$in_trans} {
					ob_db::rollback_tran
				}
				return [list 0 $msg]
			}

			if {[db_get_nrows $rs] != 1} {
				set msg "no open session found for $term_code"
				ob_log::write ERROR {$msg}
				if {!$in_trans} {
					ob_db::rollback_tran
				}
				return [list 0 $msg]
			}

			set sess_op_type TPAY
			set session_id   [db_get_col $rs 0 session_id]
			ob_db::rs_close $rs
		} else {
			set sess_op_type ""
			set session_id   ""
		}

		# do the cash payment
		if {[catch {
			set result [OB_CASH_BET::do_cash_payment \
				"$pub_acct_id" \
				"$amount" \
				"W" \
				"$term_code" \
				"$ipAddr" \
				"$source" \
				"$oper_id" \
				"$j_op_type" \
				$sess_op_type \
				$session_id \
				$ccy_code \
				[expr !$in_trans] \
				0]
		} msg]} {
			# catch the errors
			set result [list 0 $msg]
		}

		# error handling for cash payment
		if {[lindex $result 0] == 0 } {
			set msg "unable to do payment (NOTE: the money has been\
				transferred to the public account): [lindex $result 1]"
			ob_log::write ERROR {$msg}
			if {!$in_trans} {
				ob_db::rollback_tran
			}
			return [list 0 $msg]
		}
	}

	# return a response
	if {!$in_trans} {
		ob_db::commit_tran
	}
	ob_log::write DEBUG {<== anon_payout: $amount}
	return [list 1 $amount]
}


#
# builds up a 16 digit barcode that can be mapped
# back to original bet
# First digit tells what type of receipt this is:
# 0: Sports Bet
# 1: Pools Bet
# 2: Xgame Bet
# 3: Credit Slip
# 4: FOG Credit Slip (slip coming from FOBT's)
#
# Next 2 digits tell how many digits the bet id is
# and then that many next digits is the bet id for
# whatever type of bet it is.
#
proc OB_CASH_BET::get_barcode {sort id receipt ccy_code {admin_user ""}} {
	set bar_code ""

	# indentify transaction type
	switch -- $sort {
		"BET" {
			set bar_code 0
		}
		"POOLS" {
			set bar_code 1
		}
		"XGAME" {
			set bar_code 2
		}
		"CREDIT" {
			set bar_code 3
		}
		"FOG_CREDIT" {
			set bar_code 4
		}
		default {
			error "barcode: unknown transaction type"
		}
	}

	# length of the id
	append bar_code [format %02d [string length $id]]

	# the id
	append bar_code $id

	# there is a chance that customers will be able to type in
	# their bet details and check them over the internet
	# in order to stop people generating their own bar codes and
	# trying to claim winnings before the actual customer, we are
	# going to hash a server end component into the string
	# We're not going to blowfish encrypt the string so as to reduce
	# the length and make it possible to type in if there is a problem
	# with the barcode reader.

	set enc [md5 "[OT_CfgGet BARCODE_KEY]${receipt}${id}"]

	# has to be numeric barcode
	regsub -all {[^0-9]} $enc {} enc
	append bar_code $enc

	# make it 16 characters long
	if {[string length $bar_code] > 16} {
		set bar_code [string range $bar_code 0 15]
	} else {
		set bar_code [format %-016s $bar_code]
	}


	# Insert the pos slip if it doesn't exist already
	# In case of winning over NIF_WINNINGS_AMT_LIMIT,
	# during the pay out process, the customer will be asked the
	# NIF, name, surname and the pos slip will be updated
	if {[OT_CfgGet SETTLE_NIF_NUMBER_REQ 0] && $admin_user != ""} {
		if {$ccy_code == "EUR"} {
			set pos_slip_res [OB_CASH_BET::get_pos_slip_id $id $sort]
			if {[lindex $pos_slip_res 0] == -1} {
				return
			} elseif {[lindex $pos_slip_res 0] == 0} {
				# create a pos slip entry in tPOSSlip
				set result [OB_CASH_BET::create_POS_slip $admin_user $bar_code $sort $id]
				if {[lindex $result 0] == 0} {
					ob_log::write ERROR "Failed to insert pos slip: [lindex $result 1]"
					return
				}
			}
		}
	}
	return $bar_code
}


#
# Returns the sort from the barcode and
# a query to execute in read_barcode
#
proc OB_CASH_BET::get_sort_from_barcode {barcode} {

	switch -- [string index $barcode 0] {
		0 {
			return [list 1 "BET" "OB_CASH_BET::barcode_bet"]
		}
		1 {
			return [list 1 "POOLS" "OB_CASH_BET::barcode_pools"]
		}
		2 {
			return [list 1 "XGAME" "OB_CASH_BET::barcode_xgame"]
		}
		3 {
			return [list 1 "CREDIT" "OB_CASH_BET::barcode_credit"]
		}
		4 {
			return [list 0 "REGISTER" ""]
		}
		5 {
			return [list 1 "FOG_CREDIT" "OB_CASH_BET::barcode_credit"]
		}
		default {
			ob_log::write ERROR "barcode: unknown transaction type"
			return [list 0 "" ""]
		}
	}
}

proc OB_CASH_BET::get_pos_slip_id {bet_id sort} {

	if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::get_pos_slip_id $bet_id $sort]} msg]} {
		ob_log::write ERROR "Failed to get pos_slip_id: $msg"
		return [list -1 "Failed to get pos_slip_id: $msg"]
	}
	if {[db_get_nrows $rs] == 1} {
		set pos_slip_id [db_get_col $rs 0 pos_slip_id]
		set nif         [db_get_col $rs 0 nif]
		set fname       [db_get_col $rs 0 fname]
		set lname       [db_get_col $rs 0 lname]

		ob_db::rs_close $rs
		return [list 1 $pos_slip_id $nif $fname $lname]
	}

	ob_db::rs_close $rs
	# pos slip not found
	return [list 0]
}

#
# Reads the barcode by stripping out bet_id
# by following above procedure in reverse.
# Then as a check, recreate barcode to ensure
# that it matches.
#
proc OB_CASH_BET::read_barcode {barcode} {

	set sort_res [OB_CASH_BET::get_sort_from_barcode $barcode]

	if {[lindex $sort_res 0] == 1} {
		set sort [lindex $sort_res 1]
		set qry  [lindex $sort_res 2]
	} else {
		return $sort_res
	}

	## pull out the first 16 digits..
	##
	set barcode [string range $barcode 0 15]

	#get the id
	set id_length [string trimleft [string range $barcode 1 2] "0"]

	if {$id_length == ""} {
		## haven't found anything
		##
		return [list 0 "" ""]
	}

	set id [string range $barcode 3 [expr {($id_length - 1) + 3}]]

	#get the details of the transaction
	if {[catch {
		set rs [ob_db::exec_qry $qry $id $id]
	} msg]} {
		ob_log::write ERROR "ERROR:getting receipt info: $msg"
		return [list 0 "" ""]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
		set receipt  [db_get_col $rs 0 receipt]
		set ccy_code [db_get_col $rs 0 ccy_code]

		#check the encryption
		if {$barcode == [get_barcode $sort $id $receipt $ccy_code]} {
			set status 1
		} else {
			set status 0
		}
	} else {
		set status 0
		set sort ""
	}
	ob_db::rs_close $rs
	return [list $status $sort $rs]
}

#
# This proc tranfers cash from the float of one session curency to the float
# of a different session. The currencies must be the same.
#
proc OB_CASH_BET::transfer_float {to_session_ccy_id from_session_ccy_id amount \
		{transactional Y} {oper_id ""} {term_code ""} {transfer_type_id ""}} {

	ob_log::write DEBUG {==> transfer_float $to_session_ccy_id \
		$from_session_ccy_id $amount $oper_id $term_code $transfer_type_id}

	set args [list $to_session_ccy_id $from_session_ccy_id \
			$amount $transactional $oper_id $term_code]

	if {[OT_CfgGet ENABLE_TRANSFER_TYPES 0]} {
		lappend args $transfer_type_id
	}

	if [catch {
		set rs [eval ob_db::exec_qry OB_CASH_BET::transfer_float [subst $args]]
	} msg] {
		ob_log::write ERROR {failed to do transfer_float: $msg}
		return [list 0 $msg]
	}

	set float_transfer_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs
	ob_log::write DEBUG {<== transfer_float [list 1 $float_transfer_id]}
	return [list 1 $float_transfer_id]
}

#
# This proc tranfers cash from the last closed session to the open
# session for a given terminal
#
proc OB_CASH_BET::transfer_session_float {term_code oper_id {transactional Y}} {

	ob_log::write INFO "==> OB_CASH_BET::transfer_session_float"
	ob_log::write INFO "==  oper_id:$oper_id"
	ob_log::write INFO "==  term_code:$term_code"
	ob_log::write INFO "==  transactional:$transactional"

	# Get the FROM session
	set res [OB_CASH_BET::get_open_session $term_code 1]
	if {![lindex $res 0]} {
		return [list 0 [lindex $res 1]]
	}
	ob_log::write INFO "== Found FROM session: [lindex $res 1]"
	array set FROM [lindex $res 1]

	if {$FROM(ccy_list) == ""} {
		ob_log::write INFO "==  No from session"
		return [list 1 0]
	}

	# Get the TO session
	set res [OB_CASH_BET::get_open_session $term_code]
	if {![lindex $res 0]} {
		return [list 0 [lindex $res 1]]
	}
	ob_log::write INFO "== Found TO session: [lindex $res 1]"
	array set TO [lindex $res 1]

	if {$FROM(ccy_list) == "" || $TO(ccy_list) == ""} {
		ob_log::write WARNING "== Failed to locate TO and FROM sessions"
		return [list 0 NO_TO_FROM]
	}

	set transferred 0

	foreach ccy_code $FROM(ccy_list) {
		set amount $FROM($ccy_code)
		if {$amount > 0} {
			ob_log::write INFO "== Transferring: $amount"

			if {[catch {set rs [ob_db::exec_qry OB_CASH_BET::transfer_session_float \
					$TO($ccy_code,session_ccy_id) $FROM($ccy_code,session_ccy_id) \
					$amount "N" $oper_id $term_code]} msg]} {
				ob_log::write WARNING "== failed to do transfer_session_float: $msg"
				return [list 0 $msg]
			}
			set transferred 1
			ob_db::rs_close $rs
		}
	}

	ob_log::write INFO "==  transferred:$transferred"
	ob_log::write INFO "<== OB_CASH_BET::transfer_session_float"

	ob_db::rs_close $rs
	return [list 1 $transferred]
}

#
# This proc moves the given amount from the public to private account of the
# given terminal and then creates a credit slip for that amount
#
proc OB_CASH_BET::create_credit_slip {term_code amount ccy_code call_id} {

	ob_log::write DEBUG {==> create_credit_slip $term_code $amount $ccy_code\
		$call_id}

	#
	# Begin our own transaction
	#
	ob_db::begin_tran

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::create_credit_slip \
			$term_code $amount $ccy_code $call_id]
		set slip_id [db_get_coln $rs 0 0]
		#
		# Create a barcode from the slip_id
		#
		set barcode [get_barcode CREDIT $slip_id $slip_id $ccy_code]
	} msg]} {
		ob_log::write ERROR {failed to do create_credit_slip: $msg}
		catch {ob_db::rollback_tran}
		return [list 0 $msg]
	}

	ob_db::commit_tran

	ob_log::write DEBUG {<== create_credit_slip [list 1 $barcode]}
	return [list 1 $barcode]
}

#
# This proc creates a POS slip with the given barcode and bet id
# The nif (Spanish fiscal number) first name and last name may be blank
#
proc OB_CASH_BET::create_POS_slip {admin_user barcode sort id {nif ""} {fname ""} {lname ""}} {

	ob_log::write DEBUG {==> create_POS_slip $admin_user $barcode\
		$sort $id $nif $fname $lname}

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::ins_pos_slip \
			$admin_user $barcode $sort $id $nif $fname $lname]
		set pos_slip_id [db_get_coln $rs 0 0]
	} msg]} {
		ob_log::write ERROR {failed to do create_POS_slip: $msg}
		return [list 0 $msg]
	}

	return [list 1 $pos_slip_id]
}

#
# This proc updates a POS slip with the given nif, fname and lname
#
proc OB_CASH_BET::update_POS_slip {admin_user pos_slip_id nif fname lname} {


	ob_log::write DEBUG {==> update_POS_slip $admin_user $pos_slip_id\
		$nif $fname $lname}

	if {[catch {
		set rs [ob_db::exec_qry OB_CASH_BET::upd_pos_slip \
			$admin_user $pos_slip_id $nif $fname $lname]
	} msg]} {
		ob_log::write ERROR {failed to do create_credit_slip: $msg}
		return [list 0 $msg]
	}

	return [list 1]
}
