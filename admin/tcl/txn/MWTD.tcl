
# ==============================================================
# $Id: MWTD.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::MWTD {

asSetAct ADMIN::TXN::MWTD::GoTxn   [namespace code go_mwtd]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_mwtd args {

	global DB

	set mwtd_id [reqGetArg op_ref_id]

	set sql {
		select
			m.cr_date,
			m.amount,
			m.commission,
			m.status,
			m.method,
			m.extra_info,
			m.code,
			m.location,
			m.collect_time,
			u.username
		from
			tManWtdRqst m,
			outer tAdminUser u
		where
			m.mwr_id = ? and
			m.user_id = u.user_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $mwtd_id]

	inf_close_stmt $stmt

	tpBindString MDate         [db_get_col $res 0 cr_date]
	tpBindString MAmount       [db_get_col $res 0 amount]
	tpBindString MCommission   [db_get_col $res 0 commission]
	tpBindString MStatus       [db_get_col $res 0 status]
	tpBindString MMethod       [db_get_col $res 0 method]
	tpBindString MExtraInfo    [db_get_col $res 0 extra_info]
	tpBindString MCode         [db_get_col $res 0 code]
	tpBindString MLocation     [db_get_col $res 0 location]
	tpBindString MColleactTime [db_get_col $res 0 collect_time]
	tpBindString MUsername     [db_get_col $res 0 username]

	db_close $res

	asPlayFile -nocache txn_drill_mdep.html
}

}
