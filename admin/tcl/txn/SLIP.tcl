# ==============================================================
# $Id: SLIP.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::SLIP {

asSetAct ADMIN::TXN::SLIP::GoTxn   [namespace code go_slip]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_slip args {

	set slip_id [reqGetArg op_ref_id]

	ADMIN::SLIP::go_slip_receipt slip_id $slip_id
}

}