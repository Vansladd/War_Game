# $Id: selection.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SELN {

asSetAct ADMIN::SELN::GoOc             [namespace code go_oc]
asSetAct ADMIN::SELN::GoOcsRes         [namespace code go_ocs_res]
asSetAct ADMIN::SELN::DoOcsRes         [namespace code do_ocs_res]
asSetAct ADMIN::SELN::DoOc             [namespace code do_oc]
asSetAct ADMIN::SELN::DoOcsUpd         [namespace code do_ocs_upd]
asSetAct ADMIN::SELN::GoOcPrice        [namespace code go_oc_price]
asSetAct ADMIN::SELN::DoOcPriceUpd     [namespace code do_oc_price_upd]
asSetAct ADMIN::SELN::DoShowPriceCheck [namespace code do_show_price_check]

variable RSLT_MAP
variable RISK_INFO

array set RSLT_MAP [list - none V Void W Win L Lose H Handicap P Place U Push]
set RISK_INFO [list]
foreach nv [OT_CfgGet SELN_RISK_INFO ""] {
	foreach {n v} $nv {
		lappend RISK_INFO $n
		lappend RISK_INFO $v
	}
}


proc get_rslts_list {r} {

	variable RSLT_MAP

	set l [list]

	foreach f [split $flags ""] {
		lappend l $f $RSLT_MAP($f)
	}

	return $l
}

proc get_market_results {c_sort m_sort} {
	return [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort results]
}

proc get_seln_results {c_sort m_sort s_sort} {
	return [ADMIN::MKTPROPS::seln_flag $c_sort $m_sort $s_sort results]
}

proc bind_seln_results {c_sort m_sort s_sort} {

	global RESULTS

	variable RSLT_MAP

	#
	# Try to get selection-specific results list first - if not present,
	# fall back to the market results list
	#
	set flags [ADMIN::MKTPROPS::seln_flag $c_sort $m_sort $s_sort results]

	if {[llength $flags] == 0} {
		set flags [ADMIN::MKTPROPS::mkt_flag $c_sort $m_sort results]
	}

	set i 0

	foreach f [split $flags ""] {
		set RESULTS($i,flag) $f
		set RESULTS($i,name) $RSLT_MAP($f)
		incr i
	}

	tpBindVar ResultVal  RESULTS flag result_idx
	tpBindVar ResultDesc RESULTS name result_idx

	tpSetVar NumMktResults $i
}

proc bind_mkt_flags {csort mkt_sort} {

	global FLAGS

	set flags [ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort tags]
	set i     0

	foreach {f n} $flags {
		set FLAGS($i,flag) $f
		set FLAGS($i,name) $n
		incr i
	}

	tpBindVar FlagVal  FLAGS flag flag_idx
	tpBindVar FlagDesc FLAGS name flag_idx

	tpSetVar NumMktFlags $i
}

proc bind_risk_info {} {

	global RISK
	variable RISK_INFO

	set i 0

	foreach {r n} $RISK_INFO {
		set RISK($i,risk) $r
		set RISK($i,name) $n
		incr i
	}

	tpBindVar RiskVal  RISK risk risk_idx
	tpBindVar RiskDesc RISK name risk_idx

	tpSetVar NumRiskInfo $i
}

#
# ----------------------------------------------------------------------------
# Add/Update market activator
# ----------------------------------------------------------------------------
#
proc go_oc args {

	set oc_id [reqGetArg OcId]

	if {$oc_id == ""} {
		if {[reqGetArg SubmitName] == "MktAddSeln"} {
			go_oc_add
		} else {
			go_ocs_upd
		}
	} else {
		go_oc_upd
	}
}


#
# ----------------------------------------------------------------------------
# Go to "add new selection" page
# ----------------------------------------------------------------------------
#
proc go_oc_add args {

	global DB FLAGS

	tpSetVar opAdd 1

	set mkt_id [reqGetArg MktId]

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			c.ev_class_id,
			c.category,
			m.type,
			m.sort,
			m.status,
			e.ev_id,
			e.start_time,
			e.result_conf,
			e.desc,
			m.acc_min,
			m.lp_avail,
			m.sp_avail,
			m.channels,
			g.name mkt_name,
			g.mkt_max_liab,
			g.oc_min_bet,
			g.oc_max_bet,
			g.sp_max_bet,
			g.ep_max_bet,
			g.oc_max_pot_win,
			g.oc_ew_factor,
			y.ah_prc_chng_amt,
			y.ah_prc_lo,
			y.ah_prc_hi,
			NVL(m.min_bet, e.min_bet) min_bet,
			NVL(m.max_bet, e.max_bet) max_bet,
			g.max_multiple_bet,
			g.grouped
		from
			tEvClass     c,
			tEvType      t,
			tEv          e,
			tEvMkt       m,
			tEvOcGrp     g,
			tEvMktConstr y
		where
			m.ev_mkt_id    = $mkt_id        and
			m.ev_id        = e.ev_id        and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id  and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id    = y.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set channel_mask [db_get_col $res 0 channels]
	set csort        [db_get_col $res 0 csort]
	set mkt_type     [db_get_col $res 0 type]
	set mkt_sort     [db_get_col $res 0 sort]
	set status       [db_get_col $res 0 status]
	set start_time   [db_get_col $res 0 start_time]
	set result_conf  [db_get_col $res 0 result_conf]
	set lp_avail     [db_get_col $res 0 lp_avail]
	set sp_avail     [db_get_col $res 0 sp_avail]

	make_channel_binds "" $channel_mask 1

	tpBindString EvDesc       [db_get_col $res 0 desc]
	tpBindString ClassSort    $csort
	tpBindString EvId         [db_get_col $res 0 ev_id]
	tpBindString MktId        $mkt_id
	tpBindString MktType      $mkt_type
	tpBindString MktSort      $mkt_sort
	tpBindString MktAccMin    [db_get_col $res 0 acc_min]
	tpBindString OcMinBet     [db_get_col $res 0 oc_min_bet]
	tpBindString OcMaxBet     [db_get_col $res 0 oc_max_bet]
	tpBindString OcSpMaxBet   [db_get_col $res 0 sp_max_bet]
	tpBindString OcEpMaxBet   [db_get_col $res 0 ep_max_bet]
	tpBindString OcMaxPotWin  [db_get_col $res 0 oc_max_pot_win]
	tpBindString OcEWFactor   [db_get_col $res 0 oc_ew_factor]
	tpBindString MinBet       [db_get_col $res 0 min_bet]
	tpBindString MaxBet       [db_get_col $res 0 max_bet]
	tpBindString OcMaxMultipleBet [db_get_col $res 0 max_multiple_bet]
	tpSetVar     MktGrouped   [db_get_col $res 0 grouped]

	# Default OcFlag to Named Runner for adding Horse selections
	tpBindString OcFlag "-"

	#
	# Set up some limits for selections in handicap markets
	#
	if {[string first $mkt_type "AHLl"] >= 0} {

		set p_lo [db_get_col $res 0 ah_prc_lo]
		set p_hi [db_get_col $res 0 ah_prc_hi]

		tpBindString OcMaxTotal [db_get_col $res 0 mkt_max_liab]
		tpBindString APCPrcLo   $p_lo
		tpBindString APCPrcHi   $p_hi

		#
		# If it's a handicap market, and the lo/hi price bounds are
		# identical, put in a default price...
		#
		if {$p_lo == $p_hi} {
			tpBindString OcLP $p_lo
		}
	}

	tpSetVar ClassSort $csort
	tpSetVar ClassId   [db_get_col $res 0 ev_class_id]
	tpSetVar Category  [db_get_col $res 0 category]
	tpSetVar MktSort   $mkt_sort
	tpSetVar MktType   $mkt_type
	tpSetVar LP_Avail  [expr {$lp_avail == "Y"}]
	tpSetVar SP_Avail  [expr {$sp_avail == "Y"}]

	#
	# Get and bind flag values and risk info
	#
	bind_mkt_flags $csort $mkt_sort
	bind_risk_info

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

	asPlayFile selection.html

	db_close $res

	catch {unset FLAGS}
	catch {unset RISK}
}


#
# ----------------------------------------------------------------------------
# Event select activator
# ----------------------------------------------------------------------------
#
proc go_oc_upd args {

	global DB FLAGS RESULTS DBL_RES USERID BF_MTCH

	set DFLT_SP_NUM [OT_CfgGet DFLT_SP_NUM  5]
	set DFLT_SP_DEN [OT_CfgGet DFLT_SP_DEN  2]

	tpSetVar opAdd 0

	set oc_id  [reqGetArg OcId]

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			c.ev_class_id,
			c.category,
			m.ev_mkt_id,
			m.type,
			m.sort,
			m.status,
			e.start_time,
			e.result_conf,
			e.desc,
			e.ev_id,
			m.lp_avail,
			m.sp_avail,
			m.channels,
			m.acc_min,
			m.dbl_res,
			g.name mkt_name,
			y.ah_prc_chng_amt,
			y.ah_prc_lo,
			y.ah_prc_hi,
			e.allow_stl,
			NVL(m.min_bet, e.min_bet) min_bet,
			NVL(m.max_bet, e.max_bet) max_bet,
			NVL(NVL(NVL(NVL(s.max_multiple_bet, m.max_multiple_bet), e.max_multiple_bet), t.max_multiple_bet), 'n/a') f_max_multiple_bet,
			s.priced_by_feed,
			g.grouped
		from
			tEvClass     c,
			tEvType      t,
			tEv          e,
			tEvMkt       m,
			tEvOc        s,
			tEvOcGrp     g,
			tEvMktConstr y
		where
			s.ev_oc_id     = $oc_id         and
			s.ev_mkt_id    = m.ev_mkt_id    and
			m.ev_id        = e.ev_id        and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id  and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id    = y.ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set channel_mask   [db_get_col $res 0 channels]
	set csort          [db_get_col $res 0 csort]
	set mkt_id         [db_get_col $res 0 ev_mkt_id]
	set mkt_type       [db_get_col $res 0 type]
	set mkt_sort       [db_get_col $res 0 sort]
	set status         [db_get_col $res 0 status]
	set start_time     [db_get_col $res 0 start_time]
	set result_conf    [db_get_col $res 0 result_conf]
	set lp_avail       [db_get_col $res 0 lp_avail]
	set sp_avail       [db_get_col $res 0 sp_avail]
	set priced_by_feed [db_get_col $res 0 priced_by_feed]

	_bind_mkt_prices $mkt_id

	# if double resulting functionality not active, ignore db value
	if {[OT_CfgGet FUNC_DBL_RES 0]} {
		set dbl_res [db_get_col $res 0 dbl_res]
	} else {
		set dbl_res "N"
	}


	if {[OT_CfgGet REMAIN_DISP_LIVE_PRICES 0] == 1} {
		set lp_avail "Y"
	}

	tpBindString EvDesc       [db_get_col $res 0 desc]
	tpBindString ClassSort    $csort
	tpBindString EvId         [db_get_col $res 0 ev_id]
	tpBindString MktId        $mkt_id
	tpBindString MktType      $mkt_type
	tpBindString MktSort      $mkt_sort
	tpBindString MinBet       [db_get_col $res 0 min_bet]
	tpBindString MaxBet       [db_get_col $res 0 max_bet]
	tpBindString MktActive    [ expr { ( $status == "A") ? 1 : 0 }  ]
	tpBindString DblRes       $dbl_res
	tpBindString PricedByFeed $priced_by_feed
	tpBindString MktAccMin    [db_get_col $res 0 acc_min]
	tpSetVar     MktGrouped   [db_get_col $res 0 grouped]

	tpBindString FinalMaxMultipleBet\
	 [db_get_col $res 0 f_max_multiple_bet]

	tpSetVar EvAllowSettle  [db_get_col $res 0 allow_stl]

	if {[string first $mkt_type "AHLl"] >= 0} {
		tpBindString APCPrcLo   [db_get_col $res 0 ah_prc_lo]
		tpBindString APCPrcHi   [db_get_col $res 0 ah_prc_hi]
	}

	tpSetVar ClassSort $csort
	tpSetVar ClassId   [db_get_col $res 0 ev_class_id]
	tpSetVar Category  [db_get_col $res 0 category]
	tpSetVar MktType   $mkt_type
	tpSetVar MktSort   $mkt_sort
	if {[OT_CfgGet REMAIN_DISP_LIVE_PRICES 0] == 1} {
		tpSetVar LP_Avail "Y"
	} else {
		tpSetVar LP_Avail  [expr {$lp_avail == "Y"}]
	}
	tpSetVar SP_Avail  [expr {$sp_avail == "Y"}]

	db_close $res

	#
	# Get selection information
	#
	set sql [subst {
		select
			o.desc,
			o.status,
			o.result,
			o.result_conf,
			o.place,
			o.settled,
			o.disporder,
			o.displayed,
			o.lp_num,
			o.lp_den,
			o.sp_num,
			o.sp_den,
			o.sp_num_guide,
			o.sp_den_guide,
			o.fb_result,
			o.hcap_score,
			o.cs_home,
			o.cs_away,
			o.mult_key,
			o.ext_key,
			o.shortcut,
			o.acc_min,
			o.min_bet,
			o.max_bet,
			o.sp_max_bet,
		    o.max_place_lp,
		    o.max_place_sp,
			o.ep_max_bet,
			o.max_place_ep,
			o.runner_num,
			o.channels,
			o.risk_info,
			o.feed_updateable,
			o.has_oc_variants,
			o.code as oc_code,
		    o.fc_stk_limit,
		    o.tc_stk_limit,
			z.stk_or_lbt,
			z.max_total,
			z.cur_total,
			z.lp_win_liab,
			(1.0+NVL(NVL(NVL(o.sp_num,o.sp_num_guide),o.lp_num),$DFLT_SP_NUM)/
				NVL(NVL(NVL(o.sp_den,o.sp_den_guide),o.lp_den),$DFLT_SP_DEN))*
				z.sp_win_stake as sp_win_liab,
			nvl(o2.fb_result,'-') favourite,
			o.max_pot_win,
			o.max_multiple_bet,
			o.ew_factor,
			o.lock_stake_lmt,
			o.fixed_stake_limits,
			o.selection_msg,
			o.req_guid,
			case
				when exists (select 1 from tDeadHeatRedn
					where ev_oc_id = $oc_id) then
				"Y"
			else
				"N"
			end use_dh_redn,
			t.name     as team_name,
			t.team_id,
			o.link_key
		from
			tEvOc       o,
			tEvOcConstr z,
			outer tEvOc o2,
			outer ( tTeamEvOc te,
					tTeam t)
		where
			o.ev_oc_id = $oc_id and
			o.ev_oc_id = z.ev_oc_id and
			o.ev_mkt_id = o2.ev_mkt_id and
			((o.fb_result != '-' and
			  o.ev_oc_id = o2.ev_oc_id) or
			 (o.fb_result = '-' and
			  o.runner_num = o2.runner_num and
			  o2.runner_num is not null and
			  o2.fb_result != '-')) and
			o.ev_oc_id = te.ev_oc_id and
			te.team_id = t.team_id
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set result       [db_get_col $res_seln 0 result]
	set result_conf  [db_get_col $res_seln 0 result_conf]
	set settled      [db_get_col $res_seln 0 settled]
	set fb_result    [db_get_col $res_seln 0 fb_result]
	set cs_home      [db_get_col $res_seln 0 cs_home]
	set cs_away      [db_get_col $res_seln 0 cs_away]
	set channels     [db_get_col $res_seln 0 channels]
	set place        [db_get_col $res_seln 0 place]
	set hcap_score   [db_get_col $res_seln 0 hcap_score]
	set lock_stake_lmt [db_get_col $res_seln 0 lock_stake_lmt]

	# default values for double resulting
	set dbl_type    "Final"
	set dbl_user    "N/A"
	set main_result $result

	# if selection is part of a double resulting market, need to get double
	# resulting entries
	if {$dbl_res == "Y"} {


		#
		# Get double resulting entries
		#
		set sql [subst {
			select
				r.user_id,
				r.result,
				r.place,
				r.sp_num,
				r.sp_den,
				r.hcap_score,
				r.cr_date,
				a.username
			from
				tEvOc       o,
				tEvOcDblRes r,
				tAdminUser  a
			where
				o.ev_oc_id  = $oc_id       and
				o.ev_oc_id  = r.ev_oc_id   and
				r.user_id   = a.user_id
			order by
				cr_date
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res_dbl  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res_dbl]

		set user_ids [list]

		if {$nrows == 0} {

			set dbl_res_num   0

			if {$result == "-"} {
				set dbl_type      "1st"
				set dbl_user      "-"
			}

		} else {

			set dbl_res_num $nrows

			for {set r 0} {$r < $nrows} {incr r} {

				set user_id  [db_get_col $res_dbl $r user_id]

				if {$nrows == 1} {

					if {$user_id == $USERID} {
						set dbl_type      "1st"
						set dbl_user      [db_get_col $res_dbl 0 username]
						set dbl_res_num   0

						# overwrite the existing results
						foreach col  [list sp_num sp_den place result hcap_score] {
							set $col [db_get_col $res_dbl 0 $col]
						}

					} else {
						set DBL_RES(0,dbl_user)  [db_get_col $res_dbl 0 username]
						set DBL_RES(0,dbl_type) "1st"

						foreach col  [list sp_num sp_den place result hcap_score] {
							set DBL_RES(0,$col) "***"
						}

						set DBL_RES(0,dbl_mask) 1
						set dbl_type "2nd"
						set dbl_user "-"
					}
				} else {

					set DBL_RES($r,dbl_user)  [db_get_col $res_dbl $r username]

					foreach col  [list place result hcap_score] {
						set DBL_RES($r,$col) [db_get_col $res_dbl $r $col]
					}
					set DBL_RES($r,sp) [mk_price\
						[db_get_col $res_dbl $r sp_num]\
						[db_get_col $res_dbl $r sp_den]]

					if {$DBL_RES($r,sp) == ""} {
						set DBL_RES($r,sp) "-"
					}

					if {$r == 0} {
						set DBL_RES($r,dbl_type) "1st"
					} else {
						set DBL_RES($r,dbl_type) "2nd"

						# check results match - if not need to highlight
						# differences
						foreach val [list place result hcap_score sp] {
							if {$DBL_RES(0,$val) != $DBL_RES(1,$val)} {
								tpSetVar DBL_highlight_$val 1
							}
						}
					}

				}
			}


		}
		db_close $res_dbl
	} else {
		set dbl_res_num 0
	}

	tpSetVar      DblResNum $dbl_res_num

	tpBindVar DBL_dbl_type    DBL_RES dbl_type   dbl_idx
	tpBindVar DBL_dbl_user    DBL_RES dbl_user   dbl_idx
	tpBindVar DBL_dbl_mask    DBL_RES dbl_mask   dbl_idx
	tpBindVar DBL_sp          DBL_RES sp         dbl_idx
	tpBindVar DBL_place       DBL_RES place      dbl_idx
	tpBindVar DBL_result      DBL_RES result     dbl_idx
	tpBindVar DBL_hcap_score  DBL_RES hcap_score dbl_idx

	tpBindString DblType $dbl_type
	tpBindString DblUser $dbl_user

	tpSetVar Result     $main_result
	tpSetVar ResultSet  [expr {$main_result != "-"}]
	tpSetVar Confirmed  [expr {$result_conf == "Y"}]
	tpSetVar Settled    [expr {$settled == "Y"}]
	tpSetVar Flag       $fb_result
	tpSetVar UseDHRedn  [db_get_col $res_seln 0 use_dh_redn]

	switch $lock_stake_lmt {
		"N" {
			set lock_win_stake_lmt_bool "";
			set lock_place_stake_lmt_bool "";
			}
		"Y" {
			set lock_win_stake_lmt_bool "CHECKED";
			set lock_place_stake_lmt_bool "CHECKED";
			}
		"W" {
			set lock_win_stake_lmt_bool "CHECKED";
			set lock_place_stake_lmt_bool "";
			}
		"P" {
			set lock_win_stake_lmt_bool "";
			set lock_place_stake_lmt_bool "CHECKED";
			}
		default {
			set lock_win_stake_lmt_bool "";
			set lock_place_stake_lmt_bool "";
		}
	}
	tpBindString LOCK_WIN_STAKE_LIMITS $lock_win_stake_lmt_bool

	if {$lock_win_stake_lmt_bool == "CHECKED"} {
		tpBindString DisableMaxWin "DISABLED"
	} else {
		tpBindString DisableMaxWin ""
	}

	tpBindString LOCK_PLACE_STAKE_LIMITS $lock_place_stake_lmt_bool

	if {$lock_place_stake_lmt_bool == "CHECKED"} {
		tpBindString DisableMaxPlace "DISABLED"
	} else {
		tpBindString DisableMaxPlace ""
	}

	make_channel_binds $channels $channel_mask

	set LP [mk_price\
		[db_get_col $res_seln 0 lp_num]\
		[db_get_col $res_seln 0 lp_den]]

	set SP [mk_price\
		[db_get_col $res_seln 0 sp_num]\
		[db_get_col $res_seln 0 sp_den]]

	set GP [mk_price\
		[db_get_col $res_seln 0 sp_num_guide]\
		[db_get_col $res_seln 0 sp_den_guide]]

	set stk_or_lbt [db_get_col $res_seln 0 stk_or_lbt]

	tpBindString OcDesc       [db_get_col $res_seln 0 desc]
	tpBindString OcStatus     [db_get_col $res_seln 0 status]
	tpBindString OcResult     $result
	tpBindString OcPlace      $place
	tpBindString OcResultConf $result_conf
	tpBindString OcSettled    $settled
	tpBindString OcDisporder  [db_get_col $res_seln 0 disporder]
	tpBindString OcDisplayed  [db_get_col $res_seln 0 displayed]
	tpBindString OcLP         $LP
	tpBindString OcSP         $SP
	tpBindString OcSPGuide    $GP
	tpBindString OcFlag       $fb_result
	tpBindString OcHcapScore  $hcap_score
	tpBindString OcMultKey    [db_get_col $res_seln 0 mult_key]
	tpBindString OcExtKey     [db_get_col $res_seln 0 ext_key]
	tpBindString OcShortcut   [db_get_col $res_seln 0 shortcut]
	tpBindString OcAccMin     [db_get_col $res_seln 0 acc_min]
	tpBindString OcMinBet     [db_get_col $res_seln 0 min_bet]
	tpBindString OcMaxBet     [db_get_col $res_seln 0 max_bet]
	tpBindString OcSpMaxBet   [db_get_col $res_seln 0 sp_max_bet]
	tpBindString OcMaxPlaceSP [db_get_col $res_seln 0 max_place_sp]
	tpBindString OcMaxPlaceLP [db_get_col $res_seln 0 max_place_lp]
	tpBindString OcEpMaxBet   [db_get_col $res_seln 0 ep_max_bet]
	tpBindString OcMaxPlaceEP [db_get_col $res_seln 0 max_place_ep]
	tpBindString OcStkOrLbt   $stk_or_lbt
	tpBindString OcMaxTotal   [db_get_col $res_seln 0 max_total]
	tpBindString OcRunnerNum  [db_get_col $res_seln 0 runner_num]
	tpBindString OcRiskInfo   [db_get_col $res_seln 0 risk_info]
	tpBindString OcFeedUpd    [db_get_col $res_seln 0 feed_updateable]
	tpBindString OcFav        [db_get_col $res_seln 0 favourite]
	tpBindString OcMaxPotWin  [db_get_col $res_seln 0 max_pot_win]
	tpBindString OcMaxMultipleBet  [db_get_col $res_seln 0 max_multiple_bet]
	tpBindString OcEWFactor   [db_get_col $res_seln 0 ew_factor]
	tpBindString OcCode       [db_get_col $res_seln 0 oc_code]
	tpBindString FcStkLimit   [db_get_col $res_seln 0 fc_stk_limit]
	tpBindString TcStkLimit   [db_get_col $res_seln 0 tc_stk_limit]
	tpBindString OcHasVariant [db_get_col $res_seln 0 has_oc_variants]
	tpBindString OcTeamName   [db_get_col $res_seln 0 team_name]
	tpBindString OcTeamId     [db_get_col $res_seln 0 team_id]
	tpBindString OcFixedStake [db_get_col $res_seln 0 fixed_stake_limits]
	tpBindString OcSelMsg     [db_get_col $res_seln 0 selection_msg]
	tpBindString ReqGUID      [db_get_col $res_seln 0 req_guid]
	tpBindString OcSelLinkKey [db_get_col $res_seln 0 link_key]

	if {$stk_or_lbt == "L"} {
		set  lp_win_liab  [db_get_col $res_seln 0 lp_win_liab]
		set  sp_win_liab  [db_get_col $res_seln 0 sp_win_liab]
		tpBindString OcCurLiab [expr {$sp_win_liab + $lp_win_liab}]
	}

	if {[string first $mkt_type "AHLl"] >= 0} {
		tpBindString OcCurTotal   [db_get_col $res_seln 0 lp_win_liab]
	} else {
		tpBindString OcCurTotal   [db_get_col $res_seln 0 cur_total]
	}

	if {$cs_home != "" && $cs_away != ""} {
		tpBindString OcCSHome $cs_home
		tpBindString OcCSAway $cs_away
	}

	tpBindString OcId $oc_id

	db_close $res_seln

	#
 	# BetFair outcome settings
 	#
 	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_SELN::go_bf_oc_upd $oc_id $mkt_id
 	}

	#
	# Bind results and flags and risk info
	#
	bind_mkt_flags    $csort $mkt_sort
	bind_seln_results $csort $mkt_sort $fb_result
	bind_risk_info

	#
	# Optional configuration items to simplify result setting
	#
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort places] == "never"} {
		tpSetVar MktCanPlace 0
	} else {
		tpSetVar MktCanPlace 1
	}
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort dead-heat] == "never"} {
		tpSetVar MktCanDeadHeat 0
	} else {
		tpSetVar MktCanDeadHeat 1
	}

	#
	# Get selection price history
	#
	set sql [subst {
		select
			price_id,
			cr_date,
			p_num,
			p_den,
			status
		from
			tEvOcPrice
		where
			ev_oc_id = $oc_id
		order by
			price_id desc
	}]

	set stmt      [inf_prep_sql $DB $sql]
	set res_price [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumPrices [set nrows [db_get_nrows $res_price]]

	global PRC

	for {set r 0} {$r < $nrows} {incr r} {
		set PRC($r,LP) [mk_price\
			[db_get_col $res_price $r p_num]\
			[db_get_col $res_price $r p_den]]
	}

	tpBindVar OcPr       PRC         LP         price_idx
	tpBindTcl OcPrId     sb_res_data $res_price price_idx price_id
	tpBindTcl OcPrDate   sb_res_data $res_price price_idx cr_date
	tpBindTcl OcPrStatus sb_res_data $res_price price_idx status

	if {[OT_CfgGet FUNC_FORM_FEEDS 0]} {
		ADMIN::FORM::make_form_feed_provider_binds
	}

	# work out number of columns in results table
	set colspan 1
	set rowspan 1

	if {[string first $mkt_type "AHM"] >= 0 &&   $fb_result != "L"} {
		incr colspan
	} elseif {[string first [tpGetVar MktType] "LUSC"] == -1 &&
	          [tpGetVar MktCanPlace 1]} {
		incr colspan
	}
	if {$settled != "Y" && $result_conf != "Y"} {
		if {$sp_avail  == "Y"} {
			incr colspan
		}
	}
	if {$dbl_res == "Y"} {
		incr colspan +2
		incr rowspan
	}

	tpBindString ResColSpan $colspan
	tpBindString ResRowSpan $rowspan

	#
	#
	# If we've just come from the event list results page
	# we have to remember what the search criteria is to go
	# back to this page successfully.  If we've come from
	# anywhere else, these values will just be blank.
	# slee
	#

	tpBindString ClassId    [reqGetArg ClassId]
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

	asPlayFile -nocache selection.html

	db_close $res_price

	catch {unset PRC}
	catch {unset FLAGS}
	catch {unset RESULTS}
	catch {unset DBL_RES}
	catch {unset RISK}
	catch {unset BF_MTCH}
}


#
# ----------------------------------------------------------------------------
# Price "manipulation"
# ----------------------------------------------------------------------------
#
proc go_oc_price args {

	global DB

	set oc_price_id [reqGetArg OcPriceId]

	set sql [subst {
		select
			ev_oc_id,
			cr_date,
			p_num,
			p_den,
			status
		from
			tEvOcPrice
		where
			price_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $oc_price_id]
	inf_close_stmt $stmt

	set p_num [db_get_col $res 0 p_num]
	set p_den [db_get_col $res 0 p_den]

	tpBindString OcPriceId     $oc_price_id
	tpBindString OcId          [db_get_col $res 0 ev_oc_id]
	tpBindString OcPrice       [mk_price $p_num $p_den]
	tpBindString OcPriceDate   [db_get_col $res 0 cr_date]
	tpBindString OcPriceStatus [db_get_col $res 0 status]

	db_close $res

	asPlayFile -nocache seln_price.html
}


proc do_oc_price_upd args {

	if {[reqGetArg SubmitName] == "Back"} {
		go_oc_upd
		return
	}

	global DB

	set sql {
		update tEvOcPrice set
			status = ?
		where
			price_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt\
		[reqGetArg OcPriceStatus]\
		[reqGetArg OcPriceId]]
	inf_close_stmt $stmt

	db_close $res

	go_oc_upd
}



#
# ----------------------------------------------------------------------------
# Selection update
# ----------------------------------------------------------------------------
#
proc do_oc args {

	set act [reqGetArg SubmitName]

	if {$act == "SelnAdd"} {
		do_oc_add
	} elseif {$act == "SelnMod"} {
		do_oc_upd
	} elseif {$act == "SelnDel"} {
		do_oc_del
	} elseif {$act == "SelnSetRes"} {
		do_oc_set_res
	} elseif {$act == "SelnConf"} {
		do_oc_conf_res
	} elseif {$act == "SelnUnconf"} {
		do_oc_conf_res
	} elseif {$act == "SelnStl"} {
		do_oc_stl
	} elseif {$act == "SelnReStl"} {
		do_oc_restl
	} elseif {$act == "SelnSettleChk"} {
		ADMIN::SETTLE::add_seln_stl_chk
	} elseif {$act == "ViewDHRedns"} {
		do_oc_dheat_redn
	} elseif {$act == "Back"} {
		ADMIN::MARKET::go_mkt
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_oc_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsEvOc(
			p_adminuser = ?,
			p_ev_mkt_id = ?,
			p_ev_id = ?,
			p_desc = ?,
			p_status = ?,
			p_ext_key = ?,
			p_shortcut = ?,
			p_ext_id = ?,
			p_disporder = ?,
			p_displayed = ?,
			p_acc_min = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_max_place_lp = ?,
			p_max_place_sp = ?,
			p_ep_max_bet = ?,
			p_max_place_ep = ?,
			p_max_total = ?,
			p_stk_or_lbt = ?,
			p_lp_num = ?,
			p_lp_den = ?,
			p_sp_num_guide = ?,
			p_sp_den_guide = ?,
			p_mult_key = ?,
			p_fb_result = ?,
			p_cs_home = ?,
			p_cs_away = ?,
			p_runner_num = ?,
			p_channels = ?,
			p_risk_info = ?,
			p_allow_feed_upd = ?,
			p_lock_stake_lmt = ?,
			p_max_pot_win = ?,
			p_max_multiple_bet = ?,
			p_ew_factor = ?,
			p_do_tran = 'N',
			p_gen_code = ?,
			p_team_id = ?,
			p_fixed_stake_limits = ?,
			p_selection_msg = ?,
			p_link_key = ?
		)
	}]


	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
		set v_[reqGetNthName $a] [reqGetNthVal $a]
	}

	set channels [make_channel_str]

	set bad 0

	#
	# Make some market-specific pricing checks
	#
	set v_MktType   [reqGetArg MktType]
	set v_MktSort   [reqGetArg MktSort]
	set v_OcLP      [reqGetArg OcLP]
	set v_OcSPGuide [reqGetArg OcSPGuide]
	set v_APCPrcLo  [reqGetArg APCPrcLo]
	set v_APCPrcHi  [reqGetArg APCPrcHi]

	if {[string first $v_MktType "AHLl"] >= 0} {
		if {[string trim $v_OcLP] != ""} {
			if {$v_APCPrcLo != ""} {
				if {$v_APCPrcLo > $v_OcLP}  {
					set msg "Price ($v_OcLP) is below minimum ($v_APCPrcLo)"
					set bad 1
				}
				if {$v_APCPrcHi < $v_OcLP}  {
					set msg "Price ($v_OcLP) is above maximum ($v_APCPrcHi)"
					set bad 1
				}
			}
		}
	}

	#
	# Check whether MARKET_PROPERTIES (config item) requires
	# OcFlag to be unique for selections in this market
	#
	set unique [ADMIN::MKTPROPS::mkt_flag $v_ClassSort $v_MktSort unique false]
	if {$unique=="true" && [do_oc_check_unique_oc_flag $v_OcFlag $v_MktId]=="fail"} {
		set dropdown_desc [ADMIN::MKTPROPS::mkt_flag $v_ClassSort $v_MktSort desc ""]
		set msg "The value given in the $dropdown_desc drop-down menu must be unique for each selection on this market."
		set bad 1
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		err_bind $msg
		go_oc_add
		return
	}

	if {[OT_CfgGet FUNC_GEN_OC_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	set stmt [inf_prep_sql $DB $sql]

	#
	# Get price information
	#
	foreach {LP_N LP_D} [get_price_parts $v_OcLP]      { break }
	foreach {GP_N GP_D} [get_price_parts $v_OcSPGuide] { break }

	#
	#determine what stake locking should be applied
	#
	set lock_win_stake_limits [reqGetArg lock_win_stake_limits];
	set lock_place_stake_limits [reqGetArg lock_place_stake_limits];

	if {$lock_win_stake_limits == "on" && $lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "Y";
	} elseif {$lock_win_stake_limits == "on"} {
		set lock_stake_limits_code "W";
	} elseif {$lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "P";
	} else {
		set lock_stake_limits_code "N";
	}

	OT_LogWrite 5 "record locked = $lock_stake_limits_code";

	set fixed_stake_limits [expr {[reqGetArg fixed_stake_limits] == "on" ? 1 : 0}]

	#
	# Attempt insert of selection
	#
	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktId]\
			[reqGetArg EvId]\
			[reqGetArg OcDesc]\
			[reqGetArg OcStatus]\
			[reqGetArg OcExtKey]\
			[reqGetArg OcShortcut]\
			[reqGetArg OcExtId]\
			[reqGetArg OcDisporder]\
			[reqGetArg OcDisplayed]\
			[reqGetArg OcAccMin]\
			[reqGetArg OcMinBet]\
			[reqGetArg OcMaxBet]\
			[reqGetArg OcSpMaxBet]\
			[reqGetArg OcMaxPlaceLP]\
			[reqGetArg OcMaxPlaceSP]\
			[reqGetArg OcEpMaxBet]\
			[reqGetArg OcMaxPlaceEP]\
			[reqGetArg OcMaxTotal]\
			[reqGetArg OcStkOrLbt]\
			$LP_N\
			$LP_D\
			$GP_N\
			$GP_D\
			[reqGetArg OcMultKey]\
			[reqGetArg OcFlag]\
			[reqGetArg OcCSHome]\
			[reqGetArg OcCSAway]\
			[reqGetArg OcRunnerNum]\
			$channels\
			[reqGetArg OcRiskInfo]\
			[reqGetArg OcFeedUpdateable]\
			$lock_stake_limits_code\
			[reqGetArg OcMaxPotWin]\
			[reqGetArg OcMaxMultipleBet]\
			[reqGetArg OcEWFactor]\
			$gen_code\
			[reqGetArg teamId]\
			$fixed_stake_limits\
			[reqGetArg OcSelMsg]\
			[reqGetArg OcSelLinkKey]\
		]
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	if {!$bad} {
		set oc_id [db_get_coln $res 0 0]

		if {[OT_CfgGet FUNC_BET_MATCHING 0]} {
			set sql_tevoc_desc [subst {
				insert into tevoc_desc (
					btn_text_f,
					btn_text_a,
					ev_oc_id
				 ) values (
					?, ?, ?
				)
			}]
			set stmt [inf_prep_sql $DB $sql_tevoc_desc]
			if {[catch {
				set rs [inf_exec_stmt $stmt\
					[reqGetArg btn_text_f]\
					[reqGetArg btn_text_a]\
					$oc_id]} msg]} {
				set bad 1
				err_bind $msg
			}

			inf_close_stmt $stmt
			catch {db_close $rs}
		}
	}

	if {$bad || [db_get_nrows $res] != 1} {
		#
		# Something went wrong : go back to the selection screen
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_oc_add
		return
	}

	inf_commit_tran $DB

	db_close $res

	#
	# Insertion was OK, go back to the market screen
	#
	tpSetVar OcAdded 1

	ADMIN::MARKET::go_mkt
}

proc do_oc_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdEvOc(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_desc = ?,
			p_disporder = ?,
			p_displayed = ?,
			p_status = ?,
			p_ext_key = ?,
			p_shortcut = ?,
			p_ext_id = ?,
			p_acc_min = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_max_place_lp = ?,
			p_max_place_sp = ?,
			p_ep_max_bet = ?,
			p_max_place_ep = ?,
			p_max_total = ?,
			p_mult_key = ?,
			p_fb_result = ?,
			p_cs_home = ?,
			p_cs_away = ?,
			p_lp_num = ?,
			p_lp_den = ?,
			p_sp_num_guide = ?,
			p_sp_den_guide = ?,
			p_runner_num = ?,
			p_channels = ?,
			p_risk_info = ?,
			p_allow_feed_upd = ?,
			p_lock_stake_lmt = ?,
			p_max_pot_win = ?,
			p_ew_factor = ?,
			p_code = ?,
			p_fc_stk_limit = ?,
			p_tc_stk_limit = ?,
			p_do_tran = 'N',
			p_max_multiple_bet = ?,
			p_team_id = ?,
			p_fixed_stake_limits = ?,
			p_priced_by_feed = ?,
			p_selection_msg = ?,
			p_link_key = ?
		)
	}]

	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
		set v_[reqGetNthName $a] [reqGetNthVal $a]
	}

	set channels [make_channel_str]

	set bad 0

	#
	# Make some market-specific pricing checks
	#
	set v_MktSort   [reqGetArg MktSort]
	set v_OcLP      [reqGetArg OcLP]
	set v_OcSPGuide [reqGetArg OcSPGuide]
	set v_APCPrcLo  [reqGetArg APCPrcLo]
	set v_APCPrcHi  [reqGetArg APCPrcHi]

	if {$v_MktSort == "AH"} {
		if {[string trim $v_OcLP] != ""} {
			if {$v_APCPrcLo != ""} {
				if {$v_APCPrcLo > $v_OcLP}  {
					set msg "Price ($v_OcLP) is below minimum ($v_APCPrcLo)"
					set bad 1
				}
				if {$v_APCPrcHi < $v_OcLP}  {
					set msg "Price ($v_OcLP) is above maximum ($v_APCPrcHi)"
					set bad 1
				}
			}
		}
	}


	#
	# Check whether MARKET_PROPERTIES (config item) requires
	# OcFlag to be unique for selections in this market
	#
	set unique [ADMIN::MKTPROPS::mkt_flag $v_ClassSort $v_MktSort unique false]
	if {$unique=="true" && [do_oc_check_unique_oc_flag $v_OcFlag $v_MktId $v_OcId]=="fail"} {
		set dropdown_desc [ADMIN::MKTPROPS::mkt_flag $v_ClassSort $v_MktSort desc ""]
		set msg "The value given in the $dropdown_desc drop-down menu must be unique for each selection on this market."
		set bad 1
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		err_bind $msg
		go_oc_upd
		return
	}

	set stmt [inf_prep_sql $DB $sql]

	foreach {LP_N LP_D} [get_price_parts $v_OcLP]      { break }
	foreach {GP_N GP_D} [get_price_parts $v_OcSPGuide] { break }

	# Set up FC/TC stake limits
	set fc_stk_limit [reqGetArg fc_stk_limit]
	set tc_stk_limit [reqGetArg tc_stk_limit]

	#
	#determine what stake locking should be applied
	#
	set lock_win_stake_limits [reqGetArg lock_win_stake_limits];
	set lock_place_stake_limits [reqGetArg lock_place_stake_limits];

	if {$lock_win_stake_limits == "on" && $lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "Y";
	} elseif {$lock_win_stake_limits == "on"} {
		set lock_stake_limits_code "W";
	} elseif {$lock_place_stake_limits == "on"} {
		set lock_stake_limits_code "P";
	} else {
		set lock_stake_limits_code "N";
	}

	OT_LogWrite 5 "record locked = $lock_stake_limits_code";

	set fixed_stake_limits [expr {[reqGetArg fixed_stake_limits] == "on" ? 1 : 0}]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg OcId]\
			[reqGetArg OcDesc]\
			[reqGetArg OcDisporder]\
			[reqGetArg OcDisplayed]\
			[reqGetArg OcStatus]\
			[reqGetArg OcExtKey]\
			[reqGetArg OcShortcut]\
			[reqGetArg OcExtId]\
			[reqGetArg OcAccMin]\
			[reqGetArg OcMinBet]\
			[reqGetArg OcMaxBet]\
			[reqGetArg OcSpMaxBet]\
			[reqGetArg OcMaxPlaceLP]\
			[reqGetArg OcMaxPlaceSP]\
			[reqGetArg OcEpMaxBet]\
			[reqGetArg OcMaxPlaceEP]\
			[reqGetArg OcMaxTotal]\
			[reqGetArg OcMultKey]\
			[reqGetArg OcFlag]\
			[reqGetArg OcCSHome]\
			[reqGetArg OcCSAway]\
			$LP_N\
			$LP_D\
			$GP_N\
			$GP_D\
			[reqGetArg OcRunnerNum]\
			$channels\
			[reqGetArg OcRiskInfo]\
			[reqGetArg OcFeedUpdateable]\
			$lock_stake_limits_code\
			[reqGetArg OcMaxPotWin]\
			[reqGetArg OcEWFactor]\
			[reqGetArg OcCode]\
			$fc_stk_limit\
			$tc_stk_limit\
			[reqGetArg OcMaxMultipleBet]\
			[reqGetArg teamId]\
			$fixed_stake_limits\
			[reqGetArg PricedByFeed]\
			[reqGetArg OcSelMsg]\
			[reqGetArg OcSelLinkKey]\
		]
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	if {[OT_CfgGet FUNC_BET_MATCHING 0]} {
		set sql_tevoc_desc_check {
			select
				*
			from
				tevoc_desc
			where
				ev_oc_id = ?
		}
		set stmt [inf_prep_sql $DB $sql_tevoc_desc_check]
		set rs [inf_exec_stmt $stmt [reqGetArg OcId]]
		inf_close_stmt $stmt

		set nr [db_get_nrows $rs]
		db_close $rs

		if {$nr == 0} {
			set sql_tevoc_desc {
				insert into tevoc_desc (
					btn_text_f,
					btn_text_a,
					ev_oc_id
			 	) values (
					?, ?, ?
				)
			}
		} else {
			set sql_tevoc_desc {
				update tevoc_desc set
					btn_text_f = ?,
					btn_text_a = ?
				where
					ev_oc_id = ?
			}
		}
		set stmt [inf_prep_sql $DB $sql_tevoc_desc]
		if {[catch {
			set rs [inf_exec_stmt $stmt\
				[reqGetArg btn_text_f]\
				[reqGetArg btn_text_a]\
				[reqGetArg OcId]]} msg]} {
			set bad 1
			err_bind $msg
		}
		inf_close_stmt $stmt
		catch {db_close $rs}
	}

	if {$bad || [db_get_nrows $res] != 1} {
		#
		# Something went wrong : go back to the selection screen
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_oc_upd
		return
	}

	inf_commit_tran $DB

	db_close $res

	if {[OT_CfgGet BF_ACTIVE 0]} {
		set bad [ADMIN::BETFAIR_SELN::do_bf_oc_upd]
		if {$bad == 1} {
		   return
		}
	}

	# if the selection just updated is in a WDW market then
	# update double chance odds
	if {$v_MktSort == {MR}} {
		ADMIN::AUTOGEN::update_mkt_odds_DC $v_EvId
	}

	# If the "Force removal of price" box is checked, do so:
	if {[reqGetNumArgs null_price]} {
		set null_price_sql {
			update tEvOc set
				lp_num = null,
				lp_den = null
			where
				ev_oc_id = ?;
		}
		set oc_id [reqGetArg OcId]
		ob::log::write INFO "ADMIN::SELN::do_oc_upd - Clearing price for selection $oc_id"
		set null_stmt [inf_prep_sql $DB $null_price_sql]
		set rs [inf_exec_stmt $null_stmt $oc_id]
		inf_close_stmt $null_stmt
		db_close $rs
	}


	#
	# Update was OK, go back to the market screen
	#
	tpSetVar OcUpdated 1

	ADMIN::MARKET::go_mkt
}

# Return "fail" if some row exists in tevoc with ev_mkt_id=mkt_id
# and fb_result=oc_flag and ev_oc_id<>oc_id
# Return "succeed" otherwise.
# If we don't supply oc_id (i.e. We're doing an insert rather than
# an update) then we remove that clause from the sql
proc do_oc_check_unique_oc_flag {oc_flag mkt_id {oc_id -1}} {
	global DB

	set sql [subst {
		select
			oc.ev_oc_id
		from
			tevoc oc, tevmkt m
		where
			oc.ev_mkt_id = m.ev_mkt_id and
			m.ev_mkt_id = $mkt_id and
			oc.fb_result = $oc_flag
	}]

	if {$oc_id!=-1} {
		append sql " and oc.ev_oc_id <> $oc_id"
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		set res [inf_exec_stmt $stmt]
	} msg]} {
		inf_close_stmt $stmt
		error "Error checking uniqueness of OcFlag: $msg"
	}
	set count [db_get_nrows $res]

	inf_close_stmt $stmt

	if {$count>0} {
		return "fail"
	} else {
		return "succeed"
	}
}

proc do_oc_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelEvOc(
			p_adminuser = ?,
			p_ev_oc_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg OcId]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
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
		go_oc
		return
	}

	ADMIN::MARKET::go_mkt
}

proc do_oc_set_res args {

	global DB USERNAME

	set oc_id [reqGetArg OcId]
	set OcRes [reqGetArg OcResult]

	if {$OcRes == "W" || $OcRes == "P"} {
		set show_prc_set [do_show_price_check $oc_id]
		set fs [lindex $show_prc_set 0]
		set ss [lindex $show_prc_set 1]
		if {$fs == "N" || ($fs=="-" && $ss=="N")} {
			tpSetVar ShowPriceSet "Y"
			go_oc_upd
			return
		}
	}

	set sql [subst {
		execute procedure pSetEvOcResult(
			p_adminuser     = ?,
			p_ev_oc_id      = ?,
			p_result        = ?,
			p_place         = ?,
			p_sp_num        = ?,
			p_sp_den        = ?,
			p_hcap_score    = ?,
			p_func_dbl_res  = ?,
			p_force_dbl_res = ?
		)
	}]

	set bad 0

	foreach {SP_N SP_D} [get_price_parts [reqGetArg OcSP]] { break }

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg OcId]\
			[reqGetArg OcResult]\
			[reqGetArg OcPlace]\
			$SP_N\
			$SP_D\
			[reqGetArg OcHcapScore]\
			[expr {[OT_CfgGet FUNC_DBL_RES 0]?"Y":"N"}]\
			[expr {[reqGetArg DblResForce] == 1?"Y":"N"}]]} msg]} {
		err_bind $msg
		set bad 1
	}
	inf_close_stmt $stmt

	if {!$bad} {
		# store result of update
		set r [db_get_coln $res 0]
	}


	catch {db_close $res}

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_oc
		return
	}

	inf_commit_tran $DB

	if {$r == 1} {
		msg_bind "Successfully updated results"
	} elseif {$r == 0} {
		msg_bind "First stage of double resulting complete"
	} else {
		err_bind "Mismatches were found during double resulting. Please review"
	}

	set mkt_id [reqGetArg MktId]

	if {$mkt_id != "" && $r != -1} {

		ADMIN::MARKET::go_mkt
		return

	} else {

		# For BIRTi calls into this function or if error in double resulting,
		# go to the selection
		go_oc
		return
	}
}

proc do_oc_conf_res args {

	global DB USERNAME

	set oc_id [reqGetArg OcId]
	set OcRes [reqGetArg OcResult]

	if {$OcRes == "W" || $OcRes == "P"} {
		set show_prc_set [do_show_price_check $oc_id]
		set fs [lindex $show_prc_set 0]
		set ss [lindex $show_prc_set 1]
		if { $fs == "N" || ($fs=="-" && $ss=="N")} {
			tpSetVar ShowPriceSet "Y"
			go_oc_upd
			return
		}
	}

	if {[reqGetArg SubmitName] == "SelnConf"} {
		set conf_flag Y
	} else {
		set conf_flag N
	}

        # For BIR, skip dividend stuff
        set mkt_id [reqGetArg MktId]

	if {$OcRes != "V" && $mkt_id != ""} {
	if {$conf_flag=="Y"} {


		set mkt_id [reqGetArg MktId]

		#check that any required dividends have been set before allowing confirmation
		set errors [ADMIN::MARKET::check_market_dividend_set $mkt_id]

		if {$errors !=""} {
			err_bind $errors
			OT_LogWrite 30 "Selection result confirm attempted for ev_mkt_id:$mkt_id with forecast/tricast dividends unset"
			go_oc
			return
		}
	}
	}


	set sql [subst {
		execute procedure pSetResultConf(
			p_adminuser = ?,
			p_obj_type = ?,
			p_obj_id = ?,
			p_conf = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			S\
			$oc_id\
			$conf_flag]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
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
		go_oc
		return
	}


        # For BIR, go to selection
        if {$mkt_id != ""} {
                ADMIN::MARKET::go_mkt
                return
        } else {
                go_oc
                return
        }

}


#
# ----------------------------------------------------------------------------
# Settle this selection
# ----------------------------------------------------------------------------
#
proc do_oc_stl args {

	global USERNAME

	# For BIR, skip dividend stuff
	set mkt_id [reqGetArg MktId]
	set OcRes [reqGetArg OcResult]
	if {$OcRes != "V" && $mkt_id != ""} {
		set errors [ADMIN::MARKET::check_market_dividend_set $mkt_id]
		if {$errors != ""} {
			OT_LogWrite 30 "Result confirm attempted for ev_mkt_id:$mkt_id with forecast/tricast dividends unset"
			err_bind $errors
			go_oc
			return
		}
	}

	tpSetVar StlObj   selection
	tpSetVar StlObjId [reqGetArg OcId]
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

#
# ----------------------------------------------------------------------------
# Settle this selection
# ----------------------------------------------------------------------------
#
proc do_oc_restl args {

	global USERNAME

	if {![op_allowed ReSettle]} {
		err_bind "You don't have permission to re-settle selections"
		go_ocs_upd
		return
	} else {
		do_oc_stl
	}
}

#
# ----------------------------------------------------------------------------
# Show Dead Heat reductions for this seln
# ----------------------------------------------------------------------------
#
proc do_oc_dheat_redn args {

	global DB TERMS

	set ev_oc_id [reqGetArg OcId]
	set mkt_id   [reqGetArg MktId]

	set deadheat_ev_sql [subst {
		select
			e.ew_terms_id,
			e.ew_fac_num,
			e.ew_fac_den,
			e.ew_places,
			d.dh_num,
			d.dh_den,
			d.dh_type
		from
			tEachWayTerms e,
			outer tDeadHeatRedn d
		where
			e.ev_mkt_id    = ?              and
			e.ew_terms_id  = d.ew_terms_id  and
			d.ev_oc_id     = ?              and
			d.dh_type      = 'P'

		union

		select
			d.ew_terms_id,
			-1,
			-1,
			-1,
			d.dh_num,
			d.dh_den,
			d.dh_type
		from
			 tDeadHeatRedn d
		where
			d.ev_oc_id    = ? and
			d.ew_terms_id is null
	}]

 	set stmt       [inf_prep_sql $DB $deadheat_ev_sql]
	set res_seln   [inf_exec_stmt $stmt $mkt_id $ev_oc_id $ev_oc_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_seln]

	for {set r 0} {$r < $nrows} {incr r} {

		set dh_type     [db_get_col $res_seln $r dh_type]
		set ew_terms_id [db_get_col $res_seln $r ew_terms_id]

		if {$ew_terms_id == ""} {
			if {$dh_type == "W"} {
				set w_dh_num($ev_oc_id) [db_get_col $res_seln $r dh_num]
				set w_dh_den($ev_oc_id) [db_get_col $res_seln $r dh_den]
			} else {
				set p_dh_num($ev_oc_id) [db_get_col $res_seln $r dh_num]
				set p_dh_den($ev_oc_id) [db_get_col $res_seln $r dh_den]
			}
		} else {

			set EACHW($r,ew_terms_id)  $ew_terms_id
			set EACHW($r,ew_fac_num)   [db_get_col $res_seln $r ew_fac_num]
			set EACHW($r,ew_fac_den)   [db_get_col $res_seln $r ew_fac_den]
			set EACHW($r,ew_places)    [db_get_col $res_seln $r ew_places]
			set EACHW($r,ev_oc_id)     $ev_oc_id

			set p_dh_num($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) \
				[db_get_col $res_seln $r dh_num]
			set p_dh_den($EACHW($r,ew_terms_id),$EACHW($r,ev_oc_id)) \
				[db_get_col $res_seln $r dh_den]

			set ew_term_ids($EACHW($r,ew_terms_id)) "$EACHW($r,ew_places) \
				$EACHW($r,ew_fac_num) $EACHW($r,ew_fac_den)"
		}

	}

 	# Build list of ew_terms. HTML will loop through it and try and get
	# reductions for each event, if exists
	set l 0
	set EW_terms ""
	foreach ew_term_id [array names ew_term_ids] {
		set TERMS($l,ew_terms_id)      $ew_term_id
		set TERMS($l,ew_fac_num)       [lindex $ew_term_ids($ew_term_id) 1]
		set TERMS($l,ew_fac_den)       [lindex $ew_term_ids($ew_term_id) 2]
		set TERMS($l,ew_places)        [lindex $ew_term_ids($ew_term_id) 0]
		incr l
	}

	tpSetVar      NumTerms $l
	tpSetVar      OcId $ev_oc_id
	tpBindString  ColSpan [expr {$l + 8}]
	tpBindVar     TERMS_ew_terms_id TERMS ew_terms_id terms_idx
	tpBindVar     TERMS_ew_fac_num  TERMS ew_fac_num  terms_idx
	tpBindVar     TERMS_ew_fac_den  TERMS ew_fac_den  terms_idx
	tpBindVar     TERMS_ew_places   TERMS ew_places   terms_idx

	asPlayFile -nocache dheat_redn.html
}

#
# ----------------------------------------------------------------------------
# Go to bulk selection update
# ----------------------------------------------------------------------------
#
proc go_ocs_upd args {

	global DB CHANNELS CHANNEL_MAP

	if {[info exists CHANNELS]} {
		unset CHANNELS
	}

	set mkt_id [reqGetArg MktId]

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			c.name class_name,
			c.category,
			m.type,
			m.sort,
			m.status,
			e.start_time,
			e.result_conf,
			e.desc,
			e.ev_id,
			m.lp_avail,
			m.sp_avail,
			m.hcap_value,
			m.channels mkt_channels,
			m.bir_index,
			m.ew_fac_num,
			m.ew_fac_den,
			g.name mkt_name,
			g.grouped,
			y.ah_prc_lo,
			y.ah_prc_hi
		from
			tEvMkt       m,
			tEv          e,
			tEvOcGrp     g,
			tEvMktConstr y,
			tEvType      t,
			tEvClass     c
		where
			m.ev_mkt_id    = $mkt_id        and
			m.ev_id        = e.ev_id        and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			m.ev_mkt_id    = y.ev_mkt_id    and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id;
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set csort        [db_get_col $res 0 csort]
	set mkt_type     [db_get_col $res 0 type]
	set mkt_sort     [db_get_col $res 0 sort]
	set status       [db_get_col $res 0 status]
	set start_time   [db_get_col $res 0 start_time]
	set result_conf  [db_get_col $res 0 result_conf]
	set lp_avail     [db_get_col $res 0 lp_avail]
	set sp_avail     [db_get_col $res 0 sp_avail]
	set hcap_value   [db_get_col $res 0 hcap_value]
	set mkt_channels [db_get_col $res 0 mkt_channels]
	set bir_index    [db_get_col $res 0 bir_index]
	set ew_fac_num   [db_get_col $res 0 ew_fac_num]
	set ew_fac_den   [db_get_col $res 0 ew_fac_den]

	tpBindString ClassSort   $csort
	tpBindString EvDesc      [db_get_col $res 0 desc]
	tpBindString EvStartTime $start_time
	tpBindString MktName     [db_get_col $res 0 mkt_name]
	tpBindString MktActive   [expr { ( [db_get_col $res 0 status] == "A") ? 1 : 0 }]
	tpBindString MktType     $mkt_type
	tpBindString MktSort     $mkt_sort
	tpBindString EvId        [db_get_col $res 0 ev_id]
	tpBindString MktId       $mkt_id

	if {[OT_CfgGet REMAIN_DISP_LIVE_PRICES 0] == 1} {
		tpBindString MktLPAvail  "Y"
	} else {
		tpBindString MktLPAvail  $lp_avail
	}
	tpBindString MktSPAvail  $sp_avail
	tpBindString BirIndex    $bir_index
	tpSetVar     MktGrouped  [db_get_col $res 0 grouped]

	tpSetVar ClassSort  $csort
	tpSetVar ClassName  [db_get_col $res 0 class_name]
	tpSetVar Category   [db_get_col $res 0 category]
	tpSetVar MktType    $mkt_type
	tpSetVar MktSort    $mkt_sort
	if {[string first $mkt_type "AHLl"] >= 0} {
		tpSetVar HcapMkt 1
	} else {
		tpSetVar HcapMkt 0
	}
	if {[OT_CfgGet REMAIN_DISP_LIVE_PRICES 0] == 1} {
		tpSetVar MktLPAvail "Y"
	} else {
		tpSetVar MktLPAvail [expr {$lp_avail == "Y"}]
	}
	tpSetVar MktSPAvail [expr {$sp_avail == "Y"}]

	#
	# Play with the handicap value for handicap/asian handicap market...
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
				set hcap_side ""
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

	tpBindString MktHcapValue $hcap_value

	db_close $res


	#
	# Get selection information
	#
	set sql [subst {
		select
			o.ev_oc_id,
			c.ev_class_id,
			o.desc,
			o.status,
			o.result,
			o.result_conf,
			o.place,
			o.settled,
			o.disporder,
			o.displayed,
			o.lp_num,
			o.lp_den,
			o.sp_num,
			o.sp_den,
			o.sp_num_guide,
			o.sp_den_guide,
			o.fb_result,
			o.mult_key,
			o.min_bet,
			o.max_bet,
			o.sp_max_bet,
			o.ep_max_bet,
			o.runner_num,
			o.channels,
			o.feed_updateable,
			o.has_oc_variants,
			o.max_pot_win,
			o.max_multiple_bet,
			o.ew_factor,
			z.stk_or_lbt,
			z.max_total,
			z.cur_total,
			case when (o.lp_num is not null and o.lp_den is not null) then
				o.lp_num/o.lp_den
				 when (o.sp_num is not null and o.sp_den is not null) then
				o.sp_num/o.sp_den
				 when (o.sp_num_guide is not null and o.sp_den_guide is not null) then
				o.sp_num_guide/o.sp_den_guide
				 else
				0
 			end prc_ord,
 			case fb_result
 				when 'H' then 0
 				when 'D' then 1
 				when 'A' then 2
 			end mr_order,
			o.link_key
		from
			tEvOc       o,
			tEv 	    e,
			tEvClass    c,
			tEvOcConstr z
		where
			o.ev_mkt_id = $mkt_id and
			o.ev_oc_id  = z.ev_oc_id and
			o.ev_id = e.ev_id and
			e.ev_class_id = c.ev_class_id
		order by
			disporder asc, mr_order asc, prc_ord, o.desc
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumMktSelns [set nrows [db_get_nrows $res_seln]]

	global PRC

	read_channel_info

	set numMktChnnl [string length $mkt_channels]

	tpSetVar NumChannels $numMktChnnl
	tpBindString EWPL [mk_price $ew_fac_num $ew_fac_den]

	for {set r 0} {$r < $nrows} {incr r} {
		set ev_oc_channels [db_get_col $res_seln $r channels]
		for {set j 0} {$j < $numMktChnnl} {incr j} {
			  set mc [string index $mkt_channels $j]
			  set CHANNELS($r,$j,chnnl_name) $CHANNEL_MAP(code,$mc)
			  set CHANNELS($r,$j,channel_cd) $mc
			  if {[string first $mc $ev_oc_channels] >= 0} {
				set CHANNELS($r,$j,use) "checked"
			  } else {
				set CHANNELS($r,$j,use) ""
			  }
		}
		set lp_num [db_get_col $res_seln $r lp_num]
		set lp_den [db_get_col $res_seln $r lp_den]
		set gp_num [db_get_col $res_seln $r sp_num_guide]
		set gp_den [db_get_col $res_seln $r sp_den_guide]

		set PRC($r,LP) [mk_price $lp_num $lp_den]
		set PRC($r,GP) [mk_price $gp_num $gp_den]

		if { $lp_num != "" && $ew_fac_num != "" && $lp_den != "" && $ew_fac_den != "" } {
			# Need to ensure price is in its lowest terms, e.g. 4/2 --> 2/1
			set place_lp_num [expr $lp_num * $ew_fac_num]
			set place_lp_den [expr $lp_den * $ew_fac_den]

			foreach {place_lp_num place_lp_den} [ob_price::simplify_price $place_lp_num $place_lp_den] {}

			set PRC($r,LPL) [mk_price $place_lp_num $place_lp_den]

			ob_log::write ERROR { PRC($r,LPL) = $PRC($r,LPL) }
		} else {
			set PRC($r,LPL) ""
		}

		# if we're reloading this page after an error, we don't really
		# want to lose all the prices that have been entered so far.
		# let's read them in and bind them, if there are any

		set ev_oc_id         [db_get_col $res_seln $r ev_oc_id]
		set PRC($r,LP_PRICE) [string trim [reqGetArg lp_$ev_oc_id]]
		set PRC($r,GP_PRICE) [string trim [reqGetArg spg_$ev_oc_id]]
	}
	set class_id [db_get_col $res_seln 0 ev_class_id]

	tpBindVar OcLP      PRC LP       seln_idx
	tpBindVar OcLPPrice PRC LP_PRICE seln_idx
	tpBindVar OcGP      PRC GP       seln_idx
	tpBindVar OcGPPrice PRC GP_PRICE seln_idx
	tpBindVar OcLPL     PRC LPL      seln_idx
	tpSetVar ClassId $class_id
	tpBindVar ChannelCd    CHANNELS channel_cd seln_idx chnnl_idx
	tpBindVar ChannelUse   CHANNELS use        seln_idx chnnl_idx
	tpBindVar ChannelName  CHANNELS chnnl_name seln_idx chnnl_idx

	tpBindTcl OcId         sb_res_data $res_seln seln_idx ev_oc_id
	tpBindTcl OcDesc       sb_res_data $res_seln seln_idx desc
	tpBindTcl OcStatus     sb_res_data $res_seln seln_idx status
	tpBindTcl OcLPNum      sb_res_data $res_seln seln_idx lp_num
	tpBindTcl OcLPDen      sb_res_data $res_seln seln_idx lp_den
	tpBindTcl OcResult     sb_res_data $res_seln seln_idx result
	tpBindTcl OcResultConf sb_res_data $res_seln seln_idx result_conf
	tpBindTcl OcSettled    sb_res_data $res_seln seln_idx settled
	tpBindTcl OcDisporder  sb_res_data $res_seln seln_idx disporder
	tpBindTcl OcDisplayed  sb_res_data $res_seln seln_idx displayed
	tpBindTcl OcRunnerNum  sb_res_data $res_seln seln_idx runner_num
	tpBindTcl OcFlag       sb_res_data $res_seln seln_idx fb_result
	tpBindTcl OcMultKey    sb_res_data $res_seln seln_idx mult_key
	tpBindTcl OcMinBet     sb_res_data $res_seln seln_idx min_bet
	tpBindTcl OcMaxBet     sb_res_data $res_seln seln_idx max_bet
	tpBindTcl OcSpMaxBet   sb_res_data $res_seln seln_idx sp_max_bet
	tpBindTcl OcEpMaxBet   sb_res_data $res_seln seln_idx ep_max_bet
	tpBindTcl OcStkOrLbt   sb_res_data $res_seln seln_idx stk_or_lbt
	tpBindTcl OcCurTotal   sb_res_data $res_seln seln_idx cur_total
	tpBindTcl OcMaxTotal   sb_res_data $res_seln seln_idx max_total
	tpBindTcl OcFeedUpd    sb_res_data $res_seln seln_idx feed_updateable
	tpBindTcl OcMaxPotWin  sb_res_data $res_seln seln_idx max_pot_win
	tpBindTcl OcEWFactor   sb_res_data $res_seln seln_idx ew_factor
	tpBindTcl OcHasVariant sb_res_data $res_seln seln_idx has_oc_variants
	tpBindTcl OcMaxMultipleBet sb_res_data $res_seln seln_idx max_multiple_bet
	tpBindTcl OcLinkKey    sb_res_data $res_seln seln_idx link_key

	asPlayFile market_selns.html

	db_close $res_seln

	catch {unset PRC}
}


#
# ----------------------------------------------------------------------------
# Do bulk selection update
# ----------------------------------------------------------------------------
#
proc do_ocs_upd args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		ADMIN::MARKET::go_mkt
		return
	}

	if {![op_allowed ManageEvOc]} {
		err_bind "You don't have permission to update selections"
		go_ocs_upd
		return
	}

	set ev_id     [reqGetArg EvId]
	set ev_mkt_id [reqGetArg MktId]
	set mkt_sort  [reqGetArg MktSort]
	set mkt_type  [reqGetArg MktType]
	set bir_index [reqGetArg MktBirIndex]

	assert {$ev_id     != ""}
	assert {$ev_mkt_id != ""}
	assert {$mkt_sort  != ""}
	assert {$mkt_type  != ""}

	#
	# Retrieve current state of selections
	#
	set sql [subst {
		select
			o.ev_oc_id,
			o.ev_id,
			o.ev_mkt_id,
			o.cr_date,
			o.status,
			o.desc,
			o.result,
			o.place,
			o.min_bet,
			o.max_bet,
			o.sp_max_bet,
			o.ep_max_bet,
			o.disporder,
			o.displayed,
			o.lp_num,
			o.lp_den,
			o.sp_num,
			o.sp_den,
			NVL(o.sp_num_guide,'') sp_num_guide,
			NVL(o.sp_den_guide,'') sp_den_guide,
			o.settled,
			o.mult_key,
			o.runner_num,
			o.channels,
			o.max_pot_win,
			o.max_multiple_bet,
			o.ew_factor,
			z.max_total
		from
			tEvOc    o,
			tEvOcConstr z
		where
			z.ev_oc_id  = o.ev_oc_id and
			o.ev_mkt_id = $ev_mkt_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res_s [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res_s]

	set SELN(rows)  $rows
	set SELN(oc_id) [list]

	for {set r 0} {$r < $rows} {incr r} {

		set v_ev_id [db_get_col $res_s $r ev_id]

		if {$ev_id != $v_ev_id} {
			error "ev_id mismatch ($ev_id vs $v_ev_id) : bailing out"
		}

		set v_oc_id [db_get_col $res_s $r ev_oc_id]

		lappend SELN(oc_id) $v_oc_id

		set SELN($v_oc_id,status)     [db_get_col $res_s $r status]
		set SELN($v_oc_id,desc)       [db_get_col $res_s $r desc]
		set SELN($v_oc_id,min_bet)    [db_get_col $res_s $r min_bet]
		set SELN($v_oc_id,max_bet)    [db_get_col $res_s $r max_bet]
		set SELN($v_oc_id,sp_max_bet) [db_get_col $res_s $r sp_max_bet]
		set SELN($v_oc_id,ep_max_bet) [db_get_col $res_s $r ep_max_bet]
		set SELN($v_oc_id,disporder)  [db_get_col $res_s $r disporder]
		set SELN($v_oc_id,displayed)  [db_get_col $res_s $r displayed]
		set SELN($v_oc_id,runner_num) [db_get_col $res_s $r runner_num]
		set SELN($v_oc_id,lp_num)     [db_get_col $res_s $r lp_num]
		set SELN($v_oc_id,lp_den)     [db_get_col $res_s $r lp_den]
		set SELN($v_oc_id,spg_num)    [db_get_col $res_s $r sp_num_guide]
		set SELN($v_oc_id,spg_den)    [db_get_col $res_s $r sp_den_guide]
		set SELN($v_oc_id,mult_key)   [db_get_col $res_s $r mult_key]
		set SELN($v_oc_id,max_total)  [db_get_col $res_s $r max_total]
		set SELN($v_oc_id,channels)   [db_get_col $res_s $r channels]
		set SELN($v_oc_id,max_pot_win) [db_get_col $res_s $r max_pot_win]
		set SELN($v_oc_id,ew_factor)  [db_get_col $res_s $r ew_factor]
		set SELN($v_oc_id,max_multiple_bet)  [db_get_col $res_s $r max_multiple_bet]
	}

	db_close $res_s

	# Get list of oc ids from posted form

	set F_oc_ids [split [reqGetArg EvOcIdList] ,]

	# Get LP/SP available flags from form

	set F_LP [reqGetArg MktLPAvail]
	set F_SP [reqGetArg MktSPAvail]

	# Check each posted oc_id tallies with those retrieved, and if so,
	# see whether oc_id data has changed

	set update_sql {
		execute procedure pUpdEvOcSimple(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_status = ?,
			p_disporder = ?,
			p_displayed = ?,
			p_lp_num = ?,
			p_lp_den = ?,
			p_sp_num_guide = ?,
			p_sp_den_guide = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_sp_max_bet = ?,
			p_ep_max_bet = ?,
			p_mult_key = ?,
			p_max_total = ?,
			p_channels = ?
		)
	}

	set update_hcap_mkt_sql {
		execute procedure pUpdEvMktHcap (
			p_adminuser  = ?,
			p_ev_mkt_id  = ?,
			p_hcap_value = ?,
			p_hcap_step  = ?
		)
	}

	set update_mkt_bir_index {
		execute procedure pUpdMktBirIndex (
			p_adminuser = ?,
			p_ev_mkt_id  = ?,
			p_bir_index = ?
		)
	}


	set mkt_info_sql {
		select
			ah_prc_lo,
			ah_prc_hi
		from
			tEvMktConstr
		where
			ev_mkt_id = ?
	}

	set s_upd [inf_prep_sql $DB $update_sql]

	inf_begin_tran $DB

	set ret [catch {

		if {[string first $mkt_type "AHULl"] >= 0} {

			set hcap_value [reqGetArg MktHcapValue]

			if {$mkt_type == "l"} {
				set hcap_value [parse_hcap_str $hcap_value]
			}

			#
			# Some chicanery to sort out handicap markets: when the market type
			# is "A" or "H", we need to set the sign of the handicap value to
			# be -ve if the handicap is given away by the home side
			#
			if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
				if {$mkt_type == "A" || $mkt_type == "H"} {
					if {[reqGetArg MktHcapSide] == "A"} {
						set hcap_value [expr {0-$hcap_value}]
					}
				}
			}

			set stmt [inf_prep_sql $DB $update_hcap_mkt_sql]
			set res  [inf_exec_stmt $stmt\
				$USERNAME\
				$ev_mkt_id\
				$hcap_value]
			catch {db_close $res}
			inf_close_stmt $stmt

			#
			# Load the market constraints for price bounds - we
			# need to validate prices against these limits when they
			# change
			#
			set stmt [inf_prep_sql $DB $mkt_info_sql]
			set res [inf_exec_stmt $stmt $ev_mkt_id]
			inf_close_stmt $stmt

			if {[db_get_nrows $res] == 1} {
				set ah_prc_lo [db_get_col $res 0 ah_prc_lo]
				set ah_prc_hi [db_get_col $res 0 ah_prc_hi]
			} else {
				set ah_prc_lo ""
				set ah_prc_hi ""
			}

			db_close $res
		}

		if {$mkt_type == "N"} {
			#update the Betting in running index
			set stmt [inf_prep_sql $DB $update_mkt_bir_index]
			set res  [inf_exec_stmt $stmt\
						  $USERNAME\
						  $ev_mkt_id\
						  $bir_index]
			catch {db_close $res}
			inf_close_stmt $stmt
		}

		foreach oc_id $F_oc_ids {

			if {![info exists SELN($oc_id,status)]} {
				error "oc_id mismatch : $oc_id"
			}

			set changed       0
			set price_changed 0

			set F_status   [string trim [reqGetArg status_$oc_id]]
			set F_disp     [string trim [reqGetArg dispo_$oc_id]]
			set F_dispYN   [string trim [reqGetArg displayed_$oc_id]]
			set F_lp       [string trim [reqGetArg lp_$oc_id]]
			set F_spg      [string trim [reqGetArg spg_$oc_id]]
			set F_min      [string trim [reqGetArg min_$oc_id]]
			set F_max      [string trim [reqGetArg max_$oc_id]]
			set F_sp_max   [string trim [reqGetArg sp_max_$oc_id]]
			set F_ep_max   [string trim [reqGetArg ep_max_$oc_id]]
			set F_multkey  [string trim [reqGetArg mult_key_$oc_id]]
			set F_maxtotal [string trim [reqGetArg max_total_$oc_id]]
			set F_channels [make_channel_str "CN_" $oc_id]
			set F_link_key [string trim [reqGetArg link_key_$oc_id]]

			if {[string compare $F_status $SELN($oc_id,status)]} {
				set changed 1
			}
			if {[string compare $F_disp $SELN($oc_id,disporder)]} {
				set changed 1
			}
			if {[string compare $F_dispYN $SELN($oc_id,displayed)]} {
				set changed 1
			}
			if {$F_LP == "Y"} {
				set F_lp_nd [get_price_parts $F_lp]

				set F_lp_num [lindex $F_lp_nd 0]
				set F_lp_den [lindex $F_lp_nd 1]

				if {$F_lp_num != $SELN($oc_id,lp_num) ||
					$F_lp_den != $SELN($oc_id,lp_den)} {

					if {$mkt_sort == "AH" || $mkt_sort == "WH"} {
						if {$ah_prc_lo != "" && $ah_prc_hi != ""} {

							set p_dec [expr {1.0+$F_lp_num/double($F_lp_den)}]

							if {$p_dec < $ah_prc_lo || $p_dec > $ah_prc_hi} {
								error "Price for selection is outside bounds"
							}
						}
					}

					set changed       1
					set price_changed 1

					set old_lp_num $SELN($oc_id,lp_num)
					set old_lp_den $SELN($oc_id,lp_den)
				}
			} else {
				set F_lp_num ""
				set F_lp_den ""
			}
			if {$F_SP == "Y"} {

				if {[string trim $F_spg] == ""} {
					set F_spg_num ""
					set F_spg_den ""
				} else {
					set F_spg_nd  [get_price_parts $F_spg]
					set F_spg_num [lindex $F_spg_nd 0]
					set F_spg_den [lindex $F_spg_nd 1]
				}

				if {$F_spg_num != $SELN($oc_id,spg_num) ||
					$F_spg_den != $SELN($oc_id,spg_den)} {
					set changed 1
				}
			} else {
				set F_spg_num ""
				set F_spg_den ""
			}
			if [string compare $F_min $SELN($oc_id,min_bet)] {
				set changed 1
			}
			if {[string length $F_min] == 0} {
				set F_min ""
			}
			if [string compare $F_max $SELN($oc_id,max_bet)] {
				set changed 1
			}
			if {[string length $F_max] == 0} {
				set F_max ""
			}
			if [string compare $F_sp_max $SELN($oc_id,sp_max_bet)] {
				set changed 1
			}
			if {[string length $F_sp_max] == 0} {
				set F_sp_max ""
			}
			if [string compare $F_ep_max $SELN($oc_id,ep_max_bet)] {
				set changed 1
			}
			if {[string length $F_ep_max] == 0} {
				set F_sp_max ""
			}
			if [string compare $F_maxtotal $SELN($oc_id,max_total)] {
				set changed 1
			}
			if {[string length $F_maxtotal] == 0} {
				set F_maxtotal ""
			}
			if [string compare $F_multkey $SELN($oc_id,mult_key)] {
				set changed 1
			}
			if {[string length $F_multkey] == 0} {
				set F_multkey ""
			}
			if [string compare $F_channels $SELN($oc_id,channels)] {
				set changed 1
			}

			if {$changed} {

				inf_exec_stmt $s_upd\
					$USERNAME\
					$oc_id\
					$F_status\
					$F_disp\
					$F_dispYN\
					$F_lp_num\
					$F_lp_den\
					$F_spg_num\
					$F_spg_den\
					$F_min\
					$F_max\
					$F_sp_max\
					$F_ep_max\
					$F_multkey\
					$F_maxtotal\
					$F_channels
			}
		}
	} msg]

	inf_close_stmt $s_upd

	if {$ret} {
		err_bind $msg
		inf_rollback_tran $DB
		go_ocs_upd
		return
	} else {
		inf_commit_tran $DB

		# if the selection just updated is in a WDW market then
		# update double chance odds
		if {$mkt_sort == "MR"} {
			ADMIN::AUTOGEN::update_mkt_odds_DC $ev_id
		}
	}

	ADMIN::MARKET::go_mkt
}

proc go_ocs_res_CW args {

	global DB OC BIR

	set mkt_id [reqGetArg MktId]


	#outcomes
	set sql [subst {
		select
		  o.ev_oc_id,
		  o.desc,
		  o.status
		from
		  tEvOc o
		where
		  o.ev_mkt_id = $mkt_id
	}]

	set stmt	 [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumMktSelns [set nrows [db_get_nrows $res_seln]]

	for {set r 0} {$r < $nrows} {incr r} {
		set OC($r,ev_oc_id)	   [db_get_col $res_seln $r ev_oc_id]
		set OC($r,desc)	 [db_get_col $res_seln $r desc]
	}

	db_close $res_seln

	set sql [subst {
		select
		  m.mkt_bir_idx,
		  m.bir_index,
		  m.default_res,
		  m.result_conf,
		  m.settled,
		  r.ev_oc_id,
		  r.result,
		  o.desc
		from
		  tMktBirIdx m,
		  outer (tMktBirIdxRes r, tEvOc o)
		where
		  m.mkt_bir_idx = r.mkt_bir_idx
		and
		  r.ev_oc_id = o.ev_oc_id
		and
		  m.ev_mkt_id = $mkt_id
		order by 1;
	}]

	set stmt	 [inf_prep_sql $DB $sql]
	set res_mkt [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res_mkt]

	set prev_bir_idx -1
	set i 0
	set j 0
	set num_unconfirmed 0

	for {set r 0} {$r < $nrows} {incr r} {
		set curr_bir_idx [db_get_col $res_mkt $r bir_index]
		set curr_oc      [db_get_col $res_mkt $r ev_oc_id]

		if {$curr_bir_idx != $prev_bir_idx} {
			set BIR($i,bir_idx) $curr_bir_idx
			set BIR($i,mkt_bir_idx) [db_get_col $res_mkt $r mkt_bir_idx]
			set BIR($i,bir_default) [db_get_col $res_mkt $r default_res]

			set BIR($i,result_conf) [db_get_col $res_mkt $r result_conf]
			if {$BIR($i,result_conf) == "N"} {
				incr num_unconfirmed
			}
			set BIR($i,settled)     [db_get_col $res_mkt $r settled]


			if {$i != 0} {
				set BIR([expr {$i-1}],num_res) $j
			}
			incr i
			set j 0
			set prev_bir_idx $curr_bir_idx

		}

		if {$curr_oc != ""} {
			set BIR([expr {$i-1}],$j,ev_oc_id) [db_get_col $res_mkt $r ev_oc_id]
			set BIR([expr {$i-1}],$j,desc) [db_get_col $res_mkt $r desc]
			set BIR([expr {$i-1}],$j,result) [db_get_col $res_mkt $r result]
			incr j
		}
	}

	db_close $res_mkt
	set num_birs $i
	set BIR([expr {$i-1}],num_res) $j

	if {[OT_CfgGet BIR_INX_ONE_RES 0] == 1} {

		for {set i 0} {$i < $num_birs} {incr i} {
			if {$BIR($i,num_res) > 0} {
				set BIR($i,show_add) 0
			} else {
				set BIR($i,show_add) 1
			}
		}
	} else {

		for {set i 0} {$i < $num_birs} {incr i} {
			set BIR($i,show_add) 1
		}

	}

	tpBindVar OcId       OC  ev_oc_id    oc_ix
	tpBindVar OcDesc     OC  desc        oc_ix

	tpSetVar  NumBirs    $num_birs
	tpSetVar  NumUnconfirmed $num_unconfirmed

	tpBindVar BirIdx     BIR bir_idx     bir_ix
	tpBindVar BirDefault BIR bir_default bir_ix
	tpBindVar MktBirIdx  BIR mkt_bir_idx bir_ix
	tpBindVar ResultConf BIR result_conf bir_ix
	tpBindVar Settled    BIR settled     bir_ix
	tpBindVar EvOcId     BIR ev_oc_id    bir_ix  res_ix
	tpBindVar EvOcDesc   BIR desc        bir_ix  res_ix
	tpBindVar Result     BIR result      bir_ix  res_ix


	asPlayFile market_results_CW.html

	catch {unset OC}
	catch {unset BIR}
}


#
# ----------------------------------------------------------------------------
# Go to bulk selection results setting
# ----------------------------------------------------------------------------
#
proc go_ocs_res args {

	global DB OC TERMS USERID

	set mkt_id [reqGetArg MktId]

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			m.type,
			m.sort,
			m.status,
			e.start_time,
			e.result_conf,
			e.desc,
			e.ev_id,
			m.lp_avail,
			m.sp_avail,
			m.pm_avail,
			m.ew_avail,
			m.ew_places,
			m.ew_fac_num,
			m.ew_fac_den,
			m.result_conf mkt_res_conf,
			m.settled,
			m.dbl_res,
			g.name mkt_name,
			m.auto_dh_redn
		from
			tEvMkt       m,
			tEv          e,
			tEvOcGrp     g,
			tEvType      t,
			tEvClass     c
		where
			m.ev_mkt_id    = $mkt_id        and
			m.ev_id        = e.ev_id        and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id;
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set csort        [db_get_col $res 0 csort]
	set mkt_type     [db_get_col $res 0 type]
	set mkt_sort     [db_get_col $res 0 sort]
	set status       [db_get_col $res 0 status]
	set start        [db_get_col $res 0 start_time]
	set result_conf  [db_get_col $res 0 result_conf]
	set lp_avail     [db_get_col $res 0 lp_avail]
	set sp_avail     [db_get_col $res 0 sp_avail]
	set pm_avail     [db_get_col $res 0 pm_avail]
	set ew_avail     [db_get_col $res 0 ew_avail]
	set mkt_res_conf [db_get_col $res 0 mkt_res_conf]
	set settled      [db_get_col $res 0 settled]
	set auto_dh_redn [db_get_col $res 0 auto_dh_redn]

	set auto_dh_redn [expr {[OT_CfgGet FUNC_AUTO_DH 0] ? $auto_dh_redn : "N"}]

	# if double resulting functionality not active, ignore db value
	if {[OT_CfgGet FUNC_DBL_RES 0]} {
		set dbl_res [db_get_col $res 0 dbl_res]
	} else {
		set dbl_res "N"
	}

	tpBindString EvDesc      [db_get_col $res 0 desc]
	tpBindString EvStartTime $start
	tpBindString MktName     [db_get_col $res 0 mkt_name]
	tpBindString EvId        [db_get_col $res 0 ev_id]
	tpBindString MktId       $mkt_id
	tpBindString MktType     $mkt_type
	tpBindString MktSort     $mkt_sort
	tpBindString MktLPAvail  $lp_avail
	tpBindString MktSPAvail  $sp_avail
	tpBindString MktPMAvail  $pm_avail
	tpBindString MktEWAvail  $ew_avail
	tpBindString MktDblRes   $dbl_res

	tpSetVar ClassSort  $csort
	tpSetVar MktType    $mkt_type
	tpSetVar MktSort    $mkt_sort
	tpSetVar MktLPAvail [expr {$lp_avail == "Y"}]
	tpSetVar MktSPAvail [expr {$sp_avail == "Y"}]
	tpSetVar MktPMAvail [expr {$pm_avail == "Y"}]
	tpSetVar MktEWAvail [expr {$ew_avail == "Y"}]
	tpSetVar MktDblRes  [expr {$dbl_res  == "Y"}]
	tpSetVar MktAutoDH  [expr {$auto_dh_redn == "Y"}]

	#needed on displaying CW results
	tpSetVar MktSettled $settled
	tpSetVar MktResConf $mkt_res_conf

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	tpSetVar AfterEventStart [expr {[string compare $start $now] <= 0 ? 1 : 0}]

	db_close $res


	#
	# Optional configuration items to simplify result setting
	#
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort places] == "never"} {
		tpSetVar MktCanPlace 0
	} else {
		tpSetVar MktCanPlace 1
	}
	if {[ADMIN::MKTPROPS::mkt_flag $csort $mkt_sort dead-heat] == "never"} {
		set do_deadheats 0
		tpSetVar     MktCanDeadHeat 0
		tpBindString MktCanDeadHeat 0
	} else {
		set do_deadheats 1
		tpSetVar     MktCanDeadHeat 1
		tpBindString MktCanDeadHeat 1
	}

	if {$mkt_sort == "CW"} {
		go_ocs_res_CW
		return
	}

	array set TERMS [ADMIN::MARKET::get_ew_terms $mkt_id]

	# retrieve dead heat reductions
	if {$do_deadheats} {

		# check that the loading of dead heat
		# reductions was successful
		set do_auto_dh [expr {$auto_dh_redn == "Y"}]
		if {![ob_dh_redn::load "M" $mkt_id $do_auto_dh 1 0]} {
			err_bind [ob_dh_redn::get_err]
			ADMIN::MARKET::go_mkt
			return
		}
	}

	# if market is a double resulting market, need to get double resulting
	# entries
	if {$dbl_res == "Y"} {

		set DBL_RES(ev_oc_ids) [list]

		#
		# Get double resulting entries
		#
		set sql [subst {
			select
				o.ev_oc_id,
				r.user_id,
				r.result,
				r.place,
				r.sp_num,
				r.sp_den,
				r.hcap_score,
				r.tw_div,
				r.tp_div,
				a.username
			from
				tEvOc       o,
				tEvOcDblRes r,
				tAdminUser  a
			where
				o.ev_mkt_id = $mkt_id      and
				o.ev_oc_id  = r.ev_oc_id   and
				r.user_id   = a.user_id
			order by
				o.ev_oc_id
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res_dbl  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res_dbl]

		for {set r 0} {$r < $nrows} {incr r} {

			set ev_oc_id [db_get_col $res_dbl $r ev_oc_id]
			set user_id  [db_get_col $res_dbl $r user_id]

			# new ev_oc_id
			if {[lsearch $DBL_RES(ev_oc_ids) $ev_oc_id] == -1} {
				lappend DBL_RES(ev_oc_ids) $ev_oc_id
				set DBL_RES($ev_oc_id,user_ids) [list $user_id]

			# existing ev_oc_id
			} else {
				lappend DBL_RES($ev_oc_id,user_ids) $user_id
			}

			foreach c [list result place sp_num sp_den hcap_score tw_div \
			           tp_div username] {
				set DBL_RES($ev_oc_id,$user_id,$c) [db_get_col $res_dbl $r $c]
			}
		}

		db_close $res_dbl
	}

	#
	# Get selection information
	#
	set sql [subst {
		select
			o.ev_oc_id,
			o.desc,
			o.status,
			o.result,
			o.result_conf,
			o.place,
			o.settled,
			o.lp_num,
			o.lp_den,
			o.sp_num,
			o.sp_den,
			o.fb_result,
			o.hcap_score,
			tw.dividend tw_div,
			tp.dividend tp_div
		from
			tEvOc o,
			outer tDividend tw,
			outer tDividend tp
		where
			o.ev_mkt_id = $mkt_id and
			o.ev_mkt_id = tw.ev_mkt_id and
			o.ev_mkt_id = tp.ev_mkt_id and
			tw.type = 'TW' and
			tp.type = 'TP' and
			tw.seln_1 = o.ev_oc_id and
			tp.seln_1 = o.ev_oc_id
		order by
			displayed desc, disporder asc
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_seln [inf_exec_stmt $stmt]
	inf_close_stmt $stmt


	set mkt_results [get_market_results $csort $mkt_sort]

	tpSetVar NumMktSelns [set nrows [db_get_nrows $res_seln]]

	for {set r 0} {$r < $nrows} {incr r} {

		set lp_num   [db_get_col $res_seln $r lp_num]
		set lp_den   [db_get_col $res_seln $r lp_den]
		set sp_num   [db_get_col $res_seln $r sp_num]
		set sp_den   [db_get_col $res_seln $r sp_den]
		set flag     [db_get_col $res_seln $r fb_result]
		set ev_oc_id [db_get_col $res_seln $r ev_oc_id]

		# store core information about selection
		set OC($r,lp) [mk_price $lp_num $lp_den]
		set OC($r,ev_oc_id)      $ev_oc_id
		set OC($r,fb_result)     [db_get_col $res_seln $r fb_result]
		set OC($r,desc)          [db_get_col $res_seln $r desc]
		set OC($r,status)        [db_get_col $res_seln $r status]
		set OC($r,result_conf)   [db_get_col $res_seln $r result_conf]
		set OC($r,settled)       [db_get_col $res_seln $r settled]
		set OC($r,flag)          $flag

		# and then split out information about result (required for
		# double resulting
		set OC($r,0,result)      [db_get_col $res_seln $r result]
		set OC($r,0,place)       [db_get_col $res_seln $r place]
		set OC($r,0,hcap_score)  [db_get_col $res_seln $r hcap_score]
		set OC($r,0,tw_div)      [db_get_col $res_seln $r tw_div]
		set OC($r,0,tp_div)      [db_get_col $res_seln $r tp_div]
		set OC($r,0,sp)          [mk_price $sp_num $sp_den]
		set OC($r,0,dbl_type)    "Final"
		set OC($r,0,dbl_user)    "N/A"

		set seln_results [get_seln_results $csort $mkt_sort $flag]

		if {$seln_results == ""} {
			set seln_results $mkt_results
		}

		set OC($r,result_flags) $seln_results

		# if double resulting and we have some double results then bind up
		#details
		if {
			$dbl_res == "Y" &&
			[lsearch $DBL_RES(ev_oc_ids) $ev_oc_id] != -1
		} {

			set cols [list result place hcap_score tw_div tp_div]

			# do we have 2 sets, or one set entered by this user
			if {
			    [llength $DBL_RES($ev_oc_id,user_ids)] > 1 ||
			    [lindex $DBL_RES($ev_oc_id,user_ids) 0] == $USERID
			} {

				if {
					[llength $DBL_RES($ev_oc_id,user_ids)] == 1
				} {
					# if only one result and we are here then this user must have
					# entered them. Store in the fields used to display in the
					# input boxes
					set key "\$r,0"
					set OC($r,res_num) 1

					set user_id [lindex $DBL_RES($ev_oc_id,user_ids) 0]
					foreach col $cols {
						set OC($r,0,$col) $DBL_RES($ev_oc_id,$user_id,$col)
					}

					set OC($r,0,sp) \
						[mk_price $DBL_RES($ev_oc_id,$user_id,sp_num)  $DBL_RES($ev_oc_id,$user_id,sp_den)]
					set OC($r,0,dbl_user) $DBL_RES($ev_oc_id,$user_id,username)
					set OC($r,0,dbl_type) "1st"

				} else {
					# otherwise, store specific to the user
					set key "\$r,\$user_idx"
					set OC($r,res_num) \
						[expr {[llength $DBL_RES($ev_oc_id,user_ids)] + 1}]

					set user_idx 1

					foreach user_id $DBL_RES($ev_oc_id,user_ids) {
						foreach col $cols {
							set OC([subst $key],$col) \
								$DBL_RES($ev_oc_id,$user_id,$col)
						}

						set OC([subst $key],sp) \
							[mk_price $DBL_RES($ev_oc_id,$user_id,sp_num)  $DBL_RES($ev_oc_id,$user_id,sp_den)]

						if {$user_idx == 1} {
							set OC([subst $key],dbl_type) "1st"
						} else {
							set OC([subst $key],dbl_type) "2nd"
						}
						set OC([subst $key],dbl_user) \
							$DBL_RES($ev_oc_id,$user_id,username)

						incr user_idx
					}
				}

			# we have one set by a different user - these results
			# must be masked
			} else {

				set user_id [lindex $DBL_RES($ev_oc_id,user_ids) 0]

				set OC($r,res_num)    2
				set OC($r,1,dbl_user) $DBL_RES($ev_oc_id,$user_id,username)
				set OC($r,0,dbl_type) "2nd"
				set OC($r,0,dbl_user) "-"
				set OC($r,1,dbl_type) "1st"
				set OC($r,1,dbl_mask) 1
				tpBindString DblMaskStr "***"
			}

		# no existing double resulting entries to show
		} else {
			set OC($r,res_num)    1

			# if double resulting active, and haven't already set results in
			# main table - this is the first set of results
			if {$dbl_res == "Y" && $OC($r,0,result) == "-"} {
				set OC($r,0,dbl_type) "1st"
				set OC($r,0,dbl_user) "-"
			}
		}

		if {$do_deadheats} {

			set mask 0

			if {$dbl_res == "Y" &&
			    [lsearch $DBL_RES(ev_oc_ids) $ev_oc_id] != -1
			} {

				if {[llength $DBL_RES($ev_oc_id,user_ids)] > 1} {
					set user_ids [concat [list 0] $DBL_RES($ev_oc_id,user_ids)]
				} elseif { [lindex $DBL_RES($ev_oc_id,user_ids) 0] == $USERID} {
					set user_ids [list $USERID]
				} else {
					set user_ids [concat [list 0] $DBL_RES($ev_oc_id,user_ids)]
					set mask 1
				}
			} else {
				set user_ids [list 0]
			}

			# loop through possible reduction types
			foreach dh_type {W P} {

				if {$dh_type == "W"} {
					set ew_ids 0
				} else {
					set ew_ids $TERMS(ew_ids)
				}

				# loop through each way terms including 0
				# placeholder for no each way terms
				set ew_idx   0

				foreach ew_id $ew_ids {

					set user_idx 0

					foreach user_id $user_ids {

							# retrieve dead heat reduction
							set dh [ob_dh_redn::get "$dh_type,$ev_oc_id,$user_id,$ew_id"]

							set dh_num    [lindex $dh 0]
							set dh_den    [lindex $dh 1]
							set dh_mod    [lindex $dh 2]

							# Don't display if fractions 1/1 or we are masking
							if {$dh_num == $dh_den || ($user_idx > 0 && $mask)} {
								set dh_num ""
								set dh_den ""
								set dh_mod 0
							}

							if {$dh_type == "W"} {
								set s_key "$r,$user_idx"
							} else {
								set s_key "$r,$user_idx,$ew_idx"
							}

							set OC($s_key,${dh_type}_dh_num) $dh_num
							set OC($s_key,${dh_type}_dh_den) $dh_den
							set OC($s_key,${dh_type}_dh_mod) $dh_mod

							if {$dh_type == "P"} {
								set OC($s_key,${dh_type}_ew_id)  $ew_id
							}
						#
						incr user_idx
					}
					incr ew_idx
				}
			}
		}

	}


	db_close $res_seln

	# bind array variables
	foreach key [array names OC] {
		set name [lindex [split $key ","] end]
		if {[regexp {^\w*,\w*$} $key]} {
			tpBindVar $name OC $name s_idx
		} elseif {[regexp {^\w*,\w*,\w*$} $key]} {
			tpBindVar $name OC $name s_idx u_idx
		} elseif {[regexp {^\w*,\w*,\w*,\w*$} $key]} {
			tpBindVar ${name} OC $name s_idx u_idx e_idx
		}
	}

	# bind up each way terms
	ADMIN::MARKET::bind_ew_terms [array get TERMS]

	tpBindString DeadHeatReductionsDisabled \
		[expr {[ob_control::get allow_dd_creation] == "N" ? "disabled" : ""}]

	asPlayFile market_results.html

	catch {unset OC TERMS DBL_RES}

}


#
# ----------------------------------------------------------------------------
# Do bulk selection results setting
# ----------------------------------------------------------------------------
#
proc do_ocs_res args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		ADMIN::MARKET::go_mkt
		return
	}


	# Support ticket#42265: Read from tControl to determine if this system is allowed
	# to alter tdeadheatredn.  Should be only be allowed from offshore environment.
	set sql [subst {select 1 from tcontrol where allow_dd_creation = 'Y'}]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set alter_dd_allowed [db_get_nrows $rs]
	db_close $rs

	set ev_id     [reqGetArg EvId]
	set ev_mkt_id [reqGetArg MktId]

	set oc_ids [split [reqGetArg EvOcIdList] ,]

	# only do automatic dead heat reductions if the market can do
	# automatic dead heats and the functionality is enabled
	set do_auto_dh [expr {[reqGetArg MktAutoDH] == "Y" ? [OT_CfgGet FUNC_AUTO_DH 0] : 0}]

	# if fs_home and fs_away are set then we want to set full-time
	# scores first so we can actually result the OU mkt
	set ou_check [list]

	set fs_home [reqGetArg fs_home]
	set fs_away [reqGetArg fs_away]

	if {$fs_home != ""} {
		lappend ou_check $fs_home
	}
	if {$fs_away != ""} {
		lappend ou_check $fs_away
	}

	if {[reqGetArg SubmitName] == "Back"} {
		ADMIN::MARKET::go_mkt
		return
	}

	# clear all dead heat reduction
	# this equals doing only automatically calculated reductions
	if {[reqGetArg SubmitName] == "CalcDH"} {
		if {![ob_dh_redn::clear $ev_mkt_id]} {
			err_bind [ob_dh_redn::get_err]
		}
		go_ocs_res
		return
	}

	set sql [subst {
		execute procedure pSetEvOcResult(
			p_adminuser     = ?,
			p_ev_oc_id      = ?,
			p_result        = ?,
			p_place         = ?,
			p_sp_num        = ?,
			p_sp_den        = ?,
			p_tw_div        = ?,
			p_tp_div        = ?,
			p_hcap_score    = ?,
			p_func_dbl_res  = ?,
			p_force_dbl_res = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	set func_dbl_res [expr {[OT_CfgGet FUNC_DBL_RES 0]?"Y":"N"}]
	set ret [catch {

		set r [list]

		foreach oc_id $oc_ids {

			set sp           [reqGetArg oc_sp_$oc_id]
			set res          [reqGetArg oc_res_$oc_id]
			set place        [reqGetArg oc_place_$oc_id]
			set wr           [reqGetArg oc_wr_$oc_id]
			set pr           [reqGetArg oc_pr_$oc_id]
			set twd          [reqGetArg oc_tw_div_$oc_id]
			set tpd          [reqGetArg oc_tp_div_$oc_id]
			set score        [reqGetArg oc_score_$oc_id]
			set dh_red       [reqGetArg dh_red_$oc_id]
			set force        [reqGetArg dbl_res_force_$oc_id]
			set num_terms    [reqGetArg num_terms]
			set ew_term_ids  [split [reqGetArg ew_term_ids] ","]
			set can_deadheat [reqGetArg can_deadheat]

			# first do the dead heat reductions
			if {$can_deadheat == 1 && $alter_dd_allowed} {

				catch {unset INPUT_DH}
				set INPUT_DH(W,$oc_id,0) [reqGetArg dh_wr_$oc_id]

				if {$num_terms > 0} {

					foreach ew_term_id $ew_term_ids {

						set dh_key  "$oc_id,$ew_term_id"
						set dh_pr   [reqGetArg dh_pr_${oc_id}_${ew_term_id}]

						set INPUT_DH(P,$dh_key) $dh_pr
					}
				}

				# retrieve reductions and throw an error if unsuccessful
				if {![ob_dh_redn::load "M" $ev_mkt_id $do_auto_dh 1 0]} {
					error [ob_dh_redn::get_err]
				}

				# loop through all input reductions to check
				# whether we need to update/insert reductions
				foreach dh_key [array names INPUT_DH] {

					# split the reduction into num/den
					set dh [get_reduction_parts [lindex $INPUT_DH($dh_key) 0]]

					if {![ob_dh_redn::update $dh_key $dh $func_dbl_res [expr {$force == 1?"Y":"N"}] $res "N"]} {
						# error updating the dead heat reductions
						error [ob_dh_redn::get_err]
					}
				}
			}


			# and now the core resulting update
			set spl   [get_price_parts     $sp]
			set wrl   [get_reduction_parts $wr]
			set prl   [get_reduction_parts $pr]

			# Over/Under markets: set score to be the market makeup
			if {[llength $ou_check] > 0} {
				set score [expr [lindex $ou_check 0] + [lindex $ou_check 1]]
			}

			set rs [inf_exec_stmt $stmt\
				$USERNAME\
				$oc_id\
				$res\
				$place\
				[lindex $spl 0]\
				[lindex $spl 1]\
				$twd\
				$tpd\
				$score\
				$func_dbl_res\
				[expr {$force == 1?"Y":"N"}]]

			# store result of update
			lappend r [db_get_coln $rs 0]
			db_close $rs
		}

	} msg]
	inf_close_stmt $stmt


	if {$ret} {
		err_bind $msg
		inf_rollback_tran $DB
		go_ocs_res
		return
	} else {
		inf_commit_tran $DB

		# if we had some errors in the double resulting, take back to results
		# page
		if {[lsearch $r -1] != -1} {
			err_bind \
				"Mismatches were found during double resulting. Please review"
			go_ocs_res
			return
		# were some double resulting entries only partially complete
		} elseif {[lsearch $r 0] != -1} {
			if {[lsearch $r 1] != -1} {
				msg_bind "Results partially set (double resulting not complete on all selections)"
			} else {
				msg_bind "First stage of double resulting complete"
			}
		} else {
			msg_bind "Successfully updated results"
		}

	}
	ADMIN::MARKET::go_mkt
}

#
#------------------------------------------------------------------------------
# For a selection, has a bet been placed for it with a show price?
#------------------------------------------------------------------------------
#
proc do_show_price_check {oc_id} {

	global DB

	set sql [subst {
		select
				ob.ev_oc_id,
				ob.price_type,
				p.status
		from
				tOBet ob,
				tEvOc o,
				outer tEvOcPrice p
		where
				ob.ev_oc_id = o.ev_oc_id
		and     o.ev_oc_id = p.ev_oc_id
		and     ob.price_type in ('1','2')
		and     ob.ev_oc_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $oc_id]
	inf_close_stmt $stmt

	set show_prc_set [list]
	set nrows [db_get_nrows $res]

	set fs_set 0
	set ss_set 0
	set fs_found 0
	set ss_found 0

	for {set i 0} {$i < $nrows} {incr i} {
		set price_type [db_get_col $res $i price_type]
		set status     [db_get_col $res $i status]
		if { $price_type == "1" } {
			set fs_found 1
		} elseif { $price_type == "2" } {
			set ss_found 1
		}
		if {$status == "1"} {
			set fs_set 1
		} elseif {$status == "2"} {
			set ss_set 1
		}
		if { $fs_set == 1 && $ss_set == 1 } {
			break
		}
	}
	if { $fs_set == 1 } {
		lappend show_prc_set Y
	} elseif { $fs_found == 1 || $ss_found==1 } {
		lappend show_prc_set N
	} else {
		lappend show_prc_set "-"
	}

	if { $ss_set == 1 } {
		lappend show_prc_set Y
	} elseif { $ss_found == 1 } {
		lappend show_prc_set N
	} else {
		lappend show_prc_set "-"
	}

	return $show_prc_set
}



proc print_req_args args {
	ob::log::write DEV "******** REQ ARGS *********"
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set name  [reqGetNthName $i]
		set value [reqGetNthVal $i]
		ob::log::write DEV "$name = $value"
	}
	ob::log::write DEV "******** END REQ ARGS *********"
}

#Bind prices for a market.
proc _bind_mkt_prices { ev_mkt_id } {

	global DB MKT_PRICES

	catch { unset MKT_PRICES }

	set sql {
		select
			o.ev_oc_id,
			o.lp_num,
			o.lp_den
		from
			tevOc o
		where
			o.ev_mkt_id = ? and
			o.result = '-' and
			o.status != 'S'
		order by ev_oc_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $ev_mkt_id]
	inf_close_stmt $stmt

	tpSetVar NumOcs [db_get_nrows $res ]

	for {set i 0} { $i < [db_get_nrows $res ]} {incr i} {
		set MKT_PRICES($i,ev_oc_id) [ db_get_col $res $i ev_oc_id ]
		set MKT_PRICES($i,lp_num)   [db_get_col $res $i lp_num ]
		set MKT_PRICES($i,lp_den)   [db_get_col $res $i lp_den ]

	}

	db_close $res

	tpBindVar EvOcId MKT_PRICES ev_oc_id oc_idx
	tpBindVar LpNum MKT_PRICES lp_num oc_idx
	tpBindVar LpDen MKT_PRICES lp_den oc_idx

}


}
