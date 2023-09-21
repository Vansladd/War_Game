#-------------------------------------------------------------------------------
# Copyright (C) 2005 Orbis Technology Ltd.  All rights reserved.
#-------------------------------------------------------------------------------
# $Id: cust_promotions.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#-------------------------------------------------------------------------------

namespace eval ADMIN::CUST::PROMOTIONS {

	asSetAct ADMIN::CUST::PROMOTIONS::go_promotion [namespace code go_promotion]
	asSetAct ADMIN::CUST::PROMOTIONS::DoPromotion [namespace code do_promotion]
	asSetAct ADMIN::CUST::PROMOTIONS::DoPromoTxnQuery [namespace code do_txn_hist]
}

proc ADMIN::CUST::PROMOTIONS::go_promotion {cust_id promotion_id} {

	global DB CUST_PROMO

	##
	## As points are earned they are decremented
	## rather than incremented.
	## This is so that customers are always
	## trying to reach the target that was the
	## target when they initially started the promotion (as
	## it's possible to change it).
	## So total_points is the total points needed rather than
	## total_points that a customer has.
	##
	set stmt [inf_prep_sql $DB {

		select
			pc.points_target,
			pc.cr_date,
			pc.status,
			pc.total_points,
			pc.total_stake,
			pc.cum_min_stake,
			p.name,
			c.acct_no,
			c.username
		from 
			tPromoCust pc,
			tPromotion p,
			tCustomer c
		where 
			pc.cust_id = ? and
			pc.cust_id = c.cust_id and
			pc.promotion_id = ? and
			pc.promotion_id = p.promotion_id
		order by 
			cr_date
	}]

	set ok 1

	if { [catch {
		set rs [inf_exec_stmt $stmt $cust_id $promotion_id]
	} err] } {

		OT_LogWrite 1 "ADMIN::CUST::PROMO::go_promotion:\
			query failed for cust_id #$cust_id: $err"

		err_bind "ADMIN::CUST::PROMO::go_promotion:\
			query failed for cust_id #$cust_id: $err"

		set ok 0

	}

	inf_close_stmt $stmt

	if { !$ok } {
		return
	}

	set columns [db_get_colnames $rs]

	foreach col $columns {
		set CUST_PROMO($col) [db_get_col $rs $col]
	}

	db_close $rs

	foreach col $columns {
		tpBindVar PROMO_$col CUST_PROMO $col
	}
	
	tpBindString PROMO_cust_id $cust_id
	tpBindString Promo_promotion_id $promotion_id

	tpBindString PROMO_cust_id $cust_id
	tpBindString Promo_promotion_id $promotion_id

	asPlayFile -nocache cust_promotion.html
}

proc ADMIN::CUST::PROMOTIONS::do_promotion args {

	set cust_id [reqGetArg CustId]
	set promo_id [reqGetArg PromoId]

	set act [reqGetArg SubmitName]

	switch $act {
		
		"Update" {
			update_cust_promo
			go_promotion $cust_id $promo_id
		}
		"Delete" {
			delete_cust_promo
			ADMIN::CUST::go_cust
			return
		}
		"Back" {
			ADMIN::CUST::go_cust
			return
		}
	}
}


proc ADMIN::CUST::PROMOTIONS::update_cust_promo args {

	global DB

	set status [reqGetArg status]
	set cust_id [reqGetArg CustId]
	set promotion_id [reqGetArg PromoId]

	set stmt [inf_prep_sql $DB {

		update tPromoCust
			set 
			status = ?
		where 
			cust_id = ? and
			promotion_id = ?
	}]

	if { [catch {
		set rs [inf_exec_stmt $stmt \
								$status \
								$cust_id $promotion_id]
	} err] } {

		OT_LogWrite 1 "ADMIN::CUST::PROMO::update_cust_promo:\
			query failed for cust_id #$cust_id: $err"

		err_bind "ADMIN::CUST::PROMO::update_cust_promo:\
			query failed for cust_id #$cust_id: $err"
	} else {
		msg_bind "Details Updated Successfully"
	}

	inf_close_stmt $stmt
}

proc ADMIN::CUST::PROMOTIONS::delete_cust_promo args {

	global DB

	set cust_id [reqGetArg CustId]
	set promo_id [reqGetArg PromoId]

	set stmt [inf_prep_sql $DB {

		delete from tPromoCust
		where 
			cust_id = ? and
			promotion_id = ?
	}]

	if { [catch {
		set rs [inf_exec_stmt $stmt \
								$cust_id $promotion_id]
	} err] } {

		OT_LogWrite 1 "ADMIN::CUST::PROMO::update_cust_promo:\
			query failed for cust_id #$cust_id: $err"

		err_bind "ADMIN::CUST::PROMO::update_cust_promo:\
			query failed for cust_id #$cust_id: $err"
	}

	inf_close_stmt $stmt

}

proc ADMIN::CUST::PROMOTIONS::do_txn_hist args {

		global DB PROMO_TXN

		if {[set TxnsPerPage [reqGetArg TxnsPerPage]] == ""} {
				set TxnsPerPage 25
		}                                                                                                                                                    
		tpBindString CustId      [set CustId      [reqGetArg CustId]]
		tpBindString PromoId	 [set PromoId	  [reqGetArg PromoId]]
		tpBindString Username    [set Username    [reqGetArg Username]]
		tpBindString AcctNo      [set AcctNo      [reqGetArg AcctNo]]
		tpBindString TxnsPerPage $TxnsPerPage
		tpBindString HiCrDate    [set HiCrDate    [reqGetArg HiCrDate]]
		tpBindString LoCrDate    [set LoCrDate    [reqGetArg LoCrDate]]

		set sort [reqGetArg SubmitName]

		if {$sort == "Customer" || $sort == "CustBack"} {
			ADMIN::CUST::go_cust cust_id $CustId
			return
		} elseif {$sort == "Back"} {
			go_promotion $CustId $PromoId
			return
		}

		set where_dt ""

		if {$sort == "First"} {
				set dt1 [reqGetArg TxnDate1]
				set dt2 [reqGetArg TxnDate2]

		if {($dt1 != "") || ($dt2 != "")} {
				set btn [mk_between_clause j.cr_date date $dt1 $dt2]
				set where_dt " and $btn"
		}
				set order desc
		} elseif {$sort == "Next"} {
				set where_dt " and j.cr_date < '$LoCrDate'"
				set order desc
		} else {
				set where_dt " and j.cr_date > '$HiCrDate'"
				set order asc
		}

		set sql [subst {
				select first $TxnsPerPage
						j.cr_date,
						j.pc_jrnl_id
				from
						tpromocustjrnl j,
						tpromocust p
				where
						j.promo_cust_id = p.promo_cust_id and
						p.cust_id = ? $where_dt
				order by
						j.cr_date $order
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $CustId]
		inf_close_stmt $stmt

		set n_rows [db_get_nrows $res]

		if {$n_rows > 0} {

			if {$order == "asc"} {
					set dt_0 [db_get_col $res 0 cr_date]
					set dt_1 [db_get_col $res [expr {$n_rows-1}] cr_date]
			} else {
					set dt_0 [db_get_col $res [expr {$n_rows-1}] cr_date]
					set dt_1 [db_get_col $res 0 cr_date]
			}

			db_close $res

			set sql [subst {
					select
							j.cr_date,
							j.pc_jrnl_id,
							j.points,
							case when (j.pc_jrnl_type == 'C') then
							"Claimed"
							else "Modified"
							end as pc_jrnl_type,
							j.stake,
							j.total_points,
							j.total_stake,
							j.cum_min_stake
					from
							tpromocustjrnl j,
							tpromocust p
					where
							j.promo_cust_id = p.promo_cust_id and
							j.cr_date between '$dt_0' and '$dt_1' and
							p.cust_id = ?
					order by
							j.pc_jrnl_id $order, j.cr_date $order
			}]

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $CustId]
			inf_close_stmt $stmt

			set n_rows [db_get_nrows $res]
		}

		tpSetVar NumTxns $n_rows

		if {$n_rows > 0} {

				set dt_0 [db_get_col $res 0 cr_date]
				set dt_1 [db_get_col $res [expr {$n_rows-1}] cr_date]

			if {$order == "asc"} {
					tpBindString LoCrDate $dt_0
					tpBindString HiCrDate $dt_1

					set l_start 0
					set l_op    <=
					set l_end   [expr {$n_rows-1}]
					set l_inc   1
					set date_to_use $dt_0

			} else {
					tpBindString LoCrDate $dt_1
					tpBindString HiCrDate $dt_0

					set l_start [expr {$n_rows-1}]
					set l_op    >=
					set l_end   0
					set l_inc   -1
					set date_to_use $dt_1
			}

			set row [expr {$n_rows-1}]
			for {set r $l_start} {[expr "$r $l_op $l_end"]} {incr r $l_inc} {

				set PROMO_TXN($row,date) [db_get_col $res $r cr_date]
				set PROMO_TXN($row,pc_jrnl_id) [db_get_col $res $r pc_jrnl_id]
				set PROMO_TXN($row,points) [db_get_col $res $r points]
				set PROMO_TXN($row,pc_jrnl_type) [db_get_col $res $r pc_jrnl_type]
				set PROMO_TXN($row,stake) [db_get_col $res $r stake]
				set PROMO_TXN($row,total_points) [db_get_col $res $r total_points]
				set PROMO_TXN($row,total_stake) [db_get_col $res $r total_stake]
				set PROMO_TXN($row,cum_min_stake) [db_get_col $res $r cum_min_stake]

				incr row -1
			}
		}

		db_close $res

		tpBindVar PROMO_date PROMO_TXN date i
		tpBindVar PROMO_pc_jrnl_id PROMO_TXN pc_jrnl_id i
		tpBindVar PROMO_points PROMO_TXN points i
		tpBindVar PROMO_pc_jrnl_type PROMO_TXN pc_jrnl_type i	
		tpBindVar PROMO_stake PROMO_TXN stake i
		tpBindVar PROMO_total_points PROMO_TXN total_points i
		tpBindVar PROMO_total_stake PROMO_TXN total_stake i
		tpBindVar PROMO_cum_min_stake PROMO_TXN cum_min_stake i

		asPlayFile -nocache cust_promo_txn_list.html
		
}

#-------------------------------------------------------------------------------
# vim:noet:ts=4:sts=4:sw=4:tw=80:ft=tcl:ff=unix:
#-------------------------------------------------------------------------------
