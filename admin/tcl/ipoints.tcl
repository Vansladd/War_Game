# ==============================================================
# $Id: ipoints.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IPOINTS {

asSetAct ADMIN::IPOINTS::GoQuery            [namespace code go_ipoints_query]
asSetAct ADMIN::IPOINTS::DoQuery            [namespace code do_ipoints_query]

# Go to the "query" page
#
proc go_ipoints_query args {
	asPlayFile -nocache ipoints_qry.html
}

proc do_ipoints_query args {
	global DB

	# authorise
	if {![op_allowed ViewIPoints]} {
		err_bind "You do not have permission to search ipoints conversions"
		ADMIN::IPOINTS::go_ipoints_query
		return
	}

	# bind post data
	foreach f {
		SR_username
		SR_upper_username
		SR_acct_no_exact
		SR_acct_no
		SR_date_1
		SR_date_2
		SR_date_range
		SR_status
		SR_conversion_id
	} {
		set $f [reqGetArg $f]
		tpBindString $f [subst "$$f"]
	}

	# build sql query
	set where [list {a.acct_id = p.acct_id} {a.cust_id = c.cust_id}]

	if {$SR_username ne ""} {
		if {$SR_upper_username == "Y"} {
			lappend where "c.username_uc like '%[string toupper $SR_username]%'"
		} else {
			lappend where "c.username like '%${SR_username}%'"
		}
	}

	if {$SR_acct_no ne ""} {
		if {$SR_acct_no_exact == "Y"} {
			lappend where "c.acct_no = '$SR_acct_no'"
		} else {
			lappend where "c.acct_no like '$SR_acct_no%'"
		}
	}

	if {$SR_date_range != "" && $SR_date_1 == "" && $SR_date_2 == ""} {
		set now [clock seconds]

		switch -exact -- $SR_date_range {
			"HR" {
				# last hour
				set hour [expr {$now-60*60}]
				set SR_date_1 [clock format $hour -format {%Y-%m-%d %H:%M:%S}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"TD" {
				# today
				set SR_date_1 [clock format $now -format {%Y-%m-%d 00:00:00}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d 23:59:59}]
			}
			"YD" {
				# yesterday
				set yday [expr {$now-60*60*24}]
				set SR_date_1   [clock format $yday -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $yday -format {%Y-%m-%d 23:59:59}]
			}
			"L3" {
				# last 3 days
				set 3day [expr {$now-3*60*60*24}]
				set SR_date_1   [clock format $3day -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"L7" {
				# last 7 days
				set 7day [expr {$now-7*60*60*24}]
				set SR_date_1   [clock format $7day -format {%Y-%m-%d 00:00:00}]
				set SR_date_2   [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			"CM" {
				# this month
				set SR_date_1 [clock format $now -format {%Y-%m-01 00:00:00}]
				set SR_date_2 [clock format $now -format {%Y-%m-%d %H:%M:%S}]
			}
			default {
				set SR_date_1 [set SR_date_2 ""]
			}
		}
	}

	if {$SR_date_1 ne "" && $SR_date_2 ne ""} {
		lappend where "p.cr_date between '$SR_date_1' and '$SR_date_2'"
	}

	if {$SR_status ne ""} {
		lappend where "p.status ='$SR_status'"
	}

	# if search by id, override where clause
	if {[string is integer -strict $SR_conversion_id] && $SR_conversion_id > 0} {
		set where [list {a.acct_id = p.acct_id} \
		                {a.cust_id = c.cust_id} \
		                "p.ipoint_cnv_id = $SR_conversion_id"]
	} 

	# join where clause
	set where [join $where { and }]

	set sql [subst {
		select
			p.ipoint_cnv_id,
			p.cr_date,
			p.bonus_awarded,
			p.ipoint_value,
			p.cash_value,
			p.status,
			p.ret_msg,
			c.username,
			c.acct_no,
			c.cust_id
		from
			tPtIPointCnv p,
			tCustomer c,
			tAcct a
		where
				$where
			order by
				p.cr_date desc;
	}]
	OT_LogWrite INFO "sql: $sql"
	# prepare and execute query
	set stmt  [inf_prep_sql $DB $sql]
	set res   [inf_exec_stmt $stmt]
	set nrows [db_get_nrows $res]
	inf_close_stmt $stmt

	# process resulset
	global DATA
	array set DATA [list]

	for {set r 0} {$r < $nrows} {incr r} {
		set DATA($r,ipoint_cnv_id)   [db_get_col $res $r ipoint_cnv_id]
		set DATA($r,cr_date)         [db_get_col $res $r cr_date]
		set DATA($r,bonus_awarded)   [db_get_col $res $r bonus_awarded]
		set DATA($r,ipoint_value)    [db_get_col $res $r ipoint_value]
		set DATA($r,cash_value)      [db_get_col $res $r cash_value]
		set DATA($r,status)          [db_get_col $res $r status]
		set DATA($r,ret_msg)         [db_get_col $res $r ret_msg]
		set DATA($r,username)        [db_get_col $res $r username]
		set DATA($r,acct_no)         [db_get_col $res $r acct_no]
		set DATA($r,cust_id)         [db_get_col $res $r cust_id]
	}

	# bind template data
	tpBindVar ConversionId    DATA ipoint_cnv_id    pmt_idx
	tpBindVar CrDate          DATA cr_date          pmt_idx
	tpBindVar BonusDate       DATA bonus_awarded    pmt_idx
	tpBindVar IPointValue     DATA ipoint_value     pmt_idx
	tpBindVar CashValue       DATA cash_value       pmt_idx
	tpBindVar Status          DATA status           pmt_idx
	tpBindVar ReturnMessage   DATA ret_msg          pmt_idx
	tpBindVar Username        DATA username         pmt_idx
	tpBindVar AcctNo          DATA acct_no          pmt_idx
	tpBindVar CustId          DATA cust_id          pmt_idx

	# play template
	tpSetVar  NumRows $nrows
	tpBindString CCY USD
	asPlayFile -nocache ipoints_qry_list.html

	# free resultset
	unset DATA
	db_close $res
}

}
