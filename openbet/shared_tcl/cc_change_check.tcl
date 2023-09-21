# $Id: cc_change_check.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Card Change Check
#  Functionality to determine whether a changing a customers credit card
#  is safe.
#
#
# Procedures:
#  cc_change::init                    - one time initialisation. called in file
#  cc_change::perform_checks          - performs configured in checks
#  cc_change::cust_acct_detail        - retrieve customer information
#  cc_change::check_recent_xsysfer - check for transactions to external
#                                       systems within configurable time period
#  cc_change::check_open_ballssub     - check for active balls subscriptions
#  cc_change::check_balance           - check the customer's balance
#  cc_change::check_unsettled_bets    - check for unsettled bets
#                                       (pools, xgame, sports)
#  cc_change::check_multi_state_games - check for openbet multistate FOG games
#  cc_change::check_pending_payments  - check for pending payments
#  cc_change::check_bossmedia         - check for open Bossmedia Casino sessions
#  cc_change::check_sngsub            - check for outstanding SNG subscriptions
#  cc_change::check_acct_open	      - check the account status is active
#  cc_change::check_card_changes      - check the number of card changes in last 30 days
#  cc_change::check_open_subs         - check for active external subscriptions
#
#  cc_change::remove_cpm              - remove's a customer pay method
#
# Config Items:
#  FUNC_CARD_CHANGE_ALLOWED           - flag to define whether any checks shall
#                                       be performed (0|1)
#  CC_CHANGE_CHECKS                   - list all procedures names which need to
#                                       be run. may contain procedures defined
#                                       within this file or customer specific
#                                       checks defined elsewhere
#  CC_CHANGE_UPMT_WAIT                - time period in days to check for unknown
#                                       payments. defaults to 3
#  CC_CHANGE_PPMT_WAIT                - time period in days to check for unknown
#                                       payments. defaults to 7
#  CC_CHANGE_XSYSFER_WAIT             - time period in hours to check for
#                                       transfers to external systems.
#                                       defaults to 24
#
#
#  EXTERNAL_SYS_SUBS_NOT_ALLOWED      - host system names that are not allowed to have
#                                       active subscriptions for card change
#
#  PMT_CHANGE_CHK:                   - Limits configurable from the admin screens or in tPmtChangeChk
#                                      or that are in the table tPmtChangeChk
#      PLAYTECHCASINO_WALLET_LIMIT    - balance limit for playtechcasino (Above
#                                       this limit user cannot change his cc)
#      PLAYTECHPOKER_WALLET_LIMIT     - balance limit for playtechpoker (Above 
#                                       this limit user cannot change his cc)
#      PLAYTECHPOKER_BONUS_LIMIT      - bonus limit for playtech poker. Above 
#                                       this limit user cannot change his cc)
#      PLAYTECHCASINO_BONUS_LIMIT     - bonus limit for playtech casino. Above 
#                                       this limit user cannot change his cc)
#      CC_MAX_POKER_IN_PLAY           - poker in-play money (money on the table,
#                                       it only exists in poker and make 
#                                       no sense in Casino. Above this limit user
#                                       cannot change his cc)
#      CC_MAX_SB_BALANCE              - max sportsbook balance allowed for card change
#      CC_MAX_EXT_BALANCE             - max external systems balance allowed for card change
#      CC_MAX_TOTAL_BALANCE           - max total balance allowed for card change
#      CC_MAX_CARD_CHANGES            - number of card changes allowed in the specified period
#      CARD_CHANGE_PERIOD             - Period for which to count card changes (days)
#      MAX_PMB_REMOVE
#
# Synopsis:
#  Call cc_change::perform_checks to perform a series of checks to determine
#  whether changing a customer's card is safe. Any checks performed are
#  specified  in configuration item CARD_CHANGE_CHECKS as list of procedure
#  names. Each check procedure is expected to be of following format:
#
#  PARAMS:  cust_id acct_id
#  RETURNS: list of format
#               - success code: 0 - Check Failed
#                               1 - Check Succeeded
#                               2 - Check could not be executed
#               - message:      Optional description (i.e. why check failed)
#               - check name:   Check Identifier (i.e. CC_CHANGE_BALANCE for
#                               balance check)
#
#  This file should contain relatively generic check procedures. Customer
#  specific check procedure can be defined elsewhere and configured in the
#  same way.
#
#  cc_change::perform_checks will return a list of overall success/failure
#  and a list of all values returned by checks performed.
#
#
# List of check names:
#  cc_change::check_recent_xsysfer    - CC_CHANGE_XSYSFER
#  cc_change::check_open_ballssub     - CC_CHANGE_BALLSSUB
#  cc_change::check_balance           - CC_CHANGE_BALANCE
#  cc_change::check_game_acct_balance    - CC_CHANGE_GAME_ACCT_BALANCE
#  cc_change::check_playtech_poker_funds - CC_CHECK_PLAYTECH_RING_TOURN_FUNDS
#  cc_change::check_total_balance        - CC_CHANGE_TOTAL_BALANCE
#  cc_change::check_unsettled_bets    - CC_CHANGE_UNSETTLEDBETS
#  cc_change::check_multi_state_games - CC_CHANGE_GAMESMULTISTATE
#  cc_change::check_pending_payments  - CC_CHANGE_PENDINGPMTS
#  cc_change::check_bossmedia         - CC_CHANGE_BOSSMEDIA
#  cc_change::check_sngsub            - CC_CHANGE_SNGSUB
#  cc_change::check_acct_open	      - CC_CHANGE_ACCT_OPEN
#  cc_change::check_card_changes      - CC_CHANGE_CARD_CHANGES
#  cc_change::check_open_subs	      - CC_CHANGE_CHECK_OPEN_SUBS

# Namespace Variables
#
namespace eval cc_change {
	variable CARD_CHANGE_CHECKS
}


package require tls
package require http
package require tdom


# Initialisation
#
proc cc_change::init {} {

	# initialise variables
	cc_change::_init_variables

	# set sql
	cc_change::_set_sql
}



# Read configuration for variable CARD_CHANGE_CHECKS
#
proc cc_change::_init_variables args {

	variable CARD_CHANGE_CHECKS

	set CARD_CHANGE_CHECKS [OT_CfgGet CARD_CHANGE_CHECKS ""]

	ob::log::write INFO {CARD_CHANGE_CHECKS: $CARD_CHANGE_CHECKS}
}



# Set shared sql
#
proc cc_change::_set_sql {} {

	global SHARED_SQL


	set SHARED_SQL(cc_change::cust_acct_detail) {
		select
			a.acct_id,
			a.acct_type
		from
			tCustomer c,
			tAcct     a
		where
			c.cust_id = a.cust_id and
			c.cust_id = ?
	}




	set SHARED_SQL(cc_change::check_balance) {
		select
			a.ccy_code,
			a.balance,
			b.exch_rate
		from
			tAcct a,
			tCcy  b
		where
			a.acct_id = ?
			and a.ccy_code = b.ccy_code
	}

	set SHARED_SQL(cc_change::check_currency) {
		select
			a.ccy_code,
			b.exch_rate
		from
			tAcct a,
			tCcy  b
		where
			a.cust_id = ?
			and a.ccy_code = b.ccy_code
	}

	set SHARED_SQL(cc_change::check_unsettled_bets) {

		select
			bu.bet_id
		from
			tBetUnstl bu
		where
			bu.acct_id = ?

		union

		select
			x.xgame_bet_id
		from
			tXGameSub s,
			tXGameBet x
		where
			x.settled_at is null            and
			s.xgame_sub_id = x.xgame_sub_id and
			s.acct_id      = ?

		union

		select
			pu.pool_bet_id
		from
			tPoolBet      pb,
			tPoolBetUnstl pu
		where
			pu.pool_bet_id = pb.pool_bet_id and
			pb.acct_id     = ?
	}


	set SHARED_SQL(cc_change::check_multi_state_games) {
		select
			s.cg_game_id,
			g.display_name
		from
			tCGAcct        a,
			tCGGameSummary s,
			tCGGame        g,
			tCGJavaClass   j,
			tCGClass       c
		where a.acct_id      = ?
		  and a.cg_acct_id   = s.cg_acct_id
		  and s.state        = 'O'
		  and s.cg_id        = g.cg_id
		  and g.cg_class     = c.cg_class
		  and c.java_class   = j.java_class
		  and g.free_play    = 'N'
		  and j.multi_state  = 'Y'
		  and not exists (
			select
				1
			from tCGGSFinished
			where cg_game_id = s.cg_game_id
		  )
	}

	# Ignore pending transactions that can be cancelled (tPayMthd.cancel_pending)
	# if they are the only payments via the payment method
	set SHARED_SQL(cc_change::last_transactions_by_status) {
		select
			p.pmt_id
		from
			tPmt p,
			tPayMthd m
		where
			p.acct_id = ? and
			p.cr_date between ? and CURRENT and
			p.status in (?,?,?,?) and
			m.pay_mthd = p.ref_key
			and not
				(m.cancel_pending = "Y" and p.status = "P"
				 and not exists (
				 	select
				 		1
				 	from tPmt p2
				 	where
				 		p2.cpm_id = p.cpm_id
				 		and p2.status NOT IN ('P','X')
				 	))
	}

	set SHARED_SQL(cc_change::check_open_ballssub) {
		select first 1
			*
		from
			tBallsActSub s
		where
			s.acct_id = ?
	}


	set SHARED_SQL(cc_change::check_recent_xsysfer) {
		select distinct
			h.name,
			h.system_id
		from
			tXSysXfer x,
			tXSysHost h
		where
			h.system_id = x.system_id and
			x.acct_id   = ?           and
			x.cr_date > current - ? units hour
	}

        set SHARED_SQL(cc_change::check_bossmedia) {
                select first 1
			*
                from
                        tBMCust b
                where
                        b.cust_id   = ?
        }

        set SHARED_SQL(cc_change::check_sngsub) {
                select first 1
			*
                from
                        tUGDrawSub d
                where
                        d.acct_id   = ? and
			d.num_complete < d.num_draws
        }

	set SHARED_SQL(cc_change::check_acct_open) {
		select
			status
		from
			tCustomer a
		where
			a.cust_id = ?
	}

	set SHARED_SQL(cc_change::get_username) {
		select
			username,
			password,
			password_salt
		from
			tCustomer
		where
			cust_id = ?
	}

	set SHARED_SQL(cc_change::check_recent_changes) [subst {
		select
			count(*) as changes
		from
			tCpmCC
		where
			cust_id = ? and
			cr_date > current - ? units day
	}]

	set SHARED_SQL(cc_change::check_open_subs) {
		select
			host.name,
			count(host.system_id) as count
		from
			tXSysSub sub,
			tXSysHost host
		where
			sub.acct_id = ? and
			sub.status = 'A' and
			sub.system_id = host.system_id
		group by
			1
	}

	# get pending payments, used by remove cpm to cancel pending payments
	set SHARED_SQL(cc_change::get_pending_payments) {
		select
			p.pmt_id,
			m.cancel_pending,
			m.pay_mthd
		from
			tPmt p,
			tPayMthd m
		where
			p.cpm_id = ? and
			p.ref_key = m.pay_mthd and
			p.status =  "P" and
			m.cancel_pending = "Y"
	}

	# Updates the status of a payment
	set SHARED_SQL(cc_change::cancel_pmt) {
		execute procedure pPmtUpdStatus (
			p_pmt_id         = ?,
			p_status         = 'X'
		)
	}

	set SHARED_SQL(cc_change::remove_cpm_cust) {
		update
			tCustPayMthd
		set
			status = 'X'
		where
			cpm_id  = ? and
			cust_id = ?
	}

	set SHARED_SQL(cc_change::check_removed_cpm_pmts) {
		select
			1
		from
			tPmt p
		where
			p.cpm_id = ? and
			p.status <> "X"
	}

	# Get the configuration for card change checks
	set SHARED_SQL(cc_change::get_cc_change_config) {
		select
			max_sb_balance,
			max_ext_balance,
			max_total_balance,
			max_card_changes,
			card_change_period,
			max_pmb_remove,
			max_casino_wallet,
			max_poker_wallet,
			max_poker_in_play,
			max_poker_bonus,
			max_casino_bonus
		from
			tPmtChangeChk
	}

	set SHARED_SQL(cc_change::check_pending_payments_wtd) {
		select
			count(*)
		from
			tPmt p,
			tCPMGroupLink l1,
			tCPMGroupLink l2
		where
			l1.cpm_id = ? and
			l1.cpm_grp_id = l2.cpm_grp_id and
			p.cpm_id = l2.cpm_id and
			p.status = 'P' and
			p.payment_sort = 'W'
	}

}


# If this function returns 1 the rest of the checks are not made
proc cc_change::check_pmb_value {cust_id cpm_id} {
	variable PMT_CHANGE_CHK

	set rs [tb_db::tb_exec_qry cc_change::get_cc_change_config]

	set PMT_CHANGE_CHK(MAX_PMB_REMOVE)       [db_get_col $rs 0 max_pmb_remove]

	db_close $rs

	if {[cust_acct_type $cust_id] != "DEP"} {
		return	[list 0 [list 0 "Account type does not have pmb method balance checks" \
							CC_CHANGE_PMB_CHECK]]
	}

	# Get PMB Info - methods can be removed when pmb <= 0
	set pmb_result [payment_multi::calc_cpm_pmb $cust_id $cpm_id]

	if {[lindex $pmb_result 0]} {
		set pmb [lindex $pmb_result 1]
	} else {
		return [list 2 ""]
	}

	set rs_currency [tb_db::tb_exec_qry cc_change::check_currency $cust_id]

	if {[db_get_nrows $rs_currency] == 1} {
		set ccy_code [db_get_col $rs_currency 0 ccy_code]
		set exch_rate [db_get_col $rs_currency 0 exch_rate]
		set max_allowed_balance [expr $exch_rate * $PMT_CHANGE_CHK(MAX_PMB_REMOVE)]
		db_close $rs_currency
	} else {
		db_close $rs_currency
		return \
		[list 0 [list 0 "Cannot determine currency settings" CC_CHANGE_PMB_CHECK]]
	}

	if {$pmb <= $max_allowed_balance} {
		# PMB Balance less than minimum check that there are no associated pending
		# payments that could be reversed
		set rs_pending \
			[tb_db::tb_exec_qry cc_change::check_pending_payments_wtd $cpm_id]

		set pending [db_get_coln $rs_pending 0]
		db_close $rs_pending

		if {$pending} {
			return [list 0 [list 0 "Pending payments exists" CC_CHANGE_PMB_CHECK]]
		} else {
			return [list 1 [list 1 "Payment method balance is less than minimum" \
							CC_CHANGE_PMB_CHECK]]
		}
	}

	# Failed
	return [list 0 [list 0 "Payment method balance above minimum" CC_CHANGE_PMB_CHECK]]
}


# Perform checks specified by CARD_CHANGE_CHECKS
# Checks are expected to be in format specified in header comment
#
#  cust_id  - customer id
#
#  returns  - list of format
#             success flag - 0: failed
#                            1: success
#                            2: no checks performed
#             checks       - list of values returned by check
#                            procedures. checks procedures return
#                            lists of format
#                            success - 0|1|2
#                            message - details on check peformed
#                            check   - check identifier
#                            value   - value specific to check; eg for
#                                      check_pending_payment, return how many.
#
# It is possible to turn off all checks using FUNC_CARD_CHANGE_ALLOWED
#
proc cc_change::perform_checks {cust_id} {

	variable CARD_CHANGE_CHECKS
	variable PMT_CHANGE_CHK

	ob::log::write DEBUG {cc_change::perform_checks: $CARD_CHANGE_CHECKS}

	# is the card change check functionality activated
	if {![OT_CfgGet FUNC_CARD_CHANGE_ALLOWED 0]} {
		ob::log::write INFO {cc_change::perform_checks: \
		                     skipped all checks}
		return [list 2 ""]
	}

	# retrieve customers account id
	set acct_id [cc_change::cust_acct_detail $cust_id]
	if {$acct_id == ""} {
		ob::log::write INFO {cc_change::perform_checks: \
		                     Could not retrieve customer details}
		return [list 2 ""]
	}

	# initialise variables
	#
	set ret [list]
	set overall_success 1

	_get_cc_change_config $cust_id
	
	# execute each check specified
	foreach {check_proc args} $CARD_CHANGE_CHECKS {

		ob::log::write DEBUG {cc_change::perform_checks: \
		                      check_proc = $check_proc}

		# execute check procedure
		set check_result [eval $check_proc $cust_id $acct_id $args]

		# retrieve success flag
		set check_success [lindex $check_result 0]

		# if the check has failed for any reason set overall success to 0
		if {($check_success == 0) || ($check_success == 2)} {
			set overall_success 0
		}

		# append list of success, msg and check name to return value
		lappend ret $check_result

	}

	# return a list of overall success and check return values
	set ret [list $overall_success $ret]

	ob::log::write INFO {cc_change::perform_checks: $ret}
	return $ret

}



# Retrieve customer's account id
#
#  cust_id - customer_id
#
#  returns - account id or empty string on failure
#
proc cc_change::cust_acct_detail {cust_id args} {

	ob::log::write DEBUG {cc_change::cust_acct_detail: cust_id $cust_id}

	set acct_id ""

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::cust_acct_detail $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute cust_acct_detail: $msg}
		return ""
	}

	if {[db_get_nrows $rs] != 0} {
		set acct_id  [db_get_col $rs 0 acct_id]
	} else {
		ob::log::write ERROR {cc_change::cust_acct_detail: \
		                      Wrong number of rows returned.}
	}
	db_close $rs

	return $acct_id

}

proc cc_change::cust_acct_type {cust_id args} {
	ob::log::write DEBUG {cc_change::cust_acct_detail: cust_id $cust_id}

	set acct_type ""

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::cust_acct_detail $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute cust_acct_detail: $msg}
		return ""
	}

	if {[db_get_nrows $rs] != 0} {
		set acct_type  [db_get_col $rs 0 acct_type]
	} else {
		ob::log::write ERROR {cc_change::cust_acct_type: \
		                      Wrong number of rows returned.}
	}
	db_close $rs

	return $acct_type
}



# Check for transfers to external systems within time period specified
# by config item CC_CHANGE_XSYSFER_WAIT (default 24)
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_XSYSFER
#            value
#               how many transfers
#
proc cc_change::check_recent_xsysfer {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_recent_xsysfer: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_XSYSFER"

	# retrieve time period to check in
	set waittime [OT_CfgGet CC_CHANGE_XSYSFER_WAIT 24]

	if {[catch {
		set rs  [tb_db::tb_exec_qry cc_change::check_recent_xsysfer $acct_id \
		                                                            $waittime]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_recent_xsysfer: $msg}
		set success  2
		set msg_txt  "Failed to determine if customer has transfered funds."
		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	set hosts [list]

	if {$nrows > 0} {
		ob::log::write INFO {cc_change::check_recent_xsysfer: \
		                     Customer has transfered to external systems}

		for {set i 0} {$i < $nrows} {incr i} {
			lappend hosts [db_get_col $rs $i name]
		}

		set    success  0
		set    msg_txt  "Customer has transfered money to"
		append msg_txt  "[join $hosts ,] in the last $waittime hours."
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_recent_xsysfer: \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $nrows]

}



# Check for openbet balls subscriptions
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_BALLSSUB
#            value
#               how many subs
#
proc cc_change::check_open_ballssub {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_open_ballssub: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_BALLSSUB"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_open_ballssub $acct_id]
	} msg]} {
		ob::log::write ERROR \
		              {Failed to execute check_open_ballssub: $msg}

		set    success 2
		set    msg_txt "Failed to determine if the customer has "
		append msg_txt "open Balls subscriptions."

		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	# if the customer has open balls subscritions
	if {$nrows != 0} {
		ob::log::write INFO {cc_change::check_open_ballssub: \
		                     Customer has open balls subscriptions.}
		set success 0
		set msg_txt "Customer has open Balls subscriptions."
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_open_ballssub: \
	                     [list $success $msg_txt $check]}

	return [list $success $msg_txt $check $nrows]

}



# Check whether the customer has a balance below the max allowed balance for a card change
# specified in CARD_CHANGE_MAX_BALANCE
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_BALANCE
#            value
#               balance
#
proc cc_change::check_balance {cust_id acct_id args} {

	variable PMT_CHANGE_CHK

	ob::log::write DEBUG {cc_change::check_balance: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_BALANCE"
	set balance -1

	#config for the max allowed GBP
	set max_allowed_balance $PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_balance $acct_id]
	} msg]} {

		ob::log::write ERROR {Failed to execute check_balance: $msg}

		set msg_txt "Failed to determine the customer's balance."
		set success 2

		return [list $success $msg_txt $check -1]

	}

	if {[db_get_nrows $rs] != 1} {

		ob::log::write ERROR {cc_change::check_balance: \
		                      Balance check did not return one row.}

		set msg_txt "Failed to determine the customer's balance."
		set success 2

	} else {

		set balance  [db_get_col $rs 0 balance]
		set ccy_code [db_get_col $rs 0 ccy_code]
		# The limit is already converted to the customer currency

		# if the balance is greater than or equal to the last max allowed balance
		if {$balance > $max_allowed_balance} {
			ob::log::write INFO {cc_change::check_balance: \
			                     Balance is more than the max allowed balance :$max_allowed_balance}
			set success 0
			set msg_txt "The customer's account balance is: $balance $ccy_code.  Maximum balance allowed is: $max_allowed_balance"
		}

	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_balance: \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $balance]

}



# Check whether the customer has a balance below the max allowed balance for a card change
# specified in CARD_CHANGE_GAME_ACCT_MAX_BALANCE
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#               3: Partial fail, we want to know its a fail but allow the customer to change
#                  cards still.
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_GAME_ACCT_BALANCE
#            value
#               balance
#
proc cc_change::check_game_acct_balance {cust_id acct_id args} {

	variable PMT_CHANGE_CHK

	set fn {cc_change::check_game_acct_balance}

	variable CC_CUST
	variable XML_DOM

	ob::log::write DEBUG {${fn}: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_GAME_ACCT_BALANCE"
	set balance -1


	# Config for the max allowed GBP
	set max_allowed_balance $PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)

	if {[_smart_reset CC_CUST]} {
		_get_cust_details $cust_id
	}

	if {$CC_CUST(status) != "OK"} {
		return [list 2 "Failed to retrieve username." $check -1]
	}

	set username $CC_CUST(username)


	# Build request, in the format:
	# 	<playerFundsInPlayRequest xmlns="http://gameaccount.com/xml/ns/gafferTape/playerStatus">
	# 		<partnerKey>partnerKey</partnerKey>
	# 		<partnerToken>partnerToken</partnerToken>
	# 		<userName>jblTest01</userName>
	# 	</playerFundsInPlayRequest>
	#

	variable XML_DOM
	catch {$XML_DOM delete}

	# Create root.
	set XML_DOM [dom createDocument "playerFundsInPlayRequest"]
	set E_Req [$XML_DOM documentElement]
	$E_Req setAttribute "xmlns" "http://gameaccount.com/xml/ns/gafferTape/playerStatus"

	# partnerKey
	set E_Key [$XML_DOM createElement "partnerKey"]
	$E_Key appendChild [$XML_DOM createTextNode [OT_CfgGet GAME_ACCT_PARTNER_KEY]]
	$E_Req appendChild $E_Key

	# partnerToken
	set E_Token [$XML_DOM createElement "partnerToken"]
	$E_Token appendChild [$XML_DOM createTextNode [OT_CfgGet GAME_ACCT_PARTNER_TOKEN]]
	$E_Req appendChild $E_Token

	# userName
	set E_UserName [$XML_DOM createElement "userName"]
	$E_UserName appendChild [$XML_DOM createTextNode $username]
	$E_Req appendChild $E_UserName

	set xml_req [$XML_DOM asXML]


	#
	# Send the XML
	#
	ob_log::write INFO {${fn}: xml:-\n$xml_req}
	set ncode ""
	if {[catch {
		# Send to request.
		set token [::http::geturl \
			[OT_CfgGet GAME_ACCT_URL] \
			-query   $xml_req \
			-type    "text/xml;charset=UTF-8" \
			-timeout [OT_CfgGet GAME_ACCT_TIMEOUT]]

		# Get the response.
		set xml_resp  [::http::data  $token]
		set ncode [::http::ncode $token]
		::http::cleanup $token
	} msg]} {
		ob_log::write INFO {${fn}: error sending response: $ncode}
		set msg_txt "Failed to make XML request to retrieve balance."
		set success 3

		return [list $success $msg_txt $check -1]
	}

	if {$ncode != "200"} {
		ob_log::write INFO {${fn}: error sending response: $ncode}
		set msg_txt "Failed to make XML request to retrieve balance."
		set success 3

		return [list $success $msg_txt $check -1]
	}


	#
	# Parse Response, in the format of:
	# 	<playerFundsInBalanceResponse xmlns="http://gameaccount.com/xml/ns/gafferTape/playerStatus">
	# 		<partnerKey>partnerKey</partnerKey>
	# 		<partnerToken>partnerToken</partnerToken>
	# 		<balance>123.45</balance>
	# 		<inPlay>23.99</inPlay>
	# 	</playerFundsInBalanceResponse>
	#


	ob_log::write INFO {${fn}:xml response:-\n$xml_resp}

	if {[catch {
		# If this is hanging around for any reason, nuke it.
		catch {$XML_DOM delete}
		ob_log::write INFO {${fn}:unpacking XML}

		set XML_DOM [dom parse $xml_resp]
		ob_log::write INFO {${fn}:parsed XML DOM}

		set resp [$XML_DOM documentElement]
		ob_log::write INFO {${fn}:found root element}

		# Get the two balances we're interested in.
		set resp_responseState [[$resp getElementsByTagName "*responseState"] text]

		if {$resp_responseState != "OK"} {
			error "Response failed with $responseState"
		}

		set resp_balance [[$resp getElementsByTagName "*balance"] text]
		set resp_inPlay  [[$resp getElementsByTagName "*inPlay"] text]

		if {$resp_balance == {} || $resp_inPlay == {}} {
			error "Error parsing response."
		}

		set balance [expr {$resp_balance + $resp_inPlay}]

	} msg]} {
		ob_log::write INFO {${fn}: Unable to parse XML}
		set response_state ""
		catch {
			set response_state [[$resp getElementsByTagName "*responseState"] text]
		}
		if {$response_state == "UNKNOWN_PLAYER"} {
			set msg_txt "Cannot find player in Game Account.  You may Proceed."
		} else {
			set msg_txt "Failed to parse the XML request."
		}
		set success 3

		return [list $success $msg_txt $check -1]
	}

	# We've parsed the XML request.
	ob_log::write INFO {${fn}: Successfully parsed XML}
	ob_log::write INFO {${fn}: Details - cust_id:$cust_id, balance:$resp_balance, inPlay:$resp_inPlay}

	# if the balance is greater than or equal to the last max allowed balance
	if {$balance > $max_allowed_balance} {
		ob::log::write INFO {${fn}: Balance is more than the max allowed balance :$max_allowed_balance}
		set success 0
		set msg_txt "The customer's account balance is: $balance. Maximum balance allowed is: $max_allowed_balance"
	}

	# Return success
	ob::log::write DEBUG {${fn}: \[list $success $msg_txt $check\]}

	# ensure 2 decimal places
	set balance [format %.2f $balance]

	return [list $success $msg_txt $check $balance]
}



# Check whether the customer has a total balance below the max allowed total
# balance for a card change specified in CC_MAX_TOTAL_BALANCE
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_MAX_TOTAL_BALANCE
#            value
#               balance
#
proc cc_change::check_total_balance {cust_id acct_id args} {

	variable PMT_CHANGE_CHK
	variable CC_CUST
	variable XML_DOM

	set fn {cc_change::check_total_balance}

	ob::log::write DEBUG {cc_change::check_total_balance: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_TOTAL_BALANCE"
	set balance -1

	ob::log::write DEBUG {${fn}: acct_id $acct_id}

	set game_acct_balance -1

	if {[_smart_reset CC_CUST]} {
		_get_cust_details $cust_id
	}

	if {$CC_CUST(status) != "OK"} {
		return [list 2 "Failed to retrieve username." $check -1]
	}

	set username $CC_CUST(username)
	set password $CC_CUST(password)

	# Build XML
	variable XML_DOM
	catch {$XML_DOM delete}

	# Create root.
	set XML_DOM [dom createDocument "playerFundsInPlayRequest"]
	set E_Req [$XML_DOM documentElement]
	$E_Req setAttribute "xmlns" "http://gameaccount.com/xml/ns/gafferTape/playerStatus"

	# partnerKey
	set E_Key [$XML_DOM createElement "partnerKey"]
	$E_Key appendChild [$XML_DOM createTextNode [OT_CfgGet GAME_ACCT_PARTNER_KEY]]
	$E_Req appendChild $E_Key

	# partnerToken
	set E_Token [$XML_DOM createElement "partnerToken"]
	$E_Token appendChild [$XML_DOM createTextNode [OT_CfgGet GAME_ACCT_PARTNER_TOKEN]]
	$E_Req appendChild $E_Token

	# userName
	set E_UserName [$XML_DOM createElement "userName"]
	$E_UserName appendChild [$XML_DOM createTextNode $username]
	$E_Req appendChild $E_UserName

	set xml_req [$XML_DOM asXML]

	# Send the XML
	ob_log::write INFO {${fn}: xml:-\n$xml_req}
	set ncode ""
	if {[catch {
		# Send to request.
		set token [::http::geturl \
			[OT_CfgGet GAME_ACCT_URL] \
			-query   $xml_req \
			-type    "text/xml;charset=UTF-8" \
			-timeout [OT_CfgGet GAME_ACCT_TIMEOUT]]

		# Get the response.
		set xml_resp  [::http::data  $token]
		set ncode [::http::ncode $token]
		::http::cleanup $token
	} msg]} {
		ob_log::write INFO {${fn}: error sending response: $ncode}
		set msg_txt "Failed to make XML request to retrieve balance."
		set success 3

		return [list $success $msg_txt $check -1]
	}

	if {$ncode != "200"} {
		ob_log::write INFO {${fn}: error sending response: $ncode}
		set msg_txt "Failed to make XML request to retrieve balance."
		set success 3

		return [list $success $msg_txt $check -1]
	}

	ob_log::write INFO {${fn}:xml response:-\n$xml_resp}

	# Parse response
	if {[catch {
		# If this is hanging around for any reason, nuke it.
		catch {$XML_DOM delete}
		ob_log::write INFO {${fn}:unpacking XML}

		set XML_DOM [dom parse $xml_resp]
		ob_log::write INFO {${fn}:parsed XML DOM}

		set resp [$XML_DOM documentElement]
		ob_log::write INFO {${fn}:found root element}

		# Get the two balances we're interested in.
		set resp_responseState [[$resp getElementsByTagName "*responseState"] text]

		if {$resp_responseState != "OK"} {
			error "Response failed with $responseState"
		}

		set resp_balance [[$resp getElementsByTagName "*balance"] text]
		set resp_inPlay  [[$resp getElementsByTagName "*inPlay"] text]

		if {$resp_balance == {} || $resp_inPlay == {}} {
			error "Error parsing response."
		}

		set game_acct_balance [expr {$resp_balance + $resp_inPlay}]

		# We've parsed the XML request.
		ob_log::write INFO {${fn}: Successfully parsed XML}
		ob_log::write INFO {${fn}: Details - cust_id:$cust_id, game_acct_balance:$resp_balance, inPlay:$resp_inPlay}

	} msg]} {
		ob_log::write INFO {${fn}: Unable to parse XML: assuming Game Account balance is 0}
		set response_state ""
		catch {
			set response_state [[$resp getElementsByTagName "*responseState"] text]
		}
		if {$response_state == "UNKNOWN_PLAYER"} {
			set msg_txt "Cannot find player in Game Account.  You may Proceed."
		} else {
			set msg_txt "Failed to parse the XML request: assuming Game Account balance is 0"
		}

		set game_acct_balance 0
	}

	# Get the Playtech balance
	set playtech_balance 0
	foreach system "PlaytechCasino PlaytechPoker" {

		playtech::get_balance $username $password $system

		if {[playtech::status] != "OK"} {
			return [list 2 {} $check -1]
		}

		set playtech_balance [expr {$playtech_balance + [playtech::response balance]}]
		set playtech_balance [expr {$playtech_balance + [playtech::response bonusbalance]}]
	}

	playtech::get_playerfunds "PlaytechPoker" $username
	if {[playtech::status] != "OK"} {

		if {[playtech::code] == "PT_ERR_INVALID_USERNAME"} {
			set pt_poker_balance 0
		} else {
			return [list 2 {} $check -1]
		}
	} else {
		set pt_poker_balance [expr {[playtech::response players,available-funds-in-table] + [playtech::response players,available-funds-in-tourn]}]
	}

	set playtech_balance [expr {$playtech_balance + $pt_poker_balance}]

	# config for the max allowed total balance in GBP
	set max_allowed_balance $PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_balance $acct_id]
	} msg]} {

		ob::log::write ERROR {Failed to execute check_balance: $msg}

		set msg_txt "Failed to determine the customer's total balance."
		set success 2

		return [list $success $msg_txt $check -1]

	}

	if {[db_get_nrows $rs] != 1} {

		ob::log::write ERROR {cc_change::check_balance: \
		                      Balance check did not return one row.}

		set msg_txt "Failed to determine the customer's total balance."
		set success 2

	} else {

		set balance             [expr {[db_get_col $rs 0 balance] + $game_acct_balance + $playtech_balance}]
		set ccy_code            [db_get_col $rs 0 ccy_code]

		#The limit is already converted to the customer currency

		if {$balance > $max_allowed_balance} {
			ob::log::write INFO {cc_change::check_total_balance: \
					     Total balance is more than the max allowed total balance :$max_allowed_balance}
			set success 0
			set msg_txt "The customer's total account balance is: $balance $ccy_code.  Maximum total balance allowed is: $max_allowed_balance"
		}

		# ensure 2 decimal places
		set balance [format %.2f $balance]
	}

	ob::log::write DEBUG {cc_change::check_total_balance: \
	                      [list $success $msg_txt $check]}

	return [list $success $msg_txt $check $balance]
}



# Check whether the customer has unsettled bets including
# pools bets, lotteries and sports bets
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_UNSETTLEDBETS
#            value
#               number of unsettled bets
#
proc cc_change::check_unsettled_bets {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_unsettled_bets: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_UNSETTLEDBETS"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_unsettled_bets \
						$acct_id $acct_id $acct_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_unsettled_bets: $msg}

		set msg_txt "Failed to determine if the customer has unsettled bets."
		set success 2

		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	# check fails if customer has unsettled bets
	if {$nrows != 0} {
		ob::log::write INFO {cc_change::check_unsettled_bets: \
		                     Customer has unsettled bets.}
		set msg_txt "Customer has unsettled bets."
		set success 0
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_unsettled_bets: \
	                     [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $nrows]

}



# Check whether the customer open multi state games
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_GAMESMULTISTATE
#            value
#               number of games
#
proc cc_change::check_multi_state_games {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_multi_state_games: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_GAMESMULTISTATE"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_multi_state_games $acct_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_multi_state_games: $msg}

		set success 2
		set msg_txt "Failed to determine if the customer has open multi-state games."

		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	# check fails if the query returns any row
	if {$nrows != 0} {
		set success 0
		set msg_txt "Customer has open multi-state games."
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_multi_state_games:  \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $nrows]

}



# Check whether the customer has payments in status 'U' within
# time period specified by config item CC_CHANGE_UPMT_WAIT
# Check whether the customer has payments in status 'P','L','I' within
# time period specified by config item CC_CHANGE_PPMT_WAIT
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_PENDINGPMTS
#            value
#               number of pend pmts
#
proc cc_change::check_pending_payments {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_pending_payments: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_PENDINGPMTS"

	set unknown_period [clock scan "today - [OT_CfgGet CC_CHANGE_UPMT_WAIT 3] day"]
	set pending_period [clock scan "today - [OT_CfgGet CC_CHANGE_PPMT_WAIT 7] day"]

	set start1    "[clock format $unknown_period -format %Y-%m-%d] 00:00:00"
	set start2    "[clock format $pending_period -format %Y-%m-%d] 00:00:00"

	ob::log::write DEBUG {cc_change::check_pending_payments: \
	                      start1: $start1, start2: $start2}

	if {[catch {

		set rs  [tb_db::tb_exec_qry cc_change::last_transactions_by_status \
		                                                          $acct_id \
		                                                          $start1  \
		                                                          "U"      \
		                                                          ""       \
		                                                          ""       \
		                                                          ""]

		set rs2 [tb_db::tb_exec_qry cc_change::last_transactions_by_status \
		                                                          $acct_id \
		                                                          $start2  \
		                                                          "L"      \
		                                                          "I"      \
		                                                          "P"      \
		                                                          "R"]
	} msg]} {

		ob::log::write ERROR {Failed to execute last_transactions_by_status: $msg}

		set success 2
		set msg_txt "Failed to determine if the customer has pending payments."

		catch {db_close $rs}
		catch {db_close $rs2}

		return [list $success $msg_txt $check -1]

	}


	# QC 3497 : Search for payments with U status is optional, make sure the search here
	#           matches the search query for customer history screens
	set nrows 0
	if {[OT_CfgGet CC_CHANGE_USE_UPMT 0] == 1} {
		set nrows  [db_get_nrows $rs]
	}

	set nrows2 [db_get_nrows $rs2]
	if {$nrows != 0 || $nrows2 != 0} {
		ob::log::write INFO {cc_change::check_pending_payments: \
		                     Customer has pending payments}
		set success 0
		set msg_txt "Customer has pending payments."
	}

	db_close $rs
	db_close $rs2

	ob::log::write DEBUG {cc_change::check_pending_payments: \
	                     [list $success $msg_txt $check]}
	return [list $success $msg_txt $check [expr {$nrows+$nrows2}]]

}



# Check whether the customer has open bossmedia sessions
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_BOSSMEDIA
#            value
#               number of sessions
#
proc cc_change::check_bossmedia {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_bossmedia: cust_id $cust_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_BOSSMEDIA"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_bossmedia $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_bossmedia: $msg}

		set success 2
		set msg_txt "Failed to determine if the customer has an open BossMedia Casino session."

		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	# check fails if the query returns any row
	if {$nrows != 0} {
		set success 0
		set msg_txt "Customer has an open BossMedia Casino session."
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_bossmedia:  \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $nrows]

}



# Check whether the customer has incomplete SNG subscriptions
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_SNGSUB
#            value
#               number of subs
#
proc cc_change::check_sngsub {cust_id acct_id args} {

	ob::log::write DEBUG {cc_change::check_sngsub: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check   "CC_CHANGE_SNGSUB"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_sngsub $acct_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_sngsub: $msg}

		set success 2
		set msg_txt "Failed to determine if the customer has any incomplete SNG Balls subscriptions."

		return [list $success $msg_txt $check -1]
	}

	set nrows [db_get_nrows $rs]
	# check fails if the query returns any row
	if {$nrows != 0} {
		set success 0
		set msg_txt "Customer has open SNG Balls subscriptions."
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_bossmedia:  \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $nrows]

}



# Check the customer has fewer than 3 card changes in the last 30 days
# (maximum 3 card changes in 30 day period)
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_CARD_CHANGES
#            value
#               number of card changes
#
proc cc_change::check_card_changes {cust_id acct_id args} {
	ob::log::write DEBUG {cc_change::check_card_changes: acct_id $acct_id}

	variable PMT_CHANGE_CHK

	set success 1
	set msg_txt ""
	set check "CC_CHANGE_CARD_CHANGES"
	set num_changes -1

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_recent_changes $cust_id $PMT_CHANGE_CHK(CARD_CHANGE_PERIOD)]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_recent_changes: $msg}
		set success 2
		set msg_txt "Failed to check number of customers recent card changes"

		return [list $success $msg_txt $check -1]
	}

	if {[db_get_nrows $rs] != 1} {

		ob::log::write ERROR {cc_change::check_card_changes: \
		    Check number of recent card changes did not return one row.}

		set msg_txt "Failed to determine number of recent card changes."
		set success 2
	} else {
		set num_changes [db_get_col $rs 0 changes]
		set allowedChanges [expr $PMT_CHANGE_CHK(CC_MAX_CARD_CHANGES) -1]

		if {$num_changes > $allowedChanges} {
			ob::log::write INFO {cc_change::check_card_changes: \
			                     More than $allowedChanges card changes in last $PMT_CHANGE_CHK(CARD_CHANGE_PERIOD) days}
			set success 0
			set msg_txt "The customer has changed cards : $num_changes times in the last $PMT_CHANGE_CHK(CARD_CHANGE_PERIOD) days"
		}
	}

	db_close $rs

	ob::log::write DEBUG {cc_change::check_card_changes: \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check $num_changes]
}



# Check open subscriptions
#
#  cust_id - customer id
#  acct_id - account id
#
#  uses config item EXTERNAL_SYS_SUBS_NOT_ALLOWED for list of systems
#  which cannot have active subscriptions
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_CHECK_OPEN_SUBS
#            value
#               list {name_A count_A name_B count_B ...}
#
proc cc_change::check_open_subs {cust_id acct_id args} {
	ob::log::write DEBUG {cc_change::check_open_subs: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check "CC_CHANGE_CHECK_OPEN_SUBS"
	set nsubs   0

	set NOT_ALLOWED_SYSTEMS [OT_CfgGet EXTERNAL_SYS_SUBS_NOT_ALLOWED [list]]

	if {[llength $NOT_ALLOWED_SYSTEMS] == 0} {
		set msgtxt "No external systems require checking"
		ob::log::write DEBUG {cc_change::check_acct_open: \
	                      [list $success $msg_txt $check]}
		return [list $success $msg_txt $check 0]
	} else {
		if {[catch {
			set rs [tb_db::tb_exec_qry cc_change::check_open_subs $acct_id]
		} msg]} {
				ob::log::write ERROR {Failed to execute check_open_subs: $msg}
				set success 2
				set msg_txt "Failed to check customers subs status."
				return [list $success $msg_txt $check -1]
		}

		set systems      [list]
		set systems_list [list]

		set nrows [db_get_nrows $rs]
		if {$nrows > 0} {
			ob::log::write INFO \
				{cc_change::check_open_subs: Customer has active subscriptions }

			for {set i 0} {$i < $nrows} {incr i} {
				foreach system $NOT_ALLOWED_SYSTEMS {
					set systemName [db_get_col $rs $i name]
					set count      [db_get_col $rs $i count]
					if {$system == $systemName} {
						lappend systems $systemName
						lappend systems_list $system $count
					}
				}
			}

			if {[llength $systems] > 0} {
				set success 0
				set msg_txt  "Customer has active subscriptions to [join $systems ,]"
			}
		}

		db_close $rs

		ob::log::write DEBUG {cc_change::check_acct_open: $success $msg_txt $check}
		return [list $success $msg_txt $check $systems_list]
	}

}



# Check the customer account status is Active (A)
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHANGE_ACCT_OPEN
#            value
#               -
#
proc cc_change::check_acct_open {cust_id acct_id args} {
	ob::log::write DEBUG {cc_change::check_acct_open: acct_id $acct_id}

	set success 1
	set msg_txt ""
	set check "CC_CHANGE_ACCT_OPEN"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::check_acct_open $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to execute check_acct_open: $msg}
		set success 2
		set msg_txt "Failed to check customers status."
		return [list $success $msg_txt $check -]
	}

	if {[db_get_nrows $rs] != 1} {

		ob::log::write ERROR {cc_change::check_acct_open: \
		                      Status check did not return one row.}

		set msg_txt "Failed to determine the customer's status."
		set success 2

	} else {
		set status  [db_get_col $rs 0 status]

		# if the status is not A (active)
		if {$status != "A"} {
			ob::log::write INFO {cc_change::check_acct_open: \
			                     Account status is not open}
			set success 0

			switch $status {
				"C" {
					set status "Closed"
				}
				"S" {
					set status "Suspended"
				}
			}

			set msg_txt "The customer's status is: $status"
		}
	}

	db_close $rs
	ob::log::write DEBUG {cc_change::check_acct_open: \
	                      [list $success $msg_txt $check]}
	return [list $success $msg_txt $check -]
}



# Removes a customer payment method (CPM)
#
#  cust_id - customer id
#  cpm_id  - customer payment method id
#
#  This should not be called to remove a payment method without a cc_change_check
#  having been passed first
#
#  returns 1 for successfully removed
#
proc cc_change::remove_cpm {cpm_id cust_id} {
	ob::log::write INFO {cc_change::remove_cpm: cpm_id: $cpm_id cust_id: $cust_id}

	set success 0

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::get_pending_payments $cpm_id]
	} msg]} {
			ob::log::write ERROR {Failed to execute get_pending_payments: $msg}
			return 0
	}


	set nrows [db_get_nrows $rs]

	# If there are pending payments cancel them
	if {$nrows != 0} {
		for {set i 0} {$i < $nrows} {incr i} {
			set pmt_id [db_get_col $rs $i pmt_id]

			if {[catch {
					tb_db::tb_exec_qry cc_change::cancel_pmt $pmt_id
				} msg]} {
				ob::log::write ERROR {cc_change::cancel_pmt: Failed to execute query - $msg}
				db_close $rs
				return 0
			}
			ob::log::write INFO {cc_change::remove_cpm: cancelling pmt_id: $pmt_id}
		}
	}
	db_close $rs

	tb_db::tb_begin_tran
	# Remove cpm
	if {[catch {
			tb_db::tb_exec_qry cc_change::remove_cpm_cust $cpm_id $cust_id
		} msg]} {
			ob::log::write ERROR \
			{cc_change::remove_cpm: couldn't remove cpm: $msg}
			return 0
	}

	# If payments were cancelled check that none were updated
	if {$nrows} {
		if {[catch {
			set rs [tb_db::tb_exec_qry cc_change::check_removed_cpm_pmts $cpm_id]
		} msg]} {
			ob::log::write ERROR \
				{cc_change::remove_cpm: couldn't remove cpm: $msg}
			return 0
		}
		if {[db_get_nrows $rs]} {
			ob::log::write ERROR \
				{cc_change::remove_cpm: payments in a state other than cancelled $cpm_id $cust_id}
			db_close $rs
			tb_db::tb_rollback_tran
			return 0
		}
	}
	tb_db::tb_commit_tran

	if {[db_garc cc_change::remove_cpm_cust] != 1} {
		ob::log::write ERROR \
			{cc_change::remove_cpm: no rows removed:$cpm_id, $cust_id}
		db_close $rs
		return 0
	}

	db_close $rs

	set success 1
	return $success

}



#
# 0 Check failed (request sent through and card change should be denied)
# 1 Success. Authorised
# 2 Check could not be performed.
#
proc cc_change::check_playtech_wallet_funds {cust_id acct_id args} {

	variable CC_CUST
	variable PLAYTECHCASINO_WALLET_LIMIT
	variable PLAYTECHPOKER_WALLET_LIMIT


	variable PMT_CHANGE_CHK

	set system [lindex $args 0]

	set check "CC_CHECK_[string toupper $system]_FUNDS"

	if {[_smart_reset CC_CUST]} {
		_get_cust_details $cust_id
	}

	if {$CC_CUST(status) != "OK"} {
		return [list 2 {} $check {}]
	}

	foreach c {
		username
		password
		password_salt
	} {
		set $c $CC_CUST($c)
	}

	# First perform a get player info request to get the balance

	playtech::get_balance $username $password $system
	set code [playtech::status]

	if {$code != "OK"} {
		return [list 2 {} $check {}]
	}

	set wallet  [playtech::response balance]

	set limit_name "[string toupper $system]_WALLET_LIMIT"
	set limit_value $PMT_CHANGE_CHK($limit_name)

	if {$limit_value == -1} {
		# There has been an error converting the limit to the customer ccy
		return [list 2 {} $check {}]
	}

	set success [expr {$wallet > $limit_value ? 0 : 1}]

	return [list $success {} $check $wallet]
}

#
# check bonus funds for a given customer.
#
# 0 Check failed (request sent through and card change should be denied)
# 1 Success. Authorised
# 2 Check could not be performed.
#
proc cc_change::check_playtech_bonus_funds {cust_id acct_id args} {

	variable CC_CUST
	variable PLAYTECHPOKER_BONUS_LIMIT
	variable PLAYTECHCASINO_BONUS_LIMIT

	variable PMT_CHANGE_CHK
	set system [lindex $args 0]
	set check "CC_CHECK_[string toupper $system]_BONUS"

	if {[_smart_reset CC_CUST]} {
		_get_cust_details $cust_id
	}

	if {$CC_CUST(status) != "OK"} {
		return [list 2 {} $check {}]
	}

	foreach c {
		username
		password
		password_salt
	} {
		set $c $CC_CUST($c)
	}

	# First perform a get player info request to get the bonus funds.

	playtech::get_playerinfo $username $password $system
	set code [playtech::status]

	if {$code != "OK"} {
		return [list 2 {} $check {}]
	}

	set bns_bal [playtech::response bonusbalance]

	set limit_name "[string toupper $system]_BONUS_LIMIT"
	set limit_value $PMT_CHANGE_CHK($limit_name)

	if {$limit_value == -1} {

		# There has been an error converting the limit to the customer ccy
		return [list 2 {} $check {}]
		
	}

	set success [expr {$bns_bal > $limit_value ? 0 : 1}]

	return [list $success {} $check $bns_bal]
}


#
# Check funds in games of Playtech poker.
#
# Awaiting details of the API
#
#  cust_id - customer id
#  acct_id - account id
#
#  returns - list of format
#            success flag (0|1|2)
#               0: check has failed
#               1: check succeeded
#               2: check could not be performed
#            msg
#               string giving information on check
#            check name
#               CC_CHECK_PLAYTECH_RING_TOURN_FUNDS
#            value
#               balance
#
proc cc_change::check_playtech_poker_funds {cust_id acct_id args} {

	variable CC_CUST
	variable PMT_CHANGE_CHK

	set check "CC_CHECK_PLAYTECH_RING_TOURN_FUNDS"
	set system [lindex $args 0]

	if {[_smart_reset CC_CUST]} {
		_get_cust_details $cust_id
	}

	if {$CC_CUST(status) != "OK"} {
		return [list 2 {} $check {}]
	}

	set max_allowed_balance $PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)

	if {$max_allowed_balance == -1} {
		# There has been an error converting the limit to the customer ccy
		return [list 2 {} $check {}]
	}

	playtech::get_playerfunds $system $CC_CUST(username)
	if {[playtech::status] != "OK"} {

		set code [playtech::code]

		if {$code == "PT_ERR_INVALID_USERNAME"} {
			# either player doesn't exist or they never logged in.
			# either way they can't have any funds in Poker. return success
			return [list 1 {} $check {0 0}]
		}

		return [list 2 {} $check { "" "" }]
	}

	set funds1 [playtech::response players,available-funds-in-table]
	set funds2 [playtech::response players,available-funds-in-tourn]

	set success 1
	if {$funds1 > $max_allowed_balance || $funds2 > $max_allowed_balance} {
		set success 0
	}

	return [list $success {} $check "$funds1 $funds2"]

}



#
proc cc_change::_smart_reset {array_name} {

	set reset 0

	variable $array_name
	set req_id [reqGetId]

	if {![info exists ${array_name}(req_id)]} {
		set reset 1
	} elseif {[set ${array_name}(req_id)] != $req_id} {
		set reset 1
	} else {
		set reset 0
	}

	if {$reset} {
		ob::log::write INFO "Resetting $array_name array"
		array unset ${array_name}
		set ${array_name}(req_id) $req_id
		set ${array_name}(num) 0
	}

	return $reset
}


proc cc_change::_get_cust_details {cust_id} {

	variable CC_CUST

	set CC_CUST(req_id) [reqGetId]
	set CC_CUST(status) "BLANK"

	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::get_username $cust_id]
	} msg]} {
		ob::log::write ERROR {Failed to retrieve username: $msg}
		return
	}

	if {[db_get_nrows $rs] != 1} {
		return
	}

	foreach c [db_get_colnames $rs] {
		set CC_CUST($c) [db_get_col $rs 0 $c]
	}

	set CC_CUST(status) "OK"
}

# Get the limits from the database.
# if change_if_errors=1 it will return -1 per each limit in case of error
proc cc_change::_get_limits_cust_ccy {cust_id {change_if_error 1}} {

	variable PMT_CHANGE_CHK


	set PMT_CHANGE_CHK(ccy_code) "GBP"

	if {[catch {

		set rs_currency [tb_db::tb_exec_qry cc_change::check_currency $cust_id]

	} msg]} {

		ob::log::write ERROR {Failed to retrieve exchange_rate for the limits: $msg}
		db_close $rs_currency

		if {$change_if_error} {

			set PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)         -1
			set PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT)  -1
			set PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)   -1
			set PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)    -1
			set PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)   -1
			set PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)            -1
			set PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)           -1
			set PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)         -1
			# PMT_CHANGE_CHK(MAX_PMB_REMOVE) will be without ccy conversion 

		}
		
		return 0
	} else {
	

		if {[db_get_nrows $rs_currency] == 1} {

			set ccy_code [db_get_col $rs_currency 0 ccy_code]

			set PMT_CHANGE_CHK(ccy_code) $ccy_code

			if {$ccy_code == "GBP"} {
				# Nothing to convert
				return 1
			}

			set exch_rate [db_get_col $rs_currency 0 exch_rate]

			set PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)         [expr $exch_rate * $PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)]
			set PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT)  [expr $exch_rate * $PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT)]
			set PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)   [expr $exch_rate * $PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)]
			set PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)    [expr $exch_rate * $PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)]
			set PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)   [expr $exch_rate * $PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)]
			set PMT_CHANGE_CHK(MAX_PMB_REMOVE)               [expr $exch_rate * $PMT_CHANGE_CHK(MAX_PMB_REMOVE)]
			set PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)            [expr $exch_rate * $PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)]
			set PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)           [expr $exch_rate * $PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)]
			set PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)         [expr $exch_rate * $PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)]
	
			db_close $rs_currency
			return 1

		} else {

			if {$change_if_error} {
	
				set PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)         -1
				set PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT)  -1
				set PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)   -1
				set PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)    -1
				set PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)   -1
				set PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)            -1
				set PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)           -1
				set PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)         -1
				# will be without ccy conversion set PMT_CHANGE_CHK(MAX_PMB_REMOVE)
			}
	

			db_close $rs_currency
			return 0

		}

	}
}

proc cc_change::_get_cc_change_config {cust_id {change_if_error 1}} {

	variable PMT_CHANGE_CHK


	catch {array unset PMT_CHANGE_CHK}

	# Define the PMT_CHANGE_CHK
	# If the query fails try to use default value
	set PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT)   20
	set PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)    20
	set PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)     0
	set PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)    0
	set PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)          0

	# Get the payment method change config settings
	if {[catch {
		set rs [tb_db::tb_exec_qry cc_change::get_cc_change_config]
	} msg]} {

		ob_log::write ERROR {cc_change::_get_cc_change_config: $msg}

		ob_log::write INFO { Playtech limits will use a default value instead}
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 0} {

		ob_log::write ERROR { \
		No rows returned. Playtech limits will use a default value instead}

	} else {

		set PMT_CHANGE_CHK(CC_MAX_SB_BALANCE)           [db_get_col $rs 0 max_sb_balance]
		set PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE)          [db_get_col $rs 0 max_ext_balance]
		set PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE)        [db_get_col $rs 0 max_total_balance]

		set PMT_CHANGE_CHK(CC_MAX_CARD_CHANGES)         [db_get_col $rs 0 max_card_changes]
		set PMT_CHANGE_CHK(CARD_CHANGE_PERIOD)          [db_get_col $rs 0 card_change_period]
		set PMT_CHANGE_CHK(MAX_PMB_REMOVE)              [db_get_col $rs 0 max_pmb_remove]

		set PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT)   [db_get_col $rs 0 max_poker_bonus]
		set PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)  [db_get_col $rs 0 max_casino_bonus]

		set PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT) [db_get_col $rs 0 max_casino_wallet]
		set PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT)  [db_get_col $rs 0 max_poker_wallet]
		set PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY)        [db_get_col $rs 0 max_poker_in_play]
	

	}

	cc_change::_get_limits_cust_ccy $cust_id $change_if_error
	catch {db_close $rs}

}

proc cc_change::get_cc_change_config {cust_id} {

	variable PMT_CHANGE_CHK

	_get_cc_change_config $cust_id 0

	# Limits will be printed in the customer currency unless there is an error


	return [list \
		ccy_code \
		$PMT_CHANGE_CHK(ccy_code) \
		CC_MAX_SB_BALANCE \
		$PMT_CHANGE_CHK(CC_MAX_SB_BALANCE) \
		CC_MAX_EXT_BALANCE \
		$PMT_CHANGE_CHK(CC_MAX_EXT_BALANCE) \
		CC_MAX_TOTAL_BALANCE \
		$PMT_CHANGE_CHK(CC_MAX_TOTAL_BALANCE) \
		CC_MAX_CARD_CHANGES \
		$PMT_CHANGE_CHK(CC_MAX_CARD_CHANGES) \
		CARD_CHANGE_PERIOD \
		$PMT_CHANGE_CHK(CARD_CHANGE_PERIOD) \
		MAX_PMB_REMOVE \
		$PMT_CHANGE_CHK(MAX_PMB_REMOVE) \
		CC_MAX_POKER_IN_PLAY \
		$PMT_CHANGE_CHK(CC_MAX_POKER_IN_PLAY) \
		PLAYTECHCASINO_WALLET_LIMIT \
		$PMT_CHANGE_CHK(PLAYTECHCASINO_WALLET_LIMIT) \
		PLAYTECHPOKER_WALLET_LIMIT \
		$PMT_CHANGE_CHK(PLAYTECHPOKER_WALLET_LIMIT) \
		PLAYTECHPOKER_BONUS_LIMIT \
		$PMT_CHANGE_CHK(PLAYTECHPOKER_BONUS_LIMIT) \
		PLAYTECHCASINO_BONUS_LIMIT \
		$PMT_CHANGE_CHK(PLAYTECHCASINO_BONUS_LIMIT)]

}
# Call initialisation
cc_change::init
