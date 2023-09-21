# ==============================================================
# $Id: aff.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::AFF {

asSetAct ADMIN::AFF::GoUploadAffList [namespace code go_upload_aff_list]
asSetAct ADMIN::AFF::GoAffList       [namespace code go_aff_list]
asSetAct ADMIN::AFF::GoAff           [namespace code go_aff]
asSetAct ADMIN::AFF::GoAffGrp        [namespace code go_aff_grp]
asSetAct ADMIN::AFF::GoBeFreePrg     [namespace code go_befree_program]
asSetAct ADMIN::AFF::GoBeFreeAffPrg  [namespace code go_befree_affprog]
asSetAct ADMIN::AFF::DoAff           [namespace code do_aff]
asSetAct ADMIN::AFF::DoAffGrp        [namespace code do_aff_grp]
asSetAct ADMIN::AFF::DoBeFreeAffPrg  [namespace code do_befree_affprog]
asSetAct ADMIN::AFF::DoBeFreePrg     [namespace code do_befree_program]
asSetAct ADMIN::AFF::AffUtdAdd       [namespace code add_aff_utd_code]
asSetAct ADMIN::AFF::DelAffUtd       [namespace code del_aff_utd_code]
asSetAct ADMIN::AFF::AddAdvCode      [namespace code add_advertiser_code]
asSetAct ADMIN::AFF::DelAdvCode      [namespace code del_advertiser_code]
asSetAct ADMIN::AFF::FindAdvCode     [namespace code do_adv_popup]
asSetAct ADMIN::AFF::SearchAdvCode   [namespace code do_adv_popup_search]

#
# Get the list of affiliates
#

#########################
proc validate_response {http_response} {
#########################

	set http_error 		[http::error $http_response]
	set http_code 		[http::code $http_response]
	set http_wait 		[http::wait $http_response]

	if {$http_wait != "ok"} {
		return [list 1 "TIMEOUT (code=$http_wait)"]
	}
	if {$http_error != ""} {
		return [list 1 "HTTP_ERROR (code=$http_error)"]
	}
	if {$http_code != "HTTP/1.1 200 OK"} {
		return [list 1 "HTTP_WRONG_CODE (code=$http_code)"]
	}
	return [list 0 OK]
}

# populate a filter select
proc populate_filter {is_aff} {

	global DATA

	# if this is an affiliate filter then set var names
	# and sql for affiliates
	if {$is_aff} {
		set first_char_name {first_char_a}
		set first_char_id   {first_char_a_idx}
		set first_char_num  {num_first_chars_a}

	# else set var names and sql for aff programs
	} else {
		set first_char_name {first_char_p}
		set first_char_id   {first_char_p_idx}
		set first_char_num  {num_first_chars_p}
	}

	set DATA($first_char_num) 24

	# create array of chars
	for {set i 0} {$i < 25} {incr i} {
		set DATA($i,$first_char_name) [format %c [expr $i+65]]
	}

	tpBindVar $first_char_name DATA $first_char_name $first_char_id

}

# get the list of affiliates
proc get_affiliates {{is_filtered 0}} {

	global DB DATA

	# constant for no group
	set NO_GROUP {-1}

	# constant for any group
	set ANY_GROUP {0}

	# constant for any char
	set ANY_CHAR {0}

	# populate the filter select
	populate_filter 1

	# get the group constraint from the request
	set group_id [reqGetArg group]

	# get the first char constraint from the request
	set first_char [reqGetArg first_char_a]

	# if both group and first char are blank (show none selected)
	# then return nothing
	if {$is_filtered && $group_id == "" && $first_char == ""} {
		# bind affiliate data
		set DATA(numAffs) 0

	# else return some data
	} else {

		set affSql {
			select
				a.aff_id,
				g.aff_grp_name,
				a.aff_name,
				a.cr_date,
				a.status,
				a.free_bet,
				a.channels,
				a.image,
				a.url
			from
				tAffiliate          a,
				outer tAffiliateGrp g
			where
				a.aff_grp_id = g.aff_grp_id
		}

		if {$is_filtered} {

			if {$group_id == $NO_GROUP} {
				append affSql {
					and
						a.aff_grp_id is null
				}
			} elseif {$group_id != $ANY_GROUP && $group_id != ""} {
				append affSql "
					and
						a.aff_grp_id = $group_id
				"
			}

			if {$first_char != $ANY_CHAR && $first_char != ""} {
				append affSql "
					and
						(
							a.aff_name LIKE ('[string tolower $first_char]%')
						or
							a.aff_name LIKE ('[string toupper $first_char]%')
						)
				"
			}
		}

		# order by
		append affSql {
			order by
				a.aff_name asc
		}

		set affStmt [inf_prep_sql $DB $affSql]
		set affRes  [inf_exec_stmt $affStmt]
		inf_close_stmt $affStmt

		set numAffs    [db_get_nrows $affRes]

		# bind affiliate data
		set DATA(numAffs) $numAffs
		for {set i 0} {$i < $numAffs} {incr i} {
			set DATA($i,aff_id)       [db_get_col $affRes $i aff_id]
			set DATA($i,aff_name)     [db_get_col $affRes $i aff_name]
			if {[db_get_col $affRes $i aff_grp_name] == ""} {
				set grp_name "No Group"
			} else {
				set grp_name [db_get_col $affRes $i aff_grp_name]
			}
			set DATA($i,aff_grp_name) $grp_name
			set DATA($i,cr_date)      [db_get_col $affRes $i cr_date]
			set DATA($i,status)       [db_get_col $affRes $i status]
			set DATA($i,free_bet)     [db_get_col $affRes $i free_bet]
			set DATA($i,channels)     [db_get_col $affRes $i channels]
			set DATA($i,image)	      [db_get_col $affRes $i image]
			set DATA($i,url)	      [db_get_col $affRes $i url]
		}
		tpBindVar AffId      DATA aff_id	   aff_idx
		tpBindVar AffName    DATA aff_name     aff_idx
		tpBindVar AffGrpName DATA aff_grp_name aff_idx
		tpBindVar AffCreated DATA cr_date      aff_idx
		tpBindVar AffStatus  DATA status       aff_idx
		tpBindVar AffFreeBet DATA free_bet     aff_idx
		tpBindVar AffChannel DATA channels     aff_idx
		tpBindVar AffImage	 DATA image	       aff_idx
		tpBindVar AffURL	 DATA url	       aff_idx

		db_close $affRes

	}
}

#
# Get the list of affiliate groups
#
proc get_affiliate_groups {} {

	global DB DATA

	set grpSql {
		select
			g.aff_grp_id,
			g.aff_grp_name,
			g.cr_date,
			g.status
		from
			tAffiliateGrp g
		order by
			g.aff_grp_name
	}

	set grpStmt [inf_prep_sql $DB $grpSql]
	set grpRes  [inf_exec_stmt $grpStmt]
	inf_close_stmt $grpStmt

	set numGrps    [db_get_nrows $grpRes]

	#Bind group data
	set DATA(numGrps) $numGrps
	for {set i 0} {$i < $numGrps} {incr i} {
		set DATA($i,g_aff_grp_id)   [db_get_col $grpRes $i aff_grp_id]
		set DATA($i,g_aff_grp_name) [db_get_col $grpRes $i aff_grp_name]
		set DATA($i,g_cr_date)      [db_get_col $grpRes $i cr_date]
		set DATA($i,g_status)       [db_get_col $grpRes $i status]
	}
	tpBindVar grpAffGrpId      DATA g_aff_grp_id   aff_grp_idx
	tpBindVar grpAffGrpName    DATA g_aff_grp_name aff_grp_idx
	tpBindVar grpAffGrpCreated DATA g_cr_date      aff_grp_idx
	tpBindVar grpAffGrpStatus  DATA g_status       aff_grp_idx

	db_close $grpRes
}

#
# Get the list of BeFree programs
#
proc get_befree_programs {} {

	global DB DATA DATA_P

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set grpSql {
		select
			p.prog_id,
			p.ext_prog_id,
			p.prog_name,
			p.file_name,
			p.status
		from
			tProgram p
		order by
			p.prog_name
	}

	set grpStmt     [inf_prep_sql $DB $grpSql]
	set grpRes      [inf_exec_stmt $grpStmt]
	inf_close_stmt  $grpStmt

	set numProgs    [db_get_nrows $grpRes]

	#Bind prog data
	set DATA(numProgs) $numProgs

	for {set i 0} {$i < $numProgs} {incr i} {
		set DATA($i,p_prog_id)       [db_get_col $grpRes $i prog_id]
		set DATA($i,p_ext_prog_id)   [db_get_col $grpRes $i ext_prog_id]
		set DATA($i,p_prog_name)     [db_get_col $grpRes $i prog_name]
		set DATA($i,p_filename)      [db_get_col $grpRes $i file_name]
		set DATA($i,p_status)        [db_get_col $grpRes $i status]
		set DATA_P([db_get_col $grpRes $i prog_id]) [db_get_col $grpRes $i prog_name]

	}

	tpBindVar p_prog_id      DATA p_prog_id      aff_prg_idx
	tpBindVar p_ext_prog_id  DATA p_ext_prog_id  aff_prg_idx
	tpBindVar p_prog_name    DATA p_prog_name    aff_prg_idx
	tpBindVar p_filename     DATA p_filename     aff_prg_idx
	tpBindVar p_status       DATA p_status       aff_prg_idx

	db_close $grpRes
}

#
# Get the list of BeFree affiliate programs
#
proc get_befree_aff_progs {} {

	global DB DATA

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	# constant for any group
	set ANY_PROGRAM {0}

	# constant for any char
	set ANY_CHAR {0}

	# populate the filter select
	populate_filter 0

	# get the program constraint from the request
	set program_id [reqGetArg program]

	# get the first char constraint from the request
	set first_char [reqGetArg first_char_p]

	# if both program and first char are blank (show none selected)
	# then return nothing
	if {$program_id == "" && $first_char == ""} {
		# bind affiliate data
		set DATA(numAffPrgs) 0

	# else return some data
	} else {

		set grpSql {
			select
				a.aff_id,
				a.prog_id,
				a.bf_id,
				a.source_id,
				a.reg_aff,
				a.bet_aff,
				a.status,
				p.prog_name,
				p.ext_prog_id,
				af.aff_name
			from
				taffprogram a,
				tprogram p,
				taffiliate af
			where
				p.prog_id = a.prog_id
			and
				a.aff_id = af.aff_id
		}


		if {$program_id != $ANY_PROGRAM && $program_id != ""} {
			append grpSql "
				and
					a.prog_id = $program_id
			"
		}

		if {$first_char != $ANY_CHAR && $first_char != ""} {
			append grpSql "
				and
					(
						af.aff_name LIKE ('[string tolower $first_char]%')
					or
						af.aff_name LIKE ('[string toupper $first_char]%')
					)
			"
		}

		# order by
		append grpSql {
			order by
				a.prog_id asc,
				af.aff_name asc
		}

		set grpStmt [inf_prep_sql $DB $grpSql]
		set grpRes  [inf_exec_stmt $grpStmt]
		inf_close_stmt $grpStmt

		set numAffPrgs    [db_get_nrows $grpRes]

		#Bind prog data
		set DATA(numAffPrgs) $numAffPrgs

		for {set i 0} {$i < $numAffPrgs} {incr i} {
			if {[db_get_col $grpRes $i prog_name] == ""} {
				set prog_name2 "No Program"
			} else {
				set prog_name2 [db_get_col $grpRes $i prog_name]
			}
			set DATA($i,bf_aff_id)         [db_get_col $grpRes $i aff_id]
			set DATA($i,bf_aff_name)       [db_get_col $grpRes $i aff_name]
			set DATA($i,bf_prog_id)        [db_get_col $grpRes $i prog_id]
			set DATA($i,bf_ext_prog_id)    [db_get_col $grpRes $i ext_prog_id]
			set DATA($i,bf_bf_id)          [db_get_col $grpRes $i bf_id]
			set DATA($i,bf_source_id)      [db_get_col $grpRes $i source_id]
			set DATA($i,bf_reg_aff)        [db_get_col $grpRes $i reg_aff]
			set DATA($i,bf_bet_aff)        [db_get_col $grpRes $i bet_aff]
			set DATA($i,bf_prog_name2)     [db_get_col $grpRes $i prog_name]
			set DATA($i,bf_status)         [db_get_col $grpRes $i status]
		}

		tpBindVar a_aff_id        DATA bf_aff_id      aff_prg_idx
		tpBindVar a_aff_name      DATA bf_aff_name    aff_prg_idx
		tpBindVar a_prog_id       DATA bf_prog_id     aff_prg_idx
		tpBindVar a_ext_prog_id   DATA bf_ext_prog_id aff_prg_idx
		tpBindVar a_bf_id         DATA bf_bf_id       aff_prg_idx
		tpBindVar a_source_id     DATA bf_source_id   aff_prg_idx
		tpBindVar a_reg_aff       DATA bf_reg_aff     aff_prg_idx
		tpBindVar a_bet_aff       DATA bf_bet_aff     aff_prg_idx
		tpBindVar a_prog_name2    DATA bf_prog_name2  aff_prg_idx
		tpBindVar a_status        DATA bf_status      aff_prg_idx

		db_close $grpRes
	}
}

#
# ----------------------------------------------------------------------------
# Go to BeFree affiliate add/update
# ----------------------------------------------------------------------------
#
proc go_befree_affprog args {

	global DB DATA

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set source_id [reqGetArg source_id]

	foreach {n v} $args {
		set $n $v
	}

	#Populate the program dropdown
	get_befree_programs

	#Populate the affiliate dropdown
	get_affiliates

	tpBindString source_id $source_id

	if {$source_id == ""} {

		tpSetVar opAdd 1

		if {[reqGetArg specify_id]=="Y"} {
			tpBindString specify_id "checked"
			tpBindString new_id [reqGetArg new_id]
		} else {
			tpBindString use_next_id "checked"
			tpBindString new_id ""
		}

		tpBindString reg_aff   "CHECKED"
		tpBindString bet_aff   "CHECKED"

	} else {

		tpSetVar opAdd 0

		#
		# Get aff information
		#
		set sql {
			select
			a.aff_id,
			a.prog_id,
			a.bf_id,
			a.source_id,
			a.reg_aff,
			a.bet_aff,
			a.status
		from
			tAffProgram a
		where
			a.source_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $source_id]
		inf_close_stmt $stmt

		tpSetVar     prog_id   [db_get_col $res 0 prog_id]
		tpSetVar     aff_id    [db_get_col $res 0 aff_id]
		tpBindString aff_id    [db_get_col $res 0 aff_id]
		tpBindString prog_id   [db_get_col $res 0 prog_id]
		tpBindString bf_id     [db_get_col $res 0 bf_id]
		tpBindString source_id [db_get_col $res 0 source_id]
		tpBindString reg_aff   [expr {[db_get_col $res 0 reg_aff] == "Y" ? "CHECKED" : ""}]
		tpBindString bet_aff   [expr {[db_get_col $res 0 bet_aff] == "Y" ? "CHECKED" : ""}]
		tpBindString status    [db_get_col $res 0 status]

		db_close $res
	}

	asPlayFile -nocache befree_aff.html
}

#
# ----------------------------------------------------------------------------
# Do BeFree Affiliate Program insert/update
# ----------------------------------------------------------------------------
#
proc do_befree_affprog args {

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_aff_list
		return
	}

	if {$act == "AffAdd"} {
		do_befree_aff_add
	} elseif {$act == "AffMod"} {
		do_befree_aff_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_befree_aff_add args {

	global DB USERNAME DATA DATA_P

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	#Populate the program data
	get_befree_programs

	# get the befree program id
	set getBfProgSql "
		select
			ext_prog_id
		from
			tProgram
		where
			prog_id = [reqGetArg prog_id]
	"

	set getBfProgStmt [inf_prep_sql $DB $getBfProgSql]
	set getBfProgRes  [inf_exec_stmt $getBfProgStmt]
	inf_close_stmt $getBfProgStmt

	set bfmid [db_get_col $getBfProgRes 0 ext_prog_id]

	db_close $getBfProgRes

	if {[catch {set http_response [http::geturl "[OT_CfgGet BEFREE_SOURCE_ID_URL]?bfmid=$bfmid&siteid=[reqGetArg bf_id]&bfpage=bf_advanced&bfurl=http%3A%2F%2Fwww%2Eladbrokes%2Ecom&bfcookietest=N"]} msg]} {
		ob::log::write ERROR "Failed to retrieve response from BeFree server: $msg"
		err_bind $msg
	}

	# check that the response is valid
	# The usual response is that The Page Has Moved	so comment out this check. Might change in future.

	#set result [validate_response $http_response]
	#if {[lindex $result 0]>0} {
	#	ob::log::write ERROR "Bad response from BeFree server: [lindex $result 1]"
	#	err_bind [lindex $result 1]
	#}

	ob::log::write INFO "Got URL response: [http::data $http_response]"

	regexp {sourceid=([^&]+)&} [http::data $http_response] unused source_id

	ob::log::write INFO "Adding new BeFree affiliate. source_id = $source_id"

	# Garbage collect request
	http::cleanup $http_response

	# Set reg/bet criteria from checkbox to N if unticked

	if {[reqGetArg reg_aff] != "Y"} {
		reqSetArg reg_aff "N"
	}
	if {[reqGetArg bet_aff] != "Y"} {
		reqSetArg bet_aff "N"
	}

	set sql {
		execute procedure pInsBeFreeAffProg(
			p_adminuser =?,
			p_aff_id =?,
			p_prog_id =?,
			p_bf_id =?,
			p_source_id =?,
			p_reg_aff =?,
			p_bet_aff =?,
			p_status =?
		)
	}


	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg aff_id]\
			[reqGetArg prog_id]\
			[reqGetArg bf_id]\
			$source_id\
			[reqGetArg reg_aff]\
			[reqGetArg bet_aff]\
			[reqGetArg status]]} msg]} {
		err_bind "$msg :<br> Check this combination of aff_ids and prog_ids are not already used"
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_befree_affprog
		return
	}

	go_befree_affprog

}

proc do_befree_aff_upd args {

	global DB USERNAME

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set sql {
		execute procedure pUpdBeFreeAffProg(
			p_adminuser =?,
			p_aff_id  =?,
			p_prog_id =?,
			p_bf_id =?,
			p_source_id =?,
			p_reg_aff =?,
			p_bet_aff =?,
			p_status =?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	# Set reg/bet criteria from checkbox to N if unticked

	if {[reqGetArg reg_aff] != "Y"} {
		reqSetArg reg_aff "N"
	}
	if {[reqGetArg bet_aff] != "Y"} {
		reqSetArg bet_aff "N"
	}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg aff_id]\
			[reqGetArg prog_id]\
			[reqGetArg bf_id]\
			[reqGetArg source_id]\
			[reqGetArg reg_aff]\
			[reqGetArg bet_aff]\
			[reqGetArg status]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_befree_affprog
		return
	}

	go_aff_list
}



#
# ----------------------------------------------------------------------------
# Go to BeFree program add/update
# ----------------------------------------------------------------------------
#
proc go_befree_program args {

	global DB DATA

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set prog_id [reqGetArg prog_id]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString prog_id $prog_id

	if {$prog_id == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get aff information
		#
		set sql {
			select
				p.prog_id,
				p.prog_name,
				p.file_name,
				p.status,
				p.ext_prog_id
			from
				tProgram p
			where
				p.prog_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $prog_id]
		inf_close_stmt $stmt

		tpSetVar     prog_id     [db_get_col $res 0 prog_id]
		tpBindString prog_id     [db_get_col $res 0 prog_id]
		tpBindString prog_name   [db_get_col $res 0 prog_name]
		tpBindString file_name   [db_get_col $res 0 file_name]
		tpBindString status      [db_get_col $res 0 status]
		tpBindString ext_prog_id [db_get_col $res 0 ext_prog_id]

		db_close $res
	}

	asPlayFile -nocache befree_prog.html
}

#
# ----------------------------------------------------------------------------
# Do BeFree Program insert/update
# ----------------------------------------------------------------------------
#
proc do_befree_program args {

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_aff_list
		return
	}

	if {$act == "AffAdd"} {
		do_befree_prog_add
	} elseif {$act == "AffMod"} {
		do_befree_prog_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_befree_prog_add args {

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	global DB USERNAME

	ob::log::write INFO "About to add BeFree Program"

	set sql {
		execute procedure pInsBeFreeProg(
			p_adminuser =?,
			p_prog_id =?,
			p_prog_name =?,
			p_file_name =?,
			p_status =?,
			p_ext_prog_id =?
		)
	}


	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			0\
			[reqGetArg prog_name]\
			[reqGetArg file_name]\
			[reqGetArg status]\
			[reqGetArg ext_prog_id]]} msg]} {
		err_bind "$msg :<br> Check this prog_id is not in use"
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_befree_program
		return
	}

	go_befree_program

}

proc do_befree_prog_upd args {

	global DB USERNAME

	if {![OT_CfgGet FUNC_BEFREE_AFF_PROGRAM 1]} {
		return
	}

	set sql {
		execute procedure pUpdBeFreeProg(
			p_adminuser =?,
			p_prog_id =?,
			p_prog_name =?,
			p_file_name =?,
			p_status =?,
			p_ext_prog_id =?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg prog_id_old]\
			[reqGetArg prog_name]\
			[reqGetArg file_name]\
			[reqGetArg status]\
			[reqGetArg ext_prog_id]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_befree_program
		return
	}

	go_aff_list
}


#
# ----------------------------------------------------------------------------
# Go to affiliate list
# ----------------------------------------------------------------------------
#
proc go_aff_list args {

	global DATA DB AUDATA ADATA

	set useFreeBets  [OT_CfgGet USE_FREE_BETS 0]
	tpSetVar useFreeBets $useFreeBets

	# Retrieve affiliate and affiliate group data
	get_affiliates 1
	get_affiliate_groups

	# Get BeFree affiliate programs and aff progs
	get_befree_aff_progs
	get_befree_programs

	# Get all Affiliates United promo codes
	set au_sql {
		select
			p.promo_code,
			a.advertiser,
			p.desc
		from
			tAUPromo p,
			tAUAdvertiser a
		where
			a.adv_id = p.adv_id
	}

	set au_stmt [inf_prep_sql $DB $au_sql]

	if {[catch {
		set au_rs [inf_exec_stmt $au_stmt]
	} msg]} {
		err_bind $msg
	}

	## Bind up data
	tpSetVar au_rows [set nrows [db_get_nrows $au_rs]]
	set AUDATA(advertisers) [list]

	for {set i 0} {$i < $nrows} {incr i} {
		set AUDATA($i,promo_code) [db_get_col $au_rs $i promo_code]
		set AUDATA($i,advertiser) [db_get_col $au_rs $i advertiser]
		lappend AUDATA(advertisers) $AUDATA($i,advertiser)
		set AUDATA($i,desc)       [db_get_col $au_rs $i desc]
	}

	catch {db_close $au_rs}
	inf_close_stmt $au_stmt

	tpBindVar AU_PromoCode  AUDATA promo_code au_idx
	tpBindVar AU_Advertiser AUDATA advertiser au_idx
	tpBindVar AU_Desc       AUDATA desc       au_idx

	# Get all Advertiser Codes

	set a_sql {
		select
			advertiser,
			desc
		from
			tAUAdvertiser
	}

	set a_stmt [inf_prep_sql $DB $a_sql]

	if {[catch {
		set a_rs [inf_exec_stmt $a_stmt]
	} msg]} {
		err_bind $msg
	}

	## Bind up data
	tpSetVar a_rows [set nrows [db_get_nrows $a_rs]]

	for {set i 0} {$i < $nrows} {incr i} {
		set ADATA($i,advertiser) [db_get_col $a_rs $i advertiser]
		set ADATA($i,desc)       [db_get_col $a_rs $i desc]

		## Find out if this advertiser code has a promo code attached to it
		if {[lsearch $AUDATA(advertisers) $ADATA($i,advertiser)] != -1} {
			set ADATA($i,has_promo) 1		
		} else {
			set ADATA($i,has_promo) 0
		}
	}
	catch {db_close $a_rs}
	inf_close_stmt $a_stmt

	tpBindVar A_Advertiser ADATA advertiser a_idx
	tpBindVar A_Desc       ADATA desc       a_idx	
	tpBindVar A_HasPromo   ADATA has_promo  a_idx	

	asPlayFile -nocache aff_list.html

	catch {unset DATA}
}


#
# ----------------------------------------------------------------------------
# Go to affiliate add/update
# ----------------------------------------------------------------------------
#
proc go_aff args {

	global DB DATA

	set aff_id [reqGetArg AffId]

	set useFreeBets  [OT_CfgGet USE_FREE_BETS 0]
	tpSetVar useFreeBets $useFreeBets

	foreach {n v} $args {
		set $n $v
	}

	#Populate the group data
	get_affiliate_groups

	tpBindString AffId $aff_id

	if {$aff_id == ""} {

		tpSetVar opAdd 1

		if {[reqGetArg specify_id]=="Y"} {
			tpBindString specify_id "checked"
			tpBindString new_id [reqGetArg new_id]
		} else {
			tpBindString use_next_id "checked"
			tpBindString new_id ""
		}


		make_channel_binds "" "-" 1

		tpBindString AffImage "common/bs_logo.gif"
	} else {

		tpSetVar opAdd 0

		#
		# Get aff information
		#
		set sql {
			select
				aff_grp_id,
				aff_name,
				status,
				free_bet,
				channels,
				image,
				url
			from
				tAffiliate
			where
				aff_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $aff_id]
		inf_close_stmt $stmt

		tpSetVar AffGrpId  [db_get_col $res 0 aff_grp_id]
		tpBindString AffName   [db_get_col $res 0 aff_name]
		tpBindString AffStatus [db_get_col $res 0 status]
		tpBindString AffFreeBet [db_get_col $res 0 free_bet]
		tpBindString AffImage   [db_get_col $res 0 image]
		tpBindString AffURL   [db_get_col $res 0 url]

		make_channel_binds [db_get_col $res 0 channels] "-" 0

		db_close $res
	}

	asPlayFile -nocache aff.html
}

#
# ----------------------------------------------------------------------------
# Go to affiliate group add/update
# ----------------------------------------------------------------------------
#
proc go_aff_grp args {

	global DB DATA

	set aff_grp_id [reqGetArg AffGrpId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString AffGrpId $aff_grp_id

	if {$aff_grp_id == ""} {

		tpSetVar opAdd 1

		if {[reqGetArg specify_id]=="Y"} {
			tpBindString specify_id "checked"
			tpBindString new_id [reqGetArg new_id]
		} else {
			tpBindString use_next_id "checked"
			tpBindString new_id ""
		}

	} else {

		tpSetVar opAdd 0

		#
		# Get aff grp information
		#
		set sql {
			select
				aff_grp_name,
				status
			from
				tAffiliateGrp
			where
				aff_grp_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $aff_grp_id]
		inf_close_stmt $stmt

		tpBindString AffGrpName   [db_get_col $res 0 aff_grp_name]
		tpBindString AffGrpStatus [db_get_col $res 0 status]
		db_close $res
	}

	asPlayFile -nocache aff_grp.html
}

proc go_upload_aff_list args {
	tpBindString upload_type {AFF}
		tpBindString UPLOAD_URL [OT_CfgGet UPLOAD_URL]
	asPlayFile -nocache upload/aff_upload.html
}

#
# ----------------------------------------------------------------------------
# Do affiliate insert/update
# ----------------------------------------------------------------------------
#
proc do_aff args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_aff_list
		return
	}

	if {$act == "AffAdd"} {
		do_aff_add
	} elseif {$act == "AffMod"} {
		do_aff_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_aff_add args {

	global DB USERNAME

	set sql {
		execute procedure pInsAff(
			p_adminuser  = ?,
			p_aff_grp_id = ?,
			p_aff_name   = ?,
			p_status     = ?,
			p_channels   = ?,
			p_free_bet   = ?,
			p_aff_id     = ?,
			p_image      = ?,
			p_url        = ?
		)
	}


	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[reqGetArg specify_id]=="Y"} {
		set new_id [reqGetArg new_id]
	} else {
		set new_id ""
	}

	if {[reqGetArg AffGrpId] == 0} {reqSetArg AffGrpId ""}

	# If user does not provide an image use the default image
	if {[reqGetArg AffImage] == ""} {reqSetArg AffImage "common/bs_logo.gif"}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AffGrpId]\
			[reqGetArg AffName]\
			[reqGetArg AffStatus]\
			[make_channel_str]\
			[reqGetArg AffFreeBet]\
			$new_id\
			[reqGetArg AffImage]\
			[reqGetArg AffURL]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_aff
		return
	}

	set sql {
		select aff_id
		from   tAffiliate
		where  aff_name = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt [reqGetArg AffName]]
	set aff_id [db_get_col $res 0 aff_id]
	reqSetArg AffId $aff_id

	set group "Affiliates"
	set blurb_code AFF_BLURB_$aff_id
	set header_code AFF_HEADER_$aff_id

	ADMIN::MSG::add_code $blurb_code $group 0
	ADMIN::MSG::add_code $header_code $group 0

	if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
		go_aff
	} else {
		go_aff_list
	}
}

proc do_aff_upd args {

	global DB USERNAME

	set sql {
		execute procedure pUpdAff(
			p_adminuser = ?,
			p_aff_id = ?,
			p_aff_grp_id = ?,
			p_aff_name = ?,
			p_status = ?,
			p_free_bet = ?,
			p_channels = ?,
			p_image    = ?,
			p_url      = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	#Catch the No Group selection and pass in null
	set grp_id [reqGetArg AffGrpId]
	if {$grp_id == 0} {set grp_id ""}

	# If user does not provide an image use the default image
	if {[reqGetArg AffImage] == ""} {reqSetArg AffImage "common/bs_logo.gif"}

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AffId]\
			$grp_id\
			[reqGetArg AffName]\
			[reqGetArg AffStatus]\
			[reqGetArg AffFreeBet]\
			[make_channel_str]\
			[reqGetArg AffImage]\
			[reqGetArg AffURL]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_aff
		return
	}

	go_aff_list
}

#
# ----------------------------------------------------------------------------
# Do affiliate group insert/update
# ----------------------------------------------------------------------------
#
proc do_aff_grp args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_aff_list
		return
	}

	if {$act == "AffGrpAdd"} {
		do_aff_grp_add
	} elseif {$act == "AffGrpMod"} {
		do_aff_grp_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_aff_grp_add args {

	global DB USERNAME

	set sql {
		execute procedure pInsAffGrp(
			p_adminuser    = ?,
			p_aff_grp_name = ?,
			p_status       = ?,
			p_aff_grp_id   = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[reqGetArg specify_id]=="Y"} {
		set new_id [reqGetArg new_id]
	} else {
		set new_id ""
	}

	#Call stored procedure
	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AffGrpName]\
			[reqGetArg AffGrpStatus]\
			$new_id]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_aff_grp
		return
	}

	go_aff_list
}

proc do_aff_grp_upd args {

	global DB USERNAME

	set sql {
		execute procedure pUpdAffGrp(
			p_adminuser = ?,
			p_aff_grp_id = ?,
			p_aff_grp_name = ?,
			p_status = ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AffGrpId]\
			[reqGetArg AffGrpName]\
			[reqGetArg AffGrpStatus]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_aff_grp
		return
	}

	go_aff_list
}

#
# Add an Affiliates United Promo Code
#
proc add_aff_utd_code args {

	global DB USERNAME

	set promo_code [ob_chk::get_arg promoCode -on_err 0 {ALNUM}]
	set adv_code   [ob_chk::get_arg advCode -on_err 0 {ALNUM}]
	set desc       [reqGetArg descCode]
	set override   [ob_chk::get_arg override -on_err "N" {EXACT -args {Y}}]

	if {$promo_code == 0 || [string length $promo_code] > 16} {
		err_bind "Invalid Promo Code"
		go_aff_list
		return
	}

	if {$adv_code == 0 || [string length $adv_code] > 100} {
		err_bind "Invalid Advertiser Code"
		go_aff_list
		return
	}

	if {[string length $desc] > 255} {
		set desc [string index $desc 254]
	}

	## check that the advertiser code exists and throw an error if not
	set check_sql {
		select
			adv_id,
			advertiser
		from
			tAUAdvertiser
		where
			advertiser = ?
	}

	set check_stmt [inf_prep_sql $DB $check_sql]

	if {[catch {
		set check_rs [inf_exec_stmt $check_stmt $adv_code]
		set advertiser_exists [db_get_nrows $check_rs]
	} msg]} {
		err_bind $msg
		ob_log::write ERROR {add_aff_utd_code: $msg}
		inf_close_stmt $check_stmt
		go_aff_list
		return
	}

	if {$advertiser_exists} {
		set adv_id [db_get_col $check_rs 0 adv_id]
	}

	catch {db_close $check_rs}
	inf_close_stmt $check_stmt

	if {!$advertiser_exists} {
		err_bind "Advertiser Code $adv_code doesn't exist."
		go_aff_list
		return
	}

	## advertiser exists so continue inserting promo code
	set sql {
		insert into tAUPromo 
			(promo_code, override, adv_id, desc)
		values
			(?, ?, ?, ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		ob_log::write INFO {Inserting into tAUPromo args $promo_code, $override, \
							$adv_code, $desc}
		set rs [inf_exec_stmt $stmt $promo_code $override $adv_id $desc]
	} msg]} {
		err_bind $msg
		ob_log::write ERROR {add_aff_utd_code: $msg}
	} else {
		msg_bind "Successfully added promo code $promo_code"
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

	go_aff_list

}

#
# Delete an Affiliates United Promo Code
#
proc del_aff_utd_code args {

	global DB

	if {![op_allowed DelAffCodes]} {
		err_bind "You do not have permission to delete promo codes"
		return 0
	}

	set codes [reqGetArg deletes]

	set promoCodes [split $codes]

	set errs ""

	foreach promo_code $promoCodes {

		set sql {
			delete from
				tAUPromo
			where
				promo_code = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			ob_chk::get_arg adv_code -value -on_err -1 {ALNUM}
			
			if {$promo_code  != -1} {
				set rs [inf_exec_stmt $stmt $promo_code]
				catch {db_close $rs}
				inf_close_stmt $stmt
			}
		} msg]} {
			append errs "Failed to delete promo code: $promo_code<br/>"
			ob_log::write ERROR {del_aff_utd_code: $msg}
		}
	}

	if {$errs != ""} {
		err_bind $errs
	} else {
		msg_bind "Successfully deleted promo codes"
	}

	go_aff_list

}

#
# Add an Affiliates United Advertiser Code
#
proc add_advertiser_code args {
	global DB USERNAME

	set adv_code   [ob_chk::get_arg advCode -on_err 0 {ALNUM}]
	set desc       [reqGetArg descCode]

	if {$adv_code == 0 || [string length $adv_code] > 100} {
		err_bind "Invalid Advertiser Code"
		go_aff_list
		return
	}

	if {[string length $desc] > 255} {
		set desc [string index $desc 254]
	}

	## check that the advertiser code doesn't exist and throw an error if it does
	set check_sql {
		select
			advertiser
		from
			tAUAdvertiser
		where
			advertiser = ?
	}

	set check_stmt [inf_prep_sql $DB $check_sql]

	if {[catch {
		set check_rs [inf_exec_stmt $check_stmt $adv_code]
		set advertiser_exists [db_get_nrows $check_rs]
	} msg]} {
		err_bind $msg
		ob_log::write ERROR {add_aff_utd_code: $msg}
		inf_close_stmt $check_stmt
		go_aff_list
		return
	}

	catch {db_close $check_rs}
	inf_close_stmt $check_stmt

	if {$advertiser_exists} {
		err_bind "Advertiser Code $adv_code already exists."
		go_aff_list
		return
	}

	## advertiser code doesn't exist so continue to add it.
	set sql {
		insert into tAUAdvertiser
			(advertiser, desc)
		values
			(?, ?)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		ob_log::write INFO {Inserting into tAUAdvertiser args $adv_code, $desc}
		set rs [inf_exec_stmt $stmt $adv_code $desc]
	} msg]} {
		err_bind $msg
		ob_log::write ERROR {add_advertiser_code: $msg}
	} else {
		msg_bind "Successfully added advertiser $adv_code"
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

	go_aff_list
}

#
# Add an Affiliates United Advertiser Code
#
proc del_advertiser_code args {

	global DB

	if {![op_allowed DelAffCodes]} {
		err_bind "You do not have permission to delete advertiser codes"
		return 0
	}

	set codes [reqGetArg deletes]

	set advCodes [split $codes]

	set errs ""

	foreach adv_code $advCodes {

		set sql {
			delete from
				tAUAdvertiser
			where
				advertiser = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			ob_chk::get_arg adv_code -value -on_err -1 {ALNUM}

			if {$adv_code  != -1} {
				set rs [inf_exec_stmt $stmt $adv_code]
				catch {db_close $rs}
				inf_close_stmt $stmt
			}
		} msg]} {
			append errs "Failed to delete advertiser: $adv_code<br/>"
			ob_log::write ERROR {del_advertiser_code: $msg}
		}
	}

	if {$errs != ""} {
		err_bind $errs
	} else {
		msg_bind "Successfully deleted advertisers"
	}

	go_aff_list

}

#
# Display the find advertiser code popup
#
proc do_adv_popup args {
	asPlayFile aff_adv_find.html
}

#
# Search for advertiser codes.
#
proc do_adv_popup_search args {

	global DB ADVDATA

	set adv_code [ob_chk::get_arg advCode -on_err -1 {ALNUM}]

	if {$adv_code == -1 || [string length $adv_code] > 100} {
		err_bind "Please enter the start of an advertiser code"
		asPlayFile aff_adv_find.html
		return
	}

	tpBindString SearchString $adv_code

	set adv_code $adv_code%

	set sql {
		select
			advertiser
		from
			tauadvertiser
		where
			advertiser like ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt $adv_code]
	} msg]} {
		err_bind $msg
		ob_log::write ERROR {do_adv_popup_search: $msg}
	}

	## Bind up data
	tpSetVar Results 1
	tpSetVar adv_nrows [set nrows [db_get_nrows $rs]]

	for {set i 0} {$i < $nrows} {incr i} {
		set ADVDATA($i,advertiser) [db_get_col $rs $i advertiser]
	}

	catch {db_close $rs}
	inf_close_stmt $stmt

	tpBindVar Advertiser ADVDATA advertiser adv_idx

	asPlayFile aff_adv_find.html
}

}
