# ==============================================================
# $Id: BIR.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::BIR {

asSetAct ADMIN::TXN::BIR::GoTxn   [namespace code go_bet]


#
# ----------------------------------------------------------------------------
# Generate customer transaction query page
# ----------------------------------------------------------------------------
#
proc go_bet args {

	global DB

	set bir_req_id [reqGetArg op_ref_id]

	set sql {
		select
			r.status,
			r.failure_reason,
			b.bet_id
		from
			tBIRReq r,
			tBIRBet b
		where
			r.bir_req_id = ? and
			r.bir_req_id = b.bir_req_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $bir_req_id]

	inf_close_stmt $stmt
	foreach c [db_get_colnames $res] {
		set $c [db_get_col $res 0 $c]
	}
	db_close $res

	# Show the Bet
	if {$status == "A"} {
		return [ADMIN::BET::go_bet_receipt bet_id $bet_id]
	}

	# Bet failed, show reason.
	# -if an override then get override details
	if {$failure_reason == "OVERRIDES"} {

		tpSetVar OVERRIDE 1

		set sql {
			select
			    o.override,
			    oc.desc as oc_desc,
			    e.desc ev_desc,
			    t.name as type_desc
			from
			    tBIRBet b,
			    tBIROBet o,
			    tEvOc oc,
			    tEv e,
			    tEvType t
			where
			    b.bir_req_id = ?
			and o.bir_bet_id = b.bir_bet_id
			and oc.ev_oc_id = o.ev_oc_id
			and e.ev_id = oc.ev_id
			and t.ev_type_id = e.ev_type_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $bir_req_id]

		inf_close_stmt $stmt
		foreach c [db_get_colnames $res] {
			if {$c == "override"} {
				set override [db_get_col $res 0 $c]
			} else {
				tpBindString $c [db_get_col $res 0 $c]
			}
		}
		db_close $res

		# extract override details
		set override [split $override |]

		switch -- [lindex $override 0] {
			PRC_CHG {
				foreach {c n1 d1 n2 d2} $override { break }
				tpBindString override "Price changed from $n1/$d1 to $n2/$d2"
			}

			HCAP_CHG {
				foreach {c v1 v2} $override { break }
				tpBindString override "Handicap changed from $v1 to $v2"
			}

			BIR_CHG {
				foreach {c v1 v2} $override { break }
				tpBindString override "BIR index changed from $v1 to $v2"
			}

			EW_PLC_CHG {
				foreach {c v1 v2} $override { break }
				tpBindString override "Each/Way place changed from $v1 to $v2"
			}

			EW_PRC_CHG {
				foreach {c n1 d1 n2 d2} $override { break }
				tpBindString override "Each/Way price changed from $n1/$d1 to $n2/$d2"
			}

			default {
				tpBindString override [ob_xl::sprintf en SLIP_ERR_$override]
			}
		}

	} else {

		switch -- $failure_reason {
			TIMEOUT           -
			GET_BET_FAIL      -
			NO_BET            -
			GET_OBET_FAIL     -
			NO_OBET           -
			BET_OVERRIDE_FAIL -
			LEG_OVERRIDE_FAIL -
			SET_BET_ID_FAIL   { set failure_reason SLIP_ERR_BET_DELAY_${failure_reason} }
			default           { set failure_reason SLIP_ERR_${failure_reason} }
		}

		tpBindString failure_reason [ob_xl::sprintf en $failure_reason]
	}

	asPlayFile -nocache txn_drill_bir.html
}
}

