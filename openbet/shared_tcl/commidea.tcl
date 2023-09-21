# $Id: commidea.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd.  All rights reserved.
#
# OpenBet Commidea API
#
# CONFIG
#
# Attribute set in all xml requests, required by Commedia
# COMMIDEA_XMLNS = https://www.commidea.webservices.com
#
# PROCEDURES
#
# public:
#    ob_commidea::init
#    ob_commidea::make_call
#    ob_commidea::do_request
#
# private:
#    ob_commidea::_msg_pack
#    ob_commidea::_msg_pack_trecord
#    ob_commidea::_load_data_trecord
#    ob_commidea::_msg_send
#    ob_commidea::_msg_unpack
#    ob_commidea::_msg_unpack_trecord
#    ob_commidea::_decode_cv2avs
#    ob_commidea::_construct_msg
#    ob_commidea::_load_host_details
#    ob_commidea::_mask_sensitive_info
#
# The paysettler also sources this file and makes use of the
# ob_commidea::do_request proc. The shared code for the apps calls
# ob_commidea::make_call

namespace eval ob_commidea {

	variable INITIALISED 0
	variable COMMIDEA_STATUS_RESPONSES
	variable COMMIDEA_DATA
	variable COMMIDEA_CFG
	variable COMMIDEA_CV2AVS_MAP
	variable COMMIDEA_AVS_MAP
	variable COMMIDEA_RESP
	variable COMMIDEA

}

proc ob_commidea::init {} {

	global SHARED_SQL

	variable INITIALISED
	variable COMMIDEA_STATUS_RESPONSES
	variable COMMIDEA_CV2AVS_MAP
	variable COMMIDEA_AVS_MAP
	variable COMMIDEA

	if {$INITIALISED} {
		return
	}

	package require tls
	package require tdom
	package require util_db

	_prep_qrys

	# Response Descriptions
	#        2 Referred
	#        5 Declined
	#        6 Authorised
	#       -1 Unspecified Error
	#       -2 Invalid transaction type
	#       -3 Invalid card number
	#       -4 Card scheme not recognised
	#       -5 Card scheme not accepted
	#       -6 Invalid card number
	#       -7 Invalid card number length
	#       -8 Invalid card number
	#       -9 Expired card
	#       -10 Card not yet valid
	#       -11 Invalid card service code
	#       -12 File missing/wrong format
	#       -13 File permanently locked
	#       -14 Out of memory
	#       -15 Account number does not exist
	#       -16 Value exceeds ceiling limit
	#       -18 Transaction ccy invalid
	#       -19 Lay-aways disallowed
	#       -20 Lay-away already stored
	#       -21 EFT system not configured
	#       -22 Internal error
	#       -23 Unknown comms device type
	#       -24 Configuration file invalid
	#       -25 No valid accounts
	#       -26 Invalid channel
	#       -27 System error
	#       -28 General transaction error
	#       -29 Transaction store unavailable
	#       -30 Unspecified error
	#       -31 Transaction cancelled
	#       -32 Library not open
	#       -33 Specified error (Look at error message for info)
	#       -34 Modifier field invalid/missing
	#       -35 Invalid card/track 1
	#       -36 Invalid card/track 3
	#       -37 Invalid/missing expiry date
	#       -38 Invalid/missing issue number
	#       -39 Invalid/missing start date
	#       -40 Purchase/refund value bad
	#       -41 Cash-back value bad
	#       -42 Auth code value bad
	#       -43 Cheque acct no. bad
	#       -44 Invalid cheque sort code
	#       -45 Invalid/missing cheque no.
	#       -46 Invalid/missing cheque type
	#       -47 Invalid EFT serial number
	#       -48 Unexpected CPC data
	#       -49 Transaction already resolved
	#       -50 Copy protection failure
	#       -51 Post confirm reversal disallowed
	#       -52 Bad transaction data
	#       -53 Transaction already void
	#       -54 Card on hot list
	#       -55 Invalid transaction
	#       -56 CV2 invalid
	#       -57 AVS invalid
	#       -100 File cancelled by user
	#       -102 User has no permissions
	array set COMMIDEA_STATUS_RESPONSES {
		2   PMT_REFER
		5   PMT_DECL
		6   OK
		-1  PMT_ERR
		-2  PMT_ERR_NOT_UNKNOWN
		-3  PMT_CARD
		-4  PMT_CARD_UNKNWN
		-5  PMT_CARD_UNKNWN
		-6  PMT_CARD
		-7  PMT_CLEN
		-8  PMT_CRNO
		-9  PMT_B2
		-10 PMT_B3
		-11 PMT_ERR
		-12 PMT_ERR
		-13 PMT_ERR
		-14 PMT_ERR
		-15 PMT_ERR
		-16 PMT_MAX
		-18 PMT_NOCCY
		-19 PMT_ERR
		-20 PMT_ERR
		-21 PMT_ERR
		-22 PMT_ERR
		-23 PMT_ERR
		-24 PMT_ERR
		-25 PMT_ERR
		-26 PMT_ERR
		-27 PMT_ERR
		-28 PMT_ERR
		-29 PMT_ERR
		-30 PMT_ERR
		-31 PMT_ERR
		-32 PMT_ERR
		-33 PMT_ERR
		-34 PMT_ERR
		-35 PMT_B1
		-36 PMT_B1
		-37 PMT_EXPR
		-38 PMT_ISSUE
		-39 PMT_STRT
		-40 PMT_AMNT
		-41 PMT_ERR
		-42 PMT_REF
		-43 PMT_ERR_INSERT_CHQ
		-44 PMT_ERR_INSERT_CHQ
		-45 PMT_ERR_INSERT_CHQ
		-46 PMT_ERR_INSERT_CHQ
		-47 PMT_ERR
		-48 PMT_ERR
		-49 PMT_ERR_ALREADY_ST
		-50 PMT_ERR
		-51 PMT_ERR
		-52 PMT_ERR_NOT_UNKNOWN
		-53 PMT_ERR_NOT_UNKNOWN
		-54 PMT_NO_PAYBACK_ACC
		-55 PMT_ERR_INVALID_STATUS
		-56 PMT_ERR
		-57 PMT_AVS
		-100 PMT_ERR
		-102 PMT_ERR
	}

	# Version 4 responses
	set COMMIDEA_STATUS_RESPONSES(ERROR)      PMT_ERR
	set COMMIDEA_STATUS_RESPONSES(REFERRAL)   PMT_REFER
	set COMMIDEA_STATUS_RESPONSES(COMMSDOWN)  PMT_ERR
	set COMMIDEA_STATUS_RESPONSES(DECLINED)   PMT_DECL
	set COMMIDEA_STATUS_RESPONSES(REJECTED)   PMT_ERR
	set COMMIDEA_STATUS_RESPONSES(CHARGED)    OK
	set COMMIDEA_STATUS_RESPONSES(AUTHORISED) OK
	set COMMIDEA_STATUS_RESPONSES(AUTHONLY)   OK


	# Commidea responses need to be mapped onto the standard
	# Datacash CV2AVS responses as this is what shared payments
	# code uses. We transform Commideas responses into:
	# 0 - failed match
	# 1 - matched
	# 2 - not checked
	#
	# this array maps the responses for "cv2,avs"
	# onto one of the datacash responses:
	# * DATA NOT CHECKED
	# * ALL MATCH
	# * SECURITY CODE MATCH ONLY
	# * ADDRESS MATCH ONLY
	# * NO DATA MATCHES
	#
	#
	# A few exceptions we have to make are to do with failed
	# CV2 responses. CV2 will always take priority over AVS.
	# For instance in the case of a failed CV2 response and
	# address not checked we use "NO DATA MATCHES" rather than
	# "DATA NOT CHECKED" as we never want to hide a failed/matched
	# CV2 response.
	#
	# Array key is set as "cv2,avs"
	array set COMMIDEA_CV2AVS_MAP {
		0,0 "NO DATA MATCHES"
		0,1 "ADDRESS MATCH ONLY"
		0,2 "NO DATA MATCHES"
		1,0 "SECURITY CODE MATCH ONLY"
		1,1 "ALL MATCH"
		1,2 "SECURITY CODE MATCH ONLY"
		2,0 "DATA NOT CHECKED"
		2,1 "DATA NOT CHECKED"
		2,2 "DATA NOT CHECKED"
	}

	# Address and Postcode each return their own response. We use
	# this map to combine them into one avs_status. This uses the
	# same statuses as the previous map:
	# 0 - failed match
	# 1 - matched
	# 2 - not checked
	#
	#
	# We use this order of determining status:
	# - Either one not checked then avs_status = 2
	# - Either one failed then avs_status = 0
	# - Else avs_status = 1
	#
	#
	# Array key is set as "address,postcode"
	array set COMMIDEA_AVS_MAP {
		0,0 0
		0,1 0
		0,2 2
		1,0 0
		1,1 1
		1,2 2
		2,0 2
		2,1 2
		2,2 2
	}

	set COMMIDEA(DOC_HEADER)         "<?xml version=\"1.0\"?>"
	set COMMIDEA(DOC_TITLE,UKASH)    "ukashrequest"
	set COMMIDEA(DOC_TITLE,TXN)      "transactionrequest"
	set COMMIDEA(DOC_TITLE,CNF)      "confirmationrequest"
	set COMMIDEA(DOC_TITLE,RJT)      "rejectionrequest"
	set COMMIDEA(DOC_TITLE,ENR)      "payerauthenrollmentcheckrequest"
	set COMMIDEA(DOC_TITLE,PAY_AUTH) "payerauthauthenticationcheckrequest"

	# Message Types
	set COMMIDEA(MSG_TYPE,UKASH)    "UKASH"
	set COMMIDEA(MSG_TYPE,TXN)      "TXN"
	set COMMIDEA(MSG_TYPE,CNF)      "CNF"
	set COMMIDEA(MSG_TYPE,RJT)      "RJT"
	set COMMIDEA(MSG_TYPE,ENR)      "PAI"
	set COMMIDEA(MSG_TYPE,PAY_AUTH) "PAI"

	# Namespaces
	set COMMIDEA(NS,UKASH)          "UKASH"
	set COMMIDEA(NS,TXN)            "TXN"
	set COMMIDEA(NS,CNF)            "TXN"
	set COMMIDEA(NS,RJT)            "TXN"
	set COMMIDEA(NS,ENR)            "PAYERAUTH"
	set COMMIDEA(NS,PAY_AUTH)       "PAYERAUTH"

	#Response Nodes
	set COMMIDEA(RESP,UKASH)        "ukashresponse"
	set COMMIDEA(RESP,TXN)          "transactionresponse"
	set COMMIDEA(RESP,CNF)          "transactionresponse"
	set COMMIDEA(RESP,RJT)          "transactionresponse"
	set COMMIDEA(RESP,ENR)          "payerauthenrollmentcheckresponse"
	set COMMIDEA(RESP,PAY_AUTH)     "payerauthauthenticationcheckresponse"

	set COMMIDEA(XMLNS.XSI)\
		[OT_CfgGet COMMIDEA.NS.XSI  "http://www.w3.org/2001/XMLSchema-instance"]
	set COMMIDEA(XMLNS.XSD)\
		[OT_CfgGet COMMIDEA.NS.XSD  "http://www.w3.org/2001/XMLSchema"]
	set COMMIDEA(XMLNS.SOAP)\
		[OT_CfgGet COMMIDEA.NS.SOAP "http://schemas.xmlsoap.org/soap/envelope/"]
	set COMMIDEA(XMLNS)\
		[OT_CfgGet COMMIDEA.NS      "https://www.commidea.webservices.com"]



	# HEADER:  Header wraps all requests in version 4
	set COMMIDEA(HEADER,fields) {
		SystemID                   M AccountID
		SystemGUID                 M GUID
		Passcode                   M Passcode
		ProcessingDB               O ProcessingDB
		SendAttempt                M SendAttempt
	}

	# TXN: Card Transaction request
	set COMMIDEA(TXN,fields) {
		{merchantreference          O VAL  MerchantData}
		{accountid                  M VAL  AccountNumber}
		{txntype                    M VAL  TxnType}
		{transactioncurrencycode    M VAL  NumericCcy}
		{apacsterminalcapabilities  M VAL  TermCaps}
		{capturemethod              M VAL  CaptureMethod}
		{processingidentifier       M VAL  ProcessingIdentifier}
		{tokenid                    O VAL  TokenId}
		{pan                        M VAL  Pan}
		{track2                     M VAL  Track2}
		{csc                        O VAL  CSC}
		{avshouse                   O VAL  AVSHouse}
		{avspostcode                O VAL  AVSPostCode}
		{expirydate                 M VAL  ExpiryDate}
		{issuenumber                O VAL  Issue}
		{startdate                  O VAL  StartDate}
		{txnvalue                   M VAL  TxnValue}
		{authcode                   O VAL  AuthCode}
		{transactiondatetime        M VAL  DateTime}
		{payerauthauxiliarydata     O NODE AUX_DATA}
	}

	set COMMIDEA(TXN,resp_fields) {
		merchantreference            MerchantReference
		transactionid                TransactionID
		resultdatetimestring         ResultDateTime
		processingdb                 ProcessingDB
		errormsg                     ErrorMsg
		merchantnumber               MerchantNumber
		tid                          Tid
		schemename                   SchemeName
		messagenumber                MessageNumber
		authcode                     AuthCode
		authmessage                  AuthResult
		vrtel                        VRTel
		txnresult                    TransactionResult
		pcavsresult                  PcAvsResult
		ad1avsresult                 Ad1AvsResult
		cvcresult                    CvcResult
		arc                          Arc
		authorisingentity            AuthorisingEntity
	}

	# AUX_DATA: Passes result of 3D Secure check
	set COMMIDEA(AUX_DATA,fields) {
		{authenticationstatus       M VAL AuthStatus}
		{authenticationcavv         M VAL AuthCavv}
		{authenticationeci          M VAL AuthEci}
		{atsdata                    M VAL AtsData}
		{transactionid              M VAL AuthRequestId}
	}

	# CNF: Confirm Card Payments
	set COMMIDEA(CNF,fields) {
		{merchantreference          O VAL MerchantData}
		{transactionid              M VAL TransactionID}
		{authcode                   M VAL AuthCode}
	}

	set COMMIDEA(CNF,resp_fields) $COMMIDEA(TXN,resp_fields)

	# ENR: Card Enrollment Check
	set COMMIDEA(ENR,fields) {
		{merchantreference          M VAL MerchantData}
		{mkaccountid                M VAL AccountNumber}
		{mkacquirerid               M VAL MkAcquirerId}
		{merchantname               M VAL MerchantName}
		{merchantcountrycode        M VAL MerchantCountryCode}
		{merchanturl                M VAL MerchantURL}
		{visamerchantbankid         M VAL VisaMerchantBankId}
		{visamerchantnumber         M VAL VisaMerchantNumber}
		{visamerchantpassword       M VAL VisaMerchantPassword}
		{mcmmerchantbankid          M VAL McmMerchantBankId}
		{mcmmerchantnumber          M VAL McmMerchantNumber}
		{mcmmerchantpassword        M VAL McmMerchantPassword}
		{cardnumber                 M VAL Pan}
		{cardexpmonth               M VAL CardExpMonth}
		{cardexpyear                M VAL CardExpYear}
		{currencycode               M VAL NumericCcy}
		{currencyexponent           M VAL CcyExponent}
		{browseracceptheader        M VAL BrowserAcceptHeader}
		{browseruseragentheader     M VAL BrowserUserAgentHeader}
		{transactionamount          M VAL TxnValuePence}
		{transactiondisplayamount   M VAL TxnValue}
		{transactiondescription     M VAL TxnDesc}
	}

	set COMMIDEA(ENR,resp_fields) {
		merchantreference            MerchantReference
		processingdb                 ProcessingDB
		payerauthrequestid           AuthRequestId
		enrolled                     Enrolled
		acsurl                       ACSUrl
		pareq                        PaReq
		proofxml                     ProofXml
	}

	#PAY_AUTH: 3DS Authorisation request
	set COMMIDEA(PAY_AUTH,fields) {
		{merchantreference          M VAL MerchantData}
		{payerauthrequestid         M VAL AuthRequestId}
		{pares                      M VAL PaRes}
		{enrolled                   M VAL Enrolled}
	}

	set COMMIDEA(PAY_AUTH,resp_fields) {
		merchantreference            MerchantData
		processingdb                 ProcessingDB
		payerauthrequestid           AuthRequestId
		authenticationstatus         AuthStatus
		authenticationcertificate    AuthCert
		authenticationcavv           AuthCavv
		authenticationeci            AuthEci
		authenticationtime           AuthTime
		atsdata                      AtsData
	}

	# REJECT: Cancel Card Payments
	set COMMIDEA(RJT,fields) {
		{merchantreference          O VAL MerchantData}
		{transactionid              M VAL TransactionID}
		{authcode                   M VAL AuthCode}
		{capturemethod              M VAL CaptureMethod}
		{pan                        M VAL Pan}
		{track2                     M VAL Track2}
		{expirydate                 M VAL ExpiryDate}
	}

	set COMMIDEA(RJT,resp_fields) $COMMIDEA(TXN,resp_fields)


	# UKASH: Voucher payments
	set COMMIDEA(UKASH,fields) {
		{merchantreference          O VAL MerchantData}
		{requesttype                M VAL UKASHReqType}
		{ukashlogin                 M VAL UKASHLogin}
		{ukashpassword              M VAL UKASHPassword}
		{transactionid              O VAL MerchantData}
		{brandid                    M VAL UKASHBrandId}
		{vouchernumber              O VAL UKASHVoucherNumber}
		{vouchervalue               O VAL UKASHVoucherValue}
		{ukashpin                   O VAL UKASHPin}
		{basecurr                   M VAL UKASHBaseCurr}
		{ticketvalue                O VAL UKASHTicketValue}
		{redemptiontype             M VAL UKASHRedemptionType}
		{merchdatetime              O VAL MerchDateTime}
		{merchcustomvalue           O VAL MerchCustomValue}
		{storelocationid            O VAL StoreLocId}
		{vouchercurrproductcode     O VAL UKASHProductCode}
		{amountreference            O VAL UKASHAmountRef}
	}

	set COMMIDEA(UKASH,resp_fields) {
		AmountReference              amountReference
		mkTransactionId              mkTransactionId
		MerchantReference            merchantReference
		txCode                       txCode
		txDescription                txDescription
		transactionId                transactionId
		settleAmount                 settleAmount
		accountBalance               accountBalance
		accountCurrency              accountCcy
		changeIssueVoucherNumber     changeIssueVoucherNumber
		changeIssueVoucherCurr       changeIssueVoucherCurr
		changeIssueAmount            changeIssueAmount
		changeIssueExpiryDate        changeIssueExpiryDate
		IssuedVoucherNumber          issuedVoucherNumber
		IssuedVoucherCurr            issuedVoucherCurr
		IssuedAmount                 issuedAmount
		IssuedExpiryDate             issuedExpiryDate
		ukashTransactionId           ukashTransactionId
		currencyConversion           currencyConversion
		errCode                      errCode
		errDescription               errDescription
	}

	# Get the iso codes for currencies
	if {[catch {ob_db::exec_qry ob_commidea::get_ccy_iso_codes} rs]} {
		set err "ob_commidea::init: failed to get ccy iso codes- $rs"
		ob_log::write ERROR {$err}
		error $err
	}

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		set COMMIDEA(CCY,[db_get_col $rs $r ccy_code])\
			[db_get_col $rs $r num_iso_code]
	}

	ob_db::rs_close $rs

	set INITIALISED 1
}

proc ob_commidea::_prep_qrys {} {

	# query to retrieve host details, needed for confirming
	# transactions as these are sent to a different url
	ob_db::store_qry ob_commidea::commidea_get_host {
		select
			pg_ip,
			conn_timeout,
			resp_timeout
		from
			tPmtGateHost
		where
			pg_type = ? and
			status  = "A" and
			default = "Y"
	}

	# Get the numeric currency code
	ob_db::store_qry ob_commidea::get_ccy_iso_codes {
		select
			ccy_code,
			num_iso_code
		from
			tCcy
	}

	# Get the 3D Secure login details
	ob_db::store_qry ob_commidea::get_card_auth {
		select
			a.acquirer,
			a.merchant_name,
			a.merchant_country,
			a.merchant_url,
			a.visa_bank_id,
			a.enc_visa_login,
			a.enc_visa_password,
			a.mcm_bank_id,
			a.enc_mcm_login,
			a.enc_mcm_password
		from
			tGatewayCardAuth g,
			tCardAuth a
		where
			g.pg_acct_id = ? and
			g.card_auth_id = a.card_auth_id
	} 20
}

proc ob_commidea::make_call {ARRAY} {

	variable INITIALISED
	variable COMMIDEA_STATUS_RESPONSES
	variable COMMIDEA
	variable COMMIDEA_CFG
	variable COMMIDEA_RESP

	if {!$INITIALISED} {
		init
	}

	upvar $ARRAY PMT

	# Host details
	set COMMIDEA_CFG(host)         $PMT(host)
	set COMMIDEA_CFG(conn_timeout) $PMT(conn_timeout)
	set COMMIDEA_CFG(resp_timeout) $PMT(resp_timeout)

	if {![info exists PMT(pay_mthd)] || $PMT(pay_mthd) eq ""} {
		set PMT(pay_mthd) "CC"
	}

	if {![info exists PMT(pay_sort)] || $PMT(pay_sort) eq ""} {
		set PMT(pay_sort) "-"
	}

	if {![info exists PMT(req_type)]} {
		set PMT(req_type) ""
	}

	switch -exact -- "$PMT(req_type)$PMT(pay_mthd)$PMT(pay_sort)" {
		"PAY_AUTHCCD" -
		"PAY_AUTHCCW" {
			# Authenticate 3D Secure details
			set msg_type "PAY_AUTH"
			set res_handle "parse_PAY_AUTH_resp"
		}
		"ENRCCD" -
		"ENRCCW" {
			# Check 3D Secure Enrollment
			set msg_type "ENR"
			set res_handle "parse_ENR_resp"
		}
		"CCD"   -
		"CCW"   {
			set msg_type "TXN"
			set res_handle "parse_CC_resp"
		}
		"CCY"   {
			set msg_type "CNF"
			set res_handle "parse_CC_resp"
		}
		"CCX"   {
			set msg_type "RJT"
			set res_handle "parse_CC_resp"
		}
		"UKSH-" {
			set msg_type "UKASH"
			set PMT(UKASHReqType) "ukashgetsettleamount"
			set res_handle "parse_UKash_resp"
		}
		"UKSHD" {
			set msg_type "UKASH"
			set PMT(UKASHReqType) "ukashfullvaluevoucher"
			set res_handle "parse_UKash_resp"
		}
		"UKSHW" {
			set msg_type "UKASH"
			set PMT(UKASHVoucherNumber) $PMT(sub_key)
			set PMT(UKASHReqType) "ukashissuevoucher"
			set res_handle "parse_UKash_resp"
		}
		default {
			ob_log::write ERROR {ob_commidea::make_call : Unrecognised payment sort - $PMT(pay_sort) type: $PMT(pay_type)}
			return [list 0 PMT_TYPE]
		}
	}

	# construct the request and send it off to Commidea
	foreach {ok reason} [do_request $msg_type PMT] {break}

	if {!$ok} {
		ob_log::write ERROR {ob_commidea::make_call : do_request fail: $reason}

		#
		# Commidea withdrawals in this case can be handled generally via
		# failing the payment. This is as we'll never send a confirm so it'll
		# never be marked as good.
		#

		if {$reason == "PMT_NO_SOCKET"} {
			if {[lsearch [OT_CfgGet COMMIDEA_PAY_SORTS_BAD_ON_ERROR_CONN {D W}] $PMT(pay_sort)] > -1} {
				return PMT_NO_SOCKET
			} else {
				return PMT_RESP
			}
		}

		if {[lsearch [OT_CfgGet COMMIDEA_PAY_SORTS_BAD_ON_ERROR_RESP {W}] $PMT(pay_sort)] > -1} {
			return PMT_TIMEOUT_ABANDON
		}

		return $reason
	}

	return [$res_handle PMT]
}

proc ob_commidea::parse_CC_resp {ARRAY} {

	variable COMMIDEA_STATUS_RESPONSES
	variable COMMIDEA
	variable COMMIDEA_CFG
	variable COMMIDEA_RESP

	upvar $ARRAY PMT

	# now take info from COMMIDEA_RESP array and store in PMT array in
	# format used by shared payments code

	# set the cv2avs_status in line with Datacash as shared payments code
	# relies on it to be in this format
	set PMT(cv2avs_status) [_decode_cv2avs \
			$COMMIDEA_RESP(CvcResult)\
			$COMMIDEA_RESP(Ad1AvsResult)\
			$COMMIDEA_RESP(PcAvsResult)]

	set status $COMMIDEA_RESP(TransactionResult)

	switch -exact -- $status {
		"ERROR"      {set PMT(gw_ret_code) 0}
		"REFERRAL"   {set PMT(gw_ret_code) 1}
		"COMMSDOWN"  {set PMT(gw_ret_code) 2}
		"DECLINED"   {set PMT(gw_ret_code) 3}
		"REJECTED"   {set PMT(gw_ret_code) 4}
		"CHARGED"    {set PMT(gw_ret_code) 5}
		"AUTHORISED" {set PMT(gw_ret_code) 6}
		"AUTHONLY"   {set PMT(gw_ret_code) 7}
		default      {set PMT(gw_ret_code) 8}
	}

	set PMT(auth_code) $COMMIDEA_RESP(AuthCode)
	set PMT(gw_uid)    $COMMIDEA_RESP(gw_uid)

	set PMT(gw_ret_msg) [join [list \
		$COMMIDEA_RESP(AuthResult) \
		$COMMIDEA_RESP(AuthCode) \
		$COMMIDEA_RESP(ResultDateTime) \
		$COMMIDEA_RESP(MerchantNumber) \
		$COMMIDEA_RESP(SchemeName)] ":"]

	# If pay_sort is X then we are cancelling a transaction and the shared
	# payments code expects a declined response for a successful cancellation.
	# As Commidea's transaction response to the confirmation will contain
	# the AuthResult for the original transaction, we ignore this and check
	# if the TransactionResult is now 'Rejected'
	if {$PMT(pay_sort) == "X"} {
		if {[string toupper $COMMIDEA_RESP(TransactionResult)] == "REJECTED"} {
			# Cancellation request was successful so send declined
			# error code back
			return PMT_DECL
		} else {
			# Failed to cancel transaction, extra info will be updated in shared
			# code to alert administrator
			ob_log::write ERROR {ob_commidea::make_call : Failed to cancel transaction after failed cv2avs check}
			return PMT_ERR
		}
	} else {

		if {[info exists COMMIDEA_STATUS_RESPONSES($status)]} {

			return $COMMIDEA_STATUS_RESPONSES($status)
		} else {

			ob_log::write ERROR {ob_commidea::make_call : Unrecognised Auth Result in Commidea response: $status)}
			return PMT_ERR
		}
	}
}

proc ob_commidea::parse_ENR_resp {ARRAY} {

	variable COMMIDEA_RESP
	variable COMMIDEA

	upvar $ARRAY PMT

	set PMT(3d_secure,pareq)   $COMMIDEA_RESP(PaReq)
	set PMT(3d_secure,acs_url) $COMMIDEA_RESP(ACSUrl)
	set PMT(3d_secure,ref)\
		"$COMMIDEA_RESP(ProcessingDB):$COMMIDEA_RESP(AuthRequestId)"

	#TODO
	set PMT(3d_secure,scheme)  "VBV"

	set enrolled $COMMIDEA_RESP(Enrolled)

	# retreive the commidea response code for the enrolment check
	set PMT(enrol_3d_resp) $enrolled

	# JP: Just testing: shoot me if I leave this in.
	#set enrolled N

	switch -- $enrolled {
		"Y" {
			# Issuer is in the scheme and is enrolled
			# Need to do the redirect
			return PMT_3DS_OK_REDIRECT
		}
		"N" {
			# Issuer is in the scheme but the
			# card holder is not enrolled
			return PMT_3DS_OK_DIRECT_AUTH
		}
		"U" {
			# If participating issuer, this means that the there was a problem
			# getting the the details.  May also be a non-participating issuer
			return PMT_3DS_NO_SUPPORT
		}
		default {
			# Problem with the request.
			# We won't have liab protection so will have to make a
			# business decission as to whether to continue with
			# the payment
			ob_log::write INFO {ob_commidea::parse_ENR_resp: error checking enrollment: enr = $enrolled}
			return PMT_3DS_NO_SUPPORT
		}
	}
}

proc ob_commidea::parse_PAY_AUTH_resp {ARRAY} {

	variable COMMIDEA_RESP
	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	set PMT(payer_auth,req_id)   $COMMIDEA_RESP(AuthRequestId)
	set PMT(payer_auth,status)   $COMMIDEA_RESP(AuthStatus)
	set PMT(payer_auth,cert)     $COMMIDEA_RESP(AuthCert)
	set PMT(payer_auth,cavv)     $COMMIDEA_RESP(AuthCavv)
	set PMT(payer_auth,eci)      $COMMIDEA_RESP(AuthEci)
	set PMT(payer_auth,time)     $COMMIDEA_RESP(AuthTime)
	set PMT(payer_auth,ats_data) $COMMIDEA_RESP(AtsData)

	# retreive the commidea response code for the enrolment check
	set PMT(auth_3d_resp) $PMT(payer_auth,status)

	if {$COMMIDEA_DATA(Enrolled) eq "N"} {
		# Authenticate resp. doesn't matter
		return "OK"
	}

	# Customer is enrolled

	# JP: Just testing 3DS Failure: shoot me if I leave this in.
	# set PMT(payer_auth,status) N

	switch -- $PMT(payer_auth,status) {
		"Y" {
			# Details authenticated
			return "OK"
		}
		"A" {
			# Cardholder enrollment authenticated
			# Subtly different to 'Y' but as far as I can
			# see we treat it the same.
			return "OK"
		}
		"N" {
			# Cardholder unable to provide correct password
			return "PMT_3DS_VERIFY_FAIL"
		}
		"U" {
			# Problem during 3D Secure authentication, we continue anyway
			ob_log::write INFO {Unable to verify 3DS details: $PMT(payer_auth,status), continuing anyway}
			return "OK"
		}
		default {
			# Bad response
			ob_log::write ERROR {Unable to verify 3DS details: status U}
			return "PMT_3DS_AUTH_ERROR"
		}
	}
}

proc ob_commidea::parse_UKash_resp {ARRAY} {

	variable COMMIDEA_RESP
	variable COMMIDEA

	upvar $ARRAY PMT

	foreach {ign field} $COMMIDEA(UKASH,resp_fields) {
		set PMT($field) $COMMIDEA_RESP($field)
	}

	return "OK"
}

#
# Loads information from the PMT array into COMMIDEA_DATA.
# The keys used in the COMMIDEA_DATA array relate directly
# to the names of the elements used in the XML request.
# Simple validation is performed on some of the data.
#
proc ob_commidea::_load_data_TXN {ARRAY} {

	variable COMMIDEA_DATA
	variable COMMIDEA

	upvar $ARRAY PMT

	# Mandatory static fields - informed by Matt Sharp @ Commidea
	# that there is no need to send different term caps for phone and ECOM
	# transactions.
	set COMMIDEA_DATA(TermCaps) [OT_CfgGet COMMIDEA_TERM_CAPS "4298"]
	set COMMIDEA_DATA(DateTime) ""

	# Auth and Charge at the same time
	set COMMIDEA_DATA(ProcessingIdentifier) 1

	# Unique reference
	set COMMIDEA_DATA(MerchantData) $PMT(apacs_ref)

	# Is this a redirect from a 3D Secure Request?
	if {[info exists PMT(3d_secure,pmt_id)]} {
		set 3ds 1
		set cvv2 $PMT(3d_secure,cvv2)
	} else {
		set 3ds 0
		set cvv2 $PMT(cvv2)
	}

	# Currency
	if {![info exists COMMIDEA(CCY,$PMT(ccy_code))]} {
		ob_log::write ERROR\
			{ob_commidea::_load_data_TXN : Unrecognised ccy $PMT(ccy_code)}
		return [list 0 PMT_CCY]
	}
	set COMMIDEA_DATA(NumericCcy) $COMMIDEA(CCY,$PMT(ccy_code))

	# TxnType needs to be set to:
	#    01 - deposit
	#    02 - withdrawal
	#
	switch $PMT(pay_sort) {
		"D" {
			set COMMIDEA_DATA(TxnType)   "01"

			# Commidea recommend that referred payments are sent as offline
			# settled payments
			if {[info exists PMT(is_referral)] && $PMT(is_referral) == 1} {
				#JP: TODO - check
				set COMMIDEA_DATA(Offline)   "Y"
				set COMMIDEA_DATA(Online)    "N"
				set COMMIDEA_DATA(AuthCode)  $PMT(gw_auth_code)
			} else {
				set COMMIDEA_DATA(Offline)   "N"
				set COMMIDEA_DATA(Online)    "Y"
			}
		}
		"W" {
			set COMMIDEA_DATA(TxnType)   "02"

			# Commidea recommend that referred payments are sent as offline
			# settled payments
			if {[info exists PMT(is_referral)] && $PMT(is_referral) == 1} {
				set COMMIDEA_DATA(Offline)   "Y"
				set COMMIDEA_DATA(Online)    "N"
				set COMMIDEA_DATA(AuthCode)  $PMT(gw_auth_code)
			} else {
				set COMMIDEA_DATA(Offline)   "N"
				set COMMIDEA_DATA(Online)    "Y"
			}
		
			# Set the withdrawal up to be automatically auth'd
			if {[OT_CfgGet COMMIDEA_OFFLINE_WTD 0]} {
				set COMMIDEA_DATA(ProcessingIdentifier) 6
				set COMMIDEA_DATA(Offline)    "Y"
				set COMMIDEA_DATA(Online)     "N"
			}
		}
		"S" {
			set COMMIDEA_DATA(TxnType)   "01"
			set COMMIDEA_DATA(Offline)   "Y"
			set COMMIDEA_DATA(Online)    "N"
			set COMMIDEA_DATA(AuthCode)  $PMT(auth_code)
		}
		default {
			ob_log::write ERROR {ob_commidea::_load_data_trecord : Unrecognised payment sort - $PMT(pay_sort)}
			return [list 0 PMT_TYPE]
		}
	}

	foreach {ok err} [_parse_source $PMT(source) $PMT(pay_sort)] {break}
	if {!$ok} {return [list 0 $err]}

	# Special Case for Laser Cards
	# Advised by Commidea that all laser cards need to be sent through
	# as customer present transactions.

	if {[info exists PMT(pg_method)] && $PMT(pg_method) ne ""} {
		set COMMIDEA_DATA(CaptureMethod) $PMT(pg_method)
	}

	foreach {ok err} [_parse_card\
		$PMT(card_no) $PMT(issue_no) $PMT(start) $PMT(expiry)] {break}
	if {!$ok} {return [list 0 $err]}

	# Remove any whitespace
	set COMMIDEA_DATA(CSC)               [string map {" " ""} $cvv2]
	set COMMIDEA_DATA(TxnValue)          [string map {" " ""} $PMT(amount)]

	# Check CSC is between 3 and 4 digits. If it's null then we can assume it
	# wasn't required as the check will have been performed in the calling app
	if {$COMMIDEA_DATA(CSC) != "" && ![regexp {^[0-9]{3,4}$} $COMMIDEA_DATA(CSC)]} {
		ob_log::write ERROR {ob_commidea::_load_data_TXN : CSC failed regexp}
		return [list 0 PMT_ERR]
	}

	# Check amount resembles a valid decimal number (format %0.2f already
	# performed earlier)
	if {![regexp {^(0|[1-9][0-9]*|[0-9]+\.[0-9]{0,2}|\.[0-9]{1,2})$} $COMMIDEA_DATA(TxnValue)]} {
		ob_log::write ERROR {ob_commidea::_load_data_TXN : Transaction amount failed check - $COMMIDEA_DATA(TxnValue)}
		return [list 0 PMT_AMNT]
	}

	# AVS

	if {!$3ds} {
		# Set AVS info. This needs to be in the format:
		#     <House number or name>;<Postcode>;<Country Code>
		#
		# The limit on this field is 40 chars. The house name should
		# be truncated to ensure the field's value is within the limit
		#
		# We're not to supply the country code currently
		#set avs_end ";$PMT(postcode);$PMT(cntry_code)"
		set avs_end ";$PMT(postcode);"
		set first_line $PMT(addr_1)
		# We'll try to extract the house number from the first line of the
		# address. If we can't, then we'll use the first line itself thinking
		# that its the house name. The regexp will match the following:
		# "13 Kings Road" -> 13
		# "Flat 13" -> 13
		# "123-124 Kings Road" -> 123-124
		# "Flat 13, Some House" -> 13
		# "13a Kings Road" -> 13a
		# "13, Kings Road" -> 13
		if {[regexp {^.*?([0-9]+[\-a-zA-Z0-9]*).*$} $PMT(addr_1) match num]} {
			set first_line $num
		}
		# strip any commas
		set first_line [string map {"," ""} $first_line]
		set addr1 [string range $first_line 0 [expr {39 - [string length $avs_end]}]]
		set COMMIDEA_DATA(AVS) "${addr1}$avs_end"
	}

	# Have we made the autentication request?
	if {[info exists PMT(payer_auth,status)]} {

		set COMMIDEA_DATA(AUX_DATA)   1
		set COMMIDEA_DATA(AuthRequestId) $PMT(payer_auth,req_id)
		set COMMIDEA_DATA(AuthStatus)    $PMT(payer_auth,status)
		set COMMIDEA_DATA(AuthCavv)      $PMT(payer_auth,cavv)
		set COMMIDEA_DATA(AuthEci)       $PMT(payer_auth,eci)
		set COMMIDEA_DATA(AtsData)       $PMT(payer_auth,ats_data)
	}

	return [list 1 OK]
}

proc ob_commidea::_msg_send {request} {

	variable COMMIDEA_CFG
	variable COMMIDEA_RESP
	variable COMMIDEA

	#! UTF-8 encoding - the nuclear option
	#
	# Strips any non-ASCII characters - this is unfortunately the only option
	# available to us as we cannot work out what character encoding the data is
	# in (eg, if the request is from the portal, it may be in the user's language
	# encoding - but if it came from OXi XML, it may already be in UTF-8)
	if {[regexp {[^\n\040-\176]} $request]} {
		set count [regsub -all {[^\n\040-\176]} $request {} request]
		ob_log::write WARN \
			"ob_commidea::_msg_send : Warning: stripped $count non-ASCII character(s) from request"
	}

	ob_log::write INFO "ob_commidea::_msg_send : Sending request to \
		$COMMIDEA_CFG(host), conn_timeout is $COMMIDEA_CFG(conn_timeout), \
		resp_timeout is $COMMIDEA_CFG(resp_timeout)"

	foreach {success ret} [ob_commidea::_send_req $COMMIDEA_CFG(host) $request $COMMIDEA_CFG(conn_timeout) $COMMIDEA_CFG(resp_timeout)] {}
		if {$success != "OK"} {
			ob_log::write INFO {ob_commidea::_msg_send : Bad Connection : $success $ret}
			ob_log::write INFO {ob_commidea::_msg_send : Server : $COMMIDEA_CFG(host)}

			#
			# We need to keep track of the case of timeouts. We may use it in
			# displaying errors.

			if {$success == "PMT_NO_SOCKET"} {
				set COMMIDEA_RESP(TransactionStatus) "TIMED_OUT"
				return [list 0 PMT_NO_SOCKET]
			} elseif {$success == "PMT_REQ_TIMEOUT"} {
				set COMMIDEA_RESP(TransactionStatus) "TIMED_OUT"
			}

			return [list 0 PMT_RESP]
	}

	return [list 1 $ret]

}

#
# We get a 3-part response from Commidea relating to cv2avs checking.
# A seperate result is sent for cv2, address and postcode. Other shared
# code relies on the cv2avs status to be in Datacash format so we will
# continue to use that structure and return one of the following status
# messages:
#    * DATA NOT CHECKED
#    * ALL MATCH
#    * SECURITY CODE MATCH ONLY
#    * ADDRESS MATCH ONLY
#    * NO DATA MATCHES
#
#
# The Commidea response received is as follows:
#
# Address and Postcode
#    0 - Matched
#    1 - Not checked
#    2 - Partial match
#    3 - Not supported by acquirer
#    4 - Not matched
#    5 - AVS feature not enabled on server
#
# CV2
#    0 - Not Provided
#    1 - Not checked
#    2 - Matched
#    3 - Not supported by acquirer
#    4 - Not matched
#    5 - CV2 feature not enabled on server
#
#
# Address and postcode will be treated as one item
proc ob_commidea::_decode_cv2avs {cv2 address postcode} {

	variable COMMIDEA_AVS_MAP
	variable COMMIDEA_CV2AVS_MAP

	# first we'll decode the possible Commidea responses
	# into one of the following:
	# 0 - not matched
	# 1 - matched
	# 2 - not checked
	foreach item {cv2 address postcode} {
		switch -exact -- [subst $$item] {
			"0" {
				set ${item}_status 2
			}
			"1" {
				set ${item}_status 2
			}
			"2" {
				set ${item}_status 1
			}
			"4" {
				set ${item}_status 0
			}
			default {
				set ${item}_status 2
			}
		}
	}

	# Now combine the address and postcode statuses to give us
	# an avs_status
	set avs_status $COMMIDEA_AVS_MAP($address_status,$postcode_status)

	# Now use the cv2_status and avs_status to map onto a Datacash
	# response
	return $COMMIDEA_CV2AVS_MAP($cv2_status,$avs_status)
}

#
# Verifies data and loads into COMMIDEA_DATA using the keys that
# are going to be used as the element names in the xml request.
# Then constructs the xml message based on this data. The payment
# sort determines the message to be sent:
#    D - deposit, send a transaction record
#    W - withdrawal, send a transaction record
#    Y - confirmation, send a confirmation record to
#        confirm the transaction (for confirming transactions
#        which are not just authorisations)
#    X - cancellation, send a confirmation record to
#        cancel the transaction (normally when rejecting
#        a transaction based on CV2AVS checking)
#    S - settle, this is used by the pay settler to send
#        an 'offline' transaction to settle the deposit
proc ob_commidea::_construct_msg {msg_type ARRAY} {

	upvar $ARRAY PMT

	variable COMMIDEA_DATA
	array set COMMIDEA_DATA [array unset COMMIDEA_DATA]

	# Generic request data:

	# enc_mid field in tPmtGateAcct stores merchant number and
	# account number with a pipe seperator
	set COMMIDEA_DATA(GUID)              [lindex [split $PMT(mid) "|"] 0]
	set COMMIDEA_DATA(AccountNumber)     [lindex [split $PMT(mid) "|"] 1]
	set COMMIDEA_DATA(AccountID)         $PMT(client)
	set COMMIDEA_DATA(Passcode)          $PMT(password)
	set COMMIDEA_DATA(SendAttempt)       0

	set COMMIDEA_DATA(Track2)            ""

	switch -- $msg_type {
		"TXN" {
			foreach {ok reason} [_load_data_TXN PMT] {break}
		}
		"CNF" {
			foreach {ok reason} [_load_data_CNF PMT] {break}
		}
		"RJT" {
			foreach {ok reason} [_load_data_RJT PMT] {break}
		}
		"ENR" {
			foreach {ok reason} [_load_data_ENR PMT] {break}
		}
		"PAY_AUTH" {
			foreach {ok reason} [_load_data_PAY_AUTH PMT] {break}
		}
		"UKASH" {
			foreach {ok reason} [_load_data_UKASH PMT] {break}
		}
		default {
			ob_log::write ERROR {ob_commidea::_construct_msg : Unrecognised payment sort - $msg_type}
			return [list 0 PMT_TYPE]
		}
	}

	if {!$ok} {
		ob_log::write ERROR {ob_commidea::_construct_msg : load failed: $reason}
		return [list 0 $reason]
	}

	foreach {ok xml} [_msg_pack $msg_type] {break}

	if {$ok ne "OK"} {
		ob_log::write ERROR {ob_commidea::_construct_msg : xml build failed}
		return [list 0 ERROR]
	}

	return [list 1 $xml]
}

proc ob_commidea::_load_data_CNF {ARRAY} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	_parse_gw_uid $PMT(gw_uid)

	set COMMIDEA_DATA(MerchantData)      $PMT(apacs_ref)

	set COMMIDEA_DATA(AuthCode) $PMT(auth_code)
	# 1 - Confirm transaction
	set COMMIDEA_DATA(Command)  1

	return [list 1 OK]
}

proc ob_commidea::_load_data_RJT {ARRAY} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	set COMMIDEA_DATA(MerchantData)      $PMT(apacs_ref)

	foreach {ok err} [_parse_gw_uid $PMT(gw_uid)] {break}
	if {!$ok} {return [list 0 $err]}

	foreach {ok err} [_parse_source $PMT(source) $PMT(pay_sort)] {break}
	if {!$ok} {return [list 0 $err]}

	# Special Case for Laser Cards
	# Advised by Commidea that all laser cards need to be sent through
	# as customer present transactions.
	if {[info exists PMT(pg_method)] && $PMT(pg_method) ne ""} {
		set COMMIDEA_DATA(CaptureMethod) $PMT(pg_method)
	}

	foreach {ok err} [_parse_card\
		$PMT(card_no) $PMT(issue_no) $PMT(start) $PMT(expiry)] {break}
	if {!$ok} {return [list 0 $err]}


	set COMMIDEA_DATA(AuthCode) $PMT(auth_code)
	# 2 - Reverse/Reject Transaction
	set COMMIDEA_DATA(Command) 2

	return [list 1 OK]
}

proc ob_commidea::_load_data_ENR {ARRAY} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	set COMMIDEA_DATA(MerchantData)      $PMT(apacs_ref)

	# Currency
	if {![info exists COMMIDEA(CCY,$PMT(ccy_code))]} {
		ob_log::write ERROR\
			{ob_commidea::_load_data_trecord : Unrecognised ccy $PMT(ccy_code)}
		return [list 0 PMT_CCY]
	}
	set COMMIDEA_DATA(NumericCcy) $COMMIDEA(CCY,$PMT(ccy_code))

	foreach {ok err} [_parse_card\
		$PMT(card_no) $PMT(issue_no) $PMT(start) $PMT(expiry)] {break}
	if {!$ok} {return [list 0 $err]}

	# note that the expiry is sent as YYMM
	regexp {([0-1][0-9])/([0-9][0-9])} $PMT(expiry) -> m y
	set COMMIDEA_DATA(CardExpMonth) $m
	set COMMIDEA_DATA(CardExpYear)  $y
	set COMMIDEA_DATA(CcyExponent)  2
	set COMMIDEA_DATA(TxnDesc) ""

	# Get the VBV, 3DS login details
	if {[catch {ob_db::exec_qry ob_commidea::get_card_auth $PMT(pg_acct_id)} rs]} {
		ob_log::write ERROR {Error executing get_card_auth: $rs}
		return [list 0 "NO_3DS_DETAILS"]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR {No 3DS details from acct_id $PMT(pg_acct_id)}
		ob_db::rs_close $rs
		return [list 0 "NO_3DS_DETAILS"]
	}

	foreach {col is_enc var} {
		acquirer           0 MkAcquirerId
		merchant_name      0 MerchantName
		merchant_country   0 MerchantCountryCode
		merchant_url       0 MerchantURL
		visa_bank_id       0 VisaMerchantBankId
		enc_visa_login     1 VisaMerchantNumber
		enc_visa_password  1 VisaMerchantPassword
		mcm_bank_id        0 McmMerchantBankId
		enc_mcm_login      1 McmMerchantNumber
		enc_mcm_password   1 McmMerchantPassword
	} {
		set val [db_get_col $rs 0 $col]
		if  {$is_enc} {
			set val [ob_crypt::decrypt_by_bf $val]
		}

		set COMMIDEA_DATA($var) $val
	}

	set COMMIDEA_DATA(TxnValue) [string map {" " ""} $PMT(amount)]
	set COMMIDEA_DATA(TxnValuePence) [expr {int(100 * $COMMIDEA_DATA(TxnValue))}]

	# Browser Settings

	set COMMIDEA_DATA(BrowserAcceptHeader)    $PMT(3d_secure,browser,accept_headers)
	set COMMIDEA_DATA(BrowserUserAgentHeader) $PMT(3d_secure,browser,user_agent)

	return [list 1 OK]
}

proc ob_commidea::_load_data_PAY_AUTH {ARRAY} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	set COMMIDEA_DATA(MerchantData)  $PMT(apacs_ref)

	set ref [split $PMT(3d_secure,ref) ":"]
	set COMMIDEA_DATA(ProcessingDB)  [lindex $ref 0]
	set COMMIDEA_DATA(AuthRequestId) [lindex $ref 1]

	if {[info exists PMT(3d_secure,pareq)]} {

		# We haven't done the redirect so have decided
		# that we can process the payment without it
		set COMMIDEA_DATA(Enrolled) "N"
		set COMMIDEA_DATA(PaRes)    ""

	} elseif {[info exists PMT(3d_secure,pares)]} {

		# We have come back from the redirect
		set COMMIDEA_DATA(Enrolled) "Y"
		set COMMIDEA_DATA(PaRes)    $PMT(3d_secure,pares)

	} else {
		ob_log::write ERROR {_load_data_PAY_AUTH: cannot find enrollment req}
		return [list 0 ERR]
	}


	return [list 1 OK]
}

proc ob_commidea::_load_data_UKASH {ARRAY} {

	variable COMMIDEA_DATA

	upvar $ARRAY PMT

	foreach {v var_name} {
		MerchantData        transactionId
		UKASHReqType        UKASHReqType
		UKASHLogin          sub_client
		UKASHPassword       sub_password
		UKASHBrandId        sub_mid
		UKASHVoucherNumber  UKASHVoucherNumber
		UKASHVoucherValue   UKASHVoucherValue
		UKASHBaseCurr       UKASHBaseCurr
		UKASHTicketValue    UKASHTicketValue
		UKASHRedemptionType UKASHRedemptionType
		UKASHProductCode    UKASHProductCode
		MerchDateTime       time
	} {
		if {[info exists PMT($var_name)]} {
			set COMMIDEA_DATA($v) $PMT($var_name)
		}
	}

	return [list 1 OK]
}

proc ob_commidea::_load_host_details {pg_type} {

	if {[catch {set rs [ob_db::exec_qry ob_commidea::commidea_get_host $pg_type]} msg]} {
		ob_log::write ERROR {ob_commidea::_load_host_details : failed to retrieve $pg_type host details - $msg}
		return [list 0 "" ""]
	}

	if {[db_get_nrows $rs] != 1} {
		ob_log::write ERROR {ob_commidea::_load_host_details : commidea_get_host should have returned 1 row - returned [db_get_nrows $rs]}
		return [list 0 "" ""]
	}

	set host         [db_get_col $rs 0 pg_ip]
	set conn_timeout [db_get_col $rs 0 conn_timeout]
	set resp_timeout [db_get_col $rs 0 resp_timeout]

	ob_db::rs_close $rs

	return [list 1 $host $conn_timeout $resp_timeout]
}

#
# This is also called from the payment settler, so care should be taken
# when changing the interface or behaviour of this proc.
#
proc ob_commidea::do_request {type ARRAY} {

	upvar $ARRAY PMT

	# verify data and construct the xml message
	foreach {ok request} [_construct_msg $type PMT] {
		if {!$ok} {
			ob_log::write ERROR {ob_commidea::do_request : _construct_msg failed: $request}
			return [list 0 $request]
		}
	}

	set sensitive_request [_mask_sensitive_info $request]
	ob_log::write INFO {ob_commidea::do_request - Request:\n$sensitive_request}

	# send the message to Commidea
	foreach {ok response} [_msg_send $request] {
		if {!$ok} {
			ob_log::write ERROR {ob_commidea::do_request : _msg_send failed: $response}
			return [list 0 $response]
		}
	}

	ob_log::write INFO {Response: $response}

	# unpack the message
	foreach {ok reason} [_msg_unpack $type $response] {
		if {!$ok} {
			ob_log::write ERROR {ob_commidea::do_request : _msg_unpack failed: $reason}
			return [list 0 $reason]
		}
	}

	return [list 1 OK]
}

#
# Masks information in the request string which shouldn't be logged
# such as the card number and the CV2 number.
#
proc ob_commidea::_mask_sensitive_info {message} {

	# mask the card number to only show the card bin (first 6) and last 4 digits
	if {[regexp {<pan>([0-9]*)</pan>} $message match card_num]} {

		# replace the digits with an 'X' except for the card bin and last 4
		set masked_num "[string range $card_num 0 5][string repeat "X" [expr {[string length $card_num] - 10}]][string range $card_num end-3 end]"

		# now put the masked version back in the message
		regsub $match $message "<pan>$masked_num</pan>" message
	}

	if {[regexp {<cardnumber>([0-9]*)</cardnumber>} $message match card_num]} {

		# replace the digits with an 'X' except for the card bin and last 4
		set masked_num "[string range $card_num 0 5][string repeat "X" [expr {[string length $card_num] - 10}]][string range $card_num end-3 end]"

		# now put the masked version back in the message
		regsub $match $message "<cardnumber>$masked_num</cardnumber>" message
	}

	# Mask Ukash vouchers
	if {[regexp {<vouchernumber>([0-9]*)</vouchernumber>} $message match voucher]} {

		# replace the digits with an 'X' except for the card bin and last 4
		set masked_num "[string range $voucher 0 5][string repeat "X" [expr {[string length $voucher] - 10}]][string range $voucher end-3 end]"

		# now put the masked version back in the message
		regsub $match $message "<vouchernumber>$masked_num</vouchernumber>" message

	}

	# mask the CV2 number
	if {[regexp {<csc>([0-9]*)</csc>} $message match cv2_num]} {

		set masked_num "[string repeat "X" [string length $cv2_num]]"

		# now put the masked version back in the message
		regsub $match $message "<csc>$masked_num</csc>" message
	}

	return $message
}

proc ob_commidea::_send_req {url req conn_timeout resp_timeout} {

	# Make the connection
	foreach {prot host port path u p} [::ob_socket::split_url $url] {break}

	if {[string length $path] == 0} {
		set path /
	}

	switch -exact -- $prot {
		"http" {
			ob_log::write INFO {Connecting to $host on port $port using http.}
			set tls -1
		}
		"https" {
			ob_log::write INFO {Connecting to $host on port $port using tls.}
			set tls ""
		}
		default {
			return [list "ERR_CON_ERROR" "Unknown protocol: $prot"]
		}
	}

	set request [::ob_socket::format_http_req\
		-headers [list "content-type" "text/xml; charset=UTF-8"]\
		-host $host \
		-port $port \
		-method "POST" \
		-post_data $req \
		$path]

	set response {}

	set ret [::ob_socket::send_req\
		-conn_timeout $conn_timeout\
		-req_timeout  $resp_timeout\
		-tls          $tls\
		-is_http      1\
		$request $host $port]

	foreach {req_id status complete} $ret {break}

	if {$status == "OK"} {
		set response [::ob_socket::req_info $req_id http_body]
		::ob_socket::clear_req $req_id
		return [list "OK" $response]
	}

	if {[::ob_socket::server_processed $req_id]} {
		#
		# The server *MAY* have processed this request, but we don't know
		# for sure. If we have an explicit request timeout, we need to pass this back.

		::ob_socket::clear_req $req_id

		if {$status == "REQ_TIMEOUT"} {
			return [list PMT_REQ_TIMEOUT ""]
		}

		return [list "ERR_BAD_RESPONSE" ""]
	} else {
		::ob_socket::clear_req $req_id
		return [list "PMT_NO_SOCKET" ""]
	}
}

#
# Calls to create the required xml for commidea requests
#
proc ob_commidea::_msg_pack  {msg_type} {

	variable COMMIDEA
	variable COMMIDEA_DATA
	variable INITIALISED

	if {!$INITIALISED} {
		init
	}

	foreach {wrap_doc wrap_root data_node} [_msg_pack_wrapper $msg_type] {break}

	# Create the XML doc
	dom setResultEncoding "UTF-8"
	set doc      [dom createDocument $COMMIDEA(DOC_TITLE,$msg_type)]
	set root     [$doc documentElement]

	$root setAttribute "xmlns:xsi" $COMMIDEA(XMLNS.XSI)
	$root setAttribute "xmlns"     $COMMIDEA(NS,$msg_type)

	if {[catch {_msg_pack_nodes $doc $root $msg_type} msg]} {
		ob_log::write ERROR {_msg_pack: Error preparing dom tree: $msg}
		$doc delete
		return [list ERR ""]
	}

	set data_msg "$COMMIDEA(DOC_HEADER) [$root asXML]"
	$doc delete

	set txtn [$wrap_doc createCDATASection $data_msg]
	$data_node appendChild $txtn

	set msg "$COMMIDEA(DOC_HEADER) [$wrap_root asXML]"
	$wrap_doc delete

	return [list "OK" $msg]
}

proc ob_commidea::_msg_pack_nodes {doc root_node msg_type} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	set parent    $root_node
	set node_name $msg_type
	set pos       0
	set stack     [list]

	# Build up the DOM tree from a set of tcl lists
	while {1} {

		set data COMMIDEA($node_name,fields)

		if {$pos >= [llength [set $data]]} {

			# The end of this node
			if {![llength $stack]} {
				break
			}

			# Pop
			foreach {parent node_name pos} [lindex $stack end] {break}
			set stack [lrange $stack 0 end-1]
			continue
		}

		# Read the node info and move the position pointer on
		foreach {item optional type f} [lindex [set $data] $pos] {break}
		incr pos

		if {![info exists COMMIDEA_DATA($f)]} {
			if {$optional eq "O"} {
				continue
			} else {
				error "$item needs to be set up"
			}
		}

		# Process the node
		if {$type eq "VAL"} {

			set elem [$doc createElement $item]
			set node [$parent appendChild $elem]
			set txtn [$doc createTextNode $COMMIDEA_DATA($f)]
			$node appendChild $txtn

		} elseif {$type eq "NODE"} {

			# Push
			lappend stack [list $parent $node_name $pos]
			set pos 0

			set node_name $f
			set elem [$doc createElement $item]
			set node [$parent appendChild $elem]
			set parent $node
		}
	}
}

proc ob_commidea::_msg_unpack {msg_type xml} {

	variable COMMIDEA
	variable COMMIDEA_RESP

	if {[catch {
		set doc [dom parse $xml]
	} msg]} {
		ob_log::write ERROR {ob_commidea::_msg_unpack failed - $msg}
		return [list 0 PMT_ERR]
	}

	set root   [$doc documentElement]

	set node [$root selectNodes\
		-namespaces [list ci $COMMIDEA(XMLNS)]\
		{//soap:Envelope/soap:Body/ci:ProcessMsgResponse/ci:ProcessMsgResult/ci:MsgData}]

	set xml_resp [[$node firstChild] nodeValue]

	$doc delete

	ob_log::write INFO {xml response: $xml_resp}

	# Message Result
	set doc    [dom parse $xml_resp]
	set root   [$doc documentElement]

	foreach {f var} $COMMIDEA($msg_type,resp_fields) {
		set ns $COMMIDEA(NS,$msg_type)
		set node [$root selectNodes -namespaces [list $ns $ns]\
			"//$ns:$COMMIDEA(RESP,$msg_type)/$ns:$f"]

		set value ""
		if {$node != "" && [$node hasChildNodes]} {
			set value [[$node firstChild] nodeValue]
		}
		set COMMIDEA_RESP($var) $value
		ob_log::write INFO {$f ($var) = $value}
	}

	if {![info exists COMMIDEA_RESP(ProcessingDB)]} {
		set COMMIDEA_RESP(ProcessingDB) "DBNotSet"
	}

	if {![info exists COMMIDEA_RESP(TransactionID)]} {
		set COMMIDEA_RESP(TransactionID) "UIDNotSet"
	}

	set COMMIDEA_RESP(gw_uid) [join [list \
		$COMMIDEA_RESP(ProcessingDB) $COMMIDEA_RESP(TransactionID)] ":"]

	ob_log::write INFO {COMMIDEA_RESP(gw_uid): $COMMIDEA_RESP(gw_uid)}

	$doc delete
}



proc ob_commidea::_msg_pack_wrapper {msg_type} {

	variable COMMIDEA_DATA
	variable COMMIDEA

	# Create the Soap Wrappers
	dom setResultEncoding "UTF-8"
	set doc      [dom createDocument "soap:Envelope"]
	set root     [$doc documentElement]

	$root setAttribute "xmlns:xsi"  $COMMIDEA(XMLNS.XSI)
	$root setAttribute "xmlns:xsd"  $COMMIDEA(XMLNS.XSD)
	$root setAttribute "xmlns:soap" $COMMIDEA(XMLNS.SOAP)

	set elem [$doc createElement "soap:Body"]
	set node [$root appendChild $elem]

	set elem [$doc createElement "ProcessMsg"]
	$elem setAttribute "xmlns" $COMMIDEA(XMLNS)
	set node [$node appendChild $elem]

	set elem [$doc createElement "Message"]
	set message_node [$node appendChild $elem]

	# The Client Header

	set elem [$doc createElement "ClientHeader"]
	$elem setAttribute "xmlns" $COMMIDEA(XMLNS)
	set header_node [$message_node appendChild $elem]

	foreach {item optional f} $COMMIDEA(HEADER,fields) {

		if {![info exists COMMIDEA_DATA($f)]} {
			if {$optional eq "O"} {
				continue
			} else {
				error "$item needs to be set up"
			}
		}

		set elem [$doc createElement $item]
		set node [$header_node appendChild $elem]
		set txtn [$doc createTextNode $COMMIDEA_DATA($f)]
		$node appendChild $txtn
	}
	# End of Client Header

	# Message Type

	set elem [$doc createElement "MsgType"]
	$elem setAttribute "xmlns" $COMMIDEA(XMLNS)
	set node [$message_node appendChild $elem]
	set txtn [$doc createTextNode $COMMIDEA(MSG_TYPE,$msg_type)]
	$node appendChild $txtn

	# Message Data
	set elem [$doc createElement "MsgData"]
	$elem setAttribute "xmlns" $COMMIDEA(XMLNS)
	set node [$message_node appendChild $elem]

	# The transaction details will be added to the Message Data Node
	# Hence returning a handle to this.
	return [list $doc $root $node]
}

proc ob_commidea::_parse_gw_uid {gw_uid} {

	variable COMMIDEA
	variable COMMIDEA_DATA

	set req_ids [split $gw_uid ":"]
	set COMMIDEA_DATA(ProcessingDB)  [lindex $req_ids 0]
	set COMMIDEA_DATA(TransactionID) [lindex $req_ids 1]

	return [list 1 "OK"]
}

proc ob_commidea::_parse_source {source pay_sort} {

	variable COMMIDEA_DATA

	# Set e-commerce flag to Y only for internet
	if {$source eq "I" && $pay_sort eq "D"} {
		set COMMIDEA_DATA(ECom)          "Y"
		set COMMIDEA_DATA(CaptureMethod) 12
	} else {
		# Refunds cannot be captured as ecommerce payments with commidea.
		# Following their advice these are processed as:
		# Keyed Customer Not Present Telephone Order - Capture Method  11
		set COMMIDEA_DATA(ECom)          "N"
		set COMMIDEA_DATA(CaptureMethod) 11
	}

	return [list 1 "OK"]
}

proc ob_commidea::_parse_card {Pan Issue StartDate ExpiryDate} {

	variable COMMIDEA_DATA

	# Remove spaces
	foreach f {Pan Issue StartDate ExpiryDate} {
		regsub -all {\s} [set $f] {} COMMIDEA_DATA($f)
	}

	if {![regexp {^[0-9]{13,19}$} $COMMIDEA_DATA(Pan)]} {
		ob_log::write ERROR {ob_commidea::_parse_card: Card number failed regexp. Length is [string length $COMMIDEA_DATA(Pan)]}
		return [list 0 PMT_CARD]
	}

	# Check issue no. is between 1 and 2 digits if not null
	if {$COMMIDEA_DATA(Issue) != "" && ![regexp {^[0-9]{1,2}$} $COMMIDEA_DATA(Issue)]} {
		ob_log::write ERROR {ob_commidea::_parse_card: Issue No. failed regexp}
		return [list 0 PMT_ISSUE]
	}

	if {$COMMIDEA_DATA(StartDate) != "" && ![card_util::check_card_start $COMMIDEA_DATA(StartDate)]} {
		ob_log::write ERROR {ob_commidea::_parse_card: Start Date failed check - $COMMIDEA_DATA(StartDate)}
		return [list 0 PMT_STRT]
	}

	if {$COMMIDEA_DATA(ExpiryDate) != "" && ![card_util::check_card_expiry $COMMIDEA_DATA(ExpiryDate)]} {
		ob_log::write ERROR {ob_commidea::_parse_card: Expiry Date failed check - $COMMIDEA_DATA(ExpiryDate)}
		return [list 0 PMT_EXPR]
	}

	# split up the start date
	if {$COMMIDEA_DATA(StartDate) != ""} {
		if {![regexp {^([01][0-9])\/([019][0-9])$} $COMMIDEA_DATA(StartDate) junk start_month start_year]} {
			ob_log::write ERROR {ob_commidea::_parse_card: Failed to reverse start date format - $COMMIDEA_DATA(StartDate)}
			return [list 0 PMT_STRT]
		} else {
			# Commidea expect the start/expiry dates to be without the "/"
			# Support 52743: StartDate should be in format MMYY, while ExpiryDate YYMM
			set COMMIDEA_DATA(StartDate)  "${start_month}${start_year}"
		}
	}

	# split up the expiry date
	if {$COMMIDEA_DATA(ExpiryDate) != ""} {
		if {![regexp {^([01][0-9])\/([0129][0-9])$} $COMMIDEA_DATA(ExpiryDate) junk expiry_month expiry_year]} {
			ob_log::write ERROR {ob_commidea::_parse_card: Failed to reverse expiry date format - $COMMIDEA_DATA(ExpiryDate)}
			return [list 0 PMT_EXPR]
		} else {
			# Commidea expect the start/expiry dates to be without the "/"
			set COMMIDEA_DATA(ExpiryDate) "${expiry_year}${expiry_month}"
		}
	}

	return [list 1 "OK"]
}
