# $Name:  $
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/betx.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
# 2008 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#
# Send Betx Monitor Message
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#   ::ob_monitor::betx     sends a betx message
#
#-------------------------------------------------------------------------------

package require monitor_monitor 4.5
ob_monitor::init

namespace eval ::ob_monitor {
}

#-------------------------------------------------------------------------------
# Betx
#-------------------------------------------------------------------------------
#
# cust_id            -
# cust_uname         -
# cust_fname         -
# cust_lname         -
# cust_reg_code      -
# cust_is_elite      -
# cust_is_notifiable -
# country_code       -
# channel            -
# betx_id            -
# betx_type          -
# betx_date          -
# amount_usr         -
# amount_sys         -
# ccy_code           -
# class_id           -
# class_name         -
# type_id            -
# type_name          -
# ev_id              -
# ev_name            -
# ev_date            -
# mkt_id             -
# mkt_name           -
# sln_id             -
# sln_name           -
# betx_polarity      -
# betx_hcap          -
# betx_price         -
# betx_stake_u       -
# betx_stake_m       -
# betx_payout_m      -
# betx_expire_type   -
# betx_expire_at     -
#
#-------------------------------------------------------------------------------
proc ::ob_monitor::betx {
	cust_id
	cust_uname
	cust_fname
	cust_lname
        cust_reg_code
	cust_is_elite
	cust_is_notifiable
	country_code
	channel
	betx_id
	betx_type
	betx_date
	amount_usr
	amount_sys
	ccy_code
	class_id
	class_name
	type_id
	type_name
	ev_id
	ev_name
	ev_date
	mkt_id
	mkt_name
	sln_id
	sln_name
	betx_polarity
	betx_hcap
	betx_price
	betx_stake_u
	betx_stake_m
	betx_payout_m
	betx_expire_type
	betx_expire_at
} {

	variable MESSAGE

	ob_log::write DEBUG {MONITOR: betx}

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

	set status [_send BETX]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
