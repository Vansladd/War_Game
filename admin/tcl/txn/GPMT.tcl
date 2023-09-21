# ==============================================================
# $Id: GPMT.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::TXN::GPMT {

asSetAct ADMIN::TXN::GPMT::GoPmt   [namespace code go_pmt]
asSetAct ADMIN::TXN::GPMT::GoTxn   [namespace code go_pmt_txn]


proc go_pmt_txn {} {

	reqSetArg pmt_id [reqGetArg op_ref_id]
	go_pmt

}


#
# ----------------------------------------------------------------------------
# Go to a specific payment
#
# 1) Get the generic header information
# 2) Get the payment-specific information
# ----------------------------------------------------------------------------
#
proc go_pmt {{pmt_id ""}} {

	global DB BET

	OT_LogWrite 5 "==> go_pmt"

	if {$pmt_id == ""} {
		set pmt_id [reqGetArg pmt_id]
	}

	set cust_id      [reqGetArg cust_id]

	foreach f {SR_username SR_upper_username SR_fname SR_lname SR_email \
			SR_acct_no_exact SR_acct_no SR_date_1 SR_date_2 SR_date_range SR_status \
			SR_payment_sort SR_channel SR_pay_mthd} {
		set $f [reqGetArg $f]
		tpBindString $f [reqGetArg $f]
	}

	#
	# Get payment header information - once this is done, we go elsewhere
	# to get the payment method-specific information
	#
	set sql [subst {
		select
			c.username,
			c.acct_no,
			c.cust_id,
			a.acct_id,
			a.ccy_code,
			r.title,
			r.fname,
			r.lname,
			p.pmt_id,
			p.cr_date,
			p.source,
			p.status,
			p.payment_sort,
			p.amount,
			p.commission,
			p.ref_key,
			p.call_id,
			p.settled_at,
			NVL(pp.process_date,extend(current,year to second)) as pending_process_date,
			p.receipt,
			u1.username as operator,
			u2.username as settled_by,
			m.desc,
			m.pay_mthd,
			p.auth_code,
			cm.cpm_id,
			l.telephone as line_no,
			p.ipaddr,
			p.unique_id,
			pst.large_ret_auth,
			pst.lr_auth_user_id,
			pst.lr_auth_date,
			pst.fraud_check_auth,
			pst.fc_auth_user_id,
			pst.fc_auth_date,
			ir.device_alias,
			ir.response
		from
			tPmt p,
			tAcct a,
			tCustomer c,
			tCustomerreg r,
			tCustPayMthd cm,
			tPayMthd m,
			outer tAdminUser u1,
			outer tAdminUser u2,
			outer tCall l,
			outer tPmtPendStatus pst,
			outer tPmtPending pp,
			outer tIovResponse ir
		where
			p.pmt_id  = ? and
			p.acct_id = a.acct_id and
			a.cust_id = c.cust_id and
			c.cust_id = r.cust_id and
			p.cpm_id = cm.cpm_id and
			cm.pay_mthd = m.pay_mthd and
			p.oper_id    = u1.user_id and
			p.settled_by = u2.user_id and
			p.call_id = l.call_id     and
			p.pmt_id  = pst.pmt_id and
			p.pmt_id  = pp.pmt_id and
			ir.ref_key = 'PMT' and
			p.pmt_id  = ir.ref_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	tpSetVar pay_mthd           [db_get_col $res 0 pay_mthd]
	tpSetVar status             [db_get_col $res 0 status]
	tpSetVar cpm_id             [db_get_col $res 0 cpm_id]
	tpSetVar payment_sort       [db_get_col $res 0 payment_sort]
	tpSetVar pmt_id             $pmt_id
	tpSetVar call_id            [db_get_col $res 0 call_id]

	tpBindString status         [db_get_col $res 0 status]
	tpBindString ref_no         [format %08d $pmt_id]
	tpBindString cust_id        [db_get_col $res 0 cust_id]
	tpBindString username       [db_get_col $res 0 username]
	tpBindString acct_no        [db_get_col $res 0 acct_no]
	tpBindString title          [db_get_col $res 0 title]
	tpBindString fname          [db_get_col $res 0 fname]
	tpBindString lname          [db_get_col $res 0 lname]
	tpBindString acct_pmt_id    $pmt_id
	tpBindString cr_date        [db_get_col $res 0 cr_date]
	tpBindString ccy_code       [db_get_col $res 0 ccy_code]
	tpBindString source         [db_get_col $res 0 source]
	tpBindString payment_sort   [db_get_col $res 0 payment_sort]
	tpBindString amount         [db_get_col $res 0 amount]
	tpBindString commission     [db_get_col $res 0 commission]
	tpBindString pay_mthd_desc  [db_get_col $res 0 desc]
	tpBindString pay_mthd       [db_get_col $res 0 pay_mthd]
	tpBindString auth_code      [db_get_col $res 0 auth_code]
	tpBindString settled_at     [db_get_col $res 0 settled_at]
	tpBindString operator       [db_get_col $res 0 operator]
	tpBindString settled_by     [db_get_col $res 0 settled_by]
	tpBindString line_no        [db_get_col $res 0 line_no]
	tpBindString cpm_id         [db_get_col $res 0 cpm_id]
	tpBindString ipaddr         [db_get_col $res 0 ipaddr]
	tpBindString unique_id      [db_get_col $res 0 unique_id]
	tpBindString receipt        [db_get_col $res 0 receipt]

	if {[OT_CfgGet FUNC_IOVATION_SNARE 0]} {
		tpBindString iova_device_alias [db_get_col $res 0 device_alias]
		tpBindString iova_response     [db_get_col $res 0 response]
	}

	set pending_process_date    [db_get_col $res 0 pending_process_date]
	if {[clock scan $pending_process_date] > [clock seconds]} {
		tpBindString is_delayed "Y"
	}

	set ref_key [db_get_col $res 0 ref_key]

	set cpm_id  [db_get_col $res 0 cpm_id]

	set desc    [db_get_col $res 0 desc]

	#
	# check we have a valid pay method
	#
	set pay_mthd [db_get_col $res 0 pay_mthd]
	if {[lsearch {CHQ CC BANK GDEP GWTD CSH PB EP BC NTLR BASC WU ENET MB ENVO C2P PPAL SHOP UKSH IKSH CB PSC} $pay_mthd] == -1} {
		error "payment method not recognised"
	}

	# Bind the Agent name into the Description if method == BASC
	if {$pay_mthd == "BASC"} {
		set agent [ADMIN::PMT::bind_detail_BASC $cpm_id 1]
		if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
			tpBindString pay_mthd_desc "MCA ($agent)"
		} else {
			tpBindString pay_mthd_desc "$desc ($agent)"
		}
	}

	set large_ret_auth   [db_get_col $res 0 large_ret_auth]
	set fraud_check_auth [db_get_col $res 0 fraud_check_auth]

	if {$large_ret_auth == "P"} {
		tpSetVar PendFraudFlags 1
		tpSetVar ShowLargeRetAuth 1
	}

	if {$fraud_check_auth == "P"} {
		tpSetVar PendFraudFlags 1
		tpSetVar ShowFraudCheckAuth 1
	}

	db_close $res


	global DATA

	#
	# Get all linked Manual Adjustments
	#
	set sql [subst {
		select
			madj_id
		from
			tManAdj
		where
			    ref_key = "PMT"
			and ref_id  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	tpSetVar NumAdjs [set NumAdjs [db_get_nrows $res]]

	for {set r 0} {$r < $NumAdjs} {incr r} {
		set DATA($r,madj_id) [db_get_col $res $r madj_id]
	}

	tpBindVar ManAdjId DATA madj_id adj_idx

	#
	# Bank CPMs may have gone via Envoy
	#
	if {$pay_mthd == "BANK" && $ref_key == "ENVO"} {
		set pay_mthd "ENVO"
		tpBindString route "Envoy"
	} elseif {$pay_mthd == "BANK"} {
		tpBindString route "Bank"
	}

	#
	# bind the relevent detail
	#
	go_pmt_${pay_mthd} $pmt_id

	if {[reqGetArg additional_html] != {}} {
		asPlayFile -nocache [reqGetArg additional_html]
	}

	asPlayFile -nocache pmt/pmt_detail.html
}

proc go_pmt_BC {pmt_id} {

	global DB

	set sql [subst {
		select
			p.vendor_pmt_id,
			p.vendor_id,
			p.betcard_id,
			v.vendor_uname,
			c.betcard_no,
			c.betcard_key
		from
			tPmtBetcard p,
			tBetcard c,
			tBetcardVendor v
		where
			p.pmt_id  = ?
		and
			p.betcard_id = c.betcard_id
		and
			p.vendor_id = v.vendor_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	set betcard_no [db_get_col $res 0 betcard_no]
	set betcard_key [db_get_col $res 0 betcard_key]

	tpBindString PMT_betcard_no_enc [OB::BETCARD::generate_betcard_number $betcard_no $betcard_key]

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

proc go_pmt_CSH {pmt_id} {

	global DB

	set sql [subst {
		select
			p.outlet,
			p.id_serial_no,
			p.manager,
			p.extra_info
		from
			tPmtCsh p
		where
			p.pmt_id  = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}


proc go_pmt_CHQ {pmt_id} {

    global DB

    set sql [subst {
        select
            p.payer,
            p.chq_no,
            p.chq_sort_code,
            p.chq_acct_no,
            p.chq_date,
            p.rec_delivery_ref,
            p.extra_info
        from
            tPmtChq p
        where
            p.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}



proc go_pmt_CC {pmt_id} {

	global DB

	set sql [subst {
		select
			c.ref_no,
			c.gw_auth_code,
			c.gw_uid,
			c.gw_ret_code,
			c.cvv2_resp,
			c.gw_acq_bank,
			c.enrol_3d_resp,
			c.auth_3d_resp,
			c.gw_ret_msg,
			c.extra_info,
			decode (c.auth_type, 'Y', '3DS Enrolled',
			                     'N', '3DS Not Enrolled',
			                     'No 3DS Verification') auth_type,
			case when
				c.fulfilled_at is null
			then 'N'
			else 'Y'
			end as fulfilled,
			h.desc as pg_host_desc,
			a.desc as pg_acct_desc,
			a.pg_type,
			c.chargeback,
			c.defended
		from
			tPmtCC c,
			outer tPmtGateHost h,
			outer tPmtGateAcct a
		where
			c.pg_acct_id = a.pg_acct_id and
			c.pg_host_id = h.pg_host_id and
			c.pmt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	tpSetVar pg_type [db_get_col $res 0 pg_type]

	if {[db_get_col $res 0 pg_type] == "COMMIDEA_ATH"} {
		set gw_uid_TID   {}
		set gw_uid_EFTSN {}

		set gw_uid_elems [split [db_get_col $res 0 gw_uid] ":"]

		if {[llength $gw_uid_elems] == 3} {
			set gw_uid_TID    [lindex $gw_uid_elems 1]
			set gw_uid_EFTSN  [lindex $gw_uid_elems 2]
		}

		tpBindString PMT_gw_uid_TID   $gw_uid_TID
		tpBindString PMT_gw_uid_EFTSN $gw_uid_EFTSN

	}

	if {[db_get_col $res 0 pg_type] == "COMMIDEA"} {
		# map the db stored code back to the response code from commidea, not
		# sure where the numeric code for commidea came from but they appear
		# made up, its probably because the gw_ret_code is a small int though

		switch -exact -- [db_get_col $res 0 gw_ret_code] {
			"0"     {set commidea_gw_ret_code "ERROR"}
			"1"     {set commidea_gw_ret_code "REFERRAL"}
			"2"     {set commidea_gw_ret_code "COMMSDOWN"}
			"3"     {set commidea_gw_ret_code "DECLINED"}
			"4"     {set commidea_gw_ret_code "REJECTED"}
			"5"     {set commidea_gw_ret_code "CHARGED"}
			"6"     {set commidea_gw_ret_code "AUTHORISED"}
			"7"     {set commidea_gw_ret_code "AUTHONLY"}
			default {set commidea_gw_ret_code "UNKNOWN"}
		}

		tpBindString PMT_commidea_gw_ret_code $commidea_gw_ret_code
	}


	tpSetVar Fulfilled [db_get_col $res 0 fulfilled]

	# Bind the information about if the transaction is a chargeback
	set defended [db_get_col $res 0 defended]

	switch -exact -- [db_get_col $res 0 defended] {
		"D"      {tpBindString defended_label "Defended"}
		"N"      {tpBindString defended_label "Not Defended"}
		"U" -
		default  {tpBindString defended_label "Unset"}
	}

	tpBindString defended $defended

	if {[db_get_col $res 0 chargeback] == "Y"} {
		tpSetVar isChargeback 1
	}

	db_close $res
}


proc go_pmt_PB {pmt_id} {

    global DB

    set sql [subst {
        select
            c.ref_no,
            c.gw_auth_code,
            c.gw_uid,
            c.gw_ret_code,
            c.gw_ret_msg,
            c.extra_info
        from
            tPmtPB c
        where
            c.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_BASC {pmt_id} {

    global DB

    set sql [subst {
        select
            c.desc,
            c.ext_ref
        from
            tPmtBasic c
        where
            c.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_EP {pmt_id} {

    global DB

    set sql {
        select
            e.trade_id,
            e.ref_no,
            e.ext_id,
            e.van_from,
            e.van_to,
            e.ext_amount,
            e.ccy_code,
            e.trade_desc,
            e.trans_time,
            e.trade_type,
            e.exch_to_gbp,
            e.exch_frm_gbp
        from
            tPmtEP e
        where
            e.pmt_id = ?
    }

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_BANK {pmt_id} {

    global DB

    set sql [subst {
        select
            p.code,
            p.extra_info
        from
            tPmtBank p
        where
            p.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_WU {pmt_id} {

    global DB

    set sql [subst {
        select
            p.mtcn,
            p.req_location,
            p.extra_info
        from
            tPmtWU p
        where
            p.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_GDEP {pmt_id} {

    global DB

    set sql [subst {
        select
            p.blurb,
            p.pay_type,
            p.extra_info
        from
            tPmtGdep p
        where
            p.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_GWTD {pmt_id} {

	global DB

	set sql [subst {
		select
			p.blurb,
			p.pay_type,
			p.extra_info
		from
			tPmtGwtd p
		where
			p.pmt_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

proc go_pmt_NTLR {pmt_id} {

    global DB

    set sql {
        select
            p.gw_uid
        from
            tPmtNeteller p
        where
            p.pmt_id = ?
    }

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_ENET {pmt_id} {

    global DB

    set sql {
        select
            gw_uid,
			gw_pmt_id,
			ext_ord_status,
			gw_ret_msg
        from
            tPmteNETS p
        where
            p.pmt_id = ?
    }

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

proc go_pmt_MB {pmt_id} {

	global DB

	set sql {
		select
			p.sid,
			p.mb_transaction_id,
			p.mb_status,
			p.pg_acct_id,
			mb.desc as mb_payment_type
		from
			tPmtMB p,
			outer tExtSubPayMthd mb
		where
			p.pmt_id = ?
			and p.payment_type = mb.sub_type_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

#
# Bind the relevent detail for ENVOY
#
proc go_pmt_ENVO {pmt_id} {

	global DB

	set sql {
		select
			p.epacs_ref      envoy_epac_ref,
			p.pg_acct_id,
			p.pg_host_id,
			sb.desc as       envoy_payment_type
		from
			tPmtEnvoy        p,
			outer (
				tExtSubCPMLink   sl,
				tExtSubPayMthd   sb
				)
		where
			p.pmt_id           = ?
		and p.ext_sub_link_id  = sl.ext_sub_link_id
		and sl.sub_type_code   = sb.sub_type_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

proc go_pmt_C2P {pmt_id} {

	global DB

	set sql {
		select
			c.ref_no,
			c.gw_auth_code,
			c.gw_uid,
			c.gw_ret_code,
			c.gw_ret_msg,
			c.extra_info,
			h.desc as pg_host_desc,
			a.desc as pg_acct_desc
		from
			tPmtC2P c,
			outer tPmtGateHost h,
			outer tPmtGateAcct a
		where
			c.pg_acct_id = a.pg_acct_id and
			c.pg_host_id = h.pg_host_id and
			c.pmt_id = ?

	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}



#
#  go_pmt_PPAL
#
#  pmt_id - The ID of the PayPal payment to obtain information for
#
proc go_pmt_PPAL {pmt_id} {
	global DB

	set sql {
		select
			pp_inv_num,
			pp_txn_id,
			extra_info as pp_extra_info,
			pp_case_id,
			pp_case_info,
			cr_date
		from
			tPmtPayPal p
		where
			p.pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

#
#  go_pmt_SHOP
#
#  pmt_id - The ID of the Shop payment to obtain information for
#
proc go_pmt_SHOP {pmt_id} {

    global DB

    set sql [subst {
        select
            s.shop_no,
            s.shop_name,
            p.shop_pmt_type,
            p.ticket_num,
            p.staff_member
        from
            tPmtShop p,
            tRetailShop s
        where
            p.shop_id = s.shop_id
        and
            p.pmt_id = ?
    }]

    set stmt [inf_prep_sql $DB $sql]
    set res  [inf_exec_stmt $stmt $pmt_id]
    inf_close_stmt $stmt

    foreach f [db_get_colnames $res] {
        tpBindString PMT_${f} [db_get_col $res 0 $f]
    }

    db_close $res
}

#  Wrapper function to det details of Quickcash payment
#
proc go_pmt_UKSH { pmt_id } {
	_go_pmt_ukash $pmt_id
}

#  Wrapper function to det details of Ukash International payment
#
proc go_pmt_IKSH { pmt_id } {
	_go_pmt_ukash $pmt_id
}

#  go_pmt_UKSH
#
#  pmt_id - The pmt_id for the Quickcash payment
#
# Helper function as UKSH and IKSH use same DB table
#
proc _go_pmt_ukash { pmt_id } {
	global DB

	set sql {
		select
			u.cr_date,
			u.enc_voucher,
			u.txn_id,
			u.err_code,
			u.expiry,
			u.value,
			u.prod_code
		from
			tPmtUkash u
		where
			u.pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	set voucher [ob_ukash::decrypt_voucher [db_get_col $res 0 enc_voucher]]
	if {![op_allowed ShowFullUKashNr]} {
		set disp ""
		append disp [string range $voucher 0 8]
		append disp "XXXXXX"
		append disp [string range $voucher 15 end]
		set voucher $disp
	}

	tpBindString PMT_voucher $voucher

	foreach f {
		cr_date
		enc_voucher
		expiry
		txn_id
		err_code
		prod_code
	} {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	tpBindString PMT_err_desc [ob_ukash::err_desc [db_get_col $res 0 err_code]]

	db_close $res
}

#
#  go_pmt_CB
#
#  pmt_id - The ID of the Click and Buy payment we're looking
#           to get info for
#
proc go_pmt_CB {pmt_id} {
	global DB

	set sql {
		select
			cb_bdr_id,
			extra_info
		from
			tPmtClickAndBuy
		where
			pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	foreach f [db_get_colnames $res] {
		tpBindString PMT_${f} [db_get_col $res 0 $f]
	}

	db_close $res
}

#
#  go_pmt_PSC
#
#  pmt_id - The ID of the Pay Safe Card payment we're looking
#           to get info for
#
proc go_pmt_PSC {pmt_id} {

	global DB
	global PSC_SERIALS

	catch {unset PSC_SERIALS}

	set sql {
		select
			psc_serial,
			psc_value
        	from
        		tPSCInfo
        	where
        		pmt_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $pmt_id]
	inf_close_stmt $stmt

	set      num_serials [db_get_nrows $res]
	tpSetVar NumSerials  $num_serials

	for {set i 0} {$i < $num_serials} {incr i} {
		set PSC_SERIALS($i,psc_serial) [db_get_col $res $i psc_serial]
		set PSC_SERIALS($i,psc_value)  [db_get_col $res $i psc_value ]
	}

	ob::log::write_array INFO PSC_SERIALS

	tpBindVar psc_serial PSC_SERIALS psc_serial psc_idx
	tpBindVar psc_value  PSC_SERIALS psc_value  psc_idx

	db_close $res
	
	
	set sql2 {
		select
			p.state,
			p.errcode,
			p.errmessage,
			h.desc as pg_host_desc,
			a.desc as pg_acct_desc
		from
			tPmtPSC p,
			outer tPmtGateHost h,
			outer tPmtGateAcct a
		where
			p.pg_acct_id = a.pg_acct_id and
			p.pg_host_id = h.pg_host_id and
			p.pmt_id = ?

	}

	set stmt2 [inf_prep_sql $DB $sql2]
	set res2  [inf_exec_stmt $stmt2 $pmt_id]
	inf_close_stmt $stmt2

	foreach f [db_get_colnames $res2] {
		tpBindString PMT_${f} [db_get_col $res2 0 $f]
	}

	db_close $res2
}

}
