# ==============================================================
# $Id: cust_prefs.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUST_PREFS {

asSetAct ADMIN::CUST_PREFS::GoCustPrefList  [namespace code go_cust_pref_list]
asSetAct ADMIN::CUST_PREFS::GoCustPref      [namespace code go_cust_pref]
asSetAct ADMIN::CUST_PREFS::DoCustPref      [namespace code do_cust_pref]


#
# Display a list of the currently set prefs for a customer
#
proc go_cust_pref_list args {

	global DB
	global CUST_PREFS

	set cust_id [reqGetArg CustId]

	# get all the customer prefs
	set sql "select
				pref_name,
				pref_cvalue,
				pref_ivalue,
				pref_pos
			from
				tCustomerPref
			where
				cust_id = $cust_id"
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {

		set CUST_PREFS($i,name)   [db_get_col $rs $i pref_name]
		set CUST_PREFS($i,cvalue) [db_get_col $rs $i pref_cvalue]
		set CUST_PREFS($i,ivalue) [db_get_col $rs $i pref_ivalue]
		set CUST_PREFS($i,pos)    [db_get_col $rs $i pref_pos]
	}

	tpSetVar num_prefs $nrows
	tpBindString CustId $cust_id

	tpBindVar pref_name   CUST_PREFS name   p_idx
	tpBindVar pref_cvalue CUST_PREFS cvalue p_idx
	tpBindVar pref_ivalue CUST_PREFS ivalue p_idx
	tpBindVar pref_pos    CUST_PREFS pos    p_idx

	asPlayFile -nocache cust_pref_list.html
	
}



#
# Display information about a single customer preference
#
proc go_cust_pref args {

	global DB
	global CUST_PREFS

	catch {unset CUST_PREFS}

	set edit_type [reqGetArg type]
	set cust_id   [reqGetArg CustId]
	tpBindString  CustId $cust_id

	if {$edit_type eq "Update"} {
		# Not adding a new preference - get the details from the db

		set pref_name [reqGetArg pref_name]

		set sql "select
					pref_name,
					pref_cvalue,
					pref_ivalue,
					pref_pos
				from
					tCustomerPref
				where
					cust_id   = $cust_id
				and pref_name = '$pref_name'"

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $rs]

		# There should be 1 and only 1 row returned
		if {$nrows != 1} {
		
		}

		tpBindString pref_name   $pref_name
		tpBindString pref_cvalue [db_get_col $rs 0 pref_cvalue]
		tpBindString pref_ivalue [db_get_col $rs 0 pref_ivalue]
		tpBindString pref_pos    [db_get_col $rs 0 pref_pos]

		tpSetVar type $edit_type
	}

	# get all possible prefs not already set
	set sql "select
				pref_name
			from
				tCustomerPrefTypes t
			where
				not exists (
					select
						pref_name
					from
						tCustomerPref c
					where
						cust_id = $cust_id
					and c.pref_name = t.pref_name)"

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i 1} {

		set CUST_PREFS($i,name) [db_get_col $rs $i pref_name]
	}

	# bind up and play
	tpSetVar num_prefs $nrows
	tpBindVar pref_name_list CUST_PREFS name p_idx

	tpBindString type $edit_type

	asPlayFile -nocache cust_pref.html

}



#
# Insert/Update/Delete a customer preference or go Back
#
proc do_cust_pref args {

	set submit_name [reqGetArg SubmitName]
	set cust_id     [reqGetArg CustId]

	switch -exact -- $submit_name {
		Add {
			_do_add_cust_pref
		}
		Update {
			_do_update_cust_pref
		}
		Back {
			#ADMIN::CUST::go_cust cust_id $cust_id
			go_cust_pref_list
		}
		Delete {
			_do_delete_cust_pref
		}
		default {
			OT_LogWrite 2 "CUST_PREFS: Invalid SubmitName in do_cust_group_pref."
			go_cust_group_product
		}
	}
	
}



#
# Add a new customer preference.
#
proc _do_add_cust_pref args {

	global DB

	# get values
	set cust_id     [reqGetArg CustId]
	set pref_name   [reqGetArg pref_name]
	set pref_cvalue [reqGetArg pref_cvalue]
	set pref_ivalue [reqGetArg pref_ivalue]
	set pref_pos    [reqGetArg pref_pos]

	set sql_val_cols   ""
	set sql_val_values ""

	# Check to see if either cvalue or ivalue is blank
	if {$pref_ivalue ne "" && $pref_cvalue ne ""} {
		# error
		err_bind "You cannot set both cvalue and ivalue"
		go_cust_pref
		return
	} elseif {$pref_cvalue ne ""} {
		set sql_val_cols   "pref_cvalue,"
		set sql_val_values "'$pref_cvalue',"
	} elseif {$pref_ivalue ne ""} {
		set sql_val_cols   "pref_ivalue,"
		set sql_val_values "$pref_ivalue,"
	} else {
		# error
		err_bind "You must select either a cvalue or ivalue"
		go_cust_pref
		return
	}

	# Check for blank pref_pos - if so, set it to 0
	if {$pref_pos eq ""} {
		set pref_pos 0
	}

	# add to database
	set sql "insert into tCustomerPref (
					cust_id,
					pref_name,
					$sql_val_cols
					pref_pos
			) values (
					$cust_id,
					'$pref_name',
					$sql_val_values
					$pref_pos
			)";

	set stmt [inf_prep_sql $DB $sql]
	
	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 1 "CUST_PREFS: Error inserting cust pref -> cust_id=$cust_id, pref_name=$pref_name: $msg"
		err_bind "Error inserting customer preference: $msg"
		go_cust_pref
		return
	}

	# display cust pref list if no errors
	go_cust_pref_list
}



#
# Update a customer preference
#
proc _do_update_cust_pref args {

	global DB

	# get values
	set cust_id     [reqGetArg CustId]
	set pref_name   [reqGetArg pref_name]
	set pref_cvalue [reqGetArg pref_cvalue]
	set pref_ivalue [reqGetArg pref_ivalue]
	set pref_pos    [reqGetArg pref_pos]

	# check for blanks in fields
	if {$pref_cvalue ne "" && $pref_ivalue ne ""} {
		err_bind "You cannot set both cvalue and ivalue"
		go_cust_pref
		return
	}

	if {$pref_cvalue eq "" && $pref_ivalue eq ""} {
		err_bind "One of cvalue and ivalue must have a value"
		go_cust_pref
		return
	}

	if {$pref_cvalue eq ""} {
		set pref_cvalue "null"
	} else {
		set pref_cvalue "'$pref_cvalue'"
	}

	if {$pref_ivalue eq ""} {
		set pref_ivalue "null"
	}

	if {$pref_pos eq ""} {
		set pref_pos 0
	}

	# update values
	set sql "update
				tCustomerPref
			set
				pref_cvalue = $pref_cvalue,
				pref_ivalue = $pref_ivalue,
				pref_pos    = $pref_pos
			where
				cust_id     = $cust_id
			and pref_name   = '$pref_name'"
	
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 1 "CUST_PREFS: Error Updating cust pref -> cust_id=$cust_id, pref_name=$pref_name: $msg"
		err_bind "Error updating customer preference: $msg"
		go_cust_pref
		return
	}

	# display cust pref list if no errors
	go_cust_pref_list
}



#
# Delete a customer preference
#
proc _do_delete_cust_pref args {

	global DB

	# get values
	set cust_id   [reqGetArg CustId]
	set pref_name [reqGetArg pref_name]

	# create query
	set sql "delete
			from
				tCustomerPref
			where
				cust_id   = $cust_id
			and pref_name = '$pref_name'"

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 1 "CUST_PREFS: Error deleting cust pref -> cust_id=$cust_id, pref_name=$pref_name: $msg"
		err_bind "Error deleting customer preference: $msg"
		go_cust_pref
		return
	}

	# display cust pref list if no errors
	go_cust_pref_list
}

}
