# ==============================================================
# $Id: bf_type.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_TYPE {

asSetAct ADMIN::BETFAIR_TYPE::UpdSubTypeRule [namespace code handle_upd_sub_rule]
asSetAct ADMIN::BETFAIR_TYPE::UpdTypeRule 	 [namespace code handle_upd_rule]


#
# Bind the Betfair Type Filter Option & matching logic in the 
# class details page 
#
# returns 1 - bind info   0 - ignore 
#
proc bind_bf_type_match_info {{class_id ""} {type_order_by ""}} {

	global BFEVTYPES BFEVS OBTYPE

	catch {unset BFEVTYPES}
	catch {unset BFEVS}
	catch {unset OBTYPE}

	set is_sub_type 0
	set bf_type_id 	""

	set match_class [bf_class_match ID $class_id]

	if {[OT_CfgGet BF_MANUAL_MATCH 0] || [OT_CfgGet BF_AUTO_MATCH 0]} {
				
		if {$match_class} { 		
			_bind_bf_type_filter $class_id
			set bf_type_id [_bind_old_filter $class_id]
		} 

		if {[OT_CfgGet BF_AUTO_MATCH 0] == 1} {
			_bind_type_matching	$class_id $bf_type_id $is_sub_type "" $type_order_by 
		} 
	}
	
	return
} 


#
# Bind the sub-type matching logic in the type details page 
#
proc bind_bf_sub_type_match_info {{class_id ""} {type_id ""}} {

	global BFEVTYPES BFEVS OBTYPE

	catch {unset BFEVTYPES}
	catch {unset BFEVS}
	catch {unset OBTYPE}

	set is_sub_type 1

	tpSetVar IsSubType $is_sub_type
	tpSetVar EvTypeId $type_id
	
	if {$class_id != "" && $type_id != ""} {

		set match_class [bf_class_match ID $class_id]

		if {$match_class} { 
			set bf_type_id [_bind_old_filter $class_id]
		} else { 
			set bf_type_id ""
		} 		
		
		_bind_type_matching	$class_id $bf_type_id $is_sub_type $type_id
	}
}


#
# Bind the 'Betfair Type' dropdown 
#
proc _bind_bf_type_filter {class_id} {
	
	global BFEVTYPES BFEVS OBTYPE

	set sql {
		select
			e.bf_ev_items_id,
			e.bf_desc,
			m.ob_id
		from
			tBFEvItems e,
			outer tBFMap m
		where
			e.bf_type='ET'
			and e.bf_ev_items_id=m.bf_ev_items_id
			and m.ob_type='EC'
			and m.ob_id = ?
		order by
			e.bf_ev_items_id
	}

	set stmt [inf_prep_sql $::DB $sql]

	set res [inf_exec_stmt $stmt $class_id]

	set nrows  [db_get_nrows $res]

	if {$nrows > 0} {

		for {set i 0} {$i < $nrows } {incr i} {
			set BFEVTYPES($i,name)     	[db_get_col $res $i bf_desc]
			set BFEVTYPES($i,id)       	[db_get_col $res $i bf_ev_items_id]
			set BFEVTYPES($i,ob_id)		[db_get_col $res $i ob_id]
		}

		ob_log::write_array INFO BFEVTYPES

		tpBindVar BF_Type_Name		BFEVTYPES	name	bf_type_filter_idx
		tpBindVar BF_Type_id		BFEVTYPES	id		bf_type_filter_idx
		tpBindVar BF_Type_Obid		BFEVTYPES	ob_id	bf_type_filter_idx
		tpSetVar TypeFilterRows $nrows
	}

	inf_close_stmt $stmt
	db_close $res
} 


#
# Bind up the current betfair type_id
#
proc _bind_old_filter {class_id} {

	global BFEVTYPES BFEVS OBTYPE

	set bf_type_id ""

	set sql {
		select
			bf_type_id
		from
			tBFEventType
		where
			bf_ev_items_id in (
					select
						bf_ev_items_id
					from
						tBFMap
					where
						ob_id = ?
						and ob_type = 'EC'
					)
	}

	set stmt [inf_prep_sql $::DB $sql]

	set res [inf_exec_stmt $stmt $class_id]

	set nrows  [db_get_nrows $res]
	
	if {$nrows > 0} {
		set bf_type_id	[db_get_col $res 0 bf_type_id]
		tpSetVar Old_filter_id 	$bf_type_id
	}

	inf_close_stmt $stmt
	db_close $res
	
	return $bf_type_id
	
} 


#
# Binds up the type matching rules for types/sub-types
#
# type_id 		- only required for sub_types
# type_order_by - the ordering must match the ordering of the original type list
#                 else mappings get incorrectly assigned. Have a parameter so can 
#                 keep bf_match generic between clients.
#
proc _bind_type_matching {class_id bf_type_id is_sub_type {type_id ""} {type_order_by ""}} {

	global BFEVTYPES BFEVS OBTYPE

	if {$class_id == ""} { 
		return 
	} 

	# Event Type Rules 
	
	set sql [ADMIN::BETFAIR_EV::get_event_list_sql 0 $bf_type_id]

	set stmt [inf_prep_sql $::DB $sql]

	set res [inf_exec_stmt $stmt $bf_type_id]

	set nrows  [db_get_nrows $res]

	set bf_ev_list [list]

	set nrows_bf $nrows

	if {$nrows > 0} {
		for {set i 0} {$i < $nrows } {incr i} {
			set BFEVS($i,id)	[db_get_col $res $i bf_ev_items_id0]
			set desc ""

			for {set k 6} {$k >= 0} {incr k -1} {
				if {[db_get_col $res $i name$k] != ""} {
					if {$desc == ""} {
						set desc [db_get_col $res $i name$k]
					} else {
						append desc " -> [db_get_col $res $i name$k]"
					}
				}
			}

			set BFEVS($i,name) $desc
			lappend bf_ev_list	[list $BFEVS($i,name) $BFEVS($i,id)]

		}

		# sort the list
		set bf_ev_list	[lsort $bf_ev_list]

		for {set i 0} {$i < $nrows } {incr i} {
			set bf_ev [lindex $bf_ev_list $i]
			set k 0

			foreach item $bf_ev {
				if { $k == 0 } {
					set BFEVS($i,name)	$item
				} else {
					set BFEVS($i,id)	$item
				}
				incr k
			}
		}

		tpBindVar BF_Ev_Name	BFEVS	name	bf_ev_idx
		tpBindVar BF_Ev_Id		BFEVS	id		bf_ev_idx

		tpSetVar BFEvRows $nrows
	}

	inf_close_stmt $stmt
	db_close $res
		
	# Event Types details
	
	if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
		set pricingType "t.pricing_type,"
	} else {
		set pricingType ""
	}

	if {$is_sub_type == 0} { 

		if {$type_order_by == ""} { 
			set type_order_by "t.disporder,t.name"
		} 

		set sql [subst {
			select unique 
				t.ev_type_id,
				t.name as type_name,
				t.ev_class_id,
				t.disporder,
				t.displayed,
				t.status,
				t.languages,
				t.channels,
				$pricingType
				t.fastkey,
				m.bf_ev_items_id,
				m.map_type,
				m.glob_desc,
				m.glob_desc_exclude,
				m.is_std_hr,
				m.auto_match_mode
			from
				tEvType t,
				outer tBFMap m
			where
				t.ev_class_id = ?
			and
				t.ev_type_id = m.ob_id
			and
				m.ob_type = 'ET'
			and 
				m.ob_sub_type_id is null
			order by
				$type_order_by 
		}]

		set stmt      [inf_prep_sql $::DB $sql]
		set res_type  [inf_exec_stmt $stmt $class_id]

	} else { 

		set sql [subst {
				select
					t.ev_type_id,
					t.name as type_name,
					t.ev_class_id,
					t.disporder,
					t.displayed,
					t.status,
					t.languages,
					t.channels,
					$pricingType
					t.fastkey,						
					m.bf_ev_items_id,
					m.map_type,
					m.glob_desc,
					m.glob_desc_exclude,
					m.is_std_hr,
					m.auto_match_mode,						
					s.ev_sub_type_id,
					s.name as sub_name,
					s.disporder as sub_disporder
				from
					tEvSubType s,
					tEvType t,
					outer tBFMap m
				where
					s.ev_type_id = ?
				and
					s.ev_type_id = t.ev_type_id
				and
					m.ob_id = s.ev_type_id
				and
					m.ob_sub_type_id = s.ev_sub_type_id
				and
					m.ob_type = 'ET'
				order by
					s.disporder asc     
		}]

		set stmt [inf_prep_sql $::DB $sql]
		set res_type [inf_exec_stmt $stmt $type_id]
	}

	set nrows  [db_get_nrows $res_type]
	
	if {$nrows > 0} {
		
		for {set i 0} {$i < $nrows } {incr i} {
			if {$is_sub_type == 1} { 
				set OBTYPE($i,ob_type_id)	[db_get_col $res_type $i ev_sub_type_id]
				set OBTYPE($i,name)			[db_get_col $res_type $i sub_name]
				set OBTYPE($i,disporder)	[db_get_col $res_type $i sub_disporder]
			} else { 
				set OBTYPE($i,ob_type_id)	[db_get_col $res_type $i ev_type_id]
				set OBTYPE($i,name)			[db_get_col $res_type $i type_name]
				set OBTYPE($i,disporder)	[db_get_col $res_type $i disporder]
			} 
			set OBTYPE($i,ev_class_id)		[db_get_col $res_type $i ev_class_id]
			set OBTYPE($i,status)			[db_get_col $res_type $i status]						
			if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
				set OBTYPE($i,pricing_type)	[db_get_col $res_type $i pricing_type]
			}								
			set OBTYPE($i,displayed)		[db_get_col $res_type $i displayed]
			set OBTYPE($i,channels)			[db_get_col $res_type $i channels]
			set OBTYPE($i,fastkey)			[db_get_col $res_type $i fastkey]
			set OBTYPE($i,languages)		[db_get_col $res_type $i languages]
			set OBTYPE($i,bf_ev_items_id)	[db_get_col $res_type $i bf_ev_items_id]

			set bf_ev_items_id				[db_get_col $res_type $i bf_ev_items_id]

			if {$bf_ev_items_id != ""} {
				# To Retrieve the Mapped event name
				 for {set j 0} {$j < $nrows_bf } {incr j} {
					set bf_ev 	[lindex $bf_ev_list $j]
					set k 		[lsearch $bf_ev $bf_ev_items_id]

					if {$k != -1} {
						foreach item $bf_ev {
							set OBTYPE($i,bf_name) $item
							break
						}							
						break
					}
				}
			} else {
				set OBTYPE($i,bf_name) ""
			}
			
			set OBTYPE($i,map_type)				[db_get_col $res_type $i map_type]
			set OBTYPE($i,glob_desc)			[db_get_col $res_type $i glob_desc]
			set OBTYPE($i,glob_desc_exclude)	[db_get_col $res_type $i glob_desc_exclude]
			set OBTYPE($i,is_std_hr)			[db_get_col $res_type $i is_std_hr]

			# To perform the manual event matching functionality by Admin User
			set OBTYPE($i,auto_match_mode)		[db_get_col $res_type $i auto_match_mode]
		}
	}

	tpSetVar NumTypes [db_get_nrows $res_type]

	inf_close_stmt $stmt

	if {$is_sub_type} { 
		set idx "sub_type_idx"
	} else { 
		set idx "type_idx"
	} 

	OT_LogWrite 8 "NumTypes = [db_get_nrows $res_type] ev_class_id = $class_id idx=$idx"

	if {$is_sub_type} { 	
		tpBindVar ObTypeName      		OBTYPE name 			$idx 		
	} else { 	
		tpBindVar TypeId        		OBTYPE ob_type_id 		$idx
		tpBindVar TypeName      		OBTYPE name 			$idx 			
	}  		
	tpBindVar ObTypeId        		OBTYPE ob_type_id 			$idx
	tpBindVar TypeClassId			OBTYPE ev_class_id 			$idx	
	tpBindVar TypeStatus    		OBTYPE status 				$idx
	tpBindVar TypeDisporder 		OBTYPE disporder 			$idx
	tpBindVar TypeDisplayed 		OBTYPE displayed 			$idx
	tpBindVar TypeChannels  		OBTYPE channels 			$idx
	tpBindVar TypeFastkey   		OBTYPE fastkey 				$idx
	tpBindVar TypeLangs     		OBTYPE languages 			$idx		
	tpBindVar TypeBfEvId			OBTYPE bf_ev_items_id 		$idx
	tpBindVar TypeMapType			OBTYPE map_type  			$idx
	tpBindVar TypeGlobDesc			OBTYPE glob_desc  			$idx
	tpBindVar TypeGlobDescExclude	OBTYPE glob_desc_exclude 	$idx
	tpBindVar TypeIsStdHRExclude	OBTYPE is_std_hr  			$idx
	tpBindVar BFName				OBTYPE bf_name 				$idx
	tpBindVar TypeAutoMatchMode 	OBTYPE auto_match_mode 		$idx

	if {[OT_CfgGet FUNC_ADMIN_CLONE_EVENTS 0]} {
		tpBindVar TypePricingType OBTYPE pricing_type $idx
	}

	db_close $res_type
}

#
# Proc to update the bf_type filter for an event class
#     - Redo mappings and remove mappings under this level
#
proc do_bf_type_filter {{classid ""}} {
	
	if {![op_allowed BFMatch]} {		
		return 
	} 
	
	set BF_TypeFilterId_old	[reqGetArg BF_TypeFilterId_old]
	set BF_TypeFilter		[reqGetArg BF_TypeFilter]
	
	if { $classid != ""  && [reqGetArg Sort] != "HR" && [reqGetArg Sort] != "GR"} {
		if { $BF_TypeFilter != "" } {
			if { $BF_TypeFilterId_old != $BF_TypeFilter } {
				# insert/update a row into the tBFMap table
				set sql [subst {
					execute procedure pBFUpdMap (
						p_adminuser     	= ?,
						p_status 			= ?,
						p_ob_type       	= ?,
						p_ob_id         	= ?,
						p_bf_ev_items_id	= ?
						)
				}]
			
				set stmt [inf_prep_sql $::DB $sql]
			
				if {[catch {set rs [inf_exec_stmt $stmt	$::USERNAME "A" "EC" $classid $BF_TypeFilter]} msg]} {
					ob::log::write ERROR {do_bf_type_filter - $msg}
					err_bind "$msg"
				}
				
				inf_close_stmt $stmt
				db_close $rs
			}
		} else {
			# Delete the EC and ET mappings from the tBFMap table
			set sql2 [subst {
				delete from
					tBFMap
				where
					ob_id = ?
					and ob_type = ?
			}]
			
			set stmt2 [inf_prep_sql $::DB $sql2]
		
			if {[catch {set rs2 [inf_exec_stmt $stmt2 $classid "EC"]} msg]} {
				ob::log::write ERROR {do_bf_type_filter - $msg}
				err_bind "$msg"
			}
			
			inf_close_stmt $stmt2
			db_close $rs2
			
			set sql3 [subst {
				delete from
					tBFMap
				where
					ob_type = 'ET'
					and ob_id in (
							select 
								ev_type_id 
							from 
								tEvType 
							where 
								ev_class_id = ?
							)
			}]
			
			set stmt3 [inf_prep_sql $::DB $sql3]
		
			if {[catch {set rs3 [inf_exec_stmt $stmt3 $classid]} msg]} {
				ob::log::write ERROR {do_bf_type_filter - $msg}
				err_bind "$msg"
			}
			
			inf_close_stmt $stmt3
			db_close $rs3

		}
	}
}


#
# Wrapper around proc to update a rules details for a sub-type
#
proc handle_upd_sub_rule args { 

	_do_upd_rule 1

	ADMIN::TYPE::go_type
} 


#
# Wrapper around proc to update a rules details for a type
#
proc handle_upd_rule args { 

	_do_upd_rule 0

	ob_log::write INFO {handle_upd_rule} 

	ADMIN::CLASS::go_class
} 

#
# Generic wrapper around proc to update a rule for sub-types/types
#
proc do_upd_rule {args} {

	set is_sub_type [reqGetArg IsSubType]

	ob_log::write INFO {do_upd_rule is_sub_type=$is_sub_type} 

	if {$is_sub_type == ""} { 
		set is_sub_type 0
	} 

	_do_upd_rule $is_sub_type
}

#
# proc to update the map rule for an openbet type/subtype
#
proc _do_upd_rule {{is_sub_type 0}} {

	set class_id 	[reqGetArg ClassId]
	set class_sort	[reqGetArg ClassSort]
	set type_id 	[reqGetArg TypeId]	
	
	ob_log::write INFO {_do_upd_rule is_sub_type=$is_sub_type class_id=$class_id class_sort=$class_sort type_id=$type_id}

	if {$is_sub_type} {
	
		set ob_id $type_id
	
		if { $class_id != "" && $type_id != "" && $class_sort != ""} {
			set sql [subst {
				select
					ev_sub_type_id as ob_id,
					name
				from
					tEvSubType
				where
					ev_type_id = ?
			}]
		} else { 	
			ob_log::write INFO {MISSING class_id=$class_id OR class_sort=$class_sort OR type_id=$type_id}
			return
		} 
		
	} else { 	
	
		set ob_id $class_id
	
		if { $class_id != ""  && $class_sort != ""} {
			set sql [subst {
				select
					ev_type_id as ob_id,
					name
				from
					tEvType
				where
					ev_class_id = ?
			}]
		} else { 			
			ob_log::write INFO {MISSING class_id=$class_id OR class_sort=$class_sort}
			return
		} 
	}	
		
	set stmt      	[inf_prep_sql $::DB $sql]
	set res_type  	[inf_exec_stmt $stmt $ob_id]
	set nrows  		[db_get_nrows $res_type]
		
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows } {incr i} {
			set type_id		[db_get_col $res_type $i ob_id]
			set name		[db_get_col $res_type $i name]

			if {$is_sub_type} {
				set sub_type_id($i) $type_id
				set ev_type_id($i)	$ob_id
			} else { 
				set sub_type_id($i) ""
				set ev_type_id($i)	$type_id
			} 			
			
			set ev_name($i)		$name
			set bf_ev_id($i)	[reqGetArg BF_TypeFilter_$type_id]
			set map_type($i)	[reqGetArg linkType_$type_id]

			if { $map_type($i) != "STR" && $map_type($i) != "ADD" && $map_type($i) != "BLL"} {
				set glob_desc($i)	[reqGetArg txtGlob_$type_id]
			} else {
				set glob_desc($i)	""
			}

			set glob_desc_exclude($i)	""

			set glob_desc_exclude($i)	[reqGetArg txtGlobExclude_$type_id]

			if {[reqGetArg isStdEvt_$type_id] == "on"} {
				set is_std_hr($i)	"Y"	
			} else {
				set is_std_hr($i) 	"N"
			}							

			# For updating the Event Type Rules to also Store the Auto-Match mode value for each Event Type
			set auto_match_mode($i)		[reqGetArg BF_AutoMatch_$type_id]
		}
	}

	inf_close_stmt $stmt
	db_close $res_type

	if {$nrows > 0} {
		for {set i 0} {$i < $nrows } {incr i} {

			ob::log::write INFO {MAP $i = $map_type($i) ev_type_id=$ev_type_id($i)} 

			# insert/update a row into the tBFMap table
			
			if {[OT_CfgGet BF_INF731_COMPLIANT 0]} { 
				set param_desc_excl "p_glob_desc_excl = ?,"
			} else { 
				set param_desc_excl "p_glob_desc_exclude = ?,"
			} 
			
			set sql1 [subst {
				execute procedure pBFUpdMap (
					p_adminuser     	= ?,
					p_ob_type       	= ?,
					p_ob_id         	= ?,
					p_bf_ev_items_id	= ?,						
					p_map_type			= ?,
					p_glob_desc			= ?,
					$param_desc_excl         
					p_is_std_hr			= ?,
					p_auto_match_mode 	= ?,
					p_ob_sub_type_id    = ?
				)
			}]			

			set stmt1 [inf_prep_sql $::DB $sql1]

			if {$class_sort != "HR" && $class_sort != "GR"} {
				# NON RACING
				if {$bf_ev_id($i) != "" } {
					if {[catch {
						set rs1 [inf_exec_stmt $stmt1 $::USERNAME\
													"ET"\
													$ev_type_id($i)\
													$bf_ev_id($i)\
													$map_type($i)\
													$glob_desc($i)\
													$glob_desc_exclude($i)\
													$is_std_hr($i)\
													$auto_match_mode($i)\
													$sub_type_id($i)]} msg]} {
									ob::log::write ERROR {_do_upd_rule - $msg}
									err_bind "$msg"
					}
					inf_close_stmt $stmt1
					db_close $rs1
				} else {
					# delete the row from the tBFMap table					
					if {$is_sub_type} {
						set sql3 [subst {
							delete from
								tBFMap
							where
								ob_id = ?
							and ob_type = ?
							and ob_sub_type_id = ? 
						}]
						
						set stmt3 [inf_prep_sql $::DB $sql3]
						
						if {[catch {set rs3 [inf_exec_stmt $stmt3 $ob_id "ET" $sub_type_id($i)]} msg]} {
							ob::log::write ERROR {_do_upd_rule - $msg}
							err_bind "$msg"
						}
						
					} else { 
						set sql3 [subst {
							delete from
								tBFMap
							where
								ob_id = ?
							and ob_type = ?
						}]			
						
						set stmt3 [inf_prep_sql $::DB $sql3]
						
						if {[catch {set rs3 [inf_exec_stmt $stmt3 $ev_type_id($i) "ET"]} msg]} {
							ob::log::write ERROR {_do_upd_rule - $msg}
							err_bind "$msg"
						}
					} 
					
					inf_close_stmt $stmt3
					db_close $rs3

				}
			} else {
				# RACING
				if {$class_sort == "HR"} { 
					set racing_desc [OT_CfgGet BF_HORSE_RACING_TYPE "Horse Racing"]
				} else { 
					set racing_desc [OT_CfgGet BF_GREYHOUND_RACING_TYPE "Greyhound Racing"]
				} 

				if {$glob_desc($i) != "" || $is_std_hr($i) == "Y"} {

					if {$glob_desc($i) != ""} {

						regsub -all {\%} $glob_desc($i) "" glob_desc_sub 

						set sql_g [subst {
							execute procedure pBFInsSynonym (
								p_syn_group_id 	= ?,
								p_syn_desc1 	= ?,
								p_syn_desc2 	= ?,
								p_syn_type 		= ?
							)
						}]

						set stmt_g [inf_prep_sql $::DB $sql_g]
						if {[catch {set rs1 [inf_exec_stmt $stmt_g "" $ev_name($i) $glob_desc_sub "" ]} msg]} {
							ob::log::write ERROR {_do_upd_rule - $msg}
							err_bind "$msg"
						}

						ob::log::write INFO { _do_upd_rule: synonyms added $ev_name($i), $glob_desc_sub}
					}						

					set sql2 [subst {
						select
							bf_ev_items_id
						from
							tBFEvItems
						where
							bf_desc="$racing_desc"
							and bf_type='ET'
					}]

					set stmt2      [inf_prep_sql $::DB $sql2]
					set res_type2  [inf_exec_stmt $stmt2]
					set nrows2  [db_get_nrows $res_type2]

					if {$nrows2 > 0} {
						set bf_ev_id_hr		[db_get_col $res_type2 0 bf_ev_items_id]
					}

					inf_close_stmt $stmt2
					db_close $res_type2

					if {[catch {set rs1 [inf_exec_stmt $stmt1 $::USERNAME\
							"ET"\
							$ev_type_id($i)\
							$bf_ev_id_hr\
							$class_sort\
							$glob_desc($i)\
							$glob_desc_exclude($i)\
							$is_std_hr($i)\
							$auto_match_mode($i)\
							$sub_type_id($i)]} msg]} {
						ob::log::write ERROR {_do_upd_rule - $msg}
						err_bind "$msg"
					}
					inf_close_stmt $stmt1
					db_close $rs1
				
				} else {
				
					# delete the row from tbfmap table
					if {$is_sub_type} {
						set sql3 [subst {
							delete from
								tBFMap
							where
								ob_id = ?
							and ob_type = ?
							and ob_sub_type_id = ? 
						}]

						set stmt3 [inf_prep_sql $::DB $sql3]

						if {[catch {set rs3 [inf_exec_stmt $stmt3 $ob_id "ET" $ev_type_id($i)]} msg]} {
							ob::log::write ERROR {_do_upd_rule - $msg}
							err_bind "$msg"
						}

					} else { 
						set sql3 [subst {
							delete from
								tBFMap
							where
								ob_id = ?
							and ob_type = ?
						}]			

						set stmt3 [inf_prep_sql $::DB $sql3]

						if {[catch {set rs3 [inf_exec_stmt $stmt3 $ev_type_id($i) "ET"]} msg]} {
							ob::log::write ERROR {_do_upd_rule - $msg}
							err_bind "$msg"
						}
					} 
					
					inf_close_stmt $stmt3
					db_close $rs3
				}
			}
		}
	}
}


#
# Check to see if we should bind up Betfair class matching 
# information for this class. Currently LIVE BETTING for 
# CentreBet doesn't have a mapping at the class level. 
#
# returns 1 (match) 0 (ignore) 
#
proc bf_class_match {lookup_type desc} {

	ob_log::write INFO {bf_class_match $lookup_type $desc} 

	if {$lookup_type == "NAME"} {
		set class_name $desc
	} else {
		set class_name ""
		
		set sql [subst {
					select
						name
					from
						tevclass
					where
						ev_class_id = ?					
		}]
			
		set stmt [inf_prep_sql $::DB $sql]
	
		if {[catch {set rs [inf_exec_stmt $stmt $desc]} msg]} {
			ob::log::write ERROR {bf_class_match - $msg}
			err_bind "$msg"
		} else {
				
			if {[db_get_nrows $rs] > 0} {
				set class_name [db_get_col $rs 0 name]
			} else {
				err_bind "class not found for id=$desc"
			} 
		}	
	}

	set lClassList [OT_CfgGet BF_IGNORE_CLASS_MATCH ""]
	
	if {[llength $lClassList] == 0} { 		
		return 1
	}

	foreach item $lClassList {	
		if {$class_name == $item} {
			tpSetVar NoBFClassMap 1
			return 0 
		} 
	} 
	
	return 1
}

# end of namespace
}