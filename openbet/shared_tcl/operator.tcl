#-------------------------------------------------------------------
# $Id: operator.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
#
#-------------------------------------------------------------------
# Functions to validate operator login and retrieve operator details
#-------------------------------------------------------------------
#
# The Big Override Assumption:
#    All overrides of the same type are overridden by the same supervisors.
#

namespace eval OB_operator {

	namespace export init_operator
	namespace export operator_login
	namespace export reset_oper_login
	namespace export op_allowed
	namespace export get_oper_id
	namespace export get_auth_id
	namespace export get_authorised_opers
	namespace export op_override
	namespace export record_override
	namespace export get_opers_with_perm
	namespace export get_override_op
	namespace export get_override_parameter

	# Contains details about the current operator.
	#
	variable OPER

	# Contains details about overrides.
	#
	variable OVERRIDES

	# Contains details about permissions.
	#
	variable PERMISSIONS

	# Contains details about the override for the current operator.
	#
	variable OPER_OVERRIDES

	# An array storing the permissions for each user.
	# This is cached for a short period of time (60 secs).
	#
	variable OPER_PERMISSIONS
}

proc OB_operator::init_operator args {

	variable OVERRIDES
	variable PERMISSIONS

	array unset OVERRIDES
	array unset PERMISSIONS

	operator_prepare_queries

	foreach pair [OT_CfgGet OP_OVERRIDES [list]] {
		foreach {override permission} $pair {break}
		set OVERRIDES($override,permission) $permission
		set PERMISSIONS($permission,override) $override
	}
}


# Get the permission require to override.
#
#   override - The name of the override e.g. PRC_CHG.
#   returns  - The name of the permission e.g. PriceChangeOverride.
#              or "" if it cannot be overridden.
#
proc OB_operator::get_override_op {override} {

	variable OVERRIDES

	if {[info exists OVERRIDES($override,permission)]} {
		return $OVERRIDES($override,permission)
	}

	ob::log::write DEBUG {get_override_op: unknown override '$override'}

	return ""
}


# Get the over override require for a specific permission.
# If you're using this, you probably shouldn't be.
#
#   permission - The permissing e.g. PriceChangeOverride.
#   returns    - The override e.g. PRC_CHG, or empty string.
#
proc OB_operator::get_permission_override {permission} {
	variable PERMISSIONS

	if {[info exists PERMISSIONS($permission,override)]} {
		return $PERMISSIONS($permission,override)
	}

	ob::log::write DEBUG {get_permission_override: permission without override '$permission'}

	return ""
}


proc OB_operator::operator_prepare_queries args {

	db_store_qry op_login {
		execute procedure pAdminLogin(
			p_username  = ?,
			p_password  = ?,
			p_login_uid = ?,
			p_pwd_expires = ?
		)
	}

	db_store_qry get_admin_user_id {
		select user_id
		from tAdminUser
		where status = "A"
		and   username = ?
	}

	db_store_qry get_admin_names {
	    	select username, fname, lname
	    	from tAdminUser
	    	where username in (?,?,?,?,?,?,?,?,?,?)
	}

	db_store_qry op_permissions {
		select uo.action
		from   tAdminUserOp uo, tAdminOp o
		where  uo.action = o.action
		and    o.type    = ?
		and    user_id   = ?

		union

		select o.action
		from tAdminUserGroup aug, tAdminGroupOp ago, tAdminOp o
		where o.type = ?
		and   aug.user_id = ?
		and   aug.group_id = ago.group_id
		and   ago.action = o.action

		union

		select
			o.action
		from
			tAdminPosnGroup apg,
			tAdminGroupOp ago,
			tAdminOp o,
			tAdminUser u
		where
			o.type = ?
		and
			u.user_id = ?
		and
			apg.group_id = ago.group_id
		and
			apg.position_id = u.position_id
		and
			ago.action = o.action
	} 300

	db_store_qry authorised_opers {
		select
				u.username
		from
				tAdminUser u,
				tAdminUserOp o
		where
				u.user_id = o.user_id
		and     u.status = "A"
		and     o.action = ?

		union

		select
				u.username
		from
				tAdminUser u,
				tAdminGroupOp ago,
				tAdminUserGroup aug
		where
				u.user_id = aug.user_id
		and     aug.group_id = ago.group_id
		and     u.status = "A"
		and     ago.action = ?

		union

		select
			u.username
		from
			tAdminUser u,
			tAdminGroupOp ago,
			tAdminPosnGroup apg
		where
			u.position_id = apg.position_id
		and
			apg.group_id = ago.group_id
		and
			u.status = "A"
		and
			ago.action = ?
		order by 1
	} 300

	db_store_qry ins_override {
		execute procedure pInsOverride(
			p_cust_id = ?,
			p_oper_id = ?,
			p_override_by = ?,
			p_action = ?,
			p_call_id = ?,
			p_ref_id = ?,
			p_ref_key = ?,
			p_leg_no = ?,
			p_part_no = ?,
			p_reason = ?
		)
	}

	db_store_qry gen_login_uid {
		execute procedure pGenAdminLoginUID()
	}

	db_store_qry set_global_admin_user {
		execute procedure pSetGAdminUser(
			p_admin_id = ?
		)
	}

	db_store_qry get_cust_segment {
		select
			code
		from
			tCustomerReg
		where
			cust_id = ?
	}

}

proc OB_operator::reset_oper_login args {

	variable OPER
	variable OPER_OVERRIDES

	array unset OPER
	array unset OPER_OVERRIDES

}




# Attempt an operator login.
#
#
#          [list $OPER(auth_id) permission_1 permission_2 ...] - OK
#          -1 - Need to request further authorisation
#
proc OB_operator::operator_login {type} {

	variable OPER

	reset_oper_login

	set OPER(type)    $type
	set OPER(id)      [reqGetArg oper_id]
	set OPER(perms)   [list]

	#
	# username and password only needed for initial login or
	# if overriding restrictions
	#
	set username [reqGetArg oper_uname]

	if {[OT_CfgGetTrue CONVERT_ADMIN_HASHES]} {
		# Changes the hash in tAdminUsers to be a SHA-1 hash. Shouldn't
		# require handling of returns, as the password is checked later.
		convert_admin_password_hash $username [reqGetArg oper_pwd]
	}

	set salt_resp [get_admin_salt $username]
	set salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set salt ""
	}

	set password [encrypt_admin_password [reqGetArg oper_pwd] $salt]

	#
	# Log in
	#
	if {$username=="" && $OPER(id)==""} {
		error "Must enter both username and password"
	}

	if {$username != "" && [reqGetArg no_pwd] != "Y"} {
		if {[catch {set rs [db_exec_qry gen_login_uid]} msg] || \
			[db_get_nrows $rs] != 1} {
			error "Failed to generate admin login uid"
		} else {

			set login_uid [db_get_coln $rs 0 0]
		}
		if {[OT_CfgGet PWD_SECURITY_CHECK 0]} {
			set rs [db_exec_qry op_login $username $password $login_uid Y]
		} else {
			set rs [db_exec_qry op_login $username $password $login_uid N]
		}
		set OPER(auth_id) [db_get_coln $rs 0 0]
		db_close $rs
	} else {
		if {[reqGetArg no_pwd] == "Y"} {

			set rs [db_exec_qry get_admin_user_id $username]
			set nrows [db_get_nrows $rs]

			if {$nrows != 1} {
				db_close $rs
				error "No such user: $username"
			}

			set OPER(auth_id) [db_get_coln $rs 0 0]
			db_close $rs
		} else {
			set OPER(auth_id) $OPER(id)
		}
	}

	if {$OPER(id) == "" && $OPER(auth_id) != ""} {
		set OPER(id) $OPER(auth_id)
	}

	if {$OPER(id) != ""} {
		set rs [db_exec_qry set_global_admin_user $OPER(id)]
		db_close $rs

		set OPER(perms) [_get_oper_permissions $OPER(type) $OPER(id)]
	}


	if {[catch {
		_chk_oper_overrides [reqGetArg -unsafe overrides]
	} msg]} {
		err_add $msg
	}

	if {[err_numerrs] > 0} {
		set ret -1
	} else {
		set ret [list $OPER(auth_id)]
		set ret [concat $ret $OPER(perms)]
	}

	return $ret
}


# See if operator has permission to override specified errors.
#
#   overrides - A list of overrides.
#   throws    - An error if the overrides are invalid.
#
proc OB_operator::_chk_oper_overrides {overrides} {

	variable OPER_OVERRIDES

	array unset OPER_OVERRIDES

	set OPER_OVERRIDES(overrides) [list]

	foreach item  $overrides {
		set override [lindex $item 0]
		set parameter [lindex $item 1]

		switch [llength $item] {
			2 {
				# This doesn't appear to get used, but just in case this code
				# will remain here and be backwards compatible.
				set username [reqGetArg oper_uname]
				set password [reqGetArg oper_pwd]
			}
			4 {
				set username [lindex $item 2]
				set password [lindex $item 3]
			}
			default {
				error "Expected 2 or 4 items"
			}
		}

		add_oper_override $override $parameter $username $password
	}
}



# Add a new operator override.
#
#   override  - The name of the override e.g. PRC_CHG.
#   parameter - The parameter of the overide e.g. 0,bets,0
#   username  - The authorisor's username
#   password  - The authorizor's password.
#   throws    - Error if the authorisor fails to validate.
#
proc OB_operator::add_oper_override {override parameter username password} {

	variable OPER
	variable OPER_OVERRIDES

	ob::log::write DEV {Adding override=$override, parameter=$parameter, username=$username}

	set permission [get_override_op $override]

	if {$permission == ""} {
		error "Cannot override '$override', no suitable permission"
	}

	if {![op_allowed $permission]} {

		if {$username == ""} {
			if {[OT_CfgGet OVERRIDE_CODES 0]} {
				error "Override code for override '$override' was incorrect"
			} else {
				error "Username for override '$override' must be specified"
			}
		}

		if {![_is_auto_authorizable $override] &&
			$password == ""} {
			error "Override '$override' is not auto-authorizable, \
				password must be specified"
		}

		# Password may be blank, this validates the user.
		#
		_get_supervisor $username $password SUPERVISOR

		set user_id $SUPERVISOR(user_id)

		if {[lsearch [_get_oper_permissions $OPER(type) $user_id] $permission] == -1} {
			error "Overriding operator '$username' doesn't have \
				permission '$permission'"
		}
	} else {
		set user_id $OPER(id)
	}


	lappend OPER_OVERRIDES(overrides) $override

	set OPER_OVERRIDES($override,override)  $override
	lappend OPER_OVERRIDES($override,parameters) $parameter
	set OPER_OVERRIDES($override,username)  $username
	set OPER_OVERRIDES($override,password)  $password
	set OPER_OVERRIDES($override,user_id)   $user_id
}


# Get a list of permissions for an operator.
#
#   type    - The type of user e.g. TEL.
#   user_id - The user's ID.
#   returns - A list of the user's permissions.
#
proc OB_operator::_get_oper_permissions {type user_id} {

	variable OPER
	variable OPER_PERMISSIONS

	# We need to update the users permissions if they've not
	# been updated this request.
	#
	if {
		![info exists OPER_PERMISSIONS($type,$user_id,permissions)]
		||
		(
			$OPER_PERMISSIONS($type,$user_id,last_req_id) != [reqGetId]
			&&
			$OPER_PERMISSIONS($type,$user_id,last_updated) < [clock scan "now -60 seconds"]
		)
	} {
		set OPER_PERMISSIONS($type,$user_id,last_req_id)  [reqGetId]
		set OPER_PERMISSIONS($type,$user_id,last_updated) [clock scan now]

		if {[catch {
			set rs [db_exec_qry op_permissions \
				$type \
				$user_id \
				$type \
				$user_id \
				$type \
				$user_id]
		} msg]} {
			ob::log::write ERROR {Failed to get user permissions for \
				user_id=$user_id:$msg}
			return [list]
		}

		set nrows [db_get_nrows $rs]

		set OPER_PERMISSIONS($type,$user_id,permissions) [list]

		for {set i 0} {$i < $nrows} {incr i} {
			lappend OPER_PERMISSIONS($type,$user_id,permissions) [db_get_col $rs $i action]
		}

		db_close $rs
	}

	return $OPER_PERMISSIONS($type,$user_id,permissions)
}


# Find out if we can do a specific operation.
#
#   op      - The permissions e.g. ChangeEvent
#   returns - Boolean.
#
proc OB_operator::op_allowed {op} {

	variable OPER

	if {[lsearch $OPER(perms) $op] >= 0} {
		return 1
	} else {
		return 0
	}
}


# Find out if an override is OK
#
#    override  - Name of the override.
#    returns   -  0 - Not OK to override.
#                 1 - OK to override.
#                -1 - OK to override, but require permission.
#
proc OB_operator::op_override {override {id -1}} {

	variable OPER
	variable OPER_OVERRIDES

	# Find out the permission required for this override.
	#
	set permission [get_override_op $override]


	# This is a quite acceptable.
	#
	if {$permission == ""} {
		ob::log::write DEBUG {op_override: no permission for '$override'}
		return 0
	}

	# If we're in retrospective mode, we want to override SUSP and START automatically.
	#
	if {($override == "SUSP" || $override == "START") && \
		([reqGetArg is_retrospective] || [reqGetArg referral] != 0)} {
		return 1
	}

	# Check to see if the override is declared by the client as something
	# that it needs to be overridden.
	#
	if {[lsearch $OPER_OVERRIDES(overrides) $override] == -1} {
		ob::log::write ERROR {op_override: override '$override'  \
			not declared, require confirmation}
		return -1
	}

	if {$id != -1 && [lsearch -exact [get_override_parameter $override] $id] < 0} {
		ob::log::write ERROR {op_override: override '$override' where id='$id' \
			not declared, require confirmation}
		return -1
	}

	# The operator may already have this permission.
	#
 	if {[op_allowed $permission]} {
 		return 1
 	}

	if {[_is_auto_authorizable $override]} {
		ob::log::write DEV {op_override: override '$override' is \
			auto-authorizable}
		return 1
	}

	# We must now know the user. This is a double check, and should have already
	# been done when the operator logs in.
	#
	if {[lsearch [_get_oper_permissions $OPER(type) [get_auth_id $override]] \
		$permission] == -1} {
		ob::log::write DEV {op_override: supervisor doesn't have override '$override'}
		return 0
	}

	return 1
}

# Warning! This procedure doesn't not return a single paramter like you
# might expect. It returns a list.
#
#   override - The override we're interested in, e.g. PRC_CHG.
#   returns  - A *list* parameters, or the empty string.
#
proc OB_operator::get_override_parameter {override} {

	variable OPER_OVERRIDES

	if {[info exists OPER_OVERRIDES($override,parameters)]} {
		return $OPER_OVERRIDES($override,parameters)
	}

	return ""
}


# Get the supervisors details. Just the user ID is currently returned.
#
# Example:
#   _get_supervisor $username $password SUPERVISOR
#   puts $SUPERVISOR(user_id)
#
#   username   - The supervisor's username.
#   password   - The password.
#   supervisor - The name of an array to populate with supervisor's
#                details. e.g. user_id
#   throws     - DB errors, should be wrapped in a catch block.
#
proc OB_operator::_get_supervisor {username password supervisor} {

	variable OPER
	upvar 1 $supervisor SUPERVISOR

	array unset SUPERVISOR

	# Make sure we don't repeatedly log the user id, we store the
	# user_id here. The index includes the password, so that
	# we don't get an auto followed by a full and just use the cached
	# value.
	#
	if {[info exists OPER(supervisor,$username,$password,user_id)]} {
		set SUPERVISOR(user_id) $OPER(supervisor,$username,$password,user_id)
		return
	}

	if {$password != ""} {
		set rs [db_exec_qry gen_login_uid]
		set login_uid [db_get_coln $rs 0 0]
		db_close $rs

		set salt_resp [get_admin_salt $username]
		set salt [lindex $salt_resp 1]
		if {[lindex $salt_resp 0] == "ERROR"} {
			set salt ""
		}

		set password_hash [encrypt_admin_password $password $salt]

		set rs [db_exec_qry op_login $username $password_hash \
			$login_uid "TB"]
		set user_id [db_get_coln $rs 0 0]
		db_close $rs
	} else {
		set rs [db_exec_qry get_admin_user_id $username]
		set user_id [db_get_col $rs 0 user_id]
		db_close $rs
	}

	set SUPERVISOR(user_id) $user_id
	set OPER(supervisor,$username,$password,user_id) $user_id
}


# Can we automatically override permission with just a username.
#
#   override - The name of the override e.g. PRC_CHG.
#   returns  - If it is automatically authorizable.
#
proc OB_operator::_is_auto_authorizable {override} {

	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		return 1
	}

	if {[lsearch [OT_CfgGet NP_OP_OVERRIDES] $override] >= 0} {
		return 1
	}

	return 0
}


proc OB_operator::get_oper_id args {
	variable OPER

	if {![info exists OPER(id)]} {
		return [reqGetArg oper_id]
	}

	return $OPER(id)
}


# Get the authorizing user's (the supervisor's) user_id for a specific override.
#
#   override - The name of the override e.g. PRC_CHG.
#   returns  - The authorizor's user_id.
#
proc OB_operator::get_auth_id {override} {

	variable OPER
	variable OPER_OVERRIDES

	if {[info exists OPER_OVERRIDES($override,user_id)]} {
		return $OPER_OVERRIDES($override,user_id)
	}


	if {[info exists OPER(auth_id)]} {
		return $OPER(auth_id)
	}

	return ""
}


# Get a list of operators?
#
proc OB_operator::get_op_names {uname_list} {

    set admin_details [list]

	# Do the server calls in batches of 10 for efficiency
	while {[llength $uname_list] > 0} {

		set unames     [lrange $uname_list 0 9]
		set uname_list [lrange $uname_list 10 end]

		for {set padding [llength $unames]} {$padding < 10} {incr padding} {
			lappend unames -
		}

		if {[catch {set rs [eval "db_exec_qry get_admin_names $unames"]} msg]} {
			ob::log::write ERROR {unable to retrieve username details: $msg }
			catch {db_close $rs}
			error "Error executing get_admin_details query"
		}

		for {set row_idx 0} {$row_idx < [db_get_nrows $rs]} {incr row_idx} {
			set username [db_get_col $rs $row_idx username]
			set fname    [db_get_col $rs $row_idx fname]
			set lname    [db_get_col $rs $row_idx lname]
			lappend admin_details [list $username $fname $lname]
		}

		catch {db_close $rs}
	}
	return $admin_details
}


# Get list of operator who are capable to doing the permission.
#
#   perm    - The permissions e.g PriceChange.
#   returns - A list of the username's of authorized operators.
#
proc OB_operator::get_opers_with_perm {perm} {


	set rs [db_exec_qry authorised_opers $perm $perm $perm]
	set nrows [db_get_nrows $rs]
	set opers [list]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend opers [db_get_col $rs $i username]
	}

	return $opers
}


# Given a list of restrictions, bring back usernames of all operators who can
# override them all
#
#   r_list  - A list of overrides e.g. [list PRC_CHG STK_HIGH].
#   returns - A list of operators authorized to do all of the operation.
#
proc OB_operator::get_authorised_opers {r_list} {

	variable OVERRIDES

	ob::log::write DEV {get_authorised_opers with $r_list}

	set users ""
	set len [llength $r_list]
	for {set i 0} {$i < $len} {incr i} {
		set r [lindex $r_list $i]
		if {[lsearch -exact $r_list $r] != $i} {
			#
			# Not the first occurrence of restriction
			#
			continue
		}
		if {![info exists OVERRIDES($r,permission)]} {
			ob::log::write WARNING {No permission configured for override}
			return [list]
		}
		set op $OVERRIDES($r,permission)
		if {[catch {set rs [db_exec_qry authorised_opers $op $op $op]} msg]} {
			ob::log::write ERROR {Error getting authorised operators: $msg}
			return  ""
		}
		set nrows [db_get_nrows $rs]
		ob::log::write DEV {Found $nrows operators with $r}
		if {$i==0} {
			for {set j 0} {$j < $nrows} {incr j} {
				lappend users [db_get_col $rs $j username]
			}
		} else {
			set new_users   [list]
			for {set j 0} {$j < $nrows} {incr j} {
				set idx [lsearch -exact $users [db_get_col $rs $j username]]
				if {$idx >= 0} {
					lappend new_users   [lindex $users $idx]
				}
			}
			set users   $new_users
		}
		db_close $rs
	}
	return $users
}


# Record that the customer has had an override done.
#
#   cust_id   - The customer's ID.
#   override  - The specific override.
#   reason    - The reason for the override.
#
proc OB_operator::record_override {cust_id permission {reason {}} {ref_id {}} {ref_key {}} {leg_no {}} {part_no {}} {call_id {}}} {

	variable OPER

	ob::log::write DEBUG {[info level [info level]]}

	if {$cust_id == ""} {
		#
		# Override not related to customer
		#
		if {[lsearch -exact $OPER(perms) $override]>=0} {
			return ""
		} else {
			return "You do not have the $override permission"
		}
	}

	set override [get_permission_override $permission]

	# We need to find out who authorized this. This may be the current operator.
	#
	set user_id [get_auth_id $override]


	# This is a sanity check, this should have been checked already, but there no
	# harm in checking again, permissions are cached.
	#
	if {[lsearch [_get_oper_permissions $OPER(type) $user_id] $permission] == -1} {
		error "Operator doesn't have permission"
	}

	if {[catch {db_exec_qry ins_override $cust_id $OPER(id) $user_id $permission $call_id $ref_id $ref_key $leg_no $part_no $reason} msg]} {
		ob::log::write ERROR {An error occurred while recording override: $msg}
		return $msg
	}

	if {[catch {set rs [db_exec_qry get_cust_segment $cust_id]} msg]} {
		ob::log::write ERROR {An error occurred while getting customer segment during recording override: $msg}
		return $msg
	}
	if {[db_get_nrows $rs]!=1} {
		ob::log::write ERROR {Too many rows returned when getting customer segment: [db_get_nrows $rs]}
		return "Too many rows returned"
	}
	set cust_reg_code [db_get_coln $rs 0 0]
	db_close $rs

	if {[OT_CfgGet MONITOR 0]} {
		MONITOR::send_override\
			$cust_id\
			$cust_reg_code\
			$OPER(id)\
			$user_id\
			$permission\
			[MONITOR::datetime_now]\
			$call_id\
			$leg_no\
			$part_no
	}

	return ""
}
