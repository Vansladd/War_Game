# ==============================================================
# $Id: class.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CLASS {

asSetAct ADMIN::CLASS::GoClassList [namespace code go_class_list]
asSetAct ADMIN::CLASS::GoClass     [namespace code go_class]
asSetAct ADMIN::CLASS::DoClass     [namespace code do_class]

#
# ----------------------------------------------------------------------------
# Generate top-level list of event classes
# ----------------------------------------------------------------------------
#
proc go_class_list args {

	set sql [subst {
		select
			ev_class_id,
			name,
			category,
			disporder,
			displayed,
			status,
			channels,
			flags,
			fastkey,
			languages
		from
			tEvClass
		order by
			displayed desc, disporder asc, name asc
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumClasses $rows

	tpBindTcl Status      sb_res_data $res class_idx status
	tpBindTcl Displayed   sb_res_data $res class_idx displayed
	tpBindTcl Disporder   sb_res_data $res class_idx disporder
	tpBindTcl Category    sb_res_data $res class_idx category
	tpBindTcl ClassId     sb_res_data $res class_idx ev_class_id
	tpBindTcl ClassName   sb_res_data $res class_idx name
	tpBindTcl Channels    sb_res_data $res class_idx channels
	tpBindTcl Flags       sb_res_data $res class_idx flags
	tpBindTcl Fastkey     sb_res_data $res class_idx fastkey
	tpBindTcl Languages   sb_res_data $res class_idx languages

	# Check whether it is allowed to insert or delete classes.
	# When allow_dd_creation is set to Y, it enables the creating and
	# deleting of any dilldown items. Such as categories, classes
	# types and markets.
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile class_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to class page - two activators, one with a class id, one without
# ----------------------------------------------------------------------------
#
proc go_class args {

	global CHANNEL_MAP CLSORT BFEVTYPES

	if {[reqGetArg SubmitName] == "CatEdit"} {
		ADMIN::CATEGORY::go_category_list
		return
	}

	set class_id [reqGetArg ClassId]

	foreach {n v} $args {
		set $n $v
	}

	set sql [subst {
		select
			category
		from
			tEvCategory
		order by
			1 asc
	}]

	set stmt    [inf_prep_sql $::DB $sql]
	set res_cat [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCats [db_get_nrows $res_cat]

	tpBindTcl Category sb_res_data $res_cat cat_idx category

	array set CLSORT [list]

	set num_sorts 0

	foreach {s n}  [ADMIN::MKTPROPS::class_sorts] {
		set CLSORT($num_sorts,sort) $s
		set CLSORT($num_sorts,name) $n
		incr num_sorts
	}

	tpSetVar NumSorts $num_sorts

	tpBindVar SortCode CLSORT sort sort_idx
	tpBindVar SortName CLSORT name sort_idx

	if {[OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToClass]} {
		ADMIN::BETFAIR_ACCT::bind_bf_accounts
	}

	if {$class_id == ""} {

		tpSetVar opAdd 1

		make_channel_binds  "" - 1
		make_language_binds "" - 1
		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			make_view_binds "" - 1
		}

		tpBindString FcStkFactor [OT_CfgGet DFLT_FC_STAKE_FACTOR]
		tpBindString TcStkFactor [OT_CfgGet DFLT_TC_STAKE_FACTOR]

	} else {

		tpBindString ClassId $class_id

		tpSetVar opAdd 0

		#
		# Get class information
		#
		set sql [subst {
			select
				cl.ev_class_id,
				cl.category,
				cl.name,
				cl.status,
				cl.disporder,
				cl.displayed,
				cl.url,
				cl.sort,
				cl.async_betting,
				cl.blurb,
				cl.languages,
				cl.channels,
				cl.flags,
				cl.fastkey,
				cl.fc_stk_factor,
				cl.tc_stk_factor,
				cl.fc_min_stk_limit,
				cl.tc_min_stk_limit,
				cs.commentary_ver,
				cl.bir_delay as bir_delay,
				pGetHierarchyBIRDelayLevel ("CLASS", ?) as bir_hierarchy,
				pGetHierarchyBIRDelay ("CLASS", ?) as bir_hierarchy_value
			from
				tEvClass cl,
				outer tComSport cs
			where
				cl.ev_class_id = ?           and
				cl.ev_class_id = cs.ob_id    and
				cs.ob_level    = 'C'
		}]

		set stmt      [inf_prep_sql $::DB $sql]
		set res_class [inf_exec_stmt $stmt $class_id $class_id $class_id]
		inf_close_stmt $stmt

		set bir_delay     [db_get_col $res_class 0 bir_delay]
		set bir_hierarchy [db_get_col $res_class 0 bir_hierarchy]

		tpBindString ClassCategory [db_get_col $res_class 0 category]
		tpBindString ClassName     [db_get_col $res_class 0 name]
		tpBindString Status        [db_get_col $res_class 0 status]
		tpBindString Disporder     [db_get_col $res_class 0 disporder]
		tpBindString Displayed     [db_get_col $res_class 0 displayed]
		tpBindString URL           [db_get_col $res_class 0 url]
		tpBindString Sort          [db_get_col $res_class 0 sort]
		tpBindString AsyncBetting  [db_get_col $res_class 0 async_betting]
		tpBindString Blurb         [db_get_col $res_class 0 blurb]
		tpBindString Fastkey       [db_get_col $res_class 0 fastkey]
		tpBindString FcStkFactor   [db_get_col $res_class 0 fc_stk_factor]
		tpBindString TcStkFactor   [db_get_col $res_class 0 tc_stk_factor]
		tpBindString FcMinStk      [db_get_col $res_class 0 fc_min_stk_limit]
		tpBindString TcMinStk      [db_get_col $res_class 0 tc_min_stk_limit]
		tpBindString ClassSort	   [db_get_col $res_class 0 sort]
		tpBindString Commentary    [db_get_col $res_class 0 commentary_ver]

		if {$bir_delay == "" && $bir_hierarchy != ""} {
			tpSetVar displayBIRHierarchy 1
			tpBindString BIRHierarchy     $bir_hierarchy
			tpBindString BIRHierarchyVal  [db_get_col $res_class 0 bir_hierarchy_value]
		}
		tpBindString BIRDelay         $bir_delay

		make_channel_binds  [db_get_col $res_class 0 channels] -
		make_language_binds [db_get_col $res_class 0 languages] -

		db_close $res_class

		if {[OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToClass]} {
			ADMIN::BETFAIR_ACCT::get_mapped_bf_acct $class_id "class"
		}

		if {[OT_CfgGet FUNC_VIEWS 0]} {
			#
			# Build up the View array
			#
			set sql [subst {
				select
					view
				from
					tView
				where
					id   = ? and sort = ?
			}]

			set stmt [inf_prep_sql $::DB $sql]
			set rs   [inf_exec_stmt $stmt $class_id CLASS]
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
				select
					distinct name
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
			set rs   [inf_exec_stmt $stmt $class_id CLASS]
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

		#
		# Get type information
		#

		set order_by "disporder"

		if {[OT_CfgGet BF_ACTIVE 0] == 0 || [OT_CfgGet BF_AUTO_MATCH 0] == 0} {

			set sql [subst {
				select
					ev_type_id,
					name,
					disporder,
					displayed,
					status,
					languages,
					channels,
					fastkey
				from
					tEvType
				where
					ev_class_id = ?
				order by
					$order_by
			}]

			set stmt      [inf_prep_sql $::DB $sql]
			set res_type  [inf_exec_stmt $stmt $class_id]
			inf_close_stmt $stmt

			tpSetVar NumTypes [db_get_nrows $res_type]

			tpBindTcl TypeId        sb_res_data $res_type type_idx ev_type_id
			tpBindTcl TypeName      sb_res_data $res_type type_idx name
			tpBindTcl TypeStatus    sb_res_data $res_type type_idx status
			tpBindTcl TypeDisporder sb_res_data $res_type type_idx disporder
			tpBindTcl TypeDisplayed sb_res_data $res_type type_idx displayed
			tpBindTcl TypeChannels  sb_res_data $res_type type_idx channels
			tpBindTcl TypeFastkey   sb_res_data $res_type type_idx fastkey
			tpBindTcl TypeLangs     sb_res_data $res_type type_idx languages
		}

		if {[OT_CfgGet BF_ACTIVE 0]} {
			ADMIN::BETFAIR_TYPE::bind_bf_type_match_info $class_id $order_by
		}

	}

	bind_class_flags $class_id


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

	asPlayFile class.html

	unset CLSORT
	catch {unset BFEVTYPES}
	catch {unset BFEVS}

	if {$class_id != ""} {
		if {[OT_CfgGet BF_ACTIVE 0] == 0 || [OT_CfgGet BF_AUTO_MATCH 0]==0} {
			db_close $res_type
		}
	}
	db_close $res_cat
}


proc bind_class_flags {{ev_class_id ""}} {

	global CLSFLAG

	if {$ev_class_id != ""} {
		set sql [subst {
			select
				flags
			from
				tEvClass
			where
				ev_class_id = $ev_class_id
			order by
				1 asc
		}]

		set stmt    [inf_prep_sql $::DB $sql]
		set res     [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set tag_used [split [db_get_col $res 0 flags] ,]

	} else {

		set tag_used ""
	}

	catch {db_close $res}

	set i 0

	foreach {t n} [OT_CfgGet CLASS_FLAGS ""] {
		set CLSFLAG($i,code) $t
		set CLSFLAG($i,name) $n

		if {[lsearch -exact $tag_used $t] >= 0} {
			set CLSFLAG($i,selected) CHECKED
		} else {
			set CLSFLAG($i,selected) ""
		}
		incr i
	}

	tpSetVar NumClsFlags $i

	tpBindVar ClsFlagName  CLSFLAG name     ev_tag_idx
	tpBindVar ClsFlagCode  CLSFLAG code     ev_tag_idx
	tpBindVar ClsFlagSel   CLSFLAG selected ev_tag_idx

}


# modified version of proc make_ev_tag_str in event.tcl
proc make_cls_flag_str {{prefix ClsFlag_}} {

	set res [list]

	foreach {t n} [OT_CfgGet CLASS_FLAGS ""] {
		if {[reqGetArg ${prefix}$t] != ""} {
			lappend res $t
		}
	}
	return [join $res ,]
}

#
# ----------------------------------------------------------------------------
# Add/Update/Delete class
# ----------------------------------------------------------------------------
#
proc do_class args {

	set act [reqGetArg SubmitName]

	if {$act == "ClassAdd"} {
		do_class_add
	} elseif {$act == "ClassMod"} {
		do_class_upd
	} elseif {$act == "ClassDel"} {
		do_class_del
	} elseif {$act == "Back"} {
		go_class_list
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_class_add args {

	set bad 0

	set sql [subst {
		execute procedure pInsEvClass(
			p_adminuser = ?,
			p_category = ?,
			p_name = ?,
			p_status = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_async_betting = ?,
			p_url = ?,
			p_sort = ?,
			p_blurb = ?,
			p_channels = ?,
			p_flags = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_fc_stk_factor = ?,
			p_tc_stk_factor = ?,
			p_fc_min_stk_limit = ?,
			p_tc_min_stk_limit = ?,
			p_bir_delay = ?
		)
	}]

	set stmt [inf_prep_sql $::DB $sql]

	set fc_stk_factor [reqGetArg fc_stk_factor]
	set tc_stk_factor [reqGetArg tc_stk_factor]

	set bir_delay [reqGetArg ClassBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_class
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_class
			return
		}

	}

	# attempt to insert new class
	if {[catch {

		inf_begin_tran $::DB

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			[reqGetArg Category]\
			[reqGetArg ClassName]\
			[reqGetArg Status]\
			[reqGetArg Displayed]\
			[reqGetArg Disporder]\
			[reqGetArg AsyncBetting]\
			[reqGetArg URL]\
			[reqGetArg Sort]\
			[reqGetArg Blurb]\
			[make_channel_str]\
			[make_cls_flag_str]\
			[reqGetArg Fastkey]\
			[make_language_str]\
			$fc_stk_factor\
			$tc_stk_factor\
			[reqGetArg fc_min_stk]\
			[reqGetArg tc_min_stk]\
			$bir_delay]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add class (no class_id retrieved)"
			set bad 1
		} else {
			set class_id [db_get_coln $res 0 0]
		}

		catch {db_close $res}

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad == 0} {
			set upd_view [ADMIN::VIEWS::upd_view CLASS $class_id]
			if {[lindex $upd_view 0]} {
				err_bind [lindex $upd_view 1]
				set bad 1
			}
		}

		if {$bad == 0 && [OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToClass]} {
			ADMIN::BETFAIR_ACCT::do_map_bf_class_to_account $class_id [reqGetArg BF_Account]
		}

		# Added for bf type filter option
		if {$bad == 0 && [OT_CfgGet BF_ACTIVE 0]} {
			ADMIN::BETFAIR_TYPE::do_bf_type_filter $class_id
		}

	} msg]} {
		set bad 1
		err_bind $msg
	}

	set commentary [reqGetArg commentary]

	if {$commentary != ""} {
		# Update the commentary version
		set sql {
			execute procedure pUpdComSport (
				p_ob_id          = ?,
				p_ob_level       = 'C',
				p_commentary_ver = ?
			)
		}

		set stmt [inf_prep_sql $::DB $sql]
		if {[catch {inf_exec_stmt $stmt $class_id $commentary} msg]} {
			err_bind $msg
		}
		inf_close_stmt $stmt
	}
	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar ClassAddFailed 1
		go_class
		return
	}

	inf_commit_tran $::DB

	tpSetVar ClassAdded 1

	go_class class_id $class_id
}

proc do_class_upd args {

	set bad      0
	set class_id [reqGetArg ClassId]

	set sql [subst {
		execute procedure pUpdEvClass(
			p_adminuser = ?,
			p_ev_class_id = ?,
			p_category = ?,
			p_name = ?,
			p_status = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_async_betting = ?,
			p_url = ?,
			p_sort = ?,
			p_blurb = ?,
			p_channels = ?,
			p_flags = ?,
			p_fastkey = ?,
			p_languages = ?,
			p_fc_stk_factor = ?,
			p_tc_stk_factor = ?,
			p_fc_min_stk_limit = ?,
			p_tc_min_stk_limit = ?,
			p_bir_delay = ?
		)
	}]

	set stmt [inf_prep_sql $::DB $sql]

	set bir_delay [reqGetArg ClassBirDelay]

	if {[OT_CfgGet FUNC_MIN_MAX_BIR_DELAY 0]} {

		if {$bir_delay != "" && $bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
			err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
			go_class
			return
		}

	} else {

		if {$bir_delay != "" && $bir_delay < 0 } {
			err_bind "BIR delay value cannot be less than 0"
			go_class
			return
		}

	}

	if {[catch {

		inf_begin_tran $::DB

		if {[reqGetArg LangChange] == 1} {
			ADMIN::LANG::upd_lang_disp C $class_id [reqGetArg LangDisporder]
		}

		if {[OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToClass]} {
			ADMIN::BETFAIR_ACCT::do_map_bf_class_to_account $class_id [reqGetArg BF_Account]
		}

		# Added for bf type filter option
		if {[OT_CfgGet BF_MANUAL_MATCH 0]} {
			ADMIN::BETFAIR_TYPE::do_bf_type_filter $class_id
		}

		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			[reqGetArg ClassId]\
			[reqGetArg Category]\
			[reqGetArg ClassName]\
			[reqGetArg Status]\
			[reqGetArg Displayed]\
			[reqGetArg Disporder]\
			[reqGetArg AsyncBetting]\
			[reqGetArg URL]\
			[reqGetArg Sort]\
			[reqGetArg Blurb]\
			[make_channel_str]\
			[make_cls_flag_str]\
			[reqGetArg Fastkey]\
			[make_language_str]\
			[reqGetArg fc_stk_factor]\
			[reqGetArg tc_stk_factor]\
			[reqGetArg fc_min_stk]\
   		    	[reqGetArg tc_min_stk]\
			$bir_delay]

		inf_close_stmt $stmt
		catch {db_close $res}

	} msg]} {
		err_bind $msg
		set bad 1
	}

	#
	# Update class views
	#
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad !=1} {
		set upd_view [ADMIN::VIEWS::upd_view CLASS $class_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	set commentary [reqGetArg commentary]

	if {$commentary != ""} {
		# Update the commentary version
		set sql {
			execute procedure pUpdComSport (
				p_ob_id          = ?,
				p_ob_level       = 'C',
				p_commentary_ver = ?
			)
		}

		set stmt [inf_prep_sql $::DB $sql]
		if {[catch {inf_exec_stmt $stmt $class_id $commentary} msg]} {
			err_bind $msg
		}
	} else {
		# Delete the commentary version
		set sql {
			execute procedure pDelComSport (
				p_ob_id          = ?,
				p_ob_level       = 'C'
			)
		}

		set stmt [inf_prep_sql $::DB $sql]
		if {[catch {inf_exec_stmt $stmt $class_id} msg]} {
			err_bind $msg
		}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $::DB

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	} else {
		inf_commit_tran $::DB

		tpSetVar ClassUpdated 1
	}

	go_class_list
}

proc do_class_del args {

	global DB
	set bad      0
	set class_id [reqGetArg ClassId]

	set category   [reqGetArg Category]

	# Delete the commentary version
	set sql {
		execute procedure pDelComSport (
			p_ob_id          = ?,
			p_ob_level       = 'C'
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $class_id} msg]} {
		err_bind $msg
	}
	inf_close_stmt $stmt


	set sql [subst {
		execute procedure pDelEvClass(
			p_adminuser = ?,
			p_ev_class_id = ?
		)
	}]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$::USERNAME\
			$class_id]} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	catch {db_close $res}

	#
	# Delete views for Event Class
	#
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set del_view [ADMIN::VIEWS::del_view CLASS $class_id]
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
		go_class
		return
	}

	go_class_list
}

}
