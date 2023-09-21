# ==============================================================
# $Id: mkt_template.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Market/Event Templates Management
#
# This is used to control how the markets / events are displayed in the
# Sportsbook - which templates are attached to which market groups
#
#

namespace eval ADMIN::MKT_TEMPLATE {

asSetAct ADMIN::MKT_TEMPLATE::GoMktTemplatesList      [namespace code go_template_list]
asSetAct ADMIN::MKT_TEMPLATE::GoMktTemplateLink       [namespace code go_template_link]
asSetAct ADMIN::MKT_TEMPLATE::DoMktTemplateLink       [namespace code do_template_link]
asSetAct ADMIN::MKT_TEMPLATE::GoAddLinkMktTemplate    [namespace code go_template_add_link]
asSetAct ADMIN::MKT_TEMPLATE::AddMktGroupLinkByNames  [namespace code add_mkt_group_link_by_names]
asSetAct ADMIN::MKT_TEMPLATE::RemoveMktGroupLinks     [namespace code remove_mkt_grp_links]
asSetAct ADMIN::MKT_TEMPLATE::AddMktGroupLink         [namespace code add_mkt_group_link]


#==============================================================================
#
# go_template_list  : display the list of available templates
#
proc ::ADMIN::MKT_TEMPLATE::go_template_list {{order_by "name"}} {

	global DB
	variable TEMPLATE
	unset -nocomplain TEMPLATE

	set stmt [inf_prep_sql $DB [subst {
		select
			mkt_tmpl_id,
			name,
			valid_sorts
		from
			tMktTemplate
		order by $order_by
	}]]

	set res  [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $res]

	ob_log::write INFO {MKT_TEMPLATE::go_template_list: NumTemplates = $nrows}

	for {set r 0} {$r < $nrows} {incr r} {
		set TEMPLATE($r,mkt_tmpl_id) [db_get_col $res $r mkt_tmpl_id]
		set TEMPLATE($r,name)        [db_get_col $res $r name]
	}

	inf_close_stmt $stmt
	db_close $res

	# Bind
	set cns [namespace current]

	tpBindVar mkt_tmpl_id       ${cns}::TEMPLATE   mkt_tmpl_id   tp_idx
	tpBindVar mkt_tplate_name   ${cns}::TEMPLATE   name          tp_idx

	# Cleanup
	GC::mark TEMPLATE

	tpSetVar NumTemplates $nrows

	asPlayFile mkt_template_list.html
}


#==============================================================================
#
# go_template_link  : display the list of available templates
#
proc ::ADMIN::MKT_TEMPLATE::go_template_link {args} {

	global DB
	global COL_MKT_GRP_LINK

	set order_by     [ob_chk::get_arg order -on_err "grp_name" {RE -args {^[A-Za-z_]+$}}]
	set mkt_tmpl_id  [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]
	set sport_id     [ob_chk::get_arg sport_id -on_err -1 UINT]
	if {$sport_id == -1} {
		set sport_id  [ob_chk::get_arg sport_filter -on_err -1 UINT]
	}

	ob_log::write INFO {MKT_TEMPLATE::go_template_link mkt_tmpl_id=$mkt_tmpl_id}

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $sport_id]

	# Bind the template detail
	_bind_selected_template $mkt_tmpl_id

	# Bind the groups linked to this template for the selected sport
	set sport_ob_level [lindex $selected_sport 1]
	set sport_ob_id    [lindex $selected_sport 2]

	# Decide whether we start at class or category for this sport
	if {$sport_ob_level == "y"} {
		# Get all classes
		set PathLevel "category"
	} else {
		set PathLevel "class"
	}

	# We need to extract details depending on which level we are looking for Category/Class
	switch -exact -- $PathLevel {
		"class" {
			# Get types entries as part of this class
			set sql [subst {
				select
					t.name          as type_name,
					g.name          as grp_name,
					g.ev_oc_grp_id  as grp_id
				from
					tEvType t,
					tEvOcGrp g
				where
					g.mkt_tmpl_id = %s and
					g.ev_type_id = t.ev_type_id and
					t.ev_class_id  = %s
				order by $order_by
			}]
		}
		"category" -
		default {
			# Get class entries as part of this category
			set sql [subst {
				select
					t.name          as type_name,
					g.name          as grp_name,
					g.ev_oc_grp_id  as grp_id
				from
					tEvOcGrp g,
					tEvType t,
					tEvClass c,
					tEvCategory cat
				where
					g.mkt_tmpl_id      = %s and
					g.ev_type_id       = t.ev_type_id and
					t.ev_class_id      = c.ev_class_id and
					cat.category       = c.category and
					cat.ev_category_id = %s
				order by $order_by
			}]
		}
	}

	set sql [format $sql $mkt_tmpl_id $sport_ob_id]

	ob::log::write DEBUG "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumGrps $rows

	ob::log::write INFO "rows = $rows"

	for {set i 0} {$i < $rows} {incr i} {
		set COL_MKT_GRP_LINK($i,type_name)   [db_get_col $res $i type_name]
		set COL_MKT_GRP_LINK($i,grp_name)    [db_get_col $res $i grp_name]
		set COL_MKT_GRP_LINK($i,grp_id)      [db_get_col $res $i grp_id]
	}

	tpBindVar type_name     COL_MKT_GRP_LINK type_name  grp_link_idx
	tpBindVar grp_name      COL_MKT_GRP_LINK grp_name   grp_link_idx
	tpBindVar grp_id        COL_MKT_GRP_LINK grp_id     grp_link_idx

	asPlayFile mkt_template_link.html
}


#==============================================================================
#
# do_template_link -> go to either add/remove link
#
proc ::ADMIN::MKT_TEMPLATE::do_template_link {args} {

	set action [ob_chk::get_arg SubmitName -on_err "en" {RE -args {^[A-Za-z]+$}}]

	if {$action == "FilterSport"} {
		::ADMIN::MKT_TEMPLATE::go_template_link
	} elseif {$action == "AddLink"} {
		::ADMIN::MKT_TEMPLATE::go_add_link
	} elseif {$action == "RemoveLink"} {
		::ADMIN::MKT_TEMPLATE::remove_mkt_grp_links
	} else {
		error {::ADMIN::MKT_TEMPLATE::do_template_link - Unknown action}
		# Invalid action
	}
}


#==============================================================================
#
# go_add_link - add a template link
#
proc ::ADMIN::MKT_TEMPLATE::go_add_link {args} {

	set mkt_tmpl_id [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]
	set sport_id    [ob_chk::get_arg sport_filter -on_err -1 UINT]

	ob_log::write INFO {*** go_add_link - mkt_tmpl_id=$mkt_tmpl_id sport_id=$sport_id ***}

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $sport_id]

	# Bind the template detail
	_bind_selected_template $mkt_tmpl_id

	asPlayFile mkt_template_link_add.html
}


#==============================================================================
#
# Select the correct method of linking market groups
#
proc ::ADMIN::MKT_TEMPLATE::go_template_add_link {args} {

	set link_method [reqGetArg linkMethod]

	if {$link_method == "FullList"} {
		go_template_mkt_grp_link_full_list $args
	} elseif {$link_method == "EachType"} {
		go_template_mkt_grp_link_each_type $args
	} else {
		error "unexpected link method: $link_method"
	}
}


#
# ----------------------------------------------------------------------------
# Display the full list of groups for the sport
# ----------------------------------------------------------------------------
#
proc ::ADMIN::MKT_TEMPLATE::go_template_mkt_grp_link_full_list args {

	global COL_MKT_GRP_LINK
	variable VALID_SORT_LIST

	set mkt_tmpl_id   [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]
	set sport_id      [ob_chk::get_arg sport_id -on_err -1 UINT]

	ob::log::write INFO "go_template_mkt_grp_link_full_list mkt_template_id= $mkt_tmpl_id"
	ob::log::write INFO "go_template_mkt_grp_link_full_list sport_id= $sport_id"

	# Bind the template detail
	_bind_selected_template $mkt_tmpl_id

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $sport_id]

	set sport_ob_level [lindex $selected_sport 1]
	set sport_ob_id    [lindex $selected_sport 2]

	# Decide whether we start at class or category for this sport
	if {$sport_ob_level == "y"} {
		# Get all classes
		set PathLevel "category"
	} else {
		set PathLevel "class"
	}

	# We need to extract details depending on which level we are looking for Category/Class
	switch -exact -- $PathLevel {
		"class" {
			# Get types entries as part of this class
			set sql [subst {
				select distinct
					g.name          as ob_name,
					g.sort,
					g.mkt_info_push_payload
				from
					tEvType t,
					tEvOcGrp g
				where
					g.ev_type_id = t.ev_type_id and
					t.ev_class_id  = %s

			}]
		}
		"category" -
		default {
			# Get class entries as part of this category
			set sql [subst {
				select distinct
					g.name          as ob_name,
					g.sort,
					g.mkt_info_push_payload
				from
					tEvOcGrp g,
					tEvType t,
					tEvClass c,
					tEvCategory cat
				where
					g.ev_type_id       = t.ev_type_id and
					t.ev_class_id      = c.ev_class_id and
					cat.category       = c.category and
					cat.ev_category_id = %s
			}]
		}
	}

	set sql [format $sql $sport_ob_id]

	ob::log::write DEBUG "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	ob::log::write DEBUG "rows = $rows"

	for {set i 0} {$i < $rows} {incr i} {
		set COL_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]

		set sort [db_get_col $res $i sort]
		set is_push_market [db_get_col $res $i mkt_info_push_payload]

		if {[lsearch -exact $VALID_SORT_LIST $sort] > -1
			 && $is_push_market == "N"} {
			set COL_MKT_GRP_LINK($i,disabled) ""
		} else {
			set COL_MKT_GRP_LINK($i,disabled) "disabled"
		}
	}

	ob_log::write_array INFO COL_MKT_GRP_LINK

	tpBindVar objName     COL_MKT_GRP_LINK name      col_mkt_grp_link_idx
	tpBindVar isDisabled  COL_MKT_GRP_LINK disabled  col_mkt_grp_link_idx

	tpBindString mkt_tmpl_id $mkt_tmpl_id

	asPlayFile mkt_template_link_mktgrp_full_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Add links between market groups and templates, enumerating for a set of
# market group names
# ----------------------------------------------------------------------------
#
proc ::ADMIN::MKT_TEMPLATE::add_mkt_group_link_by_names args {

	set mkt_tmpl_id [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]
	set sport_id    [ob_chk::get_arg sport_id -on_err -1 UINT]

	ob::log::write INFO "add_mkt_group_link_by_names mkt_template_id= $mkt_tmpl_id"
	ob::log::write INFO "add_mkt_group_link_by_names sport_id= $sport_id"

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $sport_id]

	set sport_ob_level [lindex $selected_sport 1]
	set sport_ob_id    [lindex $selected_sport 2]

	set overwrite_clause ""

	if {[reqGetNumArgs no_overwrite] > 0} {
		set overwrite_clause "tEvOcGrp.mkt_tmpl_id is null and "
	}

	if {[reqGetNumArgs selBoxes] > 0} {

		if {![string is integer $mkt_tmpl_id]} {
			error "Invalid template ID"
		}

		if {![string is integer $sport_id]} {
			error "Invalid reference"
		}

		if { $sport_ob_level == "y" } {
			set sql [subst {
				update tEvOcGrp
					set mkt_tmpl_id = $mkt_tmpl_id
				where
					$overwrite_clause
					tEvOcGrp.ev_type_id in (
						select
							t.ev_type_id
						from
							tEvType     t,
							tEvClass    c,
							tEvCategory cat
						where
							t.ev_class_id       = c.ev_class_id and
							c.category          = cat.category and
							cat.ev_category_id  = $sport_ob_id
					) and tEvOcGrp.name = ?
			}]

		} else {
			set sql [subst {
				update tEvOcGrp
				set
					mkt_tmpl_id = $mkt_tmpl_id
				where
					$overwrite_clause
					tEvOcGrp.ev_type_id in (
						select
							t.ev_type_id
						from
							tEvType t
						where
							t.ev_class_id = $sport_ob_id
					) and tEvOcGrp.name = ?
			}]
		}

		ob::log::write DEBUG "sql = $sql"
		set stmt [inf_prep_sql $::DB $sql]

		for {set i 0} {$i < [reqGetNumArgs selBoxes]} {incr i} {
			set grp_name [reqGetNthArg selBoxes $i]
			if {[catch {inf_exec_stmt $stmt $grp_name} msg]} {
					ob::log::write ERROR {ERROR adding market group link: $msg}
					inf_close_stmt $stmt
					err_bind $msg
					go_template_link
					return
			}

		}

		inf_close_stmt $stmt

		msg_bind "Links Successfully Added"

	} else {
		error "No market groups received"
	}

	go_template_link
}


#
# ----------------------------------------------------------------------------
# Remove links from market groups
# ----------------------------------------------------------------------------
#
proc ::ADMIN::MKT_TEMPLATE::remove_mkt_grp_links args {

	ob_log::write INFO {remove_mkt_grp_links}

	set list_del_groups [list ""]

	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[reqGetNthName $i] == "delBoxes"} {
			lappend list_del_groups [reqGetNthVal $i]
		}
	}

	if {[llength $list_del_groups] > 0} {

		set sql [subst {
			update
				tEvOcGrp
			set
				mkt_tmpl_id = null
			where
				ev_oc_grp_id = ?
		}]

		set stmt [inf_prep_sql $::DB $sql]

		for {set i 0} {$i < [llength $list_del_groups]} {incr i} {

			if {[catch {inf_exec_stmt $stmt [lindex $list_del_groups $i]} msg]} {
				ob::log::write ERROR {ERROR removing market group link: $msg}
				inf_close_stmt $stmt
				err_bind $msg
				go_template_link
				return
			} else {
				msg_bind "Link(s) Removed Successfully"
			}
		}

		catch {inf_close_stmt $stmt}
	}

	go_template_link
}



#
# ----------------------------------------------------------------------------
# Goto to the page which allows user to link to markets groups
# ----------------------------------------------------------------------------
#
proc ::ADMIN::MKT_TEMPLATE::go_template_mkt_grp_link_each_type args {

	global COL_MKT_GRP_LINK
	variable VALID_SORT_LIST

	set mkt_tmpl_id      [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]
	set sport_id         [ob_chk::get_arg sport_id -on_err -1 UINT]
	set PathLevel        [ob_chk::get_arg PathLevel -on_err "" {RE -args {^[A-Za-z]+$}}]

	set clicked_obj_name [reqGetArg clickedObjName]
	set requiredObjId    [reqGetArg clickedObjId]

	tpBindString clickedObjName       $clicked_obj_name

	# Bind the template detail
	_bind_selected_template $mkt_tmpl_id

	ob::log::write INFO "go_template_mkt_grp_link_full_list mkt_template_id= $mkt_tmpl_id"
	ob::log::write INFO "go_template_mkt_grp_link_full_list sport_id= $sport_id"

	# Bind the sports dropdown list
	set selected_sport [_bind_sports $sport_id]

	set sport_ob_level [lindex $selected_sport 1]
	set sport_ob_id    [lindex $selected_sport 2]

	if {$PathLevel == ""} {
		# Decide whether we start at class or category for this sport
		if {$sport_ob_level == "y"} {
			# Get all classes
			set PathLevel "category"
		} else {
			set PathLevel "class"
		}
	}

	if { $requiredObjId == ""} {
		# This should only be the case for category/class
		# At the start of Sport drill down
		set requiredObjId $sport_ob_id
		tpSetVar root 1
	}


	# We need to extract details depending on which level we are looking for Category/Class/Type/Tevocgrp
	switch -exact -- $PathLevel {
		"type" {
			# Get maret groups entries as part of this type
			set sql [subst {
				select
					g.name          as ob_name,
					g.ev_oc_grp_id  as ob_id,
					g.mkt_tmpl_id,
					g.sort,
					g.mkt_info_push_payload
				from
					tEvOcGrp g
				where
					g.ev_type_id  = %s

			}]

			tpSetVar     PathLevel       group
			tpBindString parentName      [reqGetArg parentName]
			tpBindString parentId        [reqGetArg parentId]
			tpSetVar     ShowParentName  [reqGetArg parentName]
		}
		"class" {
			# Get types entries as part of this class
			set sql [subst {
				select
					t.name       as ob_name,
					t.ev_type_id as ob_id
				from
					tEvType t
				where
					t.ev_class_id  = %s
			}]

			tpSetVar PathLevel       type
			tpBindString parentName  $clicked_obj_name
			tpBindString parentId    $requiredObjId
		}
		"category" -
		default {
			# Get class entries as part of this category
			set sql [subst {
				select
					c.name        as ob_name,
					c.ev_class_id as ob_id
				from
					tEvClass c,
					tEvCategory cat
				where
					cat.category  = c.category
					and cat.ev_category_id = %s
			}]

			tpSetVar PathLevel class
			tpBindString categoryId    $requiredObjId
		}
	}

	set sql [format $sql ${requiredObjId}]

	ob::log::write DEBUG "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	ob_log::write INFO {rows = $rows}

	for {set i 0} {$i < $rows} {incr i} {
		set COL_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]
		set COL_MKT_GRP_LINK($i,id)     [db_get_col $res $i ob_id]

		if { $PathLevel == "type"} {
			# Limit markets available to select based on market sor
			set sort [db_get_col $res $i sort]
			set is_push_market [db_get_col $res $i mkt_info_push_payload]
			if { [db_get_col $res $i mkt_tmpl_id] == "" \
				&& [lsearch -exact $VALID_SORT_LIST $sort] > -1
				 && $is_push_market == "N" } {
				set COL_MKT_GRP_LINK($i,disabled) ""
			} else {
				set COL_MKT_GRP_LINK($i,disabled) "disabled"
			}
		}
	}

	#ob_log::write_array INFO COL_MKT_GRP_LINK

	tpBindVar objId       COL_MKT_GRP_LINK id     col_mkt_grp_link_idx
	tpBindVar objName     COL_MKT_GRP_LINK name   col_mkt_grp_link_idx

	if { $PathLevel == "type"} {
		tpBindVar isDisabled  COL_MKT_GRP_LINK disabled   col_mkt_grp_link_idx
	}

	asPlayFile mkt_template_link_mktgrp.html
	db_close $res
}


#
# ----------------------------------------------------------------------------
# Add links between market groups and template
# ----------------------------------------------------------------------------
#
proc ::ADMIN::MKT_TEMPLATE::add_mkt_group_link args {

	set mkt_tmpl_id     [ob_chk::get_arg mkt_tmpl_id -on_err -1 UINT]

	if {[reqGetNumArgs selBoxes] > 0} {

		set sql [subst {
			update
				tEvOcGrp
			set
				mkt_tmpl_id = %s
			where
				ev_oc_grp_id =?
		}]

		set sql [format $sql $mkt_tmpl_id]
		set stmt [inf_prep_sql $::DB $sql]

		for {set i 0} {$i < [reqGetNumArgs selBoxes]} {incr i} {
			set grp_id [reqGetNthArg selBoxes $i]

			ob_log::write INFO {::ADMIN::MKT_TEMPLATE::add_mkt_group_link adding grp_id=$grp_id}

			if {[catch {inf_exec_stmt $stmt $grp_id} msg]} {
				ob::log::write ERROR {ERROR adding market group link: $msg}
				inf_close_stmt $stmt
				err_bind $msg
				go_template_link
				return
			}

		}

		inf_close_stmt $stmt

		msg_bind "Links Successfully Added"
	}

	go_template_link
}


#
# Bind the selected template
#
proc ::ADMIN::MKT_TEMPLATE::_bind_selected_template {{template_sel}} {

	global DB
	variable VALID_SORT_LIST

	set stmt [inf_prep_sql $DB [subst {
		select
			mkt_tmpl_id,
			name,
			valid_sorts
		from
			tMktTemplate
		where
			mkt_tmpl_id = $template_sel
	}]]

	set res  [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $res]
	inf_close_stmt $stmt

	set id          [db_get_col $res 0 mkt_tmpl_id]
	set name        [db_get_col $res 0 name]
	set valid_sorts [db_get_col $res 0 valid_sorts]

	set VALID_SORT_LIST [split $valid_sorts ","]

	db_close $res

	tpBindString mkt_tmpl_id        $id
	tpBindString mkt_tplate_name    $name
}


#==============================================================================
#
# _bind_sports: Bind Up the sports information for the dropdown
#
proc ::ADMIN::MKT_TEMPLATE::_bind_sports { {sport_sel -1} } {

	global DB
	variable SPORTS
	unset -nocomplain SPORTS

	ob_log::write DEV {::ADMIN::MKT_TEMPLATE::_bind_sports $sport_sel}

	set stmt [inf_prep_sql $DB {
		select
			sport_id,
			name,
			ob_level,
			ob_id
		from
			tSport
		order by
			name;
	}]

	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSports [set n_rows [db_get_nrows $res]]

	set selected_sport_name ""

	# Cycle on sports
	for {set r 0} {$r < $n_rows} {incr r} {
		set SPORTS($r,sport_id) [db_get_col $res $r sport_id]
		set SPORTS($r,ob_id)    [db_get_col $res $r ob_id]
		set SPORTS($r,ob_level) [db_get_col $res $r ob_level]
		set SPORTS($r,name)     [db_get_col $res $r name]

		# set the default to the 1st sport in the dropdown
		if {$r == 0 || ($SPORTS($r,sport_id) == $sport_sel)} {
			set default_sport_id   $SPORTS($r,sport_id)
			set default_sport_dd   $SPORTS($r,ob_level)
			set default_sport_obid $SPORTS($r,ob_id)
			if { $SPORTS($r,sport_id) == $sport_sel } {
				set SPORTS($r,selected) {selected="selected"}
				set selected_sport_name $SPORTS($r,name)
			}
		}
	}

	tpBindString SelectedSportId $default_sport_id
	tpBindString SportOBId       $default_sport_obid

	tpBindString sport_id $sport_sel

	# Remember the drilldown level for the default sport
	switch -exact $default_sport_dd {
		"y" {
			tpBindString SelectedSportDD ROOT
		}
		"c" {
			tpBindString SelectedSportDD CLASS
		}
		default {
			error {Drilldown filter is not 'y' or 'c'}
		}

	}

	set cns [namespace current]

	tpBindVar SportId   ${cns}::SPORTS   sport_id   sport_idx
	tpBindVar SportName ${cns}::SPORTS   name       sport_idx
	tpBindVar SportLev  ${cns}::SPORTS   ob_level   sport_idx
	tpBindVar SportSel  ${cns}::SPORTS   selected   sport_idx

	tpBindString selSportName $selected_sport_name

	# Cleanup
	GC::mark SPORTS
	db_close $res

	# Return the default to be pre selected.
	return [list $default_sport_id $default_sport_dd $default_sport_obid]
}

# namespace end
}

