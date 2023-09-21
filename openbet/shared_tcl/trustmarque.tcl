package require tls 1.4
package require http 2.3

# $Id: trustmarque.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $

http::register https 443 tls::socket

namespace eval trustmarque {

	namespace export trustmarque_init
	namespace export make_trustmarque_call

	variable RES
	variable TRUSTDAT
	variable ISO_CURR
	variable IS_TEST
	variable TMARQUE_INITIALISED 0

}

proc trustmarque::trustmarque_init {} {

	variable ISO_CURR
	variable TRUSTDAT
	variable ERR_CODES
	variable MSG_CODES
	variable IS_TEST
	variable TMARQUE_INITIALISED

	# Check if already initialised as there can be two payment gateways
	# Trustmarque Payback and Trustmarque PaymentTrust
	if {$TMARQUE_INITIALISED} {
		return
	}

	set IS_TEST [OT_CfgGetTrue TMARQUE_ISTEST]

	global SHARED_SQL

	log 5 {<== trustmarque_init}

	if {![info exists SHARED_SQL(pmt_cust_detail)]} {
		set SHARED_SQL(pmt_cust_detail) {
			select
				r.fname,
				r.lname,
				r.email,
				r.telephone,
				r.addr_street_1,
				r.addr_street_2,
				r.addr_street_3,
				r.addr_street_4,
				r.addr_city,
				r.addr_postcode,
				c.country_code
			FROM
				tCustomer c,
				tCustomerReg r
			WHERE
				c.cust_id = ? and
				c.cust_id = r.cust_id
		}
	}

	set SHARED_SQL(tmarque_mop) {

		select
			DECODE(s.scheme,'SWCH','DS','CC') as mop,
			s.issue_length,
			s.start_date,
			s.expiry_date

		from
			tCardScheme s
		where
			s.bin_lo <= ? and
			s.bin_hi >= ?
	}

	set SHARED_SQL(tmarque_alert_mail) {
		insert into tAlertMail(alert_mail_type, alert_mail_subject, alert_mail_text)
		values (?,?,?)
	}

	set SHARED_SQL(tmarque_mail_test) {
		select
			alert_mail_email
		from
			tAlertMailType
		where
			alert_mail_type = ?
	}

	set SHARED_SQL(tmarque_acct) {
		select
			acct_no
		from
			tCustomer
		where
			cust_id = ?
	}

	array set ISO_CURR [list \
		AUD	36\
		ATS	40\
		BHD	48\
		BEF	56\
		BMD	60\
		BRL	986\
		CAD	124\
		COP	170\
		CYP	196\
		CZK	203\
		DKK	208\
		EUR	978\
		FIM	246\
		FRF	250\
		XPF	953\
		DEM	280\
		GRD	300\
		HKD	344\
		HUF	348\
		ISK	352\
		INR	356\
		IDR	360\
		IEP	372\
		ILS	376\
		ITL	380\
		JMD	388\
		JPY	392\
		JOD	400\
		KRW	410\
		KWD	414\
		LUF	442\
		MYR	458\
		MTL	470\
		MXN	484\
		MAD	504\
		NLG	528\
		NZD	554\
		NOK	578\
		OMR	512\
		PAB	590\
		PHP	608\
		PLN	616\
		PTE	620\
		QAR	634\
		RUR	643\
		SAR	682\
		SGD	702\
		ZAR	710\
		ESP	724\
		SEK	752\
		CHF	756\
		TWD	901\
		THB	764\
		TRL	792\
		AED	784\
		GBP	826\
		USD	840\
		UZS 860\
		VEB 862]

	array set ERR_CODES [list \
		2000 PMT_RESP_BANK \
		2200 PMT_DECL \
		2210 PMT_CRNO \
		2212 PMT_EXPR \
		2214 PMT_B2 \
		2219 PMT_PAYBACK \
		2223 PMT_NO_PAYBACK_ACC \
		2280 PMT_STRT \
		2282 PMT_ISSUE \
		2332 PMT_CRNO \
		2350 PMT_DECL \
		2352 PMT_DECL \
		2354 PMT_DECL \
		2610 PMT_RESP_BANK \
		2611 PMT_RESP_BANK \
		2612 PMT_RESP_BANK \
		2614 PMT_RESP_BANK \
		2618 PMT_ERR \
		2620 PMT_ERR \
		2954 PMT_RA \
		2956 PMT_DECL \
		2960 PMT_FUNDS \
		2958 PMT_REFR]

		set TMARQUE_INITIALISED 1

		log 5 {==> trustmarque_init}

}

proc trustmarque::send_req {url req timeout} {

	log 5 {Making Request to $url}
	log_no_card $req
        set startTime [OT_MicroTime -micro]
	#make the connection
	if [catch {
		set token [http::geturl $url -query $req -timeout $timeout]
		upvar #0 $token state
	} msg] {
		# Didn't manage to establish a connection
		set res [list "ERR_CON_ERROR" $msg]
	} else {

	   switch -exact -- $state(status) {
				"ok" {
						if { [regexp {\s*(\d\d\d)\s*} $state(http) x http_code] } {
								if {$http_code == "200"} {
										set res [list "OK" $state(body)]
								} else {
										set res [list "ERR_BAD_RESPONSE" $state(http)]
								}
						} else {
								set res [list "ERR_BAD_HTTP_CODE" $state(http)]
						}
				}
				"timeout" {
						set res [list "ERR_TIMEOUT"]
				}
				"eof" {
						set res [list "ERR_NO_RESPONSE"]
				}
				"error" {
						set res [list "ERR_ERROR" $state(error)]
				}
				default {
						set res [list "ERR_UNKNOWN_STATUS" $state(status)]
				}
		}
           
		# check for posterror (not all post data was sent before ok response or eof
		# was received).
		if { [info exists state(posterror)] } {
				set res [list "ERR_POSTERROR" $state(posterror)]
		}

		::http::cleanup $token


	}
        set totalTime [format "%.2f" [expr {[OT_MicroTime -micro] - $startTime}]]
	log INFO "Req Time: $totalTime seconds"
	return $res
}

proc trustmarque::build_StringIn {} {

	variable TRUSTDAT

	set datlist [array get TRUSTDAT]

	set pairlist [list]
	foreach {key val} $datlist {
		lappend pairlist "$key^$val"
	}

	return "StringIn=[join $pairlist ~]"
}

proc trustmarque::split_result {result} {

	variable TRUSTRES

	set datapairs [split $result ~]
	foreach pair $datapairs {
		foreach {key value} [split $pair ^] {
			set TRUSTRES($key) $value
		}
	}
}

proc trustmarque::make_trustmarque_call {ARRAY {REFUND 0}} {

	variable ISO_CURR
	variable TRUSTDAT
	variable TRUSTRES
	variable ERR_CODES
	variable IS_TEST

	catch {unset TRUSTDAT}
	upvar $ARRAY PMT

	set TRUSTDAT(IsTest) $IS_TEST

	switch -- $PMT(pay_sort) {
		"D" {
			set TRUSTDAT(RequestType) A
		}
		"W" {
				if $REFUND {
					set TRUSTDAT(RequestType) R
				} else {
					set TRUSTDAT(RequestType) P
				}
			}
		"X" {
			# Cancel payment
			set TRUSTDAT(RequestType) C
		}
		default {
			log 2 {Bad payment sort $PMT(pay_sort)}
			return PMT_TYPE
		}
	}


	# TrustMarque mandatory fields
	# MerchantId
	# UserName
	# UserPassword
	# TimeOut

	set TRUSTDAT(MerchantId)          [break_mid $PMT(mid) MerchantId]
	set TRUSTDAT(UserName)            $PMT(client)
	set TRUSTDAT(UserPassword)        $PMT(password)
	set TRUSTDAT(TimeOut)             $PMT(resp_timeout)

	# HTTP(S) Settings
	set CONN_TIMEOUT       $PMT(conn_timeout)
	set HOST               $PMT(host)

	# Trustmarque payment mandatory fields
	#
	# VersionUsed (1)
	# TransactionType (PT)
	# MOP
	# AcctNumber
	# ExpDate
	# CurrencyId
	# Amount

	if {[info exists PMT(risk_guardian)]} {
	  set TRUSTDAT(TransactionType) RG
	  set TRUSTDAT(VersionUsed)     3.0
	} else {
	  set TRUSTDAT(TransactionType) PT
	  set TRUSTDAT(VersionUsed)     1
	}

	set TRUSTDAT(AcctNumber)      $PMT(card_no)

	foreach {ret data} [format_start_expiry $PMT(expiry)] {}
	if {$ret == "OK"} {
		set TRUSTDAT(ExpDate) $data
	} else {
		log 2 {Failed to format expiry $ret $data}
		return PMT_ERR
	}

	if [catch {set TRUSTDAT(CurrencyId) $ISO_CURR($PMT(ccy_code))} msg] {
		log 1 {Failed to match currency : $msg}
		return PMT_ERR
	}

	# MOP - method of payment CC for credit DC for debit etc.
	foreach {ret data} [get_mop $PMT(card_no)] {}
	if {$ret == "OK"} {
		foreach {mop issue start expiry} $data {}
		set TRUSTDAT(MOP) $mop
	} else  {
		log 1 {Problem getting MOP for Trustmarque}
		return PMT_ERR
	}

	set TRUSTDAT(Amount)  [string trim $PMT(amount)]

	if {![info exists PMT(risk_guardian)]} {
	  set TRUSTDAT(OrderNumber)     $PMT(apacs_ref)
	}

	if {[info exists PMT(risk_guardian)]} {

		# Trustmarque RiskGuardian

		# Check RiskGuardian mandatory parameters. If we have no data for them then we might as
		# well give up on RiskGuardian now (City and PhoneNumber are special cases - see below)
		if {$PMT(acct_name) == "" || $PMT(first_name) == "" ||
			$PMT(last_name) == "" || $PMT(address1) == "" || $PMT(country_code) == ""} {
			return PMT_RG_MANDATORY_MISSING
		}

		# if amount has no decimal point add in a decimal point and two zero's for TrustMarque
		if {[string first "." $TRUSTDAT(Amount)] == -1} {
			append TRUSTDAT(Amount) ".00"
		}

 		set TRUSTDAT(TypeOfSale) "S"

		if {$PMT(source) == "P"} {
			# Mail order/telephone transactions (card not present)
			set TRUSTDAT(TRXSource) "3"
		} else {
			# Internet transactions (card not present)
			set TRUSTDAT(TRXSource) "5"
		}

		set TRUSTDAT(StoreId)    [break_mid $PMT(mid) StoreId]
		set TRUSTDAT(AcctName)    $PMT(acct_name)
		set TRUSTDAT(IsMember)    $PMT(is_member)
		set TRUSTDAT(Title)       $PMT(title)
		set TRUSTDAT(FirstName)   $PMT(first_name)
		set TRUSTDAT(LastName)    $PMT(last_name)
		set TRUSTDAT(Address1)    $PMT(address1)
		set TRUSTDAT(Address2)    $PMT(address2)
		set TRUSTDAT(Address3)    $PMT(address3)

		## TrustMarque has City as a mandatory field, but we have some customers
		## with no city in the database
		if {$PMT(city) == ""} {
			set TRUSTDAT(City) "No City"
		} else {
			set TRUSTDAT(City) $PMT(city)
		}

		# If we have an account number, use that as the order number
		if {[OT_CfgGet TMARQUE_ORDER_IS_ACCT 0] && $PMT(acct_no) != ""} {
			set TRUSTDAT(OrderNumber) $PMT(acct_no)
		}

		set TRUSTDAT(ZipCode)     $PMT(zipcode)

		# TrustMarque does not have UK on their ISO country list...
		if {$PMT(country_code) == "UK"} {
			set TRUSTDAT(CountryCode) "GB"
		} else {
			set TRUSTDAT(CountryCode) $PMT(country_code)
		}

		# TrustMarque has PhoneNumber as a mandatory field, but we have some customers
		## with no phone number in the database
		if {$PMT(phone_number) == ""} {
			set TRUSTDAT(PhoneNumber) " "
		} else {
			set TRUSTDAT(PhoneNumber) $PMT(phone_number)
		}

		set TRUSTDAT(Email)       $PMT(email)
		set TRUSTDAT(REMOTE_ADDR)          $PMT(REMOTE_ADDR)
		set TRUSTDAT(HTTP_USER_AGENT)      $PMT(HTTP_USER_AGENT)
		set TRUSTDAT(HTTP_ACCEPT_LANGUAGE) $PMT(HTTP_ACCEPT_LANGUAGE)
		set TRUSTDAT(HTTP_ACCEPT-CHARSET)  $PMT(HTTP_ACCEPT_CHARSET)
		set TRUSTDAT(HTTP_REFERER)         $PMT(HTTP_REFERER)

	} elseif {$TRUSTDAT(RequestType) == "P"} {

		# Trustmarque PayBack additional mandatory fields
		#
		# RequestType (P)

	} elseif {$TRUSTDAT(RequestType) == "A"} {

		# Trustmarque Auth additional mandatory fields
		#
		# RequestType (A)
		# MOP
		# TypeOfSale
		# StoreId

		if {$issue > 0} {
			set TRUSTDAT(Issuenumber) [format_issue $issue $PMT(issue_no)]
		}
		if {$start == "Y"} {
			foreach {ret data} [format_start_expiry $PMT(start)] {}
			if {$ret == "OK"} {
				set TRUSTDAT(startdate)  $data
			} else {
				log 2 {Failed to format start $ret $data}
				return PMT_ERR
			}
		}

		# Service sale
		set TRUSTDAT(TypeOfSale) "S"

		set TRUSTDAT(StoreId) [break_mid $PMT(mid) StoreId]

	} elseif {$TRUSTDAT(RequestType) == "R"} {

		if {$issue > 0} {
			set TRUSTDAT(Issuenumber) [format_issue $issue $PMT(issue_no)]
		}
		if {$start == "Y"} {
			foreach {ret data} [format_start_expiry $PMT(start)] {}
			if {$ret == "OK"} {
				set TRUSTDAT(startdate)  $data
			} else {
				log 2 {Failed to format start $ret $data}
				return PMT_ERR
			}
		}

		# Service sale
		set TRUSTDAT(TypeOfSale) "S"

	} elseif {$TRUSTDAT(RequestType) =="S"} {
		# Trustmarque Simultaneous Authorization and Settlement fields
		#
		# RequestType (S)
		# MOP
		# StoreID
		#

		if {$issue > 0} {
			set TRUSTDAT(Issuenumber) [format_issue $issue $PMT(issue_no)]
		}

		set TRUSTDAT(CVN) $PMT(cvv2)

		if {$start == "Y"} {
			foreach {ret data} [format_start_expiry $PMT(start)] {}
			if {$ret == "OK"} {
				set TRUSTDAT(startdate)  $data
			} else {
				log 2 {Failed to format start $ret $data}
				return PMT_ERR
			}
		}

	} elseif {$TRUSTDAT(RequestType) =="C"} {
		# Trustmarque Cancel Payment fields
		#
		# RequestType (C)
		# PTTID
		#
		set TRUSTDAT(PTTID) $PMT(gw_uid)

		# This is BlueSq specific and should be added to tPmtGateAcct
		# as it will change for each customer
		set TRUSTDAT(StoreId) [break_mid $PMT(mid) StoreId]

	}

	# cleanup some of the fields here
	foreach field {Address1 Address2 Address3 City HTTP_REFERER} {
		if {[info exists TRUSTDAT($field)]} {
			set TRUSTDAT($field) [_clean_data $TRUSTDAT($field)]
		}
	}

   	set TRUSTRES(CVNMessageCode) ""

	foreach {success ret} [send_req $HOST [build_StringIn] $CONN_TIMEOUT] {}
	if {$success != "OK"} {
		log 2 {Bad Connection : $success $ret}
		log 2 {Server : $HOST}
		if {$success == "ERR_CON_ERROR"} {
			return PMT_NO_SOCKET
		} else {
			return PMT_RESP
		}
	}

	# Store full return string
	set PMT(gw_ret_msg) $ret

	log 5 $ret

	# Split result into TRUSTRET
	split_result $ret

	if {[info exists PMT(risk_guardian)]} {

		set PMT(gw_ret_code)      $TRUSTRES(MessageCode)
		catch {set PMT(order_no)  $TRUSTRES(OrderNumber)}

		# Trustmarque should send back RgId for VersionUsed 3.0, but it still sends back GttId instead
		# so lets look out for both.
		catch {set PMT(rgid)          $TRUSTRES(RgId)}
		catch {set PMT(rgid)          $TRUSTRES(GttId)}
		catch {set PMT(trisk)         $TRUSTRES(tRisk)}
		catch {set PMT(fraud_score)   $TRUSTRES(tScore)}
		catch {set PMT(tscore)        $TRUSTRES(tScore)}
		set PMT(fraud_score_source)   {RG}

	} elseif {$TRUSTDAT(RequestType) == "P"} {

 		# Trustmarque PayBack return values
 		#
 		# MerchantId
 		# TransactionType (PT)
 		# OrderNumber     (sent with request)
 		# StrId			  (STLink Ref)
 		# PTTID			  (Payment Ref)
 		# CurrencyId
 		# Amount
 		# RequestType     (P)
 		# MessageCode          (success/error code)
 		# Message

		set PMT(gw_ret_code)       $TRUSTRES(MessageCode)
		catch {set PMT(gw_uid)     $TRUSTRES(PTTID)}

 	} elseif {$TRUSTDAT(RequestType) == "A" || $TRUSTDAT(RequestType) == "R"} {

 		# Trustmarque Auth return values
 		#
 		# MerchantId
 		# TransactionType (PT)
 		# OrderNumber     (sent with request)
 		# StrId			  (STLink Ref)
 		# PTTID			  (Payment Ref)
 		# MOP
 		# CurrencyId
 		# AcctNumber
 		# Amount
 		# RequestType     (A)
 		# AuthCode
 		# Result          (success/error code)
 		# AvsZip          (US only)
 		# AvsAddr         (US only)
 		# Message


		set PMT(gw_ret_code)         $TRUSTRES(MessageCode)
		catch {set PMT(gw_auth_code) $TRUSTRES(AuthCode)}
		catch {set PMT(gw_uid)       $TRUSTRES(PTTID)}
	} elseif {$TRUSTDAT(RequestType) == "S"} {

 		# Trustmarque Simultaneous Auth and Settlement return values
 		#
 		# MerchantId
 		# TransactionType (PT)
 		# OrderNumber     (sent with request)
 		# StrId			  (STLink Ref)
 		# PTTID			  (Payment Ref)
 		# MOP
 		# CurrencyId
 		# Amount
 		# RequestType     (S)
 		# AuthCode
 		# Message Code
		# Message
		# CVNMessageCode
		# CVNMessage

		set PMT(gw_ret_code)   $TRUSTRES(MessageCode)
		catch {set PMT(gw_uid) $TRUSTRES(PTTID)}

		# Get the CVN response
		set PMT(cv2avs_status) [get_cvn_status $TRUSTRES(CVNMessageCode)]

	} elseif {$TRUSTDAT(RequestType) == "C"} {

 		# Trustmarque Cancel Payment return values
 		#
 		# MerchantId
 		# TransactionType (PT)
 		# OrderNumber     (sent with request)
 		# StrId			  (STLink Ref)
 		# PTTID			  (Payment Ref)
 		# CurrencyId
 		# Amount
 		# RequestType     (C)
 		# Message Code
		# Message
		set PMT(gw_ret_code)   $TRUSTRES(MessageCode)
		catch {set PMT(gw_uid) $TRUSTRES(PTTID)}
	}

	if {$TRUSTRES(MessageCode) == "2170"}  {
		# Success code for cancel payment 2170

		log_result 5
		set ret_code PMT_DECL

	} elseif {[string range $TRUSTRES(MessageCode) 0 1] == "21" || $TRUSTRES(MessageCode) == "2050" ||
				$TRUSTRES(MessageCode) == "2001" || $TRUSTRES(MessageCode) == "100" } {
		# Sucess codes start 21 apart from
		# 2050 PayBack request pending
		# 2001 no need for transaction
		# 100 Risk Guardian successful
		log_result 5
		set ret_code OK
	} else {

		if {$TRUSTRES(MessageCode) == "2223"} {
			# Alert BlueSq to contact customer
			create_alert_mail $PMT(cust_id) $PMT(card_no)
		}

		if {[catch {set ret_code $ERR_CODES($TRUSTRES(MessageCode))}]} {
			# Unknown Error
			set ret_code PMT_ERR
		}
		log 2 {Error : $TRUSTRES(MessageCode) [catch {$TRUSTRES(Message)}]}
		log_result 2
	}

	catch {unset TRUSTDAT}
	return $ret_code
}



proc trustmarque::break_mid {mid_string {part MerchantId}} {

	# In the case of Trustmarque we need two Merchant ID
	# One from Trustmarque and one (called the Store ID) from the aquiring bank

	set index 0

	switch $part {
		MerchantId {}
		StoreId    {set index 1}
		default    {log 1 "Unknown part of MID requested"}
	}

	return [lindex [split $mid_string |] $index]


}

proc trustmarque::format_issue {requiredlen issue} {
	set islen [string length $issue]
	if {$islen == $requiredlen} {
		return $issue
	} elseif {$islen < $requiredlen} {
		return "0$issue"
	} else {
		return [string index $issue end]
	}
}

proc trustmarque::format_start_expiry {date} {

	if {![regexp {(\d{2})/(\d{2})} $date all month 2digyear]} {
		return [list ERR PMT_EXPR]
	}

	## For cards starting before 2000
	if {$2digyear > 90} {
		return [list OK "${month}19${2digyear}"]
	} else {
		return [list OK "${month}20${2digyear}"]
	}


}

proc trustmarque::log {level msg} {

	variable TRUSTDAT
	variable IS_TEST
	global TESTLOG

	if {$IS_TEST} {
		lappend TESTLOG $msg
		set msg "TMARQUE TEST $msg"
	} else {
		set msg "TMARQUE LIVE $msg"
	}

	uplevel [list ob_log::write $level $msg]
}

proc trustmarque::log_result {level} {

	variable TRUSTRES

	log $level {Response}
	foreach {key val} [array get TRUSTRES] {
		log $level {    $key : $val}
	}

}

proc trustmarque::get_mop {card_no} {

	# MOP Calculated from tCardScheme tCardSchemeInfo
	set bin [string range $card_no 0 5]
	set rs [tb_db::tb_exec_qry tmarque_mop $bin $bin]
	set num_rows [db_get_nrows $rs]

	if {$num_rows != 1} {
		log 2 {Failed to resolve method of payment, unknown card scheme}
		return [list ERR NONE]
	}

	return [list OK [db_get_row $rs 0]]
}



proc trustmarque::create_alert_mail {cust_id card_no} {

	if {[catch {set rs [tb_db::tb_exec_qry tmarque_mail_test TMARQUE]} msg]} {
		log 1 {tmarque_email_test query failed : $msg}
		return
	}

	if {[db_get_nrows $rs] == 1} {

		if {[catch {set rs [tb_db::tb_exec_qry tmarque_acct $cust_id]} msg]} {
			log 1 {tmarque_acct query failed : $msg}
			return
		}
		set acct_no [db_get_col $rs 0 acct_no]
		set card_bin [string range $card_no 0 8]
		set subject "2223 Payment"
		set type "TMARQUE"
		set error "Customer ID : $cust_id \n Account Number : $acct_no \n Card Bin : $card_bin"
		if {[catch {set rs [tb_db::tb_exec_qry tmarque_alert_mail $type $subject $error]} msg]} {
			log 1 {tmarque_alert_mail query failed : $msg}
			return
		}

		log 10 {Queued alert email for 2223}
	} else {
		log 10 {No TMARQUE alert type set}
	}

}

proc trustmarque::log_no_card {req} {

	variable IS_TEST

	if $IS_TEST {
		log 5 $req
	} else {

		if {[regexp {^(.*)(UserPassword\^)([^~]+)(.*)(AcctNumber\^)([0-9]+)(.*)$} $req all start user pword mid acc card end]} {
			log 5 {$start$user{PASSWORD_HIDDEN}$mid$acc{CARD_HIDDEN}$end}
		} else {
			log 5 {$req}
		}
	}

}



#
# trustmarque_decrypt
#
# Decrypts an encrypted value
#
# Param
#
#     value - an encrypted value
#
# Returns
#
#      Param 'value' in its decrypted form
#
proc trustmarque::trustmarque_decrypt {value} {
	return [card_util::card_decrypt $value 0]
}



#
# get_cft_daily_wtd_limit
#
# Checks whether customer is over CFT daily withdrawal limit. The CFT withdrawal
# limit is defined bu the config item: CFT_DAILY_US_LIMIT
#
# Param
#
#     cpm_id        - the identifier of the customer's payment method
#     cust_ccy_code - the customers currency
#     cust_amount   - the amount being withdrawn in the customer's currency
#
# Returns
#
#    1 if customer is over the CFT limit; 0 otherwise
#
proc trustmarque::get_cft_daily_wtd_limit {cpm_id cust_ccy_code cust_amount} {

	set us_ccy_code  {USD}
	set us_daily_limit [OT_CfgGet CFT_DAILY_US_LIMIT 5000]

	# Get the US exhange rate
	if {[catch {set rs [tb_db::tb_exec_qry get_exch_rate $us_ccy_code]} msg]} {
		log 1 {get_exch_rate query failed : $msg}
		return 1
	}

	set num_rows [db_get_nrows $rs]

	if {$num_rows != 1} {
		log 2 {Failed to retrieve US exchange rate}
		return 1
	}

	# US exchange rate
	set us_exch_rate [db_get_col $rs 0 exch_rate]

	db_close $rs
	unset rs

	# Get the customers exchange rate
	if {[catch {set rs [tb_db::tb_exec_qry get_exch_rate $cust_ccy_code]} msg]} {
		log 1 {get_exch_rate query failed : $msg}
		return 1
	}

	set num_rows [db_get_nrows $rs]

	if {$num_rows != 1} {
		log 2 {Failed to retrieve customers exchange rate}
		return 1
	}

	# Customer's exchange rate
	set cust_exch_rate [db_get_col $rs 0 exch_rate]

	db_close $rs
	unset rs

	# Convert customer's amount to the db currency
	set db_amount [expr {$cust_amount / $cust_exch_rate}]

	# Convert amount to US dollars
	set us_amount    [expr {$db_amount * $us_exch_rate}]

	# Check if US amount withdrawn is greated than the daily limit
	if {$us_amount > $us_daily_limit} {
		return 1
	}

	# Get the db amount withdrawn by this customers payment method for the last 24 hours
	if {[catch {set rs [tb_db::tb_exec_qry get_cust_wtd_last_day\
																$cpm_id\
																$cust_ccy_code]} msg]} {
		log 1 {get_cust_cft_daily_total_so_far query failed : $msg}
		return 1
	}

	set num_rows [db_get_nrows $rs]

	if {$num_rows == 0} {
		# Customer not over CFT daily limit
		return 0
	}

	# Get todays db amount withdrawn so far
	set todays_db_amount [db_get_col $rs 0 db_amount_so_far]

	# If no withdrawals took place, CFT Limit check is ok
	if {$todays_db_amount == ""} {
		return 0
	}

	# Add the amount(US) currently being withdrawn to the amount(US) that has been
	# withdrawn so far today
	set us_amount [expr {($todays_db_amount * $us_exch_rate) + $us_amount}]

	# Check if US amount withdrawn is greated than the daily limit
	if {$us_amount > $us_daily_limit} {
		return 1
	} else {
		return 0
	}
}

# Translate the CVN response fields into Datacash standard text
# format
#
# intCV2  - Customer Security Code response from Metacharge
#
# returns - Datacash-style cvn_status string
#
proc trustmarque::get_cvn_status {intCVN} {

	# No responses
	if {$intCVN == 1} {
		set cvn_status "DATA NOT CHECKED"
	}

	# Unexpected responses
	if {$intCVN < 0 && $intCVN > 4 || $intCVN == ""} {
		set cvn_status "UNKNOWN"
	}

	# Security match only
	if {$intCVN == 4} {
		set cvn_status "SECURITY CODE MATCH ONLY"
	} elseif {$intCVN == 3} {
	# Address check passed
		set cvn_status "ADDRESS MATCH ONLY"
	} elseif {$intCVN == 2} {
	# No data matches
		set cvn_status "NO DATA MATCHES"
	# All matched
	} elseif {$intCVN == 0} {
		set cvn_status "ALL MATCH"
	}

	return $cvn_status
}

proc trustmarque::_clean_data {s} {

	set esc_map \
	[list \
		"<"    "[urlencode <]" \
		">"    "[urlencode >]" \
		"\""   "[urlencode \"]" \
		"'"    "[urlencode ']" \
		"&"    "[urlencode &]"]

	return [string map $esc_map $s]

}
