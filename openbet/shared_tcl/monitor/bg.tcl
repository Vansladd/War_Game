# $Id: bg.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
# 2005 Orbis Technology Ltd. All rights reserved.
#
# Send Monitor Backgammon messages
#
# Configuration:
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#    ::ob_monitor::send_bg_transfer        send a transfer message
#    ::ob_monitor::send_bg_first_transfer  send a first transfer message
#    ::ob_monitor::send_bg_match           send a match message
#



# Variables
#
namespace eval ::ob_monitor {
}

#--------------------------------------------------------------------------
# Backgammon
#--------------------------------------------------------------------------

# Send a backgammon transfer message
#
#	cust_id             - cust id 
#	cust_uname          - cust username
#	cust_is_notifiable  - is notifiable
#	fraud_status        - cust fraud status
#	transfer_time       - the time of the transfer
#	ccy_code            - cust currency code
#	country_code        - cust country code
#	ip_country          - cust ip and country
#	transfer_type       - transfer type (in or out) 
#	amount_sys          - transfer amount (in system currency)
#	casino_code         - code to identify transfer as backgammon
#	alias               - cust backgammon alias
#	returns             - monitor status, OB_OK denotes success
#
proc ::ob_monitor::send_bg_transfer {
	cust_id 
	cust_uname
	cust_is_notifiable
	fraud_status
	transfer_time
	ccy_code
	country_code
	ip_country
	transfer_type
	amount_sys
	casino_code
	alias
} {
	variable MESSAGE

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

	set status [_send PKR]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}



# Send a backgammon first transfer message
#
#	cust_id             - cust id 
#	cust_uname          - cust username
#	cust_is_notifiable  - is notifiable
#	transfer_time       - the time of the transfer
#	ccy_code            - cust currency code
#	country_code        - cust country code
#	ip_country          - cust ip and country
#	transfer_type       - transfer type (in or out) 
#	amount_sys          - transfer amount (in system currency)
#       fraud_card          - cust card
#       fraud_bank          - cust bank
#	casino_code         - code to identify transfer as backgammon
#	alias               - cust backgammon alias
#	returns             - monitor status, OB_OK denotes success
#
proc ::ob_monitor::send_bg_first_transfer {
	cust_id 
	cust_uname
	cust_is_notifiable
	transfer_time
	ccy_code
	country_code
	ip_country
	transfer_type
	amount_sys
	fraud_card
	fraud_bank
	casino_code
	alias
} {
	variable MESSAGE

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

	set status [_send 1XFER]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}


# Send a backgammon match monitor message
#
#	cust_uname          - cust username
#	bg_rating           - cust username
#	bg_exp              - cust username
#	cust_uname_2        - cust username
#	bg_rating_2         - cust username
#	bg_exp_2            - cust username
#	returns             - monitor status, OB_OK denotes success
#
proc ::ob_monitor::send_bg_match {
	cust_uname
	bg_rating
	bg_exp
	cust_uname_2
	bg_rating_2
	bg_exp_2
} {
	variable MESSAGE

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

	# Add the rating difference
	lappend MESSAGE bg_rating_diff [expr {abs($bg_rating - $bg_rating_2)}]

	set status [_send BGM]
	if {$status != "OB_OK"} {
		ob_log::write ERROR {MONITOR: $status}
	}

	return $status
}
