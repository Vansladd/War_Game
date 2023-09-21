# ==============================================================
# $Id: tb_statement.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================


#
# WARNING: file will be initialised at the end of the source
#


namespace eval tb_statement {

# supported j_op_types:
# DEP
# WTD
# RWTD
# DREF
# WREF
# DRES
# WRES
# DCAN
# WCAN
# BSTK
# BSTL
# MAN
# XFER
# LB--
# LB++

namespace export init_tb_statement

namespace export tb_stmt_next_n_weekly
namespace export tb_stmt_next_n_monthly


#
# adding, modifying, deleting statement params
#
namespace export tb_stmt_add
namespace export tb_stmt_del
namespace export tb_stmt_upd
namespace export tb_stmt_upd_ext



namespace export get_acct_stmt_params
namespace export get_next_stmt_dates
namespace export tb_stmt_get_info
namespace export tb_stmt_count
namespace export tb_stmt_acct_has_stmt

namespace export insert_stmt_record

#
# time function
#
namespace export tb_stmt_get_time

variable MSG
variable Weekdays

set Weekdays(Sun) 1
set Weekdays(Mon) 2
set Weekdays(Tue) 3
set Weekdays(Wed) 4
set Weekdays(Thu) 5
set Weekdays(Fri) 6
set Weekdays(Sat) 7


proc init_tb_statement {} {

	OT_LogWrite 5 "==> init_tb_statement"
	global SHARED_SQL

	set SHARED_SQL(tb_stmt_delete) {
		delete from
			tAcctStmt
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_add) {
		insert into tacctstmt
		(
			acct_id,
			status,
			brief,
			dlv_method,
			freq_unit,
			freq_amt,
			due_from,
			due_to
		)
		values
		(
			?, ?, ?, ?, ?, ?, ?, ?
		)
	}

	set SHARED_SQL(tb_stmt_upd) {
		update tacctstmt set
			status = ?,
			brief = ?,
			dlv_method = ?,
			freq_unit = ?,
			freq_amt = ?,
			due_from = ?,
			due_to = ?
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_upd_ext) {
		update tacctstmt set
			pull_status = ?,
			pull_reason = ?,
			cust_msg_1 = ?,
			cust_msg_2 = ?,
			cust_msg_3 = ?,
			cust_msg_4 = ?,
			remove_msg = ?
		where
			acct_id = ?
	}

	if {[OT_CfgGet STMTS_EFFECTIVE_TO 0]} {
		set SHARED_SQL(tb_stmt_effective_to) {
			update tacctstmt set
				pull_to_date = ?
			where
				acct_id = ?
		}
	}

	set SHARED_SQL(tb_stmt_get_freq) {
		select
			freq_unit,
			freq_amt
		from
			tAcctStmt
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_previous) {
		select
			date_to
		from
			tStmtRecord
		where
			acct_id = ? and
			sort = 'R'
		order by
			date_to DESC
	}

	set SHARED_SQL(tb_stmt_count) {
		select
			stmt_num
		from
			tStmtRecord
		where
			acct_id = ?
		order by
			stmt_num DESC
	}

	#
	# insert row into tStmtRecord
	#
	set SHARED_SQL(tb_stmt_insert_record) {
		insert into tStmtRecord (
			acct_id,
			stmt_num,
			date_from,
			date_to,
			sort,
			dlv_method,
			brief,
			cust_msg_1,
			cust_msg_2,
			cust_msg_3,
			cust_msg_4,
			pmt_amount,
			pmt_method,
			pmt_desc,
			pull_status,
			pull_reason,
			printed,
			review_date,
			product_filter
		) values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	}

	set SHARED_SQL(tb_stmt_acct_has_stmt) {
		select
			acct_id
		from
			tAcctStmt
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_info) {
		select
			status,
			brief,
			dlv_method,
			freq_unit,
			freq_amt,
			due_from,
			due_to
		from
			tAcctStmt
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_find_pmt_made) {
		select {INDEX (tjrnl ijrnl_x2)}
		first 1
			jrnl_id,
			j_op_ref_key,
			j_op_ref_id,
			amount,
			(cr_date + interval (1) day to day) as cr_date_plus_1
		from
			tJrnl
		where
			acct_id = ? and
			(cr_date + interval (1) day to day) > ? and
			j_op_type = 'DWTD'
		order by
			cr_date_plus_1 desc, jrnl_id desc
	}

	set SHARED_SQL(tb_stmt_get_CDT_acct_params) {
		select
			min_settle,
			pay_pct
		from
			tAcct
		where
			acct_id = ?
	}

	set SHARED_SQL(tb_stmt_get_sum_ap_at_time) {
		select first 1
			ap_balance,
			cr_date,
			appmt_id
		from
			tAPPmt
		where
			acct_id = ? and
			cr_date <= ?
		order by cr_date desc, appmt_id desc
	}

	set SHARED_SQL(tb_stmt_get_historic_balance) {
		select {INDEX (tjrnl ijrnl_x2)}
		first 1
			balance,
			cr_date,
			jrnl_id
		from
			tJrnl
		where
			acct_id = ? and
			cr_date < ?
		order by
			cr_date desc, jrnl_id desc
	}

	set SHARED_SQL(tb_stmt_get_quick_historic_balance) {
		select {INDEX (tjrnl ijrnl_x2)}
		first 1
				balance,
				cr_date,
				jrnl_id
		from
				tJrnl
		where
				acct_id = ? and
				cr_date between ? and ?
		order by
				cr_date desc, jrnl_id desc
	}

	if {[OT_CfgGet STMT_CONTROL 0]} {
		set SHARED_SQL(tb_get_stmt_control) {
			select
				sched_date,
				sched_date_two,
				freq_unit,
				freq_amt
			from
				tStmtControl
			where
				acct_type = ?
		}
		set SHARED_SQL(tb_get_stmt_control,cache) 600
	}

	if {[OT_CfgGet STMT_CONTROL 0]} {
		set SHARED_SQL(tb_upd_stmt_control) {
			update tStmtControl
			set
				sched_date    = ?,
				deferred_date = null
			where
				acct_type     = ?
		}
	}

	if {[OT_CfgGet STMT_CONTROL 0]} {
		set SHARED_SQL(tb_upd_stmt_control_two) {
			update tStmtControl
			set
				sched_date_two    = ?,
				deferred_date = null
			where
				acct_type     = ?
		}
	}

	if {[OT_CfgGet FUNC_DEBT_MANAGEMENT 0]} {
		set SHARED_SQL(tb_get_stmt_review_date) {
			select
				flag_value
			from
				tCustomerFlag s,
				tAcct a
			where
				a.acct_id = ? and
				a.cust_id = s.cust_id and
				flag_name = 'ChaseArrGrace'
		}
	}

	if {[OT_CfgGet STATEMENT_BATCH 0]} {
		set SHARED_SQL(tb_get_num_sched_type) {
			select
				count(*) as count
			from
				tAcctStmt
			where
				due_to  = ?
		}
	}


	OT_LogWrite 5 "<== init_tb_statement"
}


# Populate the STMT_CONTROL array with the details from the stmt control
#
proc tb_get_stmt_control {acct_type} {

	variable STMT_CONTROL

	array unset STMT_CONTROL

	# If the statement control is configured on, then grab the details out of the DB
	# and use them in place of the ones that we made up ourselves.
	#
	if {![OT_CfgGet STMT_CONTROL 0] || \
		[lsearch [OT_CfgGet STATEMENT_CONTROL_ACCT_TYPES] $acct_type] == -1} {
		return
	}

	set rs [tb_db::tb_exec_qry tb_get_stmt_control $acct_type]
	set sched_date      [db_get_col $rs 0 sched_date]
	set freq_unit       [db_get_col $rs 0 freq_unit]
	set freq_amt        [db_get_col $rs 0 freq_amt]
	set current_date    [clock format [clock scan today] \
			-format {%Y-%m-%d %H:%M:%S}]


	while {$sched_date <= $current_date} {
		set sched_date [tb_get_next_sched_date $sched_date $freq_unit $freq_amt $current_date]
		db_close [tb_db::tb_exec_qry tb_upd_stmt_control $sched_date $acct_type]
	}

	if {[OT_CfgGet STATEMENT_BATCH 0]} {
		set sched_date_two  [db_get_col $rs 0 sched_date_two]
		while {$sched_date_two <= $current_date} {
			set sched_date_two [tb_get_next_sched_date $sched_date_two $freq_unit $freq_amt $current_date]
			db_close [tb_db::tb_exec_qry tb_upd_stmt_control_two $sched_date_two $acct_type]
		}
		set STMT_CONTROL(sched_date_two)   $sched_date_two
	}

	db_close $rs

	set STMT_CONTROL(sched_date)       $sched_date
	set STMT_CONTROL(freq_unit)        $freq_unit
	set STMT_CONTROL(freq_amt)         $freq_amt
}



proc tb_get_next_sched_date {sched_date freq_unit freq_amt current_date} {

	OT_LogWrite 4 "Sched : $sched_date freq: $freq_unit  amt: $freq_amt"

		# otherwise add units of freq_amt freq_unit
		# until the time is greater than the run date
		set next_scan [clock scan $sched_date]
		set next_date $sched_date
		set run_scan  [clock scan $current_date]

		while {$next_scan <= $run_scan} {
			OT_LogWrite 4 "next_scan $next_scan next_date $next_date run_scan $run_scan"
			set next_scan [clock scan "$next_date + $freq_amt \
					[string map [list D days W weeks M months] $freq_unit]"]
			set next_date [clock format $next_scan -format {%Y-%m-%d}]
		}

	OT_LogWrite 4 "next_sched_date returning $next_date"
	return $next_date
}



proc tb_stmt_get_time {} {

	return [clock seconds]

	#
	# use this to artificially set the time (debugging)
	#
	set date "2001-01-07 00:00:00"
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $date all yr mn dy hh mm ss]} {
		error "date wrong format"
	}
	return [clock scan "$mn/$dy/$yr $hh:$mm:$ss"]
}


#
# calculates the next weekly statement date
#
proc tb_stmt_next_weekly {{after_date ""}} {

	variable Weekdays

	#
	# retrieve stmt day from config file (sunday is default)
	#
	set pb [OT_CfgGet PERIOD_BOUNDARY_WEEK 1]

	# get reference day (if not passed in then use current time)
	if {$after_date == ""} {
		set wait_time	[clock format [tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]
  	} else {
		set wait_time 	$after_date
   	}

	# split date
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $wait_time all yr mn dy hh mm ss]} {
		error "date wrong format"
	}

	set wait_day $Weekdays([clock format [clock scan "$mn/$dy/$yr"] -format "%a"])


	# calculate how many days away from next statement date
	set diff [expr $pb - $wait_day]
	if {$diff <= 0} {
		set diff [expr $diff + 7]
	}

	set next_date [clock format [clock scan "$mn/$dy/$yr 00:00:00 $diff day"] -format "%Y-%m-%d"]
	set diff 0
	if {![regexp {^(....)-(..)-(..)$} $next_date all yr mn dy]} {
		error "date wrong format"
	}

	# check bi-weekly option
	if {[OT_CfgGet STMT_FORCE_BI_WEEKLY 0] != 0} {

		if {[even_week $yr $mn $dy] != [expr [OT_CfgGet STMT_FORCE_BI_WEEKLY] -1]} {
			#
			# add 7 days
			#
			set diff [expr $diff + 7]
		}
	}

	# What's the date in '$difference' days from now?
	set next_date [clock format [clock scan "$mn/$dy/$yr 00:00:00 $diff day"] -format "%Y-%m-%d %H:%M:%S"]

	return $next_date
}

#
# calculates the next monthly statement date
#
proc tb_stmt_next_monthly {{after_date ""}} {

	OT_LogWrite 5 "==> tb_stmt_next_monthly"
	OT_LogWrite 5 "after_date:  $after_date"

	#
	# retrieve stmt day from config file (the 1st is default)
	#
	set pb [OT_CfgGet PERIOD_BOUNDARY_MONTH 1]


	#
	# get reference day (if not passed in then use current time)
	#
	if {$after_date == ""} {
		set wait_time [clock format [tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]
	} else {
		set wait_time $after_date
	}

	OT_LogWrite 5 "wait_time:  $wait_time"

	#
	# split date
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $wait_time all yr mn dy hh mm ss]} {
		error "date wrong format"
	}

	#
	# get the scans for the period bound and the wait time to compare
	#
	set pb_scan_cmp	[clock scan "$mn/$pb/$yr 00:00:00 1 second ago"]
	set wt_scan [clock scan "$mn/$dy/$yr $hh:$mm:$ss"]

	set pb_scan	[clock scan "$mn/$pb/$yr 00:00:00"]

	#if {$wt_scan > $pb_scan_cmp} {}
	if {[expr [string trim $pb 0] <= [string trim $dy 0]]} {
		#
		# add on a month
		#
		OT_LogWrite 5 "adding 1 month"
		set next_stmt_scan [clock scan [clock format $pb_scan -format "%m/%d/%Y %H:%M:%S 1 month"]]
		set next_stmt_date [clock format $next_stmt_scan -format "%Y-%m-%d %H:%M:%S"]
	} else {
		#
		# don't add on a month
		#
		set next_stmt_date [clock format $pb_scan -format "%Y-%m-%d %H:%M:%S"]
	}

	OT_LogWrite 5 "next_stmt_date:  $next_stmt_date"
	return $next_stmt_date
}


#
# calculates the next n weekly statement dates
#
proc tb_stmt_next_n_weekly {num_weeks DATA_OUT} {

	upvar 1 $DATA_OUT OUT

	# retrieve statement day from the db
	set next_date    [tb_stmt_next_weekly]

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $next_date all yr mn dy hh mm ss]} {
		error "date wrong format"
	}

	for {set i 0} {$i < $num_weeks} {incr i} {

		if {[OT_CfgGet STMT_FORCE_BI_WEEKLY 0]} {
			set weeks_to_add [expr $i * 2]
		} else {
			set weeks_to_add $i
		}

		set OUT(W,$i,day)	[clock format [clock scan "$mn/$dy/$yr $weeks_to_add week"] -format "%d"]
		set OUT(W,$i,mnth)	[clock format [clock scan "$mn/$dy/$yr $weeks_to_add week"] -format "%m"]
		set OUT(W,$i,year)	[clock format [clock scan "$mn/$dy/$yr $weeks_to_add week"] -format "%Y"]
		set OUT(W,$i,date)  "$OUT(W,$i,year)-$OUT(W,$i,mnth)-$OUT(W,$i,day)"
	}
}


#
# calculates the next n monthly statement dates
#
proc tb_stmt_next_n_monthly {num_months DATA_OUT} {

	upvar 1 $DATA_OUT OUT

	#
	# retrieve next monthly statement day from the db
	#
	set next_date    [tb_stmt_next_monthly]

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $next_date all yr mn dy hh mm ss]} {
		error "date wrong format"
	}

	#
	# add the months on
	#
	for {set i 0} {$i < $num_months} {incr i} {

		set OUT(M,$i,day)	[clock format [clock scan "$mn/$dy/$yr $i month"] -format "%d"]
		set OUT(M,$i,mnth)	[clock format [clock scan "$mn/$dy/$yr $i month"] -format "%m"]
		set OUT(M,$i,year)	[clock format [clock scan "$mn/$dy/$yr $i month"] -format "%Y"]
		set OUT(M,$i,date)	"$OUT(M,$i,year)-$OUT(M,$i,mnth)-$OUT(M,$i,day)"
	}
}

proc get_acct_stmt_params {acct_id DATA_OUT} {

	upvar 1 $DATA_OUT OUT

	#
	# retrieve accounts statement information
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_freq $acct_id]} msg] {
		OT_LogWrite 5 "Failed to retrieve accounts statement information: $msg"
		return 0
	}
	if {[db_get_nrows $rs] == 0} {
		OT_LogWrite 5 "There is no statement defined for this account"
		return 0
	}

	set OUT(freq_unit)		[db_get_col $rs 0 freq_unit]
	set OUT(freq_amt)		[db_get_col $rs 0 freq_amt]
	set OUT(pv_date)		[get_pv_date $acct_id]
	set OUT(enforce_period) 1

	db_close $rs

	return 1
}

proc tb_stmt_get_info {acct_id DATA_OUT} {

	upvar 1 $DATA_OUT OUT

	#
	# retrieve accounts statement information
	#

	if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_info $acct_id]} msg] {
		return 0
	}
	if {[db_get_nrows $rs] == 0} {
		set OUT(stmt_on) "N"
		db_close $rs
		return 0
	}
	set OUT(stmt_on)		"Y"
	set OUT(freq_unit)		[db_get_col $rs 0 freq_unit]
	set OUT(freq_amt)		[db_get_col $rs 0 freq_amt]
	set OUT(dlv_method)		[db_get_col $rs 0 dlv_method]
	set OUT(brief)			[db_get_col $rs 0 brief]
	set OUT(due_from)		[db_get_col $rs 0 due_from]
	set OUT(due_to)			[db_get_col $rs 0 due_to]
	set OUT(status)			[db_get_col $rs 0 status]

	db_close $rs
	return 1
}

proc get_pv_date {acct_id} {

	#
	# retrieve previous statement information
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_stmt_get_previous $acct_id]} msg] {
		OT_LogWrite 5 "Failed to retrieve previous statement information: $msg"
		return ""
	}

	set date_to ""
	if {[db_get_nrows $rs] != 0} {
		set date_to [db_get_col $rs date_to]
	}

	db_close $rs
	return $date_to
}

proc get_next_stmt_dates {DATA} {

	OT_LogWrite 5 "==> get_next_stmt_dates"

	upvar 1 $DATA IN

	#
	# calculate the date from
	#
	set IN(due_from) [get_next_stmt_date_from $IN(ff_date) $IN(pv_date)]

	#
	# new due_from date is IN(due_from) -1 second
	#
	OT_LogWrite 5 "IN(due_from):   $IN(due_from)"
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $IN(due_from) all yr mn dy hh mm ss]} {
		error "date wrong format"
	}
	set due_from [clock format [clock scan "$mn/$dy/$yr $hh:$mm:$ss 1 second ago"] -format "%Y-%m-%d %H:%M:%S"]
	OT_LogWrite 5 "due_from: $due_from"

	#
	# now calculate the date to
	#
	set IN(due_to)   [get_next_stmt_date_to $due_from $IN(ft_date) $IN(freq_amt) $IN(freq_unit) $IN(enforce_period)]

	OT_LogWrite 5 "<== get_next_stmt_dates"
	return 1
}

proc get_next_stmt_date_from {ff_date pv_date} {

	OT_LogWrite 5 "==> get_next_stmt_date_from"

	OT_LogWrite 5 "ff_date: $ff_date"
	OT_LogWrite 5 "pv_date: $pv_date"

	#
	# split the date and scan
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $ff_date all ff_yr ff_mn ff_dy ff_hh ff_mm ff_ss]} {
		error "date wrong format"
	}
	set ff_scan 	[clock scan "$ff_mn/$ff_dy/$ff_yr $ff_hh:$ff_mm:$ff_ss"]

	#
	# check previous date
	#
	if {$pv_date != ""} {

		#
		# split previous and scan
		#
		if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $pv_date all pv_yr pv_mn pv_dy pv_hh pv_mm pv_ss]} {
			error "date wrong format"
		}
		set pv_scan 	[clock scan "$pv_mn/$pv_dy/$pv_yr $pv_hh:$pv_mm:$pv_ss 1 second"]

		#
		# if previous is later than force from then use previous
		#
		if {$pv_scan > $ff_scan} {
			return [clock format $pv_scan -format "%Y-%m-%d %H:%M:%S"]
		}
	}

	#
	# no previous date, or force from is later than previous
	#
	return [clock format $ff_scan -format "%Y-%m-%d %H:%M:%S"]
}


proc get_next_stmt_date_to {ff_date ft_date freq_amt freq_unit enforce_ff} {


	OT_LogWrite 5 "==> get_next_stmt_date_to"

	OT_LogWrite 5 "ff_date:    $ff_date"
	OT_LogWrite 5 "ft_date:    $ft_date"
	OT_LogWrite 5 "freq_amt:   $freq_amt"
	OT_LogWrite 5 "freq_unit:  $freq_unit"
	OT_LogWrite 5 "enforce_ff: $enforce_ff"

	#
	# split and scan dates
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $ff_date all ff_yr ff_mn ff_dy ff_hh ff_mm ff_ss]} {
		error "date wrong format"
	}

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $ft_date all ft_yr ft_mn ft_dy ft_hh ft_mm ft_ss]} {
		error "date wrong format"
	}

	#
	# calculate two date_to dates - one based upon ff + duration, one based upon ft
	#
	if {$freq_unit == "M"} {
		set time_unit "month"
		set ff_date_to   [tb_stmt_next_monthly $ff_date]
		set ft_date_to   [tb_stmt_next_monthly $ft_date]

	} elseif {$freq_unit == "W"} {
		set time_unit "week"
		set ff_date_to   [tb_stmt_next_weekly $ff_date]
		set ft_date_to   [tb_stmt_next_weekly $ft_date]
	} else {
		error "invalid value for frequency units"
	}
	OT_LogWrite 5 "ff_date_to: $ff_date_to"
	OT_LogWrite 5 "ft_date_to: $ft_date_to"

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $ff_date_to all ff_yr_to ff_mn_to ff_dy_to ff_hh_to ff_mm_to ff_ss_to]} {
		error "date wrong format"
	}

	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $ft_date_to all ft_yr_to ft_mn_to ft_dy_to ft_hh_to ft_mm_to ft_ss_to]} {
		error "date wrong format"
	}

	# add the duration
	set ff_scan_to	[clock scan "$ff_mn_to/$ff_dy_to/$ff_yr_to $freq_amt $time_unit"]
	set ft_scan_to	[clock scan "$ft_mn_to/$ft_dy_to/$ft_yr_to $freq_amt $time_unit"]

	# subtract 1 second from the to date
	set ff_scan_to 	[clock scan "[clock format $ff_scan_to -format "%m/%d/%Y %H:%M:%S"] 1 second ago"]
	set ft_scan_to 	[clock scan "[clock format $ft_scan_to -format "%m/%d/%Y %H:%M:%S"] 1 second ago"]

	#
	# now see which one of the times is later than the other (take the later one)
	#
	if {$ft_scan_to > $ff_scan_to || !$enforce_ff} {
		OT_LogWrite 5 "using ft"
		set due_to [clock format $ft_scan_to -format "%Y-%m-%d %H:%M:%S"]
	} else {
		OT_LogWrite 5 "using ff + duration"
		set due_to [clock format $ff_scan_to -format "%Y-%m-%d %H:%M:%S"]
	}

	OT_LogWrite 5 "due_to:   $due_to"
	OT_LogWrite 5 "<== get_next_stmt_date_to"
	return $due_to
}



proc tb_stmt_add {acct_id freq_unit freq_amt ff_date ft_date dlv_method brief {enforce_period 1} {acct_type ""}} {

	variable Weekdays

	set stmt_day [OT_CfgGet PERIOD_BOUNDARY_WEEK 1]
	#
	# grab the current time, and set some sensible defaults
	#
	set status					"A"
	set DATA(ff_date) 			$ff_date
	set DATA(ft_date) 			$ft_date
	set DATA(pv_date) 			""
	set DATA(freq_amt) 			$freq_amt
	set DATA(freq_unit) 		$freq_unit
	set DATA(enforce_period)	$enforce_period
	set DATA(due_from)          $ff_date

	switch -exact -- $freq_unit {
		M {
			set freq_unit month
		}
		W {
			set freq_unit week
		}
	}
	# Get the statement end date ignoring other factors such as due dates
	set strict_stmt_end_dt [clock format [clock scan "$ff_date $freq_amt $freq_unit"] -format "%Y-%m-%d"]
	# If using batch statementing add a week to none random
	if {[OT_CfgGet STMT_FORCE_BI_WEEKLY 0] && [expr $acct_id % 2]} {
		set strict_stmt_end_dt [clock format [clock scan "$strict_stmt_end_dt 7 day"] -format "%Y-%m-%d"]
	}

	# Get the day of the stmt end date and work out number of days this is from a statementing day
	set current_day $Weekdays([clock format [clock scan $strict_stmt_end_dt] -format "%a"])
	set diff [expr $stmt_day - $current_day]

	#set diff [expr $current_day - $stmt_day]
	# Set due_to day
	set DATA(due_to) [clock format [clock scan "$strict_stmt_end_dt $diff day"] -format {%Y-%m-%d 23:59:59}]
	#
	# insert into tacctstmt
	#
	tb_db::tb_exec_qry tb_stmt_add \
				$acct_id \
				$status \
				$brief \
				$dlv_method \
				$DATA(freq_unit) \
				$DATA(freq_amt) \
				$DATA(due_from) \
				$DATA(due_to)
}


# Decides which stmt_control schedule to use
# sched or sched_two
# returns sched_date or sched_date_two
proc tb_stmt_control_batch args {
	variable STMT_CONTROL

	set sched sched_date
	set sTime    "$STMT_CONTROL(sched_date) - 1 day"
	set sTimeTwo "$STMT_CONTROL(sched_date_two) - 1 day"

	set sTime [clock format [clock scan \
			"$sTime"] -format {%Y-%m-%d 23:59:59}]

	set sTimeTwo [clock format [clock scan \
			"$sTimeTwo"] -format {%Y-%m-%d 23:59:59}]

	if [catch {set rs [tb_db::tb_exec_qry tb_get_num_sched_type $sTime]} msg] {
		error "Failed counting previous statements: $msg"
	}

	set sched_count [db_get_col $rs 0 count]
	db_close $rs

	if [catch {set rs [tb_db::tb_exec_qry tb_get_num_sched_type $sTimeTwo]} msg] {
		error "Failed counting statements: $msg"
	}

	set sched_two_count [db_get_col $rs 0 count]
	db_close $rs

	if {$sched_count > $sched_two_count} {
		set sched sched_date_two
	}

	return $sched
}



proc tb_stmt_upd {acct_id freq_unit freq_amt ff_date ft_date status dlv_method brief {enforce_period 1} {acct_type DEP} {overide 0}} {

		variable Weekdays

		set stmt_day [OT_CfgGet PERIOD_BOUNDARY_WEEK 1]

		switch -exact -- $freq_unit {
			M {
				set freq_unit_type month
			}
			W {
				set freq_unit_type week
			}
		}
		# Get the statement end date ignoring other factors such as due dates
		set strict_stmt_end_dt [clock format [clock scan "$ff_date $freq_amt $freq_unit_type"] -format "%Y-%m-%d"]

		# Get the day of the stmt end date and work out number of days this is from a statementing day
		set current_day $Weekdays([clock format [clock scan $strict_stmt_end_dt] -format "%a"])
		set diff [expr $stmt_day - $current_day]

		# Set due_to day
		set DATA(due_to) [clock format [clock scan "$strict_stmt_end_dt $diff day"] -format {%Y-%m-%d 23:59:59}]

		if {[clock scan $ft_date] > [clock scan $DATA(due_to)]} {
			set DATA(due_to) [clock format [clock scan "$ft_date"] -format {%Y-%m-%d 23:59:59}]
		}

		# Make sure statement date is greater than current
		while {[clock scan $DATA(due_to)] < [clock scan today]} {
			set DATA(due_to) [clock format [clock scan "$DATA(due_to) 7 day"] -format {%Y-%m-%d 23:59:59}]
		}

		# Make sure we're the right day
		while {$stmt_day != $Weekdays([clock format [clock scan $DATA(due_to)] -format "%a"])} {
			set DATA(due_to) [clock format [clock scan "$DATA(due_to) 1 day"] -format {%Y-%m-%d 23:59:59}]
		}

		#
		# update
		#
		tb_db::tb_exec_qry tb_stmt_upd \
						$status \
						$brief \
						$dlv_method \
						$freq_unit \
						$freq_amt \
						$ff_date \
						$DATA(due_to) \
						$acct_id

}

proc tb_stmt_upd_ext {acct_id pulled pull_reason cust_msg_1 cust_msg_2 cust_msg_3 cust_msg_4 remove_msg} {

	tb_db::tb_exec_qry tb_stmt_upd_ext \
					$pulled \
					$pull_reason \
					$cust_msg_1 \
					$cust_msg_2 \
					$cust_msg_3 \
					$cust_msg_4 \
					$remove_msg \
					$acct_id
}


proc tb_stmt_count {acct_id} {

	if [catch {set rs [tb_db::tb_exec_qry tb_stmt_count $acct_id]} msg] {
		error "Failed counting previous statements: $msg"
	}

	if {[db_get_nrows $rs] == 0} {
		return 0
	}

	set num [db_get_col $rs 0 stmt_num]
	db_close $rs
	return $num
}

proc write_stmt_to_file {ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# write to file (for statement generation)
	#
	set filename "$DATA(hdr,acct_type)-$DATA(hdr,due_to).csv"

	if {[OT_CfgGet STATEMENT_REMOVE_COLON 0]} {
		#Remove colon for windows systems
		set filename [string map {: -} $filename]
	}

	set STATEMENT_DIR [OT_CfgGet STATEMENT_DIR]
	set f_id [open "$STATEMENT_DIR/$filename" w]


	for {set i 0} {$i < $DATA(bdy,num_txns)} {incr i} {

		for {set j 0} {$j < $DATA(bdy,$i,nrows)} {incr j} {
			#puts $f_id "$DATA(bdy,$i,cr_date)|$DATA(bdy,$i,$j,desc)|$DATA(bdy,$i,credit)|$DATA(bdy,$i,debit)|$DATA(bdy,$i,balance)"
		}
	}
	close $f_id
}

proc tb_stmt_effective_to {acct_id pull_to_date} {

	# If pull_to_date is empty, we are trying to blank the date
	if {$pull_to_date != ""} {
		# Check that pull_to_date is a valid date
		if {[catch {set date [clock scan $pull_to_date]} msg]} {
			OT_LogWrite ERROR "The date passed in is invalid."
			error "The Effective To date passed in is invalid."
		}

		set now [clock scan seconds]
		# Check that pull_to_date is in the future
		if {$date < $now} {
			OT_LogWrite ERROR "The date passed in is not in the future."
			error "The Effective To date, passed is is not in the future."
		}
	}

	tb_db::tb_exec_qry tb_stmt_effective_to \
					$pull_to_date \
					$acct_id
}

proc insert_stmt_record {ARRAY} {

	upvar 1 $ARRAY DATA

	OT_LogWrite 5 "==> tb_stmt_gen"
	OT_LogWrite 5 "$DATA(hdr,sort)"
	OT_LogWrite 5 "$DATA(hdr,dlv_method)"
	OT_LogWrite 5 "$DATA(hdr,brief)"

	if {[OT_CfgGet FUNC_DEBT_MANAGEMENT 0] == 1} {
		set DATA(hdr,review_date) [get_stmt_review_date $DATA(hdr,acct_id)]
	} else {
		set DATA(hdr,review_date) ""
	}

	if {![info exists DATA(hdr,product_filter)]} {
		set DATA(hdr,product_filter) "ALL"
	}

	#
	# record the statement
	#
	tb_db::tb_exec_qry tb_stmt_insert_record \
									$DATA(hdr,acct_id) \
									$DATA(hdr,stmt_num) \
									$DATA(hdr,due_from) \
									$DATA(hdr,due_to) \
									$DATA(hdr,sort) \
									$DATA(hdr,dlv_method) \
									$DATA(hdr,brief) \
									$DATA(hdr,cust_msg_1) \
									$DATA(hdr,cust_msg_2) \
									$DATA(hdr,cust_msg_3) \
									$DATA(hdr,cust_msg_4) \
									$DATA(hdr,pmt_amount) \
									$DATA(hdr,pmt_method) \
									$DATA(hdr,pmt_desc) \
									$DATA(hdr,pull_status) \
									$DATA(hdr,pull_reason) \
									$DATA(hdr,printed) \
									$DATA(hdr,review_date) \
									$DATA(hdr,product_filter)
}

proc tb_stmt_del {acct_id} {
	tb_db::tb_exec_qry tb_stmt_delete $acct_id
}


proc get_stmt_review_date {acct_id} {

	set rs [tb_db::tb_exec_qry tb_get_stmt_review_date $acct_id]
	if {[db_get_nrows $rs] != 1} {
		set num_days [OT_CfgGet DEBT_MAN_GRACE_PERIOD 11]
	} else {
		set num_days [db_get_col $rs 0 flag_value]
	}
	db_close $rs

	set result [clock format [clock scan "+$num_days days"\
		 -base [clock seconds]] -format "%Y-%m-%d"]

	return $result
}

proc tb_stmt_acct_has_stmt {acct_id} {

	set rs [tb_db::tb_exec_qry tb_stmt_acct_has_stmt $acct_id]
	set result [db_get_nrows $rs]
	db_close $rs
	return $result
}


proc calc_stmt_end_pmt {ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# search for an authorised payment in 24 hour period prior to
	# due_to datewith j_op_type = 'DWTD' otherwise, if found this
	# means that we're in a 'payment sent to customer' state
	#
	set rs [tb_db::tb_exec_qry tb_stmt_find_pmt_made $DATA(hdr,acct_id) $DATA(hdr,due_to)]

	if {[db_get_nrows $rs] != 0} {

		# NOTE a positive amount is a payment sent in tstmtrecord

		set jrnl_id [db_get_col $rs 0 jrnl_id]
		set amount  [format "%.2f" [expr [db_get_col $rs 0 amount] * -1]]
		set ref_id  [db_get_col $rs 0 j_op_ref_id]
		db_close $rs

		set desc    [lindex [tb_statement_build::tb_stmt_get_pay_mthd $ref_id] 0]

		set DATA(hdr,pmt_amount_abs) $amount
		set DATA(hdr,pmt_amount)     $amount
		set DATA(hdr,pmt_method)     $desc
		set DATA(hdr,pmt_desc)       ""
		set DATA(hdr,pmt_type)       "SNT"
	} else {
		if {[expr $DATA(hdr,close_bal) < 0.00]} {
			#
			# if the a/c balance is less than zero then we're in a 'request
			# payment from customer state' - use payment %
			#

			# NOTE a negative amount is a payment requested in tstmtrecord

			# get the pmt % and min_settle
			set rs [tb_db::tb_exec_qry tb_stmt_get_CDT_acct_params $DATA(hdr,acct_id)]
			set min_settle [db_get_col $rs 0 min_settle]
			set pay_pct [db_get_col $rs 0 pay_pct]
			db_close $rs

			if {[OT_CfgGet OVERIDE_MIN_SETTLE 0]} {
				set config_settle [OT_CfgGet MIN_SETTLE_AMOUNT]
				if {$min_settle < $config_settle} {
					set min_settle $config_settle
				}
			}

			if {[expr $DATA(hdr,close_bal) < ($min_settle * -1)]} {
				# payment amount
				set amount [format "%.2f" [expr $DATA(hdr,close_bal) * $pay_pct / 100]]

				set DATA(hdr,pmt_desc)       ""
				set DATA(hdr,pmt_method)     ""
				set DATA(hdr,pmt_amount)     $amount
				set DATA(hdr,pmt_type)       "REQ"
			} else {
				set DATA(hdr,pmt_desc)       ""
				set DATA(hdr,pmt_method)     ""
				set DATA(hdr,pmt_amount)     "0.00"
				set DATA(hdr,pmt_type)       "NON"
			}
		} else {
			set DATA(hdr,pmt_desc)       ""
			set DATA(hdr,pmt_method)     ""
			set DATA(hdr,pmt_amount)     "0.00"
			set DATA(hdr,pmt_type)       "NON"
		}
		db_close $rs
	}
}

proc tb_stmt_get_balance {acct_id at {from ""}} {

	#
	# gets the account balance at a given time
	#
	if {$from == ""} {

		set rs2 [tb_db::tb_exec_qry tb_stmt_get_historic_balance $acct_id $at]

	} else {

		#Speed up query by supplying a from date to narrow the search
		set rs2 [tb_db::tb_exec_qry tb_stmt_get_quick_historic_balance $acct_id $from $at ]

	}

	if {[db_get_nrows $rs2] == 0} {
		set balance "0.00"
	} else {
		set balance [db_get_col $rs2 0 balance]
	}

	db_close $rs2

	return $balance
}


proc tb_stmt_get_sum_ap {acct_id at} {

	#
	# Check the tAPPmt time to get the correct balance at that time
	#
	set rs [tb_db::tb_exec_qry tb_stmt_get_sum_ap_at_time $acct_id $at]
	if {[db_get_nrows $rs] < 1} {
		set sum_ap 0.00
	} else {
		set sum_ap [db_get_col $rs 0 ap_balance]
	}

	db_close $rs

	return $sum_ap
}

proc even_week {yr mn dy} {

	#
	# determine if we're in an 'even' or 'odd' week
	#
	set ndays  [string trimleft [clock format [clock scan "$mn/$dy/$yr"] -format "%j"] 0]
	set nyears [expr $yr - 1900]

	set total_days [expr ($nyears * 365) + $ndays]

	return [expr ($total_days / 7) % 2]
}

init_tb_statement

# close namespace
}

