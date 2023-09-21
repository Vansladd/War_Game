# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# emerchants web API harness
#
set pkg_version 1.0
package provide core::harness::api::emerchants $pkg_version

# Dependencies
package require core::api::emerchants  1.0
package require core::log              1.0
package require core::args             1.0
package require core::check            1.0
package require core::stub             1.0
package require core::xml              1.0
package require core::date             1.0

load libOT_Tcl.so
load libOT_Template.so

core::args::register_ns \
	-namespace core::harness::api::emerchants \
	-version   $pkg_version \
	-dependent [list \
		core::api::emerchants \
		core::log \
		core::args \
		core::check \
		core::stub \
		core::xml \
	]

namespace eval core::harness::api::emerchants  {
	variable CFG
	variable CORE_DEF
	variable HARNESS_DATA

	set CORE_DEF(request) [list -arg -request -mand 1 -check ASCII -desc {Request data}]

	dict set HARNESS_DATA CREATE_ACCOUNT template success {
		<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
			<s:Body>
				<CreateAccountResponse xmlns="http://tempuri.org/">
					<CreateAccountResult
						xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
						xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						<ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
						<ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
						<Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">##TP_Success##</Success>
						<a:AccountId xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
							<b:ExternalAccountId>##TP_ExternalAccountId##</b:ExternalAccountId>
						</a:AccountId>
					</CreateAccountResult>
				</CreateAccountResponse>
			</s:Body>
		</s:Envelope>
	}

	# Code                     90
	# Description              {Operation failed due to invalid parameters}
	# ExtendedErrorInformation {Failed validation for request fields: ClientDetails.City and ClientDetails.Suburb. Please use suburb instead of city.}
	dict set HARNESS_DATA CREATE_ACCOUNT template failed {
		<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
			<s:Body>
				<CreateAccountResponse xmlns="http://tempuri.org/">
					<CreateAccountResult
						xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
						xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						<ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">
							<_x003C_Code_x003E_k__BackingField>##TP_Code##</_x003C_Code_x003E_k__BackingField>
							<_x003C_Description_x003E_k__BackingField>##TP_Description##</_x003C_Description_x003E_k__BackingField>
						</ErrorCode>
						<ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">##TP_ExtendedErrorInformation##</ExtendedErrorInformation>
						<Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">##TP_Success##</Success>
						<a:AccountId xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers" i:nil="true"/>
					</CreateAccountResult>
				</CreateAccountResponse>
			</s:Body>
		</s:Envelope>
	}


	dict set HARNESS_DATA CREATE_ACCOUNT username WS_Sportsbet_DEV_INT_LT_CH success {
		Success {true}
		ExternalAccountId {XGNV80D3A}
	}

	dict set HARNESS_DATA CREATE_ACCOUNT username WS_Sportsbet_DEV_INT_LT_CH failed  {
		Success                  {false}
		Code                     {90}
		Description              {Operation failed due to invalid parameters}
		ExtendedErrorInformation {Failed validation for request fields: ClientDetails.City and ClientDetails.Suburb. Please use suburb instead of city.}
	}


	dict set HARNESS_DATA GET_ACCOUNT_STATUS template success {
		<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
			<s:Body>
				<GetAccountStatusResponse xmlns="http://tempuri.org/">
					<GetAccountStatusResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						<ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
						<ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
						<Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">##TP_Success##</Success>
						<a:Balance>##TP_Balance##</a:Balance>
						<a:Status xmlns:b="http://schemas.datacontract.org/2004/07/EML.Data.Common">
							<b:_x003C_Code_x003E_k__BackingField>##TP_Code##</b:_x003C_Code_x003E_k__BackingField>
							<b:_x003C_Description_x003E_k__BackingField>##TP_Description##</b:_x003C_Description_x003E_k__BackingField>
							<b:_x003C_IsActive_x003E_k__BackingField>##TP_IsActive##</b:_x003C_IsActive_x003E_k__BackingField>
							<b:_x003C_LegacyCode_x003E_k__BackingField>##TP_LegacyCode##</b:_x003C_LegacyCode_x003E_k__BackingField>
						</a:Status>
					</GetAccountStatusResult>
				</GetAccountStatusResponse>
			</s:Body>
		</s:Envelope>
	}

	dict set HARNESS_DATA GET_ACCOUNT_STATUS template failed {
		<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
			<s:Body>
				<GetAccountStatusResponse xmlns="http://tempuri.org/">
					<GetAccountStatusResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						<ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">
							<_x003C_Code_x003E_k__BackingField>##TP_Code##</_x003C_Code_x003E_k__BackingField>
							<_x003C_Description_x003E_k__BackingField>##TP_Description##</_x003C_Description_x003E_k__BackingField>
						</ErrorCode>
						<ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true">##TP_ExtendedErrorInformation##</ExtendedErrorInformation>
						<Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">##TP_Success##</Success>
						<a:Balance>##TP_Balance##</a:Balance>
						<a:Status xmlns:b="http://schemas.datacontract.org/2004/07/EML.Data.Common" i:nil="true"></a:Status>
					</GetAccountStatusResult>
				</GetAccountStatusResponse>
			</s:Body>
		</s:Envelope>
	}

	dict set HARNESS_DATA GET_ACCOUNT_STATUS username WS_Sportsbet_DEV_INT_LT_CH success {
		Success     {true}
		Balance     {0}
		Code        {1}
		Description {Pre-active}
		IsActive    {false}
		LegacyCode  {PA}
	}

	dict set HARNESS_DATA GET_ACCOUNT_STATUS username WS_Sportsbet_DEV_INT_LT_CH success {
		Success     {true}
		Balance     {10}
		Code        {2}
		Description {Active}
		IsActive    {true}
		LegacyCode  {AC}
	}

	dict set HARNESS_DATA GET_ACCOUNT_STATUS username WS_Sportsbet_DEV_INT_LT_CH failed {
		Success                  {false}
		Code                     {24}
		Description              {Card not owned by company}
		ExtendedErrorInformation {}
		Balance                  {0}
		Status                   {}
	}

	dict set HARNESS_DATA UPDATE_ACCOUNT_DETAILS {
		<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
			<s:Body>
				<UpdateAccountDetailsResponse xmlns="http://tempuri.org/">
					<UpdateAccountDetailsResult
						xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
						xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
						<Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
						<a:AccountId xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers" i:nil="true"/>
					</UpdateAccountDetailsResult>
				</UpdateAccountDetailsResponse>
			</s:Body>
		</s:Envelope>
	}
}

# 
# init
#
# Register eMerchants service harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::api::emerchants::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg EMERCHANTS_SERVICE_HARNESS_ENABLED -default 0 -desc {Enable the emerchants harness}] \
	] \
	-body \
{
	if {!$ARGS(-enabled)} {
		core::log::xwrite -msg {eMerchants harness - available though disabled} -colour yellow
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
		-scope_key       {::core::api::emerchants::create_account} \
		-use_body_return 1 \
		-body {
			array set ARGS [core::args::check core::socket::send_req {*}$args]

			return [core::harness::api::emerchants::_process_request \
				-requestName {CreateAccount} \
				-request $ARGS(-req)]
		}

	core::stub::set_override \
		-proc_name       {core::socket::send_req} \
		-scope           proc \
		-scope_key       {::core::api::emerchants::get_account_status} \
		-use_body_return 1 \
		-body {
			array set ARGS [core::args::check core::socket::send_req {*}$args]

			return [core::harness::api::emerchants::_process_request \
				-requestName {GetAccountStatus} \
				-request $ARGS(-req)]
		}

	core::stub::set_override \
		-proc_name       {core::socket::send_req} \
		-scope           proc \
		-scope_key       {::core::api::emerchants::update_account_details} \
		-use_body_return 1 \
		-body {
			array set ARGS [core::args::check core::socket::send_req {*}$args]

			return [core::harness::api::emerchants::_process_request \
				-requestName {UpdateAccountDetails} \
				-request $ARGS(-req)]
		}

	core::stub::set_override \
		-proc_name       {core::socket::req_info} \
		-scope           proc \
		-scope_key       {::core::api::emerchants::update_account_details} \
		-use_body_return 1 \
		-body {
			return [core::harness::api::emerchants::_get_response] 
		}

	core::stub::set_override \
		-proc_name       {core::socket::clear_req} \
		-scope           proc \
		-scope_key       {::core::api::emerchants::update_account_details} \
		-use_body_return 1 \
		-body {
			return 
		}


	core::log::xwrite -msg {eMerchants Harness - available and enabled} -colour yellow
}

core::args::register \
	-proc_name {core::harness::api::emerchants::_process_request} \
	-desc      {Main request processing proc to decide which response to send back} \
	-args      [list \
		[list -arg -requestName -mand 1 -check ASCII -desc {The requestName to be processed}] \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body \
{
	variable HARNESS_DATA

	set requestName $ARGS(-requestName)
	set request     $ARGS(-request)

	return [_prepare_response_$requestName -request $request]
}

core::args::register \
	-proc_name {core::harness::api::emerchants::_prepare_response_CreateAccount} \
	-desc      {prepare the result for CreateAccount} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body \
{
	variable HARNESS_DATA

	lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

	set username [core::xml::extract_data \
		-node    $doc \
		-xpath   {//*[local-name()='Username']/@id} \
		-default {WS_Sportsbet_DEV_INT_LT_CH} \
		-return_list 1]

	set template [dict keys [dict get $HARNESS_DATA CREATE_ACCOUNT data $username]]
	set response_data [dict get $HARNESS_DATA CREATE_ACCOUNT data $username $template]

	foreach {key value} $response_data {
		tpBindString $key $value
	}

	set response_get_balance [tpStringPlay -tostring [dict get $HARNESS_DATA CREATE_ACCOUNT template $template]]
	dict set HARNESS_DATA response $response_get_balance

	return [list 1 OK 1]
}

core::args::register \
	-proc_name {core::harness::api::emerchants::_prepare_response_GetAccountStatus} \
	-desc      {prepare the result for GetAccountStatus} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body \
{
	variable HARNESS_DATA

	lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

	set username [core::xml::extract_data \
		-node    $doc \
		-xpath   {//*[local-name()='Username']/@id} \
		-default {WS_Sportsbet_DEV_INT_LT_CH} \
		-return_list 1]

	set template [dict keys [dict get $HARNESS_DATA GET_ACCOUNT_STATUS data $username]]
	set response_data [dict get $HARNESS_DATA GET_ACCOUNT_STATUS data $username $template]

	foreach {key value} $response_data {
		tpBindString $key $value
	}

	set response_get_balance [tpStringPlay -tostring [dict get $HARNESS_DATA GET_ACCOUNT_STATUS template $template]]
	dict set HARNESS_DATA response $response_get_balance

	return [list 1 OK 1]
}

core::args::register \
	-proc_name {core::harness::api::emerchants::_prepare_response_UpdateAccountDetails} \
	-desc      {prepare the result for UpdateAccountDetails} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body \
{
	return [list 1 OK 1]
}

core::args::register \
	-proc_name {core::harness::api::emerchants::_get_response} \
	-desc      {Gets the response prepared by _process_request} \
	-body \
{
	variable HARNESS_DATA

	return [dict get $HARNESS_DATA UPDATE_ACCOUNT_DETAILS]
}
