# ==============================================================
# $Id: fraud.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999,2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::FRAUD {

asSetAct ADMIN::FRAUD::GoFraudQuery   	[namespace code go_fraud_query]
asSetAct ADMIN::FRAUD::DoFraudQuery   	[namespace code do_fraud_query]


################################################################################
# Procedure :   go_fraud_query
# Description : Go to fraud query screen. This screen allows you to search
#				for customers who have been fraud screened
# Input :
# Output :
# Author :      AJ, 16-10-2002
################################################################################
proc go_fraud_query {} {

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

	#
	# Load Channel List
	#
	set stmt [inf_prep_sql $DB {
		select
			channel_id,
			desc
		from
			tChannel
		order by
			desc asc
	}]

	set res_chan  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumChannels [db_get_nrows $res_chan]

	tpBindTcl ChannelId          sb_res_data $res_chan channel_idx channel_id
	tpBindTcl ChannelName        sb_res_data $res_chan channel_idx desc

	asPlayFile -nocache fraud_query.html

	db_close $res_ccy
	db_close $res_cntry
	db_close $res_chan
}


################################################################################
# Procedure :   do_fraud_query
# Description : Do the query and return a list of customers
#				or the customer details page
# Input :
# Output :
# Author :      AJ, 16-10-2002
################################################################################
proc do_fraud_query {} {

	global DB USERID DATA

	array set DATA [list]

	set where [list]

	#
	# Build up selection query
	#
	# Customer details
	if {[string length [set name [reqGetArg Customer]]] > 0} {
		if {[reqGetArg ExactName] == "Y"} {
			set op =
		} else {
			set op like
			append name %
		}
		if {[reqGetArg UpperName] == "Y"} {
			lappend where "[upper_q c.username] $op [upper_q \"${name}\"]"
		} else {
			lappend where "c.username $op \"${name}\""
		}
	}
	if {[string length [set fname [reqGetArg FName]]] > 0} {
		lappend where "[upper_q r.fname] = [upper_q '$fname']"
	}
	if {[string length [set lname [reqGetArg LName]]] > 0} {
		lappend where "[upper_q r.lname] = [upper_q '$lname']"
	}
	if {[string length [set email [reqGetArg Email]]] > 0} {
		lappend where "upper(r.email) like upper('%${email}%')"
	}
	if {[string length [set acctno [reqGetArg AcctNo]]] > 0} {
		lappend where "c.acct_no = '$acctno'"
	}
	if {[string length [set address [reqGetArg Address]]] > 0} {
		lappend where [get_indexed_sql_query $address address]
	}
	if {[string length [set addr_postcode [reqGetArg Postcode]]] > 0} {
		lappend where [get_indexed_sql_query $addr_postcode addr_postc]
	}
	if {[string length [set ccy_code [reqGetArg CCYCode]]] > 0} {
		lappend where "a.ccy_code = '$ccy_code'"
	}
	if {[string length [set cntry_code [reqGetArg CNTRYCode]]] > 0} {
		if {[reqGetArg CNTRYExclude] == "Y"} {
			lappend where "c.country_code <> '$cntry_code'"
		} else {
			lappend where "c.country_code = '$cntry_code'"
		}
	}
	set rd1 [string trim [reqGetArg RegDate1]]
	set rd2 [string trim [reqGetArg RegDate2]]
	lappend where "f.flag_name = 'fraud_status'"
	if {([string length $rd1] > 0) || ([string length $rd2] > 0)} {
		lappend where [mk_between_clause c.cr_date date $rd1 $rd2]
	}
	if {[string length [set fraud_status [reqGetArg FraudStatus]]] > 0} {
		lappend where "f.flag_value = '$fraud_status'"
	}

	# Card registration details
	set card_reg_join "outer tCardReg cr"
	if {[string length [set ipaddr [reqGetArg IPAddress]]] > 0} {
		lappend where "cr.ipaddr = '$ipaddr'"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set CardNo [reqGetArg CardNo]]] > 0} {
		regsub -all {[[:space:]]} $CardNo "" card
		OT_LogWrite 10 "card: $card"
		set card_matches [list]

		set hash_sql {
			select
				reg_hash_id,
				enc_reg_id,
				ivec,
				data_key_id
			from
				tCardRegHash
			where
				reg_hash = ?
		}

		set hash_stmt [inf_prep_sql $DB $hash_sql]
		set hash_res  [inf_exec_stmt $hash_stmt [md5 $card]]
		inf_close_stmt $hash_stmt

		set found_ids [list]

		for {set i 0} {$i < [db_get_nrows $hash_res]} {incr i} {
			set reg_hash_id [db_get_col $hash_res $i reg_hash_id]
			set enc_reg_id  [db_get_col $hash_res $i enc_reg_id]
			set ivec        [db_get_col $hash_res $i ivec]
			set data_key_id [db_get_col $hash_res $i data_key_id]
	
			lappend found_ids [list $reg_hash_id $enc_reg_id $ivec $data_key_id]
		}

		db_close $hash_res

		# Deal with card number
		set reg_dec_rs [card_util::decrypt_cpmid $found_ids "Admin Card Registration query" "" $USERID "tCardRegHash"]

		if {[lindex $reg_dec_rs 0] == 0} {
			return [list 0 [lindex $reg_dec_rs 1]]
		} else {
			set card_matches [lindex $reg_dec_rs 1]
		}

		lappend where "cr.card_reg_id in ([join $card_matches ,])"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set channel [reqGetArg channels]]] > 0} {
		lappend where "cr.source = '$channel'"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set SR_date_range [reqGetArg SR_date_range]]] > 0} {
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
		lappend where "cr.cr_date >= '$SR_date_1'"
		lappend where "cr.cr_date <= '$SR_date_2'"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set SR_date_1 [reqGetArg SR_date_1]]] > 0} {
		lappend where "cr.cr_date >= '$SR_date_1'"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set SR_date_2 [reqGetArg SR_date_2]]] > 0} {
		lappend where "cr.cr_date <= '$SR_date_2'"
		set card_reg_join "tCardReg cr"
	}
	if {[string length [set SR_payment_sort [reqGetArg SR_payment_sort]]] > 0} {
		lappend where "cr.payment_sort = '$SR_payment_sort'"
		set card_reg_join "tCardReg cr"
	}


	#
	# Don't allow a query with no filters
	#
	if {[llength $where] == 0} {
		error "No search criteria supplied"
	}

	if {[info exists CUST(CUST_SEARCH_ORDER)]} {
		set order_by $CUST(CUST_SEARCH_ORDER)
	} else {
		set order_by "c.cust_id"
	}

	set where "and [join $where { and }]"

	set sql [subst {
		select
			unique c.cust_id,
			c.username,
			c.status,
			c.acct_no,
			c.bet_count,
			c.country_code,
			c.elite,
			a.ccy_code,
			c.cr_date,
			c.max_stake_scale,
			a.balance + a.sum_ap AS balance,
			a.credit_limit,
			r.nickname,
			r.addr_city,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_postcode,
			r.email,
			e.ext_cust_id,
			e.master,
			e.code,
			NVL((select d.desc from tCustCode d where r.code = d.cust_code),'(None)')
				as cust_group
		from
			tCustomer     c,
			outer tExtCust e,
			tAcct         a,
			tCustomerReg  r,
			tCustomerFlag f,
			$card_reg_join
		where
			c.cust_id = a.cust_id and
			c.cust_id = e.cust_id and
			c.cust_id = r.cust_id and
			c.cust_id = f.cust_id and
			c.cust_id = cr.cust_id and
			a.owner   <> 'D'
			$where
		order by
			$order_by
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_elite 0
	set num_norm [db_get_nrows $res]

	# play
	if {$num_norm == 1} {
		ADMIN::CUST::go_cust cust_id [db_get_col $res 0 cust_id]
		db_close $res
		return
	}

	for {set r 0} {$r < $num_norm} {incr r} {
		set DATA($r,acct_no) [acct_no_enc [db_get_col $res $r acct_no]]

		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo      DATA acct_no cust_idx

	tpBindTcl CustID        sb_res_data $res cust_idx cust_id
	tpBindTcl Username      sb_res_data $res cust_idx username
	tpBindTcl Status        sb_res_data $res cust_idx status
	tpBindTcl BetCount      sb_res_data $res cust_idx bet_count
	tpBindTcl CountryCode   sb_res_data $res cust_idx country_code
	tpBindTcl Elite         sb_res_data $res cust_idx elite
	tpBindTcl NickName      sb_res_data $res cust_idx nickname
	tpBindTcl City          sb_res_data $res cust_idx addr_city
	tpBindTcl CcyCode       sb_res_data $res cust_idx ccy_code
	tpBindTcl Balance       sb_res_data $res cust_idx balance
	tpBindTcl MaxStakeScale sb_res_data $res cust_idx max_stake_scale
	tpBindTcl RegDate       sb_res_data $res cust_idx cr_date
	tpBindTcl RegFName      sb_res_data $res cust_idx fname
	tpBindTcl RegLName      sb_res_data $res cust_idx lname
	tpBindTcl Address1      sb_res_data $res cust_idx addr_street_1
	tpBindTcl Postcode      sb_res_data $res cust_idx addr_postcode
	tpBindTcl Email         sb_res_data $res cust_idx email
	tpBindTcl ExtCustId     sb_res_data $res cust_idx ext_cust_id
	tpBindTcl Master        sb_res_data $res cust_idx master
	tpBindTcl ExtCustCode   sb_res_data $res cust_idx code
	tpBindTcl CustGroup     sb_res_data $res cust_idx cust_group

	asPlayFile -nocache cust_list.html

	unset DATA

	db_close $res
}

}
