# ==============================================================
# $Id: cust_activity.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Procedures:
#     ADMIN::CUST_ACTIVITY::go_activity
#     ADMIN::CUST_ACTIVITY::do_cust_activity
#     ADMIN::CUST_ACTIVITY::get_where_clause
#
namespace eval ADMIN::CUST_ACTIVITY {

	asSetAct ADMIN::CUST_ACTIVITY::GoActivity [namespace code go_activity]

}



# go_activity
#
#
#
proc ADMIN::CUST_ACTIVITY::go_activity {} {

	set act [reqGetArg SubmitName]
	set cust_id [reqGetArg CustId]

	ob_log::write DEBUG {go_activity: $act}

	switch -- $act {
		"DoCustActivity" {
			do_cust_activity
			return
		}
		"Back" {
			if {$cust_id == ""} {
				ADMIN::CUST::go_cust_query
			} else {
				ADMIN::CUST::go_cust
			}
			return
		}
		default {
			ADMIN::CUST::go_cust_query
		}
	}
}



# do_cust_activity
#
#     Searches tCustStatsAction and plays results in cust_activity.html
#
# params:
#    single_customer - We only want all results for one customer
proc ADMIN::CUST_ACTIVITY::do_cust_activity {{single_customer 0}} {

	global DB
	global DATA
	set where_clause ""
	set cust_id ""
	array unset DATA

	ob_log::write INFO "ADMIN::CUST_ACTIVITY::do_cust_activity: single_customer=$single_customer"

	# are we only displaying one users details?
	if {$single_customer} {
		set cust_id [reqGetArg CustId]
		tpBindString CustId $cust_id
		set where_clause "ac.cust_id = $cust_id and"
	} else {
		ob_log::write INFO "ADMIN::CUST_ACTIVITY::do_cust_activity: Building where clause"

		if {[string trim [reqGetArg Username]] == "" &&
			([string trim [reqGetArg FirstDate1]] == "" ||
			 [string trim [reqGetArg FirstDate2]] == "") &&
			[string trim [reqGetArg LastDateRange]] == ""
		} {
			err_bind "Must supply search conditions: Username, First/Last date or a date range"
			ADMIN::CUST::go_cust_query
			return
		}

		set where_clause [get_where_clause]
	}

	set sql [subst {
	select first 1000
		a.action_name,
		a.action_id,
		g.desc,
		min(s.first_date) as first_date,
		max(s.last_date)  as last_date,
		sum(s.count)      as count,
		s.acct_id,
		u.username        as uname,
		DECODE(aggregate_channels, 'Y', 'All', c.desc) as channel_name
	from
		tCustStats         s,
		tCustStatsAction   a,
		tCustomer          u,
		tAcct              ac,
		outer tXSysHostGrp g,
		outer tChannel     c
	where
		$where_clause
		a.action_id  = s.action_id and
		g.group_id   = a.system_group_id and
		c.channel_id = s.source and
		ac.acct_id   = s.acct_id and
		u.cust_id    = ac.cust_id
	group by 1,2,3,7,8,9
	order by 5}]

	set stmt    [inf_prep_sql $DB $sql]
	set rs      [inf_exec_stmt $stmt]
	set nrows   [db_get_nrows $rs]

	if {$nrows == 1000} {
		tpSetVar MaxDisplayAdj 1
	} else {
		tpSetVar MaxDisplayAdj 0
	}

	# Bind data to be displayed
	for {set r 0} {$r < $nrows} {incr r} {
		set action_name [db_get_col $rs $r action_name]
		# getting the translation is rather slow and we only have a few distinct
		# values
		if {![info exists TRANSLATED_ACTION_NAMES($action_name)]} {
			set TRANSLATED_ACTION_NAMES($action_name) \
				[ADMIN::XLATE::get_translation en "CUST_STATS_ACTION_${action_name}"]
		}
		set DATA($r,action_name)    $TRANSLATED_ACTION_NAMES($action_name)
		set DATA($r,sys_group_name) [db_get_col $rs $r desc]
		set DATA($r,first_date)     [db_get_col $rs $r first_date]
		set DATA($r,last_date)      [db_get_col $rs $r last_date]
		set DATA($r,acct_no)        [db_get_col $rs $r acct_id]
		set DATA($r,source)         [db_get_col $rs $r channel_name]
		set DATA($r,count)          [db_get_col $rs $r count]
		set DATA($r,username)       [db_get_col $rs $r uname]
	}

	db_close $rs
	inf_close_stmt $stmt

	tpSetVar nActivities $nrows
	tpBindVar activities_acct_no     DATA   acct_no         act_idx
	tpBindVar activities_source      DATA   source          act_idx
	tpBindVar activities_fistDate    DATA   first_date      act_idx
	tpBindVar activities_lastDate    DATA   last_date       act_idx
	tpBindVar activities_count       DATA   count           act_idx
	tpBindVar activities_action_name DATA   action_name     act_idx
	tpBindVar activities_username    DATA   username        act_idx

	asPlayFile -nocache cust_activity.html
}



#
# Returns a string to be used with the where clause
#
proc ADMIN::CUST_ACTIVITY::get_where_clause {} {

	set where           [list]
	set from            [list]

	# Customer's Username
	if {[string length [set name [reqGetArg Username]]] > 0} {
		if {[reqGetArg ExactName] == "Y"} {
			set op "="
		} else {
			set op "like"
			append name %
		}
		if {[reqGetArg UpperName] == "Y"} {
			lappend where "u.username_uc $op [upper_q \"${name}\"]"
		} else {
			lappend where "u.username $op \"${name}\""
		}
	}

	# First activity date range
	set first_lo [string trim [reqGetArg FirstDate1]]
	set first_hi [string trim [reqGetArg FirstDate2]]

	if {([string length $first_lo] > 0) || ([string length $first_hi] > 0)} {
		lappend where [mk_between_clause s.first_date date $first_lo $first_hi]
	}

	if {[set date_range [reqGetArg FirstDateRange]] != ""} {
		set first_now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $first_now_dt -] { break }
		set first_hi "$Y-$M-$D 23:59:59"
		if {$date_range == "TD"} {
			set first_lo "$Y-$M-$D 00:00:00"
		} elseif {$date_range == "CM"} {
			set first_lo "$Y-$M-01 00:00:00"
		} elseif {$date_range == "YD"} {
			set first_lo "[date_days_ago $Y $M $D 1] 00:00:00"
			set first_hi "[date_days_ago $Y $M $D 1] 23:59:59"
		} elseif {$date_range == "L3"} {
			set first_lo "[date_days_ago $Y $M $D 3] 00:00:00"
		} elseif {$date_range == "L7"} {
			set first_lo "[date_days_ago $Y $M $D 7] 00:00:00"
		}
	}

	if {([string length $first_lo] > 0) || ([string length $first_hi] > 0)} {
		lappend where [mk_between_clause s.first_date date $first_lo $first_hi]
	}

	# Last activity date range
	set last_lo [string trim [reqGetArg LastDate1]]
	set last_hi [string trim [reqGetArg LastDate2]]

	if {[string length $last_lo] > 0 || [string length $last_hi] > 0} {
		lappend where [mk_between_clause s.last_date date $last_lo $last_hi]
	}

	if {[set date_range [reqGetArg LastDateRange]] != ""} {
		set last_now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $last_now_dt -] { break }
		set last_hi "$Y-$M-$D 23:59:59"
		if {$date_range == "TD"} {
			set last_lo "$Y-$M-$D 00:00:00"
		} elseif {$date_range == "CM"} {
			set last_lo "$Y-$M-01 00:00:00"
		} elseif {$date_range == "YD"} {
			set last_lo "[date_days_ago $Y $M $D 1] 00:00:00"
			set last_hi "[date_days_ago $Y $M $D 1] 23:59:59"
		} elseif {$date_range == "L3"} {
			set last_lo "[date_days_ago $Y $M $D 3] 00:00:00"
		} elseif {$date_range == "L7"} {
			set last_lo "[date_days_ago $Y $M $D 7] 00:00:00"
		}
	}

	# Activity
	if {[string length [set action_id [reqGetArg action_id]]] > 0} {
		lappend where "a.action_id = $action_id"
	}

	# Channel
	if {[string length [set channel [reqGetArg channel]]] > 0} {
		lappend where "s.source = '$channel'"
	}

	if {[llength $where] > 0} {
		set where "[join $where { and }] and"
	}

	return $where
}
