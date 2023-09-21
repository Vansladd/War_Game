# $Id $

package require util_appcontrol

namespace eval OB::BETCARD {

	variable base16 "0123456789ABCDEF"
	variable base36 "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

}

proc _prep_queries {} {
	global SHARED_SQL

	set SHARED_SQL(insert_betcard) {
		execute procedure pInsBetcard(
			p_betcard_key = ?,
			p_vendor_id = ?,
			p_cust_id = ?,
			p_betcard_sort = ?,
			p_amount = ?,
			p_vndr_pmt_id = ?,
			p_cust_pmt_id = ?,
			p_transactional = ?
		)
	}

	set SHARED_SQL(mk_vendor_pmt) {
		execute procedure pMkVendorPmt(
			p_type = ?,
			p_amount = ?,
			p_vendor_id = ?,
			p_adj_reason =?,
			p_transactional = ?
		)
	}

	set SHARED_SQL(get_active_bc_total) {
		select
			NVL(sum(amount),0) active_betcards
		from
			tbetcard
		where
			status = 'A'
		and
			betcard_sort = 'D'
		and
			vendor_id = ?
	}

	set SHARED_SQL(get_pending_bc_total) {
		select
			NVL(sum(amount),0) pending_wtds
		from
			tbetcard
		where
			status = 'A'
		and
			betcard_sort = 'W'
		and
			vendor_id = ?
	}

	set SHARED_SQL(get_bc_payment_method) {
		select
			cpm_id,
			status,
			cr_date
		from
			tCustPayMthd
		where
			status = 'A'
		and
			pay_mthd = 'BC'
		and
			cust_id = ?
	}

	set SHARED_SQL(get_cust_vendors) {
		select
			distinct v.vendor_id,
			v.vendor_name
		from
			tBetcard c,
			tBetcardVendor v
		where
			c.vendor_id = v.vendor_id
		and
			v.status = 'A'
		and
			c.cust_id = ?
	}

	set SHARED_SQL(get_pending_cust_wtds) {
		select
			v.vendor_name,
			c.amount,
			p.pmt_id,
			c.cr_date,
			c.betcard_no,
			c.betcard_key
		from
			tBetcard c,
			tBetcardVendor v,
			tPmtBetcard p
		where
			c.vendor_id = v.vendor_id
		and
			c.cust_pmt_id = p.pmt_id
		and
			c.status = 'A'
		and
			c.betcard_sort = 'W'
		and
			c.cust_id = ?
	}

	set SHARED_SQL(insert_betcard_pmt) {
		execute procedure pPmtInsBetcard (
			p_acct_id      = ?,
			p_cpm_id       = ?,
			p_payment_sort = ?,
			p_amount       = ?,
			p_commission   = ?,
			p_ipaddr       = ?,
			p_source       = ?,
			p_oper_id      = ?,
			p_unique_id    = ?,
			p_betcard_id       = ?,
			p_vendor_id      = ?,
			p_transactional	=?,
			p_locale       = ?
		)
	}

	set SHARED_SQL(get_betcard) {
		select
			betcard_id,
			betcard_key,
			vendor_id
		from
			tbetcard
		where
			betcard_no = ?
	}
}

proc OB::BETCARD::generate_betcard {vendor_id betcard_sort amount {vndr_pmt_id ""} {cust_id ""} {cust_pmt_id ""} {transactional "Y"}} {
	# need to create a random betcard key to put in the db and use to encrypt the betcard
	# number will be an 8 digit hex number for use with blowfish encryption

	set betcard_key ""

	for {set i 0} {$i < 8} {incr i} {

		set random_float	[expr {rand()}]
		set random_float	[expr {($random_float * 1000) / 66}]
		set random_int		[expr {round($random_float)}]
		set random_hex		[format "%x" $random_int]

		append betcard_key $random_hex
	}

	# insert a new betcard into tBetcard returning the betcard id

	set c [catch {
		set rs [tb_db::tb_exec_qry insert_betcard \
			$betcard_key \
			$vendor_id \
			$cust_id \
			$betcard_sort \
			$amount \
			$vndr_pmt_id \
			$cust_pmt_id \
			$transactional]
	} msg]

	if {$c} {
		catch {tb_db::tb_close $rs}
		ob::log::write ERROR {Failed to create betcard $msg}
		return [list "err" [strip_inf_exec $msg]]
	}

	# get the betcard no from the result set
	set betcard_no [db_get_coln $rs 0 0]
	set betcard_id [db_get_coln $rs 0 1]

	tb_db::tb_close $rs

	set betcard_no_enc [generate_betcard_number $betcard_no $betcard_key]

	return [list $betcard_no_enc $betcard_id]
}

proc OB::BETCARD::check_betcard_number {encoded_betcard_no {this_vendor_id ""}} {

	ob::log::write DEBUG {CHECKING BETACARD $encoded_betcard_no}

	variable base16
	variable base36

	set parts [split $encoded_betcard_no "-"]
	set num_parts [llength $parts]

	if {$num_parts != 5} {
		return [list -1 "VENDOR_DECODE_ERR"]
	}

	set betcard_raw ""

	for {set x 0} {$x < $num_parts} {incr x} {
		set part [lindex $parts $x]
		set decoded [dec_to_base_x [base_x_to_dec $part $base36] $base16]
		append betcard_raw [format "%05s" $decoded]
	}

	set betcard_no [string trimleft [string range $betcard_raw 1 8] "0"]
	set enc_betcard_no [string range $betcard_raw 9 24]

	set c [catch {
		set res [tb_db::tb_exec_qry get_betcard \
			$betcard_no \
		]
	} msg]

	if {$c == 0} {
		set rows [db_get_nrows $res]
		if {$rows != 1} {
			return [list -1 "VENDOR_DECODE_ERR"]
		}

		set betcard_id [db_get_col $res 0  betcard_id]
		set betcard_key [db_get_col $res 0  betcard_key]
		set vendor_id [db_get_col $res 0  vendor_id]

		tb_db::tb_close $res

		set enc_betcard_no_from_db [string toupper [betcard_encrypt [format "%08s" $betcard_no] $betcard_key]]

		if {$enc_betcard_no_from_db==$enc_betcard_no} {

			if {$this_vendor_id != ""} {
				if {$vendor_id==$this_vendor_id} {
						return $betcard_id
				} else {
					return [list -1 "VENDOR_DECODE_VENDOR_MISMATCH"]
				}
			} else {
				return $betcard_id
			}
		} else {
			return [list -1 "VENDOR_DECODE_ERR"]
		}

	} else {
		catch {tb_db::tb_close $res}
		return -1
	}
}

proc OB::BETCARD::generate_betcard_number {betcard_no betcard_key} {

	variable base16
	variable base36

	# now need to pad the betcard no with zeros before encryption
	# this will make sure all betcards are the same length
	# zeros will be stripped during validation when betcard is redeemed

	set betcard_no [format "%08s" $betcard_no]

	set enc_betcard_no [betcard_encrypt $betcard_no $betcard_key]

	# now need to format the betcard into 6 groups of 4 digits, separated by '-'s
	# this is the format in which the codes will be presented to the customer
	# need to pad it out one char so the string is can be broken in to groups of 5
	# i add a B as its a betcard!
	set raw_betcard [string toupper "B${betcard_no}${enc_betcard_no}"]

	set r {^(.{5})(.{5})(.{5})(.{5})(.{5})$}

	if {[regexp $r $raw_betcard a p1 p2 p3 p4 p5]} {

		set betcard ""

		for {set i 1} {$i <= 5} {incr i} {

			set part [set p[set i]]

			set reduced [dec_to_base_x [base_x_to_dec $part $base16] $base36]

			append betcard [format "%04s" $reduced]

			if {$i != 5} {
				append betcard "-"
			}
		}

		return $betcard

	} else {
		ob::log::write ERROR {bad betcard $raw_betcard}
		return [list "err" "bad betcard $raw_betcard"]
	}
}

proc OB::BETCARD::betcard_encrypt {betcard_no betcard_key} {

	if {[string length $betcard_no] != 8} {
		return ""
	}

	if {[string length $betcard_key] != 8} {
		return ""
	}

	set enc_betcard_no [blowfish encrypt -hex $betcard_key -bin $betcard_no]

	return $enc_betcard_no
}

proc OB::BETCARD::make_payment {type amount vendor_id reason {transactional "Y"}} {

	set c [catch {
		set res [tb_db::tb_exec_qry mk_vendor_pmt \
			$type \
			$amount \
			$vendor_id \
			$reason \
			$transactional \
		]
	} msg]

	if {$c == 0} {
		set vendor_pmt_id [db_get_coln $res 0 0]

		tb_db::tb_close $res
		ob::log::write INFO {payment made $type $amount $vendor_id $reason ($vendor_pmt_id)}
		return $vendor_pmt_id
	} else {
		catch {tb_db::tb_close $res}
		ob::log::write ERROR {payment failed $msg}
		return [list "err" [strip_inf_exec $msg]]
	}
}

proc OB::BETCARD::get_vendor_balances {vendor_id} {

	set res  [tb_db::tb_exec_qry get_active_bc_total $vendor_id]

	set active_betcards [db_get_col $res 0  active_betcards]

	tb_db::tb_close $res

	set res  [tb_db::tb_exec_qry get_pending_bc_total $vendor_id]

	set pending_wtds [db_get_col $res 0  pending_wtds]

	tb_db::tb_close $res

	return [list $active_betcards $pending_wtds]
}

proc OB::BETCARD::get_vendor {vendor_identifier {vendor_uname "ID"}} {

	global DB

	if {$vendor_uname=="UNAME"} {
		set where "v.vendor_uname = ?"
	} else {
		set where "v.vendor_id = ?"
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
			v.addr_country,
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
		and
			$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $vendor_identifier]
	inf_close_stmt $stmt

	return $res
}

proc OB::BETCARD::bind_vendor {res} {

	set vendor_id [db_get_col $res 0  vendor_id]
	tpBindString vendor_id 			$vendor_id
	tpBindString vendor_acct_no 	[db_get_col $res 0  vendor_acct_no]
	tpBindString vendor_uname		[db_get_col $res 0  vendor_uname]
	tpBindString password			[db_get_col $res 0  password]
	tpBindString vendor_name		[db_get_col $res 0  vendor_name]
	tpBindString l_name				[db_get_col $res 0  l_name]
	tpBindString f_name				[db_get_col $res 0  f_name]
	tpBindString addr_street_1		[db_get_col $res 0  addr_street_1]
	tpBindString addr_street_2		[db_get_col $res 0  addr_street_2]
	tpBindString addr_street_3		[db_get_col $res 0  addr_street_3]
	tpBindString addr_street_4		[db_get_col $res 0  addr_street_4]
	tpBindString addr_postcode		[db_get_col $res 0  addr_postcode]
	tpBindString telephone 			[db_get_col $res 0  telephone]
	tpBindString email 				[db_get_col $res 0  email]
	tpBindString ccy_name 			[db_get_col $res 0  ccy_name]
	tpBindString addr_country_name 	[db_get_col $res 0  country_name]
	tpBindString withdrawal_balance [db_get_col $res 0  withdrawal_balance]
	tpBindString deposit_balance 	[db_get_col $res 0  deposit_balance]
	tpBindString commission_rate 	[db_get_col $res 0  commission_rate]
	tpBindString betcard_min_amt 	[db_get_col $res 0  betcard_min_amt]
	tpBindString betcard_amt_incr 	[db_get_col $res 0  betcard_amt_incr]
	tpBindString lad_wtd_min		[db_get_col $res 0  lad_wtd_min]

	set status [db_get_col $res 0 status]
	if {$status == "S"} {
		tpSetVar VendorSuspended 1
	}

	set balances [get_vendor_balances $vendor_id]

	tpBindString active_betcards [lindex $balances 0]
	tpBindString pending_cust_wtds [lindex $balances 1]
}

proc OB::BETCARD::generate_vendor_betcard {amount vendor_id} {

	##get vendor info
	set res [get_vendor $vendor_id]

	set betcard_min_amt [db_get_col $res 0  betcard_min_amt]
	set betcard_amt_incr [db_get_col $res 0  betcard_amt_incr]

	tb_db::tb_close $res

	if {$amount < $betcard_min_amt} {
		return [list "err" "betcard amount too small"]
	}

	if {[expr {int(100*$amount) % int(100*$betcard_amt_incr)}]} {
		return [list "err" "betcard amount not multiple of $betcard_amt_incr"]
	}


	tb_db::tb_begin_tran
	## start transaction

	## make a 'customer payment' vendor payment
	set return_val [make_payment "CP" $amount $vendor_id "" "N"]

	if {[lindex $return_val 0] == "err"} {
		tb_db::tb_rollback_tran

		return $return_val
	}

	## generate a betcard, link it to the payment id
	set return_val [generate_betcard $vendor_id "D" $amount $return_val "" "" "N"]

	if {[lindex $return_val 0] == "err"} {
		tb_db::tb_rollback_tran
		return $return_val
	}

	tb_db::tb_commit_tran
	## all done

	return $return_val
}

proc OB::BETCARD::get_active {cust_id OUT } {

	upvar 1 $OUT DATA

	set DATA(betcard_available) "N"

	set rs  [tb_db::tb_exec_qry get_bc_payment_method $cust_id]

	if {[db_get_nrows $rs] == 1} {
		set DATA(betcard_available) "Y"
		set DATA(cpm_id)		[db_get_col $rs 0 cpm_id]
		set DATA(status)		[db_get_col $rs 0 status]
		set DATA(cr_date)		[db_get_col $rs 0 cr_date]
	}

	tb_db::tb_close $rs

	set rs  [tb_db::tb_exec_qry get_cust_vendors $cust_id]

	set DATA(vendor_count) [db_get_nrows $rs]
	if {$DATA(vendor_count) > 0} {
		for {set i 0} {$i < $DATA(vendor_count)} {incr i} {
			set DATA($i,vendor_id)			[db_get_col $rs $i vendor_id]
			set DATA($i,vendor_name)		[db_get_col $rs $i vendor_name]
		}
	}
	tb_db::tb_close $rs

	set rs  [tb_db::tb_exec_qry get_pending_cust_wtds $cust_id]

	set DATA(pending_wtd_count) [db_get_nrows $rs]
	if {$DATA(pending_wtd_count) > 0} {
		for {set i 0} {$i < $DATA(pending_wtd_count)} {incr i} {
			set DATA($i,pending_vendor_name)		[db_get_col $rs $i vendor_name]
			set DATA($i,pending_pmt_id)				[db_get_col $rs $i pmt_id]
			set DATA($i,pending_amount)				[db_get_col $rs $i amount]
			set DATA($i,pending_cr_date)			[db_get_col $rs $i cr_date]
			set DATA($i,pending_betcard_no_enc)		[generate_betcard_number [db_get_col $rs $i betcard_no] [db_get_col $rs $i betcard_key]]
		}
	}
	tb_db::tb_close $rs
}

proc OB::BETCARD::insert_customer_payment {
	acct_id
	cpm_id
	pay_sort
	amount
	tPmt_amount
	commission
	ipaddr
	source
	oper_id
	unique_id
	betcard_id
	vendor_uname
	{vendor_id ""}
	{OUT ""}
	{cust_id ""}
} {
	if {$OUT!=""} {
		upvar 1 $OUT DATA
	}

	tb_db::tb_begin_tran
	## start transaction

	if {$pay_sort == "W"} {
		## generate the betcard for the customer

		if {$vendor_id==""} {
			##get vendor info
			set res [OB::BETCARD::get_vendor $vendor_uname "UNAME"]
			if {[db_get_nrows $res] != 1} {
				tb_db::tb_close $res
				tb_db::tb_rollback_tran
				error "Failed to find vendor \"$vendor_uname\""
				return [list err "Failed to find vendor $vendor_uname"]
			}
			set vendor_id [db_get_col $res 0 vendor_id]
			tb_db::tb_close $res
		}

		set betcard [OB::BETCARD::generate_betcard $vendor_id "W" $amount "" "" "" "N"]
		## the pmt will update the betcard with the pmt id and the cust id

		if {[lindex $betcard 0] == "err"} {
			tb_db::tb_rollback_tran
			return $betcard
		}

		set betcard_id [lindex $betcard 1]

		set DATA(betcard_id) $betcard_id
		set DATA(betcard_no_enc) [lindex $betcard 0]
	}

	# Is the locale configured.
	if {[lsearch [OT_CfgGet LOCALE_INCLUSION] PMT] > -1} {
		set locale [app_control::get_val locale]
	} else {
		set locale ""
	}

	if {[catch {set rs [tb_db::tb_exec_qry insert_betcard_pmt $acct_id\
							               $cpm_id\
							               $pay_sort\
							               $tPmt_amount\
							               $commission\
							               $ipaddr\
							               $source\
							               $oper_id\
							               $unique_id\
							               $betcard_id\
							               $vendor_id\
						                   $locale
											N]} msg]} {
		tb_db::tb_rollback_tran
		ob::log::write ERROR {failed to insert payment record: $msg}
		return [list err [strip_inf_exec $msg]]
	}

	set pmt_id [db_get_coln $rs 0 0]

	tb_db::tb_close $rs

	tb_db::tb_commit_tran
	## all done

	if { [OT_CfgGetTrue CAMPAIGN_TRACKING] && $pay_sort == "D" } {
		ob_camp_track::record_camp_action $cust_id "DEP" "OB" $pmt_id
	}

	return $pmt_id
}

proc OB::BETCARD::strip_inf_exec {msg} {
	## removes unsightly stuff from the message so we can dump these straight to the lang business:
	if {[string first inf_exec_stmt $msg]} {
		set re {^inf_exec_stmt[ ]?: error \(-746\) }
		set res [regexp $re $msg msg]
	}
	set re {^(IX[0-9]{3}) ([a-zA-Z0-9_]*)$}
	set res [regexp $re $msg x y err_code]



	if {$res == 1} {
 		ob::log::write DEBUG {err_code is $err_code}
		if {[string first "PMT_ERR_INSERT_BC" $err_code]==-1 && [string first "PMT_ERR_UPD_BC" $err_code]==-1  && [string first "PMT_ERR_ALREADY_STL" $err_code]==-1} {
			## not a message we expect so use generic one
			set err_code "PMT_ERR_BC"
		}

	} else {
		## not a message we expect so use generic one
		set err_code "PMT_ERR_BC"
	}

	return $err_code
}

## prep the queries
_prep_queries
