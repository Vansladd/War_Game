# ==============================================================
# $Id: payment_PB.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

#
# Requires shared_tcl/payment_gateway.tcl
#

package require util_appcontrol

namespace eval payment_PB {

namespace export pb_pmt_init
namespace export pb_pmt_make_payment


#-----------------------------------------------------------------
# Initialise the queries and stored proc calls
#-----------------------------------------------------------------
proc pb_pmt_init {} {

	global SHARED_SQL

	#
	# to retrieve details of this paybox account
	#
	set SHARED_SQL(pb_pmt_get_pb_number) {
		select
			pb_number
		from
			tcpmpb
		where
			cpm_id = ?
	}

	#
	# to retrieve cust_id
	#
	set SHARED_SQL(pb_pmt_acct_info) {
		select
			cust_id,
			ccy_code
		from
			tAcct
		where
			acct_id = ?
	}

	#
	# insering paybox payments
	#
	set SHARED_SQL(pb_pmt_insert_pmt) {
		execute procedure pPmtInsPB (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_extra_info = ?,
			p_transactional = ?,
			p_min_amt = ?,
			p_max_amt = ?,
			p_call_id = ?,
			p_j_op_type = ?
		)
	}

	#
	# Update paybox payments
	#
	set SHARED_SQL(pb_pmt_upd_pmt) {
		execute procedure pPmtUpdPB (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?
		)
	}

	#
	# retrieve the just stored apacs ref no
	#
	set SHARED_SQL(pb_pmt_get_apacs_ref) {
		execute procedure pPmtGetPBRefNo (
			p_pmt_id = ?
		);
	}

	set SHARED_SQL(pb_pmt_upd_gtwy_params) {
		update tpmtpb
		set
			pg_acct_id = ?,
			pg_host_id = ?
		where
			pmt_id = ?
	}
}

#-----------------------------------------------------------------
# Make the paybox payment
#
# PARAMETERS:
#	acct_id -    the tAcct.acct_id for the account
#	oper_id -    the tAdmin.user_id if the request is coming from an
#	             admin user
#	unique_id -  unique_id to ensure payments are not processed twice
#	pay_sort -   'W' - Withdraw, 'D' - Deposit
#	amount -     amount for the transaction
#	cpm_id -     tCustPayMthd.cpm_id for PB payment method
#   source -     channel making payment
#	extra_info - any misc details to be stored against payment record
#	j_op_type -  tJrnl.j_op_type to record against the journal entry
#	min_amt -    the minimum allowable amount for this transaction
#	max_amt -    the max allowable amount for this transaction
#
# RETURNS:
#
#-----------------------------------------------------------------
proc pb_pmt_make_payment {acct_id oper_id unique_id pay_sort amount cpm_id source {auth_code ""} \
							  {extra_info ""} {j_op_type ""} {min_amt ""} {max_amt ""} {call_id ""} \
							  {admin 0}} {

	OT_LogWrite 5 " ==>pb_pmt_make_payment"

	set DATA(acct_id)       $acct_id
	set DATA(oper_id)       $oper_id
	set DATA(unique_id)     $unique_id
	set DATA(pay_sort)      $pay_sort
	set DATA(amount)        $amount
	set DATA(cpm_id)        $cpm_id
	set DATA(source)        $source
	set DATA(auth_code)     $auth_code
	set DATA(extra_info)    $extra_info
	set DATA(j_op_type)     $j_op_type
	set DATA(min_amt)       $min_amt
	set DATA(max_amt)       $max_amt
	set DATA(call_id)       $call_id
	set DATA(admin)         $admin
	set DATA(transactional) "Y"

	#
	# grab some other data
	#
	set result [pb_pmt_get_data DATA]
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	#
	# verify data and record
	#
	set result [pb_pmt_verify_and_record DATA]
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	#
	# call to proxy
	#
	set result [pb_pmt_do_transaction DATA]
	OT_LogWrite 7 "$result : result"
	if {[lindex $result 0] == 0} {
		unset DATA
		return $result
	}

	set pmt_id $DATA(pmt_id)
	unset DATA

	#
	# return the payment id
	#
	return [list 1 $pmt_id]
}

#-----------------------------------------------------------------
# Retreive the paybox mobile number and account details from the
# database and also the applicable payment gateway details for
# processing the payment
#-----------------------------------------------------------------
proc pb_pmt_get_data {ARRAY} {

	upvar 1 $ARRAY DATA

	set DATA(ip) [reqGetEnv REMOTE_ADDR]

	#
	# retrieve the paybox details
	#
	if [catch {set rs [tb_db::tb_exec_qry pb_pmt_get_pb_number $DATA(cpm_id)]} msg] {
		ob_log::write ERROR {PMT Error retrieving paybox details; $msg}
		return [list 0 "Could not retrieve paybox details: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_NO_PB] PMT_NO_PB]
	}

	set DATA(pb_number)    [db_get_col $rs 0 pb_number]

	db_close $rs


	#
	# Account information
	#
	if [catch {set rs [tb_db::tb_exec_qry pb_pmt_acct_info $DATA(acct_id)]} msg] {
		ob_log::write ERROR {PMT Error retrieving account information; $msg}
		return [list 0 "Could not retrieve account information: $msg" PMT_ERR]
	}

	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_NOCCY] PMT_NOCCY]
	}

	set DATA(ccy_code) [db_get_col $rs 0 ccy_code]
	set DATA(cust_id)  [db_get_col $rs 0 cust_id]

	db_close $rs

	return [list 1]

}

#-----------------------------------------------------------------
# Checks data is valid and that payment method is not blocked etc
# before storing payment details with status 'P' for pending
#-----------------------------------------------------------------
proc pb_pmt_verify_and_record {ARRAY} {

	upvar 1 $ARRAY DATA

	#
	# check the payment sort and grab the ip address (must be deposit)
	#
	if {![info exists DATA(pay_sort)] || $DATA(pay_sort) != "D"} {
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_TYPE] PMT_TYPE]
	}

	#
	# insert the payment record as a pending
	#
	set result [pb_pmt_insert_payment $DATA(acct_id) \
									  $DATA(cpm_id) \
									  $DATA(pay_sort) \
									  $DATA(amount) \
									  $DATA(ip) \
									  $DATA(source) \
									  $DATA(oper_id) \
									  $DATA(unique_id) \
									  $DATA(extra_info) \
									  $DATA(transactional) \
									  $DATA(min_amt) \
									  $DATA(max_amt) \
									  $DATA(call_id) \
									  $DATA(j_op_type)]
	if {![lindex $result 0]} {
		set code [payment_gateway::cc_pmt_get_sp_err_code [lindex $result 1]]
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $code] $code]
	}

	set DATA(pmt_id) [lindex $result 1]

	return [list 1]

}

proc pb_pmt_insert_payment {acct_id cpm_id pay_sort amount ip_addr source oper_id unique_id \
								extra_info transactional min_amt max_amt call_id j_op_type} {

	if [catch {set rs [tb_db::tb_exec_qry pb_pmt_insert_pmt \
									$acct_id \
									$cpm_id \
									$pay_sort \
									$amount \
									$ip_addr \
									$source \
									$oper_id \
									$unique_id \
									$extra_info \
									$transactional \
									$min_amt \
									$max_amt \
									$call_id \
									$j_op_type \
	]} msg] {
		ob_log::write ERROR {PMT Error inserting payment record; $msg}
		return [list 0 $msg]
	}

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $rs 0 0]

	db_close $rs
	return [list 1 $pmt_id]

}

proc pb_pmt_do_transaction {ARRAY} {

	OT_LogWrite 7 " ==> pb_pmt_do_transaction"

	upvar 1 $ARRAY DATA

	set result [pb_pmt_send_to_proxy DATA]

	if {$result == "PMT_UNKNOWN"} {
		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code PMT_ERR] PMT_ERR]

	} elseif {$result != "OK"} {
		#
		# we can decline this payment
		#
		set status "N"
		pb_pmt_auth_payment $DATA(pmt_id) $status $DATA(oper_id)

		return [list 0 [payment_gateway::pmt_gtwy_xlate_err_code $result] $result]
	}

	return [list 1]
}

proc pb_pmt_send_to_proxy {ARRAY} {
	upvar 1 $ARRAY DATA
	variable read_status

	set host    [OT_CfgGet PAYBOX_PROXY_HOST localhost]
	set port    [OT_CfgGet PAYBOX_PROXY_PORT 9908]
	set timeout [OT_CfgGet PAYBOX_PROXY_TIMEOUT 10000]

	# open a socket
	if [catch {set sock [payment_gateway::socket_timeout $host $port $timeout]} msg] {
		OT_LogWrite 1 "ERROR: Caught socket exception: $msg"
		return PMT_NO_SOCKET
	}

	OT_LogWrite 1 "sending ($sock) $DATA(pmt_id):$DATA(oper_id):$DATA(auth_code)"

	if [catch {
		puts $sock "$DATA(pmt_id):$DATA(oper_id):$DATA(auth_code)"
		puts $sock ""

	} msg] {
		OT_LogWrite 1 "failed to send request to paybox : $msg"
		catch {close $sock}
		return PMT_UNKNOWN
	}

	OT_LogWrite 2 "awaiting response..."

	set cancel_id [after $timeout {set payment_PB::read_status "TIMED_OUT"}]
	fileevent $sock readable "payment_PB::pb_pmt_read_data $sock"

	vwait payment_PB::read_status

	after cancel $cancel_id
	fileevent $sock readable {}

	if {$read_status == "TIMED_OUT"} {
		OT_LogWrite 1 "ERROR: Proxy timed out whilst reading response"
		return PMT_UNKNOWN

	} elseif {$read_status == "FAILED"} {
		OT_LogWrite 1 "ERROR: Failed to read response from proxy"
		return PMT_UNKNOWN

	} elseif {$read_status == "OK"} {
		variable msg_${sock}
		set msg [set msg_${sock}]
		return $msg
	}
	error "unknown read status, $read_status"
}


proc pb_pmt_read_data {sock} {
	variable msg_${sock}
	variable read_status

	OT_LogWrite 1 "=> pb_pmt_read_data"

	if {[gets $sock str] >= 0 && ![eof $sock] && $str != ""} {
		OT_LogWrite 2 "append ($sock): $str"
		append msg_${sock} $str
		return
	}

	# end of message received
	set message [set msg_${sock}]
	OT_LogWrite 2 "end of message received ($sock): $message"

	set read_status "OK"
}


proc pb_clean_sock {sock} {
	variable cancel_${sock}

	if {[info exists cancel_${sock}]} {
		after cancel [set cancel_${sock}]
		unset cancel_${sock}
	}
	catch {close $sock}
}




proc pb_pmt_auth_payment {pmt_id status oper_id} {

	if [catch {set rs [tb_db::tb_exec_qry pb_pmt_upd_pmt \
						   $pmt_id \
						   $status \
						   $oper_id]} msg] {

		OT_LogWrite 1 ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
		OT_LogWrite 1 "Error updating payment record; $msg"
		OT_LogWrite 1 ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	}
	catch {	db_close $rs }

}

#
# Initialise this file
#
pb_pmt_init

}
