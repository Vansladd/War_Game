# $Id: bet_rcpt.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# =======================================================================
#
# Copyright (c) Orbis Technology 2001. All rights reserved.
#
#
# A generic set of bet receipt functions.
#
# =======================================================================
#
# What the new error codes should effectively translate to in txlateval (English)
#
#	ACCT_NO_SUB_DATA    {Unable to retrieve your subscription details at this time, please try again later.}
#	ACCT_NO_BET_DETS    {Unable to retrieve the details for your bet at this time, please try again later.}
#
# Other translations required
#
#	CUST_ACCT_CHEQUE   {Cheque}
#	CUST_ACCT_FREE_BET {Free bet}
#	CUST_ACCT_PRIZE    {A non-cash Prize}
#	CUST_ACCT_PICTURE  {Picture}
#	CUST_ACCT_BALL     {ball}
#	CUST_ACCT_MATCH    {Match}
#	CUST_ACCT_VERSUS   {Vs}
#	CUST_ACCT_HOME_WIN {Home Win}
#	CUST_ACCT_AWAY_WIN {Away Win}
#	CUST_ACCT_DRAW     {Draw}
#	CUST_ACCT_VOID     {Void}

proc init_rcpt {} {

	prep_rcpt_qrys
}

proc prep_rcpt_qrys {} {

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		db_store_qry rcpt_bet_detail {
			SELECT
			b.bet_id,
			b.settled        bet_settled,
			b.settled_at     bet_settled_at,
			b.settle_info    bet_settle_info,
			b.receipt        receipt,
			b.cr_date        bet_date,
			b.acct_id        bet_acct_id,
			b.stake          stake,
			b.stake_per_line stake_per_line,
			b.tax_type       bet_tax_type,
			b.tax            tax,
			b.token_value	 token_value,
			b.max_payout     bet_max_payout,
			b.tax_rate       bet_tax_rate,
			b.winnings       bet_winnings,
			b.refund         bet_refund,
			b.bet_type       bet_type,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.leg_type,

			c.name        cl_name,
			t.name        type_name,
			e.desc        ev_name,
			e.venue       ev_venue,
			e.country     ev_country,
			e.start_time  ev_time,
			e.result_conf ev_result_conf,
			m.name        mkt_name,
			s.desc        oc_name,
			s.result      oc_result,
			s.place       oc_place,
			o.price_type,
			o.o_num       price_num,
			o.o_den       price_den,
			o.leg_no,
			o.leg_sort,
			o.part_no

			FROM
			tBet b,
			tObet o,
			tEvOc s,
			tEvMkt m,
			tEv e,
			tEvType t,
			tEvClass c

			WHERE
			b.acct_id   = ? and
			b.bet_id    = ? and
			b.bet_id    = o.bet_id and
			o.ev_oc_id  = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			s.ev_id     = e.ev_id and
			t.ev_type_id   = e.ev_type_id and
			c.ev_class_id  = t.ev_class_id

			ORDER BY
			o.leg_no, o.part_no
		}
	} else {
		db_store_qry rcpt_bet_detail {
			SELECT
			b.bet_id,
			b.settled        bet_settled,
			b.settled_at     bet_settled_at,
			b.settle_info    bet_settle_info,
			b.receipt        receipt,
			b.cr_date        bet_date,
			b.acct_id        bet_acct_id,
			b.stake          stake,
			b.stake_per_line stake_per_line,
			b.tax_type       bet_tax_type,
			b.tax            tax,
			b.max_payout     bet_max_payout,
			b.tax_rate       bet_tax_rate,
			b.winnings       bet_winnings,
			b.refund         bet_refund,
			b.bet_type       bet_type,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.leg_type,

			c.name        cl_name,
			t.name        type_name,
			e.desc        ev_name,
			e.venue       ev_venue,
			e.country     ev_country,
			e.start_time  ev_time,
			e.result_conf ev_result_conf,
			m.name        mkt_name,
			s.desc        oc_name,
			s.result      oc_result,
			s.place       oc_place,
			o.price_type,
			o.o_num       price_num,
			o.o_den       price_den,
			o.leg_no,
			o.leg_sort,
			o.part_no

			FROM
			tBet b,
			tObet o,
			tEvOc s,
			tEvMkt m,
			tEv e,
			tEvType t,
			tEvClass c

			WHERE
			b.acct_id   = ? and
			b.bet_id    = ? and
			b.bet_id    = o.bet_id and
			o.ev_oc_id  = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			s.ev_id     = e.ev_id and
			t.ev_type_id   = e.ev_type_id and
			c.ev_class_id  = t.ev_class_id

			ORDER BY
			o.leg_no, o.part_no
		}
	}


	db_store_qry rcpt_man_bet_detail {
		SELECT
			b.bet_id,
			b.settled        bet_settled,
			b.settled_at     bet_settled_at,
			b.settle_info    bet_settle_info,
			b.receipt        receipt,
			b.cr_date        bet_date,
			b.acct_id        bet_acct_id,
			b.stake          stake,
			b.stake_per_line stake_per_line,
			b.tax_type       bet_tax_type,
			b.tax            tax,
			b.max_payout     bet_max_payout,
			b.tax_rate       bet_tax_rate,
			b.winnings       bet_winnings,
			b.refund         bet_refund,
			b.bet_type       bet_type,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.leg_type,
			b.token_value,
			o.desc_1,
			o.desc_2,
			o.desc_3,
			o.desc_4,
			o.to_settle_at
		FROM
			tBet b,
			tManOBet o
		WHERE
			b.acct_id   = ? and
			b.bet_id    = ? and
			b.bet_id    = o.bet_id
	}


	if {[OT_CfgGetTrue HAS_XGAMES]} {
		if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE"} {
			db_store_qry rcpt_xgame_detail {
				SELECT	  name			bet_name
					, s.cr_date		bet_date
					, num_subs
					, free_subs
					, s.xgame_sub_id	bet_id
					, picks
					, acct_id		bet_acct_id
					, stake_per_bet		stake_per_line
					, gd.sort		bet_type
					, s.token_value		token_value
				FROM	  tXGameSub s
					, tXGame g
					, tXGameDef gd
				WHERE	gd.sort = g.sort
				and	g.xgame_id = s.xgame_id
				and	s.acct_id   = ?
				and	s.xgame_sub_id = ?
			}
		} else {
			db_store_qry rcpt_xgame_detail {
				SELECT
				name			bet_name,
				s.cr_date		bet_date,
				num_subs,
				free_subs,
				s.xgame_sub_id	bet_id,
				picks,
				acct_id        bet_acct_id,
				stake_per_bet  stake_per_line,
				gd.sort        bet_type
				from tXGameSub s,
				tXGame g,
				tXGameDef gd
				where
				gd.sort = g.sort and
				g.xgame_id = s.xgame_id and
				s.acct_id   = ? and
				s.xgame_sub_id = ?
			}
		}

		db_store_qry rcpt_xgame_sub_detail {
			SELECT
			xgame_bet_id,
			b.xgame_id,
			name,
			b.cr_date 	bet_date,
			stake,
			winnings,
			paymethod,
			refund,
			b.settled,
			b.picks,
			gd.sort,
			shut_at,
			draw_at,
			results,
			s.num_lines,
			s.stake_per_line,
			s.stake_per_bet
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
			s.acct_id = ?
		}

		db_store_qry rcpt_xgame_bet_detail {
			select xgame_bet_id  bet_id
				, b.xgame_id
				, s.xgame_sub_id sub_id
				, num_subs
				, name
				, b.cr_date      bet_cr_date
				, stake
				, winnings
				, paymethod
				, refund
				, b.settled
				, b.picks
				, has_balls
				, gd.sort
				, shut_at
				, draw_at
				, results
			FROM  tXGameBet b
				, tXGameSub s
				, tXGame g
				, tXGameDef gd
			WHERE	g.xgame_id = b.xgame_id
			and	b.xgame_sub_id = s.xgame_sub_id
			and	gd.sort = g.sort
			and 	b.xgame_bet_id = ?
			and	s.acct_id = ?
		}
	}
}



# ======================================================================
# generate a BSEL array similar to that used by placebet
# so that the same code can be used to bind data to the bet receipt
# ======================================================================


proc setup_acct_bet_rcpt {id acct_id} {

	global BSEL BET_TYPE LOGIN_DETAILS

	array set LEG_SORTS_TXT [list    "" ""\
					 -- ""\
					 SF "Forecast" \
					 RF "Reverse Forecast" \
					 CF "Combination Forecast"\
					 TC "Tricast"\
					 CT "Combination Tricast"\
					 SC "Scorecast"\
					 AH "Asian Handicap"\
					 WH "Western Handicap"\
					 OU "Over Under"\
			 CW "Continuous Win"]

	catch {unset BSEL}

	if {[catch {set rs [db_exec_qry rcpt_bet_detail $acct_id $id]} msg]} {
		ob::log::write ERROR {Failed to exec bet detail qry: $msg}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}



	if {[db_get_nrows $rs] < 1} {
		ob::log::write ERROR {Failed to retrieve details for bet id ($id)}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}

	#
	# store the bet information
	#
	set bk "0,bets,0"

	set BSEL($bk,bet_id)         [db_get_col $rs bet_id]
	set BSEL($bk,bet_date)       [html_date [db_get_col $rs bet_date] shrttime]
	set BSEL($bk,bet_date_informix) [db_get_col $rs bet_date]
	set BSEL($bk,receipt)        [db_get_col $rs receipt]
	set BSEL($bk,stake)          [print_ccy [db_get_col $rs stake] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,stake_per_line) [print_ccy [db_get_col $rs stake_per_line] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,tax_rate)       [db_get_col $rs bet_tax_rate]
	set BSEL($bk,tax_type)       [db_get_col $rs bet_tax_type]
	set BSEL($bk,tax)            [print_ccy [db_get_col $rs tax] $LOGIN_DETAILS(CCY_CODE)]

	set BSEL($bk,settled)        [db_get_col $rs bet_settled]
	set BSEL($bk,settled_at)     [db_get_col $rs bet_settled_at]
	set BSEL($bk,settle_info)    [XL [db_get_col $rs bet_settle_info]]
	set BSEL($bk,winnings)       [print_ccy [db_get_col $rs bet_winnings] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,refund)         [print_ccy [db_get_col $rs bet_refund] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,num_lines)      [db_get_col $rs num_lines]
	set BSEL($bk,num_legs)       [db_get_col $rs num_legs]
	set BSEL($bk,num_selns)      [db_get_col $rs num_selns]
	set BSEL($bk,num_lines_win)  [db_get_col $rs num_lines_win]
	set BSEL($bk,num_lines_lose) [db_get_col $rs num_lines_lose]
	set BSEL($bk,num_lines_void) [db_get_col $rs num_lines_void]
	set BSEL($bk,max_payout)     [db_get_col $rs bet_max_payout]
	set BSEL($bk,bet_placed)         1
	set bet_type                 [db_get_col $rs bet_type]

	set BSEL($bk,bet_type)       $bet_type
	set BSEL($bk,bet_name)       [XL $BET_TYPE($bet_type,bet_name)]

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set BSEL($bk,token_value)    [db_get_col $rs token_value]
		set BSEL($bk,token_value_disp)   $BSEL($bk,token_value)
		set BSEL($bk,total_paid)	 [print_ccy [max [expr {[db_get_col $rs tax] + [db_get_col $rs stake] - $BSEL($bk,token_value)}] 0] ]
	} else {
		set BSEL($bk,total_paid)	 [print_ccy [expr {[db_get_col $rs tax] + [db_get_col $rs stake]}]]
	}

	#
	# now store leg and selection info
	#

	set nselns  [db_get_col $rs num_selns]
	for {set i 0} {$i < $nselns} {incr i} {

		set leg_no  [db_get_col $rs $i leg_no]
		set part_no [db_get_col $rs $i part_no]

		# can do this as selections are ordered in leg/part order
		# db leg_no & part_no start at 1 whereas we start as 0

		set BSEL(0,num_legs)          $leg_no
		# decrement the leg and part_nos as we count like C
		incr leg_no  -1
		set BSEL(0,$leg_no,num_parts) $part_no
		incr part_no -1


		set BSEL(0,$leg_no,leg_sort)  [db_get_col $rs $i leg_sort]
		set BSEL(0,$leg_no,leg_sort_desc) [XL $LEG_SORTS_TXT($BSEL(0,$leg_no,leg_sort))]

		set pk "0,$leg_no,$part_no"

		set BSEL($pk,cl_name)    [XL [db_get_col $rs $i cl_name]]
		set BSEL($pk,type_name)  [XL [db_get_col $rs $i type_name]]
		set BSEL($pk,ev_name)    [XL [db_get_col $rs $i ev_name]]
		set BSEL($pk,ev_country) [XL [db_get_col $rs $i ev_country]]
		set BSEL($pk,ev_venue)   [XL [db_get_col $rs $i ev_venue]]
		set BSEL($pk,ev_time)    [html_date [db_get_col $rs $i ev_time] shrttime]
		set BSEL($pk,ev_time_informix) [db_get_col $rs $i ev_time]
		set BSEL($pk,mkt_name)   [XL [db_get_col $rs $i mkt_name]]
		set BSEL($pk,oc_name)    [XL [db_get_col $rs $i oc_name]]
		set BSEL($pk,oc_result)  [db_get_col $rs $i oc_result]
		set BSEL($pk,oc_place)   [db_get_col $rs $i oc_place]
		set BSEL($pk,leg_type)   [db_get_col $rs $i leg_type]
		set BSEL($pk,leg_no)     [db_get_col $rs $i leg_no]
		set BSEL($pk,part_no)    [db_get_col $rs $i part_no]


		set prc_type [db_get_col $rs $i price_type]
		set prc_num  [db_get_col $rs $i price_num]
		set prc_den  [db_get_col $rs $i price_den]

		set BSEL($pk,price) [mk_bet_price_str $prc_type\
						 $prc_num $prc_den\
						 $prc_num $prc_den]
	}
	set BSEL(0,num_bets_avail) 1
	set BSEL(sks) 0

	bind_rcpt_info

	tpBindString top_receipt $BSEL(0,bets,0,receipt)
	if {[db_get_col $rs bet_settled] == "Y"} {
		tpSetVar BetSettled 1

		tpBindVar NL_WIN   BSEL num_lines_win   sk bets bet_idx
		tpBindVar NL_LOSE  BSEL num_lines_lose  sk bets bet_idx
		tpBindVar NL_VOID  BSEL num_lines_void  sk bets bet_idx

		tpBindVar WINNINGS BSEL winnings    sk bets bet_idx
		tpBindVar REFUND   BSEL refund      sk bets bet_idx
		tpBindVar STL_INFO BSEL settle_info sk bets bet_idx

	} else {
		tpSetVar BetSettled 0
	}

	db_close $rs


	return 1
}

# ======================================================================
# generate a BSEL array for an external game subscription receipt
# ======================================================================


proc setup_acct_xgame_sub_rcpt {id acct_id} {

	global BSEL BET_TYPE LOGIN_DETAILS PLATFORM

	if {[info exists PLATFORM]} {
		tpBindString PLATFORM $PLATFORM
	}

	tpBindString ACCT_NO $acct_id

	catch {unset BSEL}

	if {[catch {set rs [db_exec_qry rcpt_xgame_detail $acct_id $id]} msg]} {
		ob::log::write ERROR {Failed to exec bet detail qry: $msg}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}


	if {[db_get_nrows $rs] < 1} {
		ob::log::write ERROR {Failed to retrieve details for bet id ($id)}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}

	#
	# store the bet information
	#
	set bk "0,bets,0"

	set BSEL($bk,bet_id)         [db_get_col $rs bet_id]
	set BSEL($bk,bet_date)       [html_date [db_get_col $rs bet_date] shrttime]
	set BSEL($bk,bet_date_informix) [db_get_col $rs bet_date]
	set num_subs			[db_get_col $rs num_subs]
	set free_subs			[db_get_col $rs free_subs]
	set BSEL($bk,subs_total)  $num_subs
	set BSEL($bk,stake_per_line) [print_ccy [db_get_col $rs stake_per_line] $LOGIN_DETAILS(CCY_CODE)]
	set stake [expr {[db_get_col $rs stake_per_line] * ($num_subs - $free_subs)}]
	set BSEL($bk,stake)	 [print_ccy $stake $LOGIN_DETAILS(CCY_CODE) ]
	set BSEL($bk,bet_type)       [db_get_col $rs bet_type]

	set BSEL($bk,bet_name)       [XL [db_get_col $rs bet_name]]

	if {[OT_CfgGet ENABLE_FREEBETS "FALSE"] == "TRUE" || [OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set BSEL($bk,token_value)    [db_get_col $rs token_value]
		set BSEL($bk,token_value_disp)    [print_ccy $BSEL($bk,token_value) $LOGIN_DETAILS(CCY_CODE)]
		set BSEL($bk,stake)	 [print_ccy [max [expr {$stake - $BSEL($bk,token_value)}] 0] ]
	}

	db_close $rs

	#
	# now get subscription info
	#

	if {[catch {set rs [db_exec_qry rcpt_xgame_sub_detail $id $acct_id ]} msg]} {
		ob::log::write ERROR {Failed to exec bet sub detail qry: $msg}
		err_add [ml_printf ACCT_NO_SUB_DATA]
		return 0
	}

	set subs_conv [db_get_nrows $rs]

	set BSEL($bk,subs_converted)  $subs_conv
	set BSEL($bk,subs_left)  [expr {$num_subs - $subs_conv}]

	for {set i 0} {$i < $subs_conv} {incr i} {

		set BSEL(0,bets,$i,bet_id)    [db_get_col $rs $i xgame_bet_id]
		set BSEL(0,bets,$i,line_date) [db_get_col $rs $i bet_date]
		set BSEL(0,bets,$i,draw_at) [db_get_col $rs $i draw_at]
		set BSEL(0,bets,$i,line_stake) [print_ccy [db_get_col $rs $i stake] $LOGIN_DETAILS(CCY_CODE)]

		set BSEL(0,bets,$i,line_refund) [print_ccy [db_get_col $rs $i refund] $LOGIN_DETAILS(CCY_CODE)]

		set BSEL(0,bets,$i,num_lines)       [db_get_col $rs num_lines]
		set BSEL(0,bets,$i,stake_per_line)       [db_get_col $rs stake_per_line]
		set stake_per_bet [db_get_col $rs stake_per_bet]

		set BSEL(0,bets,$i,stake_per_bet)	[print_ccy $stake_per_bet $LOGIN_DETAILS(CCY_CODE)]
		set BSEL(0,bets,$i,total_cost) [print_ccy [expr $stake_per_bet*$num_subs] $LOGIN_DETAILS(CCY_CODE)]

		set BSEL(0,bets,$i,paymethod) [db_get_col $rs $i paymethod]

		if {$BSEL(0,bets,$i,paymethod) == "L"} {
			set BSEL(0,bets,$i,winnings)    [ml_printf CUST_ACCT_CHEQUE]
		} elseif {$BSEL(0,bets,$i,paymethod) == "F"} {
			set BSEL(0,bets,$i,winnings)    [ml_printf CUST_ACCT_FREE_BET]
		} elseif {$BSEL(0,bets,$i,paymethod) == "P"} {
			set BSEL(0,bets,$i,winnings)    [ml_printf CUST_ACCT_PRIZE]
		} else {
			set BSEL(0,bets,$i,winnings)    [print_ccy [db_get_col $rs $i winnings] $LOGIN_DETAILS(CCY_CODE)]
		}

	}

	tpBindVar BET_ID        BSEL bet_id      0 bets bet_idx
	tpBindVar LINE_DATE     BSEL line_date   0 bets bet_idx
	tpBindVar DRAW_AT       BSEL draw_at     0 bets bet_idx
	tpBindVar LINE_STAKE    BSEL line_stake  0 bets bet_idx
	tpBindVar LINE_REFUND   BSEL line_refund 0 bets bet_idx
	tpBindVar LINE_WINNINGS BSEL winnings    0 bets bet_idx

	bind_rcpt_info

	db_close $rs


	return 1
}

# ======================================================================
# generate a BSEL array for an external game receipt
# ======================================================================

proc setup_acct_xgame_rcpt {id acct_id} {

	global BSEL BET_TYPE LOGIN_DETAILS

	if {[info exists PLATFORM]} {
		tpBindString PLATFORM $PLATFORM
	}

	catch {unset BSEL}

	if {[catch {set rs [db_exec_qry rcpt_xgame_bet_detail $id $acct_id]} msg]} {
		ob::log::write ERROR {Failed to exec bet detail qry: $msg}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}

	if {[db_get_nrows $rs] < 1} {
		ob::log::write ERROR {Failed to retrieve details for bet id ($id)}
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}

	#
	# store the bet information
	#
	set bk "0,bets,0"

	set BSEL($bk,bet_id)         [db_get_col $rs bet_id]
	set BSEL($bk,sub_id)         [db_get_col $rs sub_id]
	set BSEL($bk,game_id)        [db_get_col $rs xgame_id]
	set BSEL($bk,bet_date)       [html_date [db_get_col $rs bet_cr_date] shrttime]
	set BSEL($bk,bet_date_informix) [db_get_col $rs bet_cr_date]
	set BSEL($bk,stake)	 [print_ccy [db_get_col $rs stake] $LOGIN_DETAILS(CCY_CODE) ]
	set BSEL($bk,settled)        [db_get_col $rs settled]
	set BSEL($bk,winnings)       [print_ccy [db_get_col $rs winnings] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,refund)         [print_ccy [db_get_col $rs refund] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,bet_name)       [XL [db_get_col $rs name]]
	set BSEL($bk,bet_sort)       [db_get_col $rs sort]
	set BSEL($bk,draw_date)      [db_get_col $rs draw_at]
	set BSEL($bk,enc_draw_date)  [urlencode $BSEL($bk,draw_date)]
	set BSEL($bk,num_subs)       [db_get_col $rs num_subs]
	set BSEL($bk,has_balls)      [db_get_col $rs has_balls]
	set BSEL($bk,results)      	 [db_get_col $rs results]
	set BSEL($bk,enc_results)    [urlencode $BSEL($bk,results)]
	set BSEL($bk,picks)      	 [db_get_col $rs picks]

	set BSEL($bk,paymethod) [db_get_col $rs paymethod]

	set BSEL($bk,winnings)    [print_ccy [db_get_col $rs winnings] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,formatted_picks) [format_picks $BSEL($bk,picks) $BSEL($bk,game_id) $BSEL($bk,bet_sort)  $BSEL($bk,has_balls)]

	if {$BSEL($bk,results) != "" && $BSEL($bk,bet_sort) != "SATPOOL" && $BSEL($bk,bet_sort) != "MONPOOL"} {
		set BSEL($bk,correct_picks) [format_picks $BSEL($bk,results) $BSEL($bk,game_id) $BSEL($bk,bet_sort)  $BSEL($bk,has_balls)]
	}

	tpBindVar WINNINGS      BSEL winnings      sk bets bet_idx
	tpBindVar REFUND        BSEL refund        sk bets bet_idx
	tpBindVar SETTLED       BSEL settled       sk bets bet_idx
	tpBindVar DRAW_DATE     BSEL draw_date     sk bets bet_idx
	tpBindVar NUM_SUBS      BSEL num_subs      sk bets bet_idx
	tpBindVar SUB_ID        BSEL sub_id        sk bets bet_idx
	tpBindVar ENC_RESULTS   BSEL results       sk bets bet_idx
	tpBindVar ENC_DRAW_DATE BSEL enc_draw_date sk bets bet_idx

	bind_rcpt_info

	db_close $rs

	return 1
}


# ======================================================================
# generate a BSEL array for a manual bet receipt
# ======================================================================

proc setup_acct_man_bet_rcpt {id acct_id} {

	global BSEL LOGIN_DETAILS

	if {[info exists BSEL]} {
		unset BSEL
	}

	if [catch {set rs [db_exec_qry rcpt_man_bet_detail $acct_id $id]} msg] {
		OT_LogWrite 3 "Failed to exec bet detail qry: $msg"
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}


	if {[db_get_nrows $rs] < 1} {
		OT_LogWrite 3 "Failed to retrieve details for bet id ($id)"
		err_add [ml_printf ACCT_NO_BET_DETS]
		return 0
	}

	OT_LogWrite 10 ">>> Setting up Manual Bet Receipt"

	#
	# store the bet information
	#
	set bk "0,bets,0"

	set BSEL($bk,bet_id)         [db_get_col $rs bet_id]
	set BSEL($bk,bet_date)       [html_date [db_get_col $rs bet_date] shrttime]
	set BSEL($bk,bet_date_informix) [db_get_col $rs bet_date]
	set BSEL($bk,receipt)        [db_get_col $rs receipt]
	set BSEL($bk,stake)          [print_ccy [db_get_col $rs stake] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,stake_per_line) [print_ccy [db_get_col $rs stake_per_line] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,tax_rate)       [db_get_col $rs bet_tax_rate]
	set BSEL($bk,tax_type)       [db_get_col $rs bet_tax_type]
	set BSEL($bk,tax)            [print_ccy [db_get_col $rs tax]]

	set BSEL($bk,settled)        [db_get_col $rs bet_settled]
	set BSEL($bk,settled_at)     [db_get_col $rs bet_settled_at]
	set BSEL($bk,settle_info)    [db_get_col $rs bet_settle_info]
	set BSEL($bk,winnings)       [print_ccy [db_get_col $rs bet_winnings] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,refund)         [print_ccy [db_get_col $rs bet_refund] $LOGIN_DETAILS(CCY_CODE)]
	set BSEL($bk,num_lines)      [db_get_col $rs num_lines]
	set BSEL($bk,num_legs)       [db_get_col $rs num_legs]
	set BSEL($bk,num_selns)      [db_get_col $rs num_selns]
	set BSEL($bk,num_lines_win)  [db_get_col $rs num_lines_win]
	set BSEL($bk,num_lines_lose) [db_get_col $rs num_lines_lose]
	set BSEL($bk,num_lines_void) [db_get_col $rs num_lines_void]
	set BSEL($bk,max_payout)     [db_get_col $rs bet_max_payout]
	set BSEL($bk,bet_placed)     1
	set bet_type                 [db_get_col $rs bet_type]

	set BSEL($bk,bet_type)       $bet_type
	set BSEL($bk,bet_name)       "Manual Bet"

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		set BSEL($bk,token_value)    [db_get_col $rs token_value]
		set BSEL($bk,token_value_disp)    [print_ccy $BSEL($bk,token_value)]
		set BSEL($bk,total_paid)	 [print_ccy [max [expr [db_get_col $rs tax] + [db_get_col $rs stake] - $BSEL($bk,token_value)] 0] ]
	} else {
		set BSEL($bk,total_paid)	 [print_ccy [expr [db_get_col $rs tax] + [db_get_col $rs stake]]]
	}

	set BSEL($bk,desc_1)     [db_get_col $rs desc_1]
	set BSEL($bk,desc_2)     [db_get_col $rs desc_2]
	set BSEL($bk,desc_3)     [db_get_col $rs desc_3]
	set BSEL($bk,desc_4)     [db_get_col $rs desc_4]
	set BSEL($bk,to_settle_at)  [db_get_col $rs to_settle_at]

	set BSEL(0,num_bets_avail) 1
	set BSEL(sks) 0

	bind_rcpt_info


	tpBindString top_receipt $BSEL(0,bets,0,receipt)
	if {[db_get_col $rs bet_settled] == "Y"} {
		tpSetVar BetSettled 1

		tpBindVar NL_WIN   BSEL num_lines_win   sk bets bet_idx
		tpBindVar NL_LOSE  BSEL num_lines_lose  sk bets bet_idx
		tpBindVar NL_VOID  BSEL num_lines_void  sk bets bet_idx

		tpBindVar WINNINGS BSEL winnings    sk bets bet_idx
		tpBindVar REFUND   BSEL refund      sk bets bet_idx
		tpBindVar STL_INFO BSEL settle_info sk bets bet_idx

	} else {
		tpSetVar BetSettled 0
	}

	db_close $rs

	tpSetVar ManualBet 1

	return 1
}


# ======================================================================
# bet receipt called after bet placement
# ======================================================================

proc go_bet_rcpt {{popup ""}} {

	global BSEL LOGIN_DETAILS

	tpSetVar BetSettled 0

	if {![info exists BSEL(BET_IDS)]} {
		err_add [ml_printf ACCT_NO_BET_DETS]
		play_template Error
		return 0
	}

	if {[OT_CfgGet POTENTIAL_WIN_CALCULATOR 0] == 1} {
		calculate_potential_win
	}

	bind_rcpt_info

	play_file bet_receipt${popup}.html

	unset BSEL
}

# Use override if the bets have not yet been placed
proc calculate_potential_win {{sk 0} {override 0}} {

	global BSEL LOGIN_DETAILS

	for {set i 0} {$i < $BSEL($sk,num_bets_avail)} {incr i} {

		if {$BSEL($sk,bets,$i,bet_placed) || $override} {

			set result [calculate_potential_win_id $sk $i]

			if {$result == "FAILED"} {
				set BSEL($sk,bets,$i,potential_win_avail) 0
			} else {
				set BSEL($sk,bets,$i,potential_win_avail) 1
				set BSEL($sk,bets,$i,potential_win) $result
				set BSEL($sk,bets,$i,potential_win_disp) [print_ccy $result $LOGIN_DETAILS(CCY_CODE)]
			}
		}
	}
}

proc calculate_potential_win_id {sk bet_id} {

	global BSEL CUST

	set bet_type 	$BSEL($sk,bets,$bet_id,bet_type)
	if {![info exists BSEL($sk,bets,$bet_id,stake_per_line)]} {
		return FAILED
	}
	set spl 		$BSEL($sk,bets,$bet_id,stake_per_line)
	set leg_type 	$BSEL($sk,bets,$bet_id,leg_type)

	set prices [list]
	set ew_fac [list]
	set ah_val [list]

	set max_payout ""

	# figure out the prices..
	for {set i 0} {$i < $BSEL($sk,num_legs)} {incr i} {

		if {$BSEL($sk,$i,num_parts) != 1 && ($BSEL($sk,$i,leg_sort) != "SC")} {
			# can't do legs with more than one part, with the exception of scorecasts
			return FAILED
		}

		set p 0

		# check price type
		set price_type 		$BSEL($sk,$i,$p,price_type)
		if {$price_type == "S"} {
			# only works for live prices
			return FAILED
		}

		set lp_num 	$BSEL($sk,$i,$p,lp_num)
		set lp_den 	$BSEL($sk,$i,$p,lp_den)
		lappend prices  [list $lp_num $lp_den]


		set ew_fac_num 	$BSEL($sk,$i,$p,ew_fac_num)
		set ew_fac_den	$BSEL($sk,$i,$p,ew_fac_den)

		if {($leg_type == "E" || $leg_type == "P") && ($ew_fac_num == "" || $ew_fac_den == "")} {
			# only works for each-way/place bets if ew prices are available
			return FAILED
		}
		lappend ew_fac [list $ew_fac_num $ew_fac_den]

		if {$BSEL($sk,$i,leg_sort)=="AH" || $BSEL($sk,$i,leg_sort)=="A2"} {
			lappend ah_val $BSEL($sk,$i,$p,hcap_value)
		} else {
			lappend ah_val ""
		}

		# check the max_payout for this selection
		set ev_max_payout $BSEL($sk,$i,$p,max_payout)
		if {$ev_max_payout != "" && ($max_payout > $ev_max_payout || $max_payout == "")} {
			set max_payout $ev_max_payout
		}
	}

	if {$leg_type == "E" || $leg_type == "P"} {
		set each_way_fac $ew_fac
	} else {
		set each_way_fac ""
	}

	set potential_win [could_win $bet_type $spl $leg_type $prices $each_way_fac $ah_val]

	# convert the maximum payout to users currency
	set max_payout [expr {floor(100.0 * $max_payout * [::OB_ccy::rate $CUST(ccy_code)]) / 100.0}]

	if {$max_payout != "" && $max_payout < $potential_win} {
		set potential_win $max_payout
	}

	return $potential_win
}


#
# Generates list of selections
#
proc format_picks {picks xgame_id xgame_sort hasballs} {

	global acQRYS xgQRYS

	# Pools games results have multiple strings of picks, separated by 'x'
	if {[lsearch -exact [list SATPOOL MONPOOL VPOOLSM VPOOLS10 VPOOLS11] $xgame_sort] >= 0} {
		regsub -all "x" $picks "|" picks
	}

	set mypicks [split $picks "|"]

	set picklist ""

	if {$hasballs=="N"} {
		lappend picklist [join $mypicks ", "]
		return $picklist
	}

	if {$xgame_sort=="TOPSPOT"} {
		foreach p [split $picks "|"] {
			set pair [split $p "_"]
			set picture [lindex $pair 0]
			set ball [lindex $pair 1]
			lappend picklist "[ml_printf CUST_ACCT_PICTURE] $picture, [ml_printf CUST_ACCT_BALL] $ball"
		}
	} else {
		set rs [ob_get_balls_for_xgame $xgame_id]
		set nrows [db_get_nrows $rs]
		for {set r 0} {$r < $nrows} {incr r} {
			set text [db_get_col $rs $r ball_name]
			set ball_no [db_get_col $rs $r ball_no]
			switch -- $xgame_sort {
				BIGMATCH {
					set ballname($ball_no) $text
				}
				MYTH {
					set i 0
					foreach hdav {"[ml_printf CUST_ACCT_HOME_WIN]" "[ml_printf CUST_ACCT_DRAW]" "[ml_printf CUST_ACCT_AWAY_WIN]" "[ml_printf CUST_ACCT_VOID]"} {
						set ballname($ball_no$i) "[ml_printf CUST_ACCT_MATCH] $ball_no: $hdav "
						incr i
					}
				}
				PREMIER10 {
					set b [split $text "|"]
					set ballname($ball_no) "[lindex $b 0] [ml_printf CUST_ACCT_VERSUS] [lindex $b 1]"
					switch -- [string trim [lindex $b 2]] {
						Draw {
							set match($ball_no) [ml_printf CUST_ACCT_DRAW]
						}
						Away {
							set match($ball_no) [ml_printf CUST_ACCT_AWAY_WIN]
						}
						Home {
							set match($ball_no) [ml_printf CUST_ACCT_HOME_WIN]
						}
					}
				}
				GOALRUSH {
					set b [split $text "|"]
					set ballname($ball_no) "[lindex $b 0] vs [lindex $b 1]"
				}
				default {
					regexp {([^\|]+)\|(.+)} $text match team1 team2
					set ballname($ball_no) "($ball_no) $team1 [ml_printf CUST_ACCT_VERSUS] $team2"
				}
			}
		}
		db_close $rs

		set r 0
		set m 1
		foreach p $mypicks {
			if {$xgame_sort == "PREMIER10"} {
				if {$p == "V"} {
					lappend picklist "$ballname($m) [ml_printf {Void}]"
				} else {
					lappend picklist "$ballname($m) $match($p)"
				}
				set m [expr {$m + 3}]
			} elseif {$xgame_sort == "GOALRUSH"} {
				set bnum [string index $p 0]
				set res [string index $p 1]
				if {$res != "V"} {
					set res [expr {$res - 1}]
					if {$res == 5} {
						append res "+"
					}
				}
				if {$res == 1} {
					set goal "goal"
				} else {
					set goal "goals"
				}

				if {$res!="V"} {
					lappend picklist "$ballname($bnum) $res $goal"
				} else {
					lappend picklist "$ballname($bnum) Void"
				}

			} else {
				#Not Prem 10 or Goalrush
				if {$p != ""} {
					lappend picklist $ballname($p)
				}
			}
			incr r
		}
	}

	return $picklist
}


proc bind_rcpt_info {} {

	global CUST BSEL

	tpSetVar sk 0
	tpSetVar b  b
	tpSetVar 0  0
	tpSetVar bets bets

	tpBindVar EV_NAME          BSEL ev_name          sk_idx leg_idx 0
	tpBindVar TP_NAME          BSEL type_name        sk_idx leg_idx 0
	tpBindVar CL_NAME          BSEL cl_name          sk_idx leg_idx 0
	tpBindVar EV_TIME          BSEL ev_time          sk_idx leg_idx 0
	tpBindVar EV_TIME_INFORMIX BSEL ev_time_informix sk_idx leg_idx 0
	tpBindVar MKT_NAME         BSEL mkt_name         sk_idx leg_idx 0
	tpBindVar LEG_SORT         BSEL leg_sort_desc    sk_idx leg_idx
	tpBindVar OC_NAME          BSEL oc_name          sk_idx leg_idx pt_idx
	tpBindVar OC_PRC           BSEL price            sk_idx leg_idx pt_idx

	tpBindVar BIR_INDEX           BSEL bir_index            sk_idx leg_idx 0

	tpBindVar RECEIPT             BSEL receipt             sk_idx bets bet_idx
	tpBindVar BET_ID              BSEL bet_id              sk_idx bets bet_idx
	tpBindVar BET_TYPE            BSEL bet_name            sk_idx bets bet_idx
	tpBindVar SUBS_CONVERTED      BSEL subs_converted      sk_idx bets bet_idx
	tpBindVar SUBS_LEFT           BSEL subs_left           sk_idx bets bet_idx
	tpBindVar BET_DATE            BSEL bet_date            sk_idx bets bet_idx
	tpBindVar BET_DATE_INFORMIX   BSEL bet_date_informix   sk_idx bets bet_idx
	tpBindVar STAKE_PER_LINE      BSEL stake_per_line      sk_idx bets bet_idx
	tpBindVar NUM_LINES           BSEL num_lines           sk_idx bets bet_idx
	tpBindVar STAKE               BSEL stake               sk_idx bets bet_idx
	tpBindVar TAX                 BSEL tax                 sk_idx bets bet_idx
	tpBindVar TAX_TYPE            BSEL tax_type            sk_idx bets bet_idx
	tpBindVar TAX_RATE            BSEL tax_rate            sk_idx bets bet_idx
	tpBindVar TOTAL_PAID          BSEL total_paid          sk_idx bets bet_idx
	tpBindVar STAKE_PER_LINE_DISP BSEL stake_per_line_disp sk_idx bets bet_idx
	tpBindVar STAKE_DISP          BSEL stake_disp          sk_idx bets bet_idx
	tpBindVar TAX_DISP            BSEL tax_disp            sk_idx bets bet_idx
	tpBindVar TOTAL_PAID_DISP     BSEL total_paid_disp     sk_idx bets bet_idx

	tpBindVar DESC1         BSEL desc_1          sk bets bet_idx
	tpBindVar DESC2         BSEL desc_2          sk bets bet_idx
	tpBindVar DESC3         BSEL desc_3          sk bets bet_idx
	tpBindVar DESC4         BSEL desc_4          sk bets bet_idx
	tpBindVar SETTLE_AT     BSEL to_settle_at    sk bets bet_idx

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" } {
		tpBindVar TOKEN_VALUE BSEL token_value   sk_idx bets bet_idx
		tpBindVar TOKEN_VALUE_DISP BSEL token_value_disp sk_idx bets bet_idx
	}

	if {[OT_CfgGet POTENTIAL_WIN_CALCULATOR 0] == 1} {
		tpBindVar POTENTIAL_WIN_AVAIL BSEL potential_win_avail   sk_idx bets bet_idx
		tpBindVar POTENTIAL_WIN BSEL potential_win sk_idx bets bet_idx
		tpBindVar POTENTIAL_WIN_DISP BSEL potential_win_disp sk_idx bets bet_idx
	}
}

proc array_print {array_name} {

	upvar #0 $array_name array_name_local

	ob::log::write DEV {======================}
	ob::log::write DEV {Printing contents of $array_name:}
	ob::log::write_array DEV array_name_local
	ob::log::write DEV {======================}
}
