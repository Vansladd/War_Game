# ==============================================================
# $Id: pmt_mthd_auth.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::go_pay_mthd_auth [namespace code go_pay_mthd_auth]
asSetAct ADMIN::PMT::do_pay_mthd_auth [namespace code do_pay_mthd_auth]



proc go_pay_mthd_auth args {

	global DB CPM CPM_LINKS

	OT_LogWrite 5 "==> go_pay_mthd_auth"

	set cpm_id            [reqGetArg cpm_id]
	set pay_mthd          [reqGetArg pay_mthd]
	set cust_id           [reqGetArg CustId]
	set from_cust_details [reqGetArg from_cust_details]

	tpSetVar        pay_mthd           $pay_mthd
	tpBindString    pay_mthd           $pay_mthd
	tpSetVar        cpm_id             $cpm_id
	tpBindString    cpm_id             $cpm_id
	tpSetVar        CustId             $cust_id
	tpBindString    CustId             $cust_id
	tpSetVar        from_cust_details  $from_cust_details
	tpBindString    from_cust_details  $from_cust_details
	tpSetVar        ShowCCAuditButton  1


	OT_LogWrite 5 "cust_id = $cust_id"
	OT_LogWrite 5 "cpm_id  = $cpm_id"

	#
	# Get details of this payment method
	#
	set sql [subst {
		select
			m.status,
			m.auth_dep,
			m.status_dep,
			m.order_dep,
			m.auth_wtd,
			m.status_wtd,
			m.order_wtd,
			m.oper_notes,
			m.disallow_dep_rsn,
			m.disallow_wtd_rsn,
			m.type,
			m.num_fails,
			m.last_fail_reason,
			m.pmb_period,
			m.deposit_check,
			p.desc,
			c.elite,
			c.username
		from
			tCustPayMthd m,
			tPayMthd p,
			tCustomer c
		where
			m.cpm_id        = ? and
			m.pay_mthd      = p.pay_mthd and
			m.cust_id       = c.cust_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	set elite 0

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
		if {$c == {status}} {
			tpSetVar PM_$c [db_get_col $res 0 $c]
		}
		if {$c == "elite" && [db_get_col $res 0 $c] == "Y"} {
			set elite 1
		}
	}

	tpSetVar IS_ELITE $elite
	tpBindString Username           [db_get_col $res 0 username]


	# Rebind the description to MCA rather than Basic Pay if Ladbrokes
	if {$pay_mthd == "BASC" && [OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
		tpBindString PM_desc "MCA"
	}

	#
	# check whether to show the deposit/withdrawal options
	#
	set status          [db_get_col $res 0 status]
	set status_dep      [db_get_col $res 0 status_dep]
	set auth_dep        [db_get_col $res 0 auth_dep]
	set status_wtd      [db_get_col $res 0 status_wtd]
	set auth_wtd        [db_get_col $res 0 auth_wtd]


	tpSetVar ShowDep 0
	tpSetVar ShowWtd 0

	if {$status == "A" && $status_dep == "A" && ($auth_dep == "Y" || $auth_dep == "P")} {
		tpSetVar ShowDep 1
	}
	if {$status == "A" && $status_wtd == "A" && ($auth_wtd == "Y" || $auth_wtd == "P")} {
		tpSetVar ShowWtd 1
	}
	if {$pay_mthd == "GDEP" || $pay_mthd == "PB" || $pay_mthd == "ENET" || [OT_CfgGet DISALLOW_WTD_${pay_mthd} 0]} {
		tpSetVar ShowWtd 0
	}
	if {$pay_mthd == "GWTD" || $pay_mthd == "EP" || $pay_mthd == "ENET" || $pay_mthd == "MB" || $pay_mthd == "CB" || [OT_CfgGet DISALLOW_DEP_${pay_mthd} 0]} {
		tpSetVar ShowDep 0
	}

	db_close $res

	#
	# Get the details for any linked methods
	#
	set sql {
		select
			l2.cpm_id,
			DECODE(l2.type, 'D', 'Deposit', 'W', 'Withdraw','B','Withdraw') as link_type,
			pm.pay_mthd
		from
			tCPMGroupLink l1,
			tCPMGroupLink l2,
			tCustPayMthd  pm
		where
			    l1.cpm_id = ?
			and l2.cpm_grp_id = l1.cpm_grp_id
			and ((l2.type not in ('B', 'E'))
			or (l2.type ='B' and pm.pay_mthd IN ('BANK','CHQ')))
			and l2.type != l1.type
			and pm.cpm_id = l2.cpm_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	set CPM_LINKS(count) [db_get_nrows $rs]
	for {set i 0} {$i < $CPM_LINKS(count)} {incr i} {
		set CPM_LINKS($i,cpm_id)        [db_get_col $rs $i cpm_id]
		set CPM_LINKS($i,link_type)     [db_get_col $rs $i link_type]
		set CPM_LINKS($i,link_pay_mthd) [db_get_col $rs $i pay_mthd]
	}

	db_close $rs

	tpSetVar   NumLinkedMethods $CPM_LINKS(count)
	tpBindVar  LinkedCpmId    CPM_LINKS  cpm_id         l_idx
	tpBindVar  LinkType       CPM_LINKS  link_type      l_idx
	tpBindVar  LinkedPayMthd  CPM_LINKS  link_pay_mthd  l_idx

	global CPM_CUST
	global PMT_SEARCH

	tpBindString PaymentListTitle "Other payment methods"

	ADMIN::CUST::get_cust_pmt_mthds $cust_id $cpm_id

	if {[OT_CfgGet FUNC_ONEPAY 0]} {
		set cust_ccy [ventmear::get_cust_ccy $cust_id]

		tpSetVar onepay_options [ventmear::is_1pay_ccy $cust_ccy]

		if {[ventmear::get_1pay_status $cpm_id] == "OP"} {
			tpBindString OP_CHECKED "checked=\"true\""
		}
	}

	# Bind up the customers current AV status.
	# If FUNC_OVS is not enabled , users wont be able to see Make Withdrawal button in pmt/pmt_auth.html
	if {[OT_CfgGet FUNC_OVS 0]} {
		tpBindString av_status [verification_check::get_ovs_status $cust_id "AGE"]
	}

	asPlayFile -nocache pmt/pmt_auth.html

	catch {unset PMT}
}


proc do_pay_mthd_auth args {
	global DB

	if {[reqGetArg SubmitName] == "Back"} {
		go_auth_qry
		return

	} elseif {[reqGetArg SubmitName] == "DoDep"} {
		go_pay_mthd_pmt DEP
		return

	} elseif {[reqGetArg SubmitName] == "DoWtd"} {
		go_pay_mthd_pmt WTD
		return

	} elseif {[reqGetArg SubmitName] == "UpdEP"} {
		do_upd_EP_details
		return
	} elseif {[reqGetArg SubmitName] == "ZeroCPMFails"} {
		zero_cpm_fails
		return
	} elseif {[reqGetArg SubmitName] == "UpdPMBExpiry"} {
		do_upd_pmb_expiry
		return
	} elseif {[reqGetArg SubmitName] == "UpdEnvoyDetails"} {
		do_upd_envoy_details
		return
	}

	set pay_mthd      [reqGetArg pay_mthd]
	set cust_id       [reqGetArg CustId]
	set cpm_id        [reqGetArg cpm_id]
	set others        [reqGetArg UpdateAction]
	set status        [reqGetArg status]
	set auth_dep      [reqGetArg auth_dep]
	set status_dep    [reqGetArg status_dep]
	set order_dep  	  [reqGetArg order_dep]
	set auth_wtd      [reqGetArg auth_wtd]
	set status_wtd    [reqGetArg status_wtd]
	set order_wtd     [reqGetArg order_wtd]
	set van_id        [reqGetArg van_id]
	set deposit_check [reqGetArg deposit_check]
	set prev_status   [reqGetArg prev_status]

	if {$status == "A" && $prev_status != "A"} {
		## If the status is changing to A, check we are not exceeding the
		## max limits
		set ok 0
		set can_reg [payment_multi::get_mthd_can_register $cust_id $pay_mthd]
		if {[lindex $can_reg 0]} {
			set ok [lindex $can_reg 1]
		}

		if {!$ok} {
			set err_msg "Cannot activate method due to max method limits"
			ob_log::write WARNING $err_msg
			err_bind $err_msg
			rebind_request_data
			go_pay_mthd_auth
			return
		}
	}

	if {$pay_mthd == "CC"} {



		#
		# retrieve card details for this id
		#
		set sql {
			select
				cc.enc_card_no,
				cc.start,
				cc.expiry,
				cc.issue_no,
				cc.card_bin,
				cc.ivec,
				cc.data_key_id,
				cc.enc_with_bin,
				a.acct_type,
				a.settle_type
			from
				tCpmCC cc, tAcct a
			where
				cc.cust_id = a.cust_id and
				cpm_id = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cpm_id]
		inf_close_stmt $stmt

		if {[OT_CfgGet FUNC_CC_CHECKS_ON_REMOVE 0] == 1 && $status eq "X"} {
			#
			# Check if we can remove this card using the card change rules
			#

			# Checks
			set results [cc_change::perform_checks $cust_id]
			foreach {- checks} $results { break }

			set check_codes    [list]
			set errs           [list]
			set removal_checks [OT_CfgGet CC_CHECKS_ON_REMOVE {}]

			ob_log::write INFO ">>> Evalutating CC change checks for \
								CPM:$cpm_id - and Customer$cust_id"

			foreach c $checks {
				foreach {success - check value} $c { break }
				lappend check_codes $check

				# Only if it's one of the configured checks for removal
				if { [lsearch -exact $removal_checks $check] >= 0 } {

					# We don't have to specialize, but all the alternatives are
					# listed so that we know the ones we are expecting to see
					switch -exact $check {
						"CC_CHANGE_BALANCE"                   -
						"CC_CHANGE_TOTAL_BALANCE"             -
						"CC_CHANGE_UNSETTLEDBETS"             -
						"CC_CHANGE_PENDINGPMTS"               -
						"CC_CHANGE_CHECK_OPEN_SUBS"           -
						"CC_CHANGE_GAME_ACCT_BALANCE"         -
						"CC_CHECK_PLAYTECHPOKER_FUNDS"        -
						"CC_CHECK_PLAYTECHCASINO_FUNDS"       -
						"CC_CHECK_PLAYTECHPOKER_BONUS"        -
						"CC_CHECK_PLAYTECHCASINO_BONUS"       -
						"CC_CHECK_PLAYTECH_RING_TOURN_FUNDS"  -
						"CC_CHANGE_GAMESMULTISTATE" {
							if {$success == 0 || $success == 2} {
								ob_log::write INFO \
									{ XXX - Failed CC change check - $check}
								lappend errs $check
							} else {
								ob_log::write INFO \
									{ ./  -Success CC change check - $check}
							}
						}
					}
				}
			}

			ob_log::write INFO " <<< CC change checks end"

			set nerrs [llength $errs]

			if {[lindex $results 0] == 2} {
				ob_log::write WARNING {Credit Card Change checks \
				    were not performed prior to card removal.}
			} else {
				if {$nerrs > 0} {
					set err_msg "Cannot remove credit card \
					    ($nerrs checks failed)<br/> [join $errs </br>]"
					ob_log::write WARNING $err_msg
					err_bind $err_msg
					rebind_request_data
					go_pay_mthd_auth
					return
				}
			}
		}

		#
		# An old bug means some CC payment methods have no cards. Allow these to
		# be suspended or removed.
		#

		set num_cards [db_get_nrows $res]

		if {$num_cards > 0} {
			set enc_card_no  [db_get_col $res 0 enc_card_no]
			set start        [db_get_col $res 0 start]
			set expiry       [db_get_col $res 0 expiry]
			set issue_no     [db_get_col $res 0 issue_no]
			set card_bin     [db_get_col $res 0 card_bin]
			set ivec         [db_get_col $res 0 ivec]
			set data_key_id  [db_get_col $res 0 data_key_id]
			set enc_with_bin [db_get_col $res 0 enc_with_bin]
			set acct_type    [db_get_col $res 0 acct_type]
			set settle_type  [db_get_col $res 0 settle_type]
		}

		db_close $res

		#
		# Allow the payment method to be suspended or removed.
		#

		if {$num_cards == 0} {

			ob::log::write INFO { No card found - continue changing status to $status }

			if {$status != "A"} {

				inf_begin_tran $DB

				set sql_suspend [subst {
					update tCustPayMthd
					set
						status = ?
					where
						cpm_id = ?
				}]

				set stmt_suspend [inf_prep_sql $DB $sql_suspend]

				set c [catch {
					inf_exec_stmt $stmt_suspend\
								  $status \
								  $cpm_id

					inf_close_stmt $stmt_suspend
				} msg]

				if {$c} {
					inf_rollback_tran $DB
					ob::log::write INFO { $msg }
					err_bind "failed to update payment method: $msg "
					rebind_request_data
				} else {
					inf_commit_tran $DB
					go_pay_mthd_auth
					return
				}
			}
		}

		#
		# Only allow activation of credit cards on debit accounts
		# if cleardown (tAcct.settle_type) is 'N'
		#
		if {$status == "A" && $acct_type == "DBT" && $settle_type != "N"} {

			card_util::cd_get_req_fields $card_bin CARD_DATA

			if {$CARD_DATA(type) == "CDT"} {
				err_bind "Cannot activate a Credit Card unless Settle Type is set to 'Never' for this customer"
				rebind_request_data
				go_pay_mthd_auth
				return
			}
		}

		#
		# now recheck whether this card is active on another account etc. etc.
		#
		if {$status == "A" || $status == "S"} {

			if {![op_allowed OverrideDuplicateCPM]} {

				set card_dec_rs [card_util::card_decrypt $enc_card_no $ivec $data_key_id]

				if {[lindex $card_dec_rs 0] == 0} {
					# Check on the reason decryption failed, if we encountered corrupt data we should also
					# record this fact in the db
					if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
						card_util::update_data_enc_status "tCPMCC" $cpm_id [lindex $card_dec_rs 2]
					}

					err_bind "Decryption error: [lindex $card_dec_rs 1]"
					rebind_request_data
					go_pay_mthd_auth
					return
				} else {
					set dec_card_no [lindex $card_dec_rs 1]
				}

				set card_no [card_util::format_card_no $dec_card_no $card_bin $enc_with_bin]

				if {![card_util::verify_card_not_used $card_no $cust_id]} {
					err_bind "Cannot update this card: duplicate card found on another account"
					rebind_request_data
					go_pay_mthd_auth
					return
				}
			}
		}
	}

	if {[OT_CfgGet CLICK2PAY_CHECK_DUP 1] == 1 && $pay_mthd == "C2P" && $status == "A"} {

		set resGetPan [ob_click2pay::c2p_get_pan $cpm_id]
		set failed 0

		if {[lindex $resGetPan 0]} {

			set pan [lindex $resGetPan 1]
			# Check if this PAN is already active or suspended on the customer's account
			# or different account
			set resVerifyPan [ob_click2pay::verify_pan_not_used $pan $cpm_id]

			if {![lindex $resVerifyPan 0]} {
				set msg [lindex $resVerifyPan 1]
				set failed 1
			} else {
				# Check if different pan is already active on the customer's account
				set resVerifyCPM [ob_click2pay::c2p_get_cpm_details $cust_id]
				if {[lindex $resVerifyCPM 0] && [lindex $resVerifyCPM 1] != $cpm_id} {
					set msg "Different PAN is already active (cpm_id=[lindex $resVerifyCPM 1])"
					set failed 1
				} else {
					set failed 0
				}
			}
		} else {
			set msg [lindex $resGetPan 1]
			set failed 1
		}

		if {$failed} {
			err_bind "Cannot update this clic2pay account: $msg"
			rebind_request_data
			go_pay_mthd_auth
			return
		}
	}

	if {$pay_mthd == "SHOP" && [op_allowed ShopPaymentSecurityE]} {
		# Need to update the security number if it has been changed
		if {[reqGetArg PM_security_number_current] != [reqGetArg PM_security_number]} {
			set sql {
				update tCPMShop set
					security_number = ?
				where
					cpm_id = ?
			}

			set c [catch {
				set stmt [inf_prep_sql $DB $sql]
				inf_exec_stmt $stmt [reqGetArg PM_security_number] $cpm_id
				inf_close_stmt $stmt
			} msg]

			if {$c} {
				err_bind "Can't update the payment method security number: $msg"
				rebind_request_data
				go_pay_mthd_auth
				return
			}
		}
	}

	set sql_gen [subst {
		update tCustPayMthd set
			status = ?,
			auth_dep = ?,
			status_dep = ?,
			order_dep = ?,
			auth_wtd = ?,
			status_wtd = ?,
			order_wtd = ?,
			oper_notes = ?,
			disallow_dep_rsn = ?,
			disallow_wtd_rsn = ?,
			deposit_check = ?
		where
			cpm_id = ?
	}]

	set stmt_gen [inf_prep_sql $DB $sql_gen]

	inf_begin_tran $DB

	set c [catch {
		inf_exec_stmt $stmt_gen\
						$status \
						$auth_dep \
						$status_dep \
						$order_dep \
						$auth_wtd \
						$status_wtd \
						$order_wtd \
						[reqGetArg oper_notes]\
						[reqGetArg disallow_dep_rsn]\
						[reqGetArg disallow_wtd_rsn]\
						$deposit_check \
						$cpm_id

		inf_close_stmt $stmt_gen
	} msg]

	if {$c} {
		inf_rollback_tran $DB
		err_bind "failed to update payment method: $msg "
		rebind_request_data

	} else {
		inf_commit_tran $DB

		# Send message to earthport to close account iff status is 'X'
		if {$status == {X} && $van_id != ""} {
			set result   [earthport::close_account_req $van_id]
			if {[lindex $result 0] == 0} {
				ob::log::write ERROR {[lindex $result 1]}
			} else {
				ob::log::write INFO { Close earthport a/c => Successful }
			}
		}
	}

	# Attempt to change tCustPayMthd.type for eligible customers.
	if {[OT_CfgGetTrue ENTROPAY] && [entropay::is_entropay_cpm $cpm_id]} {
		entropay::upd_entropay_cpm $cpm_id
	} elseif {[OT_CfgGet FUNC_ONEPAY 0]} {
		set op [reqGetArg gw]
		if {$op == ""} {set op 0}
		ventmear::set_1pay_cpmtype $cpm_id $op
	}

	go_pay_mthd_auth
}


#
# Display deposit/withdraw page for a given payment method
#
proc go_pay_mthd_pmt {type} {

	OT_LogWrite 5 "==> go_pay_mthd_pmt"

	set cust_id  [reqGetArg CustId]
	set pay_mthd [reqGetArg pay_mthd]
	set cpm_id   [reqGetArg cpm_id]

	if {[lsearch {"WTD" "DEP"} $type] == -1} {
		err_bind "Invalid payment type"
		rebind_request_data
		go_pay_mthd_auth
	}

	if {[lsearch -exact {CC CHQ BANK GDEP GWTD CSH PB EP BC NTLR BASC WU ENET MB C2P PPAL SHOP UKSH IKSH CB BARC} $pay_mthd] == -1} {

		err_bind "Invalid payment method"
		rebind_request_data
		go_pay_mthd_auth
		return
	}

	if {$pay_mthd == "PPAL" && $type == "DEP"} {
		err_bind "You cannot make a PayPal deposit"
		rebind_request_data
		go_pay_mthd_auth
		return
	}

	# is the customer KYC withdrawal blocked?
	if {$type == "WTD" && [OT_CfgGet FUNC_KYC 0]} {

		foreach {res block} [ob_kyc::cust_is_blocked [reqGetArg CustId] 1] {}

		if {$res != "OK"} {
			err_bind "Failed to go to withdrawal page - unable to check KYC status"
			rebind_request_data
			go_pay_mthd_auth
			return
		}

		if {$block} {

			# if allowed to override - warn the user
			if {[op_allowed OverrideKYCWtdBlock]} {
				tpBindString IsKYCOverride 1
			# else play appropriate error
			} else {
				err_bind " Customer is KYC restricted - withdrawal not possible"
				rebind_request_data
				go_pay_mthd_auth
				return
			}
		}
	}

	if {[OT_CfgGet FUNC_PMT_SURCHARGE 0]} {
		get_pmt_surcharges $cust_id $pay_mthd
	}

	# are they domestic customers? Have they received their free cheques?
	if {[OT_CfgGet FUNC_WTD_FREE_CHQ 0] && $type =="WTD"} {
		set free_chq [get_free_charges $cust_id $pay_mthd]

		if {$free_chq >0} {
			tpBindString WtdCharge "0.00"
		}
	}

	#
	# set the cust id so we can retrieve customer details later
	#
	tpSetVar        CustId  $cust_id
	tpSetVar        DepWtd  $type
	tpBindString    DepWtd  $type
	tpSetVar        cpm_id  $cpm_id
	tpBindString    cpm_id  $cpm_id
	tpBindString    pay_mthd $pay_mthd
	tpBindString    desc [reqGetArg desc]

	#
	# display the channels
	#
	set mask [make_channel_mask [OT_CfgGet PMT_EXCLUDED_CHANNELS ""]]
	make_channel_binds  "" $mask 1 1

	#
	# play the appropriate template
	#
	OT_LogWrite 5 "playing pmt/pmt_${pay_mthd}.html"
	asPlayFile -nocache "pmt/pmt_${pay_mthd}.html"

}


proc get_pmt_surcharges {cust_id pay_mthd} {

	# get surcharges for depositing
	global DB

	# first get the customer's currency/country and the default country
	set sql [subst {
		select
			c.country_code,
			a.ccy_code,
			t.default_country
		from
			tCustomer  c,
			tAcct       a,
			tControl    t
		where
			c.cust_id = a.cust_id and
			c.cust_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		set $c [db_get_col $res 0 $c]
	}

	db_close $res

	# get surcharges depending if customer is domestic or international
	set fee_sql [subst {
		select dep_charge,
			wtd_charge,
			int_dep_charge,
			int_wtd_charge
		from
			tPMTSurcharge
		where
			pay_mthd = ? and
			ccy_code = ?
	}]
	set stmt [inf_prep_sql $DB $fee_sql]
	set fee_res [inf_exec_stmt $stmt $pay_mthd $ccy_code]
	inf_close_stmt $stmt

	if {$country_code == $default_country} {
		set dep_charge [db_get_col $fee_res 0 dep_charge]
		set wtd_charge [db_get_col $fee_res 0 wtd_charge]
	} else {
		set dep_charge [db_get_col $fee_res 0 int_dep_charge]
		set wtd_charge [db_get_col $fee_res 0 int_wtd_charge]
	}

	db_close $fee_res

	tpBindString DepCharge $dep_charge
	tpBindString WtdCharge $wtd_charge

}

#
# Is this a free cheque withdrawal
# Return 1 if the withdrawal is a free cheque, else 0
#
proc get_free_charges {cust_id pay_mthd} {
	global DB

	if {$pay_mthd != "CHQ"} {
		return 0
	}

	# are they domestic players?
	set sql [subst {
		select c.cust_id,
			a.ccy_code,
			a.acct_id
		from tCustomer c,
			tAcct      a,
			tControl   t
		where c.cust_id = a.cust_id
		and c.country_code = t.default_country
		and c.cust_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	set nrows [db_get_nrows $res]

	# if international player, return 0
	if {$nrows == 0} {
		db_close $res
		return 0
	} else {
		set ccy_code [db_get_col $res 0 ccy_code]
		set acct_id  [db_get_col $res 0 acct_id]
	}
	db_close $res

	# number of free cheques and period
	set sql [subst {
		select free_txn,
			free_txn_period
		from tPMTSurcharge
		where pay_mthd = ?
		and ccy_code = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pay_mthd $ccy_code]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] > 0} {
		set free_txn [db_get_col $res 0 free_txn]
		set free_txn_period [db_get_col $res 0 free_txn_period]
	} else {
		OT_LogWrite 5 "Error getting free_txn for paymthd $pay_mthd and ccy_code $ccy_code"
		return 0
	}
	db_close $res

	# number of cheque withdrawals by customer for the given period
	set sql [subst {
		select count(*) as num_wtd
		from tPMT
		where ref_key = 'CHQ'
		and payment_sort = 'W'
		and status <> 'N'
		and acct_id = ?
		and cr_date - current < interval ($free_txn_period) day to day
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] > 0} {
		set num_wtd [db_get_col $res 0 num_wtd]
	}

	db_close $res

	if {$num_wtd < $free_txn} {
		return 1
	} else {
		return 0
	}

}

##
# Update Earthport payment method details
##
proc do_upd_EP_details args {
	global DB USERID EARTHPORT

	ob::log::write INFO {do_upd_EP_details}

	set cpm_id                  [reqGetArg cpm_id]
	set van_id                  [reqGetArg van_id]
	set cust_id                 [reqGetArg CustId]
	set new_cpm_id              $cpm_id
	set pm_status               [reqGetArg status]

	set EARTHPORT(OPER_ID)      $USERID
	set EARTHPORT(CUST_ID)      $cust_id
	set EARTHPORT(COUNTRY)      [reqGetArg bank_country]
	set EARTHPORT(BANKCCY)      [reqGetArg ep_ccy]
	set EARTHPORT(ACCCY)        [reqGetArg ep_ccy]
	set EARTHPORT(BANKNAME)     [reqGetArg -unsafe bank_name]
	set EARTHPORT(HOLDING)      [reqGetArg -unsafe holding]
	set EARTHPORT(ACNAME)       [reqGetArg -unsafe ac_name]
	set EARTHPORT(DESCRIPTION)  [reqGetArg -unsafe desc]
	set EARTHPORT(ACNUM)        [reqGetArg -unsafe ac_num]
	set EARTHPORT(BANKSORT)  	[reqGetArg -unsafe bank_sort]
	set EARTHPORT(BRANCHCODE)  	[reqGetArg -unsafe branch_code]
	set EARTHPORT(BANK_CODE)  	[reqGetArg -unsafe bank_code]

	#
	# Get Card Details
	#
	array set CARD ""
	card_util::cd_get_active [reqGetArg CustId] CARD
	if {$CARD(card_available) == "Y"} {
		set EARTHPORT(ALLOW_WTD) "P"
		set EARTHPORT(MULT_CPM)	 "Y"
	} else {
		set EARTHPORT(ALLOW_WTD) "Y"
		set EARTHPORT(MULT_CPM)	 "N"
	}

	# Suspend customers current EP account
	set sql_gen [subst {
		update tCustPayMthd set
			status = ?
		where
			cpm_id = ?
	}]

	set stmt_gen [inf_prep_sql $DB $sql_gen]

	if {[catch {inf_exec_stmt $stmt_gen "X" $cpm_id} msg]} {
		ob::log::write ERROR {failed to update payment method: $msg}
		err_bind "failed to update payment method: $msg"
	} else {

		# Send message to earthport to change account details
		set result [earthport::change_bank_details $van_id]

		if {[lindex $result 0] != 1} {
			ob::log::write ERROR {[lindex $result 1]}
			err_bind "[lindex $result 1]"

			# Error occurred in connecting to Earthport
			# Reset the status of the customers EP payment method to what it previously
			set stmt_gen [inf_prep_sql $DB $sql_gen]

			if {[catch {inf_exec_stmt $stmt_gen $pm_status $cpm_id} msg]} {
				ob::log::write ERROR {failed to update payment method: $msg}
				err_bind "failed to update payment method: $msg"
			}
		} else {
			set new_cpm_id [lindex $result 1]
		}
	}

	ob::log::write DEV {do_upd_EP_details => Old cpm id: $cpm_id; New cpm id : $new_cpm_id}

	# Set arguments & reload the page
	reqSetArg cpm_id  $new_cpm_id
	reqSetArg cust_id $cust_id
	reqSetArg pay_mthd "EP"

	go_pay_mthd_auth
}



# Update Envoy details
proc do_upd_envoy_details {} {

	global DB USERID

	if {![op_allowed EditCPMEnvoyEwallet]} {
		err_bind "You do not have permission"
		go_pay_mthd_auth
		return
	}

	set sub_type [ob_chk::get_arg sub_mthd_code -on_err "" ALNUM]

	if {[payment_ENVO::get_envo_ewallet_detail $sub_type add_info_type] != "REMOTE"} {
		err_bind "Details are not editable for this sub pay method"
		go_pay_mthd_auth
		return
	}

	set validation [payment_ENVO::get_envo_ewallet_detail $sub_type validation]
	set additional_info [ob_chk::get_arg envoy_additional_info -on_err "" $validation]

	if {$additional_info == ""} {
		err_bind "Invalid eWallet ID."
		go_pay_mthd_auth
		return
	}

	set cpm_id          [ob_chk::get_arg cpm_id -on_err "" UINT]
	set remote_ccy      [ob_chk::get_arg envoy_remote_ccy -on_err "" {AZ -min_str 3 -max_str 3}]

	if {$remote_ccy == ""} {
		err_bind "Invalid currency."
		go_pay_mthd_auth
		return
	}

	# leaving wtd status/auth, dep status/auth as they are
	payment_ENVO::update_cpm $cpm_id "" "" $additional_info $remote_ccy $USERID Y

	go_pay_mthd_auth
}


# Update the PMB expiry date for a customer's CPM.
proc do_upd_pmb_expiry {} {

	global DB

	ob::log::write INFO {do_upd_pmb_expiry}

	set cpm_id  [reqGetArg cpm_id]
	set pmb_exp [reqGetArg pmb_exp]

	set sql [subst {
		update tCustPayMthd set
			pmb_period = ?
		where
			cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt $pmb_exp $cpm_id} msg]} {
		ob::log::write ERROR {Failed to update payment method: $msg}
		err_bind "Failed to update payment method: $msg"
	}

	inf_close_stmt $stmt

	go_pay_mthd_auth
}



proc zero_cpm_fails {} {

	global DB

	OT_LogWrite 1 "zero_cpm_fails cpm_id = [reqGetArg cpm_id]"

	if  {![op_allowed ZeroCPMFails]} {
		err_bind "You do not have permission"
		go_pay_mthd_auth
		return
	}

	set cpm_id [reqGetArg cpm_id]

	set stmt {
		update tCustPayMthd
		set num_fails = 0
		where cpm_id = ?
	}

	set stmt [inf_prep_sql $DB $stmt]
	inf_exec_stmt $stmt $cpm_id
	inf_close_stmt $stmt

	msg_bind "Fail counter zeroed."

	go_pay_mthd_auth
}

}
