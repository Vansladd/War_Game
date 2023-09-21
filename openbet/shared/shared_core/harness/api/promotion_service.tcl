# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# promotion service harness
#
set pkg_version 1.0
package provide core::harness::api::promotion_service $pkg_version

# Dependencies
package require core::api::promotion_service 1.0
package require core::log                    1.0
package require core::args                   1.0
package require core::check                  1.0
package require core::stub                   1.0
package require core::xml                    1.0

load libOT_Tcl.so
load libOT_Template.so

core::args::register_ns \
	-namespace core::harness::api::promotion_service \
	-version   $pkg_version \
	-dependent [list \
		core::api:promotion_service \
		core::log \
		core::args \
		core::check \
		core::stub \
		core::xml \
	]

namespace eval core::harness::api::promotion_service  {
	variable CFG
	variable CORE_DEF
	variable HARNESS_DATA

	set CORE_DEF(request) [list -arg -request -mand 1 -check ASCII -desc {Request data}]

	dict set HARNESS_DATA CREATEWAGERINGREQUIREMENT template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:createWageringRequirementResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
							xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
							xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##"/>
					<ns2:wageringRequirement>
						<ns3:externalWageringRequirementRef id="##TP_wagering.id##" provider="##TP_wagering.provider##" />
						<ns3:creationDate>##TP_wagering.creationDate##</ns3:creationDate>
						<ns3:initialBalance>##TP_wagering.initial_balance##</ns3:initialBalance>
						<ns3:currentBalance>##TP_wagering.current_balance##</ns3:currentBalance>
						<ns3:status>##TP_wagering.status##</ns3:status>
						<ns3:type>##TP_wagering.type##</ns3:type>
						<ns3:multiplier>##TP_wagering.multiplier##</ns3:multiplier>
					</ns2:wageringRequirement>
				</ns2:createWageringRequirementResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CREATEWAGERINGREQUIREMENT template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:createWageringRequirementResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
							xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
							xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</ns2:status>
				</ns2:createWageringRequirementResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETWAGERINGREQUIREMENTS template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
							xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:getWageringRequirementsResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
							xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
							xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##"/>
					<ns2:wageringRequirements>
						<ns3:wageringRequirement>
							<ns3:externalWageringRequirementRef id="##TP_wagering.id##" provider="##TP_wagering.provider##" />
							<ns3:creationDate>##TP_wagering.creation_date##</ns3:creationDate>
							<ns3:lastUpdated>##TP_wagering.last_updated##</ns3:lastUpdated>
							<ns3:initialBalance>##TP_wagering.initial_balance##</ns3:initialBalance>
							<ns3:currentBalance>##TP_wagering.current_balance##</ns3:currentBalance>
							<ns3:status>##TP_wagering.status##</ns3:status>
						</ns3:wageringRequirement>
					</ns2:wageringRequirements>
				</ns2:getWageringRequirementsResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETWAGERINGREQUIREMENTS template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
							xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:getWageringRequirementsResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
							xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
							xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</ns2:status>
				</ns2:getWageringRequirementsResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	# getWageringRequirementHistory details

	dict set HARNESS_DATA GETWAGERINGREQUIREMENTHISTORY template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:getWageringRequirementHistoryResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
							xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
							xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##"/>
					<ns2:wageringRequirement>
						<ns3:externalWageringRequirementRef id="##TP_wagering.id##" provider="##TP_wagering.provider##" />
					</ns2:wageringRequirement>
					<ns2:wageringRequirementAdjustments>
						<ns3:wageringRequirementAdjustment>
							<ns3:adjustmentDate>##TP_wagering.adjustment_date##</ns3:adjustmentDate>
							<ns3:type>##TP_wagering.type##</ns3:type>
							<ns3:initialBalance>##TP_wagering.initial_balance##</ns3:initialBalance>
							<ns3:balance>##TP_wagering.balance##</ns3:balance>
							<ns3:activity>
								<ns3:externalActivityRef id="##TP_wagering.external_activity_id##" provider="##TP_wagering.provider##" />
							</ns3:activity>
						</ns3:wageringRequirementAdjustment>
					</ns2:wageringRequirementAdjustments>
				</ns2:getWageringRequirementHistoryResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA UPDATEWAGERINGREQUIREMENT template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
							xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<ns2:updateWageringRequirementResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promotionsTypes"
						xmlns:ns2="http://schema.products.sportsbook.openbet.com/promotions"
						xmlns="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<ns2:status code="##TP_status.code##"/>
					<ns2:wageringRequirement>
						<ns3:externalWageringRequirementRef id="##TP_wagering.id##" provider="##TP_wagering.provider##" />
						<ns3:creationDate>##TP_wagering.creation_date##</ns3:creationDate>
						<ns3:initialBalance>##TP_wagering.initial_balance##</ns3:initialBalance>
						<ns3:currentBalance>##TP_wagering.current_balance##</ns3:currentBalance>
						<ns3:status>##TP_wagering.status##</ns3:status>
					</ns2:wageringRequirement>
			</ns2:updateWageringRequirementResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}
	# Below are the response data definitions keyed by the currency code
	# e.g.
	# dict set HARNESS_DATA request data wallettype template {response values}

	dict set HARNESS_DATA CREATEWAGERINGREQUIREMENT data USD failed  {status.code REQUEST_VALIDATION  service_error.code {INVALID_REQUEST}  service_error.message {Internal Error}  status.subcode INVALID_REQUEST status.specification {Violations (1): INVALID_RESTRICTION - Provider must not be empty.}}
	dict set HARNESS_DATA CREATEWAGERINGREQUIREMENT data EUR success [list status.code {OK} wagering.status {ACTIVE} wagering.creationDate {2014-05-21T10:34:41}]
	dict set HARNESS_DATA CREATEWAGERINGREQUIREMENT data GBP success [list status.code {OK} wagering.status {ACTIVE} wagering.creationDate {2013-05-21T10:34:41}]

	dict set HARNESS_DATA GETWAGERINGREQUIREMENTS data USD failed  {status.code REQUEST_VALIDATION  service_error.code {INVALID_REQUEST}  service_error.message {Internal Error}  status.subcode INVALID_REQUEST status.specification {Violations (1): INVALID_RESTRICTION - Provider must not be empty.}}
	dict set HARNESS_DATA GETWAGERINGREQUIREMENTS data EUR success [list \
		status.code {OK} wagering.status {EXPIRED} \
		wagering.initial_balance {100.00} wagering.current_balance {0.00} wagering.creation_date {2013-12-22T12:33:11} wagering.last_updated {2014-05-15T12:15:11} \
	]
	dict set HARNESS_DATA GETWAGERINGREQUIREMENTS data GBP success [list \
		status.code {OK} wagering.status {ACTIVE} \
		wagering.initial_balance {100.00} wagering.current_balance {50.00} wagering.creation_date {2013-01-14T14:13:41} wagering.last_updated {2014-03-12T11:45:12} \
	]

	dict set HARNESS_DATA GETWAGERINGREQUIREMENTHISTORY data success [list \
		status.code {OK} \
		wagering.adjustment_date {2001-02-02T14:17:59} wagering.type {ACTIVITY} \
		wagering.initial_balance {100.00} wagering.balance {90.00} \
	]

	dict set HARNESS_DATA UPDATEWAGERINGREQUIREMENT data success [list \
		status.code {OK} wagering.status {ACTIVE} \
		wagering.initial_balance {100.00} wagering.current_balance {50.00} wagering.creation_date {2013-01-14T14:13:41} \
	]
}

core::args::register \
	-proc_name core::harness::api::promotion_service::expose_magic \
	-body {
		variable HARNESS_DATA
		set i 0

		set MAGIC(0,header) {Currency type}
		set MAGIC(1,header) {Template scenario}
		set MAGIC(2,header) {Response Data}

		foreach request_type [dict keys $HARNESS_DATA] {
			set MAGIC($i,request_type) "$request_type promotion service"
			set j 0

			foreach key [dict keys [dict get $HARNESS_DATA $request_type data]] {

				foreach template [dict keys [dict get $HARNESS_DATA $request_type data $key]] {
					set response_data [dict get $HARNESS_DATA $request_type data $key $template]
				}

				set MAGIC($i,$j,0,column) $key
				set MAGIC($i,$j,1,column) $template
				set MAGIC($i,$j,2,column) $response_data
				core::log::write DEV {$request_type - $key - $template - $response_data}
				incr j
			}

			set MAGIC($i,num_rows) $j
			incr i
		}

		set MAGIC(num_requests) $i
		set MAGIC(num_columns) 3

		return [array get MAGIC]
	}

#
# init
#
# Register promotion service harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::api::promotion_service::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg PROMOTION_SERVICE_HARNESS_ENABLED -default 0 -desc {Enable the promotion service harness}] \
	] \
	-body {
		if {!$ARGS(-enabled)} {
			core::log::xwrite -msg {Promotion service Harness - available though disabled} -colour yellow
			return
		}
		variable CFG

		core::stub::init

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				core::socket   send_req \
				core::socket   req_info \
				core::socket   clear_req \
			]

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::create_wagering_requirement} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::promotion_service::_process_request \
					-requestName {createWageringRequirement} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirements} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::promotion_service::_process_request \
					-requestName {getWageringRequirements} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::create_wagering_requirement} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::promotion_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirements} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::promotion_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::create_wagering_requirement} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirements} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirement_history} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::promotion_service::_process_request \
					-requestName {getWageringRequirementHistory} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirement_history} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::promotion_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::get_wagering_requirement_history} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::update_wagering_requirement} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::promotion_service::_process_request \
					-requestName {updateWageringRequirement} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::update_wagering_requirement} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::promotion_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::promotion_service::update_wagering_requirement} \
			-return_data     {}

		core::log::xwrite -msg {Promotion service Harness - available and enabled} -colour yellow
	}

core::args::register \
	-proc_name {core::harness::api::promotion_service::_process_request} \
	-desc      {Main request processing proc to decide which response to send back} \
	-args      [list \
		[list -arg -requestName -mand 1 -check ASCII -desc {The requestName to be processed}] \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		set requestName $ARGS(-requestName)
		set request     $ARGS(-request)

		return [_prepare_response_$requestName -request $request]
	}

core::args::register \
	-proc_name {core::harness::api::promotion_service::_prepare_response_createWageringRequirement} \
	-desc      {prepare the result for createWageringRequirement} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set id [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@id} \
				-return_list 1]

		set provider [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@provider} \
				-return_list 1]

		set balance [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='targetAmount']} \
			-return_list 1]

		set multiplier [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='multiplier']} \
			-return_list 1]

		set type [core::xml::extract_data \
                        -node    $doc \
                        -xpath   {//*[local-name()='wageringRequirement']/@type} \
			-default "STANDARD" \
                        -return_list 1]

		set template [dict keys [dict get $HARNESS_DATA CREATEWAGERINGREQUIREMENT data $currency]]
		set response_data [dict get $HARNESS_DATA CREATEWAGERINGREQUIREMENT data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString {wagering.id} $id
		tpBindString {wagering.provider} $provider
		tpBindString {wagering.initial_balance} $balance
		tpBindString {wagering.current_balance} $balance
		tpBindString {wagering.multiplier} $multiplier
		tpBindString {wagering.type} $type

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CREATEWAGERINGREQUIREMENT template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::promotion_service::_prepare_response_getWageringRequirements} \
	-desc      {prepare the result for getWageringRequirements} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set id 1

		set provider G

		if {![dict exists $HARNESS_DATA GETWAGERINGREQUIREMENTS data $currency]} {
			set currency GBP
		}

		set template [dict keys [dict get $HARNESS_DATA GETWAGERINGREQUIREMENTS data $currency]]
		set response_data [dict get $HARNESS_DATA GETWAGERINGREQUIREMENTS data $currency $template]

		core::log::write ERROR $response_data

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString {wagering.id} $id
		tpBindString {wagering.provider} $provider

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA GETWAGERINGREQUIREMENTS template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::promotion_service::_prepare_response_getWageringRequirementHistory} \
	-desc      {prepare the result for getWageringRequirementHistory} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set id [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@id} \
				-return_list 1]

		set provider [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@provider} \
				-return_list 1]
		
		set response_data [dict get $HARNESS_DATA GETWAGERINGREQUIREMENTHISTORY data success]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString {wagering.id} $id
		tpBindString {wagering.provider} $provider
		tpBindString {wagering.external_activity_id} $id
		tpBindString {wagering.provider} $provider

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA GETWAGERINGREQUIREMENTHISTORY]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::promotion_service::_prepare_response_updateWageringRequirement} \
	-desc      {prepare the result for updateWageringRequirement, always return success} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set id [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@id} \
				-return_list 1]

		set provider [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalWageringRequirementRef']/@provider} \
				-return_list 1]

		set initial_balance [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='initialBalance']} \
			-default {} \
			-return_list 1]

		set current_balance [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currentBalance']} \
			-default {} \
			-return_list 1]

		set status [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='status']} \
			-default {} \
			-return_list 1]


		set response_data [dict get $HARNESS_DATA UPDATEWAGERINGREQUIREMENT data success]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString {wagering.id} $id
		tpBindString {wagering.provider} $provider
		if {$initial_balance!= {}} {
			tpBindString {wagering.initial_balance} $initial_balance
		}
		if {$current_balance!= {}} {
			tpBindString {wagering.current_balance} $current_balance
		}
		if {$status!= {}} {
			tpBindString {wagering.status} $status
		}

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA UPDATEWAGERINGREQUIREMENT template success]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

#
# _get_response
#
# Simply returns the prepared response. After calling any prepared
# response in the dictionary will be cleared
#
core::args::register \
	-proc_name {core::harness::api::promotion_service::_get_response} \
	-desc      {Gets the response prepared by _process_request} \
	-body {
		variable HARNESS_DATA

		set response [dict get $HARNESS_DATA response]

		dict unset HARNESS_DATA response

		return $response
	}
