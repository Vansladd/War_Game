# ==============================================================
# $Id: cybersource.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2003 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================
#
# A credit card payment has two phases. The first phase is the
# authorisation which takes place when the initial request for
# a deposit is made. This is a check that the card exists, sufficient funds
# etc. The customer deposit triggers this "ics_auth" message request to
# be sent to Cybersource.
#
# There is also an option at this stage to send a settlement request
# too, "ics_bill". This second phase (also refered to as "fulfilment", "billing"
# or "settling") is when the funds are transfered from the card issuing
# bank's account into the merchant's bank account.
#
# In the past only the authorization requests were sent when the
# customer made a deposit and the settlement requests were sent in a batch
# every night, using a cronscript and the ics_stl.tcl script.  Now the
# settle request is sent at the same time as the authorization request;
#
# Note the entry in the trans type array below.
#		"D" "ics_auth,ics_bill"
# i.e. a deposit is an ics_auth _and_ an ics_bill
#
# ============================================================
#
# CONFIGURATION REQUIREMENTS
#
# 1) Generate cybersource public/private keys and set ICSPATH in your environment
#    to their location.
#
#  e.g if you have
#     /opt/CyberSource/SDK/keys/orbis1.crt
#     /opt/CyberSource/SDK/keys/orbis1.pwd
#     /opt/CyberSource/SDK/keys/orbis1.pvt
#
#     then you need
#     export ICSPATH=/opt/CyberSource/SDK in your environment
#
# 2) ICS_MERCHANT_IDS set in your config file to identify the
#    Cybersource username that you use for each combination of
#    currency and payment method ("D"eposit or "W"ithdrawal)
#
#  e.g. ICS_MERCHANT_IDS = {GBP D myusername} {GBP W myusername}
#  if you use "myusername" to do only deposits and withdrawals in GBP.
#
# 3) ICS_LIBRARY = libics_tcl.so
#
# 4) Entries in tpmtgateacct, tpmtgatehost
#
#    tpmtgateacct                              tpmtgatehost
#    ============                              ============
#    pg_acct_id   = <whatever number>          pg_host_id   = <same whatever number>
#    pg_type      = CYBERSOURCE                pg_type      = CYBERSOURCE
#    enc_client   = <blowfished username>      pg_ip        = <ip/host e.g ics2test.ic3.com>
#    enc_password = <blowfished password>      pg_port      = 80
#    status       = A                          resp_timeout = 30000 (for example)
#    pay_mthd     = CC                         conn_timeout = 150000 (for example)
#                                              desc         = "Cybersource Gateway (or whatever)"
#                                              status       = A
#                                              default      = N/Y
#
#
# 5) Source this file in init.tcl, before payment_gateway.tcl
#
# ============================================================

package provide ICS 1.0

namespace eval ICS {

	variable ICS_AUTH_FIELDS
	variable ICS_CREDIT_FIELDS
	variable ICS_BILL_FIELDS
	variable ICS_CFG
	variable ICS_RESP

	set ICS_AUTH_FIELDS {
		auth_code
		auth_rflag
		auth_rmsg
		auth_auth_amount
		auth_auth_response
		auth_auth_code
		auth_auth_avs
		auth_auth_time
		bill_rcode
		bill_rflag
		bill_rmsg
		bill_bill_request_time
		bill_bill_amount
		score_rcode
		score_rflag
		score_rmsg
		score_factors
		score_host_serverity
		score_score_result
		score_time_local
	}

	set ICS_CREDIT_FIELDS {
		credit_rcode
		credit_rflag
		credit_rmsg
		credit_auth_response
		credit_credit_amount
		credit_credit_request_time
	}

	set ICS_BILL_FIELDS {
		bill_rcode
		bill_rflag
		bill_rmsg
		bill_bill_amount
		bill_bill_request_time
	}

	# transaction types
	variable TRANS_TYPES

	# (D)eposit
	# (W)ithdrawal
	# (B)ill

	# The config file parameter ICS_SCORE (Y/N)
	# will determine whether or not ics_score
	# should be included for deposits.
	# See ICS;;_read_config
	#
	array set TRANS_TYPES [subst {
		"D" "ics_auth,ics_bill"
		"W" "ics_credit"
		"B" "ics_bill"
	}]

}


###################
proc ICS::init {} {
###################
	global SHARED_SQL

	variable ICS_CFG
	variable TRANS_TYPES

	::ob::log::write 15 { CYBER : DEBUG Starting Cybersource initialisation ...}

	set ics_library  [OT_CfgGet ICS_LIBRARY "" ]

	load $ics_library ics


	if {[OT_CfgGet ICS_SCORE "N"] == "Y"} {

		set TRANS_TYPES(D) "ics_auth,ics_bill,ics_score"

	} else {

		set TRANS_TYPES(D) "ics_auth,ics_bill"

	}
	::ob::log::write 4 { CYBER : trans types : $TRANS_TYPES(D)}


	if {[OT_CfgGet ICS_MERCHANT_IDS ""] == "" } {

		error "Missing config parameter ICS_MERCHANT_IDS"

	} else {
		foreach {ccy type id} [join [OT_CfgGet ICS_MERCHANT_IDS]] {

			set ICS_CFG(merchant_id,$type,$ccy) $id
			::ob::log::write 4 { CYBER : adding currency : $type, $ccy = $id}
		}
	}


	 set SHARED_SQL(cyber_get_reg_detail) {
   		select
			r.fname,
			r.lname,
			r.addr_postcode,
			r.telephone,
			r.addr_street_1,
			r.addr_city,
			c.country_code,
			r.email
		from
			tCustomer c,
			tCustomerReg r,
			tAcct a
		where
			r.cust_id = c.cust_id and
			c.cust_id = a.cust_id and
			a.acct_id = ?
	}
}

##############################
proc ICS::set_pmt_data {
	 server
	 port
	 merchant_id
	 timeout
	 pay_sort
	 ccy_code
	{http_proxy          ""}
	{http_proxy_username ""}
	{http_proxy_password ""}
	{ignore_avs          "no"}
} {
##############################

	variable ICS_CFG

	set ICS_CFG(server)              $server
	set ICS_CFG(port)                $port
	set ICS_CFG(merchant_id)         $merchant_id
	set ICS_CFG(timeout)             $timeout
	set ICS_CFG(http_proxy)          $http_proxy
	set ICS_CFG(http_proxy_username) $http_proxy_username
	set ICS_CFG(http_proxy_password) $http_proxy_password
	set ICS_CFG(ignore_avs)          $ignore_avs


	if {[info exists ICS_CFG(merchant_id,$pay_sort,$ccy_code)]} {
		set ICS_CFG(merchant_id) $ICS_CFG(merchant_id,$pay_sort,$ccy_code)
	} else {
		return PMT_ERR
	}

	# Check that required items have values

	foreach item {
		server
		port
		merchant_id
		timeout
		ignore_avs
	} {
		if {$ICS_CFG($item) == ""} {
			return PMT_ERR
		}
	}

	::ob::log::write 15 { CYBER : merchant_id  = $ICS_CFG(merchant_id)}
	::ob::log::write 15 { CYBER : server       = $ICS_CFG(server)}
	::ob::log::write 15 { CYBER : port         = $ICS_CFG(port)}
	::ob::log::write 15 { CYBER : timeout      = $ICS_CFG(timeout)}
	::ob::log::write 15 { CYBER : ignore_avs   = $ICS_CFG(ignore_avs)}

	return OK
}



#############################
proc ICS::authorise {ARRAY} {
#############################
	# This procedure will send an ics_auth, and ics_bill message to Cybersource.
	# ics_score will also be set if ICS_SCORE = Y

	variable ICS_DATA
	variable ICS_CFG
	variable ICS_RESP

	catch { unset ICS_DATA }

	upvar $ARRAY PMT


	if {[set ret [set_pmt_data \
		$PMT(host) \
		$PMT(port) \
		$PMT(client) \
		$PMT(resp_timeout) \
		$PMT(pay_sort) \
		$PMT(ccy_code) \
		"" \
		"" \
		"" \
		[OT_CfgGet ICS_IGNORE_AVS "no"]]] != "OK"} {

		::ob::log::write 1 { CYBER : Failed to set up payment correctly }

		return $ret
	}


	set trans_type     $PMT(pay_sort)
	set ref_no         $PMT(apacs_ref)
	set amount         $PMT(amount)
	set currency       $PMT(ccy_code)
	set card_number    $PMT(card_no)
	set expiry_date    $PMT(expiry)
	set start_date     $PMT(start)
	set issue_number   $PMT(issue_no)
	set cvv2           $PMT(cvv2)

	set ICS_DATA(trans_type)   $trans_type
	set ICS_DATA(ref_no)       $ref_no
	set ICS_DATA(amount)       $amount
	set ICS_DATA(currency)     $currency
	set ICS_DATA(card_number)  $card_number
	set ICS_DATA(expiry_date)  $expiry_date
	set ICS_DATA(start_date)   $start_date
	set ICS_DATA(issue_number) $issue_number
	set ICS_DATA(cv2)          $cvv2
	set ICS_DATA(ipaddr)       [reqGetEnv REMOTE_ADDR]

	if [catch {set rs [tb_db::tb_exec_qry cyber_get_reg_detail $PMT(acct_id)]} msg] {
		::ob::log::write 1 { CYBER : ****failed to exec qry cyber_get_reg_detail : $msg}
		return PMT_ERR
	}

	if {[db_get_nrows $rs] != 1} {
		::ob::log::write 1 { CYBER : ****qry cyber_get_reg_detail did not return 1 row}
		return PMT_ERR
	}

	# Email address might be null in telebet, if so then
	# set it to "null@cybersource.com" so that cybersource
	# does not complain.

	set email_addr [db_get_col $rs email]

	if {$email_addr == ""} {
		set ICS_DATA(email) "null@cybersource.com"
	} else {
		set ICS_DATA(email) $email_addr
	}

	if {[OT_CfgGet NORMALISE_FOREIGN_CHARS 0]} {
		set ICS_DATA(fname)    [ob_cust::normalise_unicode [db_get_col $rs fname] 0 0]
		set ICS_DATA(lname)    [ob_cust::normalise_unicode [db_get_col $rs lname] 0 0]
		set ICS_DATA(address)  [ob_cust::normalise_unicode [db_get_col $rs addr_street_1] 0 0]
		set ICS_DATA(city)     [ob_cust::normalise_unicode [db_get_col $rs addr_city] 0 0]
	} else {
		set ICS_DATA(fname)   [db_get_col $rs fname]
		set ICS_DATA(lname)   [db_get_col $rs lname]
		set ICS_DATA(address) [db_get_col $rs addr_street_1]
		set ICS_DATA(city)    [db_get_col $rs addr_city]
	}
	set ICS_DATA(zip)     [db_get_col $rs addr_postcode]
	set ICS_DATA(phone)   [db_get_col $rs telephone]
	set ICS_DATA(country) [db_get_col $rs country_code]

	db_close $rs

	set ICS_DATA(score_threshold)          ""
	set ICS_DATA(score_category_longterm)  ""
	set ICS_DATA(score_category_time)      ""
	set ICS_DATA(score_host_hedge)         ""
	set ICS_DATA(score_time_hedge)         ""
	set ICS_DATA(score_velocity_hedge)     ""

	::ob::log::write 7 { CYBER : ==========START===========}
	::ob::log::write 7 { CYBER :trans_type              = $PMT(pay_sort)}
	::ob::log::write 7 { CYBER :merchant_ref_no         = $PMT(apacs_ref)}
	::ob::log::write 7 { CYBER :amount                  = $PMT(amount)}
	::ob::log::write 7 { CYBER :currency                = $PMT(ccy_code)}
	::ob::log::write 7 { CYBER :fname                   = $ICS_DATA(fname)}
	::ob::log::write 7 { CYBER :lname                   = $ICS_DATA(lname)}
	::ob::log::write 7 { CYBER :zip                     = $ICS_DATA(zip)}
	::ob::log::write 7 { CYBER :score_threshold         = $ICS_DATA(score_threshold)}
	::ob::log::write 7 { CYBER :score_category_longterm = $ICS_DATA(score_category_longterm)}
	::ob::log::write 7 { CYBER :score_category_time     = $ICS_DATA(score_category_time)}
	::ob::log::write 7 { CYBER :score_host_hedge        = $ICS_DATA(score_host_hedge)}
	::ob::log::write 7 { CYBER :score_time_hedge        = $ICS_DATA(score_time_hedge)}
	::ob::log::write 7 { CYBER :score_velocity_hedge    = $ICS_DATA(score_velocity_hedge)}

	if {[set ret [check_data]] != "OK"} {
		::ob::log::write 7 { CYBER : check_data failed: $ret}
		::ob::log::write 7 { CYBER : ===========END============}

		return $ret
	}

	# split expiry and start dates into month and year
	foreach item {
		expiry
		start
	} {
		if {[string length [set ${item}_date]] == 0} {
			set ${item}_date "/"
		}

		foreach {month year} [split [set ${item}_date] "/"] {

			set ICS_DATA(${item}_month) $month
			set ICS_DATA(${item}_year)  [get4digitYear $year]
		}
	}


	# create the cybersource message

	set result [message_pack]

	if {[lindex $result 0] != "OK"} {
		return [lindex $result 1]
	}

	set request [lindex $result 1]


	# and send

	set send_result [message_send $request]

	if {[lindex $send_result 0] != "OK"} {
		::ob::log::write 1 { CYBER : failed to send message : [lindex $send_result 0] }
		::ob::log::write 1 { CYBER : ===========END============}

		return [lindex $send_result 0]
	}

	set response [lindex $send_result 1]


	# unpack

	set unpack_result [message_unpack $response]

	if {[lindex $unpack_result 0] != "OK"} {
		::ob::log::write 1 { CYBER : failed to unpack message : [lindex $unpack_result 0] }
		::ob::log::write 1 { CYBER : ===========END============}

		return [lindex $unpack_result 0]
	}

	# If we requested and auth the response codes, regardless of success/failure.

	set PMT(gw_uid)       $ICS_RESP(request_id)
	set PMT(gw_ret_msg)   $ICS_RESP(ics_rmsg)
	set PMT(gw_ret_code)  $ICS_RESP(ics_rcode)

	if {$trans_type == "D"} {
		set PMT(gw_auth_code) $ICS_RESP(auth_auth_code)
	}

	message_destroy $request
	message_destroy $response

	# Response codes - ics_rcode
	# -1 - Failed
	# 0  - Declined payments
	# 1  - Successful payments

	::ob::log::write 4 { CYBER :****** Response $ICS_RESP(ics_rcode)}


	switch -- $ICS_RESP(ics_rcode) {

		"-1"    { return PMT_ERR }

		"0"     { return "ICS_$ICS_RESP(ics_rflag)" }

		"1"     { return "OK" }

		default { return "PMT_ERR" }
	}

}


##################
proc ICS::settle {
	amount
	currency
	auth_code
	reference
	trans_type
} {
##################

	# WARNING!   this needs rewriting....

	# This procedure send an ics_bill request to Cybersource.

	variable ICS_DATA
	variable ICS_CFG

	catch { unset ICS_DATA }

	# Check the arguments
	if {[regexp {^\s*$} $amount]} {

			err_add [ICS::ml_printf MISSING_AMOUNT]
			return [list ERR 1]

	}

	if {[regexp {^\s*$} $currency]} {

			err_add [ICS::ml_printf MISSING_CURRENCY]
			return [list ERR 1]

	}

	if {[regexp {^\s*$} $auth_code]} {

			err_add [ICS::ml_printf MISSING_AUTH_CODE]
			return [list ERR 1]

	}

	if {[regexp {^\s*$} $reference]} {

			err_add [ICS::ml_printf MISSING_REFERENCE]
			return [list ERR 1]

	}

	set ICS_DATA(trans_type) "B"
	set ICS_DATA(amount)     $amount
	set ICS_DATA(currency)   $currency
	set ICS_DATA(auth_code)  $auth_code
	set ICS_DATA(reference)  $reference

	# retrieve the correct merchant id for the currency specified
	if {![info exists ICS_CFG(merchant_id)]} {

		::ob::log::write 10 { CYBER : no merchant id specified for $currency}
		::ob::log::write 10 { CYBER : ===========END============}

		err_add [ICS::ml_printf CCY_MRCH_ID $currency]
		return [list ERR 1]
	}

	# Pack the message
	foreach {status request} [message_settle_pack] {
		if {$status == "ERR"} {
			::ob::log::write 10 { CYBER : DEBUG ERROR packing message}
			return [list ERR $request]
		}
	}

	# Send the message
	foreach {status response} [message_send $request] {
		if {$status == "ERR"} {
			::ob::log::write 10 { DEBUG ERROR sending message}
			return [list ERR $response]
		}
	}

	# Unpack the message
	foreach {status ret} [message_unpack $response] {
		if {$status == "ERR"} {
			::ob::log::write 10 { DEBUG ERROR unpacking response}
			return [list ERR $ret]
		}
	}

	return [list OK]

}

#########################
proc ICS::check_data {} {
#########################
	variable ICS_DATA
	variable TRANS_TYPES

	if {![info exists TRANS_TYPES($ICS_DATA(trans_type))]} {
		return PMT_TYPE
	}

	if {![regexp {^([0-9]+)(\.([0-9]([0-9])?))?$} $ICS_DATA(amount)]} {
		return PMT_AMNT
	}

	if {[string trim [string length $ICS_DATA(currency)]] == 0} {
		return PMT_CCY
	}

	return OK
}

###########################
proc ICS::message_pack {} {
###########################

	# Generates the message that will be sent to the
	# ICS payment gateway.

	variable ICS_CFG
	variable ICS_DATA
	variable TRANS_TYPES

	set msg [ics init 0]

	foreach {key val} {
		server_host  server
		server_port  port
		merchant_id  merchant_id
		timeout      timeout
	} {

		if {[set ret [message_add $msg $key $ICS_CFG($val)]] != "OK"} {
			return [list $ret]
		}
	}

	foreach {key val} {
		http_proxy http_proxy
		http_proxy_username http_proxy_username
		http_proxy_password http_proxy_password
		ignore_avs ignore_avs
	} {
		if {$ICS_CFG($val) != ""} {
			if {[set ret [message_add $msg $key $ICS_CFG($val)]] != "OK"} {
				return [list $ret]
			}
		}
	}

	message_add $msg ics_applications $TRANS_TYPES($ICS_DATA(trans_type))

	set offer_string "quantity:1^amount:$ICS_DATA(amount)"

	foreach item {
		score_threshold
		score_category_longterm
		score_category_time
		score_host_hedge
		score_time_hedge
		score_velocity_hedge
	} {
		if {[info exists ICS_DATA($item)] && $ICS_DATA($item) != ""} {
			append offer_string "^$item:$ICS_DATA($item)"
		}
	}

	message_add $msg "offer0" $offer_string

	foreach {key val} {
		merchant_ref_number ref_no
		currency            currency
		customer_cc_number  card_number
		customer_cc_expmo   expiry_month
		customer_cc_expyr   expiry_year
		customer_firstname  fname
		customer_lastname   lname
		customer_email      email
		customer_ipaddress  ipaddr
		customer_phone      phone
		bill_address1       address
		bill_city           city
		bill_country        country
	} {
		if {[set ret [message_add $msg $key $ICS_DATA($val)]] != "OK"} {
			return [list $ret]
		}
	}

	foreach {key val} {
		customer_cc_issue_number issue_number
		customer_cc_startmo      start_month
		customer_cc_startyr      start_year
		customer_cc_cv_number    cv2
		bill_zip                 zip
		bill_state               state
	} {

		if {[info exists ICS_DATA($val)] && $ICS_DATA($val) != ""} {

			if {[set ret [message_add $msg $key $ICS_DATA($val)]] != "OK"} {
				return [list $ret]
			}
		}
	}

	return [list OK $msg]
}

##################################
proc ICS::message_settle_pack {} {
##################################

	# Generates the message that will be sent to the
	# ICS payment gateway for a settlement.

	variable ICS_CFG
	variable ICS_DATA
	variable TRANS_TYPES

	set msg [ics init 0]

	foreach {key val} {
		server_host  server
		server_port  port
		merchant_id  merchant_id
		timeout      timeout
	} {
		message_add $msg $key $ICS_CFG($val)
	}

	foreach {key val} {
		http_proxy
		http_proxy_username
		http_proxy_password
		ignore_avs
	} {
		if {$ICS_CFG($val) != ""} {
			message_add $msg $key $ICS_CFG($val)
		}
	}

	message_add $msg ics_applications $TRANS_TYPES($ICS_DATA(trans_type))

	set offer_string "quantity:1^amount:$ICS_DATA(amount)"

	message_add $msg "offer0" $offer_string

	foreach {key val} {
		auth_request_id		auth_code
		merchant_ref_number reference
		currency            currency
	} {
		message_add $msg $key $ICS_DATA($val)
	}

	return [list OK $msg]

}

##################################
proc ICS::message_send {request} {
##################################
	# Sends the payment request to the ICS payment
	# gateway.

	variable ICS_DATA

	set response ""

	if [catch {set response [ics send $request]} msg] {

		::ob::log::write 1 { CYBER : Failed to send message : $msg}

		message_destroy $request

		return [list PMT_ERR]

	}
	return [list OK $response]
}

#####################################
proc ICS::message_unpack {response} {
#####################################
	variable ICS_DATA
	variable ICS_RESP
	variable ICS_AUTH_FIELDS
	variable ICS_CREDIT_FIELDS
	variable ICS_BILL_FIELDS

	catch { unset ICS_RESP }


	set header {
		ics_rcode
		ics_rflag
		ics_rmsg
		request_id
	}

	set trans_type [string toupper $ICS_DATA(trans_type)]

	switch -- $trans_type {
		"D" {
			set fields [concat $header $ICS_AUTH_FIELDS]
		}
		"W" {
			set fields [concat $header $ICS_CREDIT_FIELDS]
		}
		"B" {
			set fields [concat $header $ICS_BILL_FIELDS]
		}
		default {
			return [list PMT_ERR]
		}
	}


	foreach item $fields {

		set value ""

		#don't mind if some fields aren't returned
		catch {set value [ics fgetbyname $response $item]}
		catch {set ICS_RESP($item) $value}

		::ob::log::write 10 { CYBER : message_unpack: $item = $value}
	}

	return [list OK]
}

########################################
proc ICS::message_add {msg name value} {
########################################

	# Logging credit card details is a potential security risk
	set cc_names [list customer_cc_number customer_cc_expmo \
					   customer_cc_expyr customer_cc_issue_number \
   	                   customer_cc_startmo customer_cc_startyr \
					   customer_cc_cv_number]

	if {[ics fadd $msg $name $value] < 0} {

		return PMT_ERR

	} else {

		if {[lsearch $cc_names $name] == -1} {

			::ob::log::write 3 { message_add: added $name=$value to $msg}

		} else {

			::ob::log::write 3 { message_add: added $name to $msg}

		}

	}
	return OK
}

#################################
proc ICS::message_destroy {msg} {
#################################
	catch { ics destory $msg }
}

################################
proc ICS::get4digitYear {year} {
################################
	if {[string length $year] == 2} {
		if {$year < 90} {
			return "20$year"
		} else {
			return "19$year"
		}
	} else {
		return $year
	}
}

