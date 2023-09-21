# ==============================================================
# $Id: bf_match.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_MATCH {

asSetAct ADMIN::BETFAIR_MATCH::GoBFMatch	       	[namespace code go_bf_match]
asSetAct ADMIN::BETFAIR_MATCH::GoSearchBFMatch     	[namespace code go_search_bf_match]
asSetAct ADMIN::BETFAIR_MATCH::DoBFAutoMatch	       	[namespace code do_bf_auto_match]



#-----------------------------------------------------------------------------------
# Proc to enable auto match ON/OFF and to search mappings on certain criteria
#------------------------------------------------------------------------------------
proc go_bf_match args {
	global DB CLASS TYPE SORT 
	
	#
	# Retrieve current auto matching on/off status
	#
	set sql [subst {
			select
				bf_auto_match
			from
				tBFConfig
	}]

	set stmt [inf_prep_sql $DB $sql]
	catch {set rs [inf_exec_stmt $stmt]}

	set res [db_get_nrows $rs]

	set bf_match   [db_get_col $rs 0 bf_auto_match]
	tpBindString 	BFMatch	$bf_match
	
	inf_close_stmt $stmt
	db_close $rs
	
	if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
		set pricingType "t.pricing_type,"
	} else {
		set pricingType ""
	}
	
	set sql [subst {
		select
			c.ev_class_id,
			c.name cname,
			c.sort,
			c.displayed cdisp,
			c.disporder cdispo,
			t.ev_type_id,
			t.name tname,
			$pricingType
			t.displayed tdisp,
			t.disporder tdispo,
			upper(c.name) as upcname,
			upper(t.name) as uptname
		from
			tEvClass c,
			tEvType t
		where
			c.ev_class_id = t.ev_class_id
			
		order by
			c.displayed desc,
			upcname asc,
			c.ev_class_id,
			t.displayed desc,
			tdispo asc,
			uptname asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	catch {set res [inf_exec_stmt $stmt]}
	
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	set c_ix       -1
	set c_class_id -1

	for {set r 0} {$r < $rows} {incr r} {

		set class_id [db_get_col $res $r ev_class_id]
		set type_id  [db_get_col $res $r ev_type_id]
		set cname    [db_get_col $res $r cname]
		set tname    [db_get_col $res $r tname]
		set sort	 [db_get_col $res $r sort]
		if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
			set pricing_type [db_get_col $res $r pricing_type]
		}

		if {$class_id != $c_class_id} {

			incr c_ix

			set CLASS($c_ix,id)    $class_id
			set CLASS($c_ix,name)  [ADMIN::BETFAIR::remove_tran_bars $cname]
			set CLASS($c_ix,sort)  $sort
			set CLASS($c_ix,types) 0

			set c_class_id $class_id
		}

		set t_ix $CLASS($c_ix,types)

		set TYPE($c_ix,$t_ix,id)   $type_id
		set TYPE($c_ix,$t_ix,name) [ADMIN::BETFAIR::remove_tran_bars $tname]
		set SORT($r,type)		   $type_id
		set SORT($r,sort)		   $sort
		if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
			set TYPE($c_ix,$t_ix,pricing_type)   $pricing_type
		}

		incr CLASS($c_ix,types)
	}

	tpSetVar NumClasses [expr {$c_ix+1}]
	tpSetVar NumSorts	$rows

	tpBindVar ClassId   CLASS id   class_idx
	tpBindVar ClassName CLASS name class_idx
	tpBindVar ClassSort CLASS sort class_idx
	tpBindVar TypeId    TYPE  id   class_idx type_idx
	tpBindVar TypeName  TYPE  name class_idx type_idx
	if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
		tpBindVar TypePricingType TYPE pricing_type class_idx type_idx
	}
	tpBindVar SortType  SORT  type sort_idx
	tpBindVar TypeSort  SORT  sort sort_idx
	tpSetVar SEARCH 0
	tpBindString Ev_Displayed [OT_CfgGet DFLT_EVENT_SEL_STATUS "A"]
	asPlayFile -nocache bf_auto_match.html
	
	catch {unset CLASS}
	catch {unset TYPE}
	catch {unset SORT}
}

#--------------------------------------------------------------------------------
# Proc to display event mappings based on the parameter(s) passed
#--------------------------------------------------------------------------------
proc go_search_bf_match  args {
	global DB MAPPING
	
	set class_id 	[reqGetArg ClassId]
	set type_id 	[reqGetArg TypeId]
	set date_sel 	[reqGetArg date_range]
	set map_type 	[reqGetArg map_type]
	set username 	[reqGetArg username]
	set match_type 	[reqGetArg match_type]
	set desc 		[reqGetArg desc]
	set exclude_desc [reqGetArg exclude_desc]
	set start_date	[reqGetArg start_date]
	set end_date	[reqGetArg end_date]
	set search_string ""
	set search_str1 ""
	set search_str2 ""
	set bf_map_id_list ""	
	
	if {$class_id != 0 && $type_id ==0} {
		append search_str1 " and t.ev_class_id=$class_id "
	} elseif {$class_id != 0 } {
		append search_str1 " and t.ev_type_id=$type_id "
	}
	
	if {$desc != ""} {
		set f_char [string index $desc 0]
		if {$f_char != "%"} {
			set desc [string toupper $desc 0]
		}
		append search_str2 " and b.glob_desc like '$desc%' "
	}

	if {$exclude_desc != ""} {
		set f_char [string index $exclude_desc 0]
		if {$f_char != "%"} {
			set exclude_desc [string toupper $exclude_desc 0]
		}
		append search_str2 " and b.glob_desc_exclude like '$exclude_desc%' "
	}

	if {$map_type != "ALL"} {
		append search_str2 " and b.map_type = \"$map_type\" "
	}

	set sql_type " select 
				b.bf_map_id,
				t.ev_type_id
			from 
				tbfmap b, 
				tevtype t 
			where 
				b.ob_id=t.ev_type_id 
				and b.ob_type='ET'
				$search_str1 
				$search_str2 "
	
	set stmt_type [inf_prep_sql $DB $sql_type]
	set r_type [inf_exec_stmt $stmt_type]
	set nrows_type [db_get_nrows $r_type]
	set type_id_list ""
	for {set i 0} {$i < $nrows_type} {incr i} {
		if {$bf_map_id_list == ""} {
			append bf_map_id_list [db_get_col $r_type $i bf_map_id]
			append type_id_list [db_get_col $r_type $i ev_type_id] 
		} else {
			append bf_map_id_list ","
			append bf_map_id_list [db_get_col $r_type $i bf_map_id]
			append type_id_list ","
			append type_id_list [db_get_col $r_type $i ev_type_id]
		}
	}
	db_close $r_type

	if {$search_str1 == "" && $search_str2 != "" && $type_id_list != ""} {
		append search_str1 " and t.ev_type_id in ($type_id_list) "
	}
	
	if {$search_str1 != "" || $type_id_list != ""} {
		set sql_event " select 
					b.bf_map_id 
				from 
					tbfmap b, 
					tevtype t, 
					tev e 
				where 
					b.ob_id = e.ev_id 
					and b.ob_type='EV' 
					and e.ev_type_id =t.ev_type_id
					$search_str1 "
	
		set stmt_event [inf_prep_sql $DB $sql_event]
		set r_event [inf_exec_stmt $stmt_event]
		set nrows_event [db_get_nrows $r_event]
	
		for {set i 0} {$i < $nrows_event} {incr i} {
			if {$bf_map_id_list == ""} {
				append bf_map_id_list [db_get_col $r_event $i bf_map_id]
			} else {
				append bf_map_id_list ","
				append bf_map_id_list [db_get_col $r_event $i bf_map_id]
			}
		}
		db_close $r_event
		
		if {$bf_map_id_list != ""} {
			append search_string " and m.bf_map_id in ($bf_map_id_list)"
			
			if {$match_type != "B"} {
				append search_string "and m.match_type=\"$match_type\""
			}
			tpSetVar MatchType $match_type
			
			if {$start_date != "" && $end_date != "" && $date_sel == "-"} {
				set st_date "'$start_date 00:00:00'"
				set en_date "'$end_date 23:59:59'"
				append search_string " and m.cr_date between $st_date and $en_date"
			} elseif {$date_sel != "-"} {
				set st_date ""
				set en_date ""
				set dt [clock format [clock seconds] -format "%Y-%m-%d"]

				foreach {y m d} [split $dt -] {
					set y [string trimleft $y 0]
					set m [string trimleft $m 0]
					set d [string trimleft $d 0]
				}
				
				if {$date_sel == "0"} {
					set st_date "'$dt 00:00:00'"
					set en_date "'$dt 23:59:59'"
				} elseif {$date_sel == "-30"} {
					set en_date [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
					if {[incr m -1] < 1} {
						set m 12
						incr y -1
					}
					set st_date [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				} else {
					set en_date [format "'%s-%02d-%02d 23:59:59'" $y $m $d]
					if {[incr d $date_sel] <= 0} {
						if {[incr m -1] < 1} {
							set m 12
							incr y -1
						}
						set d [expr {[days_in_month $m $y]+$d}]
					}
					set st_date [format "'%s-%02d-%02d 00:00:00'" $y $m $d]
				}
				append search_string " and m.cr_date between $st_date and $en_date"
			}
			
			if {$username != ""} {
				if {[reqGetArg ExactName] == "Y"} {
					set op =
				} else {
					set op like
					set username "%$username%"
				}
				if {[reqGetArg UpperName] == "Y"} {
					append search_string " and upper(u.username) ${op} '[string toupper ${username}]'"
				} else {
					append search_string " and u.username ${op} '${username}'"
				}
			}

			#
			# Retrieve all the manual openbet type and event matching
			#
			set sql [subst {
					select
						m.bf_map_id,
						u.username,
						m.ob_type,
						m.ob_id,
						b.bf_ev_items_id,
						b.bf_desc,
						m.map_type,
						m.glob_desc,
						m.glob_desc_exclude
					from
						tBFMap m,
						tAdminUser u,
						outer tBFEvItems b
					where
						m.user_id = u.user_id
					and	m.bf_ev_items_id = b.bf_ev_items_id
					$search_string
			}]
		
			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt]
			set res [db_get_nrows $rs]

			for {set i 0} { $i < $res } {incr i} {
				set MAPPING($i,bf_map_id)	[db_get_col $rs $i bf_map_id]
				set MAPPING($i,username)	[db_get_col $rs $i username]
				set MAPPING($i,ob_type)		[db_get_col $rs $i ob_type]
				set MAPPING($i,ob_id)		[db_get_col $rs $i ob_id]
				set MAPPING($i,bf_ev_items_id)	[db_get_col $rs $i bf_ev_items_id]
				set MAPPING($i,bf_desc)		[db_get_col $rs $i bf_desc]
				set MAPPING($i,map_type)	[db_get_col $rs $i map_type]
				set MAPPING($i,glob_desc)	[db_get_col $rs $i glob_desc]
				set MAPPING($i,glob_desc_exclude) [db_get_col $rs $i glob_desc_exclude]
				
				# get both betfair and openbet hierarchy
				if {$MAPPING($i,ob_type) == "ET" } {
					set ob_select 	"c.name as c_name, t.name as t_name"
					set ob_from 	"tEvClass c, tEvType t"
					set ob_where	"t.ev_type_id = ? and	t.ev_class_id = c.ev_class_id"
				} else {
					set ob_select 	"c.name as c_name, t.name as t_name, ev.desc as e_name"
					set ob_from 	"tEvClass c, tEvType t, tEv ev"
					set ob_where	"ev.ev_id = ? and t.ev_type_id = ev.ev_type_id and t.ev_class_id = c.ev_class_id"
				}
				
				# openbet HR types are mapped to BF type and not to BF event
				if {$MAPPING($i,ob_type) == "ET"  && ($MAPPING($i,map_type) == "HR" || $MAPPING($i,map_type) == "GR")} {
					set sql [subst {
						select
						    et.name as type_name,
						    $ob_select
						from
							tBFEventType et, tBFEvItems b,
							$ob_from
						where
							b.bf_ev_items_id = ?
						and et.bf_ev_items_id = b.bf_ev_items_id
						and	$ob_where
					}]
				} else {
					set sql [subst {
						select
						    et.name as type_name,
						    e.name as name0,
						    e1.name as name1,
						    e2.name as name2,
						    e3.name as name3,
						    e4.name as name4,
						    e5.name as name5,
						    e6.name as name6,
						    $ob_select
					from
						    tBFEventType et, tBFEvent e, tBFEvItems b,
						    outer (tBFEvent e1,
						    outer (tBFEvent e2,
						    outer (tBFEvent e3,
						    outer (tBFEvent e4,
						    outer (tBFEvent e5,
						    outer (tBFEvent e6)))))),
						    $ob_from
					where
						b.bf_ev_items_id = ?
					and e.bf_ev_items_id = b.bf_ev_items_id
					and	e.bf_parent_id = e1.bf_ev_id
					and e1.bf_parent_id = e2.bf_ev_id
					and e2.bf_parent_id = e3.bf_ev_id
					and e3.bf_parent_id = e4.bf_ev_id
					and e4.bf_parent_id = e5.bf_ev_id
					and e5.bf_parent_id = e6.bf_ev_id
					and e.bf_type_id = et.bf_type_id
					and	$ob_where
					}]
				}
				
				set stmt_e [inf_prep_sql $DB $sql]
			
				set res_e [inf_exec_stmt $stmt_e $MAPPING($i,bf_ev_items_id) $MAPPING($i,ob_id)]
				
				set nrows  [db_get_nrows $res_e]
				
				set MAPPING($i,bf_desc)		""
				set MAPPING($i,name) 		""
				
				if {$nrows > 0} {
					# set the full betfair heirarchy
					if {$MAPPING($i,ob_type) == "ET"  && ($MAPPING($i,map_type) == "HR" || $MAPPING($i,map_type) == "GR")} {
						set MAPPING($i,bf_desc)		"[db_get_col $res_e 0 type_name]"
					} else {						
						set desc ""
						for {set k 6} {$k >= 0} {incr k -1} {
							if {[db_get_col $res_e 0 name$k] != ""} {
								if {$desc == ""} {
									set desc [db_get_col $res_e 0 name$k]
								} else {
									append desc " --> [db_get_col $res_e 0 name$k]"
								}
							}
						}
						set MAPPING($i,bf_desc)		"[db_get_col $res_e 0 type_name] --> $desc"
					}
					
					# set the full openbet heirarchy
					if {$MAPPING($i,ob_type) == "ET" } {
						set MAPPING($i,name)	"[db_get_col $res_e 0 c_name] --> [db_get_col $res_e 0 t_name]"
					} else {
						set MAPPING($i,name)	"[db_get_col $res_e 0 c_name] --> [db_get_col $res_e 0 t_name] --> [db_get_col $res_e 0 e_name] "
					}
				}
				
				inf_close_stmt $stmt_e
				db_close $res_e
				# End ob/bf parent trail
			}
			
			inf_close_stmt $stmt
			db_close $rs
		} else {
			set res 0
		}
	} else {
		set res 0
	}
	
	tpSetVar MapRows $res

	tpBindVar MapId				MAPPING		bf_map_id			map_idx
	tpBindVar MapUserName		MAPPING		username			map_idx
	tpBindVar MapOBType			MAPPING		ob_type				map_idx
	tpBindVar MapOBId			MAPPING		ob_id				map_idx
	tpBindVar MapOBName			MAPPING		name				map_idx
	tpBindVar MapBFId			MAPPING		bf_ev_items_id		map_idx
	tpBindVar MapBFDesc			MAPPING		bf_desc				map_idx
	tpBindVar MapType			MAPPING		map_type			map_idx
	tpBindVar MapGlob			MAPPING		glob_desc			map_idx
	tpBindVar MapGlobExclude    MAPPING     glob_desc_exclude   map_idx
	
	tpSetVar SEARCH 1
	
	asPlayFile -nocache bf_auto_match.html

	catch {unset MAPPING}
}


#--------------------------------------------------------------------------
# set bf_auto_match to Yes or No
#--------------------------------------------------------------------------
proc do_bf_auto_match args {
	global DB

	set bf_auto_match 	[reqGetArg bf_auto_match]

	set sql [subst {
		update
			tBFConfig
		set
			bf_auto_match = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt	$bf_auto_match} msg]} {
			ob::log::write ERROR {do_bf_auto_match - $msg}
			err_bind "$msg"
	}

	inf_close_stmt $stmt

	go_bf_match
}

}
