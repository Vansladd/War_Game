# $Id: bet.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
# 2005 Orbis Technology Ltd. All rights reserved.
#
# Send Bet Monitor Message
#
# Configuration:
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#	::ob_monitor::bet       send a bet message
#	::ob_monitor::pkg_bet   send a bet message, getting the details from
#	                        cust_reg, cust_login and bet_bet packages
#


# Variables
#
namespace eval ::ob_monitor {
}



#--------------------------------------------------------------------------
# Bet
#--------------------------------------------------------------------------

# Send a bet message
#
#   cust_id             - customer identifier
#   cust_uname          - customer username
#   cust_fname          - customer firstname
#   cust_lname          - customer lastname
#   cust_reg_code       - customer reg' code
#   cust_is_elite       - elite customer
#   cust_is_notifiable  - customer notifiable
#   country_code        - country code
#   cust_reg_postcode   - customer's postcode
#   cust_reg_email      - customer email-address
#   channel             - source/channel
#   bet_id              - bet identifier
#   bet_type            - bet type
#   bet_date            - date bet was placed
#   amount_usr          - stake in customer's currency
#   amount_sys          - stake in system currency
#   pct_max_bet         - percentage of the stake per line / maximum bet
#   ccy_code            - customer's curreny code
#   stake_factor        - stake factor
#   num_slns            - number of selections within the bet
#   categorys           - selection categories (list)
#   class_ids           - selection class identifiers (list)
#   class_names         - selection class names (list)
#   type_ids            - selection type identifiers (list)
#   type_names          - selection type names (list)
#   ev_ids              - selection event identifiers (list)
#   ev_names            - selection event names (list)
#   ev_dates            - selection event dates (list)
#   mkt_ids             - selection market identifiers (list)
#   mkt_names           - selection market names (list)
#   sln_ids             - selection identifiers (list)
#   sln_names           - selection names (list)
#   prices              - selection prices (list)
#   leg_type            - leg type
#   liab_group          - liability group
#   returns             - monitor status, OB_OK denotes success
#   suspend_at          - event suspend_at time
#   est_start_time      - event estimated start time
#   in_running          - Market bet_in_run status (Y/N)
#   trader              - tEv.trader
#
proc ob_monitor::bet {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_code
	cust_is_elite
	cust_is_notifiable
	country_code
	cust_reg_postcode
	cust_reg_email
	channel
	bet_id
	bet_type
	bet_date
	amount_usr
	amount_sys
	ccy_code
	stake_factor
	num_slns
	categorys
	class_ids
	class_names
	type_ids
	type_names
	ev_ids
	ev_names
	ev_dates
	mkt_ids
	mkt_names
	sln_ids
	sln_names
	prices
	leg_type
	liab_group
	monitoreds
	{max_bet_allowed_per_line {}}
	{max_stake_percentage_used {}}
} {



       variable MESSAGE



	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	set MESSAGE [list]

		# create message
	set msg [list]
	foreach n {
		cust_id
		cust_uname
		cust_fname
		cust_lname
		cust_reg_code
		cust_is_elite
		cust_is_notifiable
		country_code
		cust_reg_postcode
		cust_reg_email
		channel
		bet_id
		bet_type
		bet_date
		amount_usr
		amount_sys
		ccy_code
		stake_factor
		num_slns
		leg_type
		liab_group
		max_bet_allowed_per_line
		max_stake_percentage_used
	} {
		lappend MESSAGE $n [set $n]
	}

	foreach n {
		category
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
		price
		monitored
	} {
		foreach v [set "${n}s"] {
			lappend MESSAGE $n $v
		}
	}

	set status [_send BET]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}



# Send bet message(s), getting the details from cust_reg, cust_login and bet_bet
# packages.
# Sends a bet message for each successfuly placed bet currently stored within
# the bet package.
#
#	returns - monitor status, OB_OK denotes success
#
proc ::ob_monitor::pkg_bet args {

	ob_log::write DEBUG {MONITOR: pkg_bet}

	if {![is_enabled]} {
		ob_log::write WARNING {MONITOR: disabled}
		return OB_OK
	}

	# get customer details from cust_login package
	foreach c [list \
		cust_id \
		ccy_code \
		username \
		elite \
		notifiable \
		cntry_code \
		acct_id \
	    max_stake_scale] {

		set MONITOR($c) [ob_login::get $c]
		set status [ob_login::get login_status]
		if {$status != "OB_OK"} {
			ob_log::write ERROR {MONITOR: $status}
			return $status
		}
	}

	# get registration date from cust_reg package
	set status [ob_reg::load $MONITOR(cust_id)]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
		return $status
	}

	# get the exchange rate
	if {[catch {set rs [ob_db::exec_qry ob_monitor::get_exch_rate\
	            $MONITOR(ccy_code)]} msg]} {
		ob_log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_EXCH_RATE
	}
	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		set status OB_ERR_MONITOR_NO_EXCH_RATE
		ob_log::write ERROR {MONITOR: $status $MONITOR(ccy_code)}
		return $status
	}
	set MONTIOR(exch_rate) [db_get_col $rs 0 exch_rate]
	ob_db::rs_close $rs

	# get the source/channel
	if {[catch {set MONTOR(source) [ob_bet::get_config source]} msg]} {
		set status OB_ERR_MONITOR_NO_SOURCE
		ob_log::write ERROR {MONITOR: $status $msg}
		return $status
	}
}
