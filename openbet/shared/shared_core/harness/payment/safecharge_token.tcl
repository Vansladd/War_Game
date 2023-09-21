# $Header$
# Copyright (C) 2013 OpenBet Technology Ltd. All Rights Reserved.
#
# SafeCharge Harness
#
# How to enable:
#    - add harness to auto_path:
#        $ export TCLLIBPATH="$OPENBETSHAREDDIR/shared_core/harness $TCLLIBPATH"
#    - enable harness in your app's configs:
#        SCTK_HARNESS_ENABLED = 1
#
set pkg_version 1.0
package provide core::harness::payment::SCTK $pkg_version

# Make template procs available to standalone scripts as well
load libOT_Template.so

# Dependencies
package require core::payment 1.0
package require core::log     1.0
package require core::args    1.0
package require core::check   1.0
package require core::stub    1.0
package require core::socket  1.0

core::args::register_ns \
	-namespace core::harness::payment::SCTK \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check \
		core::stub]


namespace eval core::harness::payment::SCTK  {
	variable CFG
	variable HARNESS_DATA

	# This creates dictionary:
	#    dict set HARNESS_DATA gateway data <code> type <type>
	#    dict set HARNESS_DATA gateway data <code> desc <desc>
	# To trigger the error, simply fill in amount that equals to the ex_err_code
	# All other values trigger successful transaction
	# code:
	#     > 800 < 900 - core::socket errors
	#     > 900 < 1000 - alternatives to specific safecharge errors
	#     > 1000 - error codes that SafeCharge returns
	foreach {code type desc} {
		801  {core::socket} {CONN_FAIL}
		802  {core::socket} {CONN_TIMEOUT}
		803  {core::socket} {HANDSHAKE_FAIL}
		901  {SC auth_code} {PENDING}
		902  {SC auth_code} {DECLINED}
		903  {SC error}     {Invalid Login}
		904  {SC error}     {Harness msg: Invalid Login - BSQ-11556}
		905  {SC error}     {IP out of range}
		906  {SC error}     {Timeout/Retry}
		907  {SC 3ds}       {Use 3d secure (success)}
		908  {SC 3ds}       {Use 3d secure (cancel)}
		909  {SC 3ds}       {Use 3d secure (error)}
		910  {SC 3ds}       {Payment does no need to get through 3DS redirection}
		1100 {SC error}     {Harness msg: Generic Eror ex_err_code = -1100}
		1001 {SC error}     {Invalid Expiration Date}
		1002 {SC error}     {Expiration Date Too Old}
		1101 {SC error}     {Invalid Card Number (Alpha Numeric)}
		1103 {SC error}     {Invalid Card Number (MOD 10)}
		1102 {SC error}     {Invalid Card Number (Digits Count)}
		1104 {SC error}     {Invalid CVV2}
		1161 {SC error}     {This Bank allows only 3 digits in CVV2}
		1105 {SC error}     {Auth Code/Trans Mismatch Number}
		1106 {SC error}     {Credit Amount Exceeds Total Charges}
		1107 {SC error}     {Cannot Credit this CC company}
		1108 {SC error}     {Illegal interval between Auth and Settle}
		1109 {SC error}     {Not allowed to process this CC company}
		1110 {SC error}     {Unrecognized CC company}
		1113 {SC error}     {Terminal is not configured to work with this CC company}
		1118 {SC error}     {'N' Cannot be a Positive CVV2 Reply}
		1119 {SC error}     {'B'/'N' Cannot be a Positive AVS Reply}
		1121 {SC error}     {CVV2 check is not allowed in  Credit/Settle/Void}
		1122 {SC error}     {AVS check is not allowed in Credit/Settle/Void}
		1124 {SC error}     {Credits total amount exceeds restriction}
		1125 {SC error}     {Format Error}
		1126 {SC error}     {Credit amount exceeds ceiling}
		1127 {SC error}     {Limit exceeding amount}
		1128 {SC error}     {Invalid Transaction Type Code}
		1129 {SC error}     {General Filter Error}
		1134 {SC error}     {AVS Processor Error}
		1135 {SC error}     {Only one credit per sale is allowed}
		1137 {SC error}     {Credit count exceeded CCC restriction}
		1138 {SC error}     {Invalid Credit Type}
		1139 {SC error}     {This card is not supported in the CFT Program}
		1140 {SC error}     {Card must be processed in the GW System}
		1141 {SC error}     {Transaction type is not allowed}
		1142 {SC error}     {AVS required fields are missing or incorrect}
		1143 {SC error}     {Country does not match ISO Code}
		1144 {SC error}     {Must provide transaction}
		1145 {SC error}     {Your Rebill profile does not support this ID/CC UserID in a Rebill}
		1146 {SC error}     {Void is not allowed due to CC restriction}
		1147 {SC error}     {Invalid Account Number}
		1148 {SC error}     {Invalid Cheque Number}
		1149 {SC error}     {Account Number/Trans ID Mismatch}
		1150 {SC error}     {UserID/Trans Type /Trans ID Mismatch}
		1151 {SC error}     {Transaction does not exist in the rebill system.}
		1152 {SC error}     {Transaction was already canceled}
		1153 {SC error}     {Invalid Bank Code (Digits Count)}
		1154 {SC error}     {Invalid Bank Code (Alpha Numeric)}
		1155 {SC error}     {VBV-Related transaction is missing or incorrect}
		1156 {SC error}     {Debit card required fields are missing or incorrect}
		1157 {SC error}     {No updated parameters were supplied}
		1158 {SC error}     {VBV PaRes value is incorrect}
		1159 {SC error}     {State does not match ISO Code}
		1160 {SC error}     {Invalid Bank Code (Checksum Digit)}
		1162 {SC error}     {Age verification Failed}
		1163 {SC error}     {Transaction must number/Token}
		1164 {SC error}     {Invalid Token}
		1165 {SC error}     {Token Mismatch}
		1166 {SC error}     {Invalid Email address}
		1169 {SC error}     {sg_ResponseFormat field is not valid}
		1170 {SC error}     {Version field is missing or incorrect}
		1171 {SC error}     {Issuing Country is invalid}
		1172 {SC error}     {Phone is missing or format error}
		1173 {SC error}     {Check number is missing or incorrect}
		1174 {SC error}     {Birth date format error}
		1175 {SC error}     {Zip code format error}
		1176 {SC error}     {Cannot void an auth transaction}
		1177 {SC error}     {Can't Void a Credit Transaction must be 3D}
		1178 {SC error}     {Cannot void a void transaction}
		1179 {SC error}     {Cannot perform this void}
		1181 {SC error}     {Merchant Name is too long (>25)}
		1182 {SC error}     {Transaction must be send as 3Dsecure}
		1183 {SC error}     {Account is not 3D enabled}
		1184 {SC error}     {Transaction 3D status is incorrect contain a Card}
		1185 {SC error}     {Related transaction must be of type 'AUTH3D'}
		1186 {SC error}     {Related transaction authenticated}
		1187 {SC error}     {Country does not support CFT program}
		1111 {SC error}     {This Transaction was charged back}
		1112 {SC error}     {Sale/Settle was already credited}
		1114 {SC error}     {Blocked (Black-listed) card number}
		1115 {SC error}     {Illegal BIN number}
		1131 {SC error}     {This transaction type is not allowed for this bank}
		1116 {SC error}     {Custom Fraud Screen Filter}
		1120 {SC error}     {Invalid AVS}
		1130 {SC error}     {Bank required fields are missing or incorrect}
		1133 {SC error}     {GW required fields are missing}
		1136 {SC error}     {Mandatory fields are missing}
		1132 {SC error}     {Amount exceeds bank limit}
		1167 {SC error}     {Transaction already settled}
		1168 {SC error}     {Transaction already voided}
		1180 {SC error}     {Invalid start date}
		1201 {SC error}     {Invalid Amount}
		1202 {SC error}     {Invalid Curency}
	} {
		dict set HARNESS_DATA gateway data $code type $type
		dict set HARNESS_DATA gateway data $code desc $desc
	}

	# Example request:
	# sg_TransType=Auth
	# &sg_ResponseFormat=4
	# &sg_Version=4%2e0%2e2
	# &sg_Currency=GBP
	# &sg_ClientLoginID=OpenBetTestTRX
	# &sg_ClientPassword=rcJ3mYwC4N
	# &sg_ClientUniqueID=14
	# &sg_CCToken=RwBVAFAAUABlADQAVQA1AE4ATwBRADYAcAB3ACMARgBvACwAeQB0ADEATwBnAEYAVwBjADoAcABOAGcARwArADAANQBwAFcAewBvAFYAaQBcAD4AMwA%3d
	# &sg_ExpMonth=08
	# &sg_ExpYear=30
	# &sg_NameOnCard=afsd+fdsa
	# &sg_FirstName=afsd
	# &sg_LastName=fdsa
	# &sg_Address=1259898
	# &sg_City=sdfa
	# &sg_Zip=w45xt
	# &sg_Country=GB
	# &sg_Phone=0231456789
	# &sg_Email=asfd%40fdsa%2esd
	# &sg_Amount=10%2e00
	# &sg_IPAddress=10%2e194%2e11%2e158
	# &sg_UserID=1

	# Response template
	dict set HARNESS_DATA gateway template {
		<Response>
			<Version>4.0.2</Version>
			<ClientLoginID>##TP_client_login_id##</ClientLoginID>
			<ClientUniqueID>##TP_client_unique_id##</ClientUniqueID>
			<TransactionID>##TP_transaction_id##</TransactionID>
			<Status>##TP_status##</Status>
			<AuthCode>##TP_auth_code##</AuthCode>
			##TP_COMMENT Empty when an AVSOnly request was not submitted (otherwise A|W|Y|X|Z|U|R|B|N)##
			<AVSCode></AVSCode>
			##TP_COMMENT Empty for current implementation otherwise M|N|P|U|S ##
			<CVV2Reply>##TP_cvv2_reply##</CVV2Reply>
			<ReasonCodes>
				<Reason code="##TP_reason_code##">##TP_reason##</Reason>
			</ReasonCodes>
			<ErrCode>##TP_err_code##</ErrCode>
			<ExErrCode>##TP_ex_err_code##</ExErrCode>
			<Token>##TP_token##</Token>
			<CustomData>##TP_custom_data##</CustomData>
			##TP_IF {[tpGetVar 3ds_error 0]}##
				<ECI>##TP_eci_value##</ECI>
				<ThreeDReason>##TP_three_d_reason##</ThreeDReason>
			##TP_ENDIF##
			<AcquirerID>10</AcquirerID>
			##TP_COMMENT Never seen this being filled in: Alphanumeric. Maximum length is limited to 125 characters.##
			<IssuerBankName></IssuerBankName>
			##TP_COMMENT Never seen this being filled in: 2 character country ISO code. (ZZ == bank BIN not analysed by SC yet).##
			<IssuerBankCountry></IssuerBankCountry>
			##TP_COMMENT Empty (Reserved field).##
			<Reference></Reference>
			##TP_COMMENT Empty (For clients who uses the age verification service).##
			<AGVCode></AGVCode>
			##TP_COMMENT Empty (For clients who uses the age verification service).##
			<AGVError></AGVError>
			<UniqueCC>##TP_unique_cc##</UniqueCC>
			##TP_IF {[tpGetVar 3ds_enabled 0]}##
				<ThreeDFlow>##TP_three_d_flow##</ThreeDFlow>
				##TP_IF {[tpGetVar is_3d_flow  0]}##
					<PaReq>##TP_pareq##</PaReq>
					<MerchantID>##TP_merchant_id##</MerchantID>
					<ACSurl>##TP_acs_url##</ACSurl>
				##TP_ENDIF##
			##TP_ENDIF##

		</Response>
	}
}

core::args::register \
	-proc_name core::harness::payment::SCTK::expose_magic \
	-desc {Provides magic data details to the documentation generator} \
	-body {
		variable HARNESS_DATA
		set fn {core::harness::payment::SCTK::expose_magic}
		set i 0

		set MAGIC(0,header) {CVV2 Number}
		set MAGIC(1,header) {Type}
		set MAGIC(2,header) {Response}

		foreach request_type [dict keys $HARNESS_DATA] {
			set MAGIC($i,request_type) "$request_type"
			set j 0

			foreach {key val} [dict get $HARNESS_DATA $request_type data] {
				set MAGIC($i,$j,0,column) $key
				set MAGIC($i,$j,1,column) [dict get $HARNESS_DATA $request_type data $key type]
				set MAGIC($i,$j,2,column) [dict get $HARNESS_DATA $request_type data $key desc]
				incr j
			}

			set MAGIC($i,num_rows) $j
			incr i
		}

		set MAGIC(num_requests) $i
		set MAGIC(num_columns)  3

		return [array get MAGIC]
	}

#
# Register SCTK harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::payment::SCTK::init \
	-desc {Prepares queries, stubs core::socket} \
	-args [list \
		[list -arg -enabled -mand 0 -check BOOL  -default_cfg SCTK_HARNESS_ENABLED -default 0  -desc {Enable the SafeCharge harness}] \
		[list -arg -ppp_url -mand 0 -check ASCII -default_cfg SCTK_PPP_URL         -default {} -desc {Override PPP url to redirect to the Redirect Harness}] \
		[list -arg -acs_url -mand 0 -check ASCII -default_cfg SCTK_ACS_URL         -default {} -desc {Override ACS url received from Safecharge in 3ds case}] \
	] \
	-body {
		variable CFG

		set fn {core::harness::payment::SCTK::init}

		core::stub::init

		if {!$ARGS(-enabled)} {
			core::log::write WARNING {$fn: SafeCharge Harness available though disabled}
			return
		}
		core::log::write INFO {$fn: SafeCharge Harness enabled}

		set CFG(acs_url) $ARGS(-acs_url)

		core::harness::payment::SCTK::_prepare_queries

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				core::socket  send_req \
				core::socket  req_info \
				core::socket  clear_req \
				core::control get \
		]

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_deposit} \
			-use_body_return 1 \
			-body {
				# args is a list of arguments passed to send_req
				foreach {key val} $args {
					switch $key {
						-req {set req $val}
					}
				}
				return [core::harness::payment::SCTK::_process_request -request $req]
			}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::complete_deposit} \
			-use_body_return 1 \
			-body {
				#args is a list of arguments passed to send_req
				foreach {key val} $args {
					switch $key {
						-req    {set req $val}
					}
				}
				return [core::harness::payment::SCTK::_process_request -request $req]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_deposit} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::SCTK::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::complete_deposit} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::SCTK::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_deposit} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::complete_deposit} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_withdrawal} \
			-body {
				# args is a list of arguments passed to send_req
				foreach {key val} $args {
					switch $key {
						-req {set req $val}
					}
				}
				return [core::harness::payment::SCTK::_process_request -request $req]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_withdrawal} \
			-body {
				set ret [core::harness::payment::SCTK::_get_response]
				return $ret
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::make_withdrawal} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::fulfill_pmt} \
			-body {
				# args is a list of arguments passed to send_req
				foreach {key val} $args {
					switch $key {
						-req {set req $val}
					}
				}
				return [core::harness::payment::SCTK::_process_request -request $req]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::fulfill_pmt} \
			-body {
				return [core::harness::payment::SCTK::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::SCTK::fulfill_pmt} \
			-return_data     {}

		if {[string length $ARGS(-ppp_url)] > 0} {
			core::log::write INFO {$fn: stubbing STCK_PPP_URL: $CFG(ppp_url)}

			core::stub::set_override \
				-proc_name   {core::control::get} \
				-arg_list    [list -name SCTK_PPP_URL] \
				-scope       proc \
				-scope_key   {::core::payment::SCTK::insert_cpm} \
				-return_data $ARGS(-ppp_url)
		}
	}


core::args::register \
	-proc_name {core::harness::payment::SCTK::_process_request} \
	-desc      {} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA
		set fn {core::harness::payment::SCTK::_process_request}

		core::log::write DEV {$fn: $ARGS(-request)}

		# sg_CustomData is optional
		dict set HARNESS_DATA request custom_data {}

		set ldata [list]
		foreach row [split $ARGS(-request) "\n"] {
			if {[regexp {^sg_.*} $row]} {
				set ldata [split $row {=&}]
				break
			}
		}

		if {[llength $ldata] == 0} {
			core::log::write ERROR {$fn: no data detected - returning CONN_FAIL}
			return [list 0 CONN_FAIL 1]
		}

		set check_cvv2 0
		foreach {key val} $ldata {
			set val [urldecode $val]
			switch $key {
				sg_ClientLoginID  {dict set HARNESS_DATA request client_login_id  $val}
				sg_ClientUniqueID {dict set HARNESS_DATA request client_unique_id $val}
				sg_CustomData     {dict set HARNESS_DATA request custom_data      $val}
				sg_CVV2           {
					dict set HARNESS_DATA request cvv2 $val
					set check_cvv2 $val
				}
				sg_TransType      {
					if {$val == "Sale3D"} {
						dict set HARNESS_DATA request is_sale_3d 1
					} else {
						dict set HARNESS_DATA request is_sale_3d 0
					}
				}
			}
		}

		if {![dict exists $HARNESS_DATA request client_unique_id]} {
			core::log::write ERROR {$fn: no client_unique_id detected - returning CONN_FAIL}
			return [list 0 CONN_FAIL 1]
		}

		set status OK
		switch $check_cvv2 {
			801  {set status CONN_FAIL}
			802  {set status CONN_TIMEOUT}
			803  {set status HANDSHAKE_FAIL}
		}
		return [list 1 $status 1]
	}


core::args::register \
	-proc_name {core::harness::payment::SCTK::_get_response} \
	-desc      {Get the prepared response data} \
	-body {
		variable HARNESS_DATA
		variable CFG
		set fn {core::harness::payment::SCTK::_get_response}

		core::log::write DEV {$fn}

		set pmt_id [dict get $HARNESS_DATA request client_unique_id]

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::harness::payment::SCTK::get_cpm_detail \
				-args [list $pmt_id]]
		} msg]} {
			core::log::write ERROR {$fn: Error in get_cpm_detail: $msg}
			# SCTK implementation will take care of invalid XML, so we can return this.
			return "$fn: Error in get_cpm_detail: $msg"
		}

		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			core::log::write ERROR {$fn: No cpm returned.}
			core::db::rs_close -rs  $rs
			# SCTK implementation will take care of invalid XML, so we can return this.
			return "$fn: No cpm returned."
		}

		# Some fields we read from the db
		tpBindString token               [db_get_col $rs 0 sc_unique_token]
		tpBindString unique_cc           [db_get_col $rs 0 sc_unique_cc]
		core::db::rs_close -rs  $rs

		# Some fields have to have the same value as in the request
		tpBindString client_login_id     [dict get $HARNESS_DATA request client_login_id]
		tpBindString client_unique_id    [dict get $HARNESS_DATA request client_unique_id]
		tpBindString custom_data         [dict get $HARNESS_DATA request custom_data]

		# TransactionID A 32-bit unique integer ID generated by the Gateway,
		set transaction_id               [string range [clock milliseconds] 3 end]
		tpBindString transaction_id      $transaction_id

		if {[dict exist $HARNESS_DATA request cvv2]} {
			set check_cvv2 [dict get $HARNESS_DATA request cvv2]
			set result [core::harness::payment::SCTK::_resolve_magic_values\
				-cvv2         $check_cvv2\
				-transaction_id $transaction_id]

			set cvv2_err_code_val "M"
			if {$check_cvv2 == 1104 || $check_cvv2 == 1118 || $check_cvv2 == 1161} {
				set cvv2_from_err_code_val "N"
			}
			set merchant_id 738728722
			if {$check_cvv2 == 908} {
				set merchant_id 1000
			} elseif {$check_cvv2 == 909} {
				set merchant_id 2000
			}

			tpBindString cvv2_reply  $cvv2_err_code_val
		} else {
			# We get in this case when we try to stub core::socket::req_info
			# when it in scope of core::payment::SCTK::complete_deposit.
			# We set the cvv2 value to 916 just to have a dummy value
			# in order to return ECI code in the complete deposit case.
			dict set HARNESS_DATA request cvv2 916
			set result [core::harness::payment::SCTK::_resolve_magic_values \
				-cvv2           916 \
				-transaction_id $transaction_id]

			core::harness::payment::SCTK::_add_3ds_elements
		}

		tpBindString status              [dict get $result status]
		# An authorization code (up to 35 chars) returned  for each approved or pending transaction.
		tpBindString auth_code           [dict get $result auth_code]
		tpBindString reason_code         [dict get $result reason_code]
		tpBindString reason              [dict get $result reason]
		tpBindString err_code            [dict get $result err_code]
		tpBindString ex_err_code         [dict get $result ex_err_code]

		set is_sale_3d [dict get $HARNESS_DATA request is_sale_3d]
		if {$is_sale_3d} {
			core::harness::payment::SCTK::_add_3ds_elements
		}

		return [tpStringPlay -tostring [dict get $HARNESS_DATA gateway template]]
	}


core::args::register \
	-proc_name {core::harness::payment::SCTK::_add_3ds_elements} \
	-desc      {Add 3ds elements in response xml} \
	-body      {
		variable HARNESS_DATA
		variable CFG
		set fn {core::harness::payment::SCTK::_add_3ds_elements}

		core::log::write DEV {$fn}

		set transaction_id  [string range [clock milliseconds] 3 end]
		set check_cvv2      [dict get $HARNESS_DATA request cvv2]
		set result [core::harness::payment::SCTK::_resolve_magic_values\
			-cvv2         $check_cvv2\
			-transaction_id $transaction_id]

		set merchant_id 738728722
		if {$check_cvv2 == 908} {
			set merchant_id 1000
		} elseif {$check_cvv2 == 909} {
			set merchant_id 2000
		}

		set pareq_val [join [list \
			"eJxVUctuwjAQ/JWIK1LsvAqNNpZSEA8BLS1UhWMwFolC4sR2Wvj7" \
			"2jQpreTDzuzueDQL21QwNt4w2ghGYMWkTE7Myo5Rr5AnO+gRWMdv" \
			"rCbwyYTMeEkcG9suoA7qFUHTpFQEElo/zZ+J5/l+EABqIRRMzMdk" \
			"4A0Hrn569YeAMikYiQXlytoyqaxOCNCtA5Q3pRJXMvQxoA5AI84k" \
			"VaoKETpzmpxTLvWGYQHdrawbU0mtcsmOZBnM+rTm02Xu9i+5XOXX" \
			"/mLyGk/j+D0CZCbgmChGXIwH+AF7luOH+DHEQ0A3HpLCfE8CG2sr" \
			"LYDK/BG3HdP4S4DOU7CSdvY7BOxS8ZLpCR3Ebw3obngM0lSpSPyP" \
			"vguraYHNKqz3WGxmbzs8/1XFJlsbwNGLdOpOI7x2gJARgK1Z0PtS" \
			"XX179TffiaoOQ=="] ""]

		tpBindString   three_d_flow   [dict get $result three_d_flow]
		tpSetVar       3ds_enabled    [dict get $result 3ds_enabled]
		tpSetVar       is_3d_flow     0

		switch $check_cvv2 {
			908 {
				tpSetVar       3ds_error      1
				tpBindString   eci_value      7
				tpBindString   three_d_reason "Error In 3DSecure Processing"
			}
			909 {
				tpSetVar       3ds_error      1
				tpBindString   eci_value      6
				tpBindString   three_d_reason "Attempted But Card Not Enrolled"
			}
			911 {
				tpSetVar       3ds_error      1
				tpBindString   eci_value      7
				tpBindString   three_d_reason "Card Not Eligible"
				tpBindString   reason_code    0
				tpBindString   reason         "Card Not Eligible"
			}
			912 -
			913 -
			914 {
				tpSetVar       3ds_enabled    0
				tpSetVar       3ds_error      1
				tpBindString   eci_value      7
				tpBindString   three_d_reason ""
			}
			916 {
				tpSetVar       3ds_enabled    0
				tpSetVar       3ds_error      1
				tpBindString   eci_value      2
				tpBindString   three_d_reason ""
			}
			default {
				tpSetVar       is_3d_flow     1
				tpBindString   acs_url        $CFG(acs_url)
				tpBindString   merchant_id    $merchant_id
				tpBindString   pareq          $pareq_val
			}
		}

		return 1
	}


core::args::register \
	-proc_name {core::harness::payment::SCTK::_resolve_magic_values} \
	-desc      {} \
	-args      [list \
		[list -arg -cvv2     -mand 1 -check DECIMAL -desc {Cvv2 number to be resolved}] \
		[list -arg -transaction_id -mand 1 -check DECIMAL -desc {Transaction ID}] \
	] \
	-body {
		variable HARNESS_DATA
		set fn {core::harness::payment::SCTK::_resolve_magic_values}

		core::log::write DEV {$fn: cvv2: $ARGS(-cvv2)}

		set cvv2 [expr {int($ARGS(-cvv2))}]

		dict set result auth_code   {}
		dict set result reason_code {0}
		dict set result reason      {}
		dict set result 3ds_enabled {1}
		dict set result three_d_flow {0}

		# Values: 800 < $cvv2 < 900 is reserved for errors coming out of send_req
		# and therefore is dealt with in the _process_request proc.

		if {$cvv2 == -1100} {
			# Generic error
			dict set result status      {ERROR}
			dict set result err_code    -1100
			dict set result ex_err_code -1100
		} elseif {$cvv2 > 1000 && [dict exists $HARNESS_DATA gateway data $cvv2]} {
			# Filter errors
			dict set result status      {ERROR}
			dict set result reason_code $cvv2
			dict set result err_code    -1100
			dict set result ex_err_code $cvv2
			if {$cvv2 == 1116} {
				dict set result reason  [format\
					{TRANSID=%d TRANSREC=D TRANSSCORE=0TRANSREASONAMOUNT=1 TRANSREASON1=4}\
					$ARGS(-transaction_id)]
			} else {
				dict set result reason  [dict get $HARNESS_DATA gateway data $cvv2 desc]
			}
		} else {
			# Specific cases
			switch $cvv2 {
				901 {
					dict set result auth_code   [OT_UniqueId]
					dict set result status      {PENDING}
					dict set result err_code    0
					dict set result ex_err_code -2
				}
				902 {
					dict set result status      {DECLINED}
					dict set result err_code    -1
					dict set result ex_err_code 0
				}
				903 {
					dict set result status      {ERROR}
					dict set result reason      [dict get $HARNESS_DATA gateway data $cvv2 desc]
					dict set result err_code    -1001
					dict set result ex_err_code 0
				}
				904 {
					dict set result status      {ERROR}
					dict set result reason      [dict get $HARNESS_DATA gateway data $cvv2 desc]
					dict set result err_code    -1100
					dict set result ex_err_code 0
				}
				905 {
					dict set result status      {ERROR}
					dict set result reason      [dict get $HARNESS_DATA gateway data $cvv2 desc]
					dict set result err_code    -1005
					dict set result ex_err_code 0
				}
				906 {
					dict set result status      {ERROR}
					dict set result reason      [dict get $HARNESS_DATA gateway data $cvv2 desc]
					dict set result err_code    -1203
					dict set result ex_err_code 0
				}
				907 {
					# 3DS redirect required
					dict set result status      {APPROVED}
					dict set result reason      {}
					dict set result err_code    0
					dict set result ex_err_code 0

					# It is a little bit agly to have such a
					# variable here; however, this way, all
					# decisions about the responce values
					# are made in this proc.
					# We use 907 to return success from 3ds
					dict set result three_d_flow 1
					dict set result 3ds_enabled  1
				}
				908 -
				909 -
				911 {
					# 908 : error in 3DS processing
					# 909 : 3ds card not enrolled
					# 911 : 3ds card not eligible

					dict set result status       {APPROVED}
					dict set result reason       {}
					dict set result three_d_flow 1
					dict set result 3ds_enabled  0
					dict set result err_code     0
					dict set result ex_err_code  0
				}
				910 {
					# 3ds flow not needed

					dict set result status       {APPROVED}
					dict set result reason       {}
					dict set result three_d_flow 0
					dict set result 3ds_enabled  1
					dict set result err_code     0
					dict set result ex_err_code  0
				}
				912 -
				913 -
				914 {
					# 912 : Authentication failure
					# 913 : Authentication Not Available
					# 914 : Invalid PaRes

					dict set result status       {APPROVED}
					dict set result reason       {}
					dict set result three_d_flow 1
					dict set result 3ds_enabled  0
					dict set result err_code     -1
					dict set result ex_err_code  0
				}
				915 {
					# 3ds success

					dict set result status       {APPROVED}
					dict set result reason       {}
					dict set result three_d_flow 1
					dict set result 3ds_enabled  1
					dict set result err_code     0
					dict set result ex_err_code  0
				}
				default {
					dict set result three_d_flow 0
					dict set result auth_code   [OT_UniqueId]
					dict set result status      {APPROVED}
					dict set result err_code    0
					dict set result ex_err_code 0
				}
			}
		}

		core::log::write DEV {$fn: result: $result}

		return $result
	}


core::args::register \
	-proc_name {core::harness::payment::SCTK::_prepare_queries} \
	-desc      {Prepare database queries needed by the harness} \
	-body {

		core::db::store_qry \
			-name {core::harness::payment::SCTK::get_cpm_detail} \
			-qry  {
				select
					cs.sc_unique_token,
					cs.sc_unique_cc
				from
					tPmt   p,
					tCPMSC cs
				where
					p.pmt_id     = ?
					and p.cpm_id = cs.cpm_id
			}
	}


#
# This proc is called by the Redirect Harness.
# List of input arguments matches the one of DMN Processor default_action handler
# except for:
#     secret_key      : SC Secret Key as normally stored in tPmtGateAcct
#     dmn_url         : DMN Processor endpoint URL
#     dmn_port        : DMN Processor port
#     dmn_conn_timeout: DMN Processor connection timeout
#     dmn_req_timeout : DMN Processor request timeout
#
core::args::register \
	-proc_name {core::harness::payment::SCTK::do_redirect_callback} \
	-desc      {Called by the Redirect Harness (appserv application).} \
	-args      [list \
		[list -arg -ppp_status          -mand 1 -check {EXACT -args {OK FAIL}}                                 -desc {PPP Status}] \
		[list -arg -ppp_transaction_id  -mand 1 -check UINT                                                    -desc {Transaction ID}] \
		[list -arg -total_amount        -mand 1 -check MONEY                                                   -desc {Deposited Amount}] \
		[list -arg -currency            -mand 1 -check Az                                                      -desc {Currency}] \
		[list -arg -status              -mand 1 -check {EXACT -args {APPROVED SUCCESS DECLINED ERROR PENDING}} -desc {Transaction Status}] \
		[list -arg -merchant_site_id    -mand 1 -check ALNUM                                                   -desc {Merchant Site ID}] \
		[list -arg -request_version     -mand 1 -check {EXACT -args {1.0.0 3.0.0}}                             -desc {SC API Version}] \
		[list -arg -message             -mand 1 -check ASCII                                                   -desc {Message}] \
		[list -arg -payment_method      -mand 1 -check ASCII                                                   -desc {Pay Method}] \
		[list -arg -merchant_id         -mand 1 -check UINT                                                    -desc {Merchant ID}] \
		[list -arg -response_time_stamp -mand 1 -check NONE                                                    -desc {Transaction Date Time}] \
		[list -arg -dynamic_descriptor  -mand 1 -check ASCII                                                   -desc {Dynamic Descriptor}] \
		[list -arg -item_name_1         -mand 1 -check ASCII                                                   -desc {Bought Item Name}] \
		[list -arg -item_amount_1       -mand 1 -check MONEY                                                   -desc {Bought Item Amount}] \
		[list -arg -client_ip           -mand 1 -check IPADDR                                                  -desc {Client's IP}] \
		[list -arg -merchant_unique_id  -mand 1 -check UINT                                                    -desc {Merchant Unique ID}] \
		[list -arg -exp_month           -mand 1 -check {RE -args {^(0[1-9]|1[0-2])$}}                          -desc {Expiry Month}] \
		[list -arg -exp_year            -mand 1 -check {RE -args {^\d{2}$}}                                    -desc {Expiry Year}] \
		[list -arg -name_on_card        -mand 1 -check ASCII                                                   -desc {Cardholder's name}] \
		[list -arg -card_number         -mand 1 -check {RE -args {^\d{1}\*{4}\d{4}$}}                          -desc {Card Number containing stars}] \
		[list -arg -err_code            -mand 1 -check INT                                                     -desc {Error Code}] \
		[list -arg -ex_err_code         -mand 1 -check INT                                                     -desc {Extended Error Code}] \
		[list -arg -reason              -mand 0 -check ASCII -default {}                                       -desc {Decline Reason}] \
		[list -arg -token               -mand 1 -check ANY                                                     -desc {Token}] \
		[list -arg -unique_cc           -mand 1 -check ANY                                                     -desc {Unique Card Identification}] \
		[list -arg -bin                 -mand 1 -check {RE -args {^\d{6}$}}                                    -desc {Card BIN}] \
		[list -arg -secret_key          -mand 1 -check ANY                                                     -desc {SC Secret Key as normally stored in tPmtGateAcct}] \
		[list -arg -dmn_url             -mand 1 -check ANY                                                     -desc {DMN Processor endpoint URL}] \
		[list -arg -dmn_port            -mand 0 -check INT -default 443                                        -desc {DMN Processor port}] \
		[list -arg -dmn_conn_timeout    -mand 0 -check INT -default 10000                                      -desc {DMN Processor connection timeout}] \
		[list -arg -dmn_req_timeout     -mand 0 -check INT -default 10000                                      -desc {DMN Processor request timeout}] \
	] \
	-body {
		variable CFG

		set fn  {core::harness::payment::SCTK::do_redirect_callback}
		set tls 1

		core::log::write       DEV {$fn: args array follows.}
		core::log::write_array DEV ARGS

		set checksum_fields [join [list\
			$ARGS(-secret_key) \
			$ARGS(-total_amount) \
			$ARGS(-currency) \
			$ARGS(-response_time_stamp) \
			$ARGS(-ppp_transaction_id) \
			$ARGS(-status) \
			$ARGS(-item_name_1)] \
			{}]

		set advanceResponseChecksum [md5 $checksum_fields]

		set post_data [list \
			advanceResponseChecksum $advanceResponseChecksum \
			ppp_status              $ARGS(-ppp_status) \
			PPP_TransactionID       $ARGS(-ppp_transaction_id) \
			totalAmount             $ARGS(-total_amount) \
			currency                $ARGS(-currency) \
			Status                  $ARGS(-status) \
			merchant_site_id        $ARGS(-merchant_site_id) \
			requestVersion          $ARGS(-request_version) \
			message                 $ARGS(-message) \
			payment_method          $ARGS(-payment_method) \
			merchant_id             $ARGS(-merchant_id) \
			responseTimeStamp       $ARGS(-response_time_stamp) \
			dynamicDescriptor       $ARGS(-dynamic_descriptor) \
			item_name_1             $ARGS(-item_name_1) \
			item_amount_1           $ARGS(-item_amount_1) \
			client_ip               $ARGS(-client_ip) \
			merchant_unique_id      $ARGS(-merchant_unique_id) \
			expMonth                $ARGS(-exp_month) \
			expYear                 $ARGS(-exp_year) \
			nameOnCard              $ARGS(-name_on_card) \
			cardNumber              $ARGS(-card_number) \
			ErrCode                 $ARGS(-err_code) \
			ExErrCode               $ARGS(-ex_err_code) \
			Reason                  $ARGS(-reason) \
			Token                   $ARGS(-token) \
			uniqueCC                $ARGS(-unique_cc) \
			bin                     $ARGS(-bin)]

		if {[catch {
			foreach {api_scheme api_host api_port api_urlpath api_username api_password} \
				[core::socket::split_url -url $ARGS(-dmn_url)] {break}
		} msg]} {
			core::log::write ERROR {$fn: Bad API URL: $msg}
			return [list 0 ERR_SC_BAD_URL $msg]
		}

		# Construct the raw HTTP request.
		if {[catch {
			set req [core::socket::format_http_req \
				-host       $api_host \
				-method     "POST" \
				-form_args  $post_data \
				-url        $ARGS(-dmn_url)]
		} msg]} {
			core::log::write ERROR {$fn: Bad request: $msg}
			return [list 0 ERR_SC_BAD_REQ $msg]
		}

		core::log::write DEV {$fn: request: $req}

		# Cater for the unlikely case that we're not using HTTPS.
		if {$api_scheme == "http"} {
			set tls -1
		}

		if {[catch {
			foreach {req_id status complete} \
				[core::socket::send_req \
					-tls          $tls \
					-is_http      1 \
					-conn_timeout $ARGS(-dmn_conn_timeout) \
					-req_timeout  $ARGS(-dmn_req_timeout) \
					-req          $req \
					-host         $api_host \
					-port         $ARGS(-dmn_port) \
				] {break}
			} msg]} {
			# We can't be sure if anything reached the server or not.
			core::log::write ERROR {$fn: send_req failed: $msg}
			return [list 0 "HTTP_ERROR" $msg]
		}

		# If we receive anything else than OK, return error. Handling code will
		# in most cases set payment status to "U" and the payment will be taken
		# care of manually by operators or by the Pmt Scratcher app
		if {$status != "OK"} {
			core::log::write ERROR {$fn: Bad response, status was: $status}
			core::socket::clear_req -req_id $req_id
			return [list 0 $status]
		}

		# Request successful - get and return the response data.
		set res_body [core::socket::req_info -req_id $req_id -item http_body]

		core::socket::clear_req -req_id $req_id

		set return_value [list 1 $res_body]

		core::log::write DEV {$fn: done: $return_value}
		return $return_value
	}
