# ==============================================================
# $Header: /cvsroot-openbet/training/admin/tcl/pmt/pmt_batch_GWTD_C2P.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

proc _set_up_details_C2P {} {
	global PMTDET

	set batch_type C2P

        if {[info exists PMTDET($batch_type,$batch_type,sql_list)]} {
                return
        }

	OT_LogWrite DEBUG "Setting up pmt batch info for $batch_type"

	# def_headers represents a default pmt mthd that can be used to retrieve
	# the headers for the csv file. It will be different for each batch type
	set PMTDET($batch_type,def_headers) $batch_type


	set date [clock format [clock seconds] -format "%y%m%d"]

	set PMTDET($batch_type,$batch_type,colheaders) 0
	set PMTDET($batch_type,$batch_type,colseparator) "\n"
	set PMTDET($batch_type,$batch_type,filename) "[OT_CfgGet GWTD_C2P_FILENAME {}]${date}.xml"
	set PMTDET($batch_type,$batch_type,template) [OT_CfgGet GWTD_C2P_TEMPLATE {}]

	set PMTDET($batch_type,$batch_type,column_list) [list \
		{mid}                         STATIC  [OT_CfgGet GWTD_C2P_MID {}] \
		{ext_email_addr}              DB      ext_email_addr \
		{amount_by_100}               DB      amount_by_100 \
		{ccy_code}                    DB      ccy_code \
		{product_id}                  STATIC  [OT_CfgGet GWTD_C2P_PRODUCT {}] \
		{pmt_id}                      DB      pmt_id \
	]

	set sql_list [list]

	# Sql to get payments
	lappend sql_list {
		select
			p.pmt_id,
			p.amount,
			round(p.amount*100) as amount_by_100,
			c.cust_id,
			g.pay_type as pay_mthd,
			g.blurb as ext_email_addr,
			g.extra_info as ext_acct_no,
			ac.acct_id,
			ac.ccy_code,
			c.username,
			upper(r.fname) as fname,
			upper(r.lname) as lname,
			r.lname,
			r.email,
			upper(r.addr_street_1) as address_1,
			upper(r.addr_street_2) as address_2,
			upper(r.addr_street_3) as city,
			cs.state,
			upper(ct.country_name) as country,
			r.addr_postcode,
			decode(ac.ccy_code,'USD','USD',c.country_code) as fx_ccy_code
		from
			tPmtBatchLink l,
			tPmt p,
			tPmtGWTD g,
			tAcct ac,
			tCustomer c,
			tCustomerReg r,
			tCountry ct,
			outer tCountryState cs
		where
			l.pmt_batch_id = ?
		and l.pmt_id      = p.pmt_id
		and p.pmt_id      = g.pmt_id
		and p.acct_id     = ac.acct_id
		and ac.cust_id    = c.cust_id
		and c.cust_id     = r.cust_id
		and c.country_code = ct.country_code
		and r.addr_state_id = id
	}

	set PMTDET($batch_type,$batch_type,sql_list) $sql_list
}

_set_up_details_C2P
}
