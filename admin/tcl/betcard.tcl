# ==============================================================
# $Id: betcard.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BETCARD {

	asSetAct ADMIN::BETCARD::GoVendorQuery        	[namespace code go_vendor_query]
	asSetAct ADMIN::BETCARD::DoVendorQuery        	[namespace code do_vendor_query]
	asSetAct ADMIN::BETCARD::DoVendorReg        	[namespace code do_vendor_reg]
	asSetAct ADMIN::BETCARD::GoVendor        		[namespace code go_vendor]
	asSetAct ADMIN::BETCARD::DoVendor        		[namespace code do_vendor]
	asSetAct ADMIN::BETCARD::DoPayment				[namespace code do_payment]
	asSetAct ADMIN::BETCARD::GoReconcilePayment		[namespace code go_reconcile_payment]
	asSetAct ADMIN::BETCARD::DoReconcilePayment		[namespace code do_reconcile_payment]
	asSetAct ADMIN::BETCARD::DoVendorCusts			[namespace code do_vendors_customers]
	asSetAct ADMIN::BETCARD::DoBetcard				[namespace code do_betcard]
	asSetAct ADMIN::BETCARD::GoSuspendBetcard		[namespace code go_suspend_betcard]
	asSetAct ADMIN::BETCARD::DoSuspendBetcard		[namespace code do_suspend_betcard]

}

proc ADMIN::BETCARD::go_vendor_query args {

	global DB

	#
	# Pre-load currency and country code/name pairs
	#
	set stmt [inf_prep_sql $DB {
		select ccy_code,ccy_name,disporder
		from tccy
		order by disporder
	}]
	set res_ccy [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCCYs [db_get_nrows $res_ccy]

	tpBindTcl CCYCode sb_res_data $res_ccy ccy_idx ccy_code
	tpBindTcl CCYName sb_res_data $res_ccy ccy_idx ccy_name

	set stmt [inf_prep_sql $DB {
		select country_code,country_name,disporder
		from tcountry
		order by disporder, country_name, country_code
	}]
	set res_cntry [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCNTRYs [db_get_nrows $res_cntry]

	tpBindTcl CNTRYCode sb_res_data $res_cntry cntry_idx country_code
	tpBindTcl CNTRYName sb_res_data $res_cntry cntry_idx country_name


	asPlayFile -nocache betcard/vendor_query.html

	db_close $res_ccy
	db_close $res_cntry
}

proc ADMIN::BETCARD::do_vendor_query args {
	global DB

	set action [reqGetArg SubmitName]

	if {$action == "AddVendor"} {
		go_vendor_reg
		return
	}

	set where [list]

	if {[string length [set name [reqGetArg Username]]] > 0} {
		if {[reqGetArg ExactName] == "Y"} {
			set op =
		} else {
			set op like
			append name %
		}

		lappend where "v.vendor_uname $op \"${name}\""
	}

	if {[string length [set vendor_name [reqGetArg VendorName]]] > 0} {
		lappend where "v.vendor_name = '$vendor_name'"
	}

	if {[string length [set fname [reqGetArg FName]]] > 0} {
		set fname [string map {' ''} $fname]
		lappend where "UPPER(v.f_name) = [string toupper '$fname']"
	}

	if {[string length [set lname [reqGetArg LName]]] > 0} {
		set lname [string map {' ''} $lname]
		lappend where "UPPER(v.l_name) = [string toupper '$lname']"
	}

	if {[string length [set address1 [reqGetArg Address1]]] > 0} {
		lappend where "UPPER(v.addr_street_1) like [string toupper '$%{address1}%']"
	}

	if {[string length [set address2 [reqGetArg Address2]]] > 0} {
		lappend where "UPPER(v.addr_street_2) like [string toupper '$%{address2}%']"
	}

	if {[string length [set address3 [reqGetArg Address3]]] > 0} {
		lappend where "UPPER(v.addr_street_3) like [string toupper '$%{address3}%']"
	}

	if {[string length [set address4 [reqGetArg Address4]]] > 0} {
		lappend where "UPPER(v.addr_street_4) like [string toupper '%${address4}%']"
	}

	if {[string length [set postcode [reqGetArg Postcode]]] > 0} {
		lappend where "UPPER(v.addr_postcode) like [string toupper '%${postcode}%']"
	}

	if {[string length [set telephone [reqGetArg Telephone]]] > 0} {
		lappend where "v.telephone = '$telephone'"
	}

	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where "UPPER(v.email) like [string toupper '%${email}%']"
	}

	if {[string length [set ccy_code [reqGetArg CCYCode]]] > 0} {
		lappend where "v.ccy_code = '$ccy_code'"
	}

	if {[string length [set cntry_code [reqGetArg CNTRYCode]]] > 0} {
		lappend where "v.addr_country = '$cntry_code'"
	}

	if {[llength $where] > 0} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			v.vendor_id,
			v.vendor_acct_no,
			v.vendor_uname,
			v.password,
			v.vendor_name,
			v.status,
			v.l_name,
			v.f_name,
			v.addr_street_1,
			v.addr_street_2,
			v.addr_street_3,
			v.addr_street_4,
			v.addr_postcode,
			cntry.country_name,
			v.telephone,
			v.email,
			ccy.ccy_name,
			v.withdrawal_balance,
			v.deposit_balance,
			v.commission_rate,
			v.betcard_min_amt,
			v.betcard_amt_incr,
			v.lad_wtd_min
		from
			tBetcardVendor v ,
			tCCY ccy,
			tCountry cntry
		where
			v.ccy_code = ccy.ccy_code
		and
			v.addr_country = cntry.country_code
			$where
	}]

	ob::log::write DEBUG {SEARCH SQL: $sql}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumVendors [set NumVendors [db_get_nrows $res]]

	tpBindTcl V_vendor_id 			sb_res_data $res vendor_idx vendor_id
	tpBindTcl V_vendor_acct_no 		sb_res_data $res vendor_idx vendor_acct_no
	tpBindTcl V_vendor_uname		sb_res_data $res vendor_idx vendor_uname
	tpBindTcl V_password			sb_res_data $res vendor_idx password
	tpBindTcl V_vendor_name			sb_res_data $res vendor_idx vendor_name
	tpBindTcl V_status				sb_res_data $res vendor_idx status
	tpBindTcl V_l_name				sb_res_data $res vendor_idx l_name
	tpBindTcl V_f_name				sb_res_data $res vendor_idx f_name
	tpBindTcl V_addr_street_1		sb_res_data $res vendor_idx addr_street_1
	tpBindTcl V_addr_street_2		sb_res_data $res vendor_idx addr_street_2
	tpBindTcl V_addr_street_3		sb_res_data $res vendor_idx addr_street_3
	tpBindTcl V_addr_street_4		sb_res_data $res vendor_idx addr_street_4
	tpBindTcl V_addr_postcode		sb_res_data $res vendor_idx addr_postcode
	tpBindTcl V_country_name 		sb_res_data $res vendor_idx country_name
	tpBindTcl V_telephone 			sb_res_data $res vendor_idx telephone
	tpBindTcl V_email 				sb_res_data $res vendor_idx email
	tpBindTcl V_ccy_name 			sb_res_data $res vendor_idx ccy_name
	tpBindTcl V_withdrawal_balance 	sb_res_data $res vendor_idx withdrawal_balance
	tpBindTcl V_deposit_balance 	sb_res_data $res vendor_idx deposit_balance
	tpBindTcl V_commission_rate 	sb_res_data $res vendor_idx commission_rate
	tpBindTcl V_betcard_min_amt 	sb_res_data $res vendor_idx betcard_min_amt
	tpBindTcl V_betcard_amt_incr 	sb_res_data $res vendor_idx betcard_amt_incr
	tpBindTcl V_lad_wtd_min			sb_res_data $res vendor_idx lad_wtd_min

	asPlayFile -nocache betcard/vendor_list.html

	db_close $res
}

proc ADMIN::BETCARD::go_vendor_reg args {

	set vendor_id [reqGetArg vendor_id]

	if {$vendor_id == ""} {
		ob::log::write DEBUG {New vendor}
		go_vendor_reg_new
	} else {
		go_vendor_reg_upd
	}
}

proc ADMIN::BETCARD::go_vendor_reg_new args {
	global DB

	#
	# Pre-load currency and country code/name pairs
	#
	set stmt [inf_prep_sql $DB {
		select ccy_code,ccy_name,disporder
		from tccy
		order by disporder
	}]
	set res_ccy [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCCYs [db_get_nrows $res_ccy]

	tpBindTcl CCYCode sb_res_data $res_ccy ccy_idx ccy_code
	tpBindTcl CCYName sb_res_data $res_ccy ccy_idx ccy_name

	set stmt [inf_prep_sql $DB {
		select country_code,country_name,disporder
		from tcountry
		order by disporder, country_name, country_code
	}]
	set res_cntry [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCNTRYs [db_get_nrows $res_cntry]

	tpBindTcl CNTRYCode sb_res_data $res_cntry cntry_idx country_code
	tpBindTcl CNTRYName sb_res_data $res_cntry cntry_idx country_name
	tpSetVar NewVendor 1

	asPlayFile -nocache betcard/vendor_reg.html

	db_close $res_ccy
	db_close $res_cntry
}

proc ADMIN::BETCARD::go_vendor_reg_upd args {

	global DB COUNTRIES

	if {[info exists COUNTRIES]} {
		unset COUNTRIES
	}

	set vendor_id [reqGetArg vendor_id]

	tpSetVar NewVendor 0

	set res [OB::BETCARD::get_vendor $vendor_id]

	OB::BETCARD::bind_vendor $res

	set country [db_get_col $res 0  addr_country]

	db_close $res

	set stmt [inf_prep_sql $DB {
		select country_code,country_name,disporder
		from tcountry
		order by disporder, country_name, country_code
	}]
	set res_cntry [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_countries [db_get_nrows $res_cntry]

	for {set r 0} {$r < $num_countries} {incr r} {
		set COUNTRIES($r,country_code)	[db_get_col $res_cntry $r  country_code]
		set COUNTRIES($r,country_name)	[db_get_col $res_cntry $r  country_name]
		if {$COUNTRIES($r,country_code) ==  $country} {
			set COUNTRIES($r,selected) "selected"
		} else {
			set COUNTRIES($r,selected) ""
		}
	}

	db_close $res_cntry

	tpSetVar  NumCNTRYs $num_countries
	tpBindVar CNTRYCode		COUNTRIES country_code	cntry_idx
	tpBindVar CNTRYName		COUNTRIES country_name	cntry_idx
	tpBindVar CountrySel	COUNTRIES selected		cntry_idx

	asPlayFile -nocache betcard/vendor_reg.html
}

proc ADMIN::BETCARD::do_vendor_reg args {
	ob::log::write DEBUG {do_vendor_reg}

	set vendor_id [reqGetArg vendor_id]

	if {$vendor_id == ""} {
		ob::log::write DEBUG {New vendor}
		do_vendor_reg_new
	} else {
		if {[reqGetArg SubmitName] == "Back"} {
			ob::log::write DEBUG {Back button}
			go_vendor
			return
		}
		ob::log::write DEBUG {Update vendor}
		do_vendor_reg_upd
	}
}

proc ADMIN::BETCARD::do_vendor_reg_new args {

	global DB

	set pwd_1 [reqGetArg Password_1]
	set pwd_2 [reqGetArg Password_2]

	if {$pwd_1 != $pwd_2} {
		err_bind "Passwords don't match"

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_vendor_reg
		return
	}

	set username	[reqGetArg vendor_uname]
	set vendor_name	[reqGetArg vendor_name]
	set f_name 		[reqGetArg f_name]
	set l_name		[reqGetArg l_name]
	set addr_1		[reqGetArg addr_street_1]
	set addr_2		[reqGetArg addr_street_2]
	set addr_3		[reqGetArg addr_street_3]
	set addr_4		[reqGetArg addr_street_4]
	set postcode	[reqGetArg addr_postcode]
	set cntry		[reqGetArg CNTRYCode]
	set phone		[reqGetArg telephone]
	set email		[reqGetArg email]
	set commission	[reqGetArg commission_rate]
	set min_amount	[reqGetArg betcard_min_amt]
	set increment	[reqGetArg betcard_amt_incr]
	set min_wtd		[reqGetArg lad_wtd_min]
	set status		[reqGetArg status]
	set ccy			[reqGetArg CCYCode]

	set sql {
		execute procedure pInsVendor(
			p_vendor_uname = ?,
			p_password = ?,
			p_vendor_name = ?,
			p_f_name = ?,
			p_l_name = ?,
			p_addr_street_1 = ?,
			p_addr_street_2 = ?,
			p_addr_street_3 = ?,
			p_addr_street_4 = ?,
			p_addr_postcode = ?,
			p_addr_country = ?,
			p_telephone = ?,
			p_email = ?,
			p_commission_rate = ?,
			p_betcard_min_amt = ?,
			p_betcard_amt_incr = ?,
			p_lad_wtd_min = ?,
			p_status = ?,
			p_ccy_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt\
			$username \
			[md5 $pwd_1] \
			$vendor_name \
			$f_name \
			$l_name \
			$addr_1 \
			$addr_2 \
			$addr_3 \
			$addr_4 \
			$postcode \
			$cntry \
			$phone \
			$email \
			$commission \
			$min_amount \
			$increment \
			$min_wtd \
			$status \
			$ccy
		]
	} msg]

	if {$c == 0} {
		set vendor_id [db_get_coln $res 0 0]
		db_close $res
		go_vendor vendor_id $vendor_id

	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {Add failed: $msg}
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_vendor_reg
	}
}

proc ADMIN::BETCARD::do_vendor_reg_upd  args {

	global DB

	set vendor_id	[reqGetArg vendor_id]
	set vendor_name	[reqGetArg vendor_name]
	set f_name 		[reqGetArg f_name]
	set l_name		[reqGetArg l_name]
	set addr_1		[reqGetArg addr_street_1]
	set addr_2		[reqGetArg addr_street_2]
	set addr_3		[reqGetArg addr_street_3]
	set addr_4		[reqGetArg addr_street_4]
	set postcode	[reqGetArg addr_postcode]
	set cntry		[reqGetArg CNTRYCode]
	set phone		[reqGetArg telephone]
	set email		[reqGetArg email]
	set commission	[reqGetArg commission_rate]
	set min_amount	[reqGetArg betcard_min_amt]
	set increment	[reqGetArg betcard_amt_incr]
	set min_wtd		[reqGetArg lad_wtd_min]
	set status		[reqGetArg status]

	set sql {
		execute procedure pUpdVendor(
			p_vendor_id = ?,
			p_vendor_name = ?,
			p_f_name = ?,
			p_l_name = ?,
			p_addr_street_1 = ?,
			p_addr_street_2 = ?,
			p_addr_street_3 = ?,
			p_addr_street_4 = ?,
			p_addr_postcode = ?,
			p_addr_country = ?,
			p_telephone = ?,
			p_email = ?,
			p_commission_rate = ?,
			p_betcard_min_amt = ?,
			p_betcard_amt_incr = ?,
			p_lad_wtd_min = ?,
			p_status = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt\
			$vendor_id \
			$vendor_name \
			$f_name \
			$l_name \
			$addr_1 \
			$addr_2 \
			$addr_3 \
			$addr_4 \
			$postcode \
			$cntry \
			$phone \
			$email \
			$commission \
			$min_amount \
			$increment \
			$min_wtd \
			$status
		]
	} msg]

	if {$c == 0} {

		db_close $res
		go_vendor vendor_id $vendor_id

	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {Update failed: $msg}
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		if {$status == "S"} {
			tpSetVar VendorSuspended 1
		}

		go_vendor_reg
	}
}

proc ADMIN::BETCARD::go_vendor args {

	set vendor_id [reqGetArg vendor_id]

	foreach {n v} $args {
		set $n $v
	}

	set res [OB::BETCARD::get_vendor $vendor_id]

	OB::BETCARD::bind_vendor $res

	db_close $res

	asPlayFile -nocache betcard/vendor.html
}

proc ADMIN::BETCARD::do_vendor args {

	set submit [reqGetArg SubmitName]

	if {$submit == "UpdVendorReg"} {
		go_vendor_reg_upd
	} elseif {$submit == "Back"} {
		go_vendor_query
	}
}

proc ADMIN::BETCARD::do_payment args {
	set submit [reqGetArg SubmitName]

	if {$submit == "MakePayment"} {
		make_payment
	} elseif {$submit == "FindPayments"} {
		do_payment_query
	}
}

proc ADMIN::BETCARD::make_payment args {

	global DB

	set type 		[reqGetArg type]
	set amount 		[reqGetArg amount]
	set vendor_id 	[reqGetArg vendor_id]
	set reason 		[reqGetArg reason]

	set return_val [OB::BETCARD::make_payment $type $amount $vendor_id $reason]

	if {[lindex $return_val 0] == "err"} {
		err_bind [lindex $return_val 1]
	}

	go_vendor vendor_id $vendor_id
}

proc ADMIN::BETCARD::do_payment_query args {
	global DB

	set where [list]

	set vendor_id 	[reqGetArg vendor_id]

	set str_date 		[reqGetArg str_date]
	set end_date 		[reqGetArg end_date]

	if {[string length [set vendor_pmt_id [reqGetArg vendor_pmt_id]]] > 0} {
		lappend where "p.vendor_pmt_id = $vendor_pmt_id"
	}

	if {[string length [set status [reqGetArg status]]] > 0} {
		lappend where "p.status = '$status'"
	}

	if {[string length [set type [reqGetArg type]]] > 0} {
		lappend where "p.pmt_type = '$type'"
	}

	if {([string length $str_date] > 0) || ([string length $end_date] > 0)} {
		lappend where [mk_between_clause p.cr_date date $str_date $end_date]
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			p.vendor_pmt_id,
			v.vendor_uname,
			p.cr_date,
			p.status,
			p.pmt_type,
			p.amount,
			p.commission,
			p.completed_date,
			a1.username as completed_by_name,
			p.completed_by,
			p.rejected_date,
			a2.username as rejected_by_name,
			p.rejected_by,
			p.rejected_reason,
			p.adjustment_reason
		from
			tBetcardVendorPmt p,
			tBetcardVendor v,
			outer tAdminUser a1,
			outer tAdminUser a2
		where
			v.vendor_id = ?
		and
			v.vendor_id = p.vendor_id
		and
			p.completed_by = a1.user_id
		and
			p.rejected_by = a2.user_id
			$where
		order by cr_date asc
	}]

	ob::log::write DEBUG {SEARCH SQL: $sql}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $vendor_id]
	inf_close_stmt $stmt

	tpSetVar NumPayments [set NumPayments [db_get_nrows $res]]

	ob::log::write DEBUG {Payment count: $NumPayments}

	tpBindTcl	vendor_pmt_id		sb_res_data	$res	vendor_pmt_idx vendor_pmt_id
	tpBindTcl	vendor_uname		sb_res_data	$res	vendor_pmt_idx vendor_uname
	tpBindTcl	cr_date				sb_res_data	$res	vendor_pmt_idx cr_date
	tpBindTcl	status				sb_res_data	$res	vendor_pmt_idx status
	tpBindTcl	pmt_type			sb_res_data	$res	vendor_pmt_idx pmt_type
	tpBindTcl	amount				sb_res_data	$res	vendor_pmt_idx amount
	tpBindTcl	commission			sb_res_data	$res	vendor_pmt_idx commission
	tpBindTcl	completed_date		sb_res_data	$res	vendor_pmt_idx completed_date
	tpBindTcl	completed_by_name	sb_res_data	$res	vendor_pmt_idx completed_by_name
	tpBindTcl	completed_by		sb_res_data	$res	vendor_pmt_idx completed_by
	tpBindTcl	rejected_date		sb_res_data	$res	vendor_pmt_idx rejected_date
	tpBindTcl	rejected_by_name	sb_res_data	$res	vendor_pmt_idx rejected_by_name
	tpBindTcl	rejected_by			sb_res_data	$res	vendor_pmt_idx rejected_by
	tpBindTcl	rejected_reason		sb_res_data	$res	vendor_pmt_idx rejected_reason
	tpBindTcl	adjustment_reason	sb_res_data	$res	vendor_pmt_idx adjustment_reason

	asPlayFile -nocache betcard/vendor_payment_list.html

	db_close $res
}

proc ADMIN::BETCARD::go_reconcile_payment args {
	set vendor_pmt_id [reqGetArg vendor_pmt_id]

	tpBindString vendor_pmt_id $vendor_pmt_id

	asPlayFile -nocache betcard/vendor_reconcile_payment.html
}

proc ADMIN::BETCARD::do_reconcile_payment args {

	global DB USERID

	set vendor_pmt_id [reqGetArg vendor_pmt_id]
	set status [reqGetArg status]
	set reason [reqGetArg reason]

	set sql {
		execute procedure pRecVendorPmt(
			p_vendor_pmt_id = ?,
			p_status = ?,
			p_reason = ?,
			p_admin_user_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt\
			$vendor_pmt_id \
			$status \
			$reason \
			$USERID
		]
	} msg]

	if {$c == 0} {
		db_close $res
		ob::log::write DEBUG {Payment reconciled vendor_pmt_id: $vendor_pmt_id status: $status reason: $reason}
		tpSetVar reconcileResult "OK"
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {Payment failed to reconcile vendor_pmt_id: $vendor_pmt_id status: $status reason: $reason $msg}
	}

	tpSetVar reconcileDone "Y"

	asPlayFile -nocache betcard/vendor_reconcile_payment.html
}

proc ADMIN::BETCARD::do_vendors_customers args {
	global DB

	set vendor_id [reqGetArg vendor_id]

	set sql {
		select
			distinct c.cust_id,
			c.username,
			r.fname,
			r.lname,
			r.email
		from
			tBetcard cd,
			tCustomer c,
			tCustomerReg r
		where
			c.cust_id = r.cust_id
		and
			c.cust_id = cd.cust_id
		and
			cd.vendor_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $vendor_id]
	inf_close_stmt $stmt

	tpSetVar NumCusts [set NumCusts [db_get_nrows $res]]

	tpBindTcl	cust_id		sb_res_data	$res	cust_idx cust_id
	tpBindTcl	username	sb_res_data	$res	cust_idx username
	tpBindTcl	fname		sb_res_data	$res	cust_idx fname
	tpBindTcl	lname		sb_res_data	$res	cust_idx lname
	tpBindTcl	email		sb_res_data	$res	cust_idx email

	asPlayFile -nocache betcard/vendor_cust_list.html

	db_close $res
}

proc ADMIN::BETCARD::do_betcard args {
	set submit [reqGetArg SubmitName]

	if {$submit == "GenerateBetcards"} {
		do_generate_vendor_betcards
	} elseif {$submit == "FindBetcards"} {
		do_query_betcards
	}
}

proc ADMIN::BETCARD::do_generate_vendor_betcards args {

	global DB

	set amount [reqGetArg amount]
	set vendor_id [reqGetArg vendor_id]
	set count [reqGetArg count]

	for {set a 0} {$a < $count} {incr a} {
		set return_val [OB::BETCARD::generate_vendor_betcard $amount $vendor_id]

		if {[lindex $return_val 0] == "err"} {
			err_bind [lindex $return_val 1]
			break;
		}
	}

	go_vendor vendor_id $vendor_id
}

proc ADMIN::BETCARD::do_query_betcards args {
	global DB BETCARDS

	set str_date 		[reqGetArg str_date]
	set end_date 		[reqGetArg end_date]

	set where [list]

	if {([string length $str_date] > 0) || ([string length $end_date] > 0)} {
		lappend where [mk_between_clause c.cr_date date $str_date $end_date]
	}

	if {[string length [set vendor_id [reqGetArg vendor_id]]] > 0} {
		lappend where "c.vendor_id = $vendor_id"
	}

	if {[string length [set cust_id [reqGetArg cust_id]]] > 0} {
		lappend where "c.cust_id = $cust_id"
	}

	if {[string length [set betcard_id [reqGetArg betcard_id]]] > 0} {
		lappend where "c.betcard_id = $betcard_id"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			c.betcard_id,
			c.cr_date,
			c.betcard_no,
			c.vendor_id,
			vu.vendor_uname,
			c.cust_id,
			cu.username,
			c.betcard_sort,
			c.amount,
			c.status,
			c.redeemed_date,
			c.suspended_date,
			c.suspended_by,
			c.suspended_id,
			c.betcard_key,
			c.vendor_pmt_id,
			c.cust_pmt_id
		from
			tBetcard c,
			tBetcardVendor vu,
			outer tCustomer cu
		where
			c.cust_id = cu.cust_id
		and
			c.vendor_id = vu.vendor_id
			$where
		order by cr_date asc
	}]

	ob::log::write DEBUG {SEARCH SQL: $sql}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumBetcards [set NumBetcards [db_get_nrows $res]]

	for {set r 0} {$r < $NumBetcards} {incr r} {
		set BETCARDS($r,betcard_id)	[db_get_col $res $r betcard_id]
		set BETCARDS($r,cr_date)	[db_get_col $res $r cr_date]
		set BETCARDS($r,betcard_no)	[db_get_col $res $r betcard_no]
		set BETCARDS($r,vendor_id)	[db_get_col $res $r vendor_id]
		set BETCARDS($r,vendor_uname)	[db_get_col $res $r vendor_uname]
		set BETCARDS($r,cust_id)	[db_get_col $res $r cust_id]
		set BETCARDS($r,username)	[db_get_col $res $r username]
		set BETCARDS($r,betcard_sort)	[db_get_col $res $r betcard_sort]
		set BETCARDS($r,amount)	[db_get_col $res $r amount]
		set BETCARDS($r,status)	[db_get_col $res $r status]
		set BETCARDS($r,redeemed_date)	[db_get_col $res $r redeemed_date]
		set BETCARDS($r,suspended_date)	[db_get_col $res $r suspended_date]
		set BETCARDS($r,suspended_by)	[db_get_col $res $r suspended_by]
		set BETCARDS($r,suspended_id)	[db_get_col $res $r suspended_id]
		set BETCARDS($r,betcard_key)	[db_get_col $res $r betcard_key]

		set BETCARDS($r,vendor_pmt_id)	[db_get_col $res $r vendor_pmt_id]
		set BETCARDS($r,cust_pmt_id)	[db_get_col $res $r cust_pmt_id]

		set BETCARDS($r,betcard_no_enc) [OB::BETCARD::generate_betcard_number $BETCARDS($r,betcard_no) $BETCARDS($r,betcard_key)]
		ob::log::write DEBUG {$BETCARDS($r,betcard_no_enc)}
	}

	db_close $res

	tpBindVar betcard_id BETCARDS betcard_id betcards_idx
	tpBindVar cr_date BETCARDS cr_date betcards_idx
	tpBindVar betcard_no BETCARDS betcard_no betcards_idx
	tpBindVar vendor_id BETCARDS vendor_id betcards_idx
	tpBindVar vendor_uname BETCARDS vendor_uname betcards_idx

	tpBindVar cust_id BETCARDS cust_id betcards_idx
	tpBindVar username BETCARDS username betcards_idx
	tpBindVar betcard_sort BETCARDS betcard_sort betcards_idx
	tpBindVar amount BETCARDS amount betcards_idx
	tpBindVar status BETCARDS status betcards_idx

	tpBindVar redeemed_date BETCARDS redeemed_date betcards_idx
	tpBindVar suspended_date BETCARDS suspended_date betcards_idx
	tpBindVar suspended_by BETCARDS suspended_by betcards_idx
	tpBindVar suspended_id BETCARDS suspended_id betcards_idx
	tpBindVar betcard_key BETCARDS betcard_key betcards_idx

	tpBindVar vendor_pmt_id BETCARDS vendor_pmt_id betcards_idx
	tpBindVar cust_pmt_id BETCARDS cust_pmt_id betcards_idx

	tpBindVar betcard_no_enc BETCARDS betcard_no_enc betcards_idx

	asPlayFile -nocache betcard/vendor_betcard_list.html
}

proc ADMIN::BETCARD::go_suspend_betcard args {
	set betcard_id [reqGetArg betcard_id]

	tpBindString betcard_id $betcard_id

	asPlayFile -nocache betcard/vendor_suspend_betcard.html
}

proc ADMIN::BETCARD::do_suspend_betcard args {

	global DB USERID

	set betcard_id [reqGetArg betcard_id]
	set reason [reqGetArg reason]

	set sql {
		execute procedure pSuspendBetcard(
			p_betcard_id = ?,
			p_suspended_by = ?,
			p_suspended_id = ?,
			p_reason = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt	$stmt\
			$betcard_id \
			"A" \
			$USERID \
			$reason \
		]
	} msg]

	if {$c == 0} {
		db_close $res
		ob::log::write DEBUG {Betcard rejected betcard_id: $betcard_id reason: $reason}
		tpSetVar suspensionResult "OK"
	} else {
		err_bind $msg
		catch {db_close $res}
		ob::log::write ERROR {Betcard rejection failed betcard_id: $betcard_id reason: $reason $msg}
	}

	tpSetVar suspensionDone "Y"

	asPlayFile -nocache betcard/vendor_suspend_betcard.html
}
