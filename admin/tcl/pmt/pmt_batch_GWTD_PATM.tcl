# ==============================================================
# $Header: /cvsroot-openbet/training/admin/tcl/pmt/pmt_batch_GWTD_PATM.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2006 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

proc _set_up_details_PATM {} {
	global PMTDET

	set batch_type PATM

        if {[info exists PMTDET($batch_type,$batch_type,sql_list)]} {
                return
        }

	OT_LogWrite DEBUG "Setting up pmt batch info for $batch_type"

	# def_headers represents a default pmt mthd that can be used to retrieve
	# the headers for the csv file. It will be different for each batch type
	set PMTDET($batch_type,def_headers) $batch_type


	set date [clock format [clock seconds] -format "%Y%m%d%H%M%S"]

	set PMTDET($batch_type,$batch_type,colheaders) 0
	set PMTDET($batch_type,$batch_type,filename) "[OT_CfgGet GWTD_PATM_FILENAME {}]_${date}_PpATM.txt"
	set PMTDET($batch_type,$batch_type,template) [OT_CfgGet GWTD_PATM_TEMPLATE {}]

	set PMTDET($batch_type,$batch_type,column_list) [list \
		{ext_email_addr}              DB      ext_email_addr \
		{amount}                      DB      amount \
		{pmt_id}                      DB      pmt_id \
		{ext_acct_no}                 DB      ext_acct_no \
	]

	set sql_list [list]

	# Sql to get payments
	set col_sql {
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
	}

	set from_sql {
		from
			tPmtBatchLink l,
			tPmt p,
			tPmtGWTD g,
			tAcct ac,
			tCcy x,
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
		and r.addr_state_id = cs.id
		and ac.ccy_code   = x.ccy_code
	}

	lappend sql_list "$col_sql $from_sql"

	set PMTDET($batch_type,$batch_type,sql_list) $sql_list

	set totals_sql [subst {
		select
			count(*) as count,
			sum(p.amount / x.exch_rate) as amount,
			ac.ccy_code
		$from_sql
		group by ac.ccy_code
	}]

	set PMTDET($batch_type,$batch_type,totals_sql) $totals_sql
}

_set_up_details_PATM
}
