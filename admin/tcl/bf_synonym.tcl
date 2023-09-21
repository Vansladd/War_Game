# ==============================================================
# $Id: bf_synonym.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETFAIR_SYN {

asSetAct ADMIN::BETFAIR_SYN::GoBFSynonym           [namespace code go_bf_synonym]
asSetAct ADMIN::BETFAIR_SYN::DoBFSynonym           [namespace code do_bf_synonym]


#
#-----------------------------------------------------------------------------------------
# Go to the Synonym list page
#-----------------------------------------------------------------------------------------
#
proc go_bf_synonym args {
	tpSetVar SynMod 0
	global SYNGRP
	if {[info  exists SYNGRP]} {
		unset SYNGRP
	}

	set NumGrp 0
	set SynGrps [OT_CfgGet BF_DEF_SEARCH_LIST ""]
	foreach grp $SynGrps {
		set SYNGRP($NumGrp,name) $grp
		incr NumGrp
	}
	tpBindVar SynDescr SYNGRP name grp_idx
	tpBindVar SynGrpId SYNGRP name grp_idx
	tpSetVar  Nrows $NumGrp
	asPlayFile -nocache bf_synonym.html
}

#
#-----------------------------------------------------------------------------------------
# Go to the Add Synonym page
#-----------------------------------------------------------------------------------------
#
proc go_add_synonym args {
	tpSetVar SynAdded 1
	asPlayFile -nocache bf_add_synonym.html
}

#
#-----------------------------------------------------------------------------------------
# Go to the Update Synonym page
#-----------------------------------------------------------------------------------------
#
proc go_upd_synonym args {

	global DB
	global SYNONYMS

	set syn_grp_id [reqGetArg SynGrpSelId]

	if {$syn_grp_id != ""} {

		#to select all the synonyms under this group id
		set sql {
			select
				syn_desc
			from
				tBFSynonym
			where
				syn_group_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set rs [inf_exec_stmt $stmt $syn_grp_id]} msg]} {
			err_bind $msg
			ob::log::write ERROR {go_upd_synonym - $msg}
		}

		inf_close_stmt $stmt

		set SYNONYMS(nrows) [db_get_nrows $rs]
		if { $SYNONYMS(nrows) == 0} {
			go_bf_synonym
			return
		} else {
			for {set i 0} {$i < $SYNONYMS(nrows)} {incr i} {
				set SYNONYMS($i,syn_desc)   [db_get_col $rs $i syn_desc]
			}
			tpBindString SYNONYMS_NROWS $SYNONYMS(nrows)
			tpBindVar SynDescr SYNONYMS syn_desc grp_idx
			tpBindString SynGrpSelId $syn_grp_id
		}
		db_close $rs
	}

	tpBindString SynType [reqGetArg SynType] 
	asPlayFile bf_modify_synonym.html
}

#
#-----------------------------------------------------------------------------------------
# Do Search or Update or Add the synonym to/from  tBFSynonym
#-----------------------------------------------------------------------------------------
#
proc do_bf_synonym args {

        global DB

        set act [reqGetArg SubmitName]

        if {$act == "SearchSyn"} {
                do_search_synonym
        } elseif {$act == "GoAddSyn"} {
		go_add_synonym
        } elseif {$act == "DoAddSyn"} {
                do_add_synonym
        } elseif {$act == "DoAddSyntoGrp"} {
                do_add_syn_to_grp
        } elseif {$act == "DoUpdSyn"} {
                do_upd_synonym
        } elseif {$act == "GoUpdSyn"} {
                go_upd_synonym
        } elseif {$act == "DelSyn"} {
                do_del_synonym
        } elseif {$act == "QSearchSyn"} {
                do_search_synonym
	} elseif {$act == "GoUplSyn"} {
		ADMIN::UPLOAD::go_upload
        } elseif {$act == "Back"} {
		go_bf_synonym
        }

}



#
#------------------------------------------------------------------------------------------
# Retrieving the list of synonyms which satisfy the criteria
#------------------------------------------------------------------------------------------
#
proc do_search_synonym args {

	global DB
	global SYNONYMS

	if {[info exists SYNONYMS]} {
		unset SYNONYMS
	}
	
	set qsearch [reqGetArg SynGrpSelId]

	if {$qsearch == ""} {
		set orig_syn_type   [reqGetArg SynType]
		set orig_syn_desc   [reqGetArg SynDesc]
		set orig_match_type [reqGetArg MatchType]
		# check for the search type
		switch -- $orig_match_type {
			ST {
			set orig_syn_desc "$orig_syn_desc%"
			}
			EN {
			set orig_syn_desc "%$orig_syn_desc"
			}
			CN {
			set orig_syn_desc "%$orig_syn_desc%"
			}
		}
		tpBindString MatchType $orig_match_type
	} else {
		set orig_syn_type "ID"
		set orig_syn_desc "$qsearch%"
	}

	#
	# To retrieve the group_id,syn_desc of synonyms which match the
	# criteria from tBFSynonym.
	#
	set sql {
		select
			syn_group_id,
			syn_desc
		from
			tBFSynonym
		where
			syn_group_id in (
				select
					distinct syn_group_id
				from
					tBFSynonym
				where
					syn_type = ? and
	}

	# To make the search case insensitive
	if {[reqGetArg SynCase] == "Y"} {
		append sql	" upper(syn_desc) like ?"
		set orig_syn_desc [string toupper $orig_syn_desc]
		tpBindString SynCase "Y"
	} else {
		append sql	" syn_desc like ?"
	}
	append sql " )"
	append sql " order by 1,2"

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $orig_syn_type $orig_syn_desc]} msg]} {
		err_bind $msg
		ob::log::write ERROR {do_search_synonym - $msg}
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	#
	# To populate SYNONYM - all the synonyms that belong to the groups
	#
	set curr_grp_id         -1
	set grp_idx             -1
	set SYNONYMS(num_grp)    0
	
	if {$nrows == 0} {
		tpBindString Nrows $nrows
		go_bf_synonym
		return
	} else {
		tpSetVar SynMod 1
	}

	for {set i 0} {$i < $nrows} {incr i} {
		# To syn_desc into groups that it belongs to
		if {[set syn_grp_id [db_get_col $rs $i syn_group_id]] != $curr_grp_id} {
			incr grp_idx
			set desc_idx -1
			set curr_grp_id $syn_grp_id
			set SYNONYMS($grp_idx,num_desc)   0
			set SYNONYMS($grp_idx,syn_grp_id) [db_get_col $rs $i syn_group_id]
			set SYNONYMS($grp_idx,syn_desc)   [db_get_col $rs $i syn_desc]
			incr SYNONYMS(num_grp)
		} else {
			set SYNONYMS($grp_idx,syn_desc)   "$SYNONYMS($grp_idx,syn_desc),[db_get_col $rs $i syn_desc]"
		}
		incr desc_idx
		incr SYNONYMS($grp_idx,num_desc)
	}

	db_close $rs

	#Binding synonyms
	tpBindVar SynGrpId SYNONYMS syn_grp_id grp_idx
	tpBindVar SynDescr SYNONYMS syn_desc   grp_idx
	tpBindVar NumDesc  SYNONYMS num_desc   grp_idx

	tpSetVar Nrows     $SYNONYMS(num_grp)
	tpBindString SynType   $orig_syn_type
	tpBindString SynDesc   [reqGetArg SynDesc]

	# to show all the search results page


	asPlayFile -nocache bf_synonym.html
}

#
#------------------------------------------------------------------------------------------------
# Adding the Synonym to tBfSynonym table
#------------------------------------------------------------------------------------------------
#
proc do_add_synonym args {

        global DB
	global SYNONYMS

	#get the synonym type
	set syn_type [reqGetArg SynType]
	ob_log::write INFO {do_add_synonym - Synonym Type: $syn_type }

        # To retrieve the maximum syn_group_id from tBFSynonym
        #
        set sql {
                select
                       max(syn_group_id) as syn_grp_id
                from
                        tBFSynonym
        }

        set stmt [inf_prep_sql $DB $sql]

        if {[catch {set rs [inf_exec_stmt $stmt]} msg]} {
                err_bind $msg
                ob::log::write ERROR {do_add_synonym - $msg}
        }

        inf_close_stmt $stmt

        set nrows [db_get_nrows $rs]

        # the new syn_grp_id is always one greater than the max syn_grp_id
        if {$nrows == 1} {
                set last_syn_grp_id [db_get_col $rs 0 syn_grp_id]
        } else {
                set last_syn_grp_id 0
        }

        set new_syn_grp_id [expr $last_syn_grp_id + 1]
	
	ob_log::write INFO {do_add_synonym - New Synonym group $new_syn_grp_id created.}
	
	#add the synonym
	set sql_d [subst {
		execute procedure pBFInsSynonym(
			p_syn_group_id = ?,
			p_syn_desc1    = ?,
			p_syn_desc2    = ?,
			p_syn_type     = ?
		)
	}]

	set stmt_d [inf_prep_sql $DB $sql_d]



	#retrieve the list of synonyms to be added
	set args_count [reqGetNumVals]
	set syn_count 0; set syn_exception 0
	set syn_desc_list ""
	for {set i 0} {$i < $args_count} {incr i} {
		set syn_name [reqGetNthName $i]
		set syn_desc [reqGetNthVal $i]
		if { $syn_name == "SynName" && $syn_exception == 0} {
			ob_log::write INFO {do_add_synonym -  Synonym: $syn_desc to be added to group $new_syn_grp_id}
			set SYNONYMS($syn_count,syn_desc) $syn_desc
			if {$syn_desc_list == ""} {
				append syn_desc_list '$syn_desc'
			} else {
				append syn_desc_list ","
				append syn_desc_list '$syn_desc'
			}
			if {$syn_count == 0} {
				set SYNONYMS($syn_count,First) 1
			} else {
				set SYNONYMS($syn_count,First) 0
			}
			if { $syn_exception == 0 } {
				#validate the synonym name
				if {([string first "%" $syn_desc] != -1)} {
                                        set syn_exception 1
                                        set excp_msg "$syn_desc is not a valid synonym."
                        	} elseif {($syn_desc=="")} {
                                        set syn_exception 1
                                        set excp_msg "Synonym string can't be empty."
				}
			}
			incr syn_count
		}
		
	}
	if { $syn_exception == 0 } {
		set sql_c "select 
				syn_desc 
			   from 
			   	tbfsynonym 
			   where 
			   	syn_desc in ($syn_desc_list)"
		set stat_c [inf_prep_sql $DB $sql_c]
		set s [inf_exec_stmt $stat_c]
		set nrows [db_get_nrows $s]
		if {$nrows != 0} {
			set syn_exception 1
			set syn_desc ""
			for {set i 0} {$i < $nrows} {incr i} {
				if {$syn_desc == ""} {
					append syn_desc [db_get_col $s $i syn_desc]
				} else {
					append syn_desc ","
					append syn_desc [db_get_col $s $i syn_desc]
				}
			}
			set excp_msg "Synonym ($syn_desc) already exist"
		} else {
			inf_begin_tran $DB
			#check if there is an exception
			for {set i 0} {$i < $args_count} {incr i} {
				set syn_name [reqGetNthName $i]
				set syn_desc [reqGetNthVal $i]
				if { $syn_name == "SynName" } {
					if {[catch {inf_exec_stmt $stmt_d\
						$new_syn_grp_id\
							$syn_desc\
							""\
							$syn_type
					} msg]} {
						set syn_exception 1
						set excp_msg "Synonym $syn_desc couldn't be added: $msg"
					}
				}
				if {$syn_exception} {
					break
				}
			}
			#check if the transaction is successful
			if {$syn_exception} {
				inf_rollback_tran $DB
				inf_close_stmt $stmt_d
			} else {
				inf_commit_tran $DB
				inf_close_stmt $stmt_d
				tpBindString msg_d "Synonyms updated successfully" 
				tpSetVar SynAdded 1
				ob_log::write INFO {do_add_synonym - Synonyms added successfully to group $new_syn_grp_id}
			}
		}
	}

	if {$syn_exception} {
		tpSetVar SynAdded 0
		tpBindString SynAdded 0
		tpBindString SYNONYMS(nrows) $syn_count
		tpBindVar SynDescr SYNONYMS syn_desc   grp_idx 
		tpBindVar First SYNONYMS First   grp_idx
		tpBindString msg_d $excp_msg
		ob_log::write INFO {do_add_synonym - Synonyms addition failed for group $new_syn_grp_id}
	}

	tpBindString SynType [reqGetArg SynType]

        # retun to the add synonym page added
	asPlayFile bf_add_synonym.html
	return 0
}
#
#---------------------------------------------------------------------------------------------
# updating a synonym to an existing group
#---------------------------------------------------------------------------------------------
#
proc do_upd_synonym args {

        global DB

	#retrieve the group id
	set syn_grp_id [reqGetArg SynGrpSelId]
	set args_count [reqGetNumVals]

	#update the synonym
	set sql {
		update                        
			tBFSynonym
		set
			syn_desc = ?
		where
			syn_group_id = ?
		and 
			syn_desc = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	#retrieve the list of synonyms to be updated
	for {set i 0} {$i < $args_count} {incr i} {
		set arg_name [reqGetNthName $i]
		set arg_val [reqGetNthVal $i]
		if { $arg_name == "SyntoUpd" } {
			ob_log::write INFO { do_upd_synonym update request for synonym : $arg_val}
			#check if the synonym value if same as exsisting 
			if { $arg_val !=  ([reqGetArg UPD_$arg_val]) } {
				set new_syn_desc [reqGetArg UPD_$arg_val]
				# Checking whether the syn_desc already exists
				if {![check_synonym_exists $new_syn_desc]} {
					if {$syn_grp_id != ""} {
						if {[catch {set rs [inf_exec_stmt $stmt $new_syn_desc $syn_grp_id $arg_val]} msg]} {
							err_bind $msg
							ob::log::write ERROR {do_upd_synonym - $msg}
						}
					}
        				tpSetVar SynUpdated 1
					inf_close_stmt $stmt
					db_close $rs
				} else {
					ob_log::write INFO {go_upd_synonym - $new_syn_desc already exists}
        				tpSetVar SynUpdated 0
				}
			}
		}
	}
	#return to the update page
        go_upd_synonym
}

#
#---------------------------------------------------------------------------------------------
# Checks whether synonym already exists in tBFSynonym
# Returns	0 - when syn_desc exists in tBFSynonym
#		1 - when not exists
#---------------------------------------------------------------------------------------------
#
proc check_synonym_exists {syn_desc} {

	global DB

	# syn_desc already exists or not
	set sql {
                select
			1
		from
                        tBFSynonym
                where
                        syn_desc = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set rs [inf_exec_stmt $stmt $syn_desc]} msg]} {
                err_bind $msg
                ob::log::write ERROR {check_synonym_exists - $msg}
	}

	inf_close_stmt $stmt

        set nrows [db_get_nrows $rs]

	db_close $rs

	if {$nrows > 0} {
		# to show synonym already exists
		tpSetVar SynExists 1
		return 1
	}

	return 0
}

#
#---------------------------------------------------------------------------------------------
# deleteing the Synonym/s from tBFSynonym table
#---------------------------------------------------------------------------------------------
#
proc do_del_synonym args {

	global DB

	#retrive the group id
	set syn_grp_id [reqGetArg SynGrpSelId]
	set args_count [reqGetNumVals]

	#delete the synonym 
	set sql {
		delete from                        
			tBFSynonym
		where
			syn_group_id = ?
		and 
			syn_desc = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	#retrieve the list of synonyms to be deleted
	for {set i 0} {$i < $args_count} {incr i} {
		set arg_name [reqGetNthName $i]
		set arg_val [reqGetNthVal $i]
		if { $arg_name == "SyntoUpd" } {
			set syn_to_del [reqGetArg UPD_$arg_val]
			# Checking whether the syn_desc exists
			if {[check_synonym_exists $syn_to_del]} {
				if {$syn_grp_id != ""} {
					if {[catch {set rs [inf_exec_stmt $stmt $syn_grp_id $syn_to_del]} msg]} {
						err_bind $msg
						ob::log::write ERROR {do_del_synonym - $msg}
					}
				}
				ob_log::write INFO {do_del_synonym :::: $syn_to_del deleted.}
        			tpSetVar SynDeleted 1
				tpSetVar SynExists 0
				db_close $rs
			} else {
				ob_log::write INFO {do_del_synonym :::: $syn_to_del doesn't exists}
        			tpSetVar SynDeleted 0
			}
		}
		
	}
	inf_close_stmt $stmt
	#return to the update synonym page
        go_upd_synonym
}

#
#---------------------------------------------------------------------------------------------
# Adding a synonym to an existing group 
#---------------------------------------------------------------------------------------------
#
proc do_add_syn_to_grp args {

	global DB

	#retrieve the synonym group, type and description
	set syn_type [reqGetArg SynType]
	set syn_grp_id [reqGetArg SynGrpSelId]
	set syn_desc [reqGetArg SynName] 

	ob_log::write INFO {do_add_syn_to_grp syn_type=$syn_type, syn_grp_id=$syn_grp_id and syn_desc=$syn_desc.}

	#validate the synonym
	if {([string first "%" $syn_desc] != -1)} {
		tpSetVar SynUpdated 0
	} elseif {($syn_desc=="")} {
		tpSetVar SynUpdated 0
	} elseif {$syn_grp_id != "" && !([check_synonym_exists $syn_desc])} {

		#add the synonym
		set sql_d [subst {
			execute procedure pBFInsSynonym(
				p_syn_group_id = ?,
				p_syn_desc1    = ?,
				p_syn_desc2    = ?,
				p_syn_type     = ?
			)
		}]

		set stmt_d [inf_prep_sql $DB $sql_d]

		if {[catch {set rs [inf_exec_stmt $stmt_d $syn_grp_id $syn_desc "" $syn_type]} msg]} {
			err_bind $msg
			ob::log::write ERROR {do_add_syn_to_grp - $msg}
		}

		inf_close_stmt $stmt_d
		db_close $rs
		tpSetVar SynUpdated 1
	}
	#return to the update synonym page
	go_upd_synonym
}


}
