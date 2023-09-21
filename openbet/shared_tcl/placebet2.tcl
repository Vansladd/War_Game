# $Id: placebet2.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#---------------------------------------------------------------------------
# Functions to facilitate the placing of bets of all types
#---------------------------------------------------------------------------

if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {
	package require fbets_fbets
	ob_fbets::init
}

set BET_TYPE(loaded)    0
set BET_TYPE(bet_types) [list]

namespace eval OB_placebet {

	namespace export init_placebet

	namespace export pb_start
	namespace export mult_get_selns
	namespace export mult_add_selns
	namespace export build_available_bets
	namespace export place_bet
	namespace export pb_end
	namespace export pb_abort
	namespace export MSEL
	namespace export PB_AFF_ID
	namespace export pb_set_sc_price_func
	namespace export get_bet_map
	namespace export validate_scorecast(tm)_leg
	namespace export pb_err
	namespace export get_user_data
	namespace export check_overrides

	variable pb_qrys_prepared
	variable pb_real

	variable VAL_OPS
	variable LEG_SORTS
	variable LEG_TYPES_TXT
	variable LEG_SORTS_TXT
	variable DIVS
	variable MAX_SELNS
	variable BP_MESSAGE
	variable BP_MESSAGES
	variable PC_BET_DELAY
	variable GLOB
	variable sc_price_func
	variable do_funds_chk
	variable MONITOR_MSG
	variable CFG

	set sc_price_func  default_sc_price_func

	array set LEG_SORTS_TXT [list "" ""\
								 -- ""\
								 SF "Forecast" \
								 RF "Reverse Forecast" \
								 CF "Combination Forecast"\
								 TC "Tricast"\
								 CT "Combination Tricast"\
								 SC "Scorecast"\
								 AH "Asian Handicap"\
								 A2 "1st Half Asian Handicap"\
								 WH "Western Handicap"\
								 MH "Western Handicap with Line"\
								 HL "Higher Lower"\
								 hl "Higher Lower (split)"\
								 OU "Over Under" \
								 CW "Next Scorer"]

	array set LEG_TYPES_TXT [list W "To Win" E "Each-way" P "to be placed"]
	set pb_qrys_prepared    0
	set pb_real             0
	set do_funds_chk        1

	set VAL_OPS(loaded)     0

	set LEG_SORTS   {-- SF RF CF TC CT SC}
	set DIVS        {SF CF RF TC CT}
	set MAX_SELNS   20

	set BP_MESSAGES  [list]
	set BP_MESSAGE   [list]
	set PC_BET_DELAY [OT_CfgGet CUM_STAKES_DELAY [expr {24 * 60 * 60}]]

	set log_name "default"

	OT_LogWrite 1 "log name is set to $log_name"
	if {[OT_CfgGet PB_LOG_FILE ""] != ""} {
		set file     [OT_CfgGet LOG_DIR ""]
		lappend file [OT_CfgGet PB_LOG_FILE]

		set file [join $file "/"]
		if {[catch {set log_name [OT_LogOpen -mode append -level 100 $file]} msg]} {
			OT_LogWrite 1 "failed to open log file: $msg"
		}

	}

	# Receipt formatting options
	set CFG(bet_receipt_format) [OT_CfgGet BET_RECEIPT_FORMAT 0]
	set CFG(bet_receipt_tag)    [OT_CfgGet BET_RECEIPT_TAG   ""]

	OT_LogWrite 1 "log name is set to $log_name"

}


# ----------------------------------------------------------------------
# placebet logging function
# ----------------------------------------------------------------------

proc OB_placebet::log {level msg} {
	variable log_name
	OT_LogWrite $log_name $level "PB: $msg"
}

# ----------------------------------------------------------------------
# Collect data for freebet package
# This proc populates information for the FBDATA array used by the
# freebet package. The FBDATA array is available whether you come from
# the bet packages or placebet2.tcl
# ----------------------------------------------------------------------
proc OB_placebet::_prepare_fb_data { evocs sk bet_num } {

	global FBDATA CUST BSEL
	variable MSEL

	set prices             [list]
	set ew_terms           [list]
	set ah_value           [list]

	# Set global bet values
	set FBDATA(bet_ids)            $evocs

	set FBDATA(stake)              $BSEL($sk,bets,$bet_num,stake)
	set FBDATA(leg_type)           $BSEL($sk,bets,$bet_num,leg_type)
	set FBDATA(bet_type)           $BSEL($sk,bets,$bet_num,bet_type)

	set ew_terms [list]
	set ah_value [list]

	# Work out any ew term / asian handicap
	for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {
		for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {
		# Is this one of the selections we are interested in ?
		if  { [lsearch -exact $evocs $BSEL($sk,$l,$p,ev_oc_id)] >=0 } {
			# Populate data structures
			lappend ew_terms [list $BSEL($sk,$l,$p,ew_fac_num) \
			                       $BSEL($sk,$l,$p,ew_fac_den)]
			lappend ah_value [list $BSEL($sk,$l,$p,hcap_value)]

			}
		}
	}


	foreach seln $evocs {
		set FBDATA($seln,ev_mkt_id)    $MSEL($seln,ev_mkt_id)
		set FBDATA($seln,ev_id)        $MSEL($seln,ev_id)
		set FBDATA($seln,ev_type_id)   $MSEL($seln,ev_type_id)
		set FBDATA($seln,ev_class_id)  $MSEL($seln,ev_class_id)
		set FBDATA($seln,seln_class)   $MSEL($seln,class_name)

		# Do we have prices? (not complex leg, price type not S). If so populate
		# relevant data structures

		# SP and GP do not matter, it has to be LP for a min price check

		if { [lsearch -exact {AH MH WH OU hl HL --} $BSEL(ids,$seln,leg_sort)] >= 0 \
		      && $BSEL(ids,$seln,price_type) == "L" } {
			set FBDATA($seln,lp_num)       $BSEL(ids,$seln,lp_num)
			set FBDATA($seln,lp_den)       $BSEL(ids,$seln,lp_den)
			lappend prices [list $FBDATA($seln,lp_num) $FBDATA($seln,lp_den)]
		}

		set FBDATA($seln,price_type)   $BSEL(ids,$seln,price_type)
		set FBDATA($seln,leg_sort)     $BSEL(ids,$seln,leg_sort)

		ob_log::write INFO {OB_placebet::_prepare_fb_data - ev_oc_id    = $seln}
		ob_log::write INFO {                              - ev_mkt_ids  = $FBDATA($seln,ev_mkt_id)}
		ob_log::write INFO {                              - ev_id       = $FBDATA($seln,ev_id) }
		ob_log::write INFO {                              - ev_type_id  = $FBDATA($seln,ev_type_id)}
		ob_log::write INFO {                              - ev_class_id = $FBDATA($seln,ev_class_id)}
	}

	# Only calculate potential payout if the bet is not a single and we have prices set up for all the selections
	# in the bet
	if { ([llength $prices] ==  [llength $evocs]) && $FBDATA(bet_type) != "SGL"} {
		set FBDATA(potential_payout)   [could_win $FBDATA(bet_type) $FBDATA(stake) $FBDATA(leg_type) $prices $ew_terms $ah_value]
	}

}

#---------------------------------------------------------------------------
# prepare the queries required by bet placement
#---------------------------------------------------------------------------

proc OB_placebet::placebet_prepare_queries args {

	variable PC_BET_DELAY
	variable pb_qrys_prepared

	if {$pb_qrys_prepared == 1} {
		return
	}

	db_store_qry pb_control {
		select
		bets_allowed
		from tcontrol
	} 15

	db_store_qry pb_bet_type_qry {
		SELECT
		bet_type,
		bet_name,
		bet_settlement,
		num_selns,
		num_lines,
		num_bets_per_seln,
		min_combi,
		max_combi,
		min_bet,
		max_bet,
		blurb

		FROM
		tBetType

		WHERE
		status = 'A' and
		channels like ?
	} 600

	## in applications which are not BIR aware we dont want to ignore start time/is off
	## just in case someting goes wrong in the app and we get this far
	if {[OT_CfgGet PB_ALLOW_BIR 0]} {
		set bir_term "m.bet_in_run"
	} else {
		set bir_term "'N'"
	}

	db_store_qry pb_selns_qry [subst {
		select
		c.ev_class_id,
		c.sort as  ev_class_sort,
		t.ev_type_id,
		t.name as ev_type,
		t.max_payout,
		t.fc_max_payout fc_max_pay,
		t.tc_max_payout tc_max_pay,
		NVL(m.tax_rate, NVL(e.tax_rate, t.tax_rate)) tax_rate,
		e.ev_id,
		e.start_time ev_start_time,
		NVL(NVL(NVL(s.min_bet,m.min_bet), e.min_bet), t.ev_min_bet) stk_min,
		NVL(NVL(NVL(s.max_bet,m.max_bet), e.max_bet), t.ev_max_bet) max_win_lp,
		NVL(NVL(NVL(s.sp_max_bet,m.sp_max_bet), e.sp_max_bet), t.sp_max_bet) max_win_sp,
		NVL(NVL(s.ep_max_bet, g.ep_max_bet), t.ep_max_bet) max_win_ep,
		NVL(NVL(s.max_place_lp,e.max_place_lp),t.ev_max_place_lp) max_place_lp,
		NVL(NVL(s.max_place_sp,e.max_place_sp),t.ev_max_place_sp) max_place_sp,
		NVL(NVL(s.max_place_ep,g.oc_max_place_ep), t.ev_max_place_ep) max_place_ep,
		NVL(s.fc_stk_limit,t.fc_max_bet) fc_max_bet,
		NVL(s.tc_stk_limit,t.tc_max_bet) tc_max_bet,
		NVL(NVL(NVL(s.max_multiple_bet, m.max_multiple_bet), e.max_multiple_bet), t.max_multiple_bet) max_mult_bet,
		e.sort ev_sort,
		m.ev_oc_grp_id,
		m.ev_mkt_id,
		m.type mkt_type,
		m.sort mkt_sort,
		m.ew_avail,
		m.pl_avail,
		m.ew_fac_num,
		m.ew_fac_den,
		m.ew_places,
		m.ew_with_bet,
		m.fc_avail,
		m.tc_avail,
		m.pm_avail,
		m.lp_avail,
		m.sp_avail,
		m.gp_avail,
		m.ep_active,
		NVL(s.acc_min, m.acc_min) acc_min,
		m.acc_max,
		m.hcap_value,
		m.hcap_precision,
		m.bir_index,
		NVL(m.bir_delay, NVL(e.bir_delay, NVL(t.bir_delay, NVL(c.bir_delay, NVL(ct.bir_delay, 0))))) as bir_delay,
		NVL(m.hcap_steal,0) as hcap_steal,
		m.xmul,
		m.is_ap_mkt,
		m.bet_in_run,
		decode(c.status||t.status||e.status||m.status||s.status,
			   'AAAAA', 'A', 'S') status,

		case
		when ((e.suspend_at is null
			   or e.suspend_at >=
			   extend(current, year to second)
			  )
			  and
			  ($bir_term = 'Y' or
			   ((e.is_off = '-' and e.start_time > extend(current, year to second)) or
				(e.is_off = 'N'))
			  )
			 )
		then 'N'
		else 'Y'
		end as started,
		case
		when ($bir_term = 'Y' and (e.is_off = 'Y' or (e.is_off = '-' and e.start_time < extend(current, year to second))))
		then 'Y'
		else 'N'
		end as bir_started,
		s.ev_oc_id,
		s.lp_num,
		s.lp_den,
		NVL(NVL(s.sp_num_guide,s.lp_num),5) sp_num_guide,
		NVL(NVL(s.sp_den_guide,s.lp_den),2) sp_den_guide,
		s.mult_key,
		e.mult_key ev_mult_key,
		s.fb_result,
		s.cs_home,
		s.cs_away,
		c.category   category,
		c.name       class_name,
		t.name       type_name,
		e.desc       ev_name,
		e.venue      ev_venue,
		e.country    ev_country,
		e.start_time ev_time,
		e.late_bet_tol_op,
		m.name       mkt_name,
		s.has_oc_variants,
		case when c.sort in ('[join [OT_CfgGet PLACEBET2_SHOW_RUNNER_NUM_SORTS [list]] {', '}]') and s.runner_num is not null then s.runner_num||'. '||s.desc else
			s.desc     end  oc_name,
		s.risk_info,
		extend(current,year to second) as current_time,
		NVL(NVL(NVL(NVL(s.max_pot_win,m.max_pot_win), e.max_pot_win), t.ev_max_pot_win),0) max_pot_win,
		NVL(NVL(NVL(NVL(s.ew_factor,m.ew_factor), e.ew_factor), t.ev_ew_factor),1) ew_factor
		FROM
		tEvOc s,
		tEvMkt m,
		tEvOcGrp g,
		tEv e,
		tEvType t,
		tEvClass c,
		tEvCategory ct

		WHERE
		s.ev_oc_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
		s.ev_mkt_id = m.ev_mkt_id and
		m.ev_oc_grp_id = g.ev_oc_grp_id and
		m.ev_id = e.ev_id and
		e.ev_type_id = t.ev_type_id and
		t.ev_class_id = c.ev_class_id and
		ct.category = c.category
	}]

	db_store_qry pb_get_dynamic_stake_factors {
		select
			'CATEGORY' as level,
			s.ev_oc_id,
			e.start_time,
			sfp1.mins_before_from,
			sfp1.mins_before_to,
			sfp1.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvClass c,
			tEvCategory y,
			tStkFacPrfLink sfl1,
			tStkFacPrfPeriod sfp1
		where
			s.ev_id = e.ev_id and
			e.ev_class_id = c.ev_class_id and
			c.category = y.category and
			y.ev_category_id = sfl1.id and
			sfl1.sf_prf_id = sfp1.sf_prf_id and
			sfl1.level = 'CATEGORY' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'CLASS' as level,
			s.ev_oc_id,
			e.start_time,
			sfp2.mins_before_from,
			sfp2.mins_before_to,
			sfp2.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl2,
			tStkFacPrfPeriod sfp2
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			c.ev_class_id = sfl2.id and
			sfl2.sf_prf_id = sfp2.sf_prf_id and
			sfl2.level = 'CLASS' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'TYPE' as level,
			s.ev_oc_id,
			e.start_time,
			sfp3.mins_before_from,
			sfp3.mins_before_to,
			sfp3.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl3,
			tStkFacPrfPeriod sfp3
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			t.ev_type_id = sfl3.id and
			sfl3.sf_prf_id = sfp3.sf_prf_id and
			sfl3.level = 'TYPE' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		union
		select
			'EVENT' as level,
			s.ev_oc_id,
			e.start_time,
			sfp4.mins_before_from,
			sfp4.mins_before_to,
			sfp4.stake_factor
		from
			tEvOc s,
			tEv e,
			tEvType t,
			tEvClass c,
			tStkFacPrfLink sfl4,
			tStkFacPrfPeriod sfp4
		where
			s.ev_id = e.ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			e.ev_id = sfl4.id and
			sfl4.sf_prf_id = sfp4.sf_prf_id and
			sfl4.level = 'EVENT' and
			s.ev_oc_id in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		order by
			2,1,4 asc
	} 300

	#we can cache this query as it is only used to determine whether or not
	#a liability has been set on a particular outcome, the actual values are
	#read after the table has been updated later on
	db_store_qry pb_is_liab_set {
		select
		  NVL(mc.liab_limit,-1.0) mkt_liab_limit,
		  mc.apc_status,
		  sc.stk_or_lbt,
		  NVL(sc.max_total,-1.0) seln_max_limit
		from
		  tEvOcConstr sc,
		  tEvMktConstr mc
		where
		  sc.ev_mkt_id = mc.ev_mkt_id and
		  sc.ev_oc_id = ?
	} 20

	db_store_qry pb_punter_prev_stakes {
		select
			sum(b.stake)
		from
			tExtCust e1,
			tExtCust e2,
			tAcct a,
			tBet b,
			tOBet ob,
			tEvOc oc
		where
				e1.ext_cust_id = e2.ext_cust_id
			and e2.cust_id     = a.cust_id
			and oc.ev_oc_id    = ob.ev_oc_id
			and ob.bet_id      = b.bet_id
			and b.acct_id      = a.acct_id
			and e1.cust_id     != e2.cust_id
			and e1.cust_id     = ?
			and oc.ev_oc_id    = ?
	}

	db_store_qry pb_cust_lk  {
		update tcustomer set

		bet_count = bet_count

		where
		cust_id = ?
	}

	db_store_qry pb_check_panic_mode {
		select
			c.repl_check_mode,
			c.repl_max_wait,
			c.repl_max_lag,
			s.last_msg_time,
			s.last_ping_time,
			s.current_lag,
			s.last_msg_id,
			s.head_msg_id
		from
			tControl c,
			tOXiRepClientSess s
		where
			s.name = ?
	}


	#Bit gratuitous storing this as one of two queries for just a couple
	#of columns but don't see why _normal_ customers should suffer another
	#join into an unneeded table for information they don't use
	if {[OT_CfgGet EXTRA_BETTING_TICKER_DATA 0]} {

		db_store_qry pb_cust_info {
			select
			  c.username,
			  c.acct_no,
			  c.last_bet,
			  c.receipt_counter,
			  c.max_stake_scale,
			  c.bet_count,
			  c.elite,
			  c.country_code,
			  c.lang,
			  c.notifyable,
			  gv.group_value as code,
			  a.owner as acct_owner,
			  a.owner_type as acct_owner_type,
			  re.code,
			  re.fname,
			  re.lname,
			  re.addr_postcode,
			  re.email,
			  re.shop_id,
			  a.acct_id,
			  a.ccy_code,
			  a.balance,
			  a.acct_type,
			  y.exch_rate,
			  decode(c.status, 'A', a.status, 'S') status,
			  a.credit_limit,
			  NVL(s.tax_rate,NVL(l.tax_rate,r.default_tax_rate)) tax_rate,
			  l.max_stake_mul chnl_max_stk_mul,
			  c.liab_group
			from
			  tCustomer     c,
			  tCustomerReg  re,
			  tAcct         a,
			  tCcy          y,
			  tCustomerSort s,
			  tChannel      l,
			  tControl      r,
			  outer (
				tCustGroup  cg,
				tGroupValue gv
			  )
			where
			  c.cust_id         = a.cust_id         and
			  c.cust_id         = re.cust_id        and
			  s.sort            = c.sort            and
			  a.ccy_code        = y.ccy_code        and
			  re.cust_id        = cg.cust_id        and
			  cg.group_value_id = gv.group_value_id and
			  gv.group_name     = 'SBOOK'           and
			  c.cust_id         = ?                 and
			  l.channel_id      = ?
		}
	} else {
		db_store_qry pb_cust_info {
			select
			  c.username,
			  c.acct_no,
			  c.last_bet,
			  c.receipt_counter,
			  c.max_stake_scale,
			  c.bet_count,
			  c.notifyable,
			  c.country_code,
			  c.lang,
			  a.owner as acct_owner,
			  a.acct_id,
			  a.ccy_code,
			  a.balance,
			  a.acct_type,
			  y.exch_rate,
			  decode(c.status, 'A', a.status, 'S') status,
			  a.credit_limit,
			  NVL(s.tax_rate,NVL(l.tax_rate,r.default_tax_rate)) tax_rate,
			  l.max_stake_mul chnl_max_stk_mul,
			  c.liab_group
			from
			  tCustomer     c,
			  tAcct         a,
			  tCcy          y,
			  tCustomerSort s,
			  tChannel      l,
			  tControl      r
			where
			  c.cust_id    = a.cust_id   and
			  s.sort       = c.sort      and
			  a.ccy_code   = y.ccy_code  and
			  c.cust_id    = ?           and
			  l.channel_id = ?
		}
	}

	db_store_qry pb_max_chnl_max_stk_mul {
		select
		max(max_stake_mul) max_chnl_stk_mul

		from
		tChannel
	} 30

	db_store_qry pb_cashcust_info {
		select
		c.username,
		c.acct_no,
		c.last_bet,
		c.receipt_counter,
		c.max_stake_scale,
		c.bet_count,
		c.lang,
		c.country_code,
		a.owner as acct_owner,
		a.acct_id,
		a.ccy_code,
		a.balance,
		y.exch_rate,
		decode(c.status, 'A', a.status, 'S') status,
		a.credit_limit,
		NVL(s.tax_rate,NVL(l.tax_rate,r.default_tax_rate)) tax_rate,
		l.max_stake_mul chnl_max_stk_mul

		from
		tCustomer     c,
		tAcct         a,
		tCcy          y,
		tCustomerSort s,
		tChannel      l,
		tControl      r

		where
		c.cust_id    = a.cust_id   and
		s.sort       = c.sort      and
		a.ccy_code   = y.ccy_code  and
		a.acct_id    = ?           and
		l.channel_id = ?

	}




	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		db_store_qry pb_ins_bet {
			execute procedure pInsOBet(
									   p_use_free_bets  = ?,
									   p_ipaddr         = ?,
									   p_aff_id         = ?,
									   p_source         = ?,
									   p_placed_by      = ?,
									   p_cust_id        = ?,
									   p_acct_id        = ?,
									   p_unique_id      = ?,
									   p_bet_type       = ?,
									   p_num_selns      = ?,
									   p_num_legs       = ?,
									   p_num_lines      = ?,
									   p_stake          = ?,
									   p_stake_per_line = ?,
									   p_tax_rate       = ?,
									   p_tax_type       = ?,
									   p_tax            = ?,
									   p_max_payout     = ?,
									   p_slip_id        = ?,
									   p_token_value    = ?,
									   p_pay_now        = ?,
									   p_call_id        = ?,
									   p_receipt_format = ?,
									   p_receipt_tag    = ?,
									   p_leg_no         = ?,
									   p_leg_sort       = ?,
									   p_part_no        = ?,
									   p_ev_oc_id       = ?,
									   p_ev_id          = ?,
									   p_ev_mkt_id      = ?,
									   p_price_type     = ?,
									   p_o_num          = ?,
									   p_o_den          = ?,
									   p_ep_active      = ?,
									   p_hcap_value     = ?,
									   p_bir_index      = ?,
									   p_leg_type       = ?,
									   p_ew_fac_num     = ?,
									   p_ew_fac_den     = ?,
									   p_ew_places      = ?,
									   p_bet_id         = ?,
									   p_in_running     = ?,
									   p_settle_info    = ?,
									   p_rep_code       = ?,
									   p_on_course_type = ?
									   )
		}
	} else {

		db_store_qry pb_ins_bet {
			execute procedure pInsOBet(
									   p_use_free_bets  = ?,
									   p_ipaddr         = ?,
									   p_aff_id         = ?,
									   p_source         = ?,
									   p_placed_by      = ?,
									   p_cust_id        = ?,
									   p_acct_id        = ?,
									   p_unique_id      = ?,
									   p_bet_type       = ?,
									   p_num_selns      = ?,
									   p_num_legs       = ?,
									   p_num_lines      = ?,
									   p_stake          = ?,
									   p_stake_per_line = ?,
									   p_tax_rate       = ?,
									   p_tax_type       = ?,
									   p_tax            = ?,
									   p_max_payout     = ?,
									   p_slip_id        = ?,
									   p_pay_now        = ?,
									   p_call_id        = ?,
									   p_receipt_format = ?,
									   p_receipt_tag    = ?,
									   p_leg_no         = ?,
									   p_leg_sort       = ?,
									   p_part_no        = ?,
									   p_ev_oc_id       = ?,
									   p_ev_id          = ?,
									   p_ev_mkt_id      = ?,
									   p_price_type     = ?,
									   p_o_num          = ?,
									   p_o_den          = ?,
									   p_ep_active      = ?,
									   p_hcap_value     = ?,
									   p_bir_index      = ?,
									   p_leg_type       = ?,
									   p_ew_fac_num     = ?,
									   p_ew_fac_den     = ?,
									   p_ew_places      = ?,
									   p_bet_id         = ?,
									   p_in_running     = ?,
									   p_settle_info    = ?,
									   p_rep_code       = ?,
									   p_on_course_type = ?
									   )
		}
	}


	db_store_qry pb_get_sc_status {
		select
		m.status,
		g.name

		from
		tEvMkt m,
		tEvOCGrp g

		where
		m.ev_id = ?   and
		m.sort = 'SC' and
		m.status = 'A' and
		m.ev_oc_grp_id = g.ev_oc_grp_id
	}


	# We default to taking just the MR market with the lowest disporder,
	# to allow for having more than one active MR market.  Assumption is
	# that the market with the lowest disporder is 90 minutes (rather than
	# half-time for example)
	db_store_qry pb_get_mr_prc_for_sc {
		select first 1
		lp_num,
		lp_den

		from
		tEvOc  o,
		tEvMkt m

		where
		m.ev_id     = ?           and
		m.ev_mkt_id = o.ev_mkt_id and
		m.sort      = 'MR'        and
		m.status    = 'A'         and
		o.fb_result = ?

		order by
		m.disporder asc
	}
	# EvOcVariants Available hcaps
	db_store_qry pb_check_evocvariant_prc_hcap {
		SELECT
			1
		FROM
			tEvOcVariant  v
		WHERE
			v.ev_oc_id = ?
		AND v.type      = 'HC'
		AND v.status    = 'A'
		AND v.displayed = 'Y'
		AND v.value     = ?
		AND (v.apply_price = 'A' AND v.price_num = ? AND v.price_den = ?) OR (v.apply_price = 'R')
	} 10

	db_store_qry pb_get_evocvariant_prc_hcap {
		SELECT
			price_num,
			price_den,
			apply_price,
			max_bet
		FROM
			tEvOcVariant  v
		WHERE
			v.ev_oc_id = ?
		AND v.type      = 'HC'
		AND v.status    = 'A'
		AND v.displayed = 'Y'
		AND v.value     = ?
	} 10


	db_store_qry pb_get_sc_price {
		execute procedure pGetPriceSC(
									  p_type   = ?,
									  p_cs_num = ?,
									  p_cs_den = ?,
									  p_fg_num = ?,
									  p_fg_den = ?
									  )
	}

	# Cum Stakes precision
	set precision [string length $PC_BET_DELAY]

	# Do we use Database Cumulative Stakes Delay ?
	if {[OT_CfgGet PB_USE_DB_BET_DELAY 0]} {
		# Then we pass an informix placeholder , the value needs to be taken
		# from tControl dynamically
		set cum_stk_limit_clause "b.cr_date > CURRENT - ? units second and"
		log 5 " Initialized cumulative stakes query using DB value"
	} else {
		# Else we do the old way which is set up once per init
		set cum_stk_limit_clause \
			"b.cr_date   > CURRENT-interval($PC_BET_DELAY) second(${precision}) to second and"
		log 5 " Initialized cumulative stakes query using config value"
	}

	set cum_stakes_type [OT_CfgGet "CUM_STAKES_TYPE" "ALL"]

	# set up defaults for the select part of cum stakes and winnings for
	# when we're not interested in these values
	set select_cum_stk_default \
			"0 as cum_win_lp_stk,
			0 as cum_win_sp_stk,
			0 as cum_place_lp_stk,
			0 as cum_place_sp_stk,
			0 as cum_fc_stk,
			0 as cum_tc_stk"

	set select_cum_wins_default \
			"0 as cum_win_lp_wins,
			0 as cum_win_sp_wins,
			0 as cum_place_lp_wins,
			0 as cum_place_sp_wins"

	if {[OT_CfgGet FUNC_MAX_WIN 0]} {
		set select_cum_wins \
				"nvl(sum(case when s.price_type not in ('L','G') or b.leg_type = 'P' then 0
						else (NVL(s.o_num,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5])/NVL(s.o_den,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_DEN 2]))*b.stake_per_line*t.num_bets_per_seln
						end),0)
				as cum_win_lp_wins,
				nvl(sum(case when s.price_type in ('L','G') or b.leg_type = 'P' then 0
						else (NVL(o.lp_num,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5])/NVL(o.lp_den,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_DEN 2]))*b.stake_per_line*t.num_bets_per_seln
						end),0)
				as cum_win_sp_wins,
				nvl(sum(case when s.price_type not in ('L','G') or b.leg_type = 'W' then 0
						else (NVL(s.o_num,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5])/NVL(s.o_den,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_DEN 2]))*b.stake_per_line*t.num_bets_per_seln
						end),0)
				as cum_place_lp_wins,
				nvl(sum(case when s.price_type in ('L','G') or b.leg_type = 'W' then 0
						else (NVL(o.lp_num,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5])/NVL(o.lp_den,[OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_DEN 2]))*b.stake_per_line*t.num_bets_per_seln
						end),0)
				as cum_place_sp_wins"
	} else {
		set select_cum_wins $select_cum_wins_default
	}

	switch -- $cum_stakes_type {

		"ALL" { db_store_qry pb_get_cum_stake [subst {
			select {+INDEX (b ibet_x2)}
			s.ev_oc_id,
			b.source,
			nvl(ocv.oc_var_id,-1) as oc_var_id,
			nvl(sum(b.stake_per_line*t.num_bets_per_seln),0)
			as cum_stakes,
 			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line * t.num_bets_per_seln
			end),0) as cum_stakes_priced,
 			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line * t.num_bets_per_seln
			end),0) as cum_stakes_priced_var,
			nvl(sum(case when s.price_type not in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_win_lp_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type not in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_win_lp_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type not in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_win_lp_stk_priced_var,
			nvl(sum(case when s.price_type in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_win_sp_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_win_sp_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type in ('L','G') or b.leg_type = 'P' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_win_sp_stk_priced_var,
			nvl(sum(case when s.price_type not in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_place_lp_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type not in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_place_lp_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type not in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_place_lp_stk_priced_var,
			nvl(sum(case when s.price_type in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_place_sp_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_place_sp_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.price_type in ('L','G') or b.leg_type = 'W' or s.leg_sort in ('SF','TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_place_sp_stk_priced_var,
			nvl(sum(case when s.leg_sort not in ('SF') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_fc_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.leg_sort not in ('SF') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_fc_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.leg_sort not in ('SF') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_fc_stk_priced_var,
			nvl(sum(case when s.leg_sort not in ('TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_tc_stk,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.leg_sort not in ('TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_tc_stk_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when s.leg_sort not in ('TC') then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_tc_stk_priced_var,
			nvl(sum(case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_mult_stakes,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_mult_stakes_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_mult_stakes_priced_var,
			$select_cum_wins
			from
			tOBet    s,
			tBet     b,
			tBetType t,
			tEvMkt   m,
			tEvOc    o,
			outer tEvOcVariant ocv

			where
			b.acct_id   = ? and
			$cum_stk_limit_clause
			s.ev_oc_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
			s.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			s.bet_id    = b.bet_id          and
			s.leg_sort  in ('--','AH','A2','WH','HL','hl','MH','CW','SF','TC') and
			b.bet_type  = t.bet_type and
			NVL(s.bir_index,-1) = NVL(m.bir_index,-1) and
			s.ev_oc_id = ocv.ev_oc_id and
			m.ev_mkt_id = ocv.ev_mkt_id and
			(
				(ocv.type = 'HC' and s.hcap_value = ocv.value) or
				(ocv.type = '--' and s.hcap_value is null)
			)
			group by
			1,2,3
		}]
		}
		"SINGLES" { db_store_qry pb_get_cum_stake [subst {
			select {+INDEX (b ibet_x2)}
			s.ev_oc_id,
			b.source,
			nvl(ocv.oc_var_id,-1) as oc_var_id,
			nvl(sum(b.stake_per_line*t.num_bets_per_seln),0)
			as cum_stakes,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line*t.num_bets_per_seln end),0)
			as cum_stakes_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line*t.num_bets_per_seln end),0)
			as cum_stakes_priced_var,
			0 as cum_mult_stakes,
			0 as cum_mult_stakes_priced,
			0 as cum_mult_stakes_priced_var
			$select_cum_stk_default,
			$select_cum_wins_default
			from
			tOBet    s,
			tBet     b,
			tBetType t,
			tEvMkt   m,
			tEvOc    o,
			outer tEvOcVariant ocv

			where
			b.acct_id   = ? and
			$cum_stk_limit_clause
			s.ev_oc_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
			s.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			s.bet_id    = b.bet_id          and
			s.leg_sort  in ('--','AH','A2','WH','HL','hl','CW','SF','TC') and
			b.bet_type  = t.bet_type        and
			b.bet_type  = 'SGL' and
			NVL(s.bir_index,-1) = NVL(m.bir_index,-1) and
			s.ev_oc_id = ocv.ev_oc_id and
			m.ev_mkt_id = ocv.ev_mkt_id and
			(
				(ocv.type = 'HC' and s.hcap_value = ocv.value) or
				(ocv.type = '--' and s.hcap_value is null)
			)
			group by
			1,2,3
		}]
		}
		"CUSTOM" { db_store_qry pb_get_cum_stake [subst {
			select {+INDEX (b ibet_x2)}
			s.ev_oc_id,
			b.source,
			nvl(ocv.oc_var_id,-1) as oc_var_id,
			nvl(sum(b.stake_per_line*t.num_bets_per_seln),0)
			as cum_stakes,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line*t.num_bets_per_seln end),0)
			as cum_stakes_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else b.stake_per_line*t.num_bets_per_seln end),0)
			as cum_stakes_priced_var,
			nvl(sum(case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end),0)
			as cum_mult_stakes,
			nvl(sum(case
				when nvl(o.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_mult_stakes_priced,
			nvl(sum(case
				when nvl(ocv.price_changed_at,b.cr_date) > b.cr_date then 0
				else (case when b.num_legs == 1 then 0
					else b.stake_per_line*t.num_bets_per_seln
					end)
				end),0)
			as cum_mult_stakes_priced_var,
			$select_cum_stk_default,
			$select_cum_wins_default
			from
			tOBet    s,
			tBet     b,
			tBetType t,
			tEvMkt   m,
			tEvOc    o,
			outer tEvOcVariant ocv

			where
			b.acct_id   = ? and
			$cum_stk_limit_clause
			s.ev_oc_id  in (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) and
			s.ev_oc_id = o.ev_oc_id and
			o.ev_mkt_id = m.ev_mkt_id and
			s.bet_id    = b.bet_id          and
			s.leg_sort  in ([OT_CfgGet CUM_STAKES_LEG_SORTS '']) and
			b.bet_type  = t.bet_type        and
			b.bet_type  = 'SGL' and
			NVL(s.bir_index,-1) = NVL(m.bir_index,-1) and
			s.ev_oc_id = ocv.ev_oc_id and
			m.ev_mkt_id = ocv.ev_mkt_id and
			(
				(ocv.type = 'HC' and s.hcap_value = ocv.value) or
				(ocv.type = '--' and s.hcap_value is null)
			)
			group by
			1,2,3
		}]
		}
	}


	db_store_qry pb_get_rcpt {
		SELECT
		receipt,
		cr_date

		FROM
		tBet

		WHERE
		bet_id = ?
	}

	db_store_qry pb_get_xgame_rcpt {
		select
			receipt
		from
			tXGameSub
		where
			xgame_sub_id = ?
	}

	db_store_qry pb_chk_hcap_apc {
		execute procedure pChkHcapAPC(
									  p_ev_mkt_id = ?,
									  p_ev_oc_id  = ?,
									  p_stake     = ?,
									  p_o_num     = ?,
									  p_o_den     = ?,
									  p_hcap_value = ?)
	}

	db_store_qry pb_get_cust_ev_lvl_limit {
		select
			level,
			id,
			max_stake_scale,
			liab_group_id
		from
			tCustLimit
		where
			cust_id = ?
	}

	# extra customer information to be sent to betting ticker
	# added for Ladbrokes
	if {[OT_CfgGet EXTRA_BETTING_TICKER_DATA 0]} {

		db_store_qry pb_get_extra_betting_ticker_data {
			select
				cr.lname,
				cr.fname,
				cr.code,
				c.country_code,
				c.elite
			from
				tCustomer c,
				tCustomerreg cr
			where
				c.cust_id = cr.cust_id and
				c.cust_id = ?
		}
	}

	#
	# Retrieve information from the anonymous terminal account
	# NOTE: at this stage we are dealing with the PUBLIC terminal
	# account so balance checking is seemless. pInsBet handles the
	# conversion of accounts and places the bet in the PRIVATE account
	#
	db_store_qry pb_anon_info {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.last_bet,
			c.receipt_counter,
			c.max_stake_scale,
			c.bet_count,
			c.elite,
			c.country_code,
			c.notifyable,
			c.lang,
			re.code,
			re.fname,
			re.lname,
			re.addr_postcode,
			re.email,
			a.acct_id,
			a.ccy_code,
			a.balance,
			a.acct_type,
			a.owner as acct_owner,
			a.owner_type as acct_owner_type,
			y.exch_rate,
			decode(c.status, 'A', a.status, 'S') status,
			a.credit_limit,
			NVL(l.tax_rate,r.default_tax_rate) tax_rate,
			l.max_stake_mul chnl_max_stk_mul,
			c.liab_group,
			c.aff_id,
			f1.flag_value trading_note,
			adl.loc_name
		from
			tCustomer           c,
			tCustomerReg        re,
			tAcct               a,
			tCcy                y,
			tChannel            l,
			tControl            r,
			tTermAcct           t,
			outer tCustomerFlag f1,
			outer (
				tAdminTerm      adt,
				tAdminLoc       adl
			)
		where
			c.cust_id        = a.cust_id
			and a.acct_id    = t.acct_id
			and c.cust_id    = re.cust_id
			and a.acct_type  = 'PUB'
			and a.ccy_code   = y.ccy_code
			and a.ccy_code   = ?
			and t.term_code  = ?
			and l.channel_id = ?
			and f1.cust_id   = c.cust_id
			and f1.flag_name = 'trading_note'
			and t.term_code  = adt.term_code
			and adt.loc_code = adl.loc_code
	}

	# Lock the anonymous betting account
	db_store_qry pb_anon_lock  {
		update tadminterm set
			bet_count = bet_count
		where
			term_code = ?
	}

	set pb_qrys_prepared 1
}


#---------------------------------------------------------------------------
# Initialise any data required for a bet placement
#---------------------------------------------------------------------------

proc OB_placebet::init_placebet {{source ""}} {


	global PB_ERRORS BSEL CUST USER_ID PB_OVERRIDES BET_TYPE

	variable PB_MODE
	variable MSEL
	variable GLOB
	variable CUST_EV_LVL_LIMIT

	foreach v {MSEL BSEL CUST PB_ERRORS GLOB PB_OVERRIDES CUST_EV_LVL_LIMIT} {
		catch {unset $v}
	}

	# If we are changing channels then reload the available bet types
	if {[info exists BET_TYPE(source)] && $BET_TYPE(source) != $source} {
		set BET_TYPE(loaded) 0
		set BET_TYPE(source) $source
	}

	set CUST(USER_ID)         -1
	set CUST(exch_rate)        1
	set CUST(balance)          0
	set CUST(credit_limit)     0
	set CUST(max_stake_scale)  1
	set CUST(ccy_code)         GBP
	set CUST(bet_count)        0
	set CUST(chnl_max_stk_mul) 1
	set CUST(term_code)        {}

	# Since init_placebet is called in multiple places we
	# need to ensure that anonymous betting is not overwritten
	# if it has been set up. If it has not been explicity enabled
	# in init_anon_placebet it is disabled
	if {![info exists PB_MODE]} {
		set PB_MODE "ACCOUNT"
	}

	set BSEL(num_bets)    0
	set BSEL(sks)         ""

	if {$source != ""} {
		set BSEL(source) $source
	} else {
		set BSEL(source) [OT_CfgGet CHANNEL I]
	}



	#
	# Three kinds of bet building/placement errors:
	# 1. normal error
	# 2. warning
	# 3. confirmation request: for telebetting, an error which may be
	#    overridden would precipitate a confirmation request
	#
	set PB_ERRORS(num_err)  0
	set PB_ERRORS(num_warn) 0
	set PB_ERRORS(num_conf) 0

	#
	# PB_OVERRIDES is an array holding information about overrides
	# which need to be recorded (i.e. inserted into tOverride) after
	# bet placement
	#
	array set PB_OVERRIDES [list]
	set PB_OVERRIDES(code) [list]


	# prepare the qureies if not done so

	placebet_prepare_queries


	# get control data

	get_control


	# load the bet map

	get_bet_map


	# get validation options from config file

	get_val_conf

	# get the maximum channel max stake multiplier

	get_max_channel_max_stake_multiplier
}

#---------------------------------------------------------------------------
# Initialise the bet placement mode
#
# Anonymous Hospitality betting allows customers to place bets without an
# openbet account. Funds are paid into a public account associated with the
# terminal. When placing the bet the public terminal account is used until
# pInsBet is actually called whereby the funds are transfered to the private
# account and the bet struck against the private account.
#---------------------------------------------------------------------------
proc OB_placebet::init_placebet_mode {{mode "ACCOUNT"} {ccy_code GBP} {term_code ""}} {

	variable PB_MODE
	global   CUST

	OT_LogWrite 4 "Initialising placebet mode: $mode, \
		ccy_code: $ccy_code, term_code: $term_code"

	# Enable / Disable Anonymous Betting
	switch -- $mode {
		{ANON} {
			set PB_MODE         "ANON"
			set CUST(ccy_code)  $ccy_code
			set CUST(term_code) $term_code
		}
		{ACCOUNT} -
		default {
			set PB_MODE "ACCOUNT"
		}
	}

	return
}


#---------------------------------------------------------------------------
# record all errors for return to the calling process
#
# err_type {WARN|ERR|CONF}
# level    {SYS|ALL|BET|SELN|PART}
# id       appropriate id based on level above
# code     an agreed error code
# msg      an explanatory error message
#
# PB_ERRORS is an array containing values: num_err & num_warn &num_conf
# and lists: errors & warnings & override confirmation requests
# each element in the list is an array containing:
#  level, id, code, msg
#---------------------------------------------------------------------------

proc OB_placebet::pb_err {err_type code msg level {bet_id -1} {seln_id -1} {part_id -1} {must_check_override 0}} {
#
# Returns 1 if an error has been added
#         0 if error is overridden
#        -1 if confirmation of override required
#

	global PB_ERRORS PB_OVERRIDES
	variable pb_real

	set err(code)    $code
	set err(msg)     $msg
	set err(level)   $level
	set err(bet_id)  $bet_id
	set err(seln_id) $seln_id
	set err(part_id) $part_id

	#
	# Don't add error if overridden
	# If override has not been declared, add error of type CONF to request
	# confirmation or authorisation
	#
	if {$pb_real==1 || $must_check_override==1} {
		switch -- [::OB_operator::op_override $code $bet_id] {
			1 {

				OT_LogWrite 1 "\n\npb_errB: level: $level, code: $code"

				lappend PB_OVERRIDES(code) [array get err]
				switch -- $level {
					OC  {
							if {![info exists PB_OVERRIDES(OC,$bet_id)]|| [lsearch $PB_OVERRIDES(OC,$bet_id) $code]<0} {
								lappend PB_OVERRIDES(OC,$bet_id) $code
							}
						}
					PART {
							if {![info exists PB_OVERRIDES(PART,$bet_id,$seln_id,$part_id)] || [lsearch $PB_OVERRIDES(PART,$bet_id,$seln_id,$part_id) $code]<0} {
								lappend PB_OVERRIDES(PART,$bet_id,$seln_id,$part_id) $code
							}
						 }
					BET  {
							if {![info exists PB_OVERRIDES(BET,$bet_id)] || [lsearch $PB_OVERRIDES(BET,$bet_id) $code]<0} {
								lappend PB_OVERRIDES(BET,$bet_id) $code
							}
						 }
					XGAME  {
							if {![info exists PB_OVERRIDES(XGAME,$bet_id)] || [lsearch $PB_OVERRIDES(XGAME,$bet_id) $code]<0} {
								lappend PB_OVERRIDES(XGAME,$bet_id) $code
							}
						}
				}
				return 0
			  }
		   -1 {
		   		OT_LogWrite 1 "\n\npb_errC: level: $level, code: $code"

		   	set err_type CONF}
		}
	}


	OT_LogWrite 1 "err_type: $err_type"

	if {$err_type == "CONF"} {
		set log_lev 2
		incr    PB_ERRORS(num_conf)
		lappend PB_ERRORS(confirms)   [array get err]
	} elseif {$err_type == "WARN"} {
		set     log_lev 3
		incr    PB_ERRORS(num_warn)
		lappend PB_ERRORS(warnings)   [array get err]
	} else {
		if {$level == "SYS"} {
			set log_lev 1
		} else {
			set log_lev 2
		}
		incr    PB_ERRORS(num_err)
		lappend PB_ERRORS(errors) [array get err]
	}

	set str $level

	if {[OT_CfgGet ADD_PB2_ERRS_TO_ERR_LIST 1]} {
	err_add $msg
	}

	foreach id "$bet_id $seln_id $part_id" {
		if {$id >= 0} {
			append str ":$id"
		}
	}

	log $log_lev "$str:$code:$msg"

	if {$err_type == "CONF"} {
		return -1
	} else {
		return 1
	}
}


#---------------------------------------------------------------------------
# retrieve the global limits from tcontrol
#---------------------------------------------------------------------------

proc OB_placebet::get_control args {

	variable GLOB

	if {[catch {set rs [db_exec_qry pb_control]} msg]} {
		catch {log 1 "pb_caching error: $msg"}
		set GLOB(bets_allowed) "Y"
	}
	if {[db_get_nrows $rs] != 1} {
		catch {log 1 "pb_caching error: control table did not return 1 row"}
		set GLOB(bets_allowed) "Y"
	}
	if {[catch {
		if {[db_get_col $rs bets_allowed] != "Y"} {
			pb_err ERR NO_BETS \
				"service is currently unavailable,\n please try again shortly" SYS
			return
		}
		set GLOB(bets_allowed) [db_get_col $rs bets_allowed]
	} msg]} {
		catch {log 1 "pb_caching error: colnames-[db_get_colnames $rs]- $msg"}
		set GLOB(bets_allowed) "Y"
	}

	db_close $rs
}





#---------------------------------------------------------------------------
# Retrieve BET_MAP information from database and cache it
#---------------------------------------------------------------------------

proc OB_placebet::get_bet_map args {

	global BET_TYPE
	global BSEL

	if $BET_TYPE(loaded) {
		return
	}

	log 5 "get_bet_map: loading bet map for channel $BSEL(source)"

	if [catch {set rs [db_exec_qry pb_bet_type_qry "%${BSEL(source)}%"]} msg] {
		pb_err ERR BMAP_SQL "unable to run bet map query:$msg" SYS
		return
	}

	set rows   [db_get_nrows $rs]
	set fields [db_get_colnames $rs]

	for {set r 0} {$r <$rows} {incr r} {

		set bet_type [string trim [db_get_col $rs $r bet_type]]
		lappend BET_TYPE(bet_types) $bet_type

		foreach f $fields {
			set BET_TYPE($bet_type,$f) [db_get_col $rs $r $f]
		}
	}

	db_close $rs

	#	log 3 "PB(get_bet_map) read $rows bet_types"

	set BET_TYPE(source) $BSEL(source)
	set BET_TYPE(loaded) 1
}





#---------------------------------------------------------------------------
# Particular validation rules can be requested or ignored from the
# configuration file.
#
# These are stored in the VAL_OPS array for use during the validation
# process
#---------------------------------------------------------------------------

proc OB_placebet::get_val_conf args {

	variable VAL_OPS
	variable COMBI_MKTS

	if $VAL_OPS(loaded) {
		return
	}

	if {[OT_CfgGetTrue ALLOW_FIVE_DRAWS]} {
		set VAL_OPS(allow_five_draws) 1
	}


	set COMBI_MKTS [OT_CfgGet PB_COMBI_MKTS ""]

	set $VAL_OPS(loaded) 1
}

#-----------------------------------------------------------------------------
# Retrieve the maximum channel max stake multiplier.
# Need it to determine customer max stake across different channels
#-----------------------------------------------------------------------------

proc OB_placebet::get_max_channel_max_stake_multiplier args {

	variable GLOB

	if {[catch {set rs [db_exec_qry pb_max_chnl_max_stk_mul]} msg]} {
		catch {log 1 "pb_caching error: $msg"}
		set GLOB(max_chnl_max_stk_mul) 1
	}

	if {[catch {set GLOB(max_chnl_max_stk_mul) [db_get_col $rs max_chnl_stk_mul]} msg]} {
		catch {log 1 "pb_caching error: colnames-[db_get_colnames $rs]- $msg"}
		set GLOB(max_chnl_max_stk_mul) 1
	}

	if {$GLOB(max_chnl_max_stk_mul) == ""} {
		set GLOB(max_chnl_max_stk_mul) 1
	}

	db_close $rs
}

# ----------------------------------------------------------------------
# called to start the bet placement proceedings
#
# begins a transaction, and indicates that the customer record
# should be locked when the time comes
# MUST be followed by a call to pb_end at some point in this
# request
# ----------------------------------------------------------------------

proc OB_placebet::pb_start {{source ""}} {

	global BSEL USER_ID
	variable pb_real
	variable BP_MESSAGES
	variable MONITOR_MSG
	variable FREEBET_CHECKS
	variable LBT_BET_QUEUE

	set pb_real 0

	if [catch {db_begin_tran} msg] {
		pb_err ERR NO_TRAN "Failed to start Transaction $msg" SYS
		return
	}

	if {[OB_login::ob_is_guest_user]} {
		pb_err ERR GUEST "Guest user cannot place bets" BET
		return
	}

	set BP_MESSAGES {}
	array unset MONITOR_MSG
	set MONITOR_MSG(num_rows) 0

	set pb_real 1

	if {[info exists FREEBET_CHECKS]} {
		unset FREEBET_CHECKS
	}

	if {[info exists LBT_BET_QUEUE]} {
		unset LBT_BET_QUEUE
	}
	set LBT_BET_QUEUE [list]


	init_placebet $source
}



#---------------------------------------------------------------------------
# retrieve and store selection data in MSEL
#---------------------------------------------------------------------------

proc OB_placebet::get_seln_details {seln_ids {get_cum_stk 1}} {

	global CUST
	variable MSEL
	variable MAX_SELNS


	set nids     [llength $seln_ids]

	log 5 "retrieving $nids ev_oc_ids ($seln_ids) for place_bet"

	set seln_base "db_exec_qry pb_selns_qry"

	catch {unset MSEL}

	set   MSEL(rows) 0

	#
	# we only have MAX_SELNS place holders in the statement
	# so we need to loop the query if we have more seln ids than this
	#

	# we pad out seln_ids with -1's to occupy params in the statement
	for {set num [expr {$MAX_SELNS - ($nids % $MAX_SELNS)}]} {$num > 0} {incr num -1} {
		lappend seln_ids -1
	}

	for {set lstart 0} {$lstart < $nids} {incr lstart $MAX_SELNS} {

		set l [lrange $seln_ids $lstart [expr {$lstart+$MAX_SELNS-1}]]
		set qry "$seln_base $l"

		if [catch {set rs [eval $qry]} msg] {
			pb_err ERR SELN_SQL \
				"unable to retrieve selections: $msg:\n $qry"\
				SYS
			return 0
		}


		set rows [db_get_nrows $rs]

		#
		# store selection info in MSEL array
		#
		set fields [db_get_colnames $rs]

		incr MSEL(rows) $rows

		# Are dynamic profiles, e.g. time-based stake factor dependant
		# on hierarchy level, to be applied?  If so, load the relevant
		# stake factor into the SF_PROFILE array
		catch {unset SF_PROFILE}
		if {[OT_CfgGet FUNC_SF_PROFILES "N"] == "Y"} {
			set sf_qry "db_exec_qry pb_get_dynamic_stake_factors $l $l $l $l"
			if [catch {set sf_rs [eval $sf_qry]} msg] {
				pb_err ERR SELN_SQL \
					"unable to retrieve selection stake factors: $msg:\n $qry"\
					SYS
				return 0
			}
			set nrows [db_get_nrows $sf_rs]
			set current [clock seconds]

			for {set i 0} {$i < $nrows} {incr i} {
				set level      [db_get_col $sf_rs $i level]
				set oc         [db_get_col $sf_rs $i ev_oc_id]
				set start_time [db_get_col $sf_rs $i start_time]
				set from       [db_get_col $sf_rs $i mins_before_from]
				set to         [db_get_col $sf_rs $i mins_before_to]
				set sf         [db_get_col $sf_rs $i stake_factor]

				set mins_before [expr ([clock scan $start_time] - $current)/60]

				# Only update if for current time t, $from >= t > $to
				# Note, $from can be null but $to can't, and no two rows
				# should overlap for the same level and ev_oc_id
				if {($from == "" && $mins_before > $to) ||
							($from >= $mins_before && $mins_before > $to)} {
					if {![info exists SF_PROFILE($oc,sf_level)]} {
						# Nothing's added for this selection yet so jus update
						set SF_PROFILE($oc,sf_level) $level
						set SF_PROFILE($oc,sf)       $sf
					} elseif {$SF_PROFILE($oc,sf_level) == $level ||
								($SF_PROFILE($oc,sf_level) == "CATEGORY" &&
									($level == "CLASS" || $level == "TYPE" ||
									$level == "EVENT")) ||
								($SF_PROFILE($oc,sf_level) == "CLASS" &&
									($level == "TYPE" || $level == "EVENT")) ||
								($SF_PROFILE($oc,sf_level) == "TYPE" &&
									$level == "EVENT")} {
						# The lowest level in the hierarchy takes priority, so only
						# update if the new level is the same or lower than the old
						set SF_PROFILE($oc,sf_level) $level
						set SF_PROFILE($oc,sf)       $sf
					}
				}
			}
			db_close $sf_rs
		}

		for {set r 0} {$r < $rows} {incr r} {

			set e [db_get_col $rs $r ev_oc_id]

			foreach f $fields {
				lappend MSEL($f) \
					[set MSEL($e,$f) [db_get_col $rs $r $f]]
			}

			#When displaying the Next Goal market need to display the bir_index
			if {[OT_CfgGet NEXT_GOAL_SHOW_INDEX 0]} {
				if {[regexp {Next Goal} $MSEL($e,mkt_name)]} {
					append MSEL($e,mkt_name) " $MSEL($e,bir_index)"
				}
			}

			# Establish formated version of handicap value
			if {[info exists MSEL($e,hcap_value)] && $MSEL($e,hcap_value) != ""} {
				set MSEL($e,hcap_value_fmt) [format "%0.$MSEL($e,hcap_precision)f" $MSEL($e,hcap_value)]
			} else {
				set MSEL($e,hcap_value_fmt) ""
			}

			# check if we are to use the each-way factor, else default
			# it to 1
			if {![OT_CfgGet FUNC_EW_FACTOR 0]} {
				set MSEL($e,ew_factor) 1.0
			}

			if {[OT_CfgGet FUNC_SF_PROFILES "N"] == "Y" && [info exists SF_PROFILE($e,sf)]} {
				set stake_factor $SF_PROFILE($e,sf)
			} else {
				set stake_factor 1
			}

			# check for non-existent stake limits and inherit from
			# other appropriate limits if necessary
			if {$MSEL($e,max_win_lp) == ""} {
				set MSEL($e,max_win_lp) [expr 999999 * $stake_factor]
			} else {
				set MSEL($e,max_win_lp) \
					[expr $MSEL($e,max_win_lp) * $stake_factor]
			}
			if {$MSEL($e,max_win_sp) == ""} {
				set MSEL($e,max_win_sp) $MSEL($e,max_win_lp)
			} else {
				set MSEL($e,max_win_sp) \
					[expr $MSEL($e,max_win_sp) * $stake_factor]
			}
			if {$MSEL($e,max_win_ep) == ""} {
				set MSEL($e,max_win_ep) $MSEL($e,max_win_lp)
			} else {
				set MSEL($e,max_win_ep) \
					[expr $MSEL($e,max_win_ep) * $stake_factor]
			}
			if {$MSEL($e,max_place_lp) == ""} {
				set MSEL($e,max_place_lp) [expr $MSEL($e,max_win_lp) * $MSEL($e,ew_factor)]
			} else {
				set MSEL($e,max_place_lp) \
					[expr $MSEL($e,max_place_lp) * $stake_factor]
			}
			if {$MSEL($e,max_place_sp) == ""} {
				set MSEL($e,max_place_sp) [expr $MSEL($e,max_win_sp) * $MSEL($e,ew_factor)]
			} else {
				set MSEL($e,max_place_sp) \
					[expr $MSEL($e,max_place_sp) * $stake_factor]
			}
			if {$MSEL($e,max_place_ep) == ""} {
				set MSEL($e,max_place_ep) [expr $MSEL($e,max_win_ep) * $MSEL($e,ew_factor)]
			} else {
				set MSEL($e,max_place_ep) \
					[expr $MSEL($e,max_place_ep) * $stake_factor]
			}
			if {$MSEL($e,stk_min) == ""} {
				set MSEL($e,stk_min) 0.0
			}
			if {$MSEL($e,fc_max_bet) == ""} {
				set MSEL($e,fc_max_bet) $MSEL($e,max_win_lp)
			} else {
				set MSEL($e,fc_max_bet) \
					[expr $MSEL($e,fc_max_bet) * $stake_factor]
			}
			if {$MSEL($e,tc_max_bet) == ""} {
				set MSEL($e,tc_max_bet) $MSEL($e,max_win_lp)
			} else {
				set MSEL($e,tc_max_bet) \
					[expr $MSEL($e,tc_max_bet) * $stake_factor]
			}
			# if the early price is enabled (ep_active)
			#overwrite the live prices with the appropriate early prices
			if {$MSEL($e,ep_active) == "Y"} {
				set MSEL($e,max_win_lp)   $MSEL($e,max_win_ep)
				set MSEL($e,max_place_lp) $MSEL($e,max_place_ep)
			}
			# Need to check if variable_max_stakes is enabled and if it's a relevant class (ie horse racing / ladbrokes)
			if {[var_stakes_enabled $MSEL($e,ev_class_id)] && [OT_CfgGet FUNC_VARIABLE_MAX_STAKES_BY_TIME 0]} {

				# Not entirely sure if this is necessary
				if {[OT_CfgGet FUNC_MAX_WIN 0]} {
					set MSEL($e,start_time) [db_get_col $rs $r ev_start_time]
				}

				set max_lp_bet  $MSEL($e,max_win_lp)
				log 5 "max_lp_bet is $max_lp_bet"
				set max_sp_bet  $MSEL($e,max_win_sp)
				log 5 "max_sp_bet is $max_sp_bet"

				set max_lp_stk $max_lp_bet
				set max_sp_stk $max_sp_bet

				set lp_avail Y
				if {[catch {set odds [expr {double($MSEL($e,lp_num)) / double($MSEL($e,lp_den)) + 1}]} $msg]} {
					set lp_avail N
				}
				set sp_avail $MSEL($e,sp_avail)

				if {$lp_avail == "Y" || $sp_avail == "Y"} {

					# Get the phase start times
					set ev_start_time [db_get_col $rs $r ev_start_time]
					set ev_start_day  [string range $ev_start_time 0 9]
					set phase_2_start [clock scan "$ev_start_day [OT_CfgGet PHASE_2_START]"]
					set phase_3_start [clock scan "$ev_start_day [OT_CfgGet PHASE_3_START]"]
					set current_time  [clock scan [db_get_col $rs $r current_time]]

					if {$current_time < $phase_2_start} {
						log 5 "event is in phase 1"
						set max_lp_stk [expr {$max_lp_bet * [OT_CfgGet PHASE_1_LP_SCALE 1]}]
						set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_1_SP_SCALE 1]}]
					} elseif {$current_time < $phase_3_start} {
						log 5 "event is in phase 2"
						set max_lp_stk [expr {$max_lp_bet * [OT_CfgGet PHASE_2_LP_SCALE 1]}]
						set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_2_SP_SCALE 1]}]
					} else {
						log 5 "event is in phase 3"
						set odds_boundary_1 [OT_CfgGet HORSE_STAKE_ODDS_BOUNDARY_1 1]
						set odds_boundary_2 [OT_CfgGet HORSE_STAKE_ODDS_BOUNDARY_2 1]
						if {$lp_avail=="Y"} {
							if {$odds <= $odds_boundary_1} {
								log 5 "selection is in odds 1"
								set max_lp_stk [expr {$max_lp_bet * [OT_CfgGet PHASE_3_ODDS_1_LP_SCALE 1]}]
								set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_3_ODDS_1_SP_SCALE 1]}]
							} elseif {$odds <= $odds_boundary_2} {
								log 5 "selection is in odds 2"
								set max_lp_stk [expr {$max_lp_bet * [OT_CfgGet PHASE_3_ODDS_2_LP_SCALE 1]}]
								set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_3_ODDS_2_SP_SCALE 1]}]
							} else {
								log 5 "selection is in odds 3"
								set max_lp_stk [expr {$max_lp_bet * [OT_CfgGet PHASE_3_ODDS_3_LP_SCALE 1]}]
								set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_3_ODDS_3_SP_SCALE 1]}]
							}
						} else {
							log 5 "no odds available - set to odds 3"
							set max_sp_stk [expr {$max_sp_bet * [OT_CfgGet PHASE_3_ODDS_3_SP_SCALE]}]
						}

					}

					log 5 "max_lp_stk : $max_lp_stk"
					log 5 "max_sp_stk : $max_sp_stk"

					# The FUNC_VARIABLE_MAX_STAKES_BY_TIME functionality needs extending
					# so that scales are specified seperately for Win and Place. For now
					# check that the place max bet for a price type is not greater than the
					# win max bet after the time phase scales have been applied
					if {$lp_avail == "Y"} {
						set MSEL($e,max_win_lp) $max_lp_stk
						set MSEL($e,max_place_lp) [min $MSEL($e,max_place_lp) $max_lp_stk]
					}
					if {$sp_avail == "Y"} {
						set MSEL($e,max_win_sp) $max_sp_stk
						set MSEL($e,max_place_sp) [min $MSEL($e,max_place_sp) $max_sp_stk]
					}
				}
            		}

			log 5 "MSEL($e,max_win_lp) is $MSEL($e,max_win_lp) and MSEL($e,max_place_lp) is $MSEL($e,max_place_lp)"
			log 5 "MSEL($e,max_win_sp) is $MSEL($e,max_win_sp) and MSEL($e,max_place_sp) is $MSEL($e,max_place_sp)"
		}

		db_close $rs


		#
		# sometimes we really aren't interested
		# in cumulative stake
		#

		if {$get_cum_stk == 0 || ([OT_CfgGet "CUM_STAKES_TYPE" "ALL"] == "NONE")} {
			continue
		}

		# Get previous stakes only at price change overrides set up
		set prev_stk_bir      [ob_control::get prev_stk_bir]
		set prev_stk_nobir    [ob_control::get prev_stk_nobir]

		log 5 " BIR Ignore previous stk?     : $prev_stk_bir"
		log 5 " NON BIR ignore previous stk? : $prev_stk_nobir"

		# If we fetch the cumulative stakes from DB ...
		if {[OT_CfgGet PB_USE_DB_BET_DELAY 0]} {
			# ... we need to get them each time, as they may have updated
			# and the query expects the delay value
			set delay_value [ob_control::get cum_stakes_delay]
			log 5 " Using DB cum_stakes_delay : $delay_value"
			set qry  {db_exec_qry pb_get_cum_stake $CUST(acct_id) $delay_value $l}
		} else {
			# ... otherwise do old way
			log 5 " Using CFG cum_stakes_delay"
			set qry  {db_exec_qry pb_get_cum_stake $CUST(acct_id) $l}
		}

		#
		# Retrieve the cumulative stake info for each selection
		#

		if [catch {set rs_stk [eval [subst $qry]]} msg] {
			pb_err ERR SELN_SQL \
				"unable to retrieve cumulative stake details: $msg:\n $qry" SYS
			return 0
		}

		set rows            [db_get_nrows $rs_stk]

		for {set r 0} {$r < $rows} {incr r} {

			# Get the selection ID
			set e  [db_get_col $rs_stk $r ev_oc_id]
			set c  [db_get_col $rs_stk $r source]

			# do we have a variant ?
			set has_variant [db_get_col $rs_stk $r oc_var_id]

			# Work out what calculation to use, expanded for clarity.
			if { $prev_stk_bir == "Y"  && $MSEL($e,bet_in_run) == "Y" } {
					set calculation "PriceChanged"
				} elseif { $prev_stk_nobir == "Y"  && $MSEL($e,bet_in_run) == "N" } {
					set calculation "PriceChanged"
				} elseif { $prev_stk_bir == "N" && $MSEL($e,bet_in_run) == "Y" } {
					set calculation "Default"
				} elseif { $prev_stk_nobir == "N" && $MSEL($e,bet_in_run) == "N"} {
					set calculation "Default"
			}

			# Store cumulative stake limits
			if { $calculation == "Default" } {
				set cs [expr {double([db_get_col $rs_stk $r cum_stakes])}]
				log 5 ">> Using db.cum_stakes"
			} else {
				# Do we have values in tEvOcVariant ?
				if {$has_variant == -1} {
					set cs [expr {double([db_get_col $rs_stk $r cum_stakes_priced])}]
					log 5 ">> Using db.cum_stakes_priced"
				} else {
					set cs [expr {double([db_get_col $rs_stk $r cum_stakes_priced_var])}]
					log 5 ">> Using db.cum_stakes_priced_var"
				}
			}

			if {![info exists MSEL($e,cum_stakes)]} {
				set MSEL($e,cum_stakes) $cs
			} else {
				set MSEL($e,cum_stakes) [expr {$MSEL($e,cum_stakes) + $cs}]
			}
			log 5 "MSEL($e,cum_stakes) set to $MSEL($e,cum_stakes)"

			# Store multiples cumulative stake limits
			if { $calculation == "Default" } {
				set cms [expr {double([db_get_col $rs_stk $r cum_mult_stakes])}]
				log 5 ">> Using db.cum_mult_stakes"
			} else {
				# Do we have values in tEvOcVariant ?
				if {$has_variant == -1} {
					set cms [expr {double([db_get_col $rs_stk $r cum_mult_stakes_priced])}]
					log 5 ">> Using db.cum_mult_stakes_priced"
				} else {
					set cms [expr {double([db_get_col $rs_stk $r cum_mult_stakes_priced_var])}]
					log 5 ">> Using db.cum_mult_stakes_priced_var"
				}
			}

			if {![info exists MSEL($e,cum_mult_stakes)]} {
				set MSEL($e,cum_mult_stakes) $cms
			} else {
				set MSEL($e,cum_mult_stakes) [expr {$MSEL($e,cum_mult_stakes) + $cms}]
			}
			log 5 "MSEL($e,cum_mult_stakes) set to $MSEL($e,cum_mult_stakes)"

			# if variable stakes is enabled for a class then we need to make a price type
			# and leg type distinction when determining the stake limits.
			if {[var_stakes_enabled $MSEL($e,ev_class_id)]} {

				log 5 "variable stakes enabled for this class"

				# These cumulative stakes are currently in the customer's currency, but
				# can be left as they are because the max stakes are to be converted to
				# the customers currency.
				# If we are looking at 'ALL' cumulative stakes then set these to be the
				# individual price/leg type cumulative totals, else set them to the total
				# stakes
				if {[OT_CfgGet "CUM_STAKES_TYPE" "ALL"] == "ALL"} {
					if { $calculation == "Default" } {
						log 5 ">> Using ALL Default cum stakes (win,place,fc,tc)"
						set cum_win_lp_stk   [expr {double([db_get_col $rs_stk $r cum_win_lp_stk])}]
						set cum_win_sp_stk   [expr {double([db_get_col $rs_stk $r cum_win_sp_stk])}]
						set cum_place_lp_stk [expr {double([db_get_col $rs_stk $r cum_place_lp_stk])}]
						set cum_place_sp_stk [expr {double([db_get_col $rs_stk $r cum_place_sp_stk])}]
						set cum_fc_stk       [expr {double([db_get_col $rs_stk $r cum_fc_stk])}]
						set cum_tc_stk       [expr {double([db_get_col $rs_stk $r cum_tc_stk])}]
					} else {
						# Do we have values in tEvOcVariant ?
						if {$has_variant == -1} {
							log 5 ">> Using ALL Priced cum stakes (win,place,fc,tc)"
							set cum_win_lp_stk   [expr {double([db_get_col $rs_stk $r cum_win_lp_stk_priced])}]
							set cum_win_sp_stk   [expr {double([db_get_col $rs_stk $r cum_win_sp_stk_priced])}]
							set cum_place_lp_stk [expr {double([db_get_col $rs_stk $r cum_place_lp_stk_priced])}]
							set cum_place_sp_stk [expr {double([db_get_col $rs_stk $r cum_place_sp_stk_priced])}]
							set cum_fc_stk       [expr {double([db_get_col $rs_stk $r cum_fc_stk_priced])}]
							set cum_tc_stk       [expr {double([db_get_col $rs_stk $r cum_tc_stk_priced])}]
						} else {
							log 5 ">> Using ALL Priced VARIANT cum stakes (win,place,fc,tc)"
							set cum_win_lp_stk   [expr {double([db_get_col $rs_stk $r cum_win_lp_stk_priced_var])}]
							set cum_win_sp_stk   [expr {double([db_get_col $rs_stk $r cum_win_sp_stk_priced_var])}]
							set cum_place_lp_stk [expr {double([db_get_col $rs_stk $r cum_place_lp_stk_priced_var])}]
							set cum_place_sp_stk [expr {double([db_get_col $rs_stk $r cum_place_sp_stk_priced_var])}]
							set cum_fc_stk       [expr {double([db_get_col $rs_stk $r cum_fc_stk_priced_var])}]
							set cum_tc_stk       [expr {double([db_get_col $rs_stk $r cum_tc_stk_priced_var])}]
						}
					}
				} else {
					set cum_win_lp_stk   $cs
					set cum_win_sp_stk   $cs
					set cum_place_lp_stk $cs
					set cum_place_sp_stk $cs
					set cum_fc_stk       $cs
					set cum_tc_stk       $cs
				}
				# Set up the LP cumulative Win stakes
				if {![info exists MSEL($e,cum_win_lp_stk)]} {
					set MSEL($e,cum_win_lp_stk) $cum_win_lp_stk
				} else {
					set MSEL($e,cum_win_lp_stk) [expr {$MSEL($e,cum_win_lp_stk) + $cum_win_lp_stk}]
				}

				# Set up the SP cumulative Win stakes
				if {![info exists MSEL($e,cum_win_sp_stk)]} {
					set MSEL($e,cum_win_sp_stk) $cum_win_sp_stk
				} else {
					set MSEL($e,cum_win_sp_stk) [expr {$MSEL($e,cum_win_sp_stk) + $cum_win_sp_stk}]
				}

				# Set up the LP cumulative Place stakes
				if {![info exists MSEL($e,cum_place_lp_stk)]} {
					set MSEL($e,cum_place_lp_stk) $cum_place_lp_stk
				} else {
					set MSEL($e,cum_place_lp_stk) [expr {$MSEL($e,cum_place_lp_stk) + $cum_place_lp_stk}]
				}

				# Set up the SP cumulative Place stakes
				if {![info exists MSEL($e,cum_place_sp_stk)]} {
					set MSEL($e,cum_place_sp_stk) $cum_place_sp_stk
				} else {
					set MSEL($e,cum_place_sp_stk) [expr {$MSEL($e,cum_place_sp_stk) + $cum_place_sp_stk}]
				}

				# Set up the forecast stakes
				if {![info exists MSEL($e,cum_fc_stk)]} {
					set MSEL($e,cum_fc_stk) $cum_fc_stk
				} else {
					set MSEL($e,cum_fc_stk) [expr {$MSEL($e,cum_fc_stk) + $cum_fc_stk}]
				}

				# Set up the tricast stakes
				if {![info exists MSEL($e,cum_tc_stk)]} {
					set MSEL($e,cum_tc_stk) $cum_tc_stk
				} else {
					set MSEL($e,cum_tc_stk) [expr {$MSEL($e,cum_tc_stk) + $cum_tc_stk}]
				}

				log 5 "MSEL($e,cum_win_lp_stk) set to $MSEL($e,cum_win_lp_stk)"
				log 5 "MSEL($e,cum_win_sp_stk) set to $MSEL($e,cum_win_sp_stk)"
				log 5 "MSEL($e,cum_place_lp_stk) set to $MSEL($e,cum_place_lp_stk)"
				log 5 "MSEL($e,cum_place_sp_stk) set to $MSEL($e,cum_place_sp_stk)"
				log 5 "MSEL($e,cum_fc_stk) set to $MSEL($e,cum_fc_stk)"
				log 5 "MSEL($e,cum_tc_stk) set to $MSEL($e,cum_tc_stk)"
			}

			# If we're looking at max winnings then store cumulative winnings too
			if {[OT_CfgGet FUNC_MAX_WIN 0]} {

				log 5 "Storing cumulative winnings"

				# These cumulative winnings are currently in the customer's currency
				set cum_win_lp_wins   [expr {double([db_get_col $rs_stk $r cum_win_lp_wins])}]
				set cum_win_sp_wins   [expr {double([db_get_col $rs_stk $r cum_win_sp_wins])}]
				set cum_place_lp_wins [expr {double([db_get_col $rs_stk $r cum_place_lp_wins])}]
				set cum_place_sp_wins [expr {double([db_get_col $rs_stk $r cum_place_sp_wins])}]

				# Set up the LP cumulative Win leg winnings
				if {![info exists MSEL($e,cum_win_lp_wins)]} {
					set MSEL($e,cum_win_lp_wins) $cum_win_lp_wins
				} else {
					set MSEL($e,cum_win_lp_wins) [expr {$MSEL($e,cum_win_lp_wins) + $cum_win_lp_wins}]
				}

				# Set up the SP cumulative Win leg winnings
				if {![info exists MSEL($e,cum_win_sp_wins)]} {
					set MSEL($e,cum_win_sp_wins) $cum_win_sp_wins
				} else {
					set MSEL($e,cum_win_sp_wins) [expr {$MSEL($e,cum_win_sp_wins) + $cum_win_sp_wins}]
				}

				# Set up the LP cumulative Place leg winnings
				if {![info exists MSEL($e,cum_place_lp_wins)]} {
					set MSEL($e,cum_place_lp_wins) $cum_place_lp_wins
				} else {
					set MSEL($e,cum_place_lp_wins) [expr {$MSEL($e,cum_place_lp_wins) + $cum_place_lp_wins}]
				}

				# Set up the SP cumulative Place leg winnings
				if {![info exists MSEL($e,cum_place_sp_wins)]} {
					set MSEL($e,cum_place_sp_wins) $cum_place_sp_wins
				} else {
					set MSEL($e,cum_place_sp_wins) [expr {$MSEL($e,cum_place_sp_wins) + $cum_place_sp_wins}]
				}

				log 5 "MSEL($e,cum_win_lp_wins) set to $MSEL($e,cum_win_lp_wins)"
				log 5 "MSEL($e,cum_win_sp_wins) set to $MSEL($e,cum_win_sp_wins)"
				log 5 "MSEL($e,cum_place_lp_wins) set to $MSEL($e,cum_place_lp_wins)"
				log 5 "MSEL($e,cum_place_sp_wins) set to $MSEL($e,cum_place_sp_wins)"
			}
		}

		db_close $rs_stk
	}

	return 1
}


#---------------------------------------------------------------------------
# retrieve the customer account data and the operator privilidges if any
#
# PB_MODE is set to ANON for anonymous terminal cash betting. For this mode
# the terminals account information is set instead of a users account info
#---------------------------------------------------------------------------

proc OB_placebet::get_user_data {{lock 1}} {

	global USER_ID CUST CASHACCT BSEL

	variable PB_MODE

	if {[OB_login::ob_is_guest_user]} {
		return 1
	}

	OT_LogWrite 1 "CUSTOMER SOURCE: $BSEL(source), PB_MODE: $PB_MODE"

	switch -- $PB_MODE {
		{ANON} {
			set cust_qry [list pb_anon_info $CUST(ccy_code) $CUST(term_code) $BSEL(source)]

			# Lock the terminal account if lock is set
			if {$lock && ![OB_placebet::lock_anon_acct]} {
				return 0
			}
		}
		{ACCOUNT} -
		default {

			set CUST(cust_id) $USER_ID

			if {([info exists CASHACCT]) && ($CASHACCT != "")} {
				#will not want to lock these accounts
				#they are accounts associated with cash betting
				set cust_qry [list pb_cashcust_info $CASHACCT $BSEL(source)]
			} else {

				##------------------------------------------------------------------
				# update tcustomer to lock the customer record
				#
				if {$lock} {
					if [catch {set rs [db_exec_qry pb_cust_lk $USER_ID]} msg] {
						pb_err ERR LK_SQL \
							"failed to exec lock qry: $msg" SYS
						return 0
					}

					if {[db_garc pb_cust_lk] != 1} {
						pb_err ERR LK_CUST "failed to lock customer" ALL
						return 0
					}
				}
				#
				# locking done
				##------------------------------------------------------------------
				set cust_qry [list pb_cust_info $USER_ID $BSEL(source)]
			}
		}
	}

	##---------------------------------------------------------------------
	# retrieve the customer data
	#
	if [catch {set rs [eval db_exec_qry $cust_qry]} msg] {
		pb_err ERR CUST_SQL "failed to exec cust query: $msg" SYS
		return 0
	}

	OT_LogWrite 5 "\#\# USER_ID $USER_ID, ccy [db_get_col $rs ccy_code], exch_rate [db_get_col $rs exch_rate]"

	if {[db_get_nrows $rs] == 1} {
		foreach f [db_get_colnames $rs] {
			set CUST($f) [db_get_col $rs 0 $f]
		}
		db_close $rs
		if {$CUST(chnl_max_stk_mul) == ""} {
			set CUST(chnl_max_stk_mul) 1
		}

	} else {
		pb_err ERR NO_CUST "customer not found" ALL $USER_ID
		db_close $rs
		return 0
	}

	#initialise all cust stake factors by class
	#
	if {[OT_CfgGet EVENT_CLASS_STAKE_SCALE N] == "Y"} {
		OB_placebet::init_ev_class_limit
	}

	#
	# customer data retrieved
	##---------------------------------------------------------------------

	OT_LogWrite 1 "CUSTOMER TAX: $CUST(tax_rate)"

	return 1

}


#----------------------------------------------------------------------
# OB_placebet::lock_anon_acct
# update tadminterm to lock the customer record
#----------------------------------------------------------------------
proc OB_placebet::lock_anon_acct {} {
	global CUST

	if [catch {set rs [db_exec_qry pb_anon_lock $CUST(term_code)]} msg] {
		pb_err ERR LK_SQL "failed to exec lock qry: $msg" SYS
		return 0
	}

	if {[db_garc pb_anon_lock] != 1} {
		pb_err ERR LK_CUST "failed to lock terminal" ALL
		return 0
	}

	return 1
}

#----------------------------------------------------------------------
# When building up a multiple, all the selections data is
# retrieved from the database. This can then be used to build
# the BSEL array for validation against the multiple rules.
#
#----------------------------------------------------------------------


proc OB_placebet::mult_get_selns {seln_ids} {

	global USER_ID
	global LOGIN_DETAILS
	variable SELNS
	variable pb_real
	variable PB_MODE

	log 10 "mult_get_selns called with $seln_ids"


	# only init if we have not already done so
	# in pb_start

	# If this is anon cash betting then we need to initialise placebet as such
	if {[info exists LOGIN_DETAILS(ANON_CASH_BET)] && $LOGIN_DETAILS(ANON_CASH_BET) == "Y"} {
		init_placebet [reqGetArg source]
		OT_LogWrite 4 "Initialising anonymous bet placement"
		OB_placebet::init_placebet_mode ANON $LOGIN_DETAILS(CCY_CODE) [reqGetArg term_code]
	} elseif {$pb_real == 0} {
		init_placebet [reqGetArg source]
		OB_placebet::init_placebet_mode
	}

	get_user_data    $pb_real

	if {[OB_login::ob_is_guest_user] || $PB_MODE=={ANON}} {
		set guest 1
		set get_cum_stk 0
	} else {
		set guest 0
		set get_cum_stk 1
	}
	get_seln_details $seln_ids $get_cum_stk

	if {!$guest} {

		# get the max stake scale for customer based on class ids for
		# all selections which will have been loaded after the call
		# to get_seln_details
		if {[OT_CfgGet EVENT_CLASS_STAKE_SCALE N] == "Y"} {
			calc_ev_class_limit
		}

		if {[OT_CfgGet EVENT_HIER_STAKE_SCALE N] == "Y" && $seln_ids != ""} {
			calc_cust_ev_lvl_limits
		}

	}

	if {[info exists SELNS]} {
		unset SELNS
	}
}




# ----------------------------------------------------------------------
# initialise BSEL for a particular selection key
# ----------------------------------------------------------------------

proc OB_placebet::init_sk {sk} {

	global   BSEL

	set BSEL($sk,num_bets)        0
	set BSEL($sk,num_legs)        0
	set BSEL($sk,num_selns)       0
	set BSEL($sk,tax_rate)        0
	set BSEL($sk,max_payout)      9999999
	set BSEL($sk,acc_min)         1
	set BSEL($sk,acc_max)         25
	set BSEL($sk,stk_min)         999999
	set BSEL($sk,stk_max)         999999
	set BSEL($sk,ids)             ""
	set BSEL($sk,ev_ids)          ""
	if {[OT_CfgGetTrue ALLOW_MIXED_EW_MULTIPLIERS]} {
		set BSEL($sk,ew_avail)     N
	} else {
		set BSEL($sk,ew_avail)    Y
	}

	set BSEL($sk,pl_avail)        Y
	set BSEL($sk,is_ap_mkt)       Y
	set BSEL($sk,xmul)            ""

	lappend BSEL(sks) $sk
}

# ----------------------------------------------------------------------
# add a list of selections to the BSEL array
#
# If we do not have a selection from the same event
# it is a simple matter of adding a new leg.
# Otherwise we must try to fit the selection in as
# a forecast/tricast etc.
# ----------------------------------------------------------------------


proc OB_placebet::mult_add_selns {sk seln_data} {

	global   BSEL CUST

	variable MSEL
	variable SELNS
	variable DIVS
	variable COMBI_MKTS

	log 9 "mult_add_selns for sk $sk, array is $seln_data"

	if {![info exists BSEL($sk,num_legs)]} {
		init_sk $sk
	}

	set BSEL($sk,selns_ok) 0
	set BSEL($sk,last_add_list) [list]

	if [catch {array set SELNS $seln_data} msg] {
		pb_err ERR BAD_ARRAY "Passed bad array to mult_add_selns $msg" ALL
		return ""
	}



	set ids $SELNS(ids)

	foreach id $ids {

		if {![info exists MSEL($id,ev_oc_id)]} {
			pb_err ERR NO_SELN "Selection does not exist" ALL $id
			return ""
		}

		set class_id $MSEL($id,ev_class_id)
		set type_id  $MSEL($id,ev_type_id)
		set ev_id    $MSEL($id,ev_id)
		set mkt_sort $MSEL($id,mkt_sort)

		log 15 "***********************************"
		log 15 "id now $id, ev_id $ev_id"

		set ret 0

		# Retain the accumulator restriction of the lowest level
		# ie: 'T'ype over 'C'lass over "-" or "<blank>"
		if {$BSEL($sk,xmul)=="" || $BSEL($sk,xmul)=="-" || $MSEL($id,xmul)=="T"} {
			set BSEL($sk,xmul) $MSEL($id,xmul)
		}

		log 15 "-- xmul now $BSEL($sk,xmul) ---"


		if {$BSEL($sk,xmul) == "C"} {
			for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {
				if {$BSEL($sk,$l,class_id) != $class_id} {
					set ret -1
					pb_err ERR NO_CLASS\
						"This selection can only be combined with others within this class" ALL
					break
				}
			}
		}

		if {$BSEL($sk,xmul) == "T"} {
			for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {
				if {$BSEL($sk,$l,type_id) != $type_id} {
					pb_err ERR NO_TYPE\
						"This selection can only be combined with others within this type" ALL
					set ret -1
					break
				}
			}
		}

		if {$ret == 0} {
			if {[lsearch $BSEL($sk,ev_ids) $ev_id] < 0} {
				log 15 "adding leg"
				log 15 "ev_id $ev_id, ids $BSEL($sk,ev_ids)"
				set ret [mult_add_leg $sk $id]
			} else {
				log 15 "adding leg from same event, class_id is $class_id"
				set ok_to_add 0

				set num_legs $BSEL($sk,num_legs)
				foreach {cid mkts} $COMBI_MKTS {
					log 15 "checking rules for class $cid"

					if {$cid == $class_id || $cid == "ALL"} {
						set ok_to_add 1

						foreach mkt_list $mkts {
							if {[lsearch $mkt_list $mkt_sort] >= 0} {

								for {set l 0} {$l < $num_legs} {incr l} {

									if {$BSEL($sk,$l,ev_id) != $ev_id} {
										continue
									}

									set leg_mkt_sort $BSEL($sk,$l,mkt_sort)
									if {$mkt_sort == $leg_mkt_sort} {
										set ok_to_add 0
										break
									}

									log 15 "ms1 $mkt_sort, ms2 $leg_mkt_sort, li $mkt_list"
									if {[lsearch $mkt_list $leg_mkt_sort] < 0} {
										set ok_to_add 0
										break
									}
								}
							}
							if {!$ok_to_add} break
						}
					}
				}

				if {$ok_to_add} {
					log 15 "actually adding leg"
					set ret [mult_add_leg $sk $id]
				} else {
					for {set l 0} {$l < $num_legs} {incr l} {
						if {$BSEL($sk,$l,ev_id) == $ev_id} {
							set ret [mult_add_part $sk $l $id]
							break
						}
					}
				}
			}
		}


		if {$ret == -1} {
			pb_err ERR NO_COMBI "Selection cannot be combined"\
				OC $id
		}

		if {$ret == 0} {
			incr BSEL($sk,num_selns)

			# Loop thru legs
			set num_legs $BSEL($sk,num_legs)

			for {set l 0} {$l < $num_legs} {incr l} {
				if {$BSEL($sk,$l,ev_id) == $ev_id} {

					# if there is a legsort specified for this seln
					# then we store it.
					# The validation cannot be done until later
					# as we may not have all the parts for this leg in yet
					# Validation is therefore done in validate_mult_rules

					if {[info exists SELNS(ids,$id,leg_sort)]} {
						set BSEL(ids,$id,leg_sort) $SELNS(ids,$id,leg_sort)
						set BSEL($sk,$l,leg_sort)  $SELNS(ids,$id,leg_sort)
						log 10 "setting leg sort to $BSEL(ids,$id,leg_sort)"
					} else {
						# Default to first valid leg sort
						set BSEL(ids,$id,leg_sort) [lindex $BSEL($sk,$l,valid_sorts) 0]
						set BSEL($sk,$l,leg_sort)  $BSEL(ids,$id,leg_sort)
						log 10 "setting default leg sort to $BSEL(ids,$id,leg_sort)"
					}

					# Loop thru parts
					set num_parts $BSEL($sk,$l,num_parts)

					for {set p 0} {$p < $num_parts} {incr p} {


						set pk "$sk,$l,$p"
						#
						# check the selection price data against that being
						# requested
						#
						if {[OT_CfgGetTrue TELEBET]} {
							# Check for ev_oc_variant and adjust bet
							matched_to_ev_oc_variant $id $sk $l $p
						}
						if {[info exists SELNS(ids,$id,price_type)]} {

							if {[mult_check_price_data $id $sk $l $p] != 0} {
								return [list]
							}

							set BSEL($pk,price_type) $SELNS(ids,$id,price_type)
							log 9 "set price type(BSEL($pk,price_type)) to $BSEL($pk,price_type)"
						} else {
							# Default value
							if {$BSEL($sk,$l,valid_sorts) == "--"} {
								if {$BSEL($pk,lp_avail) == "Y" &&
									$BSEL($pk,lp_num)   != "" &&
									$BSEL($pk,lp_den)   != "" } {
									set BSEL($pk,price_type) "L"
								} else {
									set BSEL($pk,price_type) "S"
								}
							} elseif {[lsearch $DIVS $BSEL($sk,$l,valid_sorts)] >= 0} {
								log 90 "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
								log 90 "setting price type D, vs $BSEL($sk,$l,valid_sorts)"
								set BSEL($pk,price_type) "D"
							} else {
								set BSEL($pk,price_type) "L"
							}

							log 7 "setting default price_type to $BSEL($pk,price_type)"
						}

						if {[info exists BSEL($pk,price_type)]} {

							set BSEL($pk,price) \
								[mk_bet_price_str $BSEL($pk,price_type)\
									 $BSEL($pk,lp_num) $BSEL($pk,lp_den)]
							log 20 "BSEL($pk,price) is $BSEL($pk,price)"
						} else {

							set BSEL($pk,price)\
								[mk_price_str \
									 $MSEL($id,lp_avail) $MSEL($id,sp_avail)\
									 $BSEL($pk,lp_num)   $BSEL($pk,lp_den)]
						}

					}

				}
			}
		}

	}

	validate_mult_rules $sk
	return [array get BSEL ids*]
}





# ----------------------------------------------------------------------
# start a new leg in the BSEL array, then call add_part to
# actually add the data for that part
# ----------------------------------------------------------------------


proc OB_placebet::mult_add_leg {sk id} {

	global BSEL

	variable MSEL
	variable SELNS


	set  l $BSEL($sk,num_legs)

	log 15 "adding leg $l to sk $sk id = $id"

	set  BSEL($sk,$l,num_parts) 0

	set  BSEL($sk,$l,ev_id)     $MSEL($id,ev_id)
	set  BSEL($sk,$l,class_id)  $MSEL($id,ev_class_id)
	set  BSEL($sk,$l,type_id)   $MSEL($id,ev_type_id)

	set  BSEL($sk,$l,mkt_sort)  $MSEL($id,mkt_sort)
	set  BSEL($sk,$l,mkt_type)  $MSEL($id,mkt_type)

	# Get the maximum bir_delay from all mkts (for mult in-running)
	set sel_bir_delay $MSEL($id,bir_delay)
	if {$MSEL($id,bir_started) != "Y"} {
		set sel_bir_delay 0
	}
	if {!([info exists BSEL(bir_delay)])} {
		set  BSEL(bir_delay) $sel_bir_delay
	} elseif {$BSEL(bir_delay) < $sel_bir_delay} {
		set  BSEL(bir_delay) $sel_bir_delay
	}

	set ret [mult_add_part $sk $l $id]

	if {$ret == 0} {

		lappend BSEL($sk,ev_ids) $MSEL($id,ev_id)


		incr BSEL($sk,num_legs)
	}

	return $ret
}






#----------------------------------------------------------------------
# create a new part in a given leg and copy all the
# data across from the MSEL array
#
# registers an error if the selection to be added is the same as any
# selections currently in the multiple
#----------------------------------------------------------------------


proc OB_placebet::mult_add_part {sk l id} {

	global   BSEL CUST

	variable MSEL
	variable DIVS
	variable SELNS
	variable GLOB
	variable pb_real

	log 15 "looking for $id in $BSEL($sk,ids)"

	if {[lsearch $BSEL($sk,ids) $id] >= 0} {

		pb_err ERR SAME_SELN "Can't have the same selection twice" \
			OC $id
		return -1
	}

	if {![info exists MSEL($id,ev_oc_id)]} {
		pb_err ERR NO_SELN "Selection not retrieved" OC $id
		return -1
	}

	#
	# check selection status
	#

	if {$MSEL($id,status) != "A"\
		&& (![OT_CfgGetTrue TELEBET] || $MSEL($id,late_bet_tol_op) == "")\
		&& (![OT_CfgGetTrue TELEBET] || $pb_real==1)} {
		#
		# If we're not actually placing a bet in telebetting,
		# we don't care if the selection is suspended because
		# this restriction may be overridden at bet placement
		#
		if {[pb_err ERR SUSP "Selection Suspended" OC $id]==1} {
			return -1
		}
	}

	if {$MSEL($id,started) != "N"\
		&& (![OT_CfgGetTrue TELEBET] || $MSEL($id,late_bet_tol_op) == "")\
		&& (![OT_CfgGetTrue TELEBET] || $pb_real==1)} {
		#
		# Same as selection suspension (see above)
		#
		if {[pb_err ERR START "Selection Started" OC $id]==1} {
			return -1
		}
	}

	#
	# selections in a multipart leg must all
	# be from the same event (market for fc/tc)
	#
	set p $BSEL($sk,$l,num_parts)

	log 15 "adding part $p to sk $sk, leg $l id = $id"

	if {$p > 0} {
		set valid_lsorts [mult_check_leg $sk $l $id]

		if {[llength $valid_lsorts] == 0} {
			pb_err ERR NO_COMBI "Selection cannot be combined"\
				OC $id
			return -1
		}

		if {![OT_CfgGetTrue TELEBET]} {
			# complex legs must be to-win
			set BSEL($sk,ew_avail) N
			set BSEL($sk,pl_avail) N
		} elseif {$MSEL($id,mkt_type) == "A"} {
			set BSEL($sk,$l,$p,is_asian_handicap) Y
		}

	} else {
		if {$MSEL($id,mkt_type) != "-"} {
			if {$MSEL($id,mkt_type) == "A"} {
				set valid_lsorts "AH"
				if {[OT_CfgGetTrue TELEBET]} {
					set BSEL($sk,$l,$p,is_asian_handicap) Y
				}
			} else {
				set valid_lsorts $MSEL($id,mkt_sort)
			}
			# complex legs must be to-win
			set BSEL($sk,ew_avail) N
			set BSEL($sk,pl_avail) N
		} else {
			set valid_lsorts "--"
		}
	}

	set BSEL($sk,$l,valid_sorts) $valid_lsorts
	log 15 "valid_leg sorts are $BSEL($sk,$l,valid_sorts)"

	foreach sort $valid_lsorts {

		set BSEL($sk,$l,$sort,num_lines) \
			[get_num_leg_lines $sort [expr {$p + 1}]]
	}

	set pk "$sk,$l,$p"

	#
	# if the leg_type has been specified, check that
	# it is legal
	#

	if {[info exists SELNS(ids,$id,leg_type)]} {
		if {$SELNS(ids,$id,leg_type) == "E" &&
			$MSEL($id,ew_avail) != "Y"} {

			pb_err ERR LEG_TYPE "Selection cannot be each way"\
				OC $id

			return -1
		}

		if {$SELNS(ids,$id,leg_type) == "P" &&
			$MSEL($id,pl_avail) != "Y"} {

			pb_err ERR NO_COMBI "Selection cannot be placed"\
				OC $id

			return -1
		}


		set BSEL(ids,$id,leg_type) $SELNS(ids,$id,leg_type)
	}


	set BSEL($sk,max_payout)\
		[min $BSEL($sk,max_payout) $MSEL($id,max_payout)]


	# Set up the following variables
	foreach f {\
				   ev_oc_id   ev_mkt_id   ev_id\
				   ev_type_id ev_class_id ev_sort\
				   mult_key   ev_mult_key mkt_sort\
				   ev_time    ev_class_sort\
				   fc_avail   tc_avail    pm_avail\
				   ew_avail   pl_avail    sp_avail gp_avail is_ap_mkt\
				   lp_avail   lp_num      lp_den   risk_info\
				   tax_rate   acc_min     acc_max\
				   fb_result  cs_home     cs_away\
				   max_payout hcap_value  hcap_steal bir_index bir_delay\
				   ew_fac_num ew_fac_den  ew_places ew_with_bet\
				   max_pot_win ew_factor  bir_started hcap_precision\
				   mkt_type max_mult_bet  } {

		set BSEL($pk,$f) $MSEL($id,$f)
	}
	# formats the handicap value to the precision required and then formats it for
	# the customer screens
	if {$BSEL($pk,hcap_value) != ""} {
		set BSEL($pk,hcap_value_fmt) [format "%0.$MSEL($id,hcap_precision)f" $BSEL($pk,hcap_value)]

	} else {
		set BSEL($pk,hcap_value_fmt) ""
	}
	set BSEL($pk,hcap_string) [format_hcap_string $BSEL($pk,mkt_sort) $BSEL($pk,mkt_type) \
		$BSEL($pk,fb_result) $BSEL($pk,hcap_value) $BSEL($pk,hcap_value_fmt)]


	# Need to XL these variables
	foreach f {\
					ev_type    class_name  type_name\
					ev_name    ev_country  ev_venue\
					mkt_name   oc_name     category} {

		set BSEL($pk,$f) [OB_mlang::XL $MSEL($id,$f)]
	}


	#
	# ew_avail must be Y for all parts
	# if ew_is to be available for the whole
	# unless MIXED_EW_MULTIPLES is set
	#
	if {[OT_CfgGetTrue ALLOW_MIXED_EW_MULTIPLIERS]} {
		if {$BSEL($pk,ew_avail)=="Y"} {
			#ew_avail only set to Y if this isn't a complex leg and
			#market is standard.
			if {$p==0 && $MSEL($id,mkt_type) == "-"} {
				set BSEL($sk,ew_avail) Y
			}
		}
	} elseif {$BSEL($pk,ew_avail) == "N"} {
		set BSEL($sk,ew_avail) N
	}

	if {[OT_CfgGet SET_EW_OFF_FOR_UNNAMED_FAV 0] == 1} {
		if {($BSEL($pk,fb_result) == 1 || $BSEL($pk,fb_result) == 2)} {
			set BSEL($sk,favourite_added) 1
		}
		# if any selection has been a favourite then disable EW
		if {[info exists BSEL($sk,favourite_added)] && $BSEL($sk,favourite_added)} {
			set BSEL($sk,ew_avail) N
		}
	}

	log 20 "BSEL($pk,ew_avail) = $BSEL($pk,ew_avail)"
	log 20 "MSEL($id,ew_avail) = $MSEL($id,ew_avail)"
	log 20 "BSEL($sk,ew_avail) = $BSEL($sk,ew_avail)"

	if {$BSEL($pk,pl_avail) == "N"} {

			set BSEL($sk,pl_avail) N
	}
	log 20 "BSEL($pk,pl_avail) = $BSEL($pk,pl_avail)"
	log 20 "MSEL($id,pl_avail) = $MSEL($id,pl_avail)"
	log 20 "BSEL($sk,pl_avail) = $BSEL($sk,pl_avail)"


	# Check we have lp or sp available
	if {(	$BSEL($pk,sp_avail)=="N" &&
		(	$BSEL($pk,lp_avail)=="N" ||
			$BSEL($pk,lp_num)=="" ||
			$BSEL($pk,lp_den)==""
		)
	)} {
		pb_err ERR NO_PRICE "No price available" OC $id
		return -1
	}

	set BSEL($pk,l_price) \
		[mk_bet_price_str L $MSEL($id,lp_num) $MSEL($id,lp_den)]
	log 20 "BSEL($pk,l_price) is $BSEL($pk,l_price)"




	#
	# keep track of the acc_min/max for these selections
	#
	set BSEL($sk,acc_min) [max $BSEL($sk,acc_min) $MSEL($id,acc_min)]
	set BSEL($sk,acc_max) [min $BSEL($sk,acc_max) $MSEL($id,acc_max)]

	set BSEL($pk,stk_min) [expr {$MSEL($id,stk_min) * $CUST(exch_rate)}]

	#
	# check if cumulative stakes have been set, won't if they weren't required
	#
	foreach cum_type {cum_stakes cum_win_lp_stk cum_win_sp_stk\
	 cum_place_lp_stk cum_place_sp_stk cum_fc_stk cum_tc_stk\
	 cum_mult_stakes} {

		if {[info exists MSEL($id,$cum_type)]} {
			set $cum_type $MSEL($id,$cum_type)
		} else {
			set $cum_type 0
		}
	}

	# to calculate the max bets for this seln and customer
	# we need to do the following:
	#
	# max bet = (channel stake scale * customer stake scale * exch_rate * max bet from DB) - cum_stakes
	#
	# first we can obtain the product (channel stake scale * customer stake scale * exch_rate)
	# as these are going to remain constant for a customer.
	# (guests have default values loaded in CUST)
	set bet_factor [expr {$CUST(chnl_max_stk_mul) * $CUST(max_stake_scale) * $CUST(exch_rate)}]

	log 5 "mult_add_part : CUST(chnl_max_stk_mul) $CUST(chnl_max_stk_mul)"
	log 5 "mult_add_part : CUST(max_stake_scale) $CUST(max_stake_scale)"
	log 5 "mult_add_part : CUST(exch_rate) $CUST(exch_rate)"
	log 5 "mult_add_part : bet_factor $bet_factor"

	if {[var_stakes_enabled $BSEL($pk,ev_class_id)]} {

		# if variable stake is enabled for class then we need to use the relevant
		# price/leg type limit and cumulative stake
		log 5 "mult_add_part : var stakes enabled for class id $BSEL($pk,ev_class_id)"
		set BSEL($pk,max_win_lp)   [expr {($bet_factor * $MSEL($id,max_win_lp)) - $cum_win_lp_stk}]
		set BSEL($pk,max_win_sp)   [expr {($bet_factor * $MSEL($id,max_win_sp)) - $cum_win_sp_stk}]
		set BSEL($pk,max_place_lp) [expr {($bet_factor * $MSEL($id,max_place_lp)) - $cum_place_lp_stk}]
		set BSEL($pk,max_place_sp) [expr {($bet_factor * $MSEL($id,max_place_sp)) - $cum_place_sp_stk}]

	} else {

		# variable stakes isn't enabled so we should just use the max_win_lp
		# limit for the selection and use total cumulative stakes
		set BSEL($pk,max_win_lp)   [expr {($bet_factor * $MSEL($id,max_win_lp)) - $cum_stakes}]
		set BSEL($pk,max_win_sp)   $BSEL($pk,max_win_lp)
		set BSEL($pk,max_place_lp) $BSEL($pk,max_win_lp)
		set BSEL($pk,max_place_sp) $BSEL($pk,max_win_lp)
	}

	# now set max bets for Each-Way leg type
	set BSEL($pk,max_ew_lp) [min $BSEL($pk,max_win_lp) $BSEL($pk,max_place_lp)]
	set BSEL($pk,max_ew_sp) [min $BSEL($pk,max_win_sp) $BSEL($pk,max_place_sp)]

	# now set max bets for FC/TC (may not be required depending on leg sort)
	set BSEL($pk,max_fc)       [expr {($bet_factor * $MSEL($id,fc_max_bet)) - $cum_fc_stk}]
	set BSEL($pk,max_tc)       [expr {($bet_factor * $MSEL($id,tc_max_bet)) - $cum_tc_stk}]

	# ensure non of the max bets have dropped below zero
	foreach type {max_win_lp max_win_sp max_place_lp max_place_sp max_ew_lp max_ew_sp max_fc max_tc} {
		set BSEL($pk,$type) [max 0 $BSEL($pk,$type)]
		log 5 "BSEL($pk,$type) $BSEL($pk,$type)"
	}

	# finally look at the bet specifics and store a global max bet based on these
	set price_type ""
	set leg_type ""
	set leg_sort ""
	if {[info exists SELNS(ids,$id,price_type)]} {
		set price_type $SELNS(ids,$id,price_type)
	}
	if {[info exists SELNS(ids,$id,leg_type)]} {
		set leg_type $SELNS(ids,$id,leg_type)
	}
	if {[info exists BSEL($sk,$l,leg_sort)]} {
		set leg_sort $BSEL($sk,$l,leg_sort)
	}

	log 5 "mult_add_part : price_type $price_type, leg_type $leg_type"

	if {$leg_sort == "SF"} {

		# forecast
		set max_win_bet $BSEL($pk,max_fc)
		# FC should really only be available with Win leg types
		set max_plc_bet $BSEL($pk,max_fc)
		set max_ew_bet $BSEL($pk,max_fc)

	} elseif {$leg_sort == "TC"} {

		# tricast
		set max_win_bet $BSEL($pk,max_tc)
		# TC should really only be available with Win leg types
		set max_plc_bet $BSEL($pk,max_tc)
		set max_ew_bet $BSEL($pk,max_tc)

	} elseif {$price_type == ""} {

		# take the lowest from the price types
		set max_win_bet [min $BSEL($pk,max_win_lp) $BSEL($pk,max_win_sp)]
		set max_plc_bet [min $BSEL($pk,max_place_lp) $BSEL($pk,max_place_sp)]
		set max_ew_bet  [min $BSEL($pk,max_ew_lp) $BSEL($pk,max_ew_sp)]

	} elseif {$price_type == "L" || $price_type == "G"} {

		set max_win_bet $BSEL($pk,max_win_lp)
		set max_plc_bet $BSEL($pk,max_place_lp)
		set max_ew_bet  $BSEL($pk,max_ew_lp)

	} else {

		set max_win_bet $BSEL($pk,max_win_sp)
		set max_plc_bet $BSEL($pk,max_place_sp)
		set max_ew_bet  $BSEL($pk,max_ew_sp)

	}

	# we store all leg type information as this can be selected dynamically
	# on the betslip
	if {[info exists BSEL($sk,max_win_bet)]} {
		set BSEL($sk,max_win_bet) [min $BSEL($sk,max_win_bet) $max_win_bet]
	} else {
		set BSEL($sk,max_win_bet) $max_win_bet
	}

	if {[info exists BSEL($sk,max_plc_bet)]} {
		set BSEL($sk,max_plc_bet) [min $BSEL($sk,max_plc_bet) $max_plc_bet]
	} else {
		set BSEL($sk,max_plc_bet) $max_plc_bet
	}

	if {[info exists BSEL($sk,max_ew_bet)]} {
		set BSEL($sk,max_ew_bet) [min $BSEL($sk,max_ew_bet) $max_ew_bet]
	} else {
		set BSEL($sk,max_ew_bet) $max_ew_bet
	}

	# now set the global max stake for the currently selected leg type
	switch -- $leg_type {

		"W" {

			set max_bet $BSEL($sk,max_win_bet)
		}

		"P" {

			set max_bet $BSEL($sk,max_plc_bet)
		}

		"E" {

			set max_bet $BSEL($sk,max_ew_bet)
		}

		default {

			# not set or not recognised, so set to lowest
			#set max_bet [min [min $BSEL($sk,max_win_bet) $BSEL($sk,max_plc_bet)] $BSEL($sk,max_ew_bet)]
			# use win as the default leg type
			set max_bet $BSEL($sk,max_win_bet)
		}
	}

	if {[info exists BSEL($sk,stk_max)]} {
		set BSEL($sk,stk_max) [min $BSEL($sk,stk_max) $max_bet]
	} else {
		set BSEL($sk,stk_max) $max_bet
	}

	# take the lowest min bet from the selections
	if {[info exists BSEL($sk,stk_min)]} {
		set BSEL($sk,stk_min) [min $BSEL($sk,stk_min) $BSEL($pk,stk_min)]
	} else {
		set BSEL($sk,stk_min) $BSEL($pk,stk_min)
	}

	# and make sure it doesn't exceed the max bet
	set BSEL($sk,stk_min) [min $BSEL($sk,stk_min) $BSEL($sk,stk_max)]

	log 5 "mult_add_part : BSEL($sk,max_win_bet) $BSEL($sk,max_win_bet)"
	log 5 "mult_add_part : BSEL($sk,max_plc_bet) $BSEL($sk,max_plc_bet)"
	log 5 "mult_add_part : BSEL($sk,max_ew_bet) $BSEL($sk,max_ew_bet)"
	log 5 "mult_add_part : BSEL($sk,stk_max) $BSEL($sk,stk_max)"
	log 5 "mult_add_part : BSEL($sk,stk_min) $BSEL($sk,stk_min)"

	#
	# Now need to look at storing info about max winnings.
	#
	if {[OT_CfgGet FUNC_MAX_WIN 0]} {

		# We also need to apply the bet_factor calculated earlier to the
		# winnings. Note currently only one value exists for max_pot_win
		# regardless of price/leg type. Also we are currently just using
		# max winnings functionality for SGL bets. If it is to be used
		# for multiples, then we also need to do some work to store a
		# global (for the sk) max_pot_win (this will most likely be the
		# lowest from all legs/parts)
		set BSEL($pk,max_pot_win) [expr {$bet_factor * $MSEL($id,max_pot_win)}]
		log 5 "mult_add_part : MSEL($id,max_pot_win) $MSEL($id,max_pot_win)"
		log 5 "mult_add_part : BSEL($pk,max_pot_win) $BSEL($pk,max_pot_win)"
	}

	if {$BSEL($pk,is_ap_mkt)=="N"} {
		set BSEL($sk,is_ap_mkt) N
	}

	incr BSEL($sk,$l,num_parts)
	lappend BSEL($sk,ids) $id

	log 9 "successfully added $id as leg $l part $p"
	set BSEL($sk,last_leg_num) $l
	set BSEL($sk,last_part_num) $p

	if {[info exists BSEL($sk,last_add_list)]} {
		lappend BSEL($sk,last_add_list) [list $l $p]
	} else {
		set BSEL($sk,last_add_list) [list [list $l $p]]
	}
	return 0
}

proc OB_placebet::init_ev_class_limit args {

	global CUST USER_ID CUST_CLASS_LIMIT
	variable MSEL

	set cust_id $USER_ID

	if {![info exists CUST_CLASS_LIMIT]} {
		if [catch {set rs [db_exec_qry pb_get_cust_ev_lvl_limit $cust_id]} msg] {
			pb_err ERR CHK_CLASS_LIMIT \
				"failed to exec class limit query: $msg" BET
			return 0
		}
		set CUST_CLASS_LIMIT [list]
		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			lappend CUST_CLASS_LIMIT [db_get_col $rs $r ev_class_id] [db_get_col $rs $r max_stake_scale]
		}
		db_close $rs
	}
}

proc OB_placebet::calc_ev_class_limit {} {

	global CUST USER_ID CUST_CLASS_LIMIT
	variable MSEL

	set cust_id $USER_ID

	if {![info exists MSEL(ev_class_id)]} {
		# No selection details have been loaded
		return 1
	}

	set ev_class_ids $MSEL(ev_class_id)
	set current_max_scale 999999

	foreach ev_class_id $ev_class_ids {
		set limit -1

		foreach {id val} $CUST_CLASS_LIMIT {
			if {$id == $ev_class_id} {
				set limit $val
				break
			}
		}

		if {$limit == -1} {
			set limit $CUST(max_stake_scale)
		}

		if {$current_max_scale > $limit} {
			set current_max_scale $limit
		}

	}

	set CUST(max_stake_scale) $current_max_scale

	return 1
}


proc OB_placebet::calc_cust_ev_lvl_limits {} {

	global   CUST
	variable MSEL
	variable CUST_EV_LVL_LIMIT

	if {[OB_login::ob_is_guest_user]} {
		#this is OK as may be from an external betslip - checks
		#are done elsewhere to make sure a guest doesn't actually bet
		return 1
	}

	# Get all max stake factors defined for customer
	load_cust_ev_lvl_limit

	set current_max_scale 999999
	foreach seln_id $MSEL(ev_oc_id) {
		# There are now 3 bet levels for specifying customer
		# stake factor i.e. EVOCGRP,TYPE & CLASS
		# EVOCGRP takes 1st priority, TYPE is 2nd priority
		# whilst CLASS is 3rd priority in deciding which
		# max scale factor will be associated with a selection.
		set priority [list]
		lappend priority EVOCGRP $MSEL($seln_id,ev_oc_grp_id)
		lappend priority TYPE $MSEL($seln_id,ev_type_id)
		lappend priority CLASS $MSEL($seln_id,ev_class_id)

		set sf_limit -1
		foreach {level id} $priority {
			# lower priority max stake scales will not alter the sf_limit
			if {[info exists CUST_EV_LVL_LIMIT($level,$id,max_stake_scale)]} {
				set sf_limit $CUST_EV_LVL_LIMIT($level,$id,max_stake_scale)
				break
			}
		}
		# If no sf_limit is set for selection default to customer
		if {$sf_limit == -1} {
			set sf_limit $CUST(max_stake_scale)
		}
		if {$current_max_scale > $sf_limit} {
			set current_max_scale $sf_limit
		}

	}

	set CUST(max_stake_scale) $current_max_scale

	return 1
}

proc OB_placebet::load_cust_ev_lvl_limit {} {

	global   USER_ID
	variable CUST_EV_LVL_LIMIT

	if {[array exists CUST_EV_LVL_LIMIT]} {
		return
	}

	# load all of the event level limits defined for customer
	if [catch {
		set rs [db_exec_qry pb_get_cust_ev_lvl_limit $USER_ID]
	} msg] {
		pb_err ERR CHK_CUST_EV_LVL_LIMIT \
			"failed to exec cust event level limit query: $msg" BET
		return
	}
	array set CUST_EV_LVL_LIMIT [list]

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set level            [db_get_col $rs $r level]
		set id               [db_get_col $rs $r id]
		set max_stake_scale  [db_get_col $rs $r max_stake_scale]
		set liab_group_id    [db_get_col $rs $r liab_group_id]

		if {$max_stake_scale != ""} {
			set CUST_EV_LVL_LIMIT($level,$id,max_stake_scale) $max_stake_scale
		}
		if {$liab_group_id != ""} {
			set CUST_EV_LVL_LIMIT($level,$id,liab_group_id)   $liab_group_id
		}
	}
	db_close $rs
}


proc OB_placebet::mult_check_price_data {id sk l p} {

	global   BSEL

	variable MSEL
	variable SELNS
	variable pb_real

	#
	# Live prices AND Guaranteed Prices.
	# Guaranteed price bets are passed the live prices and require the
	# same checks.
	#
	set BSEL(price_changed) 0
	set BSEL(hcap_changed)  0
	set BSEL(bir_idx_changed) 0
	OT_LogWrite 5 "price type is $SELNS(ids,$id,price_type)"

	# case of Unnamed favorite in a GP race.  THIS IS A HACK.
	#  it has to be without a re-write, as the GP functionality specifically bans
	#  no live price races in more than a few places
	if {$SELNS(ids,$id,price_type) == "G" && ($MSEL($id,lp_num) == "" || $MSEL($id,lp_den) == "") && ![OT_CfgGetTrue TELEBET]} {
		set SELNS(ids,$id,price_type) "S"
		set MSEL($id,sp_avail)        "Y"
		set MSEL($id,lp_avail)        "N"
		tpSetVar prc_type "S"
	}

	if {$SELNS(ids,$id,price_type) == "L" || $SELNS(ids,$id,price_type) == "G"} {

		if {![OT_CfgGetTrue TELEBET] && ($MSEL($id,lp_avail) != "Y" || $MSEL($id,lp_num) == "" || $MSEL($id,lp_den) == "")} {
			#
			# For telebetting we allow having no current live price data
			#
			if {!$pb_real && $MSEL($id,sp_avail) == "Y"} {
				# if SP is available then reset the selection to SP odds
				set BSEL(ids,$id,price_type) S
				set BSEL(ids,$id,lp_num) ""
				set BSEL(ids,$id,lp_den) ""
				set SELNS(ids,$id,price_type) S
				pb_err ERR NO_LP "Live Price not available" \
				OC $id
			} else {
				pb_err ERR NO_LP "Live Price not available" \
				OC $id
				return 1
			}
		} elseif {([OT_CfgGetTrue TELEBET] && $pb_real==1) && $MSEL($id,lp_avail) != "Y"} {

			if {[pb_err ERR NO_LP "Live Price not available" PART $sk $l $p ]==0} {

				##
				## Override on lp = no
				##
				set BSEL(ids,$id,price_type) L
				set BSEL(ids,$id,lp_num) $MSEL($id,lp_num)
				set BSEL(ids,$id,lp_den) $MSEL($id,lp_den)
			}
		} elseif {$SELNS(ids,$id,price_type) == "G" && $MSEL($id,sp_avail) != "Y"} {
			#
			# Guaranteed Price bets must also have SP enabled
			#
			pb_err ERR NO_SP "Starting Price not available." \
			OC $id
			return 1
		} else {
			##
			##  MSEL(lp_avail) must be Y, therefore no problem having this particular
			##  selection set to live price.
			##
			if { $MSEL($id,lp_avail) == "Y" } {

				set BSEL(ids,$id,price_type) L
				set BSEL(ids,$id,lp_num) $MSEL($id,lp_num)
				set BSEL(ids,$id,lp_den) $MSEL($id,lp_den)

			}
		}

		# Allow exemption due to ev_oc_variants
		#--------------------------------------
		matched_to_ev_oc_variant $id $sk $l $p

		# If available, the price token is an encrypted string containing
		# the selection price at the time it was added to the betslip.
		# We check this against the bet price here, if they are the same
		# then use that price instead of the db price.
		set validate_price 1
		if {[OT_CfgGet ENABLE_PRICE_TOKENS 0]} {

			if {[info exists SELNS(ids,$id,price_token)]} {

				OT_LogWrite INFO "Price token present, checking price"

				set price_token $SELNS(ids,$id,price_token)

				# Decrypt the token
				set dec_token [decrypt_token $price_token]
				set tlp_num   [lindex $dec_token 2]
				set tlp_den   [lindex $dec_token 3]

				OT_LogWrite INFO "Token price: lp_num = $tlp_num, lp_den = $tlp_den"

				# Get the passed in price
				set lp_num    $SELNS(ids,$id,lp_num)
				set lp_den    $SELNS(ids,$id,lp_den)

				OT_LogWrite INFO "Passed in price: lp_num = $lp_num, lp_den = $lp_den"

				if {$MSEL($id,bet_in_run) == "Y"} {
					# Always revalidate in-running prices
					OT_LogWrite INFO "Selection is in-running, always revalidate price"

				} elseif {[lindex $dec_token 0] == 0} {
					# If the token has expired then revalidate the price anyway
					OT_LogWrite INFO "Price token has expired, revalidate price"

				} elseif {$lp_num == $tlp_num && $lp_den == $tlp_den} {
					# Check the token price against the passed in price, if they
					# are the same, then set a flag so we don't revalidate the
					# price
					OT_LogWrite INFO "Prices the same, not revalidating"
					set validate_price 0
					set BSEL($sk,$l,$p,lp_num) $lp_num
					set BSEL($sk,$l,$p,lp_den) $lp_den

				} else {
					OT_LogWrite INFO "Token price differs from passed in price, revalidating"
				}
			}
		}

		# check for the live price...
		if {![info exists SELNS(ids,$id,lp_num)] || ![info exists SELNS(ids,$id,lp_den)]} {
				pb_err WARN NO_LP_SPEC "Live Price not specified" \
				OC $id
		}

		# and now check it matches what the customer has seen.
		if {($SELNS(ids,$id,lp_num) != $MSEL($id,lp_num)) || ($SELNS(ids,$id,lp_den) != $MSEL($id,lp_den))} {
			set price_changed 1
		} else {
			set price_changed 0
		}

		# If we want to validate prices, and the price is different to the DB,
		# then throw the right error here
		if {$validate_price && $price_changed} {

			# if the price has changed but the odds have lengthened
			# we can opt not to warn the customer and place the bet
			# anyway.  This is useful for Grand National and other
			# times of heavy traffic
			if {[OT_CfgGet IGNORE_PRC_CHG "N"] == "Y"} {
				if {[expr ($SELNS(ids,$id,lp_num) * $MSEL($id,lp_den)) <=\
				    ($SELNS(ids,$id,lp_den)*$MSEL($id,lp_num))]} {
					# price has lengthened or stayed the same
					set allow_change 1
				} else {
					set allow_change 0
				}
			} else {
				set allow_change 0
			}

			if {(![OT_CfgGetTrue TELEBET] && !$allow_change ) || \
				  ([OT_CfgGetTrue TELEBET] && $pb_real==1)} {

				# Ignore price change for tricast/ forcast
				set prc_chg_ignore [OT_CfgGet LEG_SORT_PRC_CHG_IGNORE [list SF RF TC CT CF]]
				if {[lsearch $prc_chg_ignore $SELNS(ids,$id,leg_sort)] < 0} {
					if {[pb_err ERR PRC_CHG "Price changed" PART $sk $l $p]==0} {
						#
						# Price override... we use the price passed in not
						# the database price
						#
						set BSEL($sk,$l,$p,lp_num) $SELNS(ids,$id,lp_num)
						set BSEL($sk,$l,$p,lp_den) $SELNS(ids,$id,lp_den)
					}
				}
			}

		}

		#
		# if we were passed a handicap value check that it
		# is valid and that this is a hcap mkt
		#
		if {[info exists SELNS(ids,$id,hcap_value)] &&
			$SELNS(ids,$id,hcap_value) != "" 
			} {
			if {$SELNS(ids,$id,hcap_value) != $MSEL($id,hcap_value)} {
				if {![OT_CfgGetTrue TELEBET] || ([OT_CfgGetTrue TELEBET] && \
					$pb_real==1)} {
					if {[pb_err ERR HCAP_CHG "Handicap changed" PART $sk $l $p]==0} {
						set BSEL(ids,$id,hcap_value) $SELNS(ids,$id,hcap_value)
						set BSEL($sk,$l,$p,hcap_value) $SELNS(ids,$id,hcap_value)
					}
				}
			}
		}

		if { ![OT_CfgGetTrue TELEBET] || ![info exists SELNS(ids,$id,hcap_value)] } {
			if {$MSEL($id,hcap_value) != ""} {
				set BSEL(ids,$id,hcap_value) $MSEL($id,hcap_value)
				set BSEL($sk,$l,$p,hcap_value) $MSEL($id,hcap_value)
			}
		}

		#
		# check the bir_index
		#

		if {[info exists SELNS(ids,$id,bir_index)]} {
			if {$SELNS(ids,$id,bir_index) != $MSEL($id,bir_index)} {
				pb_err ERR BIR_CHG "BIR changed" PART $sk $l $p
			}
		}

		if {$MSEL($id,bir_index) != ""} {
			set BSEL(ids,$id,bir_index) $MSEL($id,bir_index)
		}

		if {$MSEL($id,bir_delay) != ""} {
			set BSEL(ids,$id,bir_delay) $MSEL($id,bir_delay)
		}


	} elseif {$SELNS(ids,$id,price_type) == "S"} {
		if {$MSEL($id,sp_avail) != "Y"} {

			pb_err ERR NO_SP "Starting Price not available" \
				OC $id
			return 1
		}
	} elseif {$SELNS(ids,$id,price_type) == "D"} {
		# do nothing
		log 90 "%%%%%%% mult_check_price_data %%%%%%%%%"
		log 90 "setting price type D, vs $BSEL($sk,$l,valid_sorts)"
	} elseif {[OT_CfgGetTrue TELEBET]} {
		#
		# Telebetting only: allow Best,Next,First,Second Prices on racing
		#
		set racing 1
		if {$MSEL($id,ev_class_sort) != "GR" &&
			$MSEL($id,ev_class_sort) != "HR"} {
			set racing 0
		} else {
			set exotic_prices [OT_CfgGet EXOTIC_RACING_PRICES ""]
		}
		if {$SELNS(ids,$id,price_type) == "B"} {
			if {!$racing || [string first BP $exotic_prices] < 0} {
				pb_err ERR NO_BP "Best Price not available" \
					OC $id
				return 1
			}
		} elseif {$SELNS(ids,$id,price_type) == "1"} {
			if {!$racing || [string first FS $exotic_prices] < 0} {
				pb_err ERR NO_FS "First Show not available" \
					OC $id
				return 1
			}
		} elseif {$SELNS(ids,$id,price_type) == "2"} {
			if {!$racing || [string first SS $exotic_prices] < 0} {
				pb_err ERR NO_SS "Second Show not available" \
					OC $id
				return 1
			}
		} elseif {$SELNS(ids,$id,price_type) == "N"} {
			if {!$racing || [string first NP $exotic_prices] < 0} {
				pb_err ERR NO_NP "Next Price not available" \
					OC $id
				return 1
			}
		} else {
			pb_err ERR BAD_PRC "Invalid price type -$SELNS(ids,$id,price_type)-" OC $id
			unset SELNS(ids,$id,price_type)
			return 0
		}
	} else {
		pb_err ERR BAD_PRC "Invalid price type -$SELNS(ids,$id,price_type)-" \
			OC $id
		unset SELNS(ids,$id,price_type)

		return 1
	}

	set BSEL(ids,$id,price_type) $SELNS(ids,$id,price_type)
	return 0
}
########################################################
proc OB_placebet::matched_to_ev_oc_variant {id sk l p} {
########################################################
#------------------------------------------------------------------
# Check if the provided price/hcap can be matched by an EvOcVariant
# - If so, also check max_bet for the variant and override selections
#   normal max_bet.
#------------------------------------------------------------------

	global   BSEL
	variable SELNS
	variable MSEL
	global   CUST

	if {[OT_CfgGet ENABLE_OC_VARIANTS 0] == 1 && \
			$MSEL($id,has_oc_variants) == "Y" && \
			$BSEL($sk,$l,$p,ev_oc_id) == $id} {
		ob::log::write DEBUG {PB : matched_to_ev_oc_variant ==>}
		set hcap_changed 0
		set prc_changed  0

		if {[info exists SELNS(ids,$id,hcap_value)] &&
		    $SELNS(ids,$id,hcap_value) != $MSEL($id,hcap_value)} {
			set hcap_changed 1
		}

		if {[info exists SELNS(ids,$id,lp_num)] && [info exists SELNS(ids,$id,lp_den)]} {
			if {($SELNS(ids,$id,lp_num) != $MSEL($id,lp_num)) ||
			    ($SELNS(ids,$id,lp_den) != $MSEL($id,lp_den))} {
				set prc_changed 1
			}
		}

		set variant_override 0
		if {$hcap_changed == 0 && $prc_changed == 0} { return }

		if {[catch {
			set rs [db_exec_qry pb_check_evocvariant_prc_hcap $MSEL($id,ev_oc_id) \
			                                                  $SELNS(ids,$id,hcap_value) \
			                                                  $SELNS(ids,$id,lp_num) \
			                                                  $SELNS(ids,$id,lp_den)]
		} msg]} {
			ob::log::write INFO {error : pb_check_evocvariant_prc_hcap failed : $msg}
			return
		}

		set max_bet ""

		if {[db_get_nrows $rs] > 0} {
			set prc_num        $SELNS(ids,$id,lp_num)
			set prc_den        $SELNS(ids,$id,lp_den)
			set hcap_value     $SELNS(ids,$id,hcap_value)

			catch {db_close $rs}

			# get the max_bet info
			if {[catch {
				set rs [db_exec_qry pb_get_evocvariant_prc_hcap $MSEL($id,ev_oc_id) \
				                                                $SELNS(ids,$id,hcap_value)]
			} msg]} {
					ob::log::write INFO {error : pb_get_evocvariant_prc_hcap failed : $msg}
			}

			if {[db_get_nrows $rs] > 0} {
				set max_bet [db_get_col $rs 0 max_bet]
			}

			set variant_override 1
			catch {db_close $rs}

		} elseif {$hcap_changed} {
			catch {db_close $rs}

			if {[catch {
				set rs [db_exec_qry pb_get_evocvariant_prc_hcap $MSEL($id,ev_oc_id) \
				                                                $SELNS(ids,$id,hcap_value)]
				} msg]} {
				ob::log::write INFO {error : pb_get_evocvariant_prc_hcap failed : $msg}
			}

			if {[db_get_nrows $rs] > 0} {
				set prc_num    [db_get_col $rs 0 price_num]
				set prc_den    [db_get_col $rs 0 price_den]
				set max_bet	   [db_get_col $rs 0 max_bet]

				set hcap_value $SELNS(ids,$id,hcap_value)
				set variant_override 1

				if {[db_get_col $rs 0 apply_price] == "R"} {
					set prc_num    [expr {$prc_num * $MSEL(ids,$id,lp_num)}]
					set prc_den    [expr {$prc_den * $MSEL(ids,$id,lp_den)}]
				}
			}
			catch {db_close $rs}
		}

		# ------------------------------------

		if {$variant_override} {
			set BSEL($sk,$l,$p,lp_num)         $prc_num
			set BSEL($sk,$l,$p,lp_den)         $prc_den
			set BSEL($sk,$l,$p,hcap_value)     $hcap_value

			#
			# check if cumulative stakes have been set, won't if they weren't required
			#
			foreach cum_type {cum_stakes cum_win_lp cum_win_sp cum_place_lp cum_place_sp} {

				if {[info exists MSEL($id,$cum_type)]} {
					set $cum_type $MSEL($id,$cum_type)
					ob::log::write DEBUG {matched_to_ev_oc_variant : $cum_type $MSEL($id,$cum_type)}
				} else {
					set $cum_type 0
					ob::log::write DEBUG {matched_to_ev_oc_variant : $cum_type 0}
				}
			}

			set bet_factor [expr {$CUST(chnl_max_stk_mul) * $CUST(max_stake_scale) * $CUST(exch_rate)}]

			ob::log::write DEBUG {matched_to_ev_oc_variant : $CUST(chnl_max_stk_mul) * $CUST(max_stake_scale) * $CUST(exch_rate) = $bet_factor}

			ob::log::write DEBUG {matched_to_ev_oc_variant : max_bet $max_bet}

			# Override max_bet with variant value if required
			if {$max_bet != ""} {
				# Call 25996 - set the max win, place and ew bet
				# and everything else relevant
				# because the variant always overrides these

				set mb [expr {($bet_factor * $max_bet) - $cum_stakes}]

				ob::log::write INFO {matched_to_ev_oc_variant : mb $mb}

				foreach var [list max_bet stk_max max_win_bet max_plc_bet max_ew_bet max_win_lp max_win_sp max_place_lp max_place_sp max_ew_lp max_ew_sp] {
					set BSEL($sk,$var)          $mb
					set BSEL($sk,bets,$p,$var)  $mb
					set BSEL($sk,$l,$p,$var)    $mb
				}
				set MSEL($id,stk_max)          $mb
				set MSEL(stk_max)              $mb

				# variable stakes means we might have some slightly different maxes...
				if {[var_stakes_enabled $BSEL($sk,$l,$p,ev_class_id)]} {

					# if variable stake is enabled for class then we need to use the relevant
					# price/leg type limit and cumulative stake
					ob::log::write DEBUG {matched_to_ev_oc_variant: var stakes enabled for class id $BSEL($sk,$l,$p,ev_class_id)}

					if {[OT_CfgGet CUM_STAKES_BY_LEG_TYPE 0] == 1} {

						ob::log::write DEBUG {matched_to_ev_oc_variant : CUM_STAKES_BY_LEG_TYPE}

						# make cumulative stakes independent of price type
						set cum_win   [expr {$cum_win_lp   + $cum_win_sp}]
						set cum_place [expr {$cum_place_lp + $cum_place_sp}]


						ob::log::write DEBUG {matched_to_ev_oc_variant : cumulative win   stakes $cum_win}
						ob::log::write DEBUG {matched_to_ev_oc_variant : cumulative place stakes $cum_place}

						set BSEL($sk,$l,$p,max_win_lp)   [expr {($bet_factor * $max_bet)   - $cum_win}]
						set BSEL($sk,$l,$p,max_win_sp)   [expr {($bet_factor * $max_bet)   - $cum_win}]
						set BSEL($sk,$l,$p,max_place_lp) [expr {($bet_factor * $max_bet)   - $cum_place}]
						set BSEL($sk,$l,$p,max_place_sp) [expr {($bet_factor * $max_bet)   - $cum_place}]

					} else {

						# keep cumulative stakes separated by leg and price type
						set BSEL($sk,$l,$p,max_win_lp)   [expr {($bet_factor * $max_bet) - $cum_win_lp}]
						set BSEL($sk,$l,$p,max_win_sp)   [expr {($bet_factor * $max_bet) - $cum_win_sp}]
						set BSEL($sk,$l,$p,max_place_lp) [expr {($bet_factor * $max_bet) - $cum_place_lp}]
						set BSEL($sk,$l,$p,max_place_sp) [expr {($bet_factor * $max_bet) - $cum_place_sp}]
					}

				}
			}
			set MSEL($id,lp_num)               $prc_num
			set MSEL($id,lp_den)               $prc_den
			set MSEL($id,hcap_value)           $hcap_value
			set BSEL(ids,$id,lp_num)           $prc_num
			set BSEL(ids,$id,lp_den)           $prc_den
			set BSEL(ids,$id,hcap_value)       $hcap_value
			set BSEL($sk,$l,$p,hcap_value_fmt) [format "%0.$MSEL($id,hcap_precision)f" $BSEL($sk,$l,$p,hcap_value)]
			set BSEL($sk,$l,$p,hcap_string)    [format_hcap_string $BSEL($sk,$l,$p,mkt_sort) \
			                                                       $BSEL($sk,$l,$p,mkt_type) \
			                                                       $BSEL($sk,$l,$p,fb_result) \
			                                                       $BSEL($sk,$l,$p,hcap_value) \
			                                                       $BSEL($sk,$l,$p,hcap_value_fmt)]
		}
	}
	ob::log::write DEBUG {PB: matched_to_ev_oc_variant <==}
}







#----------------------------------------------------------------------
# before adding a new part to a leg, this function checks that
# the parts can be combined together to make a FC/TC etc.
#
# It returns a list of the valid leg_sorts
#----------------------------------------------------------------------


proc OB_placebet::mult_check_leg {sk l id} {

	global   BSEL
	variable MSEL

	set num_parts [expr {$BSEL($sk,$l,num_parts) + 1}]

	set lsorts ""

	if {[OT_CfgGetTrue NO_COMPLEX_LEGS]} {
		return ""
	}

	if {[OT_CfgGetTrue TELEBET]} {
		#
		# For telebetting provide leg sort of '--', signifying
		# the option to separate parts of a leg, e.g. two selections
		# from the same race which normally form a straight forecast
		# can optionally be placed as two separate singles
		#
		lappend lsorts "--"
	}

	# fc/tc are all in the same market
	if {$BSEL($sk,$l,0,ev_mkt_id) == $MSEL($id,ev_mkt_id)} {

		# Complex legs not available for unnamed favourites

		# if selection is from horse or greyhound racing check previous parts first for unnamed favourites
		set unnamed_fav_present 0
		set racing 0
		set named_runner_present 0

		if {$MSEL($id,ev_class_sort) == "GR" ||
			$MSEL($id,ev_class_sort) == "HR"} {

			set racing 1
			for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {
				if {$BSEL($sk,$l,$p,fb_result) != "-"} {
					set unnamed_fav_present 1
					break
				} else {
					set named_runner_present 1
				}
			}
		}

		if {($MSEL($id,fb_result) == "-") && (!($unnamed_fav_present)) } {

			if {$num_parts == 2} {
				if {$MSEL($id,fc_avail) == "Y"} {
					lappend lsorts SF RF
				}

			} elseif {$num_parts == 3 } {

				if {$MSEL($id,fc_avail) == "Y"} {
					lappend lsorts CF
				}

				if {$MSEL($id,tc_avail) == "Y"} {
					lappend lsorts TC CT
				}

			} elseif {$num_parts > 3} {

				if {$MSEL($id,fc_avail) == "Y"} {
					lappend lsorts CF
				}

				if {$MSEL($id,tc_avail) == "Y"} {
					lappend lsorts  CT
				}
			}
		} else {
			if {$racing} {
				set unnamed_fav 0
				if {[OT_CfgGet ALLOW_FIRST_TWO_UNNAMED_FAV 0]} {
				# If ALLOW_FIRST_TWO_UNNAMED_FAV is set, check if the selection is unnamed fav or 2nd unnamed fav,
				# if yes then add to the betslip if not, pop up a message that the selection cant be added to slip.
					if {($MSEL($id,fb_result) != 1) && ($MSEL($id,fb_result) != 2)} {
						set unnamed_fav 1
					} elseif {$named_runner_present == 1} {
						set unnamed_fav 1
					}
				} else {
					set unnamed_fav 1
				}
				if {$unnamed_fav} {
					pb_err ERR NO_COMBI_UNFAV "Selection cannot be combined due to unnamed favourite"\
					OC $id
				}
			}
		}
	} elseif {$BSEL($sk,$l,ev_id) == $MSEL($id,ev_id)} {

		if {$num_parts == 2} {
			set id0 $BSEL($sk,$l,0,ev_oc_id)
			if {[validate_scorecast(tm)_leg $sk $l $id0 $id] == 0} {
				set lsorts [linsert $lsorts 0 SC]
			}
		}
	}

	return $lsorts
}



proc OB_placebet::get_num_leg_lines {sort num_parts} {

	if {$sort == "RF" ||
		$sort == "CF"} {
		return [expr {$num_parts * ($num_parts - 1)}]
	} elseif {$sort == "CT"} {
		return [expr {$num_parts * ($num_parts - 1) * ($num_parts - 2)}]
	} else {
		return 1
	}
}



#----------------------------------------------------------------------
# only validate simple single selection legs here
# all others are passed on to validate_complex_leg
#----------------------------------------------------------------------

proc OB_placebet::validate_leg {b sk l} {

	global BSEL PB_ERRORS

	variable LEG_SORTS_TXT
	if {![info exists BSEL($sk,$l,leg_sort)]} {
		if {[llength $BSEL($sk,$l,valid_sorts)] == 1} {
			set BSEL($sk,$l,leg_sort) $BSEL($sk,$l,valid_sorts)
		} else {
			pb_err ERR NO_LEG_SORT \
				"No Leg sort specified and unable to guess"\
				SELN $sk $l
			return
		}
	}

	if {![info exists BSEL($sk,$l,0,price_type)]} {
		pb_err SELN PRC_TYPE "No price type specified." $sk $l 0
	}

	if {$BSEL($sk,$l,num_parts) > 1} {

		# can't have ew or placed bets with
		# complex legs

		set BSEL($sk,ew_avail) N
		set BSEL($sk,pl_avail) N

		validate_complex_leg $b $sk $l

	}

	set BSEL($sk,$l,leg_sort_desc) [OB_mlang::XL $LEG_SORTS_TXT($BSEL($sk,$l,leg_sort))]

	if {$PB_ERRORS(num_err) > 0} {
		return
	}


	#
	# if this is a handicap type leg then
	# we must have a handicap value set
	#

	if {[lsearch {A H U} $BSEL($sk,$l,mkt_type)] >= 0 &&
		$BSEL($sk,$l,0,hcap_value) == ""} {
		pb_err ERR NO_HCAP "Handicap not specified in hcap mkt" SELN $sk $l
	}

	#check that a BIR index is set for a bir market
	if {[lsearch {N} $BSEL($sk,$l,mkt_type)] >= 0 &&
		$BSEL($sk,$l,0,bir_index) == ""} {
		pb_err ERR NO_BIR "BIR phase not specified" SELN $sk $l
	}

	log 9 "Leg validation completed OK"
}





#----------------------------------------------------------------------
# complex legs with more than 1 part will be validated against
# the database.
#
# a list af valid leg sorts for the selections is stored in the array
#----------------------------------------------------------------------

proc OB_placebet::validate_complex_leg {b sk l} {

	global BSEL

	variable MSEL

	set num_parts $BSEL($sk,$l,num_parts)

	if {![info exists BSEL($sk,$l,leg_sort)]} {
		pb_err ERR NO_LT "Leg type not specified" SELN $sk $l
		return
	}

	#
	# check the availability of the requested leg_type
	# propagate any special stake limits down
	#

	set leg_sort $BSEL($sk,$l,leg_sort)


	if {[lsearch {SF RF CF} $leg_sort ] >= 0} {

		if {$BSEL($sk,$l,0,fc_avail) == "N"} {
			pb_err ERR NO_FC\
				"Forecasts not available"\
				SELN $b $l
			return
		}

		set id $BSEL($sk,$l,0,ev_oc_id)

	} elseif {[lsearch {TC CT} $leg_sort] >= 0} {
		if {$BSEL($sk,$l,0,tc_avail) == "N"} {
			pb_err ERR NO_TRC\
				"Tricasts not available"\
				SELN $b $l
			return
		}
		set id $BSEL($sk,$l,0,ev_oc_id)

	} elseif {$leg_sort == "SC"} {
		validate_scorecast(tm)_leg $sk $l \
			$BSEL($sk,$l,0,ev_oc_id)\
			$BSEL($sk,$l,1,ev_oc_id)
	} else {
		pb_err ERR LEG_SORT\
			"Unknown leg sort $leg_sort"\
			SELN $b $l

		return
	}




	#
	# check that we have the number of parts we
	# were expecting for this selection type
	#
	set errstr "wrong number of parts for this seln sort"

	if {($leg_sort == "SF" ||
		 $leg_sort == "SC" ||
		 $leg_sort == "RF") &&
		$num_parts != 2} {
		pb_err ERR LEG_SORT "$errstr, $leg_sort, $num_parts"\
			SELN $b $l
		return
	} elseif {$leg_sort == "CF" && $num_parts < 2} {
		pb_err ERR LEG_SORT "$errstr CF" SELN $b $l
		return
	} elseif {$leg_sort == "TC" && $num_parts != 3} {
		pb_err ERR LEG_SORT "$errstr TC" SELN $b $l
		return
	} elseif {$leg_sort == "CT" && $num_parts < 3} {
		pb_err ERR LEG_SORT "$errstr CT" SELN $b $l
		return
	}


	#
	# forecasts and tricast legs have all parts from the same market
	# scorecasts must be from the same event
	#
	set errstr "$leg_sort selns must be in the same"
	switch -- $leg_sort {
		SF -
		RF -
		CF -
		CT  {
			set mkt_id $MSEL($BSEL($sk,$l,0,ev_oc_id),ev_mkt_id)
			for {set i 1} {$i < $num_parts} {incr i} {
				set id $BSEL($sk,$l,$i,ev_oc_id)
				if {$mkt_id != $MSEL($id,ev_mkt_id)} {

					pb_err ERR MKT_ID "$errstr market"\
						SELN $b $l
					return
				}
				if {$BSEL($sk,$l,$i,fb_result) != "-"} {
					pb_err ERR FB_RES "$leg_sort selns must be named runners"\
						 SELN $b $l
					return
				}
			}
		}

		SC {
			set id1 $BSEL($sk,$l,0,ev_oc_id)
			set id2 $BSEL($sk,$l,1,ev_oc_id)

			if {$MSEL($id1,ev_id) != $MSEL($id2,ev_id)} {
				pb_err ERR EV_ID "$errstr event" SELN $b $l
				return
			}
		}
	}


	#
	# calculate the number of lines that this bet leg has
	#
	if {$leg_sort == "RF" ||
		$leg_sort == "CF"} {
		set BSEL($sk,$l,num_lines) \
			[expr {$num_parts * ($num_parts - 1)}]
	} elseif {$leg_sort == "CT"} {
		set BSEL($sk,$l,num_lines) \
			[expr {$num_parts * ($num_parts - 1)* ($num_parts - 2)}]
	} else {
		set BSEL($sk,$l,num_lines) 1
	}

}






#----------------------------------------------------------------------
# validate a scorecast leg, this is called in addition to
# validate_complex_leg for scorecast legs
#----------------------------------------------------------------------

proc OB_placebet::validate_scorecast(tm)_leg {sk l ev_oc_id1 ev_oc_id2} {

	global   BSEL
	variable MSEL
	variable sc_price_func

	if {[get_sc_status $BSEL($sk,$l,ev_id)] == "S"} {
		if {![OT_CfgGetTrue TELEBET]} {
			#
			# For telebetting, don't throw error so that even though
			# the selections cannot be combined, they can still
			# be placed as separate single bets
			#
			pb_err ERR SC_SUSP "Scorecast not available" SELN $sk $l
			return 1
		} else {
			return -1
		}
	}


	set ls1 $MSEL($ev_oc_id1,mkt_sort)
	set ls2 $MSEL($ev_oc_id2,mkt_sort)

	set sc_type ""

	if {$ls1 == "CS" && $ls2 == "FS"} {
		set cs_id  $ev_oc_id1
		set fs_id  $ev_oc_id2
	} elseif {$ls1 == "FS" && $ls2 == "CS"} {
		set cs_id  $ev_oc_id2
		set fs_id  $ev_oc_id1
	} elseif {![OT_CfgGetTrue TELEBET]} {
		#
		# Same reason as above
		#
		pb_err ERR SC_LEG_MKTS "Need one Correct Score and one First Scorer selection in a scorecast" SELN $sk $l
		return 1
	} else {
		return -1
	}


	set fs_num    $MSEL($fs_id,lp_num)
	set fs_den    $MSEL($fs_id,lp_den)
	set cs_num    $MSEL($cs_id,lp_num)
	set cs_den    $MSEL($cs_id,lp_den)
	set fs_result $MSEL($fs_id,fb_result)
	set cs_home   $MSEL($cs_id,cs_home)
	set cs_away   $MSEL($cs_id,cs_away)



	if {$cs_home > $cs_away} {
		set cs_result H
	} elseif {$cs_home < $cs_away} {
		set cs_result A
	} else {
		set cs_result D
	}

	if {[OT_CfgGet SCORECAST_NO_GOALSCORER 1]==0} {
		if {($fs_result == "H" && $cs_home==0) || ($fs_result=="A" && $cs_away==0)} {
			if {![OT_CfgGetTrue TELEBET]} {
				#
				# Same reason as above
				#
				pb_err ERR SC_IMPOSSIBLE "This scorecast combination is impossible" SELN $sk $l
				return 1
			} else {
				return -1
			}
		}
	}

	if {$fs_result == "H"} {

		switch -- $cs_result {
			"H" {set sc_type "W"}
			"D" {set sc_type "D"}
			"A" {set sc_type "L"}
			"S" {
				if {$cs_home > $cs_away} {
					set sc_type W
				} elseif {$cs_home == $cs_away} {
					set sc_type D
				} elseif {$cs_home < $cs_away} {
					set sc_type L
				}
			}
			default {
				if {![OT_CfgGetTrue TELEBET]} {
					pb_err ERR SC_FBFLAGS "Football Flags set incorrectly for Correct Score Selection ($cs_id)" SELN $sk $l
					return 1
				} else {
					return -1
				}
			}
		}

	} elseif {$fs_result == "A"} {

		switch -- $cs_result {
			"H" {set sc_type "L"}
			"D" {set sc_type "D"}
			"A" {set sc_type "W"}
			"S" {
				if {$cs_home > $cs_away} {
					set sc_type L
				} elseif {$cs_home == $cs_away} {
					set sc_type D
				} elseif {$cs_home < $cs_away} {
					set sc_type W
				}
			}
			default {
				pb_err ERR SC_FBFLAGS "Football Flags set incorrectly for Correct Score Selection ($cs_id)" SELN $sk $l
				return 1
			}
		}

	} elseif {$fs_result == "-"} {

		pb_err ERR SC_FBFLAGS "Football Flags set incorrectly for First Scorer Selection ($fs_id)" SELN $sk $l
		return 1

	} else {

		pb_err ERR SC_FBFLAGS "Football Flags set incorrectly" \
			SELN $sk $l
		return 1
	}


	set mr_prc [get_mr_price_for_sc  $MSEL($ev_oc_id1,ev_id) $cs_result]
	set mr_num [lindex $mr_prc 0]
	set mr_den [lindex $mr_prc 1]


	# Littlewoods and willhill are a slight exception to the rule
	set exception [list "lwd_sc_price_func" "wh_scorecast::get_fscs_price"]
	if {[lsearch $exception $sc_price_func] < 0 } {
		# Normal
		set prc_func [subst {$sc_price_func\
								 $sc_type\
								 $cs_num\
								 $cs_den\
								 $fs_num\
								 $fs_den\
								 $mr_num\
								 $mr_den}]
	} else {
		# Littlewoods and willhill
		set prc_func [subst {{$sc_price_func}\
								 {$sc_type}\
								 {$cs_num}\
								 {$cs_den}\
								 {$fs_num}\
								 {$fs_den}\
								 {$mr_num}\
								 {$mr_den}\
								 {$fs_result}\
								 {$cs_home}\
								 {$cs_away}}]
	}

	if [catch {set sc_prc [eval $prc_func]} msg] {
		pb_err ERR SCPRC_SQL "Error getting SC price: $msg" SYS
		return 1
	}

	set num   [lindex $sc_prc 0]
	set den   [lindex $sc_prc 1]
	set price [mk_bet_price_str L $num $den]

	set BSEL($sk,$l,0,price_type) L
	set BSEL($sk,$l,1,price_type) L
	set BSEL($sk,$l,0,lp_num)     $num
	set BSEL($sk,$l,1,lp_num)     $num
	set BSEL($sk,$l,0,lp_den)     $den
	set BSEL($sk,$l,1,lp_den)     $den
	set BSEL($sk,$l,0,price)      $price
	set BSEL($sk,$l,1,price)      $price

	return 0
}





#---------------------------------------------------------
# return the status of the scorecast market for a given
# event_id, if no such market exists 'S' is returned
#---------------------------------------------------------

proc OB_placebet::get_sc_status ev_id {

	variable LEG_SORTS_TXT
	set retval "S"

	if {[catch {set rs [db_exec_qry pb_get_sc_status $ev_id]} msg]} {
		pb_err ERR SCSTATUS_SQL "failed to exec qry: $msg:\n$qry" SYS
	} else {
		if {[db_get_nrows $rs] == 1} {
			set retval [db_get_col $rs status]

			# this doesn't really belong here
			# but we need to retrieve the name of the
			# sc market

			set LEG_SORTS_TXT(SC) [db_get_col $rs name]

		}
		db_close $rs
	}
	return $retval
}

# ----------------------------------------------------------------------
# the default function for generating scorecast prices
# ----------------------------------------------------------------------

proc OB_placebet::default_sc_price_func {type cs_num cs_den fs_num fs_den args} {

	if [catch {set rs [db_exec_qry pb_get_sc_price \
						   $type\
						   $cs_num\
						   $cs_den\
						   $fs_num\
						   $fs_den]} msg] {
		pb_err ERR SCPRC_SQL "Error getting SC price: $msg" SYS
		return ""
	}

	set ret ""
	if {[db_get_nrows $rs] != 1} {
		pb_err ERR SCPRC_SQL "Error getting SC price" SYS
	} else {
		lappend ret [db_get_coln $rs 0] [db_get_coln $rs 1]
	}
	db_close $rs

	return $ret
}


# ----------------------------------------------------------------------
# retrive the price for the appropriate MR selection
# for generating SC prices
# ----------------------------------------------------------------------

proc OB_placebet::get_mr_price_for_sc {ev_id res} {

	if [catch {set rs [db_exec_qry pb_get_mr_prc_for_sc $ev_id $res]} msg] {
		pb_err ERR MRPRC_SQL "Error getting MR price: $msg" SYS
		return ""
	}

	set ret ""
	if {[db_get_nrows $rs] != 1} {
		pb_err ERR SCPRC_SQL "Error getting MR price" SYS
	} else {
		lappend ret [db_get_coln $rs 0] [db_get_coln $rs 1]
	}
	db_close $rs

	return $ret
}


# ----------------------------------------------------------------------
# change the function used to generate scorecast prices
# ----------------------------------------------------------------------

proc OB_placebet::pb_set_sc_price_func {func} {
	variable sc_price_func

	set sc_price_func $func
}




#---------------------------------------------------------------
# validate the selections against combination rules
#
# This procedure does not actually validate the selections
# against any particular bet type, it therefore takes a
# selection key and not a betid as parameter
#
# It determines if these selections can be combined together and
# any limits that are imposed if they are.
#---------------------------------------------------------------

proc OB_placebet::validate_mult_rules {sk} {

	global   BSEL CUST
	variable DIVS
	variable LEG_SORTS_TXT
	variable pb_real


	set SGL_LEGS {TC CT SC}
	set TBL_LEGS {SF RF CF}

	log 9 "Validating multiple rules for sk $sk"

	array set EV_IDS [list]
	array set TSORTS [list]
	set num_legs $BSEL($sk,num_legs)
	set BSEL($sk,drw_cnt) 0
	set BSEL(ids) ""
	set bad 0
	for {set l 0} {$l < $num_legs} {incr l} {

		#
		# if a leg sort has been specified
		# we update the sk acc_max to
		# to reflect any effect that this has
		#
		set lsort "--"

		# Cf call 39716 et al related.
		# Sometimes we want to override the given leg_sort, (eg default '--'
		# becomes an 'AH' sort). This is an artefact of misimplementation and/or
		# bad design - but we're stuck with it.
		# We refine the circumstances under which this over-riding takes place
		# as problems arise. So this now occurs iff (there is no leg sort, or
		# the leg sort is not a forecast-type one) and there is only one
		# valid sort available.
		if {![info exists BSEL($sk,$l,leg_sort)] || [lsearch [list SF RF CF TC CT] $BSEL($sk,$l,leg_sort)] == -1} {
			if {[llength $BSEL($sk,$l,valid_sorts)] == 1} {
				set BSEL($sk,$l,leg_sort) $BSEL($sk,$l,valid_sorts)
			}
		}

		if {[info exists BSEL($sk,$l,leg_sort)]} {
			set lsort $BSEL($sk,$l,leg_sort)
			set BSEL($sk,$l,leg_sort_desc) [OB_mlang::XL $LEG_SORTS_TXT($lsort)]

			if {[lsearch $SGL_LEGS $lsort] >= 0} {
				set BSEL($sk,acc_max) 1
			} elseif {[lsearch $TBL_LEGS $lsort] >= 0} {
				set BSEL($sk,acc_max) [min $BSEL($sk,acc_max) 3]
			}

		}

		#
		# if we have a multiple leg bet we must
		# remove any leg_sorts which are not permitted... but
		# telebetting does its own thing
		#
		if {(![OT_CfgGetTrue TELEBET]) && ($num_legs > 1)} {

			if {$num_legs > 15} {
				set BAD_LEGS [OT_CfgGet MULTRULES_GT15_BADLEGS [concat $SGL_LEGS $TBL_LEGS]]
			} elseif {$num_legs > 3} {
				set BAD_LEGS [OT_CfgGet MULTRULES_GT3_BADLEGS [concat $SGL_LEGS $TBL_LEGS]]
			} elseif {$num_legs > 1} {
				set BAD_LEGS [OT_CfgGet MULTRULES_GT1_BADLEGS $SGL_LEGS]
			}

			set valid_legs ""
			set found_bad_legs ""

			foreach ls $BSEL($sk,$l,valid_sorts) {
				if {[lsearch $BAD_LEGS $ls] == -1} {
					lappend valid_legs $ls
				} else {
					lappend found_bad_legs $ls
				}
			}

			if {$found_bad_legs != ""} {
				log 10 "bad legs $found_bad_legs removed as no.legs=$num_legs"
				if {[OT_CfgGet CUSTOMER none] == "littlewoods"} {
					pb_err ERR BAD_LEGS "These legs cannot be combined." ALL
					incr bad
					continue
				}
			}

			set BSEL($sk,$l,valid_sorts) $valid_legs

		}

		set num_parts $BSEL($sk,$l,num_parts)

		if {($num_parts == 1) || ([string first $lsort "SC/--/AH/A2/WH/OU/HL/hl/CW"]>=0)} {

		  if {[OT_CfgGet USE_CUST_SORT_TAX 0]} {
				#
				# Using cust sort tax
				#
				set BSEL($sk,tax_rate) $CUST(tax_rate)
		  } else {

			#
			# For Telebetting, always need to know the tax rate in case the
			# parts of a tax-free leg get split up
			#
			set tax_rate $BSEL($sk,$l,0,tax_rate)
			if {$tax_rate==""} {
				#
				# If tax rate is not specified in event hierarchy
				# or if required explicitly,
				# use tax rate from tControl/tChannel/tCustomerSort
				# hierarachy
				#
				set tax_rate $CUST(tax_rate)
			}

			set BSEL($sk,tax_rate) \
				[max $BSEL($sk,tax_rate) $tax_rate]

		  }

		} else {
			log 5 "Not setting sk,tax_rate still $BSEL($sk,tax_rate)"
		}

		for {set p 0} {$p < $num_parts} {incr p} {

			# set up a part key short cut
			set pk "$sk,$l,$p"




			# 1.
			# if two selections are from the same event then:
			# - they must be in the same leg
			# - they must be in a special leg (checked elswhere)
			#

			#
			# removed this check as it done when adding the legs
			#




			# 2.
			# Selections from the same event must all be
			# of type MTCH
			#

			set    errstr "Cannot combine the outright winner of a tournament"
			append errstr " with any other selection from the same event"

			set type_id $BSEL($pk,ev_type_id)
			if {[info exists TSORTS($type_id)]} {
				if {($TSORTS($type_id)  == "TNMT"
					|| $BSEL($pk,ev_sort) == "TNMT")
					&& (![OT_CfgGetTrue TELEBET] || $pb_real==1)} {

					pb_err ERR TNMT $errstr PART $sk $l $p
					incr bad
					continue
				} elseif {$TSORTS($type_id) != $BSEL($pk,ev_sort)} {

					pb_err ERR NO_COMBI "Selections cannot be combined"\
						PART $sk $l $p
					incr bad
					continue

				}

			} else {
				set TSORTS($type_id) $BSEL($pk,ev_sort)
			}




			# 3.
			# No two selections with the same mult_key
			# unless they are in the same leg of a sc/fc/tc...
			#

			set mult_key $BSEL($pk,mult_key)
			if {[info exists MULT_KEYS(s,$mult_key)]} {
				if {$l != $MULT_KEYS(s,$mult_key)} {
					pb_err ERR MULT_KEY \
						"selections can't be combined" \
						PART $sk $l $p
					incr bad
					continue
				}
			} else {
				if {$mult_key != ""} {
					set MULT_KEYS(s,$mult_key) $l
				}
			}

			# only need to check the event level mult key
			# for the first part of a multi part leg

			if {$p == 0} {
				set mult_key $BSEL($pk,ev_mult_key)
				if {[info exists MULT_KEYS(e,$mult_key)]} {
					pb_err ERR MULT_KEY \
						"selections can't be combined" \
						PART $sk $l $p
					incr bad
					continue
				} else {
					if {$mult_key != ""} {
						set MULT_KEYS(e,$mult_key) $pk
					}
				}
			}



			#
			# count the number of match result draws selected
			#
			set mkt_sort $BSEL($pk,mkt_sort)
			if {($mkt_sort  == "MR" || $mkt_sort  == "CS") &&
				$BSEL($pk,fb_result) == "D"} {
				incr BSEL($sk,drw_cnt)
			}


			lappend BSEL(ids) $BSEL($pk,ev_oc_id)
		}
	}




	#
	# as a concession to the pools companies ?
	# some bookmakers will not accept accumulators
	# with more than 5 draw results from w/d/w or CS markets
	#

	if {![OT_CfgGetTrue ALLOW_FIVE_DRAWS]} {
		if {$BSEL($sk,drw_cnt) > 5 && $BSEL($sk,acc_max) > 5} {
			set BSEL($sk,acc_max) 5
		}
	}

	log 10 "returning with ids set to $BSEL(ids)"
	if {!$bad} {
		set BSEL($sk,selns_ok) 1
	}
}








# ----------------------------------------------------------------------
# insert into BSEL all the available bet types and any associated
# data e.g. num_lines
#
# ----------------------------------------------------------------------

proc OB_placebet::build_available_bets {sk} {

	global BSEL BET_TYPE CUST
	variable MSEL

	# if simple single and max winnings enabled then factor in winnings
	if {[OT_CfgGet FUNC_MAX_WIN 0] && $BSEL($sk,num_legs) == 1 && $BSEL($sk,0,num_parts) == 1} {

		set max_pot_win 0
		if {[info exists BSEL($sk,0,0,max_pot_win)]} {
			set max_pot_win $BSEL($sk,0,0,max_pot_win)
		}

		log 5 "build_available_bets - max potential win: $max_pot_win"

		if {[info exists BSEL($sk,0,0,lp_num)] && [info exists BSEL($sk,0,0,lp_den)]} {
			set lp_num $BSEL($sk,0,0,lp_num)
			set lp_den $BSEL($sk,0,0,lp_den)
		} else {
			set lp_num [OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5]
			set lp_den [OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_DEN 2]
		}

		set ev_oc_id $BSEL($sk,0,0,ev_oc_id)

		# We now work out the maximum bet that would be possible based on
		# previous potential winnings, for each leg/price type.
		# If VAR_STAKES_SEP_CUM_SP_LP is Y (default) then cum winnings
		# for the specific price type is used, else we combine the winnings
		# for LP and SP.
		if {[OT_CfgGet VAR_STAKES_SEP_CUM_SP_LP "Y"] == "Y"} {

			set max_win_lp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							1.0 \
							$MSEL($ev_oc_id,cum_win_lp_wins) \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"LP"]

			set max_win_sp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							1.0 \
							$MSEL($ev_oc_id,cum_win_sp_wins) \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"SP"]

			set max_place_lp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							$BSEL($sk,0,0,ew_factor) \
							$MSEL($ev_oc_id,cum_place_lp_wins) \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"LP"]

			set max_place_sp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							$BSEL($sk,0,0,ew_factor) \
							$MSEL($ev_oc_id,cum_place_sp_wins) \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"SP"]
		} else {

			set max_win_lp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							1.0 \
							[expr {$MSEL($ev_oc_id,cum_win_lp_wins) + $MSEL($ev_oc_id,cum_win_sp_wins)}]\
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"LP"]

			set max_win_sp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							1.0 \
							[expr {$MSEL($ev_oc_id,cum_win_lp_wins) + $MSEL($ev_oc_id,cum_win_sp_wins)}]\
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"SP"]

			set max_place_lp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							$BSEL($sk,0,0,ew_factor) \
							[expr {$MSEL($ev_oc_id,cum_place_lp_wins) + $MSEL($ev_oc_id,cum_place_sp_wins)}] \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"LP"]

			set max_place_sp_wins [OB_placebet::calculate_max_win \
							$max_pot_win \
							$BSEL($sk,0,0,ew_factor) \
							[expr {$MSEL($ev_oc_id,cum_place_lp_wins) + $MSEL($ev_oc_id,cum_place_sp_wins)}] \
							$lp_num \
							$lp_den \
							$ev_oc_id \
							"SP"]
		}

		set max_ew_lp_wins [min $max_win_lp_wins $max_place_lp_wins]
		set max_ew_sp_wins [min $max_win_sp_wins $max_place_sp_wins]

		# factor in at part level
		set BSEL($sk,0,0,max_win_lp)       [max $max_win_lp_wins $BSEL($sk,0,0,max_win_lp)]
		set BSEL($sk,0,0,max_win_sp)       [max $max_win_sp_wins $BSEL($sk,0,0,max_win_sp)]
		set BSEL($sk,0,0,max_place_lp)     [max $max_place_lp_wins $BSEL($sk,0,0,max_place_lp)]
		set BSEL($sk,0,0,max_place_sp)     [max $max_place_sp_wins $BSEL($sk,0,0,max_place_sp)]
		set BSEL($sk,0,0,max_ew_lp)        [max $max_ew_lp_wins $BSEL($sk,0,0,max_ew_lp)]
		set BSEL($sk,0,0,max_ew_sp)        [max $max_ew_sp_wins $BSEL($sk,0,0,max_ew_sp)]

		# factor in at selection key level
		if {[info exists BSEL($sk,0,0,price_type)]} {
			if {[lsearch [list L G] $BSEL($sk,0,0,price_type)] > -1} {

				set BSEL($sk,max_win_bet) [max $max_win_lp_wins   $BSEL($sk,max_win_bet)]
				set BSEL($sk,max_plc_bet) [max $max_place_lp_wins $BSEL($sk,max_plc_bet)]
				set BSEL($sk,max_ew_bet)  [max $max_ew_lp_wins    $BSEL($sk,max_ew_bet)]

				if {[info exists BSEL(ids,$ev_oc_id,leg_type)]} {
					switch -- $BSEL(ids,$ev_oc_id,leg_type) {
						"W" {
							set max_wins $max_win_lp_wins
						}
						"E" {
							set max_wins $max_ew_lp_wins
						}
						"P" {
							set max_wins $max_place_lp_wins
						}
						default {
							# take W as default
							set max_wins $max_win_lp_wins
						}
					}
				} else {
					# take W as default
					set max_wins $max_win_lp_wins
				}

				set BSEL($sk,stk_max) [max $max_wins $BSEL($sk,stk_max)]
			} else {

				set BSEL($sk,max_win_bet) [max $max_win_sp_wins   $BSEL($sk,max_win_bet)]
				set BSEL($sk,max_plc_bet) [max $max_place_sp_wins $BSEL($sk,max_plc_bet)]
				set BSEL($sk,max_ew_bet)  [max $max_ew_sp_wins    $BSEL($sk,max_ew_bet)]

				if {[info exists BSEL(ids,$ev_oc_id,leg_type)]} {
					switch -- $BSEL(ids,$ev_oc_id,leg_type) {
						"W" {
							set max_wins $max_win_sp_wins
						}
						"E" {
							set max_wins $max_ew_sp_wins
						}
						"P" {
							set max_wins $max_place_sp_wins
						}
						default {
							# take W as default
							set max_wins $max_win_sp_wins
						}
					}
				} else {
					# take W as default
					set max_wins $max_win_sp_wins
				}

				set BSEL($sk,stk_max) [max $max_wins $BSEL($sk,stk_max)]
			}
		} else {
			# Assume we should take the lowest winnings from the
			# price types
			set BSEL($sk,max_win_bet) [max [min $max_win_lp_wins $max_win_sp_wins]     $BSEL($sk,max_win_bet)]
			set BSEL($sk,max_plc_bet) [max [min $max_place_lp_wins $max_place_sp_wins] $BSEL($sk,max_plc_bet)]
			set BSEL($sk,max_ew_bet)  [max [min $max_ew_lp_wins $max_ew_sp_wins]       $BSEL($sk,max_ew_bet)]

			if {[info exists BSEL(ids,$ev_oc_id,leg_type)]} {
				switch -- $BSEL(ids,$ev_oc_id,leg_type) {
					"W" {
						set max_wins [min $max_win_lp_wins $max_win_sp_wins]
					}
					"E" {
						set max_wins [min $max_ew_lp_wins $max_ew_sp_wins]
					}
					"P" {
						set max_wins [min $max_place_lp_wins $max_place_sp_wins]
					}
					default {
						# take W as default
						set max_wins [min $max_win_lp_wins $max_win_sp_wins]
					}
				}
			} else {
				# take W as default
				set max_wins [min $max_win_lp_wins $max_win_sp_wins]
			}

			set BSEL($sk,stk_max) [max $max_wins $BSEL($sk,stk_max)]
		}
	}

	# Set the max_multiple_bet, if possible
	set num_legs $BSEL($sk,num_legs)
	if {[OT_CfgGet FUNC_MAX_WIN_MULTIPLES 0] && $num_legs != 1} {

		for {set j 0} {$j < $num_legs} {incr j} {

			set num_parts $BSEL($sk,$j,num_parts)

			for {set p 0} {$p < $num_parts} {incr p} {

				set ev_oc_id $BSEL($sk,$j,$p,ev_oc_id)

				if {![info exists MSEL($ev_oc_id,cum_mult_stakes)]} {
					set MSEL($ev_oc_id,cum_mult_stakes) 0.0
				}

				if {$MSEL($ev_oc_id,max_mult_bet) != ""} {

					OT_LogWrite 5 "Limit Calc: Selection has max_mult_bet set"
					OT_LogWrite 5 "- max_mult_bet:$MSEL($ev_oc_id,max_mult_bet)"
					OT_LogWrite 5 "- cum_mult_stakes:$MSEL($ev_oc_id,cum_mult_stakes)"

					# Apply the max stake scale to the limit
					set max_mult_bet [expr\
					 {$MSEL($ev_oc_id,max_mult_bet)
					* $CUST(max_stake_scale)}]

					# Subtract Cumulative Multi Stakes
					set max_mult_bet [expr {$max_mult_bet
					- $MSEL($ev_oc_id,cum_mult_stakes)}]

					# Apply exch rate
					set max_mult_bet [expr {$max_mult_bet
					* $CUST(exch_rate)}]
					set max_mult_bet [max 0 $max_mult_bet]

				} else {
					continue;
				}

				# finally look at the bet specifics and store
				# a global max bet based on these
				set leg_sort ""

				if {[info exists $BSEL($sk,$j,leg_sort)]} {
					set leg_sort $BSEL($sk,$j,leg_sort)
				}

				set pk "$sk,$j,$p"

				# max_fc/tc may still apply
				# override everything else
				if {$leg_sort == "SF"} {

					set max_bet [min $max_mult_bet\
					$BSEL($pk,max_fc)]

				} elseif {$leg_sort == "TC"} {

					set max_bet [min $max_mult_bet\
					$BSEL($pk,max_tc)]

				} else {
					set max_bet $max_mult_bet
				}

				set BSEL($pk,max_mult_bet) $max_bet

				if {[info exists BSEL($sk,max_mult_bet)]} {
					set BSEL($sk,max_mult_bet)\
					 [min $max_bet $BSEL($sk,max_mult_bet)]
				} else {
					set BSEL($sk,max_mult_bet) $max_bet
				}

				OT_LogWrite 5 "build_available_bets:\
					 Overriding max_bet:\
					 seln $ev_oc_id max $max_mult_bet"

			}
		}

		if {[info exists BSEL($sk,max_mult_bet)]} {

			foreach limit [list max_bet stk_max\
			 max_win_bet max_plc_bet max_ew_bet ] {
				set BSEL($sk,$limit) $BSEL($sk,max_mult_bet)
			}
		}
	}

	set bets [get_valid_bets $sk]
	log 2 "available bets: $bets"

	set nbets [llength $bets]

	for {set i 0} {$i < $nbets} {incr i} {
		set bet [lindex $bets $i]
		set b "$sk,bets,$i"

		set BSEL($b,bet_placed)    0
		set BSEL($b,bet_type)      $bet
		set BSEL($b,bet_name)      $BET_TYPE($bet,bet_name)
		set BSEL($b,blurb)         $BET_TYPE($bet,blurb)
		set BSEL($b,bet_seln_key)  $sk
		set BSEL($b,bet_num_lines) [get_num_bet_lines $sk $bet]

		# stake limits in BSEL will already have been converted into the
		# user's currency. Max payout, MSEL, BET_TYPE, etc. will need to
		# be converted
		set max_pay [expr {$BSEL($sk,max_payout) * $CUST(exch_rate)}]

		# check min_bet is less than the bet type limit
		set min_bet [min [expr {$BET_TYPE($bet,min_bet) * $CUST(exch_rate)}] $BSEL($sk,stk_min)]

		if {[OT_CfgGetTrue SLOT_MAX_BET]} {

			# max bet based on current price/leg types selected
			set max_bet $BSEL($sk,stk_max)

			# max bet for all possible leg types
			set max_win_bet $BSEL($sk,max_win_bet)
			set max_plc_bet $BSEL($sk,max_plc_bet)
			set max_ew_bet  $BSEL($sk,max_ew_bet)
		} else {
			# max bet based on current price/leg types selected
			set max_bet [expr {$BSEL($sk,stk_max) / $BET_TYPE($bet,num_bets_per_seln)}]

			# max bet for all possible leg types
			set max_win_bet [expr {$BSEL($sk,max_win_bet) / $BET_TYPE($bet,num_bets_per_seln)}]
			set max_plc_bet [expr {$BSEL($sk,max_plc_bet) / $BET_TYPE($bet,num_bets_per_seln)}]
			set max_ew_bet  [expr {$BSEL($sk,max_ew_bet) / $BET_TYPE($bet,num_bets_per_seln)}]
		}

		# check max bets are below bet type's limits and still at least 0
		set bet_type_max_ccy [expr {$BET_TYPE($bet,max_bet) * $CUST(exch_rate)}]
		log 5 "build_available_bets : bet_type_max_ccy $bet_type_max_ccy"
		foreach type {max_bet max_win_bet max_plc_bet max_ew_bet} {
			set $type [min [subst $$type] $bet_type_max_ccy]
			set $type [max [subst $$type] 0]
		}

		set min_bet [min $max_bet $min_bet]

		# For logged shop punters, offset the max bet values by the amount they may have
		# already staked from other shops
		if {[OT_CfgGet LOG_PUNTER_TOTAL_BETS 0] && $CUST(acct_owner_type) == "LOG"} {

			if {[catch {set res_punter_stakes [db_exec_qry pb_punter_prev_stakes \
													$CUST(cust_id) \
													$BSEL($sk,0,0,ev_oc_id)]} msg]} {
				pb_err ERR PUNTER_STAKES \
					"Unable to retrieve previous bets by punter: $msg" SYS
				return 0
			} else {
				set max_bet_offset 0
				if {[db_get_nrows $res_punter_stakes] == 1} {
					set punter_stakes [db_get_coln $res_punter_stakes 0 0]

					# The query will return null if no other stakes have been placed
					# on the selection
					if {$punter_stakes != ""} {
						set max_bet     [expr $max_bet     - $punter_stakes]
						set max_win_bet [expr $max_win_bet - $punter_stakes]
						set max_plc_bet [expr $max_plc_bet - $punter_stakes]
						set max_ew_bet  [expr $max_ew_bet  - $punter_stakes]

						# If less than 0, return the max stake to 0
						if {$max_bet < 0}     {set max_bet 0}
						if {$max_win_bet < 0} {set max_win_bet 0}
						if {$max_plc_bet < 0} {set max_plc_bet 0}
						if {$max_ew_bet < 0}  {set max_ew_bet 0}
					}
				}

				db_close $res_punter_stakes

			}
		}

		OT_LogWrite 5 "max_pay $max_pay [format %0.2f $max_pay]"
		set BSEL($b,bet_max_payout) [format %0.2f $max_pay]
		set BSEL($b,min_bet)        [format %0.2f $min_bet]
		set BSEL($b,max_bet)        [format %0.2f $max_bet]
		set BSEL($b,max_win_bet)    [format %0.2f $max_win_bet]
		set BSEL($b,max_plc_bet)    [format %0.2f $max_plc_bet]
		set BSEL($b,max_ew_bet)     [format %0.2f $max_ew_bet]

		foreach type {min_bet max_bet max_win_bet max_plc_bet max_ew_bet} {
			log 5 "build_available_bets : BSEL($b,$type) $BSEL($b,$type)"
		}
	}


	set BSEL($sk,num_bets_avail) [llength $bets]

	return $bets
}



#----------------------------------------------------------------------
# given a selection key this procedure will return a list
# of bet types that are valid for the selections
#----------------------------------------------------------------------


proc OB_placebet::get_valid_bets {sk} {

	global   BSEL BET_TYPE


	if {!$BSEL($sk,selns_ok)} {
		validate_mult_rules $sk
	}


	if {[info exists BSEL($sk,valid_bets)]} {
		return $BSEL($sk,valid_bets)
	}

	set BSEL($sk,valid_bets) ""

	set num_legs $BSEL($sk,num_legs)
	set acc_min  $BSEL($sk,acc_min)
	set acc_max  $BSEL($sk,acc_max)

	#
	# shortcut for singles
 	#
	if {$num_legs == 1 && $acc_min == 1} {
		return [set BSEL($sk,valid_bets) SGL]
	}

	log 9 "number of legs passed in: $num_legs"
	foreach bet_type $BET_TYPE(bet_types) {

		if {$BET_TYPE($bet_type,num_selns) != $num_legs} {
			continue
		}
		#restrict luckyX bets to certain classes and markets
		if {([lsearch {L15 L31 L63 YAP} $bet_type] != -1) && ([OT_CfgGet LUCKY_CLASS_RESTRICT ""] != "") || ([lsearch {L7B} $bet_type] != -1) && ([OT_CfgGet LUCKY_HR_GR ""] != "")} {
			#
			# LUCKY_HR_GR restricts to only HR & GR (for L7B), so (not correct score's etc.)
			# Same format as LUCKY_CLASS_RESTRICT.
			#
			# LUCKY_CLASS_RESTRICT is a list of valid class sort, market sort combinations
			# ie if it were GH {} HR {} FB {CS FS HF}
			# We would only allow luckyX bets on Greyhound, Horseracing and
			# Football correct_score, first scorer and Half-Time/Full-Time markets
			OT_LogWrite 5 "Looking to see if we should restrict lucky bets for this combination"

			set lucky_class_restrict [list]
			if {[OT_CfgGet LUCKY_HR_GR ""] != ""} {
				set lucky_class_restrict [OT_CfgGet LUCKY_HR_GR]
			} else {
				set lucky_class_restrict [OT_CfgGet LUCKY_CLASS_RESTRICT]
			}

			set lucky_allowed 1

			for {set i 0} {$i < $num_legs} {incr i} {
				if {[catch {
					set class_sort $BSEL($sk,$i,0,ev_class_sort)
					set mkt_sort   $BSEL($sk,$i,0,mkt_sort)

				} msg]} {
					OT_LogWrite 1 "BSEL($sk,$i,0,ev_class_sort) or BSEL($sk,$i,0,mkt_sort)"
					OT_LogWrite 1 "not set - assuming lucky X/Yap bet not allowed"
					set lucky_allowed 0
					break
				}
				set sel_allowed 0
				foreach {allowed_class allowed_mkts} $lucky_class_restrict {
					if {$class_sort == $allowed_class} {
						if {$allowed_mkts == {}} {
							#all markets allowed for this class
							set sel_allowed 1
							break
						} else {
							foreach allowed_mkt $allowed_mkts {
								if {$allowed_mkt == $mkt_sort} {
									set sel_allowed 1
									break
								}
							}
						}
					}
				}

				if {!$sel_allowed} {
					set lucky_allowed 0
					break
				}
			}

			if {!$lucky_allowed} {
				OT_LogWrite 5 "Lucky/Yap bets not allowed for this combination"
				continue
			}
		}

		#if the betslip contains any antepost selections do not offer any bet
		#types that are in DISALLOWED_AP_BETS [TTE078 / RFC 010]
		set is_ap_mkt 0
		for {set i 0} {$i < $num_legs} {incr i} {
			if {$BSEL($sk,$i,0,is_ap_mkt) == "Y"} {
				set is_ap_mkt 1
				break
			}
		}

                if { $is_ap_mkt &&
                        ([lsearch -exact [OT_CfgGet DISALLOWED_AP_BETS {}] $bet_type] >= 0) } {
			OT_LogWrite 5 "Bet type not valid: $bet_type is in DISALLOWED_AP_BETS list"
                        continue
                }

		log 9 "acc_min:$acc_min"
		log 9 "acc_max:$acc_max"
		log 9 "bet type min: $BET_TYPE($bet_type,min_combi)"
		log 9 "bet type max: $BET_TYPE($bet_type,max_combi)"

		set BSEL($sk,acc_min_restricted) 0
		set BSEL($sk,acc_max_restricted) 0

		if {($BET_TYPE($bet_type,min_combi) >= $acc_min)} {
			if {($BET_TYPE($bet_type,max_combi) <= $acc_max)} {
				lappend BSEL($sk,valid_bets) $bet_type
			} else {
				# Flag to tell the user that his
				# choice of bets has been limited
				# because of acc_max.
				set BSEL($sk,acc_max_restricted) 1
			}
		} else {
			# Flag to tell the user that his
			# choice of bets has been limited
			# because of acc_min.
			set BSEL($sk,acc_min_restricted) 1
		}
	}


	log 9 "valid bets for sk $sk are $BSEL($sk,valid_bets)"


	return $BSEL($sk,valid_bets)
}


proc OB_placebet::get_num_bet_lines {sk bet} {

	global BSEL BET_LINES
	variable BET

	set rows $BET_LINES($bet)
	set num_lines 0
	foreach row $rows {
		set nlines 1
		foreach l $row {
			incr l -1

			if {![info exists BSEL($sk,$l,leg_sort)]} {
				log 15 "leg_sort (BSEL($sk,$l,leg_sort)) not decided, can't count bet lines"
				pb_err ERR NO_LEG_SORT "No Leg sort specified and unable to guess" SELN $sk $l
				continue
			}

			set leg_sort $BSEL($sk,$l,leg_sort)
			if {[lsearch $BSEL($sk,$l,valid_sorts) $leg_sort] < 0} {
				log 15 "leg_sort $leg_sort is no longer valid, can't count bet lines"
				pb_err ERR NO_LEG_SORT "Invalid Leg sort specified" SELN $sk $l
				unset BSEL($sk,$l,leg_sort)
				continue
			}

			if {![info exists BSEL($sk,$l,num_lines)]} {
				set BSEL($sk,$l,num_lines)\
					$BSEL($sk,$l,$BSEL($sk,$l,leg_sort),num_lines)
			}

			set nlines [expr {$nlines * $BSEL($sk,$l,num_lines)}]
		}
		incr num_lines $nlines
	}

	return $num_lines
}


# ----------------------------------------------------------------------
# The procedures from here on down are concerned with the bets
# themselves. Validating them against the restrictions imposed
# by the selections, and, if successful, placing them
# ----------------------------------------------------------------------


proc OB_placebet::place_bet {sk bet_type stk uid leg_type tax_type tax_rate {num_lines 0} {max_payout 0} {tokens ""} {pay_for_ap Y} {slip_id {}} {is_retro_mode 0}} {

	global   BSEL BET_TYPE
	variable BP_MESSAGE
	variable BP_MESSAGES
	variable pb_real
	variable do_funds_chk


	log 3 "starting place_bet with $sk $bet_type $stk $uid $leg_type $tax_type $tax_rate $num_lines $max_payout $tokens $pay_for_ap $slip_id"
	#
	# validate the parameters
	#

	if {![info exists BSEL($sk,num_legs)]} {
		pb_err ERR BAD_SK "invalid selection key $sk" SYS
		return
	}

	if {[lsearch $BET_TYPE(bet_types) $bet_type] < 0} {
		pb_err ERR BET_TYPE "No such bet type $bet_type" BET
		return
	}

	if {![regexp {^(0|[1-9][0-9]*|[0-9]+\.[0-9]{0,2}|\.[0-9]{1,2})$} $stk]} {
		pb_err ERR BET_STK "invalid stake $stk" BET
		return
	}

	if {[string length $uid] < 1} {
		pb_err ERR BET_UID "no unique id" BET
		return
	}

	if {[lsearch {W E P} $leg_type] < 0} {
		pb_err ERR LEG_TYPE "invalid leg type $leg_type" BET
		return
	}

	if {$tax_type != "S" && $tax_type != "W"} {
		pb_err ERR TAX_TYPE "invalid tax_type $tax_type" BET
		return
	}

	if {![regexp {^(0|[1-9][0-9]*|[0-9]+\.[0-9]*|\.[0-9]+)$} $tax_rate]} {
		pb_err ERR TAX_RATE "invalid tax rate $tax_rate" BET
		return
	}

	if {![regexp {^[0-9]+$} $num_lines]} {
		pb_err ERR NUM_LINES "Invalid number of lines $num_lines" BET
		return
	}

	if {![regexp {^(0|[1-9][0-9]*|[0-9]+\.[0-9]{0,2}|\.[0-9]{1,2})$} $max_payout]} {
		pb_err ERR MAX_PAY "invalid max payout $max_payout" BET
		return
	}

	#
	# find the requested bet type in the
	# available bet types
	#

	if {![info exists BSEL($sk,num_bets_avail)]} {
		build_available_bets $sk
	}

	set bet_no -1
	for {set i 0} {$i < $BSEL($sk,num_bets_avail)} {incr i} {
		if {$bet_type == $BSEL($sk,bets,$i,bet_type)} {
			set bet_no $i
			break
		}
	}

	if {$bet_no == -1} {
		pb_err ERR BET_TYPE "Bet type $bet_type not available" BET
		return
	}

	set b "$sk,bets,$bet_no"
	if {$BSEL($b,bet_placed)} {
		pb_err ERR BET_PLACE "Bet has already been placed" BET
		return
	}

	set BSEL($b,bet_ok) 0

	array set BSEL [list \
						$b,leg_type   $leg_type\
						$b,stake_per_line $stk\
						$b,unique_id      $uid\
						$b,num_lines      $num_lines\
						$b,tax_type       $tax_type\
						$b,tax_rate       $tax_rate\
						$b,max_payout     $max_payout\
						$b,cust_token_ids $tokens\
						$b,token_value    0\
						$b,pay_for_ap     $pay_for_ap\
						$b,slip_id        $slip_id]

	OT_LogWrite 1 "For $b, pay_for_ap is : $pay_for_ap"

	#for shop bets the funds have already been taken out of the account
	if {$slip_id != ""} {
		set do_funds_chk 0
	}
	if {[validate_bet $sk $bet_no] == 0} {
		log 3 "Bet $b validated successfully, placing"

		if {$pb_real != 1} {
			pb_err ERR NO_TRAN\
				"You must call pb_start before placing bets"\
				BET $bet_no
			return
		}

		set BP_MESSAGE ""
		actually_place_bet $sk $bet_no $is_retro_mode
		set  BSEL($b,bet_placed) 1
		incr BSEL($sk,num_bets)
		incr BSEL(num_bets)
		lappend BP_MESSAGES $BP_MESSAGE


	} else {
		log 3 "Bet $b validation failed"
	}

	return
}


proc OB_placebet::validate_bet {sk bet_no} {

	global BSEL CUST BET_TYPE BET_LINES PB_ERRORS
	global PB_OVERRIDES

	variable LEG_TYPES_TXT
	variable do_funds_chk
	variable pb_real

	if {[check_acct_owner] != 0} {
		return
	}

	set b "$sk,bets,$bet_no"

	set bet_type $BSEL($b,bet_type)

	#
	# validate the individual legs
	#

	set num_legs $BSEL($sk,num_legs)
	for {set l 0} {$l < $num_legs} {incr l} {
		validate_leg $bet_no $sk $l

		if {$PB_ERRORS(num_err) > 0} {
			return -1
		}
	}

	#
	# stake must be greater than the minumum of
	# the min stake for the bet type and
	# the min_stake for the selections
	#


if {$BSEL($b,stake_per_line) < $BSEL($b,min_bet)} {
		if {[pb_err ERR STK_LOW "Stake too low - the minimum total stake for this bet is $BSEL($b,min_bet)" BET $b] != 0} {
			return -1
		}
	}

	#
	# calculate the number of lines for this bet_type
	# with these selections, this must then be compared
	# with what the user has been told
	#

	if {$BSEL($b,num_lines) == 0} {
		set BSEL($b,num_lines) $BSEL($b,bet_num_lines)
	} elseif {$BSEL($b,bet_num_lines) != $BSEL($b,num_lines)} {
		pb_err ERR NUM_LINES \
			"incorrect number of lines in bet" BET $b
		return -1
	}

	#
	# if the bet is Each-Way or Equally Divided lines *= 2
	#
	if {$BSEL($b,leg_type) == "E" || $BSEL($b,leg_type) == "Q"} {
		set BSEL($b,num_lines) [expr {2 * $BSEL($b,num_lines)}]
	}

	#
	# the selected leg type must be available for the selections
	#
	if {$BSEL($b,leg_type) == "E" && $BSEL($sk,ew_avail) != "Y"} {

		# check if can place an ew bet when ew is not available
		if {![OT_CfgGetTrue ALLOW_MIXED_EW_MULTIPLIERS]} {
			pb_err ERR EW_NOT_AV \
			"Each-Way bets not available" BET $b
			return -1
		}

		if {$bet_type != "SGL"} {

			set BSEL($sk,is_ew_mix_mult) 0

			# CHECK THAT AT LEAST ONE PART IS EW
			for {set l 0} {$l < $num_legs} {incr l} {
				for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {
					if {$BSEL($sk,$l,$p,ew_avail)=="Y"} {
						set BSEL($sk,is_ew_mix_mult) 1
						break
					}
				}
			}

			# NO PARTS ARE EW - THROW ERROR
			if {$BSEL($sk,is_ew_mix_mult)!=1} {
				pb_err ERR EW_NOT_AV \
				"Must have at least one EW selection to place a EW multiple" BET $b
				return -1
			}
		} else {
			pb_err ERR EW_NOT_AV \
			"Non Each-Way selections cannot be part of an EW single bet" BET $b
			return -1
		}
	}

	if {$BSEL($b,leg_type) == "P" && $BSEL($sk,pl_avail) != "Y"} {
		#
		# Allow Place bets for telebet
		#
		if {![OT_CfgGetTrue TELEBET]} {
			pb_err ERR EW_NOT_AV \
				"Place bets not available" BET $b
			return -1
		}
	}

	set BSEL($b,leg_type_desc) $LEG_TYPES_TXT($BSEL($b,leg_type))

	# and less than the minimum of their maximums

	#
	# check the leg type to retrieve the relevant max bet for this bet type
	#
	switch -- $BSEL($b,leg_type) {
		"W" {
			set max_bet $BSEL($b,max_win_bet)
		}
		"P" {
			set max_bet $BSEL($b,max_plc_bet)
		}
		"E" {
			set max_bet $BSEL($b,max_ew_bet)
		}
		default {
			# set to lowest of all three
			set max_bet [min [min $BSEL($b,max_win_bet) $BSEL($b,max_plc_bet)] $BSEL($b,max_ew_bet)]
		}
	}

	# Check max_bet UNLESS it's a notification
	if {$BSEL($b,stake_per_line) > $max_bet && [reqGetArg referral 0] != -1} {
		if {[pb_err ERR STK_HIGH "Stake too high - Maximum total stake for this bet is $max_bet" BET $b] != 0} {
			return -1
		}
	}

	# Handle overrides for referrals
	if {[reqGetArg referral] == 1} {
		if {[OT_CfgGet LOG_PUNTER_TOTAL_BETS 0]} {
			# If this config is on, we always want to add this override without
			# actually throwing an error to the operator
			if {![info exists PB_OVERRIDES(BET,0)] || [lsearch $PB_OVERRIDES(BET,0) SHOP_BET]<0} {
				lappend PB_OVERRIDES(BET,0) SHOP_BET
			}

		} elseif {[pb_err ERR SHOP_BET "This is a referred bet and requires authorisation" BET 0]==1} {
			# Request authorisation to place referred bets
			return -1
		}
	}

	#
	# make sure that the real max_payout is at least
	# as high as that the customer has seen
	#
	log 5 "max_payout=$BSEL($b,max_payout) bet_max_payout=$BSEL($b,bet_max_payout)"
	if {$BSEL($b,max_payout) > $BSEL($b,bet_max_payout)} {
		pb_err ERR MAX_PAYOUT \
			"max payout too high "\
			BET $b
		return -1
	}


	#	if {[validate_cum_stakes $sk $bet_no] != 0} {
	#
	#		return  -1
	#	}


	#
	# stake is num lines * stake_per_line
	#
	set BSEL($b,stake)     \
		[expr {$BSEL($b,num_lines) * $BSEL($b,stake_per_line)}]
	set BSEL($b,stake)	[format "%0.2f" $BSEL($b,stake)]

	#
	# Hideous 'first bet tax free' for ladbrokes
	#

	if {$CUST(bet_count) == 0 && [OT_CfgGetTrue BET_1_TAX_FREE]} {
		set BSEL($b,tax_rate) 0
	}

	#
	# check that the tax rates match
	#


	if {$BSEL($b,tax_rate) != 0 &&
		$BSEL($b,tax_rate) != $BSEL($sk,tax_rate)} {
		OT_LogWrite 9 "TAX should be $BSEL($sk,tax_rate)"
		pb_err ERR TAX_RATE "Incorrect tax rate $BSEL($b,tax_rate)" BET $b
		return -1
	}

	#
	# calculate tax on stake (if any)
	#
	if {$BSEL($b,tax_type) == "S"} {
		set BSEL($b,tax) \
			[expr {round($BSEL($b,stake) * $BSEL($b,tax_rate))/100.0}]
	} else {
		set BSEL($b,tax) 0.0
	}


	set BSEL($b,total_paid) [expr {$BSEL($b,stake) + $BSEL($b,tax)}]


	# Validate any freebets tokens used - must do this here as we
	# need to know how much is paid to validate
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		if {[llength $BSEL($b,cust_token_ids)] > 0} {

			set redeemList [OB_freebets::validate_tokens $BSEL($b,cust_token_ids) $BSEL($sk,ids) $BSEL($b,total_paid)]

			set BSEL($b,token_value) 0
			# Step thru list, generating total token value

			for {set i 0} {$i < [llength $redeemList]} {incr i} {
				array set token  [lindex $redeemList $i]
				set BSEL($b,token_value) [expr "$BSEL($b,token_value) + $token(redeemed_val)"]
				OT_LogWrite 10 "Token $i (id $token(id), value $token(redeemed_val))"
			}
		}
	}


	#
	# we keep note of how each bet affects the customers
	# balance so that the calling procedure can make a deposit
	# if required
	#
	OT_LogWrite 1 "Cust balance b4		: 	$CUST(balance)"

	# normal credit limit
	set credit_limit [expr {
		$CUST(acct_type) == "CDT" && $CUST(credit_limit) != "" ?
		$CUST(credit_limit) : 0.0
	}]

	# hard credit limits
	set soft_credit_limit [expr {
		$credit_limit * (
			[OT_CfgGet SOFT_CREDIT_LIMITS 0] ?
			(1.0 + [ob_control::get credit_limit_or] / 100.0) :
			1.0
		)
	}]

	set CUST(balance)\
		[format "%0.2f" [expr {$CUST(balance) - ($BSEL($b,stake) - $BSEL($b,token_value))  - $BSEL($b,tax)}]]

	# if the credit limit is null - unlimited credit
	# added in for cashbetting accounts
	# Take freebets tokens into account when checking funds
	# Credit accounts, only, will need to consider credit limit which
	# can be overridden

	OT_LogWrite 1 "Cust balance			: 	$CUST(balance)"
	OT_LogWrite 1 "Credit limit			:	$credit_limit"
	OT_LogWrite 1 "Soft credit limit	:	$soft_credit_limit"
	OT_LogWrite 1 "token_value 			:	$BSEL($b,token_value)"

	if {$credit_limit != "" && $do_funds_chk} {
		set available $CUST(balance)
		set err_msg "Insufficient funds in your account to place bet"
		if {$CUST(acct_type)=="CDT"} {
			# We only use this override if the soft limit is greater than
			# the normal limit, and the customer is over this limit.
			# We don't want to show two sets of overrides.
			#
			if {$soft_credit_limit > $credit_limit &&
				$available + $soft_credit_limit < 0} {
				if {[pb_err ERR SOFT_CREDIT $err_msg BET 0] == 1} {
					return -1
				}
			} elseif {[expr {$available + $credit_limit}] < 0} {
				if {[pb_err ERR CREDIT $err_msg BET 0] == 1} {
					return -1
				}
			}
		} else {
			log  1 "AVAILABLE: $available"
			if {$available < 0} {

				#Display different error message for debit customers
				#To allow debit customers to go below zero set
				#PMT_DBT_BAL_TO_ZERO in config file to 0

				if {$CUST(acct_type)!="DBT" || [OT_CfgGet PMT_DBT_BAL_TO_ZERO 1]==1} {

					# Display error message explaining that you cannot place bets
					# online with this account.

					if {[OT_CfgGet PMT_DBT_BAL_TO_ZERO_ERR 0] == 1} {
						set err_msg [ml_printf ERR_DEP_ACCT_FUNDS_CHECK ]
						log 1 "DEP ERR acct_type is $CUST(acct_type)"
					}

				}

				if {[pb_err ERR LOW_FUNDS $err_msg BET 0]==1} {
					return -1
				}
			}
		}
	}


	log 3 "Total stake is $BSEL($b,stake) ($BSEL($b,num_lines) * $BSEL($b,stake_per_line)), tax $BSEL($b,tax), FreeBets tokens $BSEL($b,token_value)"

	set BSEL($b,bet_ok) 1

	return 0
}


#
proc OB_placebet::validate_cum_stakes {sk bet_no} {
#
# This doesn't actually get called... exceeding cumulative stakes once is
# OK as the act then automatically suspends the selection through the
# liability checks pb_do_liab
#


	global BSEL CUST BET_TYPE

	variable MSEL
	set ret 0

	set b "$sk,bets,$bet_no"

	set bet_type $BSEL($b,bet_type)

	foreach id $BSEL($sk,ids) {


		log 1 "*** cum_stakes = $MSEL($id,cum_stakes)"
		log 1 "*** spl        = $BSEL($b,stake_per_line)"
		log 1 "*** exch_rate  = $CUST(exch_rate)"
		log 1 "*** nbps       = $BET_TYPE($bet_type,num_bets_per_seln)"

		set MSEL($id,cum_stakes) \
			[expr {$MSEL($id,cum_stakes) +
				   ($BSEL($b,stake_per_line) *
					$BET_TYPE($bet_type,num_bets_per_seln))}]

		if {$MSEL($id,stk_max) >= 0.0 &&
			$MSEL($id,cum_stakes) >
			($MSEL($id,stk_max) *
			 $CUST(max_stake_scale)   *
			 $CUST(exch_rate))} {

			####	log 1 "*** cum_stakes = $MSEL($id,cum_stakes)
			####	log 1 "*** max_stakes = $MSEL($id,stk_max)"
			####	log 1 "*** cust_scale = $CUST(max_stake_scale)"
			pb_err ERR CUM_STAKE "Cumulative stake exceeded for selection $id" OC $id
			incr ret

		}
	}

	return $ret
}



#
# call the liability functions - only for single bets.
# this will send the ticker messages aswell as doing any
# suspensions necessary
#

proc OB_placebet::pb_do_liab {sk bet_no leg_sort leg_type} {

	global BSEL CUST

	variable MSEL
	set b  "$sk,bets,$bet_no"
	set pk "$sk,0,0"

	set seln_id $BSEL($sk,ids)

	# APC not implemented for MH markets
	if {([string first $leg_sort "AH/A2/WH/HL/hl"] >= 0)
		&& $BSEL($b,bet_type) == "SGL"} {
		# call AH APC procedure

		set mkt_id $BSEL($pk,ev_mkt_id)
		set stake  [expr {$BSEL($b,stake) / $CUST(exch_rate)}]
		set o_num  $BSEL($pk,lp_num)
		set o_den  $BSEL($pk,lp_den)
		set hcap_value  $BSEL($pk,hcap_value)

		log 5 "Running HCAP APC with vals mkt $mkt_id oc $seln_id stk $stake $o_num/$o_den"

		if [catch {set rs [db_exec_qry pb_chk_hcap_apc $mkt_id $seln_id $stake $o_num $o_den $hcap_value]} msg] {
			pb_err ERR AH_APC_SQL "Failed to run HCAP APC check" BET $b
			return
		}

		set apc_status [db_get_coln $rs 0 0]
		db_close $rs

		# If APC is enabled, pChkHcapAPC will take care of everything for us.
		# However, if APC is disabled, pChkHcapAPC will do nothing other
		# than return -1 - in which case we must fall through and treat this
		# like a non-handicap market.

		if {$apc_status != -1} {
			return
		}

		log 5 "HCAP APC disabled for mkt $mkt_id, treating as normal market"

		# Having said that, an non-handicap bet wouldn't have got to pb_do_liab
		# if it was a (non-hedging) Telebet bet - leave if this is the case.
		# (Cf. logic in do_liab_updates)

		if {[OT_CfgGetTrue TELEBET] && $CUST(acct_owner) != "Y"} {
			log 10 "Not calling lbt_bet_upd (treating like a non-handicap telebet bet)"
			return
		}

	}

	#this code only gets called for singles so shouldn't be inefficent to
	#run separately for each ev_oc
	if {[catch {set rs [db_exec_qry pb_is_liab_set $seln_id]} msg]} {
		pb_err ERR AH_APC_SQL "Failed to run LIAB check" BET $b
		return
	}

	if {[db_get_nrows $rs] != 1} {
		pb_err ERR AH_APC_SQL "Failed to run LIAB check" BET $b
		db_close $rs
		return
	}

	foreach f {mkt_liab_limit seln_max_limit apc_status stk_or_lbt} {
		set $f [db_get_col $rs 0 $f]
	}

	db_close $rs

	if {$mkt_liab_limit  >= 0.0 ||
		$seln_max_limit  >= 0.0 ||
		$apc_status      == "A"} {

		#
		# call the "liability" routines... if the bet is a telephone
		# bet, don't reject it based on the liability thresholds
		# being busted...
		#
		#		if {$QRY_OPER_ID != ""} {
		set reject N
		#		} else {
		#			set reject Y
		#		}


		### log 1 "Calling lbt_bet_upd..."

		set adj_stk ""

		# Check if the bet is an each-way or place bet. If an each-way bet,
		# do not use the place part of the bet to calculate the liability.
		# If a place bet, disregard the stake in the liability calculation.
		if { $leg_type == "E" && ![OT_CfgGet USE_PLACE_IN_LIABS 1] } {
			set adj_stk [expr $BSEL($b,stake) / 2]
		} elseif { $leg_type == "P" && ![OT_CfgGet USE_PLACE_IN_LIABS 1] } {
			set adj_stk 0.00
		} else {
			set adj_stk $BSEL($b,stake)
		}

		if {$CUST(acct_owner) == "Y"} {
			set adj_stk [expr 0 - $adj_stk]
		}

		set r [catch {
			set lbt_status [lbt_bet_upd\
				$MSEL($seln_id,ev_mkt_id)\
				$seln_id\
				$adj_stk\
				$CUST(ccy_code)\
				$BSEL($pk,price_type)\
				$BSEL($pk,lp_num)\
				$BSEL($pk,lp_den)\
				$MSEL($seln_id,sp_num_guide)\
				$MSEL($seln_id,sp_den_guide)\
				$reject\
				$mkt_liab_limit\
				$stk_or_lbt\
				$seln_max_limit\
				$apc_status\
				]} msg]

		if {$r == 0} {

			log 1 "lbt_bet_upd returns: $lbt_status"

			#
			# Process the return from lbt_bet_upd -
			# a (possibly empty) list of alerts or
			# warnings which need to be sent to
			# the message router...
			#
			foreach a $lbt_status {

				foreach {m_sort m_obj_id} $a { break }

				switch -- $m_sort {
					MKT-SUSP {
						set alert_code "ALERT"
						set sln_id     ""
						set sln_name   ""
					}
					SELN-SUSP {
						set alert_code "ALERT"
						set sln_id     $MSEL($seln_id,ev_oc_id)
						set sln_name   $MSEL($seln_id,oc_name)
					}
					SELN-WARN {
						set alert_code "WARNING"
						set sln_id     $MSEL($seln_id,ev_oc_id)
						set sln_name   $MSEL($seln_id,oc_name)
					}
					default {
						log 1 "Unrecognised message: $m_sort"
						continue
					}
				}

				send_msg_alert \
					$MSEL($seln_id,ev_class_id) \
					$MSEL($seln_id,class_name) \
					$MSEL($seln_id,ev_type_id) \
					$MSEL($seln_id,type_name) \
					$MSEL($seln_id,ev_id) \
					$MSEL($seln_id,ev_name) \
					$MSEL($seln_id,ev_mkt_id) \
					$MSEL($seln_id,mkt_name) \
					$sln_id \
					$sln_name \
					$alert_code
			}

		} else {

			global errorInfo
			log 1 "lbt_bet_upd failed"
			foreach m [split $errorInfo \n] {
				log 1 "   ==> $m"
			}
		}

	} else {

		log 1 "Not calling lbt_bet_upd (limits both null)"

	}

}

proc OB_placebet::check_acct_owner {} {

	global CUST

	log 5 "Checking account owner $CUST(acct_owner)"

	# This is used for permissions checking. If the operator doesn't have
	# the correct permission, then they can be overridden by the use of
	# a override.
	#
	# Suggested permissions:
	#
	#   HEDGE - HedgeBetOverride
	#   FIELD - FieldBetOverride
	#
	# Developer notes:
	#
	#   Notice that I'm using a list here to makesure that the account types
	#   are evaluated.
	#
	switch $CUST(acct_owner) [list \
		"B" {
			# Bookmaker - for double entry book keeping
		} \
		"C" {
			# Customer
		} \
		[OT_CfgGet HEDGING_ACCT_OWNER_TYPE "Y"] {
			# Hedging
			if {![OB_operator::op_allowed HedgeBet] &&
				[pb_err ERR HEDGE \
					"The customer's account is a hedging account , but the operator has no hedge betting permission" \
					ALL] != 0} {
				return -1
			}
		} \
		[OT_CfgGet FIELDING_ACCT_OWNER_TYPE "F"] {
			# Fielding
			if {![OB_operator::op_allowed FieldBet] &&
				[pb_err ERR FIELD \
					"The customer's account is a fielding account, but the operator has no field betting permission" \
					ALL] != 0} {
				return -1
			}
		} \
		[OT_CfgGet HOSPITALITY_ACCT_OWNER_TYPE "H"] {
			if {![OB_operator::op_allowed AllowAnonCashBetting] &&
				[pb_err ERR HOSP \
					"The operator does not have permission to place anonymous cash bets" \
					ALL] != 0} {
				return -i
			}

		}
	]

	return 0
}
#
# end - bet validation procedures
#################################################################



#----------------------------------------------------------------------------
# place a bet
#----------------------------------------------------------------------------

proc OB_placebet::actually_place_bet {sk bet_no {is_retro_mode 0}} {

	global BSEL CUST USER_ID PB_AFF_ID
	global FBDATA


	set limits ""
	if {[OT_CfgGet EVENT_CLASS_STAKE_SCALE N] == "Y"} {
		global CUST_CLASS_LIMIT
		set limits CUST_CLASS_LIMIT
	}

	# if EVENT_HIER_STAKE_SCALE is set, it overrides the regular limit setting
	if {[OT_CfgGet EVENT_HIER_STAKE_SCALE N] == "Y"} {
		global CUST_EV_LVL_LIMIT
		set limits CUST_EV_LVL_LIMIT
	}

	variable MSEL
	variable BET_IDS
	variable BP_MESSAGE
	variable DIVS
	variable MONITOR_MSG
	variable FREEBET_CHECKS
	variable LBT_BET_QUEUE
	variable CFG

	# Grab current affiliate from cookie
	set aff_id [get_cookie AFF_ID]

	if {[info exists PB_AFF_ID] && $PB_AFF_ID != ""} {
		set BSEL(aff_id) $PB_AFF_ID
	} else {
		set BSEL(aff_id) $aff_id
	}
	if {![regexp {^[1-9]\d*$} $BSEL(aff_id)]} {
		set BSEL(aff_id) ""
	}

	set b "$sk,bets,$bet_no"

	if {$BSEL($b,bet_ok) != 1 || $BSEL($sk,selns_ok) != 1} {
		pb_err ERR NOT_VALID "Bet or selections not validated" BET $b
		return
	}

	# Validate any freebets tokens used
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {


		set redeemList [OB_freebets::validate_tokens $BSEL($b,cust_token_ids) $BSEL($sk,ids) $BSEL($b,total_paid)]

		set BSEL($b,token_value) 0
		set BSEL($b,cust_token_ids) [list]

		# Step thru list, creating a list of tokens and a total value
		for {set i 0} {$i < [llength $redeemList]} {incr i} {
			array set token  [lindex $redeemList $i]

			lappend BSEL($b,cust_token_ids) $token(id)

			set BSEL($b,token_value) [expr "$BSEL($b,token_value) + $token(redeemed_val)"]

			OT_LogWrite 10 "Token $i (id $token(id), value $token(redeemed_val))"
		}
	}

	# if we're retrieving all event data over it's dangerous to accept bets if the oxi
	# feed is down as the event may have started and we haven't received the status/is_off
	# change. Clearly betting in running is also dangerous.
	if {!$is_retro_mode && [OT_CfgGet REPL_ALLOW_PANIC_MODE 0] && [check_panic_mode]} {
		# if we're in panic mode we loop over all events and check the start time
		# and if it's in the past or has a BIR market we error
		# clock scan "2037-12-31 23:59:59" --> 2145916799

		set start_time_min 2145916799
		set is_bir "N"
		for {set l 0} {$l < $BSEL($sk,num_legs)} {incr l} {
			set start_time_secs [clock scan $BSEL($sk,$l,0,ev_time)]

			if {$start_time_secs < $start_time_min} {
				set start_time_min $start_time_secs
			}
			if {$BSEL($sk,$l,0,bir_started)} {
				set is_bir "Y"
			}
		}

		if {[clock seconds] > $start_time_min} {
			pb_err ERR PANIC_TIME [ml_printf PANIC_MODE_PANIC_TIME] BET
		}

		if {$is_bir} {
			pb_err ERR PANIC_BIR [ml_printf PANIC_MODE_PANIC_BIR] BET
		}
	}

	print_bet $sk $bet_no

	#
	# If we have a credit customer and a fully antepost bet,
	# can choose not to pay for it till settlement.
	#
	# If CREDIT_PAY_STAKE_LATER==1 then we can choose to pay for it
	# at settlement even if the market is not set up as antepost.
	#
	if {$CUST(acct_type)=="CDT" && \
		$BSEL($b,pay_for_ap)=="N" && \
		($BSEL($sk,is_ap_mkt)=="Y" || [OT_CfgGet "CREDIT_PAY_STAKE_LATER" 0]==1) } {
		set pay_now N
	} else {
		set pay_now Y
	}

	set     qry_base db_exec_qry
	lappend qry_base pb_ins_bet
	lappend qry_base [OT_CfgGet USE_FREE_BETS 0]
	lappend qry_base [reqGetEnv REMOTE_ADDR]
	lappend qry_base $BSEL(aff_id)
	lappend qry_base $BSEL(source)
	lappend qry_base [OB_operator::get_oper_id]
	lappend qry_base $USER_ID
	lappend qry_base $CUST(acct_id)
	lappend qry_base $BSEL($b,unique_id)
	lappend qry_base $BSEL($b,bet_type)
	lappend qry_base $BSEL($sk,num_selns)
	lappend qry_base $BSEL($sk,num_legs)
	lappend qry_base $BSEL($b,num_lines)
	lappend qry_base $BSEL($b,stake)
	lappend qry_base $BSEL($b,stake_per_line)
	lappend qry_base $BSEL($b,tax_rate)
	lappend qry_base $BSEL($b,tax_type)
	lappend qry_base $BSEL($b,tax)
	lappend qry_base $BSEL($b,bet_max_payout)
	lappend qry_base $BSEL($b,slip_id)

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		lappend qry_base $BSEL($b,token_value)
	}
	lappend qry_base $pay_now
	lappend qry_base [reqGetArg call_id]
	lappend qry_base $CFG(bet_receipt_format)
	lappend qry_base $CFG(bet_receipt_tag)

	set bet_id ""

	#
	# loop through each leg
	# and the each part inserting each
	#

	set num_legs $BSEL($sk,num_legs)

	for {set l 0} {$l < $num_legs} {incr l} {
		set     qry_seln $qry_base
		set     leg_sort $BSEL($sk,$l,leg_sort)
		lappend qry_seln [expr {$l+1}]
		lappend qry_seln $leg_sort

		for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {

			set pk "$sk,$l,$p"
			set qry $qry_seln
			set ev_oc_id $BSEL($pk,ev_oc_id)

			# part_no and all the ids
			lappend qry [expr {$p+1}]
			lappend qry $ev_oc_id
			lappend qry $MSEL($ev_oc_id,ev_id)
			lappend qry $MSEL($ev_oc_id,ev_mkt_id)

			# price details
			if {[lsearch $DIVS $leg_sort] >= 0} {
				lappend qry D {} {} "N"
			} elseif {$BSEL($pk,price_type) == "S"} {
				lappend qry S {} {} "N"
			} elseif {$BSEL($pk,price_type) == "B"} {
				lappend qry B {} {} "N"
			} elseif {$BSEL($pk,price_type) == "N"} {
				lappend qry N {} {} "N"
			} elseif {$BSEL($pk,price_type) == "1"} {
				lappend qry 1 {} {} "N"
			} elseif {$BSEL($pk,price_type) == "2"} {
				lappend qry 2 {} {} "N"
			} else {
				lappend qry $BSEL($pk,price_type)
				lappend qry $BSEL($pk,lp_num)
				lappend qry $BSEL($pk,lp_den)
				# Early Prices Active?  Only applies for Live Prices and Garenteed Prices
				lappend qry $MSEL($ev_oc_id,ep_active)
			}

			lappend qry $BSEL($pk,hcap_value)
			lappend qry $BSEL($pk,bir_index)

			set leg_type $BSEL($b,leg_type)

			lappend qry $leg_type

			# CHECK IF CAN HAVE EW MIXED MULTIPLES
			if {[info exists BSEL($sk,is_ew_mix_mult)] } {

				if {$BSEL($sk,is_ew_mix_mult) == 1 && $BSEL($pk,ew_avail) == "N"} {
					lappend qry {} {} -1
				} else {
					lappend qry $BSEL($pk,ew_fac_num)
					lappend qry $BSEL($pk,ew_fac_den)
					lappend qry $BSEL($pk,ew_places)
				}
			} else {
				if {($leg_type == "E" || $leg_type == "P")
					&& $BSEL($pk,ew_with_bet) == "Y"} {
					lappend qry $BSEL($pk,ew_fac_num)
					lappend qry $BSEL($pk,ew_fac_den)
					lappend qry $BSEL($pk,ew_places)
				} else {
					lappend qry {} {} {}
				}
			}

			lappend qry $bet_id
			lappend qry $MSEL($ev_oc_id,bir_started)

			# Don't pass in settle_info anymore
			lappend qry ""

			lappend qry [reqGetArg rep_code]
			lappend qry [reqGetArg course]

			#
			# execute the query
			#
			if [catch {set rs [eval $qry]} msg] {
				pb_err ERR INSOB_SQL \
					"failed to exec qry: $msg:\n$qry" SYS
				return
			}

			if {[db_get_nrows $rs] < 1} {
				pb_err ERR PINSBET \
					"procedure returned no rows" SYS
				db_close $rs
				return
			}

			set bet_id [db_get_coln $rs 0 0]
			db_close $rs
			#
			# Need to record overrides here, if any has taken place
			# putting the newly produced bet_id against the overrides
			#
			check_overrides $sk $l $p $ev_oc_id $bet_id $bet_no
		}
	}

	set BSEL($b,bet_id) $bet_id

	lappend BSEL(BET_IDS) $bet_id
	incr CUST(bet_count)

	# Redeem tokens used
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		if {[OB_freebets::redeem_tokens $redeemList $bet_id] == "0"} {
			OT_LogWrite 1 "Failed to redeem tokens $redeemList for selection(s) $BSEL($sk,ids)"
			pb_err ERR BET_PLACE_FREEBET "Failed to redeem tokens" BET $bet_id
			return
		}
	}

	# Fire sportsbet triggers
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		set trig_list {SPORTSBET BET SPORTSBET1 BET1}

		#we now have a choice...
		# FREEBET_IN_TRAN = 1 (default)
		# if we choose check freebet triggers in the placebet transaction
		# we will be sure to roll back the pb_tran if anything goes wrong
		# with issuing new freebets.
		# FREEBET_IN_TRAN = 0
		# The bet would be placed regardless of whether there was a problem
		# issuing the freebets or not.
		# This will also decrease the length of time of the placebet txn and
		# reduce the likelyhood of locking on the liability tables

		if {[OT_CfgGet TOKENS_CONTRIBUTE_TO_FREEBETS 1]} {
			set stake $BSEL($b,stake)
		} else {
			set stake [expr {$BSEL($b,stake) - $BSEL($b,token_value)}]
		}

		if {$stake > 0} {
			if {[OT_CfgGet FREEBET_IN_TRAN 1]} {

				set check_action_fn "OB_freebets::check_action"

				OT_LogWrite 5 "Sending $trig_list to FreeBets , ids = $BSEL($sk,ids)"

				if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

					catch {unset FBDATA}

					set check_action_fn "::ob_fbets::go_check_action_fast"

					set FBDATA(lang)           $CUST(lang)
					set FBDATA(ccy_code)       $CUST(ccy_code)
					set FBDATA(country_code)   $CUST(country_code)

					_prepare_fb_data $BSEL($sk,ids) $sk $bet_no
				}

				if {[ ${check_action_fn} $trig_list \
							$CUST(cust_id) \
							$aff_id \
							$stake \
							$BSEL($sk,ids) \
							"" \
							"" \
							"" \
							$bet_id \
							"SPORTS" \
							"" \
							0 \
							$BSEL(source)] != 1} {
					OT_LogWrite 1 "Check action $trig_list failed"
					OT_LogWrite 1 "username : $CUST(username)"
					OT_LogWrite 1 "amount   : $BSEL($b,stake)"
					OT_LogWrite 1 "ids      : $BSEL($sk,ids)"
					pb_err ERR BET_PLACE_FREEBET "Failed to check new tokens" BET $bet_id
					return
				}
			} else {
				#we'll save these up and put them through if bet-placement
				#was successful
				lappend FREEBET_CHECKS $trig_list $stake $BSEL($sk,ids) $bet_id
			}
		}
	}


	#
	# We will add every bet we place to LBT_BET_QUEUE
	# IN pb_end we will then go through the list and do the
	# necessary liabilities work.
	#
	lappend LBT_BET_QUEUE $bet_no $sk

	# log 3 "bet_id $bet_id successfully placed"

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" &&
	    [OT_CfgGet USE_CUST_STATS 0] == 0 &&
	    [OT_CfgGet FREEBET_IN_TRAN 1]} {
			#
			# Update flags indicating tha channels bet through
			#

			set chan_bet_thru [OB_prefs::get_flag chan_bet_thru]
			ob::log::write INFO {for cust: $USER_ID chan_bet_thru: $BSEL(source)}
			if {[string first $BSEL(source) $chan_bet_thru] == -1} {
				OB_prefs::set_flag chan_bet_thru "$BSEL(source)$chan_bet_thru"
				ob::log::write INFO {for cust: $USER_ID ADDING channel: $BSEL(source)}
			}
	}


	#
	# Build the message which is sent to the bet ticker
	#

	set BP_MESSAGE [list]

	set canon_stake [expr {$BSEL($b,stake) / [::OB_ccy::rate $CUST(ccy_code)]}]
	set canon_stake [format %0.2f $canon_stake]

	lappend BP_MESSAGE\
		source   $BSEL(source)\
		bet_type $BSEL($b,bet_type)\
		stake    $canon_stake \
		bet_at   [clock format [clock seconds] -format "%H:%M:%S"]

	if {$CUST(acct_owner) == {F} && [lsearch [list STR VAR OCC REG LOG] $CUST(acct_owner_type)] != -1} {
		# B for LBO Fielding
		set channel B
	} else {
		set channel $BSEL(source)
	}

	if {[OT_CfgGet MONITOR 0]} {
		# Build up monitor message
		set mIdx $MONITOR_MSG(num_rows)

		set MONITOR_MSG($mIdx,cust_id)           $CUST(cust_id)
		set MONITOR_MSG($mIdx,cust_uname)        $CUST(username)
		set MONITOR_MSG($mIdx,cust_notifiable)   $CUST(notifyable)

		if {[OT_CfgGet EXTRA_BETTING_TICKER_DATA 0]} {
			set MONITOR_MSG($mIdx,cust_fname)        $CUST(fname)
			set MONITOR_MSG($mIdx,cust_lname)        $CUST(lname)
			set MONITOR_MSG($mIdx,cust_reg_code)     $CUST(code)
			set MONITOR_MSG($mIdx,cust_is_elite)     $CUST(elite)
			set MONITOR_MSG($mIdx,cust_country_code) $CUST(country_code)
			set MONITOR_MSG($mIdx,cust_postcode)     $CUST(addr_postcode)
			set MONITOR_MSG($mIdx,cust_email)        $CUST(email)
		} else {
			foreach v {fname lname reg_code is_elite country_code postcode email} {
				set MONITOR_MSG($mIdx,cust_$v) {}
			}
		}

		set MONITOR_MSG($mIdx,channel)           $channel
		set MONITOR_MSG($mIdx,bet_id)            $BSEL($b,bet_id)
		set MONITOR_MSG($mIdx,bet_type)          $BSEL($b,bet_type)
		set MONITOR_MSG($mIdx,bet_date)          [MONITOR::datetime_now]
		set MONITOR_MSG($mIdx,amount_usr)        $BSEL($b,stake)
		set MONITOR_MSG($mIdx,amount_sys)        $canon_stake
		set MONITOR_MSG($mIdx,ccy_code)          $CUST(ccy_code)
		set MONITOR_MSG($mIdx,stake_factor)      $CUST(max_stake_scale)
		set MONITOR_MSG($mIdx,liab_group)        $CUST(liab_group)
		set MONITOR_MSG($mIdx,leg_type)          $BSEL($b,leg_type)
		set MONITOR_MSG($mIdx,categorys)    [list]
		set MONITOR_MSG($mIdx,class_ids)    [list]
		set MONITOR_MSG($mIdx,class_names)  [list]
		set MONITOR_MSG($mIdx,type_ids)     [list]
		set MONITOR_MSG($mIdx,type_names)   [list]
		set MONITOR_MSG($mIdx,ev_ids)       [list]
		set MONITOR_MSG($mIdx,ev_names)     [list]
		set MONITOR_MSG($mIdx,ev_dates)     [list]
		set MONITOR_MSG($mIdx,mkt_ids)      [list]
		set MONITOR_MSG($mIdx,mkt_names)    [list]
		set MONITOR_MSG($mIdx,sln_ids)      [list]
		set MONITOR_MSG($mIdx,sln_names)    [list]
		set MONITOR_MSG($mIdx,prices)       [list]
		set MONITOR_MSG($mIdx,monitored)    [list]

		set MONITOR_MSG($mIdx,max_bet_allowed_per_line)  [format "%.2f" \
			$BSEL($sk,stk_max)]
		set MONITOR_MSG($mIdx,max_stake_percentage_used) [format "%.1f" \
			[expr {($BSEL($b,stake) * 100.00) / $BSEL($sk,stk_max)}]]
		set MONITOR_MSG($mIdx,num_slns) 0
	}

	set num_selns 0

	for {set s 0} {$s < $num_legs} {incr s} {

		for {set p 0} {$p < $BSEL($sk,$s,num_parts)} {incr p} {

			set seln_id $BSEL($sk,$s,$p,ev_oc_id)

			set price_type $BSEL($sk,$s,$p,price_type)

			if {$price_type == "L"} {
				set price_type "$BSEL($sk,$s,$p,lp_num)/$BSEL($sk,$s,$p,lp_den)"
			} elseif {$price_type == "G"} {
				set price_type "GP ($BSEL($sk,$s,$p,lp_num)/$BSEL($sk,$s,$p,lp_den))"
			} elseif {$price_type == "S"} {
				set price_type SP
			} elseif {$price_type == "N"} {
				set price_type NP
			} elseif {$price_type == "B"} {
				set price_type BP
			} elseif {$price_type == "1"} {
				set price_type FS
			} elseif {$price_type == "2"} {
				set price_type SS
			} elseif {$price_type == "D"} {
				set price_type DIV
			} else {
				set price_type -
			}

			incr num_selns

			lappend BP_MESSAGE\
				customer   $CUST(username)\
				category   $MSEL($seln_id,category)\
				class	   $MSEL($seln_id,class_name)\
				type       $MSEL($seln_id,type_name)\
				event      $MSEL($seln_id,ev_name)\
				event_time $MSEL($seln_id,ev_time)\
				market     $MSEL($seln_id,mkt_name)\
				selection  $MSEL($seln_id,oc_name)\
				price      $price_type


			# check whether additional customer data is to be sent to ticker
			# added for ladbrookes by Justin Hayes 18/10/01
			if {[OT_CfgGet EXTRA_BETTING_TICKER_DATA 0]} {

				# add extra data to ticker message
				set customername "$CUST(fname) $CUST(lname)"
				lappend BP_MESSAGE\
				custname   $customername\
				elite	   $CUST(elite)

				if {$CUST(code) != ""} {
					lappend BP_MESSAGE\
					code $CUST(code)
				}
			}

			# check whether key client data is to be sent to ticker
			# added for blueSq by Justin Hayes 23/10/01
			if {[OT_CfgGet KEY_CLIENT_TICKER_DATA 0]} {
				# add data to ticker message
				lappend BP_MESSAGE\
					stake_factor $CUST(max_stake_scale)
			}

			#Now build 'bet monitored info'. Should be really be done for the leg,
			#is done for the parts also to keep consistency with existing code.
			set cust_class_max_scale CUST(max_stake_scale)
			set monitored "N"

			set class_scale_idx [lsearch $limits $MSEL($seln_id,ev_class_id)]

			if {$class_scale_idx != -1} {
				set cust_class_max_scale [lindex $limits [expr {$class_scale_idx + 1}] ]
			}

			if {$cust_class_max_scale < 1 } {
				set monitored "Y"
			}

			if {[OT_CfgGet MONITOR 0]} {
				# Generate monitor message for the bet selection
				lappend MONITOR_MSG($mIdx,categorys)    $MSEL($seln_id,category)
				lappend MONITOR_MSG($mIdx,class_ids)    $MSEL($seln_id,ev_class_id)
				lappend MONITOR_MSG($mIdx,class_names)  $MSEL($seln_id,class_name)
				lappend MONITOR_MSG($mIdx,type_ids)     $MSEL($seln_id,ev_type_id)
				lappend MONITOR_MSG($mIdx,type_names)   $MSEL($seln_id,type_name)
				lappend MONITOR_MSG($mIdx,ev_ids)       $MSEL($seln_id,ev_id)
				lappend MONITOR_MSG($mIdx,ev_names)     $MSEL($seln_id,ev_name)
				lappend MONITOR_MSG($mIdx,ev_dates)     $MSEL($seln_id,ev_time)
				lappend MONITOR_MSG($mIdx,mkt_ids)      $MSEL($seln_id,ev_mkt_id)
				lappend MONITOR_MSG($mIdx,mkt_names)    $MSEL($seln_id,mkt_name)
				lappend MONITOR_MSG($mIdx,sln_ids)      $MSEL($seln_id,ev_oc_id)
				lappend MONITOR_MSG($mIdx,sln_names)    $MSEL($seln_id,oc_name)
				lappend MONITOR_MSG($mIdx,prices)       $price_type
				lappend MONITOR_MSG($mIdx,monitored)    $monitored
			}
		}
	}

	lappend BP_MESSAGE num_selns $num_selns

	if {[OT_CfgGet MONITOR 0]} {
		set MONITOR_MSG($mIdx,num_slns) $num_selns
		incr MONITOR_MSG(num_rows)
	}

	return $bet_id
}


proc OB_placebet::pb_end {} {

	global BSEL CUST
	global FBDATA
	variable pb_real
	variable FREEBET_CHECKS
	variable LBT_BET_QUEUE
	variable MSEL

	set pb_real 0

	# call to do all the singles liability work
	# and to send any messages to offline liability engines.
	do_liab_updates

	if {[catch {db_commit_tran} msg]} {
		log 2 "Failed to commit placebet transaction: $msg"
	}

	# Check campaign tracking, needed to be done outside bet transaction
	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] } {
		foreach sk $BSEL(sks) {
			for {set c 0} {$c < $BSEL($sk,num_bets_avail)} {incr c} {
				ob_camp_track::record_camp_action $CUST(cust_id) "BET" "OB" $BSEL($sk,bets,$c,bet_id)
			}
		}
	}

	# send message to router
	send_msg_bet

	#if we've chosen to calculate new freebets outside of the placebet txn
	#we should do it now
	if {[OT_CfgGet FREEBET_IN_TRAN 1] == 0 && [info exists FREEBET_CHECKS]} {

		set check_action_fn "OB_freebets::check_action"

		if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

			catch {unset FBDATA}

			set check_action_fn "::ob_fbets::go_check_action_fast"

			set FBDATA(lang)           $CUST(lang)
			set FBDATA(ccy_code)       $CUST(ccy_code)
			set FBDATA(country_code)   $CUST(country_code)
		}

		foreach {trig_list stk ids bet_id} $FREEBET_CHECKS {
			OT_LogWrite 5 "Sending $trig_list to FreeBets , ids = $ids - post transaction"

			if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

				# Initialize current selection key and current bet indexes
				set curr_sk -1
				set curr_bet -1

				# Search and find which selection key and bet index we are
				# interested on so that we can pass them to _prepare_fb_data
				for {set i 0} { $i < [llength $BSEL(sks)] } {incr i} {
					if { $ids == $BSEL($i,ids) } {
						set curr_sk $i
						for {set j 0} { $j < $BSEL($curr_sk,num_bets_avail) } {incr j} {
							if { [info exists BSEL($curr_sk,bets,$j,bet_placed)]\
						          && $BSEL($curr_sk,bets,$j,bet_placed) == 1 } {
							set curr_bet $j
							break
							}
						}
						break
					}
				}
				ob_log::write DEBUG {OB_placebet::pb_end > Current sk is $curr_sk and curr bet is $curr_bet}
				_prepare_fb_data $ids $curr_sk $curr_bet
			}

			if {[ ${check_action_fn} $trig_list \
			                               $CUST(cust_id) \
			                               $BSEL(aff_id) \
			                               $stk \
			                               $ids \
			                               "" \
			                               "" \
			                               "" \
			                               $bet_id \
			                               "SPORTS" \
							"" \
							0 \
							$BSEL(source)] != 1} {

				OT_LogWrite 1 "Check action $trig_list failed - POST TRANSACTION"
				OT_LogWrite 1 "username : $CUST(username)"
				OT_LogWrite 1 "amount   : $stk"
				OT_LogWrite 1 "ids      : $ids"
				break

			}
		}

		if {[OT_CfgGet USE_CUST_STATS 0] == 0} {

			#
			# Update flags indicating tha channels bet through

			set chan_bet_thru [OB_prefs::get_cust_flag $CUST(cust_id) chan_bet_thru]
			ob::log::write INFO {OB_placebet::pb_end - for cust: $CUST(cust_id) chan_bet_thru: $BSEL(source)}
			if {[string first $BSEL(source) $chan_bet_thru] == -1} {
				OB_prefs::set_cust_flag $CUST(cust_id) chan_bet_thru "$BSEL(source)$chan_bet_thru"
				ob::log::write INFO {OB_placebet::pb_end - for cust: $CUST(cust_id) ADDING channel: $BSEL(source)}
			}

		}

		unset FREEBET_CHECKS
	}

	set BSEL(total_stake) 0.00
	set BSEL(total_tax)   0.00
	set BSEL(total_paid)  0.00

	foreach sk $BSEL(sks) {

		log 3 "**************************************"
		log 3 "Bets placed:"
		for {set i 0} {$i < $BSEL($sk,num_bets_avail)} {incr i} {
			set b "$sk,bets,$i"
			if {$BSEL($b,bet_placed) == 0} {
				log 8 "bet $i,($BSEL($b,bet_name)) was available but not placed"
				continue
			}



			set bet_id $BSEL($b,bet_id)
			set BSEL($b,receipt) ""
			set BSEL($b,settled) N
			log 4 "bet $i, ($BSEL($b,bet_name)) placed, id $bet_id"

			if [catch {set rs [db_exec_qry pb_get_rcpt $bet_id]} msg] {
				pb_err ERR SYS "Failed to retrieve recipt no." SYS
			} else {
				if {[db_get_nrows $rs] == 1} {
					set BSEL($b,receipt)\
						[db_get_col $rs receipt]
					set BSEL($b,bet_date_informix)\
						[db_get_col $rs cr_date]
					set BSEL($b,bet_date)\
						[html_date $BSEL($b,bet_date_informix) shrttime]
					set BSEL(total_stake) [expr {$BSEL(total_stake) + $BSEL($b,stake)}]
					set BSEL(total_tax)   [expr {$BSEL(total_tax)   + $BSEL($b,tax)}]
					set BSEL(total_paid)  [expr {$BSEL(total_paid)  + $BSEL($b,total_paid)}]
					# These are the same values with the country info added for display purposes
					set BSEL($b,stake_per_line_disp)\
						[print_ccy $BSEL($b,stake_per_line) $CUST(ccy_code)]
 					set BSEL($b,stake_disp)\
						[print_ccy $BSEL($b,stake) $CUST(ccy_code)]
					set BSEL($b,tax_disp)\
						[print_ccy $BSEL($b,tax) $CUST(ccy_code)]
					if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
						set BSEL($b,total_paid_disp)\
							[print_ccy [max [expr {$BSEL($b,total_paid) - $BSEL($b,token_value)}] 0] $CUST(ccy_code)]
						set BSEL($b,token_value_disp)\
							[format "%.2f" $BSEL($b,token_value)]
					} else {
						set BSEL($b,total_paid_disp)\
							[print_ccy $BSEL($b,total_paid) $CUST(ccy_code)]
					}
					log 4 "Receipt number $BSEL($b,receipt)"
				}

				db_close $rs
			}
		}
		log 3 "**************************************"
	}

	set pb_real 0
}

proc OB_placebet::check_overrides {sk l p ev_oc_id ref_id bet_no {ref_key BET}} {
	global CUST PB_OVERRIDES

	#
	# Update the PB_OVERRIDES entries with the bet_id
	#

	if {![info exists PB_OVERRIDES(record)]} {
		set PB_OVERRIDES(record) [list]
	}

	if [info exists PB_OVERRIDES(OC,$ev_oc_id)] {
		foreach restriction $PB_OVERRIDES(OC,$ev_oc_id) {
			set item [list [get_override_op $restriction] {} $ref_id $ref_key [expr {$l + 1}] [expr {$p + 1}]]
			if {[lsearch -exact $PB_OVERRIDES(record) $item] < 0} {
				lappend PB_OVERRIDES(record) $item
			}
		}
	}

	if [info exists PB_OVERRIDES(PART,$sk,$l,$p)] {
		foreach restriction $PB_OVERRIDES(PART,$sk,$l,$p) {
			lappend PB_OVERRIDES(record) [list [get_override_op $restriction] {} $ref_id $ref_key [expr {$l + 1}] [expr {$p + 1}]]
		}
	}

	if [info exists PB_OVERRIDES(BET,$sk,bets,$bet_no)] {
		foreach restriction $PB_OVERRIDES(BET,$sk,bets,$bet_no) {
			set item [list [get_override_op $restriction] {} $ref_id $ref_key {} {}]
			if {[lsearch -exact $PB_OVERRIDES(record) $item] < 0} {
				lappend PB_OVERRIDES(record) $item
			}
		}
	}


	if [info exists PB_OVERRIDES(BET,0)] {
		foreach restriction $PB_OVERRIDES(BET,0) {
			set item [list [get_override_op $restriction] {} $ref_id $ref_key {} {}]
			if {[lsearch -exact $PB_OVERRIDES(record) $item] < 0} {
				lappend PB_OVERRIDES(record) $item
			}
		}
	}


}

proc OB_placebet::print_bet {sk bet_no} {

	global BSEL CUST
	set b $sk,bets,$bet_no

	log 3 "**************************************"
	log 3 "placing bet"
	log 3 "bet_type     $BSEL($b,bet_type)"
	log 3 "cust_id      $CUST(cust_id)"
	log 3 "uid          $BSEL($b,unique_id)"
	log 3 "stake pl     $BSEL($b,stake_per_line)"
	log 3 "num_lines    $BSEL($b,num_lines)"
	log 3 "stake        $BSEL($b,stake)"
	log 3 "tax          $BSEL($b,tax_type):$BSEL($b,tax_rate):$BSEL($b,tax)"
	log 3 "leg_type     $BSEL($b,leg_type)"

	# Print FreeBets tokens used
	if {[reqGetArg redeem_tokens] == "TRUE"} {
		log 3 "cust tokens       $BSEL($b,cust_token_ids)"
	}

	log 3 "max_payout   $BSEL($b,bet_max_payout)"
	log 3 "num_selns    $BSEL($sk,num_selns)"
	log 3 "num_legs     $BSEL($sk,num_legs)"

	set num_legs $BSEL($sk,num_legs)
	for {set l 0} {$l < $num_legs} {incr l} {
		log 3 "($l) leg_sort  $BSEL($sk,$l,leg_sort)"
		log 3 "($l) num_parts $BSEL($sk,$l,num_parts)"
		log 3 "($l) ev_desc   $BSEL($sk,$l,0,ev_name)"
		for {set p 0} {$p < $BSEL($sk,$l,num_parts)} {incr p} {
			set pk "$sk,$l,$p"
			log 3 "($l) ($p) ev_oc_id   $BSEL($pk,ev_oc_id)"
			log 3 "($l) ($p) oc_desc    $BSEL($pk,oc_name)"
			log 3 "($l) ($p) price_type $BSEL($pk,price_type)"
			log 3 "($l) ($p) lp_num     $BSEL($pk,lp_num)"
			log 3 "($l) ($p) lp_den     $BSEL($pk,lp_den)"
		}
	}
	log 3 "**************************************"
}


proc OB_placebet::pb_abort {} {

	variable pb_real

	set pb_real 0

	catch {db_rollback_tran}
}


#----------------------------------------------------------------------------
# checks to see whether variable stakes are enabled for this class
#----------------------------------------------------------------------------
proc OB_placebet::var_stakes_enabled {class_id} {
	if {
		([OT_CfgGet FUNC_VARIABLE_MAX_STAKES_FOR_ALL_CLASSES 0] == "1")
		||
		(
			[OT_CfgGet FUNC_VARIABLE_MAX_STAKES 0] == "1"
			&&
			[lsearch [OT_CfgGet VAR_MAX_STAKE_CLASSES [list]] $class_id] != -1
		)

	} {
		return 1
	} else {
		return 0
	}
}


#
# Sends bet message to router
#
proc OB_placebet::send_msg_bet {} {
	variable BP_MESSAGES
	variable MONITOR_MSG

	if {[OT_CfgGet MONITOR 0]} {
		# send to monitor
		for {set i 0} {$i < $MONITOR_MSG(num_rows)} {incr i} {
			MONITOR::send_bet \
				$MONITOR_MSG($i,cust_id) \
				$MONITOR_MSG($i,cust_uname) \
				$MONITOR_MSG($i,cust_fname) \
				$MONITOR_MSG($i,cust_lname) \
				$MONITOR_MSG($i,cust_reg_code) \
				$MONITOR_MSG($i,cust_is_elite) \
				$MONITOR_MSG($i,cust_notifiable) \
				$MONITOR_MSG($i,cust_country_code)\
				$MONITOR_MSG($i,cust_postcode)\
				$MONITOR_MSG($i,cust_email)\
				$MONITOR_MSG($i,channel) \
				$MONITOR_MSG($i,bet_id) \
				$MONITOR_MSG($i,bet_type) \
				$MONITOR_MSG($i,bet_date) \
				$MONITOR_MSG($i,amount_usr) \
				$MONITOR_MSG($i,amount_sys) \
				$MONITOR_MSG($i,ccy_code) \
				$MONITOR_MSG($i,stake_factor) \
				$MONITOR_MSG($i,num_slns) \
				$MONITOR_MSG($i,categorys) \
				$MONITOR_MSG($i,class_ids) \
				$MONITOR_MSG($i,class_names) \
				$MONITOR_MSG($i,type_ids) \
				$MONITOR_MSG($i,type_names) \
				$MONITOR_MSG($i,ev_ids) \
				$MONITOR_MSG($i,ev_names) \
				$MONITOR_MSG($i,ev_dates) \
				$MONITOR_MSG($i,mkt_ids) \
				$MONITOR_MSG($i,mkt_names) \
				$MONITOR_MSG($i,sln_ids) \
				$MONITOR_MSG($i,sln_names) \
				$MONITOR_MSG($i,prices) \
				$MONITOR_MSG($i,leg_type) \
				$MONITOR_MSG($i,liab_group)\
				$MONITOR_MSG($i,monitored) \
				$MONITOR_MSG($i,max_bet_allowed_per_line) \
				$MONITOR_MSG($i,max_stake_percentage_used)
		}

		# data no longer need
		array unset MONITOR_MSG
	}

	if {[OT_CfgGet MSG_SVC_ENABLE 1]} {
		# send msg to legacy ticker
		foreach M $BP_MESSAGES {
			log 20 "MSG: $M"
			eval [concat MsgSvcNotify bet $M]
		}
	}
}

#
# Sends alert message to router
#
proc OB_placebet::send_msg_alert {
	class_id
	class_name
	type_id
	type_name
	ev_id
	ev_name
	mkt_id
	mkt_name
	sln_id
	sln_name
	alert_code
} {

	if {[OT_CfgGet MONITOR 0]} {
		# send msg to monitor
		MONITOR::send_alert \
			$class_id \
			$class_name \
			$type_id \
			$type_name \
			$ev_id \
			$ev_name \
			$mkt_id \
			$mkt_name \
			$sln_id \
			$sln_name \
			$alert_code \
			[MONITOR::datetime_now]
	}

	if {[OT_CfgGet MSG_SVC_ENABLE 1]} {
		# send msg to legacy ticker
		MsgSvcNotify alert \
			class      $class_name \
			type       $type_name \
			event      $ev_name \
			market     $mkt_name \
			action     $alert_code \
			selection  $sln_name
	}
}

#
# In pb_end we want to do all liabilitity updates.
# This reduces the time we have locks on liability rows in the database.
#
# It is most beneficial doing this liabilities work all-at-once at the end
# when we are placing groups of bets.
#
# This proc will also queue the necessary messages with offline
# liabilities engines (if they exist).
#
proc OB_placebet::do_liab_updates {} {


	global BSEL CUST

	variable LBT_BET_QUEUE

	log 3 "OB_placebet::do_liab_updates -> doing liabilities updates for bets just placed."


	#
	# We need to do the appropriate liabilities work for
	# each bet just placed.
	#
	foreach {bet_no sk} $LBT_BET_QUEUE {
		log 10 "OB_placebet::do_liab_updates -> bet_no=$bet_no sk=$sk"

		#
		# Set some information we need for this bet
		#
		set pk          "$sk,0,0"
		set b           "$sk,bets,$bet_no"

		log 10 "OB_placebet::do_liab_updates -> pk=$pk b=$b"

		set bet_id      $BSEL($b,bet_id)
		set bet_type    $BSEL($b,bet_type)
		set leg_type    $BSEL($b,leg_type)
		set mkt_id      $BSEL($pk,ev_mkt_id)
		set leg_sort    $BSEL($sk,0,leg_sort)
		set num_selns   $BSEL($sk,num_selns)
		set acct_owner  $CUST(acct_owner)

		log 10 "OB_placebet::do_liab_updates -> bet_type=$bet_type mkt_id=$mkt_id leg_sort=$leg_sort leg_type=$leg_type num_selns=$num_selns"

		if {$bet_type == "SGL"} {

			#
			# If bet is a single fixed-odds bet (not *-cast) call the liability
			# update routines (unless both constraints are null and there's no APC)
			# We also omit this step for non-handicap based bets placed via Telebetting
			# But if a hedging bet has been placed via telebet, then do call the
			# liability update routines so that markets/selections can be reopened
			# if the hedged bet takes the liabilies back below the threshold.
			#

			if {$num_selns == 1 \
				&& (![OT_CfgGetTrue TELEBET] \
				|| ([OT_CfgGetTrue TELEBET] \
				&& [string first $leg_sort "AH/A2/WH/HL/hl"] >= 0) \
				|| ([OT_CfgGetTrue TELEBET] \
				&& $acct_owner == "Y"))} {

				#
				# This current bet is a single and we need to do some
				# singles liabilities work for it. If there is a singles
				# engine running then add it to that queue. Otherwise
				# we will do the liabilities work here by calling pb_do_liab.
				#
				if {[OT_CfgGet OFFLINE_LIAB_ENG_SGL 0]} {
					lbt_queue_bet $bet_type $bet_id $mkt_id
				} else {
					# a single bet without any liab engine ?
					pb_do_liab $sk $bet_no $leg_sort $leg_type
				}
			} else {
				log 10 "Not calling lbt_bet_upd (bet not a simple SGL or non-handicap telebetting bet)"
			}

		} else {

			#
			# This current bet is not a single - queue it
			# for the RUM engine ?
			#
			if {[OT_CfgGet OFFLINE_LIAB_ENG_RUM 0]} {
				lbt_queue_bet $bet_type $bet_id $mkt_id
			}
		}



	}

	log 10 "OB_placebet::do_liab_updates -> finished doing liabilities updates"
}

proc OB_placebet::apply_roving_liability {max_win e price_type} {
	global BSEL BET_TYPE CUST
	variable MSEL

	if {[OT_CfgGet FUNC_VARIABLE_MAX_STAKES_BY_TIME 0] == 0} {
		return $max_win
	}

	if {[lsearch [OT_CfgGet VAR_MAX_STAKE_CLASSES_BY_TIME {}] $MSEL($e,ev_class_id)] == -1} {
		return $max_win
	}

	set lp_avail Y
	if {[catch {set odds [expr {double($MSEL($e,lp_num)) / double($MSEL($e,lp_den)) + 1}]} msg]} {
		set lp_avail N
	}

	# Get the phase start times
	set ev_start_time $MSEL($e,start_time)
	set ev_start_day  [string range $ev_start_time 0 9]
	set phase_2_start [clock scan "$ev_start_day [OT_CfgGet PHASE_2_START]"]
	set phase_3_start [clock scan "$ev_start_day [OT_CfgGet PHASE_3_START]"]
	set current_time  [clock scan [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]

	if {$current_time < $phase_2_start} {
		log 15 "event is in phase 1"
		return [expr {$max_win * [OT_CfgGet PHASE_1_${price_type}_SCALE 1]}]
	} elseif {$current_time < $phase_3_start} {
		log 15 "event is in phase 2"
		return [expr {$max_win * [OT_CfgGet PHASE_2_${price_type}_SCALE 1]}]
	} else {
		log 15 "event is in phase 3"
		set odds_boundary_1 [OT_CfgGet HORSE_STAKE_ODDS_BOUNDARY_1 1]
		set odds_boundary_2 [OT_CfgGet HORSE_STAKE_ODDS_BOUNDARY_2 1]
		if {$lp_avail=="Y"} {
			if {$odds <= $odds_boundary_1} {
				log 15 "selection is in odds 1"
				return [expr {$max_win * [OT_CfgGet PHASE_3_ODDS_1_${price_type}_SCALE 1]}]
			} elseif {$odds <= $odds_boundary_2} {
				log 15 "selection is in odds 2"
				return [expr {$max_win * [OT_CfgGet PHASE_3_ODDS_2_${price_type}_SCALE 1]}]
			} else {
				log 15 "selection is in odds 3"
				return [expr {$max_win * [OT_CfgGet PHASE_3_ODDS_3_${price_type}_SCALE 1]}]
			}
		} else {
			if {$price_type == "SP"} {
				log 15 "no odds available - set to odds 3"
				return [expr {$max_win * [OT_CfgGet PHASE_3_ODDS_3_SP_SCALE]}]
			}
		}
	}

	return $max_win
}

proc OB_placebet::calculate_max_win {max_potential_win ew_factor cum_value lp_num lp_den e {price_type "LP"}} {
	global CUST

	if {$lp_num == ""} {
		set lp_num [OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 5]
	}

	if {$lp_den == ""} {
		set lp_den [OT_CfgGet MAX_WIN_SP_NO_LP_DEFAULT_NUM 2]
	}

	if {$CUST(max_stake_scale) != 0} {
		#divide cum "thing" by max stake scale factor
		set cum_value [expr {$cum_value / $CUST(max_stake_scale)}]
	}

	return [max 0 [expr {[expr {[expr {[OB_placebet::apply_roving_liability $max_potential_win $e $price_type] * $ew_factor}] - $cum_value}] * [expr {double($lp_den) / double($lp_num)}]}]]
}

proc OB_placebet::apply_sep_lp_sp_var_stakes {e max_potential_win ew_factor lp_num lp_den value cum_type {price_type "LP"}} {
	variable MSEL

	if {[OT_CfgGet VAR_STAKES_SEP_CUM_SP_LP Y] == "N"} {
		if {[info exists MSEL($e,${cum_type})]} {
			return [min $value [OB_placebet::calculate_max_win $max_potential_win $ew_factor $MSEL($e,$cum_type) $lp_num $lp_den $e $price_type]]
		}
	}

	return $value
}

#
# This proc checks if something is wrong with the feed and returns 1 if so
#
proc OB_placebet::check_panic_mode {} {

	set OXiRepClientMainName [OT_CfgGet PANIC_MODE_REP_CLIENTNAME "OXiDBSyncClient"]

	if {[catch {set rs [db_exec_qry pb_check_panic_mode $OXiRepClientMainName]} msg]} {
		pb_err ERR SQL_ERR "unable to run pb_check_panic_mode:$msg" SYS
		return 0
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {
		# no row in tOXiRepClientSess so we're not getting data via a feed,
		# so no need to panic
		db_close $rs
		return 0
	} elseif {$nrows > 1} {
		pb_err ERR SQL_ERR "pb_check_panic_mode received $nrows rows expected 1" SYS
		db_close $rs
		return 0
	}

	set repl_check_mode [db_get_col $rs 0 repl_check_mode]
	set repl_max_wait   [db_get_col $rs 0 repl_max_wait]
	set repl_max_lag    [db_get_col $rs 0 repl_max_lag]
	set last_msg_time   [db_get_col $rs 0 last_msg_time]
	set last_ping_time  [db_get_col $rs 0 last_ping_time]
	set current_lag     [db_get_col $rs 0 current_lag]

	set last_msg_id     [db_get_col $rs 0 last_msg_id]
	set head_msg_id     [db_get_col $rs 0 head_msg_id]

	set current_time [clock seconds]

	set last_msg_time_secs   [clock scan $last_msg_time]
	set last_ping_time_secs  [clock scan $last_ping_time]

	log 99 "last_msg_time_secs = $last_msg_time_secs last_ping_time_secs = $last_ping_time_secs"

	set lag_triggered  [expr {$current_lag > $repl_max_lag}]
	set msg_triggered  [expr {$current_time - $last_msg_time_secs > $repl_max_wait }]
	set ping_triggered [expr {$current_time - $last_ping_time_secs > $repl_max_wait }]

	# repl_check_mode == "Y" means we're for sure in panic mode
	# and "-" means that we're only in panic mode if the feed
	# is running behind or stopped working
	if {$repl_check_mode == "Y" ||
		($repl_check_mode == "-" &&
		 ($lag_triggered ||
		  ($ping_triggered && ($last_msg_id == $head_msg_id)) ||
		  $msg_triggered))} {
		log 3 "We are in panic mode"
		set ret 1
	} else {
		log 99 "We are not in panic mode"
		set ret 0
	}
	log 99 "Panic mode check params: repl_check_mode = $repl_check_mode\
			repl_max_wait = $repl_max_wait\
			repl_max_lag = $repl_max_lag\
			last_msg_time = $last_msg_time\
			last_ping_time = $last_ping_time\
			last_msg_id = $last_msg_id \
			head_msg_id = $head_msg_id \
			current_lag = $current_lag\
			lag_triggered = $lag_triggered\
			ping_triggered = $ping_triggered\
			msg_triggered = $msg_triggered"
	db_close $rs
	return $ret
}
