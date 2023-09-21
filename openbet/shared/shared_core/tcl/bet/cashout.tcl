# $Id$
# (C) 2014 Orbis Technology Ltd. All rights reserved.
#
# Cashout interface.
# Provides functionality to cashout a bet.
#
# Example usage:
# package require core::bet::cashout 1.0
#
# Procedures:
#     core::bet::cashout::init
#     core::bet::cashout::cashout_bet
#     core::bet::cashout::filter_cashout_bets
#     core::bet::cashout::can_cashout_bet
#     core::bet::cashout::get_cashout_amount
#     core::bet::cashout::get_cashout_pricing_chart
#     core::bet::cashout::is_cashout_enabled
#     core::bet::cashout::get_unsettled_cashout_bets
#     core::bet::cashout::get_bir_cashout_info
#

set pkg_version 1.0
package provide core::bet::cashout $pkg_version

# Dependencies
package require core::args                 1.0
package require core::check                1.0

core::args::register_ns \
	-namespace     core::bet::cashout \
	-version       $pkg_version \
	-dependent     [list \
		core::args \
		core::check \
		core::interface] \
	-desc          {Core interface for Cashouts.} \
	-docs          "xml/bet/cashout.xml"


namespace eval core::bet::cashout {

	# Cashout specific parameters
	variable CORE_DEF
	set CORE_DEF(bet_id)                 [list -arg -bet_id             -mand 1 -check INT      -desc {Bet Id Identifier}]
	set CORE_DEF(bet_ids)                [list -arg -bet_ids            -mand 1 -check LIST     -desc {List of Bet Identifiers}]
	set CORE_DEF(cashout_amount)         [list -arg -cashout_amount     -mand 1 -check UDECIMAL -desc {Amount for which the bet is being cashed out}]
	set CORE_DEF(source)                 [list -arg -source             -mand 1 -check STRING   -desc {Channel the cashout action is done}]
	set CORE_DEF(acct_id)                [list -arg -acct_id            -mand 1 -check STRING   -desc {Customer Account Id}]
	set CORE_DEF(bet_reference)          [list -arg -bet_reference      -mand 1 -check UINT     -desc {Bet num or group_id in the bet packages}]
	set CORE_DEF(bet_type)               [list -arg -bet_type           -mand 0 -check STRING   -default "" -desc {Bet type, required if bet_reference is a GROUP}]
	set CORE_DEF(reference_type)         [list -arg -reference_type     -mand 0 -check {EXACT -args {BET GROUP}} -default "BET" -desc {Whether the reference refers to a BET or a GROUP}]
	set CORE_DEF(user_id)                [list -arg -user_id            -mand 1 -check INT      -desc {Admin User Identifier}]
	set CORE_DEF(bir_req_id)             [list -arg -bir_req_id         -mand 1 -check INT      -desc {BIR Cashout Id Identifier}]
	set CORE_DEF(admin_user_id,opt)      [list -arg -admin_user_id      -mand 0 -check INT      -default ""  -desc {Admin User Identifier}]
	set CORE_DEF(admin_username,opt)     [list -arg -admin_username     -mand 0 -check STRING   -default ""  -desc {Admin Username}]
	set CORE_DEF(cashout_type,opt)       [list -arg -cashout_type       -mand 0 -check {EXACT -args {C M}}   -default "C"  -desc {Cashout type e.g. C--> customer initiated, M--> manual}]
	set CORE_DEF(cashout_info,opt)       [list -arg -cashout_info       -mand 0 -check STRING   -default ""  -desc {Information provided by admin user on manual cashout}]
	set CORE_DEF(transactional,opt)      [list -arg -transactional      -mand 0 -check BOOL     -default 1   -desc {Whether the DB transaction should be handled by the Cashout package (true) or by the calling application (false).}]
	set CORE_DEF(ipaddr,opt)             [list -arg -ipaddr             -mand 0 -check IPADDR   -default ""  -desc {IP address the cashout was initiated}]
	set CORE_DEF(format,opt)             [list -arg -format             -mand 0 -check {EXACT -args {JSON LIST}}   -default ""  -desc {Return format}]
	set CORE_DEF(error_overrides,opt)    [list -arg -error_overrides    -mand 0 -check LIST     -default ""  -desc {List of cashout errors to ignore when checking the cashout rules. For instance, adding "CASHOUT_ODDS_TOO_HIGH" to this list will skip the cashout max odd rule}]
	set CORE_DEF(overridden_errors,opt)  [list -arg -overridden_errors  -mand 0 -check LIST     -default ""  -desc {List of cashout errors that would have been thrown if not for the error_overrides.}]
	set CORE_DEF(joint_account_id,opt)   [list -arg -joint_account_id   -mand 0 -check UINT     -default -1  -desc {Joint Account Id. Provided when cashout is being done on behalf of a Joint Account}]
	set CORE_DEF(log_only,opt)           [list -arg -log_only           -mand 0 -check BOOL     -default 0   -desc {Whether we want to do any DB work or just return what we would have passed into the DB}]
	set CORE_DEF(cust_id,opt)            [list -arg -cust_id            -mand 0 -check UINT     -default -1  -desc {Customer Id. Provided when cashout is being done on nominated member of a joint account}]
	set CORE_DEF(max_num,opt)            [list -arg -max_num            -mand 0 -check UINT     -default -1  -desc {Number of bets to return. No value or -1 means no number restriction}]


	set CORE_DEF(errors)  [list \
		DB_ERROR \
		CASHOUT_BET_NOT_LOADED \
		CASHOUT_BIR_BET_NOT_LOADED \
		CASHOUT_CASHOUT_SETTLED \
		CASHOUT_NEGATIVE_OFFER \
		CASHOUT_NO_ODDS \
		CASHOUT_DISABLED \
		CASHOUT_ALGORITHM_UNAVAILABLE \
		CASHOUT_SOURCE_NOT_ALLOWED \
		CASHOUT_BET_SETTLED \
		CASHOUT_BET_PARKED \
		CASHOUT_BET_SUSP \
		CASHOUT_BET_CANCELLED \
		CASHOUT_BET_WAITING \
		CASHOUT_BET_BAD_STATUS \
		CASHOUT_BET_NO_CASHOUT \
		CASHOUT_BETTYPE_NOT_ALLOWED \
		CASHOUT_BIR_NOT_ALLOWED \
		CASHOUT_ERROR_REPRICING \
		CASHOUT_FREEBET_USED \
		CASHOUT_MANBET_NOT_ALLOWED \
		CASHOUT_SINGLES_NOT_ALLOWED \
		CASHOUT_MULTIS_NOT_ALLOWED \
		CASHOUT_LEGSORT_NOT_ALLOWED \
		CASHOUT_BET_NOT_TO_WIN \
		CASHOUT_PRICETYPE_NOT_ALLOWED \
		CASHOUT_MAX_NUM_EXCEEDED \
		CASHOUT_MONITOR_ERROR \
		CASHOUT_NOPRICE \
		CASHOUT_NON_EXISTENT \
		CASHOUT_ODDS_TOO_HIGH \
		CASHOUT_VALUE_TOO_LOW \
		CASHOUT_PLACED_ODDS_TOO_HIGH \
		CASHOUT_SELN_NOT_LOADED \
		CASHOUT_SELN_RESULTED \
		CASHOUT_SELN_NOT_DISPLAYED \
		CASHOUT_SELN_SUSPENDED \
		CASHOUT_LINKED_SELN_NO_BIR_CASHOUT \
		CASHOUT_SELN_NO_BIR_CASHOUT \
		CASHOUT_SELN_NO_CASHOUT \
		CASHOUT_CHANNEL_BIR_NOT_ALLOWED \
		CASHOUT_ALL_SELN_SETTLED \
		CASHOUT_HCAP_CHANGED \
		CASHOUT_BIR_INDEX_CHANGED \
		CASHOUT_SELN_DEAD_HEAT \
		CASHOUT_SELN_RULE_4 \
		CASHOUT_CUST_ERROR \
		CASHOUT_CUST_RESTRICT_FLAG \
		CASHOUT_JOINT_ACCT_UNKNOWN]

}

##
# @brief   Initialisation of the cashout configuration and prepare the queries.
#
core::args::register \
	-interface core::bet::cashout::init \
	-desc      {Initialisation of the cashout configuration and prepare the queries.} \
	-mand_impl 0

##
# @brief   Cashout a bet.
#
# @return
#          status
#            The cashout status. Will be either:
#                CASHOUT_SUCCESS        - if the bet could be cashed out
#                CASHOUT_PENDING        - if there will be a delay due to the
#                                         event having started
#                CASHOUT_WAITING        - if there will be a delay due to the
#                                         funding being sent asynchronously
#                CASHOUT_VALUE_CHANGE   - if the cashout value has changed. i.e.
#                                         is different from the -cashout_amount
#                                         argument value
#                CASHOUT_VALUE_TOO_HIGH - if the calculated cashout amount is
#                                         greated than potential payout of bet.
#
#          overridden_errors
#                An optional list containing the overriden errors
#
#          cashout_delay
#                Cashout delay for the bet if the bet is in running.
#
#          cashout_req_id
#                BIR request identifier if the bet is in running.
#
#          cashout_amount
#                New cashout amount when CASHOUT_VALUE_CHANGE or
#                CASHOUT_VALUE_TOO_HIGH errors are thrown (returned as part of the errorinfo).
#
core::args::register \
	-interface    core::bet::cashout::cashout_bet \
	-desc         {Cashout a bet} \
	-errors       $::core::bet::cashout::CORE_DEF(errors) \
	-return_data  [list \
		[list -arg -status         -mand 1   -check {EXACT -args {CASHOUT_SUCCESS CASHOUT_WAITING CASHOUT_PENDING CASHOUT_VALUE_CHANGE CASHOUT_VALUE_TOO_HIGH}} -desc {Confirms whether the cashout was successful or whether there will be a delay due to the event having started}] \
		[list -arg -cashout_delay  -mand 0   -check UINT     -desc {Cashout delay for the bet, used when the event the bet was placed on is in running.}] \
		[list -arg -bir_req_id     -mand 0   -check UINT     -desc {BIR request identifier.}] \
		[list -arg -cashout_amount -mand 0   -check UDECIMAL -desc {New cashout amount when CASHOUT_VALUE_CHANGE or CASHOUT_VALUE_TOO_HIGH errors are thrown (returned as part of the errorinfo).}] \
        $::core::bet::cashout::CORE_DEF(overridden_errors,opt) \
	] \
	-args         [list \
		 $::core::bet::cashout::CORE_DEF(bet_id) \
		 $::core::bet::cashout::CORE_DEF(cashout_amount) \
		 $::core::bet::cashout::CORE_DEF(source) \
		 $::core::bet::cashout::CORE_DEF(cashout_type,opt) \
		 $::core::bet::cashout::CORE_DEF(admin_user_id,opt) \
		 $::core::bet::cashout::CORE_DEF(cashout_info,opt) \
		 $::core::bet::cashout::CORE_DEF(transactional,opt) \
		 $::core::bet::cashout::CORE_DEF(ipaddr,opt) \
		 $::core::bet::cashout::CORE_DEF(error_overrides,opt) \
		 $::core::bet::cashout::CORE_DEF(joint_account_id,opt) \
		 $::core::bet::cashout::CORE_DEF(cust_id,opt) \
	]

##
# @brief   Filter a list of bet IDs down to only those which have cashout available
#
# @return
#          bet_ids
#             A list containing the bet IDS that can be cashed out.
#
#          overridden_errors
#             An optional list containing the overriden errors
#
#          filtered_bets
#             An optional list with the filtered out bet IDS
#
core::args::register \
	-interface     core::bet::cashout::filter_cashout_bets \
	-desc          {Filter a list of bet IDs down to only those which have cashout available} \
	-errors        [list \
		DB_ERROR \
	] \
	-return_data   [list \
		$::core::bet::cashout::CORE_DEF(bet_ids) \
		$::core::bet::cashout::CORE_DEF(overridden_errors,opt) \
		[list -arg -filtered_bets -mand 0 -check LIST -desc {List containing the list of Bet filtered out and the reason why the bet was filtered out.}] \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(bet_ids) \
		$::core::bet::cashout::CORE_DEF(source) \
		$::core::bet::cashout::CORE_DEF(admin_user_id,opt) \
		$::core::bet::cashout::CORE_DEF(error_overrides,opt) \
		$::core::bet::cashout::CORE_DEF(max_num,opt) \
	]

##
# @brief   Take a bet from the bet packages and figure out whether it qualifies for cashout
#
# @return
#          can_cashout_bet
#              Whether the bet can be cashed out excluding customer specific checks,
#              hierarchy specific checks and any other checks whose results might change at a later date.
#
#          overridden_errors
#              An optional list containing the overriden errors
#
core::args::register \
	-interface     core::bet::cashout::can_cashout_bet \
	-desc          {Take a bet from the bet packages and figure out whether it could qualify for cashout.} \
	-errors        $::core::bet::cashout::CORE_DEF(errors) \
	-return_data   [list \
		[list -arg -can_cashout_bet -mand  1  -check BOOL  -desc {Whether the bet could qualify for cashout.}] \
		$::core::bet::cashout::CORE_DEF(overridden_errors,opt) \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(bet_reference) \
		$::core::bet::cashout::CORE_DEF(reference_type) \
		$::core::bet::cashout::CORE_DEF(bet_type) \
		$::core::bet::cashout::CORE_DEF(source) \
		$::core::bet::cashout::CORE_DEF(error_overrides,opt) \
	]

##
# @brief   Calculates the cashout value for a given bet. Assumes the bet is available for cashout.
#
# @return
#          offer_amount
#             The cashout amount (in the customer's currency). It is the amount we are offering
#             to the customer if they want proceed with cashing out.
#
#          cashout_price
#             (odds at bet placement) divided by (odds at cashout time)
#
#          charge_amount
#             The amount charged for cashing out (in the customer's currency)
#
#          current_odds
#             The odds at cashout time
#
core::args::register \
	-interface     core::bet::cashout::get_cashout_amount \
	-desc          {Calculates the cashout value for a given bet. Assumes the bet is available for cashout.} \
	-errors        [list \
		CASHOUT_BET_NOT_LOADED \
	] \
	-return_data   [list \
		[list -arg -offer_amount  -mand 1 -check UDECIMAL -desc {the amount we are offering}] \
		[list -arg -cashout_price -mand 0 -check UDECIMAL -desc {Cashout price worked out with an OpenBet-customer-specific formula}] \
		[list -arg -charge_amount -mand 0 -check UDECIMAL -desc {Amount charged to the customer for cashing out}] \
		[list -arg -current_odds  -mand 0 -check UDECIMAL -desc {Current odds for bet at cashout time}] \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(bet_id) \
	]

##
# @brief   Returns a value or entire Cashout Pricing Chart by given key in the specified format
#
# @return
#          chart_values
#            A list of Cashout Chart values in the specified format.
#
core::args::register \
	-interface     core::bet::cashout::get_cashout_pricing_chart \
	-desc          {Returns a value or entire Cashout Pricing Chart by given key in the specified format} \
	-errors        [list \
		CASHOUT_CHART_ERROR \
	] \
	-return_data   [list \
		[list -arg -chart_values -mand 1 -check LIST -desc {Cashout Chart values in a specified format}] \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(format,opt) \
	]

##
# @brief   Determine if cashout has been enabled for a particular channel
#
# @return
#          cashout_enabled
#             Whether or not cashout has been enabled.
#
#          overridden_errors
#             An optional list containing the overriden errors
#
core::args::register \
	-interface     core::bet::cashout::is_cashout_enabled \
	-desc          {Determine if cashout has been enabled for a particular channel} \
	-errors        [list \
		CASHOUT_DISABLED \
		CASHOUT_SOURCE_NOT_ALLOWED \
	] \
	-return_data   [list  \
		[list -arg -cashout_enabled -mand 1 -check BOOL -desc {Whether or not cashout has been enabled}] \
		$::core::bet::cashout::CORE_DEF(overridden_errors,opt) \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(source) \
		$::core::bet::cashout::CORE_DEF(error_overrides,opt) \
		[list -arg -bir               -mand 0 -check BOOL  -default 0 -desc {Whether to consider event in-running.}] \
		[list -arg -check_disp_rules  -mand 0 -check BOOL  -default 0 -desc {Whether to include any display related rules.}] \
	]

##
# @brief   Get the list of customers bets which could be cashed out.
#
# @return  [list bet_id1 [list selns] bet_id2 [list selns]]
#
core::args::register \
	-interface     core::bet::cashout::get_unsettled_cashout_bets \
	-desc          {Get the list of customers bets which could be cashed out.} \
	-errors        [list \
		DB_ERROR \
	] \
	-return_data   [list \
		[list -arg -bets -mand 0 -check LIST -default {} -desc {List of bet ids followed by their selections}] \
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(acct_id) \
	]


##
# @brief   Retrieve information related to cashed out bet with a BIR delay.
#
# @return
#
#          bet_id
#             Bet Identifier if the cashed out bet was placed by the betting
#             delay application. If the bet has yet to be placed, returns -1
#
#          bet_delay
#             Delay in second after which the bet will be cashed out. If the
#             bet has been placed, returns 0
#
#          status
#             BIR Cashout status. Allowed values are:
#                  A. BIR Cashout success
#                  P. BIR Cashout pending
#                  F. BIR Cashout failed
#                  C. BIR Cashout price changed
#                  E. Unsupported status
#                  Q. BIR Cashout queued
#          offer_amount
#             New cashout offer if a price change occured
#
core::args::register \
	-interface     core::bet::cashout::get_bir_cashout_info \
	-desc          {Retrieve information related to a cashed out bet with a BIR delay.} \
	-errors        [list \
		CASHOUT_BIR_BET_NOT_LOADED \
		DB_ERROR \
	] \
	-return_data   [list \
		[list -arg -bet_id        -mand 1 -check UINT                      -desc {Bet Id Identifier}] \
		[list -arg -bet_delay     -mand 1 -check UINT                      -desc {Delay in second after which the bet will be cashed out.}] \
		[list -arg -offer_amount  -mand 0 -check UDECIMAL                  -desc {New cashout offer if a price change occured.}] \
		[list -arg -status        -mand 1 -check {EXACT -args {A P F C U Q}} -desc {BIR Cashout status. Allowed values are: \
																					A. BIR Cashout success \
																					P. BIR Cashout pending \
																					F. BIR Cashout failed \
																					C. BIR Cashout price changed \
																					Q. BIR Cashout queued \
																					E. Unsupported status}] \
		[list -arg -reason        -mand 0 -check STRING                    -desc {The failure reason if there is one}]\
	] \
	-args          [list \
		$::core::bet::cashout::CORE_DEF(bir_req_id) \
	]


##
# @brief   Perform tasks after the cashout transaction (which may contain other operations than just cashing out)
#
# @return - Nothing
#
#
core::args::register \
	-interface    core::bet::cashout::post_cashout_tran \
	-desc         {Tasks to perform post cashout transaction} \
	-errors       $::core::bet::cashout::CORE_DEF(errors) \
	-args         [list \
		 $::core::bet::cashout::CORE_DEF(bet_id) \
		 $::core::bet::cashout::CORE_DEF(cashout_amount) \
		 $::core::bet::cashout::CORE_DEF(source) \
		 $::core::bet::cashout::CORE_DEF(cashout_type,opt) \
		 $::core::bet::cashout::CORE_DEF(admin_user_id,opt) \
		 $::core::bet::cashout::CORE_DEF(cashout_info,opt) \
		 $::core::bet::cashout::CORE_DEF(ipaddr,opt) \
		 $::core::bet::cashout::CORE_DEF(error_overrides,opt) \
	]


##
# @brief   Unsettle a cashed out bet
#
# @return - Nothing
#
#
core::args::register \
	-interface    core::bet::cashout::unsettle \
	-desc         {Unsettle cashed out bet} \
	-errors       [list\
		DB_ERROR \
	] \
	-args         [list \
		 $::core::bet::cashout::CORE_DEF(bet_id) \
		 $::core::bet::cashout::CORE_DEF(admin_username,opt) \
		 $::core::bet::cashout::CORE_DEF(transactional,opt) \
	]


##
# @brief   Attempt to (re)settle a cashed out bet according to specific rules.
#          By cashed out bet, we mean a bet that has been cashed out at some point in
#          the past (i.e by definition was settled) but that might have been unsettled.
#
#          Calling this proc will not necessarily result in the bet itself being resettled,
#          depending on the rules attached to cashout resettlement.
#
#
core::args::register \
	-interface    core::bet::cashout::settle \
	-desc         {Attempt to settle cashed out bet} \
	-errors       [list\
		DB_ERROR \
		CASHOUT_BET_SETTLED \
		CASHOUT_CASHOUT_SETTLED \
		CASHOUT_ERROR_REPRICING \
		CASHOUT_BET_NOT_LOADED \
		CASHOUT_NON_EXISTENT \
	] \
	-return_data [list \
		[list -arg -bet_settled    -mand 1 -check BOOL   -desc {Whether the bet itself got settled}]\
		[list -arg -num_lines_win  -mand 0 -check UINT   -desc {Number of win lines the bet was settled at}]\
		[list -arg -num_lines_void -mand 0 -check UINT   -desc {Number of void lines the bet was settled at}]\
		[list -arg -num_lines_lose -mand 0 -check UINT   -desc {Number of lose lines the bet was settled at}]\
		[list -arg -winnings       -mand 0 -check UMONEY -desc {Winnings amount the bet was settled at}]\
		[list -arg -refund         -mand 0 -check UMONEY -desc {Refund amount the bet was settled at}]\
	] \
	-args         [list \
		 $::core::bet::cashout::CORE_DEF(bet_id) \
		 $::core::bet::cashout::CORE_DEF(admin_username,opt) \
		 $::core::bet::cashout::CORE_DEF(cashout_type,opt) \
		 $::core::bet::cashout::CORE_DEF(cashout_info,opt) \
		 $::core::bet::cashout::CORE_DEF(transactional,opt) \
		 $::core::bet::cashout::CORE_DEF(log_only,opt) \
	]
