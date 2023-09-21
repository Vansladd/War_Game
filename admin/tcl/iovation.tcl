# ==============================================================
# $Id: iovation.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IOVATION {

asSetAct ADMIN::IOVATION::GoControl            [namespace code go_control]
asSetAct ADMIN::IOVATION::DoControl            [namespace code do_control]
asSetAct ADMIN::IOVATION::DoControlTrig        [namespace code do_control_trig]
asSetAct ADMIN::IOVATION::QueryControlCustTrig [namespace code query_control_cust_trig_args]
asSetAct ADMIN::IOVATION::DoControlCustTrig    [namespace code do_control_cust_trig]


# Go to the "control" page
#
proc go_control args {

	global DB

	set stmt [inf_prep_sql $DB {
		select first 1
			max_wait,
			enabled
		from
			tIovationCtrl
	}]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString MaxWait [db_get_col $res max_wait]
	tpBindString Enabled [db_get_col $res enabled]

	db_close $res

	# trigger control
	if {[op_allowed IovManageSystem]} {
		_go_control_trig
	}

	# customer control
	if {[op_allowed IovManageAccount]} {
		query_control_cust_trig_args
	}

	asPlayFile -nocache iovation_control.html

	catch {unset TRIG}
	catch {unset CUSTTRIG}
}


# Update the main control information
#
proc do_control args {

	global DB USERNAME

	if {![op_allowed IovManageGlobal]} {
		err_bind "You do not have permission to update Global Iovation settings"
		go_control
		return
	}

	# QC13913: temporary not updating max_wait as it is not in use due to submit
	# button reenabling issue by Iovation javascript
	#set sql_params {
	#	p_max_wait  = ?,
	#	p_enabled   = ?
	#}
	set sql_params {
		p_enabled   = ?
	}

	set sql [subst {
		execute procedure pUpdIovationCtrl (
			p_adminuser = ?,
			$sql_params
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	# QC13913: temporary not updating max_wait
	#set stmt_params { \
	#	[string trim [reqGetArg MaxWait]] \
	#	[string trim [reqGetArg Enabled]] \
	#}
	set stmt_params { \
		[string trim [reqGetArg Enabled]] \
	}

	if {[catch {
		set res [eval inf_exec_stmt $stmt $USERNAME $stmt_params]
	} msg]} {
		err_bind $msg
	}

	inf_close_stmt $stmt

	go_control
}


# Bind the "trigger control" page
#
proc _go_control_trig args {

	global DB
	global TRIG

	if {![op_allowed IovManageSystem]} {
		err_bind "You do not have permission to access System Level Iovation settings"
		go_control
		return
	}

	set stmt [inf_prep_sql $DB {
		select
			trigger_type,
			desc,
			enabled,
			freq_str,
			max_count
		from
			tIovTrigCtrl
	}]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumTrig [set nrows [db_get_nrows $res]]

	for {set r 0} {$r < $nrows} {incr r} {
		set TRIG($r,trigger_type) [db_get_col $res $r trigger_type]
		set TRIG($r,desc)         [db_get_col $res $r desc]
		set TRIG($r,freq_str)     [db_get_col $res $r freq_str]
		set TRIG($r,enabled)      [db_get_col $res $r enabled]
		set TRIG($r,max_count)    [db_get_col $res $r max_count]
	}

	db_close $res

	tpBindVar TrigType     TRIG trigger_type trig_idx
	tpBindVar TrigDesc     TRIG desc         trig_idx
	tpBindVar TrigFreqStr  TRIG freq_str     trig_idx
	tpBindVar TrigEnabled  TRIG enabled      trig_idx
	tpBindVar TrigMaxCount TRIG max_count    trig_idx
}


# Update the trigger control information
#
proc do_control_trig args {

	global DB USERNAME

	if {![op_allowed IovManageSystem]} {
		err_bind "You do not have permission to update System Level Iovation settings"
		go_control
		return
	}

	set sql_params {
		p_trigger_type = ?,
		p_enabled      = ?,
		p_freq_str     = ?,
		p_max_count    = ?
	}

	set sql [subst {
		execute procedure pUpdIovTrigCtrl (
			p_adminuser = ?,
			$sql_params
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	for {set i 0} {$i < [reqGetArg NumTrig]} {incr i} {
		set trigger_type   [string trim [reqGetArg "row_${i}"]]
		set trig_enabled   [string trim [reqGetArg "Enabled_${trigger_type}"]]
		set trig_freq_str  [string trim [reqGetArg "FreqStr_${trigger_type}"]]
		set trig_max_count [string trim [reqGetArg "MaxCount_${trigger_type}"]]

		if {[lsearch {Y N} $trig_enabled] == -1} {
			set trig_enabled "N"
		}

		if {![regexp {^(\*|[0-9]+(,[0-9]+)*)$} $trig_freq_str]} {
			err_bind "Frequency string invalid, expected '*' or comma-separated integers"
			break
		}

		set stmt_params { \
			$trigger_type \
			$trig_enabled \
			$trig_freq_str \
			$trig_max_count \
		}

		if {[catch {
			set res [eval inf_exec_stmt $stmt $USERNAME $stmt_params]
		} msg]} {
			err_bind $msg
			break
		}
	}

	inf_close_stmt $stmt

	go_control
}


# Bind the "customer trigger control" page
#
proc query_control_cust_trig_args args {

	global DB
	global CUSTTRIG

	if {![op_allowed IovManageAccount]} {
		err_bind "You do not have permission to update Account Level Iovation settings"
		go_control
		return
	}

	set action [reqGetArg SubmitName]

	if {$action == "Query"} {

		set where [list]

		set username     [string trim [reqGetArg SR_Username]]
		set trigger_type [string trim [reqGetArg SR_TrigType]]
		set enabled      [string trim [reqGetArg SR_Enabled]]
		set max_count_1  [string trim [reqGetArg SR_MaxCount1]]
		set max_count_2  [string trim [reqGetArg SR_MaxCount2]]

		if {[reqGetArg SR_ExactName] == "Y"} {
			set op "="
		} else {

			# force to provide minimum characters in search criteria
			set _min_chars [min_search_chars $username]
			if {[min_search_chars $username] != "OK"} {
				err_bind "Must provide no less than $_min_chars characters for\
					Username"
				reqSetArg SubmitName ""
				go_control
				return
			}

			set op "like"
			append username "%"
		}

		if {[reqGetArg SR_Ignorecase] == "Y"} {
			lappend where "[upper_q c.username] $op [upper_q '${username}']"
		} else {
			lappend where "c.username $op '${username}'"
		}

		if {$trigger_type != ""} {
			lappend where "citc.trigger_type = '$trigger_type'"
		}

		if {$enabled != ""} {
			if {$enabled == "sys"} {
				lappend where "citc.enabled is null"
			} else {
				lappend where "citc.enabled = '$enabled'"
			}
		}

		if {$max_count_1 != ""} {
			lappend where "citc.max_count >= '$max_count_1'"
		}

		if {$max_count_2 != ""} {
			lappend where "citc.max_count <= '$max_count_2'"
		}

		if {[llength $where]} {
			set where "and [join $where { and }]"
		}

		set sql [subst {
			select
				c.username,
				c.cust_id,
				itc.desc,
				citc.trigger_type,
				citc.enabled,
				citc.freq_str,
				citc.max_count
			from
				tCustomer        c,
				tCustIovTrigCtrl citc,
				tIovTrigCtrl     itc
			where
				c.cust_id        = citc.cust_id      and
				itc.trigger_type = citc.trigger_type
			$where
			order by
				c.username asc
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		tpSetVar NumCustTrig [set nrows [db_get_nrows $res]]

		for {set r 0} {$r < $nrows} {incr r} {
			set CUSTTRIG($r,username)     [db_get_col $res $r username]
			set CUSTTRIG($r,cust_id)      [db_get_col $res $r cust_id]
			set CUSTTRIG($r,desc)         [db_get_col $res $r desc]
			set CUSTTRIG($r,trigger_type) [db_get_col $res $r trigger_type]
			set CUSTTRIG($r,enabled)      [db_get_col $res $r enabled]
			set CUSTTRIG($r,freq_str)     [db_get_col $res $r freq_str]
			set CUSTTRIG($r,max_count)    [db_get_col $res $r max_count]
		}

		db_close $res

		tpBindVar Username     CUSTTRIG username     ctrig_idx
		tpBindVar CustId       CUSTTRIG cust_id      ctrig_idx
		tpBindVar TrigDesc     CUSTTRIG desc         ctrig_idx
		tpBindVar TrigType     CUSTTRIG trigger_type ctrig_idx
		tpBindVar TrigEnabled  CUSTTRIG enabled      ctrig_idx
		tpBindVar TrigFreqStr  CUSTTRIG freq_str     ctrig_idx
		tpBindVar TrigMaxCount CUSTTRIG max_count    ctrig_idx

		_rebind_query_data

		asPlayFile -nocache iovation_control_cust_trig.html

		catch {unset CUSTTRIG}

		return

	} else {

		set stmt [inf_prep_sql $DB {
			select
				trigger_type,
				desc
			from
				tIovTrigCtrl
		}]
		set res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCustTrig [set nrows [db_get_nrows $res]]

		for {set r 0} {$r < $nrows} {incr r} {
			set CUSTTRIG($r,trigger_type) [db_get_col $res $r trigger_type]
			set CUSTTRIG($r,desc)         [db_get_col $res $r desc]
		}

		db_close $res

		tpBindVar CustTrigType CUSTTRIG trigger_type ctrig_idx
		tpBindVar CustTrigDesc CUSTTRIG desc         ctrig_idx
	}
}


# Update the account level settings
#
proc do_control_cust_trig args {

	global DB USERNAME

	if {[reqGetArg SubmitName] == "Back"} {
		ADMIN::IOVATION::go_control
		return
	}

	if {![op_allowed IovManageAccount]} {
		err_bind "You do not have permission to update Account Level Iovation settings"
		go_control
		return
	}

	set sql_params {
		p_cust_id      = ?,
		p_trigger_type = ?,
		p_enabled      = ?,
		p_freq_str     = ?,
		p_max_count    = ?
	}

	set sql [subst {
		execute procedure pUpdCustIovTrigCtrl (
			p_adminuser = ?,
			$sql_params
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	for {set i 0} {$i < [reqGetArg NumCustTrig]} {incr i} {

		set cust_id        [string trim [reqGetArg "CustId_${i}"]]
		set trigger_type   [string trim [reqGetArg "TrigType_${i}"]]
		set trig_enabled   [string trim [reqGetArg "Enabled_${i}"]]
		set trig_freq_str  [string trim [reqGetArg "FreqStr_${i}"]]
		set trig_max_count [string trim [reqGetArg "MaxCount_${i}"]]

		if {[lsearch {Y N ""} $trig_enabled] == -1} {
			set trig_enabled "N"
		}

		if {![regexp {^(|\*|[0-9]+(,[0-9]+)*)$} $trig_freq_str]} {
			err_bind "Frequency string invalid, expected empty or '*' or comma-separated integers"
			break
		}

		set stmt_params { \
			$cust_id \
			$trigger_type \
			$trig_enabled \
			$trig_freq_str \
			$trig_max_count \
		}

		if {[catch {
			set res [eval inf_exec_stmt $stmt $USERNAME $stmt_params]
		} msg]} {
			err_bind $msg
			break
		}
	}

	inf_close_stmt $stmt

	set return_page [reqGetArg ReturnPage]
	if {$return_page == "GoCust"} {
		ADMIN::CUST::go_cust
	} else {
		_rebind_query_data
		reqSetArg SubmitName "Query"
		query_control_cust_trig_args
	}
}


# Rebind query search data
#
proc _rebind_query_data {} {
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[string range [reqGetNthName $i] 0 2] == "SR_"} {
			tpBindString [reqGetNthName $i] [string trim [reqGetNthVal $i]]
		}
	}
}


# To check for minimum characters entered in search criteria
#
# Accepts
#    override - override config setting for minimum number of characters
#
# Returns:
#    OK       - if success
#    min_char - if failed - minimum number of chars required
#
# (note: can be moved to shared utils if needed)
#
proc min_search_chars {str {override -1}} {

	set min_char    [OT_CfgGet ADMIN_SEARCH_MIN_CHAR    2]
	set min_char_re [OT_CfgGet ADMIN_SEARCH_MIN_CHAR_RE {[a-zA-Z0-9]}]

	if {$override > -1} {
		set min_char $override
	}

	if {$min_char > 0 && [regexp -all $min_char_re $str] < $min_char} {
		return $min_char
	}

	return "OK"
}

}
