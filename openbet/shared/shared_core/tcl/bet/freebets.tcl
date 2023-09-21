# Copyright (C) 2013 Orbis Technology Ltd. All Rights Reserved.
#
# Core Freebets intefaces
#
#
set pkg_version 1.0
package provide core::freebets $pkg_version

# Dependencies
package require core::args     1.0

core::args::register_ns \
	-namespace core::freebets \
	-version   $pkg_version \
	-dependent [list \
		core::args \
	] \
	-docs xml/bet/freebets.xml

namespace eval core::freebets {

	variable CORE_DEF

	set CORE_DEF(cust_id)          [list -arg -cust_id          -mand 1 -check UINT            -desc {Customer identifier}]
	set CORE_DEF(source)           [list -arg -source           -mand 1 -check ASCII           -desc {Source / Channel}]
	set CORE_DEF(actions)          [list -arg -actions          -mand 1 -check LIST            -desc {Actions performed to check for triggers}]
	set CORE_DEF(lang)             [list -arg -lang             -mand 1 -check {Az -max_str 2} -desc {The customer's registered language}]
	set CORE_DEF(ccy_code)         [list -arg -ccy_code         -mand 1 -check ASCII           -desc {The customer's account currency}]
	set CORE_DEF(reg_affiliate_id) [list -arg -reg_affiliate_id -mand 1 -check ASCII           -desc {The customer's registered affiliate}]
	set CORE_DEF(country_code)     [list -arg -country_code     -mand 1 -check STRING          -desc {The customer's registered country}]
	set CORE_DEF(voucher_code)     [list -arg -voucher_code     -mand 1 -check ASCII           -desc {Customer's voucher code}]
	set CORE_DEF(promo_code)       [list -arg -promo_code       -mand 1 -check STRING          -desc {Customer's promo code}]
	set CORE_DEF(trigger_id)       [list -arg -trigger_id       -mand 1 -check UINT            -desc {The trigger id that should be called}]

	# Optional arguments (config based)
	set CORE_DEF(offer_cache_time,opt)   [list -arg -offer_cache_time   -mand 0 -check INT    -default_cfg FREEBET_OFFER_TIME -default 300 -desc {Query cache time in seconds}]
	set CORE_DEF(xsys_host_url_base,opt) [list -arg -xsys_host_url_base -mand 0 -check STRING -default_cfg XSYS_HOST_URL_BASE              -desc {External Host URL Base}]
	set CORE_DEF(system_name,opt)        [list -arg -system_name        -mand 0 -check STRING -default_cfg SYSTEM_NAME                     -desc {Identifies parallel system instance type}]

	# Optional arguments
	set CORE_DEF(amount,opt)                      [list -arg -amount                      -mand 0 -check MONEY           -default {} -desc {The payment amount}]
	set CORE_DEF(bet_type,opt)                    [list -arg -bet_type                    -mand 0 -check STRING          -default {} -desc {Type of bet}]
	set CORE_DEF(bet_id,opt)                      [list -arg -bet_id                      -mand 0 -check UINT            -default {} -desc {Bet ID}]
	set CORE_DEF(affiliate_id,opt)                [list -arg -affiliate_id                -mand 0 -check UINT            -default {} -desc {Affiliate ID}]
	set CORE_DEF(affiliate_group_id,opt)          [list -arg -affiliate_group_id          -mand 0 -check UINT            -default {} -desc {Affiliate group ID}]
	set CORE_DEF(ev_oc_ids,opt)                   [list -arg -ev_oc_ids                   -mand 0 -check LIST            -default {} -desc {List of selection IDs}]
	set CORE_DEF(ev_mkt_ids,opt)                  [list -arg -ev_mkt_ids                  -mand 0 -check LIST            -default {} -desc {List of event market IDs}]
	set CORE_DEF(ev_ids,opt)                      [list -arg -ev_ids                      -mand 0 -check LIST            -default {} -desc {List of event IDs}]
	set CORE_DEF(ev_type_ids,opt)                 [list -arg -ev_type_ids                 -mand 0 -check LIST            -default {} -desc {List of event type IDs}]
	set CORE_DEF(ev_class_ids,opt)                [list -arg -ev_class_ids                -mand 0 -check LIST            -default {} -desc {List of event class IDs}]
	set CORE_DEF(trigger_id,opt)                  [list -arg -trigger_id                  -mand 0 -check UINT            -default {} -desc {The trigger id that should be called (OPTIN VOUCHER)}]
	set CORE_DEF(promo_code,opt)                  [list -arg -promo_code                  -mand 0 -check STRING          -default {} -desc {Customer's promo code}]
	set CORE_DEF(type_code,opt)                   [list -arg -type_code                   -mand 0 -check AZ              -default {} -desc {Type of voucher}]
	set CORE_DEF(subscription_id,opt)             [list -arg -subscription_id             -mand 0 -check UINT            -default {} -desc {Subscription ID (tXSysSub)}]
	set CORE_DEF(log_only,opt)                    [list -arg -log_only                    -mand 0 -check BOOL            -default 0  -desc {Perform a dry run without changing anything}]
	set CORE_DEF(redeem_list,opt)                 [list -arg -redeem_list                 -mand 0 -check LIST            -default {} -desc {Used for pre-redeemed matched bet tokens}]
	set CORE_DEF(referer_user_id,opt)             [list -arg -referer_user_id             -mand 0 -check UINT            -default {} -desc {User id of the referer}]
	set CORE_DEF(remote_unique_id,opt)            [list -arg -remote_unique_id            -mand 0 -check STRING          -default {} -desc {Unique id for the remote trigger}]
	set CORE_DEF(external_trigger,opt)            [list -arg -external_trigger            -mand 0 -check UINT            -default {} -desc {External trigger}]
	set CORE_DEF(external_host,opt)               [list -arg -ext_host                    -mand 0 -check ASCII           -default {} -desc {External host}]
	set CORE_DEF(include_future_offers,opt)       [list -arg -include_future_offers       -mand 0 -check BOOL            -default 0  -desc {Include offers which have not yet started}]
	set CORE_DEF(include_ended_offers,opt)        [list -arg -include_ended_offers        -mand 0 -check BOOL            -default 0  -desc {Include offers which have ended}]
	set CORE_DEF(filter_cust_id,opt)              [list -arg -filter_cust_id              -mand 0 -check UINT            -default {} -desc {Only include offers for this cust_id}]
	set CORE_DEF(filter_lang,opt)                 [list -arg -filter_lang                 -mand 0 -check {Az -max_str 2} -default {} -desc {Only include offers for this language}]
	set CORE_DEF(filter_country_code,opt)         [list -arg -filter_country_code         -mand 0 -check STRING          -default {} -desc {Only include offers for this country code}]
	set CORE_DEF(filter_ccy_code,opt)             [list -arg -filter_ccy_code             -mand 0 -check ASCII           -default {} -desc {Only include offers for this currency code}]
	set CORE_DEF(claimed_offers,opt)              [list -arg -claimed_offers              -mand 0 -check LIST            -default {} -desc {List of offers and the number of times they have been claimed}]
	set CORE_DEF(called_triggers,opt)             [list -arg -called_triggers             -mand 0 -check LIST            -default {} -desc {List of triggers and the number of times they have been called}]
	set CORE_DEF(exclude_no_triggers,opt)         [list -arg -exclude_no_triggers         -mand 0 -check BOOL            -default 1  -desc {Exclude offers with no triggers}]
	set CORE_DEF(exclude_qualification,opt)       [list -arg -exclude_qualification       -mand 0 -check BOOL            -default 1  -desc {Exclude offers with qualification requirements}]
	set CORE_DEF(exclude_entry_expired,opt)       [list -arg -exclude_entry_expired       -mand 0 -check BOOL            -default 1  -desc {Exclude expired offers. End date, entry expiry, expired triggers}]
	set CORE_DEF(exclude_max_claims_met,opt)      [list -arg -exclude_max_claims_met      -mand 0 -check BOOL            -default 1  -desc {Exclude include offers that reach their max claims}]
	set CORE_DEF(exclude_uncallable_triggers,opt) [list -arg -exclude_uncallable_triggers -mand 0 -check BOOL            -default 1  -desc {Exclude include offers with uncallable triggers}]
	set CORE_DEF(effective_end_from,opt)          [list -arg -effective_end_from          -mand 0 -check DATETIME        -default {} -desc {Effective end from date for filtering offers}]
	set CORE_DEF(effective_end_to,opt)            [list -arg -effective_end_to            -mand 0 -check DATETIME        -default {} -desc {Effective end to date for filtering offers}]
	set CORE_DEF(include_delayed,opt)             [list -arg -include_delayed             -mand 0 -check BOOL            -default {} -desc {Include delayed tokens}]
	set CORE_DEF(expiry_from,opt)                 [list -arg -expiry_from                 -mand 0 -check DATETIME        -default {} -desc {Expiry from date for filtering available tokens}]
	set CORE_DEF(expiry_to,opt)                   [list -arg -expiry_to                   -mand 0 -check DATETIME        -default {} -desc {Expiry to date for filtering available tokens}]
	set CORE_DEF(redemption_from,opt)             [list -arg -redemption_from             -mand 0 -check DATETIME        -default {} -desc {Redemption from date for filtering redeemed tokens}]
	set CORE_DEF(redemption_to,opt)               [list -arg -redemption_to               -mand 0 -check DATETIME        -default {} -desc {Redemption to date for filtering redeemed tokens}]

	set CORE_DEF(errors)  [list \
		DB_ERROR]
}

# core::freebets::init
#
# Interface for one time initialisation of freebets code
#
core::args::register \
	-interface core::freebets::init \
	-desc      {Initialise freebets code} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(offer_cache_time,opt) \
		$::core::freebets::CORE_DEF(xsys_host_url_base,opt) \
		$::core::freebets::CORE_DEF(system_name,opt) \
	]

# core::freebets::check_action
#
# Interface for checking if an action calls a trigger
#
core::args::register \
	-interface core::freebets::check_action \
	-desc      {Check if an action calls any trigger and claim and offers as appropriate} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(source) \
		$::core::freebets::CORE_DEF(actions) \
		$::core::freebets::CORE_DEF(lang) \
		$::core::freebets::CORE_DEF(ccy_code) \
		$::core::freebets::CORE_DEF(reg_affiliate_id) \
		$::core::freebets::CORE_DEF(country_code) \
		$::core::freebets::CORE_DEF(affiliate_id,opt) \
		$::core::freebets::CORE_DEF(affiliate_group_id,opt) \
		$::core::freebets::CORE_DEF(amount,opt) \
		$::core::freebets::CORE_DEF(bet_type,opt) \
		$::core::freebets::CORE_DEF(bet_id,opt) \
		$::core::freebets::CORE_DEF(ev_oc_ids,opt) \
		$::core::freebets::CORE_DEF(ev_mkt_ids,opt) \
		$::core::freebets::CORE_DEF(ev_ids,opt) \
		$::core::freebets::CORE_DEF(ev_type_ids,opt) \
		$::core::freebets::CORE_DEF(ev_class_ids,opt) \
		$::core::freebets::CORE_DEF(trigger_id,opt) \
		$::core::freebets::CORE_DEF(promo_code,opt) \
		$::core::freebets::CORE_DEF(type_code,opt) \
		$::core::freebets::CORE_DEF(subscription_id,opt) \
		$::core::freebets::CORE_DEF(log_only,opt) \
		$::core::freebets::CORE_DEF(redeem_list,opt) \
		$::core::freebets::CORE_DEF(referer_user_id,opt) \
		$::core::freebets::CORE_DEF(remote_unique_id,opt) \
		$::core::freebets::CORE_DEF(external_trigger,opt) \
		$::core::freebets::CORE_DEF(external_host,opt) \
	]

# core::freebets::redeem_voucher
#
# Interface for checking and redemption of a freebet voucher
#
core::args::register \
	-interface core::freebets::redeem_voucher \
	-desc      {Handles Checking and redeption of a freebet voucher} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(voucher_code) \
	]

# core::freebets::validate_promo
#
# Interface for cheking whether a promotional code is valid
#
core::args::register \
	-interface   core::freebets::validate_promo \
	-desc        {Checks whether a freebet promotional offer is valid} \
	-allow_rpc   1 \
	-errors      $::core::freebets::CORE_DEF(errors) \
	-return_data [list \
		[list -arg -promo_valid -mand 1 -check BOOL -desc {Is the promo code valid}] \
	] \
	-args        [list \
		$::core::freebets::CORE_DEF(promo_code) \
		$::core::freebets::CORE_DEF(source) \
		$::core::freebets::CORE_DEF(lang) \
		$::core::freebets::CORE_DEF(filter_country_code,opt) \
		$::core::freebets::CORE_DEF(filter_ccy_code,opt) \
	]

# core::freebets::redeem_promo
#
# Interface for redeeming a promotional code
#
core::args::register \
	-interface core::freebets::redeem_promo \
	-desc      {Redeems a freebet promotional offer} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(promo_code) \
	]

# core::freebets::call_custgroup_trigger \
#
# Interface for call cust group trigger
#
core::args::register \
	-interface core::freebets::call_custgroup_trigger \
	-desc      {External calls to call cust group trigger} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(trigger_id) \
		$::core::freebets::CORE_DEF(source) \
		$::core::freebets::CORE_DEF(affiliate_id,opt) \
	]

# core::freebets::get_offers
#
# Interface for getting offers
#
core::args::register \
	-interface core::freebets::get_offers \
	-desc      {Get offers in the system} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(include_future_offers,opt) \
		$::core::freebets::CORE_DEF(include_ended_offers,opt) \
		$::core::freebets::CORE_DEF(filter_cust_id,opt) \
		$::core::freebets::CORE_DEF(filter_lang,opt) \
		$::core::freebets::CORE_DEF(filter_country_code,opt) \
		$::core::freebets::CORE_DEF(filter_ccy_code,opt) \
		$::core::freebets::CORE_DEF(claimed_offers,opt) \
		$::core::freebets::CORE_DEF(called_triggers,opt) \
		$::core::freebets::CORE_DEF(exclude_no_triggers,opt) \
		$::core::freebets::CORE_DEF(exclude_qualification,opt) \
		$::core::freebets::CORE_DEF(exclude_entry_expired,opt) \
		$::core::freebets::CORE_DEF(exclude_max_claims_met,opt) \
		$::core::freebets::CORE_DEF(exclude_uncallable_triggers,opt) \
		$::core::freebets::CORE_DEF(effective_end_from,opt) \
		$::core::freebets::CORE_DEF(effective_end_to,opt) \
	]

# core::freebets::get_available_tokens
#
# Interface to get availabel tokens
#
core::args::register \
	-interface core::freebets::get_available_tokens \
	-desc      {Get tokens which are available} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(include_delayed,opt) \
		$::core::freebets::CORE_DEF(expiry_from,opt) \
		$::core::freebets::CORE_DEF(expiry_to,opt) \
	]

# core::freebets::get_redeemed_tokens
#
# Interface for getting redeemed tokens
#
core::args::register \
	-interface core::freebets::get_redeemed_tokens \
	-desc      {Get tokens which have been redeemed by the player} \
	-allow_rpc 1 \
	-args      [list \
		$::core::freebets::CORE_DEF(cust_id) \
		$::core::freebets::CORE_DEF(redemption_from,opt) \
		$::core::freebets::CORE_DEF(redemption_to,opt) \
	]
