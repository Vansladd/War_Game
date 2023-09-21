# =============================================================================
# $Id: payment_rules_profile.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# =============================================================================


# -----------------------------------------------------------------------------
# Code for the Activation and Management of Payment-Rule-Profiles (PRPs).
# -----------------------------------------------------------------------------

namespace eval ADMIN::PMT {
}

#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One off initialisation
#
proc ADMIN::PMT::PRProfile_init {} {

	# Action handlers

	# prp_switch_profile.html
	#
	asSetAct ADMIN::PMT::GoSwitchPRProfile   [namespace code H_go_switch_prp]
	asSetAct ADMIN::PMT::DoActivatePRProfile [namespace code H_do_activate_prp]

	# prp_profiles_list.html
	#
	asSetAct ADMIN::PMT::GoListPRProfiles    [namespace code H_go_list_prps]
	asSetAct ADMIN::PMT::GoEditPRProfile     [namespace code H_go_edit_prp]
	asSetAct ADMIN::PMT::GoNewPRProfile      [namespace code H_go_new_prp]
	asSetAct ADMIN::PMT::DeleteProfile       [namespace code H_do_delete_profile]

	# prp_new_profile.html
	#
	asSetAct ADMIN::PMT::DoAddNewPRProfile   [namespace code H_do_add_prp]

	# prp_edit_profile.html
	#
	asSetAct ADMIN::PMT::GoEditPmtRule       [namespace code H_go_edit_pmt_rule]
	asSetAct ADMIN::PMT::DoUpdatePRProfile   [namespace code H_do_update_prp]

	# prp_edit_rule.html
	#
	asSetAct ADMIN::PMT::DoEditPmtRule       [namespace code H_do_update_pmt_rule]

}



#-------------------------------------------------------------------------------
# Action handlers
#-------------------------------------------------------------------------------

# Prepares a page that allows the activation of a payment rule profile.
#
proc ADMIN::PMT::H_go_switch_prp args {

	ob_log::write DEBUG {===> H_go_switch_prp}

	global DB

	# Array to contain list of active payment rule profiles
	global    PR_PROFILES
	array set PR_PROFILES [list]

	# get active payment rule profiles
	set sql {
		select
			profile_id,
			profile_name,
			cur_active
		from
			tPmtRuleProf
		where
			status = 'A';
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {

		set profile_id   [db_get_col $res $i profile_id]
		set profile_name [db_get_col $res $i profile_name]

		set PR_PROFILES($i,id)   $profile_id
		set cur_active           [db_get_col $res $i cur_active]

		# The last profile activated is set as 'selected' in dropdown list
		if {$cur_active == "Y"} {

			ob_log::write DEBUG {Profile '$profile_name' (id=$profile_id)\
			                     was the last to be activated.}

			set PR_PROFILES($i,name) "$profile_name (Currently Active)"

			tpBindString ActivePRProfileId $profile_id
		} else {
			set PR_PROFILES($i,name) $profile_name
		}
	}

	db_close $res

	ob_log::write_array DEBUG PR_PROFILES

	tpSetVar N_PRProfiles $n_rows

	tpBindVar  PRProfile_Id    PR_PROFILES  id    prp_idx
	tpBindVar  PRProfile_Name  PR_PROFILES  name  prp_idx

	asPlayFile -nocache prp_switch_profile.html

	ob_log::write DEBUG {<=== H_go_switch_prp}
}



# Activate a payment rules profile.
#
proc ADMIN::PMT::H_do_activate_prp args {

	ob_log::write DEBUG {===> H_do_activate_prp}

	global DB

	# check for permission to activate profile
	if {[op_allowed ActivatePRProfile]} {

		set profile_id [reqGetArg active_profile]

		ob_log::write INFO {Activating payment rule profile id=$profile_id.}

		# Start transaction
		inf_begin_tran $DB

		# Phase 1/3 - Remove the existing live rules - CC rules only.
		#             pg_sub_acct_id rules relate to non CC rules that
		#             are proxied throug the CC managed service.
		set sql {
			delete from tPmtRuleDest
			where exists (
				select
					1
				from
					tPmtGateAcct a
				where
					a.pg_acct_id   = tPmtRuleDest.pg_acct_id
				and a.pay_mthd     = 'CC'
			)
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt]} msg]} {

			# Failed - Rollback trans & report the error.
			_rollback_prp_activation {Profile not activated: The live payment\
			                          rules cannot be removed.} $msg

			ob_log::write DEBUG {<=== H_do_activate_prp}
			
			return
		}

		inf_close_stmt $stmt
		db_close $res

		# Phase 2/3 - Copy rows from the selected profile into tPmtRuleDest
		#
		set sql {
			insert into tPmtRuleDest(
				pg_rule_id,
				pg_acct_id,
				pg_host_id,
				percentage,
				pg_sub_acct_id
			)
			select
				pg_rule_id,
				pg_acct_id,
				pg_host_id,
				percentage,
				pg_sub_acct_id
			from
				tPmtRulePrfDst
			where
				profile_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $profile_id]} msg]} {

			# Failed - Rollback trans & report the error.
			_rollback_prp_activation {Profile not activated: The rules of the\
								   selected profile cannot be made live.} $msg

			ob_log::write DEBUG {<=== H_do_activate_prp}

			return
		}

		inf_close_stmt $stmt
		db_close $res

		# Phase 3/3 - Set the activated profile as 'last used' in TWO steps:
		#
		# (i) Set the cur_active flag to 'N' from all existing profiles.
		#
		set sql {
			update
				tPmtRuleProf
			set
				cur_active   = 'N'
			where 
				profile_id  <> ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $profile_id]} msg]} {

			# Failed - Rollback trans & report the error.
			_rollback_prp_activation {Profile not activated: Failed in resetting\
			                          the cur_active flag.} $msg

			ob_log::write DEBUG {<=== H_do_activate_prp}
			
			return
		}

		inf_close_stmt $stmt
		db_close $res


		# (ii) Set the cur_active flag to 'Y' for the activated profile.
		#
		set sql {
			update
				tPmtRuleProf
			set
				cur_active  = 'Y'
			where
				profile_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $profile_id]} msg]} {

			# Failed - Rollback trans & report the error.
			_rollback_prp_activation {Profile not activated: Failed to set the \
			                          cur_active flag.} $msg

			ob_log::write DEBUG {<=== H_do_activate_prp}
			
			return
		}

		# All stages have completed successfully. Commit the transaction and
		# display message to the user.
		inf_close_stmt $stmt
		db_close $res

		inf_commit_tran $DB

		_report_op_success {Activated profile}

	} else {

		# No Admin permission
		#
		_report_op_error \
			{You do not have the permission to activate the profile}
	}

	H_go_switch_prp

	ob_log::write DEBUG {<=== H_do_activate_prp}
}



# Lists all payment gateway profiles and their statuses.
#
# This page also provides the links to edit these profiles or
# to create a new one.
#
proc ADMIN::PMT::H_go_list_prps args {

	ob_log::write DEBUG {===> H_go_list_prps}

	global DB

	# Array to store profile data
	global    PR_PROFILES
	array set PR_PROFILES [list]

	# Get all payment gateway profiles
	set sql [subst {
		select
			profile_id,
			profile_name,
			profile_desc,
			status
		from
			tPmtRuleProf
		where
			status <> 'X'
		order by
			status
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set PR_PROFILES($i,id)     [db_get_col $res $i profile_id]
		set PR_PROFILES($i,name)   [db_get_col $res $i profile_name]
		set PR_PROFILES($i,desc)   [db_get_col $res $i profile_desc]
		set PR_PROFILES($i,status) [db_get_col $res $i status]
	}

	db_close $res

	ob_log::write_array DEBUG PR_PROFILES

	tpSetVar N_PRProfiles $n_rows

	tpBindVar  PRProfile_Id      PR_PROFILES  id      prp_idx
	tpBindVar  PRProfile_Name    PR_PROFILES  name    prp_idx
	tpBindVar  PRProfile_Desc    PR_PROFILES  desc    prp_idx
	tpBindVar  PRProfile_Status  PR_PROFILES  status  prp_idx

	asPlayFile -nocache prp_profiles_list.html

	ob_log::write DEBUG {<=== H_go_list_prps}
}



# Mark a profile as removed (status 'X')
#
proc ADMIN::PMT::H_do_delete_profile args {

	ob_log::write DEBUG {===> H_do_delete_profile}

	global DB

	# get the profile_id
	set profile_id [reqGetArg profile_id]

	# check that the profile exists
	set sql {
		select
			profile_id
		from
			tPmtRuleProf
		where
			profile_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set res  [inf_exec_stmt $stmt $profile_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		# don't go any further - there was nothing (or too much) to delete
		H_go_list_prps
		return
	}

	# now go ahead with the delete
	inf_begin_tran $DB

	# first, delete from tPmtRulePrfDst
	set sql {
		delete from
			tPmtRulePrfDst
		where
			profile_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $profile_id]} msg]} {
		inf_rollback_tran $DB
		_report_op_error "Unable to delete profile dest" $msg
		H_go_list_prps
		return
	}

	# Now delete from tPmtRuleProf
	set sql {
		delete from
			tPmtRuleProf
		where
			profile_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $profile_id]} msg]} {
		inf_rollback_tran $DB
		_report_op_error "Unable to delete profile" $msg
		H_go_list_prps
		return
	}

	# otherwise, it worked
	inf_commit_tran $DB

	H_go_list_prps

}



# Creating a new payment-rules-profile.
#
proc ADMIN::PMT::H_go_new_prp args {

	# if the page is being redisplayed (e.g. after an error) rebind up the
	# values submitted.
	tpBindString ProfileName   [reqGetArg profile_name]
	tpBindString ProfileDesc   [reqGetArg profile_desc]
	tpBindString ProfileStatus [reqGetArg profile_status]

	asPlayFile -nocache prp_new_profile.html
}



# Add a new payment rule profile.
#
proc ADMIN::PMT::H_do_add_prp args {

	ob_log::write DEBUG {===> H_do_add_new_prp}

	global DB

	# Check user has permissions
	if {[op_allowed EditPRProfile]} {

		set profile_name   [reqGetArg profile_name]
		set profile_desc   [reqGetArg profile_desc]
		set profile_status [reqGetArg profile_status]

		ob_log::write INFO \
			{Add a new payment-rules-profile name=$profile_name, desc=$profile_desc, status=$profile_status}

		# insert the new profile.
		set sql {
			insert into tPmtRuleProf (
				profile_name,
				profile_desc,
				status)
			values
				(?, ?, ?)
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt $stmt $profile_name $profile_desc \
					$profile_status]} exception_msg]
		} {

			# insert failed - replay the page with an error msg.
			_report_op_error {Cannot add profile} $exception_msg

			H_go_new_prp

		} else {

			# succeeded
			inf_close_stmt $stmt
			db_close $res	

			_report_op_success "New profile '$profile_name' created."

			H_go_list_prps
		}

	} else {

		# No Admin permission
		#
		_report_op_error \
			{You do not have the permission to edit payment rules profiles}

		H_go_list_prps
	}

	ob_log::write DEBUG {<=== H_do_add_new_prp}
}



# Given a profile_id passed in as a request argument, display an overview of
# the payment rule profile. This overview will consist of the name, description
# and status of the profile. Also, there will be a list of all payment rules
# (from tPmtGateChoose) and for each rule, the currently stored percentages
# will be displayed next to it, e.g.:
#
#   UK Internet Deposits       ---> 50% UK Internet Deposits Datacash GBP
#                              ---> 50% UK Internet Deposits Trustmarque GBP
#   UK Internet Withdrawals    ---> 100% UK Internet Withdrawals Datacash GBP
#   NONUK Internet Deposits    ---> 100% NONUK Internet Deposits Datacash GBP
#
# Each rule will link to a page where the percentages can be modified.
#
# The profile name, description and status can also be updated
#
proc ADMIN::PMT::H_go_edit_prp args {

	ob_log::write DEBUG {===> H_go_view_prps}

	global DB

	# Holds info about payment rules in selected profile
	global    PRP_RULES
	array set PRP_RULES [list]

	set profile_id   [reqGetArg profile_id]

	ob_log::write INFO \
		{Listing information on payment rules for id=$profile_id}

	# Prepare a list of all Active payment rules for CC accounts only, together
	# with the accounts and the percentages being paid through them for the
	# given profile.
	set sql {
		select
			rd.pg_rule_id,
			rd.condition_desc,
			rd.condition_tcl_1,
			rd.condition_tcl_2,
			a.desc,
			a.pg_type,
			a.pg_acct_id,
			NVL(r.percentage, 0) as percentage,
			rd.priority
		from
			tPmtGateChoose rd,
			outer (tPmtRulePrfDst r,
			       tPmtGateAcct a)
		where
			rd.status     = 'A'
		and rd.pay_mthd   = 'CC'
		and r.profile_id  = ?
		and a.pg_acct_id  = r.pg_acct_id
		and rd.pg_rule_id = r.pg_rule_id
		order by
			rd.priority
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $profile_id]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]
	
	# initialise counters
	set rule_idx -1
	set prev_pg_rule_id -1

	# Loop through the result set.
	for {set i 0} {$i < $n_rows} {incr i} {

		set rule_id           [db_get_col $res $i pg_rule_id]
		set percentage        [db_get_col $res $i percentage]

		if {$prev_pg_rule_id != $rule_id} {

			# The current rule is a new rule. Setup the rule based data and
			# then initialise counters for the account based data.
			incr rule_idx 1
			set prev_pg_rule_id $rule_id

			set PRP_RULES($rule_idx,rule_id) \
				[db_get_col $res $i pg_rule_id]
			set PRP_RULES($rule_idx,rule_desc) \
				[db_get_col $res $i condition_desc]
			set PRP_RULES($rule_idx,accounts)  1

			set PRP_RULES($rule_idx,condition_tcl_1) \
				"[db_get_col $res $i condition_tcl_1] [db_get_col $res $i condition_tcl_2]"

			set PRP_RULES($rule_idx,priority) \
				[db_get_col $res $i priority]

			set acct_index 0
		} else {

			# Current rule is the same as the previous one. Just increase the
			# counters.
			incr PRP_RULES($rule_idx,accounts) 1

			incr acct_index 1
		}

		# Store the Account based data.
		set PRP_RULES($rule_idx,$acct_index,percentage) \
									  [db_get_col $res $i percentage]

		set PRP_RULES($rule_idx,$acct_index,desc) [db_get_col $res $i desc]
		set PRP_RULES($rule_idx,$acct_index,pg_type) [db_get_col $res $i pg_type]
		set PRP_RULES($rule_idx,$acct_index,pg_acct_id) [db_get_col $res $i pg_acct_id]


	}

	db_close $res

	ob_log::write_array DEBUG PRP_RULES

	tpSetVar N_Rules [expr $rule_idx + 1]

	tpBindVar  Rule_Name        PRP_RULES rule_desc        rule_idx
	tpBindVar  Rule_Id          PRP_RULES rule_id          rule_idx
	tpBindVar  Rule_Priority    PRP_RULES priority         rule_idx
	tpBindVar  Num_Accounts     PRP_RULES accounts         rule_idx
	tpBindVar  Rule_Tcl         PRP_RULES condition_tcl_1  rule_idx
	tpBindVar  Acct_Desc        PRP_RULES desc        rule_idx  account_idx
	tpBindVar  Acct_PG_Type     PRP_RULES pg_type     rule_idx  account_idx
	tpBindVar  Acct_Percentage  PRP_RULES percentage  rule_idx  account_idx
	tpBindVar  Acct_Id          PRP_RULES pg_acct_id  rule_idx  account_idx


	# Get profile name and description.
	#
	set sql [subst {
		select
			profile_name,
			profile_desc,
			status
		from
			tPmtRuleProf
		where
			profile_id = $profile_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString Profile_Id       $profile_id
	tpBindString Profile_Name     [db_get_col $res 0 profile_name]
	tpBindString Profile_Desc     [db_get_col $res 0 profile_desc]
	tpBindString Profile_CBStatus [db_get_col $res 0 status]

	db_close $res


	asPlayFile -nocache prp_edit_profile.html

	ob_log::write DEBUG {<=== H_go_view_prps}
}



# Updates the name, description and status of a profile
#
proc ADMIN::PMT::H_do_update_prp args {

	ob_log::write DEBUG {===> H_do_update_prp}

	global DB

	# Check for permission to edit payment gateway rules
	if {[op_allowed EditPRProfile]} {

		set profile_id     [reqGetArg profile_id]
		set profile_name   [reqGetArg profile_name]
		set profile_desc   [reqGetArg profile_desc]
		set profile_status [reqGetArg profile_status]

		ob_log::write INFO {Updating payment-rules-profile (id=$profile_id)\
				 name=$profile_name, desc=$profile_desc, status=$profile_status}

		# Update profile.
		#
		set sql {
			update
				tPmtRuleProf
			set
				profile_name = ?,
				profile_desc = ?,
				status       = ?
			where
				profile_id = ?
		}
	
		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt $stmt $profile_name $profile_desc \
				$profile_status $profile_id]} msg]
		} {
			# insert failed - replay the page with an error msg.
			_report_op_error {Cannot add profile} $exception_msg

			go_edit_prp

			inf_close_stmt $stmt
			db_close $res
			return
		}

		inf_close_stmt $stmt
		db_close $res

		# Report the success
		#
		_report_op_success {Profile updated}

	} else {

		# No Admin permission
		#
		_report_op_error {You do not have the permission to edit payment \
				rules profiles}

		H_go_edit_prp

		return
	}

	H_go_list_prps

	ob_log::write DEBUG {<=== H_do_update_prp}
}



# Prepares a page to allow users to change to the payment
# percentage allocated to different payment accounts.
#
proc ADMIN::PMT::H_go_edit_pmt_rule args {

	ob_log::write DEBUG {===> H_go_edit_pmt_rule}

	global DB

	global    GW_RULE_ACCTS
	array set GW_RULE_ACCTS [list]

	# Array to hold payment gateway host info
	global    GW_HOSTS
	array set GW_HOSTS [list]

	array set PMT_ACCOUNTS      [list]
	array set PMT_ACCT_TO_INDEX [list]

	set profile_id   [reqGetArg profile_id]
	set rule_id      [reqGetArg rule_id]

	# get profile info
	ob_log::write INFO \
		{In H_go_edit_pmt_rule: for rule_id=$rule_id, id=$profile_id}

	# Get a list of active gateway hosts.
	set sql {
		select
			pg_host_id,
			pg_type,
			desc
		from
			tPmtGateHost
		where
			status = 'A'
		and pg_type in (select pg_type from tPmtGateAcct a where a.pay_mthd   = 'CC')
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {

		set GW_HOSTS($i,host_id)   [db_get_col $res $i pg_host_id]
		set GW_HOSTS($i,host_type) [db_get_col $res $i pg_type]
		set GW_HOSTS($i,host_desc) [db_get_col $res $i desc]
	}

	db_close $res

	ob_log::write_array DEBUG GW_HOSTS

	tpSetVar   N_Hosts $n_rows

	tpBindVar  GWHost_Id    GW_HOSTS  host_id    host_idx
	tpBindVar  GWHost_Type  GW_HOSTS  host_type  host_idx
	tpBindVar  GWHost_Desc  GW_HOSTS  host_desc  host_idx

	# Get a list of all payment gateway accounts and for any accounts that have
	# a percentage assigned for the currently selected rule, also get the
	# percentage
	set sql {
		select
			a.pg_acct_id,
			a.desc,
			h.pg_host_id,
			a.pg_type,
			r.percentage
		from
			tPmtGateAcct a,
			outer (tPmtRulePrfDst r,
			       tPmtGateHost h)
		where
			a.status         = 'A'
			and a.pay_mthd   = 'CC'
			and r.profile_id = ?
			and r.pg_rule_id = ?
			and a.pg_acct_id = r.pg_acct_id
			and h.pg_host_id = r.pg_host_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $profile_id $rule_id]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {

		set GW_RULE_ACCTS($i,acct_id)    [db_get_col $res $i pg_acct_id]
		set GW_RULE_ACCTS($i,acct_desc)  [db_get_col $res $i desc]
		set GW_RULE_ACCTS($i,host_id)    [db_get_col $res $i pg_host_id]
		set GW_RULE_ACCTS($i,pg_type)    [db_get_col $res $i pg_type]
		set GW_RULE_ACCTS($i,percentage) [db_get_col $res $i percentage]
	}

	db_close $res

	ob_log::write_array DEBUG GW_RULE_ACCTS

	tpSetVar   N_Accts $n_rows

	tpBindVar  Account_Id      GW_RULE_ACCTS  acct_id     acct_idx
	tpBindVar  Account_Name    GW_RULE_ACCTS  acct_desc   acct_idx
	tpBindVar  Host_Id         GW_RULE_ACCTS  host_id     acct_idx
	tpBindVar  pg_type         GW_RULE_ACCTS  pg_type     acct_idx
	tpBindVar  Pmt_Percentage  GW_RULE_ACCTS  percentage  acct_idx

	# Finally, get the profile name
	set sql {
		select
			profile_name
		from
			tPmtRuleProf
		where
			profile_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $profile_id]

	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		ob_log::write ERROR \
			{H_go_edit_pmt_rule - no profile found id=$profile_id}
	} else {
		set profile_name [db_get_col $res 0 profile_name]
	}

	db_close $res

	tpBindString Profile_Id   $profile_id
	tpBindString Profile_Name $profile_name
	tpBindString Rule_Id      $rule_id

	asPlayFile -nocache prp_edit_rule.html

	ob_log::write DEBUG {<=== H_go_edit_pmt_rule}
}



# Updates the payment gateway host id and payment percentage
# allocated to the payment accounts of a given rule.
#
proc ADMIN::PMT::H_do_update_pmt_rule args {

	ob_log::write DEBUG {===> H_do_update_pmt_rule}

	global DB

	if {[op_allowed EditPRProfile]} {

		set accounts   [reqGetArg accounts]
		set profile_id [reqGetArg profile_id]
		set rule_id    [reqGetArg rule_id]

		ob_log::write INFO {Update profile rule for profile_id=$profile_id\
		                                            and rule_id=$rule_id.}

		# Start a transaction to update payment accounts.
		#
		inf_begin_tran $DB

		set acct_ids_to_remove ""

		# Phase 1/2 - Going through the payment accounts
		# to update the rule descriptor table.
		#
		for {set i 0} {$i < $accounts} {incr i} {

			set percentage [reqGetArg "percentage_$i"]
			set acct_id    [reqGetArg "acct_$i"]
			set host_id    [reqGetArg "host_id_$i"]

			ob_log::write INFO {$percentage% of the payment is going through\
			                     acct_id=$acct_id is using host_id=$host_id.}

			# Update the profile-rule-descriptor table only
			# if a payment percentage was specified. Remove
			# the payment descriptions for accounts with no
			# percentage specified.
			#
			if {$percentage != "" && $percentage > 0} {

				# Check if a record exists to determine
				# if we need an INSERT or UPDATE.
				#
				set sql [subst {
					select
						pg_host_id,
						percentage
					from
						tPmtRulePrfDst
					where
						profile_id     = $profile_id
						and pg_rule_id = $rule_id
						and pg_acct_id = $acct_id
				}]

				set stmt [inf_prep_sql $DB $sql]
				set res [inf_exec_stmt $stmt]
				inf_close_stmt $stmt

				set n_rows [db_get_nrows $res]

				if {$n_rows == 0} {

					db_close $res

					# Insert a new account payment setting.
					#
					ob_log::write INFO {inserting new tPmtRulePrfDst record\
					                     (profile_id=$profile_id,\
					                         rule_id=$rule_id,\
					                         acct_id=$acct_id,\
					                         host_id=$host_id,\
					                      percentage=$percentage).}

					set sql [subst {
						insert into
							tPmtRulePrfDst
						values (
							'$profile_id',
							'$rule_id',
							'$acct_id',
							'$host_id',
							'$percentage'
						)}]

					set stmt [inf_prep_sql $DB $sql]

					if {[catch {set res [inf_exec_stmt $stmt]} exception_msg]} {

						# Failed - Rollback, report error then end procedure.
						#
						inf_rollback_tran $DB

						_report_op_error {Cannot update payment accounts:\
						                 Failed to insert info for a new\
						                 payment account.}\
						                $exception_msg

						H_go_edit_prp

						ob_log::write DEBUG {<=== H_do_update_pmt_rule}

						return
					}

					# Succeeded - Continue with the next account.
					#
					inf_close_stmt $stmt
					db_close $res

				} else {

					set old_percentage [db_get_col $res 0 percentage]
					set old_host_id    [db_get_col $res 0 pg_host_id]

					db_close $res

					# We update tPmtRulePrfDst if either the host
					# or payment percentage changed.
					#
					if {$old_percentage != $percentage
					    || $old_host_id != $host_id} {

						# Update payment account setting.
						#
						ob_log::write INFO {updating host_id and %:\
						                     (old host id=$old_host_id,\
						                      old percentage value=$old_percentage%)\
						                  to (host_id=$host_id,\
						                      percentage=$percentage%).}

						set sql [subst {
							update tPmtRulePrfDst
							set pg_host_id = $host_id,
							    percentage = $percentage
							where
							    profile_id     = $profile_id
							    and pg_rule_id = $rule_id
							    and pg_acct_id = $acct_id
						}]

						set stmt [inf_prep_sql $DB $sql]

						if {[catch {set res [inf_exec_stmt $stmt]} exception_msg]} {

							# Failed - Rollback, report error then end procedure.
							#
							inf_rollback_tran $DB

							_report_op_error {Cannot update payment accounts:\
							                 Failed to update info for an existing\
							                 payment account.}\
							                $exception_msg

							H_go_edit_prp

							ob_log::write DEBUG {<=== do_update_pmt_rule}

							return
						}

						# Succeeded - Continue with the next account.
						#
						inf_close_stmt $stmt
						db_close $res
					}
				}

			} else {

				# Add this account to the 'to remove list'.
				#
				if {$acct_ids_to_remove == ""} {

					append acct_ids_to_remove "$acct_id"

				} else {

					append acct_ids_to_remove ",$acct_id"
				}
			}
		}

		# Phase 2/2 - Remove payment descriptors where no
		# percentage value was specified.
		#
		if {$acct_ids_to_remove != ""} {
			set sql [subst {
				delete from tPmtRulePrfDst
				where
					profile_id     =  $profile_id
					and pg_rule_id =  $rule_id
					and pg_acct_id in ($acct_ids_to_remove)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {set res [inf_exec_stmt $stmt]} exception_msg]} {

				# Failed - Rollback, report error then end procedure.
				#
				inf_rollback_tran $DB

				_report_op_error {Cannot update payment accounts:\
				                 Failed to remove accounts with no\
				                 payment percentages.}\
				                $exception_msg

				H_go_edit_prp

				ob_log::write DEBUG {<=== do_update_pmt_rule}

				return
			}

			# Succeeded
			#
			inf_close_stmt $stmt

			db_close $res
		}

		# Commit transaction and report a success
		inf_commit_tran $DB

		_report_op_success {Payment accounts updated.}

	} else {

		# No Admin permission
		_report_op_error {You do not have the permission to edit payment rules profiles}
	}

	H_go_edit_prp

	ob_log::write DEBUG {<=== H_do_update_pmt_rule}
}



#-------------------------------------------------------------------------------
# Utilities
#-------------------------------------------------------------------------------

# Report an error during an operation to the log and user screen
#
#    err_msg        - error message to display to user
#    exception_msg  - exception to log
#
proc ADMIN::PMT::_report_op_error {err_msg {exception_msg ""}} {

	err_bind $err_msg

	ob_log::write ERROR {$err_msg}

	if {$exception_msg != ""} {
		ob_log::write INFO {$exception_msg}
	}
}



# Report the success of an operation to the log and user screen
#
#    msg - the message to display
#
proc ADMIN::PMT::_report_op_success msg {

	msg_bind $msg

	ob_log::write INFO {$msg}
}



# Rollback transaction and log error messages
#
#    err_msg       - error message to show user
#    exception_msg - exception to log
#
proc ADMIN::PMT::_rollback_prp_activation {err_msg exception_msg} {

	global DB

	inf_rollback_tran $DB

	_report_op_error $err_msg $exception_msg

	H_go_switch_prp
}

# self initialisation
ADMIN::PMT::PRProfile_init
