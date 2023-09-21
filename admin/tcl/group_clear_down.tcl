# ==============================================================
# $Id: group_clear_down.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::AUTODBT {

asSetAct ADMIN::AUTODBT::GoGroupClearDown   [namespace code go_group_cleardown]
asSetAct ADMIN::AUTODBT::GoGroupDetails     [namespace code go_group_details]
asSetAct ADMIN::AUTODBT::DoGroupDetails     [namespace code do_group_details]
asSetAct ADMIN::AUTODBT::GoGroupAdd         [namespace code go_group_add]


#
# Display all the clear down groups from tgrpcleardown.
# Play cleardown_groups.html to display the group data, and allow
# each to be clicked, and hence edited (go_group_details)
#
proc go_group_cleardown {} {

	set sql [ subst {
		select
			cd_grp_id,
			cd_grp_name,
			cd_days,
			status
		from
			tGrpClearDown
		order by cd_grp_name
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]

	set rows [db_get_nrows $res]
	tpSetVar NumGrps $rows
	tpBindTcl cd_grp_id      sb_res_data $res grp_idx cd_grp_id
	tpBindTcl cd_grp_name    sb_res_data $res grp_idx cd_grp_name
	tpBindTcl cd_days        sb_res_data $res grp_idx cd_days
	tpBindTcl cd_status      sb_res_data $res grp_idx status

	inf_close_stmt $stmt

	asPlayFile cleardown_groups.html


}

#
# Play cleardown_details.html to show the details of the group
# Allow an update button (to call do_group_details)
#       a  delete button (to call do_group_details)
#       a  back button (to call_do_group_details)
#
proc go_group_details args {

global DAY_ARR
	set grp_id [reqGetArg GroupId]

	set sql [ subst {
		select
			cd_grp_name,
			cd_days,
			status
		from
			tGrpClearDown
		where cd_grp_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt $grp_id]

	set rows [db_get_nrows $res]
	set cd_grp_name [db_get_col $res 0 cd_grp_name]
	set cd_days [db_get_col $res 0 cd_days]
	set cd_status [db_get_col $res 0 status]
	tpBindString GroupId $grp_id
	tpBindString GroupName $cd_grp_name
	tpBindString GroupStatus $cd_status
	make_day_binds $cd_days

   	inf_close_stmt $stmt
	tpSetVar opAdd 0
	asPlayFile cleardown_details.html
}

#
# Called from the add button on cleardown_groups
# Play the group entry screen (cleardown_details.html)
# with an add and back button
#
proc go_group_add args {
	make_day_binds ""
	tpSetVar opAdd 1
	asPlayFile cleardown_details.html
}


#
# Act upon the button press received from cleardown_details.html
# Either an update, delete or back
#
proc do_group_details args {

	set op [reqGetArg SubmitName]

	if {$op == "Update" } {
		do_update_group
		go_group_cleardown
	} elseif {$op == "Activate"} {
		do_activate_suspend_group "A"
		go_group_cleardown
	} elseif {$op == "Suspend"} {
		do_activate_suspend_group "S"
		go_group_cleardown
	} elseif {$op == "Back"} {
		go_group_cleardown
	} elseif {$op == "Add"} {
		do_add_group
		go_group_cleardown
	} else {
		error "Unexpected operation : $op"
	}
}

#
# Bind for the checkboxs which represent the days of the week.
# Build this from a daystring which is the daynumbers concatenated
# together. e.g. weekend is 67, Monday is 1, Weekdays is 12345
#
proc make_day_binds {day_str} {

global DAY_ARR

	set days {{Monday} {Tuesday} {Wednesday} {Thursday} {Friday} {Saturday} {Sunday}}

	catch {unset DAY_ARR}
	array set DAY_ARR [list]
	set no_days 7
	for {set i 0} {$i <= $no_days} {incr i} {
		set DAY_ARR($i,dnum) [expr {$i+1}]
		set DAY_ARR($i,dname) [lindex $days $i]

		set day_checked [string first [expr {$i+1}] $day_str]
		if {$day_checked != -1} {
			set DAY_ARR($i,dsel) CHECKED
		}
	}

	tpSetVar NumDays $no_days

	tpBindVar DayNum DAY_ARR dnum day_idx
	tpBindVar DayName DAY_ARR dname day_idx
	tpBindVar DaySel DAY_ARR dsel day_idx
}

#
# Create a day string (3456) from the day variables (DY_1, DY_2, etc, etc)
# being returned from cleardown_details.html
#
proc make_day_str {{prefix DY_}} {

	set result ""

	for {set i 1} {$i < 8} {incr i} {
		if {[reqGetArg ${prefix}${i}] != ""} {
			append result $i
		}
	}
	return $result
}

#
# Get the group id from the presented args, and set it's status to either
# A - Active or S - Suspended
#
proc do_activate_suspend_group AorS {
	set grp_id [reqGetArg GroupId]

	set sql [subst {
		update tGrpClearDown
		set status=?
		where cd_grp_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res [inf_exec_stmt $stmt $AorS $grp_id]
	catch {db_close $res}
	inf_close_stmt $stmt

}

#
# Update the group details in the db
#
proc do_update_group args {
	set grp_id   [reqGetArg GroupId]
	set grp_name [reqGetArg GroupName]
	set grp_days [make_day_str]
	set status   [reqGetArg GroupStatus]

	set sql [subst {
		update tGrpClearDown set
			cd_grp_name = ?,
			cd_days = ?,
			status = ?
		where
			cd_grp_id = ?
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res [inf_exec_stmt $stmt $grp_name $grp_days $status $grp_id]
	inf_close_stmt $stmt
	db_close $res
}

#
# Add the group details to the db
#
proc do_add_group args {
	set grp_id   [reqGetArg GroupId]
	set grp_name [reqGetArg GroupName]
	set grp_days [make_day_str]
	set status   [reqGetArg GroupStatus]

	set sql [subst {
		insert into tGrpClearDown
			(cd_grp_name, cd_days, status)
			values (?,?,?)
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res [inf_exec_stmt $stmt $grp_name $grp_days $status]
	inf_close_stmt $stmt
	db_close $res
}

}

