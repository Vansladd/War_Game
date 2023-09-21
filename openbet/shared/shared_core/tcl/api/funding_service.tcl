#
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

set pkg_version 1.0
package provide core::api::funding_service $pkg_version

package require core::log           1.0
package require core::util          1.0
package require core::check         1.0
package require core::args          1.0
package require core::gc            1.0
package require core::soap          1.0
package require core::date          1.0

core::args::register_ns \
	-namespace core::api::funding_service \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::date \
		core::soap] \
	-docs xml/api/funding_service.xml

namespace eval ::core::api::funding_service {
	variable CFG
	variable INIT
	variable CORE_DEF

#-----------------------------header elements-----------------------------
	set CORE_DEF(session_token_value,opt)        [list -arg -session_token_value        -mand 0 -check ASCII -desc {session token value}               -default {}]
	set CORE_DEF(client_session_token_value,opt) [list -arg -client_session_token_value -mand 0 -check ASCII -desc {client session token value}        -default {}]
	set CORE_DEF(contexts,opt)                   [list -arg -contexts                   -mand 0 -check LIST  -desc {a list of context <methodName,parameters>} -default [list]]
	set CORE_DEF(service_initiator_id,opt)       [list -arg -service_initiator_id       -mand 0 -check ASCII -desc {service_initiatior_id}             -default {}]
	set CORE_DEF(usersession_token,opt)          [list -arg -usersession_token          -mand 0 -check ASCII -desc {end user session token}            -default {}]
	set CORE_DEF(usersession_lastupdate,opt)     [list -arg -usersession_lastupdate     -mand 0 -check ASCII -desc {end user session last update}      -default {}]
	set CORE_DEF(usersession_expiration,opt)     [list -arg -usersession_expiration     -mand 0 -check ASCII -desc {end user session expiration time}  -default {}]
	set CORE_DEF(usersession_subjects,opt)       [list -arg -usersession_subjects       -mand 0 -check LIST  -desc {a list of end user session subjects <id,name,roles,type>} -default [list]]
#-----------------------------body elements-----------------------------
	set CORE_DEF(fund_expiry_date)          [list -arg -fund_expiry_date       -mand 1 -check DATETIME -desc {Fund expiry date}]
	set CORE_DEF(restriction_id)            [list -arg -restriction_id         -mand 1 -check ASCII -desc {Restriction id Created from the Funding Service}]
	set CORE_DEF(fund_id)                   [list -arg -fund_id                -mand 1 -check ASCII -desc {Fund id of the current system}]
	set CORE_DEF(funding_transaction_id)    [list -arg -funding_transaction_id -mand 1 -check ASCII -desc {Id of particular funding transaction entity}]

	set CORE_DEF(customer_id,opt)           [list -arg -customer_id         -mand 0 -check ASCII -desc {Customer id of the current system, fill and is mandatory if the account parameters are missing}       -default {}]
	set CORE_DEF(customer_id)               [list -arg -customer_id         -mand 1 -check ASCII -desc {Customer id of the current system, fill and is mandatory if the account parameters are missing}       -default {}]
	set CORE_DEF(currency_id,opt)           [list -arg -currency_id         -mand 0 -check ASCII -desc {The currency ISO code, fill only if the customer parameters are defined}                              -default {}]
	set CORE_DEF(currency_id)               [list -arg -currency_id         -mand 1 -check ASCII -desc {The currency ISO code}]
	set CORE_DEF(funding_account_id,opt)    [list -arg -funding_account_id  -mand 0 -check ASCII -desc {Account id of Funding Service system (external), it should be used only by systems that share the DB with the Funding Service, and is mandatory if the customer parameters are missing} -default {}]
	set CORE_DEF(fund_start_date,opt)       [list -arg -fund_start_date     -mand 0 -check DATETIME -desc {Fund start date} -default {}]
	set CORE_DEF(grouping_condition,opt)    [list -arg -grouping_condition  -mand 0 -check ASCII -desc {text string used to provide grouping logic for funds} -default {}]
	set CORE_DEF(return_closed,opt)         [list -arg -return_closed       -mand 0 -check BOOL  -desc {Flag to indicate the closed funds should be returned in the response} -default 0]
	set CORE_DEF(return_restrictions,opt)   [list -arg -return_restrictions -mand 0 -check BOOL  -desc {Flag to indicate whether fund usage restrictions are returned in the response} -default 0]
	set CORE_DEF(activation_status,opt)     [list -arg -activation_status  -mand 0 -check  {ENUM -args {ACTIVE SUSPENDED EXPIRED}}  -desc {Indicates whether a fund is active, supsended or expired on creation} -default {}]
	set CORE_DEF(additional_properties,opt) [list -arg -additional_properties -mand 0 -check ASCII -desc {List of name/vale pairs that will be stored with the fund} -default {}]

	set INIT 0
}

# Initialise the API
core::args::register \
	-proc_name core::api::funding_service::init \
	-desc {Initialise Funding Service} \
	-args [list \
		[list -arg -service_endpoint  -mand 0 -check STRING -default_cfg FUNDING_SERVICE_ENDPOINT                         -desc {the funding service server's url that is providing the API}] \
		[list -arg -api_version       -mand 0 -check ASCII  -default_cfg FUNDING_SERVICE_API_VERSION       -default {1.0} -desc {api version}] \
		[list -arg -channel_id        -mand 0 -check ASCII  -default_cfg FUNDING_SERVICE_CHANNEL_ID        -default {A}   -desc {Channel id of the current system}] \
		[list -arg -system_provider   -mand 0 -check ASCII  -default_cfg FUNDING_SERVICE_SYSTEM_PROVIDER   -default {G}   -desc {Current system provider code}] \
		[list -arg -customer_provider -mand 0 -check ASCII  -default_cfg FUNDING_SERVICE_CUSTOMER_PROVIDER -default {G}   -desc {Current customer provider code}] \
		[list -arg -bet_provider      -mand 0 -check ASCII  -default_cfg FUNDING_SERVICE_BET_PROVIDER      -default {G}   -desc {Current bet provider code}] \
	] \
	-body {
		variable CFG
		variable INIT

		if {$INIT} {
			core::log::write INFO {funding_service already initialised}
			return
		}

		core::log::write INFO {Initialising funding_service...}
		foreach {n v} [array get ARGS] {
			set n   [string trimleft $n -]
			set str [format "%-35s = %s" $n $v]
			core::log::write INFO {funding_service initialised with $str}

			set CFG($n) $v
		}

		set CFG(GET_BALANCE,request_name) {getBalance}
		set CFG(GET_BALANCE,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType {http://schema.products.sportsbook.openbet.com/fundingTypes}]
		set CFG(GET_BALANCE,soap,request_header) {requestHeader}
		set CFG(GET_BALANCE,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_BALANCE,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CREATE_FUND,request_name) {createFund}
		set CFG(CREATE_FUND,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType {http://schema.products.sportsbook.openbet.com/fundingTypes}]
		set CFG(CREATE_FUND,soap,request_header) {requestHeader}
		set CFG(CREATE_FUND,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CREATE_FUND,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CREATE_RESTRICTION,request_name) {createRestriction}
		set CFG(CREATE_RESTRICTION,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(CREATE_RESTRICTION,soap,request_header) {requestHeader}
		set CFG(CREATE_RESTRICTION,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CREATE_RESTRICTION,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CONFIRM_FUNDING,request_name) {confirmFunding}
		set CFG(CONFIRM_FUNDING,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:n2 {http://schema.products.sportsbook.openbet.com/fundingTypes}]
		set CFG(CONFIRM_FUNDING,soap,request_header) {requestHeader}
		set CFG(CONFIRM_FUNDING,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CONFIRM_FUNDING,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(RESERVE_MULTIPLE_FUNDING,request_name) {reserveMultipleFunding}
		set CFG(RESERVE_MULTIPLE_FUNDING,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(RESERVE_MULTIPLE_FUNDING,soap,request_header) {requestHeader}
		set CFG(RESERVE_MULTIPLE_FUNDING,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(RESERVE_MULTIPLE_FUNDING,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(GET_FUND_HISTORY,request_name) {getFundHistory}
		set CFG(GET_FUND_HISTORY,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(GET_FUND_HISTORY,soap,request_header) {requestHeader}
		set CFG(GET_FUND_HISTORY,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_FUND_HISTORY,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CANCEL_FUNDING,request_name) {cancelFunding}
		set CFG(CANCEL_FUNDING,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
		]
		set CFG(CANCEL_FUNDING,soap,request_header) {requestHeader}
		set CFG(CANCEL_FUNDING,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CANCEL_FUNDING,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CANCEL_ACTIVITY,request_name) {cancelActivity}
		set CFG(CANCEL_ACTIVITY,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
		]
		set CFG(CANCEL_ACTIVITY,soap,request_header) {requestHeader}
		set CFG(CANCEL_ACTIVITY,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CANCEL_ACTIVITY,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CANCEL_RESTRICTION,request_name) {cancelRestriction}
		set CFG(CANCEL_RESTRICTION,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(CANCEL_RESTRICTION,soap,request_header) {requestHeader}
		set CFG(CANCEL_RESTRICTION,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CANCEL_RESTRICTION,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(CANCEL_MULTIPLE_RESTRICTION,request_name) {cancelMultipleRestriction}
		set CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_header) {requestHeader}
		set CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CANCEL_MULTIPLE_RESTRICTION,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(GET_FUND_ACCOUNT_HISTORY,request_name) {getFundAccountHistory}
		set CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_header) {requestHeader}
		set CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_FUND_ACCOUNT_HISTORY,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(GET_FUND_ACCOUNT_SUMMARY,request_name) {getFundAccountSummary}
		set CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_header) {requestHeader}
		set CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_FUND_ACCOUNT_SUMMARY,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

        set CFG(MAKE_FUND_PAYMENT,request_name) {makeFundPayment}
		set CFG(MAKE_FUND_PAYMENT,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(MAKE_FUND_PAYMENT,soap,request_header) {requestHeader}
		set CFG(MAKE_FUND_PAYMENT,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(MAKE_FUND_PAYMENT,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]


		set CFG(ACTIVATE_FUND,request_name) {activateFund}
		set CFG(ACTIVATE_FUND,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(ACTIVATE_FUND,soap,request_header) {requestHeader}
		set CFG(ACTIVATE_FUND,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(ACTIVATE_FUND,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(UPDATE_FUND,request_name) {updateFund}
		set CFG(UPDATE_FUND,soap,request_xmlns) [list \
			xmlns                 {http://schema.products.sportsbook.openbet.com/fundingService} \
			xmlns:fundType        {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
		]
		set CFG(UPDATE_FUND,soap,request_header) {requestHeader}
		set CFG(UPDATE_FUND,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(UPDATE_FUND,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/fundingService} \
			n2 {http://schema.products.sportsbook.openbet.com/fundingTypes} \
			n3 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		if {![catch {
			package require core::harness::api::funding_service 1.0
		} msg]} {
			core::harness::api::funding_service::init
		}

		set INIT 1
	}

# getBalance
core::args::register \
	-proc_name core::api::funding_service::get_balance \
	-desc {Retrieve the customer balance} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id,opt) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(funding_account_id,opt) \
		$::core::api::funding_service::CORE_DEF(return_closed,opt) \
		$::core::api::funding_service::CORE_DEF(return_restrictions,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		if {$ARGS(-customer_id) != {}} {
			set customer_attributes [list]
			lappend customer_attributes id $ARGS(-customer_id)
			lappend customer_attributes provider $system_provider
			dict set body_elements externalCustRef $customer_attributes
			dict set body_elements currencyRef [list id $ARGS(-currency_id)]
		}

		if {$ARGS(-funding_account_id) != {}} {
			dict set body_elements fundingAccountRef [list id $ARGS(-funding_account_id)]
		}

		if {$ARGS(-return_closed)} {
			dict set body_elements returnClosed {true}
		}

		if {$ARGS(-return_restrictions)} {
			dict set body_elements returnRestrictions {true}
		}

		dict set body_elements channelRef  [list id $channel_id]
		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_BALANCE,request_name)
		set request_xmlns        $CFG(GET_BALANCE,soap,request_xmlns)
		set request_header       $CFG(GET_BALANCE,soap,request_header)
		set request_header_xmlns $CFG(GET_BALANCE,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# createFund
core::args::register \
	-proc_name core::api::funding_service::create_fund \
	-desc {Create a new fund} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(fund_id) \
		$::core::api::funding_service::CORE_DEF(fund_expiry_date) \
		$::core::api::funding_service::CORE_DEF(restriction_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id,opt) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(funding_account_id,opt) \
		$::core::api::funding_service::CORE_DEF(fund_start_date,opt) \
		$::core::api::funding_service::CORE_DEF(additional_properties,opt) \
		$::core::api::funding_service::CORE_DEF(grouping_condition,opt) \
		$::core::api::funding_service::CORE_DEF(activation_status,opt) \
		[list -arg -cash_fund_balance     -mand 0 -check MONEY          -default {}  -desc {Initial fund value}] \
		[list -arg -bonus_fund_balance    -mand 0 -check MONEY                       -desc {Initial Bonus fund value}] \
		[list -arg -lockedin_fund_balance -mand 0 -check MONEY          -default 0   -desc {Initial Lockedin fund value}] \
		[list -arg -fund_type -mand 0 -check {ENUM -args {WR STANDARD FREESPINS_STANDARD FREESPINS_WR CASH}} -default {WR} -desc {Type of Fund, default is WR (Wagering requirement); use STANDARD if the fund does not have any WR associated, FREESPINS_STANDARD for a non-wagering freespin token or FREESPINS_WR for awagering freespins token}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		core::log::write DEBUG {core::api::funding_service::create_fund called...}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)

		##--------START Preparing input dict body elements------#
		dict set body_elements channelRef [list id $channel_id]

		if {$ARGS(-customer_id) != {} } {
			set customer_attributes [list]
			lappend customer_attributes id $ARGS(-customer_id)
			lappend customer_attributes provider $system_provider
			dict set body_elements externalCustRef $customer_attributes
			dict set body_elements currencyRef [list id $ARGS(-currency_id)]
		}

		if {$ARGS(-funding_account_id) != {}} {
			dict set body_elements fundingAccountRef [list id $ARGS(-funding_account_id)]
		}

		dict set body_elements externalFundRef [list id $ARGS(-fund_id) provider $system_provider]
		dict set body_elements externalRestrictionRef [list id $ARGS(-restriction_id) provider $system_provider]

		if {$ARGS(-fund_start_date) != {}} {
			dict set body_elements fund_start_date $ARGS(-fund_start_date)
		}
		dict set body_elements fund_expiry_date $ARGS(-fund_expiry_date)

		dict set body_elements fund_type [list type $ARGS(-fund_type)]

		if {$ARGS(-activation_status) != {}} {
			dict set body_elements activation_status $ARGS(-activation_status)
		}

		if {$ARGS(-grouping_condition) != {}} {
			dict set body_elements grouping_condition $ARGS(-grouping_condition)
		}

		set funds [list]
		if {$ARGS(-bonus_fund_balance) != 0} {
			if {$ARGS(-fund_type) == {STANDARD} || $ARGS(-fund_type) == {WR}} {
				lappend funds [list type {BONUS} amount $ARGS(-bonus_fund_balance)]
			} else {
				lappend funds [list type {FREESPINS} amount $ARGS(-bonus_fund_balance)]
			}
		}

		if {$ARGS(-cash_fund_balance) != {}} {
			if {$ARGS(-fund_type) == {CASH}} {
				lappend funds [list type CASH amount $ARGS(-cash_fund_balance)]
			}
		}

		if {$ARGS(-lockedin_fund_balance) != 0 } {
			lappend funds [list type {LOCKEDIN} amount $ARGS(-lockedin_fund_balance)]
		}

		dict set body_elements fund_items $funds

		set additional_properties [list]
		foreach prop $ARGS(-additional_properties) {
			foreach {k v} $prop {
				lappend additional_properties [list key $k value $v]
			}
		}

		if {[llength $additional_properties] != 0} {
			dict set body_elements additional_properties $additional_properties
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CREATE_FUND,request_name)
		set request_xmlns        $CFG(CREATE_FUND,soap,request_xmlns)
		set request_header       $CFG(CREATE_FUND,soap,request_header)
		set request_header_xmlns $CFG(CREATE_FUND,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

#createRestriction
core::args::register \
	-proc_name core::api::funding_service::create_restriction \
	-desc {Create a new restriction in the funding service} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id,opt) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(funding_account_id,opt) \
		$::core::api::funding_service::CORE_DEF(restriction_id) \
		[list -arg -usage_restrictions -mand 0 -check LIST -default {} -desc {values that determine what the fund can be redeemed against}] \
		[list -arg -use_bet_tags -mand 0 -check BOOL -default 0 -desc {flags that the list of usage restrictions are bet tag strings}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)

		##--------START Preparing input dict body elements------#
		#Adding channel information
		dict set body_elements channelRef [list id $channel_id]

		#adding customer information
		if {$ARGS(-customer_id) != {}} {
			set customer_attributes [list]
			lappend customer_attributes id $ARGS(-customer_id)
			lappend customer_attributes provider $system_provider
			dict set body_elements externalCustRef $customer_attributes
			# adding currency, if customer id is provider, the currency is mandatory
			dict set body_elements currencyRef [list id $ARGS(-currency_id)]
		}

		if {$ARGS(-funding_account_id) != {}} {
			dict set body_elements fundingAccountRef [list id $ARGS(-funding_account_id)]
		}

		# adding our reference to the new restriction
		dict set body_elements externalRestrictionRef  [list id $ARGS(-restriction_id) provider $system_provider]
		dict set body_elements usageRestrictionDetails $ARGS(-usage_restrictions)
		dict set body_elements betTagGroups $ARGS(-use_bet_tags)

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CREATE_RESTRICTION,request_name)
		set request_xmlns        $CFG(CREATE_RESTRICTION,soap,request_xmlns)
		set request_header       $CFG(CREATE_RESTRICTION,soap,request_header)
		set request_header_xmlns $CFG(CREATE_RESTRICTION,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# confirmFunding
core::args::register \
	-proc_name core::api::funding_service::confirm_funding \
	-desc {Confirm that funds have been reserved} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(funding_transaction_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		set api_version     $CFG(api_version)

		if {!$INIT} {
			core::api::funding_service::init
		}

		##--------START Preparing input dict body elements------#

		dict set body_elements fundingTransactionRef [list id $ARGS(-funding_transaction_id)]

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CONFIRM_FUNDING,request_name)
		set request_xmlns        $CFG(CONFIRM_FUNDING,soap,request_xmlns)
		set request_header       $CFG(CONFIRM_FUNDING,soap,request_header)
		set request_header_xmlns $CFG(CONFIRM_FUNDING,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# reserveMultipleFunding
core::args::register \
	-proc_name core::api::funding_service::reserve_multiple_funding \
	-desc {Reserve funding for multiple activities} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		[list -arg -usage_restrictions     -mand 0 -check LIST -default {} -desc {values that determine what the fund can be redeemed against}] \
		[list -arg -use_bet_tags           -mand 0 -check BOOL -default 0  -desc {flags that the list of usage restrictions are bet tag strings}] \
		$::core::api::funding_service::CORE_DEF(additional_properties,opt) \
		[list -arg -transaction_status     -mand 0 -check {ENUM -args {PENDING COMPLETE}} -default {} -desc {Indicates whether the transaction should be completed or left pending}] \
		[list -arg -include_funds          -mand 0 -check BOOL -default 0 -desc {return fund balance in the response}] \
		[list -arg -activities             -mand 1 -check LIST -desc {A list of dictionaries that represent the activities. An activity should be created using core::api::create_activity}] \
		[list -arg -allow_negative_balance -mand 0 -check BOOL -default 0 -desc {Allow the cash balance to go negative}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version       $CFG(api_version)
		set customer_provider $CFG(customer_provider)
		set bet_provider      $CFG(bet_provider)
		set channel_id        $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		dict set body_elements channelRef [list id $channel_id]

		set customer_attributes [list]
		lappend customer_attributes id $ARGS(-customer_id)
		lappend customer_attributes provider $customer_provider
		dict set body_elements externalCustRef $customer_attributes
		dict set body_elements currencyRef [list id $ARGS(-currency_id)]

		dict set body_elements usageRestrictionDetails $ARGS(-usage_restrictions)
		dict set body_elements betTagGroups $ARGS(-use_bet_tags)

		dict set body_elements transactionStatus       $ARGS(-transaction_status)
		dict set body_elements negativeBalanceOverride $ARGS(-allow_negative_balance)

		if {$ARGS(-include_funds)} {
			dict set body_elements includeFundsBalanceOnResponse "true"
		} else {
			dict set body_elements includeFundsBalanceOnResponse "false"
		}
		dict set body_elements fundingActivityProperties $ARGS(-additional_properties)

		dict set body_elements activities $ARGS(-activities)

		set request_name         $CFG(RESERVE_MULTIPLE_FUNDING,request_name)
		set request_xmlns        $CFG(RESERVE_MULTIPLE_FUNDING,soap,request_xmlns)
		set request_header       $CFG(RESERVE_MULTIPLE_FUNDING,soap,request_header)
		set request_header_xmlns $CFG(RESERVE_MULTIPLE_FUNDING,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]

	}

# getFundHistory
core::args::register \
	-proc_name core::api::funding_service::get_fund_history \
	-desc {Get fund history transaction} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(fund_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		[list -arg -from_date -mand 0 -check DATETIME -default {} -desc {The start date which the history have to be provided}] \
		[list -arg -to_date   -mand 0 -check DATETIME -default {} -desc {The end date which the history have to be provided}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)

		##--------START Preparing input dict body elements------#

		dict set body_elements externalFundRef [list id $ARGS(-fund_id) provider $system_provider]

		if {$ARGS(-from_date) != {}} {
			dict set body_elements fromDate $ARGS(-from_date)
		}

		if {$ARGS(-to_date) != {}} {
			dict set body_elements toDate $ARGS(-to_date)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_FUND_HISTORY,request_name)
		set request_xmlns        $CFG(GET_FUND_HISTORY,soap,request_xmlns)
		set request_header       $CFG(GET_FUND_HISTORY,soap,request_header)
		set request_header_xmlns $CFG(GET_FUND_HISTORY,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# cancelFunding
core::args::register \
	-proc_name core::api::funding_service::cancel_funding \
	-desc {Cancel a fund that has been reserved} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(funding_transaction_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		set api_version     $CFG(api_version)

		if {!$INIT} {
			core::api::funding_service::init
		}

		##--------START Preparing input dict body elements------#

		dict set body_elements fundingTransactionRef [list id $ARGS(-funding_transaction_id)]

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CANCEL_FUNDING,request_name)
		set request_xmlns        $CFG(CANCEL_FUNDING,soap,request_xmlns)
		set request_header       $CFG(CANCEL_FUNDING,soap,request_header)
		set request_header_xmlns $CFG(CANCEL_FUNDING,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# cancelActivity
core::args::register \
	-proc_name core::api::funding_service::cancel_activity \
	-desc {Cancel an activity that has been completed} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		[list -arg -activities -mand 1 -check LIST -desc {A list of cancel activity elements}] \
		[list -arg -description        -mand 0 -check ASCII -default {} -desc {A free text description of the activity}] \
		[list -arg -transaction_type   -mand 0 -check ASCII -default {} -desc {transaction type code for the activity}] \
	] \
	-body {
		variable INIT
		variable CFG

		set api_version     $CFG(api_version)

		if {!$INIT} {
			core::api::funding_service::init
		}

		set bet_provider      $CFG(bet_provider)
		set channel_id        $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		dict set body_elements channelRef         		 [list id $channel_id]
		dict set body_elements activities 				 $ARGS(-activities)
		dict set body_elements provider   				 $bet_provider
		dict set body_elements transactionType           $ARGS(-transaction_type)
		dict set body_elements description               $ARGS(-description)

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CANCEL_ACTIVITY,request_name)
		set request_xmlns        $CFG(CANCEL_ACTIVITY,soap,request_xmlns)
		set request_header       $CFG(CANCEL_ACTIVITY,soap,request_header)
		set request_header_xmlns $CFG(CANCEL_ACTIVITY,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# cancelRestriction
core::args::register \
	-proc_name core::api::funding_service::cancel_restriction \
	-desc {Cancel a restriction} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(restriction_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)

		if {!$INIT} {
			core::api::funding_service::init
		}

		##--------START Preparing input dict body elements------#

		dict set body_elements externalRestrictionRef [list id $ARGS(-restriction_id) provider $system_provider]

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CANCEL_RESTRICTION,request_name)
		set request_xmlns        $CFG(CANCEL_RESTRICTION,soap,request_xmlns)
		set request_header       $CFG(CANCEL_RESTRICTION,soap,request_header)
		set request_header_xmlns $CFG(CANCEL_RESTRICTION,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# canceliMultipleRestriction
core::args::register \
	-proc_name core::api::funding_service::cancel_multiple_restriction \
	-desc {Cancel a restriction} \
	-args [list \
		[list -arg -grouping_condition -mand 1 -check ASCII -desc {text string used to provide grouping logic for funds} -default {}] \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)

		if {!$INIT} {
			core::api::funding_service::init
		}

		##--------START Preparing input dict body elements------#

		dict set body_elements groupingCondition $ARGS(-grouping_condition)

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CANCEL_MULTIPLE_RESTRICTION,request_name)
		set request_xmlns        $CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_xmlns)
		set request_header       $CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_header)
		set request_header_xmlns $CFG(CANCEL_MULTIPLE_RESTRICTION,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}


# getFundAccountHistory
core::args::register \
	-proc_name core::api::funding_service::get_fund_account_history \
	-desc {Retrieve account history} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id,opt) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		[list -arg -from_date         -mand 0 -check DATETIME -default {}   -desc {The start date which the history have to be provided}] \
		[list -arg -to_date           -mand 0 -check DATETIME -default {}   -desc {The end date which the history have to be provided}] \
		[list -arg -activity_types    -mand 0 -check LIST     -default {}   -desc {The activity types to retrieve history for.}] \
		[list -arg -transaction_types -mand 0 -check LIST     -default {}   -desc {The transaction types to retrieve history for}] \
		[list -arg -page_size         -mand 1 -check UINT     -default {}   -desc {Number of results to return}] \
		[list -arg -transaction_id    -mand 0 -check UINT     -default {}   -desc {Start id for page requested}] \
		[list -arg -page_boundary     -mand 0 -check LIST     -default {}   -desc {List of first and last item and respective dates returned}] \
		[list -arg -page_direction    -mand 0 -check ASCII    -default NEXT -desc {NEXT or PREV}] \
	] \
	-body {

		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version       $CFG(api_version)
		set customer_provider $CFG(customer_provider)
		set bet_provider      $CFG(bet_provider)
		set channel_id        $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		dict set body_elements channelRef [list id $channel_id]

		set customer_attributes [list]
		lappend customer_attributes id $ARGS(-customer_id)
		lappend customer_attributes provider $customer_provider
		dict set body_elements externalCustRef $customer_attributes
		# adding currency, if customer id is provider, the currency is mandatory
		dict set body_elements currencyRef [list id $ARGS(-currency_id)]

		dict set body_elements pageSize             $ARGS(-page_size)

		if {$ARGS(-activity_types) != {}} {
			dict set body_elements fundingActivityTypes $ARGS(-activity_types)
		}

		if {$ARGS(-transaction_types) != {}} {
			dict set body_elements transactionTypes $ARGS(-transaction_types)
		}

		if {$ARGS(-from_date) != {}} {
			dict set body_elements fromDate $ARGS(-from_date)
		}

		if {$ARGS(-to_date) != {}} {
			dict set body_elements toDate $ARGS(-to_date)
		}

		if {$ARGS(-transaction_id) != {}} {
			dict set body_elements transactionId $ARGS(-transaction_id)
		}

		if {$ARGS(-page_direction) != {}} {
			dict set body_elements pageDirection $ARGS(-page_direction)
		}

		if {$ARGS(-page_boundary) != {}} {
			dict set body_elements pageBoundary $ARGS(-page_boundary)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_FUND_ACCOUNT_HISTORY,request_name)
		set request_xmlns        $CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_xmlns)
		set request_header       $CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_header)
		set request_header_xmlns $CFG(GET_FUND_ACCOUNT_HISTORY,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# getFundAccountSummary
core::args::register \
	-proc_name core::api::funding_service::get_fund_account_summary \
	-desc {Retrieve account transactions summary} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id) \
		$::core::api::funding_service::CORE_DEF(currency_id) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		[list -arg -from_date            -mand 1 -check DATE -default {}   -desc {The start date which the summary have to be provided}] \
		[list -arg -to_date              -mand 1 -check DATE -default {}   -desc {The end date which the summary have to be provided}] \
		[list -arg -from_time			 -mand 0 -check TIME -default {}   -desc {The start time which the summary have to be provided}] \
		[list -arg -to_time			 	 -mand 0 -check TIME -default {}   -desc {The end time which the summary have to be provided}] \
		[list -arg -transaction_types    -mand 0 -check LIST -default {}   -desc {The transaction types to retrieve history for}] \
	] \
	-body {

		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version       $CFG(api_version)
		set customer_provider $CFG(customer_provider)
		set bet_provider      $CFG(bet_provider)

		##--------START Preparing input dict body elements------#

		set customer_attributes [list]
		lappend customer_attributes id $ARGS(-customer_id)
		lappend customer_attributes provider $customer_provider
		dict set body_elements externalCustRef $customer_attributes
		# adding currency, if customer id is provider, the currency is mandatory
		dict set body_elements currencyRef [list id $ARGS(-currency_id)]

		if {$ARGS(-transaction_types) != {}} {
			dict set body_elements transactionTypes $ARGS(-transaction_types)
		}


		dict set body_elements fromDate $ARGS(-from_date)
		dict set body_elements toDate $ARGS(-to_date)

		if {$ARGS(-from_time) != {}} {
			dict set body_elements fromTime $ARGS(-from_time)
		}
		if {$ARGS(-to_time) != {}} {
			dict set body_elements toTime $ARGS(-to_time)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_FUND_ACCOUNT_SUMMARY,request_name)
		set request_xmlns        $CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_xmlns)
		set request_header       $CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_header)
		set request_header_xmlns $CFG(GET_FUND_ACCOUNT_SUMMARY,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# makeFundPayment
core::args::register \
	-proc_name core::api::funding_service::make_fund_payment \
	-desc {Update the balance of a cash fund} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::funding_service::CORE_DEF(customer_id) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(fund_id) \
		[list -arg -include_funds      -mand 0 -check BOOL  -default 0 -desc {return fund balance in the response}] \
		[list -arg -amount             -mand 1 -check MONEY -desc {Amount to dep/withdraw from the fund}] \
		[list -arg -fund_item_type     -mand 1 -check {ENUM -args {CASH}} -desc {FundItem type of the fund to update}] \
		[list -arg -operation_id       -mand 1 -check ASCII -desc {A reference ID of the operation}] \
		[list -arg -operation_type     -mand 1 -check ASCII -desc {the type of the operation}] \
		[list -arg -activity_id        -mand 1 -check ASCII -desc {A reference ID of the funding activity in the current system}] \
		[list -arg -activity_type      -mand 1 -check {ENUM -args {DEP WITHDRAW MANADJ}} -desc {the type of the funding activity}] \
		[list -arg -activity_provider  -mand 0 -check ASCII -default {} -desc {An identifier of the system the activity has taken place in}] \
		[list -arg -description        -mand 0 -check ASCII -default {} -desc {A free text description of the activity}] \
		[list -arg -transaction_type   -mand 0 -check ASCII -default {} -desc {transaction type code for the activity}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		set api_version       $CFG(api_version)
		set customer_provider $CFG(customer_provider)
		set bet_provider      $CFG(bet_provider)
		set channel_id        $CFG(channel_id)
		set system_provider   $CFG(system_provider)

		set activity_provider $ARGS(-activity_provider)
		if {$ARGS(-activity_provider) == {}} {
			set activity_provider $CFG(system_provider)
		}

		##--------START Preparing input dict body elements------#

		#channelRef
		dict set body_elements channelRef [list id $channel_id]

		#fundingAccount
		set customer_attributes [list]
		lappend customer_attributes id $ARGS(-customer_id)
		lappend customer_attributes provider $customer_provider
		dict set body_elements externalCustRef $customer_attributes
		dict set body_elements currencyRef [list id $ARGS(-currency_id)]

		#fundingActivity
		dict set body_elements externalActivityRef       [list id $ARGS(-activity_id) provider $activity_provider]
		dict set body_elements type                      $ARGS(-activity_type)
		dict set body_elements externalFundRef           [list id $ARGS(-fund_id) provider $system_provider]
		dict set body_elements fundItem                  [list type $ARGS(-fund_item_type) amount $ARGS(-amount)]
		dict set body_elements transactionType           $ARGS(-transaction_type)
		dict set body_elements description               $ARGS(-description)
		dict set body_elements externalOperationRef      [list id $ARGS(-operation_id) provider $customer_provider]
		dict set body_elements operationType             $ARGS(-operation_type)

		set request_name         $CFG(MAKE_FUND_PAYMENT,request_name)
		set request_xmlns        $CFG(MAKE_FUND_PAYMENT,soap,request_xmlns)
		set request_header       $CFG(MAKE_FUND_PAYMENT,soap,request_header)
		set request_header_xmlns $CFG(MAKE_FUND_PAYMENT,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]

	}

# activateFund
core::args::register \
	-proc_name core::api::funding_service::activate_fund \
	-desc {Activate a fund} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(fund_id) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		core::log::write DEBUG {core::api::funding_service::activate_fund called...}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		dict set body_elements externalFundRef [list id $ARGS(-fund_id) provider $system_provider]

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(ACTIVATE_FUND,request_name)
		set request_xmlns        $CFG(ACTIVATE_FUND,soap,request_xmlns)
		set request_header       $CFG(ACTIVATE_FUND,soap,request_header)
		set request_header_xmlns $CFG(ACTIVATE_FUND,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# updateFund
core::args::register \
	-proc_name core::api::funding_service::update_fund \
	-desc {Update a fund} \
	-args [list \
		$::core::api::funding_service::CORE_DEF(fund_id) \
		$::core::api::funding_service::CORE_DEF(customer_id) \
		$::core::api::funding_service::CORE_DEF(currency_id,opt) \
		$::core::api::funding_service::CORE_DEF(session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::funding_service::CORE_DEF(contexts,opt) \
		$::core::api::funding_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_token,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::funding_service::CORE_DEF(usersession_subjects,opt) \
		[list -arg -start_date -mand 0 -check DATETIME -default {}   -desc {The new start date to give to the fund}] \
		[list -arg -end_date   -mand 1 -check DATETIME -default {}   -desc {The new end date to give to the fund}] \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::funding_service::init
		}

		core::log::write DEBUG {core::api::funding_service::update_fund called...}

		set api_version       $CFG(api_version)
		set system_provider   $CFG(system_provider)
		set channel_id        $CFG(channel_id)

		##--------START Preparing input dict body elements------#

		#fundingAccount
		set customer_attributes [list]
		lappend customer_attributes id $ARGS(-customer_id)
		lappend customer_attributes provider $system_provider
		dict set body_elements externalCustRef $customer_attributes
		dict set body_elements currencyRef [list id $ARGS(-currency_id)]

		dict set body_elements externalFundRef [list id $ARGS(-fund_id) provider $system_provider]
		dict set body_elements newExpiryDate $ARGS(-end_date)
		if {$ARGS(-start_date) != {}} {
			dict set body_elements newStartDate  $ARGS(-start_date)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(UPDATE_FUND,request_name)
		set request_xmlns        $CFG(UPDATE_FUND,soap,request_xmlns)
		set request_header       $CFG(UPDATE_FUND,soap,request_header)
		set request_header_xmlns $CFG(UPDATE_FUND,soap,request_header_xmlns)

		if {$request_xmlns != {} } {
			dict set body_elements request_xmlns $request_xmlns
		}

		return [_send_soap_request \
			$body_elements \
			$request_name \
			$api_version \
			$request_header \
			$request_header_xmlns \
			$ARGS(-session_token_value) \
			$ARGS(-client_session_token_value) \
			$ARGS(-contexts) \
			$ARGS(-service_initiator_id) \
			$ARGS(-usersession_token) \
			$ARGS(-usersession_lastupdate) \
			$ARGS(-usersession_expiration) \
			$ARGS(-usersession_subjects) \
		]
	}

# Build a new activity dictionary
core::args::register \
	-proc_name core::api::funding_service::create_activity \
	-desc {Create an activity for use in reserve multiple funding} \
	-args [list \
		[list -arg -activity_id        -mand 1 -check ASCII                                       -desc {A reference ID of the funding activity in the current system}] \
		[list -arg -activity_provider  -mand 1 -check ASCII                                       -desc {An identifier of the system the activity has taken place in}] \
		[list -arg -activity_amount    -mand 1 -check MONEY                                       -desc {The amount of the funding activity}] \
		[list -arg -operations         -mand 1 -check LIST                                        -desc {a list of ID of the current system for the operations in the funding activity}] \
		[list -arg -operation_provider -mand 1 -check ASCII                                       -desc {An identifier of the system the operation took place in}] \
		[list -arg -activity_type      -mand 1 -check {ENUM -args {DEBIT STAKE PAYOUT BET_STAKE}} -desc {the type of the funding activity}] \
		[list -arg -usage_restrictions -mand 0 -check LIST  -default {}                           -desc {Activity specific usage restriction}] \
		[list -arg -use_bet_tags       -mand 0 -check BOOL  -default 0                            -desc {flags that the list of usage restrictions are bet tag strings}] \
		[list -arg -use_cash_only      -mand 0 -check BOOL  -default 0                            -desc {flags that indicates automated freebet redemption should be disabled.}] \
		[list -arg -fund_id            -mand 0 -check ASCII -default {}                           -desc {freebet token id}] \
		[list -arg -description        -mand 0 -check ASCII -default {}                           -desc {A free text description of the activity}] \
		[list -arg -transaction_type   -mand 0 -check ASCII -default {}                           -desc {transaction type code for the activity}] \
	] \
	-body {
		dict set activity externalActivityRef      [list id $ARGS(-activity_id) provider $ARGS(-activity_provider)]
		dict set activity type                     $ARGS(-activity_type)
		dict set activity amount                   $ARGS(-activity_amount)
		dict set activity fundingOperations        $ARGS(-operations)
		dict set activity fundingOperationProvider $ARGS(-operation_provider)
		dict set activity usageRestrictionDetails  $ARGS(-usage_restrictions)
		dict set activity betTagGroups             $ARGS(-use_bet_tags)
		dict set activity useCashFunds             $ARGS(-use_cash_only)
		dict set activity description              $ARGS(-description)
		dict set activity transactionType          $ARGS(-transaction_type)

		if {$ARGS(-fund_id) != {}} {
			dict set activity externalFundRef [list id $ARGS(-fund_id) provider $ARGS(-activity_provider)]
		} else {
			dict set activity externalFundRef {}
		}

		return $activity
	}

# Build a new cancel activity dictionary
core::args::register \
	-proc_name core::api::funding_service::create_cancel_activity \
	-desc {Reserve funding for multiple activities} \
	-args [list \
		[list -arg -activity_id        -mand 1 -check ASCII -desc {A reference ID to the cancellation activity}] \
		[list -arg -target_activity_id -mand 1 -check ASCII -desc {A reference ID of the funding activity in the current system}] \
	] \
	-body {

		dict set activity activity_id        $ARGS(-activity_id)
		dict set activity target_activity_id $ARGS(-target_activity_id)

		return $activity
	}



### Private procedure START ###
proc core::api::funding_service::_send_soap_request {
	body_elements
	request
	{api_version {}}
	{request_header {requestHeader}}
	{request_header_xmlns {http://schema.core.sportsbook.openbet.com/requestHeader}}
	{session_token_value {}}
	{client_session_token_value {}}
	{contexts {}}
	{service_initiator_id {}}
	{usersession_token {}}
	{usersession_lastupdate {}}
	{usersession_expiration {}}
	{usersession_subjects {}}
} {
	variable CFG

	set fn {core::api::funding_service::_send_soap_request }
	set request_endpoint $CFG(service_endpoint)
	set envelope_name "fundingservice.$request"

	# Build the SOAP XML for the request
	_build_request \
		$envelope_name \
		$body_elements \
		$request \
		$api_version \
		$request_header \
		$request_header_xmlns \
		$session_token_value \
		$client_session_token_value\
		$contexts \
		$service_initiator_id \
		$usersession_token \
		$usersession_lastupdate \
		$usersession_expiration \
		$usersession_subjects

	# Log the message type and endpoint
	core::log::write INFO {$fn - Sending request: -endpoint $request_endpoint -name $request}

	core::log::write DEBUG {$fn: request: [core::soap::print_soap -name $envelope_name -type "request"]}

	# Send the SOAP to the endpoint
	if {[catch {set ret [core::soap::send -endpoint $request_endpoint -name $envelope_name]} msg]} {
		core::log::write ERROR {$fn: exception thrown from core::soap::send - $msg}
		core::soap::cleanup -name $envelope_name
		error "$fn: core::soap::send failed - $msg" $::errorInfo $::errorCode
	}

	# Clean-up request if failed
	if {[string compare [lindex $ret 0] NOT_OK] == 0} {
		core::log::write ERROR {$fn: core::soap::send failed, cleaning up $request, error: $ret}
		core::soap::cleanup -name $envelope_name
		error "calling core::soap::send failed from $fn"
	}

	core::log::write DEBUG {$fn: response: [core::soap::print_soap -name $envelope_name -type "received"]}
	if {[catch {
		# parse the response with specific handler
		set result [_parse_response_$request $envelope_name]
		if { $result == {} } {
			# failure case - response not recognized
			_validate_error_handling $envelope_name
		}
	} msg]} {
		core::log::write ERROR {Funding service - error parsing response: [core::soap::print_soap -name $envelope_name -type "received"]}
		core::soap::cleanup -name $envelope_name
		error "$fn: funding service - error parsing response: - $msg" $::errorInfo $::errorCode
	} else {
		core::soap::cleanup -name $envelope_name
		core::log::write DEBUG {$fn: returning $result}
		return $result
	}
}

#It read the response and try to find some scenario that we could have that can explain the reason because the request failed,
# in the case we are not recognizing the scenario, we trown a generic parsing error
proc core::api::funding_service::_validate_error_handling envelope_name {

	# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
	set list_params [list \
		status_header_code      {//*[local-name()='responseHeader']/*[local-name()='serviceError']/*[local-name()='code']}   0 {} 1 {} \
		status_header_message   {//*[local-name()='responseHeader']/*[local-name()='serviceError']/*[local-name()='message']} 0 {} 1 {} \
		schema_validation_code  {//*[local-name()='faultcode']}   0 {} 1 {} \
		schema_validation_msg   {//*[local-name()='faultstring']} 0 {} 1 {} \
	]
	set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	foreach param {status_header_code status_header_message schema_validation_code schema_validation_msg} {
		set $param [dict get $generic_result $param]
	}
	# Schema Validation error?
	if {$schema_validation_code != {} && $schema_validation_msg != {}} {
		error "Error parsing response funding service $schema_validation_msg" {} $schema_validation_code
	} else {
		# Do we have a code and message in the common responseHeader?
		if {$status_header_code != {} && $status_header_message != {}} {
			error "Error parsing response funding service $status_header_message" {} $status_header_code
		} else {
			# Generic error during the parsing.
			error "Error parsing response funding service" {} GENERIC_PARSING_ERROR
		}
	}
}

## SPECIFIC RESPONSE PARSER Section###
# response parser for get_balance
proc core::api::funding_service::_parse_response_getBalance envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_getBalance }

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_BALANCE,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:getBalanceResponse/n1:status/@code}] 1]

	set result {}
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets {//n1:getBalanceResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			funds   {//n1:getBalanceResponse/n1:funds/n2:fund}     0 {} 1 [list \
				id                   {/n2:externalFundRef/@id}              1 {} 0 {} \
				provider             {/n2:externalFundRef/@provider}        1 {} 0 {} \
				restriction_id       {/n2:externalRestrictionRef/@id}       1 {} 0 {} \
				restriction_provider {/n2:externalRestrictionRef/@provider} 1 {} 0 {} \
				type                 {/n2:type}                             0 {} 0 {} \
				status               {/n2:status}                           0 {} 0 {} \
				create_date          {/n2:createDate}                       0 {} 0 {} \
				start_date           {/n2:startDate}                        0 {} 0 {} \
				expiry_date          {/n2:expiryDate}                       0 {} 0 {} \
				activation_status    {/n2:activationStatus}                 0 {} 0 {} \
				grouping_condition   {/n2:groupingCondition}                0 {} 0 {} \
				fund_items           {/n2:fundItems/n2:fundItem}            0 {} 1 [list \
					type            {/n2:type}           0 {} 0 {} \
					balance         {/n2:balance}        0 {} 0 {} \
					initial_balance {/n2:initialBalance} 0 {} 0 {} \
				] \
				additionalProperties {/n2:additionalProperties/n2:additionalProperty} 0 {} 1 [list \
						key {/@key} 1 {} 0 {} \
						value {/@value} 1 {} 0 {} \
				] \
				betTagGroups {/n2:usageRestrictionDetails/n2:betTagGroups} 0 {} 1 [list \
					betTagGroup {/n2:betTagGroup} 0 {} 1 [list \
						betTag {/n2:betTag} 0 {} 1 [list \
							tag {/.} 0 {} 0 {} \
						]\
					] \
				] \
				gameGroups {/n2:usageRestrictionDetails/n2:gameGroups} 0 {} 1 [list \
					gameGroup {/n2:gameGroup} 0 {} 1 [list \
						group {/.} 0 {} 0 {} \
					]\
				] \
			]\
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]
			}

			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		set funds [list]
		foreach fund [dict get $generic_result funds] {
			set current_fund {}
			foreach param {id provider restriction_id restriction_provider type status create_date start_date expiry_date activation_status grouping_condition} {
				set value [dict get $fund $param]
				if {$param in [list create_date start_date expiry_date] && $value != {} } {
					set value [core::date::format_xml_date -date $value]
				}
				dict set current_fund $param $value
			}

			set items [list]
			foreach fund_item [dict get $fund fund_items] {
				set current_fund_item {}
				foreach param [list type balance initial_balance] {
					set value [dict get $fund_item $param]
					dict set current_fund_item $param $value
				}
				lappend items $current_fund_item
			}

			dict set current_fund {items} $items

			foreach property [dict get $fund additionalProperties] {
				dict set current_fund [dict get $property key] [dict get $property value]
			}

			set bet_tag_groups     [dict get $fund betTagGroups]
			set bet_tag_groups_res [list]
			if {$bet_tag_groups != {}} {
				foreach group $bet_tag_groups {
					set group_tags [list]
					set tag_group [dict get $group betTagGroup]
					foreach tag_list $tag_group {
						set tags [dict get $tag_list betTag]
						foreach tag $tags {
							lappend group_tags [dict get $tag tag]
						}
						lappend bet_tag_groups_res $group_tags
					}
				}
			}
			dict set current_fund {bet_tag_groups} $bet_tag_groups_res


			set game_groups     [dict get $fund gameGroups]
			set game_groups_res [list]
			if {$game_groups != {}} {
				foreach group $game_groups {
					set game_group [dict get $group gameGroup]
					foreach gg $game_group {
						lappend game_groups_res [dict get $gg group]
					}
				}
			}
			dict set current_fund {game_groups} $game_groups_res

			lappend funds $current_fund
		}
		dict set result funds $funds
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:getBalanceResponse/n1:status/@subcode} \
			{//n1:getBalanceResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}

	return $result
}

# response parser for create_fund
proc core::api::funding_service::_parse_response_createFund envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_createFund }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CREATE_FUND,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:createFundResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets              {//n1:createFundResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			id                   {//n1:createFundResponse/n1:fund/n2:externalFundRef/@id}              1 {} 0 {} \
			provider             {//n1:createFundResponse/n1:fund/n2:externalFundRef/@provider}        1 {} 0 {} \
			restriction_id       {//n1:createFundResponse/n1:fund/n2:externalRestrictionRef/@id}       1 {} 0 {} \
			restriction_provider {//n1:createFundResponse/n1:fund/n2:externalRestrictionRef/@provider} 1 {} 0 {} \
			type                 {//n1:createFundResponse/n1:fund/n2:type}                             0 {} 0 {} \
			status               {//n1:createFundResponse/n1:fund/n2:status}                           0 {} 0 {} \
			create_date          {//n1:createFundResponse/n1:fund/n2:createDate}                       0 {} 0 {} \
			start_date           {//n1:createFundResponse/n1:fund/n2:startDate}                        0 {} 0 {} \
			expiry_date          {//n1:createFundResponse/n1:fund/n2:expiryDate}                       0 {} 0 {} \
			fund_items           {//n1:createFundResponse/n1:fund/n2:fundItems/n2:fundItem}            0 {} 1 [list \
				type            {/n2:type}           0 {} 0 {} \
				balance         {/n2:balance}        0 {} 0 {} \
				initial_balance {/n2:initialBalance} 0 {} 0 {} \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		foreach param {id provider restriction_id restriction_provider type status create_date start_date expiry_date } {
			set value [dict get $generic_result $param]
			if {$param in [list create_date start_date expiry_date] && $value != {} } {
				set value [core::date::format_xml_date -date $value]
			}
			dict set fund_created $param $value
		}

		set items [list]
		foreach fund_item [dict get $generic_result fund_items] {
			set current_fund_item {}
			foreach param [list type balance initial_balance] {
				set value [dict get $fund_item $param]
				dict set current_fund_item $param $value
			}
			lappend items $current_fund_item
		}
		dict set fund_created {items} $items

		dict set result fund_created $fund_created
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:createFundResponse/n1:status/@subcode} \
			{//n1:createFundResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for create_restriction
proc core::api::funding_service::_parse_response_createRestriction envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_createRestriction }

	set result {}
	#setting namespaces in the response envelope
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CREATE_RESTRICTION,response_namespaces)

	#checking the status of the response
	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:createRestrictionResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		#retrieving information on the id and the status
		foreach {param xpath is_attribute} {
			restriction_status   {//n1:createRestrictionResponse/n1:restriction/n2:status} 0
			restriction_id       {//n1:createRestrictionResponse/n1:restriction/n2:externalRestrictionRef/@id} 1
			restriction_provider {//n1:createRestrictionResponse/n1:restriction/n2:externalRestrictionRef/@provider} 1
		} {
			if {$is_attribute} {
				set $param [lindex [core::soap::get_attributes \
					-name $envelope_name \
					-xpath $xpath] 1]
			} else {
				set $param [lindex [core::soap::get_element \
					-name $envelope_name \
					-xpath $xpath] 0]
			}
		}

		dict set result id       $restriction_id
		dict set result provider $restriction_provider
		dict set result status   $restriction_status
	} elseif {$status_body != {}} {
		# failed so try to read the subcode and specification
		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:createRestrictionResponse/n1:status/@subcode} \
			{//n1:createRestrictionResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for confirm_funding
proc core::api::funding_service::_parse_response_confirmFunding envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_confirmFunding }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CONFIRM_FUNDING,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:confirmFundingResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets               {//n1:confirmFundingResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			fundingTransaction   {//n1:confirmFundingResponse/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		dict set result fundingTransaction [dict get $generic_result fundingTransaction]
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:confirmFundingResponse/n1:status/@subcode} \
			{//n1:confirmFundingResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for get_fund_history
proc core::api::funding_service::_parse_response_getFundHistory envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_getFundHistory }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_FUND_HISTORY,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:getFundHistoryResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			fund_id            {//n1:getFundHistoryResponse/n1:fund/n2:externalFundRef/@id} 1 {} 0 {} \
			fund_provider      {//n1:getFundHistoryResponse/n1:fund/n2:externalFundRef/@provider} 1 {} 0 {} \
			transactions {//n1:getFundHistoryResponse/n1:transactions/n2:transaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
				transaction_date       {/n2:transactionDate} 0 {} 0 {} \
				fund_activity_id       {/n2:fundingActivity/n2:externalActivityRef/@id} 1 {} 0 {} \
				fund_activity_provider {/n2:fundingActivity/n2:externalActivityRef/@provider} 1 {} 0 {} \
				fund_activity_type     {/n2:fundingActivity/n2:type} 0 {} 0 {} \
				funding_operations     {/n2:fundingActivity/n2:fundingOperations//n2:externalOperationRef} 0 {} 1 [list \
					operation_id       {/@id} 1 {} 0 {} \
					operation_provider {/@provider} 1 {} 0 {} \
				]\
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		set transactions [list]
		foreach transaction [dict get $generic_result transactions] {
			set date [dict get $transaction transaction_date]
			if {$date != {} } {
				set date [core::date::format_xml_date -date $date]
				dict set transaction transaction_date $date
			}
			lappend transactions $transaction
		}
		dict set result fund_requested id       [dict get $generic_result fund_id]
		dict set result fund_requested provider [dict get $generic_result fund_provider]
		dict set result transactions $transactions

	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:getFundHistoryResponse/n1:status/@subcode} \
			{//n1:getFundHistoryResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for cancel_funding
proc core::api::funding_service::_parse_response_cancelFunding envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_cancelFunding }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CANCEL_FUNDING,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:cancelFundingResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets               {//n1:cancelFundingResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			fundingTransaction   {//n1:cancelFundingResponse/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		dict set result fundingTransaction [dict get $generic_result fundingTransaction]
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:cancelFundingResponse/n1:status/@subcode} \
			{//n1:cancelFundingResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for cancel_activity
proc core::api::funding_service::_parse_response_cancelActivity envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_cancelActivity }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CANCEL_ACTIVITY,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:cancelActivityResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets               {//n1:cancelActivityResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			fundingTransaction   {//n1:cancelActivityResponse/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		dict set result fundingTransaction [dict get $generic_result fundingTransaction]
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:cancelActivityResponse/n1:status/@subcode} \
			{//n1:cancelActivityResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for cancel_restriction
proc core::api::funding_service::_parse_response_cancelRestriction envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_cancelRestriction}

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CANCEL_RESTRICTION,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:cancelRestrictionResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			fundingTransactions   {//n1:cancelRestrictionResponse/n1:fundingTransactions/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
			] \
		]

		set result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:cancelRestrictionResponse/n1:status/@subcode} \
			{//n1:cancelRestrictionResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for cancel_multiple_restriction
proc core::api::funding_service::_parse_response_cancelMultipleRestriction envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_cancelMultipleRestriction}

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CANCEL_MULTIPLE_RESTRICTION,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:cancelMultipleRestrictionResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}


	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			restrictions {//n1:cancelMultipleRestrictionResponse/n1:restrictions/n2:restriction} 0 {} 1 [list \
				restriction_id {/n2:externalRestrictionRef/@id} 1 {} 0 {} \
				restriction_provider {/n2:externalRestrictionRef/@provider} 1 {} 0 {} \
				status {/n2:status} 0 {} 0 {}
			]
		]

		set result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:cancelMultipleRestrictionResponse/n1:status/@subcode} \
			{//n1:cancelMutipleRestrictionResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for reserve_multiple_funding
proc core::api::funding_service::_parse_response_reserveMultipleFunding envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_reserveMultipleFunding }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(RESERVE_MULTIPLE_FUNDING,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:reserveMultipleFundingResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets               {//n1:reserveMultipleFundingResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			fundingTransaction   {//n1:reserveMultipleFundingResponse/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				transactionFunds            {/n2:transactionFunds/n2:transactionFund} 0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n2:type}   0 {} 0 {} \
						transaction_amount {/n2:amount} 0 {} 0 {} \
					] \
				] \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		dict set result fundingTransaction [dict get $generic_result fundingTransaction]
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:reserveMultipleFundingResponse/n1:status/@subcode} \
			{//n1:reserveMultipleFundingResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for get_fund_account_history
proc core::api::funding_service::_parse_response_getFundAccountHistory envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_getFundAccountHistory }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_FUND_ACCOUNT_HISTORY,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:getFundAccountHistoryResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			transactions {//n1:getFundAccountHistoryResponse/n1:transactions/n3:transaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				wallets {//n3:wallets/n3:wallet}        0 {} 1 [list \
					walletType           {/n3:walletType}       0 {}     0 {} \
					totalBalance         {/n3:totalBalance}     0 {0.00} 0 {} \
				] \
				transactionFunds       {/n3:transactionFunds/n3:transactionFund}         0 {} 1 [list \
					fund_id              {/n3:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n3:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n3:transactionFundItems/n3:transactionFundItem} 0 {} 1 [list \
						transaction_type   {/n3:type}   0 {} 0 {} \
						transaction_amount {/n3:amount} 0 {} 0 {} \
					] \
				] \
				transaction_date       {/n3:creationDate}                                               0 {} 0 {} \
				transaction_type       {/n3:transactionType}                                               0 {} 0 {} \
				description            {/n3:description}                                                   0 {} 0 {} \
				fund_activity_id       {/n3:fundingActivity/n3:externalActivityRef/@id}                    1 {} 0 {} \
				fund_activity_provider {/n3:fundingActivity/n3:externalActivityRef/@provider}              1 {} 0 {} \
				fund_activity_type     {/n3:fundingActivity/n3:type}                                       0 {} 0 {} \
				funding_operations     {/n3:fundingActivity/n3:fundingOperations}                          0 {} 1 [list \
					operation_id           {//n3:externalOperationRef/@id}       1 {} 0 {} \
					operation_provider     {//n3:externalOperationRef/@provider} 1 {} 0 {} \
					funding_operation_type {//n3:operationType}                  0 {} 0 {} \
				]\
			] \
			has_next {//n1:getFundAccountHistoryResponse/n1:hasNext} 0 "false" 0 {} \
			has_prev {//n1:getFundAccountHistoryResponse/n1:hasPrev} 0 "false" 0 {} \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		set transactions [list]
		foreach transaction [dict get $generic_result transactions] {
			set date [dict get $transaction transaction_date]
			if {$date != {} } {
				set date [core::date::format_xml_date -date $date]
				dict set transaction transaction_date $date
			}
			#dict set transaction id [dict get $transaction transaction_id]
			#dict unset transaction transaction_id
			lappend transactions $transaction
		}
		#dict set result fund_requested id       [dict get $generic_result fund_id]
		#dict set result fund_requested provider [dict get $generic_result fund_provider]
		dict set result transactions $transactions
		set has_next [dict get $generic_result has_next]
		set has_prev [dict get $generic_result has_prev]
		dict set result has_next [expr {$has_next == "false" ? 0 : 1}]
		dict set result has_prev [expr {$has_prev == "false" ? 0 : 1}]

	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:getFundAccountHistoryResponse/n1:status/@subcode} \
			{//n1:getFundAccountHistoryResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}

	return $result

}

# response parser for get_fund_account_summary
proc core::api::funding_service::_parse_response_getFundAccountSummary envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_getFundAccountSummary }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_FUND_ACCOUNT_SUMMARY,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:getFundAccountSummaryResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			summaries {//n1:getFundAccountSummaryResponse/n1:summaries/n3:summary} 0 {} 1 [list \
				transaction_type  {/n3:transactionType}   0 {}     0 {} \
				operation_type    {/n3:operationType}     0 {}     0 {} \
				amount            {/n3:amount}            0 {0.00} 0 {} \
				transaction_count {/n3:transactionCount}  0 {0}    0 {} \
				from_date         {/n3:fromDate}          0 {}     0 {} \
				to_date           {/n3:toDate}            0 {}     0 {} \
				from_time         {/n3:fromTime}          0 {}     0 {} \
				to_time           {/n3:toTime}            0 {}     0 {} \
			]\
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		set summaries [list]
		foreach summary [dict get $generic_result summaries] {
			set date [dict get $summary from_date]
			if {$date != {} } {
				dict set summary from_date $date
			}

			set date [dict get $summary to_date]
			if {$date != {} } {
				dict set summary to_date $date
			}

			set time [dict get $summary from_time]
			if {$time != {} } {
				dict set summary from_time $time
			}

			set time [dict get $summary to_time]
			if {$time != {} } {
				dict set summary to_time $time
			}

			lappend summaries $summary
		}

		dict set result summaries $summaries

	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:getFundAccountSummaryResponse/n1:status/@subcode} \
			{//n1:getFundAccountSummaryResponse/n1:status/n2:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}

	return $result

}

# response parser for make Fund Payment
proc core::api::funding_service::_parse_response_makeFundPayment envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_makeFundPayment }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(MAKE_FUND_PAYMENT,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:makeFundPaymentResponse/n1:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wallets               {//n1:makeFundPaymentResponse/n1:wallets/n2:wallet} 0 {} 1 [list \
				walletType         {/n2:walletType}       0 {}     0 {} \
				totalBalance       {/n2:totalBalance}     0 {0.00} 0 {} \
				num_funds_open     {/n2:openItemsCount}   0 {0}    0 {} \
				totalRedeemed      {/n2:totalRedeemed}    0 {0.00} 0 {} \
				num_funds_redeemed {/n2:closedItemsCount} 0 {0}    0 {} \
			] \
			fundingTransaction   {//n1:makeFundPaymentResponse/n1:fundingTransaction} 0 {} 1 [list \
				transaction_id              {/@id}                                    1 {} 0 {} \
				transaction_amount          {/@amount}                                1 {} 0 {} \
				transaction_requestedAmount {/@requestedAmount}                       1 {} 0 {} \
				transaction_status          {/@status}                                1 {} 0 {} \
				externalActivityRef         {/n2:externalActivityRef}                 0 {} 1 [list \
					activity_id                 {/@id}			                      1 {} 0 {} \
					activity_provider           {/@provider}                          1 {} 0 {} \
				]\
				transactionFunds         {/n2:transactionFunds/n2:transactionFund}         0 {} 1 [list \
					fund_id              {/n2:externalFundRef/@id}                         1 {} 0 {} \
					fund_provider        {/n2:externalFundRef/@provider}                   1 {} 0 {} \
					transactionFundItems {/n2:transactionFundItems/n2:transactionFundItem} 0 {} 1 [list \
						forfeited		   {/@forfeited} 								   1 {} 0 {} \
						fund_item_type   {/n2:type}                                      0 {} 0 {} \
						fund_item_amount {/n2:amount}                                    0 {} 0 {} \
					] \
				] \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wallet [dict get $generic_result wallets] {

			foreach param [list walletType totalBalance num_funds_open totalRedeemed num_funds_redeemed] {
				set $param [dict get $wallet $param]

			}
			dict set result $walletType balance            $totalBalance
			dict set result $walletType redeemed           $totalRedeemed
			dict set result $walletType num_funds_open     $num_funds_open
			dict set result $walletType num_funds_redeemed $num_funds_redeemed
		}

		dict set result fundingTransaction [dict get $generic_result fundingTransaction]
	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:makeFundPaymentResponse/n1:status/@subcode} \
			{//n1:makeFundPaymentResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}

	return $result
}


# response parser for activate_fund
proc core::api::funding_service::_parse_response_activateFund envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_activateFund }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(ACTIVATE_FUND,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:activateFundResponse/n1:status/@code}] 1]

	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			fund_id              {//n1:activateFundResponse/n1:fund/n2:externalFundRef/@id}              1 {} 0 {} \
			fund_provider        {//n1:activateFundResponse/n1:fund/n2:externalFundRef/@provider}        1 {} 0 {} \
			restriction_id       {//n1:activateFundResponse/n1:fund/n2:externalRestrictionRef/@id}       1 {} 0 {} \
			restriction_provider {//n1:activateFundResponse/n1:fund/n2:externalRestrictionRef/@provider} 1 {} 0 {} \
			type                 {//n1:activateFundResponse/n1:fund/n2:type}                             0 {} 0 {} \
			status               {//n1:activateFundResponse/n1:fund/n2:status}                           0 {} 0 {} \
			create_date          {//n1:activateFundResponse/n1:fund/n2:createDate}                       0 {} 0 {} \
			start_date           {//n1:activateFundResponse/n1:fund/n2:startDate}                        0 {} 0 {} \
			expiry_date          {//n1:activateFundResponse/n1:fund/n2:expiryDate}                       0 {} 0 {} \
			activation_status    {//n1:activateFundResponse/n1:fund/n2:activationStatus}                 0 {} 0 {} \
			grouping_condition   {//n1:activateFundResponse/n1:fund/n2:groupingCondition}                0 {} 0 {} \
			fund_items           {//n1:activateFundResponse/n1:fund/n2:fundItems/n2:fundItem}            0 {} 1 [list \
				type            {/n2:type}           0 {} 0 {} \
				balance         {/n2:balance}        0 {} 0 {} \
				initial_balance {/n2:initialBalance} 0 {} 0 {} \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach param {fund_id fund_provider restriction_id restriction_provider type status create_date start_date expiry_date activation_status grouping_condition} {
			set value [dict get $generic_result $param]
			if {$param in [list create_date start_date expiry_date] && $value != {} } {
				set value [core::date::format_xml_date -date $value]
			}
			dict set fund_activated $param $value
		}

		set items [list]
		foreach fund_item [dict get $generic_result fund_items] {
			set current_fund_item {}
			foreach param [list type balance initial_balance] {
				set value [dict get $fund_item $param]
				dict set current_fund_item $param $value
			}
			lappend items $current_fund_item
		}

		dict set fund_activated {items} $items
		dict set result fund_activated $fund_activated


	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:activateFundResponse/n1:status/@subcode} \
			{//n1:activateFundResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

# response parser for activate_fund
proc core::api::funding_service::_parse_response_updateFund envelope_name {
	variable CFG

	set fn {core::api::funding_service::_parse_response_updateFund }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(UPDATE_FUND,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n1:updateFundResponse/n1:status/@code}] 1]

	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			fund_id              {//n1:updateFundResponse/n1:fund/@id}              				   1 {} 0 {} \
			fund_reference_id    {//n1:updateFundResponse/n1:fund/n2:externalFundRef/@id}              1 {} 0 {} \
			fund_provider        {//n1:updateFundResponse/n1:fund/n2:externalFundRef/@provider}        1 {} 0 {} \
			restriction_id       {//n1:updateFundResponse/n1:fund/n2:externalRestrictionRef/@id}       1 {} 0 {} \
			restriction_provider {//n1:updateFundResponse/n1:fund/n2:externalRestrictionRef/@provider} 1 {} 0 {} \
			type                 {//n1:updateFundResponse/n1:fund/n2:type}                             0 {} 0 {} \
			status               {//n1:updateFundResponse/n1:fund/n2:status}                           0 {} 0 {} \
			create_date          {//n1:updateFundResponse/n1:fund/n2:createDate}                       0 {} 0 {} \
			start_date           {//n1:updateFundResponse/n1:fund/n2:startDate}                        0 {} 0 {} \
			expiry_date          {//n1:updateFundResponse/n1:fund/n2:expiryDate}                       0 {} 0 {} \
			activation_status    {//n1:updateFundResponse/n1:fund/n2:activationStatus}                 0 {} 0 {} \
			grouping_condition   {//n1:updateFundResponse/n1:fund/n2:groupingCondition}                0 {} 0 {} \
			fund_items           {//n1:updateFundResponse/n1:fund/n2:fundItems/n2:fundItem}            0 {} 1 [list \
				type            {/n2:type}           0 {} 0 {} \
				balance         {/n2:balance}        0 {} 0 {} \
				initial_balance {/n2:initialBalance} 0 {} 0 {} \
			] \
		]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach param {fund_id fund_reference_id fund_provider restriction_id restriction_provider type status create_date start_date expiry_date activation_status grouping_condition} {
			set value [dict get $generic_result $param]
			if {$param in [list create_date start_date expiry_date] && $value != {} } {
				set value [core::date::format_xml_date -date $value]
			}
			dict set fund_updated $param $value
		}

		set items [list]
		foreach fund_item [dict get $generic_result fund_items] {
			set current_fund_item {}
			foreach param [list type balance initial_balance] {
				set value [dict get $fund_item $param]
				dict set current_fund_item $param $value
			}
			lappend items $current_fund_item
		}

		dict set fund_updated {items} $items
		dict set result fund_updated $fund_updated


	} elseif {$status_body != {}} {

		lassign [core::api::funding_service::_parse_error_info \
			$envelope_name \
			{//n1:updateFundResponse/n1:status/@subcode} \
			{//n1:updateFundResponse/n1:status/n3:specification} \
			$status_body] error_code error_msg
		error $error_msg {} $error_code
	}
	return $result
}

proc core::api::funding_service::_parse_error_info {envelope_name subcode_xpath specification_msg_xpath status_code} {

	foreach {param xpath is_attribute} [subst {
		status_subcode    $subcode_xpath           1
		specification_msg $specification_msg_xpath 0
	}] {
		if {$is_attribute} {
			set $param [lindex [core::soap::get_attributes \
				-name $envelope_name \
				-xpath $xpath] 1]
		} else {
			set $param [lindex [core::soap::get_element \
				-name $envelope_name \
				-xpath $xpath] 0]
		}
	}

	if {$status_subcode == {}} {
		return [list $status_code $specification_msg]
	} else {
		return [list $status_subcode $specification_msg]
	}
}

### BUILD REQUEST CONTROLLER#
proc core::api::funding_service::_build_request {
	envelope_name
	body_elements
	request
	{api_version {}}
	{request_header {requestHeader}}
	{request_header_xmlns {http://schema.core.sportsbook.openbet.com/requestHeader}}
	{session_token_value {}}
	{client_session_token_value {}}
	{contexts {}}
	{service_initiator_id {}}
	{usersession_token {}}
	{usersession_lastupdate {}}
	{usersession_expiration {}}
	{usersession_subjects {}}
} {

	_create_envelope \
		$envelope_name \
		$request_header \
		$request_header_xmlns

	_create_header \
		$envelope_name \
		$api_version \
		$request_header \
		$session_token_value \
		$client_session_token_value\
		$contexts \
		$service_initiator_id \
		$usersession_token \
		$usersession_lastupdate \
		$usersession_expiration \
		$usersession_subjects

	_create_body_$request $envelope_name $request $body_elements

	return [list OK]
}

## SPECIFIC BODY REQUEST

#	<getBalance xmlns="http://schema.products.sportsbook.openbet.com/fundingService"  xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes">
#		<!-- .. -->
#		<externalCustRef id="val" provider="val"/>
#		<currencyRef id="val"/>
#		<!-- or -->
#		<fundingAccountRef id="val"/>
#		<!-- .. -->
#		<channelRef id="val"/>
#		<returnClosed>false</returnClosed>
#		<returnUsageRestrictions>false</returnUsageRestrictions>
#	</getBalance>
# create body for get_balance
proc core::api::funding_service::_create_body_getBalance {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	if {[dict exists $elements externalCustRef]} {

		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {externalCustRef} \
			-attributes [dict get $elements externalCustRef]

		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {currencyRef} \
			-attributes [dict get $elements currencyRef]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fundingAccountRef} \
			-attributes [dict get $elements fundingAccountRef]
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]

	if {[dict exists $elements returnClosed]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {returnClosed} \
			-value [dict get $elements returnClosed]
	}

	if {[dict exists $elements returnRestrictions]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {returnUsageRestrictions} \
			-value [dict get $elements returnRestrictions]
	}
}

# <createFund xmlns="http://schema.products.sportsbook.openbet.com/fundingService" xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes">
#	<channelRef id="A"/>
#	-----
#	<externalCustRef id="?" provider="G"/>
#	<currencyRef id="?"/>
#	or
#	<fundingAccountRef id="?"/>
#	-----
#	<fund type="?">
#		<ns2:externalFundRef id="?" provider="?" />
#		<ns2:externalRestrictionRef id="2" provider="G" />
#		<ns2:startDate>...</ns2:startDate>
#		<ns2:expiryDate>...</ns2:expiryDate>
#		<ns2:fundItems>
#			<ns2:fundItem type="BONUS" amount="50.00" />
#			....
#		</ns2:fundItems>
#	</fund>
# </createFund>
# create body for create_fund
proc core::api::funding_service::_create_body_createFund {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]

	if {[dict exists $elements externalCustRef]} {

		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {externalCustRef} \
			-attributes [dict get $elements externalCustRef]

		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {currencyRef} \
			-attributes [dict get $elements currencyRef]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fundingAccountRef} \
			-attributes [dict get $elements fundingAccountRef]
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fund} \
		-attributes [dict get $elements fund_type]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:externalFundRef} \
		-attributes [dict get $elements externalFundRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:externalRestrictionRef} \
		-attributes [dict get $elements externalRestrictionRef]

	if {[dict exists $elements fund_start_date]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements fund_start_date]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fund} \
			-elem   {fundType:startDate} \
			-value  $date_formatted
	}

	set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements fund_expiry_date]]
	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:expiryDate} \
		-value  $date_formatted

	if {[dict exists $elements activation_status]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fund} \
			-elem   {fundType:activationStatus} \
			-value   [dict get $elements activation_status]
	}

	if {[dict exists $elements grouping_condition]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fund} \
			-elem   {fundType:groupingCondition} \
			-value   [dict get $elements grouping_condition]
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:fundItems}

	set fund_index 0
	foreach fund [dict get $elements fund_items] {
		set fund_label "fundItems.fundItem.$fund_index"

		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:fundItems} \
			-elem   {fundType:fundItem} \
			-label  $fund_label \
			-attributes $fund

		incr fund_index 1
	}

	if {[dict exists $elements additional_properties]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fund} \
			-elem   {fundType:additionalProperties}

		set prop_index 0
		foreach property [dict get $elements additional_properties] {
			set prop_label "additionalProperties.additioanlPropery.$prop_index"

			core::soap::add_element \
				-name   $envelope_name \
				-parent {fundType:additionalProperties} \
				-elem   {fundType:additionalProperty} \
				-label  $prop_label \
				-attributes $property

			incr prop_index 1
		}
	}

}

#	<createRestriction xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#		xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#		xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#		<channelRef id="A"/>
#		<fundingAccount>
#			<!-- .. -->
#			<promoCommonType:externalCustRef id="val" provider="val"/>
#			<promoCommonType:currencyRef id="val"/>
#			<!-- or -->
#			<promoCommonType:fundingAccountRef id="val"/>
#			<!-- .. -->
#		</fundingAccount>
#		<restriction>
#			<fundType:externalRestrictionRef id="myRestriction" provider="G"/>
#			<fundType:usageRestrictionDetails>
#				<fundType:gameGroups>
#					<fundType:gameGroup>1</fundType:gameGroup>
#					<fundType:gameGroup>2</fundType:gameGroup>
#				</fundType:gameGroups>
#			</fundType:usageRestrictionDetails>
#		</restriction>
#	</createRestriction>
# create body for create_restriction
proc core::api::funding_service::_create_body_createRestriction {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	if {[dict exists $elements externalCustRef]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingAccount} \
			-elem   {promoCommonType:externalCustRef} \
			-attributes [dict get $elements externalCustRef]

		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingAccount} \
			-elem   {promoCommonType:currencyRef} \
			-attributes [dict get $elements currencyRef]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingAccount} \
			-elem   {promoCommonType:fundingAccountRef} \
			-attributes [dict get $elements fundingAccountRef]
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {restriction}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {restriction} \
		-elem   {fundType:externalRestrictionRef} \
		-attributes [dict get $elements externalRestrictionRef]

	set restrictions [dict get $elements usageRestrictionDetails]
	if {$restrictions != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {restriction} \
			-elem   {fundType:usageRestrictionDetails}

		# Create the usage restriction. This may take the form of gameGroups
		# or betTagGroups elements
		if {[dict get $elements betTagGroups]} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent {fundType:usageRestrictionDetails} \
				-elem   {fundType:betTagGroups}

			set tag_group_index 0
			foreach group $restrictions {
				set group_label "betTagGroups.ref.$tag_group_index"
				core::soap::add_element \
					-name   $envelope_name \
					-parent {fundType:betTagGroups} \
					-elem   {fundType:betTagGroup} \
					-label  $group_label

				set restriction_index 0
				foreach {type value} $group {
					set restriction_label "betTagGroup.group.$tag_group_index.ref.$restriction_index"
					core::soap::add_element \
						-name   $envelope_name \
						-parent $group_label \
						-elem   {fundType:betTag} \
						-label  $restriction_label \
						-value  "$type/$value"
					incr restriction_index
				}
				incr tag_group_index
			}
		} else {
			core::soap::add_element \
				-name   $envelope_name \
				-parent {fundType:usageRestrictionDetails} \
				-elem   {fundType:gameGroups}

			set restriction_index 0
			foreach {type value} $restrictions {
				set restriction_label "gameGroups.ref.$restriction_index"
				core::soap::add_element \
					-name   $envelope_name \
					-parent {fundType:gameGroups} \
					-elem   {fundType:gameGroup} \
					-label  $restriction_label \
					-value  $value
				incr restriction_index
			}
		}
	}
}

#<?xml version="1.0" ?>
#<confirmFunding
#	xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#	xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes">
#	<fundingTransactionRef id="1" />
#</confirmFunding>
# create body for confirm_funding
proc core::api::funding_service::_create_body_confirmFunding {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name       $envelope_name \
			-parent     {soapenv:Body} \
			-elem       $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingTransactionRef} \
		-attributes [dict get $elements fundingTransactionRef]
}

#	<reserveiMultipleFunding xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#		xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#		xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#		<channelRef id="val"/>
#		<fundingAccount>
#			<!-- .. -->
#			<promoCommonType:externalCustRef id="val" provider="val"/>
#			<promoCommonType:currencyRef id="val"/>
#			<!-- or -->
#			<promoCommonType:fundingAccountRef id="val"/>
#			<!-- .. -->
#		</fundingAccount>
#		<fundingActivity>
#			<fundType:externalActivityRef id="" provider="" />
#			<fundType:type> </fundType:type>
#			<fundType:amount> </fundType:amount>
#			<fundType:fundingOperations>
#				<fundType:externalOperationRef id="" provider="" />
#				....
#			</fundType:fundingOperations>
#			<fundType:fundingActivityDetails>
#				<fundType:gameGroups>
#					<fundType:gameGroup> </fundType:gameGroup>
#					....
#				</fundType:gameGroups>
#			</fundType:fundingActivityDetails>
#		</fundingActivity>
#		<fundingActivity>
#			<fundType:externalActivityRef id="" provider="" />
#			<fundType:type> </fundType:type>
#			<fundType:amount> </fundType:amount>
#			<fundType:fundingOperations>
#				<fundType:externalOperationRef id="" provider="" />
#				....
#			</fundType:fundingOperations>
#			<fundType:fundingActivityDetails>
#				<fundType:gameGroups>
#					<fundType:gameGroup> </fundType:gameGroup>
#					....
#				</fundType:gameGroups>
#			</fundType:fundingActivityDetails>
#		</fundingActivity>
#		<negativeBalanceOverride>false</negativeBalanceOverride>
#	</reserveMultipleFunding>
# create body for reserve_funding
proc core::api::funding_service::_create_body_reserveMultipleFunding {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:externalCustRef} \
		-attributes [dict get $elements externalCustRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:currencyRef} \
		-attributes [dict get $elements currencyRef]

	if {[dict get $elements transactionStatus] != {}} {
		core::soap::add_element \
			-name $envelope_name \
			-parent $request \
			-elem   {transactionStatus} \
			-value  [dict get $elements transactionStatus]
	}

	set restrictions [dict get $elements usageRestrictionDetails]
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {usageRestriction}

	if {$restrictions != {}} {
		# Create the usage restriction. This may take the form of gameGroups
		# or betTagGroups elements
		if {[dict get $elements betTagGroups]} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent {usageRestriction} \
				-elem   {fundType:betTagGroups}

			set tag_group_index 0
			foreach group $restrictions {
				set group_label "betTagGroups.ref.$tag_group_index"
				core::soap::add_element \
					-name   $envelope_name \
					-parent {fundType:betTagGroups} \
					-elem   {fundType:betTagGroup} \
					-label  $group_label

				set restriction_index 0
				foreach {type value} $group {
					set restriction_label "betTagGroup.group.$tag_group_index.ref.$restriction_index"
					core::soap::add_element \
						-name   $envelope_name \
						-parent $group_label \
						-elem   {fundType:betTag} \
						-label  $restriction_label \
						-value  "$type/$value"
					incr restriction_index
				}
				incr tag_group_index
			}
		} else {
			core::soap::add_element \
				-name   $envelope_name \
				-parent {usageRestriction} \
				-elem   {fundType:gameGroups}

			set restriction_index 0
			foreach {type value} $restrictions {
				set restriction_label "gameGroups.ref.$restriction_index"
				core::soap::add_element \
					-name   $envelope_name \
					-parent {fundType:gameGroups} \
					-elem   {fundType:gameGroup} \
					-label  $restriction_label \
					-value  $value
				incr restriction_index
			}
		}
	}

	if {[dict exists $elements additional_properties]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fundingActivityProperties}

		set prop_index 0
		foreach property [dict get $elements additional_properties] {
			set prop_label "additionalProperties.additioanlPropery.$prop_index"
			foreach {k v} $property {

				core::soap::add_element \
					-name   $envelope_name \
					-parent {fundingActivityProperties} \
					-elem   {fundType:additionalProperty} \
					-label  $prop_label \
					-attributes [list key $k value $v]
			}

			incr prop_index 1
		}
	}

	set activities [dict get $elements activities]
	set activity_ref 0
	foreach activity $activities {
		set activity_label "fundingActivity.ref.$activity_ref"
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fundingActivity} \
			-label  $activity_label

		core::soap::add_element \
			-name   $envelope_name \
			-parent $activity_label \
			-elem   {fundType:externalActivityRef} \
			-attributes [dict get $activity externalActivityRef] \
			-label "$activity_label.activity_ref"

		core::soap::add_element \
			-name   $envelope_name \
			-parent $activity_label \
			-elem   {fundType:type} \
			-value  [dict get $activity type] \
			-label "$activity_label.activity_type"

		if {[dict get $activity transactionType] != {}} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent $activity_label \
				-elem   {fundType:transactionType} \
				-value  [dict get $activity transactionType] \
				-label "$activity_label.activity_transaction_type"
		}

		core::soap::add_element \
			-name   $envelope_name \
			-parent $activity_label \
			-elem   {fundType:amount} \
			-value  [dict get $activity amount] \
			-label "$activity_label.activity_amount"

		core::soap::add_element \
			-name   $envelope_name \
			-parent $activity_label \
			-elem   {fundType:fundingOperations} \
			-label "$activity_label.operations"

		set operation_index 0
		set operation_provider [dict get $activity fundingOperationProvider]
		foreach {operation_id status type} [dict get $activity fundingOperations] {
			core::soap::add_element \
				-name   $envelope_name \
				-parent $activity_label.operations \
				-elem   {fundType:fundingOperation} \
				-label "$activity_label.operations.$operation_index"

			set operation_label "$activity_ref.operations.ref.$operation_index"
			core::soap::add_element \
				-name   $envelope_name \
				-parent "$activity_label.operations.$operation_index" \
				-elem   {fundType:externalOperationRef} \
				-label  $operation_label \
				-attributes [list id $operation_id provider $operation_provider]

			set operation_status "$activity_ref.operations.type.$operation_index"
			core::soap::add_element \
				-name   $envelope_name \
				-parent "$activity_label.operations.$operation_index" \
				-elem   {fundType:operationType} \
				-label  $operation_status \
				-value  $type

			set operation_status "$activity_ref.operations.status.$operation_index"
			core::soap::add_element \
				-name   $envelope_name \
				-parent "$activity_label.operations.$operation_index" \
				-elem   {fundType:status} \
				-label  $operation_status \
				-value  $status

			incr operation_index 1
		}

		set restrictions [dict get $activity usageRestrictionDetails]

		if {$restrictions != {}} {
			core::soap::add_element \
				-name   $envelope_name     \
				-parent $activity_label    \
				-elem   {fundType:usageRestriction} \
				-label  "$activity_label.restriction"

			# Create the usage restriction. This may take the form of gameGroups
			# or betTagGroups elements
			if {[dict get $activity betTagGroups]} {
				core::soap::add_element \
					-name   $envelope_name \
					-parent "$activity_label.restriction" \
					-elem   {fundType:betTagGroups} \
					-label "$activity_label.restriction.groups"

				set tag_group_index 0
				foreach group $restrictions {
					set group_label "$activity_label.restriction.groups.$tag_group_index"
					core::soap::add_element \
						-name   $envelope_name \
						-parent "$activity_label.restriction.groups" \
						-elem   {fundType:betTagGroup} \
						-label  "$group_label"

					set restriction_index 0
					foreach {type value} $group {
						set restriction_label "$group_label.$restriction_index"
						core::soap::add_element \
							-name   $envelope_name \
							-parent $group_label \
							-elem   {fundType:betTag} \
							-label  $restriction_label \
							-value  "$type/$value"
						incr restriction_index
					}
					incr tag_group_index
				}
			} else {
				core::soap::add_element \
					-name   $envelope_name \
					-parent "$activity_label.restriction" \
					-elem   {fundType:gameGroups} \
					-label  "$activity_label.restriction.gg"

				set restriction_index 0
				foreach {type value} $restrictions {
					set restriction_label "$activity_label.restriction.gg.$restriction_index"
					core::soap::add_element \
						-name   $envelope_name \
						-parent "$activity_label.restriction.gg" \
						-elem   {fundType:gameGroup} \
						-label  $restriction_label \
						-value  $value
					incr restriction_index
				}
			}

		}
		set fund_ref [dict get $activity externalFundRef]
		if {$fund_ref != {}} {
			set fund_label "$activity_label.fund"
			set fund_ref_label "$activity_label.fund.ref"
				core::soap::add_element    \
					-name   $envelope_name  \
					-parent $activity_label \
					-elem   {fundType:fund} \
					-label  $fund_label

				core::soap::add_element    \
					-name        $envelope_name  \
					-parent      $fund_label     \
					-elem        {fundType:externalFundRef} \
					-label       $fund_ref_label \
					-attributes  $fund_ref

		}


		if {[dict get $activity useCashFunds]} {
			core::soap::add_element    \
				-name   $envelope_name  \
				-parent $activity_label \
				-elem   {fundType:useCashFunds} \
				-label  "$activity_label.use_cash" \
				-value  "true"
		}

		if {[dict get $activity description] != {}} {
			core::soap::add_element    \
				-name   $envelope_name  \
				-parent $activity_label \
				-elem   {fundType:description} \
				-label  "$activity_label.description" \
				-value  [dict get $activity description]
		}

		incr activity_ref
	}

	if {[dict get $elements negativeBalanceOverride]} {
		core::soap::add_element \
			-name $envelope_name \
			-parent $request \
			-elem   {negativeBalanceOverride} \
			-value  "true"
	}

}

#<makeFundPayment xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#	xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#   xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<channelRef id="A" />
#	<fundingAccount>
#	    <promoCommonType:externalCustRef id="1" provider="G"/>
#	    <promoCommonType:currencyRef id="GBP"/>
#	</fundingAccount>
#	<fundingActivity>
#	    <fundType:externalActivityRef id="1" provider="G"/>
#	    <fundType:type>DEP</fundType:type>
#	     <fundType:transactionType>TYPE</fundType:transactionType>
#	     <fundType:fundingOperations>
#	     	<fundType:fundingOperation>
#	     		<fundType:externalOperationRef id="2" provider="G"/>
#	    		<fundType:operationType>TYPE</fundType:operationType>
#	    	</fundType:fundingOperation>
#	     </fundType:fundingOperations>
#		<fundType:fund>
#			<fundType:externalFundRef id="DevClientFund" provider="G"/>
#			<fundType:fundItems>
#				<fundType:fundItem type="CASH" amount="10.00"/>
#			</fundType:fundItems>
#		</fundType:fund>
#		<fundType:description>some_description_here</fundType:description>
#	</fundingActivity>
#</makeFundPayment>
proc core::api::funding_service::_create_body_makeFundPayment {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]


	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:externalCustRef} \
		-attributes [dict get $elements externalCustRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:currencyRef} \
		-attributes [dict get $elements currencyRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingActivity}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingActivity} \
		-elem   {fundType:externalActivityRef} \
		-attributes [dict get $elements externalActivityRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingActivity} \
		-elem   {fundType:type} \
		-value [dict get $elements type]

	if {[dict get $elements transactionType] != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingActivity} \
			-elem   {fundType:transactionType} \
			-value  [dict get $elements transactionType]
	}

	 core::soap::add_element \
	 	 -name   $envelope_name \
	     -parent {fundingActivity} \
	     -elem   {fundType:fundingOperations}

	 core::soap::add_element \
	     -name   $envelope_name \
	     -parent {fundType:fundingOperations} \
	     -elem   {fundType:fundingOperation}

	 core::soap::add_element \
	     -name   $envelope_name \
	     -parent {fundType:fundingOperation} \
	     -elem   {fundType:externalOperationRef} \
	     -attributes [dict get $elements externalOperationRef]

	 core::soap::add_element \
	     -name   $envelope_name \
	     -parent {fundType:fundingOperation} \
         -elem   {fundType:operationType} \
	     -value  [dict get $elements operationType]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingActivity} \
		-elem   {fundType:fund}

	array set FUND [dict get  $elements externalFundRef]

	if {$FUND(id) != {}} {

		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:fund} \
			-elem   {fundType:externalFundRef} \
			-attributes [dict get $elements externalFundRef]
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundType:fund} \
		-elem   {fundType:fundItems}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundType:fundItems} \
		-elem   {fundType:fundItem} \
		-attributes [dict get $elements fundItem]

	if {[dict get $elements description] != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingActivity} \
			-elem   {fundType:description} \
			-value  [dict get $elements description]
	}
}

#<getFundHistory xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#	xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#	xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<fund>
#		<fundType:externalFundRef id="TheFund" provider="G"/>
#	</fund>
#	<fromDate>2014-01-01T00:00:00</fromDate>
#	<toDate>2020-01-01T00:00:00</toDate>
#</getFundHistory>
# create body for get_fund_history
proc core::api::funding_service::_create_body_getFundHistory {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fund}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:externalFundRef} \
		-attributes [dict get $elements externalFundRef]

	if {[dict exists $elements fromDate]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements fromDate]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fromDate} \
			-value  $date_formatted
	}

	if {[dict exists $elements toDate]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements toDate]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {toDate} \
			-value  $date_formatted
	}
}

#<?xml version="1.0" ?>
#<cancelFunding
#	xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#	xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes">
#	<fundingTransactionRef id="1" />
#</cancelFunding>
# create body for cancel_funding
proc core::api::funding_service::_create_body_cancelFunding {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name       $envelope_name \
			-parent     {soapenv:Body} \
			-elem       $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingTransactionRef} \
		-attributes [dict get $elements fundingTransactionRef]
}

#<?xml version="1.0" ?>
#<cancelActivity
#		xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#		xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#		xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#		<channelRef id="A" />
#		<activity>
#			<ns2:externalActivityRef id="2" provider="G"/>
#			<ns2:targetActivityRef id="2X" provider="G"/>
#		</activity>
#</cancelActivity>
# create body for cancel_activity
proc core::api::funding_service::_create_body_cancelActivity {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name       $envelope_name \
			-parent     {soapenv:Body} \
			-elem       $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}


	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {channelRef} \
		-attributes [dict get $elements channelRef]

	set activities   [dict get $elements activities]
	set activity_ref 0
	set provider     [dict get $elements provider]

	foreach activity $activities {

		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {activity} \
			-label  "activity.$activity_ref"

		set activity_id [list id [dict get $activity activity_id] provider $provider]
		core::soap::add_element \
			-name   $envelope_name \
			-parent "activity.$activity_ref" \
			-elem   {fundType:externalActivityRef} \
			-attributes $activity_id \
			-label  "activity.$activity_ref.activity_id" \

		set target_id [list id [dict get $activity target_activity_id] provider $provider]
		core::soap::add_element \
			-name   $envelope_name \
			-parent "activity.$activity_ref" \
			-elem   {fundType:targetActivityRef} \
			-label  "target_activity.$activity_ref.target_id" \
			-attributes $target_id

		if {[dict get $elements transactionType] != {}} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent "activity.$activity_ref" \
				-elem   {fundType:transactionType} \
				-value  [dict get $elements transactionType]
		}

		if {[dict get $elements description] != {}} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent "activity.$activity_ref" \
				-elem   {fundType:description} \
				-value  [dict get $elements description]
		}

		incr activity_ref
	}

}

#<cancelRestriction
#		xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#		xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#		xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<restriction>
#		<fundType:externalRestrictionRef id="1" provider="G"/>
#	</restriction>
#</cancelRestriction>
# create body for cancel_restriction
proc core::api::funding_service::_create_body_cancelRestriction {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {restriction}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {restriction} \
		-elem   {fundType:externalRestrictionRef} \
		-attributes [dict get $elements externalRestrictionRef]
}

#<cancelMultipleRestriction
#		xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#		xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#		xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<groupingCondition>1</groupingCondition>
#	</restriction>
#</cancelMultipleRestriction>
# create body for cancel_multiple_restriction
proc core::api::funding_service::_create_body_cancelMultipleRestriction {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {groupingCondition} \
		-value  [dict get $elements groupingCondition]
}




proc core::api::funding_service::_create_body_getFundAccountHistory {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:externalCustRef} \
		-attributes [dict get $elements externalCustRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:currencyRef} \
		-attributes [dict get $elements currencyRef]

	if {[dict exists $elements fundingActivityTypes]} {
		set activity_types [dict get $elements fundingActivityTypes]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fundingActivityTypes}

		set type_idx 0
		foreach type $activity_types {
			set label "fundType.activityTypes.$type_idx"
			core::soap::add_element \
				-name   $envelope_name \
				-parent {fundingActivityTypes} \
				-elem   {fundType:activityType} \
				-label  $label \
				-value  $type

			incr type_idx
		}
	}

	if {[dict exists $elements transactionTypes]} {
		set transaction_types [dict get $elements transactionTypes]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {transactionTypes}

		set type_idx 0
		foreach type $transaction_types {
			set label "fundType.transactionTypes.$type_idx"
			core::soap::add_element \
				-name   $envelope_name \
				-parent {transactionTypes} \
				-elem   {fundType:transactionType} \
				-label  $label \
				-value  $type

			incr type_idx
		}
	}

	if {[dict exists $elements fromDate]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements fromDate]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fromDate} \
			-value  $date_formatted
	}

	if {[dict exists $elements toDate]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements toDate]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {toDate} \
			-value  $date_formatted
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {pageSize} \
		-value  [dict get $elements pageSize]

	if {[dict exists $elements pageDirection]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {pageDirection} \
			-value  [dict get $elements pageDirection]
	}

	if {[dict exists $elements pageBoundary]} {
		set page_boundary [dict get $elements pageBoundary]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {pageBoundary}

		core::soap::add_element \
			-name   $envelope_name \
			-parent {pageBoundary} \
			-elem   {fundType:start}

		core::soap::add_element \
			-name   $envelope_name \
			-parent {pageBoundary} \
			-elem   {fundType:end}

		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:start} \
			-elem   {fundType:id} \
			-value  [lindex $page_boundary 0]

		set date_formatted [core::date::datetime_to_xml_date -datetime [lindex $page_boundary 2]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:start} \
			-elem   {fundType:date} \
			-value  $date_formatted

		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:end} \
			-elem   {fundType:id} \
			-label  {fundType:id2} \
			-value  [lindex $page_boundary 1]

		set date_formatted [core::date::datetime_to_xml_date -datetime [lindex $page_boundary 3]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundType:end} \
			-elem   {fundType:date} \
			-label  {fundType:date2} \
			-value  $date_formatted
	}

}

proc core::api::funding_service::_create_body_getFundAccountSummary {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:externalCustRef} \
		-attributes [dict get $elements externalCustRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:currencyRef} \
		-attributes [dict get $elements currencyRef]

	if {[dict exists $elements transactionTypes]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {transactionTypes}


		set type_idx 0
		set transaction_types [dict get $elements transactionTypes]

		foreach type $transaction_types {
			set label "fundType.transactionType.$type_idx"
			core::soap::add_element \
				-name   $envelope_name \
				-parent {transactionTypes} \
				-elem   {fundType:transactionType} \
				-label  $label \
				-value  $type

			incr type_idx
		}
	}

	set date_formatted [dict get $elements fromDate]
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fromDate} \
		-value  $date_formatted

	set date_formatted [dict get $elements toDate]
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {toDate} \
		-value  $date_formatted

	if {[dict exists $elements fromTime]} {
		set time [dict get $elements fromTime]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {fromTime} \
			-value  $time
	}

	if {[dict exists $elements toTime]} {
		set time [dict get $elements toTime]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {toTime} \
			-value  $time
	}
}

#<?xml version="1.0" ?>
#<activateFund xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#  xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#  xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#   <fund>
#   	<fundType:externalFundRef id="TheFund" provider="G"/>
#   </fund>
#</activateFund>
# create body for activate_fund
proc core::api::funding_service::_create_body_activateFund {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fund}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:externalFundRef} \
		-attributes [dict get $elements externalFundRef]
}

#<?xml version="1.0" ?>
#<updateFund xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
#  xmlns:fundType="http://schema.products.sportsbook.openbet.com/fundingTypes"
#  xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<fundingAccount>
#	    <promoCommonType:externalCustRef id="1" provider="G"/>
#	    <promoCommonType:currencyRef id="GBP"/>
#	</fundingAccount>
#	<fund>
#		<fundType:externalFundRef id="201602191048" provider="G"/>
#	</fund>
#	<newStartDate>2095-01-01T00:00:00</newStartDate>
#	<newExpiryDate>2099-01-01T00:00:00</newExpiryDate>
#</updateFund>
# create body for update_fund
proc core::api::funding_service::_create_body_updateFund {envelope_name request elements} {

	if {[dict exists $elements request_xmlns]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request \
			-attributes [dict get $elements request_xmlns]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {soapenv:Body} \
			-elem   $request
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fundingAccount}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:externalCustRef} \
		-attributes [dict get $elements externalCustRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fundingAccount} \
		-elem   {promoCommonType:currencyRef} \
		-attributes [dict get $elements currencyRef]

	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {fund}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {fund} \
		-elem   {fundType:externalFundRef} \
		-attributes [dict get $elements externalFundRef]

	if {[dict exists $elements newStartDate]} {
		set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements newStartDate]]
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {newStartDate} \
			-value  $date_formatted
	}

	set date_formatted [core::date::datetime_to_xml_date -datetime [dict get $elements newExpiryDate]]
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {newExpiryDate} \
		-value  $date_formatted

}

# Create a generic soap envelope structure.
#
# <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
#		<soapenv:Header>
#			<requestHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" >
#				...
#			</requestHeader>
#		</soapenv:Header>
#		<soapenv:Body />
# </soapenv:Envelope>
proc core::api::funding_service::_create_envelope {envelope_name request_header request_header_xmlns } {

	core::soap::create_envelope \
		-name  $envelope_name \
		-namespaces [list {soapenv} {http://schemas.xmlsoap.org/soap/envelope/}]

	core::soap::add_soap_header \
		-name  $envelope_name \
		-label {soapenv:Header}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Header} \
		-elem   $request_header \
		-attributes [list {xmlns} $request_header_xmlns]

	core::soap::add_soap_body \
		-name  $envelope_name \
		-label {soapenv:Body}

	return [list OK]
}

# Create a request header, that should be in common with all the other functionality available in this api.
#
#<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
#	<soapenv:Header>
#		<requestHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader">
#			<apiVersion>..</apiVersion>
#			<sessionToken tokenValue=".." />
#			<clientSessionToken tokenValue=".." />
#			<context>
#				<methodName>..</methodName>
#				<parameters>..</parameters>
#				<contextNext>
#					<methodName>..</methodName>
#					<parameters>..</parameters>
#					<contextNext>
#						<methodName>..</methodName>
#						<parameters>..</parameters>
#					</contextNext>
#				</contextNext>
#			</context>
#			<endUserSession>
#				<sessionToken>..</sessionToken>
#				<lastUpdated>..</lastUpdated>
#				<expiration>..</expiration>
#				<subjects>
#					<id>..</id>
#					<name>..</name>
#					<roles>
#						<name>..</name>
#					</roles>
#					<roles>
#						..
#					</roles>
#					<type>.</type>
#				</subjects>
#				<subjects>
#				...
#				</subjects>
#			</endUserSession>
#			<serviceInitiatorId>..</serviceInitiatorId>
#		</requestHeader>
#	</soapenv:Header>
#	<soapenv:Body />
#</soapenv:Envelope>
proc core::api::funding_service::_create_header {
	envelope_name
	{api_version {}}
	{request_header {requestHeader}}
	{session_token_value {}}
	{client_session_token_value {}}
	{contexts {}}
	{service_initiator_id {}}
	{usersession_token {}}
	{usersession_lastupdate {}}
	{usersession_expiration {}}
	{usersession_subjects {}}
} {
	if {$api_version != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request_header \
			-elem   {apiVersion} \
			-value  $api_version
	}

	if {$session_token_value != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request_header \
			-elem   {sessionToken} \
			-attributes [list {tokenValue} $session_token_value]
	}

	if {$client_session_token_value != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request_header \
			-elem   {clientSessionToken} \
			-attributes [list {tokenValue} $client_session_token_value]
	}

#		this has a recursive structure, need to map the label with the structure and change the name of the parent each time.
#		<context>
#			<methodName>..</methodName>
#			<parameters>..</parameters>
#			<contextNext>
#				<methodName>..</methodName>
#				<parameters>..</parameters>
#				<contextNext>
#					<methodName>..</methodName>
#					<parameters>..</parameters>
#				</contextNext>
#			</contextNext>
#		</context>
	set context_index 0
	foreach context $contexts {
		if {$context_index == 0} {
			set context_parent $request_header
			set context_element_name {context}
		} else {
			set context_parent $context_label
			set context_element_name {contextNext}
		}
		set context_label "$context_parent.ctx.$context_index"

		foreach {methodName parameters} $context {
			core::soap::add_element \
				-name   $envelope_name \
				-parent $context_parent \
				-elem   $context_element_name \
				-label  $context_label

			core::soap::add_element \
				-name   $envelope_name \
				-parent $context_label \
				-elem   {methodName} \
				-value  $methodName \
				-label  "$context_label.methodName"

			core::soap::add_element \
				-name   $envelope_name \
				-parent $context_label \
				-elem   {parameters} \
				-value  $parameters \
				-label  "$context_label.parameters"
		}
		incr context_index 1
	}

	if {$usersession_token != {} && [llength usersession_subjects] > 0} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request_header \
			-elem   {endUserSession}

		core::soap::add_element \
			-name   $envelope_name \
			-parent {endUserSession} \
			-elem   {sessionToken} \
			-value  $usersession_token \
			-label  {endUserSession.sessionToken}

		if {$usersession_lastupdate != {}} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent endUserSession \
				-elem   {lastUpdated} \
				-value  $usersession_lastupdate
		}

		if {$usersession_expiration != {}} {
			core::soap::add_element \
				-name   $envelope_name \
				-parent endUserSession \
				-elem   {expiration} \
				-value  $usersession_expiration
		}

#			subject has a structure like that:
#			<endUserSession>
#				...
#				<subjects>
#					<id>..</id>
#					<name>..</name>
#					<type>..</type>
#					<roles>
#						<name>..</name>
#					</roles>
#					<roles>
#						<name>..</name>
#					</roles>
#				</subjects>
#				<subjects>
#					<id>..</id>
#					<name>..</name>
#					<type>..</type>
#					<roles>
#						<name>..</name>
#					</roles>
#					<roles>
#						<name>..</name>
#					</roles>
#				</subjects>
#				..
#			</endUserSession>
		set subject_index 0
		foreach subject $usersession_subjects {

			set subject_label "endUserSession.sbj.$subject_index"

			core::soap::add_element \
				-name   $envelope_name \
				-parent {endUserSession} \
				-elem   {subjects} \
				-label  $subject_label

			foreach {id name roles type} $subject {

				core::soap::add_element \
					-name   $envelope_name \
					-parent $subject_label \
					-elem   {id} \
					-value  $id \
					-label  "$subject_label.id"

				core::soap::add_element \
					-name   $envelope_name \
					-parent $subject_label \
					-elem   {name} \
					-value  $name \
					-label  "$subject_label.name"

				set role_index 0
				foreach role $roles {
					set parent_roles_label  "$subject_label.roles.$role_index"

					core::soap::add_element \
						-name   $envelope_name \
						-parent $subject_label \
						-elem   {roles} \
						-label  $parent_roles_label

					core::soap::add_element \
						-name   $envelope_name \
						-parent $parent_roles_label \
						-elem   {name} \
						-value  $role \
						-label  "$parent_roles_label.name"
					incr role_index 1
				}

				core::soap::add_element \
					-name   $envelope_name \
					-parent $subject_label \
					-elem   {type} \
					-value  $type \
					-label  "$subject_label.type"

			}
			incr subject_index 1
		}
	}

	if {$service_initiator_id != {}} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request_header \
			-elem   {serviceInitiatorId} \
			-value  $service_initiator_id
	}

	return [list OK]
}
