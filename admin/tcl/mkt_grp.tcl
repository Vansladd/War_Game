# ==============================================================
# $Id: mkt_grp.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::MKT_GRP {

asSetAct ADMIN::MKT_GRP::GoMktGrp [namespace code go_mkt_grp]
asSetAct ADMIN::MKT_GRP::DoMktGrp [namespace code do_mkt_grp]



#
# ----------------------------------------------------------------------------
# Go to market type page - two activators, one with a market id, one without
# ----------------------------------------------------------------------------
#
proc go_mkt_grp args {

	global DB COLLECTION DISP_SORT

	set class_id   [reqGetArg ClassId]
	set type_id    [reqGetArg TypeId]
	set mkt_grp_id [reqGetArg MktGrpId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ClassId $class_id
	tpSetVar     ClassId $class_id
	tpBindString TypeId  $type_id

	#
	# Find out some information about the class and type
	#
	set sql [subst {
		select
			c.name,
			c.sort,
			t.channels,
			t.name type_name,
			t.ev_min_bet,
			t.ev_max_bet,
			t.sp_max_bet,
			t.ev_max_place_sp,
			t.ev_max_place_lp,
			t.ep_max_bet,
			t.ev_max_place_ep,
			cat.ev_category_id,
			cat.category,
			g.acc_max
		from
			tEvType t,
			tEvClass c,
			tEvCategory cat,
			tControl g
		where
			t.ev_type_id = ? and
			t.ev_class_id = c.ev_class_id and
			cat.category  = c.category
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $type_id]
	inf_close_stmt $stmt

	tpSetVar ClassSort [set csort [db_get_col $res 0 sort]]
	tpSetVar Category  [db_get_col $res 0 category]

	set channel_mask [db_get_col $res 0 channels]

	tpBindString TypeName           [db_get_col $res 0 type_name]
	tpBindString MktGrpAccMin       1
	tpBindString MktGrpAccMax       [db_get_col $res 0 acc_max]

	#Set the default min/max bets
	tpBindString MktGrpOcMinBet     [db_get_col $res 0 ev_min_bet]
	tpBindString MktGrpOcMaxBet     [db_get_col $res 0 ev_max_bet]
	tpBindString MktGrpOcMaxBetSP   [db_get_col $res 0 sp_max_bet]
	tpBindString MktGrpOcMaxPlaceLP [db_get_col $res 0 ev_max_place_lp]
	tpBindString MktGrpOcMaxPlaceSP [db_get_col $res 0 ev_max_place_sp]
	tpBindString MktGrpOcMaxBetEP   [db_get_col $res 0 ep_max_bet]
	tpBindString MktGrpOcMaxPlaceEP [db_get_col $res 0 ev_max_place_ep]

	set category_id                 [db_get_col $res 0 ev_category_id]

	db_close $res

	ADMIN::MKTPROPS::make_mkt_binds $csort

	set mktGrpColId ""
	set mkt_grp_collection_id ""
	set mktGrpDispSortId ""
	set mkt_grp_disp_sort_id ""

	if {$mkt_grp_id == ""} {

		tpSetVar opAdd 1

		set msort [reqGetArg MktGrpSort]
		set mtype [ADMIN::MKTPROPS::mkt_type $csort $msort]

		make_channel_binds "" $channel_mask 1
		if {$mtype == "l"} {
			make_layout_binds "" Y
		} else {
			make_layout_binds
		}

		tpBindString MktGrpCanWithdraw CHECKED
		tpBindString MktGrpCanDeadHeat CHECKED

		# set default percentages for event lay to lose and liability values
		tpBindString EventLL  [OT_CfgGet DEFAULT_MKTGRP_EVENTLL  100]
		tpBindString EventLTL [OT_CfgGet DEFAULT_MKTGRP_EVENTLTL 100]
		tpBindString EventLMB [OT_CfgGet DEFAULT_MKTGRP_EVENTLMB 100]
		tpBindString EventMMB [OT_CfgGet DEFAULT_MKTGRP_EVENTMMB 100]

		tpBindString MktGrpOcStkOrLbt [OT_CfgGet AUTO_STK_OR_LBT S]

		tpBindString MktGrpExpandMkts "checked"

		foreach {n v} {
			MktGrpXmul       xmul
			MktGrpHcapPrcLo  hcap-prc-lo
			MktGrpHcapPrcHi  hcap-prc-hi
			MktGrpHcapPrcAdj hcap-prc-adj
			MktGrpHcapStep   hcap-step
			MktGrpHcapSteal  hcap-steal
			MktGrpOcEachWayFactor ew-factor
			MktGrpOcMaxPotWin   max-pot-win
			MktGrpMaxMultipleBet max-multiple-bet
		} {
			tpBindString $n [ADMIN::MKTPROPS::mkt_flag $csort $msort $v]
		}

		#
		# To bind the betfair related i.e., Minimum Back Liquidity per Selection
		# information for the new market
		#
		if {[OT_CfgGet BF_ACTIVE 0]} {
			tpBindString MktGrpMinBackLiqOC [OT_CfgGet BF_MIN_BACK_LIQUID 20]
		}

		make_template_binds

	} else {

		tpBindString MktGrpId $mkt_grp_id

		tpSetVar opAdd 0

		#
		# Get market information
		#
		set sql [subst {
			select
				m.ev_oc_grp_id,
				t.name type_name,
				t.ev_class_id,
				m.name,
				m.tag,
				m.flags,
				m.sort,
				m.type,
				m.xmul,
				m.mkt_max_liab,
				m.blurb,
				m.disporder,
				m.acc_min,
				m.acc_max,
				m.oc_min_bet,
				m.oc_max_bet,
				m.sp_max_bet,
				m.oc_max_place_lp,
				m.oc_max_place_sp,
				m.ep_max_bet,
				m.oc_max_place_ep,
				m.oc_stk_or_lbt,
				m.min_spread_cap,
				m.max_spread_cap,
				m.can_withdraw,
				m.can_dead_heat,
				m.channels,
				m.hcap_prc_lo,
				m.hcap_prc_hi,
				m.hcap_prc_adj,
				m.hcap_step,
				m.hcap_steal,
				m.bir_index,
				m.bir_delay,
				m.win_lp,
				m.win_sp,
				m.place_lp,
				m.place_sp,
				m.win_ep,
				m.place_ep,
				m.least_max_bet,
				m.most_max_bet,
				m.event_ll,
				m.event_ltl,
				m.event_lmb,
				m.event_mmb,
				m.oc_max_pot_win,
				m.max_multiple_bet,
				m.oc_ew_factor,
				m.flags,
				m.template,
				m.dbl_res,
				m.collection_id,
				m.disp_sort_id,
				m.mkt_info_push_payload,
				mt.name as mkt_tplate_name,
				pGetHierarchyBIRDelayLevel ("OCGRP", $mkt_grp_id) as bir_hierarchy,
				pGetHierarchyBIRDelay ("OCGRP", $mkt_grp_id) as bir_hierarchy_value,
				m.grouped
			from
				tEvType  t,
				tEvOcGrp m,
				outer tMktTemplate mt
			where
				t.ev_type_id    = m.ev_type_id    and
				m.ev_oc_grp_id  = $mkt_grp_id and
				m.mkt_tmpl_id = mt.mkt_tmpl_id
		}]

		set stmt    [inf_prep_sql $DB $sql]
		set res_mkt [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set msort [db_get_col $res_mkt 0 sort]
		set mtype [db_get_col $res_mkt 0 type]

		set bir_delay     [db_get_col $res_mkt 0 bir_delay]
		set bir_hierarchy [db_get_col $res_mkt 0 bir_hierarchy]

		tpBindString ClassId            [db_get_col $res_mkt 0 ev_class_id]
		tpBindString TypeName           [db_get_col $res_mkt 0 type_name]
		tpBindString MktGrpName         [db_get_col $res_mkt 0 name]
		tpBindString MktGrpXmul         [db_get_col $res_mkt 0 xmul]
		tpBindString MktGrpTag          [db_get_col $res_mkt 0 tag]
		tpBindString MktGrpMaxLiab      [db_get_col $res_mkt 0 mkt_max_liab]
		tpBindString MktGrpAccMin       [db_get_col $res_mkt 0 acc_min]
		tpBindString MktGrpAccMax       [db_get_col $res_mkt 0 acc_max]
		tpBindString MktGrpOcMinBet     [db_get_col $res_mkt 0 oc_min_bet]
		tpBindString MktGrpOcMaxBet     [db_get_col $res_mkt 0 oc_max_bet]
		tpBindString MktGrpOcMaxSpBet   [db_get_col $res_mkt 0 sp_max_bet]
		tpBindString MktGrpOcMaxPlaceLP [db_get_col $res_mkt 0 oc_max_place_lp]
		tpBindString MktGrpOcMaxPlaceSP [db_get_col $res_mkt 0 oc_max_place_sp]
		tpBindString MktGrpOcMaxEpBet   [db_get_col $res_mkt 0 ep_max_bet]
		tpBindString MktGrpOcMaxPlaceEP [db_get_col $res_mkt 0 oc_max_place_ep]
		tpBindString MktGrpOcStkOrLbt   [db_get_col $res_mkt 0 oc_stk_or_lbt]
		tpBindString MktGrpMinSpreadCap [db_get_col $res_mkt 0 min_spread_cap]
		tpBindString MktGrpMaxSpreadCap [db_get_col $res_mkt 0 max_spread_cap]
		tpBindString MktGrpDisporder    [db_get_col $res_mkt 0 disporder]
		tpBindString MktGrpBlurb        [db_get_col $res_mkt 0 blurb]
		tpBindString MktGrpHcapPrcLo    [db_get_col $res_mkt 0 hcap_prc_lo]
		tpBindString MktGrpHcapPrcHi    [db_get_col $res_mkt 0 hcap_prc_hi]
		tpBindString MktGrpHcapPrcAdj   [db_get_col $res_mkt 0 hcap_prc_adj]
		tpBindString MktGrpHcapStep     [db_get_col $res_mkt 0 hcap_step]
		tpBindString MktGrpHcapSteal    [db_get_col $res_mkt 0 hcap_steal]
		tpBindString MktGrpBirIndex     [db_get_col $res_mkt 0 bir_index]
		tpBindString MktGrpBirDelay     $bir_delay
		tpBindString MktGrpWinLP        [db_get_col $res_mkt 0 win_lp]
		tpBindString MktGrpWinSP        [db_get_col $res_mkt 0 win_sp]
		tpBindString MktGrpPlaceLP      [db_get_col $res_mkt 0 place_lp]
		tpBindString MktGrpPlaceSP      [db_get_col $res_mkt 0 place_sp]
		tpBindString MktGrpWinEP        [db_get_col $res_mkt 0 win_ep]
		tpBindString MktGrpPlaceEP      [db_get_col $res_mkt 0 place_ep]
		tpBindString MktGrpLeastMaxBet  [db_get_col $res_mkt 0 least_max_bet]
		tpBindString MktGrpMostMaxBet   [db_get_col $res_mkt 0 most_max_bet]
		tpBindString EventLL            [db_get_col $res_mkt 0 event_ll]
		tpBindString EventLTL           [db_get_col $res_mkt 0 event_ltl]
		tpBindString EventLMB           [db_get_col $res_mkt 0 event_lmb]
		tpBindString EventMMB           [db_get_col $res_mkt 0 event_mmb]
		tpBindString MktGrpOcMaxPotWin  [db_get_col $res_mkt 0 oc_max_pot_win]
		tpBindString MktGrpOcEachWayFactor [db_get_col $res_mkt 0 oc_ew_factor]
		tpBindString MktGrpOcDblRes     [db_get_col $res_mkt 0 dbl_res]
		tpBindString MktGrpMaxMultipleBet  [db_get_col $res_mkt 0 max_multiple_bet]
		tpBindString MktGrpPushPayload  [db_get_col $res_mkt 0 mkt_info_push_payload]

		set mkt_disp_name [db_get_col $res_mkt 0 mkt_tplate_name]
		if {$mkt_disp_name == ""} {set mkt_disp_name "default"}
		tpBindString MktGrpTplateDisp $mkt_disp_name


		if {$bir_delay == "" && $bir_hierarchy != ""} {
			tpSetVar displayBIRHierarchy 1
			tpBindString BIRHierarchy     $bir_hierarchy
			tpBindString BIRHierarchyVal  [db_get_col $res_mkt 0 bir_hierarchy_value]
		}

		set mkt_grp_collection_id [db_get_col $res_mkt 0 collection_id]
		tpSetVar mktGrpColId      $mkt_grp_collection_id

		set mkt_grp_disp_sort_id  [db_get_col $res_mkt 0 disp_sort_id]
		tpSetVar mktGrpDispSortId      $mkt_grp_disp_sort_id

		# set checkbox value for "Multi-Template" field
		if {[db_get_col $res_mkt 0 grouped] == "Y"} {
			tpBindString MultiTemplate_Checked "checked"
		} else {
			tpBindString MultiTemplate_Checked ""
		}

		# Flag to determine whether market is displayed expanded in
		# Endemol's Flash app
		if {[string match "*ME*" [db_get_col $res_mkt 0 flags]]} {
			tpBindString MktBirExpand "checked"
		}

		# Flag to determine whether markets of this group are expanded by default
		if {[string match "*MX*" [db_get_col $res_mkt 0 flags]]} {
			tpBindString MktGrpExpandMkts "checked"
		}

		if {[db_get_col $res_mkt 0 can_withdraw]=="Y"} {
			tpBindString MktGrpCanWithdraw CHECKED
		}
		if {[db_get_col $res_mkt 0 can_dead_heat]=="Y"} {
			tpBindString MktGrpCanDeadHeat CHECKED
		}

		# Can we push this market via payload ?
		if {[lsearch [OT_CfgGet PUSH_MKT_PAYLOAD_TEMPLATES [list]] $msort] != -1} {
			tpSetVar showPushPayload 1
		}

		#tpBindString MktGrpTemplateSelected [db_get_col $res_mkt 0 template]


		make_template_binds [db_get_col $res_mkt 0 template]

		make_channel_binds [db_get_col $res_mkt 0 channels] $channel_mask

		if {$mtype == "l"} {
			make_layout_binds  [db_get_col $res_mkt 0 flags] Y
		} else {
			make_layout_binds  [db_get_col $res_mkt 0 flags] N
		}
		db_close $res_mkt

		if {[OT_CfgGet BF_ACTIVE 0]} {
			# To bind all the betfair related information for the market
			ADMIN::BETFAIR_MKTGRP::bind_bf_mkt_grp $csort
		}
	}

	# Get relevant collection details for this class

	set sql [subst {
		select
			col.name,
			col.collection_id
		from
			tCollection col,
			tSport s
		where
			col.sport_id = s.sport_id and
			s.ob_level = "c"          and
			s.ob_id = ?

		union

		select
			col.name,
			col.collection_id
		from
			tCollection col,
			tSport s
		where
			col.sport_id = s.sport_id and
			s.ob_level = "y"          and
			s.ob_id = ?

		order by
			name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $class_id $category_id]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumCollections $rows

	set mktGrpColIndx -1

	for {set i 0} {$i < $rows} {incr i} {

		set COLLECTION($i,collection_id)    [db_get_col $res $i collection_id]
		set COLLECTION($i,name)             [db_get_col $res $i name]

		if { $mkt_grp_collection_id == $COLLECTION($i,collection_id) } {
			tpSetVar mktGrpColIndx $i
			tpSetVar mktGrpColName  $COLLECTION($i,name)
		}

	}

	tpBindVar collectionId   COLLECTION collection_id collection_idx
	tpBindVar collectionName COLLECTION name          collection_idx

	db_close $res

	# Get relevant display sort details for this class

	set sql [subst {
		select
			d.disp_code,
			d.disp_sort_id
		from
			tDispSort d,
			tSport s
		where
			d.sport_id = s.sport_id and
			s.ob_level = "c"          and
			s.ob_id = ?

		union

		select
			d.disp_code,
			d.disp_sort_id
		from
			tDispSort d,
			tSport s
		where
			d.sport_id = s.sport_id and
			s.ob_level = "y"          and
			s.ob_id = ?

		order by
			disp_code
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $class_id $category_id]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumDispSorts $rows

	set mktGrpDispSortIndx -1

	for {set i 0} {$i < $rows} {incr i} {

		set DISP_SORT($i,disp_sort_id)    [db_get_col $res $i disp_sort_id]
		set DISP_SORT($i,name)             [db_get_col $res $i disp_code]

		if { $mkt_grp_disp_sort_id == $DISP_SORT($i,disp_sort_id) } {
			tpSetVar mktGrpDispSortIndx $i
			tpSetVar dispSortName  $DISP_SORT($i,name)
		}

	}

	tpBindVar dispSortId   DISP_SORT disp_sort_id  disp_sort_idx
	tpBindVar dispSortName DISP_SORT name          disp_sort_idx

	db_close $res

	#
	# Set site variables which control which bits of the template # are played
	#
	tpSetVar     MktGrpSort $msort
	tpBindString MktGrpSort $msort
	tpSetVar     MktGrpType $mtype
	tpBindString MktGrpType $mtype

	# Check whether it is allowed to delete selections. When
	# allow_dd_deletion is set to Y, it enables the deleting
	# any dilldown items. Such as categories, classes types and
	# markets.
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}

	asPlayFile -nocache mkt_grp.html
}


#
# ----------------------------------------------------------------------------
# Update market group
# ----------------------------------------------------------------------------
#
proc do_mkt_grp args {

	set act [reqGetArg SubmitName]

	if {$act == "MktGrpAdd"} {
		do_mkt_grp_add
	} elseif {$act == "MktGrpMod"} {
		do_mkt_grp_upd
	} elseif {$act == "MktGrpDel"} {
		do_mkt_grp_del
	} elseif {$act == "LaytoLose"} {
		do_laytolose
	} elseif {$act == "Back"} {
		ADMIN::TYPE::go_type
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_mkt_grp_add args {

	global DB USERNAME

	set event_ll  [reqGetArg EventLL]
	set event_lmb [reqGetArg EventLMB]
	set event_mmb [reqGetArg EventMMB]
	set event_ltl [reqGetArg EventLTL]

	set win_lp        [reqGetArg MktGrpWinLP]
	set win_sp        [reqGetArg MktGrpWinSP]
	set place_lp      [reqGetArg MktGrpPlaceLP]
	set place_sp      [reqGetArg MktGrpPlaceSP]
	set win_ep        [reqGetArg MktGrpWinEP]
	set place_ep      [reqGetArg MktGrpPlaceEP]
	set least_max_bet [reqGetArg MktGrpLeastMaxBet]
	set most_max_bet  [reqGetArg MktGrpMostMaxBet]

	# If no minimum max bet value exists, default it to zero
	if { $least_max_bet == "" } {
		set last_max_bet 0
	}

	# Check that lay to lose values are numeric -- allow aaaaa and aaaaa.bb
	set re1 {^[0-9]+\.[0-9]*$}
	set re2 {^[0-9]+$}

	foreach ltl_var {win_lp win_sp place_lp place_sp least_max_bet most_max_bet} {
		ob::log::write DEBUG "$ltl_var is [set $ltl_var]"
		if {[regexp $re1 [set $ltl_var] match] == 1 ||
		    [regexp $re2 [set $ltl_var] match] == 1 ||
		    [set $ltl_var] == ""} {
		} else {
			lappend error_list $ltl_var
		}
	}

	# Check for sensible values for least_max_bet and most_max_bet
	if { $least_max_bet < 0 } {
		set least_max_bet 0
	}
	if { ($most_max_bet < $least_max_bet || $most_max_bet < 0) && $most_max_bet != "" } {
		set most_max_bet $least_max_bet
	}

	set bir_delay [reqGetArg MktGrpBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_mkt_grp
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_mkt_grp
			return
		}

	}

	# check percentage values are valid
	set error_list [list]
	if { [valid_input $event_ll] == 0} {
		lappend error_list "Event Liability Limit"
	}
	if { [valid_input $event_lmb] == 0} {
		lappend error_list "Event Least Max Bet"
	}
	if { [valid_input $event_mmb] == 0} {
		lappend error_list "Event Most Max Bet"
	}
	if { [llength $error_list] != 0 } {
		set error_str [join $error_list ", "]
		err_bind "Re enter values for $error_str"
		go_mkt_grp
		return
	}

	# check for sensible percentage values
	if { $event_ll == ""} { set event_ll 100 }
	if { $event_ll < 0 } { set event_ll 0 }
	if { $event_lmb == ""} { set event_lmb 100 }
	if { $event_lmb < 0 } { set event_lmb 0 }
	if { $event_mmb == ""} { set event_mmb 100 }
	if { $event_mmb < 0 } { set event_mmb 0 }
	if { $event_ltl < 0 || $event_ltl == ""}  {set event_ltl 100}

	set sql [subst {
		execute procedure pInsEvOcGrp(
			p_adminuser = ?,
			p_ev_type_id = ?,
			p_name = ?,
			p_tag = ?,
			p_flags = ?,
			p_type = ?,
			p_sort = ?,
			p_xmul = ?,
			p_blurb = ?,
			p_disporder = ?,
			p_acc_min = ?,
			p_acc_max = ?,
			p_oc_min_bet = ?,
			p_oc_max_bet = ?,
			p_sp_max_bet = ?,
			p_oc_max_place_lp = ?,
			p_oc_max_place_sp = ?,
			p_ep_max_bet = ?,
			p_oc_max_place_ep = ?,
			p_oc_stk_or_lbt = ?,
			p_mkt_max_liab = ?,
			p_min_spread_cap = ?,
			p_max_spread_cap = ?,
			p_can_withdraw = ?,
			p_can_dead_heat = ?,
			p_channels = ?,
			p_hcap_prc_lo = ?,
			p_hcap_prc_hi = ?,
			p_hcap_prc_adj = ?,
			p_hcap_step = ?,
			p_hcap_steal = ?,
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
			p_event_ll = ?,
			p_event_lmb = ?,
			p_event_mmb = ?,
			p_event_ltl = ?,
			p_special_type = ?,
			p_oc_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_oc_ew_factor = ?,
			p_bir_template = ?,
			p_dbl_res = ?,
			p_collection_id = ?,
			p_disp_sort_id = ?,
			p_grouped = ?
		)
	}]

	set channels [make_channel_str]

	if {[reqGetArg MktGrpCanWithdraw]!=""} {
		set can_withdraw "Y"
	} else {
		set can_withdraw "N"
	}

	if {[reqGetArg MktGrpCanDeadHeat]!=""} {
		set can_dead_heat "Y"
	} else {
		set can_dead_heat "N"
	}

	if {[reqGetArg multiTemplate] == ""} {
		set grouped "N"
	} else {
		set grouped [reqGetArg multiTemplate]
	}

	set bad 0

	set flags [reqGetArg MktGrpLayout]
	if {[OT_CfgGet FUNC_MARKET_FLAGS 0]} {
		if {[reqGetArg MktGrpExpandMkts] == 1} {
			if {$flags != ""} {
				set flags "${flags},MX"
			} else {
				set flags "MX"
			}
		}
	}
	#
	# propagate max_bet and max_bet_sp field to place fields if they're empty
	#
	if { [reqGetArg MktGrpOcMaxPlaceLP] == "" } {
		set max_place_lp [reqGetArg MktGrpOcMaxBet]
	} else {
		set max_place_lp [reqGetArg MktGrpOcMaxPlaceLP]
	}
	if { [reqGetArg MktGrpOcMaxPlaceSP] == "" } {
		set max_place_sp [reqGetArg MktGrpOcMaxBetSP]
	} else {
		set max_place_sp [reqGetArg MktGrpOcMaxPlaceSP]
	}
	if { [reqGetArg MktGrpOcMaxPlaceEP] == "" } {
		set max_place_ep [reqGetArg MktGrpOcMaxBetEP]
	} else {
		set max_place_ep [reqGetArg MktGrpOcMaxPlaceEP]
	}

	set stmt [inf_prep_sql $DB $sql]

	# This makes the spread betting backwards compatible
	# with older databases
	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg TypeId]\
			[reqGetArg MktGrpName]\
			[reqGetArg MktGrpTag]\
			$flags\
			[reqGetArg MktGrpType]\
			[reqGetArg MktGrpSort]\
			[reqGetArg MktGrpXmul]\
			[reqGetArg MktGrpBlurb]\
			[reqGetArg MktGrpDisporder]\
			[reqGetArg MktGrpAccMin]\
			[reqGetArg MktGrpAccMax]\
			[reqGetArg MktGrpOcMinBet]\
			[reqGetArg MktGrpOcMaxBet]\
			[reqGetArg MktGrpOcMaxSpBet]\
			$max_place_lp\
			$max_place_sp\
			[reqGetArg MktGrpOcMaxEpBet]\
			$max_place_ep\
			[reqGetArg MktGrpOcStkOrLbt]\
			[reqGetArg MktGrpMaxLiab]\
			[reqGetArg MktGrpMinSpreadCap]\
			[reqGetArg MktGrpMaxSpreadCap]\
			$can_withdraw\
			$can_dead_heat\
			$channels\
			[reqGetArg MktGrpHcapPrcLo]\
			[reqGetArg MktGrpHcapPrcHi]\
			[reqGetArg MktGrpHcapPrcAdj]\
			[reqGetArg MktGrpHcapStep]\
			[reqGetArg MktGrpHcapSteal]\
			[reqGetArg MktGrpBirIndex]\
			$bir_delay\
			$win_lp\
			$win_sp\
			$place_lp\
			$place_sp\
			$win_ep\
			$place_ep\
			$least_max_bet\
			$most_max_bet\
			$event_ll\
			$event_lmb\
			$event_mmb\
			$event_ltl \
		    [reqGetArg MktGrpSpecialType]\
			[reqGetArg MktGrpOcMaxPotWin]\
			[reqGetArg MktGrpMaxMultipleBet]\
			[reqGetArg MktGrpOcEachWayFactor]\
			[reqGetArg SelTemplate]\
			[reqGetArg MktGrpOcDblRes]\
			[reqGetArg MktGrpCollectionId]\
			[reqGetArg MktGrpDispSortId]\
			$grouped\
	]} msg]} {

		set bad 1
		err_bind $msg
	} else {
		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add market (no ev_oc_grp_id retrieved)"
			set bad 1
		} else {
			set mkt_grp_id [db_get_coln $res 0 0]
		}
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {!$bad} {
		if {[OT_CfgGet BF_ACTIVE 0]} {
			# To add the Minimum Back Liquidity per Selection for the market
			set bad [ADMIN::BETFAIR_MKTGRP::do_bf_mkt_grp_add $mkt_grp_id]
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar MarketAddFailed 1
		go_mkt_grp
		return
	}

	tpSetVar MarketAdded 1

	ADMIN::TYPE::go_type
}

proc do_mkt_grp_upd args {

	global DB USERNAME

	set event_ll     [reqGetArg EventLL]
	set event_lmb    [reqGetArg EventLMB]
	set event_mmb    [reqGetArg EventMMB]
	set event_ltl    [reqGetArg EventLTL]
	set ev_oc_grp_id [reqGetArg MktGrpId]
	set type_id      [reqGetArg TypeId]

	# check percentage values are valid
	set error_list [list]
	if { [valid_input $event_ll] == 0} {
		lappend error_list "Event Liability Limit"
	}
	if { [valid_input $event_lmb] == 0} {
		lappend error_list "Event Least Max Bet"
	}
	if { [valid_input $event_mmb] == 0} {
		lappend error_list "Event Most Max Bet"
	}
	if { [llength $error_list] != 0 } {
		set error_str [join $error_list ", "]
		err_bind "Re enter values for $error_str"
		go_mkt_grp
		return
	}

	# check for sensible percentage values
	if { $event_ll == ""} { set event_ll 100 }
	if { $event_ll < 0 } { set event_ll 0 }
	if { $event_lmb == ""} { set event_lmb 100 }
	if { $event_lmb < 0 } { set event_lmb 0 }
	if { $event_mmb == ""} { set event_mmb 100 }
	if { $event_mmb < 0 } { set event_mmb 0 }
	if { $event_ltl < 0 || $event_ltl == ""}  {set event_ltl 100}

	set channels [make_channel_str]

	# find out whether values which affect liablities
	# and lay to lose have actually changed
	set update_markets 0
	set bad 0

	set sql_oc_grp [subst {
		select
			event_ll,
			event_lmb,
			event_mmb,
			channels,
			grouped
		from
			tEvOcGrp
		where
			ev_oc_grp_id = $ev_oc_grp_id
	}]

	set stmt_oc_grp [inf_prep_sql $DB $sql_oc_grp]

	if {[catch {set rs_oc_grp [inf_exec_stmt $stmt_oc_grp]} msg]} {
		OT_LogWrite 1 "Failed to get info for ev_oc_grp_id $ev_oc_grp_id"
		err_bind $msg
		set bad 1
	} elseif {[db_get_nrows $rs_oc_grp] == 1} {
		foreach column {event_ll event_lmb event_mmb channels} {
			if {[set $column] != [db_get_col $rs_oc_grp 0 $column]} {
				set update_markets 1
			}
		}
		# get the current grouped (multi-market) status
		set grouped [db_get_col $rs_oc_grp 0 grouped]
	} else {
		OT_LogWrite 1 "Query for Market Group $ev_oc_grp_id did not return 1 row"
		err_bind "Query for Market Group did not return 1 row"
		set bad 1
	}


	set removed_channels ""
	set added_channels   ""

	if {[OT_CfgGet PROPAGATE_CHAN 0]} {

		foreach channel [split [db_get_col $rs_oc_grp 0 channels] {}] {
			if {![regexp $channel $channels]} {
				append removed_channels $channel
			}
		}

		foreach channel [split $channels {}] {
			if {![regexp $channel [db_get_col $rs_oc_grp 0 channels]]} {
				append added_channels $channel
			}
		}

	}


	inf_close_stmt $stmt_oc_grp
	catch {db_close $rs_oc_grp}

	set bir_delay [reqGetArg MktGrpBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_mkt_grp
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_mkt_grp
			return
		}

	}

	if {!$bad} {
		set sql [subst {
			execute procedure pUpdEvOcGrp(
				p_adminuser = ?,
				p_ev_oc_grp_id = ?,
				p_name = ?,
				p_tag = ?,
				p_flags = ?,
				p_sort = ?,
				p_xmul = ?,
				p_blurb = ?,
				p_disporder = ?,
				p_acc_min = ?,
				p_acc_max = ?,
				p_oc_min_bet = ?,
				p_oc_max_bet = ?,
				p_sp_max_bet = ?,
				p_oc_max_place_lp = ?,
				p_oc_max_place_sp = ?,
				p_ep_max_bet = ?,
				p_oc_max_place_ep = ?,
				p_oc_stk_or_lbt = ?,
				p_mkt_max_liab = ?,
				p_min_spread_cap = ?,
				p_max_spread_cap = ?,
				p_can_withdraw = ?,
				p_can_dead_heat = ?,
				p_channels = ?,
				p_hcap_prc_lo = ?,
				p_hcap_prc_hi = ?,
				p_hcap_prc_adj = ?,
				p_hcap_step = ?,
				p_hcap_steal = ?,
				p_bir_index  = ?,
				p_bir_delay  = ?,
				p_win_lp = ?,
				p_win_sp = ?,
				p_place_lp = ?,
				p_place_sp = ?,
				p_win_ep = ?,
				p_place_ep = ?,
				p_least_max_bet = ?,
				p_most_max_bet = ?,
				p_event_ll = ?,
				p_event_lmb = ?,
				p_event_mmb = ?,
				p_event_ltl = ?,
				p_special_type = ?,
				p_oc_max_pot_win = ?,
				p_oc_ew_factor = ?,
				p_bir_template = ?,
				p_dbl_res      = ?,
				p_max_multiple_bet = ?,
				p_collection_id = ?,
				p_push_payload = ?,
				p_disp_sort_id = ?,
				p_grouped = ?
			)
		}]
	}


	if {[reqGetArg MktGrpCanWithdraw]!=""} {
		set can_withdraw "Y"
	} else {
		set can_withdraw "N"
	}

	if {[reqGetArg MktGrpCanDeadHeat]!=""} {
		set can_dead_heat "Y"
	} else {
		set can_dead_heat "N"
	}

	# if configged off, default to the current database value
	if {[OT_CfgGet FUNC_DISPLAY_GROUPING 0]} {
		if {[reqGetArg multiTemplate] == ""} {
			set grouped "N"
		} else {
			set grouped [reqGetArg multiTemplate]
		}
	}

	#
	# propagate max_bet and max_bet_sp field to place fields if they're empty
	#
	if { [reqGetArg MktGrpOcMaxPlaceLP] == "" } {
		set max_place_lp [reqGetArg MktGrpOcMaxBet]
	} else {
		set max_place_lp [reqGetArg MktGrpOcMaxPlaceLP]
	}
	if { [reqGetArg MktGrpOcMaxPlaceSP] == "" } {
		set max_place_sp [reqGetArg MktGrpOcMaxBetSP]
	} else {
		set max_place_sp [reqGetArg MktGrpOcMaxPlaceSP]
	}
	if { [reqGetArg MktGrpOcMaxPlaceEP] == "" } {
		set max_place_ep [reqGetArg MktGrpOcMaxBetEP]
	} else {
		set max_place_ep [reqGetArg MktGrpOcMaxPlaceEP]
	}

	# update flags to include ME flag
	#
	# (NB MktGrpLayout seems to always be empty...
	#     Think it's a holdover from somewhere else.
	#     I'm leaving it in for possibly compatability
	#     issues, and because it's always empty, it
	#     serves as a way of deleting the ME flag too.)
	set flags [reqGetArg MktGrpLayout]
	if {[OT_CfgGetTrue FUNC_BIR_MKT_EXPAND]} {
		if {[reqGetArg MktBirExpand] == 1} {
			if {$flags != ""} {
				set flags "${flags},ME"
			} else {
				set flags "ME"
			}
		}
	}

	if {[OT_CfgGet FUNC_MARKET_FLAGS 0]} {
		if {[reqGetArg MktGrpExpandMkts] == 1} {
			if {$flags != ""} {
				set flags "${flags},MX"
			} else {
				set flags "MX"
			}
		}
	}

	if {[OT_CfgGet FUNC_MENU_COLLECTIONS 0] && [op_allowed ManageCollection]} {
		set collection_id [reqGetArg MktGrpCollectionId]
	} else {
		set collection_id -1
	}

	# Are we pushing this market via payload ?
	set push_payload [expr {[reqGetArg MktGrpPushPayload] == "Y" ? "Y" : "N"}]

	if {[OT_CfgGet FUNC_MENU_DISP_SORTS 0] && [op_allowed ManageEv]} {
		set disp_sort_id [reqGetArg MktGrpDispSortId]
	} else {
		set disp_sort_id ""
	}


	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktGrpId]\
			[reqGetArg MktGrpName]\
			[reqGetArg MktGrpTag]\
			$flags\
			[reqGetArg MktGrpSort]\
			[reqGetArg MktGrpXmul]\
			[reqGetArg MktGrpBlurb]\
			[reqGetArg MktGrpDisporder]\
			[reqGetArg MktGrpAccMin]\
			[reqGetArg MktGrpAccMax]\
			[reqGetArg MktGrpOcMinBet]\
			[reqGetArg MktGrpOcMaxBet]\
			[reqGetArg MktGrpOcMaxSpBet]\
			$max_place_lp\
			$max_place_sp\
			[reqGetArg MktGrpOcMaxEpBet]\
			$max_place_ep\
			[reqGetArg MktGrpOcStkOrLbt]\
			[reqGetArg MktGrpMaxLiab]\
			[reqGetArg MktGrpMinSpreadCap]\
			[reqGetArg MktGrpMaxSpreadCap]\
			$can_withdraw\
			$can_dead_heat\
			$channels\
			[reqGetArg MktGrpHcapPrcLo]\
			[reqGetArg MktGrpHcapPrcHi]\
			[reqGetArg MktGrpHcapPrcAdj]\
			[reqGetArg MktGrpHcapStep]\
			[reqGetArg MktGrpHcapSteal]\
			[reqGetArg MktGrpBirIndex]\
			$bir_delay\
			[reqGetArg MktGrpWinLP]\
			[reqGetArg MktGrpWinSP]\
			[reqGetArg MktGrpPlaceLP]\
			[reqGetArg MktGrpPlaceSP]\
			[reqGetArg MktGrpWinEP]\
			[reqGetArg MktGrpPlaceEP]\
			[reqGetArg MktGrpLeastMaxBet]\
			[reqGetArg MktGrpMostMaxBet]\
			$event_ll\
			$event_lmb\
			$event_mmb\
			$event_ltl \
			[reqGetArg MktGrpSpecialType]\
			[reqGetArg MktGrpOcMaxPotWin]\
			[reqGetArg MktGrpOcEachWayFactor]\
			[reqGetArg SelTemplate]\
			[reqGetArg MktGrpOcDblRes]\
			[reqGetArg MktGrpMaxMultipleBet]\
			$collection_id \
			$push_payload \
			$disp_sort_id\
			$grouped\
	]} msg]} {

		err_bind $msg
		set bad 1
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad != 1} {
		if {[OT_CfgGet BF_ACTIVE 0]} {
			# Updating betfair related information
			set bad [ADMIN::BETFAIR_MKTGRP::do_bf_mkt_grp_upd]
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_mkt_grp
		return
	}

	if {[OT_CfgGet PROPAGATE_LTL 0] == 1 || [OT_CfgGet PROPAGATE_CHAN 0]} {

	# modify all unsettled markets of this type
	# only if the relevant values have changed
		if {$update_markets} {
			set sql_mkt [subst {
				select
					m.ev_mkt_id,
					m.channels
				from
					tEvMkt m,
					tEvUnstl u
				where
					m.ev_id            = u.ev_id
					and m.ev_oc_grp_id = $ev_oc_grp_id
					and m.settled      = 'N'
			}]
			set stmt_mkt [inf_prep_sql $DB $sql_mkt]
			set rs_mkt [inf_exec_stmt $stmt_mkt]
			set nrows [db_get_nrows $rs_mkt]

			OT_LogWrite 20 "ADMIN::MKT_GRP::do_mkt_grp_upd: Updating $nrows markets"

			if {[OT_CfgGet PROPAGATE_LTL 0] == 1} {

				for {set n 0} {$n < $nrows} {incr n} {
					set ev_mkt_id [db_get_col $rs_mkt $n ev_mkt_id]
					set sql_ev [subst {
					select
						l.ev_id,
						l.least_max_bet,
						l.most_max_bet,
						l.liability,
						t.ltl_win_lp,
						t.ltl_win_sp,
						t.ltl_place_lp,
						t.ltl_place_sp,
						t.ltl_win_ep,
						t.ltl_place_ep,
						mkt.win_lp as mkt_win_lp,
						mkt.win_sp as mkt_win_sp,
						mkt.place_lp as mkt_place_lp,
						mkt.place_sp as mkt_place_sp,
						mkt.win_ep as mkt_win_ep,
						mkt.place_ep as mkt_place_ep

						from
							tEvMkt m,
							tLayToLoseEv l,
							tLayToLose mkt,
							tEvType t,
							tEv e
						where
							m.ev_mkt_id = $ev_mkt_id and
							mkt.ev_mkt_id = $ev_mkt_id and
							m.ev_mkt_id = mkt.ev_mkt_id and
							m.ev_id = e.ev_id and
							e.ev_type_id = t.ev_type_id and
							l.ev_id = m.ev_id
					}]
					set stmt_ev [inf_prep_sql $DB $sql_ev]
					set rs_ev [inf_exec_stmt $stmt_ev]
					set n_rows [db_get_nrows $rs_ev]

					if { $n_rows > 0 } {
						set least_max_bet [db_get_col $rs_ev 0 least_max_bet]
						set most_max_bet  [db_get_col $rs_ev 0 most_max_bet]
						set ltl_win_lp    [db_get_col $rs_ev 0 ltl_win_lp]
						set ltl_win_sp    [db_get_col $rs_ev 0 ltl_win_sp]
						set ltl_place_lp  [db_get_col $rs_ev 0 ltl_place_lp]
						set ltl_place_sp  [db_get_col $rs_ev 0 ltl_place_sp]
						set ltl_win_ep    [db_get_col $rs_ev 0 ltl_win_ep]
						set ltl_place_ep  [db_get_col $rs_ev 0 ltl_place_ep]
						set mkt_win_lp    [db_get_col $rs_ev 0 mkt_win_lp]
						set mkt_win_sp    [db_get_col $rs_ev 0 mkt_win_sp]
						set mkt_place_lp  [db_get_col $rs_ev 0 mkt_place_lp]
						set mkt_place_sp  [db_get_col $rs_ev 0 mkt_place_sp]
						set mkt_win_ep    [db_get_col $rs_ev 0 mkt_win_ep]
						set mkt_place_ep  [db_get_col $rs_ev 0 mkt_place_ep]
						set liability     [db_get_col $rs_ev 0 liability]

						if { [max $mkt_win_lp $mkt_win_sp $mkt_place_lp $mkt_place_sp] != "" } {
							if { $most_max_bet == "" } {
								if { $liability == "" } {
									if { [max $ltl_win_lp $ltl_win_sp $ltl_place_lp $ltl_place_sp $ltl_win_ep $ltl_place_ep] != "" } {
										set most_max_bet [max $ltl_win_lp $ltl_win_sp $ltl_place_lp $ltl_place_sp $ltl_win_ep $ltl_place_ep]
									} else {
										set most_max_bet [max $mkt_win_lp $mkt_win_sp $mkt_place_lp $mkt_place_sp $mkt_win_ep $mkt_place_ep]
									}
								}
							}
							if { $least_max_bet == "" } {
								set least_max_bet 0
							}
							set mkt_most_max_bet  [expr double($most_max_bet) / 100 * $event_mmb]
							set mkt_least_max_bet [expr double($least_max_bet) / 100 * $event_lmb]
							if { $mkt_most_max_bet < $mkt_least_max_bet } {
								set mkt_most_max_bet $mkt_least_max_bet
							}
							set sql [subst {
								execute procedure pLayToLose (
									$ev_mkt_id,
									$ltl_win_lp,
									$ltl_win_sp,
									$ltl_place_lp,
									$ltl_place_sp,
									$ltl_win_ep,
									$ltl_place_ep,
									$mkt_least_max_bet,
									$mkt_most_max_bet
								)
							}]
							set stmt [inf_prep_sql $DB $sql]
							set res [inf_exec_stmt $stmt]
							inf_close_stmt $stmt
							db_close $res

							if { $liability != "" } {
								set mkt_liability [expr double($liability) / 100 * $event_ll]

								set sql [subst {
									execute procedure pLayToLose (
										$ev_mkt_id,
										$ltl_win_lp,
										$ltl_win_sp,
										$ltl_place_lp,
										$ltl_place_sp,
										$mkt_least_max_bet,
										$mkt_most_max_bet
									)
								}]
								set stmt [inf_prep_sql $DB $sql]
								set res [inf_exec_stmt $stmt]
								inf_close_stmt $stmt
								db_close $res

								if { $liability != "" } {
									set mkt_liability [expr double($liability) / 100 * $event_ll]
									set sql [subst {
										update
											tEvMktConstr
										set
											liab_limit = $mkt_liability
										where
											ev_mkt_id = $ev_mkt_id
									}]
									set stmt [inf_prep_sql $DB $sql]
									set rs [inf_exec_stmt $stmt]
									inf_close_stmt $stmt
									db_close $rs
								}
							}
						}
						db_close $rs_ev
					}
				}
			}

			if {[OT_CfgGet PROPAGATE_CHAN 0] && ($removed_channels != "" || $added_channels != "")} {
				# if the channel list has changed, propegate this through the markets

				set sql_upd_mkt [subst {
					update
						tEvMkt
					set
						channels  = ?
					where
						ev_mkt_id = ?
				}]
				set stmt_upd [inf_prep_sql $DB $sql_upd_mkt]

				set nrows [db_get_nrows $rs_mkt]
				if {$nrows == 0} {
					ob_log::write INFO "EvOcGrp channel propegation: no tevunstl markets to update"
				} else {
					ob_log::write INFO "EvOcGrp channel propegation: number of rows to change: $nrows"
				}

				for {set n 0} {$n < $nrows} {incr n} {

					# loop over the markets and find the appropriate replacement string for each
					set ev_mkt_id              [db_get_col $rs_mkt $n ev_mkt_id]
					set current_mrkts_channels [db_get_col $rs_mkt $n channels ]
					set new_mrkts_channels     $current_mrkts_channels

					# systematically remove each market from the channel list
					foreach channel [split $removed_channels {}] {
						set new_mrkts_channels [regsub $channel $new_mrkts_channels {}]
					}

					# add the new markets and format the channel string
					append new_mrkts_channels $added_channels
					set channel_string [make_formatted_channel_string $new_mrkts_channels]

					# if markets were removed or added, update the channel list for the market
					if {$new_mrkts_channels != $current_mrkts_channels} {
						ob_log::write DEV "replacing mrkt $ev_mkt_id: $current_mrkts_channels with $channel_string"

						if {[catch {inf_exec_stmt $stmt_upd $channel_string $ev_mkt_id} msg]} {
							ob_log::write ERROR "submarket update channel for MarketId:$ev_mkt_id failed"

							# return if there was an update error
							for {set a 0} {$a < [reqGetNumVals]} {incr a} {
								tpBindString [reqGetNthName $a] [reqGetNthVal $a]
							}
							go_mkt_grp

							return
						}
					}

				# end of for loop over unsettled markets
				}
				inf_close_stmt $stmt_upd
			}

			db_close $rs_mkt
		}
	}

	tpSetVar MarketUpdated 1
	ADMIN::TYPE::go_type
}

proc do_mkt_grp_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelEvOcGrp(
			p_adminuser = ?,
			p_ev_oc_grp_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktGrpId]]} msg]} {
		err_bind $msg
		set bad 1
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_mkt_grp
		return
	}

	ADMIN::TYPE::go_type
}

# simple procedure for validating inputs. null values are valid
proc valid_input {input args} {
	if { [ regexp {^[0-9]+$} $input match ] == 1 || $input == ""} {
		return 1
	} else { return 0 }
}



# Gets the lay to lose values passed from the page and checks that they are
# numeric, then updates the values in tevocgrp.
#
proc do_laytolose args {

	global DB USERNAME

	set mkt_grp_id   [reqGetArg MktGrpId]
	set win_lp       [reqGetArg MktGrpWinLP]
	set win_sp       [reqGetArg MktGrpWinSP]
	set place_lp     [reqGetArg MktGrpPlaceLP]
	set place_sp     [reqGetArg MktGrpPlaceSP]
	set win_ep       [reqGetArg MktGrpWinEP]
	set place_ep     [reqGetArg MktGrpPlaceEP]

	set least_max_bet [reqGetArg MktGrpLeastMaxBet]
	set most_max_bet  [reqGetArg MktGrpMostMaxBet]

	if {$mkt_grp_id == ""} {
		return
	}
	if {$least_max_bet == ""} {
		set least_max_bet 0
	}

	# check that our values are numeric -- allow aaaaa and aaaaa.bb
	set re1 {^[0-9]+\.[0-9]*$}
	set re2 {^[0-9]+$}

	set elist [ list ]
	set null_count 0
	foreach ltl_var {win_lp win_sp place_lp place_sp least_max_bet most_max_bet} {
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
			err_add "Non-numeric value passed for $check"
		go_mkt_grp
		return
	}

	if {$least_max_bet < 0} {
		set least_max_bet 0
	}
	if {($most_max_bet < $least_max_bet || $most_max_bet < 0) && $most_max_bet != ""} {
		set most_max_bet $least_max_bet
	}

	set maxval [max $win_ep [max $win_lp [max $win_sp [max $place_lp [max $place_sp $place_ep]]]]]

	if {$most_max_bet == 0} {
		set most_max_bet $maxval
	}

	# Update the database
	set sql {
		update tEvOcGrp set
			win_lp        = ?,
			win_sp        = ?,
			place_lp      = ?,
			place_sp      = ?,
			win_ep        = ?,
			place_ep      = ?,
			least_max_bet = ?,
			most_max_bet  = ?
		where
			ev_oc_grp_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res  [inf_exec_stmt $stmt $win_lp $win_sp $place_lp \
			 $place_sp $win_ep $place_ep $least_max_bet $most_max_bet $mkt_grp_id]
		inf_close_stmt $stmt
	} msg]} {
		ob_log::write ERROR "do_laytolose: Unable to generate limits - $msg"
		err_bind  "Unable to generate limits - $msg"
	}

	go_mkt_grp
}

}
