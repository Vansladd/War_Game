#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

set pkg_version 1.0
package provide core::api::promotion_service $pkg_version

package require core::log           1.0
package require core::util          1.0
package require core::check         1.0
package require core::args          1.0
package require core::gc            1.0
package require core::soap          1.0
package require core::date          1.0

core::args::register_ns \
	-namespace core::api::promotion_service \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::date \
		core::soap] \
	-docs xml/api/promotion_service.xml

namespace eval ::core::api::promotion_service {
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
	set CORE_DEF(wagering_id)                [list -arg -wagering_id            -mand 1 -check ASCII -desc {Wagering requirement id in the current system}]
	set CORE_DEF(username)                   [list -arg -username               -mand 1 -check ASCII -desc {Username of the operator that is attempting to do the operation}]

	set CORE_DEF(customer_id,opt)            [list -arg -customer_id            -mand 0 -check ASCII -desc {Customer id of the current system, is mandatory if the account parameters are missing} -default {}]
	set CORE_DEF(currency_id,opt)            [list -arg -currency_id            -mand 0 -check ASCII -desc {The currency ISO code, fill only if the customer parameters are defined}               -default {}]
	set CORE_DEF(funding_account_id,opt)     [list -arg -funding_account_id     -mand 0 -check ASCII -desc {Account id of Funding Service system (external), it should be used only by systems that share the DB with the Funding Service,it is mandatory if the customer parameters are missing}       -default {}]
	set CORE_DEF(wagering_amount,opt)        [list -arg -wagering_amount        -mand 0 -check ASCII -desc {The amount related to the wagering requirement, meaningful only if wagering_on_winnings is N} -default {}]
	set CORE_DEF(wagering_scale_factors,opt) [list -arg -wagering_scale_factors -mand 0 -check LIST  -desc {a list of scale wagering requirement per game group <id,scale_factor>} -default [list]]
	set CORE_DEF(wagering_multiplier,opt)    [list -arg -wagering_multiplier    -mand 0 -check ASCII -desc {The multiplier used to calculate the target amount, meaningful only if wagering_on_winnings is Y} -default {}]
	set CORE_DEF(wagering_on_winnings)       [list -arg -wagering_on_winnings   -mand 0 -check {ENUM -args {Y N}} -default {N} -desc {Whether the Wagering amount shall be calculated on winnings}]
	set CORE_DEF(requirement_status,opt)     [list -arg -requirement_status     -mand 0 -check {ENUM -args {ACTIVE EXPIRED COMPLETE}} -desc {Value to filter by requirement Status} -default {}]
	set CORE_DEF(requirement_initial_balance,opt) [list -arg -requirement_initial_balance     -mand 0 -check MONEY -desc {Initial balance of the wagering requirement} -default {}]
	set CORE_DEF(requirement_current_balance,opt) [list -arg -requirement_current_balance     -mand 0 -check MONEY -desc {Current balance of the wagering requirement} -default {}]

	set CORE_DEF(from_date)                  [list -arg -from_date              -mand 0 -check DATETIME  -desc {Oldest date under consideration}]
	set CORE_DEF(to_date)                    [list -arg -to_date                -mand 0 -check DATETIME  -desc {Most recent date under consideration}]
	set INIT 0
}

# Initialise the API
core::args::register \
	-proc_name core::api::promotion_service::init \
	-desc {Initialise Promotion Service} \
	-args [list \
		[list -arg -service_endpoint  -mand 0 -check STRING -default_cfg PROMOTION_SERVICE_ENDPOINT                          -desc {the promotion service server's url that is providing the API}] \
		[list -arg -api_version       -mand 0 -check ASCII  -default_cfg PROMOTION_SERVICE_API_VERSION     -default {1.0}    -desc {api version}] \
		[list -arg -channel_id        -mand 0 -check ASCII  -default_cfg PROMOTION_SERVICE_CHANNEL_ID      -default {A}      -desc {Channel id of the current system}] \
		[list -arg -system_provider   -mand 0 -check ASCII  -default_cfg PROMOTION_SERVICE_SYSTEM_PROVIDER -default {G}      -desc {Current system provider provider code}] \
		[list -arg -game_provider     -mand 0 -check ASCII  -default_cfg PROMOTION_SERVICE_GAME_PROVIDER   -default {GGROUP} -desc {Current system game provider code}] \
	] \
	-body {
		variable CFG
		variable INIT

		if {$INIT} {
			core::log::write INFO {promotion_service already initialised}
			return
		}

		core::log::write INFO {Initialising promotion_service...}
		foreach {n v} [array get ARGS] {
			set n   [string trimleft $n -]
			set str [format "%-35s = %s" $n $v]
			core::log::write INFO {promotion_service initialised with $str}

			set CFG($n) $v
		}

		#----------- CREATE_WAGERING_REQ ---------------
		set CFG(CREATE_WAGERING_REQ,request_name) {createWageringRequirement}
		set CFG(CREATE_WAGERING_REQ,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/promotions} \
			xmlns:promoType {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes}]

		set CFG(CREATE_WAGERING_REQ,soap,request_header) {requestHeader}
		set CFG(CREATE_WAGERING_REQ,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(CREATE_WAGERING_REQ,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n2 {http://schema.products.sportsbook.openbet.com/promotions} \
			n3 {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		#----------- GET_WAGERING_REQS -----------------
		set CFG(GET_WAGERING_REQS,request_name) {getWageringRequirements}
		set CFG(GET_WAGERING_REQS,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/promotions} \
			xmlns:promoType {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes}]

		set CFG(GET_WAGERING_REQS,soap,request_header) {requestHeader}
		set CFG(GET_WAGERING_REQS,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_WAGERING_REQS,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n2 {http://schema.products.sportsbook.openbet.com/promotions} \
			n3 {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(GET_WAGERING_REQ_HIST,request_name) {getWageringRequirementHistory}
		set CFG(GET_WAGERING_REQ_HIST,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/promotions} \
			xmlns:promoType {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes}]

		set CFG(GET_WAGERING_REQ_HIST,soap,request_header) {requestHeader}
		set CFG(GET_WAGERING_REQ_HIST,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(GET_WAGERING_REQ_HIST,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n2 {http://schema.products.sportsbook.openbet.com/promotions} \
			n3 {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		set CFG(UPDATE_WAGERING_REQ,request_name) {updateWageringRequirement}
		set CFG(UPDATE_WAGERING_REQ,soap,request_xmlns) [list \
			xmlns {http://schema.products.sportsbook.openbet.com/promotions} \
			xmlns:promoType {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			xmlns:promoCommonType {http://schema.products.sportsbook.openbet.com/promoCommonTypes}]

		set CFG(UPDATE_WAGERING_REQ,soap,request_header) {requestHeader}
		set CFG(UPDATE_WAGERING_REQ,soap,request_header_xmlns) {http://schema.core.sportsbook.openbet.com/requestHeader}
		set CFG(UPDATE_WAGERING_REQ,response_namespaces) [list \
			n1 {http://schema.products.sportsbook.openbet.com/promoCommonTypes} \
			n2 {http://schema.products.sportsbook.openbet.com/promotions} \
			n3 {http://schema.products.sportsbook.openbet.com/promotionsTypes} \
			h1 {http://schema.core.sportsbook.openbet.com/requestHeader} \
			h2 {http://schema.core.sportsbook.openbet.com/responseHeader} \
		]

		if {![catch {
				package require core::harness::api::promotion_service 1.0
			} msg]} {
			core::harness::api::promotion_service::init
		}

		set INIT 1
	}

# createWageringRequirement
core::args::register \
	-proc_name core::api::promotion_service::create_wagering_requirement \
	-desc {Create Wagering requirement in the promotion service} \
	-args [list \
		$::core::api::promotion_service::CORE_DEF(wagering_id) \
		$::core::api::promotion_service::CORE_DEF(session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(contexts,opt) \
		$::core::api::promotion_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_token,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::promotion_service::CORE_DEF(customer_id,opt) \
		$::core::api::promotion_service::CORE_DEF(currency_id,opt) \
		$::core::api::promotion_service::CORE_DEF(funding_account_id,opt) \
		$::core::api::promotion_service::CORE_DEF(wagering_amount,opt) \
		$::core::api::promotion_service::CORE_DEF(wagering_scale_factors,opt) \
		$::core::api::promotion_service::CORE_DEF(wagering_on_winnings) \
		$::core::api::promotion_service::CORE_DEF(wagering_multiplier,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::promotion_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)
		set game_provider   $CFG(game_provider)

		##--------START Preparing input dict body elements------#

		# Adding customer information
		if {$ARGS(-customer_id) != {}} {
			set customer_attributes [list]
			lappend customer_attributes id $ARGS(-customer_id)
			lappend customer_attributes provider $system_provider
			dict set body_elements externalCustRef $customer_attributes
			# if the request has customer id the currency is mandatory
			dict set body_elements currencyRef [list id $ARGS(-currency_id)]
		}

		if {$ARGS(-funding_account_id) != {}} {
			dict set body_elements fundingAccountRef [list id $ARGS(-funding_account_id)]
		}

		#adding wagering information
		dict set body_elements externalWageringRequirementRef [list id $ARGS(-wagering_id) provider $system_provider]
		dict set body_elements targetAmount $ARGS(-wagering_amount)
		if {$ARGS(-wagering_multiplier) != {}} {
			dict set body_elements wageringMultiplier [expr int($ARGS(-wagering_multiplier))]
		} else {
			dict set body_elements wageringMultiplier {}
		}
		if {[string equal "Y" $ARGS(-wagering_on_winnings)]} {
			dict set body_elements wageringOnWinnings "Y"
		}

		# adding scale factoring wagering requirements
		# the input is a list of list like [list [list id scale_factor] [list id scale_factor]]
		set contributes [list]
		foreach factor $ARGS(-wagering_scale_factors) {
			foreach {id scale_factor} $factor {
				lappend contributes [list type $game_provider id $id factor $scale_factor ]
			}
		}
		if {[llength $contributes] != 0} {
			dict set body_elements contributeFactors $contributes
		}
		##--------END Preparing input dict body elements------#

		set request_name         $CFG(CREATE_WAGERING_REQ,request_name)
		set request_xmlns        $CFG(CREATE_WAGERING_REQ,soap,request_xmlns)
		set request_header       $CFG(CREATE_WAGERING_REQ,soap,request_header)
		set request_header_xmlns $CFG(CREATE_WAGERING_REQ,soap,request_header_xmlns)

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

core::args::register \
	-proc_name core::api::promotion_service::get_wagering_requirements \
	-desc      {Get wagering restrictions for a customer account from the promotion service} \
	-args [list \
		$::core::api::promotion_service::CORE_DEF(funding_account_id,opt) \
		$::core::api::promotion_service::CORE_DEF(customer_id,opt) \
		$::core::api::promotion_service::CORE_DEF(currency_id,opt) \
		$::core::api::promotion_service::CORE_DEF(requirement_status,opt) \
		$::core::api::promotion_service::CORE_DEF(session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(contexts,opt) \
		$::core::api::promotion_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_token,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::promotion_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)
		set game_provider   $CFG(game_provider)

		##--------START Preparing input dict body elements------#

		# Adding customer information
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

		if {$ARGS(-requirement_status) != {}} {
			dict set body_elements requirementStatus $ARGS(-requirement_status)
		}
		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_WAGERING_REQS,request_name)
		set request_xmlns        $CFG(GET_WAGERING_REQS,soap,request_xmlns)
		set request_header       $CFG(GET_WAGERING_REQS,soap,request_header)
		set request_header_xmlns $CFG(GET_WAGERING_REQS,soap,request_header_xmlns)

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

# getWageringRequirementHistory
core::args::register \
	-proc_name core::api::promotion_service::get_wagering_requirement_history \
	-desc {Get the adjustment history for a wagering requirement} \
	-args [list \
		$::core::api::promotion_service::CORE_DEF(wagering_id) \
		$::core::api::promotion_service::CORE_DEF(from_date) \
		$::core::api::promotion_service::CORE_DEF(to_date) \
		$::core::api::promotion_service::CORE_DEF(session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(contexts,opt) \
		$::core::api::promotion_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_token,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_subjects,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::promotion_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)
		set channel_id      $CFG(channel_id)
		set game_provider   $CFG(game_provider)

		##----------START Preparing input dict body elements--------#

		#adding wagering information
		dict set body_elements externalWageringRequirementRef [list id $ARGS(-wagering_id) provider $system_provider]
		if {$ARGS(-from_date) != {}} {
			dict set body_elements fromDate $ARGS(-from_date) 
		}
		if {$ARGS(-to_date) != {}} {
			dict set body_elements toDate $ARGS(-to_date)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(GET_WAGERING_REQ_HIST,request_name)
		set request_xmlns        $CFG(GET_WAGERING_REQ_HIST,soap,request_xmlns)
		set request_header       $CFG(GET_WAGERING_REQ_HIST,soap,request_header)
		set request_header_xmlns $CFG(GET_WAGERING_REQ_HIST,soap,request_header_xmlns)

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

# updateWageringRequirement
core::args::register \
	-proc_name core::api::promotion_service::update_wagering_requirement \
	-desc {update a Wagering requirement in the promotion service} \
	-args [list \
		$::core::api::promotion_service::CORE_DEF(wagering_id) \
		$::core::api::promotion_service::CORE_DEF(username) \
		$::core::api::promotion_service::CORE_DEF(session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(client_session_token_value,opt) \
		$::core::api::promotion_service::CORE_DEF(contexts,opt) \
		$::core::api::promotion_service::CORE_DEF(service_initiator_id,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_token,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_lastupdate,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_expiration,opt) \
		$::core::api::promotion_service::CORE_DEF(usersession_subjects,opt) \
		$::core::api::promotion_service::CORE_DEF(requirement_status,opt) \
		$::core::api::promotion_service::CORE_DEF(requirement_initial_balance,opt) \
		$::core::api::promotion_service::CORE_DEF(requirement_current_balance,opt) \
	] \
	-body {
		variable INIT
		variable CFG

		if {!$INIT} {
			core::api::promotion_service::init
		}

		set api_version     $CFG(api_version)
		set system_provider $CFG(system_provider)

		##--------START Preparing input dict body elements------#

		dict set body_elements username $ARGS(-username)

		dict set body_elements externalWageringRequirementRef [list id $ARGS(-wagering_id) provider $system_provider]
		
		if {$ARGS(-requirement_initial_balance) == {} && $ARGS(-requirement_status) == {} && $ARGS(-requirement_current_balance) == {}} {
			error "core::api::promotion_service::update_wagering_requirement: at least one need to be modified between: status, initial balance and current balance" {} INVALID_REQUEST
		}

		if {$ARGS(-requirement_initial_balance) != {}} {
			dict set body_elements initialBalance $ARGS(-requirement_initial_balance)
		}

		if {$ARGS(-requirement_current_balance) != {}} {
			dict set body_elements currentBalance $ARGS(-requirement_current_balance)
		}

		if {$ARGS(-requirement_status) != {}} {
			dict set body_elements status $ARGS(-requirement_status)
		}

		##--------END Preparing input dict body elements------#

		set request_name         $CFG(UPDATE_WAGERING_REQ,request_name)
		set request_xmlns        $CFG(UPDATE_WAGERING_REQ,soap,request_xmlns)
		set request_header       $CFG(UPDATE_WAGERING_REQ,soap,request_header)
		set request_header_xmlns $CFG(UPDATE_WAGERING_REQ,soap,request_header_xmlns)

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

### Private procedure START ###
proc core::api::promotion_service::_send_soap_request {
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

	set fn {core::api::promotion_service::_send_soap_request }
	set request_endpoint $CFG(service_endpoint)
	set envelope_name "promotionservice.$request"

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
		error "calling core::soap::send failed from $fn" {} COMMUNICATION_ERROR
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
		core::log::write ERROR {promotion service - error parsing response: [core::soap::print_soap -name $envelope_name -type "received"]}
		core::soap::cleanup -name $envelope_name
		error "$fn: promotion service - error parsing response: - $msg" $::errorInfo $::errorCode
	} else {
		core::soap::cleanup -name $envelope_name
		core::log::write DEBUG {$fn: returning $result}
		return $result
	}
}

#It read the response and try to find some scenario that we could have that can explain the reason because the request failed,
# in the case we are not recognizing the scenario, we trown a generic parsing error
proc core::api::promotion_service::_validate_error_handling envelope_name {

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
		error "Error parsing response promotion service $schema_validation_msg" {} $schema_validation_code
	} else {
		# Do we have a code and message in the common responseHeader?
		if {$status_header_code != {} && $status_header_message != {}} {
			error "Error parsing response promotion service $status_header_message" {} $status_header_code
		} else {
			# Generic error during the parsing.
			error "Error parsing response promotion service" {} GENERIC_PARSING_ERROR
		}
	}
}

## SPECIFIC RESPONSE PARSER Section### 
# response parser for create_wagering_requirement
proc core::api::promotion_service::_parse_response_createWageringRequirement envelope_name {
	variable CFG

	set fn {core::api::promotion_service::_parse_response_createWageringRequirement }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(CREATE_WAGERING_REQ,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
				-name $envelope_name \
				-xpath {//n2:createWageringRequirementResponse/n2:status/@code}] 1]
	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		foreach {param xpath is_attribute} {
			wagering_provider        {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:externalWageringRequirementRef/@provider} 1
			wagering_id              {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:externalWageringRequirementRef/@id} 1
			wagering_creation_date   {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:creationDate} 0
			wagering_initial_balance {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:initialBalance} 0
			wagering_current_balance {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:currentBalance} 0
			wagering_status          {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:status} 0
			wagering_type            {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:type} 0
			wagering_multiplier      {//n2:createWageringRequirementResponse/n2:wageringRequirement/n3:multiplier} 0
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

		if {$wagering_creation_date != {}} {
			set wagering_creation_date [core::date::format_xml_date -date $wagering_creation_date]
		}

		dict set result id              $wagering_id
		dict set result provider        $wagering_provider
		dict set result creation_date   $wagering_creation_date
		dict set result initial_balance $wagering_initial_balance
		dict set result current_balance $wagering_current_balance
		dict set result status          $wagering_status
		dict set result type            $wagering_type
		dict set result multiplier      $wagering_multiplier
	} elseif {$status_body != {}} {
		lassign [core::api::promotion_service::_parse_error_info \
			$envelope_name \
			{//n2:createWageringRequirementResponse/n2:status/@subcode} \
			{//n2:createWageringRequirementResponse/n2:status/n3:specification} \
			$status_body] error_code error_msg

		error $error_msg {} $error_code
	}
	return $result
}

#get_wagering_requirements
proc core::api::promotion_service::_parse_response_getWageringRequirements envelope_name {
	variable CFG

	set fn {core::api::promotion_service::_parse_response_getWageringRequirements }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_WAGERING_REQS,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n2:getWageringRequirementsResponse/n2:status/@code}] 1]

	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wageringRequirements {//n2:getWageringRequirementsResponse/n2:wageringRequirements/n3:wageringRequirement} 0 {} 1 [list \
				wagering_id        {/n3:externalWageringRequirementRef/@id}       1 {} 0 {} \
				wagering_provider  {/n3:externalWageringRequirementRef/@provider} 1 {} 0 {} \
				initial_balance    {/n3:initialBalance}                           0 {} 0 {} \
				current_balance    {/n3:currentBalance}                           0 {} 0 {} \
				status             {/n3:status}                                   0 {} 0 {} \
				creation_date      {/n3:creationDate}                             0 {} 0 {} \
				last_updated       {/n3:lastUpdated}                              0 {} 0 {} \
			] \
		]

		set id_list [list]

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wagering_requirement [dict get $generic_result wageringRequirements] {

			foreach param [list wagering_id wagering_provider initial_balance current_balance status creation_date last_updated] {
				set value [dict get $wagering_requirement $param]
				if {($param == "creation_date" || $param == "last_updated" ) && $value != {}} {
					set value [core::date::format_xml_date -date $value]
				}
				set $param $value
			}

			dict set result $wagering_id $wagering_provider creation_date   $creation_date
			dict set result $wagering_id $wagering_provider last_updated    $last_updated
			dict set result $wagering_id $wagering_provider initial_balance $initial_balance
			dict set result $wagering_id $wagering_provider current_balance $current_balance
			dict set result $wagering_id $wagering_provider status          $status
			lappend id_list "$wagering_id $wagering_provider"
		}
		dict set result id_list $id_list

	} elseif {$status_body != {}} {
		lassign [core::api::promotion_service::_parse_error_info \
			$envelope_name \
			{//n2:getWageringRequirementsResponse/n2:status/@subcode} \
			{//n2:getWageringRequirementsResponse/n2:status/n3:specification} \
			$status_body] error_code error_msg

		error $error_msg {} $error_code
	}
	return $result
}

# response parser for get_wagering_requirement_history
proc core::api::promotion_service::_parse_response_getWageringRequirementHistory envelope_name {
	variable CFG

	set fn {core::api::promotion_service::_parse_response_getWageringRequirementHistory}

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(GET_WAGERING_REQ_HIST,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n2:getWageringRequirementHistoryResponse/n2:status/@code}] 1]
	core::log::write INFO {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			wagering_requirement {//n2:getWageringRequirementHistoryResponse/n2:wageringRequirement} 0 {} 1 [list \
				id       {/n3:externalWageringRequirementRef/@id}       1 {} 0 {} \
				provider {/n3:externalWageringRequirementRef/@provider} 1 {} 0 {} \
			] \
			wagering_requirement_adjustment {//n2:getWageringRequirementHistoryResponse/n2:wageringRequirementAdjustments/n3:wageringRequirementAdjustment} 0 {} 1 [list \
				adjustment_date {/n3:adjustmentDate} 0 {} 0 {} \
				initial_balance {/n3:initialBalance} 0 {} 0 {} \
				balance         {/n3:balance}        0 {} 0 {} \
				type            {/n3:type}           0 {} 0 {} \
				activity        {/n3:activity}       0 {} 1 [list \
					id       {/n3:externalActivityRef/@id}       1 {} 0 {} \
					provider {/n3:externalActivityRef/@provider} 1 {} 0 {} \
				] \
			] \
		] \

		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		foreach wagering_requirement [dict get $generic_result wagering_requirement] {

			foreach param [list id provider] {
				set $param [dict get $wagering_requirement $param]
			}

			dict set result id $id 
			dict set result provider $provider
		}

		set wagering_requirement_adjustments [list]
			
		foreach wagering_requirement_adjustment [dict get $generic_result wagering_requirement_adjustment] {
			set current_adjustment {}
			foreach param {adjustment_date initial_balance balance type activity} {
				set value [dict get $wagering_requirement_adjustment $param]
				if {$param == "adjustment_date" && $value != {}} {
					set value [core::date::format_xml_date -date $value]
				}
				dict set current_adjustment $param $value
			}
			lappend wagering_requirement_adjustments $current_adjustment
		}
		dict set result wagering_requirement_adjustments $wagering_requirement_adjustments
			
	} elseif {$status_body != {}} {
		lassign [core::api::promotion_service::_parse_error_info \
			$envelope_name \
			{//n2:getWageringRequirementHistoryResponse/n2:status/@subcode} \
			{//n2:getWageringRequirementHistoryResponse/n2:status/n3:specification} \
			$status_body] error_code error_msg

		error $error_msg {} $error_code
	}
	return $result
}

# update_wagering_requirement
proc core::api::promotion_service::_parse_response_updateWageringRequirement envelope_name {
	variable CFG

	set fn {core::api::promotion_service::_parse_response_updateWageringRequirement }

	set result {}
	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(UPDATE_WAGERING_REQ,response_namespaces)

	set status_body [lindex [core::soap::get_attributes \
		-name $envelope_name \
		-xpath {//n2:updateWageringRequirementResponse/n2:status/@code}] 1]

	core::log::write DEBUG {$fn - status $status_body}

	if {$status_body == {OK}} {

		# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
		set list_params [list \
			id                 {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:externalWageringRequirementRef/@id}       1 {} 0 {} \
			provider           {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:externalWageringRequirementRef/@provider} 1 {} 0 {} \
			creation_date      {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:creationDate}                             0 {} 0 {} \
			initial_balance    {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:initialBalance}                           0 {} 0 {} \
			current_balance    {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:currentBalance}                           0 {} 0 {} \
			status             {//n2:updateWageringRequirementResponse/n2:wageringRequirement/n3:status}                                   0 {} 0 {} \
		]


		set generic_result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

		set value [dict get $generic_result creation_date]
		if {$value != {}} {
			dict set generic_result creation_date [core::date::format_xml_date -date $value]
		}

		return $generic_result
	} elseif {$status_body != {}} {
		lassign [core::api::promotion_service::_parse_error_info \
			$envelope_name \
			{//n2:updateWageringRequirementResponse/n2:status/@subcode} \
			{//n2:updateWageringRequirementResponse/n2:status/n3:specification} \
			$status_body] error_code error_msg

		error $error_msg {} $error_code
	}
	return $result
}

proc core::api::promotion_service::_parse_error_info {envelope_name subcode_xpath specification_msg_xpath status_code} {

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
proc core::api::promotion_service::_build_request {
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

# <getWageringRequirementHistory xmlns="http://schema.products.sportsbook.openbet.com/promotions" xmlns:promoType="http://schema.products.sportsbook.openbet.com/promotionsTypes" xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
# 	<wageringRequirement>
#		<promoType:externalWageringRequirementdRef id="TheWR" provider="G"/>
#	</wageringRequirement>
#	<fromDate>2014-01-01T00:00:00</fromDate>
#	<toDate>2020-01-01T00:00:00</toDate>
# </getWageringRequirementHistory>
# get_wagering_requirement_history
proc core::api::promotion_service::_create_body_getWageringRequirementHistory {envelope_name request elements} {

	# creating the request body
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
		-elem   {wageringRequirement} \

	core::soap::add_element \
		-name   $envelope_name \
		-parent {wageringRequirement} \
		-elem   {promoType:externalWageringRequirementRef} \
		-attributes [dict get $elements externalWageringRequirementRef] 

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

#	<createWageringRequirement xmlns="http://schema.products.sportsbook.openbet.com/promotions" xmlns:promoType="http://schema.products.sportsbook.openbet.com/promotionsTypes" xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#		<fundingAccount>
#			<!-- .. -->
#			<promoCommonType:externalCustRef id="val" provider="val"/>
#			<promoCommonType:currencyRef id="val"/>
#			<!-- or -->
#			<promoCommonType:fundingAccountRef id="val"/>
#			<!-- .. -->
#		</fundingAccount>
#		<wageringRequirement>
#			<promoType:externalWageringRequirementRef id="2" provider="G"/>
#			<promoType:targetAmount>..</promoType:targetAmount>
#		</wageringRequirement>
#		<contributionFactors>
#			<promoType:contributionFactor type="GGROUP" id="3" factor="100.00"/>
#			<promoType:contributionFactor type="GGROUP" id="3" factor="100.00"/>	
#		</contributionFactors>
#	</createWageringRequirement>
# create body for create_wagering_requirement
proc core::api::promotion_service::_create_body_createWageringRequirement {envelope_name request elements} {

	# creating the request body
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

	# Adding customer/account information
	if {[dict exists $elements externalCustRef]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingAccount} \
			-elem   {promoCommonType:externalCustRef} \
			-attributes [dict get $elements externalCustRef]

		# if the customer id is provided, the currency is mandatory
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

	# adding wagering requriment info 

	set wr_type "STANDARD"
	if {[dict exists $elements wageringOnWinnings] && [string equal "Y" [dict get $elements wageringOnWinnings]]} {
		set wr_type "WINNINGS"
	}

        if {[string equal $wr_type "WINNINGS"]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {wageringRequirement} \
			-attributes [list {type} $wr_type]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {wageringRequirement}
	}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {wageringRequirement} \
		-elem   {promoType:externalWageringRequirementRef} \
		-attributes [dict get $elements externalWageringRequirementRef]

        if {[string equal $wr_type "WINNINGS"]} {
                core::soap::add_element \
                        -name   $envelope_name \
                        -parent {wageringRequirement} \
                        -elem   {promoType:multiplier} \
                        -value  [dict get $elements wageringMultiplier]
	} else {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {wageringRequirement} \
			-elem   {promoType:targetAmount} \
			-value  [dict get $elements targetAmount]
	}

	# adding wagering contribution factors
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {contributionFactors}

	if {[dict exists $elements contributeFactors]} {

		set contribute_index 0
		foreach contribute [dict get $elements contributeFactors] {
			# the label need to be unique, for defaul the soap api use the element as a label.
			set contribute_label "contributionFactors.factor.$contribute_index"
	
			core::soap::add_element \
				-name   $envelope_name \
				-parent {contributionFactors} \
				-elem   {promoType:contributionFactor} \
				-label  $contribute_label \
				-attributes $contribute
	
			incr contribute_index 1
		}
	}
}

# get_wagering_requirements 
proc core::api::promotion_service::_create_body_getWageringRequirements {envelope_name request elements} {

	# creating the request body
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

	# Adding customer/account information
	if {[dict exists $elements externalCustRef]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {fundingAccount} \
			-elem   {promoCommonType:externalCustRef} \
			-attributes [dict get $elements externalCustRef]

		# if the customer id is provided, the currency is mandatory
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

	if {[dict exists $elements requirementStatus]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent $request \
			-elem   {requirementStatus} \
			-value  [dict get $elements requirementStatus]
	}
}

#<?xml version="1.0" ?>
#<updateWageringRequirement xmlns="http://schema.products.sportsbook.openbet.com/promotions"
#	xmlns:promoType="http://schema.products.sportsbook.openbet.com/promotionsTypes"
#	xmlns:promoCommonType="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
#	<username>admin</username>
#	<wageringRequirement>
#	<promoType:externalWageringRequirementRef id="2" provider="G"/>
#	<promoType:initialBalance>600.00</promoType:initialBalance>
#	<promoType:currentBalance>500.00</promoType:currentBalance>
#	<promoType:status>ACTIVE</promoType:status>
#	</wageringRequirement>
#</updateWageringRequirement>
#update_wagering_requirement
proc core::api::promotion_service::_create_body_updateWageringRequirement {envelope_name request elements} {

	# creating the request body
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
		-elem   {username} \
		-value  [dict get $elements username]

	# adding wagering requriment info 
	core::soap::add_element \
		-name   $envelope_name \
		-parent $request \
		-elem   {wageringRequirement}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {wageringRequirement} \
		-elem   {promoType:externalWageringRequirementRef} \
		-attributes [dict get $elements externalWageringRequirementRef]

	if {[dict exists $elements initialBalance]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {wageringRequirement} \
			-elem   {promoType:initialBalance} \
			-value  [dict get $elements initialBalance]
	}

	if {[dict exists $elements currentBalance]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {wageringRequirement} \
			-elem   {promoType:currentBalance} \
			-value  [dict get $elements currentBalance]
	}

	if {[dict exists $elements status]} {
		core::soap::add_element \
			-name   $envelope_name \
			-parent {wageringRequirement} \
			-elem   {promoType:status} \
			-value  [dict get $elements status]
	}
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
proc core::api::promotion_service::_create_envelope {envelope_name request_header request_header_xmlns } {

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
proc core::api::promotion_service::_create_header {
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
