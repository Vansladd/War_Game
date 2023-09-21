# $Id: AMSG.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

namespace eval ADMIN::TXN::AMSG {
	asSetAct ADMIN::TXN::AMSG::GoTxn   [namespace code go_txn]

	# forward the request to alerts.tcl
	proc go_txn args {
		reqSetArg AlertMsgId [reqGetArg op_ref_id]

		ADMIN::ALERTS::go_alert_message
	}
}
