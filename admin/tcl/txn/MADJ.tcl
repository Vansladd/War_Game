
# ==============================================================
# $Id: MADJ.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::MADJ {

asSetAct ADMIN::TXN::MADJ::GoTxn   [namespace code go_madj]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_madj args {
	set fn {ADMIN::TXN::MADJ::go_madj}

	global DB

	set madj_id [reqGetArg op_ref_id]

	set sql {
		select
			m.amount,
			m.desc,
			m.cr_date,
			m.ref_key,
			m.ref_id,
			m.oper_notes,
			u.username,
		    nvl(m.batch_ref_id,"Not in batch") batch_ref_id,
		    u1.username as auth_by,
		    m.auth_at,
		    u2.username as post_by,
		    m.post_at
		from
			tManAdj m,
			outer tAdminUser u,
		    outer tAdminUser u1,
		    outer tAdminUser u2
		where
			m.madj_id = ? and
			m.user_id = u.user_id and
			m.auth_by = u1.user_id and
			m.post_by = u2.user_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $madj_id]

	inf_close_stmt $stmt

	tpBindString MDate       [db_get_col $res 0 cr_date]
	tpBindString MDesc       [db_get_col $res 0 desc]
	tpBindString MAmount     [db_get_col $res 0 amount]
	tpBindString MUsername   [db_get_col $res 0 username]
	tpBindString MBatchRefID [db_get_col $res 0 batch_ref_id]
	tpBindString MAuthUser   [db_get_col $res 0 auth_by]
	tpBindString MPostUser   [db_get_col $res 0 post_by]
	tpBindString MAuthAt     [db_get_col $res 0 auth_at]
	tpBindString MPostAt     [db_get_col $res 0 post_at]
	tpBindString OperNotes   [db_get_col $res 0 oper_notes]

	# ManAdj linking.
	tpSetVar     RefKey      [db_get_col $res 0 ref_key]
	tpBindString RefId       [db_get_col $res 0 ref_id]

	db_close $res

	asPlayFile -nocache txn_drill_madj.html
}

}
