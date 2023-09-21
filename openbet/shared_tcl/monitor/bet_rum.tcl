# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/bet_rum.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Bet RUM Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::bet_rum     sends a bet rum message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Bet RUM
#-------------------------------------------------------------------------------
#
# channel    - channel
# bet_id     - bet id: tBet.bet_id
# bet_type   - bet type: tBetType.bet_type
# bet_date   - date and time bet was placed
# amount_sys - bet stake amount in db currency
# num_slns   - number of selections
# leg_type   - whether tBet.leg_type
# num_legs   - number of legs of the bet
# num_lines  - number of lines in the bet
# rum_total  - the total RUM figure for this bet
# rum_liab_total
# cust_uname
# sln_names
# class_names

proc ::ob_monitor::bet_rum {
	channel
	bet_id
	bet_type
	bet_date
	amount_sys
	num_slns
	leg_type
	num_legs
	num_lines
	rum_total
        rum_liab_total
	cust_uname
	sln_names
	class_names
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: bet_rum}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

        set alert_date [MONITOR::datetime_now]


	set MESSAGE [list]

      	foreach n [list \
		channel \
		bet_id \
		bet_type \
		bet_date \
		amount_sys \
		num_slns \
		leg_type \
		num_legs \
		num_lines \
		rum_total \
		rum_liab_total \
		cust_uname \
		alert_date \
	] {
		lappend MESSAGE $n [set $n]
	}

	foreach n {
		sln_name
		class_name
	} {
		foreach v [set "${n}s"] {
			lappend MESSAGE $n $v
		}
	}
  


	set status [_send BRM]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
