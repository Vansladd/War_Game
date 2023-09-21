# ==============================================================
# $Id: exclusions.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# OB::EXCLUSIONS Functionality for checking whether a
# a customer is excluded from a channel or
# external system/system group
# ==============================================================

namespace eval OB::EXCLUSIONS {
}


##
## Initializes sql for this library
##
proc OB::EXCLUSIONS::init args {

	ob_db::store_qry OB::EXCLUSIONS::check_prohibited_channel {
		select
			e.cust_id
		from
			tCustChanExcl e
		where
			e.cust_id = ?
			and e.channel_id = ?
	}

	ob_db::store_qry OB::EXCLUSIONS::check_prohibited_system {
		select
			e.cust_id
		from
			tCustSysExcl e,
			tXSysHostGrpLk l,
			tXSysHost h 
		where
			e.cust_id = ?
			and e.group_id = l.group_id
			and l.system_id = h.system_id
			and h.system_id = ?
	}

	# Check to see whether a customer has any system exclusions
	ob_db::store_qry OB::EXCLUSIONS::has_prohibited_system {
		select
			first 1 e.cust_id
		from
			tCustSysExcl e
		where
			e.cust_id = ?
	}
	
	#
	# Restrictions on account type (CDT, DBT, DEP)
	#
	
	ob_db::store_qry OB::EXCLUSIONS::check_acct_prohibited_system {
		select
			a.acct_type
		from
			tAcctTypeExcl e,
			tAcct a,
			tXSysHostGrpLk l
		where
			e.excl_type = 'SYS'
			and e.acct_type = a.acct_type
			and e.ref_id = l.group_id
			and a.cust_id = ?
			and l.system_id = ?
	}
	
	ob_db::store_qry OB::EXCLUSIONS::check_acct_prohibited_channel {
		select
			a.acct_type
		from
			tAcctTypeExcl e,
			tAcct a
		where
			e.acct_type = a.acct_type
			and a.cust_id  = ?
			and e.ref_char = ?
	}
}



#
# Checks whether a customer is allowed to use a channel
# returns a list -
#     -check_success  (OK or FAIL for whether the check runs alright)
#     -channel_allowed  1 if the customer can use the channel else 0
#
proc OB::EXCLUSIONS::check_channel_allowed {cust_id channel_id} {
	
	set exclusions 0
	
	if {[catch {
		set rs [ob_db::exec_qry OB::EXCLUSIONS::check_prohibited_channel \
			$cust_id $channel_id]
		set exclusions [expr {$exclusions + [db_get_nrows $rs]}]
		ob_db::rs_close $rs

		if {[OT_CfgGet FUNC_ACCT_TYPE_EXCL 0]} {
			set rs [ob_db::exec_qry OB::EXCLUSIONS::check_acct_prohibited_channel \
				$cust_id $channel_id]
			set exclusions [expr {$exclusions + [db_get_nrows $rs]}]
			ob_db::rs_close $rs
		}
	} msg]} {
		ob_log::write ERROR {Failed to check prohibited channel: $msg}
		return [list FAIL 0]
	}

	if {$exclusions > 0} {
		set result [list OK 0]
	} else {
		set result [list OK 1]
	}

	ob_db::rs_close $rs
	return $result
}


#
# Checks whether a customer is allowed to use a system, if no system id is
# provided will reject a customer if they have any system exclusions
# returns a list -
#     -check_success  (OK or FAIL for whether the check runs alright)
#     -system_allowed  1 if the customer can use the system else 0
#
proc OB::EXCLUSIONS::check_system_allowed {cust_id {system_id ""}} {
	ob_log::write INFO {OB::EXCLUSIONS::check_system_allowed cust_id: $cust_id system_id: $system_id}
	
	set exclusions 0

	if {[string length $system_id]} {
		if {[catch {
			# Check for per customer exclusions
			set rs [ob_db::exec_qry OB::EXCLUSIONS::check_prohibited_system \
				$cust_id $system_id]
			set exclusions [expr {$exclusions + [db_get_nrows $rs]}]
			ob_db::rs_close $rs
			
			if {[OT_CfgGet FUNC_ACCT_TYPE_EXCL 0]} {
				# Check for acct type exclusions
				set rs [ob_db::exec_qry OB::EXCLUSIONS::check_acct_prohibited_system \
					$cust_id $system_id]
				set exclusions [expr {$exclusions + [db_get_nrows $rs]}]
				ob_db::rs_close $rs
			}
		} msg]} {
			ob_log::write ERROR {Failed to check prohibited system: $msg}
			return [list FAIL 0]
		}
	} else {
		if {[OT_CfgGet USE_PROHIBITED_SYSTEMS_CHECK 0]} {
			if {[catch {
				set rs [ob_db::exec_qry OB::EXCLUSIONS::has_prohibited_system \
					$cust_id]
				set exclusions [expr {$exclusions + [db_get_nrows $rs]}]
				ob_db::rs_close $rs
			} msg]} {
				ob_log::write ERROR {Failed to check for prohibited systems: $msg}
				return [list FAIL 0]
			}
		} else {
			return [list OK 1]
		}
	}

	if {$exclusions > 0} {
		set result [list OK 0]
	} else {
		set result [list OK 1]
	}

	ob_db::rs_close $rs
	return $result
}



OB::EXCLUSIONS::init
