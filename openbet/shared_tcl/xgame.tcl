#$Id: xgame.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $

# ==============================================================
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================


# What the new error codes should effectively translate to in txlateval (English)
#
#
#
#	XG_PB_ERROR_NO_GAME_DETS (**)	{Failed to place bet.  Failed to retrieve game details.}
#	XG_PB_ERROR_NO_GAMES_FOR	{Failed to place bet.  There are currently no games set up for %s %s.}
#   XG_PB_ERROR_NO_OPTION	 (**)	{Failed to place bet.  Failed to retrieve game option details for game %s.}
#	LOGIN_NO_LOGIN			{You are not currently logged-in, please log in now or click <i>OPEN ACCOUNT</i> to open an account with us}
#	XG_PB_GAME_OPTION_SUSP 		{Failed to place bet.  Bet has not been placed.  Game option has been suspended. Please select another game option.}
#	XG_PB_ERROR_NO_STK_FOR 		{Failed to place bet.  Could not retrieve stake for %s.}
#	XG_PB_ERROR_INVALID_STK 	{Failed to place bet.  Invalid stake entered.}
#	XG_PB_ERROR_STK_LOW		{Failed to place bet.  Invalid stake: Minimum stake is %s.}
#	XG_PB_ERROR_STK_HIGH		{Failed to place bet.  Invalid stake: Maximum stake is %s.}
#	XG_PB_ERROR_PMT_FUND			{You do not have sufficient funds in your account}
#	XG_PB_ERROR_INACTIVE_GAME	{No longer accepting bets for this game.}
#	XG_PB_ERROR_INTERNAL $sort	{Failed to place bet on game %s.  An internal error has occurred. Please try again later.}
#
#		May not want to show customer some of these messages (**) .....In such cases, substitute with
#		 a standard error message....logging the real error message

#	XG_ERROR_NO_GAME_DETS
#	XG_ERROR_NO_BALLS
#	XG_ERROR_NO_GAMES_FOR

package require util_appcontrol


namespace eval OB_xgame {

namespace export init_xgame

namespace export ob_get_balls_for_xgame
namespace export ob_get_xgame_for_sort
namespace export ob_get_xgame_stk_for_sort
namespace export go_next_xgame
namespace export set_xgame_template
namespace export xgame_place_bet
namespace export retrieve_exchange_rate
namespace export bind_draw_desc
namespace export xgame_go_lotto
namespace export xgame_go_lotto_sort

variable XGAME_TEMPLATE
variable MAIN_URL
variable CFG

array set XGAME_TEMPLATE [list\
	Guest	      	guest.html\
	Error	      	betslip_err.html\
	GamePlay	play.html\
	Receipt         betslip_receipt_lotto.html]

set MAIN_URL "go_xgame_home"

if {[OT_CfgGet XGAME_RECEIPT_FUNC 0]} {
	set CFG(receipt_format) [OT_CfgGet BET_RECEIPT_FORMAT 0]
	set CFG(receipt_tag)    [OT_CfgGet BET_RECEIPT_TAG ""]
} else {
	set CFG(receipt_format) 0
	set CFG(receipt_tag)    ""
}

proc init_xgame {} {

	prep_xgame_qrys
}

proc prep_xgame_qrys {} {


	# General queries for xgames copied from footballcomp.tcl

	db_store_qry xgame_sub_rcpt {
		select  c.username,
			r.fname,
			r.lname,
			r.email,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			gd.sort,
			gd.name,
			s.stake_per_bet,
			s.num_subs,
			s.free_subs,
			g.draw_at,
			g.wed_sat,
			s.cr_date,
			s.xgame_sub_id,
			s.picks,
			s.draws
		from    tXGameDef gd,
			tXGame g,
			tXGameSub s,
			tCustomerReg r,
			tAcct a,
			tCustomer c

		where
				gd.sort = g.sort
		and	g.xgame_id = s.xgame_id
		and     s.acct_id = a.acct_id
		and     a.cust_id = c.cust_id
		and     c.cust_id = r.cust_id
		and	s.xgame_sub_id = ?

		order by g.draw_at,s.xgame_sub_id

	}

	db_store_qry get_drawdesc_info {
		select
			desc,
			name,
			day
		from
			txgamedrawdesc
		where
			desc_id = ?
	} 100

	db_store_qry get_stake_conversion {
		select
			round_exch_rate
		from
			tXGameRoundCCY
		where
			ccy_code like ?

	} 100

	db_store_qry get_tCCY_exchange {
		select
			exch_rate
		from
			tCCY
		where
			ccy_code like ?

	}  100

	db_store_qry place_bet {
		EXECUTE PROCEDURE pInsXGameBet2 (
						p_xgame_id=?,
						p_bet_type=?,
						p_ipaddr=?,
						p_acct_id=?,
						p_stake_per_bet=?,
						p_stake_per_line=?,
						p_picks=?,
						p_num_selns=?,
						p_num_lines=?,
						p_num_subs=?,
						p_sub_wed_sat=?,
						p_sub_draws=?,
						p_source=?,
						p_aff_id=?,
						p_free_subs=?,
						p_token_value=?,
						p_transactional=?,
						p_unique_id=?,
						p_call_id=?,
						p_placed_by=?,
						p_slip_id=?,
						p_prices=?,
						p_locale=?,
						p_rep_code=?,
						p_on_course_type=?,
						p_receipt_format=?,
						p_receipt_tag=?
						)
	}

	db_store_qry place_bet_no_sub {
		EXECUTE PROCEDURE pInsXGameBetNoSub (
						p_xgame_id=?,
						p_bet_type=?,
						p_sub_id=?,
						p_acct_id=?,
						p_stake_per_bet=?,
						p_stake_per_line=?,
						p_picks=?,
						p_num_selns=?,
						p_num_lines=?,
						p_num_subs=?,
						p_sub_wed_sat=?,
						p_sub_draws=?,
						p_source=?,
						p_aff_id=?,
						p_free_subs=?,
						p_token_value=?,
						p_transactional=?,
						p_unique_id=?,
						p_call_id=?,
						p_placed_by=?,
						p_slip_id=?,
						p_complete=?,
						p_prices=?,
						p_locale=?,
						p_rep_code=?,
						p_on_course_type=?
						)
	}

	db_store_qry get_xgame_for_sort {
		select nvl(g.desc, gd.desc) as desc,
			misc_desc,
			g.xgame_id,
			gd.name,
			g.comp_no,
			gd.num_picks_max,
			gd.num_picks_min,
			gd.conf_needed,
			gd.has_balls,
			gd.num_min,
			gd.num_max,
			g.open_at,
			g.shut_at,
			g.draw_at,
			op.option_id,
			gd.coupon_max_lines,
			gd.stake_mode,
			gd.min_stake,
			gd.max_stake,
			gd.max_subs,
			gd.min_subs,
			gd.flag_gif
		from
			tXGame g,
			tXGameDef gd,
			outer tXGameOption op
		where gd.sort = g.sort AND
			g.sort = op.sort AND
			g.sort = ? AND
			g.status = 'A' AND
			g.open_at < CURRENT AND
			g.shut_at > CURRENT AND
			(
			g.wed_sat in (?,?)
			or g.wed_sat is null
			)
		order by
			g.draw_at
	}

	db_store_qry get_all_xgame {
		select nvl(g.desc, gd.desc) as desc,
			misc_desc,
			g.xgame_id,
			g.sort,
			gd.name,
			g.open_at,
			g.shut_at,
			g.draw_at,
			gd.result_url,
			gd.rules_url,
			gd.flag_gif,
			gr.day,
			gr.default_shut_at,
			gr.default_draw_at,
			nvl(gr.shut_day, gr.day) as shut_day
		from
			tXGame g,
			tXGameDef gd,
			tXGameDrawDesc gr
		where gd.sort = g.sort AND
			g.status = 'A' AND
			g.open_at < CURRENT AND
			g.draw_at > CURRENT AND
			(
			g.wed_sat in (?,?)
			or g.wed_sat is null
			) AND
			g.draw_desc_id = gr.desc_id
		order by
			g.sort,
			gr.default_shut_at,
			gr.default_draw_at,
			shut_day

	}

	db_store_qry get_balls_for_xgame {
		select
		xgame_ball_id,
		ball_no,
		ball_name
		from tXGameBall
		where
		xgame_id = ?
		ORDER BY
		ball_no
	}

	db_store_qry get_balls_for_sort {
		select
		xgame_ball_id,
		ball_no,
		ball_name
		FROM tXGameBall
		WHERE
		sort = ?
		ORDER BY
		ball_no
	}

	db_store_qry get_xgame_stk_for_sort {
		select stake
		from   tXGameDefStake
		where  sort = ?
	}


	# get price also
	# if option-id known then price is dynamic
	# need to check for price change
	db_store_qry option_detail {
		select
		option_id,
		sort,
		num_picks,
		status
		from tXGameOption op
		where
			op.option_id = ?
	}

	#
	# retrieves current valid option price for game
	# able to check game price

	db_store_qry option_price_details {
		select
		op.option_id,
		op.sort,
		op.num_picks,
		op.status,
		pr.price_num,
		pr.price_den
		from tXGameOption op,
			 tXGamePrice pr,
			 tXGameDef d
		where
			op.option_id = ?
		and	op.sort = d.sort
		and	op.sort = pr.sort
		and	(pr.num_picks = op.num_picks or pr.num_picks is null)
	}

	db_store_qry get_xgame_prices {
		select
			p.num_picks,
			p.num_correct,
			p.price_num,
			p.price_den,
			b.min_combi,
			b.max_combi
		from
			tXGamePrice p,
			tXGameBetType b
		where
			b.bet_type = ?
			and p.sort = ?
			and (p.valid_from <= CURRENT or p.valid_from is null)
			and (CURRENT < p.valid_to or p.valid_to is null)
			and p.num_picks = b.num_selns
			and p.num_correct <= b.max_combi
			and p.num_correct >= b.min_combi
		order by p.num_correct
	}


	db_store_qry get_xgame_acc_prices {
		select
			p.num_picks,
			p.num_correct,
			p.price_num,
			p.price_den,
			b.min_combi,
			b.max_combi
		from
			tXGamePrice p,
			tXGameBetType b
		where
			b.bet_type = ?
			and p.sort = ?
			and (p.valid_from <= CURRENT or p.valid_from is null)
			and (CURRENT < p.valid_to or p.valid_to is null)
			and p.num_correct = p.num_picks
			and p.num_correct = b.max_combi
			and p.num_correct = b.min_combi
		order by p.num_correct
	}

	db_store_qry get_xgame_old_prices {
		select
			p.num_picks,
			p.num_correct,
			p.price_num,
			p.price_den,
			b.min_combi,
			b.max_combi
		from
			tXGamePrice p,
			tXGameBetType b
		where
			b.bet_type = ?
			and p.sort = ?
			and (p.valid_from <= ? or p.valid_from is null)
			and (? < p.valid_to or p.valid_to is null)
			and p.num_picks = b.num_selns
			and p.num_correct <= b.max_combi
			and p.num_correct >= b.min_combi
		order by p.num_correct
	}


	db_store_qry get_xgame_acc_old_prices {
		select
			p.num_picks,
			p.num_correct,
			p.price_num,
			p.price_den,
			b.min_combi,
			b.max_combi
		from
			tXGamePrice p,
			tXGameBetType b
		where
			b.bet_type = ?
			and p.sort = ?
			and (p.valid_from <= ? or p.valid_from is null)
			and (? < p.valid_to or p.valid_to is null)
			and p.num_picks = b.num_selns
			and p.num_correct <= b.max_combi
			and p.num_correct >= b.min_combi
		order by p.num_correct
	}


	db_store_qry get_bet_type_by_selns {
		select bet_type
		from   tXGameBetType
		where  num_selns = ?
			and min_combi = max_combi
			and min_combi = num_selns
	}

	db_store_qry check_if_external {
		select external_settle
		from   tXGameDef
		where  sort = ?
			and external_settle = 'Y'
	}

	if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

		#Query used to work out the number of bets placed - used for first bet triggers.
		db_store_qry xgame_bet_count {
			select count(*) as total
			from tXGameSub
			where acct_id = ?
		}
	}

	db_store_qry xgame_detail {
		select
		gd.sort,
		name,
		g.comp_no,
		num_picks_max,
		num_picks_min,
		conf_needed,
		has_balls,
		wed_sat,
		num_min,
		num_max,
		min_stake,
		max_stake,
		stake_mode,
		min_subs,
		max_subs,
		nvl(g.desc,gd.desc) as desc,
		misc_desc,
		nvl(m.min_bet, -1) as bet_type_min_stake,
		nvl(m.max_bet, -1) as bet_type_max_stake
		from
		tXGameDef gd,
		tXGame    g,
		outer txgameminmax m
		where
		gd.sort = g.sort
		and m.sort = gd.sort
		and g.xgame_id = ?
		and m.bet_type = ?

	}


	db_store_qry xgame_detail_option {
		select
		gd.sort,
		name,
		g.comp_no,
		g.status as game_status,
		num_picks_max,
		num_picks_min,
		conf_needed,
		has_balls,
		wed_sat,
		num_min,
		num_max,
		min_stake,
		max_stake,
		stake_mode,
		min_subs,
		max_subs,
		nvl(g.desc,gd.desc) as desc,
		misc_desc,
		nvl(o.option_id, -1) as option_id,
		nvl(o.status, "S") as option_status,
		nvl(m.min_bet, -1) as bet_type_min_stake,
		nvl(m.max_bet, -1) as bet_type_max_stake
		from
		tXGameDef gd,
		tXGame    g,
		outer tXGameOption o,
		outer txgameminmax m
		where
		gd.sort = g.sort
		and o.sort = gd.sort
		and m.sort = gd.sort
		and g.status = "A"
		and g.open_at < CURRENT
		and g.shut_at > CURRENT
		and o.num_picks = ?
		and g.xgame_id = ?
		and m.bet_type = ?

	}

	db_store_qry xgame_detail_option_old {
		select
		gd.sort,
		name,
		g.comp_no,
		g.status as game_status,
		num_picks_max,
		num_picks_min,
		conf_needed,
		has_balls,
		wed_sat,
		num_min,
		num_max,
		min_stake,
		max_stake,
		stake_mode,
		min_subs,
		max_subs,
		nvl(g.desc,gd.desc) as desc,
		misc_desc,
		nvl(o.option_id, -1) as option_id,
		nvl(o.status, "S") as option_status,
		nvl(m.min_bet, -1) as bet_type_min_stake,
		nvl(m.max_bet, -1) as bet_type_max_stake
		from
		tXGameDef gd,
		tXGame    g,
		outer tXGameOption o,
		outer txgameminmax m
		where
		gd.sort = g.sort
		and o.sort = gd.sort
		and m.sort = gd.sort
		and g.open_at > ?
		and g.shut_at < ?
		and o.num_picks = ?
		and g.xgame_id = ?
		and m.bet_type = ?
	}


	db_store_qry xgame_sub_detail {
		select
		name,
		s.cr_date as sub_cr_date,
		num_subs,
		xgame_sub_id,
		stake_per_bet,
		s.picks

		from tXGameSub s,
		tXGame g,
		tXGameDef gd
		where
		gd.sort = g.sort and
		g.xgame_id = s.xgame_id and
		xgame_sub_id = ? and
		s.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?)
	}

	db_store_qry xgame_bet_detail_for_sub {
		select
		xgame_bet_id,
		b.xgame_id,
		name,
		b.cr_date as bet_cr_date,
		stake,
		winnings,
		paymethod,
		refund,
		b.settled,
		b.picks,
		gd.sort,
		shut_at,
		draw_at,
		results
		from
		tXGameBet b,
		tXGameSub s,
		tXGame   g,
		tXGameDef gd
		where
		g.xgame_id = b.xgame_id
		and b.xgame_sub_id = s.xgame_sub_id
		and gd.sort = g.sort
		and s.xgame_sub_id = ?  and
		s.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?)
	}

	db_store_qry xgame_bet_detail {
		select
		xgame_bet_id,
		b.xgame_id,
		s.xgame_sub_id,
		num_subs,
		name,
		b.cr_date as bet_cr_date,
		stake,
		winnings,
		paymethod,
		refund,
		b.settled,
		b.picks,
		has_balls,
		gd.sort,
		shut_at,
		draw_at,
		results
		from
		tXGameBet b,
		tXGameSub s,
		tXGame   g,
		tXGameDef gd
		where
		g.xgame_id = b.xgame_id
		and b.xgame_sub_id = s.xgame_sub_id
		and gd.sort = g.sort
		and b.xgame_bet_id = ?  and
		s.acct_id = (select acct_id
				 from tAcct
				 where cust_id = ?)
	}

	db_store_qry get_results {
		select xgame_id,
		draw_at,
		results
		from tXGame
		where xgame_id = ?
		and results is not null
	}

	db_store_qry get_latest_results {
		select first 1
		xgame_id,
		draw_at,
		results
		from tXGame
		where sort like ?
		and results is not null
		order by draw_at desc
	}

	db_store_qry get_recent_results {
		select first 15
		xgame_id,
		desc,
		draw_at,
		results
		from tXGame
		where sort like ?
		and results is not null
		order by draw_at desc
	}

	db_store_qry get_dividends {
		select type, points, prizes from txgamedividend
		where xgame_id=?
		order by type, prizes desc
	}

	db_store_qry get_latest_dividends {
		select first 15 type, points, prizes, draw_at
		from txgame g,
		outer txgamedividend d
		where d.xgame_id = g.xgame_id
		and results is not null
		and sort like ?
		order by draw_at desc
	}

	db_store_qry get_recent_dividends {
		select first 15
		draw_at,
		results
		from tXGame
		where sort like ?
		and results is not null
		order by draw_at desc
	}

	db_store_qry xgame_bet_history {
		select
			'sub' type,
			xgame_sub_id id,
			s.cr_date,
			stake_per_bet as stake,
			sort,
			comp_no,
			0 as refund,
			0 as winnings,
			'-' as paymethod
		from
			txgamesub s,
			txgame g,
			tacct a
		where
			s.xgame_id = g.xgame_id
		and num_subs>1
		and s.cr_date between ? and ?
		and s.acct_id=a.acct_id
		and cust_id=?
		and s.status<>'V'

		union

		select
			'bet' type,
			xgame_bet_id id,
			b.cr_date,
			stake as stake,
			sort,
			comp_no,
			refund,
			winnings,
			paymethod
		from
			txgamebet b,
			txgamesub s,
			txgame g,
			tacct a
		where
			s.xgame_sub_id = b.xgame_sub_id
		and g.xgame_id = b.xgame_id
		and b.cr_date between ? and ?
		and s.acct_id=a.acct_id
		and cust_id=?
		order by 3 desc;
	}


	db_store_qry get_topspot_pictures {
		select pic_filename,
			   number,
			   small_pic_filename,
			   topspot_pic_id
		from   tTopSpotPic
		where xgame_id = ?
	}

	db_store_qry get_topspot_balls {
		select b.number as ball_number,
			   p.number as pic_number,
			   b.x,
			   b.y,
			   b.topspot_ball_id
		from
			 tTopSpotPic p,
			 tTopSpotBall b
		where
			 p.topspot_pic_id = b.topspot_pic_id
			 and p.xgame_id=?
	}

	db_store_qry get_username_password {
		select username, password from tcustomer
		where cust_id = ?
	}

	db_store_qry get_active_xgame_id {
		SELECT
		g.xgame_id,
		g.status

		FROM
		tXGame AS g,
		tXGameDef AS gd

		WHERE gd.sort = g.sort AND
		g.xgame_id = ? AND
		g.status = 'A' AND
		g.open_at < CURRENT AND
		g.shut_at > CURRENT
	}

	db_store_qry get_active_option_id {
		SELECT
		op.option_id,
		op.status

		FROM
		tXGameOption As op

		WHERE
			  op.option_id = ? AND
			  op.status = 'A'
	}

	db_store_qry xg_cust_lk {
		update
			tCustomer
		set
			bet_count = bet_count
		where
			cust_id = ?
	}

	db_store_qry get_balance {
		select balance, credit_limit, acct_type from tacct where acct_id=?
	}

	db_store_qry get_other_valid_xgames {
		select
			xgame_id,
			draw_at,
			draw_desc_id
		from
			txgame
		where
			draw_at > (select draw_at from txgame where xgame_id = ?)
			and status = "A"
		order by draw_at
	}

	db_store_qry get_sort_and_details {
		select
			x.sort,
			d.num_picks_max,
			x.draw_desc_id
		from
			txgame x,
			txgamedef d
		where
			xgame_id = ?
			and d.sort = x.sort
	}


}

proc xgame_go_lotto args {

	go_all_next_xgame "ANY" "chooselottery.html"

}

proc xgame_go_lotto_sort args {

	tpBindString ON_LOAD_CMD "onLoad=\"javascript:init();\""
	ukb_lotto::go_lotto

}

# ----------------------------------------------------------------------
# Override default templates to play
# ----------------------------------------------------------------------
proc set_xgame_template args {

	variable XGAME_TEMPLATE

	if {[llength $args] == 1} {
		return $XGAME_TEMPLATE([lindex $args 0])
	} elseif {[llength $args] == 2} {
		set XGAME_TEMPLATE([lindex $args 0]) [lindex $args 1]
	}
}

# ----------------------------------------------------------------------
# procedures to produce "Error" and "Guest" templates
# ----------------------------------------------------------------------
proc play_template {which} {

	variable XGAME_TEMPLATE

	ob::log::write DEV {Xgame: (XgamePlayFile=$which) $XGAME_TEMPLATE($which)}

	tpSetVar XgamePlayFile $which
	play_file $XGAME_TEMPLATE($which)
}

proc ob_get_balls_for_xgame xgame_id {

	if {[catch {set rs [db_exec_qry xgame_detail $xgame_id "SGL"]} msg]} {
		ob::log::write ERROR {ob_get_balls_for_xgame: $xgame_id error retrieving xgame detail: $msg}
		return [err_add [ml_printf XG_ERROR_NO_GAME_DETS]]
	}

	set has_balls [db_get_col $rs 0 has_balls]
	set sort      [db_get_col $rs 0 sort]

	db_close $rs

	if { $has_balls == "G" } {
		if {[catch {set rs [db_exec_qry get_balls_for_xgame $xgame_id]} msg]} {
			ob::log::write ERROR {ob_get_balls_for_xgame: $xgame_id error retrieving xgame balls: $msg}
			return [err_add [ml_printf XG_ERROR_NO_BALLS]]
		}
	} else {
		if {[catch {set rs [db_exec_qry get_balls_for_sort $sort]} msg]} {
			ob::log::write ERROR {ob_get_balls_for_xgame: $xgame_id error retrieving xgame balls: $msg}
			return [err_add [ml_printf XG_ERROR_NO_BALLS]]
		}

	}

	return $rs
}

proc ob_get_xgame_for_sort {sort wed_or_sat} {

	switch -- $wed_or_sat {
		"WED" {
			set ws1 "W"
			set ws2 "W"
		}
		"SAT" {
			set ws1 "S"
			set ws2 "S"
		}
		"ANY" {
			set ws1 "W"
			set ws2 "S"
		}
	}

	if {[catch {set rs [db_exec_qry get_xgame_for_sort\
				   $sort\
				   $ws1\
				   $ws2]} msg]} {
		ob::log::write ERROR {ob_get_xgame_for_sort: sort=$sort wed_or_sat=$wed_or_sat - Error retrieving xgame: $msg}
		return [err_add [ml_printf XG_ERROR_NO_GAMES_FOR $sort $wed_or_sat]]

	}
	if {[OT_CfgGet XG_GAME_OPTIONS 0] == 1} {
		set nrows [db_get_nrows $rs]
		if {$nrows > 0 && [db_get_col $rs 0 option_id]==""} {
			db_close $rs
			ob::log::write INFO {ob_get_xgame_for_sort: no game options found: sort=$sort wed_or_sat=$wed_or_sat}
			return [err_add [ml_printf XG_ERROR_NO_GAMES_FOR $sort $wed_or_sat]]		}
	}

	return $rs
}

proc ob_get_all_xgame {wed_or_sat} {

switch -- $wed_or_sat {
		"WED" {
			set ws1 "W"
			set ws2 "W"
		}
		"SAT" {
			set ws1 "S"
			set ws2 "S"
		}
		"ANY" {
			set ws1 "W"
			set ws2 "S"
		}
	}

	if {[catch {set rs [db_exec_qry get_all_xgame\
				   $ws1\
				   $ws2]} msg]} {
		ob::log::write ERROR {ob_get_all_xgame: wed_or_sat=$wed_or_sat - Error retrieving xgame: $msg}
		return [err_add [ml_printf XG_ERROR_NO_GAMES_FOR $wed_or_sat]]
	}

	db_close $rs
	return $rs
}

proc ob_get_xgame_stk_for_sort {sort} {

	if {[catch {set rs [db_exec_qry get_xgame_stk_for_sort $sort]} msg]} {

		ob::log::write ERROR {ob_get_xgame_stk_for_sort: $sort - Error retrieving stake for xgame: $msg}
		err_add [ml_printf XG_ERROR_NO_STK_FOR $sort]
		return ""
	}

	set nrows [db_get_nrows $rs]
	if {$nrows < 1} {
		db_close $rs
		err_add [ml_printf XG_ERROR_NO_STK_FOR $sort]
		return ""
	}

	set vals {}
	for {set r 0} {$r < $nrows} {incr r} {
		lappend vals [db_get_col $rs $r stake]
	}
	db_close $rs
	return $vals
}

proc go_next_xgame {sort wed_or_sat {gameplay ""} {receipt ""}} {

	# Allow setup of templates if passed in
	if {$gameplay != ""} {
		set_xgame_template GamePlay $gameplay
	}

	if {$receipt != ""} {
		set_xgame_template Receipt  $receipt
	}

	if {[bind_next_xgame_info $sort $wed_or_sat]!=0} {
		tpSetVar NO_NEXT_GAME 1
		play_template GamePlay
	} else {
		play_template GamePlay
	}

}

proc go_all_next_xgame {wed_or_sat {gameplay ""} {error ""} {receipt ""}} {

	# Allow setup of templates if passed in
	if {$gameplay != ""} {
		set_xgame_template GamePlay $gameplay
	}

	if {$error != ""} {
		set_xgame_template Error    $error
	}

	if {$receipt != ""} {
		set_xgame_template Receipt  $receipt
	}

	if {[bind_all_next_xgame_info $wed_or_sat]!=0} {
		play_template Error
	} else {
		play_template GamePlay
	}

}

proc bind_all_next_xgame_info {wed_or_sat} {

	global PLATFORM LOGIN_DETAILS XGAME_STAKES LOTTOS

	# Add platform stuff here
	if {[OT_CfgGet MULTI_PLATFORM 0]} {
		tpBindString PLATFORM $PLATFORM
	}

	# Get details of xgames
	set rs [ob_get_all_xgame $wed_or_sat]

	# Check at least one row and bind variables
	set nrows [db_get_nrows $rs]

	if {$nrows<1} {
		ob::log::write ERROR {There are $nrows games set up for $wed_or_sat.}
		err_add [ml_printf XG_ERROR_NO_GAMES_FOR ""]
		return -1
	}

	array set LOTTOS [list]

	set num_lottos 0
	for {set i 0} {$i < $nrows} {incr i} {

		set add_row 1

		if {$i > 0} {
			if {[db_get_col $rs $i sort] == $LOTTOS([expr $num_lottos-1],sort)} {
				set add_row 0
			}
		}

		if {$add_row} {

			set LOTTOS($num_lottos,xgame_id) [db_get_col $rs $i xgame_id]
			set LOTTOS($num_lottos,desc)      [db_get_col $rs $i desc]
			set LOTTOS($num_lottos,name)      [db_get_col $rs $i name]
			set LOTTOS($num_lottos,misc_desc) [db_get_col $rs $i misc_desc]
			set LOTTOS($num_lottos,sort)   [db_get_col $rs $i sort]
			set LOTTOS($num_lottos,result) [db_get_col $rs $i result_url]
			set LOTTOS($num_lottos,rules) [db_get_col $rs $i rules_url]
			set LOTTOS($num_lottos,flag_gif) [db_get_col $rs $i flag_gif]
			set LOTTOS($num_lottos,num_draws) 1
			set LOTTOS($num_lottos,0,default_shut_at) [db_get_col $rs $i default_shut_at]
			set LOTTOS($num_lottos,0,default_draw_at) [db_get_col $rs $i default_draw_at]
			set LOTTOS($num_lottos,0,day) [db_get_col $rs $i day]
			set LOTTOS($num_lottos,0,shut_day) [db_get_col $rs $i shut_day]
			set LOTTOS($num_lottos,dif_times) 0
			set LOTTOS($num_lottos,dif_days) 0

			incr num_lottos

		} else {

			set entry_pos [expr $num_lottos-1]

			set last_de_shut_at $LOTTOS($entry_pos,[expr $LOTTOS($entry_pos,num_draws)-1],default_shut_at)
			set last_de_draw_at $LOTTOS($entry_pos,[expr $LOTTOS($entry_pos,num_draws)-1],default_draw_at)

			set last_shut_day $LOTTOS($entry_pos,[expr $LOTTOS($entry_pos,num_draws)-1],shut_day)

			if {$last_de_shut_at == [db_get_col $rs $i default_shut_at] && $last_de_draw_at == [db_get_col $rs $i default_draw_at] && $last_shut_day == [db_get_col $rs $i shut_day]} {

			} else {

				set LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),default_shut_at) [db_get_col $rs $i default_shut_at]
				set LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),default_draw_at) [db_get_col $rs $i default_draw_at]
				set LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),day) [db_get_col $rs $i day]
				set LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),shut_day) [db_get_col $rs $i shut_day]

				if {$last_de_shut_at != $LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),default_shut_at) || $last_de_draw_at != $LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),default_draw_at)} {
					set LOTTOS($entry_pos,dif_times) 1
				}

				if {$last_shut_day != $LOTTOS($entry_pos,$LOTTOS($entry_pos,num_draws),shut_day)} {

					set LOTTOS($entry_pos,dif_days) 1
				}

				incr LOTTOS($entry_pos,num_draws)
			}
		}
	}

	tpSetVar NUM_LOTTOS        $num_lottos
	ob::log::write INFO "LOTTO -> Number of next lotto draws is: $num_lottos"

	tpBindVar XGAME_ID         	LOTTOS xgame_id           	lidx
	tpBindVar DESC           	  	LOTTOS desc                	lidx
	tpBindVar NAME           	  	LOTTOS name                	lidx
	tpBindVar MISC_DESC			LOTTOS misc_desc          	lidx
	tpBindVar COMP_NO       	   	LOTTOS comp_no            lidx
	tpBindVar SORT            		LOTTOS sort                	lidx
	tpBindVar RESULT           		LOTTOS result              	lidx
	tpBindVar RULES            		LOTTOS rules               	lidx
	tpBindVar FLAG_GIF         	LOTTOS flag_gif            	lidx
	tpBindVar NUM_DRAWS      	LOTTOS num_draws        lidx
	tpBindVar DEFAULT_SHUT   LOTTOS default_shut_at  lidx didx
	tpBindVar DEFAULT_DRAW LOTTOS default_draw_at  lidx didx
	tpBindVar DAY              		LOTTOS day                     lidx didx
	tpBindVar SHUT_DAY         	LOTTOS shut_day             lidx didx

	db_close $rs

	return 0


}

proc bind_next_xgame_info {sort wed_or_sat} {

	global PLATFORM LOGIN_DETAILS XGAME_STAKES LOGGED_IN


	# Add platform stuff here
	if {[OT_CfgGet MULTI_PLATFORM 0]} {
		tpBindString PLATFORM $PLATFORM
	}

	# Get details of xgames
	set rs [ob_get_xgame_for_sort $sort $wed_or_sat]

	# Check at least one row and bind variables
	set nrows [db_get_nrows $rs]

	if {$nrows<1} {
		ob::log::write ERROR {There are $nrows $sort games set up for $wed_or_sat.}
		err_add [ml_printf XG_ERROR_NO_GAMES_FOR $sort ""]
		return -1
	}


	set stake_mode [db_get_col $rs 0 stake_mode]

	if {$stake_mode=="D"} {
		# Set up stake per game for currency
		set stakes [ob_get_xgame_stk_for_sort $sort]
		ob::log::write DEV {bind_next_xgame_info: stakes=$stakes}

		if {[llength $stakes] < 1} {
			err_add [ml_printf XG_ERROR_NO_GAMES_FOR $sort ""]
			return -1
		}

		if {$LOGGED_IN} {
			if {[OT_CfgGet XG_MULTICURRENCY 0]==1} {
				set rate [round_rate $LOGIN_DETAILS(CCY_CODE)]
			} else {
				set rate [rate $LOGIN_DETAILS(CCY_CODE)]
			}
			set ss {}
			foreach s $stakes {
				lappend ss [format {%.2f} [expr {$s * $rate}]]
			}
			set stakes $ss
			ob::log::write DEV {bind_next_xgame_info: currency converted stakes=$stakes}
		}

		# create XGAME_STAKES array
		catch {unset XGAME_STAKES}
		set num_stakes [llength $stakes]
		for {set i 0} {$i < $num_stakes} {incr i} {
			set XGAME_STAKES($i,stake) [lindex $stakes $i]
		}

		tpSetVar NUM_XGAME_STAKES $num_stakes
		tpBindVar XGAME_STAKE XGAME_STAKES stake stake_idx
		tpBindString COST_PER_GAME     $XGAME_STAKES(0,stake)
		tpBindString COST_PER_GAME_OUT [print_ccy $XGAME_STAKES(0,stake)]

		tpBindString XGAME_MAX_STAKE  -1
		tpBindString XGAME_MIN_STAKE  -1

	} elseif {$stake_mode=="C"} {
		set max_stake [db_get_col $rs 0 max_stake]
		set min_stake [db_get_col $rs 0 min_stake]

		if {$LOGGED_IN} {
			if {[OT_CfgGet XG_MULTICURRENCY 0]==1} {
				set rate [round_rate $LOGIN_DETAILS(CCY_CODE)]
			} else {
				set rate [rate $LOGIN_DETAILS(CCY_CODE)]
			}
			set max_stake [format {%.2f} [expr {$max_stake * $rate}]]
			set min_stake [format {%.2f} [expr {$min_stake * $rate}]]
		}

		tpBindString XGAME_MAX_STAKE $max_stake
		tpSetVar XGAME_MAX_STAKE [print_ccy $max_stake DEFAULT 0]

		tpBindString XGAME_MIN_STAKE $min_stake
		tpSetVar XGAME_MIN_STAKE [print_ccy $min_stake DEFAULT 0]
	}

	if {[html_date [db_get_col $rs 0 draw_at] fullday] == [html_date [db_get_col $rs 0 shut_at] fullday]} {
		tpSetVar DIF_DAYS 0
	} else {
		tpSetVar DIF_DAYS 1
	}

	ob::log::write INFO "LOTTO xgame_id = [db_get_col $rs 0 xgame_id]"
	ob::log::write INFO "LOTTO shut_at = [html_date [db_get_col $rs 0 shut_at]]"
	ob::log::write INFO "LOTTO open_at = [html_date [db_get_col $rs 0 open_at]]"
	ob::log::write INFO "LOTTO draw_at = [html_date [db_get_col $rs 0 draw_at]]"

	tpBindString XGAME_ID  [db_get_col $rs 0 xgame_id]
	tpBindString FLAG_GIF  [db_get_col $rs 0 flag_gif]
	tpBindString NAME      [db_get_col $rs 0 name]
	tpBindString SHUT_AT   [html_date [db_get_col $rs 0 shut_at]]
	tpBindString SHUT_AT_TIME [html_date [db_get_col $rs 0 shut_at] hr_min]
	tpBindString OPEN_AT   [html_date [db_get_col $rs 0 open_at]]
	tpBindString DRAW_AT   [html_date [db_get_col $rs 0 draw_at] fullday]
	tpBindString DRAW_AT_TIME [html_date [db_get_col $rs 0 draw_at] hr_min]
	tpBindString DESC      [db_get_col $rs 0 desc]
	tpBindString MISC_DESC [db_get_col $rs 0 misc_desc]
	tpBindString COMP_NO   [db_get_col $rs 0 comp_no]

	tpBindString BALLS_MAX   [db_get_col $rs 0 num_max]
	tpBindString BALLS_MIN   [db_get_col $rs 0 num_min]
	tpBindString PICKS_MAX   [db_get_col $rs 0 num_picks_max]
	tpBindString PICKS_MIN   [db_get_col $rs 0 num_picks_min]
	tpBindString CPN_MAX_LINES [db_get_col $rs 0 coupon_max_lines]

	tpSetVar BALLS_MAX   [db_get_col $rs 0 num_max]
	tpSetVar BALLS_MIN   [db_get_col $rs 0 num_min]
	tpSetVar PICKS_MAX   [db_get_col $rs 0 num_picks_max]
	tpSetVar PICKS_MIN   [db_get_col $rs 0 num_picks_min]
	tpSetVar CPN_MAX_LINES [db_get_col $rs 0 coupon_max_lines]

	tpSetVar max_subs [db_get_col $rs 0 max_subs]

	tpSetVar min_subs [db_get_col $rs 0 min_subs]

	tpSetVar     SORT       $sort
	tpBindString     SORT       $sort
	tpSetVar     DRAW_DOW  [html_date [db_get_col $rs 0 draw_at] dayofweek]

	db_close $rs

	return 0

}

proc lot_validate_enc_string {sort xgame_id has_balls numpicks mypicks {min_ball 0} {max_ball 0}} {

	ob::log::write INFO {$mypicks}
	ob::log::write INFO {sort = $sort}
	ob::log::write INFO {xgame_id = $xgame_id}
	ob::log::write INFO {has_balls = $has_balls}
	ob::log::write INFO {numpicks = $numpicks}
	ob::log::write INFO {mypicks = $mypicks}
	ob::log::write INFO {min_ball = $min_ball}
	ob::log::write INFO {max_ball = $max_ball}

	set picks [list]
	foreach p [split $mypicks "|"] {
		ob::log::write INFO {pick is $p}
		lappend picks [string trim $p]
	}

	ob::log::write INFO {numpicks = $numpicks; [llength [split $mypicks |]]}
	
	if {[llength $picks] != [llength [lsort -unique $picks]]} {
		ob::log::write INFO {detected same pick twice: $picks}
		return 0
	}

	# Check balls are actually in the space of available balls
	if {$has_balls != "N"} {
		set rs    [ob_get_balls_for_xgame $xgame_id]
		set nrows [db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			set ball_no [db_get_col $rs $r ball_no]
			set ballfound($ball_no) 1
		}

		db_close $rs

		if {$sort == "GOALRUSH"} {
			# Handle special case for Goal Rush
			foreach p [split $mypicks "|"] {
				if {$ballfound([string index $p 0]) != 1} {
					return 0
				}
			}
		} else {
			foreach p [split $mypicks "|"] {
				if {$ballfound($p) != 1} {
					return 0
				}
			}
		}

	} else {
		foreach p [split $mypicks "|"] {
			if {[string first . $p] !=-1} {
				return 0
			}

			ob::log::write INFO {p=$p; min_ball=$min_ball max_ball=$max_ball}
			if { [expr "${p}.0 < ${min_ball}.0"] || [expr "${p}.0 > ${max_ball}.0"] } {
				return 0
			}
		}
	}

	if {$sort == "BIGMATCH"} {
		# Handle special case for Big Match
		foreach p {1 2 3 4 5} {
			set used_row($p) 0
		}
		foreach p [split $mypicks "|"] {
			set row [expr {$p / 10}]
			if {$used_row($row) != 0} {
				return 0
			}
			set used_row($row) 1
		}
	}

	return 1
}

proc xg_pb_start args {

	global USER_ID

	OB_db::db_begin_tran

	set rs [db_exec_qry xg_cust_lk $USER_ID]

	if {[db_garc xg_cust_lk] != 1} {
		error "failed to lock customer"
	}

	db_close $rs

}

proc validate_token {redeem_list} {
	set cust_token_ids [list]
	set token_value 0
	# Step thru list, creating a list of tokens and a total value
	for {set token 0} {$token < [llength $redeem_list]} {incr token} {

		array set token_info  [lindex $redeem_list $token]

		lappend cust_token_ids $token_info(id)

		set token_value [expr "$token_value + $token_info(redeemed_val)"]

		ob::log::write INFO {Token $token (id $token_info(id), value $token_info(redeemed_val))}
	}

	return  $token_value
}

#------------------------------------------------------------------------------
#	xgame_place_bet
#------------------------------------------------------------------------------
#
# Stake is either obtained from argument, or if stake_mode == 'D' from tXGameDefStake
# or if stake_mode = 'C' from request parameter stake_per_line
#
# The following validates request, input into table and returns receipt (if all is well).
#
#  If option_id="" then will be using dividends table, no need to check price etc...
# should maybe check some config file param?
# Should check price has not changed if price_num and price_den is not blank
# so at least will now price store is relevant...
#
#
#------------------------------------------------------------------------------
proc xgame_place_bet {{stake ""} {operator ""} {slip_id ""} {token_ids ""}} {

	global xgQRYS LOGIN_DETAILS USER_ID
	global PLATFORM
	global DB

	variable CFG

	#SGiles - i think this is no longer needed because, login check is done in ukb_lotto.tcl

	#if {[OB_login::ob_is_guest_user]} {
		#err_add [ml_printf LOGIN_NO_LOGIN]
		#tpSetVar ERROR_CODE "LOGIN_NO_LOGIN"
		#play_template Error
		#return
	#}

	#
	# Start place bet transaction and lock the customer's record
	#
	ob::log::write INFO {Starting xgame place bet transaction}

	set region_cookie [OB::AUTHENTICATE::retrieve_region_cookie]
	set allow_bet [OB::AUTHENTICATE::authenticate default [OT_CfgGet CHANNEL "I"] \
			$USER_ID x_bet 0 [reqGetEnv REMOTE_ADDR] $region_cookie "" "" "" "" "Y" [reqGetArg sort]]


	if {[lindex $allow_bet 0] != "S"} {
		# check channel
		if { [string trim [lindex [lindex $allow_bet 1] 0]] == "COUNTRY_CHAN_ALLOWED" } {
			xg_pb_err LOTTO_ERR_BET_AUTH_COUNTRY_BLOCKED_CHAN
		# check lottery
		} elseif { [string trim [lindex [lindex $allow_bet 1] 0]] == "COUNTRY_LOT_ALLOWED" } {
			xg_pb_err LOTTO_ERR_BET_AUTH_COUNTRY_BLOCKED_LOT
		# something else?
		} else {
			xg_pb_err [lindex [lindex $allow_bet 1] 2]
		}
		return
	}

	if {[catch {xg_pb_start} msg]} {
		xg_pb_err XG_PB_ERROR_INTERNAL
		return
	}

	# Get user's currency details and associated exchange rate
	set ccy_code $LOGIN_DETAILS(CCY_CODE)
	set exc_rate [retrieve_exchange_rate $ccy_code]
	if {$exc_rate==""} {
		xg_pb_err XG_PB_ERROR_INTERNAL
		return
	}

	set sort  [reqGetArg sort]
	set xgame_id  [reqGetArg xgame_id]
	set draws  [reqGetArg draws]
	set lines     [reqGetArg numLines]
	set option_id [reqGetArg option_id]
	set num_subs  [reqGetArg numComps]
	set free_subs [reqGetArg freeSubs]

	set max_subs 0
	set min_subs 0

	ob::log::write INFO {sort       = $sort}
	ob::log::write INFO {draws      = $draws}
	ob::log::write INFO {option_id  = $option_id}
	ob::log::write INFO {xgame_id   = $xgame_id}
	ob::log::write INFO {lines      = $lines}
	ob::log::write INFO {num_subs   = $num_subs}
	ob::log::write INFO {free_subs  = $free_subs}

	if {$free_subs==""} {
		set free_subs 0
	}

	set tot_num_subs [expr {$free_subs + $num_subs}]

	ob::log::write INFO {xgame_place_bet: xgame_id = $xgame_id lines=$lines tot_num_subs=$tot_num_subs num_subs=$num_subs free_subs=$free_subs}

	#	If using price table rather than dividends table,
	#	refer to both tXGameOption and tXGamePrice.
	#	Price is dynamic and can therefore change, option (ie: num picks) can
	#	also be suspended...must check for these..
	#	Price will be stored along with subscription....

	if {[OT_CfgGet XG_GAME_OPTIONS 0] == 1} {
		#
		#	check option still active
		#
		ob::log::write DEV {option_id = $option_id}

		if {$option_id == ""} {
			# error no option details given
			ob::log::write ERROR {xgame_place_bet: no option_id passed to place_bets: config file has XG_GAME_OPTIONS set}
			xg_pb_err XG_PB_ERROR_NO_OPTION $sort
			return
		}

		# gather option details
		if {[catch {set rs [db_exec_qry option_detail $option_id]} msg]} {
			ob::log::write ERROR {xgame_place_bet: failed to exec option detail: $msg}
			xg_pb_err XG_PB_ERROR_NO_OPTION $sort
			return
		}

		ob::log::write DEV {option_detail executed without failure}
		ob::log::write DEV {db_get_nrows [db_get_nrows $rs]}

		if {[db_get_nrows $rs] == 0} {
			db_close $rs
			ob::log::write ERROR {xgame_place_bet: no option details retrieved for option_id $options_id}
			xg_pb_err XG_PB_ERROR_NO_OPTION $sort
			return
		}

		# has game option been suspended?
		set npicks [db_get_col $rs 0 num_picks]
		set status [db_get_col $rs 0 status]
		db_close $rs

		if {$status == "S"} {
			ob::log::write ERROR {xgame_place_bet: game ($sort) option  ($option_id) suspended}
			xg_pb_err XG_PB_GAME_OPTION_SUSP $npicks
			return
		}
	}

	#
	#	Check game is still active
	#	and that game option is still active
	#	Again another new wee bit: games have options where
	#   option is num_picks user can select in a game
	#   (Rather than have game defs for each option).
	#

	# is game still active?
	if {[catch {set rs [db_exec_qry get_active_xgame_id $xgame_id]} msg]} {
		ob::log::write ERROR {$xgame_id is no longer active: $msg}
		xg_pb_err XG_PB_ERROR_INACTIVE_GAME
		return
	}
	set nrows [db_get_nrows $rs]
	db_close $rs
	if {$nrows==0} {
		ob::log::write ERROR {$xgame_id is no longer active}
		xg_pb_err XG_PB_ERROR_INACTIVE_GAME
		return
	}

	set game_draw ""

	if { $draws == ""} {
		ob::log::write INFO "LOTTO draws is blank using query to get draws"
		# Get Sort and max/min picks from the xgame_id
		if {[catch {set rs [db_exec_qry get_sort_and_details $xgame_id]} msg]} {
			ob::log::write ERROR {Cannot get details for $xgame_id: $msg}
			xg_pb_err XG_PB_ERROR_INTERNAL
			return
		}
		set nrows [db_get_nrows $rs]
		if {$nrows==0} {
			ob::log::write ERROR {Cannot find details for $xgame_id}
			xg_pb_err XG_PB_ERROR_INTERNAL
			return
		} else {
			set sort [db_get_col $rs 0 sort]
			set num_selns [db_get_col $rs 0 num_picks_max]

			# if game has a draw desc id but the bet doesnt we need it
			# passed on to the sub to make subs code and settlement work
			set game_draw [db_get_col $rs 0 draw_desc_id]

			ob::log::write INFO {infering draw desc if not passsd $game_draw}
		}
		db_close $rs
	}
	## Run through each line and generate the selections

	for {set l 1} {$l <= $lines} {incr l} {
		if {$game_draw == ""} {
			set selns_count_name sel_cnt_[expr $l-1]
			set num_selns [reqGetArg $selns_count_name]
		} else {
			set draws "|$game_draw|"
		}

		ob::log::write INFO "LOTTO xgame_place_bet -> draws = $draws"

		## Determine Bet type
		#
		# If more bet types (perms etc) are required for Internet lottery betting
		# then this will need to be updated, because it just won't work
		# If the xgame is settled externally then we don't really care about bet type
		# so we set all external bet types to EXT
		#

		if {[catch {set type_rs [db_exec_qry check_if_external $sort]} msg]} {
						ob::log::write ERROR {xgame_place_bet: failed to determine if external game: $msg}
						xg_pb_err XG_PB_ERROR_INTERNAL
						return
						}
		if { [db_get_nrows $type_rs] > 0 } {
			# This is an external bet
			set bet_type "EXT"
		} else {
			# This is internally settled so we need the correct bet type
			db_close $type_rs
			if {[catch {set type_rs [db_exec_qry get_bet_type_by_selns $num_selns]} msg]} {
				ob::log::write ERROR {xgame_place_bet: failed to exec get bet type: $msg}
				xg_pb_err XG_PB_ERROR_INTERNAL
				return
				}
			set bet_type [db_get_col $type_rs 0 bet_type]
		}
		db_close $type_rs

		if {[catch {set rs [db_exec_qry xgame_detail $xgame_id $bet_type]} msg]} {
			ob::log::write ERROR {xgame_place_bet: failed to exec xgame detail: $msg}
			xg_pb_err XG_PB_ERROR_NO_GAME_DETS
			return
		}
		ob::log::write DEBUG {xgame_detail executed with game_id $xgame_id   nrows = [db_get_nrows $rs]}

		set stake_mode [db_get_col $rs 0 stake_mode]
		set bet_type_min_stake [db_get_col $rs 0 bet_type_min_stake]
		if {$bet_type_min_stake == -1} {
			set min_stake [db_get_col $rs 0 min_stake]
		} else {
			set min_stake $bet_type_min_stake
		}
		set bet_type_max_stake [db_get_col $rs 0 bet_type_max_stake]
		if {$bet_type_max_stake == -1} {
			set max_stake [db_get_col $rs 0 max_stake]
		} else {
			set max_stake $bet_type_max_stake
		}

		set npicks     [db_get_col $rs 0 num_picks_max]
		set npicks_min [db_get_col $rs 0 num_picks_min]
		set hasballs   [db_get_col $rs 0 has_balls]
		set sort       [db_get_col $rs 0 sort]
		set num_min    [db_get_col $rs 0 num_min]
		set num_max    [db_get_col $rs 0 num_max]
		set wed_or_sat [db_get_col $rs 0 wed_sat]
		set max_subs	[db_get_col $rs 0 max_subs]
		set min_subs	[db_get_col $rs 0 min_subs]
		ob::log::write DEBUG {stake_mode = $stake_mode}
		ob::log::write DEBUG {npicks = $npicks}
		ob::log::write DEBUG {npicks_min = $npicks_min}
		ob::log::write DEBUG {hasballs = $hasballs}
		ob::log::write DEBUG {sort = $sort}
		ob::log::write DEBUG {num_min = $num_min}
		ob::log::write DEBUG {num_max = $num_max}
		ob::log::write DEBUG {wed_or_sat = $wed_or_sat}

		db_close $rs

		for {set i 1} {$i <= $num_selns} {incr i} {
			if {$i!=1} {
					append pick_$l "|"
			}
			set vname r$l
			append vname _$i
			set ball_number [reqGetArg $vname]
			append pick_$l $ball_number
		}

		set encstrings(prices,$l) [get_prices $bet_type $sort "" ""]

		set encstrings(sort,$l) $sort
		set encstrings(picks,$l) [set pick_$l]
		set encstrings(bet_type,$l) $bet_type
		set encstrings(min_stake,$l) $min_stake
		set encstrings(max_stake,$l) $max_stake

		# verify that the picks are in the correct format and no horseplay
		if {[lot_validate_enc_string $sort $xgame_id \
				$hasballs $npicks $encstrings(picks,$l) \
				$num_min $num_max] != 1} {

			ob::log::write ERROR {xgame_place_bet: **User trying to hack external game $sort with $encstrings(picks,$l)}
			xg_pb_err XG_PB_ERROR_INTERNAL $sort
			return
		}
	}

	set tokens_total_redeemed 0

	#	Now check stake
	#	Either read stake input from user
	#	or arg passed in and checked against DefStake table
	#	or first matching stake returned from DefStake table
	if {$stake_mode == "D"} {

		set stakes [ob_get_xgame_stk_for_sort $sort]
		if {[llength $stakes] < 1} {
			# No stakes set in db
			set stake -1
		} else {
			if {$stake == ""} {
				# Use first stake from tXGameDefStake
				set stake [lindex $stakes 0]
			} else {
				# Check that stake is in our list
				if {[lsearch -exact $stakes $stake] < 0} {
					# Stake is not in the db
					set stake -1
				}
			}
		}
		if {$stake == -1} {
			ob::log::write ERROR {xgame_place_bet: Couldn't get stake for $sort}
			xg_pb_err XG_PB_ERROR_NO_STK_FOR $sort
			return
		}

		if {$stake == 0} {
			ob::log::write ERROR {Invalid stake: $stake}
			xg_pb_err XG_PB_ERROR_INVALID_STK $stake
			return
		}

		# Convert the stake into the customer's currency
		ob::log::write DEBUG "xgame_place_bet: exchange_rate being used=$exc_rate"
		set stake [format {%.2f} [expr {$stake*$exc_rate}]]
		ob::log::write DEBUG "stake after exchange = $stake"

		# get stake details
		 if {$min_stake != "" && ([expr {$stake - ($min_stake * $exc_rate) + 0.00001}] < 0)} {
			ob::log::write ERROR {Invalid stake: Min stake is [print_ccy [expr {$min_stake*$exc_rate}] $ccy_code].}
			xg_pb_err XG_PB_ERROR_STK_LOW [print_ccy $min_stake $ccy_code]
			return
		 }


		if {$max_stake != ""} {
			set adjusted_max_stake [expr {$max_stake * $LOGIN_DETAILS(MAX_STAKE_SCALE)}]
		}

		if {$max_stake != "" && $stake > [expr {$adjusted_max_stake * $exc_rate}]} {
			ob::log::write ERROR {Invalid stake: Maximum stake is [print_ccy [expr {$adjusted_max_stake*$exc_rate}] $ccy_code].}
			xg_pb_err XG_PB_ERROR_STK_HIGH [print_ccy $adjusted_max_stake $ccy_code]
			return
		 }

		for {set l 1} {$l <= $lines} {incr l} {
			set encstrings(stake,$l) $stake

			if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

				set redeem_list [OB_freebets::validate_tokens $token_ids [list $xgame_id] $stake "XGAME"]

				set token_val [validate_token $redeem_list]

				set encstrings(token_val,$l) $token_val

				set encstrings(redeem_list,$l) $redeem_list

				if {[string length $token_val]>0} {
					set tokens_total_redeemed [expr $tokens_total_redeemed + $token_val]
				}

			} else {
				set encstrings(token_val,$l) 0
			}
		}

		set total_stake [expr {$stake * $lines}]

	} elseif {$stake_mode == "C"} {
		set total_stake 0
		for {set l 1} {$l <= $lines} {incr l} {

			set stake [reqGetArg rowpc_hidden_[expr $l-1]]
			set min_stake $encstrings(min_stake,$l)
			set max_stake $encstrings(max_stake,$l)

			if {$stake == -1} {
				ob::log::write ERROR {xgame_place_bet: Couldn't get stake for $sort}
				xg_pb_err XG_PB_ERROR_NO_STK_FOR $sort
				return
			}

			if {$stake == 0} {
				ob::log::write ERROR {Invalid stake: $stake}
				xg_pb_err XG_PB_ERROR_INVALID_STK $stake
				return
			}

			if {$min_stake != "" && $stake < [expr {$min_stake * $exc_rate}]} {
				ob::log::write ERROR {Invalid stake: Min stake is [print_ccy [expr {$min_stake*$exc_rate}] $ccy_code].}
				xg_pb_err XG_PB_ERROR_STK_LOW [print_ccy $min_stake $ccy_code]
				return
			}

			if {$max_stake != ""} {
				set adjusted_max_stake [expr {$max_stake * $LOGIN_DETAILS(MAX_STAKE_SCALE)}]
			}

			if {$max_stake != "" && $stake > [expr {$adjusted_max_stake * $exc_rate}]} {
				ob::log::write ERROR {Invalid stake: Maximum stake is [print_ccy [expr {$adjusted_max_stake*$exc_rate}] $ccy_code].}
				xg_pb_err XG_PB_ERROR_STK_HIGH [print_ccy $adjusted_max_stake $ccy_code]
				return
			}

			set encstrings(stake,$l) $stake
			set total_stake [expr {$stake + $total_stake}]

			if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

				set redeem_list [OB_freebets::validate_tokens $token_ids [list $xgame_id] $stake "XGAME"]

				set token_val [validate_token $redeem_list]

				set encstrings(token_val,$l) $token_val

				set encstrings(redeem_list,$l) $redeem_list

				if {[string length $token_val]>0} {
					set tokens_total_redeemed [expr $tokens_total_redeemed + $token_val]
				}
			} else {
				set encstrings(token_val,$l) 0
			}
		}
	}

	set total_stake [expr {$num_subs * $total_stake}]

	if {[catch {set rs [db_exec_qry get_balance $LOGIN_DETAILS(ACCT_ID)]} msg]} {
		ob::log::write ERROR {xgame_place_bet: failed to get balance: $msg}
		xg_pb_err XG_PB_ERROR_INTERNAL $sort
		return
	}
	set balance [db_get_col $rs 0 balance]
	set credit_limit [db_get_col $rs 0 credit_limit]
	set acct_type [db_get_col $rs 0 acct_type]
	db_close $rs

	if {$acct_type!="CDT"} {
		## not a credit account so reset the credit limit
		set credit_limit 0
	}

	# Soft credit limits
	set soft_credit_limit [expr {
		$acct_type != "CDT" ? 0.0 : (
			$credit_limit == "" ? "" : (
				$credit_limit * (
					[OT_CfgGet SOFT_CREDIT_LIMITS 0] ?
					(1.0 + [ob_control::get credit_limit_or] / 100.0) :
					1.0
				)
			)
		)
	}]

	if {$balance < [expr {$total_stake - $tokens_total_redeemed - $soft_credit_limit}]} {
		ob::log::write ERROR {xgame_place_bet: insufficient funds in account}
		xg_pb_err XG_PB_ERROR_PMT_FUND
		return
	}

	if {$tot_num_subs > $max_subs || $tot_num_subs < $min_subs} {
		ob::log::write ERROR {xgame_place_bet: subs ($tot_num_subs) not in range of $min_subs to $max_subs}
		xg_pb_err XG_SUBS_RANGE_ERR
		return
	}


	tpSetVar totalTokens $tokens_total_redeemed
	tpBindString TOTAL_TOKENS $tokens_total_redeemed

	#
	# Get the source and affilitate ID
	# Get source from config file: ie: CHANNEL
	#
	set source [OT_CfgGet CHANNEL "I"]

	set aff_id [get_cookie AFF_ID]
	if {$aff_id == "0"} {
		set aff_id ""
	}

	# Is the locale configured.
	if {[lsearch [OT_CfgGet LOCALE_INCLUSION] BET_XGAME] > -1} {
		set locale [app_control::get_val locale]
	} else {
		set locale ""
	}

	# call id is for telebetting-style apps. Probably always null
	set call_id ""

	set sub_id_list [list]

	set rep_code [reqGetArg rep_code]
	set on_course_type [reqGetArg course]

	set entry 0
	for {set l 1} {$l <= $lines} {incr l} {

		ob::log::write INFO "LOTTO place_bet draws = $draws"

		set unique_id [reqGetArg unique_id_$entry]
		if {[catch {
				set res [db_exec_qry place_bet \
					   $xgame_id\
					   $encstrings(bet_type,$l)\
					   [reqGetEnv REMOTE_ADDR]\
					   $LOGIN_DETAILS(ACCT_ID)\
					   $encstrings(stake,$l)\
					   $encstrings(stake,$l)\
					   $encstrings(picks,$l)\
					   1\
					   1\
					   $tot_num_subs\
					   $wed_or_sat\
					   $draws\
					   $source\
					   $aff_id\
					   $free_subs\
					   $encstrings(token_val,$l)\
					   N\
					   $unique_id \
					   $call_id \
					   $operator \
					   $slip_id \
					   $encstrings(prices,$l) \
					   $locale \
					   $rep_code \
					   $on_course_type \
					   $CFG(receipt_format) \
					   $CFG(receipt_tag) \
				]} msg]} {
			ob::log::write ERROR {xgame_place_bet: failed to place external game bet: $msg}
			set message $msg
			if {-1 != [string first  "AX9001" $message 0] } {
				xg_pb_err XG_PB_PAGE_RELOAD
			} else {
				xg_pb_err XG_PB_ERROR_INTERNAL $sort
			}
			return
		}

		set entry [expr $entry + 1]

		if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

			set redeemList $encstrings(redeem_list,$l)

			# Redeem any freebet tokens that were used
			set sub_id [db_get_coln $res 0 0]
			if {![OB_freebets::redeem_tokens $redeemList $sub_id "XGAME"]} {
				ob::log::write ERROR {Failed to redeem tokens $redeemList for xgame(s) $xgame_id}
				error XG_PB_ERROR_INTERNAL
				return
			}

			## Fire XGAMEBET1
		 	set num_bets 0
		 	if {[catch {set rs [db_exec_qry xgame_bet_count $LOGIN_DETAILS(ACCT_ID)]} msg]} {

				ob::log::write ERROR {Failed to retrieve XGame bet count for $username: $msg}
		 		return
		 	} else {

				set num_bets [db_get_col $rs 0 total]
		 		db_close $rs
			}

			set sub_id [db_get_coln $res 0 0]
			if {$num_bets == 1} {

				foreach trig_name {XGAMEBET1 FBET} {
					ob::log::write DEV {Sending $trig_name to FreeBets}

					if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake $xgame_id \
						$sort "" "" $sub_id "XGAME"] != 1} {

						ob::log::write WARNING {Check action $trig_name failed for $USER_ID}
						ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $sort}
						ob::log::write INFO {xgame_id $xgame_id, sub_id $sub_id, XGAME}
						return
					}
				}
			}

			##Fire XGAMEBET AND GENERIC BET. Also fire XGAMEBET1 and FBET as due to channel strictness these can
			# fire not just on the 1st bet.
			ob::log::write DEV {Sending XGAMEBET and GENERIC BET and XGAMEBET1 and FBETto FreeBets}
			foreach trig_name {XGAMEBET BET XGAMEBET1 FBET} {
				if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake $xgame_id \
					$sort "" "" $sub_id "XGAME"] != 1} {

					ob::log::write INFO {Check action $trig_name failed for $USER_ID}
					ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $sort}
					ob::log::write INFO {xgame_id $xgame_id, sub_id $sub_id, XGAME}
					return
				}
			}
		}

		set sub_id [db_get_coln $res 0 0]
		db_close $res

		# Split out the various draw descs
		# If more than one then make sure all available bets are placed
		# (Also remove the start and end pipes)

		set draw_descs [split $draws |]

		# In order to support old-style pools we check to see if any draws have been specified
		# If not then don't attempt to place any further bets from the subscription

		if {[llength $draw_descs] > 0} {

			set draw_descs [lrange $draw_descs 1 [expr [llength $draw_descs] - 2]]

			if {$tot_num_subs > 1} {

			# See if there are any more xgames available which match this xgame's draw desc type

				set BETSPLACED(draw_desc) [list]

				ob::log::write INFO "tot_num_subs = $tot_num_subs"

				for {set r 0} {$r < $tot_num_subs} {} {
					foreach draw $draw_descs {
					ob::log::write INFO " draw = $draw"
						if {$r >= $tot_num_subs} {
							ob::log::write INFO "r >= tot_num_subs"
							if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
								ob::log::write INFO "cannot find $draw in $BETSPLACED(draw_desc)"
								ob::log::write INFO "so setting BETSPLACED($draw,required) to 0"
								set BETSPLACED($draw,required) 0
								set BETSPLACED($draw,count) 0
							}
						} else {
							ob::log::write INFO "r < tot_num_subs"
							if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
								ob::log::write INFO "cannot find $draw in $BETSPLACED(draw_desc)"
								ob::log::write INFO "appending $draw"
								ob::log::write INFO "so setting BETSPLACED($draw,required) to 1"
								lappend BETSPLACED(draw_desc) $draw
								set BETSPLACED($draw,required) 1
								set BETSPLACED($draw,count) 0
								ob::log::write INFO "count =  $BETSPLACED($draw,count)"
							} else {
								ob::log::write INFO "found it"
								incr BETSPLACED($draw,required)
								ob::log::write INFO "BETSPLACED($draw,required) =$BETSPLACED($draw,required)"
							}
						}
						incr r
					}
				}

				#set first_draw [reqGetArg this_draw_id]
				set first_draw [lindex $draw_descs 0]
				incr BETSPLACED($first_draw,count)

				if {[catch {set rs [db_exec_qry get_other_valid_xgames $xgame_id]} msg]} {
					ob::log::write ERROR {xgame_placebet2 aborting: $msg}
					error XG_PB_ERROR_INTERNAL
				}

				ob::log::write INFO "get_other_valid_xgames"

				set nrows [db_get_nrows $rs]
				set total_placed 1

				if { $nrows > 0 } {

					set complete 0

					for {set j 0} {$j < $nrows} {incr j} {

						set new_xgame_id [db_get_col $rs $j xgame_id]
						set new_draw_id [db_get_col $rs $j draw_desc_id]

						ob::log::write INFO "new_xgame_id = $new_xgame_id"
						ob::log::write INFO "new_draw_id = $new_draw_id"

						ob::log::write INFO "looking for $new_draw_id in $draw_descs"

						if {[lsearch $draw_descs $new_draw_id] != -1} {

							if { $BETSPLACED($new_draw_id,count) < $BETSPLACED($new_draw_id,required) } {
								ob::log::write INFO "BETSPLACED($new_draw_id,count) < BETSPLACED($new_draw_id,required)"
								ob::log::write INFO "$BETSPLACED($new_draw_id,count) < $BETSPLACED($new_draw_id,required)"
								incr BETSPLACED($new_draw_id,count)
								incr total_placed
							} else {
								continue
							}

							if { $total_placed == $tot_num_subs } {
								set complete 1
							}

							set xg_pb_query "db_exec_qry place_bet_no_sub"

							lappend xg_pb_query $new_xgame_id
							lappend xg_pb_query $encstrings(bet_type,$l)
							lappend xg_pb_query $sub_id
							lappend xg_pb_query $LOGIN_DETAILS(ACCT_ID)
							lappend xg_pb_query $encstrings(stake,$l)
							lappend xg_pb_query $encstrings(stake,$l)
							lappend xg_pb_query $encstrings(picks,$l)
							lappend xg_pb_query 1
							lappend xg_pb_query 1
							lappend xg_pb_query $tot_num_subs
							lappend xg_pb_query $wed_or_sat
							lappend xg_pb_query $draws
							lappend xg_pb_query $source
							lappend xg_pb_query $aff_id
							lappend xg_pb_query $free_subs
							lappend xg_pb_query $encstrings(token_val,$l)
							lappend xg_pb_query N
							lappend xg_pb_query $unique_id
							lappend xg_pb_query $call_id
							lappend xg_pb_query $operator
							lappend xg_pb_query $slip_id
							lappend xg_pb_query $complete
							lappend xg_pb_query $encstrings(prices,$l)
							lappend xg_pb_query [reqGetArg rep_code]
							lappend xg_pb_query [reqGetArg course]


							ob_log::write DEBUG "\n"
							ob_log::write DEBUG "$xg_pb_query"

							if {[catch {set pb_rs [eval $xg_pb_query]} $msg]} {
								ob::log::write ERROR {xgame_place_bet: FAILED - $msg}
								error XG_PB_ERROR_INTERNAL
							}
							if {$complete} {
								break
							}
						}
					}
				}
				db_close $rs
			}
		}
		lappend sub_id_list $sub_id
	}

	ob::log::write INFO {Subscriptions placed: $sub_id_list}

	xg_pb_end $sub_id_list

	ob::log::write INFO {Successfully committed xgame place bet transaction}

	# Check campaign tracking
	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] } {
		foreach sub_id $sub_id_list {
			ob_camp_track::record_camp_action $USER_ID "BET" "XGAM" $sub_id
		}
	}

	return $sub_id_list
}

proc xg_pb_abort args {

	catch {OB_db::db_rollback_tran}
}

proc xg_pb_end {sub_id_list} {

	OB_db::db_commit_tran

	setup_sub_rcpt $sub_id_list

	if {[OT_CfgGet XGAMES_ENABLE_RECEIPT_PLAYING 1]} {
		go_sub_rcpt
	}

}

proc xg_pb_err {err_code {arg ""}} {

	xg_pb_abort
	if {[OT_CfgGet XGAME_HANDLE_ERRORS_IN_APP 0]} {
		error [ml_printf ${err_code} $arg] "" "$err_code"
	}

	err_add [ml_printf $err_code $arg]
	tpSetVar ERROR_CODE $err_code

	if {[OT_CfgGet XGAME_TEMPLATE_IN_SHARED 1]} {
		play_template Error
	}
}

proc setup_sub_rcpt {sub_id_list} {

	global SUBS LOGIN_DETAILS

	if {[info exists SUBS]} {
		unset SUBS
	}

	set i 0
	set SUBS(no_subs)       [llength $sub_id_list]
	set SUBS(total_paid_subs) 0
	set SUBS(total_free_subs) 0
	set SUBS(total_subs) 0

	set runningTotalCost 0

	foreach sub_id $sub_id_list {

		ob::log::write INFO {sub_id=$sub_id}

		if {[catch {set rs [db_exec_qry xgame_sub_rcpt $sub_id]} msg]} {
			ob::log::write ERROR {setup_sub_rcpt: failed to get subscription receipt details for $sub_id: $msg}
			return
		}

		set SUBS($i,xgame_sub_id) [db_get_col $rs 0 xgame_sub_id]
		set SUBS($i,ref_num)      [db_get_col $rs 0 xgame_sub_id]
		regsub -all  {\|} [db_get_col $rs 0 picks] {,} SUBS($i,picks)


		regsub -all  {\|} [db_get_col $rs 0 picks] {\t} SUBS($i,tabbed_picks)

		set t_subs [db_get_col $rs 0 num_subs]
		set f_subs [db_get_col $rs 0 free_subs]

		set runningTotalCost [expr {$runningTotalCost + ([db_get_col $rs 0 stake_per_bet] * ($t_subs - $f_subs))}]

		incr SUBS(total_subs)       [db_get_col $rs 0 num_subs]
		incr SUBS(total_free_subs)  [db_get_col $rs 0 free_subs]
		incr SUBS(total_paid_subs)  [expr {[db_get_col $rs 0 num_subs] - [db_get_col $rs 0 free_subs]}]
		incr i

	}
	if {[string match *Lottery* "[db_get_col $rs 0 name]" ] || [string match *49s* "[db_get_col $rs 0 name]" ]} {
		tpSetVar NUMBERS 1
	} else {
		tpSetVar NUMBERS 0
	  }
	set SUBS(draws)		[db_get_col $rs 0 draws]
	set SUBS(fullname)     "[db_get_col $rs 0 fname] [db_get_col $rs 0 lname]"
	set SUBS(game)         [db_get_col $rs 0 name]

	set SUBS(totalcost)    [print_ccy $runningTotalCost $LOGIN_DETAILS(CCY_CODE)]

	set SUBS(firstdraw)    [html_date [db_get_col $rs 0 draw_at] fullday]
	set SUBS(cr_date)      [html_date [db_get_col $rs 0 cr_date] shrttime]
	set SUBS(cr_date_inf)  [db_get_col $rs 0 cr_date]
	set SUBS(no_comps)     [db_get_col $rs 0 num_subs]
	set SUBS(draw_dow)     [html_date [db_get_col $rs 0 draw_at] dayofweek]
	set SUBS(draw_time)     [html_date [db_get_col $rs 0 draw_at] hr_min]
	set SUBS(firstdraw_db_rep) [db_get_col $rs 0 draw_at]



	db_close $rs
	tpSetVar  GAME	       $SUBS(game)
	tpSetVar  NUM_SUBS     $SUBS(no_subs)
	tpSetVar  NUM_COMPS    $SUBS(no_comps)
	tpSetVar  DRAW_DOW     $SUBS(draw_dow)
	tpSetVar  DRAWS	       $SUBS(draws)

	tpBindString USERID $LOGIN_DETAILS(ACCT_ID)

	tpBindVar FULLNAME        SUBS fullname
	tpBindVar GAME            SUBS game
	tpBindVar TOTALCOST       SUBS totalcost
	tpBindVar FIRSTDRAW       SUBS firstdraw
	tpBindVar PLACED_DATE     SUBS cr_date
	tpBindVar XGAME_SUB_ID    SUBS xgame_sub_id sub_idx
	tpBindVar REF_NUM         SUBS ref_num      sub_idx
	tpBindVar PICKS           SUBS picks        sub_idx

	bind_draw_desc $SUBS(draws)

	if {[catch {set rs [db_exec_qry get_balance $LOGIN_DETAILS(ACCT_ID)]} msg]} {
		ob::log::write ERROR {setup_sub_rcpt: Cannot get cusomer's account balance: $msg}
		tpBindString ACC_BAL "unknown"
	} else {
		set acc_bal [db_get_col $rs 0 balance]
		set credit_limit [db_get_col $rs 0 credit_limit]
		tpBindString ACC_BAL [print_ccy [expr {$acc_bal + $credit_limit}] $LOGIN_DETAILS(CCY_CODE)]
		db_close $rs
	 }

}

proc bind_draw_desc draws {

	global DRAW_DESCS
	set count 0
	foreach n [split $draws "|"] {
		if {$n!=""} {
			if {[catch {set rs [db_exec_qry get_drawdesc_info $n]} msg]} {
				return
			}
			set nrows [db_get_nrows $rs]

			if {$nrows>0} {
				set DRAW_DESCS($count,desc) [db_get_col $rs 0 desc]
				set DRAW_DESCS($count,day) [db_get_col $rs 0 day]
				incr count
			}
		}
	}

	tpSetVar draw_descs $count
	tpBindVar DRAWDESC DRAW_DESCS desc desc_idx
	tpBindVar DRAWDAY DRAW_DESCS day desc_idx

}


proc go_sub_rcpt {{receipt ""}} {

	global SUBS


	# Allow setup of template if passed in
	if {$receipt != ""} {
		set_xgame_template Receipt $receipt
	}

	play_template Receipt
}

proc retrieve_exchange_rate {ccy_code} {
		#
		# First try and use tXGameRoundCcy table
		#
		if {[catch {set round_rs [db_exec_qry get_stake_conversion $ccy_code]} msg]} {
				#
				# table tXGameRoundCCY doesn't exist, use tCcy table
				#
				if {[catch {set rs [db_exec_qry get_tCCY_exchange $ccy_code]} msg]} {
						return ""
				}
		}
		if {[info exists round_rs]} {
				if {[db_get_nrows $round_rs] != 1} {
						#if tXGameRoundCCY exists but has no entry
						#for $ccy_code

						if {[catch {set rs [db_exec_qry get_tCCY_exchange $ccy_code]} msg]} {
							    return ""
						}
				} else {
						#There is an entry for $ccy_code in tXGameRoundCCY
						return [db_get_col $round_rs round_exch_rate]
				}
		}
		return [db_get_col $rs exch_rate]

}

proc get_prices { bet_type sort {start} {end} } {

	global BET_TYPE

	# If the bet is on an externally settled game we don't care about prices

	if {$bet_type == "EXT"} {
		return ""
	}

	# If BET_TYPE not populated we know it is an Internet (simple) bet
	# If min_combi == max_combi then we know it is a simple ACC
	if {![info exists BET_TYPE($bet_type,min_combi)] || ($BET_TYPE($bet_type,min_combi) == $BET_TYPE($bet_type,max_combi))} {
		if {[string length $start] > 0} {
			if {[catch {set prices_rs [db_exec_qry get_xgame_acc_old_prices $bet_type $sort $start $end]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		} else {
			if {[catch {set prices_rs [db_exec_qry get_xgame_acc_prices $bet_type $sort]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}
	} else {
		if {[string length $start] > 0} {
			if {[catch {set prices_rs [db_exec_qry get_xgame_old_prices $bet_type $sort $start $end]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		} else {
			if {[catch {set prices_rs [db_exec_qry get_xgame_prices $bet_type $sort]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}
	}

	set nrows [db_get_nrows $prices_rs]
	if {$nrows == 0} {
		ob::log::write ERROR {xgame_placebet2 aborting: Couldn't find prices}
		error XG_PB_ERROR_NO_PRICES
	}

	set expected [expr {[db_get_col $prices_rs 0 max_combi] - [db_get_col $prices_rs 0 min_combi] + 1}]
	if {$nrows != $expected} {
		ob::log::write ERROR {xgame_placebet2 aborting: Couldn't find correct number of prices}
		error XG_PB_ERROR_PRICES_MISSING
	}

	for {set i 0} {$i < $nrows} {incr i} {
		if {$i != 0} {
			append prices "|"
		}
		append prices [db_get_col $prices_rs $i price_num] "-" [db_get_col $prices_rs $i price_den]
	}

	db_close $prices_rs

	return $prices
}



#
# This is only used for telebetting. Placing fo Xgame Bets for the Internet is handled
# in place_bet (above).
#
# new version of xgame_placebet. All bet data should be filled in in the XGAMES array.
# This version of xgame bet placement allows you to perform a single procedure call
# to process multiple bets from multiple xgames/sorts within a single transaction.
#
# Note: this procedure does not run in a transaction (hence unsafe). You should either
# set up your own transaction gubbins or run xgame_placebet2 which does it for you.
#
# Parameters: call_id and operator are required for telebetting - defaults to null
# Returns: a list of all of the sub_ids succesfully placed.
# Requirements: the XGAMES array should be set up as follows (where _bet_num_ is
# an integer less than XGAMES(num_bets) :
#	XGAMES(num_bets) the number of bets contained in the array
#	XGAMES(source) where the bet is coming from
#	XGAMES(_bet_num_,xgame_id) *obvious*
#	XGAMES(_bet_num_,sort) the sort as defined in tXGameDef
#	XGAMES(_bet_num_,stake_per_line) stake in the cutomer's currency
#	XGAMES(_bet_num_,numPicks) the number of picks
#	XGAMES(_bet_num_,picks) picks in format: 1|2|3
#	XGAMES(_bet_num_,numComps) otherwise known as subscriptions
#	XGAMES(_bet_num_,freeSubs) free subscriptions
# 	XGAMES(_bet_num_,draws) not to be confused with picks - draws describes whether to place
#		on midweek/Saturday games etc see tXGameDrawDesc

# new
#	XGAMES(_bet_num_,draw_before)
#	XGAMES(_bet_num_,draw_after)
#	XGAMES(_bet_num_,bet_type)
#	XGAMES(_bet_num_,num_lines)

###########################
proc xgame_placebet2_unsafe {{call_id ""} {operator ""} {slip_id ""}} {
###########################


	variable XGAMES
	global LOGIN_DETAILS
	global PLATFORM
	global USER_ID
	global DB

	variable CFG

	ob::log::write INFO {xgame placebet2 - placing $XGAMES(num_bets) bets - slip_id = $slip_id}


	if {[OB_login::ob_is_guest_user]} {
		error LOGIN_NO_LOGIN
	}


	#only Telebet and OXi use this proc, so "no_cookie is used."
	set region_cookie "no_cookie"
	set failed 0

	# call authenticate for each game with a different sort
	# all the other parameters stay the same therefore authenticate
	# is called only if the sort is different than previuos game

	set tempsort "NOTSETYET"
	set allow_bet [list]

	for {set i 0} {$i < $XGAMES(num_bets) && !$failed} {incr i} {

		# if the sort is the same as previous, do not call authenticate
		if {$tempsort != $XGAMES($i,sort)} {
			set tempsort $XGAMES($i,sort)
			set allow_bet [OB::AUTHENTICATE::authenticate $XGAMES(application) $XGAMES(channel) $USER_ID x_bet 0 [reqGetEnv REMOTE_ADDR] $region_cookie  "" "" "" "" "Y" $XGAMES($i,sort)]
		}

		# if one of the games doesnt pass authentication, break loop
		if {[lindex $allow_bet 0] != "S"} {
			set failed 1
		}
	}



	if {[lindex $allow_bet 0] != "S"} {
		# check channel
		if {[string trim [lindex [lindex $allow_bet 1] 0]] == "COUNTRY_CHAN_ALLOWED"} {
			xg_pb_err LOTTO_ERR_BET_AUTH_COUNTRY_BLOCKED_CHAN
		# check lottery
		} elseif {[string trim [lindex [lindex $allow_bet 1] 0]] == "COUNTRY_LOT_ALLOWED"} {
			xg_pb_err LOTTO_ERR_BET_AUTH_COUNTRY_BLOCKED_LOT
		# something else?
		} else {
			xg_pb_err [lindex [lindex $allow_bet 1] 2]
		}

		return
	}

	# Get user's currency details and associated exchange rate
	set ccy_code $LOGIN_DETAILS(CCY_CODE)
	set exc_rate [retrieve_exchange_rate $ccy_code]
	if {$exc_rate==""} {
		error XG_PB_ERROR_INTERNAL
		return
	}

	set aff_id [get_cookie AFF_ID]
	if {$aff_id == "0"} {
		set aff_id ""
	}

	set sub_id_list [list]

	#
	# do per bet data processing
	#

	for {set i 0} {$i < $XGAMES(num_bets)} {incr i} {

		ob::log::write ERROR {xgame_placebet2: placing $XGAMES($i,bet_type)}

		# this is probably redundant:
		if {$XGAMES($i,numPicks) != [llength [split $XGAMES($i,picks) | ]]} {
			ob::log::write INFO {xgame_placebet2 aborting: expecting $XGAMES($i,numPicks) picks, got: $XGAMES($i,picks)}
			error XG_PB_ERROR_INTERNAL
		}

		if {$XGAMES($i,search_start_time) != -1} {

			ob::log::write INFO {********\n********XGAMES($i,search_start_time): $XGAMES($i,search_start_time)}
			ob::log::write INFO {********\n********XGAMES($i,search_end_time): $XGAMES($i,search_end_time)}

			if {[catch {set detail_rs [db_exec_qry xgame_detail_option_old $XGAMES($i,search_start_time) $XGAMES($i,search_end_time) $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		} else {
			if {[catch {set detail_rs [db_exec_qry xgame_detail_option $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}

		# NOTE: this could indicate that this xgame is no longer valid! (ie has expired / is suspended)
		if {[db_get_nrows $detail_rs] != 1} {
			ob::log::write ERROR {xgame_placebet2 aborting: unexpected number of rows returned}

			# There is a chance that the game has recently been suspended
			# so check for this. If so carry on, should be picked up by check_override below

			if {$XGAMES($i,search_start_time) == -1} {

				set start_time [clock format [clock seconds] -format "%Y-%m-%d 00:00:00"]
				set end_time [clock format [clock seconds] -format "%Y-%m-%d 23:59:59"]

				if {[catch {set detail_rs [db_exec_qry xgame_detail_option_old $start_time $end_time $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
					ob::log::write ERROR {xgame_placebet2 aborting: $msg}
					error XG_PB_ERROR_INTERNAL
				}
				if {[db_get_nrows $detail_rs] != 1} {
					error XG_PB_ERROR_NO_GAME_DETS
				} else {
					if {[pb_err ERR XG_PB_ERROR_GAME_SUSP "Lottery game shut" BET $i] != 0} {
						error XG_PB_ERROR_GAME_SUSP
						return -1
					}
				}
			} else {
				# this error code may not be exactly true but it's more expressive than an 'internal' error
				error XG_PB_ERROR_NO_GAME_DETS
			}
		}

		# option_id must be valid and active for options to have an effect

		if {[OT_CfgGet XG_GAME_OPTIONS 0] == 1} {
			if {[db_get_col $detail_rs 0 option_id] == -1 || [db_get_col $detail_rs 0 option_status] == "S"} {
				ob::log::write ERROR {xgame_placebet2 aborting: invalid option_id}
				error XG_PB_ERROR_NO_OPTION
			}
		}

		set XGAMES($i,tot_num_subs) [expr {$XGAMES($i,numComps) + $XGAMES($i,freeSubs)}]

		# Use the min/max stake for the bet_type and sort if present
		# otherwise use the default min/max from the game definition.

		set XGAMES($i,bet_type_min_stake) [db_get_col $detail_rs 0 bet_type_min_stake]
		if {$XGAMES($i,bet_type_min_stake) == -1} {
			set XGAMES($i,min_stake) [db_get_col $detail_rs 0 min_stake]
		} else {
			set XGAMES($i,min_stake) $XGAMES($i,bet_type_min_stake)
		}

		set XGAMES($i,bet_type_max_stake) [db_get_col $detail_rs 0 bet_type_max_stake]
		if {$XGAMES($i,bet_type_max_stake) == -1} {
			set XGAMES($i,max_stake) [db_get_col $detail_rs 0 max_stake]
		} else {
			set XGAMES($i,max_stake) $XGAMES($i,bet_type_max_stake)
		}

		set XGAMES($i,stake_mode) [db_get_col $detail_rs 0 stake_mode]
		set XGAMES($i,num_picks_max) [db_get_col $detail_rs 0 num_picks_max]
		set XGAMES($i,num_picks_min) [db_get_col $detail_rs 0 num_picks_min]
		set XGAMES($i,has_balls) [db_get_col $detail_rs 0 has_balls]
		set XGAMES($i,num_min) [db_get_col $detail_rs 0 num_min]
		set XGAMES($i,num_max) [db_get_col $detail_rs 0 num_max]
		set XGAMES($i,wed_sat) [db_get_col $detail_rs 0 wed_sat]
		set XGAMES($i,game_status) [db_get_col $detail_rs 0 game_status]

		db_close $detail_rs

		# Get the prices for this bet_type/sort
		if {$XGAMES($i,search_start_time) != -1} {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) $XGAMES($i,search_start_time) $XGAMES($i,search_end_time)]
		} else {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) "" ""]
		}

		# only support stake mode C for the time being

		if {$XGAMES($i,stake_mode) != "C"} {
			ob::log::write ERROR {xgame_placebet2 aborting: stake_mode not supported}
			error XG_PB_ERROR_INTERNAL
		}

		# if you get here stake mode is C and so stake_per_line
		# comes from the application and is in the user's currency
		# to check it falls between min_stake and max_stake
		# convert min_stake and max_stake to user's currency

		set XGAMES($i,min_stake) [format {%.2f} [expr {$XGAMES($i,min_stake)*$exc_rate}]]
		set XGAMES($i,max_stake) [format {%.2f} [expr {$XGAMES($i,max_stake)*$exc_rate}]]

		# check that the stake is okay

		ob::log::write INFO {STAKE: $XGAMES($i,stake_per_line), max: $XGAMES($i,max_stake), min: $XGAMES($i,min_stake)}

		if {$XGAMES($i,min_stake) != "" && $XGAMES($i,stake_per_line) < $XGAMES($i,min_stake)} {


			ob::log::write INFO {Invalid stake: Minimum stake is [print_ccy $XGAMES($i,min_stake) $ccy_code].}

			if {[pb_err ERR XG_PB_ERROR_STK_LOW "Invalid lottery stake: Minimum stake is $XGAMES($i,min_stake) $ccy_code" BET $i] != 0} {

				err_add XG_PB_ERROR_STK_LOW
				continue
			}
		}

		# Set the maximimum stake to be the max stake for the xgame OR the max_stake for the
		# sort/bet_type if present. Multiply by the customers max_stake_scale (in spec).

		set adjusted_max_stake [expr {$XGAMES($i,max_stake) * $LOGIN_DETAILS(MAX_STAKE_SCALE)}]

		if {$XGAMES($i,max_stake) != "" && $XGAMES($i,stake_per_line) > $adjusted_max_stake } {
			ob::log::write WARNING {Invalid stake: Maximum stake is [print_ccy $adjusted_max_stake $ccy_code].}

			if {[pb_err ERR XG_PB_ERROR_STK_HIGH "Invalid lottery stake: Maximum stake is $adjusted_max_stake $ccy_code" BET $i] != 0} {
				error XG_PB_ERROR_STK_HIGH
				return -1
			}
		}

		# verify that the picks are in the correct format and no horseplay
		if {[lot_validate_enc_string $XGAMES($i,sort) $XGAMES($i,xgame_id) \
				$XGAMES($i,has_balls) $XGAMES($i,numPicks) $XGAMES($i,picks) \
				$XGAMES($i,num_min) $XGAMES($i,num_max)] != 1} {

			ob::log::write WARNING {xgame_place_bet: **User trying to hack external game $sort with $XGAMES($i,picks)}
			error XG_PB_ERROR_INTERNAL
		}

		if {$XGAMES($i,game_status) == "S"} {
			ob::log::write INFO {Error: Lottery game suspended}

			if {[pb_err ERR XG_PB_ERROR_GAME_SUSP "Lottery game suspended" BET $i] != 0} {

				err_add XG_PB_ERROR_GAME_SUSP
				continue
			}
		}

		# source: comes from client as either L or P depending on elite or something
		# old xgpb get's a config parm - the caller should sort it out in the XGAME array

		# Calculate total stake - does not seem to be any tax on xgames at the moment
		set total_stake [expr {$XGAMES($i,stake_per_line) * $XGAMES($i,numLines) * $XGAMES($i,tot_num_subs)}]

		# Is the locale configured.
		if {[lsearch [OT_CfgGet LOCALE_INCLUSION] BET_XGAME] > -1} {
			set locale [app_control::get_val locale]
		} else {
			set locale ""
		}

		# Validate any freebets tokens used
		if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

			set redeemList [OB_freebets::validate_tokens $XGAMES($i,token_ids) [list $XGAMES($i,xgame_id)] $total_stake "XGAME"]
			set XGAMES($i,token_value) 0
			set XGAMES($i,cust_token_ids) [list]

			# Step thru list, creating a list of tokens and a total value
			for {set token 0} {$token < [llength $redeemList]} {incr token} {

				array set token_info  [lindex $redeemList $token]

				lappend XGAMES($i,cust_token_ids) $token_info(id)

				set XGAMES($i,token_value) [expr "$XGAMES($i,token_value) + $token_info(redeemed_val)"]

			}

			set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

			set rep_code [reqGetArg rep_code]
			set on_course_type [reqGetArg course]

			if {[catch {set pb_rs [db_exec_qry place_bet \
									$XGAMES($i,xgame_id) \
									$XGAMES($i,bet_type) \
									[reqGetEnv REMOTE_ADDR] \
									$LOGIN_DETAILS(ACCT_ID) \
									$stake_per_bet \
									$XGAMES($i,stake_per_line) \
									$XGAMES($i,picks) \
									$XGAMES($i,numPicks) \
									$XGAMES($i,numLines) \
									$XGAMES($i,tot_num_subs) \
									$XGAMES($i,wed_sat) \
									$XGAMES($i,draws) \
									$XGAMES(source) \
									$aff_id \
									$XGAMES($i,freeSubs) \
									$XGAMES($i,token_value) \
									N \
									"" \
									$call_id \
									$operator \
									$slip_id \
									$prices \
									$locale \
									$rep_code \
									$on_course_type \
									$CFG(receipt_format) \
									$CFG(receipt_tag) \
								]} msg]} {
				ob::log::write ERROR {xgame_placebet2: FAILED - $msg}
				error XG_PB_ERROR_INTERNAL
			} else {

				# Redeem any freebet tokens that were used
				set sub_id [db_get_coln $pb_rs 0 0]
				if {![OB_freebets::redeem_tokens $redeemList $sub_id "XGAME"]} {
					ob::log::write ERROR {Failed to redeem tokens $redeemList for xgame(s) $XGAMES($i,xgame_id)}
					error XG_PB_ERROR_INTERNAL
					return
				}

				# Fire appropriate FreeBet triggers
				## Fire XGAMEBET1
				set num_bets 0
				if {[catch {set xg_count_rs [db_exec_qry xgame_bet_count $LOGIN_DETAILS(ACCT_ID)]} msg]} {

					ob::log::write ERROR {Failed to retrieve XGame bet count for $USER_ID: $msg}
					error XG_PB_ERROR_INTERNAL
					return
				} else {

					set num_bets [db_get_col $xg_count_rs 0 total]
					db_close $xg_count_rs
				}

				if {$num_bets == 1} {

					foreach trig_name {XGAMEBET1 FBET} {

						if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake \
							$XGAMES($i,xgame_id) $XGAMES($i,sort) "" "" $sub_id "XGAME"] != 1} {

							ob::log::write INFO {Check action $trig_name failed for $USER_ID}
							ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $XGAMES($i,sort)}
							ob::log::write INFO {xgame_id $XGAMES($i,xgame_id), sub_id $sub_id, XGAME}
							return
						}
					}
				}

				##Fire XGAMEBET and GENERIC BET
				foreach trig_name {XGAMEBET BET} {
					if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake \
						$XGAMES($i,xgame_id) $XGAMES($i,sort) "" "" $sub_id "XGAME"] != 1} {

						ob::log::write INFO {Check action $trig_name failed for $USER_ID}
						ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $XGAMES($i,sort)}
						ob::log::write INFO {xgame_id $XGAMES($i,xgame_id), sub_id $sub_id, XGAME}
						return
					}
				}
			}

		} else {

			ob::log::write INFO {XGAMES($i,search_start_time): $XGAMES($i,search_start_time)}

			set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

			set rep_code [reqGetArg rep_code]
			set on_course_type [reqGetArg course]

			if {[catch {set pb_rs [db_exec_qry place_bet \
						$XGAMES($i,xgame_id) \
						$XGAMES($i,bet_type) \
						[reqGetEnv REMOTE_ADDR] \
						$LOGIN_DETAILS(ACCT_ID) \
						$stake_per_bet \
						$XGAMES($i,stake_per_line) \
						$XGAMES($i,picks) \
						$XGAMES($i,numPicks) \
						$XGAMES($i,numLines) \
						$XGAMES($i,tot_num_subs) \
						$XGAMES($i,wed_sat) \
						$XGAMES($i,draws) \
						$XGAMES(source) \
						$aff_id \
						$XGAMES($i,freeSubs) \
						"" \
						N \
						"" \
						$call_id \
						$operator \
						$slip_id \
						$prices \
						$locale \
						$rep_code \
						$on_course_type \
						$CFG(receipt_format) \
						$CFG(receipt_tag) \
					]} msg]} {
				ob::log::write ERROR {xgame_placebet2: FAILED - $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}

		set sub_id [db_get_coln $pb_rs 0 0]
		check_overrides $i 0 0 $XGAMES($i,xgame_id) [db_get_coln $pb_rs 0 0] $i XGAME
		db_close $pb_rs

		# Split out the various draw descs.
		# If more than one then make sure that all bets are placed.

		set draw_descs [split $XGAMES($i,draws) |]
		set draw_descs [lrange $draw_descs 1 [expr [llength $draw_descs] - 2]]

		ob::log::write ERROR {draw_descs $draw_descs}

		if {$XGAMES($i,tot_num_subs) > 1} {

			#
			# Support 27992 we need to order the draw_descs
			# in the order they are next going to occur.
			#

			set first_draw [lindex $draw_descs 0]

			if {[catch {set rs [db_exec_qry get_other_valid_xgames $XGAMES($i,xgame_id)]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}

			set nrows [db_get_nrows $rs]

			set new_draw_descs [list]
			for {set d_i 0} {$d_i < $nrows} {incr d_i} {
				if {[llength $draw_descs] == 0} {
					break
				}

			    set draw_desc_id [db_get_col $rs $d_i draw_desc_id]
				ob::log::write DEBUG "comparing $draw_descs $draw_desc_id"

				if {[set l_idx [lsearch $draw_descs $draw_desc_id]] != -1} {
					lappend new_draw_descs $draw_desc_id
					ob::log::write DEBUG "Adding $draw_desc_id to list"
					# remove from the old list
					set draw_descs [lreplace $draw_descs $l_idx $l_idx]
				}
			}

			# only need to continue if found some relevant draws to place bets
			#on
			if {[llength $new_draw_descs]} {

				set draw_descs $new_draw_descs
				ob::log::write DEBUG "new draw descs =$draw_descs"

				set BETSPLACED(draw_desc) [list]

				for {set r 0} {$r < $XGAMES($i,tot_num_subs)} {} {
					foreach draw $draw_descs {
						if {$r >= $XGAMES($i,tot_num_subs)} {
							if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
								set BETSPLACED($draw,required) 0
								set BETSPLACED($draw,count) 0
							}
						} else {
							if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
								lappend BETSPLACED(draw_desc) $draw
								set BETSPLACED($draw,required) 1
								set BETSPLACED($draw,count) 0
							} else {
								incr BETSPLACED($draw,required)
							}
						}

						incr r
					}
				}

				set BETSPLACED($first_draw,count) 1

				set total_placed 1

				if { $nrows > 0 } {

					set complete 0

					for {set j 0} {$j < $nrows} {incr j} {

						set new_xgame_id [db_get_col $rs $j xgame_id]
						set new_draw_id [db_get_col $rs $j draw_desc_id]

						if {[lsearch $draw_descs $new_draw_id] != -1} {

							if { $BETSPLACED($new_draw_id,count) < $BETSPLACED($new_draw_id,required) } {
								incr BETSPLACED($new_draw_id,count)
								incr total_placed
							} else {
								continue
							}

							if { $total_placed == $XGAMES($i,tot_num_subs) } {
								set complete 1
							}

							set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

							set rep_code [reqGetArg rep_code]
							set on_course_type [reqGetArg course]

							if {[catch {set pb_rs [db_exec_qry place_bet_no_sub \
										$new_xgame_id \
										$XGAMES($i,bet_type) \
										$sub_id \
										$LOGIN_DETAILS(ACCT_ID) \
										$stake_per_bet \
										$XGAMES($i,stake_per_line) \
										$XGAMES($i,picks) \
										$XGAMES($i,numPicks) \
										$XGAMES($i,numLines) \
										$XGAMES($i,tot_num_subs) \
										$XGAMES($i,wed_sat) \
										$XGAMES($i,draws) \
										$XGAMES(source) \
										$aff_id \
										$XGAMES($i,freeSubs) \
										"" \
										N \
										"" \
										$call_id \
										$operator \
										$slip_id \
										$complete \
										$prices \
										$locale \
										$rep_code \
										$on_course_type \
									]} msg]} {
								ob::log::write ERROR {xgame_placebet2: FAILED - $msg}
								error XG_PB_ERROR_INTERNAL
								}

							if {$complete} {
								break
							}
						}
					}
				}
			}
			db_close $rs
		}

		lappend sub_id_list $sub_id

	}

	ob::log::write INFO {Subscriptions placed: $sub_id_list}

	return $sub_id_list
}


#
# transactional interface for xgame_placebet2_unsafe
#
# see xgame_placebet2_unsafe for the list of parameters etc
####################
proc xgame_placebet2 {} {
####################

	# begin placebet transaction
	if {[catch {xg_pb_start} msg]} {
		xg_pb_err XG_PB_ERROR_INTERNAL
		return
	}

	if {[catch {set sub_id_list [xgame_placebet2_unsafe]} msg]} {
		xg_pb_err $msg
		return
	}

	xg_pb_end $sub_id_list
	return $sub_id_list
}


# Taken from RC_PaddyPower4_5_4
#
# Check the bets in the XGAMES array can be placed (used only by Telebet).
#
# Params:
#
#   ob_bet_num - The bet number representing all the xgame bets in the bet
#                packages. Used when requesting overrides.
#
#   The XGAMES array should be set up as follows (where _bet_num_ is
#   an integer less than XGAMES(num_bets) :
#     XGAMES(num_bets) the number of bets contained in the array
#     XGAMES(source) where the bet is coming from
#     XGAMES(_bet_num_,xgame_id) *obvious*
#     XGAMES(_bet_num_,sort) the sort as defined in tXGameDef
#     XGAMES(_bet_num_,stake_per_line) stake in the cutomer's currency
#     XGAMES(_bet_num_,numPicks) the number of picks
#     XGAMES(_bet_num_,picks) picks in format: 1|2|3
#     XGAMES(_bet_num_,numComps) otherwise known as subscriptions
#     XGAMES(_bet_num_,freeSubs) free subscriptions
#     XGAMES(_bet_num_,draws) not to be confused with picks - draws describes
#            whether to place on midweek/Saturday games etc see tXGameDrawDesc
#     XGAMES(_bet_num_,draw_before)  ?
#     XGAMES(_bet_num_,draw_after)   ?
#     XGAMES(_bet_num_,bet_type)     ?
#     XGAMES(_bet_num_,num_lines)    ?
#
# Returns:
#
#   The total cost of the bets if no fatal errors, but will:
#
#   * Throw one of the following errors if the bets are hopelessly bad:
#
#     LOGIN_NO_LOGIN
#     XG_PB_ERROR_INTERNAL
#     XG_PB_ERROR_NO_GAME_DETS
#     XG_PB_ERROR_NO_OPTION
#     XG_PB_ERROR_NO_PRICES
#     XG_PB_ERROR_PRICES_MISSING
#
#   * Request one or more of the following overrides from the bet packages
#     if the bets are bad, but not irretrievably so:
#
#     XG_PB_ERROR_STK_LOW
#     XG_PB_ERROR_STK_HIGH
#     XG_PB_ERROR_GAME_SUSP
#
#   The caller should therefore catch errors AND check for overrides added.
#
proc check_xgames_telebet {ob_bet_num xgame_bet_ids} {

	variable XGAMES
	global LOGIN_DETAILS
	global PLATFORM
	global USER_ID
	global DB

	set XGAMES(checked) 0
	set total_cost    0.0

	ob::log::write INFO {Checking $XGAMES(num_bets) xgame bets}

	if {[OB_login::ob_is_guest_user]} {
		error LOGIN_NO_LOGIN
	}
	set ccy_code $LOGIN_DETAILS(CCY_CODE)
	set exc_rate [retrieve_exchange_rate $ccy_code]
	if {$exc_rate == ""} {
		error XG_PB_ERROR_INTERNAL
		return
	}

	foreach i $xgame_bet_ids {

		ob::log::write INFO {Checking xgame $i - $XGAMES($i,bet_type)}

		# this is probably redundant:
		if {$XGAMES($i,numPicks) != [llength [split $XGAMES($i,picks) | ]]} {
			ob::log::write INFO {expecting $XGAMES($i,numPicks) picks, got: $XGAMES($i,picks)}
			error XG_PB_ERROR_INTERNAL
		}

		if {$XGAMES($i,search_start_time) != -1} {

			ob::log::write INFO {********\n********XGAMES($i,search_start_time): $XGAMES($i,search_start_time)}
			ob::log::write INFO {********\n********XGAMES($i,search_end_time): $XGAMES($i,search_end_time)}

			if {[catch {set detail_rs [db_exec_qry xgame_detail_option_old $XGAMES($i,search_start_time) $XGAMES($i,search_end_time) $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
				ob::log::write ERROR {xgame aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		} else {
			if {[catch {set detail_rs [db_exec_qry xgame_detail_option $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
				ob::log::write ERROR {xgame aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}

		# NOTE: this could indicate that this xgame is no longer valid! (ie has expired / is suspended)
		if {[db_get_nrows $detail_rs] != 1} {
			ob::log::write ERROR {xgame aborting: unexpected number of rows returned}

			# There is a chance that the game has recently been suspended
			# so check for this.

			if {$XGAMES($i,search_start_time) == -1} {

				set start_time [clock format [clock scan "-1 week" -base [clock seconds]] -format "%Y-%m-%d 00:00:00"]
				set end_time [clock format [clock seconds] -format "%Y-%m-%d 23:59:59"]

				if {[catch {set detail_rs [db_exec_qry xgame_detail_option_old $start_time $end_time $XGAMES($i,numPicks) $XGAMES($i,xgame_id) $XGAMES($i,bet_type)]} msg]} {
					ob::log::write ERROR {xgame aborting: $msg}
					error XG_PB_ERROR_INTERNAL
				}
				if {[db_get_nrows $detail_rs] != 1} {
					error XG_PB_ERROR_NO_GAME_DETS
				} else {
					ob_bet::need_override BET $ob_bet_num XG_PB_ERROR_GAME_SUSP [list "Lottery game shut"]
			    }
			} else {
				# this error code may not be exactly true but it's more expressive than an 'internal' error
				error XG_PB_ERROR_NO_GAME_DETS
			}
		}

		# option_id must be valid and active for options to have an effect

		if {[OT_CfgGet XG_GAME_OPTIONS 0] == 1} {
			if {[db_get_col $detail_rs 0 option_id] == -1 || [db_get_col $detail_rs 0 option_status] == "S"} {
				ob::log::write ERROR {xgame aborting: invalid option_id}
				error XG_PB_ERROR_NO_OPTION
			}
		}

		set XGAMES($i,tot_num_subs) [expr {$XGAMES($i,numComps) + $XGAMES($i,freeSubs)}]

		# Use the min/max stake for the bet_type and sort if present
		# otherwise use the default min/max from the game definition.

		set XGAMES($i,bet_type_min_stake) [db_get_col $detail_rs 0 bet_type_min_stake]
		if {$XGAMES($i,bet_type_min_stake) == -1} {
			set XGAMES($i,min_stake) [db_get_col $detail_rs 0 min_stake]
		} else {
			set XGAMES($i,min_stake) $XGAMES($i,bet_type_min_stake)
		}

		set XGAMES($i,bet_type_max_stake) [db_get_col $detail_rs 0 bet_type_max_stake]
		if {$XGAMES($i,bet_type_max_stake) == -1} {
			set XGAMES($i,max_stake) [db_get_col $detail_rs 0 max_stake]
		} else {
			set XGAMES($i,max_stake) $XGAMES($i,bet_type_max_stake)
		}

		set XGAMES($i,stake_mode) [db_get_col $detail_rs 0 stake_mode]
		set XGAMES($i,num_picks_max) [db_get_col $detail_rs 0 num_picks_max]
		set XGAMES($i,num_picks_min) [db_get_col $detail_rs 0 num_picks_min]
		set XGAMES($i,has_balls) [db_get_col $detail_rs 0 has_balls]
		set XGAMES($i,num_min) [db_get_col $detail_rs 0 num_min]
		set XGAMES($i,num_max) [db_get_col $detail_rs 0 num_max]
		set XGAMES($i,wed_sat) [db_get_col $detail_rs 0 wed_sat]
		set XGAMES($i,game_status) [db_get_col $detail_rs 0 game_status]

		db_close $detail_rs

		# Get the prices for this bet_type/sort
		if {$XGAMES($i,search_start_time) != -1} {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) $XGAMES($i,search_start_time) $XGAMES($i,search_end_time)]
		} else {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) "" ""]
		}

		# only support stake mode C for the time being

		if {$XGAMES($i,stake_mode) != "C"} {
			ob::log::write ERROR {xgame aborting: stake_mode not supported}
			error XG_PB_ERROR_INTERNAL
		}

		# if you get here stake mode is C and so stake_per_line
		# comes from the application and is in the user's currency
		# to check it falls between min_stake and max_stake
		# convert min_stake and max_stake to user's currency

		set XGAMES($i,min_stake) [format {%.2f} [expr {$XGAMES($i,min_stake)*$exc_rate}]]
		set XGAMES($i,max_stake) [format {%.2f} [expr {$XGAMES($i,max_stake)*$exc_rate}]]

		# check that the stake is okay

		ob::log::write INFO {STAKE: $XGAMES($i,stake_per_line), max: $XGAMES($i,max_stake), min: $XGAMES($i,min_stake)}

		if {$XGAMES($i,min_stake) != "" && $XGAMES($i,stake_per_line) < $XGAMES($i,min_stake)} {
			ob::log::write INFO {Invalid stake: Minimum stake is [print_ccy $XGAMES($i,min_stake) $ccy_code].}
			ob_bet::need_override BET $ob_bet_num XG_PB_ERROR_STK_LOW [list "Invalid lottery stake: Minimum stake is $XGAMES($i,min_stake) $ccy_code"]
		}

		# Set the maximimum stake to be the max stake for the xgame OR the max_stake for the
		# sort/bet_type if present. Multiply by the customers max_stake_scale (in spec).

		set adjusted_max_stake [expr {$XGAMES($i,max_stake) * $LOGIN_DETAILS(MAX_STAKE_SCALE)}]

		if {$XGAMES($i,max_stake) != "" && $XGAMES($i,stake_per_line) > $adjusted_max_stake } {
			ob::log::write WARNING {Invalid stake: Maximum stake is [print_ccy $adjusted_max_stake $ccy_code].}
			ob_bet::need_override BET $ob_bet_num XG_PB_ERROR_STK_HIGH [list "Invalid lottery stake: Maximum stake is $adjusted_max_stake $ccy_code"]
		}

		# verify that the picks are in the correct format and no horseplay
		if {[lot_validate_enc_string $XGAMES($i,sort) $XGAMES($i,xgame_id) \
				$XGAMES($i,has_balls) $XGAMES($i,numPicks) $XGAMES($i,picks) \
				$XGAMES($i,num_min) $XGAMES($i,num_max)] != 1} {
			ob::log::write WARNING {xgame_place_bet: **User trying to hack external game $sort with $p}
			error XG_PB_ERROR_INTERNAL
		}

		if {$XGAMES($i,game_status) == "S"} {
			ob::log::write INFO {Error: Lottery game suspended}
			ob_bet::need_override BET $ob_bet_num XG_PB_ERROR_GAME_SUSP [list "Lottery game suspended"]
		}

		# Calculate total stake - does not seem to be any tax on xgames at the moment
		set total_stake [expr {$XGAMES($i,stake_per_line) * $XGAMES($i,numLines) * $XGAMES($i,tot_num_subs)}]

		# Ignore freebets since they're not currently enabled for xgames via Telebet...
		set total_cost [expr {$total_cost + $total_stake}]

	}

	set XGAMES(checked) 1

	return $total_cost
}

# Taken from RC_PaddyPower4_5_4 for placement with bet packages rather than
# placebet2
#
# Place the bets in the XGAMES array. (used only by Telebet)
#
# Params:
#
#   call_id, operator, slip_id - details of the telebet call
#
#   The XGAMES array should be set up as follows (where _bet_num_ is
#   an integer less than XGAMES(num_bets) :
#     XGAMES(num_bets) the number of bets contained in the array
#     XGAMES(source) where the bet is coming from
#     XGAMES(_bet_num_,xgame_id) *obvious*
#     XGAMES(_bet_num_,sort) the sort as defined in tXGameDef
#     XGAMES(_bet_num_,stake_per_line) stake in the cutomer's currency
#     XGAMES(_bet_num_,numPicks) the number of picks
#     XGAMES(_bet_num_,picks) picks in format: 1|2|3
#     XGAMES(_bet_num_,numComps) otherwise known as subscriptions
#     XGAMES(_bet_num_,freeSubs) free subscriptions
#     XGAMES(_bet_num_,draws) not to be confused with picks - draws describes
#            whether to place on midweek/Saturday games etc see tXGameDrawDesc
#     XGAMES(_bet_num_,draw_before)  ?
#     XGAMES(_bet_num_,draw_after)   ?
#     XGAMES(_bet_num_,bet_type)     ?
#     XGAMES(_bet_num_,num_lines)    ?
#
# Returns:
#
#   List of subscription ids on success, or throws an error on failure.
#
# WARNING:
#
#   It is the caller's responsibility to:
#      a) call check_xgames_telebet first
#      b) provide a transaction
#      c) rollback the transaction on failure
#
proc place_xgames_telebet_unsafe {call_id operator slip_id xgame_bet_ids} {

	variable XGAMES
	global LOGIN_DETAILS
	global PLATFORM
	global USER_ID
	global DB

	ob::log::write INFO {xgame placebet2 - placing $xgame_bet_ids - slip_id = $slip_id}

	if {![info exists XGAMES(checked)] || !$XGAMES(checked)} {
		error "XGAMES have not been checked"
	}

	if {[OB_login::ob_is_guest_user]} {
		error LOGIN_NO_LOGIN
	}

	# Get user's currency details and associated exchange rate
	set ccy_code $LOGIN_DETAILS(CCY_CODE)
	set exc_rate [retrieve_exchange_rate $ccy_code]
	if {$exc_rate == ""} {
		error XG_PB_ERROR_INTERNAL
		return
	}

	set aff_id [get_cookie AFF_ID]
	if {$aff_id == "0"} {
		set aff_id ""
	}

	set sub_id_list [list]

	#
	# do per bet data processing
	#

	foreach i $xgame_bet_ids {

		ob::log::write ERROR {Placing xgame bet $i - $XGAMES($i,bet_type)}

		# Get the prices for this bet_type/sort
		if {$XGAMES($i,search_start_time) != -1} {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) $XGAMES($i,search_start_time) $XGAMES($i,search_end_time)]
		} else {
			set prices [get_prices $XGAMES($i,bet_type) $XGAMES($i,sort) "" ""]
		}

		# Calculate total stake - does not seem to be any tax on xgames at the moment
		set total_stake [expr {$XGAMES($i,stake_per_line) * $XGAMES($i,numLines) * $XGAMES($i,tot_num_subs)}]

		# Validate any freebets tokens used
		if {[OT_CfgGet ENABLE_XGAME_FREEBETS "FALSE"] == "TRUE"} {

			set redeemList [OB_freebets::validate_tokens $XGAMES($i,token_ids) [list $XGAMES($i,xgame_id)] $total_stake "XGAME"]
			set XGAMES($i,token_value) 0
			set XGAMES($i,cust_token_ids) [list]

			# Step thru list, creating a list of tokens and a total value
			for {set token 0} {$token < [llength $redeemList]} {incr token} {

				array set token_info  [lindex $redeemList $token]

				lappend XGAMES($i,cust_token_ids) $token_info(id)

				set XGAMES($i,token_value) [expr "$XGAMES($i,token_value) + $token_info(redeemed_val)"]

			}

			set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

			if {[catch {set pb_rs [db_exec_qry place_bet \
									$XGAMES($i,xgame_id) \
									$XGAMES($i,bet_type) \
									[reqGetEnv REMOTE_ADDR] \
									$LOGIN_DETAILS(ACCT_ID) \
									$stake_per_bet \
									$XGAMES($i,stake_per_line) \
									$XGAMES($i,picks) \
									$XGAMES($i,numPicks) \
									$XGAMES($i,numLines) \
									$XGAMES($i,tot_num_subs) \
									$XGAMES($i,wed_sat) \
									$XGAMES($i,draws) \
									$XGAMES(source) \
									$aff_id \
									$XGAMES($i,freeSubs) \
									$XGAMES($i,token_value) \
									N \
									"" \
									$call_id \
									$operator \
									$slip_id \
									$prices]} msg]} {
				ob::log::write ERROR {Failed to place xgame bet; $msg}
				error XG_PB_ERROR_INTERNAL
			} else {

				# Redeem any freebet tokens that were used
				set sub_id [db_get_coln $pb_rs 0 0]
				if {![OB_freebets::redeem_tokens $redeemList $sub_id "XGAME"]} {
					ob::log::write ERROR {Failed to redeem tokens $redeemList for xgame(s) $XGAMES($i,xgame_id)}
					error XG_PB_ERROR_INTERNAL
					return
				}

				# Fire appropriate FreeBet triggers
				## Fire XGAMEBET1
				set num_bets 0
				if {[catch {set xg_count_rs [db_exec_qry xgame_bet_count $LOGIN_DETAILS(ACCT_ID)]} msg]} {

					ob::log::write ERROR {Failed to retrieve XGame bet count for $USER_ID: $msg}
					error XG_PB_ERROR_INTERNAL
					return
				} else {

					set num_bets [db_get_col $xg_count_rs 0 total]
					db_close $xg_count_rs
				}

				if {$num_bets == 1} {

					foreach trig_name {XGAMEBET1 FBET} {

						if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake \
							$XGAMES($i,xgame_id) $XGAMES($i,sort) "" "" $sub_id "XGAME"] != 1} {

							ob::log::write INFO {Check action $trig_name failed for $USER_ID}
							ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $XGAMES($i,sort)}
							ob::log::write INFO {xgame_id $XGAMES($i,xgame_id), sub_id $sub_id, XGAME}
							return
						}
					}
				}

				##Fire XGAMEBET and GENERIC BET
				foreach trig_name {XGAMEBET BET} {
					if {[OB_freebets::check_action $trig_name $USER_ID $aff_id $total_stake \
						$XGAMES($i,xgame_id) $XGAMES($i,sort) "" "" $sub_id "XGAME"] != 1} {

						ob::log::write INFO {Check action $trig_name failed for $USER_ID}
						ob::log::write INFO {aff_id $aff_id, amount $total_stake, sort $XGAMES($i,sort)}
						ob::log::write INFO {xgame_id $XGAMES($i,xgame_id), sub_id $sub_id, XGAME}
						return
					}
				}
			}

		} else {

			ob::log::write INFO {XGAMES($i,search_start_time): $XGAMES($i,search_start_time)}

			set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

			if {[catch {set pb_rs [db_exec_qry place_bet \
						$XGAMES($i,xgame_id) \
						$XGAMES($i,bet_type) \
						[reqGetEnv REMOTE_ADDR] \
						$LOGIN_DETAILS(ACCT_ID) \
						$stake_per_bet \
						$XGAMES($i,stake_per_line) \
						$XGAMES($i,picks) \
						$XGAMES($i,numPicks) \
						$XGAMES($i,numLines) \
						$XGAMES($i,tot_num_subs) \
						$XGAMES($i,wed_sat) \
						$XGAMES($i,draws) \
						$XGAMES(source) \
						$aff_id \
						$XGAMES($i,freeSubs) \
						"" \
						N \
						"" \
						$call_id \
						$operator \
						$slip_id \
						$prices]} msg]} {
				ob::log::write ERROR {Failed to place xgame bet; $msg}
				error XG_PB_ERROR_INTERNAL
			}
		}

		set sub_id [db_get_coln $pb_rs 0 0]
		db_close $pb_rs

		# Split out the various draw descs.
		# If more than one then make sure that all bets are placed.

		set draw_descs [split $XGAMES($i,draws) |]
		set draw_descs [lrange $draw_descs 1 [expr [llength $draw_descs] - 2]]

		ob::log::write ERROR {draw_descs $draw_descs}

		if {$XGAMES($i,tot_num_subs) > 1} {

			set BETSPLACED(draw_desc) [list]

			for {set r 0} {$r < $XGAMES($i,tot_num_subs)} {} {
				foreach draw $draw_descs {
					if {$r >= $XGAMES($i,tot_num_subs)} {
						if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
							set BETSPLACED($draw,required) 0
						}
					} else {
						if  {[lsearch $BETSPLACED(draw_desc) $draw] < 0} {
							lappend BETSPLACED(draw_desc) $draw
							set BETSPLACED($draw,required) 1
							set BETSPLACED($draw,count) 0
						} else {
							incr BETSPLACED($draw,required)
						}
					}

					incr r
				}
			}

			set first_draw [lindex $draw_descs 0]
			incr BETSPLACED($first_draw,count)

			if {[catch {set rs [db_exec_qry get_other_valid_xgames $XGAMES($i,xgame_id)]} msg]} {
				ob::log::write ERROR {xgame_placebet2 aborting: $msg}
				error XG_PB_ERROR_INTERNAL
			}

			set nrows [db_get_nrows $rs]
			set total_placed 1

			if { $nrows > 0 } {

				set complete 0

				for {set j 0} {$j < $nrows} {incr j} {

					set new_xgame_id [db_get_col $rs $j xgame_id]
					set new_draw_id [db_get_col $rs $j draw_desc_id]

					if {[lsearch $draw_descs $new_draw_id] != -1} {

						if { $BETSPLACED($new_draw_id,count) < $BETSPLACED($new_draw_id,required) } {
							incr BETSPLACED($new_draw_id,count)
							incr total_placed
						} else {
							continue
						}

						if { $total_placed == $XGAMES($i,tot_num_subs) } {
							set complete 1
						}

						set stake_per_bet [expr "$XGAMES($i,stake_per_line) * $XGAMES($i,numLines)"]

						if {[catch {set pb_rs [db_exec_qry place_bet_no_sub \
									$new_xgame_id \
									$XGAMES($i,bet_type) \
									$sub_id \
									$LOGIN_DETAILS(ACCT_ID) \
									$stake_per_bet \
									$XGAMES($i,stake_per_line) \
									$XGAMES($i,picks) \
									$XGAMES($i,numPicks) \
									$XGAMES($i,numLines) \
									$XGAMES($i,tot_num_subs) \
									$XGAMES($i,wed_sat) \
									$XGAMES($i,draws) \
									$XGAMES(source) \
									$aff_id \
									$XGAMES($i,freeSubs) \
									"" \
									N \
									"" \
									$call_id \
									$operator \
									$slip_id \
									$complete \
									$prices]} msg]} {
							ob::log::write ERROR {Failed to place xgame bet using place_bet_no_sub; $msg}
							error XG_PB_ERROR_INTERNAL
							}

						if {$complete} {
							break
						}
					}
				}
			}
			db_close $rs
		}

		lappend sub_id_list $sub_id

	}

	ob::log::write INFO {Subscriptions placed: $sub_id_list}

	return $sub_id_list
}

# close namespace
}

