# ==============================================================
# $Id: bir.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================
# Used to manage the Betting in Running app
#
namespace eval ADMIN::BIR {

asSetAct ADMIN::BIR::SetRes                [namespace code do_res]
asSetAct ADMIN::BIR::go_bir                [namespace code go_bir]
asSetAct ADMIN::BIR::do_bir                [namespace code do_bir]
asSetAct ADMIN::BIR::go_bir_refresh        [namespace code go_bir_refresh]
asSetAct ADMIN::BIR::go_bir_tab_detail     [namespace code go_bir_tab_detail]
asSetAct ADMIN::BIR::go_bir_add_templ_map  [namespace code go_bir_add_templ_map]
asSetAct ADMIN::BIR::go_bir_add_templ      [namespace code go_bir_add_templ]
asSetAct ADMIN::BIR::go_bir_add_tab        [namespace code go_bir_add_tab]
asSetAct ADMIN::BIR::do_bir_dd             [namespace code go_dd]
asSetAct ADMIN::BIR::go_bir_add_mkt_map    [namespace code go_bir_add_mkt_map]

variable SQL


set SQL(get_languages) {
	select
		lang
	from
		tLang
	where
		displayed = 'Y'
	order by
		disporder asc
}

set SQL(get_bir_info) {
	select
		refresh_id,
		file_type,
		refresh_time
	from
		tBIRRefresh
	where
		ref_class_id = ?
}

set SQL(get_default_bir_info) {
	select
		refresh_id,
		file_type,
		refresh_time
	from
		tBIRRefresh
	where
		ref_class_id is null
}

set SQL(ins_bir_refresh) {
	execute procedure pInsBIRRefresh(
		p_adminuser       = ?,
		p_file_type       = ?,
		p_ref_class_id    = ?,
		p_refresh_time    = ?
	)
}

set SQL(upd_bir_refresh) {
	execute procedure pUpdBIRRefresh(
		p_adminuser       = ?,
		p_file_type       = ?,
		p_ref_class_id    = ?,
		p_refresh_time    = ?
	)
}

set SQL(del_bir_refresh) {
	execute procedure pDelBIRRefresh(
		p_adminuser       = ?,
		p_file_type       = ?,
		p_ref_class_id    = ?
	)
}

set SQL(ins_bir_schedule) {
	execute procedure pInsBIRSchedule(
		p_adminuser       = ?,
		p_day             = ?,
		p_mode            = ?
	)
}

set SQL(upd_bir_schedule) {
	execute procedure pUpdBIRSchedule(
		p_adminuser       = ?,
		p_day             = ?,
		p_mode            = ?
	)
}


# Get the details of a specific sport tab
set SQL(get_sport_tab)  {
	select
		s.sport_name,
		s.ob_id,
		s.ob_level,
		s.lang,
		s.disp_order
	from
		tBIRSportTab s
	where
		s.tab_id = ?
}

# As they wanted the market mapping to be none tab / language
set SQL(get_bir_mkt_maps) {
	select
		unique(k.mkt_name) mkt_name,
		k.disp_order,
		t.name
	from
		tBIRTemplate    t,
		tBIRTemplateMap m,
		tBIRSportTab    s,
		tBIRTabMktMap   k
	where
		k.tab_id          = m.tab_id
		and k.template_id = m.template_id
		and t.template_id = m.template_id
		and s.tab_id      = k.tab_id
		and t.template_id = ?
		and s.ob_id       = ?
		and s.ob_level    = ?
	order by
		k.disp_order
	}

set SQL(upd_bir_mkt_map) {
	execute procedure pInsBIRTabMktMap (
		p_ob_id       = ?,
		p_ob_level    = ?,
		p_template_id = ?,
		p_mkt_name    = ?,
		p_disp_order  = ?
	)
}

# Get list of classes that are not currently being used
set SQL(get_class_list) {
	select
		ev_class_id,
		name,
		disporder
	from
		tEvClass
	where
		ev_class_id not in
		(
			select unique ref_class_id from tBIRRefresh where ref_class_id is not null
		)
	order by
		disporder, name
}

set SQL(get_refresh_by_class) {
	select
		c.ev_class_id,
		c.name,
		c.disporder,
		b1.refresh_time as event_refresh,
		b2.refresh_time as comm_refresh
	from
		tEvClass c,
		outer tBIRRefresh b1,
		outer tBIRRefresh b2
	where
		c.ev_class_id = ? and
		b1.ref_class_id is not null and
		b1.ref_class_id  = c.ev_class_id and
		b1.file_type     = 'EVENT' and
		b2.ref_class_id is not null and
		b2.ref_class_id  = c.ev_class_id and
		b2.file_type     = 'COMM'
}

set SQL(get_bir_classes) {
	select
		c.ev_class_id,
		c.name,
		c.disporder,
		nvl(b1.refresh_time, '-') as event_refresh,
		nvl(b2.refresh_time, '-') as comm_refresh
	from
		tEvClass c,
		outer tBIRRefresh b1,
		outer tBIRRefresh b2
	where
		b1.ref_class_id is not null and
		b1.ref_class_id  = c.ev_class_id and
		b1.file_type     = 'EVENT' and
		b2.ref_class_id is not null and
		b2.ref_class_id  = c.ev_class_id and
		b2.file_type     = 'COMM'
	order by
		disporder, name
}


set SQL(get_schedule_views) {
	select
		day,
		mode
	from
		tBIRSchedule
}

set SQL(get_bir_display_option) {
	select
		display_mini,
		display_cs,
		display_fe
	from
		tBIRFlashControl
}

set SQL(upd_bir_display_option) {
	execute procedure pUpdBIRFlashControl (
		p_adminuser    = ?,
		p_display_mini = ?,
		p_display_cs   = ?,
		p_display_fe = ?
	)
}


set SQL(upd_bir_templ_map) {
	execute procedure pInsBIRTemplateMap (
		p_tab_id      = ?,
		p_template_id = ?,
		p_disp_order  = ?
	)
}

set SQL(del_bir_mkt_map) {
	delete from
		tBIRTabMktMap
	where
		template_id  = ?    and
		mkt_name     = ?    and
		tab_id in (
			select
				tab_id
			from
				tBIRSportTab
			where
				ob_id        = ?
				and ob_level = ?
		)
}

# Returns the template maps for a given sports tab
# Only when a mapping to a market name is complete
set SQL(get_bir_template_maps) {
	select
		m.tab_id,
		k.mkt_name,
		t.name as templ_name,
		t.template_id,
		m.disp_order as templ_disp_order
	from
		tBIRTemplateMap m,
		tBIRTabMktMap   k,
		tBIRTemplate    t
	where
		m.tab_id          = k.tab_id
		and m.template_id = k.template_id
		and t.template_id = m.template_id
		and k.mkt_name is not null
		and m.tab_id      = ?
	order by
		t.name desc
}

set SQL(get_bir_template_map) {
	select
		t.template_id,
		t.name         as templ_name,
		m.disp_order   as templ_disp_order
	from
		tBIRTemplateMap m,
		tBIRTabMktMap   k,
		tBIRTemplate    t
	where
		k.template_id     = m.template_id
		and m.tab_id      = k.template_id
		and t.template_id = m.template_id
		and m.template_id = ?
		and m.tab_id      = ?

}

set SQL(get_bir_tab_templ_maps) {
	select
		s.sport_name,
		m.template_id,
		k.mkt_name as mkt_name,
		t.name as templ_name,
		m.disp_order as templ_disp_order
	from
		tBIRTemplateMap m,
		tBIRTabMktMap   k,
		tBIRSportTab    s,
		tBIRTemplate    t
	where
		m.tab_id          = k.tab_id
		and m.template_id = k.template_id
		and t.template_id = m.template_id
		and m.tab_id      = s.tab_id
		and k.mkt_name    is not null
		and s.tab_id      = ?
	order by
		t.name desc

}

set SQL(get_bir_tab_templates) {
	select
		s.sport_name,
		s.lang,
		t.template_id,
		t.name,
		nvl(m.disp_order,'1000') as disp_order
	from
		outer(tBIRTemplateMap m),
		tBIRTemplate          t ,
		tBIRSportTab          s

	where
		s.tab_id      = ?               and
		m.template_id = t.template_id   and
		m.tab_id      = s.tab_id
	order by
		m.disp_order   asc,
		t.name         asc
		
}

set SQL(get_bir_templates) {
	select
		t.template_id,
		t.name
	from
		tBirTemplate t
	order by
		t.name desc
}


set SQL(get_market_names) {
	select distinct
		o.name    as mkt_name
	from
		tBIRSportTab s,
		tEvCategory  y,
		tEvClass     c,
		tEvType      t,
		tEvOcGrp     o
	where
		y.category    = c.category        and
		c.ev_class_id = t.ev_class_id     and
		o.ev_type_id  = t.ev_type_id      and

		s.tab_id      = ?                 and
		(
		(s.ob_id      = y.ev_category_id  and
		 s.ob_level   = 'y'
		)
		or
		(s.ob_id      = c.ev_class_id     and
		 s.ob_level   = 'c'
		)
		)                                 and
		not exists
		(
			select
				template_id
			from
				tBIRTabMktMap m
			where
					m.tab_id   = s.tab_id and
					m.mkt_name = o.name
		)

	order by
		o.name asc
}

set SQL(get_bir_template) {
	select
		t.template_id,
		t.name
	from
		tBirTemplate    t
	where
		t.template_id = ?
}

set SQL(upd_bir_template) {
	execute procedure pInsBIRTemplate (
		p_template_id = ?,
		p_name        = ?
	)
}

set SQL(get_bir_tab) {
	select
		t.tab_id,
		t.sport_name,
		t.ob_id,
		t.ob_level,
		(case t.ob_level when 'y' then "CATEGORY" when 'c' then "CLASS" end) as level_desc,
		(case t.ob_level
			when 'y' then (select name from tEvCategory where ev_category_id = t.ob_id)
			when 'c' then (select name from tEvClass where ev_class_id = t.ob_id)
		end) as ob_name,
		t.lang,
		t.disp_order
	from
		tBIRSportTab t
	where
		t.tab_id = ?
}

set SQL(get_sports) {
	select
		s.sport_id,
		s.name
	from
		tSport s
	order by
		name asc
}

set SQL(get_sport_group) {
	select
		s.ob_id,
		s.ob_level,
		s.name
	from
		tSport s
	where
		s.sport_id = ?
}

set SQL(get_sport_group_by_id) {
	select
		s.sport_id,
		s.name
	from
		tSport s
	where
		s.ob_id    = ? and
		s.ob_level = ?
}

set SQL(get_bir_tab_maps) {
	select
		t.tab_id,
		t.sport_name,
		t.ob_id,
		t.ob_level,
		(case t.ob_level when 'y' then "CATEGORY" when 'c' then "CLASS" end) as level_desc,
		(case t.ob_level
			when 'y' then (select name from tEvCategory where ev_category_id = t.ob_id)
			when 'c' then (select name from tEvClass where ev_class_id = t.ob_id)
		end) as name,
		t.lang,
		t.disp_order
	from
		tBIRSportTab t
	where
		t.lang = ?
	order by
		t.disp_order asc
}

set SQL(del_bir_tab_map) {
	execute procedure pDelBIRSportTab (
		p_tab_id = ?
	)
}

set SQL(upd_bir_tab_map) {
	execute procedure  pInsBIRSportTab (
		p_tab_id     = ?,
		p_sport_name = ?,
		p_ob_id      = ?,
		p_ob_level   = ?,
		p_lang       = ?,
		p_disp_order = ?
	)
}



proc do_bir_delete_tab {} {
	global DB
	variable SQL

	set tab_id [reqGetArg TabId]

	if {[catch {

		set stmt [inf_prep_sql $DB $SQL(del_bir_tab_map)]
		inf_exec_stmt $stmt $tab_id
		inf_close_stmt $stmt

	} err_msg]} {

		tpBindString tabDBActionError "There was an error deleting the tab map."
		OT_LogWrite 1 "Failed to insert bir tab map: $err_msg"

	} else {
		tpBindString tabDBActionSuccess "Sucessfully deleted sports tab."
	}

	# Replay the page
	go_bir

}



proc do_bir_add_tab {} {
	global DB
	variable SQL

	set map_id   [reqGetArg MapId]

	set sport_id [reqGetArg SportId]

	# Get specific sport detail
	set stmt [inf_prep_sql $DB $SQL(get_sport_group)]
	set rs   [inf_exec_stmt $stmt $sport_id]

	inf_close_stmt $stmt	

	set ob_level      [db_get_col $rs 0 ob_level]
	set ob_id         [db_get_col $rs 0 ob_id]
	set sport_name    [db_get_col $rs 0 name]

	db_close $rs

	set lang           [reqGetArg TabLang]
	set disp_order     [reqGetArg DispOrder]
	set tab_sport_name $sport_name

	set stmt [inf_prep_sql $DB $SQL(upd_bir_tab_map)]

	set action [expr {$map_id == "" ? "Insert" : "Update"}]

	if {[catch {
		OT_LogWrite 20 "Inserting new tab with '$map_id' '$tab_sport_name' \
			'$ob_id' '$ob_level' '$lang' '$disp_order'"
		inf_exec_stmt $stmt $map_id $tab_sport_name \
			$ob_id $ob_level $lang $disp_order
		inf_close_stmt $stmt
	} err_msg]} {
		tpBindString tabDBActionError "There was an error inserting the new tab map."
		OT_LogWrite 1 "Failed to insert bir tab map: $err_msg"
	} else {
		tpBindString tabDBActionSuccess "Sucessfully $action sports tabe."
	}

	# Replay the page with the update info on
	go_bir
}

proc do_bir_del_templ_map {} {

	global DB
	variable SQL

	set tab_id      [reqGetArg TabId]
	set template_id [reqGetArg TemplId]
	set mkt_name    [reqGetArg mkt_name]


	set stmt [inf_prep_sql $DB $SQL(del_bir_templ_map)]

	if {[catch {
		inf_exec_stmt $stmt $tab_id $template_id $mkt_name
	} err_msg]} {
		OT_LogWrite 1 "BIR ERROR: The template map was not deleted. $err_msg"
		tpBindString templDBActionError \
			"There was a error the template map was not deleted $err_msg"
	} else {
		tpBindString templDBActionSuccess "Succesfully deleted Template Map."
	}

	inf_close_stmt $stmt

	# Replay the template mapping page
	bind_tab_templ_maps
}

proc do_bir_del_mkt_map {} {
	global DB
	variable SQL

	set mkt_name    [reqGetArg DelMktName]
	set template_id [reqGetArg TemplId]
	set tab_id      [reqGetArg TabId]

	set ob_id    [reqGetArg ObId]
	set ob_level [reqGetArg ObLevel]

	set stmt [inf_prep_sql $DB $SQL(del_bir_mkt_map)]

	if {[catch {
		inf_exec_stmt $stmt $template_id $mkt_name $ob_id $ob_level
	} err_msg]} {
		OT_LogWrite 1 "BIR ERROR: The template map was not deleted. $err_msg"
		tpBindString templDBActionError \
			"There was a error the template map was not deleted $err_msg"
	} else {
		tpBindString templDBActionSuccess "Succesfully deleted Template Map."
	}

	inf_close_stmt $stmt

	go_bir_add_mkt_map $tab_id $template_id $ob_id $ob_level

}

proc do_bir_add_mkt_map {} {
	global DB
	variable SQL

	set mkt_name    [reqGetArg MktName]
	set disp_order  [reqGetArg DispOrder]
	set template_id [reqGetArg TemplId]
	set tab_id      [reqGetArg TabId]

	set ob_id    [reqGetArg ObId]
	set ob_level [reqGetArg ObLevel]

	set stmt [inf_prep_sql $DB $SQL(upd_bir_mkt_map)]

	if {[catch {
		inf_exec_stmt $stmt $ob_id $ob_level $template_id $mkt_name $disp_order

	} err_msg]} {
		OT_LogWrite 1 "BIR ERROR: The template map was not updated. $err_msg"
		tpBindString templDBActionError \
			"There was a error the template map was not updated $err_msg"
	} else {
		tpBindString templDBActionSuccess "Succesfully updated Template Map."
	}

	inf_close_stmt $stmt

	go_bir_add_mkt_map $tab_id $template_id $ob_id $ob_level
}

proc go_bir_add_mkt_map {{tab_id ""} {template_id ""} {ob_id ""} {ob_level ""}} {
	global DB TATMAPS
	variable SQL

	array set TATMAPS [list]

	if {$tab_id == ""} {
		set tab_id [reqGetArg TabId]
	}

	if {$template_id == ""} {
		set template_id [reqGetArg TemplId]
	}

	if {$ob_id == ""} {
		set ob_id [reqGetArg ob_id]
	}

	if {$ob_level == ""} {
		set ob_level [reqGetArg ob_level]
	}

	# Variables bound
	set templ_name ""

	set nrows 0

	if {$tab_id != "" && $template_id != ""} {

		set stmt [inf_prep_sql $DB $SQL(get_sport_tab)]
		set rs_tab [inf_exec_stmt $stmt $tab_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs_tab] == 1} {
			set ob_id      [db_get_col $rs_tab ob_id]
			set ob_level   [db_get_col $rs_tab ob_level]
			set sport_name [db_get_col $rs_tab sport_name]
			set tab_lang   [db_get_col $rs_tab lang]
			db_close $rs_tab
		} else {
			db_close $rs_tab
			OT_LogWrite 5 "Unable to find tab for tab_id '$tab_id'"
			return -1
		}

		set stmt [inf_prep_sql $DB $SQL(get_bir_mkt_maps)]
		set rs [inf_exec_stmt $stmt $template_id $ob_id $ob_level]

		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		for {set r 0} {$r < $nrows} {incr r} {
			if {$r == 0} {
				set templ_name [db_get_col $rs 0 name]
			}

			set TATMAPS($r,disp_order) [db_get_col $rs $r disp_order]
			set TATMAPS($r,mkt_name)   [db_get_col $rs $r mkt_name]
		 }

		db_close $rs
	}

	tpBindVar   tatempl_MktName       TATMAPS   mkt_name    tatempl_idx
	tpBindVar   tatempl_MktDispOrder  TATMAPS   disp_order  tatempl_idx

	tpSetVar NumberTabMktMaps $nrows

	bind_markets $tab_id

	tpBindString ObId      $ob_id
	tpBindString ObLevel   $ob_level
	tpBindString SportName $sport_name
	tpBindString TabLang   $tab_lang
	tpBindString TabId     $tab_id
	tpBindString TemplId   $template_id
	tpBindString TemplName $templ_name

	asPlayFile -nocache bir_mkt_tmpl_map.html
}



proc do_bir_add_templ_map {} {
	global DB
	variable SQL

	set template_id [reqGetArg TemplId]
	set tab_id      [reqGetArg TabId]
	set disp_order  [reqGetArg DispOrder]

	set stmt [inf_prep_sql $DB $SQL(upd_bir_templ_map)]

	if {[catch {
		inf_exec_stmt $stmt $tab_id $template_id $disp_order

	} err_msg]} {
		OT_LogWrite 1 "BIR ERROR: The template map was not inserted. $err_msg"
		tpBindString templDBActionError \
			"There was a error the template map was not inserted $err_msg"
	} else {
		tpBindString templDBActionSuccess "Succesfully inserted the Template Map."
	}

	inf_close_stmt $stmt

	# Replay the tab template map
	go_bir_tab_detail $tab_id
}



proc go_bir_add_templ_map {} {
	global DB
	variable SQL

	set tab_id [reqGetArg TabId]

	if {$tab_id != ""} {
		set stmt [inf_prep_sql $DB $SQL(get_bir_template_map)]
		set rs [inf_exec_stmt $stmt $tab_id]

		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {

			tpBindString templm_Template_Id [db_get_col $rs 0 template_id]
			tpBindString templm_MktName     [db_get_col $rs 0 mkt_name]
			tpBindString templm_DispOrder   [db_get_col $rs 0 templ_disp_order]

			# Used to set the template as SELECTED in the drop down
			set template_id [db_get_col $rs 0 template_id]
		}

		db_close $rs
	}

	bind_tab_templates

	tpBindString TabId $tab_id

	asPlayFile -nocache bir_templ_map.html
}



proc bind_tab_templ_maps {{tab_id ""}} {

	global DB TATMAPS
	variable SQL

	if {$tab_id == ""} {
		set tab_id [reqGetArg TabId]
	}

	if {$tab_id == ""} {
		error "No sport_tab_id Mapping ID was passed"
	}

	set stmt [inf_prep_sql $DB $SQL(get_bir_tab_templ_maps)]
	set rs   [inf_exec_stmt $stmt $tab_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set TATMAPS($r,sport_name)   [db_get_col $rs $r sport_name]
		set TATMAPS($r,template_id)  [db_get_col $rs $r template_id]
		set TATMAPS($r,templ_name)   [db_get_col $rs $r templ_name]
		set TATMAPS($r,disp_order)   [db_get_col $rs $r templ_disp_order]
		set TATMAPS($r,mkt_name)     [db_get_col $rs $r mkt_name]
	}

	tpBindVar   tatempl_SportName    TATMAPS    sport_name    tatempl_idx
	tpBindVar   tatempl_TemplId      TATMAPS    template_id   tatempl_idx
	tpBindVar   tatempl_TemplName    TATMAPS    templ_name    tatempl_idx
	tpBindVar   tatempl_DispOrder    TATMAPS    disp_order    tatempl_idx
	tpBindVar   tatempl_MktName      TATMAPS    mkt_name      tatempl_idx

	tpSetVar NumberTabTemplMaps $nrows

	db_close $rs

	tpBindString TabId $tab_id

}



proc go_bir_tab_detail {{tab_id ""}} {

	bind_tab_templates $tab_id
	asPlayFile -nocache bir_tab_setup.html
}



proc go_bir_add_tab {} {
	global DB
	variable SQL
	global SPORT

	set map_id [reqGetArg map_id]

	if {$map_id != ""} {
		set stmt [inf_prep_sql $DB $SQL(get_bir_tab)]
		set rs   [inf_exec_stmt $stmt $map_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			tpBindString tab_map_id      [db_get_col $rs 0 tab_id]
			tpBindString tab_sport_name  [db_get_col $rs 0 sport_name]
			tpBindString tab_ob_name     [db_get_col $rs 0 ob_name]

			set ob_id                    [db_get_col $rs 0 ob_id]
			tpBindString tab_ob_id       $ob_id

			set ob_level                 [db_get_col $rs 0 ob_level]
			tpBindString tab_ob_level    $ob_level

			tpBindString tab_ob_lvl_desc [db_get_col $rs 0 level_desc]

			tpBindString tab_lang        [db_get_col $rs 0 lang]
			tpBindString tab_disp_order  [db_get_col $rs 0 disp_order]

			# Used to bind the language drop down to the selected value
			reqSetArg TabLanguage [db_get_col $rs 0 lang]

			db_close $rs

			# Now get Sport info
			set stmt [inf_prep_sql $DB $SQL(get_sport_group_by_id)]
			set rs   [inf_exec_stmt $stmt $ob_id $ob_level]
			inf_close_stmt $stmt

			if {[db_get_nrows $rs] == 1} {
				tpBindString sport_id    [db_get_col $rs 0 sport_id]
				tpBindString sport_name  [db_get_col $rs 0 name]
				db_close $rs
			} else {
				# This is to catch any existing entries in tBIRSportTab that 
				# we have yet to define a matching sport for it in tSport
				tpBindString sport_id    "undefined"
				tpBindString sport_name  "undefined"
			}
		} else {
			OT_LogWrite 5 "BIR:: The Map ID '$map_id' returned no rows."
			error "'$map_id' is not an existing sport tab map."
		}

	} else {
		tpSetVar InsertMode 1

		# Get sports info
		set stmt [inf_prep_sql $DB $SQL(get_sports)]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt	
	
		set rows [db_get_nrows $rs]
		tpSetVar NumSports $rows
	
		for {set i 0} {$i < $rows} {incr i} {
			set SPORT($i,sport_id)      [db_get_col $rs $i sport_id]
			set SPORT($i,name)          [db_get_col $rs $i name]
		}
	
		db_close $rs
	
		tpBindVar sportId       SPORT sport_id     sport_idx
		tpBindVar sportName     SPORT name         sport_idx

	}

	bind_langs

	asPlayFile -nocache bir_add_tab.html
}



proc bind_langs {} {
	global DB LANGS
	variable SQL

	# Bind up the classes
	set stmt [inf_prep_sql $DB $SQL(get_languages)]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	array set LANGS [list]

	set lang [reqGetArg TabLanguage]

	set index 0
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {

		set LANGS($index,lang)		[db_get_col $rs $r lang]

		# Default to first lang by disp order in tLang
		if {$lang == ""} {
			set lang $LANGS($index,lang)
			# Used internally to set default lang
			set LANGS(default) $LANGS($index,lang)
		}


		set LANGS($index,selected) ""

		if {$LANGS($index,lang) == $lang} {
			set LANGS($index,selected) "SELECTED"
		}

		incr index
	}


	tpBindVar    lang_Name       LANGS     lang        lang_idx
	tpBindVar    lang_Selected   LANGS     selected    lang_idx
	tpSetVar NumberLangs $index

	db_close $rs

}



proc bind_markets {tab_id {market_name ""}} {
	global DB MARKS
	variable SQL

	set seln_mkt_name [reqGetArg SelnMarketName]

	if {$seln_mkt_name != ""} {
		set market_name $seln_mkt_name
	}

	set stmt [inf_prep_sql $DB $SQL(get_market_names)]
	set rs   [inf_exec_stmt $stmt $tab_id]
	inf_close_stmt $stmt

	array set MARKS [list]

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set MARKS($r,market_name) [db_get_col $rs $r mkt_name]

		if {[db_get_col $rs $r mkt_name] != $market_name} {
			set MARKS($r,selected) ""
		} else {
			set MARKS($r,selected) "SELECTED"
		}
	}

	tpBindVar	marks_MktName	MARKS	market_name	marks_idx
	tpBindVar	marks_Selected	MARKS	selected	marks_idx

	tpSetVar NumberMarketNames [db_get_nrows $rs]

}



proc bind_tab_templates {{tab_id ""}} {
	global DB TEMPL
	variable SQL

	if {$tab_id == ""} {
		# Selected on screen template
		set tab_id [reqGetArg TabId]
	}

	set stmt [inf_prep_sql $DB $SQL(get_bir_tab_templates)]
	set rs   [inf_exec_stmt $stmt $tab_id]
	inf_close_stmt $stmt

	array set TEMPL [list]

	set index 0
	for {set r 0} { $r < [db_get_nrows $rs]} {incr r} {

		if {$r == 0} {
			tpBindString SportName [db_get_col $rs 0 sport_name]
			tpBindString TabLang   [db_get_col $rs 0 lang]
		}
		set TEMPL($index,template_id) [db_get_col $rs $r template_id]
		set TEMPL($index,name)        [db_get_col $rs $r name]
		set disp_order                [db_get_col $rs $r disp_order]

		set TEMPL($index,disp_order)  [expr {$disp_order == 1000 ? "--" : $disp_order}]

		incr index
	}

	db_close $rs

	tpBindVar   templ_Id         TEMPL      template_id    templ_idx
	tpBindVar   templ_Name       TEMPL      name           templ_idx
	tpBindVar   templ_DispOrder  TEMPL      disp_order     templ_idx

	tpBindString TabId $tab_id

	tpSetVar NumberTabTemplates $index
}



proc bind_template_maps {} {
	global DB TEMPL_MAP
	variable SQL

	set map_id [reqGetArg MapId]

	# Bind up the classes
	set stmt [inf_prep_sql $DB $SQL(get_bir_template_maps)]
	set rs   [inf_exec_stmt $stmt $map_id]
	inf_close_stmt $stmt

	array set TEMPL_MAP [list]

	set index 0
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set TEMPL_MAP($index,map_id)           [db_get_col $rs $r tab_id]
		set TEMPL_MAP($index,mkt_name)         [db_get_col $rs $r mkt_name]
		set TEMPL_MAP($index,templ_name)       [db_get_col $rs $r templ_name]
		set TEMPL_MAP($index,templ_disp_ord)   [db_get_col $rs $r templ_disp_order]

		incr index
	}

	db_close $rs

	tpBindVar templm_MapId      TEMPL_MAP      map_id           templm_idx
	tpBindVar templm_MktName    TEMPL_MAP      mkt_name         templm_idx
	tpBindVar templm_TemplName  TEMPL_MAP      templ_name       templm_idx
	tpBindVar templm_DispOrder  TEMPL_MAP      templ_disp_ord   templm_idx

	tpSetVar NumberTemplMaps $index
}



proc do_bir_add_templ {} {
	global DB
	variable SQL

	set template_id [reqGetArg TemplId]
	set name [reqGetArg TemplName]

	set action [expr {$template_id == "" ? "Inserted" : "Updated"}]

	set stmt [inf_prep_sql $DB $SQL(upd_bir_template)]

	if {[catch {
		set rs   [inf_exec_stmt $stmt $template_id $name]
	} err_msg]} {
		OT_LogWrite 1 "BIR ERROR: The template map was not $action. $err_msg"
		tpBindString templDBActionError \
			"There was a error the template map was not $action. $err_msg"
	} else {
		db_close $rs
		tpBindString templDBActionSuccess "Succesfully $action the Template"
	}

	inf_close_stmt $stmt
	db_close $rs

	go_bir
}



proc go_bir_add_templ {} {
	global DB
	variable SQL

	set template_id [reqGetArg TemplId]
	set tab_id [reqGetArg TabId]


	if {$template_id != "" && $tab_id != ""} {
		set stmt [inf_prep_sql $DB $SQL(get_bir_template)]
		set rs   [inf_exec_stmt $stmt $template_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {
			tpBindString templ_Id       [db_get_col $rs 0 template_id]
			tpBindString templ_Name     [db_get_col $rs 0 name]

			tpBindString templ_IdDisability  "READONLY"
		}
	}

	tpBindString TabId $tab_id
	tpBindString TemplId $template_id

	asPlayFile -nocache bir_template_add.html
}



proc bind_tab_maps {} {
	global DB TAB_MAP
	variable SQL

	set lang [reqGetArg TabLanguage]

	# Default to EN
	if {$lang == ""} {
		set lang "en"
	}

	# Bind up the maps
	set stmt [inf_prep_sql $DB $SQL(get_bir_tab_maps)]
	set rs   [inf_exec_stmt $stmt $lang]
	inf_close_stmt $stmt

	array set TAB_MAP [list]

	set index 0
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set TAB_MAP($index,map_id)         [db_get_col $rs $r tab_id]
		set TAB_MAP($index,sport_name)     [db_get_col $rs $r sport_name]
		set TAB_MAP($index,ob_id)          [db_get_col $rs $r ob_id]
		set TAB_MAP($index,level_desc)     [db_get_col $rs $r level_desc]
		set TAB_MAP($index,ob_level)       [db_get_col $rs $r ob_level]
		set TAB_MAP($index,name)           [db_get_col $rs $r name]
		set TAB_MAP($index,disp_order)     [db_get_col $rs $r disp_order]
		set TAB_MAP($index,languages)      [db_get_col $rs $r lang]

		incr index
	}

	tpBindVar tab_MapID         TAB_MAP     map_id          tab_idx
	tpBindVar tab_SportName     TAB_MAP     sport_name      tab_idx
	tpBindVar tab_LevelDesc     TAB_MAP     level_desc      tab_idx
	tpBindVar tab_Name          TAB_MAP     name            tab_idx
	tpBindVar tab_DispOrder     TAB_MAP     disp_order      tab_idx
	tpBindVar tab_Languages     TAB_MAP     languages       tab_idx

	tpSetVar NumberTabs $index

	db_close $rs
}



proc do_bir_update {} {

	set map_id [reqGetArg MapID]
	set display_order [reqGetArg DisplayOrder]

	go_bir
}



proc go_dd {} {
	return [ADMIN::POPUP_DD::go_dd "" [list choice]]
}



# Displays Betting in Running information
proc go_bir {} {
	global DB BIR_CLASSLIST
	variable SQL

	# Bind the tab mappings
	bind_tab_maps

	# Bind the languages
	bind_langs

	# Bind the templates mappings
	bind_template_maps

	# Bind up the schedule views
	set stmt [inf_prep_sql $DB $SQL(get_schedule_views)]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set day  [db_get_col $rs $r day]
		set mode [db_get_col $rs $r mode]
		tpBindString "schedsel_${day}_${mode}" "checked"
	}

	db_close $rs

	# Bind up the defaults
	set stmt [inf_prep_sql $DB $SQL(get_default_bir_info)]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		tpBindString refresh_[db_get_col $rs $r file_type] [db_get_col $rs $r refresh_time]
	}

	db_close $rs

	# Bind up the classes
	set stmt [inf_prep_sql $DB $SQL(get_bir_classes)]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set index 0
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		if {[db_get_col $rs $r event_refresh] != "-" || [db_get_col $rs $r comm_refresh] != "-"} {
			set BIR_CLASSLIST($index,ev_class_id)     [db_get_col $rs $r ev_class_id]
			set BIR_CLASSLIST($index,name)            [db_get_col $rs $r name]
			set BIR_CLASSLIST($index,event_refresh)   [db_get_col $rs $r event_refresh]
			set BIR_CLASSLIST($index,comm_refresh)    [db_get_col $rs $r comm_refresh]

			incr index
		}
	}

	db_close $rs

	tpBindVar ClassID            BIR_CLASSLIST  ev_class_id   class_idx
	tpBindVar ClassName          BIR_CLASSLIST  name          class_idx
	tpBindVar class_EVENT        BIR_CLASSLIST  event_refresh class_idx
	tpBindVar class_COMM         BIR_CLASSLIST  comm_refresh  class_idx
	tpSetVar NumClasses $index

	if {[OT_CfgGet FUNC_MANAGE_FLASH 0]} {
		set stmt [inf_prep_sql $DB $SQL(get_bir_display_option)]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar DisplayManageFlash 1
		tpSetVar DisplayBIRFlashMini  [db_get_col $res 0 display_mini]
		tpSetVar DisplayBIRFlashCS    [db_get_col $res 0 display_cs]
		tpSetVar DisplayBIRFlashEvent [db_get_col $res 0 display_fe]
		db_close $res
	}

	asPlayFile -nocache bir.html
}

proc do_bir {} {
	set act [reqGetArg SubmitName]

	if {$act == "Update"} {
		do_bir_upd
	} elseif {$act == "BIRRefreshAdd"} {
		do_bir_class_upd
	} elseif {$act == "BIRRefreshMod"} {
		do_bir_class_upd
	} elseif {$act == "BIRRefreshDel"} {
		do_bir_class_del
	} elseif {$act == "BIRScheduleUpd"} {
		do_bir_sched_upd
	} elseif {$act == "BIRFlashControl"} {
		do_bir_flash_upd
	} elseif {$act == "Back"} {
		go_bir
	} elseif {$act == "BIRTabMapping"} {
		do_bir_update
	} elseif {$act == "BIRDoDelTab"} {
		do_bir_delete_tab
	} elseif {$act == "BIRTabLang"} {
		go_bir
	} elseif {$act == "BIRTabUpdate"} {
		do_bir_add_tab
	} elseif {$act == "BIRTemplMapUpdate"} {
		do_bir_add_templ_map
	} elseif {$act == "BIRDoDelTemplMap"} {
		do_bir_del_templ_map
	} elseif {$act == "BIRDoDelTabMkt"} {
		do_bir_del_mkt_map
	} elseif {$act == "BIRMktMapUpdate"} {
		do_bir_add_mkt_map
	} elseif {$act == "BIRDoUpdTempl"} {
		do_bir_add_templ
	} elseif {$act == "BIRGoDD"} {
		go_dd
	} else {
		error "unexpected SubmitName: $act"
	}
}


# Updates the schedule views
proc do_bir_sched_upd {} {
	global DB USERNAME
	variable SQL

	set stmt_ins [inf_prep_sql $DB $SQL(ins_bir_schedule)]
	set stmt_upd [inf_prep_sql $DB $SQL(upd_bir_schedule)]

	for {set i -1} {$i < 4} {incr i} {
		set mode   [reqGetArg "sched_$i"]

		if {$mode != ""} {
			set rs     [inf_exec_stmt $stmt_upd $USERNAME $i $mode]

			# If no rows are updated, we insert instead
			ob::log::write INFO "[db_get_coln $rs 0]"
			if {[db_get_coln $rs 0] == 0} {
				inf_exec_stmt $stmt_ins $USERNAME $i $mode
			}
		}
	}

	go_bir
}


# Deletes all references to a class from tBIRRefresh
proc do_bir_class_del {} {
	# Blank args and call update (lazy _)
	reqSetArg refresh_EVENT ""
	reqSetArg refresh_COMM  ""

	do_bir_class_upd
}

# Update a class' BIR refresh times
proc do_bir_class_upd {} {
	global DB USERNAME
	variable SQL

	set class_id [reqGetArg ClassID]
	reqSetArg ClassID $class_id

	# Prepare queries
	set stmt_ins [inf_prep_sql $DB $SQL(ins_bir_refresh)]
	set stmt_upd [inf_prep_sql $DB $SQL(upd_bir_refresh)]
	set stmt_del [inf_prep_sql $DB $SQL(del_bir_refresh)]

	# Get the existing rows
	set stmt [inf_prep_sql $DB $SQL(get_bir_info)]
	set rs   [inf_exec_stmt $stmt $class_id]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set bir_defaults([db_get_col $rs $r file_type]) [db_get_col $rs $r refresh_time]
	}

	db_close $rs

	if {[catch {
		foreach type [list EVENT COMM] {
			if {[reqGetArg refresh_$type] == ""} {
				# Delete any existing row
				inf_exec_stmt $stmt_del\
					$USERNAME\
					$type\
					$class_id\
				]
			} elseif {[info exists bir_defaults($type)]} {
				# Update existing row
				inf_exec_stmt $stmt_upd\
					$USERNAME\
					$type\
					$class_id\
					[reqGetArg refresh_$type]\
				]
			} else {
				# Insert new row
				inf_exec_stmt $stmt_ins\
					$USERNAME\
					$type\
					$class_id\
					[reqGetArg refresh_$type]\
				]
			}
		}
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt_ins
	inf_close_stmt $stmt_upd
	inf_close_stmt $stmt_del

	go_bir
}

# Update the default BIR refresh times
proc do_bir_upd {} {
	global DB USERNAME
	variable SQL

	# Prepare queries
	set stmt_ins [inf_prep_sql $DB $SQL(ins_bir_refresh)]
	set stmt_upd [inf_prep_sql $DB $SQL(upd_bir_refresh)]

	# Get the existing rows
	set stmt [inf_prep_sql $DB $SQL(get_default_bir_info)]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set bir_defaults([db_get_col $rs $r file_type]) [db_get_col $rs $r refresh_time]
	}

	db_close $rs

	if {[catch {
		foreach type [list MINI SCHED EVENT COMM HOME ALLBL SPORT COMP CROSS EVLST] {
			if {[info exists bir_defaults($type)]} {
				# Update existing row
				inf_exec_stmt $stmt_upd\
					$USERNAME\
					$type\
					""\
					[reqGetArg refresh_$type]\
				]
			} else {
				# Insert new row
				inf_exec_stmt $stmt_ins\
					$USERNAME\
					$type\
					""\
					[reqGetArg refresh_$type]\
				]
			}
		}
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt_ins
	inf_close_stmt $stmt_upd

	go_bir
}



proc do_bir_flash_upd {} {
	global DB USERNAME
	variable SQL

	if {[catch {
		set stmt [inf_prep_sql $DB $SQL(upd_bir_display_option)]
		set res  [inf_exec_stmt $stmt \
		              $USERNAME \
		              [reqGetArg display_mini] \
		              [reqGetArg display_cs] \
		              [reqGetArg display_fe]]
		inf_close_stmt $stmt
		db_close $res
	} msg]} {
		err_bind $msg
		set bad 1
	}

	msg_bind "Updated Flash-App Control Settings"
	go_bir

}



proc go_bir_refresh args {
	global DB BIR_CLASSLIST
	variable SQL

	set class_id [reqGetArg ClassID]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ClassID $class_id

	if {$class_id == ""} {
		tpSetVar opAdd 1

		# We need a list of all the classes available
		set stmt [inf_prep_sql $DB $SQL(get_class_list)]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			set BIR_CLASSLIST($i,ev_class_id) [db_get_col $res $i ev_class_id]
			set BIR_CLASSLIST($i,name)        [db_get_col $res $i name]
		}

		tpBindVar BIR_CLASS_ID      BIR_CLASSLIST  ev_class_id  class_idx
		tpBindVar BIR_NAME          BIR_CLASSLIST  name         class_idx

		tpSetVar NumClasses [db_get_nrows $res]

		db_close $res
	} else {
		tpSetVar opAdd 0

		#
		# Get information
		#
		set stmt [inf_prep_sql $DB $SQL(get_refresh_by_class)]
		set res  [inf_exec_stmt $stmt $class_id]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] != 1} {
			err_bind "No information found for class $class_id"
		} else {
			tpBindString ClassName     [db_get_col $res 0 name]
			tpBindString refresh_COMM  [db_get_col $res 0 comm_refresh]
			tpBindString refresh_EVENT [db_get_col $res 0 event_refresh]
		}

		db_close $res
	}

	asPlayFile -nocache bir_refresh_class.html
}

proc do_res {} {
	set act [reqGetArg SubmitName]

	if {$act == "DoAddBirOc"} {
		do_add_bir_oc
	} elseif {$act == "DelBirOc"} {
		del_bir_oc
	} elseif {$act == "UpdDfltRes"} {
		upd_dflt_res
	} elseif {$act == "ConfirmRes"} {
		confirm_res
	} elseif {$act == "SettleRes"} {
		settle_res
	} elseif {$act == "SetMktRes"} {
		set_mkt_res
	} elseif {$act == "Back"} {
		ADMIN::MARKET::go_mkt
	} else {
		error "unexpected SubmitName: $act"
	}
}

#-----------------------------------------------------------------------------
# Add a result that has been set for a market index.
#-----------------------------------------------------------------------------

proc do_add_bir_oc {} {
	global DB

	# Configurable so that you have only one resuls per bir index

	if {[OT_CfgGet BIR_INX_ONE_RES 0] == 1} {

		set sql [subst {
			select mkt_bir_idx
			from tMktBirIdxRes
			where mkt_bir_idx = [reqGetArg MktBirIdx]
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		db_close $res

		if {$nrows > 0} {
			err_bind "Error adding result - can only have one results per index"
			ADMIN::SELN::go_ocs_res
			return
		}
	}

	set sql [subst {
		insert into tMktBirIdxRes
		  (mkt_bir_idx,ev_oc_id,result)
		values
		  ([reqGetArg MktBirIdx],[reqGetArg EvOcId],'[reqGetArg Result]')
	}]

	set stmt [inf_prep_sql $DB $sql]
	set ret [catch {inf_exec_stmt $stmt}]
	inf_close_stmt $stmt

	if {$ret} {
		err_bind "Error adding result - make sure that this selection has not already been chosen"
	}

	ADMIN::SELN::go_ocs_res

}

  #-----------------------------------------------------------------------------
  # Remove a result that has been set for a market index.
  #-----------------------------------------------------------------------------

proc del_bir_oc {} {
	global DB

	set sql [subst {
		delete from tMktBirIdxRes
		where mkt_bir_idx = [reqGetArg MktBirIdx]
		and   ev_oc_id    = [reqGetArg EvOcId]
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	ADMIN::SELN::go_ocs_res

}

  #-----------------------------------------------------------------------------
  # Changes the default result for a market index
  #-----------------------------------------------------------------------------

proc upd_dflt_res {} {
	global DB

	set sql [subst {
		update tMktBirIdx
		set default_res = '[reqGetArg DefaultResult]'
		where mkt_bir_idx = [reqGetArg MktBirIdx]
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	ADMIN::SELN::go_ocs_res

}

   #-----------------------------------------------------------------------------
   # Confirms the results for a market index
   #-----------------------------------------------------------------------------

proc confirm_res {} {
	global DB

	set sql [subst {
		update tMktBirIdx
		set result_conf = '[reqGetArg Confirm]'
		where mkt_bir_idx = [reqGetArg MktBirIdx]
	}]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	ADMIN::SELN::go_ocs_res
}

   #-----------------------------------------------------------------------------
   #       Play the settlement page which calls the settlement code.
   #-----------------------------------------------------------------------------

proc settle_res {} {

	global USERNAME

	tpSetVar StlObj   bir
	tpSetVar StlObjId [reqGetArg MktBirIdx]
	tpSetVar MktId    [reqGetArg MktId]
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}

   #-----------------------------------------------------------------------------
   #       the resulting is done in tmktbiridxres so we just need to
   #       update the selection to show that the resulting has been handled
   #   - n.b. its a clean up option setting results to 'continuous' as there
   #          are only index level results, not market level results for CW
   #-----------------------------------------------------------------------------

proc set_mkt_res {} {
	global DB USERNAME

	set sql [subst {
		select ev_oc_id
		from   tEvOc
		where ev_mkt_id = [reqGetArg MktId]
		and   result != 'N'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set oc_ids [list]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		lappend oc_ids [db_get_col $res $i ev_oc_id]
	}
	db_close $res

	set sql [subst {
		execute procedure pSetEvOcResult(
			p_adminuser = ?,
			p_ev_oc_id = ?,
			p_result = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	set ret [catch {
		foreach oc_id $oc_ids {
			inf_exec_stmt $stmt\
				$USERNAME\
				$oc_id\
				"N"
		}
	} msg]

	inf_close_stmt $stmt

	if {$ret} {
		err_bind $msg
		inf_rollback_tran $DB
		ADMIN::SELN::go_ocs_res
		return
	} else {
		inf_commit_tran $DB
	}

	ADMIN::MARKET::go_mkt

}

#
# For use with bir markets such as
# "To score Xth goal", if bir_idx is 5, will be converted to
# "To score 5th goal".
#
proc subst_xth {text bir_idx {mkt_sort CW}} {
	if {$mkt_sort == "CW"} {
		set idx [ADMIN::XLATE::get_translation "en" IDX_$bir_idx]
		regsub -all {[X|x]th} $text $idx text
	}
	return $text
}


}

