# ==============================================================
# $Id: tb_statement_build.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

#
# WARNING: file will be initialised at the end of the source
#
package require smtp
package require mime


namespace eval tb_statement_build {

# supported j_op_types:
# DEP
# WTD
# RWTD
# DREF
# WREF
# DRES
# WRES
# DCAN
# WCAN
# SSTK
# SCAN
# SPRF
# BSTK
# BSTL
# BWIN
# BRFD
# BUST
# BURF
# BUWN
# MAN
# XFER
# LB--
# LB++
# NBST
# NBWN
# XSIN
# XSOT
# XSRF
# CGSK
# CGWN
# CGPS
# CGPW
# BXCG (Bet Exchange Charge)
# ALRT (Alerts)
# COMM

namespace export init_tb_statement_build


#
# statement generation
#
namespace export get_stmt_data
namespace export write_stmt_to_file

variable ROW_PROCS
set ROW_PROCS [list]

variable SPECIAL_PRICE
array set SPECIAL_PRICE\
	[list 13/8 2.62 15/8 2.87 11/8 2.37 8/13 1.61 2/7 1.28 1/8 1.12]



proc init_tb_statement_build {} {

	OT_LogWrite 5 "==> init_tb_statement_build"

	global SHARED_SQL

	set SHARED_SQL(get_message_xl) {
		select x.xlation_1,
			   x.xlation_2,
			   x.xlation_3,
			   x.xlation_4
		from   tXlateCode c, tXlateVal x
		where  c.code_id = x.code_id
		and    c.code = ?
		and    x.lang = ?
	}


		# If a second customer address table is used this query returns
		# the address from that table if one exists for the customer otherwise
		# it returns the tCustomerReg Address
		set SHARED_SQL(tb_stmt_get_header) {
		select
			a.acct_type,
			c.acct_no,
			c.cust_id,
			c.username,
			c.country_code,
			r.title,
			r.fname,
			r.lname,
			r.addr_street_1 As addr_street_1,
			r.addr_street_2 As addr_street_2,
			r.addr_street_3 As addr_street_3,
			r.addr_street_4 As addr_street_4,
			r.addr_city As addr_city,
			r.addr_country As addr_country,
			r.addr_postcode As addr_postcode,
			cn.country_name,
			r.addr_country As addr_country,
			co.desc cust_code,
			a.ccy_code,
			a.credit_limit
		from
			tCustomer c,
			tCustomerReg r,
			tCountry cn,
			tAcct a,
			outer tCustCode co
		where
			a.acct_id = ?
			and a.cust_id = c.cust_id
			and c.cust_id = r.cust_id
			and c.country_code = cn.country_code
			and r.code = co.cust_code
	}

	#
	# 3 parts:  a) gets all journal entries
	#           b) gets ap bets on settlement
	#           c) gets all settled bets
	#
	set SHARED_SQL(tb_stmt_get_stmt_entries) {
		select {INDEX(tjrnl ijrnl_x2)}
			cr_date as date,
			jrnl_id as id
		from
			tJrnl
		where
			acct_id = ? and
			cr_date >= ? and
			cr_date <= ?
		order by
			date, id
	}

	set SHARED_SQL(tb_stmt_get_xfer_entries) {
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tXsysXfer x,
			tXSysHostGrp g,
			tXSysHostGrpLk lk
		where
			j.j_op_ref_key = 'XSYS'
			and j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_id = x.xfer_id
			and x.system_id = lk.system_id
			and lk.group_id = g.group_id
			and g.desc = ?
			and g.type = 'SMT'
		order by date,id
	}

	set SHARED_SQL(tb_stmt_get_pmt_entries) {
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tPmt p
		where
				j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_key = 'GPMT'
			and j.j_op_ref_id  = p.pmt_id
		order by date,id
	}

	set SHARED_SQL(tb_stmt_get_bets_entries) {
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tBet b
		where
				j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_key = 'ESB'
			and j.j_op_type    = 'BSTK'
			and j.j_op_ref_id  = b.bet_id
		union
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tPoolBet pbt
		where
			    j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_type    = 'BSTK'
			and j.j_op_ref_key = 'TPB'
			and j.j_op_ref_id  = pbt.pool_bet_id
		order by date,id
	}

	set SHARED_SQL(tb_stmt_get_xgames_entries) {
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tXGameSub x
		where
				j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_key = 'XGAM'
			and j.j_op_type    = 'BSTK'
			and j.j_op_ref_id  = x.xgame_sub_id
		union
		select
			j.cr_date as date,
			j.jrnl_id as id
		from
			tJrnl j,
			tXGameBet x
		where
			    j.acct_id = ?
			and j.cr_date >= ?
			and j.cr_date <= ?
			and j.j_op_ref_key  = 'XGAM'
			and j.j_op_type     in ('BWIN','BRFD')
			and j.j_op_ref_id   = x.xgame_bet_id
		order by date,id
	}

	set SHARED_SQL(tb_stmt_get_chq_payee) {
		select
			NVL(c.payee,'') As payee
		from
			tCPMChq c,
			tAcct a
		where
			a.cust_id = c.cust_id and
			a.acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_jrnl_entry) {
		select
			cr_date,
			jrnl_id,
			line_id,
			desc,
			j_op_ref_key,
			j_op_ref_id,
			amount,
			j_op_type,
			balance
		from
			tJrnl
		where
			jrnl_id = ? and
			acct_id = ?
	}

	## no ref_key in journal of this type currently.
	set SHARED_SQL(tb_stmt_get_BXMX_details) {
		select
			e.desc as ev_name,
			t.name,
			x.bet_mkt_id as receipt
		from
			tEv as e,
			tEvMkt as m,
			tBxBetMktCan x,
			tEvtype as t
		where
			x.bet_mkt_id = ? and
			x.ev_mkt_id = m.ev_mkt_id and
			m.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
	}

	set SHARED_SQL(tb_stmt_get_acct_mkt_details) {
		select
			e.desc as ev_name,
			t.name,
			am.ev_mkt_id as receipt
		from
			tEv as e,
 			tEvMkt as m,
			tBxAcctMkt as am,
			tEvtype as t
		where
			am.ev_mkt_id = ? and
			am.acct_id = ? and
			am.ev_mkt_id = m.ev_mkt_id and
			m.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
	}

	## This potentially return more than one row.
	##
	set SHARED_SQL(tb_stmt_get_BXOM_details) {
		select
			e.desc as ev_name,
			t.name,
			b.bet_id as receipt
		from
			tEv as e,
			tEvMkt as m,
			tBxBetMod as bm,
			tBxBet as b,
			tEvoc as o,
			tEvType as t
		where
			bm.bet_mod_grp_id = ? and
			bm.bet_id = b.bet_id and
			b.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			m.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
	}


	## This potentially returns more than one row.
	##
	set SHARED_SQL(tb_stmt_get_BXON_details) {
		select
			e.desc as ev_name,
			t.name,
			b.bet_id as receipt
		from
			tEv as e,
			tEvMkt as m,
			tBxbet as b,
			tEvoc as o,
			tEvType as t
		where
			b.bet_grp_id = ? and
			b.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			m.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id
	}

	set SHARED_SQL(tb_stmt_get_jrnl_op) {
		select
			j_op_name
		from
			tJrnlOp
		where
			j_op_type = ?
	}

	set SHARED_SQL(tb_stmt_get_comm_details) {
		select
			p.source as channel,
			op.j_op_name as name
		from
			tpmt as p,
			tjrnl as j,
			tjrnlop as op
		where
			j.jrnl_id = ? and
			j.acct_id = ? and
			j.j_op_type = op.j_op_type and
			p.pmt_id = j.j_op_ref_id and
			j.j_op_type = 'COMM'
	}

	set SHARED_SQL(tb_stmt_get_mwtd_desc) {
		select
			extra_info
		from
			tManWtdRqst
		where
			mwr_id = ?
	}

	set SHARED_SQL(tb_stmt_get_mdep_desc) {
		select
			extra_info
		from
			tManDepRqst
		where
			mwr_id = ?
	}

	set SHARED_SQL(tb_stmt_get_madj_desc) {
		select
			m.desc,
			m.amount,
			mt.desc  as type,
			mst.desc as subtype
		from
			tManAdj              m,
			tManAdjType          mt,
			outer tManAdjSubType mst
		where
			    m.madj_id = ?
			and m.type    = mt.type
			and m.subtype = mst.subtype
			and m.type    = mst.type
	}

	set SHARED_SQL(tb_stmt_get_xsys_desc) {
		select
			s.system_id,
			x.desc,
			s.name
		from
			tjrnl j,
			tXSysHost s,
			tXSysXfer x
		where
			j.jrnl_id = ? and
			x.xfer_id = j.j_op_ref_id and
			s.system_id = x.system_id
	}


	set SHARED_SQL(tb_stmt_get_gpmt_desc) [subst {
		select
			[expr {
				[OT_CfgGet AUTO_CHQ_NO 0] ?
				{trim(m.desc||' '||nvl(q.chq_no, ''))} :
				{m.desc}
			}] as desc,
			m.pay_mthd,
			p.source,
			p.status
		from
			tPayMthd m,
			tPmt p,
		outer
			tPmtChq q
		where
			p.ref_key = m.pay_mthd and
			p.pmt_id = ? and
			p.pmt_id = q.pmt_id;
	}]

	set SHARED_SQL(tb_stmt_get_cggames_desc) {
		select
			s.stakes,
			g.display_name,
			s.source,
			g.name,
			g.cg_class game_class
		from
			tCGGameSummary as s,
			tCGGame as g,
			tCGGameVersion as v
		where
			s.cg_id = g.cg_id and
			g.cg_id = v.cg_id and
			s.version = v.version and
			s.cg_game_id = ?
	}

	set SHARED_SQL(igf_gbet_details_stmt) {
		select
			NVL(h.drawn, '-') as drawn,
			g.name as game_desc,
			p.name as bet_name,
			p.bet_type as bet_type,
			p.sub_bet_type as sub_bet_type,
			p.seln_1 as seln_1,
			b.seln as pick


		from
			tCgGameSummary as s,
			tCgBetHist as h,
			tCgAcct as a,
			tcgGame as g,
			tcgBetPayout as p,
			tcgBet as b
		where
			g.cg_id = s.cg_id and
			b.cg_game_id = s.cg_game_id and
			b.payout_id = p.payout_id and
			h.cg_game_id = s.cg_game_id and
			s.cg_acct_id = a.cg_acct_id and
			s.cg_game_id = ?
	}

	set SHARED_SQL(igf_keno_details_stmt) {

		select
			tCgKenoHist.drawn,
			tCgKenoHist.selected,
			tCgKenoHist.matches
		from
			tCgKenoHist
		where
			tCgKenoHist.cg_game_id = ?

	}

	set SHARED_SQL(igf_vkeno_details_stmt) {
		select
			h.drawn,
			h.selected,
			h.matches,
			h.is_reverse
		from
			tCgVKenoHist as h
		where
			h.cg_game_id = ?
	}

	set SHARED_SQL(igf_xslot_history_stmt) {

		select
			tcgxslothist.cr_date as date,
			tCGXSlotHist.stop,
			tCGGameSummary.stake_per_line,
			tCGGameSummary.winnings,
			tcgxslotdef.symbols
		from
			tCGXslotHist,
			tCGGameSummary,
			tCGXSlotDef
		where
			tCGXSlotHist.cg_game_id = ?
			and tCGGameSummary.cg_game_id = tCGXSlotHist.cg_game_id
			and tCGGameSummary.version = tCGXSlotDef.version
			and tCGGameSummary.cg_id = tCGXSlotDef.cg_id
	}

	set SHARED_SQL(igf_xslot_get_reels) {
		select
			TCGXSlotReel.cg_id,
			tCGXSlotReel.index,
			TCGXSlotReel.reel
		from
			tCGXSlotReel,
			tCGGameSummary
		where
			tCGGameSummary.cg_game_id = ?
			and tCGGameSummary.cg_id = tCGXSlotReel.cg_id
		order by
			tCGXSlotReel.index
	}




	set SHARED_SQL(tb_stmt_get_cgprog_desc) {
		select
			s.stakes,
			p.fixed_stake,
			s.source,
			g.name,
			g.display_name,
			g.cg_class as game_class
		from
			tCGGameSummary as s,
			tCGProgSummary as p,
			tCGGameVersion as v,
			tCGGame as g
		where
			s.cg_id = g.cg_id and
			g.cg_id = v.cg_id and
			s.version = v.version and
			s.cg_game_id = p.cg_game_id and
			p.prog_play_id = ?
	}

	set SHARED_SQL(tb_stmt_shanghai_darts_detail) {
		select
					tCgDartHist.drawn,
			tCgDartHist.positions,
			tCgDartHist.colours
		from
			tCgDartHist
		where
			tCgDartHist.cg_game_id = ?
	}


	set SHARED_SQL(tb_stmt_hilox_detail) {
		select
					tCgHlxHist.cr_date as date,
					tCgHlxRule.value as selected,
					tCgHlxDrawable.value as num_drawn,
					tCgHlxDrawable.attr as attr,
					tCgHlxHist.action as action,
					tCgHlxHist.current_winnings as current_winnings
			from
					tCgHlxHist,
					OUTER tCgHlxRule,
					tCgHlxDrawable,
					tCgGameSummary,
					tCgGame,
					tCgAcct
			where
					tCgHlxHist.cg_game_id = ?
			and
					tCgHlxRule.rule_id = tCgHlxHist.rule_id
			and
					tCgHlxRule.cg_id = tCgGameSummary.cg_id
			and
					tCgHlxRule.version = tCgGameSummary.version
			and
					tCgHlxDrawable.index = tCgHlxHist.game_state
			and
					tCgHlxDrawable.cg_id = tCgGameSummary.cg_id
			and
					tCgHlxDrawable.version = tCgGameSummary.version
			and
					tCgGameSummary.cg_game_id = tCgHlxHist.cg_game_id
			and
					tCgGame.cg_id = tCgGameSummary.cg_id
			and
					tCgGameSummary.cg_acct_id = tCgAcct.cg_acct_id
			and
					tCgAcct.acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_hilohist_detail) {
		select
			tCgHiLoHist.cr_date as date,
			tCgHiLoHist.action as action,
			tCgHiLoHist.game_state as drawn,
			tCgHiLoHist.current_winnings as current_winnings,
			tCgHiLoHist.action_index as selected,
			tCgHiloHist.win_index,
			tCgHiloHist.lose_index
		from
			tCgHiLoHist,
			tCgGameSummary,
			tCgGame,
			tCgAcct
		where
			tCgHiLoHist.cg_game_id = ?
		and
			tCgGameSummary.cg_game_id = tCgHiLoHist.cg_game_id
		and
			tCgGame.cg_id = tCgGameSummary.cg_id
		and
			tCgGameSummary.cg_acct_id = tCgAcct.cg_acct_id
		and
			tCgAcct.acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_bslot_stop_detail) {
		select
			tCGMlSlotDef.symbols,
			tCGMlSlotDef.cg_id,
			tCGMlSlotDef.view_size,
			tCGMlSlotHist.stop,
			tCGMlSlotHist.sel_win_lines,
			tCGGameSummary.stake_per_line,
			tCGMlSlotHist.mplr_result
		from
			tCGMlSlotDef,
			tCGMlSlotHist,
			tCGGameSummary
		where
			tCGMlSlotHist.cg_game_id = ?
		and
			tCGMlSlotHist.cg_game_id = tCGGameSummary.cg_game_id
		and
			tCGGameSummary.cg_id = tCGMlSlotDef.cg_id
	}


	set SHARED_SQL(tb_stmt_bslot_reel_detail) {
		select
			tCGMlSlotReel.reel
		from
			tCGMlSlotReel
		where
			tCGMlSlotReel.cg_id = ?
	}


	set SHARED_SQL(tb_stmt_bbank_history) {
		select
			tCgHiLoHist.cr_date as date,
			tCgHiLoHist.action_data as action_data,
			tCgHiLoHist.action as action,
			tCgHiLoHist.game_state as drawn,
			tCgHiLoHist.current_winnings as current_winnings,
			tCgHiLoHist.action_index as selected,
			tCgBBankBoHist.bonus as bonus,
			tCgBBankBoHist.nudges as nudges,
			tcgBBankBoHist.extra_life as extra_life
		from
			tCgHiLoHist,
			tCgBBankBoHist,
			tCgGameSummary,
			tCgGame,
			tCgAcct
		where
			tCgHiLoHist.cg_game_id = ?
		and
			tCgGameSummary.cg_game_id = tCgHiLoHist.cg_game_id
		and
			tCgGame.cg_id = tCgGameSummary.cg_id
		and
			tCgHiLoHist.cg_game_id = tCgBBankBoHist.cg_game_id
		and
			tCgHiLoHist.interaction = tCgBBankBoHist.interaction
		and
			tCgGameSummary.cg_acct_id = tCgAcct.cg_acct_id
		and
			tCgAcct.acct_id = ?
		order by
			tCgHiLoHist.cr_date asc
	}


	set SHARED_SQL(tb_stmt_get_gdep_type) {
		select
			p.pay_type
		from
			tPmtGdep p
		where
			p.pmt_id = ?
	}


	set SHARED_SQL(tb_stmt_get_esb_desc) {
		select
			b.bet_id,
			b.cr_date        bet_date,
			b.receipt        bet_receipt,
			b.acct_id        bet_acct_id,
			b.settled        bet_settled,
			case
				when b.tax_type = 'W' then
					b.stake
				when b.tax_type = 'S' then
					(b.stake + b.tax)
				else
					b.stake
				end as bet_stake_total,
			b.winnings + b.refund bet_returns_total,
			b.stake_per_line bet_stake_per_line,
			b.bet_type,
			b.num_lines,
			b.leg_type,
			b.tax_type,
			b.paid,
			b.settled_at,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			e.desc              ev_name,
			b.source            channel,
			e.result_conf       ev_result_conf,
			e.start_time        ev_start_time,
			g.name              mkt_name,
			case when s.runner_num is not null and c.sort='GR'
				then "Trap "||s.runner_num||" "||s.desc
				else s.desc
			end                 oc_name,
			s.result            oc_result,
			s.place             oc_place,
			o.ev_oc_id,
			o.price_type,
			o.o_num,
			o.o_den,
			o.leg_no,
			o.leg_sort,
			o.part_no,
			o.hcap_value,
			o.bir_index,
			s.fb_result,
			t.name              type_name,
			c.name              class_name,
			a.ap_amount         ap_stake,
			a.ap_op_type,
			b.token_value,
			s.ev_mkt_id
		from
			tBet b,
			tObet o,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e,
			tEvType t,
			tEvClass c,
			outer tAPPmt a
		where
			b.bet_id       = ? and
			b.bet_id       = o.bet_id and
			o.ev_oc_id     = s.ev_oc_id and
			s.ev_mkt_id    = m.ev_mkt_id and
			s.ev_id        = e.ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			e.ev_type_id   = t.ev_type_id and
			t.ev_class_id  = c.ev_class_id and
			b.bet_id = a.bet_id and
			a.ap_op_type = 'ASTL'
		order by
			o.leg_no, o.part_no
	}

	set SHARED_SQL(tb_stmt_get_esb_man_desc) {
		select
			b.cr_date,
			b.receipt,
			b.status,
			b.settled,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			b.source,
			b.paid,
			b.tax_type,
			case
				when b.tax_type = 'W' then
					b.stake
				when b.tax_type = 'S' then
					(b.stake + b.tax)
				else
					b.stake
				end as bet_stake_total,
			(b.winnings + b.refund) as bet_returns_total,
			b.stake_per_line,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			NVL(o.desc_1,'Manual Bet') As desc_1,
			NVL(o.desc_2,'') As desc_2,
			NVL(o.desc_3,'') As desc_3,
			NVL(o.desc_4,'') As desc_4,
			a.ap_amount    ap_stake,
			a.ap_op_type
		from
			tBet b,
			tManOBet o,
			outer tAPPmt a
		where
			b.bet_id = ? and
			b.bet_id = o.bet_id and
			b.bet_id = a.bet_id and
			a.ap_op_type = 'ASTL'
	}

	set SHARED_SQL(tb_stmt_get_xgam_desc) {
		select
			d.name game_name,
			d.sort,
			g.comp_no,
			g.draw_at as draw_time,
			s.xgame_sub_id,
			s.num_subs,
			s.source,
			s.stake_per_bet,
			s.prices,
			(num_subs * stake_per_bet) as amount,
			1 + length(s.picks) - length(replace(s.picks, "|", "")) as num_picks,
			s.picks,
			s.token_value,
			nvl(sum(b.winnings),0) as total_winnings,
			count(b.xgame_bet_id) as winning_bets,
			round(s.num_subs - count(bb.xgame_bet_id)) as subs_remaining,
			dd.desc,
			s.num_lines,
			s.bet_type,
			s.draws,
			s.acct_id
		from
			txgamedef d,
			txgamesub s,
			txgame g,
			outer txgamebet b,
			outer txgamebet bb,
			outer txgamedrawdesc dd
		where
			s.xgame_sub_id = ? and
			s.xgame_id     = g.xgame_id and
			g.sort         = d.sort and
			b.xgame_sub_id = s.xgame_sub_id and
			b.winnings > 0 and
			bb.xgame_sub_id = s.xgame_sub_id and
			bb.settled = "Y" and
			g.draw_desc_id = dd.desc_id
			group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 21
	}

	set SHARED_SQL(tb_stmt_get_pools_desc) {
		select
			b.pool_bet_id,
			b.settled		as bet_settled,
			b.settled_at		as bet_settled_at,
			b.settle_info		as bet_settle_info,
			b.receipt		as bet_receipt,
			b.cr_date		as bet_date,
			b.acct_id		as bet_acct_id,
			b.stake			as bet_stake_total,
			b.max_payout		as bet_max_payout,
			b.winnings		as bet_winnings,
			b.winnings + b.refund	as bet_returns_total,
			b.bet_type,
			b.num_legs,
			b.num_selns,
			b.num_lines,
			b.num_lines_win,
			b.num_lines_lose,
			b.num_lines_void,
			b.leg_type,
			b.call_id,
			b.paid,
			b.source			as channel,
			p.leg_no,
			p.part_no,
			p.ev_oc_id,
			p.pool_id,
			p.banker_info,
			n.name 				as pool_name,
			e.desc 				as ev_name,
			to_char(e.start_time,'%d %b %Y %R') as ev_time,
			o.desc 				as oc_name,
			o.result			as oc_result,
			o.place 			as oc_place,
			o.runner_num,
			s.desc as source_name,
			t.name				as meeting,
			pt.name             as pool_type,
			pt.pool_type_id,
			em.meeting_date,
			o.ev_mkt_id
		from
			tPoolBet b,
			tPbet p,
			tPool n,
			tPoolType pt,
			tevoc o,
			tev e,
			tevtype t,
			tPoolSource s,
			outer tEvMeeting em
		where
			b.pool_bet_id    = ? and
			b.pool_bet_id = p.pool_bet_id and
			p.ev_oc_id = o.ev_oc_id and
			o.ev_id = e.ev_id and
			p.pool_id = n.pool_id and
			n.pool_type_id = pt.pool_type_id and
			n.pool_source_id = s.pool_source_id and
			e.ev_type_id = t.ev_type_id and
			em.ev_meeting_id = e.ev_meeting_id
	}

		set SHARED_SQL(tb_stmt_get_dleg_type) {
				select
						o.pool_type_id
				from
						tpoolbet b,
						tPbet p,
						tpool o
				where
						b.pool_bet_id = ? and
						b.pool_bet_id = p.pool_bet_id and
						p.pool_id = o.pool_id
		}

	set SHARED_SQL(tb_stmt_get_appmt_desc) {
		select
			bet_id,
			ap_amount,
			ap_op_type
		from
			tAPPmt
		where
			appmt_id = ?
	}

	set SHARED_SQL(tb_stmt_get_xgam_stl_desc) {
		select
			d.name game_name,
			d.sort,
			g.comp_no,
			s.source,
			s.picks,
			dd.desc,
			s.num_lines,
			s.bet_type,
			s.xgame_sub_id,
			g.draw_at as draw_time,
			s.prices,
			b.stake,
			g.results,
			b.num_lines_win,
			b.num_lines_void,
			b.num_lines_lose,
			s.token_value,
			b.winnings,
			s.acct_id
		from
			txgamebet b,
			txgamedef d,
			txgamesub s,
			txgame g,
			outer txgamedrawdesc dd
		where
			b.xgame_bet_id = ? and
			b.xgame_sub_id = s.xgame_sub_id and
			s.xgame_id     = g.xgame_id and
			g.sort         = d.sort and
			g.draw_desc_id = dd.desc_id
	}

	set SHARED_SQL(tb_stmt_check_rule4) {
		select
			s.result,
			s.result_conf as confirmed
		from
		   	tEvOc s,
		   	tOBet o
		where
		   	o.ev_oc_id = ? and
		   	o.leg_sort = '--' and
		   	o.ev_oc_id = s.ev_oc_id
	}

	set SHARED_SQL(tb_stmt_get_mkt_rule4_deductions) {
		select
			market,
			NVL(time_from,'2000-01-01 00:00:00') time_from,
			NVL(time_to,  '2100-01-01 00:00:00') time_to,
			deduction,
			comment
		from
			tEvMktRule4
		where
			ev_mkt_id = ?

	}

	set SHARED_SQL(tb_stmt_get_ap_bets) {
		select
			bet_id,
			cr_date
		from
			tBet
		where
			acct_id = ? and
			cr_date <= ? and
			(settled <> 'Y' or settled_at > ?) and
			paid <> 'Y'
	}


	set SHARED_SQL(tb_stmt_get_record) {
		select
			acct_id,
			cr_date,
			stmt_num,
			date_from,
			date_to,
			dlv_method,
			sort,
			brief,
			cust_msg_1,
			cust_msg_2,
			cust_msg_3,
			cust_msg_4,
			pmt_amount,
			pmt_method,
			pmt_desc,
			product_filter
		from
			tStmtRecord
		where
			stmt_id = ?
	}

	set SHARED_SQL(tb_stmt_get_prc_type) {
		select
			pref_cvalue
		from
			tcustomerpref
		where
			cust_id=? and
			pref_name ='PRICE_TYPE'
	}

	set SHARED_SQL(tb_stmt_get_exch_rate) {
		select
			exch_rate
		from
			tccy
		where
			ccy_code = ?
	}

	set SHARED_SQL(tb_stmt_get_balls_payout_sub_id) {
		select
			sub_id
		from
			tballspayout
		where
			payout_id = ?
	}

	set SHARED_SQL(tb_stmt_get_pmt_source) {
		select
			source
		from
			tPmt
		where
			pmt_id = ?
	}

	set SHARED_SQL(create_stmt_run) {

		execute procedure pInsStmtRun(
			p_stmt_run_ref = ?,
			p_elite = ?
		)

	}

	set SHARED_SQL(close_stmt_run) {

		update
			tStmtRun
		set
			status = 'C'
		where
			stmt_run_id = ?

	}

	set SHARED_SQL(get_stmt_run_time) {
		select
			cr_date
		from
			tStmtRun
		where
			stmt_run_id = ?
	}

	set SHARED_SQL(get_stmt_run_report) {
		select
			stmt_run_id,
			stmt_run_ref,
			cr_date,
			num_pull_perm,
			done_pull_perm,
			num_pull_temp,
			done_pull_temp,
			num_dep,
			done_dep,
			num_dbt,
			done_dbt,
			num_cdt,
			done_cdt,
			num_failed,
			status,
			elite
		from
			tStmtRun
		where
			stmt_run_id = ? and
			elite = ?
	}

	set SHARED_SQL(tb_stmt_get_slip_parts) {
		select
			part_ref_key,
			part_ref_id
		from
			tSlipPart
		where
			slip_id = ?
	}

	set SHARED_SQL(tb_stmt_get_vet_code) {
		select
			v.description
		from
			tCustomerFlag f,
			tCustFlagVal v,
			tAcct a
		where
			a.acct_id = ?
			and a.cust_id = f.cust_id
			and f.flag_name = ?
			and f.flag_value = v.flag_value

	}


	OT_LogWrite 5 "<== init_tb_statement_build"
}


proc get_stmt_data {stmt_id ARRAY} {

	upvar 1 $ARRAY DATA

	OT_LogWrite 5 "==> get_stmt_data"

	#
	# get the statement header information
	#
	get_stmt_hdr $stmt_id DATA

	#
	# force the price type
	#
	set_price_type DATA

	#
	# generate the main body
	#
	get_stmt_body DATA

	#
	# footer
	#
	get_stmt_ftr DATA


	#
	# populate missing data if not set
	#
	foreach f {stakes_os} {
		if {![info exists DATA(hdr,$f)]} {
			set DATA(hdr,$f) ""
		}
	}

	OT_LogWrite 5 "<== get_stmt_data"
}

#
# Count the number of statements for this run and insert
# a record into the database.
#
proc create_stmt_run {stmt_run_key {elite "N"}} {

	#
	# Calculate the number of statements to be created, and
	# insert a record for this run
	#
	OT_LogWrite 3 "tb_statement_build create_stmt_run stmt_run_key $stmt_run_key"
	set stmt_run_id -1

	if [catch {set rs [tb_db::tb_exec_qry create_stmt_run $stmt_run_key \
				$elite]} msg] {
		OT_LogWrite 1 "Failed (create_stmt_run): $msg"
		error "failed to retrieve statement volumes : $msg"
		return
	} elseif {[db_get_nrows $rs] != 1} {
		OT_LogWrite 1 "Failed to retrieve"
		error "failed to retrieve statement volumes."
		return
	}

	set stmt_run_id [db_get_coln $rs 0 0]
	OT_LogWrite 1 "Statement run ref key = $stmt_run_key, Statement run id = $stmt_run_id"

	db_close $rs

	return $stmt_run_id
}

#
# Close a stmt run
#
proc close_stmt_run {stmt_run_id} {

	#
	# Update the stmt run record
	# Set status='C' for stmtruns with this stmt_run_id.
	# there could possibly be 2 rows; 1 for normal, 1 for elite
	#
	if [catch {set rs [tb_db::tb_exec_qry close_stmt_run $stmt_run_id]} msg] {
		error "failed to mark statement run as closed : $msg"
		return
	}

	db_close $rs
}

#
# We need to have a common stmt_run_time so that all the filenames will have
# identical times, and hence will be able to be joined.
#
proc get_stmt_run_time {stmt_run_id} {

	#Retrieve the stmt_run creation date
	#There may be 1 or 2 rows returned, always 1 for normal customers
	#sometimes 2 with elite customers..
	OT_LogWrite 7 "Retrieving the stmt run time for stmt_run_id $stmt_run_id"
	if [catch {set rs [tb_db::tb_exec_qry get_stmt_run_time $stmt_run_id]} msg] {
		error "Could not find the stmt run record: $msg"
	} elseif {[db_get_nrows $rs] < 1} {
		error "Could not find the stmt run record: [db_get_nrows $rs] rows retrieved"
	}

	#Pull out the creation date
	set cr_date [db_get_col $rs 0 cr_date]

	db_close $rs

	return $cr_date
}

#
# Retrieve the statement run report
#
proc get_stmt_run_report {stmt_run_id OUT {elite "N"}} {

	upvar $OUT DATA

	#Retrieve the stmt_run details
	if [catch {set rs [tb_db::tb_exec_qry get_stmt_run_report $stmt_run_id \
				$elite]} msg] {
		error "Could not find the stmt run record: $msg"
	} elseif {[db_get_nrows $rs] != 1} {
		error [subst "Could not find the stmt run record: [db_get_nrows $rs]\
					rows retrieved"]
	}

	#Pull out the details
	foreach col [db_get_colnames $rs] {
		set DATA($col) [db_get_col $rs 0 $col]
	}
	db_close $rs
}

proc get_stmt_hdr {stmt_id ARRAY} {

	OT_LogWrite 5 "==> get_stmt_hdr $stmt_id"

	upvar 1 $ARRAY DATA


	OT_LogWrite 5 "6==> get_stmt_hdr $stmt_id"
	#
	# get info from tstmtrecord
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_record $stmt_id]} msg] {
		error "tb_stmt_get_record: $msg"
	}


	OT_LogWrite 5 "5==> get_stmt_hdr $stmt_id"

	#
	# generate the statement data
	#
	set DATA(stmt_id)        $stmt_id
	set DATA(hdr,acct_id)    [db_get_col $rs 0 acct_id]
	set DATA(hdr,dlv_method) [db_get_col $rs 0 dlv_method]
	set DATA(hdr,brief)      [db_get_col $rs 0 brief]
	set DATA(hdr,due_from)   [db_get_col $rs 0 date_from]
	set DATA(hdr,due_to)     [db_get_col $rs 0 date_to]
	set DATA(hdr,sort)       [db_get_col $rs 0 sort]
	set DATA(hdr,stmt_num)   [db_get_col $rs 0 stmt_num]
	set DATA(hdr,cust_msg)   "[db_get_col $rs 0 cust_msg_1][db_get_col $rs 0 cust_msg_2][db_get_col $rs 0 cust_msg_3][db_get_col $rs 0 cust_msg_4]"
	set DATA(hdr,pmt_amount) [db_get_col $rs 0 pmt_amount]
	set DATA(hdr,pmt_method) [db_get_col $rs 0 pmt_method]
	set DATA(hdr,pmt_desc)   [db_get_col $rs 0 pmt_desc]
	set DATA(hdr,product_filter) [db_get_col $rs 0 product_filter]

	if {$DATA(hdr,pmt_amount) == "0.00" || $DATA(hdr,pmt_amount) == ""} {
		set DATA(hdr,pmt_type) "NON"
		set DATA(hdr,pmt_amount_abs) "0.00"
	} elseif {[expr $DATA(hdr,pmt_amount) > 0]} {
		set DATA(hdr,pmt_type) "SNT"
		set DATA(hdr,pmt_amount_abs) $DATA(hdr,pmt_amount)
	} elseif {[expr $DATA(hdr,pmt_amount) < 0]} {
		set DATA(hdr,pmt_type) "REQ"
		set DATA(hdr,pmt_amount_abs) [expr abs($DATA(hdr,pmt_amount)) * -1]
	}

	OT_LogWrite 5 "4==> get_stmt_hdr $stmt_id"

	#
	# clip the due_to date to the current time
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $DATA(hdr,due_to) all yr mn dy hh mm ss]} {
		error "date wrong format"
	}
	set scan_to        [clock scan "$mn/$dy/$yr $hh:$mm:$ss"]
	set scan_current   [tb_statement::tb_stmt_get_time]

	if {$scan_to > $scan_current} {
		set scan_to $scan_current
	}
	set DATA(hdr,due_to) [clock format $scan_to -format "%Y-%m-%d %H:%M:%S"]

	db_close $rs

	OT_LogWrite 5 "3==> get_stmt_hdr $stmt_id"

	#
	# get the main header information
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_header $DATA(hdr,acct_id)]
	OT_LogWrite 5 "2==> get_stmt_hdr $stmt_id"
	if {[db_get_nrows $rs] != 1} {
		error "Failed to locate customer information ($DATA(hdr,acct_id))"
	}

	foreach f [db_get_colnames $rs] {
		set DATA(hdr,$f) [db_get_col $rs 0 $f]
	}
	db_close $rs

	OT_LogWrite 5 "1==> get_stmt_hdr $stmt_id"
	#
	# check for a custom specified country name
	#
	if {$DATA(hdr,country_code) == "--"} {
		set DATA(hdr,country_name) ""
	}

	if {$DATA(hdr,addr_country) != ""} {
		set DATA(hdr,country_name) $DATA(hdr,addr_country)
	}

	#
	# add Stralfors Statement Vet Code
	#
	if {[OT_CfgGet STMT_ADD_VET_CODE 0]} {
		if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_vet_code \
			$DATA(hdr,acct_id) [OT_CfgGet STMT_VET_CODE_FLAG_NAME]]} msg] {
			error "tb_stmt_get_vet_code: $msg"
		}
		if {[db_get_nrows $rs] == 0} {
			set DATA(hdr,vet_code) ""
		} else {
			set DATA(hdr,vet_code) [db_get_col $rs 0 description]
		}
		db_close $rs
	} else {
		set DATA(hdr,vet_code) ""
	}

	if {[OT_CfgGet STMT_CHEQUE_PAYEE 0]} {
		if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_chq_payee \
			$DATA(hdr,acct_id)]} msg] {
			error "tb_stmt_get_cheque_payee: $msg"
		}
		if {[db_get_nrows $rs] == 0} {
			set DATA(hdr,chq_payee) ""
		} else {
			set DATA(hdr,chq_payee) [db_get_col $rs 0 payee]
		}
		db_close $rs
	} else {
		set DATA(hdr,chq_payee) ""
	}

	# enable product filter ?
	set DATA(hdr,extra_infos) [list]
	switch -exact -- $DATA(hdr,product_filter) {
		CAS -
		EVO -
		BNG -
		SKI -
		VEG -
		GAM -
		POK {
			set DATA(hdr,qry) tb_stmt_get_xfer_entries
			foreach c [OT_CfgGet STATEMENTS_PROD_FILT_$DATA(hdr,product_filter)_INFOS [list]] {
				lappend DATA(hdr,extra_infos) $c
			}
		}
		PMT {
			set DATA(hdr,qry) tb_stmt_get_pmt_entries
		}
		SPO {
			set DATA(hdr,qry) tb_stmt_get_bets_entries
		}
		LOT {
			set DATA(hdr,qry) tb_stmt_get_xgames_entries
		}
		ALL -
		default {
			set DATA(hdr,qry) tb_stmt_get_stmt_entries
		}
	}

	OT_LogWrite 5 "<== get_stmt_hdr"
}



proc get_stmt_ftr {ARRAY} {

	OT_LogWrite 5 "==> get_stmt_ftr"

	upvar 1 $ARRAY DATA

	#
	# a/p bets (credit a/c only)
	#
	if {$DATA(hdr,acct_type) == "CDT"} {
		get_stmt_ap_bets DATA
	}

	#
	# Set the win indication based upon the pmt_amount
	# this is painful
	#
	switch -- $DATA(hdr,acct_type) {
		"DEP" {set DATA(hdr,win_indication) "D"}
		"DBT" {set DATA(hdr,win_indication) "O"}
		"CDT" {
			if {$DATA(hdr,pmt_amount) == ""} {
				set DATA(hdr,pmt_amount) 0.00
			}
			if {$DATA(hdr,pmt_amount) > 0 && $DATA(hdr,pmt_type) == "SNT"} {
				set DATA(hdr,win_indication) "W2"
			} elseif {$DATA(hdr,pmt_amount) < 0 && $DATA(hdr,pmt_type) == "REQ"} {
				set DATA(hdr,win_indication) "L2"
			} elseif {$DATA(hdr,close_bal) < 0} {
				set DATA(hdr,win_indication) "L1"
			} elseif {$DATA(hdr,close_bal) > 0} {
				set DATA(hdr,win_indication) "W1"
			} else {
				# Default to O
				ob::log::write INFO {defaulting win_indication to O}
				set DATA(hdr,win_indication) "O"
			}
		}
		default {
			ob::log::write INFO {Unknown acct_type: $acct_type}
			set DATA(hdr,win_indication) "O"
		}
	}

	OT_LogWrite 5 "<== get_stmt_ftr"
}



proc get_stmt_body {ARRAY} {

	OT_LogWrite 5 "==> get_stmt_body"

	upvar 1 $ARRAY DATA

	OT_LogWrite 5 "==> $DATA(hdr,acct_id) $DATA(hdr,due_from) $DATA(hdr,due_to)"

	set balance [tb_statement::tb_stmt_get_balance $DATA(hdr,acct_id) $DATA(hdr,due_from)]

	set DATA(hdr,open_bal)          $balance
	set DATA(hdr,close_bal)         $balance
	set DATA(hdr,total_staked)      0
	set DATA(hdr,total_returns)     0
	set DATA(hdr,total_deposits)    0
	set DATA(hdr,total_withdrawals) 0

	#
	# if a credit account then adjust by sum_ap
	#
	if {$DATA(hdr,acct_type) == "CDT"} {
		set sum_ap  [tb_statement::tb_stmt_get_sum_ap  $DATA(hdr,acct_id) $DATA(hdr,due_from)]
		set DATA(junk,sum_ap)   $sum_ap

		set DATA(hdr,close_bal) [format "%.2f" [expr $DATA(hdr,close_bal) + $DATA(junk,sum_ap)]]
		set DATA(hdr,open_bal)  [format "%.2f" [expr $DATA(hdr,open_bal) + $DATA(junk,sum_ap)]]
	}


	#
	# get the list of statement entries for this period
	#
	set cmd [list tb_db::tb_exec_qry $DATA(hdr,qry) $DATA(hdr,acct_id) $DATA(hdr,due_from) $DATA(hdr,due_to)]
	foreach c $DATA(hdr,extra_infos) {
		lappend cmd $c
	}

	set rs [eval $cmd]

	set nrows [db_get_nrows $rs]
	OT_LogWrite 5 "num_stmt_entries: $nrows"

	# Key used to position entries within the data array
	set last_entry_key -1
	for {set i 0} {$i < $nrows} {incr i} {

		set id   [db_get_col $rs $i id]
		set date [db_get_col $rs $i date]

		# Set the key for this iteration
		set key [incr last_entry_key]

		# default entry type is TXN
		set DATA(bdy,$key,entry_type) TXN

		OT_LogWrite 3 "Calling do_journal_entry - key is $key, jrnl_id = $id, date = $date"

		# Increment the key and do journal entry
		set last_entry_key [do_journal_entry $key $id DATA]

	}
	db_close $rs

	set DATA(bdy,num_txns) [incr last_entry_key]



}

#------------------------------------------------------------------------------
# Populate array with data relating to the passed journal item. Start inserting
# the data at the point specified by the passed key. Increment the key as
# required, and return the value of the key at the last piece of data inserted.
#
# This enables journal items to relate to multiple transactions without the need
# to fudge them.
#------------------------------------------------------------------------------

proc do_journal_entry {key jrnl_id ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# get journal entry
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_jrnl_entry $jrnl_id $DATA(hdr,acct_id)]

	set DATA(bdy,$key,cr_date)        [db_get_col $rs 0 cr_date]
	set DATA(bdy,$key,jrnl_id)        [db_get_col $rs 0 jrnl_id]
	set DATA(bdy,$key,j_op_type)      [db_get_col $rs 0 j_op_type]
	set DATA(bdy,$key,j_op_ref_key)   [db_get_col $rs 0 j_op_ref_key]
	set DATA(bdy,$key,j_op_ref_id)    [db_get_col $rs 0 j_op_ref_id]
	set amount                        [db_get_col $rs 0 amount]
	set DATA(bdy,$key,desc)           [db_get_col $rs 0 desc]
	set jrnl_bal                      [db_get_col $rs 0 balance]

	db_close $rs

	# Default the last entry key to the passed one
	set last_entry_key $key

	#
	# now generate extra information based upon entry type
	#
	set op_type $DATA(bdy,$key,j_op_type)
	set result 0

	if {[lsearch {
		"DEP"  "WTD"  "BSTK" "BSTL" "BWIN" "BRFD" "DDEP" "DWTD" "DREF" "WREF" "MAN" \
		"RDEP" "DCAN" "WCAN" "BCAN" "RWTD" "XFER" "DRES" "WRES" "LB++" "BUWN" "BURF"\
		"LB--" "BUST" "SSTK" "SCAN" "SPRF" "NBST" "NBWN" "XSIN" "XSOT" "XSRF" "CGWN"\
		"CGSK" "CGPS" "CGPW" "BXCG" "ALRT" "COMM" "TTFR" "TCOL" "TBET" "TCSL" "TREF"\
		"HSTK" "HWIN" "HRFD"
	} $op_type] == -1} {
		# Unknown transaction type. Don't try to handle this, just throw an error. This statement will fail,
		# but at least the error will be detected, and the appopriate op type handler can then be implemented.
		# If we try to work around this, it will probably be slip through the net and remain unresolved.
		#
		set command get_stmt_entry_unknown
	} else {
		set command get_stmt_entry_$op_type
	}

	# In this case, we believe that there should be a command, but there isn't.
	#
	if {[info commands $command] == ""} {
		ob::log::write ERROR "Failed to find appropriate command for type $op_type"
		set command get_stmt_entry_unknown
	}

	# For xternal transfers we need to locate and display the system_id
	if {[OT_CfgGet STMT_DISP_XTERNAL_SYSTEM_ID 0]} {
		if {[lsearch [list XSIN XSOT XSRF] $DATA(bdy,$key,j_op_type)] != -1} {
			set rs [tb_db::tb_exec_qry tb_stmt_get_xsys_desc $DATA(bdy,$key,jrnl_id)]

			if {[db_get_nrows $rs] != "1"} {
				ob::log::write INFO {tb_stmt_get_xsys_desc: Couldn't locate system_id}
				set DATA(bdy,$key,system_id)      ""
			} else {
				ob::log::write INFO {tb_stmt_get_xsys_desc: Setting system_id}
				set DATA(bdy,$key,system_id)      [db_get_col $rs 0 system_id]
			}
			db_close $rs
		} else {
			set DATA(bdy,$key,system_id)      ""
		}
	}



	ob::log::write DEBUG "generating entry for key $key : $DATA(bdy,$key,jrnl_id), \
		$DATA(bdy,$key,j_op_type), $DATA(bdy,$key,j_op_ref_key), \
		$DATA(bdy,$key,j_op_ref_id)"

	set DATA(bdy,$key,adjustment)  $amount
	set DATA(bdy,$key,receipt)     ""
	set DATA(bdy,$key,token_value) 0.00

	set key [$command $key $amount DATA]

	return $key
}


# Get thet statement entry for an unknown op type. This can event deal this
# the situation where there entry isn't even in tJrnlOp.
#
#   key    - The key.
#   amount - The amount of the entry.
#   ARRAY  - DATA.
#
proc get_stmt_entry_unknown {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	ob::log::write WARNING "Unknown transaction type $DATA(bdy,$key,j_op_type)"

	if {$amount >= 0} {
		set DATA(bdy,$key,dep) $amount
	} else {
		set DATA(bdy,$key,wtd) $amount
	}

	set desc    $DATA(bdy,$key,desc)
	set cr_date $DATA(bdy,$key,cr_date)

	# If the description is blank, try and get the journal op name, if that's
	# blank just call it unknown.
	#
	if {$desc == ""} {
		# If this query fails, we can still set it as 'Unknown'.
		#
		if {[catch {
			set rs [tb_db::tb_exec_qry tb_stmt_get_jrnl_op \
				$DATA(bdy,$key,j_op_type)]
		} msg]} {
			ob::log::write ERROR "Failed to retrieve info: \
				$DATA(bdy,$key,j_op_type): $msg"
		} else {
			if {[db_get_nrows $rs] == 1} {
				set desc [db_get_col $rs j_op_name]
			} else {
				set desc ""
			}
			db_close $rs
		}
	}

	if {$desc == ""} {
		set desc "Unknown"
	}

	set DATA(bdy,$key,channel)    "I"
	set DATA(bdy,$key,adjustment) $amount
	set DATA(bdy,$key,nrows) 	  1
	set DATA(bdy,$key,0,desc)     $desc
	set DATA(bdy,$key,cr_date)    $cr_date

	adjust_rolling_balance $key $ARRAY

	return $key
}

#------------------------------------------------------------------------------
# Set the rolling balance for the transaction, and adjust the close balance
#------------------------------------------------------------------------------
proc adjust_rolling_balance {key ARRAY} {

	# Declarations
	upvar 1 $ARRAY DATA

	# Log the method details
	log_proc_call 20

	# Make sure that this hasn't been called twice for the same transaction
	if {![info exists DATA($DATA(stmt_id),$key,lock)]} {

		#Update the close balance
		set DATA(hdr,close_bal)    [format "%.2f" [expr $DATA(hdr,close_bal) + $DATA(bdy,$key,adjustment)]]

		# Update the Total Staked
		if {[info exists DATA(bdy,$key,stake)]} {
			set DATA(hdr,total_staked) [format "%.2f" [expr $DATA(hdr,total_staked) + $DATA(bdy,$key,stake)]]
		}

		# Update the Total Returns
		if {[info exists DATA(bdy,$key,returns)]} {
			set DATA(hdr,total_returns) [format "%.2f" [expr $DATA(hdr,total_returns) + $DATA(bdy,$key,returns)]]
		}

		# Update the Total Deposits
		if {[info exists DATA(bdy,$key,dep)]} {
			OT_LogWrite 10 "Adjusted deposit balance for stmt $DATA(stmt_id), acct: $DATA(hdr,acct_id) amount: $DATA(bdy,$key,dep)"
			set DATA(hdr,total_deposits) [format "%.2f" [expr $DATA(hdr,total_deposits) + $DATA(bdy,$key,dep)]]
		}

		# Update the Total Withdrawals
		if {[info exists DATA(bdy,$key,wtd)]} {
			set DATA(hdr,total_withdrawals) [format "%.2f" [expr $DATA(hdr,total_withdrawals) + $DATA(bdy,$key,wtd)]]
		}

		# Set the rolling balance
		set DATA(bdy,$key,balance) $DATA(hdr,close_bal)

		# Set the lock to make sure we don't increment the balance twice if this method is called again
		set DATA($DATA(stmt_id),$key,lock) 1

	} else {
		OT_LogWrite 1 "WARNING! adjust_rolling_balance has already been called for key $key, stmt_id $DATA(stmt_id), acct_id $DATA(hdr,acct_id)"
	}
}


#------------------------------------------------------------------------------
# Cancelled retail slip
#------------------------------------------------------------------------------
proc get_stmt_entry_SCAN {key amount ARRAY} {

	# Declarations
	upvar 1 $ARRAY DATA

	# Check ref key type
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set cr_date $DATA(bdy,$key,cr_date)

	if {$ref_key == "SLIP"} {

		# This represents the case where a retail slip has been cancelled,
		# and the total stake refunded to the account
		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,0,desc)     "Cancelled shop bet"
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,returns)    $amount

		# Hard-code to retail channel, as this entry can only be retail
		set DATA(bdy,$key,channel)    "S"

		# Adjust balance appropriately
		adjust_rolling_balance $key DATA

	} else {

		# Unknown ref key
			OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
				set DATA(bdy,$key,nrows)        1
				set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}

	#Return the key value of the last row
	return $key
}

#------------------------------------------------------------------------------
# Populate the statement array with the data for the passed slip. Note that
# this will possibly populate multiple rows within the ARRAY - the key for
# the last row inserted will be returned to the caller.
#------------------------------------------------------------------------------
proc get_stmt_entry_SSTK {key amount ARRAY} {

	# Declarations
	upvar 1 $ARRAY DATA

	# Check ref key type
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set cr_date $DATA(bdy,$key,cr_date)
	if {$ref_key == "SLIP"} {

		#Retrieve the slip parts
		set rs [tb_db::tb_exec_qry tb_stmt_get_slip_parts $ref_id]

		# Check the number of parts
		set nrows [db_get_nrows $rs]
		if {$nrows == 0} {

			# This represents the case where a slip entry has been created, but
						# the bets have not yet been captured. All we can do is enter a
						# summary entry for the entire slip.
			set DATA(bdy,$key,nrows)      1
			set DATA(bdy,$key,0,desc)     "Retail betslip stake"
			set DATA(bdy,$key,adjustment) $amount
			set DATA(bdy,$key,stake)      $amount

			# Hard-code to retail channel, as this entry can only be retail
			set DATA(bdy,$key,channel)    "S"

			# Adjust balance appropriately
			adjust_rolling_balance $key DATA

		} else {

			# Treat each entry as a separate virtual journal item
			for {set part 0} {$part < $nrows} {incr part} {

				# Retrieve the reference data
				set part_ref_key [db_get_col $rs $part part_ref_key]
				set part_ref_id  [db_get_col $rs $part part_ref_id]

				if {$part_ref_key == "MADJ"} {
					# Manual adjustment refunds will generate their own journal
					# entry so skip this part
					incr key -1
				} else {
					# Hack in some values for fields normally set in do_journal_entry
					set DATA(bdy,$key,entry_type) TXN
					set DATA(bdy,$key,cr_date)    $cr_date

					# Build the associated bet record
					if {$part_ref_key == "ESB"} {

						#Regular sports bet
						build_bet_desc "bdy,$key" $part_ref_id DATA BSTK $amount

					} elseif {$part_ref_key == "XGAM"} {

						#XGames bet
						build_xgame_bet_desc "bdy,$key" $part_ref_id DATA BSTK

					} elseif {$part_ref_key == "TPB"} {

						#XGames bet
						build_pools_bet_desc "bdy,$key" $part_ref_id DATA BSTK

					} else {

						#Unknown ref type
						set DATA(bdy,$key,nrows) 	  1
						set DATA(bdy,$key,0,desc)     "Invalid part_ref_key: $part_ref_key"
						set DATA(bdy,$key,adjustment) 0
					}

					# Adjust the rolling balance fields
					adjust_rolling_balance $key DATA
				}

				# Increment key, unless this is the last part
				if {$part + 1 < $nrows} {
					incr key
				}
			}
		}

		#Close the recordset
		db_close $rs

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}

	#Return the key value of the last row
	return $key
}

#------------------------------------------------------------------------------
# A refund due to the entire slip stake not being used
#------------------------------------------------------------------------------
proc get_stmt_entry_SPRF {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	set man_txt "Manual adjustment:"

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	if {$ref_key == "MADJ"} {
		set DATA(bdy,$key,nrows) 	1
		set rs [tb_db::tb_exec_qry tb_stmt_get_madj_desc $DATA(bdy,$key,j_op_ref_id)]

		set subtype [db_get_col $rs 0 subtype]
		if {[string length $subtype]} {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type] - $subtype"
		} else {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type]"
		}

		set DATA(bdy,$key,channel) "S"
		db_close $rs

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	if {$amount >= 0} {
		set DATA(bdy,$key,dep)	$amount
	} else {
		set DATA(bdy,$key,wtd)	$amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last rowGBet
	return $key

}

proc get_stmt_entry_DEP {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- payment received with thanks"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key
}

proc get_stmt_entry_DDEP {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pre_txt "Automated:"
	set pmt_txt "- payment received with thanks"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "$pre_txt [lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_DWTD {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pre_txt "Automated:"
	set pmt_txt "- payment"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)    1
		set DATA(bdy,$key,pay_mthd) [lindex $pay_desc 0]
		set DATA(bdy,$key,0,desc)   "$pre_txt [lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel)  [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,wtd)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_DREF {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- payment (referral) received with thanks"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_WREF {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- payment (referral)"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,wtd)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_DRES {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- payment (transaction pending)"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows)        1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)  $amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_WRES {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- payment (transaction pending)"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows)        1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)  $amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_DCAN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "Cancelled deposit - failed referral"

	if {$ref_key == "MADJ" || $ref_key == "GPMT"} {
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "$pmt_txt"
		set DATA(bdy,$key,channel) ""

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,wtd)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_WCAN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "Cancelled withdrawal - failed referral"

	if {$ref_key == "MADJ" || $ref_key == "GPMT"} {
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "$pmt_txt"
		set DATA(bdy,$key,channel) ""

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_WTD {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set pmt_txt "- withdrawal"

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}
	set DATA(bdy,$key,wtd)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_RWTD {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set pmt_txt "- refunded failed withdrawal"
	set ref_key $DATA(bdy,$key,j_op_ref_key)

	if {$ref_key == "GPMT"} {
		set pay_desc [tb_stmt_get_pay_mthd $DATA(bdy,$key,j_op_ref_id)]
		set DATA(bdy,$key,nrows)   1
		set status [lindex $pay_desc 2]

		if {$status == "B"} {
			set pmt_txt "- reversed"
		}
		set DATA(bdy,$key,0,desc)  "[lindex $pay_desc 0] $pmt_txt"
		set DATA(bdy,$key,channel) [lindex $pay_desc 1]

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}
	set DATA(bdy,$key,dep)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_MAN {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	set man_txt "Manual adjustment:"

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	if {$ref_key == "MADJ"} {
		set DATA(bdy,$key,nrows) 	1
		set rs [tb_db::tb_exec_qry tb_stmt_get_madj_desc $DATA(bdy,$key,j_op_ref_id)]

		set subtype [db_get_col $rs 0 subtype]
		if {[string length $subtype]} {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type] - $subtype"
		} else {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type]"
		}

		set DATA(bdy,$key,channel) ""
		db_close $rs

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	if {$amount >= 0} {
		set DATA(bdy,$key,dep)	$amount
	} else {
		set DATA(bdy,$key,wtd)	$amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_XFER {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	set man_txt "Manual Adjustment:"
	set ref_key $DATA(bdy,$key,j_op_ref_key)
	if {$ref_key == "MADJ"} {
		set DATA(bdy,$key,nrows) 	1
		set rs [tb_db::tb_exec_qry tb_stmt_get_madj_desc $DATA(bdy,$key,j_op_ref_id)]

		set subtype [db_get_col $rs 0 subtype]
		if {[string length $subtype]} {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type] - $subtype"
		} else {
			set DATA(bdy,$key,0,desc) "$man_txt [db_get_col $rs 0 type]"
		}

		set DATA(bdy,$key,channel) "I"
		db_close $rs

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	if {$amount >= 0} {
		set DATA(bdy,$key,dep)	$amount
	} else {
		set DATA(bdy,$key,wtd)	$amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_BCAN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set can_txt "Bet cancelled:"

	if {$ref_key == "ESB"} {

		#
		# links to tBet
		#
		build_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BSTL $amount

	} elseif {$ref_key == "FANT"} {

		#
		# Fantasy type betting
		#
		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "$can_txt Fantasy League Subscription"
		set DATA(bdy,$key,returns)	  $amount
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} elseif {$ref_key == "XGAM"} {

		# External Games
		build_xgame_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BCAN $amount $can_txt

	} elseif {$ref_key=="TPB"} {

		# Links to tPoolBet
		build_pools_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BSTL

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_BSTK {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)

	if {$ref_key == "ESB"} {

		#
		# links to tBet
		#
		build_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BSTK $amount

	} elseif {$ref_key == "FANT"} {

		#
		# Fantasy type betting
		#
		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Fantasy League Subscription"
		set DATA(bdy,$key,stake)	  $amount
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} elseif {$ref_key == "XGAM"} {

		# External Games
		build_xgame_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BSTK $amount

	} elseif {$ref_key=="TPB"} {

		build_pools_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA BSTK
		set DATA(bdy,$key,stake)	  $amount
		set DATA(bdy,$key,adjustment) $amount

	} elseif {$ref_key == "APAY"} {

		#
		# Payment for an AP Bet (this is reflected in the statement as
		# a normal bet stake, except that this time the stake debit
		# is reflected in the rolling balance
		#
		set rs [tb_db::tb_exec_qry tb_stmt_get_appmt_desc $DATA(bdy,$key,j_op_ref_id)]

		set bet_id     [db_get_col $rs 0 bet_id]
		set ap_amount  [db_get_col $rs 0 ap_amount]
		set ap_op_type [db_get_col $rs 0 ap_op_type]

		#
		# Always display as a Bet Stake line
		set j_op_type BSTK

		build_bet_desc "bdy,$key" $bet_id DATA $j_op_type $ap_amount

		set DATA(bdy,$key,adjustment) $ap_amount
		db_close $rs

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}



proc get_stmt_entry_BRFD {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	get_stmt_entry_BSTL $key $amount DATA BRFD

}



proc get_stmt_entry_BWIN {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	get_stmt_entry_BSTL $key $amount DATA BWIN

}



proc get_stmt_entry_BSTL {key amount ARRAY {j_op_type "BSTL"}} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)

	if {$ref_key == "ESB"} {

		build_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA $j_op_type $amount

	} elseif {$ref_key == "FANT"} {
		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Fantasy Games Subscription"
		set DATA(bdy,$key,returns)	  $amount
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} elseif {$ref_key == "XGAM"} {

		set rs [tb_db::tb_exec_qry tb_stmt_get_xgam_stl_desc $DATA(bdy,$key,j_op_ref_id)]

		# Retrieve and format the game description fields
		set game_name  [db_get_col $rs 0 game_name]
		set desc       [db_get_col $rs 0 desc]
		set comp_no    [db_get_col $rs 0 comp_no]
		set picks      [join [split [db_get_col $rs 0 picks] "|"] " "]
		set results    [join [split [db_get_col $rs 0 results] "|"] " "]

		set DATA(bdy,$key,entry_type)     XGSTL
		set DATA(bdy,$key,nrows)          1
		set DATA(bdy,$key,game_name)      $game_name
		set DATA(bdy,$key,0,desc)         "$game_name (${desc}) - $picks"
		set DATA(bdy,$key,returns)        $amount
		set DATA(bdy,$key,adjustment)     $amount
		set DATA(bdy,$key,draw_desc)      [db_get_col $rs 0 desc]
		set DATA(bdy,$key,channel)        [db_get_col $rs 0 source]
		set DATA(bdy,$key,bet_type)       [db_get_col $rs 0 bet_type]
		set DATA(bdy,$key,num_lines)      [db_get_col $rs 0 num_lines]
		set DATA(bdy,$key,picks)          $picks
		set DATA(bdy,$key,receipt)        "L/[db_get_col $rs 0 acct_id]/[db_get_col $rs 0 xgame_sub_id]"
		set DATA(bdy,$key,draw_time)      [db_get_col $rs 0 draw_time]
		set DATA(bdy,$key,price)          [db_get_col $rs 0 prices]
		set DATA(bdy,$key,stake)          [db_get_col $rs 0 stake]
		set DATA(bdy,$key,results)        $results
		set DATA(bdy,$key,num_lines_win)  [db_get_col $rs 0 num_lines_win]
		set DATA(bdy,$key,num_lines_lose) [db_get_col $rs 0 num_lines_lose]
		set DATA(bdy,$key,num_lines_void) [db_get_col $rs 0 num_lines_void]
		set DATA(bdy,$key,token_value)    [db_get_col $rs 0 token_value]
		set DATA(bdy,$key,winnings)       [db_get_col $rs 0 winnings]
		set DATA(bdy,$key,isxgame)        1

		db_close $rs

	} elseif {$ref_key == "TPB"} {

		build_pools_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA $j_op_type
		set DATA(bdy,$key,adjustment) $amount

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


#
# For Hedged bets, we want to just pass the bet into build_bet_desc.  Note
# that these will always be ESB bets so we don't need to worry about the ref_key
# like in get_stmt_entry_BSTK or get_stmt_entry_BSTL
#
proc get_stmt_entry_HSTK {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	return [get_stmt_entry_hedged $key $amount DATA HSTK]

}

proc get_stmt_entry_HWIN {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	return [get_stmt_entry_hedged $key $amount DATA HWIN]

}

proc get_stmt_entry_HRFD {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	return [get_stmt_entry_hedged $key $amount DATA HRFD]

}



proc get_stmt_entry_hedged {key amount ARRAY op_type} {

	upvar 1 $ARRAY DATA

	build_bet_desc "bdy,$key" $DATA(bdy,$key,j_op_ref_id) DATA $op_type $amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

###
# General statement type, until we've more details about what is wanted.
###

proc get_stmt_entry_BXCG {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set acct_id $DATA(hdr,acct_id)

	## need date, channel, desc, credit amount or debit amount.
	set final_desc ""

	switch -- $ref_key {

		"BXMX" {
			## get description
			set txt ": Order Cancellation"

			if {[catch {
				set rs [tb_db::tb_exec_qry \
					tb_stmt_get_BXMX_details $DATA(bdy,$key,j_op_ref_id)]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {
				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		"BXMC" {
			set txt ": Commission Charged"
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_acct_mkt_details \
					$DATA(bdy,$key,j_op_ref_id) $acct_id]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {

				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}

				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		"BXMS" {
			set txt ": Market Settlement"
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_acct_mkt_details \
					$DATA(bdy,$key,j_op_ref_id) $acct_id]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {

				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		"BXMU" {
			set txt ": Market Update"
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_acct_mkt_details \
					$DATA(bdy,$key,j_op_ref_id) $acct_id]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {
				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}

		}
		"BXOM" {
			set txt ": Order Amendment"
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_BXOM_details \
					$DATA(bdy,$key,j_op_ref_id)]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {
				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				set DATA(bdy,$key,hasBreceipt) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		"BXON" {
			set txt ": Order Placement"
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_BXON_details \
					$DATA(bdy,$key,j_op_ref_id)]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {
				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				set DATA(bdy,$key,hasBreceipt) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		"BXMV" {
			## leave in main body for statements.
			##
			set txt ": Commission V.A.T."
			if {[catch {
				set rs [tb_db::tb_exec_qry tb_stmt_get_acct_mkt_details \
					$DATA(bdy,$key,j_op_ref_id) $acct_id]
			} msg]} {
				ob::log::write ERROR "Failed to retrieve info: \
					$DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
				return
			} else {

				if {[db_get_nrows $rs] == 0} {
					ob::log::write ERROR "Failed to retrieve info for ref_key: \
						$ref_key, ref_id:$DATA(bdy,$key,j_op_ref_id)"
					return
			 	}
				set ev_name [TB_XL [db_get_col $rs 0 ev_name]]
				set type [TB_XL [db_get_col $rs 0 name]]
				set desc "$ev_name $type"
				set final_desc "$desc$txt"
				set DATA(bdy,$key,isbx) 1
				#set DATA(bdy,$key,op_ref_key) $ref_key
				set DATA(bdy,$key,receipt) [db_get_col $rs 0 receipt]
				db_close $rs
			}
		}
		default {
			OT_LogWrite 1 \
				"ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
			set DATA(bdy,$key,nrows) 	1
			set desc "Unknown ref key!!"
		}
	}


	set DATA(bdy,$key,betx_dep) ""
	set DATA(bdy,$key,betx_wtd) ""


	#
	# This is going to be a GENTRAN entry type, but to be consistant with games
	# (which display in admin screens as "stake & returns" but in CSV files
	# entries in "payment & receipt" fields) we're going to do it the same.
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,betx_dep) $amount
		set DATA(bdy,$key,returns) $amount
	} else {
		set DATA(bdy,$key,betx_wtd) $amount
		set DATA(bdy,$key,stake) $amount
	}

	set DATA(bdy,$key,channel) "I"
	set DATA(bdy,$key,adjustment) $amount
	set DATA(bdy,$key,nrows) 	1
	set DATA(bdy,$key,0,desc) $final_desc

	adjust_rolling_balance $key $ARRAY

	return $key


}


###
# General statement type, until we've more details about what is wanted.
###

proc get_stmt_entry_ALRT {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	return [get_stmt_entry_unknown $key $amount DATA]
}

###
# Commission statement type, picks up any commission paid on payments
###
proc get_stmt_entry_COMM {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	if {$amount >= 0} {
		set DATA(bdy,$key,dep) $amount
	} else {
		set DATA(bdy,$key,wtd) $amount
	}

	if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_comm_details $DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id)]} msg]} {
		ob::log::write ERROR "Failed to retrieve info: $DATA(bdy,$key,jrnl_id) $DATA(hdr,acct_id): $msg"
		return
	}

	set DATA(bdy,$key,channel)    [db_get_col $rs channel]
	set DATA(bdy,$key,adjustment) $amount
	set DATA(bdy,$key,nrows) 	  1
	set DATA(bdy,$key,0,desc)     [db_get_col $rs name]

	db_close $rs

	adjust_rolling_balance $key $ARRAY

	return $key
}

# Transfer from/to terminal account
proc get_stmt_entry_TTFR {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "TTXN"} {
		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,channel)  [OT_CfgGet HOSP_CHANNEL Q]
		set DATA(bdy,$key,0,desc)  "Transfer between terminals"

	} else {
		ob_log::write ERROR {ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))}
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep) $amount

	adjust_rolling_balance $key $ARRAY

	return $key
}

# Collect from terminal account
proc get_stmt_entry_TCOL {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "TTXN"} {
		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,channel)  [OT_CfgGet HOSP_CHANNEL H]
		set DATA(bdy,$key,0,desc)  "Transfer to terminal for collection"

	} else {

		ob_log::write ERROR {ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))}
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep) $amount

	adjust_rolling_balance $key $ARRAY

	return $key
}

# Bet from terminal account
proc get_stmt_entry_TBET {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "TTXN"} {
		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,channel)  [OT_CfgGet HOSP_CHANNEL H]
		set DATA(bdy,$key,0,desc)  "Transfer to Place Bet"

	} else {

		ob_log::write ERROR {ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))}
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep) $amount

	adjust_rolling_balance $key $ARRAY

	return $key
}

# Credit slip terminal account
proc get_stmt_entry_TCSL {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "TTXN"} {
		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,channel)  [OT_CfgGet HOSP_CHANNEL H]
		set DATA(bdy,$key,0,desc)  "Credit Slip"

	} else {

		ob_log::write ERROR {ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))}
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep) $amount

	adjust_rolling_balance $key $ARRAY

	return $key
}

# Refund from terminal account
proc get_stmt_entry_TREF {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "TTXN"} {

		set DATA(bdy,$key,nrows)      1
		set DATA(bdy,$key,channel)  [OT_CfgGet HOSP_CHANNEL H]
		set DATA(bdy,$key,0,desc)  "Refund - bet not placed"

	} else {

		ob_log::write ERROR {ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))}
		set DATA(bdy,$key,nrows)  1
		set DATA(bdy,$key,0,desc) "Unknown ref key!!"
	}

	set DATA(bdy,$key,dep) $amount

	adjust_rolling_balance $key $ARRAY

	return $key
}

proc get_stmt_entry_CGSK {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set acct_id $DATA(hdr,acct_id)
	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	#
	# This is going to be a GAMES entry type (same as a Gentran)
	# but we don't want anythign in payments and receipts field
	# in the admin screens (instead entries in stake & returns)
	# but we do want payments & receipts populated in CSV files
	# so formatting doesnt break (hence the extra variables here).
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep) $amount
		set DATA(bdy,$key,returns) $amount
	} else {
		set DATA(bdy,$key,game_wtd) $amount
		set DATA(bdy,$key,stake) $amount
	}


	if {$ref_key == "IGF" ||$ref_key == "CASI" } {

		if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_cggames_desc $DATA(bdy,$key,j_op_ref_id)]} msg]} {
				ob::log::write ERROR "Failed to retrieve IGF game $ref_id $acct_id: $msg"
 		        return
		}

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find IGF game: $ref_id $acct_id"
				return
			}

		set desc [db_get_col $rs 0 display_name]	;# the display name, this will be appended to later.....
		set game_class [db_get_col $rs 0 game_class]

		if {$desc == ""} {
			set desc [db_get_col $rs 0 name]
		}

		set game_desc [db_get_col $rs 0 name]

		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,channel) [db_get_col $rs 0 source]
		set DATA(bdy,$key,adjustment) $amount

		db_close $rs


		if {$desc == "Shanghai Darts" || $desc == "ShanghaiDarts"} {

			set desc "Shanghai Darts"
			set drawn [set_desc_shanghaidarts $key $ref_id ARRAY]
			set desc "$desc:$drawn"

		} elseif {$desc == "Hotshots"} {

			set drawn [build_hotshots_desc $key $ref_id $acct_id ARRAY]
			OT_LogWrite 20 "set drawn to : $drawn"
			set desc "$desc:$drawn"

		} elseif {$desc == "TripleChance" || $desc == "Tri Hi Lo"} {

			set desc "Triple Chance Hi/Lo"
			set drawn [build_triple_chance_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$drawn"

		} elseif {$game_class == "GBet"} {

			set drawn [set_gbet_detail $key $ref_id $acct_id ARRAY $game_desc]
			set desc $desc:$drawn

		} elseif {$game_class == "Keno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Keno"]

			set selected [lindex $results 0]
			set matches [lindex $results 1]

			OT_LogWrite 5 "Selected: $selected, matches: $matches"

			set desc "$desc-Selection:$selected"

		} elseif {$game_class == "Colours"} {

			set result [set_spectrum_desc $key $ref_id ARRAY]
			set selected  [lindex $result 0]
			set drawn [lindex $result 1]

			set desc "$desc: Selection: $selected"

		} elseif {$desc == "Digit"} {

			set desc "Digit"
			set digit_desc [build_digit_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$digit_desc"

		} elseif {$game_class == "VKeno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "VKeno"]

			set game_type [lindex $results 0]
			set num_selected [lindex $results 1]
			set selected [lindex $results 2]
			set matches [lindex $results 3]

			OT_LogWrite 5 "Game Type: $game_type, Num selected: $num_selected, Selected: $selected, matches: $matches"

			set desc "$desc-Game Type: $game_type,Selection:$selected"

		} elseif {$game_class == "Bingo"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Bingo"]
			set selected [lindex $results 0]
			set matches [lindex $results 1]

			OT_LogWrite 5 "Selected:$selected, Matches:$matches"

			set desc "$desc-Selection:$selected"

		} elseif {$game_class == "XSlot"} {

			set results [set_xslot_details $key $ref_id ARRAY $game_desc]
			set symbols [lindex $results 0]
			set multiplier [lindex $results 1]

			OT_LogWrite 5 "Symbols $symbols - multiplier $multiplier"

			if {$multiplier != "-"} {
				set desc "$desc-Symbols:$symbols - Multiplier:$multiplier"
			} else {
				set desc "$desc-Symbols:$symbols"
			}
		} elseif {$game_class == "BBank"} {

			set bbank_desc [build_bbank_desc $key $ref_id $acct_id ARRAY]

			OT_LogWrite 5 "desc - $bbank_desc"

			set desc "$desc:$bbank_desc"
		} elseif {$game_class == "BSlot"} {

			set values [build_bslot_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$values"
		}

		set DATA(bdy,$key,0,desc) $desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}


	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_CGWN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set acct_id $DATA(hdr,acct_id)

	if {$ref_key == "IGF" || $ref_key == "CASI" } {

		if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_cggames_desc $DATA(bdy,$key,j_op_ref_id)]} msg]} {
				ob::log::write ERROR "Failed to retrieve IGF game $ref_id $acct_id: $msg"
 		       return
		}

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find IGF game: $ref_id $acct_id"
				return
			}

		set desc [db_get_col $rs 0 display_name]	;# the display name, this will be appended to later.....
		if {$desc == ""} {
			set desc [db_get_col $rs 0 name]
		}

		set game_class [db_get_col $rs 0 game_class]
		set game_desc [db_get_col $rs 0 name]

		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,channel) [db_get_col $rs 0 source]
		set DATA(bdy,$key,adjustment) $amount

		db_close $rs

		#####
		## For more detailed descriptions.....
		#####

		if {$desc == "Shanghai Darts" || $desc == "ShanghaiDarts"} {

			set desc "Shanghai Darts"
			set drawn [set_desc_shanghaidarts $key $ref_id ARRAY]
			set desc "$desc:$drawn"
		} elseif {$desc == "Hotshots"} {

			set drawn [build_hotshots_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$drawn"
		} elseif {$desc == "TripleChance" || $desc == "Tri Hi Lo"} {

			set desc "Triple Chance Hi/Lo"
			set drawn [build_triple_chance_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$drawn"
		} elseif {$game_class == "GBet"} {

			set drawn [set_gbet_detail $key $ref_id $acct_id ARRAY $game_desc]
			set desc $desc:$drawn

		}  elseif {$game_class == "Keno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Keno"]
			set selected [lindex $results 0]
			set matches [lindex $results 1]

			set desc "$desc-Selection:$selected"

			OT_LogWrite 20 "Selected: $selected"

		} elseif {$game_class == "Colours"} {

			set result [set_spectrum_desc $key $ref_id ARRAY]
			set selected  [lindex $result 0]
			set drawn [lindex $result 1]

			set desc "$desc: Selection: $selected"

		} elseif {$desc == "Digit"} {

			set desc "Digit"
			set digit_desc [build_digit_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$digit_desc"

		} elseif {$game_class == "VKeno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "VKeno"]

			set game_type [lindex $results 0]
			set num_selected [lindex $results 1]
			set selected [lindex $results 2]
			set matches [lindex $results 3]

			OT_LogWrite 5 "Game Type: $game_type, Num selected: $num_selected, Selected: $selected, matches: $matches"

			set desc "$desc-Game Type: $game_type,Selection:$selected"

		} elseif {$game_class == "Bingo"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Bingo"]
			set selected [lindex $results 0]
			set matches [lindex $results 1]

			OT_LogWrite 5 "Selected:$selected, Matches:$matches"

			set desc "$desc-Selection:$selected"
		} elseif {$game_class == "XSlot"} {

			set results [set_xslot_details $key $ref_id ARRAY $game_desc]
			set symbols [lindex $results 0]
			set multiplier [lindex $results 1]

			OT_LogWrite 5 "Symbols $symbols - multiplier $multiplier"

			if {$multiplier != "-"} {
				set desc "$desc-Symbols:$symbols - Multiplier:$multiplier"
			} else {
				set desc "$desc-Symbols:$symbols"
			}
		} elseif {$game_class == "BBank"} {

			set bbank_desc [build_bbank_desc $key $ref_id $acct_id ARRAY]

			OT_LogWrite 5 "desc - $bbank_desc"

			set desc "$desc:$bbank_desc"
		} elseif {$game_class == "BSlot"} {

			set values [build_bslot_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$values"
		}



		set DATA(bdy,$key,0,desc) $desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	#
	# This is going to be a GAMES entry type (same as a Gentran)
	# but we don't want anythign in payments and receipts field
	# in the admin screens (instead entries in stake & returns)
	# but we do want payments & receipts populated in CSV files
	# so formatting doesnt break (hence the extra variables here).
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
		set DATA(bdy,$key,returns) $amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
		set DATA(bdy,$key,stake) $amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_CGPS {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set acct_id $DATA(hdr,acct_id)

	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$ref_key == "IGFP" || $ref_key == "CASP"} {

		if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_cgprog_desc $DATA(bdy,$key,j_op_ref_id)]} msg]} {
				ob::log::write ERROR "Failed to retrieve IGF game $ref_id $acct_id: $msg"
 		       return
		}

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find IGF game: $ref_id $acct_id"
				return
			}

		set desc [db_get_col $rs 0 display_name]	;# the display name, this will be appended to later.....
		if {$desc == ""} {
			set desc [db_get_col $rs 0 name]
		}
		set game_class [db_get_col $rs 0 game_class]
		set game_desc [db_get_col $rs 0 name]

		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,channel) [db_get_col $rs 0 source]
		set DATA(bdy,$key,adjustment) $amount

		if {$amount > 0} {
			set DATA(bdy,$key,returns)	  $amount
		} else {
			set DATA(bdy,$key,stake) [db_get_col $rs 0 fixed_stake]
		}

		db_close $rs


		#####
		##If it's a Shanghai Darts Game then get a more detailed description
		#####

		if {$desc == "Shanghai Darts" || $desc == "ShanghaiDarts"} {

			set desc "Shanghai Darts"
			set drawn [set_desc_shanghaidarts $key $ref_id ARRAY]
			set desc "$desc: $drawn"

		} elseif {$desc == "Hotshots"} {

			set drawn [build_hotshots_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc: $drawn"

		} elseif {$desc == "TripleChance" || $desc == "Tri Hi Lo"} {

			set desc "Triple Chance Hi/Lo"
			set drawn [build_triple_chance_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc: $drawn"

		} elseif {$game_class == "GBet"} {

			set drawn [set_gbet_detail $key $ref_id $acct_id ARRAY $game_desc]
			set desc $desc:$drawn

		}  elseif {$game_class == "Keno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Keno"]
			set selected [lindex $results 0]
			set matches [lindex $results 1]

			set desc "$desc-Selection:$selected"

		} elseif {$game_class == "Colours"} {

			set result [set_spectrum_desc $key $ref_id ARRAY]
			set selected  [lindex $result 0]
			set drawn [lindex $result 1]

			set desc "$desc: Selection: $selected"

		} elseif {$desc == "Digit"} {

			set desc "Digit"
			set digit_desc [build_digit_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$digit_desc"

		} elseif {$game_class == "VKeno"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "VKeno"]

			set game_type [lindex $results 0]
			set num_selected [lindex $results 1]
			set selected [lindex $results 2]
			set matches [lindex $results 3]

			OT_LogWrite 5 "Game Type: $game_type, Num selected: $num_selected, Selected: $selected, matches: $matches"

			set desc "$desc-Game Type: $game_type,Selection:$selected"

		} elseif {$game_class == "Bingo"} {

			set results [set_keno_details_desc $key $ref_id ARRAY "Bingo"]
			set selected [lindex $results 0]
			set matches [lindex $results 1]

			OT_LogWrite 5 "Selected:$selected, Matches:$matches"

			set desc "$desc-Selection:$selected"
		} elseif {$game_class == "XSlot"} {

			set results [set_xslot_details $key $ref_id ARRAY $game_desc]
			set symbols [lindex $results 0]
			set multiplier [lindex $results 1]

			OT_LogWrite 5 "Symbols $symbols - multiplier $multiplier"

			if {$multiplier != "-"} {
				set desc "$desc-Symbols:$symbols - Multiplier:$multiplier"
			} else {
				set desc "$desc-Symbols:$symbols"
			}
		} elseif {$game_class == "BBank"} {

			set bbank_desc [build_bbank_desc $key $ref_id $acct_id ARRAY]

			OT_LogWrite 5 "desc - $bbank_desc"

			set desc "$desc:$bbank_desc"
		} elseif {$game_class == "BSlot"} {

			set values [build_bslot_desc $key $ref_id $acct_id ARRAY]
			set desc "$desc:$values"
		}


		set DATA(bdy,$key,0,desc) $desc



	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	#
	# This is going to be a GAMES entry type (same as a Gentran)
	# but we don't want anythign in payments and receipts field
	# in the admin screens (instead entries in stake & returns)
	# but we do want payments & receipts populated in CSV files
	# so formatting doesnt break (hence the extra variables here).
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


proc get_stmt_entry_CGPW {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set acct_id $DATA(hdr,acct_id)

	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
	}

	if {$ref_key == "IGFP" || $ref_key == "CASP"} {

		if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_cgprog_desc $DATA(bdy,$key,j_op_ref_id)]} msg]} {
				ob::log::write ERROR "Failed to retrieve IGF game $ref_id $acct_id: $msg"
 		       return
		}

		if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find IGF game: $ref_id $acct_id"
				return
			}


		set desc [db_get_col $rs 0 display_name]	;# the display name, this will be appended to later.....
		if {$desc == ""} {
			set desc [db_get_col $rs 0 name]
		}
		set game_class [db_get_col $rs 0 game_class]
		set game_desc [db_get_col $rs 0 name]

		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,channel) [db_get_col $rs 0 source]
		set DATA(bdy,$key,adjustment) $amount

		if {$amount > 0} {
			set DATA(bdy,$key,returns)	  $amount

		} else {
			set DATA(bdy,$key,stake) [db_get_col $rs 0 fixed_stake]
		}
		db_close $rs


		set DATA(bdy,$key,0,desc) $desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}


#
# Netballs bet stake
#
proc get_stmt_entry_NBST {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$ref_key == "NBST"} {

		set balls_sub_id $ref_id

		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Netballs Subscription ($balls_sub_id)"
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
		set DATA(bdy,$key,returns)	  $amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
		set DATA(bdy,$key,stake)	  $amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

#
# Netballs payout
#
proc get_stmt_entry_NBWN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$ref_key == "NBWN"} {

		set balls_sub_id $ref_id

		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Netballs Payout ($balls_sub_id)"
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
		set DATA(bdy,$key,returns)	  $amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
		set DATA(bdy,$key,stake)	 $amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_LB++ {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$ref_key == "LB++"} {

		set balls_sub_id $ref_id

		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Balls Payout ($balls_sub_id)"
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	#
	# This is going to be a GAMES entry type (same as a Gentran)
	# but we don't want anythign in payments and receipts field
	# in the admin screens (instead entries in stake & returns)
	# but we do want payments & receipts populated in CSV files
	# so formatting doesnt break (hence the extra variables here).
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
		set DATA(bdy,$key,returns)	$amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
		set DATA(bdy,$key,stake)	$amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_LB-- {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set DATA(bdy,$key,game_dep) ""
	set DATA(bdy,$key,game_wtd) ""

	if {$ref_key == "LB--"} {

		set balls_sub_id $ref_id

		set DATA(bdy,$key,nrows) 	  1
		set DATA(bdy,$key,0,desc) 	  "Balls Subscription ($balls_sub_id)"
		set DATA(bdy,$key,adjustment) $amount
		set DATA(bdy,$key,channel)    "I"

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}


	#
	# This is going to be a GAMES entry type, we want nothing
	# in their "Payments" & "Receipts" fields in admin screens,
	# but they do want them populated in their CSV files.
	# These extra variables are set for this reason.
	#

	if {$amount >= 0} {
		set DATA(bdy,$key,game_dep)	$amount
		set DATA(bdy,$key,returns)	  $amount
	} else {
		set DATA(bdy,$key,game_wtd)	$amount
		set DATA(bdy,$key,stake)	  $amount
	}

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}



proc get_stmt_entry_BURF {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	set desc "Unsettled Bet Refund"

	get_stmt_entry_BUST $key $amount DATA $desc

}



proc get_stmt_entry_BUWN {key amount ARRAY} {

	upvar 1 $ARRAY DATA
	set desc "Unsettled Bet Winnings"

	get_stmt_entry_BUST $key $amount DATA $desc

}



proc get_stmt_entry_BUST {key amount ARRAY {desc "Unsettled bet"}} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)

	if {$ref_key == "ESB"} {
		set receipt ""
		#
		# get bet description entry
		#
		set rs [tb_db::tb_exec_qry tb_stmt_get_esb_desc $ref_id]

		#
		# If no rows are returned this might be a manual bet
		#
		if {[db_get_nrows $rs] == 0} {

			#
			# get bet description entry
			#
			set man_rs [tb_db::tb_exec_qry tb_stmt_get_esb_man_desc $ref_id]

			if {[db_get_nrows $man_rs] > 0} {
				set receipt [db_get_col $man_rs 0 receipt]
			}

			db_close $man_rs

		} else {
			set receipt [db_get_col $rs 0 bet_receipt]
		}

		db_close $rs

		if {$receipt == ""} {
			set desc "$desc ($ref_id)"
		} else {
			set desc "$desc ($receipt)"
		}

		set DATA(bdy,$key,nrows)   1
		set DATA(bdy,$key,0,desc)  $desc
		set DATA(bdy,$key,channel) ""

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc)   "Unknown ref key!!"
	}
	set DATA(bdy,$key,wtd)	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key
}



proc get_stmt_entry_XSIN {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "XSYS"} {

		set DATA(bdy,$key,nrows)	1
		set DATA(bdy,$key,channel)	""
		set DATA(bdy,$key,0,desc)	$desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	set DATA(bdy,$key,dep)	  	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_XSOT {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "XSYS"} {

		set DATA(bdy,$key,nrows)	1
		set DATA(bdy,$key,channel)	""
		set DATA(bdy,$key,0,desc)	$desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	set DATA(bdy,$key,wtd)	  	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

proc get_stmt_entry_XSRF {key amount ARRAY} {

	upvar 1 $ARRAY DATA

	set ref_key $DATA(bdy,$key,j_op_ref_key)
	set ref_id  $DATA(bdy,$key,j_op_ref_id)
	set desc    $DATA(bdy,$key,desc)

	if {$ref_key == "XSYS"} {

		set DATA(bdy,$key,nrows)	1
		set DATA(bdy,$key,channel)	""
		set DATA(bdy,$key,0,desc)	$desc

	} else {
		OT_LogWrite 1 "ERROR: unknown j_op_ref_key ($DATA(bdy,$key,j_op_ref_key))"
		set DATA(bdy,$key,nrows) 	1
		set DATA(bdy,$key,0,desc) 	"Unknown ref key!!"
	}

	set DATA(bdy,$key,wtd)	  	$amount

	adjust_rolling_balance $key $ARRAY

	#Return the key value of the last row
	return $key

}

#
# Telebetting multi-lingual stuff (needs to be put elsewhere).  Hard Coded to "en"
#

proc tb_ml_printf {key args} {

	global LOGIN_DETAILS
	variable MSG

	#set lang $LOGIN_DETAILS(LANG)
	set lang "en"
	# does a translation exist in the cache?
	if {[info exists MSG($key,$lang)]} {
		set tmp $MSG($key,$lang)
	} else {
		set tmp [get_message $key $lang]
		tb_ml_insert $key $lang $tmp
	}

	if {$tmp!=""} {
		set key $tmp
	}

	OT_LogWrite 5 "key=$key"
	# If there are no % signs, just return the key.
	if {[string first % $key] < 0 || [llength $args] == 0} {
		return $key
	} else {
		# Try and sub the args in.
		if {[catch {set key [eval [linsert $args 0 format $key]]} msg]} {
			# If that fails, try and regsub all the potentially bogus % signs out
			OT_LogWrite 5 "Sub failed with: $msg"
			if {[catch {
				# regsub percent signs with %% iff there follows:
				# 0/1 of: ?!([1-9]\d*\$ , then
				# 0/more of: -0 , then
				# 0/1 of: [1-9]\d*|\* , then
				# 0/1 of: \.\d+ , then
				# 1 of: duisf
				#
				# This selection was based on an analysis of actually used
				# format specifiers. See call #42587 journals 46 for details.
				# Unused formats are not specified due to the possibility of
				# false positives.
				# Already-doubled percent signs will be re-doubled. These will
				# have to be re-corrected by hand.
				regsub -all {%(?!([1-9]\d*\$)?[-0]*([1-9]\d*)?(\.\d+)?[duisf])} $key {%%} key
				set key eval [linsert $args 0 format $key]]
			} msg]} {
				# If that fails, just return the key.
				OT_LogWrite 5 "Final regsub failed due to: ${msg}, key=$key"
			}
		}
	}
	# We always return key at the end.
	return $key
}

proc get_message {key lang} {

	# attempt the query
	set rs [tb_db::tb_exec_qry get_message_xl $key $lang]

	# should return 1 row
	if {[db_get_nrows $rs] != 1} {
		set message ""
	} else {
		set message "[db_get_col $rs 0 xlation_1][db_get_col $rs 0 xlation_2][db_get_col $rs 0 xlation_3][db_get_col $rs 0 xlation_4]"
	}

	db_close $rs
	return $message
}


# ----------------------------------------------------------------------
# Put an entry in MSG
# key is the english version
# lang is 2 character language code
# xlation is the relevant translation
# ----------------------------------------------------------------------

proc tb_ml_insert {key lang xlation} {
	variable MSG

	set MSG($key,$lang) $xlation
}


# ----------------------------------------------------------------------
# XL translates all symbols marked up for translation in the given phrase
# symbols are marked up by enclosing them in pipes |<symbol>|
# |ARSE| |VS| |MANU| should be transalated to
# Arsenal V Manchester Utd (in english)
# ----------------------------------------------------------------------

proc TB_XL {str} {

	set res ""
	while {[regexp {([^\|]*)\|([^\|]*)\|(.*)} $str match head code str]} {
		append res $head
		append res [tb_ml_printf $code]
	}
	append res $str
	return $res
}


proc get_stmt_ap_bets {ARRAY} {

	upvar 1 $ARRAY DATA

	set rs [tb_db::tb_exec_qry tb_stmt_get_ap_bets $DATA(hdr,acct_id) $DATA(hdr,due_to) $DATA(hdr,due_to)]
	set DATA(ftr,num_ap)    [db_get_nrows $rs]
	set stakes_outstanding  0.00


	for {set j 0} {$j < $DATA(ftr,num_ap)} {incr j} {
		build_bet_desc "ftr,$j" [db_get_col $rs $j bet_id] DATA BSTK ""

		set stakes_outstanding [expr $stakes_outstanding + $DATA(ftr,$j,stake)]
		set DATA(ftr,$j,cr_date) [db_get_col $rs $j cr_date]
	}
	db_close $rs

	set DATA(hdr,stakes_os) [format "%.2f" $stakes_outstanding]
}



proc tb_stmt_get_pay_mthd {pmt_id} {

	set rs [tb_db::tb_exec_qry tb_stmt_get_gpmt_desc $pmt_id]

	if {[db_get_nrows $rs] == 0} {
		return ">>>>>>"
	}

	set pay_mthd [db_get_col $rs 0 pay_mthd]
	set desc     [db_get_col $rs 0 desc]
	set source   [db_get_col $rs 0 source]
	set status   [db_get_col $rs 0 status]
	db_close $rs

	if {$pay_mthd == "GDEP"} {
		set rs       [tb_db::tb_exec_qry tb_stmt_get_gdep_type $pmt_id]
		set pay_type [db_get_col $rs 0 pay_type]
		db_close $rs
		return [list $pay_type $source $status]
	}
	return [list $desc $source $status]
}

#------------------------------------------------------------------------------
# Build the description for an XGame bet
#------------------------------------------------------------------------------
proc build_xgame_bet_desc {key sub_id ARRAY type {amount ""} {prefix ""}} {

	upvar 1 $ARRAY DATA

	#Debug the proc call
	log_proc_call 20

	# External Games
	set rs [tb_db::tb_exec_qry tb_stmt_get_xgam_desc $sub_id]

	if {[db_get_nrows $rs] == 0} {
		error "Cannot find entry for xgame id $sub_id"
	}

	# See if we have a prefix
	set prefix [string trim $prefix]
	if [string length $prefix] {
		set prefix "$prefix "
	}

	# Retrieve and format the game description fields
	set game_name  [db_get_col $rs 0 game_name]
	set desc       [db_get_col $rs 0 desc]
	set comp_no    [db_get_col $rs 0 comp_no]
	set picks      [join [split [db_get_col $rs 0 picks] "|"] " "]

	set DATA($key,nrows) 	   1
	set DATA($key,entry_type)  XGSUB
	set DATA($key,0,desc) 	  "${prefix}$game_name (${desc}) - $picks"

	set DATA($key,game_name)      $game_name
	set DATA($key,draw_desc)      $desc
	set DATA($key,comp_no)        $comp_no
	set DATA($key,picks)          $picks
	set DATA($key,receipt)        "L/[db_get_col $rs 0 acct_id]/[db_get_col $rs 0 xgame_sub_id]"
	set DATA($key,channel)        [db_get_col $rs 0 source]
	set DATA($key,sort)           [db_get_col $rs 0 sort]
	set DATA($key,draw_time)      [db_get_col $rs 0 draw_time]
	set DATA($key,num_subs)       [db_get_col $rs 0 num_subs]
	set DATA($key,num_lines)      [db_get_col $rs 0 num_lines]
	set DATA($key,stake_per_bet)  [db_get_col $rs 0 stake_per_bet]
	set DATA($key,price)          [db_get_col $rs 0 prices]
	set DATA($key,num_picks)      [db_get_col $rs 0 num_picks]
	set DATA($key,total_winnings) [db_get_col $rs 0 total_winnings]
	set DATA($key,subs_remaining) [db_get_col $rs 0 subs_remaining]
	set DATA($key,winning_bets)   [db_get_col $rs 0 winning_bets]
	set DATA($key,token_value)    [db_get_col $rs 0 token_value]
	set DATA($key,bet_type)       [db_get_col $rs 0 bet_type]
	set DATA($key,isxgame)        1
	set DATA($key,consec_draws) 1

	if {$DATA($key,num_subs) > 1} {
			set draw_descs [split [db_get_col $rs 0 draws] |]
	   		if {[expr [llength $draw_descs] - 2] > 1} {
			set DATA($key,consec_draws) 1
			set DATA($key,0,desc) 	  "${prefix}$game_name (${desc}) - $picks (for the next $DATA($key,num_subs) draws)"
		} else {
			set DATA($key,consec_draws) 0
			set draw_string " draws"
			if { [regexp -nocase {(draw)$} $desc] } {
				set draw_string "s"
			}
			set DATA($key,0,desc) 	  "${prefix}$game_name (${desc}) - $picks (for the next $DATA($key,num_subs) $desc$draw_string)"
		}
	}



	# Different fields for different operations
	if {$type == "BSTK"} {
		#
		# Bet Placement
		#
		#If we're not passed an amount then extract it from the resultset
		if {$amount == ""} {
			set DATA($key,stake)	  [expr [db_get_col $rs 0 amount] * -1]
		} else {
			set DATA($key,stake)	  $amount
		}
		set DATA($key,adjustment)     $DATA($key,stake)
	} else {
		#
		# Bet returns
		#
				set DATA($key,returns)          [format "%.2f" [db_get_col $rs 0 total_winnings]]
				set DATA($key,adjustment)       $DATA($key,returns)

	}

	#Cleanup
	db_close $rs
}

proc build_man_bet_desc {key bet_id ARRAY type amount} {

	upvar 1 $ARRAY DATA

	OT_LogWrite 5 "==> build_man_bet_desc"

	#
	# get bet description entry
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_esb_man_desc $bet_id]

	if {[db_get_nrows $rs] == 0} {
		return 0
	}

	set DATA($key,bet_id)         $bet_id
	set DATA($key,bet_type)       [db_get_col $rs 0 bet_type]
	set DATA($key,receipt)        [db_get_col $rs 0 receipt]
	set DATA($key,channel)        [db_get_col $rs 0 source]
	set DATA($key,num_lines)      [db_get_col $rs 0 num_lines]
	set DATA($key,leg_type)       [db_get_col $rs 0 leg_type]
	set DATA($key,tax_type)       [db_get_col $rs 0 tax_type]
	set DATA($key,stake_per_line) [db_get_col $rs 0 stake_per_line]

	# Flag for hedging bets
	set is_hedged 0

	set DATA($key,nrows)         1
	set DATA($key,0,part_no)     0
	set DATA($key,0,leg_sort)    "--"
	set DATA($key,0,desc)        "[db_get_col $rs 0 desc_1][db_get_col $rs 0 desc_2][db_get_col $rs 0 desc_3][db_get_col $rs 0 desc_4]"
	set DATA($key,0,price_type)  ""
	set DATA($key,0,price)       ""
	set DATA($key,0,hcap_value)  ""
	set DATA($key,0,rule4)       ""

	if {$type == "BSTK"} {
		#
		# bet placement
		#
		set bet_stake_total        [db_get_col $rs 0 bet_stake_total]
		set DATA($key,stake)       [format "%.2f" [expr {$bet_stake_total * -1}]]
		set DATA($key,adjustment)  $DATA($key,stake)

	} elseif {$type == "HSTK"} {
		#
		# Hedged bet placement, note that for these bets we credit the account rather than debit
		#
		set bet_stake_total        [db_get_col $rs 0 bet_stake_total]
		set DATA($key,stake)       [format "%.2f" $bet_stake_total]
		set DATA($key,adjustment)  $DATA($key,stake)
		set is_hedged 1
	} else {
		#
		# bet returns
		#
		set DATA($key,num_lines_void)   [db_get_col $rs 0 num_lines_void]
		set DATA($key,num_lines_win)    [db_get_col $rs 0 num_lines_win]
		set DATA($key,num_lines_lose)   [db_get_col $rs 0 num_lines_lose]

		set DATA($key,returns)          $amount
		set DATA($key,adjustment)       $amount

		# Mark if hedged bet
		if {$type == "HWIN" || $type == "HRFD"} {
			set is_hedged 1
		}
	}

	# Set entry type depending on journal type
	if {$is_hedged} {
		set DATA($key,entry_type) HMANBET
	} else {
		set DATA($key,entry_type) MANBET
	}

	if {[db_get_col $rs 0 paid] != "Y"} {

		set DATA($key,ap) "AP"

		if {$type == "BSTK"} {
			#
			# ap bet stake
			#
			set DATA($key,adjustment) 0
		}

	} else {
		set DATA($key,ap) ""
	}

	db_close $rs

	return 1
}


proc build_bet_desc {key bet_id ARRAY type amount} {

	upvar 1 $ARRAY DATA

	#Log the procedure call for debug purposes
	log_proc_call 20

	#
	# get bet description entry
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_esb_desc $bet_id]

	#
	# If no rows are returned this might be a manual bet
	#
	if {[db_get_nrows $rs] == 0} {

		if {[build_man_bet_desc $key $bet_id DATA $type $amount] == 0} {
			#
			# failed to locate bet information
			#
			OT_LogWrite 1 "WARNING Failed to locate information for bet ($bet_id)"
		}
		return
	}

	set DATA($key,bet_id)     $bet_id

	set DATA($key,bet_type)       [db_get_col $rs 0 bet_type]
	set DATA($key,receipt)        [db_get_col $rs 0 bet_receipt]
	set DATA($key,channel)        [db_get_col $rs 0 channel]
	set DATA($key,num_lines)      [db_get_col $rs 0 num_lines]
	set DATA($key,leg_type)       [db_get_col $rs 0 leg_type]
	set DATA($key,tax_type)       [db_get_col $rs 0 tax_type]
	set DATA($key,token_value)    [db_get_col $rs 0 token_value]
	set DATA($key,stake_per_line) [db_get_col $rs 0 bet_stake_per_line]

	set time [db_get_col $rs 0 bet_date]

	# Flag for hedging bets
	set is_hedged 0

	if {$type == "BSTK"} {
		#
		# bet placement
		#
		set bet_stake_total        [db_get_col $rs 0 bet_stake_total]
		set DATA($key,stake)       [format "%.2f" [expr {$bet_stake_total * -1}]]
		set DATA($key,adjustment)  [format "%.2f" [expr {($bet_stake_total - $DATA($key,token_value)) * -1}]]

	} elseif {$type == "HSTK"} {
		#
		# Hedged bet placement, note that for these bets we credit the account rather than debit
		#
		set bet_stake_total        [db_get_col $rs 0 bet_stake_total]
		set DATA($key,stake)       [format "%.2f" $bet_stake_total]
		set DATA($key,adjustment)  [format "%.2f" [expr {$bet_stake_total - $DATA($key,token_value)}]]
		set is_hedged 1
	} else {
		#
		# bet returns
		#
		set DATA($key,num_lines_void)   [db_get_col $rs 0 num_lines_void]
		set DATA($key,num_lines_win)    [db_get_col $rs 0 num_lines_win]
		set DATA($key,num_lines_lose)   [db_get_col $rs 0 num_lines_lose]

		# old code from before resettlement fix
		#set DATA($key,returns)          [format "%.2f" [db_get_col $rs 0 bet_returns_total]]
		#set DATA($key,adjustment)       $DATA($key,returns)

		# now use the journal amount for returns to cope with resettled bets
		# where the returns in tbet may not match the jounral entry
		set DATA($key,returns)    $amount
		set DATA($key,adjustment) $amount

		# Mark if hedged bet
		if {$type == "HWIN" || $type == "HRFD"} {
			set is_hedged 1
		}
	}

	# Set entry type depending on journal type
	if {$is_hedged} {
		set DATA($key,entry_type) HBET
	} else {
		set DATA($key,entry_type) BET
	}

	if {[db_get_col $rs 0 paid] != "Y"} {

		set DATA($key,ap) "AP"

		if {$type == "BSTK"} {
			#
			# ap bet stake
			#
			set DATA($key,adjustment) 0

		}

	} else {
		set DATA($key,ap) ""
	}

	set nrows [db_get_nrows $rs]
	set prev_leg_sort ""
	OT_LogWrite 4 "build_bet_desc: found $nrows rows"

	for {set i 0} {$i < $nrows} {incr i} {

		set DATA($key,$i,oc_name)     [TB_XL [db_get_col $rs $i oc_name]]
		set DATA($key,$i,ev_name)     [TB_XL [db_get_col $rs $i ev_name]]
		set DATA($key,$i,mkt_name)    [TB_XL [db_get_col $rs $i mkt_name]]
		set DATA($key,$i,type_name)   [TB_XL [db_get_col $rs $i type_name]]
		set DATA($key,$i,class_name)  [TB_XL [db_get_col $rs $i class_name]]

		set DATA($key,$i,leg_sort)    [db_get_col $rs $i leg_sort]
		set DATA($key,$i,ev_mkt_id)   [db_get_col $rs $i ev_mkt_id]

		# if the bir index is present then append it to the event name
		# (this is used to record eg the game number in a tennis match)
		# the leg_sort should be "CW" but I'm not going to enforce it here.
		## note: moved from mkt_name as that was not diplayed on statement (PT4174)

		set bir_index                 [db_get_col $rs $i bir_index]
		if {$bir_index != "" && $bir_index > 0} {
			set DATA($key,$i,ev_name) "$DATA($key,$i,ev_name) ($bir_index)"
		}

		set price_type [db_get_col $rs $i price_type]
		set DATA($key,$i,price_type)  $price_type
		set DATA($key,$i,price)       [build_price $DATA($key,$i,price_type) \
												[db_get_col $rs $i o_num] \
												[db_get_col $rs $i o_den] \
												DATA]

		set DATA($key,$i,hcap_value)  [db_get_col $rs $i hcap_value]

		if {[has_rule_4 [db_get_col $rs $i ev_mkt_id]] && $type != "BSTK" && $type != "HSTK"} {

			set result [get_rule_4_info [db_get_col $rs $i ev_oc_id]]
			if {$result == "W" || $result == "P"} {

				set deduction [get_rule_4_deduction [db_get_col $rs $i ev_mkt_id] $time $price_type]
				set DATA($key,$i,rule4) $deduction
			} else {
				set DATA($key,$i,rule4) ""
			}
		} else {
			set DATA($key,$i,rule4) ""
		}


		# record the part number
		if {$prev_leg_sort != $DATA($key,$i,leg_sort)} {
			set prev_leg_sort $DATA($key,$i,leg_sort)
			set j 0
		}
		set DATA($key,$i,part_no) $j
		incr j

		# Leg sort specific stuff
		set leg_sort $DATA($key,$i,leg_sort)
		switch -regexp -- $leg_sort {

			"AH|hl" {

				# Uppercase the leg sort - for high/low
				set DATA($key,$i,leg_sort) [string toupper $leg_sort]

				# For AH reverse the handicap for the away team
				set hcap_value $DATA($key,$i,hcap_value)
				if {$leg_sort == "AH" && [db_get_col $rs $i fb_result] == "A"} {
					set hcap_value [expr {$hcap_value * -1}]
				}

				# Make split handicap string
				set DATA($key,$i,hcap_value) [mk_ah_str [expr {int($hcap_value)}]]

				# Always display price as decimal
				set DATA($key,$i,price) [mk_price [db_get_col $rs $i o_num] [db_get_col $rs $i o_den] DECIMAL]
			}
		}

		# If it's a hedging bet, add the description
		if {$is_hedged} {
			set DATA($key,$i,desc) "Hedged bet on $DATA($key,$i,oc_name) at $DATA($key,$i,ev_name) at price $DATA($key,$i,price)"
			if {$DATA($key,$i,rule4) != ""} {
				set DATA($key,$i,desc) "$DATA($key,$i,desc) with Rule4 applied at $DATA($key,$i,rule4)"
			}
		}

		if {$DATA(hdr,brief) == "Y"} {
			break
		}
	}
	set DATA($key,nrows) $j
	set DATA($key,nlegs) $nrows

	db_close $rs

	OT_LogWrite 10 "<<< build_bet_desc"
}


proc build_pools_bet_desc {key bet_id ARRAY type} {

	upvar 1 $ARRAY DATA

	#
	# get bet description entry
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_pools_desc $bet_id]

	#
	# If no rows are returned this might be a manual bet
	#
	if {[db_get_nrows $rs] == 0} {
		OT_LogWrite 1 "WARNING Failed to locate information for pools bet ($bet_id)"
		return
	}

	set DATA($key,bet_id)     $bet_id
	set DATA($key,entry_type) BET
		if {[db_get_col $rs 0 bet_type] == "DLEG"} {
				#
				# If bet_type id dleg perform a second query to
				# determine full bet type, one of Win/Shw, Win/Plc or Plc/Shw
				#
				set res [tb_db::tb_exec_qry tb_stmt_get_dleg_type $bet_id]
				for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
						lappend dleg_type [db_get_col $res $r pool_type_id]
				}
				db_close $res
				if {[lsearch $dleg_type WIN] == -1} {
						set dleg_bet_type "Plc/Shw"
				} else {
						if {[lsearch $dleg_type PLC] == -1} {
							    set dleg_bet_type "Win/Shw"
						} else {
							    set dleg_bet_type "Win/Plc"
						}
				}
				set DATA($key,bet_type) $dleg_bet_type
		} elseif { [db_get_col $rs 0 bet_type] == "TLEG"} {
				set DATA($key,bet_type) "Win/Plc/Shw"
		} else {
				set pool_type [db_get_col $rs 0 pool_type]
				if {$pool_type == "Win" || $pool_type == "Place"} {
					set pool_type "Tote $pool_type"
				}
				set DATA($key,bet_type)  $pool_type
		}
	set DATA($key,receipt)    [db_get_col $rs 0 bet_receipt]
	set DATA($key,channel)    [db_get_col $rs 0 channel]
	set DATA($key,num_lines)  [db_get_col $rs 0 num_lines]
	set DATA($key,leg_type)   [db_get_col $rs 0 leg_type]
	set DATA($key,tax_type)   ""
	set DATA($key,token_value) "0.00"
	set DATA($key,ispools)    1
	set time [db_get_col $rs 0 bet_date]

	if {$type == "BSTK"} {
		#
		# bet placement
		#
		set DATA($key,stake)      [format "%.2f" [expr [db_get_col $rs 0 bet_stake_total] * -1]]
		set DATA($key,adjustment) $DATA($key,stake)

	} else {
		#
		# bet returns
		#
		set DATA($key,num_lines_void)   [db_get_col $rs 0 num_lines_void]
		set DATA($key,num_lines_win)    [db_get_col $rs 0 num_lines_win]
		set DATA($key,num_lines_lose)   [db_get_col $rs 0 num_lines_lose]

		set DATA($key,returns)          [format "%.2f" [db_get_col $rs 0 bet_returns_total]]
		set DATA($key,adjustment)       $DATA($key,returns)

	}

	if {[db_get_col $rs 0 paid] != "Y"} {

		set DATA($key,ap) "AP"

		if {$type == "BSTK"} {
			#
			# ap bet stake
			#
			set DATA($key,adjustment) 0

		}

	} else {
		set DATA($key,ap) ""
	}

	set nrows [db_get_nrows $rs]
	set prev_leg_sort ""
	set mod_nrows 0

	for {set i 0} {$i < $nrows} {incr i} {

		# The pools display text seeme to be forever changing, so set up variables and
		# have the actual strings set through a config items
		set oc_name [to_proper_case [db_get_col $rs $i oc_name]]
		set ev_mkt_id [db_get_col $rs $i ev_mkt_id]
		set ev_name [db_get_col $rs $i ev_name]

		# Change the text of TOTE scoop 6 pools from 'Clone Race of ...'
		regexp {^Clone Race of } $ev_name match1
		if {[info exists match1]} {
			regsub "Clone Race of " $ev_name {} ev_name
			set k [string first "Race" $ev_name]
			if {$k > 0} {
				set i_start [string trim [string range $ev_name 0 [expr {$k - 1}]]]
				set i_end [string range $ev_name $k end]
				set ev_name "$i_start Scoop 6 $i_end"
			} else {
				append ev_name " Scoop 6"
			}
		}

		set meeting [TB_XL [db_get_col $rs $i meeting]]
		set ev_date [clock format [clock scan [db_get_col $rs $i meeting_date]] -format "%d %b %Y"]
		set runner  [db_get_col $rs $i runner_num]
		set banker  [db_get_col $rs $i banker_info]
		set pool_type_id [db_get_col $rs $i pool_type_id]
		if [regexp "^B(\[0-9\]+)\$" $banker all num] {
			# Format into a more readable form
			set banker " (Banker $num)"
		}

		# Perform the substitutions to retrieve the final text
		set disp_oc_name [subst [OT_CfgGet POOLS_STMT_OC_NAME_TXT {$oc_name}]]
		set disp_ev_name [subst [OT_CfgGet POOLS_STMT_EV_NAME_TXT {$ev_name}]]
		set duplicate -1
		if {[OT_CfgGet STMT_SINGLE_LINE_POOL_PERMS 0]} {
			set bettypes [OT_CfgGet STMT_SINGLE_LINE_POOL_TYPES ""]
			if {[lsearch $bettypes $pool_type_id] != -1} {
				for {set j 0} {$j < $mod_nrows} {incr j} {
					if {$disp_ev_name == $DATA($key,$j,ev_name)} {
						set duplicate $j
					}
				}
			}
		}
		if {$duplicate >= 0} {
			set DATA($key,$duplicate,oc_name) "$DATA($key,$duplicate,oc_name) $disp_oc_name"
		} else {

			set DATA($key,$mod_nrows,oc_name)     $disp_oc_name
			set DATA($key,$mod_nrows,ev_name)     $disp_ev_name
			set DATA($key,$mod_nrows,mkt_name)    [TB_XL [db_get_col $rs 0 pool_name]]
			set DATA($key,$mod_nrows,type_name)   ""
			set DATA($key,$mod_nrows,class_name)  [TB_XL [db_get_col $rs 0 source_name]]

			set DATA($key,$mod_nrows,desc)  "$DATA($key,$mod_nrows,class_name): $DATA($key,$mod_nrows,mkt_name): [TB_XL [db_get_col $rs $i oc_name]]"

			set DATA($key,$mod_nrows,leg_sort)    ""
			set DATA($key,$mod_nrows,price_type)  ""

			set DATA($key,$mod_nrows,price)       ""

			set DATA($key,$mod_nrows,hcap_value)  ""

			if {[has_rule_4 [db_get_col $rs $i ev_mkt_id]] && $type != "BSTK"} {
				set result [get_rule_4_info [db_get_col $rs $i ev_oc_id]]
				if {$result == "W" || $result == "P"} {
					set deduction [get_rule_4_deduction [db_get_col $rs $i ev_mkt_id] $time]
					set DATA($key,$mod_nrows,rule4) $deduction
				} else {
					set DATA($key,$mod_nrows,rule4) ""
				}
			} else {
				set DATA($key,$mod_nrows,rule4) ""
			}
			#Is $i the correct leg number to display??
			set DATA($key,$mod_nrows,part_no) $i
			incr mod_nrows
		}

		if {$DATA(hdr,brief) == "Y"} {
			break
		}
	}
	set DATA($key,nrows) $mod_nrows

	db_close $rs
}



###
# Checks to see if rule4 applies to bet
###
proc has_rule_4 {ev_mkt_id} {

	set rs    [tb_db::tb_exec_qry tb_stmt_get_mkt_rule4_deductions $ev_mkt_id]
	set nrows [db_get_nrows $rs]
	db_close $rs
	if {$nrows != 0} {
		return 1
	}

	return 0
}



###
# Gets the result of the Race: i.e. W(in) or P(lace).
# If the result hasn't been confirmed, then the result should be treated as "-".
###
proc get_rule_4_info {ev_oc_id} {

	set rs [tb_db::tb_exec_qry tb_stmt_check_rule4 $ev_oc_id]

	set result [db_get_col $rs result]
	set confirmed [db_get_col $rs confirmed]

	if {$confirmed == "N"} {
		set result "-"
	}

	db_close $rs

	return $result

}



###
# Gets the deduction applied (pence in pound)
###
proc get_rule_4_deduction {ev_mkt_id time {which_market ""}} {

	set rs [tb_db::tb_exec_qry tb_stmt_get_mkt_rule4_deductions $ev_mkt_id]

	set nrows [db_get_nrows $rs]

	set deduction 0

	for {set i 0} {$i < $nrows} {incr i} {

		set market    [db_get_col $rs $i market]
		set time_from [db_get_col $rs $i time_from]
		set time_to   [db_get_col $rs $i time_to]
		set dedn [db_get_col $rs $i deduction]

		if {$market == $which_market || $which_market == ""} {

			if {$time >= $time_from && $time <= $time_to} {
					incr deduction $dedn
			}
		}

	}

	if {$deduction > [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]} {
		set deduction [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]
	}

	db_close $rs
	return $deduction
}



proc build_price {type opn opd ARRAY} {

	upvar 1 $ARRAY DATA

	switch -- $type {
		"D" {return "DIV"}
		"S" {return "SP"}
		"B" {return "Best"}
		"1" {return "1st"}
		"2" {return "2nd"}
		"N" {return "Next"}
		"L" {return [tb_statement_build::mk_price $opn $opd $DATA(hdr,price_type)]}
		"G" {return "GP"}
	}
}



proc write_comma_sep_values {f_id args} {

	set sub_quote [list]

	foreach f $args {
		regsub -all "\"" $f "\\\"" f2
		# Replace end of line characters with appropriate character/code from
		# config
		if {[OT_CfgGet STMT_REPLACE_LINE_END 0]} {
			set line_end [OT_CfgGet STMT_LINE_END_CODE]
			set f2 [regsub -all (\n|\x0a) $f2 $line_end]
			set f2 [regsub -all {\x0d} $f2 ""]
		}
		lappend sub_quote $f2
	}

	puts $f_id \"[join $sub_quote \",\"]\"
}



proc write_stmt_to_file {f_id ARRAY} {

	upvar 1 $ARRAY DATA

	OT_LogWrite 20 "==> write_stmt_to_file"

	#
	# Different process for CSV or PS files
	#
	if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {

		variable ROW_PROCS

		#
		# Here we go into the ::cust_stmt namespace to get a list of defined
		# procs. This way, we know which row types have defined procs and
		# which to send to the DEFAULT proc
		#
		namespace eval ::cust_stmt {
			set ::tb_statement_build::ROW_PROCS [info commands "get_ps_*"]
		}

		write_ps_client_row $f_id DATA
		write_ps_data_row   $f_id DATA

	} else {

		#
		# write the header
		#
		write_stmt_hdr_to_file $f_id DATA

		#
		# the body
		#
		write_stmt_body_to_file $f_id DATA
	}

	OT_LogWrite 20 "<== write_stmt_to_file"

}


proc write_stmt_hdr_to_file {f_id ARRAY} {

	OT_LogWrite 20 "==> write_stmt_hdr_to_file"

	upvar 1 $ARRAY DATA

	switch -- $DATA(hdr,pmt_type) {
		"REQ"   { set pmt_type "REQUIRED" }
		"SNT"   { set pmt_type "SENT" }
		default { set pmt_type "NEITHER"}
	}

	if {[OT_CfgGet STMT_CLOSE_BAL_IF_NO_PMT 0]} {
		if {$DATA(hdr,pmt_amount_abs) == 0} {
			set DATA(hdr,pmt_amount_abs) $DATA(hdr,close_bal)
		}
	}

	write_comma_sep_values $f_id CLIENT \
								 $DATA(hdr,acct_type) \
								 $DATA(hdr,acct_no) \
								 $DATA(hdr,username) \
								 $DATA(hdr,title) \
								 $DATA(hdr,fname) \
								 $DATA(hdr,lname) \
								 $DATA(hdr,addr_street_1) \
								 $DATA(hdr,addr_street_2) \
								 $DATA(hdr,addr_street_3) \
								 $DATA(hdr,addr_street_4) \
								 $DATA(hdr,addr_city) \
								 $DATA(hdr,addr_postcode) \
								 $DATA(hdr,country_name) \
								 $DATA(hdr,due_from) \
								 $DATA(hdr,due_to) \
								 $DATA(hdr,open_bal) \
								 $DATA(hdr,close_bal) \
								 $DATA(hdr,ccy_code) \
								 $DATA(hdr,credit_limit) \
								 $DATA(hdr,cust_code) \
								 $pmt_type \
								 $DATA(hdr,pmt_method) \
								 $DATA(hdr,pmt_desc) \
								 [format %.2f $DATA(hdr,pmt_amount_abs)] \
								 $DATA(hdr,stakes_os) \
								 $DATA(hdr,cust_msg) \
								 $DATA(hdr,win_indication) \
								 $DATA(hdr,total_staked) \
								 $DATA(hdr,total_returns) \
								 $DATA(hdr,vet_code) \
								 $DATA(hdr,total_deposits) \
								 $DATA(hdr,total_withdrawals) \
								 $DATA(hdr,chq_payee)

}

proc write_stmt_body_to_file {f_id ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	for {set i 0} {$i < $DATA(bdy,num_txns)} {incr i} {
		if {[lsearch {"BET" "MANBET" "TXN" "XGSUB" "XGSTL" "HBET" "HMANBET"} \
				$DATA(bdy,$i,entry_type)] == -1} {
			OT_LogWrite 1 "Unknown entry type ($DATA(bdy,$i,entry_type))"
			error "unknown entry type ($DATA(bdy,$i,entry_type))"
		}
		set a $DATA(bdy,$i,entry_type)
		write_stmt_entry_${a} $f_id $i DATA
	}
}

proc write_stmt_entry_TXN {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	set type "GENTRAN"

	if {[OT_CfgGet STMT_MAP_XSYS 0] && \
		[lsearch [list XSIN XSOT XSRF] $DATA(bdy,$key,j_op_type)] != -1} {
		ob::log::write DEBUG {mapping $DATA(bdy,$key,0,desc), \
			to: [OT_CfgGet STMT_XSYS_MAPPINGS ""]}
		set desc [split $DATA(bdy,$key,0,desc) " "]
		set desc [string trim [lindex $desc 1] ()]
		set desc [string map [OT_CfgGet STMT_XSYS_MAPPINGS ""] $desc]
		set DATA(bdy,$key,0,desc) $desc
	}

	#
	# Checking the j_op_type so that for games entries will still go in the dep,wtd fields in CSV file,
	# but nothing shall be entered into "Payments" & "Receipts" fields in admin screens.
	#
	if {[lsearch {"CGSK" "CGWN" "LB--" "LB++" "CGPS" "CGPW" "NBWN" "NBST"} $DATA(bdy,$key,j_op_type)] != -1} {

		set DATA(bdy,$key,dep) $DATA(bdy,$key,game_dep)
		set DATA(bdy,$key,wtd) $DATA(bdy,$key,game_wtd)
		set type "GAMES"

	}

		if {[lsearch {"BXCG"} $DATA(bdy,$key,j_op_type)] != -1} {
				 set DATA(bdy,$key,dep) $DATA(bdy,$key,betx_dep)
				 set DATA(bdy,$key,wtd) $DATA(bdy,$key,betx_wtd)
		}

	foreach f {dep wtd channel} {
		if {![info exists DATA(bdy,$key,$f)]} {
			set DATA(bdy,$key,$f) ""
		}
	}

	if {[OT_CfgGet STMT_DISP_XTERNAL_SYSTEM_ID 0]} {
		write_comma_sep_values $f_id $type \
								 $DATA(bdy,$key,cr_date) \
								 $DATA(bdy,$key,channel) \
								 $DATA(bdy,$key,0,desc) \
								 $DATA(bdy,$key,dep) \
								 $DATA(bdy,$key,wtd) \
								 $DATA(bdy,$key,balance) \
								 $DATA(bdy,$key,system_id)

	} else {
		write_comma_sep_values $f_id $type \
								 $DATA(bdy,$key,cr_date) \
								 $DATA(bdy,$key,channel) \
								 $DATA(bdy,$key,0,desc) \
								 $DATA(bdy,$key,dep) \
								 $DATA(bdy,$key,wtd) \
								 $DATA(bdy,$key,balance)
	}
}



proc write_stmt_entry_MANBET {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	foreach f {returns stake num_lines_win num_lines_lose num_lines_void} {
		if {![info exists DATA(bdy,$key,$f)]} {
			set DATA(bdy,$key,$f) ""
		}
	}

	write_comma_sep_values $f_id MANBET \
								$DATA(bdy,$key,cr_date) \
								$DATA(bdy,$key,receipt) \
								$DATA(bdy,$key,channel) \
								$DATA(bdy,$key,ap) \
								$DATA(bdy,$key,num_lines) \
								$DATA(bdy,$key,leg_type) \
								$DATA(bdy,$key,tax_type) \
								$DATA(bdy,$key,bet_type) \
								$DATA(bdy,$key,0,leg_sort) \
								$DATA(bdy,$key,0,part_no) \
								[encoding convertfrom utf-8 $DATA(bdy,$key,0,desc)] \
								$DATA(bdy,$key,0,price_type) \
								$DATA(bdy,$key,0,price) \
								$DATA(bdy,$key,0,hcap_value) \
								$DATA(bdy,$key,0,rule4) \
								$DATA(bdy,$key,stake) \
								$DATA(bdy,$key,returns) \
								$DATA(bdy,$key,num_lines_win) \
								$DATA(bdy,$key,num_lines_lose) \
								$DATA(bdy,$key,num_lines_void) \
								$DATA(bdy,$key,balance)

}



proc write_stmt_entry_HMANBET {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	foreach f {returns stake num_lines_win num_lines_lose num_lines_void} {
		if {![info exists DATA(bdy,$key,$f)]} {
			set DATA(bdy,$key,$f) ""
		}
	}

	write_comma_sep_values $f_id MANBET \
								$DATA(bdy,$key,cr_date) \
								$DATA(bdy,$key,receipt) \
								$DATA(bdy,$key,channel) \
								$DATA(bdy,$key,ap) \
								$DATA(bdy,$key,num_lines) \
								$DATA(bdy,$key,leg_type) \
								$DATA(bdy,$key,tax_type) \
								$DATA(bdy,$key,bet_type) \
								$DATA(bdy,$key,0,leg_sort) \
								$DATA(bdy,$key,0,part_no) \
								[encoding convertfrom utf-8 $DATA(bdy,$key,0,desc)] \
								$DATA(bdy,$key,0,price_type) \
								$DATA(bdy,$key,0,price) \
								$DATA(bdy,$key,0,hcap_value) \
								$DATA(bdy,$key,0,rule4) \
								$DATA(bdy,$key,stake) \
								$DATA(bdy,$key,returns) \
								$DATA(bdy,$key,num_lines_win) \
								$DATA(bdy,$key,num_lines_lose) \
								$DATA(bdy,$key,num_lines_void) \
								$DATA(bdy,$key,balance)

}



proc write_stmt_entry_BET {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	ob::log::write INFO {write_stmt_entry_BET: f_id=$f_id, key=$key}

	for {set i 0} {$i < $DATA(bdy,$key,nrows)} {incr i} {

		if {$i == 0} {

			foreach f {returns stake num_lines_win num_lines_lose num_lines_void token_value stake_per_line} {
				if {![info exists DATA(bdy,$key,$f)]} {
					ob::log::write INFO {write_stmt_entry_BET: $f not found, defaulting}
					set DATA(bdy,$key,$f) ""
				}
			}

			#
			# I am adding config option here so CSV files will be generated differently than admin screen payments.
			# i.e. "R4" will appear in CSV files, and amount in admin screens
			#

			if {![OT_CfgGet RULE_4_STATEMENTS_CSV 0]} {

				#They don't want to put the rule 4 stuff in the CSV file,
				#just the admin screen statements
				#Just checking the content

				if {$DATA(bdy,$key,$i,rule4) != ""} {
					set DATA(bdy,$key,$i,rule4) "R4"
				}
			}

			# Map the bet type to alternative names if required
			if {[OT_CfgGet STMT_MAP_BET_TYPE 0]} {
				set DATA(bdy,$key,bet_type)  \
					[string map [OT_CfgGet STMT_BET_TYPE_MAPPINGS] \
						$DATA(bdy,$key,bet_type)]
			}

			# Map the leg type to alternative names if required
			if {[OT_CfgGet STMT_MAP_LEG_TYPE 0]} {
				set DATA(bdy,$key,leg_type)  \
					[string map [OT_CfgGet STMT_LEG_TYPE_MAPPINGS] \
						$DATA(bdy,$key,leg_type)]
			}

			write_comma_sep_values $f_id BET \
										$DATA(bdy,$key,cr_date) \
										$DATA(bdy,$key,receipt) \
										$DATA(bdy,$key,channel) \
										$DATA(bdy,$key,ap) \
										$DATA(bdy,$key,num_lines) \
										$DATA(bdy,$key,leg_type) \
										$DATA(bdy,$key,tax_type) \
										$DATA(bdy,$key,bet_type) \
										$DATA(bdy,$key,$i,leg_sort) \
										$DATA(bdy,$key,$i,part_no) \
										$DATA(bdy,$key,$i,oc_name) \
										$DATA(bdy,$key,$i,ev_name) \
										$DATA(bdy,$key,$i,mkt_name) \
										$DATA(bdy,$key,$i,type_name) \
										$DATA(bdy,$key,$i,class_name) \
										$DATA(bdy,$key,$i,price_type) \
										$DATA(bdy,$key,$i,price) \
										$DATA(bdy,$key,$i,hcap_value) \
										$DATA(bdy,$key,$i,rule4) \
										$DATA(bdy,$key,stake) \
										$DATA(bdy,$key,returns) \
										$DATA(bdy,$key,num_lines_win) \
										$DATA(bdy,$key,num_lines_lose) \
										$DATA(bdy,$key,num_lines_void) \
										$DATA(bdy,$key,balance) \
										$DATA(bdy,$key,token_value) \
										$DATA(bdy,$key,stake_per_line)

		} else {
			write_comma_sep_values $f_id BETDETAIL \
										$DATA(bdy,$key,$i,leg_sort) \
										$DATA(bdy,$key,$i,part_no) \
										$DATA(bdy,$key,$i,oc_name) \
										$DATA(bdy,$key,$i,ev_name) \
										$DATA(bdy,$key,$i,mkt_name) \
										$DATA(bdy,$key,$i,type_name) \
										$DATA(bdy,$key,$i,class_name) \
										$DATA(bdy,$key,$i,price_type) \
										$DATA(bdy,$key,$i,price) \
										$DATA(bdy,$key,$i,hcap_value) \
										$DATA(bdy,$key,$i,rule4)
		}
	}
}

proc write_stmt_entry_XGSUB {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	foreach f {returns stake num_lines_win num_lines_lose num_lines_void token_value} {
		if {![info exists DATA(bdy,$key,$f)]} {
			set DATA(bdy,$key,$f) ""
		}
	}

	write_comma_sep_values $f_id XGSUB \
					$DATA(bdy,$key,cr_date) \
					$DATA(bdy,$key,receipt) \
					$DATA(bdy,$key,channel) \
					$DATA(bdy,$key,bet_type) \
					$DATA(bdy,$key,picks) \
					$DATA(bdy,$key,game_name) \
					$DATA(bdy,$key,draw_desc) \
					$DATA(bdy,$key,draw_time) \
					"" \
					$DATA(bdy,$key,num_subs) \
					$DATA(bdy,$key,subs_remaining) \
					$DATA(bdy,$key,total_winnings) \
					$DATA(bdy,$key,stake_per_bet) \
					$DATA(bdy,$key,stake) \
					$DATA(bdy,$key,balance) \
					$DATA(bdy,$key,token_value) \
					$DATA(bdy,$key,consec_draws)
}

proc write_stmt_entry_XGSTL {f_id key ARRAY} {

	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	foreach f {returns stake num_lines_win num_lines_lose num_lines_void token_value} {
		if {![info exists DATA(bdy,$key,$f)]} {
			set DATA(bdy,$key,$f) ""
		}
	}

	write_comma_sep_values $f_id XGSTL \
					$DATA(bdy,$key,cr_date) \
					$DATA(bdy,$key,receipt) \
					$DATA(bdy,$key,channel) \
					$DATA(bdy,$key,bet_type) \
					$DATA(bdy,$key,picks) \
					$DATA(bdy,$key,game_name) \
					$DATA(bdy,$key,draw_desc) \
					$DATA(bdy,$key,draw_time) \
					"" \
					$DATA(bdy,$key,stake) \
					$DATA(bdy,$key,results) \
					$DATA(bdy,$key,returns) \
					$DATA(bdy,$key,num_lines_win) \
					$DATA(bdy,$key,num_lines_lose) \
					$DATA(bdy,$key,num_lines_void) \
					$DATA(bdy,$key,balance) \
					$DATA(bdy,$key,token_value)
}

proc write_stmt_entry_HBET {f_id key ARRAY} {
	upvar 1 $ARRAY DATA

	# debug log call
	log_proc_call 20

	ob::log::write INFO {write_stmt_entry_HBET: f_id=$f_id, key=$key}

	for {set i 0} {$i < $DATA(bdy,$key,nrows)} {incr i} {

		if {$i == 0} {

			foreach f {returns stake num_lines_win num_lines_lose num_lines_void token_value stake_per_line} {
				if {![info exists DATA(bdy,$key,$f)]} {
					ob::log::write INFO {write_stmt_entry_HBET: $f not found, defaulting}
					set DATA(bdy,$key,$f) ""
				}
			}

			#
			# I am adding config option here so CSV files will be generated differently than admin screen payments.
			# i.e. "R4" will appear in CSV files, and amount in admin screens
			#

			if {![OT_CfgGet RULE_4_STATEMENTS_CSV 0]} {

				#They don't want to put the rule 4 stuff in the CSV file,
				#just the admin screen statements
				#Just checking the content

				if {$DATA(bdy,$key,$i,rule4) != ""} {
					set DATA(bdy,$key,$i,rule4) "R4"
				}
			}

			# Map the bet type to alternative names if required
			if {[OT_CfgGet STMT_MAP_BET_TYPE 0]} {
				set DATA(bdy,$key,bet_type)  \
					[string map [OT_CfgGet STMT_BET_TYPE_MAPPINGS] \
						$DATA(bdy,$key,bet_type)]
			}

			# Map the leg type to alternative names if required
			if {[OT_CfgGet STMT_MAP_LEG_TYPE 0]} {
				set DATA(bdy,$key,leg_type)  \
					[string map [OT_CfgGet STMT_LEG_TYPE_MAPPINGS] \
						$DATA(bdy,$key,leg_type)]
			}

			write_comma_sep_values $f_id HBET \
										$DATA(bdy,$key,cr_date) \
										$DATA(bdy,$key,receipt) \
										$DATA(bdy,$key,channel) \
										$DATA(bdy,$key,ap) \
										$DATA(bdy,$key,num_lines) \
										$DATA(bdy,$key,leg_type) \
										$DATA(bdy,$key,tax_type) \
										$DATA(bdy,$key,bet_type) \
										$DATA(bdy,$key,$i,leg_sort) \
										$DATA(bdy,$key,$i,part_no) \
										$DATA(bdy,$key,$i,oc_name) \
										$DATA(bdy,$key,$i,ev_name) \
										$DATA(bdy,$key,$i,mkt_name) \
										$DATA(bdy,$key,$i,type_name) \
										$DATA(bdy,$key,$i,class_name) \
										$DATA(bdy,$key,$i,price_type) \
										$DATA(bdy,$key,$i,price) \
										$DATA(bdy,$key,$i,hcap_value) \
										$DATA(bdy,$key,$i,rule4) \
										$DATA(bdy,$key,stake) \
                         				$DATA(bdy,$key,returns) \
										$DATA(bdy,$key,num_lines_win) \
										$DATA(bdy,$key,num_lines_lose) \
										$DATA(bdy,$key,num_lines_void) \
										$DATA(bdy,$key,balance) \
										$DATA(bdy,$key,token_value) \
										$DATA(bdy,$key,stake_per_line)

		} else {
			write_comma_sep_values $f_id BETDETAIL \
										$DATA(bdy,$key,$i,leg_sort) \
										$DATA(bdy,$key,$i,part_no) \
										$DATA(bdy,$key,$i,oc_name) \
										$DATA(bdy,$key,$i,ev_name) \
										$DATA(bdy,$key,$i,mkt_name) \
										$DATA(bdy,$key,$i,type_name) \
										$DATA(bdy,$key,$i,class_name) \
										$DATA(bdy,$key,$i,price_type) \
										$DATA(bdy,$key,$i,price) \
										$DATA(bdy,$key,$i,hcap_value) \
										$DATA(bdy,$key,$i,rule4)
		}
	}

}

##
## This translates positions for shanghai darts.
##
##################################
proc convert_position {position} {
##################################

	switch -- $position {
		"D" {
			set position "Double"
		}
		"S" {
			set position "Single"
		}
		"T" {
			set position "Triple"
		}
		"B" {
			set position "Bull"
		}
		"O" {
			set position "Outer"
		}

	}
	return $position
}


##
## XSlot
##
#####################################################
proc set_xslot_details {key ref_id ARRAY game_desc} {
#####################################################

	upvar 1 $ARRAY DATA

	set values [list]

	## get game details
	##
	if {[catch {set rs [tb_db::tb_exec_qry igf_xslot_history_stmt $ref_id]} msg]} {
		ob::log::write ERROR "Failed running query in get_casino_receipt id: $id j_op_type: $j_op_type: $msg"
		return ""
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR "Could not locate casino game"
		db_close $rs
		return ""

	}

	##
	## get reels for that game
	##
	if {[catch {set reel_rs [tb_db::tb_exec_qry igf_xslot_get_reels $ref_id]} msg]} {
		 ob::log::write ERROR "Failed to retrieve game details $id"
		 return
	}

	if {[db_get_nrows $reel_rs] == 0} {
		ob::log::write ERROR "Could not locate reels"
		db_close $reel_rs
	}


	set symbols [split [db_get_col $rs 0 symbols] "|"]
	set stop [split [db_get_col $rs 0 stop] "|"]
	set multiplier -

	for {set i 0} {$i < [llength $stop]} {incr i} {
		set reel [split [db_get_col $reel_rs $i reel] "|"]

		if {$i == 9 && $game_desc == "Trippel"} {
			set multiplier [lindex $symbols [lindex $reel [lindex $stop $i]]]
		} else {
			set value [lindex $symbols [lindex $reel [lindex $stop $i]]]

			if {$i != 9 && $game_desc != "Trippel"} {
				if {$i != [expr {[llength $stop] -1}]} {
					lappend values "$value,"
				} else {
					lappend values $value
				}
			} else {
				lappend values $value
			}
		}
	}

	db_close $rs
	db_close $reel_rs

	return [list $values $multiplier]

}



##
## GBet
##
###########################################################
proc set_gbet_detail {key ref_id acct_id ARRAY game_desc} {
###########################################################

	upvar 1 $ARRAY DATA

		if {[catch {set rs [tb_db::tb_exec_qry igf_gbet_details_stmt $ref_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve game details $ref_id: $msg"
			return ""
	}

	set nrows [db_get_nrows $rs]

	set selection ""
	set game_desc [db_get_col $rs game_desc]

	if {$nrows == 0} {
		ob::log::write ERROR "Could not find GBet game: $ref_id $acct_id"
		return ""
		}

	for {set i 0} {$i < $nrows} {incr i} {

		set bet_names [db_get_col $rs $i bet_name]

		if {$game_desc == "WheelSpinner"} {

			set bet_type [db_get_col $rs $i bet_type]
			set sub_bet_type [db_get_col $rs $i sub_bet_type]
			set seln [db_get_col $rs $i seln_1]

			# High/Low/Same bet type
			if {$bet_type == "H"} {

				if {$sub_bet_type == "HIGH"} {
					set bet_name [TB_XL "IGF_[string toupper $game_desc]_HIGHER $seln"]
				} elseif {$sub_bet_type == "LOW"} {
					set bet_name [TB_XL "IGF__LOWER $seln"]
				} else {
					set bet_name [TB_XL "IGF_X18WOF_SAME $seln"]
				}

			# Pick_1 bet type
			} elseif {$bet_type == "L"} {
				set bet_name [db_get_col $rs $i pick]
			# Anything left (same)
			} else {
				set bet_name "Same"
			}

		} else {
			###need to translate these numbers
			set bet_name [TB_XL "|IGF_[string toupper $game_desc]_[string toupper $bet_names]|"]
		}
		if {[expr $i+1] == $nrows} {
			set selection "$selection $bet_name"
		} else {
			if {$bet_name != ""} {
				set selection "$selection $bet_name,"
			}
		}
		}
	return $selection

	db_close $rs

}

###########################################
proc set_spectrum_desc {key ref_id ARRAY} {
###########################################

	upvar 1 $ARRAY DATA

		if {[catch {set rs [tb_db::tb_exec_qry igf_gbet_details_stmt $ref_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve game details $ref_id: $msg"
			return ""
	} else {
			set nrows [db_get_nrows $rs]

		if {$nrows != 1} {
			ob::log::write ERROR "Could not find Spectrum game: $ref_id $acct_id"
			return ""
			}

		set selected [db_get_col $rs 0 bet_name]
		set drawn [db_get_col $rs 0 drawn]

		set drawn_list [split $drawn "|"]
		set num_1 0
		set num_2 0
		set num_3 0

		foreach {drawn_number} $drawn_list {
			incr num_${drawn_number}
		}
		###need to translate these colours
		set colour_1 [TB_XL "|IGF_COLOURS_COLOUR_1|"]
		set colour_2 [TB_XL "|IGF_COLOURS_COLOUR_2|"]
		set colour_3 [TB_XL "|IGF_COLOURS_COLOUR_3|"]

		set drawn "${num_1} ${colour_1}, ${num_2} ${colour_2}, ${num_3} ${colour_3}"

		###need to translate
		set selected [TB_XL "|IGF_COLOURS_SELN_[string toupper $selected]|"]

		set desc [list $selected $drawn]

		}
	return $desc

	db_close $rs

}



##############################################################
proc set_keno_details_desc {key cg_game_id ARRAY game_class} {
##############################################################

	if {$game_class == "VKeno"} {
		set qry igf_vkeno_details_stmt
	} else {
		## for Keno & Bingo
		set qry igf_keno_details_stmt
	}

	if {[catch {set rs [tb_db::tb_exec_qry $qry $cg_game_id]} msg]} {
		OT_LogWrite 10 "Failed to retrieve game details $cg_game_id: $msg"
		return ""
	} else {

		if {[db_get_nrows $rs] != 1} {
			OT_LogWrite 10 "Could not find game: $cg_game_id"
			return ""
		}

		set selected [db_get_col $rs 0 selected]
		set drawn [db_get_col $rs 0 drawn]
		set matches [db_get_col $rs 0 matches]


		if {$game_class == "VKeno"} {

			set is_reverse [db_get_col $rs 0 is_reverse]

			if {$is_reverse == "Y"} {
				# Bismarck play
				set game_type [TB_XL "IGF_VKENO_BISMARCK"]
			} else {
				# Nelson play
				set game_type [TB_XL "IGF_VKENO_NELSON"]
			}

			set num_drawn [llength [split $drawn {,}]]
		}

		db_close $rs

		set selected_list [split $selected ","]
		set drawn_list [split $drawn ","]

		for {set i 0} {$i < [llength $drawn_list]} {incr i} {

			if {$i == [expr {[llength $drawn_list] - 1}]} {
				continue
			} else {
				set drawn_list [lreplace $drawn_list $i $i "[lindex $drawn_list $i], "]
			}

		}

		for {set i 0} {$i < [llength $selected_list]} {incr i} {

			if {$i == [expr {[llength $selected_list] - 1}]} {
				continue
			} else {
				set selected_list [lreplace $selected_list $i $i "[lindex $selected_list $i], "]
			}
		}

		set drawn [join $drawn_list ""]
		set selected [join $selected_list ""]

		if {$game_class == "VKeno"} {
			set results [list $game_type $num_drawn $selected $matches]
		} else {
			set results [list $selected $matches]
		}

		return $results

	}

}

################################################
proc set_desc_shanghaidarts {key ref_id ARRAY} {
################################################

	upvar 1 $ARRAY DATA

		if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_shanghai_darts_detail $ref_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve game details $ref_id: $msg"
			return ""
	}

	if {[db_get_nrows $rs] != 1} {
			ob::log::write ERROR "Could not find game: $DATA(bdy,$key,j_op_ref_id)"
			 	return ""
	}

	#The numbers on the dart board (1-20).
	set drawn [db_get_col $rs 0 drawn]

	#The positions on the dart board (Single(S), Double(D), Triple(T)).
	set positions [db_get_col $rs 0 positions]

	#The colours on the dart board (Single(S), Double(D), Triple(T)).
	set colours [db_get_col $rs 0 colours]

	regexp {^(\d+)\|(\d+)\|(\d+)$} $drawn match drawn_1 drawn_2 drawn_3
	regexp {^([SDTOB])\|([SDTOB])\|([SDTOB])$} $positions match position_1 position_2 position_3
	regexp {^(\w)\|(\w)\|(\w)$} $colours match colour_1 colour_2 colour_3

	set position_one ${position_1}
	set position_two ${position_2}
	set position_three ${position_3}

	OT_LogWrite 20 "have set the positions - calling convert_position"

	set position_one [convert_position $position_one]
	set position_two [convert_position $position_two]
	set position_three [convert_position $position_three]

	OT_LogWrite 20 "have converted the positions....."

	set dart_1 "$position_one ${drawn_1}"
	set dart_2 "$position_two ${drawn_2}"
	set dart_3 "$position_three ${drawn_3}"

	set drawn "$dart_1, $dart_2, $dart_3"

	db_close $rs

	return $drawn
}


#####################################################
proc build_hotshots_desc {key ref_id acct_id ARRAY} {
#####################################################


	upvar 1 $ARRAY DATA

	set drawn ""

	if {[catch {set results [tb_db::tb_exec_qry tb_stmt_hilox_detail $ref_id $acct_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve hotshots game $ref_id $acct_id: $msg"
			return $drawn
		}

	set nrows [db_get_nrows $results]

 	if {$nrows == 0} {
		ob::log::write ERROR "Could not find hotshots game: $ref_id $acct_id"
			return $drawn
		}

	# start a string here and append the "value" field to it at the end of every iteration
	# This string shall be returned and "Hotshots" stick on the front of it for the
	# final "description".

	for {set i 0} {$i < $nrows} {incr i} {

		set num_drawn [db_get_col $results $i selected] ;# this is the "value" column
			set colour_drawn [db_get_col $results $i attr]   ;#don't think we need this

		if {[expr $i+1] == $nrows} {
			set drawn "$drawn $num_drawn"
		} else {
			if {$num_drawn != ""} {
				set drawn "$drawn $num_drawn,"
			}
		}
	}

	db_close $results

	return $drawn

}

##################################################
proc build_bslot_desc {key ref_id acct_id ARRAY} {
##################################################

	upvar 1 $ARRAY DATA

	set desc ""

	if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_bslot_stop_detail $ref_id $acct_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve BSlot game $ref_id $acct_id: $msg"
			return $desc
		}

	set values [list]

	set nrows [db_get_nrows $rs]

 	if {$nrows == 0} {
		ob::log::write ERROR "Could not find BSlot game: $ref_id $acct_id"
			return $desc
		}

	set symbols [split [db_get_col $rs 0 symbols] "|"]
	set stop [split [db_get_col $rs 0 stop] "|"]
	set cg_id [db_get_col $rs 0 cg_id]
	set view_size [db_get_col $rs 0 view_size]
	set wlines [db_get_col $rs 0 sel_win_lines]
	set stake_per_line [db_get_col $rs 0 stake_per_line]
	set mplr_res [split [db_get_col $rs 0 mplr_result] "|"]


	if {$mplr_res == {}} {
		set feature_win	"-"
	} else {
		set mplr 0
		#go through mplr result and calculate the mplr
		for {set i 0} {$i < [llength $mplr_res]} {incr i} {
			set mplr [expr [lindex $mplr_res $i] + $mplr]
		}
		set feature_win [expr $stake_per_line * $mplr]
	}

	if {[catch {set rss [tb_db::tb_exec_qry tb_stmt_bslot_reel_detail $cg_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve IGF game $cg_game_id $acct_id: $msg"
		return $desc
	}


	#loop through the stop positions
	#each element in stop corresponds to an index
	#in the corresponding reel. the value of the reel
	#at this index is the index of the symbol in symbols
	set nreels [db_get_nrows $rss]

	for {set i 0} {$i < $nreels} {incr i} {
		set reel [split [db_get_col $rss $i reel] "|"]
		set current_idx [lindex $stop $i]
		set reel_length [llength $reel]

		#go through each element on the real up
		#to view_size-1

		for {set j 0} {$j < $view_size} {incr j} {

			if {$current_idx == $reel_length} {
				set current_idx 0
			}
			set value [lindex $symbols [lindex $reel $current_idx]]
			set current [incr current_idx]

			lappend values $value
		}
	}

	db_close $rs
	db_close $rss

	return $values
}



##################################################
proc build_bbank_desc {key ref_id acct_id ARRAY} {
##################################################

	upvar 1 $ARRAY DATA

	set desc ""

	if {[catch {set results [tb_db::tb_exec_qry tb_stmt_bbank_history $ref_id $acct_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve BBank game $ref_id $acct_id: $msg"
			return $desc
		}

	set nrows [db_get_nrows $results]

 	if {$nrows == 0} {
		ob::log::write ERROR "Could not find Digit game: $ref_id $acct_id"
			return $desc
		}

	for {set i 0} {$i < $nrows} {incr i} {

		set date [db_get_col $results $i date]

		set selected [db_get_col $results $i selected]
		if {$selected != ""} {
			set selected [TB_XL "|IGF_BBANK_[string toupper $selected]|"]
		}

		set drawn [db_get_col $results $i drawn]
		if {$drawn != ""} {
			set drawn [join [split $drawn "|"] ","]
		}

		set current_winnings [db_get_col $results $i current_winnings]

		set action [db_get_col $results $i action]
		set action_data [db_get_col $results $i action_data]
		set bonus [db_get_col $results $i bonus]
		set nudges [db_get_col $results $i nudges]
		set extra_life [db_get_col $results $i extra_life]

		#bet action simply does the first draw, so
		#returns and action don't make sense.
		if {$action == "Bet"} {
			set returns ""
			set action ""
		} else {
			set current_winnings [print_ccy $current_winnings]
		}

		#drawn doesn't make sense for collect action
		if {$action == "Collect"} {
			set drawn ""
		}

		if {$action != ""} {
			set action [TB_XL "|IGF_BBANK_[string toupper $action]|"]
		}

		if {$action_data != ""} {
			set action_data [TB_XL "|IGF_BBANK_[string toupper $action_data]|"]
		}

		if {$bonus == "F"} {
			set bonus [TB_XL "|IGF_BBANK_FREE_SPIN|"]
		} elseif {$bonus == "9"} {
			set bonus [TB_XL "|IGF_BBANK_NINE_OUT_OF_NINE|"]
		} elseif {$bonus == "N"} {
			set bonus [TB_XL "|IGF_BBANK_NUDGES|"]
		} elseif {$bonus == "E"} {
			set bonus [TB_XL "|IGF_BBANK_EXTRA_LIFE|"]
		} else {
			set bonus [TB_XL "|IGF_BBNK_NO_BONUS|"]
		}

		if {$extra_life == "H"} {
			set extra_life [TB_XL "|IGF_BBANK_HELD|"]
		} elseif {$extra_life == "U"} {
			set extra_life [TB_XL "|IGF_BBANK_USED|"]
			} else {
			set extra_life [TB_XL "|IGF_BBANK_NO_EXTRA_LIFE|"]
		}

		set desc "$desc Drawn:$drawn, Action:$action_data, Bonus:$bonus, Nudges:$nudges, Extra Life:$extra_life"

	}

	db_close $results

	return $desc

}


## Note ref_id is cg_game_id
##
##################################################
proc build_digit_desc {key ref_id acct_id ARRAY} {
##################################################

	upvar 1 $ARRAY DATA

	set desc ""

	if {[catch {set results [tb_db::tb_exec_qry tb_stmt_hilox_detail $ref_id $acct_id]} msg]} {
		ob::log::write ERROR "Failed to retrieve Digit game $ref_id $acct_id: $msg"
			return $desc
		}

	set nrows [db_get_nrows $results]

 	if {$nrows == 0} {
		ob::log::write ERROR "Could not find Digit game: $ref_id $acct_id"
			return $desc
		}

	for {set i 0} {$i < $nrows} {incr i} {

		set selected [db_get_col $results $i selected]

		if {$selected != ""} {
			set selected [TB_XL "|IGF_DIGIT_[string toupper $selected]|"]
		}


		set drawn [db_get_col $results $i num_drawn]

		if {$drawn != ""} {
			set drawn [TB_XL "|IGF_DIGIT_[string toupper $drawn]|"]
		}

		set attributes [db_get_col $results $i attr]

		if {$attributes != ""} {

			set attribute_strings ""
			foreach attribute [split $attributes "|"] {
				lappend attribute_strings [TB_XL "|IGF_DIGIT_[string toupper ${attribute}]|"]
			}
			set drawn "$drawn [join $attribute_strings {, }]"
		}

		set action [db_get_col $results $i action]


		## Bet action means the first card is being drawn, doesn't really make sense.
		if {$action == "bet"} {
			set action ""
		}

		## Collect action means that drawn doesn't make sense...
		if {$action == "collect"} {
			set drawn ""
		}

		if {$action != "" } {
			set action [TB_XL "|IGF_DIGIT_[string toupper $action]|"]
		}

		set desc "$desc $drawn $selected:$action"
	}

	db_close $results

	return $desc

}

######################################################
proc build_generator_desc {key ref_id acct_id ARRAY} {
######################################################

	upvar 1 $ARRAY DATA

	set desc ""

	if {[catch {set rs [tb_db::tb_exec_qry tb_stmt_get_hilohist_detail $ref_id $acct_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve triple chance game $ref_id $acct_id: $msg"
			return $desc
		}

	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		ob::log::write ERROR "Could not find generator game: $ref_id $acct_id"
			return $desc
	}


	for {set i 0} {$i < $nrows} {incr i} {

		set date [db_get_col $rs $i date]
		set action [db_get_col $rs $i action]
		set drawn [db_get_col $rs $i drawn]
		set win_index [db_get_col $rs $i win_index]
		set lose_index [db_get_col $rs $i lose_index]

		set selected ""
		set selected_list [join [list [split $win_index "|"] [split $lose_index "|"]] " "]
		set drawn_list [split $drawn "|"]

		if {$action == "High" || $action == "Low"} {

			if {$i == 0} {
				ob::log::write ERROR "No bet action was found for this generator game: $ref_id $acct_id"
				return
			}

			# Need to get the previous draw to determine which reels have been bet on
			set pdrawn [db_get_col $rs [expr $i - 1] drawn]
			set pdrawn_list [split $pdrawn "|"]
			set unsorted_selection [list]

			# Win index
			foreach x [split $win_index "|"] {
				if {[lindex $drawn_list $x]  > [lindex $pdrawn_list $x]} {
					# Gone higher
					lappend unsorted_selection [list [TB_XL "|IGF_GENERATOR_REEL|"] [expr $x + 1] "-" [TB_XL "|IGF_GENERATOR_HIGH|"]]
				} else {
					# Gone lower
					lappend unsorted_selection [list [TB_XL "|IGF_GENERATOR_REEL|"] [expr $x + 1] "-" [TB_XL "|IGF_GENERATOR_LOW|"]]
				}
			}

			# Lose index
			foreach x [split $lose_index "|"] {
				if {[lindex $drawn_list $x]  < [lindex $pdrawn_list $x]} {
					# Gone higher
					lappend unsorted_selection [list [TB_XL "|IGF_GENERATOR_REEL|"] [expr $x + 1] "-" [TB_XL "|IGF_GENERATOR_HIGH|"]]
				} else {
					# Gone lower
					lappend unsorted_selection [list [TB_XL "|IGF_GENERATOR_REEL|"] [expr $x + 1] "-" [TB_XL "|IGF_GENERATOR_LOW|"]]
				}
			}

			# Sort the unsorted list and join
			set selected [join [lsort $unsorted_selection] " "]
		}

		for {set j 0} {$j < [llength $drawn_list]} {incr j} {

			if {$j == [expr {[llength $drawn_list] - 1}]} {
				continue
			} else {
				set drawn_list [lreplace $drawn_list $j $j "[lindex $drawn_list $j], "]
			}

		}

		set drawn [join $drawn_list ""]

		#bet action simply does the first draw, so
		#returns and action don't make sense.
		if {$action == "Bet"} {
			set returns ""
		}

		if {$action == "Collect"} {
			set drawn ""
		}

		if {$action != "" && $action != "High" && $action != "Low"} {
			set action [TB_XL "|IGF_GENERATOR_[string toupper $action]|"]
		} elseif {$action == "High" || $action == "Low"} {
			set action [TB_XL "|IGF_GENERATOR_PLAY|"]
		}

		if {$selected != ""} {
			set desc "$desc Selected:$selected Drawn:$drawn Action:$action"
		} else {
			if {$drawn != ""} {
				set desc "$desc Drawn:$drawn"
			} else {
				set desc "$desc Action:$action"
			}
		}
	}

	db_close $rs

	return $desc

}



##########################################################
proc build_triple_chance_desc {key ref_id acct_id ARRAY} {
##########################################################

	upvar 1 $ARRAY DATA

	set picks ""

	if {[catch {set results [tb_db::tb_exec_qry tb_stmt_get_hilohist_detail $ref_id $acct_id]} msg]} {
			ob::log::write ERROR "Failed to retrieve triple chance game $ref_id $acct_id: $msg"
			return $picks
		}

	set nrows [db_get_nrows $results]

	if {$nrows == 0} {
		ob::log::write ERROR "Could not find triple chance game: $ref_id $acct_id"
			return $picks
	}

	for {set i 0} {$i < $nrows} {incr i} {

		set action [db_get_col $results $i action]
		set selected [db_get_col $results $i selected]

		if {$selected != ""} {
			## this refers to the reel selected, 0 - 2.
			## 1 - 3 makes more sense to player.

			incr selected
			set selected "$selected:"
		}

		#Bet action simply does the first draw, so
		#action don't make sense.

		if {$action == "Game" || $action == "Bet"} {
			set action ""
		} else {
			if {[expr $i+1] == $nrows } {
				set picks "$picks $selected$action"
			} else {
				set picks "$picks $selected$action,"
			}
		}
	}

	db_close $results

	return $picks

}

proc set_price_type {ARRAY} {

	upvar 1 $ARRAY DATA

	OT_LogWrite 5 ">>> set price type"

	set rs [tb_db::tb_exec_qry tb_stmt_get_prc_type $DATA(hdr,cust_id)]

	if {[db_get_nrows $rs] == 1} {
		set DATA(hdr,price_type) [db_get_col $rs 0 pref_cvalue]
	} else {
		set DATA(hdr,price_type) [OT_CfgGet DEFAULT_PRICE_TYPE ODDS]
	}

	db_close $rs
}

# HEAT 9850 - making proc in line with other apps
#
# ##################
# proc mk_ah_str v {
# ##################

# 	log_proc_call 20

# 	if {$v % 2 == 0} {
# 		return [expr {($v%4==0)?$v/4:$v/4.0}]
# 	}
# 	incr v -1
# 	lappend l [expr {($v%4==0)?$v/4:$v/4.0}]
# 	incr v 2
# 	lappend l [expr {($v%4==0)?$v/4:$v/4.0}]
# 	return [join [lsort -real -increasing $l] /]
# }

##################
proc mk_ah_str v {
##################
	set v [expr {int(($v>0)?($v+0.25):($v-0.25))}]
	if {$v % 2 == 0} {
		return [format %0.1f [expr {($v%4==0)?$v/4:$v/4.0}]]
	}
	incr v -1
	set h1 [expr {($v%4==0)?$v/4:$v/4.0}]
	incr v 2
	set h2 [expr {($v%4==0)?$v/4:$v/4.0}]

	if {$h1 >= 0.0 && $h2 >= 0.0} {
		return "[format %0.1f $h1]/[format %0.1f $h2]"
	} else {
		return "[format %0.1f $h2]/[format %0.1f $h1]"
	}

}

proc mk_price {n d prc_type} {

	variable SPECIAL_PRICE

	if {$n == "" || $d == ""} {
		return "-"
	}

	switch -- $prc_type {

		DECIMAL {

			if [info exists SPECIAL_PRICE($n/$d)] {
				return $SPECIAL_PRICE($n/$d)
			}

		   	return [format %0.2f [expr 1.0+(double($n)/$d)]]
		}

		ODDS -
		default {

			if {$n == $d} {
				return Evens

			} elseif {$d == 1000} {
				#
				# These odds were entered as a decimal, so we return them as a
				# decimal
				#
				return [format %0.2f [expr 1.0+(double($n)/$d)]]

			}
			set n [expr {int($n)}]
			set d [expr {int($d)}]
			return "$n/$d"
		}
	}
}

#
# This proc reads in the customer specific ps template file and then initialises
# the output file making it ready to populate with the statements data
#
# ARGS:
#
#    f_id = file id of output file
#
proc init_ps_output {f_id write_header} {

	# Open the customer specific statement tcl file
	set cust_stmt "[OT_CfgGet PS_TEMPLATE_DIR {.}][OT_CfgGet PS_TCL_FILE]"
	OT_LogWrite 3 "Sourcing customer stmt file from: $cust_stmt"

	if {[catch {source $cust_stmt} msg]} {
		OT_LogWrite 1 "Error sourcing $cust_stmt: $msg"
	}

	# Write the ps header to the output file
	if {$write_header} {
		puts $f_id [::cust_stmt::get_ps_header]
	}

}

#
# This proc is responsible for getting the formatted postscript client string
# (containing name, address etc.) from the customer specific statement code
# and writing it to the output file
#
proc write_ps_client_row {f_id ARRAY} {

	upvar 1 DATA $ARRAY

	set line [::cust_stmt::get_ps_CLIENT_row DATA]

	puts $f_id $line
}

#
# This proc is responsible for looping through a customers transactions and
# retrieving a formatted postscript string for each one from the customer
# specific statement code and writing the lines to the output file
#
proc write_ps_data_row {f_id ARRAY} {

	variable ROW_PROCS

	upvar 1 $ARRAY DATA

	# Loop through each transaction
	for {set i 0} {$i < $DATA(bdy,num_txns)} {incr i} {

		set row_type $DATA(bdy,$i,entry_type)

		if {[lsearch {"BET" "MANBET" "TXN" "XGSUB" "XGSTL" "HBET" "HMANBET"} \
				$row_type] == -1} {
			OT_LogWrite 2 "Unknown entry type $row_type"
			error "unknown entry type $row_type"
		}

		if {[lsearch $ROW_PROCS "get_ps_${row_type}_row"] == -1} {

			OT_LogWrite 2 "No PS row proc found for type: $row_type, using the\
							default proc"
			# Use the default ps row proc - this is just a fall back, if it
			# is being called then something is wrong!!! Most likely an
			# undefined row type has been found
			if {[catch {
				set line [::cust_stmt::get_ps_DEFAULT_row DATA $i]
			} msg]} {

				OT_LogWrite 3 "An error occured in\
					::cust_stmt::get_ps_DEFAULT_row: $msg"

			} else {

				# Write the line to the output file
				puts $f_id $line
			}

		} else {

			if {[catch {
				set line [cust_stmt::get_ps_${row_type}_row DATA $i]
			} msg]} {

				OT_LogWrite 3 "An error occured in\
					::cust_stmt::get_ps_${row_type}_row: $msg"

			} else {

				# Write the line to the output file
				puts $f_id $line
			}

			# If this is the last row of a customers statement then call the
			# get_ps_FINAL_row proc if it exists, to get a final row of data.
			# This could be "Amount due for settlement" etc.
			if {$i == [expr {$DATA(bdy,num_txns) - 1}] &&\
				[lsearch $ROW_PROCS "get_ps_FINAL_row"] != -1} {

				set line [cust_stmt::get_ps_FINAL_row]
				puts $f_id $line
			}
		}
	}
}

#
# initialise this file
#
init_tb_statement_build


# close namespace
}
