# ==============================================================
# $Id: autogen.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUTOGEN {

asSetAct ADMIN::AUTOGEN::DoEvFB [namespace code do_ev_FB]
asSetAct ADMIN::AUTOGEN::DoEvBB [namespace code do_ev_BB]

variable SUBSTS
variable MR_MKT_ID

set SUBSTS(names) [list]

foreach nv [OT_CfgGet AUTO_SUBST_VARS ""] {
	foreach {n v} $nv {
		set SUBSTS($n) $v
		lappend SUBSTS(names) $n
	}
}


#
# ----------------------------------------------------------------------------
# Add a new event
# ----------------------------------------------------------------------------
#
proc go_ev_add_BB {{homeTeamId ""} {awayTeamId ""}} {

	global DB TEAMARRAY MKTGRPS

	set type_id [reqGetArg TypeId]

	#
	# Read market information for this type
	#
	get_available_ev_oc_grps $type_id

	#
	# First check that the event type has a handicap market available
	#
	if {![info exists MKTGRPS(sort,WH)] || [llength $MKTGRPS(sort,WH)] > 1} {
		err_bind "The event type must have a handicap market available"
		ADMIN::EV_SEL::go_ev_sel
		return
	}

	tpSetVar MKT_WH 1

	set mkt_grp_list [list]

	foreach ev_oc_grp_id $MKTGRPS(ev_oc_grp_id) {

		set sort $MKTGRPS($ev_oc_grp_id,sort)

		if {$sort != "--"} {
			tpSetVar     MKT_$sort     1
			tpBindString DESC_$sort    $MKTGRPS($ev_oc_grp_id,name)
			tpBindString CHECKED_$sort CHECKED

			lappend mkt_grp_list $sort
		}
	}

	tpBindString MktGrpList [join $mkt_grp_list ,]

	#
	# Special case : bind strings to WH market prices
	#
	set dp [ADMIN::MKTPROPS::mkt_flag BB WH default-price]

	if {[string length $dp] > 0} {
		tpBindString WHHomeLP $dp
		tpBindString WHAwayLP $dp
	}

	make_magic_market_default_binds BB

	#
	# Bind team info to datasites
	#
	bind_team_lists $homeTeamId $awayTeamId

	#
	# Get class/type information for display
	#
	bind_class_type_info $type_id

	tpSetVar opAdd 1

	if {[OT_CfgGet FUNC_TYPE_FLAGS 0]} {
		ADMIN::EVENT::make_ev_tag_binds BB [tpGetVar type_flags]
	} else {
		ADMIN::EVENT::make_ev_tag_binds BB RN
	}

	asPlayFile -nocache autogen_BB.html

	catch {unset MKTGRPS}
}


#
# ----------------------------------------------------------------------------
# Route BB event add to appropriate handler
# ----------------------------------------------------------------------------
#
proc do_ev_BB args {

	set act [reqGetArg SubmitName]

	if {$act == "EvAddBB"} {
		do_ev_add_BB
	} elseif {$act == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}


proc do_ev_add_BB args {

	global DB MKTGRPS

	variable SUBSTS
	variable MR_MKT_ID

	#reset this variable for this request to prevent mishaps
	set MR_MKT_ID -1

	set type_id [reqGetArg TypeId]

	#
	# Get list of market types
	#
	get_available_ev_oc_grps $type_id

	set homeTeamId   [reqGetArg EvHomeTeamId]
	set awayTeamId   [reqGetArg EvAwayTeamId]
	set typeId       [reqGetArg TypeId]
	set homeTeamName [get_team_name $homeTeamId]
	set awayTeamName [get_team_name $awayTeamId]
	set evDisporder  [get_latest_ev_disporder $typeId [reqGetArg EvStartTime]]
	set calendar     [reqGetArg Calendar]
	if {$calendar != ""} {
		set calendar "Y"
	}

	#
	# Build event name from substitution string
	#
	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	set evDesc "$homeTeamName $VS $awayTeamName"

	inf_begin_tran $DB

	set ev_id [auto_add_event $typeId\
		desc          $evDesc\
		country       [reqGetArg EvCountry]\
		venue         [reqGetArg EvVenue]\
		ext_key       [reqGetArg EvExtKey]\
		shortcut      [reqGetArg EvShortcut]\
		start_time    [reqGetArg EvStartTime]\
		sort          MTCH\
		flags         [ADMIN::EVENT::make_ev_tag_str BB]\
		disporder     $evDisporder\
		url           [reqGetArg EvURL]\
		tax_rate      [reqGetArg EvTaxRate]\
		mult_key      [reqGetArg EvMultKey]\
		min_bet       [reqGetArg EvMinBet]\
		max_bet       [reqGetArg EvMaxBet]\
		suspend_at    [reqGetArg EvSuspendAt]\
		channels      [make_channel_str]\
		fastkey       [reqGetArg EvFastkey]\
		home_team_id  $homeTeamId\
		away_team_id  $awayTeamId\
		blurb         [reqGetArg EvBlurb]\
		calendar      $calendar]

	if {$ev_id < 0} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		inf_rollback_tran $DB
		autogen_error BB
		return
	}

	#
	# Get list of market sorts to generate
	#
	set mkt_grp_list [split [reqGetArg MktGrpList] ,]
	set mktList      [list]

	foreach m $mkt_grp_list {
		set autogen($m) [reqGetArg ${m}autogen]
		if {$autogen($m) == "1"} {
			if {$m != "WH"} {
				lappend mktList $m
			}
		}
		tpSetVar AUTOGEN_$m $autogen($m)
	}

	#
	# Force autogen of WH market first
	#
	set mktList [linsert $mktList 0 WH]

	OT_LogWrite 1 "Auto-generate [join $mktList ,] markets"

	#
	# Add markets in specified order
	#
	foreach sort $mktList {

		foreach ev_oc_grp_id $MKTGRPS(ev_oc_grp_id) {

			if {$sort == $MKTGRPS($ev_oc_grp_id,sort)} {

				OT_LogWrite 2 "About to auto-generate $sort"

				if {[info commands do_autogen_$sort] == "do_autogen_$sort"} {
					set m_proc do_autogen_$sort
				} else {
					set m_proc do_autogen_magic_market
				}

				set bad [$m_proc\
					[reqGetArg ClassSort]\
					$sort\
					$ev_id\
					$ev_oc_grp_id\
					$MKTGRPS($ev_oc_grp_id,name)\
					$MKTGRPS($ev_oc_grp_id,disporder)\
					$homeTeamName\
					$awayTeamName\
					$homeTeamId\
					$awayTeamId]

				if {$bad != 0} {
					inf_rollback_tran $DB
					autogen_error BB
					return
				}
			}
		}
	}

	tpSetVar EvAdded 1

	inf_commit_tran $DB

	ADMIN::EVENT::go_ev_upd ev_id $ev_id
}


#
# ----------------------------------------------------------------------------
# Add a new event
# ----------------------------------------------------------------------------
#
proc go_ev_add_FB {{homeTeamId ""} {awayTeamId ""}} {

	global DB FB_CHART_MAP TEAMARRAY MKTGRPS

	set type_id [reqGetArg TypeId]

	#
	# Get available market types
	#
	get_available_ev_oc_grps $type_id

	#
	# Check that the event type has a MR market available
	#
	if {![info exists MKTGRPS(sort,MR)]} {
		err_bind "The event type must have a Win/Draw/Win market available"
		ADMIN::EV_SEL::go_ev_sel
		return
	}

	set mkt_grp_list [list]

	foreach ev_oc_grp_id $MKTGRPS(ev_oc_grp_id) {

		set sort $MKTGRPS($ev_oc_grp_id,sort)

		if {$sort != "--"} {

			tpSetVar     MKT_$sort     1
			tpBindString DESC_$sort    $MKTGRPS($ev_oc_grp_id,name)
			tpBindString CHECKED_$sort CHECKED

			lappend mkt_grp_list $sort
		}
	}

	tpBindString MktGrpList [join $mkt_grp_list ,]

	make_magic_market_default_binds FB

	#
	# Bind default to handicap value
	#
	tpBindString MktHcapValue 0

	#
	# Bind team information to data sites
	#
	bind_team_lists $homeTeamId $awayTeamId

	#
	# Get class/type information for display
	#
	bind_class_type_info $type_id

	#
	# Force loading of football chart information
	#
	ADMIN::FBCHARTS::fb_read_chart_info

	tpSetVar NumDomains $FB_CHART_MAP(num_domains)

	tpBindVar DomainFlag FB_CHART_MAP flag domain_idx
	tpBindVar DomainName FB_CHART_MAP name domain_idx

	tpSetVar opAdd 1

	if {[OT_CfgGet FUNC_TYPE_FLAGS 0]} {
		ADMIN::EVENT::make_ev_tag_binds FB [tpGetVar type_flags]
	} else {
		ADMIN::EVENT::make_ev_tag_binds FB "RN"
	}

	asPlayFile -nocache autogen_FB.html
}


#
# ----------------------------------------------------------------------------
# Route event add/update/delete to appropriate handler
# ----------------------------------------------------------------------------
#
proc do_ev_FB args {

	set act [reqGetArg SubmitName]

	if {$act == "EvAddFB"} {
		do_ev_add_FB
	} elseif {$act == "Back"} {
		ADMIN::EV_SEL::go_ev_sel
	} else {
		error "unexpected event operation SubmitName: $act"
	}
}


#
# ----------------------------------------------------------------------------
# Event Add
# ----------------------------------------------------------------------------
#
proc do_ev_add_FB args {

	global DB USERNAME MKTGRPS

	variable SUBSTS
	variable MR_MKT_ID

	#reset this variable for this request to prevent mishaps
	set MR_MKT_ID -1

	set type_id [reqGetArg TypeId]

	#
	# Get list of available markets
	#
	get_available_ev_oc_grps $type_id


	set mkt_grp_list [split [reqGetArg MktGrpList] ,]
	set mktList      [list]

	foreach m $mkt_grp_list {
		set autogen($m) [reqGetArg ${m}autogen]
		if {$autogen($m) == "1"} {
			if {$m != "MR"} {
				lappend mktList $m
			}
		}
		tpSetVar AUTOGEN_$m $autogen($m)
	}

	#
	# Force autogen of MR market first
	#
	set mktList [linsert $mktList 0 MR]
	set autogen(MR) 1

	OT_LogWrite 1 "Auto-generate [join $mktList ,] markets"

	set homeTeamId   [reqGetArg EvHomeTeamId]
	set awayTeamId   [reqGetArg EvAwayTeamId]
	set typeId       [reqGetArg TypeId]
	set homeTeamName [get_team_name $homeTeamId]
	set awayTeamName [get_team_name $awayTeamId]

	set evDisporder  [get_latest_ev_disporder $typeId [reqGetArg EvStartTime]]
	set calendar     [reqGetArg Calendar]
	if {$calendar != ""} {
		set calendar "Y"
	}

	#
	# Build event name from substitution string
	#
	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	set evDesc "$homeTeamName $VS $awayTeamName"

	if {[info exists autogen(SC)] && $autogen(SC)==1} {
		if {![info exists MKTGRPS(sort,CS)] ||
			![info exists MKTGRPS(sort,FS)] ||
			![info exists autogen(CS)] || $autogen(CS) != 1 ||
			![info exists autogen(FS)] || $autogen(FS) != 1} {
			err_bind "For CS/FG Combo, must have CS & FG Markets"
			autogen_error FB
			return
		}
	}

	inf_begin_tran $DB

	set ev_id [auto_add_event $typeId\
		desc          $evDesc\
		country       [reqGetArg EvCountry]\
		venue         [reqGetArg EvVenue]\
		ext_key       [reqGetArg EvExtKey]\
		shortcut      [reqGetArg EvShortcut]\
		start_time    [reqGetArg EvStartTime]\
		sort          MTCH\
		flags         [ADMIN::EVENT::make_ev_tag_str FB]\
		disporder     $evDisporder\
		url           [reqGetArg EvURL]\
		tax_rate      [reqGetArg EvTaxRate]\
		mult_key      [reqGetArg EvMultKey]\
		min_bet       [reqGetArg EvMinBet]\
		max_bet       [reqGetArg EvMaxBet]\
		suspend_at    [reqGetArg EvSuspendAt]\
		fb_dom_int    [reqGetArg EvFBDomain]\
		channels      [make_channel_str]\
		fastkey       [reqGetArg EvFastkey]\
		home_team_id  $homeTeamId\
		away_team_id  $awayTeamId\
		blurb         [reqGetArg EvBlurb]\
		calendar      $calendar ]

	if {$ev_id < 0} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		inf_rollback_tran $DB
		autogen_error FB
		return
	}

	#
	# Need to process markets in mktList order (e.g. to make sure MR
	# is added first
	#

	#Keep track of ev_oc_grp already used, to not do autogenerate twice the same market.
	#This means that if an event type has two H1 ocgrps (like First Half and Half Time), the only resulting H1
	#market will be derived form the first H1 oc_grp of the type. This is because quick setup doesn't allow
	#the generation of several markets of the same sort within an event because we only generate using the sorts and not the ev_oc_grps.
	set processed_ev_oc_grps [list]

	foreach sort $mktList {

		foreach ev_oc_grp_id $MKTGRPS(ev_oc_grp_id) {

			if {$sort == $MKTGRPS($ev_oc_grp_id,sort) && [lsearch $processed_ev_oc_grps $ev_oc_grp_id] == -1} {

				OT_LogWrite 2 "About to auto-generate $sort"

				if {[info commands do_autogen_$sort] == "do_autogen_$sort"} {
					set m_proc do_autogen_$sort
				} else {
					set m_proc do_autogen_magic_market
				}

				OT_LogWrite 2 "Using ev_oc_grp_id $ev_oc_grp_id"

				set bad [$m_proc\
					[reqGetArg ClassSort]\
					$sort\
					$ev_id\
					$ev_oc_grp_id\
					$MKTGRPS($ev_oc_grp_id,name)\
					$MKTGRPS($ev_oc_grp_id,disporder)\
					$homeTeamName\
					$awayTeamName\
					$homeTeamId\
					$awayTeamId]

				lappend processed_ev_oc_grps $ev_oc_grp_id

				if {$bad != 0} {
					inf_rollback_tran $DB
					autogen_error FB
					return
				}
			}
		}
	}

	inf_commit_tran $DB

	tpSetVar EvAdded 1

	catch {unset MKTGRPS}

	ADMIN::EVENT::go_ev_upd ev_id $ev_id
}


#
# ==========================================================================
# Wrappers for SPL calls to insert event/market/selection
# ==========================================================================
#
proc auto_get_param {ary param {dflt ""}} {

	upvar 1 $ary PARAM

	if {[info exists PARAM($param)]} {
		return $PARAM($param)
	}
	return $dflt
}


proc auto_add_event {ev_type_id args} {

	global DB USERNAME

	array set PARAM {
		status          S
		displayed       N
		disporder       1
		feed_updateable -
		is_off          -
	}

	foreach {n v} $args {
		set PARAM($n) $v
	}

	set sql [subst {
		execute procedure pInsEv(
			p_adminuser = ?,
			p_ev_type_id = ?,
			p_desc = ?,
			p_country = ?,
			p_venue = ?,
			p_ext_key = ?,
			p_shortcut = ?,
			p_start_time = ?,
			p_is_off = ?,
			p_sort = ?,
			p_flags = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_url = ?,
			p_status = ?,
			p_tax_rate = ?,
			p_feed_updateable = ?,
			p_mult_key = ?,
			p_min_bet = ?,
			p_max_bet = ?,
			p_t_bet_cutoff = ?,
			p_suspend_at = ?,
			p_fb_dom_int = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_home_team_id = ?,
			p_away_team_id = ?,
			p_blurb = ?,
			p_calendar = ?,
			p_gen_code = ?,
			p_do_tran = 'N'
		)
	}]

	if {[OT_CfgGet FUNC_GEN_EV_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_type_id\
			[auto_get_param PARAM desc]\
			[auto_get_param PARAM country]\
			[auto_get_param PARAM venue]\
			[auto_get_param PARAM ext_key]\
			[auto_get_param PARAM shortcut]\
			[auto_get_param PARAM start_time]\
			[auto_get_param PARAM is_off]\
			[auto_get_param PARAM sort]\
			[auto_get_param PARAM flags]\
			[auto_get_param PARAM displayed]\
			[auto_get_param PARAM disporder]\
			[auto_get_param PARAM url]\
			[auto_get_param PARAM status]\
			[auto_get_param PARAM tax_rate]\
			[auto_get_param PARAM feed_updateable]\
			[auto_get_param PARAM mult_key]\
			[auto_get_param PARAM min_bet]\
			[auto_get_param PARAM max_bet]\
			[auto_get_param PARAM t_bet_cutoff]\
			[auto_get_param PARAM suspend_at]\
			[auto_get_param PARAM fb_dom_int]\
			[auto_get_param PARAM channels]\
			[auto_get_param PARAM fastkey]\
			[auto_get_param PARAM home_team_id]\
			[auto_get_param PARAM away_team_id]\
			[auto_get_param PARAM blurb]\
			[auto_get_param PARAM calendar]\
			$gen_code
		]
	} msg]} {
		 err_bind $msg
		 set bad 1
	}

	inf_close_stmt $stmt

	if {$bad || [db_get_nrows $res] != 1} {
		catch {db_close $res}
		return -1
	}

	set ev_id [db_get_coln $res 0 0]

	db_close $res

	return $ev_id
}


proc auto_add_market {ev_id ev_oc_grp_id sort args} {

	global DB USERNAME
	global DB MKTGRPS

	array set PARAM {
		status    A
		lp_avail  Y
		displayed Y
		disporder 1
	}

	foreach {n v} $args {
		set PARAM($n) $v
	}

	set accMin $MKTGRPS($ev_oc_grp_id,acc_min)
	set accMax $MKTGRPS($ev_oc_grp_id,acc_max)

	set sql [subst {
		execute procedure pInsEvMkt(
			p_adminuser       = ?,
			p_ev_id           = ?,
			p_ev_oc_grp_id    = ?,
			p_sort            = ?,
			p_status          = ?,
			p_displayed       = ?,
			p_disporder       = ?,
			p_lp_avail        = ?,
			p_acc_min         = ?,
			p_acc_max         = ?,
			p_channels        = ?,
			p_apc_status      = ?,
			p_hcap_value      = ?,
			p_deriving_mkt_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_id\
			$ev_oc_grp_id\
			$sort\
			[auto_get_param PARAM status]\
			[auto_get_param PARAM displayed]\
			[auto_get_param PARAM disporder]\
			[auto_get_param PARAM lp_avail]\
			$accMin\
			$accMax\
			[auto_get_param PARAM channels]\
			[auto_get_param PARAM apc_status]\
			[auto_get_param PARAM hcap_value]\
			[auto_get_param PARAM deriving_mkt_id]]} msg]} {
		 err_bind $msg
		 set bad 1
	}

	inf_close_stmt $stmt

	if {$bad || [db_get_nrows $res] != 1} {
		catch {db_close $res}
		return -1
	}

	set mkt_id [db_get_coln $res 0 0]

	db_close $res

	return $mkt_id
}


proc auto_add_seln {ev_id mkt_id args} {

	global DB USERNAME

	array set PARAM {
		status    A
		lp_avail  Y
		displayed Y
		disporder 1
	}

	foreach {n v} $args {
		set PARAM($n) $v
	}

	#
	# Now create the home and away selections
	#
	set sql [subst {
		execute procedure pInsEvOc(
			p_adminuser = ?,
			p_ev_id = ?,
			p_ev_mkt_id = ?,
			p_desc = ?,
			p_status = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_lp_num = ?,
			p_lp_den = ?,
			p_fb_result = ?,
			p_shortcut = ?,
			p_channels = ?,
			p_max_total = ?,
			p_stk_or_lbt = ?,
			p_cs_home = ?,
			p_cs_away = ?,
			p_ext_id = ?,
			p_gen_code = ?,
			p_do_tran = 'N'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	# if we need event/selection codes generating
	if {[OT_CfgGet FUNC_GEN_EV_CODE 0]} {
		set gen_code Y
	} else {
		set gen_code N
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ev_id\
			$mkt_id\
			[auto_get_param PARAM desc]\
			[auto_get_param PARAM status]\
			[auto_get_param PARAM displayed]\
			[auto_get_param PARAM disporder]\
			[auto_get_param PARAM lp_num]\
			[auto_get_param PARAM lp_den]\
			[auto_get_param PARAM fb_result]\
			[auto_get_param PARAM shortcut]\
			[auto_get_param PARAM channels]\
			[auto_get_param PARAM max_total]\
			[auto_get_param PARAM stk_or_lbt]\
			[auto_get_param PARAM cs_home]\
			[auto_get_param PARAM cs_away]\
			[auto_get_param PARAM ext_id]\
			$gen_code\
		]
	} msg]} {

		err_bind $msg
		set bad 1
	}

	catch inf_close_stmt $stmt

	if {$bad || [db_get_nrows $res] != 1} {
		catch {db_close $res}
		return -1
	}

	set seln_id [db_get_coln $res 0 0]

	db_close $res

	return $seln_id

}


#
# ==========================================================================
# Procedures to generate markets of a given sort
# ==========================================================================
#
proc do_autogen_WH {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	global MKTGRPS

	set channels       [make_channel_str]
	set mkt_hcap_value [reqGetArg MktHcapValue]

	if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
		if {[reqGetArg MktHcapSide] == "A"} {
			set mkt_hcap_value [expr {0-$mkt_hcap_value}]
		}
	}

	#
	# Add market
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id WH\
		disporder   $disporder\
		channels    $channels\
		apc_status  A\
		hcap_value  $mkt_hcap_value]

	if {$mkt_id == -1} {
		return 1
	}

	#
	# Set selection info
	#
	set lpNum_H    [reqGetArg WHHomeLP]
	set lpNum_A    [reqGetArg WHAwayLP]

	foreach {lpNum(H) lpDen(H)} [get_price_parts $lpNum_H] {break}
	foreach {lpNum(A) lpDen(A)} [get_price_parts $lpNum_A] {break}

	array set mktDesc [list H $homeTeamName A $awayTeamName]

	set disporder 10

	#
	# Add selections
	#
	foreach oc {H A} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc      $mktDesc($oc)\
			disporder $disporder\
			lp_num    $lpNum($oc)\
			lp_den    $lpDen($oc)\
			fb_result $oc\
			channels  $channels\
			max_total $MKTGRPS($ev_oc_grp_id,mkt_max_liab)]

		if {$seln_id < 0} {
			return 1
		}

		incr disporder 10

		OT_LogWrite 2 "Created WH market selection for $oc"
	}

	return 0
}


proc do_autogen_AH {class_sort
					mktSort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	global MKTGRPS

	set channels        [make_channel_str]
	set mkt_hcap_value	[reqGetArg MktHcapValue]
	set lpNum_H         [reqGetArg AHBHomeLP]
	set lpNum_A         [reqGetArg AHBAwayLP]

	if {[OT_CfgGetTrue FUNC_HCAP_SIDE]} {
		if {[reqGetArg MktHcapSide] == "A"} {
			set mkt_hcap_value [expr {0-$mkt_hcap_value}]
		}
	}

	#
	# Add market
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id AH\
		disporder   $disporder\
		channels    $channels\
		apc_status  A\
		hcap_value  $mkt_hcap_value]

	if {$mkt_id == -1} {
		return 1
	}

	#
	# Set selection info
	#
	foreach {lpNum(H) lpDen(H)} [get_price_parts $lpNum_H] {break}
	foreach {lpNum(A) lpDen(A)} [get_price_parts $lpNum_A] {break}

	set bad [check_AH_price\
		$MKTGRPS($ev_oc_grp_id,hcap_prc_lo)\
		$MKTGRPS($ev_oc_grp_id,hcap_prc_hi)\
		[expr {1.0+(double($lpNum(H))/$lpDen(H))}] "Home"]

	incr bad [check_AH_price\
		$MKTGRPS($ev_oc_grp_id,hcap_prc_lo)\
		$MKTGRPS($ev_oc_grp_id,hcap_prc_hi)\
		[expr {1.0+(double($lpNum(A))/$lpDen(A))}] "Away"]

	if {$bad > 0} {
		return 1
	}

	array set selnDesc [list H $homeTeamName A $awayTeamName]

	set disporder 10

	#
	# Add selections
	#
	foreach oc {H A} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc      $selnDesc($oc)\
			disporder $disporder\
			lp_num    $lpNum($oc)\
			lp_den    $lpDen($oc)\
			fb_result $oc\
			channels  $channels\
			max_total $MKTGRPS($ev_oc_grp_id,mkt_max_liab)]

		if {$seln_id < 0} {
			return 1
		}

		incr disporder 10

		OT_LogWrite 2 "Created AH market selection for $oc"
	}

	return 0
}


proc do_autogen_CS {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	set mr_mkt_id [_get_mr_mkt_id]

	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id CS\
		disporder $disporder\
		channels  [make_channel_str]\
		deriving_mkt_id $mr_mkt_id]

	if {$mkt_id == -1} {
		return 1
	}

	ADMIN::FBCHARTS::fb_read_chart_info

	ADMIN::FBCHARTS::fb_setup_mkt_CS $ev_id $mkt_id $mr_mkt_id

	return 0
}

proc do_autogen_QR {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	set mr_mkt_id [_get_mr_mkt_id]

	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id QR\
		disporder $disporder\
		channels  [make_channel_str]\
		displayed [ADMIN::MKTPROPS::mkt_flag $class_sort $mkt_sort displayed Y]\
		deriving_mkt_id $mr_mkt_id]

	if {$mkt_id == -1} {
		return 1
	}

	ADMIN::FBCHARTS::fb_setup_mkt_QR $ev_id $mkt_id $mr_mkt_id

	return 0
}

proc do_autogen_HF {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	set mr_mkt_id [_get_mr_mkt_id]

	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id HF\
		disporder $disporder\
		channels  [make_channel_str]\
		deriving_mkt_id $mr_mkt_id]

	if {$mkt_id == -1} {
		return 1
	}

	ADMIN::FBCHARTS::fb_read_chart_info

	ADMIN::FBCHARTS::fb_setup_mkt_HF $ev_id $mkt_id $mr_mkt_id

	return 0
}


proc do_autogen_SC {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id SC\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	return 0
}


proc do_autogen_FS {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	return [do_autogen_scorer_mkt\
		$ev_id\
		$ev_oc_grp_id\
		$mktName\
		$disporder\
		$homeTeamName\
		$awayTeamName\
		FS\
		$homeTeamId\
		$awayTeamId]
}

proc do_autogen_LS {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	return [do_autogen_scorer_mkt\
		$ev_id\
		$ev_oc_grp_id\
		$mktName\
		$disporder\
		$homeTeamName\
		$awayTeamName\
		LS\
		$homeTeamId\
		$awayTeamId]
}

proc do_autogen_MR {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	global MKTGRPS

	variable SUBSTS
	variable MR_MKT_ID

	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	#
	# Create the event market first
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id MR\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		set MR_MKT_ID -1
		return 1
	} else {
		# only want to set it the first time round
		if {$MR_MKT_ID == -1} {
			set MR_MKT_ID $mkt_id
		}
	}

	#
	# Set up selection data
	#
	foreach {lpNum(H) lpDen(H)} [get_price_parts [reqGetArg WDWHomeLP]] {break}
	foreach {lpNum(D) lpDen(D)} [get_price_parts [reqGetArg WDWDrawLP]] {break}
	foreach {lpNum(A) lpDen(A)} [get_price_parts [reqGetArg WDWAwayLP]] {break}

	array set wdwDesc [list H $homeTeamName D $DRAW A $awayTeamName]

	set disporder 10
	set channels  [make_channel_str]

	#
	# Now create the Win/Draw/Win selections
	#
	foreach fb_result {H D A} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $wdwDesc($fb_result)\
			disporder   $disporder\
			fb_result   $fb_result\
			channels    $channels\
			lp_num      $lpNum($fb_result)\
			lp_den      $lpDen($fb_result)\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			return 1
		}
		incr disporder 10

	}

	return 0
}

proc do_autogen_HT {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId} {

	global MKTGRPS

	variable SUBSTS

	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	#
	# Create the event market first
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id $mkt_sort\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	array set wdwDesc [list H $homeTeamName D $DRAW A $awayTeamName]

	set disporder 10
	set channels  [make_channel_str]

	#
	# Now create the Win/Draw/Win selections
	#
	foreach fb_result {H D A} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $wdwDesc($fb_result)\
			disporder   $disporder\
			fb_result   $fb_result\
			channels    $channels\
			lp_num      1\
			lp_den      100\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			return 1
		}
		incr disporder 10

	}

	return 0
}

# autogeneration for Win No Draw
# like W-D-W, but on a draw, all bets are voided
proc do_autogen_WL {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	global MKTGRPS

	variable SUBSTS

	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	#
	# Create the event market first
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id WL\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	#
	# Set up selection data
	#
	foreach {lpNum(H) lpDen(H)} [get_price_parts [reqGetArg WLHomeLP]] {break}
	foreach {lpNum(D) lpDen(D)} [get_price_parts [reqGetArg WLDrawLP]] {break}
	foreach {lpNum(A) lpDen(A)} [get_price_parts [reqGetArg WLAwayLP]] {break}

	array set wdwDesc [list H $homeTeamName A $awayTeamName]

	set disporder 10
	set channels  [make_channel_str]

	#
	# Now create the Win/Draw/Win selections
	#
	foreach fb_result {H A} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $wdwDesc($fb_result)\
			disporder   $disporder\
			fb_result   $fb_result\
			channels    $channels\
			lp_num      $lpNum($fb_result)\
			lp_den      $lpDen($fb_result)\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			return 1
		}
		incr disporder 10

	}

	return 0
}

# ----------------------------------------------------------------------------
# Store win-draw-win market details in global WDW array
# ----------------------------------------------------------------------------
proc read_wdw {ev_id {mkt_sort ""}} {
	global DB WDW

	# execute query
	set sql [subst {
		select
			s.lp_num,
			s.lp_den,
			s.fb_result,
			m.disporder,
			m.ev_mkt_id
		from
			tEvClass c,
			tEvType  t,
			tEv      e,
			tEvMkt   m,
			tEvOc    s
		where
			e.ev_id       = ?             and
			e.ev_id       = m.ev_id       and
			m.sort        = 'MR'          and
			m.ev_mkt_id   = s.ev_mkt_id   and
			e.ev_type_id  = t.ev_type_id  and
			t.ev_class_id = c.ev_class_id and
			s.fb_result <> '-'
		order by
			m.disporder, m.ev_mkt_id
	}]

        set stmt [inf_prep_sql $DB $sql]
        if {[catch {set res  [inf_exec_stmt $stmt $ev_id]} msg]} {
                ob::log::write ERROR {proc read_wdw, read_wdw: $msg}
                error {read_wdw failed in proc read_wdw}
                return
        }

        inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows < 3} {
		db_close $res
		error "expected at least three rows in win/draw/win market"
	}

	# there may be multiple MR markets, so ordering by m.disporder
	# and selecting the first three results
	for {set r 0} {$r < 3} {incr r} {

		set v_fb_result [db_get_col $res $r fb_result]

		foreach v [db_get_colnames $res] {
			set WDW($v_fb_result,$v) [db_get_col $res $r $v]
		}
	}

	db_close $res
}


# ----------------------------------------------------------------------------
# Finds and returns the selection ids, old prices and selection names for the
# specified market as a list of 3 lists,
#     list 1 results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
#     list 2 results and old prices: 1 hd_price   2 ad_price   3 ha_price
#     list 3 results and seln names: 1 hd_name    2 ad_name    3 ha_name
# ----------------------------------------------------------------------------
proc get_selns {ev_mkt_id} {
	global DB

	set sql [subst {
		select
			ev_oc_id,
			fb_result,
			lp_num,
			lp_den,
			desc
		from
			tEvOc
		where
			ev_mkt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
        if {[catch {set rs  [inf_exec_stmt $stmt $ev_mkt_id]} msg]} {
                ob::log::write ERROR {get_selns, get_selns: $msg}
                error {get_selns failed in proc get_selns}
                return
        }

        inf_close_stmt $stmt

	set num_rows   [db_get_nrows $rs]
	set results    [list]
	set prices     [list]
	set seln_names [list]

	for {set r 0} {$r < $num_rows} {incr r} {

		set ev_oc_id  [db_get_col $rs $r ev_oc_id]
		set fb_result [db_get_col $rs $r fb_result]
		set lp_num    [db_get_col $rs $r lp_num]
		set lp_den    [db_get_col $rs $r lp_den]
		set desc      [db_get_col $rs $r desc]

		lappend results    $fb_result $ev_oc_id
		lappend prices     $fb_result [list $lp_num $lp_den]
		lappend seln_names $fb_result $desc
	}

	db_close $rs

	return [list $results $prices $seln_names]
}



# ----------------------------------------------------------------------------
# Finds and returns the market id for the specified event and
# market sort
# ----------------------------------------------------------------------------
proc find_ev_mkt_id {ev_id mkt_sort} {
	global DB

	set sql [subst {
		select
			m.ev_mkt_id
		from
			tEvMkt   m
		where
			m.ev_id = ? and
			m.sort  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
        if {[catch {set res  [inf_exec_stmt $stmt $ev_id $mkt_sort]} msg]} {
                ob::log::write ERROR {proc find_ev_mkt_id: $msg}
                error {find_ev_mkt_id failed in proc find_ev_mkt_id}
                return
        }

        inf_close_stmt $stmt

        set rows [db_get_nrows $res]

	if {[db_get_nrows $res] > 0} {
		set ev_mkt_id [db_get_col $res 0 ev_mkt_id]
	} else {
		set ev_mkt_id {}
	}

	db_close $res
	return   $ev_mkt_id
}


# ----------------------------------------------------------------------------
# Calculates and returns double chance odds as a list:
#     {HD hd_odds AD ad_odds HA ha_odds}
#
# Requires WDW array to have been populated with win-draw-win details
# for the specified event
# ----------------------------------------------------------------------------
proc calc_odds_DC {ev_id} {
	global WDW

	# wdw odds
	set p_home [expr {1.0+$WDW(H,lp_num)/double($WDW(H,lp_den))}]
	set p_away [expr {1.0+$WDW(A,lp_num)/double($WDW(A,lp_den))}]
	set p_draw [expr {1.0+$WDW(D,lp_num)/double($WDW(D,lp_den))}]

	# calculate wdw probabilities
	set prob_home [expr {1/double($p_home)}]
	set prob_away [expr {1/double($p_away)}]
	set prob_draw [expr {1/double($p_draw)}]

	# calculate double chance probabilities
	# home and draw
	set hd [expr {double($prob_home) + double($prob_draw)}]

	# away and draw
	set ad [expr {double($prob_away) + double($prob_draw)}]

	# home and away
	set ha [expr {double($prob_home) + double($prob_away)}]

	# convert to decimal odds, some of these may be less than zero.
	set hd [expr {1/double($hd)}]
	set ad [expr {1/double($ad)}]
	set ha [expr {1/double($ha)}]

	OT_LogWrite 1 "calc_odds_DC home and draw: $hd"
	OT_LogWrite 1 "calc_odds_DC away and draw: $ad"
	OT_LogWrite 1 "calc_odds_DC home and away: $ha"

	return [list HD $hd AD $ad HA $ha]
}




# ----------------------------------------------------------------------------
# Update double chance market odds for the specified event.
# Updates the double chance odds if there is a double chance
# market for the specified event; does nothing otherwise
# ----------------------------------------------------------------------------
proc update_mkt_odds_DC {ev_id} {
	global DB WDW USERNAME

	# find the market details for the specified event and market sort
	set ev_mkt_id [find_ev_mkt_id $ev_id DC]

	# if there is not a double chance market for the specified event then return
	if {$ev_mkt_id == {}} {
		return
	}

	# populate WDW array with win-draw-win details
	read_wdw $ev_id DC

	array set FB_RESULT [list HD 1 AD 2 HA 3]

	# calculate the odds
	# (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
	array set DC_ODDS [calc_odds_DC $ev_id]

	# find the selection ids, old prices and selection names
	# (returned as a list of 3 lists,
	#     list 1 fb_results and seln_ids:   1 hd_seln_id 2 ad_seln_id 3 ha_seln_id
	#     list 2 fb_results and old prices: 1 hd_price   2 ad_price   3 ha_price
	#     list 3 fb_results and seln names: 1 hd_name    2 ad_name    3 ha_name
	# )
	set   seln_id_price_list [get_selns $ev_mkt_id]
	array set SELN_IDS       [lindex $seln_id_price_list 0]
	array set SELN_PRC       [lindex $seln_id_price_list 1]
	array set SELN_NAM       [lindex $seln_id_price_list 2]

	foreach result {HD AD HA} {

		# only continue if we have a selection id for this result
		if {[info exists SELN_IDS($FB_RESULT($result))]} {

			set ev_oc_id $SELN_IDS($FB_RESULT($result))
			set status   "A"
			set displayed "Y"
			set odds     $DC_ODDS($result)

			OT_LogWrite 1 "update_mkt_odds_DC odds: $odds"

			set odds_list [get_price_parts $odds]

			OT_LogWrite 1 "update_mkt_odds_DC odds(frac): $odds_list"

			# now some checks: if num/den < 1 this selection cannot be
		    # available as it would allow hedging against the bookmaker
		    # so we suspend it and don't display it.
			if {[expr {double([lindex $odds_list 0])/[lindex $odds_list 1]}] <= 0.00} {
				OT_LogWrite 5 "Result = $result: suspending selection"
								# set to 1/100 and suspend it.
								set numerator 1
								set denominator 100
                                set status "S"
                                set displayed "N"
			} else {
								set numerator   [lindex $odds_list 0]
								set denominator [lindex $odds_list 1]
			}

			# check whether prices have changed
			set old_prices_list $SELN_PRC($FB_RESULT($result))

			# if prices have changed then update selection
			if {$old_prices_list != $odds_list} {


				# execute query
				set sql [subst {
					execute procedure pUpdEvOc(
						p_adminuser = ?,
						p_ev_oc_id  = ?,
						p_displayed = ?,
						p_status    = ?,
						p_lp_num    = ?,
						p_lp_den    = ?
					)
				}]

				set stmt [inf_prep_sql $DB $sql]
			        if {[catch {set res [inf_exec_stmt $stmt $USERNAME $ev_oc_id $displayed $status $numerator $denominator]} msg]} {
			                ob::log::write ERROR {proc update_mkt_odds_DC, upd_ev_oc: $msg}
			                error {upd_ev_oc failed in proc update_mkt_odds_DC}
			                return
			        }

			        inf_close_stmt $stmt
				db_close $res
			}
		}
	}


	unset WDW FB_RESULT DC_ODDS SELN_IDS SELN_PRC SELN_NAM
}



# autogeneration for Double Chance
proc do_autogen_DC {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	global MKTGRPS WDW

	variable SUBSTS

	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	#
	# Create the event market first
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id DC\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	# we have three selections for Double Chance: 1X, X2 and 12
	set Desc [list 1 "1X" 2 "X2" 3 "12"]

	set disporder 10
	set channels  [make_channel_str]

	# calculate the 1X, X2 and 12 probabilities
	set H [get_price_parts [reqGetArg WDWHomeLP]]
	set D [get_price_parts [reqGetArg WDWDrawLP]]
	set A [get_price_parts [reqGetArg WDWAwayLP]]

	# Store the win-draw-win values in global WDW
        set WDW(H,lp_num) [lindex $H 0]
        set WDW(H,lp_den) [lindex $H 1]
        set WDW(D,lp_num) [lindex $D 0]
        set WDW(D,lp_den) [lindex $D 1]
        set WDW(A,lp_num) [lindex $A 0]
        set WDW(A,lp_den) [lindex $A 1]

        # calculate the odds
        # (returned as a list: HD hd_odds AD ad_odds HA ha_odds)
        array set DC_ODDS [calc_odds_DC $ev_id]

	foreach {result i} {HD 1 AD 2 HA 3} {
		set status($i) "A"
		set displayed($i) "Y"
		set odds $DC_ODDS($result)

		set odds_list [get_price_parts $odds]
		# and make the values accessible to the stored proc
		set lp($i,num) [lindex $odds_list 0]
		set lp($i,den) [lindex $odds_list 1]

		if {[expr {double($lp($i,num))/$lp($i,den)}] <= 0.00} {
			OT_LogWrite 5 "i = $i: suspending selection"
			set status($i) "S"
			set displayed($i) "N"
			set lp($i,num) 1
			set lp($i,den) 100
		}
	}

	#
	# Now create the selections
	#
	foreach {fb_result desc} $Desc {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $desc\
			disporder   $disporder\
			fb_result   $fb_result\
			channels    $channels\
			lp_num      $lp($fb_result,num)\
			lp_den      $lp($fb_result,den)\
			status      $status($fb_result)\
			displayed   $displayed($fb_result)\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			return 1
		}
		incr disporder 10

	}

	return 0
}

# autogeneration for Goal/No Goal market
proc do_autogen_GG {class_sort
					sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId} {

	global MKTGRPS

	variable SUBSTS

	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}

	#
	# Create the event market first
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id GG\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	array set Desc [list 1 "No Score(home)"\
						 2 "Score(home)"\
						 3 "No Score(away)"\
						 4 "Score(away)"]

	set disporder 10
	set channels  [make_channel_str]

	# do we need to do any odds calculations here?


	#
	# Now create the selections
	#
	foreach fb_result {1 2 3 4} {

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $Desc($fb_result)\
			disporder   $disporder\
			fb_result   $fb_result\
			channels    $channels\
			lp_num      1\
			lp_den      100\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			return 1
		}
		incr disporder 10

	}

	return 0
}

# autogeneration of GoalScorer market
proc do_autogen_GS {class_sort
					mkt_sort
					ev_id
					ev_oc_grp_id
					mktName
					disporder
					homeTeamName
					awayTeamName
					homeTeamId
					awayTeamId
					args} {

	return [do_autogen_scorer_mkt\
		$ev_id\
		$ev_oc_grp_id\
		$mktName\
		$disporder\
		$homeTeamName\
		$awayTeamName\
		GS\
		$homeTeamId\
		$awayTeamId]
}



#
# ==========================================================================
# Generation of simple "magic markets"
# ==========================================================================
#
proc do_autogen_magic_selns {csort msort ev_id mkt_id channels hcap selns} {

	variable SUBSTS

	set disporder 10
	set bad       0

	#
	# For each class sort we can handle, get the "sort" flag for the
	# market containing the selection names which will be used to build
	# "magic" market selection names using "subst"
	#
	switch -- $csort {
		FB {
			set mkt_sort MR
		}
		BB {
			set mkt_sort WH
		}
		default {
			error "Don't know what the default market for $csort is"
		}
	}

	#
	# Read the base market selection names, and use the flag value
	# (from fb_result) as the name of a variable to be
	# used in the "subst" call below to make the selection name
	# auto-magically appear... we also add in the values in the SUBSTS
	# array, and the handicap value
	#
	foreach {k v} [get_base_mkt_seln_names $ev_id $mkt_sort] {
		set $k $v
	}
	foreach n $SUBSTS(names) {
		set $n $SUBSTS($n)
	}
	set HCAP $hcap

	#
	# Add selections
	#
	foreach s $selns {

		array set NV $s

		set s_desc [subst -nocommands -nobackslashes $NV(desc)]

		set s_price [ADMIN::MKTPROPS::mkt_flag $csort $msort default-price]

		if {[string length $s_price] == 0} {
			set s_price "1/100"
		}

		foreach {lp_num lp_den} [get_price_parts $s_price] {break}

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $s_desc\
			disporder   $disporder\
			fb_result   $NV(fb_result)\
			channels    $channels\
			lp_num      $lp_num\
			lp_den      $lp_den\
			cs_home     [lindex [array get NV cs_home] 1]\
			cs_away		[lindex [array get NV cs_away] 1]\
			shortcut    [lindex [array get NV shortcut] 1]]

		array unset NV

		if {$seln_id < 0} {
			return 1
		}

		incr disporder 10
	}

	return 0
}


proc do_autogen_magic_market {csort
							  msort
							  ev_id
							  ev_oc_grp_id
							  mktName
							  disporder
							  args} {

	set channels   [make_channel_str]
	set hcap_value [reqGetArg ${msort}_hcap_value]

	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id $msort\
		disporder  $disporder\
		channels   $channels\
		hcap_value $hcap_value]

	if {$mkt_id == -1} {
		return 1
	}

	#
	# Get seln information from magic market configuration
	#
	set selns [ADMIN::MKTPROPS::mkt_seln_info $csort $msort]

	return [do_autogen_magic_selns\
		$csort $msort $ev_id $mkt_id $channels $hcap_value $selns]
}


proc do_autogen_scorer_mkt {ev_id
							ev_oc_grp_id
							mktName
							disporder
							homeTeamName
							awayTeamName
							sort
							homeTeamId
							awayTeamId
							args} {

	global MKTGRPS playernames

	set ok         1
	set channels   [make_channel_str]

	#
	# Add market
	#
	set mkt_id [auto_add_market $ev_id $ev_oc_grp_id $sort\
		disporder $disporder\
		channels  [make_channel_str]]

	if {$mkt_id == -1} {
		return 1
	}

	#
	# read team players...
	#
	set rsHomePlayers [get_team_players $homeTeamId]
	set rsAwayPlayers [get_team_players $awayTeamId]

	build_player_names $rsHomePlayers $rsAwayPlayers


	#
	# Home players
	#
	if {$ok} {
		set numPlayers [db_get_nrows $rsHomePlayers]

		set disporder 10

		for {set i 0} {$i<$numPlayers} {incr i} {

			set player_id [db_get_col $rsHomePlayers $i player_id]
			set ext_id    [db_get_col $rsHomePlayers $i ext_id]

			set seln_id [auto_add_seln $ev_id $mkt_id\
				desc        $playernames($player_id)\
				disporder   $disporder\
				fb_result   H\
				channels    $channels\
				lp_num      1\
				lp_den      100\
				stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)\
				ext_id      $ext_id]

			if {$seln_id < 0} {
				set ok 0
				break
			}
			if {[OT_CfgGet ORDERED_FS "Y"] == "Y"} {
				incr disporder 10
			}
		}
	}

	#
	# No goalscorer
	#
	if {$ok} {
		set disporder 1010
		set desc      "No Goalscorer"

		set seln_id [auto_add_seln $ev_id $mkt_id\
			desc        $desc\
			disporder   $disporder\
			fb_result   N\
			channels    $channels\
			lp_num      1\
			lp_den      100\
			stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)]

		if {$seln_id < 0} {
			set ok 0
		}
	}

	#
	# Away players
	#
	if {$ok} {
		set numPlayers [db_get_nrows $rsAwayPlayers]
		set disporder  2010

		for {set i 0} {$i<$numPlayers} {incr i} {

			set player_id [db_get_col $rsAwayPlayers $i player_id]
			set ext_id    [db_get_col $rsAwayPlayers $i ext_id]


			set seln_id [auto_add_seln $ev_id $mkt_id\
				desc        $playernames($player_id)\
				disporder   $disporder\
				fb_result   A\
				channels    $channels\
				lp_num      1\
				lp_den      100\
				stk_or_lbt  $MKTGRPS($ev_oc_grp_id,oc_stk_or_lbt)\
				ext_id      $ext_id]

			if {$seln_id < 0} {
				set ok 0
				break
			}

			incr disporder 10
		}
	}

	db_close $rsHomePlayers
	db_close $rsAwayPlayers

	catch {unset playernames}

	return [expr {($ok == 1) ? 0 : -1}]
}


proc get_base_mkt_seln_names {ev_id sort} {

	global DB

	set sql [subst {
		select
			s.desc,
			s.fb_result res_flag
		from
			tEvmkt m,
			tEvOc s
		where
			m.ev_id = $ev_id and
			m.ev_mkt_id = s.ev_mkt_id and
			m.sort = '$sort'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set teams [list]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		lappend teams [db_get_col $res $r res_flag]
		lappend teams [db_get_col $res $r desc]
	}

	return $teams
}


proc check_AH_price {prcLo prcHi prc side} {

	if {[string trim $prc] != ""} {
		if {$prcLo != ""} {
			if {$prcLo > $prc} {
				err_bind "AH $side Price is below minimum of $prcLo"
				return 1
			}
			if {$prcHi < $prc} {
				err_bind "AH $side Price is above maximum of $prcHi"
				return 1
			}
		}
		return 0
	}
	err_bind "Must specify AH $side Price"
	return 1
}


proc bind_class_type_info {type_id} {

	global DB

	#
	# Get class/type information for display
	#
	set sql [subst {
		select
			c.name cname,
			t.name tname,
			c.sort,
			t.channels,
			t.ev_min_bet,
			t.ev_max_bet,
			t.flags
		from
			tEvClass c,
			tEvType  t
		where
			t.ev_type_id = $type_id and
			t.ev_class_id = c.ev_class_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar ClassSort [db_get_col $res 0 sort]

	tpBindString TypeId     $type_id
	tpBindString ClassName  [db_get_col $res 0 cname]
	tpBindString TypeName   [db_get_col $res 0 tname]
	tpBindString EvMinBet   [db_get_col $res 0 ev_min_bet]
	tpBindString EvMaxBet   [db_get_col $res 0 ev_max_bet]
	tpSetVar     type_flags [db_get_col $res 0 flags]

	make_channel_binds "" [db_get_col $res 0 channels] 1

	db_close $res
}


proc get_team_players {team_id} {

	global DB

	set stmt [inf_prep_sql $DB {
		select
			p.player_id,
			p.fname,
			p.lname,
			tp.tp_id as ext_id
		from
			tTeam t,
			tPlayer p,
			tPlayerTeam tp
		where
			p.player_id = tp.player_id
		and tp.team_id  = t.team_id
		and t.team_id = ?
		order by
			p.lname
	}]

	set rs [inf_exec_stmt $stmt $team_id]

	inf_close_stmt $stmt

	return $rs
}


proc build_player_names {players1 players2} {

	global playernames

	set np 0

	foreach res [list $players1 $players2] {
		set n [db_get_nrows $res]
		for {set i 0} {$i < $n} {incr i} {
			lappend playerId [db_get_col $res $i player_id]
			lappend playerFN [db_get_col $res $i fname]
			lappend playerLN [db_get_col $res $i lname]
			incr np
		}
	}

	array set playernames [list]

	for {set i 0} {$i < $np} {incr i} {

		set player_id  [lindex $playerId $i]
		set name       [lindex $playerLN $i]
		set w_playerLN [lreplace $playerLN $i $i]
		set w_index    [lsearch -exact $w_playerLN $name]

		#
		# look for a repeat occurrence of the last name
		#
		if {$w_index != -1} {
			append name ", [lindex $playerFN $i]"
		}
		set playernames($player_id) $name
	}
}


proc autogen_error {sort} {

	for {set a 0} {$a < [reqGetNumVals]} {incr a} {
		tpBindString [reqGetNthName $a] [reqGetNthVal $a]
	}

	set homeTeam [reqGetArg EvHomeTeamId]
	set awayTeam [reqGetArg EvAwayTeamId]

	go_ev_add_$sort $homeTeam $awayTeam
}


proc bind_team_lists {{homeTeamId ""} {awayTeamId ""}} {

	global DB TEAMARRAY

	#
	# Get available team lists
	#
	set sql [subst {
		select
			name,
			team_id,
			sort_name,
			nvl(sort_name, 'ZZZZZZ') sort,
			status
		from
			tTeam
		order by
			status,
			sort,
			name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set TEAMARRAY(entries) [set numTeams [db_get_nrows $res]]

	set homeIdx 0
	set awayIdx 0

	for {set i 0} {$i < $numTeams} {incr i} {

		set team_id [db_get_col $res $i team_id]

		set TEAMARRAY($i,team_id) $team_id

		if {$team_id == $homeTeamId} {
			set homeIdx $i
		}
		if {$team_id == $awayTeamId} {
			set awayIdx $i
		}

		#
		# Prepend the sort name for menu display purposes (if not zero length).
		#
		if {[set sort_name [db_get_col $res $i sort_name]] != ""} {
			set TEAMARRAY($i,menu_name) "$sort_name,[db_get_col $res $i name]"
		} else {
			set TEAMARRAY($i,menu_name) [db_get_col $res $i name]
		}
	}

	tpBindString HOME_TEAM_IDX $homeIdx
	tpBindString AWAY_TEAM_IDX $awayIdx

	tpBindVar TEAM_ID   TEAMARRAY team_id    c_idx
	tpBindVar TEAM_NAME TEAMARRAY menu_name  c_idx
}


proc get_team_name {team_id} {

	global DB

	set sql [subst {
		select name
		from   tTeam
		where  team_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $team_id]

	inf_close_stmt $stmt

	set name [db_get_col $res 0 name]
	db_close $res

	return $name
}


proc get_latest_ev_disporder {ev_type_id start_time} {

	global DB

	set sql [subst {
		select NVL(max(disporder),0) as disporder
		from   tEv
		where  ev_type_id = ? and start_time = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ev_type_id $start_time]

	inf_close_stmt $stmt

	set disporder [expr {10+[db_get_col $res 0 disporder]}]
	db_close $res

	return $disporder
}


proc get_available_ev_oc_grps {type_id} {

	global DB MKTGRPS

	set sql [subst {
		select
			ev_oc_grp_id,
			name,
			sort,
			mkt_max_liab,
			disporder,
			acc_min,
			acc_max,
			oc_min_bet,
			oc_max_bet,
			oc_stk_or_lbt,
			hcap_prc_lo,
			hcap_prc_hi,
			hcap_prc_adj,
			hcap_step
		from
			tEvOcGrp
		where
			ev_type_id = ?
		order by
			disporder asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $type_id]

	inf_close_stmt $stmt

	catch {unset MKTGRPS}

	set MKTGRPS(ev_oc_grp_id) [list]

	set n_rows [db_get_nrows $res]

	if {$n_rows > 0} {

		set col_names [db_get_colnames $res]

		for {set r 0} {$r < $n_rows} {incr r} {

			set ev_oc_grp_id [db_get_col $res $r ev_oc_grp_id]
			set sort         [db_get_col $res $r sort]

			foreach c $col_names {
				set MKTGRPS($ev_oc_grp_id,$c) [db_get_col $res $r $c]
			}

			lappend MKTGRPS(sort,$sort)   $ev_oc_grp_id
			lappend MKTGRPS(ev_oc_grp_id) $ev_oc_grp_id
		}
	}

	set MKTGRPS(num_mkts) $n_rows

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Bind default values in magic market configuration to data sites
# ----------------------------------------------------------------------------
#
proc make_magic_market_default_binds {csort} {

	foreach mkt_sort [ADMIN::MKTPROPS::mkt_sorts $csort] {
		foreach {n v} [ADMIN::MKTPROPS::mkt_sort_info $csort $mkt_sort] {
			tpBindString ${mkt_sort}_$n $v
		}
	}
}


proc _get_mr_mkt_id args {

	variable MR_MKT_ID
	return $MR_MKT_ID

}

}
