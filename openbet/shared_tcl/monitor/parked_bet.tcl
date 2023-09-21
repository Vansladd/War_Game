# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/parked_bet.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Parked Bet Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::parked_bet     sends a parked_bet message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Parked Bet
#-------------------------------------------------------------------------------
#
# bet_receipt        - the bet receipt number                tbet.receipt
# cust_uname         - customer's username
# cust_acctno        - customers account number             tAcct.acct_no
# cust_is_notifiable - is customer notifiable           tCustomer.notifyable
# bet_date           - Date/time of when bet was place       tBet.cr_date
# bet_settled        - indicates if bet is settled           tBet.settled
# bet_type           - bet type                              tBet.bet_type
# leg_type           - leg type                              tBet.leg_type
# ccy_code           - currency                             tAcct.ccy_code
# bet_stake          - bet stake                             tBet.stake
# bet_winnings       - bet winnings                          tBet.winnings
# bet_refund         - amount refunded                       tBet.refund
# leg_sort           - leg number                           tOBet.leg_no
# leg_sort           - leg sort                             tOBet.leg_sort
# ev_name            - event name                             tEv.desc
# mkt_name           - market name                       tEvOcGrp.name
# sln_name           - selection name                       tEvOc.desc
# price              - the odds of the selection
# result             - the result of the bet                tEvOc.result
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::parked_bet {
	bet_receipt
	cust_uname
	cust_acctno
	cust_is_notifiable
	bet_date
	bet_settled
	bet_type
	leg_no
	leg_type
	ccy_code
	bet_stake
	bet_winnings
	bet_refund
	leg_sort
	ev_name
	mkt_name
	sln_name
	price
	result
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: parked_bet}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	set MESSAGE [list]

	# Get the name of the current procedure
	set current_proc [lindex [info level [info level]] 0]

	# For each arg passed to this procedure, append it to message
	foreach n [info args $current_proc] {
		lappend MESSAGE $n [set $n]
	}

	set status [_send PND]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
