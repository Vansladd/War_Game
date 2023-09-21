# $Id: neteller.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2003 Orbis Technology Ltd. All rights reserved.
#
# Neteller payment gateway functionality
#
# Required Configuration:
#
# NETELLER_URL_DEP			URL for Neteller Deposits
# NETELLER_URL_WTD			URL for Neteller Withdrawals
# NETELLER_MERCHANT_ID
# NETELLER_MERCHANT_KEY
# NETELLER_MERCHANT_PASS
#
# Optional Configuration:
#
# NETELLER_TIMEOUT			Timeout for contacting Neteller servers
#
# Synopsis:
#
# Procedures:
# OB_neteller::reg                          Register new pay method.
# OB_neteller::get_neteller                 Get neteller details from DB
# OB_neteller::verify_neteller_id_not_used  Checks to see if a given neteller id already exists
# OB_neteller::delete_cpm
# OB_neteller::check_prev_pmt
# OB_neteller::dep                          Make a deposit
# OB_neteller::wtd                          Make a withdrawal
# OB_neteller::auth                         Check the status of a given payment
# OB_neteller::get_neteller
# OB_neteller::reg
# OB_neteller::verify_neteller_id_not_used
# OB_neteller::send_wtd                       Sends withdral request to Neteller.

namespace eval OB_neteller {
	variable NETELLER
	variable ERROR_CODES_DEP
	variable ERROR_CODES_WTD
	variable CFG
}

# One time initialisation.
# Set up error code lookup array and call query initialisation.
#
#  OB_neteller::init
#
proc _init {} {
	variable ERROR_CODES_DEP
	variable ERROR_CODES_WTD
	variable ERROR_CODES_AUTH
	variable OB_neteller::CFG

	array set ERROR_CODES_AUTH {
		1001 ERR_NTLR_ID_NOT_RECEIVED
		1002 TRANSACTION_NOT_FOUND
		2001 ERR_NTLR_MISSING_INFO
		2002 ERR_NTLR_TXN_NOT_FINISHED
		2003 ERR_NTLR_TXN_HAS_FAILED
		2004 ERR_NTLR_TXN_NOT_FOUND
	}

	array set ERROR_CODES_DEP {
		500  ERR_NTLR_LIMIT             ;# this is a known bug of Neteller's older servers - should be 1005
		1001 ERR_NTLR_MISSING_FIELD
		1002 ERR_NTLR_INVALID_FIELD
		1003 ERR_NTLR_INVALID_FIELD
		1004 ERR_NTLR_INVALID_MERCHANT
		1005 ERR_NTLR_LIMIT
		1006 ERR_NTLR_MERCHANT_FAULT
		1007 ERR_NTLR_INVALID_ACCOUNT
		1008 ERR_NTLR_INVALID_SECUREID
		1009 ERR_NTLR_CLIENT_SUSPENDED
		1010 ERR_NTLR_NO_MONEY
		1011 ERR_NTLR_INVALID_ACCOUNT   ;# only from Direct Accept option
		1012 ERR_NTLR_INVALID_FIELD     ;# only from Direct Accept option
		1013 ERR_NTLR_LIMIT             ;# only from Direct Accept option
		1014 ERR_NTLR_ACCOUNT_FAULT     ;# only from Direct Accept option
		1015 ERR_NTLR_INVALID_CURRENCY
		1016 ERR_NTLR_UNKNOWN
		1017 ERR_NTLR_TEST_MERCHANT
		1018 ERR_NTLR_MERCHANT_FAULT
		1019 ERR_NTLR_INVALID_CURRENCY
		1020 ERR_NTLR_INVALID_TEST_ACCOUNT
		1021 ERR_NTLR_INVALID_FIELD_LENGTH
		1023 ERR_NTLR_NOT_ACCEPTED_TERMS
		1024 ERR_NTLR_BLOCKED_REGION
		1025 ERR_NTLR_INVALID_VERSION
		1026 ERR_NTLR_NOT_REGISTERED
		1027 ERR_NTLR_BLOCK_INSTACASH
		5000 ERR_NTLR_INVALID_API_COM
	}

	array set ERROR_CODES_WTD {
		3011 ERR_NTLR_INVALID_ACCOUNT
		3013 ERR_NTLR_LIMIT
		3014 ERR_NTLR_LIMIT
		3015 ERR_NTLR_INVALID_AMOUNT
		3017 ERR_NTLR_INVALID_CURRENCY
		3026 ERR_NTLR_BLOCKED_REGION
		3027 ERR_NTLR_INVALID_FIELD_LENGTH
		3028 ERR_NTLR_BLOCKED_REGION
		3029 ERR_NTLR_BLOCKED_REGION
		5000 ERR_NTLR_INVALID_API_COM

	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set OB_neteller::CFG(pmt_receipt_format) [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set OB_neteller::CFG(pmt_receipt_tag)    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set OB_neteller::CFG(pmt_receipt_format) 0
		set OB_neteller::CFG(pmt_receipt_tag)    ""
	}

	package require pmt_validate
	package require net_socket
	package require tdom
	package require util_appcontrol

	_prep_queries

}

#
# Store queries required by procedures
#
proc _prep_queries {} {

	global SHARED_SQL

	set SHARED_SQL(neteller.new_account) {
		execute procedure pCPMInsNeteller (
			p_cust_id          = ?,
			p_oper_id          = ?,
			p_auth_wtd         = 'Y',
			p_auth_dep         = 'Y',
			p_transactional    = 'Y',
			p_neteller_id      = ?,
			p_allow_duplicates = ?,
			p_strict_check     = ?
		)
	}

	set SHARED_SQL(neteller.txn) {
		execute procedure pPmtInsNeteller (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_commission     = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_transactional  = 'Y',
			p_j_op_type      = ?,
			p_oper_id        = ?,
			p_unique_id      = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?,
			p_overide_min_wtd= ?,
			p_call_id        = ?
		)
	}

	set SHARED_SQL(neteller.get_cpm) {
		select *
		from
			tCPMNeteller as n,
			tAcct        as a,
			tCustPayMthd as p
		where
			n.cpm_id  = p.cpm_id  and
			p.cust_id = a.cust_id and
			p.status  = 'A' and
			p.cust_id = ?
	}

	set SHARED_SQL(neteller.complete) {
		execute procedure pPmtUpdNeteller (
			p_pmt_id       = ?,
			p_status       = ?,
			p_j_op_type    = ?,
			p_gw_uid       = ?,
			p_extra_info   = ?
		)
	}

	set SHARED_SQL(neteller.set_unknown) {
		update
			tPmt
		set
			status = 'U'
		where
			pmt_id = ?
	}

	set SHARED_SQL(neteller.check_prev_pmt) {
		select first 1
			p.pmt_id
		from
			tPmt p,
			tCPMNeteller n
		where
			p.cpm_id      = n.cpm_id and
			n.neteller_id = ? and
			n.cust_id     = ? and
			p.status not in ('N','X')
	}

	set SHARED_SQL(neteller.get_pmt_sort) {
		select
			p.payment_sort
		from
			tPmt p,
			tCPMNeteller n
		where
			p.cpm_id      = n.cpm_id and
			n.cust_id     = ? and
			p.pmt_id      = ?
	}

	set SHARED_SQL(neteller.cpm_remove) {
		update
			tCustPayMthd
		set
			status = 'X'
		where
			cpm_id = ?
	}

	set SHARED_SQL(neteller.id_already_used) {
		select
			n.cpm_id
		from
			tCPMNeteller n,
			tCustPayMthd cpm
		where
			n.cpm_id = cpm.cpm_id and
			cpm.cust_id <> ? and
			n.neteller_id = ?
         }

        set SHARED_SQL(neteller.id_used_and_active) {
                select
                    n.cpm_id
                from
                    tCPMNeteller n,
                    tCustPayMthd cpm
                where
                    n.neteller_id = ? and
                    n.cpm_id = cpm.cpm_id and
                    cpm.pay_mthd = 'NTLR' and
                    cpm.status <> 'X'
         }

	        # query used to get data to send to the payment non-card ticker
        set SHARED_SQL(neteller.get_payment_ticker_data) {
            select
                 c.cust_id,
                 c.cr_date as cust_reg_date,
                 c.username,
                 c.notifyable,
                 c.country_code,
                 cr.fname,
                 cr.lname,
                 cr.email,
                 cr.code,
                 cr.addr_city,
                 cr.addr_postcode,
                 cr.addr_country,
                 a.balance,
                 ccy.exch_rate
            from
                 tcustomer c,
                 tcustomerreg cr,
                 tacct a,
                 tCcy ccy
            where
                 a.acct_id = ? and
                 a.cust_id = cr.cust_id and
                 cr.cust_id = c.cust_id and
                 a.ccy_code = ccy.ccy_code
       }

}

#
# marks cpm as removed in the db
#
proc OB_neteller::delete_cpm {cust_id} {

	variable NETELLER

	# first locate the cpm_id
	if {![get_neteller $cust_id]} {
		return [list 0 "Failed to remove existing cpm: $msg" PMT_ERR]
	}

	# Remove the card
	if {[catch {
		set rs [tb_db::tb_exec_qry neteller.cpm_remove $NETELLER(cpm_id)]} msg]
	} {
		ob::log::write ERROR {Failed to remove existing card: $msg}
		return [list 0 "Failed to remove existing cpm: $msg" PMT_ERR]
	}

	return [list 1]
}

proc OB_neteller::check_prev_pmt {cust_id neteller_id} {

	# search for previous successfuly payments

	if {[catch {set rs [tb_db::tb_exec_qry neteller.check_prev_pmt $neteller_id $cust_id]} msg]} {
		ob::log::write ERROR {failed to check prev pmts on neteller account: $msg}
		return 1
	}

	set result [expr {[db_get_nrows $rs] > 0}]

	db_close $rs

	return $result
}

# Used to check the status of an unknown payment and update the payment
# accordingly
proc OB_neteller::auth {cust_id pmt_id} {

	variable NETELLER

	ob::log::write INFO {OB_neteller::auth $cust_id $pmt_id}

	# first locate the cpm_id
	if {![get_neteller $cust_id]} {
		return [list 0 "Failed to get customer details" -42]
	}

	#
	# Only can do this for deposits. Will double-check we actually have a deposit.

	if {[catch {
		set rs [tb_db::tb_exec_qry neteller.get_pmt_sort $cust_id $pmt_id]
	} msg]} {
		ob::log::write ERROR $msg
		db_close $rs
		return [list 0 "Can't recheck withdrawal" PMT_ERR]
	}

	set rows [db_get_nrows $rs]

	if {$rows == 0} {
		db_close $rs
		return [list 0 "Can't recheck withdrawal" PMT_ERR]
	}

	if {$rows > 1} {
		#Shouldn't happen(!)
		ob::log::write ERROR {More than one cpm returned}
		db_close $rs
		return [list 0 "Can't recheck withdrawal" PMT_ERR]
	}

	set payment_sort [db_get_col $rs 0 payment_sort]
	db_close $rs

	if {$payment_sort != "D"} {
		ob::log::write ERROR {pmt_id $pmt_id payment sort not deposit: $payment_sort}
		return [list 0 "Can't recheck withdrawal" PMT_ERR]
	}

	return [_send 0 "-" $pmt_id "DEP" "-" "-" AUTH]
}


proc OB_neteller::dep {amt currency unique_id secure_id {source I} {oper_id ""} {comm_list {}}} {

	variable NETELLER
	variable CFG

	# OVS
	if {[OT_CfgGet FUNC_OVS_VERF_NTLR_CHK 1] && [OT_CfgGet FUNC_OVS 0]} {
		set chk_resp [verification_check::do_verf_check \
			"NTLR" \
			"D" \
			$NETELLER(acct_id)]

		if {![lindex $chk_resp 0]} {
			return [list 0 [lindex $chk_resp 2]]
		}
	}

	set NETELLER(secure_id) $secure_id

	# Make sure the NETELLER array has been populated in the current request
	if {$NETELLER(req_id) != [reqGetId]} {
		ob::log::write ERROR "Error: NETELLER array not populated in this request"
		return 0
	}

	# get the time payment started
	set time        [clock seconds]
	set pmt_date [clock format $time -format "%Y-%m-%d %H:%M:%S"]

	# if commission list is empty then initialize it with 0 commission
	if {$comm_list == {}} {
		set comm_list [list 0 $amt $amt]
	}

	#
	# get the commission, payment amount and tPmt amount from the list
	#
	set commission  [lindex $comm_list 0]
	set amt         [lindex $comm_list 1]
	set tPmt_amount [lindex $comm_list 2]

	if {[catch {
			set rs [tb_db::tb_exec_qry neteller.txn \
				$NETELLER(acct_id) \
				$NETELLER(cpm_id) \
				D \
				$tPmt_amount \
				$commission \
				[reqGetEnv REMOTE_ADDR] \
				$source\
				DEP\
				$oper_id\
				$unique_id\
				$CFG(pmt_receipt_format)\
				$CFG(pmt_receipt_tag)\
				"N"\
			]
		} msg ]} {
		ob::log::write ERROR "Error: $msg"
		return [list 0 ERR_NTLR_UNKNOWN 30]
	}
	set pmt_id [db_get_coln $rs 0]

	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] } {
		ob_camp_track::record_camp_action $NETELLER(cust_id) "DEP" "OB" $pmt_id
	}

	# Set status to unknown
	if {![_upd_pmt $pmt_id U DEP]} {
		# Bail if we can't set status
		return [list 0 ERR_NTLR_UNKNOWN 31 $pmt_id]
	}
	return [_send $amt $currency $pmt_id DEP $source $pmt_date DEP]

}



# min_overide - whether this withdrawal can ignore the minimum withdrawal limits
# call_id     - (optional) if this is a telebetting transaction, the tCall.call_id for this
proc OB_neteller::wtd {amt currency unique_id \
					{source I} {oper_id ""} {comm_list {}} \
					{min_overide "N"} {call_id ""}} {

	variable NETELLER
	variable CFG

	# if commission list is empty then initialize it with 0 commission
	if {$comm_list == {}} {
		set comm_list [list 0 $amt $amt]
	}

	# Make sure the NETELLER array has been populated in the current request
	if {$NETELLER(req_id) != [reqGetId]} {
		ob::log::write ERROR "Error: NETELLER array not populated in this request"
		return 0
	}

	# OVS
	if { [OT_CfgGet FUNC_OVS 0] &&  [OT_CfgGet FUNC_OVS_VERF_NTLR_CHK 1]} {
		set chk_resp [verification_check::do_verf_check \
			"NTLR" \
			"W" \
			$NETELLER(acct_id)]

		if {![lindex $chk_resp 0]} {
			return [list 0 [lindex $chk_resp 2]]
		}
	}

	# get the time payment started
	set time        [clock seconds]
	set pmt_date [clock format $time -format "%Y-%m-%d %H:%M:%S"]

	#
	# get the commission, payment amount and tPmt amount from the list
	#
	set commission  [lindex $comm_list 0]
	set amt         [lindex $comm_list 1]
	set tPmt_amount [lindex $comm_list 2]

	if {[catch {
		set rs [tb_db::tb_exec_qry neteller.txn \
			$NETELLER(acct_id) \
			$NETELLER(cpm_id) \
			W \
			$tPmt_amount \
			$commission \
			[reqGetEnv REMOTE_ADDR] \
			$source\
			WTD\
			$oper_id\
			$unique_id\
			$CFG(pmt_receipt_format)\
			$CFG(pmt_receipt_tag)\
			$min_overide\
			$call_id \
		]
	} msg ]} {
		ob::log::write ERROR $msg
		return [list 0 ERR_NTLR_UNKNOWN 50]
	}

	set pmt_id [db_get_coln $rs 0]
	db_close $rs

	# Do not send if we need to do a fraud check on the payment
	set process_pmt [ob_pmt_validate::chk_wtd_all\
		$NETELLER(acct_id)\
		$pmt_id\
		"NTLR"\
		"----"\
		$tPmt_amount\
		$currency]

	if {!$process_pmt} {
		return [list 2 NTLR_PENDING 52 $pmt_id]
	}


	# Do not send the wtd request to Neteller
	# if CFG is set to 1
	# This means that withdrawals are queued in the db
	# and processed via the admin screens
	if {[OT_CfgGet NETELLER_PENDING_WITHDRAWALS 0]} {
		return [list 2 NTLR_PENDING 52 $pmt_id]
	}

	OB_neteller::send_wtd $pmt_id $tPmt_amount $currency $source $pmt_date WTD

}

proc OB_neteller::send_wtd {pmt_id amt currency source pmt_date v_type} {

	# Set status to unknown
	if {![_upd_pmt $pmt_id U WTD]} {
		# Bail if we can't set status
		return [list 0 ERR_NTLR_UNKNOWN 51 $pmt_id]
	}
	return [_send $amt $currency $pmt_id WTD $source $pmt_date $v_type]
}


proc _upd_pmt {pmt_id status type {gw_uid ""} {ext_info ""}} {

	if {$status=="U"} {
		set qry neteller.set_unknown
	} else {
		set qry neteller.complete
	}

	set payment_sort [expr {$type=="DEP"?"D":"W"}]

	set fail [catch {
		tb_db::tb_exec_qry $qry $pmt_id $status $type $gw_uid $ext_info
	} msg]

	if {$fail} {
		ob::log::write ERROR {Unable to set payment status to $status}
		ob::log::write ERROR {for pmt_id $pmt_id: $msg}
	}

	return [expr !$fail]
}

# Get pay method details from DB.
# Returns pmt_id of existing neteller payment method.
# If cpm_id is passed, multiple Neteller accounts are allowed
# but we only return the id of the matching cpm_id
# Returns 0 if account doesn't exist.
proc OB_neteller::get_neteller {cust_id {cpm_id 0}} {

	variable NETELLER

	if {[catch {
		set rs [tb_db::tb_exec_qry neteller.get_cpm $cust_id]
	} msg]} {
		ob::log::write ERROR $msg
		db_close $rs
		return 0
	}

	set rows [db_get_nrows $rs]
	if {$rows == 0} {
		db_close $rs
		return 0
	}

	if {$rows > 1 && $cpm_id == 0} {
		#Shouldn't happen(!)
		ob::log::write ERROR {More than one cpm returned}
		db_close $rs
		return 0
	}

	# 1 row
	catch {unset NETELLER}

	set NETELLER(req_id) [reqGetId]
	set NETELLER(cust_id) $cust_id

	for {set r 0} {$r < $rows} {incr r} {
		set r_neteller_id [db_get_col $rs $r neteller_id]
		set r_acct_id     [db_get_col $rs $r acct_id]
		set r_cpm_id      [db_get_col $rs $r cpm_id]

		# if we passed a cpm_id, only store the matching one
		if {$cpm_id == 0 || $cpm_id == $r_cpm_id} {
			set NETELLER(neteller_id) $r_neteller_id
			set NETELLER(acct_id)     $r_acct_id
			set NETELLER(cpm_id)      $r_cpm_id
		}
	}

	db_close $rs
	return $NETELLER(neteller_id)
}

proc OB_neteller::reg {cust_id neteller_id {oper_id -1} {allow_duplicate "N"} {strict_check "Y"}} {

	variable NETELLER

	if {[catch {
		set rs [
			tb_db::tb_exec_qry neteller.new_account\
				$cust_id\
				$oper_id\
				$neteller_id\
				$allow_duplicate\
				$strict_check
		]
	} msg]} {
		ob::log::write ERROR $msg
		return [list 0 $msg]
	}

	set nrows [db_get_nrows $rs]

	if {$nrows != 1} {
		set msg "Rows returned does not equal 1. Returned $nrows rows for cust_id $cust_id"
		ob_log::write ERROR {OB_neteller::reg: $msg}
		ob_db::rs_close $rs
		return [list 0 NTLR_INSERT_ERR]
	}

	set cpm_id     [db_get_coln $rs 0 0]
	set cpm_status [db_get_coln $rs 0 1]
	ob_db::rs_close $rs

	if {$strict_check == "N" && $cpm_status == "S"} {
		set msg "Inserted a Neteller payment method with cpm_id = $cpm_id, but it was immediately suspended"
		ob::log::write INFO {OB_neteller::reg: $msg}
		return [list 2 $cpm_id NTLR_DUP_ACCT]
	}

	# Populate NETELLER array
	get_neteller $cust_id

	return [list 1 $NETELLER(cpm_id)]
}

# Checks to see if the passed neteller id already exists for another account
proc OB_neteller::verify_no_duplicate_id {cust_id neteller_id} {

	if {[catch {
		set rs [tb_db::tb_exec_qry neteller.id_already_used $cust_id $neteller_id]
	} msg] } {
		ob::log::write ERROR {Failed to execute OB_neteller::verify_no_duplicate_id: $msg}
		db_close $rs
		return 0
	}

	if {[db_get_nrows $rs] != 0} {
		db_close $rs
		return 0
	}

	db_close $rs
	return 1
}

# Checks to see if the passed neteller id already exists and is active
proc OB_neteller::verify_neteller_id_not_used {neteller_id} {

        if {[catch {
           set rs [tb_db::tb_exec_qry neteller.id_used_and_active $neteller_id]

        } msg] } {
            ob::log::write ERROR {Failed to execute verify_neteller_id_not_used: $msg}
            db_close $rs
            return 0
        }
        if {[db_get_nrows $rs] != 0} {
            db_close $rs
            return 0
        }

        db_close $rs
        return 1

}


# Send a payment request to Neteller and parse the response.
#
# If auth is set, we're checking the status of an existing payment rather
# than making a new one
#
# type can be one of:
#    DEP  - Deposit
#    WTD  - Withdrawal
#
# v_type can be one of:
#    DEP  - Deposit
#    WTD  - Withdrawal
#    AUTH - Authorisation
proc _send {amt currency pmt_id type source pmt_date v_type} {
	variable ERROR_CODES_${v_type}

   	# Figure out the connection settings for this API.
	set api_url     [OT_CfgGet NETELLER_URL_$v_type]
	set api_timeout [OT_CfgGet NETELLER_TIMEOUT 0]

	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $api_url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {Bad Neteller URL: $msg}
		return {0 ERR_NTLR_NOCONTACT 61}
	}

	set params_nv [_build_query_$v_type $amt $currency $pmt_id]

	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "POST" \
		           -form_args  $params_nv \
		           $api_url]
	} msg]} {
		ob::log::write ERROR {Unable to build Neteller request: $msg}
		return {0 ERR_NTLR_NOCONTACT 62}
	}

   	ob::log::write INFO {Neteller args: [join $params_nv " "]}

	# Cater for the unlikely case that we're not using HTTPS.
	set tls [expr {$api_scheme == "http" ? -1 : ""}]

	# Send the request to Neteller.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout $api_timeout \
		    -req_timeout  $api_timeout \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob::log::write ERROR {Unsure whether request reached Neteller:\
		                      send_req blew up with $msg}
		return {0 ERR_NTLR_UNKNOWN 63}
	}

	if {$status != "OK"} {
		# Is there a chance this request might actually have got to Neteller?
		if {[::ob_socket::server_processed $req_id]} {
			ob::log::write ERROR \
			  {Unsure whether request reached Neteller: status was $status}
			::ob_socket::clear_req $req_id
			return {0 ERR_NTLR_UNKNOWN 64}
		} else {
			ob::log::write ERROR \
			  {Unable to send request to Neteller: status was $status}
			::ob_socket::clear_req $req_id
			return {0 ERR_NTLR_NOCONTACT 65}
		}
	}

	set response [string trim [::ob_socket::req_info $req_id http_body]]
	::ob_socket::clear_req $req_id
	ob_log::write INFO {Neteller Response Body: $response}

	parse_xml::parseBody $response
	upvar parse_xml::XML_RESPONSE XML
	ob::log::write INFO {Neteller response:}
	foreach {n v} [array get XML] {
		ob::log::write INFO {  $n = $v}
	}

	# XML returned for withdrawals start with <instantpayout>
	# Deposits and Authorisations use <netdirect>
	set element [expr {$v_type=="WTD"?"instantpayout":"netdirect"}]

	# Retrieve pmt_id from response in case we have crossed wires...
	if {[info exists XML($element,custom_1)]} {
		if {$pmt_id != $XML($element,custom_1)} {

			# Send message to payment ticker (status = 'U')
			neteller_send_pmt_ticker \
			                        $pmt_id\
			                        $pmt_date\
			                        $type\
			                        $currency\
			                        $amt\
			                        $source\
			                        "U"

			#We have the wrong message. Bail
			return [list 0 ERR_NTLR_UNKNOWN 12 $pmt_id]
		}
	}

	if {![info exists XML($element,approval)]} {
		# Send message to payment ticker (status = 'U')
		_neteller_send_pmt_ticker \
		                        $pmt_id\
		                        $pmt_date\
		                        $type\
		                        $currency\
		                        $amt\
		                        $source\
		                        "U"

		# Leave status as unknown ?
		ob::log::write ERROR {Unknown XML Format}
		return [list 0 ERR_NTLR_UNKNOWN 13 $pmt_id]
	}

	if {$XML($element,approval)=="no"} {

		# Set status to N early doors
		if {![_upd_pmt $pmt_id N $type "" $XML($element,error)]} {


			ob::log::write ERROR {Unable to update table status}
			# Send message to payment ticker  (status = 'U')
			_neteller_send_pmt_ticker \
			                        $pmt_id\
			                        $pmt_date\
			                        $type\
			                        $currency\
			                        $amt\
			                        $source\
			                        "U"

			ob::log::write ERROR {Unable to update table status}
			return [list 0 ERR_NTLR_UNKNOWN 14 $pmt_id]
		}

		# Send message to payment ticker (status = 'N')
		_neteller_send_pmt_ticker \
		                        $pmt_id\
		                        $pmt_date\
		                        $type\
		                        $currency\
		                        $amt\
		                        $source\
		                        "N"

		if {![info exists XML($element,error)]} {
			ob::log::write ERROR {Unknown XML Format (no error element)}
			return [list 0 ERR_NTLR_UNKNOWN 15 $pmt_id]
		}

		set code $XML($element,error)

		if {[info exists ERROR_CODES_${v_type}($code)]} {
			ob::log::write ERROR {error code $code}


			# Yuuuck, gets the value from ERROR_CODES_DEP(1002) for example
			return [list 0 [subst $[subst ERROR_CODES_${v_type}($code)]] $code]
		}

		ob::log::write ERROR {No error message in array for code $code}
		return [list 0 ERR_NTLR_UNKNOWN $code $pmt_id]
	}

	# Everything has hopefully gone OK
	if {![info exists XML($element,trans_id)]} {
		# Send message to payment ticker (status = 'U')
		_neteller_send_pmt_ticker \
		                        $pmt_id\
		                        $pmt_date\
		                        $type\
		                        $currency\
		                        $amt\
		                        $source\
		                        "U"

		ob::log::write ERROR {No trans_id in response}
		return [list 0 ERR_NTLR_UNKNOWN 16 $pmt_id]
	}

	set gw_uid $XML($element,trans_id)

	if {![_upd_pmt $pmt_id Y $type $gw_uid]} {
		# Send message to payment ticker (status = 'U')
		_neteller_send_pmt_ticker \
		                        $pmt_id\
		                        $pmt_date\
		                        $type\
		                        $currency\
		                        $amt\
		                        $source\
		                        "U"
		return [list 0 ERR_NTLR_UNKNOWN 17 $pmt_id]
	}

	# Send message to payment ticker (status = 'Y')
	_neteller_send_pmt_ticker \
	                        $pmt_id\
	                        $pmt_date\
	                        $type\
	                        $currency\
	                        $amt\
	                        $source\
	                        "Y"

	return [list 1 $pmt_id]
}

# Create encoded query for withdrawal
proc _build_query_WTD {amt currency pmt_id} {

	variable OB_neteller::NETELLER

	set err ""
	set err_code [OT_CfgGet NETELLER_SIMERROR ""]
	if {$err_code != ""} {
		set err "error"
		ob::log::write INFO {Neteller: Simulating error $err_code}
	}

	set query [list\
		version       [OT_CfgGet NETELLER_WTD_VER 4.0]\
		amount        $amt\
		currency      $currency\
		test          [OT_CfgGet NETELLER_TEST 0]\
		merchant_id   [OT_CfgGet NETELLER_MERCHANT_ID]\
		merch_key     [OT_CfgGet NETELLER_MERCHANT_KEY]\
		merch_pass    [OT_CfgGet NETELLER_MERCHANT_PASS]\
		net_account   $NETELLER(neteller_id)\
		merch_transid $pmt_id\
		custom_1      $pmt_id\
		$err          $err_code
	]

	ob::log::write INFO {Making withdrawal request to Neteller for $amt $currency (payment #$pmt_id)}

	return $query
}

# Create encoded query for deposit
proc _build_query_DEP {amt currency pmt_id} {

	variable OB_neteller::NETELLER

	set err ""
	set err_code [OT_CfgGet NETELLER_SIMERROR ""]
	if {$err_code != ""} {
		set err "error"
		ob::log::write INFO {Neteller: Simulating error $err_code}
	}

	set query [list\
		version       [OT_CfgGet NETELLER_DEP_VER 4.1]\
		amount        $amt\
		currency      $currency\
		test          [OT_CfgGet NETELLER_TEST 0]\
		net_account   $NETELLER(neteller_id)\
		secure_id     $NETELLER(secure_id)\
		merchant_id   [OT_CfgGet NETELLER_MERCHANT_ID ""]\
		merch_key     [OT_CfgGet NETELLER_MERCHANT_KEY]\
		merch_transid $pmt_id\
		custom_1      $pmt_id\
		$err          $err_code
	]

	ob::log::write INFO {Making deposit request to Neteller for $amt $currency (payment #$pmt_id)}

	return $query
}

# Create encoded query for deposit
proc _build_query_AUTH {amt currency pmt_id} {

	variable OB_neteller::NETELLER

	set err ""
	set err_code [OT_CfgGet NETELLER_SIMERROR ""]
	if {$err_code != ""} {
		set err "error"
		ob::log::write INFO {Neteller: Simulating error $err_code}
	}

	set query [list\
		merchant_id   [OT_CfgGet NETELLER_MERCHANT_ID ""]\
		merch_transid $pmt_id\
		merch_key     [OT_CfgGet NETELLER_MERCHANT_KEY]\
		merch_pass    [OT_CfgGet NETELLER_MERCHANT_PASS]\
		test          [OT_CfgGet NETELLER_TEST 0]
	]

	ob::log::write INFO {Making authorisation request to Neteller (payment #$pmt_id)}

	return $query
}

# Create encoded query for neteller quick sign-up form
proc OB_neteller::build_query_SIGN_UP {cust_id} {

	# get customer information to be passed to NETeller Quick Sign-up form
	if {[catch {set rs [OB_register::get_cust_details $cust_id]} msg]} {
		ob::log::write ERROR {build_query_SIGN_UP : Failed to find customers details : $msg}
		return 0
	}

	set fname        [urlencode [db_get_col [lindex $rs 1] 0 fname]]
	set title        [urlencode [db_get_col [lindex $rs 1] 0 title]]
	set lname        [urlencode [db_get_col [lindex $rs 1] 0 lname]]
	set addr_1       [urlencode [db_get_col [lindex $rs 1] 0 addr_street_1]]
	set addr_2       [urlencode [db_get_col [lindex $rs 1] 0 addr_street_2]]
	set city         [urlencode [db_get_col [lindex $rs 1] 0 addr_city]]
	set postcode     [urlencode [db_get_col [lindex $rs 1] 0 addr_postcode]]
	set country      [urlencode [db_get_col [lindex $rs 1] 0 country_code]]
	set phone        [urlencode [db_get_col [lindex $rs 1] 0 telephone]]
	set email        [urlencode [db_get_col [lindex $rs 1] 0 email]]
	set mobile       [urlencode [db_get_col [lindex $rs 1] 0 mobile]]
	set dob          [urlencode [db_get_col [lindex $rs 1] 0 dob]]

	# format the date as MM/DD/YYYY as required by NETeller
	set dob          [db_get_col [lindex $rs 1] 0 dob]
	set day          [string range $dob 8 9]
	set month        [string range $dob 5 6]
	set year         [string range $dob 0 3]
	set dob          "$month%2F$day%2F$year"

	 # Change the county code 'UK' to 'GB' if the United Kingdom is the country code to be passed in the query string as this is required by Neteller
	if {$country=="UK"} {
		set country "GB"
	}

	set NETELLER_URL [OT_CfgGet NETELLER_URL ""]
	set NETELLER_MERCHANT_ID [OT_CfgGet NETELLER_MERCHANT_ID ""]
	set NETELLER_LINK_BACK_URL [OT_CfgGet NETELLER_LINK_BACK_URL ""]

	# create query string to be passed to NETeller Quick Sign-up form
	set qryStr "${NETELLER_URL}?International=True&DOB=$dob&firstname=$fname&lastname=$lname&email=$email&address=$addr_1+$addr_2&city=$city&state=NA&zip=$postcode&country=$country&wphone=$phone&cphone=$mobile&MerchantID=${NETELLER_MERCHANT_ID}&LinkBackURL=${NETELLER_LINK_BACK_URL}"

	return $qryStr
}



# Sends a payment message to the ticker
#
# pmt_id      - id of payment
# pmt_date    - date of payment
# type        - "WTD" for withdrawals,"DEP" for deposits
# ccy_code    - customer currenct
# amount_user - amount in customer currency
# source      - channel
# pmt_status  - status of payment
#

proc _neteller_send_pmt_ticker {
		pmt_id
		pmt_date
		type
		ccy_code
		amount_user
		source
		pmt_status} {

	variable ::OB_neteller::NETELLER

	# Check if this message type is supported
	if {![string equal [OT_CfgGet MONITOR 0] 1] ||
	    ![string equal [OT_CfgGet PAYMENT_TICKER 0] 1]} {
		return 0
	}

	set pay_method "NTLR"
	set ipaddr [reqGetEnv REMOTE_ADDR]

	if {[catch {set rs [tb_db::tb_exec_qry neteller.get_payment_ticker_data $NETELLER(acct_id)]} msg]} {
		ob::log::write ERROR {ep_send_pmt_ticker : Failed to execute qry neteller.get_monitor_details : $msg}
		return 0
	}

	set cust_id       [db_get_col $rs cust_id]
	set username      [db_get_col $rs username]
	set fname         [db_get_col $rs fname]
	set lname         [db_get_col $rs lname]
	set postcode      [db_get_col $rs addr_postcode]
	set country_code  [db_get_col $rs country_code]
	set email         [db_get_col $rs email]
	set reg_date      [db_get_col $rs cust_reg_date]
	set reg_code      [db_get_col $rs code]
	set notifiable    [db_get_col $rs notifyable]
	set acct_balance  [db_get_col $rs balance]
	set addr_city     [db_get_col $rs addr_city]
	set addr_country  [db_get_col $rs addr_country]
	set exch_rate     [db_get_col $rs exch_rate]

	db_close $rs

	set bank_name "N/A"
	set pmt_sort [expr {[string equal $type "WTD"]?"W":"D"}]

	# convert user amount into system ccy
	set amount_sys [format "%.2f" [expr {$amount_user / $exch_rate}]]

	if {[catch {set result [MONITOR::send_pmt_non_card\
	                                 $cust_id\
	                                 $username\
	                                 $fname\
	                                 $lname\
	                                 $postcode\
	                                 $email\
	                                 $country_code\
	                                 $reg_date\
	                                 $reg_code\
	                                 $notifiable\
	                                 $NETELLER(acct_id)\
	                                 $acct_balance\
	                                 "$ipaddr-${addr_country}"\
	                                 "$ipaddr-${addr_city}"\
	                                 $pay_method\
	                                 $ccy_code\
	                                 $amount_user\
	                                 $amount_sys\
	                                 $pmt_id\
	                                 $pmt_date\
	                                 $pmt_sort\
	                                 $pmt_status\
	                                 $NETELLER(neteller_id)\
	                                 $bank_name\
	                                 $source]} msg]} {
		ob::log::write ERROR {_neteller_send_pmt_ticker: Failed to send
		payment monitor message : $msg}
		return 0
	}
	return $result
}

_init
