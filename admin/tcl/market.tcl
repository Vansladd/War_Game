# $Id: market.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::MARKET {

asSetAct ADMIN::MARKET::GoMkt            [namespace code go_mkt]
asSetAct ADMIN::MARKET::DoMkt            [namespace code do_mkt]
asSetAct ADMIN::MARKET::DoMktRule4       [namespace code do_mkt_rule4]
asSetAct ADMIN::MARKET::DoMktDiv         [namespace code do_mkt_div]
asSetAct ADMIN::MARKET::DispMktMBS       [namespace code disp_mkt_mbs]
asSetAct ADMIN::MARKET::DoMBSUpd         [namespace code do_upd_mkt_mbs]

#
# ----------------------------------------------------------------------------
# Add/Update market activator
# ----------------------------------------------------------------------------
#
proc go_mkt args {

	set mkt_id [reqGetArg MktId]

	if {$mkt_id == ""} {
		go_mkt_add
	} else {
		go_mkt_upd
	}
}

#
# ----------------------------------------------------------------------------
# Go to "add new market" page
# ----------------------------------------------------------------------------
#
proc go_mkt_add args {

	global DB

	tpSetVar opAdd 1

	set ev_id        [reqGetArg EvId]
	set ev_oc_grp_id [reqGetArg MktGrpId]


	#
	# Get setup information
	#
	set sql [subst {
		select
			c.sort csort,
			c.fc_stk_factor,
			c.tc_stk_factor,
			c.fc_min_stk_limit,
			c.tc_min_stk_limit,
			c.category,
			t.ltl_win_lp,
			t.ltl_win_sp,
			t.ltl_place_lp,
			t.ltl_place_sp,
			t.ltl_win_ep,
			t.ltl_place_ep,
			t.flags as ev_type_flags,
			e.desc desc,
			e.ev_type_id,
			e.channels,
			e.displayed,
			e.start_time,
			e.is_off,
			e.min_bet,
			e.max_bet
		from
			tEv      e,
			tEvType  t,
			tEvClass c
		where
			e.ev_id = $ev_id and
			e.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set ev_type_id    [db_get_col $res 0 ev_type_id]
	set csort         [db_get_col $res 0 csort]
	set start         [db_get_col $res 0 start_time]
	set is_off        [db_get_col $res 0 is_off]
	set ev_displayed  [db_get_col $res 0 displayed]

	tpBindString EvDesc               [db_get_col $res 0 desc]
	tpBindString ClassSort            $csort
	tpSetVar     ClassSort            $csort
	tpSetVar     Category             [db_get_col $res 0 category]
	tpBindString EvId                 $ev_id
	tpBindString TypeId               $ev_type_id
	tpBindString MktGrpId             $ev_oc_grp_id
	tpBindString EvMinBet             [db_get_col $res 0 min_bet]
	tpBindString EvMaxBet             [db_get_col $res 0 max_bet]
	tpBindString ClassFcStkFactor     [db_get_col $res 0 fc_stk_factor]
	tpBindString ClassTcStkFactor     [db_get_col $res 0 tc_stk_factor]
	tpBindString ClassFcMinStk        [db_get_col $res 0 fc_min_stk_limit]
	tpBindString ClassTcMinStk        [db_get_col $res 0 tc_min_stk_limit]
	tpBindString TypeWinLP            [db_get_col $res 0 ltl_win_lp]
	tpBindString TypeWinSP            [db_get_col $res 0 ltl_win_sp]
	tpBindString TypePlaceLP          [db_get_col $res 0 ltl_place_lp]
	tpBindString TypePlaceSP          [db_get_col $res 0 ltl_place_sp]
	tpBindString TypeWinEP            [db_get_col $res 0 ltl_win_ep]
	tpBindString TypePlaceEP          [db_get_col $res 0 ltl_place_ep]

	# "Early Prices Active" flag - defaults to N
	tpBindString MktEPActive N


	# If the event is displayed default the market to not displayed
	# and vice versa
	if {[OT_CfgGet MARKET_OPP_DISP 1]} {
		if {$ev_displayed == "Y"} {
			set mktdisp "N"
		} else {
			set mktdisp "Y"
		}
	} else {
		set mktdisp $ev_displayed
	}

	# used below
	set event_channels [db_get_col $res 0 channels]
	set ev_type_flags [db_get_col $res 0 ev_type_flags]

	db_close $res

	set def_liab_limit [OT_CfgGet DEFAULT_LIAB_LIMIT 3000]

	#
	# Get information about the market we're about to add
	#
	set sql [subst {
		select
			name,
			sort,
			type,
			xmul,
			channels,
			disporder,
			hcap_prc_lo,
			hcap_prc_hi,
			hcap_prc_adj,
			hcap_step,
			hcap_steal,
			min_spread_cap,
			max_spread_cap,
			acc_min,
			acc_max,
			NVL(mkt_max_liab, $def_liab_limit) mkt_max_liab,
			bir_index,
			bir_delay,
			win_lp,
			win_sp,
			place_lp,
			place_sp,
			win_ep,
			place_ep,
			least_max_bet,
			most_max_bet,
			oc_min_bet,
			oc_max_bet,
			sp_max_bet,
			oc_max_pot_win,
			max_multiple_bet,
			oc_ew_factor,
		    flags,
			dbl_res,
			blurb,
			pGetHierarchyBIRDelayLevel ("EVENT", $ev_id) as bir_hierarchy,
			pGetHierarchyBIRDelay ("EVENT", $ev_id) as bir_hierarchy_value
		from
			tEvOcGrp
		where
			ev_oc_grp_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_oc_grp_id]
	inf_close_stmt $stmt

	set mkt_sort     [db_get_col $res 0 sort]
	set mkt_type     [db_get_col $res 0 type]
	set mkt_channels [db_get_col $res 0 channels]

	set bir_delay     [db_get_col $res 0 bir_delay]
	set bir_hierarchy [db_get_col $res 0 bir_hierarchy]

	tpBindString MktName           [db_get_col $res 0 name]
	tpBindString MktOcGrpName      [db_get_col $res 0 name]
	tpBindString MktSpreadMinCap   [db_get_col $res 0 min_spread_cap]
	tpBindString MktSpreadMaxCap   [db_get_col $res 0 max_spread_cap]
	tpBindString MktAccMin         [db_get_col $res 0 acc_min]
	tpBindString MktAccMax         [db_get_col $res 0 acc_max]
	tpBindString MktXmul           [db_get_col $res 0 xmul]
	tpBindString MktLiabLimit      [db_get_col $res 0 mkt_max_liab]
	tpBindString MktDisporder      [db_get_col $res 0 disporder]
	tpBindString MktBirIndex       [db_get_col $res 0 bir_index]
	tpBindString MktBirDelay       $bir_delay
	tpBindString MktWinLP          [db_get_col $res 0 win_lp]
	tpBindString MktWinSP          [db_get_col $res 0 win_sp]
	tpBindString MktPlaceLP        [db_get_col $res 0 place_lp]
	tpBindString MktPlaceSP        [db_get_col $res 0 place_sp]
	tpBindString MktWinEP          [db_get_col $res 0 win_ep]
	tpBindString MktPlaceEP        [db_get_col $res 0 place_ep]
	tpBindString MktLeastMaxBet    [db_get_col $res 0 least_max_bet]
	tpBindString MktMostMaxBet     [db_get_col $res 0 most_max_bet]
	tpBindString MktMinBet         [db_get_col $res 0 oc_min_bet]
	tpBindString MktMaxBet         [db_get_col $res 0 oc_max_bet]
	tpBindString MktSPMaxBet       [db_get_col $res 0 sp_max_bet]
	tpBindString MktMaxPotWin      [db_get_col $res 0 oc_max_pot_win]
	tpBindString MktMaxMultipleBet [db_get_col $res 0 max_multiple_bet]
	tpBindString MktEachWayFactor  [db_get_col $res 0 oc_ew_factor]
	tpBindString MktDblRes         [db_get_col $res 0 dbl_res]
	tpBindString MktBlurb          [db_get_col $res 0 blurb]

	tpBindString BIRHierarchy      $bir_hierarchy
	tpBindString BIRHierarchyVal   [db_get_col $res 0 bir_hierarchy_value]

	if {$bir_delay == "" && $bir_hierarchy != ""} {
		tpSetVar displayBIRHierarchy 1
	}

	set win_lp            [db_get_col $res 0 win_lp]
	set win_sp            [db_get_col $res 0 win_sp]
	set place_lp          [db_get_col $res 0 place_lp]
	set place_sp          [db_get_col $res 0 place_sp]
	set win_ep            [db_get_col $res 0 win_ep]
	set place_ep          [db_get_col $res 0 place_ep]
	set least_max_bet     [db_get_col $res 0 least_max_bet]
	set most_max_bet      [db_get_col $res 0 most_max_bet]

	# If no market values, show type-level values for Lay to Lose
	if {$win_lp == ""} {
		tpSetVar WinLPAvail 0
	} else {
		tpSetVar WinLPAvail 1
	}

	if {$win_sp == ""} {
		tpSetVar WinSPAvail 0
	} else {
		tpSetVar WinSPAvail 1
	}

	if {$place_lp == ""} {
		tpSetVar PlaceLPAvail 0
	} else {
		tpSetVar PlaceLPAvail 1
	}

	if {$place_sp == ""} {
		tpSetVar PlaceSPAvail 0
	} else {
		tpSetVar PlaceSPAvail 1
	}
	if {$win_ep == ""} {
		tpSetVar WinEPAvail 0
	} else {
		tpSetVar WinEPAvail 1
	}
	if {$place_ep == ""} {
		tpSetVar PlaceEPAvail 0
	} else {
		tpSetVar PlaceEPAvail 1
	}

	# Flag to determine whether market is displayed expanded in
	# Endemol's Flash app
	if {[string match "*ME*" [db_get_col $res 0 flags]]} {
		tpBindString MktBirExpand "checked"
	}

	# Set default E/W With Bet to Y
	OT_LogWrite INFO "Setting default E/W With Bet to Y"
	tpBindString MktEWWithBet Y

	# Just adding this mkt so default to N (might not be using BIR)
	tpBindString MktBetInRun "N"
	#

	#default auto deadheat reduction to Yes
	tpBindString MktAutoDHRedn "Y"

	# If this is a FB event, prevent the addition of a new
	# active Win/Draw/Win market if one already exists
	#
	if {$csort == "FB" && $mkt_sort == "MR"} {
		set mr_sql [subst {
			select
				m.ev_mkt_id
			from
				tEv      e,
				tEvMkt  m
			where
				e.ev_id = $ev_id and
				e.ev_id = m.ev_id and
				m.sort = 'MR' and
				m.status = 'A'
		}]

		set mr_stmt [inf_prep_sql $DB $mr_sql]
		set mr_res  [inf_exec_stmt $mr_stmt]
		inf_close_stmt $mr_stmt

		if {[db_get_nrows $mr_res] > 0} {
			err_bind "Can only have one active Win/Draw/Win market for Football events."
			ADMIN::EVENT::go_ev
			return
		}

		db_close $mr_res
	}

	#
	# Default Asian-Handicap handicap value to 0 (to stop the drop-down
	# list starting at a silly extreme value...
	#
	if {$mkt_type == "A"} {
		tpBindString MktHcapValue 0
	}

	tpBindString MktSort  $mkt_sort
	tpSetVar     MktSort  $mkt_sort
	tpBindString MktType  $mkt_type
	tpSetVar     MktType  $mkt_type

	set chans_offered ""
	for {set i 0} {$i < [string length $event_channels]} {incr i} {
		set c [string range $event_channels $i $i]
		if {[string first $c $mkt_channels]>=0} {
			append chans_offered $c
		}
	}

	if {[OT_CfgGet PROPAGATE_CHAN 0]} {
		make_channel_binds ${chans_offered} $mkt_channels
	} else {
		make_channel_binds ${chans_offered} $event_channels$mkt_channels
	}

	ADMIN::MKTPROPS::make_mkt_binds $csort

	#
	# Optional configuration items to simplify market setup
	#
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort places] == "never"} {
		tpSetVar MktCanPlace 0
	} else {
		tpSetVar MktCanPlace 1
	}

	# If it's set in the config file, use that.
	# If not, use the opposite of the ev display property
	tpBindString MktDisplayed [ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort displayed $mktdisp]

	## get defualt bir status from the market config
	tpBindString MktBetInRun [ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort bir "N"]

	#
	# For a handicap market, set some initial defaults
	#
	if {[string first $mkt_type "AHLl"] >= 0} {
		tpBindString MktAHPrcChngAmt [db_get_col $res 0 hcap_prc_adj]
		tpBindString MktAHPrcLo      [db_get_col $res 0 hcap_prc_lo]
		tpBindString MktAHPrcHi      [db_get_col $res 0 hcap_prc_hi]
		tpBindString MktHcapStep     [db_get_col $res 0 hcap_step]
		tpBindString MktHcapSteal    [db_get_col $res 0 hcap_steal]
	} elseif {$mkt_type == "U"} {
		tpBindString MktHcapValue\
			[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort hcap_value]
	}

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	# Assume betting is open when adding a market so that it is possible to add
	# selections, handicap value, etc.
	tpSetVar BettingOpen 1

	#market flags logic
	if {[OT_CfgGet FUNC_MARKET_FLAGS 0]} {
		bind_market_flags "" [db_get_col $res 0 flags]
	}

	db_close $res

	# Default values of gp_avail based on
	# event type flags specified in GP_AVAIL_TYPE_FLAG_LIST
	if {$csort == "HR" || $csort == "GR"} {
		set gp_avail_type_flag_list [OT_CfgGet GP_AVAIL_TYPE_FLAG_LIST ""]
		OT_LogWrite  DEV  "EvType Flag List: $gp_avail_type_flag_list"
		set evtype_flag_list [split $ev_type_flags ,]
		foreach flag $gp_avail_type_flag_list {
			if {[lsearch $evtype_flag_list $flag] != -1} {
				tpBindString MktLPAvail "Y"
				tpBindString MktSPAvail "Y"
				tpBindString MktGPAvail "Y"
				break
			}
		}
	}

	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any dilldown items. Such as categories, classes types and
	# markets. and allow_dd_deletion is for deleting items
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	make_template_binds

	asPlayFile -nocache market.html
}


#
# ----------------------------------------------------------------------------
# Event select activator
# ----------------------------------------------------------------------------
#
proc go_mkt_upd args {

	global DB
	global DBL_RES
	global OC_VARIANTS
	global WDWMKTS
	global BF_MTCH
	global DH_REDN
	global USERID

	catch {unset WDWMKTS}

	tpSetVar opAdd 0

	set mkt_id [reqGetArg MktId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString MktId  $mkt_id

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			c.ev_class_id,
			c.fc_stk_factor as cfc_stk_factor,
			c.tc_stk_factor as ctc_stk_factor,
			c.fc_min_stk_limit as cfc_min_stk_limit,
			c.tc_min_stk_limit as ctc_min_stk_limit,
			c.category,
			t.ev_type_id,
			t.ltl_win_lp,
			t.ltl_win_sp,
			t.ltl_place_lp,
			t.ltl_place_sp,
			t.ltl_win_ep,
			t.ltl_place_ep,
			m.type,
			m.sort,
			m.xmul,
			m.status,
			m.displayed,
			m.disporder,
			m.fc_stk_factor,
			m.tc_stk_factor,
			m.fc_min_stk_limit,
			m.tc_min_stk_limit,
			e.ev_id,
			e.desc,
			e.start_time,
			e.is_off,
			e.channels event_channels,
			e.fb_dom_int,
			m.ext_key,
			m.tax_rate,
			m.lp_avail,
			m.sp_avail,
			m.gp_avail,
			m.ep_active,
			m.pm_avail,
			m.ew_avail,
			m.ew_places,
			m.ew_fac_num,
			m.ew_fac_den,
			m.ew_with_bet,
			m.pl_avail,
			m.fc_avail,
			m.tc_avail,
			m.acc_min,
			m.acc_max,
			m.hcap_value,
			m.hcap_step,
			m.hcap_steal,
			m.hcap_makeup,
			m.spread_lower,
			m.spread_upper,
			m.spread_makeup,
			m.min_spread_cap,
			m.max_spread_cap,
			m.result_conf,
			m.settled,
			m.channels,
			m.ev_oc_grp_id,
			m.is_ap_mkt,
			m.bir_index,
			m.bir_delay,
			m.flags,
			m.template_id,
			m.name mkt_name,
			g.name mkt_type_name,
			g.channels mkt_channels,
			m.blurb,
			m.feed_updateable,
			z.liab_limit,
			z.apc_status,
			z.apc_trigger,
			z.apc_margin,
			z.ah_prc_chng_amt,
			z.ah_prc_lo,
			z.ah_prc_hi,
			z.lp_bet_count,
			z.lp_win_stake,
			e.allow_stl,
			m.min_bet,
			m.max_bet,
			m.sp_max_bet,
			m.max_pot_win,
			m.max_multiple_bet,
			m.ew_factor,
			m.bet_in_run,
			m.dbl_res,
			m.auto_traded,
			m.req_guid,
			e.min_bet ev_min_bet,
			e.max_bet ev_max_bet,
			NVL(NVL(NVL(m.max_multiple_bet, e.max_multiple_bet), t.max_multiple_bet), 'n/a') f_max_multiple_bet,
			m.auto_dh_redn,
			m.stake_factor,
			pGetHierarchyBIRDelayLevel ("MKT", $mkt_id ) as bir_hierarchy,
			pGetHierarchyBIRDelay ("MKT", $mkt_id ) as bir_hierarchy_value
		from
			tEvClass     c,
			tEvType      t,
			tEv          e,
			tEvMkt       m,
			tEvOcGrp     g,
			tEvMktConstr z
		where
			m.ev_mkt_id    = ?        and
			m.ev_id        = e.ev_id        and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id  and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id    = z.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $mkt_id]
	inf_close_stmt $stmt

	# get lay to lose values from tLaytoLose
	set sql "select * from tLaytoLose where ev_mkt_id = $mkt_id"
	set stmt [inf_prep_sql $DB $sql]
	set res_ltl [inf_exec_stmt $stmt]
	if { [db_get_nrows $res_ltl] != 1 } { set res_ltl "" }
	inf_close_stmt $stmt
	#
	# Build information
	#
	set ev_id          [db_get_col $res 0 ev_id]
	set type_id        [db_get_col $res 0 ev_type_id]
	set mkt_channels   [db_get_col $res 0 mkt_channels]
	set event_channels [db_get_col $res 0 event_channels]
	set fb_dom_int     [db_get_col $res 0 fb_dom_int]
	set channels       [db_get_col $res 0 channels]
	set csort          [db_get_col $res 0 csort]
	set mkt_sort       [db_get_col $res 0 sort]
	set mkt_type       [db_get_col $res 0 type]
	set start          [db_get_col $res 0 start_time]
	set is_off         [db_get_col $res 0 is_off]
	set result_conf    [db_get_col $res 0 result_conf]
	set settled        [db_get_col $res 0 settled]
	set ew_avail       [db_get_col $res 0 ew_avail]
	set pl_avail       [db_get_col $res 0 pl_avail]
	set lp_avail       [db_get_col $res 0 lp_avail]
	set sp_avail       [db_get_col $res 0 sp_avail]
	set gp_avail       [db_get_col $res 0 gp_avail]
	set pm_avail       [db_get_col $res 0 pm_avail]
	set fc_avail       [db_get_col $res 0 fc_avail]
	set tc_avail       [db_get_col $res 0 tc_avail]
	set hcap_value     [db_get_col $res 0 hcap_value]
	set hcap_step      [db_get_col $res 0 hcap_step]
	set makeup_value   [db_get_col $res 0 hcap_makeup]
	set spread_value   [db_get_col $res 0 spread_makeup]
	set bet_in_run     [db_get_col $res 0 bet_in_run]
	set dbl_res        [db_get_col $res 0 dbl_res]
	set ew_fac_num     [db_get_col $res 0 ew_fac_num]
	set ew_fac_den     [db_get_col $res 0 ew_fac_den]
	set bir_delay      [db_get_col $res 0 bir_delay]
	set bir_hierarchy  [db_get_col $res 0 bir_hierarchy]

	if { $res_ltl != "" } {
		set win_lp          [db_get_col $res_ltl 0 win_lp]
		set win_sp          [db_get_col $res_ltl 0 win_sp]
		set place_lp        [db_get_col $res_ltl 0 place_lp]
		set place_sp        [db_get_col $res_ltl 0 place_sp]
		set win_ep          [db_get_col $res_ltl 0 win_ep]
		set place_ep        [db_get_col $res_ltl 0 place_ep]
		set least_max_bet   [db_get_col $res_ltl 0 min_bet]
		set most_max_bet    [db_get_col $res_ltl 0 max_bet]
	} else {
		set win_lp ""
		set win_sp ""
		set place_lp ""
		set place_sp ""
		set win_ep ""
		set place_ep ""
		set least_max_bet ""
		set most_max_bet ""
	}
	db_close $res_ltl

	# If no market values, show type-level values for Lay to Lose
	if {$win_lp == ""} {
		tpSetVar WinLPAvail 0
	} else {
		tpSetVar WinLPAvail 1
	}

	if {$win_sp == ""} {
		tpSetVar WinSPAvail 0
	} else {
		tpSetVar WinSPAvail 1
	}

	if {$place_lp == ""} {
		tpSetVar PlaceLPAvail 0
	} else {
		tpSetVar PlaceLPAvail 1
	}

	if {$place_sp == ""} {
		tpSetVar PlaceSPAvail 0
	} else {
		tpSetVar PlaceSPAvail 1
	}
	if {$win_ep == ""} {
		tpSetVar WinEPAvail 0
	} else {
		tpSetVar WinEPAvail 1
	}
	if {$place_ep == ""} {
		tpSetVar PlaceEPAvail 0
	} else {
		tpSetVar PlaceEPAvail 1
	}

	# If no market values, show class-level values for FC/TC stake limits
	set fc_stk_factor    [db_get_col $res 0 fc_stk_factor]
	set tc_stk_factor    [db_get_col $res 0 tc_stk_factor]
	set fc_min_stk_limit [db_get_col $res 0 fc_min_stk_limit]
	set tc_min_stk_limit [db_get_col $res 0 tc_min_stk_limit]
	foreach fctc {fc tc} {
		if {[set ${fctc}_stk_factor] == ""} {
			tpSetVar ${fctc}StkFactorAvail 0
		} else {
			tpSetVar ${fctc}StkFactorAvail 1
		}
		if {[set ${fctc}_min_stk_limit] == ""} {
			tpSetVar ${fctc}MinStkAvail 0
		} else {
			tpSetVar ${fctc}MinStkAvail 1
		}
	}

	set auto_dh_redn [db_get_col $res 0 auto_dh_redn]
	set auto_dh_redn [expr {[OT_CfgGet FUNC_AUTO_DH 0] ? $auto_dh_redn : "N"}]

	tpBindString MktAutoDHRedn $auto_dh_redn

	tpBindString EvId   $ev_id
	tpBindString TypeId $type_id

	if {[OT_CfgGet PROPAGATE_CHAN 0]} {
		make_channel_binds $channels ${mkt_channels}
	} else {
		make_channel_binds $channels ${mkt_channels}${event_channels}
	}

	ADMIN::MKTPROPS::make_mkt_binds $csort

	if {$bir_delay == "" && $bir_hierarchy != ""} {
		tpSetVar displayBIRHierarchy  1
		tpBindString BIRHierarchy     $bir_hierarchy
		tpBindString BIRHierarchyVal  [db_get_col $res 0 bir_hierarchy_value]
	}

	set class_id [db_get_col $res 0 ev_class_id]

	tpSetVar     ClassId             $class_id
	tpBindString ClassId             $class_id
	tpSetVar     Category            [db_get_col $res 0 category]
	tpBindString TypeId              [db_get_col $res 0 ev_type_id]
	tpBindString EvDesc              [db_get_col $res 0 desc]
	tpBindString MktName             [db_get_col $res 0 mkt_name]
	tpBindString MktOcGrpName        [db_get_col $res 0 mkt_type_name]
	tpBindString MktGrpId            [db_get_col $res 0 ev_oc_grp_id]
	tpBindString MktSort             $mkt_sort
	tpBindString MktType             $mkt_type
	tpBindString MktXmul             [db_get_col $res 0 xmul]
	tpBindString MktDisporder        [db_get_col $res 0 disporder]
	tpBindString MktDisplayed        [db_get_col $res 0 displayed]
	tpBindString MktStatus           [db_get_col $res 0 status]
	tpBindString MktTaxRate          [db_get_col $res 0 tax_rate]
	tpBindString MktExtKey           [db_get_col $res 0 ext_key]
	tpBindString MktLPAvail          $lp_avail
	tpBindString MktSPAvail          $sp_avail
	tpBindString MktGPAvail          $gp_avail
	tpBindString MktEPActive         [db_get_col $res 0 ep_active]
	tpBindString MktPMAvail          $pm_avail
	tpBindString MktEWAvail          $ew_avail
	tpBindString MktEWPlaces         [db_get_col $res 0 ew_places]
	tpBindString MktEWFacNum         [db_get_col $res 0 ew_fac_num]
	tpBindString MktEWFacDen         [db_get_col $res 0 ew_fac_den]
	tpBindString MktEWWithBet        [db_get_col $res 0 ew_with_bet]
	tpBindString MktPLAvail          $pl_avail
	tpBindString MktFCAvail          $fc_avail
	tpBindString MktTCAvail          $tc_avail
	tpBindString MktAccMin           [db_get_col $res 0 acc_min]
	tpBindString MktAccMax           [db_get_col $res 0 acc_max]
	tpBindString MktHcapValue        $hcap_value
	tpBindString MktHcapStep         $hcap_step
	tpBindString MktHcapSteal        [db_get_col $res 0 hcap_steal]
	tpBindString MktMakeupValue      $makeup_value
	tpBindString MktLiabLimit        [db_get_col $res 0 liab_limit]
	tpBindString MktAPCStatus        [db_get_col $res 0 apc_status]
	tpBindString MktAPCMargin        [db_get_col $res 0 apc_margin]
	tpBindString MktAPCTrigger       [db_get_col $res 0 apc_trigger]
	tpBindString MktAHPrcChngAmt     [db_get_col $res 0 ah_prc_chng_amt]
	tpBindString MktAHPrcLo          [db_get_col $res 0 ah_prc_lo]
	tpBindString MktAHPrcHi          [db_get_col $res 0 ah_prc_hi]
	tpBindString MktBlurb            [db_get_col $res 0 blurb]
	tpBindString MktSpreadValue      $spread_value
	tpBindString MktSpreadLowerQuote [db_get_col $res 0 spread_lower]
	tpBindString MktSpreadUpperQuote [db_get_col $res 0 spread_upper]
	tpBindString TypeWinLP           [db_get_col $res 0 ltl_win_lp]
	tpBindString TypeWinSP           [db_get_col $res 0 ltl_win_sp]
	tpBindString TypePlaceLP         [db_get_col $res 0 ltl_place_lp]
	tpBindString TypePlaceSP         [db_get_col $res 0 ltl_place_sp]
	tpBindString TypeWinEP           [db_get_col $res 0 ltl_win_ep]
	tpBindString TypePlaceEP         [db_get_col $res 0 ltl_place_ep]
	tpBindString MktSpreadMinCap     [db_get_col $res 0 min_spread_cap]
	tpBindString MktSpreadMaxCap     [db_get_col $res 0 max_spread_cap]
	tpBindString MktLPBetCount       [db_get_col $res 0 lp_bet_count]
	tpBindString MktLPWinStake       [db_get_col $res 0 lp_win_stake]
	tpBindString MktIsApMkt          [db_get_col $res 0 is_ap_mkt]
	tpBindString MktBirIndex         [db_get_col $res 0 bir_index]
	tpBindString MktBirDelay         $bir_delay
	tpBindString MktMinBet           [db_get_col $res 0 min_bet]
	tpBindString MktMaxBet           [db_get_col $res 0 max_bet]
	tpBindString MktSPMaxBet         [db_get_col $res 0 sp_max_bet]
	tpBindString MktMaxPotWin        [db_get_col $res 0 max_pot_win]
	tpBindString MktMaxMultipleBet   [db_get_col $res 0 max_multiple_bet]
	tpBindString MktEachWayFactor    [db_get_col $res 0 ew_factor]
	tpBindString MktBetInRun         $bet_in_run
	tpBindString MktAutoTraded       [db_get_col $res 0 auto_traded]
	tpBindString EvMaxBet            [db_get_col $res 0 ev_max_bet]
	tpBindString EvMinBet            [db_get_col $res 0 ev_min_bet]
	tpBindString FcStkFactor         $fc_stk_factor
	tpBindString TcStkFactor         $tc_stk_factor
	tpBindString FcMinStk            $fc_min_stk_limit
	tpBindString TcMinStk            $tc_min_stk_limit
	tpBindString ClassFcStkFactor    [db_get_col $res 0 cfc_stk_factor]
	tpBindString ClassTcStkFactor    [db_get_col $res 0 ctc_stk_factor]
	tpBindString ClassFcMinStk       [db_get_col $res 0 cfc_min_stk_limit]
	tpBindString ClassTcMinStk       [db_get_col $res 0 ctc_min_stk_limit]
	tpBindString MktDblRes           $dbl_res
	tpBindString FinalMaxMultipleBet [db_get_col $res 0 f_max_multiple_bet]
	tpBindString MktWinLP            $win_lp
	tpBindString MktWinSP            $win_sp
	tpBindString MktPlaceLP          $place_lp
	tpBindString MktPlaceSP          $place_sp
	tpBindString MktWinEP            $win_ep
	tpBindString MktPlaceEP          $place_ep
	tpBindString MktLeastMaxBet      $least_max_bet
	tpBindString MktMostMaxBet       $most_max_bet
	tpBindString MktFeedUpd          [db_get_col $res 0 feed_updateable]
	tpBindString ReqGUID            [db_get_col $res 0 req_guid]

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_MKT::bind_bf_mkt $ev_id $mkt_id
	}
	tpBindString MktStkFactor        [db_get_col $res 0 stake_factor]

	tpSetVar EvAllowSettle  [db_get_col $res 0 allow_stl]

	tpSetVar Confirmed [expr {$result_conf == "Y"}]
	tpSetVar Settled   [expr {$settled == "Y"}]
	tpSetVar ClassSort $csort
	tpSetVar HcapMkt   [expr {($mkt_sort=="A")||($mkt_sort=="H")}]
	tpSetVar EWAvail   [expr {$ew_avail == "Y"}]
	tpSetVar FCorTC    [expr {$fc_avail == "Y" || $tc_avail == "Y"}]
	tpSetVar MktSort   $mkt_sort
	tpSetVar MktType   $mkt_type


	make_template_binds [db_get_col $res 0 template_id]

	#market flags
	if {[OT_CfgGet FUNC_MARKET_FLAGS 0]} {
		bind_market_flags [db_get_col $res 0 flags]
	}

	#
	# Set up Bir specific stuff
	#

	# Flag to determine whether market is displayed expanded in
	# Endemol's Flash app
	if {[string match "*MFE*" [db_get_col $res 0 flags]]} {
		tpBindString MktBirExpand "checked"
	}

	if {$bet_in_run == "Y"} {
		tpSetVar MktBetInRun 1
	} else {
		tpSetVar MktBetInRun 0
	}

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	if {[string compare $start $now] <= 0} {
		if {$is_off == "N" || $bet_in_run == "Y"} {
			tpSetVar BettingOpen 1
		} else {
			tpSetVar BettingOpen 0
		}
		tpSetVar AfterEventStart 1
	} else {
		if {$is_off == "Y" && $bet_in_run == "N"} {
			tpSetVar BettingOpen 0
		} else {
			tpSetVar BettingOpen 1
		}
		tpSetVar AfterEventStart 0
	}

	db_close $res

	#
	# Play with the handicap value for handicap or higher/lower market...
	#
	if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
		switch -- $mkt_type {
			A {
				set hcap_side   [expr {($hcap_value < 0) ? "A" : "H"}]
				set hcap_value  [expr {round(abs($hcap_value))}]
			}
			H {
				set hcap_side   [expr {($hcap_value < 0) ? "A" : "H"}]
				set hcap_value  [expr {abs($hcap_value)}]
			}
			default {
				set hcap_side   ""
			}
		}
		tpBindString MktHcapSide $hcap_side
	} else {
		switch -- $mkt_type {
			A {
				set hcap_value [expr {round($hcap_value)}]
			}
			l {
				set hcap_value [ah_string $hcap_value]
			}
		}
	}
	tpBindString MktHcapValue   $hcap_value
	tpBindString MktMakeupValue $makeup_value

	set sql_sp {
		select
			Case
				when sp.special_type = "MBS" then '1'
				else '0'
			end as special_type
		from
			tSpecialOffer sp
		where
			sp.id    = ?  and
			sp.level = 'MARKET'
	}

	set stmt_sp [inf_prep_sql $DB $sql_sp]
	set res_sp [inf_exec_stmt $stmt_sp $mkt_id]
	inf_close_stmt $stmt_sp

	if {[db_get_nrows $res_sp] != 0} {
		tpBindString MBSmkt 1
	} else {
		tpBindString MBSmkt 0
	}

	#
	# Optional configuration items to simplify market setup
	#
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort places] == "never"} {
		tpSetVar MktCanPlace 0
	} else {
		tpSetVar MktCanPlace 1
	}

	if {[OT_CfgGet DISPLAY_HIERARCHY_STAKE_LIMITS 0] == 1} {
		set find_min_max_bets {
			NVL(NVL(o.max_bet, m.max_bet), e.max_bet) max_bet,
			NVL(NVL(o.min_bet, m.min_bet), e.min_bet) min_bet,}
	} else {
		set find_min_max_bets {o.min_bet, o.max_bet,}
	}

	#
	# Get selections for the market
	#
	set order_by "o.disporder asc, mr_order asc, prc_ord, o.desc"

	set sql [subst {
		select
			o.ev_oc_id,
			o.status,
			o.desc,
			o.result,
			o.result_conf,
			o.place,
			$find_min_max_bets
			o.sp_max_bet,
			o.max_place_lp,
			o.max_place_sp,
			o.ep_max_bet,
			o.max_place_ep,
			o.displayed,
			o.disporder,
			o.lp_num,
			o.lp_den,
			o.sp_num,
			o.sp_den,
			o.sp_num_guide,
			o.sp_den_guide,
			o.settled,
			o.hcap_score,
			o.has_oc_variants,
			z.max_total,
			z.lp_bet_count,
			z.lp_win_stake,
 			z.lp_win_liab,
 			case fb_result
 				when 'H' then 0
 				when 'D' then 1
 				when 'A' then 2
 			end mr_order,
 			case when (o.lp_num is not null and o.lp_den is not null) then
 				o.lp_num/o.lp_den
 					when (o.sp_num is not null and o.sp_den is not null) then
 				o.sp_num/o.sp_den
 					when (o.sp_num_guide is not null and o.sp_den_guide is not null) then
 				o.sp_num_guide/o.sp_den_guide
 					else
 				0
 			end prc_ord,
			count(d.ev_oc_id) as dbl_res_no
		from
			tEvOc    o,
			tEvMkt   m,
			tEv      e,
			outer tEvOcConstr z,
			outer tEvOcDblRes d
		where
			o.ev_mkt_id = $mkt_id     and
			m.ev_mkt_id = o.ev_mkt_id and
			e.ev_id     = m.ev_id     and
			o.ev_oc_id  = z.ev_oc_id  and
			o.ev_oc_id  = d.ev_oc_id
		group by
			1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
			16,17,18,19,20,21,22,23,24,25,26,27,28,29
		order by
			$order_by
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSelns [set nrows [db_get_nrows $res_seln]]
	#
	# We've set the market-related flags for after event start, confirmed
	# and settled, but we add a further twist by only allowing confirmation
	# if all selections have results...
	#
	if {$mkt_type != "S"} {
		if {[lsearch -exact [db_get_col_list $res_seln result] -] >= 0} {
			tpSetVar AllResultsSet 0
		} else {
			tpSetVar AllResultsSet 1
		}
	} else {
		# ... unless it's a spread bet market with no selections
		if {$spread_value!=""} {
			tpSetVar AllResultsSet 1
		} else {
			tpSetVar AllResultsSet 0
		}
	}

	#
	# Decide whether auto-generation of selections is to be offered - at
	# present this is only offered for football (class sort=FB),
	# on the following markets:
	#   - correct score (mkt sort=CS)
	#   - half-time/full-time (mkt sort=HF)
	#   - quatro (mkt sort=QR)
	#
	tpSetVar OfferAutoGen 0

	if {[tpGetVar NumSelns] == 0} {
		if {$csort == "FB"} {
			if {[lsearch -exact [list CS HF QR] $mkt_sort] >= 0} {
				tpSetVar OfferAutoGen 1
				tpSetVar AutoGenOK    0

				set NumWDWMkts 0
				set indx 0

				set wdw_check_sql {
					select
						ev_mkt_id,
						name
					from
						tEvMkt
					where
						ev_id = ? and
						sort = 'MR'
				}

				set stmt [inf_prep_sql $DB $wdw_check_sql]
				set mr [inf_exec_stmt $stmt $ev_id]
				inf_close_stmt $stmt

				if {[db_get_nrows $mr ] > 0} {

					set wdw_check_oc_sql {
							select count(*)
							from tEvOc o
							where
								o.ev_mkt_id = ? and
								o.fb_result <> '-'

					}
					set stmt [inf_prep_sql $DB $wdw_check_oc_sql]

					for {set i 0} {$i < [db_get_nrows $mr]} {incr i} {
						set res1 [ inf_exec_stmt $stmt [db_get_col $mr $i ev_mkt_id]]
						if { [db_get_coln $res1 0 0 ] == "3"} {

							set WDWMKTS($indx,name) [db_get_col $mr $i name]
							set WDWMKTS($indx,ev_mkt_id) [db_get_col $mr $i ev_mkt_id]
							incr NumWDWMkts
							incr indx

						}
						db_close $res1
					}
					inf_close_stmt $stmt
				}

				db_close $mr

				if { $NumWDWMkts > 0 } {

					if { $fb_dom_int != "-" || $mkt_sort == "QR" } {
						tpSetVar AutoGenOK 1
						tpSetVar NumWDWMkt $NumWDWMkts
						tpBindVar AutoGenMktId WDWMKTS ev_mkt_id auto_idx
						tpBindVar AutoGenMktName WDWMKTS name auto_idx
					}
				}
			}
		}
	}

	#
	# Decide whether cascading of WDW prices is to be offered.
	# i.e This button allows auto-generated prices to be re-generated.
	# Only display button if these are all true:
	#   - class sort = FB
	#   - mkt sort = MR (i.e. WDW)
	#   - all 3 WDW selections are available
	#   - at least one of the following mkt sorts is available on this event:
	#      - CS, HF
	#   - at least one of the above mkts has at least one selection set up
	#   - user has the UpdAutoGenEvOcPrices permission (check in html not here)
	#
	tpSetVar OfferCascade 0
	if {$csort == "FB" && $mkt_sort == "MR" && [tpGetVar NumSelns] == 3} {
		set cascade_check_sql {
			select
				count(*)
			from
				tEvMkt m
			where
				m.deriving_mkt_id = ? and
				m.ev_id = ? and
				m.sort in ('CS','HF')
		}
		set stmt [inf_prep_sql $DB $cascade_check_sql]
		set res [inf_exec_stmt $stmt $mkt_id $ev_id]
		inf_close_stmt $stmt
		if {[db_get_nrows $res] == 1 && [db_get_coln $res 0 0] > 0} {
			tpSetVar OfferCascade 1
		}
		db_close $res
	}

	# get dead heat reductions
	set do_auto_dh [expr {$auto_dh_redn == "Y" ? 1 : 0}]
	set dh_loaded  [ob_dh_redn::load "M" $mkt_id $do_auto_dh 1 0]

	if {!$dh_loaded} {
		err_bind [ob_dh_redn::get_err]
	}

	array set DH [ob_dh_redn::get_all]


	#
	# Make proper prices out of fractions from DB
	#
	global PRC SHOW

	set margin            0.0
	set place_margin      0.0
	set num_selns_no_rslt 0
	set num_selns_void    0

	for {set r 0} {$r < $nrows} {incr r} {

		set result  [db_get_col $res_seln $r result]
		set status  [db_get_col $res_seln $r status]
		set lp_num  [db_get_col $res_seln $r lp_num]
		set lp_den  [db_get_col $res_seln $r lp_den]
		set sp_num  [db_get_col $res_seln $r sp_num]
		set sp_den  [db_get_col $res_seln $r sp_den]
		set settled [db_get_col $res_seln $r settled]

		set ev_oc_id [db_get_col $res_seln $r ev_oc_id]
		set SHOWPT [ADMIN::SELN::do_show_price_check $ev_oc_id]
		set SHOW($r,fs) [lindex $SHOWPT 0]
		set SHOW($r,ss) [lindex $SHOWPT 1]

		# if status is suspended then show prices as N/A
		# reset lp_num to exclude it from margin calculations
		if {$status != "S" || $settled == "Y"} {
			set PRC($r,LP) [mk_price $lp_num $lp_den]
			set PRC($r,SP) [mk_price $sp_num $sp_den]
			if { $lp_num != "" && $ew_fac_num != "" && $lp_den != "" && $ew_fac_den != "" } {

				# Need to ensure price is in its lowest terms, e.g. 4/2 --> 2/1
				set place_lp_num [expr $lp_num * $ew_fac_num]
				set place_lp_den [expr $lp_den * $ew_fac_den]

				foreach {place_lp_num place_lp_den} [ob_price::simplify_price $place_lp_num $place_lp_den] {}

				set PRC($r,LPL) [mk_price $place_lp_num $place_lp_den]

			} else {
				set PRC($r,LPL) "N/A"
			}

		} else {
			set PRC($r,LP) "N/A"
			set PRC($r,SP) "N/A"
			set PRC($r,LPL) "N/A"
			set lp_num ""
		}

		if {$result == "-"} {
			incr num_selns_no_rslt
			if {$lp_num != ""} {
				set margin [expr {$margin+$lp_den/double($lp_num+$lp_den)}]
				if { $lp_num != "" && $ew_fac_num != "" && $lp_den != "" && $ew_fac_den != "" } {
					set place_margin [expr {$place_margin+double($lp_den*$ew_fac_den)/double(($lp_num*$ew_fac_num)+($lp_den*$ew_fac_den))}]
				}
			}
		} elseif {$result == "V"} {
			incr num_selns_void
		}

		if {$dbl_res == "Y"} {

			set dbl_res_no [db_get_col $res_seln $r dbl_res_no]

			if {$result != "-"} {
				if {$dbl_res_no != 2} {
					set DBL_RES($r,desc) "Complete (forced)"
				} else {
					set DBL_RES($r,desc) "Complete"
				}
			} elseif {$dbl_res_no == 2} {
				set DBL_RES($r,desc) "2 set"
			} elseif {$dbl_res_no == 1} {
				set DBL_RES($r,desc) "1 Set"
			} else {
				set DBL_RES($r,desc) "0 Set"
			}

		}

		# user_id is set to 0 as we only show information that has been double resulted
		set rs_key "$ev_oc_id,0"

		# Dead Heat Reductions
		foreach dh_type {W P} {

			set DH_REDN($r,${dh_type}_dh_redn) [list]

			ob_log::write DEV {[array names DH $dh_type,$rs_key,*]}

			foreach dh_key [array names DH $dh_type,$rs_key,*,dh_num] {

				regexp {^\w*,\w*,\w*,\w*} $dh_key dh_key

				set dh_num $DH($dh_key,dh_num)
				set dh_den $DH($dh_key,dh_den)

				# ignore even reductions
				if {$dh_num == $dh_den} {
					continue
				}
				lappend DH_REDN($r,${dh_type}_dh_redn) [mk_price $dh_num $dh_den]

			}

			set DH_REDN($r,${dh_type}_dh_redn) [join $DH_REDN($r,${dh_type}_dh_redn) ","]
		}
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_MKT::bind_bf_seln_det $mkt_id $order_by
	}

	if {$num_selns_void == $nrows} {
		tpBindString AllSelnsVoid 1
	} else {
		tpBindString AllSelnsVoid 0
	}
	tpSetVar     NumSelnsNoRslt $num_selns_no_rslt
	tpBindString NumSelnsNoRslt $num_selns_no_rslt

	if {$margin != 0.0} {
		tpBindString MktMargin [format %0.2f [expr {$margin*100.0}]]
	} else {
		tpBindString MktMargin ---
	}
	if {$place_margin != 0.0} {
		tpBindString MktPlaceMargin [format %0.2f [expr {$place_margin*100.0}]]
	} else {
		tpBindString MktPlaceMargin ---
	}

	tpBindTcl OcResult      sb_res_data $res_seln   seln_idx result
	tpBindTcl OcPlace       sb_res_data $res_seln   seln_idx place
	tpBindTcl OcHcapScore   sb_res_data $res_seln   seln_idx hcap_score
	tpBindTcl OcResultConf  sb_res_data $res_seln   seln_idx result_conf
	tpBindTcl OcDisplayed   sb_res_data $res_seln   seln_idx displayed
	tpBindTcl OcDisporder   sb_res_data $res_seln   seln_idx disporder
	tpBindTcl OcSettled     sb_res_data $res_seln   seln_idx settled
	tpBindTcl OcStatus      sb_res_data $res_seln   seln_idx status
	tpBindTcl OcId          sb_res_data $res_seln   seln_idx ev_oc_id
	tpBindTcl OcDesc        sb_res_data $res_seln   seln_idx desc
	tpBindVar OcLP          PRC         LP          seln_idx
	tpBindVar OcSP          PRC         SP          seln_idx
	tpBindVar OcLPL         PRC         LPL         seln_idx
	tpBindTcl OcMinBet      sb_res_data $res_seln   seln_idx min_bet
	tpBindTcl OcMaxBet      sb_res_data $res_seln   seln_idx max_bet
	tpBindTcl OcSpMaxBet    sb_res_data $res_seln   seln_idx sp_max_bet
	tpBindTcl OcMaxPlaceLP  sb_res_data $res_seln   seln_idx max_place_lp
	tpBindTcl OcMaxPlaceSP  sb_res_data $res_seln   seln_idx max_place_sp
	tpBindTcl OcEpMaxBet    sb_res_data $res_seln   seln_idx ep_max_bet
	tpBindTcl OcMaxPlaceEP  sb_res_data $res_seln   seln_idx max_place_ep
	tpBindTcl OcZMaxTotal   sb_res_data $res_seln   seln_idx max_total
	tpBindTcl OcZLPBetCount sb_res_data $res_seln   seln_idx lp_bet_count
	tpBindTcl OcZLPWinStake sb_res_data $res_seln   seln_idx lp_win_stake
	tpBindTcl OcZLPWinLiab  sb_res_data $res_seln   seln_idx lp_win_liab
	tpBindVar FSPriceSet    SHOW        fs          seln_idx
	tpBindVar SSPriceSet    SHOW        ss          seln_idx
	tpBindTcl OcHasOcVars   sb_res_data $res_seln seln_idx has_oc_variants
	tpBindVar OcWinDHRed    DH_REDN     W_dh_redn   seln_idx
	tpBindVar OcPlDHRed     DH_REDN     P_dh_redn   seln_idx

	if {$dbl_res == "Y"} {
		tpBindVar OcDblResDesc  DBL_RES     desc        seln_idx
	}

	#
	# if this is a pools market show a list of the pools that it
	# is part of
	#
	if {$pm_avail == "Y"} {
		set sql {
			select
				p.pool_id,
				p.name,
				m.leg_num,
				t.num_legs,
				t.disporder,
				p.displayed,
				p.status,
				p.is_void,
				p.result_conf,
				p.settled
			from
				tPoolMkt  m,
				tPool     p,
				tPoolType t
			where
				p.pool_id = m.pool_id
			and p.pool_type_id = t.pool_type_id
			and m.ev_mkt_id = ?
			order by
				t.disporder
		}

		set stmt [inf_prep_sql $DB $sql]
		set rpl  [inf_exec_stmt $stmt $mkt_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rpl]!=0} {
			tpSetVar HasPools Y
			tpSetVar NumPools [db_get_nrows $rpl]
			tpBindTcl PoolId         sb_res_data $rpl pool_idx pool_id
			tpBindTcl PoolName       sb_res_data $rpl pool_idx name
			tpBindTcl PoolLegNum     sb_res_data $rpl pool_idx leg_num
			tpBindTcl PoolNumLegs    sb_res_data $rpl pool_idx num_legs
			tpBindTcl PoolDisplayed  sb_res_data $rpl pool_idx displayed
			tpBindTcl PoolStatus     sb_res_data $rpl pool_idx status
			tpBindTcl PoolIsVoid     sb_res_data $rpl pool_idx is_void
			tpBindTcl PoolConfirmed  sb_res_data $rpl pool_idx result_conf
			tpBindTcl PoolSettled    sb_res_data $rpl pool_idx settled
		}

		#
		# If selections has no results and the users has permission allow them
		# to void all results. Allow them to void all pools without dividends.
		#

		if [op_allowed PoolVoidAll] {
			if {[regexp {^-+$} [join [db_get_col_list $res_seln result] ""]]} {
				tpSetVar VoidSelectionsButton 1
			}
			set sql {
				select 1
				from
					tPoolMkt  m,
					tPool     p
				where
					p.pool_id = m.pool_id
				and m.ev_mkt_id = ?
				and p.is_void = "N"
				and p.rec_dividend = "N"
				and p.result_conf = "N"
			}
			set stmt [inf_prep_sql $DB $sql]
			set vres [inf_exec_stmt $stmt $mkt_id]
			inf_close_stmt $stmt
			if {[db_get_nrows $vres] > 0} {
				tpSetVar VoidAllPoolsWithNoDiv 1
			}
		}

	}

	if {[string first $csort "HR/GR"] >= 0 && $mkt_type == "-"} {
		tpBindString SelColSpan [expr {$dbl_res=="Y"?24:23}]
	} else {
		tpBindString SelColSpan [expr {$dbl_res=="Y"?22:21}]
	}

	GC::mark DBL_RES

	# Find any selection variants for this market
	#--------------------------------------------
	if {[OT_CfgGet ENABLE_OC_VARIANTS 0] == 1} {

		set sql {
			SELECT
				e.desc,
				e.ev_oc_id,
				e.disporder,
				e.fb_result,
				v.price_num,
				v.price_den,
				v.value AS value,
				v.status,
				v.displayed,
				v.oc_var_id,
				v.disporder,
				v.max_bet,
				m.hcap_value,
				m.hcap_precision,
				m.sort as mkt_sort,
				m.type as mkt_type
			FROM
				tEvOc e,
				tEvOcVariant v,
				tEvMkt m
			WHERE
				e.ev_oc_id = v.ev_oc_id
			AND v.ev_mkt_id = ?
			AND m.ev_mkt_id = v.ev_mkt_id
			AND v.type = 'HC'
			ORDER BY
			v.disporder, v.value, e.disporder, e.ev_oc_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set ocv_rs [inf_exec_stmt $stmt $mkt_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $ocv_rs]

		set row_idx 0
		set next_seln_idx 0
		set hcap_idx 0

		catch {unset OC_VARIANTS}
		catch {unset SELN_IDX_MAP}

		while {$row_idx < $nrows} {
			set OC_VARIANTS($hcap_idx,value)           [db_get_col $ocv_rs $row_idx value]
			set hcap_value [db_get_col $ocv_rs $row_idx value]

			while {$row_idx < $nrows && $hcap_value == [db_get_col $ocv_rs $row_idx value]} {

				if {[info exists SELN_IDX_MAP([db_get_col $ocv_rs $row_idx ev_oc_id])]} {
					set seln_idx $SELN_IDX_MAP([db_get_col $ocv_rs $row_idx ev_oc_id])
				} else {
					set seln_idx [set SELN_IDX_MAP([db_get_col $ocv_rs $row_idx ev_oc_id]) $next_seln_idx]
					set SELN_IDX_MAP($seln_idx,selection) [db_get_col $ocv_rs $row_idx desc]
					incr next_seln_idx
				}
				set OC_VARIANTS($hcap_idx,$seln_idx,desc)            [db_get_col $ocv_rs $row_idx desc]
				set OC_VARIANTS($hcap_idx,$seln_idx,ev_oc_id)        [db_get_col $ocv_rs $row_idx ev_oc_id]
				set OC_VARIANTS($hcap_idx,$seln_idx,disporder)       [db_get_col $ocv_rs $row_idx disporder]
				set OC_VARIANTS($hcap_idx,$seln_idx,fb_result)       [db_get_col $ocv_rs $row_idx fb_result]
				set OC_VARIANTS($hcap_idx,$seln_idx,price_num)       [db_get_col $ocv_rs $row_idx price_num]
				set OC_VARIANTS($hcap_idx,$seln_idx,price_den)       [db_get_col $ocv_rs $row_idx price_den]
				set OC_VARIANTS($hcap_idx,$seln_idx,max_bet)         [db_get_col $ocv_rs $row_idx max_bet]
				set OC_VARIANTS($hcap_idx,$seln_idx,status)          [db_get_col $ocv_rs $row_idx status]
				set OC_VARIANTS($hcap_idx,$seln_idx,displayed)       [db_get_col $ocv_rs $row_idx displayed]
				set OC_VARIANTS($hcap_idx,$seln_idx,oc_var_id)       [db_get_col $ocv_rs $row_idx oc_var_id]
				set OC_VARIANTS($hcap_idx,$seln_idx,disporder)       [db_get_col $ocv_rs $row_idx disporder]
				set OC_VARIANTS($hcap_idx,$seln_idx,hcap_value)      [db_get_col $ocv_rs $row_idx hcap_value]
				set OC_VARIANTS($hcap_idx,$seln_idx,hcap_precision)  [db_get_col $ocv_rs $row_idx hcap_precision]
				set OC_VARIANTS($hcap_idx,$seln_idx,mkt_sort)        [db_get_col $ocv_rs $row_idx mkt_sort]
				set OC_VARIANTS($hcap_idx,$seln_idx,mkt_type)        [db_get_col $ocv_rs $row_idx mkt_type]

				if {[db_get_col $ocv_rs $row_idx value] == [db_get_col $ocv_rs $row_idx hcap_value]} {
					set OC_VARIANTS($hcap_idx,$seln_idx,pegged) 1
				} else {
					set OC_VARIANTS($hcap_idx,$seln_idx,pegged) 0
				}

				set ocv_row_value [db_get_col $ocv_rs $row_idx value]
				if {$ocv_row_value == "" } {
					set ocv_row_value 0
				}

				set OC_VARIANTS($hcap_idx,$seln_idx,hcap_value_fmt)\
				 [ADMIN::OC_VARIANTS::format_hcap_string\
				 	 [db_get_col $ocv_rs $row_idx mkt_sort]\
				 	 [db_get_col $ocv_rs $row_idx mkt_type]\
				 	 [db_get_col $ocv_rs $row_idx fb_result]\
				 	 [db_get_col $ocv_rs $row_idx value]\
				 	 [format "%0.[db_get_col $ocv_rs $row_idx hcap_precision]f"\
				 	 $ocv_row_value]]

				switch "$OC_VARIANTS($hcap_idx,$seln_idx,status),$OC_VARIANTS($hcap_idx,$seln_idx,displayed)" {
					"S,Y"   {set OC_VARIANTS($hcap_idx,$seln_idx,status_class) ocv_suspended}
					"S,N"   {set OC_VARIANTS($hcap_idx,$seln_idx,status_class) ocv_suspended}
					"A,N"   {set OC_VARIANTS($hcap_idx,$seln_idx,status_class) ocv_hidden}
					default {set OC_VARIANTS($hcap_idx,$seln_idx,status_class) ocv_active}
				}

				incr row_idx
			}
			incr hcap_idx
		}
		db_close $ocv_rs
		set OC_VARIANTS(num_hcaps)        $hcap_idx
		set OC_VARIANTS(num_selections)   $next_seln_idx

#		ob::log::write_array INFO OC_VARIANTS
#		ob::log::write_array INFO SELN_IDX_MAP

		tpBindString ocv_num_selns   $OC_VARIANTS(num_selections)
		tpBindString ocv_num_hcaps   $OC_VARIANTS(num_hcaps)

		tpBindVar ocv_value           OC_VARIANTS  value            ocv_hcap_idx
		tpBindVar ocv_selection       SELN_IDX_MAP selection        ocv_seln_idx

		tpBindVar ocv_desc            OC_VARIANTS  desc             ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_ev_oc_id        OC_VARIANTS  ev_oc_id         ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_disporder       OC_VARIANTS  disporder        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_fb_result       OC_VARIANTS  fb_result        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_price_num       OC_VARIANTS  price_num        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_price_den       OC_VARIANTS  price_den        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_max_bet         OC_VARIANTS  max_bet          ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_status          OC_VARIANTS  status           ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_displayed       OC_VARIANTS  displayed        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_oc_var_id       OC_VARIANTS  oc_var_id        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_disporder       OC_VARIANTS  disporder        ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_hcap_value      OC_VARIANTS  hcap_value       ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_hcap_precision  OC_VARIANTS  hcap_precision   ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_mkt_sort        OC_VARIANTS  mkt_sort         ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_mkt_type        OC_VARIANTS  mkt_type         ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_pegged          OC_VARIANTS  pegged           ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_hcap_value_fmt  OC_VARIANTS  hcap_value_fmt   ocv_hcap_idx ocv_seln_idx
		tpBindVar ocv_ocv_suspended   OC_VARIANTS  ocv_suspended    ocv_hcap_idx ocv_seln_idx
	}

	#
	#
	# If we've just come from the event list results page
	# we have to remember what the search criteria is to go
	# back to this page successfully.  If we've come from
	# anywhere else, these values will just be blank.
	# slee
	#

	if {$class_id == ""} {
		set class_id [reqGetArg ClassId]
	}
	tpBindString ClassId    $class_id
	tpBindString type_id    [reqGetArg type_id]
	tpBindString date_range [reqGetArg date_range]
	tpBindString date_lo    [reqGetArg date_lo]
	tpBindString date_hi    [reqGetArg date_hi]
	tpBindString settled    [reqGetArg settled]
	tpBindString status     [reqGetArg status]
	tpBindString allow_stl  [reqGetArg allow_stl]


	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any dilldown items. Such as categories, classes types and
	# markets. and allow_dd_deletion is for deleting items
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile -nocache market.html

	db_close $res_seln

	catch {unset PRC}
	catch {unset BF_MTCH_MKT}
}

#
# ----------------------------------------------------------------------------
# Add event activator
# ----------------------------------------------------------------------------
#
proc do_mkt args {

	set act [reqGetArg SubmitName]

	if {$act == "MktAdd"} {
		do_mkt_add
	} elseif {$act == "MktMod"} {
		do_mkt_upd
	} elseif {$act == "MktDel"} {
		do_mkt_del
	} elseif {$act == "EditRule4"} {
		go_mkt_rule4
	} elseif {$act == "EditDivs"} {
		go_mkt_div
	} elseif {$act == "MktConf"} {
		do_mkt_conf_yn Y
	} elseif {$act == "MktUnconf"} {
		do_mkt_conf_yn N
	} elseif {$act == "MktStl"} {
		do_mkt_stl
	} elseif {$act == "MktReStl"} {
		do_mkt_restl
	} elseif {$act == "MktStlSpread"} {
		do_mkt_stl_spread
	} elseif {$act == "MktReStlSpread"} {
		do_mkt_restl_spread
	} elseif {$act == "MktAutoGen"} {
		do_mkt_autogen
	} elseif {$act == "MktCascadeWDW"} {
		do_mkt_cascadewdw
	} elseif {$act == "MktAHApcLog"} {
		go_mkt_ah_apc_rpt
	} elseif {$act == "MktVoidAllSel"} {
		do_mkt_void_all_selections
	} elseif {$act == "MktSettleChk"} {
		ADMIN::SETTLE::add_mkt_stl_chk
	} elseif {$act == "Back"} {
		ADMIN::EVENT::go_ev
	} elseif {$act == "Refresh"} {
		go_mkt
	} elseif {$act == "LaytoLose"} {
		do_laytolose
		go_mkt
	} elseif {$act == "ProcessOcVariant"} {
		process_oc_variant_action
	} elseif {$act == "MktClone"} {
		do_mkt_clone
	} else {
		error "unexpected market operation SubmitName: $act"
	}
}


#
# ----------------------------------------------------------------------------
# Generate AH/WH auto price change log
# ----------------------------------------------------------------------------
#
proc go_mkt_ah_apc_rpt args {

	global DB AH

	set mkt_id [reqGetArg MktId]

	tpBindString MktId $mkt_id

	set sql_mkt [subst {
		select
			e.desc ev_name,
			e.start_time,
			g.name mkt_name
		from
			tEvMkt m,
			tEvOcGrp g,
			tEv e
		where
			m.ev_mkt_id = ? and
			m.ev_id = e.ev_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id
	}]

	set stmt [inf_prep_sql $DB $sql_mkt]
	set res  [inf_exec_stmt $stmt $mkt_id]
	inf_close_stmt $stmt

	tpBindString EvName   [db_get_col $res 0 ev_name]
	tpBindString EvStart  [db_get_col $res 0 start_time]
	tpBindString MktName  [db_get_col $res 0 mkt_name]

	db_close $res

	set sql_ah [subst {
		select
			h.hcappc_id,
			h.cr_date,
			h.ev_mkt_id,
			h.ev_oc_id,
			h.m_hcap_pre,
			h.m_stakes_pre,
			h.s_stakes_pre,
			h.s_liab_pre,
			h.s_prc_pre,
			h.m_hcap_post,
			h.m_stakes_post,
			h.s_stakes_post,
			h.s_liab_post,
			h.s_prc_post,
			h.b_stake,
			m.type,
			s.desc,
			s.fb_result
		from
			tHcapPrcChng h,
			tEvMkt m,
			tEvOc s
		where
			h.ev_mkt_id = ? and
			h.ev_mkt_id = m.ev_mkt_id and
			h.ev_oc_id = s.ev_oc_id
		order by
			h.hcappc_id
	}]

	set stmt [inf_prep_sql $DB $sql_ah]
	set res  [inf_exec_stmt $stmt $mkt_id]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	array set AH [list]

	for {set i 0} {$i < $n_rows} {incr i} {

		set AH($i,PCTime)           [db_get_col $res $i cr_date]
		set AH($i,PCTeam)           [db_get_col $res $i desc]
		set AH($i,PCBet)            [db_get_col $res $i b_stake]

		set m_hcap_pre              [db_get_col $res $i m_hcap_pre]
		set m_stakes_pre            [db_get_col $res $i m_stakes_pre]
		set s_stakes_pre            [db_get_col $res $i s_stakes_pre]
		set s_liab_pre              [db_get_col $res $i s_liab_pre]
		set s_prc_pre               [db_get_col $res $i s_prc_pre]
		set m_hcap_post             [db_get_col $res $i m_hcap_post]
		set m_stakes_post           [db_get_col $res $i m_stakes_post]
		set s_stakes_post           [db_get_col $res $i s_stakes_post]
		set s_liab_post             [db_get_col $res $i s_liab_post]
		set s_prc_post              [db_get_col $res $i s_prc_post]

		set s_fb_result             [db_get_col $res $i fb_result]
		set m_type                  [db_get_col $res $i type]

		set h_str_pre  [mk_hcap_str $m_type $s_fb_result $m_hcap_pre]
		set h_str_post [mk_hcap_str $m_type $s_fb_result $m_hcap_post]

		set AH($i,PCHcapPRE)        $h_str_pre
		set AH($i,PCTotMktStkPRE)   $m_stakes_pre
		set AH($i,PCTotSelStkPRE)   $s_stakes_pre
		set AH($i,PCTeamPayoutPRE)  $s_liab_pre
		set AH($i,PCTeamPricePRE)   $s_prc_pre
		set AH($i,PCNetLossPRE)     [expr {$s_liab_pre-$m_stakes_pre}]

		set AH($i,PCHcapPOST)       $h_str_post
		set AH($i,PCTotMktStkPOST)  $m_stakes_post
		set AH($i,PCTotSelStkPOST)  $s_stakes_post
		set AH($i,PCTeamPayoutPOST) $s_liab_post
		set AH($i,PCTeamPricePOST)  $s_prc_post
		set AH($i,PCNetLossPOST)    [expr {$s_liab_post-$m_stakes_post}]

		set hcap_delta [expr {$m_hcap_post-$m_hcap_pre}]

		set AH($i,PCHcapJumps) [format %d [expr {round($hcap_delta)}]]
	}

	db_close $res

	tpBindVar PCTime           AH PCTime           pc_idx
	tpBindVar PCTeam           AH PCTeam           pc_idx
	tpBindVar PCBet            AH PCBet            pc_idx

	tpBindVar PCHcapPRE        AH PCHcapPRE        pc_idx
	tpBindVar PCTotMktStkPRE   AH PCTotMktStkPRE   pc_idx
	tpBindVar PCTotSelStkPRE   AH PCTotSelStkPRE   pc_idx
	tpBindVar PCTeamPayoutPRE  AH PCTeamPayoutPRE  pc_idx
	tpBindVar PCTeamPricePRE   AH PCTeamPricePRE   pc_idx
	tpBindVar PCNetLossPRE     AH PCNetLossPRE     pc_idx

	tpBindVar PCHcapPOST       AH PCHcapPOST       pc_idx
	tpBindVar PCTotMktStkPOST  AH PCTotMktStkPOST  pc_idx
	tpBindVar PCTotSelStkPOST  AH PCTotSelStkPOST  pc_idx
	tpBindVar PCTeamPayoutPOST AH PCTeamPayoutPOST pc_idx
	tpBindVar PCTeamPricePOST  AH PCTeamPricePOST  pc_idx
	tpBindVar PCNetLossPOST    AH PCNetLossPOST    pc_idx

	tpSetVar NumPrcChngs $n_rows

	asPlayFile -nocache market_ah_rpt.html

	catch {unset AH}
}


#
# ----------------------------------------------------------------------------
# Add event activator
# ----------------------------------------------------------------------------
#
proc do_mkt_add args {

	global DB USERNAME

	set ev_id [reqGetArg EvId]

	set sql [subst {
		execute procedure pInsEvMkt(
			p_adminuser = ?,
			p_ev_id = ?,
			p_ev_oc_grp_id = ?,
			p_ext_key = ?,
			p_status = ?,
			p_sort = ?,
			p_xmul = ?,
			p_disporder = ?,
			p_displayed = ?,
			p_tax_rate = ?,
			p_ew_avail = ?,
			p_pl_avail = ?,
			p_ew_places = ?,
			p_ew_fac_num = ?,
			p_ew_fac_den = ?,
			p_ew_with_bet = ?,
			p_lp_avail = ?,
			p_sp_avail = ?,
			p_gp_avail = ?,
			p_ep_active = ?,
			p_pm_avail = ?,
			p_fc_avail = ?,
			p_tc_avail = ?,
			p_acc_min = ?,
			p_acc_max = ?,
			p_liab_limit = ?,
			p_apc_status = ?,
			p_apc_margin = ?,
			p_apc_trigger = ?,
			p_hcap_value = ?,
			p_hcap_step = ?,
			p_hcap_steal = ?,
			p_ah_prc_chng_amt = ?,
			p_ah_prc_lo = ?,
			p_ah_prc_hi = ?,
			p_spread_lower = ?,
			p_spread_upper = ?,
			p_spread_makeup	= ?,
			p_min_spread_cap = ?,
			p_max_spread_cap = ?,
			p_channels = ?,
			p_blurb = ?,
			p_is_ap_mkt = ?,
			p_bir_index = ?,
			p_bir_delay = ?,
			p_win_lp = ?,
			p_win_sp = ?,
			p_place_lp = ?,
			p_place_sp = ?,
			p_win_ep = ?,
			p_place_ep = ?,
			p_least_max_bet = ?,
			p_most_max_bet = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_ew_factor = ?,
			p_bet_in_run = ?,
			p_fc_stk_factor = ?,
			p_tc_stk_factor = ?,
			p_fc_min_stk_limit = ?,
			p_tc_min_stk_limit = ?,
			p_mkt_name = ?,
			p_dbl_res = ?,
			p_flags   = ?,
			p_feed_updateable = ?,
			p_template_id = ?,
			p_auto_dh_redn = ?,
			p_stake_factor = ?
		)
	}]

	set channels [make_channel_str]

	#
	# Some chicanery to sort out handicap markets: when the market type
	# is "A" or "H", we need to set the sign of the handicap value to
	# be -ve if the handicap is given away by the home side
	#
	set mkt_hcap_value [reqGetArg MktHcapValue]

	#
	# Hi-Lo-split ('l') markets haver the handicap string entered manually...
	#
	if {[reqGetArg MktType] == "l"} {
		set mkt_hcap_value [parse_hcap_str $mkt_hcap_value]
		if {$mkt_hcap_value < 0 } {
			err_bind "Higher/Lower (split) value cannot be negative"
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}

			go_mkt_add
			return
		}
	}

	if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
		if {[string first [reqGetArg MktType] "AH"] >= 0} {
			if {[reqGetArg MktHcapSide] == "A"} {
				set mkt_hcap_value [expr {0-$mkt_hcap_value}]
			}
		}
	}

	set stmt [inf_prep_sql $DB $sql]

	# Sets the money back special details
	set has_MBSmkt [reqGetArg MBSmkt]
	if {$has_MBSmkt == ""} {
		set has_MBSmkt 0
	}







	set bad 0

	inf_begin_tran $DB

	if {[OT_CfgGet DISPLAY_HIERARCHY_STAKE_LIMITS 0] == 1} {
		if {[reqGetArg MktLiabLimit] != ""} {
			set mkt_liab_limit_value [reqGetArg MktLiabLimit]
		} else {
			set mkt_liab_limit_value [reqGetArg MktLiabLimitDefault]
		}
	} else {
		set mkt_liab_limit_value [reqGetArg MktLiabLimit]
	}

	set bir_delay [reqGetArg MktBirDelay]


	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_mkt_add
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_mkt_add
			return
		}

	}


	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg EvId]\
			[reqGetArg MktGrpId]\
			[reqGetArg MktExtKey]\
			[reqGetArg MktStatus]\
			[reqGetArg MktSort]\
			[reqGetArg MktXmul]\
			[reqGetArg MktDisporder]\
			[reqGetArg MktDisplayed]\
			[reqGetArg MktTaxRate]\
			[reqGetArg MktEWAvail]\
			[reqGetArg MktPLAvail]\
			[reqGetArg MktEWPlaces]\
			[reqGetArg MktEWFacNum]\
			[reqGetArg MktEWFacDen]\
			[reqGetArg MktEWWithBet]\
			[reqGetArg MktLPAvail]\
			[reqGetArg MktSPAvail]\
			[reqGetArg MktGPAvail]\
			[reqGetArg MktEPActive]\
			[reqGetArg MktPMAvail]\
			[reqGetArg MktFCAvail]\
			[reqGetArg MktTCAvail]\
			[reqGetArg MktAccMin]\
			[reqGetArg MktAccMax]\
			$mkt_liab_limit_value\
			[reqGetArg MktAPCStatus]\
			[reqGetArg MktAPCMargin]\
			[reqGetArg MktAPCTrigger]\
			$mkt_hcap_value\
			[reqGetArg MktHcapStep]\
			[reqGetArg MktHcapSteal]\
			[reqGetArg MktAHPrcChngAmt]\
			[reqGetArg MktAHPrcLo]\
			[reqGetArg MktAHPrcHi]\
			[reqGetArg MktSpreadLowerQuote]\
			[reqGetArg MktSpreadUpperQuote]\
			[reqGetArg MktSpreadValue]\
			[reqGetArg MktSpreadMinCap]\
			[reqGetArg MktSpreadMaxCap]\
			$channels\
			[reqGetArg MktBlurb]\
			[reqGetArg MktIsApMkt]\
			[reqGetArg MktBirIndex]\
			$bir_delay\
			[reqGetArg win_lp]\
			[reqGetArg win_sp]\
			[reqGetArg place_lp]\
			[reqGetArg place_sp]\
			[reqGetArg win_ep]\
			[reqGetArg place_ep]\
			[reqGetArg InfMB]\
			[reqGetArg SupMB]\
			[reqGetArg MktMinBet]\
			[reqGetArg MktMaxBet]\
			[reqGetArg MktSPMaxBet]\
			[reqGetArg MktMaxPotWin]\
			[reqGetArg MktMaxMultipleBet]\
			[reqGetArg MktEachWayFactor]\
			[reqGetArg MktBetInRun]\
			[reqGetArg fc_stk_factor]\
			[reqGetArg tc_stk_factor]\
			[reqGetArg fc_min_stk]\
			[reqGetArg tc_min_stk]\
			[reqGetArg mkt_name]\
			[reqGetArg MktDblRes]\
			[make_mkt_flag_str]\
			[reqGetArg MktFeedUpd]\
			[reqGetArg SelTemplate]\
			[reqGetArg MktAutoDHRedn]\
			[reqGetArg MktStkFactor]]} msg]} {
		err_bind $msg
		set bad 1
	}

	if {!$bad} {
		set mkt_id [db_get_coln $res 0 0]
	}

	# Adds the money back special details to tSpecialOffer
	if {!$bad && $has_MBSmkt} {
		if {[catch {
			set passed [update_special_type "MARKET" $mkt_id "MBS" $special_langs 1 0 1]
			if {!$passed} {set bad  1}
		} msg]} {
			ob_log::write ERROR {Failed to set special type for event: $msg}
			err_bind "Failed to set special type for event: $msg"
			set bad 1
		}
	}


	inf_close_stmt $stmt

	if {$bad || [db_get_nrows $res] != 1} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_mkt_add
		return
	}

	inf_commit_tran $DB

	db_close $res

	#
	# Insertion was OK, go back to the market screen in update mode
	#
	tpSetVar MktAdded 1

	go_mkt_upd mkt_id $mkt_id
}


proc do_mkt_upd args {

	global DB USERNAME BF_PB_CAN

	set ev_id  [reqGetArg EvId]
	set mkt_id [reqGetArg MktId]

	# Check accumulator limits if they're set (if not, the stored_proc wont change them)
	# (Limits are in constraints cEvOcGrp_c6 and cEvOcGrp_c7)
	set acc_max [reqGetArg MktAccMax]
	set acc_min [reqGetArg MktAccMin]

	if {(($acc_max!="") || ($acc_min!="")) && (($acc_max > 25) || ($acc_max <1) || ($acc_min < 1) || ($acc_min > 25))} {
		err_bind "Accumulator limits must be between 1 and 25"

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_mkt
		return
	}

	set sql {
		execute procedure pUpdEvMkt(
			p_adminuser = ?,
			p_ev_mkt_id = ?,
			p_ext_key = ?,
			p_status = ?,
			p_sort = ?,
			p_xmul = ?,
			p_disporder = ?,
			p_displayed = ?,
			p_tax_rate = ?,
			p_ew_avail = ?,
			p_pl_avail = ?,
			p_ew_places = ?,
			p_ew_fac_num = ?,
			p_ew_fac_den = ?,
			p_ew_with_bet = ?,
			p_lp_avail = ?,
			p_sp_avail = ?,
			p_gp_avail = ?,
			p_ep_active = ?,
			p_pm_avail = ?,
			p_fc_avail = ?,
			p_tc_avail = ?,
			p_acc_min = ?,
			p_acc_max = ?,
			p_liab_limit = ?,
			p_apc_status = ?,
			p_apc_margin = ?,
			p_apc_trigger = ?,
			p_apc_reset = ?,
			p_hcap_value = ?,
			p_hcap_step = ?,
			p_hcap_steal = ?,
			p_hcap_makeup = ?,
			p_ah_prc_chng_amt = ?,
			p_ah_prc_lo = ?,
			p_ah_prc_hi = ?,
			p_spread_lower = ?,
			p_spread_upper = ?,
			p_spread_makeup = ?,
			p_min_spread_cap = ?,
			p_max_spread_cap = ?,
			p_channels = ?,
			p_blurb = ?,
			p_is_ap_mkt = ?,
			p_bir_index = ?,
			p_bir_delay = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_ew_factor = ?,
			p_bet_in_run = ?,
			p_fc_stk_factor = ?,
			p_tc_stk_factor = ?,
			p_fc_min_stk_limit = ?,
			p_tc_min_stk_limit = ?,
			p_flags = ?,
			p_mkt_name = ?,
			p_dbl_res = ?,
			p_feed_updateable = ?,
			p_template_id = ?,
			p_auto_dh_redn = ?,
			p_stake_factor = ?
		)
	}

	set channels [make_channel_str]

	#
	# Some chicanery to sort out handicap markets: when the market sort
	# is "AH" or "WH", we need to set the sign of the handicap value to
	# be -ve if the handicap applies to the away side
	#
	set mkt_hcap_value [reqGetArg MktHcapValue]

	#
	# Hi-Lo-split ('l') markets haver the handicap string entered manually...
	#
	if {[reqGetArg MktType] == "l"} {
		set mkt_hcap_value [parse_hcap_str $mkt_hcap_value]
		if {$mkt_hcap_value < 0 } {
			err_bind "Higher/Lower (split) value cannot be negative"
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}

			go_mkt
			return
		}
	}

	if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
		if {[reqGetArg MktHcapSide] == "A"} {
			set mkt_hcap_value [expr {0-$mkt_hcap_value}]
		}
	}

	set flags ""

	# Set up BIR Market expand flag
	# NB:  ME is the only flag ever used in tEvMkt/flags at this point
	if {[OT_CfgGetTrue FUNC_BIR_MKT_EXPAND]} {
		if {[reqGetArg MktBirExpand] == 1} {
			set flags "MFE"
		} else {
			set flags "MFC"
		}
	}

	if {[OT_CfgGet FUNC_MARKET_FLAGS 0]} {
		set suppl_flags [make_mkt_flag_str]
		if {$suppl_flags != ""} {
			set flags [append flags "," $suppl_flags]
		}
	}

	if {[ob_control::get allow_dd_creation] == "N"} {
		msg_bind "Not updating Each Way Terms - these will be updated by replication"
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

    	set bir_delay [reqGetArg MktBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_mkt_upd
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_mkt_upd
			return
		}

	}

	# Money Back Special
	set has_MBSmkt [reqGetArg MBSmkt]
	if {$has_MBSmkt == ""} {
		set has_MBSmkt 0
	}

	set sql_mbs {
		select
			lang
		from
			tSpecialOffer so
		where
			so.id     = ?
			and so.level = "EVENT"
			and so.special_type = "MBS";
	}

	set stmt_mbs     [inf_prep_sql $DB $sql_mbs]
	set rs_mbs       [inf_exec_stmt $stmt_mbs $ev_id]
	set nrows_mbs    [db_get_nrows $rs_mbs]
	ob_log::write INFO "Found $nrows_mbs lang rows for the MBS"
	set special_langs [list]
	for {set i 0} {$i < $nrows_mbs} {incr i} {
		lappend special_langs [db_get_col $rs_mbs $i lang]
	}
	ob_log::write INFO "Found $special_langs for the MBS"
	ob_db::rs_close $rs_mbs
	inf_close_stmt $stmt_mbs
	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktId]\
			[reqGetArg MktExtKey]\
			[reqGetArg MktStatus]\
			[reqGetArg MktSort]\
			[reqGetArg MktXmul]\
			[reqGetArg MktDisporder]\
			[reqGetArg MktDisplayed]\
			[reqGetArg MktTaxRate]\
			[reqGetArg MktEWAvail]\
			[reqGetArg MktPLAvail]\
			[reqGetArg MktEWPlaces]\
			[reqGetArg MktEWFacNum]\
			[reqGetArg MktEWFacDen]\
			[reqGetArg MktEWWithBet]\
			[reqGetArg MktLPAvail]\
			[reqGetArg MktSPAvail]\
			[reqGetArg MktGPAvail]\
			[reqGetArg MktEPActive]\
			[reqGetArg MktPMAvail]\
			[reqGetArg MktFCAvail]\
			[reqGetArg MktTCAvail]\
			[reqGetArg MktAccMin]\
			[reqGetArg MktAccMax]\
			[reqGetArg MktLiabLimit]\
			[reqGetArg MktAPCStatus]\
			[reqGetArg MktAPCMargin]\
			[reqGetArg MktAPCTrigger]\
			[reqGetArg MktAPCReset]\
			$mkt_hcap_value\
			[reqGetArg MktHcapStep]\
			[reqGetArg MktHcapSteal]\
			[reqGetArg MktMakeupValue]\
			[reqGetArg MktAHPrcChngAmt]\
			[reqGetArg MktAHPrcLo]\
			[reqGetArg MktAHPrcHi]\
			[reqGetArg MktSpreadLowerQuote]\
			[reqGetArg MktSpreadUpperQuote]\
			[reqGetArg MktSpreadValue]\
			[reqGetArg MktSpreadMinCap]\
			[reqGetArg MktSpreadMaxCap]\
			$channels\
			[reqGetArg MktBlurb]\
			[reqGetArg MktIsApMkt]\
			[reqGetArg MktBirIndex]\
			$bir_delay\
			[reqGetArg MktMinBet]\
			[reqGetArg MktMaxBet]\
			[reqGetArg MktSPMaxBet]\
			[reqGetArg MktMaxPotWin]\
			[reqGetArg MktMaxMultipleBet]\
			[reqGetArg MktEachWayFactor]\
			[reqGetArg MktBetInRun]\
			[reqGetArg fc_stk_factor]\
			[reqGetArg tc_stk_factor]\
			[reqGetArg fc_min_stk]\
			[reqGetArg tc_min_stk]\
			$flags\
			[reqGetArg mkt_name]\
			[reqGetArg MktDblRes]\
			[reqGetArg MktFeedUpd]\
			[reqGetArg SelTemplate]\
			[reqGetArg MktAutoDHRedn]\
			[reqGetArg MktStkFactor]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} elseif {[reqGetArg initial_MktLPAvail] == "N" && \
				[reqGetArg MktLPAvail] == "Y" && \
				[catch {do_laytolose} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		set bf_bad [ADMIN::BETFAIR_MKT::do_bf_mkt_upd $mkt_id]
	} else {
		set bf_bad 0
	}

	if {$bad == 0 && $bf_bad == 0} {
		# Turn off APC if market status is changed from Active to Suspended
		ADMIN::BETFAIR_MKT::upd_mkt_apc $mkt_id
	}

	# Stores any changes in the Money back special in tSpecialOffer
	if {!$bad} {
		if {[catch {
			if {$has_MBSmkt} {
				set passed [update_special_type "MARKET" $mkt_id "MBS" $special_langs 0 1 1]
			} else {
				set passed [update_special_type "MARKET" $mkt_id "" $special_langs 0 1 0]
			}
			if {!$passed} {set bad  1}
		} msg]} {
			ob_log::write ERROR {Failed to set special type for event: $msg}
			err_bind "Failed to set special type for event: $msg"
			set bad 1
		}
	}

	if {$bad || $bf_bad} {
		#
		# Something went wrong : go back to the market with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_mkt
		return
	}

	ADMIN::EVENT::go_ev
}

proc do_mkt_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelEvMkt(
			p_adminuser = ?,
			p_ev_mkt_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktId]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {!$bad} {
		set special_langs [make_special_langs_list]
		if {[catch {
			update_special_type "MARKET" [reqGetArg MktId] "" $special_langs 0 1 0
		} msg]} {
			ob_log::write ERROR {Failed to set special type for event: $msg}
			err_bind "Failed to set special type for event: $msg"
			set bad 1
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		ADMIN::EVENT::go_ev
		return
	}

	ADMIN::EVENT::go_ev
}

proc do_mkt_conf_yn conf_yn {

	global DB USERNAME

	set mkt_id [reqGetArg MktId]

	if {$conf_yn=="Y"} {

		#check any required dividends have been set before allowing confirmation
		set errors [check_market_dividend_set $mkt_id]

		if {$errors !=""} {
			err_bind $errors
			OT_LogWrite 30 "Result confirm attempted for ev_mkt_id:$mkt_id with forecast/tricast dividends unset"
			go_mkt
			return
		}

		# RT1819. If this is a Handicap market, force the user to set hcap_makeup
		# unless all the selections are void
		# (which is why this is not enforced in a constraint)
		set mkt_type        [reqGetArg MktType]
		set mkt_hcap_makeup [reqGetArg MktMakeupValue]
		if {[lsearch  {A H U L l M} $mkt_type] != -1} {
			set selections_are_void [reqGetArg AllSelnsVoid]
			if {$selections_are_void == "" || !$selections_are_void} {
				if {$mkt_hcap_makeup == ""} {
					set msg "Set handicap result to confirm results for a handicap market"
					err_bind $msg
					OT_LogWrite 30 $msg
					go_mkt
					return
				}
			}
		}

		#
		# Make sure the appropriate show prices have been set first
		# for certain racing selections... oh, how ugly is this?!
		#
		set sql [subst {
			select
					o.ev_oc_id,
					o.result,
					c.sort
			from
					tEvOc o,
					tEvClass c,
					tEv e,
					tEvType t
			where
					o.ev_id = e.ev_id
			and     e.ev_type_id = t.ev_type_id
			and     t.ev_class_id = c.ev_class_id
			and     o.ev_mkt_id = ?
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $mkt_id]
		inf_close_stmt $stmt
		set nrows [db_get_nrows $res]
		for {set i 0} {$i < $nrows} {incr i} {
			set sort [db_get_col $res $i sort]
			if {$sort!="GR" && $sort!="HR"} {
				break
			}
			set result [db_get_col $res $i result]
			if {$result=="W" || $result=="P"} {
				set show_prc_set [ADMIN::SELN::do_show_price_check [db_get_col $res $i ev_oc_id]]
				set fs [lindex $show_prc_set 0]
				set ss [lindex $show_prc_set 1]
				if { $fs == "N" || ($fs=="-" && $ss=="N")} {
					tpSetVar ShowPriceSet "Y"
					go_mkt_upd
					return
				}
			}
		}
		db_close $res
	}

	set sql [subst {
		execute procedure pSetResultConf(
			p_adminuser = ?,
			p_obj_type = ?,
			p_obj_id = ?,
			p_conf = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res  [inf_exec_stmt $stmt\
			$USERNAME\
			M\
			$mkt_id\
			$conf_yn]} msg]} {
		set bad 1
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	 if {$bad == 1} {
		err_bind "Failed to confirm results: $msg"
	}

	go_mkt
}


#
# ----------------------------------------------------------------------------
# Settle this market
# ----------------------------------------------------------------------------
#
proc do_mkt_stl args {

	global USERNAME
	set mkt_id [reqGetArg MktId]
	set errors [check_market_dividend_set $mkt_id]
	if {$errors != ""} {
		err_bind $errors
		OT_LogWrite 30 "Result confirm attempted for ev_mkt_id:$mkt_id with forecast/tricast dividends unset"
		go_mkt
		return
	}

	tpSetVar StlObj   market
	tpSetVar StlObjId $mkt_id
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

#
# ----------------------------------------------------------------------------
# Re-Settle this market
# ----------------------------------------------------------------------------
#
proc do_mkt_restl args {

	global USERNAME

	if {![op_allowed ReSettle]} {
		err_bind "You don't have permission to re-settle markets"
		do_mkt_upd
		return
	} else {
		do_mkt_stl
	}
}

#
# ----------------------------------------------------------------------------
# Settle this spread bet market
# ----------------------------------------------------------------------------
#
proc do_mkt_stl_spread args {

	global USERNAME

	tpSetVar StlObj   spread_market
	tpSetVar StlObjId [reqGetArg MktId]
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}


#
# ----------------------------------------------------------------------------
# Re-Settle this spread bet market
# ----------------------------------------------------------------------------
#
proc do_mkt_restl_spread args {

	global USERNAME

	if {![op_allowed ReSettle]} {
		err_bind "You don't have permission to re-settle markets"
		do_mkt_upd
		return
	} else {
		do_mkt_stl_spread
	}
}


#
# ----------------------------------------------------------------------------
# Show Rule 4 deductions
# ----------------------------------------------------------------------------
#
proc go_mkt_rule4 args {

	global DB

	set ev_id  [reqGetArg EvId]
	set mkt_id [reqGetArg MktId]

	set sql [subst {
		select
			d.ev_mkt_rule4_id,
			d.ev_mkt_id,
			s.desc,
			d.is_valid,
			d.market,
			d.time_from,
			d.time_to,
			d.deduction,
			d.comment
		from
			tEvMktRule4 d,
			outer tEvOc s
		where
			d.ev_mkt_id = $mkt_id and
			d.ev_oc_id  = s.ev_oc_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString EvId    $ev_id
	tpBindString MktId   $mkt_id
	tpBindString EvDesc  [reqGetArg EvDesc]
	tpBindString MktDesc [reqGetArg MktDesc]

	tpSetVar NumRule4s [db_get_nrows $res]

	tpBindTcl Rule4Id      sb_res_data $res rule4_idx ev_mkt_rule4_id
	tpBindTcl Rule4Seln    sb_res_data $res rule4_idx desc
	tpBindTcl Rule4Type    sb_res_data $res rule4_idx market
	tpBindTcl Rule4IsValid sb_res_data $res rule4_idx is_valid
	tpBindTcl Rule4DateLo  sb_res_data $res rule4_idx time_from
	tpBindTcl Rule4DateHi  sb_res_data $res rule4_idx time_to
	tpBindTcl Rule4Amount  sb_res_data $res rule4_idx deduction
	tpBindTcl Rule4Reason  sb_res_data $res rule4_idx comment

	asPlayFile -nocache market_rule4.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Update Rule 4 deductions
# ----------------------------------------------------------------------------
#
proc do_mkt_rule4 args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		go_mkt_upd
		return
	}

	if {![op_allowed ManageEvMkt]} {
		err_bind "You don't have permission to update rule 4s"
		go_mkt_rule4
		return
	}

	set ev_mkt_id [reqGetArg MktId]
	set r4_ids    [split [string trim [reqGetArg Rule4IdList]] ,]

	set r4_ids_to_del [list]
	set r4_ids_to_upd [list]

	#
	# see if any existing deduction lines need deleting
	#
	foreach id $r4_ids {
		set r4_amt     [string trim [reqGetArg Rule4Amount_$id]]

		if {$r4_amt == ""} {

			lappend r4_ids_to_del $id

		} else {

			foreach field {
				Rule4Type
				Rule4IsValid
				Rule4DateLo
				Rule4DateHi
				Rule4Amount
				Rule4Reason
			} {
				set f_new [string trim [reqGetArg   ${field}_$id]]
				set f_old [string trim [reqGetArg h_${field}_$id]]

				if {![string equal $f_new $f_old]} {
					lappend r4_ids_to_upd $id
					break
				}
			}
		}
	}

	set sql_r4 {
		execute procedure pDoEvMktRule4(
			p_adminuser = ?,
			p_transactional = 'N',
			p_op = ?,
			p_ev_mkt_rule4_id = ?,
			p_ev_mkt_id = ?,
			p_ev_oc_id = ?,
			p_is_valid = ?,
			p_market = ?,
			p_time_from = ?,
			p_time_to = ?,
			p_deduction = ?,
			p_comment = ?
		)
	}

	set stmt_r4 [inf_prep_sql $DB $sql_r4]

	inf_begin_tran $DB

	if {[catch {

		# delete anything which needs deleting

		foreach id $r4_ids_to_del {
			inf_exec_stmt $stmt_r4 $USERNAME D $id $ev_mkt_id
		}

		# conservatively update all remaining existing rule 4s

		foreach id $r4_ids_to_upd {

			inf_exec_stmt $stmt_r4 $USERNAME U $id $ev_mkt_id ""\
				[reqGetArg Rule4IsValid_$id]\
				[reqGetArg Rule4Type_$id]\
				[reqGetArg Rule4DateLo_$id]\
				[reqGetArg Rule4DateHi_$id]\
				[reqGetArg Rule4Amount_$id]\
				[reqGetArg Rule4Reason_$id]
		}

		# check to see whether new row is being inserted

		set r4_seln_id [string trim [reqGetArg NewRule4Seln]]
		set r4_valid   [string trim [reqGetArg NewRule4IsValid]]
		set r4_applic  [string trim [reqGetArg NewRule4Type]]
		set r4_date_lo [string trim [reqGetArg NewRule4DateLo]]
		set r4_date_hi [string trim [reqGetArg NewRule4DateHi]]
		set r4_amt     [string trim [reqGetArg NewRule4Amount]]
		set r4_comment [string trim [reqGetArg NewRule4Reason]]

		if {(($r4_date_lo != "") || ($r4_date_hi != "")) && ($r4_amt != "")} {

			inf_exec_stmt $stmt_r4 $USERNAME I ""\
				$ev_mkt_id\
				""\
				$r4_valid\
				$r4_applic\
				$r4_date_lo\
				$r4_date_hi\
				$r4_amt\
				$r4_comment

		}
	} msg]} {
		err_bind $msg
		inf_rollback_tran $DB
		inf_close_stmt $stmt_r4
		go_mkt_rule4
		return
	} else {
		inf_commit_tran $DB
		inf_close_stmt $stmt_r4
	}

	go_mkt_upd
}


#
# ----------------------------------------------------------------------------
# Show Dividends
# ----------------------------------------------------------------------------
#
proc go_mkt_div args {

	global DB

	if {[reqGetArg SubmitName] == "Back"} {
		go_mkt_upd
		return
	}

	set ev_id  [reqGetArg EvId]
	set mkt_id [reqGetArg MktId]

	tpBindString EvId    $ev_id
	tpBindString MktId   $mkt_id
	tpBindString EvDesc  [reqGetArg EvDesc]
	tpBindString MktDesc [reqGetArg MktDesc]

	#
	# Market setup info...
	#
	set sql [subst {
		select
			pm_avail
		from
			tEvMkt
		where
			ev_mkt_id = $mkt_id
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_mkt [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar PMAvail [expr {([db_get_col $res_mkt 0 pm_avail]=="Y")?1:0}]

	db_close $res_mkt


	#
	# Selection info...
	#
	set sql [subst {
		select
			ev_oc_id,
			desc
		from
			tEvOc
		where
			ev_mkt_id = $mkt_id
		order by
			desc
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSelns [db_get_nrows $res_seln]

	tpBindTcl OcListId   sb_res_data $res_seln seln_idx ev_oc_id
	tpBindTcl OcListDesc sb_res_data $res_seln seln_idx desc


	#
	# Dividends...
	#
	set sql [subst {
		select
			d.div_id,
			d.type,
			d.seln_1,
			s1.desc desc_1,
			d.seln_2,
			s2.desc desc_2,
			d.seln_3,
			s3.desc desc_3,
			d.dividend
		from
			tDividend   d,
			tEvOc       s1,
			outer tEvOc s2,
			outer tEvOc s3
		where
			d.ev_mkt_id = $mkt_id and
			d.seln_1 = s1.ev_oc_id and
			d.seln_2 = s2.ev_oc_id and
			d.seln_3 = s3.ev_oc_id
		order by
			2,1
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_div [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumDivs [db_get_nrows $res_div]

	tpBindTcl DivId     sb_res_data $res_div div_idx div_id
	tpBindTcl DivType   sb_res_data $res_div div_idx type
	tpBindTcl DivSeln1  sb_res_data $res_div div_idx desc_1
	tpBindTcl DivSeln2  sb_res_data $res_div div_idx desc_2
	tpBindTcl DivSeln3  sb_res_data $res_div div_idx desc_3
	tpBindTcl DivAmount sb_res_data $res_div div_idx dividend

	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile -nocache market_div.html

	db_close $res_seln
	db_close $res_div
}


#
# ----------------------------------------------------------------------------
# Update Dividends
# ----------------------------------------------------------------------------
#
proc do_mkt_div args {

	global DB USERID

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_mkt_upd
		return
	}

	if {![op_allowed SetResults]} {
		err_bind "You don't have permission to set dividends"
		go_mkt_div
		return
	}

	if {$act == "GoAuditMktDivDel"} {
		go_mkt_div_audit_del
		return
	}

	set ev_mkt_id [string trim [reqGetArg MktId]]
	set div_ids   [split [string trim [reqGetArg DivIdList]] ,]

	set div_ids_to_del [list]
	set div_ids_to_upd [list]


	# see if any existing dividend lines need deleting

	foreach id $div_ids {
		set div_amt [string trim [reqGetArg DivAmount_$id]]

		if {$div_amt == ""} {
			#
			# Don't allow onshore to delete dividends
			#
			if {[ob_control::get allow_dd_creation] == "Y"} {
				lappend div_ids_to_del $id
			} else {
				err_bind "You don't have permission to delete dividends onshore"
				go_mkt_div
				return
			}
		} else {
			lappend div_ids_to_upd $id
		}
	}

	set sql_d [subst {
		delete from tDividend
		where div_id in ([join $div_ids_to_del ,])
	}]

	set sql_u [subst {
		update tDividend set
			dividend = ?,
			user_id  = ?
		where
			div_id = ?
	}]

	#
	# Don't allow onshore to insert dividends
	#
	if {[ob_control::get allow_dd_creation] == "Y"} {
	set sql_i [subst {
		insert into tDividend (
			type, ev_mkt_id, seln_1, seln_2, seln_3, dividend, user_id
		) values (
			?, ?, ?, ?, ?, ?, ?
		)
	}]
	}

	inf_begin_tran $DB

	if {[catch {

		if [llength $div_ids_to_del] {
			set stmt [inf_prep_sql $DB $sql_d]
			inf_exec_stmt $stmt
			inf_close_stmt $stmt
		}

		# do any updates (this will update all existing rows - not optimal
		# but this is an infrequently trodden path...)

		if [llength $div_ids_to_upd] {

			set stmt [inf_prep_sql $DB $sql_u]

			foreach id $div_ids_to_upd {
				inf_exec_stmt $stmt [reqGetArg DivAmount_$id] $USERID $id
			}
			inf_close_stmt $stmt
		}

		# check to see whether new row is being inserted

		set div_type    [string trim [reqGetArg NewDivType]]
		set div_seln1   [string trim [reqGetArg NewDivSeln1]]
		set div_seln2   [string trim [reqGetArg NewDivSeln2]]
		set div_seln3   [string trim [reqGetArg NewDivSeln3]]
		set div_amt     [string trim [reqGetArg NewDivAmount]]

		if {$div_amt != ""} {

			set stmt [inf_prep_sql $DB $sql_i]

			inf_exec_stmt $stmt\
				$div_type\
				$ev_mkt_id\
				$div_seln1\
				$div_seln2\
				$div_seln3\
				$div_amt\
				$USERID

			inf_close_stmt $stmt
		}
	} msg]} {
		#
		# If an onshore user tries to insert then the sql_i is hidden and so
		# the transaction returns an error.  This error msg is changed to make
		# sense to the user.
		#
		if {$msg == {can't read "sql_i": no such variable}} {
			set msg "You don't have permission to insert dividends onshore"
		}
		err_bind $msg
		inf_rollback_tran $DB
		go_mkt_div
		return
	} else {
		inf_commit_tran $DB
	}

	go_mkt_upd
}


#
# ----------------------------------------------------------------------------
# Auto-generate market selections...
# ----------------------------------------------------------------------------
#
proc do_mkt_autogen {} {

	global DB

	set MktSort [reqGetArg MktSort]
	set EvId    [reqGetArg EvId]
	set MktId   [reqGetArg MktId]
	set Fave   [reqGetArg Fave]
	set WDWMktId [reqGetArg autogen_mkt_id]

	#
	# Force loading of chart info
	#
	ADMIN::FBCHARTS::fb_read_chart_info

	inf_begin_tran $DB

	set c [catch {
		if {$MktSort == "CS"} {
			ADMIN::FBCHARTS::fb_setup_mkt_CS $EvId $MktId $WDWMktId "INSERT" 1
		} elseif {$MktSort == "HF"} {
			ADMIN::FBCHARTS::fb_setup_mkt_HF $EvId $MktId $WDWMktId "INSERT" 1
		} elseif {$MktSort == "QR"} {
			ADMIN::FBCHARTS::fb_setup_mkt_QR $EvId $MktId $WDWMktId $Fave "INSERT" 1
		} else {
			error "can't auto-generate for $MktSort markets"
		}
	} msg]

	if {$c} {
		inf_rollback_tran $DB
		error $msg
	}

	inf_commit_tran $DB

	go_mkt_upd
}

#
# ----------------------------------------------------------------------------
# Cascade WDW prices down to auto-generated markets.
# i.e. Re-generate auto-generated prices.
# ----------------------------------------------------------------------------
#
proc do_mkt_cascadewdw {} {

	global DB

	set EvId    [reqGetArg EvId]
	set WDWMktId [reqGetArg MktId]

	#user input mkt_ids to cascade
	#prices

	if {!([op_allowed UpdAutoGenEvOcPrices] && [op_allowed UpdEvOcPrice])} {
			err_bind "You don't have permission to cascade prices"
			go_mkt_upd
			return
	}

	#
	# Force loading of CS/HF chart info
	#
	ADMIN::FBCHARTS::fb_read_chart_info

	set sql {
		select
			m.ev_mkt_id,
			m.sort
		from
			tEvMkt m
		where
			m.deriving_mkt_id = ? and
			m.ev_id = ? and
			m.sort in ('CS','HF')
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $WDWMktId $EvId]
	inf_close_stmt $stmt

	inf_begin_tran $DB

	set c [catch {
		# Loop over each market and call the relevant procedure:
		#    fb_update_mkt_CS
		#    fb_update_mkt_HF
		# Each market is guaranteed to have at least 1 selection
		# since we joined to tEvOc in the query above.
		for {set row 0} {$row<[db_get_nrows $res]} {incr row} {
			set MktId [db_get_col $res $row ev_mkt_id]
			set MktSort [db_get_col $res $row sort]
			if {$MktSort=="CS"} {
				ADMIN::FBCHARTS::fb_setup_mkt_CS $EvId $MktId $WDWMktId "UPDATE"
			} elseif {$MktSort=="HF"} {
				ADMIN::FBCHARTS::fb_setup_mkt_HF $EvId $MktId $WDWMktId "UPDATE"
			} else {
				error "Invalid market sort ($MktSort) for auto-generation"
			}

		}
	} msg]

	if {$c} {
		inf_rollback_tran $DB
		db_close $res
		error $msg
	}

	inf_commit_tran $DB

	db_close $res
	go_mkt_upd
}


####################################
proc process_oc_variant_action {} {
####################################
#----------------------------------------
# Add handicap variants in specified range
#----------------------------------------

	global USERNAME DB

	# Check the user has requisit permissions
	#---------------------------------------
	if {![op_allowed ManageOcVar]} {
		tpSetVar IsError 1
		tpBindString ErrMsg "You don't have permission to add market variants"
		go_mkt_upd
		return
	}

	set action [reqGetArg oc_var_action]

	switch -exact $action {

		AddHcapVarMkt {

			set mkt_id            [reqGetArg MktId]
			set max_hcap          [reqGetArg MaxHcapVariant]
			set min_hcap          [reqGetArg MinHcapVariant]
			set max_bet_hcap      [reqGetArg MaxBetHcapVariant]
			set increment         [reqGetArg VariantHcapIncr]
			set default_status    [reqGetArg VariantHcapStatus]

			#set default_price [split [reqGetArg VariantHcapPrice] /]
			set default_price     [get_price_parts [reqGetArg VariantHcapPrice]]
			set default_price_num [lindex $default_price 0]
			set default_price_den [lindex $default_price 1]

			set rtn [ADMIN::OC_VARIANTS::generate_hcap_variants\
				 $mkt_id\
				 $min_hcap\
				 $max_hcap\
				 $increment\
				 $default_status\
				 $default_price_num\
				 $default_price_den\
				 $max_bet_hcap]

			if {[lindex $rtn 0] == 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
			}
		}


		UpdateOcvSgl {

			set oc_var_id  [reqGetArg oc_var_id]
			set status     [reqGetArg ocv_status_$oc_var_id]
			set max_bet    [reqGetArg ocv_maxbet_$oc_var_id]
			#set price      [split [reqGetArg ocv_prc_$oc_var_id] /]
			set price      [get_price_parts [reqGetArg ocv_prc_$oc_var_id]]
			set price_num  [lindex $price 0]
			set price_den  [lindex $price 1]

			set rtn [ADMIN::OC_VARIANTS::update_ocvar\
				 $oc_var_id\
				 $status\
				 $price_num\
				 $price_den\
				 $max_bet]

			if {[lindex $rtn 0] == 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
			}
		}


		UpdateOcvAll {

			set err_str [list]
			for {set i 0} {$i < [reqGetNumVals]} {incr i} {
				if {[regexp {^ocv_id_([0-9]*)$} [reqGetNthName $i] match oc_var_id]} {
					set status     [reqGetArg ocv_status_$oc_var_id]
					set max_bet    [reqGetArg ocv_maxbet_$oc_var_id]
					set price      [split [reqGetArg ocv_prc_$oc_var_id] /]
					set price_num  [lindex $price 0]
					set price_den  [lindex $price 1]

					set rtn [ADMIN::OC_VARIANTS::update_ocvar\
						 $oc_var_id\
						 $status\
						 $price_num\
						 $price_den\
						 $max_bet]

					if {[lindex $rtn 0] == 0} {
						lappend err_str "[ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
					}
				}
			}
			if {[llength $err_str] > 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [join $err_str <br/>]"
			}
		}

		UpdOcvSelnEnabled {

			set err_str [list]
			for {set i 0} {$i < [reqGetNumVals]} {incr i} {
				if {[regexp {^ocv_seln_status_([0-9]*)$} [reqGetNthName $i] match ev_oc_id]} {
					set status     [reqGetArg ocv_seln_status_$ev_oc_id]

					set rtn [ADMIN::OC_VARIANTS::update_ocv_for_seln\
						 $ev_oc_id\
						 $status]

					if {[lindex $rtn 0] == 0} {
						lappend err_str "[ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
					}
				}
			}
			if {[llength $err_str] > 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [join $err_str <br/>]"
			}
		}

		ChangeMktValue {

			set old_value [reqGetArg oc_var_old_value]
			set new_value [reqGetArg ocv_hcap_$old_value]
			set mkt_id    [reqGetArg MktId]

			set rtn [ADMIN::OC_VARIANTS::change_market_value\
			 $mkt_id\
			 $old_value\
			 $new_value]

			if {[lindex $rtn 0] == 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
			}
		}

		DeleteMktValue {

			set value [reqGetArg oc_var_old_value]
			set mkt_id    [reqGetArg MktId]

			set rtn [ADMIN::OC_VARIANTS::delete_market_value\
				 $mkt_id\
				 $value]

			if {[lindex $rtn 0] == 0} {
				tpSetVar IsError 1
				tpBindString ErrMsg "An Error Occured, Action aborted : [ADMIN::OC_VARIANTS::get_err_defn [lindex $rtn 1]]"
			}
		}
	}

	go_mkt_upd
}



#
# ----------------------------------------------------------------------------
# Void all selections
# ----------------------------------------------------------------------------
#

proc do_mkt_void_all_selections {} {

	global USERNAME DB

	if {![op_allowed PoolVoidAll]} {
		error "You don't have permission to void all selections"
		go_mkt_upd
	}

	set mkt_id [reqGetArg MktId]

	#
	# Get all unset unconfirmed results
	#
	set sql [subst {
		select
			o.ev_oc_id,
			o.result,
			o.result_conf
		from
			tEvOc o
		where
			o.ev_mkt_id = $mkt_id and
			o.result = '-' and
			o.result_conf = 'N'
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $res_seln]

	set upd [subst {
		execute procedure pSetEvOcResult(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_result = ?
		)
	}]

	set updstmt [inf_prep_sql $DB $upd]

	#
	# Void the results
	#

	for {set i 0} {$i < $nrows} {incr i} {

		set ev_oc_id [db_get_col $res_seln $i ev_oc_id]

		inf_begin_tran $DB

		if {[catch {
			inf_exec_stmt $updstmt\
				$USERNAME\
				$ev_oc_id\
				"V"} msg]} {
					inf_rollback_tran $DB
					error $msg
					break
		} else {
					inf_commit_tran $DB
		}

	}

	inf_close_stmt $stmt
	inf_close_stmt $updstmt

	go_mkt_upd

}

proc check_market_dividend_set {mkt_id} {

	global DB

	#first check if forecasts and/or tricasts are allowed for this market
	set sql [subst {
		select
			fc_avail,
			tc_avail
		from
			tEvMkt
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $mkt_id]
	inf_close_stmt $stmt
	set fc_available [db_get_col $res 0 fc_avail]
	set tc_available [db_get_col $res 0 tc_avail]
	db_close $res


	#if forecast and/or tricasts are allowed then see if there are dividends set
	set errors ""
	if {$fc_available == "Y" && ![check_dividend_set $mkt_id "FC"]} {
		append errors "<BR> &nbsp;&nbsp;&nbsp;&nbsp;Can't confirm/settle results until forecast dividends are set"
	}
	if {$tc_available == "Y" && ![check_dividend_set $mkt_id "TC"]} {

		append errors "<BR> &nbsp;&nbsp;&nbsp;&nbsp;Can't confirm/settle results until tricast dividends are set"
	}
	return $errors
}

#
# Checks to see if a dividend of a given type for a certain market id exists
# returns 1 if at least one dividend exists, else returns 0
#
proc check_dividend_set {ev_mkt_id type} {

	global DB

	set sql [subst {
		select
			count(*)
		from
			tDividend
		where
			ev_mkt_id = ? and
			type = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_mkt_id $type]
	inf_close_stmt $stmt
	if {[db_get_col $res 0 "(count(*))"] == 0} {
		return 0
	} else {
		return 1
	}

}

#
# ----------------------------------------------------------------------------
# Gets a list of div_ids associated with the dividends that have been deleted
# within a particualr market & displays their audit details
# ----------------------------------------------------------------------------
#
proc go_mkt_div_audit_del {} {
	global DB

	set div_list    [reqGetArg DivIdList]
	set mkt_id      [reqGetArg MktId]

	set div_del_list [list]

	if {[llength $div_list] < 1} {
		set where ""
	} else {
		set where " and div_id not in ($div_list)"
	}

	# Get all the deleted dividends for this market
	set sql [subst {
		select
			div_id
		from
			tdividend_aud
		where
			ev_mkt_id = $mkt_id
			$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows < 1} {
		err_bind "No dividends have been deleted for this market (ev_mkt_id : $mkt_id)"
		go_mkt_div
		return
	}

	for {set i 0} {$i < $nrows} {incr i} {
		set del_div_id [db_get_col $res $i div_id]
		if {[lsearch -exact $div_del_list $del_div_id] == -1} {
			lappend div_del_list $del_div_id
		}
	}

	db_close $res
	unset res

	# Set for the AUDIT array
	reqSetArg DivId [join $div_del_list ,]

	# Display the audit details
	ADMIN::AUDIT::go_audit
}

# Updates all markets for a given event with the money back special flag
# If the market was selected in the money back special list
proc do_upd_mkt_mbs { } {
	global DB

	set ev_id  [reqGetArg EvId]

	set bad 0

	set sql {
		select
			lang
		from
			tSpecialOffer so
		where
			so.id     = ?
			and so.level = "EVENT"
			and so.special_type = "MBS";
	}

	set stmt     [inf_prep_sql $DB $sql]
	set rs       [inf_exec_stmt $stmt $ev_id]
	set nrows    [db_get_nrows $rs]

	ob_log::write INFO {disp_mkt_mbs: number of langauge rows found = $nrows}
	set special_langs [list]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend special_langs [db_get_col $rs $i lang]
	}
	ob_db::rs_close $rs
	inf_close_stmt $stmt

	ob_log::write INFO {Prepearing SQL statment for ev_id #$ev_id}
	set sql {
		select
			e.ev_mkt_id
		from
			tEvMkt e
		where
			e.ev_id = ?;
	}

	set stmt     [inf_prep_sql $DB $sql]
	set rs       [inf_exec_stmt $stmt $ev_id]
	set nrows    [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set ev_mkt_id    [db_get_col $rs $i ev_mkt_id]
		set mbs_setting  [reqGetArg MBSmkt_${ev_mkt_id}]
		if {[catch {
			if {$mbs_setting == 1} {
				# Adds the MBS flag to the market
				update_special_type MARKET $ev_mkt_id "MBS" $special_langs 0 1 1
			} else {
				# Removes the entry in tSpecialOffer for the market
				update_special_type MARKET $ev_mkt_id "" $special_langs 0 1 0
			}
		} msg]} {
			ob_log::write ERROR {Failed to set special type for market: $msg}
			err_bind "Failed to set special type for market: $msg"
			set bad 1
		}

	}

	ob_db::rs_close $rs
	inf_close_stmt $stmt


	# Sets text to confirm update completed
	if {$bad == 0} {
		tpSetVar MBSUpDated 1
	}
	disp_mkt_mbs

}

# Displays the individual markets for the event including a money back specical
# check box to select individual markets
proc disp_mkt_mbs {} {
	global MBSLIST DB

	catch {unset MBSLIST}
	set ev_id  [reqGetArg EvId]
	# Outer join to tSpecialOffer as not all markets will have an entry in
	# the table and the proc works needing all markets
	ob_log::write INFO {disp_mkt_mbs: Prepearing SQL statment}

	set sql {
		select distinct
			m.ev_mkt_id,
			m.name,
			m.status,
			m.displayed,
			m.disporder,
			m.lp_avail,
			m.sp_avail,
			m.ew_avail,
			m.result_conf,
			m.settled,
			e.desc,
			case
				when so.special_type = "MBS" then 1
				else 0
			end as special_type
		from
			tEvMkt m left outer join tSpecialOffer so on so.id = m.ev_mkt_id,
			tEv e
		where
			    m.ev_id     = ?
			and m.ev_id = e.ev_id;
	}

	set stmt     [inf_prep_sql $DB $sql]
	set rs       [inf_exec_stmt $stmt $ev_id]
	set nrows    [db_get_nrows $rs]

	ob_log::write INFO {disp_mkt_mbs: number of rows found = $nrows}

	for {set i 0} {$i < $nrows} {incr i} {
		set MBSLIST($i,ev_mkt_id)    [db_get_col $rs $i ev_mkt_id]
		set MBSLIST($i,name)         [db_get_col $rs $i name]
		set MBSLIST($i,status)       [db_get_col $rs $i status]
		set MBSLIST($i,displayed)    [db_get_col $rs $i displayed]
		set MBSLIST($i,disporder)    [db_get_col $rs $i disporder]
		set MBSLIST($i,lp_aval)      [db_get_col $rs $i lp_avail]
		set MBSLIST($i,sp_aval)      [db_get_col $rs $i sp_avail]
		set MBSLIST($i,ew_aval)      [db_get_col $rs $i ew_avail]
		set MBSLIST($i,result_conf)  [db_get_col $rs $i result_conf]
		set MBSLIST($i,settled)      [db_get_col $rs $i settled]
		set MBSLIST($i,special_type) [db_get_col $rs $i special_type]
	}
	tpBindString EvDesc [db_get_col $rs 0 desc]
	ob_db::rs_close $rs
	inf_close_stmt $stmt

	set r_count $i
	tpBindString r_count $r_count
	tpBindVar ev_mkt_id    MBSLIST  ev_mkt_id     mbs_idx
	tpBindVar name         MBSLIST  name          mbs_idx
	tpBindVar status       MBSLIST  status        mbs_idx
	tpBindVar display      MBSLIST  displayed     mbs_idx
	tpBindVar disporder    MBSLIST  disporder     mbs_idx
	tpBindVar lp_avail     MBSLIST  lp_aval       mbs_idx
	tpBindVar sp_avail     MBSLIST  sp_aval       mbs_idx
	tpBindVar ew_avail     MBSLIST  ew_aval       mbs_idx
	tpBindVar result_conf  MBSLIST  result_conf   mbs_idx
	tpBindVar settled      MBSLIST  settled       mbs_idx
	tpBindVar special_type MBSLIST  special_type  mbs_idx

	tpBindString EvId     $ev_id
	asPlayFile -nocache market_mbs_list.html

}



#
# Retrieve all each way terms for a market
#
proc get_ew_terms {mkt_id} {

	global DB

	ob::log::write DEV "get_ew_terms $mkt_id"

	set sql [subst {
		select
			ew_terms_id,
			ew_fac_num,
			ew_fac_den,
			ew_places
		from
			tEachWayTerms e
		where
			ev_mkt_id = $mkt_id

		union

		select
			0 as ew_terms_id,
			ew_fac_num,
			ew_fac_den,
			ew_places
		from
			tEvMkt
		where
			ev_mkt_id = $mkt_id and
			decode(ew_avail,'N',pl_avail,ew_avail) = 'Y'

		order by
			1
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set EW(ew_ids) [list]

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {

		set ew_id [db_get_col $rs $r ew_terms_id]

		lappend EW(ew_ids) $ew_id

		set EW($ew_id,ew_num)    [db_get_col $rs $r ew_fac_num]
		set EW($ew_id,ew_den)    [db_get_col $rs $r ew_fac_den]
		set EW($ew_id,ew_places) [db_get_col $rs $r ew_places]

	}

	db_close $rs

	return [array get EW]

}



#
# Bind details of each way terms
#
proc bind_ew_terms {ew_array} {

	global EWTERMS

	array set EW $ew_array

	set ew_idx 0

	foreach ew_id $EW(ew_ids) {
		set EWTERMS($ew_idx,id)  $ew_id
		set EWTERMS($ew_idx,num) $EW($ew_id,ew_num)
		set EWTERMS($ew_idx,den) $EW($ew_id,ew_den)
		set EWTERMS($ew_idx,pl)  $EW($ew_id,ew_places)
		incr ew_idx
	}

	tpSetVar     NumTerms $ew_idx
	tpBindString NumTerms $ew_idx

	tpBindVar EWId   EWTERMS id   ew_idx
	tpBindVar EWNum  EWTERMS num  ew_idx
	tpBindVar EWDen  EWTERMS den  ew_idx
	tpBindVar EWPl   EWTERMS pl   ew_idx

	tpBindString EWTermIds [join $EW(ew_ids) ","]

	GC::mark EWTERMS

}



# Looks at the lay to lose values passed from the page,
# and given that they exist, passes them to the lay to lose
# stored procedure to update the max_bet columns in tEvOc
# win_lp, win_sp, place_lp and place_sp are the laytolose values
# for live price win, starting price win, etc.
proc do_laytolose {args} {

	global DB USERNAME

	set mkt_id   [reqGetArg MktId]
	set win_lp   [reqGetArg win_lp]
	set win_sp   [reqGetArg win_sp]
	set place_lp [reqGetArg place_lp]
	set place_sp [reqGetArg place_sp]
	set win_ep   [reqGetArg win_ep]
	set place_ep [reqGetArg place_ep]

	set t_win_lp   [reqGetArg t_win_lp]
	set t_win_sp   [reqGetArg t_win_sp]
	set t_place_lp [reqGetArg t_place_lp]
	set t_place_sp [reqGetArg t_place_sp]
	set t_win_ep   [reqGetArg t_win_ep]
	set t_place_ep [reqGetArg t_place_ep]

	set inf [reqGetArg InfMB]
	set sup [reqGetArg SupMB]


	# if there's no markets don't do anything
	if { ![ info exists mkt_id ] || $mkt_id == "" } {
		return
	}
	if { ![ info exists inf ] || $inf == "" } {
		# no minimum max_bet value, so default it to zero
		set inf 0
	}

# Following commented out, as we'll do it in the stored proc pLayToLose
#
#	if { ![ info exists sup ] || $sup == "" } {
#		# no maximum max bet value, so default it to live price win
#		set sup $win_lp
#	}


	# check that our values are numeric -- allow aaaaa and aaaaa.bb
	set re1 {^[0-9]+\.[0-9]*$}
	set re2 {^[0-9]+$}

	set elist [ list ]
	set null_count 0
	foreach ltl_var {win_lp t_win_lp win_sp t_win_sp place_lp t_place_lp place_sp \
         		 t_place_sp win_ep t_win_ep place_ep t_place_ep inf sup} {
		ob::log::write DEBUG "$ltl_var is [set $ltl_var]"
		# check for non-numericity (is that a word?)
		if {[regexp $re1 [set $ltl_var] match] == 1 ||
		    [regexp $re2 [set $ltl_var] match] == 1 ||
		    [set $ltl_var] == ""} {
		    # fine
		} else {
			lappend elist $ltl_var
		}
	}

	if { [llength $elist] != 0 } {
		foreach check $elist {
			ob::log::write INFO "Non-numeric value for $check"
		}
			error "Non-numeric value passed for $check -- please use the back button on the browser and reenter."
		return
	}
	# check for sensible values for inf and sup
	if { $inf < 0 } { set inf 0 }
	if { ($sup < $inf || $sup < 0) && $sup != "" } { set sup $inf }
	set maxval [max $win_ep [max $win_lp [max $win_sp [max $place_lp [max $place_sp $place_ep]]]]]
	#if { $sup > $maxval } { set sup $maxval }
	# above commented out to allow max_bet to be higher than laytolose values
	# uncomment it to make the laytolose the dominant maximum.
	if { $sup == 0 } { set sup $maxval }

	# with all the values in and validated, call the stored procedure to do the work
	#
	# NB This also updates FC/TC Stake limits
	set sql {execute procedure pLayToLose(\
			p_ev_mkt_id = ?,\
			p_win_lp = ?,\
			p_win_sp = ?,\
			p_place_lp = ?,\
			p_place_sp = ?,\
			p_win_ep = ?,\
			p_place_ep = ?,\
            p_t_win_lp = ?,\
            p_t_win_sp = ?,\
            p_t_place_lp = ?,\
            p_t_place_sp = ?,\
	    p_t_win_ep   = ?,\
	    p_t_place_ep = ?,\
			p_min_bet = ?,\
			p_max_bet = ?\
		)}
	set stmt [ inf_prep_sql $DB $sql ]
	ob::log::write DEBUG "executing pLayToLose: $stmt $mkt_id $win_lp $win_sp $place_lp $place_sp $t_win_lp $t_win_sp $t_place_lp $t_place_sp $win_ep $place_ep $inf $sup"

	if {[catch {
		set res  [ inf_exec_stmt $stmt $mkt_id $win_lp $win_sp $place_lp \
			 $place_sp $win_ep $place_ep $t_win_lp $t_win_sp $t_place_lp \
			 $t_place_sp $t_win_ep $t_place_ep $inf $sup]
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR "do_laytolose: Unable to generate limits - $msg"
		err_bind  "Unable to generate limits - $msg"
	}
}



proc bind_market_flags {flags {mkt_grp_flags ""}} {

	global MKT_FLAGS

	GC::mark MKT_FLAGS

	if {$flags != ""} {
		set tag_used [split $flags ","]
	} else {
		set tag_used ""
	}

	set i 0

	foreach {t n} [OT_CfgGet MARKET_FLAGS ""] {
		set MKT_FLAGS($i,code) $t
		set MKT_FLAGS($i,name) $n

		if {[lsearch -exact $tag_used $t] >= 0} {
			set MKT_FLAGS($i,selected) CHECKED
		} else {
			set MKT_FLAGS($i,selected) ""
		}

		# Inserting a market, inherit the BIR expand flag, as the default value of EXP flag
		if {$mkt_grp_flags != "" && $t == "EXP"} {
			if {[string match "*MX*" $mkt_grp_flags]} {
				set MKT_FLAGS($i,selected) CHECKED
			}
		}

		incr i
	}

	tpSetVar NumMktFlags $i

	foreach c {
		code
		name
		selected
	} {
		tpBindVar market_flag_$c MKT_FLAGS $c mkt_flag_idx
	}

}


proc make_mkt_flag_str args {

	set res [list]

	foreach {t n} [OT_CfgGet MARKET_FLAGS ""] {
		if {[reqGetArg market_flag_$t] != ""} {
			lappend res $t
		}
	}
	return [join $res ,]
}

#Creates a new market by copying the structure of an existing market
#Copies across all the selections of the market.
proc do_mkt_clone args {

	global USERID

	#check permission
	if {![op_allowed "ManageEvMkt"]} {
		err_bind "You don't have permission to copy markets"
		ADMIN::EVENT::go_ev
		return
	}

	set new_name  [reqGetArg newMktName]
	set ev_mkt_id [reqGetArg MktId]

	#Use the clone_row functionnality to copy market.

	#Initialise new extra columns 'cause we don't want everything to be copied across.
	#In particular, all the results will be void, the status will be suspended,
	#the liabilities reset, etc.
	set additionnal_cols_mkt [list name\
									user_id\
									cr_date\
									status\
									hcap_makeup\
									spread_makeup\
									result_conf\
									settled\
									subst_ev_oc_id_1\
									subst_ev_oc_id_2\
									subst_ev_oc_id_3\
									r4_version\
									r4_version_liab]
	set additionnal_vals_mkt [list $new_name\
									$USERID\
									null\
									S\
									null\
									null\
									N\
									N\
									null\
									null\
									null\
									0\
									0]

	set additionnal_cols_seln [list user_id\
									cr_date\
									result\
									result_conf\
									place\
									settled\
									hcap_score]
	set additionnal_vals_seln [list $USERID\
									null\
									-\
									N\
									null\
									N\
									null]

	set additionnal_cols_mktconstr [list lp_bet_count\
										lp_win_stake\
										sp_bet_count\
										sp_win_stake]
	set additionnal_vals_mktconstr [list 0\
										0\
										0\
										0]

	set additionnal_cols_selnconstr [list cur_total\
										lp_bet_count\
										lp_win_stake\
										lp_win_liab\
										sp_bet_count\
										sp_win_stake\
										apc_total\
										apc_last_move\
										apc_moves\
										apc_start_num\
										apc_start_den\
										apc_susp_o_c]
	set additionnal_vals_selnconstr [list 0\
										0\
										0\
										0\
										0\
										0\
										null\
										null\
										null\
										null\
										null\
										N]

	ADMIN::CLONE_ROW::reset_additionnal_values tevmkt $additionnal_cols_mkt\
														$additionnal_vals_mkt
	ADMIN::CLONE_ROW::reset_additionnal_values tevoc  $additionnal_cols_seln\
														 $additionnal_vals_seln
	ADMIN::CLONE_ROW::reset_additionnal_values tevmktconstr $additionnal_cols_mktconstr\
															$additionnal_vals_mktconstr
	ADMIN::CLONE_ROW::reset_additionnal_values tevocconstr $additionnal_cols_selnconstr\
															$additionnal_vals_selnconstr

	if { [ catch { ADMIN::CLONE_ROW::clone_row tevmkt $ev_mkt_id }  msg ] } {

		if { [ string first cevmkt_u1 $msg ] } {
			set msg "Markets must have different names for the same event"
		}
		err_bind $msg

	}

	ADMIN::EVENT::go_ev

}

}
