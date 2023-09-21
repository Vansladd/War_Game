# ==============================================================
# $Id: pmt_detail.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {


asSetAct ADMIN::PMT::bind_detail_cust [namespace code bind_detail_cust]
asSetAct ADMIN::PMT::bind_detail_BANK [namespace code bind_detail_BANK]
asSetAct ADMIN::PMT::bind_detail_CHQ  [namespace code bind_detail_CHQ]
asSetAct ADMIN::PMT::bind_detail_CC   [namespace code bind_detail_CC]
asSetAct ADMIN::PMT::bind_detail_PB   [namespace code bind_detail_PB]
asSetAct ADMIN::PMT::bind_detail_WU   [namespace code bind_detail_WU]
asSetAct ADMIN::PMT::bind_detail_EP   [namespace code bind_detail_EP]
asSetAct ADMIN::PMT::bind_detail_bet  [namespace code bind_detail_bet]
asSetAct ADMIN::PMT::bind_detail_BASC [namespace code bind_detail_BASC]
asSetAct ADMIN::PMT::bind_detail_ENET [namespace code bind_detail_ENET]
asSetAct ADMIN::PMT::bind_detail_MB   [namespace code bind_detail_MB]
asSetAct ADMIN::PMT::bind_detail_C2P  [namespace code bind_detail_C2P]
asSetAct ADMIN::PMT::bind_detail_PPAL [namespace code bind_detail_PPAL]
asSetAct ADMIN::PMT::bind_detail_SHOP [namespace code bind_detail_SHOP]
asSetAct ADMIN::PMT::bind_detail_CB   [namespace code bind_detail_CB]
asSetAct ADMIN::PMT::bind_detail_ENVO [namespace code bind_detail_ENVO]



proc bind_detail_GDEP {cpm_id} {
	global DB

	set sql [subst {
		select
		from
		where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	db_close $res

	return
}

proc bind_detail_WU {cpm_id} {

	global DB

	set sql [subst {
		select
			w.payee wu_payee,
			w.country_code wu_country_code
		from
			tCPMWU w
		where
			w.cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_BANK {cpm_id} {

	global DB

	set sql [subst {
		select
			b.bank_name,
			b.bank_addr_1,
			b.bank_addr_2,
			b.bank_addr_3,
			b.bank_addr_4,
			b.bank_addr_city,
			b.bank_addr_postcode,
			b.bank_acct_no,
			b.bank_acct_name,
			b.bank_sort_code,
			b.bank_branch,
			b.swift_code,
			b.iban_code,
			t.country_name
		from
			tCPMBank b,
			tCountry t
		where
			t.country_code = b.country_code and
			b.cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_CHQ {cpm_id} {

	global DB

	set sql [subst {
		select
			c.payee,
			c.addr_street_1,
			c.addr_street_2,
			c.addr_street_3,
			c.addr_street_4,
			c.addr_city,
			c.addr_postcode,
			t.country_name
		from
			tCPMChq c,
			tCountry t
		where
			t.country_code = c.country_code and
			c.cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_CC {cpm_id} {

	global DB BET

	OT_LogWrite 5 "==> bind_detail_CC cpm_id=($cpm_id)"

	set sql [subst {
		select
			m.type,
			c.card_bin cc_card_bin,
			c.enc_card_no cc_enc_card_no,
			c.ivec cc_ivec,
			c.data_key_id cc_data_key_id,
			c.start cc_start,
			c.expiry cc_expiry,
			c.issue_no cc_issue_no,
			c.hldr_name cc_hldr_name,
			c.desc cc_desc,
			c.cvv2_resp,
			c.enc_with_bin
		from
			tCustPayMthd m,
			tCPMCC c
		where
			c.cpm_id = ?
		and m.cpm_id = c.cpm_id
	}]


	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	#
	# Now decrypt the card number and rebind the string site
	#
	set card_bin      [db_get_col $res 0 cc_card_bin]
	set enc_card_no   [db_get_col $res 0 cc_enc_card_no]
	set ivec          [db_get_col $res 0 cc_ivec]
	set data_key_id   [db_get_col $res 0 cc_data_key_id]
	set type          [db_get_col $res 0 type]
	set enc_with_bin  [db_get_col $res 0 enc_with_bin]

	set is_entropay_card [expr {$type == "EN"}]

	set repl_midrange [expr {
		![op_allowed ViewCardNumber] ||
		($is_entropay_card && ![op_allowed ViewEntropayCardNum])
	}]

	# Decrypt the card number and add the bin to the front of it
	set card_dec_rs [card_util::card_decrypt $enc_card_no $ivec $data_key_id]

	if {[lindex $card_dec_rs 0] == 0} {
		# Check on the reason decryption failed, if we encountered corrupt data we should also
		# record this fact in the db
		if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
			card_util::update_data_enc_status "tCPMCC" $cpm_id [lindex $card_dec_rs 2]
		}

		OT_LogWrite 1 "Error decrypting card number: [lindex $card_dec_rs 1]"
		tpBindString PM_card_no DECRYPT_ERR
	} else {
		set dec_card_no [lindex $card_dec_rs 1]
		set card_no [card_util::format_card_no $dec_card_no $card_bin $enc_with_bin]

		if {$repl_midrange} {
			set card_no [card_util::card_replace_midrange $card_no 1]
		}

		set tmp_card_no ""

		# split the card number up into blocks of four digitsfor readability
		for {set ind 0} {$ind < [expr [string length $card_no] - 4]} {incr ind 4} {
			append tmp_card_no [string range $card_no $ind [expr $ind + 3]] " "
		}
		append tmp_card_no [string range $card_no $ind end]

		tpBindString PM_card_no $tmp_card_no
	}

	tpBindString PM_enc_card_no $enc_card_no
	tpBindString PM_cc_type [ADMIN::PMT::get_card_type $card_bin]
	tpSetVar PM_is_entropay_card $is_entropay_card
	tpSetVar HasResp [card_util::payment_has_resp $cpm_id]


	db_close $res
}

proc bind_detail_PB {cpm_id} {

	global DB BET

	OT_LogWrite 5 "==> bind_detail_PB cpm_id=($cpm_id)"

	set sql [subst {
		select
			p.pb_number
		from
			tCPMPB p
		where
			p.cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_BASC {cpm_id {return_name 0}} {

	global DB

	OT_LogWrite 5 "==> bind_detail_BASC cpm_id=($cpm_id)"

	set sql [subst {
		select
			i.name,
			i.deposit_email,
			i.withdrawal_email,
			i.auto_auth_dep,
			i.auto_auth_wtd
		from
			tCPMBasic b,
			tBasicPayInfo i
		where
			b.cpm_id = ?
		and
			i.basic_info_id = b.basic_info_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString Basic_$c [db_get_col $res 0 $c]
	}
	set name [db_get_col $res 0 name]

	db_close $res

	if {$return_name} {
		return $name
	}
}

proc bind_detail_EP {cpm_id} {
	global DB

	OT_LogWrite 5 "==> bind_detail_EP cpm_id=($cpm_id)"

	set sql [subst {
		select
			earthport_van,
			description,
			country,
			ac_ccy,
			bank_name,
			bank_code,
			ac_name,
			ac_num,
			bank_sort,
			holding,
			branch_code
		from
			tcpmep
		where
			cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
		if {$c == {earthport_van}} {
			tpSetVar PM_$c [db_get_col $res 0 $c]
		}
	}

	db_close $res
}

proc bind_detail_NTLR {cpm_id} {
	global DB

	OT_LogWrite 5 "==> bind_detail_NTLR cpm_id=($cpm_id)"

	set sql [subst {
		select
			neteller_id
		from
			tCPMNeteller
		where
			cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_ENET {cpm_id} {
	global DB

	OT_LogWrite 5 "==> bind_detail_ENET cpm_id=($cpm_id)"

	set sql [subst {
		select
			cpm_id,
			cust_id
		from
			tCPMeNETS
		where
			cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}


proc bind_detail_MB {cpm_id} {

	OT_LogWrite 5 "==> bind_detail_MB cpm_id=($cpm_id)"

	global DB

	set sql {
		select
			mb_email_addr,
			mb_cust_id
		from
			tCPMMB
		where
			cpm_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $res] {
		tpBindString PM_$c [db_get_col $res 0 $c]
	}

	db_close $res
}

proc bind_detail_ENVO {cpm_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_ENVO cpm_id=($cpm_id)"

	set sql {
		select
			a.ccy_code,
			l.ext_sub_link_id,
			s.sub_type_code,
			s.desc,
			e.additional_info1 as additional_info,
			e.remote_ccy
		from
			tCustPayMthd cpm,
			tAcct a,
			tExtSubCPMLink l,
			tExtSubPayMthd s,
			tCPMEnvoy e
		where
			cpm.cpm_id      = ?
		and cpm.cust_id     = a.cust_id
		and cpm.cpm_id      = l.cpm_id
		and l.sub_type_code = s.sub_type_code
		and cpm.cpm_id      = e.cpm_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	set unique_ref [payment_ENVO::generate_cust_ref \
		[db_get_col $rs 0 ext_sub_link_id] \
		[db_get_col $rs 0 ccy_code]]

	set sub_type [db_get_col $rs 0 sub_type_code]

	tpBindString PM_envoy_add_info_type   [payment_ENVO::get_envo_ewallet_detail $sub_type add_info_type]
	tpBindString PM_envoy_uniq_ref        $unique_ref
	tpBindString PM_sub_mthd_code         $sub_type
	tpBindString PM_envoy_remote_ccy      [db_get_col $rs 0 remote_ccy]
	tpBindString PM_sub_mthd_desc         [db_get_col $rs 0 desc]
	tpBindString PM_envoy_additional_info [db_get_col $rs 0 additional_info]

	bind_currency_codes

	db_close $rs

}

# Binding  Click and Buy customers data
#
#   cpm_id - customer payment method id
#

proc bind_detail_CB {cpm_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_CB cpm_id=($cpm_id)"

	set sql {
		select
			p.cb_crn,
			c.lang
		from
			tCPMClickAndbuy p,
			tCustomer c
		where
			c.cust_id = p.cust_id and
			p.cpm_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	foreach col [db_get_colnames $res] {
		tpBindString PM_$col [db_get_col $res 0 $col]
	}

	db_close $res

}


proc bind_detail_C2P {cpm_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_C2P cpm_id=($cpm_id)"

	set sql [subst {
		select
			enc_pan,
			username
		from
			tCPMC2P
		where
			cpm_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	tpBindString PM_username [db_get_col $res 0 username]
	tpBindString PM_pan [ob_click2pay::replace_midrange \
	                        [ob_click2pay::encrypt_decrypt_pan \
	                        [db_get_col $res 0 enc_pan] "decrypt"]]

	db_close $res
}



#
#  bind_detail_PPAL
#
#  Bind up info for Paypal CPM
#
#  cpm_id - The ID of the customer's payment method
#
proc bind_detail_PPAL {cpm_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_PPAL cpm_id=($cpm_id)"
	set sql {
		select
			payer_id,
			email
		from
			tCPMPayPal
		where
			cpm_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 1} {
		foreach c [db_get_colnames $res] {
			tpBindString PM_$c [db_get_col $res 0 $c]
		}
	} else {
		OT_LogWrite 1 "==> bind_detail_PPAL cpm_id=($cpm_id) not found (nrows=$nrows)"
	}

	db_close $res
}


#
#  bind_detail_SHOP
#
#  Bind up info for Shop payment method
#
#  cpm_id - The ID of the customer's payment method
#
proc bind_detail_SHOP {cpm_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_SHOP cpm_id=($cpm_id)"
	set sql {
		select
			security_number
		from
			tCPMShop
		where
			cpm_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cpm_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 1} {
		foreach c [db_get_colnames $res] {
			tpBindString PM_$c [db_get_col $res 0 $c]
		}
	} else {
		OT_LogWrite 1 "==> bind_detail_SHOP cpm_id=($cpm_id) not found (nrows=$nrows)"
	}

	db_close $res
}



#
#  get_ppal_txn_details
#
#  Obtain the PayPal transaction details within a given timeframe
#
#  pmt_id     - the ID of the payment
#  txn_id     - the PayPal transaction ID
#  inv_num    - the invoice number
#  ccy_code   - The users currency code
#  start_date - the start date range to use in the search
#
proc get_ppal_txn_details { pmt_id txn_id inv_num ccy_code start_date} {

	OT_LogWrite 5 \
		"==> get_ppal_txn_details $pmt_id,$txn_id,$ccy_code,$start_date"

	# if we don't have a transaction need to search for transaction id
	# first
	if {$txn_id == ""} {

		set ret \
			[ob_paypal::do_transaction_search $inv_num $start_date $ccy_code]

		# was it successful?
    	if {[lindex $ret 0]} {

			set pmts [lindex $ret 1]

 			# we must only have one element
 			if {[llength $pmts] == 1} {

				array set PMT [lindex $pmts 0]

				set txn_id $PMT(L_TRANSACTIONID)

			} else {
				err_bind "Failed to get transaction details: Found more than 1 payment"
				return
			}

 		} else {
			set err_msg [lindex $ret 1]
			err_bind "Failed to get transaction details: $err_msg"
			return
		}

	}

	# we have a transaction id. Get the details
	set res [ob_paypal::get_transaction_details $txn_id $ccy_code]

	if {![lindex $res 0]} {
		set err_msg [lindex $ret 1]
		err_bind "Failed to get transaction details: $err_msg"
		return
	}

	set txn_details [lindex $res 1]

	# bind up PayPal transaction details
	foreach {elem_name elem_value} $txn_details {
		tpBindString "ppal_[string tolower ${elem_name}]" $elem_value
	}

	tpSetVar SHOW_PPAL_TXN_DETAILS 1

}


proc bind_detail_cust {cust_id} {

	global DB

	OT_LogWrite 5 "==> bind_detail_cust ($cust_id)"

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.elite,
			c.country_code,
			r.title,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_postcode,
			t.country_name,
			a.ccy_code,
			a.acct_id
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			tCustomerSort s,
			tCountry   t
		where
			c.cust_id = ? and
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			c.sort = s.sort and
			c.country_code = t.country_code
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set elite 0

	if {[db_get_nrows $res]>0} {

		if {[db_get_col $res 0 elite] == "Y"} {
			incr elite
		}

		tpBindString CustUsername   [db_get_col $res 0 username]
		tpBindString CustAcctNo     [acct_no_enc [db_get_col $res 0 acct_no]]
		tpBindString Elite          [db_get_col $res 0 elite]
		tpBindString CustTitle      [db_get_col $res 0 title]
		tpBindString CustFName      [db_get_col $res 0 fname]
		tpBindString CustLName      [db_get_col $res 0 lname]
		tpBindString CustAddr1      [db_get_col $res 0 addr_street_1]
		tpBindString CustAddr2      [db_get_col $res 0 addr_street_2]
		tpBindString CustAddr3      [db_get_col $res 0 addr_street_3]
		tpBindString CustAddr4      [db_get_col $res 0 addr_street_4]
		tpBindString CustAddrCity   [db_get_col $res 0 addr_city]
		tpBindString CustPostCode   [db_get_col $res 0 addr_postcode]
		tpBindString CustCountry    [db_get_col $res 0 country_name]
		tpBindString CustCurrency   [db_get_col $res 0 ccy_code]
		tpBindString AcctId         [db_get_col $res 0 acct_id]


		if {[db_get_col $res 0 country_code] ==""} {
			bind_country_codes "UK"
		} else {
			bind_country_codes [db_get_col $res 0 country_code]
		}
	}
	db_close $res

	tpSetVar IS_ELITE $elite

	tpBindString CustId $cust_id
}

proc bind_country_codes {default_ctry} {
	global DB DATA

	set sql {
		select
			bank_template,
			country_code,
			country_name,
			disporder
		from
			tCountry
		where
			status = 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCountrys [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set DATA($r,bank_template)  [db_get_col $res $r bank_template]
		set DATA($r,country_code)   [db_get_col $res $r country_code]
		set DATA($r,country_name)   [db_get_col $res $r country_name]

		if {$default_ctry == $DATA($r,country_code)} {
			set DATA($r,country_sel) SELECTED
		} else {
			set DATA($r,country_sel) ""
		}
	}

	tpBindVar CountryCode DATA bank_template country_idx
	tpBindVar CountryCode DATA country_code  country_idx
	tpBindVar CountryName DATA country_name  country_idx
	tpBindVar CountrySel  DATA country_sel   country_idx

	db_close $res
}

proc bind_currency_codes {{selected ""}} {
	global DB DATA

	set sql [subst {
		select
			ccy_code,
			ccy_name
		from
			tCCY
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [expr {[db_get_nrows $res] + 1}]
	tpSetVar NumCcy $nrows

	if {$nrows>0} {
		for {set r 0} {$r < $nrows} {incr r} {
			if {$r == 0} {
				set DATA($r,ccy_name) "--"
				set DATA($r,ccy_code) ""
				if {$selected == ""} {
					set DATA($r,sel_ccy) "selected"
				}
				continue

			} else {
				set DATA($r,ccy_name) [db_get_col $res [expr {$r-1}] ccy_name]
				set DATA($r,ccy_code) [db_get_col $res [expr {$r-1}] ccy_code]
			}


			if {$selected == [db_get_col $res [expr {$r-1}] ccy_code]} {
				set DATA($r,sel_ccy) "selected"
			} else {
				set DATA($r,sel_ccy) ""
			}
		}

		tpBindVar PayMthdCcyName DATA  ccy_name  ccy_idx
		tpBindVar PayMthdCcyCode DATA  ccy_code  ccy_idx
		tpBindVar SelPayMthdCcy  DATA  sel_ccy   ccy_idx
	}

	db_close $res

}

proc bind_detail_bet {pmt_id} {

	global DB BET

	# Get which type of query has been selected

	set sql [subst {
		select
			c.cust_id,
			c.username,
			a.ccy_code,
			b.call_id,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.winnings,
			b.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			t.gw_auth_code,
			e.desc ev_name,
			g.name mkt_name,
			s.desc seln_name,
			s.result,
			s.ev_mkt_id,
			s.ev_oc_id,
			s.ev_id,
			o.bet_id,
			o.leg_no,
			o.part_no,
			o.leg_sort,
			o.price_type,
			""||o.o_num o_num,
			""||o.o_den o_den
		from
			tBet b,
			tOBet o,
			tPmt p,
			tPmtCC t,
			tAcct a,
			tCustomer c,
			tEvOc s,
			tEvMkt m,
			tEvOcGrp g,
			tEv e
		where
			p.pmt_id = ? and
			p.pmt_id = t.pmt_id and
			p.call_id = b.call_id and
			b.settled = 'N' and
			b.bet_id = o.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			o.ev_oc_id = s.ev_oc_id and
			s.ev_mkt_id = m.ev_mkt_id and
			m.ev_oc_grp_id = g.ev_oc_grp_id and
			s.ev_id = e.ev_id
		union

		select
			c.cust_id,
			c.username,
			a.ccy_code,
			b.call_id,
			b.cr_date,
			b.receipt,
			b.stake,
			b.status,
			b.settled,
			b.winnings,
			b.refund,
			b.num_lines,
			b.bet_type,
			b.leg_type,
			t.gw_auth_code,
			m.desc_1 ev_name,
			m.desc_2 mkt_name,
			m.desc_3 seln_name,
			'-' result,
			0 ev_mkt_id,
			0 ev_oc_id,
			0 ev_id,
			m.bet_id,
			1 leg_no,
			1 part_no,
			'--' leg_sort,
			'L' price_type,
			'' o_num,
			'' o_den
		from
			tBet b,
			tManOBet m,
			tAcct a,
			tCustomer c,
			tPmtCC t,
			tPmt p
		where
			p.pmt_id = ? and
			p.pmt_id = t.pmt_id and
			p.call_id = b.call_id and
			b.settled = 'N' and
			b.bet_id = m.bet_id and
			b.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			b.bet_type = 'MAN'
		order by
			23 desc,24 asc,25 asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id $pmt_id]
	inf_close_stmt $stmt

	bind_bet_list $res
	db_close $res
}

proc bind_bet_list {res} {

	global BET
	set rows [db_get_nrows $res]

	set cur_id 0
	set b -1
	catch {
		unset BET
	}
	array set BET [list]

	for {set r 0} {$r < $rows} {incr r} {

		set call_id [db_get_col $res $r call_id]
		set bet_id  [db_get_col $res $r bet_id]

		if {$bet_id != $cur_id} {
			set cur_id $bet_id
			set l 0
			incr b
			set BET($b,num_selns) 0
		}
		incr BET($b,num_selns)

		if {$l == 0} {
			set bet_type          [db_get_col $res $r bet_type]
			if {$bet_type=="MAN"} {
				set man_bet 1
			} else {
				set man_bet 0
			}
			if {$man_bet==1} {
				tpSetVar ManBet 1
			}

			if {$bet_type=="XGAME"} {
				set xgame_bet 1
			} else {
				set xgame_bet 0
			}

			set BET($b,bet_type)  $bet_type
			set BET($b,bet_id)    $bet_id
			set BET($b,receipt)   [db_get_col $res $r receipt]
			set BET($b,bet_time)  [db_get_col $res $r cr_date]
			set BET($b,leg_type)  [db_get_col $res $r leg_type]
			set BET($b,stake)     [db_get_col $res $r stake]
			set BET($b,ccy)       [db_get_col $res $r ccy_code]
			set BET($b,cust_id)   [db_get_col $res $r cust_id]
			set BET($b,cust_name) [db_get_col $res $r username]
			set BET($b,status)    [db_get_col $res $r status]
			set BET($b,settled)   [db_get_col $res $r settled]
			set BET($b,winnings)  [db_get_col $res $r winnings]
			set BET($b,refund)    [db_get_col $res $r refund]
		}

		set price_type [db_get_col $res $r price_type]

		if {$price_type == "L" || $price_type == "S"} {
			set o_num [db_get_col $res $r o_num]
			set o_den [db_get_col $res $r o_den]
			if {$o_num=="" || $o_den==""} {
				set p_str "-"
			} else {
				set p_str [mk_price $o_num $o_den]
				if {$p_str == ""} {
					set p_str "SP"
				}
			}
		} else {
			set p_str "DIV"
		}
		set BET($b,$l,price)     $p_str
		set BET($b,$l,man_bet)   $man_bet
		set BET($b,$l,xgame_bet) $xgame_bet
		set BET($b,$l,leg_sort)  [db_get_col $res $r leg_sort]
		set BET($b,$l,leg_no)    [db_get_col $res $r leg_no]
		set ev_name              [string trim [db_get_col $res $r ev_name]]
		if {$man_bet==0} {
			set BET($b,$l,event)     $ev_name
			set BET($b,$l,mkt)       [db_get_col $res $r mkt_name]
			set BET($b,$l,seln)      [db_get_col $res $r seln_name]
			set BET($b,$l,result)    [db_get_col $res $r result]
			set BET($b,$l,ev_id)     [db_get_col $res $r ev_id]
			set BET($b,$l,ev_mkt_id) [db_get_col $res $r ev_mkt_id]
			set BET($b,$l,ev_oc_id)  [db_get_col $res $r ev_oc_id]
		} else {
			set BET($b,$l,event)     [string range $ev_name 0 25]
			set BET($b,$l,mkt)       [string range $ev_name 26 51]
			set BET($b,$l,seln)      [string range $ev_name 52 77]
			set BET($b,$l,result)    "-"
		}
		incr l
	}
	if {$bet_type=="XGAME"} {
		set BET($b,num_selns) 1
	}

	tpSetVar NumBets [expr {$b+1}]

	tpBindVar CustId      BET cust_id   bet_idx
	tpBindVar CustName    BET cust_name bet_idx
	tpBindVar BetId       BET bet_id    bet_idx
	tpBindVar BetReceipt  BET receipt   bet_idx
	tpBindVar Manual      BET manual    bet_idx
	tpBindVar BetTime     BET bet_time  bet_idx
	tpBindVar BetSettled  BET settled   bet_idx
	tpBindVar BetType     BET bet_type  bet_idx
	tpBindVar LegType     BET leg_type  bet_idx
	tpBindVar BetCCY      BET ccy       bet_idx
	tpBindVar BetStake    BET stake     bet_idx
	tpBindVar Winnings    BET winnings  bet_idx
	tpBindVar Refund      BET refund    bet_idx
	tpBindVar BetLegNo    BET leg_no    bet_idx seln_idx
	tpBindVar BetLegSort  BET leg_sort  bet_idx seln_idx
	tpBindVar EvDesc      BET event     bet_idx seln_idx
	tpBindVar MktDesc     BET mkt       bet_idx seln_idx
	tpBindVar SelnDesc    BET seln      bet_idx seln_idx
	tpBindVar Price       BET price     bet_idx seln_idx
	tpBindVar Result      BET result    bet_idx seln_idx
	tpBindVar EvId        BET ev_id     bet_idx seln_idx
	tpBindVar EvMktId     BET ev_mkt_id bet_idx seln_idx
	tpBindVar EvOcId      BET ev_oc_id  bet_idx seln_idx

	if [tpGetVar ManBet 0] {
		foreach f {UseSub Customer UpperCust FName LName \
			Email AcctNo Receipt CompNo BetDate1 BetDate2 \
			StlDate1 StlDate2 Stake1 Stake2 Wins1 Wins2 \
			Settled BetTypeOp BetType Manual GameType} {
			set $f [reqGetArg $f]
			tpBindString SR_$f [reqGetArg $f]
		}
	}

}

proc get_card_type {card_bin} {

	global DB

	OT_LogWrite 5 "==> get_card_type card_bin=$card_bin"

	set sql [subst {
		select
			i.type
		from
			tCardSchemeInfo i,
			tCardScheme s
		where
			s.bin_lo <= ? and
			s.bin_hi >= ? and
			i.scheme = s.scheme
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $card_bin $card_bin]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] != 1} {
		return ""
	}

	set card_type [db_get_col $res 0 type]
	db_close $res

	return $card_type
}

# close namespace
}
