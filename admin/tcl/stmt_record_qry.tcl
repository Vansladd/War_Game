# $Id: stmt_record_qry.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C)2008 Orbis Technology Ltd. All rights reserved.
#
# Search of statement records.
#
# Configuration:
#    FUNC_MENU_STMT_RECORD_QUERY
#



namespace eval ADMIN::STMT_RCD {
	asSetAct ADMIN::STMT_RCD::GoStmtRcdQuery [namespace code go_stmt_rcd_qry]
	asSetAct ADMIN::STMT_RCD::DoStmtRcdQuery [namespace code do_stmt_rcd_qry]
}



proc ADMIN::STMT_RCD::go_stmt_rcd_qry {} {

	# bind product_filter info
	make_stmt_prod_filter_bind

	asPlayFile -nocache stmt_record_qry.html

}



proc ADMIN::STMT_RCD::do_stmt_rcd_qry {} {

	global DB STMT_RCD

	# Query parameters
	set where [list]

	set username        [reqGetArg Username]
	set ignorecase      [reqGetArg ignorecase]
	set acct_no         [reqGetArg AcctNo]
	set product_filter  [reqGetArg product_filter]
	set date_range      [reqGetArg DateRange]

	if {$username != ""} {
		if {$ignorecase == "Y"} {
			lappend where "c.username_uc = '[string toupper $username]'"
		} else {
			lappend where "c.username like '%$username%'"
		}
	}
	if {$acct_no != ""} {
		lappend where "c.acct_no = '$acct_no'"
	}
	if {$product_filter != "-1" && $product_filter != ""} {
		lappend where "s.product_filter = '$product_filter'"
	}

	set date_lo   [reqGetArgDflt StmtCrDate1 1990-01-01]
	set date_hi   [reqGetArgDflt StmtCrDate2 2100-01-01]

	if {$date_range != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set date_hi "$Y-$M-$D"
		if {$date_range == "TD"} {
			set date_lo "$Y-$M-$D"
		} elseif {$date_range == "CM"} {
			set date_lo "$Y-$M-01"
		} elseif {$date_range == "YD"} {
			set date_lo [date_days_ago $Y $M $D 1]
			set date_hi "$date_lo"
		} elseif {$date_range == "L3"} {
			set date_lo [date_days_ago $Y $M $D 3]
		} elseif {$date_range == "L7"} {
			set date_lo [date_days_ago $Y $M $D 7]
		}
	}

	lappend where "s.cr_date >= '$date_lo 00:00:00'"
	lappend where "s.cr_date <= '$date_hi 23:59:59'"

	if {[llength $where]} {
		set where " and [join $where { and }]"
	}

	set sql [subst {
		select
			s.stmt_id,
			s.cr_date,
			c.cust_id,
			c.username,
			c.acct_no,
			r.lname,
			s.stmt_num,
			s.date_from,
			s.date_to,
			s.sort,
			s.product_filter
		from
			tStmtRecord s,
			tCustomer c,
			tAcct a,
			tCustomerReg r
		where
			s.acct_id = a.acct_id and
			c.cust_id = r.cust_id and
			c.cust_id = a.cust_id
			$where
		order by
			cr_date asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumStmtRecords [set nrows [db_get_nrows $res]]

	if {$nrows > 0} {
	for {set r 0} {$r < $nrows} {incr r} {
		foreach col [db_get_colnames $res] {
			set STMT_RCD($r,$col) [db_get_col $res $r $col]
			}
		}
	}

	foreach f [db_get_colnames $res] {
		tpBindVar STMT_RCD_${f} STMT_RCD $f stmt_rcd_idx
	}

	tpBindString ColSpan 11

	# rebind search parameters
	tpBindString username       $username
	tpBindString ignorecase     $ignorecase
	tpBindString acct_no        $acct_no
	tpBindString product_filter $product_filter
	tpBindString date_range     $date_range
	tpBindString date_lo        $date_lo
	tpBindString date_hi        $date_hi

	asPlayFile -nocache stmt_record_list.html

	db_close $res

	catch {unset STMT_RCD}

}
