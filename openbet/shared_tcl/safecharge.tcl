# $Id: safecharge.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd.  All rights reserved.
#
# SafeCharge API
#
# CONFIG
#
#
# PROCEDURES
#
# public:
#    ob_safecharge::init
#    ob_safecharge::make_call
#
# private:
#    ob_safecharge::_prep_qrys
#    ob_safecharge::_get_cvv2_status
#    ob_safecharge::_setup_data
#    ob_safecharge::_parse_resp
#    ob_safecharge::_parse_auth3d_resp
#    ob_safecharge::_setup_data_Sale
#    ob_safecharge::_setup_data_Credit
#    ob_safecharge::_setup_data_Void
#    ob_safecharge::_setup_data_Auth3D
#    ob_safecharge::_send_request
#    ob_safecharge::_mask_sensitive_info
#    ob_safecharge::_parse_overall_response

# comments:
# TODO: Item to update / change
# TEST: Test code to generate specific responses
#
# Note:
# Safecharge has a 2 step 3D secure process. The first step which we generally
# consider the "enroll" step, SafeCharge calls the Auth3D step.
# After an Auth3D request, a Sale request is sent to finish the payment.
#



namespace eval ob_safecharge {

	variable INITIALISED 0
	variable SAFECHARGE_ERR_RESP
	variable SAFECHARGE_DATA
	variable SAFECHARGE_CFG
	variable SAFECHARGE_RESP
	variable SAFECHARGE_RESP_FIELDS
	variable SAFECHARGE

}

proc ob_safecharge::init {} {

	variable INITIALISED
	variable SAFECHARGE_ERR_RESP
	variable SAFECHARGE_DATA
	variable SAFECHARGE_CFG
	variable SAFECHARGE_RESP
	variable SAFECHARGE_RESP_FIELDS
	variable SAFECHARGE

	if {$INITIALISED} {
		return
	}

	package require net_socket

	_prep_qrys

	# General Response Codes

	# ErrCode   ExErrorCode  Description
	#	0		0		APPROVED
	#	-1		0		DECLINED*
	#	0		-2		PENDING
	#	-1100	>0		ERROR (Filter error)**
	#	<0		!= 0	ERROR (Gateway/Bank Error)
	#	-1001	0		Invalid Login
	#	-1005	0		IP out of range
	#	-1203	0		Timeout/Retry
	# Error Reason Codes

	#   ExErrorCode		Description
	#	1001	Invalid Expiration Date
	#	1002	Expiration Date Too Old
	#	1101	Invalid Card Number (Alpha Numeric)
	#	1102	Invalid Card Number (Digits Count)
	#	1103	Invalid Card Number (MOD 10)
	#	1104	Invalid CVV2
	# 	1105	Auth Code/Trans ID/CC   Numbe
	#	1106	Credit Amount Exceeds Total Charges
	#	1107	Cannot Credit this CC company
	#	1108	Illegal interval between Auth and Settle
	#	1109	Not allowed to process this CC company
	#	1110	Unrecognized CC company
	#	1111	This Transaction was charged back
	#	1112	Sale/Settle was already credited
	#	1113	Terminal is not configured to work with this CC company
	#	1114	Blocked (Black-listed) card number
	#	1115	Illegal BIN number
	#	1116	<Custom Fraud Screen Filter>
	#	1118	'N' Cannot be a Positive CVV2 Reply
	#	1119	B'/'N' Cannot be a Positive AVS Reply
	#	1120	Invalid AVS
	#	1121	CVV2 check is not allowed  in Credit/Settle/Void
	#	1122	AVS check is not allowed in Credit/Settle/Void
	#	1124	Credits total amount exceeds restriction
	#	1125	Format Error
	#	1126	Credit amount exceeds ceiling
	#	1127	Limit exceeding amount
	#	1128	Invalid Transaction Type Code
	#	1129	General Filter Error
	#	1130	Bank required fields are missing or	incorrect
	#	1131	This transaction type is not allowed for this bank
	#	1132	Amount exceeds bank limit
	#	1133	GW required fields are missing
	#	1134	AVS Processor Error
	#	1135	Only one credit per sale is allowed
	#	1136	Mandatory fields are missing
	#	1137	Credit count exceeded CCC restriction
	#	1138	Invalid Credit Type
	#	1139	This card is not supported in the CFT Program
	#	1140	Card must be processed in the GW System
	#	1141	Transaction type is not allowed
	#	1142	AVS required fields are missing or incorrect
	#	1143	Country does not match ISO Code
	#	1144	Must provide UserID    in   a  Rebill transaction
	#	1145	Your Rebill profile does not support this Transaction type
	#	1146	Void is not allowed due to CC restriction
	#	1147	Invalid Account Number
	#	1148	Invalid Cheque Number
	#	1149	Account Number/Trans ID Mismatch
	#	1150	UserID/Trans Type /Trans ID Mismatch
	#	1151	Transaction does not exist in the rebill system.
	#	1152	Transaction was already canceled
	#	1153	Invalid Bank Code (Digits Count)
	#	1154	Invalid Bank Code (Alpha Numeric)
	#	1155	VBV-Related transaction is missing or incorrect
	#	1156	Debit card required fields are missing or incorrect
	#	1157	No updated parameters were supplied
	#	1158	VBV PaRes value is incorrect
	#	1159	State does not match ISO Code
	#	1160	Invalid Bank Code (Checksum Digit)
	#	1161	This Bank allows only 3 digits in CVV2
	#	1162	Age verification Failed
	#	1163	Transaction must contain a  Card number/Token
	#	1164	Invalid Token
	#	1165	Token Mismatch
	#	1166	Invalid Email address
	#	1167	Transaction already settled
	#	1168	Transaction already voided
	#	1169	sg_ResponseFormat field is not valid
	#	1170	Version field is missing or incorrect
	#	1171	Issuing Country is invalid
	#	1172	Phone is missing or format error
	#	1173	Check number is missing or incorrect
	#	1174	Birth date format error
	#	1175	Zip code format error
	#	1176	Cannot void an auth transaction
	#	1177	Can’t Void a Credit Transaction
	#	1178	Cannot void a void transaction
	#	1179	Cannot perform this void
	#	1180	Invalid start date
	#	1181	Merchant Name is too long (>25)
	#	1182	Transaction must be send as 3Dsecure
	#	1183	Account is not 3D enabled
	#	1184	Transaction 3D status is incorrect
	#	1185	Related transaction must be of type ‘AUTH3D’
	#	1186	Related transaction  must be 3D authenticated
	#	1187	Country does not support CFT program
	#	1201	Invalid Amount
	#	1202	Invalid Currency
	array set SAFECHARGE_ERR_RESP {
		 	-1	PMT_DECL
		-1100	PMT_ERR
		-1001	PMT_ERR_INVALID_LOGIN
		-1005	PMT_ERR_IP_RANGE
		-1203	PMT_ERR_TIMEOUT
		0		PMT_DECL
		1001	PMT_EXPR
		1002	PMT_EXPR
		1101	PMT_CARD
		1102	PMT_CLEN
		1103	PMT_CARD
		1104	PMT_ERROR_INVALID_CVV2
		1105	PMT_ERR
		1106	PMT_ERR_TECH
		1107	PMT_ERR_TECH
		1108	PMT_ERR_TECH
		1109	PMT_ERR_TECH
		1110	PMT_ERR_TECH
		1111	PMT_ERR_BANK
		1112	PMT_ERR_BANK
		1113	PMT_ERR_TECH
		1114	PMT_ERR_BANK
		1115	PMT_ERR_BANK
		1116	PMT_ERR_FRAUD
		1118	PMT_ERR_TECH
		1119	PMT_ERR_TECH
		1120	PMT_AVS
		1121	PMT_ERR_TECH
		1122	PMT_ERR_TECH
		1124	PMT_ERR_TECH
		1125	PMT_ERR_TECH
		1126	PMT_ERR_TECH
		1127	PMT_ERR_TECH
		1128	PMT_ERR_TECH
		1129	PMT_ERR_TECH
		1130	PMT_ERR_CUST
		1131	PMT_ERR_BANK
		1132	PMT_MAX
		1133	PMT_ERR_CUST
		1134	PMT_ERR_TECH
		1135	PMT_ERR_TECH
		1136	PMT_ERR_CUST
		1137	PMT_ERR_TECH
		1138	PMT_ERR_TECH
		1139	PMT_ERR_TECH
		1140	PMT_ERR_TECH
		1141	PMT_ERR_TECH
		1142	PMT_ERR_TECH
		1143	PMT_ERR_TECH
		1144	PMT_ERR_TECH
		1145	PMT_ERR_TECH
		1146	PMT_ERR_TECH
		1147	PMT_ERR_TECH
		1148	PMT_ERR_TECH
		1149	PMT_ERR_TECH
		1150	PMT_ERR_TECH
		1151	PMT_ERR_TECH
		1152	PMT_ERR_TECH
		1153	PMT_ERR_TECH
		1154	PMT_ERR_TECH
		1155	PMT_ERR_TECH
		1156	PMT_ERR_TECH
		1157	PMT_ERR_TECH
		1158	PMT_ERR_TECH
		1159	PMT_ERR_TECH
		1160	PMT_ERR_TECH
		1161	PMT_ERROR_INVALID_CVV2
		1162	PMT_ERR_TECH
		1163	PMT_ERR_TECH
		1164	PMT_ERR_TECH
		1165	PMT_ERR_TECH
		1166	PMT_ERR_TECH
		1167	PMT_ERR_TECH
		1168	PMT_ERR_NOT_UNKNOWN
		1169	PMT_ERR_TECH
		1170	PMT_ERR_TECH
		1171	PMT_ERR_TECH
		1172	PMT_ERR_TECH
		1173	PMT_ERR_TECH
		1174	PMT_ERR_TECH
		1175	PMT_ERR_TECH
		1176	PMT_ERR_TECH
		1177	PMT_ERR_TECH
		1178	PMT_ERR_TECH
		1179	PMT_ERR_TECH
		1180	PMT_STRT
		1181	PMT_ERR_TECH
		1182	PMT_ERR_TECH
		1183	PMT_ERR_TECH
		1184	PMT_ERR_TECH
		1185	PMT_ERR_TECH
		1186	PMT_ERR_TECH
		1187	PMT_ERR_TECH
		1201	PMT_AMNT
		1202	PMT_NOCCY
	}

	# Mandatory Customer Fields
	# SafeChargeParam  PMT array field
	set SAFECHARGE(customer,fields) {
		sg_FirstName	fname
		sg_LastName	 	lname
		sg_Address		addr_1
		sg_City			city
		sg_Zip			postcode
		sg_Country		cntry_code
		sg_Phone		telephone
		sg_IPAddress	ip
		sg_Email		email
	}
	#	sg_State		none
	# Non Mandatory
	#		sg_Ship_Country
	#		sg_Ship_State
	#		sg_Ship_City
	#		sg_Ship_Address
	#		sg_Ship_Zip
	#		sg_BirthDate


	# Mandataory Credit Card Fields
	# SafeChargeParam  PMT array field
	set SAFECHARGE(cc,fields) {
		sg_NameOnCard   hldr_name
		sg_CardNumber   card_no
		sg_ExpMonth     expiry_month
		sg_ExpYear      expiry_year
		sg_CVV2         cvv2
		sg_DC_Issue     issue_no
		sg_DC_StartMon  start_month
		sg_DC_StartYear start_year
	}
	# Non Mandatory
	#	sg_DC_Issue
	#	sg_DC_StartMon
	#	sg_DC_StartYear
	#	sg_IssuingBankName


	# Mandataory Transaction Fields
	# SafeChargeParam  PMT array field
	set SAFECHARGE(transaction,fields) {
		sg_Currency			ccy_code
		sg_Amount			amount
		sg_ClientLoginID	client
		sg_ClientPassword	password
		sg_ClientUniqueID	apacs_ref
	}
	# Populated Elsewhere - used for Credit/3Ds
	#	sg_TransType		none
	#	sg_AuthCode			none
	#	sg_TransactionID	none
	#	sg_CreditType		C

	# Non Mandatory
	#	sg_AVS_Approves
	#	sg_CustomData
	#	sg_UserID
	#	sg_CreditType
	#	sg_WebSite
	#	sg_ProductID
	#	sg_ResponseFormat
	#	sg_Rebill
	#	sg_ResponseURL
	#	sg_TemplateID


	# XML Fields Returned
	set SAFECHARGE_RESP_FIELDS(fields) {
		ClientID
		ClientUniqueID
		TransactionID
		Status
		AuthCode
		AVSCode
		CVV2Reply
		AcquirerID
		IssuerBankName
		IssuerBankCountry
		Reason
		ErrCode
		ExErrCode
		CustomData
		PaReq
		MerchantID
		ACSurl
		ECI
		ThreeDReason
		"ReasonCodes,Reason"
	}

	# Mappings to PMT array
	set SAFECHARGE_RESP_FIELDS(pmt) {
		TransactionID	gw_uid
		AuthCode		auth_code
		Status			gw_auth_code
		Reason			gw_ret_msg
		ErrCode			gw_ret_code
		AcquirerID		gw_acq_bank
		AVSCode 		cv2avs_status
	}

	set INITIALISED 1
}

proc ob_safecharge::_prep_qrys {} {

	# Get customer elite status
	ob_db::store_qry ob_safecharge::get_elite_status {
		select
			elite
		from
			tCustomer c
		where
			c.cust_id = ?
	}

	# Retrieve pmt details for VOID call
	ob_db::store_qry ob_safecharge::get_pmt_details {
		select
			gw_auth_code,
			gw_uid
		from
			tPmtCC
		where
			p.pmt_id = ?
	}

	# Retrieve cust details
	ob_db::store_qry ob_safecharge::get_cust_details {
		select
			a.cust_id,
			a.ccy_code,
		    a.cr_date reg_date,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_postcode,
			r.addr_city,
			r.addr_country,
			r.email,
			r.telephone,
			c.country_code
		from
			tAcct a,
			tCustomerReg r,
			tCustomer c
		where
			  a.acct_id = ?
		  and a.cust_id = r.cust_id
		  and a.cust_id = c.cust_id
	}


}

# Reset variables to default state
proc ob_safecharge::_reset {} {

	variable SAFECHARGE_DATA
	variable SAFECHARGE_RESP

	catch {unset SAFECHARGE_RESP}
	catch {unset SAFECHARGE_DATA}
}


proc ob_safecharge::_load_non_3ds_info { ARRAY } {
	variable SAFECHARGE_DATA
	set fn "ob_safecharge::_load_non_3ds_info"

	upvar $ARRAY PMT

	ob_log::write ERROR {$fn: Loading Non 3ds account info }
	set SAFECHARGE_DATA(sg_ClientLoginID)	$PMT(sub_client)
	set SAFECHARGE_DATA(sg_ClientPassword)	$PMT(sub_password)
}


proc ob_safecharge::_setup_data { ARRAY } {

	variable SAFECHARGE_CFG
	variable SAFECHARGE
	variable SAFECHARGE_DATA

	set fn "ob_safecharge::_setup_data"

	upvar $ARRAY PMT

	#TODO: Remove
	ob_log::write DEV {PMT Array:}
	ob_log::write_array DEV PMT

	# Host details
	set SAFECHARGE_CFG(host)         $PMT(host)
	set SAFECHARGE_CFG(conn_timeout) $PMT(conn_timeout)
	set SAFECHARGE_CFG(resp_timeout) $PMT(resp_timeout)

	# Always want XML Response
	set SAFECHARGE_DATA(sg_ResponseFormat) 4
	set SAFECHARGE_DATA(sg_Version)    "2.0.1"

	# Default to off
	set SAFECHARGE_DATA(sg_Is3dTrans) 	0

	# Setup SAFECHARGE_DATA arrays
	set cust_missing 0
	foreach {sc p} $SAFECHARGE(customer,fields) {
		if {[info exists PMT($p)] } {
			set SAFECHARGE_DATA($sc) $PMT($p)
		} else {
			ob_log::write ERROR {$fn: Missing mandatory data: $sc }
			set cust_missing 1
		}
	}

	if {$cust_missing} {

		ob_log::write INFO {$fn: Customer data missing. Attempting to load.}

		if [catch {set rs [ob_db::exec_qry ob_safecharge::get_cust_details $PMT(acct_id)]} msg] {
			ob_log::write ERROR {$fn: PMT Error retrieving account information; $msg}
			# Will continue with the request for now...
		} else {
			if {[db_get_nrows $rs] != 1} {
				db_close $rs
				ob_log::write ERROR {$fn: PMT Error retrieving account information; Will try to continue}
			} else {
				set PMT(ccy_code) 		  [db_get_col $rs 0 ccy_code]
				set PMT(cust_id)  		  [db_get_col $rs 0 cust_id]

				if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
					set PMT(fname)           [ob_cust::normalise_unicode [db_get_col $rs 0 fname] 0 0]
					set PMT(lname)           [ob_cust::normalise_unicode [db_get_col $rs 0 lname] 0 0]
				} else {
					set PMT(fname)           [db_get_col $rs 0 fname]
					set PMT(lname)           [db_get_col $rs 0 lname]
				}

				set PMT(reg_date)          [db_get_col $rs 0 reg_date]

				if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
					set PMT(addr_1)          [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_1] 0 0]
					set PMT(addr_2)          [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_2] 0 0]
					set PMT(addr_4)          [ob_cust::normalise_unicode [db_get_col $rs 0 addr_street_4] 0 0]
				} else {
					set PMT(addr_1)          [db_get_col $rs 0 addr_street_1]
					set PMT(addr_2)          [db_get_col $rs 0 addr_street_2]
					set PMT(addr_4)          [db_get_col $rs 0 addr_street_4]
				}

				set PMT(addr_3)            [db_get_col $rs 0 addr_street_3]
				set PMT(postcode)          [db_get_col $rs 0 addr_postcode]


				if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
					set PMT(city)           [ob_cust::normalise_unicode [db_get_col $rs 0 addr_city] 0 0]
				} else {
					set PMT(city)           [db_get_col $rs 0 addr_city]
				}

				set PMT(cntry)            [db_get_col $rs 0 addr_country]
				set PMT(telephone)        [db_get_col $rs 0 telephone]
				set PMT(email)            [db_get_col $rs 0 email]
				set PMT(cntry_code)       [db_get_col $rs 0 country_code]
				set PMT(ip)               [reqGetEnv REMOTE_ADDR]
				db_close $rs

				# Reload SafeCharge Data array
				foreach {sc p} $SAFECHARGE(customer,fields) {
					if {[info exists PMT($p)] && ![info exists SAFECHARGE_DATA($sc)]} {
						set SAFECHARGE_DATA($sc) $PMT($p)
					} else {
						ob_log::write ERROR {$fn: Still missing mandatory data: $sc }
					}
				}
			}
		}
	}

	# Need to manually parse start and expiry dates to split into month and year
	if {[info exists PMT(expiry)]} {
		set PMT(expiry_month) [lindex [split $PMT(expiry) "/"] 0]
		set PMT(expiry_year)  [lindex [split $PMT(expiry) "/"] 1]
	}
	if {[info exists PMT(start)]} {
		set PMT(start_month) [lindex [split $PMT(start) "/"] 0]
		set PMT(start_year)  [lindex [split $PMT(start) "/"] 1]
	}

	foreach {sc p} $SAFECHARGE(cc,fields) {
		if {[info exists PMT($p)]} {
			set SAFECHARGE_DATA($sc) $PMT($p)
		} else {
			ob_log::write ERROR {$fn: Missing mandatory data: $sc }
			# Will continue with the request for now...
		}
	}
	foreach {sc p} $SAFECHARGE(transaction,fields) {
		if {[info exists PMT($p)]} {

			#SafeCharge treats JPY differently
			if { $sc == "sg_Currency" && $PMT($p) == "JPY" } {
				set SAFECHARGE_DATA($sc) "YEN"
			} else {
				set SAFECHARGE_DATA($sc) $PMT($p)
			}
		} else {
			ob_log::write ERROR {$fn: Missing mandatory data: $sc }
			# Will continue with the request for now...
		}
	}

	# Properly set expiration dates
	set SAFECHARGE_DATA(sg_ExpMonth) [lindex [split $PMT(expiry) /] 0]
	set SAFECHARGE_DATA(sg_ExpYear)  [lindex [split $PMT(expiry) /] 1]

	# Get Customer VIP Status
	set elite "N"
	if {[catch {ob_db::exec_qry ob_safecharge::get_elite_status $PMT(cust_id)} rs]} {
		ob_log::write ERROR {$fn: Error executing get_elite_status: $rs}
	} else {
		if {[db_get_nrows $rs] == 1} {
			set elite     [db_get_col $rs 0 elite]
		}
		ob_db::rs_close $rs
	}

	if {$elite == "Y"} {
		set SAFECHARGE_DATA(sg_VIPCardHolder)  "true"
	}

	return 1
}

# Additional data needed for Sale Request
proc ob_safecharge::_setup_data_Sale { ARRAY } {
	variable SAFECHARGE_DATA

	upvar $ARRAY PMT
	set fn "ob_safecharge::_setup_data_Sale"

	set SAFECHARGE_DATA(sg_TransType) "Sale"
	ob_log::write INFO {$fn: Sale Request}

	# Complete the 3DS Process - an Auth3D request has already been sent.
	if {[info exists PMT(req_type)] && $PMT(req_type) == "3DSSALE"} {

		ob_log::write INFO {$fn: Completing 3DS with Sale.}
 		if {[info exists PMT(3d_secure,pares)]} {
			set SAFECHARGE_DATA(sg_PARes)    	$PMT(3d_secure,pares)
		}

		if { $PMT(enrol_3d_resp) == 7 } {
			# ECI of 7 means 3DS error. So now send over the non 3DS account.
 			_load_non_3ds_info PMT
			set SAFECHARGE_DATA(sg_Is3dTrans) 	0
		} else {
			set SAFECHARGE_DATA(sg_Is3dTrans) 	1
		}

		set SAFECHARGE_DATA(sg_TransactionID)  	$PMT(3d_secure,ref)
		if { [info exists PMT(3d_secure,cvv2) ]} {
			set SAFECHARGE_DATA(sg_CVV2)	$PMT(3d_secure,cvv2)
		}
	}
}



# Additional data needed for Credit Request
proc ob_safecharge::_setup_data_Credit { ARRAY } {
	variable SAFECHARGE_DATA
	set fn "ob_safecharge::_setup_data_Credit"

	upvar $ARRAY PMT

	set SAFECHARGE_DATA(sg_TransType)  "Credit"
	# 1 = Regular Credit.
	set SAFECHARGE_DATA(sg_CreditType) "1"

}

# Additional data needed for Void Request
proc ob_safecharge::_setup_data_Void { ARRAY } {
	variable SAFECHARGE_DATA
	set fn "ob_safecharge::_setup_data_Void"

	upvar $ARRAY PMT

	# Void Payment - not currently used.

	# Retrieve params of payment to void. This could also be done before the call.....
	if {[catch {ob_db::exec_qry ob_safecharge::get_pmt_details $PMT(pmt_id)} rs]} {
		ob_log::write ERROR {$fn:: Could not find payment $rs}
		return PMT_ERR
	} else {
		if {[db_get_nrows $rs] == 1} {
			set gw_auth_code    [db_get_col $rs 0 gw_auth_code]
			set gw_uid    		[db_get_col $rs 0 gw_uid]
		} else {
			ob_log::write ERROR {$fn:: Could not find payment}
			ob_db::rs_close $rs
			return PMT_ERR
		}
		ob_db::rs_close $rs
	}

	# Additional Mandatory Void fields
	set SAFECHARGE_DATA(sg_TransType) 		"Void"
	set SAFECHARGE_DATA(sg_TransactionID) 	$gw_uid
	set SAFECHARGE_DATA(sg_AuthCode) 		$gw_auth_code

}

# Additional data needed for Auth3D Request
proc ob_safecharge::_setup_data_Auth3D { ARRAY } {
	variable SAFECHARGE_DATA
	set fn "ob_safecharge::_setup_data_Auth3D"

	upvar $ARRAY PMT
	ob_log::write INFO {$fn: 3DS Request}
	set SAFECHARGE_DATA(sg_TransType)  "Auth3D"
	set SAFECHARGE_DATA(sg_Is3dTrans) 	1

}


proc ob_safecharge::_parse_resp {XML_ARRAY PMT_ARRAY} {

	variable SAFECHARGE_RESP_FIELDS
	variable SAFECHARGE_RESP

	upvar $XML_ARRAY XML
	upvar $PMT_ARRAY PMT

	set fn "ob_safecharge::_parse_resp"

	ob::log::write INFO {$fn: SafeCharge response:}

	# Record the response in extra_info
	set extra_info ""

	# extra_info is 160 chars. Can't fit entire response. could make this a config item...
	set extra_info_fields [list ErrCode ExErrCode ClientLoginID Status TransactionID \
				AuthCode AVSCode CVV2Reply AcquirerID]

	foreach {n v} [array get XML] {
		set ele [lindex [split $n ","] 1]
		if { [lsearch $extra_info_fields $ele] != -1 } {
			append  extra_info "${ele}:${v} "
		}  elseif {$n == "Response,ReasonCodes,Reason,code"} {
			append  extra_info "ReasonCode:${v} "
		} elseif {$n == "Response,ReasonCodes,Reason"} {
			append  extra_info "Reason:${v} "
		}
	}
	set PMT(extra_info) $extra_info
	ob_log::write DEV {$fn: extra_info $extra_info}

	# Retrieve SafeCharge Response
	foreach {resp} $SAFECHARGE_RESP_FIELDS(fields) {
		if {[info exists XML(Response,$resp)]} {
			set SAFECHARGE_RESP($resp) $XML(Response,$resp)
		}
	}
	# Reason changed in the latest API?
	if { [info exists XML(Response,ReasonCodes,Reason)] } {
		set SAFECHARGE_RESP(Reason) $XML(Response,ReasonCodes,Reason)
	}

	ob::log::write DEV "$fn: SAFECHARGE_RESP Array:"
	ob_log::write_array DEV SAFECHARGE_RESP


	# Load PMT array with SafeCharge Reponse
	foreach {sc pmt} $SAFECHARGE_RESP_FIELDS(pmt) {
		if { [info exists SAFECHARGE_RESP($sc)]} {
			set PMT($pmt) $SAFECHARGE_RESP($sc)
		} else {
			set PMT($pmt) ""
		}
	}

	if { [info exists SAFECHARGE_RESP(CVV2Reply)] } {
		if { [info exists SAFECHARGE_RESP(AVSCode)] } {
			set PMT(cv2avs_status) [_get_cvv2_status $SAFECHARGE_RESP(CVV2Reply) $SAFECHARGE_RESP(AVSCode) ]
		} else {
			set PMT(cv2avs_status) [_get_cvv2_status $SAFECHARGE_RESP(CVV2Reply)]
		}
	}

	# Append Optional Acquring Bank Info
	if { [info exists SAFECHARGE_RESP(IssuerBankName)]} {
		append PMT(gw_acq_bank) " : $SAFECHARGE_RESP(IssuerBankName)"
	}

	if { [info exists SAFECHARGE_RESP(IssuerBankCountry)]} {
		append PMT(gw_acq_bank) " : $SAFECHARGE_RESP(IssuerBankCountry)"
	}
}

# 3D Secure "Enrollment" Response
proc ob_safecharge::_parse_auth3d_resp { ARRAY } {
	variable SAFECHARGE_RESP

	set fn "ob_safecharge::_parse_auth3d_resp"

	# Process Auth3D Response
	upvar $ARRAY PMT

	#  We use the SafeCharge Transaction ID
	set PMT(3d_secure,ref) $PMT(gw_uid)

	# retreive the SafeCharge response code for the enrolment check
	set PMT(enrol_3d_resp)    $SAFECHARGE_RESP(ErrCode)

	# Scheme is not provided in the API.
	#set PMT(3d_secure,scheme)  "VBV"

	if { $SAFECHARGE_RESP(ErrCode) != "0" } {
		ob_log::write INFO {$fn: Error from Auth3D response: Er: \
			$SAFECHARGE_RESP(ErrCode) Ex: $SAFECHARGE_RESP(ExErrCode) }

		return [_parse_overall_response PMT]
	}

	# ECommerce Indicator
	# If this exists, then this value is stored in enrol_3d_resp.
	if { [info exists SAFECHARGE_RESP(ECI)] } {

		#TODO: Not sure if this is correct...
		set PMT(enrol_3d_resp) $SAFECHARGE_RESP(ECI)

		ob_log::write INFO {$fn: $SAFECHARGE_RESP(ThreeDReason) }

		switch -- $SAFECHARGE_RESP(ECI) {
			1 -
			6 {
				# Issuer is in the scheme but the
				# card holder is not enrolled
				ob_log::write INFO {$fn: Returning PMT_3DS_OK_DIRECT_AUTH}
				return PMT_3DS_OK_DIRECT_AUTH
			}
			7 {
				# If participating issuer, this means that the there was a problem
				# getting the the details.  May also be a non-participating issuer
				ob_log::write INFO {$fn: Returning PMT_3DS_NO_SUPPORT}
				return PMT_3DS_NO_SUPPORT
			}
			default {
				# Problem with the request.
				# We won't have liab protection so will have to make a
				# business decission as to whether to continue with
				# the payment
				ob_log::write INFO {$fn: error checking enrollment: ECI = $SAFECHARGE_RESP(ECI)}
				return PMT_3DS_NO_SUPPORT
			}
		}

	}

	#
	#  3D Secure processing - enrolement response parsing
	#
	set PMT(3d_secure,pareq) 	$SAFECHARGE_RESP(PaReq)
	set PMT(3d_secure,acs_url) 	$SAFECHARGE_RESP(ACSurl)

	ob_log::write INFO {$fn: Returning PMT_3DS_OK_REDIRECT}
	return PMT_3DS_OK_REDIRECT
}

# Format and send HTTPS Request
proc ob_safecharge::_send_request { ARRAY XML_ARRAY} {
	variable SAFECHARGE_DATA
	variable SAFECHARGE_CFG

	set fn "ob_safecharge::_send_request"
	upvar $ARRAY PMT
	upvar $XML_ARRAY XML

	set params [array get SAFECHARGE_DATA]

	# Create HTPP request
	if {[catch {
		set req [ob_socket::format_http_req \
		           -method     "POST" \
		           -form_args  $params \
				    $SAFECHARGE_CFG(host)]
	} msg]} {
		ob::log::write ERROR {$fn: Unable to build SafeCharge request: $msg}
		return ERR_SC_NOCONTACT
	}

	set masked_req [_mask_sensitive_info $req]
	ob::log::write INFO "$fn: HTTP Request is: $masked_req"

	# Decode Host URL
	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $SAFECHARGE_CFG(host)] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn: Bad SafeCharge URL: $msg}
		return ERR_SC_NOCONTACT
	}

	# Send the request to SafeCharge.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          "" \
		    -is_http      1 \
		    -conn_timeout $SAFECHARGE_CFG(conn_timeout) \
		    -req_timeout  $SAFECHARGE_CFG(resp_timeout) \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob::log::write ERROR {$fn: Unsure whether request reached SafeCharge:\
		                      send_req blew up with $msg}
		return ERR_SC_UNKNOWN
	}

	if {$status != "OK"} {
		# Is there a chance this request might actually have got to SafeCharge?
		if {[::ob_socket::server_processed $req_id]} {
			ob::log::write ERROR \
			  {$fn: Unsure whether request reached SafeCharge: status was $status}
			::ob_socket::clear_req $req_id
			return ERR_SC_UNKNOWN
		} else {
			ob::log::write ERROR \
			  {$fn: Unable to send request to SafeCharge: status was $status}
			::ob_socket::clear_req $req_id
			return ERR_SC_NOCONTACT
		}
	}

	set response [string trim [::ob_socket::req_info $req_id http_body]]
	::ob_socket::clear_req $req_id

	#parse_xml has an issue with &amp;
	regsub -all {&amp;} $response {\&} response

	ob_log::write INFO {$fn: SafeCharge XML Response Body: $response}
	parse_xml::parseBody $response
	upvar parse_xml::XML_RESPONSE XML2

	#TODO: THIS IS HACKY AND UGLY
	#but I cant get upvar working properly.
 	array set XML [array get XML2]
	#TODO: Remove this
	ob_log::write_array DEV XML

	return OK

}

proc ob_safecharge::make_call {ARRAY {enroll_3ds 0}} {

	variable INITIALISED
	variable SAFECHARGE_ERR_RESP
	variable SAFECHARGE
	variable SAFECHARGE_RESP_FIELDS
	variable SAFECHARGE_CFG
	variable SAFECHARGE_DATA
	variable SAFECHARGE_RESP

	if {!$INITIALISED} {
		init
	}

	# make sure data is cleared
	_reset

	set fn "ob_safecharge::make_call"
	upvar $ARRAY PMT

	# Setup SafeCharge Data
	if {![ob_safecharge::_setup_data PMT]} {
		ob_log::write ERROR {$fn: Failed to load necessary data}
		return PMT_ERR
	}

	# Setup Transaction Type
	switch $PMT(pay_sort) {
		"D" {
			set is_3ds 0
			if { $enroll_3ds && [info exists PMT(3d_secure)] && $PMT(3d_secure) } {
				if { [info exists PMT(3d_secure,policy,bypass_verify)] && $PMT(3d_secure,policy,bypass_verify) } {
					ob_log::write INFO {$fn: Bypassing 3DS}
					# SafeCharge has two accounts. One that does 3Ds and one that
					# does not. Since we are bypassing 3Ds, we need to load the
					# non 3Ds account information.
					_load_non_3ds_info PMT
				} else {
					# perform enrollment
					set is_3ds 1
				}
			}
			if { $is_3ds} {
				# Setup 3ds enrollment data
				ob_safecharge::_setup_data_Auth3D PMT
			} else  {
				# Possibly returning from 3ds redirect and completing the sale OR
				# Sending a normal non 3ds Sale request depending on PMT(req_type)
				ob_safecharge::_setup_data_Sale PMT
			}
		}
		"W" {
			ob_safecharge::_setup_data_Credit PMT
		}
		"V" {
			ob_safecharge::_setup_data_Void PMT
		}
		default {
			ob_log::write ERROR {$fn: Unrecognised payment sort - $PMT(pay_sort)}
			return PMT_TYPE
		}
	}

	# Send HTTPS Request
	set XML(0) ""
	set status [_send_request PMT XML]
	if {$status ne "OK"} {
		ob_log::write ERROR {$fn: Error Sending Request}
		return $status
	}

	# TODO: Remove?
	ob::log::write DEV  "$fn: XML Array:"
	ob_log::write_array DEV XML

	# Load Arrays with Response Data
	_parse_resp XML PMT

	# Gateway 3D-Secure Enrollment Response
	if {$SAFECHARGE_DATA(sg_TransType) == "Auth3D"} {
		return [_parse_auth3d_resp PMT]
	}

	set ret_code [ _parse_overall_response PMT]

	# Clear data arrays
	_reset

	return $ret_code
}


proc ob_safecharge::_parse_overall_response { ARRAY } {

	variable SAFECHARGE_RESP
	variable SAFECHARGE_ERR_RESP
	set ret_code OK

	set fn "ob_safecharge::_parse_overall_response"

	upvar $ARRAY PMT

	switch -- $SAFECHARGE_RESP(ErrCode) {
		0	{
			if { $SAFECHARGE_RESP(ExErrCode) == 0 } {
				set ret_code OK
			} else {
				set ret_code PMT_PENDING
			}
		}
		-1  {
			ob_log::write INFO {$fn: Payment Declined}

			if { [info exists SAFECHARGE_RESP(ThreeDReason)] } {
				set PMT(gw_ret_msg) $SAFECHARGE_RESP(ThreeDReason)
			}
			set ret_code $SAFECHARGE_ERR_RESP($SAFECHARGE_RESP(ExErrCode))
		}
		-1100 	{
			ob_log::write ERROR {$fn: Payment Error}
			# -1100 means error. Storing the ExErrCode as return code.
			if { [info exists SAFECHARGE_RESP(ExErrCode)] } {
				set PMT(gw_ret_code) $SAFECHARGE_RESP(ExErrCode)
			}

			set ret_code $SAFECHARGE_ERR_RESP($SAFECHARGE_RESP(ExErrCode))
		}
		-1001 {
			ob_log::write ERROR {$fn: Invalid Login}
			set ret_code $SAFECHARGE_ERR_RESP(-1001)
		}
		-1005 {
			ob_log::write ERROR {$fn: IP out of Range}
			set ret_code $SAFECHARGE_ERR_RESP(-1005)
		}
		-1203 {
			ob_log::write ERROR {$fn: Timeout / Retry}
			set ret_code $SAFECHARGE_ERR_RESP(-1203)
		}
		default {
			# shouldnt get here...
			ob_log::write INFO {$fn: Unknown return error code}
			set ret_code ERROR
		}
	}
	return $ret_code
}


proc ob_safecharge::_get_cvv2_status { cvv2_status {avs_code ""}} {

	set cvv2_ret ""
	set ret_avs  ""
	set ret_cvv2 ""

	set fn "ob_safecharge::_get_cvv2_status"

	switch -- $cvv2_status {
		"M" {
			set ret_cvv2 "CVV2 Match"
		}
		"N" {
			set ret_cvv2 "CVV2 No Match"
		}
		"P" {
			set ret_cvv2 "Not Processed"
		}
		"U" {
			set ret_cvv2 "Issuer is not certified and/or has not provided Visa the encryption keys"
		}
		"S" {
			set ret_cvv2 "CVV2 processor is unavailable."
		}
	}

	switch -- $avs_code {
		"A" {
			set ret_avs "The street address matches, the zip code does not"
		}
		"W" {
			set ret_avs "Whole 9-digits zip code match, the street address does not"
		}
		"Y" {
			set ret_avs "Both the 5-digits zip code and the street address match"
		}
		"X" {
			set ret_avs "An exact match of both the 9-digits zip code and the street address"
		}
		"Z" {
			set ret_avs "Only the 5-digits zip code match, the street code does not"
		}
		"U" {
			set ret_avs "Issuer is unavailable"
		}
		"S" {
			set ret_avs "Not Supported"
		}
		"R" {
			set ret_avs "Retry"
		}
		"B" {
			set ret_avs "Not authorized (declined)"
		}
		"N" {
			set ret_avs "Both street address and zip code do not match"
		}
	}

	if { $ret_avs == "" } {
		return $ret_cvv2
	} else {
		return "${ret_cvv2} | ${ret_avs}"
	}
}



#
# Masks information in the request string which shouldn't be logged
# such as the card number and the CV2 number.
#
proc ob_safecharge::_mask_sensitive_info {message} {

	# mask the card number to only show the card bin (first 6) and last 4 digits
	if {[regexp {sg_CardNumber=([0-9]*)} $message match card_num]} {

		# replace the digits with an 'X' except for the card bin and last 4
		set masked_num "[string range $card_num 0 5][string repeat "X" [expr {[string length $card_num] - 10}]][string range $card_num end-3 end]"

		# now put the masked version back in the message
		regsub $match $message "sg_CardNumber=$masked_num" message
	}

	# mask the CV2 number
	if {[regexp {sg_CVV2=([0-9]*)} $message match cv2_num]} {

		set masked_num "[string repeat "X" [string length $cv2_num]]"

		# now put the masked version back in the message
		regsub $match $message "sg_CVV2=$masked_num" message
	}

	# mask the SafeCharge password
	if {[regexp {sg_ClientPassword=([a-zA-Z0-9]*)} $message match clientPassword]} {

		# now put the masked version back in the message
		regsub $match $message "sg_ClientPassword=XXXXX" message
	}

	return $message
}
