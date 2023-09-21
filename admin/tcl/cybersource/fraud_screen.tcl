# ==============================================================
# $Id: fraud_screen.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CYBERSOURCE {

asSetAct ADMIN::CYBERSOURCE::GoParams [namespace code go_params]
asSetAct ADMIN::CYBERSOURCE::DoParams [namespace code do_params]

#
# ----------------------------------------------------------------------------
# Got to the "control" page
# ----------------------------------------------------------------------------
#
proc go_params args {

	global DB

	set sql {
		select
			threshold,
			host_hedge,
			time_hedge,
			velocity_hedge,
			category_time,
			category_longterm
		from
			tCyberSource
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString score_threshold         [db_get_col $res 0 threshold]
	tpBindString score_host_hedge        [db_get_col $res 0 host_hedge]
	tpBindString score_time_hedge        [db_get_col $res 0 time_hedge]
	tpBindString score_velocity_hedge    [db_get_col $res 0 velocity_hedge]
	tpBindString score_category_time     [db_get_col $res 0 category_time]
	tpBindString score_category_longterm [db_get_col $res 0 category_longterm]

	db_close $res

	asPlayFile -nocache cybersource/fraud_screen.html
}


#
# ----------------------------------------------------------------------------
# Update control information
# ----------------------------------------------------------------------------
#
proc do_params args {

	global DB USERNAME

	if {![op_allowed ManageCyberSource]} {
		err_bind "You do not have permission to update CyberSource parameters"
		go_params
		return
	}

	set sql [subst {
		update tCyberSource set
			threshold = ?,
			host_hedge = ?,
			time_hedge = ?,
			velocity_hedge = ?,
			category_time = ?,
			category_longterm = ?
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg score_threshold]\
			[reqGetArg score_host_hedge]\
			[reqGetArg score_time_hedge]\
			[reqGetArg score_velocity_hedge]\
			[reqGetArg score_category_time]\
			[reqGetArg score_category_longterm]]} msg]} {
		set bad 1
		err_bind $msg
	}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar UpdateFailed 1
		asPlayFile -nocache cybersource/fraud_screen.html
		return
	}

	go_params
}

}
