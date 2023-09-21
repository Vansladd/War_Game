# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# POLi payment harness
#
# http://www.polipayments.com/
#

load libOT_Tcl.so
set ::xtn tcl

set pkg_version 1.0
package provide core::harness::payment::POLI $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0
package require core::stub    1.0

core::args::register_ns \
	-namespace core::harness::payment::POLI \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check \
		core::stub]

namespace eval core::harness::payment::POLI  {
	variable CFG
	variable HARNESS_DATA

	dict set HARNESS_DATA INIT_TRAN          data success       {transaction_status_code {Initiated}}
	dict set HARNESS_DATA INIT_TRAN          data oper_err_init {errors 1 error_code 8003 error_message {An operational error occured}}
	dict set HARNESS_DATA INIT_TRAN          data oper_err_get  {transaction_status_code {Initiated}}

	dict set HARNESS_DATA GET_TRAN           data success       {transaction_status_code {Completed}}
	dict set HARNESS_DATA GET_TRAN           data oper_err_get  {transaction_status_code {Failed} errors 1 error_code 8003 error_message {An operational error occured}}

	dict set HARNESS_DATA GET_DETAILED_TRAN  data success       {transaction_status_code {Completed}}
	dict set HARNESS_DATA GET_DETAILED_TRAN  data oper_err_get  {transaction_status_code {Failed} errors 1 error_code 8003 error_message {An operational error occured}}



	dict set HARNESS_DATA INIT_TRAN template {
		<?xml version="1.0" encoding="utf-8"?>
		<InitiateTransactionResponse xmlns="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
			##TP_IF {[tpGetVar errors 0]}##
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"> 
				<dco:Error>
					<dco:Code>##TP_error_code##</dco:Code>
					<dco:Field>##TP_error_field##</dco:Field>
					<dco:Message>##TP_error_message##</dco:Message>
				</dco:Error>
			</Errors>
			<TransactionStatusCode i:nil="true" />
			<Transaction i:nil="true" xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"/>
			##TP_ELSE##
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"/>
			<TransactionStatusCode>##TP_transaction_status_code##</TransactionStatusCode>
			<Transaction xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO">
				<dco:NavigateURL>https://transaction.apac.paywithpoli.com/Default.aspc?token=##TP_transaction_token##</dco:NavigateURL>
				<dco:TransactionRefNo>##TP_transaction_ref_no##</dco:TransactionRefNo>
				<dco:TransactionToken>##TP_transaction_token##</dco:TransactionToken>
			</Transaction>
			##TP_ENDIF##
		</InitiateTransactionResponse>
	}

	dict set HARNESS_DATA GET_TRAN template {
		<?xml version="1.0" encoding="utf-8"?>
		<GetTransactionResponse xmlns="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
			##TP_IF {[tpGetVar errors 0]}##
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"> 
				<dco:Error>
					<dco:Code>##TP_error_code##</dco:Code>
					<dco:Field>##TP_error_field##</dco:Field>
					<dco:Message>##TP_error_message##</dco:Message>
				</dco:Error>
			</Errors>
			##TP_ELSE##
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"/>
			##TP_ENDIF##
			<TransactionStatusCode>##TP_transaction_status_code##</TransactionStatusCode>
			##TP_IF {[tpGetVar errors 0]}##
			<Transaction i:nil="true" xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO"/>
			##TP_ELSE##
			<Transaction xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO">
				<dco:AmountPaid>##TP_amount_paid##</dco:AmountPaid>
				<dco:BankReceipt>##TP_bank_receipt##</dco:BankReceipt>
				<dco:BankReceiptDateTime>##TP_bank_receipt_date_time##</dco:BankReceiptDateTime>
				<dco:CountryCode>##TP_country_code##</dco:CountryCode>
				<dco:CountryName>##TP_country_name##</dco:CountryName>
				<dco:CurrencyCode>##TP_ccy_code##</dco:CurrencyCode>
				<dco:CurrencyName>##TP_ccy_name##</dco:CurrencyName>
				<dco:EndDateTime>##TP_end_date_time##</dco:EndDateTime>
				<dco:ErrorCode i:nil="true"/>
				<dco:ErrorMessage i:nil="true"/>
				<dco:EstablishedDateTime>##TP_established_date_time##</dco:EstablishedDateTime>
				<dco:FinancialInstitutionCode>##TP_financial_institution_code##</dco:FinancialInstitutionCode>
				<dco:FinancialInstitutionCountryCode>##TP_financial_institution_country_code##</dco:FinancialInstitutionCountryCode>
				<dco:FinancialInstitutionName>##TP_financial_institution_name##</dco:FinancialInstitutionName>
				<dco:MerchantAcctName>##TP_merchant_acct_name##</dco:MerchantAcctName>
				<dco:MerchantAcctNumber>##TP_merchant_acct_num##</dco:MerchantAcctNumber>
				<dco:MerchantAcctSortCode>##TP_merchant_acct_sort_code##</dco:MerchantAcctSortCode>
				<dco:MerchantAcctSuffix/>
				<dco:MerchantDefinedData>##TP_merchant_defined_data##</dco:MerchantDefinedData>
				<dco:MerchantEstablishedDateTime>##TP_merchant_established_date_time##</dco:MerchantEstablishedDateTime>
				<dco:MerchantReference>##TP_merchant_reference##</dco:MerchantReference>
				<dco:PaymentAmount>##TP_payment_amount##</dco:PaymentAmount>
				<dco:StartDateTime>##TP_start_date_time##</dco:StartDateTime>
				<dco:TransactionID>##TP_transaction_id##</dco:TransactionID>
				<dco:TransactionRefNo>##TP_transaction_ref_no##</dco:TransactionRefNo>
			</Transaction>
			##TP_ENDIF##
		</GetTransactionResponse>
	}

	dict set HARNESS_DATA GET_DETAILED_TRAN template {
		<?xml version="1.0" encoding="utf-8"?>
		<GetDetailedTransactionResponse xmlns="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
			##TP_IF {[tpGetVar errors 0]}##			
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO">
				<dco:Error>
					<dco:Code>2007</dco:Code>
					<dco:Field />
					<dco:Message>POLi is unable to continue with this payment. Please contact the Merchant for assistance. </dco:Message>
				</dco:Error>
			</Errors>
			<TransactionStatusCode>Failed</TransactionStatusCode>
			<Transaction i:nil="true" xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO" />
			##TP_ELSE##
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO" />
			<DetailedTransaction xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO">
				<dco:AmountPaid>##TP_amount_paid##</dco:AmountPaid>
				<dco:BankReceiptNo i:nil="true" />
				<dco:CurrencyCode>##TP_country_code##</dco:CurrencyCode>
				<dco:CurrencyName>##TP_country_name##</dco:CurrencyName>
				<dco:EndDateTime>##TP_end_date_time##</dco:EndDateTime>
				<dco:EstablishedDateTime>##TP_established_date_time##</dco:EstablishedDateTime>
				<dco:FailureReason i:nil="true" />
				<dco:FinancialInstitutionCode>##TP_financial_institution_code##</dco:FinancialInstitutionCode>
				<dco:FinancialInstitutionName>##TP_financial_institution_name##</dco:FinancialInstitutionName>
				<dco:MerchantCode>##TP_merchant_code##</dco:MerchantCode>
				<dco:MerchantCommonName>##TP_merchant_common_name##</dco:MerchantCommonName>
				<dco:MerchantDefinedData>##TP_merchant_defined_data##</dco:MerchantDefinedData>
				<dco:MerchantReference>##TP_merchant_reference##</dco:MerchantReference>
				<dco:PaymentAmount>##TP_payment_amount##</dco:PaymentAmount>
				<dco:TransactionRefNo>##TP_transaction_ref_no##</dco:TransactionRefNo>
				<dco:TransactionStatus>##TP_transaction_status##</dco:TransactionStatus>
				<dco:TransactionStatusCode>##TP_transaction_status_code##</dco:TransactionStatusCode>
				<dco:UserIPAddress>##TP_user_ip_address##</dco:UserIPAddress>
				<dco:UserPlatform>##TP_user_platform##</dco:UserPlatform>
			</DetailedTransaction>
			<TransactionStepList xmlns:dco="http://schemas.datacontraci.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO" >
				<dco:TransactionStepsList>
					<dco:CreatedDateTime>2008-08-22T14:07:22.023</dco:CreatedDateTime>
					<dco:TransactionStepTypeName>status has changed to Initiated</dco:TransactionStepTypeName>
				</dco:TransactionStepsList>
			</TransactionStepList>
			##TP_ENDIF##
		</GetDetailedTransactionResponse>
	}

	dict set HARNESS_DATA GET_FIN_INST template {
		<?xml version="1.0" encoding="utf-8"?>
        <GetFinancialInstitutionsResponse xmlns="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
			<Errors xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO" />
			<TransactionStatusCode i:nil="true" />
			<FinancialInstitutionList xmlns:dco="http://schemas.datacontract.org/2004/07/Centricom.POLi.Services.MerchantAPI.DCO">
				##TP_LOOP financial_institutions {[tpGetVar num_financial_institutions 0]}##
				<dco:FinancialInstitution>
					<dco:FinancialInstitutionCode>##TP_financial_institution_code##</dco:FinancialInstitutionCode>
					<dco:FinancialInstitutionName>##TP_financial_institution_code##</dco:FinancialInstitutionName>
				</dco:FinancialInstitution>
				##TP_ENDLOOP##
			</FinancialInstitutionList>
		</GetFinancialInstitutionsResponse>
	}

}

core::args::register \
	-proc_name {core::harness::payment::POLI::expose_magic} \
	-body {
		variable HARNESS_DATA
		set i 0

		set MAGIC(0,header) {Financial Institution Code}
		set MAGIC(1,header) {Response Data}

		foreach request_type [dict keys $HARNESS_DATA] {

			if {[dict exists $HARNESS_DATA $request_type data]} {
				set MAGIC($i,request_type) "$request_type POLi request"
				set j 0

				foreach key [dict keys [dict get $HARNESS_DATA $request_type data]] {
					if {[dict exists $HARNESS_DATA $request_type data $key]} {
						set data [dict get $HARNESS_DATA $request_type data $key]
						set MAGIC($i,$j,0,column) $key
						set MAGIC($i,$j,1,column) $data
						core::log::write DEV {$request_type - $key - $data}
						incr j
					}
				}
				set MAGIC($i,num_rows) $j
				incr i
			}
		}
		set MAGIC(num_requests) $i
		set MAGIC(num_columns) 2

		return [array get MAGIC]
	}

# Register POLi interface interface.
core::args::register \
	-proc_name core::harness::payment::POLI::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg POLI_HARNESS_ENABLED -default 0 -desc {Enable the Poli harness}] \
	] \
	-body {
		if {!$ARGS(-enabled)} {
			core::log::write INFO {Harness available though disabled}
			return
		}

		core::log::xwrite -msg {Harness available and enabled} -colour yellow

		set ::ob_poli::PMT_DATA(client)       TEST
		set ::ob_poli::PMT_DATA(password)     1234
		set ::ob_poli::PMT_DATA(host)         http://www.test.com
		set ::ob_poli::PMT_DATA(conn_timeout) 50

		variable HARNESS_DATA

		core::harness::payment::POLI::_prep_qrys

		core::stub::define_procs \
			-proc_definition [list \
				core::socket send_req \
				core::socket req_info \
				core::socket clear_req \
			] \
			-scope           proc \
			-pass_through    1 \
			

		# Send request overrides
		core::stub::set_override \
			-proc_name   core::socket::send_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::make_deposit} \
			-body {
				return [core::harness::payment::POLI::_prepare_response_INIT_TRAN -http_request [lindex $args end-2]]
			} \
			-use_body_return 1


		core::stub::set_override \
			-proc_name   core::socket::send_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::complete_payment} \
			-body {
				core::log::xwrite -msg {get_transaction->send_req override called} -colour yellow
				return [core::harness::payment::POLI::_prepare_response_GET_TRAN -http_request [lindex $args end-2]]
			} \
			-use_body_return 1

		core::stub::set_override \
			-proc_name   core::socket::send_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_detailed_tran} \
			-body {
				core::log::xwrite -msg {get_detailed_transaction->send_req override called} -colour yellow
				return [core::harness::payment::POLI::_prepare_response_GET_DETAILED_TRAN -http_request [lindex $args end-2]]
			} \
			-use_body_return 1

		core::stub::set_override \
			-proc_name   core::socket::send_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_financial_inst} \
			-body {
				core::log::xwrite -msg {get_financial_inst->send_req override called} -colour yellow
				return [core::harness::payment::POLI::_prepare_response_GET_FIN_INST -http_request [lindex $args end-2]]
			} \
			-use_body_return 1


		# Req info overrides
		core::stub::set_override \
			-proc_name   core::socket::req_info \
			-scope       proc \
			-scope_key   {::core::payment::POLI::make_deposit} \
			-body {
				return [core::harness::payment::POLI::_get_response]
			} \
			-use_body_return 1


		core::stub::set_override \
			-proc_name   core::socket::req_info \
			-scope       proc \
			-scope_key   {::core::payment::POLI::complete_payment} \
			-body {
				return [core::harness::payment::POLI::_get_response]
			} \
			-use_body_return 1

		core::stub::set_override \
			-proc_name   core::socket::req_info \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_detailed_tran} \
			-body {
				return [core::harness::payment::POLI::_get_response]
			} \
			-use_body_return 1

		core::stub::set_override \
			-proc_name   core::socket::req_info \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_financial_inst} \
			-body {
				return [core::harness::payment::POLI::_get_response]
			} \
			-use_body_return 1

		# clear_req overrides
		core::stub::set_override \
			-proc_name   core::socket::clear_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::make_deposit} \
			-return_data 1

		core::stub::set_override \
			-proc_name   core::socket::clear_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::complete_payment} \
			-return_data 1

		core::stub::set_override \
			-proc_name   core::socket::clear_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_detailed_tran} \
			-return_data 1

		core::stub::set_override \
			-proc_name   core::socket::clear_req \
			-scope       proc \
			-scope_key   {::core::payment::POLI::get_financial_inst} \
			-return_data 1
	}

# Return the prepared response and clear it out of the dictionary
core::args::register \
	-proc_name {core::harness::payment::POLI::_get_response} \
	-desc      {Get the prepared response data} \
	-body {
		variable HARNESS_DATA
		set response [dict get $HARNESS_DATA response]
		dict unset HARNESS_DATA response

		return $response
	}

core::args::register \
	-proc_name {core::harness::payment::POLI::_prep_qrys} \
	-desc      {Prepare sql queries. This should be called in the harness's init proc} \
	-body {
		core::db::store_qry -name core::harness::payment::POLI::get_pmt_info -qry {
			select
				c.country_code,
				p.amount,
				c.username as cust_username,
				c.acct_no as cust_acct_no,
				a.ccy_code,
				ctry.country_name,
				ccy.ccy_name,
				pb.bank_code,
				pb.bank_name,
				pp.cr_date
			from
				tCustomer c,
				tPmt p,
				tPmtPoli pp,
				tAcct a,
				tCountry ctry,
				tCCY ccy,
				tPoliBank pb
			where
				pp.poli_token = ?
				and pp.pmt_id = p.pmt_id
				and p.acct_id = a.acct_id
				and a.cust_id = c.cust_id
				and c.country_code = ctry.country_code
				and a.ccy_code = ccy.ccy_code
				and pp.bank_id = pb.bank_id
		}

		# add more queries here
	}

core::args::register \
	-proc_name {core::harness::payment::POLI::_get_request_doc} \
	-desc      {Pull out the xml from the request and creat and XML doc} \
	-args      [list \
		[list -arg -http_request -mand 1 -check ASCII -desc {The HTTP request}] \
	] \
	-body {
		set request $ARGS(-http_request)

		set body_start [string first "\n\r" $request]

		if {$body_start == -1} {
			# No body found
			core::log::xwrite \
				-msg    {Request Body not found in request : $request} \
				-colour red
			return [list -0 {Request Body not found in request}]
		}

		set xml [string range $request [expr {$body_start + 2}] end]

		foreach {status doc} [core::xml::parse -strict 0 -xml $xml] {}

		if {$status != {OK}} {
			core::log::xwrite \
				-msg    {Unable to parse xml: $req} \
				-colour red
			return [list 0 {Unable to parse xml}]
		}

		return [list 1 $doc]
	}


core::args::register \
	-proc_name {core::harness::payment::POLI::_prepare_response_INIT_TRAN} \
	-desc      {} \
	-args      [list \
		[list -arg -http_request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		foreach {status doc} [_get_request_doc -http_request $ARGS(-http_request)] {}

		if {!$status} {
			return [list -1 HTTP_INVALID 1]
		}

		# Pull out the bank code from the request to use as a key into the HARNESS_DATA
		# dictionary
		foreach {param xpath} {
			bank_code              /*[local-name()='InitiateTransactionRequest']/*[local-name()='Transaction']/*[local-name()='SelectedFICode']
		} {
			if {[catch {
				set $param [core::xml::extract_data \
					-node $doc \
					-xpath $xpath \
					-return_list 1]
			} msg]} {
				set $param {}
			}
		}

		# Is the bank code we found in HANRESS_DATA
		if {![dict exists $HARNESS_DATA INIT_TRAN data $bank_code]} {
			core::log::xwrite \
				-msg    {Unexpected bank code '$bank_code', defaulting to bank code: 'success'} \
				-colour yellow
			set bank_code "success"
		}

		set response_data [dict get $HARNESS_DATA INIT_TRAN data $bank_code]

		# Bind up the response specific data
		foreach {param value} $response_data {
			if {$param == {errors}} {
				tpSetVar $param $value
			} else {
				tpBindString $param $value
			}
		}

		# Generate a token which is unique and also contains the
		# bank code for future get transaction requests
		set token "[OT_UniqueId]_$bank_code"
		set token [urlencode -form false $token]

		tpBindString transaction_ref_no $token
		tpBindString transaction_token  $token

		dict set HARNESS_DATA response [tpStringPlay -tostring [dict get $HARNESS_DATA INIT_TRAN template]]

		tpDelVar errors

		return [list 1 OK 1]
	}


core::args::register \
	-proc_name {core::harness::payment::POLI::_prepare_response_GET_TRAN} \
	-desc      {} \
	-args      [list \
		[list -arg -http_request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		foreach {status doc} [_get_request_doc -http_request $ARGS(-http_request)] {}

		if {!$status} {
			return [list -1 HTTP_INVALID 1]
		}

		# Pull out the transaction token from the request.
		foreach {param xpath} {
			transaction_token             /*[local-name()='GetTransactionRequest']/*[local-name()='TransactionToken']
		} {
			if {[catch {
				set $param [core::xml::extract_data \
					-node $doc \
					-xpath $xpath \
					-return_list 1]
			} msg]} {
				set $param {}
			}
		}

		# The transaction token contains an embedded bank_code which we need to use as a key
		# into the HARNESS_DATA dictionary
		if {[string length $transaction_token] >= 29} {

			set bank_code [string range $transaction_token 29 end]

			if {![dict exists $HARNESS_DATA GET_TRAN data $bank_code]} {
				core::log::xwrite \
					-msg    {Unexpected bank code '$bank_code' embedded in transaction token for test 
						harness, defaulting to bank code: 'success'} 
				set bank_code "success"
			}		
		} else {
			core::log::xwrite \
				-msg    {The length of token '$transaction_token' is invalid for the test harness reverting to default behavior: success response}
			set bank_code "success"
		}

		set response_data [dict get $HARNESS_DATA GET_TRAN data $bank_code]

		# Bind up the response specific data
		foreach {param value} $response_data {
			if {$param == {errors}} {
				tpSetVar $param $value
			} else {
				tpBindString $param $value
			}
		}

		# The harness does not store any request data so we have to 'fake' the transaction
		# details which are specific to the individual payment. We do this by using values
		# out of the database.
		if {[catch {
			set rs [core::db::exec_qry \
				-name core::harness::payment::POLI::get_pmt_info \
				-args [list $transaction_token]]
		} msg]} {
			core::log::write ERROR {Failed to find pmt details in database : $msg}
			return [list -1 "HTTP_INVALID" 1]
		}

		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
				core::log::write ERROR {Failed to find pmt details in database : found $nrows entries}
				core::db::rs_close -rs $rs
				return [list -1 "HTTP_INVALID" 1]
		}

		tpBindString amount_paid                     [db_get_col $rs 0 amount]	
		tpBindString bank_receipt                    "98742364-5" ; # made up
		tpBindString bank_receipt_date_time          [db_get_col $rs 0 cr_date]
		tpBindString country_code                    [db_get_col $rs 0 country_code]
		tpBindString country_name                    [db_get_col $rs 0 country_name]
		tpBindString ccy_code                        [db_get_col $rs 0 ccy_code]
		tpBindString ccy_name                        [db_get_col $rs 0 ccy_name]
		tpBindString end_date_time                   [db_get_col $rs 0 cr_date]
		tpBindString established_date_time           [db_get_col $rs 0 cr_date]
		tpBindString financial_institution_code      [db_get_col $rs 0 bank_code]
		tpBindString financial_institution_ccy_code  [db_get_col $rs 0 bank_code] ; # tCPMBank.country_code
		tpBindString financial_institution_name      [db_get_col $rs 0 bank_name] ; # tCPMBank.bank_name
		tpBindString merchant_acct_name              [db_get_col $rs 0 cust_username] ; #tCustomer.username
		tpBindString merchant_acct_num               [db_get_col $rs 0 cust_acct_no] ; #tCustomer.acct_no
		tpBindString merchant_acct_sort_code         "345345" ; # made up
		tpBindString merchant_defined_data           ""			
		tpBindString merchant_established_date_time  [db_get_col $rs 0 cr_date]
		tpBindString merchant_reference              "78589" ; # made up... or should it be this? : $::ob_poli::PMT_DATA(client)
		tpBindString payment_amount                  [db_get_col $rs 0 amount]
		tpBindString start_date_time                 [db_get_col $rs 0 cr_date]
		tpBindString transaction_id                  $transaction_token
		tpBindString transaction_ref_no              $transaction_token

		dict set HARNESS_DATA response [tpStringPlay -tostring [dict get $HARNESS_DATA GET_TRAN template]]

		tpDelVar errors

		return [list 1 OK]
	}


core::args::register \
	-proc_name {core::harness::payment::POLI::_prepare_response_GET_DETAILED_TRAN} \
	-desc      {} \
	-args      [list \
		[list -arg -http_request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		foreach {status doc} [_get_request_doc -http_request $ARGS(-http_request)] {}

		if {!$status} {
			return [list -1 HTTP_INVALID 1]
		}

		# Pull out the transaction reference number from the request.
		foreach {param xpath} {
			transaction_ref_no             /*[local-name()='GetDetailedTransactionRequest']/*[local-name()='TransactionRefNo']
		} {
			if {[catch {
				set $param [core::xml::extract_data \
					-node $doc \
					-xpath $xpath \
					-return_list 1]
			} msg]} {
				set $param {}
			}
		}

		# The harness sets the transaction token and ref num the same for clarity sake we now explicitly set the token
		set transaction_token $transaction_ref_no

		# The transaction token contains an embedded bank_code which we need to use as a key
		# into the HARNESS_DATA dictionary
		if {[string length $transaction_token] >= 29} {

			set bank_code [string range $transaction_token 29 end]

			if {![dict exists $HARNESS_DATA GET_DETAILED_TRAN data $bank_code]} {
				core::log::xwrite \
					-msg {Unexpected bank code '$bank_code' embedded in transaction token for test 
						harness, defaulting to bank code: 'success'} 
				set bank_code "success"
			}		
		} else {
			core::log::xwrite \
				-msg    {The length of token '$transaction_token' is invalid for the test harness 
				reverting to default behavior: success response}
			set bank_code "success"
		}

		set response_data [dict get $HARNESS_DATA GET_DETAILED_TRAN data $bank_code]

		foreach {param value} $response_data {
			if {$param == {errors}} {
				tpSetVar $param $value
			} else {
				puts "$param - $value"
				set          $param $value
				tpBindString $param $value
			}
		}

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::harness::payment::POLI::get_pmt_info \
				-args [list $transaction_token]]
		} msg]} {
			core::log::write ERROR {Failed to find pmt details in database : $msg}
			return [list -1 "HTTP_INVALID" 1]
		}

		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			core::log::write ERROR {Failed to find pmt details in database : found $nrows entries}
			core::db::rs_close -rs $rs
			return [list -1 "HTTP_INVALID" 1]
		}

		# values common to get_transaction
		tpBindString amount_paid                     [db_get_col $rs 0 amount]	
		tpBindString bank_receipt                    "10000-1"
		tpBindString bank_receipt_date_time          [db_get_col $rs 0 cr_date]
		tpBindString ccy_code                        [db_get_col $rs 0 ccy_code]
		tpBindString ccy_name                        [db_get_col $rs 0 ccy_name]
		tpBindString end_date_time                   [db_get_col $rs 0 cr_date]
		tpBindString established_date_time           [db_get_col $rs 0 cr_date]
		tpBindString financial_institution_code      [db_get_col $rs 0 bank_code]
		tpBindString financial_institution_name      [db_get_col $rs 0 bank_name]
		tpBindString merchant_defined_data           ""
		tpBindString merchant_reference              "10000"
		tpBindString payment_amount                  [db_get_col $rs 0 amount]
		tpBindString transaction_ref_no              $transaction_ref_no

		# values not common to get_transaction
		tpBindString merchant_code                   "OPENBET"
		tpBindString merchant_common_name            "OpenBet Ltd."
		tpBindString user_ip_address                 "127.0.0.1"
		tpBindString user_platform                   "0S: Windows Vista, Browser: IE7.0, .NET Framework: 3.5.30428"
		#let transaction status = transaction_status_code		
		tpBindString transaction_status              $transaction_status_code

		dict set HARNESS_DATA response [tpStringPlay -tostring [dict get $HARNESS_DATA GET_DETAILED_TRAN template]]

		return [list 1 OK]
	}

core::args::register \
	-proc_name {core::harness::payment::POLI::_prepare_response_GET_FIN_INST} \
	-desc      {Prepare the response for the get financial institutions request} \
	-args      [list \
		[list -arg -http_request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA
		global BANK_CODES

		foreach {status doc} [_get_request_doc -http_request $ARGS(-http_request)] {}

		if {!$status} {
			return [list -1 HTTP_INVALID 1]
		}

		#Make a list of all bank codes used as keys in the dictionary
		set bank_code_list [dict keys [dict get $HARNESS_DATA INIT_TRAN data]]
		lappend $bank_code_list [dict keys [dict get $HARNESS_DATA GET_TRAN data]]
		lappend $bank_code_list [dict keys [dict get $HARNESS_DATA GET_DETAILED_TRAN data]]

		set BANK_CODES(success) 1

		# Remove duplicates
		foreach bank_code $bank_code_list {
			set BANK_CODES($bank_code) 1
		}
		set bank_code_list [array names BANK_CODES]

		for {set i 0} {$i < [llength $bank_code_list]} {incr i} {
			set BANK_CODES($i,bank_code) [lindex $bank_code_list $i]
		}

		tpBindVar financial_institution_code  BANK_CODES bank_code financial_institutions
		tpSetVar  num_financial_institutions  [llength $bank_code_list]

		dict set HARNESS_DATA response [tpStringPlay -tostring [dict get $HARNESS_DATA GET_FIN_INST template]]

		return [list 1 OK]
	}
