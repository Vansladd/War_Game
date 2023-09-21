# ==============================================================
# $Id: pmt_auth.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::do_pmt_auth [namespace code do_pmt_auth]


proc do_pmt_auth {} {

	global USERID DB

	if {![op_allowed UpdPaymentStatus]} {
		err_bind "You do not have permission to update customers payment status"
		rebind_request_data
		ADMIN::PMT::do_pmt_query
		return
	}

	set submit_name [reqGetArg SubmitName]

	switch -exact -- $submit_name {
		"UpdMarks"   -
		"UpdMarksFC" -
		"UpdMarksLR" {
			switch -exact -- $submit_name {
				"UpdMarks"   {
					set mark_action [reqGetArg MarkAction]
					set auth "auth_check"
				}
				"UpdMarksFC" {
					set mark_action [reqGetArg MarkActionFC]
					set auth "auth_check_fc"
				}
				"UpdMarksLR" {
					set mark_action [reqGetArg MarkActionLR]
					set auth "auth_check_lr"
				}
				default {error "Unknown submit name"}
			}

			if {$mark_action == "A"} {
				tpBindString $auth "checked"
			} elseif {$mark_action == "D"} {
				tpBindString decl_check "checked"
			} elseif {$mark_action == "U"} {
			}
			ADMIN::PMT::do_pmt_query
			return
		}
		"MarkDecline" {
			tpBindString decl_check "checked"
			ADMIN::PMT::do_pmt_query
			return
		}
		"Authorise" {
			set auth_type "auth"
			set prefix "auth"
			set status "Y"
		}
		"AuthoriseFC" {
			set auth_type "FC"
			set prefix "auth_fc"
			set status "Y"
		}
		"AuthoriseLR" {
			set auth_type "LR"
			set prefix "auth_lr"
			set status "Y"
		}
		"Decline" {
			set auth_type "auth"
			set prefix "decl"
			set status "N"
		}
		"DoPSCPmtRetry" {
			set pmt_id  [reqGetArg pmt_id]
			set cust_id [reqGetArg cust_id]
			do_psc_pmt_retry $pmt_id $cust_id

			set prefix ""
			set status ""
			ADMIN::PMT::do_pmt_query
			return
		}
	}

	# Yucky hack
	# There are Western Union OPs that can only authorise WU payments.
	# To check this, we check all payments to see which are WU and which aren't.
	# Also checking to see if payment is over a certain amount
	set count_wu 0
	set count_other 0
	set count_opa 0
	for {set i 0} {$i < [reqGetArg NumPmts]} {incr i} {
		set pmt_id    [reqGetArg "row_${i}"]
		set pmt_amt   [reqGetArg "sys_amt_${pmt_id}"]
		if {[reqGetArg "${prefix}_${pmt_id}"] == "Y"} {
			set pay_mthd  [reqGetArg "pay_mthd_${i}"]
			if {[reqGetArg "pay_mthd_${i}"] == "WU"} {
				incr count_wu
			} elseif {$pmt_amt >= [OT_CfgGet AUTH_LARGE_PMT 6000] && ($prefix == "auth")} {
				incr count_opa
			} else {
				incr count_other
			}
		}
	}

	set count_total [expr $count_wu + $count_other + $count_opa]

	if {![OT_CfgGet FUNC_PERM_AUTH_LARGE_PMT 0]} {
		incr count_other $count_opa
		set count_opa 0
	}

	if {([expr $count_other + $count_opa] > 0 || $count_wu == 0) && ![op_allowed UpdPaymentStatus]} {
		err_bind "You do not have permission to update customers payment status"
		rebind_request_data
		ADMIN::PMT::do_pmt_query
		return
	}

	if {$count_wu > 0 && ![op_allowed PmtWUAuth]} {
		err_bind "You do not have permission to update Western Union customers payment status"
		rebind_request_data
		ADMIN::PMT::do_pmt_query
		return
	}

	if {$count_opa > 0 && ![op_allowed PmtAuthDeclineHighVa]} {
		err_bind "You do not have permission to update customers payments of this amount"
		rebind_request_data
		ADMIN::PMT::do_pmt_query
		return
	}

	set num_payments [reqGetArg NumPmts]
	set auth_code    [reqGetArg auth_code]

	set output ""
	for {set i 0} {$i < $num_payments} {incr i} {

		set pmt_id    [reqGetArg "row_${i}"]

		if {[reqGetArg "${prefix}_${pmt_id}"] == "Y"} {

			set pay_mthd  [reqGetArg "pay_mthd_${i}"]

			if {[lsearch {"CHQ" "BANK" "GDEP" "GWTD" "CC" "CSH" "BC" "BASC" "WU" "ENET" "NTLR" "MB" "ENVO" "C2P" "PPAL" "SHOP" "CB" "UKSH" "IKSH" "PSC"} $pay_mthd] == -1} {

				error "invalid payment type"
			}

			# need to retreive some information on the payment before we do
			# anything to the payment so we know whether or not we should call
			# check action, safer than relying on the args from the page

			set pmt_detail_sql {
				select
					a.cust_id,
					p.payment_sort,
					p.source,
					p.amount,
					p.status
				from
					tAcct a,
					tPmt p
				where
					a.acct_id = p.acct_id and
					p.pmt_id = ?
			}

			set stmt [inf_prep_sql $DB $pmt_detail_sql]
			set res  [inf_exec_stmt $stmt $pmt_id]
			inf_close_stmt $stmt

			if {[db_get_nrows $res] != 1} {
				err_bind "Failed to retreive details for pmt_id $pmt_id"
				rebind_request_data
				ADMIN::PMT::do_pmt_query
				return
			}

			# we need to set whether it is a deposit or withdrawal
			set cust_id    [db_get_col $res 0 cust_id]
			set pay_sort   [db_get_col $res 0 payment_sort]
			set amount     [db_get_col $res 0 amount]
			set source     [db_get_col $res 0 source]
			set old_status [db_get_col $res 0 status]

			db_close $res

			#
			# Authorise this payment id
			#
			if {$auth_type == "LR"} {
				set result [auth_payment_LR $pmt_id]
			} elseif {$auth_type == "FC"} {
				set result [auth_payment_FC $pmt_id]
			} else {
				set result [auth_payment_${pay_mthd} $pmt_id $status $USERID $auth_code "" $old_status]
			}

			if {$result != "OK"} {
				lappend output $result
			} else {

				# If we are authorising a deposit then we need to call freebets
				# to indicate a deposit.
				# Exception to the rule - card payments (through payment_CC.tcl)
				# if we are authorising late(L) card payments dont call freebets
				# it does it for you

				if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0] &&
					[reqGetArg SubmitName] == "Authorise" &&
					[string match $pay_sort "D"] &&
					!(${pay_mthd} == "CC" &&
					  ($old_status == "L" || $old_status == "P"))
				} {

					OB_freebets::check_action \
						[list DEP DEP1] \
						$cust_id \
						"" \
						$amount \
						"" \
						"" \
						"" \
						"" \
						$pmt_id \
						"PMT"\
						"" \
						0 \
						$source
				}

				# send email
				if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {

					set email_type_list [list]

					if {[string match $pay_sort "D"]} {
						lappend email_type_list DEPOSIT
					} else {
						lappend email_type_list WITHDRAWAL
					}

					# is it an authorise or a deline?
					if {[reqGetArg SubmitName] == "Authorise"} {
						lappend email_type_list ACCEPTED
					} elseif {[reqGetArg SubmitName] == "Decline"} {
						lappend email_type_list DENIED
					}

					# create the email type from the pay_sort and submitname
					set email_type [join $email_type_list "_"]

					set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC \
											"queue_email"]
					set params [list $email_type \
								$cust_id \
								E \
								PMT \
								$pmt_id]

					# send email to customer
					if {[catch {set res [eval $queue_email_func $params]} msg]} {
						OT_LogWrite 2 "Failed to queue $email_type email, $msg"
					}
				}
			}
		}
	}
	if {$output != ""} {
		err_bind [join $output "<br>\n"]
	} else {
		if {$count_total > 0} {
			if {[reqGetArg SubmitName] == "Authorise"} {
				msg_bind "Payments successfully authorised"
			} elseif {[reqGetArg SubmitName] == "Decline"} {
				msg_bind "Payments successfully declined"
			}
		}
	 }
	do_pmt_query
}

proc auth_payment_LR {pmt_id} {

	global DB
	global USERID

	# Check permissions TODO

	set sql {
		update tPmtPendStatus set
			large_ret_auth = 'Y',
			lr_auth_user_id = ?,
			lr_auth_date    = current
		where
			pmt_id = ?
		and
			large_ret_auth = 'P'
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERID $pmt_id
	inf_close_stmt $stmt

	return "OK"
}

proc auth_payment_FC {pmt_id} {

	global DB
	global USERID

	# Check permissions TODO

	set sql {
		update tPmtPendStatus set
			fraud_check_auth = 'Y',
			fc_auth_user_id = ?,
			fc_auth_date    = current
		where
			pmt_id = ?
		and
			fraud_check_auth = 'P'
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $USERID $pmt_id
	inf_close_stmt $stmt

	return "OK"
}

proc do_psc_pmt_retry {pmt_id cust_id} {

	global DB

	# This function is accessed by the retry button on the Payment
	# search results screen. It will call the "get serial numbers" psc
	# function. If then the state is S, the "execute debit" request will be
	# sent to complete the payment.
	# --------------------------------------------------------------
	set log_prefix "do_psc_pmt_retry"

	ob::log::write INFO {$log_prefix: pmt_id = $pmt_id, cust_id = $cust_id}

	# Get disposition state
	set success     [ob_psc::execute_deposit $pmt_id $cust_id]

	if {[lindex $success 0]} {
		set msg_txt  "Payment ID $pmt_id: successfully processed."
	} else {
		if {[lindex $success 1] == "PMT_PSC_ERR_UNEXPECTED_STATE"} {
			err_bind "Error processing payment $pmt_id - Unable to fulfil the transaction due to incomplete transaction details."
		} else {
			err_bind "Error processing payment $pmt_id - [lindex $success 1]"
		}
		return
	}

	msg_bind $msg_txt
	return
}



}
