#
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

# eMerchants SOAP API client
#
# Public procedures
# =================
# core::api::emerchants::init
# core::api::emerchants::create_account
# core::api::emerchants::update_account_details
# core::api::emerchants::get_account_status
# core::api::emerchants::get_account_details
# core::api::emerchants::get_transaction_history
# core::api::emerchants::transfer
# core::api::emerchants::activate_card
# core::api::emerchants::deactivate_card
# core::api::emerchants::ping
# core::api::emerchants::translate_transaction_type_id
#
# NOTE: the word operations (op) and requests are used interchangebaly in this
# file. This is mainly due to the way its called withing eMerchants
# terminology.

set pkg_version 1.0

package provide core::api::emerchants $pkg_version

package require core::log    1.0
package require core::util   1.0
package require core::check  1.0
package require core::args   1.0
package require core::gc     1.0
package require core::soap   1.0
package require core::date   1.0

core::args::register_ns \
	-namespace core::api::emerchants \
	-version   $pkg_version \
	-desc      {eMerchants SOAP services API} \
	-dependent [list \
		core::log \
		core::soap \
	] \
	-docs xml/api/emerchants.xml

namespace eval ::core::api::emerchants {
	variable CFG
	variable INIT
	variable CORE_DEV
	variable TRANS_TYPES
	variable SOAP_AUTH

	# SOAP service required credentials
	set CORE_DEF(soap_username)             [list -arg -soap_username      -mand 1 -check STRING   -desc {SOAP service username}]
	set CORE_DEF(soap_password)             [list -arg -soap_password      -mand 1 -check STRING   -desc {SOAP service password}]

	# default arguments setup
	set CORE_DEF(ext_id)                   [list -arg -ext_id              -mand 1 -check ASCII    -desc {external id}]
	set CORE_DEF(ext_id,opt)               [list -arg -ext_id              -mand 0 -check ASCII    -desc {external id (optional)}]
	set CORE_DEF(src_ext_id)               [list -arg -src_ext_id          -mand 1 -check ASCII    -desc {source external id}]
	set CORE_DEF(src_ext_id,opt)           [list -arg -src_ext_id          -mand 0 -check ASCII    -desc {source external id (optional)}]
	set CORE_DEF(src_ref)                  [list -arg -src_ref             -mand 1 -check STRING   -desc {Source reference text}]
	set CORE_DEF(src_ref,opt)              [list -arg -src_ref             -mand 0 -check STRING   -desc {Source reference text (optional)}]
	set CORE_DEF(dest_ext_id)              [list -arg -dest_ext_id         -mand 1 -check STRING   -desc {destination external id}]
	set CORE_DEF(dest_ext_id,opt)          [list -arg -dest_ext_id         -mand 0 -check STRING   -desc {destination external id (optional)}]
	set CORE_DEF(dest_ref)                 [list -arg -dest_ref            -mand 1 -check STRING   -desc {Destination reference text}]
	set CORE_DEF(dest_ref,opt)             [list -arg -dest_ref            -mand 0 -check STRING   -desc {Destination reference text (optiona)}]
	set CORE_DEF(title)                    [list -arg -title               -mand 1 -check STRING   -desc {Customer's title}]
	set CORE_DEF(firstname)                [list -arg -firstname           -mand 1 -check STRING   -desc {Customer's first name}]
	set CORE_DEF(lastname)                 [list -arg -lastname            -mand 1 -check STRING   -desc {Customer's last name}]
	set CORE_DEF(emailaddress)             [list -arg -emailaddress        -mand 1 -check STRING   -desc {Customer's emailaddress}]
	set CORE_DEF(emailaddress,opt)         [list -arg -emailaddress        -mand 0 -check STRING   -desc {Customer's emailaddress (optional)}]
	set CORE_DEF(dateofbirth)              [list -arg -dateofbirth         -mand 1 -check STRING   -desc {Customer's date of birth}]
	set CORE_DEF(dateofbirth,opt)          [list -arg -dateofbirth         -mand 0 -check STRING   -desc {Customer's date of birth (optional)}]
	set CORE_DEF(phonenumber)              [list -arg -phonenumber         -mand 1 -check STRING   -desc {Customer's phonenumber number}]
	set CORE_DEF(phonenumber,opt)          [list -arg -phonenumber         -mand 0 -check STRING   -desc {Customer's phonenumber number (optional)}]
	set CORE_DEF(mobilenumber)             [list -arg -mobilenumber        -mand 1 -check STRING   -desc {Customer's mobile number}]
	set CORE_DEF(mobilenumber,opt)         [list -arg -mobilenumber        -mand 0 -check STRING   -desc {Customer's mobile number (optional)}]
	set CORE_DEF(country)                  [list -arg -country             -mand 1 -check STRING   -desc {Customer's country}]
	set CORE_DEF(country,opt)              [list -arg -country             -mand 0 -check STRING   -desc {Customer's country (optional)}]
	set CORE_DEF(state)                    [list -arg -state               -mand 1 -check STRING   -desc {Customer's state}]
	set CORE_DEF(state,opt)                [list -arg -state               -mand 0 -check STRING   -desc {Customer's state (optional)}]
	set CORE_DEF(city)                     [list -arg -city                -mand 1 -check STRING   -desc {Customer's city}]
	set CORE_DEF(city,opt)                 [list -arg -city                -mand 0 -check STRING   -desc {Customer's city (optional)}]
	set CORE_DEF(suburb)                   [list -arg -suburb              -mand 1 -check STRING   -desc {Customer's suburb}]
	set CORE_DEF(suburb,opt)               [list -arg -suburb              -mand 0 -check STRING   -desc {Customer's suburb (optional)}]
	set CORE_DEF(addressline1)             [list -arg -addressline1        -mand 1 -check STRING   -desc {Customer's address line 1}]
	set CORE_DEF(addressline1,opt)         [list -arg -addressline1        -mand 0 -check STRING   -desc {Customer's address line 1 (optional)}]
	set CORE_DEF(addressline2)             [list -arg -addressline2        -mand 1 -check STRING   -desc {Customer's address line 2}]
	set CORE_DEF(addressline2,opt)         [list -arg -addressline2        -mand 0 -check STRING   -desc {Customer's address line 2 (optional)}]
	set CORE_DEF(postcode)                 [list -arg -postcode            -mand 1 -check STRING   -desc {Customer's postcode}]
	set CORE_DEF(postcode,opt)             [list -arg -postcode            -mand 0 -check STRING   -desc {Customer's postcode (optional)}]
	set CORE_DEF(start_date)               [list -arg -start_date          -mand 1 -check DATETIME -desc {Start time}]
	set CORE_DEF(start_date,opt)           [list -arg -start_date          -mand 0 -check DATETIME -desc {Start time (optional)}]
	set CORE_DEF(end_date)                 [list -arg -end_date            -mand 1 -check DATETIME -desc {End Time}]
	set CORE_DEF(end_date,opt)             [list -arg -end_date            -mand 0 -check DATETIME -desc {End Time (optional)}]
	set CORE_DEF(trans_type_id)            [list -arg -trans_type_id       -mand 1 -check UINT     -desc {Transaction Type ID}]
	set CORE_DEF(trans_type_id,opt)        [list -arg -trans_type_id       -mand 0 -check UINT     -desc {Transaction Type ID (optional)}]
	set CORE_DEF(initial_load_amount)      [list -arg -initial_load_amount -mand 1 -check UINT     -desc {Initial load amount on cash-card}]
	set CORE_DEF(initial_load_amount,opt)  [list -arg -initial_load_amount -mand 0 -check UINT     -desc {Initial load amount on cash-card (optional)}]
	set CORE_DEF(amount)                   [list -arg -amount              -mand 1 -check DECIMAL  -desc {Amount to transfer}]
	set CORE_DEF(amount,opt)               [list -arg -amount              -mand 0 -check DECIMAL  -desc {Amount to transfer (optional)}]
	set CORE_DEF(detail_flags)             [list -arg -detail_flags        -mand 1 -check {ENUM -args {AccountOnly ClientDetails CardNumber Cvv All}}                -desc {Details required by GetAccountDetails request}]
	set CORE_DEF(detail_flags,opt)         [list -arg -detail_flags        -mand 0 -check {ENUM -args {AccountOnly ClientDetails CardNumber Cvv All}} -default {All} -desc {Details required by GetAccountDetails request (optional)}]
	set CORE_DEF(reason_code)              [list -arg -reason_code         -mand 1 -check {ENUM -args {3 5}}                                          -default {3}   -desc {ReasonCode for CashCard deactivation. 3 - Inactive, 5 - Cancelled / Closed.}]
	set CORE_DEF(reason_code,opt)          [list -arg -reason_code         -mand 0 -check {ENUM -args {3 5}}                                          -default {3}   -desc {ReasonCode for CashCard deactivation  3 - Inactive, 5 - Cancelled / Closed. (optional)}]

	# Transaction Types
	#   id    category             description
	set CORE_DEF(def_trans_types) {
		1101  {ATM}                {ATM Cash Withdrawal}
		1104  {ATM Reversal}       {ATM Reversal}
		1124  {ATM Reversal}       {ATM Clearing Reversal}
		3120  {Activation}         {Card Activation}
		3121  {Activation}         {Make Card Inactive}
		3123  {Activation}         {Activate Card}
		3130  {Activation}         {Load Activation Fee}
		1901  {Adjustment}         {Debit Adjustment}
		2901  {Adjustment}         {Credit}
		1106  {Balance}            {ATM Balance Inquiry}
		1114  {Cleared ATM}        {ATM Clearing}
		1116  {Cleared Credit}     {POS Credit}
		1115  {Cleared POS}        {POS Clearing}
		1117  {Credit}             {Clearing Credit Back}
		2404  {Credit}             {Incoming Bank to Card Transfer}
		2942  {Credit}             {Bpay Fund Load}
		1945  {Debit}              {Debit}
		4101  {Decline}            {ATM Withdrawal - Declined}
		4105  {Decline}            {POS Purchase - Declined}
		4106  {Decline}            {ATM Balance Inq - Declined}
		4112  {Decline}            {Incorrect PIN}
		4118  {Decline}            {POS Authorisation Purchase - Declined}
		4805  {Decline}            {Feature Unsupported}
		4812  {Decline}            {Velocity Limit Exceeded}
		2980  {Direct Entry}       {Direct Entry Out}
		3131  {Fee}                {Charge Maintenance Fee (Monthly)}
		3132  {Fee}                {Monthly Inactivity Fee}
		1103  {POS}                {POS Purchase advice}
		1105  {POS}                {POS Purchase}
		1118  {POS Authorisation}  {POS Authorisation Purchase}
		1107  {POS Reversal}       {POS Reversal}
		1120  {POS Reversal}       {POS Authorisation Purchase Reversal}
		1125  {POS Reversal}       {POS Clearing Reversal}
		2902  {Transfer}           {Card to Card Transfer}
		2917  {Transfer}           {Funds Transfer}
		2919  {Transfer}           {Transfer}
		2925  {Transfer}           {Funds Transfer}
		2934  {Transfer}           {Breakage}
		2981  {Transfer}           {BPay Out}
		3003  {Update}             {Update Card Status}
		3013  {Update}             {Update Velocity}
		3022  {Update}             {Update Cardholder Information}
	}

	set INIT 0
}

# initialise
core::args::register \
	-proc_name core::api::emerchants::init \
	-desc {Initialise eMerchants SOAP API package} \
	-args [list \
		[list -arg -service_base_url    -mand 0 -check STRING -default_cfg EMERCHANTS_SERVICE_BASE_URL    -default {}                     -desc {base url of eMerchants service}] \
		[list -arg -trans_types         -mand 0 -check STRING -default_cfg EMERCHANTS_TRANS_TYPES         -default {}                     -desc {Emerchants transaction types. see CORE_DEF(def_trans_types)}] \
		[list -arg -trans_hist_days     -mand 0 -check STRING -default_cfg EMERCHANTS_TRANS_HIST_DAYS     -default {-14}                  -desc {Number of days in past from where the transaction history is requested from emerchants}] \
		[list -arg -date_format         -mand 0 -check STRING -default_cfg EMERCHANTS_DATE_FORMAT         -default {%Y-%m-%dT%T}          -desc {Format of emerchants transaction dates}] \
		[list -arg -timezone            -mand 0 -check STRING -default_cfg EMERCHANTS_TIMEZONE            -default {:Australia/Melbourne} -desc {Timezone of dates}] \
		[list -arg -conn_timeout        -mand 0 -check UINT   -default_cfg EMERCHANTS_CONN_TIMEOUT        -default 10000                  -desc {Default connection timeout to eMerchant servers}] \
		[list -arg -def_req_timeout     -mand 0 -check UINT   -default_cfg EMERCHANTS_DEF_TIMEOUT         -default 10000                  -desc {Default request timeout to eMerchant service endpoints}] \
		[list -arg -req_timeouts        -mand 0 -check UINT   -default_cfg EMERCHANTS_REQ_TIMEOUTS        -default {}                     -desc {A map of timeouts for each request. For requests not in this map, we fallback to default request timeout.}] \
	] \
	-body \
{
	variable CFG
	variable INIT
	variable TRANS_TYPES

	set fn {core::api::emerchants::init}

	if {$INIT} {
		core::log::write INFO {$fn: API already initialised}
		return
	}

	# initialise
	core::log::write INFO {$fn: initialising ...}
	foreach {n v} [array get ARGS] {
		set n   [string trimleft $n -]
		set str [format "%-35s = %s" $n $v]
		core::log::write INFO {$fn: initialised with $str}

		set CFG($n) $v
	}

	# service URL must be present
	if {$CFG(service_base_url) eq {}} {
		error "$fn: eMerchants service base url cannot be empty"
	}

	# setup number of days in past for GetTransactionHistory request.
	if {$CFG(trans_hist_days) >= 1} {
		set CFG(trans_hist_days) [expr {-1 * $CFG(trans_hist_days)}]
	}

	# namespace list for requests
	set CFG(request_namespaces) [list \
		{soapenv} {http://schemas.xmlsoap.org/soap/envelope/} \
		{tem}     {http://tempuri.org/} \
		{eml}     {http://schemas.datacontract.org/2004/07/EML.Services.Base} \
		{eml1}    {http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO} \
		{eml2}    {http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers} \
		{usr}     {http://schemas.datacontract.org/2004/07/EML.DTO.Users} \
		{eml3}    {http://schemas.datacontract.org/2004/07/EML.Services.External.Shared} \
	]

	# namespace list for response
	set CFG(response_namespaces) [list \
		{s} {http://schemas.xmlsoap.org/soap/envelope/} \
		{a} {http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO} \
		{b} {http://schemas.datacontract.org/2004/07/EML.DTO.Users} \
		{c} {http://schemas.datacontract.org/2004/07/EML.Data.Common} \
		{d} {http://schemas.datacontract.org/2004/07/EML.DTO.Transactions} \
		{i} {http://www.w3.org/2001/XMLSchema-instance} \
	]

	# all available namespaces
	set CFG(all_namespaces) [concat \
		$CFG(request_namespaces) \
		$CFG(response_namespaces) \
	]

	# Services/Requests
	#
	# maintenance requests
	set CFG(PingService,SOAPActionBase) {http://tempuri.org/IService}
	set CFG(PingService,operations) {
		ConnectionCheck
		Ping
	}

	# account management requests
	set CFG(AccountManagementService,SOAPActionBase) {http://tempuri.org/IAccountManagementService}
	set CFG(AccountManagementService,operations) {
		ActivateCard
		CreateAccount
		DeactivateCard
		GetAccountDetails
		GetAccountStatus
		UpdateAccountDetails
	}

	# transaction requests
	set CFG(TransactionService,SOAPActionBase) {http://tempuri.org/ITransactionService}
	set CFG(TransactionService,operations) {
		GetBillerName
		GetTransactionHistory
		Transfer
		ValidateBpayPayment
	}

	# Service URLS
	set CFG(base_url)  $CFG(service_base_url)
	set CFG(wsdl_extn) {.svc}
	set CFG(services)  {PingService AccountManagementService TransactionService}

	# service/request endpoints
	# example:
	# set CFG(CreateAccount,endpoint) {https://beta.emerchants.com.au/EML.Services.External/AccountManagementService.svc}
	foreach svc $CFG(services) {
		# op - operation or a request
		foreach op $CFG($svc,operations) {
			set CFG($op,endpoint)   [join [list $CFG(base_url) [format "%s%s" $svc $CFG(wsdl_extn)]] /]
			set CFG($op,SOAPAction) [join [list $CFG($svc,SOAPActionBase) $op] /]
			# set the default timeout for each operation for now,
			# we'll overwrite this depending on another config
			# REQ_TIMEOUTS later on
			set CFG($op,timeout)    $CFG(def_req_timeout)
		}
	}

	# SOAP Objects
	set CFG(ClientDetails,namespace)          {eml1}
	set CFG(ClientDetails,children_namespace) {usr}
	set CFG(ClientDetails,elements) {
		{AddressLine1}     {addressline1}
		{AddressLine2}     {addressline2}
		{City}             {city}
		{Country}          {country}
		{DateOfBirth}      {dateofbirth}
		{EmailAddress}     {emailaddress}
		{FirstName}        {firstname}
		{LastName}         {lastname}
		{MobileNumber}     {mobilenumber}
		{PhoneNumber}      {phonenumber}
		{PostCode}         {postcode}
		{State}            {state}
		{Suburb}           {suburb}
		{Title}            {title}
	}

	set CFG(AccountId,namespace)          {eml1}
	set CFG(AccountId,children_namespace) {eml2}
	set CFG(AccountId,elements) {
		{ExternalAccountId}  {ext_id}
	}

	set CFG(SourceAccountId,namespace)          {eml1}
	set CFG(SourceAccountId,children_namespace) {eml2}
	set CFG(SourceAccountId,elements) {
		{ExternalAccountId}  {src_ext_id}
	}

	set CFG(DestinationAccountId,namespace)          {eml1}
	set CFG(DestinationAccountId,children_namespace) {eml2}
	set CFG(DestinationAccountId,elements) {
		{ExternalAccountId}  {dest_ext_id}
	}

	set CFG(SourceReference,namespace)          {eml1}
	set CFG(DestinationReference,namespace)     {eml1}
	set CFG(Amount,namespace)                   {eml1}

	# response account elements
	set CFG(Account,elements) {
		{Balance}                   {balance}
		{BpayBillerCode}            {bpaybillercode}
		{BpayReferenceNumber}       {bpayreferencenumber}
		{CardNumber}                {cardnumber}
		{Cvv2}                      {cvv2}
		{DirectEntryAccountNumber}  {directentryaccountnumber}
		{DirectEntryBsb}            {directentrybsb}
		{ExpiryDate}                {expirydate}
		{ExternalAccountId}         {externalaccountid}
		{FreeDec1}                  {freedec1}
		{FreeDec2}                  {freedec2}
		{FreeInt1}                  {freeint1}
		{FreeInt2}                  {freeint2}
		{FreeText1}                 {freetext1}
		{FreeText2}                 {freetext2}
		{FreeText3}                 {freetext3}
		{FreeText4}                 {freetext4}
		{FreeText5}                 {freetext5}
		{FreeText6}                 {freetext6}
		{FreeText7}                 {freetext7}
		{FreeText8}                 {freetext8}
	}

	# response state
	set CFG(State,elements) {
		{Code}             {code}
		{Description}      {description}
		{IsActive}         {isactive}
		{LegacyCode}       {legacycode}
	}

	# response Client details elements
	set CFG(Client,elements) $CFG(ClientDetails,elements)

	set CFG(TransactionDetails,elements) {
		{BaseAmount}         {baseamount}
		{CardId}             {cardid}
		{CashAmount}         {cashamount}
		{CompanyId}          {companyid}
		{Date}               {date}
		{Description}        {description}
		{FeeTotal}           {feetotal}
		{Id}                 {id}
		{ParentId}           {parentid}
		{TransactionTypeId}  {transactiontypeid}
	}

	set CFG(Status,elements) {
		{Code}             {code}
		{Description}      {description}
		{IsActive}         {isactive}
		{LegacyCode}       {legacycode}
	}

	set CFG(ReasonCode,namespace) {eml1}

	# SOAP fields prefix and suffix
	set CFG(prefix) {_x003C_}
	set CFG(suffix) {_x003E_k__BackingField}

	# setup transaction types from config if exists, otherwise use default list
	# we have in namespace
	if {$CFG(trans_types) eq {}} {
		set CFG(trans_types) $::core::api::emerchants::CORE_DEF(def_trans_types)
	}

	# list of all the transaction IDs
	foreach {trans_id category desc} $CFG(trans_types) {
		lappend TRANS_TYPES(trans_ids) $trans_id

		set TRANS_TYPES($trans_id,category) $category
		set TRANS_TYPES($trans_id,desc)     $desc
	}

	# log configurations and settings
	core::log::write       INFO {$fn: CFG}
	core::log::write_array INFO CFG
	core::log::write       INFO {$fn: TRANS_TYPES}
	core::log::write_array INFO TRANS_TYPES

	# set the timeouts from config if any
	foreach {op timeout} $CFG(req_timeouts) {
		if {![string is wideinteger -strict $timeout]} {
			continue
		}

		set CFG($op,timeout) $timeout
	}

	# initialise harness - this is inly relevant for unit tests
	if {![catch {
		package require core::harness::api::emerchants 1.0
	} msg]} {
		core::harness::api::emerchants::init
	}

	set INIT 1
}
		

# CreateAccount
# make request to create the account on the emerchants system
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::create_account \
	-desc {Request to create an emerchants account for a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(title) \
		$::core::api::emerchants::CORE_DEF(firstname) \
		$::core::api::emerchants::CORE_DEF(lastname) \
		$::core::api::emerchants::CORE_DEF(emailaddress) \
		$::core::api::emerchants::CORE_DEF(dateofbirth) \
		$::core::api::emerchants::CORE_DEF(phonenumber,opt) \
		$::core::api::emerchants::CORE_DEF(mobilenumber,opt) \
		$::core::api::emerchants::CORE_DEF(country) \
		$::core::api::emerchants::CORE_DEF(city,opt) \
		$::core::api::emerchants::CORE_DEF(state) \
		$::core::api::emerchants::CORE_DEF(suburb,opt) \
		$::core::api::emerchants::CORE_DEF(addressline1,opt) \
		$::core::api::emerchants::CORE_DEF(addressline2,opt) \
		$::core::api::emerchants::CORE_DEF(postcode,opt) \
		$::core::api::emerchants::CORE_DEF(initial_load_amount,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::create_account}

	set request       {CreateAccount}
	set envelope_name [_get_envelope_name $request]
	set req_endpoint  $CFG($request,endpoint)

	set client_details {}

	foreach {field index} $CFG(ClientDetails,elements) {
		dict set client_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_CreateAccount \
		$envelope_name \
		$client_details \
		$ARGS(-initial_load_amount)

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# UpdateAccount
# update details of an existing emerchants account.
#
# @returns [dict status {OK|NOT_OK} ...]
#
# NOTE: this procs expects all the modified/un-modified ClientDetails. It does
# not care what details are changed.
#
core::args::register \
	-proc_name core::api::emerchants::update_account_details \
	-desc {Request to update emerchants account details for a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(title) \
		$::core::api::emerchants::CORE_DEF(firstname) \
		$::core::api::emerchants::CORE_DEF(lastname) \
		$::core::api::emerchants::CORE_DEF(emailaddress) \
		$::core::api::emerchants::CORE_DEF(dateofbirth) \
		$::core::api::emerchants::CORE_DEF(phonenumber) \
		$::core::api::emerchants::CORE_DEF(mobilenumber) \
		$::core::api::emerchants::CORE_DEF(country) \
		$::core::api::emerchants::CORE_DEF(city,opt) \
		$::core::api::emerchants::CORE_DEF(state) \
		$::core::api::emerchants::CORE_DEF(suburb,opt) \
		$::core::api::emerchants::CORE_DEF(addressline1) \
		$::core::api::emerchants::CORE_DEF(addressline2) \
		$::core::api::emerchants::CORE_DEF(postcode,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG 
	variable SOAP_AUTH

	set request        {UpdateAccountDetails}
	set envelope_name  [_get_envelope_name $request]
	set client_details {}

	foreach {field index} $CFG(ClientDetails,elements) {
		dict set client_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_UpdateAccountDetails \
		$envelope_name \
		$ARGS(-ext_id) \
		$client_details

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# GetAccountStatus
# get status of an existing emerchants account
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::get_account_status \
	-desc {Request to get emerchants account status for an already registered customer} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::get_account_status}

	set request          {GetAccountStatus}
	set envelope_name    [_get_envelope_name $request]
	set ext_acct_details {}

	foreach {field index} $CFG(AccountId,elements) {
		dict set ext_acct_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_GetAccountStatus \
		$envelope_name \
		$ext_acct_details

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# GetAccountDetails
# get the details for an account setup on emerchants
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::get_account_details \
	-desc {Request account details for an already registered account} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(detail_flags,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::GetAccountDetails}

	set request       {GetAccountDetails}
	set envelope_name [_get_envelope_name $request]

	set ext_acct_details {}

	foreach {field index} $CFG(AccountId,elements) {
		dict set ext_acct_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_GetAccountDetails \
		$envelope_name \
		$ext_acct_details \
		$ARGS(-detail_flags)

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# GetTransactionHistory
# get transaction history from emerchants for an account
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::get_transaction_history \
	-desc {Request to get emerchants transaction history for a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(start_date,opt) \
		$::core::api::emerchants::CORE_DEF(end_date,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::get_transaction_history}

	set request       {GetTransactionHistory}
	set envelope_name [_get_envelope_name $request]

	set ext_acct_details {}

	foreach {field index} $CFG(AccountId,elements) {
		dict set ext_acct_details $index $ARGS(-$index)
	}

	set st_dt {}

	if {$ARGS(-start_date) eq {}} {
		set now [clock scan now -timezone $CFG(timezone)]
		set st_dt [clock add $now $CFG(trans_hist_days) days -timezone $CFG(timezone)]
	} else {
		set st_dt [clock scan $ARGS(-start_date) -timezone $CFG(timezone)]
	}

	# 2017-09-01T00:00:00
	set ARGS(-start_date) [clock format $st_dt -format $CFG(date_format) -timezone $CFG(timezone)]

	set to_dt {}

	if {$ARGS(-end_date) eq {}} {
		if {![info exists now]} {
			set now [clock scan now -timezone $CFG(timezone)]
		}

		set to_dt $now
	} else {
		set to_dt [clock scan $ARGS(-end_date) -timezone $CFG(timezone)]
	}

	set ARGS(-end_date) [clock format $to_dt -format $CFG(date_format) -timezone $CFG(timezone)]

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_GetTransactionHistory \
		$envelope_name \
		$ext_acct_details \
		$ARGS(-start_date) \
		$ARGS(-end_date)

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# Transfer
# make an emerchants transfer from one account to another with a certain amount
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::transfer \
	-desc {Request to transfer funds from one emerchants account to another emerchants account for a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(src_ext_id) \
		$::core::api::emerchants::CORE_DEF(dest_ext_id) \
		$::core::api::emerchants::CORE_DEF(amount) \
		$::core::api::emerchants::CORE_DEF(src_ref,opt) \
		$::core::api::emerchants::CORE_DEF(dest_ref,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG 
	variable SOAP_AUTH

	set request       {Transfer}
	set envelope_name [_get_envelope_name $request]

	# source account
	set src_ext_acct_details {}

	foreach {field index} $CFG(SourceAccountId,elements) {
		dict set src_ext_acct_details $index $ARGS(-$index)
	}

	# Destination account
	set dest_ext_acct_details {}

	foreach {field index} $CFG(DestinationAccountId,elements) {
		dict set dest_ext_acct_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_Transfer \
		$envelope_name \
		$src_ext_acct_details \
		$dest_ext_acct_details \
		$ARGS(-amount) \
		$ARGS(-src_ref) \
		$ARGS(-dest_ref)

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# ActivateCard
# activate a card on the emerchants system
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::activate_card \
	-desc {Request to activate eMerchants account/card of a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG 
	variable SOAP_AUTH

	set request       {ActivateCard}
	set envelope_name [_get_envelope_name $request]

	set ext_acct_details {}

	foreach {field index} $CFG(AccountId,elements) {
		dict set ext_acct_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_ActivateCard \
		$envelope_name \
		$ext_acct_details

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# DeactivateCard
# deactivate the card on the emerchants system
#
# @returns [dict status {OK|NOT_OK} ...]
#
core::args::register \
	-proc_name core::api::emerchants::deactivate_card \
	-desc {Request to deactivate eMerchants account/card of a customer (end-user)} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(ext_id) \
		$::core::api::emerchants::CORE_DEF(reason_code,opt) \
		$::core::api::emerchants::CORE_DEF(soap_username) \
		$::core::api::emerchants::CORE_DEF(soap_password) \
	] \
	-body \
{
	variable CFG 
	variable SOAP_AUTH

	set request          {DeactivateCard}
	set envelope_name    [_get_envelope_name $request]
	set ext_acct_details {}

	foreach {field index} $CFG(AccountId,elements) {
		dict set ext_acct_details $index $ARGS(-$index)
	}

	# setup SOAP service credentials
	set SOAP_AUTH($request,username) $ARGS(-soap_username)
	set SOAP_AUTH($request,password) $ARGS(-soap_password)

	_create_request_DeactivateCard \
		$envelope_name \
		$ext_acct_details \
		$ARGS(-reason_code)

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# Not available on LIVE
#
# @returns [dict status {OK|NOT_OK}]
#
core::args::register \
	-proc_name core::api::emerchants::ping \
	-desc {Request to ping eMerchants API servers} \
	-args [list] \
	-body \
{
	set request       {Ping}
	set envelope_name [_get_envelope_name $request]

	_create_request_Ping \
		$envelope_name

	return [_send_soap_request \
		$envelope_name \
		$request \
	]
}


# Given a transaction type id, this function returns the categry and
# description of transaction type
# 
# @param  -trans_type_id  UINT from TRANSACTION_TYPES
# @returns [dict status {OK|NOT_OK} category {Category} desc {Description}]
#   or throws an error
#
core::args::register \
	-proc_name core::api::emerchants::translate_transaction_type_id \
	-desc {Get the transaction category and description from a transaction type id} \
	-args [list \
		$::core::api::emerchants::CORE_DEF(trans_type_id) \
	] \
	-body \
{
	variable TRANS_TYPES

	set fn {core::api::emerchants::translate_transaction_type_id}

	if {$ARGS(-trans_type_id) ni $TRANS_TYPES(trans_ids)} {
		error "$fn: Unknown transaction type id"
	}

	set ret {}
	dict set ret status   OK
	dict set ret category $TRANS_TYPES($ARGS(-trans_type_id),category)
	dict set ret desc     $TRANS_TYPES($ARGS(-trans_type_id),desc)

	return $ret
}


################################################################################
# PRIVATE PROCEDURES
################################################################################

# get the envelope name from request
proc core::api::emerchants::_get_envelope_name {request} {
	return "eMerchants.$request"
}


# send a soap request
proc core::api::emerchants::_send_soap_request {
	envelope_name
	request
} {

	variable CFG

	set fn {core::api::emerchants::_send_soap_request}

	# Mask sensitive elements from the SOAP request / response
	core::soap::set_masked_elements -name $envelope_name -elements [list eml:Username eml:Password]

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name> <request:$request>}
	core::log::write INFO {$fn: [core::soap::print_soap -name $envelope_name -type "request"]}

	set conn_timeout $CFG(conn_timeout)
	set req_timeout  $CFG($request,timeout)
	set req_endpoint $CFG($request,endpoint)
	set http_headers [list \
		"Content-Type" "text/xml; charset=utf-8" \
		"SOAPAction"   $CFG($request,SOAPAction) \
	]

	core::log::write DEBUG {$fn: <http_headers:$http_headers> <req_endpoint:$req_endpoint>}

	# Send the SOAP to the endpoint
	if {[catch {
		set ret [core::soap::send \
			-endpoint     $req_endpoint \
			-name         $envelope_name \
			-headers      $http_headers \
			-req_timeout  $req_timeout \
			-conn_timeout $conn_timeout \
		]
	} msg]} {
		# failure case - response not recognized
		_validate_error_handling $envelope_name

		core::log::write ERROR {$fn: exception thrown from core::soap::send - $msg}
		core::soap::cleanup -name $envelope_name
		error "$fn: core::soap::send failed - $msg" $::errorInfo $::errorCode
	}

	# Clean-up request if failed
	if {[string compare [lindex $ret 0] NOT_OK] == 0} {
		core::log::write ERROR {$fn: core::soap::send failed, cleaning up $request, error: $ret}
		core::soap::cleanup -name $envelope_name
		error "$fn: core::soap::send failed" {} $ret
	}

	set result {}

	core::log::write INFO {$fn: response: [core::soap::print_soap -name $envelope_name -type "received"]}

	# parse the response with specific handler
	set result [_parse_response_$request $envelope_name]

	core::soap::cleanup -name $envelope_name
	core::log::write DEBUG {$fn: returning $result}

	return $result
}


# create SOAP envelope for a request
proc core::api::emerchants::_create_envelope {
	envelope_name
	{req_ns {}}
	{req_header {}}
	{req_header_ns {}}
} {

	variable CFG

	set fn {core::api::emerchants::_create_envelope}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>\
		<req_ns:$req_ns> <req_header:$req_header>\
		<req_header_ns:$req_header_ns>}

	if {$req_ns eq {}} {
		set req_ns $CFG(request_namespaces)
	}
	
	core::soap::create_envelope \
		-name $envelope_name \
		-namespaces $req_ns

	core::soap::add_soap_header \
		-name $envelope_name \
		-label {soapenv:Header}

	if {$req_header ne {} && $req_header_ns ne {}} {
		core::soap::add_element \
			-name $envelope_name \
			-parent {soapenv:Header} \
			-elem $req_header \
			-attributes [list \
				{xmlns} $req_header_ns \
			]
	}

	core::soap::add_soap_body \
		-name $envelope_name \
		-label {soapenv:Body}

	return [list OK]
}


# parse request error info
proc core::api::emerchants::_parse_error_info {
	envelope_name
	errorcode_xpath
	errorinfo_xpath
} {

	variable CFG

	set err_code_elems {Code Description}

	foreach elem $err_code_elems {
		set elem_name [core::api::emerchants::_format_xml_element $elem {eml}]

		set ERR($elem) [core::soap::get_element \
			-name  $envelope_name \
			-xpath "$errorcode_xpath/${elem_name}" \
		]
	}

	set err_msg [core::soap::get_element \
		-name  $envelope_name \
		-xpath $errorinfo_xpath \
	]

	return [list $ERR(Code) $ERR(Description) $err_msg]
}


# validate errors
proc core::api::emerchants::_validate_error_handling {
	envelope_name
} {

	# map Entry : param xpath is_attribute default_value is_nested nested_elements(another list with entry like this one)
	#
	set list_params [list \
		status_header_code      {//*[local-name()='responseHeader']/*[local-name()='serviceError']/*[local-name()='code']}   0 {} 1 {} \
		status_header_message   {//*[local-name()='responseHeader']/*[local-name()='serviceError']/*[local-name()='message']} 0 {} 1 {} \
		schema_validation_code  {//*[local-name()='faultcode']}   0 {} 1 {} \
		schema_validation_msg   {//*[local-name()='faultstring']} 0 {} 1 {} \
	]

	set generic_result [core::soap::map_to_dict \
		-map $list_params \
		-envelope_name $envelope_name \
	]

	foreach param {
		status_header_code
		status_header_message
		schema_validation_code
		schema_validation_msg
	} {
		set $param [dict get $generic_result $param]
	}

	# Schema Validation error?
	if {$schema_validation_code != {} && $schema_validation_msg != {}} {
		error "Error parsing emerchants response $schema_validation_msg" {} $schema_validation_code
	} else {
		# Do we have a code and message in the common responseHeader?
		if {$status_header_code != {} && $status_header_message != {}} {
			error "Error parsing emerchants response $status_header_message" {} $status_header_code
		} else {
			# Generic error during the parsing.
			error "Error parsing emerchants response" {} GENERIC_PARSING_ERROR
		}
	}
}


# add security object in SOAP request
proc core::api::emerchants::_add_security_credentials {
	envelope_name
	soap_username
	soap_password
} {
	variable CFG

	core::soap::add_element \
		-name $envelope_name \
		-parent {tem:request} \
		-elem   {eml:SecurityRequest}

	core::soap::add_element \
		-name $envelope_name \
		-parent {eml:SecurityRequest} \
		-elem   {eml:Password} \
		-value  $soap_password

	core::soap::add_element \
		-name $envelope_name \
		-parent {eml:SecurityRequest} \
		-elem   {eml:Username} \
		-value  $soap_username
}


# create CreateAccount SOAP request
#
# Example:
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Users">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:CreateAccount>
#             <!--Optional:-->
#             <tem:request>
#                 <!--Optional:-->
#                 <eml:SecurityRequest>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Password>?</eml:Password>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Username>?</eml:Username>
#                 </eml:SecurityRequest>
#                 <!--Optional:-->
#                 <!--type: string-->
#                 <eml1:CardPoolCode>?</eml1:CardPoolCode>
#                 <!--Optional:-->
#                 <eml1:ClientDetails>
#                     <!--type: string-->
#                     <eml2:_x003C_AddressLine1_x003E_k__BackingField>?</eml2:_x003C_AddressLine1_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_AddressLine2_x003E_k__BackingField>?</eml2:_x003C_AddressLine2_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_City_x003E_k__BackingField>?</eml2:_x003C_City_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_Country_x003E_k__BackingField>?</eml2:_x003C_Country_x003E_k__BackingField>
#                     <!--type: dateTime-->
#                     <eml2:_x003C_DateOfBirth_x003E_k__BackingField>?</eml2:_x003C_DateOfBirth_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_EmailAddress_x003E_k__BackingField>?</eml2:_x003C_EmailAddress_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_FirstName_x003E_k__BackingField>?</eml2:_x003C_FirstName_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_LastName_x003E_k__BackingField>?</eml2:_x003C_LastName_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_MobileNumber_x003E_k__BackingField>?</eml2:_x003C_MobileNumber_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_PhoneNumber_x003E_k__BackingField>?</eml2:_x003C_PhoneNumber_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_PostCode_x003E_k__BackingField>?</eml2:_x003C_PostCode_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_State_x003E_k__BackingField>?</eml2:_x003C_State_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_Suburb_x003E_k__BackingField>?</eml2:_x003C_Suburb_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml2:_x003C_Title_x003E_k__BackingField>?</eml2:_x003C_Title_x003E_k__BackingField>
#                 </eml1:ClientDetails>
#                 <!--Optional:-->
#                 <!--type: decimal-->
#                 <eml1:InitialLoadAmount>?</eml1:InitialLoadAmount>
#                 <!--Optional:-->
#                 <eml1:LoginCredentials>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:Context>?</eml2:Context>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:Password>?</eml2:Password>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:UserName>?</eml2:UserName>
#                 </eml1:LoginCredentials>
#                 <!--Optional:-->
#                 <!--type: string-->
#                 <eml1:VoucherCode>?</eml1:VoucherCode>
#             </tem:request>
#         </tem:CreateAccount>
#     </soapenv:Body>
# </soapenv:Envelope>
proc core::api::emerchants::_create_request_CreateAccount {
	envelope_name
	client_details
	initial_load_amount
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_CreateAccount}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set request {CreateAccount}
	set act_elem_with_ns {tem:CreateAccount}
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set client_details_elem_with_ns {eml1:ClientDetails}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $client_details_elem_with_ns

	set cl_fields_ns $CFG(ClientDetails,children_namespace)
	set client_elems $CFG(ClientDetails,elements)

	foreach {field index} $client_elems {
		set elem [core::api::emerchants::_format_xml_element ${field} ${cl_fields_ns}]

		core::soap::add_element \
			-name   $envelope_name \
			-parent $client_details_elem_with_ns \
			-elem   ${elem} \
			-value  [dict get $client_details $index]
	}

	core::soap::add_element \
		-name  $envelope_name \
		-parent $req_elem_with_ns \
		-elem   {eml:InitialLoadAmount} \
		-value  $initial_load_amount
}


# parse response from CreateAccount request
# 
# Example:
# <?xml version="1.0"?>
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <CreateAccountResponse xmlns="http://tempuri.org/">
#             <CreateAccountResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#                 <a:AccountId xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
#                     <b:ExternalAccountId>MM802TC1F</b:ExternalAccountId>
#                 </a:AccountId>
#             </CreateAccountResult>
#         </CreateAccountResponse>
#     </s:Body>
# </s:Envelope>
# 
proc core::api::emerchants::_parse_response_CreateAccount {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_CreateAccount}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	set success [lindex [core::soap::get_element\
		-name $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:CreateAccountResponse/tem:CreateAccountResult/eml:Success} \
	]]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:CreateAccountResponse/tem:CreateAccountResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:CreateAccountResponse/tem:CreateAccountResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set list_params [list \
		account_ids {//s:Envelope/s:Body/tem:CreateAccountResponse/tem:CreateAccountResult/a:AccountId/eml2:ExternalAccountId} 0 {} 0 {} \
	]

	set result [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	core::log::write DEBUG {$fn: <result:$result>}

	set ret {}
	dict set ret result $result

	if {$result eq {}} {
		dict set ret status FAIL
		dict set ret code   {RESPONSE_PARSE_ERROR}
		dict set ret desc   {Could not get ExternalAccountId in response}
		dict set ret info   {}
		return $ret
	}

	dict set ret status OK
	return $ret
}


# create UpdateAccountDetails SOAP request
#
# Example:
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers"
# 	xmlns:eml3="http://schemas.datacontract.org/2004/07/EML.DTO.Users">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:UpdateAccountDetails>
#             <!--Optional:-->
#             <tem:request>
#                 <!--Optional:-->
#                 <eml:SecurityRequest>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Password>?</eml:Password>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Username>?</eml:Username>
#                 </eml:SecurityRequest>
#                 <!--Optional:-->
#                 <eml1:AccountId>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#                 </eml1:AccountId>
#                 <!--Optional:-->
#                 <eml1:ClientDetails>
#                     <!--type: string-->
#                     <eml3:_x003C_AddressLine1_x003E_k__BackingField>?</eml3:_x003C_AddressLine1_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_AddressLine2_x003E_k__BackingField>?</eml3:_x003C_AddressLine2_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_City_x003E_k__BackingField>?</eml3:_x003C_City_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_Country_x003E_k__BackingField>?</eml3:_x003C_Country_x003E_k__BackingField>
#                     <!--type: dateTime-->
#                     <eml3:_x003C_DateOfBirth_x003E_k__BackingField>?</eml3:_x003C_DateOfBirth_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_EmailAddress_x003E_k__BackingField>?</eml3:_x003C_EmailAddress_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_FirstName_x003E_k__BackingField>?</eml3:_x003C_FirstName_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_LastName_x003E_k__BackingField>?</eml3:_x003C_LastName_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_MobileNumber_x003E_k__BackingField>?</eml3:_x003C_MobileNumber_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_PhoneNumber_x003E_k__BackingField>?</eml3:_x003C_PhoneNumber_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_PostCode_x003E_k__BackingField>?</eml3:_x003C_PostCode_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_State_x003E_k__BackingField>?</eml3:_x003C_State_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_Suburb_x003E_k__BackingField>?</eml3:_x003C_Suburb_x003E_k__BackingField>
#                     <!--type: string-->
#                     <eml3:_x003C_Title_x003E_k__BackingField>?</eml3:_x003C_Title_x003E_k__BackingField>
#                 </eml1:ClientDetails>
#             </tem:request>
#         </tem:UpdateAccountDetails>
#     </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_create_request_UpdateAccountDetails {
	envelope_name
	ext_acct_id
	client_details
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_UpdateAccountDetails}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set request {UpdateAccountDetails}
	set act_elem_with_ns {tem:UpdateAccountDetails}
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  $ext_acct_id

	set client_details_elem_with_ns {eml1:ClientDetails}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $client_details_elem_with_ns

	set cl_fields_ns $CFG(ClientDetails,children_namespace)
	set client_elems $CFG(ClientDetails,elements)

	foreach {field index} $client_elems {
		set elem [core::api::emerchants::_format_xml_element ${field} ${cl_fields_ns}]

		core::soap::add_element \
			-name   $envelope_name \
			-parent $client_details_elem_with_ns \
			-elem   ${elem} \
			-value  [dict get $client_details $index]
	}
}

# Parse the response from an UpdateAccountDetails request
#
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <UpdateAccountDetailsResponse xmlns="http://tempuri.org/">
#             <UpdateAccountDetailsResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#             </UpdateAccountDetailsResult>
#         </UpdateAccountDetailsResponse>
#     </s:Body>
# </s:Envelope>
#
proc core::api::emerchants::_parse_response_UpdateAccountDetails {envelope_name} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_UpdateAccountDetails}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	set success [lindex [core::soap::get_element\
		-name $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:UpdateAccountDetailsResponse/tem:UpdateAccountDetailsResult/eml:Success} \
	]]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:UpdateAccountDetailsResponse/tem:UpdateAccountDetailsResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:UpdateAccountDetailsResponse/tem:UpdateAccountDetailsResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set ret {}
	dict set ret status  OK
	dict set ret result {}

	# UpdateAccountDetails doesn't returns anything (apart from Success status
	# and error codes)
	return $ret
}


# create GetAccountDetails SOAP request
#
# Example:
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:GetAccountDetails>
#             <tem:request>
#                 <eml:SecurityRequest>
#                     <eml:Username>?</eml:Username>
#                     <eml:Password>?</eml:Password>
#                 </eml:SecurityRequest>
#                 <eml1:AccountId>
#                     <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#                 </eml1:AccountId>
#             </tem:request>
#         </tem:GetAccountDetails>
#     </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_create_request_GetAccountDetails {
	envelope_name
	ext_acct_details
	{detail_flags {All}}
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_GetAccountDetails}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set request {GetAccountDetails}

	if {[dict get $ext_acct_details ext_id] eq {}} {
		error "$fn: ext_acct_id is required"
	}

	set act_elem_with_ns {tem:GetAccountDetails}
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  [dict get $ext_acct_details ext_id]

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   {eml1:RequiredDetail} \
		-value  $detail_flags
}



# parse the response of the GetAccountDetails request
#
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <GetAccountDetailsResponse xmlns="http://tempuri.org/">
#             <GetAccountDetailsResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#                 <a:Account xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Users">
#                     <b:_x003C_Balance_x003E_k__BackingField>0</b:_x003C_Balance_x003E_k__BackingField>
#                     <b:_x003C_BpayBillerCode_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_BpayReferenceNumber_x003E_k__BackingField>5021XXXXXXXX8189</b:_x003C_BpayReferenceNumber_x003E_k__BackingField>
#                     <b:_x003C_CardNumber_x003E_k__BackingField>5021XXXXXXXX8189</b:_x003C_CardNumber_x003E_k__BackingField>
#                     <b:_x003C_Cvv2_x003E_k__BackingField/>
#                     <b:_x003C_DirectEntryAccountNumber_x003E_k__BackingField>10890838</b:_x003C_DirectEntryAccountNumber_x003E_k__BackingField>
#                     <b:_x003C_DirectEntryBsb_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_ExpiryDate_x003E_k__BackingField>2017-09-01T00:00:00</b:_x003C_ExpiryDate_x003E_k__BackingField>
#                     <b:_x003C_ExternalAccountId_x003E_k__BackingField>WAP00B9N5</b:_x003C_ExternalAccountId_x003E_k__BackingField>
#                     <b:_x003C_FreeDec1_x003E_k__BackingField>0</b:_x003C_FreeDec1_x003E_k__BackingField>
#                     <b:_x003C_FreeDec2_x003E_k__BackingField>0</b:_x003C_FreeDec2_x003E_k__BackingField>
#                     <b:_x003C_FreeInt1_x003E_k__BackingField>0</b:_x003C_FreeInt1_x003E_k__BackingField>
#                     <b:_x003C_FreeInt2_x003E_k__BackingField>0</b:_x003C_FreeInt2_x003E_k__BackingField>
#                     <b:_x003C_FreeText1_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText2_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText3_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText4_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText5_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText6_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText7_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_FreeText8_x003E_k__BackingField i:nil="true"/>
#                     <b:_x003C_State_x003E_k__BackingField xmlns:c="http://schemas.datacontract.org/2004/07/EML.Data.Common">
#                         <c:_x003C_Code_x003E_k__BackingField>1</c:_x003C_Code_x003E_k__BackingField>
#                         <c:_x003C_Description_x003E_k__BackingField>Pre-active</c:_x003C_Description_x003E_k__BackingField>
#                         <c:_x003C_IsActive_x003E_k__BackingField>false</c:_x003C_IsActive_x003E_k__BackingField>
#                         <c:_x003C_LegacyCode_x003E_k__BackingField>PA</c:_x003C_LegacyCode_x003E_k__BackingField>
#                     </b:_x003C_State_x003E_k__BackingField>
#                 </a:Account>
#                 <a:Client xmlns:b="http://schemas.datacontract.org/2004/07/EML.DTO.Users">
#                     <b:_x003C_AddressLine1_x003E_k__BackingField>2 Fake Street (upd)</b:_x003C_AddressLine1_x003E_k__BackingField>
#                     <b:_x003C_AddressLine2_x003E_k__BackingField>In Fake Building (upd)</b:_x003C_AddressLine2_x003E_k__BackingField>
#                     <b:_x003C_City_x003E_k__BackingField>Sydney</b:_x003C_City_x003E_k__BackingField>
#                     <b:_x003C_Country_x003E_k__BackingField>AU</b:_x003C_Country_x003E_k__BackingField>
#                     <b:_x003C_DateOfBirth_x003E_k__BackingField>1980-12-31T00:00:00</b:_x003C_DateOfBirth_x003E_k__BackingField>
#                     <b:_x003C_EmailAddress_x003E_k__BackingField>abc.upd@def.ghi</b:_x003C_EmailAddress_x003E_k__BackingField>
#                     <b:_x003C_FirstName_x003E_k__BackingField>Fakey 2 (Upd)</b:_x003C_FirstName_x003E_k__BackingField>
#                     <b:_x003C_LastName_x003E_k__BackingField>Fakerson</b:_x003C_LastName_x003E_k__BackingField>
#                     <b:_x003C_MobileNumber_x003E_k__BackingField>0123456789</b:_x003C_MobileNumber_x003E_k__BackingField>
#                     <b:_x003C_PhoneNumber_x003E_k__BackingField>0123456789</b:_x003C_PhoneNumber_x003E_k__BackingField>
#                     <b:_x003C_PostCode_x003E_k__BackingField>2000</b:_x003C_PostCode_x003E_k__BackingField>
#                     <b:_x003C_State_x003E_k__BackingField>NSW   </b:_x003C_State_x003E_k__BackingField>
#                     <b:_x003C_Suburb_x003E_k__BackingField>Sydney</b:_x003C_Suburb_x003E_k__BackingField>
#                     <b:_x003C_Title_x003E_k__BackingField>Mr</b:_x003C_Title_x003E_k__BackingField>
#                 </a:Client>
#             </GetAccountDetailsResult>
#         </GetAccountDetailsResponse>
#     </s:Body>
# </s:Envelope>
#
proc core::api::emerchants::_parse_response_GetAccountDetails {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_GetAccountDetails}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	core::log::write DEBUG {$fn: response}
	core::log::write DEBUG {[core::soap::print_soap -name $envelope_name -type {received}]}

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:GetAccountDetailsResponse/tem:GetAccountDetailsResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:GetAccountDetailsResponse/tem:GetAccountDetailsResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:GetAccountDetailsResponse/tem:GetAccountDetailsResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set client_child_params [list]
	foreach {elem var} $CFG(Client,elements) {
		# get the formatted element
		set elem_f [core::api::emerchants::_format_xml_element ${elem} {usr}]

		lappend client_child_params \
			$var "/${elem_f}" 0 {} 0 {}
	}

	set account_child_params [list]
	foreach {elem var} $CFG(Account,elements) {
		# get the formatted element
		set elem_f [core::api::emerchants::_format_xml_element ${elem} {usr}]

		lappend account_child_params \
			$var "/${elem_f}" 0 {} 0 {}
	}

	set state_child_params [list]
	foreach {elem var} $CFG(State,elements) {
		# get the formatted element
		set elem_f [core::api::emerchants::_format_xml_element ${elem} {c}]

		lappend state_child_params \
			$var "/${elem_f}" 0 {} 0 {}
	}

	# get the formatted State element
	set state_f [core::api::emerchants::_format_xml_element {State} {b}]

	lappend account_child_params \
		state "/${state_f}" 0 {} 1 $state_child_params

	set list_params [list \
		accounts {//s:Envelope/s:Body/tem:GetAccountDetailsResponse/tem:GetAccountDetailsResult/a:Account} 0 {} 1 $account_child_params \
		client   {//s:Envelope/s:Body/tem:GetAccountDetailsResponse/tem:GetAccountDetailsResult/a:Client}  0 {} 1 $client_child_params \
	]

	core::log::write DEBUG {$fn: <list_params:$list_params>}

	set map_res [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	core::log::write DEBUG {$fn: <map_res:$map_res>}

	set ret {}
	dict set ret result $map_res

	if {$map_res eq {}} {
		dict set ret status FAIL
		dict set ret code   {RESPONSE_PARSE_ERROR}
		dict set ret desc   {Could not extract required Account and Client details from response}
		dict set ret info   {}
		return $ret
	}

	dict set ret status OK
	return $ret
}


# create GetAccountStatus SOAP request
#
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers"
# 	xmlns:usr="http://schemas.datacontract.org/2004/07/EML.DTO.Users"
# 	xmlns:eml3="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:GetAccountStatus>
#             <tem:request>
#                 <eml:SecurityRequest>
#                     <eml:Password>Friday14#</eml:Password>
#                     <eml:Username>WS_Sportsbet</eml:Username>
#                 </eml:SecurityRequest>
#                 <eml1:AccountId>
#                     <eml2:ExternalAccountId>WAP00B9N5</eml2:ExternalAccountId>
#                 </eml1:AccountId>
#             </tem:request>
#         </tem:GetAccountStatus>
#     </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_create_request_GetAccountStatus {
	envelope_name
	ext_acct_details
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_GetAccountStatus}

	set request {GetAccountStatus}

	if {[dict get $ext_acct_details ext_id] eq {}} {
		error "$fn: ext_acct_id is required"
	}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set act_elem_with_ns "tem:$request"
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	# add security credentials
	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  [dict get $ext_acct_details ext_id]
}


# parse response from GetAccountStatus request
#
# Example:
#
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <GetAccountStatusResponse xmlns="http://tempuri.org/">
#             <GetAccountStatusResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#                 <a:Balance>0</a:Balance>
#                 <a:Status xmlns:b="http://schemas.datacontract.org/2004/07/EML.Data.Common">
#                     <b:_x003C_Code_x003E_k__BackingField>1</b:_x003C_Code_x003E_k__BackingField>
#                     <b:_x003C_Description_x003E_k__BackingField>Pre-active</b:_x003C_Description_x003E_k__BackingField>
#                     <b:_x003C_IsActive_x003E_k__BackingField>false</b:_x003C_IsActive_x003E_k__BackingField>
#                     <b:_x003C_LegacyCode_x003E_k__BackingField>PA</b:_x003C_LegacyCode_x003E_k__BackingField>
#                 </a:Status>
#             </GetAccountStatusResult>
#         </GetAccountStatusResponse>
#     </s:Body>
# </s:Envelope>
#
proc core::api::emerchants::_parse_response_GetAccountStatus {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_GetAccountStatus}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	core::log::write DEBUG {$fn: response}
	core::log::write DEBUG {[core::soap::print_soap -name $envelope_name -type {received}]}

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:GetAccountStatusResponse/tem:GetAccountStatusResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:GetAccountStatusResponse/tem:GetAccountStatusResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:GetAccountStatusResponse/tem:GetAccountStatusResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set status_params [list]
	foreach {elem var} $CFG(Status,elements) {
		# get the formatted element
		set elem_f [core::api::emerchants::_format_xml_element ${elem} {c}]

		lappend status_params \
			$var "/${elem_f}" 0 {} 0 {}
	}

	set list_params [list \
		balance  {//s:Envelope/s:Body/tem:GetAccountStatusResponse/tem:GetAccountStatusResult/a:Balance} 0 {} 0 {} \
		status   {//s:Envelope/s:Body/tem:GetAccountStatusResponse/tem:GetAccountStatusResult/a:Status}  0 {} 1 $status_params \
	]

	core::log::write DEBUG {$fn: <list_params:$list_params>}

	set map_res [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	core::log::write DEBUG {$fn: <map_res:$map_res>}

	set ret {}
	dict set ret result $map_res

	if {$map_res eq {}} {
		dict set ret status FAIL
		dict set ret code   {RESPONSE_PARSE_ERROR}
		dict set ret desc   {Could not get Balance and Status in response}
		dict set ret info   {}
		return $ret
	}

	dict set ret status OK
	return $ret
}


# create GetTransactionHistory SOAP request
#
# Example:
#
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
# <soapenv:Header/>
# <soapenv:Body>
#     <tem:GetTransactionHistory>
#         <!--Optional:-->
#         <tem:request>
#             <!--Optional:-->
#             <eml:SecurityRequest>
#                 <!--Optional:-->
#                 <!--type: string-->
#                 <eml:Password>?</eml:Password>
#                 <!--Optional:-->
#                 <!--type: string-->
#                 <eml:Username>?</eml:Username>
#             </eml:SecurityRequest>
#             <!--Optional:-->
#             <eml1:AccountId>
#                 <!--Optional:-->
#                 <!--type: string-->
#                 <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#             </eml1:AccountId>
#             <!--Optional:-->
#             <!--type: dateTime-->
#             <eml1:EndDate>?</eml1:EndDate>
#             <!--Optional:-->
#             <!--type: dateTime-->
#             <eml1:StartDate>?</eml1:StartDate>
#         </tem:request>
#     </tem:GetTransactionHistory>
# </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_create_request_GetTransactionHistory {
	envelope_name
	ext_acct_details
	start_date
	end_date
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_GetTransactionHistory}
	
	core::log::write DEBUG {$fn: <envelope_name:$envelope_name> \
		<ext_acct_details:$ext_acct_details> <start_date:$start_date> \
		<end_date:$end_date>}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set request {GetTransactionHistory}

	if {[dict get $ext_acct_details ext_id] eq {}} {
		error "$fn: ext_acct_id is required"
	}

	set act_elem_with_ns "tem:$request"
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  [dict get $ext_acct_details ext_id]

	# NOTE: there's a bug on EMerchants end where they respond with wrong
	# tranasactions wthen the <StartDate> element appears before <EndDate>
	# element.
	#
	# We need to make sure the <EndDate> element is added before
	# <StartDate> element because of above. If you're planning to change
	# following code, make sure to not alter the order, unless EMerchant
	# has confirmed that their bug is fixed.

	set end_date_elem_with_ns   {eml1:EndDate}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $end_date_elem_with_ns \
		-value  $end_date

	set start_date_elem_with_ns {eml1:StartDate}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $start_date_elem_with_ns \
		-value  $start_date
}


# parse the response from GetTransactionHistory request
#
# Example:
# <soapenv:Envelope
#     xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
#     xmlns:tem="http://tempuri.org/"
#     xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
#     xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
#     xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Transactions">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:GetTransactionHistoryResponse>
#             <!--Optional:-->
#             <tem:GetTransactionHistoryResult>
#                 <!--Optional:-->
#                 <eml:ErrorCode>
#                     <eml:_x003C_Code_x003E_k__BackingField>?</eml:_x003C_Code_x003E_k__BackingField>
#                     <eml:_x003C_Description_x003E_k__BackingField>?</eml:_x003C_Description_x003E_k__BackingField>
#                 </eml:ErrorCode>
#                 <!--Optional:-->
#                 <eml:ExtendedErrorInformation>?</eml:ExtendedErrorInformation>
#                 <!--Optional:-->
#                 <eml:Success>?</eml:Success>
#                 <!--Optional:-->
#                 <eml1:Transactions>
#                     <!--Zero or more repetitions:-->
#                     <eml2:TransactionDetails>
#                         <eml2:_x003C_BaseAmount_x003E_k__BackingField>?</eml2:_x003C_BaseAmount_x003E_k__BackingField>
#                         <eml2:_x003C_CardId_x003E_k__BackingField>?</eml2:_x003C_CardId_x003E_k__BackingField>
#                         <eml2:_x003C_CashAmount_x003E_k__BackingField>?</eml2:_x003C_CashAmount_x003E_k__BackingField>
#                         <eml2:_x003C_CompanyId_x003E_k__BackingField>?</eml2:_x003C_CompanyId_x003E_k__BackingField>
#                         <eml2:_x003C_Date_x003E_k__BackingField>?</eml2:_x003C_Date_x003E_k__BackingField>
#                         <eml2:_x003C_Description_x003E_k__BackingField>?</eml2:_x003C_Description_x003E_k__BackingField>
#                         <eml2:_x003C_FeeTotal_x003E_k__BackingField>?</eml2:_x003C_FeeTotal_x003E_k__BackingField>
#                         <eml2:_x003C_Id_x003E_k__BackingField>?</eml2:_x003C_Id_x003E_k__BackingField>
#                         <eml2:_x003C_ParentId_x003E_k__BackingField>?</eml2:_x003C_ParentId_x003E_k__BackingField>
#                         <eml2:_x003C_TransactionTypeId_x003E_k__BackingField>?</eml2:_x003C_TransactionTypeId_x003E_k__BackingField>
#                     </eml2:TransactionDetails>
#                 </eml1:Transactions>
#             </tem:GetTransactionHistoryResult>
#         </tem:GetTransactionHistoryResponse>
#     </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_parse_response_GetTransactionHistory {
	envelope_name
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_parse_response_GetTransactionHistory}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:GetTransactionHistoryResponse/tem:GetTransactionHistoryResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:GetTransactionHistoryResponse/tem:GetTransactionHistoryResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:GetTransactionHistoryResponse/tem:GetTransactionHistoryResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set transactions_params [list]

	foreach {elem var} $CFG(TransactionDetails,elements) {
		# get the formatted element
		set elem_f [core::api::emerchants::_format_xml_element ${elem} {d}]

		lappend transactions_params \
			$var "/${elem_f}" 0 {} 0 {} \
	}

	set list_params [list \
		transactions {//s:Envelope/s:Body/tem:GetTransactionHistoryResponse/tem:GetTransactionHistoryResult/a:Transactions} 0 {} 1 [list \
			transaction_details {/d:TransactionDetails} 0 {} 1 $transactions_params \
		] \
	]

	core::log::write DEBUG {$fn: <list_params:$list_params>}

	set map_res \
		[core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	core::log::write DEBUG {$fn: <map_res:$map_res>}

	set ret {}

	if {$map_res eq {}} {
		dict set ret result $map_res
		dict set ret status FAIL
		dict set ret code   {RESPONSE_PARSE_ERROR}
		dict set ret desc   {Could not get any Transactions in response}
		dict set ret info   {}
		return $ret
	}

	set transactions \
		[dict get $map_res transactions]
	set transaction_details \
		[dict get [lindex $transactions 0] transaction_details]

	set result {}

	foreach transaction $transaction_details {
		set id [dict get $transaction id]
		dict set result $id $transaction
	}

	core::log::write DEBUG {$fn: <result:$result>}

	dict set ret result  $result
	dict set ret status  OK

	return $ret
}


# create ActivateCard SOAP request
#
# Example:
#
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:ActivateCard>
#             <!--Optional:-->
#             <tem:request>
#                 <!--Optional:-->
#                 <eml:SecurityRequest>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Password>?</eml:Password>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Username>?</eml:Username>
#                 </eml:SecurityRequest>
#                 <!--Optional:-->
#                 <eml1:AccountId>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#                 </eml1:AccountId>
#             </tem:request>
#         </tem:ActivateCard>
#     </soapenv:Body>
# </soapenv:Envelope>
#
proc core::api::emerchants::_create_request_ActivateCard {
	envelope_name
	ext_acct_details
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_ActivateCard}

	set request {ActivateCard}

	if {[dict get $ext_acct_details ext_id] eq {}} {
		error "$fn: ext_acct_id is required"
	}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set act_elem_with_ns "tem:$request"
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  [dict get $ext_acct_details ext_id]
}


# parse response from Activate Card request
#
# Example:
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <ActivateCardResponse xmlns="http://tempuri.org/">
#             <ActivateCardResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#             </ActivateCardResult>
#         </ActivateCardResponse>
#     </s:Body>
# </s:Envelope>
# 
proc core::api::emerchants::_parse_response_ActivateCard {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_ActivateCard}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	core::log::write DEBUG {$fn: response}
	core::log::write DEBUG {[core::soap::print_soap -name $envelope_name -type {received}]}

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:ActivateCardResponse/tem:ActivateCardResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:ActivateCardResponse/tem:ActivateCardResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:ActivateCardResponse/tem:ActivateCardResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	# ActivateCard doesn't return anything apart from Success status
	set ret {}
	dict set ret status OK
	dict set ret result {}

	return $ret
}


# create DeactivateCard SOAP request
#
# Example
# <soapenv:Envelope
# 	xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
# 	xmlns:tem="http://tempuri.org/"
# 	xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
# 	xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
# 	xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:DeactivateCard>
#             <!--Optional:-->
#             <tem:request>
#                 <!--Optional:-->
#                 <eml:SecurityRequest>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Password>?</eml:Password>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml:Username>?</eml:Username>
#                 </eml:SecurityRequest>
#                 <!--Optional:-->
#                 <eml1:AccountId>
#                     <!--Optional:-->
#                     <!--type: string-->
#                     <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#                 </eml1:AccountId>
#                 <!--Optional:-->
#                 <!--type: int-->
#                 <eml1:ReasonCode>?</eml1:ReasonCode>
#             </tem:request>
#         </tem:DeactivateCard>
#     </soapenv:Body>
# </soapenv:Envelope>
# 
proc core::api::emerchants::_create_request_DeactivateCard {
	envelope_name
	ext_acct_details
	reason_code
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_DeactivateCard}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>\
		<ext_acct_details:$ext_acct_details> <reason_code:$reason_code>}

	set request {DeactivateCard}

	if {[dict get $ext_acct_details ext_id] eq {}} {
		error "$fn: ext_acct_id is required"
	}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set act_elem_with_ns "tem:$request"
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	set acc_id_with_ns "$CFG(AccountId,namespace):AccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $acc_id_with_ns

	set ext_acct_id_with_ns {eml2:ExternalAccountId}

	core::soap::add_element \
		-name   $envelope_name \
		-parent $acc_id_with_ns \
		-elem   $ext_acct_id_with_ns \
		-value  [dict get $ext_acct_details ext_id]

	# reason for deactivation
	set reason_code_with_ns "$CFG(ReasonCode,namespace):ReasonCode"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $reason_code_with_ns \
		-value  $reason_code
}


# parse response from DeactivateCard request
#
# Example:
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <DeactivateCardResponse xmlns="http://tempuri.org/">
#             <DeactivateCardResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base" i:nil="true"/>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">true</Success>
#             </DeactivateCardResult>
#         </DeactivateCardResponse>
#     </s:Body>
# </s:Envelope>
#
proc core::api::emerchants::_parse_response_DeactivateCard {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_DeactivateCard}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	core::log::write DEBUG {$fn: response}
	core::log::write DEBUG {[core::soap::print_soap -name $envelope_name -type {received}]}

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:DeactivateCardResponse/tem:DeactivateCardResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:DeactivateCardResponse/tem:DeactivateCardResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:DeactivateCardResponse/tem:DeactivateCardResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	# DeactivateCard only returns the Success status
	set ret {}
	dict set ret status OK
	dict set ret result {}

	return $ret
}



# create a Transfer SOAP request
#
# Example:
# <soapenv:Envelope
#     xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
#     xmlns:tem="http://tempuri.org/"
#     xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
#     xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO"
#     xmlns:eml2="http://schemas.datacontract.org/2004/07/EML.DTO.Identifiers">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:Transfer>
#             <!--Optional:-->
#             <tem:request>
#                 <!--Optional:-->
#                 <eml:SecurityRequest>
#                     <!--Optional:-->
#                     <eml:Password>?</eml:Password>
#                     <!--Optional:-->
#                     <eml:Username>?</eml:Username>
#                 </eml:SecurityRequest>
#                 <!--Optional:-->
#                 <eml1:Amount>?</eml1:Amount>
#                 <!--Optional:-->
#                 <eml1:DestinationAccountId>?</eml1:DestinationAccountId>
#                 <!--Optional:-->
#                 <eml1:DestinationReference>?</eml1:DestinationReference>
#                 <!--Optional:-->
#                 <eml1:SourceAccountId>
#                     <!--Optional:-->
#                     <eml2:ExternalAccountId>?</eml2:ExternalAccountId>
#                 </eml1:SourceAccountId>
#                 <!--Optional:-->
#                 <eml1:SourceReference>?</eml1:SourceReference>
#             </tem:request>
#         </tem:Transfer>
#     </soapenv:Body>
# </soapenv:Envelope>
proc core::api::emerchants::_create_request_Transfer {
	envelope_name
	src_ext_acct_details
	dest_ext_acct_details
	amount
	src_ref
	dest_ref
} {

	variable CFG
	variable SOAP_AUTH

	set fn {core::api::emerchants::_create_request_Transfer}

	core::log::write DEV {$fn: <envelope_name:$envelope_name>\
		<src_ext_acct_details:$src_ext_acct_details> <dest_ext_id:$dest_ext_id>\
		<amount:$amount> <dest_ref:$dest_ref>}

	if {[dict get $src_ext_acct_details  src_ext_id] eq {}
		|| [dict get $dest_ext_acct_details dest_ext_id] eq {}
	} {
		error "$fn: ext_acct_id is required"
	}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name \
		$CFG(all_namespaces)

	set request {Transfer}
	set act_elem_with_ns "tem:$request"
	set req_elem_with_ns {tem:request}

	core::soap::add_element \
		-name   $envelope_name \
		-parent {soapenv:Body} \
		-elem   $act_elem_with_ns

	core::soap::add_element \
		-name   $envelope_name \
		-parent $act_elem_with_ns \
		-elem   $req_elem_with_ns

	_add_security_credentials \
		$envelope_name \
		$SOAP_AUTH($request,username) \
		$SOAP_AUTH($request,password)

	# amount
	set amount_with_ns       "$CFG(Amount,namespace):Amount"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $amount_with_ns \
		-value  $amount

	# destination account
	set dest_acct_id_with_ns "$CFG(DestinationAccountId,namespace):DestinationAccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $dest_acct_id_with_ns \
		-attributes [list {i:type} {eml2:ExternalAccountIdentifier}]

	set dest_ext_acct_id_with_ns "$CFG(DestinationAccountId,children_namespace):ExternalAccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $dest_acct_id_with_ns \
		-elem   $dest_ext_acct_id_with_ns \
		-value  [dict get $dest_ext_acct_details dest_ext_id] \
		-label  {destExternalAccountId}


	# destination reference
	set dest_ref_with_ns     "$CFG(DestinationReference,namespace):DestinationReference"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $dest_ref_with_ns \
		-value  $dest_ref

	# source account
	set src_acc_id_with_ns "$CFG(SourceAccountId,namespace):SourceAccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $src_acc_id_with_ns

	set src_ext_acct_id_with_ns "$CFG(SourceAccountId,children_namespace):ExternalAccountId"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $src_acc_id_with_ns \
		-elem   $src_ext_acct_id_with_ns \
		-value  [dict get $src_ext_acct_details src_ext_id] \
		-label  {srcExternalAccountId}

	# source reference
	set src_ref_with_ns      "$CFG(SourceReference,namespace):SourceReference"

	core::soap::add_element \
		-name   $envelope_name \
		-parent $req_elem_with_ns \
		-elem   $src_ref_with_ns \
		-value  $src_ref

}


# Parse response from a Transfer request
#
# Example:
# <soapenv:Envelope 
#     xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
#     xmlns:tem="http://tempuri.org/"
#     xmlns:eml="http://schemas.datacontract.org/2004/07/EML.Services.Base"
#     xmlns:eml1="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO">
#     <soapenv:Header/>
#     <soapenv:Body>
#         <tem:TransferResponse>
#             <!--Optional:-->
#             <tem:TransferResult>
#                 <!--Optional:-->
#                 <eml:ErrorCode>
#                     <eml:_x003C_Code_x003E_k__BackingField>?</eml:_x003C_Code_x003E_k__BackingField>
#                     <eml:_x003C_Description_x003E_k__BackingField>?</eml:_x003C_Description_x003E_k__BackingField>
#                 </eml:ErrorCode>
#                 <!--Optional:-->
#                 <eml:ExtendedErrorInformation>?</eml:ExtendedErrorInformation>
#                 <!--Optional:-->
#                 <eml:Success>?</eml:Success>
#                 <!--Optional:-->
#                 <eml1:TransactionId>?</eml1:TransactionId>
#             </tem:TransferResult>
#         </tem:TransferResponse>
#     </soapenv:Body>
# </soapenv:Envelope>
proc core::api::emerchants::_parse_response_Transfer {
	envelope_name
} {

	variable CFG

	set fn {core::api::emerchants::_parse_response_Transfer}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name>}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	core::log::write DEBUG {$fn: response}
	core::log::write DEBUG {[core::soap::print_soap -name $envelope_name -type {received}]}

	set success [core::soap::get_element \
		-name  $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:TransferResponse/tem:TransferResult/eml:Success} \
	]

	core::log::write DEBUG {$fn: <success:$success>}

	if {$success ne {true}} {
		lassign [core::api::emerchants::_parse_error_info \
			$envelope_name \
			{//s:Envelope/s:Body/tem:TransferResponse/tem:TransferResult/eml:ErrorCode} \
			{//s:Envelope/s:Body/tem:TransferResponse/tem:TransferResult/eml:ExtendedErrorInformation} \
		] error_code error_desc error_info

		set errors {}
		dict set errors status FAIL
		dict set errors code   $error_code
		dict set errors desc   $error_desc
		dict set errors info   $error_info

		core::log::write ERROR {$fn: request failed <errors:$errors>}

		return $errors
	}

	set list_params [list \
		trans_id {//s:Envelope/s:Body/tem:TransferResponse/tem:TransferResult/eml1:TransactionId} 0 {} 0 {} \
	]

	core::log::write DEBUG {$fn: <list_params:$list_params>}

	set map_res [core::soap::map_to_dict -map $list_params -envelope_name $envelope_name]

	core::log::write DEBUG {$fn: <map_res:$map_res>}

	set ret {}
	dict set ret result $map_res

	if {$map_res eq {}} {
		dict set ret status FAIL
		dict set ret code   {RESPONSE_PARSE_ERROR}
		dict set ret desc   {Could not get TransactionId in response}
		dict set ret info   {}
		return $ret
	}

	dict set ret status OK
	return $ret
}



# create a ping SOAP request. NOT-USED
#
# Example:
# <s11:Envelope xmlns:s11='http://schemas.xmlsoap.org/soap/envelope/'>
#     <s11:Body>
#         <ns1:Ping xmlns:ns1='http://tempuri.org/' />
#     </s11:Body>
# </s11:Envelope>
# 
proc core::api::emerchants::_create_request_Ping {
	envelope_name
} {
	
	variable CFG

	set fn {core::api::emerchants::_create_request_Ping}

	core::log::write DEBUG {$fn: <envelope_name:$envelope_name}

	# create the SOAP envelope
	_create_envelope \
		$envelope_name

	set request {Ping}

	core::soap::add_element \
		-name $envelope_name \
		-parent {soapenv:Body} \
		-elem   {tem:Ping}
}


# parse response from a Ping request
#
# Example:
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <PingResponse xmlns="http://tempuri.org/">
#             <PingResult>07/09/2014 10:24:58: EML.Services.External, 1.0.0.59</PingResult>
#         </PingResponse>
#     </s:Body>
# </s:Envelope>
#
proc core::api::emerchants::_parse_response_Ping {envelope_name} {

	variable CFG 

	set fn {core::api::emerchants::_parse_response_Ping}

	core::soap::set_namespaces \
		-name $envelope_name \
		-namespaces $CFG(all_namespaces)

	set result [lindex [core::soap::get_element \
		-name $envelope_name \
		-xpath {//s:Envelope/s:Body/tem:PingResponse/tem:PingResult} \
	] 0]

	core::log::write DEBUG {$fn: <result:$result>}

	set ret {}
	dict set ret result $result

	if {$result eq {}} {
		dict set ret status FAIL
		return $ret
	}

	dict set ret status OK
	return $ret
}



# Examples of error responses
# ===========================
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <ActivateCardResponse xmlns="http://tempuri.org/">
#             <ActivateCardResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">
#                     <_x003C_Code_x003E_k__BackingField>95</_x003C_Code_x003E_k__BackingField>
#                     <_x003C_Description_x003E_k__BackingField>Invalid operation</_x003C_Description_x003E_k__BackingField>
#                 </ErrorCode>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">The status of a cancelled/closed card can not be changed.</ExtendedErrorInformation>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">false</Success>
#             </ActivateCardResult>
#         </ActivateCardResponse>
#     </s:Body>
# </s:Envelope>
#
#
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <DeactivateCardResponse xmlns="http://tempuri.org/">
#             <DeactivateCardResult xmlns:a="http://schemas.datacontract.org/2004/07/EML.Services.External.Shared.DTO" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                 <ErrorCode xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">
#                     <_x003C_Code_x003E_k__BackingField>90</_x003C_Code_x003E_k__BackingField>
#                     <_x003C_Description_x003E_k__BackingField>Operation failed due to invalid parameters</_x003C_Description_x003E_k__BackingField>
#                 </ErrorCode>
#                 <ExtendedErrorInformation xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">Failed validation for request fields: ReasonCode</ExtendedErrorInformation>
#                 <Success xmlns="http://schemas.datacontract.org/2004/07/EML.Services.Base">false</Success>
#             </DeactivateCardResult>
#         </DeactivateCardResponse>
#     </s:Body>
# </s:Envelope>
#
#
# 
# <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
#     <s:Body>
#         <s:Fault>
#             <faultcode xmlns:a="http://schemas.microsoft.com/net/2005/12/windowscommunicationfoundation/dispatcher">a:DeserializationFailed</faultcode><faultstring xml:lang="en-AU">The formatter threw an exception while trying to deserialize the message: There was an error while trying to deserialize parameter http://tempuri.org/:request. The InnerException message was 'Error in line 23 position 61. 'Element' '_x003C_Title_x003E_k__BackingField' from namespace 'http://schemas.datacontract.org/2004/07/EML.DTO.Users' is not expected. Expecting element '_x003C_Suburb_x003E_k__BackingField'.'.  Please see InnerException for more details.</faultstring>
#             <detail>
#                 <ExceptionDetail xmlns="http://schemas.datacontract.org/2004/07/System.ServiceModel" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
#                     <HelpLink i:nil="true"/>
#                     <InnerException>
#                         <HelpLink i:nil="true"/><InnerException i:nil="true"/>
#                         <Message>Error in line 23 position 61. 'Element' '_x003C_Title_x003E_k__BackingField' from namespace 'http://schemas.datacontract.org/2004/07/EML.DTO.Users' is not expected. Expecting element '_x003C_Suburb_x003E_k__BackingField'.</Message><StackTrace>   at System.Runtime.Serialization.XmlObjectSerializerReadContext.ThrowRequiredMemberMissingException(XmlReaderDelegator xmlReader, Int32 memberIndex, Int32 requiredIndex, XmlDictionaryString[] memberNames)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.GetMemberIndexWithRequiredMembers(XmlReaderDelegator xmlReader, XmlDictionaryString[] memberNames, XmlDictionaryString[] memberNamespaces, Int32 memberIndex, Int32 requiredIndex, ExtensionDataObject extensionData)&#xD;
#                             at ReadClientDetailsFromXml(XmlReaderDelegator , XmlObjectSerializerReadContext , XmlDictionaryString[] , XmlDictionaryString[] )&#xD;
#                             at System.Runtime.Serialization.ClassDataContract.ReadXmlValue(XmlReaderDelegator xmlReader, XmlObjectSerializerReadContext context)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.ReadDataContractValue(DataContract dataContract, XmlReaderDelegator reader)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator reader, String name, String ns, Type declaredType, DataContract&amp; dataContract)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator xmlReader, Int32 id, RuntimeTypeHandle declaredTypeHandle, String name, String ns)&#xD;
#                             at ReadCreateAccountRequestFromXml(XmlReaderDelegator , XmlObjectSerializerReadContext , XmlDictionaryString[] , XmlDictionaryString[] )&#xD;
#                             at System.Runtime.Serialization.ClassDataContract.ReadXmlValue(XmlReaderDelegator xmlReader, XmlObjectSerializerReadContext context)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.ReadDataContractValue(DataContract dataContract, XmlReaderDelegator reader)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator reader, String name, String ns, Type declaredType, DataContract&amp; dataContract)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializerReadContext.InternalDeserialize(XmlReaderDelegator xmlReader, Type declaredType, DataContract dataContract, String name, String ns)&#xD;
#                             at System.Runtime.Serialization.DataContractSerializer.InternalReadObject(XmlReaderDelegator xmlReader, Boolean verifyObjectName, DataContractResolver dataContractResolver)&#xD;
#                             at System.Runtime.Serialization.XmlObjectSerializer.ReadObjectHandleExceptions(XmlReaderDelegator reader, Boolean verifyObjectName, DataContractResolver dataContractResolver)&#xD;
#                             at System.Runtime.Serialization.DataContractSerializer.ReadObject(XmlDictionaryReader reader, Boolean verifyObjectName)&#xD;
#                             at System.ServiceModel.Dispatcher.DataContractSerializerOperationFormatter.DeserializeParameterPart(XmlDictionaryReader reader, PartInfo part, Boolean isRequest)
#                         </StackTrace>
#                         <Type>System.Runtime.Serialization.SerializationException</Type>
#                     </InnerException>
#                     <Message>The formatter threw an exception while trying to deserialize the message: There was an error while trying to deserialize parameter http://tempuri.org/:request. The InnerException message was 'Error in line 23 position 61. 'Element' '_x003C_Title_x003E_k__BackingField' from namespace 'http://schemas.datacontract.org/2004/07/EML.DTO.Users' is not expected. Expecting element '_x003C_Suburb_x003E_k__BackingField'.'.  Please see InnerException for more details.</Message><StackTrace>   at System.ServiceModel.Dispatcher.DataContractSerializerOperationFormatter.DeserializeParameterPart(XmlDictionaryReader reader, PartInfo part, Boolean isRequest)&#xD;
#                         at System.ServiceModel.Dispatcher.DataContractSerializerOperationFormatter.DeserializeParameter(XmlDictionaryReader reader, PartInfo part, Boolean isRequest)&#xD;
#                         at System.ServiceModel.Dispatcher.DataContractSerializerOperationFormatter.DeserializeParameters(XmlDictionaryReader reader, PartInfo[] parts, Object[] parameters, Boolean isRequest)&#xD;
#                         at System.ServiceModel.Dispatcher.DataContractSerializerOperationFormatter.DeserializeBody(XmlDictionaryReader reader, MessageVersion version, String action, MessageDescription messageDescription, Object[] parameters, Boolean isRequest)&#xD;
#                         at System.ServiceModel.Dispatcher.OperationFormatter.DeserializeBodyContents(Message message, Object[] parameters, Boolean isRequest)&#xD;
#                         at System.ServiceModel.Dispatcher.OperationFormatter.DeserializeRequest(Message message, Object[] parameters)&#xD;
#                         at System.ServiceModel.Dispatcher.DispatchOperationRuntime.DeserializeInputs(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.DispatchOperationRuntime.InvokeBegin(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage5(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage41(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage4(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage31(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage3(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage2(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage11(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.ImmutableDispatchRuntime.ProcessMessage1(MessageRpc&amp; rpc)&#xD;
#                         at System.ServiceModel.Dispatcher.MessageRpc.Process(Boolean isOperationContextSet)
#                     </StackTrace>
#                     <Type>System.ServiceModel.Dispatcher.NetDispatcherFaultException</Type>
#                 </ExceptionDetail>
#             </detail>
#         </s:Fault>
#     </s:Body>
# </s:Envelope>


# returns a canonicalised xml element name
#
# @param  elem - name of the xml element
# @param  ns   - namespace of the element if required
#
proc core::api::emerchants::_format_xml_element {
	elem
	{ns {}}
} {
	variable CFG

	# formatted element
	set elem_f [format "%s%s%s" $CFG(prefix) $elem $CFG(suffix)]

	# no namespace required
	if {$ns eq {}} {
		return $elem_f
	}

	# element name with namespace
	return [format "%s:%s" ${ns} $elem_f]
}



# vim: set ts=8 sw=8 nowrap noet:
