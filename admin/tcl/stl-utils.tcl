# ==============================================================
# $Id: stl-utils.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SETTLE {

variable STL_FCAST_VOID
variable STL_DISP_LEVEL
variable BCONTROL
variable FUNC_AUT

#
# Global configuration
#
set STL_FCAST_VOID [OT_CfgGet STL_FCAST_VOID VOID]
set STL_TCAST_VOID [OT_CfgGet STL_TCAST_VOID VOID]
set STL_DISP_LEVEL [OT_CfgGet STL_DISP_LEVEL 5]

set FUNC_AUTO_DH  [OT_CfgGet FUNC_AUTO_DH 0]


# HEDGING
# Hedged bets cannot be settled automatically, so find the hedging channels
# and don't retrieve those bets in the queries

# find out from site operator/channel tables what the hedging channel is
set sql {
	select
		c.channel_id
	from
		tChannel c,
		tChanGrpLink cgl
	where
		c.channel_id = cgl.channel_id and
		cgl.channel_grp = 'HEDG'
}

set stmt [inf_prep_sql $DB $sql]
set res  [inf_exec_stmt $stmt]

inf_close_stmt $stmt

set rows [db_get_nrows $res]

# there could be many hedging channels if there are multiple sites
# being run off the single app
if {$rows > 0} {
	# initialise list
	set hedge_channels {}

	# put all hedging channels in a list
	for {set i 0} {$i < $rows} {incr i 1} {
		lappend hedge_channels [db_get_col $res $i channel_id]
	}

	# form the where clause eg "not matches [Y]"
	set hedge_where "and b.source not matches '\[[join $hedge_channels {}]\]'"
} else {
	# no hedging channel
	set hedge_where {}
}


#
# ----------------------------------------------------------------------------
# Get control information
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_CONTROL,sql) {
	select
		ah_refund_pct,
		max_payout_parking
	from
		tControl
}


#
# ----------------------------------------------------------------------------
# Get bet type information
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_BET_TYPES,sql) {
	select
		bet_type,
		stl_sort,
		bet_name,
		bet_settlement,
		num_selns,
		num_bets_per_seln,
		num_lines,
		min_combi,
		max_combi,
		max_losers,
		is_perm
	from
		tBetType
}


#
# ----------------------------------------------------------------------------
# Get bet type information
# ----------------------------------------------------------------------------
#
set STL_QRY(CHK_CAN_SETTLE,sql) {
	execute procedure pChkCanSettle(
		p_obj_type = ?,
		p_obj_id = ?
	)
}


#
# ----------------------------------------------------------------------------
# Blockbuster check
# ----------------------------------------------------------------------------
#
set STL_QRY(CHK_BLOCKBUSTER,sql) {
	select
		bonus_percentage
	from
		tBetBlockBuster
	where
		bet_id = ?
}


#
# ----------------------------------------------------------------------------
# Market information - there are three chunks of market information: the
# master row from tEvMkt, and the Rule 4 dedcutions information (from
# tEvMktRule4 and the forecast/tricast dividend information from tDividend
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_MKT_INFO,sql) {
	select
		e.ev_class_id,
		e.ev_type_id,
		e.ev_id,
		e.desc event_name,
		e.start_time,
		e.sp_allbets_from,
		e.sp_allbets_to,
		g.name market_name,
		m.type,
		m.sort,
		m.ev_mkt_id,
		m.ew_avail,
		m.pl_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.ew_with_bet,
		m.hcap_value,
		m.hcap_makeup,
		NVL(m.hcap_steal,0.0) hcap_steal,
		m.result_conf,
		NVL(m.tax_rate, NVL(e.tax_rate, t.tax_rate)) tax_rate,
		m.subst_ev_oc_id_1,
		m.subst_ev_oc_id_2,
		m.subst_ev_oc_id_3,
		c.sort class_sort
	from
		tEvMkt m,
		tEvOcGrp g,
		tEv e,
		tEvType t,
		tEvClass c
	where
		m.ev_mkt_id    = ? and
		m.ev_oc_grp_id = g.ev_oc_grp_id and
		m.ev_id        = e.ev_id        and
		e.ev_type_id   = t.ev_type_id and
		t.ev_class_id  = c.ev_class_id
}

set STL_QRY(GET_MKT_EW,sql) {
	select
		ew_terms_id,
		ew_fac_num,
		ew_fac_den,
		ew_places
	from
		tEachWayTerms
	where
		ev_mkt_id = ?
}

set STL_QRY(GET_MKT_RULE4,sql) {
	select
	    ev_mkt_rule4_id,
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


set STL_QRY(GET_MKT_DIVIDEND,sql) {
	select
	    div_id,
		type,
		seln_1,
		seln_2,
		seln_3,
		dividend
	from
		tDividend
	where
		ev_mkt_id = ?
}

set STL_QRY(GET_MKT_SC_FS_INFO,sql) {
	select
		s.result
	from
		tEvOc s
	where
		s.ev_mkt_id   = ?   and
		s.fb_result   = 'N' and
		s.result_conf = 'Y'
}




#
# ----------------------------------------------------------------------------
# Get all the bets in a spread bet market which need settling.
# We order by account id so that we can settle all the bets on a per-customer
# basis in one transaction. This is required so we can return early settlement
# payments a la Chiffon.
# ----------------------------------------------------------------------------
#

set STL_QRY(GET_SPREAD_BETS,sql) {
	select
		spread_bet_id,
		acct_id
	from
		tSpreadBet
	where
		ev_mkt_id = ? and settled = 'N'
	order by
		acct_id
}

set STL_QRY(SETTLE_SPREAD_BET,sql) {
	execute procedure pSettleSpreadBet (
		p_spread_bet_id = ?
	)
}


#
# ----------------------------------------------------------------------
# Early settlements (money given to the punter when he's in a no-lose
# situation before settlement) can be regarded as loans which must be
# repaid out of his winnings
# ----------------------------------------------------------------------
#
set STL_QRY(REPAY_EARLY_SETTLE,sql) {
	execute procedure pReturnAdvance(
		p_acct_id = ?,
		p_ev_mkt_id = ?
	)
}


#
# ----------------------------------------------------------------------------
# Selection information - a lot of this stuff isn't needed for the
# calculations but is brought back so we can write meaninful logfiles
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_SELN_INFO,sql) {
	select
		e.ev_class_id,
		e.ev_type_id,
		s.ev_id,
		s.ev_mkt_id,
		s.ev_oc_id,
		s.desc,
		case
			when s.result_conf='Y' then s.result else '-'
		end result,
		NVL(s.place,999) place,
		s.lp_num,
		s.lp_den,
		s.sp_num,
		s.sp_den,
		s.fb_result,
		s.cs_home,
		s.cs_away,
		s.runner_num,
		NVL(e.suspend_at,e.start_time + NVL(e.late_bet_tol,0) UNITS SECOND ) AS suspend_at,
		e.late_bet_tol_op
	from
		tEvOc s,
		tEv e
	where
		s.ev_oc_id = ? and
		s.ev_id = e.ev_id
}

set STL_QRY(GET_BIR_SELN_INFO,sql) {
        select
            NVL(r.result, m.default_res) result
        from
        tMktBirIdx m,
        outer tMktBirIdxRes r
    where
        m.mkt_bir_idx = r.mkt_bir_idx
        and
            m.ev_mkt_id = ?
        and
            m.bir_index = ?
        and
            r.ev_oc_id = ?
        and
        m.result_conf = 'Y'
        order by 1
}

# ----------------------------------------------------------------------------
# Retrieve all dead heat reductions for a selection
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_SELN_DHEAT,sql) {
	select
		d.ev_oc_id,
		d.dh_type,
		d.dh_num,
		d.dh_den,
		NVL(d.ew_terms_id,0) as ew_terms_id
	from
		tDeadHeatRedn d
	where
		d.ev_oc_id = ?
}


#
# ----------------------------------------------------------------------------
# Retrieve list of selections for a given event
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_EVENT_MKTS,sql) {
	select
		'M' market_cat,
		ev_mkt_id market_id,
		type market_type,
		sort market_sort
	from
		tEvMkt
	where
		ev_id = ? and settled = 'N' and result_conf = 'Y'
}
if {[OT_CfgGet FUNC_INDEX_TRADE 0]} {
	append STL_QRY(GET_EVENT_MKTS,sql) {
		union all
		select
			'X' market_cat,
			f_mkt_id market_id,
			'' market_type,
			'' market_sort
		from
			tfMkt
		where ev_id = ? and settled = 'N' and result_conf = 'Y'

	}
}

set STL_QRY(GET_MKT_SELNS,sql) {
	select
		ev_oc_id,
		case
			when result_conf='Y' then result else '-'
		end result,
		decode(result,'W',1,'P',2,'V',3,'H',4,5) settle_order
	from
		tEvOc
	where
		ev_mkt_id = ?
	order by
		settle_order asc
}


#
# ----------------------------------------------------------------------------
# Retrieve a list of bets which are candidates for settlement
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_SELN_BETS,sql) [subst {
	select distinct
		o.bet_id
	from
		tOBet o,
		tBet  b,
		tBetType t
	where
		o.ev_oc_id = ? and
		o.bet_id   = b.bet_id and
		b.bet_type = t.bet_type and
		b.settled  in (?,?) and
		b.status   <> 'S' and
		b.bet_type <> 'MAN' and
		t.bet_settlement <> 'Manual'
		$hedge_where
}]

# ----------------------------------------------------------------------------
# Retrieve a list of bets which are candidates for settlement
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_BIR_BETS,sql) [subst {
	select distinct
		o.bet_id
	from
		tOBet o,
		tBet  b,
		tBetType t,
	    tEvOc s,
	    tMktBirIdx m
	where
        m.mkt_bir_idx = ? and
        m.ev_mkt_id = s.ev_mkt_id and
	    m.bir_index = o.bir_index and
		s.ev_oc_id = o.ev_oc_id and
		o.bet_id   = b.bet_id and
		b.bet_type = t.bet_type and
		b.settled  = 'N' and
		b.status   <> 'S' and
		b.bet_type <> 'MAN' and
		t.bet_settlement <> 'Manual'
		$hedge_where
}]

#
# ----------------------------------------------------------------------------
# Get historic selection live price
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_HIST_SELN_PRICE,sql) {
	select p_num, p_den
	from tEvOcPrice
	where price_id = (
		select max(price_id)
		from tEvOcPrice
		where ev_oc_id = ?
		and cr_date <= ?
	)
}


#
# ----------------------------------------------------------------------------
# Get "exotic" selection price
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_SELN_PRICE,sql) {
	execute procedure pGetEvOcPrice(
		p_ev_oc_id   = ?,
		p_price_type = ?,
		p_price_date = ?
	)
}


#
# ----------------------------------------------------------------------------
# Settle bet as a loser - this is a simple update as no accounts need
# modifying
# ----------------------------------------------------------------------------
#
set STL_QRY(BET_LOSE,sql) {
	update tBet set
		num_lines_lose = num_lines,
		num_lines_win  = 0,
		num_lines_void = 0,
		winnings       = 0,
		settled        = 'Y',
		settled_at     = CURRENT
	where
		bet_id = ? and settled = 'N'
}


#
# ----------------------------------------------------------------------------
# Check for opt-out of automatic dead heat reduction calculation
# ----------------------------------------------------------------------------
#
if {$FUNC_AUTO_DH} {

	set STL_QRY(CHK_MKT_AUTO_DH,sql) {
		select
			auto_dh_redn
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}

}

#
# ----------------------------------------------------------------------------
# Settlement for win/void bets - the procedure which is called makes
# all the necessary account postings and updates the bet
# ----------------------------------------------------------------------------
#

if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" } {
	set enable_freebets Y
} else {
	set enable_freebets N
}

if {[OT_CfgGet RETURN_FREEBETS_VOID "FALSE"] == "TRUE"} {
	set return_freebets_void Y
} else {
	set return_freebets_void N
}

if {[OT_CfgGet RETURN_FREEBETS_CANCEL "FALSE"] == "TRUE"} {
	set return_freebets_cancel Y
} else {
	set return_freebets_cancel N
}

# If the bet has been voided do we still want to trigger
# the activation of Freebet tokens (if tOffer.on_settle = 'Y')
if [OT_CfgGet FREEBETS_NO_TOKEN_ON_VOID 0] {
    set no_token_on_void Y
} else {
    set no_token_on_void N
}
set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

set STL_QRY(BET_WIN_REFUND,sql) [subst {
	execute procedure pSettleBet(
		p_adminuser        = ?,
		p_bet_id           = ?,
		p_num_lines_win    = ?,
		p_num_lines_lose   = ?,
		p_num_lines_void   = ?,
		p_winnings         = ?,
		p_tax              = ?,
		p_refund           = ?,
		p_settle_info      = ?,
		p_enable_parking   = ?,
		p_park_by_winnings = ?,
		p_lose_token_value = ?,
		p_man_bet_in_summary = ?,
		p_freebets_enabled = '$enable_freebets',
		p_return_freebet   = '$return_freebets_void',
		p_rtn_freebet_can  = '$return_freebets_cancel',
		p_no_token_on_void = '$no_token_on_void',
		p_r4_limit         = '$r4_limit')
}]

set STL_QRY(DEBUG,sql) {
	set debug file to '/tmp/debug-ml.log'
}

#
# ----------------------------------------------------------------------------
# Settlement for Asian Handicap bets
# ----------------------------------------------------------------------------
#
set STL_QRY(STL_AH_BET,sql) {
    execute procedure pSettleAHBet(
        p_adminuser      = ?,
        p_bet_id         = ?,
}


#
# ----------------------------------------------------------------------------
# Get bet information - two queries, one to get the master bet information
# from tBet, the other to get the leg information, from tOBet
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_BET_MASTER,sql) {
	select
		b.bet_id,
		-- Support ticket#41152: tCall.retro_date takes precedence over tBet.cr_date
		-- At this time of writing I see no use for the bet_date parameter here as it
		-- does not seem to be used later?
		NVL(c.retro_date,b.cr_date) cr_date,
		NVL(to_char(c.retro_date, "%Y%m%d%H%M%S"),to_char(b.cr_date, "%Y%m%d%H%M%S")) bet_date,
		b.bet_type,
		b.acct_id,
		b.stake,
		b.tax_type,
		b.tax,
		b.stake_per_line,
		b.max_payout,
		b.tax_rate,
		b.num_selns,
		b.num_legs,
		b.leg_type,
		b.num_lines,
		b.num_nocombi,
		b.receipt,
		b.source,
	    b.settled,
	    NVL(b.num_lines_void, 0) num_lines_void,
	    NVL(b.num_lines_lose, 0) num_lines_lose,
	    NVL(b.num_lines_win, 0) num_lines_win,
	    NVL(b.winnings,0) winnings,
	    NVL(b.refund,0) refund,
		a.ccy_code cust_ccy
	from
		tBet b,
		tAcct a,
		outer tCall c
	where
		a.acct_id = b.acct_id
	and
		b.bet_id = ?
	and
		b.call_id = c.call_id

}

set STL_QRY(GET_BET_DETAIL,sql) {
	select
		bet_id,
		no_combi,
		leg_no,
		part_no,
		leg_sort,
		ev_oc_id,
		o_num,
		o_den,
		price_type,
		ew_fac_num,
		ew_fac_den,
		ew_places,
		hcap_value,
		bir_index,
		banker,
		in_running
	from
		tOBet
	where
		bet_id = ?
	order by
		bet_id  asc,
		leg_no  asc,
		part_no asc
}


#
# ----------------------------------------------------------------------------
# Mark selections, markets and events as settled
# ----------------------------------------------------------------------------
#
set STL_QRY(SET_SETTLED,sql) {
	execute procedure pSetSettled(
		p_adminuser = ?,
		p_obj_type = ?,
		p_obj_id = ?,
		p_req_guid = ?
	)
}


#
# ----------------------------------------------------------------------------
# Get all the exchange rate history
# ----------------------------------------------------------------------------
#
set STL_QRY(GET_CCY_TABLE,sql) {
	select
		ccy_code,
		to_char(date_from, "%Y%m%d%H%M%S") date_from,
		exch_rate
	from
		tCCYHist
}

#
# ----------------------------------------------------------------------------
# Prepare a query - return a cached statement id if we have one
# ----------------------------------------------------------------------------
#
proc stl_qry_prepare qry {

	global DB

	variable STL_QRY

	if [info exists STL_QRY($qry,stmt)] {
		incr STL_QRY($qry,use_count)
		return $STL_QRY($qry,stmt)
	}
	set stmt [inf_prep_sql $DB $STL_QRY($qry,sql)]

	set STL_QRY($qry,stmt)      $stmt
	set STL_QRY($qry,prep_time) [clock seconds]
	set STL_QRY($qry,use_count) 1

	return $stmt
}


#
# ----------------------------------------------------------------------------
# Write a log file entry
# ----------------------------------------------------------------------------
#
proc log {level args} {

	variable STL_DISP_LEVEL

	OT_LogWrite $level [join $args " "]

	if {[OT_CfgGet LOG_BREAK_DISPLAY 0]} {

		if {$level <= $STL_DISP_LEVEL} {
			tpBufWrite [join $args "<br>"]
			tpBufWrite "<br>"
		}

	} else {

		if {$level <= $STL_DISP_LEVEL} {
			tpBufWrite [join $args " "]
			tpBufWrite "\n"
		}

	}
}


#
# ----------------------------------------------------------------------------
# Get exchange rate history
# ----------------------------------------------------------------------------
#
proc stl_get_exch_rates {} {
	variable exch_rate

	set stmt [stl_qry_prepare GET_CCY_TABLE]
	set res [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $res]

	for {set idx 0} {$idx < $nrows} {incr idx} {

		set ccy_code  [db_get_col $res $idx ccy_code]
		set date_from [db_get_col $res $idx date_from]
		set exch_rate [db_get_col $res $idx exch_rate]

		lappend ccys $ccy_code

		lappend exch_rate($ccy_code) $date_from

		set exch_rate($ccy_code,$date_from) $exch_rate
	}

	# Sort all our rates
	foreach ccy [lsort -ascii -unique $ccys] {
		set exch_rate($ccy) [lsort -real -decreasing $exch_rate($ccy)]
	}

	db_close $res
}

proc get_rate {ccy_code date} {
	variable exch_rate

	foreach ccy_date $exch_rate($ccy_code) {
		if {$date >= $ccy_date} {
			return $exch_rate($ccy_code,$ccy_date)
		}
	}

	error "get_rate: unable to get exchange rate ($ccy_code, $date)"
}

#
# ----------------------------------------------------------------------------
# Get overall control information
# ----------------------------------------------------------------------------
#
proc stl_get_control {} {

	variable BCONTROL

	set stmt [stl_qry_prepare GET_CONTROL]
	set res  [inf_exec_stmt $stmt]

	set BCONTROL(ah_refund_pct)       [db_get_col $res 0 ah_refund_pct]
	set BCONTROL(max_payout_parking)  [db_get_col $res 0 max_payout_parking]

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Get bet types
#
# Load the table of bet type descriptions - this provides some of the
# information which is needed by the settler for its various machinations
# ----------------------------------------------------------------------------
#
proc stl_get_bet_types {} {

	variable BTYPE

	set stmt [stl_qry_prepare GET_BET_TYPES]
	set res  [inf_exec_stmt $stmt]

	set n_rows [db_get_nrows $res]

	if {$n_rows <= 0} {
		error "failed to get bet type information"
	}

	for {set i 0} {$i < $n_rows} {incr i} {
		set type [string trim [db_get_col $res $i bet_type]]
		foreach n [db_get_colnames $res] v [db_get_row $res $i] {
			set n [string trim $n]
			set BTYPE($type,$n) [string trim $v]
		}
	}

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Get bet information. The retrieved information is put into BET,
# a global associative array. BET only holds details of one bet at a time,
# so this procedure wilfully destroys any information previously in BET
# ----------------------------------------------------------------------------
#
proc stl_get_bet_info {bet_id} {

	variable BET

	catch {unset BET}

	#
	# Get master information
	#
	set stmt [stl_qry_prepare GET_BET_MASTER]
	set res  [inf_exec_stmt $stmt $bet_id]

	if {[db_get_nrows $res] != 1} {
		error "failed to retrieve master information for bet $bet_id"
	}

	foreach n [db_get_colnames $res] v [db_get_row $res 0] {
		set BET($n) [string trim $v]
	}
	db_close $res

	#
	# Get detail lines
	#
	set stmt [stl_qry_prepare GET_BET_DETAIL]
	set res  [inf_exec_stmt $stmt $bet_id]

	if {[db_get_nrows $res] < 1} {
		error "failed to retrieve detail information for bet $bet_id"
	}

	set leg_no  0
	set BET(num_combi) 0
	set BET(num_bankers) 0

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

		set n_leg_no [db_get_col $res $i leg_no]
		set no_combi [db_get_col $res $i no_combi]
		set banker   [db_get_col $res $i banker]

		if {$n_leg_no != $leg_no} {
			if {$leg_no != 0} {
				set BET($leg_no,num_parts) $part_no
			}
			set leg_no $n_leg_no
		}

		set part_no [db_get_col $res $i part_no]

		if {$part_no == 1} {
			if {$no_combi == ""} {
				incr BET(num_combi)
			}
			if {$banker == "Y"} {
				incr BET(num_bankers)
			}
		}

		foreach n [db_get_colnames $res] v [db_get_row $res $i] {
			if {$n == "leg_sort" || $n == "no_combi" || $n == "banker" || $n == "in_running"} {
				set BET($n_leg_no,$n) [string trim $v]
			} else {
				set BET($n_leg_no,$part_no,$n) [string trim $v]
			}
			if {$n == "pool_id"} {
				if {![info exists BET(pools)]} {
					set BET(pools) $v
				} elseif {[lsearch $BET(pools) $v] == -1} {
					lappend BET(pools) $v
				}
			}
		}
	}

	set BET($leg_no,num_parts) $part_no

	if {$BET(num_legs) != $leg_no && $BET(leg_type) != "T"} {
		OT_LogWrite 1 "bet #$bet_id has incorrect number of legs: $BET(num_legs) but we just worked out $leg_no"
		error "bet #$bet_id has incorrect number of legs: $BET(num_legs) but we just worked out $leg_no"
	}

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Get market information
# ----------------------------------------------------------------------------
#
proc stl_get_mkt_info {ev_mkt_id} {

	variable MKT
	variable USE_RULE4
	variable USE_DIVIDENDS
	variable STL_LOG_ONLY

	if [info exists MKT($ev_mkt_id,ev_id)] {
		return
	}

	set stmt [stl_qry_prepare GET_MKT_INFO]
	set res  [inf_exec_stmt $stmt $ev_mkt_id]

	if {[db_get_nrows $res] != 1} {
		error "failed to retrieve information for market $ev_mkt_id"
	}

	foreach n [db_get_colnames $res] v [db_get_row $res 0] {
		set MKT($ev_mkt_id,$n) [string trim $v]
	}

	db_close $res

	#
	# Get all each way terms
	#
	set MKT($ev_mkt_id,EW) [list]

	set stmt [stl_qry_prepare GET_MKT_EW]
	set res  [inf_exec_stmt $stmt $ev_mkt_id $ev_mkt_id]

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

		foreach n [db_get_colnames $res] v [db_get_row $res $i] {
			set $n [string trim $v]
		}

		set ew_key "$ew_fac_num,$ew_fac_den,$ew_places"

		set MKT($ev_mkt_id,EW,$ew_key) $ew_terms_id
		lappend MKT($ev_mkt_id,EW) $ew_terms_id

	}

	db_close $res

	#
	# Get Rule 4 deductions information
	#
	if {$USE_RULE4} {
		set MKT($ev_mkt_id,RULE4)    [list]

		set stmt [stl_qry_prepare GET_MKT_RULE4]
		set res  [inf_exec_stmt $stmt $ev_mkt_id]

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

			set ev_mkt_rule4_id [db_get_col $res $i ev_mkt_rule4_id]
			set market          [db_get_col $res $i market]
			set time_from       [db_get_col $res $i time_from]
			set time_to         [db_get_col $res $i time_to]
			set deduction       [db_get_col $res $i deduction]

			lappend MKT($ev_mkt_id,RULE4)\
				[list $ev_mkt_rule4_id $market $time_from $time_to $deduction]
		}

		db_close $res
	}

	#
	# Now get FC/TC dividend information
	#
	if {$USE_DIVIDENDS} {
		set MKT($ev_mkt_id,DIV) [list]
		set MKT($ev_mkt_id,DIV,TYPES) [list]

		set stmt [stl_qry_prepare GET_MKT_DIVIDEND]
		set res  [inf_exec_stmt $stmt $ev_mkt_id]

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

			set type     [string trim [db_get_col $res $i type]]
			set seln_1   [db_get_col $res $i seln_1]
			set seln_2   [db_get_col $res $i seln_2]
			set seln_3   [db_get_col $res $i seln_3]
			set dividend [db_get_col $res $i dividend]

			lappend MKT($ev_mkt_id,DIV)\
				[list $type $seln_1 $seln_2 $seln_3 $dividend]

			lappend MKT($ev_mkt_id,DIV,TYPES) $type

			switch -- $type {
				TW -
				TP {
					set MKT($ev_mkt_id,DIV,$type,$seln_1) $dividend
				}
				FC {
					set MKT($ev_mkt_id,DIV,FC,$seln_1,$seln_2) $dividend
				        log 1 "Old FC: MKT($ev_mkt_id,DIV) => [list $type $seln_1 $seln_2 $seln_3 $dividend]"
				        log 1 "Old FC dividend: MKT($ev_mkt_id,DIV,FC,$seln_1,$seln_2) => $dividend"
				}
				TC {
					set MKT($ev_mkt_id,DIV,TC,$seln_1,$seln_2,$seln_3) $dividend
				}
				default {
					error "unexpected div type ($type): expected TW/TP/FC/TC"
				}
			}
		}

		db_close $res
	}

	#we can rerun settlement with 'alternative' results
	#to see what would happen if it were settled a different
	#way
	if {$STL_LOG_ONLY} {
		_res_override_value "M" $ev_mkt_id
	}
}


#
# ----------------------------------------------------------------------------
# Calculate the rule 4 deductions in a market
# ----------------------------------------------------------------------------
#
proc stl_get_rule4 {ev_mkt_id time which_market} {

	variable MKT

	stl_get_mkt_info $ev_mkt_id

	set deduction 0

	foreach r4 $MKT($ev_mkt_id,RULE4) {
		set id        [lindex $r4 0]
		set market    [lindex $r4 1]
		set time_from [lindex $r4 2]
		set time_to   [lindex $r4 3]
		set dedn      [lindex $r4 4]

		if {$market == $which_market} {
			if {$time >= $time_from && $time <= $time_to} {
				incr deduction $dedn
			}
		}
	}

    if {$deduction > [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]} {
		set deduction [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]
	}

	return $deduction
}

#
# ----------------------------------------------------------------------------
# Calculate the Dead heat reductions in a market
# ----------------------------------------------------------------------------
#
proc stl_get_deadheat {dh_type ev_oc_id {ew_terms_id 0}} {

	global DB

	variable DHEAT
	variable STL_LOG_ONLY

	set log_prefix "stl_get_deadheat"

	log 20 "$log_prefix: dh_type:$dh_type ev_oc_id:$ev_oc_id ew_terms_id:$ew_terms_id"

	set num 1
	set den 1

	# check for a valid place dead heat reduction
	set search_key "$dh_type,$ev_oc_id,$ew_terms_id"

	# check to see if we already retrieve the place dead heat
	# reductions for this selection and result and retrieve
	# them if not
	if {![info exists DHEAT($ev_oc_id,retrieved)]} {

		log 20 "$log_prefix: not retrieved. Loading"

		# retrieve dead heat information from tDeadHeatRedn
		set stmt  [stl_qry_prepare GET_SELN_DHEAT]
		set res   [inf_exec_stmt $stmt $ev_oc_id]
		set nrows [db_get_nrows $res]

		for {set r 0} {$r < $nrows} {incr r} {

			foreach n [db_get_colnames $res] v [db_get_row $res $r] {
				set $n [string trim $v]
			}

			# check for a valid place dead heat reduction
			set dh_key "$dh_type,$ev_oc_id,$ew_terms_id"

			set DHEAT($dh_key,dh_num) $dh_num
			set DHEAT($dh_key,dh_den) $dh_den

		}

		set DHEAT($ev_oc_id,retrieved) 1
		db_close $res

	}

	#we can rerun settlement with 'alternative' results
	#to see what would happen if it were settled a different way
	if {$STL_LOG_ONLY} {
		_res_override_value "O" $ev_oc_id
	}

	# set dead heat reduction if exists
	if {[info exists DHEAT($search_key,dh_num)] &&
	        $DHEAT($search_key,dh_num) != "" && $DHEAT($search_key,dh_den) != ""} {
		set num $DHEAT($search_key,dh_num)
		set den $DHEAT($search_key,dh_den)

	# can't find them - if we're using a place reduction associated with terms
	# see if we can use the main place reduction instead
	} elseif {$dh_type == "P" && $ew_terms_id != 0} {

		set search_key "$dh_type,$ev_oc_id,0"

		if {[info exists DHEAT($search_key,dh_num)]} {
			log 5 "$log_prefix: using main reductions instead of those linked to each way terms"
			set num $DHEAT($search_key,dh_num)
			set den $DHEAT($search_key,dh_den)
		}
	}

	if {$num == $den} {
		set num 1
		set den 1
	}

	return [list $num $den]

}

#
# ----------------------------------
# Do automatic dead heat reductions 
# ----------------------------------
#
proc stl_do_auto_calcs {ev_oc_id} {

	variable MKT
	variable SELN

	variable FUNC_AUTO_DH

	set ev_mkt_id  $SELN($ev_oc_id,ev_mkt_id)
	set log_prefix "selection #$ev_oc_id"

	if {[info exists MKT($ev_mkt_id,auto_calc)] ||\
	    [info exists SELN($ev_oc_id,auto_calc)]} {
		# automatic calculations have already been
		# done on the market level or have already
		# been done for this selection
		return
	}


	#
	# Auto Generation of Dead Heat Reductions
	#
	if {$FUNC_AUTO_DH && [stl_mkt_can_auto_dh $SELN($ev_oc_id,ev_mkt_id)]} {

		log 1 "$log_prefix: generating dead heat reductions"

		# attempt insertion of dead heat reductions
		# for all confirmed win/place results
		stl_do_seln_dh $ev_oc_id

	} else {
		log 1 "$log_prefix: opted out of dead heat reduction generation"
	}

	set SELN($ev_oc_id,auto_calc) 1

}

#
# ----------------------------------------------------------------------------
# Fill in dead heat reductions for any confirmed results for a selection
# ----------------------------------------------------------------------------
#
proc stl_do_seln_dh {ev_oc_id} {

	variable SELN
	variable FUNC_AUTO_DH

	if {!$FUNC_AUTO_DH} {return}

	ob::log::write DEBUG {==> stl_do_seln_dh $ev_oc_id}

	# check for confirmed official place/win result
	if {[string first $SELN($ev_oc_id,result) "WP"] > -1} {

		# attempt insert of dead heats for all results
		if {![ob_dh_redn::insert_auto "S" $ev_oc_id]} {
			error [ob_dh_redn::get_err]
		}

		return
	}
}

#
# ----------------------------------------------------------------------------
# Perform check to determine whether dead heat reductions should be
# generated
# ----------------------------------------------------------------------------
#
proc stl_mkt_can_auto_dh {ev_mkt_id} {

	variable MKT

	if {[info exists MKT($ev_mkt_id,auto_dh_redn)]} {
		return $MKT($ev_mkt_id,auto_dh_redn)
	}

	set stmt [stl_qry_prepare CHK_MKT_AUTO_DH]

	set rs [inf_exec_stmt $stmt $ev_mkt_id]
	if {[db_get_nrows $rs] != 1} {
		db_close $res
		error "failed to determine whether to generate reductions for #$ev_mkt_id"
	}

	set auto_dh_redn [db_get_col $rs 0 auto_dh_redn]

	db_close $rs

	set MKT($ev_mkt_id,auto_dh_redn) [expr {$auto_dh_redn == "Y"}]

	return $MKT($ev_mkt_id,auto_dh_redn)
}

#
# ----------------------------------------------------------------------------
# Calculate dividend for a forecast/tricast
# ----------------------------------------------------------------------------
#
proc stl_get_dividend {ev_mkt_id type s1 s2 {s3 ""}} {

	variable MKT
	variable USE_DIVIDENDS

	stl_get_mkt_info $ev_mkt_id

	if {$type == "FC"} {
		set key $ev_mkt_id,DIV,FC,$s1,$s2
	} elseif {$type == "TC"} {
		set key $ev_mkt_id,DIV,TC,$s1,$s2,$s3
	} else {
		error "expected FC or TC (got $type)"
	}

	if { $USE_DIVIDENDS && [lsearch $MKT($ev_mkt_id,DIV,TYPES) $type] == -1 } {
		# If we have actually tried to get the dividends for the market
		# but we did not find any, return NO_DIVS
		log 2 "stl_get_dividend: no dividend found - ev_mkt_id $ev_mkt_id, type $type"
		return NO_DIVS
	}

	if [info exists MKT($key)] {
		return $MKT($key)
	}
	return 0.0
}


#
# ----------------------------------------------------------------------------
# Get result of "No Goalscorer" selection in first scorer (FS) market
# ----------------------------------------------------------------------------
#
proc stl_get_mkt_sc_fs_info {ev_mkt_id} {

	variable MKT

	if {[info exists MKT($ev_mkt_id,have_sc_fs)]} {
		return $MKT($ev_mkt_id,sc_fs_none)
	}

	set stmt [stl_qry_prepare GET_MKT_SC_FS_INFO]
	set res  [inf_exec_stmt $stmt $ev_mkt_id]

	if {[db_get_nrows $res] == 1} {
		set MKT($ev_mkt_id,have_sc_fs) 1
		set MKT($ev_mkt_id,sc_fs_none) [db_get_col $res 0 result]
	} else {
		error "No confirmed 'no goalscorer' seln for FS/CS mkt #$ev_mkt_id"
	}
}


#
# ----------------------------------------------------------------------------
# Get relevant selection information
#
# ----------------------------------------------------------------------------
#
proc stl_get_seln_info {ev_oc_id} {

	variable SELN
	variable SELN_OVERRIDE
	variable STL_LOG_ONLY

	if [info exists SELN($ev_oc_id,ev_mkt_id)] {
		return
	}

	set stmt [stl_qry_prepare GET_SELN_INFO]

	set res [inf_exec_stmt $stmt $ev_oc_id]

	if {[db_get_nrows $res] != 1} {
		error "failed to retrieve information for selection $ev_oc_id"
	}

	foreach n [db_get_colnames $res] v [db_get_row $res 0] {
		set SELN($ev_oc_id,$n) $v
	}

	db_close $res
	
	# do any auto calculations (dead heat reductions, unnamed favs)
	stl_do_auto_calcs $ev_oc_id

	#we can rerun settlement with 'alternative results
	#to see what would happen if it were settled a different
	#way
	if {$STL_LOG_ONLY} {
		_res_override_value "O" $ev_oc_id
	}

	return
}



#
# ----------------------------------------------------------------------------
# Get selection price when the price is 'exotic'
# ----------------------------------------------------------------------------
#
proc stl_get_seln_price {ev_oc_id price_type cr_date} {

	set stmt [stl_qry_prepare GET_SELN_PRICE]

	set res [inf_exec_stmt $stmt $ev_oc_id $price_type $cr_date]

	if {[db_get_nrows $res] != 1} {
		error "failed to retrieve $price_type price for selection $ev_oc_id"
	}

	set o_num [db_get_coln $res 0 0]
	set o_den [db_get_coln $res 0 1]

	db_close $res

	return [list $o_num $o_den]
}


#
# ----------------------------------------------------------------------------
# Get relevant selection information
# ----------------------------------------------------------------------------
#
proc stl_get_bet_names {sort} {

	if {$sort == "LuckyX"} {
		return [list L15 L31 L63]
	}

	if {$sort == "ATC"} {
		return [list SS2 SS3 SS4 SS5 SS6 SS7 SS8 SS9 SS10 SS11 SS12 \
						 DS2 DS3 DS4 DS5 DS6 DS7 DS8 DS9 DS10 DS11 DS12 \
						 ROB FLG]

	}

	return [list]
}


################################################################
# Is the bet placed after the supend_at time. If the bet_tolerance
# setting is set and in state B/V then the leg will be voided.
################################################################
proc stl_is_after_bet_time_void { bet_id leg_no ev_oc_id } {

	variable BET
	variable SELN

	set in_running      $BET($leg_no,in_running)
	set suspend_at      $SELN($ev_oc_id,suspend_at)
	set late_bet_tol_op $SELN($ev_oc_id,late_bet_tol_op)
	set bet_date        $BET(cr_date)

	log 4 "late_bet_tol bet_id $bet_id leg_no= $leg_no bet_date $bet_date \
		suspend_at $suspend_at tol=$suspend_at ($late_bet_tol_op)"

	if { $in_running == "Y" || $suspend_at == "" } {
		return 0
	}

	if { ($bet_date > $suspend_at) && \
         ($late_bet_tol_op == "V" || $late_bet_tol_op == "B") } {
        log 4 "late_bet_tol - bet placed after suspend_at and op =\
        	$late_bet_tol_op RET=1 (void leg)"
		return 1
	} else {
		log 4 "late_bet_tol - bet not placed after suspend_at or op not B/V. \
			op = $late_bet_tol_op RET=0"
		return 0
	}

}



# When a customer's winnings exceed max payout, this proc is used to send an email
# to the appropriate admin user list to inform them that the user's bet has been parked
# and needs manual settlement
proc send_max_payout_notification {acct_id bet_id} {

	global DB

	log 1 "Queueing MAX_PAYOUT_NOTIFY email for acct ID $acct_id, bet ID $bet_id"

	# get basic customer and bet details
	set sql {
		select
			r.fname,
			r.lname,
			c.acct_no,
			c.username,
			a.ccy_code as ccy,
			b.stake,
			b.stake_per_line,
			b.max_payout,
			b.potential_payout,
			b.cr_date,
			b.leg_type,
			b.receipt,
			t.bet_name
		from
			tAcct a,
			tCustomer c,
			tCustomerReg r,
			tBet b,
			tBetType t
		where
			    a.acct_id  = ?
			and c.cust_id  = a.cust_id
			and r.cust_id  = a.cust_id
			and b.bet_id   = ?
			and b.bet_type = t.bet_type

	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $acct_id $bet_id]

	# grab all those variables
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		foreach c [db_get_colnames $res] {
			set $c [db_get_col $res $i $c]
		}
	}

	inf_close_stmt $stmt
	db_close $res

	# get selection details
	set sql {
		select
			o.desc as oc_name,
			m.name as mkt_name,
			e.desc as ev_name,
			ob.o_num,
			ob.o_den,
			o.result
		from
			tOBet ob,
			tEvOc o,
			tEvMkt m,
			tEv e
		where
			    ob.bet_id    = ?
			and ob.ev_oc_id  = o.ev_oc_id
			and o.ev_mkt_id  = m.ev_mkt_id
			and m.ev_id      = e.ev_id

	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bet_id]

	# build the selection string
	set selections ""
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		foreach c [db_get_colnames $res] {
			set $c [db_get_col $res $i $c]
		}
		append selections "$oc_name \\t $mkt_name \\t $ev_name \\t $o_num/$o_den \\t $result\\n"
	}

	inf_close_stmt $stmt
	db_close $res

	# build the email content
	set reason "$fname $lname \\t $acct_no \\t $username \\n\\n"
	append reason "$receipt\\n"
	append reason "Winnings: $ccy $potential_payout\\n"
	append reason "Maximum Payout: $ccy $max_payout\\n\\n"
	append reason "$stake_per_line $leg_type $bet_name \\t $cr_date \\t Stakes $stake \\n\\n"
	append reason "$selections"

	# the reason field in the DB is capped at 255 chars, so for messages with a lot of selections it is understood
	# that the message will be capped. however we need to ensure the final character is not going to be a backslash,
	# otherwise we'll cause problems when the string is being passed around.
	set reason [string range $reason 0 244]
	if {[string index $reason end] == "\\"} {
		set reason [string range $reason 0 end-1]
	}

	set sql [subst {
		execute procedure pInsEmailQueue
		(
			p_email_type = "MAX_PAYOUT_NOTIFY",
			p_reason     = "$reason"
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt
	db_close $res

}


}
