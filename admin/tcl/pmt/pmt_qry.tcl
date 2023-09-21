# ==============================================================
# $Id: pmt_qry.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::GoPmtAuthQry     [namespace code go_auth_qry]
asSetAct ADMIN::PMT::do_auth_qry      [namespace code do_auth_qry]

asSetAct ADMIN::PMT::go_pay_mthd_add  [namespace code go_pay_mthd_add]
asSetAct ADMIN::PMT::do_pay_mthd_add  [namespace code do_pay_mthd_add]

asSetAct ADMIN::PMT::do_card_qry      [namespace code do_card_qry]
asSetAct ADMIN::PMT::do_phone_qry     [namespace code do_phone_qry]
asSetAct ADMIN::PMT::do_earthport_qry [namespace code do_earthport_qry]
asSetAct ADMIN::PMT::do_neteller_qry  [namespace code do_neteller_qry]
asSetAct ADMIN::PMT::do_c2p_qry       [namespace code do_c2p_qry]
asSetAct ADMIN::PMT::do_paypal_qry    [namespace code do_paypal_qry]
asSetAct ADMIN::PMT::do_clickandbuy_qry    [namespace code do_clickandbuy_qry]
asSetAct ADMIN::PMT::do_moneybookers_qry   [namespace code do_moneybookers_qry]
asSetAct ADMIN::PMT::do_paysafecard_qry    [namespace code do_paysafecard_qry]
asSetAct ADMIN::PMT::do_envoy_pmt_mthd_qry [namespace code do_envoy_pmt_mthd_qry]


#
# ----------------------------------------------------------------------
# Produce payment method authorisations query screen
# ----------------------------------------------------------------------
#
proc go_auth_qry args {

    global PAYMTHD

    bind_mthds

    asPlayFile -nocache pmt/pmt_qry.html

    unset PAYMTHD
}


#
# ----------------------------------------------------------------------
# Get list of matching payment authorisations
# ----------------------------------------------------------------------
#
proc do_auth_qry args {

    global DB CPM

	# Get all the request arguments
	foreach {a b} {
		username      Username
		ignore_case   ignorecase
		acct_no       AcctNo
		dep           DepAuthStatus
		wtd           WtdAuthStatus
		pay_mthd      pay_mthd
		cvv2_resp     cvv2_resp
		pmt_date_1    PmtDate1
		pmt_date_2    PmtDate2
		date_range    DateRange
	} {
		set $a [reqGetArg $b]
	}

	if {[OT_CfgGet VALIDATE_PMT_METHOD_SEARCHES 0]} {
		# Check for the presence of compulsory fields, so that we
		# don't attempt a nasty query.
		set compulsory_fields ""

		foreach f {
			username
			acct_no
			pmt_date_1
			pmt_date_2
			date_range
		} {
			append compulsory_fields [subst "$$f"]
		}

		if {$compulsory_fields == ""} {
			# Rebind request args
			for {set n 0} {$n < [reqGetNumVals]} {incr n} {
				tpBindString [reqGetNthName $n] [reqGetNthVal $n]
			}

			err_bind "There aren't sufficient filters on the payment methods
				query.  Please enter a new search."
			ADMIN::PMT::go_auth_qry
			return
		}
	}

    #
    # Query parameters
    #
    set where [list]
	set from  [list]

    if {$username != ""} {
	    if {$ignore_case == "Y"} {
			lappend where "c.username_uc = '[string toupper $username]'"
		} else {
			lappend where "c.username = '$username'"
		}
    }
    if {$acct_no != ""} {
        lappend where "c.acct_no = '$acct_no'"
    }
    if {$dep != ""} {
        lappend where "m.auth_dep = '$dep'"
    }
    if {$wtd != ""} {
        lappend where "m.auth_wtd = '$wtd'"
    }
    if {$pay_mthd != ""} {
        lappend where "m.pay_mthd = '$pay_mthd'"
    }

	if {$cvv2_resp != ""} {
		lappend where "cpmcc.cpm_id = m.cpm_id"
        lappend where "cpmcc.cvv2_resp = '$cvv2_resp'"
		lappend from  "tCPMCC cpmcc"
    }

    set date_lo $pmt_date_1
    set date_hi $pmt_date_2

    if {$date_range != ""} {
        set now_dt [clock format [clock seconds] -format %Y-%m-%d]
        foreach {Y M D} [split $now_dt -] { break }
        set date_hi "$Y-$M-$D"
        if {$date_range == "TD"} {
            set date_lo "$Y-$M-$D"
        } elseif {$date_range == "CM"} {
            set date_lo "$Y-$M-01"
        } elseif {$date_range == "YD"} {
            set date_lo [date_days_ago $Y $M $D 1]
            set date_hi "$date_lo"
        } elseif {$date_range == "L3"} {
            set date_lo [date_days_ago $Y $M $D 3]
        } elseif {$date_range == "L7"} {
            set date_lo [date_days_ago $Y $M $D 7]
        }
    }

	if {$date_lo != "" && $date_hi != ""} {
		lappend where "m.cr_date >= '$date_lo 00:00:00'"
		lappend where "m.cr_date <= '$date_hi 23:59:59'"
	}

    if {[llength $where]} {
        set where " and [join $where { and }]"
    }

	if {[llength $from]} {
		set from ", [join $from { , }]"
	}

	# Only return the first n items from this search.
	set first_n ""
	if {[set n [OT_CfgGet SELECT_FIRST_N 0]]} {
		set first_n " first $n "
	}

	set sql [subst {
		select $first_n
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			c.elite,
			r.lname,
			a.ccy_code,
			p.desc,
			spm.desc as sub_mthd_desc
		from
			tCustPayMthd m,
			tPayMthd p,
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			outer (
				tExtSubCPMLink scl,
				tExtSubPayMthd spm
			)
			$from
		where
			m.cust_id         = c.cust_id and
			c.cust_id         = r.cust_id and
			c.cust_id         = a.cust_id and
			m.pay_mthd        = p.pay_mthd and
			a.owner          <> 'D' and
			m.cpm_id          = scl.cpm_id and
			scl.sub_type_code = spm.sub_type_code
			$where
		order by
			cpm_id asc
	}]

	ob_log::write INFO $sql

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $dep $wtd]
    inf_close_stmt $stmt

    tpSetVar NumCPM [set nrows [db_get_nrows $res]]

    set elite 0

    if {$nrows > 0} {
	for {set r 0} {$r < $nrows} {incr r} {
		foreach col [db_get_colnames $res] {
			set CPM($r,$col) [db_get_col $res $r $col]
			if {$col == "elite" && [db_get_col $res $r $col] == "Y"} {
				incr elite
			}
		}
	}
    }

    tpSetVar IS_ELITE $elite

    foreach f [db_get_colnames $res] {
		tpBindVar CPM_${f} CPM $f cpm_idx
    }

	if {$nrows > 0} {
		set csh_count 0
		for {set r 0} {$r < $nrows} {incr r} {
			# Set Method to be "Method(agent)" if it is BASC
			if {[db_get_col $res $r pay_mthd] == "BASC"} {
				set cpm_id [db_get_col $res $r cpm_id]
				if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
					set desc "MCA"
				} else {
					set desc [db_get_col $res $r desc]
				}
				tpSetVar CPM_Desc_$r "$desc ([ADMIN::PMT::bind_detail_BASC $cpm_id 1])"
			} elseif {[db_get_col $res $r pay_mthd] == "ENVO"} {
				tpSetVar CPM_Desc_$r "[db_get_col $res $r desc] [db_get_col $res $r sub_mthd_desc]"
			} else {
				tpSetVar CPM_Desc_$r [db_get_col $res $r desc]
			}

			if {[db_get_col $res $r pay_mthd] == "CSH"} {
				incr csh_count
			}
		}

		tpSetVar CshCPM $csh_count

		if {$csh_count == 0} {
			tpBindString CustId  [db_get_col $res 0 cust_id]
			tpBindString username [reqGetArg Username]
			tpBindString acct_no  [reqGetArg AcctNo]
		}
	}

	show_auth_list

    db_close $res

    catch {unset CPM}
}

proc do_pay_mthd_add args {

	set action [reqGetArg SubmitName]

	if {$action == "Back"} {
		if {[reqGetArg backAction] == "PMT"} {
			go_auth_qry
		} else {
			ADMIN::CUST::go_cust
		}
		return
	}

	tpBindString Username   [reqGetArg Username]
	tpBindString AcctNo     [reqGetArg AcctNo]
	tpBindString backAction [reqGetArg backAction]


	#
	# Add this payment method
	#
	set pay_mthd [reqGetArg pay_mthd]

	if {$pay_mthd != "CC" && [OT_CfgGet ENABLE_MULTIPLE_CPMS 0]} {
		# In case people play with the back button recheck the method can be
		# added - not done for credit cards as we check again for the scheme
		# for them
		set cust_id [reqGetArg CustId]

		if {[CPMRules::check_cust_needs_wtd_mthd $cust_id] && \
				($pay_mthd == "CHQ" || $pay_mthd == "BANK")} {
			OT_LogWrite 5 "Linked Method okay to add for $cust_id"
		} else {
			set can_reg [payment_multi::get_mthd_can_register \
			               $cust_id $pay_mthd]

			set can_reg_mthd 0
			if {[lindex $can_reg 0]} {
				if {[lindex $can_reg 1]} {
					set can_reg_mthd 1
				}
			}

			if {!$can_reg_mthd} {
				err_bind "Cannot add method $pay_mthd for this customer"
				rebind_request_data
				go_pay_mthd_add
				return
			}
		}
	}

	switch -- $pay_mthd {
		"CC" {
			do_add_CC
			#srobins - reset srp lev to 1 on new card
			if {[OT_CfgGet FUNC_MCS_POKER 0]} {
				ADMIN::MCS_CUST::reset_poker_srp [reqGetArg CustId]
			}
		}
		"CHQ" {
			do_add_CHQ
		}
		"BANK" {
			do_add_BANK
		}
		"GDEP" {
			do_add_GDEP
		}
		"GWTD" {
			do_add_GWTD
		}
		"CSH" {
			do_add_CSH
		}
		"PB" {
			do_add_PB
		}
		"EP" {
			do_add_EP
		}
		"BC" {
			do_add_BC
		}
		"NTLR" {
			do_add_NTLR
		}
		"CB" {
			do_add_CB
		}
		"BASC" {
			do_add_BASC
		}
		"WU" {
			do_add_WU
		}
		"ENET" {
			do_add_ENET
		}
		"MB" {
			do_add_MB
		}
		"C2P" {
			do_add_C2P
		}
		"SHOP" {
			do_add_SHOP
		}
		"UKSH" {
			do_add_UKSH
		}
		"IKSH" {
			do_add_IKSH
		}
		"BARC" {
			do_add_BARC
		}
		default {
			err_bind "Unknown payment method"
			go_pay_mthd_add
		}
	}
}


#
# flag the customer as one pay.
#
proc set_cpm_type {cpm_id cust_id} {
	if {[OT_CfgGetTrue ENTROPAY] && [entropay::is_entropay_cpm $cpm_id]} {
		entropay::upd_entropay_cpm $cpm_id
	} elseif {[OT_CfgGet FUNC_ONEPAY 0]} {
		OT_LogWrite 6 "One Pay is active"
		if {[ventmear::is_1pay_cust $cust_id]} {
			OT_LogWrite 6 "Registering $cust_id as 1 pay customer"
			ventmear::set_1pay_cpmtype $cpm_id
		}
	}
}

proc do_add_CC {} {

    OT_LogWrite 5 "==> do_add_CC"

    global USERID

    set card_no     [reqGetArg CardNumber]
    set start_date  [reqGetArg StartDate]
    set exp_date    [reqGetArg ExpiryDate]
    set issue_no    [reqGetArg IssueNumber]
    set cust_id     [reqGetArg CustId]
    set settle_type [reqGetArg SettleType]
    set acct_type   [reqGetArg AcctType]
    set hldr_name   [reqGetArg CardHolderName]
    set verify_card 1

	# check to see if the card is an encrypted entropay card
	set entropay_card 0
	if {[OT_CfgGetTrue ENTROPAY]} {
		foreach {entropay_card card_no} [entropay::identify $card_no] {break}
	}

    #
    # customer specific card verification
    #
    reqSetArg card_no   $card_no
    reqSetArg issue_no  $issue_no
    reqSetArg oper_id   $USERID
    reqSetArg start     $start_date
    reqSetArg expiry    $exp_date
    reqSetArg hldr_name $hldr_name

    OT_LogWrite 5 "settle_type: $settle_type"

    if {$acct_type == "DBT" && $settle_type != "N"} {
        #
        # Only allow registration of credit cards on debit accounts
        # if cleardown (tAcct.settle_type) is 'N'
        #
        card_util::cd_get_req_fields [string range $card_no 0 5] CARD_DATA

        if {$CARD_DATA(type) == "CDT"} {
            err_bind "Cannot register a Credit Card unless Settle Type is set to 'Never' for this customer"
            rebind_request_data
            go_pay_mthd_add
            return
        }
    }

	if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0]} {
		set card_scheme [card_util::get_card_scheme $card_no]
		set can_reg [payment_multi::get_mthd_can_register $cust_id CC \
			[lindex $card_scheme 0]]

		set can_reg_card 0
		if {[lindex $can_reg 0]} {
			if {[lindex $can_reg 1]} {
				set can_reg_card 1
			}
		}

		if {!$can_reg_card} {
			err_bind "Cannot add card type $card_scheme for this customer"
			rebind_request_data
			go_pay_mthd_add
			return
		}
	}

	# Check if fraud screen functionality is required
	if {[OT_CfgGet FUNC_FRAUD_SCREEN 0] != 0} {

		tb_db::tb_begin_tran

		# Fraud check:
		# - store card registration attempt in tcardreg
		# - check for tumbling and swapping (10 channels)
		# - IP address monitoring (internet only)
		# - compare address country, currency country
		# 	and ip country with card country (internet only)
		OT_LogWrite 10 "fraud check"
		set channel "P"
		if {[catch {set fraud_monitor_details [fraud_check::screen_customer $cust_id $channel "" 0 "Y"]} msg]} {
			tb_db::tb_rollback_tran
			err_bind "Cannot complete fraud check: $msg"
			rebind_request_data
			go_pay_mthd_add
			return
		} else {
			tb_db::tb_commit_tran

			# Can send fraud ticker now, since we're not in a transaction
			# and therefore can't get into the situation where we rollback
			# but still send the ticker msg
			if {[llength $fraud_monitor_details] > 1} {
				eval [concat fraud_check::send_ticker $fraud_monitor_details]
			}
		}
	}

	#
	# Now make the duplicate card check
	#
	set reg_duplicate_card "N"

	if {[reqGetArg DuplicateOverride] == "Y"} {

		if {[op_allowed OverrideDuplicateCPM]} {

			OT_LogWrite 5 "***Warning duplicate card: Override Allowed"
			msg_bind "Warning duplicate card: Override Allowed"
			set reg_duplicate_card "Y"

		} else {

			OT_LogWrite 5 "***Warning duplicate card: Override Allowed but card will be suspended"
			msg_bind "Warning duplicate card: Card has been suspended and deposits and withdrawals have been blocked on this account"

		}

	} else {

		# check for duplicate card
		if {[card_util::verify_card_not_used $card_no $cust_id] == 0} {

			#check permissions
			if {[op_allowed OverrideDuplicateCPM]} {

				tpSetVar ShowOverrideOption 1
				rebind_request_data
				go_pay_mthd_add
				return

			} else {

				if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {

					tpSetVar ShowOverrideOption 1
					rebind_request_data
					go_pay_mthd_add
					return

				} else {

					err_bind "card already active on another account"
					rebind_request_data
					go_pay_mthd_add
					return

				}
			}
		}
	}


	#
	# Use a dummy scheme for registration or not ?
	#

	if {!$entropay_card && [OT_CfgGet FUNC_ONEPAY 0]} {
		# get the customer's currency
		set cust_ccy [ventmear::get_cust_ccy $cust_id]

		if {[ventmear::is_1pay_ccy $cust_ccy]} {
			set verify_card 0
		}

		# Doing a 1-pay registration - then manually set the
		# card type to debit or credit depending on currency - horrible!
		reqSetArg card_type [expr {$cust_ccy == "RMB"?"DBT":"CDT"}]
	}

	#
	# If verify_card is 1, then we use a dummy scheme
	# and don't verify the card length.
	# This is for 1pay cards.
	#
	set use_dummy_scheme [expr {$verify_card? 0 : 1}]
	set verify_card_length [expr {$verify_card? {Y} : {N}}]

	# We don't need to check for a duplicate card as we can't get to this point with a
	# duplicated card unless we are allowed to override the duplicate check
	set ignore_duplicate_check 1
	set result [card_util::verify_cust_card_all $verify_card_length "N" $cust_id $ignore_duplicate_check $use_dummy_scheme]
	if {$result != 1} {
		err_bind $result
		rebind_request_data
		go_pay_mthd_add
		return
	}


    #
    # register the card
    #
    set result [card_util::cd_reg_card $cust_id "Y" $reg_duplicate_card $use_dummy_scheme]
    if {[lindex $result 0] != 1} {
        err_bind [lindex $result 1]
        rebind_request_data
        go_pay_mthd_add
        return
    }

    #
    # goto the authorize page
    #
    reqSetArg cpm_id [lindex $result 1]
	reqSetArg mthd   "CC"

	set_cpm_type [lindex $result 1] $cust_id
    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_CC"
}

proc do_add_CSH {} {

    OT_LogWrite 5 "==> do_add_CSH"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsCsh (
            p_cust_id = ?,
            p_oper_id = ?
        )
    }]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt [reqGetArg CustId] $USERID]
        inf_close_stmt $stmt

    } msg]

    if {$c} {

        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }

    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "CSH"

	### Send message to Monitor ###

	set sql {
		select
			csh_outlet_id,
			id_type
		from
			tCPMCSH
		where
			cust_id = ? and
			cpm_id = ?
	}

	set cust_id [reqGetArg CustId]
	set cpm_id [db_get_coln $rs 0]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt $stmt $cust_id $cpm_id]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		ob::log::write ERROR {failed to get payment method information: $msg}
	} else {
		set amount "N/A"
		set generic_pmt_mthd_id [db_get_col $rs csh_outlet_id]
		set id_type             [db_get_col $rs id_type]
		set channel "Admin"

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			[reqGetArg mthd] \
			$cpm_id \
			$generic_pmt_mthd_id \
			$id_type
	}

	### End of Monitor code ###

    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_CSH"
}

proc do_add_BC {} {

    OT_LogWrite 5 "==> do_add_BC"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsBetcard (
            p_cust_id = ?,
            p_oper_id = ?
        )
    }]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt [reqGetArg CustId] $USERID]
        inf_close_stmt $stmt

    } msg]

    if {$c} {

        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }

    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "BC"


	### Send message to Monitor ###

	set cust_id [reqGetArg CustId]
	set cpm_id [db_get_coln $rs 0]

	set amount "N/A"
	set other  ""
	set generic_pmt_mthd_id ""

	set channel "Admin"

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		[reqGetArg mthd] \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other

	### End of Monitor code ###

    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_BC"

}

proc do_add_CHQ {} {

    OT_LogWrite 5 "==> do_add_CHQ"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsChq (
            p_cust_id = ?,
            p_oper_id = ?,
            p_payee = ?,
            p_addr_street_1 = ?,
            p_addr_street_2 = ?,
            p_addr_street_3 = ?,
            p_addr_street_4 = ?,
            p_addr_city = ?,
            p_addr_postcode = ?,
            p_country_code = ?
        )
    }]


    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID \
                            [reqGetArg payee] \
                            [reqGetArg addr_street_1] \
                            [reqGetArg addr_street_2] \
                            [reqGetArg addr_street_3] \
                            [reqGetArg addr_street_4] \
                            [reqGetArg addr_city] \
                            [reqGetArg addr_postcode] \
                            [reqGetArg country_code]]

        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }


    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "CHQ"


	### Send message to Monitor ###

	set sql {
		select
			payee,
			addr_city
		from
			tCPMCHQ
		where
			cust_id = ? and
			cpm_id = ?
	}

	set cust_id [reqGetArg CustId]
	set cpm_id [db_get_coln $rs 0]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt $stmt $cust_id $cpm_id]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		ob::log::write ERROR {failed to get payment method information: $msg}
	} else {
		set amount "N/A"
		set generic_pmt_mthd_id [db_get_col $rs payee]
		set other               [db_get_col $rs addr_city]
		set channel "Admin"

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			[reqGetArg mthd] \
			$cpm_id \
			$generic_pmt_mthd_id \
			$other
	}

	### End of Monitor code ###


    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_CHQ"
}


proc do_add_BANK {} {

	OT_LogWrite 5 "==> do_add_BANK"

	global DB USERID

	set sql [subst {
		execute procedure pCPMInsBank (
			p_cust_id = ?,
			p_oper_id = ?,
			p_bank_name = ?,
			p_bank_addr_1 = ?,
			p_bank_addr_2 = ?,
			p_bank_addr_3 = ?,
			p_bank_addr_4 = ?,
			p_bank_addr_city = ?,
			p_bank_addr_pc = ?,
			p_country_code = ?,
			p_bank_acct_no = ?,
			p_bank_sort_code = ?,
			p_bank_acct_name = ?,
			p_bank_branch = ?,
			p_iban_code = ?,
			p_swift_code = ?
        )
    }]

	# Get form data for validation.
	regsub -all {[ \r\t\n]+} [reqGetArg iban_code]  "" iban
	regsub -all {[ \r\t\n]+} [reqGetArg swift_code] "" swift

	# Do validation.
	set errors [list]
	if {$iban != "" && [ob_chk::iban $iban] != "OB_OK"} {
		lappend errors "IBAN is in the incorrect format."
	}

	if {$swift != "" && [ob_chk::swift $swift] != "OB_OK"} {
		lappend errors "Swift is in the incorrect format."
	}

	# Show validation errors.
	if {[llength $errors] > 0} {
		set err_str ""
		foreach err $errors {
			set err_str "${err_str}<br>${err}"
		}
		err_bind $err_str
		rebind_request_data
		go_pay_mthd_add
		return
	}

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID \
                            [reqGetArg bank_name] \
                            [reqGetArg bank_addr_1] \
                            [reqGetArg bank_addr_2] \
                            [reqGetArg bank_addr_3] \
                            [reqGetArg bank_addr_4] \
                            [reqGetArg bank_addr_city] \
                            [reqGetArg bank_addr_postcode] \
                            [reqGetArg bank_country_code] \
                            [reqGetArg bank_acct_no] \
                [reqGetArg bank_sort_code] \
                            [reqGetArg bank_acct_name] \
		            [reqGetArg bank_branch] \
		            $iban \
		            $swift]

        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }


    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "BANK"

	### Send message to Monitor ###

	set sql {
		select
			bank_name,
			bank_acct_name
		from
			tCPMBank
		where
			cust_id = ? and
			cpm_id = ?
	}

	set cust_id [reqGetArg CustId]
	set cpm_id [db_get_coln $rs 0]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt $stmt $cust_id $cpm_id]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		ob::log::write ERROR {failed to get payment method information: $msg}
	} else {
		set amount "N/A"
		set generic_pmt_mthd_id [db_get_col $rs bank_name]
		set other               [db_get_col $rs bank_acct_name]
		set channel "Admin"

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			[reqGetArg mthd] \
			$cpm_id \
			$generic_pmt_mthd_id \
			$other
	}

	### End of Monitor code ###


	set_cpm_type [reqGetArg cpm_id] [reqGetArg CustId]
    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_BANK"
}


proc do_add_GDEP {} {

    OT_LogWrite 5 "==> do_add_GDEP"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsGdep (
            p_cust_id = ?,
            p_oper_id = ?
        )
    }]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID]
        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }


    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "GDEP"


	### Send message to Monitor ###

	set cust_id [reqGetArg CustId]
	set cpm_id [db_get_coln $rs 0]

	set amount "N/A"
	set generic_pmt_mthd_id ""
	set other               ""
	set channel "Admin"

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		[reqGetArg mthd] \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other


	### End of Monitor code ###


    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_GDEP"
}

proc do_add_GWTD {} {

    OT_LogWrite 5 "==> do_add_GWTD"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsGwtd (
            p_cust_id = ?,
            p_oper_id = ?
        )
    }]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {

        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID]
        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }


    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "GWTD"


        ### Send message to Monitor ###

        set cust_id [reqGetArg CustId]
        set cpm_id [db_get_coln $rs 0]

        set amount "N/A"
        set generic_pmt_mthd_id ""
        set other               ""
        set channel "Admin"

        OB_gen_payment::send_pmt_method_registered \
                $cust_id \
                $channel \
                $amount \
                [reqGetArg mthd] \
                $cpm_id \
                $generic_pmt_mthd_id \
                $other


        ### End of Monitor code ###


    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_GWTD"
}

proc do_add_EP {} {
    global DB USERID EARTHPORT

	catch {unset EARTHPORT}

    for {set n 0} {$n < [reqGetNumVals]} {incr n} {
        OT_LogWrite 5 "param: [reqGetNthName $n]\t=\t[reqGetNthVal $n]"
    }

    OT_LogWrite 5 "==> do_add_EP"

	set EARTHPORT(OPER_ID)      $USERID
    set EARTHPORT(CUST_ID)      [reqGetArg CustId]
    set EARTHPORT(USERNAME)     [reqGetArg Username]

    set EARTHPORT(COUNTRY)      [reqGetArg Country]
    set EARTHPORT(BANKCCY)      [reqGetArg epCcy]
    set EARTHPORT(ACCCY)        [reqGetArg epCcy]
    set EARTHPORT(BANKNAME)     [reqGetArg -unsafe BankName]
    set EARTHPORT(HOLDING)      [reqGetArg -unsafe BranchName]
    set EARTHPORT(ACNAME)       [reqGetArg -unsafe AccName]
    set EARTHPORT(DESCRIPTION)  [reqGetArg -unsafe AccountDesc]
    set EARTHPORT(ACNUM)        [reqGetArg -unsafe AccNumber]
    if {[reqGetArg BranchSort] != ""} {set EARTHPORT(BANKSORT)  [reqGetArg -unsafe BranchSort]}
    if {[reqGetArg BranchCode] != ""} {set EARTHPORT(BRANCHCODE)  [reqGetArg -unsafe BranchCode]}
    if {[reqGetArg BankCode] != ""} {set EARTHPORT(BANK_CODE)  [reqGetArg -unsafe BankCode]}

	# Before attempting to contact earthport, check if the user
	# has an active earthport payment method
	set sql [subst {
				select ep.cpm_id
				from tcpmep ep, tcustpaymthd pm
				where ep.cpm_id = pm.cpm_id
				and status = 'A'
				and ep.cust_id = ?}]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt [reqGetArg CustId]]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] > 0} {
		db_close $rs
		err_bind "Customer already has active Earthport pay method"
		rebind_request_data
		go_pay_mthd_add
		return
	}
	db_close $rs

    #
    # Get Card Details
    #
    array set CARD ""
    card_util::cd_get_active [reqGetArg CustId] CARD
   if {$CARD(card_available) == "Y" || [lindex [enets::get_cpm [reqGetArg CustId]] 0]} {
		set EARTHPORT(ALLOW_WTD) "P"
		set EARTHPORT(MULT_CPM)	 "Y"
	} else {
		set EARTHPORT(ALLOW_WTD) "Y"
		set EARTHPORT(MULT_CPM)	 "N"
	}

	set EARTHPORT(CHANNEL)      "Admin"

    set list [earthport::registerEarthportAcc]

    if {[lindex $list 0] == 0} {
        global LANG
        set LANG en
        err_bind "Could not add payment method: [lindex $list 1]"
        tpSetVar Country [reqGetArg Country]
        rebind_request_data
        go_pay_mthd_add
        return
    }

    reqSetArg mthd   "EP"
    reqSetArg cpm_id [lindex $list 2]
    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_EP"
}

proc do_add_WU {} {
	global DB USERID

	OT_LogWrite 5 "==> do_add_WU"

	set sql [subst {
		execute procedure pCPMInsWU (
			p_cust_id = ?,
			p_oper_id = ?,
			p_auth_dep = 'Y',
			p_auth_wtd = 'Y',
			p_payee = ?,
			p_country_code = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set rs [inf_exec_stmt $stmt \
		        [reqGetArg CustId] \
		        $USERID \
		        [reqGetArg CustName] \
		        [reqGetArg CustCountryCode]]

		inf_close_stmt $stmt
	} msg]

	if {$c} {
		#
		# failed to add payment method
		#
		err_bind "Could not add payment method: $msg"
		rebind_request_data
		go_pay_mthd_add
		return
	}


	#
	# Succeeded in adding payment method
	#
	reqSetArg cpm_id [db_get_coln $rs 0]
	reqSetArg mthd   "WU"


	### Send message to Monitor ###

	set sql {
		select
			payee
		from
			tCPMWU
		where
			cust_id = ? and
			cpm_id = ?
	}

	set cust_id [reqGetArg CustId]
	set cpm_id  [db_get_coln $rs 0]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt $stmt $cust_id $cpm_id]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		ob::log::write ERROR {failed to get payment method information: $msg}
	} else {
		set amount "N/A"
		set generic_pmt_mthd_id [db_get_col $rs payee]
		set other               "N/A"
		set channel "Admin"

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			[reqGetArg mthd] \
			$cpm_id \
			$generic_pmt_mthd_id \
			$other
	}

	### End of Monitor code ###


	set_cpm_type [reqGetArg cpm_id] [reqGetArg CustId]
	pmt_qry_back [reqGetArg backAction]

	OT_LogWrite 5 "<== do_add_WU"
}

proc do_add_BASC {} {
    global DB USERID

    for {set n 0} {$n < [reqGetNumVals]} {incr n} {
        OT_LogWrite 5 "param: [reqGetNthName $n]\t=\t[reqGetNthVal $n]"
    }

    OT_LogWrite 5 "==> do_add_BASC"

    set sql [subst {
        execute procedure pCPMInsBasic (
            p_cust_id = ?,
            p_oper_id = ?,
            p_basic_info_id = ?
        )
    }]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {
        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID \
                            [reqGetArg agent]]
        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }

    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "BASC"


	### Send message to Monitor ###

	set sql {
		select
			basic_info_id
		from
			tCPMBasic
		where
			cust_id = ? and
			cpm_id = ?
	}

	set cust_id [reqGetArg CustId]
	set cpm_id  [db_get_coln $rs 0]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set rs [inf_exec_stmt $stmt $cust_id $cpm_id]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		ob::log::write ERROR {failed to get payment method information: $msg}
	} else {
		set amount "N/A"
		set generic_pmt_mthd_id [db_get_col $rs basic_info_id]
		set other ""
		set channel "Admin"

		if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
			set mthd "MCA"
		} else {
			set mthd "BASC"
		}

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			$mthd \
			$cpm_id \
			$generic_pmt_mthd_id \
			$other
	}

	### End of Monitor code ###


    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_BASC"
}

proc do_add_PB {} {

    OT_LogWrite 5 "==> do_add_PB"

    global DB USERID

    set sql [subst {
        execute procedure pCPMInsPB (
            p_cust_id = ?,
            p_oper_id = ?,
            p_pb_bin = ?,
            p_pb_number = ?
        )
    }]

    regsub -all {[ ]} [reqGetArg MobileNumber] "" pb_number
    set pb_number "+$pb_number"

    if {![regexp {^\+[0-9][0-9][1-9][0-9]+$} $pb_number]} {
        err_bind "Mobile number must contain digits only and not include the zero following the country code"
        rebind_request_data
        go_pay_mthd_add
        return
    }

    # set last 6 digits as pb_bin
    set pb_bin [string range $pb_number [expr {[string length $pb_number] - 6}] end]

    set stmt [inf_prep_sql $DB $sql]
    set c [catch {
        set rs [inf_exec_stmt $stmt \
                            [reqGetArg CustId] \
                            $USERID \
                            $pb_bin \
                            $pb_number]
        inf_close_stmt $stmt
    } msg]

    if {$c} {
        #
        # failed to add payment method
        #
        err_bind "Could not add payment method: $msg"
        rebind_request_data
        go_pay_mthd_add
        return
    }


    #
    # Succeeded in adding payment method
    #
    reqSetArg cpm_id [db_get_coln $rs 0]
    reqSetArg mthd   "PB"

    pmt_qry_back [reqGetArg backAction]

    OT_LogWrite 5 "<== do_add_PB"
}

proc do_add_NTLR {} {
	OT_LogWrite 5 "==> do_add_NTLR"

	global DB USERID

	set cust_id [reqGetArg CustId]

	if {[OB_neteller::get_neteller $cust_id]} {
		err_bind "Customer already has active Neteller payment method"
		rebind_request_data
		go_pay_mthd_add
		return
	}

	#
	# Now make the duplicate neteller id check
	#
	set allow_duplicate "N"
	set strict_check "Y"

	if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {

		if {[reqGetArg DuplicateOverride] == "Y"} {

			OT_LogWrite 5 "***Warning duplicate neteller id: Override Allowed but payment method will be suspended"
			msg_bind "Warning duplicate neteller id: Payment method has been suspended and deposits and withdrawals have been blocked on this account"
			set strict_check "N"

		} else {

			# check for duplicate neteller id
			if {[OB_neteller::verify_no_duplicate_id $cust_id [reqGetArg NetellerID]] == 0} {

				#check permissions
				if {[op_allowed OverrideDuplicateCPM]} {

					OT_LogWrite 5 "***Warning duplicate neteller id: Override Allowed"
					msg_bind "Warning duplicate neteller id: Override Allowed"
					set allow_duplicate "Y"
				} else {

					tpSetVar ShowOverrideOption 1
					rebind_request_data
					go_pay_mthd_add
					return

				}
			}
		}
	}

	set result [OB_neteller::reg $cust_id [reqGetArg NetellerID] $USERID $allow_duplicate $strict_check]

	if {[lindex $result 0] == 0} {
		err_bind "Could not add payment method [lindex $result 1]"
		rebind_request_data
		go_pay_mthd_add
		return
	}

	reqSetArg cpm_id [lindex $result 1]
	reqSetArg mthd   NTLR

	if {[lindex $result 0] == 1} {

		### Send message to Monitor ###
		# Can't put this in shared_tcl/neteller.tcl because the portal
		# registers the account and then tries to do the transfer.
		# If the transfer fails, the payment method is removed.
		# Don't want to send monitor message in that case

		set channel "Admin"
		set amount  "N/A"
		set mthd    "NTLR"
		set cpm_id  [reqGetArg cpm_id]
		set generic_pmt_mthd_id [reqGetArg NetellerID]
		set other   ""

		OB_gen_payment::send_pmt_method_registered \
			$cust_id \
			$channel \
			$amount \
			$mthd \
			$cpm_id \
			$generic_pmt_mthd_id \
			$other

		### End of Monitor code ###
	}

	pmt_qry_back [reqGetArg backAction]

	OT_LogWrite 5 "<== do_add_NTLR"
}

#
# Adds a Click and Buy payment method for a customer.
#
proc do_add_CB {} {

	set cust_id  [reqGetArg CustId]
	set cb_crn   [reqGetArg cb_crn]
    	set cb_email [reqGetArg Email]

	OT_LogWrite 5 "==> do_add_CB - cust_id=$cust_id"

	set auth_dep P
	set auth_wtd P

	set ret [ob_clickandbuy::insert_cpm $cust_id $cb_crn $auth_dep $auth_wtd $cb_email]

	if {[lindex $ret 0]} {
		set cpm_id [lindex $ret 1]
		OT_LogWrite 5 "do_add_CB - inserted Click and Buy pay method cpm_id=$cpm_id"
		msg_bind "Successfully inserted Click and Buy payment method (cpm_id=$cpm_id)"

	} else {
																	     set err [lindex $ret 1]
	        err_bind "Error inserting Click and Buy payment method - $err"
		rebind_request_data
		go_pay_mthd_add
        	return
	}

    	reqSetArg cpm_id [lindex $ret 1]
    	reqSetArg mthd   "CB"

	pmt_qry_back [reqGetArg backAction]

	OT_LogWrite 5 "==> do_add_CB"
}


proc do_add_ENET {} {
	OT_LogWrite 5 "==> do_add_ENET"

	global DB USERID

	set cust_id [reqGetArg CustId]

	foreach {ok xl msg} [enets::ins_cpm $cust_id "Admin" $USERID] {break}

	if {!$ok} {
		err_bind "Could not add payment method($xl): $msg"
		rebind_request_data
		go_pay_mthd_add
		return
	}

	foreach {ok xl msg} [enets::get_cpm $cust_id CPM] {break}

	if {!$ok} {
		err_bind "Could not get payment method($xl): $msg"
		rebind_request_data
		go_pay_mthd_add
		return
	}

	reqSetArg cpm_id $CPM(cpm_id)
	reqSetArg mthd   ENET

	pmt_qry_back [reqGetArg backAction]

	OT_LogWrite 5 "<== do_add_ENET"
}

proc do_add_MB {} {
	OT_LogWrite 5 "==> do_add_MB"

	global DB USERID

	set cust_id [reqGetArg CustId]
	set mb_email_addr [reqGetArg MBEmailAddr]

	set result [payment_MB::insert_cpm $cust_id\
						$mb_email_addr\
						P\
						P\
						Y\
						$USERID]

	if {![lindex $result 0]} {
		err_bind "Could not add payment method [lindex $result 1]"
		rebind_request_data
        	go_pay_mthd_add
        	return
	}

	### Send message to Monitor ###
	set channel "Admin"
	set amount  "N/A"
	set mthd    "MB"
	set generic_pmt_mthd_id $mb_email_addr
	set other   ""
	set cpm_id [lindex $result 1]

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		$mthd \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other
	### End of Monitor code ###

	reqSetArg cpm_id $cpm_id
	pmt_qry_back [reqGetArg backAction]

	OT_LogWrite 5 "<== do_add_MB"
}


proc do_add_C2P {} {

	ob::log::write DEBUG {do_add_C2P}

	global DB USERID

	set cust_id [reqGetArg CustId]

	if {[lindex [ob_click2pay::c2p_get_cpm_details $cust_id] 0]} {
		err_bind "Customer already has active Click2Pay payment method"
		rebind_request_data
		go_pay_mthd_add
		return
	}

	set result [ob_click2pay::do_registration $cust_id [reqGetArg c2pPAN] [reqGetArg c2pUsername] $USERID]

	if {![lindex $result 0]} {
		err_bind "Could not add payment method [lindex $result 1]"
		rebind_request_data
        go_pay_mthd_add
        return
	}

	set cpm_id [lindex $result 1]

	reqSetArg cpm_id $cpm_id
	reqSetArg mthd   C2P

	### Send message to Monitor ###
	# Can't put this in shared_tcl/click2pay.tcl because the portal
	# registers the account and then tries to do the transfer.
	# If the transfer fails, the payment method is removed.
	# Don't want to send monitor message in that case

	set channel "Admin"
	set amount  "N/A"
	set mthd    "C2P"
	set cpm_id  [reqGetArg cpm_id]
	set generic_pmt_mthd_id [reqGetArg c2pPAN]
	set other   ""

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		$mthd \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other

	### End of Monitor code ###

	pmt_qry_back [reqGetArg backAction]

}


proc do_add_SHOP {} {

	ob::log::write DEBUG {do_add_SHOP}

	global DB USERID

	set sql [subst {
		execute procedure pCPMInsShop (
			p_cust_id = ?,
			p_oper_id = ?,
			p_security_number = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set c [catch {
		set rs [inf_exec_stmt $stmt \
			[reqGetArg CustId] \
			$USERID \
			[reqGetArg SecurityNumber]]
		inf_close_stmt $stmt
	} msg]

	if {$c} {
		#
		# failed to add payment method
		#
		err_bind "Could not add payment method: $msg"
		rebind_request_data
		go_pay_mthd_add
		return
	}


	#
	# Succeeded in adding payment method
	#
	reqSetArg cpm_id [set cpm_id [db_get_coln $rs 0]]
	reqSetArg mthd   [set mthd "SHOP"]

	### Send message to Monitor ###

	set cust_id [reqGetArg CustId]

	set amount "N/A"
	set generic_pmt_mthd_id ""
	set other               ""
	set channel "Admin"

	OB_gen_payment::send_pmt_method_registered \
		$cust_id \
		$channel \
		$amount \
		$mthd \
		$cpm_id \
		$generic_pmt_mthd_id \
		$other


	### End of Monitor code ###

	pmt_qry_back [reqGetArg backAction]
}

# Wrapper function to add a Quickcash payment method for a customer
#
proc do_add_UKSH {} {
	_do_add_ukash "UKSH"
}

# Wrapper function to add a Ukash International payment method for a customer
#
proc do_add_IKSH {} {
	_do_add_ukash "IKSH"
}

# Helper function to insert Ukash payment method.
# UKSH/IKSH uses same DB tables
#
proc _do_add_ukash {pay_mthd} {

	set fn "_do_add_ukash ($pay_mthd)"

	set cust_id [reqGetArg CustId]

	OT_LogWrite 5 "==> $fn - cust_id=$cust_id"

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

	set auth_dep Y
	set auth_wtd N

	if {$pay_mthd == "UKSH"} {
		# Only Quickash supports withdrawals
		set auth_wtd "Y"
	}

	set ret [ob_ukash::insert_cpm $pay_mthd $cust_id $auth_dep $auth_wtd "Y"]

	if {[lindex $ret 0]} {
		set cpm_id [lindex $ret 1]
		OT_LogWrite 5 "$fn - inserted $cpm_desc pay method cpm_id=$cpm_id"

		msg_bind "Successfully inserted $cpm_desc payment method (cpm_id=$cpm_id)"

	} else {
		set err [lindex $ret 1]
		err_bind "Error inserting $cpm_desc payment method - $err"
	}

	OT_LogWrite 5 "<== $fn"

	reqSetArg CustId $cust_id
	ADMIN::CUST::go_cust
}

#
# Adds a Barclays BACS transfer method for a customer
#
proc do_add_BARC {} {

	global DB

	set cust_id [reqGetArg CustId]

	OT_LogWrite 5 "==> do_add_BARC - cust_id=$cust_id"

	# Initially we set the dep authorisation to Pending
	set auth_dep P

	set sql [subst {
		execute procedure pCPMIns (
			p_cust_id       = ?,
			p_auth_dep      = ?,
			p_auth_wtd      = 'N',
			p_status_wtd    = 'S',
			p_pay_mthd      = 'BARC'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		set rs [inf_exec_stmt $stmt $cust_id $auth_dep]
		inf_close_stmt $stmt
	} msg]} {
		#
		# Failed to add payment method
		#
		err_bind "Could not add payment method: $msg"
		rebind_request_data
		go_pay_mthd_add
		return
	} else {

		set cpm_id [db_get_coln $rs 0 0]
		OT_LogWrite 5 "do_add_BARC - inserted Barclay BACS Transfer\
			pay method cpm_id=$cpm_id"

		msg_bind "Successfully inserted Barclay BACS Transfer\
			 method (cpm_id=$cpm_id)"

	}

	go_pay_mthd_add
	OT_LogWrite 5 "==> do_add_BARC"

}

proc do_card_qry {} {

    OT_LogWrite 5 "==> do_card_qry"

    global DB CPM USERID

    set card_no  [reqGetArg card_no]
    set card_bin [reqGetArg card_bin]
	set status   [reqGetArg status]
    set where ""

    if {$card_no != ""} {
    	# We can no longer simply search on enc_card_no - instead we retrieve all of the
		# cpm_ids from tCPMCCHash for cards
		set hash_rs [card_util::get_cards_with_hash $card_no "Admin Card Query" "" $USERID]

		if {[lindex $hash_rs 0] == 0} {
			err_bind "Error occurred decrypting cpm_id"
			go_auth_qry
			return
		} else {
			set card_matches [lindex $hash_rs 1]
		}

		# card_matches now represents the full range of cpm_ids which match the card number
		# provided. If we have any, add these to the main query where clause
		if {[llength $card_matches] == 0} {
			tpSetVar NumCPM 0
			show_auth_list
			return
		} else {
			append where "and d.cpm_id in ([join $card_matches ,])"
		}
    }
    if {$card_bin != ""} {
		append where "and d.card_bin = $card_bin"
    }
	if {$status != ""} {
		append where "and m.status = '$status'"
	}

    set sql [subst {
        select
            m.cpm_id,
            m.cust_id,
            m.pay_mthd,
            m.cr_date,
            m.status,
            m.auth_dep,
            m.order_dep,
            m.auth_wtd,
            m.order_wtd,
            c.username,
            c.acct_no,
		    c.elite,
            r.lname,
            a.ccy_code,
            p.desc
        from
            tCustPayMthd m,
            tPayMthd p,
            tCustomer c,
            tCPMCC d,
            tAcct a,
            tCustomerReg r
        where
            m.cust_id = c.cust_id and
            c.cust_id = r.cust_id and
            c.cust_id = a.cust_id and
            m.pay_mthd = p.pay_mthd and
            d.cpm_id = m.cpm_id and
            a.owner   <> 'D'
            $where
        order by
            cpm_id asc
    }]


    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt]
    inf_close_stmt $stmt

    tpSetVar NumCPM [set nrows [db_get_nrows $res]]

    set elite 0

    if {$nrows > 0} {
	for {set r 0} {$r < $nrows} {incr r} {
		foreach col [db_get_colnames $res] {
			set CPM($r,$col) [db_get_col $res $r $col]
			if {$col == "elite" && [db_get_col $res $r $col] == "Y"} {
				incr elite
			}
		}
	}
    }

    tpSetVar IS_ELITE $elite

    foreach f [db_get_colnames $res] {
        tpBindVar CPM_${f} CPM $f cpm_idx
    }

	show_auth_list

    db_close $res

    catch {unset CPM}
}

proc do_phone_qry {} {

        OT_LogWrite 5 "==> do_phone_qry"

        global DB

        set phone_no [reqGetArg phone_no]
        set where ""

        # remove spaces
        regsub -all {[ ]} phone_no "" $phone_no

        # Add the preceeding + if its not there
        if {[string index $phone_no 0] != "+"} {
                set phone_no "+$phone_no"
        }

        set sql [subst {

                select
                        m.cpm_id,
                        m.cust_id,
                        m.pay_mthd,
                        m.cr_date,
                        m.status,
                        m.auth_dep,
                        m.order_dep,
                        m.auth_wtd,
                        m.order_wtd,
                        c.username,
                        c.acct_no,
				        r.lname,
				        a.ccy_code,
                        p.desc
                from
                        tCustPayMthd m,
                        tPayMthd p,
                        tCustomer c,
                        tCPMPB pb,
				        tAcct a,
				        tCustomerReg r

                where
                        m.cust_id = c.cust_id and
                        m.pay_mthd = p.pay_mthd and
                        pb.cpm_id = m.cpm_id and
				        c.cust_id = r.cust_id and
				        c.cust_id = a.cust_id and
                        pb.pb_number like '$phone_no%'
                order by
                        cpm_id asc
        }]

        set stmt [inf_prep_sql $DB $sql]
        set res  [inf_exec_stmt $stmt]
        inf_close_stmt $stmt

        tpSetVar NumCPM [set nrows [db_get_nrows $res]]

        foreach f [db_get_colnames $res] {
                tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
        }

		show_auth_list

        db_close $res
}

proc do_earthport_qry {} {
    OT_LogWrite 5 "==> do_earthport_qry"

    global DB

    set ep_van_no   	[reqGetArg ep_van_no]
    regsub -all {[ ]} ep_van_no "" $ep_van_no

    set ep_acc_no   	[reqGetArg ep_acc_no]
    set ep_bank_name	[reqGetArg ep_bank_name]

    set whereclause ""

    if {$ep_van_no != ""} {
    	set whereclause "$whereclause and ep.earthport_van = $ep_van_no"
    }

    if {$ep_acc_no != ""} {
    	set whereclause "$whereclause and ep.ac_num = '$ep_acc_no'"
    }

    if {$ep_bank_name != ""} {

    	if {[reqGetArg is_upper_name] == "Y"} {
		OT_LogWrite 1 "WHERE: $whereclause"
		set whereclause "$whereclause and upper(ep.bank_name) like upper('%$ep_bank_name%')"
	} else {
		set whereclause "$whereclause and ep.bank_name like '%$ep_bank_name%'"
	}

    }


    set sql [subst {
        select
                m.cpm_id,
                m.cust_id,
                m.pay_mthd,
                m.cr_date,
                m.status,
                m.auth_dep,
                m.order_dep,
                m.auth_wtd,
                m.order_wtd,
                c.username,
                c.acct_no,
		        r.lname,
                a.ccy_code,
                p.desc
        from
                tCustPayMthd m,
                tPayMthd p,
                tCustomer c,
                tCPMep ep,
                tAcct a,
                tCustomerReg r
        where
                m.cust_id = c.cust_id and
                m.pay_mthd = p.pay_mthd and
                ep.cpm_id = m.cpm_id  and
                a.cust_id = c.cust_id and
		        c.cust_id = r.cust_id
                $whereclause
        order by
                cpm_id asc
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt]
    inf_close_stmt $stmt

    tpSetVar NumCPM [set nrows [db_get_nrows $res]]

    foreach f [db_get_colnames $res] {
        tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
    }

	show_auth_list

    db_close $res
}

proc do_neteller_qry {} {
	OT_LogWrite 5 "==> do_neteller_qry"

	global DB

	set neteller_id [reqGetArg neteller_id]

	set neteller_id [string trim $neteller_id]

	if {[string length $neteller_id] == 0} {
		err_bind "You must enter a Neteller ID to search for"
		go_auth_qry
		return
	}

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc

		from
			tCustPayMthd m,
			tPayMthd p,
			tCustomer c,
			tCPMNeteller n,
			tAcct a,
			tCustomerReg r

		where
			n.neteller_id = $neteller_id and
			n.cpm_id = m.cpm_id and
			c.cust_id = m.cust_id and
			m.pay_mthd = p.pay_mthd and
			c.cust_id = r.cust_id and
			c.cust_id = a.cust_id and
			a.owner   <> 'D'

		order by
			cpm_id asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCPM [set nrows [db_get_nrows $res]]

	foreach f [db_get_colnames $res] {
		tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
	}

	show_auth_list

	db_close $res
}


#
#  Performs a Click2Pay Username search
#
proc do_c2p_qry {} {

	OT_LogWrite 5 "==> do_c2p_qry"

	global DB

	# Grab the form arguments
	set c2pUsername [string toupper [reqGetArg c2pUsername]]
	set c2pPAN      [reqGetArg c2pPAN]

	OT_LogWrite 10 "do_c2p_qry (c2pUsername=$c2pUsername, c2pPAN=$c2pPAN)"

	if {$c2pUsername == "" && $c2pPAN == ""} {
		OT_LogWrite 10 "do_c2p_qry: params are empty"
		err_bind "Please enter either an Email address or a PAN"
		ADMIN::PMT::go_auth_qry
		return
	}

	# build up the query
	set where {}

	if {$c2pUsername != {}} {
		append where [subst {and UPPER(c2p.username) = '${c2pUsername}'}]
	}

	if {$c2pPAN != {}} {
		set enc_pan [ob_click2pay::encrypt_decrypt_pan \
		            $c2pPAN "encrypt"]
		append where [subst {
			and c2p.enc_pan = '$enc_pan'
		}]
	}

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc

		from
			tCustPayMthd m,
			tPayMthd p,
			tCustomer c,
			tCPMC2P c2p,
			tAcct a,
			tCustomerReg r

		where
			c2p.cpm_id = m.cpm_id and
			c.cust_id = m.cust_id and
			m.pay_mthd = p.pay_mthd and
			c.cust_id = r.cust_id and
			c.cust_id = a.cust_id and
			a.owner   <> 'D'
			$where
		order by
			cpm_id asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCPM [set nrows [db_get_nrows $res]]

	foreach f [db_get_colnames $res] {
		tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
	}

	show_auth_list

	db_close $res
}



# Search for PayPal payment methodss
#
proc do_paypal_qry {} {

	global DB

	set payer_id [string trim [reqGetArg payer_id]]
	set email    [string toupper [string trim [reqGetArg email]]]

	OT_LogWrite 10 "do_paypal_qry (payer_id=$payer_id, email=$email)"

	if {$payer_id == "" && $email == ""} {
		OT_LogWrite 10 "do_paypal_qry: params are empty"
		err_bind "Please enter either a Payer Id or an Email address"
		ADMIN::PMT::go_auth_qry
		return
	}

	# build up the query
	set where {}

	if {$payer_id != {}} {
		append where [subst {
			and pp.payer_id = '$payer_id'
		}]
	}

	if {$email != {}} {
		append where [subst {and UPPER(pp.email) = '${email}'}]
	}

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc
		from
			tCustPayMthd m,
			tPayMthd     p,
			tCustomer    c,
			tCPMPayPal   pp,
			tAcct        a,
			tCustomerReg r
		where
			pp.cpm_id  = m.cpm_id
		and c.cust_id  = m.cust_id
		and m.pay_mthd = p.pay_mthd
		and c.cust_id  = r.cust_id
		and c.cust_id  = a.cust_id
		and a.owner    <> 'D'
		$where
		order by
			cpm_id asc
	}]

	OT_LogWrite 10 "do_paypal_qry: $sql"

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		OT_LogWrite 1 "do_paypal_qry: Error executing query - $msg"
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_auth_qry

	} else {

		tpSetVar NumCPM [set nrows [db_get_nrows $res]]

		OT_LogWrite 10 "do_paypal_qry: nrows = $nrows"

		foreach f [db_get_colnames $res] {
			tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
		}

		for {set i 0} {$i<$nrows} {incr i} {
			tpSetVar CPM_Desc_$i [db_get_col $res $i desc]
		}

		show_auth_list

		db_close $res
	}
}


# Searchs click and buy pay methods for a customer by cb_crn and email
#

proc do_clickandbuy_qry {} {

	global DB

	set cb_crn [string trim   [reqGetArg cb_crn]]
	set email  [string toupper [string trim [reqGetArg email]]]

	OT_LogWrite 10 "do_clickandbuy_qry (cb_crn= $cb_crn, email=$email)"

	if {$cb_crn == {} && $email == ""} {
		OT_LogWrite 10 "do_clickandbuy_qry: params are empty"
		err_bind "Please enter either a CRN Number or an Email address"
		ADMIN::PMT::go_auth_qry
		return
	}


	# build up the query
	set where {}

	if {$cb_crn != {}} {
		append where [subst {
			and cb.cb_crn = '$cb_crn'
		}]
	}

	if {$email != {}} {
		append where [subst {and UPPER(cb.cb_email) = '${email}'}]
	}

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc
		from
			tCustPayMthd m,
			tPayMthd     p,
			tCustomer    c,
			tCPMClickAndBuy cb,
			tAcct        a,
			tCustomerReg r
		where
			cb.cpm_id  = m.cpm_id
			and c.cust_id  = m.cust_id
			and m.pay_mthd = p.pay_mthd
			and c.cust_id  = r.cust_id
			and c.cust_id  = a.cust_id
			and a.owner    <> 'D'
			$where
		order by
			m.cpm_id asc
	}]

	OT_LogWrite 10 "do_clickandbuy_qry: $sql"

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		OT_LogWrite 1 "do_clickandbuy_qry: Error executing query - $msg"
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_auth_qry

	} else {

		tpSetVar NumCPM [set nrows [db_get_nrows $res]]
		OT_LogWrite 10 "do_clickandbuy_qry: nrows = $nrows"

		foreach f [db_get_colnames $res] {
			tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
		}

		for {set i 0} {$i<$nrows} {incr i} {
			tpSetVar CPM_Desc_$i [db_get_col $res $i desc]
		}

		show_auth_list

		db_close $res
	}

}

# Search MoneyBookers pay methods for a customer by email or their unique id
#
proc do_moneybookers_qry {} {

	global DB

	set email  [string toupper [string trim [reqGetArg email]]]
	set mb_id  [string trim   [reqGetArg mb_id]]

	OT_LogWrite 10 "do_moneybookers_qry (email= $email, mb_id=$mb_id)"

	if {$email == "" && $mb_id == ""} {
		OT_LogWrite 10 "do_moneybookers_qry: params are empty"
		err_bind "Please enter either an Email address or a MoneyBookers ID"
		ADMIN::PMT::go_auth_qry
		return
	}


	# build up the query
	set where {}

	if {$email != {}} {
		append where [subst {and UPPER(mb.mb_email_addr) = '${email}'}]
	}

	if {$mb_id != {}} {
		append where [subst {
			and mb.mb_cust_id = '$mb_id'
		}]
	}

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc
		from
			tCustPayMthd m,
			tPayMthd     p,
			tCustomer    c,
			tCPMMB       mb,
			tAcct        a,
			tCustomerReg r
		where
			mb.cpm_id  = m.cpm_id
			and c.cust_id  = m.cust_id
			and m.pay_mthd = p.pay_mthd
			and c.cust_id  = r.cust_id
			and c.cust_id  = a.cust_id
			and a.owner    <> 'D'
			$where
		order by
			m.cpm_id asc
	}]

	OT_LogWrite 10 "do_moneybookers_qry: $sql"

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		OT_LogWrite 1 "do_moneybookers_qry: Error executing query - $msg"
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_auth_qry

	} else {

		tpSetVar NumCPM [set nrows [db_get_nrows $res]]
		OT_LogWrite 10 "do_moneybookers_qry: nrows = $nrows"

		foreach f [db_get_colnames $res] {
			tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
		}

		for {set i 0} {$i<$nrows} {incr i} {
			tpSetVar CPM_Desc_$i [db_get_col $res $i desc]
		}

		show_auth_list

		db_close $res
	}

}

# Search Pay Safe Card pay methods for a customer by psc serial
#
proc do_paysafecard_qry {} {

	global DB

	set serial         [reqGetArg psc_serial]
	set search_exact   [reqGetArg psc_serial_exact]

	OT_LogWrite 10 "do_paysafecard_qry (serial= $serial, search_exact=$search_exact)"

	if {$serial == ""} {
		OT_LogWrite 10 "do_paysafecard_qry: params are empty"
		err_bind "Please enter a Serial Number"
		ADMIN::PMT::go_auth_qry
		return
	}


	# build up the query
	set where {}

	if {$serial != {}} {
		if {$search_exact == "Y"} {
			append where [subst {pi.psc_serial = '${serial}'}]
		} else {
			append where [subst {pi.psc_serial like '${serial}%'}]
		}
	}

	set sql [subst {
		select
			pi.psc_serial,
			c.cust_id,
			c.username,
			pi.psc_value,
			pp.cr_date,
			pp.state,
			pp.pmt_id,
			pp.errmessage
		from
			tPSCInfo  pi,
			tCustomer c,
			tPmtPSC   pp,
			tPmt      p,
			tAcct     a
		where
			c.cust_id = a.cust_id and
			a.acct_id = p.acct_id and
			p.pmt_id  = pi.pmt_id and
			pi.pmt_id = pp.pmt_id and
			$where
		order by
			pi.psc_serial
	}]

	OT_LogWrite 10 "do_paysafecard_qry: $sql"

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		OT_LogWrite 1 "do_paysafecard_qry: Error executing query - $msg"
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_auth_qry

	} else {

		tpSetVar NumCPM [set nrows [db_get_nrows $res]]
		OT_LogWrite 10 "do_paysafecard_qry: nrows = $nrows"

		foreach f [db_get_colnames $res] {
			tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
		}

		tpBindString ColSpan 7

		asPlayFile -nocache pmt/pmt_psc_list.html

		db_close $res
	}

}

proc do_envoy_pmt_mthd_qry {} {

	global DB

	set envoy_uniq_ref [reqGetArg envoy_uniq_ref]

	set ext_sub_link_id \
	       [payment_ENVO::b27_to_b10 [string range $envoy_uniq_ref 5 end]]

	set sql [subst {
		select
			m.cpm_id,
			m.cust_id,
			m.pay_mthd,
			m.cr_date,
			m.status,
			m.auth_dep,
			m.order_dep,
			m.auth_wtd,
			m.order_wtd,
			c.username,
			c.acct_no,
			r.lname,
			a.ccy_code,
			p.desc,
			s.desc as sub_mthd_desc
		from
			tCustPayMthd   m,
			tPayMthd       p,
			tCustomer      c,
			tAcct          a,
			tCustomerReg   r,
			tExtSubCPMLink l,
			tExtSubPayMthd s
		where
			l.ext_sub_link_id = $ext_sub_link_id
		and l.cpm_id          = m.cpm_id
		and c.cust_id         = m.cust_id
		and m.pay_mthd        = p.pay_mthd
		and c.cust_id         = r.cust_id
		and c.cust_id         = a.cust_id
		and a.owner          <> 'D'
		and l.sub_type_code   = s.sub_type_code
		order by
			cpm_id asc
	}]

	OT_LogWrite 10 "do_envoy_pmt_mthd_qry: $sql"

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	} msg]} {

		OT_LogWrite 1 "do_envoy_pmt_mthd_qry: Error executing query - $msg"
		err_bind "Error executing query - $msg"
		ADMIN::PMT::go_auth_qry

	} else {

		tpSetVar NumCPM [set nrows [db_get_nrows $res]]
		OT_LogWrite 10 "do_envoy_pmt_mthd_qry: nrows = $nrows"

		foreach f [db_get_colnames $res] {
			tpBindTcl CPM_${f} sb_res_data $res cpm_idx $f
		}

		for {set i 0} {$i<$nrows} {incr i} {
			tpSetVar CPM_Desc_$i "[db_get_col $res $i desc] [db_get_col $res $i sub_mthd_desc]"
		}

		show_auth_list

		db_close $res
	}
}


proc show_auth_list {} {
	#decide which columns to show
	if {[set auth_fields [OT_CfgGet PMT_AUTH_FIELDS ""]] == ""} {
		set auth_fields [list Date Username Acct Method]
	}
	foreach f $auth_fields {
		tpSetVar Show${f} "Y"
	}

	tpBindString ColSpan [expr {5 + [llength $auth_fields]}]

    uplevel 1 asPlayFile -nocache pmt/pmt_auth_list.html


}

proc pmt_qry_back {action} {
	if {$action == "PMT"} {
		go_pay_mthd_auth
	} else {
		ADMIN::CUST::go_cust
	}
}

# close namespace
}
