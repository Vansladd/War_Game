# ==============================================================
# $Id: type.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TYPE {

asSetAct ADMIN::TYPE::GoType [namespace code go_type]
asSetAct ADMIN::TYPE::DoType [namespace code do_type]

#
# ----------------------------------------------------------------------------
# Go to type page - two activators, one with a type id, one without
# ----------------------------------------------------------------------------
#
proc go_type args {

	global BF_CC SUB_TYPE

	set class_id [reqGetArg ClassId]
	set type_id  [reqGetArg TypeId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ClassId $class_id

	#
	# Find out some class information
	#
	set sql [subst {
		select
			name,
			sort,
			channels,
			languages,
			category
		from
			tEvClass
		where
			ev_class_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt $class_id]
	inf_close_stmt $stmt

	tpBindString  ClassName [db_get_col $res 0 name]
	tpSetVar      ClassSort [db_get_col $res 0 sort]
	tpSetVar 	  ClassId   $class_id
	tpSetVar      Category  [db_get_col $res 0 category]

	set channel_mask  [db_get_col $res 0 channels]
	set language_mask [db_get_col $res 0 languages]

	db_close $res

	ADMIN::MKTPROPS::make_mkt_binds [tpGetVar ClassSort]
	make_region_binds

	#
	# If we're adding a type, there's not much to do. For updating a type,
	# there's a load of stuff thet needs to be pulled from the database
	#
	if {$type_id == ""} {

		tpSetVar opAdd 1

		make_channel_binds  "" $channel_mask  1
		make_language_binds $language_mask - 1

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			make_view_binds "" - 1
		}

	} else {

		tpBindString TypeId $type_id
		tpSetVar opAdd 0

		#
		# Get type information
		#
		set sql [subst {
			select
				t.name,
				t.disporder,
				t.displayed,
				t.status,
				t.async_betting,
				t.ext_key,
				t.url,
				t.max_payout,
				t.ev_min_bet,
				t.ev_max_bet,
				t.ev_max_pot_win,
				t.ev_ew_factor,
				t.sp_max_bet,
				t.ep_max_bet,
				t.fc_max_bet,
				t.fc_max_payout,
				t.tc_max_bet,
				t.tc_max_payout,
				t.blurb,
				t.region_id,
				t.tax_rate,
				t.channels,
				t.fastkey,
				t.languages,
				t.flags,
				t.coupon_sort,
				t.ltl_win_lp,
				t.ltl_win_sp,
				t.ltl_place_lp,
				t.ltl_place_sp,
				t.ltl_win_ep,
				t.ltl_place_ep,
				t.max_multiple_bet,
				t.bir_delay,
				pGetHierarchyBIRDelayLevel ("TYPE", ?) as bir_hierarchy,
				pGetHierarchyBIRDelay ("TYPE", ?) as bir_hierarchy_value
			from
				tEvType t
			where
				t.ev_type_id = ?
			order by
				disporder
		}]

		set stmt      [inf_prep_sql $::DB $sql]
		set res_type  [inf_exec_stmt $stmt $type_id $type_id $type_id]
		inf_close_stmt $stmt


		set bir_delay     [db_get_col $res_type 0 bir_delay]
		set bir_hierarchy [db_get_col $res_type 0 bir_hierarchy]

		if {$bir_delay == "" && $bir_hierarchy != ""} {
			tpSetVar displayBIRHierarchy 1
			tpBindString BIRHierarchy     $bir_hierarchy
			tpBindString BIRHierarchyVal  [db_get_col $res_type 0 bir_hierarchy_value]
		}

		tpBindString BIRDelay             $bir_delay
		tpBindString TypeName             [db_get_col $res_type 0 name]
		tpBindString TypeStatus           [db_get_col $res_type 0 status]
		tpBindString TypeExtKey           [db_get_col $res_type 0 ext_key]
		tpBindString TypeTaxRate          [db_get_col $res_type 0 tax_rate]
		tpBindString TypeMaxPayout        [db_get_col $res_type 0 max_payout]
		tpBindString TypeEvMinBet         [db_get_col $res_type 0 ev_min_bet]
		tpBindString TypeEvMaxBet         [db_get_col $res_type 0 ev_max_bet]
		tpBindString TypeEvMaxPotWin      [db_get_col $res_type 0 ev_max_pot_win]
		tpBindString TypeEvEachWayFactor  [db_get_col $res_type 0 ev_ew_factor]
		tpBindString TypeSpMaxBet         [db_get_col $res_type 0 sp_max_bet]
		tpBindString TypeEpMaxBet         [db_get_col $res_type 0 ep_max_bet]
		tpBindString TypeFCMaxBet         [db_get_col $res_type 0 fc_max_bet]
		tpBindString TypeFCMaxPayout      [db_get_col $res_type 0 fc_max_payout]
		tpBindString TypeTCMaxBet         [db_get_col $res_type 0 tc_max_bet]
		tpBindString TypeTCMaxPayout      [db_get_col $res_type 0 tc_max_payout]
		tpBindString TypeDisporder        [db_get_col $res_type 0 disporder]
		tpBindString TypeDisplayed        [db_get_col $res_type 0 displayed]
		tpBindString TypeAsyncBetting     [db_get_col $res_type 0 async_betting]
		tpBindString TypeURL              [db_get_col $res_type 0 url]
		tpBindString TypeBlurb            [db_get_col $res_type 0 blurb]
		tpBindString TypeFastkey          [db_get_col $res_type 0 fastkey]
		tpBindString TypeLaytoLose1       [db_get_col $res_type 0 ltl_win_lp]
		tpBindString TypeLaytoLose2       [db_get_col $res_type 0 ltl_win_sp]
		tpBindString TypeLaytoLose3       [db_get_col $res_type 0 ltl_place_lp]
		tpBindString TypeLaytoLose4       [db_get_col $res_type 0 ltl_place_sp]
		tpBindString TypeLaytoLose5       [db_get_col $res_type 0 ltl_win_ep]
		tpBindString TypeLaytoLose6       [db_get_col $res_type 0 ltl_place_ep]
		tpBindString TypeCouponSort       [db_get_col $res_type 0 coupon_sort]
		tpBindString TypeRegionId         [db_get_col $res_type 0 region_id]
		tpBindString TypeMaxMultipleBet  [db_get_col $res_type 0 max_multiple_bet]

		make_channel_binds  [db_get_col $res_type 0 channels]  $channel_mask
		make_language_binds [db_get_col $res_type 0 languages] -

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			#
			# Build up the View array
			#
			set sql [subst {
				select
					view
				from
					tView
				where
					id   = ?
				and sort = ?
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $type_id TYPE]
			inf_close_stmt $stmt

			set view_list [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend view_list [db_get_col $rs $i view]
			}

			make_view_binds $view_list -

			db_close $rs

			#
			# Build up a list of languages that will need to be translated
			# with the current view list
			#
			set sql [subst {
				select distinct
					name
				from
					tView c,
					tViewLang v,
					tLang l
				where
					c.view = v.view and
					v.lang = l.lang and
					c.id   = ? and
					c.sort = ?
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $type_id TYPE]
			inf_close_stmt $stmt

			set lang_list [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend lang_list [db_get_col $rs $i name]
			}

			if {[llength $lang_list] < 1} {
				set lang_list "No Views Selected"
			}

			tpBindString lang_list $lang_list

			db_close $rs
		}

		if {[OT_CfgGet FUNC_MENU_EV_TYPE_LINK 0]} {
			global LINKED_EV_TYPES
			catch {unset LINKED_EV_TYPES}

			#This is used to link ev_types
			set sql {
				select
					t.name,
					c.name as class,
					t.ev_type_id
				from
					tevtype  t,
					tevclass c,
					tevtypelink l1,
					tevtypelink l2
				where
					    c.ev_class_id  = t.ev_class_id
					and t.ev_type_id   = l2.ev_type_id
					and l2.link_key    = l1.link_key
					and l2.ev_type_id != ?
					and l1.ev_type_id  = ?
			}

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $type_id $type_id]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $rs]

			for {set i 0} {$i < $nrows} {incr i} {
				set LINKED_EV_TYPES($i,ev_type_id) [db_get_col $rs $i ev_type_id]
				set LINKED_EV_TYPES($i,name)       [db_get_col $rs $i name]
				set LINKED_EV_TYPES($i,class)      [db_get_col $rs $i class]
			}
			db_close $rs

			GC::mark LINKED_EV_TYPES

			tpSetVar  NumLinkedEvTypes   $nrows

			tpBindVar LinkedEvTypeId     LINKED_EV_TYPES ev_type_id     linked_ev_type_idx
			tpBindVar LinkedEvTypeName   LINKED_EV_TYPES name           linked_ev_type_idx
			tpBindVar LinkedEvTypeClass  LINKED_EV_TYPES class          linked_ev_type_idx
		}

		#
		# get market information
		#
		set sql [subst {
			select
				ev_type_id,
				ev_oc_grp_id,
				disporder,
				name,
				tag,
				channels,
				bir_delay
			from
				tEvOcGrp
			where
				ev_type_id = $type_id
			order by
				disporder asc
		}]

		set stmt     [inf_prep_sql $::DB $sql]
		set res_mkt  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumMktGrps [db_get_nrows $res_mkt]

		tpBindTcl MktGrpId        sb_res_data $res_mkt market_idx ev_oc_grp_id
		tpBindTcl MktGrpName      sb_res_data $res_mkt market_idx name
		tpBindTcl MktGrpTag       sb_res_data $res_mkt market_idx tag
		tpBindTcl MktGrpDisporder sb_res_data $res_mkt market_idx disporder
		tpBindTcl MktGrpChannels  sb_res_data $res_mkt market_idx channels
		tpBindTcl MktGrpBIRDelay  sb_res_data $res_mkt market_idx bir_delay

		if {[OT_CfgGet FUNC_INDEX_TRADE 0]} {

			ADMIN::IXMKTPROPS::make_mkt_binds [tpGetVar ClassSort]

			set sql [subst {
				select
					f.f_mkt_grp_id id,
					f.disporder,
					f.sort,
					f.channels,
					f.name,
					f.code
				from
					tfMktGrp f
				where
					ev_type_id = $type_id
				order by
					f.disporder asc
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set res  [inf_exec_stmt $stmt]
			inf_close_stmt $stmt

			tpSetVar NumIxMktGrps [set n_rows [db_get_nrows $res]]

			GC::mark ::IXMKTGRP

			for {set r 0} {$r < $n_rows} {incr r} {
				set ::IXMKTGRP($r,id)        [db_get_col $res $r id]
				set ::IXMKTGRP($r,disporder) [db_get_col $res $r disporder]
				set ::IXMKTGRP($r,sort)      [db_get_col $res $r sort]
				set ::IXMKTGRP($r,name)      [db_get_col $res $r name]
				set ::IXMKTGRP($r,channels)  [db_get_col $res $r channels]
			}

			tpBindVar IxMktGrpId        ::IXMKTGRP id         ixmg_idx
			tpBindVar IxMktGrpDisporder ::IXMKTGRP disporder  ixmg_idx
			tpBindVar IxMktGrpSort      ::IXMKTGRP sort       ixmg_idx
			tpBindVar IxMktGrpName      ::IXMKTGRP name       ixmg_idx
			tpBindVar IxMktGrpChannels  ::IXMKTGRP channels   ixmg_idx

			db_close $res
		}


		#
		# Get location constraint information
		#
		set sql [subst {
			select
				c.country_code,
				c.country_name,
				case NVL(t.ev_type_id,0)
					when 0 then "" else "selected"
				end selected
			from
				tCountry c,
				outer tEvTypeExcl t
			where
				t.ev_type_id = $type_id and
				c.country_code = t.country_code
		}]

		set stmt      [inf_prep_sql $::DB $sql]
		set res_cntry [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCountries [db_get_nrows $res_cntry]

		tpBindTcl CntryCode sb_res_data $res_cntry cntry_idx country_code
		tpBindTcl CntryName sb_res_data $res_cntry cntry_idx country_name
		tpBindTcl Selected  sb_res_data $res_cntry cntry_idx selected

		# Added for the Betfair Sub Type mapping option
		if {[OT_CfgGet BF_ACTIVE 0] && [OT_CfgGet BF_SUB_TYPE_MATCH 0]} {
			ADMIN::BETFAIR_TYPE::bind_bf_sub_type_match_info $class_id $type_id
		}

		#Get track code info
		set sql {
			select
				fm.track_code
			from
				tForm2Map fm
			where
				ev_type_id = ?
		}

		set stmt      [inf_prep_sql $::DB $sql]
		set res_track [inf_exec_stmt $stmt $type_id]

		if {[db_get_nrows $res_track] == 1} {
			tpBindString TypeForm2Map [db_get_col $res_track 0 track_code]
		}

	}

	#
	# Get flag information for type
	#
	if {[OT_CfgGet FUNC_TYPE_FLAGS 0]} {
		global TYPETAGS
		catch {unset TYPETAGS}

		if {$type_id != ""} {
			set flags [split [db_get_col $res_type 0 flags] ,]
		} else {
			set flags [split [make_flag_str] ,]
		}

		set ci 0
		foreach c [OT_CfgGet TYPE_FLAGS ""] {
			set TYPETAGS($ci,TypeTagCode) [lindex $c 0]
			set TYPETAGS($ci,TypeTagName) [lindex $c 1]
			if {[lsearch -exact $flags $TYPETAGS($ci,TypeTagCode)] != -1} {
				set TYPETAGS($ci,TypeTagSel) checked
			}
			incr ci
		}

		tpSetVar NumTypeTags $ci

		tpBindVar TypeTagCode TYPETAGS TypeTagCode type_tag_idx
		tpBindVar TypeTagName TYPETAGS TypeTagName type_tag_idx
		tpBindVar TypeTagSel  TYPETAGS TypeTagSel  type_tag_idx
	}

	if {[string first COUPON_SORT [OT_CfgGet FUNC_TYPE_FIELDS ""]] >= 0} {
		if {[OT_CfgGet COUPON_SORTS ""] != ""} {
			set coupon_sorts [OT_CfgGet COUPON_SORTS]
		} else {
			set coupon_sorts "'','Standard', 'AH','Asian Handicap',\
							'WH','Straight handicap', 'EC','Event coupon',\
							'DC','Double Chance', 'MR','Win Draw Win',\
							'hl','Hi-Lo coupon'"
			if {[OT_CfgGet COUPONS_EXTRA ""] != ""} {
				append coupon_sorts ", [OT_CfgGet COUPONS_EXTRA]"
			}
		}
		tpSetVar COUPON_SORTS $coupon_sorts
	}

	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any drilldown items. Such as categories, classes types and
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

	asPlayFile type.html

	if {$type_id != ""} {
		db_close $res_type
		db_close $res_mkt
		db_close $res_cntry
		db_close $res_track
	}
}


#
# ----------------------------------------------------------------------------
# Update type
# ----------------------------------------------------------------------------
#
proc do_type args {

	set act [reqGetArg SubmitName]

	if {$act == "TypeAdd"} {
		do_type_add
	} elseif {$act == "TypeMod"} {
		do_type_upd
	} elseif {$act == "TypeDel"} {
		do_type_del
	} elseif {$act == "Back"} {
		ADMIN::CLASS::go_class
	} elseif {$act == "UpdRule"} {
		ADMIN::BETFAIR_TYPE::do_upd_rule
	} elseif {$act == "TypeClone"} {
		do_type_clone
	} elseif {$act == "ResetOcGrp"} {
		do_type_reset_oc_grp
		puts "ResetOcGrp"
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_type_add args {

	set sql {
		execute procedure pInsEvType(
			p_adminuser = ?,
			p_ev_class_id = ?,
			p_name = ?,
			p_status = ?,
			p_ext_key = ?,
			p_max_payout = ?,
			p_tax_rate = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_async_betting = ?,
			p_region_id = ?,
			p_linked_ev_type_id = ?,
			p_url = ?,
			p_blurb = ?,
			p_ev_min_bet = ?,
			p_ev_max_bet = ?,
			p_sp_max_bet = ?,
			p_ep_max_bet = ?,
			p_fc_max_bet = ?,
			p_fc_max_payout = ?,
			p_tc_max_bet = ?,
			p_tc_max_payout = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_flags = ?,
			p_coupon_sort = ?,
			p_ev_max_pot_win = ?,
			p_ev_ew_factor = ?,
			p_ltl_win_lp = ?,
			p_ltl_win_sp = ?,
			p_ltl_place_lp = ?,
			p_ltl_place_sp = ?,
			p_ltl_win_ep = ?,
			p_ltl_place_ep = ?,
			p_max_multiple_bet = ?,
			p_track_code = ?,
			p_bir_delay = ?
		)
	}

	set bad 0
	set stmt [inf_prep_sql $::DB $sql]

	#do linked ev type stuff
	set linked_ev_type_id [reqGetArg LinkedEventTypeId]

	set bir_delay [reqGetArg TypeBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_type
			return
		}
	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_type
			return
		}
	}

	if {[catch {

		inf_begin_tran $::DB

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			[reqGetArg ClassId]\
			[reqGetArg TypeName]\
			[reqGetArg TypeStatus]\
			[reqGetArg TypeExtKey]\
			[reqGetArg TypeMaxPayout]\
			[reqGetArg TypeTaxRate]\
			[reqGetArg TypeDisplayed]\
			[reqGetArg TypeDisporder]\
			[reqGetArg TypeAsyncBetting]\
			[reqGetArg TypeRegion]\
			$linked_ev_type_id\
			[reqGetArg TypeURL]\
			[reqGetArg TypeBlurb]\
			[reqGetArg TypeEvMinBet]\
			[reqGetArg TypeEvMaxBet]\
			[reqGetArg TypeSpMaxBet]\
			[reqGetArg TypeEpMaxBet]\
			[reqGetArg TypeFCMaxBet]\
			[reqGetArg TypeFCMaxPayout]\
			[reqGetArg TypeTCMaxBet]\
			[reqGetArg TypeTCMaxPayout]\
			[make_channel_str]\
			[reqGetArg TypeFastkey]\
			[make_language_str]\
			[make_flag_str]\
			[reqGetArg TypeCouponSort]\
			[reqGetArg TypeEvMaxPotWin]\
			[reqGetArg TypeEvEachWayFactor]\
			[reqGetArg TypeLaytoLose1]\
			[reqGetArg TypeLaytoLose2]\
			[reqGetArg TypeLaytoLose3]\
			[reqGetArg TypeLaytoLose4]\
			[reqGetArg TypeLaytoLose5]\
			[reqGetArg TypeLaytoLose6]\
			[reqGetArg TypeMaxMultipleBet]\
			[reqGetArg TypeForm2Map] \
			$bir_delay]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add type (no type_id retrieved)"
			set bad 1
		} else {
			set type_id [db_get_coln $res 0 0]
		}

		catch {db_close $res}

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad == 0} {
			set upd_view [ADMIN::VIEWS::upd_view TYPE $type_id]
			if {[lindex $upd_view 0]} {
				err_bind [lindex $upd_view 1]
				set bad 1
			}
		}

	} msg]} {
		set bad 1
		err_bind $msg
	}

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar TypeAddFailed 1
		go_type
		return
	}

	inf_commit_tran $::DB

	tpSetVar TypeAdded 1

	go_type type_id $type_id
}

proc do_type_upd args {

	set sql {
		execute procedure pUpdEvType(
			p_adminuser = ?,
			p_ev_type_id = ?,
			p_name = ?,
			p_status = ?,
			p_ext_key = ?,
			p_max_payout = ?,
			p_tax_rate = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_async_betting = ?,
			p_region_id = ?,
			p_linked_ev_type_id = ?,
			p_url = ?,
			p_blurb = ?,
			p_ev_min_bet = ?,
			p_ev_max_bet = ?,
			p_sp_max_bet = ?,
			p_ep_max_bet = ?,
			p_fc_max_bet = ?,
			p_fc_max_payout = ?,
			p_tc_max_bet = ?,
			p_tc_max_payout = ?,
			p_channels = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_flags = ?,
			p_coupon_sort = ?,
			p_ev_max_pot_win = ?,
			p_ev_ew_factor = ?,
			p_ltl_win_lp = ?,
			p_ltl_win_sp = ?,
			p_ltl_place_lp = ?,
			p_ltl_place_sp = ?,
			p_ltl_win_ep = ?,
			p_ltl_place_ep = ?,
			p_max_multiple_bet = ?,
			p_track_code = ?,
			p_bir_delay = ?
		)
	}

	set bad 0
	set type_id [reqGetArg TypeId]
	set stmt    [inf_prep_sql $::DB $sql]

	#do linked ev type stuff
	set linked_ev_type_id [reqGetArg LinkedEventTypeId]

	set bir_delay [reqGetArg TypeBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_type
			return
		}
	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_type
			return
		}
	}

	if {[catch {

		inf_begin_tran $::DB

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			[reqGetArg TypeId]\
			[reqGetArg TypeName]\
			[reqGetArg TypeStatus]\
			[reqGetArg TypeExtKey]\
			[reqGetArg TypeMaxPayout]\
			[reqGetArg TypeTaxRate]\
			[reqGetArg TypeDisplayed]\
			[reqGetArg TypeDisporder]\
			[reqGetArg TypeAsyncBetting]\
			[reqGetArg TypeRegion]\
			$linked_ev_type_id\
			[reqGetArg TypeURL]\
			[reqGetArg TypeBlurb]\
			[reqGetArg TypeEvMinBet]\
			[reqGetArg TypeEvMaxBet]\
			[reqGetArg TypeSpMaxBet]\
			[reqGetArg TypeEpMaxBet]\
			[reqGetArg TypeFCMaxBet]\
			[reqGetArg TypeFCMaxPayout]\
			[reqGetArg TypeTCMaxBet]\
			[reqGetArg TypeTCMaxPayout]\
			[make_channel_str]\
			[reqGetArg TypeFastkey]\
			[make_language_str]\
			[make_flag_str]\
			[reqGetArg TypeCouponSort]\
			[reqGetArg TypeEvMaxPotWin]\
			[reqGetArg TypeEvEachWayFactor]\
			[reqGetArg TypeLaytoLose1]\
			[reqGetArg TypeLaytoLose2]\
			[reqGetArg TypeLaytoLose3]\
			[reqGetArg TypeLaytoLose4]\
			[reqGetArg TypeLaytoLose5]\
			[reqGetArg TypeLaytoLose6]\
			[reqGetArg TypeMaxMultipleBet]\
			[reqGetArg TypeForm2Map]\
			$bir_delay]

		inf_close_stmt $stmt
		catch {db_close $res}

	} msg]} {
		err_bind $msg
		set bad 1
	}


	# Update Type views
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad !=1} {
		set upd_view [ADMIN::VIEWS::upd_view TYPE $type_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_type
		return
	}

	inf_commit_tran $::DB

	tpSetVar TypeUpdated 1

	ADMIN::CLASS::go_class
}

proc do_type_del args {

	set sql [subst {
		execute procedure pDelEvType(
			p_adminuser = ?,
			p_ev_type_id = ?
		)
	}]

	set bad 0
	set type_id [reqGetArg TypeId]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			$type_id]} msg]} {
		err_bind $msg
		set bad 1
	}
	inf_close_stmt $stmt
	catch {db_close $res}


	# Delete views for Event Class
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set del_view [ADMIN::VIEWS::del_view TYPE $type_id]
		if {[lindex $del_view 0]} {
			err_bind [lindex $del_view 1]
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
		go_type
		return
	}

	ADMIN::CLASS::go_class
}


#
# ----------------------------------------------------------------------------
# creates comma separated list of flags (for inserting into db) from form data
# ----------------------------------------------------------------------------
#
proc make_flag_str {{prefix TYPETAG_}} {

	set res [list]

	foreach {c} [OT_CfgGet TYPE_FLAGS ""] {
		set fl [lindex $c 0]
		if {[reqGetArg ${prefix}$fl] != ""} {
			lappend res $fl
		}
	}

	return [join $res ,]
}

# Creates a new event type by copying the structure of an existing type.
# Copies across all the markets for the event type.
proc do_type_clone args {

	global USERID

	# Check permissions
	if {![op_allowed "ManageEvType"]} {
		err_bind "You don't have permission to copy event types"
		ADMIN::TYPE::go_type
		return
	}

	set new_name    [reqGetArg newTypeName]
	set ev_type_id  [reqGetArg TypeId]

	# Use the clone_row functionality to copy event type.
	# Initialise new columns for the name, user ID and cr_date
  # Support 46980 : this used to pass "CURRENT" as the cr_date value,
  # which would then be interpreted as a string, and break.
  # passing null, so the col is ignored by clone_row, and defaulted
  # to CURRENT (as per the market copying).
	set additional_cols_type [list  name\
					user_id\
					cr_date]
	set additional_vals_type [list "$new_name" \
					$USERID\
					null]

	ADMIN::CLONE_ROW::reset_additionnal_values tevtype $additional_cols_type $additional_vals_type

	if { [ catch { ADMIN::CLONE_ROW::clone_row tevtype $ev_type_id }  msg ] } {
		err_bind $msg
	}

	ADMIN::CLASS::go_class
}

proc do_type_reset_oc_grp args {

	set ev_type_id  [reqGetArg TypeId]

	set sql [subst {
		update
			tEvOcGrp
		set
			bir_delay = null
		where
			ev_type_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	inf_exec_stmt $stmt $ev_type_id
	inf_close_stmt $stmt

	msg_bind "All event outcome groups for this type have been updated"

	go_type  $args
}

}
