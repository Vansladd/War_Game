# $Id: ventmear.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
##
# Ventmear Server has been set up as a payment gateway. It provides
# an automatic means for Chineese customers to deposit money both on
# their credit and debit card.
#
#
##

namespace eval ventmear {

namespace export make_ventmear_call
namespace export is_1pay_cust
namespace export get_1pay_status
namespace export get_cust_ccy

#-----------------------------------------------------------------
#
# DESCRIPTION :
# 	Initialise the queries and stored procedure calls.
#
#-----------------------------------------------------------------
proc ventmear_init {} {
	prep_qrys
}

proc prep_qrys {} {

	global SHARED_SQL

	set SHARED_SQL(update_cpm_type) {
		update tcustpaymthd
		set    type   = ?
		where  cpm_id = ?
	}

	set SHARED_SQL(get_cpm_type) {
		select type
		from   tCustPayMthd
		where  cpm_id = ?
	}

	set SHARED_SQL(get_1pay_ccy) {
		select ccy_code
		from   tacct
		where  cust_id = ?
	}
}



#-----------------------------------------------------------------
# DESCRIPTION :
# 	Opens up a HTTP connection to ventmear and
#	sends a request for a deposit. If the result is
#	positive a URL will be returned to redirect the
#       customer to in order to finish off the payment with
#	1-Pay.
#
# INPUTS :
#	Array containing payment information.
#
# RETURNS :
#	-"PMT_URL_REDIRECT" to indicate success contacting Venmear
#	-translatable error code otherwise
#
#-----------------------------------------------------------------
proc make_ventmear_call {ARRAY} {

	ob::log::write DEBUG {==>::ventmear::make_ventmear_call}

	upvar 1 $ARRAY PMT
	global LOGIN_DETAILS

	package require http

	#
	# Set the necessary variables
	#
	set url          [OT_CfgGet VENTMEAR_URL "http://$PMT(host)/ventmear"]
	set w_id         [expr {[reqGetArg w_id]==""?[clock seconds]:[reqGetArg w_id]}]
	set action       "get_url"
	set sess_id      $w_id
	set txn_ref      $PMT(pmt_id)
	set ccy          $PMT(ccy_code)
	set amt          [expr round($PMT(amount) * 100)]
	set card_no      $PMT(card_no)
	set card_expiry  $PMT(expiry)
	set resp_timeout $PMT(resp_timeout)

	if {[info exists LOGIN_DETAILS(LANG)]} {
		set lang $LOGIN_DETAILS(LANG)
	} else {
		set lang en
	}

	#
	# Build request
	#
	set request_vars [::http::formatQuery 	"action" 	$action\
						"sess_id" 	$sess_id\
						"txn_ref"	$txn_ref\
						"lang"		$lang\
						"ccy"		$ccy\
						"amt"		$amt\
						"card_no"	$card_no\
						"card_expiry"	$card_expiry]

	if {[string first "?" $url] == -1} {
		append url "?"
	}
	append url $request_vars


	#
	# Send the request and wait for a response
	#
	ob::log::write INFO {Sending request URL to Ventmear : $url}

	if [catch {
		set token [::http::geturl $url -type "text" -timeout $resp_timeout]
		upvar #0 $token state
		} msg] {
		# Didn't manage to establish a connection
		ob::log::write ERROR {Could not establist HTTP connection to Ventmear Server : $msg}
		::http::cleanup $token
		return [list "PMT_ERR"]
	}

	# Check the HTTP response code
	set ncode [::http::ncode $token]
	ob::log::write DEBUG {Ventmear response code: $ncode}

	if {$ncode != "200"} {
		set errmsg "Invalid server response from Ventmear : [::http::code $token] "
		ob::log::write ERROR {$errmsg}
		::http::cleanup $token
		return [list "PMT_ERR"]
	}

	set response [::http::data $token]


	#
	# Validate the Ventmear reponse
	# Response format {<0|1> <PMT_ID> <REDIRECT_URL>}
	#
	ob::log::write DEBUG {Ventmear response : $response}

	# check for all elements in the response
	if {[llength $response] != 3} {
		return [list "PMT_ERR"]
	}

	# good or bad ?
	if {[lindex $response 0] == 1 } {
		set result	"PMT_URL_REDIRECT"
	} else {
		return [list "PMT_ERR"]
	}

	#check for correct pmt-id
	if {[lindex $response 1] != $PMT(pmt_id)} {
		ob::log::write ERROR {Incorrect PMT_ID Received from VENTMEAR}
		::http::cleanup $token
		return [list "PMT_ERR"]
	}

	set PMT(gw_ret_msg)		$response
	set PMT(gw_redirect_url)	[lindex $response 2]


	#
	# Clean Up and Return
	#
	::http::cleanup $token
	ob::log::write DEBUG {<==::ventmear::make_ventmear_call}

	return $result

}

# Return customer's ccy
proc get_cust_ccy {cust_id} {
	ob::log::write DEBUG {==> get_cust_ccy}

	if {[catch {set rs [tb_db::tb_exec_qry get_1pay_ccy $cust_id]} msg]} {
		ob::log::write ERROR {==> unable to get currency for $cust_id}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob::log::write ERROR {==> unable to get currency for $cust_id, [db_get_nrows $rs] returned}
		return 0
	}
	set ccy [db_get_col $rs 0 ccy_code]

	db_close $rs

	return $ccy
}

# Hard code rules for this here for now
proc is_1pay_cust {cust_id} {

	ob::log::write DEBUG {==> is_1pay_cust}

	set ccy [get_cust_ccy $cust_id]

	return [expr {$ccy == "RMB" || ($ccy == "HKD" && [OT_CfgGet USE_VENTMEAR_FOR_HKD_PMT 0])}]
}

proc is_1pay_ccy {ccy} {
	ob::log::write DEBUG {==> is_1pay_ccy $ccy}

	return [expr {$ccy == "RMB" || $ccy == "HKD"}]
}

proc set_1pay_cpmtype {cpm_id {op 1}} {
	if {$op} {
		set type OP
	} else {
		set type ""
	}

	if [catch {
		tb_db::tb_exec_qry update_cpm_type $type $cpm_id
	} msg] {
		ob::log::write ERROR {Unable to update custpaymthd.type for cpm_id $cpm_id: $msg}
	}
}

proc get_1pay_status {cpm_id} {
	if [catch {
		set rs [tb_db::tb_exec_qry get_cpm_type $cpm_id]
	} msg] {
		ob::log::write ERROR {Unable to get custpaymthd.type for cpm_id $cpm_id: $msg}
	}
	return [db_get_col $rs 0 type]
}

ventmear_init

}
