# ==============================================================
# $Id: TPB.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::TPB {

asSetAct ADMIN::TXN::TPB::GoTxn   [namespace code go_pool_bet]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_pool_bet args {

	set pool_bet_id [reqGetArg op_ref_id]

	ADMIN::BET::go_pools_receipt bet_id $pool_bet_id
}

}
