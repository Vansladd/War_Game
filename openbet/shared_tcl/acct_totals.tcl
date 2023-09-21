# $Id: acct_totals.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
#   totals::calculate_simple_totals - Calculates totals for pool, fixed odds
#                                     xgames and payment for a time period.

namespace eval acct_totals {

proc init_acct_totals {} {

	global SHARED_SQL

	set SHARED_SQL(get_j_op_type_total) {
		select {+INDEX(tJrnl ijrnl_x2)}
			NVL(sum(amount),0.00) as total
		from
			tJrnl
		where
			acct_id = ?
		and cr_date >= ?
		and cr_date < ?
		and j_op_type = ?
	}

	set SHARED_SQL(get_acct_cr_date) {
		select
			cr_date as acct_cr_date
		from
			tAcct
		where
			acct_id = ?
	}

	set SHARED_SQL(get_j_op_type_total_all) {
		select
			NVL(sum(amount),0.00) as total
		from
			tJrnl
		where
			acct_id = ?
		and cr_date >= ?
		and j_op_type = ?
	}

	set SHARED_SQL(get_bstk_total) {
		select {+INDEX(tJrnl ijrnl_x2)}
			NVL(sum(j.amount),0.00) as total
		from
			tJrnl j,
			tBet b
		where
			j.acct_id = ?
		and j.cr_date >= ?
		and j.cr_date < ?
		and j.j_op_type = 'BSTK'
		and j.j_op_ref_key != 'XGAM'
		and j.j_op_ref_id = b.bet_id
		and b.source = ?
	}

	set SHARED_SQL(get_xgame_bstk_total) {
		select {+INDEX(tJrnl ijrnl_x2)}
			NVL(sum(j.amount),0.00) as total
		from
			tJrnl j,
			tXgameSub x
		where
			j.acct_id = ?
		and j.cr_date >= ?
		and j.cr_date < ?
		and j.j_op_type = 'BSTK'
		and j.j_op_ref_key = 'XGAM'
		and j.j_op_ref_id = x.xgame_sub_id
		and x.source = ?

	}

	set SHARED_SQL(get_bstk_total_all) {
		select
			NVL(sum(j.amount),0.00) as total
		from
			tJrnl j,
			tBet b
		where
			j.acct_id = ?
		and j.cr_date >= ?
		and j.j_op_type = 'BSTK'
		and j.j_op_ref_key != 'XGAM'
		and j.j_op_ref_id = b.bet_id
		and b.source = ?
	}

	set SHARED_SQL(get_xgame_bstk_total_all) {
		select
			NVL(sum(j.amount),0.00) as total
		from
			tJrnl j,
			tXGameSub x
		where
			j.acct_id = ?
		and j.cr_date >= ?
		and j.j_op_type = 'BSTK'
		and j.j_op_ref_key = 'XGAM'
		and j.j_op_ref_id = x.xgame_sub_id
		and x.source = ?
	}

	set SHARED_SQL(get_j_op_types) {
		select
			j_op_type,
			j_op_name
		from
			tJrnlOp
	}

	set SHARED_SQL(get_channels) {
		select
			channel_id,
			desc
		from
			tChannel
	}

	set SHARED_SQL(get_last_stmt_date) {
		select
			(date(due_from) + interval (1) day to day) as due_from,
			(date(due_to) + interval (0) day to day) as due_to
		from
			tacctstmt
		where
			acct_id = ?
	}

	# simple totals, costs are estimated
	# cost: 1
	set SHARED_SQL(SIMPLE_TOTALS_fixed) {
		select
			nvl(sum(stake), 0)    fixed_stk,
			nvl(sum(winnings), 0) fixed_winnings,
			nvl(sum(refund), 0)   fixed_refund,
			nvl(sum(decode(settled, 'Y', stake, 0)), 0) fixed_stl,
			nvl(sum(decode(settled, 'N', stake, 0)), 0) fixed_ustl,
			nvl(sum(winnings + refund - decode(settled, 'Y', stake, 0)), 0) fixed_profit
		from
			tBet
		where
			acct_id =  ? and
			status != "X" and
		    cr_date between ? and ?
	}

	# cost: 2
	set SHARED_SQL(SIMPLE_TOTALS_pool) {
		select
			nvl(sum(stake), 0)    pool_stk,
			nvl(sum(winnings), 0) pool_winnings,
			nvl(sum(refund), 0)   pool_refund,
			nvl(sum(decode(settled, 'Y', stake, 0)), 0) pool_stl,
			nvl(sum(decode(settled, 'N', stake, 0)), 0) pool_ustl,
			nvl(sum(winnings + refund - decode(settled, 'Y', stake, 0)), 0) pool_profit
		from
			tPoolBet
		where
			acct_id =  ?
		and cr_date between ? and ?
	}

	# cost: 14
	set SHARED_SQL(SIMPLE_TOTALS_xgame) {
		select
			nvl(sum(b.stake), 0)    xgame_stk,
			nvl(sum(b.winnings), 0) xgame_winnings,
			nvl(sum(b.refund), 0)   xgame_refund,
			nvl(sum(decode(settled, 'Y', stake, 0)), 0) xgame_stl,
			nvl(sum(decode(settled, 'N', stake, 0)), 0) xgame_ustl,
			nvl(sum(winnings + refund - decode(settled, 'Y', stake, 0)), 0) xgame_profit
		from
			tXGameSub s,
			tXGameBet b
		where
			s.acct_id       =  ?
		and b.xgame_sub_id  =  s.xgame_sub_id
		and b.cr_date       between ? and ?
	}

	# cost: 3
	set SHARED_SQL(SIMPLE_TOTALS_rk) {
		select
			ref_key,
			nvl(sum(decode(payment_sort, 'D', amount, 0)), 0) dep,
			nvl(sum(decode(payment_sort, 'W', amount, 0)), 0) wtd
		from
			tPmt
		where
			acct_id =  ?
		and cr_date between ? and ?
		-- only non-failed payments
		and status  <> 'N'
		and status  <> 'X'
		and status  <> 'U'
		and status  <> 'I'
		and status  <> 'B'
		group by
			ref_key
		order by
			ref_key
	}

	if {[OT_CfgGet SHOW_WEEKLY_TOTALS 0]} {
		set SHARED_SQL(SIMPLE_DAILY_TOTALS_DAYS) {
			select
				extend (cr_date,year to day) as day,
				ref_key,
				'' as scheme,
				nvl(sum(decode(payment_sort, 'D', 1)),0) numdep,
				nvl(sum(decode(payment_sort, 'W', 1)),0) numwtd,
				nvl(sum(decode(payment_sort, 'D', amount, 0)), 0) dep,
				nvl(sum(decode(payment_sort, 'W', amount, 0)), 0) wtd,
				count(*)
			from
				tPmt p
 			where
				acct_id = ?
				and cr_date between ? and ?
				and status not in ('N','X')
				and ref_key != 'CC'
			group by
				1,2
		union
			select
				extend (p.cr_date,year to day) as day,
				'CC' as ref_key,
				i.scheme as scheme,
				nvl(sum(decode(p.payment_sort, 'D', 1)),0) numdep,
				nvl(sum(decode(p.payment_sort, 'W', 1)),0) numwtd,
				nvl(sum(decode(p.payment_sort, 'D', amount, 0)), 0) dep,
				nvl(sum(decode(p.payment_sort, 'W', amount, 0)), 0) wtd,
				count(*)
			from
				tPmt p,
				tCPMCC c,
				tCardInfo i
			where
				acct_id = ?
				and p.cr_date between ? and ?
				and p.status not in ('N','X')
				and p.ref_key = 'CC'
				and p.cpm_id = c.cpm_id
				and c.card_bin = i.card_bin
			group by
				1,3
			order by
				day desc
		}
	}

	set SHARED_SQL(get_token_amounts) {
		select
			NVL(sum(r.redemption_amount),0.00) As total
		from
			tCustTokRedemption r,
			tAcct a,
			tCustomerToken t
		where
			a.acct_id = ? and
			a.cust_id = t.cust_id and
			r.cust_token_id = t.cust_token_id and
			r.cr_date > ? and
			r.cr_date < ?
	}

    set SHARED_SQL(get_business_period) {
        select
            period_date_from,
            period_date_to
        from 
            tBusinessPeriod
        where
           period_date_from <= ? and
           period_date_to >= ?
    }
}

proc calculate_totals {acct_id ARRAY {bp 0}} {


	upvar 1 $ARRAY DATA

	#
	# get the optypes
	#
	if {[catch {set rs [tb_db::tb_exec_qry get_j_op_types]} msg]} {
		ob::log::write ERROR {failed to retrieve j_op_types: $msg}
		return 0
	}

	set DATA(optypes,number) [db_get_nrows $rs]

	for {set i 0} {$i < $DATA(optypes,number)} {incr i} {
		set DATA(optypes,$i,name) [db_get_col $rs $i j_op_name]
		set DATA(optypes,$i) [db_get_col $rs $i j_op_type]
	}
	db_close $rs

	#
	# get the channels
	#
	if {[catch {set rs [tb_db::tb_exec_qry get_channels]} msg]} {
		ob::log::write ERROR {failed to retrieve channels: $msg}
		return 0
	}

	set DATA(channels,number) [db_get_nrows $rs]

	for {set i 0} {$i < $DATA(channels,number)} {incr i} {
		set DATA(channels,$i,name) [db_get_col $rs $i desc]
		set DATA(channels,$i) [db_get_col $rs $i channel_id]
	}
	db_close $rs


	# calcualte the totals
	calculate_weekly_period_totals $acct_id DATA
	calculate_monthly_period_totals $acct_id DATA

    # if $bp is set to 1, then we calculate over business period
    # and avoid calculating monthly as this would waste processing time
    if {$bp == 1} {
        ob_log::write INFO {acct_totals::calculate_totals >> calculating over b_period}
        calculate_business_period_totals $acct_id DATA
    } else {
        ob_log::write INFO {acct_totals::calculate_totals >> calculating over month}
        calculate_monthly_period_totals $acct_id DATA
    }
	calculate_yearly_period_totals $acct_id DATA
	calculate_all_time_totals $acct_id DATA
	calculate_stmt_period_totals $acct_id DATA
}


proc calculate_totals_for_period {acct_id from to key ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# include the date periods for the given key
	#
	set DATA($key,from) $from
	set DATA($key,to) $to


	#
	# compute each op type value
	#
	for {set i 0} {$i < $DATA(optypes,number)} {incr i} {

		set f $DATA(optypes,$i)

		if {[catch {set rs [tb_db::tb_exec_qry get_j_op_type_total $acct_id "$from 00:00:00" "$to 23:59:59" $f]} msg]} {
			ob::log::write ERROR {failed to calculate value for op type $f: $msg}
			return 0
		}

		set DATA(optypes,$i,$key,amount) [db_get_col $rs 0 total]

		if {$f == "BSTL" || $f == "BWIN" || $f == "BRFD"} {
			set DATA($f,$key,amount) [db_get_col $rs 0 total]
		}

		if {$f == "OFFR" && [OT_CfgGet USE_CUST_TOK_REDEMPTION_TOTALS 1]} {
			if {[catch {set rs2 [tb_db::tb_exec_qry  get_token_amounts $acct_id "$from 00:00:00" "$to 23:59:59"]} msg]} {
				ob::log::write ERROR {failed to calculate value for token redemptions: $msg}
				return 0
			}
			set DATA(optypes,$i,$key,amount) [db_get_col $rs2 0 total]

			db_close $rs2
		}
		db_close $rs
	}


	#
	# compute each channel, bet stake
	#
	set DATA(BSTK,$key,amount) 0.00

	for {set i 0} {$i < $DATA(channels,number)} {incr i} {

		set f $DATA(channels,$i)

		if {[catch {set rs [tb_db::tb_exec_qry get_bstk_total $acct_id "$from 00:00:00" "$to 23:59:59" $f]} msg]} {
			ob::log::write ERROR {failed to calculate value for channel $f: $msg}
			return 0
		}

		if {[catch {set rs2 [tb_db::tb_exec_qry get_xgame_bstk_total $acct_id "$from 00:00:00" "$to 23:59:59" $f]} msg]} {
			ob::log::write ERROR {failed to calculate xgame value for channel $f: $msg}
			return 0
		}

		set DATA(channels,$i,$key,amount) [format "%.2f" [expr [db_get_col $rs 0 total] + [db_get_col $rs2 0 total]]]
		set DATA(BSTK,$key,amount) [expr {$DATA(BSTK,$key,amount) + [db_get_col $rs 0 total]}]
		set DATA(BSTK,$key,amount) [expr {$DATA(BSTK,$key,amount) + [db_get_col $rs2 0 total]}]
		db_close $rs
		db_close $rs2
	}
	set DATA(BSTK,$key,amount) [format "%.2f" $DATA(BSTK,$key,amount)]

	foreach rtn {
		BSTL
		BWIN
		BRFD
	} {
		if {![info exists DATA($rtn,$key,amount)]} {
			set DATA($rtn,$key,amount) 0.00
		}
	}
	
	set win [expr {$DATA(BSTL,$key,amount) +
	               $DATA(BWIN,$key,amount) +
	               $DATA(BRFD,$key,amount)}]

	#
	# do win/loss
	#
	set DATA(WL,$key,amount) [format "%.2f/%.2f" $win $DATA(BSTK,$key,amount)]

	if {$DATA(BSTK,$key,amount) == "0.00"} {
		# this should never really happen (returns without stakes)
		# don't worry -
		set DATA(WLP,$key,amount) ""
	} else {
		set DATA(WLP,$key,amount) [format "%.2f" [expr {abs($win) / abs($DATA(BSTK,$key,amount)) * 100.0}]]
	}

	return 1
}


proc calculate_totals_for_all {acct_id ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# Get the creation date of the account... can narrow down tJrnl lookup
	#
	if {[catch {set rs [tb_db::tb_exec_qry get_acct_cr_date $acct_id]} msg]} {
		ob::log::write ERROR {failed to get acct cr_date for acct_id $acct_id: $msg}
		return 0
	}

	set acct_cr_date [db_get_col $rs 0 acct_cr_date]

	db_close $rs

	#
	# compute each op type value
	#
	for {set i 0} {$i < $DATA(optypes,number)} {incr i} {

		set f $DATA(optypes,$i)

		if {[catch {set rs [tb_db::tb_exec_qry get_j_op_type_total_all $acct_id $acct_cr_date $f]} msg]} {
			ob::log::write ERROR {failed to calculate value for op type $f: $msg}
			return 0
		}

		set DATA(optypes,$i,all,amount) [db_get_col $rs 0 total]

		if {$f == "BSTL" || $f == "BWIN" || $f == "BRFD"} {
			set DATA($f,all,amount) [db_get_col $rs 0 total]
		}

		db_close $rs
	}


	#
	# compute each channel, bet stake
	#
	set DATA(BSTK,all,amount) 0.00

	for {set i 0} {$i < $DATA(channels,number)} {incr i} {

		set f $DATA(channels,$i)

		if {[catch {set rs [tb_db::tb_exec_qry get_bstk_total_all $acct_id $acct_cr_date $f]} msg]} {
			ob::log::write ERROR {failed to calculate value for channel $f: $msg}
			return 0
		}

		if {[catch {set rs2 [tb_db::tb_exec_qry get_xgame_bstk_total_all $acct_id $acct_cr_date $f]} msg]} {
			ob::log::write ERROR {failed to calculate value for channel $f: $msg}
			return 0
		}

		set DATA(channels,$i,all,amount) [format "%.2f" [expr [db_get_col $rs 0 total] + [db_get_col $rs2 0 total]]]
		set DATA(BSTK,all,amount) [expr {$DATA(BSTK,all,amount) + [db_get_col $rs 0 total]}]
		set DATA(BSTK,all,amount) [expr {$DATA(BSTK,all,amount) + [db_get_col $rs2 0 total]}]

		db_close $rs
		db_close $rs2
	}
	set DATA(BSTK,all,amount) [format "%.2f" $DATA(BSTK,all,amount)]

	foreach rtn {
		BSTL
		BWIN
		BRFD
	} {
		if {![info exists DATA($rtn,all,amount)]} {
			set DATA($rtn,all,amount) 0.00
		}
	}

	set win [expr {$DATA(BSTL,all,amount) +
	               $DATA(BWIN,all,amount) +
	               $DATA(BRFD,all,amount)}]


	#
	# do win/loss
	#
	set DATA(WL,all,amount) [format "%.2f/%.2f" $win $DATA(BSTK,all,amount)]

	if {$DATA(BSTK,all,amount) == "0.00"} {
		# this should never really happen (returns without stakes)
		# don't worry -
		set DATA(WLP,all,amount) ""
	} else {
		set DATA(WLP,all,amount) [format "%.2f" [expr {abs($win) / abs($DATA(BSTK,all,amount)) * 100.0}]]
	}

	return 1
}


proc calculate_weekly_period_totals {acct_id ARRAY {date ""}} {

	upvar 1 $ARRAY DATA

	#
	# get the next period boundary
	#
	set date_to [tb_statement::tb_stmt_next_weekly $date]

	#
	# and the previous
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $date_to all yr mn dy hh mm ss]} {
		error "date wrong format"
	}
	set date_to   "$yr-$mn-$dy"
	# this is wrong if bi-weekly statements - see QC#3367
	set date_from [clock format [clock scan "$mn/$dy/$yr $hh:$mm:$ss 1 week ago"] -format "%Y-%m-%d"]
	# and this is the fix
	set check_date_from [clock scan "$mn/$dy/$yr $hh:$mm:$ss 1 week ago"]
	if {$check_date_from > [clock seconds]} {
		set date_from [clock format [clock scan "$mn/$dy/$yr $hh:$mm:$ss 2 week ago"] -format "%Y-%m-%d"]
	}

	calculate_totals_for_period $acct_id $date_from $date_to week DATA
	return 1
}

#
# calculate totals over a business period
# if $date is set, we calculate on the date's business period
# if $date is not set, we calculate on the today's business period
#
proc calculate_business_period_totals {acct_id ARRAY {date ""}} {

    upvar 1 $ARRAY DATA

    set target_date ""
	set DATA(error_message) ""

    if {$date == "" } {
       # select today BP
        set target_date [clock format [clock seconds] -format {%Y-%m-%d}] 
    } else {
       # check and use user defined date
      if {[regexp {^(\d{2})/(\d{2})/(\d{2,4})$} $date all dd mm yy]} {
        # date is dd/mm/yy or dd/mm/yyyy
        set target_date [clock format [clock scan "$mm/$dd/$yy"] -format "%Y-%m-%d"]
      } elseif {[regexp {^(\d{4})-(\d{2})-(\d{2})$} $date match]} {
        # date is already informix date, no need to do anything
        set target_date $date
      } else {
        # we don't accept other formats
        error {acct_totals::calculate_business_period_totals: supplied date's format is not acceptable}
        return 0
      }
    }

    if {[catch {set rs [tb_db::tb_exec_qry get_business_period $target_date $target_date]} msg]} {
           error {'get_business_period' query has failed}
           return 0
            }

    if { [db_get_nrows $rs] != 1 }  {
		ob_log::write ERROR {Failed to get business period for date. No rows returned}
		set DATA(error_message) "No Business Period is defined for the current date"
		catch { db_close $rs }
		return 0
    }

    set bp_date_from            [db_get_col $rs 0 period_date_from]
    set bp_date_to              [db_get_col $rs 0 period_date_to]

    catch { db_close $rs } 

    calculate_totals_for_period $acct_id $bp_date_from $bp_date_to bperiod DATA

    return 1
}


proc calculate_monthly_period_totals {acct_id ARRAY {date ""}} {

	upvar 1 $ARRAY DATA

	#
	# get the next period boundary
	#
	set date_to [tb_statement::tb_stmt_next_monthly $date]

	#
	# and the previous
	#
	if {![regexp {^(....)-(..)-(..) (..):(..):(..)$} $date_to all yr mn dy hh mm ss]} {
		error "date wrong format"
	}
	set date_to   "$yr-$mn-$dy"
	set date_from [clock format [clock scan "$mn/$dy/$yr $hh:$mm:$ss 1 month ago"] -format "%Y-%m-%d"]

	calculate_totals_for_period $acct_id $date_from $date_to month DATA

	return 1
}

proc calculate_yearly_period_totals {acct_id ARRAY {date ""}} {

	upvar 1 $ARRAY DATA

	#
	# get the next period boundary
	#
	set current_year [clock format [clock seconds] -format "%Y"]
	set date_to "$current_year-[OT_CfgGet PERIOD_BOUNDARY_YEAR 01-01]"

	if {![regexp {^(....)-(..)-(..)$} $date_to all yr mn dy]} {
		error "date wrong format"
	}

	# is this beyond the current time?
	if {[clock scan "$mn/$dy/$yr"] < [clock seconds]} {
		#
		# add a year
		#
		set date_to [clock format [clock scan "$mn/$dy/$yr 1 year"] -format "%Y-%m-%d"]
	}

	if {![regexp {^(....)-(..)-(..)$} $date_to all yr mn dy]} {
		error "date wrong format"
	}

	#
	# and the previous
	#
	set date_from [clock format [clock scan "$mn/$dy/$yr 1 year ago"] -format "%Y-%m-%d"]

	calculate_totals_for_period $acct_id $date_from $date_to year DATA

	return 1
}

proc calculate_stmt_period_totals {acct_id ARRAY {date ""}} {

	upvar 1 $ARRAY DATA

	#
	# get the total from the last statement period
	# (if no statement period then default to two weekly period)
	#
	if {[catch {set rs [tb_db::tb_exec_qry get_last_stmt_date $acct_id]} msg]} {
		ob::log::write ERROR {failed to get_last_stmt_date: $msg}
		return 0
	}
	if {[db_get_nrows $rs] == 0} {

		#
		# customer doesn't have a statement
		#
		db_close $rs

		if {[catch {set rs [tb_db::tb_exec_qry get_last_stmt_date -1]} msg]} {
			ob::log::write ERROR {failed to get_last_stmt_date: $msg}
			return 0
		}
	}

	#
	# customer has a statement
	#
	set from [db_get_col $rs 0 due_from]
	set to   [db_get_col $rs 0 due_to]
	db_close $rs

	calculate_totals_for_period $acct_id $from $to stmt DATA

	return 1
}


proc calculate_all_time_totals {acct_id ARRAY} {

	upvar 1 $ARRAY DATA

	calculate_totals_for_all $acct_id DATA

	return 1

}


# Calculate the acct totals for a specified period.
#
#   acct_id    - The customer's acct_id.
#   ARRAY      - The name of an array to put the results into.
#   start_time - A date or a time for the beginining of the
#                period, default to the beginning of today.
#   end_time   - A date of time for the end of the period. Default to the end
#                of today.
#
proc calculate_simple_totals {acct_id ARRAY ARRAY_DAYS {start_time today} {end_time today}} {
	variable CFG

	upvar 1 $ARRAY       DATA
	upvar 1 $ARRAY_DAYS  DATA_DAYS

	array unset DATA
	array unset DATA_DAYS

	set today [clock format [clock seconds] -format {%Y-%m-%d}]

	# set the default today
	if {$start_time == "today" || $start_time == ""} {
		set start_time $today
	}
	if {$end_time == "today" || $end_time == ""} {
		set end_time   $today
	}

	# add the extenstion to the begining and end of the day
	if {[string length $start_time] == 10} {
		set start_time "$start_time 00:00:00"
	}
	if {[string length $end_time]   == 10} {
		set end_time   "$end_time 23:59:59"
	}

	set DATA(start_time) $start_time
	set DATA(end_time)   $end_time

	# check args
	if {
		![string is integer -strict $acct_id] ||
		![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$} $start_time] ||
		![regexp {^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$} $end_time]
	} {
		return [list 0 SIMPLE_TOTALS_ERR_BAD_ARG "One of the arguments was bad"]
	}

	# execute each qry and show the results (a bit 'clever' but less room for
	# errors)
	foreach qry [list SIMPLE_TOTALS_fixed SIMPLE_TOTALS_pool SIMPLE_TOTALS_xgame] {

		if {[catch {
			set rs [tb_db::tb_exec_qry $qry $acct_id $start_time $end_time]
		} msg]} {
			return [list 0 SIMPLE_TOTALS_ERR_DB $msg]
		}

		foreach col [db_get_colnames $rs] {
			set DATA($col) [db_get_col $rs 0 $col]
		}

		db_close $rs
	}

	# sum the totals
	foreach col [list stk stl ustl winnings refund profit] {
		set DATA(total_$col) 0
		foreach method [list fixed pool xgame] {
			set DATA(total_$col) [expr {$DATA(total_$col) + $DATA(${method}_$col)}]
		}
	}

	# format to two decimal places
	foreach col [list stk stl ustl winnings refund profit] {
		foreach method [list fixed pool xgame total] {
			set DATA(${method}_$col) [format %.2f $DATA(${method}_$col)]
		}
	}

	# do the payments
	if {[catch {
		set rs [tb_db::tb_exec_qry SIMPLE_TOTALS_rk $acct_id $start_time $end_time]
	} msg]} {
		return [list 0 SIMPLE_TOTALS_ERR_DB $msg]
	}

	set DATA(RK_nrows) [db_get_nrows $rs]

	# do the totals
	set DATA(total_dep) 0
	set DATA(total_wtd) 0

	for {set r 0} {$r < $DATA(RK_nrows)} {incr r} {
		set DATA($r,ref_key) [db_get_col $rs $r ref_key]
		set DATA($r,dep)     [db_get_col $rs $r dep]
		set DATA($r,wtd)     [db_get_col $rs $r wtd]

		set DATA(total_dep) [expr {$DATA(total_dep) + $DATA($r,dep)}]
		set DATA(total_wtd) [expr {$DATA(total_wtd) + $DATA($r,wtd)}]

		set DATA($r,dep)     [format %.2f $DATA($r,dep)]
		set DATA($r,wtd)     [format %.2f $DATA($r,wtd)]
	}

	set DATA(total_dep) [format %.2f $DATA(total_dep)]
	set DATA(total_wtd) [format %.2f $DATA(total_wtd)]

	db_close $rs

	if {[OT_CfgGet SHOW_WEEKLY_TOTALS 0]} {
		if {[catch {
			set rs [tb_db::tb_exec_qry SIMPLE_DAILY_TOTALS_DAYS \
					$acct_id \
					$start_time \
					$end_time \
					$acct_id \
					$start_time \
					$end_time]
		} msg]} {
			return [list 0 SIMPLE_TOTALS_ERR_DB $msg]
		}

		set DATA_DAYS(nrows) [db_get_nrows $rs]

		for {set r 0} {$r < $DATA_DAYS(nrows)} {incr r} {
			set DATA_DAYS($r,ref_key)       [db_get_col $rs $r ref_key]
			set DATA_DAYS($r,scheme)        [db_get_col $rs $r scheme]
			set DATA_DAYS($r,numdep)        [db_get_col $rs $r numdep]
			set DATA_DAYS($r,numwtd)        [db_get_col $rs $r numwtd]
			set DATA_DAYS($r,dep)           [db_get_col $rs $r dep]
			set DATA_DAYS($r,wtd)           [db_get_col $rs $r wtd]
			set DATA_DAYS($r,date)          [db_get_col $rs $r day]

			set DATA_DAYS($r,day) \
				[clock format [clock scan $DATA_DAYS($r,date)] -format {%a}]
		}

		db_close $rs
	}


	return [list 1 SIMPLE_TOTALS_OK]
}

init_acct_totals

# close namespace
}

