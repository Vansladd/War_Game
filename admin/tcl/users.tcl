# ==============================================================
# $Id: users.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::USERS {

asSetAct ADMIN::USERS::GoUsers                [namespace code go_user_list]
asSetAct ADMIN::USERS::GoUser                 [namespace code go_user]
asSetAct ADMIN::USERS::DoUser                 [namespace code do_user]
asSetAct ADMIN::USERS::DoUserSearch           [namespace code do_user_search]
asSetAct ADMIN::USERS::GoPassword             [namespace code go_password]
asSetAct ADMIN::USERS::DoPassword             [namespace code do_password]
asSetAct ADMIN::USERS::GoGroup                [namespace code go_group]
asSetAct ADMIN::USERS::DoGroup                [namespace code do_group]
asSetAct ADMIN::USERS::GoPosition             [namespace code go_position]
asSetAct ADMIN::USERS::DoPosition             [namespace code do_position]
asSetAct ADMIN::USERS::GoPositionHierarchy    [namespace code go_position_hierarchy]
asSetAct ADMIN::USERS::DoActivateSuspendUsers [namespace code do_activate_suspend_users]

#
# ----------------------------------------------------------------------------
# Go to user list
# ----------------------------------------------------------------------------
#
proc go_user_list args {

	global DB USERNAME AU AG AP

	if {[has_view_rights] != 1} {
		err_bind "You do not have the correct permission to view this"
		tpSetVar NumUsers 0
		tpSetVar hasRights 0
		asPlayFile -nocache user_list.html
		return
	}

	tpSetVar hasRights 1

	set admin_group [reqGetArg AdminGroup]

	if {$admin_group != ""} {
		set where [subst {
			where exists (
				select 'Y'
				from tAdminUserGroup g
				where g.user_id = a.user_id
				and   g.group_id = $admin_group
			)
		}]
		tpBindString AdminGroup $admin_group
	} else {
		set where ""
	}

	set sql [subst {
		select
			a.user_id,
			a.username,
			a.status,
			a.logged_in,
			a.login_loc,
			a.login_time
		from
			tAdminUser a
			$where
		order by
			3 asc, 2 asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {

		set user_id [db_get_col $res $r user_id]

		set AU($r,user_id)    $user_id
		set AU($r,username)   [db_get_col $res $r username]
		set AU($r,status)     [db_get_col $res $r status]
		set AU($r,logged_in)  [db_get_col $res $r logged_in]
		set AU($r,login_loc)  [db_get_col $res $r login_loc]
		set AU($r,login_time) [db_get_col $res $r login_time]

		if {$user_id < 0} {
			set desc "special"
		} else {
			set desc ""
		}

		set AU($r,desc) $desc
	}

	db_close $res

	tpSetVar NumUsers $n_rows

	tpBindVar UserId    AU user_id    user_idx
	tpBindVar Username  AU username   user_idx
	tpBindVar Status    AU status     user_idx
	tpBindVar Desc      AU desc       user_idx
	tpBindVar LoggedIn  AU logged_in  user_idx
	tpBindVar LoginTime AU login_time user_idx
	tpBindVar LoginLoc  AU login_loc  user_idx

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		#get list of positions if enabled.
		getPositions
	}
	if {[OT_CfgGet FUNC_ADMIN_USER_SEARCH 0]} {
		getPermissions
	}
	if {[OT_CfgGet USE_ADMIN_USER_OP 0]==0} {
		getGroups
	}

	if {[OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToAdmin]} {
		ADMIN::BETFAIR_ACCT::bind_bf_accounts
	}

	asPlayFile -nocache user_list.html

	catch {unset AU}
	catch {unset AG}
	catch {unset AP}
}


#
# ----------------------------------------------------------------------------
# Searches admin users.
# ----------------------------------------------------------------------------
#
proc do_user_search {} {
	global DB AU AP AG AO

	if {[has_view_rights] != 1} {
		err_bind "You do not have the correct permission to view this"
		tpSetVar NumUsers 0
		tpSetVar hasRights 0
		asPlayFile -nocache user_list.html
		return
	}

	tpSetVar hasRights 1

	set where [list]

	if {[string length [set name [reqGetArg username]]] > 0} {
		if {[reqGetArg exact] == "Y"} {
			set op =
		} else {
			set op like
			append name %
		}
		if {[reqGetArg ignorecase] == "Y"} {
			lappend where "upper(a.username) $op upper(\"${name}\")"
		} else {
			lappend where "a.username $op \"${name}\""
		}
	}

	if {[string length [set fname [reqGetArg fname]]] > 0} {
		if {[reqGetArg fname_exact] == "Y"} {
			set op =
		} else {
			set op like
			append fname %
		}
		if {[reqGetArg fname_ignorecase] == "Y"} {
			lappend where "upper(a.fname) $op upper(\"${fname}\")"
		} else {
			lappend where "a.fname $op \"${fname}\""
		}
	}

	if {[string length [set lname [reqGetArg lname]]] > 0} {
		if {[reqGetArg lname_exact] == "Y"} {
			set op =
		} else {
			set op like
			append lname %
		}
		if {[reqGetArg lname_ignorecase] == "Y"} {
			lappend where "upper(a.lname) $op upper(\"${lname}\")"
		} else {
			lappend where "a.lname $op \"${lname}\""
		}
	}

	if {[string length [set status [reqGetArg status]]] > 0} {
		lappend where "a.status = \"${status}\""
	} else {
		# include deleted users in search if deleted_users is checked
		if {[reqGetArg deleted_users] != "on"} {
			lappend where "a.status != \"X\""
		}
	}

	if {[string length [set logged_in [reqGetArg loggedIn]]] > 0} {
		lappend where "a.logged_in = \"${logged_in}\""
	}

	if {[string length [set group [reqGetArg group]]] > 0} {
		lappend where "exists (select 'Y' from tAdminUserGroup g where g.user_id = a.user_id and g.group_id = ${group})"
	}

	if {[string length [set position [reqGetArg position]]] > 0} {
		if {$position == "-1"} {
			lappend where "a.position_id is null"
		} else {
			lappend where "a.position_id = ${position}"
		}
	}

	if {[string length [set permission [reqGetArg permission]]] > 0} {
		lappend where [subst {
			(exists (
			select "Y"
			from   tAdminUserOp uo
			where  uo.user_id = a.user_id
			and    uo.action = \"$permission\"
			)
			or exists (
			select "Y"
			from   tAdminUserGroup ug,
				   tAdminGroupOp gop
			where  ug.user_id = a.user_id and
				   ug.group_id = gop.group_id and
				   gop.action = \"$permission\"
			)

			or exists (
			select "Y"
			from   tAdminPosnGroup pg,
				   tAdminGroupOp gop,
				   tAdminUser u
			where  u.user_id = a.user_id and
				   u.position_id = pg.position_id and
				   pg.group_id = gop.group_id and
				   gop.action = \"$permission\"
			))
		}]
	}

	if {$where != ""} {set where "and [join $where { and }]"}

	set override ""
	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		set override "a.override_code,"

	}

	set sql [subst {
		select
			a.user_id,
			a.username,
			a.fname,
			a.lname,
			a.status,
			a.logged_in,
			a.login_loc,
			a.login_time,
			$override
			case when p.position_name is null then "--ROOT--" else p.position_name end position_name
		from
			tAdminUser a,
			outer tAdminPosition p
		where
			status != "X" and
			p.position_id=a.position_id
			$where
		order by
			a.status, a.username
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {

		set user_id [db_get_col $res $r user_id]

		set AU($r,user_id)    $user_id
		set AU($r,username)    [db_get_col $res $r username]
		set AU($r,fname)       [db_get_col $res $r fname]
		set AU($r,lname)       [db_get_col $res $r lname]
		set AU($r,status)      [db_get_col $res $r status]
		set AU($r,logged_in)   [db_get_col $res $r logged_in]
		set AU($r,login_loc)   [db_get_col $res $r login_loc]
		set AU($r,login_time)  [db_get_col $res $r login_time]
		set AU($r,position)    [db_get_col $res $r position_name]

		if {[OT_CfgGet OVERRIDE_CODES 0]} {
			set AU($r,override_code) [db_get_col $res $r override_code]
		}

		if {$user_id < 0} {
			set desc "special"
		} else {
			set desc ""
		}

		set AU($r,desc) $desc
	}

	db_close $res

	tpSetVar NumUsers $n_rows

	tpBindVar UserId    AU user_id    user_idx
	tpBindVar Username  AU username   user_idx
	tpBindVar Fname     AU fname      user_idx
	tpBindVar Lname     AU lname      user_idx
	tpBindVar Status    AU status     user_idx
	tpBindVar Desc      AU desc       user_idx
	tpBindVar LoggedIn  AU logged_in  user_idx
	tpBindVar LoginTime AU login_time user_idx
	tpBindVar LoginLoc  AU login_loc  user_idx
	tpBindVar Position  AU position   user_idx

	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		tpBindVar OverrideCode AU override_code user_idx
	}

	# get info for search box
	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		#get list of positions if enabled.
		getPositions
	}
	getGroups
	getPermissions

	asPlayFile -nocache user_search.html

	catch {unset AU}
	catch {unset AP}
	catch {unset AG}
	catch {unset AO}
}

#
# ----------------------------------------------------------------------------
# Find out if the logged-in user can assign permissions
# ----------------------------------------------------------------------------
#
proc has_assign_rights {} {

	return [tpGetVar PERM_AssignRights 0]
}


#
# ----------------------------------------------------------------------------
# Find out if the user logged-in can view users
# ----------------------------------------------------------------------------
#
proc has_view_rights {} {
	return [expr {[op_allowed ViewRights] || [tpGetVar PERM_AssignRights 0]}]
}

# Can delete if user has assign rights
proc has_delete_rights {} {
	return [has_assign_rights]
}


#
# ----------------------------------------------------------------------------
# Go to individual user detail
# ----------------------------------------------------------------------------
#
proc go_user {{user_id ""} {position_id ""}} {

	global DB AO AG UN USERNAME AP THIRD_PARTIES

	if {[reqGetArg SubmitName]=="Viewusers"} {
		go_user_list
		return
	}

	set CanAssignRights [has_assign_rights]

	# set user_id [reqGetArg UserId] only if it has not already been set

	if {$user_id == ""} {
		set user_id [reqGetArg UserId]
	}

	tpSetVar UserId $user_id

	set has_user_op 0

	if {$user_id != ""} {

	set select ""
	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		set select ",a.override_code"
	}

		# viewing existing user
		set sql [subst {
			select first 1
				a.user_id,
				a.username,
				a.fname,
				a.lname,
				a.email,
				a.status,
				a.logged_in,
				a.login_time,
				a.login_loc,
				a.agent_id,
				a.phone_switch,
				f1.flag_name,
				o.action,
				f1.flag_value as third_party,
				f2.flag_value as is_automated
				$select
			from
				tAdminUser a,
				outer tAdminUserOp o,
				outer tAdminUserFlag f1,
				outer tAdminUserFlag f2
			where
				a.user_id = ?
			and f1.user_id = a.user_id
			and f1.flag_name like "3RDPARTY_%"
			and a.user_id = o.user_id
			and f2.user_id = a.user_id
			and f2.flag_name = 'IS_AUTOMATED'
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $user_id]
		inf_close_stmt $stmt

		set logged_in [db_get_col $res 0 logged_in]

		tpSetVar LoggedIn $logged_in

		tpBindString UserId      [db_get_col $res 0 user_id]
		tpBindString Username    [db_get_col $res 0 username]
		tpBindString Fname       [db_get_col $res 0 fname]
		tpBindString Lname       [db_get_col $res 0 lname]
		tpBindString Email       [db_get_col $res 0 email]
		tpBindString Status      [db_get_col $res 0 status]
		tpBindString ThirdParty  [db_get_col $res 0 flag_name]
		tpBindString AgentId     [db_get_col $res 0 agent_id]
		tpBindString PhoneSwitch [db_get_col $res 0 phone_switch]
		tpBindString LoggedIn    $logged_in
		tpBindString LoginTime   [db_get_col $res 0 login_time]
		tpBindString LoginLoc    [db_get_col $res 0 login_loc]
		tpSetVar IsAutomated     [db_get_col $res 0 is_automated]

		if {[OT_CfgGet OVERRIDE_CODES 0]} {
			tpBindString OverrideCode [db_get_col $res 0 override_code]
		}

		if {[db_get_col $res 0 action] != ""} {
			set has_user_op 1
		}

		db_close $res

		tpSetVar opAdd 0

		if {[OT_CfgGet BF_ACTIVE 0] && [op_allowed MapBFAcctToAdmin]} {
			ADMIN::BETFAIR_ACCT::get_mapped_bf_acct $user_id "admin"
		}

	} else {
		# adding new user
		set sql_users {
			select
				username,
				user_id
			from
				tAdminUser
			order by
				1
		}

		set stmt_u [inf_prep_sql $DB $sql_users]
		set res_u  [inf_exec_stmt $stmt_u]
		inf_close_stmt $stmt_u

		set n_users [db_get_nrows $res_u]

		for {set i 0} {$i < $n_users} {incr i} {
			set UN($i,username) [db_get_col $res_u $i username]
			set UN($i,user_id)  [db_get_col $res_u $i user_id]
		}

		db_close $res_u

		tpBindVar UserName UN username user_idx
		tpBindVar UserId   UN user_id  user_idx

		tpSetVar NumUsers $n_users

		tpSetVar opAdd 1

	}

	if {[OT_CfgGet USE_ADMIN_USER_OP 0]==0 && [reqGetArg AdminUserOp]=="" && $has_user_op==0 } {
		tpSetVar AdminUserOp 0
	} else {
		tpSetVar AdminUserOp 1
	}

	if {[tpGetVar AdminUserOp 0]==0 || [OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {

		#
		# Get groups and membership details
		#
		set sql {
			select
				g.group_id,
				g.group_name,
				case when ug.user_id is not null then "CHECKED" else "" end status
			from
				tAdminGroup g,
				outer tAdminUserGroup ug
			where
				g.group_id = ug.group_id and
				ug.user_id = ?
			order by
				g.group_name
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $user_id]
		inf_close_stmt $stmt

		set n_rows  [db_get_nrows $res]

		set has_group 0

		for {set r 0} {$r < $n_rows} {incr r} {
			set AG($r,group_id)   [db_get_col $res $r group_id]
			set AG($r,group_name) [db_get_col $res $r group_name]
			set AG($r,selected)   [db_get_col $res $r status]
			if {$AG($r,selected) != ""} {
				set has_group 1
			}
		}

		tpBindVar GroupId       AG group_id   group_idx
		tpBindVar GroupName     AG group_name group_idx
		tpBindVar GroupSelected AG selected   group_idx

		tpSetVar NumGroups $n_rows
		tpSetVar HasGroup  $has_group

	}
	if {[tpGetVar AdminUserOp 0]==1} {
	# -------------------------------------------------------------------
	# If permissions are not done by groups
	# -------------------------------------------------------------------

		set sql [subst {
			select
				o.action,
				o.desc,
				t.type,
				t.desc type_desc,
				case when r.user_id is not null then 'CHECKED' else '' end status,
				NVL(t.disporder,0) t_disporder,
				NVL(o.disporder,0) o_disporder
			from
				tAdminOp o,
				tAdminOpType t,
				outer tAdminUserOp r
			where
				r.user_id = ? and
				o.action = r.action and
				o.type = t.type and
				NVL(o.disporder,0) >= 0
			order by
				t_disporder,
				t.type,
				o_disporder
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $user_id]
		inf_close_stmt $stmt

		set n_rows  [db_get_nrows $res]

		set n_perms -1
		set n_grps  -1

		set c_grp ""

		for {set r 0} {$r < $n_rows} {incr r} {

			if {[set grp [db_get_col $res $r type]] != $c_grp} {

				incr n_grps
				set c_grp $grp
				set n_perms 0
				set AO($n_grps,op_grp_name) [db_get_col $res $r type_desc]
			}

			set AO($n_grps,$n_perms,op)          [db_get_col $res $r action]
			set AO($n_grps,$n_perms,op_desc)     [db_get_col $res $r desc]
			set AO($n_grps,$n_perms,op_selected) [db_get_col $res $r status]

			set AO($n_grps,n_perms) [incr n_perms]
		}

		if {$n_rows} {
			incr n_grps
		}

		db_close $res


		tpSetVar NumPermGrps     $n_grps

		tpBindVar AdminOpGrp  AO op_grp_name grp_idx
		tpBindVar AdminOp     AO op          grp_idx perm_idx
		tpBindVar AdminOpDesc AO op_desc     grp_idx perm_idx
		tpBindVar OpSelected  AO op_selected grp_idx perm_idx

	}

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		# get list of positions
		if {[tpGetVar opAdd 0]==1} {

			# if posid does not exist or posid is empty string
			if {![info exists position_id] || $position_id == ""} {
				set position_id 0
			}
			set sql [subst {
				select
				  	position_id,
					position_name,
					case when position_id = $position_id
					then 'selected' else '' end as status
				from
					tAdminPosition
				order by
					position_name
			}]
		} else {
			set sql [subst {
				select
					position_id,
					position_name,
					case when position_id = (
						select
					 	 	position_id
						from
						  	tAdminUser
						where
						   	user_id = ?
					)
					then 'selected' else '' end as status
				from
					tAdminPosition
				order by
					position_name
			}]
	}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $user_id]
		inf_close_stmt $stmt

		set n_rows [db_get_nrows $res]
		for {set i 0} {$i < $n_rows} {incr i} {
			set AP($i,pos_id)           [db_get_col $res $i position_id]
			set AP($i,pos_name)         [db_get_col $res $i position_name]
			set AP($i,pos_selected)     [db_get_col $res $i status]

		}

		tpSetVar NumPositions $n_rows

		tpBindVar PosId       AP pos_id          pos_idx
		tpBindVar PosName     AP pos_name        pos_idx
		tpBindVar PosSelected AP pos_selected    pos_idx

		if {[tpGetVar opAdd] == 0} {
			#get groups associated with each position
			set sql [subst {
				select
					g.group_id,
					g.group_name,
					case when pg.position_id is not null then "1" else "0" end status
				from
					tAdminGroup g,
					outer tAdminPosnGroup pg
				where
					g.group_id = pg.group_id and
					pg.position_id = ?
				order by
				g.group_name
			}]
			set stmt [inf_prep_sql $DB $sql]

			for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
				set grp_res [inf_exec_stmt $stmt $AP($i,pos_id)]
				set grp_res_nrows [db_get_nrows $grp_res]
				for {set j 0} {$j < $grp_res_nrows} {incr j} {
					set AP($i,$j,pos_group_checked) [db_get_col $grp_res $j status]
				}
				db_close $grp_res
			}
			db_close $res

			tpBindVar PosGrpChecked AP pos_group_checked pos_idx pos_grp_idx
		}
	}

	tpSetVar NumThirdParties [ADMIN::THIRDPARTY::bind_third_parties THIRD_PARTIES description]

	tpSetVar CanAssignRights $CanAssignRights

	asPlayFile -nocache user.html

	catch {unset THIRD_PARTIES}
	catch {unset AO}
	catch {unset AG}
	catch {unset UN}
	catch {unset AP}

}


proc do_user args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "UserAdd"} {
		do_user_add
	} elseif {$act == "UpdPerms"} {
		if {[OT_CfgGet USE_ADMIN_USER_OP 0]==0 && [reqGetArg AdminUserOp]==""} {
			do_user_perms
		} else {
			do_user_perms_op
		}
	} elseif {$act == "UserAudit"} {
		reqSetArg AuditInfo AdminUserOp
		ADMIN::AUDIT::go_audit
	} elseif {$act == "GroupsAudit"} {
		reqSetArg AuditInfo AdminUserGroup
		ADMIN::AUDIT::go_audit
	} elseif {$act == "NoGroups"} {
		go_user "" ""
	} elseif {$act == "UserMod"} {
		do_user_mod
	} elseif {$act == "UserModPwd"} {
		do_user_mod_pwd
	} elseif {$act == "UserLogout"} {
		do_user_logout
	} elseif {$act == "Back"} {
		go_user_list
	} elseif {$act == "MapAdmin"} {
		ADMIN::BETFAIR_ACCT::do_map_bf_admin_to_account [reqGetArg UserId] [reqGetArg BF_Account]
		ADMIN::USERS::go_user "" ""
	} else {
		error "unexpected action: $act"
	}
}

proc do_user_add args {

	global DB USERNAME

	set username     [reqGetArg username]
	set fname        [reqGetArg fname]
	set lname        [reqGetArg lname]
	set pwd_1        [reqGetArg password_1]
	set pwd_2        [reqGetArg password_2]
	set user_email   [reqGetArg email]
	set status       [reqGetArg status]
	set third_party  [reqGetArg thirdparty]
	set agent_id     [reqGetArg agent_id]
	set phone_switch [reqGetArg phone_switch]
	set clone        [reqGetArg clone]
	set position_id  [reqGetArg position]
	set is_automated [reqGetArg is_automated]

	if {$is_automated == "on"} {
		set is_automated 1
	} else {
		set is_automated 0
	}

	# rebind some of the data in case we reload the page with errors
	tpBindString Username          $username
	tpBindString Fname             $fname
	tpBindString Lname             $lname
	tpBindString Status            $status
	tpBindString Clone             $clone
	tpBindString OverrideCode      [reqGetArg overridecode]

	set override ""
	set override_code ""
	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		set override_code [string toupper [reqGetArg overridecode]]
		set override ", p_override_code = ?"

		set check [_check_override_code $override_code]

		if {[lindex $check 0] == "0"} {
			err_bind [lindex $check 1]
			go_user "" ""
			return
		}
	}

	if {[OT_CfgGet ADMIN_PCI_PASSWORDS 0]} {
		# make sure the password complies with pci rules
		set valid_pwd [_validate_password $pwd_1 $pwd_2 $username]

		if {![lindex $valid_pwd 0]} {
			err_bind "Invalid password : [lindex $valid_pwd 1]"
			go_user "" ""
			return
		}
	} else {

		if {$pwd_1 != $pwd_2 || [string length $pwd_1] < 6} {
			err_bind "invalid password"
			go_user "" ""
			return
		}
	}

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		set user_pos_id [getCurrentUsersPositionId]
		set descendant_list [getPositionDescendants $user_pos_id]
		if {[lsearch -exact $descendant_list $position_id] == -1} {
			err_bind "you do not have enough privilege to assign user to that position"
			go_user "" ""
			return
		}
	}

	set pwd_salt ""
	if {[OT_CfgGet USE_ADMIN_PASSWORD_SALT 1]} {
		set pwd_salt [ob_crypt::generate_salt]
	}

	set pwd_hash [ob_crypt::encrypt_admin_password $pwd_1 $pwd_salt]

	set sql [subst {
		execute procedure pInsAdminUser(
			p_username = ?,
			p_n_username = ?,
			p_fname = ?,
			p_lname = ?,
			p_n_password = ?,
			p_pwd_salt = ?,
			p_status = ?,
			p_third_party = ?,
			p_clone_user = ?,
			p_position_id = ?,
			p_email = ?,
			p_agent_id = ?,
			p_phone_switch = ?,
			p_is_automated = ?
			$override
		)
	}]

	set user_test [subst {
		select
			COUNT(*) as user_exists
		from
			tAdminUser
		where
			username=?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set user_test_stmt [inf_prep_sql $DB $user_test]

	if {[catch {set res [inf_exec_stmt $stmt\
		$USERNAME\
		$username\
		$fname\
		$lname\
		$pwd_hash\
		$pwd_salt\
		$status\
		$third_party\
		$clone\
		$position_id\
		$user_email\
		$agent_id\
		$phone_switch\
		$is_automated\
		$override_code]} msg]} {
		#If the error msg is AX2300 (user already exists) search for an alternative username
		if {[string match *AX2300* $msg]} {
			set alter_id 1
			set alter_found 0
			while {$alter_found==0} {
				if {$alter_id>=[OT_CfgGet MAX_USERNAME_POSTFIX 999]} {
					append msg ". All user names up to suffix [OT_CfgGet MAX_USERNAME_POSTFIX 999] have been searched, select a new username"
					break
				}
				set res [inf_exec_stmt $user_test_stmt $username$alter_id]
				if {[db_get_col $res 0 user_exists] != 0} {
					incr alter_id
				} else {
					set newusername "$username$alter_id"
					set username $newusername
					incr alter_found
					db_close $res
				}
			}
		}
		err_bind $msg
		#Roll back data to user with new alternative username
		tpBindString Username $username
		tpBindString Fname $fname
		tpBindString Lname $lname
		tpBindString Email $user_email
		tpBindString Pwd_1 $pwd_1
		tpBindString Pwd_2 $pwd_2
		tpBindString Status $status
		tpBindString ThirdParty $third_party
		tpBindString AgentId $agent_id
		tpBindString PhoneSwitch $phone_switch
		tpBindString Clone $clone
		tpSetVar Position_id $position_id
		inf_close_stmt $user_test_stmt
		inf_close_stmt $stmt
		go_user "" $position_id

		if {[OT_CfgGet OVERRIDE_CODES 0]} {
			tpBindString OverrideCode $override_code
		}
	} else {
		set user_id [db_get_coln $res 0 0]
		inf_close_stmt $user_test_stmt
		inf_close_stmt $stmt
		db_close $res
		go_user $user_id ""
	}
}

proc do_user_perms args {

	global DB USERNAME

	set user_id [reqGetArg UserId]

	set sql_f {
		select
			group_id
		from
			tAdminGroup
	}

	set stmt_f   [inf_prep_sql $DB $sql_f]
	set res_grps [inf_exec_stmt $stmt_f]
	inf_close_stmt $stmt_f

	set n_grps [db_get_nrows $res_grps]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {

		set descendant_list [getPositionDescendants [getCurrentUsersPositionId]]
		if {[lsearch -exact $descendant_list [getUsersPositionId $user_id]] == -1} {
			err_bind "you do not have enough privilege to modify this user"
			go_user_list
			return
		}

		set group_list [list -1]
		for {set i 0} {$i < $n_grps} {incr i} {
			set group_id [db_get_col $res_grps $i group_id]
			if {[reqGetArg AG_$group_id] == "Y"} {
				lappend group_list ",$group_id"
			}
		}

		set change_list [list]

		set sql_del [subst {
			select
				group_id
			from
				tAdminUserGroup
			where
				user_id = ?
			and group_id not in ($group_list)
		}]

		set sql_add [subst {
			select
				g.group_id
			from
				tAdminGroup g
			where
				g.group_id in ($group_list)
			and g.group_id not in (
					select
						u.group_id
					from
						tAdminUserGroup u
					where user_id = ?
				)
		}]

		set stmt_del [inf_prep_sql $DB $sql_del]
		set stmt_add [inf_prep_sql $DB $sql_add]

		set res_del  [inf_exec_stmt $stmt_del $user_id]
		set res_add  [inf_exec_stmt $stmt_add $user_id]

		for {set i 0} {$i < [db_get_nrows $res_del]} {incr i} {
			lappend change_list [db_get_col $res_del $i group_id]
		}
		for {set i 0} {$i < [db_get_nrows $res_add]} {incr i} {
			lappend change_list [db_get_col $res_add $i group_id]
		}

		set valid 1
		set invalid_groups ""
		set sql [subst {
			select
				g.action,
				d.group_name
			from
				tAdminGroupOp g,
				tAdminGroup d
			where
				g.group_id = ?
			and g.group_id = d.group_id
			and g.action not in ([getCurrentUsersPermissions])

		}]

		set stmt [inf_prep_sql $DB $sql]

		foreach group_id $change_list {
			set res [inf_exec_stmt $stmt $group_id]

			if {[db_get_nrows $res] > 0} {
				set valid 0
				if {$invalid_groups == ""} {set invalid_groups "[db_get_col $res 0 group_name]"} else {
					set invalid_groups "$invalid_groups, [db_get_col $res 0 group_name]"
				}
			}
		}
		if {!$valid} {
			err_bind "you do not have enough privilege to modify users membership of the following group(s): $invalid_groups"
			go_user "" ""
			return
		}
	}

	set sql_d [subst {
		execute procedure pDoAdminUserGroup(
			p_username = ?,
			p_op = ?,
			p_group_id = ?,
			p_user_id = ?
		)
	}]

	set stmt_d [inf_prep_sql $DB $sql_d]

	inf_begin_tran $DB

	set r [catch {

		for {set i 0} {$i < $n_grps} {incr i} {

			set group_id [db_get_col $res_grps $i group_id]
			if {[reqGetArg AG_$group_id] == "Y"} {
				set op I
			} else {
				set op D
			}

			inf_exec_stmt $stmt_d\
			$USERNAME\
			$op\
			$group_id\
			$user_id

		}
	} msg]

	db_close $res_grps

	if {$r} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
		msg_bind "Permissions updated successfully"
	}

	inf_close_stmt $stmt_d
	go_user "" ""
}

proc do_user_perms_op args {

	global DB USERNAME

	set user_id [reqGetArg UserId]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		set descendant_list [getPositionDescendants [getCurrentUsersPositionId]]
		if {[lsearch -exact $descendant_list [getUsersPositionId $user_id]] == -1} {
			err_bind "you do not have enough privilege to modify this user"
			go_user_list
			return
		}

		set action_list [list '-1']
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			set a [reqGetNthName $i]
			if {[string range $a 0 2]== "AP_"} {
				lappend action_list ",'[string range $a 3 end]'"
			}
		}

		set change_list [list '-1']

		set sql_del [subst {
			select
				action
			from
				tAdminUserOp
			where
				user_id = ?
			and action not in ($action_list)
		}]

		set sql_add [subst {
			select
				o.action
			from
				tAdminOp o
			where
				o.action in ($action_list)
			and o.action not in (
					select
						u.action
					from
						tAdminUserOp u
					where user_id = ?
				)
		}]

		set stmt_del [inf_prep_sql $DB $sql_del]
		set stmt_add [inf_prep_sql $DB $sql_add]

		set res_del  [inf_exec_stmt $stmt_del $user_id]
		set res_add  [inf_exec_stmt $stmt_add $user_id]

		for {set i 0} {$i < [db_get_nrows $res_del]} {incr i} {
			lappend change_list ",'[db_get_col $res_del $i action]'"
		}
		for {set i 0} {$i < [db_get_nrows $res_add]} {incr i} {
			lappend change_list ",'[db_get_col $res_add $i action]'"
		}

		set sql_chk [subst {
			select
				action
			from
				tAdminOp o
			where
				o.action in ($change_list)
			and o.action not in (
				select
					u.action
				from
					tAdminUserOp u,
					tAdminUser a
				where a.user_id=u.user_id
				and   a.username = ?
			)
		}]

		set stmt_chk [inf_prep_sql $DB $sql_chk]
		set res [inf_exec_stmt $stmt_chk $USERNAME]

		if {[db_get_nrows $res] != 0} {
			err_bind "you do not have enough permissions to assign some of those permissions"
			go_user "" ""
			return
		}
	}

	set sql_d [subst {
		execute procedure pDelAdminPerms(
			p_username = ?,
			p_user_id  = ?
		)
	}]

	set sql_i [subst {
		execute procedure pInsAdminPerm(
			p_username = ?,
			p_user_id = ?,
			p_action = ?
		)
	}]

	set stmt_d [inf_prep_sql $DB $sql_d]
	set stmt_i [inf_prep_sql $DB $sql_i]

	inf_begin_tran $DB

	set r [catch {
		inf_exec_stmt $stmt_d\
			$USERNAME\
			$user_id

		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			set a [reqGetNthName $i]

			if {[string range $a 0 2]== "AP_"} {
				inf_exec_stmt $stmt_i\
					$USERNAME\
					$user_id\
					[string range $a 3 end]
			}
		}
	} msg]

	if {$r} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
		msg_bind "Permissions updated successfully"
	}

	inf_close_stmt $stmt_d
	inf_close_stmt $stmt_i
	go_user "" ""
}


proc do_user_mod_pwd args {

	global DB USERNAME

	set username [reqGetArg username]
	set pwd_1    [reqGetArg password_1]
	set pwd_2    [reqGetArg password_2]

	if {![op_allowed UpdUserPassword]} {
		err_bind "You don't have permission to update user passwords"
		go_user_list
		return
	}

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		if {![is_root_user] && $USERNAME!=$username} {
			set descendant_list [getPositionDescendants [getCurrentUsersPositionId]]
			if {[lsearch -exact $descendant_list [getUsersPositionIdFromUname $username]] == -1} {
				err_bind "you do not have enough privilege to modify this user"
				go_user_list
				return
			}
		}
	}

	if {[OT_CfgGet ADMIN_PCI_PASSWORDS 0]} {
		# make sure the password complies with pci rules
		set valid_pwd [_validate_password $pwd_1 $pwd_2 $username]

		if {![lindex $valid_pwd 0]} {
			err_bind "Invalid password : [lindex $valid_pwd 1]"
			go_user_list
			return
		}
	} else {
		if {$pwd_1 != "" || $pwd_2 != ""} {
			if {$pwd_1 != $pwd_2 || [string length $pwd_1] < 6} {
				err_bind "invalid password"
				go_user_list
				return
			}
		} else {
				err_bind "Must supply a valid password"
				go_user_list
				return
		}
	}

	if {$username != ""} {

		set sql [subst {
			select
				user_id
			from
				tAdminUser
			where
				username = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $username]
		inf_close_stmt $stmt

		set n_rows  [db_get_nrows $res]
		db_close $res

		if {$n_rows != 1} {
			err_bind "No user '$username' found."
			go_user_list
			return
		}

		set salt ""
		if {[OT_CfgGet USE_ADMIN_PASSWORD_SALT 1]} {
			set salt [ob_crypt::generate_salt]
		}

		set pwd_hash [ob_crypt::encrypt_admin_password $pwd_1 $salt]

		# Check for duplicates in the last n passwords
		set pwd_ok [ob_crypt::is_prev_admin_pwd $username $pwd_1]
		if {$pwd_ok != "PWD_IS_OK"} {
			set num_pwds [ob_crypt::get_prev_admin_pwd_count]
			set msg "Password should not be the same as the last $num_pwds passwords"
			err_bind "Failed to change password: $msg"
			go_user_list
			return
		}

		set sql {
			execute procedure pChgAdminPwd (
				p_username  = ?,
				p_new_pass  = ?,
				p_new_salt  = ?,
				p_set_guser = 'N'
			)
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			inf_exec_stmt $stmt $username $pwd_hash $salt
		} msg]} {
			err_bind "Failed to change password: $msg"
			go_user_list
			return
		}

		inf_close_stmt $stmt
		add_admin_sha1_flag $username

		msg_bind "User $username updated successfully"

	} else {
		err_bind "Must supply a username"
		go_user_list
		return
	}

	if {$username == $USERNAME} {
		# changing password for user currently logged in, need to re login
		reqSetArg password $pwd_1
		reqSetArg loginuid [ADMIN::LOGIN::gen_login_uid]

		if {[ADMIN::LOGIN::do_login 0] == 0} {
			# do login has thrown an error and played a page
			return
		}
		# successful login
	}

	go_user_list
}

proc do_user_mod args {

	global DB USERNAME OWNERS GROUPS

	set username    [reqGetArg Username]
	set user_id     [reqGetArg UserId]
	set pwd_1       [reqGetArg password_1]
	set pwd_2       [reqGetArg password_2]
	set user_email  [reqGetArg email]
	set status      [reqGetArg status]
	set third_party [reqGetArg thirdparty]
	set agent_id    [reqGetArg agent_id]
	set phone_switch [reqGetArg phone_switch]
	set position_id [reqGetArg position]
	set fname       [reqGetArg fname]
	set lname       [reqGetArg lname]
	set is_automated [reqGetArg is_automated]

	if {$is_automated == "on"} {
		set is_automated 1
	} else {
		set is_automated 0
	}

	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		set override_code [string toupper [reqGetArg overridecode]]

		# Edit customer details
		#michael
		set check [_check_override_code $override_code $user_id]
		if {[lindex $check 0] == "0"} {
			err_bind [lindex $check 1]
			go_user "" ""
			return
		}
	}

	# Make doubly sure that the user has the right to modify user settings

	if {[has_assign_rights] != 1} {
		err_bind "You do not have the correct permission to do this"
		tpSetVar NumUsers 0
		tpSetVar hasRights 0
		asPlayFile -nocache user_list.html
		return
	}

	set do_pwd 0

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		if {![is_root_user]} {
			set curr_user_pos_id [getCurrentUsersPositionId]
			set descendant_list [getPositionDescendants $curr_user_pos_id]
			if {[lsearch -exact $descendant_list [getUsersPositionId $user_id]] == -1} {
				err_bind "you do not have enough privilege to modify this user"
				go_user "" ""
				return
			}
			if {([lsearch -exact $descendant_list $position_id] == -1) && ($position_id != $curr_user_pos_id)} {
				err_bind "you do not have enough privilege to assign that position to a user"
				go_user "" ""
				return
			}
		}
	}

	if {$pwd_1 != "" || $pwd_2 != ""} {
		if {![op_allowed UpdUserPassword]} {
			err_bind "You don't have permission to update user passwords"
			go_user "" ""
			return
		}

		set do_pwd 1

		if {[OT_CfgGet ADMIN_PCI_PASSWORDS 0]} {
			# make sure the password complies with pci rules
			set valid_pwd [_validate_password $pwd_1 $pwd_2 $username]

			if {![lindex $valid_pwd 0]} {
				err_bind "Invalid password : [lindex $valid_pwd 1]"
				go_user "" ""
				return
			}
		} else {
			if {$pwd_1 != $pwd_2 || [string length $pwd_1] < 6} {
				err_bind "invalid password"
				go_user "" ""
				return
			}
		}

		set salt ""
		if {[OT_CfgGet USE_ADMIN_PASSWORD_SALT 1]} {
			set salt [ob_crypt::generate_salt]
		}

		set pwd_hash [ob_crypt::encrypt_admin_password $pwd_1 $salt]
	}

	set override ""
	if {[OT_CfgGet OVERRIDE_CODES 0]} {

		# We need to check here that the override code is unique

		set override ",override_code = ?"

	}

	if {$do_pwd} {
		# Check for duplicates in the last n passwords
		set pwd_ok [ob_crypt::is_prev_admin_pwd $username $pwd_1]
		if {$pwd_ok != "PWD_IS_OK"} {
			set num_pwds [ob_crypt::get_prev_admin_pwd_count]
			set msg "Password should not be the same as the last $num_pwds passwords"
			err_bind "Failed to change password: $msg"
			go_user "" ""
			return
		}

		set sql {
			execute procedure pChgAdminPwd (
				p_username  = ?,
				p_new_pass  = ?,
				p_new_salt  = ?,
				p_set_guser = 'N'
			)
		}

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			inf_exec_stmt $stmt $username $pwd_hash $salt
		} msg]} {
			inf_close_stmt $stmt
			err_bind "Failed to change password: $msg"
			go_user "" ""
			return
		}

		inf_close_stmt $stmt
	}

	set sql [subst {
		update tAdminUser set
			status = ?,
			position_id = ?,
			fname = ?,
			lname = ?,
			email = ?,
			agent_id = ?,
			phone_switch = ?
			$override
		where
			user_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[OT_CfgGet OVERRIDE_CODES 0]} {
		inf_exec_stmt $stmt $status $position_id $fname $lname $user_email $agent_id $phone_switch $override_code $user_id
	} else {
		inf_exec_stmt $stmt $status $position_id $fname $lname $user_email $agent_id $phone_switch $user_id
	}

	inf_close_stmt $stmt

	# Update 3rd Party flag
	if {[OT_CfgGetTrue FUNC_ADMIN_USER_THIRDPARTIES]} {
		set remove_third_party_sql {
			delete from
				tAdminUserFlag
			where
				    flag_name like "3RDPARTY_%"
				and user_id = ?
		}

		set insert_third_party_sql {
			insert into tAdminUserFlag(
				user_id,
				flag_name
			) values (?, ?)
		}

		set st [inf_prep_sql $DB $remove_third_party_sql]
		inf_exec_stmt $st $user_id
		inf_close_stmt $st

		if {$third_party != ""} {
			set st [inf_prep_sql $DB $insert_third_party_sql]
			inf_exec_stmt $st $user_id $third_party
			inf_close_stmt $st
		}
	}

	# Update is_automated flag
	set sql {
		select
			flag_name
		from
			tAdminUserFlag
		where
			user_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $user_id]
	set nrows [db_get_nrows $rs]
	inf_close_stmt $stmt
	db_close $rs

	if {$nrows > 0} {
		set sql {
			update
				tAdminUserFlag
			set
				flag_value = ?
			where
				user_id = ?
			and
				flag_name = 'IS_AUTOMATED'
		}

		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $is_automated $user_id
		inf_close_stmt $stmt

	} else {
		set sql {
			insert into
				tAdminUserFlag (
					user_id,
					flag_name,
					flag_value
				)
			values (
					?,
					'IS_AUTOMATED',
					?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $user_id $is_automated
		inf_close_stmt $stmt
	}

	if {$do_pwd && $username == $USERNAME} {
		# changing password for user currently logged in, need to re login
		reqSetArg password $pwd_1
		reqSetArg loginuid [ADMIN::LOGIN::gen_login_uid]

		# log the current user in
		if {[ADMIN::LOGIN::do_login 0] == 0} {
			# do login has encountered an error and played a page, return
			return
		}
		# successful login
	}

	# We need to check whether this user was the owner of any groups.
	#  If they were we must reassign the ownership.
	if {$status == "S"} {

		# Get group ids of all groups this user is owner of
		set sql [subst {
			select
				group_id,
				group_name
			from
				tAdminGroup
			where
				group_owner = $user_id
		}]


		set stmt [inf_prep_sql $DB $sql]
		set rs   [ inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set numGroups [db_get_nrows $rs]

		OT_LogWrite 1 "This User is owner of $numGroups groups"

		# We must now prompt the operator to reassign an owner to
		#  each of these groups (if any exist)
		if {$numGroups > 0} {

			for {set i 0} {$i < $numGroups} {incr i} {
				set GROUPS($i,group_name) [db_get_col $rs $i group_name]
				set GROUPS($i,group_id)   [db_get_col $rs $i group_id]
				lappend group_list $GROUPS($i,group_id)
			}

			tpBindString GroupList [join $group_list "|"]

			# Get & bind all possible group owners
			set sql2 {
				select
					user_id,
					username
				from
					tAdminUser
				where
					status = 'A'
				order by
					2
			}

			set stmt2 [inf_prep_sql $DB $sql2]
			set rs2   [inf_exec_stmt $stmt2]
			inf_close_stmt $stmt2

			set numOwners [db_get_nrows $rs2]

			for {set i 0} {$i < $numOwners} {incr i} {
				set OWNERS($i,owner_id)   [db_get_col $rs2 $i user_id]
				set OWNERS($i,owner_name) [db_get_col $rs2 $i username]
			}

			tpSetVar  numGroups  $numGroups
			tpBindVar GroupID    GROUPS  group_id    group_idx
			tpBindVar GroupName  GROUPS  group_name  group_idx

			tpSetVar  numOwners  $numOwners
			tpBindVar OwnerID    OWNERS  owner_id    owner_idx
			tpBindVar OwnerName  OWNERS  owner_name  owner_idx

			db_close $rs2
		}

		db_close $rs

		asPlayFile -nocache user_group_owner.html
		return
	}

	go_user_list
}


#
# This proc is used to reassign the ownership of a group if the original
#  owner has been status suspended
#
proc do_reassign_group_owner args {

	global DB USERNAME

	set	group_list [split [reqGetArg group_list] "|"]

	set sql {
		execute procedure pDoAdminGroup (
			p_username = ?,
			p_op = ?,
			p_group_id = ?,
			p_group_name = ?,
			p_group_owner = ?
		)
	}

	set sql2 [subst {
		execute procedure pDoAdminUserGroup (
			p_username = ?,
			p_op       = ?,
			p_group_id = ?,
			p_user_id  = ?
		)
	}]

	foreach eachGroupID $group_list {

		set group_name  [reqGetArg ${eachGroupID}_group_name]
		set group_owner [reqGetArg ${eachGroupID}_group_owner]

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {set rs [inf_exec_stmt $stmt $USERNAME "U" $eachGroupID $group_name $group_owner]} msg]} {
			err_bind "do_reassign_group_owner - stmt - $msg"
		} else {

			# If the group owner is changed we want to make sure the new owner is
			#  actually added to the group
			set stmt2 [inf_prep_sql $DB $sql2]

			# We delete first to ensure we dont have duplicate values
			if {[catch {set rs2D [inf_exec_stmt $stmt2 $USERNAME "D" $eachGroupID $group_owner]} msg]} {
				err_bind "do_reassign_group_owner - stmt2(D) - $msg"
			} else {
				db_close $rs2D
			}

			if {$group_owner != ""} {
				if {[catch {set rs2I [inf_exec_stmt $stmt2 $USERNAME "I" $eachGroupID $group_owner]} msg]} {
					err_bind "do_reassign_group_owner - stmt2(I) - $msg"
				} else {
					db_close $rs2I
				}
			}

			inf_close_stmt $stmt2

		}
		inf_close_stmt $stmt

	}

	go_user_list
}



proc do_user_logout args {

	global DB
	set username [reqGetArg username]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0]} {
		if {![is_root_user]} {
			set descendant_list [getPositionDescendants [getCurrentUsersPositionId]]
			if {[lsearch -exact $descendant_list [getUsersPositionIdFromUname $username]] == -1} {
				err_bind "you do not have enough privilege to logout $username"
				go_user_list
				return
			}
		}
	}

	set sql {
		execute procedure pAdminLogout(
			p_username = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $username
	inf_close_stmt $stmt

	go_user_list
}

proc go_password args {
	global USERNAME

	# May already have set up username from login.tcl's pwd expiry
	if {$USERNAME != ""} {
		tpSetVar username $USERNAME
	}

	asPlayFile -nocache password.html
}

proc do_password args {

	global DB

	set username [reqGetArg username]
	set is_login [reqGetArg is_login]

	tpSetVar username $username
	tpSetVar is_login $is_login

	set pwd_0    [reqGetArg Password_0]
	set pwd_1    [reqGetArg Password_1]
	set pwd_2    [reqGetArg Password_2]

	if {[OT_CfgGet ADMIN_PCI_PASSWORDS 0]} {
		# make sure the password complies with pci rules
		set valid_pwd [_validate_password $pwd_1 $pwd_2 $username]

		if {![lindex $valid_pwd 0]} {
			err_bind "Invalid password : [lindex $valid_pwd 1]"
			go_password
			return
		}
	} else {
		if {$pwd_1 != $pwd_2 || [string length $pwd_1] < 6} {
			error "Invalid password"
		}
	}

	if {[OT_CfgGetTrue CONVERT_ADMIN_HASHES]} {
		# Changes the hash in tAdminUsers to be a SHA-1 hash. Shouldn't
		# require handling of returns, as the password is checked later.
		ob_crypt::convert_admin_password_hash $username $pwd_0
	}

	set salt_resp [ob_crypt::get_admin_salt $username]
	set old_salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set old_salt ""
	}

	set new_salt ""
	if {[OT_CfgGet USE_ADMIN_PASSWORD_SALT 1]} {
		set new_salt [ob_crypt::generate_salt]
	}

	set pwd_old_hash [ob_crypt::encrypt_admin_password $pwd_0 $old_salt]
	set pwd_new_hash [ob_crypt::encrypt_admin_password $pwd_1 $new_salt]

	# Check for duplicates in the last n passwords
	set pwd_ok [ob_crypt::is_prev_admin_pwd $username $pwd_1]
	if {$pwd_ok != "PWD_IS_OK"} {
		set num_pwds [ob_crypt::get_prev_admin_pwd_count]
		set msg "Password should not be the same as the last $num_pwds passwords"
		err_bind "Failed to change password: $msg"
		go_password
		return
	}

	set sql {
		execute procedure pChgAdminPwd (
			p_username  = ?,
			p_new_pass  = ?,
			p_new_salt  = ?,
			p_old_pass  = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt $username $pwd_new_hash $new_salt $pwd_old_hash
	} msg]} {
		err_bind "Failed to change password: $msg"
		go_password
		return
	}
	ob::log::write ERROR {Pwd change succeeded}
	tpSetVar PasswordChanged 1

	inf_close_stmt $stmt

	ob::log::write DEV {Now logging in $username}

	reqSetArg password $pwd_1
	reqSetArg loginuid [ADMIN::LOGIN::gen_login_uid]

	if {[reqGetArg is_login] == 1} {

		set change_pwd_redir      [OT_CfgGet EXPIRED_PWD_REDIR 0]
		set change_pwd_redir_url  [OT_CfgGet EXPIRED_PWD_REDIR_URL "/office"]

		if {$change_pwd_redir} {
			if {[ADMIN::LOGIN::do_login 0] == 0} {
				# do login has thrown an error and played a page return
				return
			}

			tpBindString OFFICE_URL $change_pwd_redir_url
			ob::log::write DEV "Expired password changed, redirecting"
			asPlayFile -nocache redirect_office.html

		} else {
			# this is during login, perform a full login, play left nav
			ADMIN::LOGIN::do_login
		}

	} else {
		# login, but dont play
		if {[ADMIN::LOGIN::do_login 0] == 0} {
			# do login has thrown an error and played a page return
			return
		}
		# successful login play the password page
		go_password
	}
}

#
# ----------------------------------------------------------------------------
# Go view/add position page
# ----------------------------------------------------------------------------
#
proc go_position args {
	global DB USERNAME AP AG

	set position_id [reqGetArg PositionId]

	foreach {n v} $args {
		set $n $v
	}

	set CanAssignRights [has_assign_rights]

	tpSetVar PositionId $position_id
	if {$position_id == ""} {set position_id -1}

	if {$position_id != -1} {
		# get position details
		set sql [subst {
			select
				position_id,
				position_name
			from
				tAdminPosition
			where
				position_id = ?

		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $position_id]
		inf_close_stmt $stmt

		tpBindString PositionId     $position_id
		tpBindString PositionName   [db_get_col $res 0 position_name]

		db_close $res

		tpSetVar opAdd 0
	} else {
		tpSetVar opAdd 1
	}

	# get list of all postions so parent can be specified.
	set sql [subst {
		select
			position_id,
			position_name,
			case when position_id = (
				select parent_position_id
				from   tAdminPosition
				where  position_id = ?
			) then 'selected' else '' end as status
		from
			tAdminPosition
		where
			position_id not in ([getPositionDescendants $position_id 1])
		and position_id != ?
		order by
			position_name
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $position_id $position_id]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]
	for {set i 0} {$i < $n_rows} {incr i} {
		set AP($i,parent_pos_id)           [db_get_col $res $i position_id]
		set AP($i,parent_pos_name)         [db_get_col $res $i position_name]
		set AP($i,parent_pos_selected)      [db_get_col $res $i status]

	}
	db_close $res

	tpSetVar NumPositions $n_rows

	tpBindVar ParentPosId       AP parent_pos_id          pos_idx
	tpBindVar ParentPosName     AP parent_pos_name        pos_idx
	tpBindVar ParentPosSelected AP parent_pos_selected    pos_idx

	# Get groups and membership details
	set sql {
		select
			g.group_id,
			g.group_name,
			case when pg.position_id is not null then "CHECKED" else "" end status
		from
			tAdminGroup g,
			outer tAdminPosnGroup pg
		where
			g.group_id = pg.group_id and
			pg.position_id = ?
		order by
			g.group_name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $position_id]
	inf_close_stmt $stmt

	set n_rows  [db_get_nrows $res]


	for {set r 0} {$r < $n_rows} {incr r} {
		set AG($r,group_id)   [db_get_col $res $r group_id]
		set AG($r,group_name) [db_get_col $res $r group_name]
		set AG($r,selected)   [db_get_col $res $r status]
	}

	tpBindVar GroupId       AG group_id   group_idx
	tpBindVar GroupName     AG group_name group_idx
	tpBindVar GroupSelected AG selected   group_idx

	tpSetVar NumGroups $n_rows

	asPlayFile -nocache user_position.html

	catch {unset AP}
	catch {unset AG}
}


#
# ----------------------------------------------------------------------------
# Wrapper for all action where changes are performed on positions
# ----------------------------------------------------------------------------
#
proc do_position args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "PosnAdd"} {
		do_position_add
	} elseif {$act == "PosnMod"} {
		do_position_mod
	} elseif {$act == "PosnDel"} {
		do_position_del
	} elseif {$act == "UpdPerms"} {
		do_position_perms
	} elseif {$act == "Back"} {
		go_user_list
	} else {
		error "unexpected action: $act"
	}
}


#
# ----------------------------------------------------------------------------
# Add new position
# ----------------------------------------------------------------------------
#
proc do_position_add args {
	global DB USERNAME

	set position_name [reqGetArg PositionName]
	set parent_position_id [reqGetArg PositionParentId]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		set current_user_pos_id [getCurrentUsersPositionId]
		if {$parent_position_id != $current_user_pos_id} {
			set descendant_list [getPositionDescendants $current_user_pos_id]
			if {[lsearch -exact $descendant_list $parent_position_id] == -1} {
				err_bind "you do not have enough privilege to add position with that parent"
				go_position
				return
			}
		}
	}

	set sql [subst {
		execute procedure pDoAdminPosition (
			p_username = ?,
			p_op = 'I',
			p_position_name = ?,
			p_parent_posn_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $USERNAME $position_name $parent_position_id]} msg]} {
		set bad 1
		err_bind $msg
		tpBindString PositionName $position_name
		go_group
	} else {
		set position_id [db_get_coln $res 0 0]
		db_close $res
		go_position position_id $position_id
	}
}


#
# ----------------------------------------------------------------------------
# Modify position
# ----------------------------------------------------------------------------
#
proc do_position_mod args {
	global DB USERNAME

	set position_id        [reqGetArg PositionId]
	set position_name      [reqGetArg PositionName]
	set parent_position_id [reqGetArg PositionParentId]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		set current_user_pos_id [getCurrentUsersPositionId]
		set descendant_list [getPositionDescendants $current_user_pos_id]
		if {[lsearch -exact $descendant_list $position_id] == -1} {
			err_bind "you do not have enough privilege to modify that position"
			go_user_list
			return
		}
		if {$parent_position_id != $current_user_pos_id} {
			if {[lsearch -exact $descendant_list $parent_position_id] == -1} {
				err_bind "you do not have enough privilege to modify position to have that parent"
				go_position
				return
			}
		}
	}

	set sql {
		execute procedure pDoAdminPosition (
			p_username = ?,
			p_op = 'U',
			p_position_name = ?,
			p_position_id = ?,
			p_parent_posn_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERNAME $position_name $position_id $parent_position_id
	inf_close_stmt $stmt

	go_user_list
}


#
# ----------------------------------------------------------------------------
# Delete position
# ----------------------------------------------------------------------------
#
proc do_position_del args {
	global DB USERNAME

	set position_id [reqGetArg PositionId]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		set current_user_pos_id [getCurrentUsersPositionId]
		set descendant_list [getPositionDescendants $current_user_pos_id]
		if {[lsearch -exact $descendant_list $position_id] == -1} {
			err_bind "you do not have enough privilege to delete that position"
			go_user_list
			return
		}
	}

	set sql {
		execute procedure pDoAdminPosition (
			p_username = ?,
			p_op = 'D',
			p_position_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERNAME $position_id
	inf_close_stmt $stmt

	go_user_list
}


#
# ----------------------------------------------------------------------------
# Change groups associated with position
# ----------------------------------------------------------------------------
#
proc do_position_perms args {
	global DB USERNAME


	set position_id [reqGetArg PositionId]

	set sql_f {
		select
			group_id
		from
			tAdminGroup
	}

	set stmt_f [inf_prep_sql $DB $sql_f]
	set res_grps [inf_exec_stmt $stmt_f]
	inf_close_stmt $stmt_f

	set n_grps [db_get_nrows $res_grps]

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {

		set descendant_list [getPositionDescendants [getCurrentUsersPositionId]]
		if {[lsearch -exact $descendant_list $position_id] == -1} {
			err_bind "you do not have enough privilege to modify this position"
			go_user_list
			return
		}

		set group_list [list -1]
		for {set i 0} {$i < $n_grps} {incr i} {
			set group_id [db_get_col $res_grps $i group_id]
			if {[reqGetArg AG_$group_id] == "Y"} {
				lappend group_list ",$group_id"
			}
		}

		set change_list [list]

		set sql_del [subst {
			select
				group_id
			from
				tAdminPosnGroup
			where
				position_id = ?
			and group_id not in ($group_list)
		}]

		set sql_add [subst {
			select
				g.group_id
			from
				tAdminGroup g
			where
				g.group_id in ($group_list)
			and g.group_id not in (
					select
						p.group_id
					from
						tAdminPosnGroup p
					where position_id = ?
				)
		}]

		set stmt_del [inf_prep_sql $DB $sql_del]
		set stmt_add [inf_prep_sql $DB $sql_add]

		set res_del  [inf_exec_stmt $stmt_del $position_id]
		set res_add  [inf_exec_stmt $stmt_add $position_id]

		for {set i 0} {$i < [db_get_nrows $res_del]} {incr i} {
			lappend change_list [db_get_col $res_del $i group_id]
		}
		for {set i 0} {$i < [db_get_nrows $res_add]} {incr i} {
			lappend change_list [db_get_col $res_add $i group_id]
		}

		set valid 1
		set invalid_groups ""
		set sql [subst {
			select
				g.action,
				d.group_name
			from
				tAdminGroupOp g,
				tAdminGroup d
			where
				g.group_id = ?
			and g.group_id = d.group_id
			and g.action not in ([getCurrentUsersPermissions])

		}]

		set stmt [inf_prep_sql $DB $sql]

		foreach group_id $change_list {
			set res [inf_exec_stmt $stmt $group_id]
			if {[db_get_nrows $res] > 0} {
				set valid 0
				if {$invalid_groups == ""} {set invalid_groups "[db_get_col $res 0 group_name]"} else {
					set invalid_groups "$invalid_groups, [db_get_col $res 0 group_name]"
				}
			}
		}
		if {!$valid} {
			err_bind "you do not have enough privilege to add/remove the following groups from this position: $invalid_groups"
			go_position
			return
		}
	}

	set sql_d [subst {
		execute procedure pDoAdminPosnGroup(
			p_username = ?,
			p_op = ?,
			p_group_id = ?,
			p_position_id = ?
		)
	}]

	set stmt_d [inf_prep_sql $DB $sql_d]

	inf_begin_tran $DB

	set r [catch {

		for {set i 0} {$i < $n_grps} {incr i} {

			set group_id [db_get_col $res_grps $i group_id]
			if {[reqGetArg AG_$group_id] == "Y"} {
				set op I
			} else {
				set op D
			}

			inf_exec_stmt $stmt_d\
			$USERNAME\
			$op\
			$group_id\
			$position_id

		}
	} msg]

	db_close $res_grps

	if {$r} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
		msg_bind "Permissions updated successfully"
	}

	inf_close_stmt $stmt_d

	go_position position_id $position_id
}


#
# ----------------------------------------------------------------------------
# Go to individual group detail
# ----------------------------------------------------------------------------
#
proc go_group args {

	global DB AG OWNERS USERNAME

	set group_id [reqGetArg GroupId]
	set group_owner [reqGetArg group_owner]

	foreach {n v} $args {
		set $n $v
	}

	set CanAssignRights [has_assign_rights]

	tpSetVar GroupId $group_id

	if {$group_id != ""} {

		set sql [subst {
			select
				group_id,
				group_name,
				group_owner
			from
				tAdminGroup
			where
				group_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $group_id]
		inf_close_stmt $stmt

		tpBindString GroupId   $group_id
		tpBindString GroupName [db_get_col $res 0 group_name]
		tpBindString GroupOwner [db_get_col $res 0 group_owner]

		db_close $res

		tpSetVar opAdd 0

	} else {
		tpSetVar opAdd 1
	}

	# get permissions
	set sql [subst {
		select
			o.action,
			o.desc,
			t.type,
			t.desc type_desc,
			case when g.group_id is not null then 'CHECKED' else '' end status,
			NVL(t.disporder,0) t_disporder,
			NVL(o.disporder,0) o_disporder
		from
			tAdminOp o,
			tAdminOpType t,
			outer tAdminGroupOp g
		where
			g.group_id = ? and
			o.action = g.action and
			o.type = t.type
	}]
	#if user is not root user, must have permissions themselves
	#to be able to view and change them.
	if {![is_root_user]} {
		set sql $sql[subst {
		  and NVL(o.disporder,0) >= 0
			and (o.action in (
				select
					gop.action
				from
					tAdminUser u,
					tAdminUserGroup ug,
					tAdminGroupOp gop
				where
					u.username = ? and
					u.user_id = ug.user_id and
					ug.group_id = gop.group_id

			) or o.action in (
				select
					auo.action
				from
					tAdminUser au,
					tAdminUserOp auo
				where
					au.username = ? and
					au.user_id = auo.user_id
			))
		}]
	}
	set sql $sql[subst {
		order by
			t_disporder,
			t.type,
			o_disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $group_id $USERNAME $USERNAME]
	inf_close_stmt $stmt

	set n_rows  [db_get_nrows $res]

	set n_perms -1
	set n_grps  -1

	set c_grp ""

	for {set r 0} {$r < $n_rows} {incr r} {

		if {[set grp [db_get_col $res $r type]] != $c_grp} {

			incr n_grps
			set c_grp $grp
			set n_perms 0
			set AG($n_grps,op_grp_name) [db_get_col $res $r type_desc]
		}

		set AG($n_grps,$n_perms,op)          [db_get_col $res $r action]
		set AG($n_grps,$n_perms,op_desc)     [db_get_col $res $r desc]
		set AG($n_grps,$n_perms,op_selected) [db_get_col $res $r status]

		set AG($n_grps,n_perms) [incr n_perms]
	}

	if {$n_rows} {
		incr n_grps
	}

	db_close $res


	# Get & bind all possible group owners
	set sql {
		select
			user_id,
			username
		from
			tAdminUser
		where
			status = 'A'
		order by
			2
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_owners [db_get_nrows $rs]

	for {set i 0} {$i < $num_owners} {incr i} {
		set OWNERS($i,id)   [db_get_col $rs $i user_id]
		set OWNERS($i,name) [db_get_col $rs $i username]
	}


	tpSetVar NumPermGrps     $n_grps
	tpSetVar CanAssignRights $CanAssignRights

	tpBindVar AdminOpGrp  AG op_grp_name grp_idx
	tpBindVar AdminOp     AG op          grp_idx perm_idx
	tpBindVar AdminOpDesc AG op_desc     grp_idx perm_idx
	tpBindVar OpSelected  AG op_selected grp_idx perm_idx

	tpSetVar  NumOwners  $num_owners
	tpBindVar OwnerID    OWNERS          id      owner_idx
	tpBindVar OwnerName  OWNERS          name    owner_idx

	db_close $rs

	asPlayFile -nocache user_group.html

	catch {unset AG}
}


proc do_group args {

	global DB

	set act [reqGetArg SubmitName]

	if {$act == "GroupAdd"} {
		do_group_add
	} elseif {$act == "AuditGroups"} {
		reqSetArg AuditInfo AdminGroupOp
		ADMIN::AUDIT::go_audit
	} elseif {$act == "UpdPerms"} {
		do_group_perms
	} elseif {$act == "GroupMod"} {
		do_group_mod
	} elseif {$act == "GroupDel"} {
		do_group_del
	} elseif {$act == "Back"} {
		go_user_list
	} elseif {$act == "ReassignOwner"} {
		do_reassign_group_owner
	} else {
		error "unexpected action: $act"
	}
}

proc do_group_add args {

	global DB USERNAME

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		err_bind "only root users may add a new group"
		go_user_list
		return
	}

	set group_name [reqGetArg GroupName]
	set parent_group_id [reqGetArg GroupParent]
	set group_owner     [reqGetArg group_owner]


	set sql [subst {
		execute procedure pDoAdminGroup(
			p_username = ?,
			p_op = 'I',
			p_group_name = ?,
			p_group_owner = ?
		)
	}]

	OT_LogWrite 10 "Inserting new group with username = ${USERNAME}, \n group_name = ${group_name}, \n group_owner = ${group_owner}"

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt $USERNAME $group_name $group_owner $parent_group_id]} msg]} {
		set bad 1
		err_bind "do_add_group - stmt - $msg"
		tpSetVar opAdd 1
		tpBindString GroupName $group_name
		go_group
	} else {
		set group_id [db_get_coln $res 0 0]
		db_close $res
		# If a user is being set as the group owner we add them to that group
		if {$group_owner != ""} {
			set sql2 [subst {
				execute procedure pDoAdminUserGroup (
					p_username = ?,
					p_op       = 'I',
					p_group_id = ?,
					p_user_id  = ?
				)
			}]

			set stmt2 [inf_prep_sql $DB $sql2]
			if {[catch {set rs [inf_exec_stmt $stmt2 $USERNAME $group_id $group_owner]} msg]} {
				set bad2 1
				err_bind "do_add_group - stmt2 - $msg"
				tpBindString GroupName $group_name
			} else {
				db_close $rs
			}

			inf_close_stmt $stmt2
		}

		go_group group_id $group_id
	}
	inf_close_stmt $stmt
}

proc do_group_mod args {

	global DB USERNAME

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		err_bind "only root users may modify groups"
		go_user_list
		return
	}

	set group_id        [reqGetArg GroupId]
	set group_name      [reqGetArg GroupName]
	set parent_group_id [reqGetArg GroupParent]
	set group_owner     [reqGetArg group_owner]

	if {![op_allowed AssignRights]} {
		err_bind "You don't have permission to assign admin rights"

		reqSetArg GroupId     $group_id
		reqSetArg group_owner $group_owner

		go_group group_id $group_id

		return
	}

	set sql {
		execute procedure pDoAdminGroup(
			p_username = ?,
			p_op = ?,
			p_group_name = ?,
			p_group_id = ?,
			p_group_owner = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERNAME U $group_name $group_id $group_owner $parent_group_id
	inf_close_stmt $stmt


	# If the group owner is changed to NOT NONE we want to make sure the new owner is
	#  actually added to the group
	if {$group_owner != ""} {

		# Get all existing members of this group
		set sql2 {
			select
				user_id
			from
				tAdminUserGroup
			where
				group_id = ?
		}

		set stmt2 [inf_prep_sql $DB $sql2]

		if {[catch {set rs2 [inf_exec_stmt $stmt2 $group_id]} msg]} {
			err_bind "do_group_mod - stmt2 - $msg"
		}

		set group_members [list]

		for {set i 0} {$i < [db_get_nrows $rs2]} {incr i} {
			lappend group_members [db_get_col $rs2 $i user_id]
		}

		# Check if new group owner is in the list.
		#  If not then we add them
		if {[lsearch $group_members $group_owner] == -1} {

			set sql3 [subst {
				execute procedure pDoAdminUserGroup (
					p_username = ?,
					p_op       = 'I',
					p_group_id = ?,
					p_user_id  = ?
				)
			}]

			set stmt3 [inf_prep_sql $DB $sql3]

			if {[catch {set rs3 [inf_exec_stmt $stmt3 $USERNAME $group_id $group_owner]} msg]} {
				err_bind "do_group_mod - stmt3 - $msg"
			} else {
				db_close $rs3
			}

			inf_close_stmt $stmt3

		}

		inf_close_stmt $stmt2
		db_close $rs2
	}

	go_user_list
}

proc do_group_del args {

	global DB USERNAME

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		err_bind "only root users may delete groups"
		go_user_list
		return
	}

	set group_id   [reqGetArg GroupId]

	set sql {
		execute procedure pDoAdminGroup(
			p_username = ?,
			p_op = ?,
			p_group_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
	inf_exec_stmt $stmt $USERNAME D $group_id
	} msg]} {
		err_bind $msg
	}

	inf_close_stmt $stmt

	go_user_list
}

proc do_group_perms args {

	global DB USERNAME

	if {[OT_CfgGet FUNC_ADMIN_HIERARCHY 0] && ![is_root_user]} {
		err_bind "only root users may change group permissions"
		go_user_list
		return
	}

	set group_id [reqGetArg GroupId]

	set select_sql {
		select
			action
		from
			tAdminOp
	}

	set sql {
		execute procedure pDoAdminGroupOp(
			p_username = ?,
			p_op = ?,
			p_group_id = ?,
			p_action = ?
		)
	}


	inf_begin_tran $DB

	# Get the list of permissions
	set stmt [inf_prep_sql $DB $select_sql]
	set rs   [inf_exec_stmt $stmt]
	set actions [list]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		lappend actions [db_get_col $rs $i action]
	}

	db_close $rs
	inf_close_stmt $stmt

	puts "actions = $actions"

	# Update each permission in the list
	set stmt [inf_prep_sql $DB $sql]

	set r [catch {
		foreach a $actions {
			if {[reqGetArg "AP_$a"] == "on"} {
				set op I
			} else {
				set op D
			}

			inf_exec_stmt $stmt\
				$USERNAME\
				$op\
				$group_id\
				$a
		}
	} msg]

	if {$r} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt

	go_group
}


#
# ----------------------------------------------------------------------------
# Returns a list of all the descendants of the given position_id.
# If sql_format is set to 1, then commas will be inserted so that results can
# be used in sql queries.
# getPositionDescendantsInner is called recursively.
# ----------------------------------------------------------------------------
#
proc getPositionDescendants {id {sql_format 0}} {
	global DB POSN_DESC_LIST

	catch {unset POSN_DESC_LIST}
	set POSN_DESC_LIST [list -1]

	set sql [subst {
		select
			position_id
		from
			tAdminPosition
		where
			parent_position_id=?
	}]

	set stmt [inf_prep_sql $DB $sql]
	getPositionDescendantsInner $stmt $id $sql_format
	inf_close_stmt $stmt

	return $POSN_DESC_LIST
}


proc getPositionDescendantsInner {stmt id sql_format} {
	global POSN_DESC_LIST
	set res [inf_exec_stmt $stmt $id]
	set n_rows [db_get_nrows $res]

	for {set i 0} {$i < $n_rows} {incr i} {
		set desc_id [db_get_col $res $i position_id]
		if {[lsearch -exact POSN_DESC_LIST $desc_id] == -1} {
			if {$sql_format} {
				lappend POSN_DESC_LIST ",$desc_id"
			} else {
				lappend POSN_DESC_LIST $desc_id
			}
			getPositionDescendantsInner $stmt $desc_id $sql_format
		}
	}

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Display hierarchical tree
# ----------------------------------------------------------------------------
#
proc go_position_hierarchy {} {
	global DB POSN_DESC_ARRAY
	global COL ROW NROWS NCOLS PARENT_COL

	set sql [subst {
		select
			position_id,
			position_name
		from
			tAdminPosition
		where
			parent_position_id is null

	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	set sql [subst {
		select
			position_id,
			position_name
		from
			tAdminPosition
		where
			parent_position_id = ?

	}]

	set stmt [inf_prep_sql $DB $sql]

	set COL 0
	set ROW 0
	set NCOLS 1
	set NROWS 1
	set PARENT_COL 0
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		if {$i < ([db_get_nrows $res]-1)} {
				set last_child 0
		} else {set last_child 1}
		go_position_hierarchy_inner $stmt [db_get_col $res $i position_id] [db_get_col $res $i position_name] $last_child 1
		if {$i < ([db_get_nrows $res]-1)} {
			incr COL
			incr NCOLS
	   }
	}

	inf_close_stmt $stmt
	db_close $res

	tpSetVar ncols $NCOLS
	tpSetVar nrows $NROWS

	tpBindVar PositionName POSN_DESC_ARRAY name row_idx col_idx
	tpBindVar PositionId   POSN_DESC_ARRAY id row_idx col_idx
	tpBindVar Branching    POSN_DESC_ARRAY branching row_idx col_idx

	asPlayFile -nocache user_position_hierarchy.html

	catch {
		unset COL
		unset ROW
		unset NCOLS
		unset NROWS
		unset PARENT_COL
		unset POSN_DESC_ARRAY
	}
}


#
# ----------------------------------------------------------------------------
# Recursive part of displaying position hierarchical tree.
# Builds up an array, indexed by row and column of table cell entries.
# Branch positions either FC (first child), OC (only child), NC (next child),
# LC (last child) or '-' (no entry). CO (continue) used in template to continue
# branch where needed over areas without children.
# ----------------------------------------------------------------------------
#
proc go_position_hierarchy_inner {stmt id name last_child new_row} {
	global POSN_DESC_ARRAY
	global COL ROW NROWS NCOLS PARENT_COL

	if {$COL == $PARENT_COL} {
		#first child
		if {$ROW == ($NROWS - 1) && $new_row} {
			# first child of a new row - must fill in all spaces to your left
			for {set i 0} {$i < $NCOLS} {incr i} {
				if {$i == $COL} {
					set POSN_DESC_ARRAY($ROW,$i,name) $name
					set POSN_DESC_ARRAY($ROW,$i,id) $id
					if {$last_child} {
						#only child
						set POSN_DESC_ARRAY($ROW,$i,branching) OC
					} else {
						#first child of multiple
						set POSN_DESC_ARRAY($ROW,$i,branching) FC
					}
				} else {
					set POSN_DESC_ARRAY($ROW,$i,name) &nbsp;
					set POSN_DESC_ARRAY($ROW,$i,branching) -
				}
			}
		} else {
			# first child of an existing row
			set POSN_DESC_ARRAY($ROW,$COL,name) $name
			set POSN_DESC_ARRAY($ROW,$COL,id) $id
			if {$last_child} {
				set POSN_DESC_ARRAY($ROW,$COL,branching) OC
			} else {
				set POSN_DESC_ARRAY($ROW,$COL,branching) FC
			}
		}
	} else {
		#you are not first child and therefore have empty cols above you (& poss below you) to fill in
		for {set i 0} {$i < $NROWS} {incr i} {
			if {$i == $ROW} {
				set POSN_DESC_ARRAY($i,$COL,name) $name
				set POSN_DESC_ARRAY($i,$COL,id) $id
				if {$last_child} {
					#last child
					set POSN_DESC_ARRAY($i,$COL,branching) LC
				} else {
					#middle child
					set POSN_DESC_ARRAY($i,$COL,branching) NC
				}
			} else {
				set POSN_DESC_ARRAY($i,$COL,name) &nbsp;
				set POSN_DESC_ARRAY($i,$COL,branching) -
			}
		}
	}

	set res [inf_exec_stmt $stmt $id]
	set db_rows [db_get_nrows $res]
	set PARENT_COL $COL
	incr ROW
	set new_row 0
	if {$db_rows > 0 && ($ROW==$NROWS)} {incr NROWS; set new_row 1}
	for {set i 0} {$i < $db_rows} {incr i} {
		if {$i < ($db_rows - 1)} {
			set last_child 0
		} else {set last_child 1}
		go_position_hierarchy_inner $stmt [db_get_col $res $i position_id] [db_get_col $res $i position_name] $last_child $new_row
		if {$i < ($db_rows - 1)} {
			incr COL
			incr NCOLS
		}
	}
	incr ROW -1
	db_close $res

}


proc getCurrentUsersPositionId {} {
	global USERNAME
	return [getUsersPositionIdFromUname $USERNAME]
}


proc getUsersPositionId {user_id} {
	global DB

	set sql [subst {
		select
			position_id
		from
			tAdminuser
		where
			user_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $user_id]

	set result [db_get_col $res 0 position_id]

	inf_close_stmt $stmt
	db_close $res

	return $result
}


proc getUsersPositionIdFromUname {username} {
	global DB

	set sql [subst {
		select
			position_id
		from
			tAdminUser
		where
			username = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $username]
	set result [db_get_col $res 0 position_id]

	inf_close_stmt $stmt
	db_close $res

	return $result
}


#
# ----------------------------------------------------------------------------
# Find out if the logged-in user is a at the root of the hierarchical tree.
# They must have no position_id.
# ----------------------------------------------------------------------------
#
proc is_root_user {} {

	global DB USERNAME

	if {[getCurrentUsersPositionId] == ""} {
		return 1
	}
	return 0
}


#
# ----------------------------------------------------------------------------
# Retrieve all of current users permissions
# ----------------------------------------------------------------------------
#
proc getCurrentUsersPermissions {} {
	global DB USERID

	set sql [subst {
		select action
		from   tAdminUserOp
		where  user_id = ?

		union

		select gop.action
		from   tAdminUserGroup ug,
			   tAdminGroupOp gop
		where  ug.user_id = ? and
			   ug.group_id = gop.group_id

		union

		select gop.action
		from   tAdminPosnGroup pg,
			   tAdminGroupOp gop,
			   tAdminUser u
		where  u.user_id = ? and
			   u.position_id = pg.position_id and
			   pg.group_id = gop.group_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $USERID $USERID $USERID]

	set result [list '-1']
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		lappend result ",'[db_get_col $res $i action]'"
	}

	inf_close_stmt $stmt
	db_close $res

	return $result
}


#
# ----------------------------------------------------------------------------
# Get positions - bind into global AP for display
# ----------------------------------------------------------------------------
#
proc getPositions {} {
	global DB AP

	set sql [subst {
		select
			t1.position_id,
			t1.position_name,
			t2.position_name as parent_posn_name
		from
			tAdminPosition t1,
			outer tAdminPosition t2
		where
			t1.parent_position_id = t2.position_id
		order by
			t1.position_name

	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]
	for {set i 0} {$i < $n_rows} {incr i} {
		set AP($i,pos_id)           [db_get_col $res $i position_id]
		set AP($i,pos_name)         [db_get_col $res $i position_name]
		set AP($i,pos_parent_name)  [db_get_col $res $i parent_posn_name]

	}
	db_close $res

	tpSetVar NumPositions $n_rows

	tpBindVar PosId     AP pos_id          pos_idx
	tpBindVar PosName   AP pos_name        pos_idx
	tpBindVar PosParent AP pos_parent_name pos_idx
}


#
# ----------------------------------------------------------------------------
# Get groups - bind into global AG for display
# ----------------------------------------------------------------------------
#
proc getGroups {} {
	global DB AG

	set sql {
		select
			g.group_id,
			g.group_name,
			g.group_owner,
			u.username
		from
			tAdminGroup g,
			outer tAdminUser  u
		where
			g.group_owner = u.user_id
		order by
			group_name
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {
		set AG($r,group_id)    [db_get_col $res $r group_id]
		set AG($r,group_name)  [db_get_col $res $r group_name]
		set AG($r,group_owner)    [db_get_col $res $r group_owner]
		set AG($r,owner_username) [db_get_col $res $r username]
	}

	db_close $res

	tpSetVar NumGroups $n_rows

	tpBindVar GroupId    AG group_id    group_idx
	tpBindVar GroupName  AG group_name  group_idx
	tpBindVar GroupOwnerId AG group_owner    group_idx
	tpBindVar GroupOwner   AG owner_username group_idx
}


#
# ----------------------------------------------------------------------------
# Get permissions - bind into global AO for display
# ----------------------------------------------------------------------------
#
proc getPermissions {} {
	global DB AO

	set sql {
		select
			action,
			desc,
			type,
			disporder
		from tAdminOp
		order by desc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {
		set AO($r,action)    [db_get_col $res $r action]
		set AO($r,desc)      [db_get_col $res $r desc]
		set AO($r,type)      [db_get_col $res $r type]
		set AO($r,disporder) [db_get_col $res $r disporder]
	}

	inf_close_stmt $stmt
	db_close $res

	tpSetVar NumOps $n_rows
	tpBindVar OpAction  AO action op_idx
	tpBindVar OpDesc    AO desc   op_idx
	tpBindVar OpType    AO type   op_idx
}

##
# DESCRIPTION
#
#	Update the statuses of the users.
##
proc do_activate_suspend_users {} {
	global DB

	OT_LogWrite 12 "==>[info level [info level]]"

	# a list of all the users who should be active
	set active_user_ids	[reqGetArgs active_user_id]
	# a list of pairs for user_id and status
	set user_id_status	[reqGetArgs user_id_status]

	# validate arguments & build array USER
	foreach user_id $active_user_ids {
		if {![string is integer -strict $user_id]} {
			err_bind "The user of user_id '$user_id' must be an integer"
			go_user_list
			return
		}
		OT_LogWrite 12 "Found user $user_id whose future status should be A"
		set USER($user_id) ""
	}
	foreach {user_id_status} $user_id_status {
		# break the pair up
		foreach {user_id status} $user_id_status {}
		OT_LogWrite 12 "Found user $user_id with current status $status"

		if {![string is integer -strict $user_id]} {
			err_bind "The user of user_id '$user_id' must be an integer"
			go_user_list
			return
		}
		if {[lsearch {A S} $status] < 0} {
			err_bind "The status '$status' must be either A or S"
			go_user_list
			return
		}
		# find out if the user's status needs changing and change it
		if {[info exists USER($user_id)] && $status == "S"} {
			# change from suspended to active
			set USER($user_id) "A"
		} elseif {![info exists USER($user_id)] && $status == "A"} {
			# change for active to suspended
			set USER($user_id) "S"
		} elseif {[info exists USER($user_id)]} {
			# no change from active to active, remove it from the list
			unset USER($user_id)
		} else {
			# no change from suspended to suspended, do nothing
		}
	}

	# prepare sql & stmt
	set sql {update tAdminUser set status = ? where user_id = ?}
	set stmt [inf_prep_sql $DB $sql]

	# row by row change users
	foreach {user_id status} [array get USER] {
		OT_LogWrite 12 "Changing the status of user $user_id to $status"
		if {[catch {inf_exec_stmt $stmt $status $user_id} msg]} {
			# an error has occured!
			# gracefully degarde performance - i.e. ignore the error and carry on
			err_bind "Failed to update the status of user $user_id to $status: $msg"
		}
	}

	msg_bind "Changed [array size USER] user's status"

	# don't go back to the same page, because we'd have to recycle the arguments of the
	# query, I don't think the user will mind
	go_user_list
}

# This proc is to check that an override code is unique
# Returns a list [list 1] or [list 0 errormsg]
#
proc _check_override_code {code {user_id ""}} {
	global DB

	# if empty string, its ok
	if {$code == ""} {
		return [list 1]
	}

	set override_code [string toupper [string trim $code]]

	# Check that the override code is 2 upper case letters
	if {[regexp {^[A-Z][A-Z]$} $override_code] == 0} {
		set result [list 0 "Invalid override code. Please try again"]
		return $result
	}

	if {$user_id != ""} {
		set user_string "and user_id != '$user_id'"
	} else {
		set user_string ""
	}

	set sql [subst {
		select
			first 1 user_id
		from
			tAdminUser
		where
			override_code = ?
			$user_string
	}]

	set stmt  [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt $override_code]
	set nrows [db_get_nrows $res]
	db_close $res

	if {$nrows > 0} {
		return [list 0 "The overide code you have chosen is already in use"]
	} else {
		return [list 1]
	}
}

proc _validate_password {pwd_1 pwd_2 username} {

	global DB

	# not blank
	if {$pwd_1 == "" || $pwd_2 == ""} {
		return [list 0 "Password cannot be blank"]
	}

	# they match
	if {$pwd_1 != $pwd_2} {
		return [list 0 "Passwords do not match"]
	}

	# password != username
	if {[string toupper $pwd_1] == [string toupper $username]} {
		return [list 0 "Password can not be the same as username"]
	}

	# password != 'password'
	if {[string toupper $pwd_1] == "PASSWORD"} {
		return [list 0 "Password can not be 'password'."]
	}

	# check length
	set min_length_sql {
		select
			admn_pwd_min_len
		from
			tControl
	}

	set stmt  [inf_prep_sql $DB $min_length_sql]
	set res   [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $res]

	set admn_pwd_min_len [db_get_col $res 0 admn_pwd_min_len]

	db_close $res

	if {[string length $pwd_1] < $admn_pwd_min_len} {
		return [list 0 "Password needs to be at least $admn_pwd_min_len \
		                characters"]
	}

	# contains both upper and lower case letters
	if {[regexp {[A-Z]} $pwd_1]==0 || [regexp {[a-z]} $pwd_1]==0} {
		return [list 0 \
					"Password must contain both upper and lower case letters."]
	}

	# contains non-alphabetical character(s)
	if {[regexp {[^A-Za-z]} $pwd_1]==0} {
		return [list 0 "Password must contain numbers or special characters."]
	}

	return [list 1]
}

# end of namespace
}
