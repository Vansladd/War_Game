# ==============================================================
# $Id: make_payment.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

namespace export insert_payment_CSH
namespace export auth_payment_CSH

namespace export insert_payment_CHQ
namespace export auth_payment_CHQ

namespace export insert_payment_BANK
namespace export auth_payment_BANK

namespace export insert_payment_GDEP
namespace export auth_payment_GDEP

namespace export insert_payment_GWTD
namespace export auth_payment_GWTD

namespace export auth_payment_CC

namespace export insert_payment_BASC
namespace export auth_payment_BASC

namespace export insert_payment_WU
namespace export auth_payment_WU

namespace export auth_payment_C2P
namespace export auth_payment_CB

#namespace export insert_payment_NTLR
namespace export auth_payment_NTLR

namespace export auth_payment_PPAL

namespace export insert_payment_SHOP
namespace export auth_payment_SHOP

namespace export auth_payment_PSC

proc insert_payment_BC {
	acct_id
	cpm_id
	pay_sort
	amount
	tPmt_amount
	commission
	ipaddr
	source
	oper_id
	unique_id
	betcard_id
	vendor_uname
} {
	if {[catch {set result [OB::BETCARD::insert_customer_payment \
						$acct_id \
						$cpm_id \
						$pay_sort \
						$amount \
						$tPmt_amount \
						$commission \
						$ipaddr \
						$source \
						$oper_id \
						$unique_id \
						$betcard_id \
						$vendor_uname]} msg]} {

		ob::log::write ERROR {Error inserting betcard payment: $msg}
		return [list 0 $msg]
	} else {
	    if {[lindex $result 0] == "err"} {
		return [list 0 [lindex $result 1]]
	    } else {
		return [list 1 [lindex $result 0]]
	    }
	}
}

proc auth_payment_BC {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdBC (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
				$pmt_id \
				$status \
				$oper_id \
				$auth_code]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

proc insert_payment_CSH {
	acct_id
	cpm_id
	pay_sort
	amount
	ipaddr
	source
	oper_id
	unique_id
	outlet
	manager
	id
	id_type
	extra_info
	commission
	tPmt_amount
} {

	global DB

	set sql {
		execute procedure pPmtInsCsh (
			p_acct_id        = ?,
			p_cpm_id         = ?,
			p_payment_sort   = ?,
			p_amount         = ?,
			p_commission     = ?,
			p_ipaddr         = ?,
			p_source         = ?,
			p_oper_id        = ?,
			p_unique_id      = ?,
			p_outlet         = ?,
			p_manager        = ?,
			p_id_serial_no   = ?,
			p_extra_info     = ?,
			p_receipt_format = ?,
			p_receipt_tag    = ?
		)
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set pmt_receipt_format [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set pmt_receipt_tag    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set pmt_receipt_format 0
		set pmt_receipt_tag    ""
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt $acct_id\
	                                       $cpm_id\
	                                       $pay_sort\
	                                       $tPmt_amount\
	                                       $commission\
	                                       $ipaddr\
	                                       $source\
	                                       $oper_id\
	                                       $unique_id\
	                                       $outlet\
	                                       $manager\
	                                       $id\
	                                       $extra_info\
	                                       $pmt_receipt_format\
	                                       $pmt_receipt_tag]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}

	inf_close_stmt $stmt

	set pmt_id [db_get_coln $rs 0 0]

	db_close $rs
	return [list 1 $pmt_id]
}

proc auth_payment_CSH {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdCsh (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?,
			p_extra_info = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
				$pmt_id \
				$status \
				$oper_id \
				$auth_code \
				$reason]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}


proc insert_payment_CHQ {acct_id cpm_id pay_sort amount commission ip source oper_id \
                         unique_id payer chq_date chq_no chq_sort_code chq_acct_no \
                         rec_delivery_ref extra_info tPmt_amount min_amt max_amt} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsChq (
				p_acct_id = ?,
				p_cpm_id = ?,
				p_payment_sort = ?,
				p_amount = ?,
				p_commission = ?,
				p_ipaddr = ?,
				p_source = ?,
				p_oper_id = ?,
				p_unique_id = ?,
				p_payer = ?,
				p_chq_date = ?,
				p_chq_no = ?,
				p_chq_sort_code = ?,
				p_chq_acct_no = ?,
				p_rec_delivery_ref = ?,
				p_extra_info = ?,
				p_min_amt = ?,
				p_max_amt = ?,
				p_receipt_format = ?,
				p_receipt_tag = ?
		)
	}

	if {[OT_CfgGet FUNC_OVERIDE_MIN_MAX_PMT_AMT 0]} {
 		#
		# override the min/max amounts in the admin screens
		#
		set min_amt $amount
		set max_amt $amount
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set pmt_receipt_format [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set pmt_receipt_tag    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set pmt_receipt_format 0
		set pmt_receipt_tag    ""
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$acct_id \
									$cpm_id \
									$pay_sort \
									$tPmt_amount \
									$commission \
									$ip \
									$source \
									$oper_id \
									$unique_id \
									$payer \
									$chq_date \
									$chq_no \
									$chq_sort_code \
									$chq_acct_no \
									$rec_delivery_ref \
									$extra_info \
									$min_amt \
									$max_amt \
									$pmt_receipt_format \
									$pmt_receipt_tag]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}


proc auth_payment_CHQ {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdChq (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?,
			p_extra_info = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
				$pmt_id \
				$status \
				$oper_id \
				$auth_code \
	            $reason]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

proc insert_payment_WU {acct_id cpm_id pay_sort amount commission ip source oper_id unique_id \
                        extra_info mtcn req_location} {
	global DB

	# Check that there's an mtcn number
	if {$pay_sort == "D" && $mtcn == ""} {
		return [list 0 "You need to enter an mtcn number"]
	}

	# Check that mtcn is actually a number
	if {![regexp -- {^\d*$} $mtcn]} {
			return [list 0 "The mtcn must be a number"]
	}

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsWU (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_amount = ?,
			p_payment_sort = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_wu_extra_info = ?,
			p_wu_mtcn = ?,
			p_wu_req_location = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$acct_id \
									$cpm_id \
									$amount \
									$pay_sort \
									$commission \
									$ip \
									$source \
									$oper_id \
									$unique_id \
									$extra_info \
									$mtcn \
									$req_location]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}

proc auth_payment_WU {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdWU (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_wu_mtcn = ?,
			p_wu_extra_info = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
		                                        $pmt_id \
		                                        $status \
		                                        $oper_id \
		                                        $auth_code \
	                                            $reason]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

proc insert_payment_BANK {acct_id cpm_id pay_sort amount commission ip source oper_id unique_id \
                          code extra_info tPmt_amount min_amt max_amt} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsBank (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_code = ?,
			p_extra_info = ?,
			p_min_amt = ?,
			p_max_amt = ?,
			p_receipt_format = ?,
			p_receipt_tag = ?
		)
	}

	if {[OT_CfgGet FUNC_OVERIDE_MIN_MAX_PMT_AMT 0]} {
 		#
		# override the min/max amounts in the admin screens
		#
		set min_amt $amount
		set max_amt $amount
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set pmt_receipt_format [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set pmt_receipt_tag    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set pmt_receipt_format 0
		set pmt_receipt_tag    ""
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$acct_id \
									$cpm_id \
									$pay_sort \
									$tPmt_amount \
									$commission \
									$ip \
									$source \
									$oper_id \
									$unique_id \
									$code \
									$extra_info \
									$min_amt \
									$max_amt \
									$pmt_receipt_format \
									$pmt_receipt_tag]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}

proc auth_payment_BANK {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
			execute procedure pPmtUpdBank (
					p_pmt_id = ?,
					p_status = ?,
					p_oper_id = ?,
					p_auth_code = ?,
					p_extra_info = ?
			)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
													$pmt_id \
													$status \
													$oper_id \
													$auth_code \
													$reason]} msg] {

			OT_LogWrite 2 "Error updating payment record; $msg"

			# strip out leading code from error response
			regsub -all {IX000 } $msg "" msg
			return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

proc insert_payment_BASC {acct_id cpm_id pay_sort amount commission ip oper_id unique_id \
                          desc ext_ref tPmt_amount min_amt max_amt} {
	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsBasic (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_desc = ?,
			p_ext_ref = ?,
			p_min_amt = ?,
			p_max_amt = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set res [inf_exec_stmt $stmt \
		$acct_id \
		$cpm_id \
		$pay_sort \
		$tPmt_amount \
		$commission \
		$ip \
		$oper_id \
		$unique_id \
		$desc \
		$ext_ref \
		$min_amt\
		$max_amt]} msg]} {
			OT_LogWrite 2 "Error inserting payment record; $msg"

			# strip out leading code from error response
			regsub -all {IX000 } $msg "" msg
			return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res

	# auto-authorise payment
	return [list 1 $pmt_id]
}

proc auth_payment_BASC {pmt_id status oper_id auth_code {auth_note ""} {prev_status ""}} {
	global DB


	# Check to see that the customer has had an active card
	# registered for at least the specified n number of days
	# before we allow a withdrawal to be authorised

	if {$status == "Y" && [OT_CfgGet PMT_BANK_WTD_MIN_REG_DAYS 0] != 0} {

		set n_days [OT_CfgGet PMT_BANK_WTD_MIN_REG_DAYS 0]

		set sql [subst {
			select
				p.acct_id
			from
				tPmt p
			where
				p.payment_sort = 'W' and

				not exists (
					select
						1
					from
						tPmt p2
					where
						p2.acct_id = p.acct_id and
						p2.cr_date < CURRENT - interval ($n_days) day to day and
						p2.status = 'Y'
				) and

				p.pmt_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $pmt_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 1} {

			# in this case then we have
			#    a) a withdrawal
			#    b) no registered pay method before given n days

			return PMT_WTIME
		}

		db_close $rs
	}

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdBasic (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?,
			p_extra_info  = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set res [inf_exec_stmt $stmt \
		$pmt_id \
		$status \
		$oper_id \
		$auth_code \
	    $extra_info]} msg]} {
			OT_LogWrite 2 "Error updating payment record; $msg"

			# strip out leading code from error response
			regsub -all {IX000 } $msg "" msg
			return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res

	# Send email
	if {[catch {ADMIN::PMT::send_basic_payment_email $pmt_id} msg]} {
		# A problem occurred - log and inform admin person
		ob::log::write ERROR {Failed to send email for payment $pmt_id  with error $msg}
		err_bind [subst "Failed to send email : $msg"]
	}

	return OK
}

proc insert_payment_GDEP {acct_id cpm_id amount commission ip source oper_id unique_id \
                          pay_type blurb extra_info tPmt_amount min_amt max_amt} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsGdep (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_pay_type = ?,
			p_blurb = ?,
			p_extra_info = ?,
			p_min_amt = ?,
			p_max_amt = ?
		)
	}

	if {[OT_CfgGet FUNC_OVERIDE_MIN_MAX_PMT_AMT 0]} {
 		#
		# override the min/max amounts in the admin screens
		#
		set min_amt $amount
		set max_amt $amount
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$acct_id \
									$cpm_id \
									$tPmt_amount \
									$commission \
									$ip \
									$source \
									$oper_id \
									$unique_id \
									$pay_type \
									$blurb \
									$extra_info\
									$min_amt\
									$max_amt]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}


proc auth_payment_GDEP {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdGdep (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?,
			p_extra_info = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$pmt_id \
									$status \
									$oper_id \
									$auth_code \
	                                $reason]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}


proc insert_payment_GWTD {acct_id cpm_id amount commission ip source oper_id unique_id \
                          pay_type blurb extra_info tPmt_amount min_amt max_amt} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsGwtd (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_pay_type = ?,
			p_blurb = ?,
			p_extra_info = ?,
			p_min_amt = ?,
			p_max_amt = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$acct_id \
									$cpm_id \
									$tPmt_amount \
									$commission \
									$ip \
									$source \
									$oper_id \
									$unique_id \
									$pay_type \
									$blurb \
									$extra_info\
									$min_amt\
									$max_amt]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}


proc auth_payment_GWTD {pmt_id status oper_id auth_code args} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpdGwtd (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
									$pmt_id \
									$status \
									$oper_id \
									$auth_code]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}


proc auth_payment_NTLR {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB
	set pay_sort  [reqGetArg "pay_sort_$pmt_id"]
	set pay_amt  [reqGetArg "pay_amt_$pmt_id"]
	set pay_ccy  [reqGetArg "pay_ccy_$pmt_id"]
	set cust_id  [reqGetArg "cust_id_$pmt_id"]
	# get the time payment started
	set time        [clock seconds]
	set pmt_date [clock format $time -format "%Y-%m-%d %H:%M:%S"]
	set source [OT_CfgGet CHANNEL "I"]

	if {![OT_CfgGet FUNC_SEND_NTLR_PMT 0] ||
		($status == "N" && $pay_sort == "W") ||
		($prev_status == "U" && [OT_CfgGet FUNC_ALLOW_UNKNOWN_UPD_NTLR 0])} {

		if {$reason == ""} {
			if {$status == "Y"} {
				set reason "Authorised via Admin"
			} else {
				set reason "Declined via Admin"
			}
		}

		#
		# execute the procedure
		#
		set sql {
			execute procedure pPmtUpdNeteller (
				p_pmt_id = ?,
				p_status = ?,
				p_gw_uid = ?,
				p_oper_id = ?,
				p_j_op_type = ?,
				p_auth_code = ?,
				p_transactional = ?,
				p_extra_info = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		if [catch {set res [inf_exec_stmt $stmt \
										$pmt_id \
										$status \
										""\
										$oper_id \
										""\
										$auth_code \
										""\
										$reason]} msg] {

			OT_LogWrite 2 "Error updating payment record; $msg"

			# strip out leading code from error response
			regsub -all {IX000 } $msg "" msg
			return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
		}
		inf_close_stmt $stmt
		db_close $res
		return OK
	} elseif {$status == "Y" && $pay_sort == "W"} {
		OT_LogWrite 2 "Sending to neteller $pmt_id"
		OT_LogWrite 2 "cust id : $cust_id"
		set ntlr_id [OB_neteller::get_neteller $cust_id]
		if {$ntlr_id == 0} {
			return "Error while getting Neteller Id"
		}
		set ntlr_result [OB_neteller::send_wtd $pmt_id $pay_amt $pay_ccy $source $pmt_date WTD]

		if { [lindex $ntlr_result 0] == 0} {
			ob::log::write ERROR {Error inserting Neteller payment $pmt_id  with error [lindex $ntlr_result 1]}
			return "Failed to withdraw amount : [lindex $ntlr_result 1]"
		} else {
			return OK
		}
	} else {
		ob::log::write ERROR {Can not Authorise / Decline Neteller Deposits $pmt_id}
		return "Can not Authorise / Decline Neteller Deposits"
	}
}


proc auth_payment_CC {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	set pg_type {}

	if {$status == "Y"} {

		set sql {
			select
				p.payment_sort,
				p.acct_id,
				p.amount,
				p.unique_id,
				p.ipaddr,
				p.cpm_id,
				p.source,
				p.status,
				c.gw_auth_code,
				c.gw_uid,
				a.pg_trans_type,
				a.pg_type
			from
				tPmt p,
				tPmtCC c,
				outer tPmtGateAcct a
			where
				p.pmt_id = ? and
				c.pmt_id = p.pmt_id and
				c.pg_acct_id = a.pg_acct_id
		}

		set stmt [inf_prep_sql $DB $sql]
		if [catch {set res [inf_exec_stmt $stmt $pmt_id]} msg] {
			OT_LogWrite 2 "Error retrieving payment details: $msg"

			# strip out leading code from error response
			regsub -all {IX000 } $msg "" msg
			return $msg
		}
		set pay_sort     [db_get_col $res 0 payment_sort]
		set acct_id      [db_get_col $res 0 acct_id]
		set amount       [db_get_col $res 0 amount]
		set unique_id    [db_get_col $res 0 unique_id]
		set ipaddr       [db_get_col $res 0 ipaddr]
		set cpm_id       [db_get_col $res 0 cpm_id]
		set gw_auth_code [db_get_col $res 0 gw_auth_code]
		set source       [db_get_col $res 0 source]
		set old_status   [db_get_col $res 0 status]
		set trans_type   [db_get_col $res 0 pg_trans_type]
		set gw_uid       [db_get_col $res 0 gw_uid]
		set pg_type      [db_get_col $res 0 pg_type]
		set auto_fulfil  {N}

		if {[db_get_col $res 0 pg_type] == {COMMIDEA_ATH}} {
			set auto_fulfil  {Y}
		}

		inf_close_stmt $stmt
		db_close $res

		if {$trans_type != "E" && [lsearch {P U L} $old_status] == -1} {
			OT_LogWrite 2 "Already handled this payment: $pmt_id"
			return "Failed to authorise payment, payment already processed"
		}

		if {$old_status == "U"} {
 			set transactional  "Y"
 			set gw_auth_code   ""
 			set gw_ret_code    ""
 			set gw_ret_msg     ""
 			set ref_no         ""
 			set j_op_type      ""
 			set no_settle      0

 			set result [payment_CC::cc_pmt_auth_payment $pmt_id \
 											$status \
 											$oper_id \
 											$transactional \
 											$auth_code \
 											$gw_auth_code \
 											$gw_uid \
 											$gw_ret_code \
 											$gw_ret_msg \
 											$ref_no\
 											$j_op_type \
 											$no_settle \
											"" \
											"" \
											$auto_fulfil \
											""]

 			if {[lindex $result 0] == 0} {
 				return [lindex $result 1]
 			}
 			return OK
 		} elseif {$old_status == "L" && $pg_type == {COMMIDEA_ATH}} {
			inf_begin_tran $DB

			set sql {
				Update tPmt set
					status = 'Y'
				where
					pmt_id = ? and
					status = 'L'
			}

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {inf_exec_stmt $stmt $pmt_id} msg]} {
				err_bind $msg
				inf_rollback_tran $DB
				return "Failed to authorise payment, cannot set status to GOOD"
			}

			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if {$rc != 1} {
				inf_rollback_tran $DB
				return "Failed to authorise payment, problem updating status to GOOD"
			}

			set sql {
				update
					tPmtCC
				set
					fulfilled_at = CURRENT,
					fulfil_status = ?
				where
					pmt_id = ? and
					fulfilled_at is null
			}

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {inf_exec_stmt $stmt "Y" $pmt_id} msg]} {
				err_bind $msg
				inf_rollback_tran $DB
				return "Failed to authorise payment, problem setting fulfillment details"
			}

			set rc   [ inf_get_row_count $stmt ]
			inf_close_stmt $stmt

			if {$rc != 1} {
				inf_rollback_tran $DB
				return "Failed to authorise payment, problem updating status to GOOD"
			}

			inf_commit_tran $DB
			return OK
		}

		#
		# attempt this transaction
		#
		set DATA(pmt_id)        $pmt_id
		set DATA(acct_id)       $acct_id
		set DATA(cpm_id)        $cpm_id
		set DATA(amount)        $amount
		set DATA(unique_id)     $unique_id
		set DATA(oper_id)       $oper_id
		set DATA(auth_code)     $auth_code
		set DATA(gw_auth_code)  $gw_auth_code
		set DATA(pay_sort)      $pay_sort
		set DATA(transactional) "Y"
		set DATA(source)        $source
		set DATA(pay_mthd)      "CC"

		## Needed by DCASH XML
		set DATA(addr_1)        ""
		set DATA(addr_2)        ""
		set DATA(addr_3)        ""
		set DATA(addr_4)        ""
		set DATA(postcode)      ""
		set DATA(cvv2)          ""
		set DATA(bank)          ""

		#
		# Set j_op_type to ''.
		# In theory this is OK, since for Pending payments
		# (ie cleardown withdrawls) the j_op_type isn't
		# used anyway.
		#
		set DATA(j_op_type)     ""

		set DATA(admin)         1

		payment_CC::cc_pmt_get_data DATA

		#
		# reset the ip to the one stored on insert record
		#
		set DATA(ip)            $ipaddr

		#
		# Reason why the payment has been authorized
		#
		set DATA(reason) $reason

		set result [payment_CC::cc_pmt_do_transaction DATA]
		if {[lindex $result 0] == 0} {
			return [lindex $result 1]
		} else {
			return OK
		}

	} elseif {$status == "N"} {

		set sql {
			select
				p.status,
				a.pg_trans_type,
				a.pg_type
			from
				tPmt p,
				tPmtCC c,
				outer tPmtGateAcct a
			where
				p.pmt_id = ? and
				c.pmt_id = p.pmt_id and
				c.pg_acct_id = a.pg_acct_id
		}

		set stmt [inf_prep_sql $DB $sql]
		if [catch {set res [inf_exec_stmt $stmt $pmt_id]} msg] {
			OT_LogWrite 2 "Error retrieving payment details: $msg"
			return $msg
		}

		set old_status [db_get_col $res 0 status]
		set trans_type   [db_get_col $res 0 pg_trans_type]

		set auto_fulfil  {N}

		if {[db_get_col $res 0 pg_type] == {COMMIDEA_ATH}} {
			set auto_fulfil  {Y}
		}

		inf_close_stmt $stmt
		db_close $res

		if {$trans_type != "E" && [lsearch {P U} $old_status] == -1} {
			OT_LogWrite 2 "Already handled this payment: $pmt_id"
			return "Failed to decline payment, payment already processed"
		}

		set transactional  "Y"
		set gw_auth_code   ""
		set gw_uid         ""
		set gw_ret_code    ""
		set gw_ret_msg     ""
		set ref_no         ""
		set j_op_type      ""
		set no_settle      0

		set result [payment_CC::cc_pmt_auth_payment $pmt_id \
										$status \
										$oper_id \
										$transactional \
										$auth_code \
										$gw_auth_code \
										$gw_uid \
										$gw_ret_code \
						  				$gw_ret_msg \
										$ref_no\
										$j_op_type \
										$no_settle \
										"" \
										"" \
										$auto_fulfil \
										""]

		if {[lindex $result 0] == 0} {
			return [lindex $result 1]
		}
		return OK
	}
}


#
# Authorise/Decline a Click2Pay Payment. Authorisation will only
# be available for withdrawals (which will consists of a withdrawal
# request).
#
#  pmt_id - the ID of the payment
#  status - the status of the payment
#  oper_id - the Admin operator ID who is performing the authorisation
#  auth_code - the authorisation code
#  reason - reason for authorising the payment
#
#  returns - 'OK' on  successful authorisation, 0 otherwise
#
proc auth_payment_C2P {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	set pay_sort [reqGetArg "pay_sort_$pmt_id"]

	if {($status == "N" && $pay_sort == "W") ||
		($prev_status == "U" && [OT_CfgGet FUNC_ALLOW_UNKNOWN_UPD_C2P 0])} {

		# Just update the payment don't send to C2P
		if {[catch {set result [ob_click2pay::_upd_pmt_status \
		                              $pmt_id \
		                              $status \
		                              $oper_id \
		                              $pay_sort \
		                              $reason \
		                              "" \
		                              "" \
		                              "" \
		                              $auth_code]\
		} msg]} {
			OT_LogWrite 2 "Error updating payment record; $msg"
			return FAILED_UPD_PMT
		} else {
			return OK
		}

	} elseif {$status == "Y" && $pay_sort == "W"} {

		set pay_amt  [reqGetArg "pay_amt_$pmt_id"]
		set pay_ccy  [reqGetArg "pay_ccy_$pmt_id"]
		set cust_id  [reqGetArg "cust_id_$pmt_id"]
		# get the time payment started
		set current [clock format [clock seconds] -format  {%Y-%m-%d %H:%M:%S}]

		set pmt_status_sql {
			select
				p.acct_id,
				p.unique_id,
				p.cpm_id,
				p.source
			from
				tPmt p
			where
				p.pmt_id = ?
		}

		set stmt [inf_prep_sql $DB $pmt_status_sql]
		if [catch {set res [inf_exec_stmt $stmt $pmt_id]} msg] {
			OT_LogWrite 2 "Error retrieving payment details: $msg"
			return $msg
		}

		set acct_id    [db_get_col $res 0 acct_id]
		set unique_id  [db_get_col $res 0 unique_id]
		set cpm_id     [db_get_col $res 0 cpm_id]
		set source     [db_get_col $res 0 source]

		inf_close_stmt $stmt
		db_close $res

		OT_LogWrite 2 "Making Click2Pay withdrawal"

		#Make withdrawal request to Click2Pay
		set result [ob_click2pay::make_click2pay_transaction $cust_id $acct_id $oper_id $unique_id $pay_sort $pay_amt $cpm_id $source $pay_ccy 1 $pmt_id $reason]

		set ret_msg [lindex $result 1]

		if {[lindex $result 0] == 1} {
			set pmt_id [lindex $result 1]
			OT_LogWrite 2 "CLICK2PAY transaction successful for pmt_id $pmt_id and result = $ret_msg"
			return OK
		} else {
			OT_LogWrite 2 "CLICK2PAY transaction was not successful for pmt_id $pmt_id and result = $ret_msg"
			return $ret_msg
		}
	} else {
		ob::log::write ERROR {Can not Authorise / Decline Click2Pay Deposits $pmt_id}
		return "Can not Authorise / Decline Click2Pay Deposits"
	}
}



#
# Authorise/Decline a MoneyBookers Payment. Authorisation will only
# be available for withdrawals as there's no instant mechanism for
# doing a Deposit (can be done by performing a Re-post)
#
#  pmt_id - the ID of the payment
#  status - the status of the payment
#  oper_id - the Admin operator ID who is performing the authorisation
#  auth_code - the authorisation code
#  reason - reason for authorising the payment
#
#  returns - 'OK' on  successful authorisation, 0 otherwise
#
proc auth_payment_MB {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	set pay_sort  [reqGetArg "pay_sort_$pmt_id"]

	if {$prev_status == "U" &&
		[OT_CfgGet FUNC_ALLOW_UNKNOWN_UPD_MB 0]} {

		# Just update the payment status - this assumes an offline
		# check has been done with Moneybookers to check the payment
		# from their end.
		if {[catch {set result [payment_MB::update_pmt $pmt_id $status]} msg]} {
			return $msg
		}

		if {$result == 0} {
			return FAILED_UPD_PMT
		} else {
			return OK
		}
	}

	if {$pay_sort == "W"} {
		if {$status == "Y"} {
			set result [payment_MB::do_wtd $pmt_id]
			if {[lindex $result 0] == 0} {
				return [lindex $result 1]
			} else {
				return OK
			}
		} else {

			if {[catch {set result [payment_MB::update_pmt $pmt_id $status]} msg]} {
				return $msg
			}

			if {$result == 0} {
				return FAILED_UPD_PMT
			} else {
				return OK
			}
		}
	} else {
		ob::log::write ERROR {Can not Authorise / Decline MoneyBooker Deposits $pmt_id}
		return "Can not Authorise / Decline MoneyBooker Deposits"
	}
}


#
# Update an Envoy payment
#
proc auth_payment_ENVO {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	set result [payment_ENVO::update_pmt $pmt_id $status]

	if {[lindex $result 0]} {
		return OK
	} else {
		return [lindex $result 1]
	}
}

# Wrapper function to authorise Quickcash payment
#
proc auth_payment_UKSH { pmt_id status user_id auth_code \
	{reason ""} {pmt_status ""}
} {
	return [_auth_payment_ukash $pmt_id $status $user_id $auth_code $reason \
		$pmt_status]
}

# Wrapper function to authorise Ukash International payment
#
proc auth_payment_IKSH {pmt_id status user_id auth_code \
	{reason ""} {pmt_status ""}
} {
	return [_auth_payment_ukash $pmt_id $status $user_id $auth_code $reason \
		$pmt_status]
}

# Authorise or decline a Quickcash payment
#
# Helper function to authorise Ukash payment.
# UKSH/IKSH uses same DB tables
#
# pmt_id     - the pmt in question
# status     - status to change to
# user_id    - admin user id
# auth_code  -
# pmt_status - the current status
# pmt_sort   - deposit/withdrawal (D/W)
#
proc _auth_payment_ukash {pmt_id status user_id auth_code \
	{reason ""} {pmt_status ""}
} {
	global DB

	OT_LogWrite 10 {_auth_payment_ukash ($pmt_id, $status, $user_id, \
		$auth_code, $pmt_status, $pmt_sort)}

	set sql [subst {
		execute procedure pPmtUpdUkash (
			p_pmt_id    = $pmt_id,
			p_status    = '$status',
			p_oper_id   = $user_id,
			p_auth_code = '$auth_code'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if [catch {set res [inf_exec_stmt $stmt]} msg] {
		OT_LogWrite 1 "Error authorising pmt: $msg"
		return $msg
	}

	inf_close_stmt $stmt
	db_close $res
	return OK
}



#
# Authorise or decline a PayPal payment
#
# pmt_id     - the pmt in question
# status     - status to change to
# user_id    - admin user id
# auth_code  - auth code
# reason     - reason for authorising the payment
#
proc auth_payment_PPAL { pmt_id status user_id auth_code {reason ""} {prev_status ""}} {

	global DB

	OT_LogWrite 10 {auth_payment_PPAL($pmt_id,$status,$user_id,$auth_code,)}

	set sql [subst {
		execute procedure pPmtUpdPayPal (
			p_pmt_id     = $pmt_id,
			p_status     = '$status',
			p_oper_id    = $user_id,
			p_auth_code  = '$auth_code',
			p_extra_info = '$reason'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	if [catch {set res [inf_exec_stmt $stmt]} msg] {
		return FAILED_UPD_PMT
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

#
# Insert a new shop payment
#
#
proc insert_payment_SHOP {acct_id cpm_id payment_sort amount commission ip source oper_id unique_id \
                          min_amt max_amt shop_id shop_pmt_type ticket_num staff_member} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtInsShop (
			p_acct_id = ?,
			p_cpm_id = ?,
			p_payment_sort = ?,
			p_amount = ?,
			p_commission = ?,
			p_ipaddr = ?,
			p_source = ?,
			p_oper_id = ?,
			p_unique_id = ?,
			p_min_amt = ?,
			p_max_amt = ?,
			p_shop_id = ?,
			p_shop_pmt_type = ?,
			p_ticket_num = ?,
			p_staff_member = ?,
			p_receipt_format = ?,
			p_receipt_tag = ?
		)
	}

	if {[OT_CfgGet FUNC_OVERIDE_MIN_MAX_PMT_AMT 0]} {
 		#
		# override the min/max amounts in the admin screens
		#
		set min_amt $amount
		set max_amt $amount
	}

	# Receipt formatting options
	if {[OT_CfgGet PMT_RECEIPT_FUNC 0]} {
		set pmt_receipt_format [OT_CfgGet PMT_RECEIPT_FORMAT 0]
		set pmt_receipt_tag    [OT_CfgGet PMT_RECEIPT_TAG   ""]
	} else {
		set pmt_receipt_format 0
		set pmt_receipt_tag    ""
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
						$acct_id \
						$cpm_id \
						$payment_sort \
						$amount \
						$commission \
						$ip \
						$source \
						$oper_id \
						$unique_id \
						$min_amt \
						$max_amt \
						$shop_id \
						$shop_pmt_type \
						$ticket_num \
						$staff_member \
						$pmt_receipt_format \
						$pmt_receipt_tag]} msg] {
		OT_LogWrite 2 "Error inserting payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [list 0 $msg]
	}
	inf_close_stmt $stmt

	#
	# return the payment id
	#
	set pmt_id [db_get_coln $res 0 0]

	db_close $res
	return [list 1 $pmt_id]
}

#
# Authorise a Shop Payment
#
proc auth_payment_SHOP {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	#
	# execute the procedure
	#
	set sql {
		execute procedure pPmtUpd (
			p_pmt_id = ?,
			p_status = ?,
			p_oper_id = ?,
			p_auth_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set res [inf_exec_stmt $stmt \
					$pmt_id \
					$status \
					$oper_id \
					$auth_code]} msg] {

		OT_LogWrite 2 "Error updating payment record; $msg"

		# strip out leading code from error response
		regsub -all {IX000 } $msg "" msg
		return [payment_gateway::pmt_gtwy_xlate_err_code $msg]
	}
	inf_close_stmt $stmt
	db_close $res
	return OK
}

#
# Authorise/Decline a ClickandBuy Payment. Authorisation will only
# be available for withdrawals (which will consists of a withdrawal
# request).
#
#  pmt_id - the ID of the payment
#  status - the status of the payment
#  oper_id - the Admin operator ID who is performing the authorisation
#  auth_code - the authorisation code
#  reason - reason for authorising the payment
#
#  returns - 'OK' on  successful authorisation, 0 otherwise
#
proc auth_payment_CB {pmt_id status oper_id auth_code {reason ""} {prev_status ""}} {

	global DB

	set pay_sort [reqGetArg "pay_sort_$pmt_id"]

	if { ($prev_status == "U" &&
		[OT_CfgGet FUNC_ALLOW_UNKNOWN_UPD_CB 0])
		|| ($prev_status == "P" && $status=="N") } {

		# Just update the payment status - this assumes an offline
		# check has been done with Click and Buy to check the payment
		# from their end.
		if {[catch {set result [ob_clickandbuy::update_pmt \
			$pmt_id \
			$status]\
		} msg]} {
			OT_LogWrite 2 "Error updating payment record; $msg"
			return FAILED_UPD_PMT
		} else {
			return OK
		}
	}

	if {$status == "N" && $pay_sort == "W"} {
		set pay_amt  [reqGetArg "pay_amt_$pmt_id"]
		set pay_ccy  [reqGetArg "pay_ccy_$pmt_id"]
		set cust_id  [reqGetArg "cust_id_$pmt_id"]

		ob_db::begin_tran

		# Mark the payment as bad
		if {[catch {set result [ob_clickandbuy::update_pmt \
		                              $pmt_id \
		                              $status \
					      'N']\
		} msg]} {
			OT_LogWrite 2 "Error updating payment record; $msg"
			ob_db::rollback_tran
			return FAILED_UPD_PMT
		} else {
			ob_db::commit_tran
			return OK
		}

	} elseif {$status == "Y" && $pay_sort == "W"} {

		OT_LogWrite 2 "Making Clickandbuy withdrawal"

		#Make withdrawal request to ClickandBuy
		set result  [ob_clickandbuy::send_easy_collect_wtd $pmt_id "P"]
		set ret_msg [lindex $result 1]

		if {[lindex $result 0] == 1} {
			set pmt_id [lindex $result 1]
			OT_LogWrite 2 "CLICKANDBUY transaction successful for pmt_id $pmt_id and result = $ret_msg"
			return OK
		} else {
			OT_LogWrite 2 "CLICKANDBUY transaction was not successful for pmt_id $pmt_id and result = $ret_msg"
			return "CLICKANDBUY transaction was not successful for pmt_id $pmt_id and result = $ret_msg"
		}
	} else {
		ob::log::write ERROR {Can not Authorise / Decline ClickandBay Deposits $pmt_id}
		return "Can not Authorise / Decline ClickandBuy Deposits"
	}
}



#
# Authorise or decline a PSC payment
#
# pmt_id     - the pmt in question
# status     - status to change to
# user_id    - admin user id
# auth_code  - not relevant for PSC but passed in by generic pmt handler
# reason     - not relevant for PSC but passed in by generic pmt handler
# prev_status -  not relevant for PSC but passed in by generic pmt handler
#
proc auth_payment_PSC { pmt_id status user_id {auth_code ""} {reason ""} {prev_status ""}} {

	OT_LogWrite 10 "auth_payment_PSC - $pmt_id - $status"

	if {[ob_psc::update_pmt $pmt_id $status]} {
		return OK
	} else {
		return FAILED_UPD_PMT
	}
}


# close namespace
}
