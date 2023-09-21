# ==============================================================
# $Id: genpmt.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

package require pmt_validate

namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::do_pay_mthd_pmt  [namespace code do_pay_mthd_pmt]
asSetAct ADMIN::PMT::do_pmt_referral  [namespace code do_pmt_referral]


proc do_pay_mthd_pmt {} {
	OT_LogWrite 5 "==> do_pay_mthd_pmt"

	global DB USERID

	if {[reqGetArg SubmitName] == "Back"} {
		go_pay_mthd_auth
		return
	}

	set type [reqGetArg DepWtd]

	#
	# get the amount
	#
	if {[reqGetArg Amount] == ""} {
		err_bind "No Amount entered"
		rebind_request_data
		go_pay_mthd_pmt $type
		return
	}

	#
	# check pay method is supported
	#
	set pay_mthd [reqGetArg pay_mthd]
	if {[lsearch [list "CC" "CHQ" "BANK" "GDEP" "GWTD" "CSH" "PB" "EP" "BC" "NTLR" "BASC" "WU" "MB" "C2P" "PPAL" "SHOP" "UKSH" "IKSH" "CB" "BARC"] $pay_mthd] == -1} {
		error "Payment method not supported"
	}


	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS 0] && $type == "DEP"} {
		set cust_id    [reqGetArg CustId]
		set amount     [reqGetArg Amount]
		set dep_limits [ob_srp::check_deposit $cust_id $amount]

		set dep_allowed [lindex $dep_limits 0]
		set min_dep     [lindex $dep_limits 1]
		set max_dep     [lindex $dep_limits 2]
		set reason      [lindex $dep_limits 3]

		if {[lindex $dep_limits 0] != 1} {
			err_bind "Deposit not allowed: $reason min deposit:$min_dep max deposit:$max_dep"
			if {[OT_CfgGet MONITOR 0]} {
					set sql {
						select
							c.username,
							r.fname,
							r.lname,
							a.ccy_code
						from
							tCustomer c,
							tCustomerReg r,
							tAcct a
						where
							c.cust_id = ?
							and c.cust_id = r.cust_id
							and a.cust_id = c.cust_id
					}

					set stmt [inf_prep_sql $DB $sql]
					set res  [inf_exec_stmt $stmt $cust_id]
					inf_close_stmt $stmt

					if {[db_get_nrows $res] == 0} {
						ob::log::write ERROR "No rows returned by details query in proc do_pay_mthd_pmt for cust $cust_id"
					} else {
						foreach c {username fname lname ccy_code} {
							set $c [db_get_col $res 0 $c]
						}
						db_close $res

						set pmt_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
						set channel [reqGetArg source]
						set oper_id $USERID
						MONITOR::send_payment_denied\
							$username\
							$fname\
							$lname\
							$pmt_date\
							$channel\
							$oper_id\
							$pay_mthd\
							$amount\
							$ccy_code
					}
			}

			rebind_request_data
			go_pay_mthd_pmt $type
			return
		}
	}

	# is the customer KYC withdrawal blocked?
	# NB check IsKYCOverride as if this is not set to 1 it means the user has
	# not been warned of the override
	if {
		$type == "WTD" &&
		[OT_CfgGet FUNC_KYC 0] &&
		(![op_allowed OverrideKYCWtdBlock] || [reqGetArg IsKYCOverride] != 1)
	} {
		foreach {res block} [ob_kyc::cust_is_blocked [reqGetArg CustId] 1] {}

		if {$res != "OK"} {
			err_bind "Failed to make withdrawal - unable to check KYC status"
			rebind_request_data
			go_pay_mthd_pmt $type
			return
		}

		if {$block} {
			err_bind "Failed to make a withdrawal - customer is KYC restricted"
			rebind_request_data
			go_pay_mthd_pmt $type
			return
		}
	}


	# Do OVS Checks
	if {![do_age_vrf_check [reqGetArg CustId] $pay_mthd $type [reqGetArg cpm_id]]} {
		err_bind "An age verification error has occured!"
		rebind_request_data
		go_pay_mthd_pmt $type
		return
	}


	set ovs_status [verification_check::get_ovs_status [reqGetArg CustId] "AGE"]
	if {$ovs_status == "S"} {
		err_bind "Cannot Withdraw or Deposit on an AV suspended account"
		rebind_request_data
		go_pay_mthd_pmt $type
		return
	} elseif {
		$ovs_status == "P" \
		&& ![op_allowed AVWithdrawalAllowed] \
		&& $type == "WTD" \
	} {
		# If the user hasn't got perms and withdrawing from an AV restricted account offer a smackdown!
		err_bind "You do not have the correct permissions to withdrawal from a AV suspended account."
		rebind_request_data
		go_pay_mthd_pmt "WTD"
	}


	set sql {
		select
			a.acct_type,
			a.acct_id
		from
			tAcct a
		where
			a.cust_id = ?
	}
	set cust_id    [reqGetArg CustId]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set acct_type [db_get_col $res 0 acct_type]
	set acct_id [db_get_col $res 0 acct_id]


	# If we are using multiple payment methods need to check withdrawal is
	# valid
	if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0] && $type == "WTD" } {

			set amount     [reqGetArg Amount]
			set cpm_id     [reqGetArg cpm_id]

			if {$acct_type == "DEP"} {
				set result [payment_multi::validate_chosen_wtd \
					$cust_id $amount [list [list $cpm_id $amount]]]
			} else {
				set result OK
			}

			if {$result != "OK"} {
				err_bind "This withdrawal is not possible because of: $result"
				rebind_request_data
				go_pay_mthd_pmt "WTD"
				return
			}
			ob_pmt_validate::init_mult_pmt_res $acct_id
	}


	# do the payment we need the pmt_id for group_wtd - group wtd delay
	set pmt_id [do_pay_mthd_pmt_${pay_mthd}]
	set mthd_list [list $pay_mthd $pmt_id]

	if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0] && $type == "WTD" \
		&& $acct_type == "DEP"} {
		if {$pmt_id > 0} {
			set wtd_time \
				[ob_pmt_validate::set_group_wtd_delay \
					$acct_id $mthd_list]
		}

		if {$pmt_id > -1} {
	    	ob_pmt_validate::clear_mult_pmt_res
		}
	}

	if {$pmt_id > 0} {
		go_pay_mthd_auth
		return
	}

	if {$pmt_id == 0} {
		go_pay_mthd_pmt $type
		return
	}
}




# Do a Age Verificaiton Check
#
# Params:
#	cust_id    -
#	pay_mthd   - CSH, NTLR etc...
#	type       - DEP/WTD
#	cpm_id     -
# Returns:
#	1/0 (success/failure)
#
proc do_age_vrf_check {cust_id pay_mthd type cpm_id} {

	global DB

	#
	# Grab the acct_id.
	#
	set sql {
		select
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {![db_get_nrows $res]} {
		return 0
	}
	set acct_id [db_get_col $res 0 acct_id]
	db_close $res


	#
	# Grab the scheme
	#
	set sql {
		select
			cs.scheme
		from
			tcpmcc cpm,
			tcardscheme cs
		where
			cs.bin_lo <= cpm.card_bin and
			cs.bin_hi >= cpm.card_bin and
			cpm.cpm_id = ?
	}

	set stmt2 [inf_prep_sql $DB $sql]
	set res2 [inf_exec_stmt $stmt2 $cpm_id]
	inf_close_stmt $stmt2

	set scheme {}
	if {[db_get_nrows $res2]} {
		# Must be a credit/debit card.
		set scheme [db_get_col $res2 0 scheme]
	}
	db_close $res2


	#
	# Do Age Verf Check.
	#
	set chk_resp [verification_check::do_verf_check \
		$pay_mthd \
		$type \
		$acct_id \
		""\
		$scheme]

	if {![lindex $chk_resp 0]} {
		return 0
	}

	return 1
}

proc get_acct_id {cust_id} {

	global DB

	set sql {
		select
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		return -1
	}

	set acct_id [db_get_col $res 0 acct_id]
	db_close $res

	return $acct_id
}

proc get_pmt_detail {pmt_id} {

	global DB

	OT_LogWrite 5 "pmt_id ($pmt_id)"

	set sql {
		select
			p.payment_sort,
			a.ccy_code,
			p.amount
		from
			tAcct a,
			tPmt p
		where
			pmt_id = ? and
			p.acct_id = a.acct_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	OT_LogWrite 5 "pmt_id nrows = [db_get_nrows $res]"
	if {[db_get_nrows $res] != 1} {
		return [list -1]
	}

	OT_LogWrite 5 "pmt_id pay_sort = [db_get_col $res 0 payment_sort]"
	set result [list [db_get_col $res 0 payment_sort] \
			[db_get_col $res 0 amount] \
			[db_get_col $res 0 ccy_code]]

	db_close $res

	return $result
}

proc do_pay_mthd_pmt_BC {} {

	global DB USERID

	#
	# Default Payment details
	#

	set cpm_id  [reqGetArg cpm_id]
	set uid     [reqGetArg uniqueId]
	set cust_id [reqGetArg CustId]
	set ip      [reqGetEnv REMOTE_ADDR]
	set amount  [reqGetArg Amount]
	set type    [reqGetArg DepWtd]
	set source  [reqGetArg source]
	set betcard_no [reqGetArg BetcardNo]

	set betcard_id ""

	#
	# payment sort
	#
	if {$type == "WTD"} {
		set pay_sort W

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0

	} else {
		set pay_sort D

		# if deposit remember that money has been transferred
		set is_pmt_done 1

		## check that the betcard is valid
		set betcard_id [OB::BETCARD::check_betcard_number $betcard_no]

		if {[lindex $betcard_id 0] == -1} {
			err_bind "Error inserting cash payment: [lindex $betcard_id 1] "
			rebind_request_data
			go_pay_mthd_pmt [reqGetArg DepWtd]
			return
		}
	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		go_pay_mthd_pmt [reqGetarg DepWtd]
		return
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission BC {} \
						$ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

	} else {
		set commission 0.0
		set tPmt_amount $amount
	}

	## check that the betcard is valid here

	set vendor_uname [reqGetArg VendorUname]

	set result [insert_payment_BC  $acct_id\
			$cpm_id\
			$pay_sort\
			$amount\
			$tPmt_amount\
			$commission\
			$ip\
			$source\
			$USERID\
			$uid\
			$betcard_id\
			$vendor_uname]
	ob::log::write INFO {insert_payment_BC returning $result}

	if {[lindex $result 0]} {

		set pmt_id     [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set msg "[lindex $result 2] [lindex $pmt_detail 2] has been successfully withdrawn from this account"

			# Check is the payment needs to be delayed or be flagged for fraud
			# checking
			ob_pmt_validate::chk_wtd_all\
				$acct_id\
				$pmt_id\
				"BC"\
				"----"\
				$tPmt_amount\
				[getCcyCode $cust_id]

		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}

		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg

		if {$pay_sort == "D"} {
			set auth_res [auth_payment_BC $pmt_id Y $USERID ""]

			if {$auth_res != "OK"} {
				error "failed to authorise payment"
				go_pay_mthd_auth
				return
			}
		}

		return $pmt_id

	} else {
		err_bind "Error inserting cash payment: $result"
		rebind_request_data
		return 0
	}
}


proc do_pay_mthd_pmt_CSH {} {

	global DB USERID

	#
	# Default Payment details
	#

	set cpm_id  [reqGetArg cpm_id]
	set uid     [reqGetArg uniqueId]
	set cust_id [reqGetArg CustId]
	set ip      [reqGetEnv REMOTE_ADDR]
	set amount  [reqGetArg Amount]
	set type    [reqGetArg DepWtd]
	set source  [reqGetArg source]

	#
	# Cash details
	#

	set outlet     [reqGetArg outlet]
	set manager    [reqGetArg manager]
	set id         [reqGetArg id]
	set id_type    [reqGetArg id_type]
	set extra_info [reqGetArg extra_info]

	#
	# payment sort
	#
	if {$type == "WTD"} {
		set pay_sort W

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0

	} else {
		set pay_sort D

		# if deposit remember that money has been transferred
		set is_pmt_done 1

	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		go_pay_mthd_pmt [reqGetarg DepWtd]
		return 0
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission CSH {} \
					$ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

	} else {
		set tPmt_amount $amount
		set commission 0.0
	}

	#
	# insert this payment
	#
	set result [insert_payment_CSH $acct_id\
									$cpm_id\
									$pay_sort\
									$amount\
									$ip\
									$source\
									$USERID\
									$uid\
									$outlet\
									$manager\
									$id\
									$id_type\
									$extra_info\
									$commission\
									$tPmt_amount]

	if {[lindex $result 0]} {

		set pmt_id     [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set msg "[lindex $result 2] [lindex $pmt_detail 2] has been successfully withdrawn from this account"
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}

		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg

		if {[OT_CfgGet FUNC_PMT_CSH_AUTO_AUTH 0]} {

			set auth_res [auth_payment_CSH $pmt_id Y $USERID ""]

			if {$auth_res != "OK"} {
				error "failed to authorise payment"
				return $pmt_id
			}

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0] && $pay_sort == "D"} {
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
		}

		return $pmt_id
	} else {
		err_bind "Error inserting cash payment: $result"
		rebind_request_data
		return 0
	}
}


proc do_pay_mthd_pmt_CHQ {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set source      [reqGetArg source]

	#
	# cheque details
	#
	set payer               [reqGetArg payer]
	set chq_no              [reqGetArg chq_no]
	set chq_date            [reqGetArg chq_date]
	set chq_sort_code       [reqGetArg chq_sort_code]
	set chq_acct_no         [reqGetArg chq_acct_no]
	set rec_delivery_ref    [reqGetArg rec_delivery_ref]
	set extra_info          [reqGetArg extra_info]

	#
	# payment sort
	#
	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]
		if {[OT_CfgGet FUNC_PMT_SURCHARGE 0]} {
			set amount [expr $amount - $commission]
		}

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0

	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]

		# if deposit remember that money has been transferred
		set is_pmt_done 1
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission CHQ {} \
					$ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set min_amt   $tPmt_amount
		set max_amt   $amount

	} else {
		set commission 0.0
		set tPmt_amount $amount

		#
		# override the min/max amount
		#
		set min_amt   $amount
		set max_amt   $amount
	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	#
	# insert this payment
	#
	set result [insert_payment_CHQ $acct_id \
					$cpm_id \
					$pay_sort \
					$amount \
					$commission \
					$ip \
					$source \
					$USERID \
					$uid \
					$payer \
					$chq_date \
					$chq_no \
					$chq_sort_code \
					$chq_acct_no \
					$rec_delivery_ref \
					$extra_info \
					$tPmt_amount \
					$min_amt \
					$max_amt]

	if {[lindex $result 0]} {

		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account, "

			# Check is the payment needs to be delayed or be flagged for fraud
			# checking
			ob_pmt_validate::chk_wtd_all\
				$acct_id\
				$pmt_id\
				"CHQ"\
				"----"\
				$tPmt_amount\
				[getCcyCode $cust_id]


		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
		return $pmt_id
	} else {
		err_bind "Error inserting cheque payment: $result"
		rebind_request_data
		return 0
	}
}


proc check_cust_prev_pmts {cust_id cpm_id} {

	card_util::cd_get_active $cust_id CARD_DETAILS
	if {$CARD_DETAILS(card_available) == "Y"} {
		set prev_pmt_made [card_util::cd_check_prev_pmt $cust_id \
			$CARD_DETAILS($cpm_id,enc_card_no) 1]
	} else {
		set prev_pmt_made 0
	}

	return $prev_pmt_made
}


proc do_pay_mthd_pmt_CC {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id       [reqGetArg cpm_id]
	set uid          [reqGetArg uniqueId]
	set cust_id      [reqGetArg CustId]
	set ip           [reqGetEnv REMOTE_ADDR]
	set amount       [reqGetArg Amount]
	set type         [reqGetArg DepWtd]
	set auth_code    [reqGetArg auth_code]
	set gw_auth_code [reqGetArg gw_auth_code]
	set extra_info   [reqGetArg extra_info]
	set source       [reqGetArg source]
	set cvv2         [reqGetArg cvv2]

	set has_resp [card_util::payment_has_resp $cpm_id]

	set prev_pmt_made 1

	if {[OT_CfgGet USE_CVV2_UPON_REG_ONLY 0]} {
		set prev_pmt_made [check_cust_prev_pmts $cust_id $cpm_id]
	}

	## check cvv2 number
	if {$has_resp == 0 && ![card_util::verify_card_cvv2 $cvv2] && ($type == "DEP" || $cvv2 != "") && !$prev_pmt_made} {
		err_bind "Invalid CSC entered"
		rebind_request_data
		return 0
	}

	##sanity check
	if {![OT_CfgGet DISPLAY_CV2_FOR_PMT 0] || $type == "WTD"} {
		set cvv2 ""
		## we wont be sending any cv2 data in this case
		ob::DCASH::set_require_cvv2 0
	} else {
		ob::DCASH::set_require_cvv2 1
	}

	if {[OT_CfgGet USE_CVV2_UPON_REG_ONLY 0]} {
		set prev_pmt_made [check_cust_prev_pmts $cust_id $cpm_id]
		if {$prev_pmt_made} {
			ob::DCASH::set_require_cvv2 0
		}
	}

	#
	# get acct_id, and currency code
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]

		#check that the user has permission to perform this operation.
		if {[op_allowed DoCcWtdUnltd]} {
		} elseif {[op_allowed DoCCWtdLtd]} {
			set sql {
				select
					c.max_withdrawal,
					c.ccy_code
				from
					tccy c,
					tacct a
				where
					c.ccy_code=a.ccy_code
				and a.acct_id=?
			}
			set stmt [inf_prep_sql $DB $sql]
			set res [inf_exec_stmt $stmt $acct_id]
			inf_close_stmt $stmt
			if {[db_get_nrows $res]!=1} {
				db_close $res
				err_bind "A problem occurred retrieving max withdrawal limit for customers account currency"
				rebind_request_data
				return 0
			}

			set max_amount [db_get_col $res 0 max_withdrawal]
			if {$amount > $max_amount} {
				set ccy [db_get_col $res 0 ccy_code]
				db_close $res
				err_bind "You only have permission to withdraw up to $max_amount for currency $ccy"
				rebind_request_data
				return 0
			}
			db_close $res
		} else {
			err_bind "You do not have permission to make credit card withdrawals"
			rebind_request_data
			return 0
		}
	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]
	}

	#
	# override the min/max amount
	#
	set min_amt   $amount
	set max_amt   $amount
	set j_op_type ""
	set call_id   ""

	#
	# if card scheme in ENFORCE_SCHEME_LMT, override
	# min_amt and max_amt to "" so card limit checks are forced
	#
	if {[OT_CfgGet ENFORCE_SCHEME_LMT ""] != ""} {
		# get the scheme
		global DB

		set sql {
			select
				cs.scheme
			from
				tcpmcc cpm,
				tcardscheme cs
			where
				cs.bin_lo <= cpm.card_bin and
				cs.bin_hi >= cpm.card_bin and
				cpm.cpm_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $cpm_id]
		inf_close_stmt $stmt

		# found scheme...
		if {[db_get_nrows $res] == 1} {
			set scheme [db_get_col $res 0 scheme]

			# and if its in the ENFORCE_SCHEME_LMT list...
			if {[lsearch [OT_CfgGet ENFORCE_SCHEME_LMT ""] "$scheme $pay_sort"] > -1} {
				set min_amt ""
				set max_amt ""
				OT_LogWrite 10 "for cpm_id:$cpm_id , scheme is $scheme ; enforcing scheme limit check"
			}
		}

		db_close $res

	}

	set country_code [get_country_code $cust_id]

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		card_util::cd_get_active $cust_id CARD

		#
		# first get the card type (credit/debit) and currency to calc commmission
		#
		set card_data [list]
		card_util::cd_get_req_fields [string range $CARD(card_no) 0 5] card_data
		set card_type $card_data(type)

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission CC [string index $card_type 0] \
													$ccy_code $pay_sort $amount]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# attempt to make the payment
		#
		set result [payment_CC::cc_pmt_make_payment $acct_id \
				$USERID \
				$uid \
				$pay_sort \
				$amount \
				$cpm_id \
				$source \
				$auth_code \
				$extra_info\
				$j_op_type\
				$min_amt\
				$amount\
				$call_id\
				$gw_auth_code\
				1\
				$cvv2 \
				$comm_list \
				$country_code]
	} else {

		#
		# attempt to make the payment
		#
		set result [payment_CC::cc_pmt_make_payment $acct_id \
				$USERID \
				$uid \
				$pay_sort \
				$amount \
				$cpm_id \
				$source \
				$auth_code \
				$extra_info\
				$j_op_type\
				$min_amt\
				$max_amt\
				$call_id\
				$gw_auth_code\
				1\
				$cvv2 \
				"" \
				$country_code]
	}

	if {[OT_CfgGet FUNC_ONEPAY 0]} {
		if {[llength [lindex $result 2]] > 1 &&  [lindex [lindex $result 2] 0] == "PMT_URL_REDIRECT"} {
			tpBindString REDIRECT_URL [lindex [lindex $result 2] 1]
			tpSetVar onepay_redirect 1
		}
	}


	#
	# process the result
	#
	if {[lindex $result 0]} {

		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account, "
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
		return $pmt_id

	} else {
		if {[lindex $result 2] == "PMT_REFER"} {
			# This is a payment referral
			# Update the status of the payment to 'I' - referral pending
			set pmt_id [lindex $result 3]
			set result [payment_CC::cc_pmt_mark_referred $pmt_id $USERID]
			if {[lindex $result 0] == 0} {
				set err_msg [lindex $result 1]
				err_bind "Failed to change status of payment from bad to incomplete: $err_msg"
				return $pmt_id
			}

			msg_bind "Payment referred"

			# Send them to the payment details screen
			reqSetArg pmt_id $pmt_id
			reqSetArg cust_id $cust_id

			if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0] && $type == "WTD"} {
				if {$pmt_id > 0} {
					set wtd_time \
						[ob_pmt_validate::set_group_wtd_delay \
							$acct_id [list CC $pmt_id]]
				}

	    		ob_pmt_validate::clear_mult_pmt_res
			}

			ADMIN::TXN::GPMT::go_pmt
			return -1
		} else {
			rebind_request_data
			err_bind "[lindex $result 1]"
			return 0
		}
	}
}

proc do_pay_mthd_pmt_WU {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id       [reqGetArg cpm_id]
	set uid          [reqGetArg uniqueId]
	set cust_id      [reqGetArg CustId]
	set ip           [reqGetEnv REMOTE_ADDR]
	set amount       [reqGetArg Amount]
	set type         [reqGetArg DepWtd]
	set mtcn         [reqGetArg mtcn]
	set req_location [reqGetArg req_location]
	set extra_info   [reqGetArg extra_info]
	set source       [reqGetArg source]

	#
	# payment sort
	#
	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0

	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]

		# if deposit remember that money has been transferred
		set is_pmt_done 1
	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission WU {} \
					$ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

	} else {
		set commission 0.0
		set tPmt_amount $amount

	}

	#
	# insert this payment
	#
	set result [insert_payment_WU   $acct_id \
			$cpm_id \
			$pay_sort \
			$tPmt_amount \
			$commission \
			$ip \
			$source \
			$USERID \
			$uid \
			$extra_info \
			$mtcn \
			$req_location]

	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account, "

			# Check is the payment needs to be delayed or be flagged for fraud
			# checking
			ob_pmt_validate::chk_wtd_all\
				$acct_id\
				$pmt_id\
				"WU"\
				"----"\
				$tPmt_amount\
				[getCcyCode $cust_id]

		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
		return $pmt_id
	} else {
		err_bind "Error inserting bank payment: [lindex $result 1]"
		rebind_request_data
		return 0
	}
}


proc do_pay_mthd_pmt_BANK {} {

	global DB USERID


	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set code        [reqGetArg code]
	set extra_info  [reqGetArg extra_info]
	set source      [reqGetArg source]

	#
	# payment sort
	#
	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]

		# if withdrawal remember that money has not yet been transferred
		set is_pmt_done 0
	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]

		# if deposit remember that money has been transferred
		set is_pmt_done 1
	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission BANK {} \
					$ccy_code $pay_sort $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set min_amt   $tPmt_amount
		set max_amt   $amount

	} else {

		set commission 0.0
		set tPmt_amount $amount

		#
		# override the min/max amount
		#
		set min_amt   $amount
		set max_amt   $amount
	}

	#
	# insert this payment
	#
	set result [insert_payment_BANK $acct_id \
					$cpm_id \
					$pay_sort \
					$amount \
					$commission \
					$ip \
					$source \
					$USERID \
					$uid \
					$code \
					$extra_info \
					$tPmt_amount \
					$min_amt \
					$max_amt]

	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {

			# Check is the payment needs to be delayed or be flagged for fraud
			# checking
			ob_pmt_validate::chk_wtd_all\
				$acct_id\
				$pmt_id\
				"BANK"\
				"----"\
				$tPmt_amount\
				[getCcyCode $cust_id]

			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account, "
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set msg "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account, "
		} else {
			error "failed to retrieve payment id from payment table"
		}
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
		return $pmt_id

	} else {
		err_bind "Error inserting bank payment: [lindex $result 1]"
		rebind_request_data
		return 0
	}
}


proc do_pay_mthd_pmt_GDEP {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set pay_type    [reqGetArg pay_type]
	set blurb       [reqGetArg blurb]
	set extra_info  [reqGetArg extra_info]

	# this is an old commission charge - it will be overwritten below
	# if CHARGE_COMMISSION = 1 in the config
	set commission  [reqGetArg dep_charge]
	set source      [reqGetArg source]

	#
	# payment sort
	#
	if {$type == "WTD"} {
		error "Withdrawals cannot be made using this payment method"
	} else {
		# if deposit remember that money has been transferred
		set is_pmt_done 1
	}

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}


	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission GDEP {} \
					$ccy_code [string index $type 0] $amount $is_pmt_done]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set min_amt   $tPmt_amount
		set max_amt   $amount

	} else {
		set commission 0.0
		set tPmt_amount $amount

		#
		# override the min/max amount
		#
		set min_amt   $amount
		set max_amt   $amount
	}

	#
	# insert this payment
	#
	set result [insert_payment_GDEP $acct_id \
					$cpm_id \
					$amount \
					$commission \
					$ip \
					$source \
					$USERID \
					$uid \
					$pay_type \
					$blurb \
					$extra_info \
					$tPmt_amount \
					$min_amt \
					$max_amt]


	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "D"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account"
		} else {
			error "failed to retrieve payment id from payment table"
		}
		return $pmt_id

	} else {
		err_bind "Error inserting bank payment: [lindex $result 1]"
		rebind_request_data
		return 0
	}
}



proc do_pay_mthd_pmt_C2P {} {

	ob::log::write DEBUG {ADMIN::PMT::do_pay_mthd_pmt_C2P}

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set pay_type    [reqGetArg pay_type]
	set extra_info  [reqGetArg extra_info]
	set commission  [reqGetArg dep_charge]
	set source      [reqGetArg source]

	# grab the customers currency code
	# Get the currency of the user from the DB
	set sql {
		select
			ccy_code
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		err_bind "Error inserting Click2Pay payment: There were $nrows returned from the DB when only 1 was expected"
		rebind_request_data
		return 0
	}
	set ccy_code [db_get_col $res 0 ccy_code]

	# get acct_id
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}


	if {$type == "WTD"} {
		set pay_sort "W"
	} else {
		set pay_sort "D"
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {
		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission C2P {} $ccy_code \
			$pay_sort $amount]

		set result [ob_click2pay::make_click2pay_transaction $cust_id \
				$acct_id \
				$USERID \
				$uid \
				$pay_sort \
				$amount \
				$cpm_id \
				$source \
				$ccy_code \
				0 \
				"" \
				$extra_info \
				$comm_list]
	} else {
		set result [ob_click2pay::make_click2pay_transaction $cust_id \
				$acct_id \
				$USERID \
				$uid \
				$pay_sort \
				$amount \
				$cpm_id \
				$source \
				$ccy_code \
				0 \
				"" \
				$extra_info]
	}

	if {[lindex $result 0] == 1} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "D"} {

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0]} {
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

			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account"
		} elseif {[lindex $pmt_detail 0] == "W"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account"
		}
		return $pmt_id
	} else {
		set msg [ADMIN::XLATE::get_translation en [lindex $result 1]]
		if {$msg == ""} {
			set msg [lindex $result 1]
		}
		err_bind "Error inserting CLICK2PAY payment: $msg"
		rebind_request_data
		return 0
	}

}


proc do_pay_mthd_pmt_NTLR {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set pay_type    [reqGetArg pay_type]
	set blurb       [reqGetArg blurb]
	set extra_info  [reqGetArg extra_info]
	set commission  [reqGetArg dep_charge]
	set source      [reqGetArg source]

	set secure_id   [reqGetArg secure_id]

	OB_neteller::get_neteller $cust_id

	# Get the currency of the user from the DB
	set sql {
		select
			ccy_code
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		err_bind "Error inserting neteller payment: There were $nrows returned from the DB when only 1 was expected"
		rebind_request_data
		return 0
	}
	set currency [db_get_col $res 0 ccy_code]

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission NTLR {} \
					$currency [string index $type 0] $amount]

		if {$type == "DEP"} {
			set result [::OB_neteller::dep $amount $currency $uid $secure_id $source $USERID $comm_list]
		} elseif {$type == "WTD"} {
			set result [::OB_neteller::wtd $amount $currency $uid $source $USERID $comm_list]
		}

	} else {
		if {$type == "DEP"} {
			set result [::OB_neteller::dep $amount $currency $uid $secure_id $source $USERID]
		} elseif {$type == "WTD"} {
			set result [::OB_neteller::wtd $amount $currency $uid $source $USERID]
		}
	}

	if {[lindex $result 0] == 1} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]
		if {[lindex $pmt_detail 0] == "D"} {

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0]} {
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

			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account"
		} elseif {[lindex $pmt_detail 0] == "W"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account"
		}
		return $pmt_id
	} elseif {[lindex $result 0] == 2} {
		set pmt_id [lindex $result 3]
		set msg [ADMIN::XLATE::get_translation en [lindex $result 1]]
		if {$msg == ""} {
			set msg [lindex $result 1]
		}
		msg_bind "Neteller withdrawal successfully  made and under Pending status: $msg Code:[lindex $result 2]"
		return $pmt_id
	} else {
		set msg [ADMIN::XLATE::get_translation en [lindex $result 1]]
		if {$msg == ""} {
			set msg [lindex $result 1]
		}
		err_bind "Error inserting neteller payment: $msg Code:[lindex $result 2]"
		rebind_request_data
		return 0
	}
}



# Do a PPAL payment
#
proc do_pay_mthd_pmt_PPAL {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set cust_id     [reqGetArg CustId]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set source      [reqGetArg source]
	set ipaddr      [reqGetEnv REMOTE_ADDR]
	set unique_id   [reqGetArg uniqueId]

	if {$type != "WTD"} {
		err_bind "Only PayPal withdrawals are possible"
		rebind_request_data
		return 0
	}

	# Get the currency of the user from the DB
	set sql {
		select
			ccy_code,
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows != 1} {
		err_bind "Error inserting PayPal payment: There were $nrows returned from the DB when only 1 was expected"
		rebind_request_data
		return 0
	}

	set currency [db_get_col $res 0 ccy_code]
	set acct_id  [db_get_col $res 0 acct_id]

	set ret [ob_paypal::insert_pmt $acct_id $cpm_id "W" $amount \
		$ipaddr $source $unique_id {} {} $currency]

	if {[lindex $ret 0]} {

		set pmt_id [lindex $ret 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		msg_bind "A withdrawal for [lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully initiated"
		return $pmt_id
	} else {
		# Failed
		err_bind "There was an error inserting PayPal payment: [lindex $ret 1]"
		rebind_request_data
		return 0

	}

}


proc do_pmt_referral {} {

	global DB USERID

	set action [reqGetArg SubmitName]
	set pmt_id [reqGetArg pmt_id]

	OT_LogWrite 1 "action=$action"

	if {$action == "Override"} {

		set result [payment_CC::cc_pmt_mark_referred $pmt_id $USERID]
		if {[lindex $result 0] == 0} {
			err_bind [lindex $result 1]

		} else {
			set    msg "Override for the referred payment was successful, "
			append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
			msg_bind $msg
		}

	} elseif {$action == "Decline"} {

		set    msg "Override was declined - payment marked as bad, "
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
	}
	go_pay_mthd_auth
}


proc do_pay_mthd_pmt_PB {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id       [reqGetArg cpm_id]
	set uid          [reqGetArg uniqueId]
	set cust_id      [reqGetArg CustId]
	set ip           [reqGetEnv REMOTE_ADDR]
	set amount       [reqGetArg Amount]
	set type         [reqGetArg DepWtd]
	set auth_code    [reqGetArg auth_code]
	set extra_info   [reqGetArg extra_info]
	set source       [reqGetArg source]

	#
	# get acct_id, and currency code
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	if {$type == "WTD"} {
		#set pay_sort W
		#set commission [reqGetArg wtd_charge]
		err_bind "Withdrawal not allowed on this method"
		rebind_request_data
		return 0

	} else {
		set pay_sort D
		set commission [reqGetArg dep_charge]
	}

	#
	# override the min/max amount
	#
	set min_amt   $amount
	set max_amt   $amount
	set j_op_type ""
	set call_id   ""

	#
	# attempt to make the payment
	#
	set result [payment_PB::pb_pmt_make_payment $acct_id \
					$USERID \
					$uid \
					$pay_sort \
					$amount \
					$cpm_id \
					$source \
					$auth_code \
					$extra_info \
					$j_op_type \
					$min_amt \
					$max_amt \
					$call_id]

	#
	# process the result
	#
	if {[lindex $result 0]} {

		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			set prefix "Withdrawal"
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set prefix "Deposit"

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0]} {
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

		} else {
			error "failed to retrieve payment id from payment table"
		}

		set    msg "$prefix request for [lindex $pmt_detail 1] [lindex $pmt_detail 2] has been sent to the paybox system, "
		append msg "id = <a href=[OT_CfgGet CGI_URL]?action=ADMIN::TXN::GPMT::GoPmt&pmt_id=$pmt_id>$pmt_id</a>"
		msg_bind $msg
		return $pmt_id
	} else {

		rebind_request_data
		err_bind "[lindex $result 1]"
		return 0
	}
}

# BASC payments are actually done by ADMIN::PMT::do_pay_mthd_pmt_BASC in pmt_basc.tcl
proc do_pay_mthd_pmt_BASC {} {
	global DB USERID

	#
	# grab the params
	#
	set cpm_id       [reqGetArg cpm_id]
	set uid          [reqGetArg uniqueId]
	set cust_id      [reqGetArg CustId]
	set ip           [reqGetEnv REMOTE_ADDR]
	set amount       [reqGetArg Amount]
	set type         [reqGetArg DepWtd]
	set location     [reqGetArg location]
	set ref_number   [reqGetArg ref_number]

	#
	# get acct_id, and currency code
	#
	if {[set acct_id [get_acct_id $cust_id]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		return 0
	}

	if {$type == "WTD"} {
		set pay_sort W

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg wtd_charge]
	} else {
		set pay_sort D

		# this is an old commission charge - it will be overwritten below
		# if CHARGE_COMMISSION = 1 in the config
		set commission [reqGetArg dep_charge]
	}

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {
		#
		# first get the currency to calc commmission
		#
		set ccy_code [getCcyCode $cust_id]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission BASC {} $ccy_code $pay_sort $amount]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set commission  [lindex $comm_list 0]
		set amount      [lindex $comm_list 1]
		set tPmt_amount [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set min_amt   $tPmt_amount
		set max_amt   $tPmt_amount

	} else {

		set commission  0.0
		set tPmt_amount $amount
		#
		# override the min/max amount
		#
		set min_amt   $amount
		set max_amt   $amount
	}

	#
	# attempt to make the payment
	#
	set result [insert_payment_BASC $acct_id \
					$cpm_id \
					$pay_sort \
					$amount \
					$commission \
					$ip \
					$USERID \
					$uid \
					$location \
					$ref_number]

	#
	# process the result
	#
	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		# Check whether the payment should be automatically authorised or not
		# Uses the type (dep or wtd) to determine the auto_auth column to select
		set sql [subst {
			select
				i.auto_auth_[string tolower $type]
			from
				tBasicPayInfo i,
				tCPMBasic b
			where
				i.basic_info_id = b.basic_info_id and
				b.cpm_id = ?
		]}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cpm_id]
		inf_close_stmt $stmt

		if {[db_get_coln $res 0 0] == "Y"} {
			set result [auth_payment_BASC $pmt_id "Y" $USERID NULL]

			if {$result != "OK"} {
				error "failed to authorise payment"
				return $pmt_id
			}

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0] && $pay_sort == "D"} {
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
					0
			}
		}

		if {[lindex $pmt_detail 0] == "W"} {
			set prefix "withdrawn from"
		} elseif {[lindex $pmt_detail 0] == "D"} {
			set prefix "deposited into"
		} else {
			error "failed to retrieve payment id from payment table"
		}
		msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully $prefix the users account"

		return $pmt_id
	} else {
		rebind_request_data
		err_bind "[lindex $result 1]"
		return 0
	}
}

proc do_pay_mthd_pmt_EP {} {
	global DB USERID
	global EARTHPORT

	set EARTHPORT(oper_id)      $USERID
	set EARTHPORT(cpm_id)       [reqGetArg cpm_id]
	set EARTHPORT(uid)          [reqGetArg uniqueId]
	set EARTHPORT(cust_id)      [reqGetArg CustId]
	set EARTHPORT(ip)           [reqGetEnv REMOTE_ADDR]
	set EARTHPORT(amount)       [reqGetArg Amount]
	#set EARTHPORT(type)         [reqGetArg DepWtd]
	set EARTHPORT(auth_code)    [reqGetArg auth_code]
	set EARTHPORT(extra_info)   [reqGetArg extra_info]
	set EARTHPORT(source)       [reqGetArg source]

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $EARTHPORT(amount) > 0} {
		#
		# first get the currency to calc commmission
		#
		set ccy_code [getCcyCode $EARTHPORT(cust_id)]

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission EP {} $ccy_code [string index [reqGetArg DepWtd] 0] $EARTHPORT(amount)]

		#
		# get the commission, payment amount and tPmt amount from the list
		#
		set EARTHPORT(commission)  [lindex $comm_list 0]
		set EARTHPORT(amount)      [lindex $comm_list 1]
		set EARTHPORT(tPmt_amount) [lindex $comm_list 2]

		#
		# override the min/max amount
		#
		set EARTHPORT(min_amt)      $EARTHPORT(tPmt_amount)
		set EARTHPORT(max_amt)      $EARTHPORT(amount)
	} else {
		#  Set no commission
		set EARTHPORT(commission)  0.00
		set EARTHPORT(tPmt_amount) $EARTHPORT(amount)

		#
		# override the min/max amount
		#
		set EARTHPORT(min_amt)      $EARTHPORT(amount)
		set EARTHPORT(max_amt)      $EARTHPORT(amount)
	}

	set result [earthport::payout_request]

	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		msg_bind "[reqGetArg Amount] successfully withdrawn from users account"
		return $pmt_id
	} else {
		rebind_request_data
		err_bind [lindex $result 1]
		#err_bind [OB_mlang::ml_printf [lindex $result 2]]
		return 0
	}
}

# Wrapper function to insert Quickcash payment
#
proc do_pay_mthd_pmt_UKSH {} {
	return [_do_pay_mthd_pmt_ukash "UKSH"]
}

# Wrapper function to insert Ukash International payment
#
proc do_pay_mthd_pmt_IKSH {} {
	return [_do_pay_mthd_pmt_ukash "IKSH"]
}

# Helper function to insert Ukash payment.
# UKSH/IKSH uses same DB tables
#
proc _do_pay_mthd_pmt_ukash {pay_mthd} {

	global DB USERID

	set oper_id    $USERID
	set cpm_id     [reqGetArg cpm_id]
	set uid        [reqGetArg uniqueId]
	set cust_id    [reqGetArg CustId]
	set acct_id    [reqGetArg AcctId]
	set ip         [reqGetEnv REMOTE_ADDR]
	set amount     [reqGetArg Amount]
	set auth_code  [reqGetArg auth_code]
	set source     [reqGetArg source]
	set ccy_code   [reqGetArg Currency]
	set unique_id  [reqGetArg uniqueId]
	set type       [reqGetArg DepWtd]

	switch -exact $pay_mthd {
		"UKSH" {
			set cpm_desc "Quickcash"
		}
		"IKSH" {
			set cpm_desc "Ukash International"
		}
		default {
			set cpm_desc $pay_mthd
		}
	}

	if {$type == "DEP"} {

		set voucher [string trim [reqGetArg ukash_voucher]]
		set value   $amount

		# Need to get the value of the voucher in customers currency...
		set ret [ob_ukash::get_settle_amount $acct_id $cpm_id $voucher $value $ccy_code STL]

		if {$ret != {UKASH_OK}} {
			err_bind $ret
			return 0
		}

		set amount     $STL(settleAmount)
		set amount_ref $STL(amountReference)

		set ret [ob_ukash::deposit $acct_id $ccy_code $cpm_id $amount $voucher $value $amount_ref $ip $source $unique_id $USERID]

		if {[lindex $ret 0] == "UKASH_ACCEPTED"} {

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0]} {
				OB_freebets::check_action \
					[list DEP DEP1] \
					$cust_id \
					"" \
					$amount \
					"" \
					"" \
					"" \
					"" \
					[lindex $ret 1] \
					"PMT"\
					"" \
					0 \
					$source
			}

			msg_bind "$amount $ccy_code has been successfully deposited to this account"
		} else {
			err_bind $ret
			return 0
		}
	} elseif {$type == "WTD"} {

		if {$pay_mthd != "UKSH"} {
			err_bind "$cpm_desc does not support withdrawals"
			return 0
		}

		set ret [ob_ukash::withdraw\
			$acct_id\
			$ccy_code\
			$cpm_id\
			$amount\
			[reqGetEnv REMOTE_ADDR]\
			$source\
			$unique_id\
			$USERID]

		if {[lindex $ret 0] == "UKASH_ACCEPTED"} {
			msg_bind "A voucher for $amount $ccy_code has been added to the account"
		} else {
			err_bind $ret
			return 0
		}

	} else {
		err_bind "Expected DEP or WTD but got $type"
		return 0
	}

	set pmt_id [lindex $ret 1]
	return $pmt_id
}

# Perform a MoneyBooker payment
proc do_pay_mthd_pmt_MB {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]
	set ip          [reqGetEnv REMOTE_ADDR]
	set amount      [reqGetArg Amount]
	set type        [reqGetArg DepWtd]
	set pay_type    [reqGetArg pay_type]
	set blurb       [reqGetArg blurb]
	set extra_info  [reqGetArg extra_info]
	set commission  [reqGetArg dep_charge]
	set source      [reqGetArg source]

	set secure_id   [reqGetArg secure_id]

	# grab the customers country and currency
	set ccy_code     [getCcyCode $cust_id]
	set country_code [get_country_code $cust_id]

	set acct_id [get_acct_id $cust_id]

	# config item to turn on payment commissions
	if {[OT_CfgGet CHARGE_COMMISSION 0] && $amount > 0} {

		#
		# calculate the commission, amount to go through the payment gateway,
		# and amount to be inserted into tPmt
		# amount passed to calcCommission is the amount by which the account balance should change
		#
		# calcCommission returns a 3 element list containing (commission, payment_amount, tPmt_amount)
		# commission is the amount of commission to be paid on this payment
		# payment_amount is the amount to go through the payment gateway
		# tPmt_amount is the amount to be inserted into tPmt
		#
		set comm_list [payment_gateway::calcCommission MB {} $ccy_code \
					[string index $type 0] $amount 0 $cust_id $country_code $source]
	}

	if {$type == "WTD"} {
		set result [payment_MB::insert_pmt $acct_id\
											$cpm_id\
											"W"\
											$amount\
											$ip\
											$source\
											$uid\
											$ccy_code\
											""\
											$USERID]
	} else {
		err_bind "Invalid transaction type"
		rebind_request_data
		return 0
	}

	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "W"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account, the payment is currently pending for approval."
		}
		return $pmt_id
	} else {
		set msg [ADMIN::XLATE::get_translation en [lindex $result 1]]
		if {$msg == ""} {
			set msg [lindex $result 1]
		}
		err_bind "Error inserting MoneyBookers payment: $msg Code:[lindex $result 2]"
		rebind_request_data
		return 0
	}
}

# Perform a shop payment
proc do_pay_mthd_pmt_SHOP {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id      [reqGetArg cpm_id]
	set amount      [reqGetArg Amount]
	set ip          [reqGetEnv REMOTE_ADDR]
	set uid         [reqGetArg uniqueId]
	set cust_id     [reqGetArg CustId]

	set shop_pmt_type  [reqGetArg PaymentType]
	set ticket_num     [reqGetArg TicketNumber]
	set staff_member   [reqGetArg StaffMember]

	#
	# get acct_id
	#
	if {[set acct_id [get_acct_id [reqGetArg CustId]]] == -1} {
		err_bind "Could not find account for this customer"
		rebind_request_data
		go_pay_mthd_pmt [reqGetArg DepWtd]
		return 0
	}

	if {[reqGetArg DepWtd] == "WTD"} {
		#
		# validate entered security number
		#
		set stmt [inf_prep_sql $DB {
			select
				security_number
			from
				tcpmshop
			where
				cpm_id = ?
		}]

		set rs [inf_exec_stmt $stmt $cpm_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] == 0} {
			db_close $rs
			err_bind "Could not find the security number for this customer"
			rebind_request_data
			return 0
		}

		set valid_security_number [db_get_col $rs 0 security_number]
		db_close $rs

		if {$valid_security_number != [reqGetArg SecurityNumber]} {
			err_bind "The security number entered is invalid for this customer"
			rebind_request_data
			return 0
		}
	}

	#
	# get pay_sort
	#
	if {[reqGetArg DepWtd] == "WTD"} {
		set pay_sort "W"
	} else {
		set pay_sort "D"
	}

	#
	# get the channel for betting shop accounts
	#
	set stmt [inf_prep_sql $DB {
		select
			channel_id
		from
			tchangrplink
		where
			channel_grp = 'SHOP';
	}]

	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "No channel/group defined for Shop Fielding accounts, payment cannot be made"
		rebind_request_data
		return 0
	}

	set source [db_get_col $rs 0 channel_id]
	db_close $rs

	#
	# get the shop_id from the shop number
	#
	set stmt [inf_prep_sql $DB {
		select
			shop_id
		from
			tRetailShop
		where
			shop_no = ?;
	}]

	set rs [inf_exec_stmt $stmt [reqGetArg ShopNumber]]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		db_close $rs
		err_bind "Invalid shop number, payment cannot be made"
		rebind_request_data
		return 0
	}

	set shop_id [db_get_col $rs 0 shop_id]
	db_close $rs

	#
	# Not sure what to do about the commission at this time
	#
	set commission 0.0
	set min_amt   $amount
	set max_amt   $amount

	#
	# insert this payment
	#
	set result [insert_payment_SHOP $acct_id \
					$cpm_id \
					$pay_sort \
					$amount \
					$commission \
					$ip \
					$source \
					$USERID \
					$uid \
					$min_amt \
					$max_amt \
					$shop_id \
					$shop_pmt_type \
					$ticket_num \
					$staff_member]

	if {[lindex $result 0]} {
		set pmt_id [lindex $result 1]
		set pmt_detail [get_pmt_detail $pmt_id]

		if {[lindex $pmt_detail 0] == "D"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully deposited to this account"
		} elseif {[lindex $pmt_detail 0] == "W"} {
			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account"
		} else {
			error "failed to retrieve payment id from payment table"
		}

		if {[OT_CfgGet FUNC_PMT_SHOP_AUTO_AUTH 0]} {
			set auth_res [auth_payment_SHOP $pmt_id Y $USERID ""]

			if {$auth_res != "OK"} {
				error "failed to authorise payment"
			}

			# payment successful and authorised call freebets
			if {[OT_CfgGet ADMIN_PAYMENTS_FREEBETS 0] &&
				[lindex $pmt_detail 0] == "D"} {

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
		}

		return $pmt_id

	} else {
		err_bind "Error inserting shop payment: [lindex $result 1]"
		rebind_request_data
		return 0
	}
}

#
# Click and Buy withdrawal.
#
proc do_pay_mthd_pmt_CB {} {

	global DB USERID

	#
	# grab the params
	#
	set cpm_id    [reqGetArg cpm_id]
	set cust_id   [reqGetArg CustId]
	set amount    [reqGetArg Amount]
	set type      [reqGetArg DepWtd]
	set source    [reqGetArg source]
	set ipaddr    [reqGetEnv REMOTE_ADDR]
	set unique_id [reqGetArg uniqueId]

	# Get the currency of the user from the DB
	set sql {
		select
			ccy_code,
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	ob::log::write DEBUG {do_pay_mthd_pmt_CB : cpm_id = $cpm_id, type = $type, amount = $amount}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	ob::log::write DEV {do_pay_mthd_pmt_CB : nrows after that is $nrows}
	if {$nrows != 1} {
		err_bind "Error inserting Click and Buy payment: There were $nrows returned from the DB when only 1 was expected"
		rebind_request_data
		return 0
	}

	set currency [db_get_col $res 0 ccy_code]
	set acct_id  [db_get_col $res 0 acct_id]

	if {$type == "WTD"} {

		# We won't have a valid bdr_id until we get the response from Click and Buy
		set cb_bdr_id ""

		# Insert the payment, goes in as pending so will not be processed immediately
		set ret [ob_clickandbuy::insert_pmt $acct_id $cpm_id "W" $amount \
					"P" $ipaddr $source $unique_id $cb_bdr_id $currency]

		if {[lindex $ret 0]} {

			set pmt_id     [lindex $ret 1]
			set pmt_detail [get_pmt_detail $pmt_id]

			msg_bind "[lindex $pmt_detail 1] [lindex $pmt_detail 2] has been successfully withdrawn from this account and is pending for processing"
			return $pmt_id
		} else {

			# Failed, get payment error code
			set code [payment_gateway::cc_pmt_get_sp_err_code [lindex $ret 1]]
			err_bind "Error inserting Click and Buy payment: [payment_gateway::pmt_gtwy_xlate_err_code $code]"
			rebind_request_data
			return 0
		}

	}

}


#
# Perform a Barclays BACS Transfer
#
proc do_pay_mthd_pmt_BARC {} {

	global DB

	# Grab the request arguments
	set cpm_id    [reqGetArg cpm_id]
	set cust_id   [reqGetArg CustId]
	set acct_id   [reqGetArg AcctId]
	set amount    [reqGetArg Amount]
	set type      [reqGetArg DepWtd]

	if {$type != "DEP"} {
		# This is a deposit only method
		OT_LogWrite 5 "do_pay_mthd_pmt_BARC: Barclays BACS Transfer is deposit only"
		err_bind "Error: Barclays BACS Transfer only supports deposits"
		rebind_request_data
		return 0
	}

	set sql {
		insert into tEmailQueue (
			email_id,
			ref_key,
			reason,
			msg_type
		) values (
			(select email_id from tEmail where type = (select type_id from tEmailType where name = 'ACCT_BARC_BACS')),
			'BARC',
			?,
			'E'
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	#
	# Add a payment email to the queue
	#
	set reason "Account ID:  $acct_id   Amount ([reqGetArg CustCurrency]):  $amount"

	if {[catch {
		inf_exec_stmt $stmt $reason
	} msg]} {
		OT_LogWrite 5 "do_pay_mthd_pmt_BARC: Failed to add Barclays BACS \
			Transfer email to the queue - $msg"
		err_bind "Failed to add Barclays BACS Transfer email to the queue"
		rebind_request_data
		return 0
	}

	#
	# We have been successful
	#
	msg_bind "Barclays BACS Transfer successful"
	return 0

}

# get the currency for the specified customer
proc getCcyCode {cust_id} {
	global DB

	# Get the currency of the user from the DB
	set sql {
		select
			ccy_code
		from
			tAcct
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 0} {
		ob::log::write ERROR "No rows returned by ccy query in proc getCcyCode for cust $cust_id"
	}

	set ccy_code [db_get_col $res 0 ccy_code]
	db_close $res
	return $ccy_code
}

proc get_country_code {cust_id} {

	global DB

	set sql {
		select
			country_code
		from
			tcustomer
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set country_code [db_get_col $res 0 country_code]
	db_close $res

	return $country_code
}

# Bind data for displaying the shop deposit/withdrawal screen
proc bind_data_SHOP {} {
	global SHOP_PAYMENT_TYPES

	array set SHOP_PAYMENT_TYPES [list]

	set payment_list {\
		CSH "Cash" \
		CHQ "Cheque" \
		SWT "Switch" \
		SOL "Solo" \
		DLT "Delta" \
		ELT "Electron" \
		CDT "Credit Card" \
		LSR "Laser Card"}

	set idx 0

	foreach {code name} $payment_list {
		set SHOP_PAYMENT_TYPES($idx,payment_code)  $code
		set SHOP_PAYMENT_TYPES($idx,payment_name)  $name
		incr idx
	}

	tpSetVar num_payments [expr [llength $payment_list] / 2]
	tpBindVar PaymentCode SHOP_PAYMENT_TYPES payment_code payment_idx
	tpBindVar PaymentName SHOP_PAYMENT_TYPES payment_name payment_idx
}

# close namespace
}
