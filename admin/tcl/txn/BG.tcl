# $Id: BG.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $

namespace eval ADMIN::TXN::BG {
	asSetAct ADMIN::TXN::BG::GoTxn   [namespace code go_txn]

	proc go_txn args {
		global DB

		set xfer_id [reqGetArg op_ref_id]

		# Redirect them to the table view
		set sql {
			select
				s.tab_id,
				x.game_type
			from
				tBGXfer  x,
				tBGSess  s
			where
				x.xfer_id = ?
				and x.id = s.sess_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $xfer_id]
		inf_close_stmt $stmt

		set tab_id [db_get_col $res 0 tab_id]
		set type   [db_get_col $res 0 game_type]

		db_close $res

		reqSetArg tab_id $tab_id
		reqSetArg type   $type

		ADMIN::BACKGMN::GAME::H_table
	}
}
