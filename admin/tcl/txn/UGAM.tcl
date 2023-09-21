# ==============================================================
# $Id: UGAM.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::UGAM {

asSetAct ADMIN::TXN::UGAM::GoTxn   [namespace code go_ug_txn]


	#
	# ----------------------------------------------------------------------------
	# Generate customer transaction query page
	# ----------------------------------------------------------------------------
	#
	proc go_ug_txn args {

		global DB
	
		set ref_id [reqGetArg op_ref_id]

		set op_type [reqGetArg op_type_code]

		## If it's a stake then the ref_id is a ug_draw_sub_id
		## If it's a return then the ref_id is a ug_draw_sub_oc_id
		
		if {$op_type == "UGSK"} {
			set GET_UG_SUMMARY_ID {
				select ug_summary_id
				from   tUGDrawSub
				where   ug_draw_sub_id = ?
			}
		} else {
			set GET_UG_SUMMARY_ID {
				select s.ug_summary_id
				from   tUGDrawSub s,
				       tUGDrawSubOc o
				where  o.ug_draw_sub_oc_id = ?
				and    o.ug_draw_sub_id = s.ug_draw_sub_id
			}
		}
		
		set stmt_ug [inf_prep_sql $DB $GET_UG_SUMMARY_ID]
		set rs_ug [inf_exec_stmt $stmt_ug $ref_id]
		reqSetArg ug_summary_id [db_get_col $rs_ug 0 ug_summary_id]

		ug::admin::go_ug_view_bet
	}
}
