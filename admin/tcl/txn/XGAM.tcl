# ==============================================================
# $Id: XGAM.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::XGAM {

asSetAct ADMIN::TXN::XGAM::GoTxn   [namespace code go_xgame_sub]


	#
	# ----------------------------------------------------------------------------
	# Generate customer transaction query page
	# ----------------------------------------------------------------------------
	#
	proc go_xgame_sub args {
	
		set ref_id [reqGetArg op_ref_id]
		
		set op_type_code [reqGetArg op_type_code]
		
		if {$op_type_code == "BSTL" || $op_type_code == "BWIN" || $op_type_code == "BRFD"} {
			ADMIN::BET::go_xgame_receipt bet_id $ref_id
		} else {
			ADMIN::BET::go_xgame_sub_query sub_id $ref_id
		}
	}
}
