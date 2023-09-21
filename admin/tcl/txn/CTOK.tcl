# $Id: CTOK.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# CTOK.tcl
# Displays details about a cash token
#


namespace eval ADMIN::TXN::CTOK {
	asSetAct ADMIN::TXN::CTOK::GoTxn [namespace code go_txn]
}



#
#
proc ADMIN::TXN::CTOK::go_txn args {
	set op_ref_id [reqGetArg op_ref_id]

	if {$op_ref_id == ""} {
		tpBindString ERROR "No op_ref_id parameter passed"	
		asPlayFile -nocache txn_drill_ctok.html
		return
	}

	set sql "
		select
			r.redemption_amount,
			case
				when
					r.redemption_type = 'CASH'
				then 
					''
				else
					'(Non Withdrawable)'
			end as type,
			r.cr_date,	
			c.username,
			a.ccy_code,
			o.offer_id,
			o.name 
		from
			tacct a,
			tcustomer c,
			tcustomertoken ct,
			toffer o,	
			tcusttokredemption r,
			ttoken t
		where
			ct.cust_token_id = $op_ref_id
		and
			r.cust_token_id = ct.cust_token_id
		and
			c.cust_id = ct.cust_id
		and
			a.cust_id = ct.cust_id
		and
			t.token_id = ct.token_id
		and
			o.offer_id = t.offer_id
	"

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {![db_get_nrows $rs]} {
		db_close $rs	
		tpBindString ERROR "No rows found"
		asPlayFile txn_drill_ctok.html
		return
	}

	foreach col [db_get_colnames $rs] {
		tpBindString $col [db_get_col $rs 0 $col]
	}

	db_close $rs
	
	asPlayFile -nocache txn_drill_ctok.html
}
