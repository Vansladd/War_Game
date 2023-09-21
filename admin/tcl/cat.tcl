# ==============================================================
# $Id: cat.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CATEGORY {

asSetAct ADMIN::CATEGORY::GoCategory [namespace code go_category]
asSetAct ADMIN::CATEGORY::DoCategory [namespace code do_category]

#
# ----------------------------------------------------------------------------
# Go to category list
# ----------------------------------------------------------------------------
#
proc go_category_list args {

	global DB BF_MTCH

	set sql {
		select
			category
		from
			tEvCategory
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	tpSetVar NumCats $rows

	tpBindTcl Category sb_res_data $res cat_idx category

	# Check whether it is allowed to insert or delete categories.
	# When allow_dd_creation is set to Y, it enables the creating and
	# deleting of any dilldown items. Such as categories, classes
	# types and markets.
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	if {[OT_CfgGet BF_ACTIVE 0]} {
		ADMIN::BETFAIR_CAT::bind_bf_category_list
	}

	asPlayFile -nocache cat_list.html

	db_close $res
	
	catch {unset BF_MTCH}
}

proc go_category args {

	global DB

	set cat [reqGetArg Category]

	foreach {n v} $args {
		set $n $v
	}

	if {$cat == ""} {
		tpSetVar opAdd 1
	} else {
		tpBindString Category $cat
		tpSetVar opAdd 0

		set sql {
			select
				name,
				displayed,
				disporder,
				commentary_ver,
				bir_delay
			from
				tEvCategory,
				outer tComSport
			where
				category       = ?     and
				ev_category_id = ob_id and
				ob_level       = 'Y'
		}

		set stmt    [inf_prep_sql $DB $sql]
		if {![catch {set res_cat [inf_exec_stmt $stmt $cat]}] } {
			inf_close_stmt $stmt

			tpBindString Name      [db_get_col $res_cat 0 name]
			tpBindString Displayed [db_get_col $res_cat 0 displayed]
			tpBindString Disporder [db_get_col $res_cat 0 disporder]
			tpBindString Commentary [db_get_col $res_cat 0 commentary_ver]
			tpBindString BIRDelay  [db_get_col $res_cat 0 bir_delay]
		} else {
			tpBindString Name       [reqGetArg Name]
			tpBindString Displayed  [reqGetArg Displayed]
			tpBindString Disporder  [reqGetArg Disporder]
			tpBindString Commentary [reqGetArg commentary]
			tpBindString BIRDelay   [reqGetArg CatBirDelay]
		} 
		# Check whether it is allowed to delete categories.
		if {[ob_control::get allow_dd_deletion] == "Y"} {
			tpSetVar AllowDDDeletion 1
		} else {
			tpSetVar AllowDDDeletion 0
		}
		db_close $res_cat
	}

	asPlayFile -nocache cat.html
}


#
# ----------------------------------------------------------------------------
# Update category
# ----------------------------------------------------------------------------
#
proc do_category args {

	set act [reqGetArg SubmitName]

	if {$act == "CatAdd"} {
		do_cat_add
	} elseif {$act == "CatMod"} {
		do_cat_upd
	} elseif {$act == "CatDel"} {
		do_cat_del
	} elseif {$act == "Back"} {
		go_category_list
	} elseif {$act == "CatBFRefresh"} {
		ADMIN::BETFAIR_CAT::go_category_bf_refresh	
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_cat_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsEvCategory (
			p_adminuser = ?,
			p_category = ?,
			p_name     = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_bir_delay = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	set category   [reqGetArg Category]
	set commentary [reqGetArg commentary]
	set bir_delay  [reqGetArg CatBirDelay]

	if {$bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
		err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_category
		return
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$category\
			[reqGetArg Name]\
			[reqGetArg Displayed]\
			[reqGetArg Disporder]\
			[reqGetArg CatBirDelay]]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_category
		return
	}

	if {$commentary != ""} {
		# Add the commentary version
		set sql {
			execute procedure pUpdComSport (
				p_ob_id          = (select ev_category_id from tEvCategory where category = ?),
				p_ob_level       = 'Y',
				p_commentary_ver = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt $category $commentary} msg]} {
			err_bind $msg
		}
		inf_close_stmt $stmt
	}
	go_category_list
}

proc do_cat_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdEvCategory (
			p_adminuser = ?,
			p_category = ?,
			p_name = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_bir_delay = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	set category   [reqGetArg Category]
	set commentary [reqGetArg commentary]
	set bir_delay  [reqGetArg CatBirDelay]

	if {$bir_delay < [OT_CfgGet MIN_BIR_DELAY 1] || $bir_delay > [OT_CfgGet MAX_BIR_DELAY 30]} {
		err_bind "BIR delay value must be between [OT_CfgGet MIN_BIR_DELAY 1] and [OT_CfgGet MAX_BIR_DELAY 30]"
		go_category
		return
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$category\
			[reqGetArg Name]\
			[reqGetArg Displayed]\
			[reqGetArg Disporder]\
			$bir_delay]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_category
		return
	}

	if {$commentary != ""} {
		# Update the commentary version
		set sql {
			execute procedure pUpdComSport (
				p_ob_id          = (select ev_category_id from tEvCategory where category = ?),
				p_ob_level       = 'Y',
				p_commentary_ver = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt $category $commentary} msg]} {
			err_bind $msg
		}
	} else {
		# Delete the commentary version
		set sql {
			execute procedure pDelComSport (
				p_ob_id          = (select ev_category_id from tEvCategory where category = ?),
				p_ob_level       = 'Y'
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt $category} msg]} {
			err_bind $msg
		}
	}
	inf_close_stmt $stmt

	go_category_list
}

proc do_cat_del args {

	global DB USERNAME

	set category   [reqGetArg Category]

	# Delete the commentary version
	set sql {
		execute procedure pDelComSport (
			p_ob_id          = (select ev_category_id from tEvCategory where category = ?),
			p_ob_level       = 'Y'
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $category} msg]} {
		err_bind $msg
	}
	inf_close_stmt $stmt

	set sql [subst {
		execute procedure pDelEvCategory(
			p_adminuser = ?,
			p_category = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$category]} msg]} {
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
		go_category
		return
	}

	go_category_list
}

}
