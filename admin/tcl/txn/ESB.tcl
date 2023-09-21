# ==============================================================
# $Id: ESB.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::ESB {

asSetAct ADMIN::TXN::ESB::GoTxn   [namespace code go_bet]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_bet args {

	set bet_id [reqGetArg op_ref_id]

	ADMIN::BET::go_bet_receipt bet_id $bet_id
}

}
