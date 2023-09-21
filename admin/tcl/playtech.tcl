# ==============================================================
# $Id: playtech.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PLAYTECH {


proc manual_adjust args {

	global DB

	if {![op_allowed PTFundsXfer]} {
		err_bind {You don't have permission to do playtech adjustments}
		ADMIN::CUST::go_cust
		return
	}

	set cust_id [reqGetArg CustId]
	set type    [reqGetArg Type]
	set amount  [reqGetArg Amount]
	set system  [reqGetArg system]

	if {[OT_CfgGet PLAYTECH_ADJ_IS_XFER 0]} {
		set reg_exp {^-?([0-9]*)(\.([0-9]([0-9])?))?$}
	} else {
		set reg_exp {^([0-9]*)(\.([0-9]([0-9])?))?$}
	}

	if {![regexp $reg_exp $amount] || [string trim $amount] == ""} {
		err_bind {Invalid Amount}
		ADMIN::CUST::go_cust
		return
	}

	# Get the customer's details
	set sql [subst {
		select
			c.username,
			c.password,
			a.ccy_code
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id = a.cust_id and
			c.cust_id = $cust_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows != 1} {
		db_close $res
		err_bind "Cannot find customer"
		ADMIN::CUST::go_cust
		return
	}

	ob::log::write INFO "ADMIN_PLAYTECH: got cust details"

	set password [db_get_col $res 0 password]
	set currency [db_get_col $res 0 ccy_code]
	set username [db_get_col $res 0 username]

	db_close $res

	# are we usng tXSysXfer or are we just making a balance adjustment?
	if {[OT_CfgGet PLAYTECH_ADJ_IS_XFER 0]} {
		_do_playtech_xfer $system $cust_id $username $password $currency $amount
	} else {
		_do_playtech_adj $type $system $cust_id $username $password $currency $amount
	}
}



# Transfer funds into/out of playtech system
#
#   system   - name of system to transfer to
#   cust_id  - customer identifier
#   username - username
#   password - customer password
#   ccy_code - customer currency code
#   amount   - amount to transfer
#
proc _do_playtech_xfer {
	system
	cust_id
	username
	password
	ccy_code
	amount
} {

	playtech::transfer_funds $system $cust_id $username $password \
	                         $ccy_code $amount [OT_UniqueId]

	if {[playtech::status] == "OK"} {

		OT_LogWrite 5 "Successfully transferred: $amount, cust: $cust_id, system: $system"
		msg_bind "Transfer approved"

	} elseif {[playtech::status] == "ERROR" && ![catch {set status [playtech::response status]}] && $status == "declined"} {

		OT_LogWrite 5 "Transfer declined, amount: $amount, cust: $cust_id, system: $system"
		err_bind   "DECLINED:[playtech::code]"

	} else {

		OT_LogWrite 5 "Transfer unknown, amount: $amount, cust: $cust_id, system: $system"
		err_bind   "Transfer is in an unknown status: [playtech::code]"

	}

	ADMIN::CUST::go_cust
}



# Move funds into/out of playtech system
#
#   type     -  is it a dep or wtd
#   system   - name of system to transfer to
#   cust_id  - customer identifier
#   username - username
#   password - customer password
#   ccy_code - customer currency code
#   amount   - amount to transfer
#
proc _do_playtech_adj {type system cust_id username password currency amount} {

	global DB USERNAME ADM_LANG

	# Record the transaction in the ad-hoc playtech table
	set sql [subst {
		execute procedure pInsPlaytechAdj(
			p_cust_id    = $cust_id,
			p_type       = '$type',
			p_amount     = '$amount',
			p_username   = '$username',
			p_ccy_code   = '$currency',
			p_admin_user = '$USERNAME',
			p_system     = '$system'
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	if {$rows != 1} {
		err_bind "Cannot insert playtech adjustment"
	}

	set id [db_get_coln $res 0 0]

	db_close $res

	ob::log::write INFO "ADMIN_PLAYTECH: inserting and id = $id"

	# Do the external transfer stuff
	array set PT_SCRIPTS [list dep externaldeposit.php wtd externalwithdraw.php]

	playtech::configure_request -channel "P" -is_critical_request "Y"

	playtech::call $system $PT_SCRIPTS($type) \
		"username       $username" \
		"password       $password" \
		"amount         $amount" \
		"externaltranid ${id}pt" \
		"currency       $currency"

	if {[playtech::status] == "OK"} {

		if {[playtech::response status] != "approved"} {
			error {Playtech status is OK but transaction has not been approved}
		}
		set status "APPROVED"
		msg_bind   "Transfer approved"

	} elseif {[playtech::status] == "ERROR" && ![catch {set status [playtech::response status]}] && $status == "declined"} {

		set status "DECLINED:[playtech::code]"
		err_bind   "DECLINED:[playtech::code]"

	} else {

		set status "UNKNOWN:[playtech::code]"
		err_bind   "UNKNOWN:[playtech::code]"

	}

	# Update the status
	set sql {
		update
			tPlaytechAdj
		set
			status = ?
		where
			trans_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
			$status\
			$id]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
	}

	inf_close_stmt $stmt
	db_close $res

	ADMIN::CUST::go_cust
}


proc view_adjustments args {

	global DB USERNAME

	set where [list]

	set SR_date_1     [reqGetArg SR_date_1]
	set SR_date_2     [reqGetArg SR_date_2]
	set SR_date_range [reqGetArg SR_date_range]
	set system        [reqGetArg system]

	if {$SR_date_range != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set SR_date_2 "$Y-$M-$D"
		if {$SR_date_range == "TD"} {
			set SR_date_1 "$Y-$M-$D"
		} elseif {$SR_date_range == "CM"} {
			set SR_date_1 "$Y-$M-01"
		} elseif {$SR_date_range == "YD"} {
			set SR_date_1 [date_days_ago $Y $M $D 1]
			set SR_date_2 $SR_date_1
		} elseif {$SR_date_range == "L3"} {
			set SR_date_1 [date_days_ago $Y $M $D 3]
		} elseif {$SR_date_range == "L7"} {
			set SR_date_1 [date_days_ago $Y $M $D 7]
		}
		append SR_date_1 " 00:00:00"
		append SR_date_2 " 23:59:59"
	}

	if {$SR_date_1 != ""} {
		lappend where "cr_date >= '$SR_date_1'"
	}
	if {$SR_date_2 != ""} {
		lappend where "cr_date <= '$SR_date_2'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			p.trans_id,
			p.type,
			p.cr_date,
			p.amount,
			p.status,
			p.admin_user,
			x.name
		from
			tPlaytechAdj p,
			tXSysHost    x
		where
			p.cust_id   = ? and
			p.system_id = x.system_id
			$where
		order by
			trans_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt [reqGetArg CustId]]
	inf_close_stmt $stmt

	tpSetVar NumPlayAdjs [db_get_nrows $res]

	tpBindTcl Date     sb_res_data $res pa_idx cr_date
	tpBindTcl Amount   sb_res_data $res pa_idx amount
	tpBindTcl Type     sb_res_data $res pa_idx type
	tpBindTcl Status   sb_res_data $res pa_idx status
	tpBindTcl User     sb_res_data $res pa_idx admin_user
	tpBindTcl System   sb_res_data $res pa_idx name

	tpBindString CustId [reqGetArg CustId]
	tpBindString AcctId [reqGetArg AcctId]

	asPlayFile -nocache cust_playtech_adj_hist.html

	db_close $res
}



# Insert a row into tXSysSyncQueue to send over the customers
# account to Playtech again. This will create the same row as if
# the customers account has just been created.
#
proc synchronise_account {} {

	global DB

	if {![op_allowed PTAccountSync]} {
		err_bind {You do not have permission to synchronise this account}
		ADMIN::CUST::go_cust
		return
	}

	set cust_id [reqGetArg CustId]

	set sql {
		select
			c.status as status,
			c.elite,
			c.username,
			c.password,
			y.country_code,
			a.ccy_code as currency_code,
			r.fname,
			r.lname,
			r.addr_street_1 as addr_1,
			r.addr_street_2 as addr_2,
			r.addr_street_3 as addr_3,
			r.addr_street_4 as addr_4,
			r.addr_city as addr_cty,
			r.addr_postcode as addr_pc,
			r.dob,
			r.email,
			r.mobile,
			r.telephone,
			r.ipaddr,
			r.title,
			r.contact_ok,
			r.contact_how,
			c.acct_no,
			NVL(g.flag_value,'N') as custom02,
			r.occupation,
			r.gender
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			outer tCountry y,
			outer tCustomerFlag g
		where
		    c.cust_id = ?
		and r.cust_id = c.cust_id
		and a.cust_id = c.cust_id
		and y.country_code = c.country_code
		and g.cust_id = c.cust_id
		and g.flag_name = 'Bonus Abuser'
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set colnames [db_get_colnames $res]
	foreach col $colnames {
		set $col [db_get_col $res 0 $col]
	}

	db_close $res

	set system [reqGetArg system]

	playtech::configure_request -channel "P" -is_critical_request "Y"

	playtech::change_player \
		$username \
		$password \
		$country_code \
		$fname \
		$lname \
		$addr_1 \
		$addr_2 \
		$addr_3 \
		$addr_4 \
		$addr_cty \
		$addr_pc \
		$email \
		$mobile \
		$telephone \
		$title \
		$contact_ok \
		$contact_how \
		[expr {$status == "A" ? "0" : "1"}] \
		0 \
		$system \
		$custom02\
		$acct_no\
		$occupation\
		$gender\
		$dob

	if {[playtech::status] == "OK"} {
		msg_bind "Successfully synchronised account"
	} else {
		err_bind ERROR:[playtech::code]
	}

	ADMIN::CUST::go_cust
}


proc synchronise_password {} {
	global DB

	if {![op_allowed PTPasswordSync]} {
		err_bind {You don't have permission to synchronise password}
		ADMIN::CUST::go_cust
		return
	}

	set sql {
		select
			username,
			password
		from
			tcustomer
		where
			cust_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt [reqGetArg CustId]]
	inf_close_stmt $stmt

	set password [db_get_col $res 0 password]
	set username [db_get_col $res 0 username]

	db_close $res

	set system [reqGetArg system]

	playtech::configure_request -channel "P" -is_critical_request "Y"

	playtech::change_password $username $password $system
	if {[playtech::status] == "OK"} {
		msg_bind "Successfully synchronised password"
	} else {
		err_bind ERROR:[playtech::code]
	}

	ADMIN::CUST::go_cust
}


}
