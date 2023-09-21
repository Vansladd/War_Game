# $Id: acct_qry.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# =======================================================================
#
# Copyright (c) Orbis Technology 2000. All rights reserved.
#
#
# A generic set of account functions, this will hopefully
# provide all the account functionality required in a
# typical set of customer screens.
#
# The payment code is no longer in here. Check out payment.tcl
# =======================================================================


# What the new error codes should effectively translate to in txlateval (English)
#
#	ACCT_NO_ACCT_DATA   {Unable to retrieve your account details at this time, please try again later.}
#	ACCT_NO_TRNS_DATA   {Unable to retrieve your transaction details at this time, please try again later.}
#	LOGIN_NO_LOGIN      {Failed to retreive customer acct_id}
#	ACCT_NO_SUB_DATA    {Unable to retrieve your subscription details at this time, please try again later.}
#	ACCT_NO_BET_DETS    {Unable to retrieve the details for your bet at this time, please try again later.}
#	ACCT_PWD_NO_MATCH   {Passwords do not match}
#	ACCT_PWD_EQ_UNAME   {Password cannot be the same as your username}
#	ACCT_FAIL_AUTH      {Failed to authenticate user}
#	ACCT_PWD_WRONG       {Password Incorrect}
#	ACCT_PWD_CHNGD_FAIL {Failed to update password}
#	ACCT_NO_FUND_XFER   {Funds transfer is currently unavailable for your account.}
#	ACCT_PWD_PIN_BLNK   {Enter Password/Pin}
#	PMT_AMNT            {Invalid amount}
#	ACCT_PIN_NO_MATCH   {PINs do not match}
#	ACCT_PIN_ENTER      {Please enter a PIN}
#	ACCT_PIN_ONLY_NUMS  {The PIN should contain only numbers}
#	ACCT_PIN_INVLD_PIN  {You are not allowed that PIN}
#	ACCT_DOB_ENTER      {Please enter your date of birth dd/mm/yyyy}
#	ACCT_DOB_INVLD      {Your date of birth is invalid or indicates that you are under 18}
#	ACCT_PIN_CONF_OLD   {Please confirm your old PIN}
#	CUST_ACCT_CONF_PWD  {Please confirm your password}
#	ACCT_PIN_UPD_FAIL   {Failed to update PIN}
#
#  Other translations required in txlateval
#
#	CUST_ACCT_UNSTL_BETS  {Unsettled Bets}
#	CUST_ACCT_SPORTS_BETS {Sports Bets}
#	CUST_ACCT_XG_BETS     {External Game Bets}
#	CUST_ACCT_BOUGHT      {Bought}
#	CUST_ACCT_SOLD        {Sold}
#	CUST_XG_SUB           {Subscription}
#	CUST_XG_BET           {Bet}
#	ACCT_PWD_CHNGD_OK     {Password successfully changed}
#	ACCT_L_ACCT_DEP       {Account Deposit}
#	ACCT_L_ACCT_WTH       {Account Withdrawal}
#	ACCT_PERS_DETS_UPD_OK {Details successfully updated}

namespace eval OB_accounts {

namespace export init_acct

# goto the filter page
namespace export go_acct_qry

# show acct history bet or txn
namespace export go_acct_hist
namespace export go_bet_hist_for_sub

# show the bet receipt
namespace export go_acct_rcpt

# show the bet receipt for xgame
namespace export go_acct_xgame_rcpt

# goto the dep/wtd pages
namespace export go_acct_txn

# do a dep/wtd
namespace export do_acct_txn

# go & update passwd
namespace export go_acct_pwd
namespace export upd_acct_pwd

# go & update dep limits
namespace export go_dep_limits
namespace export upd_dep_limits


# go and update acct_detail
namespace export go_acct_detail
namespace export upd_acct_detail

# go and update acct_pin
namespace export go_acct_pin
namespace export upd_acct_pin

# go to FreeBets pages
namespace export go_acct_freebets

# FOG game details
namespace export go_igf_game_details

# for bet receipts
namespace export play_template

variable JRNL_OP
variable BOOKIE_CUST_ID
variable BOOKIE_CASH_ACCT_ID
variable BADPINS
set BADPINS ""

set JRNL_OP(loaded)      0

variable ACCT_TEMPLATE

namespace export set_acct_template

array set ACCT_TEMPLATE [list\
	Query      			acct_qry.html\
	TxnHist    			acct_txn_hist.html\
	BetHist    			acct_bet_hist.html\
	BallsHist           acct_balls_hist.html\
	IGFReceipt          igf_game_details.html\
	BetReceipt 			acct_bet_receipt.html\
	PoolsBetReceipt 	acct_pool_bet_receipt.html\
	ManBetReceipt		acct_man_bet_receipt.html\
	XGameBetHist   		acct_xgame_bet_hist.html\
	XGameBetReceipt		acct_xgame_bet_receipt.html\
	XGameSubReceipt		acct_xgame_sub_receipt.html\
	Password   			acct_pwd.html\
	DepositLimits   	acct_dep_limits.html\
	Result     			acct_result.html\
	Txn       	 		acct_txn.html\
	PersInfo   			acct_detail.html\
	PIN  	      		acct_pin.html\
	FreeBetOffers		acct_freebets.html\
	Guest	      		acct_guest.html\
	Error	      		acct_error.html\
	Cust_Popup_Receipt  bet_receipt_popup.html]


#
# ======================================================================
# one time account initialisation
# ======================================================================
#
proc init_acct args {

	variable BOOKIE_CUST_ID
	variable BOOKIE_CASH_ACCT_ID
	variable HTML_CHARS_PREF

	# Prepare the account queries
	prep_acct_qrys

	# load the journal op types
	load_jrnl_refs

	# load the bet map from placebet2.tcl
	get_bet_map

	get_bad_pins

	# Use the config file to set HTML chars on or off for currency
	# printing (notably the &pound; symbol on DTV)
	set HTML_CHARS_PREF [OT_CfgGet HTML_CHARS 1]

	return
}

#
# ----------------------------------------------------------------------
# Override default templates to play
# ----------------------------------------------------------------------
#
proc set_acct_template args {

	variable ACCT_TEMPLATE

	if {[llength $args] == 1} {
		return $ACCT_TEMPLATE([lindex $args 0])
	} elseif {[llength $args] == 2} {
		set ACCT_TEMPLATE([lindex $args 0]) [lindex $args 1]
	}
}


#
# ----------------------------------------------------------------------
# procedures to produce "Error" and "Guest" templates
# ----------------------------------------------------------------------
#
proc play_template {which} {

	variable ACCT_TEMPLATE

	tpSetVar AcctPlayFile $which
	play_file $ACCT_TEMPLATE($which)
}


#
# ----------------------------------------------------------------------
# prepare all the queries used within the accounts
# ----------------------------------------------------------------------
#

proc prep_acct_qrys {} {

	# query for checking username and password
	db_store_qry user_auth {
		SELECT
		cust_id

		FROM
		tcustomer

		WHERE
		username = ? AND
		password = ?
	}

	# query to run pupdcustpasswd
	db_store_qry upd_pwd {
		EXECUTE PROCEDURE pUpdCustPasswd (
						  p_username = ?,
						  p_old_pwd  = ?,
						  p_new_pwd  = ?
						  )
	}

	# same as above, but flags the password as temporary.
	db_store_qry reset_pwd {
		EXECUTE PROCEDURE pUpdCustPasswd (
						  p_username = ?,
						  p_old_pwd  = ?,
						  p_new_pwd  = ?,
						  p_temp_pwd = 'Y'
						  )
	}

	# query to get a customer's acct_id given the cust_id
	db_store_qry acct_id {
		SELECT
		acct_id

		FROM
		tacct

		WHERE
		cust_id = ?    AND
		owner   = 'C'
	}


	# query to get the balance of a customer's account
	db_store_qry get_acct_balance {
		SELECT
		balance,
		balance_nowtd

		FROM
		tAcct

		WHERE
		cust_id = ?
	}


	# The customer's balance at a moment in time
	#! this is a very expensive query to run - let's not run it if we don't have to
	db_store_qry get_historic_balance {
		SELECT
		nvl(sum(amount),0) as balance

		FROM
		tJrnl
		WHERE
		cr_date <= ?  AND
		acct_id = (select acct_id from tacct where cust_id=?)
	}



	# journal operations

	db_store_qry jrnl_ops {
		SELECT
		j_op_type,
		j_op_name

		FROM
		tjrnlop
	}


	# get the type of a bet, given the bet_id

		db_store_qry get_bet_type {
			SELECT
			bet_type

			FROM
			tbet

			WHERE
			bet_id = ?
	}


	# transactions on an account
	# in a given period

	db_store_qry acct_txns {
		SELECT
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance,
		DECODE(j.j_op_ref_key, 'IGF', tCgGame.name, null) as igf_name

		FROM
		tJrnl j,
		outer (tCgGameSummary, tCgGame)

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?) and
		tCgGameSummary.cg_game_id = j.j_op_ref_id and
		tCgGameSummary.cg_id = tCgGame.cg_id


		order by
		j.cr_date desc,
		j.jrnl_id
	}

	# last 3 transactions

	set select ""
	set from ""
	set where ""

	if {[OT_CfgGet FUNC_INC_IGF_LAST_3_TXNS 0]} {
		set select "$select , DECODE(j.j_op_ref_key, 'IGF', tCgGame.name, null) as igf_name"
		set from "$from , outer (tCgGameSummary, tCgGame)"
		set where "$where and tCgGameSummary.cg_game_id = j.j_op_ref_id and tCgGameSummary.cg_id = tCgGame.cg_id"

	}

	db_store_qry last_3_acct_txns [subst {
		SELECT
		first 3
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance
		$select

		FROM
		tJrnl j
		$from

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?)
		$where
		order by
		j.cr_date desc,
		j.jrnl_id
	}]

	# Get all casino bets

	db_store_qry casino_bets {
		SELECT
		cg_game_id,
		started,
		stakes,
		winnings,
		state,
		name

		FROM
		tcggamesummary,
		tcggame

		WHERE
		tcggamesummary.cg_id = tcggame.cg_id and
		started between ? and ? and
		cg_acct_id = (select cg_acct_id
				 from tcgacct
				 where acct_id = ?)

		ORDER BY
		started desc


	}

	# Get all balls bets

	db_store_qry new_balls_bets {
		SELECT
		total_stake,
		stake_per_game,
		refund,
		status,
		started,
		finished,
		winnings

		FROM
		tUGGameSummary

		WHERE
		started between ? and ? and
		acct_id = ?

		ORDER BY
		started desc


	}


	# Get all casino and balls (SNG) bets together

	db_store_qry casino_balls_bets {

		SELECT
		cg_game_id game_id,
		started,
		stakes,
		winnings,
		state,
		name,
		"C" game

		FROM
		tcggamesummary,
		tcggame

		WHERE
		tcggamesummary.cg_id = tcggame.cg_id and
		started between ? and ? and
		cg_acct_id = (select cg_acct_id
				 from tcgacct
				 where acct_id = ?) and
		name not like "Free%"


		UNION ALL


		SELECT
		ug_summary_id game_id,
		started,
		total_stake stakes,
		winnings,
		status state,
		ug_type_code name,
		"B" game

		FROM
		tUGGameSummary

		WHERE
		started between ? and ? and
		acct_id = ?

		ORDER BY
		2 desc;


	}


	# deposits and withdrawals on an account
	# in a given period

	db_store_qry acct_deps_wtds {
		SELECT
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance

		FROM
		tJrnl j

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?) and
		j.j_op_type in ("DEP","WTD","COMM","RCOM")
		order by
		j.cr_date desc,
		j.jrnl_id
	}

	# deposits on an account
	# in a given period

	db_store_qry acct_deps {
		SELECT
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance

		FROM
		tJrnl j

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?) and
		j.j_op_type = "DEP"
		order by
		j.cr_date desc,
		j.jrnl_id
	}

	# withdraws on an account
	# in a given period
	db_store_qry acct_wtds {
		SELECT
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance

		FROM
		tJrnl j

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?) and
		j.j_op_type = "WTD"
		order by
		j.cr_date desc,
		j.jrnl_id
	}

	# microgaming(mcs) casino / poker transactions
	# on an account in a given period (ladbrokes specific)

	db_store_qry acct_mcs_txns {
		SELECT
		j.cr_date,
		j.jrnl_id,
		j.line_id,
		j.desc,
		j.j_op_ref_key,
		j.j_op_ref_id,
		j.acct_id,
		j.amount,
		j.j_op_type,
		j.user_id,
		j.balance

		FROM
		tJrnl j,
		tManAdj a

		WHERE
		j.cr_date between ? and ? and
		j.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?) and
		j.j_op_ref_key = 'MADJ' and
		j.j_op_ref_id = a.madj_id and
		a.type in ('MCSC','MCSP')
		order by
		j.cr_date desc,
		j.jrnl_id
	}

	# bets in a given period
	# (including spread bets if you ask for them)

	set extra_select_1 ""
	set extra_table_1 ""
	set extra_where_1 ""
	set extra_select_2 ""

	# Add blockbuster bets to acct transactions
	if {[OT_CfgGetTrue HAS_BLOCKBUSTER]} {
		set extra_select_1 ", NVL(bb.bonus_percentage,-1) bonus"
		set extra_table_1 ", outer tBetBlockBuster bb"
		set extra_where_1 "and b.bet_id = bb.bet_id"
		set extra_select_2 ", -1"
	}

	db_store_qry acct_bets [subst {
		select
			  decode(b.bet_type, 'MAN', 'MAN_BET', 'BET') type,
			  b.bet_id,
			  b.cr_date         bet_date,
			  b.receipt         bet_receipt,
			  b.acct_id         bet_acct_id,
			  b.settled         bet_settled,
			  b.stake           bet_stake,
			  b.stake_per_line  bet_stake_per_line,
			  b.winnings        bet_winnings,
			  b.refund          bet_refund,
			  b.bet_type,
			  b.num_lines,
			  b.leg_type,
			  e.desc            ev_name,
			  e.result_conf     ev_result_conf,
			  nvl(e.start_time, '1990-01-01 00:00:00') ev_start_time,
			  g.name            mkt_name,
			  s.desc            oc_name,
			  mb.desc_1,
			  mb.desc_2,
			  mb.desc_3,
			  mb.desc_4,
			  nvl(mb.to_settle_at, '1990-01-01 00:00:00') to_settle_at,
			  s.result          oc_result,
			  s.place           oc_place,
			  o.price_type,
			  o.o_num           price_num,
			  o.o_den           price_den,
			  NVL(o.leg_no,1)   leg_no,
			  NVL(o.part_no,1)   part_no,
			  o.leg_sort
			  $extra_select_1
		from
			  tBet  b,
		outer tManOBet mb,
		outer (tOBet o, tEvOc s,tEvMkt m,tEvOcGrp g,tEv e)
		$extra_table_1
		where
			  b.acct_id   = ? and
			  b.cr_date   between ? and ? and
			  b.settled   in (?,?) and
			  b.bet_id    = o.bet_id and
			  b.bet_id    = mb.bet_id and
			  o.ev_oc_id  = s.ev_oc_id and
			  s.ev_mkt_id = m.ev_mkt_id and
			  m.ev_id     = e.ev_id and
			  m.ev_oc_grp_id = g.ev_oc_grp_id
			  $extra_where_1
union
		select
			  'TPB',
			  b.pool_bet_id,
			  b.cr_date         bet_date,
			  b.receipt         bet_receipt,
			  b.acct_id         bet_acct_id,
			  b.settled         bet_settled,
			  b.stake           bet_stake,
			  b.ccy_stake_per_line  bet_stake_per_line,
			  b.winnings        bet_winnings,
			  b.refund          bet_refund,
			  'TPB',
			  b.num_lines,
			  b.leg_type,
			  e.desc            ev_name,
			  e.result_conf     ev_result_conf,
			  nvl(e.start_time, '1990-01-01 00:00:00') ev_start_time,
			  g.name            mkt_name,
			  s.desc            oc_name,
			  '',
			  '',
			  '',
			  '',
			  '1990-01-01 00:00:00' to_settle_at,
			  s.result          oc_result,
			  s.place           oc_place,
			  'D',
			  0           price_num,
			  0           price_den,
			  o.leg_no,
			  o.part_no,
			  ''
			  $extra_select_2
		from
			  tPoolBet  b,
			  tPBet o, tEvOc s,tEvMkt m,tEvOcGrp g,tEv e
		where
			  b.acct_id   = ? and
			  b.cr_date   between ? and ? and
			  b.settled   in (?,?) and
			  b.pool_bet_id = o.pool_bet_id and
			  o.ev_oc_id  = s.ev_oc_id and
			  s.ev_mkt_id = m.ev_mkt_id and
			  m.ev_id     = e.ev_id and
			  m.ev_oc_grp_id = g.ev_oc_grp_id
		order by 2 desc, 3, 4
	}]
	#and num_subs>1
	if {[OT_CfgGetTrue HAS_XGAMES]} {
		db_store_qry acct_xgame_bets {
			SELECT
			'sub' type,
			xgame_sub_id id,
			d.name game_name,
			s.cr_date,
			stake_per_bet stake,
			d.sort,
			comp_no,
			0 as refund,
			0 as winnings,
			'-' as paymethod,
			''  as cheque_payout_msg,
			''  as settled,
			s.picks as picks,
			g.draw_at,
			s.num_subs
			FROM
			txgamedef d,
			txgamesub s,
			txgame g
			WHERE
			s.xgame_id = g.xgame_id
			and g.sort = d.sort
			and s.acct_id= ?
			and s.cr_date between ? and ?
		UNION
			SELECT
			'bet' type,
			xgame_bet_id id,
			d.name game_name,
			b.cr_date,
			stake,
			d.sort,
			comp_no,
			refund,
			winnings,
			paymethod,
			d.cheque_payout_msg,
			b.settled,
			b.picks as picks,
			g.draw_at,
			s.num_subs
			FROM
			txgamedef d,
			txgamebet b,
			txgamesub s,
			txgame g
			WHERE
			s.xgame_sub_id = b.xgame_sub_id
			and g.xgame_id = b.xgame_id
			and g.sort = d.sort
			and s.acct_id= ?
			and b.cr_date between ? and ?
			ORDER by 4 desc;
		}
	}

	if {[OT_CfgGetTrue HAS_XGAMES]} {
		db_store_qry SUBS_ONLY_acct_xgame_bets {
			SELECT
			'sub' type,
			s.xgame_sub_id id,
			d.name game_name,
			s.cr_date,
			stake_per_bet stake,
			d.sort,
			comp_no,
			0 as refund,
			0 as winnings,
			'-' as paymethod,
			''  as cheque_payout_msg,
			''  as receipt,
			''  as settled,
			s.picks as picks,
			g.draw_at,
			s.num_subs
			FROM
			txgamedef d,
			txgamesub s,
			txgame g
			WHERE
			s.xgame_id = g.xgame_id
			and g.sort = d.sort
			and s.acct_id= ?
			and s.cr_date between ? and ?
			ORDER by 4 desc;
		} 300
	}

	if {[OT_CfgGetTrue HAS_XGAMES]} {
		db_store_qry acct_xgame_bets_for_sub {
			SELECT
			'bet' type,
			xgame_bet_id id,
			d.name game_name,
			b.cr_date,
			stake,
			d.sort,
			comp_no,
			refund,
			winnings,
			paymethod,
			d.cheque_payout_msg,
			b.settled,
			b.picks as picks,
			g.draw_at,
			s.num_subs
			FROM
			txgamedef d,
			txgamebet b,
			txgamesub s,
			txgame g
			WHERE
			s.xgame_sub_id = b.xgame_sub_id
			and g.xgame_id = b.xgame_id
			and g.sort = d.sort
			and s.xgame_sub_id = ?
			ORDER by g.draw_at asc;
		}
	}

	db_store_qry get_reg_detail {
		SELECT
		r.fname,
		r.lname,
		r.addr_street_1 addr_1,
		r.addr_street_2 addr_2,
		r.addr_street_3 addr_3,
		r.addr_street_4 addr_4,
		r.addr_city     city,
		r.addr_postcode pcode,
		r.telephone,
		r.mobile,
		r.email,
		r.itv_email,
		c.sig_date,
		r.contact_ok

		FROM
		tCustomerReg r,
		tCustomer c

		WHERE
		r.cust_id = c.cust_id and
		c.cust_id = ?
	}




	db_store_qry get_txn_limits {
		SELECT
		min_deposit    min_dep,
		max_deposit    max_dep,
		min_withdrawal min_wtd,
		max_withdrawal max_wtd,
		a.balance - a.balance_nowtd bal_wtd

		FROM
		tCustomer c,
		tCCY      y,
		tAcct     a

		WHERE
		a.ccy_code = y.ccy_code and
		a.cust_id  = c.cust_id  and
		c.cust_id  = ?
	}


	db_store_qry get_acctno {
		SELECT
		c.acct_no,
		r.dob

		FROM
		tCustomer c,
		tCustomerreg r

		WHERE
		c.cust_id = r.cust_id and
		c.cust_id = ?
	}

	db_store_qry upd_pin {
		EXECUTE PROCEDURE pUpdCustPIN (
						   p_acct_no  = ?,
						   p_old_pin  = ?,
						   p_password = ?,
						   p_new_pin  = ?,
						   p_dob      = ?,
						   p_min_pin_length = ?,
						   p_max_pin_length = ?
						   )
	}

	if {[OT_CfgGet BALLS_AVAILABLE 0]==1} {
		db_store_qry acct_balls_bets {
		   select
			  s.sub_id,
			  s.cr_date,
			  s.firstdrw_id,
			  t.desc,
			  s.stake,
			  s.returns,
			  s.ndrw,
			  s.seln
		   from
			  tBallsSub s,
			  tBallsSubType t,
			  tBallsDrwInfo i
		   where
			  s.acct_id = ?
			  and s.type_id = t.type_id
			  and s.cr_date between ? and ?
			  and i.lastdrw_id > s.firstdrw_id
		   order by
			  s.cr_date desc
		}
	} elseif {[OT_CfgGet NET_BALLS_AVAILABLE 0]==1} {
		db_store_qry acct_balls_bets {
		   select
			  s.client_sub_id as sub_id,
			  s.cr_date,
			  1 as firstdrw_id,
			  t.descr as desc,
			  s.stake,
			  s.returns,
			  s.ndraws as ndrw,
			  s.seln
		   from
			  tNmbrSub s,
			  tNmbrSubType t
		   where
			  s.acct_id = ?
			  and s.type_id = t.type_id
			  and s.cr_date between ? and ?
		   order by
			  s.cr_date desc
		}
	}

	if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
	 # get card type info
	   	db_store_qry get_card_type {
			   	SELECT
			   	si.scheme_name

			   	FROM
			   	tcardschemeinfo si,
			   	tcardscheme s

			   	WHERE
			   	s.scheme = si.scheme and
			   	s.bin_lo <= ? and
			   	s.bin_hi >= ?
   		}

		# BlueSquare now check tCardScheme

		db_store_qry get_card_scheme {
			select *
					from   tCardScheme
					where  ? between bin_lo and bin_hi
		}



	}


	if {[OT_CfgGet BALLS_AVAILABLE 0]==1} {

		# Check payout should be displayed
		db_store_qry iballs_draw_for_payout {
			select
				p.drw_id
			from
				tballspayout p, tballsdrwinfo i
			where
				p.drw_id < i.lastdrw_id - 1 and
				p.payout_id = ?
		}

	}

	if {[OT_CfgGet FUTURES_BETTING 0]==1} {
		db_store_qry acct_ix_hist {
			select
				contract_id as id,
				'100Index Order' as trans_type,
				c.cr_date,
				m.name as f_mkt_name,
				case when price > 0 then 'buy' else 'sell' end as side,
				orig_quantity as quantity,
				abs(price) as price,
				0 - c.charge as charge,
				0 - c.commission as commission,
				0 - c.charge - c.commission as amount
			from
				tfContract c,
				tfMkt m
			where
				c.cr_date between ? and ? and
				c.acct_id = ? and
				m.f_mkt_id = c.f_mkt_id
			union
			select
				c.contract_id as id,
				'100Index Trade' as trans_type,
				f.cr_date,
				m.name as f_mkt_name,
				case when c.price > 0 then 'buy' else 'sell' end  as side,
				f.quantity,
				abs(f.price) as price,
				case when c.price > 0 then nvl(t.b_returns,0) else nvl(t.s_returns,0) end as charge,
				0 as commission,
				case when c.price > 0 then nvl(t.b_returns,0) else nvl(t.s_returns,0) end as amount
			from
				tfFill f,
				tfContract c,
				tfTrade t,
				tfMkt m
			where
				f.cr_date between ? and ? and
				f.acct_id = ? and
				c.contract_id = f.contract_id and
				t.trade_id = f.trade_id and
				m.f_mkt_id = f.f_mkt_id
			union
			select
				c.contract_id as id,
				'100Index Cancellation' as trans_type,
				l.cr_date,
				m.name as f_mkt_name,
				case when c.price > 0 then 'buy' else 'sell' end as side,
				abs(l.delta_quantity) as quantity,
				abs(c.price) as price,
				l.ret_charges as charge,
				l.ret_commission as commission,
				(l.ret_charges + l.ret_commission) as amount
			from
				tfCancel l,
				tfContract c,
				tfMkt m
			where
				l.cr_date between ? and ? and
				l.acct_id =  ? and
				c.contract_id = l.contract_id and
				l.f_mkt_id = c.f_mkt_id
			union
			select
				s.settlement_id as id,
				'100Index Settlement' as trans_type,
				s.cr_date,
				m.name as f_mkt_name,
				'-' as side,
				0 as quantity,
				0 as price,
				returns as charge,
				0 as commission,
				returns as amount
			from
				tfSettlement s,
				tfMkt m
			where
				s.cr_date between ? and ? and
				acct_id =  ? and
				m.f_mkt_id = s.f_mkt_id


		}
	}

	if {[OT_CfgGet HAS_IGF_IN_CUST_SCREEN 0] != 1} {

	db_store_qry igf_game_details_stmt [subst {
		select
			tCgGameSummary.cg_game_id,
			tCgGame.name as game_desc,
			tCgGame.cg_class as game_class,
			tCgGameSummary.source,
			tCgGameSummary.started,
			tCgGameSummary.stakes,
			tCgGameSummary.winnings,
	   	    tCgJavaClass.multi_state,
	   	    NVL(tCgBetHist.drawn, '-') as drawn
	   	from
	   	    tCgGameSummary,
	   	    tCgGame,
	   	    tCgAcct,
			tCgJavaClass,
			tCgClass,
	   	    OUTER (tCgBetHist)
	   	where
	   	    tCgGameSummary.cg_game_id = ?
	   	and
	   	    tCgGame.cg_id = tCgGameSummary.cg_id
	   	and
			tCgGameSummary.cg_acct_id = tCgAcct.cg_acct_id
	   	and
	   	    tCgAcct.acct_id = ?
		and
			tCgGame.cg_class = tCgClass.cg_class
		and
			tCgClass.java_class = tCgJavaClass.java_class
		and
	   	    tCgBetHist.cg_game_id = tCgGameSummary.cg_game_id
	}]

	}

	db_store_qry igf_keno_details_stmt [subst {
		select
			tCgKenoHist.drawn,
			tCgKenoHist.selected,
			tCgKenoHist.matches
		from
			tCgKenoHist
		where
		tCgKenoHist.cg_game_id = ?}]

	db_store_qry igf_mlslot_details_stmt [subst {
		select
			c.acct_no,
			g.cg_class,
			g.name,
			g.cg_id,
			def.version,
			def.symbols,
			def.total_win_lines,
			def.view_size,
			a.ccy_code,
			slot.stop,
			slot.reverse_payout,
			slot.sel_win_lines,
			slot.win_lines,
			slot.win_payouts,
			slot.multiplier_index,
			mplr.reel as multiplier_reel,
			sum.started,
			sum.stakes,
			sum.winnings,
			sum.state,
			ch.desc as source
		from
			tCGAcct cga,
			tAcct a,
			tCustomer c,
			tCGGamesummary sum,
			tCGGame g,
			tCGMLSlotDef def,
			tCGMLSlotHist slot,
			tChannel ch,
			outer tCGMLSlotMplr mplr
		where
			sum.cg_game_id = slot.cg_game_id and
			cga.cg_acct_id = sum.cg_acct_id and
			a.acct_id = cga.acct_id and
			c.cust_id = a.cust_id and
			g.cg_id = sum.cg_id and
			def.cg_id = g.cg_id and
			def.version = sum.version and
			mplr.cg_id = def.cg_id and
			mplr.version = def.version and
			ch.channel_id = sum.source
		and
			slot.cg_game_id = ?}]

	db_store_qry get_reel_positions [subst {
		select
			index, reel
		from
			tcgmlslotreel
		where
			cg_id = ? and
			version = ?
		order by index
	}]

	db_store_qry get_card_scheme_details {
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


}


# ----------------------------------------------------------------------
# Load the Operation types from tjrnlop
# ----------------------------------------------------------------------

proc load_jrnl_refs {} {

	variable JRNL_OP

	if {$JRNL_OP(loaded) == 1} {
		return
	}

	if [catch {set rs [db_exec_qry jrnl_ops]} msg] {
		ob::log::write ERROR {failed to retrieve jrnl_ops:$msg}
		return
	}

	set rows [db_get_nrows $rs]

	for {set r 0} {$r < $rows} {incr r} {
		set type [db_get_col $rs $r j_op_type]
		set name [db_get_col $rs $r j_op_name]
		set JRNL_OP($type) $name
	}

	db_close $rs

	set JRNL_OP(loaded) 1
}

# ---------------------------------------------------------------------
# Return the customer account id using the global USER_ID as cust_id
# ----------------------------------------------------------------------

proc get_acct_id {} {

	global USER_ID

	if [catch {set rs [db_exec_qry acct_id $USER_ID]} msg] {
		return -1
	}

	if {[db_get_nrows $rs] != 1} {
		set acct_id -1
	} else {
		set acct_id [db_get_col $rs acct_id]
	}

	db_close $rs

	return $acct_id
}


# ----------------------------------------------------------------------
# return the balance for the current customer
#
# if passwd nowtd the balance returned is the non withdrawable
# balance
# ----------------------------------------------------------------------

proc get_balance {{type wtd}} {

	global USER_ID

	if [catch {set rs [db_exec_qry get_acct_balance $USER_ID]} msg] {
		ob::log::write ERROR {Failed to get customer balance: $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write WARNING {Cust balance query returned [db_get_nrows $rs] rows}
		return 0
	}

	if {$type == "wtd"} {
		set amnt [db_get_col $rs balance]
	} elseif {$type == "nowtd"} {
		set amnt [expr {[db_get_col $rs balance] - [db_get_col $rs balance_nowtd]}]
	} else {
		set amnt 0
	}

	db_close $rs

	return $amnt
}




# ======================================================================
# account query
# ======================================================================

proc go_acct_qry {} {

	global LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF
	tpBindString ISQRY _on

		set st_year     [reqGetArg start_year]
		set st_month    [reqGetArg start_mon]
		set st_day      [reqGetArg start_day]

		set end_year    [reqGetArg end_year]
		set end_month   [reqGetArg end_mon]
		set end_day     [reqGetArg end_day]


	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	tpSetVar Default [reqGetArg default]


	set start_secs [reqGetArg start_secs]
	set end_secs [reqGetArg end_secs]
	if {$start_secs=="" || $end_secs==""} {
		set end_secs [clock seconds]
		## 1 Week back
		set start_secs [expr {$end_secs - (24*7*60*60)}]
	}

	## If we're explicity passed this information, use it instead
	if {$st_year!=""  && $st_month!=""  && $st_day!="" &&
		$end_year!="" && $end_month!="" && $end_year!=""} {
		set dim         [days_in_month $st_month $st_year]
		if {$st_day > $dim} {
			set st_day $dim
		}
		set st_month    [format "%02d" $st_month]
		set st_day      [format "%02d" $st_day]
		set start       "$st_year-$st_month-$st_day 00:00:00"

		set dim         [days_in_month $end_month $end_year]
		if {$end_day > $dim} {
			set end_day $dim
		}
		set end_month   [format "%02d" $end_month]
		set end_day     [format "%02d" $end_day]
		set end         "$end_year-$end_month-$end_day 23:59:59"

		set start_secs [ifmx_date_to_secs $start]
		set end_secs   [ifmx_date_to_secs $end]
	}


	tpBindTcl days1   "openbet_func_pop_date_menus_at_time DAY   $end_secs"
	tpBindTcl months1 "openbet_func_pop_date_menus_at_time MONTH $end_secs"
	tpBindTcl years1  "openbet_func_pop_date_menus_at_time YEAR  $end_secs"

	tpBindTcl days2   "openbet_func_pop_date_menus_at_time DAY   $start_secs"
	tpBindTcl months2 "openbet_func_pop_date_menus_at_time MONTH $start_secs"
	tpBindTcl years2  "openbet_func_pop_date_menus_at_time YEAR  $start_secs"

	tpBindString balance [print_ccy [get_balance]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]

	play_template Query
}


# ------------------------------------------------------
# retrieve the dates from the query form,
# call the reqd procedure to show bet/txn history
#
# we need to check that the dates entered are legal
# as informix gets its knickers in a twist if they are not
# ------------------------------------------------------

proc go_acct_hist { {actually_play_file Y}} {


	global PLATFORM

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}


	## Bind up platform for transaction history
	if [OT_CfgGet MULTI_PLATFORM 0] {
		tpBindString PLATFORM $PLATFORM
	}

	set st_year     [reqGetArg start_year]
	set st_month    [reqGetArg start_mon]
	set st_day      [reqGetArg start_day]

	set end_year    [reqGetArg end_year]
	set end_month   [reqGetArg end_mon]
	set end_day     [reqGetArg end_day]

	if {[reqGetArg qry_type] == "L"} {
		set now [clock seconds]

		set end   [get_ifmx_date $now]
		set start [get_ifmx_date [expr {$now - [reqGetArg past]}]]

	} else {

		if {$st_year!="" && $st_month!="" && $st_day!="" &&
			$end_year!="" && $end_month!="" && $end_year!=""} {
			set dim [days_in_month $st_month $st_year]
			if {$st_day > $dim} {
				set st_day $dim
			}
			set st_month    [format "%02d" $st_month]
			set st_day      [format "%02d" $st_day]
			set start       "$st_year-$st_month-$st_day 00:00:00"

			set dim         [days_in_month $end_month $end_year]
			if {$end_day > $dim} {
				set end_day $dim
			}
			set end_month   [format "%02d" $end_month]
			set end_day     [format "%02d" $end_day]
			set end         "$end_year-$end_month-$end_day 23:59:59"
		} else {
			set now [clock seconds]

			# Use default of 1 week in the past
			set end   [get_ifmx_date $now]
			set start [get_ifmx_date [expr {$now - 60*60*24*7}]]
		}
	}

	# if $start later than $end swap them
	if {[string compare $start $end] == 1} {
		set d   $start
		set start $end
		set end   $d
	}

	# Unless start_secs and end_secs are passed in which case use them
	if {[reqGetArg start_secs]!="" && [reqGetArgs end_secs]!=""} {
		set start [get_ifmx_date [reqGetArg start_secs]]
		set end   [get_ifmx_date [reqGetArg end_secs]]
	}


	reprint_args

	tpBindString start_date [html_date $start day]
	tpBindString end_date   [html_date $end   day]

	set start_secs [ifmx_date_to_secs $start]
	tpBindString start_secs $start_secs
	set end_secs   [ifmx_date_to_secs $end]
	tpBindString end_secs $end_secs

	tpBindTcl days1   "openbet_func_pop_date_menus_at_time DAY   $end_secs"
	tpBindTcl months1 "openbet_func_pop_date_menus_at_time MONTH $end_secs"
	tpBindTcl years1  "openbet_func_pop_date_menus_at_time YEAR  $end_secs"

	tpBindTcl days2   "openbet_func_pop_date_menus_at_time DAY   $start_secs"
	tpBindTcl months2 "openbet_func_pop_date_menus_at_time MONTH $start_secs"
	tpBindTcl years2  "openbet_func_pop_date_menus_at_time YEAR  $start_secs"


	if {([OT_CfgGet OPENBET_CUST ""] == "BlueSQ") && ([reqGetArg qry_type] == "B")} {
		if {[catch {
			set start_d [format "%0.2d" [string trimleft $st_day 0]]
			set start_m [format "%0.2d" [string trimleft $st_month 0]]
			set start_y [format "%0.2d" [string trimleft $st_year 0]]
			set end_d [format "%0.2d" [string trimleft $end_day 0]]
			set end_m [format "%0.2d" [string trimleft $end_month 0]]
			set end_y [format "%0.2d" [string trimleft $end_year 0]]} msg]} {
			err_add [ml_printf MY_ACCT_BET_HIST_INVALID_DATE]
			play_template Query
			return
		}

		set start_str "$start_m/$start_d/$start_y"
		set end_str "$end_m/$end_d/$end_y"

		if {[catch {set start_time [clock scan $start_str]} msg]} {
			# START DATE IS INVALID
			err_add [ml_printf MY_ACCT_BET_HIST_INVALID_START]
			play_template Query
			return
		}

		if {[catch {set end_time [clock scan $end_str]} msg]} {
			# END DATE IS INVALID
			err_add [urlencode MY_ACCT_BET_HIST_INVALID_END]
			play_template Query
			return
		}

		set todays_date [clock format [clock seconds] -format "%Y-%m-%d"]
		scan $todays_date "%4s-%2s-%2s" Y m d

		set two_yrs_ago [clock scan "$m/$d/[expr $Y - 2]"]

		if {$start_time < $two_yrs_ago} {
			err_add [ml_printf MY_ACCT_BET_HIST_INVALID_PERIOD]
			play_template Query
			return
		}
	}

	switch -- [reqGetArg show] {
		"TX" {
		tpBindString bh_title [ml_printf ACCT_TXN_HIST_HEADER]
		go_txn_hist $start $end $actually_play_file
		}
		"BS" {
			tpBindString bh_title [ml_printf CUST_ACCT_STL_BETS]
			go_bet_hist $start $end Y Y $actually_play_file
		}
		"BU" {
			tpBindString bh_title [ml_printf CUST_ACCT_UNSTL_BETS]
			go_bet_hist $start $end N N $actually_play_file
		}
		"BA" {
			tpBindString bh_title [ml_printf CUST_ACCT_SPORTS_BETS]
			go_bet_hist $start $end Y N $actually_play_file
		}
		"XG" {
			if {[OT_CfgGet HAS_XGAMES 0] == 0} {
				# Shouldn't happen unless the db is buggered
				ob::log::write INFO {Trying to generate external game bet history, but config HAS_XGAMES = 0}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			tpBindString bh_title [ml_printf CUST_ACCT_XGAME_BETS]
			set test [ml_printf CUST_ACCT_XG_BETS]
			go_xgame_bet_hist $start $end $actually_play_file
		}
		"IB" {
			if {[OT_CfgGet BALLS_AVAILABLE 0] == 0 && [OT_CfgGet NET_BALLS_AVAILABLE 0] == 0} {
				ob::log::write INFO {Config BALLS_AVAILABLE is 0 can't access balls}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			tpBindString bh_title [ml_printf CUST_ACCT_BALLS_BETS]
			go_balls_hist $start $end $actually_play_file
		}
		"IX" {
			if {[OT_CfgGet FUTURES_BETTING 0] == 0} {
				ob::log::write WARN {Attempt to genereate index trading history, but config FUTURES_BETTING = 0}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			tpBindString bh_title [ml_printf CUST_ACCT_IX_BETS]
			go_ix_hist $start $end $actually_play_file

		}
		"CA" {
		tpBindString bh_title "Casino Bet History"
		go_casino_hist $start $end $actually_play_file
		}
		"BB" {
		tpBindString bh_title "Balls Bet History"
		go_new_balls_hist $start $end $actually_play_file
		}
		"CB" {
		tpBindString bh_title "Games History"
		go_casino_balls_hist $start $end $actually_play_file
		}
		default {
			ob::log::write ERROR {Unknown transaction type [reqGetArg show]}
			err_add [ml_printf ACCT_NO_ACCT_DATA]
			play_template Error
		}
	}
}



# ----------------------------------------------------------------
# called to display txn history
#
# the ACCT_TXN array is created with all the txn data indexed
# within. All display is the donw using tpBindVar
# ----------------------------------------------------------------

proc go_txn_hist {st end {actually_play_file Y}} {

	global USER_ID ACCT_TXNS LOGIN_DETAILS PLATFORM
	variable JRNL_OP
	variable HTML_CHARS_PREF

	set txns_per_page [reqGetArg txns_per_page]
	if {$txns_per_page == ""} {
	set txns_per_page 10
	}

	## Bind up platform for transaction history
	if [OT_CfgGet MULTI_PLATFORM 0] {
		tpBindString PLATFORM $PLATFORM
	}

	if {[reqGetArg deps_and_wtds_only]=="Y"} {
		set qry acct_deps_wtds
	} elseif {[reqGetArg mcs_txns_only]=="Y"} {
		set qry acct_mcs_txns
	} elseif {[reqGetArg last_3_acct_txns]=="Y"} {
		set qry last_3_acct_txns
	} elseif {[reqGetArg deps_only]=="Y"} {
		set qry acct_deps
	} elseif {[reqGetArg wtds_only]=="Y"} {
		set qry acct_wtds
	} else {
		set qry acct_txns
	}

	if [catch {set rs [db_exec_qry $qry $st $end $USER_ID]} msg] {
		ob::log::write ERROR {failed to retrieve txn history: $msg}
		err_add [ml_printf ACCT_NO_TRNS_DATA]
		play_template Error
		return
	}

	set nrows [db_get_nrows $rs]
	set ACCT_TXNS(num_txns) $nrows
	set j -1

	for {set i 0} {$i < $nrows} {incr i} {

		set j_op [db_get_col $rs $i j_op_type]
		set key [db_get_col $rs $i j_op_ref_key]
		set ref_id [db_get_col $rs $i j_op_ref_id]

		# Don't display a payout if the game hasn't finished running in the client
		if {$j_op == "IB++"} {
			set lsrs [db_exec_qry iballs_draw_for_payout $ref_id]
			set rws [db_get_nrows $lsrs]
			db_close $lsrs
			if {$rws == 0} {
				continue
			} else {
				incr j
			}
		} else {
			incr j
		}

		set date [db_get_col $rs $i cr_date]

		set ACCT_TXNS($j,date) [html_date $date shrtday]
		set ACCT_TXNS($j,date2digityear) [html_date $date shrtday2digityear]

		# append the j_op description to any description

		set desc [db_get_col $rs $i desc]
		if {$desc != ""} {
			set new_desc [split $desc '|']
			set value [lindex $new_desc 1]
			if {$value == "VAL_TOKEN_USED"} {
				set desc "[lindex $new_desc 0]| Freebet token used|"
			}
		}

		if {$key == "IGF"} {
			set igf_name [string toupper "${j_op}_[db_get_col $rs $i igf_name]"]
			set name "|${igf_name}|"
		} else {
			set name $JRNL_OP($j_op)
		}

		if {[db_get_col $rs $i j_op_ref_key]=="XSYS"} {
			#this ones for ladbrokes - hope it doesn't upset anyone
			set ACCT_TXNS($j,desc) "[XL $desc]"
		} elseif {[db_get_col $rs $i j_op_ref_key]=="IGF"} {
		# Customers dont know what IGF is, so remove. Otherwise have to alter table tjrnlop (which sets $JRNL_OP(CGSK) and $JRNL_OP(CGWN))
			regsub {(.*)IGF(.*)} "[XL $name]" {\1 \2} ACCT_TXNS($j,desc)
		} elseif {[string length $desc] > 0} {
			set ACCT_TXNS($j,desc) "[XL $desc] : [XL $name]"
		} else {
			set ACCT_TXNS($j,desc) "[XL $name]"
		}

		if {[OT_CfgGet USE_SHORT_DESC_CASINO 0]} {
			if {[db_get_col $rs $i j_op_ref_key]=="MCM"} {
				set ACCT_TXNS($j,desc) [OT_CfgGet SHORT_DESC_CASINO "Casino"]
			}

			if {[db_get_col $rs $i j_op_ref_key]=="MCMR"} {
				set ACCT_TXNS($j,desc) [OT_CfgGet SHORT_DESC_CASINO "Casino Refund"]
			}
		}

		set amount [db_get_col $rs $i amount]

		if {![info exists balance]} {
			set balance [db_get_col $rs $i balance]
			if {![string is double -strict $balance]} {
				# oh dear...time to get the final balance the hard way

				if [catch {set rs_bal [db_exec_qry get_historic_balance $end $USER_ID]} msg] {
					ob::log::write ERROR {failed to retrieve historic balance: $msg}
					err_add [ml_printf ACCT_NO_TRNS_DATA]
					play_template Error
					return
				} elseif {[db_get_nrows $rs_bal] != 1} {
					db_close $rs_bal
					err_add [ml_printf ACCT_NO_TRNS_DATA]
					play_template Error
					return
				}

				set balance [db_get_col $rs_bal 0 balance]
				db_close $rs_bal
			}
		}

		set ACCT_TXNS($j,balance) [print_ccy $balance $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($j,amount)  [print_ccy $amount $LOGIN_DETAILS(CCY_CODE)\
				$HTML_CHARS_PREF]
		set ACCT_TXNS($j,ref_id)  $ref_id
		set ACCT_TXNS($j,ref_key) [db_get_col $rs $i j_op_ref_key]

		# For casino games
		if {$ACCT_TXNS($j,ref_key) == "IGF" && [OT_CfgGet IGF_ACCT_HIST_NAME_ONLY 0]} {
			set ACCT_TXNS($j,desc) "[db_get_col $rs $i igf_name]"
		} elseif {$ACCT_TXNS($j,ref_key) == "IGF"} {
			 set ACCT_TXNS($j,desc) "[db_get_col $rs $i igf_name] - $ACCT_TXNS($j,desc)"
		}

		set ACCT_TXNS($j,op_type) $j_op
		set balance [expr {$balance - $amount}]

		set absamount [expr {abs($amount)}]
		if {$amount<0.00} {
			set ACCT_TXNS($j,debit) [print_ccy $absamount $LOGIN_DETAILS(CCY_CODE)\
					$HTML_CHARS_PREF]
			set ACCT_TXNS($j,credit) ""
		} else {
			set ACCT_TXNS($j,credit) [print_ccy $absamount $LOGIN_DETAILS(CCY_CODE)\
					$HTML_CHARS_PREF]
			set ACCT_TXNS($j,debit) ""
		}

		#get operator used for telebetting
		set user [db_get_col $rs $i user_id]
		if {$user != ""} {
			set ACCT_TXNS($j,user_id) $user
		} else {
			set ACCT_TXNS($j,user_id) ""
		}

	}
	db_close $rs

	tpBindVar TXN_DATE    ACCT_TXNS date    tx_idx
	tpBindVar TXN_DATE_2_DIGIT_YEAR\
				ACCT_TXNS date2digityear    tx_idx
	tpBindVar TXN_DESC    ACCT_TXNS desc    tx_idx
	tpBindVar TXN_AMNT    ACCT_TXNS amount  tx_idx
	tpBindVar TXN_ID      ACCT_TXNS ref_id  tx_idx
	tpBindVar TXN_CREDIT  ACCT_TXNS credit  tx_idx
	tpBindVar TXN_DEBIT   ACCT_TXNS debit   tx_idx
	tpBindVar TXN_BALANCE ACCT_TXNS balance tx_idx
	tpBindVar TXN_REF_KEY ACCT_TXNS ref_key tx_idx
	tpBindVar TXN_OP_TYPE ACCT_TXNS op_type tx_idx
	tpBindVar TXN_USERID  ACCT_TXNS user_id tx_idx

	set page [reqGetArg page]
	if {$page == ""} {
	   	set page 0
	}
	set show_rows [expr {$j + 1}]
	tpSetVar ThisPage  $page
	tpSetVar NumTxns   [min [expr {$txns_per_page * ($page + 1)}] $show_rows]
	tpSetVar NumPages  [expr {ceil((double($show_rows))/$txns_per_page)}]
	tpSetVar StartIdx  [expr {$txns_per_page * $page}]
	tpSetVar NumTxnRows [expr {$show_rows - 1}]
	tpSetVar TotalNumTxnRows $show_rows


	if { $actually_play_file == "Y" } {
		play_template TxnHist

		unset ACCT_TXNS
	}
}



# ----------------------------------------------------------------------
# go to the bet history list - blatently stolen from the admin screens
#
# bets_per_page controls how many bets are shown
# ----------------------------------------------------------------------

proc go_bet_hist {st end stl1 {stl2 N} {actually_play_file Y}} {

	global BET BET_TYPE LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set bets_per_page [reqGetArg bets_per_page]
	if {$bets_per_page == ""} {
	set bets_per_page 10.0
	}

	set bet_id [reqGetArg bet_id]

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if [catch {
		set rs [db_exec_qry acct_bets $acct_id $st $end $stl1 $stl2 $acct_id $st $end $stl1 $stl2]
	} msg] {
		ob::log::write ERROR {Failed to retreive bet history, $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	array set BET [list]

	set nrows [db_get_nrows $rs]


	set BET(num_bets) $nrows
	set cur_id 0
	set b -1

	for {set r 0} {$r < $nrows} {incr r} {

		set bet_id [db_get_col $rs $r bet_id]

		if {$bet_id != $cur_id || [db_get_col $rs $r bet_type]=="SB"} {
			set cur_id $bet_id
			set l 0
			incr b
			set BET($b,num_selns) 0
		}

		incr BET($b,num_selns)

		if {$l == 0} {
			set BET($b,bet_id) $bet_id
			if [OT_CfgGet FUNC_SPREAD 0] {
				set BET($b,spread_bet_id) [db_get_col $rs $r spread_bet_id]
			}

			set bet_date [db_get_col $rs $r bet_date]
			set BET($b,bet_date)  [html_date $bet_date shrtday]
			set BET($b,bet_date2digityear)  [html_date $bet_date shrtday2digityear]
			set BET($b,bet_date_inf)  [html_date $bet_date]
			set BET($b,receipt)   [db_get_col $rs $r bet_receipt]
			set BET($b,stake)     [print_ccy [db_get_col $rs $r bet_stake]\
					$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
			set BET($b,stake_per_line)     [print_ccy [db_get_col $rs $r bet_stake_per_line]\
					$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
			set BET($b,settled)   [db_get_col $rs $r bet_settled]
			set BET($b,winnings)  [print_ccy [db_get_col $rs $r bet_winnings]\
					$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
			set BET($b,refund)    [print_ccy [db_get_col $rs $r bet_refund]\
					$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
			set BET($b,num_lines) [db_get_col $rs $r num_lines]
			set BET($b,settle_type) N
			set bet_type          [db_get_col $rs $r bet_type]
			set BET($b,bet_type)  $bet_type
			# extra field added for BlockBuster coupon
			# this is the bonus from tBetBlockBuster that is associated with this bet
			if {[OT_CfgGetTrue HAS_BLOCKBUSTER]} {
				set bonus [db_get_col $rs $r bonus]
				if {$bonus != -1} {
					set BET($b,bb_bonus) $bonus
				} else {
					set BET($b,bb_bonus) ""
				}
			}

			if {$bet_type == "MAN"}	{
				set is_spread 0
				set BET($b,bet_name)  [XL "Manual Bet"]
			} elseif {$bet_type == "TPB"}	{
				set is_spread 0
				set BET($b,bet_name)  [XL "Pool Bet"]
			} else {
				if {$bet_type == "SB"} {
					set is_spread 1
					set BET($b,bet_name)  [XL "Spread Bet"]
				} else {
					set is_spread 0
					set BET($b,bet_name)  [XL $BET_TYPE($bet_type,bet_name)]
					}
				}


				if { $bet_type == "SGL" } {
					set start_date [db_get_col $rs $r ev_start_time]
					set BET($b,ev_start_date) [html_date $start_date shrtday2digityear]
				}
		}

		set BET($b,$l,leg_sort) [db_get_col $rs $r leg_sort]
		set BET($b,$l,leg_type) [db_get_col $rs $r leg_type]
		set BET($b,$l,leg_no)   [db_get_col $rs $r leg_no]

		set BET($b,$l,result)   [db_get_col $rs $r oc_result]
		set BET($b,$l,place)    [db_get_col $rs $r oc_place]
		set BET($b,$l,part_no)  [db_get_col $rs $r part_no]

		set prc_type [db_get_col $rs $r price_type]
		set prc_num  [db_get_col $rs $r price_num]
		set prc_den  [db_get_col $rs $r price_den]

		if {$is_spread} {
			set BET($b,$l,price) $prc_num
		} else {
			set BET($b,$l,price) [mk_bet_price_str $prc_type\
						  $prc_num $prc_den\
						  $prc_num $prc_den]
		}

		if {$bet_type == "MAN"}	{
			set BET($b,$l,ev_name)  [XL [db_get_col $rs $r desc_1]]
			set BET($b,$l,mkt_name) [XL [db_get_col $rs $r desc_2]]
			set BET($b,$l,oc_name)  [XL [db_get_col $rs $r desc_3]]
			set BET($b,$l,desc_4)   [XL [db_get_col $rs $r desc_4]]
		} else {
			if {$bet_type == "SB"} {
				set BET($b,$l,oc_name)  [expr {[db_get_col $rs $r oc_name]=="H" ? [ml_printf CUST_ACCT_BOUGHT] : [ml_printf CUST_ACCT_SOLD]}]
			} else {
				set BET($b,$l,ev_name)  [XL [db_get_col $rs $r ev_name]]
				set BET($b,$l,mkt_name) [XL [db_get_col $rs $r mkt_name]]
				set BET($b,$l,oc_name)  [XL [db_get_col $rs $r oc_name]]
			}
		}

		incr l
	}

	db_close $rs

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	tpSetVar ThisPage  $page
	tpSetVar NumBets   [min [expr {$bets_per_page * ($page + 1)}] [expr {$b+1}]]
	tpSetVar NumPages  [expr {ceil(double($b+1)/double($bets_per_page))}]
	tpSetVar StartBets [expr {$bets_per_page * $page}]
	tpSetVar NumRows   [expr {$b + 1}]

	tpBindVar BetDate     BET bet_date  bet_idx
	tpBindVar BetDate2DigitYear BET bet_date2digityear  bet_idx
	tpBindVar BetDateInf  BET bet_date_inf  bet_idx
	tpBindVar BetId       BET bet_id    bet_idx
	tpBindVar StartDate   BET ev_start_date       bet_idx
	if [OT_CfgGet FUNC_SPREAD 0] {
		tpBindVar SpreadBetId BET spread_bet_id    bet_idx
	}
	tpBindVar BetReceipt  BET receipt   bet_idx
	tpBindVar BetSettled  BET settled   bet_idx
	tpBindVar BetType     BET bet_name  bet_idx
	tpBindVar BetTypeCode BET bet_type  bet_idx
	tpBindVar BetStake    BET stake     bet_idx
	tpBindVar BetStakePerLine    BET stake_per_line     bet_idx
	tpBindVar NumLines    BET num_lines bet_idx
	tpBindVar BetLegNo    BET leg_no    bet_idx seln_idx
	tpBindVar BetLegSort  BET leg_sort  bet_idx seln_idx
	tpBindVar BetLegType  BET leg_type  bet_idx seln_idx
	tpBindVar EvDesc      BET ev_name   bet_idx seln_idx
	tpBindVar MktDesc     BET mkt_name  bet_idx seln_idx
	tpBindVar SelnDesc    BET oc_name   bet_idx seln_idx
	tpBindVar Price       BET price     bet_idx seln_idx
	tpBindVar Returns     BET winnings  bet_idx
	tpBindVar Refund      BET refund    bet_idx

	if {[OT_CfgGetTrue HAS_BLOCKBUSTER]} {
		tpBindVar BBBONUS     BET bb_bonus  bet_idx
	}

	if { $actually_play_file == "Y" } {
		play_template BetHist

		unset BET
	}
}


#
#	New FOG games query. template spec'd in init.tcl
#

proc go_casino_hist {st end stl1 {stl2 N} {actually_play_file Y}} {

	global USER_ID ACCT_TXNS LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set txns_per_page [reqGetArg txns_per_page]
	if {$txns_per_page == ""} {
	set txns_per_page 10
	}

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if [catch {
		set rs [db_exec_qry casino_bets $st $end $acct_id]
	} msg] {
		ob::log::write ERROR {Failed to retrieve casino bet history, $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	set nrows [db_get_nrows $rs]
	set ACCT_TXNS(num_txns) $nrows

	for {set i 0} {$i < $nrows} {incr i} {

		set ACCT_TXNS($i,cg_game_id) 	[db_get_col $rs $i cg_game_id]
		set ACCT_TXNS($i,name) 			[XL [db_get_col $rs $i name]]
		set ACCT_TXNS($i,started) 		[html_date [db_get_col $rs $i started] shrtday]
		set ACCT_TXNS($i,stakes) 		[print_ccy [db_get_col $rs $i stakes] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,winnings) 		[print_ccy [db_get_col $rs $i winnings] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]

	}

	db_close $rs

	tpBindVar NAME	   	ACCT_TXNS name    	 tx_idx
	tpBindVar STARTED   ACCT_TXNS started    tx_idx
	tpBindVar STAKES 	ACCT_TXNS stakes	 tx_idx
	tpBindVar WINNINGS  ACCT_TXNS winnings   tx_idx
	tpBindVar TXN_ID    ACCT_TXNS cg_game_id tx_idx

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	set show_rows [expr {$nrows}]
	tpSetVar ThisPage  $page
	tpSetVar NumTxns   [min [expr {$txns_per_page * ($page + 1)}] $show_rows]
	tpSetVar NumPages  [expr {ceil((double($show_rows))/$txns_per_page)}]
	tpSetVar StartIdx  [expr {$txns_per_page * $page}]
	tpSetVar NumTxnRows [expr {$show_rows - 1}]
	tpSetVar TotalNumTxnRows $show_rows


	if { $actually_play_file == "Y" } {
		play_template CasinoHist

		unset ACCT_TXNS
	}
}


#
#	New SNG Bets Query
#


proc go_new_balls_hist {st end stl1 {stl2 N} {actually_play_file Y}} {

	global USER_ID ACCT_TXNS LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set txns_per_page [reqGetArg txns_per_page]
	if {$txns_per_page == ""} {
	set txns_per_page 10
	}

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if [catch {
		set rs [db_exec_qry new_balls_bets $st $end $acct_id]
	} msg] {
		ob::log::write ERROR {Failed to retrieve balls bet history, $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	set nrows [db_get_nrows $rs]
	set ACCT_TXNS(num_txns) $nrows

	for {set i 0} {$i < $nrows} {incr i} {

		set ACCT_TXNS($i,started) 			[html_date [db_get_col $rs $i started] shrttime]
		set ACCT_TXNS($i,status)			[get_status [db_get_col $rs $i status]]
		set ACCT_TXNS($i,finished) 			[html_date [db_get_col $rs $i finished] hr_min]
		set ACCT_TXNS($i,stake_per_game)	[print_ccy [db_get_col $rs $i stake_per_game] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,total_stake)		[print_ccy [db_get_col $rs $i total_stake] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,winnings) 			[print_ccy [db_get_col $rs $i winnings] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,refund) 			[print_ccy [db_get_col $rs $i refund] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]

	}

	db_close $rs

	tpBindVar STARTED   		ACCT_TXNS started   	tx_idx
	tpBindVar STATUS			ACCT_TXNS status   	 	tx_idx
	tpBindVar FINISHED	   		ACCT_TXNS finished   	tx_idx
	tpBindVar TOTAL_STAKE 		ACCT_TXNS total_stake	tx_idx
	tpBindVar WINNINGS  		ACCT_TXNS winnings   	tx_idx
	tpBindVar REFUND    		ACCT_TXNS refund	 	tx_idx
	tpBindVar STAKE_PER_GAME  	ACCT_TXNS stake_per_game   	tx_idx
	tpBindVar REFUND    		ACCT_TXNS refund	 	tx_idx

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	set show_rows [expr {$nrows}]
	tpSetVar ThisPage  $page
	tpSetVar NumTxns   [min [expr {$txns_per_page * ($page + 1)}] $show_rows]
	tpSetVar NumPages  [expr {ceil((double($show_rows))/$txns_per_page)}]
	tpSetVar StartIdx  [expr {$txns_per_page * $page}]
	tpSetVar NumTxnRows [expr {$show_rows - 1}]
	tpSetVar TotalNumTxnRows $show_rows


	if { $actually_play_file == "Y" } {
		play_template BallsHist

		unset ACCT_TXNS
	}
}


#
#	Show Casino Bets combined with SNG bets (Ballseye, Arcade Derby etc)
#


proc go_casino_balls_hist {st end {actually_play_file Y}} {

	global USER_ID ACCT_TXNS LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set txns_per_page [reqGetArg txns_per_page]
	if {$txns_per_page == ""} {
	set txns_per_page 10
	}

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if [catch {
		set rs [db_exec_qry casino_balls_bets $st $end $acct_id $st $end $acct_id]
	} msg] {
		ob::log::write ERROR {Failed to retrieve balls bet history, $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	set nrows [db_get_nrows $rs]
	set ACCT_TXNS(num_txns) $nrows

	for {set i 0} {$i < $nrows} {incr i} {

		set ACCT_TXNS($i,game_id) 			[db_get_col $rs $i game_id]
		set ACCT_TXNS($i,started) 			[html_date [db_get_col $rs $i started] shrttime]
		set ACCT_TXNS($i,started_shrt) 			[html_date [db_get_col $rs $i started] shrtday2digityear]
		set ACCT_TXNS($i,state)				[get_status [db_get_col $rs $i state]]
		set ACCT_TXNS($i,stake)				[print_ccy [db_get_col $rs $i stakes] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,winnings) 			[print_ccy [db_get_col $rs $i winnings] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set ACCT_TXNS($i,name) 				[db_get_col $rs $i name]
		set ACCT_TXNS($i,game) 				[db_get_col $rs $i game]

	}

	db_close $rs

	tpBindVar GAME_ID			ACCT_TXNS game_id		tx_idx
	tpBindVar STARTED   		ACCT_TXNS started   	tx_idx
	tpBindVar STARTED_SHRT 		ACCT_TXNS started_shrt 	tx_idx
	tpBindVar STATE				ACCT_TXNS state   	 	tx_idx
	tpBindVar STAKE		 		ACCT_TXNS stake			tx_idx
	tpBindVar WINNINGS  		ACCT_TXNS winnings   	tx_idx
	tpBindVar NAME		  		ACCT_TXNS name		   	tx_idx
	tpBindVar GAME		  		ACCT_TXNS game		   	tx_idx

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	set show_rows [expr {$nrows}]
	tpSetVar ThisPage  $page
	tpSetVar NumTxns   [min [expr {$txns_per_page * ($page + 1)}] $show_rows]
	tpSetVar NumPages  [expr {ceil((double($show_rows))/$txns_per_page)}]
	tpSetVar StartIdx  [expr {$txns_per_page * $page}]
	tpSetVar NumTxnRows [expr {$show_rows - 1}]
	tpSetVar TotalNumTxnRows $show_rows


	if { $actually_play_file == "Y" } {
		play_template CasinoBallsHist

		unset ACCT_TXNS
	}
}




# ----------------------------------------------------------------------
# go to the xgame bet history list
#
# bets_per_page controls how many bets are shown
# ----------------------------------------------------------------------

proc go_xgame_bet_hist {st end {actually_play_file Y}} {

	global XGAME_BET BET_TYPE LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set bets_per_page 10

	set bet_id [reqGetArg bet_id]

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	#remember the args, so can re-create the page in back button
	tpBindString start $st
	tpBindString end $end

	#
	# If the SUBS ONLY option is chosen the query is effectively just the first part of the union
	# for the normal query.  So the bindings that follow will work for both queries.
	#
	if {[OT_CfgGet SUBS_ONLY ""] == "Y"} {
		ob::log::write INFO "SUBS_ONLY query"
		if [catch { set rs [db_exec_qry SUBS_ONLY_acct_xgame_bets $acct_id $st $end $acct_id $st $end ] } msg] {
			ob::log::write ERROR {Failed to retreive xgame bet history, $msg}
			err_add [ml_printf ACCT_NO_ACCT_DATA]
			play_template Error
			return
		}
	} else {
		if [catch { set rs [db_exec_qry acct_xgame_bets $acct_id $st $end $acct_id $st $end ] } msg] {
			ob::log::write ERROR {Failed to retreive xgame bet history, $msg}
			err_add [ml_printf ACCT_NO_ACCT_DATA]
			play_template Error
			return
		}
	}

	## Bind up acct_id for xgame bet reciepts
	tpBindString AcctID $acct_id


	## Bind up platform for xgame bet reciepts
	if [OT_CfgGet MULTI_PLATFORM 0] {
		tpBindString PLATFORM $PLATFORM
	}

	array set XGAME_BET [list]

	set XGAME_BET(startdate) $st
	set XGAME_BET(enddate)   $end

	set nrows [db_get_nrows $rs]
	tpSetVar TotalBets $nrows

	for {set r 0} {$r < $nrows} {incr r} {

		set type [db_get_col $rs $r type]
		if {$type == "sub"} {
			set XGAME_BET($r,bet_type) [ml_printf CUST_XG_SUB]
		} elseif {$type == "bet"} {
			set XGAME_BET($r,bet_type) [ml_printf CUST_XG_BET]
		} else {
			set XGAME_BET($r,bet_type) $type
		}

		set XGAME_BET($r,bet_type_code) $type
		set XGAME_BET($r,bet_id) [db_get_col $rs $r id]
		set XGAME_BET($r,num_subs) [db_get_col $rs $r num_subs]
		set XGAME_BET($r,bet_game_name) [db_get_col $rs $r game_name]
		set XGAME_BET($r,bet_date)  [html_date [db_get_col $rs $r cr_date] shrtday]
		set XGAME_BET($r,bet_date2digityear)  [html_date [db_get_col $rs $r cr_date] shrtday2digityear]
		set XGAME_BET($r,bet_date_inf)  [html_date [db_get_col $rs $r cr_date]]
		set XGAME_BET($r,stake)     [print_ccy [db_get_col $rs $r stake]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,bet_sort) [db_get_col $rs $r sort]
		set XGAME_BET($r,comp_no) [db_get_col $rs $r comp_no]
		set XGAME_BET($r,winnings)  [print_ccy [db_get_col $rs $r winnings]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,refund)    [print_ccy [db_get_col $rs $r refund]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,paymethod) [db_get_col $rs $r paymethod]
		set XGAME_BET($r,cheque_payout_msg) [db_get_col $rs $r cheque_payout_msg]
		set XGAME_BET($r,settled) [db_get_col $rs $r settled]
		set XGAME_BET($r,picks) [db_get_col $rs $r picks]
		set XGAME_BET($r,draw_at)  [html_date [db_get_col $rs $r draw_at] dayofweek]

		ob::log::write INFO "Day = $XGAME_BET($r,draw_at)"

		switch -exact -- $XGAME_BET($r,draw_at) {
			0 { set XGAME_BET($r,draw_at) "Sunday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			1 { set XGAME_BET($r,draw_at) "Monday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			2 { set XGAME_BET($r,draw_at) "Tuesday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			3 { set XGAME_BET($r,draw_at) "Wednesday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			4 { set XGAME_BET($r,draw_at) "Thursday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			5 { set XGAME_BET($r,draw_at) "Friday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			6 { set XGAME_BET($r,draw_at) "Saturday [html_date [db_get_col $rs $r draw_at] shrtday]" }
		}

		ob::log::write INFO "Day = $XGAME_BET($r,draw_at)"
	}

	db_close $rs

	tpBindVar StartDate   XGAME_BET startdate
	tpBindVar EndDate     XGAME_BET enddate
	tpBindVar BetDate     XGAME_BET bet_date	bet_idx
	tpBindVar BetDate2DigitYear XGAME_BET bet_date2digityear  bet_idx
	tpBindVar BetDateInf  XGAME_BET bet_date_inf	bet_idx
	tpBindVar BetId       XGAME_BET bet_id		bet_idx
	tpBindVar NumSubs       XGAME_BET num_subs	bet_idx
	tpBindVar BetGameName XGAME_BET bet_game_name   bet_idx
	tpBindVar BetType     XGAME_BET bet_type	bet_idx
	tpBindVar BetTypeCode XGAME_BET bet_type_code	bet_idx
	tpBindVar BetStake    XGAME_BET stake		bet_idx
	tpBindVar CompNo      XGAME_BET comp_no		bet_idx
	tpBindVar Returns     XGAME_BET winnings	bet_idx
	tpBindVar Refund      XGAME_BET refund		bet_idx
	tpBindVar ChequeMsg   XGAME_BET cheque_payout_msg bet_idx
	tpBindVar Picks   XGAME_BET picks bet_idx
	tpBindVar DrawAt   XGAME_BET draw_at bet_idx

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	tpSetVar ThisPage $page
	tpSetVar NumBets   [min [expr {$bets_per_page * ($page + 1)}] $nrows]
	tpSetVar NumPages [expr {ceil((double($nrows))/$bets_per_page)}]
	tpSetVar StartIdx [expr {$bets_per_page * $page}]
	tpSetVar NumBetRows [expr {$nrows - 1}]
	tpSetVar TotalNumBetRows $nrows

	if { $actually_play_file == "Y" } {
		play_template XGameBetHist

		unset XGAME_BET
	}
}

# ----------------------------------------------------------------------
# Used when the SUBS_ONLY option available
# ----------------------------------------------------------------------

proc go_bet_hist_for_sub {{actually_play_file Y}} {
	global XGAME_BET BET_TYPE LOGIN_DETAILS PLATFORM
	variable HTML_CHARS_PREF

	ob::log::write INFO "IN PROC go_bet_hist_for_sub"

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set sub_id [reqGetArg sub_id]

	tpBindString page [reqGetArg page]
	tpBindString start_secs [reqGetArg start_secs]
	tpBindString end_secs [reqGetArg end_secs]

	if [catch { set rs [db_exec_qry acct_xgame_bets_for_sub $sub_id] } msg] {
		ob::log::write ERROR {Failed to retreive xgame bet for sub_id $sub_id, $msg}
		err_add [ml_printf ACCT_NO_BETS_FOR_SUB]
		play_template Error
		return
	}

	array set XGAME_BET [list]
	set nrows [db_get_nrows $rs]

	ob::log::write INFO "number of bets for sub_id $sub_id is $nrows"

	tpSetVar TotalBets $nrows

	for {set r 0} {$r < $nrows} {incr r} {

		set XGAME_BET($r,bet_id) [db_get_col $rs $r id]
		set XGAME_BET($r,bet_game_name) [db_get_col $rs $r game_name]
		set XGAME_BET($r,bet_date)  [html_date [db_get_col $rs $r cr_date] shrtday]
		set XGAME_BET($r,bet_date2digityear)  [html_date [db_get_col $rs $r cr_date] shrtday2digityear]
		set XGAME_BET($r,bet_date_inf)  [html_date [db_get_col $rs $r cr_date]]
		set XGAME_BET($r,stake)     [print_ccy [db_get_col $rs $r stake]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,bet_sort) [db_get_col $rs $r sort]
		set XGAME_BET($r,comp_no) [db_get_col $rs $r comp_no]
		set XGAME_BET($r,winnings)  [print_ccy [db_get_col $rs $r winnings]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,refund)    [print_ccy [db_get_col $rs $r refund]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		set XGAME_BET($r,paymethod) [db_get_col $rs $r paymethod]
		set XGAME_BET($r,cheque_payout_msg) [db_get_col $rs $r cheque_payout_msg]
		set XGAME_BET($r,settled) [db_get_col $rs $r settled]
		set XGAME_BET($r,picks) [db_get_col $rs $r picks]
		set XGAME_BET($r,draw_at)  [html_date [db_get_col $rs $r draw_at] dayofweek]

		ob::log::write INFO "Day = $XGAME_BET($r,draw_at)"

		switch -exact -- $XGAME_BET($r,draw_at) {
			0 { set XGAME_BET($r,draw_at) "Sunday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			1 { set XGAME_BET($r,draw_at) "Monday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			2 { set XGAME_BET($r,draw_at) "Tuesday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			3 { set XGAME_BET($r,draw_at) "Wednesday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			4 { set XGAME_BET($r,draw_at) "Thursday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			5 { set XGAME_BET($r,draw_at) "Friday [html_date [db_get_col $rs $r draw_at] shrtday]" }
			6 { set XGAME_BET($r,draw_at) "Saturday [html_date [db_get_col $rs $r draw_at] shrtday]" }
		}

		ob::log::write INFO "Day = $XGAME_BET($r,draw_at)"

	}

	tpBindVar BetDate     XGAME_BET bet_date	bet_idx
	tpBindVar BetDate2DigitYear XGAME_BET bet_date2digityear  bet_idx
	tpBindVar BetDateInf  XGAME_BET bet_date_inf	bet_idx
	tpBindVar BetId       XGAME_BET bet_id		bet_idx
	tpBindVar BetGameName XGAME_BET bet_game_name   bet_idx
	tpBindVar BetStake    XGAME_BET stake		bet_idx
	tpBindVar CompNo      XGAME_BET comp_no		bet_idx
	tpBindVar Returns     XGAME_BET winnings	bet_idx
	tpBindVar Refund      XGAME_BET refund		bet_idx
	tpBindVar ChequeMsg   XGAME_BET cheque_payout_msg bet_idx
	tpBindVar Picks   XGAME_BET picks bet_idx
	tpBindVar DrawAt   XGAME_BET draw_at bet_idx

	if { $actually_play_file == "Y" } {
		play_template XGameBetHistForSub

		unset XGAME_BET
	}

}


# ----------------------------------------------------------------------
# Reprint the query args, with the exception of the page number
# ----------------------------------------------------------------------

proc reprint_args {} {

	set num_args [reqGetNumVals]

	set arg_list ""
	for {set i 0} {$i < $num_args} {incr i} {
		if {[reqGetNthName $i] == "page"} continue

		lappend arg_list "[reqGetNthName $i]=[reqGetNthVal $i]"
	}

	tpBindString QRY_ARGS [join $arg_list "&"]
}




# ======================================================================
# display the receipt for bet_id
# most of the code for this is provided by bet_rcpt.tcl so
# we make use of as much of that as possible
# ======================================================================

proc go_acct_rcpt {{template ""}} {

	global BSEL PLATFORM LOGIN_DETAILS

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set bet_id       [reqGetArg bet_id]
	set req_bet_type [reqGetArg bet_type]
	set acct_id      $LOGIN_DETAILS(ACCT_ID)


	# if URL passes XGAME bet type, don't look in tbet - no row will correspond to this bet_id

	# IBS = Balls Subscription
	# IBP = Balls Payout (i.e. payout for one entry in one draw)

	set bet_types "XGAM TPB IBS IBP"

	if {[lsearch $bet_types $req_bet_type]!=-1} {
		set bet_type $req_bet_type
	}  else {

		# otherwise get bet type from tbet table
		if [catch {set rs [db_exec_qry get_bet_type $bet_id "--"]} msg] {
			ob::log::write ERROR {failed to get bet type: $msg}
			err_add [ml_printf ACCT_NO_BET_DETS]
			play_template Error
			return
		}

		set bet_type  [db_get_col $rs 0 bet_type]

		db_close $rs
	}



	switch -- $bet_type {
		"XGAM" {
			## find out if we want a receipt for a bet or sub
			## default is sub
			set betorsub [reqGetArg betorsub]
			if {$betorsub == ""} {
				set betorsub "sub"
			}
			if {[OT_CfgGet HAS_XGAMES 0] == 0} {
				# Shouldn't happen unless the db is buggered
				ob::log::write ERROR {Trying to generate external game receipt without external games tables !!!}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			if {$betorsub == "sub"} {
				if {[setup_acct_xgame_sub_rcpt $bet_id $acct_id] == 0} {
					ob::log::write INFO {Could not generate receipt for external game sub $bet_id}
					err_add [ml_printf ACCT_NO_SUB_DATA]
					play_template Error
					return
				}

				if {$template != ""} {
					play_template $template
				} else {
					play_template XGameSubReceipt
				}
			} else {
				if {[setup_acct_xgame_rcpt $bet_id $acct_id] == 0} {
					ob::log::write INFO {Could not generate receipt for external game $bet_id}
					err_add [ml_printf ACCT_NO_BET_DETS]
					play_template Error
					return
				}
				if {$template != ""} {
					play_template $template
				} else {
					play_template XGameBetReceipt
				  }
			  }
		}


		"MAN"  {
			if {[setup_acct_man_bet_rcpt $bet_id $acct_id] == 0} {
				ob::log::write INFO {Could not generate receipt for bet $bet_id}
				err_add [ml_printf ACCT_NO_BET_DETS]
				play_template Error
				return
			}
			if {$template != ""} {
				play_template $template
			} else {
				play_template ManBetReceipt
			}
		}

		"TPB"  {

			if {[setup_pools_rcpt $bet_id $acct_id] == 0} {
				ob::log::write INFO {Could not generate pools receipt for id $bet_id}
				err_add [ml_printf ACCT_NO_BET_DETS]
				play_template Error
				return
			}

			if {$template != ""} {
				play_template $template
			} else {
				play_template PoolsBetReceipt
			}
		}
		"IBS"  {

			if {[setup_acct_balls_sub_rcpt $bet_id $acct_id] == 0} {
				ob::log::write INFO {Could not generate pools receipt for id $bet_id}
				err_add [ml_printf ACCT_NO_BET_DETS]
				play_template Error
				return
			}

			if {$template != ""} {
				play_template $template
			} else {
				play_template BallsSubReceipt
			}
		}
		"IBP"  {
			if {[setup_acct_balls_payout_rcpt $bet_id $acct_id] == 0} {
				ob::log::write INFO {Could not generate pools receipt for id $bet_id}
				err_add [ml_printf ACCT_NO_BET_DETS]
				play_template Error
				return
			}

			if {$template != ""} {
				play_template $template
			} else {
				play_template BallsPayoutReceipt
			}
		}
		default {

			if {[setup_acct_bet_rcpt $bet_id $acct_id] == 0} {
				ob::log::write INFO {Could not generate receipt for id $bet_id}
				err_add [ml_printf ACCT_NO_BET_DETS]
				play_template Error
				return
			}

			if {$template != ""} {
				play_template $template
			} else {
				play_template BetReceipt
			}
		}
	}

	catch {unset BSEL}
}

##############################################################################
# Procedure :   print_channel
# Description : print_channel: outputs the message code for the channel.
#               If the channel is Elite then just telebetting is returned so
#               The customers status is not displayed
# Input :       code:       Message code i.e CUST_ACCT_CHANNEL
#               aChannel :  The channel name
# Output :      Global array COUNTRIES populated with all countries.
# Author :      JDM 31-08-2001
##############################################################################
proc print_channel {code aChannel} {
	set lChannel [split $aChannel " "]
	set tmp         ""
	foreach x $lChannel {
		append tmp $x
	}
	set channel [string toupper $tmp]
	if {[string compare -nocase -length 5 $channel "ELITE"]==0} {
		set channel "TELEBET"
	}
	return [ml_printf ${code}_$channel]
}

#
#   Displays the details of an igf game.
#
proc go_igf_game_details {} {

	global DB LOGIN_DETAILS

	set cg_game_id [reqGetArg id]
	set acct_id $LOGIN_DETAILS(ACCT_ID)

	set rs ""

	if {[catch {set rs [db_exec_qry igf_game_details_stmt $cg_game_id $acct_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve IGF game $cg_game_id $acct_id: $msg"
		return
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR "Could not find IGF game: $cg_game_id $acct_id"
		return
	}

	set cg_game_id [db_get_col $rs 0 cg_game_id]
	set game_desc [db_get_col $rs 0 game_desc]
	set game_class [db_get_col $rs 0 game_class]
	set source [db_get_col $rs 0 source]
	set started [db_get_col $rs 0 started]
	set stakes [db_get_col $rs 0 stakes]
	set winnings [db_get_col $rs 0 winnings]
	set drawn [db_get_col $rs 0 drawn]

	db_close $rs

	tpSetVar GAME_DESC $game_desc
	tpSetVar GAME_CLASS $game_class

	tpBindString CG_GAME_ID $cg_game_id
	tpBindString GAME_DESC [XL "|IGF_[string toupper $game_desc]|"]
	tpBindString GAME_CLASS [XL "|IGF_[string toupper $game_class]|"]
	tpBindString SOURCE [print_channel CUST_ACCT_CHANNEL $source]
	tpBindString STARTED [html_date $started]
	tpBindString STAKES [print_ccy $stakes]
	tpBindString WINNINGS [print_ccy $winnings]

	if {$game_class == "GBet"} {
		#Collision between IGF_LUCKYSTAR_1 as both a selection and
		#a game type - use IGF_LUCKYSTAR_SELN_1 for the selection.
		if {$game_desc == "LuckyStar"} {
			set drawn [XL "|IGF_[string toupper $game_desc]_SELN_${drawn}|"]
		} else {
			set drawn [XL "|IGF_[string toupper $game_desc]_${drawn}|"]
		}

	} elseif {$game_class == "Keno" || $game_class == "Bingo"} {

		if {[catch {set rs [db_exec_qry igf_keno_details_stmt $cg_game_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve game details $cg_game_id: $msg"
			return
		} else {

			if {[db_get_nrows $rs] != 1} {
				ob::log::write ERROR "Could not find game: $cg_game_id"
				return
			}

			set selected [db_get_col $rs 0 selected]
			set drawn [db_get_col $rs 0 drawn]
			set matches [db_get_col $rs 0 matches]

			#Bold the selected numbers in the draw
			set selected_list [split $selected ","]
			set drawn_list [split $drawn ","]

			for {set i 0} {$i < [llength $drawn_list]} {incr i} {
				if {[lsearch $selected_list [lindex $drawn_list $i]] != -1} {
					set drawn_list [lreplace $drawn_list $i $i\
										"<b>[lindex $drawn_list $i]</b>"]
				}
			}

			#Insert a line break after every eight fields
			#so we don't blow out the formatting with a long
			#draw or selection.
			#Otherwise comma delimited.
			for {set i 0} {$i < [llength $drawn_list]} {incr i} {

				if {$i == [expr {[llength $drawn_list] - 1}]} {
					continue
				} elseif {($i != 0) && ([expr {$i % 8}] == 0)} {
					set drawn_list [lreplace $drawn_list $i $i "[lindex $drawn_list $i],<br>"]
				} else {
					set drawn_list [lreplace $drawn_list $i $i "[lindex $drawn_list $i], "]
				}

			}
			for {set i 0} {$i < [llength $selected_list]} {incr i} {

				if {$i == [expr {[llength $selected_list] - 1}]} {
					continue
				} elseif {($i != 0) && ([expr {$i % 8}] == 0)} {
					set selected_list [lreplace $selected_list $i $i "[lindex $selected_list $i],<br>"]
				} else {
					set selected_list [lreplace $selected_list $i $i "[lindex $selected_list $i], "]
				}

			}

			set drawn [join $drawn_list ""]
			set selected [join $selected_list ""]

			tpBindString MATCHES $matches
			tpBindString SELECTED $selected

		}

	} elseif {$game_class == "MLSlot"} {

		if {[catch {set rs [db_exec_qry igf_mlslot_details_stmt $cg_game_id \
								$acct_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve IGF game $cg_game_id $acct_id: $msg"
			return
		}

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find IGF game: $cg_game_id $acct_id"
			return
		}

		set version         [db_get_col $rs 0 version]
		set cg_id           [db_get_col $rs 0 cg_id]
		set stop            [split [db_get_col $rs 0 stop] "|"]
		set symbols         [split [db_get_col $rs 0 symbols] "|"]
		set view_size       [db_get_col $rs 0 view_size]
		set total_win_lines [db_get_col $rs 0 total_win_lines]

		db_close $rs

		if {[catch {set rs [db_exec_qry get_reel_positions $cg_id $version]} ]} {
			ob_log::write ERROR {Failed to retrieve reel information}
			return
		}

		set nrows [db_get_nrows $rs]
		set reel_state ""

		for {set i 0} {$i < $nrows} {incr i} {
			set reel [split [db_get_col $rs $i reel] "|"]
			if {$reel_state != ""} {
				append reel_state ", "
			}
			append reel_state [lindex $symbols [lindex $reel [lindex $stop $i]]]
		}

		set drawn $reel_state

		db_close $rs

	} else {

		set drawn "-"

	}

	tpBindString DRAWN $drawn

	play_template IGFReceipt

}



proc go_acct_xgame_rcpt {{template ""}} {

	global BSEL PLATFORM LOGIN_DETAILS

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set id      [reqGetArg bet_id]
	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if {[setup_acct_xgame_rcpt $id $acct_id] == 0} {
		ob::log::write INFO {Could not generate receipt for external game $id}
		err_add [ml_printf ACCT_NO_BET_DETS]
		play_template Error
		return
	}

	if {$template != ""} {
		play_template $template
	} else {
		play_template XGameBetReceipt
	}

	catch {unset BSEL}
}



# ======================================================================
# go to change password screen
# ======================================================================

proc go_acct_pwd args {

	global USER_ID

	tpBindString ISPWD _on
	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	if [catch {set rs [db_exec_qry get_acctno $USER_ID]} msg] {
		ob::log::write ERROR {unable to retrieve customer $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	if {[db_get_nrows $rs] == 1} {
		tpBindString acct_no [db_get_col $rs acct_no]
		play_template Password
	} else {
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
	}
	db_close $rs

}


# ======================================================================
# go to deposit limits screen
# ======================================================================

proc go_dep_limits args {

	global USER_ID

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	if [catch {set rs [db_exec_qry get_acctno $USER_ID]} msg] {
		ob::log::write ERROR {unable to retrieve customer $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	# N.B. This file seems to generally only be setup for Credit/Debit card
	# payments, hence passing through CC to the bind_limit_details procedure.
	# This would need to be made dynamic if this were ever to handle other
	# payment methods.
	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS 0]} {
		OB_srp::bind_limit_details $USER_ID "CC"
		play_template DepositLimits
	}
	db_close $rs

}



# ----------------------------------------------------------------------
# update dep limits
# ----------------------------------------------------------------------

proc upd_dep_limits args {

	global USER_ID

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	if { [reqGetArg dep_limit_curr] != "-1"} {
		set dep_amt [reqGetArg dep_limit_amt]
		if { [reqGetArg dep_limit_period] == "0"} {
			set dep_period "1"
		} else {
			set dep_period "7"
		}
		if {![OB_srp::insert_update_cust_dep_limit $USER_ID \
		$dep_amt $dep_period "" "" $USER_ID ""]} {
		err_add [ml_printf ACCT_DEP_LIMIT_FAILED]
		play_template Error
		return
		} else {
			tpBindString result [ml_printf ACCT_DEP_LIMIT_OK]
			tpSetVar ResultType AcctUpdDetails
			play_template Result
		}
	} else {
		err_add [ml_printf ACCT_DEP_LIMIT_FAILED]
		play_template Error
		return
	}
}


# ----------------------------------------------------------------------
# change the user password, the password in the cookie must be
# updated otherwise they will be logged out on the next request
# ----------------------------------------------------------------------

proc upd_acct_pwd args {

	global USERNAME USER_ID
	global LOGIN_DETAILS

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set old_pwd [reqGetArg OldPwd]
	set new_pwd [reqGetArg NewPwd1]

	if {$new_pwd != [reqGetArg NewPwd2]} {
		err_add [ml_printf ACCT_PWD_NO_MATCH]
		go_acct_pwd
		return
	}

	if {$new_pwd == $USERNAME} {
		err_add [ml_printf ACCT_PWD_EQ_UNAME]
		go_acct_pwd
		return
	}

	# encrypt passwords
	set old_pwd [encrypt_password $old_pwd $LOGIN_DETAILS(PASSWORD_SALT)]
	set new_pwd [encrypt_password $new_pwd $LOGIN_DETAILS(PASSWORD_SALT)]


	# authentication check
	if [catch {set rs [db_exec_qry user_auth $LOGIN_DETAILS(USERNAME) $old_pwd]} msg] {
		ob::log::write ERROR {failed to run query: $msg}
		err_add [ml_printf ACCT_FAIL_AUTH]
		go_acct_pwd
		return
	}


	set nrows [db_get_nrows $rs]
	if {$nrows!=1} {
		err_add [ml_printf ACCT_PWD_WRONG]
		go_acct_pwd
		return
	} else {
		# update password
		if [catch {set rs [db_exec_qry upd_pwd $LOGIN_DETAILS(USERNAME) $old_pwd $new_pwd]} msg] {
			ob::log::write ERROR {failed to run query: $msg}
			err_add [ml_printf ACCT_PWD_CHNGD_FAIL]
			go_acct_pwd
			return
		}


		tpBindString result [ml_printf ACCT_PWD_CHNGD_OK]

		#remember to redo cookie!!!!

		if {$LOGIN_DETAILS(LOGIN_TYPE) == "PASSWD"} {

			set_cookie [OB_login::make_login_cookie "PASSWD $LOGIN_DETAILS(USERNAME) $new_pwd"]
		}
	}

	tpSetVar ResultType AcctUpdPasswd
	tpSetVar SUCCESS Y
	play_template Result
}





# ======================================================================
# Go to the Deposit/Withdrawal screens
# ======================================================================

proc go_acct_txn type {

	global USER_ID LOGIN_DETAILS
	variable HTML_CHARS_PREF

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	#
	# grab card details
	#
	array set CARD ""
	card_util::cd_get_active $LOGIN_DETAILS(USER_ID) CARD

	if {$CARD(card_available) == "Y"} {
		if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
			if [catch {set rs [db_exec_qry get_card_type $CARD(card_bin) $CARD(card_bin)]} msg] {
				ob::log::write ERROR {Unable to retrieve card type: $msg}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			if {[db_get_nrows $rs] != 1} {
				ob::log::write ERROR {Card type query returned [db_get_nrows $rs] rows}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			tpBindString card_type [db_get_col $rs scheme_name]
			db_close $rs

			if [catch {set rs [db_exec_qry get_card_scheme $CARD(card_bin)]} msg] {
				ob::log::write ERROR {Card scheme query returned [db_get_nrows $rs] rows}
				err_add [ml_printf ACCT_NO_ACCT_DATA]
				play_template Error
				return
			}
			set issue_length [db_get_col $rs 0 issue_length]
			if {$issue_length > 0 && $CARD(issue_no) == ""} {
				tpSetVar ISSUE_REQUIRED Y
				tpBindString ISSUE_LENGTH $issue_length
			}
			set start_date [db_get_col $rs 0 start_date]
			if {$start_date == "Y" && $CARD(start) == ""} {
				tpSetVar START_DATE_REQUIRED Y
				tpBindString START_DATE_REQUIRED Y
			}
			db_close $rs
		}

		set prev_pmts [card_util::cd_check_prev_pmt $LOGIN_DETAILS(USER_ID) $CARD(card_no)]

		if {$prev_pmts} {
			tpSetVar HaveCard 1
			tpBindString card_no      $CARD(card_no_XXX)
			tpBindString start_date   $CARD(start)
			tpBindString expiry_date  $CARD(expiry)
			tpBindString issue_no     $CARD(issue_no)

		} else {
			tpSetVar HaveCard 0
		}

	} else {
		tpSetVar HaveCard 0
	}

	store_txn_limits

	tpSetVar type $type
	if {$type == "DEP"} {
		tpBindString ISDEP _on
		tpBindString txn_type "DEP"
		tpBindString txn_title [ml_printf ACCT_L_ACCT_DEP]
		tpBindString balance [print_ccy [get_balance]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
	} elseif {$type == "WTD"} {
		tpBindString ISWTD _on
		tpBindString txn_type "WTD"
		tpBindString txn_title [ml_printf ACCT_L_ACCT_WTH]
		tpBindString balance [print_ccy [get_balance nowtd]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
	} elseif {$type == "TFR"} {
		tpBindString ISTFR _on
		tpBindString txn_type "TFR"
		tpBindString txn_title [ml_printf ACCT_L_ACCT_TFR]
		tpBindString balance [print_ccy [get_balance nowtd]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
	} else {
		err_add [ml_printf ACCT_NO_FUND_XFER]
		ob::log::write ERROR {Invalid type passed to go_acct_txn}
		play_template Error
		return
	}

	tpBindString ccy_code $LOGIN_DETAILS(CCY_CODE)

	play_template Txn
}


proc store_txn_limits {} {

	global USER_ID LOGIN_DETAILS
	variable HTML_CHARS_PREF

	if [catch {set rs [db_exec_qry get_txn_limits $USER_ID]} msg] {
		ob::log::write ERROR {failed to get txn limits: $msg}
		return

	}

	set nrows [db_get_nrows $rs]

	if {$nrows ==1} {
		set min_dep [print_ccy [db_get_col $rs min_dep] $LOGIN_DETAILS(CCY_CODE)\
				$HTML_CHARS_PREF]
		tpBindString min_dep $min_dep
		set max_dep [print_ccy [db_get_col $rs max_dep] $LOGIN_DETAILS(CCY_CODE)\
				$HTML_CHARS_PREF]
		tpBindString max_dep $max_dep
		tpBindString dep_blurb [ml_printf MY_ACC_TRANS_DEP_BLURB $min_dep $max_dep]
		set bal_wtd [db_get_col $rs bal_wtd]
		set min_wtd\
				[print_ccy [min $bal_wtd [db_get_col $rs min_wtd]]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		tpBindString min_wtd $min_wtd
		set max_wtd\
				[print_ccy [min $bal_wtd [db_get_col $rs max_wtd]]\
				$LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
		tpBindString max_wtd $max_wtd

		tpBindString wtd_blurb [ml_printf MY_ACC_TRANS_WTD_BLURB $min_wtd $max_wtd]
	}

	db_close $rs
}


# ----------------------------------------------------------------------
# process a deposit or withdrawal
# all the actual payment code resides in payment.tcl
# ----------------------------------------------------------------------

proc do_acct_txn {{play_page 1}} {

	global LOGIN_DETAILS
	variable HTML_CHARS_PREF
	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set login_type $LOGIN_DETAILS(LOGIN_TYPE)
	switch -- $login_type {
		"W" -
		"PASSWD" {set auth_val [reqGetArg password]}
		"N" -
		"PIN"    {set auth_val [reqGetArg pin]}
		default  {set auth_val ""}
	}
	set type    [reqGetArg type]
	set cust_id $LOGIN_DETAILS(USER_ID)

	# check password
	if {[payment_CC::cc_pmt_auth_user $cust_id $login_type $auth_val] != 1} {
		err_add [ml_printf PMT_PWD]
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	}

	# check amount is valid
	set amount  [reqGetArg amount]

	if {![regexp {^([0-9]*)(\.([0-9]([0-9])?))?$} $amount] || [string trim $amount] == ""} {
		err_add [ml_printf PMT_AMNT]
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	}

	# if card number not in html, attempt to register new pay method
	set card_no  [reqGetArg card_no]
	set expiry   [reqGetArg expiry]
	set start    [reqGetArg start]
	set issue_no [reqGetArg issue_no]

	#remove spaces in card no. etc
	foreach v {card_no expiry start issue_no} {
		regsub -all " " [set $v] "" $v
	}

	#check card only consists of number characters
	if {(![regexp {XXXXXX} $card_no]) && ![regexp {^([0-9]*)$} $card_no]} {
		err_add [ml_printf PMT_CARD]
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	}

	reqSetArg card_no $card_no

	# check card expiry

	if {$expiry != ""} {
		if {![check_card_expiry $expiry]} {
			err_add [ml_printf PMT_EXPR]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}
		}
	}

	# check card start
	if {$start != ""} {
		if {![check_card_start $start]} {
			err_add [ml_printf PMT_STRT]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}
		}
	} elseif {[reqGetArg start_date_required] == "Y"} {
		err_add [ml_printf PMT_STRT]
		tpSetVar START_DATE_REQUIRED Y
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	  }


	# issue no.
	if {$issue_no != ""} {
		if {![regexp {^[0-9]+$} $issue_no]}  {
			err_add [ml_printf PMT_ISSUE]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				retuen FAILED
			}
		}
	}

	if {([reqGetArg issue_length_required] != "") && ([reqGetArg issue_length_required] != [string length [reqGetArg issue_no]])} {
		err_add [ml_printf PMT_ISSUE]
		tpSetVar ISSUE_REQUIRED Y
		tpBindString ISSUE_LENGTH [reqGetArg issue_length_required]
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	  }

	# check we have one of...
	if {$start == "" && $expiry == "" && $issue_no == ""} {
		err_add [ml_printf PMT_EXPR]
		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}
	}

	# attempt to get the active card

	card_util::cd_get_active $LOGIN_DETAILS(USER_ID) CARD


	set cvv2 [reqGetArg cvv2]
	# cvv2 may or may not be required, so don't try to validate it here
	# it is handled in the payment code


	if {$card_no != "" && (![regexp {XXXXXX} $card_no])} {
		# User has entered a card number

		OT_LogWrite 8 "User has provided a card number"

		# Check if fraud screen functionality is required
		if {[OT_CfgGet FRAUD_SCREEN 0] != 0} {

			# Fraud check:
			# - store card registration attempt in tcardreg
			# - check for tumbling and swapping (10 channels)
			# - IP address monitoring (internet only)
			# - compare address country, currency country
			# 	and ip country with card country (internet only)
			OT_LogWrite 10 "fraud check"
			set fraud_monitor_details [fraud_check::screen_customer $LOGIN_DETAILS(USER_ID) [OT_CfgGet CHANNEL "I"] $type $amount]
			if {[llength $fraud_monitor_details] > 1} {
				eval [concat fraud_check::send_ticker $fraud_monitor_details]
			}

		}

		if {$CARD(card_available) == "Y"} {

			if {[card_util::cd_check_prev_pmt $LOGIN_DETAILS(USER_ID) $CARD(card_no)]} {
				# Shouldn't be able to change card details
				# on a previously valid card
				err_add [ml_printf PMT_ERR]
				if {$play_page} {
					go_acct_txn $type
					return
				} else {
					return FAILED
				}
			} else {
				# If no valid payments were made with this CPM
				# remove it to allow new registration
				card_util::cd_delete_card $LOGIN_DETAILS(USER_ID) $CARD(card_no)
			}

		}

		# check card registered against another customer
		if {![card_util::verify_card_not_used $card_no $cust_id]} {
			err_add [ml_printf PMT_USED]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}
		}

		# check card has not been explicitly unblocked
		if {![card_util::verify_card_not_blocked $card_no -1]} {
			err_add [ml_printf PMT_CC_BLOCKED]
			if {$play_page} {
	  			go_acct_txn $type
	  			return
			} else {
				return FAILED
			}
		}


		#
		# add new pay method
		#
		set result [card_util::cd_reg_card $cust_id]


		if {[lindex $result 0] == 0} {

			# failed to register new card..
			ob::log::write INFO {register card error [lindex $result 2]}
			err_add [ml_printf [lindex $result 2]]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}
		}

		set cpm_id [lindex $result 1]
		ob::log::write INFO {registered card (cpm_id = $cpm_id)}

	} else {

		# User has not entered a card number

		if {$CARD(card_available) == "N"} {
			err_add [ml_printf PMT_CARD]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}
		}

		set cpm_id  $CARD(cpm_id)
		set card_no $CARD(card_no)

		reqSetArg card_no $card_no

		# check updates
		set result [card_util::verify_cust_card_update $cust_id]
		if {[lindex $result 0] == 0} {
			#
			# error details are invalid
			#
			ob::log::write ERROR {error checking to see if card has been updated [lindex $result 2]}
			err_add [ml_printf [lindex $result 2]]
			if {$play_page} {
				go_acct_txn $type
				return
			} else {
				return FAILED
			}

		} elseif {[lindex $result 0] == 1} {
			#
			# details have changed - re-register this card
			#
			set result [card_util::cd_replace_card $cust_id $card_no]
			if {[lindex $result 0] == 0} {
				ob::log::write ERROR {could not delete card method [lindex $result 2]}
				err_add [ml_printf [lindex $result 2]]
				if {$play_page} {
					go_acct_txn $type
					return
				} else {
					return FAILED
				}
			}

			set cpm_id [lindex $result 1]

		} else {
			#
			# details haven't changes
			#
		}
	}

	if {$type == "DEP"} {
		set payment_sort "D"
	} else {
		set payment_sort "W"
	}

	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS 0]} {
		if {$type == "DEP"} {
			if {[lindex [ob_srp::check_deposit $cust_id $amount] 0] != 1} {
				err_add [ml_printf ACCT_DEP_LIMIT_REACHED]
				if {$play_page} {
					go_acct_txn $type
					return
				} else {
					return FAILED
				}
			}
		}
	}


	# Make the payment
	set result [payment_CC::cc_pmt_make_payment $LOGIN_DETAILS(ACCT_ID) \
											"" \
											[reqGetArg uniqueId] \
											$payment_sort \
											$amount \
											$cpm_id \
											[OT_CfgGet CHANNEL "I"] \
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
											$LOGIN_DETAILS(CNTRY_CODE)]

	if {[lindex $result 0] != 1} {

		if {[OT_CfgGet FUNC_OVS_CHK_DOB_EXISTS 0]} {
			if {[lindex $result 2] == "ACCT_NO_OVS_DOB"} {
				err_add [ml_printf [lindex $result 2]]
				go_acct_detail
				return
			}
		}

		#
		# failure
		#
		tpBindString card_no        $card_no
		tpBindString start_date 	$start
		tpBindString expiry_date 	$expiry
		tpBindString issue_no 		$issue_no
		tpBindString amount 		$amount

		ob::log::write ERROR {Failed to make payment: [lindex $result 2]}

		err_add [ml_printf [lindex $result 2]]

		tpBindString ACC_BAL [print_ccy [get_balance] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]

		if {$play_page} {
			go_acct_txn $type
			return
		} else {
			return FAILED
		}

	}

	#
	# success
	#
	tpBindString ACC_BAL [print_ccy [get_balance] $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
	tpBindString amount [print_ccy $amount $LOGIN_DETAILS(CCY_CODE) $HTML_CHARS_PREF]
	ob::log::write INFO {============ PMT_MSG = [lindex $result 2]}
	tpBindString PMT_MESSAGE [lindex $result 2]
	tpSetVar type $type
	tpSetVar ResultType AcctTxn

	if {$play_page} {
		play_template Result
	} else {
		return SUCCESS
	}
}


# ======================================================================
# The customer can change registration details such as
# address etc. through the change details page
# ======================================================================

proc go_acct_detail {} {

	global USER_ID

	tpBindString ISDETAIL _on

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	if [catch {set rs [db_exec_qry get_reg_detail $USER_ID]} msg] {
		ob::log::write ERROR {unable to retreive customer $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		tpBindString EXPIRED_SESSION "1"
		play_template Error
		return
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {customer data query returned [db_get_nrows $rs] rows}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	# If the user has typed in a value, submitted the form
	# and the update failed (eg wrong password) then populate
	# with the value the user typed in. Failing that get the value
	# out the database.
	foreach v {fname lname addr_1 addr_2 addr_3 addr_4 city
		pcode telephone mobile email itv_email sig_date} {
		if {[reqGetArg $v]!=""} {
		tpBindString $v [reqGetArg $v]
		} else {
		tpBindString $v [db_get_col $rs $v]
		}
	}

	if {[db_get_col $rs contact_ok] == "Y"} {
		tpBindString contactOK_checked checked
	} else {
		tpBindString contactOK_notchecked checked
	}

	# Get user PRICE_TYPE pref
	set price_type [reqGetArg tbPriceType]

	if {$price_type==""} {
		set price_type [OB_prefs::get_pref PRICE_TYPE]
	}

	if {$price_type == "DECIMAL"} {
		tpBindString PriceTypeDEC "checked"
	} else {
	 	tpBindString PriceTypeODDS "checked"
	}

	play_template PersInfo
}


# ----------------------------------------------------------------------
# update registration details the values are passed to a function
# in register.tcl to be validated and inserted
# ----------------------------------------------------------------------
proc upd_acct_detail {} {

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set CUST_DETAIL(TITLE)      	[reqGetArg title]
	set CUST_DETAIL(FNAME)      	[reqGetArg fname]
	set CUST_DETAIL(LNAME)      	[reqGetArg lname]
	set CUST_DETAIL(ADDR_1)     	[reqGetArg addr_1]
	set CUST_DETAIL(ADDR_2)     	[reqGetArg addr_2]
	set CUST_DETAIL(ADDR_3)     	[reqGetArg addr_3]
	set CUST_DETAIL(ADDR_4)     	[reqGetArg addr_4]
	set CUST_DETAIL(ADDR_CTY)   	[reqGetArg city]
	set CUST_DETAIL(ADDR_PC)    	[reqGetArg pcode]
	set CUST_DETAIL(TELEPHONE)  	[reqGetArg telephone]
	set CUST_DETAIL(MOBILE)  		[reqGetArg mobile]
	set CUST_DETAIL(EMAIL)      	[reqGetArg email]
	set CUST_DETAIL(ITV_EMAIL)  	[reqGetArg itv_email]
	set CUST_DETAIL(CONTACT_OK) 	[reqGetArg contact_ok]
	set CUST_DETAIL(CONTACT_MOB_OK) [reqGetArg contact_mob_ok]
	set CUST_DETAIL(SIG_DATE)   	[reqGetArg sig_date]
	set CUST_DETAIL(PASSWORD)   	[reqGetArg password]
	set CUST_DETAIL(PIN)			[reqGetArg pin]
	set CUST_DETAIL(PRICE_TYPE)		[reqGetArg tbPriceType]
	if {[OT_CfgGet FUNC_OVS_CHK_DOB_EXISTS 0]} {
		if {[reqGetArg ovs_get_cust_dob] == 1} {
			set CUST_DETAIL(DOBYEAR) [reqGetArg tbDOBYear]
			set CUST_DETAIL(DOBMONTH) [reqGetArg tbDOBMonth]
			set CUST_DETAIL(DOBDAY) [reqGetArg tbDOBDay]
		}
	}


	if {![do_update_details CUST_DETAIL]} {
		# error: replay account details screen with bound errors
		if {[OT_CfgGet FUNC_OVS_CHK_DOB_EXISTS 0]} {
			if {[reqGetArg ovs_get_cust_dob] == 1} {
				tpSetVar OVSGetCustDOB 1
			}
		}
		go_acct_detail
		return
	}

	tpBindString result [ml_printf ACCT_PERS_DETS_UPD_OK]
	tpSetVar ResultType AcctUpdDetails
	play_template Result
}


proc go_acct_pin {} {

	global USER_ID

	tpBindString ISPIN _on

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	if [catch {set rs [db_exec_qry get_acctno $USER_ID]} msg] {
		ob::log::write ERROR {unable to retrieve customer $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	if {[db_get_nrows $rs] == 1} {
		set dob [db_get_col $rs dob]
		tpBindString acct_no [db_get_col $rs acct_no]
		tpBindString dob     [html_date $dob shrtday]
		if {$dob != ""} {
			tpSetVar ShowSigdate 0

			foreach {year mon day} [split $dob "-"] {

				if {![chk_dob $day $mon $year]} {
					tpSetVar ShowSigdate 1
				}
			}

		} else {
			tpSetVar ShowSigdate 1
		}
		play_template PIN
	} else {
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
	}
	db_close $rs

}

proc upd_acct_pin {{need_dob Y}} {

	global LOGIN_DETAILS
	variable BADPINS

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	set acct_no  $LOGIN_DETAILS(ACCT_NO)
	set old_pin  [reqGetArg old_pin]
	set passwd   [reqGetArg password]
	set pin_1    [reqGetArg pin_1]
	set pin_2    [reqGetArg pin_2]
	set pin_min	 [reqGetArg pin_min]
	set pin_max	 [reqGetArg pin_max]
	set dob      [reqGetArg dob]

	# use default values for pin min & max length if null
	if {$pin_min == ""} {
		set pin_min 4
	}

	if {$pin_max == ""} {
		set pin_max 4
	}


	if {$pin_1 != $pin_2} {
		err_add [ml_printf ACCT_PIN_NO_MATCH]
		go_acct_pin
		return
	}

	if {$pin_1 == ""} {
		err_add [ml_printf ACCT_PIN_ENTER]
		go_acct_pin
		return
	}

	if {![regexp {^[0-9]*$} $pin_1]} {
		err_add [ml_printf ACCT_PIN_ONLY_NUMS]
		go_acct_pin
		return
	}

	if {[lsearch $BADPINS $pin_1] >= 0} {
		err_add [ml_printf ACCT_PIN_INVLD_PIN]
		go_acct_pin
		return
	}

	if {$need_dob == "Y"} {
		set reg {^([0-3][0-9])\/([0-1][0-9])\/([0-2][0-9][0-9][0-9])$}
		if {![regexp $reg $dob junk day mon year]} {
			err_add [ml_printf ACCT_DOB_ENTER]
			go_acct_pin
			return
		}

		if {![chk_dob $day $mon $year]} {
			err_add [ml_printf ACCT_DOB_INVLD]
			go_acct_pin
			return
		}

		set dob "${year}-${mon}-${day}"
	}

	if {$LOGIN_DETAILS(LOGIN_TYPE) == "PIN" && $old_pin == ""} {
		err_add [ml_printf ACCT_PIN_CONF_OLD]
		go_acct_pin
		return
	}

	if {$LOGIN_DETAILS(LOGIN_TYPE) == "PASSWD" && $passwd == ""} {
		err_add [ml_printf CUST_ACCT_CONF_PWD]
		go_acct_pin
		return
	}

	if {$passwd != ""} {
		set passwd [encrypt_password $passwd $LOGIN_DETAILS(PASSWORD_SALT)]
	}

	# If we are using acct_no/pin encryption, encrypt pin
	if {[OT_CfgGet ENCRYPT_PIN 0] != 0} {
		set old_pin [encrypt_pin $old_pin]
		set pin_1 [encrypt_pin $pin_1]
	}

	if [catch {set rs [db_exec_qry upd_pin $acct_no $old_pin $passwd $pin_1 $dob $pin_min $pin_max]} msg] {
		ob::log::write ERROR {failed to update pin $msg}
		err_add [ml_printf ACCT_PIN_UPD_FAIL]
		go_acct_pin
		return
	}

	if {$LOGIN_DETAILS(LOGIN_TYPE) == "PIN"} {

		set_cookie [OB_login::make_login_cookie [list PIN $LOGIN_DETAILS(ACCT_NO) $pin_1 $dob]]
	}

	tpSetVar type PIN
	tpSetVar ResultType AcctUpdPIN
	play_template Result
	return
}

proc chk_dob {day mon year} {

	set day [string trimleft $day 0]
	set mon [string trimleft $mon 0]

	if {$mon > 12} {
		return 0
	}

	set dim [days_in_month $mon $year]
	if {$day > $dim} {
		return 0
	}

	set now [clock format [clock seconds] -format "%Y-%m-%d"]
	set dob "[expr {$year + 18}]-[format %02d $mon]-[format %02d $day]"
	if {$dob > $now} {
		return 0
	}

	return 1
}


proc get_bad_pins args {

	variable BADPINS

	for { set index 0 } { $index < 9 } { incr index } {
		set same ""
		set ascending ""
		set descending ""

		for { set i 0 } { $i < 4 } { incr i } {
			set same "$same$index"
			set ascending "$ascending[ expr {($index + $i) % 10}]"
			set descending "$descending[ expr {($index - $i) % 10}]"
		}

		lappend BADPINS $same $ascending $descending
	}
}

#
# Display customer's Freebets offers and tokens
#
proc go_acct_freebets {} {
	global LOGIN_DETAILS rs_list

	if {[ob_is_guest_user]} {
		play_template Guest
		return
	}

	# Grab current affiliate from cookie
	set aff_id [get_cookie AFF_ID]

	# Retrieve and bind up offers and tokens
	set rs_list [get_cust_freebets $LOGIN_DETAILS(USER_ID) $aff_id]

	# Play template
	play_template FreeBetOffers

	# Close result sets, if we have any.
	if {$rs_list != 0} {
		foreach rs $rs_list {
			db_close $rs
		}
	}
}

proc go_balls_hist {start end {actually_play_file Y}} {

	global LOGIN_DETAILS BALLS_BET

	set bets_per_page 10.0

	if {[ob_is_guest_user] || ![info exists LOGIN_DETAILS(ACCT_ID)]} {
		play_template Guest
		return
	}

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if {[catch {
		set rs [db_exec_qry acct_balls_bets $acct_id $start $end]
	} msg]} {
		ob::log::write ERROR {Failed to retreive balls history: $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	array set BALLS_BET [list]

	set nrows [db_get_nrows $rs]
	for {set r 0} {$r < $nrows} {incr r} {

		set BALLS_BET($r,sub_id)  [db_get_col $rs $r sub_id]
		set BALLS_BET($r,fgame)   [db_get_col $rs $r firstdrw_id]
		set BALLS_BET($r,desc)    [db_get_col $rs $r desc]
		set BALLS_BET($r,stake)   [print_ccy [db_get_col $rs $r stake]]
		set BALLS_BET($r,returns) [db_get_col $rs $r returns]
		set BALLS_BET($r,ndrw)    [db_get_col $rs $r ndrw]
		set BALLS_BET($r,seln)    [db_get_col $rs $r seln]

		set date [db_get_col $rs $r cr_date]
		set BALLS_BET($r,date) [html_date $date shrtday]
		set BALLS_BET($r,date2digityear) [html_date $date shrtday2digityear]

	}

	db_close $rs

	set BALLS_BET(num_bets) $nrows

	tpBindVar BetId            BALLS_BET sub_id  sub_idx
	tpBindVar BallsFirstGame   BALLS_BET fgame   sub_idx
	tpBindVar BallsDesc        BALLS_BET desc    sub_idx
	tpBindVar BallsStake       BALLS_BET stake   sub_idx
	tpBindVar BallsReturns     BALLS_BET returns sub_idx
	tpBindVar BallsNumDraw     BALLS_BET ndrw    sub_idx
	tpBindVar BallsSeln        BALLS_BET seln    sub_idx

	if {[OT_CfgGet NET_BALLS_AVAILABLE 0]==1} {

		tpBindVar TXN_DATE         BALLS_BET date    tx_idx
		tpBindVar TXN_DATE_2_DIGIT_YEAR \
							       BALLS_BET date2digityear tx_idx
		tpBindVar TXN_DESC         BALLS_BET desc    tx_idx
		tpBindVar TXN_AMNT         BALLS_BET stake   tx_idx
	}
	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	tpSetVar ThisPage $page
	tpSetVar NumBets   [min [expr {$bets_per_page * ($page + 1)}] $nrows]
	tpSetVar NumPages [expr {ceil((double($nrows))/$bets_per_page)}]
	tpSetVar StartIdx [expr {$bets_per_page * $page}]
	tpSetVar NumBetRows [expr {$nrows - 1}]
	tpSetVar TotalNumBetRows $nrows

	if { $actually_play_file == "Y" } {
		play_template BallsHist

		unset BALLS_BET
	}
}

proc go_ix_hist {start end {actually_play_file Y}} {

	global LOGIN_DETAILS IX_HIST

	set bets_per_page 10.0

	if {[ob_is_guest_user] || ![info exists LOGIN_DETAILS(ACCT_ID)]} {
		play_template Guest
		return
	}

	set acct_id $LOGIN_DETAILS(ACCT_ID)

	if {[catch {
		set rs [db_exec_qry acct_ix_hist $start $end $acct_id \
					$start $end $acct_id $start $end $acct_id \
					$start $end $acct_id]
	} msg]} {
		ob::log::write ERROR {Failed to retreive index trade history: $msg}
		err_add [ml_printf ACCT_NO_ACCT_DATA]
		play_template Error
		return
	}

	array set IX_HIST [list]

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach col $colnames {
			set IX_HIST($r,$col) [db_get_col $rs $r $col]
		}
		set cr_date [db_get_col $rs cr_date]
		set IX_HIST($r,date) [html_date $cr_date shrtday]
		set IX_HIST($r,date2digityear) [html_date $cr_date shrtday2digityear]
	}

	db_close $rs

	set IX_HIST(num_bets) $nrows

	tpBindVar BetDate          IX_HIST date       txn_idx
	tpBindVar TranId           IX_HIST id         txn_idx
	tpBindVar MktName          IX_HIST f_mkt_name txn_idx
	tpBindVar Side             IX_HIST side       txn_idx
	tpBindVar Quantity         IX_HIST quantity   txn_idx
	tpBindVar Price            IX_HIST price      txn_idx
	tpBindVar Charge           IX_HIST charge     txn_idx
	tpBindVar Commission       IX_HIST commission txn_idx

	tpBindVar Desc             IX_HIST trans_type txn_idx
	tpBindVar Amount           IX_HIST amount     txn_idx

	set page [reqGetArg page]
	if {$page == ""} {
		set page 0
	}
	tpSetVar ThisPage $page
	tpSetVar NumBets   [min [expr {$bets_per_page * ($page + 1)}] $nrows]
	tpSetVar NumPages [expr {ceil((double($nrows))/$bets_per_page)}]
	tpSetVar StartIdx [expr {$bets_per_page * $page}]
	tpSetVar NumBetRows [expr {$nrows - 1}]
	tpSetVar TotalNumBetRows $nrows

	if { $actually_play_file == "Y" } {
		play_template IxHist

		unset IX_HIST
	}
}


proc check_ls_payout {drw_id} {

}

#
#	Quick proc to return the new balls status from its code. Might need some ml_printing for other customers!
#

proc get_status {status} {

	switch -exact -- $status {
		O 		{return "Open"}
		C 		{return "Closed"}
		V 		{return "Void"}
		default	{return $status}
	}

}

proc detailed_cv2_check {cvv2} {

		if {$cvv2 == ""} {
			return [ml_printf PMT_CV2_NULL]
		} else {
			return [ml_printf PMT_CV2_INVALID_CHAR]
		}
}


# close namespace
}


