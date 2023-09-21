# ==============================================================
# $Id: cust_checks.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUSTBLOCK {

asSetAct ADMIN::CUSTBLOCK::DoCustDepBlocks [namespace code do_cust_dep_blocks]

#
# ----------------------------------------------------------------------------
# Customer deposit blocks
# ----------------------------------------------------------------------------
#
proc do_cust_dep_blocks args {

	global DB DATA

	set where [list]

	#From-date where clause
	if {[string length [set from_date [reqGetArg BDate1]]] == 10} {
		lappend where "b.cr_date >= '$from_date 00:00:00'"
	} elseif {$from_date != ""} {
		lappend where "b.cr_date >= '$from_date'"
	}

	#To-date where clause
	if {[string length [set to_date [reqGetArg BDate2]]] == 10} {
		lappend where "b.cr_date <= '$to_date 23:59:59'"
	} elseif {$to_date != ""} {
		lappend where "b.cr_date <= '$to_date'"
	}

	#Result where clause
	if {[set result [reqGetArg Result]] != "-"} {
		lappend where " result='$result'"
	}

	#Username where clause
	if {[set username [reqGetArg Username]] != ""} {

		if {[reqGetArg ignorecase] == "on"} {
		   lappend where "c.username_uc = '[string toupper $username]'"
		} else {
		   lappend where " c.username = '$username'"
		}
	}

	set sql [subst {
		select
			b.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			b.cr_date,
			b.ipaddr,
			b.card_bin,
			b.postcode,
			b.ip_country,
			b.cc_country,
			b.list_entry,
			b.list_value,
			b.check_flags,
			b.result
		from
			tCustCheck b,
			tCustomer c,
			tAcct a
		where
			b.cust_id = c.cust_id and
			c.cust_id = a.cust_id and
			a.owner   <> 'D'
	}]

	#Add where clauses
	foreach clause $where {
		set sql "$sql and $clause"
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	array set DATA [list]

	set num_norm  0
	set num_elite 0

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {

		set block_res [db_get_col $res $r result]

		set DATA($r,acct_no)     [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($r,blocked)     [expr {$block_res == 1 ? "Y" : "N"}]
		set DATA($r,elite)       [db_get_col $res $r elite]
		set DATA($r,cr_date)     [db_get_col $res $r cr_date]
		set DATA($r,cust_id)     [db_get_col $res $r cust_id]
		set DATA($r,username)    [db_get_col $res $r username]
		set DATA($r,ipaddr)      [db_get_col $res $r ipaddr]
		set DATA($r,card_bin)    [db_get_col $res $r card_bin]
		set DATA($r,postcode)    [db_get_col $res $r postcode]
		set DATA($r,ip_country)  [db_get_col $res $r ip_country]
		set DATA($r,cc_country)  [db_get_col $res $r cc_country]
		set DATA($r,list_entry)  [db_get_col $res $r list_entry]
		set DATA($r,list_value)  [db_get_col $res $r list_value]
		set DATA($r,check_flags) [db_get_col $res $r check_flags]
		incr num_norm
		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo     DATA acct_no     check_idx
	tpBindVar Blocked    DATA blocked     check_idx
	tpBindVar Elite      DATA elite       check_idx
	tpBindVar Time       DATA cr_date     check_idx
	tpBindVar CustId     DATA cust_id     check_idx
	tpBindVar Username   DATA username    check_idx
	tpBindVar IPAddr     DATA ipaddr      check_idx
	tpBindVar CardBin    DATA card_bin    check_idx
	tpBindVar Postcode   DATA postcode    check_idx
	tpBindVar IPCountry  DATA ip_country  check_idx
	tpBindVar CCCountry  DATA cc_country  check_idx
	tpBindVar ListEntry  DATA list_entry  check_idx
	tpBindVar ListValue  DATA list_value  check_idx
	tpBindVar Flags      DATA check_flags check_idx

	asPlayFile -nocache cust_checks.html

	db_close $res

	unset DATA
}

}
