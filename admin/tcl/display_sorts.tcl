# ==============================================================
# $Id: display_sorts.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
# Create and assign different display sorts to event market groups in order to
# sort markets depending on their display order when these markets are displayed
# in My markets list for each customer
#
namespace eval ADMIN::DISPLAYSORT {

asSetAct ADMIN::DISPLAYSORT::GoDisplaySortList               [namespace code go_display_sort_list]
asSetAct ADMIN::DISPLAYSORT::GoDisplaySort                   [namespace code go_display_sort]
asSetAct ADMIN::DISPLAYSORT::DelDisplaySort                  [namespace code del_display_sort]
asSetAct ADMIN::DISPLAYSORT::DispSortRemoveMktGroupLink      [namespace code remove_display_sort_mkt_group_link]
asSetAct ADMIN::DISPLAYSORT::DispSortAddMktGroupLink         [namespace code add_display_sort_mkt_group_link]
asSetAct ADMIN::DISPLAYSORT::DispSortAddMktGroupLinkHub      [namespace code add_display_sort_mkt_group_link_hub]
asSetAct ADMIN::DISPLAYSORT::DispSortAddMktGroupLinkByNames  [namespace code add_display_sort_mkt_group_link_by_names]

#
# ----------------------------------------------------------------------------
# Generate list of sports
# ----------------------------------------------------------------------------
#
proc go_display_sort_list args {

	global DISPLAYSORT SPORT

	# Deal with Sports first

	set sport_id [reqGetArg SportId]

	bind_sports_list $sport_id

	# Now look in to display sort details

	set where_clause ""

	if { $sport_id != "" } {
		set where_clause " and d.sport_id = $sport_id "
	}

	set sort [reqGetArg order]

	switch -exact -- $sort {
		"name" {
			set set_order "d.disp_code, s.name, disporder"
		}
		"disp" {
			set set_order "disporder, s.name, d.disp_code"
		}
		default {
			set set_order "s.name, disporder, d.disp_code"
		}
	}

	set sql [subst {
		select
			d.disp_sort_id,
			d.disp_code,
			d.disporder,
			s.name as s_name
		from
			tDispSort d,
			tSport      s
		where
			s.sport_id = d.sport_id
		%s
		order by
			%s
	}]

	set sql [format $sql ${where_clause} ${set_order}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumDispSorts $rows

	for {set i 0} {$i < $rows} {incr i} {
	
		set DISPLAYSORT($i,disp_sort_id)      [db_get_col $res $i disp_sort_id]
		set DISPLAYSORT($i,disp_code)         [db_get_col $res $i disp_code]
		set DISPLAYSORT($i,disporder)         [db_get_col $res $i disporder]
		set DISPLAYSORT($i,s_name)            [db_get_col $res $i s_name]
	
	}

	tpBindVar dispSortId    DISPLAYSORT disp_sort_id     display_sort_idx
	tpBindVar dispCode      DISPLAYSORT disp_code        display_sort_idx
	tpBindVar dispOrder     DISPLAYSORT disporder        display_sort_idx
	tpBindVar sName         DISPLAYSORT s_name           display_sort_idx

	asPlayFile display_sorts_list.html

	db_close $res
}

#
# ----------------------------------------------------------------------------
# Go to required display sort page
# ----------------------------------------------------------------------------
#
proc go_display_sort args {

	set act [reqGetArg SubmitName]

	if {$act == "GotoAdd"} {
		go_display_sort_add
	} elseif {$act == "GotoUpd"} {
		go_display_sort_upd
	} elseif {$act == "GoAddMktGrpLink"} {
		go_display_sort_mkt_grp_link
	} elseif {$act == "GoAddMktGrpLinkEachType"} {
		go_display_sort_mkt_grp_link_each_type
	} elseif {$act == "GoAddMktGrpLinkFullList"} {
		go_display_sort_mkt_grp_link_full_list
	} elseif {$act == "GoAddMktGrpLinkHub"} {
		go_display_sort_mkt_grp_link_hub
	} elseif {$act == "AddMktGroupLinkByNames"} {
		add_display_sort_mkt_group_link_by_names
	} elseif {$act == "DoAdd"} {
		do_display_sort_add
	} elseif {$act == "DoUpd"} {
		do_display_sort_upd
	} elseif {$act == "Back"} {
		go_display_sort_list
	} else {
		error "unexpected SubmitName: $act"
	}

}

#
# ----------------------------------------------------------------------------
# Delete display sort 
# ----------------------------------------------------------------------------
#
proc del_display_sort args {
	
	set delDispOrderList [reqGetArg delDispOrderList]

	if { $delDispOrderList != ""} {

		# Remove any training commas
		set delDispOrderList [string trimright $delDispOrderList ","]
		

		set sql [subst {
			delete
			from tDispSort
			where
				disp_sort_id in (%s)
		}]
		
		set sql [format $sql ${delDispOrderList}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
			ob::log::write ERROR {ERROR deleting \
			display sort: $msg}
			inf_close_stmt $stmt
			err_bind $msg
			go_display_sort_list
			return
	
		}
	
		catch {inf_close_stmt $stmt}
	}

	go_display_sort_list
}

#
# ----------------------------------------------------------------------------
# Goto the display sort add page 
# ----------------------------------------------------------------------------
#
proc go_display_sort_add args {

	global SPORT
	
	set SportId [reqGetArg SelectedSportId]

	# Get sport details
	bind_sports_list $SportId

	asPlayFile display_sorts_add.html
}

#
# ----------------------------------------------------------------------------
# Add the Display Sort
# ----------------------------------------------------------------------------
#
proc do_display_sort_add args {

	global USERNAME
	
	set sport_id     [reqGetArg SelectedSportId]
	set disporder    [reqGetArg disporder]
	set name         [reqGetArg name]

	if { [OT_CfgGet USE_DISPSORT_DISP_ORDER 0] } {
		set disp_order ", p_disporder = ?"
	} else {
		set disp_order ", p_disporder = -1"
	}

	set sql [subst { execute procedure pInsDisplaySort( \
		p_adminuser = ? , \
		p_sport_id  = ? , \
		p_name     = ? \
		$disp_order \
		) }]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {inf_exec_stmt $stmt $USERNAME \
		$sport_id $name $disporder} msg]} {
		ob::log::write ERROR {ERROR executing \
		pInsDisplaySort stored procedure: $msg}
		inf_close_stmt $stmt
		err_bind $msg
		go_display_sort_list
		return
	}

	catch {inf_close_stmt $stmt}

	go_display_sort_list
}

#
# ----------------------------------------------------------------------------
# Goto the display sort update page 
# ----------------------------------------------------------------------------
#
proc go_display_sort_upd args {

	global SPORT DISP_SORT_MKT_GRP

	set DispSortId [reqGetArg DispSortId]
	tpSetVar DispSortId $DispSortId

	# Get display sort details
	set sql [subst {
		select
			sport_id,
			disp_code,
			disporder
		from 
			tDispSort
		%s
	}]

	set where_clause "where disp_sort_id = $DispSortId"

	set sql [format $sql ${where_clause}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]

	set SportId                  [db_get_col $res 0 sport_id]
	tpBindString SportId         $SportId
	tpBindString DispSortId      $DispSortId
	tpBindString dispCode        [db_get_col $res 0 disp_code]
	tpBindString dispOrder       [db_get_col $res 0 disporder]

	inf_close_stmt $stmt

	# Get sport details
	bind_sports_list $SportId

	# Get display sort links to market groups

	set where_clause "and g.disp_sort_id = $DispSortId"

	set sort [reqGetArg order]

	switch -exact -- $sort {
		"group" {
			set set_order "mkt_group_name"
		}
		default {
			set set_order "type_name"
		}
	}

	set sql [subst {
		select 
			g.ev_oc_grp_id,
			g.ev_type_id,
			g.name as mkt_group_name,
			t.name as type_name
		
		from 
			tEvOcGrp g,
			tEvType t
		
		where
			g.ev_type_id  = t.ev_type_id 
			%s
		order by
			%s
	}]

	set sql [format $sql ${where_clause} ${set_order}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumLinkedMktGrp $rows

	for {set i 0} {$i < $rows} {incr i} {

		set DISP_SORT_MKT_GRP($i,ev_oc_grp_id)   [db_get_col $res $i ev_oc_grp_id]
		set DISP_SORT_MKT_GRP($i,ev_type_id)     [db_get_col $res $i ev_type_id]
		set DISP_SORT_MKT_GRP($i,mkt_group_name) [db_get_col $res $i mkt_group_name]
		set DISP_SORT_MKT_GRP($i,type_name)      [db_get_col $res $i type_name]
	}

	tpBindVar mktGroupId    DISP_SORT_MKT_GRP ev_oc_grp_id       disp_sort_mkt_grp_idx
	tpBindVar typeId        DISP_SORT_MKT_GRP ev_type_id         disp_sort_mkt_grp_idx
	tpBindVar mktGroupName  DISP_SORT_MKT_GRP mkt_group_name     disp_sort_mkt_grp_idx
	tpBindVar typeName      DISP_SORT_MKT_GRP type_name          disp_sort_mkt_grp_idx


	db_close $res

	asPlayFile display_sorts_upd.html
}

#
# ----------------------------------------------------------------------------
# Update the display sort 
# ----------------------------------------------------------------------------
#
proc do_display_sort_upd args {
	
	global USERNAME

	set sport_id     [reqGetArg SelectedSportId]
	set disporder    [reqGetArg disporder]
	set name         [reqGetArg name]
	set DispSortId   [reqGetArg DispSortId]
	tpSetVar DispSortId $DispSortId

	if { [OT_CfgGet USE_DISPSORT_DISP_ORDER 0] } {
		set disp_order ", p_disporder = ?"
	} else {
		set disp_order ", p_disporder = -1"
	}

	set sql [subst { execute procedure pUpdDisplaySort( \
		p_adminuser      = ? , \
		p_disp_sort_id  = ? , \
		p_sport_id  = ? ,\
		p_name     = ? \
		$disp_order ) }]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {inf_exec_stmt $stmt $USERNAME $DispSortId \
		$sport_id $name $disporder} msg]} {
		ob::log::write ERROR {ERROR executing \
		UpdDisplaySort stored procedure: $msg}
		inf_close_stmt $stmt
		err_bind $msg
		go_display_sort_upd
		return
	}

	catch {inf_close_stmt $stmt}

	go_display_sort_upd
}

#
# ----------------------------------------------------------------------------
# Remove links from market groups to a display sort
# ----------------------------------------------------------------------------
#
proc remove_display_sort_mkt_group_link args {
	
	set delMktGroupLinksList [reqGetArg delMktGroupLinksList]
	# if the delMktGroupLinksList is too big delete the links in chunks
	set chunk_size 50

	set disp_sort_id [reqGetArg DispSortId]
	tpSetVar DispSortId $disp_sort_id

	if { $delMktGroupLinksList != ""} {

		# Remove any training commas
		set delMktGroupLinksList [string trimright $delMktGroupLinksList ","]

		set sql [subst {
			update tEvOcGrp
			set 
				disp_sort_id = null 
			where 
				ev_oc_grp_id in (%s)
		}]
		
		set delMktGroupLinkArray [split $delMktGroupLinksList ","]
		set linkListLength [llength $delMktGroupLinkArray]
		
		# If the list is bigger than the chunk_size remove the links in chunks
		while { $linkListLength > $chunk_size } {
			set delMktGroupLinksList [join [lrange $delMktGroupLinkArray 0 [expr $chunk_size -1]] ","]
			set delMktGroupLinkArray [lrange $delMktGroupLinkArray $chunk_size end]
			
			set sql_tmp [format $sql $delMktGroupLinksList]
			set stmt [inf_prep_sql $::DB $sql_tmp]

			if {[catch {inf_exec_stmt $stmt } msg]} {
				ob::log::write ERROR {ERROR removing \
				market group link: $msg}
				inf_close_stmt $stmt
				err_bind $msg
				go_display_sort_upd
				return	
			}
	
			catch {inf_close_stmt $stmt}
			set linkListLength [llength $delMktGroupLinkArray]
		}

		set delMktGroupLinksList [join [lrange $delMktGroupLinkArray 0 end] ","]

		set sql [format $sql ${delMktGroupLinksList}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
			ob::log::write ERROR {ERROR removing \
			market group link: $msg}
			inf_close_stmt $stmt
			err_bind $msg
			go_display_sort_upd
			return	
		}
	
		catch {inf_close_stmt $stmt}
	}

	go_display_sort_upd
}



#
# ----------------------------------------------------------------------------
# Goto the display sort page which allows user to choose how to add links
# ----------------------------------------------------------------------------
#
proc go_display_sort_mkt_grp_link_hub args {
	global DISP_SORT_MKT_GRP_LINK

	set DispSortId [reqGetArg DispSortId]
	tpSetVar DispSortId $DispSortId


        set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set sql [subst {
		select
			d.sport_id,
			d.disp_code,
			d.disporder,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tDispSort d
		where
			s.sport_id = d.sport_id
		and     d.disp_sort_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${DispSortId}]
	inf_close_stmt $stmt

	tpBindString DispSortName          [db_get_col $res 0 disp_code]
	tpBindString DispSortDisporder     [db_get_col $res 0 disporder]
	tpBindString sportName             [db_get_col $res 0 s_name]
	
	asPlayFile display_sorts_link_mktgrp_hub.html
}



#
# ----------------------------------------------------------------------------
# Select the correct method of linking market groups
# ----------------------------------------------------------------------------
#
proc go_display_sort_mkt_grp_link args {
	set link_method [reqGetArg linkMethod]

	if {$link_method == "FullList"} {
		go_display_sort_mkt_grp_link_full_list $args
	} elseif {$link_method == "EachType"} {
		go_display_sort_mkt_grp_link_each_type $args
	} else {
		error "unexpected link method: $link_method"
	}
}



#
# ----------------------------------------------------------------------------
# Goto the display order page which allows user to link to markets groups
# ----------------------------------------------------------------------------
#
proc go_display_sort_mkt_grp_link_each_type args {

	global DISP_SORT_MKT_GRP_LINK

	set DispSortId [reqGetArg DispSortId]
	tpSetVar DispSortId $DispSortId


        set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set sql [subst {
		select
			d.sport_id,
			d.disp_code,
			d.disporder,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tDispSort d
		where
			s.sport_id = d.sport_id
		and     d.disp_sort_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${DispSortId}]
	inf_close_stmt $stmt

	tpBindString DispSortName        [db_get_col $res 0 disp_code]
	tpBindString DispSortDisporder   [db_get_col $res 0 disporder]
	tpBindString sportName           [db_get_col $res 0 s_name]

	set sport_ob_id                  [db_get_col $res 0 ob_id]
	set sport_ob_level               [db_get_col $res 0 ob_level]

	tpBindString clickedObjName       $clicked_obj_name

	tpBindString categoryId [reqGetArg categoryId]

	set PathLevel [reqGetArg PathLevel]

	if { $PathLevel == "" } {
		# Go to root level, but decide whether we start at class or
		# Category for this sport
		if { $sport_ob_level == "y" } {
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
					g.disp_sort_id  as disp_sort_id
				from
					tEvOcGrp g
				where
					g.ev_type_id  = %s

			}]

			tpSetVar PathLevel group
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

			tpSetVar PathLevel type
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

	ob_log::write DEBUG "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	for {set i 0} {$i < $rows} {incr i} {
		set DISP_SORT_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]
		set DISP_SORT_MKT_GRP_LINK($i,id)         [db_get_col $res $i ob_id]

		if { $PathLevel == "type"} {
			if { [db_get_col $res $i disp_sort_id] == "" } {
				set DISP_SORT_MKT_GRP_LINK($i,disabled) ""
			} else {
				set DISP_SORT_MKT_GRP_LINK($i,disabled) "disabled"
			}
		}
	}

	tpBindVar objId       DISP_SORT_MKT_GRP_LINK id     disp_sort_mkt_grp_link_idx
	tpBindVar objName     DISP_SORT_MKT_GRP_LINK name   disp_sort_mkt_grp_link_idx

	if { $PathLevel == "type"} {
		tpBindVar isDisabled  DISP_SORT_MKT_GRP_LINK disabled   disp_sort_mkt_grp_link_idx
	}

	asPlayFile display_sorts_link_mktgrp.html
	db_close $res
}



#
# ----------------------------------------------------------------------------
# Goto the display sort page which allows user to link to markets groups.
# This one gives the user a list of all of the market groups for the given
# sport.
# ----------------------------------------------------------------------------
#
proc go_display_sort_mkt_grp_link_full_list args {

	global DISP_SORT_MKT_GRP_LINK

	set DispSortId [reqGetArg DispSortId]
	tpSetVar DispSortId $DispSortId


    set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set sql [subst {
		select
			d.sport_id,
			d.disp_code,
			d.disporder,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tDispSort d
		where
			s.sport_id = d.sport_id
		and     d.disp_sort_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${DispSortId}]
	inf_close_stmt $stmt

	tpBindString DispSortName        [db_get_col $res 0 disp_code]
	tpBindString DispSortDisporder   [db_get_col $res 0 disporder]
	tpBindString sportName           [db_get_col $res 0 s_name]

	set sport_id                       [db_get_col $res 0 sport_id]
	set sport_ob_id                    [db_get_col $res 0 ob_id]
	set sport_ob_level                 [db_get_col $res 0 ob_level]

	tpBindString sportId             $sport_id
	tpBindString sportObId           $sport_ob_id
	tpBindString sportObLevel        $sport_ob_level

	# Decide whether we start at class or category for this sport
	if { $sport_ob_level == "y" } {
		# Get all classes
		set PathLevel "category"
	} else {
		set PathLevel "class"
	}

	set requiredObjId $sport_ob_id

	# We need to extract details depending on which level we are looking for Category/Class
	switch -exact -- $PathLevel {
		"class" {
			# Get types entries as part of this class
			set sql [subst {
				select distinct
					g.name          as ob_name
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
					g.name          as ob_name
				from
					tEvOcGrp g,
					tEvType t,
					tEvClass c,
					tEvCategory cat
				where
					g.ev_type_id = t.ev_type_id and
					t.ev_class_id  = c.ev_class_id and
					cat.category  = c.category and
					cat.ev_category_id = %s
			}]
		}
	}

	set sql [format $sql ${requiredObjId}]

	ob_log::write DEBUG "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	for {set i 0} {$i < $rows} {incr i} {
		set DISP_SORT_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]
	}

	tpBindVar objName     DISP_SORT_MKT_GRP_LINK name   disp_sort_mkt_grp_link_idx

	asPlayFile display_sorts_link_mktgrp_full_list.html
	db_close $res
}



#
# ----------------------------------------------------------------------------
# Add links between market groups and display sort, enumerating for a set of
# market group names
# ----------------------------------------------------------------------------
#
proc add_display_sort_mkt_group_link_by_names args {

	set disp_sort_id [reqGetArg DispSortId]
	set overwrite_clause ""

	if {[reqGetNumArgs no_overwrite] > 0} {
		set overwrite_clause "tEvOcGrp.disp_sort_id is null and "
	}

	if {[reqGetNumArgs selBoxes] > 0} {
		set sport_ob_id    [reqGetArg sportObId]
		set sport_ob_level [reqGetArg sportObLevel]

		if {![string is integer $disp_sort_id]} {
			error "Invalid display sort ID"
		}

		if {![string is integer $sport_ob_id]} {
			error "Invalid reference"
		}

		if { $sport_ob_level == "y" } {
			set sql [subst {
				update tEvOcGrp
				set disp_sort_id = $disp_sort_id
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
							t.ev_class_id = c.ev_class_id and
							c.category = cat.category and
							cat.ev_category_id = $sport_ob_id
					) and tEvOcGrp.name = ?
			}]

		} else {
			set sql [subst {
				update tEvOcGrp
				set
					disp_sort_id = $disp_sort_id
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

		ob_log::write DEBUG "sql = $sql"
		set stmt [inf_prep_sql $::DB $sql]

		for {set i 0} {$i < [reqGetNumArgs selBoxes]} {incr i} {
			set current_type_name [reqGetNthArg selBoxes $i]

			if {[catch {inf_exec_stmt $stmt $current_type_name} msg]} {
				ob::log::write ERROR {ERROR adding \
				market group link: $msg}
				inf_close_stmt $stmt
				err_bind $msg
				go_display_sort_upd
				return	
			}

		}

		inf_close_stmt $stmt 

	} else {
		error "No market groups received"
	}

	go_display_sort_upd
}


#
# ----------------------------------------------------------------------------
# Add links between market groups and display sorts
# ----------------------------------------------------------------------------
#
proc add_display_sort_mkt_group_link args {
	
	set selMktGroupLinksList [reqGetArg selMktGroupLinksList]

	set disp_sort_id [reqGetArg DispSortId]

	if { $selMktGroupLinksList != ""} {

		# Remove any training commas
		set selMktGroupLinksList [string trimright $selMktGroupLinksList ","]
		
		set sql [subst {
			update tEvOcGrp
			set 
				disp_sort_id = %s
			where 
				ev_oc_grp_id in (%s)
		}]
		
		set sql [format $sql $disp_sort_id ${selMktGroupLinksList}]
		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
			ob::log::write ERROR {ERROR removing \
			market group link: $msg}
			inf_close_stmt $stmt
			err_bind $msg
			go_display_sort_upd
			return	
		}
	
		catch {inf_close_stmt $stmt}
	}

	tpSetVar DispSortId $disp_sort_id
	go_display_sort_upd
}

#
# ----------------------------------------------------------------------------
# Bind the sports list for the dropdown of the display sorts
# ----------------------------------------------------------------------------
#

proc bind_sports_list {sport_id} {

	global SPORT

	set sql {
		select
			sport_id,
			name
		from
			tSport
		order by
			name asc
	}

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumSports $rows

	tpSetVar SportId $sport_id
	tpSetVar SelectedIdx -1
	tpSetVar SelectedSport "All"

	for {set i 0} {$i < $rows} {incr i} {

		set SPORT($i,sport_id)      [db_get_col $res $i sport_id]
		set SPORT($i,name)          [db_get_col $res $i name]
		if { $sport_id == $SPORT($i,sport_id)  } {
			tpSetVar SelectedIdx $i
			tpSetVar SelectedSport $SPORT($i,name)
			tpSetVar DbSelectedSportId $SPORT($i,sport_id)
		}
	}

	tpBindVar sportId       SPORT sport_id     sport_idx
	tpBindVar sportName     SPORT name         sport_idx

	db_close $res
}
}
