# ==============================================================
# $Id: login_triggers.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# Allow control of Login Actions
# NOTE: CURRENTLY ONLY ONE ACTION IS SET UP - THIS ACTION IS HARDCODED
# IN MOST CASES WHEN DOING INSERTS/UPDATES
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::LOGINTRIGGERS {

	asSetAct ADMIN::LOGINTRIGGERS::GoLoginTriggerUpdateDetails  [namespace code go_login_trigger_update_details]

	asSetAct ADMIN::LOGINTRIGGERS::DoLoginTriggerUpdateOptions  [namespace code do_login_trigger_update_options]
	asSetAct ADMIN::LOGINTRIGGERS::DoLoginTriggerUpload         [namespace code do_login_trigger_upload]
	asSetAct ADMIN::LOGINTRIGGERS::DoLoginTriggerGrp            [namespace code do_login_trigger_grp]
	asSetAct ADMIN::LOGINTRIGGERS::DoLoginTriggerFlag           [namespace code do_login_trigger_flag]
	asSetAct ADMIN::LOGINTRIGGERS::DoLoginTriggerIntervalUpdate [namespace code do_login_trigger_interval_update]

	asSetAct ADMIN::LOGINTRIGGERS::GoViewActiveUploadList       [namespace code do_view_active_upload_list]
	asSetAct ADMIN::LOGINTRIGGERS::DoActiveUploadDelete         [namespace code do_active_upload_delete]

}


#
# Build and show the update page for Login Triggers - Update Details
#
proc ADMIN::LOGINTRIGGERS::go_login_trigger_update_details {} {

	global DB GRPS AVAIL_GRPS FLAGS AVAIL_FLAGS

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to view this page"
		asPlayFile -nocache main_area.html
		return
	}

	# The action code we are using
	set action_code "UPDATE_DETAILS"

	# Get and bind action code info
	set sql {
		select
			action_id,
			action_code,
			desc,
			max_reminders,
			max_reminders_days,
			skip_elite
		from
			tLoginActCode
		where
			action_code = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_code]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {
		tpBindString action_id              [db_get_col $rs 0 action_id]
		tpBindString action_code            [db_get_col $rs 0 action_code]
		tpBindString action_code_desc       [db_get_col $rs 0 desc]
		tpBindString action_code_max_r      [db_get_col $rs 0 max_reminders]
		tpBindString action_code_max_r_days [db_get_col $rs 0 max_reminders_days]
		tpBindString action_code_skip_elite [db_get_col $rs 0 skip_elite]

		# set the action id for future use
		set action_id [db_get_col $rs 0 action_id]
	}

	db_close $rs


	# Get and bind total active upload count
	set sql {
		select
			count (unique cust_id) as total_active_uploads
		from
			tLoginActCust ac
		where
			ac.action_id = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {
		tpBindString total_active_uploads [db_get_col $rs 0 total_active_uploads]
	}

	db_close $rs


	# Get and bind all set groups
	set sql {
		select
			ag.cust_code    as grp_code,
			cc.desc         as grp_desc,
			ag.status       as grp_status,
			ag.last_updated as grp_last_updated
		from
			tLoginActGrp ag,
			tCustCode cc
		where
			ag.cust_code = cc.cust_code and
			ag.action_id = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set GRPS($i,$c) [db_get_col $rs $i $c]
		}
	}

	tpBindString num_grps $nrows
	ob_log::write_array DEV GRPS

	foreach c [db_get_colnames $rs] {
		tpBindVar $c GRPS $c grp_idx
	}

	db_close $rs


	# Get and bind all available groups
	set sql {
		select
			cust_code as avail_grp_code,
			desc      as avail_grp_desc
		from
			tCustCode
		where
			cust_code not in (  select
								cust_code
							from
								tLoginActGrp
							where
								action_id = ?);
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set AVAIL_GRPS($i,$c) [db_get_col $rs $i $c]
		}
	}

	tpBindString num_avail_grps $nrows
	ob_log::write_array DEV AVAIL_GRPS

	foreach c [db_get_colnames $rs] {
		tpBindVar $c AVAIL_GRPS $c avail_grp_idx
	}

	db_close $rs


	# Get and bind all set flags
	set sql {
		select
			af.status_flag_tag  as flag_tag,
			sf.status_flag_name as flag_name,
			af.status           as flag_status,
			af.once_only        as flag_once_only
		from
			tLoginActflag af,
			tStatusFlag sf
		where
			af.status_flag_tag = sf.status_flag_tag and
			af.action_id = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set FLAGS($i,$c) [db_get_col $rs $i $c]
		}
	}

	tpBindString num_flags $nrows
	ob_log::write_array DEV FLAGS

	foreach c [db_get_colnames $rs] {
		tpBindVar $c FLAGS $c flag_idx
	}

	db_close $rs


	# Get and bind all available flags
	set sql {
		select
			status_flag_tag  as avail_flag_tag,
			status_flag_name as avail_flag_name
		from
			tStatusFlag
		where
			status_flag_tag not in ( select
									status_flag_tag
								from
									tLoginActFlag
								where
									action_id = ?);
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set AVAIL_FLAGS($i,$c) [db_get_col $rs $i $c]
		}
	}

	tpBindString num_avail_flags $nrows
	ob_log::write_array DEV AVAIL_FLAGS

	foreach c [db_get_colnames $rs] {
		tpBindVar $c AVAIL_FLAGS $c avail_flag_idx
	}

	db_close $rs


	# Get and bind interval settings
	set sql {
		select
			action_id,
			days
		from
			tLoginActInt
		where
			action_id = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
 	set rs   [inf_exec_stmt $stmt $action_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {
		# decide which input field to use - using 999 as default incase something goes wrong
		switch [db_get_col $rs 0 days] {
			"90"  -
			"180" -
			"270" {
				tpBindString action_code_interval     [db_get_col $rs 0 days]
				tpBindString action_code_interval_alt ""
			}
			default {
				tpBindString action_code_interval     999
				tpBindString action_code_interval_alt [db_get_col $rs 0 days]
			}
		}
	}

	db_close $rs
	

	asPlayFile -nocache login_trigger_update_details.html

}


#
# Update the Options
#
proc ADMIN::LOGINTRIGGERS::do_login_trigger_update_options {} {

	global DB

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to perform this action"
		asPlayFile -nocache main_area.html
		return
	}

	set action_id                  [reqGetArg action_id]
	set action_code_desc           [reqGetArg action_code_desc]
	set action_code_reminders      [reqGetArg action_code_max_r]
	set action_code_reminders_days [reqGetArg action_code_max_r_days]
	set action_code_skip_elite     [reqGetArg action_code_skip_elite]

	if {$action_code_desc == ""} {
		err_bind "Error: the description field cannot be blank"
		go_login_trigger_update_details
		return
	}

	if {$action_code_reminders == ""} {
		err_bind "Error: the max reminders field cannot be blank"
		go_login_trigger_update_details
		return
	}

	if {$action_code_reminders_days == ""} {
		err_bind "Error: the interval field cannot be blank"
		go_login_trigger_update_details
		return
	}

	# ensure value is a number
	if {![string is integer -strict $action_code_reminders] || $action_code_reminders < 0} {
		err_bind "You must supply a positive number"
		go_login_trigger_update_details
		return
	}

	# ensure value is a number
	if {![string is integer -strict $action_code_reminders_days] || $action_code_reminders_days < 0} {
		err_bind "You must supply a positive number"
		go_login_trigger_update_details
		return
	}

	set sql {
		update
			tLoginActCode
		set
			desc               = ?,
			max_reminders      = ?,
			max_reminders_days = ?,
			skip_elite         = ?
		where
			action_id          = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_code_desc           \
							$action_code_reminders      \
							$action_code_reminders_days \
							$action_code_skip_elite     \
							$action_id]
	inf_close_stmt $stmt
	db_close $rs

	msg_bind "Successfully updated Update Details action"

	go_login_trigger_update_details

}


#
# Update the Interval Options
#
proc ADMIN::LOGINTRIGGERS::do_login_trigger_grp {} {

	global DB

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to perform this action"
		asPlayFile -nocache main_area.html
		return
	}

	set action_id [reqGetArg action_id]
	set action    [reqGetArg submit_name]

	switch $action {
		"Update" {
			# Update the group
			set grp_code [reqGetArg id_name]
			set status   [reqGetArg update_status_$grp_code]
			
			set sql {
				update
					tLoginActGrp
				set
					status       = ?,
					last_updated = current
				where
					cust_code    = ?
			}
		
			set stmt [inf_prep_sql  $DB $sql]
			set rs   [inf_exec_stmt $stmt $status \
									$grp_code]
			inf_close_stmt $stmt
			db_close $rs
		
			msg_bind "Successfully updated group '$grp_code'"
		
			go_login_trigger_update_details
		}
		"Add" {
			# Insert the group
			set grp_code [reqGetArg new_grp]
			
			set sql {
				insert into
					tLoginActGrp (
						cust_code,
						action_id,
						status,
						last_updated)
				values (  ?,
						?,
						"U",
						current)
			}
		
			set stmt [inf_prep_sql  $DB $sql]
			set rs   [inf_exec_stmt $stmt $grp_code $action_id]
			inf_close_stmt $stmt
			db_close $rs
		
			msg_bind "Successfully inserted new group '$grp_code'"
		
			go_login_trigger_update_details
		}
		"Audit" {
			# Show audit page
			reqSetArg cust_code [reqGetArg id_name]
			ADMIN::AUDIT::go_audit
		}
		default {
			# this should never happen
			err_bind "Invalid action"
			go_login_trigger_update_details
		}
	}

}


#
# Update the Interval Options
#
proc ADMIN::LOGINTRIGGERS::do_login_trigger_flag {} {

	global DB

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to perform this action"
		asPlayFile -nocache main_area.html
		return
	}

	set action_id [reqGetArg action_id]
	set action    [reqGetArg submit_name]

	switch $action {
		"Update" {
			# Update the flag
			set flag_tag  [reqGetArg id_name]
			set status    [reqGetArg update_status_$flag_tag]
			set once_only [reqGetArg once_only_$flag_tag]
			
			set sql {
				update
					tLoginActFlag
				set
					status          = ?,
					once_only       = ?
				where
					status_flag_tag = ?
			}
		
			set stmt [inf_prep_sql  $DB $sql]
			set rs   [inf_exec_stmt $stmt $status \
									$once_only \
									$flag_tag]
			inf_close_stmt $stmt
			db_close $rs
		
			msg_bind "Successfully updated flag '$flag_tag'"
		
			go_login_trigger_update_details
		}
		"Add" {
			# Insert the flag
			set flag_tag [reqGetArg new_flag]
			
			set sql {
				insert into
					tLoginActFlag (
						status_flag_tag,
						action_id,
						status,
						once_only)
				values (  ?,
						?,
						"U",
						"Y")
			}
		
			set stmt [inf_prep_sql  $DB $sql]
			set rs   [inf_exec_stmt $stmt $flag_tag $action_id]
			inf_close_stmt $stmt
			db_close $rs
		
			msg_bind "Successfully inserted new flag '$flag_tag'"
		
			go_login_trigger_update_details
		}
		"Audit" {
			# Show audit page
			reqSetArg flag_tag [reqGetArg id_name]
			ADMIN::AUDIT::go_audit
		}
		default {
			# this should never happen
			err_bind "Invalid action"
			go_login_trigger_update_details
		}
	}

}


#
# Update the Interval Options
#
proc ADMIN::LOGINTRIGGERS::do_login_trigger_interval_update {} {

	global DB

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to perform this action"
		asPlayFile -nocache main_area.html
		return
	}

	set action_id [reqGetArg action_id]
	set action    [reqGetArg submit_name]

	switch $action {
		"Update" {
			set days_1      [reqGetArg action_code_interval_1]
			set days_2      [reqGetArg action_code_interval_2]
		
			# decide which input field to use
			if {$days_2 == ""} {
				set days $days_1
			} else {
				set days $days_2
			}
		
			# we do not want to use default val
			if {$days == "999"} {
				err_bind "You must supply a value"
				go_login_trigger_update_details
				return
			}

			# ensure value is a number
			if {![string is integer -strict $days] || $days < 0} {
				err_bind "You must supply a positive number"
				go_login_trigger_update_details
				return
			}
		
			set sql {
				update
					tLoginActInt
				set
					days        = ?
				where
					action_id   = ?
			}
		
			set stmt [inf_prep_sql  $DB $sql]
			set rs   [inf_exec_stmt $stmt $days \
									$action_id]
			inf_close_stmt $stmt
			db_close $rs
		
			msg_bind "Successfully updated Interval options"
		
			go_login_trigger_update_details
		}
		"Audit" {
			# Show audit page
			reqSetArg action_code [reqGetArg action_code]
			ADMIN::AUDIT::go_audit
		}
		default {
			# this should never happen
			err_bind "Invalid action"
			go_login_trigger_update_details
		}
	}

}


#
# Show list of active entries in upload list
#
proc ADMIN::LOGINTRIGGERS::do_view_active_upload_list {} {

	global DB ACTIVE_UPLOADS

	# The action id we are using
	set action_id [reqGetArg action_id]

	set sql {
		select
			c.acct_no,
			c.cust_id,
			c.username,
			r.fname as first_name,
			r.lname as last_name,
			ac.cr_date,
			br.location as filename
		from
			tCustomer c,
			tCustomerReg r,
			tLoginActCust ac,
			tBatchReference br
		where
			c.cust_id = r.cust_id and
			r.cust_id = ac.cust_id and
			ac.batch_ref_id = br.batch_ref_id and
			ac.upload_id = (    select
								max (ac2.upload_id)
							from
								tLoginActCust ac2
							where
								ac.cust_id     = ac2.cust_id and
								ac.action_id   = ac2.action_id) and
			ac.action_id = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt $action_id]

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		foreach c [db_get_colnames $rs] {
			set ACTIVE_UPLOADS($i,$c) [db_get_col $rs $i $c]
		}
	}

	tpBindString num_active_uploads $nrows
	ob_log::write_array DEV ACTIVE_UPLOADS

	foreach c [db_get_colnames $rs] {
		tpBindVar $c ACTIVE_UPLOADS $c uploads_active_idx
	}

	tpBindString action_id $action_id

	inf_close_stmt $stmt
	db_close $rs

	asPlayFile -nocache login_trigger_view_active_uploads.html
	
}


#
# Delete selected active uploads
#
proc ADMIN::LOGINTRIGGERS::do_active_upload_delete {} {

	global DB

	# ensure Admin has right auths!
	if {![op_allowed ManageLoginTriggers]} {
		err_bind "You do not have permission to perform this action"
		asPlayFile -nocache main_area.html
		return
	}

	set action    [reqGetArg submit_name]
	set action_id [reqGetArg action_id]

	switch $action {
		"Delete" {
			set selected_cust_ids     [ob_chk::get_arg delete_active -multi UINT]

			# show an error if no accounts were selected
			if {[llength $selected_cust_ids] == 0} {
				err_bind "No accounts were selected"

				do_view_active_upload_list
				return
			}
		
			foreach cust_id $selected_cust_ids {
		
				set sql {
					delete from
						tLoginActCust
					where
						cust_id   = ? and
						action_id = ?
				}
			
				set stmt [inf_prep_sql  $DB $sql]
				if {[catch {set rs [inf_exec_stmt $stmt $cust_id $action_id]} msg]} {
					ob_log::write ERROR {ADMIN::LOGINTRIGGERS::do_active_upload_delete: Failed to execute query, $msg}
					err_bind "Some customers could not be deleted."
					inf_close_stmt $stmt
					go_login_trigger_update_details
					return
				}

				inf_close_stmt $stmt
				db_close $rs

			}
		
			msg_bind "Successfully deleted accounts from list"
		
			do_view_active_upload_list
		}
		"Back" -
		default {
			go_login_trigger_update_details
		}
	}
}
