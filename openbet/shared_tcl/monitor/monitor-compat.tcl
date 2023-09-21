# $Name:  $
#-------------------------------------------------------------------------------
#  $Header: /cvsroot-openbet/training/openbet/shared_tcl/monitor/monitor-compat.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
#-------------------------------------------------------------------------------
#  (C) 2009 Orbis Technology Ltd. All rights reserved.
#-------------------------------------------------------------------------------
#  Handle monitor compatibility with non-package monitor APIs.
#
#  The package provides wrappers for each of the older APIs which are potentially
#  still been used within other shared_tcl files or the calling application.
#  Avoid calling the wrapper APIs within your applications, always use the
#  monitor_monitor package (ob_monitor namespace).
#
#  Procedures (all exported):
#      ::MONITOR::send_alert
#      ::MONITOR::send_bet
#      ::MONITOR::send_betx
#      ::MONITOR::send_bet_rum
#      ::MONITOR::send_manual_adjustment
#      ::MONITOR::send_payment
#      ::MONITOR::send_pmt_non_card
#      ::MONITOR::send_red
#      ::MONITOR::send_fraud
#      ::MONITOR::send_async_bet
#      ::MONITOR::send_pmt_method_registered
#      ::MONITOR::send_override
#      ::MONITOR::send_poker
#      ::MONITOR::send_first_transfer
#      ::MONITOR::send_parked_bet
#      ::MONITOR::send_urn_match
#      ::MONITOR::send_suspended
#      ::MONITOR::send_man_bet
#      ::MONITOR::send_payment_denied 
#      ::MONITOR::send_non_runner
#      ::MONITOR::send_cust_max_stake
#      ::MONITOR::send_arbitrage
#      ::MONITOR::send_bf_order
#      ::MONITOR::send_ovs_response
#      ::MONITOR::send_cust_verify
#      ::MONITOR::send_crypt
#      ::MONITOR::send_system_message
#      ::MONITOR::datetime_now
#
#----------------------------------------------------------

package provide monitor_compat 1.0
package provide MONITOR 1.0
package require monitor_monitor 4.5



#-------------------------------------------------------------------------------
# NAMESPACE
#-------------------------------------------------------------------------------
namespace eval ::MONITOR {
}


#
#   MONITOR::init function 
#
proc MONITOR::init {} {

	::ob_monitor::init
}


#
#  Function to check whether monitor is enabled or not 
#  
proc MONITOR::is_enabled  {} {

	::ob_monitor::is_enabled
}

#-------------------------------------------------------------------------------
# Alert
#-------------------------------------------------------------------------------
proc MONITOR::send_alert {
	class_id
	class_name
	type_id
	type_name
	ev_id
	ev_name
	mkt_id
	mkt_name
	sln_id
	sln_name
	alert_code
	alert_date
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_alert>, using <ob_monitor::alert> would be much better.}

	return [ob_monitor::alert \
		$class_id             \
		$class_name           \
		$type_id              \
		$type_name            \
		$ev_id                \
		$ev_name              \
		$mkt_id               \
		$mkt_name             \
		$sln_id               \
		$sln_name             \
		$alert_code           \
		$alert_date           \
	]

}



#--------------------------------------------------------------------------
# Bet
#--------------------------------------------------------------------------
proc MONITOR::send_bet {
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
	{ max_bet_allowed_per_line {} }
	{ max_stake_percentage_used {} }
      } {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_bet>, using <ob_monitor::bet> would be much better.}

       return [ ob_monitor::bet \
	$cust_id  		\
	$cust_uname 		\
	$cust_fname 		\
	$cust_lname 		\
	$cust_reg_code 		\
	$cust_is_elite 		\
	$cust_is_notifiable 	\
	$country_code 		\
	$cust_reg_postcode 	\
	$cust_reg_email 	\
	$channel 		\
	$bet_id 		\
	$bet_type 		\
	$bet_date 		\
	$amount_usr 		\
	$amount_sys 		\
	$ccy_code 		\
	$stake_factor 		\
	$num_slns 		\
	$categorys 		\
	$class_ids 		\
	$class_names 		\
	$type_ids 		\
	$type_names 		\
	$ev_ids 		\
	$ev_names 		\
	$ev_dates 		\
	$mkt_ids 		\
	$mkt_names 		\
	$sln_ids 		\
	$sln_names 		\
	$prices 		\
	$leg_type 		\
	$liab_group 		\
	$monitoreds 		\
        $max_bet_allowed_per_line  \
        $max_stake_percentage_used  \
 ]

}



#-------------------------------------------------------------------------------
# Betx
#-------------------------------------------------------------------------------
proc MONITOR::send_betx {
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

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_betx>, using <ob_monitor::betx> would be much better.}

	return [ob_monitor::betx \
		$cust_id             \
		$cust_uname          \
		$cust_fname          \
		$cust_lname          \
		$cust_is_elite       \
		$cust_is_notifiable  \
		$country_code        \
		$channel             \
		$betx_id             \
		$betx_type           \
		$betx_date           \
		$amount_usr          \
		$amount_sys          \
		$ccy_code            \
		$class_id            \
		$class_name          \
		$type_id             \
		$type_name           \
		$ev_id               \
		$ev_name             \
		$ev_date             \
		$mkt_id              \
		$mkt_name            \
		$sln_id              \
		$sln_name            \
		$betx_polarity       \
		$betx_hcap           \
		$betx_price          \
		$betx_stake_u        \
		$betx_stake_m        \
		$betx_payout_m       \
		$betx_expire_type    \
		$betx_expire_at      \
	]

}


#-------------------------------------------------------------------------------
# Bet RUM
#-------------------------------------------------------------------------------
proc MONITOR::send_bet_rum {
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

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_bet_rum>, using <ob_monitor::bet_rum> would be much better.}

	return [ob_monitor::bet_rum \
		$channel                \
		$bet_id                 \
		$bet_type               \
		$bet_date               \
		$amount_sys             \
		$num_slns               \
		$leg_type               \
		$num_legs               \
		$num_lines              \
		$rum_total              \
        	$rum_liab_total         \
	 	$cust_uname             \  
        	$sln_names              \
          	$class_names            \
	]
}





#-------------------------------------------------------------------------------
# send_seln_rum
#-------------------------------------------------------------------------------
proc MONITOR::send_seln_rum {
        sln_id
	sln_name
	ev_date
	rum_total
	rum_liab_total
	mkt_name
	class_name
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_seln_rum>, using <ob_monitor::send_seln_rum> would be much better.}

	return [ob_monitor::send_seln_rum \
        $sln_id \
	$sln_name \
	$ev_date  \
	$rum_total \
	$rum_liab_total \
	$mkt_name \
	$class_name \
	]

}

#-------------------------------------------------------------------------------
# Manual Adjustment
#-------------------------------------------------------------------------------
proc MONITOR::send_manual_adjustment {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_is_notifiable
        cust_reg_code
	amount_usr
	amount_sys
	ccy_code
	madj_status
	madj_code
	madj_date
	liab_group
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_manual_adjustment>, using <ob_monitor::manual_adjustment> would be much better.}

	return [ob_monitor::manual_adjustment \
		$cust_id                          \
		$cust_uname                       \
		$cust_fname                       \
		$cust_lname                       \
		$cust_is_notifiable               \
                $cust_reg_code                    \
		$amount_usr                       \
		$amount_sys                       \
		$ccy_code                         \
		$madj_status                      \
		$madj_code                        \
		$madj_date                        \
		$liab_group                       \
	]

}


#-------------------------------------------------------------------------------
# Payment
#-------------------------------------------------------------------------------
proc MONITOR::send_payment {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	country_code
	cust_reg_date
	cust_acctno
	cust_reg_code
	cust_is_notifiable
	acct_balance
	amount_usr
	amount_sys
	ccy_code
	pmt_id
	pmt_date
	pmt_status
	pmt_sort
	channel
	gw_auth_date
	gw_auth_code
	gw_ret_code
	gw_ret_msg
	gw_ref_no
	hldr_name
	liab_group
	cv2avs_status
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_payment>, using <ob_monitor::payment> would be much better.}

	return [ob_monitor::payment \
		$cust_id                \
		$cust_uname             \
		$cust_fname             \
		$cust_lname             \
		$country_code           \
		$cust_reg_date          \
		$cust_acctno            \
             	$cust_reg_code
		$cust_is_notifiable     \
		$acct_balance           \
		$amount_usr             \
		$amount_sys             \
		$ccy_code               \
		$pmt_id                 \
		$pmt_date               \
		$pmt_status             \
		$pmt_sort               \
		$channel                \
		$gw_auth_date           \
		$gw_auth_code           \
		$gw_ret_code            \
		$gw_ret_msg             \
		$gw_ref_no              \
		$hldr_name              \
		$liab_group             \
		$cv2avs_status          \
	]

}



#-------------------------------------------------------------------------------
# Non Card Payments
#-------------------------------------------------------------------------------
proc MONITOR::send_pmt_non_card {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_postcode
	cust_reg_email
	country_code
	cust_reg_date
	cust_reg_code
	cust_is_notifiable
	cust_acctno
	acct_balance
	ip_country
	ip_city
	pmt_method
	ccy_code
	amount_usr
	amount_sys
	pmt_id
	pmt_date
	pmt_sort
	pmt_status
	ext_unique_id
	bank
	channel
	{trading_note ""}
	{cum_wtd_usr ""}
	{cum_wtd_sys ""}
	{cum_dep_usr ""}
	{cum_dep_sys ""}
	{max_wtd_pc ""}
	{max_dep_pc ""}
	args
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_pmt_non_card>, using <ob_monitor::pmt_non_card> would be much better.}

	return [ob_monitor::pmt_non_card \
		$cust_id                     \
		$cust_uname                  \
		$cust_fname                  \
		$cust_lname                  \
		$cust_reg_postcode           \
		$cust_reg_email              \
		$country_code                \
		$cust_reg_date               \
		$cust_reg_code               \
		$cust_is_notifiable          \
		$cust_acctno                 \
		$acct_balance                \
		$ip_country                  \
		$ip_city                     \
		$pmt_method                  \
		$ccy_code                    \
		$amount_usr                  \
		$amount_sys                  \
		$pmt_id                      \
		$pmt_date                    \
		$pmt_sort                    \
		$pmt_status                  \
		$ext_unique_id               \
		$bank                        \
		$channel                     \
		$trading_note                \
		$cum_wtd_usr                 \
		$cum_wtd_sys                 \
		$cum_dep_usr                 \
		$cum_dep_sys                 \
		$max_wtd_pc                  \
		$max_dep_pc                  \
		$args                        \
	]

}

#-------------------------------------------------------------------------------
# Sends a red message
#-------------------------------------------------------------------------------
proc MONITOR::send_red {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_date
	cust_is_notifiable
	amount_usr
	amount_sys
	ccy_code
	channel
	red_date
	red_status
	red_bank
	red_ip
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_red>, using <ob_monitor::red> would be much better.}
        return [ob_monitor::red
	$cust_id \
	$cust_uname \
 	$cust_fname \
	$cust_lname \ 
	$cust_reg_date \
	$cust_is_notifiable \ 
	$amount_usr \
	$amount_sys \
	$ccy_code \
	$channel \
	$red_date \
	$red_status \
	$red_bank \
	$red_ip \
        ]
}  


#-------------------------------------------------------------------------------
# Fraud
#-------------------------------------------------------------------------------
proc MONITOR::send_fraud {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_acctno
	cust_reg_date
	cust_reg_code
	cust_is_notifiable
	card_reg_date
	ccy_code
	channel
	country_code
	fraud_status
	fraud_bank
	fraud_ip
	num_cards
	amount_usr
	amount_sys
	fraud_reason
	fraud_card
	cust_reg_postcode
	cust_reg_email
	ip_city
	ip_country
	ip_routing_method
	country_cf
	hldr_name
	liab_group
	args

} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_fraud>, using <ob_monitor::fraud> would be much better.}

	return [ob_monitor::fraud \
		$cust_id \
		$cust_uname \
		$cust_fname \
		$cust_lname \
		$cust_acctno \
		$cust_reg_date \
		$cust_reg_code \
		$cust_is_notifiable \
		$card_reg_date \
		$ccy_code \
		$channel \
		$country_code \
		$fraud_status \
		$fraud_bank \
		$fraud_ip \
		$num_cards \
		$amount_usr \
		$amount_sys \
		$fraud_reason \
		$fraud_card \
		$cust_reg_postcode \
		$cust_reg_email \
		$ip_city \
		$ip_country \
		$ip_routing_method \
		$country_cf \
		$hldr_name \
		$liab_group \
		$args \
	]

}



##
# MONITOR::send_async_bet - Sends an asynchronous bet message to the ticker
#
#
# PARAMS
#
#     [bet_id] - the bet id          : tbet.bet_id
#
#     [cust_uname] - customer's username
#
#     [cust_fname] - customer's first name
#
#     [cust_lname] - customer's surname
#
#     [cust_acctno] - customers account number        : tAcct.acct_no
#
#     [cust_is_notifiable] - is customer notifiable: tCustomer.notifyable
#
#     [bet_date]   - Date/time of when bet was place: tBet.cr_date
#
#     [bet_type]   - bet type                      : tBet.bet_type
#
#     [ev_name]    - event name                     : tEv.desc
#
#     [sln_name]   - selection name               : tEvOc.desc
#
#     [price]      - the odds of the selection
#
#     [amount_usr] - bet stake in user's currency
#
#
##
proc MONITOR::send_async_bet {
	bet_id
	cust_uname
	cust_fname
	cust_lname
	cust_acctno
	cust_is_notifiable
	bet_date
	bet_type
	ev_name
	sln_name
	price
	amount_usr
	ccy_code
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_async_bet>, using <ob_monitor::async_bet> would be much better.}

	return [ob_monitor::async_bet \
	$bet_id \
	$cust_uname \
	$cust_fname \
	$cust_lname \
	$cust_acctno \ 
	$cust_is_notifiable \
	$bet_date \
	$bet_type \
	$ev_name \
	$sln_name \
	$price \
	$amount_usr \
	$ccy_code \
	]

}

#-------------------------------------------------------------------------------
# Payment Method Registered
#-------------------------------------------------------------------------------
proc MONITOR::send_pmt_method_registered {
	cust_id
	cust_uname
	cust_fname
	cust_lname
	cust_reg_date
	cust_reg_code
	cust_reg_postcode
	cust_reg_email
	cust_is_notifiable
	country_code
	ccy_code
	channel
	amount_usr
	amount_sys
	ip_city
	ip_country
	ip_routing_method
	country_cf
	liab_group
	pmt_method
	cpm_id
	pmt_method_count
	generic_pmt_mthd_id
	pmt_mthd_other
	args
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_pmt_method_registered>, using <ob_monitor::pmt_method_registered> would be much better.}

	return [ob_monitor::pmt_method_registered \
		$cust_id                              \
		$cust_uname                           \
		$cust_fname                           \
		$cust_lname                           \
		$cust_reg_date                        \
              	$cust_reg_code                        \
		$cust_reg_postcode                    \
		$cust_reg_email                       \
		$cust_is_notifiable                   \
		$country_code                         \
		$ccy_code                             \
		$channel                              \
		$amount_usr                           \
		$amount_sys                           \
		$ip_city                              \
		$ip_country                           \
		$ip_routing_method                    \
		$country_cf                           \
		$liab_group                           \
		$pmt_method                           \
		$cpm_id                               \
		$pmt_method_count                     \
		$generic_pmt_mthd_id                  \
		$pmt_mthd_other                       \
		$args                                 \
	]

}


#-------------------------------------------------------------------------------
# Override
#-------------------------------------------------------------------------------
proc MONITOR::send_override {
	cust_id
	cust_reg_code
	oper_id
	oper_auth_id
	action
	override_date
	call_id
	leg_no
	part_no
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_override>, using <ob_monitor::override> would be much better.}

	return [ob_monitor::override \
		$cust_id                 \
		$cust_reg_code		 \
		$oper_id                 \
		$oper_auth_id            \
		$action                  \
		$override_date           \
		$call_id                 \
		$leg_no                  \
		$part_no                 \
	]

}


#-------------------------------------------------------------------------------
# Poker
#-------------------------------------------------------------------------------
proc MONITOR::send_poker {
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
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_poker>, using <ob_monitor::poker> would be much better.}

	return [ob_monitor::poker \
		$cust_id              \
		$cust_uname           \
		$cust_is_notifiable   \
		$fraud_status         \
		$transfer_time        \
		$ccy_code             \
		$country_code         \
		$ip_country           \
		$transfer_type        \
		$amount_sys           \
	]

}

#-------------------------------------------------------------------------------
# First Transfer
#-------------------------------------------------------------------------------
proc MONITOR::send_first_transfer {
	cust_id
	cust_uname
	cust_is_notifiable
	transfer_time
	ccy_code
	country_code
	ip_country
	transfer_type
	amount_sys
	casino_code
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_first_transfer>, using <ob_monitor::first_transfer> would be much better.}

	return [ob_monitor::first_transfer \
		$cust_id                       \
		$cust_uname                    \
		$cust_is_notifiable            \
		$transfer_time                 \
		$ccy_code                      \
		$country_code                  \
		$ip_country                    \
		$transfer_type                 \
		$amount_sys                    \
		$casino_code                   \
	]

}


#-------------------------------------------------------------------------------
# Parked Bet
#-------------------------------------------------------------------------------
proc MONITOR::send_parked_bet {
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

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_parked_bet>, using <ob_monitor::parked_bet> would be much better.}

	return [ob_monitor::parked_bet \
		$bet_receipt               \
		$cust_uname                \
		$cust_acctno               \
		$cust_is_notifiable        \
		$bet_date                  \
		$bet_settled               \
		$bet_type                  \
		$leg_no                    \
		$leg_type                  \
		$ccy_code                  \
		$bet_stake                 \
		$bet_winnings              \
		$bet_refund                \
		$leg_sort                  \
		$ev_name                   \
		$mkt_name                  \
		$sln_name                  \
		$price                     \
		$result                    \
	]

}

##
# MONITOR::send_urn_match - Sends registration information to the ticker when
#                  there is a URN match by the criteria in module cust_matcher::
#
#

proc MONITOR::send_urn_match {
	cust_reg_date
	cust_uname
	cust_acct_no
	cust_addr_1
	cust_reg_postcode
	cust_orign_uname
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_urn_match>, using <ob_monitor::urn_match> would be much better.}

	return [ob_monitor::urn_match \
	$cust_reg_date \
	$cust_uname \
	$cust_acct_no \
	$cust_addr_1 \
	$cust_reg_postcode \
	$cust_orign_uname \
	]

}


##
# send_suspended - Sends registration information along with a reason
#                           to the ticker when a customer is suspended
#
# 
# PARAMS
#
#
#	[cust_reg_date] - customer registration date: tCustomer.cr_date
#
#	[cust_uname] - customer username: tCustomer.username
#
#	[cust_acct_no] - customer account number: tCustomer.acct_no
#
#	[cust_addr_1] - customer street: tCustomerReg.steet_addr_1
#
#	[cust_reg_postcode] - customer postcode: tCustomerReg.addr_postcode
#
#      [cust_orign_uname] - username of matched customer: tCustomer.username
#
#      [reason] - note to indicate the reason the customer was suspended
#
#
##
proc MONITOR::send_suspended {
	cust_reg_date
	cust_uname
	cust_acct_no
	cust_addr_1
	cust_reg_postcode
	cust_orign_uname
	suspended_code
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_suspended>, using <ob_monitor::suspended> would be much better.}

	return [ob_monitor::suspended \
	$cust_reg_date \
	$cust_uname \
	$cust_acct_no \
	$cust_addr_1 \
	$cust_reg_postcode \
	$cust_orign_uname \
 	$suspended_code \
	]

}



##
# MONITOR::send_man_bet - Sends a manual bet message
#
proc MONITOR::send_man_bet {
	oper_id
	oper_name
	cust_id
	cust_uname
	cust_name
	cust_liab_group
	cust_reg_code
	cust_reg_postcode
	cust_reg_email
	cust_is_elite
	cust_is_notifiable
	stake_factor
	country_code
	category
	channel
	bet_id
	bet_date
	expected_settle_date
	amount_usr
	amount_sys
	ccy_code
	class_id
	class_name
	type_id
	type_name
	desc
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_man_bet>, using <ob_monitor::man_bet> would be much better.}

	return [ob_monitor::man_bet \
	$oper_id \
	$oper_name \
	$cust_id \
	$cust_uname \
        $cust_name \
	$cust_liab_group \
	$cust_reg_code \
	$cust_reg_postcode \
	$cust_reg_email \
	$cust_is_elite \
	$cust_is_notifiable \
	$stake_factor \
	$country_code \
	$category \
	$channel \
	$bet_id \
	$bet_date \
	$expected_settle_date \
	$amount_usr \
	$amount_sys \
	$ccy_code \
	$class_id \
	$class_name \
        $type_id \
	$type_name \
	$desc \
	]

}

#
# MONITOR::send_payment_denied - Sends a payment denied message
#
#
# PARAMS
#
#	[cust_uname] - customer username
#
#	[cust_fname] - customer firstname
#
#	[cust_lname] - customer lastname
#
#	[pmt_date]   - payment date
#
#	[channel] - payment source
#
#	[oper_id] - operator id
#
#	[pmt_method] - payment method
#
#	[amount_usr] - payment amount
#
#	[ccy_code]   -currency
#
#
#
#
##
proc MONITOR::send_payment_denied {
	cust_uname
	cust_fname
	cust_lname
	pmt_date
	channel
	oper_id
	pmt_method
	amount_usr
	ccy_code
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_payment_denied>, using <ob_monitor::payment_denied> would be much better.}

	return [ob_monitor::payment_denied \
		$cust_uname \
		$cust_fname \
          	$cust_lname \
           	$pmt_date \
          	$channel \
         	$oper_id \
         	$pmt_method \
        	$amount_usr \
           	$ccy_code \
               ]
}


##
# MONITOR::send_non_runner - Sends a non runner message to the ticker
#
#
# PARAMS
#
#     [ev_name]    - the event name : tev.desc
#
#     [sln_id]     - selection id : tevoc.ev_oc_od
#
#     [sln_name]   - selection name : tevoc.desc
#
#     [price]      - the odds of the selection
#
##
proc MONITOR::send_non_runner {
	ev_name
	sln_id
	sln_name
	price
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_non_runner>, using <ob_monitor::non_runner> would be much better.}

	return [ob_monitor::non_runner \
		$ev_name \
		$sln_id \
		$sln_name \
		$price \
               ]
}


##
# MONITOR::send_cust_max_stake - Sends a customer max stake factor message
#
# 
# 
# PARAMS
#
#     [change_timestamp]   - timestamp of the change
#
#     [cust_stk_acctno]    - customers account number     : tAcct.acct_no
#
#     [cust_stk_lname]     - customer's surname           : tCustomerReg.lname
#
#     [cust_stk_username]  - customer's username          : tCustomer.username
#
#     [cust_stk_factor]    - customer's stake factor      : (DD level dependent)
#
#     [stk_factor_level]   - stake factor level           : [ALL|CLASS|EVENT]
#
#     [level_value]        - stake factor level value     : (DD level dependent)
#
#     [level_prev_value]   - stake factor previous val    : (where applicable)
#
#     [op_performed]       - operation being performed    : (where applicable)
#
#     [operator]           - operator's username          : username
#
# 
proc MONITOR::send_cust_max_stake {
	change_timestamp
	cust_stk_acctno
	cust_stk_lname
	cust_stk_username
	stk_factor_level
	cust_stk_factor
	level_value
	level_prev_value
	op_performed
	operator
 } {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_cust_max_stake>, using <ob_monitor::cust_max_stake> would be much better.}

	return [ob_monitor::cust_max_stake \
                 $change_timestamp \
                 $cust_stk_acctno \
		 $cust_stk_lname \
 	         $cust_stk_username \
		 $stk_factor_level \
     		 $cust_stk_factor \
		 $level_value \
                 $level_prev_value \
		 $op_performed \
		 $operator \
               ]
}


##
# MONITOR::send_arbitrage - Sends an arbitrage message
#
#
# PARAMS
#
#       [class_id] - class id
#
#       [class_name] - class name
#
#       [type_id] - event type id
#
#       [type_name] - event type name
#
#       [ev_id] - event id
#
#       [ev_name] - event name
#
#       [mkt_id] - market id
#
#       [mkt_name] - market name
#
#       [sln_id] - selection (aka event outcome) id
#
#       [sln_name] - selection (aka event outcome) name
#
#   	[price] - selection price
#
#   	[bf_price] - Betfair price
##
proc MONITOR::send_arbitrage {
        class_id
        class_name
        type_id
        type_name
        ev_id
        ev_name
        mkt_id
        mkt_name
        sln_id
        sln_name
        price
        bf_price
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_arbitrage>, using <ob_monitor::arbitrage> would be much better.}

	return [ob_monitor::arbitrage \
		$class_id \
	        $class_name \
	        $type_id \
	        $type_name \
	        $ev_id \
	        $ev_name \
	        $mkt_id \
	        $mkt_name \
	        $sln_id \
	        $sln_name \
	        $price \
	        $bf_price \
               ]
}

##
# MONITOR::send_bf_order - Sends a BetFair order message
#
#
# PARAMS
#
#   [order_reason] - Order reason
#
#   [ev_id] - event id
#
#   [ev_name] - event name
#
#   [mkt_id] - market id
#
#   [mkt_name] - market name
#
#   [sln_id] - selection (aka event outcome) id
#
#   [sln_name] - selection (aka event outcome) name
#
#   [bf_bet_id] - Betfair Bet Id
#
#   [bf_size] - Betfair stake
#
#   [bf_price] - Betfair price
#
#   [bf_status] - Order status in Betfair
#
#   [bf_order_id] - Betfair Openbet Order Id
#
##
proc MONITOR::send_bf_order {
	order_reason
	ev_id
	ev_name
	mkt_id
	mkt_name
	sln_id
	sln_name
	bf_bet_id
	bf_status
	bf_price
	bf_size_matched
	bf_size
	bf_order_id
} {

	ob_log::write DEBUG {!!!COMPAT WARNING!!! You are using the old proc named <MONITOR::send_bf_order>, using <ob_monitor::bf_order> would be much better.}

	return [ob_monitor::bf_order \
                 	$order_reason \
			$ev_id \
			$ev_name \
			$mkt_id \
			$mkt_name \
			$sln_id \
			$sln_name \
			$bf_bet_id \
			$bf_status \
			$bf_price  \
			$bf_size_matched \
			$bf_size \
			$bf_order_id \
                        ]
}




proc MONITOR::datetime_now {} {
	return [ob_monitor::datetime_now]
}

# Intialize monitor
#ob_monitor::init
