# ==============================================================
# $Id: XSYS.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::XSYS {

asSetAct ADMIN::TXN::XSYS::GoTxn   [namespace code go_xsys]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_xsys args {

	global DB

	set xfer_id   [reqGetArg op_ref_id]

	set sql {
		select
			h.name,
			x.cr_date,
			a.ccy_code,
			x.amount,
			x.status,
			x.remote_action,
			x.remote_ref,
			x.remote_acct,
			x.remote_unique_id,
			x.desc,
			NVL(s.xsys_sub_id,'') as sub_id
		from
			tXSysXfer x,
			tAcct a,
			tXSysHost h,
			outer tXSysSubXfer s
		where
			x.xfer_id = ?
		and
			x.acct_id = a.acct_id
		and
			x.system_id = h.system_id
		and
			x.xfer_id = s.xfer_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $xfer_id]

	inf_close_stmt $stmt

	tpBindString XSysName           [html_encode [db_get_col $res 0 name]]
	tpBindString XSysSubId          [db_get_col $res 0 sub_id]
	tpBindString XSysDate           [db_get_col $res 0 cr_date]

	# use AcctCcyCode not XSysCcyCode as the latter implies it's the xsys's ccy, which
	# is not necessarily so
	tpBindString AcctCcyCode        [db_get_col $res 0 ccy_code]
	tpBindString XSysAmount         [db_get_col $res 0 amount]
	tpBindString XSysStatus         [db_get_col $res 0 status]
	tpBindString XSysRemoteAction   [html_encode [db_get_col $res 0 remote_action]]
	tpBindString XSysRemoteRef      [html_encode [db_get_col $res 0 remote_ref]]
	tpBindString XSysRemoteAcct     [html_encode [db_get_col $res 0 remote_acct]]
	tpBindString XSysRemoteUniqueId [html_encode [db_get_col $res 0 remote_unique_id]]
	tpBindString XSysDesc           [html_encode [db_get_col $res 0 desc]]

	db_close $res

	asPlayFile -nocache txn_drill_xsys.html
}

}
