# ==============================================================
# $Id: bf_account.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::BETFAIR_ACCT {

asSetAct ADMIN::BETFAIR_ACCT::GoBFAccount           [namespace code go_bf_account]
asSetAct ADMIN::BETFAIR_ACCT::DoBFAccount           [namespace code do_bf_account]


# -------------------------------------------------------------------------------
# proc to display page to add or edit a betafir account
# --------------------------------------------------------------------------------
proc go_bf_account {} {

	global DB

	set act [reqGetArg SubmitName]

	if {$act =="AddAcct"} {
		tpSetVar AddAcct 1

	} elseif {$act =="EditAcct"} {

		set name [reqGetArg Name]

		set sql [subst {
			select
				password,
				status
			from
				tBFAccount
			where
				name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $name]} msg]} {
						ob::log::write ERROR {go_bf_account - $msg}
						err_bind "$msg"
						return 0
		}

		set nrows  [db_get_nrows $res]
		if {$nrows != 0} {
			tpBindString Name   	$name
			tpBindString Password   [db_get_col $res 0 password]
			tpBindString Status 	[db_get_col $res 0 status]
		}

		inf_close_stmt $stmt
		tpSetVar EditAcct 1
	}
	asPlayFile -nocache bf_account.html
}


proc do_bf_account {} {

	global DB

	set act [reqGetArg SubmitName]

	if {$act =="AddAccount"} {
		do_add_bf_account
	} elseif {$act =="UpdAccount"} {
		do_upd_bf_account
	}
}

#
# ----------------------------------------------------------------------------
# Add a new betfair account
# ----------------------------------------------------------------------------
#
proc do_add_bf_account {} {

	global DB

	ob::log::write INFO {Adding a new Betfair Account}

	set username 	[reqGetArg Username]
	set password 	[reqGetArg Password]
	set vpassword 	[reqGetArg VPassword]
	set status 		[reqGetArg Status]

	set sql [subst {
		select
			1
		from
			tBFAccount
		where
			name = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $username]} msg]} {
					ob::log::write ERROR {do_add_bf_account - $msg}
					err_bind "$msg"
					return 0
	}

	inf_close_stmt $stmt

	set nrows  [db_get_nrows $res]
	db_close $res

	if {$nrows > 0} {
		err_bind "User $username Already Exists"
		tpSetVar AddAcct 1
		asPlayFile -nocache bf_account.html
		return 0
	}

	if {$password != $vpassword} {
		err_bind "Password and confirm Password Fields do not match"
		tpSetVar AddAcct 1
		asPlayFile -nocache bf_account.html
		return 0
	}

	set password 	[ob_crypt::encrypt_by_bf $password]

	set sql [subst {
		insert into
			tBFAccount(name,password,status)
			values(?,?,?)
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt	$username $password $status} msg]} {
					ob::log::write ERROR {do_add_bf_account - $msg}
					err_bind "$msg"
	}

	inf_close_stmt $stmt
	ADMIN::BETFAIR::go_bf_control
}


#
# ----------------------------------------------------------------------------
# Updates existing betfair account
# ----------------------------------------------------------------------------
#
proc do_upd_bf_account {} {

	global DB

	ob::log::write INFO {Updating Betfair Account}

	set username 		[reqGetArg Username]
	set old_username 	[reqGetArg Name]
	set old_status 		[reqGetArg Old_Status]
	set password 		[reqGetArg Password]
	set vpassword 		[reqGetArg VPassword]
	set status 			[reqGetArg Status]

	tpBindString Name $old_username
	tpBindString Status $old_status

	if {$old_status != $status } {

		#
		#Check if the account is mapped to any admin user
		#
		set sql [subst {
			select
				1
			from
				tBFAccount a,
				tBFAcctAdminMap m
			where
				a.bf_acct_id = m.bf_acct_id
				and a.name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $old_username]} msg]} {
						ob::log::write ERROR {do_upd_bf_account - $msg}
						err_bind "$msg"
						return 0
		}

		inf_close_stmt $stmt

		set nrows_admin  [db_get_nrows $res]
		db_close $res

		#
		#Check if the account is mapped to any openbet class
		#
		set sql [subst {
			select
				1
			from
				tBFAccount a,
				tBFAcctClassMap m
			where
				a.bf_acct_id = m.bf_acct_id
				and a.name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $old_username]} msg]} {
						ob::log::write ERROR {do_upd_bf_account - $msg}
						err_bind "$msg"
						return 0
		}

		inf_close_stmt $stmt

		set nrows_class  [db_get_nrows $res]
		db_close $res

		if {($nrows_class > 0) || ($nrows_admin > 0)} {
			err_bind "This account's status cannot be suspended. There are Classes or Admin users mapped to it"
			tpSetVar EditAcct 1
			asPlayFile -nocache bf_account.html
			return 0
		}
	}

	if {$old_username != $username} {

		set sql [subst {
			select
				1
			from
				tBFAccount
			where
				name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $username]} msg]} {
						ob::log::write ERROR {do_upd_bf_account - $msg}
						err_bind "$msg"
						return 0
		}

		inf_close_stmt $stmt

		set nrows  [db_get_nrows $res]
		db_close $res

		if {$nrows > 0} {
			err_bind "User $username Already Exists"
			tpSetVar EditAcct 1
			asPlayFile -nocache bf_account.html
			return 0
		}
	}

	if {$password != $vpassword} {
		err_bind "Password and confirm Password Fields do not match"
		tpSetVar EditAcct 1
		asPlayFile -nocache bf_account.html
		return 0
	}

	if {($password == "") && ($vpassword == "")} {
		set sql [subst {
			update
				tBFAccount
			set
				name = ?,
				status = ?
			where
				name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt	$username $status $old_username} msg]} {
				ob::log::write ERROR {do_upd_bf_account - $msg}
				err_bind "$msg"
				return 0
		}
	} else {
		set new_password 	[ob_crypt::encrypt_by_bf $password]

		set sql [subst {
		update
			tBFAccount
		set
			name = ?,
			password = ?,
			status = ?
		where
			name = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {inf_exec_stmt $stmt	$username $new_password $status $old_username} msg]} {
				ob::log::write ERROR {do_upd_bf_account - $msg}
				err_bind "$msg"
				return 0
		}
	}

	inf_close_stmt $stmt
	ADMIN::BETFAIR::go_bf_control
}

# --------------------------------------------------------------------------
# Bind the betfair accounts
# ---------------------------------------------------------------------------
proc bind_bf_accounts {} {

	global DB 
	global BFACCT

	set sql {
		select
			name,
			status,
			bf_acct_id
		from
			tBFAccount
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt]} msg]} {
		err_bind $msg
		ob::log::write ERROR {bind_bf_accounts - $msg}
	}

	set nrows  [db_get_nrows $res]
	
	if {$nrows > 0} {
		for {set i 0} {$i < $nrows } {incr i} {
			set BFACCT($i,name) 	[db_get_col $res $i name]
			set BFACCT($i,id) 		[db_get_col $res $i bf_acct_id]
			set BFACCT($i,status) 	[db_get_col $res $i status]			
		}
		tpBindVar Name   	BFACCT name  	bf_acct_idx
		tpBindVar id      	BFACCT id    	bf_acct_idx
		tpBindVar status    BFACCT status   bf_acct_idx
		tpSetVar AcctRows $nrows
	}

	inf_close_stmt $stmt
	db_close $res
}


# ----------------------------------------------------------------------------
# retrieve the betfair account mapped to a particular class or admin user
# ----------------------------------------------------------------------------
proc get_mapped_bf_acct {user_id type} {

	global DB

	if {$type == "admin"} {

		set table_name tBFAcctAdminMap
		set field_name user_id

	} elseif {$type == "class"} {

		set table_name tBFAcctClassMap
		set field_name ev_class_id
	}

	set sql [subst {
			select
				bm.bf_acct_id,
				ba.name
			from
				$table_name bm,
				tBFAccount ba
			where
				bm.bf_acct_id = ba.bf_acct_id
				and bm.$field_name = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $user_id]} msg]} {
		ob::log::write ERROR {get_mapped_bf_acct - $msg}
		err_bind "$msg"
		return 0
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows >0} {
		set bf_acct_id 			[db_get_col $res 0 bf_acct_id]
		set bf_acct_name 		[db_get_col $res 0 name]

		tpBindString BFAcctId 		$bf_acct_id
		tpBindString BFAcctName 	$bf_acct_name
	}
	db_close $res
}

# ------------------------------------------------------------------------
# updates the betfair account mapped to a particular class or admin user
# -------------------------------------------------------------------------
proc do_map_bf_class_to_account {class_id bf_acct_id} { 

	global DB

	ob_log::write INFO {do_map_bf_class_to_account ev_class_id=$class_id bf_acct_id=$bf_acct_id} 

	#
	# Permission check 
	#
	if {![op_allowed MapBFAcctToClass]} {
		ob::log::write ERROR {do_map_bf_class_to_account - missing MapBFAcctToClass permission}
		err_bind "No Permission to update Betfair Account"
		return 
	} 

	#
	# Retrieve old class data 
	#	
	ob_log::write INFO {do_map_bf_class_to_account:: Retrieve old mapping for ev_class_id=$class_id} 
	
	set sql [subst {
		select 
			*
		from
			tBFAcctClassMap
		where
			ev_class_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $class_id]} msg]} {
		ob::log::write ERROR {do_map_bf_class_to_account - $msg}
		err_bind "$msg"
		return 0
	}

	inf_close_stmt $stmt	

	set nrows [db_get_nrows $res] 
	
	if {$nrows == 1} { 
		set old_class_id [db_get_col $res 0 ev_class_id] 
		set old_acct_id  [db_get_col $res 0 bf_acct_id] 
	} else { 
		set old_class_id ""
		set old_acct_id  ""
	} 

	if {$bf_acct_id == "" && $old_acct_id != ""} { 
		
		# Delete mapping 
		
		ob_log::write INFO {do_map_bf_class_to_account:: delete mapping for ev_class_id=$class_id} 

		set sql [subst {
			delete from
				tBFAcctClassMap
			where
				ev_class_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $class_id]} msg]} {
			ob::log::write ERROR {do_map_bf_class_to_account - $msg}
			err_bind "$msg"
			return 0
		}

		inf_close_stmt $stmt	
	
	} elseif {$bf_acct_id != "" && $old_acct_id == ""} { 

		# Insert mapping 

		ob_log::write INFO {do_map_bf_class_to_account:: insert mapping for ev_class_id=$class_id to account} 

		set sql [subst {
			insert into tBFAcctClassMap
				(bf_acct_id, ev_class_id)
			values 
				(?,?)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $bf_acct_id $class_id]} msg]} {
			ob::log::write ERROR {do_map_bf_class_to_account - $msg}
			err_bind "$msg"
			return 0
		}

		inf_close_stmt $stmt
	
	} elseif {$bf_acct_id != "" && $old_acct_id != "" && ($bf_acct_id != $old_acct_id)} { 

		# Update mapping 
		
		ob_log::write INFO {do_map_bf_class_to_account:: update mapping for ev_class_id=$class_id to account} 

		set sql [subst {
			update
				tBFAcctClassMap
			set
				bf_acct_id = ?
			where
				ev_class_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $bf_acct_id $class_id]} msg]} {
			ob::log::write ERROR {do_map_bf_class_to_account - $msg}
			err_bind "$msg"
			return 0
		}	

		inf_close_stmt $stmt	
	} 
	
} 

#
# Associate an admin user with a particular Betfair Account
#
proc do_map_bf_admin_to_account {user_id bf_acct_id} { 

	global DB

	ob_log::write INFO {do_map_bf_admin_to_account user_id=$user_id bf_acct_id=$bf_acct_id} 

	# Permission check 
	if {![op_allowed MapBFAcctToAdmin]} {
		ob::log::write ERROR {do_map_bf_admin_to_account - missing MapBFAcctToAdmin permission}
		err_bind "No Permission to assign user to Betfair Account"
		return 
	} 

	# Retrieve old details 
	set sql [subst {
		select 
			*
		from
			tBFAcctAdminMap
		where
			user_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $user_id]} msg]} {
		ob::log::write ERROR {do_map_bf_admin_to_account - $msg}
		err_bind "$msg"
		return 0
	}

	inf_close_stmt $stmt	

	set nrows [db_get_nrows $res] 
	
	if {$nrows == 1} { 
		set old_user_id [db_get_col $res 0 user_id] 
		set old_acct_id [db_get_col $res 0 bf_acct_id] 
	} else { 
		set old_user_id ""
		set old_acct_id ""
	} 

	if {$bf_acct_id == "" && $old_acct_id != ""} { 
		
		# Delete mapping 
		
		ob_log::write INFO {do_map_bf_admin_to_account:: delete mapping for user_id=$user_id} 

		set sql [subst {
			delete from
				tBFAcctAdminMap
			where
				user_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $user_id]} msg]} {
			ob::log::write ERROR {do_map_bf_admin_to_account - $msg}
			err_bind "$msg"
			return 0
		}

		inf_close_stmt $stmt	
	
	} elseif {$bf_acct_id != "" && $old_acct_id == ""} { 

		# Insert mapping 

		ob_log::write INFO {do_map_bf_admin_to_account:: insert mapping for user_id=$user_id to account} 

		set sql [subst {
			insert into tBFAcctAdminMap
				(bf_acct_id, user_id)
			values 
				(?,?)
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $bf_acct_id $user_id]} msg]} {
			ob::log::write ERROR {do_map_bf_admin_to_account - $msg}
			err_bind "$msg"
			return 0
		}

		inf_close_stmt $stmt
	
	} elseif {$bf_acct_id != "" && $old_acct_id != "" && ($bf_acct_id != $old_acct_id)} { 

		# Update mapping 
		
		ob_log::write INFO {do_map_bf_admin_to_account:: update mapping for user_id=$user_id to account} 

		set sql [subst {
			update
				tBFAcctAdminMap
			set
				bf_acct_id = ?
			where
				user_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $bf_acct_id $user_id]} msg]} {
			ob::log::write ERROR {do_map_bf_admin_to_account - $msg}
			err_bind "$msg"
			return 0
		}	

		inf_close_stmt $stmt	
	} 
} 


#---------------------------------------------------------------------------
# Retrieve the active betfair account.
#
# Priority - admin user / class / global setting
#
# N.B. IF a bookmaker wishes to use multiple accounts this priority may 
# have to be configured depending on preferences. 
# -----------------------------------------------------------------------------
proc get_active_bf_account {ev_class_id} {

	global DB USERNAME

	#
	# Get Admin user_id
	#
	set sql [subst {
			select
				user_id
			from
				tAdminUser
			where
				username = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $USERNAME]} msg]} {
		ob::log::write ERROR {get_active_bf_account - $msg}
		err_bind "$msg"
		return
	}

	inf_close_stmt $stmt

	set user_id     [db_get_col $res 0 user_id]
	db_close $res

	#
	# Retrieve active mapped bf_acct_id for admin
	#
	set sql [subst {
		select
			bf_acct_id
		from
			tBFAcctAdminMap
		where
			user_id= ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $user_id]} msg]} {
		ob::log::write ERROR {get_active_bf_account - $msg}
		err_bind "$msg"
		return
	}

	inf_close_stmt $stmt
	set nrows [db_get_nrows $res]

	#
	# if no active account is mapped to admin then retrieve the mapped active 
	# bf_acct_id for corresponding openbet class
	#
	if {$nrows == 0} {
		db_close $res

		set sql [subst {
			select
				bf_acct_id
			from
				tBFAcctClassMap
			where
				ev_class_id= ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $ev_class_id]} msg]} {
			ob::log::write ERROR {get_active_bf_account - $msg}
			err_bind "$msg"
			return
		}

		inf_close_stmt $stmt
		set nrows [db_get_nrows $res]

		#
		# if no active account is mapped to admin or openbet class the retrieve
		# the active global betfair account
		#

		if {$nrows == 0} {
			db_close $res

			set sql [subst {
				select
					bf_acct_id
				from
					tBFConfig
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {set res [inf_exec_stmt $stmt]} msg]} {
				ob::log::write ERROR {get_active_bf_account - $msg}
				err_bind "$msg"
				return
			}
			inf_close_stmt $stmt
			set nrows [db_get_nrows $res]

			if {$nrows == 0} {
				err_bind "Could not retrieve active betfair account"
				db_close $res
				return ""
			}

		}
	}
	
	set bf_acct_id     [db_get_col $res 0 bf_acct_id]
	db_close $res

	return $bf_acct_id
}

# end of namespace
}
