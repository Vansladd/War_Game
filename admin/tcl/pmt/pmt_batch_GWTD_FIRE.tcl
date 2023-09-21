# ==============================================================
# $Header: /cvsroot-openbet/training/admin/tcl/pmt/pmt_batch_GWTD_FIRE.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

proc _set_up_details_FIRE {} {
	global PMTDET

	set batch_type FIRE

        if {[info exists PMTDET($batch_type,$batch_type,sql_list)]} {
                return
        }

	OT_LogWrite DEBUG "Setting up pmt batch info for $batch_type"

	# def_headers represents a default pmt mthd that can be used to retrieve
	# the headers for the csv file. It will be different for each batch type
	set PMTDET($batch_type,def_headers) $batch_type


	set date [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

	set PMTDET($batch_type,$batch_type,colheaders) 0
	set PMTDET($batch_type,$batch_type,filename)   "[OT_CfgGet GWTD_FIRE_FILENAME {}]_${date}_Firepay.txt"
	set PMTDET($batch_type,$batch_type,template)   [OT_CfgGet GWTD_FIRE_TEMPLATE {}]
	foreach {ccy val} [OT_CfgGet GWTD_FIRE_MAX_PMT_PER_CCY {}] {
		OT_LogWrite DEBUG "Limit on $ccy is $val"
		set PMTDET($batch_type,$batch_type,$ccy) [format %.2f $val]
	}

	set PMTDET($batch_type,$batch_type,column_list) [list \
		{ext_acct_no}                 DB      ext_acct_no \
		{amount}                      DB      amount \
		{ccy_code}                    DB      ccy_code \
		{pmt_id}                      DB      pmt_id \
	]

	set sql_list [list]

	# Sql to get payments
	lappend sql_list {
		select
			p.pmt_id,
			p.amount,
			g.pay_type as pay_mthd,
			g.blurb as ext_email_addr,
			g.extra_info as ext_acct_no,
			ac.acct_id,
			ac.ccy_code,
			c.username,
			r.fname,
			r.lname,
			r.email,
			r.addr_street_1 as address_1,
			r.addr_street_2 as address_2,
			r.addr_street_3 as city,
			cs.state,
			r.addr_postcode as post_code,
			r.addr_country as country
		from
			tPmtBatchLink l,
			tPmt p,
			tPmtGWTD g,
			tAcct ac,
			tCustomer c,
			tCustomerReg r,
			outer tCountryState cs
		where
			l.pmt_batch_id = ?
		and l.pmt_id      = p.pmt_id
		and p.pmt_id      = g.pmt_id
		and p.acct_id     = ac.acct_id
		and ac.cust_id    = c.cust_id
		and c.cust_id     = r.cust_id
		and r.addr_state_id = id
	}

	set PMTDET($batch_type,$batch_type,sql_list) $sql_list
}

_set_up_details_FIRE
}
