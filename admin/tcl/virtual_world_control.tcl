


# ==============================================================
# $Id: virtual_world_control.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================


#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#



namespace eval ADMIN::VIRTUALWORLD {

asSetAct ADMIN::VIRTUALWORLD::GoVirtualWorldControl \
		[namespace code go_virtual_world_control]
asSetAct ADMIN::VIRTUALWORLD::DoVirtualWorldControl \
		[namespace code do_virtual_world_control]


##############################################################
# Handlers
##############################################################

#
# Load the admin Screen that manage the virtual world page
#
proc go_virtual_world_control {} {
	
	global DB VW_settings

	# Read virtual world settings from DB
	set nrowsVW  [_read_vw]

	_print_result
	asPlayFile -nocache virtual_world_control.html
}

#
# Update virtual world settings
#
proc do_virtual_world_control {} {

	global DB USERNAME
	global VW_settings

	set sql_vw [subst {
		execute procedure pUpdVirtualWorld(
			p_admin_user = ?,
			p_id = ?,
			p_is_highlight = ?,
			p_disporder = ?,
			p_num_races = ?
		)
	}]

	set stmt_vw [inf_prep_sql $DB $sql_vw]

	set bad 0

	set items_changed [_changed_ids_vw]

	foreach i $items_changed {
		 
		if {[catch { set res_vw [inf_exec_stmt $stmt_vw \
			$USERNAME \
			$VW_settings($i,id) \
			$VW_settings($i,is_highlight) \
			$VW_settings($i,disporder) \
			$VW_settings($i,num_races) \
			]} msg]} {
				err_bind $msg
				set bad 1
			} else {
					catch {db_close $res_vw}

			}
	}

	_print_result
	asPlayFile -nocache virtual_world_control.html

}



##############################################################
# Private utils
##############################################################

#
# Read the settings of virtual world page from the database
#
proc _read_vw {} {

	global DB
	global VW_settings

	GC::mark VW_settings

	set sql_vw [subst {
		select
			ev_class_ids,
			virtual_world_id,
			desc,
			is_highlight,
			disporder,
			num_races
		from
			tVirtualWorldCfg
		order by
			disporder
	}]

	set stmt_vw    [inf_prep_sql $DB $sql_vw]
	set res_vw     [inf_exec_stmt $stmt_vw]
	inf_close_stmt $stmt_vw

	set nrowsVW [db_get_nrows $res_vw]

	for {set i 0} {$i < $nrowsVW} {incr i} {

		set VW_settings($i,id)  \
			[db_get_col $res_vw $i virtual_world_id]
		set VW_settings($i,desc) \
			[db_get_col $res_vw $i desc]
		set VW_settings($i,is_highlight) \
			[db_get_col $res_vw $i is_highlight]
		set VW_settings($i,disporder) \
			[db_get_col $res_vw $i disporder]

		set num_races            [db_get_col $res_vw $i num_races]

		set VW_settings($i,num_races)      $num_races
	}

	catch {db_close $res_vw}

	tpSetVar nrowsVW $nrowsVW
	return $nrowsVW

}

#
# Check which elements the user has changed and retur a list of its ids.
# Update the VW_settings array for use it to upd the database
#
proc _changed_ids_vw {} {

	global DB
	global VW_settings

	#Read virtual world settings from DB
	set nrowsVW [_read_vw]

	# Compare DB data with form data
	set modified_idx [list]

	for {set i 0} {$i < $nrowsVW} {incr i} {

		set id_db               $VW_settings($i,id)

		set    disporder_param   $id_db
		set    num_races_param   $id_db
		set    is_highlight_val  $id_db 

		append disporder_param  "disporder"
		append num_races_param  "numRaces"
		append is_highlight_val "isHighlight"

		set disporder_form      [reqGetArg $disporder_param]
		set num_races_form      [reqGetArg $num_races_param]
		set is_highlight_form   [reqGetArg is_highlight]

		if {$is_highlight_form == $is_highlight_val} {
			set is_highlight_form "Y"
		} else {
			set is_highlight_form "N"
		}

		if {($is_highlight_form != $VW_settings($i,is_highlight)) || \
		($disporder_form != $VW_settings($i,disporder)) || \
		($num_races_form != $VW_settings($i,num_races))} {

			set VW_settings($i,is_highlight) $is_highlight_form
			set VW_settings($i,disporder)    $disporder_form
			set VW_settings($i,num_races)    $num_races_form

			lappend modified_idx $i
		}

	}

	return $modified_idx
	
}


#
# Prints Result
#
proc _print_result {} {
	global VW_settings

	tpSetVar readOnlyNumRaces ""

	tpBindVar vw_id       VW_settings  id             virtual_world_idx
	tpBindVar desc        VW_settings  desc           virtual_world_idx
	tpBindVar isHighlight VW_settings  is_highlight   virtual_world_idx
	tpBindVar disporder   VW_settings  disporder      virtual_world_idx
	tpBindVar numRaces    VW_settings  num_races      virtual_world_idx

}
}