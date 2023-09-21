# ==============================================================
# $Id: views.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::VIEWS {

asSetAct ADMIN::VIEWS::GoViewList        [namespace code go_view_list]
asSetAct ADMIN::VIEWS::GoView            [namespace code go_view]
asSetAct ADMIN::VIEWS::DoView            [namespace code do_view]
asSetAct ADMIN::VIEWS::DoAddClone        [namespace code do_add_clone]
asSetAct ADMIN::VIEWS::GoUpdViews        [namespace code go_upd_views]
asSetAct ADMIN::VIEWS::DoInsView         [namespace code do_ins_view]
asSetAct ADMIN::VIEWS::DoDelView         [namespace code do_del_view]
asSetAct ADMIN::VIEWS::GoViewDisporders  [namespace code go_view_disporders]
asSetAct ADMIN::VIEWS::DoViewDisporders  [namespace code do_view_disporders]

# Setup SQL that is available for this namespace
variable SQL
variable VIEW

set SQL(get_all_viewtypes) {
	select
		view,
		name,
		desc,
		status
	from
		tViewType
	order by
		view
}

set SQL(get_viewtype) {
	select
		view,
		name,
		desc,
		status
	from
		tViewType
	where
		view = ?
}

set SQL(upd_viewtype) {
	update
		tViewType
	set
		name = ?,
		desc = ?,
		status = ?
	where
		view = ?
}

set SQL(ins_viewtype) {
	insert into
		tViewType (
			view,
			name,
			desc,
			status
		)
	values (?,?,?,?)
}

set SQL(del_viewtype) {
	execute procedure pDelView (
		p_adminuser = ?,
		p_view = ?
	)
}

set SQL(clone_view_disporder) {
	execute procedure pCloneViewDispOrders(
		p_adminuser = ?,
		p_root_view = ?,
		p_new_view = ?
	)
}

set SQL(clone_view_region) {
	execute procedure pCloneViewRegion (
		p_adminuser = ?,
		p_root_view = ?,
		p_new_view = ?
	)
}

set SQL(clone_view_display_config) {
	execute procedure pCloneViewDisplayConfig (
		p_adminuser = ?,
		p_root_view = ?,
		p_new_view = ?
	)
}

set SQL(get_view_disporders) {
	select
		t.name,
		t.view,
		v.disporder
	from
		tViewType t,
		outer tView v
	where
		v.sort = ?
		and v.id = ?
		and v.view = t.view
	order by t.name
}

set SQL(get_true_view_disporders) {
	select
		v.view,
		v.disporder
	from
		tView v
	where
		v.sort = ?
		and v.id = ?
}

set SQL(ins_view) {
	insert into
	tview (sort,id,view)
	values(?,?,?)
}

set SQL(upd_view_disporders) {
	update tview
	set    disporder = ?
	where  sort = ?
	and    id = ?
	and    view = ?
}

set SQL(ins_view_disporders) {
	insert into
		tview (disporder, sort, id, view)
	values (?,?,?,?)
}

set SQL(del_view_disporder) {
	delete from
		tview
	where
		id = ?
		and sort = ?
		and view = ?
}

set SQL(del_view_all) {
	delete
	from tView
	where
		sort = ?
	and id   = ?
}

set SQL(get_view) {
	select
		t.name,
		v.view,
		v.disporder
	from
		tView v,
		tViewType t
	where
		v.sort = ?
	and v.id   = ?
	and v.view = t.view
	order by v.disporder
}


# ----------------------------------------------------------------------------
# Procedure :   go_view_list
# Description : display a matrix of views against languages.
# ----------------------------------------------------------------------------
proc go_view_list args {

	global DB
	variable VIEW

	_bind_views

	asPlayFile -nocache view_list.html

}


#
# ----------------------------------------------------------------------------
# Go to single view add/update
# ----------------------------------------------------------------------------
#
proc go_view args {

	global DB
	variable SQL

	set view [reqGetArg ViewId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ViewId $view

	if {$view == ""} {

		if {![op_allowed ManageView]} {
			err_bind "You do not have permission to update view information"
			go_view_list
			return
		}

		tpBindString ViewId            ""
		tpBindString ViewName          ""
		tpBindString ViewDesc          ""
		tpBindString ViewStatus        "A"

		_bind_views $view

		tpSetVar opAdd 1

	} else {

		#
		# Get view information
		#


		set stmt [inf_prep_sql $DB $SQL(get_viewtype)]
		set res  [inf_exec_stmt $stmt $view]
		inf_close_stmt $stmt

		tpBindString ViewId            $view
		tpBindString ViewName          [db_get_col $res 0 name]
		tpBindString ViewDesc          [db_get_col $res 0 desc]
		tpBindString ViewStatus        [db_get_col $res 0 status]

		db_close $res

		tpSetVar opAdd 0

	}

	asPlayFile -nocache view.html
}



#
# ----------------------------------------------------------------------------
# Do view insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_view args {

	global DB USERNAME
	variable SQL

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_view_list
		return
	}

	if {![op_allowed ManageView]} {
		err_bind "You do not have permission to update view information"
		go_view_list
		return
	}

	set upd_error 0

	if {($act != "ViewUpd") && ($act != "ViewDel")} {

		err_bind "unexpected SubmitName: $act"
	}

	if {$act == "ViewUpd"} {

		set stmt [inf_prep_sql $DB $SQL(upd_viewtype)]

		if {[catch {set res [inf_exec_stmt $stmt\
			[reqGetArg ViewName]\
			[reqGetArg ViewDesc]\
			[reqGetArg ViewStatus]\
			[reqGetArg ViewId]\
			]} msg]} {
				err_bind $msg
				set upd_error 1
		}

		catch {db_close $res}
		inf_close_stmt $stmt

	} elseif {$act == "ViewDel"} {
		set stmt [inf_prep_sql $DB $SQL(del_viewtype)]

		if {[catch {set res [inf_exec_stmt $stmt\
				$USERNAME\
				[reqGetArg ViewId]\
			]} msg]} {
				err_bind $msg
				set upd_error 1
		}

		catch {db_close $res}
		inf_close_stmt $stmt

	}

	if {$upd_error} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_view
		return
	}

	go_view_list
}

# ----------------------------------------------------------------------------
# Procedure :  go_view_disporders
# Description :Display the current display orders for the available views
# cr_date:     6/26/2002
# ----------------------------------------------------------------------------
proc go_view_disporders {} {
	global DB VIEWDISP
	variable SQL

	set id         [reqGetArg id]
	set sort       [reqGetArg sort]
	regsub -all {\|} [reqGetArg name] "" name

	set view_stmt  [inf_prep_sql $DB $SQL(get_view_disporders)]
	set view_rs    [inf_exec_stmt $view_stmt $sort $id]
	inf_close_stmt $view_stmt

	for {set i 0} {$i < [db_get_nrows $view_rs]} {incr i} {
		set VIEWDISP($i,view_name) [db_get_col $view_rs $i name]
		set VIEWDISP($i,view_code) [db_get_col $view_rs $i view]
		set VIEWDISP($i,disporder) [db_get_col $view_rs $i disporder]
	}

	set VIEWDISP(num_views) [db_get_nrows $view_rs]

	tpBindVar    view_name  VIEWDISP view_name view_idx
	tpBindVar    view_code  VIEWDISP view_code view_idx
	tpBindVar    disporder  VIEWDISP disporder view_idx

	tpBindString name  $name
	tpBindString id    $id
	tpBindString sort  $sort

	asPlayFile -nocache view_disporders.html
	catch {db_close $view_rs}
}

# ----------------------------------------------------------------------------
# Procedure :  do_view_disporders
# Description :
# cr_date:     6/26/2002
# ----------------------------------------------------------------------------
proc do_view_disporders {} {

	global DB VIEWDISP
	variable SQL

	set id         [reqGetArg id]
	set sort       [reqGetArg sort]

	set view_stmt  [inf_prep_sql $DB $SQL(get_all_viewtypes)]
	set view_rs    [inf_exec_stmt $view_stmt]
	inf_close_stmt $view_stmt

	set nrows [db_get_nrows $view_rs]

	set view_list [list]

	for {set i 0} {$i < [db_get_nrows $view_rs]} {incr i} {
		set view [db_get_col $view_rs $i view]
		set view_disp [list]
		lappend view_disp $view
		lappend view_disp [reqGetArg "view_${view}"]
	  	lappend view_list $view_disp
	}

	set upd_disporders [upd_view_disporders $id $sort view_list]
	if {[lindex $upd_disporders 0]} {
		err_bind [lindex $upd_disporders 1]
	} else {
		msg_bind "Successfully Updated View Display Orders"
	}
	go_view_disporders
}

# ----------------------------------------------------------------------------
# Procedure :  upd_view_disporders
# Description :
# cr_date:     6/26/2002
# ----------------------------------------------------------------------------
proc upd_view_disporders {id sort LIST_IN} {

	global DB
	variable SQL
	upvar 1 $LIST_IN view_list

	set stmt_upd [inf_prep_sql $DB $SQL(upd_view_disporders)]
	set stmt_ins [inf_prep_sql $DB $SQL(ins_view_disporders)]
	set stmt_del [inf_prep_sql $DB $SQL(del_view_disporder)]
	set view_stmt [inf_prep_sql $DB $SQL(get_true_view_disporders)]

	set views_rs [inf_exec_stmt $view_stmt $sort $id]
	set nrows [db_get_nrows $views_rs]

	array set DISPORDERS [list]

	for {set r 0} {$r < $nrows} {incr r} {
		set view      [db_get_col $views_rs $r view]
		set disporder [db_get_col $views_rs $r disporder]

		set DISPORDERS($view) $disporder
	}

	foreach v $view_list {

		set view      [lindex $v 0]
		set disporder [lindex $v 1]

		# update/insert
		if {[info exists DISPORDERS($view)]} {
			if {$disporder == ""} {
				if {[catch {set rs [inf_exec_stmt $stmt_del $id $sort $view]} msg]} {
					return [list 1 $msg]
					break
				}
				db_close $rs
			} elseif {$DISPORDERS($view) != $disporder} {
				if {[catch {set rs [inf_exec_stmt $stmt_upd $disporder $sort $id $view]} msg]} {
					return [list 1 $msg]
					break
				}
				db_close $rs
			}
		} else {
			if {$disporder != ""} {
				if {[catch {set rs [inf_exec_stmt $stmt_ins $disporder $sort $id $view]} msg]} {
					return [list 1 $msg]
					break
				}
				db_close $rs
			}
		}
	}

	inf_close_stmt $view_stmt
	inf_close_stmt $stmt_upd
	inf_close_stmt $stmt_ins
	inf_close_stmt $stmt_del

	return [list 0 OK]
}



# ----------------------------------------------------------------------------
# Procedure :  upd_view
# Description :Build two lists, one will contain those views that need to be deleted
#              the other list will contain a list of those views that need to be inserted
#              selected views for each language
# ----------------------------------------------------------------------------
proc upd_view {sort id} {
	global DB
	variable SQL

	if {![op_allowed ManageView]} {
		return [list 1 "You don't have permission to update views"]
	}

	set del_list  [list]
	set view_list [make_view_str]

	set stmt [inf_prep_sql $DB $SQL(get_view)]
	if [catch {set rs [inf_exec_stmt $stmt $sort $id]} msg] {
		return [list 1 $msg]
	} else {
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			# Test to see if view is in the view_list (from form)
			set view [db_get_col $rs $i view]
			if {[set j [lsearch -exact $view_list $view]] != -1} {
				set view_list [lreplace $view_list $j $j]
			} else {
				lappend del_list $view
			}

		}
		# delete all views that are in the del_list
		set stmt [inf_prep_sql $DB $SQL(del_view_disporder)]
		foreach d $del_list {
			if [catch {set rs [inf_exec_stmt $stmt $id $sort $d]} msg] {
				return [list 1 $msg]
				break
			}
		}

		# Insert all views that are left in the view_list
		set stmt [inf_prep_sql $DB $SQL(ins_view)]
		foreach v $view_list {
			if [catch {set rs [inf_exec_stmt $stmt $sort $id $v]} msg] {
				return [list 1 $msg]
				break
			}
		}
	}
	return [list 0 OK]
}

# ----------------------------------------------------------------------------
# Procedure :  del_view
# Description :Delete views from tview
# ----------------------------------------------------------------------------
proc del_view {sort id} {
	global DB
	variable SQL

	if {![op_allowed ManageView]} {
		err_bind "You don't have permission to delete views"
		return
	}

	set stmt [inf_prep_sql $DB  $SQL(del_view_all)]
	if {[catch {
		set res [inf_exec_stmt $stmt $sort $id]} msg]} {
		return [list 1 $msg]
	}

	inf_close_stmt $stmt
	catch {db_close $res}
	return [list 0 OK]
}



# Private procedures

proc _bind_views args {

	global DB
	variable SQL
	variable VIEW

	if { $args != ""} {
		set current_view $args
	} else {
		set current_view "\'\'"
	}

	set stmt [inf_prep_sql $DB $SQL(get_all_viewtypes)]
	set res_list  [inf_exec_stmt $stmt $current_view]
	inf_close_stmt $stmt

	set VIEW(num) [db_get_nrows $res_list]

	for {set i 0} {$i < $VIEW(num)} {incr i} {
		set VIEW($i,view)      [db_get_col $res_list $i view]
		set VIEW($i,name)      [db_get_col $res_list $i name]
		set VIEW($i,desc)      [db_get_col $res_list $i desc]
		set VIEW($i,status)    [db_get_col $res_list $i status]
	}
	catch {db_close $res_list}

	tpSetVar NumViews $VIEW(num)

	tpBindVar ViewId        ADMIN::VIEWS::VIEW view      view_idx
	tpBindVar ViewName      ADMIN::VIEWS::VIEW name      view_idx
	tpBindVar ViewDesc      ADMIN::VIEWS::VIEW desc      view_idx
	tpBindVar ViewStatus    ADMIN::VIEWS::VIEW status    view_idx

}


proc do_add_clone args {

	global DB USERNAME
	variable SQL

	set do_action [reqGetArg do_action]
	set root_view [reqGetArg root_view]
	set new_view  [reqGetArg new_view]

	set err ""

	tpBufAddHdr "Content-Type" "text/html"
	switch $do_action {
		ViewAdd {

			set stmt [inf_prep_sql $DB $SQL(ins_viewtype)]

			if {[catch {set res [inf_exec_stmt $stmt\
				[reqGetArg ViewId]\
				[reqGetArg ViewName]\
				[reqGetArg ViewDesc]\
				[reqGetArg ViewStatus]\
				]} msg]} {
					err_bind $msg
					set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "ViewAdd|1|$err"
		}
		CloneViewDispOrder {

			set stmt [inf_prep_sql $DB $SQL(clone_view_disporder)]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$root_view\
					$new_view]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneViewDispOrder|1|$err"

		}
		CloneViewRegion {

			set stmt [inf_prep_sql $DB $SQL(clone_view_region)]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$root_view\
					$new_view]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneViewRegion|1|$err"

		}
		CloneViewDislayConfig {

			set stmt [inf_prep_sql $DB $SQL(clone_view_display_config)]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$root_view\
					$new_view]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneViewDislayConfig|1|$err"

		}
	}

}

}
