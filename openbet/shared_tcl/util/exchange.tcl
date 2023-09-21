# $Id: exchange.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Currency Exchange
#
# Synopsis:
#     package require util_exchange [1.0]
#


package provide util_exchange 1.0

# Variables
#
namespace eval ob_exchange {

	variable CFG
	variable XRATE

}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time init
#
#   cache_time - how long to cache the exchange rates for (in seconds)
#
proc ob_exchange::init { {cache_time 0} } {

	variable CFG

	if {[info exists CFG(tiny)]} {
		return
	}
	ob_log::write DEBUG {ob_exchange::init}

	# add/subtract a tiny amount from ccy conversions before performing a
	# floor()/ceil() to get round any machine imprecision with fp calculations
	set CFG(tiny) "1e-9"

	# cache time
	set CFG(cache_time) $cache_time

	_prep_qrys

}



# Private procedure to prepare queries
#
proc ob_exchange::_prep_qrys {} {

	variable CFG

	# get a single exchange rate
	ob_db::store_qry ob_exchange::get {
		select
			ccy_code,
			exch_rate
		from
			tCCY
		where
			status   = 'A' and
			ccy_code = ?
	} $CFG(cache_time)
}


#--------------------------------------------------------------------------
# Exchange
#--------------------------------------------------------------------------

# Converts an amount from a customer's currency to the system currency
#
#    ccy_code     - customer's ccy code
#    amount       - amount to convert
#    force        - whether to force use of latest exchange rate
#    returns      - list; status sys_amount xrate
#
proc ob_exchange::to_sys_amount { ccy_code cust_amount {force 0} } {

	variable CFG

	set fn "ob_exchange::to_sys_amount"

	ob_log::write INFO {$fn ccy_code=$ccy_code cust_amount=$cust_amount}

	foreach {status xrate} [_get_rate $ccy_code $force] {}

	if {$status != "OK"} {
		return [list $status 0 0]
	}

	if {$cust_amount < 0} {
		set sys_amount\
		    [expr {ceil((100.0 * $cust_amount / $xrate) - $CFG(tiny)) / 100.0}]
	} else {
		set sys_amount\
		    [expr {floor((100.0 * $cust_amount / $xrate) + $CFG(tiny)) / 100.0}]
	}

	return [list OK [format %0.2f $sys_amount] $xrate]
}



# Converts an amount from the system currency to the customer's currency
#
#    ccy_code    - customer's ccy code
#    sys_amount  - amount to convert
#    force        - whether to force use of latest exchange rate
#    returns     - list; status cust_amount xrate
#
proc ob_exchange::to_cust_amount { ccy_code sys_amount {force 0} } {

	variable CFG

	set fn "ob_exchange::to_cust_amount"

	ob_log::write INFO {$fn ccy_code=$ccy_code sys_amount=$sys_amount}

	foreach {status xrate} [_get_rate $ccy_code $force] {}
	if {$status != "OK"} {
		return [list $status 0 0]
	}

	if {$sys_amount < 0} {
		set cust_amount\
		    [expr {ceil((100.0 * $sys_amount * $xrate) - $CFG(tiny)) / 100.0}]
	} else {
		set cust_amount\
		    [expr {floor((100.0 * $sys_amount * $xrate) + $CFG(tiny)) / 100.0}]
	}

	return [list OK [format %0.2f $cust_amount] $xrate]
}



# Private procedure to get the exchange rate for a currency
#
#    ccy_code - ccy code
#    force    - where to force a refresh to the latest rate
#    returns  - list; status xrate
#
proc ob_exchange::_get_rate {ccy_code force} {

	variable XRATE

	set status OK
	set xrate  0

	if {$force} {
		set qry_fn "ob_db::exec_qry_force"
	} else {
		set qry_fn "ob_db::exec_qry"
	}

	if {[catch {
		set rs [eval {$qry_fn ob_exchange::get $ccy_code}]
	} msg]} {

		ob_log::write ERROR {Failed to execute ob_exchange::get}
		set status OB_ERR_SYS_XRATE

	} else {

		if {[db_get_nrows $rs] != 1} {
			set status OB_ERR_NO_XRATE
		} else {
			set xrate [db_get_col $rs 0 exch_rate]
		}
		ob_db::rs_close $rs

	}

	return [list $status $xrate]
}
