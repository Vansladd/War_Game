# ==============================================================
# $Id: anti_laundering.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

# This file builds the view of the Anti-Money Laundering page
#
# Configuration:
#   FUNC_MENU_AML_CONTROL = 1 
#
# Also, admin user needs permission to perform action:
#   ManageAntiLaunder

namespace eval ADMIN::ANTI_LAUNDERING {

asSetAct ADMIN::ANTI_LAUNDERING::GoAntiLaundering [namespace code go_anti_laundering]
asSetAct ADMIN::ANTI_LAUNDERING::DoControl [namespace code do_control]

#
# ----------------------------------------------------------------------------
# Got to the "control" page
# ----------------------------------------------------------------------------
#
proc go_anti_laundering args {

	global DB
	global HIGH_ROLLERS

	# extract and bind AML options
	set sql {
		select
			threshold,
			gen_email,
			bets_email,
			casino_email,
			games_email
		from tAMLOpt
	}
	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	tpBindString AlertThreshold    [db_get_col $res threshold]
	tpBindString AlertEmail        [db_get_col $res gen_email]
	tpBindString BetsAlertEmail    [db_get_col $res bets_email]
	tpBindString CasinoAlertEmail  [db_get_col $res casino_email]
	tpBindString GamesAlertEmail   [db_get_col $res games_email]
	db_close $res

	# Build HIGH_ROLLERS and num_rollers with a query
	# note:  not sure where to get shop_id
	# need to import flags for AMLReportExempt
	# Only grabbing those customers marked as suspicious
	set sql {
		select
			tCustomer.cust_id,
			tCustomer.username,
			tCustomer.cr_date,
			tCustomerReg.fname,
			tCustomerReg.mname,
			tCustomerReg.lname,
			tCustomerReg.dob,
			tAMLHighRollers.stakes,
			tAMLHighRollers.returns,
			tCustomerFlag.flag_value
		from
			tAMLHighRollers,
			tCustomer,
			tCustomerReg,
		outer tCustomerFlag
		where
			tCustomer.cust_id = tAMLHighRollers.cust_id
		and tAMLHighRollers.susp_activity = 'Y'
		and tCustomerReg.cust_id = tCustomer.cust_id
		and tCustomerFlag.cust_id = tCustomerReg.cust_id
		and tCustomerFlag.flag_name = 'AMLExempt'
		and tCustomerFlag.flag_value = 'Y'
	}
	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# Build HIGH_ROLLERS array for binding from db result
	# note:  not sure where to get shop_id
	set num_rollers [db_get_nrows $res]
	for {set i 0} {$i<$num_rollers} {incr i} {
		set HIGH_ROLLERS($i,cust_id)        [db_get_col $res $i cust_id]
		set HIGH_ROLLERS($i,lname)           [db_get_col $res $i lname]
		set HIGH_ROLLERS($i,fname)           [db_get_col $res $i fname]
		set HIGH_ROLLERS($i,mname)           [db_get_col $res $i mname]
		set HIGH_ROLLERS($i,username)       [db_get_col $res $i username]
		set HIGH_ROLLERS($i,shop_id)        "?"
		set HIGH_ROLLERS($i,cr_date)        [db_get_col $res $i cr_date]
		set HIGH_ROLLERS($i,stakes)         [db_get_col $res $i stakes]
		set HIGH_ROLLERS($i,returns)        [db_get_col $res $i returns]
		set HIGH_ROLLERS($i,dob)            [db_get_col $res $i dob]

		set flag_val                        [db_get_col $res -nullind $i flag_value]
		if {![lindex $flag_val 1]}  {
			set HIGH_ROLLERS($i,excluded)       [lindex $flag_val 0]
		} else {
			set HIGH_ROLLERS($i,excluded)       "N"
		}
	}
	db_close $res
	tpBindVar HighRoller_custId       HIGH_ROLLERS cust_id rollerIdx
	tpBindVar HighRoller_lname        HIGH_ROLLERS lname rollerIdx
	tpBindVar HighRoller_fname        HIGH_ROLLERS fname rollerIdx
	tpBindVar HighRoller_mname        HIGH_ROLLERS mname rollerIdx
	tpBindVar HighRoller_username     HIGH_ROLLERS username rollerIdx
	tpBindVar HighRoller_shopId       HIGH_ROLLERS shop_id rollerIdx
	tpBindVar HighRoller_crDate       HIGH_ROLLERS cr_date rollerIdx
	tpBindVar HighRoller_stakes       HIGH_ROLLERS stakes rollerIdx
	tpBindVar HighRoller_returns      HIGH_ROLLERS returns rollerIdx
	tpBindVar HighRoller_dob          HIGH_ROLLERS dob rollerIdx
	tpBindVar HighRoller_excluded     HIGH_ROLLERS excluded rollerIdx

	tpSetVar numRollers $num_rollers

	asPlayFile -nocache anti_laundering.html
	array unset HIGH_ROLLERS
}


#
# ----------------------------------------------------------------------------
# Update control information
# ----------------------------------------------------------------------------
#
proc do_control args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdAMLOpt(
			p_adminuser        = ?,
			p_threshold        = ?,
			p_gen_email        = ?,
			p_bets_email       = ?,
			p_casino_email     = ?,
			p_games_email      = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		array set email_hash {
			AlertEmail        "General"
			BetsAlertEmail    "Betting"
			CasinoAlertEmail  "Casino/Poker"
			GamesAlertEmail   "Games"
		}
		foreach index [array names email_hash] {
			# set blank email address to "EMPTY"
			# and ignore those that are set to EMPTY
			set email [reqGetArg $index]
			switch -- $email {
				"" {
					reqSetArg $index "EMPTY"
					continue
				}
				EMPTY {continue}
				default {
					set alert_email_status [ob_chk::email $email]
					if {$alert_email_status != "OB_OK"} {
						error "$email_hash($index) Email address failed check with status = $alert_email_status"
					}
				}
			}
		}
		array unset email_hash
	} msg]} {
		err_bind $msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar UpdateFailed 1
	} elseif {[catch { 
		set res [inf_exec_stmt $stmt\
		                       $USERNAME\
		                       [reqGetArg AlertThreshold]\
		                       [reqGetArg AlertEmail]\
		                       [reqGetArg BetsAlertEmail]\
		                       [reqGetArg CasinoAlertEmail]\
		                       [reqGetArg GamesAlertEmail]]
		msg_bind "Options Update Successful.  Changes will be applied next time Anti-Laundering Check is run.<br/>Check back in a few minutes to see updates to High Rolling Customers table."
	} msg]} {
		err_bind $msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar UpdateFailed 1
		inf_close_stmt $stmt
	}

	inf_close_stmt $stmt

	go_anti_laundering

}


}
