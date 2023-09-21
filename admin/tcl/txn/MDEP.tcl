
# ==============================================================
# $Id: MDEP.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::MDEP {

asSetAct ADMIN::TXN::MDEP::GoTxn   [namespace code go_mdep]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_mdep args {

	global DB

	set mdep_id [reqGetArg op_ref_id]

	set sql {
		select
			m.cr_date,
			m.amount,
			m.method,
			m.extra_info,
			m.code,
			u.username
		from
			tManDepRqst m,
			outer tAdminUser u
		where
			m.mdr_id = ? and
			m.user_id = u.user_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $mdep_id]

	inf_close_stmt $stmt

	tpBindString MDate      [db_get_col $res 0 cr_date]
	tpBindString MAmount    [db_get_col $res 0 amount]
	tpBindString MMethod    [db_get_col $res 0 method]
	tpBindString MExtraInfo [db_get_col $res 0 extra_info]
	tpBindString MCode      [db_get_col $res 0 code]
	tpBindString MUsername  [db_get_col $res 0 username]

	db_close $res

	asPlayFile -nocache txn_drill_mdep.html
}

}
