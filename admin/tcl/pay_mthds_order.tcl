# $Id: pay_mthds_order.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Admin screens to configure the ordering of payment method groups
# and payment methods in customer screen - deposit / withdrawal
#

namespace eval ADMIN::PMT_MTHD_ORDER {

asSetAct ADMIN::PMT_MTHD_ORDER::GoPayMthdViewSettings    [namespace code go_mthd_view_settings]
asSetAct ADMIN::PMT_MTHD_ORDER::DoViewCountries          [namespace code do_view_countries]
asSetAct ADMIN::PMT_MTHD_ORDER::GoViewDef                [namespace code go_view_def]
asSetAct ADMIN::PMT_MTHD_ORDER::GoGroupConstr            [namespace code go_group_constr]
asSetAct ADMIN::PMT_MTHD_ORDER::DoViewDef                [namespace code do_view_def]
asSetAct ADMIN::PMT_MTHD_ORDER::DoGroupConstr            [namespace code do_group_constr]
asSetAct ADMIN::PMT_MTHD_ORDER::GoConstr                 [namespace code go_constr]
asSetAct ADMIN::PMT_MTHD_ORDER::DoConstr                 [namespace code do_constr]
asSetAct ADMIN::PMT_MTHD_ORDER::GoView                   [namespace code go_view]
asSetAct ADMIN::PMT_MTHD_ORDER::GoPayMthdGrpAdd          [namespace code go_grp_add]
asSetAct ADMIN::PMT_MTHD_ORDER::GoPayMthdAdd             [namespace code go_pmthd_add]
asSetAct ADMIN::PMT_MTHD_ORDER::DoView                   [namespace code do_view]
asSetAct ADMIN::PMT_MTHD_ORDER::DoPayMthdUpdate          [namespace code do_mthd_upd]
asSetAct ADMIN::PMT_MTHD_ORDER::DoPayMthdGrpUpdate       [namespace code do_grp_upd]
asSetAct ADMIN::PMT_MTHD_ORDER::DoPayMthdDispCtrlUpdate  [namespace code do_disp_ctrl_upd]


proc go_mthd_view_settings {} {

	# Bind all views
	_bind_views

	# Bind Countries associated to views
	_bind_country_views

	# Bind all groups
	_bind_group_constr

	# Bind all pay mthd types
	_bind_pay_mthd_constr

	asPlayFile -nocache pay_mthds_order_splash.html
}


proc go_view_def {} {

	tpSetVar instance "VIEW_DEF"
	asPlayFile -nocache pay_mthd_instance.html
}


proc go_group_constr {} {

	global DB

	set grp_constr_id [reqGetArg grp_constr_id]

	if {$grp_constr_id != ""} {
		tpSetVar is_upd 1
		tpBindString GrpConstrId $grp_constr_id
		set sql {
			select
				group,
				group_name,
				type
			from
				tViewPMGroupConstr
			where
				view_grp_constr_id = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $grp_constr_id]

		if {[db_get_nrows $res]} {
			tpBindString Group     [db_get_col $res 0 group]
			tpBindString GroupName [db_get_col $res 0 group_name]
			tpBindString GroupType [db_get_col $res 0 type]
		}
		db_close $res
	} else {
		tpSetVar is_add 1
	}

	tpSetVar instance "GROUP_CONSTR"
	asPlayFile -nocache pay_mthd_instance.html
}


proc go_constr {} {

	global DB

	set constr_id [reqGetArg constr_id]

	if {$constr_id != ""} {
		tpSetVar is_upd 1
		tpBindString ConstrId $constr_id
		set sql {
			select
				pay_mthd,
				type,
				desc
			from
				tViewPMConstr
			where
				view_constr_id = ?
			order by 1,2
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $constr_id]

		if {[db_get_nrows $res]} {
			tpBindString PayMthd   [db_get_col $res 0 pay_mthd]
			tpBindString Type      [db_get_col $res 0 type]
			tpBindString Desc      [db_get_col $res 0 desc]
		}
		db_close $res
	} else {
		tpSetVar is_add 1
	}

	tpSetVar instance "CONSTR"
	asPlayFile -nocache pay_mthd_instance.html
}


proc go_view {} {

	set view_id [reqGetArg view_id]
	tpBindString ViewID $view_id

	# bind all views
	_bind_views $view_id

	# display control
	_bind_disp_ctrl $view_id

	# Bind group disporder
	_bind_group_disporders $view_id

	# Bind pay mthd disporder
	_bind_pay_mthd_disporders $view_id

	asPlayFile -nocache pay_mthds_order.html
}


proc go_grp_add {} {

	tpBindString ViewID [reqGetArg view_id]

	_bind_group_constr

	tpSetVar instance "GROUP"
	asPlayFile -nocache pay_mthd_instance.html
}


proc go_pmthd_add {} {

	tpBindString ViewID [reqGetArg view_id]

	_bind_group_constr
	_bind_pay_mthd_constr

	tpSetVar instance "METHOD"
	asPlayFile -nocache pay_mthd_instance.html
}


proc do_view_def {} {

	global DB

	set submit [reqGetArg SubmitName]

	if {$submit == "do_view_add"} {
		set name [reqGetArg view_name]

		if {$name == ""} {
			err_bind "Please provide a name"
			go_view_def
			return
		}

		set sql {
			insert into tViewPMDef(name) values (?)
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set rs      [inf_exec_stmt $stmt $name]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to add view : $msg"
			go_view_def
			return
		} else {
			msg_bind "View succesfully created"
			db_close $rs
			go_mthd_view_settings
			return
		}
	}

	if {$submit == "do_view_delete"} {
		set view_id [reqGetArg view_id]

		if {$view_id == ""} {
			err_bind "Invalid View"
			go_mthd_view_settings
			return
		}

		set sql {
			delete from tViewPMDef where view_id = ?
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set rs      [inf_exec_stmt $stmt $view_id]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to delete view : $msg"
		} else {
			msg_bind "View succesfully deleted"
			db_close $rs
		}
		go_mthd_view_settings
	}
}


proc do_group_constr {} {

	global DB

	set submit [reqGetArg SubmitName]

	if {$submit == "do_group_constr_upd"} {
		set grp_constr_id [reqGetArg grp_constr_id]
		set sql {
			update tViewPMGroupConstr set group = ? , group_name = ? where view_grp_constr_id = ?
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set rs      [inf_exec_stmt $stmt [reqGetArg group] [reqGetArg group_name] $grp_constr_id]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to update group definition : $msg"
			go_group_constr
			return
		} else {
			msg_bind "Group succesfully updated"
			db_close $rs
			go_mthd_view_settings
			return
		}
	} else {
		set sql {
			insert into tViewPMGroupConstr(group,group_name) values (?,?)
		}
		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set rs      [inf_exec_stmt $stmt [reqGetArg group] [reqGetArg group_name]]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to add group definition : $msg"
			go_group_constr
			return
		} else {
			msg_bind "Group succesfully added"
			db_close $rs
			go_mthd_view_settings
			return
		}
	}
}


proc do_constr {} {

	global DB

	set submit [reqGetArg SubmitName]

	if {$submit == "do_constr_upd"} {
		set constr_id [reqGetArg constr_id]
		set sql {
			update tViewPMConstr set pay_mthd = ? , type = ?, desc = ? where view_constr_id = ?
		}

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set rs      [inf_exec_stmt $stmt [reqGetArg pay_mthd] [reqGetArg type] [reqGetArg desc] $constr_id]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to update PM definition : $msg"
			go_constr
			return
		} else {
			msg_bind "Pay Mthd succesfully updated"
			go_mthd_view_settings
			return
		}
	} else {
		set sql {
			insert into tViewPMConstr(pay_mthd,type,desc) values (?,?,?)
		}
		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt [reqGetArg pay_mthd] [reqGetArg type] [reqGetArg desc]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to add PM definition : $msg"
			go_constr
			return
		} else {
			msg_bind "PM succesfully added"
			go_mthd_view_settings
			return
		}
	}
}


proc do_view {} {

	global DB

	set view_id [reqGetArg view_id]
	set submit  [reqGetArg SubmitName]

	if {$submit == "do_view_group_add"} {
		set sql {
			insert into tViewPMGroup(view_grp_constr_id,view_id,wtdorder,deporder) values(?,?,?,?)
		}
		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt [reqGetArg view_grp_constr_id] $view_id [reqGetArg wtdorder] [reqGetArg deporder]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to add group : $msg"
			go_view
			return
		} else {
			msg_bind "Group succesfully added"
			go_view
			return
		}

	}

	if {$submit == "do_view_pay_mthd_add"} {
		set sql {
			insert into tViewPM(view_id,view_grp_constr_id,view_constr_id,deporder,wtdorder) values(?,?,?,?,?)
		}
		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt $view_id [reqGetArg view_grp_constr_id] [reqGetArg view_constr_id] [reqGetArg deporder] [reqGetArg wtdorder]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to add method: $msg"
			go_view
			return
		} else {
			msg_bind "Method succesfully added to view"
			go_view
			return
		}
	}

	go_view
}

proc do_view_countries {} {

	global DB

	set sql {
		select
			country_code,
			view_id
		from
			tViewPMCntry
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	array set existing_list [list]
	set n [db_get_nrows $res]

	for {set i 0} {$i < $n} {incr i} {
		set existing_list([db_get_col $res $i country_code]) [db_get_col $res $i view_id]
	}

	set STMT(I) [list]
	set STMT(U) [list]

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[regexp {^cntry_view_([A-Z]+)$} [reqGetNthName $i] all code]} {
			if {[info exists existing_list($code)]} {
				if {$existing_list($code) != [reqGetNthVal $i]} {
					lappend STMT(U) $code [reqGetNthVal $i]
				}
			} else {
				lappend STMT(I) $code [reqGetNthVal $i]
			}
		}
	}

	set sql_i {
		insert into tViewPMCntry(country_code,view_id) values(?,?)
	}

	set sql_u {
		update tViewPMCntry set view_id = ? where country_code = ?
	}

	set stmt_i [inf_prep_sql $DB $sql_i]
	set stmt_u [inf_prep_sql $DB $sql_u]

	set c [catch {
		foreach {cy val} $STMT(I) {
			inf_exec_stmt $stmt_i $cy $val
		}

		foreach {cy val} $STMT(U) {
			inf_exec_stmt $stmt_u $val $cy
		}
	} msg]

	if {$c} {
		OT_LogWrite 1 "Error updating some of the view settings : $msg"
		err_bind $msg
	}

	go_mthd_view_settings
}


#
# Update group vieworder
#
proc do_grp_upd {} {

	global DB

	set groups    [reqGetArgs slct_grp]

	set sql {
		update
			tViewPMGroup
		set
			deporder = ?,
			wtdorder = ?
		where
			view_pm_grp_id = ?
	}

	foreach group $groups {

		set deporder [reqGetArg GRP_DEP_$group]
		set wtdorder [reqGetArg GRP_WTD_$group]

		if {[catch {
			set stmt    [inf_prep_sql $DB $sql]
			set sel_rs  [inf_exec_stmt $stmt\
										$deporder\
										$wtdorder\
										$group]
			inf_close_stmt $stmt
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind "Unable to execute query : $msg"
			break
		} else {
			msg_bind "Groups succesfully updated"
			db_close $sel_rs
		}
	}
	go_view
}



#
# Update method vieworder
#
proc do_mthd_upd {} {

	global DB

	set view_id    [reqGetArg view_id]
	set submitName [reqGetArg SubmitName]

	if {$submitName == "DoPayMthdUpdate"} {

		set mthds     [reqGetArgs slct_mthd]

		set sql {
			update
				tViewPM
			set
				deporder = ?,
				wtdorder = ?
			where
				view_pmt_id = ?
		}

		foreach method $mthds {

			set deporder [reqGetArg MTHD_DEP_$method]
			set wtdorder [reqGetArg MTHD_WTD_$method]

			if {[catch {
				set stmt    [inf_prep_sql $DB $sql]
				set sel_rs  [inf_exec_stmt $stmt\
											$deporder\
											$wtdorder\
											$method]
				inf_close_stmt $stmt
			} msg]} {
				ob::log::write ERROR {unable to execute query : $msg}
				err_bind "Unable to execute query : $msg"
				break
			} else {
				db_close $sel_rs
				msg_bind "Method succesfully updated"
			}

		}
	}

	if {$submitName == "DoPayMthdDelete"} {
		set mthds [reqGetArgs del_slct_mthd]

		set sql {
			delete from tViewPM where view_pmt_id = ?
		}

		foreach method $mthds {

			if {[catch {
				set stmt    [inf_prep_sql $DB $sql]
				set sel_rs  [inf_exec_stmt $stmt $method]
				inf_close_stmt $stmt
			} msg]} {
				ob::log::write ERROR {unable to execute query : $msg}
				err_bind "Unable to execute query : $msg"
				break
			} else {
				db_close $sel_rs
				msg_bind "Method succesfully deleted"
			}
		}
	}

	go_view
}



#
# View the payment method groups
#
proc go_mthd_view { {p_view_id 1}} {

	global PM_VIEWS_COUNTRY
	global DB

	GC::mark PM_VIEWS_COUNTRY

	set view_id   [reqGetArg view_id]
	if {$view_id == ""} {
		set view_id $p_view_id
	}

	tpSetVar      add_new_view 1
	tpBindString  ViewId $view_id

	if {$view_id != ""} {
		tpSetVar add_new_view 0

		# Bind list of pay mthd views
		_bind_views $view_id


		# Bind contries and associated views

		# Bind view settings
		_bind_pay_mthd_settings $view_id
	}

	asPlayFile -nocache pay_mthds_order.html
}

proc do_disp_ctrl_upd {} {

	global DB

	set disp_ctrl [reqGetArg disp_ctrl]
	set view_id   [reqGetArg view_id]

	set sql {
		update
			tViewPMDef
		set
			disp_ctrl = ?
		where
			view_id = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $disp_ctrl $view_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
		go_view
	} else {
		msg_bind "Successfully updated Payment Method Display Control"
		go_view
	}
	catch {db_close $rs}
}


#
# Get & bind locales
#
proc _bind_pay_mthd_settings {view_id} {
	global DB
	global PAY_MTHD_ORDER
	global PAY_MTHD_GRP_ORDER

	#1. get groups
	set sql {
		select
			group,
			group_name,
			lang,
			type,
			wtdorder,
			deporder
		from
			tViewPayMthdGroup
		where
			view_id = ?
		order by
			deporder,
			wtdorder asc
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set sel_rs  [inf_exec_stmt $stmt $view_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	}

	set nrows [db_get_nrows $sel_rs]
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set PAY_MTHD_GRP_ORDER($i,group)      [db_get_col $sel_rs $i group]
			set PAY_MTHD_GRP_ORDER($i,group_name) [db_get_col $sel_rs $i group_name]
			set PAY_MTHD_GRP_ORDER($i,lang)       [db_get_col $sel_rs $i lang]
			set PAY_MTHD_GRP_ORDER($i,type)       [db_get_col $sel_rs $i type]
			set PAY_MTHD_GRP_ORDER($i,wtdorder)   [db_get_col $sel_rs $i wtdorder]
			set PAY_MTHD_GRP_ORDER($i,deporder)   [db_get_col $sel_rs $i deporder]
		}
	}
	catch {db_close $sel_rs}

	tpSetVar num_groups $nrows
	foreach field { group
					group_name
					lang
					type
					wtdorder
					deporder } {
		tpBindVar g_$field  PAY_MTHD_GRP_ORDER   $field       grp_idx
	}

	############################################################################
	#2. get methods
	set sql {
		select
			group,
			pay_mthd,
			lang,
			scheme,
			wtdorder,
			deporder
		from
			tViewPayMthd
		where
			view_id = ?
		order by
			group,
			deporder,
			wtdorder asc
	}

	if {[catch {
		set stmt    [inf_prep_sql $DB $sql]
		set sel_rs  [inf_exec_stmt $stmt $view_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	}

	set nrows [db_get_nrows $sel_rs]
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set PAY_MTHD_ORDER($i,group)    [db_get_col $sel_rs $i group]
			set PAY_MTHD_ORDER($i,pay_mthd) [db_get_col $sel_rs $i pay_mthd]
			set PAY_MTHD_ORDER($i,lang)     [db_get_col $sel_rs $i lang]
			set PAY_MTHD_ORDER($i,scheme)   [db_get_col $sel_rs $i scheme]
			set PAY_MTHD_ORDER($i,deporder) [db_get_col $sel_rs $i deporder]
			set PAY_MTHD_ORDER($i,wtdorder) [db_get_col $sel_rs $i wtdorder]
			if {$i > 0 &&
			$PAY_MTHD_ORDER([expr {$i-1}],group) != $PAY_MTHD_ORDER($i,group)} {
				set PAY_MTHD_ORDER($i,change_group) 1
			} else {
				set PAY_MTHD_ORDER($i,change_group) 0
			}
		}
	}
	catch {db_close $sel_rs}

	tpSetVar num_methods $nrows
	foreach field { group
					pay_mthd
					lang
					scheme
					wtdorder
					deporder
					change_group } {
		tpBindVar m_$field  PAY_MTHD_ORDER   $field       mthd_idx
	}
}


proc _bind_views {{view_id -1}} {

	global DB

	global PM_VIEWS
	GC::mark PM_VIEWS

	set sql {
		select
			view_id,
			name
		from
			tViewPMDef
	}

	if {[catch {
		set view_list_stmt [inf_prep_sql $DB $sql]
		set view_list_rs   [inf_exec_stmt $view_list_stmt]
		inf_close_stmt $view_list_stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $view_list_rs]
		tpSetVar num_views $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEWS($i,view_id)   [db_get_col $view_list_rs $i view_id]
			set PM_VIEWS($i,view_name) [db_get_col $view_list_rs $i name]
			set PM_VIEWS($i,selected) ""
			if {$view_id == [db_get_col $view_list_rs $i view_id]} {
				set PM_VIEWS($i,selected) "selected"
			}
		}
		db_close $view_list_rs
	}

	foreach c {view_id view_name selected} {
		tpBindVar l_$c PM_VIEWS $c view_idx
	}
}

proc _bind_disp_ctrl {{view_id -1}} {

	global DB

	set sql {
		select
			disp_ctrl
		from
			tViewPMDef
		where
			view_id = ?
	}

	if {[catch {
		set disp_ctrl_stmt [inf_prep_sql $DB $sql]
		set disp_ctrl_rs   [inf_exec_stmt $disp_ctrl_stmt $view_id]
		inf_close_stmt $disp_ctrl_stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		if {[db_get_nrows $disp_ctrl_rs] != 1} {
			ob::log::write ERROR {_bind_disp_ctrl: query failed to get 1 row}
			err_bind "_bind_disp_ctrl: query failed to get 1 row"
		} else {
			set disp_ctrl [db_get_col $disp_ctrl_rs 0 disp_ctrl]
			db_close $disp_ctrl_rs

			tpBindString disp_ctrl_${disp_ctrl}_chk "checked"
		}
	}
}

proc _bind_country_views args {

	global DB
	global PM_VIEWS_COUNTRY
	GC::mark PM_VIEWS_COUNTRY

	set sql {
		select
			c.country_code,
			c.country_name,
			NVL(v.view_id,1) as view_id
		from
			tcountry c,
			outer tViewPMCntry v
		where v.country_code = c.country_code
		order by c.country_name
	}

	if {[catch {
		set view_cntry_stmt [inf_prep_sql $DB $sql]
		set view_cntry_rs   [inf_exec_stmt $view_cntry_stmt]
		inf_close_stmt $view_cntry_stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $view_cntry_rs]
		tpSetVar num_countries $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEWS_COUNTRY($i,cntry_code)    [db_get_col $view_cntry_rs $i country_code]
			set PM_VIEWS_COUNTRY($i,cntry_name)    [db_get_col $view_cntry_rs $i country_name]
			set PM_VIEWS_COUNTRY($i,cntry_view_id) [db_get_col $view_cntry_rs $i view_id]
		}
		db_close $view_cntry_rs
	}

	foreach c {cntry_code cntry_name cntry_view_id} {
		tpBindVar $c PM_VIEWS_COUNTRY $c country_idx
	}
}

proc _bind_group_constr args {

	global DB
	global PM_VIEWS_GRP_CONSTR

	GC::mark PM_VIEWS_GRP_CONSTR

	set sql {
		select
			view_grp_constr_id as grp_constr_id,
			group,
			group_name,
			type
		from
			tViewPMGroupConstr
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $rs]
		tpSetVar num_grp_constr $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEWS_GRP_CONSTR($i,grp_constr_id)         [db_get_col $rs $i grp_constr_id]
			set PM_VIEWS_GRP_CONSTR($i,grp_constr_group)      [db_get_col $rs $i group]
			set PM_VIEWS_GRP_CONSTR($i,grp_constr_group_name) [db_get_col $rs $i group_name]
			set PM_VIEWS_GRP_CONSTR($i,grp_constr_type)       [db_get_col $rs $i type]
		}
		db_close $rs
	}

	foreach c {id group group_name type} {
		tpBindVar grp_constr_${c} PM_VIEWS_GRP_CONSTR grp_constr_${c} grp_constr_idx
	}
}


proc _bind_pay_mthd_constr args {

	global DB
	global PM_VIEWS_CONSTR
	GC::mark PM_VIEWS_CONSTR

	set sql {
		select
			view_constr_id,
			pay_mthd,
			type,
			desc
		from
			tViewPMConstr
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $rs]
		tpSetVar num_constr $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEWS_CONSTR($i,constr_id)          [db_get_col $rs $i view_constr_id]
			set PM_VIEWS_CONSTR($i,constr_pay_mthd)    [db_get_col $rs $i pay_mthd]
			set PM_VIEWS_CONSTR($i,constr_type)        [db_get_col $rs $i type]
			set PM_VIEWS_CONSTR($i,constr_desc)        [db_get_col $rs $i desc]
		}
		db_close $rs
	}

	foreach c {id pay_mthd type desc} {
		tpBindVar constr_${c} PM_VIEWS_CONSTR constr_${c} constr_idx
	}
}

proc _bind_group_disporders {view_id} {

	global DB
	global PM_VIEW_GROUPS
	GC::mark PM_VIEW_GROUPS

	set sql {
		select
			g.view_pm_grp_id,
			c.group,
			g.wtdorder,
			g.deporder
		from
			tViewPMGroup g,
			tViewPMGroupConstr c
		where
			g.view_id = ?
			and c.view_grp_constr_id = g.view_grp_constr_id
		order by deporder, wtdorder
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $view_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $rs]
		tpSetVar num_groups $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEW_GROUPS($i,view_pm_grp_id)  [db_get_col $rs $i view_pm_grp_id]
			set PM_VIEW_GROUPS($i,group)           [db_get_col $rs $i group]
			set PM_VIEW_GROUPS($i,wtdorder)        [db_get_col $rs $i wtdorder]
			set PM_VIEW_GROUPS($i,deporder)        [db_get_col $rs $i deporder]
		}
		db_close $rs
	}

	foreach c {view_pm_grp_id group wtdorder deporder} {
		tpBindVar g_$c PM_VIEW_GROUPS $c grp_idx
	}

	ob_log::write_array ERROR PM_VIEW_GROUPS
}


proc _bind_pay_mthd_disporders {view_id} {

	global DB
	global PM_VIEW
	GC::mark PM_VIEW

	set sql {
		select
			v.view_pmt_id,
			c.group,
			cp.type,
			cp.pay_mthd,
			cp.desc,
			v.deporder,
			v.wtdorder
		from
			tViewPM v,
			tViewPMGroupConstr c,
			tViewPMConstr cp
		where
			v.view_id = ?
			and v.view_grp_constr_id = c.view_grp_constr_id
			and v.view_constr_id     = cp.view_constr_id
		order by c.group,v.deporder,v.wtdorder
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $view_id]
		inf_close_stmt $stmt
	} msg]} {
		ob::log::write ERROR {unable to execute query : $msg}
		err_bind "Unable to execute query : $msg"
	} else {
		set n [db_get_nrows $rs]
		tpSetVar num_methods $n
		for {set i 0} {$i < $n} {incr i} {
			set PM_VIEW($i,view_pmt_id)   [db_get_col $rs $i view_pmt_id]
			set PM_VIEW($i,group)         [db_get_col $rs $i group]
			set PM_VIEW($i,type)          [db_get_col $rs $i type]
			set PM_VIEW($i,wtdorder)      [db_get_col $rs $i wtdorder]
			set PM_VIEW($i,deporder)      [db_get_col $rs $i deporder]
			set PM_VIEW($i,pay_mthd)      [db_get_col $rs $i pay_mthd]
			set PM_VIEW($i,desc)          [db_get_col $rs $i desc]

			if {$i > 0 && $PM_VIEW([expr {$i-1}],group) != $PM_VIEW($i,group)} {
				set PM_VIEW($i,change_group) 1
			} else {
				set PM_VIEW($i,change_group) 0
			}
		}
		db_close $rs
	}

	foreach c {view_pmt_id group pay_mthd type wtdorder deporder change_group desc} {
		tpBindVar m_$c PM_VIEW $c mthd_idx
	}
}


}