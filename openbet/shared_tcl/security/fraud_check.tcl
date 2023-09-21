# $Id: fraud_check.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle payment fraud checking
#
# Configurations:
#   FRAUD_CHALLENGE_POINTS     Fraud challenge point                - (10)
#   FRAUD_DECLINE_POINTS       Fraud decline point                  - (10)
#   FRAUD_TUMBLE_SWAP_CHNLS    Channels to do tumbling and swapping -
#                                                                  (DFHINOPSTW)
#   FRAUD_FAIL_CUST_SUSPEND    Fraud check failure suspend customer - (1)
#   FRAUD_CARD_REG_IP_TRIES    Within the last hour, if the number
#                              of card reg attempts from the same IP
#                              exceeds this value, fail the check   - (3)
#   FRAUD_CARD_REG_TS_TRIES    Within the last hour, if the number
#                              of card reg attempts using similar
#                              card numbers exceeds this value,
#                              fail the check                       - (3)
#
# Synopsis:
#   package require security_fraudchk ?4.5?
#
# Procedures:
#   ob_fraudchk::init                  one time initialisation
#   ob_fraudchk::screen_customer       run checks on customer
#   ob_fraudchk::screen_customer_bank  run checks on customer for bank
#                                      transactions
#   ob_fraudchk::build_ticker_msg      build ticker message
#

package provide security_fraudchk 4.5


# Dependencies
#
package require util_log          4.5
package require util_db           4.5
package require util_crypt        4.5
package require security_cntrychk 4.5


# Variables
#
namespace eval ob_fraudchk {

	variable CFG
	variable INIT

	# init flag
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_fraudchk::init args {

	variable CFG
	variable INIT

	if {$INIT} {
	    return
	}

	# init dependencies
	ob_db::init
	ob_log::init
	ob_crypt::init
	ob_countrychk::init

	ob_log::write DEBUG {FRAUDCHK: init}

	# get configuration
	array set OPT [list \
	    challenge_points       10\
	    decline_points         10\
	    tumble_swap_chnls      DFHINOPSTW\
	    challenge_points       10\
	    decline_points         10\
	    fail_cust_suspend      1\
	    card_reg_ip_tries      3\
	    card_reg_ts_tries      3]

	foreach c [array names OPT] {
	    set CFG($c) [OT_CfgGet FRAUD_[string toupper $c] $OPT($c)]
	}

	# prepare queries
	_prepare_qrys

	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_fraudchk::_prepare_qrys args {

	# is fraud screen enabled
	ob_db::store_qry ob_fraudchk::is_enabled {
		select
		    fraud_screen
		from
		    tChannel
		where
		    channel_id = ?
	}

	# get IP registered card details in the last hour
	ob_db::store_qry ob_fraudchk::get_IP_cardreg_last_hour {
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

	# get registered card details in the last hour
	ob_db::store_qry ob_fraudchk::get_PAN_cardreg_last_hour {
		select
		    enc_card_no,
		    cr_date
		from
		    tCardReg
		where
		    cr_date > CURRENT - 1 units hour and
		    card_bin = ?
	    order by
		    cr_date
	        desc
	}

	# get registration details
	ob_db::store_qry ob_fraudchk::get_reg_details {
		select
		    r.ipaddr,
		    c.country_code,
		    a.ccy_code
		from
		    tCustomer c,
		    tCustomerReg r,
		    tAcct a
		where
		    c.cust_id = r.cust_id and
		    r.cust_id = a.cust_id and
		    c.cust_id = ?
	}

	# update customer status
	ob_db::store_qry ob_fraudchk::upd_cust_status {
		EXECUTE PROCEDURE pUpdCustStatus (
		    p_cust_id = ?,
		    p_status = ?,
		    p_status_reason = ?
		)
	}

	# set faud status flag
	ob_db::store_qry ob_fraudchk::set_fraud_status_flag {
		EXECUTE PROCEDURE pUpdCustFlag (
		    p_cust_id = ?,
		    p_flag_name = ?,
		    p_flag_value = ?
		)
	}

	# get ticker info
	ob_db::store_qry ob_fraudchk::get_ticker_info {
		select
		    c.acct_no,
		    c.cr_date as cust_reg_date,
		    c.country_code,
		    a.ccy_code,
		    NVL((select bank from tCardInfo where card_bin = ?), "N/A") as bank,
		    (select count(*) from tCardReg where cust_id = ?
		        and DAY(cr_date)=DAY(current)) as nocards,
		    r.addr_postcode,
		    c.username,
		    r.fname,
		    r.lname,
		    r.code as cust_segment,
		    r.email,
		    cc.exch_rate,
		    c.liab_group
		from
		    tCustomer c,
		    tAcct a,
		    tCustomerReg r,
		    tCcy cc
		where
		    c.cust_id = ? and
		    c.cust_id = a.cust_id and
		    c.cust_id = r.cust_id and
		    a.ccy_code = cc.ccy_code
	}

	# get bank ticker info
	ob_db::store_qry ob_fraudchk::get_ticker_info_bank {
		select
		    c.acct_no,
		    c.cr_date as cust_reg_date,
		    c.country_code,
		    c.username,
		    a.ccy_code,
		    r.addr_postcode,
		    r.fname,
		    r.lname,
		    r.email,
		    cc.exch_rate,
		    c.liab_group
		from
		    tCustomer c,
		    tAcct a,
		    tCustomerReg r,
		    tCcy cc
		where
		    c.cust_id = ? and
		    c.cust_id = a.cust_id and
		    c.cust_id = r.cust_id and
		    a.ccy_code = cc.ccy_code
	}

	# store registered card
	ob_db::store_qry ob_fraudchk::store_card_reg {
		insert into tCardReg (
		    cust_id,
		    cr_date,
		    enc_card_no,
		    card_bin,
		    payment_sort,
		    amount,
		    source,
		    ipaddr
		) values (
		    ?, current, ?, ?, ?, ?, ?, ?
	    )
	}

}



#--------------------------------------------------------------------------
# Screen Customer
#--------------------------------------------------------------------------

# Perform three checks on the customer's card registration attempt:
# - tumbling and swapping (for specified channels)
# - IP address monitoring (internet only)
# - compare address country, currency country and ip country with card country
#   (internet only)
#
#    cust_id   - customer to be screened
#    channel   - channel on which the customer is trying to register a card
#    card_no   - card number used in card registration
#    txn_type  - D for deposit, W for withdrawal
#    amount    - the amount in the deposit attempt
#    cookie    - cookie string ("")
#                It is responsbility of the caller to supply the cookie string
#    returns   - "" if no screening was done (either no card passed in or
#                screening is switched off)
#              - list containing:
#                cc_cookie      - country check cookie string
#                check_status   - A for Accept, C for Challenge, D for Decline
#                ipaddr         - ip address used in transaction
#                fail_reason    - reason code if check_status is not A
#                oper_note_code - if not empty, need to update
#                                 tCustomerReg.oper_notes with the translated
#                                 message
#                ip_city        - city of the IP
#                ip_country     - country of the IP
#                ip_routing     - ip routing
#                country_cf     - country confidence factor
#
proc ob_fraudchk::screen_customer {   cust_id
	                                  channel
	                                  card_no
	                                { txn_type  - }
	                                { amount    0 }
	                                { cookie   "" } } {
	variable CFG

	ob_log::write DEBUG {FRAUDCHK: screen_customer cust_id=$cust_id}

	# check_status can be   'A' = 'Accept'
	#						'C' = 'Challenge'
	#						'D' = 'Decline'
	set check_status "A"

	set cc_cookie    ""
	set fail_reason  "-"
	set ip_country   ""
	set ip_city      ""
	set ip_routing   ""
	set country_cf   ""

	if {$card_no == ""} {
		return ""
	}

	# check if fraud screening is 'On' or 'Monitor'
	set fraud_screen_enabled [_is_fraud_screen_enabled $channel]
	ob_log::write DEV {FRAUDCHK: fraud screen enabled: $fraud_screen_enabled}

	if {$fraud_screen_enabled != "Y" && $fraud_screen_enabled != "M"} {
		return ""
	}

	if {$channel == "I"} {
		set ipaddr [reqGetEnv "REMOTE_ADDR"]
	} else {
		set ipaddr "N/A"
	}

	_store_card_reg $cust_id $card_no $channel $txn_type $amount $ipaddr

	# country check can only be done for internet
	if {$channel == "I"} {

		set card_bin [string range $card_no 0 5]
		set check_status [_cntry_ccy_ip_check $cust_id $card_bin]
		ob_log::write INFO\
		    {FRAUDCHK: country check status for cust_id $cust_id: $check_status}

		if {$check_status != "A"} {
			set fail_reason "FRAUDCHK_FAILED_CNTRY_CCY_IP"
		}

		foreach {
			cc_cookie
			ip_country
			ip_city
			ip_routing
		} [_do_country_check $cust_id $cookie] break

	}

	# check for tumbling and swapping for the specified channels:
	if {$check_status == "A"
			&& [string first $channel $CFG(tumble_swap_chnls)] >= 0} {

		set check_status [_tumbling_and_swapping $card_no]
		ob_log::write DEV \
		    {FRAUDCHK: tumbling and swapping status: $check_status}

		if {$check_status != "A"} {
			set fail_reason "FRAUDCHK_FAILED_TUMBLE_SWAP"
		}
	}

	# IP address monitoring can only be done for internet
	if {$channel == "I" && $check_status == "A"} {

		set check_status [_ipaddr_monitoring $ipaddr]
		ob_log::write INFO \
		    {FRAUDCHK: ipaddr monitoring status: $check_status}

		if {$check_status != "A"} {
			set fail_reason "FRAUDCHK_FAILED_IP_MONITOR"
		}
	}

	set oper_note_code ""

	# check results of fraud screening
	# if fraudulent and fraud screening is 'On', update customer status
	if {$check_status != "A" && $fraud_screen_enabled == "Y"} {

		# Suspend customer
		if {$CFG(fail_cust_suspend)} {
			if {[catch {ob_db::exec_qry ob_fraudchk::upd_cust_status \
			            $cust_id S $fail_reason} msg]} {
				ob_log::write ERROR\
				    {FRAUDCHK: failed to update cust status, $msg}
			}
		}

		set oper_note_code FRAUDCHK_REFER
	}

	# Store new fraud status in tCustomerFlag
	if {[catch {ob_db::exec_qry ob_fraudchk::set_fraud_status_flag $cust_id \
	            "fraud_status" $check_status} msg]} {
		ob_log::write ERROR {FRAUDCHK: failed to update fraud status, $msg}
	}

	# Return info which can be used by ticker once this transaction is committed
	return [list $cc_cookie \
	            $check_status \
	            $ipaddr \
	            $fail_reason \
	            $oper_note_code \
	            $ip_city \
	            $ip_country \
	            $ip_routing \
	            $country_cf]
}



# Private procedure to examine the IP address of the customer
#
#   cust_id   - id of customer
#   cookie    - cookie string
#               It is responsbility of the caller to supply the cookie string
#   returns   - list containing new country code cookie, ip country, ip city,
#               ip routing, country confidence factor
#
proc ob_fraudchk::_do_country_check {cust_id cookie} {

	variable CFG

	ob_log::write DEV {FRAUDCHK:_do_country_check cust_id=$cust_id}

	foreach {flag \
	        outcome \
	        cc_cookie \
	        ip_country \
	        ip_is_aol \
	        ip_city \
	        ip_routing \
	        ip_is_blocked} [ob_countrychk::cookie_check $cust_id $cookie] {}

	return [list $cc_cookie $ip_country $ip_city $ip_routing]
}



# Screen customer carrying out a bank transaction
#
#   cust_id   - id of customer
#   channel   - channel where the transaction is taking place
#   amount    - amount in the transaction
#   cookie    - cookie string
#               It is responsbility of the caller to supply the cookie string
#   returns   - "" if no screening was done (either no card passed in or
#               screening is switched off)
#             - list containing:
#               cc_cookie      - country check cookie string
#               check_status   - A for Accept, C for Challenge, D for Decline
#               ipaddr         - ip address used in transaction
#               fail_reason    - reason code if check_status is not A
#               ip_city        - city of the IP
#               ip_country     - country of the IP
#               ip_routing     - ip routing
#               country_cf     - country confidence factor
#
proc ob_fraudchk::screen_customer_bank { cust_id channel amount {cookie ""} } {

	set check_status "A"
	set fail_reason  "-"
	set ip_country   ""
	set ip_city      ""
	set ip_routing   ""
	set country_cf   ""

	# check if fraud screening is 'On' or 'Monitor'
	set enabled [_is_fraud_screen_enabled $channel]
	ob_log::write DEV {FRAUDCHK: fraud screen enabled: $enabled}

	if {$enabled != "Y" && $enabled != "M"} {
		return ""
	}

	set ipaddr "N/A"
	if {$channel == "I"} {

		set ipaddr [reqGetEnv "REMOTE_ADDR"]

		foreach {cc_cookie ip_country ip_city ip_routing} \
		        [ob_fraudchk::_do_country_check $cust_id $cookie] {}
	}

	return [list $cc_cookie \
	            $check_status \
	            $ipaddr \
	            $fail_reason \
	            $ip_city \
	            $ip_country \
	            $ip_routing \
	            $country_cf]
}



# Privare procedure to check if fraud screening is enabled for a particular
# channel
#
#   channel - channel code in question
#   returns - Y, M, N or ""
#
proc ob_fraudchk::_is_fraud_screen_enabled { channel } {

	set res [ob_db::exec_qry ob_fraudchk::is_enabled $channel]

	if {[db_get_nrows $res] == 0} {
		ob_log::write INFO \
		    {FRAUDCHK: no rows returned for ob_fraudchk::is_enabled}
		set result N
	} else {
		set result [db_get_col $res 0 fraud_screen]
	}

	ob_db::rs_close $res
	return $result
}



# Private procedure to challenge card registration attempts from the same ip
# address within an hour
#
#   ipaddr - ip address to be screened
#   returns - A for accept
#             C for challenge
#
proc ob_fraudchk::_ipaddr_monitoring {ipaddr} {

	variable CFG

	# get IP address of credit card registration attempts in the last hour
	set res [ob_db::exec_qry ob_fraudchk::get_IP_cardreg_last_hour $ipaddr]

	set attempts [db_get_nrows $res]
	ob_log::write DEV {FRAUDCHK: ipaddr monitoring: rows returned: $attempts}

	# if more attempts then allowed, compare IP address to get an exact count
	set n 0
	if {$attempts >= $CFG(card_reg_ip_tries)} {

		for {set i 0} {$i < $attempts} {incr i} {
			set next_ipaddr [db_get_col $res $i ipaddr]
			if {$next_ipaddr == $ipaddr} {
				incr n
			}
		}
	}
	ob_db::rs_close $res

	ob_log::write INFO \
	    {FRAUDCHK: ipaddr monitoring: attempts from the same IP ($ipaddr) : $n}

	if {$n >= $CFG(card_reg_ip_tries)} {
		return "C"
	}

	return "A"
}



# Private procedure to challenge tumbling and swapping.
# x card registration attempts with similar card numbers within
# an hour results in a 'challenged' fraud status for this customer
#
#   card_no - card number to be screened
#   returns - A for accept
#             C for challenge
#
proc ob_fraudchk::_tumbling_and_swapping { card_no } {

	variable CFG

	set card_bin [string range $card_no 0 5]

	# get PAN number of credit card registration attempts in the last hour
	set res [ob_db::exec_qry ob_fraudchk::get_PAN_cardreg_last_hour $card_bin]

	set attempts [db_get_nrows $res]

	# if more attempts then allowed, compare PAN number (credit card number) to
	# get exact count
	set n 1
	if {$attempts >= $CFG(card_reg_ts_tries)} {

		# Trim last 4 digits from card number to check for tumbling and swapping
		set index [expr {[string length $card_no] - 5}]
		set bin [string range $card_no 0 $index]

		for {set i 0} {$i < $attempts} {incr i} {

			set next_card_no [ob_crypt::decrypt_cardno \
			            [db_get_col $res $i enc_card_no] 0]

			if {$next_card_no != $card_no} {

				# Trim last 4 digits from card number
				set index [expr {[string length $next_card_no] - 5}]
				set next_bin [string range $next_card_no 0 $index]
				if {$next_bin == $bin} {
					incr n
				}
			}
		}
	}
	ob_db::rs_close $res

	if {$n >= $CFG(card_reg_ts_tries)} {
		return "C"
	}

	return "A"
}



# Private procedure to challenge country, ccy & IP.
# A given amount of mismatches between ip country, currency country, address
# country and card country leads to the customer getting a fraud status of
# 'Challenged' or 'Declined'.
#
#   cust_id  - customer to be screened
#   card_bin - card bin used by customer
#   returns  - A for accept
#              C for challenge
#              D for decline
#
proc ob_fraudchk::_cntry_ccy_ip_check {cust_id card_bin} {

	variable CFG

	set res [ob_db::exec_qry ob_fraudchk::get_reg_details $cust_id]

	# pre-cautionary check
	if {[db_get_nrows $res] != 1} {
		ob_log::write ERROR\
		    {FRAUDCHK: Cntry/Ccy/IPaddr fraud check, cannot find cust $cust_id}
		ob_db::rs_close $res
		return D
	}

	set ipaddr       [db_get_col $res ipaddr]
	set ccy_code     [db_get_col $res ccy_code]
	set country_code [db_get_col $res country_code]
	ob_db::rs_close $res

	set points [ob_countrychk::fraud_check $cust_id \
	                                    $ipaddr \
	                                    $card_bin \
	                                    $country_code \
	                                    $ccy_code]

	ob_log::write INFO \
		{FRAUDCHK: Cntry/Ccy/IPaddr fraud check: number of mismatches $points}
	if {$points == $CFG(challenge_points)} {
		return C
	}
	if {$points >= $CFG(decline_points)} {
		return D
	}

	return A
}


# Private procedure to record the card registration attempt.
#
#   cust_id      - id of customer
#   card_no      - card number attempted
#   channel      - channel
#   payment_sort - D for deposit, W for withdrawal, - for neither
#   amount       - amount in transaction
#   ipaddr       - IP address of customer
#   returns      - nothing
#
proc ob_fraudchk::_store_card_reg { cust_id \
	                                card_no \
	                                channel \
	                                payment_sort \
	                                amount \
	                                ipaddr} {

	ob_log::write INFO {FRAUDCHK: store card reg attempt for cust_id: $cust_id}

	set card_bin [string range $card_no 0 5]
	set enc_card_no [ob_crypt::encrypt_cardno $card_no]

	if {[catch {ob_db::exec_qry ob_fraudchk::store_card_reg \
	                $cust_id $enc_card_no $card_bin $payment_sort $amount\
	                $channel $ipaddr} msg]} {
		ob_log::write ERROR {FRAUDCHK: cannot store card reg attempt: $msg}
	}
}


#--------------------------------------------------------------------------
# Ticker
#--------------------------------------------------------------------------

# Collect information about this fraud screening
#
#   styles            - 'MONITOR'  or 'TICKER
#   cust_id           - customer identifier
#   check_status      - check status
#   ipaddr            - IP address
#   channel           - channel
#   card_no           - card number
#   fail_reason       - fail reason
#   amount            - amount
#   ip_city           - IP city
#   ip_country        - IP country
#   ip_routing_method - IP routing method
#   country_cf        - Country
#   hldr_name         - Handler name
#   args              - additional arguments
#
proc ob_fraudchk::build_ticker_msg {
	styles
	cust_id
	check_status
	ipaddr
	channel
	card_no
	fail_reason
	amount
	ip_city
	ip_country
	ip_routing_method
	country_cf
	hldr_name
	args
} {

	variable CFG

	set check_status [switch $check_status {
		A {format FRAUDCHK_ACCEPT}
		C {format FRAUDCHK_CHALLENGE}
		D {format FRAUDCHK_DECLINE}
	}]

	if {$card_no != ""} {

	# get fraud screen information for ticker
		set card_bin [string range $card_no 0 5]
		set res [ob_db::exec_qry ob_fraudchk::get_ticker_info $card_bin \
		                                             $cust_id $cust_id]

		# Only show first six and last four digits of card number
		set index [expr {[string length $card_no] - 5}]
		set card_no [string replace $card_no 6 $index \
		                  [string repeat "X" [expr {$index - 5}]]]

		set card_reg_date [clock format [clock seconds] \
		                        -format "%Y-%m-%d %H:%M:%S"]

		# get values from db query
		set acct_no        [db_get_col $res acct_no]
		set cust_reg_date  [db_get_col $res cust_reg_date]
		set ccy_code       [db_get_col $res ccy_code]
		set bank           [db_get_col $res bank]
		set country_code   [db_get_col $res country_code]
		set nocards        [db_get_col $res nocards]
		set addr_postcode  [db_get_col $res addr_postcode]

	} else {

		# Assume we are adding bank info...
		set res [ob_db::exec_qry ob_fraudchk::get_ticker_info_bank \
		                                      $cust_id $cust_id]

		foreach col {
		        acct_no cust_reg_date ccy_code country_code addr_postcode} {
			set $col [db_get_col $res $col]
		}

		foreach var {card_reg_date bank nocards card_no} {
			set $var "N/A"
		}
	}

	set liab_group [db_get_col $res liab_group]

	set msg_list [list]

	foreach style $styles {
		if {$style == "MONITOR"} {
			# build monitor message list

			# convert user amount into system ccy
			set exch_rate  [db_get_col $res exch_rate]
			set amount_sys [expr {$amount / $exch_rate}]
			set amount_sys [format "%.2f" $amount_sys]

			lappend [concat $cust_id \
			    [db_get_col $res username] \
			    [db_get_col $res fname] \
			    [db_get_col $res lname] \
			    $acct_no \
			    $cust_reg_date \
			    [db_get_col $res cust_segment] \
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
			    $fail_reason \
			    $card_no \
			    $addr_postcode \
			    [db_get_col $res email] \
			    $ip_city \
			    $ip_country \
			    $ip_routing_method \
			    $country_cf \
			    $hldr_name \
			    $liab_group \
			    $args]
	} elseif {$style == "TICKER"} {

		lappend msg_list [list \
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
		        Reason          "{$fail_reason}" \
		        Amount          "{$amount}"]
		}
	}

	ob_db::rs_close $res

	return $msg_list
}

