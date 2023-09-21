# ====================================================================
# $Id: fraud_check.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ====================================================================

#
# WARNING: file will be initialised at the end of the source
#

namespace eval fraud_check {

namespace export init
namespace export screen_customer
namespace export ipaddr_monitoring
namespace export tumbling_and_swapping
namespace export cntry_ccy_ip_check
namespace export checkFraudScreenEnabled
namespace export send_ticker

#
# store the necessary queries
#
proc init {} {

	global SHARED_SQL

	set SHARED_SQL(get_fraud_screen_enabled) {
		select
			fraud_screen
		from
			tChannel
		where
			channel_id = ?
	}

	set SHARED_SQL(get_IP_cardreg_last_hour) {
		select
			ipaddr,
			cr_date
		from
			tCardReg
		where
			cr_date > CURRENT - 1 units hour and
			ipaddr = ?
		order by
			cr_date
		desc
	}

	set SHARED_SQL(get_PAN_cardreg_last_hour) [subst {
		select
			card_reg_id,
			enc_card_no,
			ivec,
			data_key_id,
			cr_date,
			enc_with_bin
		from
			tCardReg
		where
			cr_date > CURRENT - [OT_CfgGet PAN_CARDREG_QRY_RANGE 3600] units second and
			card_bin = ?
		order by
			cr_date
		desc
	}]

	set SHARED_SQL(get_reg_details) {
		select
			r.ipaddr,
			c.country_code,
			a.ccy_code
		from
			tcustomer c,
			tcustomerreg r,
			tacct a
		where
			c.cust_id = r.cust_id and
			r.cust_id = a.cust_id and
			c.cust_id = ?
	}

	# update customer status
	set SHARED_SQL(upd_cust_status) {
		EXECUTE PROCEDURE pUpdCustStatus (
			p_cust_id = ?,
			p_status = ?,
			p_status_reason = ?
		)
	}

	set SHARED_SQL(set_oper_notes) {
		update
			tCustomerReg
		set
			oper_notes = ?
		where
			cust_id = ?
	}

	set SHARED_SQL(set_fraud_status_flag) {
		EXECUTE PROCEDURE pUpdCustFlag (
			p_cust_id = ?,
			p_flag_name = ?,
			p_flag_value = ?
		)
	}

	set SHARED_SQL(get_ticker_info) {
		select
			c.acct_no,
			c.cr_date as cust_reg_date,
			c.country_code,
			c.notifyable,
			a.ccy_code,
			NVL((select bank from tcardinfo where card_bin=?), "N/A") as bank,
			(select count(*) from tcardreg where cust_id=? and DAY(cr_date)=DAY(current)) as nocards,
			r.addr_postcode,
			c.username,
			r.fname,
			r.lname,
			r.code as cust_segment,
			r.email,
			cc.exch_rate,
			c.liab_group
		from
			tcustomer c,
			tacct a,
			tcustomerreg r,
			tccy cc
		where
			c.cust_id = ? and
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			a.ccy_code = cc.ccy_code
	}

	set SHARED_SQL(get_ticker_info_bank) {
		select
			c.acct_no,
			c.cr_date as cust_reg_date,
			c.country_code,
			c.username,
			c.notifyable,
			a.ccy_code,
			r.addr_postcode,
			r.fname,
			r.lname,
			r.code as cust_segment,
			r.email,
			cc.exch_rate,
			c.liab_group
		from
			tcustomer c,
			tacct a,
			tcustomerreg r,
			tccy cc
		where
			c.cust_id = ? and
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			a.ccy_code = cc.ccy_code
	}

	set SHARED_SQL(get_acct_id) {
		select
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}
}

################################################################################
# Procedure :   screen_customer
# Description : perform checks on the customer's card registration attempt:
# 				- tumbling and swapping (10 channels)
# 				- IP address monitoring (internet only)
# 				- compare address country, currency country
# 				  and ip country with card country (internet only)
#				- number of payment methods registered within a
#				  configurable period since registering
#
#               NB Doesn't send fraud ticker, since we may be inside a txn at
#                  this point which could get rolled back.
#
# Input :       cust_id - customer to be screened
#				channel - channel on which the customer is trying to
#						  register a card
# Output :
# Author :      AJ, 16-10-2002
#
# Returns - 0 - if its not enabled
#           "" - if there isn't a card number
#           info list - if the transaction is committed
#
#
################################################################################
proc screen_customer {cust_id channel {type ""} {amount 0} {in_tran "N"}} {
	# check_status can be   'A' = 'Accept'
	#						'C' = 'Challenge'
	#						'D' = 'Decline'
	set check_status "A"
	# action_taken can be   'N' = 'None'
	#						'S' = 'Suspended'
	set action_taken "N"
	set reason       "-"
	set ip_country   ""
	set ip_city      ""
	set ip_routing   ""
	set country_cf   ""

	# check if fraud screening is 'On' or 'Monitor'

	set fraud_screen_enabled [checkFraudScreenEnabled $channel]

	ob::log::write DEV {fraud screen enabled: $fraud_screen_enabled}

	if { $fraud_screen_enabled != "Y" && $fraud_screen_enabled != "M" } {
		return [list 0]
	}

	set hldr_name [reqGetArg hldr_name]
	set card_no   [reqGetArg card_no]

	if {$card_no == ""} {
		return
	}

	# trim anything not 0-9, card reg code matches this
	regsub -all {[^0-9]} $card_no "" card_no

	set ipaddr "N/A"
	if {$channel == "I"} {
		set ipaddr [reqGetEnv "REMOTE_ADDR"]
	}

	# Store all card registration attempts
	card_util::store_reg_attempt $cust_id $card_no $channel $type $amount $ipaddr $in_tran

	if { [OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK] } {

		# country check can only be done for internet

		if {$channel == "I" && $check_status == "A"} {

			set check_status [fraud_check::cntry_ccy_ip_check $cust_id]

			ob::log::write INFO \
				{country check status for cust_id $cust_id: $check_status}

			if {$check_status != "A"} {
				set reason "User failed fraud check for country/currency/IP"
			}

			foreach {
				ip_country
				ip_city
				ip_routing
				country_cf
			} [do_country_check $cust_id] {}

		}

	}

	# check for tumbling and swapping for the following 10 channels:
	# WebTV, Easybet, Hutchinson, Internet, NTL, Sky Active,
	# Telebetting, Shop, Telewest, WAP Mobile.
	# Also check that the customer didn't register too many payment methods
	# recently.
	switch -- $channel {

		"D" -
		"F" -
		"H" -
		"I" -
		"N" -
		"O" -
		"P" -
		"S" -
		"T" -
		"W" {

			set check_status [fraud_check::tumbling_and_swapping $card_no]

			ob::log::write DEV {tumbling and swapping status\
				for cust_id $cust_id: $check_status}

			if {$check_status != "A"} {
				set reason "User failed fraud check for tumbling and swapping"
			}
		}
	}

	# IP address monitoring can only be done for internet

	if {$channel == "I" && $check_status == "A"} {

		set check_status [fraud_check::ipaddr_monitoring $ipaddr]

		ob::log::write INFO {ipaddr monitoring status for cust_id $cust_id:\
			$check_status}

		if {$check_status != "A"} {
			set reason "User failed fraud check for IP monitoring"
		}

	}

	# check results of fraud screening
	# if fraudulent and fraud screening is 'On', update customer status
	if {$check_status != "A" && $fraud_screen_enabled == "Y"} {

		set action_taken "S"

		#update customer status
		if {[catch {
			set res [tb_db::tb_exec_qry \
				upd_cust_status $cust_id $action_taken $reason]
		} msg]} {
			ob::log::write ERROR \
				{failed to update status for customer $cust_id: $msg}
			error $msg
		}

		#set message for admin screens
		if {[catch {
			set res [tb_db::tb_exec_qry \
				set_oper_notes [ml_printf FRAUD_REFER] $cust_id]
		} msg]} {
			ob::log::write ERROR \
				{failed to set message for customer $cust_id: $msg}
			error $msg
		}

		db_close $res

	}

	# Store new fraud status in tCustomerFlag
	if {[catch {
		set res [tb_db::tb_exec_qry \
			set_fraud_status_flag $cust_id "fraud_status" $check_status]
	} msg]} {
		ob::log::write ERROR {failed to set fraud status flag: $msg}
	}
	db_close $res

	# Return info which can be used by ticker once this transaction is committed
	return [list $cust_id \
				 $check_status \
				 $ipaddr \
				 $channel \
				 $card_no \
				 $reason \
				 $amount \
				 $ip_city \
				 $ip_country \
				 $ip_routing \
				 $country_cf \
				 $hldr_name]

}

proc do_country_check {cust_id} {

	if {[OT_CfgGetTrue FUNC_GEOPOINT_IP_CHECK]} {

		OB::country_check::cookie_check $cust_id

		set results [list \
			$OB::country_check::IP_CHECK_RESULTS(ip_country) \
			$OB::country_check::IP_CHECK_RESULTS(ip_city)    \
			$OB::country_check::IP_CHECK_RESULTS(ip_routing) \
			$OB::country_check::IP_CHECK_RESULTS(country_cf)]

		ob::log::write DEV \
			{do_country_check $cust_id returning [join $results {, }]}

		return $results

	} else {

		ob::log::write DEV {do_country_check $cust_id disabled.}

	}

}

proc screen_customer_bank {cust_id channel amount} {

	set check_status "A"
	set reason       "-"
	set ip_country   ""
	set ip_city      ""
	set ip_routing   ""
	set country_cf   ""

	# check if fraud screening is 'On' or 'Monitor'
	set enabled [checkFraudScreenEnabled $channel]
	ob::log::write DEV {fraud screen enabled: $enabled}
	if {[lsearch {Y M} $enabled] > -1} {
		set ipaddr "N/A"
		if {$channel == "I"} {
			set ipaddr [reqGetEnv "REMOTE_ADDR"]

			foreach {
				ip_country
				ip_city
				ip_routing
				country_cf
			} [do_country_check $cust_id] {}
		}

		lappend rtn $cust_id $check_status $ipaddr $channel "" $reason $amount
		lappend rtn $ip_city $ip_country $ip_routing $country_cf ""

		return $rtn
	}
}


################################################################################
# Procedure :   checkFraudScreenEnabled
# Description :
# Input :
# Output :
# Author :      AJ, 17-10-2002
################################################################################
proc checkFraudScreenEnabled {channel} {

	if {[catch {set res [tb_db::tb_exec_qry get_fraud_screen_enabled $channel]} msg]} {
		ob::log::write ERROR {failed to get fraud setting: $msg}
		return N
	}
	if {[db_get_nrows $res] == 0} {
		ob::log::write INFO {no rows returned when executing get_fraud_screen_enabled}
		set result N
	} else {
		set result [db_get_col $res 0 fraud_screen]
	}
	db_close $res
	return $result
}

################################################################################
# Procedure :   ipaddr_monitoring
# Description : 3 card registration attempts from the same ip address within
#				an hour results in a 'challenged' fraud status for this customer
# Input :       cust_id - customer to be screened
# Output :      C - challenge, A - Accept
# Author :      AJ, 16-10-2002
################################################################################
proc ipaddr_monitoring {ipaddr} {

	#get IP address of credit card registration attempts in the last hour
	if {[catch {set res [tb_db::tb_exec_qry get_IP_cardreg_last_hour $ipaddr]} msg]} {
		ob::log::write ERROR {failed to get card registration attempts: $msg}
		return "A"
	}
	set attempts [db_get_nrows $res]

	ob::log::write DEV {ipaddr monitoring: rows returned: $attempts}

	#if more than 3 attempts, compare IP address
	set n 0
	if {$attempts >= 3} {

		for {set i 0} {$i < $attempts} {incr i} {

			set next_ipaddr [db_get_col $res $i ipaddr]
			if {$next_ipaddr == $ipaddr} {
				incr n
			}
		}
	}
	db_close $res

	ob::log::write INFO {ipaddr monitoring: num attempts from the same IP: $n}

	#if there were three attempts in the last hour from the same IP address,
	#set customer fraud status to 'C' for Challenge
	if {$n >= 3} {
		return "C"
	}

	#else, set customer fraud status to 'A' for Accept
	return "A"
}

################################################################################
# Procedure :   tumbling_and_swapping
# Description : 3 card registration attempts with similar card numbers within
#				an hour results in a 'challenged' fraud status for this customer
# Input :       cust_id - customer to be screened
# Output :
# Author :      AJ, 16-10-2002
################################################################################
proc tumbling_and_swapping {card_no} {
	# Check if the functionality is not disabled - defaults to enabled
	if { ![OT_CfgGet DISABLE_PAN_CARDREG_CHECK 0] } {
		# Take first 6 digits from card number to do database lookup
		set card_bin [string range $card_no 0 5]

		#get PAN number of credit card registration attempts in the last hour
		if {[catch {set res [tb_db::tb_exec_qry get_PAN_cardreg_last_hour $card_bin]} msg]} {
			ob::log::write ERROR {failed to get card registration attempts: $msg}
			return "A"
		}
		set attempts [db_get_nrows $res]

		#if more than 3 attempts, compare PAN number (credit card number)
		set n 1
		if {$attempts >= 3} {

			# Trim last 4 digits from card number to check for tumbling and swapping
			set index [expr {[string length $card_no] - 5}]
			set bin   [string range $card_no 0 $index]

			# First pass through these results - add the enc_card_no,ivec and data_id to a list
			# of values to go into a batch to the cryptoServer, and add card_reg_id. bin and
			# enc_with_bin to a list of elements required for post-decryption formatting
			set decrypt_data [list]
			set format_data  [list]

			for {set i 0} {$i < $attempts} {incr i} {
				set next_card_reg_id [db_get_col $res $i card_reg_id]
				set next_enc_card_no [db_get_col $res $i enc_card_no]
				set next_card_ivec   [db_get_col $res $i ivec]
				set next_data_key_id [db_get_col $res $i data_key_id]
				set enc_with_bin     [db_get_col $res $i enc_with_bin]

				lappend decrypt_data [list $next_enc_card_no $next_card_ivec $next_data_key_id]
				lappend format_data  [list $next_card_reg_id $enc_with_bin]
			}

			db_close $res

			set batch_rs [card_util::card_decrypt_batch $decrypt_data]

			if {[lindex $batch_rs 0] == 0} {
				# Check on the reason decryption failed, if we encountered corrupt data we should also
				# record this fact in the db
				if {[lindex $batch_rs 1] == "CORRUPT_DATA"} {
					set corrupt_rsn [lindex $batch_rs 2]
					foreach format_elem $format_data {
						update_data_enc_status "tCardReg" [lindex $format_elem 0] $corrupt_rsn
					}
				}
				return DECRYPT_ERR
			} else {
				set dec_data [lindex $batch_rs 1]
			}

			# We now have all the necessary data decrypted, so we can process it
			for {set i 0} {$i < $attempts} {incr i} {
				set enc_with_bin [lindex [lindex $format_data $i] 1]
				set next_card_no [card_util::format_card_no [lindex $dec_data $i] $card_bin $enc_with_bin]

				if {$next_card_no != $card_no} {
					# Trim last 4 digits from card number
					set index [expr {[string length $next_card_no] - 5}]
					set next_bin [string range $next_card_no 0 $index]
					if {$next_bin == $bin} {
						incr n
					}
				}
			}
		} else {
			db_close $res
		}

		#if there were three attempts in the last hour where the
		#PAN number entered was the same save the last four digits,
		#set customer fraud status to 'C' for Challenge
		if {$n >= 3} {
			return "C"
		}
	
	}
	#else, set customer fraud status to 'A' for Accept
	return "A"
}




################################################################################
# Procedure :   cntry_ccy_ip_check
# Description : A given amount of mismatches between ip country, currency country,
#				address country and card country leads to the customer getting a
#				fraud status of 'Challenged' or 'Declined'.
# Input :       cust_id - customer to be screened
#               ip_addr_details - array to be filled in with any ip address details
#               retrieved
# Output :      C(challenge), D(deny) or A(accept)
# Author :      A.Jansen / S.Luke
################################################################################
proc cntry_ccy_ip_check {cust_id} {

	global LOGIN_DETAILS

	if {[catch {set res [tb_db::tb_exec_qry get_reg_details $cust_id]} msg]} {
		ob::log::write ERROR {failed to get customer registration details: $msg}
		return "A"
	}
	set points [OB::country_check::fraud_check $cust_id \
												[db_get_col $res ipaddr] \
												[reqGetArg card_no] \
												[db_get_col $res country_code] \
												[db_get_col $res ccy_code]]
	db_close $res

	ob::log::write INFO {Country/Currency/IP address fraud check: number of mismatches $points}
	if {$points == [OT_CfgGet FRAUD_CHALLENGE_POINTS 10]} {
		#set customer fraud status to 'C' for Challenge
		return "C"
	}
	if {$points >= [OT_CfgGet FRAUD_DECLINE_POINTS 10]} {
		#set customer fraud status to 'D' for Decline
		return "D"
	}

	#else, set customer fraud status to 'A' for Accept
	return "A"
}

################################################################################
# Procedure :   send_ticker
# Description : send ticker with information about this fraud screening
# Input :       cust_id - customer which has been screened
# 				check_status - fraud status for this customer
# Output :
# Author :      A.Jansen
################################################################################
proc send_ticker {
	cust_id
	check_status
	ipaddr
	channel
	card_no
	reason
	amount
	ip_city
	ip_country
	ip_routing_method
	country_cf
	hldr_name
	args
} {

	if {!([OT_CfgGet MONITOR 0] || [OT_CfgGet MSG_SVC_ENABLE 1])} {
		return
	}

	set check_status [switch $check_status {
		A {format Accept}
		C {format Challenge}
		D {format Decline}
	}]

	if {$card_no != ""} {
		# get fraud screen information for ticker
		set card_bin [string range $card_no 0 5]
		if {[catch {
			set res [tb_db::tb_exec_qry get_ticker_info $card_bin $cust_id $cust_id]
		} msg]} {
			ob::log::write ERROR {failed to get ticker information: $msg}
			return
		}
		# Only show first six and last four digits of card number
		set index [expr {[string length $card_no] - 5}]
		set card_no [string replace $card_no 6 $index [string repeat "X" [expr {$index - 5}]]]

		set card_reg_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		# get values from db query
		set acct_no        [db_get_col $res acct_no]
		set cust_reg_date  [db_get_col $res cust_reg_date]
		set ccy_code       [db_get_col $res ccy_code]
		set bank           [db_get_col $res bank]
		set country_code   [db_get_col $res country_code]
		set nocards        [db_get_col $res nocards]
		set addr_postcode  [db_get_col $res addr_postcode]
		set notifiable     [db_get_col $res notifyable]

	} else {
		# Assume we are adding bank info...
		if {[catch {
			set res [tb_db::tb_exec_qry get_ticker_info_bank $cust_id $cust_id]
		} msg]} {
			ob::log::write ERROR {failed to get ticker information: $msg}
			return
		}

		foreach col {
			acct_no cust_reg_date ccy_code
			country_code addr_postcode
		} {
			set $col [db_get_col $res $col]
		}

		set notifiable     [db_get_col $res notifyable]

		foreach var {card_reg_date bank nocards card_no} {
			set $var "N/A"
		}
	}

	set liab_group [db_get_col $res liab_group]

	if {[OT_CfgGet MONITOR 0]} {
		# send to monitor

		# convert user amount into system ccy
		if {$amount != {}} {
			set exch_rate  [db_get_col $res exch_rate]
			set amount_sys [expr {$amount / $exch_rate}]
			set amount_sys [format "%.2f" $amount_sys]
		} else {
			set amount_sys {}
		}

		eval { MONITOR::send_fraud \
			$cust_id \
			[db_get_col $res username] \
			[db_get_col $res fname] \
			[db_get_col $res lname] \
			$acct_no \
			$cust_reg_date \
			[db_get_col $res cust_segment] \
			$notifiable \
			$card_reg_date \
			$ccy_code \
			$channel \
			$country_code \
			$check_status \
			$bank \
			$ipaddr \
			$nocards \
			$amount \
			$amount_sys \
			$reason \
			$card_no \
			$addr_postcode \
			[db_get_col $res email] \
			$ip_city \
			$ip_country \
			$ip_routing_method \
			$country_cf \
			$hldr_name \
			$liab_group \
		} $args
	}

	if {[OT_CfgGet MSG_SVC_ENABLE 0]} {
		# send to legacy ticker
		eval [concat MsgSvcNotify fraudscreen \
				AcctNo          "{$acct_no}" \
				FraudStatus     "{$check_status}"\
				CustRegDate     "{$cust_reg_date}" \
				CardRegDate     "{$card_reg_date}" \
				Ccy             "{$ccy_code}" \
				Bank            "{$bank}" \
				Cntry           "{$country_code}" \
				CardRegIPaddr   "{$ipaddr}" \
				NoCards         "{$nocards}" \
				RegChannel      "{$channel}" \
				Postcode        "{$addr_postcode}" \
				CardNumber      "{$card_no}" \
				Reason          "{$reason}" \
				Amount          "{$amount}"]
	}
}


#
# initialise this file
#
init

# close namespace
}
