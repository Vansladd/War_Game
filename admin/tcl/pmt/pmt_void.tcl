# ==============================================================
# $Id: pmt_void.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::GoPmtProcRequest [namespace code pmt_proc_request]

proc pmt_proc_upd args {

	global DB USERNAME USERID

	set err_play 0
	set pmt_id    [reqGetArg pmt_id]
	set auth_code [reqGetArg auth_code]

	if {[OT_CfgGet VALIDATE_PMT_AUTH_CODE_LOCALLY 1] && ![regexp {^[0-9][0-9][0-9][0-9]+$} $auth_code]} {
		err_bind "Auth code must be numeric and at least 4 digits long"
		return
	}

	set sql {
		Update tPmt set
		    auth_code = ?
		where
		    pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $auth_code $pmt_id} msg]} {
		err_bind $msg
		return
	}
    inf_close_stmt $stmt

	msg_bind "Authorisation code has been updated"
}


proc pmt_proc_decline {previous_status} {

	global DB USERNAME USERID

	set cust_id [reqGetArg cust_id]
	set amt     [reqGetArg amount]

	#
	# check payment status is still referred
	#
	set sql {
		select
			p.status,
			p.payment_sort
		from
			tPmt p
		where
		    p.pmt_id = ?
	}

	set pmt_id [reqGetArg pmt_id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		error "Failed to locate payment to undo"
	}

	set status [db_get_col $rs 0 status]
	set payment_sort [db_get_col $rs 0 payment_sort]

	# Do not transfer money back if we are declining an I status payment
	# UNLESS it is a withdrawal
	if {$status != "I" || $payment_sort == "W"} {
		if {$status == "R" || $status == "I"} {
			set jrnl_desc "Declined payment referral"
		} elseif {$status == "N"} {
			if {$previous_status == "L"} {
				set jrnl_desc "Declined previous payment"
			} else {
				error "This payment has already been declined"
			}
		} elseif {$status == "L"} {
			set jrnl_desc "Declined later payment"
		} elseif {$status == "P"} {
			set jrnl_desc "Declined pending payment"
		} else {
			error "This is not a payment (status=$status) that can be undone"
		}

		db_close $rs

		if {$payment_sort == "D"} {
			set op_type "DCAN"
			set amount  [expr 0.00-$amt]
			set withdrawable "Y"

		} elseif {$payment_sort == "W"} {
			set op_type "WCAN"
			set amount  [expr $amt]
			set withdrawable "Y"
		}

		#
		# cancel the payment
		#
		if [catch {
			set sql [subst {
				execute procedure pPmtCancel(
					p_cust_id = ?,
					p_adjust = ?,
					p_pmt_id = ?,
					p_desc = '$jrnl_desc',
					p_withdrawable = ?,
					p_adminuser = ?,
					p_j_op_type = ?
					)
			}]
			set stmt_dep [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt_dep $cust_id $amount $pmt_id $withdrawable $USERNAME $op_type
			inf_close_stmt $stmt_dep

		} msg]  {
			error "Failed to cancel payment: $msg"
		}
	}

	#
	# update payment to bad
	#
	if {$status != "N" && $status != "X"} {
		if [catch {
			set sql {
				update tPmt set
				   status = 'N',
				   processed_at = current,
				   processed_by = ?
				where
					pmt_id = ?
			}
			set stmt_ref [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt_ref $USERID [reqGetArg pmt_id]
			inf_close_stmt $stmt_ref
		} msg] {
			error "Failed to mark payment as declined - accounts have already been adjusted: $msg"
		}
	}

	if {$status == "I" && $payment_sort == "D"} {
		msg_bind "Payment declined successfully - no balance adjustments have been made"
	} else {
		msg_bind "Payment declined successfully - balance adjusted OK"
	}
}


proc pmt_proc_void args {
#
# Void the specified bets and undo the deposit
#

	global DB USERNAME USERID

	set cust_id [reqGetArg cust_id]
	set amt     [reqGetArg amount]

	set n [reqGetNumVals]

	array set void_bet [list]
	set void_bet(ids) [list]
	for {set i 0} {$i < $n} {incr i} {
		set j [reqGetNthName $i]
		if {[regexp {^void_bet_id_([0-9]*)$} $j match bet_id] == 1} {
			lappend void_bet(ids) $bet_id
		}
	}

	#
	# check payment status is still referral pending or bad
	# and that the there is a payment jrnl entry associated with it
	#
	set sql {
		select
			p.status
		from
			tPmt p,
			tJrnl j
		where
		    p.pmt_id = ?
		and j.acct_id = p.acct_id
		and j.j_op_ref_id = p.pmt_id
		and j.j_op_ref_key = 'GPMT'
		and j.j_op_type in ('DREF','DRES')
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt [reqGetArg pmt_id]]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		error "Failed to locate payment to undo"
	}

	set status [db_get_col $rs 0 status]

	if {$status != "R" && $status != "L" && $status != "N"} {
		error "Cannot cancel bets: no associated referral/late/bad payment"
	}
	db_close $rs

	#
	# Get bet details. Make sure the sum of stakes being voided is at least
	# the sum of the deposit being cancelled
	#
	set len [llength $void_bet(ids)]

	set bet_sql {
		select
			b.stake,
			b.tax,
			b.num_lines
		from
			tBet b
		where
			b.bet_id = ?
	}

	set void_bet_amt 0.00

	for {set i 0} {$i < $len} {incr i} {
		set stmt_bet [inf_prep_sql $DB $bet_sql]
		set bet_id [lindex $void_bet(ids) $i]
		set res [inf_exec_stmt $stmt_bet $bet_id]
		inf_close_stmt $stmt_bet
		set nrows [db_get_nrows $res]
		if {$nrows != 1} {
			db_close $res
			error "Details for bet $bet_id cannot be found"
		}
		set void_bet($bet_id,stake)     [db_get_col $res stake]
		set void_bet($bet_id,tax)       [db_get_col $res tax]
		set void_bet($bet_id,num_lines) [db_get_col $res num_lines]
		set void_bet_amt [expr $void_bet_amt + $void_bet($bet_id,stake) + $void_bet($bet_id,tax)]
		db_close $res
	}

	if {$amt > $void_bet_amt} {
		error "The bets to be voided add up only to a value of [format %.2f $void_bet_amt]"
	}

	set ok_msg "Bets have been voided"
	#
	# decline the payment for referral and late only.
	# A bad payment will already have had the payment declined
	#
	if {$status=="R" || $status=="L"} {
		if [catch {pmt_proc_decline $status} msg] {
			error "$ok_msg... $msg"
		}
		append ok_msg " and payment has been marked as declined"
	}

    #
    # void the selected bets... this is not done within a transaction!
    #

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" } {
		set enable_freebets "Y"
	} else {
		set enable_freebets "N"
	}

	if {[OT_CfgGet RETURN_FREEBETS_VOID "FALSE"] == "TRUE"} {
		set return_freebets_void Y
	} else {
		set return_freebets_void N
	}

	if {[OT_CfgGet RETURN_FREEBETS_CANCEL "FALSE"] == "TRUE"} {
		set return_freebets_cancel Y
	} else {
		set return_freebets_cancel N
	}

	# If the bet has been voided do we still want to trigger
	# the activation of Freebet tokens (if tOffer.on_settle = 'Y')
	if [OT_CfgGet FREEBETS_NO_TOKEN_ON_VOID 0] {
	    set no_token_on_void Y
	} else {
	    set no_token_on_void N
	}
	set r4_limit [OT_CfgGet TOTAL_RULE4_DEDUCTION 75]

    set void_sql [subst {
        execute procedure pSettleBet(
            p_adminuser = ?,
            p_op = ?,
            p_bet_id = ?,
            p_num_lines_win = ?,
            p_num_lines_lose = ?,
            p_num_lines_void = ?,
            p_winnings = ?,
            p_tax = ?,
            p_refund = ?,
            p_settled_how = ?,
            p_settle_info = ?,
	    p_enable_parking = ?,
	    p_freebets_enabled = '$enable_freebets',
	    p_return_freebet   = '$return_freebets_void',
	    p_rtn_freebet_can  = '$return_freebets_cancel',
	    p_no_token_on_void = '$no_token_on_void',
	    p_r4_limit = '$r4_limit'
        )
    }]

    for {set i 0} {$i < $len} {incr i} {
        set stmt_void [inf_prep_sql $DB $void_sql]
        set bet_id [lindex $void_bet(ids) $i]
        inf_exec_stmt $stmt_void\
                         $USERNAME\
                         X\
                         $bet_id\
                         0\
                         0\
                         $void_bet($bet_id,num_lines)\
                         0.00\
                         $void_bet($bet_id,tax)\
                         $void_bet($bet_id,stake)\
                         M\
                         "payment declined"\
						 N
        inf_close_stmt $stmt_void
    }

	msg_bind $ok_msg

}

proc pmt_proc_auth_code {status} {

	global DB USERID

	#
	# 'status' should be 'R' - payment referral pending (send auth code)
	#                 or 'L' - payment to be made later (get auth code)
	#                 or 'I' - payment referral pending (send auth code)
	#                        - no payment has yet been made
	#
	if {$status != "R" && $status != "L" && $status != "I"} {
		error "Payment must be referral pending or one to be made later"
	}

	set pmt_id       [reqGetArg pmt_id]
	set auth_code  [reqGetArg auth_code]
	set cust_id       [reqGetArg cust_id]
	set reason       [reqGetArg extra_info]

	#
	# Get pmt information
	#
	set pmt_sql {
		select
			p.amount,
			p.payment_sort,
			m.cpm_id,
			c.ref_no,
			m.card_bin,
			m.enc_card_no,
			m.ivec,
			m.data_key_id,
			m.start,
			m.expiry,
			m.issue_no,
			m.enc_with_bin,
			a.ccy_code
		from
			tpmt p,
			tpmtcc c,
			tcpmcc m,
			tacct a
		where
			p.pmt_id = ?
		and p.status = ?
		and p.cpm_id = m.cpm_id
		and p.pmt_id = c.pmt_id
		and p.acct_id = a.acct_id
	}

	set c [catch {

		set stmt_pmt   [inf_prep_sql $DB $pmt_sql]
		set rs 	   [inf_exec_stmt $stmt_pmt $pmt_id $status]
		inf_close_stmt $stmt_pmt

		if {[db_get_nrows $rs] != 1} {
			error "Failed to retrieve payment details ($pmt_id)"
		}

	} msg]

	if {$c} {
		err_bind $msg
		return 0
	}

	set payment_sort [db_get_col $rs payment_sort]
	set ref_no       [db_get_col $rs ref_no]
	set amount       [db_get_col $rs amount]
	set start        [db_get_col $rs start]
	set expiry       [db_get_col $rs expiry]
	set issue_no     [db_get_col $rs issue_no]
	set ccy_code     [db_get_col $rs ccy_code]

	set cpm_id       [db_get_col $rs 0 cpm_id]
	set card_bin     [db_get_col $rs 0 card_bin]
	set enc_card_no  [db_get_col $rs 0 enc_card_no]
	set ivec         [db_get_col $rs 0 ivec]
	set data_key_id  [db_get_col $rs 0 data_key_id]
	set enc_with_bin [db_get_col $rs 0 enc_with_bin]

	db_close $rs

	set card_dec_rs [card_util::card_decrypt $enc_card_no $ivec $data_key_id]

	if {[lindex $card_dec_rs 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db
		if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
			card_util::update_data_enc_status "tCPMCC" $cpm_id [lindex $card_dec_rs 2]
		}
		err_bind "Failed to decrypt card details: [lindex $card_dec_rs 1]"
		return 0
	} else {
		set dec_card_no [lindex $card_dec_rs 1]
	}

	set card_no [card_util::format_card_no $dec_card_no $card_bin $enc_with_bin]

	ob::DCASH::set_require_cvv2 0

	set result [payment_CC::cc_pmt_proc_auth $pmt_id \
											 $ref_no \
											 $auth_code \
											 $amount \
											 $payment_sort \
											 $card_no \
											 $start \
											 $expiry \
											 $issue_no \
											 $status \
											 $ccy_code \
	                                         $reason]

	if {[lindex $result 0] != 1} {

		#
		# If we have a bad 'later' payment, undo the payment straightaway
		#
		if {$status=="L" && [lindex $result 2]=="PMT_DECL"} {
				if [catch {pmt_proc_decline $status} msg] {
					err_bind $msg
					return 0
				}
			return 0
		}

		#
		# roll this back
		#
		err_bind "Errors were reported from payment gateway ([lindex $result 1])"
		return 0

	} else {
		#
		# If we have a bad 'later' payment, undo the payment straightaway
		#
		if {$status=="L"} {
			if {[lindex $result 2]=="N"} {
				if [catch {pmt_proc_decline $status} msg] {
					err_bind $msg
					return 0
				}
			} else {
				set ok_msg "Authorisation has been obtained for payment via payment gateway"
			}
		} else {
			set ok_msg "Authorisation code has been sent to payment gateway successfully"
		}
	}

	msg_bind $ok_msg
	return 1
}


proc pmt_proc_request args {

	global USERID DB

	set SR_type [reqGetArg SR_type]
	OT_LogWrite 2 "pmt_proc_request: SR_type=$SR_type"

	set status [reqGetArg status]

	if {$SR_type == "UpdAuthCode"} {
		if {[op_allowed DoPmtProcRequest]} {
			pmt_proc_upd
		} else {
			err_bind "You don't have permission to set authorisation codes"
		}
	} elseif {$SR_type == "SendAuthCode"} {
		if {[op_allowed DoPmtProcRequest]} {
			pmt_proc_auth_code R
		} else {
			err_bind "You don't have permission to set authorisation codes"
		}
	} elseif {$SR_type == "GetAuthCode"} {
		if {[op_allowed DoPmtProcRequest]} {
			pmt_proc_auth_code L
		} else {
			err_bind "You don't have permission to get authorisation codes"
		}

	} elseif {$SR_type == "Back"} {

		ADMIN::PMT::do_pmt_query
		return

	} elseif {$SR_type == "DoPmtProcVoid"} {

		if {[catch {pmt_proc_void} msg]} {
			err_bind $msg
		}

	} elseif {$SR_type == "DoPmtProcDecl"} {

		if {[catch {pmt_proc_decline $status} msg]} {
			err_bind $msg
		} else {
				# If declining of Incomplete payment was successful, insert
				# a reason to why the payment was declined
				# A reason is present if config time:
				# FUNC_MULTI_AUTH = 0

				set decl_reason [reqGetArg extra_info]
				if {$decl_reason != "" } {
					set status "N"
					set pay_mthd [reqGetArg pay_mthd]

					auth_payment_${pay_mthd} \
						[reqGetArg pmt_id]\
					    $status\
					    $USERID\
					    [reqGetArg auth_code]\
					    $decl_reason
				}
		}
	} elseif {$SR_type == "DoPmtProcAuth"} {
		# Used to authorize a payment of status 'I'
		if {[op_allowed DoPmtProcRequest]} {
			# If the authorization succeeded, we need to make the payment too
			if {[pmt_proc_auth_code I]} {
				# Transfer the money
				set result [payment_CC::cc_pmt_mark_referral_complete [reqGetArg pmt_id] $USERID]
				if {[lindex $result 0] == 0} {
					err_bind [lindex $result 1]
				}
			}
		} else {
			err_bind "You don't have permission to set authorisation codes"
		}
	} elseif {$SR_type == "AuthoriseFC"} {
		auth_payment_FC [reqGetArg pmt_id]
		msg_bind "Fraud Check Authorised"

	} elseif {$SR_type == "AuthoriseLR"} {
		auth_payment_LR [reqGetArg pmt_id]
		msg_bind "Large Returns Authorised"

	} elseif {$SR_type == "Authorise" || $SR_type == "Decline"} {
		set pay_mthd    [reqGetArg pay_mthd]
		# Used to authorise / decline a payment
		if {([op_allowed PmtWUAuth] && $pay_mthd == "WU") ||
		     ([op_allowed UpdPaymentStatus] && $pay_mthd != "WU")} {
			set pay_mthd    [reqGetArg pay_mthd]
			set pmt_id        [reqGetArg pmt_id]
			set auth_code   [reqGetArg auth_code]
			set reason        [reqGetArg extra_info]

			# Check that we're allowing this payment method
			if {[lsearch {"CHQ" "BANK" "GDEP" "GWTD" "CC" "CSH" "BC" "BASC" "WU" "ENET" "MB" "C2P" "NTLR" "PPAL" "SHOP" "CB" "PSC"} $pay_mthd] == -1} {
				error "invalid payment type"
			}

			# Check that mtcn is actually a number
			if {$pay_mthd=="WU" && $SR_type == "Authorise" && ![regexp -- {^\d+$} $auth_code]} {
				err_bind "The mtcn must be a number"
				ADMIN::TXN::GPMT::go_pmt
				return
			}

			if {$SR_type == "Authorise"} {
				set status "Y"
				set success "Payments successfully authorised"
			} else {
				set status "N"
				set success "Payments successfully declined"
			}

			# Authorise / Decline
			set result [auth_payment_${pay_mthd} \
			                    $pmt_id\
								$status\
			                    $USERID\
			                    $auth_code\
			                    $reason]
			if {$result != "OK"} {
				err_bind $result
			} else {
				msg_bind $success
			}
		} else {
			err_bind "You do not have permission to update customers payment status"
		}
	} elseif {$SR_type == "AuthoriseConfirm" || $SR_type == "DeclineConfirm"} {
		set pay_mthd    [reqGetArg pay_mthd]
		# Used to authorise / decline a payment
		if {[op_allowed UpdPaymentStatus]} {
			set pay_mthd    [reqGetArg pay_mthd]
			set pmt_id      [reqGetArg pmt_id]
			set auth_code   [reqGetArg auth_code]
			set reason      [reqGetArg extra_info]

			if {$status == "L" && \
				$SR_type == "DeclineConfirm"} {
				if [catch {pmt_proc_decline $status} msg] {
					error "Failed to decline payment"
				}
				msg_bind "Payments successfully declined"
			} else {

				if {$SR_type == "AuthoriseConfirm"} {
					set status "Y"
					set success "Payments successfully authorised"
				} else {
					set status "N"
					set success "Payments successfully declined"
				}

				# Authorise / Decline
				set result [auth_payment_${pay_mthd} \
								$pmt_id\
								$status\
								$USERID\
								$auth_code\
								$reason]
				if {$result != "OK"} {
					err_bind $result
				} else {
					msg_bind $success
				}
			}
		}
	} elseif {$SR_type == "DoPmtUpdateData"} {
		pmt_upd_details_[reqGetArg PMT_pg_type]
	} elseif {$SR_type == "Repost"} {
		set pay_mthd [reqGetArg pay_mthd]
		set pmt_id   [reqGetArg pmt_id]

		# Check that we're allowing this payment method
		if {[lsearch [list "MB"] $pay_mthd] == -1} {
			error "invalid payment type"
		}

		switch -exact $pay_mthd {
			"MB" {
				set result [payment_MB::do_repost $pmt_id]
				if {[lindex $result 0] == 0} {
					err_bind [lindex $result 1]
				} else {
					set msg "A Status Report will be sent for this payment shortly and will get updated shortly."
					msg_bind $msg
				}
			}
			default {
				# Very unlikely to occur but just in case
				OT_LogWrite 2 "Invalid payment found for Repost attempt."
			}
		}
	} elseif {$SR_type == "DoPmtPPALTxnSearch"} {
		get_ppal_txn_details [reqGetArg pmt_id] [reqGetArg ppal_txn_id] \
			[reqGetArg ppal_inv_num] [reqGetArg ppal_ccy_code] [reqGetArg ppal_cr_date]
	} elseif {$SR_type == "DoChargeback"} {
		do_chargeback
	} else {
		err_bind "No specific request found"
	}

	ADMIN::TXN::GPMT::go_pmt
}

proc pmt_upd_details_COMMIDEA_ATH args {

	global DB USERNAME USERID PMT

	if {![op_allowed UpdPaymentStatus] || ![op_allowed UpdPaymentDetails]} {
		err_bind "You do not have permission to update auth code/unique ID"
		return
	}

	set err_play 0
	set pmt_id             [reqGetArg pmt_id]
	set PMT_gw_uid_TID     [reqGetArg PMT_gw_uid_TID]
	set PMT_gw_uid_EFTSN   [reqGetArg PMT_gw_uid_EFTSN]
	set PMT_auth_code      [reqGetArg PMT_auth_code]

	#
	# Do some sanity checking on the supplied input, and only
	# update db, and do confirm, if the data looks good.

	if {[OT_CfgGet VALIDATE_PMT_AUTH_CODE_LOCALLY 1] && ![regexp {^[0-9][0-9][0-9][0-9]+$} $PMT_auth_code]} {
		err_bind "Auth code must be numeric and at least 4 digits long"
		return
	}

	if {![regexp {^[0-9][0-9][0-9][0-9]$} $PMT_gw_uid_EFTSN]} {
		err_bind "EFTSN must be numeric and 4 digits long"
		return
	}

#	if {![regexp {^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$} $PMT_gw_uid_TID]} {
#		err_bind "Transaction ID must be numeric and 8 digits long"
#		return
#	}

	#
	# This function can only be applied to payments of certain statuses,
	# currently "U" and "L". We check the payment status first and bail out if
	# it's not one of the expected statuses.

	set sql {
		select
			p.status,
			p.payment_sort
		from
			tPmt p
		where
		    p.pmt_id = ?
	}

	set pmt_id [reqGetArg pmt_id]
	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] != 1} {
		error "Failed to locate payment to undo"
	}

	set status [db_get_col $rs 0 status]
	set payment_sort [db_get_col $rs 0 payment_sort]

	if {[lsearch {"U" "L"} $status] == -1} {
		err_bind "Illegal operation for payment with status: $status"
		return
	}

	#
	# Supplied data looks generally OK at this point.

	#
	# Auth Code.

	set sql {
		Update tPmt set
		    auth_code = ?
		where
		    pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $PMT_auth_code $pmt_id} msg]} {
		err_bind $msg
		return
	}
    inf_close_stmt $stmt

	#
	# Unique ID - and increment fulfillment attempts.

	set PMT_gw_uid "$PMT_gw_uid_TID:$PMT_gw_uid_TID:$PMT_gw_uid_EFTSN"

	set sql {
		Update tPmtCC set
		    gw_uid = ?,
			num_fulfil_att = NVL(num_fulfil_att,0) + 1,
			last_fulfil_att = current
		where
		    pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $PMT_gw_uid $pmt_id} msg]} {
		err_bind $msg
		return
	}
    inf_close_stmt $stmt

	#
	# We now have the various components in order to attempt a confirmation.

	catch {unset PMT}

	set PMT(pay_sort) "Y"
	set PMT(gw_uid)    $PMT_gw_uid
	set PMT(auth_code) $PMT_auth_code

	#
	# Make another confirmation request.

	set result [ob_commidea::make_call PMT]
	set COMMIDEA_transaction_status {}

	set COMMIDEA_result             $result

	if {$result == {OK}} {
		#
		# If the confirm was successful, we authorise the payment.

		if {[string toupper $ob_commidea::COMMIDEA_RESP(TransactionStatus)] == "COMPLETED" && \
			[string toupper $ob_commidea::COMMIDEA_RESP(TransactionResult)] == "ACCEPTED" } {
			tpBindString COMMIDEA_transaction_status $ob_commidea::COMMIDEA_RESP(TransactionStatus)

			set pay_mthd    [reqGetArg pay_mthd]
			set pmt_id      [reqGetArg pmt_id]
			set auth_code   [reqGetArg auth_code]
			set reason      [reqGetArg extra_info]

			OT_LogWrite 5 "==> pmt_upd_details_COMMIDEA: ${pay_mthd} $pmt_id Y $USERID $auth_code $reason"

			set auth_result [auth_payment_${pay_mthd} \
							$pmt_id \
							{Y} \
							$USERID \
							$auth_code \
							$reason]

			if {$auth_result != "OK"} {
				err_bind $auth_result
				return
			}
		}
	}

	#
	# We must display some text for admin operators indicating the situation
	# with regards to statuses, and how to proceed. This depends on a number of
	# factors including Commidea response, payment status, etc.

	set gen_failure_message "The confirmation attempt\
				failed whilst communicating with the payment gateway. No\
				further details are available of the failure.<br>\
				Sending again is safe and will NOT cause a second\
				payment. Scroll down to send another confirmation\
				attempt."

	switch -- $result {
		OK {
			if {[string toupper $ob_commidea::COMMIDEA_RESP(TransactionStatus)] == "COMPLETED"} {
				switch -- [string toupper $ob_commidea::COMMIDEA_RESP(TransactionResult)] {
					ACCEPTED {
						tpBindString PMT_status_blurb "The payment gateway has responded \
						with a <b>SUCCESSFUL</b> confirmation for the above details.<br> \
						The payment transaction status has been changed to \"GOOD\" and \
						marked as fulfilled."
					}

					REJECTED {
						#
						# Message depends on the status of the payment.

						set COMMIDEA_result {PMT_ERR}

						switch -- $status {
							L {
								tpBindString PMT_status_blurb "The payment gateway has\
								responded with a <b>REJECTION</b> to the confirmation\
								request for the above details. The most likely reason\
								this has occurred is becuase the details entered could\
								not be found. Therefore, please confirm the above\
								details are correct. If incorrect, re-enter details\
								below and try manual authorisation again. If correct\
								then select \"Decline\"<br><b>N.B. Selecting \"Decline\"\
								will result in automatic recovery of funds from the\
								associated account"
							}

							U {
								tpBindString PMT_status_blurb "The payment gateway has\
								responded with a <b>REJECTION</b> to the confirmation\
								request for the above details. The most likely reason\
								this has occurred is because the details entered could\
								not be found. Therefore, please confirm the above\
								details are correct. If incorrect then re-enter the\
								details below and try manual authorisation again. If\
								correct then select \"Decline\""
							}
						}
					}

					default {
						tpBindString PMT_status_blurb $gen_failure_message
					}
				}
			} else {
				tpBindString PMT_status_blurb $gen_failure_message
			}
		}

		default {
			#
			# We could have timed out here, or there may be some other error
			# that is preventing the confirmation. We need to display the
			# best possible cause of the other otherwise we could simply get a
			# lot of unnecessary support calls.

			if {[info exists ob_commidea::COMMIDEA_RESP(TransactionStatus)] && \
				$ob_commidea::COMMIDEA_RESP(TransactionStatus) == "TIMED_OUT"} {
				tpBindString PMT_status_blurb "The confirmation attempt\
				has <b>TIMED OUT</b> whilst communicating with the\
				payment gateway.<br>It is possible the confirmation was\
				successfully received by the payment gateway, however\
				sending again is safe and will NOT cause a second\
				payment. Scroll down to send another confirmation\
				attempt."
			} else {
				tpBindString PMT_status_blurb $gen_failure_message
			}
		}
	}


	tpBindString PMT_acct_pmt_id    [reqGetArg pmt_id]
	tpBindString PMT_cust_id        [reqGetArg cust_id]
	tpBindString PMT_ref_no         [format %08d $pmt_id]

	tpBindString PMT_gw_uid_TID     $PMT_gw_uid_TID
	tpBindString PMT_gw_uid_EFTSN   $PMT_gw_uid_EFTSN

	tpBindString COMMIDEA_result $COMMIDEA_result

	reqSetArg additional_html pmt/pmt_confirm_[reqGetArg PMT_pg_type].html
}

proc do_chargeback {} {

	global DB

	set pmt_id           [reqGetArg pmt_id]
	set chargeback_check [reqGetArg chargeback]

	if {$chargeback_check == 1} {
		set chargeback "Y"
		set defended   [reqGetArg defended]
			
	} else {
		# Default values
		set chargeback "N"
		set defended   "U"
	}

	set sql {
		update 
			tPmtCC
		set
			chargeback = ?,
			defended = ?
		where
			pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $chargeback $defended $pmt_id]
	inf_close_stmt $stmt
	db_close $res
	msg_bind "Chargeback updated"

}

# close namespace
}

