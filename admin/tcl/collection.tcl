# ==============================================================
# $Id: collection.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::COLLECTION {

asSetAct ADMIN::COLLECTION::GoCollectionList        [namespace code go_collection_list]
asSetAct ADMIN::COLLECTION::GoCollection            [namespace code go_collection]
asSetAct ADMIN::COLLECTION::DelCollection           [namespace code del_collection]
asSetAct ADMIN::COLLECTION::RemoveMktGroupLink      [namespace code remove_mkt_group_link]
asSetAct ADMIN::COLLECTION::AddMktGroupLink         [namespace code add_mkt_group_link]
asSetAct ADMIN::COLLECTION::AddMktGroupLinkHub      [namespace code add_mkt_group_link_hub]
asSetAct ADMIN::COLLECTION::AddMktGroupLinkByNames  [namespace code add_mkt_group_link_by_names]

#
# ----------------------------------------------------------------------------
# Generate list of sports
# ----------------------------------------------------------------------------
#
proc go_collection_list args {

	global COLLECTION SPORT

	# Deal with Sports first

	set sport_id [reqGetArg SportId]


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
		}
	}

	tpBindVar sportId       SPORT sport_id     sport_idx
	tpBindVar sportName     SPORT name         sport_idx

	set sql {
		select
			mkt_collection_disp
		from
			tControl
	}
	
	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumMktPerCollection [db_get_col $res 0 mkt_collection_disp]


	# Now look in to collection details

	set where_clause ""

	if { $sport_id != "" } {
		set where_clause " and c.sport_id = $sport_id "
	}

	# Get Primary collections for sports (minimum disp order)
	set sql [subst {
		select
			s.name,
			min(c.disporder) as min_disporder
		from
			tCollection c,
			tSport      s
		where
			s.sport_id = c.sport_id
			%s
		group by 1
	}]

	set sql [format $sql ${where_clause}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	for {set i 0} {$i < $rows} {incr i} {
		set sport_name          [db_get_col $res $i name]
		set SPORT($sport_name,min_disporder)  [db_get_col $res $i min_disporder]
	}

	set sort [reqGetArg order]

	switch -exact -- $sort {
		"name" {
			set set_order "c.name, s.name, disporder, expanded"
		}
		"disp" {
			set set_order "disporder, s.name, c.name, expanded"
		}
		"exp" {
			set set_order "expanded desc, s.name, disporder, c.name"
		}
		"prim" {
			# Use the general ordering in query, we'll bind the
			# values to show the ordering by primary
			set set_order "s.name, disporder, c.name, expanded"
		}
		default {
			set set_order "s.name, disporder, c.name, expanded"
		}
	}

	set sql [subst {
		select
			c.collection_id,
			c.name as c_name,
			c.disporder,
			c.expanded,
			s.name as s_name
		from
			tCollection c,
			tSport      s
		where
			s.sport_id = c.sport_id
		%s
		order by
			%s
	}]

	set sql [format $sql ${where_clause} ${set_order}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumCollections $rows

	if { $sort == "prim"} {

		# This is pain, but we'll need to bind the Primary collection details first
		# then the non primary
		set idx 0
		# Do primary only
		for {set i 0} {$i < $rows} {incr i} {
			
			set s_name      [db_get_col $res $i s_name]
			set c_disporder [db_get_col $res $i disporder]

			if { $c_disporder == $SPORT($s_name,min_disporder) } {
				set COLLECTION($idx,primary) "Yes"
				set COLLECTION($idx,collection_id)      [db_get_col $res $i collection_id]
				set COLLECTION($idx,c_name)             [db_get_col $res $i c_name]
				set COLLECTION($idx,disporder)          $c_disporder
				set COLLECTION($idx,expanded)           [db_get_col $res $i expanded]
				set COLLECTION($idx,s_name)             $s_name
				set idx [ expr $idx+1]
			}
		}

		# Now do non primary only
		for {set i 0} {$i < $rows} {incr i} {
			
			set s_name      [db_get_col $res $i s_name]
			set c_disporder [db_get_col $res $i disporder]

			if { $c_disporder != $SPORT($s_name,min_disporder) } {
				set COLLECTION($idx,primary) "No"
				set COLLECTION($idx,collection_id)      [db_get_col $res $i collection_id]
				set COLLECTION($idx,c_name)             [db_get_col $res $i c_name]
				set COLLECTION($idx,disporder)          $c_disporder
				set COLLECTION($idx,expanded)           [db_get_col $res $i expanded]
				set COLLECTION($idx,s_name)             $s_name
				set idx [ expr $idx+1]
			}
		}

	} else {
		for {set i 0} {$i < $rows} {incr i} {
	
			set COLLECTION($i,collection_id)      [db_get_col $res $i collection_id]
			set COLLECTION($i,c_name)             [db_get_col $res $i c_name]
			set COLLECTION($i,disporder)          [db_get_col $res $i disporder]
			set COLLECTION($i,expanded)           [db_get_col $res $i expanded]
			set COLLECTION($i,s_name)             [db_get_col $res $i s_name]
	
			if { $COLLECTION($i,disporder) == $SPORT($COLLECTION($i,s_name),min_disporder) } {
				set COLLECTION($i,primary) "Yes"
			} else {
				set COLLECTION($i,primary) "No"
			}	
		}
	}

	tpBindVar collectionId  COLLECTION collection_id     collection_idx
	tpBindVar cName         COLLECTION c_name            collection_idx
	tpBindVar cDisporder    COLLECTION disporder         collection_idx
	tpBindVar cExpanded     COLLECTION expanded          collection_idx
	tpBindVar cPrimary      COLLECTION primary           collection_idx
	tpBindVar sName         COLLECTION s_name            collection_idx

	asPlayFile collection_list.html

	db_close $res
}

proc bind_collection_data args {

	tpSetVar collection_id [reqGetArg CollectionId]

	tpBindString cName         [reqGetArg cName]
	tpBindString cDisporder    [reqGetArg cDisporder]
	tpBindString cExpanded     [reqGetArg cExpanded]
	tpBindString sportId       [reqGetArg SportId]
}

#
# ----------------------------------------------------------------------------
# Go to required collection page
# ----------------------------------------------------------------------------
#
proc go_collection args {

	set act [reqGetArg SubmitName]

	if {$act == "GotoAdd"} {
		go_collection_add
	} elseif {$act == "GotoUpd"} {
		go_collection_upd
	} elseif {$act == "GoAddMktGrpLink"} {
		go_collection_mkt_grp_link
	} elseif {$act == "GoAddMktGrpLinkEachType"} {
		go_collection_mkt_grp_link_each_type
	} elseif {$act == "GoAddMktGrpLinkFullList"} {
		go_collection_mkt_grp_link_full_list
	} elseif {$act == "GoAddMktGrpLinkHub"} {
		go_collection_mkt_grp_link_hub
	} elseif {$act == "AddMktGroupLinkByNames"} {
		add_mkt_group_link_by_names
	} elseif {$act == "DoAdd"} {
		do_collection_add
	} elseif {$act == "DoUpd"} {
		do_collection_upd
	} elseif {$act == "Back"} {
		go_collection_list
	} elseif {$act == "UpdNumMkts"} {
		do_update_num_disp_mkts
	} else {
		error "unexpected SubmitName: $act"
	}

}

#
# ----------------------------------------------------------------------------
# Delete collections 
# ----------------------------------------------------------------------------
#
proc del_collection args {
	
	set delCollectionList [reqGetArg delCollectionList]

	if { $delCollectionList != ""} {

		# Remove any training commas
		if { [ string range $delCollectionList end end] == "," } {
			set delCollectionList [string range $delCollectionList 0 end-1]
		}

		set sql [subst {
			delete
			from tCollection
			where
				collection_id in (%s)
		}]
		
		set sql [format $sql ${delCollectionList}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
				ob::log::write ERROR {ERROR deleting \
				collection: $msg}
	
				inf_close_stmt $stmt
				err_bind $msg
				go_collection_list
				return
	
		}
	
		catch {inf_close_stmt $stmt}
	}

	go_collection_list
}

#
# ----------------------------------------------------------------------------
# Goto the collection add page 
# ----------------------------------------------------------------------------
#
proc go_collection_add args {

	global SPORT
	
	set SportId [reqGetArg SelectedSportId]

	# Get sport details
	set sql [subst {
		select
			sport_id,
			name
		from 
			tSport
		order by
			name
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumSports $rows

	for {set i 0} {$i < $rows} {incr i} {

		set SPORT($i,sport_id)      [db_get_col $res $i sport_id]
		set SPORT($i,name)          [db_get_col $res $i name]

		if { $SportId == $SPORT($i,sport_id)  } {
			tpSetVar SelectedIdx $i
			tpSetVar SelectedSport $SPORT($i,name)
		}
	}

	tpBindVar sportId       SPORT sport_id     sport_idx
	tpBindVar sportName     SPORT name         sport_idx

	db_close $res

	asPlayFile collection_add.html
}

#
# ----------------------------------------------------------------------------
# Add the collection
# ----------------------------------------------------------------------------
#
proc do_collection_add args {

	global USERNAME
	
	set sport_id     [reqGetArg SelectedSportId]
	set disporder    [reqGetArg disporder]
	set name         [reqGetArg name]
	set expanded     [reqGetArg expanded]
	set primary      [reqGetArg primary]

	if { $primary == "true"} {
		# Lowest disporder will be primary
		set disporder 0
	}

	if { $expanded == "true"} {
		set expanded "Y"
	} else {
		set expanded "N"
	}

	set sql [subst { execute procedure pInsCollection( \
		p_adminuser = ? , \
		p_sport_id  = ? , p_name     = ? , \
		p_disporder = ? , p_expanded = ?) }]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {inf_exec_stmt $stmt $USERNAME \
			$sport_id $name $disporder $expanded} msg]} {
                        ob::log::write ERROR {ERROR executing \
			pInsCollection stored procedure: $msg}

			inf_close_stmt $stmt
                        err_bind $msg
                        go_collection_list
                        return

	}

	catch {inf_close_stmt $stmt}

	go_collection_list
}

#
# ----------------------------------------------------------------------------
# Goto the collection update page 
# ----------------------------------------------------------------------------
#
proc go_collection_upd args {

	global SPORT COL_MKT_GRP

	set CollectionId [reqGetArg CollectionId]
	tpSetVar CollectionId $CollectionId

	# Get collection details
	set sql [subst {
		select
			sport_id,
			name,
			disporder,
			expanded
		from 
			tCollection
		%s
	}]

	set where_clause "where collection_id = $CollectionId"

	set sql [format $sql ${where_clause}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]

	set SportId                  [db_get_col $res 0 sport_id]
	tpBindString SportId         $SportId
	tpBindString CollectionId    $CollectionId
	tpBindString CollectionName  [db_get_col $res 0 name]
	tpBindString CollectionDisp  [db_get_col $res 0 disporder]
	tpSetVar CurrentDisp         [db_get_col $res 0 disporder]
	tpSetVar CollectionExp       [db_get_col $res 0 expanded]

	inf_close_stmt $stmt

	# Get sport details
	set sql [subst {
		select
			sport_id,
			name
		from 
			tSport
		order by
			name
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumSports $rows

	for {set i 0} {$i < $rows} {incr i} {

		set SPORT($i,sport_id)      [db_get_col $res $i sport_id]
		set SPORT($i,name)          [db_get_col $res $i name]

		if { $SportId == $SPORT($i,sport_id)  } {
			tpSetVar SelectedIdx $i
			tpSetVar DbSelectedSportId $SPORT($i,sport_id)
			tpSetVar SelectedSport $SPORT($i,name)
		}
	}

	tpBindVar sportId       SPORT sport_id     sport_idx
	tpBindVar sportName     SPORT name         sport_idx


	# Now look in to collection details
	set where_clause " and c.sport_id = $SportId "

	# Get Primary collections for this sports (minimum disp order)
	set sql [subst {
		select
			min(c.disporder) as min_disporder
		from
			tCollection c,
			tSport      s
		where
			s.sport_id = c.sport_id
			%s
	}]

	set sql [format $sql ${where_clause}]
	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]

	tpSetVar primaryDisp     [db_get_col $res 0 min_disporder]

	# Get collection links to market groups

	set where_clause " and g.collection_id = $CollectionId "

	set sort [reqGetArg order]

	switch -exact -- $sort {
		"group" {
			set set_order "mkt_group_name"
		}
		default {
			set set_order "type_mame"
		}
	}

	set sql [subst {
		select 
			g.ev_oc_grp_id,
			g.ev_type_id,
			g.name as mkt_group_name,
			t.name as type_mame
		
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

		set COL_MKT_GRP($i,ev_oc_grp_id)   [db_get_col $res $i ev_oc_grp_id]
		set COL_MKT_GRP($i,ev_type_id)     [db_get_col $res $i ev_type_id]
		set COL_MKT_GRP($i,mkt_group_name) [db_get_col $res $i mkt_group_name]
		set COL_MKT_GRP($i,type_mame)      [db_get_col $res $i type_mame]
	}

	tpBindVar mktGroupId    COL_MKT_GRP ev_oc_grp_id       col_mkt_grp_idx
	tpBindVar typeId        COL_MKT_GRP ev_type_id         col_mkt_grp_idx
	tpBindVar mktGroupName  COL_MKT_GRP mkt_group_name     col_mkt_grp_idx
	tpBindVar typeName      COL_MKT_GRP type_mame          col_mkt_grp_idx


	db_close $res

	asPlayFile collection_upd.html
}

#
# ----------------------------------------------------------------------------
# Update the collections 
# ----------------------------------------------------------------------------
#
proc do_collection_upd args {
	
	global USERNAME

	set sport_id     [reqGetArg SelectedSportId]
	set disporder    [reqGetArg disporder]
	set name         [reqGetArg name]
	set expanded     [reqGetArg expanded]
	set primary      [reqGetArg primary]
	set collectionId [reqGetArg CollectionId]
	tpSetVar CollectionId $collectionId

	if { $expanded == "true"} {
		set expanded "Y"
	} else {
		set expanded "N"
	}

	set sql [subst { execute procedure pUpdCollection( \
		p_adminuser      = ? , \
		p_collection_id  = ? , \
		p_sport_id  = ? , p_name     = ? , \
		p_disporder = ? , p_expanded = ?) }]

	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {inf_exec_stmt $stmt $USERNAME $collectionId \
			$sport_id $name $disporder $expanded} msg]} {
                        ob::log::write ERROR {ERROR executing \
			pInsCollection stored procedure: $msg}
			inf_close_stmt $stmt
			err_bind $msg
			go_collection_upd

			return

	}

	catch {inf_close_stmt $stmt}

	go_collection_upd
}

#
# ----------------------------------------------------------------------------
# Remove links from market groups to a collection
# ----------------------------------------------------------------------------
#
proc remove_mkt_group_link args {
	
	set delMktGroupLinksList [reqGetArg delMktGroupLinksList]

	set collection_id [reqGetArg CollectionId]
	tpSetVar CollectionId $collection_id

	if { $delMktGroupLinksList != ""} {

		# Remove any training commas
		if { [ string range $delMktGroupLinksList end end] == "," } {
			set delMktGroupLinksList [string range $delMktGroupLinksList 0 end-1]
		}

		set sql [subst {
			update tEvOcGrp
			set 
				collection_id = null 
			where 
				ev_oc_grp_id in (%s)
		}]
		
		set sql [format $sql ${delMktGroupLinksList}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
				ob::log::write ERROR {ERROR removing \
				market group link: $msg}
	
				inf_close_stmt $stmt
				err_bind $msg
				go_collection_upd
				return	
		}
	
		catch {inf_close_stmt $stmt}
	}

	go_collection_upd
}



#
# ----------------------------------------------------------------------------
# Goto the collection page which allows user to choose how to add links
# ----------------------------------------------------------------------------
#
proc go_collection_mkt_grp_link_hub args {
	global COL_MKT_GRP_LINK

	set CollectionId [reqGetArg CollectionId]
	tpSetVar CollectionId $CollectionId


        set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set isPrimary [reqGetArg isPrimary]

	set sql [subst {
		select
			c.sport_id,
			c.name as c_name,
			c.disporder,
			c.expanded,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tCollection c
		where
			s.sport_id = c.sport_id
		and     c.collection_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${CollectionId}]
	inf_close_stmt $stmt

	tpBindString CollectionName        [db_get_col $res 0 c_name]
	tpBindString CollectionDisporder   [db_get_col $res 0 disporder]
	tpSetVar CollectionExp             [db_get_col $res 0 expanded]
	tpBindString CollectionPrimary     $isPrimary
	tpBindString sportName             [db_get_col $res 0 s_name]
	
	asPlayFile collection_link_mktgrp_hub.html
}



#
# ----------------------------------------------------------------------------
# Select the correct method of linking market groups
# ----------------------------------------------------------------------------
#
proc go_collection_mkt_grp_link args {
	set link_method [reqGetArg linkMethod]
	if {$link_method == "FullList"} {
		go_collection_mkt_grp_link_full_list $args
	} elseif {$link_method == "EachType"} {
		go_collection_mkt_grp_link_each_type $args
	} else {
		error "unexpected link method: $link_method"
	}
}



#
# ----------------------------------------------------------------------------
# Goto the collection page which allows user to link to markets groups
# ----------------------------------------------------------------------------
#
proc go_collection_mkt_grp_link_each_type args {

	global COL_MKT_GRP_LINK

	set CollectionId [reqGetArg CollectionId]
	tpSetVar CollectionId $CollectionId


        set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set isPrimary [reqGetArg isPrimary]

	set sql [subst {
		select
			c.sport_id,
			c.name as c_name,
			c.disporder,
			c.expanded,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tCollection c
		where
			s.sport_id = c.sport_id
		and     c.collection_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${CollectionId}]
	inf_close_stmt $stmt

	tpBindString CollectionName        [db_get_col $res 0 c_name]
	tpBindString CollectionDisporder   [db_get_col $res 0 disporder]
	tpSetVar CollectionExp             [db_get_col $res 0 expanded]
	tpBindString CollectionPrimary     $isPrimary
	tpBindString sportName             [db_get_col $res 0 s_name]

	set sport_ob_id                    [db_get_col $res 0 ob_id]
	set sport_ob_level                 [db_get_col $res 0 ob_level]

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
					g.collection_id as collection_id
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

	OT_LogWrite INFO "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	for {set i 0} {$i < $rows} {incr i} {
		set COL_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]
		set COL_MKT_GRP_LINK($i,id)     [db_get_col $res $i ob_id]

		if { $PathLevel == "type"} {
			if { [db_get_col $res $i collection_id] == "" } {
				set COL_MKT_GRP_LINK($i,disabled) ""
			} else {
				set COL_MKT_GRP_LINK($i,disabled) "disabled"
			}
		}
	}

	tpBindVar objId       COL_MKT_GRP_LINK id     col_mkt_grp_link_idx
	tpBindVar objName     COL_MKT_GRP_LINK name   col_mkt_grp_link_idx

	if { $PathLevel == "type"} {
		tpBindVar isDisabled  COL_MKT_GRP_LINK disabled   col_mkt_grp_link_idx
	}

	asPlayFile collection_link_mktgrp.html
	db_close $res
}



#
# ----------------------------------------------------------------------------
# Goto the collection page which allows user to link to markets groups.
# This one gives the user a list of all of the market groups for the given
# sport.
# ----------------------------------------------------------------------------
#
proc go_collection_mkt_grp_link_full_list args {

	global COL_MKT_GRP_LINK

	set CollectionId [reqGetArg CollectionId]
	tpSetVar CollectionId $CollectionId


    set clicked_obj_name  [reqGetArg clickedObjName]
	set requiredObjId   [reqGetArg clickedObjId]

	set isPrimary [reqGetArg isPrimary]

	set sql [subst {
		select
			c.sport_id,
			c.name as c_name,
			c.disporder,
			c.expanded,
			s.name as s_name,
			s.ob_id,
			s.ob_level
		from
			tSport s,
			tCollection c
		where
			s.sport_id = c.sport_id
		and     c.collection_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt ${CollectionId}]
	inf_close_stmt $stmt

	tpBindString CollectionName        [db_get_col $res 0 c_name]
	tpBindString CollectionDisporder   [db_get_col $res 0 disporder]
	tpSetVar CollectionExp             [db_get_col $res 0 expanded]
	tpBindString CollectionPrimary     $isPrimary
	tpBindString sportName             [db_get_col $res 0 s_name]

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

	OT_LogWrite INFO "sql = $sql "

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumEntries $rows

	for {set i 0} {$i < $rows} {incr i} {
		set COL_MKT_GRP_LINK($i,name)   [db_get_col $res $i ob_name]
	}

	tpBindVar objName     COL_MKT_GRP_LINK name   col_mkt_grp_link_idx

	asPlayFile collection_link_mktgrp_full_list.html
	db_close $res
}



#
# ----------------------------------------------------------------------------
# Add links between market groups and collection, enumerating for a set of
# market group names
# ----------------------------------------------------------------------------
#
proc add_mkt_group_link_by_names args {

	set collection_id [reqGetArg CollectionId]
	set overwrite_clause ""

	if {[reqGetNumArgs no_overwrite] > 0} {
		set overwrite_clause "tEvOcGrp.collection_id is null and "
	}

	if {[reqGetNumArgs selBoxes] > 0} {
		set sport_ob_id    [reqGetArg sportObId]
		set sport_ob_level [reqGetArg sportObLevel]

		if {![string is integer $collection_id]} {
			error "Invalid collection ID"
		}

		if {![string is integer $sport_ob_id]} {
			error "Invalid reference"
		}

		if { $sport_ob_level == "y" } {
			set sql [subst {
				update tEvOcGrp
				set collection_id = $collection_id
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
					collection_id = $collection_id
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

		OT_LogWrite INFO "sql = $sql"
		set stmt [inf_prep_sql $::DB $sql]

		for {set i 0} {$i < [reqGetNumArgs selBoxes]} {incr i} {
			set current_type_name [reqGetNthArg selBoxes $i]

			if {[catch {inf_exec_stmt $stmt $current_type_name} msg]} {
					ob::log::write ERROR {ERROR adding \
					market group link: $msg}
		
					inf_close_stmt $stmt
					err_bind $msg
					go_collection_upd
					return	
			}

		}

		inf_close_stmt $stmt 

	} else {
		error "No market groups received"
	}

	go_collection_upd
}


#
# ----------------------------------------------------------------------------
# Add links between market groups and collection
# ----------------------------------------------------------------------------
#
proc add_mkt_group_link args {
	
	set selMktGroupLinksList [reqGetArg selMktGroupLinksList]

	set collection_id [reqGetArg CollectionId]

	if { $selMktGroupLinksList != ""} {

		# Remove any training commas
		if { [ string range $selMktGroupLinksList end end] == "," } {
			set selMktGroupLinksList [string range $selMktGroupLinksList 0 end-1]
		}

		set sql [subst {
			update tEvOcGrp
			set 
				collection_id = %s
			where 
				ev_oc_grp_id in (%s)
		}]
		
		set sql [format $sql $collection_id ${selMktGroupLinksList}]
		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
				ob::log::write ERROR {ERROR removing \
				market group link: $msg}
	
				inf_close_stmt $stmt
				err_bind $msg
				go_collection_upd
				return	
		}
	
		catch {inf_close_stmt $stmt}
	}

	tpSetVar CollectionId $collection_id
	go_collection_upd
}

#
# ----------------------------------------------------------------------------
# Update the number of displayed markets per collection (defined in tControl)
# ----------------------------------------------------------------------------
#
proc do_update_num_disp_mkts args {
	
	set selNumMktPerCollection [reqGetArg NumMktPerCollection]
	set sport_id     [reqGetArg SportId]

	set sql [subst {
		update tControl
		set mkt_collection_disp = %s
	}]

	set sql [format $sql $selNumMktPerCollection]
	set stmt [inf_prep_sql $::DB $sql]

	if {[catch {inf_exec_stmt $stmt } msg]} {
		ob::log::write ERROR {ERROR updating \
		tControl.mkts_collection_disp : $msg}

		inf_close_stmt $stmt
		err_bind $msg

		go_collection_upd
		return	
	}
	
	catch {inf_close_stmt $stmt}

	go_collection_list
}

}
