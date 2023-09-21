# ==============================================================
# $Id: paymthd.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::GoPmtScheme [namespace code go_pay_mthd_list]

asSetAct ADMIN::PMT::go_pay_mthd      [namespace code go_pay_mthd]
asSetAct ADMIN::PMT::upd_pay_mthd     [namespace code upd_pay_mthd]



#
# ----------------------------------------------------------------------
# generate the master payment method list
# ----------------------------------------------------------------------
#
proc go_pay_mthd_list {} {

	global PAYMTHD DB

	if {[info exists PAYMTHD]} {
		unset PAYMTHD
	}

	# Add check to ensure that if FUNC_BASIC_PAY is set to 1, the Basic Pay option does not appear
	set where ""
	if {[OT_CfgGet FUNC_BASIC_PAY 0] != 1} {
		set where "where pay_mthd != \"BASC\""
	}

	set sql [subst {
		select
			pay_mthd,
			desc,
			blurb,
			wtd_delay_mins,
			wtd_delay_threshold
		from
			tPayMthd
		$where
		order by
			desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	foreach c [db_get_colnames $rs] {
		for {set i 0} {$i < $nrows} {incr i} {
			set PAYMTHD($i,$c)   [db_get_col $rs $i $c]
		}
		tpBindVar $c PAYMTHD $c paymthd_idx
	}
	db_close $rs
	tpSetVar nrows $nrows

	asPlayFile -nocache "pmt/paymthd_list.html"
}


#
# ----------------------------------------------------------------------
# Go to details of a specific payment method
# ----------------------------------------------------------------------
#
proc go_pay_mthd {} {

	global PAYMTHD DB

	if {[reqGetArg SubmitName] == "Back"} {
		go_pay_mthd_list
		return
	}

	set pay_mthd [reqGetArg pay_mthd]

	if {[info exists PAYMTHD]} {
		unset PAYMTHD
	}

	set sql {
		select
			pay_mthd,
			desc,
			blurb,
			wtd_delay_mins,
			wtd_delay_threshold
		from
			tPayMthd
		where
			pay_mthd = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt [reqGetArg pay_mthd]]
	inf_close_stmt $stmt

	foreach c [db_get_colnames $rs] {
		tpBindString $c [db_get_col $rs $c]
	}

	db_close $rs

	asPlayFile -nocache "pmt/paymthd.html"
}


#
# ----------------------------------------------------------------------
# Update details of a specific payment method
# ----------------------------------------------------------------------
#
proc upd_pay_mthd {} {

	global DB

	set sql [subst {
		update tPayMthd set
			desc = ?,
			blurb = ?,
			wtd_delay_mins = ?,
			wtd_delay_threshold = ?
		where
			pay_mthd = ?
	}]

	set c [catch {
		set stmt [inf_prep_sql $DB $sql]

		set rs [inf_exec_stmt $stmt\
			[reqGetArg desc]\
			[reqGetArg blurb]\
			[reqGetArg wtd_delay_mins]\
			[reqGetArg wtd_delay_threshold]\
			[reqGetArg pay_mthd]]

		inf_close_stmt $stmt

		db_close $rs

	} msg]

	if {$c} {
		err_bind "Could not update payment method: $msg"
	} else {
		msg_bind "Payment method updated"
	}

	go_pay_mthd
}


proc bind_mthds args {

	global DB PAYMTHD

	# Add check to ensure that if FUNC_BASIC_PAY is set to 1, the Basic Pay option does not appear
	set where ""
	if {[OT_CfgGet FUNC_BASIC_PAY 0] != 1} {
		set where "where pay_mthd != \"BASC\""
	}

	set sql [subst {
		select
			pay_mthd,
			desc
		from
			tPayMthd
		$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows  [db_get_nrows $res]
	set allowed_to_add 0

	array set PAYMTHDS [list]

	for {set r 0} {$r < $nrows} {incr r} {

		set mthd                      [db_get_col $res $r pay_mthd]
		if {[op_allowed "Add${mthd}"]} {
			incr allowed_to_add
		}
		set PAYMTHD($r,pay_mthd)      $mthd
		if {$mthd == "BASC" && [OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
			set PAYMTHD($r,pay_mthd_desc) "MCA"
		} else {
			set PAYMTHD($r,pay_mthd_desc) [db_get_col $res $r desc]
		}

	}

	tpSetVar NumPayMthds $nrows
	tpSetVar AllowedToAddPayMthds $allowed_to_add

	tpBindVar pay_mthd      PAYMTHD pay_mthd      pm_idx
	tpBindVar pay_mthd_desc PAYMTHD pay_mthd_desc pm_idx

	db_close $res
}

#
# Add new payment method
#
proc go_pay_mthd_add args {

	global DB ACC TEMPLATES

	OT_LogWrite 5 "==> go_pay_mthd_add"

	set method      [reqGetArg pay_mthd]

	if {![op_allowed AddPayMethod] && ![op_allowed "Add${method}"]} {
		err_bind "You do not have permission to add payment methods"
		go_auth_qry
		return
	}

	set where [list]

	if {[string length [set name [reqGetArg Username]]] > 0} {

		if {[OT_CfgGet FUNC_DEF_CASE_INS_SEARCH 0]} {
			lappend where "c.username_uc = '[string toupper $name]'"
		} else {
			lappend where "c.username = '$name'"
		}
	}

	if {[string length [set acctno [acct_no_dec [reqGetArg AcctNo]]]] > 0} {
		lappend where "c.acct_no = '$acctno'"
	}

	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where "r.email = '$email'"
	}

	#
	# Don't allow a query with no filters
	#

	if {$name == "" && $acctno == ""} {
		if {[reqGetArg pay_mthd] != "CB" || $email == ""} {
			OT_LogWrite 5 "no search criteria supplied"
			err_bind "no search criteria supplied"
			tpSetVar Error 1
			go_auth_qry
			return
		}
	}


	set where " [join $where { and }]"

	set sql [subst {
		select
		 c.cust_id,
		 c.status,
		 c.elite,
		 a.settle_type,
		 a.ccy_code,
		 a.acct_type,
		 r.mobile,
		 c.country_code
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r
		where
			c.cust_id = a.cust_id and
			r.cust_id = c.cust_id and
			a.owner   <> 'D' and
		$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] > 0} {
		if {[db_get_col $res 0 elite] == "Y" && ![op_allowed EliteCustAccess]} {
			err_bind "You do not have permission to add payment methods to Elite Customers"
			go_auth_qry
			return
		}
		set cust_id     [db_get_col $res 0 cust_id]
		set settle_type [db_get_col $res 0 settle_type]
		set acct_type   [db_get_col $res 0 acct_type]
	} else {
		if {$name ==""} {
			set error "acct no [reqGetArg AcctNo]"
		} elseif {$acctno == ""} {
			set error "$name"
		} else {
			set error "$name, acct no [reqGetArg AcctNo]"
		}
		err_bind "Customer details not found for $error"
		go_auth_qry
		return
	}
	if {[db_get_col $res 0 status]=="S"} {
		if {$name ==""} {
			set error "acct no $acctno"
		} elseif {$acctno == ""} {
			set error "$name"
		} else {
			set error "$name, acct no $acctno"
		}
		err_bind "Customer account is suspended for $error"
		go_auth_qry
		return
	}

	#
	# play template according to payment sort, and method
	#
	set ccy_code    [db_get_col $res 0 ccy_code]
	set paybox_ccys [OT_CfgGet PAYBOX_CCY_CODES ""]
	set ccy_list    [list $paybox_ccys]
	set country	[db_get_col $res 0 country_code]
    	if {$country == "UK"} {
    		set country "GB"
    	}

	if {$method == "PB" && [lsearch -exact $paybox_ccys $ccy_code] == -1} {
		# Paybox transactions not allowed in this currency
		err_bind "Paybox method not allowed for this currency"
		go_auth_qry
		return
	 }

	if {$method == "NTLR" && [lsearch -exact [OT_CfgGet NETELLER_CCYS {}] $ccy_code] == -1} {
		# Neteller transactions not allowed in this currency
		err_bind "Neteller method not allowed for this currency"
		go_auth_qry
		return
	}


	if {$method == "CB" && [lsearch -exact [OT_CfgGet CLICKANDBUY_CCYS {}]  $ccy_code] == -1} {
		# Clickandbuy transactions not allowed in this currency
		err_bind "Clickandbuy method not allowed for this currency"
		go_auth_qry
		return
	}


	if {$method == "C2P" && [lsearch -exact [OT_CfgGet CLICK2PAY_CCYS {}] $ccy_code] == -1} {
		# Click2pay transactions not allowed in this currency
		err_bind "Click2Pay method not allowed for this currency"
		go_auth_qry
		return
	}

	if {$method == "EP"} {

		# Get earthport account countries
	    set stmt [inf_prep_sql $DB {
			select distinct
				c.country_name,
				e.country
			from
				tcountry c,
				tearthportaccount e
			where
				(c.country_code = e.country or
				(e.country = "GB" and
				c.country_code ="UK"))
		}]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
		set nrows [db_get_nrows $rs]
		set ACC(nrows) $nrows
		set other 1
		for {set i 0} {$i < $nrows} {incr i} {
			set ACC($i,country)		[db_get_col $rs $i country_name]
			set ACC($i,cntry_code)	[db_get_col $rs $i country]
			if {$ACC($i,cntry_code) == $country} {
				set ACC($i,checked) 1
				set other 0
			} else {
				set ACC($i,checked) 0
			}
		}
		db_close $rs
		tpBindVar country 		ACC country 	idx
		tpBindVar cntry_code		ACC cntry_code 	idx
		tpBindVar checked 		ACC checked 	idx
		tpSetVar other 			$other
	}

	if {$method == "BASC"} {
		global Basic_Agent

		ADMIN::PMT::get_basc_agents

		tpBindVar agent_id                 Basic_Agent agent_id   idx
		tpBindVar agent_name               Basic_Agent agent_name idx

		# Call it MCA not Basic Pay if it's Ladbrokes
		if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
			tpBindString Desc "MCA"
		} else {
			tpBindString Desc "Basic Pay"
		}
	}

	if {$method == "BANK"} {
		if {[OT_CfgGet FUNC_USE_BANK_TEMPLATES 0]} {
			# Binds info to allow bank template to validate the form
			set sql {
				select
					bank_template,
					country_code,
					disporder
				from
					tCountry
				where
					status = 'A'
				order by
					disporder
			}

			set stmt [inf_prep_sql $DB $sql]
			set res_ccode [inf_exec_stmt $stmt]
			inf_close_stmt $stmt

			# Pull info from config file
			array unset BANK_TEMPLATES
			payment_BANK::get_templates BANK_TEMPLATES
			# BANK_TEMPLATES now relates bank templates to required fields

			for {set i 0} {$i < [db_get_nrows $res_ccode]} {incr i} {
				# for each country
				set country_code [db_get_col $res_ccode $i country_code]
				set id           [db_get_col $res_ccode $i bank_template]

				set TEMPLATES($i,country_code)  $country_code

				set j 0
				foreach field $BANK_TEMPLATES($id,req_fields) {
					set TEMPLATES($i,$j,req_fields) $field
					set TEMPLATES($i,$j,regex)      $BANK_TEMPLATES($id,$field,regex)
					incr j
				}
			}
			db_close $res_ccode

			tpSetVar UseBankTemplates 1
			tpSetVar  num_countries     $i
			tpSetVar  num_req_fields    $j
			tpBindVar country_code   TEMPLATES country_code   country_idx
			tpBindVar req_fields     TEMPLATES req_fields     country_idx field_idx
			tpBindVar regex          TEMPLATES regex          country_idx field_idx
		} else {
			tpSetVar UseBankTemplates 0
		}
	}

	if {($method == "BANK" || $method == "CHQ") && $acct_type == "DEP"} {

		set sql {
			select
				pay_mthd
			from
				tCustPayMthd
			where
				cust_id = ?
				and pay_mthd in ('BANK', 'CHQ')
				and status = 'A'
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $rs] > 0} {
			err_bind "A withdrawal-only method already exists for this customer."
			db_close $rs
			go_auth_qry
			return
		}

		db_close $rs
	}


	set mobile [db_get_col $res 0 mobile]


	#
	# allow bind_cust_detail to pick up the customer id
	#
	tpSetVar        CustId $cust_id
	tpBindString    CustId $cust_id

	tpBindString    Username $name
	tpBindString    AcctNo $acctno
	tpBindString    Email $email
	tpBindString    SettleType $settle_type
	tpBindString    AcctType $acct_type
	tpBindString    MobileNumber $mobile
	tpBindString    CcyCode $ccy_code
	tpBindString	Country $country
	tpSetVar	Country $country

	# Back action because coming from multiple pages.
	tpBindString backAction [reqGetArg backAction]

	OT_LogWrite 5 "username: $name"
	OT_LogWrite 5 "CustId: $cust_id"
	OT_LogWrite 5 "Email: $email"
	OT_LogWrite 5 "acctno: $acctno"
	OT_LogWrite 5 "method: $method"
	OT_LogWrite 5 "settle_type :$settle_type"
	OT_LogWrite 5 "acct_type :$acct_type"

	if {[lsearch -exact {CC CHQ BANK GDEP GWTD CSH PB EP BC NTLR BASC WU ENET MB C2P SHOP CB BARC UKSH IKSH} $method] == -1} {

		err_bind "Payment method ($method) cannot be added via back office"
		go_auth_qry
		return
	}


	# Check cust can register
	set result [payment_multi::get_mthd_can_register $cust_id $method]

	if {[lindex $result 0]} {
		if {![lindex $result 1]} {
			if {[CPMRules::check_cust_needs_wtd_mthd $cust_id] && \
				($method == "CHQ" || $method == "BANK")} {
				OT_LogWrite 5 "==> go_pay_mthd_add allowing $method registration as withdrawal method reqd"
			} else {
				err_bind "Payment method ($method) cannot be added for this customer"
				if {[reqGetArg backAction] == "CUST"} {
					reqSetArg CustId $cust_id
					ADMIN::CUST::go_cust
				} else {
					go_auth_qry
				}
				return
			}
		}
	} else {
		err_bind "Error getting list of available payment methods"
		go_auth_qry
		return
	}

	asPlayFile -nocache "pmt/pmt_reg_${method}.html"
}


proc rebind_request_data {} {
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		tpBindString [reqGetNthName $i] [reqGetNthVal $i]
	}
}

# close namespace
}
