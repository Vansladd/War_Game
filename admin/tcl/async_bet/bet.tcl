# $Id: bet.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Admin
# Asynchronous Betting - Handle the display of a 'parked/pending' bet
#
# NOTE: The initial implementation to meet Paradise Bet's requirements,
#       therefore, does not handle each-way, starting-price, etc.
#
# Configuration:
#   ASYNC_BET_REASON_CODE_GROUP      reason XLate group (Async.Bet)
#
# Procedures:
#   ::ADMIN::ASYNC_BET::H_search       play search page
#   ::ADMIN::ASYNC_BET::H_do_search    search pending/parked bets
#   ::ADMIN::ASYNC_BET::H_bet          display pending/parked bets
#   ::ADMIN::ASYNC_BET::H_hist         play view async bet history page
#   ::ADMIN::ASYNC_BET::GetWinFactor   Check the new offer proposed in the bet
#                                      details screen
#

# Namespace
#
namespace eval ::ADMIN::ASYNC_BET {

	asSetAct ADMIN::ASYNC_BET::GoHist           ::ADMIN::ASYNC_BET::H_hist
	asSetAct ADMIN::ASYNC_BET::DoHist           ::ADMIN::ASYNC_BET::H_do_hist
	asSetAct ADMIN::ASYNC_BET::DoCatSave        ::ADMIN::ASYNC_BET::H_do_cat_save

	asSetAct ADMIN::ASYNC_BET::GoBet            ::ADMIN::ASYNC_BET::H_bet
	asSetAct ADMIN::ASYNC_BET::GoUpdateExpTime  ::ADMIN::ASYNC_BET::H_upd_exp_time
	asSetAct ADMIN::ASYNC_BET::GoStylesheet     {sb_null_bind async_bet/style.css}
	asSetAct ADMIN::ASYNC_BET::GoScript         {sb_null_bind async_bet/script.js}
	
	asSetAct ADMIN::ASYNC_BET::GetWinFactor     ::ADMIN::ASYNC_BET::get_win_factor

	variable CATEGORY_FILTER_COOKIE_NAME
	variable CUST_EV_LVL_LIMIT

	set CATEGORY_FILTER_COOKIE_NAME \
		[OT_CfgGet ASYNC_CATEGORY_FILTER_COOKIE_NAME "AsyncCategoryFilterOptions"]
}



#--------------------------------------------------------------------------
# Action Handlers
#--------------------------------------------------------------------------


# Play the Async' Betting History Page
#
proc ::ADMIN::ASYNC_BET::H_hist args {

	global DB ASYNC_USERS LIAB_GROUP REFERRAL_RULE CUSTOMER_RESPONSES CHAN

	variable CATEGORY_FILTER_COOKIE_NAME

	if {![op_allowed ViewAsyncBetsHist]} {
		_err_bind "You do not have permission to view Auto-referral Bet History"
		asPlayFile -nocache async_bet/hist.html
		return
	}

	# if we have the view async bet history functionality then bind up
	# the extra data needed
	if {[OT_CfgGet FUNC_VIEW_ASYNC_HIST 0] == 1} {
		# get list of those with 'ManageAsyncBets' permission
		set sql {
			select
				u.user_id,
				u.username
			from
				tAdminUser u,
				tAdminUserOp o
			where
				  u.user_id = o.user_id
			and o.action = 'ManageAsyncBets'
			union
			select distinct
				u.user_id,
				u.username
			from
				tAdminUser u,
				tAdminUserGroup g,
				tAdminGroupOp o
			where
				  u.user_id = g.user_id
			and g.group_id = o.group_id
			and o.action = 'ManageAsyncBets'
			order by 2
		}

		set stmt  [inf_prep_sql $DB $sql]
		set res   [inf_exec_stmt $stmt]
		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set ASYNC_USERS($i,user_id)  [db_get_col $res $i user_id]
			set ASYNC_USERS($i,username) [db_get_col $res $i username]
		}

		db_close $res

		# bind up the users
		tpSetVar  NumAsyncUsers $nrows
		tpBindVar UserId   ASYNC_USERS user_id  async_user_idx
		tpBindVar UserName ASYNC_USERS username async_user_idx

		# bind the event categories
		_bind_ev_categories

		# bind liability groups
		set sql {
			select
				disp_order,
				liab_group_id,
				liab_desc,
				colour
			from
				tLiabGroup
			order by 1
		}
	
		# execute the query
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	
		set nrows [db_get_nrows $rs]
	
		array set LIAB_GROUP [list]
	
		for {set i 0} {$i < $nrows} {incr i} {
			set LIAB_GROUP($i,liab_group_id)        [db_get_col $rs $i liab_group_id]
			set LIAB_GROUP($i,liab_desc)            [db_get_col $rs $i liab_desc]
		}
		db_close $rs

		tpSetVar NumLiabGroups $nrows
		tpBindVar LiabGroupId          LIAB_GROUP liab_group_id liab_group_idx
		tpBindVar LiabGroupDesc        LIAB_GROUP liab_desc     liab_group_idx

		# bind referral reasons
	
		array set REFERRAL_RULE [list]
		set referral_codes_and_reasons {
			ASYNC_PARK_SPL_GT_CUST_MAX_BET			"Exceeds maximum bet for this customer"
			ASYNC_PARK_BET_EXCEEDS_LIAB_LIMIT		"Bet exceeds liability on the market"
			ASYNC_PARK_STK_GT_ASYNC_RULE1			"Exceeds maximum bet in Async Rule 1"
			ASYNC_PARK_STK_GT_LIAB_GRP_INTERCEPT		"Limits for this clients liability group breached"}
		
		if {[OT_CfgGet FUNC_ASYNC_BET_RULES]} {
			append referral_codes_and_reasons {
				ASYNC_PARK_MKT_LIAB_GT_ASYNC_RULE_LIAB		ASYNC_PARK_MKT_LIAB_GT_ASYNC_RULE_LIAB
				ASYNC_PARK_BET_PAYOUT_GT_ASYNC_MAX_PAYOUT	ASYNC_PARK_BET_PAYOUT_GT_ASYNC_MAX_PAYOUT
				ASYNC_PARK_SPL_GT_RISKY_LEG_BET_LMT		ASYNC_PARK_SPL_GT_RISKY_LEG_BET_LMT
				ASYNC_PARK_BET_WIN_GT_RISKY_LEG_WIN_LMT		ASYNC_PARK_BET_WIN_GT_RISKY_LEG_WIN_LMT}
		}

		set i 0
		foreach {code reason} $referral_codes_and_reasons {
			set REFERRAL_RULE($i,referral_rule_code)   $code
			set REFERRAL_RULE($i,referral_rule_reason) $reason
			incr i
		}

		tpSetVar  NumReferralRules [expr [array size REFERRAL_RULE] / 2]
		tpBindVar ReferralRuleCode          REFERRAL_RULE referral_rule_code    referral_rule_idx
		tpBindVar ReferralRuleReason        REFERRAL_RULE referral_rule_reason  referral_rule_idx


		# Bind channels
		tpSetVar NumChannels [_bind_channels CHAN]
		
		# Bind Customer Reponses
		tpSetVar NumCustomerResponses [_bind_customer_responses CUSTOMER_RESPONSES]

		# get stored categories preferred for this user from the cookie
		set cookie [get_cookie $CATEGORY_FILTER_COOKIE_NAME]
		set params [split $cookie "|"]
		set len    [llength $params]

		for {set i 0} {$i < $len} {incr i} {
			# remove spaces, '-' and '*'
			set cat_name [string map {{ } {} {-} {} {*} {}} [lindex $params $i]]
			tpBindString "${cat_name}Checked" 1
		}

		tpBindString rejected "on"
		tpBindString limited  "on"
		tpBindString accepted "on"
		tpBindString timedout "on"

	}

	asPlayFile -nocache async_bet/hist.html
	
	catch {unset CUSTOMER_RESPONSES}
	catch {unset CHAN}

}

# Save category filter options to cookie for async bet history search
#
proc ::ADMIN::ASYNC_BET::H_do_cat_save args {

	variable CATEGORY_FILTER_COOKIE_NAME

	set params [list]
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[string first "cat_" [reqGetNthName $i]] != -1} {
			# found one of the category checkboxes, is it checked?
			if {[reqGetNthVal $i] == 1} {
				set cat_name [string range [reqGetNthName $i] 4 end]
				lappend params $cat_name

				# remove spaces
				set cat_name [string map {{ } {}} $cat_name]
				tpBindString "${cat_name}Checked" 1
			}
		}
	}

	if {[llength $params] > 0} {
		set exp [clock scan "01/01/2037"]
		ob_util::set_cookie_domain {}
		ob_util::set_cookie $CATEGORY_FILTER_COOKIE_NAME=[join $params "|"] "/" 0 $exp
	}

}



# Perform an Asynchronous Betting History Search
# Search for bets which have been handled by the async betting module
#
proc ::ADMIN::ASYNC_BET::H_do_hist args {

	global DB ASYNC_HIST

	if {![op_allowed ViewAsyncBetsHist]} {
		_err_bind "You do not have permission to view Auto-referral Bet History"
		catch {unset ASYNC_HIST}
		asPlayFile -nocache async_bet/hist.html
		return
	}

	# User filter
	set user_id [reqGetArg user_id]
	if {$user_id != "ALL" && $user_id != "System"} {
		set user_sql "and a.user_id = $user_id"
	} else {
		set user_sql ""
	}

	# Date filter
	set hist_time_range [reqGetArg hist_time_range]
	set date_from [reqGetArg hist_from]
	set date_to   [reqGetArg hist_to]

	if {($date_from == "" && $date_to == "") || $hist_time_range != ""} {
		# using one of the preset dropdown values
		set now [clock seconds]

		switch -exact -- $hist_time_range {
			"L24" {
				set date_from [expr {$now - ([clock scan "24 hours"] - $now)}]
			}
			"L12" {
				set date_from [expr {$now - ([clock scan "12 hours"] - $now)}]
			}
			"L6" {
				set date_from [expr {$now - ([clock scan "6 hours"] - $now)}]
			}
		}
		set date_from [clock format $date_from -format "%Y-%m-%d %H:%M:%S"]
		set date_sql "and b.cr_date > \"$date_from\""

	} else {
		# using specific dates
		set date_sql ""

		if {$date_from != ""} {
			append date_sql " and b.cr_date > \"$date_from\""
		}
		if {$date_to != ""} {
			append date_sql " and b.cr_date < \"$date_to\""
		}
	}


	# Action filter
	set accepted   [reqGetArg accepted]
	set rejected   [reqGetArg rejected]
	set limited    [reqGetArg limited]
	set timedout   [reqGetArg timedout]
	set cancelled  [reqGetArg cancelled]
	set overridden [reqGetArg overridden]

	# if we're after the system user, this is the same as just having timedout
	# ticked on the filter
	if {$user_id == "System"} {
		set timedout   1
		set rejected   0
		set limited    0
		set accepted   0
		set cancelled  0
		set overridden 0
	}
	
	# Accept Status / Customer Response filter
	set accept_status [reqGetArg accept_status]
	set accept_status_sql ""
	if {$accept_status != ""} {
		set accept_status_sql "and a.accept_status='$accept_status'"
	}
	
	# Channel filter
	set channel [reqGetArg channel]
	set channel_sql ""
	if {$channel != ""} {
		set channel_sql "and b.source='$channel'"
	}
	
	ob_log::write DEV "sql = $accept_status_sql / $channel_sql"
	

	# javascript validation means we must have at least one of the status codes
	set status_sql "and (a.status == "
	set first_part_done 0
	if {$accepted == 1} {
		append status_sql "\"A\""
		set first_part_done 1
	}
	if {$rejected == 1} {
		if {$first_part_done} {
			append status_sql " or a.status = \"D\""
		} else {
			append status_sql "\"D\""
			set first_part_done 1
		}
	}
	if {$limited == 1} {
		if {$first_part_done} {
			append status_sql " or a.status == \"S\""
		} else {
			append status_sql "\"S\""
			set first_part_done 1
		}
		append status_sql " or a.status == \"P\" or a.status == \"B\""
	}
	if {$timedout == 1} {
		if {$first_part_done} {
			append status_sql " or a.status == \"T\""
		} else {
			append status_sql "\"T\""
		}
	}
	if {$cancelled == 1} {
		if {$first_part_done} {
			append status_sql " or a.status == \"C\""
		} else {
			append status_sql "\"C\""
		}
	}
	if {$overridden == 1} {
		if {$first_part_done} {
			append status_sql " or a.status = 'O'"
		} else {
			append status_sql "'O'"
		}
	}
	append status_sql ")"

	# Customer username filter
	set username_sql ""
	if {[string length [set name [reqGetArg username]]] > 0} {

		if {[reqGetArg LBOCustomer] == "Y"} {
			# Shop account usernames are all preceded by 1 space
			set name " [string trimleft $name]"
		}

		if {[reqGetArg exact_name] == "Y"} {
			set op =
		} else {
			set op like
			append name %
		}

		if {[reqGetArg upper_name] == "Y"} {
			append username_sql "and s.username_uc $op \"[string toupper ${name}]\""
		} else {
			append username_sql "and s.username $op \"${name}\""
		}
	}

	# Account number filter
	set acctno_sql ""
	if {[string length [set acctno [reqGetArg acct_no]]] > 0} {
		if {[reqGetArg exact_acct_no] == "Y"} {
			set op =
		} else {
			set op like
			append acctno %
		}

		set acctno [string toupper $acctno]

		if {[reqGetArg upper_acct_no] == "Y"} {
			append acctno_sql "and s.acct_no $op \"$acctno\""
		} else {
			append acctno_sql "and s.acct_no $op \"${acctno}\""
		}
	}

	# Bet Receipt filter
	set bet_sql ""
	if {[string length [set receipt [string toupper [reqGetArg bet_receipt]]]] > 0} {

		set inet_rxp {O/([0-9]+)/([0-9]+)}
		set bet_rxp  {^#([0-9]+)$}

		if {[regexp $inet_rxp $receipt all cust count]} {
			append bet_sql "and b.receipt like '${receipt}%'"
		} elseif {[regexp $bet_rxp $receipt all bet_id]} {
			append bet_sql "and b.bet_id = $bet_id"
		} else {
			append bet_sql "and b.receipt like '${receipt}%'"
		}
	}

	#
	# Bet stake filter
	#
	set stake_sql ""
	if {([string length [set s1 [reqGetArg stake_1]]] > 0) && ([string length [set s2 [reqGetArg stake_2]]] > 0)} {
		append stake_sql "and "
		append stake_sql [mk_between_clause b.stake number $s1 $s2]
	}

	#
	# U stake filter
	#
	set u_stake_sql ""
	if {([string length [set s1 [reqGetArg u_stake_1]]] > 0) && ([string length [set s2 [reqGetArg u_stake_2]]] > 0)} {
		append u_stake_sql "and "
		append u_stake_sql [mk_between_clause "(b.stake / b.num_lines)" number $s1 $s2]
	}

	#
	# Liability filter
	#
	set liab_group_sql ""
	if {[string length [set liab_group_id [string toupper [reqGetArg liab_group_id]]]] > 0} {
		append liab_group_sql "and s.liab_group = \"$liab_group_id\""
	}

	#
	# Referral rule
	#
	set referral_rule_sql ""
	if {[string length [set referral_rule_code [string toupper [reqGetArg referral_rule_code]]]] > 0} {
		append referral_rule_sql "and a.park_reason = \"$referral_rule_code\""
	}
	
	# get the selected categories, javascript validation means we have at least one
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		if {[string first "cat_" [reqGetNthName $i]] != -1} {
			# found one of the category checkboxes, is it checked?
			if {[reqGetNthVal $i] == 1} {
				lappend categories [string range [reqGetNthName $i] 4 end]
			}
		}
	}

	for {set i 0} {$i < [llength $categories]} {incr i} {
		if {$i == 0} {
			set cat_sql "(\"[lindex $categories $i]\""
		} else {
			append cat_sql ",\"[lindex $categories $i]\""
		}
	}
	append cat_sql ")"

	set sql [subst {
		select
			u.username,
			b.cr_date as bet_placed,
			a.cr_date as bet_actioned,
			a.status as action,
			a.accept_status,
			a.org_stake_per_line,
			a.off_stake_per_line,
			b.receipt,
			s.acct_no,
			g.fname,
			g.lname,
			b.bet_id,
			b.source,
			t.cust_id,
			case
				when r.price_type = 'S'
			then
				NVL(r.o_num/r.o_den, 'SP')
			else
				NVL(r.o_num/r.o_den, '-')
			end as price,
			r.o_num,
			r.o_den,
			NVL(b.potential_payout,'-') as payout,
			o.desc as selection,
			b.bet_type,
			e.start_time,
			y.exch_rate,
			b.num_lines,
			a.reason_code,
			a.park_reason,
			r.leg_no,
			r.part_no,
			s.cust_id
		from
			tAsyncBetOff a,
			tAdminUser u,
			tOBet r,
			tBet b,
			tAcct t,
			tCcy y,
			tCustomer s,
			tCustomerReg g,
			tEvOc o,
			tEv e
		where
			  a.bet_id      = b.bet_id
		and r.bet_id      = b.bet_id
		and r.ev_oc_id    = o.ev_oc_id
		and o.ev_id       = e.ev_id
		and b.acct_id     = t.acct_id
		and t.cust_id     = s.cust_id
		and s.cust_id     = g.cust_id
		and a.user_id     = u.user_id
		and t.ccy_code    = y.ccy_code
		and a.accept_status != 'O'
		and exists (
			select 1 from
				tOBet o2,
				tEvOc oc2,
				tEv   e2,
				tEvClass c2
			where
				o2.bet_id = b.bet_id
			and o2.ev_oc_id = oc2.ev_oc_id
			and oc2.ev_id = e2.ev_id
			and e2.ev_class_id = c2.ev_class_id
			and c2.category in $cat_sql
		)
		$date_sql
		$user_sql
		$status_sql
		$username_sql
		$acctno_sql
		$bet_sql
		$stake_sql
		$u_stake_sql
		$liab_group_sql
		$referral_rule_sql
		$accept_status_sql
		$channel_sql
		order by
			2 desc, 11 desc, 23, 24
	}]

	set xl_sql1 {
		select
			v.xlation_1
		from
			tXLateCode x,
			tXLateVal v
		where
			  x.code_id = v.code_id
		and x.code = ?
		and v.lang = 'en'
	}

	set xl_sql2 {
		select
			v.xlation_1
		from
			tXLateCode x,
			tXLateVal v
		where
			  x.code_id = v.code_id
		and x.code_id = ?
		and v.lang = 'en'
	}

	set liab_sql {
		select first 1
			lg.liab_desc,
			lg.colour as liab_colour
		from
			tCustomer_Aud ca,
			tLiabGroup lg
		where
			  ca.cust_id = ?
		and ca.aud_time < ?
		and lg.liab_group_id = ca.liab_group
		order by
			ca.aud_order desc
	}

	set oprice_sql {
		select
			org_price_type,
			off_price_type,
			org_p_num,
			org_p_den,
			off_p_num,
			off_p_den
		from
			tAsyncBetLegOff
		where
			bet_id = ?
	}

	set xl_stmt1 [inf_prep_sql $DB $xl_sql1]
	set xl_stmt2 [inf_prep_sql $DB $xl_sql2]

	set liab_stmt [inf_prep_sql $DB $liab_sql]

	set oprice_stmt [inf_prep_sql $DB $oprice_sql]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $res]

	set prev_bet_id ""
	set r 0

	for {set i 0} {$i < $nrows} {incr i} {

		set bet_id [db_get_col $res $i bet_id]

		set bet_placed   [db_get_col $res $i bet_placed]
		set bet_actioned [db_get_col $res $i bet_actioned]
		set start_time   [db_get_col $res $i start_time]

		if {[OT_CfgGet FUNC_REVERSE_DATEFORMAT 0] == 1} {
			set bet_placed   [clock format [clock scan $bet_placed] -format "%H:%M:%S %d-%m-%Y"]
			set bet_actioned [clock format [clock scan $bet_actioned] -format "%H:%M:%S %d-%m-%Y"]
			set start_time   [clock format [clock scan $start_time] -format "%H:%M:%S %d-%m-%Y"]
		}

		set num_lines [db_get_col $res $i num_lines]

		# Make a decimal format price and a fractional price
		set price       [db_get_col $res $i price]
		set o_num       [db_get_col $res $i o_num]
		set o_den       [db_get_col $res $i o_den]

		if {$price != "-" && $price != "SP"} {
			set price   [ob_price::mk_dec [expr {$price + 1.0}] "DECIMAL"]
			set fprice  [mk_price $o_num $o_den]
		} else {
			set fprice  $price
		}

		set oprice_res  [inf_exec_stmt $oprice_stmt $bet_id]
		set op_nrows    [db_get_nrows $oprice_res]

		if {$op_nrows > 0} {
			set org_price_type [db_get_col $oprice_res 0 org_price_type]
			set off_price_type [db_get_col $oprice_res 0 off_price_type]
			set org_p_num   [db_get_col $oprice_res 0 org_p_num]
			set org_p_den   [db_get_col $oprice_res 0 org_p_den]
			set off_p_num   [db_get_col $oprice_res 0 off_p_num]
			set off_p_den   [db_get_col $oprice_res 0 off_p_den]
			if {$org_price_type == "S"} {
				set org_price "SP"
			} elseif {$org_p_num != "" && $org_p_den != ""} {
				set org_price "[mk_price $org_p_num $org_p_den]"
			} else {
				set org_price "-"
			}
			if {$off_price_type == "S"} {
				set off_price "SP"
			} elseif {$off_p_num != "" && $off_p_den != ""} {
				set off_price "[mk_price $off_p_num $off_p_den]"
			} else {
				set off_price "-"
			}
		} else {
			set org_price $fprice
			set off_price $fprice
		}

		# escape quotes in selection name
		set selection [db_get_col $res $i selection]
		set selection [string map {{'} {\'} {"} {\"}} $selection]

		# sort out if this is a multiple bet (has > 1 row in tOBet) or not
		# we only want one entry in the ASYNC_HIST array per bet
		if {$prev_bet_id != $bet_id} {

			set curr_bet_main_idx $r

			if {[db_get_col $res $i action] == "T"} {
				set ASYNC_HIST($r,username) "System"
			} else {
				set username [db_get_col $res $i username]
				# split usernames on '.' characters so we can get word wrapping
				set username [split $username "."]
				set username [join $username " "]
				set ASYNC_HIST($r,username) $username
			}

			# adjust payout/stake values to system currency
			set exch_rate [db_get_col $res $i exch_rate]

			set payout [db_get_col $res $i payout]
			if {$payout != "" && $payout != "-"} {
				set payout [expr {$payout / $exch_rate}]
				set payout [format "%.2f" $payout]
			}

			set org_stake_per_line [db_get_col $res $i org_stake_per_line]
			if {$org_stake_per_line != ""} {
				set org_stake [expr {($org_stake_per_line * $num_lines) / $exch_rate}]
				set org_stake [format "%.2f" $org_stake]
			} else {
				set org_stake "-"
			}

			set off_stake_per_line [db_get_col $res $i off_stake_per_line]
			if {$off_stake_per_line != ""} {
				set off_stake [expr {($off_stake_per_line * $num_lines) / $exch_rate}]
				set off_stake [format "%.2f" $off_stake]
			} else {
				set off_stake "-"
			}

			# sort out what to display for selection for a multiple bet
			set bet_type [db_get_col $res $i bet_type]

			# get message translations
			set xl_res1 [inf_exec_stmt $xl_stmt1 [db_get_col $res $i park_reason]]
			set xl_res2 [inf_exec_stmt $xl_stmt2 [db_get_col $res $i reason_code]]

			if {[db_get_nrows $xl_res1] == 1} {
				set ASYNC_HIST($r,intercept_reason) [db_get_col $xl_res1 0 xlation_1]
			} else {
				set ASYNC_HIST($r,intercept_reason) [db_get_col $res $i park_reason]
			}
			db_close $xl_res1

			if {[db_get_nrows $xl_res2] == 1} {
				set ASYNC_HIST($r,reject_reason) [db_get_col $xl_res2 0 xlation_1]
			} else {
				set ASYNC_HIST($r,reject_reason) [db_get_col $res $i reason_code]
			}

			# get liability group at the time the bet was placed
			set cust_id  [db_get_col $res $i cust_id]
			set liab_res [inf_exec_stmt $liab_stmt $cust_id [db_get_col $res $i bet_placed]]

			if {[db_get_nrows $liab_res] == 1} {
				set ASYNC_HIST($r,liab_group)  [db_get_col $liab_res 0 liab_desc]
				set ASYNC_HIST($r,liab_colour) [db_get_col $liab_res 0 liab_colour]
			} else {
				set ASYNC_HIST($r,liab_group)  ""
				set ASYNC_HIST($r,liab_colour) "black"
			}

			# escape quotes in names
			set firstname [string map {{'} {\'} {"} {\"}} [db_get_col $res $i fname]]
			set lastname  [string map {{'} {\'} {"} {\"}} [db_get_col $res $i lname]]

			set ASYNC_HIST($r,bet_placed)         $bet_placed
			set ASYNC_HIST($r,bet_actioned)       $bet_actioned
			set ASYNC_HIST($r,action)             [db_get_col $res $i action]
			set ASYNC_HIST($r,accept_status)      [db_get_col $res $i accept_status]
			set ASYNC_HIST($r,org_stake)          $org_stake
			set ASYNC_HIST($r,off_stake)          $off_stake
			set ASYNC_HIST($r,receipt)            [db_get_col $res $i receipt]
			set ASYNC_HIST($r,acct_no)            [db_get_col $res $i acct_no]
			set ASYNC_HIST($r,firstname)          $firstname
			set ASYNC_HIST($r,lastname)           $lastname
			set ASYNC_HIST($r,bet_id)             [db_get_col $res $i bet_id]
			set ASYNC_HIST($r,channel)            [db_get_col $res $i source]
			set ASYNC_HIST($r,cust_id)            [db_get_col $res $i cust_id]
			set ASYNC_HIST($r,price)              $fprice
			set ASYNC_HIST($r,dprice)             $price
			set ASYNC_HIST($r,org_price)          $org_price
			set ASYNC_HIST($r,off_price)          $off_price
			set ASYNC_HIST($r,payout)             $payout
			set ASYNC_HIST($r,selection)          $selection
			set ASYNC_HIST($r,bet_type)           $bet_type
			set ASYNC_HIST($r,start_time)         $start_time

			incr r

		} else {
			set s $curr_bet_main_idx

			append ASYNC_HIST($s,selection) ",$selection"

			# If we have a multi-part leg, we ignore all except the first part
			# but for the first leg we do display the names and prices and
			# all the parts
			#
			if {[db_get_col $res $i part_no] > 1} {
				if {[db_get_col $res $i leg_no] == 1 && $ASYNC_HIST($s,price) != "-"} {
					set ASYNC_HIST($s,selection) "$ASYNC_HIST($s,selection) $selection"
					set ASYNC_HIST($s,price) "$ASYNC_HIST($s,price) $fprice"
				}
				continue
			}

			# build up price as we've got a multi
			if {$price != "-" && $price != "SP" && $ASYNC_HIST($s,dprice) != "-" && $ASYNC_HIST($s,dprice) != "SP"} {
				# convert the decimal result into fractional.
				set dec_price  [ob_price::mk_dec [expr {$ASYNC_HIST($s,dprice) * $price}] "DECIMAL"]
				set frac_price [dec2frac [expr {$dec_price - 1.0}]]
				set ASYNC_HIST($s,price) "[lindex $frac_price 0]/[lindex $frac_price 1]"
				set ASYNC_HIST($s,org_price) $ASYNC_HIST($s,price)
				set ASYNC_HIST($s,off_price) $ASYNC_HIST($s,price)
			}

			# use earliest start time
			set prev_arr [split $ASYNC_HIST($s,start_time) " "]
			set curr_arr [split $start_time " "]

			# clock scan wants the date in the format: mm/dd/yyyy hh:mi:ss
			if {[OT_CfgGet FUNC_REVERSE_DATEFORMAT 0] == 1} {
				set prev_date [split [lindex $prev_arr 1] "-"]
				set prev_time [lindex $prev_arr 0]

				set curr_date [split [lindex $curr_arr 1] "-"]
				set curr_time [lindex $curr_arr 0]

			} else {
				set prev_date [split [lindex $prev_arr 0] "-"]
				set prev_time [lindex $prev_arr 1]

				set curr_date [split [lindex $curr_arr 0] "-"]
				set curr_time [lindex $curr_arr 1]
			}

			set prev_date [list [lindex $prev_date 1] [lindex $prev_date 0] [lindex $prev_date 2]]
			set curr_date [list [lindex $curr_date 1] [lindex $curr_date 0] [lindex $curr_date 2]]

			set prev_date [join $prev_date "/"]
			set curr_date [join $curr_date "/"]

			set prev_start_time "$prev_date $prev_time"
			set curr_start_time "$curr_date $curr_time"

			if {$curr_start_time < $prev_start_time} {
				set ASYNC_HIST($s,start_time) $start_time
			}
		}

		set prev_bet_id $bet_id
	}

	db_close $res

	tpSetVar betCount $r

	_send_async_hist $r

}


# Private proc to send back the async bet history requested to
# the AJAX callback function
#
proc ::ADMIN::ASYNC_BET::_send_async_hist {nrows} {

	global ASYNC_HIST

	tpBufAddHdr "Content-Type" "text/html"

	# dummy div so we can grab this value for elsewhere in the HTML page
	tpBufWrite "<div id=betCountDummy>$nrows</div>"

	if {$nrows == 0} {
		tpBufWrite "<div id=accActionDummy></div>"
		tpBufWrite "<div id=rejActionDummy></div>"
		tpBufWrite "<div id=canActionDummy></div>"
		tpBufWrite "<div id=ltdActionDummy></div>"
		tpBufWrite "<div id=toActionDummy></div>"
		tpBufWrite "<div id=ovrActionDummy></div>"
		return
	}

	tpBufWrite "<table width=100% border=1 cellpadding=0 cellspacing=0>"
	tpBufWrite "<tr style=background-color:#0000ff;color:white;font-weight:bold>"

	tpBufWrite "<td width=90px align=center>"
	tpBufWrite "Selection"
	tpBufWrite "</td>"

	tpBufWrite "<td width=64px align=center>"
	tpBufWrite "Original Odds Offered"
	tpBufWrite "</td>"

	tpBufWrite "<td width=64px align=center>"
	tpBufWrite "Original Stake Amount"
	tpBufWrite "</td>"

	tpBufWrite "<td width=45px align=center>"
	tpBufWrite "Bet Type"
	tpBufWrite "</td>"

	tpBufWrite "<td width=75px align=center>"
	tpBufWrite "Client"
	tpBufWrite "</td>"

	tpBufWrite "<td width=60px align=center>"
	tpBufWrite "Acc #"
	tpBufWrite "</td>"

	tpBufWrite "<td width=64px align=center>"
	tpBufWrite "Limited Stake Amount"
	tpBufWrite "</td>"

	tpBufWrite "<td width=55px align=center>"
	tpBufWrite "Limited Odds Offered"
	tpBufWrite "</td>"

	tpBufWrite "<td width=80px align=center>"
	tpBufWrite "Payout"
	tpBufWrite "</td>"

	tpBufWrite "<td width=97px align=center>"
	tpBufWrite "Bet Receipt"
	tpBufWrite "</td>"

	tpBufWrite "<td width=79px align=center>"
	tpBufWrite "Bet Placed"
	tpBufWrite "</td>"

	tpBufWrite "<td width=79px align=center>"
	tpBufWrite "Start Time"
	tpBufWrite "</td>"

	tpBufWrite "<td width=42px align=center>"
	tpBufWrite "Liability Group"
	tpBufWrite "</td>"

	tpBufWrite "<td width=150px align=center>"
	tpBufWrite "Intercept Reason"
	tpBufWrite "</td>"

	tpBufWrite "<td width=79px align=center>"
	tpBufWrite "Bet Actioned"
	tpBufWrite "</td>"

	tpBufWrite "<td width=108px align=center>"
	tpBufWrite "Actioning Trader"
	tpBufWrite "</td>"

	tpBufWrite "<td width=47px align=center>"
	tpBufWrite "Action"
	tpBufWrite "</td>"

	tpBufWrite "<td width=95px align=center>"
	tpBufWrite "Reject Reason"
	tpBufWrite "</td>"

	tpBufWrite "<td width=95px align=center>"
	tpBufWrite "Accept Status"
	tpBufWrite "</td>"

	tpBufWrite "<td widht=42px align=center>"
	tpBufWrite "Channel"
	tpBufWrite "</td>"

	tpBufWrite "</tr>"

	set acc_action 0
	set rej_action 0
	set can_action 0
	set ltd_action 0
	set to_action  0
	set ovr_action 0

	for {set i 0} {$i < $nrows} {incr i} {
		tpBufWrite "<tr>"

		# Selection
		tpBufWrite "<td width=90px align=center>"
		tpBufWrite "$ASYNC_HIST($i,selection)"
		tpBufWrite "</td>"

		# Original Odds Offered
		tpBufWrite "<td width=55px align=center>"
		tpBufWrite "$ASYNC_HIST($i,org_price)"
		tpBufWrite "</td>"

		# Original Stake Amount
		tpBufWrite "<td width=64px align=center>"
		tpBufWrite "$ASYNC_HIST($i,org_stake)"
		tpBufWrite "</td>"

		# Bet Type
		tpBufWrite "<td width=45px align=center>"
		tpBufWrite "$ASYNC_HIST($i,bet_type)"
		tpBufWrite "</td>"

		# Client Name
		tpBufWrite "<td width=75px align=center>"
		tpBufWrite "$ASYNC_HIST($i,firstname) $ASYNC_HIST($i,lastname)"
		tpBufWrite "</td>"

		# Acct No
		tpBufWrite "<td width=60px align=center>"
		tpBufWrite "<a href=[OT_CfgGet CGI_URL]?action=ADMIN::CUST::GoCust&CustId=$ASYNC_HIST($i,cust_id)>$ASYNC_HIST($i,acct_no)</a>"
		tpBufWrite "</td>"

		# Limited Stake Amount
		tpBufWrite "<td width=64px align=center>"
		tpBufWrite "$ASYNC_HIST($i,off_stake)"
		tpBufWrite "</td>"

		# Limited Odds Offered
		tpBufWrite "<td width=55px align=center>"
		tpBufWrite "$ASYNC_HIST($i,off_price)&nbsp;"
		tpBufWrite "</td>"

		# Payout
		tpBufWrite "<td width=80px align=center>"
		tpBufWrite "$ASYNC_HIST($i,payout)"
		tpBufWrite "</td>"

		# Bet Receipt
		tpBufWrite "<td width=97px align=center>"
		tpBufWrite "<a href=[OT_CfgGet CGI_URL]?action=ADMIN::BET::GoBetReceipt&BetId=$ASYNC_HIST($i,bet_id)>$ASYNC_HIST($i,receipt)</a>"
		tpBufWrite "</td>"

		# Bet placed
		tpBufWrite "<td width=79px align=center>"
		tpBufWrite "$ASYNC_HIST($i,bet_placed)"
		tpBufWrite "</td>"

		# Start Time
		tpBufWrite "<td width=79px align=center>"
		tpBufWrite "$ASYNC_HIST($i,start_time)"
		tpBufWrite "</td>"

		# Liability Group
		tpBufWrite "<td width=42px align=center style=font-weight:bold;color:$ASYNC_HIST($i,liab_colour)>"
		tpBufWrite "$ASYNC_HIST($i,liab_group)&nbsp;"
		tpBufWrite "</td>"

		# Intercept Reason
		tpBufWrite "<td width=150px align=center>"
		tpBufWrite "$ASYNC_HIST($i,intercept_reason)&nbsp;"
		tpBufWrite "</td>"

		# Bet actioned
		tpBufWrite "<td width=79px align=center>"
		tpBufWrite "$ASYNC_HIST($i,bet_actioned)"
		tpBufWrite "</td>"

		# Actioning Bookmaker
		tpBufWrite "<td width=108px align=center>"
		tpBufWrite "$ASYNC_HIST($i,username)"
		tpBufWrite "</td>"

		# Action
		switch -exact -- $ASYNC_HIST($i,action) {
			"A" {
				tpBufWrite "<td width=47px align=center style=background-color:green>"
				tpBufWrite "ACC"
				incr acc_action
			}
			"D" {
				tpBufWrite "<td width=47px align=center style=background-color:red>"
				tpBufWrite "REJ"
				incr rej_action
			}
			"S" {
				tpBufWrite "<td width=47px align=center style=background-color:yellow>"
				tpBufWrite "LTD"
				incr ltd_action
			}
			"P" {
				tpBufWrite "<td width=47px align=center style=background-color:yellow>"
				tpBufWrite "LTD"
				incr ltd_action
			}
			"B" {
				tpBufWrite "<td width=47px align=center style=background-color:yellow>"
				tpBufWrite "LTD"
				incr ltd_action
			}
			"T" {
				tpBufWrite "<td width=47px align=center>"
				tpBufWrite "Timed Out"
				incr to_action
			}
			"C" {
				tpBufWrite "<td width=47px align=center style=background-color:grey>"
				tpBufWrite "Cancelled"
				incr can_action
			}
			"O" {
				tpBufWrite "<td width=47px align=center style=background-color:lightblue;>"
				tpBufWrite "Overridden"
				incr ovr_action
			}
		}
		tpBufWrite "</td>"

		# Reject Reason
		tpBufWrite "<td width=95px align=center>"
		tpBufWrite "$ASYNC_HIST($i,reject_reason)&nbsp;"
		tpBufWrite "</td>"
		
		# Accept Status
		tpBufWrite "<td width=95px align=center>"
		tpBufWrite "$ASYNC_HIST($i,accept_status)&nbsp;"
		tpBufWrite "</td>"

		# Channel
		tpBufWrite "<td width=42px align=center>"
		tpBufWrite "$ASYNC_HIST($i,channel)"
		tpBufWrite "</td>"

		tpBufWrite "</tr>"
	}
	tpBufWrite "</table>"

	tpBufWrite "<div id=accActionDummy>$acc_action</div>"
	tpBufWrite "<div id=rejActionDummy>$rej_action</div>"
	tpBufWrite "<div id=canActionDummy>$can_action</div>"
	tpBufWrite "<div id=ltdActionDummy>$ltd_action</div>"
	tpBufWrite "<div id=toActionDummy>$to_action</div>"
	tpBufWrite "<div id=ovrActionDummy>$ovr_action</div>"
}



# Display an Asynchronous Parked/Pending Bet
#
#    bet_id - denote we already have the bet details stored in the global ASYNC
#
proc ::ADMIN::ASYNC_BET::H_bet { {bet_id ""} } {

	global DB ASYNC LEG_SORT_DESC USERNAME USERID CUST_LAST_BETS CUST_TRADING_MSGS GROUP_BETS

	if {![op_allowed ViewAsyncBets]} {
		_err_bind "You do not have permission to view Asynchronous Bets"
		catch {unset ASYNC}
		asPlayFile -nocache async_bet/bet.html
		return
	}

	# get the async' timeout
	set async_timeout [_get_timeout]

	set confirm_lock  [reqGetArg confirm_lock]

	# get details for the selected bet, if not already (via search)
	if {$bet_id == ""} {
		set bet_id [reqGetArg bet_id]

		if {[OT_CfgGet FUNC_ASYNC_BET_DETAILS 0]} {

			# Get the lcok owener of the async. bet
			set owner [_get_lock_owner $bet_id]

			# If nobody owns the lock, attempt to grab the lock
			if {$owner == {}} {

				if {[catch {_update_lock $bet_id} msg]} {
					_err_bind "_update_lock finished with error: $msg"
				}
			}
		}

		if {[catch {_get_bet $bet_id} msg]} {
			_err_bind "_get_bet finished with error: $msg"
			catch {unset ASYNC}
			asPlayFile -nocache async_bet/bet.html
			return
		}
	}

	tpSetVar betId $bet_id

	if {[OT_CfgGet FUNC_ASYNC_BET_DETAILS 0]} {

		# Get the lcok owener of the async. bet
		set owner    [_get_lock_owner $bet_id]
		set own_lock [expr {[string equal $owner $USERID] ? 1:0}]

		if {$bet_id != {}} {

			if {[reqGetArg attempt_lock] == "Y"} {
				if {$own_lock || \
					$owner == {} || \
					$confirm_lock == "Y"} {

					# Attempt to get the lock
					if {[catch {_update_lock $bet_id} msg]} {
						_err_bind "_update_lock finished with error: $msg"
					} else {
						set own_lock 1
						set ASYNC(0,locked_by) $USERNAME
					}
				} else {
					# Set a template variable so page can confirm
					# if the user wants to take the lock from another user
					tpSetVar CONFIRM_ASYNC_BET_LOCK 1
				}

			} elseif {[reqGetArg attempt_unlock] == "Y"} {

				if {$own_lock} {
					# Attempt to reset the lock
					if {[catch {_update_lock $bet_id "Y"} msg]} {
						_err_bind "_update_lock finished with error: $msg"
					} else {
						set own_lock 0
						set ASYNC(0,locked_by) {}
					}
				} else {
					err_bind "Unlock failed, you do not currently have the lock on the bet"
				}
			}
		}

		tpSetVar own_lock $own_lock
	}

	# bind bet details
	foreach c $ASYNC(cols) {
		tpBindString $c $ASYNC(0,$c)
	}

	# figure out the remainig time for a bet to bet resolved
	tpBindString time_to_resolve [expr [clock scan $ASYNC(0,expiry_date)] - [format [clock scan now]]]

	# bind customer trading messages
	if {[info exists CUST_TRADING_MSGS(nrows)]} {
		foreach c $CUST_TRADING_MSGS(cols) {
			tpBindVar cust_msgs_${c} CUST_TRADING_MSGS $c cust_trading_msgs_idx
		}
	}

	# bind last bet customer details just if they have been retrieved
	if {[info exists CUST_LAST_BETS(nrows)]} {
		foreach c $CUST_LAST_BETS(cols) {
			tpBindVar cust_last_bets_${c} CUST_LAST_BETS $c cust_last_bets_idx
		}
	}

	# foreach leg get the ev-class, ev-type, event, ev-market and ev-outcome
	# details
	set sql {
		select
			b.leg_no,
		    b.part_no,
		    b.leg_sort,
		    b.ev_oc_id,
		    b.o_num,
		    b.o_den,
		    b.hcap_value,
		    b.bir_index,
		    b.in_running,
		    b.banker,
		    b.bets_per_seln,
		    b.price_type,
			b.ep_active,
			be.source,
		    be.leg_type,
		    be.bet_type,
		    o.desc            as oc_name,
		    o.status          as oc_status,
		    o.displayed       as oc_displayed,
		    o.disporder       as oc_disporder,
		    zo.stk_or_lbt     as oc_stk_or_lbt,
		    zo.cur_total      as oc_cur_total,
		    zo.max_total      as oc_max_total,
		    zo.lp_win_liab    as oc_lp_win_liab,
		    o.lp_num          as oc_lp_num,
		    o.lp_den          as oc_lp_den,
		    o.sp_num_guide    as oc_sp_num_guide,
		    o.sp_den_guide    as oc_sp_den_guide,
		    o.min_bet         as oc_min_bet,
		    o.max_bet         as oc_lp_max_bet,
		    o.max_multiple_bet as oc_max_multiple_bet,
		    o.sp_max_bet       as oc_sp_max_bet,
		    o.ep_max_bet       as oc_ep_max_bet,
		    o.max_place_lp     as oc_lp_max_place,
		    o.max_place_sp     as oc_sp_max_place,
		    o.max_place_ep     as oc_ep_max_place,
		    o.fc_stk_limit     as oc_fc_stk_limit,
		    o.tc_stk_limit     as oc_tc_stk_limit,
		    o.lock_stake_lmt   as oc_lock_stake_lmt,
		    o.code            as oc_code,
		    o.result          as oc_result,
		    o.result_conf     as oc_result_conf,
		    o.settled         as oc_settled,
		    o.fb_result       as oc_fb_result,
			NVL(NVL(NVL(NVL(o.max_multiple_bet, m.max_multiple_bet), e.max_multiple_bet), t.max_multiple_bet), 'n/a') as oc_f_max_multiple_bet,
		    m.ev_mkt_id,
		    m.ew_fac_num,
		    m.ew_fac_den,
		    m.ew_places,
			m.ew_avail,
			m.pl_avail,
		    NVL(b.ew_fac_num,m.ew_fac_num) as bet_ew_fac_num,
		    NVL(b.ew_fac_den,m.ew_fac_den) as bet_ew_fac_den,
		    NVL(b.ew_places,m.ew_places)   as bet_ew_places,
		    m.sort            as mkt_sort,
		    m.name            as mkt_name,
		    m.ev_oc_grp_id,
		    m.status          as mkt_status,
		    m.displayed       as mkt_displayed,
		    m.disporder       as mkt_disporder,
		    m.type            as mkt_type,
		    m.xmul            as mkt_xmul,
		    m.acc_min         as mkt_acc_min,
		    m.acc_max         as mkt_acc_max,
		    m.bir_index       as mkt_bir_index,
		    m.bir_delay       as mkt_bir_delay,
		    m.bet_in_run      as mkt_bet_in_run,
		    m.min_bet         as mkt_min_bet,
		    m.max_bet         as mkt_max_bet,
		    m.lp_avail        as mkt_lp_avail,
		    m.sp_avail        as mkt_sp_avail,
		    m.max_multiple_bet as mkt_max_mult_bet,
		    zm.liab_limit     as mkt_liab_limit,
		    zm.apc_status     as mkt_apc_status,
		    zm.lp_win_stake   as mkt_lp_win_stake,
		    m.result_conf     as mkt_result_conf,
		    m.settled         as mkt_settled,
		    e.ev_id,
		    e.desc            as ev_name,
		    e.status          as ev_status,
		    e.displayed       as ev_displayed,
		    e.disporder       as ev_disporder,
		    e.start_time      as ev_start_time,
		    e.suspend_at      as ev_suspend_at,
		    e.is_off          as ev_is_off,
		    e.min_bet         as ev_min_bet,
		    e.max_bet         as ev_max_bet,
		    e.result_conf     as ev_result_conf,
		    e.settled         as ev_settled,
		    e.max_multiple_bet as ev_max_mult_bet,
		    case
		        when pCheckEvDispOkay(e.start_time, e.suspend_at, e.is_off,
		                              m.bet_in_run) = 'N'
		        then 'Y'
		        else 'N'
		        end as started,
		    d.code            as ev_code,
		    t.ev_type_id,
		    t.name            as type_name,
		    t.status          as type_status,
		    t.displayed       as type_displayed,
		    t.disporder       as type_disporder,
		    t.max_payout      as type_max_payout,
		    t.ev_max_bet      as type_ev_max_bet,
		    t.ev_min_bet      as type_ev_min_bet,
		    t.ltl_win_lp      as type_win_lp,
		    t.ltl_win_sp      as type_win_sp,
		    t.ltl_win_ep      as type_win_ep,
		    t.ltl_place_lp    as type_place_lp,
		    t.ltl_place_sp    as type_place_sp,
		    t.ltl_place_ep    as type_place_ep,
		    c.ev_class_id,
		    c.category,
		    c.name            as class_name,
		    c.status          as class_status,
		    c.displayed       as class_displayed,
		    c.disporder       as class_disporder,
		    c.sort            as class_sort,
		    ll.win_lp         as mkt_win_lp,
		    ll.win_sp         as mkt_win_sp,
		    ll.win_ep         as mkt_win_ep,
		    ll.place_lp       as mkt_place_lp,
		    ll.place_sp       as mkt_place_sp,
		    ll.place_ep       as mkt_place_ep,
		    ll.min_bet        as mkt_inf_bet,
		    ll.max_bet        as mkt_sup_bet,
		    lle.least_max_bet as ev_least_max_bet,
		    lle.most_max_bet  as ev_most_max_bet,
		    lle.liability     as ev_liability,
		    lle.lay_to_lose   as ev_lay_to_lose,
		    NVL(ba.park_reason,'-') as park_reason_code
		from
		    tOBet b,
		    outer tBetAsync ba,
		    tBet be,
		    tEvOc o,
		    tEvOcConstr zo,
		    tEvMkt m,
		    tEvMktConstr zm,
		    tEv e,
		    tEvType t,
		    tEvClass c,
		    outer tLaytoLose ll,
		    outer tLaytoLoseEv lle,
		    outer tEvCode d
		where
		    b.bet_id = ?
		and be.bet_id = b.bet_id
		and ba.bet_id = b.bet_id
		and o.ev_oc_id = b.ev_oc_id
		and zo.ev_oc_id = o.ev_oc_id
		and m.ev_mkt_id = o.ev_mkt_id
		and zm.ev_mkt_id = m.ev_mkt_id
		and e.ev_id = m.ev_id
		and d.ev_id = e.ev_id
		and t.ev_type_id = e.ev_type_id
		and c.ev_class_id = t.ev_class_id
		and ll.ev_mkt_id = m.ev_mkt_id
		and lle.ev_id = e.ev_id
		order by
		    b.leg_no,
		    b.part_no
	}

	# execute the query
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	# can only cancel the parked-bet if 'timed-out' or suspended
	set ASYNC(action,cancel)\
	    [expr {$ASYNC(0,status) == "T" || $ASYNC(0,status) == "S"}]
	set ASYNC(action,allow_cancel) $ASYNC(action,cancel)

	# copy result-set
	set ASYNC(leg,nrows)     [db_get_nrows $rs]
	set ASYNC(leg,cols)      [db_get_colnames $rs]
	set ASYNC(price,nrows)   0
	set ASYNC(offer)         0
	set ev_oc_list           ""

	# bind bet's park_reason_code

	tpBindString park_reason_code [db_get_col $rs park_reason_code]

	tpBindString source [db_get_col $rs source]
	tpSetVar     source [db_get_col $rs source]

	for {set i 0} {$i < $ASYNC(leg,nrows)} {incr i} {
		foreach c $ASYNC(leg,cols) {
			set x [db_get_col $rs $i $c]
			if {$c == "leg_sort"} {
				if {[info exists LEG_SORT_DESC($x)]} {
					set x $LEG_SORT_DESC($x)
				}
			}
			set ASYNC(leg,$i,$c) $x
		}

		foreach c {oc_name mkt_name ev_name type_name class_name} {
			set ASYNC(leg,$i,$c) [string map {"|" ""} $ASYNC(leg,$i,$c)]
		}

		#
		# Show total liability or total stake
		#
		set show_liab 0

		if {[string first $ASYNC(leg,$i,mkt_type) "AHMSCULl"] < 0} {
			if {$ASYNC(leg,$i,oc_stk_or_lbt) == "L"} {
				set show_liab 1
			}
		} else {
			set show_liab 1
		}

		if {$show_liab} {
			if {[string first $ASYNC(leg,$i,mkt_type) "AHLl"] >= 0} {
				set liab $ASYNC(leg,$i,oc_lp_win_liab)
			} else {
				set liab $ASYNC(leg,$i,oc_cur_total)
			}
			if {$liab < 0} {
				set liab 0
			}
			set ASYNC(leg,$i,oc_cur_total) $liab
		}

		# format prices
		set ASYNC(leg,$i,oc_lp)\
		    [mk_price $ASYNC(leg,$i,oc_lp_num) $ASYNC(leg,$i,oc_lp_den)]

		set ASYNC(leg,$i,oc_sp)\
		    [mk_price $ASYNC(leg,$i,oc_sp_num_guide)\
		              $ASYNC(leg,$i,oc_sp_den_guide)]

		if {$ASYNC(leg,$i,price_type) == "L" || $ASYNC(leg,$i,price_type) == "G"} {
			set ASYNC(leg,$i,o_lp)\
			    [mk_price $ASYNC(leg,$i,o_num) $ASYNC(leg,$i,o_den)]
		}

		# work out what price to display
		if {$ASYNC(leg,$i,price_type) != "L" &&
				$ASYNC(leg,$i,price_type) != "G"} {

			set ASYNC(leg,$i,price) [get_price_type_desc $ASYNC(leg,$i,price_type)]
			if {$ASYNC(leg,$i,leg_type) == "E"} {
				append ASYNC(leg,$i,price) " @ $ASYNC(leg,$i,ew_fac_num)/$ASYNC(leg,$i,ew_fac_den) (E/W)"
			} elseif {$ASYNC(leg,$i,leg_type) == "P"} {
				append ASYNC(leg,$i,price) " @ $ASYNC(leg,$i,ew_fac_num)/$ASYNC(leg,$i,ew_fac_den)"
			}
		} else {
			if {$ASYNC(leg,$i,leg_type) == "E"} {
				set ASYNC(leg,$i,price) "$ASYNC(leg,$i,o_lp) @ $ASYNC(leg,$i,ew_fac_num)/$ASYNC(leg,$i,ew_fac_den) (E/W)"
			} elseif {$ASYNC(leg,$i,leg_type) == "P"} {
				set ASYNC(leg,$i,price) "$ASYNC(leg,$i,o_lp) @ $ASYNC(leg,$i,ew_fac_num)/$ASYNC(leg,$i,ew_fac_den)"
			} else {
				set ASYNC(leg,$i,price) "$ASYNC(leg,$i,o_lp)"
			}
		}

		if {[set hcap_value [db_get_col $rs $i hcap_value]] != {}} {
			# Translate the selection's handicap value
			set hcap_str [ob_price::mk_hcap_str\
								[db_get_col $rs $i mkt_type]\
								[db_get_col $rs $i oc_fb_result]\
								$hcap_value]

			set ASYNC(leg,$i,hcap_str) $hcap_str
		} else {
			set ASYNC(leg,$i,hcap_str) ""
		}

		# prefix event-code to event-name
		if {[OT_CfgGet FUNC_GEN_EV_CODE 0] && $ASYNC(leg,$i,ev_code) != ""} {
			set ASYNC(leg,$i,ev_name)\
			    [format "%03d: %s" $ASYNC(leg,$i,ev_code)\
			                       $ASYNC(leg,$i,ev_name)]
		}

		# prefix outcome-code to outcome-name
		if {[OT_CfgGet FUNC_GEN_OC_CODE 0] && $ASYNC(leg,$i,oc_code) != ""} {
			set ASYNC(leg,$i,oc_name)\
			    "$ASYNC(leg,$i,oc_code): $ASYNC(leg,$i,oc_name)"
		}

		# can update outcome, market and/or event?
		foreach c {oc mkt ev} {
			_dd_can_update $i $c
		}

		# keep track of ev_oc_id, so we can build price-history
		if {$ev_oc_list != ""} {
			append ev_oc_list ","
		}
		append ev_oc_list $ASYNC(leg,$i,ev_oc_id)
	}

	set oc_lock_stake_lmt [db_get_col $rs 0 oc_lock_stake_lmt]

	db_close $rs
	
	# TODO Not actually needed
	# Flag if this bet has been overridden
	#
	if {$ASYNC(0,status) == "O"} {
		tpSetVar IsOverridden 1
	}

	#Get the bet group details to show in bet group detail section
	catch {unset GROUP_BETS}

	# get bet group details
	set bet_group_id [reqGetArg bet_group_id]

	set offer_count 1

	if {$bet_group_id != "" && $bet_group_id != -1} {

		array set GROUP_BETS [list]

		set sql {
		select
			b.bet_id,
			b.bet_type,
			b.stake,
			s.desc as seln_name,
			e.desc as ev_name,
			tBetAsync.park_reason
		from
			tBet b,
			tOBet o,
			tEv e,
			tEvOc s,
			tbetslipbet sb,
			outer tBetAsync
		where
			b.bet_id          = o.bet_id and
			o.ev_oc_id        = s.ev_oc_id and
			e.ev_id           = s.ev_id and
			b.bet_id          = sb.bet_id and
			tBetAsync.bet_id  = b.bet_id and
			sb.betslip_id     = ?
		}

		# execute the query
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $bet_group_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		set last_bet_id ""
		set bet_count 0
		#set offer_status 1

		for {set i 0} {$i < $nrows} {incr i} {
			# For dbls, trbls etc. we will get multiple results because of the join
			# on tEv.  So handle this by combining the multiples here
			set current_bet_id [db_get_col $rs $i bet_id]
			if {$last_bet_id == $current_bet_id} {
				set GROUP_BETS($bc,seln_name) "$GROUP_BETS($bc,seln_name), [db_get_col $rs $i seln_name]"
			} else {
				incr bet_count
				set bc [expr {$bet_count - 1}]
				set GROUP_BETS($bc,bet_id)       [db_get_col $rs $i bet_id]
				set GROUP_BETS($bc,bet_type)     [db_get_col $rs $i bet_type]
				set GROUP_BETS($bc,stake)        [db_get_col $rs $i stake]
				set GROUP_BETS($bc,seln_name)    [db_get_col $rs $i seln_name]
				set GROUP_BETS($bc,ev_name)      [db_get_col $rs $i ev_name]
				set GROUP_BETS($bc,reason)       [ob_xl::sprintf en [db_get_col $rs $i park_reason]]

				#if {![_have_offer $GROUP_BETS($bc,bet_id)]} {
				#	set offer_status 0
				#}

			}
			set last_bet_id $current_bet_id
		}

		#offer_count is used to display popup alert to close window while submitting an offer
		set offer_count $bet_count
		for {set i 0} {$i < $bet_count} {incr i} {
				if {[_have_offer $GROUP_BETS($i,bet_id)]} {
					set offer_count [expr {$offer_count - 1}]
				}
		}

		tpSetVar      NumGrpBets        $bet_count
		tpBindString  GrpId             $bet_group_id

		tpBindVar GrpBetId          GROUP_BETS bet_id      grp_idx
		tpBindVar GrpBetType        GROUP_BETS bet_type    grp_idx
		tpBindVar GrpBetStake       GROUP_BETS stake       grp_idx
		tpBindVar GrpBetSelnName    GROUP_BETS seln_name   grp_idx
		tpBindVar GrpBetEvName      GROUP_BETS ev_name     grp_idx
		tpBindVar GrpBetReason		GROUP_BETS reason      grp_idx

	}
	#End of Bet Group section

	tpBindString  GrpOfferStatus    $offer_count

	# any legs?
	if {!$ASYNC(leg,nrows)} {
		_err_bind "Cannot find any bet-legs for bet_id $bet_id"
		asPlayFile -nocache async_bet/bet.html

	} else {
	
		#
		# Calculate and bind the each-way terms 
		#
		set ew_terms [list]
		for {set i 0} {$i < $ASYNC(leg,nrows)} {incr i} {
			lappend ew_terms [list $ASYNC(leg,$i,ew_fac_num) $ASYNC(leg,$i,ew_fac_den)]
		}
		
		tpBindString ew_terms $ew_terms

		# bind legs
		tpSetVar leg leg
		lappend ASYNC(leg,cols) o_lp
		lappend ASYNC(leg,cols) oc_lp
		lappend ASYNC(leg,cols) oc_sp
		lappend ASYNC(leg,cols) hcap_str
		lappend ASYNC(leg,cols) price

		foreach c $ASYNC(leg,cols) {
			tpBindVar leg_${c} ASYNC $c leg leg_idx
		}

		# get + bind the outcome price-history
		_bind_price_history $ev_oc_list

		# get + bind bet-decline reason codes
		_bind_decline_reason_codes

		# what was previously selected (leg + drill-down tab)
		foreach c {leg dd} {
			set ASYNC(selected,$c) [reqGetArg selected_${c}]
			if {$ASYNC(selected,$c) == ""} {
				if {$c == "leg"} {
					set ASYNC(selected,leg)\
					    "$ASYNC(leg,0,leg_no)_$ASYNC(leg,0,part_no)"
				} else {
					set ASYNC(selected,dd) mkt
				}
			}
			tpBindString selected_${c} $ASYNC(selected,$c)
		}

		# what is the selected leg's leg_sort?
		foreach {leg_no part_no} [split $ASYNC(selected,leg) "_"] {}
		set found 0
		for {set i 0} {!$found && $i < $ASYNC(leg,nrows)} {incr i} {
			if {$ASYNC(leg,$i,leg_no) == $leg_no &&\
			        $ASYNC(leg,$i,part_no) == $part_no} {
				set found 1
				tpBindString selected_leg_sort $ASYNC(leg,$i,leg_sort)
			}
		}

		# Does this bet already have an offer
		# - if not, then bind Bet-Action details
		if {![_have_offer $bet_id]} {
			_bind_action
		}

		# Calculate max stake scale for this customer and bet
		array set seln [list]
		# There are now 3 bet levels for specifying customer
		# stake factor i.e. EVOCGRP,TYPE & CLASS
		# EVOCGRP takes 1st priority, TYPE is 2nd priority
		# whilst CLASS is 3rd priority in deciding which
		# max scale factor will be associated with a selection.
		for {set i 0} {$i < $ASYNC(leg,nrows)} {incr i} {
			set ev_oc_id $ASYNC(leg,$i,ev_oc_id)
			lappend seln(ev_oc_id) $ev_oc_id

			set seln($ev_oc_id,EVOCGRP) $ASYNC(leg,$i,ev_oc_grp_id)
			set seln($ev_oc_id,TYPE)    $ASYNC(leg,$i,ev_type_id)
			set seln($ev_oc_id,CLASS)   $ASYNC(leg,$i,ev_class_id)
		}

                # Lock stakes if necessary
                switch $oc_lock_stake_lmt {
                        "N" {
                                set lock_win_stake_lmt_bool "";
                                set lock_place_stake_lmt_bool "";
                        }
                        "Y" {
                                set lock_win_stake_lmt_bool "CHECKED";
                                set lock_place_stake_lmt_bool "CHECKED";
                        }
                        "W" {
                                set lock_win_stake_lmt_bool "CHECKED";
                                set lock_place_stake_lmt_bool "";
                        }
                        "P" {
                                set lock_win_stake_lmt_bool "";
                                set lock_place_stake_lmt_bool "CHECKED";
                        }
                        default {
                                set lock_win_stake_lmt_bool "";
                                set lock_place_stake_lmt_bool "";
                        }
                }

                tpBindString LOCK_WIN_STAKE_LIMITS $lock_win_stake_lmt_bool
                if {$lock_win_stake_lmt_bool == "CHECKED"} {
                        tpBindString DisableMaxWin "DISABLED"
                } else {
                        tpBindString DisableMaxWin ""
                }

                tpBindString LOCK_PLACE_STAKE_LIMITS $lock_place_stake_lmt_bool
                if {$lock_place_stake_lmt_bool == "CHECKED"} {
                        tpBindString DisableMaxPlace "DISABLED"
                } else {
                        tpBindString DisableMaxPlace ""
                }


		# Get liability groups and priorities
		_get_liab_priorities

		set cust_liab [_calc_cust_risk_limit\
							$ASYNC(0,cust_id)\
							[array get seln]]

		if {[lindex $cust_liab 0] == 1} {
			tpBindString liab_desc       [lindex $cust_liab 1]
			tpBindString liab_colour     [lindex $cust_liab 2]
			tpBindString bet_stake_scale [lindex $cust_liab 4]
		} else {
			# If no liability limits are found in the event hierarchy, the
			# max stake scale for this bet is the customer's max stake scale.
			tpBindString bet_stake_scale $ASYNC(0,cust_max_stake_scale)
		}

		tpBindString bet_id $bet_id
		tpBindString default_ccy [ob_control::get default_ccy]

		asPlayFile -nocache async_bet/bet.html
	}

	catch {unset ASYNC}
}

# Update the expiry date of the bet
#
#    bet_id - id of the bet being referred
#
proc ::ADMIN::ASYNC_BET::H_upd_exp_time { {bet_id ""} {new_res_time_sec ""}} {
	global DB

	set bet_id [reqGetArg bet_id]
	set new_res_time_sec [reqGetArg new_res_time_sec]

	# See if we have a bet group and apply change to all bets in group
	set bet_group_id [reqGetArg bet_group_id]
	if {$bet_group_id != "" && $bet_group_id != -1} {
		set sql {
			select
				bet_id
			from
				tBetSlipBet b
			where
				b.betslip_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $bet_group_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			lappend bet_ids [db_get_col $rs $i bet_id]
		}
		db_close $rs
	} else {
		set bet_ids [list $bet_id]
	}

	set get_bet_sql {
		select expiry_date from tBetAsync where bet_id = ?
	}
	set get_bet [inf_prep_sql $DB $get_bet_sql]

	set update_bet_sql {
		update
			tBetAsync
		set
			expiry_date = ?
		where
			bet_id = ?
	}
	set update_bet [inf_prep_sql $DB $update_bet_sql]

	foreach b $bet_ids {
		set rs   [inf_exec_stmt $get_bet $b]
		set expiry_date_sec [clock scan [db_get_col $rs 0 expiry_date]]
		db_close $rs

		set new_expiry_date [clock format [expr $expiry_date_sec + $new_res_time_sec] -format "%Y-%m-%d %H:%M:%S"]
		inf_exec_stmt $update_bet $new_expiry_date $b
	}

	inf_close_stmt $update_bet
	inf_close_stmt $get_bet

}


#
# Proc used in AJAX request to get potential win factor.
# Used to confirm that offer payout is less than original.
#
proc ::ADMIN::ASYNC_BET::get_win_factor args {
	set bet_type [reqGetArg bet_type]
	set leg_type [reqGetArg leg_type]
	set prices   [reqGetArg prices]
	set sorts    [reqGetArg sorts]
	set ew_terms [reqGetArg ew_terms]
	
	set stake 1
	
	::ob_bet::init
	
	set pot_payout [::ob_bet::generic_pot_payout \
						$bet_type \
						$stake \
						$leg_type \
						$prices \
						$sorts \
						$ew_terms \
					]
	
	tpBufWrite "$pot_payout"
}


#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Private procedure to bind an error message.
#
#   msg    - error message
#   dd_err - denote if the error is related to a drill-down update
#
proc ::ADMIN::ASYNC_BET::_err_bind { msg {dd_err 0} } {

	OT_LogWrite 1 $msg
	err_bind $msg

	tpSetVar DD_ERR $dd_err
}


# Private procedure to get the Asynchronous bet timeout
#
#   returns - timeout (seconds)
#
proc ::ADMIN::ASYNC_BET::_get_timeout args {

	global DB

	set sql [subst {
		select async_timeout from tControl
	}]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set async_timeout [db_get_col $rs 0 async_timeout]
	db_close $rs

	return $async_timeout
}

# Private procedure to get the bet details.
# If no bet_id is supplied, then get all pending bets but can have further
# restrictions applied to the search (supplied by the operator)
#   - by username or account number
#   - between dates
#   - pending status
# If a bet_id is supplied, then get the details for that bet (must be
# pending or cancelled).
#
#   async_timeout - asynchronous bet timeout (seconds)
#   bet_id        - bet identifier
#
proc ::ADMIN::ASYNC_BET::_get_bet { {bet_id ""} } {

	global DB ASYNC CUST_LAST_BETS CUST_TRADING_MSGS

	set channel_filter ""
	if {[info exists ASYNC(channel_ids)]} {
		set channel_ids $ASYNC(channel_ids)
		set channel_filter "and b.source in ('[join $channel_ids {','}]')"
	}

	# search criteria columns
	set cols [subst {
	    c.username,
	    c.acct_no,
	    c.cust_id,
	    c.lang,
	    c.max_stake_scale as cust_max_stake_scale,
	    c.cr_date as cust_reg_date,
		s.shop_no,
		s.addr_line_1,
		s.addr_postcode,
		s.district_id,
	    cr.fname || ' ' ||cr.lname as cust_name,
	    co.country_name as cust_country,
	    a.ccy_code,
	    a.acct_id,
		nvl(call_user.fname, "") || ' '
			|| nvl(call_user.lname, "") || '('
			|| call_user.username || ')' as admin_user,
	    b.bet_id,
	    b.cr_date,
	    b.bet_type,
	    b.stake,
	    b.leg_type,
	    b.stake_per_line,
	    b.receipt,
	    b.token_value as fb_value,
	    b.num_lines,
	    sb.betslip_id as bet_group_id,
	    NVL(b.potential_payout,'0.00') as potential_payout,
		NVL(b.max_bet,'n/a') max_bet,
		case when a.owner = 'Y' then
			'Y'
		else
			'N'
		end as hedged,
	    ch.desc as channel_desc,
	    case
	        when b.status = 'X' then 'X'
	        when b.status = 'S' then 'S'
	        when y.expiry_date > CURRENT then 'A'
	        else 'T'
	        end as status,
	    bo.status as off_status,
	    bo.accept_status as off_accept_status,
		nvl(lg.liab_desc, '-') as liab_desc,
		lg.colour as liab_colour,
		c.liab_group,
	    y.expiry_date,
	    o.ev_oc_id,
	    m.ev_mkt_id,
	    m.sort
	}]

	# build the search criteria for 'Parked' Bets
	set park_sql [subst {
		select
		    $cols,
		    ad.username locked_by
		from
		    tBetAsync y,
		    outer tAsyncBetOff bo,
		    outer tAdminUser ad,
		    tBet b,
			outer (tCall ca, outer tAdminUser call_user),
		    tObet o,
		    tEvOc oc,
		    tEvMkt m,
		    tAcct a,
		    tCustomer c,
			outer tRetailShop s,
		    tCustomerReg cr,
		    tCountry co,
		    tChannel ch,
		    outer tbetslipbet sb,
		    outer tLiabGroup lg
		where
		    b.bet_id = y.bet_id
		and o.bet_id = b.bet_id
		and b.bet_id = sb.bet_id
		and b.call_id = ca.call_id
		and ca.oper_id = call_user.user_id
		and oc.ev_oc_id = o.ev_oc_id
		and m.ev_mkt_id = oc.ev_mkt_id
		and y.bet_id = bo.bet_id
		and ad.user_id = y.lock_user_id
		and a.acct_id = y.acct_id
		and c.cust_id = a.cust_id
		and cr.shop_id = s.shop_id
		and cr.cust_id = c.cust_id
		and b.source = ch.channel_id
		and lg.liab_group_id  = c.liab_group
		and co.country_code = c.country_code
		$channel_filter
	}]

	# build the search criteria for 'Offered' Bets
	set off_sql [subst {
		select
		    $cols,
		    '' locked_by
		from
		    tAsyncBetOff bo,
			outer tAdminUser bo_user,
		    tBet b,
			outer (tCall ca, outer tAdminUser call_user),
		    tObet o,
		    tEvOc oc,
		    tEvMkt m,
		    tAcct a,
		    tCustomer c,
			outer tRetailShop s,
		    tCustomerReg cr,
		    tCountry co,
		    tChannel ch,
		    outer tLiabGroup lg,
		    outer tbetslipbet sb,
	        outer tBetAsync y
		where
			bo.user_id = bo_user.user_id
		and b.bet_id = bo.bet_id
		and o.bet_id = b.bet_id
		and b.bet_id = sb.bet_id
		and b.call_id = ca.call_id
		and ca.oper_id = call_user.user_id
		and oc.ev_oc_id = o.ev_oc_id
		and m.ev_mkt_id = oc.ev_mkt_id
		and y.bet_id = b.bet_id
		and a.acct_id = b.acct_id
		and c.cust_id = a.cust_id
		and cr.shop_id = s.shop_id
		and cr.cust_id = c.cust_id
		and b.source  = ch.channel_id
		and lg.liab_group_id  = c.liab_group
		and co.country_code = c.country_code
		$channel_filter
	}]

	# if no bet_id supplied, then get all pending bets (with some further
	# restrictions supplied by the operator)
	if {$bet_id == ""} {

		set sql $park_sql

		# search parameters
		foreach c {username acct_no date_1 date_2 status receipt} {
			set $c [reqGetArg $c]
		}

		# restrict on username
		if {$username != ""} {
			if {[reqGetArg username_exact] != "Y"} {
				append sql " and c.username like '$username'"
			} else {
				append sql " and c.username = '$username'"
			}
		}

		# restrict on account number
		if {$acct_no != ""} {
			append sql " and c.acct_no = '$acct_no'"
		}

		# restrict on receipt
		if {$receipt != ""} {
			append sql " and b.receipt like '$receipt'"
		}

		# restrict on date range
		if {$date_1 != "" && $date_2 != ""} {
			append sql " and b.cr_date between '$date_1' and '$date_2'"
		}

		# restrict on status
		if {$status == "p"} {
			append sql " and y.expiry_date >= CURRENT"
		} elseif {$status == "t"} {
			append sql " and y.expiry_date < CURRENT"
		}

		append sql " order by 7"

	# else, we have a bet_id, then get details for that bet
	# NB: we will union park-bet + offer-bet queries so we can get a bet
	#     which has just be declined or accepted (both remove the bet from
	#     the bet-park when the offer was made)
	} else {
		append park_sql "and y.bet_id = $bet_id"
		append off_sql  "and bo.bet_id = $bet_id"
		set sql "$park_sql union $off_sql order by 7"
	}


	# execute the query
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# copy the result-set
	set ASYNC(nrows) [db_get_nrows $rs]
	set ASYNC(cols)  [db_get_colnames $rs]
	
	ob_log::write DEBUG {Support ticket49731, number of rows=$ASYNC(nrows), sql=$sql}

	# For stake and payout fields, we need system ccy equivalents
	# and absolute value equivalents (can be negative for bet backs).

	for {set i 0} {$i < $ASYNC(nrows)} {incr i} {
		foreach c $ASYNC(cols) {
			set ASYNC($i,$c) [db_get_col $rs $i $c]
			ob_log::write DEV "setting ASYNC($i,$c) = [db_get_col $rs $i $c]"
		}
		set hedged [db_get_col $rs $i hedged]
		foreach c {
			stake
			stake_per_line
			potential_payout
		} {
			set ccy_code [db_get_col $rs $i ccy_code]
			set v $ASYNC($i,$c)
			set ASYNC($i,${c}_abs) $v
			if {$hedged == "Y" && [string is double -strict $v]} {
				set v [expr {0.0 - $v}]
				set ASYNC($i,${c}) $v
			}
			set res_conv [ob_exchange::to_sys_amount $ccy_code $v]
			if {[lindex $res_conv 0] == "OK"} {
				set ASYNC($i,${c}_sys) [lindex $res_conv 1]
			} else {
				set ASYNC($i,${c}_sys) $v
			}
		}
	}

	# If this is an specific bet, the customer information for the customer details tab is needed.
	if {$bet_id != ""} {
		set cust_totals_sql {
			select
				NVL(sum(stake),0) as cust_total_staked,
				NVL(sum(returns),0) as cust_total_returns
			from
				tBetSummary
			where
				acct_id = ?
		}

		# execute the query
		set stmt [inf_prep_sql $DB $cust_totals_sql]
		set rs   [inf_exec_stmt $stmt $ASYNC(0,acct_id)]
		inf_close_stmt $stmt
		
		if {[db_get_nrows $rs] == 1} {
			set total_staked   [db_get_col $rs 0 cust_total_staked]
			set total_returns  [db_get_col $rs 0 cust_total_returns]
			set ASYNC(0,cust_balance) [format "%.2f" [expr $total_staked - $total_returns]]
		} else {
			set ASYNC(0,cust_balance) {n/a}
		}
		lappend ASYNC(cols) {cust_balance}

		set cust_trading_msgs {
			select
				m.message,
				m.sort,
				m.last_update,
				u.username as admin_username
			from
				tCustomerMsg m,
				tAdminUser u
			where
				m.oper_id = u.user_id
				and m.cust_msg_id = (select
										max(cm.cust_msg_id)
									from
										tcustomermsg cm
									where
										cm.cust_id = ? and cm.sort = 'O')
			union
			select
				m.message,
				m.sort,
				m.last_update,
				u.username as admin_username
			from
				tCustomerMsg m,
				tAdminUser u
			where
				m.oper_id = u.user_id
				and m.cust_msg_id =  (select
										max(cm.cust_msg_id)
									from
										tcustomermsg cm
									where
										cm.cust_id = ? and cm.sort = 'S')
		}
		ob_log::write DEBUG {Support ticket49731, loading cust_id=$ASYNC(0,cust_id) for trading msg sql= $cust_trading_msgs}
		# execute the query
		set stmt [inf_prep_sql $DB $cust_trading_msgs]
		set rs   [inf_exec_stmt $stmt $ASYNC(0,cust_id) $ASYNC(0,cust_id)]
		inf_close_stmt $stmt

		set CUST_TRADING_MSGS(nrows) [db_get_nrows $rs]
		set CUST_TRADING_MSGS(cols)  [db_get_colnames $rs]

		for {set i 0} {$i < $CUST_TRADING_MSGS(nrows)} {incr i} {
			foreach c  $CUST_TRADING_MSGS(cols) {
				set CUST_TRADING_MSGS($i,$c) [db_get_col $rs $i $c]
			}
		}

		set last_bet_ids_sql [subst {
			select first [OT_CfgGet ASYNC_CUST_INFO_NUM_BETS 10]
				bet_id
			from
				tbet
			where
				acct_id = ?
				and status in ('A','S')
			order by
				cr_date desc
		}]

		# execute the query
		set stmt [inf_prep_sql $DB $last_bet_ids_sql]
		set rs   [inf_exec_stmt $stmt $ASYNC(0,acct_id)]
		inf_close_stmt $stmt

		set last_bet_ids [list]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			lappend last_bet_ids [db_get_col $rs $i bet_id]
		}
		set last_bet_ids [join $last_bet_ids {,}]

		set cust_last_bets_sql [subst {
			select
				b.bet_id,
				e.ev_id,
				m.ev_mkt_id,
				s.ev_oc_id,
				e.desc as event,
				m.name as market,
				s.desc as selection,
				b.stake as stake,
				b.bet_type as bet,
				b.leg_type as legs,
				o.price_type,
				o.leg_sort,
				m.type mkt_type,
				s.fb_result,
				o.hcap_value,
				o.o_num,
				o.o_den,
				s.sp_num,
				s.sp_den,
				b.cr_date as placed_at,
				b.receipt as receipt,
				b.winnings as returns,
				case
					when e.result_conf='Y' or s.result_conf='Y' then s.result else '-'
				end result
			from
				tBet b,
				tOBet o,
				tEv e,
				tEvMkt m,
				tEvOc s
			where
				o.bet_id = b.bet_id
				and s.ev_oc_id = o.ev_oc_id
				and e.ev_id = s.ev_id
				and m.ev_mkt_id = s.ev_mkt_id
				and b.bet_id in ($last_bet_ids);
		}]


		if { $last_bet_ids != "" } {
			# execute the query
			set stmt [inf_prep_sql $DB $cust_last_bets_sql]
			set rs   [inf_exec_stmt $stmt]
			inf_close_stmt $stmt

			set CUST_LAST_BETS(nrows) [db_get_nrows $rs]
			set CUST_LAST_BETS(cols)  [list bet_id event market selection stake bet \
				legs price placed_at receipt returns result]

			for {set i 0} {$i < $CUST_LAST_BETS(nrows)} {incr i} {
				set CUST_LAST_BETS($i,bet_id) [db_get_col $rs $i bet_id]

				foreach c  [list receipt placed_at bet legs stake returns] {
					if {$i == 0 || \
						$CUST_LAST_BETS([expr $i - 1],bet_id) != \
							$CUST_LAST_BETS($i,bet_id)} {
						set CUST_LAST_BETS($i,$c) [db_get_col $rs $i $c]
					} else {
						set CUST_LAST_BETS($i,$c) ""
					}
				}

				foreach c [list event market selection result price_type leg_sort \
							mkt_type fb_result hcap_value o_num o_den sp_num sp_den] {
					set CUST_LAST_BETS($i,$c) [db_get_col $rs $i $c]
				}

				set CUST_LAST_BETS($i,price) [mk_price_info \
					$CUST_LAST_BETS($i,price_type) $CUST_LAST_BETS($i,leg_sort) \
					$CUST_LAST_BETS($i,mkt_type) $CUST_LAST_BETS($i,fb_result) \
					$CUST_LAST_BETS($i,hcap_value) $CUST_LAST_BETS($i,o_num) \
					$CUST_LAST_BETS($i,o_den) $CUST_LAST_BETS($i,sp_num) \
					$CUST_LAST_BETS($i,sp_den)]
			}
		} else {
			set CUST_LAST_BETS(nrows) 0
			set CUST_LAST_BETS(cols)  [list bet_id event market selection stake bet \
				legs price placed_at receipt returns result]
		}
}

	db_close $rs

	foreach c {
		stake
		stake_per_line
		potential_payout
	} {
		lappend ASYNC(cols) "${c}_sys" "${c}_abs"
	}

	# any bets?
	if {!$ASYNC(nrows)} {
		if {$bet_id == ""} {
			error "No pending asynchronous bets found which match your criteria"
		} else {
			error "Unable to retrieve bet details for bet id: $bet_id"
		}
	}
}

#
# Bind possible channels for dropdown list
#
#   returns: Number of elements bound
#
proc ::ADMIN::ASYNC_BET::_bind_channels {arr_name} {
	global DB
	upvar $arr_name CHAN

	set sql {
		select
			channel_id,
			desc
		from
			tChannel
	}
	
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	
	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set CHAN($i,value) [db_get_col $rs $i channel_id]
		set CHAN($i,label) [db_get_col $rs $i desc]
	}

	tpBindVar ChanValue $arr_name value ${arr_name}_idx
	tpBindVar ChanLabel $arr_name label ${arr_name}_idx

	db_close $rs
	return $nrows
}

#
# Bind possible customer responses for dropdown list
#
#   returns: Number of elements bound
#
proc ::ADMIN::ASYNC_BET::_bind_customer_responses {arr_name} {
	upvar $arr_name CUSTOMER_RESPONSES

	set data {
		{O "Open"}
		{A "Accepted"}
		{D "Declined"}
		{T "Requires TopUp"}
		{C "Cancelled"}
	}
	
	set nrows [llength $data]

	for {set i 0} {$i < $nrows} {incr i} {
		set CUSTOMER_RESPONSES($i,value) [lindex [lindex $data $i] 0]
		set CUSTOMER_RESPONSES($i,label) [lindex [lindex $data $i] 1]
	}

	tpBindVar CustValue $arr_name value ${arr_name}_idx
	tpBindVar CustLabel $arr_name label ${arr_name}_idx

	return $nrows
}

# Private procedure to get + bind the outcome price-history.
#
#    ev_oc_list - comma delimetered list of ev_oc_ids
#
proc ::ADMIN::ASYNC_BET::_bind_price_history { ev_oc_list } {

	global DB ASYNC

	# get the price-change history for each of our outcomes
	set sql [subst {
		select
		    price_id,
		    ev_oc_id,
		    cr_date,
		    status,
			p_num,
		    p_den
		from
		    tEvOcPrice
		where
		    ev_oc_id in ($ev_oc_list)
		order by
		    ev_oc_id,
		    price_id desc
	}]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# copy histoty
	set ASYNC(price,nrows) [db_get_nrows $rs]
	set ASYNC(price,cols)  [db_get_colnames $rs]

	for {set i 0} {$i < $ASYNC(price,nrows)} {incr i} {
		foreach c $ASYNC(price,cols) {
			set ASYNC(price,$i,$c) [db_get_col $rs $i $c]
		}
		set ASYNC(price,$i,price)\
			[mk_price $ASYNC(price,$i,p_num) $ASYNC(price,$i,p_den)]
	}
	db_close $rs

	# bind history
	tpSetVar price price
	lappend ASYNC(price,cols) price
	foreach c $ASYNC(price,cols) {
		tpBindVar price_${c} ASYNC $c price price_idx
	}
}



# Private procedure to determine if a bet has an outstanding offer.
# If the case, then bind the details
#
#   bet_id  - bet identifier
#   returns - >= 1 if the bet has an outstanding offer, 0 if not
#             result also storder in ASYNC(offer)
#
proc ::ADMIN::ASYNC_BET::_have_offer { bet_id } {

	global DB ASYNC

	# find offer
	set sql {
		select
		    o.cr_date,
		    o.expiry_date,
		    case
		        when o.expiry_date <= CURRENT then 'Y'
		        else 'N'
		        end as expired,
		    u.username,
		    o.status,
		    o.off_stake_per_line,
		    o.org_stake_per_line,
		    v.xlation_1 as reason_desc,
		    o.accept_status,
			o.leg_type,
		    l.leg_no,
		    l.part_no,
		    l.off_p_num,
		    l.off_p_den,
			l.off_price_type
		from
		    tAsyncBetOff o,
		    tAdminUser u,
		    outer (tXlateCode x, tXLateVal v),
		    outer tAsyncBetLegOff l
		where
		    o.bet_id = ?
		and u.user_id = o.user_id
		and l.bet_id = o.bet_id
		and x.code_id = o.reason_code
		and x.code_id = v.code_id
		and v.lang = 'en'
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bet_id]
	inf_close_stmt $stmt

	set ASYNC(offer)           [db_get_nrows $rs]
	set ASYNC(offer,leg,nrows) 0

	set off_cols {cr_date expiry_date expired username status\
	              off_stake_per_line org_stake_per_line reason_desc\
	              accept_status leg_type}
	set leg_cols {leg_no part_no off_p_num off_p_den off_price_type}

	# copy + bind offer details
	for {set i 0} {$i < $ASYNC(offer)} {incr i} {
		if {$i == 0} {
			foreach c $off_cols {
				set ASYNC(offer,$c) [db_get_col $rs $i $c]
				tpBindString off_${c} $ASYNC(offer,$c)
			}
		}
		foreach c $leg_cols {
			set ASYNC(offer,leg,$i,$c) [db_get_col $rs $i $c]
		}

		# if we have a price offer
		if {$ASYNC(offer,leg,$i,leg_no) != ""} {

			# format the price

			if { [info exists ASYNC(offer,leg,$i,off_price_type) ] && \
					$ASYNC(offer,leg,$i,off_price_type) == "S" } {
					set ASYNC(offer,leg,$i,off_price) "SP"
			} else {
				set ASYNC(offer,leg,$i,off_price) [mk_price\
						$ASYNC(offer,leg,$i,off_p_num)\
						$ASYNC(offer,leg,$i,off_p_den)]
			}

			# find the associated outcome name
			set found 0
			for {set j 0} {$j < $ASYNC(leg,nrows) && !$found} {incr j} {
				if {$ASYNC(leg,$j,leg_no) == $ASYNC(offer,leg,$i,leg_no) &&\
				       $ASYNC(leg,$j,part_no) == $ASYNC(offer,leg,$i,part_no)} {
					set ASYNC(offer,leg,$i,oc_name) $ASYNC(leg,$j,oc_name)
					set found 1
				}
			}
		}
	}
	db_close $rs

	# bind offer prices
	if {$ASYNC(offer) && $ASYNC(offer,leg,0,leg_no) != ""} {
		set ASYNC(offer,leg,nrows) $ASYNC(offer)
		tpSetVar offer offer
		foreach c {off_price oc_name} {
			tpBindVar off_leg_${c} ASYNC $c offer leg off_leg_idx
		}
	} else {
		set ASYNC(offer,leg,nrows) 0
	}

	return $ASYNC(offer)
}



# Private procedure to bind the Bet-Action details.
#
proc ::ADMIN::ASYNC_BET::_bind_action args {

	global ASYNC

	# cancel-bet
	set comment [reqGetArg comment]
	if {$comment == ""} {
		if {$ASYNC(0,status) == "T"} {
			set comment "Asynchronous Bet Expired"
		} elseif {$ASYNC(0,status) == "S"} {
			set comment "Asynchronous Bet Suspended"
		} elseif {[info exists ASYNC(action,cancel,comment)]} {
			set comment $ASYNC(action,cancel,comment)
		}
	}
	tpBindString action_cancel_comment $comment

	# decline-bet
	tpBindString action_decline_reason_code [reqGetArg reason_code]

	# new stake-per-line
	set stake_per_line [reqGetArg stake_per_line]
	if {$stake_per_line != ""} {
		tpSetVar ACTION_STAKE_PER_LINE 1
	}
	tpBindString action_stake_per_line $stake_per_line

	set leg_type [reqGetArg leg_type]

	# Switching to Each Way, must load in new offers
	set load_ew_prices 0
	set leg_type_err 0

	if {$leg_type == "E" || $leg_type == "P"} {

		set load_ew_prices 1

		ob_log::write INFO  "Attempting to switch to EW or P Bet"

		for {set i 0} {$i < $ASYNC(leg,nrows)} {incr i} {

			if { $leg_type == "E" && $ASYNC(leg,$i,ew_avail) == "N" } {
				ob_log::write INFO  "ew avail set to N. Cannot continue"
				_err_bind "EW not available on one or more markets"
				set load_ew_prices 0
				set leg_type_err 1
				break;
			} elseif { $leg_type == "P" && $ASYNC(leg,$i,pl_avail) == "N" } {
				ob_log::write INFO  "pl avail set to N. Cannot continue"
				_err_bind "Place Terms not available on one or more markets"
				set load_ew_prices 0
				set leg_type_err 1
				break;
			} else {
				ob_log::write DEV "Places $ASYNC(leg,$i,bet_ew_places) Num  $ASYNC(leg,$i,bet_ew_fac_num) Den $ASYNC(leg,$i,bet_ew_fac_den)"
				set ASYNC(leg,$i,action_ew_places) $ASYNC(leg,$i,bet_ew_places)
				set ASYNC(leg,$i,action_ew_fac_num) $ASYNC(leg,$i,bet_ew_fac_num)
				set ASYNC(leg,$i,action_ew_fac_den) $ASYNC(leg,$i,bet_ew_fac_den)
				set ASYNC(leg,$i,action_leg_type)   $leg_type
			}
		}
		if { $load_ew_prices } {
			ob_log::write INFO  "Loading EW Info"
			tpBindVar leg_action_ew_places ASYNC action_ew_places leg leg_idx
			tpBindVar leg_action_ew_fac_num ASYNC action_ew_fac_num leg leg_idx
			tpBindVar leg_action_ew_fac_den ASYNC action_ew_fac_den leg leg_idx
		}
	}

	if {!$leg_type_err} {
		ob_log::write ERROR "Binding leg_type to $leg_type"
		tpBindString action_leg_type $leg_type
	} else {
		tpBindString action_leg_type ""
	}



	# new prices
	for {set i 0} {$i < $ASYNC(leg,nrows)} {incr i} {
		set lp [reqGetArg lp_$ASYNC(leg,$i,leg_no)_$ASYNC(leg,$i,part_no)]
		set ASYNC(leg,$i,action_lp) $lp
	}

	tpBindVar leg_action_lp ASYNC action_lp leg leg_idx
	ob_log::write_array DEV ASYNC
}



# Private procedure to get + bind Bet-Decline reason XLate codes
#
proc ::ADMIN::ASYNC_BET::_bind_decline_reason_codes args {

	global DB ASYNC

	set sql {
		select
			v.xlation_1 reason,
		    c.code_id
		from
		    tXLateCode c,
			tXLateVal v
		where
		    c.group = ?
		and c.code_id = v.code_id
		and v.lang = 'en'
		order by 1
	}

	# Xlate.group
	set grp [OT_CfgGet ASYNC_BET_REASON_CODE_GROUP "Async.Bet"]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $grp]
	inf_close_stmt $stmt

	set ASYNC(xlate,nrows) [db_get_nrows $rs]
	set ASYNC(xlate,cols)  [db_get_colnames $rs]

	for {set i 0} {$i < $ASYNC(xlate,nrows)} {incr i} {
		foreach c $ASYNC(xlate,cols) {
			set ASYNC(xlate,$i,$c) [db_get_col $rs $i $c]
		}
	}
	db_close $rs

	tpSetVar xlate xlate
	foreach c $ASYNC(xlate,cols) {
		tpBindVar xlate_${c} ASYNC $c xlate xlate_idx
	}

	tpSetVar decline_reason_nrows $ASYNC(xlate,nrows)
}



# Private procedure to update a lock on the pending bet
#
proc ::ADMIN::ASYNC_BET::_update_lock {bet_id {reset "N"}} {

	global DB USERID

	set sql {
		update
			tBetAsync
		set
			lock_user_id = ?
		where
			bet_id = ?
	}

	set lock_user_id [expr {$reset == "N" ? $USERID:{} }]

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {inf_exec_stmt $stmt $lock_user_id $bet_id} msg]} {
		ob::log::write ERROR \
			{::ADMIN::ASYNC_BET::_update_lock - Problem updating lock on asynchronous bet (bet_id=$bet_id), $msg}
		inf_close_stmt $stmt
		error $msg
	}

	inf_close_stmt $stmt

}



# Private procedure to check whether the admin user can lock the async. bet
#
proc ::ADMIN::ASYNC_BET::_get_lock_owner {bet_id} {

	global DB USERID

	set lock_user_id {}

	set sql {
		select
			lock_user_id
		from
			tBetAsync
		where
			bet_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $bet_id]

	set nrows [db_get_nrows $rs]

	if {$nrows !=1} {
		ob::log::write ERROR "Failed to get lock details for bet"
		return $lock_user_id
	}

	set lock_user_id [db_get_col $rs 0 lock_user_id]

	inf_close_stmt $stmt
	db_close $rs

	return $lock_user_id

}
