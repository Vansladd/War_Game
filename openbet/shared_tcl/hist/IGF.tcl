# $Id: IGF.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Internet Gaming Framework (IGF) history handler.
# Provides a listing for all CGSK & CGWN j_op_types, game classes, game versions
# or display the details for one IGF transaction.
#
# NB: IGF (original internal project name) covers Fixed Odds Games (FOG) and
#     Casino style games.
#
# The package is self initialising.
#
# Synopsis:
#    package require hist_IGF ?4.5?
#
# Procedures:
#    ob_hist::IGF_add_game_callback  add application specific game callbacks
#

package provide hist_IGF 4.5



# Dependencies
#
package require util_log   4.5
package require util_db    4.5




# Variables
#
namespace eval ob_hist {

	variable IGF_INIT
	variable IGF_CALLBACK

	# initialise flag
	set IGF_INIT 0

	# default game history handle callbacks
	# - the callbacks get specific game details, e.g. MLSlot, etc. and can
	#   be overridden by an application
	foreach {
		class                           args
	} {
		bj.Blackjack                    {bj stake}
		games.pokerdice.PokerDice       {pkdice current_winnings}
		games.pokerfruits.PokerFruits    mmlslot
		games.pyramid.Pyramid           {pyramid {stake winnings}}
		games.reddog.RedDog              red_dog
		games.vkeno.VKeno                vkeno
		hilo.HiLo                       {hilo current_winnings}
		hilox.HiLoX                     {hilox {stake
												bank
												current_winnings}}
		hilo.hilomulti.HiLoMulti        {hilo current_winnings}
		hilo.hilopoker.HiLoPoker        {hilo current_winnings}
		keno.Keno                        keno
		keno.bingo.KenoBingo             keno
		mlslot.MLSlot                    mlslot
		mlslot.bslot.BSlot               mlslot
		mlslot.bslot.mbslot.MultiBSlot   mmlslot
		xslot.XSlot                      xslot
	} {
		set IGF_CALLBACK(com.orbisuk.igf.games.$class) \
			[concat ob_hist::_IGF_game $args]
	}

	foreach {
		class                            args
	} {
		bet.Bet                          bet
		games.baccarat.Baccarat         {baccarat {stake
												   winnings
												   commission_paid}}
		games.colours.Colours            bet
		games.craps.Craps               {craps {stake winnings refund}}
		games.doublebarrel.DoubleBarrel  bet
		games.miamidice.MiamiDice        mbet
		games.paradice.Paradice          bet
		games.sicbo.Sicbo                bet
		games.snapjax.Snapjax            bet
		roulette.Roulette                roulette
		slot.Slot                       {slot {total_stake
											   stake
											   stake_per_line
											   winnings}}
	} {
		set IGF_CALLBACK(com.orbisuk.igf.games.$class) \
			[concat ob_hist::_IGF_game_details $args]
	}

	foreach {
		class                            args
	} {
		games.studpoker.StudPoker        spoker
		vpoker.VPoker                    vpoker
	} {
		set IGF_CALLBACK(com.orbisuk.igf.games.$class) \
			[concat ob_hist::_IGF_game_poker $args]
	}

}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one time initialisation.
#
proc ob_hist::_IGF_init args {

	variable IGF_INIT

	# already initialised?
	if {$IGF_INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {IGF_HIST: init}

	# prepare queries
	_IGF_prepare_qrys

	# successfully initialised
	set IGF_INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_IGF_prepare_qrys args {

	# get all CGSK journal entries between two dates
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   reference the same tCGGameSummary
	ob_db::store_qry ob_hist::IGF_get {

		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j.j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl          j,
			tCGGameSummary s,
			tCGGame        g
		where
			j.cr_date      >= ?
		and j.cr_date      <= ?
		and j.acct_id       = ?
		and j.j_op_type     = 'CGSK'
		and j.j_op_ref_key  = 'IGF'
		and j.j_op_ref_id   = s.cg_game_id
		and s.cg_id         = g.cg_id
		order by
			j.cr_date desc,
			j.jrnl_id desc;

	}

	# get all CGSK journal entries after a specific entry but before a date
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   reference the same tCGGameSummary
	ob_db::store_qry ob_hist::IGF_get_w_jrnl_id {

		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j.j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl          j,
			tCGGameSummary s,
			tCGGame        g
		where
			j.cr_date      >= ?
		and j.jrnl_id      <= ?
		and j.acct_id       = ?
		and j.j_op_type     = 'CGSK'
		and j.j_op_ref_key  = 'IGF'
		and j.j_op_ref_id   = s.cg_game_id
		and s.cg_id         = g.cg_id
		order by
			j.cr_date desc,
			j.jrnl_id desc;

	}

	# get a particular game-class CGSK journal entries between two dates
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   refer to the same tCGGameSummary.
	# - access tJrnl to avoid complications with handling different columns
	ob_db::store_qry ob_hist::IGF_get_w_cg_class {
		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl j,
			tCGGameSummary s,
			tCGGame g
		where
			g.cg_class = ?
		and s.cg_id = g.cg_id
		and j.acct_id = ?
		and j.cr_date >= ?
		and j.cr_date <= ?
		and j.j_op_ref_id = s.cg_game_id
		and j.j_op_type = 'CGSK'
		and j.j_op_ref_key = 'IGF'
		order by
			cr_date desc,
			jrnl_id desc
	}

	# get a particular game-class CGSK journal entries after a specific entry
	# but before a date
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   reference the same tCGGameSummary
	# - access tJrnl to avoid complications with handling different columns
	ob_db::store_qry ob_hist::IGF_get_w_cg_class_jrnl_id {
		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl j,
			tCGGameSummary s,
			tCGGame g
		where
			g.cg_class = ?
		and s.cg_id = g.cg_id
		and j.acct_id = ?
		and j.cr_date >= ?
		and j.jrnl_id <= ?
		and j.j_op_ref_id = s.cg_game_id
		and j.j_op_type = 'CGSK'
		and j.j_op_ref_key = 'IGF'
		order by
			cr_date desc,
			jrnl_id desc
	}

	# get a particular game id CGSK journal entries between two dates
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   reference the same tCGGameSummary
	# - access tJrnl to avoid complications with handling different columns
	ob_db::store_qry ob_hist::IGF_get_w_cg_id {
		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j.j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl j,
			tCGGameSummary s,
			tCGGame g
		where
			g.cg_id = ?
			and s.cg_id = g.cg_id
			and j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_id = s.cg_game_id
			and j.j_op_type = 'CGSK'
			and j.j_op_ref_key = 'IGF'
		order by
			cr_date desc,
			jrnl_id desc
	}

	# get a particular game id CGSK journal entries after a specific entry
	# but before a date
	# - IGF also has CGWN which denotes a win, however both op_types always
	#   reference the same tCGGameSummary
	# - access tJrnl to avoid complications with handling different columns
	ob_db::store_qry ob_hist::IGF_get_w_cg_id_jrnl_id {
		select first 21
			j.cr_date,
			j.jrnl_id,
			j.desc,
			j_op_ref_key,
			j.j_op_ref_id,
			j.j_op_type,
			j.amount,
			j.user_id,
			j.balance,
			g.name as game_name
		from
			tJrnl j,
			tCGGameSummary s,
			tCGGame g,
			tCGAcct a
		where
			g.cg_id = ?
		and s.cg_id = g.cg_id
		and j.acct_id = ?
		and j.cr_date >= ?
		and j.jrnl_id <= ?
		and j.j_op_ref_id = s.cg_game_id
		and j.j_op_type = 'CGSK'
		and j.j_op_ref_key = 'IGF'
		order by
			cr_date desc,
			jrnl_id desc
	}

	# get a game transaction detail (inc. progressive if played)
	ob_db::store_qry ob_hist::IGF_get_cg_game {
		select
			c.cg_class,
			g.display_name,
			g.name,
			gs.cg_game_id,
			gs.started,
			sf.finished,
			gs.stakes,
			gs.stake_per_line,
			gs.winnings,
			gs.state,
			gs.cg_id,
			gs.version,
			gs.cg_acct_id,
			j.java_class,
			j.hist_table,
			j.multi_state,
			p.prog_play_id,
			p.fixed_stake as prog_fixed_stake,
			p.min_prize as prog_min_prize,
			p.winnings as prog_winnings
		from
			tCGClass c,
			tCGGame g,
			tCGGameVersion v,
			tCGJavaClass j,
			tCGGameSummary gs,
			tCGAcct a,
			outer tCGProgSummary p,
			outer tCGGSFinished  sf
		where
			gs.cg_game_id = ?
		and a.acct_id = ?
		and gs.cg_acct_id = a.cg_acct_id
		and g.cg_id = gs.cg_id
		and v.cg_id = g.cg_id
		and v.version = gs.version
		and c.cg_class = g.cg_class
		and j.java_class = NVL(v.java_class, NVL(g.java_class, c.java_class))
		and p.cg_game_id = gs.cg_game_id
		and sf.cg_game_id = gs.cg_game_id
	}

	# get a progressive transaction detail (inc. associated game summary)
	ob_db::store_qry ob_hist::IGF_get_prog_play {
		select
			c.cg_class,
			g.display_name,
			g.name,
			gs.cg_game_id,
			gs.started,
			sf.finished,
			gs.stakes,
			gs.stake_per_line,
			gs.winnings,
			gs.state,
			gs.cg_id,
			gs.version,
			gs.cg_acct_id,
			j.java_class,
			j.hist_table,
			j.multi_state,
			p.prog_play_id,
			p.fixed_stake as prog_fixed_stake,
			p.min_prize as prog_min_prize,
			p.winnings as prog_winnings
		from
			tCGClass c,
			tCGGame g,
			tCGGameVersion v,
			tCGJavaClass j,
			tCGGameSummary gs,
			tCGAcct a,
			tCGProgSummary p,
			outer tCGGSFinished  sf
		where
			p.prog_play_id = ?
		and a.acct_id = ?
		and gs.cg_game_id = p.cg_game_id
		and gs.cg_acct_id = a.cg_acct_id
		and g.cg_id = gs.cg_id
		and v.cg_id = g.cg_id
		and v.version = gs.version
		and c.cg_class = g.cg_class
		and j.java_class = NVL(v.java_class, NVL(g.java_class, c.java_class))
		and p.cg_game_id = gs.cg_game_id
		and sf.cg_game_id = gs.cg_game_id
	}

	# get a Baccarat game history instance
	ob_db::store_qry ob_hist::IGF_get_baccarat_hist {

		select
			drawn,
			num_bets
		from tCGBetHist
		where cg_game_id = ?

	}

	# get a Baccarat game history bets
	ob_db::store_qry ob_hist::IGF_get_baccarat_hist_details {

		select
			b.order,
			b.stake,
			b.winnings,
			b.commission_paid,
			p.name
		from
			tCGBaccaratBet b,
			tCGBetPayout   p
		where b.cg_game_id = ?
		  and p.payout_id  = b.payout_id
		order by
			b.order;

	}

	# get a Bet game history instance
	ob_db::store_qry ob_hist::IGF_get_bet_hist {
		select
			interaction,
			drawn,
			num_bets
		from
			tCGBetHist
		where
			cg_game_id = ?
	}

	# get a Bet game history bets
	ob_db::store_qry ob_hist::IGF_get_bet_hist_details {

		select
			b.interaction,
			b.order,
			p.name,
			p.bet_type as type,
			b.seln,
			b.stake,
			b.winnings
		from
			tCGBet       b,
			tCGBetPayout p
		where b.cg_game_id = ?
		  and p.payout_id  = b.payout_id
		order by
			interaction,
			order;

	}

	# get Blackjack game history instances
	ob_db::store_qry ob_hist::IGF_get_bj_hist {

		select
			interaction,
			current_player,
			current_hand,
			action,
			stake,
			dealer,
			player,
			hand_status
		from
			tCGBJHist
		where
			cg_game_id = ?
		order by
			interaction

	}

	#
	# Get history of a craps game.
	#
	ob_db::store_qry ob_hist::IGF_get_craps_hist {

		select
			interaction,
			cr_date,
			drawn,
			num_bets,
			stake,
			refund,
			commission,
			winnings,
			comeout_point,
			action,
			game_status
		from tCGCrapsHist
		where cg_game_id = ?
		order by interaction;

	}

	#
	# Get bets from a craps games.
	#
	ob_db::store_qry ob_hist::IGF_get_craps_hist_details {

		select
			b.interaction,
			b.state,
			b.order,
			p.name as payout,
			b.cr_interaction,
			b.point,
			b.stake,
			b.winnings,
			b.refund
		from
			tCGCrapsBet  b,
			tCGBetPayout p
		where b.cg_game_id = ?
		  and b.payout_id  = p.payout_id
		order by 1, 2, 3, 4, 5;

	}

	# get HiLo game history instances
	ob_db::store_qry ob_hist::IGF_get_hilo_hist {
		select
			interaction,
			action,
			action_index,
			action_data,
			game_status,
			game_state,
			current_play,
			current_winnings,
			win_index,
			lose_index
		from
			tCGHiLoHist
		where
			cg_game_id = ?
		order by
			interaction
	}

	# get HiLoX game history instances
	ob_db::store_qry ob_hist::IGF_get_hilox_hist {
		select
			interaction,
			action,
			game_status,
			stake,
			bank,
			game_state,
			current_play,
			current_winnings,
			win_since_swap,
			rule_id
		from
			tCGHLXHist
		where
			cg_game_id = ?
		order by
			interaction
	}

	# get Keno & KenoBingo game history instances
	ob_db::store_qry ob_hist::IGF_get_keno_hist {
		select
			interaction,
			drawn,
			drawn_2,
			selected,
			matches,
			bingo_card
		from
			tCGKenoHist
		where
			cg_game_id = ?
	}

	# get an MBet game history
	ob_db::store_qry ob_hist::IGF_get_mbet_hist {

		select
			interaction,
			drawn,
			num_bets,
			stake,
			winnings,
			action,
			game_status
		from tCGMBetHist
		where cg_game_id = ?
		order by interaction;

	}

	# get a Bet game history bets
	ob_db::store_qry ob_hist::IGF_get_mbet_hist_details {

		select
			b.interaction,
			b.order,
			p.name,
			p.bet_type as type,
			b.seln,
			b.stake,
			b.winnings
		from
			tCGBet       b,
			tCGBetPayout p
		where b.cg_game_id = ?
		  and p.payout_id  = b.payout_id
		order by
			interaction,
			order;

	}

	# get an MLSlot game history
	ob_db::store_qry ob_hist::IGF_get_mlslot_hist {

		select
			interaction,
			multiplier_index,
			mplr_result,
			reverse_payout,
			stop,
			sel_win_lines,
			win_lines,
			win_payouts
		from
			tCGMLSlotHist
		where cg_game_id = ?
		order by interaction;

	}

	# get an MMLSlot game history
	ob_db::store_qry ob_hist::IGF_get_mmlslot_hist {

		select
			interaction,
			action,
			game_status,
			multiplier_index,
			reverse_payout,
			reel_set_index,
			stop,
			sel_win_lines,
			win_lines,
			win_payouts,
			win_bonus,
			mplr_result,
			bonus_spins,
			scatter_payouts,
			scatter_bonus,
			scatter_mplr_res,
			winnings
		from tCGMMLSlotHist
		where cg_game_id = ?
		order by interaction;

	}

	#
	# Get Poker Dice game history.
	#
	ob_db::store_qry ob_hist::IGF_get_pkdice_hist {

		select
			interaction,
			action,
			action_index,
			game_status,
			game_state,
			current_play,
			current_winnings,
			current_hand
		from tCGPKDiceHist
		where cg_game_id = ?
		order by interaction;

	}

	#
	# Get Pyramid game history.
	#
	ob_db::store_qry ob_hist::IGF_get_pyramid_hist {

		select
			interaction,
			action,
			selected,
			game_status,
			current_level,
			level,
			stake,
			winnings
		from tCGPyramidHist
		where cg_game_id = ?
		order by interaction;

	}

	#
	# Get Red Dog game history.
	#
	ob_db::store_qry ob_hist::IGF_get_red_dog_hist {

		select
			interaction,
			stake,
			winnings,
			game_status,
			action,
			win_status,
			cards,
			spread
		from tCGRedDogHist
		where cg_game_id = ?
		order by interaction;

	}

	# get a Roulette game history instance
	ob_db::store_qry ob_hist::IGF_get_roulette_hist {
		select
			interaction,
			ballpicked
		from
			tCGRoulHist
		where
			cg_game_id = ?
	}

	# get a Roulette game history bets
	ob_db::store_qry ob_hist::IGF_get_roulette_hist_details {
		select
			bet_stake as stake,
			winnings,
			bet_type as name
		from
			tCGRoulBets b
		where
			b.cg_game_id = ?
	}

	# get an Slot game history
	ob_db::store_qry ob_hist::IGF_get_slot_hist {

		select
			interaction,
			action,
			status,
			reverse_payout,
			reel_set_index,
			stop,
			sel_win_lines,
			sel_win_lines2,
			num_free_spins,
			total_stake,
			stake_per_line,
			winnings
		from tCGSlotHist
		where cg_game_id = ?
		order by interaction;

	}

	# get an Slot game history details
	ob_db::store_qry ob_hist::IGF_get_slot_hist_details {

		select
			w.interaction,
			w.payout_type,
			w.index,
			w.payout,
			w.winline_index,
			w.progressive_win,
			w.stake,
			w.winnings,
			b.bonus_type,
			b.num_free_spins,
			b.wheel_results,
			b.total_wheel
		from
			tCGSlotHistWin w,
			outer tCGSlotHistBon b
		where w.cg_game_id  = ?
		  and w.hist_win_id = b.hist_win_id
		order by
			w.interaction,
			w.payout_type,
			w.winline_index,
			b.bonus_type,
			b.num_free_spins,
			b.total_wheel;

	}

	#
	# Get stud poker game history
	#
	ob_db::store_qry ob_hist::IGF_get_spoker_hist {

		select
			hand_no,
			cards,
			is_dealer_hand
		from tCGStudPokerHand
		where cg_game_id = ?
		order by
			is_dealer_hand,
			hand_no;

	}

	#
	# Get stud poker game bets
	#
	ob_db::store_qry ob_hist::IGF_get_spoker_hist_details {

		select
			interaction,
			hand_no,
			name,
			stake,
			winnings,
			prog_summ_id
		from tCGStudPokerBet
		where cg_game_id = ?
		order by
			interaction,
			hand_no;

	}

	# get Victory Keno game history
	ob_db::store_qry ob_hist::IGF_get_vkeno_hist {

		select
			interaction,
			drawn,
			drawn_2,
			selected,
			matches,
			bingo_card,
			is_reverse
		from tCGVKenoHist
		where cg_game_id = ?
		order by interaction;

	}

	# get a Video Poker game history
	ob_db::store_qry ob_hist::IGF_get_vpoker_hist {

		select
			interaction,
			stake,
			winnings,
			dealt,
			held,
			dbl_dealer,
			dbl_user,
			dbl_selection,
			dbl_count,
			action
		from
			tCGVPokerHist
		where
			cg_game_id = ?
		order by
			interaction

	}

	# get Video Poker game history hands
	ob_db::store_qry ob_hist::IGF_get_vpoker_hist_details {

		select
			hand_id,
			drawn,
			win_cards,
			win_id
		from
			tCGVPokerHands
		where
			cg_game_id = ?
		order by
			hand_id

	}

	#
	# Get Scratch card game history .
	#
	ob_db::store_qry ob_hist::IGF_get_xslot_hist {

		select
			interaction,
			multiplier_index,
			reverse_payout,
			stop,
			sel_win_lines,
			outcome,
			win_id,
			feature_id,
			feature_repeat
		from
			tCGXSlotHist
		where
			cg_game_id = ?
		order by
			interaction;

	}

	ob_db::store_qry ob_hist::get_dbl_barrel_colours {

		select
			a.attr
		from
			tCGBetAttribute a,
			tCGBetDrawable  d
		where a.cg_id          = ?
		  and a.version        = ?
		  and a.cg_bet_attr_id = d.cg_bet_attr_id
		order by d.value;

	} 3600

	#
	# Want the selections for the payouts which uniquely identify one square, so
	# we can give turn the number drawn into something the customer understands.
	#
	ob_db::store_qry ob_hist::get_lucky_star_payouts {

		select
			name,
			seln_1
		from tCGBetPayout
		where cg_id   = ?
		  and version = ?
		  and name    matches '[A-E]_[0-8]';

	} 3600

	ob_db::store_qry ob_hist::get_mlslot_mpliers {

		select
			mplr_id,
			reel     as mplr_reel,
			reel_2   as mplr_reel_2,
			reel_3   as mplr_reel_3,
			prog_win as mplr_prog_win
		from
			tCGMLSlotMplr
		where cg_id   = ?
		  and version = ?
		order by 1;

	} 3600


	ob_db::store_qry ob_hist::get_slot_payouts {

		select
			payout_index as index,
			payout,
			progressive_win as prog_win,
		from
			tCGMLSlotPayout
		where cg_id   = ?
		  and version = ?
		order by 1;

	} 3600


}


# Add/re-define the game handler callbacks.
# IGF initialisation is private (initialised by the history handler), therefore,
# call the procedure after ob_hist::init.
#
#   callback - array of user supplied callbacks which may override or add to the
#              available callbacks
#
proc ob_hist::IGF_add_game_callback { callback } {

	variable IGF_CALLBACK

	array set USER_CALLBACK $callback
	foreach java_class [array names USER_CALLBACK] {
		set IGF_CALLBACK($java_class) $USER_CALLBACK($java_class)
	}
}



#--------------------------------------------------------------------------
# IGF History Handlers
#--------------------------------------------------------------------------

# Private procedure to handle IGF journal entries (CGPS | CGPW | CGSK | CGWN).
#
# The handler will either -
#     a) get all the IGF entries between two dates
#     b) get all the IGF entries between a journal identifier and a date
#     c) get all the IGF entries between two dates restricted by class or cg_id
#     d) get all the IGF entries between a journal identifier and a date,
#        restricted by class or cg_id
#     c) get one IGF entry (game-play)
#
# The entries are stored within the history package cache.
# The procedure should only be called via ob_hist::handler.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF args {

	ob_log::write DEBUG {IGF_HIST: history handler}

	set cg_game_id [get_param j_op_ref_id [get_param cg_game_id]]
	if {$cg_game_id != ""} {
		return [_IGF_id $cg_game_id]
	} else {
		return [_IGF_list]
	}
}



# Private procedure to get the game-play details for a particular IGF entry
# (details will be stored within the history package cache).
#
# If the transaction type is a Progressive, then extract the game play details
# via the progressive-summary table (tCGProgSummary), otherwise get the details
# via the game-summary table (tCGGameSummary). Stake and winning txn types
# always point to the same summary table.
#
#   id      - journal j_op_ref_id, maybe either a game or progressive summary id
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_id { id } {

	variable HIST
	variable PARAM
	variable IGF_CALLBACK

	ob_log::write DEBUG {IGF_HIST: get cg_game_id $id}

	# is supplied id a game or progressive summary?
	set txn_type [get_param txn_type]
	if {$txn_type == "CGPS" || $txn_type == "CGPW"} {
		set qry ob_hist::IGF_get_prog_play
		ob_log::write DEBUG {IGF_HIST: IGF prog_play_id=$id}
	} else {
		set qry ob_hist::IGF_get_cg_game
		ob_log::write DEBUG {IGF_HIST: IGF cg_game_id=$id}
	}

	ob_log::write_array DEV ob_hist::PARAM

	# get the transaction details
	if {[catch {set rs [ob_db::exec_qry $qry\
				$id\
				$PARAM(acct_id)]} msg]} {
		ob_log::write ERROR {IGF_HIST: $msg}
		return [add_err OB_ERR_HIST_IGF_FAILED $msg]
	}

	# store data
	if {[db_get_nrows $rs] == 1} {

		# add history details
		set status [add_hist $rs \
							 0 \
							 IGF \
							 "" \
							 [list name]\
							 [list stakes \
								   stake_per_line \
								   winnings \
								   prog_fixed_stake \
								   prog_min_prize \
								   prog_winnings]]

		if {$status == "OB_OK"} {

			# progressive play?
			if {$HIST(0,prog_fixed_stake) != [get_param empty_str]} {
				set HIST(0,progressive_play) Y
			} else {
				set HIST(0,progressive_play) N
			}

			set HIST(total) 1

			# get specific game details which are not stored within the summary
			# - executed via a callback which maybe overridden by the caller
			set java_class $HIST(0,java_class)
			if {[info exists IGF_CALLBACK($java_class)]} {
				if {[catch {eval [subst $IGF_CALLBACK($java_class)]} msg]} {
					ob_log::write ERROR {IGF_HIST: $msg}
					add_err OB_ERR_HIST_IGF_FAILED $msg
				}
			} else {
				set HIST(0,hist_total) 0
				set HIST(0,hist_type)  ""
				ob_log::write WARNING\
					{IGF_HIST: $java_class callback not available}
			}
		}

	} else {
		set HIST(total) 0
		add_err OB_OK
	}

	ob_db::rs_close $rs
	return $HIST(err,status)
}



# Private procedure to get a list of IGF plays -
#
#     a) get all the plays between two dates
#     b) get all the plays between a journal identifier and a date
#     c) get all the IGF entries between two dates restricted by class or cg_id
#     d) get all the IGF entries between a journal identifier and a date,
#        restricted by class or cg_id
#
# The entries are stored within the history package cache.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_list args {

	variable HIST
	variable PARAM

	# get IGF journal entries
	# - either all or restricted by class/cg_id
	if {[get_param cg_class] != "" || [get_param cg_id] != ""} {
		set status [_IGF_restricted_journal_list]
	} else {
		set status [_journal_list IGF\
				ob_hist::IGF_get\
				ob_hist::IGF_get_w_jrnl_id]
	}

	# as IGF has different names, e.g. FOG, Casino, etc., get the name
	# from a history parameter
	for {set i 0} {$status == "OB_OK" && $i < $HIST(total)} {incr i} {

		set name [get_param j_op_type_name $HIST($i,j_op_type_name)]
		if {$name != $HIST($i,j_op_type_name)} {
			set HIST($i,j_op_type_name) $name

			# translate text ?
			if {[catch {
				if {$PARAM(xl_proc) != ""} {
					set HIST($i,xl_j_op_type_name) [_XL $name]
				}
			} msg]} {
				ob_log::write ERROR {IGF_HIST: $msg}
				set status [add_err OB_ERR_HIST_IGF_FAILED $msg]
			}
		}

	}

	return $status
}



# Private procedure to get one of the following journal entries -
#    a) between two dates restricted by either cg_class or cg_id
#    b) between a date and a journal identifier restricted by either cg_class
#       or cg_id
#
# What to restrict the query against is determined by the PARAM cg_class or
# cg_id (cg_class takes precedence).
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_restricted_journal_list args {

	variable HIST
	variable PARAM

	# restricted by class or game identifier
	set arg [get_param cg_class]
	if {$arg != ""} {
		set type cg_class
	} else {
		set arg [get_param cg_id]
		if {$arg == ""} {
			return [add_err OB_ERR_HIST_IGF_FAILED "invalid cg_id"]
		}
		set type cg_id
	}

	ob_log::write DEBUG {IGF_HIST: restricted journal list by $type $arg}

	# must have an end timestamp
	set status [get_timestamp start]
	if {$status != "OB_OK"} {
		return [add_err $status]
	}
	set start $PARAM(start_ifmx)

	# last jrnl_id or end-time
	set last_jrnl_id [get_param last_jrnl_id]
	if {$last_jrnl_id == ""} {
		set status [get_timestamp end]
		if {$status != "OB_OK"} {
			return [add_err $status]
		}
		set qry ob_hist::IGF_get_w_${type}
		set end $PARAM(end_ifmx)
	} else {
		set qry   ob_hist::IGF_get_w_${type}_jrnl_id
		set end $last_jrnl_id
	}

	ob_log::write_array DEV ob_hist::PARAM

	# execute the query
	if {[catch {set rs [ob_db::exec_qry $qry\
				$arg\
				$PARAM(acct_id)\
				$start\
				$end]} msg]} {
		ob_log::write ERROR {IGF_HIST: $msg}
		return [add_err OB_ERR_HIST_IGF_FAILED $msg]
	}

	# store data
	set nrows    [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]
	for {set i 0} {$i < $nrows && $i <= $PARAM(txn_per_page)} {incr i} {

		# add history details
		set status [add_hist $rs $i IGF $colnames\
				{j_op_type j_op_type_name desc} {amount balance}]

		if {$status == "OB_OK"} {
			set HIST(last_jrnl_id) $HIST($i,jrnl_id)
		}
	}
	ob_db::rs_close $rs

	if {$status == "OB_OK"} {
		set HIST(total) $i
	}

	return $status
}



#--------------------------------------------------------------------------
# IGF Game History Handlers
#--------------------------------------------------------------------------

# Private procedure to get specific game history details from tCG<type>Hist
# table.
# Each Hist table details data specific to the game-type, e.g. stop positions
# on the slot machine, which cannot be added to the tCGGameSummary table.
#
#   type     - game type
#   ccy_list - optional list of columns which are ccy formatted (default "")
#              each column must be within the result-set
#   returns  - status (OB_OK denotes success)
#              the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_game { type {ccy_list ""} } {

	variable HIST

	ob_log::write DEBUG\
		{HIST_IGF: get ${type} hist cg_game_id=$HIST(0,cg_game_id)}

	# if data is empty, what to add in its place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currency amounts
	set ccy_proc [get_param fmt_ccy_proc]

	# get game history
	if {[catch {
		set rs [ob_db::exec_qry \
			ob_hist::IGF_get_${type}_hist $HIST(0,cg_game_id)]
	} msg]} {
		ob_log::write ERROR {IGF_HIST: $msg}
		return [add_err OB_ERR_HIST_IGF_HIST_FAILED]
	}

	set HIST(0,hist_type)  $type
	set HIST(0,hist_total) [db_get_nrows $rs]
	set HIST(0,hist_cols)  [db_get_colnames $rs]

	for {set i 0} {$i < $HIST(0,hist_total)} {incr i} {

		set hk 0,hist,${i}

		foreach c $HIST(0,hist_cols) {

			set HIST($hk,$c) [db_get_col $rs $i $c]

			# hack to avoid concat bug: http://www-01.ibm.com/support/docview.wss?uid=swg1IC52309
			if {$c == "sel_win_lines"} {
				append HIST($hk,$c) [db_get_col $rs $i sel_win_lines2]
			}

			if {$HIST($hk,$c) == ""} {
				set HIST($hk,$c) $empty_str
			} elseif {$ccy_proc != "" && [string first $c $ccy_list] != -1} {
				set HIST($hk,fmt_${c}) [_fmt_ccy_amount $HIST($hk,$c)]
			}

		}

	}

	ob_db::rs_close $rs
	return [add_err OB_OK]
}



# Private procedure to get game history for games which have detailed history
# held in ancillary tables.
#
#   type    - type (baccarat, bet, craps, roulette or slot)
#             default - bet
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_game_details { {type bet} {ccy_list {stake winnings}} } {

	variable HIST

	# get bet history
	set status [_IGF_game $type $ccy_list]
	if {$status != "OB_OK" || $HIST(0,hist_total) == 0} {
		return $status
	}

	ob_log::write DEBUG \
		{HIST_IGF: get customer $type bets cg_game_id=$HIST(0,cg_game_id)}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currencies
	set fmt_ccy [get_param fmt_ccy_proc]

	# get the customer's bets
	if {[catch {
		set rs [ob_db::exec_qry \
			ob_hist::IGF_get_${type}_hist_details $HIST(0,cg_game_id)]
	} msg]} {
		ob_log::write ERROR {IGF_HIST: $msg}
		return [add_err OB_ERR_HIST_IGF_HIST_FAILED]
	}

	set HIST(0,bet_total) [db_get_nrows $rs]
	set HIST(0,bet_cols)  [db_get_colnames $rs]

	for {set i 0} {$i < $HIST(0,bet_total)} {incr i} {

		set bk 0,bet,${i}

		foreach c $HIST(0,bet_cols) {

			set HIST($bk,$c) [db_get_col $rs $i $c]

			if {$HIST($bk,$c) == ""} {
				set HIST($bk,$c) $empty_str
			} elseif {$fmt_ccy != "" && [lsearch $ccy_list $c] > -1 } {
				set HIST($bk,fmt_${c}) [_fmt_ccy_amount $HIST($bk,$c)]
			}

		}

	}

	ob_db::rs_close $rs
	return [add_err OB_OK]

}



# Private procedure to get Poker (com.orbisuk.igf.games.vpoker.VPoker and
# com.orbisuk.igf.games.games.studpoker.StudPoker) specific game history details
# from history and hand tables.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::_IGF_game_poker { type { ccy_list { stake winnings } } } {

	variable HIST

	# get history
	set status [_IGF_game $type $ccy_list]
	if {$status != "OB_OK" || $HIST(0,hist_total) == 0} {
		return $status
	}

	ob_log::write DEBUG \
		{HIST_IGF: get customer $type hands cg_game_id=$HIST(0,cg_game_id)}

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	# format currencies
	set fmt_ccy [get_param fmt_ccy_proc]

	# get the customer's playing hands
	if {[catch {
		set rs [ob_db::exec_qry ob_hist::IGF_get_${type}_hist_details \
								$HIST(0,cg_game_id)]
	} msg]} {
		ob_log::write ERROR {IGF_HIST: $msg}
		return [add_err OB_ERR_HIST_IGF_HIST_FAILED]
	}

	set HIST(0,hand_total) [db_get_nrows $rs]
	set HIST(0,hand_cols)  [db_get_colnames $rs]

	for {set i 0} {$i < $HIST(0,hand_total)} {incr i} {

		set bk 0,hand,${i}

		foreach c $HIST(0,hand_cols) {

			set HIST($bk,$c) [db_get_col $rs $i $c]

			if {$HIST($bk,$c) == ""} {
				set HIST($bk,$c) $empty_str
			} elseif {$fmt_ccy != "" && [lsearch $ccy_list $c] > -1 } {
				set HIST($bk,fmt_${c}) [_fmt_ccy_amount $HIST($bk,$c)]
			}

		}

	}

	ob_db::rs_close $rs
	return [add_err OB_OK]
}

proc ob_hist::_IGF_sum_baccarat_hand hand {

	set h 0

	foreach card [split $hand ,] {

		foreach rank [split $card ""] break

		switch -- $rank {

			A { incr h }
			2 -
			3 -
			4 -
			5 -
			6 -
			7 -
			8 -
			9 { incr h $rank }

		}

	}

	return [expr { $h % 10 }]

}

proc ob_hist::_IGF_bet_parse_drawn { drawn { bet {} } } {

	global HIST

	set name    $HIST(0,name)
	set cg_id   $HIST(0,cg_id)
	set version $HIST(0,version)

	switch -- $name {

		Colours {

			array set COLOURS [list 1 B 2 Y 3 R]

			set colours [list]

			foreach c [split $drawn |] {

				lappend colours $COLOURS($c)

			}

			return "<pre>[join [list [lrange $colours 0 7]\
									 [lrange $colours 8 e]] "\n"]</pre>"

		}

		DoubleBarrel {

			set numbers [split $drawn |]
			set lang [ob_xl::get name]

			if { [catch {
				set rs [ob_db::exec_qry \
					ob_hist::get_dbl_barrel_colours \
						$cg_id \
						$version
				]
			} err] } {
				ob_log::write ERROR \
					{Query ob_hist::get_dbl_barrel_colours\
					 failed for $cg_id, $version: $err.}
			}

			if { ![db_get_nrows $rs] } {
				ob_log::write ERROR \
					{Query ob_hist::get_dbl_barrel_colours\
					 returned no rows for $cg_id, $version: $err.}
			}

			set left       [list]
			set left_total 0

			foreach l [lrange $numbers 0 2] {

				set colour [ob_xl::sprintf $lang \
					IGF_HIST_DOUBLEBARREL_COLOUR_[db_get_coln $rs $l 0]]

				lappend left $l ($colour)

				incr left_total $l

			}

			set right       [list]
			set right_total 0

			foreach r [lrange $numbers 3 e] {

				set colour [ob_xl::sprintf $lang \
					IGF_HIST_DOUBLEBARREL_COLOUR_[db_get_coln $rs $r 0]]

				lappend right $r ($colour)

				incr right_total $r

			}

			ob_db::rs_close $rs

			return [subst {

				<table>
					<tr>
						<td>[ob_xl::sprintf $lang \
											IGF_HIST_DOUBLEBARREL_LEFT]</td>
						<td>$left_total:</td>
						<td align="right">
							[join $left  {</td><td align="right">}]</td>
					</tr>
					<tr>
						<td>[ob_xl::sprintf $lang \
											IGF_HIST_DOUBLEBARREL_RIGHT]</td>
						<td>$right_total:</td>
						<td align="right">
							[join $right  {</td><td align="right">}]</td>
					</tr>
				</table>

			}]

		}

		LuckyStar {

			if { [catch {
				set rs [ob_db::exec_qry \
					ob_hist::get_lucky_star_payouts \
						$cg_id \
						$version
				]
			} err] } {
				ob_log::write ERROR \
					{Query ob_hist::get_lucky_star_payouts\
					 failed for $cg_id, $version: $err.}
				return $drawn
			}

			for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {

				if {
					[lsearch [split [db_get_col $rs $i seln_1] |] $drawn] > -1
				} {
					set drawn [db_get_col $rs name]
					break
				}

			}

			ob_db::rs_close $rs

			return [ob_xl::sprintf [ob_xl::get name] \
								   IGF_HIST_LUCKYSTAR_BET_$drawn]

		}

		RouletteUS {

			if { $drawn == 37 } {
				return 00
			} else {
				return $drawn
			}

		}

		MiamiDice -
		Paradice  -
		Sicbo     {

			if { [lsearch {TRIPLE DOUBLE} $bet] > -1 } {
				return [lindex [split $drawn |] 0]
			} else {
				return [join [split $drawn |] {, }]
			}

		}

		Snapjax {

			return [join [_IGF_format_cards [_IGF_int_to_card \
												[split $drawn |] 0] {}] {, }]

		}

		default {

			return $drawn

		}

	}

}

proc ob_hist::_IGF_hilo_cards ints {

	#
	# Mod'ing the rank by 13 means that the highest card, A or K, == 0.
	#
	set ranks [list A 2 3 4 5 6 7 8 9 T J Q K]
	set suits [list S C H D]
	set cards [list]

	foreach c $ints {

		if { $c } {

			set    card [lindex $ranks [expr { $c % 13 }]]
			append card [lindex $suits [expr { $c % 52 / 13 }]]
			append card [expr { 1 + $c / 52 }]

		} else {
			set card {}
		}

		lappend cards $card

	}

	return $cards

}


proc ob_hist::_IGF_hilo_x_parse_drawn { value attr } {

	global HIST

	switch -- $HIST(0,name) {

		Digit {

			set drawn [lindex [list {0 0 0} \
									{0 0 1} \
									{0 1 1} \
									{1 0 0} \
									{1 0 1} \
									{1 1 0} \
									{1 1 1} ] $value]

			return [list $drawn {}]

		}

		HotShots {

			return [list $value [ob_xl::sprintf [ob_xl::get name] \
				IGF_HIST_HOTSHOTS_COLOUR_[string toupper $attr]]]

		}

		default {

			return [list $value $attr]

		}

	}

}


proc ob_hist::_IGF_hilo_x_parse_rule value {

	global HIST

	set lang [ob_xl::get name]

	switch -- $HIST(0,name) {

		Digit {

			return [ob_xl::sprintf $lang \
								   IGF_HIST_DIGIT_RULE_[string toupper $value]]

		}

		HotShots {

			set attrs [list]

			foreach attr [split $value ,] {

				lappend attrs [ob_xl::sprintf $lang \
					IGF_HIST_HOTSHOTS_RULE_[string toupper $attr]]

			}

			return [join $attrs {, }]

		}

		default {

			return $value

		}

	}

}


proc ob_hist::_IGF_format_cards { hand { del , } {size ""} } {

	if { $del ne "" } {

		set hand [split $hand $del]

	}
	if {$size == ""} {
		set size_str ""
	} else {
		set size_str "size=$size"
	}
	set cards [list]

	foreach card $hand {

		foreach { rank suit deck } [split $card {}] break

		if { $rank eq "X" } {

			lappend cards [ob_xl::sprintf [ob_xl::get name] \
										  IGF_HIST_VPOKER_JOKER]

		} else {

			if { $rank eq "T" } { set rank 10 }

			switch -- $suit {

				S { set suit "<font $size_str>&spades;</font>" }
				H { set suit "<font $size_str color=red>&hearts;</font>" }
				D { set suit "<font $size_str color=red>&diams;</font>"  }
				C { set suit "<font $size_str>&clubs;</font>"  }

			}
			lappend cards [subst {$rank&nbsp;$suit}]

		}

	}

	return $cards

}


proc ob_hist::_IGF_int_to_card { ints ace_high } {

	#
	# Mod'ing the rank by 13 means that the highest card, A or K, == 0.
	#
	if { $ace_high } {
		set ranks [list A 2 3 4 5 6 7 8 9 T J Q K]
	} else {
		set ranks [list K A 2 3 4 5 6 7 8 9 T J Q]
	}
	set suits [list C H S D]
	set cards [list]

	foreach c $ints {

		set    card [lindex $ranks [expr { $c % 13 }]]
		append card [lindex $suits [expr { $c % 52 / 13 }]]
		append card [expr { 1 + $c % 52 }]

		lappend cards $card

	}

	return $cards

}



#-------------------------------------------------------------------------
# Startup
#--------------------------------------------------------------------------

# automatic startup
ob_hist::_IGF_init
