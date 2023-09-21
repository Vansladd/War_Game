# $Id: risk_guardian.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
#  RiskGuardian Gateway
#
# Description
#
# Performs fraud detection for credt/debit card deposits

# Procedures:
#    riskGuardian::init            - one time initialisation
#    riskGuardian::log             - performs logging
#    riskGuardian::do_check        - performs fraud detaction
#    riskGuardian::xlate_err_code  - translates error codes
#    riskGuardian::get_cust_info   - retrieves customer information
#    riskGuardian::get_acct        - gets RiskGuardian Account details
#    riskGuardian::decrypt         - performs decryption
#
#
namespace eval riskGuardian {

	variable RG_INITIALISED 0

	#
	# English messages for the PMT_ error codes
	#

	variable  RG_ERR_CODES
	array set RG_ERR_CODES {
	  PMT_NO_CUST_DETAILS {Customer details not found}
	  PMT_RG_REFUSED      {Transaction not recommended by Risk Guardian}
	}
	variable RG_SHM_CACHE

	# Trustmarque Risk Guardian
	trustmarque::trustmarque_init

}



# ----------------------------------------------------------------------
# Performs logging
# ----------------------------------------------------------------------
proc riskGuardian::log {level msg} {
	OT_LogWrite $level "RG: $msg"
}



# ----------------------------------------------------------------------
# Initialise the risk guardian functions
# ----------------------------------------------------------------------
proc riskGuardian::init args {

	log 5 "<== init"

	global   SHARED_SQL
	variable RG_SHM_CACHE

	# are we storing details in shared memory to share between children?
	if {[OT_CfgGet RISK_GUARDIAN_USE_SHM 0] && [llength [info commands asStoreRs]]} {
		set RG_SHM_CACHE 1
	} else {
		set RG_SHM_CACHE 0
	}

	set SHARED_SQL(rg_get_cust_info) {
	  select
		r.fname || ' ' || r.lname as fullname,
		r.title,
		r.fname,
		r.lname,
		r.addr_street_1,
		r.addr_street_2,
		r.addr_street_3,
		r.addr_city,
		r.addr_postcode,
		r.telephone,
		r.email,
		c.country_code,
		c.acct_no,
		current year to month as cdate,
		c.cr_date as rdate
	  from
		tCustomer c, tCustomerReg r
	  where
		c.cust_id = r.cust_id and
		c.cust_id = ?
	}

	set SHARED_SQL(rg_check_cust_flag) {
	  select
	    flag_value
	  from
	    tCustomerFlag f1
	  where
	    flag_name = 'RiskGuardian' and
	    cust_id = ?
	}

	set SHARED_SQL(rg_check_cust_flag_override) {
	  select
	    flag_value
	  from
	    tCustomerFlag
	  where
	    flag_name = 'RiskGuardianOver' and
	    cust_id = ?
	}

	# any transaction amount smaller than i_value should not be passed through risk guardian
	set SHARED_SQL(rg_check_amount_condition) {
	  select
	    i_value
	  from
	    tRGCondition
	  where
	    type = ?
	}

	set SHARED_SQL(rg_get_conditions) {
	  select
	    type,
	    c_value
	  from
	    tRGCondition
	  where
	    c_value is not null
	}
	set SHARED_SQL(cache,rg_get_conditions) 60

	set SHARED_SQL(rg_get_num_days_since_first_successful_dep_date) {
		select
			CURRENT - min(s.first_date)
		from
			tCustStatsAction ac,
			tCustStats s,
			tAcct a
		where
			a.cust_id      = ?            and
			s.acct_id      = a.acct_id    and
			s.action_id    = ac.action_id and
			ac.action_name  = 'DEPOSIT'
	}

	set SHARED_SQL(rg_get_acct) {
	  select
		rg_host_id,
		enc_client,
		enc_client_ivec,
		enc_password,
		enc_password_ivec,
		enc_mid,
		enc_mid_ivec,
		enc_key,
		enc_key_ivec,
		data_key_id,
		rg_ip,
		rg_port,
		resp_timeout,
		conn_timeout
	  from
		tRGHost
	  where
	    status = 'A'
	}

	set SHARED_SQL(rg_get_successful_3d_auth) {
		select
		    first 1 p.pmt_id
		from
		    tPMTCC c,
		    tPmt p
		where
		    p.cpm_id = ? and
		    p.pmt_id = c.pmt_id and
		    p.status = 'Y' and
		    c.auth_type = 'D'
	}

	set SHARED_SQL(cache,rg_get_acct) 30

	set SHARED_SQL(rg_insert_failure) {
		insert into tRGFailure (
		    cust_id,
			amount,
			order_no,
			rg_id,
			tscore,
			trisk,
			fail_date
		) values (?, ?, ?, ?, ?, ?, CURRENT)
	}

	set SHARED_SQL(rg_get_acct_type) {
	  select
	    a.acct_type
	  from
	    tAcct a
	  where
	    cust_id = ?
	}

	log 5 "==> init"

	return 1

}


# ----------------------------------------------------------------------
# Makes a call to Risk Guardian for every credit/debit card deposit
# If the trisk returned from Risk Guardian is more than the tscore value then
# the transaction is OK to proceed with
#
# Param
#      ARRAY  - the PMT array used in all gateways to hold payment details
#
# Return
#      1 if it is OK to proceed with the transaction, 0 otherwise
#
#  ----------------------------------------------------------------------
proc riskGuardian::do_check {ARRAY} {

	upvar $ARRAY RG
	variable RG_INITIALISED

	log 5 "<== do_check"

	#
	# Run this the first time this function is called
	#
	if {!$RG_INITIALISED} {
		set RG_INITIALISED [init]
	}

	# only do Risk Guardian check for deposits
	if {$RG(pay_sort) != "D"} {
		return 1
	}

	# Get the Risk Guardian account details.

	set result [get_acct RG]

	if {![lindex $result 0]} {
		return 1
	}

	# Only check if tAcct.acct_type == DEP
	if {[OT_CfgGet ENABLE_RISKGUARDIAN_DEP_ACCTS_ONLY 0]} {
		if {[catch {set rs [tb_db::tb_exec_qry rg_get_acct_type $RG(cust_id)]} msg]} {
			log 1 "ERROR: running rg_get_acct_type: $msg"
			return 1
		}
		if {[db_get_coln $rs 0 0] != "DEP"} {
			log 1 "acct_type != DEP - discarding"
			db_close $rs
			return 1
		}
		db_close $rs
	}

	# Check tCustomerFlags to see if this customer is exempt from Risk Guardian
	# checking, or has to be checked through Risk Guardian regardless.
	if {[catch {set rs [tb_db::tb_exec_qry rg_check_cust_flag $RG(cust_id)]} msg]} {
		log 1 "ERROR: running rg_check_cust_flag: $msg"
		return 1
	}

	if {[db_get_nrows $rs] > 0} {
		set flag_value [db_get_col $rs 0 flag_value]
		if {$flag_value == "Skip"} {
			# don't need to do any Risk Guardian checks
			log 1 "RiskGuardian cust flag = '$flag_value'"
			db_close $rs
			return 1
		}
	} else {
		set flag_value "NotSet"
	}
	db_close $rs

	log 1 "RiskGuardian cust flag = '$flag_value'"

	if {$flag_value != "Force"} {
		# Check we meet the Risk Guardian conditions in the OpenBet database
		# before to decide if we want to send the request to Risk Guardian.

		# Get global min for type = amount/ccy_code
		if {[catch {set rs [tb_db::tb_exec_qry rg_check_amount_condition "amount/$RG(ccy_code)" $RG(amount)]} msg]} {
			log 1 "ERROR: running rg_check_amount_condition: $msg"
			return 1
		}

		set global_min 0
		if {[db_get_nrows $rs]} {
			set global_min [db_get_coln $rs 0 0]
		}
		db_close $rs

		log 1 "global Risk Guardian min for $RG(ccy_code) = $global_min"

		# get the customer specific override in the flag, if present
		if {[catch {set rs [tb_db::tb_exec_qry rg_check_cust_flag_override $RG(cust_id)]} msg]} {
			log 1 "ERROR: running rg_check_cust_flag_override: $msg"
			return 1
		}

		set cust_override 0
		if {[db_get_nrows $rs]} {
			set cust_override [db_get_col $rs 0 flag_value]
		}
		db_close $rs

		log 1 "amount=$RG(amount), cust_override=$cust_override, global_min=$global_min"

		if {$RG(amount) - $cust_override < $global_min} {
			# we're allowing this transaction
			return 1
		}

		# Get all the other conditions..
		if {[catch {set rs [tb_db::tb_exec_qry rg_get_conditions]} msg]} {
			log 1 "ERROR: running rg_get_conditions: $msg"
			return 1
		}

		# If the config item is on, the test isn't used
		set check_rg_currency     [OT_CfgGet ENABLE_RISKGUARDIAN_CURRENCY 1]
		set check_rg_country      [OT_CfgGet ENABLE_RISKGUARDIAN_COUNTRY 1]
		set check_rg_ip_address   [OT_CfgGet ENABLE_RISKGUARDIAN_IP_ADDRESS 1]
		set check_rg_card_bin     [OT_CfgGet ENABLE_RISKGUARDIAN_CARD_BIN 1]
		set check_rg_reg_date     [OT_CfgGet ENABLE_RISKGUARDIAN_REG_DATE 1]
		set check_rg_1st_dep_date [OT_CfgGet ENABLE_RISKGUARDIAN_1ST_DEP_DATE 1]
		set match_rg_currency     0
		set match_rg_country      0
		set match_rg_ip_address   0
		set match_rg_card_bin     0
		set match_rg_reg_date     0
		set match_rg_1st_dep_date 0

		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			set type  [db_get_col $rs $r type]
			set value [db_get_col $rs $r c_value]

			if {$check_rg_currency           && $type == "currency"   && $value == $RG(ccy_code)} {
				set match_rg_currency 1
			} elseif {$check_rg_country      && $type == "country"    && $value == $RG(country)} {
				set match_rg_country 1
			} elseif {$check_rg_ip_address   && $type == "ip_address" && $value == $RG(ip)} {
				set match_rg_ip_address 1
			} elseif {$check_rg_card_bin     && $type == "card_bin"   && $value == $RG(card_bin)} {
				set match_rg_card_bin 1
			} elseif {$check_rg_reg_date     && $type == "reg_date"} {
				set qualify_date [clock format [clock scan "today - $value day"] -format "%Y-%m-%d"]
				set reg_date_ytod [lindex [split $RG(reg_date) { }] 0]

				if {$reg_date_ytod >= $qualify_date} {
					set match_rg_reg_date 1
				}
			} elseif {$check_rg_1st_dep_date && $type == "1st_dep_date"} {
				if [catch {set fd_rs [tb_db::tb_exec_qry rg_get_num_days_since_first_successful_dep_date \
										  $RG(cust_id)]} msg] {
					log 1 "ERROR: running rg_get_num_days_since_first_successful_dep_date: $msg"
					db_close $rs
					return 1
				}

				if {[db_get_nrows $fd_rs] != 1} {
					log 1 "ERROR: rg_get_num_days_since_first_successful_dep_date should return one row!"
					db_close $fd_rs
					db_close $rs
					return 1
				}

				set diff [string trim [db_get_coln $fd_rs 0 0]]
				# diff is of form 89 00:38:42.000
				# we'll round down to err on the side of caution
				if {$diff != ""} {
					set num_days [expr {[lindex [split $diff] 0] - 1}]
					if {$num_days < $value} {
						set match_rg_1st_dep_date 1
					}
				} else {
					# they haven't made a successful deposit
					set match_rg_1st_dep_date 1
				}
				db_close $fd_rs
			}
		}
		db_close $rs

		# This is quite gross, but I only want the pertinent checks in the logs
		if {$check_rg_currency} {
			log 1 "match_rg_currency     = $match_rg_currency"
		}
		if {$check_rg_country} {
			log 1 "match_rg_country      = $match_rg_country"
		}
		if {$check_rg_ip_address} {
			log 1 "match_rg_ip_address   = $match_rg_ip_address"
		}
		if {$check_rg_card_bin} {
			log 1 "match_rg_card_bin     = $match_rg_card_bin"
		}
		if {$check_rg_reg_date} {
			log 1 "match_rg_reg_date     = $match_rg_reg_date"
		}
		if {$check_rg_1st_dep_date} {
			log 1 "match_rg_1st_dep_date = $match_rg_1st_dep_date"
		}

		if {($check_rg_currency     && !$match_rg_currency) ||
			($check_rg_country      && !$match_rg_country) ||
			($check_rg_ip_address   && !$match_rg_ip_address) ||
			($check_rg_card_bin     && !$match_rg_card_bin) ||
			($check_rg_reg_date     && !$match_rg_reg_date) ||
			($check_rg_1st_dep_date && !$match_rg_1st_dep_date)} {
			log 1 "All conditions not matched.  Allow transaction."
			return 1
		}
		log 1 "Passing to Risk Guardian"
	}

	# Get extra customer info needed for Risk Guardian request
	set result [get_cust_info RG]
	if {[lindex $result 0] == 0} {
		# Failure in getting customer info for Risk Guardian
		set msg [lindex $result 1]
		log 1 "ERROR: Failure in getting customer info for Risk Guardian: $msg"
		return 1
	}

	# Return values for the payment gateway
	set RG(gw_ret_msg)  ""
	set RG(order_no)    ""
	set RG(rgid)        ""
	set RG(tscore)      ""
	set RG(trisk)       ""

	# Flag to use for checking we are doing a Risk Guardian call rather than
	# just a standard TrustMarque payment request
	set RG(risk_guardian) 1

	# Make call to Risk Guardian
	set result [trustmarque::make_trustmarque_call RG]

	# unset data from tRGHost in array to be safe.
	unset RG(rg_host_id)
	unset RG(client)
	unset RG(password)
	unset RG(mid)
	unset RG(key)
	unset RG(host)
	unset RG(port)
	unset RG(resp_timeout)
	unset RG(conn_timeout)

	if {$result == "OK"} {
		# now need to take the results and if trisk is higher
		# than tscore store some info in tRGFailure.
		if {$RG(tscore) > $RG(trisk)} {
			log 1 "tscore > trisk.  $RG(tscore) > $RG(trisk).  Don't allow transaction."
			if [catch [tb_db::tb_exec_qry rg_insert_failure $RG(cust_id) $RG(amount) $RG(order_no) $RG(rgid) $RG(tscore) $RG(trisk)] msg] {
				log 1 "Error inserting risk guardian failure data: $msg"
			}
			return 0
		}
		log 1 "tscore < trisk.  $RG(tscore) < $RG(trisk).  Allow transaction."

	} else {

		log 1 "ERROR: result != OK.  result == '$result'.  Allow transaction."
	}

	return 1
}



# ----------------------------------------------------------------------
# Translates the RG error code into the associated message
#
# Param
#      code_id - the unique identifier of an error code
#
# ----------------------------------------------------------------------
proc riskGuardian::xlate_err_code {code_id} {

	variable RG_ERR_CODES

	if {[info exists RG_ERR_CODES($code_id)]} {
		return $RG_ERR_CODES($code_id)
	}
	return $code_id

}



# ----------------------------------------------------------------------
# Retrieve the extra customer information needed for a Risk Guardian
# request over a standard payment request.
#
# Param
#      ARRAY  - the RG array used in to store details for sending
#               the Risk Guardian Request
# ----------------------------------------------------------------------
proc riskGuardian::get_cust_info {ARRAY} {

	upvar $ARRAY RG

	if [catch {set rs [tb_db::tb_exec_qry rg_get_cust_info $RG(cust_id)]} msg] {
	  log 1 "Error retrieving customer account information for Risk Guardian: $msg"
	  return [list 0 $msg]
	}

	if {[db_get_nrows $rs] != 1} {
	  db_close $rs
	  return [list 0 [riskGuardian::xlate_err_code PMT_NO_CUST_DETAILS] PMT_NO_CUST_DETAILS]
	}

	set cdate [split [db_get_col $rs 0 cdate] "-"]
	set rdate [split [db_get_col $rs 0 rdate] "-"]

	set num_years  [expr {[lindex $cdate 0] - [lindex $rdate 0]}]

	# strip leading 0's for arithmetic
	set cdate_month [lindex $cdate 1]
	if {[string index $cdate_month 0] == 0} {
	  set cdate_month [string index $cdate_month 1]
	}
	set rdate_month [lindex $rdate 1]
	if {[string index $rdate_month 0] == 0} {
	  set rdate_month [string index $rdate_month 1]
	}

	set num_months [expr {$cdate_month - $rdate_month}]
	set num_months [expr {$num_years * 12 + $num_months}]

	set RG(acct_name)    [db_get_col $rs 0 fullname]
	set RG(is_member)    $num_months
	set RG(title)        [db_get_col $rs 0 title]
	set RG(first_name)   [db_get_col $rs 0 fname]
	set RG(last_name)    [db_get_col $rs 0 lname]
	set RG(acct_no)      [db_get_col $rs 0 acct_no]
	set RG(address1)     [db_get_col $rs 0 addr_street_1]
	set RG(address2)     [db_get_col $rs 0 addr_street_2]
	set RG(address3)     [db_get_col $rs 0 addr_street_3]
	set RG(city)         [db_get_col $rs 0 addr_city]
	set RG(zipcode)      [db_get_col $rs 0 addr_postcode]
	set RG(country_code) [db_get_col $rs 0 country_code]
	set RG(phone_number) [db_get_col $rs 0 telephone]
	set RG(email)        [db_get_col $rs 0 email]

	set RG(REMOTE_ADDR)          [reqGetEnv REMOTE_ADDR]
	set RG(HTTP_USER_AGENT)      [reqGetEnv HTTP_USER_AGENT]
	set RG(HTTP_ACCEPT_LANGUAGE) [reqGetEnv HTTP_ACCEPT_LANGUAGE]
	set RG(HTTP_ACCEPT_CHARSET)  [reqGetEnv HTTP_ACCEPT_CHARSET]
	set RG(HTTP_REFERER)         [reqGetEnv HTTP_REFERER]

	db_close $rs

	return [list 1]
}



# ----------------------------------------------------------------------
# Get the details of the Trustmarque RiskGuardian account.
# ----------------------------------------------------------------------
proc riskGuardian::get_acct {ARRAY} {

	variable RG_GTWY
	variable RG_SHM_CACHE

	log 5 "==> get_acct"

	upvar $ARRAY RG

	if [catch {set rs [tb_db::tb_exec_qry rg_get_acct]} msg] {
		log 1 "ERROR: Error reading risk guardian account: $msg"
		return [list 0 $msg]
	}

	if {[db_get_nrows $rs] == 0} {
		log 1 "ERROR: Could not find risk guardian account or it is marked suspended"
		db_close $rs
		return [list 0 "Could not find risk guardian account"]
	} elseif {[db_get_nrows $rs] > 1} {
		log 1 "ERROR: More than one active risk guardian account found"
		db_close $rs
		return [list 0 "More than one active risk guardian account found"]
	}

	set RG(rg_host_id)     [db_get_col $rs 0 rg_host_id]

	set enc_db_vals    [list]
	set enc_db_rg_name [list]
	set enc_db_col     [list]

	# Required values for decryption
	foreach {col col_ivec rg_name} [list \
		enc_client          enc_client_ivec      client \
		enc_password        enc_password_ivec    password \
		enc_key             enc_key_ivec         key \
		enc_mid             enc_mid_ivec         mid] {

		set col_val       [db_get_col $rs 0 $col]
		set col_ivec_val  [db_get_col $rs 0 $col_ivec]

		set shm_found 0

		if {$RG_SHM_CACHE} {
			if {![catch {set RG($rg_name) [asFindString RG_${RG(rg_host_id)}_${col}_${col_val}_${col_ivec_val}]} msg]} {
				set shm_found 1
			}
		}

		if {!$shm_found} {
			lappend enc_db_vals    [list $col_val $col_ivec_val]
			lappend enc_db_col     $col
			lappend enc_db_rg_name $rg_name
		}
	}

	if {[llength $enc_db_rg_name]} {

		set data_key_id [db_get_col $rs 0 data_key_id]

		set decrypt_rs  [card_util::batch_decrypt_db_row \
			$enc_db_vals \
			$data_key_id \
			$RG(rg_host_id) \
			"tRGHost"]

		if {[lindex $decrypt_rs 0] == 0} {
			log 1 "Error decrypting risk guardian acct info; [lindex $decrypt_rs 1]"
			return [list 0 [lindex $decrypt_rs 1]]
		} else {
			set decrypted_vals [lindex $decrypt_rs 1]
		}

		set result_index 0

		foreach col $enc_db_col {
			set dec_val [lindex $decrypted_vals $result_index]
			set RG([lindex $enc_db_rg_name $result_index]) $dec_val

			if {$RG_SHM_CACHE} {

				set enc_val      [lindex [lindex $enc_db_vals $result_index] 0]
				set enc_ivec_val [lindex [lindex $enc_db_vals $result_index] 1]

				asStoreString \
					$dec_val \
					RG_${RG(rg_host_id)}_${col}_${enc_val}_${enc_ivec_val} \
					[OT_CfgGet RISK_GUARDIAN_SHM_CACHE_TIME 1800]
			}

			incr result_index
		}
	}

	set RG(host)           [db_get_col $rs 0 rg_ip]
	set RG(port)           [db_get_col $rs 0 rg_port]
	set RG(resp_timeout)   [db_get_col $rs 0 resp_timeout]
	set RG(conn_timeout)   [db_get_col $rs 0 conn_timeout]

	db_close $rs

	return [list 1]
}



#-------------------------------------------------------
# Decrypts payment gateway parameters stored in
# database
#
# This just wraps the same procs used
# for decrypting credit card numbers
#-------------------------------------------------------
proc riskGuardian::decrypt {value} {
	return [card_util::card_decrypt $value 0 0]
}
