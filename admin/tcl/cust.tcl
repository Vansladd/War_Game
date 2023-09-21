# ==============================================================
# $Id: cust.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUST {

asSetAct ADMIN::CUST::GoCustQuery            [namespace code go_cust_query]
asSetAct ADMIN::CUST::DoCustQuery            [namespace code do_cust_query]
asSetAct ADMIN::CUST::ExtDoCustQuery         [namespace code ext_do_cust_query]

asSetAct ADMIN::CUST::DoCardSearch           [namespace code do_card_search]
asSetAct ADMIN::CUST::DoCustAcctSusp         [namespace code do_cust_acct_susp]
asSetAct ADMIN::CUST::DoCustRegSusp          [namespace code do_cust_reg_susp]
asSetAct ADMIN::CUST::GoCust                 [namespace code go_cust]
asSetAct ADMIN::CUST::DoCust                 [namespace code do_cust]
asSetAct ADMIN::CUST::DoCustReg              [namespace code do_cust_reg]
asSetAct ADMIN::CUST::DoCustRegAnal          [namespace code do_cust_reg_anal]
asSetAct ADMIN::CUST::GoCustLvlLimit         [namespace code go_cust_lvl_limit]
asSetAct ADMIN::CUST::DoCustLvlLimit         [namespace code do_cust_lvl_limit]
asSetAct ADMIN::CUST::DoStopCode             [namespace code do_cust_stop_code]
asSetAct ADMIN::CUST::DoStmt	             [namespace code do_cust_stmt]
asSetAct ADMIN::CUST::DoCustCrdLmtSearch     [namespace code do_crd_search]
asSetAct ADMIN::CUST::DoStmtDetail           [namespace code do_stmt_detail]
asSetAct ADMIN::CUST::GoCustStatusHist       [namespace code go_cust_status_hist]
asSetAct ADMIN::CUST::GoFreeTokenList        [namespace code go_free_token_list]
asSetAct ADMIN::CUST::DelCustToken           [namespace code del_cust_token]
asSetAct ADMIN::CUST::DoCustCardTypeSearch   [namespace code go_cust_cardtype_query]
asSetAct ADMIN::CUST::GoRiskGuardianFailures [namespace code go_rg_failure_query]
asSetAct ADMIN::CUST::DoCustStatusFlags      [namespace code do_cust_status_flags]
asSetAct ADMIN::CUST::QueryCustStatusFlags   [namespace code query_cust_status_flags]
asSetAct ADMIN::CUST::EditCasinoTfrs         [namespace code edit_casino_tfrs]
asSetAct ADMIN::CUST::GoOkToDelete           [namespace code go_cpm_ok_to_delete]
asSetAct ADMIN::CUST::DoBossMediaQuery       [namespace code go_boss_media_qry]
asSetAct ADMIN::CUST::GoCustGroupsDetail     [namespace code go_cust_groups_detail]
asSetAct ADMIN::CUST::DoCustGroupsDetail     [namespace code do_cust_groups_detail]
asSetAct ADMIN::CUST::DoCustXSysAcctUpd      [namespace code do_cust_xsys_acct_upd]
asSetAct ADMIN::CUST::GoCustBetSummary       [namespace code go_cust_bet_summary]
asSetAct ADMIN::CUST::GoChanSysExclusion     [namespace code go_chan_sys_exclusions]
asSetAct ADMIN::CUST::DoChanSysExclusion     [namespace code do_chan_sys_exclusions]
asSetAct ADMIN::CUST::DoVetCode              [namespace code do_vet_codes]
asSetAct ADMIN::CUST::AjaxPlaytechBalance    [namespace code get_ajax_playtech_balance]
asSetAct ADMIN::CUST::DoCustReturnLimits     [namespace code do_cust_return_limits]

if {[OT_CfgGetTrue FUNC_MCS_POKER]} {
	tpBindString -global MCS_POKER_SRP_DAYS [OT_CfgGet MCS_POKER_SRP_DAYS 6]
}

#
# ----------------------------------------------------------------------------
# Generate customer selection criteria
# ----------------------------------------------------------------------------
#
proc go_cust_query args {

	global DB

	#
	# Pre-load currency and country code/name pairs
	#
	set stmt [inf_prep_sql $DB {
		select
			ccy_code,
			ccy_name,
			disporder
		from
			tccy
		order by
			disporder
	}]
	set res_ccy [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCCYs [db_get_nrows $res_ccy]

	tpBindTcl CCYCode sb_res_data $res_ccy ccy_idx ccy_code
	tpBindTcl CCYName sb_res_data $res_ccy ccy_idx ccy_name


	set stmt [inf_prep_sql $DB {
		select
			country_code,
			country_name,
			disporder
		from
			tcountry
		order by
			disporder,
			country_name,
			country_code
	}]
	set res_cntry [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCNTRYs [db_get_nrows $res_cntry]

	tpBindTcl CNTRYCode sb_res_data $res_cntry cntry_idx country_code
	tpBindTcl CNTRYName sb_res_data $res_cntry cntry_idx country_name

	#
	# Load Catd Type List
	#
	set stmt [inf_prep_sql $DB {
		select distinct
			scheme_name
		from
			tcardschemeinfo
	}]
	set res_cardtype [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCardTypes [db_get_nrows $res_cardtype]

	tpBindTcl CardTypeName sb_res_data $res_cardtype cardtype_idx scheme_name

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

	tpBindTcl ChannelId   sb_res_data $res_chan channel_idx channel_id
	tpBindTcl ChannelName sb_res_data $res_chan channel_idx desc

	#
	# Load actions
	#
	set stmt [inf_prep_sql $DB {
		select
			action_id,
			action_name
		from
			tcuststatsaction
		order by
			action_id asc
	}]

	set res_act  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar numActions [db_get_nrows $res_act]

	tpBindTcl ActionId   sb_res_data $res_act action_idx action_id
	tpBindTcl ActionName sb_res_data $res_act action_idx action_name

	#
	# load external customer groups
	#
	set stmt [inf_prep_sql $DB {
		select
			code,
			display
		from
			tExtCustIdent
		order by
			display asc
	}]

	set res_ext_groups [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumExtGroups [db_get_nrows $res_ext_groups]

	tpBindTcl ExtGroupCode sb_res_data $res_ext_groups ext_group_idx code
	tpBindTcl ExtGroupDisp sb_res_data $res_ext_groups ext_group_idx display

	#
	# Load experience points journal types
	#
	if {[OT_CfgGetTrue FUNC_MENU_IGF] && [op_allowed IGFExpPtsViewJrnl]} {
		ADMIN::IGF::get_exp_pts_jrnl_types
	}

	asPlayFile -nocache cust_query.html

	db_close $res_ccy
	db_close $res_act
	db_close $res_cntry
	db_close $res_chan
	db_close $res_ext_groups
}



#
# ----------------------------------------------------------------------------
# Customer search
# ----------------------------------------------------------------------------
#
proc ext_do_cust_query args {

	# bit of a wrapper around the do_cust_query stuff


	# reset the request variables
	reqSetArg action ADMIN::CUST::DoCustQuery


	asSetAction ADMIN::CUST::DoCustQuery

	set action_url [list]
	for {set a 0} {$a < [reqGetNumVals]} {incr a} {

		set str "[reqGetNthName $a]=[reqGetNthVal $a]"

		lappend action_url $str

	}

	tpBindString ACTION_URL [join $action_url {&}]

	asPlayFile -nocache xaccess_index.html
}

proc do_cust_query args {

	global DB
	global DATA
	catch { unset DATA }

	set action [reqGetArg SubmitName]

	if {$action == "AddCust"} {
		go_cust_reg
		return
	}

	set where  [list]
	set from   [list]
	set select ""
	set having ""
	set group_by ""

	set tw1 [reqGetArg twinning1]
	set tw2 [reqGetArg twinning2]
	
	set td1 [reqGetArg tdate1]
	set td2 [reqGetArg tdate2]


	if {([string length $tw1] > 0) && ([string length $tw2] > 0) && ([string length $td1] > 0) && ([string length $td2] > 0)} {
		puts "doing stuff"
		set select ", sum(b.winnings) as winnings"
		lappend from "tbgodfreywins b"
		lappend where "b.acct_id = a.acct_id"
		#lappend where "b.cr_date between '$td1' and '$td2'"
		lappend where "b.cr_date between '$td1 00:00:00' and '$td2 23:59:59'"
		set group_by "GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32"
		set having "HAVING sum(b.winnings) between $tw1 and $tw2"
	} else {
		set select ", '' as winnings"
	}


	if {[string length [set name [reqGetArg Username]]] > 0} {

		if {[reqGetArg LBOCustomer] == "Y"} {
			# Shop account usernames are all preceded by 1 space
			set name " [string trimleft $name]"
		}

		if {[reqGetArg ExactName] == "Y"} {
			set op =
		} else {
			set op like
			append name %
		}
		if {[reqGetArg UpperName] == "Y"} {
			lappend where "c.username_uc $op \"[string toupper ${name}]\""
		} else {
			lappend where "c.username $op \"${name}\""
		}
	}

	set district_search  [string length [set district  [reqGetArg DistrictNo]]]
	set shop_no_search   [string length [set shop_no   [reqGetArg ShopNumber]]]
	set shop_name_search [string length [set shop_name [reqGetArg ShopName]]]

	if {$district_search > 0 || $shop_no_search > 0 || $shop_name_search > 0} {
		lappend from  "tRetailShop"
		lappend where "r.shop_id = tRetailShop.shop_id"
	}

	if {$district_search > 0} {
		lappend from  "tRetailDistrict"
		lappend where "tRetailShop.district_id = tRetailDistrict.district_id"
		if {[string length [reqGetArg full_district_no]] > 0} {
			lappend where "tRetailDistrict.district_no = '${district}'"
		} else {
			lappend where "tRetailDistrict.district_no like '${district}%'"
		}
	}

	if {$shop_no_search > 0} {
		if {[string length [reqGetArg full_shop_no]] > 0} {
			lappend where "tRetailShop.shop_no = '${shop_no}'"
		} else {
			lappend where "tRetailShop.shop_no like '${shop_no}%'"
		}
	}

	if {$shop_name_search > 0} {
		if {[string length [reqGetArg full_shop_name]] > 0} {
			lappend where "tRetailShop.shop_name = '${shop_name}'"
		} else {
			lappend where "tRetailShop.shop_name like '${shop_name}%'"
		}
	}

	if {[reqGetArg LBOCustomer] == "Y"} {
		lappend where "a.owner = 'F'"

		if {[string length [set owner_type [reqGetArg OwnerType]]] > 0} {
			lappend where "a.owner_type = '${owner_type}'"
		} else {
			lappend where "a.owner_type in ('STR','VAR','OCC','REG','LOG')"
		}
	}

	if {[string length [set nickname [reqGetArg Nickname]]] > 0} {
		if {[reqGetArg ExactNickname] == "Y"} {
			set op =
		} else {
			set op like
			append nickname %
		}
		if {[reqGetArg UpperNickname] == "Y"} {
			lappend where "upper(r.nickname) $op \"[string toupper ${nickname}]\""
		} else {
			lappend where "r.nickname $op \"${nickname}\""
		}
	}

	if {[string length [set fname [reqGetArg FName]]] > 0} {
		set fname [string map {' \''} $fname]
		lappend where [get_indexed_sql_query $fname fname]
	}

	if {[string length [set lname [reqGetArg LName]]] > 0} {
		set lname [string map {' \''} $lname]
		lappend where [get_indexed_sql_query $lname lname]
	}
	if {[string length [set address [reqGetArg Address]]] > 0} {
		lappend where [get_indexed_sql_query $address address]
	}

	if {[string length [set addr_postcode [reqGetArg Postcode]]] > 0} {
		lappend where [get_indexed_sql_query $addr_postcode addr_postc]
	}

	if {[string length [set email [reqGetArg Email]]] > 0} {
		if {[reqGetArg LeadingEmail] == "Y"} {
			lappend where [get_indexed_sql_query "$email" email]
		} else {
			lappend where "UPPER(r.email) like [string toupper '%${email}%']"
		}
	}

	if {[string length [set acctno [reqGetArg AcctNo]]] > 0} {
		if {[reqGetArg ExactAccNo] == "Y"} {
			set op =
		} else {
			set op like
			append acctno %
		}

		set acctno [string toupper $acctno]

		if {[reqGetArg UpperAccNo] == "Y"} {
			lappend where "c.acct_no $op \"$acctno\""
		} else {
			lappend where "c.acct_no $op \"${acctno}\""
		}
	}

	#
	# If EliteSearch parameter is set search for Elite customers only
	# Otherwise search for anyone (ignore elite field).
	#
	if {[string length [set elitecust [string trim [reqGetArg EliteSearch]]]] > 0} {
		lappend where "c.elite = 'Y'"
	}

	if {[string length [set idcardno [string trim [reqGetArg IdCardNo]]]] > 0} {
		lappend where "upper(r.id_card_no) = upper(\"$idcardno\")"
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

	if {([string length $rd1] > 0) || ([string length $rd2] > 0)} {
		lappend where [mk_between_clause c.cr_date date $rd1 $rd2]
	}

	set bc1 [string trim [reqGetArg BetCount1]]
	set bc2 [string trim [reqGetArg BetCount2]]

	if {([string length $bc1] > 0) || ([string length $bc2] > 0)} {
		lappend where [mk_between_clause c.bet_count number $bc1 $bc2]
	}

	set ms1 [string trim [reqGetArg StakeScale1]]
	set ms2 [string trim [reqGetArg StakeScale2]]

	if {([string length $ms1] > 0) || ([string length $ms2] > 0)} {
		lappend where [mk_between_clause c.max_stake_scale number $ms1 $ms2]
	}

	if {[string length [set status [reqGetArg AcctStatus]]] > 0} {
		lappend where "c.status = '$status'"
	}

	set ab1 [string trim [reqGetArg AcctBal1]]
	set ab2 [string trim [reqGetArg AcctBal2]]

	if {([string length $ab1] > 0) || ([string length $ab2] > 0)} {
			lappend where [mk_between_clause a.balance number $ab1 $ab2]
		}

	if {[string length [set ipaddr [reqGetArg IPAddress]]] > 0} {

		if {[string length [reqGetArg full_ip]] > 0} {
			if {[OT_CfgGet HEXIP_SEARCH 0]} {
				set hexip [ip_to_hex $ipaddr]
				lappend where [get_indexed_sql_query $hexip ipaddr]
			} else {
				lappend where "r.ipaddr = '$ipaddr'"
			}
		} else {
			# TO DO - this bit can be made smarter as well
			lappend where "r.ipaddr like '${ipaddr}%'"
		}
	}

	if {[string length [set ext_group_code [reqGetArg ext_group_code]]] > 0} {

		if {[string length [set ext_cust_id [reqGetArg ext_cust_id]]] > 0 || [reqGetArg is_multiple]=="Y"} {
			lappend from  "tExtCust"
			lappend where "tExtCust.code = $ext_group_code"
			lappend where "c.cust_id = tExtCust.cust_id"
		}

		if {[string length [set ext_cust_id [reqGetArg ext_cust_id]]] > 0} {
			lappend where "tExtCust.ext_cust_id = '$ext_cust_id'"
		}
	}

	if {[string length [set letter_id [reqGetArg letter_id]]] > 0} {
		lappend from   "tLetterCustomer"
		lappend where  "tLetterCustomer.letter_id = $letter_id"
		lappend where  "c.cust_id = tLetterCustomer.cust_id"
	}

	#this next section is concerned with linking to operator specific tables
	set ext_from [list]
	set ext_where [list]
	set ext_select [list]
	if {[OT_CfgGet FUNC_EXT_CUST_SEARCH 0] == 1} {
		foreach {ext_from ext_where ext_select} [ADMIN::EXT::do_ext_cust_search] {break}

		foreach w $ext_where {
			lappend where $w
		}

		foreach f $ext_from {
			lappend from $f
		}
		
		foreach s $ext_select {
			lappend select $s
		}
	}

	# are we excluding affiliates (who masquerade as customers)?
	if {[OT_CfgGet EXCLUDE_AFFILIATES_FROM_SEARCH "N"] == "Y"} {
		lappend where " c.type != 'T' "
	}

	#
	# Don't allow a query with no filters
	#
	if {[llength $where] == 0} {
		err_bind "No search criteria supplied"
		asPlayFile -nocache cust_query.html
		return
	}

	if {[info exists CUST(CUST_SEARCH_ORDER)]} {
		set order_by $CUST(CUST_SEARCH_ORDER)
	} else {
		set order_by "c.cust_id"
	}

	if {[reqGetArg SortByFirstName] == "Y"} {
		set order_by "r.fname, $order_by"
	}



	set where "and [join $where { and }]"

	set from "[join $from {, }]"
	
	#set select "[join $select {, }]"
	
	#if {$select != ""} {
		#set select ", ${select}"
	#}
	
	if {$from != ""} {
		set from ", ${from}"
	}

	# Only return the first n items from this search.
	set first_n ""
	if {[set n [OT_CfgGet SELECT_FIRST_N 0]]} {
		set first_n " first $n "
	}
	# Support ticket#476342: correcting canceled bets count here.
	# May require dev work to deal with more throughly.
	# See also dbv/tcl/dbv-custs.tcl
	set sql [subst {
		select $first_n
			c.cust_id,
			c.username,
			c.status,
			c.sort,
			c.acct_no,
			c.bet_count - (select count(*) from tbet where acct_id=a.acct_id and status='X') as bet_count,
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
			r.addr_state_id,
			x.state,
			r.dob,
			r.email,
			NVL((select d.desc from tCustCode d where r.code = d.cust_code),'(None)')
				as cust_group,
			e.ext_cust_id,
			e.master,
			e.code,
			rs.shop_no,
			rs.shop_name,
			rd.district_no,
			a.owner,
			a.owner_type
			$select
		from
			tAcct a,
			tCustomerReg r,
			tCustomer c,
			outer tCountryState x,
			outer tExtCust e,
			outer (tretailshop rs, tretaildistrict rd)
			$from
		where
			c.cust_id       = a.cust_id  and
			r.addr_state_id = x.id       and
			c.cust_id       = r.cust_id  and
			c.cust_id       = e.cust_id  and
			r.shop_id       = rs.shop_id and
			rs.district_id  = rd.district_id and
			a.owner         <> 'D'
			$where
		$group_by
		$having
		order by
			$order_by
			
	}]
	OT_LogWrite 9 "SEARCH SQL: $sql"

	
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_norm  0
	set num_elite 0
	set found_shop_account 0

	if {[db_get_nrows $res] == 1} {
		go_cust cust_id [db_get_col $res 0 cust_id]
		db_close $res
		return
	}

	global DATA

	array set DATA       [list]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		set DATA($num_norm,acct_no)         [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($num_norm,elite)           [db_get_col $res $r elite]
		set DATA($num_norm,cust_id)         [db_get_col $res $r cust_id]
		set DATA($num_norm,username)        [db_get_col $res $r username]
		set DATA($num_norm,ext_cust_id)     [db_get_col $res $r ext_cust_id]
		set DATA($num_norm,master)          [db_get_col $res $r master]
		set DATA($num_norm,code)            [db_get_col $res $r code]
		set DATA($num_norm,status)          [db_get_col $res $r status]
		set DATA($num_norm,sort)            [db_get_col $res $r sort]
		set DATA($num_norm,bet_count)       [db_get_col $res $r bet_count]
		set DATA($num_norm,country_code)    [db_get_col $res $r country_code]
		set DATA($num_norm,nickname)        [db_get_col $res $r nickname]
		set DATA($num_norm,addr_city)       [db_get_col $res $r addr_city]
		set DATA($num_norm,ccy_code)        [db_get_col $res $r ccy_code]
		set DATA($num_norm,balance)         [db_get_col $res $r balance]
		set DATA($num_norm,max_stake_scale) [db_get_col $res $r max_stake_scale]
		set DATA($num_norm,cr_date)         [db_get_col $res $r cr_date]
		set DATA($num_norm,fname)           [db_get_col $res $r fname]
		set DATA($num_norm,lname)           [db_get_col $res $r lname]
		set DATA($num_norm,addr_street_1)   [db_get_col $res $r addr_street_1]
		set DATA($num_norm,addr_postcode)   [db_get_col $res $r addr_postcode]
		set DATA($num_norm,email)           [db_get_col $res $r email]
		set DATA($num_norm,cust_group)      [db_get_col $res $r cust_group]
		set DATA($num_norm,dob)             [db_get_col $res $r dob]
		set DATA($num_norm,shop_no)         [db_get_col $res $r shop_no]
		set DATA($num_norm,shop_name)       [db_get_col $res $r shop_name]
		set DATA($num_norm,district_no)     [db_get_col $res $r district_no]
		set DATA($num_norm,owner)           [db_get_col $res $r owner]
		set DATA($num_norm,owner_type)      [db_get_col $res $r owner_type]
		set DATA($num_norm,winnings)        [db_get_col $res $r winnings]

		if {$DATA($num_norm,owner) == "F" && [regexp {^(STR|VAR|OCC|REG|LOG)$} $DATA($num_norm,owner_type)]} {
			set found_shop_account 1
		}

		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
		incr num_norm
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo        DATA acct_no         cust_idx
	tpBindVar Elite         DATA elite           cust_idx
	tpBindVar CustID        DATA cust_id         cust_idx
	tpBindVar Username      DATA username        cust_idx
	tpBindVar ExtCustId     DATA ext_cust_id     cust_idx
	tpBindVar Master        DATA master          cust_idx
	tpBindVar ExtCustCode   DATA code            cust_idx
	tpBindVar Code          DATA code            cust_idx
	tpBindVar Status        DATA status          cust_idx
	tpBindVar Sort          DATA sort            cust_idx
	tpBindVar BetCount      DATA bet_count       cust_idx
	tpBindVar CountryCode   DATA country_code    cust_idx
	tpBindVar NickName      DATA nickname        cust_idx
	tpBindVar City          DATA addr_city       cust_idx
	tpBindVar CcyCode       DATA ccy_code        cust_idx
	tpBindVar Balance       DATA balance         cust_idx
	tpBindVar MaxStakeScale DATA max_stake_scale cust_idx
	tpBindVar RegDate       DATA cr_date         cust_idx
	tpBindVar RegFName      DATA fname           cust_idx
	tpBindVar RegLName      DATA lname           cust_idx
	tpBindVar Address1      DATA addr_street_1   cust_idx
	tpBindVar Postcode      DATA addr_postcode   cust_idx
	tpBindVar Email         DATA email           cust_idx
	tpBindVar CustGroup     DATA cust_group      cust_idx
	tpBindVar DOB           DATA dob             cust_idx
	tpBindVar Winnings      DATA winnings        cust_idx

	if {$found_shop_account} {
		tpSetVar ShopFieldingAccountExists  "Y"
		tpBindVar ShopNumber   DATA shop_no     cust_idx
		tpBindVar ShopName     DATA shop_name   cust_idx
		tpBindVar DistrictCode DATA district_no cust_idx
		tpBindVar OwnerType    DATA owner_type  cust_idx
	}

	set_display_fields

	asPlayFile -nocache cust_list.html

	unset DATA

	db_close $res
}



#
# ----------------------------------------------------------------------------
# Go to add new customer/update customer reg details
# ----------------------------------------------------------------------------
#
proc go_cust_reg args {

	global DATA DB

	set cust_id [reqGetArg CustId]

	#
	# Do a telebetting specific registration
	#
	if {[OT_CfgGet FUNC_TELEBETTING 0]} {
		if {[OT_CfgGet FUNC_OVS 0]} {
			tpBindString AGE_VRF_STATUS \
				[verification_check::get_ovs_status [reqGetArg CustId] {AGE}]
		}
		ADMIN::TB_CUST::go_register
		return
	}

	tpSetVar NewUser 1

	set DefaultLang    ""
	set DefaultCCY     ""
	set DefaultCountry ""

	foreach {n v} $args {
		set $n $v
	}

	set elite 0

	# existing customer - edit their details
	if {$cust_id != ""} {

		tpSetVar NewUser 0

		set sql [subst {
			select
				c.cust_id,
				c.username,
				c.acct_no,
				c.elite,
				c.country_code,
				a.ccy_code,
				c.lang,
				r.nickname,
				r.title,
				r.fname,
				r.lname,
				r.dob,
				r.addr_street_1,
				r.addr_street_2,
				r.addr_street_3,
				r.addr_street_4,
				r.addr_city,
				r.addr_state_id,
				r.addr_postcode,
				r.email,
				r.telephone,
				r.contact_ok,
				r.mkt_contact_ok,
				r.ptnr_contact_ok,
				r.challenge_1,
				r.response_1,
				r.challenge_2,
				r.response_2,
				r.id_card_no,
				r.staff_member,
				rs.shop_no,
				ocr.rep_code,
				ocr.status as rep_code_status
			from
				tCustomer c,
				tAcct a,
				tCustomerReg r,
				outer tRetailShop rs,
				outer tOnCourseRep ocr
			where
				c.cust_id = ? and
				c.cust_id = a.cust_id and
				c.cust_id = r.cust_id and
				rs.shop_id = r.shop_id and
				a.acct_id = ocr.acct_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		set DefaultLang    [db_get_col $res 0 lang]
		set DefaultCCY     [db_get_col $res 0 ccy_code]
		set DefaultCountry [db_get_col $res 0 country_code]
		set DefaultState   [db_get_col $res 0 addr_state_id]

		set acct_no [acct_no_enc [db_get_col $res 0 acct_no]]
		set rep_code_status [db_get_col $res 0 rep_code_status]

		if {$rep_code_status == "X"} {
			set rep_code_disabled "true"
		} else {
			set rep_code_disabled "false"
		}
		set rep_code [db_get_col $res 0 rep_code]

		tpBindString Username        [db_get_col $res 0 username]
		tpBindString Elite           [db_get_col $res 0 elite]
		tpBindString AcctNo          $acct_no
		tpBindString DOB             [db_get_col $res 0 dob]
		tpBindString NickName        [db_get_col $res 0 nickname]
		tpBindString Title           [db_get_col $res 0 title]
		tpBindString FName           [db_get_col $res 0 fname]
		tpBindString LName           [db_get_col $res 0 lname]
		tpBindString Addr1           [db_get_col $res 0 addr_street_1]
		tpBindString Addr2           [db_get_col $res 0 addr_street_2]
		tpBindString Addr3           [db_get_col $res 0 addr_street_3]
		tpBindString Addr4           [db_get_col $res 0 addr_street_4]
		tpBindString City            [db_get_col $res 0 addr_city]
		tpBindString Postcode        [db_get_col $res 0 addr_postcode]
		tpBindString Email           [db_get_col $res 0 email]
		tpBindString Telephone       [db_get_col $res 0 telephone]
		tpBindString Challenge1      [db_get_col $res 0 challenge_1]
		tpBindString Response1       [db_get_col $res 0 response_1]
		tpBindString Challenge2      [db_get_col $res 0 challenge_2]
		tpBindString Response2       [db_get_col $res 0 response_2]
		tpBindString IdCardNo        [db_get_col $res 0 id_card_no]
		tpBindString ShopNumber      [db_get_col $res 0 shop_no]
		tpBindString StaffMember     [db_get_col $res 0 staff_member]
		tpBindString RepCode         [db_get_col $res 0 rep_code]
		tpBindString RepCodeDisabled $rep_code_disabled

		tpBindString CustId $cust_id

		if {[db_get_col $res 0 elite] == "Y"} {
			set elite 1
		}

		db_close $res
	}

	tpSetVar IS_ELITE $elite

	global DATA

	# get available languages
	set lang_sql {
		select
			lang lang_id,
			name lang_name,
			disporder
		from
			tLang
		where
			status = 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $lang_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumLangs [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set lang_id [db_get_col $res $r lang_id]

		set DATA($r,lang_id)   $lang_id
		set DATA($r,lang_name) [db_get_col $res $r lang_name]

		if {$DefaultLang == $lang_id} {
			set DATA($r,lang_sel) SELECTED
		} else {
			set DATA($r,lang_sel) ""
		}
	}

	tpBindVar LangId   DATA lang_id   lang_idx
	tpBindVar LangName DATA lang_name lang_idx
	tpBindVar LangSel  DATA lang_sel  lang_idx

	db_close $res

	if {$cust_id == ""} {

		#
		# Don't allow registration in euro currencies
		#

		set ccy_sql {
			select
				ccy_code,
				ccy_name,
				disporder
			from
				tCCY
			where
				  status = 'A'
			  and ccy_code not in
				('ATS','DEM','ESP','FIM','FRF','GRD','IEP', 'ITL','NLG','PTE')
			order by
				disporder
		}

		set stmt [inf_prep_sql $DB $ccy_sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumCCYs [set n_rows [db_get_nrows $res]]

		for {set r 0} {$r < $n_rows} {incr r} {

			set ccy_code [db_get_col $res $r ccy_code]

			set DATA($r,ccy_code) $ccy_code
			set DATA($r,ccy_name) [db_get_col $res $r ccy_name]

			if {$DefaultCCY == $ccy_code} {
				set DATA($r,ccy_sel) SELECTED
			} else {
				set DATA($r,ccy_sel) ""
			}
		}

		tpBindVar CCYCode DATA ccy_code ccy_idx
		tpBindVar CCYName DATA ccy_name ccy_idx
		tpBindVar CCYSel  DATA ccy_sel  ccy_idx

		db_close $res

	} else {

		tpBindString CCYCode $DefaultCCY
	}

	# get available countries
	set country_sql {
		select
			country_code,
			country_name,
			disporder
		from
			tCountry
		order by
			disporder,
			country_name,
			country_code
	}

	set stmt [inf_prep_sql $DB $country_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCountrys [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set country_code [db_get_col $res $r country_code]

		set DATA($r,country_code) $country_code
		set DATA($r,country_name) [db_get_col $res $r country_name]

		if {$DefaultCountry == $country_code} {
			set DATA($r,country_sel) SELECTED
		} else {
			set DATA($r,country_sel) ""
		}
	}

	tpBindVar CountryCode DATA country_code country_idx
	tpBindVar CountryName DATA country_name country_idx
	tpBindVar CountrySel  DATA country_sel  country_idx

	db_close $res

	# load external customer groups
	set stmt [inf_prep_sql $DB {
		select
			b.code,
			b.display,
			a.master,
			a.permanent,
			a.ext_cust_id
		from
			outer tExtCust a,
			tExtCustIdent b
		where
			a.code = b.code
		and
			a.cust_id = ?
		order by
			display asc
	}]

	set res_ext_groups [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	for {set r 0} {$r < [db_get_nrows $res_ext_groups]} {incr r} {
		foreach f {master permanent} {
			if {[db_get_col $res_ext_groups $r $f] == "Y"} {
				set DATA($r,$f)  "checked=\"checked\""
			} else {
				set DATA($r,$f)  ""
			}
		}
	}

	tpSetVar NumExtGroups [db_get_nrows $res_ext_groups]

	tpBindTcl ExtGroupCode  sb_res_data $res_ext_groups ext_group_idx code
	tpBindTcl ExtGroupDisp  sb_res_data $res_ext_groups ext_group_idx display
	tpBindTcl ExtCustId     sb_res_data $res_ext_groups ext_group_idx ext_cust_id
	tpBindVar ExtMaster     DATA  master    ext_group_idx
	tpBindVar ExtPermanent  DATA  permanent ext_group_idx

	if {[OT_CfgGet FUNC_OVS 0]} {
		tpBindString AGE_VRF_STATUS \
			[verification_check::get_ovs_status [reqGetArg CustId] {AGE}]
	}

	asPlayFile -nocache cust_reg.html

	db_close $res_ext_groups

	unset DATA

}


#
# ----------------------------------------------------------------------------
# Add/update customer registration
# ----------------------------------------------------------------------------
#
proc do_cust_reg args {

	set cust_id [reqGetArg CustId]

	if {$cust_id == ""} {
		do_cust_reg_new
	} else {
		if {[reqGetArg SubmitName] == "Back"} {
			go_cust
			return
		}
		do_cust_reg_upd
	}

}



proc do_cust_reg_new args {

	global DB

	# general register permission
	if {![op_allowed DoCustReg]} {
		err_bind "You do not have permission to register customers"
		go_cust_reg\
			DefaultCCY     [reqGetArg CCYCode]\
			DefaultLang    [reqGetArg Lang]\
			DefaultCountry [reqGetArg Country]
		return
	}

	set pwd_1 [reqGetArg Password_1]
	set pwd_2 [reqGetArg Password_2]

	if {[OT_CfgGet CUST_PWD_CASE_INSENSITIVE 0]} {
		set pwd_1 [string toupper $pwd_1]
		set pwd_2 [string toupper $pwd_2]
	}

	set username [reqGetArg Username]

 	# Validate passwords because of PlayTech restrictions
	set checks_to_perform [OT_CfgGet CUST_PASSWORD_VALIDATION_CHECKS \
		{VALID_CHARS LENGTH FORBIDDEN_WORDS}]

 	set ret [check_password $pwd_1 $checks_to_perform]
 	if {$ret != "OB_OK"} {
 		err_bind $ret
 		go_cust_reg
 		return
 	}

	set msg ""

	if {$pwd_1 != $pwd_2} {
		set msg "Passwords don't match"
	} elseif {$username == ""} {
		set msg "No username"
	}

	# form error
	if {$msg != ""} {
		err_bind $msg

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_cust_reg\
			DefaultCCY     [reqGetArg CCYCode]\
			DefaultLang    [reqGetArg Lang]\
			DefaultCountry [reqGetArg Country]
		return
	}

	# insert the customer
	set sql {
		execute procedure pInsCustomer(
			p_reg_combi = 'I',
			p_source = ?,
			p_aff_id = ?,
			p_username = ?,
			p_password = ?,
			p_password_salt = ?,
			p_nickname = ?,
			p_bib_pin = ?,
			p_lang = ?,
			p_ccy_code  = ?,
			p_country_code = ?,
			p_acct_type = ?,
			p_reg_status = ?,
			p_ipaddr = ?,
			p_challenge_1 = ?,
			p_response_1 = ?,
			p_challenge_2 = ?,
			p_response_2 = ?,
			p_sig_date = ?,
			p_title = ?,
			p_fname = ?,
			p_lname = ?,
			p_dob = ?,
			p_addr_street_1 = ?,
			p_addr_street_2 = ?,
			p_addr_street_3 = ?,
			p_addr_street_4 = ?,
			p_addr_city = ?,
			p_postcode = ?,
			p_telephone = ?,
			p_mobile = ?,
			p_email = ?,
			p_contact_ok = ?,
			p_ptnr_contact_ok = ?,
			p_hear_about = ?,
			p_hear_about_txt = ?,
			p_gender = ?,
			p_acct_no_format = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[OT_CfgGet CUST_PWD_SALT 0]} {
		set password_salt [generate_salt]
	} else {
		set password_salt ""
	}

	set enc_pwd [encrypt_password $pwd_1 $password_salt]

	set c [catch {
		set res  [inf_exec_stmt $stmt\
			I\
			[reqGetArg AffId]\
			$username\
			$enc_pwd\
			$password_salt\
			[reqGetArg Nickname]\
			[reqGetArg BibPIN]\
			[reqGetArg Lang]\
			[reqGetArg CCYCode]\
			[reqGetArg Country]\
			DEP\
			A\
			Admin-Reg\
			[reqGetArg Challenge1]\
			[reqGetArg Response1]\
			[reqGetArg Challenge2]\
			[reqGetArg Response2]\
			[reqGetArg SigDate]\
			[reqGetArg Title]\
			[reqGetArg FName]\
			[reqGetArg LName]\
			[reqGetArg DOB]\
			[reqGetArg Addr1]\
			[reqGetArg Addr2]\
			[reqGetArg Addr3]\
			[reqGetArg Addr4]\
			[reqGetArg City]\
			[reqGetArg Postcode]\
			[reqGetArg Telephone]\
			[reqGetArg Mobile]\
			[reqGetArg Email]\
			[reqGetArg ContactOK]\
			[reqGetArg PtnrContactOK]\
			[reqGetArg HearAbout]\
			[reqGetArg HearAboutTxt]\
			[reqGetArg Gender]\
			[OT_CfgGet CUST_ACCT_NO_FORMAT A]
		]
	} msg]

	inf_close_stmt $stmt

	if {$c == 0} {

		set cust_id [db_get_coln $res 0 0]
		reqSetArg CustId $cust_id
		db_close $res


		go_cust cust_id $cust_id

		if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
			OB_freebets::check_action REG $cust_id

			set referrer_id [reqGetArg referrer_id]

			if {$referrer_id != ""} {

				set referrer_cust_id 0

				set stmt [inf_prep_sql $DB [subst {
					select
						cust_id
					from
						tCustomer
					where
						username = '$referrer_id'
				}]]

				set res_referrer [inf_exec_stmt $stmt]
				inf_close_stmt $stmt

				if {[db_get_nrows $res_referrer] == 1} {
					set referrer_cust_id [db_get_col $res_referrer cust_id]
				}

				if [catch {

					OB_freebets::check_referral [string toupper $referrer_id] 0 $cust_id

					if {![OB_freebets::check_action REFERRAL $referrer_cust_id 0]} {
						ob_log::write DEBUG {ADMIN::CUST:do_cust_reg_new - check_action REFERRAL - ERROR}
					}
				} msg] {
					ob_log::write DEBUG {ADMIN::CUST:do_cust_reg_new - check_referral - $msg}
				}
			}
		}

		if {[OT_CfgGetTrue CUST_MATCHER_ENABLED]} {
			ob_log::write DEV "CM was enabled"
			# link customer via URN by CUST_MATCHER rules
			# if an error was thrown, then cust_mather found a problem with the registration
			set match_code ""
			if {[catch {
				set match_code [cust_matcher::match $cust_id]
			} msg]} {
				ob_log::write WARNING "Problem running cust_matcher::match $cust_id:  $msg"
			}
			if {[lindex $match_code 0] == 2} {
				# Notify if cust_matcher::match has suspended customer account
				set code "Customer account has been Created, but Suspended.\nCust_Matcher: [lindex $match_code 1]"
				err_bind $code
				ob_log::write DEV "CM found the Match"
			} else {
				ob_log::write DEV "CM did not find the match"
			}
		} else {
			ob_log::write DEV "CM was not enabled"
		}

	}


	# failed
	if {$c} {
		err_bind $msg

		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		go_cust_reg\
			DefaultCCY     [reqGetArg CCYCode]\
			DefaultLang    [reqGetArg Lang]\
			DefaultCountry [reqGetArg CountryCode]
	}
}



#
# Takes as arguments the password and a list containing the set of checks to perform
# on the password. Available checks are: VALID_CHARS, LENGTH, FORBIDDEN_WORDS
#
proc check_password {pwd {checks {}}} {

	if {[lsearch $checks VALID_CHARS] > -1} {
		# check only contains valid characters
		if {[regexp {[^A-Za-z0-9]} $pwd]} {
			return "Password contains invalid characters"
		}
	}

	if {[lsearch $checks LENGTH] > -1} {
		# check not too short
		if {[string length $pwd] < 6} {
			return "Password is too short"
		}
	}

	if {[lsearch $checks FORBIDDEN_WORDS] > -1} {
		# check not included in list of banned words specified by playtech
		# (even though several are less than their minimum of 6 characters!)
		set playtech_forbidden [list "SECRET" \
		                             "PASSWORD" \
		                             "GAMBLE" \
		                             "WAGER" \
		                             "PUNTER" \
		                             "BOOKIE" \
		                             "BOOKMAKER" \
		                             "ARSE" \
		                       ]
		if {[lsearch -exact $playtech_forbidden [string toupper $pwd]] != -1} {
			return "Password contains forbidden words"
		}
	}

	return "OB_OK"
}



proc do_cust_reg_upd args {

	global DB

	set cust_id [reqGetArg CustId]

	if {![op_allowed DoCustReg]} {
		err_bind "You do not have permission to register customers"
		go_cust_reg
		return
	}

	set sql_cust {
		update tCustomer set
			lang = ?,
			country_code = ?
		where
			cust_id = ?
	}

	set sql_reg {
		update tCustomerReg set
			nickname = ?,
			title = ?,
			fname = ?,
			lname = ?,
			dob = ?,
			addr_street_1 = ?,
			addr_street_2 = ?,
			addr_street_3 = ?,
			addr_street_4 = ?,
			addr_city = ?,
			addr_postcode = ?,
			telephone = ?,
			email = ?,
			challenge_1 = ?,
			response_1 = ?,
			challenge_2 = ?,
			response_2 = ?,
			id_card_no = ?
		where
			cust_id = ?
	}

	if {[OT_CfgGet FUNC_OVS 0]} {
		set sql_age_vrf_status {
			execute procedure pUpdVrfCustStatus
			(
				p_adminuser     = ?,
				p_cust_id       = ?,
				p_status        = ?,
				p_vrf_prfl_code = ?
			)
		}
	}

	set upd_ext_cust_stmt [inf_prep_sql $DB {
		execute procedure pUpdExtCust(
			p_cust_id =?,
			p_ext_cust_id=?,
			p_code=?,
			p_master=?,
			p_permanent=?,
			p_transactional='N'
		)
	}]

	set external_groups_count [reqGetArg ext_group_count]

	if {$external_groups_count==""} {
		set external_groups_count 0
	}

	if {[OT_CfgGet FUNC_OVS 0]} {
		set age_vrf_status [reqGetArg age_verified_list]
	}

	set stmt_c [inf_prep_sql $DB $sql_cust]
	set stmt_r [inf_prep_sql $DB $sql_reg]
	if {[OT_CfgGet FUNC_OVS 0]} {
		set stmt_a [inf_prep_sql $DB $sql_age_vrf_status]
	}

	inf_begin_tran $DB

	set c [catch {


		set res [inf_exec_stmt $stmt_c\
			[reqGetArg Lang]\
			[reqGetArg Country]\
			[reqGetArg CustId]]
		catch {db_close $res}

		set res [inf_exec_stmt $stmt_r\
			[reqGetArg Nickname]\
			[reqGetArg Title]\
			[reqGetArg FName]\
			[reqGetArg LName]\
			[reqGetArg DOB]\
			[reqGetArg Addr1]\
			[reqGetArg Addr2]\
			[reqGetArg Addr3]\
			[reqGetArg Addr4]\
			[reqGetArg City]\
			[reqGetArg Postcode]\
			[reqGetArg Telephone]\
			[reqGetArg Email]\
			[reqGetArg Challenge1]\
			[reqGetArg Response1]\
			[reqGetArg Challenge2]\
			[reqGetArg Response2]\
			[string toupper [string trim [reqGetArg IdCardNo]]]\
			[reqGetArg CustId]]
		catch {db_close $res}

		if {$vrf_status != "" && [OT_CfgGet FUNC_OVS 0]} {
			set res [inf_exec_stmt $stmt_a\
				$USERNAME\
				$cust_id\
				$vrf_status\
				[OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""]]

			catch {db_close $res}
		}
		for {set r 0} {$r < $external_groups_count} {incr r} {
			set parameter "ext_group_id_$r"
			set code [reqGetArg $parameter]

			set parameter "ext_cust_id_$r"
			set ext_cust_id [reqGetArg $parameter]

			foreach f { master permanent } {
				if {[reqGetArg "ext_${f}_${r}"] == "on"} {
					set $f "Y"
				} elseif {[reqGetArg "ext_${f}_${r}"] == "undef"} {
					set $f "U"
				} else {
					set $f "N"
				}
			}

			set res [inf_exec_stmt $upd_ext_cust_stmt\
					 $cust_id $ext_cust_id $code $master $permanent]
			catch {db_close $res}
		}
		inf_close_stmt $upd_ext_cust_stmt

	} msg]

	inf_close_stmt $stmt_c
	inf_close_stmt $stmt_r
	if {[OT_CfgGet FUNC_OVS 0]} {
		inf_close_stmt $stmt_a
	}

	if {$c == 0} {
		inf_commit_tran $DB
		go_cust
	} else {
		inf_rollback_tran $DB
		err_bind $msg
		go_cust_reg
	}
}



#
# ----------------------------------------------------------------------------
# Search by card number
# ----------------------------------------------------------------------------
#
proc do_card_search args {

	global DB USERID

	regsub -all {[[:space:]]} [reqGetArg CardNo] "" card

	if {[string length $card] < 12} {
		err_bind "Please enter card number with at least 12 digits"
		go_cust_query
		return
	}

	if {[string is integer $card]} {
		err_bind "Invalid characters entered"
		go_cust_query
		return
	}

	# We can no longer simply search on enc_card_no - instead we retrieve all of the
	# cpm_ids from tCPMCCHash for cards
	set hash_rs [card_util::get_cards_with_hash $card "Admin Card Search" "" $USERID]

	if {[lindex $hash_rs 0] == 0} {
		err_bind "Error occurred decrypting cpm_id"
		go_cust_query
		return
	} else {
		set card_matches [lindex $hash_rs 1]
	}

	# card_matches now represents the full range of cpm_ids which match the card number
	# provided. If we have any, add these to the main query where clause
	if {[llength $card_matches] == 0} {
		tpSetVar NumCusts 0
		asPlayFile -nocache cust_list.html
		return
	} else {
		set cpm_id_where "and cc.cpm_id in ([join $card_matches ,])"
	}

	set sql [subst {
		select unique
			c.cust_id,
			c.username,
			c.status,
			c.bet_count - (select count(*) from tbet where acct_id=a.acct_id and status='X') as bet_count,
			c.acct_no,
			c.elite,
			c.country_code,
			a.ccy_code,
			c.cr_date,
			a.balance + a.sum_ap as balance,
			r.fname,
			r.lname,
					r.dob,
			r.email
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			tCustPayMthd cpm,
			tCpmCC  cc
		where
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			c.cust_id = cpm.cust_id and
			cpm.cpm_id = cc.cpm_id and
			cpm.pay_mthd = 'CC' and
			a.owner      <> 'D'
			$cpm_id_where
		order by
			1
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {
		go_cust cust_id [db_get_col $res 0 cust_id]
		db_close $res
		return
	}

	set num_norm  0
	set num_elite 0

	global DATA

	array set DATA [list]

	for {set r 0} {$r < [db_get_nrows $res]} {incr r} {
		set DATA($r,AcctNo) [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($r,Elite)    [db_get_col $res $r elite]
		set DATA($r,CustId)   [db_get_col $res $r cust_id]
		set DATA($r,Username) [db_get_col $res $r username]
		set DATA($r,Status)   [db_get_col $res $r status]
		set DATA($r,BetCount) [db_get_col $res $r bet_count]
		set DATA($r,Country)  [db_get_col $res $r country_code]
		set DATA($r,Currency) [db_get_col $res $r ccy_code]
		set DATA($r,Balance)  [db_get_col $res $r balance]
		set DATA($r,RegDate)  [db_get_col $res $r cr_date]
		set DATA($r,RegFName) [db_get_col $res $r fname]
		set DATA($r,RegLName) [db_get_col $res $r lname]
		set DATA($r,DOB)      [db_get_col $res $r dob]
		set DATA($r,Email)    [db_get_col $res $r email]
		incr num_norm
		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo   DATA AcctNo   cust_idx
	tpBindVar Elite    DATA Elite    cust_idx
	tpBindVar CustID   DATA CustId   cust_idx
	tpBindVar Username DATA Username cust_idx
	tpBindVar Status   DATA Status   cust_idx
	tpBindVar BetCount DATA BetCount cust_idx
	tpBindVar Country  DATA Country  cust_idx
	tpBindVar Currency DATA Currency cust_idx
	tpBindVar Balance  DATA Balance  cust_idx
	tpBindVar RegDate  DATA RegDate  cust_idx
	tpBindVar RegFName DATA RegFName cust_idx
	tpBindVar RegLName DATA RegLName cust_idx
	tpBindVar DOB      DATA DOB      cust_idx
	tpBindVar Email    DATA Email    cust_idx

	set_display_fields

	asPlayFile -nocache cust_list.html

	unset DATA

	db_close $res
}



#
# ----------------------------------------------------------------------------
# Customer detail
# ----------------------------------------------------------------------------
#
proc go_cust args {

	global DB CSORT CMSG DEP_LIMITS CONTACT_HOW\
		XSYS_ACCT USERNAME WTD_LMT CARD_SCHEME PAY_MTHDS CUST_CAT

	set cust_id [reqGetArg CustId]

	tpBindString FromStralfors [reqGetArg FromStralfors]

	foreach {n v} $args {
		set $n $v
	}

	# get the customer
	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.elite,
			c.acct_no,
			a.ccy_code,
			a.acct_type,
			c.bet_count - (select count(*) from tbet where acct_id=a.acct_id and status='X') as bet_count,
			c.cr_date,
			c.sort,
			c.last_bet,
			c.max_stake_scale,
			c.notifyable,
			c.status,
			c.lang,
			c.allow_card,
			c.sig_date,
			c.password,
			c.mobile_pin,
			c.aff_id,
			a.acct_id,
			a.balance + a.sum_ap as balance,
			a.balance_nowtd,
			a.credit_limit,
			a.min_repay,
			a.min_funds,
			a.min_settle,
			a.pay_pct,
			r.nickname,
			r.title,
			r.fname,
			r.mname,
			r.lname,
			r.dob,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_state_id,
			x.state,
			r.addr_country,
			r.addr_postcode,
			c.country_code,
			y.country_name,
			r.id_card_no,
			r.email,
			r.itv_email,
			r.telephone,
			r.mobile,
			r.office,
			r.pager,
			r.fax,
			r.contact_ok,
			r.mkt_contact_ok,
			r.ptnr_contact_ok,
			r.oper_notes,
			r.challenge_1,
			r.response_1,
			r.challenge_2,
			r.response_2,
			r.good_addr,
			r.good_email,
			r.good_mobile,
			r.bank_check,
			r.contact_how,
			r.hear_about_txt,
			r.gender,
			r.ipaddr,
			r.code,
			c.source,
			f1.flag_value as mcs_flag_value,
			f2.flag_value as fraud_flag_value,
			NVL((
				select d.desc from tCustCode d
				where r.code = d.cust_code), '(None)') as desc,
			NVL(f3.flag_value,"") fb_flag_value,
			s.view_date,
			s.notes,
			s.status as msf_status,
			c.liab_group,
			NVL(c.aff_id,'No affiliate') aff_id,
			rs.shop_no,
			rs.shop_name,
			rd.district_no,
			a.owner,
			a.owner_type,
			r.rn_contact_no,
			nr.banner_tag,
			nr.report_date,
			r.staff_member,
			NVL(ocr.rep_code, '(none)') as rep_code,
			ocr.status as rep_code_status
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			tCountry y,
			outer tCountryState  x,
			outer tCustStkDetail s,
			outer tCustomerFlag  f1,
			outer tCustomerFlag  f2,
			outer tCustomerFlag  f3,
			outer tNetReferCust  nr,
			outer (
				tRetailShop     rs,
				tRetailDistrict rd
			),
			outer tOnCourseRep ocr
		where
			c.cust_id      = ? and
			c.cust_id      = a.cust_id and
			c.cust_id      = r.cust_id and
			c.cust_id      = f1.cust_id and
			c.cust_id      = f2.cust_id and
			c.cust_id      = s.cust_id and
			c.cust_id      = nr.cust_id and
			c.country_code = y.country_code and
			x.id	       = r.addr_state_id and
			f1.flag_name   = "MCS_ACTIVE" and
			f2.flag_name   = "fraud_status" and
			f3.cust_id     = c.cust_id and
			f3.flag_name   = "FootBall Team" and
			rs.shop_id     = r.shop_id and
			rd.district_id = rs.district_id and
			ocr.acct_id = a.acct_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set acct_id [db_get_col $res 0 acct_id]
	set status  [db_get_col $res 0 status]
	set ccy     [db_get_col $res 0 ccy_code]
	set country_code [db_get_col $res 0 country_code]
	set num_elite 0

	if {[OT_CfgGet CUST_WTD_LIMITS 0]} {
		# Get the customer specific fraud check withdrawal limits.

		set sql {
			select
			  f.pay_mthd,
			  pm.desc as pay_desc,
			  f.scheme,
			  cs.scheme_name,
			  f.days_since_dep_1,
			  f.days_since_wtd,
			  f.max_wtd,
			  f.limit_id
			from
			  tFraudLimitWtdAcc f,
			  tPayMthd pm,
			  outer tCardSchemeInfo cs
			where
			  f.pay_mthd  = pm.pay_mthd
			  and f.scheme    = cs.scheme
			  and f.acct_id = ?
			order by
			  f.pay_mthd, f.scheme, f.days_since_dep_1, f.days_since_wtd
		}

		set stmt            [inf_prep_sql $DB $sql]
		set res_fraud_lmts  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res_fraud_lmts]

		set m -1

		for {set i 0} {$i < $nrows} {incr i} {

			if {$m == -1 || $WTD_LMT($m,pay_mthd) != [db_get_col $res_fraud_lmts $i pay_mthd] \
			|| $WTD_LMT($m,pay_schm) != [db_get_col $res_fraud_lmts $i scheme] } {
				incr m
				set WTD_LMT($m,num_rows) 1
				set WTD_LMT($m,pay_mthd)         [db_get_col $res_fraud_lmts $i pay_mthd]
				set WTD_LMT($m,pay_desc)         [db_get_col $res_fraud_lmts $i pay_desc]
				set WTD_LMT($m,scheme_name)      [db_get_col $res_fraud_lmts $i scheme_name]
				set WTD_LMT($m,pay_schm)         [db_get_col $res_fraud_lmts $i scheme]
			} else {
				incr WTD_LMT($m,num_rows)
			}
			set rowIx [expr {$WTD_LMT($m,num_rows) - 1}]
			set WTD_LMT($m,$rowIx,scheme)         [db_get_col $res_fraud_lmts $i scheme]
			set WTD_LMT($m,$rowIx,scheme_name)    [db_get_col $res_fraud_lmts $i scheme_name]
			set WTD_LMT($m,$rowIx,first_dep)      [db_get_col $res_fraud_lmts $i days_since_dep_1]
			set WTD_LMT($m,$rowIx,days_last_wtd)  [db_get_col $res_fraud_lmts $i days_since_wtd]
			set WTD_LMT($m,$rowIx,max_wtd)        [db_get_col $res_fraud_lmts $i max_wtd]
			set WTD_LMT($m,$rowIx,limitId)        [db_get_col $res_fraud_lmts $i limit_id]
		}

		tpSetVar NumFraudLimits [incr m]

		db_close $res_fraud_lmts

		# Bind variables.
		tpBindVar NumFraudRows    WTD_LMT num_rows      pay_idx
		tpBindVar payMthd         WTD_LMT pay_mthd      pay_idx
		tpBindVar payDesc         WTD_LMT pay_desc      pay_idx
		tpBindVar scheme_name     WTD_LMT scheme_name   pay_idx
		tpBindVar limitId         WTD_LMT limitId       pay_idx row_idx
		tpBindVar scheme          WTD_LMT scheme        pay_idx row_idx
		tpBindVar firstDep        WTD_LMT first_dep     pay_idx row_idx
		tpBindVar daysLastWtd     WTD_LMT days_last_wtd pay_idx row_idx
		tpBindVar maxWtd          WTD_LMT max_wtd       pay_idx row_idx

		# Get card schemes and payment methods for add withdrawal limit form
		set sql {
			select
			  "CC" as pay_mthd,
			  p.desc,
			  c.scheme,
			  c.scheme_name
			from
			  tCardSchemeInfo c,
			  tPayMthd        p
			where
			  c.scheme not in (select
					  scheme
					 from
					  tFraudLimitWtdAcc
					 where
					  scheme is not null and
					  acct_id = ?)
			  and p.pay_mthd == "CC"
			union
			select
			  pay_mthd,
			  desc,
			  "----" as scheme,
			  "" as scheme_name
			from
			  tPayMthd
			where
			  pay_mthd not in (select
					     pay_mthd
					   from
					     tFraudLimitWtdAcc
					   where
					     acct_id = ?)
			  and pay_mthd != "CC";
		}

		set stmt [inf_prep_sql $DB $sql]
		set res_pay_mthds  [inf_exec_stmt $stmt $acct_id $acct_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res_pay_mthds]

		set m 0

		set c 0

		for {set i 0} {$i < $nrows} {incr i} {

			if {[db_get_col $res_pay_mthds $i pay_mthd] == "CC"} {
				if {$c == 0} {
					set PAY_MTHDS($m,pay_mthd) [db_get_col $res_pay_mthds $i pay_mthd]
					set PAY_MTHDS($m,desc)     [db_get_col $res_pay_mthds $i desc]
					incr m
				}
				set CARD_SCHEME($c,scheme)      [db_get_col $res_pay_mthds $i scheme]
				set CARD_SCHEME($c,scheme_name) [db_get_col $res_pay_mthds $i scheme_name]
				incr c
			} else {
				set PAY_MTHDS($m,pay_mthd) [db_get_col $res_pay_mthds $i pay_mthd]
				set PAY_MTHDS($m,desc)     [db_get_col $res_pay_mthds $i desc]
				incr m
			}
		}

		tpSetVar NumFraudSchemes $c
		tpSetVar NumFraudPayMthds $m

		tpBindVar cmb_scheme      CARD_SCHEME scheme      scheme_idx
		tpBindVar cmb_scheme_name CARD_SCHEME scheme_name scheme_idx

		tpBindVar cmb_pay_mthd PAY_MTHDS pay_mthd pay_mtd_idx
		tpBindVar cmb_desc     PAY_MTHDS desc     pay_mtd_idx

		db_close $res_pay_mthds

	}

	if {[OT_CfgGet FUNC_TEXT_BETTING_SUPPORT 0]} {
		tpSetVar MustChangeMobile 0

		# For Text Betting support section check whether
		# a mobile PIN number has already been set
		if {[db_get_col $res 0 mobile_pin] != ""} {
			tpSetVar MobilePinExists 1
		} else {
			tpSetVar MobilePinExists 0

			# Check whether the mobile on this account is being
			# used for text betting on any other accounts
			set mobile [db_get_col $res 0 mobile]
			if {$mobile != ""} {
				set duplicate_mobile_qry \
					 {
					 select
						count(*) acct_count
					 from
						tcustomerreg r,
						tcustomer c
					 where
						r.mobile = ? and
						c.cust_id <> ? and
						c.status = 'A' and
						c.mobile_pin is not null and
						c.cust_id = r.cust_id}

				set stmt_duplicate_mobile [inf_prep_sql $DB $duplicate_mobile_qry]
				set res_duplicate_mobile  [inf_exec_stmt $stmt_duplicate_mobile $mobile $cust_id]
				inf_close_stmt $stmt_duplicate_mobile

				set acct_count [db_get_col $res_duplicate_mobile 0 acct_count]

				if {$acct_count > 0} {
					# Another customer has the same mobile number with
					# a PIN registered so we can't allow this one to
					# register a PIN for text betting without changing
					# mobile number
					tpSetVar MustChangeMobile 1
				}
				db_close $res_duplicate_mobile
			}
		}
	}

	if {[OT_CfgGet FUNC_INTERNET_ACTIVATION 0]} {
		tpSetVar InternetActivated [get_customer_flag $cust_id "inet_activated" 0]
	}

	if {[OT_CfgGet ENABLE_RISKGUARDIAN 0] == 1} {

		# Get the number of Risk Guardian failures for this customer
		set sql_rg [subst {
			select
			    count(*) as num_rg_failures
			from
			    tRGFailure
			where
				cust_id = ?
		}]

		set stmt_rg [inf_prep_sql $DB $sql_rg]
		set res_rg  [inf_exec_stmt $stmt_rg $cust_id]
		inf_close_stmt $stmt_rg

		set nrows [db_get_nrows $res_rg]
		if {$nrows == 1} {
			set num_rg_failures [db_get_col $res_rg 0 num_rg_failures]
		} else {
			set num_rg_failures "UNKNOWN"
		}

		tpBindString numRiskGuardianFailures $num_rg_failures
		tpSetVar numRiskGuardianFailures $num_rg_failures
	}

	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		# For obtaining information about this customers
		# tokens.
		set sql_token [subst {

			select
				count(ct.cust_token_id)           as num_tokens,
				NVL (sum(ct.value),0)             as open_total,
				NVL (sum((select sum(tr.redemption_amount) from tCustTokRedemption tr where ct.cust_token_id = tr.cust_token_id)),0) as redeem_total,
				ct.redeemed,
				ct.status
			from
				tCustomerToken           ct,
				tTokenAmount             ta,
				tAcct                     a
			where ct.cust_id       = ?
			  and ct.cust_id       = a.cust_id
			  and ct.token_id      = ta.token_id
			  and ta.ccy_code      = a.ccy_code
			  and ct.status        in ('A','X','S')
			  and (
					ct.redeemed = 'Y'
				 or ct.expiry_date > current
			  )
			  and (ct.ref_type in ('FOG','CGLW','EXP')
			  or exists (
			  	select 1
				from tPossibleBet
				where tPossibleBet.token_id = ct.token_id
			  ) or exists (
			  	select 1 from tRedemptionVal
				where tRedemptionVal.redemption_id = ct.adhoc_redemp_id
			  ))
			  group by ct.redeemed, ct.status
		}]

		set stmt_token [inf_prep_sql $DB $sql_token]
		set res_token  [inf_exec_stmt $stmt_token $cust_id]
		inf_close_stmt $stmt_token

		set nrows             [db_get_nrows $res_token]
		set num_redeem_tokens 0
		set num_open_tokens   0
		set open_total        0
		set redeem_total      0

		for {set i 0} {$i < $nrows} {incr i} {
			set redeem_total      [expr {$redeem_total + [db_get_col $res_token $i redeem_total]}]
			if {[db_get_col $res_token $i redeemed] == "Y"} {
				set num_redeem_tokens [expr {$num_redeem_tokens + [db_get_col $res_token $i num_tokens]}]
			} elseif {[db_get_col $res_token $i redeemed] == "P"} {
				set open_total        [expr {$open_total + [db_get_col $res_token $i open_total]}]
				set num_redeem_tokens [expr {$num_redeem_tokens + [db_get_col $res_token $i num_tokens]}]
				set num_open_tokens   [expr {$num_open_tokens + [db_get_col $res_token $i num_tokens]}]
			} else {
				# We do not want to count deleted tokens as open - these need to be returned by
				# query because redeemed tokens are status 'X'
				if {[db_get_col $res_token $i status] != "X"} {
					set open_total        [expr {$open_total + [db_get_col $res_token $i open_total]}]
					set num_open_tokens   [expr {$num_open_tokens + [db_get_col $res_token $i num_tokens]}]
				}
			}
		}

		tpBindString tokenRedeemTotal [format %.2f $redeem_total]
		tpBindString numRedeemTokens  $num_redeem_tokens
		tpSetVar     numRedeemTokens  $num_redeem_tokens

		tpBindString tokenOpenTotal   [format %.2f $open_total]
		tpBindString numOpenTokens    $num_open_tokens
		tpSetVar     numOpenTokens    $num_open_tokens

		db_close $res_token
	}

	if {[OT_CfgGet FUNC_REVERSE_WITHDRAWALS 0]} {
		set reverible_pmt_sql {
			select
				NVL(sum(p.amount),0) as balance
			from
				tPmt p,
				tPmtPending pp
			where
				    pp.acct_id      = ?
				and p.pmt_id        = pp.pmt_id
				and p.status        = 'P'
				and pp.process_date > current
				and p.payment_sort  = 'W'
		}

		set reverible_pmt_stmt [inf_prep_sql $DB $reverible_pmt_sql]
		set reverible_pmt_res  [inf_exec_stmt $reverible_pmt_stmt $acct_id]
		inf_close_stmt $reverible_pmt_stmt

		set reversible_wtd_balance 0
		if {[db_get_nrows $reverible_pmt_res] == 1} {
			set reversible_wtd_balance [db_get_col $reverible_pmt_res 0 balance]
		}
		tpBindString reversible_wtd_balance $reversible_wtd_balance

		db_close $reverible_pmt_res
	}

	if {[OT_CfgGet FUNC_SEARCH_XSYS_ACCT 0]} {
		set xsys_acct_sql {
			select distinct
				xg.desc as sys_grp_name,
				xa.xsys_username
			from
				tXSysHost      xh,
				tXSysHostGrp   xg,
				tXSysHostGrpLk xhl,
				outer(
					tXSysAcct     xa,
					tXSysAcctLink xl
				)
			where
				xl.acct_id      in (?,NULL)        and
				xl.xsys_acct_id = xa.xsys_acct_id  and
				xa.system_id    = xh.system_id     and
				xh.system_id    = xhl.system_id    and
				xhl.group_id    = xg.group_id      and
				xg.type         = 'SYS'
		}

		set stmt_xsys_acct [inf_prep_sql $DB $xsys_acct_sql]
		set res_xsys_acct  [inf_exec_stmt $stmt_xsys_acct $acct_id]
		inf_close_stmt $stmt_xsys_acct

		catch {array unset XSYS_ACCT}

		set XSYS_ACCT(num) [db_get_nrows $res_xsys_acct]

		for {set i 0} {$i < $XSYS_ACCT(num)} {incr i} {
			set XSYS_ACCT($i,sys_grp_name)   [db_get_col $res_xsys_acct $i sys_grp_name]
			set XSYS_ACCT($i,xsys_alias)    [db_get_col $res_xsys_acct $i xsys_username]
		}

		tpSetVar num_xsys_aliases $XSYS_ACCT(num)

		tpBindVar xsys_sys_grp_name XSYS_ACCT sys_grp_name  xsys_acct_idx
		tpBindVar xsys_alias       XSYS_ACCT xsys_alias    xsys_acct_idx
	}

	set arr_date                  [split [db_get_col $res 0 view_date] -]

	set username                  [db_get_col $res 0 username]
	set password                  [db_get_col $res 0 password]

	if {[db_get_col $res 0 elite] == "Y"} {
		incr num_elite
	}

	tpSetVar     isPlatinum       [is_platinum_customer [db_get_col $res 0 code]]
	tpBindString Elite            [db_get_col $res 0 elite]
	tpBindString CustId           [db_get_col $res 0 cust_id]
	tpSetVar     CustId           [db_get_col $res 0 cust_id]
	tpBindString Username         [db_get_col $res 0 username]
	tpBindString AcctNo           [db_get_col $res 0 acct_no]
	tpBindString AcctCCY          [db_get_col $res 0 ccy_code]
	tpBindString AcctType         [db_get_col $res 0 acct_type]
	tpSetVar     AcctType         [db_get_col $res 0 acct_type]
	tpBindString min_repay        [db_get_col $res 0 min_repay]
	tpBindString min_funds        [db_get_col $res 0 min_funds]
	tpBindString min_settle       [db_get_col $res 0 min_settle]
	tpBindString pay_pct          [db_get_col $res 0 pay_pct]
	tpBindString CustomerGroup    [db_get_col $res 0 desc]
	tpBindString RegDate          [db_get_col $res 0 cr_date]
	tpBindString Notifyable       [db_get_col $res 0 notifyable]
	tpBindString CustomerSort     [db_get_col $res 0 sort]
	tpBindString MaxStakeScale    [db_get_col $res 0 max_stake_scale]
	tpBindString AcctStatus       $status
	tpBindString Lang             [db_get_col $res 0 lang]
	tpBindString AcctId           [db_get_col $res 0 acct_id]
	tpBindString AcctBalance      [db_get_col $res 0 balance]
	tpBindString AcctBalanceNoWtd [db_get_col $res 0 balance_nowtd]
	tpBindString CreditLimit      [db_get_col $res 0 credit_limit]
	tpBindString NickName         [db_get_col $res 0 nickname]
	tpBindString Title            [db_get_col $res 0 title]
	tpBindString FName            [db_get_col $res 0 fname]
	tpBindString LName            [db_get_col $res 0 lname]
	tpBindString DOB              [db_get_col $res 0 dob]
	tpBindString Addr1            [db_get_col $res 0 addr_street_1]
	tpBindString Addr2            [db_get_col $res 0 addr_street_2]
	tpBindString Addr3            [db_get_col $res 0 addr_street_3]
	tpBindString Addr4            [db_get_col $res 0 addr_street_4]
	tpBindString City             [db_get_col $res 0 addr_city]
	tpBindString Country_Postal   [db_get_col $res 0 addr_country]
	tpBindString State            [db_get_col $res 0 state]
	tpBindString Postcode         [db_get_col $res 0 addr_postcode]
	tpBindString Country          [db_get_col $res 0 country_name]
	tpBindString IdCard           [db_get_col $res 0 id_card_no]
	tpBindString Email            [db_get_col $res 0 email]
	tpBindString ITV_Email        [db_get_col $res 0 itv_email]
	tpBindString Telephone        [db_get_col $res 0 telephone]
	tpBindString Mobile           [db_get_col $res 0 mobile]
	tpBindString Office           [db_get_col $res 0 office]
	tpBindString Pager            [db_get_col $res 0 pager]
	tpBindString Fax              [db_get_col $res 0 fax]
	tpBindString ContactOK        [db_get_col $res 0 contact_ok]
	tpBindString HearAboutTxt     [db_get_col $res 0 hear_about_txt]
	tpBindString MktContactOK     [db_get_col $res 0 mkt_contact_ok]
	tpBindString PtnrContactOK    [db_get_col $res 0 ptnr_contact_ok]
	tpBindString OperNotes        [db_get_col $res 0 oper_notes]
	tpBindString AllowCard        [db_get_col $res 0 allow_card]
	tpBindString Challenge1       [db_get_col $res 0 challenge_1]
	tpBindString Challenge2       [db_get_col $res 0 challenge_2]
	tpBindString Gender           [db_get_col $res 0 gender]
	tpBindString IPAddr           [db_get_col $res 0 ipaddr]
	tpBindString RightNowId       [db_get_col $res 0 rn_contact_no]
	# Optionally, only allow admin users with required permission
	# to view the security answers
	if {[OT_CfgGet FUNC_HIDE_SECURITY_RESPONSE 0] == 1 &&
				![op_allowed ViewSecurityResponse]} {
		tpBindString Response1 "********"
	} else {
		tpBindString Response1  [db_get_col $res 0 response_1]
	}
	if {[OT_CfgGet FUNC_HIDE_SECURITY_RESPONSE 0] == 1 &&
				![op_allowed ViewSecurityResponse]} {
		tpBindString Response1 "********"
	} else {
		tpBindString Response2  [db_get_col $res 0 response_2]
	}
	tpBindString MemorableDate    [db_get_col $res 0 sig_date]
	tpBindString RegSource        [db_get_col $res 0 source]
	tpBindString MCSActive        [db_get_col $res 0 mcs_flag_value]
	tpSetVar     MCSActive        [db_get_col $res 0 mcs_flag_value]
	tpBindString FraudStatus      [db_get_col $res 0 fraud_flag_value]
	tpBindString GoodAddr         [db_get_col $res 0 good_addr]
	tpBindString GoodEmail        [db_get_col $res 0 good_email]
	tpBindString GoodMobile       [db_get_col $res 0 good_mobile]
	tpBindString BankCheck        [db_get_col $res 0 bank_check]
	tpBindString fbteam           [db_get_col $res 0 fb_flag_value]
	tpBindString review           [db_get_col $res 0 notes]
	tpBindString yearMSF          [lindex $arr_date 0]
	tpBindString monthMSF         [lindex $arr_date 1]
	tpBindString dayMSF           [lindex $arr_date 2]
	tpBindString statusMSF        [db_get_col $res 0 msf_status]
	tpBindString LiabGroup        [db_get_col $res 0 liab_group]
	tpBindString AffID            [db_get_col $res 0 aff_id]
	tpBindString RepCode          [db_get_col $res 0 rep_code]
	tpSetVar     RepCodeStatus    [db_get_col $res 0 rep_code_status]
	if {[OT_CfgGet CAPTURE_FULL_NAME 0]} {
		tpBindString MName    [db_get_col $res 0 mname]
	} else {
		tpBindString MName    ""
	}
	set aff_desc [db_get_col $res 0 aff_id]
	if {[OT_CfgGetTrue FUNC_SHOW_AFF_ON_CUST] } {
		if {$aff_desc != ""} {
			#
			# try and get the main affiliate name
			#
			set sql {
				select
					a.cust_id,
					ac.aff_name,
					f.aff_name as aff_site_name
				from
					taffiliate f,
					taffacct ac,
					tacct a
				where
					f.aff_id = ? and
					f.aff_acct_id = ac.aff_acct_id and
					ac.acct_id = a.acct_id
			}
			set stmt [inf_prep_sql $DB $sql]
			set res_aff  [inf_exec_stmt $stmt $aff_desc]
			inf_close_stmt $stmt
			if {[db_get_nrows $res_aff] == 1} {
				tpBindString aff_cust_id [db_get_col $res_aff 0 cust_id]
				set aff_desc "Parent affiliate: [db_get_col $res_aff 0 aff_name]<br>Child affiliate: [db_get_col $res_aff 0 aff_site_name] (id: $aff_desc)"
			}
			db_close $res_aff
		} else {
			set aff_desc "Customer not affiliated"
		}
		tpBindString Affiliate $aff_desc
	}

	set bet_count  [db_get_col $res 0 bet_count]
	set acct_id    [db_get_col $res 0 acct_id]
	set last_bet   [db_get_col $res 0 last_bet]

	set contact_how [db_get_col $res 0 contact_how]

	tpBindString contact_how $contact_how

	if {[OT_CfgGet PLAYTECH_AFFILIATES_UNITED 0]} {

		#
		# Need to check for AU banner tag
		#

		# Assume AU banner doesn't exist
		set banner_tag_exists 0

		set sql {
			select
				advertiser,
				affiliate_id,
				xsys_promo_code
			from
				tAUCust
			where
				cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res_au [inf_exec_stmt $stmt $cust_id]

		set banner_tag  ""
		set banner_type ""

		if {[db_get_nrows $res_au] > 0} {


			set affiliate_id [db_get_col $res_au 0 affiliate_id]
			set advertiser   [db_get_col $res_au 0 advertiser]
			set promo_code   [db_get_col $res_au 0 xsys_promo_code]

			if {$affiliate_id != "" || $advertiser != "" || $promo_code != ""} {
				set banner_tag_exists 1
			}

			tpBindString AUAffiliateID $affiliate_id
			tpBindString AUAdvertiser  $advertiser
			tpBindString AUPromoCode   $promo_code

		}

		tpSetVar     BannerTagExists  $banner_tag_exists

	}

	# Bind NetRefer Banner Tag
	tpBindString BannerTag     [db_get_col $res 0 banner_tag]
	tpBindString NetRefDate    [db_get_col $res 0 report_date]

	set acct_owner [db_get_col $res 0 owner]

	tpBindString ShopNumber   [db_get_col $res 0 shop_no]
	tpBindString ShopName     [db_get_col $res 0 shop_name]
	tpBindString DistrictCode [db_get_col $res 0 district_no]
	tpBindString Owner        $acct_owner
	tpBindString OwnerType    [db_get_col $res 0 owner_type]
	tpBindString StaffMember  [db_get_col $res 0 staff_member]

	# For each of Email,Letter,Telephone and SMS
	# set the value to whether or not contact_how has that letter in it
	array set contact_how_map [OT_CfgGet CONTACT_HOW_MAP ""]
	if {[array size contact_how_map] > 0} {

		tpBindString contact_count [array size contact_how_map]

		set idx 0
		foreach {code name} [array get contact_how_map] {
			set CONTACT_HOW($idx,code) $code
			set CONTACT_HOW($idx,name) $name
			set CONTACT_HOW($idx,chk) \
				[expr {[string first $code $contact_how] >= 0?"checked":""}]
			incr idx
		}
		set CONTACT_HOW(num) $idx

		tpBindString contact_how_all_chk\
			[expr {[string length $contact_how] == $idx?"checked":""}]

		unset idx

		# the one letter code, the name of the contact method and whether it is
		# checked
		tpBindVar contact_how_code CONTACT_HOW code contact_how_idx
		tpBindVar contact_how_name CONTACT_HOW name contact_how_idx
		tpBindVar contact_how_chk  CONTACT_HOW chk  contact_how_idx
	}
	array unset contact_how_map

	db_close $res


	#
	# get the customer limits including exclusion info
	#
	if {[OT_CfgGetTrue FUNC_MENU_IGF]} {

		if {[OT_CfgGetTrue IGF_PLAYER_PROTECTION]
				|| [OT_CfgGetTrue IGF_SESSION_TRACKING]} {
			ADMIN::IGF::go_cust_limits $cust_id
		}

		if {[OT_CfgGetTrue IGF_PLAYER_PROTECTION]} {
			ADMIN::IGF::go_exclusions $cust_id
		}

		#
		# ... wagering requirements, ...
		#
		tpBindString wager_reqt_balance  [ADMIN::IGF::_get_wager_reqt_balance $acct_id]

		#
		# ... and held funds.
		#
		tpBindString held_fund_balance  [ADMIN::IGF::_get_held_fund_balance $acct_id]

		#
		# Wagering Requirements
		#
		tpBindString wager_reqt_balance  [ADMIN::IGF::_get_wager_reqt_balance $acct_id]

		#
		# Held Funds
		#
		tpBindString held_fund_balance  [ADMIN::IGF::_get_held_fund_balance $acct_id]


	}

	#
	# Customer Sort
	#
	set sql {
		select
			sort,
			desc
		from
			tCustomerSort
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt

	tpSetVar NumCustSorts [set n_rows [db_get_nrows $res]]

	array set CSORT [list]

	for {set r 0} {$r < $n_rows} {incr r} {
		set CSORT($r,sort)  [db_get_col $res $r sort]
		set CSORT($r,desc)  [db_get_col $res $r desc]
	}

	db_close $res

	tpBindVar CustSortSort CSORT sort sort_idx
	tpBindVar CustSortDesc CSORT desc sort_idx

	#
	# Sum stakes & winnings
	#
	set tot_xg_win        0
	set tot_xg_ref        0
	set tot_stld_xg_stk   0
	set tot_stld_xg_win   0
	set tot_stld_xg_ref   0
	set tot_unstld_xg_stk 0
	set tot_xg_stk        0
	set tot_xg_bet        0



	# retrieve xgame bet information
	if {[OT_CfgGet XGAME_TABLES "0"] == "1"} {

		set sql [subst {
			select
				sum(1)          xgame_bet_count,
				sum(b.stake)    stakes,
				sum(b.winnings) winnings,
				sum(b.refund)   refunds,
				settled
			from
				tXGameBet b,
				tXGameSub s
			where
				s.acct_id = ?
				and s.xgame_sub_id = b.xgame_sub_id
			group by settled
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			if {[db_get_col $res $i settled] == "N"} {
				set tot_unstld_xg_stk [db_get_col $res $i stakes]
			} else {
				set tot_stld_xg_stk [db_get_col $res $i stakes]
				set tot_stld_xg_win [db_get_col $res $i winnings]
				set tot_stld_xg_ref [db_get_col $res $i refunds]
			}

			set tot_xg_win [expr $tot_xg_win + [db_get_col $res $i winnings]]
			set tot_xg_ref [expr $tot_xg_ref + [db_get_col $res $i refunds]]
			set tot_xg_bet\
				[expr $tot_xg_bet + [db_get_col $res $i xgame_bet_count]]
		}

		set tot_xg_stk [expr {$tot_stld_xg_stk + $tot_unstld_xg_stk}]

		db_close $res
	}

	# sum other bets

	# settled:
	set s_sql {
		select
			nvl(sum(s.stake),0)        as stakes,
			nvl(sum(s.returns),0)      as returns
		from
			tBetSummary s
		where
			s.acct_id = ? and
			total_type = 'F';
	}

	# unsettled:
	set u_sql {
		select
			nvl(sum(b.stake),0)        as stakes
		from
			tBet b,
			tBetUnstl u
		where
			u.acct_id = ? and
			u.bet_id = b.bet_id and
			u.bet_id not in (
				select
					hb.bet_id
				from
					tHedgedBet hb,
					tBet b2
				where
					hb.bet_id = b2.bet_id
					and b2.acct_id = ?
			);
	}

	set tot_unstld_sports_stk 0
	set tot_stld_sports_stk   0
	set tot_sports_stk        0

	set stmt [inf_prep_sql $DB $s_sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt


	set tot_stld_sports_stk [db_get_col $res 0 stakes]
	set tot_stld_sports_ret [db_get_col $res 0 returns]

	db_close $res

	set stmt [inf_prep_sql $DB $u_sql]
	set res  [inf_exec_stmt $stmt $acct_id $acct_id]
	inf_close_stmt $stmt

	set tot_unstld_sports_stk [db_get_col $res 0 stakes]

	db_close $res

	# If it's a customer who can place hedged bets, then subtract the hedged bet values
	if {$acct_owner == "G"} {
		set sql [subst {
			select
				nvl(sum(b.stake),0) stakes
			from
				tBet b,
				tBetUnstl u,
				tHedgedBet hb
			where
				b.bet_id = hb.bet_id
				and b.bet_id = u.bet_id
				and u.acct_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		set tot_unstld_sports_stk [expr $tot_unstld_sports_stk - [db_get_col $res 0 stakes]]

		db_close $res
	}

	set tot_sports_stk [expr {$tot_stld_sports_stk + $tot_unstld_sports_stk}]

	# sum pool bets
	set s_sql {
		select
			nvl(sum(s.stake),0)        as stakes,
			nvl(sum(s.returns),0)      as returns
		from
			tBetSummary s
		where
			s.acct_id = ? and
			total_type = 'P';
	}
	set u_sql {
		select
			nvl(sum(b.stake),0)        as stakes
		from
			tPoolBet b,
			tPoolBetUnstl u
		where
			b.acct_id = ? and
			u.pool_bet_id = b.pool_bet_id;
	}

	set tot_unstld_pool_stk 0
	set tot_stld_pool_stk   0
	set tot_stld_pool_ret   0

	set tot_pool_stk        0

	set stmt [inf_prep_sql $DB $s_sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt

	set tot_stld_pool_stk [db_get_col $res 0 stakes]
	set tot_stld_pool_ret [db_get_col $res 0 returns]

	db_close $res

	set stmt [inf_prep_sql $DB $u_sql]
	set res  [inf_exec_stmt $stmt $acct_id]
	inf_close_stmt $stmt

	set tot_unstld_pool_stk [db_get_col $res 0 stakes]

	db_close $res

	# Sum hedged bets
	# Only bother summing hedged bets if the user can hedge
	if {$acct_owner == "G"} {
		set tot_hedge_stk        0
		set tot_hedge_win        0
		set tot_hedge_ref        0

		set sql {
			select
				nvl(sum(b.stake),0)    stakes,
				nvl(sum(b.winnings),0) winnings,
				nvl(sum(b.refund),0)   refunds
			from
				tBet b,
				tHedgedBet h
			where
				h.bet_id = b.bet_id and
				b.acct_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res] > 0} {
			set tot_hedge_stk [db_get_col $res 0 stakes]
			set tot_hedge_win [db_get_col $res 0 winnings]
			set tot_hedge_ref [db_get_col $res 0 refunds]
		}

		db_close $res

		tpSetVar isHedgingAccount 1

		tpBindString TotStakesHedge   [format "%0.2f" [expr $tot_hedge_stk]]
		tpBindString TotWinningsHedge [format "%0.2f" [expr $tot_hedge_win]]
		tpBindString TotRefundsHedge  [format "%0.2f" [expr $tot_hedge_ref]]
	}

	set tot_pool_stk [expr {$tot_stld_pool_stk + $tot_unstld_pool_stk}]
	set tot_stld_xg_ret [expr $tot_stld_xg_win - $tot_stld_xg_ref]
	set tot_xg_ret [expr $tot_xg_win - $tot_xg_ref]

	set tot_num_bets [expr $tot_xg_bet  +  $bet_count]
	tpBindString NumBets         $tot_num_bets
	tpBindString TotStldStakes   [format "%0.2f" [expr $tot_stld_xg_stk +\
	                                                   $tot_stld_sports_stk +\
	                                                   $tot_stld_pool_stk]]

	tpBindString TotStldStakesXG    [format "%0.2f" [expr $tot_stld_xg_stk]]
	tpBindString TotStldStakesPool  [format "%0.2f" [expr $tot_stld_pool_stk]]
	tpBindString TotStldStakesSport [format "%0.2f" [expr $tot_stld_sports_stk]]

	tpBindString TotUnStldStakes [format "%0.2f" [expr $tot_unstld_xg_stk +\
	                                                   $tot_unstld_sports_stk +\
	                                                   $tot_unstld_pool_stk]]

	tpBindString TotUnStldStakesXG    [format "%0.2f" [expr $tot_unstld_xg_stk]]
	tpBindString TotUnStldStakesPool  [format "%0.2f" [expr $tot_unstld_pool_stk]]
	tpBindString TotUnStldStakesSport [format "%0.2f" [expr $tot_unstld_sports_stk]]

	tpBindString TotStakes       [format "%0.2f" [expr $tot_xg_stk +\
	                                                   $tot_sports_stk +\
	                                                   $tot_pool_stk]]
	tpBindString TotReturns      [format "%0.2f" [expr $tot_stld_sports_ret +\
	                                                   $tot_stld_pool_ret +\
													   $tot_xg_ret]]


	# Running Balance Figures
	# ======================
	# The RB figure is calculated only over settled bets, for all systems
	# (lotteries, sportsbook, telebet, pool). This does not includes
	# fog or external games activity
	#
	# RB (settled) =  ( SUM(stakes) - [SUM(winnings) + SUM(refunds)] )

	set tot_stld_stks_rb [expr $tot_stld_xg_stk+\
	                           $tot_stld_pool_stk+$tot_stld_sports_stk]
	set tot_stld_rets_rb [expr $tot_stld_xg_ret+\
	                           $tot_stld_sports_ret+$tot_stld_pool_ret]

	tpBindString RunningBalance [format "%0.2f" \
	    [expr $tot_stld_stks_rb-$tot_stld_rets_rb]]

	#
	# Bind Date of last bet
	#
	if {[OT_CfgGet XGAME_TABLES "0"] == "1"} {
		#
		# retrieve date of last xgame bet
		#  - note not using date of last xgame subscription!
		#
		set sql {
			select first 1 b.cr_date
			from    tXGameBet b,
				tXGameSub s
			where   s.acct_id = ?
				and s.xgame_sub_id = b.xgame_sub_id
			order by b.cr_date desc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res] == 1} {
			set last_xgame_bet  [db_get_col $res 0 cr_date]
			if {$last_xgame_bet > $last_bet} {
				set last_bet $last_xgame_bet
			}
		}
		db_close $res
	}

	#
	# Only display date of last bet if num_bets > 0 (obviously...)
	# Check needed: because When user registers, this last_bet date defaults
	# to current As last_bet stored in tCustomer defaults to current ...
	#
	if {$tot_num_bets > 0} {
		tpBindString LastBet $last_bet
	}

	#
	# Funds In/Out
	#
	if {[OT_CfgGet FUNC_EXT_WTD 0]} {
		show_last_fund_xfer O $acct_id
		show_todays_fund_xfer O $acct_id
	}

	if {[OT_CfgGet FUNC_EXT_DEP 0]} {
		show_last_fund_xfer I $acct_id
		show_todays_fund_xfer I $acct_id
	}

	#
	# Manual adjustment types
	#
	ADMIN::ADJ::bind_man_adj


	#
	# Customer stop codes
	#
	if {[OT_CfgGet FUNC_CUST_STOP_CODES 0]} {
		set sql [subst {
			select
				cust_id,
				cr_date,
				code,
				reason
			from
				tCustStopCode
			where
				cust_id = ?
			order by
				cr_date
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res_code [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		tpSetVar NumCustStopCodes [db_get_nrows $res_code]

		tpBindTcl CustCode     sb_res_data $res_code code_idx code
		tpBindTcl CustCodeDate sb_res_data $res_code code_idx cr_date
		tpBindTcl CustCodeReas sb_res_data $res_code code_idx reason
	}

	if {[OT_CfgGet FUNC_CUST_STATUS_FLAGS 0]} {
		set sql [subst {
			select
				sf.status_flag_name,
				csf.set_flag_date,
				csf.set_flag_reason as reason
			from
				tCustStatusFlag csf,
				tStatusFlag sf,
				tCSFlagIdx idx
			where
				idx.cust_id = ?
			and
				idx.cust_flag_id = csf.cust_flag_id
			and
				csf.status_flag_tag = sf.status_flag_tag
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res_cust_flags [inf_exec_stmt $stmt $cust_id]

		inf_close_stmt $stmt

		set NumCustFlags [db_get_nrows $res_cust_flags]
		tpSetVar NumCustFlags $NumCustFlags

		tpBindTcl CSF_status_flag_name    sb_res_data $res_cust_flags cf_idx status_flag_name
		tpBindTcl CSF_reason              sb_res_data $res_cust_flags cf_idx reason
	}

	#
	# Customer message summary (just the first message of each type)

	if [info exists CMSG] {
		unset CMSG
	}

	set sql [subst {
		select
			m.cust_msg_id,
			m.message,
			m.sort,
			m.last_update,
			u.username
		from
			tCustomerMsg m,
			tAdminUser u
		where
			m.oper_id = u.user_id
		and m.cust_id = ?
		order by
			sort, last_update desc
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_msg [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set num_msgs     [db_get_nrows $res_msg]
	set curr_sort ""
	#We only want the first of each sort
	set num_disp_msgs 0
	for {set i 0} {$i < $num_msgs} {incr i} {

		set sort [db_get_col $res_msg $i sort]
		if {$curr_sort == $sort} continue
		set curr_sort $sort

		#Hide supervisor msgs where op has no permission
		if {$sort=="S" && ![op_allowed ManSupCustMsg]} continue

		set CMSG($num_disp_msgs,sort)        $sort
		set CMSG($num_disp_msgs,cust_msg_id) [db_get_col $res_msg $i cust_msg_id]
		set CMSG($num_disp_msgs,last_update) [db_get_col $res_msg $i last_update]
		set message                          [db_get_col $res_msg $i message]
		regsub -all "\r\n" $message "<BR>"   CMSG($num_disp_msgs,message_view)
		set CMSG($num_disp_msgs,username)    [db_get_col $res_msg $i username]
		incr num_disp_msgs
	}

	tpSetVar NumMsgs $num_disp_msgs
	tpBindVar CustMsgId     CMSG cust_msg_id  msg_idx
	tpBindVar CustMsgSort   CMSG sort         msg_idx
	tpBindVar CustMsgDate   CMSG last_update  msg_idx
	tpBindVar CustMsgView   CMSG message_view msg_idx
	tpBindVar CustMsgUname  CMSG username     msg_idx
	db_close $res_msg

	global CPM_CUST
	global PMT_SEARCH

	get_cust_pmt_mthds $cust_id

	tpBindString PaymentListTitle "Customer Payment Methods"

	# Bind payment methods
	ADMIN::PMT::bind_mthds


	# Customer PMB Exceptions and maximum number of payment methods to combine
	global CUST_PMB
	global CUST_MAX_COMBINE
	global CARD_SCHEMES

	set sql [subst {
		select
			max_pmt_mthds,
			max_pmb_period,
			max_cards
		from
			tCustMultiLimits
		where
			cust_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 0} {
		set cust_max_pmt_mthds  ""
		set cust_max_pmb_period ""
		set cust_max_cards      ""
	} else {
		set cust_max_pmt_mthds  [db_get_col $rs 0 max_pmt_mthds]
		set cust_max_pmb_period [db_get_col $rs 0 max_pmb_period]
		set cust_max_cards      [db_get_col $rs 0 max_cards]
	}

	db_close $rs

	set sql [subst {
		select
			c.pay_mthd,
			c.pmt_scheme,
			c.pmb_period,
			pm.desc
		from
			tCustPMBPeriod c,
			tPayMthd pm
		where
			c.cust_id = ? and
			c.pay_mthd = pm.pay_mthd
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set CUST_PMB($i,pay_mthd)      [db_get_col $rs $i pay_mthd]
		set CUST_PMB($i,pay_mthd_desc) [db_get_col $rs $i desc]
		set CUST_PMB($i,pmt_scheme)    [db_get_col $rs $i pmt_scheme]
		set CUST_PMB($i,pmb_period)    [db_get_col $rs $i pmb_period]
	}

	if {$cust_max_pmb_period != ""} {
		set CUST_PMB($i,pay_mthd)      "ALL"
		set CUST_PMB($i,pay_mthd_desc) "Default"
		set CUST_PMB($i,pmt_scheme)    "----"
		set CUST_PMB($i,pmb_period)    $cust_max_pmb_period
		set nrows [incr nrows]
	}

	db_close $rs

	tpSetVar NrPMBExceptions $nrows
	tpBindVar PayMthd     CUST_PMB pay_mthd      pmb_idx
	tpBindVar PayMthdDesc CUST_PMB pay_mthd_desc pmb_idx
	tpBindVar PmtScheme   CUST_PMB pmt_scheme    pmb_idx
	tpBindVar PMBPeriod   CUST_PMB pmb_period    pmb_idx

	if {$nrows > 0 || $cust_max_pmb_period != ""} {
		tpSetVar PMBExpAvailable 1
	}

	set sql [subst {
		select
			c.pay_mthd,
			c.pmt_scheme,
			c.max_combine,
			pm.desc
		from
			tCustMaxPmtMthd c,
			tPayMthd pm
		where
			c.cust_id = ? and
			c.pay_mthd = pm.pay_mthd
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set CUST_MAX_COMBINE($i,pay_mthd)      [db_get_col $rs $i pay_mthd]
		set CUST_MAX_COMBINE($i,pay_mthd_desc) [db_get_col $rs $i desc]
		set CUST_MAX_COMBINE($i,pmt_scheme)    [db_get_col $rs $i pmt_scheme]
		set CUST_MAX_COMBINE($i,max_combine)   [db_get_col $rs $i max_combine]
	}

	db_close $rs

	tpSetVar NrMaxCombine $nrows
	tpBindVar PayMthdMC     CUST_MAX_COMBINE pay_mthd      mc_idx
	tpBindVar PayMthdDescMC CUST_MAX_COMBINE pay_mthd_desc mc_idx
	tpBindVar PmtSchemeMC   CUST_MAX_COMBINE pmt_scheme    mc_idx
	tpBindVar MaxCombine    CUST_MAX_COMBINE max_combine   mc_idx

	tpBindString DefaultMaxCombine $cust_max_pmt_mthds
	tpBindString MaxCustCards      $cust_max_cards

	tpSetVar MaxCombineAvailable 1

	set sql [subst {
		select distinct
			scheme
		from
			tCardScheme
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set CARD_SCHEMES($i,scheme) [db_get_col $rs $i scheme]
	}

	db_close $rs

	tpSetVar NumPmtSchemes $nrows
	tpBindVar pmt_scheme CARD_SCHEMES scheme ps_idx

	if {[OT_CfgGet FUNC_CUST_STATEMENTS 1]} {

		set sql [subst {
			select
				status,
				dlv_method,
				brief,
				freq_amt,
				freq_unit,
				due_from,
				due_to
			from
				tAcctStmt
			where
				acct_id = ?
		}]
		set stmt      [inf_prep_sql $DB $sql]
		set res_stmt  [inf_exec_stmt $stmt $acct_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res_stmt] == 1} {

			tpSetVar StmtAvailable 1
			tpBindString STMT_status     [db_get_col $res_stmt 0 status]
			tpBindString STMT_dlv_method [db_get_col $res_stmt 0 dlv_method]
			tpBindString STMT_brief      [db_get_col $res_stmt 0 brief]
			tpBindString STMT_freq_amt   [db_get_col $res_stmt 0 freq_amt]
			tpBindString STMT_freq_unit  [db_get_col $res_stmt 0 freq_unit]
			tpBindString STMT_due_from   [db_get_col $res_stmt 0 due_from]
			tpBindString STMT_due_to     [db_get_col $res_stmt 0 due_to]

		} else {
			tpSetVar StmtAvailable 0
		}
	}

	#
	# Customer Promotions
	#
	if {[OT_CfgGetTrue FUNC_PROMOTIONS]} {

		set sql [subst {
			select
				name,
				promotion_id
			from
				tPromotion
		}]

		set stmt          [inf_prep_sql $DB $sql]
		set res_promo [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set promo_nrows [db_get_nrows $res_promo]
		tpSetVar NumPromotions $promo_nrows

		variable promo
		for {set i 0} {$i < $promo_nrows} {incr i} {
			set promo($i,name) [db_get_col $res_promo $i name]
			set promo($i,id) [db_get_col $res_promo $i promotion_id]
		}

		tpBindVar name ::ADMIN::CUST::promo name i
		tpBindVar id ::ADMIN::CUST::promo id i
	}

	#
	# Social Responsibility Settings
	#
	if {[OT_CfgGetTrue FUNC_CUST_DEP_LIMITS]} {
		srp_get_cust_dep_limit $cust_id $ccy
	}

	if {[OT_CfgGetTrue FUNC_CUST_SELF_EXCL]} {
		srp_get_cust_self_excl $cust_id
	}

	if {[OT_CfgGet FUNC_MCS_POKER 0]} {
		# Poker 'Social Responsibility' Settings
		# PENDING: should be made more generic.

		set sql [subst {
			select
				flag_value
			from
				tcustomerflag
			where
				cust_id = ?
				and flag_name = "poker_srp_lev"
		}]

		set stmt          [inf_prep_sql $DB $sql]
		set res_poker_srp [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res_poker_srp] == "1"} {
			set poker_level [db_get_col $res_poker_srp 0 flag_value]
		} else {
			set poker_level 1
		}

		tpBindString poker_level $poker_level

		set poker_max_wtd 0
		set poker_max_dep 0

		switch $poker_level {

			3 {
				set sql {
					select
						limit_value
					from
						tcustlimits
					where
						cust_id    =  ? and
						limit_type =  ? and
						to_date    >= CURRENT and
						from_date  <  CURRENT and
						tm_date    is null
					order by       1
				}

				set stmt          [inf_prep_sql $DB $sql]

				set res_poker_dep [inf_exec_stmt $stmt $cust_id poker_max_dep]
				set res_poker_wtd [inf_exec_stmt $stmt $cust_id poker_max_wtd]

				inf_close_stmt $stmt

				if {[db_get_nrows $res_poker_dep] == 1} {

					set poker_max_dep [db_get_col $res_poker_dep 0 limit_value]
				}

				if {[db_get_nrows $res_poker_wtd] == 1} {

					set poker_max_wtd [db_get_col $res_poker_wtd 0 limit_value]

				}

				db_close $res_poker_dep
				db_close $res_poker_wtd
			}

			2 -
			1 {
				set poker_max_wtd [convert_to_rounded_ccy\
						  [OT_CfgGet MCS_POKER_MAX_WTD_LEV_${poker_level}] $ccy]
				if {$ccy == "GBP" && $country_code == "UK"} {
					set poker_max_dep [convert_to_rounded_ccy\
						  [OT_CfgGet MCS_POKER_MAX_DEP_UK_LEV_${poker_level}\
						  [OT_CfgGet MCS_POKER_MAX_DEP_LEV_${poker_level}]] $ccy]
				} else {
					set poker_max_dep [convert_to_rounded_ccy\
						  [OT_CfgGet MCS_POKER_MAX_DEP_LEV_${poker_level}] $ccy]
				}
			}
		}

		tpBindString poker_max_dep $poker_max_dep
		tpBindString poker_max_wtd $poker_max_wtd

		db_close $res_poker_srp
	}

	# System Limit settings
	ADMIN::PMT_CONTROL::bind_cust_limits $acct_id


	## has the user played balls, casino, poker, rio bay casino or fog?

	if {[OT_CfgGet BALLS_CASINO_POKER_CHECK 0]} {
		tpSetVar BallsCasinoPokerCheck "Y"

		set sql {
			select
				a.acct_id
			from
				tacct a
			where
				a.cust_id = ?
				and exists (
					select
						jrnl_id
					from
						tjrnl j
					where
						j.j_op_type in ('LB--', 'NBST')
					and
						j.acct_id = a.acct_id
				)
		}

		set stmt          [inf_prep_sql $DB $sql]

		set res_played_balls [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		if {[db_get_nrows $res_played_balls] > 0} {
			tpBindString PlayedBalls "Y"
		} else {
			tpBindString PlayedBalls "N"
		}
		db_close $res_played_balls


		set sql {
			select
				first 1 *
			from
				tmanadj m,
				tacct a
			where
				m.acct_id = a.acct_id
			and
				a.cust_id = ?
			and
				m.type = ?
		}

		set stmt          [inf_prep_sql $DB $sql]

		set res_played_casino [inf_exec_stmt $stmt $cust_id "MCSC"]
		if {[db_get_nrows $res_played_casino] > 0} {
			tpBindString PlayedCasino "Y"
		} else {
			tpBindString PlayedCasino "N"
		}
		db_close $res_played_casino

		set res_played_poker [inf_exec_stmt $stmt $cust_id "MCSP"]
		if {[db_get_nrows $res_played_poker] > 0} {
			tpBindString PlayedPoker "Y"
		} else {
			tpBindString PlayedPoker "N"
		}
		db_close $res_played_poker

		set res_played_viper [inf_exec_stmt $stmt $cust_id "VIPC"]
		if {[db_get_nrows $res_played_viper] > 0} {
			tpBindString PlayedViperCasino "Y"
		} else {
			tpBindString PlayedViperCasino "N"
		}
		db_close $res_played_viper

		set res_played_riocasino [inf_exec_stmt $stmt $cust_id "RIOC"]
		if {[db_get_nrows $res_played_riocasino] > 0} {
			tpBindString PlayedRioCasino "Y"
		} else {
			tpBindString PlayedRioCasino "N"
		}
		db_close $res_played_riocasino

		set sql {
			select
				first 1 cg_game_id
			from
				tCGGameSummary g,
				tCGAcct a
			where
				a.cust_id = ?
			and
				a.cg_acct_id = g.cg_acct_id
		}

		set stmt [inf_prep_sql $DB $sql]

		set res_played_games [inf_exec_stmt $stmt $cust_id]
		if {[db_get_nrows $res_played_games] > 0} {
			tpBindString PlayedGames "Y"
		} else {
			tpBindString PlayedGames "N"
		}
		db_close $res_played_games
	}

	#Get the customers cleardown group
	set sql {
		select
			g.cd_grp_name,
			g.cd_days,
			g.status
		from
			tacct a,
			tgrpcleardown g
		where
			a.cust_id = ? and
			a.cd_grp_id = g.cd_grp_id
		}

	set stmt [inf_prep_sql $DB $sql]

	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {
		set cd_grp_name [db_get_col $res 0 cd_grp_name]
		set cd_days [db_get_col $res 0 cd_days]
		set cd_status [db_get_col $res 0 status]
	} else {
		set cd_grp_name "None"
		set cd_days ""
		set cd_status ""
	}

	db_close $res
	tpBindString CDGroupName $cd_grp_name
	tpBindString CDDays $cd_days
	tpBindString CDGroupStatus $cd_status

	global EXT_CUST_DETAILS

	set sql {
		select
			a.code,
			b.display,
			a.master,
			a.ext_cust_id,
			a.version
		from
			tExtCust a,
			tExtCustIdent b
		where
			a.code = b.code
		and
			a.cust_id = ? and
			a.ext_cust_id != ''
	}

	set sql_internal {
		select
			count(*) as count
		from
			tExtCust
		where
			code = ?
		and
			ext_cust_id = ?
	}

	set stmt	[inf_prep_sql $DB $sql]
	set stmt_2	[inf_prep_sql $DB $sql_internal]

	set res_external_groups [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set external_groups_count [db_get_nrows $res_external_groups]

	# when removing a customer from a group (ext_cust_id) we need to look at the code
	# so we know the exact group from which they need to be removed from.
	# currently only one code is used at a time so get that from the config
	# file. 1 being the default value for the code.
	set ident_code [OT_CfgGet INTERNAL_EXT_CUST_IDENT_CODE 1]
	set ExtCustGroup ""
	set ExtCustGroupVersion 1
	set ExtCustGroupCount 0

	for {set r 0} {$r < $external_groups_count} {incr r} {
		set code         [db_get_col $res_external_groups $r code]
		set display      [db_get_col $res_external_groups $r display]
		set ext_cust_id  [db_get_col $res_external_groups $r ext_cust_id]
		set master       [db_get_col $res_external_groups $r master]
		set version      [db_get_col $res_external_groups $r version]

		set res_external_groups_2 [inf_exec_stmt $stmt_2 $code $ext_cust_id]

		set count [db_get_col $res_external_groups_2 0 count]

		db_close $res_external_groups_2

		set EXT_CUST_DETAILS($r,code)         $code
		set EXT_CUST_DETAILS($r,display)      $display
		set EXT_CUST_DETAILS($r,ext_cust_id)  $ext_cust_id
		set EXT_CUST_DETAILS($r,count)        $count
		set EXT_CUST_DETAILS($r,master)       $master

		if {$code == $ident_code} {
			set ExtCustGroup $ext_cust_id
			set ExtCustGroupVersion $version
			set ExtCustGroupCount $count
		}
	}
	inf_close_stmt $stmt_2
	db_close $res_external_groups

	tpBindString ExtCustGroup        $ExtCustGroup
	tpBindString ExtCustGroupVersion $ExtCustGroupVersion
	tpBindString ExtCustGroupCount   $ExtCustGroupCount
	tpBindString IdentCode           $ident_code

	tpSetVar ExtGroupsCount $external_groups_count
	tpBindVar ExtCustCode    EXT_CUST_DETAILS code         ext_cust_idx
	tpBindVar ExtCustDisplay EXT_CUST_DETAILS display      ext_cust_idx
	tpBindVar ExtCustId      EXT_CUST_DETAILS ext_cust_id  ext_cust_idx
	tpBindVar ExtCustCount   EXT_CUST_DETAILS count        ext_cust_idx
	tpBindVar ExtCustMaster  EXT_CUST_DETAILS master       ext_cust_idx

	if {[OT_CfgGet FUNC_AUTO_LETTERS 0]} {
		ADMIN::AUTO_LETTERS::get_cust_letters		$cust_id
		ADMIN::AUTO_LETTERS::get_cust_avail_letters	$cust_id
	}

	if [OT_CfgGet FUNC_CUST_CATEGORIES 0] {
		ADMIN::OBJ_CATEGORY::bind_categories C $cust_id CUST_CAT
	}

	## bind liab groups

	global LIAB_GROUPS

	set sql_liab {
		select
			liab_group_id,
			liab_desc,
			disp_order
		from
			tLiabGroup
		order by disp_order
	}

	set stmt [inf_prep_sql $DB $sql_liab]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set liab_groups_count [db_get_nrows $res]

	for {set r 0} {$r < $liab_groups_count} {incr r} {
		set liab_group_id  [db_get_col $res $r liab_group_id]
		set liab_desc      [db_get_col $res $r liab_desc]

		set LIAB_GROUPS($r,liab_group_id)  $liab_group_id
		set LIAB_GROUPS($r,liab_desc)      $liab_desc
	}

	tpSetVar  LiabGroupsCount $liab_groups_count
	tpBindVar LiabGroupId     LIAB_GROUPS liab_group_id  liab_groups_idx
	tpBindVar LiabDesc        LIAB_GROUPS liab_desc      liab_groups_idx


	# Customer Terms and Conditions
	if {[OT_CfgGet CUST_TNC 0]} {

		# We want to find a list of t&c that the customer has accepted
		global CUST_TNC
		set sql_tnc {
			select
				t.tnc_name,
				c.date_accepted,
				c.version_accepted
			from
				ttnc t,
				tcusttnc c
			where
				t.tnc_id = c.tnc_id and
				c.cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql_tnc]
		set rs [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt
		set col_names [db_get_colnames $rs]

		set n_rows [db_get_nrows $rs]

		for {set t 0} {$t < $n_rows} {incr t} {
			foreach n $col_names {
				set CUST_TNC($t,$n) [db_get_col $rs $t $n]
			}
		}

		db_close $rs

		tpSetVar tnc_nrows $n_rows

		foreach n $col_names {
			tpBindVar $n CUST_TNC $n c_idx
		}
	}

	#this is for operator specific - non openbet admin functions
	#this has been put in to avoid cluttering the admin screens
	# with non openbet code
	if {[OT_CfgGet FUNC_EXT_CUST 0]} {
		ADMIN::EXT::go_ext_cust $cust_id
	}

	# show alerts
	if {[OT_CfgGet FUNC_ALERTS 0] && [op_allowed ManageAlerts]} {
		ADMIN::ALERTS::bind_alert_accts $cust_id
		ADMIN::ALERTS::bind_alerts $cust_id
	}

	if {[OT_CfgGet FUNC_CUST_IDENT 0]} {
		_bind_cust_ident $cust_id
	}

	if {[OT_CfgGet FUNC_KYC 0]} {
		ADMIN::KYC::bind_cust $cust_id
	}

	if {[OT_CfgGet FUNC_AGE_VRF_REASON 0]} {
		ADMIN::VERIFICATION::bind_cust $cust_id
	}

	go_cust_groups $cust_id

 	# Playtech
 	if {[OT_CfgGet FUNC_PLAYTECH 0]} {

		global PT_SYS

		# get the systems
		set playtech_systems [playtech::get_cfg systems]

		tpSetVar PlaytechSysNum [llength $playtech_systems]

		set i 0

		foreach system $playtech_systems {

			set PT_SYS($i,system)    $system
			set PT_SYS($i,disp_name) [playtech::get_cfg $system,disp_name]

			tpBindVar system    PT_SYS system    pt_idx
			tpBindVar disp_name PT_SYS disp_name pt_idx

			if {![OT_CfgGet PLAYTECH_AJAX_BALANCES 1]} {

				playtech::configure_request -channel "P" -is_critical_request "N"
 				playtech::get_playerinfo $username $password $system

 				if {[playtech::status] == "OK"} {
 					set playtech_balance [playtech::response balance]
					if {$playtech_balance != ""} {
						set playtech_balance [format %0.2f $playtech_balance]
					}
					set playtech_bonus [playtech::response bonusbalance]
					if {$playtech_bonus != ""} {
						set playtech_bonus [format %0.2f $playtech_bonus]
					}
					set playtech_frozen [playtech::response frozen]
					set nickname        [playtech::response pokernickname]
				} else {
					set playtech_balance [playtech::code]
					set playtech_bonus   [playtech::code]
					set playtech_frozen  [playtech::code]
					set nickname         [playtech::code]
				}

				set PT_SYS($i,balance)  $playtech_balance
				set PT_SYS($i,bonus)    $playtech_bonus
				set PT_SYS($i,frozen)   $playtech_frozen
				set PT_SYS($i,nickname) $playtech_nickname

				tpBindVar balance     PT_SYS   balance     pt_idx
				tpBindVar bonus       PT_SYS   bonus       pt_idx
				tpBindVar frozen      PT_SYS   frozen      pt_idx
				tpBindVar nickname    PT_SYS   nickname    pt_idx

			}

			incr i
		}
 	}

 	# Stralfors
 	if {[OT_CfgGet ENABLE_STRALFORS 0]} {
		set stralfor_flag [OT_CfgGet STRALFORS_FLAG_NAME]

		set flag_sql {
			select
				f.flag_value
			from
				tCustomerFlag f
			where
				f.flag_name = ?
				and f.cust_id = ?
		}

		set stmt [inf_prep_sql $DB $flag_sql]
		set res  [inf_exec_stmt $stmt $stralfor_flag $cust_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			set stral_flag [db_get_col $res 0 flag_value]
			tpBindString Stral_Flag_Value $stral_flag
			if {[string match $stral_flag Y]} {
				tpSetVar stral_flagged 1
			} else {
				tpSetVar stral_unflagged 1
			}
		} else {
			tpBindString Stral_Flag_Value U
			tpSetVar stral_flagged 0
		}

		db_close $res

		set stral_sql {
			select first 1
				s.stralfor_id,
				s.print_code,
				s.account_type,
				s.letter,
				s.tel_no,
				s.bus_cond,
				s.export_date,
				s.exported
			from
				tCustStralfor s
			where
				s.cust_id = ?
			order by
				s.cr_date DESC
		}

		set stmt [inf_prep_sql $DB $stral_sql]
		set res  [inf_exec_stmt $stmt $cust_id]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $res]

		if {$nrows == 1} {
			tpBindString Stral_print_code     [db_get_col $res 0 print_code]
			tpBindString Stral_account_type   [db_get_col $res 0 account_type]
			tpBindString Stral_letter         [db_get_col $res 0 letter]
			tpBindString Stral_tel_no         [db_get_col $res 0 tel_no]
			tpBindString Stral_bus_cond       [db_get_col $res 0 bus_cond]
			tpBindString Stral_export_date    [db_get_col $res 0 export_date]
			tpBindString Stralfor_Id          [db_get_col $res 0 stralfor_id]
			if {[string match [db_get_col $res 0 exported] Y]} {
				tpSetVar stral_exported 1
			} else {
				tpSetVar stral_exported 0
			}
		} else {
			tpSetVar stral_exported 0
		}
 	}

	# Bind large return limits
	bind_cust_return_lmts $acct_id

	# Bind adhoc token redemption values
	if {[op_allowed AdHocTokenReward]} {
		global RVALS

		set sql {
			select
				redemption_id rval_id,
				bet_level,
				bet_type,
				bet_id,
				name
			from
				tRedemptionVal
			order by
				bet_level, bet_type, bet_id
		}

		if {[catch {
			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt]
			inf_close_stmt $stmt
		} msg]} {
			ob_log::write ERROR "go_cust cust_id $cust_id $msg"
			err_bind $msg
			go_cust
			return
		}

		set nrows [db_get_nrows $res]

		tpSetVar NumRVals $nrows

		for {set i 0} {$i < $nrows} {incr i} {
			set RVALS($i,rval_id)     [db_get_col $res $i rval_id]
			set RVALS($i,bet_level)   [db_get_col $res $i bet_level]
			set RVALS($i,bet_type)    [db_get_col $res $i bet_type]
			set RVALS($i,bet_id)      [db_get_col $res $i bet_id]
			set RVALS($i,name)        [db_get_col $res $i name]
		}

		db_close $res

		tpBindVar RValID       RVALS rval_id   rval_idx
		tpBindVar RValBetLevel RVALS bet_level rval_idx
		tpBindVar RValBetType  RVALS bet_type  rval_idx
		tpBindVar RValBetID    RVALS bet_id    rval_idx
		tpBindVar RValName     RVALS name      rval_idx
	}

	tpSetVar NumElite $num_elite

	# Iovation Fraud Check
	#
	if {[OT_CfgGet FUNC_IOVATION_SNARE 0]} {

		global IOVACNT
		global IOVACTRL

		# Get the count number of Iovation Trigger actions for customer.

		set iova_cnt_sql {
			select
				itc.desc,
				nvl(cs.count, 0) count
			from
				tIovTrigCtrl itc,
				outer (
					tAcct            a,
					tCustStats       cs,
					tCustStatsAction csa
				)
			where
				a.cust_id         = ?                          and
				cs.acct_id        = a.acct_id                  and
				csa.action_id     = cs.action_id               and
				csa.action_name   = 'IOV_' || itc.trigger_type
		}

		set stmt_iova_cnt [inf_prep_sql $DB $iova_cnt_sql]
		set res_iova_cnt  [inf_exec_stmt $stmt_iova_cnt $cust_id]
		inf_close_stmt $stmt_iova_cnt

		catch {array unset IOVACNT}

		set IOVACNT(num) [db_get_nrows $res_iova_cnt]

		for {set i 0} {$i < $IOVACNT(num)} {incr i} {
			set IOVACNT($i,desc)  [db_get_col $res_iova_cnt $i desc]
			set IOVACNT($i,count) [db_get_col $res_iova_cnt $i count]
		}

		db_close $res_iova_cnt

		tpSetVar num_iova_cnt $IOVACNT(num)

		tpBindVar iova_cnt_trig_desc  IOVACNT desc  iova_cnt_idx
		tpBindVar iova_cnt_trig_count IOVACNT count iova_cnt_idx

		# Bind the Iovation Trigger Account Level settings.

		set iova_ctrl_sql {
			select
				itc.desc,
				itc.trigger_type,
				citc.enabled,
				citc.freq_str,
				citc.max_count
			from
				tIovTrigCtrl itc,
				outer (
					tCustIovTrigCtrl citc
				)
			where
				citc.cust_id     = ?                 and
				itc.trigger_type = citc.trigger_type
		}

		set stmt_iova_ctrl [inf_prep_sql $DB $iova_ctrl_sql]
		set res_iova_ctrl  [inf_exec_stmt $stmt_iova_ctrl $cust_id]
		inf_close_stmt $stmt_iova_ctrl

		catch {array unset IOVACTRL}

		set IOVACTRL(num) [db_get_nrows $res_iova_ctrl]

		for {set i 0} {$i < $IOVACTRL(num)} {incr i} {
			set IOVACTRL($i,desc)      [db_get_col $res_iova_ctrl $i desc]
			set IOVACTRL($i,type)      [db_get_col $res_iova_ctrl $i trigger_type]
			set IOVACTRL($i,enabled)   [db_get_col $res_iova_ctrl $i enabled]
			set IOVACTRL($i,freq_str)  [db_get_col $res_iova_ctrl $i freq_str]
			set IOVACTRL($i,max_count) [db_get_col $res_iova_ctrl $i max_count]
		}

		db_close $res_iova_ctrl

		tpSetVar num_iova_ctrl $IOVACTRL(num)

		tpBindVar iova_ctrl_trig_desc      IOVACTRL desc      iova_ctrl_idx
		tpBindVar iova_ctrl_trig_type      IOVACTRL type      iova_ctrl_idx
		tpBindVar iova_ctrl_trig_enabled   IOVACTRL enabled   iova_ctrl_idx
		tpBindVar iova_ctrl_trig_freq_str  IOVACTRL freq_str  iova_ctrl_idx
		tpBindVar iova_ctrl_trig_max_count IOVACTRL max_count iova_ctrl_idx
	}


	# Bind up optional systems
	if {[OT_CfgGetTrue FUNC_OPT_EXTSYS_SYNC]} {
		# Bind Customer Optional System
		ADMIN::XSYS_MGMT::bind_optional_sys_sync $cust_id
	}


	asPlayFile -nocache cust.html


	if {[OT_CfgGet FUNC_CUST_STOP_CODES 0]} {
		db_close $res_code
	}

	if {[OT_CfgGet FUNC_CUST_STATUS_FLAGS 0] && [op_allowed ViewCustStatusFlags]} {
		db_close $res_cust_flags
	}

	# unset any discarded globals
	foreach discarded {
		SRP_DEP_LIMITS
		SRP_EXCL_PERIODS
		WTD_LMT
		PAY_MTHDS
		CARD_SCHEME
		IOVACNT
		IOVACTRL
	} {
		global $discarded
		catch {unset $discarded}
	}

}



# ---------------------------------------------------------------------------
# Go to the add customer screen
# ---------------------------------------------------------------------------
proc go_add_cust_msg {} {

	#Pass on the cust id
	tpBindString CustId [reqGetArg CustId]

	#play the new message template
	asPlayFile -nocache add_cust_msg.html

}


# ---------------------------------------------------------------------------
# Go to the add filter
# ---------------------------------------------------------------------------
proc go_filter_cust_msg {} {

	global DB OPERATORS
	catch {unset ADMIN_USERS}

	# Pass on the cust id
	tpBindString CustId [reqGetArg CustId]

	#
	# Retrieve the operator usernames for filter screen
	#
	set op_sql {
			select
					username,
					status
			from
					tAdminUser
			order by
					username,
					status
	}

	set op_stmt [inf_prep_sql $DB $op_sql]
	set op_res  [inf_exec_stmt $op_stmt]
	inf_close_stmt $op_stmt

	# Store the operator info
	for {set i 0} {$i < [db_get_nrows $op_res]} {incr i} {
		regsub -all "'" [db_get_col $op_res $i username] "\\'" OPERATORS($i,operator)
		set OPERATORS($i,status)   [db_get_col $op_res $i status]
	}
	tpSetVar  NumOperators [db_get_nrows $op_res]
	tpBindVar operator  OPERATORS operator op_idx
	tpBindVar op_status OPERATORS status   op_idx

	# Store the filter defaults
	tpBindString userFilter      [reqGetArg userFilter]
	tpBindString sortFilter      [reqGetArg sortFilter]
	tpBindString startDateFilter [reqGetArg startDateFilter]
	tpBindString endDateFilter   [reqGetArg endDateFilter]
	tpBindString keysFilter      [reqGetArg keysFilter]

	# play the new message template
	asPlayFile -nocache filter_cust_msg.html

	db_close $op_res
}



# ---------------------------------------------------------------------------
# Retrieves the customer messages - filtering them where a filter has been
# supplied
# ---------------------------------------------------------------------------
proc go_cust_msgs {} {

	global DB CSORT CMSG

	# Length of message to show in summary
	set summary_length 60

	#
	# Customer messages
	#
	set cust_id [reqGetArg CustId]
	tpBindString CustId $cust_id

	if [info exists CMSG] {
			unset CMSG
	}

	# Generic select section
	set sql [subst {
			select
					m.cust_msg_id,
					m.message,
					m.sort,
					m.last_update,
					u.username
			from
					tCustomerMsg m,
					tAdminUser u
			where
					m.oper_id = u.user_id
			and m.cust_id = ?
	}]

	# Add any filters
	if {[reqGetArg SubmitName] == "FilterMsgs"} {

		set sortFilter       [string trim [reqGetArg CustMsgSort]]
		set startDateFilter  [string trim [reqGetArg CustMsgStartDate]]
		set endDateFilter    [string trim [reqGetArg CustMsgEndDate]]
		set userFilter       [string trim [reqGetArg CustMsgUser]]
		set keysFilter       [string trim [reqGetArg CustMsgKeys]]

		# Store the filters for defaults
		tpBindString sortFilter $sortFilter
		tpBindString startDateFilter $startDateFilter
		tpBindString endDateFilter $endDateFilter
		tpBindString userFilter $userFilter
		tpBindString keysFilter $keysFilter

		# sort filter
		if {$sortFilter != "A"} {
			set sql $sql[subst {
				and m.sort = '$sortFilter'
			}]
		}

		# user filter
		if {$userFilter != "Any"} {
			regsub -all "'" $userFilter "''" userFilter
			set sql $sql[subst {
				and u.username = '$userFilter'
			}]
		}

		# date filter (allow for  2 time and date formats)
		if {[string length $startDateFilter] == 10} {set startDateFilter "$startDateFilter 00:00:00"}
		if {[string length $endDateFilter] == 10} {
			set endDateFilter "extend('$endDateFilter 00:00:00',year to second) + (interval(1) day to day)"
		} elseif {[string length $endDateFilter] > 0} {
				set endDateFilter "'$endDateFilter'"
		}

		if {$startDateFilter != "" && $endDateFilter != ""} {

			set sql $sql[subst {
				and m.last_update between '$startDateFilter' and $endDateFilter
			}]

		} elseif {$startDateFilter != ""} {

			set sql $sql[subst {
				and m.last_update >= '$startDateFilter'
			}]

		} elseif {$endDateFilter != ""} {

			set sql $sql[subst {
				and m.last_update <= $endDateFilter
			}]
		}

		# keys filter
		if {$keysFilter != ""} {
			regsub -all "'" $keysFilter "''" keysFilter
			foreach key $keysFilter {
				set sql $sql[subst {
					and upper(m.message) like '%[string toupper $key]%'
				}]
			}
		}

		set filtered 1

	} else {

		set filtered 0
	}

	# Generic order-by section
	set sql $sql[subst {
		order by
			sort, last_update desc, cust_msg_id desc
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set res_msg [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set num_msgs     [db_get_nrows $res_msg]

	set j 0
	for {set i 0} {$i < $num_msgs} {incr i} {

		set sort [db_get_col $res_msg $i sort]

		if {$sort=="S" && ![op_allowed ManSupCustMsg]} {continue}

		set CMSG($j,sort)        $sort
		set CMSG($j,cust_msg_id) [db_get_col $res_msg $i cust_msg_id]
		set CMSG($j,last_update)     [db_get_col $res_msg $i last_update]
		regsub -all {\\} [db_get_col $res_msg $i message] {\\\\} message
		regsub -all "\"" $message "\\\"" message
		regsub -all "\r\n" $message "\\r\\n" CMSG($j,message_edit)

		if {([string length $CMSG($j,message_edit)] > $summary_length)} {

			set temp [string range $CMSG($j,message_edit) 0 $summary_length]
			set index [string last " " $temp]
			set CMSG($j,message_edit) "[string range $temp 0 [expr $index - 1]]..."
		}
		regsub -all "\r\n" $message "\\r\\n" CMSG($j,message_view)
		set CMSG($j,username)    [db_get_col $res_msg $i username]
		incr j
	}

	tpSetVar  NumMsgs       $j
	tpSetVar  Filtered      $filtered
	tpBindVar CustMsgId     CMSG cust_msg_id  msg_idx
	tpBindVar CustMsgSort   CMSG sort         msg_idx
	tpBindVar CustMsgDate   CMSG last_update  msg_idx
	tpBindVar CustMsgView   CMSG message_view msg_idx
	tpBindVar CustMsgEdit   CMSG message_edit msg_idx
	tpBindVar CustMsgUname  CMSG username     msg_idx

	asPlayFile -nocache cust_msg.html

	db_close $res_msg
}

#
# ----------------------------------------------------------------------------
# show details of the last manual funds transfer dep(I) wtd (O)
# ----------------------------------------------------------------------------
#
proc show_last_fund_xfer {in_out acct_id} {

	global DB

	switch  -- $in_out {
		"I" {set tab tManDepRqst}
		"O" {set tab tManWtdRqst}
		default {return}
	}

	set qry [subst {
		select first 1
			r.cr_date,
			r.amount,
			r.method,
			r.code,
			u.username
		from
			$tab r,
			tAdminUser  u
		where
			r.acct_id = $acct_id and
			r.user_id = u.user_id
		order by
			r.cr_date desc
	}]

	set stmt [inf_prep_sql $DB $qry]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] == 1} {

		set date   [db_get_col $rs cr_date]
		set amount [db_get_col $rs amount]
		set method [db_get_col $rs method]
		set code   [db_get_col $rs code]
		set user   [db_get_col $rs username]

		if {$amount < 0} {
			set amount [expr {0-$amount}]
		}

		tpBindString F${in_out}Date   [html_date $date shrttime]
		tpBindString F${in_out}Amount "($method) $amount"
		tpBindString F${in_out}Code   $code
		tpBindString F${in_out}User   $user

	} else {

		tpBindString F${in_out}Date    none

	}

	db_close $rs
}


#
# ----------------------------------------------------------------------------
# show the total of all deposits for this customer today
# ----------------------------------------------------------------------------
#
proc show_todays_fund_xfer {in_out acct_id} {

	global DB

	switch  -- $in_out {
		I {
			set sign ">"
		}
		O {
			set sign "<"
		}
		default {
			return
		}
	}

	#
	# all transfers except bet stake/refund/winnings
	#
	set qry [subst {
		select
			nvl(sum(amount), 0) amount
		from
			tjrnl
		where
			acct_id = $acct_id and
			cr_date >= today and
			amount $sign 0 and
			j_op_type not in ('BSTK','BSTL','BWIN','BRFD')
	}]

	set stmt [inf_prep_sql $DB $qry]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set amount [db_get_col $rs amount]

	if {$amount < 0} {
		set amount [expr {0-$amount}]
	}

	tpBindString TodaysF${in_out}  $amount

	db_close $rs

	switch  -- $in_out {
		"I" {set op_type DEP}
		"O" {set op_type WTD}
		default {return}
	}

	#
	# credit card transfers
	#
	set qry [subst {
		select
			nvl(sum(amount),0) amount
		from
			tjrnl
		where
			acct_id = $acct_id and
			cr_date >= today and
			j_op_type = '$op_type' and
			j_op_ref_key = 'PMT'
	}]

	set stmt [inf_prep_sql $DB $qry]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set amount [db_get_col $rs amount]

	if {$amount < 0} {
		set amount [expr {0-$amount}]
	}

	tpBindString TodaysCCF${in_out}  $amount

	db_close $rs
}


#
# ----------------------------------------------------------------------------
# Goto page of event level customer limits (liab group and max stake factor)
# ----------------------------------------------------------------------------
#
proc go_cust_lvl_limit args {

	global DB CUST_LIMIT

	if {[reqGetArg SubmitName] == "Back"} {
		go_cust
		return
	}

	set cust_id [reqGetArg CustId]

	tpBindString CustId $cust_id

	set sql [subst {
		select
			level,
			id,
			c.name as class_name,
			"" as type_name,
			"" as evocgrp_name,
			l.max_stake_scale,
			l.liab_group_id
		from
			tEvClass c,
			tCustLimit l
		where
			l.cust_id = $cust_id and
			l.level = 'CLASS' and
			l.id = c.ev_class_id and
			c.status = 'A'
		union
		select
			level,
			id,
			c.name as class_name,
			t.name as type_name,
			"" as evocgrp_name,
			l.max_stake_scale,
			l.liab_group_id
		from
			tEvClass c,
			tEvType t,
			tCustLimit l
		where
			l.cust_id = $cust_id and
			l.level = 'TYPE' and
			l.id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			c.status = 'A' and
			t.status = 'A'
		union
		select
			level,
			id,
			c.name as class_name,
			t.name as type_name,
			g.name as evocgrp_name,
			l.max_stake_scale,
			l.liab_group_id
		from
			tEvClass c,
			tEvType t,
			tEvOcGrp g,
			tCustLimit l
		where
			l.cust_id = $cust_id and
			l.level = 'EVOCGRP' and
			l.id = g.ev_oc_grp_id and
			g.ev_type_id = t.ev_type_id and
			t.ev_class_id = c.ev_class_id and
			c.status = 'A' and
			t.status = 'A'

	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCustLimit [set n_rows [db_get_nrows $rs]]

	array set CUST_LIMIT [list]

	for {set r 0} {$r < $n_rows} {incr r} {
		set CUST_LIMIT($r,level)           [db_get_col $rs $r level]
		set CUST_LIMIT($r,id)              [db_get_col $rs $r id]
		set CUST_LIMIT($r,class_name)      [db_get_col $rs $r class_name]
		set CUST_LIMIT($r,type_name)       [db_get_col $rs $r type_name]
		set CUST_LIMIT($r,evocgrp_name)    [db_get_col $rs $r evocgrp_name]
		set CUST_LIMIT($r,max_stake_scale) [db_get_col $rs $r max_stake_scale]
		set CUST_LIMIT($r,liab_group_id)   [db_get_col $rs $r liab_group_id]

		# Construct max stake factor descritpion
		set desc [list]
		foreach elem {class_name type_name evocgrp_name} {
			if {![string equal $CUST_LIMIT($r,$elem) ""]} {
				lappend desc $CUST_LIMIT($r,$elem)
			}
		}
		set CUST_LIMIT($r,name) [join $desc " -> "]
	}

	db_close $rs

	tpBindVar Level    CUST_LIMIT level           limit_idx
	tpBindVar Id       CUST_LIMIT id              limit_idx
	tpBindVar Name     CUST_LIMIT name            limit_idx
	tpBindVar MSF      CUST_LIMIT max_stake_scale limit_idx
	tpBindVar LiabGrp  CUST_LIMIT liab_group_id   limit_idx

	## bind liab groups

	global LIAB_GROUPS

	set sql_liab {
		select
			liab_group_id,
			liab_desc,
			disp_order
		from
			tLiabGroup
		order by disp_order
	}

	set stmt [inf_prep_sql $DB $sql_liab]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set liab_groups_count [db_get_nrows $res]

	for {set r 0} {$r < $liab_groups_count} {incr r} {
		set liab_group_id  [db_get_col $res $r liab_group_id]
		set liab_desc      [db_get_col $res $r liab_desc]

		set LIAB_GROUPS($r,liab_group_id)  $liab_group_id
		set LIAB_GROUPS($r,liab_desc)      $liab_desc
	}

	db_close $res

	tpSetVar  LiabGroupsCount $liab_groups_count
	tpBindVar LiabGroupId     LIAB_GROUPS liab_group_id  liab_groups_idx
	tpBindVar LiabDesc        LIAB_GROUPS liab_desc      liab_groups_idx

	asPlayFile -nocache cust_lvl_limit.html

	unset CUST_LIMIT
}


#
# Performs insert/update/deletion of customer event-level limits
#
proc do_cust_lvl_limit args {

	global DB

	set fn {ADMIN::CUST::do_cust_lvl_limit}

	if {![op_allowed UpdCustStatus]} {
		err_bind "You don't have permission to update customer information"
		go_cust
	}

	# If monitor is set, grab common user data to be used later
	# We do it once here for performance. Data will be put in
	# CUST_STK variable
	if {[OT_CfgGet MONITOR 0]} {
		_populate_max_stk_var [reqGetArg CustId]
	}

	set submit_name [reqGetArg SubmitName]

	switch -exact -- $submit_name {
		UpdLimit {
			do_cust_lvl_limit_upd
		}
		InsLimit {
			do_cust_lvl_limit_ins
		}
		DelLimit {
			do_cust_lvl_limit_del
		}
		default {
			go_cust
		}
	}
}



#
# Updates the event level limits associated with a
# customer
#
proc do_cust_lvl_limit_upd args {

	global DB

	set cust_id  [reqGetArg CustId]
	set num_rows [reqGetArg NumCustLimit]

	set sql_upd {
		update
			tCustLimit
		 set
			max_stake_scale = ?,
			liab_group_id = ?
		where
			cust_id = ? and
			level = ? and
			id = ?
	}
	set stmt_upd [inf_prep_sql $DB $sql_upd]

	set bad 0

	inf_begin_tran $DB

	if {[OT_CfgGet MONITOR 0]} {
		# a list of updated fields
		set updated_fields [list]
	}

	#
	# Do update
	#
	if {[catch {
		for {set r 0} {$r < $num_rows} {incr r} {
			set level         [reqGetArg level_$r]
			set id            [reqGetArg id_$r]
			set old_msf       [string trim [reqGetArg old_msf_$r]]
			set new_msf       [string trim [reqGetArg msf_$r]]
			set old_liabgrp   [string trim [reqGetArg old_liab_grp_$r]]
			set new_liabgrp   [string trim [reqGetArg liab_grp_$r]]

			if {![string equal $new_msf $old_msf] ||
			    ![string equal $new_liabgrp $old_liabgrp]} {
				inf_exec_stmt $stmt_upd \
				                      $new_msf\
				                      $new_liabgrp\
				                      $cust_id\
				                      $level\
				                      $id
				# if monitor is set, we build the updated list
				if {[OT_CfgGet MONITOR 0]} {
					set current_field [list]
					lappend current_field $level
					lappend current_field $id
					lappend current_field $new_msf
					lappend current_field $old_msf
					# appending the item to the list
					lappend updated_fields $current_field
				}
			}
		}
	} msg]} {
		ob::log::write INFO {BAD: $msg}
		err_bind $msg
		set bad 1
	}

	catch {inf_close_stmt $stmt_upd}

	if {$bad} {
		inf_rollback_tran $DB
		go_cust_lvl_limit
	} else {
		inf_commit_tran $DB
		 #if monitor is on, we send a message
		if {[OT_CfgGet MONITOR 0]} {

			# ... looping on all fields being updated
			foreach {field} $updated_fields {
				_send_monitor_stkfac_msg      $cust_id \
					                          [lindex $field 0] \
					                          [lindex $field 1] \
					                          [lindex $field 2] \
					                          [lindex $field 3] \
					                          "UPDATED"
			}
		}

		msg_bind "Update Successful"
		go_cust_lvl_limit
	}
}



#
# Inserts an event level limit such as liability group
# or max stake factor for a customer The limit can be
# now be defined at multiple levels for a customer:
# CLASS, TYPE and EVOCGRP
#
proc do_cust_lvl_limit_ins args {

	global DB

	set cust_id          [reqGetArg CustId]
	set bet_level        [reqGetArg BetLevel]
	set bet_id           [reqGetArg BetId]
	set max_stake_factor [reqGetArg max_stake_factor]
	set liab_group_id    [reqGetArg liab_group_id]

	ob::log::write DEV {=> do_cust_lvl_limit_ins: (cust_id:$cust_id)
        (bet_level:$bet_level) (bet_id:$bet_id)
        (max_stake_factor:$max_stake_factor) (liab_group_id:$liab_group_id)}

	# Do some error checking
	if {[string equal [string first $bet_level "CLASS/TYPE/EVOCGRP"] -1]} {
		err_bind "Bet Level must be either CLASS, TYPE or EVOCGRP"
		go_cust_lvl_limit
		return
	}
	if {$liab_group_id == "" && $max_stake_factor == ""} {
		err_bind "Liability group and/or stake factor must be specified"
		go_cust_lvl_limit
		return
	}

	set sql_ins {
		insert into tCustLimit(cust_id, level, id, max_stake_scale, liab_group_id)
		values (?,?,?,?,?)
	}
	set stmt_ins [inf_prep_sql $DB $sql_ins]

	set bad 0

	inf_begin_tran $DB

	#
	# Do update, depending on new value vs old
	#
	if {[catch {inf_exec_stmt $stmt_ins\
	                                   $cust_id\
	                                   $bet_level\
	                                   $bet_id\
	                                   $max_stake_factor\
                                           $liab_group_id} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {inf_close_stmt $stmt_ins}

	if {$bad} {
		inf_rollback_tran $DB
		go_cust_lvl_limit
	} else {
		inf_commit_tran $DB
		# if monitor is on, we send a message
		if {[OT_CfgGet MONITOR 0]} {
			_send_monitor_stkfac_msg  $cust_id \
			                          $bet_level \
			                          $bet_id \
			                          $max_stake_factor \
			                          "--" \
			                          "INSERTED"
		}

		msg_bind "Insertion Successful"
		go_cust_lvl_limit
	}
}



#
# Deletes an event level limit associated with a
# customer
#
proc do_cust_lvl_limit_del args {

	global DB

	set cust_id  [reqGetArg CustId]
	set id       [reqGetArg Id]
	set level    [reqGetArg Level]

	set sql_del {
		delete from
			tCustLimit
		where
			cust_id = ? and
			level = ? and
			id = ?
	}
	set stmt_del [inf_prep_sql $DB $sql_del]

	set bad 0

	inf_begin_tran $DB

	#
	# Do update, depending on new value vs old
	#
	if {[catch {inf_exec_stmt $stmt_del\
	                                   $cust_id\
	                                   $level\
	                                   $id} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {inf_close_stmt $stmt_ins}

	if {$bad} {
		inf_rollback_tran $DB
		go_cust_lvl_limit
	} else {
		inf_commit_tran $DB
		# if monitor is on, we send a message
		if {[OT_CfgGet MONITOR 0]} {
			set old_msf [reqGetArg OldStk]
			_send_monitor_stkfac_msg $cust_id $level $id "--" $old_msf "DELETED"
		}

		msg_bind "Deletion Successful"
		go_cust_lvl_limit
	}
}

#
# _send_monitor_stkfac_msg : wrapper for MONITOR::send_cust_max_stake, we do
# some logging and we populate required data
#
proc _send_monitor_stkfac_msg {cust_id level id msf old_msf operation} {

	global USERNAME
	# we will use this for customer data
	variable CUST_STK

	set fn {ADMIN::CUST::_send_monitor_stkfac_msg}

	# grab current timestamp
	set timestamp  [clock format [clock scan "today"] -format "%Y-%m-%d %H:%M:%S"]

	if { $level == "ALL" } {
		# If we are updating the customer global stake factor
		# we don't need to lookup the level name
		set stk_fac_val "--"
	} else {
		# otherwise we grab the human readable name associated to the current
		# level ID
		set stk_fac_val [_get_stkfac_level_name $cust_id $level $id]
	}

	# log
	ob_log::write INFO {$fn Sending Monitor Message:$timestamp - \
	                                                $CUST_STK(account_number) - \
	                                                $CUST_STK(surname) - \
	                                                $CUST_STK(username) - \
	                                                $level - \
	                                                $msf - \
	                                                $stk_fac_val - \
	                                                $old_msf - \
	                                                $operation - \
	                                                $USERNAME}

	# send message
	set outcome [ MONITOR::send_cust_max_stake   $timestamp \
	                                             $CUST_STK(account_number) \
	                                             $CUST_STK(surname) \
	                                             $CUST_STK(username) \
	                                             $level \
	                                             $msf \
	                                             $stk_fac_val \
	                                             $old_msf \
	                                             $operation \
	                                             $USERNAME ]

	if {$outcome} {
		ob_log::write INFO {$fn Monitor message has been sent}
	} else {
		ob_log::write ERROR {$fn Monitor message sending has failed!}
	}

}



#
# _get_stkfac_level_name : Helper function to retrieve the user
# readable name based on hierarchy level. We will retrieve the name associated
# to the ID, based on the level value
#
proc _get_stkfac_level_name {cust_id level_type level_id} {

	global DB

	set fn {ADMIN::CUST::_get_stkfac_level_name}
	set level_value ""

	switch -exact $level_type {

		"CLASS" {
			set sql { select
							name
						from
							tEvClass
						where
							ev_class_id = ? }
		}
		"TYPE" {
			set sql { select
							name
						from
							tEvType
						where
							ev_type_id = ? }
		}
		"EVOCGRP" {
			set sql { select
							name
						from
							tEvOcGrp
						where
							ev_oc_grp_id = ? }
		}

		default {
			ob_log::write ERROR {$fn - wrong DD level $level_type }
			return
		}

	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $level_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 0} {
		ob::log::write ERROR {$fn - No level value found }
		set level_value "Not Available"
	} else {
		set level_value [db_get_col $res 0 name]
	}

	catch {db_close $res}
	return $level_value

}



#
# _populate_max_stk_var : we grab data used for message sending and we put
# it into a variable used by other monitor related functions
#
proc _populate_max_stk_var {cust_id} {
	global DB
	# we will save common data here
	catch { unset CUST_STK }
	variable CUST_STK

	set fn "_populate_max_stk_var"

	set sql {
			select
				c.acct_no           as account_number,
				c.username          as username,
				r.lname             as surname
			from
				tCustomer c,
				tCustomerReg r
			where
				c.cust_id = ?
				and c.cust_id = r.cust_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 0} {
		ob::log::write ERROR {$fn - No customer details in DB for $cust_id}
	} else {
		# binding data found to global var
		set CUST_STK(account_number)        [db_get_col $res 0 account_number]
		set CUST_STK(username)              [db_get_col $res 0 username]
		set CUST_STK(surname)               [db_get_col $res 0 surname]
	}

	catch {db_close $res}

}

#
# ----------------------------------------------------------------------------
# Main handler for a plethora of actions from the customer management screen
# ----------------------------------------------------------------------------
#
proc do_cust args {

	set act [reqGetArg SubmitName]

	ob_log::write DEBUG {do_cust: $act}

	switch -- $act {
		"GoCust"  {
			go_cust
			return
		}
		"CustUpd" {
			do_cust_upd
		}
		"GoCustUpdReg" {
			go_cust_reg
			return
		}
		"GoCustTxnQry" {
			ADMIN::CUST_TXN::go_txn_query
			return
		}
		"GoBetTransferSearch" {
			ADMIN::BET_TRANSFER::go_bet_transfer_search
			return
		}
		"GoBetQuery" {
			tpBindString AcctNo [reqGetArg AcctNo]
			ADMIN::BET::go_bet_query
			return
		}
		"DoManDep" {
			do_cust_man_dep
		}
		"ViewManDep" {
			go_view_cust_man_dep
			return
		}
		"DoManWtd" {
			do_cust_man_wtd
		}
		"ViewManWtd" {
			go_view_cust_man_wtd
			return
		}
		"UpdManWtd" {
			do_upd_man_wtd
			return
		}
		"UpdUname" {
			do_cust_uname
		}
		"InternetActivate" {
			do_cust_internet_activate
		}
		"UpdSMS" {
			do_cust_mobile
		}
		"UpdPwd" {
			do_cust_pwd
		}
		"UpdPIN" {
			do_cust_pin
		}
		"GoNewCustMsg" {
			go_add_cust_msg
			return
		}
		"GoFilterCustMsg" {
			go_filter_cust_msg
			return
		}
		"SetMsg" {
			do_cust_msg_set
			go_cust_msgs
			return
		}
		"DoCustStopCodes" {
			do_cust_stop_code
			return
		}
		"UpdStmt" {
			go_cust_stmt
			return
		}
		"GoCustTotals" {
			ADMIN::CUST_TOTALS::go_cust_totals
			return
		}
		"GoCustSimpleTotals" {
			ADMIN::CUST_TOTALS::go_cust_simple_totals
			return
		}
		"DoCustLimit" {
			if { [OT_CfgGetTrue FUNC_CUST_DEP_LIMITS] } {
				do_cust_limit
			} else {
				error "unexpected action: $act"
			}

		}
		"DoCustSelfExcl" {
			if { [OT_CfgGetTrue FUNC_CUST_SELF_EXCL] } {
				do_cust_self_excl
			} else {
				error "unexpected action: $act"
			}
		}
		"DoCustPokerLimit" {
			if {[OT_CfgGetTrue FUNC_MCS_POKER]} {
				do_cust_poker_limit
			} else {
				error "unexpected action: $act"
			}
		}
		"DoCustTypeLimit" {
			if { [OT_CfgGetTrue FUNC_CUST_DEP_LIMITS] } {
				do_cust_type_limit
			} else {
				error "unexpected action: $act"
			}
		}
		"GoCustMsgs" {
			go_cust_msgs
			return
		}
		"FilterMsgs" {
			go_cust_msgs
			return
		}
		"ViewCustFlags" {
			go_cust_flags
			return
		}
		"UpdCustFlags" {
			do_upd_cust_flags
			return
		}
		"DoCustStatusFlags" {
			do_cust_status_flags
			return
		}
		"CustCasinoTfrHist" {
			show_casino_tfrs
			return
		}
		"UpdCustCasinoTfr" {
			upd_casino_tfrs
			return
		}
		"GoCustVerificationCheck" {
			ADMIN::VERIFICATION::go_profile_def_list 1 [reqGetArg CustId]
			return
		}
		"ViewCustPromo" {
			ADMIN::CUST::PROMOTIONS::go_promotion [reqGetArg CustId] \
												  [reqGetArg PromotionId]
			return
		}
 		"DoPlaytechAdj" {
 			ADMIN::PLAYTECH::manual_adjust
 			return
 		}
 		"ViewPlaytechAdj" {
 			ADMIN::PLAYTECH::view_adjustments
 			return
 		}
 		"ViewCasinoQueue" {
 			ADMIN::CASINOQUEUE::go username [reqGetArg Username] system [reqGetArg system]
 			return
 		}
 		"SyncPlaytechAccount" {
 			ADMIN::PLAYTECH::synchronise_account
 			return
 		}
 		"SyncPlaytechPassword" {
 			ADMIN::PLAYTECH::synchronise_password
 			return
 		}
		"GoCustNtc" {
			ADMIN::CUST::NOTICE::show
		}
		"DoCustXSysAcctUpd" {
			do_cust_xsys_acct_upd
		}
		"ZeroCPMBalances" {
			zero_balances
		}
		"UpdManLinkAcct" {
			do_manually_link_acct
		}
		"RemoveLinkAcct" {
			do_remove_link_acct
		}
		"DoNetReferTag" {
			_tag_netrefer_customer
		}
		"GoLoginHistory" {
			reqSetArg search_username [reqGetArg Username]
			reqSetArg search_username_exact "on"
			reqSetArg search_for "machine_login_history"
			ADMIN::MACHINE_ID::home
			return
		}
		"DoCustUpdLimit" {
			clear_self_excl
		}
		"DoLoggedPunterClose" {
			do_logged_punter_close
		}
		"DoLoggedPunterActivate" {
			do_logged_punter_activate
		}
		"GoCustActivity" {
			ADMIN::CUST_ACTIVITY::do_cust_activity 1
			return
		}
		"AddPMBExp" {
			ADMIN::PMT_MULTIPLE::do_cust_pmb_exp "add"
		}
		"DelPMBExp" {
			ADMIN::PMT_MULTIPLE::do_cust_pmb_exp "del"
		}
		"UpdPMBExp" {
			ADMIN::PMT_MULTIPLE::do_cust_pmb_exp "upd"
		}
		"EditCustPMB" {
			tpBindString CustId      [reqGetArg CustId]
			tpBindString Username    [reqGetArg username]
			tpBindString PayMthd     [reqGetArg pay_mthd]
			tpBindString PayMthdDesc [reqGetArg pay_mthd_desc]
			tpBindString PmtScheme   [reqGetArg pmt_scheme]
			tpBindString PMBPeriod   [reqGetArg PMBPeriod]

			asPlayFile -nocache pmt/edit_pmb.html
			return
		}
		"AddMaxCombine" {
			ADMIN::PMT_MULTIPLE::do_cust_max_combine "add"
		}
		"DelMaxCombine" {
			ADMIN::PMT_MULTIPLE::do_cust_max_combine "del"
		}
		"UpdMaxCombine" {
			ADMIN::PMT_MULTIPLE::do_cust_max_combine "upd"
		}
		"EditCustMaxCombine" {
			tpBindString CustId        [reqGetArg CustId]
			tpBindString Username      [reqGetArg username]
			tpBindString PayMthd       [reqGetArg pay_mthd]
			tpBindString PayMthdDesc   [reqGetArg pay_mthd_desc]
			tpBindString PmtScheme     [reqGetArg pmt_scheme]
			tpBindString MaxCombine    [reqGetArg MaxCombine]

			asPlayFile -nocache pmt/edit_max_combine.html
			return
		}
		"UpdDefaultMaxCombine" {
			ADMIN::PMT_MULTIPLE::do_cust_default_max_combine
		}
		"UpdMaxCustCards" {
			ADMIN::PMT_MULTIPLE::do_cust_max_cards
		}
		"DoWithdrawalLimit" {
			if {[OT_CfgGet CUST_WTD_LIMITS 0]} {
				do_withdrawal_limit
			}
		}
		"DeleteWithdrawalLimit" {
			if {[OT_CfgGet CUST_WTD_LIMITS 0]} {
				delete_withdrawal_limit
			}
		}
		"RewardAdhocToken" {
			do_reward_adhoc_token
		}
		"GoCustQualBets" {
			go_cust_qual_bets
			return
		}
		default {
			error "unexpected action: $act"
		}
	}
	go_cust
}


#
# ----------------------------------------------------------------------------
# Update customer status
# ----------------------------------------------------------------------------
#
proc do_cust_upd args {

	global DB USERNAME

	set dateMSF "[reqGetArg yearMSF]-[reqGetArg monthMSF]-[reqGetArg dayMSF]"

	if {[string length $dateMSF] == 2} {
		set dateMSF {}
	}

	if {![op_allowed UpdCustStatus]} {
		err_bind "You don't have permission to update customer information"
		return
	}

	# check if Operator Notes > 255 chars
	set OperNotes [reqGetArg OperNotes]

	if {[string length $OperNotes] > 255} {
		err_bind "Customer Notes field must not be greater than 255 characters"
		return
	}

	set sql {
		execute procedure pUpdCust(
			p_adminuser = ?,
			p_cust_id  = ?,
			p_status = ?,
			p_status_reason = ?,
			p_max_stake_scale  = ?,
			p_allow_card = ?,
			p_contact_ok = ?,
			p_mkt_contact_ok = ?,
			p_ptnr_contact_ok = ?,
			p_oper_notes = ?,
			p_customer_sort = ?,
			p_good_addr = ?,
			p_good_email = ?,
			p_good_mobile = ?,
			p_bank_check = ?,
			p_view_date = ?,
			p_notes     = ?,
			p_statusMSF   = ?,
			p_contact_how = ?,
			p_liab_group = ?
		)
	}

	# Set the default, just incase its not configed on
	set mkt_contact_ok [reqGetArg MktContactOK]
	if {$mkt_contact_ok == ""} {
		set mkt_contact_ok "Y"
	}

	# setting repeatedly used reqArgs
	set cur_max_stake_scale  [reqGetArg MaxStakeScale]
	set old_max_stake_scale  [reqGetArg OldMaxStakeScale]
	set cust_id              [reqGetArg CustId]

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$cust_id\
			[reqGetArg Status]\
			[reqGetArg StatusReason]\
			$cur_max_stake_scale\
			[reqGetArg AllowCard]\
			[reqGetArg ContactOK]\
			$mkt_contact_ok\
			[reqGetArg PtnrContactOK]\
			$OperNotes\
			[reqGetArg CustomerSort]\
			[reqGetArg GoodAddr]\
			[reqGetArg GoodEmail]\
			[reqGetArg GoodMobile]\
			[reqGetArg BankCheck]\
			$dateMSF\
			[string toupper [reqGetArg Review]]\
			[reqGetArg statusMSF]\
			[reqGetArg contact_how]\
			[reqGetArg LiabGroup]]
		catch {db_close $res}
	} msg]

	inf_close_stmt $stmt

	if {!$c && [OT_CfgGet FUNC_CUST_CATEGORIES 0]} {
		ADMIN::OBJ_CATEGORY::update_selected_categories [reqGetArg CustId] C [reqGetArgs OBJ_CATS]
	}

	if {$c} {
		err_bind $msg
	} else {
		# if monitor is enabled , send a message
		# but only if MSF has been really updated
		if {[OT_CfgGet MONITOR 0] && $old_max_stake_scale != $cur_max_stake_scale} {
			_populate_max_stk_var $cust_id
			_send_monitor_stkfac_msg  $cust_id \
			                          "ALL" \
			                          0 \
			                          $cur_max_stake_scale \
			                          $old_max_stake_scale \
			                          "UPDATED"
		}
	}
}


#
# ----------------------------------------------------------------------------
# Updates customer ovs status flag
# ----------------------------------------------------------------------------
#

proc do_cust_upd_ovs_flag {cust_id} {

	global DB USERNAME

	set get_ovs_flag {
		select
			flag_value as action
		from
			tCustomerFlag
		where
			cust_id = ? and
			flag_name = ?
	}

	set upd_ovs_flag {
		execute procedure pUpdCustFlag(
			p_cust_id  = ?,
			p_flag_name = ?,
			p_flag_value = ?
		)
	}

	set stmt [inf_prep_sql $DB $get_ovs_flag]
	set res  [inf_exec_stmt $stmt [reqGetArg CustId] "ovs_action"]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 1} {
		set ovs_action [db_get_col $res 0 action]
		if {$ovs_action == "S"} {
			set stmt [inf_prep_sql $DB $upd_ovs_flag]
			set c [catch {
				set res [inf_exec_stmt $stmt\
				[reqGetArg CustId]\
				"ovs_action"\
				"X"]
				catch {db_close $res}
			} msg]

			inf_close_stmt $stmt

			if {$c} {
				err_bind $msg
			}
		}
	}
}


#
# ----------------------------------------------------------------------------
# Do a manual deposit
# ----------------------------------------------------------------------------
#
proc do_cust_man_dep args {

	global DB USERNAME

	if {![op_allowed ManDep]} {
		err_bind "You don't have permission to do manual deposits"
		return
	}

	set sql {
		execute procedure pManDepRqst(
			p_adminuser = ?,
			p_acct_id = ?,
			p_amount = ?,
			p_method = ?,
			p_extra_info = ?,
			p_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set ret_id 0

	set c [catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AcctId]\
			[reqGetArg Amount]\
			[reqGetArg Method]\
			[reqGetArg Description]\
			[reqGetArg Code]]
		set ret_id [db_get_coln $res 0 0]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
	}

	tpSetVar     DoneOK     1
	tpSetVar     ManDepDone 1
	tpBindString ManDepId   MD[format %07d $ret_id]

	inf_close_stmt $stmt
}


#
# ----------------------------------------------------------------------------
# View manual deposits
# ----------------------------------------------------------------------------
#
proc go_view_cust_man_dep args {

	global DB USERNAME

	set sql {
		select
			mdr_id,
			cr_date,
			amount,
			method,
			code,
			extra_info
		from
			tManDepRqst
		where
			acct_id = ?
		order by
			mdr_id asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt [reqGetArg AcctId]]
	inf_close_stmt $stmt

	tpSetVar NumManDeps [db_get_nrows $res]

	tpBindTcl Date        sb_res_data $res md_idx cr_date
	tpBindTcl Amount      sb_res_data $res md_idx amount
	tpBindTcl Method      sb_res_data $res md_idx method
	tpBindTcl Code        sb_res_data $res md_idx code
	tpBindTcl ExtraInfo   sb_res_data $res md_idx extra_info

	tpBindString CustId [reqGetArg CustId]
	tpBindString AcctId [reqGetArg AcctId]

	asPlayFile -nocache cust_man_dep_hist.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Do a manual withdrawal
# ----------------------------------------------------------------------------
#
proc do_cust_man_wtd args {

	global DB USERNAME

	if {![op_allowed ManWtd]} {
		err_bind "You don't have permission to do manual adjustments"
		return
	}

	set sql {
		execute procedure pManWtdRqst(
			p_adminuser = ?,
			p_acct_id = ?,
			p_amount = ?,
			p_method = ?,
			p_extra_info = ?,
			p_location = ?,
			p_collect_time = ?,
			p_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set ret_id 0

	set c [catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg AcctId]\
			[reqGetArg Amount]\
			[reqGetArg Method]\
			[reqGetArg Description]\
			[reqGetArg Location]\
			[reqGetArg Time]\
			[reqGetArg Code]]
		set ret_id [db_get_coln $res 0 0]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
	}

	tpSetVar     DoneOK     1
	tpSetVar     ManWtdDone 1
	tpBindString ManWtdId   MW[format %07d $ret_id]

	inf_close_stmt $stmt
}


#
# ----------------------------------------------------------------------------
# View manual withdrawals
# ----------------------------------------------------------------------------
#
proc go_view_cust_man_wtd args {

	global DB USERNAME

	set sql {
		select
			mwr_id,
			cr_date,
			amount,
			method,
			code,
			extra_info,
			status,
			location,
			collect_time
		from
			tManWtdRqst
		where
			acct_id = ?
		order by
			mwr_id asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt [reqGetArg AcctId]]
	inf_close_stmt $stmt

	tpSetVar NumManWtds [set n_rows [db_get_nrows $res]]

	tpBindTcl MWRId       sb_res_data $res mw_idx mwr_id
	tpBindTcl Date        sb_res_data $res mw_idx cr_date
	tpBindTcl Amount      sb_res_data $res mw_idx amount
	tpBindTcl Method      sb_res_data $res mw_idx method
	tpBindTcl Status      sb_res_data $res mw_idx status
	tpBindTcl Code        sb_res_data $res mw_idx code
	tpBindTcl ExtraInfo   sb_res_data $res mw_idx extra_info
	tpBindTcl Location    sb_res_data $res mw_idx location
	tpBindTcl CollectTime sb_res_data $res mw_idx collect_time

	global MW

	for {set r 0} {$r < $n_rows} {incr r} {
		set MW($r,status) [db_get_col $res $r status]
	}

	tpBindString CustId [reqGetArg CustId]
	tpBindString AcctId [reqGetArg AcctId]

	asPlayFile -nocache cust_man_wtd_hist.html

	db_close $res
}


proc do_upd_man_wtd args {
	tpBufWrite "not implemnented"
}


#
# ----------------------------------------------------------------------------
# Change a customer's Text betting details
# ----------------------------------------------------------------------------
#
proc do_cust_mobile args {

	global DB

	set cust_id  [reqGetArg CustId]
	set mobile   [reqGetArg mobile]
	set int_code [reqGetArg txtCCode]
	set pin      [reqGetArg txtPIN]
	set pin2     [reqGetArg txtPIN2]

	if {$mobile == "" || $int_code == ""} {
		err_bind "Please provide a country calling code and mobile number"
		return
	}

	set full_mobile "+$int_code"
	append full_mobile [string trimleft $mobile 0]

	# Check whether the mobile on this account is being
	# used for text betting on any other accounts
	set duplicate_mobile_qry \
		 {
		 select
			count(*) acct_count
		 from
			tcustomerreg r,
			tcustomer c
		 where
			r.mobile = ? and
			c.cust_id <> ? and
			c.status = 'A' and
			c.mobile_pin is not null and
			c.cust_id = r.cust_id}

	set stmt_duplicate_mobile [inf_prep_sql $DB $duplicate_mobile_qry]
	set res_duplicate_mobile  [inf_exec_stmt $stmt_duplicate_mobile $full_mobile $cust_id]
	inf_close_stmt $stmt_duplicate_mobile

	set acct_count [db_get_col $res_duplicate_mobile 0 acct_count]
	db_close $res_duplicate_mobile

	if {$acct_count > 0} {
		# Another customer has the same mobile number with
		# a PIN registered so we can't allow this one to
		# register a PIN for text betting without changing
		# mobile number
		err_bind "Mobile number is registered for Text betting on another account"
		return
	}

	if {$pin == ""} {
		err_bind "Please provide a PIN number for Text betting"
		return
	}

	if {[string length $pin] != 4} {
		err_bind "Text betting PIN number must be 4 characters"
		return
	}

	if {$pin != $pin2} {
		err_bind "Mobile pins do not match"
		return
	} else {

		set cust_id [reqGetArg CustId]

		set sql {
			select
				password_salt
			from
				tCustomer
			where
				cust_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set rs [inf_exec_stmt $stmt $cust_id]} msg]} {
			catch {
				inf_close_stmt $stmt
				db_close $rs
			}
			err_bind $msg
			return
		}

		set nrows [db_get_nrows $rs]
		if {$nrows == 1} {
			set password_salt [db_get_col $rs 0 password_salt]
			inf_close_stmt $stmt
			db_close $rs
		} else {
			catch {
				inf_close_stmt $stmt
				db_close $rs
			}
			err_bind "Unabled to retrieve customer data"
			return
		}

		set password_salt [get_cust_passwd_salt $cust_id]
		set enc_pin [encrypt_password $pin $password_salt]
	}

	set sql {
		update
			tcustomerreg
		set
			mobile = ?
		where
			cust_id = ?
		}
	set stmt    [inf_prep_sql $DB $sql]

	set c [catch {set res [inf_exec_stmt $stmt $full_mobile $cust_id]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
		return
	}

	set sql {
		update
			tcustomer
		set
			mobile_pin = ?
		where
			cust_id = ?
		}
	set stmt    [inf_prep_sql $DB $sql]
	set cust_id [reqGetArg CustId]

	set c [catch {set res [inf_exec_stmt $stmt $enc_pin $cust_id]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
		return
	}

	inf_close_stmt $stmt
}



#
# ----------------------------------------------------------------------------
# Perform internet activation
# ----------------------------------------------------------------------------
#
proc do_cust_internet_activate args {

	global DB

	# Firstly set customer's new username and password
	# Must do it this way around, otherwise the trigger
	# on tcustomer will fail
	do_cust_pwd

	if {[tpGetVar IsError] != 1} {
		do_cust_uname
	} else {
		return
	}

	# get encrypted password from the DB
	set sql {
		select
		    username,
			password
		from
			tCustomer
		where
			cust_id = ?
	}

	set cust_id [reqGetArg CustId]
	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $cust_id]} msg]} {
		catch {
			inf_close_stmt $stmt
			db_close $rs
		}
		err_bind $msg
		return
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set username [db_get_col $rs 0 username]
		set password [db_get_col $rs 0 password]
		inf_close_stmt $stmt
		db_close $rs
	} else {
		catch {
			inf_close_stmt $stmt
			db_close $rs
		}
		err_bind "Unabled to retrieve customer data"
		return
	}

	if {[tpGetVar IsError] != 1} {
		if {[OT_CfgGet FUNC_PLAYTECH_CASINO 0] == 1} {
			# This customer shouldn't be in Playtech yet, so send them across
			set sql {
				execute procedure pXSysSync(
					p_cust_id = ?,
					p_sync_op = 'I',
					p_new_username = ?,
					p_new_password = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]
			if {[catch {
				set res [inf_exec_stmt $stmt $cust_id $username $password]
				catch {db_close $res}
				inf_close_stmt $stmt
			} msg]} {
				inf_close_stmt $stmt
				err_bind $msg
				return
			}
		}
	} else {
		return
	}

	set cust_id [reqGetArg CustId]
	set_customer_flag $cust_id "inet_activated" "1"
}


#
# ----------------------------------------------------------------------------
# Change a customer's xsysacct usernames
# ----------------------------------------------------------------------------
#
proc do_cust_xsys_acct_upd args {

	global DB

	if {![op_allowed ManageXSysAcct]} {
		err_bind "You don't have permission to update customer external aliases"
		return
	}

	# get the list of xsyshost names from the db
	# then get the input for each name
	# and if it's != "", update the db

	set cust_id         [reqGetArg CustId]
	set system_grp_name [reqGetArg systemGroupName]
	set old_alias       [reqGetArg old_xsys_alias]
	set new_alias       [reqGetArg xsys_alias]

	# get a systemname within system_grp_name

	set sql {
		select first 1
			h.name,
			h.system_id
		from
			tXSysHost      h,
			tXSysHostGrp   g,
			tXSysHostGrpLk l
		where
			g.desc      = ?             and
			g.type      = 'SYS'         and
			g.group_id  = l.group_id    and
			l.system_id = h.system_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $system_grp_name]

	set system_name [db_get_col $res 0 name]
	set system_id   [db_get_col $res 0 system_id]

	db_close $res
	inf_close_stmt $stmt

	# if old_alias == "", then there's no previous alias
	# therefore, need to use pinsxsysacct

	if {$old_alias == ""} {
		set sql {
			execute procedure pInsXSysAcct (
				p_cust_id = ?,
				p_xsys_username = ?,
				p_system_name = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id $new_alias $system_name]
	} else {

		set sql {
			execute procedure pUpdXSysAcct (
				p_xsys_username = ?,
				p_system_name = ?,
				p_new_username = ?
			)
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $old_alias $system_name $new_alias]
	}

	db_close $res
	inf_close_stmt $stmt


}

#
# ----------------------------------------------------------------------------
# Change a customer username
# ----------------------------------------------------------------------------
#
proc do_cust_uname args {

	global DB

	if {![op_allowed UpdCustUsername]} {
		err_bind "You don't have permission to update customer usernames"
		return
	}

	set uname_1 [string toupper [reqGetArg -unsafe Username_1]]
	set uname_2 [string toupper [reqGetArg -unsafe Username_2]]

	if {$uname_1 != $uname_2} {
		err_bind "Usernames don't match"
		return
	}
	if {$uname_1 == ""} {
		err_bind "Username is empty"
		return
	}
	if {[string first " " $uname_1] != -1} {
		## no spaces in username please
		err_bind "invalid username (no spaces allowed)"
		return
	}

	# Check username not present
	set sql {
		select
			first 1 cust_id
		from
			tcustomer
		where
			username_uc = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $uname_1]} msg]} {
		catch {
			inf_close_stmt $stmt
			db_close $rs
		}
		err_bind $msg
		return
	}

	set rows [db_get_nrows $rs]

	inf_close_stmt $stmt
	db_close $rs

	if {$rows > 0} {
		err_bind "Username already taken"
		return
	}

	set cust_id [reqGetArg CustId]

	# Do the update
	set msg [upd_username $cust_id $uname_1 [OT_CfgGet FUNC_NO_UPD_ACCT_NO 0]]

	if {$msg != "OK"} {
		err_bind $msg
		return
	}

}


proc get_cust_passwd_salt {cust_id} {

	global DB

	set password_salt ""

	set sql {
		select
			password_salt
		from
			tCustomer
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {set rs [inf_exec_stmt $stmt $cust_id]} msg]} {
		catch {
			inf_close_stmt $stmt
			db_close $rs
		}
		err_bind $msg
		return
	}

	set nrows [db_get_nrows $rs]
	if {$nrows == 1} {
		set password_salt [db_get_col $rs 0 password_salt]
		inf_close_stmt $stmt
		db_close $rs
	} else {
		catch {
			inf_close_stmt $stmt
			db_close $rs
		}
		err_bind "Unabled to retrieve customer data"
		return
	}

	return $password_salt
}



#
# ----------------------------------------------------------------------------
# Change a customer password
# ----------------------------------------------------------------------------
#
proc do_cust_pwd args {

	global DB USERID

	if {![op_allowed UpdCustPWD]} {
		err_bind "You don't have permission to update customer passwords"
		return
	}

	set username [reqGetArg Username]

	set pwd_1 [reqGetArg Password_1]
	set pwd_2 [reqGetArg Password_2]

	if {[OT_CfgGet CUST_PWD_CASE_INSENSITIVE 0]} {
		set pwd_1 [string toupper $pwd_1]
		set pwd_2 [string toupper $pwd_2]
	}

	#Check password is valid
	set tmp_err [tb_register::chk_unsafe_pwd $pwd_1 $pwd_2 $username]
	if {$tmp_err != ""} {
		err_bind [join $tmp_err "<br>\n"]
	}

	set cust_id [reqGetArg CustId]

	set password_salt [get_cust_passwd_salt $cust_id]

	set enc_pwd [encrypt_password $pwd_1 $password_salt]

	set sql {
		update tCustomer set
			password = ?
		where
			cust_id = ?
	}

	set stmt    [inf_prep_sql $DB $sql]
	set c       [catch {
		set res [inf_exec_stmt $stmt\
					 $enc_pwd\
					 $cust_id]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
		return
	}

	inf_close_stmt $stmt

	## add the cust status flag

	set sql {
		execute procedure pInsCustStatusFlag (
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_user_id = ?,
			p_reason = ?
		)
	}

	set stmt    [inf_prep_sql $DB $sql]
	set cust_id [reqGetArg CustId]
	set c       [catch {
		set res [inf_exec_stmt $stmt \
						$cust_id \
						"PWORD" \
						$USERID \
						"Temporary password set"]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
		return
	}

	inf_close_stmt $stmt

	chk_casino_pwd

	# send email
	if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {

		set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC "queue_email"]
		set params [list TEMP_PASSWORD $cust_id E {} {} $pwd_1]

		# send email to customer
		if {[catch {set res [eval $queue_email_func $params]} msg]} {
			OT_LogWrite 2 "Failed to queue $email_type email, $msg"
		}
	}
}

#
# ----------------------------------------------------------------------------
# Check casino password
# ----------------------------------------------------------------------------
proc chk_casino_pwd {} {

	if {[OT_CfgGet MCS_UPDATE_PASSWORD 0]} {
		ADMIN::MCS_CUST::update_password $cust_id $pwd_1
		return
	}
}


#
# ----------------------------------------------------------------------------
# Change a customer PIN
# ----------------------------------------------------------------------------
#
proc do_cust_pin args {

	global DB

	if {![op_allowed UpdCustPIN]} {
		err_bind "You don't have permission to update customer PINs"
		return
	}

	set pin_1 [reqGetArg -unsafe PIN_1]
	set pin_2 [reqGetArg -unsafe PIN_2]

	set min [OT_CfgGet MIN_PIN_LENGTH 6]
	set max [OT_CfgGet MAX_PIN_LENGTH 8]

	if {$pin_1 != $pin_2} {
		err_bind "PINs don't match"
		return
	}
	if {$pin_1 == ""} {
		err_bind "PIN is empty"
		return
	}

	if {[string length $pin_1] < $min} {
		err_bind "PIN too short"
		return
	}

	if {[string length $pin_1] > $max} {
		err_bind "PIN too long"
		return
	}

	set sql {
		update tCustomer set
			bib_pin = ?,
			temporary_pin = ?
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [inf_exec_stmt $stmt\
			[pin_no_enc $pin_1]\
			"Y"\
			[reqGetArg CustId]]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
	}

	inf_close_stmt $stmt
}


#
# ----------------------------------------------------------------------------
# Add/update customer messages
# ----------------------------------------------------------------------------
#
proc do_cust_msg_set args {

	global DB USERID

	if {![op_allowed SetCustMsg]} {
		err_bind "You don't have permission to set customer messages"
		return
	}

	set cust_id     [reqGetArg CustId]
	set msg         [string trim [reqGetArg -unsafe Message]]
	set cust_msg_id [reqGetArg CustMsgId]
	set msg_sort    [reqGetArg CustMsgSort]

	if {$cust_msg_id==0} {

		set sql {
			insert into tCustomerMsg
				(cust_id,oper_id,sort,message)
			values
				(?,?,?,?)
		}
		set stmt_args [list $cust_id $USERID $msg_sort $msg]
	} else {

		set sql {
			update tCustomerMsg set
				oper_id = ?,
				message = ?,
				last_update = CURRENT year to second
			where
				cust_msg_id = ?
		}
		set stmt_args [list $USERID $msg $cust_msg_id]
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {
		set res [eval [concat inf_exec_stmt $stmt $stmt_args]]
		catch {db_close $res}
	} msg]

	if {$c != 0} {
		err_bind $msg
	}

	inf_close_stmt $stmt
}


#
# ----------------------------------------------------------------------------
# Customer registrations
# ----------------------------------------------------------------------------
#
proc do_cust_reg_anal args {

	global DB DATA

	set dt_0 "1999-01-01 00:00:00"
	set dt_1 "2999-01-01 23:59:59"

	if {[set rd_0 [reqGetArg RegDate1]] != ""} {
		set dt_0 "$rd_0 00:00:00"
	}
	if {[set rd_1 [reqGetArg RegDate2]] != ""} {
		set dt_1 "$rd_1 23:59:59"
	}

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.country_code,
			c.cr_date,
			c.status,
			c.elite,
			r.fname,
			r.lname,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_postcode,
			r.email,
			co.country_name,
			m.ext_cust_id,
			m.code,
			count (o.cust_id) num_urn_matches
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			tCountry co,
			tExtCust m,
			outer tExtCust o
		where
			c.cr_date between ? and ? and
			c.cust_id = r.cust_id and
			c.cust_id = m.cust_id and
			o.ext_cust_id != '' and
			o.ext_cust_id = m.ext_cust_id and
			c.country_code = co.country_code and
			c.cust_id = a.cust_id  and
			a.owner   <> 'D'
		group by
			1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
		order by
			c.cust_id asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $dt_0 $dt_1]
	inf_close_stmt $stmt

	tpSetVar NumRegs [set rows [db_get_nrows $res]]

	array set DATA [list]

	#
	# Load list of US states where status is 'S'
	#
	set sql {
		select
			state_code,
			state_name
		from
			tUSState
		where
			status = 'S'
	}

	set stmt       [inf_prep_sql $DB $sql]
	set res_state  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set state_codes [join [db_get_col_list $res_state state_code] |]
	set STATE_RX    {(\m($state_codes)\M)|(\m($state_codes)\d{4,5}\M)}
	set STATE_RX    [subst -nobackslashes -nocommands $STATE_RX]
	set ZIP_RX      {\d{4,5}}
	set COUNTRY_RX  {(\mUS\M)|(\mUSA\M)|(\mUNITED STATES\M)}
	set UKPC_RX     {^[A-Z][A-Z]?[0-9][0-9A-Z]?[ ]*[0-9][A-Z][A-Z]$}

	db_close $res_state

	set num_norm  0
	set num_elite 0

	#
	# Make an attempt to guess the status of a registration
	#
	for {set r 0} {$r < $rows} {incr r} {

		set a1    [db_get_col $res $r addr_street_1]
		set a2    [db_get_col $res $r addr_street_2]
		set a3    [db_get_col $res $r addr_street_3]
		set a4    [db_get_col $res $r addr_street_4]
		set city  [db_get_col $res $r addr_city]
		set pcode [db_get_col $res $r addr_postcode]

		set ok 1

		set DATA($r,acct_no)   [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($r,elite)     [db_get_col $res $r elite]
		set DATA($r,CustId)    [db_get_col $res $r cust_id]
		set DATA($r,Username)  [db_get_col $res $r username]
		set DATA($r,Status)    [db_get_col $res $r status]
		set DATA($r,RegDate)   [db_get_col $res $r cr_date]
		set DATA($r,FName)     [db_get_col $res $r fname]
		set DATA($r,LName)     [db_get_col $res $r lname]
		set DATA($r,Addr1)     [db_get_col $res $r addr_street_1]
		set DATA($r,Addr2)     [db_get_col $res $r addr_street_2]
		set DATA($r,Addr3)     [db_get_col $res $r addr_street_3]
		set DATA($r,Addr4)     [db_get_col $res $r addr_street_4]
		set DATA($r,City)      [db_get_col $res $r addr_city]
		set DATA($r,Postcode)  [db_get_col $res $r addr_postcode]
		set DATA($r,Country)   [db_get_col $res $r country_name]
		set DATA($r,Email)     [db_get_col $res $r email]
		set DATA($r,ExtCustId) [db_get_col $res $r ext_cust_id]
		set DATA($r,Code)      [db_get_col $res $r code]
		set DATA($r,NumUrnMatches) [db_get_col $res $r num_urn_matches]
		incr num_norm
		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}




		foreach a {a1 a2 a3 a4} {
			set v [string trim [set $a]]
			if {[string length $v] > 0} {
				if {[string length $v] < 5} {
					set ok 0
					break
				}
				if {[regexp -nocase $COUNTRY_RX $v]} {
					set ok 0
					break
				}
			}
		}

		foreach a {city pcode} {
			set v [string trim [set $a]]
			if {[regexp -nocase $STATE_RX $v]} {
				set ok 0
				break
			}
			if {[regexp -nocase $ZIP_RX $v]} {
				set ok 0
				break
			}
			if {[regexp -nocase $COUNTRY_RX $v]} {
				set ok 0
				break
			}
		}

		if {$DATA($r,NumUrnMatches) > 1} {
			set ok 0
		}

		set DATA($r,ok) $ok
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo      DATA acct_no   cust_idx
	tpBindVar Elite       DATA elite     cust_idx
	tpBindVar CustId      DATA CustId    cust_idx
	tpBindVar Username    DATA Username  cust_idx
	tpBindVar Status      DATA Status    cust_idx
	tpBindVar RegDate     DATA RegDate   cust_idx
	tpBindVar FName       DATA FName     cust_idx
	tpBindVar LName       DATA LName     cust_idx
	tpBindVar Addr1       DATA Addr1     cust_idx
	tpBindVar Addr2       DATA Addr2     cust_idx
	tpBindVar Addr3       DATA Addr3     cust_idx
	tpBindVar Addr4       DATA Addr4     cust_idx
	tpBindVar City        DATA City      cust_idx
	tpBindVar Postcode    DATA Postcode  cust_idx
	tpBindVar Country     DATA Country   cust_idx
	tpBindVar Email       DATA Email     cust_idx
	tpBindVar ExtCustId   DATA ExtCustId cust_idx
	tpBindVar ExtCustCode DATA Code      cust_idx
	tpBindVar NumUrnMatches DATA NumUrnMatches cust_idx

	asPlayFile -nocache cust_regs.html

	db_close $res
	unset DATA
}


#
# ----------------------------------------------------------------------------
# Suspend indicated customer accounts
# ----------------------------------------------------------------------------
#
proc do_cust_reg_susp args {

	global DB USERNAME

	set sql {
		execute procedure pUpdCustStatus(
			p_adminuser = ?,
			p_cust_id = ?,
			p_status = ?,
			p_status_reason = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	set c [catch {
		for {set i 0} {$i < [reqGetNumVals]} {incr i} {
			set a [reqGetNthName $i]
			if {[string range $a 0 4] == "CUST_"} {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					[string range $a 5 end]\
					S\
					[reqGetArg Reason]]
				catch {db_close $res}
			}
		}
	} msg]

	inf_close_stmt $stmt

	if {$c == 0} {
		inf_commit_tran $DB
	} else {
		inf_rollback_tran $DB
		err_bind $msg
	}

	go_cust_query
}


#
# ----------------------------------------------------------------------------
# Customer account suspensions
# ----------------------------------------------------------------------------
#
proc do_cust_acct_susp args {

	global DB DATA
	catch { unset DATA }

	set where ""

	set dt_0 "1999-01-01 00:00:00"
	set dt_1 "2999-01-01 23:59:59"

	if {[set rd_0 [reqGetArg SuspDate1]] != ""} {
		set dt_0 "$rd_0 00:00:00"
	}
	if {[set rd_1 [reqGetArg SuspDate2]] != ""} {
		set dt_1 "$rd_1 23:59:59"
	}

	if {([string length $dt_0] > 0) || ([string length $dt_1] > 0)} {
		set where " and "
		append where [mk_between_clause l.cr_date date $dt_0 $dt_1]
	}

	set status [reqGetArg Status]
	if {[string length $status] > 0} {
		append where " and l.status = '$status'"
	} else {
		append where ""
	}

	set channel [reqGetArg channels]
	if {[string length $channel] > 0} {
		append where " and c.source = '$channel'"
	} else {
		append where ""
	}

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.status c_status,
			c.elite,
			l.cust_status_id,
			l.status l_status,
			l.reason,
			l.cr_date,
			a.username admin_user,
			h.desc
		from
			tCustStatusLog l,
			tCustomer c,
			tAcct ac,
			tChannel h,
			outer tAdminUser a
		where
			l.cust_id = c.cust_id and
			l.user_id = a.user_id and
			c.source = h.channel_id and
			c.cust_id = ac.cust_id and
			ac.owner   <> 'D'
			$where
		order by
			cust_status_id desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	array set DATA  [list]
	set num_norm  0
	set num_elite 0

	for {set r 0} {$r < $rows} {incr r} {
		set DATA($num_norm,acct_no)        [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($num_norm,susp)           [expr {[db_get_col $res $r l_status]=="A"?0:1}]
		set DATA($num_norm,l_status)       [db_get_col $res $r l_status]
		set DATA($num_norm,cust_id)        [db_get_col $res $r cust_id]
		set DATA($num_norm,username)       [db_get_col $res $r username]
		set DATA($num_norm,c_status)       [db_get_col $res $r c_status]
		set DATA($num_norm,elite)          [db_get_col $res $r elite]
		set DATA($num_norm,cust_status_id) [db_get_col $res $r cust_status_id]
		set DATA($num_norm,reason)         [db_get_col $res $r reason]
		set DATA($num_norm,cr_date)        [db_get_col $res $r cr_date]
		set DATA($num_norm,admin_user)     [db_get_col $res $r admin_user]
		set DATA($num_norm,desc)           [db_get_col $res $r desc]
		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
		incr num_norm
	}

	tpSetVar NumNorm  $num_norm
	tpSetVar NumElite $num_elite

	tpBindVar AcctNo       DATA acct_no        susp_idx
	tpBindVar Susp         DATA susp           susp_idx
	tpBindVar LStatus      DATA l_status       susp_idx
	tpBindVar CustID       DATA cust_id        susp_idx
	tpBindVar Username     DATA username       susp_idx
	tpBindVar CStatus      DATA c_status       susp_idx
	tpBindVar Elite        DATA elite          susp_idx
	tpBindVar CustStatusID DATA cust_status_id susp_idx
	tpBindVar Reason       DATA reason         susp_idx
	tpBindVar CRDate       DATA cr_date        susp_idx
	tpBindVar AdminUser    DATA admin_user     susp_idx
	tpBindVar Desc         DATA desc           susp_idx

	asPlayFile -nocache cust_susps.html

	db_close $res
}

#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_dep_tfr
# Description : set the default tfr limit from sports book to casino
# Input :       cust_id
# Output :      none
# Author :      sgiles, 28-01-2005
#------------------------------------------------------------------------------
proc srp_dep_tfr {cust_id} {
	global DB
	set limit_val 0
	set sql [subst {
		select trunc(limit_value,0) as limit_value
		from   tCustLimits
		where  cust_id =?
		and    limit_type = 'max_tfr_dep_day'
		and    to_date >= CURRENT
		and    from_date <= CURRENT
		and    tm_date is null
	}]
	set stmt    [inf_prep_sql $DB $sql]
	set res     [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	if {[db_get_nrows $res]==1} {
		set limit_val [db_get_col $res 0 limit_value]
		tpBindString max_tfr_dep_day $limit_val
	}
	db_close $res

	return $limit_val
}

#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_wtd_tfr
# Description : set the default tfr limit from casino to sports book
# Input :       cust_id
# Output :      none
# Author :      sgiles, 28-01-2005
#------------------------------------------------------------------------------
proc srp_wtd_tfr {cust_id} {
	global DB
	set limit_val 0
	set sql [subst {
		select trunc(limit_value,0) as limit_value
		from   tCustLimits
		where  cust_id =?
		and    limit_type = 'max_tfr_wtd_day'
		and    to_date >= CURRENT
		and    from_date <= CURRENT
		and    tm_date is null
	}]
	set stmt    [inf_prep_sql $DB $sql]
	set res     [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	if {[db_get_nrows $res]==1} {
		set limit_val [db_get_col $res 0 limit_value]
		tpBindString max_tfr_wtd_day $limit_val
	}
	db_close $res

	return $limit_val
}

#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_set_default_dep
# Description : set up default max deposit based on customers selected language
# Input :       cust_id
# Output :      none
# Author :      JDM, 14-06-2001
#------------------------------------------------------------------------------
proc srp_set_default_dep {cust_id} {
	global DB
	set sql [subst {
		select  a.ccy_code,
				c.max_deposit
		from    tAcct a,
				tCcy c
		where   a.ccy_code = c.ccy_code
		and     a.cust_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	if {[db_get_nrows $res] == 1} {
		tpBindString ccy_code    [db_get_col $res 0 ccy_code]
		tpBindString max_deposit [db_get_col $res 0 max_deposit]
	}
	db_close $res
}
#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_ccy_max_dep
# Description :
# Input :       cust_id
# Output :      none
# Author :      JDM, 14-06-2001
#------------------------------------------------------------------------------
proc srp_ccy_max_dep {cust_id} {
	global DB
	set max_dep 0
	set sql [subst {
		select  a.ccy_code,
				trunc(c.max_deposit,0) as max_deposit
		from    tCcy c,
				tAcct a
		where   a.cust_id=?
		and     a.ccy_code = c.ccy_code
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	if {[db_get_nrows $res]==1} {
		set max_dep [db_get_col $res 0 max_deposit]
	}
	db_close $res
	return $max_dep
}
#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_cust_max_dep
# Description :
# Input :       cust_id
# Output :      none
# Author :      JDM, 14-06-2001
#------------------------------------------------------------------------------
proc srp_cust_max_dep {cust_id} {
	global DB
	set limit_val 0
	set sql [subst {
		select trunc(limit_value,0) as limit_value
		from   tCustLimits
		where  cust_id =?
		and    limit_type = 'max_dep_day_amt'
		and    to_date >= CURRENT
		and    from_date <= CURRENT
		and    tm_date is null
	}]
	set stmt    [inf_prep_sql $DB $sql]
	set res     [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	if {[db_get_nrows $res]==1} {
		set limit_val [db_get_col $res 0 limit_value]
	}
	db_close $res
	return $limit_val
}
#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_max_dep
# Description :
# Input :       cust_id
# Output :      none
# Author :      FD, 06-08-2003
#------------------------------------------------------------------------------
proc srp_max_dep {cust_id} {
	global DB DEP_LIMITS

	if {[info exists DEP_LIMITS]} {
		unset DEP_LIMITS
	}

	# Get customer's preferred limit, if it's set
	set cust_limit [srp_cust_max_dep $cust_id]
	tpSetVar cust_selected_max_dep $cust_limit

	# Get ccy top limit
	set ccy_limit [srp_ccy_max_dep $cust_id]
	tpBindString ccy_max_dep $ccy_limit

	set limits ""

	# Get ccy's limit values
	set sql [subst {
		select
			trunc(v.setting_value*1,0) as limit_value
		from
			tsitecustomval v,
			tacct a
		where
			a.cust_id = ? and
			v.setting_name = a.ccy_code
		order by 1
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res [inf_exec_stmt $stmt $cust_id $cust_id]

	set nrows [db_get_nrows $res]
	for {set i 0} {$i < $nrows} {incr i} {
		lappend limits [db_get_col $res $i limit_value]
	}
	db_close $res
	inf_close_stmt $stmt

	# Add customer's preferred limit if not already added
	if {$cust_limit != 0 && [lsearch $limits $cust_limit] < 0} {
		lappend limits $cust_limit
	}
	set limits [lsort -integer $limits]


	# Build up a list of limit values
	set num_limits [llength $limits]
	for {set i 0} {$i < $num_limits} {incr i} {
		set limit [lindex $limits $i]
		set DEP_LIMITS($i,dep_limit) $limit
		if {$limit == $cust_limit} {
			set DEP_LIMITS($i,dep_selected) " (currently)"
		} else {
			set DEP_LIMITS($i,dep_selected) ""
		}
	}
	tpSetVar dep_limit_num $nrows

	tpBindVar dep_limit    DEP_LIMITS dep_limit    dep_limit_idx
	tpBindVar dep_selected DEP_LIMITS dep_selected dep_limit_idx
}
#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   srp_set_cust_frq
# Description :
# Input :       cust_id
# Output :      none
# Author :      JDM, 14-06-2001
#------------------------------------------------------------------------------
proc srp_set_cust_frq {cust_id} {
	global DB
	set sql [subst {
		select limit_value
		from   tCustLimits
		where  cust_id =?
		and    limit_type = 'max_dep_day_frq'
		and    to_date >= CURRENT
		and    from_date <= CURRENT
		and    tm_date is null
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt
	set stored_frq  25
	if {[db_get_nrows $res] == 0} {
		# use default max deposit
		tpBindString cust_max_frq $stored_frq
	} else {
		# use customers max deposit
		set prefered_frq    [db_get_col $res 0 limit_value]
		tpBindString cust_max_frq $prefered_frq
	}
	db_close $res
}

##
# DESCRIPTION
#
#       Binds the value of the flag for social responsibility.
#       This uses a default value of 0, for 24hr, which is also the
#       default interpretation of a missing value.
##
proc srp_dep_week {cust_id} {
	tpBindString srp_frq [get_customer_flag $cust_id srp_dep_week 0]
}

##
# DESCRIPTION
#
#       Returns the value of the customer flag, or the default value if it doesn't exist.
##
proc get_customer_flag {cust_id flag_name {default_flag_value ""}} {
	global DB

	OT_LogWrite 12 "==>[info level [info level]]"

	set sql {
		select flag_value
		from tCustomerFlag
		where cust_id = ?
		and flag_name = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id $flag_name]
	inf_close_stmt $stmt
	if {[db_get_nrows $rs] > 0} {
		set flag_value [db_get_col $rs 0 flag_value]
		OT_LogWrite 12 "Found flag $flag_name value $flag_value"
	} else {
		set flag_value $default_flag_value
		OT_LogWrite 12 "Not found flag $flag_name, using default '$default_flag_value'"
	}
	db_close $rs
	return $flag_value
}

##
# DESCRIPTION
#
#       Sets the value of a customer flag, or if it doesn't exist, creates it.
#       If it is the same value, then no change is made.
#       Returns the value.
##
proc set_customer_flag {cust_id flag_name flag_value} {
	global DB

	OT_LogWrite 12 "==>[info level [info level]]"

	# find out if it is already set
	set sql {
		select  flag_value
		from    tCustomerFlag
		where   cust_id =?
		and             flag_name = ?
	}
	set stmt        [inf_prep_sql $DB $sql]
	set rs          [inf_exec_stmt $stmt $cust_id $flag_name]
	set nrows       [db_get_nrows $rs]
	if {$nrows} {
		set current_flag_value  [db_get_col $rs 0 flag_value]
	}
	db_close $rs

	if {![info exists current_flag_value]} {
		# if it doesn't exist, then change the value
		OT_LogWrite 12 "Inserting flag $flag_name value $flag_value"
		set sql {
			insert into tCustomerFlag
			(cust_id, flag_name, flag_value)
			values
			(?, ?, ?)
		}
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $cust_id $flag_name $flag_value
	} elseif {$current_flag_value != $flag_value} {
		# if it exists, and does not equal the current value, change the value
		OT_LogWrite 12 "Changing flag $flag_name from $current_flag_value to $flag_value"
		set sql {
			update tCustomerFlag
			set flag_value = ?
			where cust_id = ?
			and flag_name = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt $flag_value $cust_id $flag_name
	} else {
		# no change to the value because they are the same
		OT_LogWrite 12 "Making no change to flag $flag_name ($current_flag_value == $flag_value)"
	}
	# allow re-use of flag value
	return $flag_value
}


#------------------------------------------------------------------------------
# GAMECARE
# Procedure :   do_cust_limit
# Description : Updates the customers deposit limits
# Input :       cust_id, MAX_DEP, MAX_FRQ
# Output :      none
# Author :      JDM, 18-06-2001
#------------------------------------------------------------------------------
proc do_cust_limit args {

	global USERID

	if {![op_allowed UpdCustDepLimit]} {

		err_bind "You don't have permission to update customer deposit limits"
		return
	}

	if {[OT_CfgGet FUNC_DEPOSIT_LIMIT_MANUAL_FIELD 0]} {
		set amount [reqGetArg dep_limit_text]
	} else {
		set amount ""
	}
	if {$amount == ""} {
		set amount [reqGetArg dep_limit]
	} elseif {![op_allowed UpdCustDepLimitFree]} {

		err_bind "You don't have permission to update customer deposit\
			 limits freely. Use the values provided in drop down\
			 list."
		return
	}
	set type          [reqGetArg limit_period]
	set cust_id       [reqGetArg CustId]

	if {[catch {
		set result [ob_srp::set_deposit_limit\
			$cust_id\
			$type\
			$amount\
			-oper_id $USERID\
			-force [OT_CfgGet FORCE_DEP_LIMIT_UPDATE 1]\
		]
	} msg]} {
		ob_log::write ERROR {couldn't update deposit limits $msg}
		err_bind "Couldn't update deposit limits - $msg"
	} else {
		if {[llength $result] > 0 && [lindex $result 0] != 1} {
			set monthly_limit [OT_CfgGet MONTH_DEP_LIMIT_CHNG_PERIOD -1]
			if { $monthly_limit == -1 } {
				set monthly_limit "1 month"
			} else {
				set monthly_limit "$monthly_limit days"
			}
			err_bind "Unable to increase deposit limit. You must wait\
				[OT_CfgGet DAY_DEP_LIMIT_CHNG_PERIOD 7] days (daily limit),\
				[OT_CfgGet WEEK_DEP_LIMIT_CHNG_PERIOD 14] days (weekly limit)\
				and $monthly_limit (monthly limit)\
				 from the date you last set your limit."
		} else {
			msg_bind "Your deposit limit has been successfully updated."
		}
	}
}

#------------------------------------------------------------------------------
# Procedure :   do_cust_self_excl
# Description : Updates the customers self-exclusion
# Input :       cust_id, dep_amt, cust_limit_period
# Output :      none
# Author :      pshah, 05-09-2005
#------------------------------------------------------------------------------
proc do_cust_self_excl args {

	global USERID DB USERNAME

	if {![op_allowed UpdCustSelfExcl]} {
		err_bind "You don't have permission to update the customer self exclusion"
		return
	}
	# Some users have permission to override minimum length and existing limits
	set override "N"
	if {[op_allowed SrpOverrideMin]} {
		set override "Y"
	}

	set cust_id [reqGetArg CustId]
	set excl_period    [reqGetArg excl_period]

	if {[OT_CfgGet SELF_EXCLUSION_BY_DATE 0]} {
		set excl_to_date   [reqGetArg selfexcl_date]
	} else {
		set excl_to_date   ""
	}
	# set self-exclusion by date
	if { $excl_to_date != ""} {
		if {![op_allowed UpdCustSelfExclUntil]} {
			err_bind "You don't have permission to update the customer self exclusion by date"
			return
		}
		foreach {ok msg} [ob_srp::apply_self_excl_until $cust_id $excl_to_date $USERID $override] {}
	} else {
	# self-exclusion by period
		set num_days -1
		if {[catch {

			foreach {value type} [split $excl_period ":"] {}
			set type [string toupper $type]
			switch -- $type {
				"M" {
					set num_days [expr {$value * 30}]
				}
				"Y" {
					set num_days [expr {$value * 365}]
				}
				default {
					ob_log::write ERROR {Unrecognised exclusion type $type}
				}
			}
		} msg]} {
			ob_log::write ERROR {Error parsing exclusion period - $msg}
		}

		# check this is one of the allowed periods
		if {$num_days == -1} {
			err_bind "Unrecognised exclusion period."
			return
		}

		foreach {ok msg} [ob_srp::apply_self_excl $cust_id $num_days $USERID $override] {}
	}
	if {!$ok} {
		if {$msg == "REDUCE_EXCL"} {
			err_bind "You cannot reduce the self exclusion period"
		} elseif {$msg == "EXCL_TO_SMALL"} {
			err_bind "Self exclusion less than 180 days or date wrong: $excl_to_date"
		} else {
			err_bind "Unable to update self exclusion period"
		}
	} else {
		msg_bind "Successfully updated self exclusion period"

		if {[OT_CfgGet FUNC_SELF_EXCL_ENHANCE 0]} {
			# Set Vet Codes
			set vet_code "Closed Social Responsibility"
			set vet_desc "Set Automatically when applying Self-Exclusion"
			_upd_vet_code $cust_id $vet_code $vet_desc

			# Set status to Closed
			set sql {
				execute procedure pUpdCustStatus(
					p_adminuser = ?,
					p_cust_id = ?,
					p_status = ?,
					p_status_reason = ?
				)
			}

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					[reqGetArg CustId]\
					"C"\
					"Self Exclusion"]
				catch {db_close $res}
			} msg]} {
				err_bind "Unable to update customer status and contactable info: $msg"
			}
			inf_close_stmt $stmt

			# Make un-contactable
			set sql {
				update tCustomerReg set
					contact_ok         = 'N',
					ptnr_contact_ok    = 'N',
					mkt_contact_ok     = 'N',
					contact_how        = '',
					good_addr          = 'N',
					good_email         = 'N',
					good_mobile        = 'N'
				where
					cust_id            = ?
			}
			set stmt [inf_prep_sql $DB $sql]
			if {[catch {
				set res [inf_exec_stmt $stmt $cust_id]
				catch {db_close $res}
			} msg]} {
				err_bind "Unable to update customer status and contactable info: $msg"
				ob_log::write ERROR {Unable to update customer status and contactable info: $msg}
			}
			inf_close_stmt $stmt
		}
	}
}

# ----------------------------------------------------------------------------
# Update customer poker transfer limits
# Procedure:    do_cust_poker_limit
# Input:        cust_id
# Output:       none
# Author:       sluke, 11-03-2002
# ----------------------------------------------------------------------------
proc do_cust_poker_limit {} {

	global DB USERID

	set old_max_dep [reqGetArg OLD_POKER_MAX_DEP]
	set old_max_wtd [reqGetArg OLD_POKER_MAX_WTD]
	set cust_id     [reqGetArg CustId]
	set level       [reqGetArg level]
	set old_level   [reqGetArg OLD_POKER_LEVEL]
	set ccy         [reqGetArg ccy]

	if {$level != $old_level} {
		#insert/update flag
		set sql {
			select
				flag_value
			from
				tcustomerflag
			where
				cust_id = ?
				and flag_name = "poker_srp_lev"
		}
		set stmt          [inf_prep_sql $DB $sql]
		set res_poker_srp [inf_exec_stmt $stmt $cust_id]

		inf_close_stmt $stmt

		if {[db_get_nrows $res_poker_srp] == "1"} {
			set sql {
				update
					tcustomerflag
				set
					flag_value = ?
				where
					cust_id = ?
					and flag_name = "poker_srp_lev"
			}
			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt $level $cust_id
			inf_close_stmt $stmt
		} else {
			set sql {
				insert into
					tcustomerflag
					(cust_id, flag_name, flag_value)
				values
					(?, "poker_srp_lev", ?)
			}

			set stmt [inf_prep_sql $DB $sql]

			inf_exec_stmt $stmt $cust_id $level
			inf_close_stmt $stmt
		}
		db_close $res_poker_srp
	}
	# Level is 0,1,2 or 3 - default is 1
	# Get max allowable deposit over 10 days
	# Txn limits may have changed even if level remains same.
	switch $level {

		3 {

			set max_dep [reqGetArg poker_max_dep]
			set max_wtd [reqGetArg poker_max_wtd]
		}

		2 -
		1 {

			set max_dep [convert_to_rounded_ccy [OT_CfgGet MCS_POKER_MAX_DEP_LEV_$level] $ccy]
			set max_wtd [convert_to_rounded_ccy [OT_CfgGet MCS_POKER_MAX_WTD_LEV_$level] $ccy]

		}

		default {

			set max_dep 0
			set max_wtd 0
		}
	}

	#change deposit/withdrawl values
	set sql {
		execute procedure pInsCustLimits
		(
			p_cust_id = ?,
			p_limit_type = ?,
			p_limit_value = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {$max_dep != $old_max_dep} {

		inf_exec_stmt $stmt $cust_id poker_max_dep $max_dep

	}

	if {$max_wtd != $old_max_wtd} {

		inf_exec_stmt $stmt $cust_id poker_max_wtd $max_wtd
	}

	inf_close_stmt $stmt
}

# ----------------------------------------------------------------------------
# Update customer casino transfer limits that have been typed in
# Procedure:    do_cust_type_limit
# Input:        cust_id
# Output:       none
# Author:       sgiles, 28-01-2005
# ----------------------------------------------------------------------------
proc do_cust_type_limit {} {
	global DB USERID
	if {![op_allowed UpdCustLimit]} {
		err_bind "You don't have permission to update customer limits"
		return
	}
	set max_tfr_dep_day [reqGetArg max_tfr_dep_day]
	set max_tfr_wtd_day [reqGetArg max_tfr_wtd_day]
	set srp_frq [reqGetArg SRP_FRQ]
	set cust_id [reqGetArg CustId]

	set sql [subst {
		execute procedure pInsCustLimits
		(
			p_cust_id = ?,
			p_limit_type = 'max_tfr_dep_day',
			p_limit_value = ?,
			p_delay_hrs = 0
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB
	if {[catch {
		inf_exec_stmt $stmt $cust_id $max_tfr_dep_day
	} msg]} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt

	set sql [subst {
		execute procedure pInsCustLimits
		(
			p_cust_id = ?,
			p_limit_type = 'max_tfr_wtd_day',
			p_limit_value = ?,
			p_delay_hrs = 0
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB
	if {[catch {
		inf_exec_stmt $stmt $cust_id $max_tfr_wtd_day
	} msg]} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt

	# update the customer srp frequency
	set_customer_flag $cust_id srp_dep_week $srp_frq
}

proc convert_to_rounded_ccy {amt ccy} {

	global DB

	set exch_sql {
		select round_exch_rate
		from   txgameroundccy
		where  ccy_code = ?
		and    status = 'A'
	}

	set exch_stmt [inf_prep_sql $DB $exch_sql]
	set exch_res  [inf_exec_stmt $exch_stmt $ccy]

	inf_close_stmt $exch_stmt

	if {[db_get_nrows $exch_res] == 1} {

		set exch_rate [db_get_col $exch_res 0 round_exch_rate]

		return [format "%.2f" [expr {$amt * $exch_rate}]]

	} else {

		return -1
	}
}

proc convert_to_ccy {amt ccy} {

	global DB

	set exch_sql {
		select exch_rate
		from   tCCY
		where  ccy_code = ?
		and    status   = 'A'
	}

	set exch_stmt [inf_prep_sql $DB $exch_sql]
	set exch_res  [inf_exec_stmt $exch_stmt $ccy]

	if {[db_get_nrows $exch_res] == 1} {
		set exch_rate [db_get_col $exch_res 0 exch_rate]
		return [format "%.2f" [expr {$amt * $exch_rate}]]
	} else {
		return -1
	}
}


#
# ----------------------------------------------------------------------------
# Customer Credit Limit Usage Search
# ----------------------------------------------------------------------------
#
proc do_crd_search args {

	global DB DATA CRD_SEARCH_ROW

	array set CRD_SEARCH_ROW [list]

	set use_list [reqGetArg UseList]
	if {$use_list=="Y"} {
		set usage [reqGetArg cl_limit]
		set cl [split $usage "-"]
		set lower [lindex $cl 0]
		set upper [lindex $cl 1]
	} else {
		set lower [reqGetArg CL_Lower]
		set upper [reqGetArg CL_Upper]
		if {$lower != ""} {
			set lower [expr {$lower/100.00}]
		}
		if {$upper != ""} {
			set upper [expr {$upper/100.00}]
		}
	}

	set sql {
		select
			c.cust_id,
			c.acct_no,
			c.elite,
			a.acct_id,
			a.balance + a.sum_ap as view_bal,
			a.balance            as true_bal,
			a.credit_limit,
			(ABS(a.balance) / a.credit_limit) as percent_used,
			r.fname,
			r.lname,
			(select
				max(b.cr_date)
			from
				tBet b
			where
				b.acct_id = a.acct_id) as date_last_bet
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r

		where
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			a.owner = 'C' and
			a.balance < 0  and
			a.credit_limit > 0
	}

	set stmt_args ""

	if {$lower != ""} {
		set sql [concat $sql { and (ABS(a.balance) / a.credit_limit) >= ?}]
		append stmt_args $lower
		tpSetVar LowerLim 1
		tpBindString Lower_PC [format %.2f [expr $lower * 100]]
	}
	if {$upper != ""} {
		set sql [concat $sql { and (ABS(a.balance) / a.credit_limit) <= ?}]
		append stmt_args " $upper"
		tpSetVar UpperLim 1
		tpBindString Upper_PC [format %.2f [expr $upper * 100]]
	}

	set sql [concat $sql {order by percent_used desc}]

	set stmt  [inf_prep_sql $DB $sql]
	set res   [eval [concat inf_exec_stmt $stmt $stmt_args]]
	set nrows [db_get_nrows $res]

	inf_close_stmt $stmt

	set num_elite 0

	for {set i 0} {$i < $nrows} {incr i} {

		foreach col [db_get_colnames $res] {
			set CRD_SEARCH_ROW($i,$col) [db_get_col $res $i $col]
		}
		if {[db_get_col $res $i elite] == "Y"} {
			incr num_elite
		}

		#
		# Get any stop codes for this customer
		#
		set sc_sql [subst {
			select
				code, cr_date
			from
				tCustStopCode
			where
				cust_id = $CRD_SEARCH_ROW($i,cust_id)
		}]

		set sc_stmt  [inf_prep_sql $DB $sc_sql]
		set sc_res   [eval [concat inf_exec_stmt $sc_stmt]]
		set sc_nrows [db_get_nrows $sc_res]

		inf_close_stmt $sc_stmt

		if {$sc_nrows > 0} {
			for {set sc 0} {$sc < $sc_nrows} {incr sc} {
				set CRD_SEARCH_ROW($i,$sc,code)    [db_get_col $sc_res $sc code]
				set CRD_SEARCH_ROW($i,$sc,cr_date) [db_get_col $sc_res $sc cr_date]
			}
		}

		set CRD_SEARCH_ROW($i,num_stop_codes) $sc_nrows

		#
		# Get any payments for this customer
		#
		set pmt_sql [subst {
			select
				max(cr_date), amount
			from
				tPmt
			where
				acct_id = $CRD_SEARCH_ROW($i,acct_id)
			group by amount
		}]

		set pmt_stmt  [inf_prep_sql $DB $pmt_sql]
		set pmt_res   [eval [concat inf_exec_stmt $pmt_stmt]]
		set pmt_nrows [db_get_nrows $pmt_res]

		inf_close_stmt $pmt_stmt

		if {$pmt_nrows > 0} {
			set CRD_SEARCH_ROW($i,pmt_amount)    [db_get_coln $pmt_res 0 1]
			set CRD_SEARCH_ROW($i,pmt_cr_date)   [db_get_coln $pmt_res 0 0]
		} else {
			set CRD_SEARCH_ROW($i,pmt_amount)    ""
			set CRD_SEARCH_ROW($i,pmt_cr_date)   ""
		}
	}

	tpSetVar  NumNorm      $nrows
	tpSetVar  NumElite     $num_elite
	tpBindVar Elite         CRD_SEARCH_ROW  elite             cust_idx
	tpBindVar CustId        CRD_SEARCH_ROW  cust_id           cust_idx
	tpBindVar AcctNo        CRD_SEARCH_ROW  acct_no           cust_idx
	tpBindVar VBalance      CRD_SEARCH_ROW  view_bal          cust_idx
	tpBindVar TBalance      CRD_SEARCH_ROW  true_bal          cust_idx
	tpBindVar CreditLimit   CRD_SEARCH_ROW  credit_limit      cust_idx
	tpBindVar RegFName      CRD_SEARCH_ROW  fname             cust_idx
	tpBindVar RegLName      CRD_SEARCH_ROW  lname             cust_idx
	tpBindVar DateLastBet	CRD_SEARCH_ROW  date_last_bet     cust_idx
	tpBindVar DateLastPmt	CRD_SEARCH_ROW  pmt_cr_date       cust_idx
	tpBindVar LastPmtAmount	CRD_SEARCH_ROW  pmt_amount        cust_idx
	tpBindVar StopCode	   CRD_SEARCH_ROW  code              cust_idx  stop_code_idx
	tpBindVar StopCodeDate	CRD_SEARCH_ROW  cr_date           cust_idx  stop_code_idx



	asPlayFile -nocache cust_cr_list.html
}


proc do_cust_stop_code {} {

	global DB USERID

	set action  [reqGetArg SubmitName]
	set cust_id [reqGetArg CustId]

	if {$action == "Back"} {

		go_cust
		return

	} elseif {$action == "AddCode"} {

		set code    [reqGetArg stop_code]

		set sql [subst {
			select
				code
			from
				tCustStopCode
			where
				cust_id = ? and
				code = ?
		}]

		set stmt    [inf_prep_sql $DB $sql]
		set res     [inf_exec_stmt $stmt $cust_id $code]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] == 0} {

			set reason  [reqGetArg stop_reason]

			set sql [subst {
				insert into tCustStopCode
					(
					cust_id,
					oper_id,
					code,
					reason
					)
				values
					(?,?,?,?)
			}]

			set stmt    [inf_prep_sql $DB $sql]
			set res_add [inf_exec_stmt $stmt $cust_id $USERID $code $reason]

			inf_close_stmt $stmt

			db_close $res_add

		} else {
			err_bind "This code is already assigned."
		}

	} elseif {$action == "DeleteCode"} {

		set code    [reqGetArg stop_code]

		set sql [subst {
			delete from
				tCustStopCode
			where
				cust_id = ? and
				code = ?
		}]

		set stmt    [inf_prep_sql $DB $sql]
		set res     [inf_exec_stmt $stmt $cust_id $code]

		inf_close_stmt $stmt

		db_close $res
	}

	set sql [subst {
		select
			stop_code
		from
			tStopCode
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_stop [inf_exec_stmt $stmt $cust_id]

	inf_close_stmt $stmt

	tpSetVar NumStopCodes [db_get_nrows $res_stop]

	tpBindTcl StopCode     sb_res_data $res_stop stop_idx stop_code

	set sql [subst {
		select
			cust_id,
			cr_date,
			code,
			reason
		from
			tCustStopCode
		where
			cust_id = ?
		order by
			cr_date
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_code [inf_exec_stmt $stmt $cust_id]

	inf_close_stmt $stmt

	tpSetVar NumCustStopCodes [db_get_nrows $res_code]

	tpBindTcl CustCode     sb_res_data $res_code code_idx code
	tpBindTcl CustCodeDate sb_res_data $res_code code_idx cr_date
	tpBindTcl CustCodeReas sb_res_data $res_code code_idx reason
	tpBindString CustId $cust_id

	asPlayFile -nocache cust_stop_code.html
}

proc go_cust_stmt {} {

	global DB

	set cust_id 	[reqGetArg CustId]
	tpBindString CustId $cust_id

	#
	# first grab the account id
	#
	set sql [subst {
		select
			acct_id,
			acct_type
		from
			tacct
		where
			cust_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]

	inf_close_stmt $stmt

	set acct_id [db_get_col $res 0 acct_id]
	set acct_type [db_get_col $res 0 acct_type]
	db_close $res


	#
	# Get previous statement information
	#
	set sql [subst {
		select
			date_from,
			date_to,
			stmt_id,
			stmt_num,
			pull_status,
			sort,
			product_filter
		from
			tStmtRecord
		where
			acct_id = ?
		order by
			stmt_num
	}]
	set stmt     [inf_prep_sql $DB $sql]
	set res_prev [inf_exec_stmt $stmt $acct_id]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res_prev]

	tpSetVar STMT_prev_n $nrows

	if {$nrows != 0} {

		tpBindTcl	STMT_prev_stmt_id	   sb_res_data $res_prev st_idx stmt_id
		tpBindTcl	STMT_prev_date_from	   sb_res_data $res_prev st_idx date_from
		tpBindTcl	STMT_prev_date_to	   sb_res_data $res_prev st_idx date_to
		tpBindTcl	STMT_prev_stmt_num     sb_res_data $res_prev st_idx stmt_num
		tpBindTcl	STMT_prev_pull_status  sb_res_data $res_prev st_idx pull_status
		tpBindTcl	STMT_prev_sort         sb_res_data $res_prev st_idx sort
		tpBindTcl	STMT_product_filter    sb_res_data $res_prev st_idx product_filter
	}


		if {[OT_CfgGet STMTS_EFFECTIVE_TO 0]} {
			set effective_to ", pull_to_date"
		} else {
			set effective_to ""
		}

	#
	# now check to find current statement information
	#
	set sql [subst {
		select
			status,
			dlv_method,
			brief,
			freq_amt,
			freq_unit,
			due_from,
			due_to,
			pull_status,
			pull_reason,
			cust_msg_1,
			cust_msg_2,
			cust_msg_3,
			cust_msg_4,
			remove_msg
			$effective_to
		from
			tAcctStmt
		where
			acct_id = ?
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $acct_id]

	inf_close_stmt $stmt

	if {[db_get_nrows $res] == 1} {

		set stmt_on		1
		tpSetVar		STMT_available	1

		tpBindString STMT_dlv_method     [db_get_col $res 0 dlv_method]
		tpBindString STMT_brief          [db_get_col $res 0 brief]
		tpBindString STMT_status         [db_get_col $res 0 status]
		tpBindString STMT_freq_unit      [db_get_col $res 0 freq_unit]
		tpBindString STMT_freq_amt       [db_get_col $res 0 freq_amt]
		tpBindString STMT_due_from       [db_get_col $res 0 due_from]
		tpBindString STMT_due_to         [db_get_col $res 0 due_to]
		tpBindString STMT_pull_status    [db_get_col $res 0 pull_status]
		tpBindString STMT_pull_reason    [db_get_col $res 0 pull_reason]
		tpBindString STMT_cust_msg       "[db_get_col $res 0 cust_msg_1][db_get_col $res 0 cust_msg_2][db_get_col $res 0 cust_msg_3][db_get_col $res 0 cust_msg_4]"
		tpBindString STMT_remove_msg     [db_get_col $res 0 remove_msg]

		if {[OT_CfgGet STMTS_EFFECTIVE_TO 0]} {
			# Get the effective to date
			tpBindString STMT_pull_to     [db_get_col $res 0 pull_to_date]
		}
	} else {
		set stmt_on 0

		tpSetVar STMT_available	0

		tpBindString STMT_freq_unit  "W"
		tpBindString STMT_freq_amt   "2"
		tpBindString STMT_dlv_method "E"

		set current [clock format [tb_statement::tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]

		tpBindString STMT_due_from   $current
		tpBindString STMT_due_to     $current
	}
	db_close $res

	tpBindString STMT_acct_id $acct_id
	tpBindString STMT_acct_type $acct_type

	make_stmt_prod_filter_bind

	asPlayFile -nocache cust_stmt.html

	db_close $res_prev
}



proc do_vet_codes {} {
	global DB

	set act [reqGetArg SubmitName]

	if {$act == "GoVetCode"} {
		show_vet_codes
	} elseif {$act == "UpdVetCode"} {
		upd_vet_code
	}

}

proc upd_vet_code {} {
	set cust_id  [reqGetArg CustId]
	set vet_desc [reqGetArg vet_desc]
	set flag_val [reqGetArg vet_code]
	_upd_vet_code $cust_id $flag_val $vet_desc

	show_vet_codes

}

proc _upd_vet_code {cust_id flag_val vet_desc} {
	global DB

	set sql {
		select
			desc
		from
			tVetCodeDesc
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	set desc_num [db_get_nrows $res]
	db_close $res

	set sql_insert {
		insert into
			tVetCodeDesc
		(cust_id, desc)
			values
		(?,?)
	}

	set sql_update {
		update
			tVetCodeDesc
		set
			desc    = ?
		where
			cust_id = ?
	}

	set sql_delete {
		delete from
			tVetCodeDesc
		where
			cust_id = ?
	}

	set stmt_del [inf_prep_sql $DB $sql_delete]
	set stmt_ins [inf_prep_sql $DB $sql_insert]
	set stmt_upd [inf_prep_sql $DB $sql_update]

	if {$desc_num > 0} {
		if {[string length $vet_desc]} {
			db_close [inf_exec_stmt $stmt_upd $vet_desc $cust_id]
		} else {
			#If no description and there was one delete
			db_close [inf_exec_stmt $stmt_del $cust_id]
		}
	} else {
		if {[string length $vet_desc]} {
			db_close [inf_exec_stmt $stmt_ins $cust_id $vet_desc]
		}
	}

	set sql_flag {
		select
			flag_value
		from
			tCustomerFlag
		where
			cust_id = ?
			and flag_name = 'Vet Codes'
	}

	set stmt_code [inf_prep_sql $DB $sql_flag]
	set rs        [inf_exec_stmt $stmt_code $cust_id]
	set flag_set  [db_get_nrows $rs]

	set sql_flag_ins {
		insert
			into tCustomerFlag
			(cust_id, flag_value,flag_name)
		values
			(?,?,?)
	}

	set sql_flag_upd [subst {
		execute procedure pUpdCustFlag
		(
			p_cust_id	=?,
			p_flag_name	=?,
			p_flag_value	=?
		)
	}]

	set sql_flag_del {
		delete from
			tCustomerFlag
		where
			cust_id = ?
			and flag_name = ?
	}

	set stmt_flag_upd [inf_prep_sql $DB $sql_flag_upd]
	set stmt_flag_del [inf_prep_sql $DB $sql_flag_del]

	if {$flag_set} {
		if {[string length $flag_val] > 1} {
			db_close [inf_exec_stmt $stmt_flag_upd $cust_id "Vet Codes" $flag_val]
		} else {
			db_close [inf_exec_stmt $stmt_flag_del $cust_id "Vet Codes"]
		}
	} else {
		if {[string length $flag_val] > 1} {
			db_close [inf_exec_stmt $stmt_flag_upd $cust_id "Vet Codes" $flag_val]
		}
	}

	show_vet_codes
}


# Show Vet Codes page
proc show_vet_codes {} {
	global DB VET_CODES

	set cust_id [reqGetArg CustId]

	set sql {
		select
			flag_value,
			description
		from
			tCustFlagVal
		where
			flag_name = 'Vet Codes'
	}

	set stmt [inf_prep_sql $DB $sql]
	set res_flags  [inf_exec_stmt $stmt]

	set num_flags [db_get_nrows $res_flags]

	for {set i 0} {$i < $num_flags} {incr i} {
		set VET_CODES($i,flag_value) [db_get_col $res_flags $i flag_value]
		set VET_CODES($i,description) [db_get_col $res_flags $i description]
	}

	tpBindVar flag_value  VET_CODES flag_value fg_idx
	tpBindVar description VET_CODES  description fg_idx
	tpSetVar NumFlags $num_flags

	set sql {
		select
			flag_value
		from
			tCustomerFlag
		where
			cust_id = ?
			and	(flag_name = 'Vet Codes')
	}

	set stmt     [inf_prep_sql $DB $sql]
	set res_flag [inf_exec_stmt $stmt $cust_id]

	set sql_desc {
		select
			desc
		from
			tVetCodeDesc
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql_desc]
	set res_desc  [inf_exec_stmt $stmt $cust_id]

	tpBindString CustId $cust_id

	if {[db_get_nrows $res_flag]} {
		tpSetVar flag_val [db_get_col $res_flag 0 flag_value]
	} else {
		tpSetVar flag_val 0
	}

	if {[db_get_nrows $res_desc]} {
		tpBindString flag_desc [db_get_col $res_desc 0 desc]
	} else {
		tpBindString flag_desc ""
	}

	asPlayFile -nocache cust_vet_codes.html
	db_close $res_desc
	db_close $res_flag
	db_close $res_flags
	unset VET_CODES

}



proc do_cust_stmt {} {

	global DB CHARSET

	set play_html 1
	set act [reqGetArg SubmitName]
	if {$act == "Back"} {
		go_cust
		return

	} elseif {$act == "DelStmt"} {

		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		if [catch {tb_statement::tb_stmt_del [reqGetArg acct_id]} msg] {
			err_bind "Couldn't delete statement: $msg"
		} else {
			msg_bind "Statement deleted"
		}

	} elseif {$act == "AddStmt"} {

		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		set acct_id 		[reqGetArg acct_id]
		set acct_type       [reqGetArg acct_type]
		set freq_unit		[reqGetArg freq_unit]
		set freq_amt		[reqGetArg freq_amt]
		set due_from		[reqGetArg due_from]
		set due_to			[reqGetArg due_to]
		set status			[reqGetArg status]

		if {[OT_CfgGet STATEMENT_DELIVERY_CHOOSE 1]} {
			set dlv_method    [reqGetArg dlv_method]
		} else {
			set dlv_method    P
		}

		if {[OT_CfgGet STATEMENT_BRIEF_CHOOSE 1]} {
			set brief         [reqGetArg brief]
		} else {
			set brief         N
		}

		if {[reqGetArg enforce_period] == "Y"} {
			set enforce_period 1
		} else {
			set enforce_period 0
		}

		if {[catch {
			tb_statement::tb_stmt_add \
				$acct_id \
				$freq_unit \
				$freq_amt \
				$due_from \
				$due_to \
				$dlv_method \
				$brief \
				$enforce_period \
				$acct_type
		} msg]} {
			err_bind "Could not add statement information: $msg"
		} else {
			msg_bind "Statement added successfully"
		}

	} elseif {$act == "UpdStmt" || $act == "UpdPulled" || $act == "UpdFreq"} {
		set updStmt 1
		set updPull 1
		set overide 1

		switch $act {
			UpdPulled {
				set updStmt 0
			}
			UpdFreq {
				set updPull 0
			}
		}

		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		set acct_id         [reqGetArg acct_id]
		set acct_type       [reqGetArg acct_type]
		set freq_unit       [reqGetArg freq_unit]
		set freq_amt        [reqGetArg freq_amt]
		set due_from        [reqGetArg due_from]
		set due_to          [reqGetArg due_to]
		set status          [reqGetArg status]
		set pull_status     [reqGetArg pull_status]
		set pull_reason     [reqGetArg pull_reason]
		set cust_msg        [reqGetArg cust_msg]
		set remove_msg      [reqGetArg remove_msg]


		if {[OT_CfgGet STATEMENT_DELIVERY_CHOOSE 1]} {
			set dlv_method    [reqGetArg dlv_method]
		} else {
			set dlv_method    P
		}

		if {[OT_CfgGet STATEMENT_BRIEF_CHOOSE 1]} {
			set brief         [reqGetArg brief]
		} else {
			set brief         N
		}

		ob_log::write ERROR {$acct_type}

		if {$pull_status == "T"} {
			set pull_to_date    [reqGetArg effectiveTo]
		} else {
			set pull_to_date ""
		}

		set cust_msg_1  [string range $cust_msg 0 255]
		set cust_msg_2  [string range $cust_msg 255 510]
		set cust_msg_3  [string range $cust_msg 510 765]
		set cust_msg_4  [string range $cust_msg 765 1020]


		if {$brief != "Y"} {
			set brief N
		}
		if {[reqGetArg enforce_period] == "Y"} {
			set enforce_period 1
		} else {
			set enforce_period 0
		}

		inf_begin_tran $DB

		if {$updStmt} {
			if {[catch {
				tb_statement::tb_stmt_upd $acct_id \
				$freq_unit \
				$freq_amt \
				$due_from \
				$due_to \
				$status \
				$dlv_method \
				$brief \
				$enforce_period \
				$acct_type \
				$overide
			} msg]} {
				inf_rollback_tran $DB
				err_bind "Could not update statement: $msg"
			} else {
				msg_bind "Statement updated"
			}
		}

		if {$updPull} {
			if {[catch {
				tb_statement::tb_stmt_upd_ext $acct_id \
					$pull_status \
					$pull_reason \
					$cust_msg_1 \
					$cust_msg_2 \
					$cust_msg_3 \
					$cust_msg_4 \
					$remove_msg
			} msg]} {
				inf_rollback_tran $DB
				err_bind "Could not update statement: $msg"
			} else {
				msg_bind "Statement updated"
			}
		}


		if {$updPull && [OT_CfgGet STMTS_EFFECTIVE_TO 0]} {
			tb_statement::tb_stmt_effective_to $acct_id \
				$pull_to_date
		}

		inf_commit_tran $DB

	} elseif {$act == "GenStmt"} {
		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		#
		# generate the statement
		#
		set c [catch {
			array set DATA ""

			set DATA(hdr,acct_id)        [reqGetArg acct_id]
			set DATA(hdr,dlv_method)     [reqGetArg oo_dlv_method]
			set DATA(hdr,brief)          [reqGetArg oo_brief]
			set DATA(hdr,pmt_amount)     [reqGetArg oo_pmt_amount]
			set DATA(hdr,pmt_method)     [reqGetArg oo_pmt_method]
			set DATA(hdr,pmt_desc)       [reqGetArg oo_pmt_desc]
			set DATA(hdr,pull_status)    [reqGetArg oo_pull_status]
			set DATA(hdr,pull_reason)    [reqGetArg oo_pull_reason]
			set DATA(hdr,product_filter) [reqGetArg product_filter]

			if {[OT_CfgGet STATEMENT_DELIVERY_CHOOSE 1]} {
				set DATA(hdr,dlv_method)    [reqGetArg oo_dlv_method]
			} else {
				set DATA(hdr,dlv_method)    P
			}

			if {[OT_CfgGet STATEMENT_BRIEF_CHOOSE 1]} {
				set DATA(hdr,brief)        [reqGetArg brief]
			} else {
				set DATA(hdr,brief)        N
			}

			set msg [reqGetArg oo_cust_msg]
			set DATA(hdr,cust_msg_1)  [string range $msg 0 255]
			set DATA(hdr,cust_msg_2)  [string range $msg 256 511]
			set DATA(hdr,cust_msg_3)  [string range $msg 512 767]
			set DATA(hdr,cust_msg_4)  [string range $msg 768 1023]

			# Date range
			set date_type [reqGetArg date_type]
			switch -exact $date_type {
				"T" {
					# Today
					set DATA(hdr,due_from) [clock format [clock seconds] -format "%Y-%m-%d"]
					set DATA(hdr,due_to)   [clock format [clock seconds] -format "%Y-%m-%d"]
				}
				"Y" {
					set DATA(hdr,due_from) [clock format [clock scan "yesterday"] -format "%Y-%m-%d"]
					set DATA(hdr,due_to)   [clock format [clock scan "yesterday"] -format "%Y-%m-%d"]
				}
				"7" {
					set DATA(hdr,due_from) [clock format [clock scan "6 days ago"] -format "%Y-%m-%d"]
					set DATA(hdr,due_to)   [clock format [clock seconds] -format "%Y-%m-%d"]
				}
				"C" {
					set DATA(hdr,due_from)       [reqGetArg oo_due_from]
					set DATA(hdr,due_to)         [reqGetArg oo_due_to]
				}
			}

			if {[regexp ^(....)-(..)-(..)$ [string trim $DATA(hdr,due_from)]]} {
				set DATA(hdr,due_from) "[string trim $DATA(hdr,due_from)] 00:00:00"
			}
			if {[regexp ^(....)-(..)-(..)$ [string trim $DATA(hdr,due_to)]]} {
				set DATA(hdr,due_to) "[string trim $DATA(hdr,due_to)] 23:59:59"
			}

			set DATA(hdr,sort)       "A"
			set DATA(hdr,printed)    "Y"
			set DATA(hdr,stmt_num)   [expr [tb_statement::tb_stmt_count $DATA(hdr,acct_id)] + 1]

			#
			# record_stmt
			#
			tb_statement::insert_stmt_record DATA

			unset DATA
		} msg]

		if {$c} {
			err_bind "Could not generate statement: $msg"
		} else {
			msg_bind "Statement generated successfully"
		}
	} elseif {$act == "DeleteStmtRecord"} {

		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		global DB

		#
		# delete a statement record
		#
		set stmt_id [reqGetArg stmt_id]

		set c [catch {

			set sql {
				delete from tStmtRecord
				where
					stmt_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt $stmt_id
			inf_close_stmt $stmt
		} msg]

		if {$c} {
			err_bind "Could not delete statement: $msg"
		} else {
			msg_bind "Statement deleted"
		}

	} elseif {$act == "UpdatePrevStmt"} {

		if {![op_allowed UpdStmts]} {
			err_bind "You do not have permission to modify statements."
			go_cust_stmt
			return
		}

		global DB

		inf_begin_tran $DB

		set c [catch {
			set n_prev_stmts [reqGetArg n_prev_stmts]

			set sql {
				update tStmtRecord
				set pull_status = ?
				where stmt_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]

			for {set i 0} {$i < $n_prev_stmts} {incr i} {

				set stmt_id [reqGetArg stmt_id_${i}]
				set pull_status [reqGetArg prev_pull_stmt_${stmt_id}]
				inf_exec_stmt $stmt $pull_status $stmt_id
			}
			inf_close_stmt $stmt
		} msg]

		if {!$c} {
			msg_bind "Update OK"
			inf_commit_tran $DB
		} else {
			err_bind "Update failed: $msg"
			inf_rollback_tran $DB
		}

	} elseif {$act == "GeneratePrev" || $act == "ExportPDF"} {

		if {![op_allowed GenStmts]} {
			err_bind "You do not have permission to generate statements."
			go_cust_stmt
			return
		}

		set c [catch {

			set stmt_id [reqGetArg stmt_id]
			set cust_id [reqGetArg CustId]

			#
			# generate the req'd information
			#
			array set DATA ""
			tb_statement_build::get_stmt_data $stmt_id DATA

			#
			# where shall we write the file? Need to see if this is an elite customer
			#
			set sql {
				select c.elite
				from   tcustomer c
				where  c.cust_id = ?
			}
			set stmt [inf_prep_sql $DB $sql]
			set rs [inf_exec_stmt $stmt $cust_id]

			set is_elite [db_get_col $rs 0 elite]

			inf_close_stmt $stmt
			db_close $rs
			#
			# Form the filename
			#
			set filename [generate_stmt_fname $DATA(hdr,acct_type) $DATA(hdr,due_to) $DATA(hdr,acct_no) $stmt_id $is_elite ps]

			#
			# open the file (for statement generation)
			#
			set f_id [open "$filename" w]
			fconfigure $f_id -encoding [OT_CfgGet STATEMENTS_CHARSET iso8859-1]

			#
			# If we are writing a postscript statement then we want to write
			# the postscript functions to the top of the file first
			#
			if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {
				::tb_statement_build::init_ps_output $f_id 1
			}

			#
			# write the data
			#
			tb_statement_build::write_stmt_to_file $f_id DATA

			#
			# If using postscript we need to add a final command to the bottom
			#
			if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {
				puts $f_id "showpage"
			}

			close $f_id


			if {[OT_CfgGet CONVERT_PS_STMTS_TO_PDF 0]} {
				set pdf_filename [generate_stmt_fname $DATA(hdr,acct_type) $DATA(hdr,due_to) $DATA(hdr,acct_no) $stmt_id $is_elite pdf]

				exec ps2pdf $filename $pdf_filename
				play_pdf $pdf_filename

				# delete files from the filesystem. we made sure that these are unique per run.
				exec rm $filename
				exec rm $pdf_filename

				set play_html 0
				OT_LogWrite 1 "Succesfully played PDF file"
			}
		} msg]

		if {$c} {

			#
			# remove the generated file
			#
			catch {file delete $filename}
			err_bind "Statement generation failed: $msg"
			set play_html 1
			# re-add html content-type because it was deleted to play the pdf file.
			catch {tpBufDelHdr "Content-Type"}
			tpBufAddHdr   "Content-Type"  "text/html; charset=$CHARSET"
		} else {
			msg_bind "Statement generation successful"
		}
	} else {
		error "action undefined"
	}

	if {$play_html} {
		go_cust_stmt
	}
	return
}

#
# returns the name of a statement output file based upon
# config parameters STATEMENT_DIR STATEMENT_FNAME TIME_FORMAT
# (and ELITE_STATMENT_DIR if is_elite == Y)
#
proc generate_stmt_fname {acct_type date acct_no stmt_no {is_elite "N"} {xtn ps}} {

	global USERID

	set date [clock format [clock scan $date] -format [OT_CfgGet TIME_FORMAT_STMT "%Y-%m-%d-%H:%M:-%S"]]
	set now  [clock format [clock seconds] -format [OT_CfgGet TIME_FORMAT_STMT "%Y%m%d%H%M%S"]]

	set add_xtn 0
	if {[OT_CfgGet POSTSCRIPT_STMTS 0]} {
		set stmt_fname [OT_CfgGet PS_STATEMENT_FNAME "%N-%D-%S.ps"]
		if {[OT_CfgGet PS_STATEMENT_FNAME] != ""} {
			set add_xtn 1
		}
	} else {
		set stmt_fname [OT_CfgGet STATEMENT_FNAME "%N-%D-%S.csv"]
	}

	set fmt_length [string length $stmt_fname]
	set res ""

	if {$is_elite == "Y"} {
		set stmt_dir [OT_CfgGet ELITE_STATEMENT_DIR [OT_CfgGet STATEMENT_DIR]]
	} else {
		set stmt_dir [OT_CfgGet STATEMENT_DIR]
	}

	for {set i 0} {$i < $fmt_length} {incr i} {
		set ch [string index $stmt_fname $i]

		if {$ch == " "} {
			continue
		} elseif {$ch != "%"} {
			append res $ch
		} else {
			# naughty modification of loop variable
			incr i

			# ... but at least I check if it's broken
			if {$i >= $fmt_length} {
				break
			}
			set ch [string index $stmt_fname $i]
			switch -- $ch {
				D {
					append res $date
				}
				T {
					append res $acct_type
				}
				N {
					append res $acct_no
				}
				U {
					append res $USERID
				}
				C {
					append res $now
				}
				S {
					append res $stmt_no
				}
			}
		}
	}

	if {$add_xtn} {
		append res ".${xtn}"
	}

	# arbitrary safety check: if something has gone wrong at least it will be obvious
	if {[string length $res] < 3} {
		set res "DEFAULT_STMT_NAME_$acct_no"
	}

	regsub -all { } $res {-} res

	return $res

}

proc do_stmt_detail {} {

	global DB
	global STMT_DATA

	set action [reqGetArg SubmitName]
	if {$action == "Back"} {
		go_cust_stmt
		return
	}

	#
	# display a full customers statement in html - arghhhhhhhh....
	#
	set stmt_id [reqGetArg stmt_id]
	set cust_id [reqGetArg CustId]

	set c [catch {
		tb_statement_build::get_stmt_data $stmt_id STMT_DATA
	} msg]

	if {$c} {

		#
		# statement generation failed
		#
		err_bind "Failed to generate statement: $msg"
		go_cust_stmt
		return

	}

	#
	# Bind up the variables and play the template
	#

	# the header
	foreach f {acct_type acct_no username title fname lname addr_street_1 addr_street_2 \
				addr_street_3 addr_street_4 addr_city addr_postcode country_name \
				due_from due_to open_bal close_bal ccy_code credit_limit dlv_method \
				stmt_num cust_msg cust_code stakes_os} {
		tpBindString STMT_${f} $STMT_DATA(hdr,$f)
	}


	# the body
	tpSetVar NumTxns $STMT_DATA(bdy,num_txns)
	tpSetVar bdy_idx bdy

	tpBindVar STMT_date           STMT_DATA  cr_date        bdy_idx ln_idx
	tpBindVar STMT_channel        STMT_DATA  channel        bdy_idx ln_idx
	tpBindVar STMT_bet_type       STMT_DATA  bet_type       bdy_idx ln_idx
	tpBindVar STMT_receipt        STMT_DATA  receipt        bdy_idx ln_idx
	tpBindVar STMT_num_lines      STMT_DATA  num_lines      bdy_idx ln_idx
	tpBindVar STMT_tax_type       STMT_DATA  tax_type       bdy_idx ln_idx
	tpBindVar STMT_num_lines_void STMT_DATA  num_lines_void bdy_idx ln_idx
	tpBindVar STMT_num_lines_win  STMT_DATA  num_lines_win  bdy_idx ln_idx
	tpBindVar STMT_num_lines_lose STMT_DATA  num_lines_lose bdy_idx ln_idx
	tpBindVar STMT_paid           STMT_DATA  paid           bdy_idx ln_idx
	tpBindVar STMT_ap             STMT_DATA  ap             bdy_idx ln_idx
	tpBindVar STMT_bet_id         STMT_DATA  bet_id         bdy_idx ln_idx
	tpBindVar STMT_stake          STMT_DATA  stake          bdy_idx ln_idx
	tpBindVar STMT_token_value    STMT_DATA  token_value    bdy_idx ln_idx
	tpBindVar STMT_returns        STMT_DATA  returns        bdy_idx ln_idx
	tpBindVar STMT_credit         STMT_DATA  dep            bdy_idx ln_idx
	tpBindVar STMT_debit          STMT_DATA  wtd            bdy_idx ln_idx
	tpBindVar STMT_balance        STMT_DATA  balance        bdy_idx ln_idx
	tpBindVar STMT_leg_type       STMT_DATA  leg_type       bdy_idx ln_idx

	tpBindVar STMT_desc        STMT_DATA  desc       bdy_idx ln_idx pt_idx
	tpBindVar STMT_oc_name     STMT_DATA  oc_name    bdy_idx ln_idx pt_idx
	tpBindVar STMT_ev_name     STMT_DATA  ev_name    bdy_idx ln_idx pt_idx
	tpBindVar STMT_leg_sort    STMT_DATA  leg_sort   bdy_idx ln_idx pt_idx
	tpBindVar STMT_price_type  STMT_DATA  price_type bdy_idx ln_idx pt_idx
	tpBindVar STMT_price       STMT_DATA  price      bdy_idx ln_idx pt_idx
	tpBindVar STMT_hcap_value  STMT_DATA  hcap_value bdy_idx ln_idx pt_idx
	tpBindVar STMT_rule4       STMT_DATA  rule4      bdy_idx ln_idx pt_idx

	# the footer
	if {$STMT_DATA(hdr,acct_type) == "CDT"} {
		foreach f {pmt_amount_abs pmt_method pmt_desc pmt_type} {
			tpBindString STMT_${f} $STMT_DATA(hdr,$f)
		}

		tpSetVar numAP $STMT_DATA(ftr,num_ap)

		tpSetVar ftr_idx ftr
		tpBindVar STMT_ftr_date     STMT_DATA  cr_date    ftr_idx ln_idx
		tpBindVar STMT_ftr_channel  STMT_DATA  channel    ftr_idx ln_idx
		tpBindVar STMT_ftr_bet_type STMT_DATA  bet_type   ftr_idx ln_idx
		tpBindVar STMT_ftr_receipt  STMT_DATA  receipt    ftr_idx ln_idx
		tpBindVar STMT_ftr_stake    STMT_DATA  stake      ftr_idx ln_idx
		tpBindVar STMT_ftr_oc_name  STMT_DATA  oc_name    ftr_idx ln_idx pt_idx
		tpBindVar STMT_ftr_ev_name  STMT_DATA  ev_name    ftr_idx ln_idx pt_idx
		tpBindVar STMT_ftr_desc     STMT_DATA  desc       ftr_idx ln_idx pt_idx
	}


	# other stuff
	tpSetVar     acct_type $STMT_DATA(hdr,acct_type)
	tpBindString acct_id   $STMT_DATA(hdr,acct_id)
	tpBindString CustId    $cust_id


	asPlayFile -nocache stmt_detail.html

	unset STMT_DATA
}



#
# ----------------------------------------------------------------------------
# Customer account status history
# ----------------------------------------------------------------------------
#
proc go_cust_status_hist args {

	global DB DATA

	set cust_id [reqGetArg CustId]
	set where "and c.cust_id = $cust_id"

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.acct_no,
			c.status c_status,
			l.cust_status_id,
			l.status l_status,
			l.reason,
			l.cr_date,
			a.username admin_user
		from
			tCustStatusLog l,
			tCustomer c,
			outer tAdminUser a
		where
			l.cust_id = c.cust_id and
			l.user_id = a.user_id
			$where
		order by
			cust_status_id desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumRows [set rows [db_get_nrows $res]]

	array set DATA [list]

	for {set r 0} {$r < $rows} {incr r} {
		set DATA($r,acct_no) [acct_no_enc [db_get_col $res $r acct_no]]
		set DATA($r,susp)    [expr {[db_get_col $res $r l_status]=="A"?0:1}]
	}

	tpBindVar AcctNo     DATA acct_no cust_idx

	tpBindTcl CustId     sb_res_data $res cust_idx cust_id
	tpBindTcl Username   sb_res_data $res cust_idx username
	tpBindTcl CurStatus  sb_res_data $res cust_idx c_status
	tpBindTcl LogStatus  sb_res_data $res cust_idx l_status
	tpBindTcl Time       sb_res_data $res cust_idx cr_date
	tpBindTcl Reason     sb_res_data $res cust_idx reason
	tpBindTcl AdminUser  sb_res_data $res cust_idx admin_user

	asPlayFile -nocache cust_status.html

	db_close $res
	unset DATA
}



#
# ----------------------------------------------------------------------------
# Customer Exclusions actions
# ----------------------------------------------------------------------------
#
proc do_chan_sys_exclusions args {

	set act [reqGetArg SubmitName]

	ob_log::write INFO $act

	switch -- $act {
		"AddSysExclusion" {
			add_sys_exclusion
			return
		}
		"AddChanExclusion" {
			add_chan_exclusion
			return
		}
		"DelSysExclusion" {
			del_sys_exclusion
			return
		}
		"DelChanExclusion" {
			del_chan_exclusion
			return
		}
		"GoBack" {
			go_cust
			return
		}
	}
}



# ----------------------------------------------------------------------------
# View the customer channel/external system exclusions
# ----------------------------------------------------------------------------
proc go_chan_sys_exclusions args {
	global DB

	set cust_id [reqGetArg CustId]

	set sql {
		select
			s.desc,
			e.group_id
		from
			tCustSysExcl e,
			tXSysHostGrp s
		where
			e.group_id = s.group_id
			and e.cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set num [db_get_nrows $res]

	tpSetVar NumExcl [db_get_nrows $res]
	tpBindTcl excl_id   sb_res_data $res excl_idx group_id
	tpBindTcl excl_desc sb_res_data $res excl_idx desc

	set sql {
		select
			s.desc,
			s.group_id
		from
			txSysHostGrp s
		where
			s.type = 'SYS'
			and
				s.group_id not in
					(
						select group_id
							from tCustSysExcl where cust_id = ?
					)
	}

	set stmt [inf_prep_sql $DB $sql]
	set res2  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	tpSetVar NumSys [db_get_nrows $res2]
	tpBindTcl sys_desc sb_res_data $res2 sys_idx desc
	tpBindTcl sys_id   sb_res_data $res2 sys_idx group_id

	set sql {
		select
			e.channel_id,
			c.desc
		from
			tCustChanExcl e,
			tChannel c
		where
			e.channel_id = c.channel_id
			and e.cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res3  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set num [db_get_nrows $res3]

	tpSetVar NumChanExcl [db_get_nrows $res3]
	tpBindTcl chan_excl_id   sb_res_data $res3 chan_excl_idx channel_id
	tpBindTcl chan_excl_desc sb_res_data $res3 chan_excl_idx desc

	set sql {
		select
			c.channel_id,
			c.desc
		from
			tChannel c
		where
			c.channel_id not in
					(
						select channel_id
							from tCustChanExcl where cust_id = ?
					)
	}

	set stmt [inf_prep_sql $DB $sql]
	set res4  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	tpSetVar NumChan [db_get_nrows $res4]
	tpBindTcl chan_desc sb_res_data $res4 chan_idx desc
	tpBindTcl chan_id   sb_res_data $res4 chan_idx channel_id

	tpBindString CustId $cust_id

	asPlayFile -nocache cust_exclusions.html
}



# ----------------------------------------------------------------------------
# Add a new customer system exclusion
# ----------------------------------------------------------------------------
proc add_sys_exclusion args {
	global DB

	if {![op_allowed PerSystemExcl]} {
		err_bind "You don't have permission to update customer exclusions"
		go_cust
	}

	set cust_id  [reqGetArg CustId]
	set group_id [reqGetArg Systems]

	set sql {
		insert into tCustSysExcl (
			cust_id, group_id)
		values (
			? , ?)
	}

	set stmt_ins [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt_ins $cust_id $group_id

	inf_close_stmt $stmt_ins
	go_chan_sys_exclusions
}



# ----------------------------------------------------------------------------
# Add a new customer channel exclusion
# ----------------------------------------------------------------------------
proc add_chan_exclusion args {
	global DB

	if {![op_allowed PerSystemExcl]} {
		err_bind "You don't have permission to update customer exclusions"
		go_cust
	}

	set cust_id  [reqGetArg CustId]
	set channel_id [reqGetArg Channels]

	set sql {
		insert into tCustChanExcl (
			cust_id, channel_id)
		values (
			? , ?)
	}

	set stmt_ins [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt_ins $cust_id $channel_id

	inf_close_stmt $stmt_ins
	go_chan_sys_exclusions
}



# ----------------------------------------------------------------------------
# Remove a customer system exclusion
# ----------------------------------------------------------------------------
proc del_sys_exclusion args {
	global DB

	if {![op_allowed PerSystemExcl]} {
		err_bind "You don't have permission to update customer exclusions"
		go_cust
	}

	set cust_id [reqGetArg CustId]
	set systems [reqGetArg CurrentSystems]
	set systemList  [split $systems |]
	set where [list]

	foreach sys $systemList {
		set id "Excl${sys}"
		set groups ""

		if {[reqGetArg $id]!= ""} {
			lappend where " group_id = $sys"
		}
	}

	if {[llength $where]} {
		set where "and ([join $where { or }])"

		set sql [subst {
			delete from
    			tCustSysExcl
			where
				cust_id = $cust_id $where
		}]

		set stmt_del [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt_del
		inf_close_stmt $stmt_del
	}

	go_chan_sys_exclusions
}



# ----------------------------------------------------------------------------
# Remove a customer channel exclusion
# ----------------------------------------------------------------------------
proc del_chan_exclusion args {
	global DB

	if {![op_allowed PerSystemExcl]} {
		err_bind "You don't have permission to update customer exclusions"
		go_cust
	}

	set cust_id [reqGetArg CustId]
	set channels [reqGetArg CurrentChannels]
	set channelList  [split $channels |]
	set where [list]

	foreach chan $channelList {
		set id "ChanExcl${chan}"
		set groups ""

		if {[reqGetArg $id]!= ""} {
			lappend where " channel_id = '$chan'"
		}
	}

	if {[llength $where]} {
		set where "and ([join $where { or }])"

		set sql [subst {
			delete from
    			tCustChanExcl
			where
				cust_id = $cust_id $where
		}]

		set stmt_del [inf_prep_sql $DB $sql]
		inf_exec_stmt $stmt_del
		inf_close_stmt $stmt_del
	}

	go_chan_sys_exclusions
}



# ----------------------------------------------------------------------------
# View the customer flags section
# ----------------------------------------------------------------------------
proc go_cust_flags args {

	global DB FLAGS

	set cust_id [reqGetArg CustId]

	set sql [subst {
		select unique
			case when c.cust_id is not null then 1 else 0 end
				as selected,
			f.flag_name,
			f.flag_value,
			d.description,
			d.note,
			0 as tbox
		from
			outer tCustomerFlag c,
			tCustFlagVal f,
			tCustFlagDesc d
		where
			c.cust_id = ? and
			f.flag_name = c.flag_name and
			f.flag_value = c.flag_value and
			d.flag_name = f.flag_name and
			d.status = 'A'
		union
		select unique
			case when c.cust_id is not null then 1 else 0 end
				as selected,
			c.flag_name,
			c.flag_value,
			d.description,
			d.note,
			0 as tbox
		from
			tCustomerFlag c,
			tCustFlagDesc d
		where
			c.cust_id = ? and
			d.flag_name = c.flag_name and
			d.status = 'A'
		union
		select unique
			0 as selected,
			d.flag_name,
			"" as flag_value,
			d.description,
			d.note,
			1 as tbox
		from
			tCustFlagDesc d
		where
			d.flag_name not in (
				select flag_name from tcustflagval
			) and d.status='A'
		order by flag_name, flag_value
	}]

	set stmt      [inf_prep_sql $DB $sql]
	set res       [inf_exec_stmt $stmt $cust_id $cust_id]
	set num_flags [db_get_nrows $res]

	inf_close_stmt $stmt

	set fg_count -1
	set fv_count 0
	set curr_flag_name ""
	array set FLAGS [list num_flags 0]
	for {set i 0} {$i<$num_flags} {incr i} {

		set flag_name	[db_get_col $res $i flag_name]
		set description	[db_get_col $res $i description]
		set note		[db_get_col $res $i note]
		set selected	[db_get_col $res $i selected]
		set flag_value 	[db_get_col $res $i flag_value]
		set tbox	[db_get_col $res $i tbox]

		# Only offer this flag if the admin has the correct perm.
		if {$flag_name == "SkipIPCheck" && ![op_allowed "OverrideIPCheck"]} {
			continue
		}

		if {$flag_name == "MoveToDebtState" && ![op_allowed "MoveToDebtStateCheck"]} {
			continue
		}

		if {![string equal $curr_flag_name $flag_name]} {
			set curr_flag_name $flag_name
			incr FLAGS(num_flags)
			incr fg_count

			set fv_count 0
			set FLAGS($fg_count,is_set) 		0
			set FLAGS($fg_count,flag_name) 		$flag_name
			set FLAGS($fg_count,description) 	$description
			set FLAGS($fg_count,note)		$note
			set FLAGS($fg_count,tbox)		$tbox
		}

		if {$tbox} {
			set FLAGS($fg_count,tbox)	1
		} else {

			if {$FLAGS($fg_count,is_set) == 0 && $flag_value == "reset"} {
				continue
			}
			set FLAGS($fg_count,$fv_count,flag_value) 	$flag_value
			set FLAGS($fg_count,$fv_count,selected) 	$selected
			if {$selected} {
				set FLAGS($fg_count,is_set) 1
			}
			incr fv_count
			set FLAGS($fg_count,num_values) $fv_count
		}
	}

	#Loop through and add unset options where necessary
	for {set i 0} {$i < $FLAGS(num_flags)} {incr i} {

		if { ! $FLAGS($i,is_set) } {
			set vval "unset"
			if {$FLAGS($i,tbox)} {
				set vval ""
				set FLAGS($i,num_values) 	1
			}
			set FLAGS($i,$FLAGS($i,num_values),flag_value) 	$vval
			set FLAGS($i,$FLAGS($i,num_values),selected) 	1
			incr FLAGS($i,num_values)
		}

	}

	tpBindVar flag_name 	FLAGS 	flag_name 	fg_idx
	tpBindVar description	FLAGS 	description	fg_idx
	tpBindVar note		FLAGS 	note		fg_idx
	tpBindVar tbox		FLAGS	tbox		fg_idx
	tpBindVar flag_value	FLAGS 	flag_value 	fg_idx	fv_idx
	tpBindVar selected	FLAGS 	selected 	fg_idx 	fv_idx

	tpBindString CustId $cust_id
	asPlayFile -nocache cust_flags.html

	unset FLAGS

}

# ----------------------------------------------------------------------------
# Update the customer flags section
# ----------------------------------------------------------------------------
proc do_upd_cust_flags args {
	global DB

	#Check we've the appropriate permission
	if {![op_allowed "UpdateCustomerFlags"]} {
		go_cust_flags
		return
	}

	set cust_id 	[reqGetArg CustId]

	set sql [subst {
		execute procedure pUpdCustFlag
		(
			p_cust_id	=?,
			p_flag_name	=?,
			p_flag_value	=?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	set sql_del [subst {
		delete from tCustomerFlag
		where cust_id = ?
		and flag_name = ?
	}]
	set stmt_del [inf_prep_sql $DB $sql_del]

	# go through all the flags shown
	for {set n 0} {$n < [reqGetNumVals]} {incr n} {
		if {[string range [reqGetNthName $n] 0 1] =="F_"} {
			set flag_name [string range [reqGetNthName $n] 2 [string length [reqGetNthName $n]]]

			# fraud status flag can only be changed if user has the right permission
			if {$flag_name == "fraud_status" && ![op_allowed ManageFraudStatus]} {
				continue
			}

			if {$flag_name == "no_reverse_wtd" && ![op_allowed OverridePmtBatchFlag]} {
				continue
			}

			# BIR Delay Factor should be a valid positive number if it's being set
			if {$flag_name == "BIR_DELAY_FACTOR"} {

				set bir_delay_factor [reqGetNthVal $n]

				if {!([string is double $bir_delay_factor] && $bir_delay_factor > 0)} {
					err_bind "BIR_DELAY_FACTOR should be a positive number"
					go_cust_flags $cust_id
					return
				}
			}

			if {!([string equal [reqGetNthVal $n] "unset"] || [string equal [reqGetNthVal $n] ""])}  {
				set ok 1
				if {[string equal [reqGetNthVal $n] "reset"]} {
					# Delete the flag
					if {[catch {inf_exec_stmt $stmt_del $cust_id $flag_name [reqGetNthVal $n]} msg] } {
						set ok 0
					}
				} else {
					# Update the flag
					if {[catch {inf_exec_stmt $stmt $cust_id $flag_name [reqGetNthVal $n]} msg] } {
						set ok 0
					}
				}
				if {!$ok} {
					err_bind $msg
					go_cust_flags $cust_id
					return
				} else {

					# Some flags need stuff to be done after they have been updated.
					# Ex: synchronise to external systems, etc. So do that here.
					set proc_end {}
					foreach {f p} [OT_CfgGet CUST_FLAG_PROC_ENDS] {
						if {$f == $flag_name} {
							set proc_end $p
						}
					}
					if {$proc_end != ""} {
						eval $proc_end $cust_id [reqGetNthVal $n]
					}
				}
			}
		}
	}
	go_cust
}


proc synch_bonus_abuser_to_playtech {cust_id flag_value} {

	global DB

	if {$flag_value != "Y"} {
		set flag_value "N"
	}

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
			r.fax,
			r.occupation,
			r.gender,
			c.lang
		from
			tCustomer c,
			tAcct a,
			tCustomerReg r,
			outer tCountry y
		where
		    c.cust_id = ?
		and r.cust_id = c.cust_id
		and a.cust_id = c.cust_id
		and y.country_code = c.country_code
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set colnames [db_get_colnames $res]
	foreach col $colnames {
		set $col [db_get_col $res 0 $col]
	}

	db_close $res

	foreach system [OT_CfgGet PLAYTECH_SYSTEMS] {
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
			$flag_value\
			$acct_no\
			$occupation\
			$gender\
			$dob
	}
}


#
# ----------------------------------------------------------------------------
# List Customer's Free Tokens
# ----------------------------------------------------------------------------
#
proc go_free_token_list args {

	global DB
	global TOKENS

	set cust_id [reqGetArg CustId]
	set redeem  [reqGetArg TokenType]
	set status  [expr {[reqGetArg TokensStatus] == "" ? "A" : [reqGetArg TokensStatus]}]

	tpBindString CustID $cust_id

	if {$redeem == "O"} {
		set possible_bet ""
		if {![OT_CfgGet FUNC_FREEBETS_WITH_POSSIBLE_BETS 1]} {
			set possible_bet "outer (tPossibleBet pb, tRedemptionVal rv)"
		} else {
			set possible_bet "tPossibleBet pb, tRedemptionVal rv"
		}

		if {$status == "D"} {
			set status_condition "and ct.status = 'X'"
		} else {
			set status_condition "and ct.expiry_date > current \
                                              and ct.status = 'A'"
		}

		set sql [subst {
			select
				o.name,
				ct.value amount,
				ct.status,
				ta.ccy_code,
				ct.expiry_date,
				ct.token_id,
				ct.cust_token_id,
				rv.redemption_id,
				rv.name as p_bet_name,
				tr.redemption_type
			from
				outer tCustTokRedemption tr,
				tCustomerToken ct,
				tTokenAmount ta,
				tOffer o,
				tToken t,
				tAcct a,
				$possible_bet
			where
				ct.cust_id = ? and
				ct.cust_id = a.cust_id and
				ta.ccy_code = a.ccy_code and
				ct.token_id = ta.token_id and
				ct.token_id = t.token_id and
				ct.token_id = pb.token_id and
				ct.cust_token_id = tr.cust_token_id and
				pb.redemption_id = rv.redemption_id and
				t.offer_id = o.offer_id	and
				ct.redeemed != 'Y'
				$status_condition
			union
			select
				o.name,
				ct.value amount,
				ct.status,
				ta.ccy_code,
				ct.expiry_date,
				ct.token_id,
				ct.cust_token_id,
				rv.redemption_id,
				rv.name as p_bet_name,
				tr.redemption_type
			from
				outer tCustTokRedemption tr,
				tCustomerToken ct,
				tTokenAmount ta,
				tOffer o,
				tToken t,
				tAcct a,
				tRedemptionVal rv
			where
				ct.adhoc_redemp_id is not null and
				ct.cust_id = ? and
				ct.cust_id = a.cust_id and
				ta.ccy_code = a.ccy_code and
				ct.token_id = ta.token_id and
				ct.token_id = t.token_id and
				ct.cust_token_id = tr.cust_token_id and
				ct.adhoc_redemp_id = rv.redemption_id and
				t.offer_id = o.offer_id	and
				ct.redeemed = 'N'
				$status_condition
		}]
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id $cust_id]
	} else {
		set sql {
			select
				tr.cr_date as redemption_date,
				tr.redemption_id,
				tr.redemption_amount,
				a.ccy_code,
				tr.redemption_type
			from
				tCustTokRedemption tr,
				tCustomerToken ct,
				tAcct a
			where
				ct.cust_id = ? and
				ct.cust_id = a.cust_id and
				ct.cust_token_id = tr.cust_token_id and
				ct.redeemed != 'N'
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $cust_id]
	}

	inf_close_stmt $stmt

	set nrows 	   [db_get_nrows $res]
	tpSetVar numTokens $nrows

	if {$redeem == "O"} {
		for {set i 0} {$i < $nrows} {incr i} {
			set TOKENS($i,name)             [db_get_col $res $i name]
			set TOKENS($i,amount)           [db_get_col $res $i amount]
			set TOKENS($i,status)           [db_get_col $res $i status]
			set TOKENS($i,ccy_code)         [db_get_col $res $i ccy_code]
			set TOKENS($i,expiry_date)      [db_get_col $res $i expiry_date]
			set TOKENS($i,token_id)         [db_get_col $res $i token_id]
			set TOKENS($i,cust_token_id)    [db_get_col $res $i cust_token_id]
			set TOKENS($i,p_bet_name)       [db_get_col $res $i p_bet_name]
			set TOKENS($i,redemption_id)    [db_get_col $res $i redemption_id]
			set TOKENS($i,redemption_type)  [db_get_col $res $i redemption_type]
		}

		tpBindVar token_name           TOKENS name              t_idx
		tpBindVar token_amount         TOKENS amount            t_idx
		tpBindVar token_status         TOKENS status            t_idx
		tpBindVar token_ccy_code       TOKENS ccy_code          t_idx
		tpBindVar token_expiry_date    TOKENS expiry_date       t_idx
		tpBindVar token_id             TOKENS token_id          t_idx
		tpBindVar cust_token_id        TOKENS cust_token_id     t_idx
		tpBindVar token_p_bet_name     TOKENS p_bet_name        t_idx
		tpBindVar token_redemption_id  TOKENS redemption_id     t_idx
		tpBindVar redemption_type      TOKENS redemption_type   t_idx

		tpBindString CustId       $cust_id
		tpBindString TokenType    $redeem
		tpBindString TokensStatus $status

		asPlayFile -nocache cust_open_token_list.html

	} else {
		for {set i 0} {$i < $nrows} {incr i} {
			set TOKENS($i,id)              [db_get_col $res $i redemption_id]
			set TOKENS($i,amount)          [db_get_col $res $i redemption_amount]
			set TOKENS($i,ccy_code)        [db_get_col $res $i ccy_code]
			set TOKENS($i,redemption_type) [db_get_col $res $i redemption_type]
			set TOKENS($i,date)            [db_get_col $res $i redemption_date]
		}

		tpBindVar token_redem_id     TOKENS id              t_idx
		tpBindVar token_redem_amount TOKENS amount          t_idx
		tpBindVar token_ccy_code     TOKENS ccy_code        t_idx
		tpBindVar redemtion_type     TOKENS redemption_type t_idx
		tpBindVar token_redem_date   TOKENS date            t_idx

		asPlayFile -nocache cust_redeem_token_list.html
	}
}


#
# ----------------------------------------------------------------------------
# Delete customer freebet tokens
# ----------------------------------------------------------------------------
#
proc del_cust_token {} {

	global DB

	set cust_id [reqGetArg CustId]
	set token_type [reqGetArg TokenType]

	# get the tokens list (comma separated string) from js into a proper tcl
	# list
	set tokens_array [split [reqGetArg TokensArray] ',']

	OT_LogWrite DEBUG "ADMIN::CUST::DelCustToken > Tokens $tokens_array marked \
	                  for deletion"

	if {[op_allowed DelFreebetTokens]} {
		# Sql to mark token as deleted
		set update_sql {
			update
			tCustomerToken
			set
			status = 'X'
			where
			cust_token_id = ?
		}

		set stmt [inf_prep_sql $DB $update_sql]

		# Iterate over tokens list, trying to delete them ...
		foreach token $tokens_array {

			OT_LogWrite DEBUG "ADMIN::CUST::DelCustToken > Trying to delete \
								Freebet token '$token' ..."

			if {[catch {
				# We are deleting the token
				set rs [inf_exec_stmt $stmt $token]
			} msg]} {
				OT_LogWrite ERROR "ADMIN::CUST::DelCustToken > Error while \
									trying to delete freebet token '$token'"
			} else {
				OT_LogWrite DEBUG "ADMIN::CUST::DelCustToken > Freebet token \
									'$token' has been deleted."
			}
		}

		inf_close_stmt $stmt
		db_close $rs
	}

	# Display the freebet token list
	reqSetArg CustId $cust_id
	reqSetArg TokenType $token_type

	go_free_token_list
}

#
# ----------------------------------------------------------------------------
# Customer search -> Credit Card Type
# ----------------------------------------------------------------------------
#
proc go_cust_cardtype_query args {
	global DB

	set where [list]
	set from  [list]

	# Customer's Username
	if {[string length [set name [reqGetArg Username]]] > 0} {
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

	#Customer Registered Between
	set rd1 [string trim [reqGetArg RegDate1]]
	set rd2 [string trim [reqGetArg RegDate2]]

	if {([string length $rd1] > 0) || ([string length $rd2] > 0)} {
		lappend where [mk_between_clause c.cr_date date $rd1 $rd2]
	}

	#Customer Card Registered Between
	set date_lo [string trim [reqGetArg CardRegDate1]]
	set date_hi [string trim [reqGetArg CardRegDate2]]

	if {[set date_range [reqGetArg DateRange]] != ""} {
		set now_dt [clock format [clock seconds] -format %Y-%m-%d]
		foreach {Y M D} [split $now_dt -] { break }
		set date_hi "$Y-$M-$D 23:59:59"
		if {$date_range == "TD"} {
			set date_lo "$Y-$M-$D 00:00:00"
		} elseif {$date_range == "CM"} {
			set date_lo "$Y-$M-01 00:00:00"
		} elseif {$date_range == "YD"} {
			set date_lo "[date_days_ago $Y $M $D 1] 00:00:00"
			set date_hi "[date_days_ago $Y $M $D 1] 23:59:59"
		} elseif {$date_range == "L3"} {
			set date_lo "[date_days_ago $Y $M $D 3] 00:00:00"
		} elseif {$date_range == "L7"} {
			set date_lo "[date_days_ago $Y $M $D 7] 00:00:00"
		}
	}

	if {([string length $date_lo] > 0) || ([string length $date_hi] > 0)} {
		lappend where [mk_between_clause cc.cr_date date $date_lo $date_hi]
	}

	# Card Status (A/S/X/""...)
	if {[string length [set card_status [reqGetArg CardStatus]]] > 0} {
		lappend where "m.status = '$card_status'"
	}

	# Card Type
	if {[string length [set card_type [reqGetArg CardType]]] > 0} {
		lappend where "cc.card_bin >= s.bin_lo and cc.card_bin <= s.bin_hi"
		lappend where "s.scheme = i.scheme"
		lappend where "i.scheme_name = \"$card_type\""

		lappend from  "tcardscheme      s"
		lappend from  "tcardschemeinfo  i"
	}

	#
	# Don't allow a query with no filters
	#
	#if {[llength $where] == 0} {
	#	error "No search criteria supplied"
	#}
	#set where "and [join $where { and }]"

	if {[llength $from] > 0} {
		set from ", [join $from { , }]"
	}

	if {[llength $where] > 0} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			c.cust_id,
			c.username,
			c.status,
			c.sort,
			c.acct_no,
			c.bet_count - (select count(*) from tbet where acct_id=a.acct_id and status='X') as bet_count,
			c.elite,
			c.country_code,
			a.ccy_code,
			c.cr_date,
			c.max_stake_scale,
			a.balance + a.sum_ap AS balance,
			a.credit_limit,
			r.fname,
			r.lname,
			r.dob,
			r.addr_street_1,
			r.addr_postcode,
			r.email,
			NVL((select d.desc from tCustCode d where r.code = d.cust_code),'(None)')
				as cust_group
		from
			tCustomer     c,
			tAcct         a,
			tCustomerReg  r
		where
			c.cust_id = a.cust_id and
			c.cust_id = r.cust_id and
			c.cust_id in ( select
						distinct c.cust_id
					from
						tCustomer     	c,
						tCustPayMthd  	m,
						tCpmCC 		cc
						$from
					where
						c.cust_id = m.cust_id and
						m.cpm_id = cc.cpm_id
						$where
					) and
			a.owner   <> 'D'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumNorm [set NumCusts [db_get_nrows $res]]

	if {$NumCusts == 1} {
		go_cust cust_id [db_get_col $res 0 cust_id]
		db_close $res
		return
	}

	global DATA

	array set DATA [list]

	set num_elite 0

	for {set r 0} {$r < $NumCusts} {incr r} {
		set DATA($r,acct_no) [acct_no_enc [db_get_col $res $r acct_no]]
		if {[db_get_col $res $r elite] == "Y"} {
			incr num_elite
		}
	}

	tpBindVar AcctNo      DATA acct_no cust_idx
	tpSetVar NumElite $num_elite

	tpBindTcl CustID        sb_res_data $res cust_idx cust_id
	tpBindTcl Elite         sb_res_data $res cust_idx elite
	tpBindTcl Username      sb_res_data $res cust_idx username
	tpBindTcl Status        sb_res_data $res cust_idx status
	tpBindTcl Sort          sb_res_data $res cust_idx sort
	tpBindTcl BetCount      sb_res_data $res cust_idx bet_count
	tpBindTcl Country       sb_res_data $res cust_idx country_code
	tpBindTcl Currency      sb_res_data $res cust_idx ccy_code
	tpBindTcl Balance       sb_res_data $res cust_idx balance
	tpBindTcl MaxStakeScale sb_res_data $res cust_idx max_stake_scale
	tpBindTcl RegDate       sb_res_data $res cust_idx cr_date
	tpBindTcl RegFName      sb_res_data $res cust_idx fname
	tpBindTcl RegLName      sb_res_data $res cust_idx lname
	tpBindTcl DOB           sb_res_data $res cust_idx dob
	tpBindTcl Address1      sb_res_data $res cust_idx addr_street_1
	tpBindTcl Postcode      sb_res_data $res cust_idx addr_postcode
	tpBindTcl Email         sb_res_data $res cust_idx email
	tpBindTcl CustGroup     sb_res_data $res cust_idx cust_group


	set_display_fields

	asPlayFile -nocache cust_list.html

	unset DATA

	db_close $res


}



#
# ----------------------------------------------------------------------------
# Gets the details of a particular customers Risk Guardian failures
# ----------------------------------------------------------------------------
#
proc go_rg_failure_query args {

	global DB DATA

	set cust_id [reqGetArg CustId]

	set sql [subst {
		select
		    c.username,
		    c.acct_no,
		    r.rg_failure_id,
		    r.cust_id,
		    r.fail_date,
		    r.amount,
		    r.order_no,
		    r.rg_id,
		    r.tscore,
		    r.trisk
		from
		    tRGFailure r,
		    tCustomer c
		where
		    r.cust_id        = c.cust_id and
		    r.cust_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	array set DATA [list]

	for {set r 0} {$r < $nrows} {incr r} {

		set DATA($r,username)      [db_get_col $res $r username]
		set DATA($r,acct_no)       [db_get_col $res $r acct_no]
		set DATA($r,rg_failure_id) [db_get_col $res $r rg_failure_id]
		set DATA($r,fail_date)     [db_get_col $res $r fail_date]
		set DATA($r,amount)        [db_get_col $res $r amount]
		set DATA($r,order_no)      [db_get_col $res $r order_no]
		set DATA($r,rg_id)         [db_get_col $res $r rg_id]
		set DATA($r,tscore)        [db_get_col $res $r tscore]
		set DATA($r,trisk)         [db_get_col $res $r trisk]
	}
	db_close $res

	tpBindVar RGFailureId   DATA rg_failure_id fail_idx
	tpBindVar FailDate      DATA fail_date fail_idx
	tpBindVar Amount        DATA amount fail_idx
	tpBindVar OrderNo       DATA order_no fail_idx
	tpBindVar RGId          DATA rg_id fail_idx
	tpBindVar TScore        DATA tscore fail_idx
	tpBindVar TRisk         DATA trisk fail_idx

	tpBindString Username    $DATA(0,username)
	tpBindString AcctNo      $DATA(0,acct_no)
	tpSetVar     NumFails    $nrows

	asPlayFile cust_rg_fail.html

	unset DATA
}



#
# ----------------------------------------------------------------------------
# Sets whether certain fields should be displayed on results
# screen : cust_list.html
# ----------------------------------------------------------------------------
#
proc set_display_fields args {
	#decide which columns to show
	if {[set auth_fields [OT_CfgGet USER_RES_FIELDS ""]] == ""} {
		set auth_fields [list Acct]
	}

	foreach f $auth_fields {
		tpSetVar Show${f} "Y"
	}

	tpBindString ColSpan [expr {14 + [llength $auth_fields]}]
}

#
# check_threshold
# check user has permission to make a manual adjustment
# given the amount and threshold levels
#
# stage - the stage of the process
#
proc check_threshold {amount tlimits ccy stage} {

	set fn {ADMIN::CUST::check_threshold}

	if {[lsearch {A P R} $stage] < 0} {
		ob_log::write ERROR {${fn}: $stage is not a valid stage!}
		return 0
	}

	set amount [format %0.2f $amount]

	# Not dealing with negative amounts
	if {$amount < 0} {
		set amount [expr abs($amount)]
	}

	# Just in case, we sort these in order
	set tlimits [lsort -integer $tlimits]

	set tlimits [concat 0 $tlimits]

	set stage_str [string map {"R" "Raise" "A" "Auth" "P" "Post"} $stage]

	# Work backwards through the limit amounts (so from greatest to least)
	for {set l [expr {[llength $tlimits] - 1}]} {$l > 0} {incr l -1} {

		# Get the limit amount
		set upper [lindex $tlimits $l]

		# If the man adj amount is greater than this limit amount
		# (we convert the limit amount to the customer's ccy in order to compare)
		# then the user doesn't have adequate permission
		if {$amount > [convert_to_ccy $upper $ccy]} {
			return 0
		} else {
			if {[OT_CfgGet FUNC_MANADJ_IMMEDIATE 0]} {
				if {[op_allowed AdHocFundsXferLevel$l]} {
					return 1
				}
			} else {
				if {[op_allowed Manj${stage_str}FndXferL$l]} {
					return 1
				}
			}
		}
	}

	return 0
}

proc query_cust_status_flags {} {
	global DB CUST_STATUS_FLAGS
	variable CUST_FLAGS

	set action  [reqGetArg SubmitName]

	if {$action == "Query"} {
		set where [list]

		set SR_date_1     [reqGetArg SR_date_1]
		set SR_date_2     [reqGetArg SR_date_2]
		set SR_date_range [reqGetArg SR_date_range]
		set added_by      [reqGetArg added_by]
		set cleared_by    [reqGetArg cleared_by]
		set flag          [reqGetArg flag]
		set status        [reqGetArg status]
		set SR_CustGrp    [reqGetArg SR_CustGrp]
		set outer         "outer"

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

		if {[string length [set name [reqGetArg Username]]] > 0} {
			if {[reqGetArg ignorecase] == "Y"} {
				lappend where "[upper_q c.username] like [upper_q '${name}%']"
			} else {
				lappend where "c.username = \"${name}\""
			}
		}

		if {$SR_date_1 != ""} {
			lappend where "sf.set_flag_date >= '$SR_date_1'"
		}

		if {$SR_date_2 != ""} {
			lappend where "sf.set_flag_date <= '$SR_date_2'"
		}

		if {$added_by != ""} {
			lappend where "ta1.username = '$added_by'"
		}

		if {$cleared_by != ""} {
			lappend where "ta2.username = '$cleared_by'"
			set outer ""
		}

		if {$flag != ""} {
			lappend where "sf.status_flag_tag = '$flag'"
		}

		if {$status != ""} {
			lappend where "sf.status = '$status'"
		}

		set cgroup_select ""
		set cgroup_from   ""

		# Is search per group enabled ?
		if {[OT_CfgGetTrue FUNC_FLG_SEARCH_CUST_GRP]} {
			set cgroup_select ", nvl(cco.desc,'N/A') as cust_code_desc"
			set cgroup_from   ", tCustomerReg r ,outer tCustCode cco"
			lappend where  "r.cust_id = c.cust_id"
			lappend where  "cco.cust_code = r.code"

			# Actually filter if any filter is there
			if {$SR_CustGrp != ""} {

				# Are we searching only Platinum ?
				if {$SR_CustGrp == "OPT_AllPlatinum"} {

					set plat_search_string [get_platinum_search_string]

					if {$plat_search_string != ""} {
						lappend where "r.code in $plat_search_string"
					}

				} else {
					lappend where "r.code = '$SR_CustGrp'"
				}
			}
		}


		if {[llength $where]} {
			set where "and [join $where { and }]"
		}

		set sql [subst {
			select
				c.username,
				c.cust_id,
				sf.cust_flag_id,
				sf.status_flag_tag,
				f.status_flag_name,
				sf.status,
				sf.set_flag_oper,
				ta1.username as set_flag_uname,
				sf.set_flag_date,
				sf.set_flag_reason,
				sf.clear_flag_oper,
				ta2.username as clear_flag_uname,
				sf.clear_flag_date,
				sf.ref_key,
				sf.ref_id
				$cgroup_select
			from
				tCustStatusFlag sf,
				outer tAdminUser ta1,
				tStatusFlag f,
				$outer tAdminUser ta2,
				tCustomer c,
				tacct a
				$cgroup_from
			where
				c.cust_id = sf.cust_id
			and
				f.status_flag_tag = sf.status_flag_tag
			and
				ta1.user_id = sf.set_flag_oper
			and
				ta2.user_id = sf.clear_flag_oper
			and
				c.cust_id   = a.cust_id
			and
				a.owner     <> 'D'
			$where
			order by
				set_flag_date desc
		}]

		set stmt     [inf_prep_sql $DB $sql]
		set res_cust_flags [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		set NumCustFlags [db_get_nrows $res_cust_flags]
		tpSetVar NumCustFlags $NumCustFlags

		for {set i 0} {$i < $NumCustFlags} {incr i} {
			set CUST_STATUS_FLAGS($i,username)            [db_get_col $res_cust_flags $i  username]
			set CUST_STATUS_FLAGS($i,cust_id)             [db_get_col $res_cust_flags $i  cust_id]
			set CUST_STATUS_FLAGS($i,cust_flag_id)        [db_get_col $res_cust_flags $i  cust_flag_id]
			set CUST_STATUS_FLAGS($i,status_flag_name)    [db_get_col $res_cust_flags $i  status_flag_name]
			set CUST_STATUS_FLAGS($i,status)              [db_get_col $res_cust_flags $i  status]

			if {$CUST_STATUS_FLAGS($i,status) == "A"} {
				set CUST_STATUS_FLAGS($i,status) "active"
			} else {
				set CUST_STATUS_FLAGS($i,status) "suspended"
			}

			set CUST_STATUS_FLAGS($i,set_flag_uname)      [db_get_col $res_cust_flags $i  set_flag_uname]

			if {$CUST_STATUS_FLAGS($i,set_flag_uname) == ""} {
				set CUST_STATUS_FLAGS($i,set_flag_uname) "system"
			}

			set CUST_STATUS_FLAGS($i,set_flag_date)       [db_get_col $res_cust_flags $i  set_flag_date]
			set CUST_STATUS_FLAGS($i,set_flag_reason)     [db_get_col $res_cust_flags $i  set_flag_reason]
			set CUST_STATUS_FLAGS($i,clear_flag_uname)    [db_get_col $res_cust_flags $i  clear_flag_uname]
			set CUST_STATUS_FLAGS($i,clear_flag_date)     [db_get_col $res_cust_flags $i  clear_flag_date]
			set CUST_STATUS_FLAGS($i,ref_key)             [db_get_col $res_cust_flags $i  ref_key]
			set CUST_STATUS_FLAGS($i,ref_id)              [db_get_col $res_cust_flags $i  ref_id]

			if {[OT_CfgGetTrue FUNC_FLG_SEARCH_CUST_GRP]} {
				set CUST_STATUS_FLAGS($i,cust_code_desc)  \
					[db_get_col $res_cust_flags $i cust_code_desc]
			}
		}

		db_close $res_cust_flags

		tpBindVar username        CUST_STATUS_FLAGS username     cf_idx
		tpBindVar cust_id         CUST_STATUS_FLAGS cust_id     cf_idx

		tpBindVar cust_flag_id        CUST_STATUS_FLAGS cust_flag_id     cf_idx
		tpBindVar status_flag_name    CUST_STATUS_FLAGS status_flag_name cf_idx
		tpBindVar status              CUST_STATUS_FLAGS status           cf_idx
		tpBindVar set_flag_uname      CUST_STATUS_FLAGS set_flag_uname   cf_idx
		tpBindVar set_flag_date       CUST_STATUS_FLAGS set_flag_date    cf_idx
		tpBindVar set_flag_reason     CUST_STATUS_FLAGS set_flag_reason  cf_idx
		tpBindVar clear_flag_uname    CUST_STATUS_FLAGS clear_flag_uname cf_idx
		tpBindVar clear_flag_date     CUST_STATUS_FLAGS clear_flag_date  cf_idx
		tpBindVar ref_key             CUST_STATUS_FLAGS ref_key          cf_idx
		tpBindVar ref_id              CUST_STATUS_FLAGS ref_id           cf_idx
		tpBindVar cust_code_desc      CUST_STATUS_FLAGS  cust_code_desc  cf_idx

		asPlayFile -nocache cust_status_flags_query.html

	} else {

		set sql [subst {
			select
				status_flag_tag,
				status_flag_name
			from
				tStatusFlag
		}]

		set stmt      [inf_prep_sql $DB $sql]
		set res_flags [inf_exec_stmt $stmt]

		inf_close_stmt $stmt

		tpSetVar NumFlags [set n_rows [db_get_nrows $res_flags]]

		for {set r 0} {$r < $n_rows} {incr r} {
			set CUST_FLAGS($r,status_flag_tag) \
						[db_get_col $res_flags $r status_flag_tag]
			set CUST_FLAGS($r,status_flag_name) \
						[db_get_col $res_flags $r status_flag_name]
		}

		set cns [namespace current]

		tpBindVar FlagTag     ${cns}::CUST_FLAGS status_flag_tag  flag_idx
		tpBindVar FlagName    ${cns}::CUST_FLAGS status_flag_name flag_idx

		GC::mark CUST_FLAGS
		db_close $res_flags

		# Filter per customer code
		if {[OT_CfgGetTrue FUNC_FLG_SEARCH_CUST_GRP]} {
			_bind_customer_codes
		}

		asPlayFile -nocache cust_status_flags_args.html

	}
}

proc do_cust_status_flags {} {

	global DB USERID CUST_STATUS_FLAGS

	set action  [reqGetArg SubmitName]
	set cust_id [reqGetArg CustId]

	ob_log::write DEBUG {do_cust_status_flags: $action,$cust_id}

	if {$action == "Back"} {

		go_cust
		return

	} elseif {$action == "AddFlag"} {

		set status_flag_tag    [reqGetArg status_flag_tag]

		set sql [subst {
			select
				status_flag_tag
			from
				tCustStatusFlag
			where
				cust_id = ?
			and
				status = 'A'
			and
				status_flag_tag = ?
		}]

		set stmt    [inf_prep_sql $DB $sql]
		set res     [inf_exec_stmt $stmt $cust_id $status_flag_tag]

		inf_close_stmt $stmt

		if {[db_get_nrows $res] == 0} {

			set reason  [reqGetArg reason]

			set sql [subst {
				execute procedure pInsCustStatusFlag (
					p_cust_id = ?,
					p_status_flag_tag = ?,
					p_user_id = ?,
					p_reason = ?
				)
			}]

			set stmt    [inf_prep_sql $DB $sql]
			set res_add [inf_exec_stmt $stmt $cust_id $status_flag_tag $USERID $reason]

			inf_close_stmt $stmt

			db_close $res_add

		} else {
			err_bind "This code is already assigned."
		}

	} elseif {$action == "DeleteFlag"} {

		set cust_flag_id    [reqGetArg cust_flag_id]

		set sql [subst {
			execute procedure pDelCustStatusFlag (
				p_cust_flag_id = ?,
				p_user_id = ?
			)
		}]

		set stmt    [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt $stmt $cust_flag_id $USERID]
			inf_close_stmt $stmt
			db_close $res
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind $msg
		}
	} elseif {$action == "LRtoFC"} {

		set cust_flag_id    [reqGetArg cust_flag_id]

		set sql [subst {
			execute procedure pLRtoFCStatusFlag (
				p_cust_flag_id = ?,
				p_user_id = ?
			)
		}]

		set stmt    [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt $stmt $cust_flag_id $USERID]
			inf_close_stmt $stmt
			db_close $res
		} msg]} {
			ob::log::write ERROR {unable to execute query : $msg}
			err_bind $msg
		}
	}

	set sql [subst {
		select
			status_flag_tag,
			status_flag_name
		from
			tStatusFlag
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_flags [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumFlags [db_get_nrows $res_flags]

	tpBindTcl FlagTag     sb_res_data $res_flags flag_idx status_flag_tag
	tpBindTcl FlagName    sb_res_data $res_flags flag_idx status_flag_name

	set sql [subst {
		select
			c.username,
			c.cust_id,
			sf.cust_flag_id,
			sf.status_flag_tag,
			f.status_flag_name,
			sf.status,
			sf.set_flag_oper,
			ta1.username as set_flag_uname,
			sf.set_flag_date,
			sf.set_flag_reason,
			sf.clear_flag_oper,
			ta2.username as clear_flag_uname,
			sf.clear_flag_date,
			sf.ref_key,
			sf.ref_id
		from
			tCustStatusFlag sf,
			outer tAdminUser ta1,
			tStatusFlag f,
			outer tAdminUser ta2,
			tCustomer c
		where
			f.status_flag_tag = sf.status_flag_tag
		and
			c.cust_id = sf.cust_id
		and
			sf.cust_id = ?
		and
			ta1.user_id = sf.set_flag_oper
		and
			ta2.user_id = sf.clear_flag_oper
		order by
			set_flag_date desc
	}]

	set stmt     [inf_prep_sql $DB $sql]
	set res_cust_flags [inf_exec_stmt $stmt $cust_id]

	inf_close_stmt $stmt

	set NumCustFlags [db_get_nrows $res_cust_flags]
	tpSetVar NumCustFlags $NumCustFlags
	set flags_to_ignore [OT_CfgGet NON_CLEARABLE_STATUS_FLAGS {}]

	for {set i 0} {$i < $NumCustFlags} {incr i} {

		# If the customer status exists in NON_CLEARABLE_STATUS_FLAGS it will be cleared by other means.
		set cur_flag [db_get_col $res_cust_flags $i  status_flag_tag]
		if {[lsearch $flags_to_ignore $cur_flag] > -1} {
			set CUST_STATUS_FLAGS($i,allowDelete) "N"
		} else {
			set CUST_STATUS_FLAGS($i,allowDelete) "Y"
		}

		set CUST_STATUS_FLAGS($i,username)            [db_get_col $res_cust_flags $i  username]
		set CUST_STATUS_FLAGS($i,cust_id)             [db_get_col $res_cust_flags $i  cust_id]
		set CUST_STATUS_FLAGS($i,cust_flag_id)        [db_get_col $res_cust_flags $i  cust_flag_id]
		set CUST_STATUS_FLAGS($i,status_flag_name)    [db_get_col $res_cust_flags $i  status_flag_name]
		set CUST_STATUS_FLAGS($i,status_flag_tag)     [db_get_col $res_cust_flags $i  status_flag_tag]
		set CUST_STATUS_FLAGS($i,status)              [db_get_col $res_cust_flags $i  status]

		if {$CUST_STATUS_FLAGS($i,status) == "A"} {
			set CUST_STATUS_FLAGS($i,status) "active"
		} else {
			set CUST_STATUS_FLAGS($i,status) "suspended"
		}

		set CUST_STATUS_FLAGS($i,set_flag_uname)      [db_get_col $res_cust_flags $i  set_flag_uname]

		if {$CUST_STATUS_FLAGS($i,set_flag_uname) == ""} {
			set CUST_STATUS_FLAGS($i,set_flag_uname) "system"
		}

		set CUST_STATUS_FLAGS($i,set_flag_date)       [db_get_col $res_cust_flags $i  set_flag_date]
		set CUST_STATUS_FLAGS($i,set_flag_reason)     [db_get_col $res_cust_flags $i  set_flag_reason]
		set CUST_STATUS_FLAGS($i,clear_flag_uname)    [db_get_col $res_cust_flags $i  clear_flag_uname]

		if {$CUST_STATUS_FLAGS($i,clear_flag_uname) == ""} {
			set CUST_STATUS_FLAGS($i,clear_flag_uname) "system"
		}

		set CUST_STATUS_FLAGS($i,clear_flag_date)     [db_get_col $res_cust_flags $i  clear_flag_date]

		set CUST_STATUS_FLAGS($i,ref_key)             [db_get_col $res_cust_flags $i  ref_key]
		set CUST_STATUS_FLAGS($i,ref_id)              [db_get_col $res_cust_flags $i  ref_id]
	}

	tpBindVar username        CUST_STATUS_FLAGS username     cf_idx
	tpBindVar cust_id         CUST_STATUS_FLAGS cust_id     cf_idx

	tpBindVar cust_flag_id        CUST_STATUS_FLAGS cust_flag_id     cf_idx
	tpBindVar status_flag_name    CUST_STATUS_FLAGS status_flag_name cf_idx
	tpBindVar status              CUST_STATUS_FLAGS status           cf_idx
	tpBindVar set_flag_uname      CUST_STATUS_FLAGS set_flag_uname   cf_idx
	tpBindVar set_flag_date       CUST_STATUS_FLAGS set_flag_date    cf_idx
	tpBindVar set_flag_reason     CUST_STATUS_FLAGS set_flag_reason  cf_idx
	tpBindVar clear_flag_uname    CUST_STATUS_FLAGS clear_flag_uname cf_idx
	tpBindVar clear_flag_date     CUST_STATUS_FLAGS clear_flag_date  cf_idx
	tpBindVar ref_key             CUST_STATUS_FLAGS ref_key          cf_idx
	tpBindVar ref_id              CUST_STATUS_FLAGS ref_id           cf_idx
	tpBindVar allowDelete         CUST_STATUS_FLAGS allowDelete      cf_idx


	tpBindString CustId $cust_id

	asPlayFile -nocache cust_status_flags.html

	db_close $res_cust_flags
	db_close $res_flags
}

#
# ----------------------------------------------------------------------------
# Gets the casino transfer status from tXferStatus
# screen : cust.html
# ----------------------------------------------------------------------------
#
proc show_casino_tfrs {} {

	global TFR_HIST DB

	set cust_id [reqGetArg CustId]

	set sql [subst {
		select
			tx_id,
			tx_date,
			tx_op_type,
			amount,
			status,
			failure_reason,
			man_adj_id,
			acct_id
		from
			tXferStatus
		where
			acct_id = (select acct_id
			from tCustomer
			where cust_id = ?)
		order by tx_date desc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id]

	array set TFR_HIST [list]

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach col $colnames {
			set TFR_HIST($r,$col) [db_get_col $rs $r $col]
		}
	}

	db_close $rs

	set TFR_HIST(num_tfrs) $nrows
	tpSetVar num_tfrs $TFR_HIST(num_tfrs)

	tpBindVar tx_id				TFR_HIST	tx_id			tfr_idx
	tpBindVar tx_date       	TFR_HIST	tx_date			tfr_idx
	tpBindVar tx_op_type		TFR_HIST	tx_op_type		tfr_idx
	tpBindVar amount			TFR_HIST	amount			tfr_idx
	tpBindVar status			TFR_HIST 	status			tfr_idx
	tpBindVar failure_reason	TFR_HIST	failure_reason	tfr_idx
	tpBindVar man_adj_id		TFR_HIST	man_adj_id		tfr_idx

	tpBindString CustId $cust_id
	tpBindString AcctId $TFR_HIST(0,acct_id)

	asPlayFile -nocache cust_casino_tfrs_hist.html

}

#
# ----------------------------------------------------------------------------
# Edit the casino transfer status from tXferStatus
# screen : cust.html
# ----------------------------------------------------------------------------
#
proc edit_casino_tfrs {} {

	global TFR_STATUS DB

	set tx_id   [reqGetArg tx_id]
	set cust_id [reqGetArg CustId]
	set acct_id [reqGetArg AcctId]

	set sql [subst {
		select
			tx_id,
			tx_date,
			tx_op_type,
			amount,
			status,
			failure_reason,
			man_adj_id,
			acct_id
		from
			tXferStatus
		where
			tx_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $tx_id]

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	set status ""

	for {set r 0} {$r < $nrows} {incr r} {
		foreach col $colnames {
			tpBindString $col [db_get_col $rs $r $col]
			if {$col == "status"} {
				set status [db_get_col $rs $r $col]
			}
		}
	}

	db_close $rs

	array set status_lookup {
		S {Success}
		P {Pending}
		F {Failed}
	}

	array set TFR_STATUS [list]

	set i 0

	foreach val {S P F} {
		set TFR_STATUS($i,status) $val
		set TFR_STATUS($i,desc) $status_lookup($val)
		if {$status == $val} {
			set TFR_STATUS($i,selected) "selected"
		} else {
			set TFR_STATUS($i,selected) ""
		}

		incr i
	}

	tpSetVar num_status 3

	tpBindVar status	      TFR_STATUS	status	    tfr_idx
	tpBindVar status_desc	  TFR_STATUS	desc	    tfr_idx
	tpBindVar status_selected TFR_STATUS	selected	tfr_idx

	tpBindString CustId $cust_id
	tpBindString AcctId $acct_id

	asPlayFile -nocache cust_casino_tfrs_edit.html

}

#
# ----------------------------------------------------------------------------
# Edit the casino transfer status from tXferStatus
# screen : cust.html
# ----------------------------------------------------------------------------
#
proc upd_casino_tfrs {} {

	global TFR_STATUS DB

	set tx_id           [reqGetArg tx_id]
	set cust_id         [reqGetArg CustId]
	set acct_id         [reqGetArg AcctId]
	set status          [reqGetArg status]
	set failure_reason  [reqGetArg failure_reason]

	set sql [subst {
		update
			tXferStatus
		set
			status = '$status',
			failure_reason = '$failure_reason'
		where
			tx_id = $tx_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	db_close $rs

	reqSetArg CustId $cust_id
	reqSetArg AcctId $acct_id
	reqSetArg tx_id  $tx_id

	edit_casino_tfrs
}

proc go_cpm_ok_to_delete {} {

	global DB

	#
	# Retrieve the customer's details
	#
	set username  [reqGetArg username]
	set cust_id   ""

	ob::log::write INFO {ADMIN::CUST::go_cpm_ok_to_delete: username = $username}

	set sql {
		select
			c.cust_id
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id  = a.cust_id and
			a.owner    <> 'D' and
			c.username = ?
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt $username]
	} msg]} {

		ob::log::write ERROR {go_cpm_ok_to_delete: \
		                      Failed to execute $sql: $msg}
		set err_bind "Customer not found."

		asPlayFile -nocache pmt/ok_to_delete.html
		return
	}

	if {[db_get_nrows $rs] == 1} {

		set cust_id    [db_get_col $rs 0 cust_id]

		#
		# Make the call to see if it's ok to delete
		#
		set results [cc_change::perform_checks $cust_id]
		set success [lindex $results 0]
		set checks  [lindex $results 1]

		tpSetVar  SUCCESS     $success

		#
		# Take info from the call and bind it
		# up for the template.
		#
		set TRANS(0) "Failed"
		set TRANS(1) "Passed"
		set TRANS(2) "Unable to verify at present"
		set TRANS(3) "Not tested"

		foreach check $checks {

			set check_success [lindex $check 0]
			set check_msg     [lindex $check 1]
			set check_name    [lindex $check 2]

			ob::log::write DEBUG {go_cpm_ok_to_delete: $check_success $check_msg $check_name}

			tpSetVar $check_name 1

			tpBindString ${check_name}_MSG      $check_msg
			tpBindString ${check_name}_SUCCESS  $TRANS($check_success)
			tpBindString ${check_name}_CODE     $check_success

		}

	} else {
		err_bind "Customer not found."
	}
	db_close $rs

	#
	# Tidy up and return
	#
	asPlayFile -nocache pmt/ok_to_delete.html
	return
}

#
# go_boss_media_qry
# Check if user is still logged in to a Casino section
#
proc go_boss_media_qry {} {

	global DB

	set custId [reqGetArg CustId]

    	set sql [subst {
		select
			* from tBMCust
		where
			cust_id = $custId
	}]

	set stmt [inf_prep_sql $DB $sql]

	set rs [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
	    err_bind "The customer is still logged in to a Casino Session. A card change should not be allowed."
	}
	go_cust

	db_close $rs
}


#
# go_cust_groups
# Display the customer's current group information
#
proc go_cust_groups {cust_id} {

	global DB
	global CUST_GROUPS

	catch {unset CUST_GROUPS}

	set sql [subst {
		select
			v.group_name,
			v.group_value,
			v.value_desc,
			c.group_value_txt,
			c.group_value_id
		from
			tGroupValue v,
			tCustGroup  c
		where
			v.group_value_id = c.group_value_id
		and c.cust_id = $cust_id
	}]

	set stmt [inf_prep_sql $DB $sql]

	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]
	tpSetVar  NumCustGroups $nrows

	for {set i 0} {$i < $nrows} {incr i 1} {
		set CUST_GROUPS($i,name)  [db_get_col $rs $i group_name]
		set CUST_GROUPS($i,value) [db_get_col $rs $i group_value]
		set CUST_GROUPS($i,desc)  [db_get_col $rs $i value_desc]
		set CUST_GROUPS($i,text)  [db_get_col $rs $i group_value_txt]
		set CUST_GROUPS($i,id)    [db_get_col $rs $i group_value_id]
	}

	tpSetVar  NumCustGroups $nrows
	tpBindVar group_name      CUST_GROUPS name  cg_idx
	tpBindVar group_value     CUST_GROUPS value cg_idx
	tpBindVar group_desc      CUST_GROUPS desc  cg_idx
	tpBindVar group_text      CUST_GROUPS text  cg_idx
	tpBindVar group_value_id  CUST_GROUPS id    cg_idx

}



proc go_cust_groups_detail {} {

	global DB
	global GROUP_DETAIL

	# get cust group id(s)
	set cust_id        [reqGetArg cust_id]
	set group_value_id [reqGetArg group_value_id]

	# get list of available tiers for each product
	set sql {
		select
			v.group_value_id,
			d.group_name,
			d.group_desc,
			v.group_value,
			v.value_desc
		from
			tGroupValue v,
			tGroupDesc d
		where
			v.group_name = d.group_name
		order by
			d.group_name
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	set cur_group_name {}
	set j -1
	set k 0

	for {set i 0} {$i < $nrows} {incr i 1} {
		if {![string match $cur_group_name [db_get_col $rs $i group_name]]} {
			incr j 1
			set cur_group_name [db_get_col $rs $i group_name]
			set k 0
			set GROUP_DETAIL($j,name) [db_get_col $rs $i group_name]
			set GROUP_DETAIL($j,desc) [db_get_col $rs $i group_desc]
		}

		set GROUP_DETAIL($j,$k,value) [db_get_col $rs $i group_value_id]
		set GROUP_DETAIL($j,$k,desc)  [db_get_col $rs $i value_desc]
		incr k 1
		set GROUP_DETAIL($j,num_tiers) $k
	}

	tpSetVar NumProducts [expr $j + 1]

	# get current values (if they exist)
	if {$group_value_id == ""} {
		# it is an Add request
		tpSetVar type "Add"
	} else {
		tpSetVar type "Update"

		# get the values
		set sql [subst {
			select
				v.group_name,
				v.group_value_id,
				c.group_value_txt
			from
				tGroupValue v,
				tCustGroup  c
			where
				v.group_value_id = c.group_value_id
			and c.cust_id        = $cust_id
			and c.group_value_id = $group_value_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $rs]

		if {$nrows != 1} {
			OT_LogWrite 2 "CUST: getting cust_group details. Expected 1 row, got $nrows "
		} else {
			# bind up values
			tpBindString CurrProduct  [db_get_col $rs 0 group_name]
			tpBindString CurrTier     [db_get_col $rs 0 group_value_id]
			tpBindString CurrComments [db_get_col $rs 0 group_value_txt]
		}
	}

	# bind up values
	tpBindVar product_name GROUP_DETAIL name  p_idx
	tpBindVar product_desc GROUP_DETAIL desc  p_idx
	tpBindVar num_tiers    GROUP_DETAIL num_tiers  p_idx
	tpBindVar tier_value   GROUP_DETAIL value p_idx t_idx
	tpBindVar tier_desc    GROUP_DETAIL desc  p_idx t_idx

	tpBindString CustId    $cust_id

	# display page
	asPlayFile -nocache cust_group_detail.html

}

proc do_cust_groups_detail {} {

	# get the parameters submitted
	set cust_id        [reqGetArg cust_id]
	set group_value_id [reqGetArg group_value_id]
	set submit_name    [reqGetArg SubmitName]

	# choose what to do based on the action that was submitted.
	switch -exact -- $submit_name {
		Back {
			go_cust cust_id $cust_id
		}
		Add {
			do_add_cust_group $cust_id
		}
		Update {
			do_update_cust_group $cust_id $group_value_id
		}
		Delete {
			do_delete_cust_group $cust_id $group_value_id
		}
		default {
			OT_LogWrite 2 "CUST: Invalid SubmitName in do_cust_groups_detail"
			go_cust_groups_detail
		}
	}

}


proc do_add_cust_group {cust_id} {

	global DB

	# get request values
	set product [reqGetArg product]
	set tier_id [reqGetArg tier]
	set group_value_text [reqGetArg comments]

	# replace any single quotes]
	regsub -all {[\']} $group_value_text {''} mod_group_value_text

	# check for existing groups
	set sql "select
				1
			from
				tCustGroup cg,
				tGroupValue gv
			where
				cg.group_value_id = gv.group_value_id
			and cg.cust_id        = $cust_id
			and gv.group_name     = '$product'"

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
		# there is already a group assigned for this product.
		tpSetVar ShowError 1
		tpBindString error_message "The customer already has a group assigned for this product"
		go_cust_groups_detail
		return
	}

	# create query
	set sql "insert
				into
			tCustGroup (cust_id, group_value_id, group_value_txt)
	values ($cust_id, $tier_id, '$mod_group_value_text')"

	# do add
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		# if error, display details page with message
		OT_LogWrite 2 "CUST: Error adding cust group for cust_id $cust_id - $msg"
		tpSetVar ShowError 1
		tpBindString error_message "Error adding customer group - $msg"
		go_cust_groups_detail
		return
	}

	# send email
	if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {
		set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC "queue_email"]
		set params [list UPGRADE_TO_ACCOUNT $cust_id E UPG $tier_id]

		# send email to customer
		if {[catch {set res [eval $queue_email_func $params]} msg]} {
			OT_LogWrite 2 "Failed to queue change of details email, $msg"
		}
	}

	# otherwise, display cust page
	go_cust cust_id $cust_id

}

proc do_update_cust_group {cust_id group_value_id} {

	global DB

	# get request values
	set tier_id          [reqGetArg tier]
	set group_value_text [reqGetArg comments]
	set product          [reqGetArg product]

	# replace any single quotes]
	regsub -all {[\']} $group_value_text {''} mod_group_value_text

	# create query
	set sql "update
				tCustGroup
			set
				group_value_id = $tier_id,
				group_value_txt = '$mod_group_value_text'
			where
				cust_id=$cust_id
			and group_value_id=$group_value_id"

	# do update
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "CUST: Error updating cust group for cust_id $cust_id - $msg"
		tpSetVar ShowError 1
		tpBindString error_message "Error updating customer group - $msg"
		go_cust_groups_detail
		return
	}

	# send email
	if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {
		set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC "queue_email"]
		set params [list UPGRADE_TO_ACCOUNT $cust_id E UPG $tier_id]

		# send email to customer
		if {[catch {set res [eval $queue_email_func $params]} msg]} {
			OT_LogWrite 2 "Failed to queue change of details email, $msg"
		}
	}

	# otherwise, display cust page
	go_cust cust_id $cust_id


}


proc do_delete_cust_group {cust_id group_value_id} {

	global DB

	# create query
	set sql "delete from
				tCustGroup
			where
				cust_id=$cust_id
			and group_value_id=$group_value_id"

	# do delete
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {inf_exec_stmt $stmt} msg]} {
		OT_LogWrite 2 "CUST: Error deleting cust group for cust_id $cust_id - $msg"
		tpSetVar ShowError 1
		tpBindString error_message "Error deleting customer group - $msg"
		go_cust_groups_detail
		return
	}

	# otherwise, display cust page
	go_cust cust_id $cust_id

}

proc zero_balances {} {

	global DB

	if {![op_allowed ZeroCPMBalance]} {
		ob_log::write INFO {User tried to zero balances but doesn't have perm}
		err_bind "Do not have permission to zero balances"
		return
	}

	set cust_id [reqGetArg CustId]

	set sql {
		update tCustPayMthd
		set balance = 0.00
		where cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $cust_id
	inf_close_stmt $stmt

	msg_bind "Balances updated successfully"
}


# retrieves and binds required information for a customers deposit limits
#
proc srp_get_cust_dep_limit {cust_id ccy_code} {

	global SRP_DEP_LIMITS

	set cur_dep_limit [ob_srp::get_deposit_limit $cust_id]

	if {[lindex $cur_dep_limit 0] != 1} {

		ob_log::write ERROR {Didn't get valid dep limits response: $cur_dep_limit}
		err_bind "Could not retrieve customer's deposit limit"
		return
	}

	set cur_type [lindex $cur_dep_limit 1]
	if {$cur_type == "none"} {
		set cur_amount ""
		set allow_increase 1
	} else {
		set cur_amount         [lindex $cur_dep_limit 2]
		set allow_increase     [lindex $cur_dep_limit 3]
	}

	set limit_field_value $cur_amount
	# get available deposit limits
	array set dep_limits [ob_srp::get_all_avail_dep_limits -ccy_code $ccy_code]

	if {[info exists dep_limits(${ccy_code}_total)]} {
		# has available deposit limits
		for {set i 0} {$i < $dep_limits(${ccy_code}_total)} {incr i} {
			set SRP_DEP_LIMITS($i,dep_limit) $dep_limits($ccy_code,$i)
			if { $cur_amount == $dep_limits($ccy_code,$i) } {
				set limit_field_value ""
			}
		}

		tpSetVar func_dep_limits 1
		tpSetVar num_dep_limits $dep_limits(${ccy_code}_total)
		tpSetVar dep_limit_allow_increase $allow_increase

		tpBindVar DepLimit     SRP_DEP_LIMITS dep_limit   dep_idx
	} else {

		tpSetVar func_dep_limits 0
		tpSetVar num_dep_limits  0
	}

	tpBindString CurDepLimit     	$cur_amount
	tpBindString CurLimitPeriod  	$cur_type
	tpBindString CurLimitFieldValue $limit_field_value
}



proc clear_self_excl {} {
	global DB USERNAME
	if {[op_allowed ClearSelfExcl]} {
		set cust_id [reqGetArg CustId]
		set rslt [ob_srp::clear_self_excl $cust_id]
		if {![lindex $rslt 0]} {
			err_bind "Error clearing self exclusion."
			return
		} else {
			msg_bind "Self exclusion cleared."

			if {[OT_CfgGet FUNC_SELF_EXCL_ENHANCE 0]} {
				#clear vet status
				set vet_code 0
				set vet_desc ""
				_upd_vet_code $cust_id $vet_code $vet_desc

				# Set status to Closed
				set sql {
					execute procedure pUpdCustStatus(
						p_adminuser = ?,
						p_cust_id = ?,
						p_status = ?,
						p_status_reason = ?
					)
				}

				set stmt [inf_prep_sql $DB $sql]

				if {[catch {
					set res [inf_exec_stmt $stmt\
						$USERNAME\
						[reqGetArg CustId]\
						"A"\
						"Self Exclusion Cleared"]
					catch {db_close $res}
				} msg]} {
					msg_bind "Unable to update customer status and contactable info: $msg"
				}
				inf_close_stmt $stmt
			}
		}
	} else {
		err_bind "User not permitted to clear self exclusion."
		return
	}
}



# get customers self exclusion status
#
proc srp_get_cust_self_excl {cust_id} {

	global SRP_EXCL_PERIODS

	if {[op_allowed SrpOverrideMin]} {
		tpSetVar SrpLimitLength 0
		tpBindString SrpMinLengthDays 0
	} else {
		tpSetVar SrpLimitLength 1
		tpBindString SrpMinLengthDays [OT_CfgGet SRP_SELF_EXCL_MIN_DAYS 180]
	}

	# See if the customer is in need of clearance.
	foreach {ok from_date to_date} [ob_srp::check_self_excl_clear_req $cust_id] {
		if {$ok} {
			tpSetVar self_exclusion_due_clearance 1
			tpBindString SelfExclFrom $from_date
			tpBindString SelfExclTo   $to_date
			return
		}
	}

	# get customers self exclusion status
	foreach {ok from_date to_date} [ob_srp::check_self_excl $cust_id] {}

	if {!$ok} {
		err_bind "Unable to retrieve self exclusion info."
		return
	}

	if {$to_date != ""} {

		tpSetVar self_exclusion_exists 1
		tpBindString SelfExclFrom $from_date
		tpBindString SelfExclTo   $to_date
	}

	# bind possible self-exclusion periods
	set count 0
	set period_list [split [OT_CfgGet ACCT_SRP_SELF_EXCL_PERIODS "6:M|1:Y|2:Y|3:Y|4:Y|5:Y"] "|"]
	foreach period $period_list {

		foreach {value type} [split $period ":"] {}
		set SRP_EXCL_PERIODS($count,value)    $value
		set SRP_EXCL_PERIODS($count,type)     [string toupper $type]
		set SRP_EXCL_PERIODS($count,string)   [srp_excl_string $value $type]
		incr count
	}

	tpSetVar func_self_excl 1
	tpSetVar num_excl_periods $count

	tpBindVar ExclValue      SRP_EXCL_PERIODS value       excl_idx
	tpBindVar ExclType       SRP_EXCL_PERIODS type        excl_idx
	tpBindVar ExclString     SRP_EXCL_PERIODS string      excl_idx

}



# returns display string for exclusion period
#
proc srp_excl_string {value type} {

	if {$type == "" || $value == "" || $value == 0} {
		return ""
	}

	set type [string toupper $type]

	switch -- $type {
		"M" {
			if {$value == 1} {
				set postfix "Month"
			} else {
				set postfix "Months"
			}
		}
		"Y" {
			if {$value == 1} {
				set postfix "Year"
			} else {
				set postfix "Years"
			}
		}
		default {
			ob_log::write ERROR {Unrecognised excl period type - $type}
			return ""
		}
	}

	return "$value $postfix"
}

#
#Customer breakdown proc.
#
proc go_cust_bet_summary args {

	tpBindString AcctId [reqGetArg AcctId]

	set grouped_classes [reqGetArg grouped_classes]
	set summary_type    [reqGetArg summary_type]

	switch -exact -- $summary_type {
		"F" {
			#Fixed odds bets
			if {![OT_CfgGet SPORT_CUST_BREAKDOWN_ENABLED 0]} {
				set msg "Customer breakdown for fixed-odds betting is configured-off"
				err_bind $msg
				OT_LogWrite INFO $msg
				return
			} else {
				_bind_sports_cust_bet_total "F" $grouped_classes
			}
		}
		"P" {
			#PMU pools betting
			if {![OT_CfgGet POOL_CUST_BREAKDOWN_ENABLED 0]} {
				set msg "Customer breakdown for pools betting is configured off"
				err_bind $msg
				OT_LogWrite INFO $msg
				return
			} else {
				_bind_sports_cust_bet_total "P" $grouped_classes
			}
		}
		"X" {
			#XGame/Lottery bets
			if {![OT_CfgGet XGAMES_CUST_BREAKDOWN_ENABLED 0]} {
				set msg "Customer breakdown for lottery betting is configured off"
				err_bind $msg
				OT_LogWrite INFO $msg
				return
			} else {
				_bind_xgames_cust_total
				tpSetVar is_xgame_summary 1
			}
		}
		default {
			err_bind "Unexpected total type"
			go_cust
			return
		}

	}

	asPlayFile -nocache cust_bet_total_summary.html
}



#
# Binds customer detailed breakdown for sports betting
# Params :
# -total_type (F)ixed odds betting or (P)ools
# -grouped_classes . Group classes other than horses, greyhounds, football into an "other" sport.
#
# Customer summary is for each total_type, sport, year is done by
# -price type (SP,LP,BP, etc)
# -channel (I,Telebet, etc)
# -In running
#
proc _bind_sports_cust_bet_total {total_type { grouped_classes "" }} {

	variable SUMMARY

	global DB

	GC::mark ADMIN::CUST::SUMMARY

	# Read config/requirements
	set breakdown_explicit_sorts [list "HR" "Horses" "GR" "Greyhounds" "FB" "Football"]

	set criteria [list]
	foreach c [list "on_course" "board_early_bird" "price_type" "channel" "in_running"] {
		if {[OT_CfgGet SUMMARY_LIST_${c} 1]} {
			lappend criteria $c
		}
	}
	ob_log::write INFO {Summary will be generated for - $criteria}

	set this_year [clock format [clock seconds] -format "%Y" ]
	set last_year [clock format [clock scan "last year"] -format "%Y" ]

	#initialise struture of array
	set SUMMARY(criteria) $criteria
	foreach c $criteria {

		set SUMMARY($c,name) [ml_printf "Admin.Bet_Summ.DETAILED_BREAKDOWN_BY_$c"]

		#initialise list of values for each criteria
		set SUMMARY($c,vals) [list]
		set SUMMARY($c,num_vals) 0

		#initialise sports
		set SUMMARY($c,sports) [list]
		foreach {s d} $breakdown_explicit_sorts {
			lappend SUMMARY($c,sports) $s
			set SUMMARY($c,$s,sportdesc) $d
		}

		if {$grouped_classes == "Y"} {
			lappend SUMMARY($c,sports) "OT"
			set SUMMARY($c,OT,sportdesc) "Other"
		}

		if {[OT_CfgGet FUNC_SUMMARIZE_ONCOURSE_BETS 0]} {
			lappend SUMMARY($c,sports) "OC"
			set SUMMARY($c,OC,sportdesc) "On Course Book"
		}

	}

	set sql {

		select
			extend(start_date, year to year) as bet_year,
			t.ev_class_id,
			t.price_type,
			DECODE(t.board_early_bird,'e','Board','b','Early bird','n','Neither board nor early bird',t.board_early_bird) as board_early_bird,
			t.in_running,
			t.source as channel,
			t.total_type,
			DECODE(t.on_course,'Y','On Course','N','Not On Course') as on_course,
			c.sort,
			NVL(c.category, 'MANUAL') as category,
			sum(t.stake) as stake,
			sum(t.returns) as returns,
			sum(t.count) as num_bets
		from
			tBetSummary t,
			outer tEvClass c
		where
			t.acct_id = ? and
			c.ev_class_id = t.ev_class_id and
			total_type = 'F'
		group by 1,2,3,4,5,6,7,8,9,10
		order by bet_year desc, category asc
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[ catch {
		set res  [inf_exec_stmt $stmt [reqGetArg AcctId] $total_type]
	} msg ]} {
		inf_close_stmt $stmt
		OT_LogWrite ERROR "could not query tCustBetTotal in cust.tcl : $msg"
		err_bind $msg
		go_cust
		return
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	#read result set and dispatch data into SUMMARY array
	for {set i 0 } {$i < $nrows} {incr i} {

		foreach c [db_get_colnames $res] {
			set $c [db_get_col $res $i $c]
		}

		#when?
		#if year of row is this year or last year, append data to corresponding year and 'cumulated' columns
		#of SUMMARY array. Otherwise add data to 'cumulated' column only.
		if {$bet_year == $this_year} {
			set years [list "$this_year" "cumulated"]
		} elseif {$bet_year == $last_year} {
			set years [list "$last_year" "cumulated"]
		} else {
			set years "cumulated"
		}

		#which sport?
		if {[lsearch $breakdown_explicit_sorts $sort] != -1 } {
			set k $sort
		} elseif {[OT_CfgGet FUNC_SUMMARIZE_ONCOURSE_BETS 0] &&
			      $sort == "" && $on_course == "On Course"} {
			set k "OC"
		} elseif {$grouped_classes == "Y"} {
			set k "OT"
		} else {
			set k $category
			foreach c $criteria {
				if {[lsearch $SUMMARY($c,sports) $k] == -1} {
					lappend SUMMARY($c,sports) $k
					set SUMMARY($c,$k,sportdesc) $k
				}
			}
		}

		#build row
		foreach crit $criteria {

			set current_criteria_value [db_get_col $res $i $crit]

			if {[lsearch $SUMMARY($crit,vals) $current_criteria_value] == -1} {
				lappend SUMMARY($crit,vals) $current_criteria_value
				incr SUMMARY($crit,num_vals)
			}

			foreach l $years {

				if {![info exists SUMMARY($crit,$l,$current_criteria_value,total_init)]} {
					set SUMMARY($crit,$l,$current_criteria_value,total_init) 1
					set SUMMARY($crit,$l,$current_criteria_value,total_stake) 0
					set SUMMARY($crit,$l,$current_criteria_value,total_returns) 0
					set SUMMARY($crit,$l,$current_criteria_value,total_num_bets) 0
				}

				if {[info exists SUMMARY($crit,$k,$l,$current_criteria_value,data_init)]} {

					foreach data {stake returns num_bets} {
						set curr_data_value [db_get_col $res $i $data]
						set SUMMARY($crit,$k,$l,$current_criteria_value,$data)    [expr {$SUMMARY($crit,$k,$l,$current_criteria_value,$data) + $curr_data_value}]
						set SUMMARY($crit,$l,$current_criteria_value,total_$data) [expr $SUMMARY($crit,$l,$current_criteria_value,total_$data) + $curr_data_value]
					}

				} else {

					foreach data {stake returns num_bets} {
						set curr_data_value [db_get_col $res $i $data]
						set SUMMARY($crit,$k,$l,$current_criteria_value,data_init) 1
						set SUMMARY($crit,$k,$l,$current_criteria_value,$data)    $curr_data_value
						set SUMMARY($crit,$l,$current_criteria_value,total_$data) [expr $SUMMARY($crit,$l,$current_criteria_value,total_$data) + $curr_data_value]
					}
				}
			}
		}

		# Format all the totals to 2dp.
		foreach crit $criteria {

			set current_criteria_value [db_get_col $res $i $crit]
			foreach l $years {
				foreach data {stake returns num_bets} {
					set SUMMARY($crit,$k,$l,$current_criteria_value,$data)    [format "%.2f" $SUMMARY($crit,$k,$l,$current_criteria_value,$data)]
					set SUMMARY($crit,$l,$current_criteria_value,total_$data) [format "%.2f" $SUMMARY($crit,$l,$current_criteria_value,total_$data)]
				}
			}
		}
	}


	#bind stuff for template player
	tpBindString ThisYear $this_year
	tpBindString LastYear $last_year

	foreach c {
		name
		num_vals
		vals
		sports
	} {
		tpBindVar criteria_$c ADMIN::CUST::SUMMARY $c criteria
	}

	tpBindVar sport_sportdesc ADMIN::CUST::SUMMARY sportdesc criteria sport


	foreach c {
		stake
		returns
		num_bets
	} {
		tpBindVar $c ADMIN::CUST::SUMMARY $c criteria sport year val
	}

	foreach c {
		total_stake
		total_returns
		total_num_bets
	} {
		tpBindVar $c ADMIN::CUST::SUMMARY $c criteria year val
	}

	catch {db_close $res}

}



#
#
#
proc _bind_xgames_cust_total args {

	global DB XGAMES_SUMMARY

	GC::mark XGAMES_SUMMARY

	set this_year [clock format [clock seconds] -format "%Y" ]
  	set last_year [clock format [clock scan "last year"] -format "%Y" ]

	set sql {
		select
			t.acct_id,
			extend(t.start_date,year to year) as bet_year,
			t.source,
			c.desc,
			sum(t.stake) as stake,
			sum(t.returns) as returns,
			sum(t.count) as num_bets
		from
			tXGameSummary t,
			tChannel c
		where
			t.acct_id    = ? and
			c.channel_id = t.source
		group by 1,2,3,4
		order by source asc, bet_year desc
	}


	set stmt [inf_prep_sql $DB $sql ]

	if {[ catch {
		set res  [inf_exec_stmt $stmt [reqGetArg AcctId] ]
	} msg ]} {
		inf_close_stmt $stmt
		OT_LogWrite ERROR "could not query tXGameCustBetTotal in cust.tcl : $msg"
		err_bind $msg
		go_cust
		return
	}


	inf_close_stmt $stmt

	set source_indx 0
	set curr_source ""

	for {set j 0 } { $j < 3 } {incr j} {
		set TOTALXGAMES($j,stake) 0.0
		set TOTALXGAMES($j,returns) 0.0
		set TOTALXGAMES($j,num_bets) 0
	}

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

		set source         [db_get_col $res $i source]
		set bet_year  	   [db_get_col $res $i bet_year]
		set channel_desc   [db_get_col $res $i desc]


		#find column
		if {$bet_year == $this_year} {
			set c 0
		} elseif {$bet_year == $last_year} {
			set c 1
		} else {
			set c 2
		}

		#find row
		if {$source == $curr_source} {
			set r [expr { $source_indx - 1}]
		} else {
			set r $source_indx
			set XGAMES_SUMMARY($source_indx,channel) $channel_desc
			incr source_indx
		}

		#start filling data
		#if data if earlier than last year, only update cumulated field
		if { $c == 2 } {
			set cols [list "$c" ]
		} else {
			set cols [list "$c" "2"]
		}
		foreach c $cols {
			foreach data {stake returns num_bets} {
				set curr_data_value [db_get_col $res $i $data]
				set TOTALXGAMES($c,$data) [ expr { $TOTALXGAMES($c,$data) + $curr_data_value } ]

				if { [ info exists XGAMES_SUMMARY($r,$c,$data) ] } {
					set XGAMES_SUMMARY($r,$c,$data) [ expr { $XGAMES_SUMMARY($r,$c,$data) + $curr_data_value } ]
				} else {
					set XGAMES_SUMMARY($r,$c,$data) $curr_data_value
				}
			}
		}

		set curr_source $source
	}

	catch {db_close $res}

	tpSetVar XGameNumChannels $source_indx

	#bind stuff for template player

	tpBindString ThisYear $this_year
	tpBindString LastYear $last_year

	tpBindString TotalXGameStakeThisYear       $TOTALXGAMES(0,stake)
	tpBindString TotalXGameReturnsThisYear     $TOTALXGAMES(0,returns)
	tpBindString TotalXGameNumBetsThisYear     $TOTALXGAMES(0,num_bets)
	tpBindString TotalXGameStakeLastYear       $TOTALXGAMES(1,stake)
	tpBindString TotalXGameReturnsLastYear     $TOTALXGAMES(1,returns)
	tpBindString TotalXGameNumBetsLastYear     $TOTALXGAMES(1,num_bets)
	tpBindString TotalXGameStakeCumulated      $TOTALXGAMES(2,stake)
	tpBindString TotalXGameReturnsCumulated    $TOTALXGAMES(2,returns)
	tpBindString TotalXGameNumBetsCumulated	   $TOTALXGAMES(2,num_bets)

	tpBindVar XGAMESChanDesc XGAMES_SUMMARY channel   XGames_chan_idx

	foreach c {
		stake
		returns
		num_bets
	} {
		tpBindVar XGAMES_$c    XGAMES_SUMMARY $c     XGames_chan_idx XGames_year_idx
	}

}



#
# Tag the current account with the entered NetRefer banner tag
#
# This account must be registered with NetRefer immediately and if a full report
# is requested then a customer status flag is created so that the report
#
proc _tag_netrefer_customer {} {
	global DB

	set cust_id        [reqGetArg CustId]
	set banner_tag     [reqGetArg BannerTag]
	set report_date    [reqGetArg NetRefDate]
	set request_report [reqGetArg RequestReport]

	inf_begin_tran $DB

	if {[catch {

		if {$request_report == "Y"} {
			# We want the next report to backdate to the beginning of the month
			set report_date [clock format [clock seconds] -format "%Y-%m-01 00:00:00"]
		}

		set stmt [inf_prep_sql $DB {
			execute procedure pTagNetRefCust (
				p_cust_id        = ?,
				p_banner_tag     = ?,
				p_report_date    = ?
			)
		}]

		set res [inf_exec_stmt $stmt $cust_id $banner_tag $report_date]
		inf_close_stmt $stmt

		set ins_upd_code [db_get_coln $res 0 0]
		set ins_upd_num  [db_get_coln $res 0 1]
		db_close $res

		if {$ins_upd_code == "I" && $ins_upd_num == 1} {
			# Banner Tag was inserted so update the NetRefer Affiliate
			set stmt [inf_prep_sql $DB {
				execute procedure pXSysSyncByType (
					p_sync_op        = 'B',
					p_ref_id         = ?
				)
			}]

			inf_exec_stmt $stmt $cust_id
			inf_close_stmt $stmt
		}

	} msg]} {
		inf_rollback_tran $DB
		err_bind $msg
	} else {
		inf_commit_tran $DB
		msg_bind "Account successfully tagged"
	}
}



# Bind customer identification information
#
#    cust_id - customer identifier
#
proc _bind_cust_ident { cust_id } {

	global DB

	if {[OT_CfgGet FUNC_OVS 0]} {
		tpBindString IdentAgeVrfStatus [verification_check::get_ovs_status $cust_id "AGE"]
	}

	set sql {
		select
			first 1 cust_id
		from
			tCustIdent
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql ]

	set res [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	if {[db_get_nrows $res]} {
		tpBindString IdentSet "Yes"
	} else {
		tpBindString IdentSet "No"
	}

	db_close $res

	if {[OT_CfgGet FUNC_KYC 0]} {
		# get kyc status
		foreach {status reason notes} [ADMIN::KYC::get_kyc_status $cust_id] {}
		tpBindString IdentKYCStatus $status
	}

}



#
# Switch on with FUNC_MANUALLY_LINK_ACCTS=1 and must have permission ExtIdFunc
#
proc do_manually_link_acct {} {

	set cust_id     [reqGetArg CustId]
	set username    [reqGetArg LinkUsername]
	set ext_cust_id [reqGetArg ExtCustId]

	# the tExtCustIdent.code value for linking customer internally
	# Note: this is not 'switched on' by default, 1 is the value of the code
	set ident_code [OT_CfgGet INTERNAL_EXT_CUST_IDENT_CODE 1]

	OT_LogWrite INFO "do_manually_link_acct {cust_id=$cust_id; username=$username; ext_cust_id=$ext_cust_id; ident_code=$ident_code}"

	if {$username != ""} {
		do_manually_link_username $cust_id $username $ident_code

	} elseif {$ext_cust_id != ""} {
		do_manually_link_ext_cust_id $cust_id $ext_cust_id $ident_code

	} else {
		OT_LogWrite DEBUG "Missing form data (username=$username; group=$ext_cust_id)"
		err_bind "Missing form data (username=$username; group=$ext_cust_id)"
	}
}


#
# Admin user wants to add cust_id to same group that username is in.
#
proc do_manually_link_username {cust_id username ident_code} {
	global DB

	OT_LogWrite INFO "do_manually_link_username {cust_id=$cust_id; username=$username; ident_code=$ident_code}"

	if {[reqGetArg LBOCustomer] == "Y"} {
		# Shop account usernames are all preceded by 1 space
		set username " [string trimleft $username]"
	}

	set sql {
		select
			c.cust_id,
			e.ext_cust_id,
			e.version
		from
			tCustomer c,
			outer tExtCust e
		where
			c.cust_id = e.cust_id
		and
			e.code = ?
		and
		  	c.username = ?
		and
			c.cust_id <> ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ident_code $username $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {$nrows == 0} {
		err_bind "Trying to link account to itself or '$username' doesn't exist"
		db_close $res
	} else {
		# all is well...

		# need to know which account we're looking at.
		# A is the account whose customer page we've just been looking at.
		# B is the account which we're trying to link to (ie the username entered)

		set username_A    [reqGetArg Username]
		set cust_id_A     $cust_id
		set ext_cust_id_A [reqGetArg ExtCustGroup]
		set version_A     [reqGetArg ExtCustGroupVersion]
		set group_count_A [reqGetArg ExtCustGroupCount]

		set username_B    $username
		set cust_id_B     [db_get_col $res 0 cust_id]
		set ext_cust_id_B [db_get_col $res 0 ext_cust_id]
		set version_B     [db_get_col $res 0 version]

		db_close $res

		if {$ext_cust_id_B == ""} {
			set group_count_B 0
		} else {

			# Select the number of customers in the group containing customer B
			set sql {
				select
					count(*) as count
				from
					tExtCust
				where
					code = ?
				and
					ext_cust_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $ident_code $ext_cust_id_B]
			inf_close_stmt $stmt

			set group_count_B [db_get_col $res 0 count]

			db_close $res
		}


		if {![info exists version_A] || $version_A == ""} {
			set version_A 1
		}
		if {![info exists version_B] || $version_B == ""} {
			set version_B 1
		}


		# both accounts are already in groups of more than 1 customer?
		if {$group_count_A > 1 && $group_count_B > 1} {
			if {$ext_cust_id_A == $ext_cust_id_B} {
				err_bind "Accounts are already linked to each other in group $ext_cust_id_A"
			} else {
				err_bind "Accounts are already linked to other groups ($username_A=>$ext_cust_id_A; $username_B=>$ext_cust_id_B)"
			}

		# only account A is already in a group of more than 1 customer
		} elseif {$group_count_A > 1} {

			if {$group_count_B == 1} {
				# remove account B from its group
				_remove_acct_from_group $cust_id_B $ident_code $ext_cust_id_B
			}

			# then insert account B into group A
			ins_new_acct_link $cust_id_B $ident_code $ext_cust_id_A N $version_A

		# only account B is already in a group of more than 1 customer
		} elseif {$group_count_B > 1} {

			if {$group_count_A == 1} {
				# remove account A from its group
				_remove_acct_from_group $cust_id_A $ident_code $ext_cust_id_A
			}

			# then insert account A into group B
			ins_new_acct_link $cust_id_A $ident_code $ext_cust_id_B N $version_B

		# account A has a group
		} elseif {$group_count_A == 1} {

			if {$group_count_B == 1} {
				# remove account B from its group
				_remove_acct_from_group $cust_id_B $ident_code $ext_cust_id_B
			}

			# then insert account B into group A
			ins_new_acct_link $cust_id_B $ident_code $ext_cust_id_A N $version_A

		# only account B has a group
		} elseif {$group_count_B == 1} {

			# then insert account A into group B
			ins_new_acct_link $cust_id_A $ident_code $ext_cust_id_B N $version_B

		# both accounts do not have a group
		} else {

			# generate a new group id...
			if {[set new_ext_cust_id [get_ext_cust_id]] == -1} break

			# insert the new links and make A the master...for no particular reason!
			ins_new_acct_link $cust_id_A $ident_code $new_ext_cust_id Y $version_A
			ins_new_acct_link $cust_id_B $ident_code $new_ext_cust_id N $version_B
		}
	}
}



#
# Admin user wants to add cust_id to group ext_cust_id
#
proc do_manually_link_ext_cust_id {cust_id ext_cust_id ident_code} {
	global DB

	OT_LogWrite INFO "do_manually_link_ext_cust_id {cust_id=$cust_id; ext_cust_id=$ext_cust_id; ident_code=$ident_code}"


	# check if the group exists...
	set sql [subst {
		select first 1
			e.ext_cust_id
		from
			tExtCust e
		where
			e.ext_cust_id = ?
		and
			e.code = $ident_code
	}]
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ext_cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	db_close $res

	if {$nrows != 1} {
		err_bind "Group $ext_cust_id doesn't exist"
		return
	}

	# the current users group details
	set cur_ext_cust_id [reqGetArg ExtCustGroup]
	set cur_version     [reqGetArg ExtCustGroupVersion]
	set cur_group_count [reqGetArg ExtCustGroupCount]

	if {$cur_ext_cust_id == $ext_cust_id} {
		err_bind "This user is already in group $ext_cust_id"
	} elseif {$cur_group_count > 1} {
		err_bind "This user is already in group $cur_ext_cust_id"
	} else {
		# user isn't in a group...
		if {$cur_group_count == 1} {
			# remove the current account from its group
			_remove_acct_from_group $cust_id $ident_code $cur_ext_cust_id
		}
		# add the current account to the new group
		ins_new_acct_link $cust_id $ident_code $ext_cust_id N $cur_version
	}
}


#
# Reward adhoc token to the customer
#
proc do_reward_adhoc_token {} {
	global DB TOKENS
	variable CFG

	set cust_id     [reqGetArg CustId]

	ob_log::write DEBUG {do_reward_adhoc_token}
	OT_LogWrite INFO "do_reward_adhoc_token {cust_id=$cust_id}"

	if {![op_allowed AdHocTokenReward]} {
		ob_log::write INFO {User does not have permission to reward Adhoc Tokens}
		return
	}

	set potential_tokens 0
	set granted 0

	#Get token details from arguments
	set value   [reqGetArg Value]
	set abs_exp [reqGetArg AbsoluteEx]
	set rel_exp [reqGetArg RelativeEx]
	set rval_id [reqGetArg RValID]
	set ccy_code [reqGetArg CcyCode]

	set granted [_grant_token $cust_id $value $abs_exp $rel_exp $rval_id $ccy_code]

	if {$granted} {
		msg_bind "Token succesfully granted"
	}
}


#
# Adapted from CM::freebets::adhoc::_grant_token
#
# Actually calls the sql to grant a token
#
proc _grant_token {cust_id value {abs_exp ""} {rel_exp ""} redemp_id ccy_code} {
	global DB
	variable CFG

	if {![string is double -strict $value]} {
		err_bind "Amount must be not empty and a number"
		return 0
	} elseif {$ccy_code == ""} {
		err_bind "Ccy code not found for token reward"
		return 0
	} elseif {$abs_exp == "" && $rel_exp == ""} {
		err_bind "One of absolute expiry and relative expiry fields must be populated"
		return 0
	}

	if {[OT_CfgGet USE_ADHOC_TOKEN_THRESHOLDS 0]} {
		set no_perm [_check_adhoc_token_threshold\
			$value\
			[split [OT_CfgGet ADHOC_TOKEN_THRESHOLDS 0] ","]\
			$ccy_code]

		if {$no_perm == 0} {
			err_bind "You are attempting to reward a token above your permitted limit"
			return 0
		}
	}

	set sql [subst {
		execute procedure pCreateAdhocToken(
			p_cust_id = ?,
			p_value   = ?,
			p_absolute_expiry = ?,
			p_relative_expiry = ?,
			p_adhoc_redemp_id = ?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]


	if {[catch {
		set rs [inf_exec_stmt $stmt $cust_id $value $abs_exp $rel_exp $redemp_id]
	} msg]} {
		ob_log::write ERROR "do_reward_adhoc_token cust_id $cust_id value $value expiry \
					$abs_exp $rel_exp redemp_id $redemp_id"
		ob_log::write ERROR "do_reward_adhoc_token $msg"
		err_bind $msg
		return 0
	}
	inf_close_stmt $stmt

	set result [db_get_coln $rs 0 0]
	db_close $rs

	if {$result == 0} {
		err_bind "Failed to create adhoc token for cust $cust_id"
		return 0
	}

	return 1
}


#
# Taken from CM::freebets::adhoc::_check_adhoc_token_threshold
#
# check user has permission to reward an adhoc token
# given the amount and threshold levels
#
# amount - amount to be awarded
# tlimits - threshold limits for each level
# ccy - ccy of the customer to be awarded the token
#
proc _check_adhoc_token_threshold {amount tlimits ccy} {
	set amount [format %0.2f $amount]

	# Not dealing with negative amounts
	if {$amount < 0} {
		set amount [expr abs($amount)]
	}

	# Just in case, we sort these in order
	set tlimits [lsort -integer $tlimits]

	# Special Case: Unlimited
	if {[op_allowed AdHocTokenRewardUnlim] || [op_allowed AdHocUnlimited]
		|| ([op_allowed AdHocTokenRewardUnlim] && $amount > [lindex $tlimits end])
		|| ([op_allowed AdHocUnlimited] && $amount > [lindex $tlimits end])
		} {
		return 1
	}

	set tlimits [concat 0 $tlimits]

	for {set l [expr {[llength $tlimits] - 1}]} {$l > 0} {incr l -1} {
		set upper [lindex $tlimits $l]

		if {$amount > [convert_to_ccy $upper $ccy]} {
			return 0
		} else {
			if {[op_allowed AdHocTokenRewardLevel$l] || [op_allowed AdHocRewardLevel$l]} {
				return 1
			}
		}
	}

	return 0
}



#
# Returns the next group id, -1 on error
#
proc get_ext_cust_id {} {
	global DB

	# queries stolen from the urn matcher...
	set get_urn_serial {
		select
			urn_serial
		from
			tURNMatchControl
	}

	set increase_urn_serial {
		update
			tURNMatchControl
		set
			urn_serial = urn_serial + 1
	}

	# get the next urn id...
	set stmt [inf_prep_sql $DB $get_urn_serial]
	if [catch {set res [inf_exec_stmt $stmt]} msg] {
		OT_LogWrite ERROR "Error executing get_urn_serial: $msg"
		err_bind "Error generating group id"
		return -1
	}
	inf_close_stmt $stmt

	set id [db_get_col $res 0 urn_serial]
	db_close $res

	# increase the id for the next time...
	set stmt [inf_prep_sql $DB $increase_urn_serial]
	if [catch {set res [inf_exec_stmt $stmt]} msg] {
		OT_LogWrite ERROR "Error executing increase_urn_serial: $msg"
		err_bind "Error increasing group id"
		return -1
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	# add an L to the start of the id...
	return "L$id"
}



#
# Insert a row into tExtCust.
#
proc ins_new_acct_link {cust_id code ext_cust_id master {version 1} {permanent N}} {
	global DB

	OT_LogWrite INFO "ins_new_acct_link {cust_id=$cust_id; code=$code; ext_cust_id=$ext_cust_id; master=$master permanent=$permanent, version=$version}"

	if {$version == ""} {
		set version 1
	}

	set ins_link [subst {
		insert into tExtCust (cust_id,code,ext_cust_id,permanent,master,version)
		values (?,?,?,?,?,?)
	}]
	set stmt [inf_prep_sql $DB $ins_link]
	set res  [inf_exec_stmt $stmt $cust_id $code $ext_cust_id $permanent $master $version]
	inf_close_stmt $stmt
	catch {db_close $res}
}



#
# Remove a customer from their current linked group
#
proc do_remove_link_acct {} {

	global DB

	set cust_id        [reqGetArg CustId]
	set ext_cust_group [reqGetArg ExtCustGroup]
	set ident_code     [reqGetArg IdentCode]

	ob::log::write INFO "removing cust id $cust_id from group $ext_cust_group"

	if {$ext_cust_group != ""} {

		set sql [subst {
			select
				cust_id,
				master
			from
				tExtCust
			where
				code = ? and
				ext_cust_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ident_code $ext_cust_group]
		inf_close_stmt $stmt
		set nrows [db_get_nrows $res]

		# now just check if the customer was found
		set cust_exists 0
		for {set i 0} {$i < $nrows} {incr i} {
			if {$cust_id == [db_get_col $res $i cust_id]} {
				set cust_exists 1
			}
		}
		db_close $res

		if {$nrows == 0 || !$cust_exists} {
			ob::log::write ERROR "Error: could not find cust_id $cust_id in
			 group $ext_cust_group with code $ident_code"
			err_bind "Could not find customer in group $ext_cust_group"

		} else {

			_remove_acct_from_group $cust_id $ident_code $ext_cust_group
			msg_bind "Successfully removed customer from group $ext_cust_group"

			set ext_cust_id [get_ext_cust_id]
			ins_new_acct_link $cust_id $ident_code $ext_cust_id Y

			ob::log::write INFO "successfully added cust id $cust_id to group $ext_cust_id"
		}

	} else {
		ob::log::write ERROR "Error: ext_cust_id is null, cannot remove customer from group"
		err_bind "Unable to determine customer's group"
	}
}



#
# Remove a customer from an external linked group
#
proc _remove_acct_from_group {cust_id code ext_cust_id} {

	global DB

	set sql {
		delete from
			tExtCust
		where
			cust_id = ? and
			code = ? and
			ext_cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $cust_id $code $ext_cust_id
	inf_close_stmt $stmt

	ob::log::write INFO "successfully removed cust id $cust_id from group $ext_cust_id"
}



# Handler for ajax request to get a customers playtech system balances
#
proc get_ajax_playtech_balance {} {

	global DB

	set username [reqGetArg username]
	set system   [reqGetArg system]

	set sql {
		select
			password
		from
			tcustomer
		where
			username = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $username]

	if  {[db_get_nrows $res] != 1} {
		inf_close_stmt $stmt
		db_close $res
		OT_LogWrite 5 "get_ajax_playtech_balance - failed to find user: $username"
		return
	}

	set password [db_get_col $res 0 password]
	inf_close_stmt $stmt
	db_close $res

	# Get balance of playtech 'system'
	# get the systems
	set playtech_systems [playtech::get_cfg systems]

	set resp ""

	foreach system $playtech_systems {

		playtech::configure_request -channel "P" -is_critical_request "N"
 		playtech::get_playerinfo $username $password $system

 		if {[playtech::status] == "OK"} {
 			set balance [playtech::response balance]
			if {$balance != ""} {
				set balance [format %0.2f $balance]
			}
			set bonus [playtech::response bonusbalance]
			if {$bonus != ""} {
				set bonus [format %0.2f $bonus]
			}
			set frozen        [playtech::response frozen]
			set nickname      [playtech::response pokernickname]
		} else {
			set balance  [playtech::code]
			set bonus    [playtech::code]
			set frozen   [playtech::code]
			set nickname [playtech::code]
		}

		append resp "$system|$balance|$bonus|$frozen|$nickname|"

	}

	tpBufWrite $resp
}



#
# Closes a logged punter, by closing the associated account and changing
# the username (so the log number can be re-used).
#
proc do_logged_punter_close args {

	global DB

	# Check that this operation is allowed
	if {![op_allowed CloseLoggedPunters]} {
		err_bind "You don't have permission to close this account"
		return
	}

	set username [reqGetArg Username]
	set cust_id  [reqGetArg CustId]

	#
	# Change username to include CLOSED
	#

	# Check for other closed logged punters with this shop and log number
	set sql [subst {
		select
			username
		from
			tCustomer
		where
			username like '${username}_CLOSED_%'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	# Generate the closed log number
	set max_user_num 0
	for {set i 0} {$i < $nrows} {incr i} {
		set last_username [db_get_col $rs $i username]
		set user_num [string trimleft [regexp -inline {[\d]+$} $last_username] 0]
		if {$user_num > $max_user_num} {
			set max_user_num $user_num
		}
	}

	db_close $rs

	incr max_user_num

	set username_closed "${username}_CLOSED_${max_user_num}"

	# Begin transaction in case status/username update fails
	inf_begin_tran $DB

	set msg [upd_username $cust_id $username_closed 0]

	if {$msg != "OK"} {
		inf_rollback_tran $DB
		ob_log::write ERROR {ADMIN::CUST::do_logged_punter_activate: Unable \
								change username cust_id = $cust_id, $msg}
		err_bind "Unable to change username - $msg"
		return
	}

	#
	# Close the punter's account
	#

	if {[catch {
			set sql [subst {
				execute procedure pUpdCustStatus (
					p_cust_id = $cust_id,
					p_status = 'C',
					p_status_reason = 'Logged punter account no longer needed'
				);
			}]

			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt
			inf_close_stmt $stmt

		} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR {ADMIN::CUST::do_logged_punter_activate: Unable \
								to close account cust_id = $cust_id, $msg}
		err_bind "Unable to close account - $msg"
	} else {
		inf_commit_tran $DB
		msg_bind "Logged punter successfully closed"
	}

}



#
# Re-opens a previously closed logged punter.  Checks for a current log
# number is valid, if not then gets user to input a new one.  If this is
# valid, then change the customer's username and reactivate the account.
#
proc do_logged_punter_activate args {

	global DB

	# Check that this operation is allowed
	if {![op_allowed CloseLoggedPunters]} {
		err_bind "You don't have permission to close this account"
		return
	}

	# Check to see if a new manual log number has been added
	set new_log_no [reqGetArg NewLogNo]
	set username   [reqGetArg Username]
	set cust_id    [reqGetArg CustId]

	if {$new_log_no == ""} {
		# Check for the current log number already being in use
		regsub {_CLOSED_[\d]+$} $username "" username_new
	} else {
		# User provided new log number, ammend new username, if a number
		if {[regexp {^[\d]+$} $new_log_no]} {
			regsub {[\d]+_CLOSED_[\d]+$} $username $new_log_no username_new
		} else {
			err_bind "The log number provided must be a number"
			tpSetVar NeedNewLog 1
			return
		}
	}

	set sql [subst {
		select
			username
		from
			tCustomer
		where
			username = '$username_new'
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# If there is something returned, need to get the user to input new log
	if {[db_get_nrows $rs] > 0} {
		if {$new_log_no == ""} {
			err_bind "The old log number for this punter has been reused,\
													please enter a new one."
		} else {
			err_bind "That log number is already in use, please enter a new one."
		}
		tpSetVar NeedNewLog 1
		return
	} else {
		tpSetVar NeedNewLog 0
	}

	# Begin transaction in case status/username update fails
	inf_begin_tran $DB

	set msg [upd_username $cust_id $username_new 0]

	if {$msg != "OK"} {
		inf_rollback_tran $DB
		ob_log::write ERROR {ADMIN::CUST::do_logged_punter_activate: Unable \
								change username cust_id = $cust_id, $msg}
		err_bind "Unable to change username - $msg"
		return
	}

	# If reached this point then we can reactivate the account
	if {[catch {
			set sql [subst {
				execute procedure pUpdCustStatus (
					p_cust_id = $cust_id,
					p_status = 'A',
					p_status_reason = 'Re-opening logged user account'
				);
			}]

			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt
			inf_close_stmt $stmt
		} msg]} {
		inf_rollback_tran $DB
		ob_log::write ERROR {ADMIN::CUST::do_logged_punter_activate: Unable \
								to reactivate account cust_id = $cust_id, $msg}
		err_bind "Unable to activate account - $msg"
	} else {
		inf_commit_tran $DB
		msg_bind "Logged punter reactivated successfully"
	}
}



#
# Get Video Streaming groups for which the customer has qualified
#
proc go_cust_qual_bets {} {
	global DB VS_QUAL_BETS
	array unset VS_QUAL_BETS

	set cust_id [reqGetArg CustId]
	tpBindString CustId $cust_id

	set from_date [reqGetArg BetDate1]
	set to_date   [reqGetArg BetDate2]

	set where [mk_between_clause "and b.cr_date" date $from_date $to_date]

	set vs_qual_sql [subst {
		select
			qb.name,
			qbo.ob_level,
			qbo.ob_id,
			b.cr_date,
			b.bet_id,
			b.receipt,
			gc.status,
			gc.qlfy_bet_id
		from
			tVSQualifyBet qb,
			tVSQualifyBetOn qbo,
			tVSGroupCust gc,
			tBet b
		where
			    gc.cust_id = ?
			$where
			and gc.qlfy_bet_id = qb.qlfy_bet_id
			and gc.qlfy_bet_id = qbo.qlfy_bet_id
			and gc.bet_id = b.bet_id
		order by
			gc.qlfy_bet_id
	}]

	set stmt [inf_prep_sql $DB $vs_qual_sql]
	set res  [inf_exec_stmt $stmt $cust_id $from_date $to_date]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	set bet_count -1
	set previous -1

	for {set i 0} {$i < $nrows} {incr i} {
		set qlfy_bet_id [db_get_col $res $i qlfy_bet_id]
		set level       [db_get_col $res $i ob_level]
		set id          [db_get_col $res $i ob_id]

		if {$qlfy_bet_id != $previous} {
			set previous $qlfy_bet_id
			incr bet_count
			set sub_count 0

			set VS_QUAL_BETS($bet_count,name)    [db_get_col $res $i name]
			set VS_QUAL_BETS($bet_count,date)    [db_get_col $res $i cr_date]
			set VS_QUAL_BETS($bet_count,receipt) [db_get_col $res $i receipt]
			set VS_QUAL_BETS($bet_count,bet_id)  [db_get_col $res $i bet_id]
			set VS_QUAL_BETS($bet_count,status)  [db_get_col $res $i status]
		}

		switch -- $level {
			CLASS {
				set qual_details_sql {select name from tEvClass where ev_class_id = ?}
			}
			TYPE  {
				set qual_details_sql {select name from tEvType where ev_type_id = ?}
			}
			EVENT {
				set qual_details_sql {select desc as name from tEv where ev_id = ?}
			}
		}

		set stmt [inf_prep_sql $DB $qual_details_sql]
		set r2   [inf_exec_stmt $stmt $id]
		inf_close_stmt $stmt

		if {[db_get_nrows $r2] == 1} {
			set VS_QUAL_BETS($bet_count,$sub_count,name) [ob_xl::XL [ob_xl_compat::get_lang] [db_get_col $r2 0 name]]
		} else {
			set VS_QUAL_BETS($bet_count,$sub_count,name) "unknown item"
		}

		set VS_QUAL_BETS($bet_count,$sub_count,level) $level

		incr sub_count
		set VS_QUAL_BETS($bet_count,num_bets) $sub_count

		db_close $r2
	}

	tpSetVar NumQualBets [expr {$bet_count + 1}]

	tpBindVar QualName       VS_QUAL_BETS name     qual_idx
	tpBindVar QualDate       VS_QUAL_BETS date     qual_idx
	tpBindVar QualBetReceipt VS_QUAL_BETS receipt  qual_idx
	tpBindVar QualBetId      VS_QUAL_BETS bet_id   qual_idx
	tpBindVar QualStatus     VS_QUAL_BETS status   qual_idx
	tpBindVar QualSubCount   VS_QUAL_BETS num_bets qual_idx
	tpBindVar QualSubName    VS_QUAL_BETS name     qual_idx qual_sub_idx
	tpBindVar QualSubLevel   VS_QUAL_BETS level    qual_idx qual_sub_idx

	db_close $res

	asPlayFile -nocache cust_qual_bet_list.html
}



#
# Takes a cust_id and a new username and sets the customer to have this new
# name.
#
# - cust_id:         cust_id to change the username of
# - unsername_new:   the username we're changing it to
#
# - returns: "OK" if successful, otherwise returns an error message
#
proc upd_username { cust_id username_new {no_upd_acct_no 0}} {

	global DB

	# Do the update
	if {$no_upd_acct_no} {
		set sql {
			update
				tCustomer
			set
				username    = ?,
				username_uc = upper(?)
			where
				cust_id = ?;
			}
	} else {
		set sql {
			update
				tCustomer
			set
				username    = ?,
				username_uc = upper(?),
				acct_no     = ?
			where
				cust_id = ?;
		}
	}

	set stmt    [inf_prep_sql $DB $sql]

	set c       [catch {
		if {$no_upd_acct_no} {
			set res [inf_exec_stmt $stmt\
					$username_new\
					$username_new\
					$cust_id]
		} else {
			set res [inf_exec_stmt $stmt\
					$username_new\
					$username_new\
					$username_new\
					$cust_id]
		}
		catch {db_close $res}
	} msg]

	# Return error message or OK
	if {$c} {
		return $msg
	} else {
		inf_close_stmt $stmt
		return "OK"
	}
}

#
# Procedure: do_withdrawal_limit
# Description: Updates a withdrawal limit, for fraud prevention, specific to a
# particular customer.
# Inputs: cust_id, withdrawal_limit_days_text, withdrawal_limit_amt_text
# Output: none
# Author: apriddle, 09-11-2009
#

proc do_withdrawal_limit {} {

	if {[op_allowed EditCustFraudLmt]} {

		global DB USERID

		set cust_id        [reqGetArg CustId]
		set acct_id        [reqGetArg AcctId]
		set payMthd        [reqGetArg payMthd]
		set payScheme      [reqGetArg payScheme]
		set firstDep       [reqGetArg new_firstDep]
		set daysLastWtd    [reqGetArg new_daysLastWtd]
		set maxWtd         [reqGetArg new_maxWtd]

		if {$acct_id == "" ||\
			$payMthd == "" ||\
			$firstDep == "" ||\
			$daysLastWtd == "" ||\
			$maxWtd == ""} {
			err_bind "You need to set the values for the new row in the Withdrawal Limits table"
			return
		}

		if {$payScheme == ""} {
			set payScheme "----"
		}

		set sql {
			insert into
			tFraudLimitWtdAcc (    acct_id,
						pay_mthd,
						scheme,
						days_since_dep_1,
						days_since_wtd,
						max_wtd)
			values (?,?,?,?,?,?)
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {set rs [inf_exec_stmt $stmt\
						$acct_id\
						$payMthd\
						$payScheme\
						$firstDep\
						$daysLastWtd\
						$maxWtd]} msg]} {
			err_bind "A withdrawal limit already exists for this payment method, scheme and days since first deposit"
			ob_log::write ERROR {ADMIN::CUST::do_withdrawal_limit unable to insert withdrawal limit: $msg}
			return
		}

		inf_close_stmt $stmt
		msg_bind "Successfully updated customer withdrawal limits"

	}
}

#
# Procedure: delete_withdrawal_limit
# Description: Deletes a withdrawal limit, for fraud prevention, specific to a particular customer.
# Inputs: limit_id,
# Output: none
# Author: apriddle, 09-11-2009
#
proc delete_withdrawal_limit {} {
	if {[op_allowed EditCustFraudLmt]} {

		global DB USERID

		set limit_id [reqGetArg limitId]

		set sql {
			delete from
			tFraudLimitWtdAcc
			where
			limit_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		if {[catch {inf_exec_stmt $stmt $limit_id} msg]} {
			err_bind "Unable to delete withdrawal limit"
			ob_log::write ERROR {ADMIN::CUST::delete_withdrawal_limit unable to delete withdrawal limits: $msg}
			return
		}
		inf_close_stmt $stmt
		msg_bind "Successfully deleted customer withdrawal limit"
	}
}
#
# Set per customer multiple payments values
#
# Permissions must be checked before calling this proc
#
# Special values:
#
#    - empty string (""): does not change the value currently in the DB
#    - Minus one (-1): sets the value to null (delete the value)
#
# So:
#   set_cust_multi_limits $cust_id 3 -1 ""
#
#   will set max_pmt_mthds to 3, max_pmb_period to null and leave max_cards
#   unchanged
#
proc set_cust_multi_limits {cust_id max_pmt_mthds max_pmb_period max_cards} {

	global DB

	ob_log::write INFO {set_cust_multi_limits: updating settings for cust_id\
	   $cust_id - max_pmt_mthds $max_pmt_mthds max_pmb_period $max_pmb_period\
	   max_cards $max_cards}

	if {$max_pmt_mthds == "" && $max_pmb_period == "" && $max_cards == ""} {
		return 1
	}

	set params {
		p_cust_id = ?
	}

	# Touch obscure, but beats repeating the same thing over and over
	foreach var {max_pmt_mthds max_pmb_period max_cards} {
		if {[set $var] != ""} {
			append params ", p_$var = ?"
		}
	}

	set sql [subst {
		execute procedure pSetCustMultiLimits (
			$params
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set query [list inf_exec_stmt $stmt $cust_id]

	foreach var {max_pmt_mthds max_pmb_period max_cards} {
		if {[set $var] != ""} {
			lappend query [set $var]
		}
	}

	if {[catch {set rs [eval $query]} msg]} {
		err_bind $msg
		ob_log::write ERROR {set_cust_multi_limits: Error updating settings\
		   for cust_id $cust_id - $msg}
		return 0
	} else {
		inf_close_stmt $stmt
		db_close $rs
	}
	return 1
}


#
# Bind up the customer's payment method for display
#
proc get_cust_pmt_mthds {cust_id {exclude_cpm_id -1}} {

	global DB USERNAME

	global CPM_CUST
	global PMT_SEARCH

	catch {unset CPM_CUST}
	catch {unset PMT_SEARCH}

	#
	# order the payment methods in reverse if we have a cap on
	# showing deleted ones.
	#
	set orderby [expr {[OT_CfgGet CAP_CUST_PAYMTHD_DISPLAY ""]!=""?"DESC":""}]


	set sql [subst {
		select
			cpm.cpm_id,
			cpm.status,
			cpm.auth_dep,
			cpm.auth_wtd,
			cpm.cr_date,
			cpm.cust_id,
			cpm.order_dep,
			cpm.order_wtd,
			cpm.type,
			cpm.balance,
			p.desc,
			cpm.pay_mthd,
			cc.card_bin,
			cc.enc_card_no,
			cc.ivec,
			cc.data_key_id,
			net.neteller_id,
			cc.cvv2_resp,
			c2p.username as username_c2p,
			cc.enc_with_bin,
			cpm.pmb_period,
			a.ccy_code,
			l.ext_sub_link_id,
			s.desc as sub_mthd_desc
		from
			tCustPayMthd cpm,
			tPayMthd p,
			tAcct a,
			outer tCPMCC cc,
			outer tCPMNeteller net,
			outer tCPMC2P c2p,
			outer (
				tExtSubCPMLink l,
				tExtSubPayMthd s
			)
		where
			cpm.cust_id     = ?
		and cpm.cpm_id     <> ?
		and p.pay_mthd      = cpm.pay_mthd
		and cpm.cpm_id      = cc.cpm_id
		and cpm.cpm_id      = net.cpm_id
		and cpm.cpm_id      = c2p.cpm_id
		and cpm.cust_id     = a.cust_id
		and cpm.cpm_id      = l.cpm_id
		and l.sub_type_code = s.sub_type_code
		order by
			cr_date $orderby
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $cust_id $exclude_cpm_id]
	inf_close_stmt $stmt

	set CPM_CUST(total_cpms) [db_get_nrows $rs]

	set cols [db_get_colnames $rs]

	# Determine if we want to cap the number of processed cpms
	#---------------------------------------------------------
	set show_all_cpms 1
	if {[OT_CfgGet CAP_CUST_PAYMTHD_DISPLAY 0] && ("[reqGetArg showAllCPMs]" != 1)} {
		set show_all_cpms 0
	}
	tpSetVar showAllCPMs $show_all_cpms

	# Bind up just the cpms we want to display, these will be decrypted later
	#------------------------------------------------------------------------
	set removed_cpms 0
	set CPM_CUST(num_rows) 0
	for {set r 0} {$r < $CPM_CUST(total_cpms)} {incr r} {
		if {$show_all_cpms || ($removed_cpms < [OT_CfgGet CAP_CUST_PAYMTHD_DISPLAY 0 ] || [db_get_col $rs $r status] != "X")} {
			foreach col $cols {
				set CPM_CUST($CPM_CUST(num_rows),$col) [db_get_col $rs $r $col]
			}
			incr CPM_CUST(num_rows)
		}
		if {[db_get_col $rs $r status] == "X"} {
			incr removed_cpms
		}
	}
	tpSetVar RemovedCPMs $removed_cpms

	set encrypted_data_indexes [list]
	set encrypted_data         [list]

	set sql {
		select
			pm.cpm_id,
			pm.pay_mthd
		from
			tCPMGroupLink l1,
			tCPMGroupLink l2,
			tCustPayMthd  pm
		where
			    l1.cpm_id = ?
			and l2.cpm_grp_id = l1.cpm_grp_id
			and (l2.type = 'W' or
				(l2.type = 'B' and pm.pay_mthd IN ('BANK','CHQ')))
			and pm.status = 'A'
			and pm.cpm_id = l2.cpm_id
			and l2.cpm_id <> l1.cpm_id
	}

	set stmt_link [inf_prep_sql $DB $sql]

	if {$CPM_CUST(num_rows) > 0} {
		for {set r 0} {$r < $CPM_CUST(num_rows)} {incr r} {

			# Get the PMB value for each CPM
			set pmb [payment_multi::calc_cpm_pmb $cust_id $CPM_CUST($r,cpm_id)]

			if {[lindex $pmb 0] == 1} {
				set CPM_CUST($r,pmb) [lindex $pmb 1]
				set CPM_CUST($r,pmb_period) [lindex $pmb 2]
			} else {
				set CPM_CUST($r,pmb) "unknown"
				set CPM_CUST($r,pmb_period) "unknown"
			}

			# Check for any linked withdrawal methods
			if {$CPM_CUST($r,auth_wtd) == "N"} {

				set rs_link [inf_exec_stmt $stmt_link \
					$CPM_CUST($r,cpm_id)]

				if {[db_get_nrows $rs_link] > 0} {
					set CPM_CUST($r,linked_cpm_id)   [db_get_col $rs_link 0 cpm_id]
					set CPM_CUST($r,linked_pay_mthd) [db_get_col $rs_link 0 pay_mthd]
				}

				db_close $rs_link
			}

			# Set Method to be "Method(agent)" if it is BASC
			if {[OT_CfgGet FUNC_BASIC_PAY 0] == 1 && $CPM_CUST($r,pay_mthd) == "BASC"} {
				if {[OT_CfgGet OPENBET_CUST] == "LADBROKES"} {
					set desc "MCA"
				} else {
					set desc $CPM_CUST($r,desc)
				}
				tpBindString CPM_Desc_$r "$desc ([ADMIN::PMT::bind_detail_BASC $CPM_CUST($r,cpm_id) 1])"
			} elseif {$CPM_CUST($r,pay_mthd) == "ENVO"} {
				tpBindString CPM_Desc_$r "$CPM_CUST($r,desc) $CPM_CUST($r,sub_mthd_desc)"
				tpSetVar CPM_envoy_uniq_ref_$r [payment_ENVO::generate_cust_ref $CPM_CUST($r,ext_sub_link_id) $CPM_CUST($r,ccy_code)]
			} else {
				tpBindString CPM_Desc_$r $CPM_CUST($r,desc)
			}

			set is_entopay_card [expr {$CPM_CUST($r,type) == "EN"}]
			tpSetVar CPM_Is_Entropay_Card_$r $is_entopay_card

			set repl_midrange [expr {
				![op_allowed ViewCardNumber] ||
				($is_entopay_card && ![op_allowed ViewEntropayCardNum])
			}]

			# For ids where we have a card number to decrypt we collect the encrypted data and the indexes
			# to decrypt separately in a batched request to the cryptoServer
			if {$CPM_CUST($r,enc_card_no) != ""} {
				lappend encrypted_data_indexes $r
				lappend encrypted_data [list $CPM_CUST($r,enc_card_no) $CPM_CUST($r,ivec) $CPM_CUST($r,data_key_id)]
			}

			tpSetVar CPM_Status_$r $CPM_CUST($r,status)

			# Neteller ID
			tpSetVar CPM_Neteller_Id_$r $CPM_CUST($r,neteller_id)

			# Click2Pay username
			tpSetVar CPM_username_$r $CPM_CUST($r,username_c2p)

			# Add to the list of payment methods for payments search
			set PMT_SEARCH($r,cpm_id)   $CPM_CUST($r,cpm_id)
			set PMT_SEARCH($r,pay_mthd) $CPM_CUST($r,pay_mthd)

			if {$CPM_CUST($r,pay_mthd) == "ENVO"} {
				set PMT_SEARCH($r,pay_mthd_desc) "$CPM_CUST($r,desc) $CPM_CUST($r,sub_mthd_desc)"
			} else {
				set PMT_SEARCH($r,pay_mthd_desc) $CPM_CUST($r,desc)
			}
		}

		# Now go back and actually perform any required decryptions
		set card_dec_rs [card_util::card_decrypt_batch \
			$encrypted_data \
			"Display customer details" \
			$cust_id \
			$USERNAME ]

		if {[lindex $card_dec_rs 0] == 0} {
			# Check on the reason decryption failed, if we encountered corrupt data we should also
			# record this fact in the db
			if {[lindex $card_dec_rs 1] == "CORRUPT_DATA"} {
				foreach id $encrypted_data_indexes {
					card_util::update_data_enc_status "tCPMCC" $CPM_CUST($id,cpm_id) [lindex $card_dec_rs 2]
				}
			}
			err_bind "Error occurred decrypting customer card details: Not displaying customer payment methods"
			# Stop querying customer's payment details as we can't display that section, but we can still
			# carry on getting anything else that's relevant for this customer and just hide the Payment
			# Methods section
			tpSetVar PmtDispError 1
		} else {
			set decrypted_data [lindex $card_dec_rs 1]
			set dec_val_id 0
			foreach id $encrypted_data_indexes {
				set card_no [card_util::format_card_no \
				                [lindex $decrypted_data $dec_val_id] \
				                $CPM_CUST($id,card_bin) \
				                $CPM_CUST($id,enc_with_bin)]
				incr dec_val_id

				if {$repl_midrange} {
					set card_no [card_util::card_replace_midrange $card_no 1]
				}
				# Split the card number into blocks for ease of reading
				set tmp_card_no ""
				for {set ind 0} {$ind < [expr [string length $card_no]-4]} {incr ind 4} {
					append tmp_card_no [string range $card_no $ind [expr $ind + 3]] " "
				}

				append tmp_card_no [string range $card_no $ind end]
				tpSetVar CPM_Card_No_$id $tmp_card_no
			}
		}

		foreach f $cols {
			tpBindVar CPM_${f} CPM_CUST $f cpm_idx
		}

		# Bind the PMB values
		tpBindVar CPM_pmb             CPM_CUST  pmb              cpm_idx
		tpBindVar CPM_pmb_period      CPM_CUST  pmb_period       cpm_idx

		# Bind the linked methods too
		tpBindVar CPM_linked_cpm_id   CPM_CUST  linked_cpm_id    cpm_idx
		tpBindVar CPM_linked_pay_mthd CPM_CUST  linked_pay_mthd  cpm_idx

		# Bind up the pmt search options
		tpBindVar PMT_SEARCH_cpm_id             PMT_SEARCH cpm_id         cpm_idx
		tpBindVar PMT_SEARCH_cust_pay_mthd      PMT_SEARCH pay_mthd       cpm_idx
		tpBindVar PMT_SEARCH_cust_pay_mthd_desc PMT_SEARCH pay_mthd_desc  cpm_idx

	}

	inf_close_stmt $stmt_link

	# See if CSH pay method exists in DB
	set csh_mthd_sql {
		select
			pay_mthd
		from
			tPayMthd
		where
			pay_mthd = 'CSH'
	}
	set stmt         [inf_prep_sql $DB $csh_mthd_sql]
	set csh_mthd_cpm [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# Add a default CSH method is one is not found (and the method exists in DB)
	if {$CPM_CUST(num_rows) > 0 && [db_get_nrows $csh_mthd_cpm] > 0} {
		set csh_count 0

		for {set r 0} {$r < $CPM_CUST(num_rows)} {incr r} {
			if {$CPM_CUST($r,pay_mthd) == "CSH"} {
				incr csh_count
			}
		}

		tpSetVar CshCPM $csh_count
	}
}


# Large return limits:
proc bind_cust_return_lmts { acct_id } {
	global DB
	global CUST_LARGE_RETURNS

	# To prevent have a stupidly large query, its makes the
	# union on the fly.
	#   productArea    tableName     foreignKey
	set table_map {
		{ESB           tEvCategory   ev_category_id}
		{XSYS          tXSysHost     system_id}
		{POOL          -             -}
		{FOG           -             -}
		{LOTO          -             -}
	}

	set sql_parts {}
	foreach item $table_map {
		set key   [lindex $item 0]
		set table [lindex $item 1]
		set f_key [lindex $item 2]

		if {$table != "-"} {
			lappend sql_parts [subst {
				select
					fr.product_area,
					NVL(fr.ref_id, -1) ref_id,
					fr.limit,
					NVL(rt.name,"--DEFAULT--") as ref_name
				from
					tFraudLmtRetAcct fr,
					outer $table rt
				where
						fr.acct_id = "$acct_id"
					and fr.product_area == "$key"
					and fr.ref_id = rt.$f_key
			}]
		} else {
			lappend sql_parts [subst {
				select
					fr.product_area,
					NVL(fr.ref_id, -1) ref_id,
					fr.limit,
					"n/a" as ref_name
				from
					tFraudLmtRetAcct fr
				where
						fr.acct_id = "$acct_id"
					and fr.product_area == "$key"
			}]
		}
	}
	# Union these queries.
	set sql [join $sql_parts "UNION ALL"]
	append sql " order by 2"

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	# Get/Bind the data.
	set nrows [db_get_nrows $res]
	tpSetVar LargeLmtNum $nrows
	for {set i 0} {$i < $nrows} {incr i} {
		set CUST_LARGE_RETURNS($i,product_area)   [db_get_col $res $i product_area]
		set CUST_LARGE_RETURNS($i,ref_id)         [db_get_col $res $i ref_id]
		set CUST_LARGE_RETURNS($i,ref_name)       [ADMIN::EV_SEL::remove_tran_bars [db_get_col $res $i ref_name]]
		set CUST_LARGE_RETURNS($i,limit)          [db_get_col $res $i limit]
	}

	tpBindVar productArea CUST_LARGE_RETURNS product_area   lridx
	tpBindVar refId       CUST_LARGE_RETURNS ref_id         lridx
	tpBindVar refName     CUST_LARGE_RETURNS ref_name       lridx
	tpBindVar limit       CUST_LARGE_RETURNS limit          lridx

}


proc do_del_cust_return_limits {} {
	global DB
	global USERNAME

	set product_area [reqGetArg productArea]
	set ref_id  [reqGetArg refId]
	set acct_id [reqGetArg acctId]
	set cust_id [reqGetArg custId]

	set sql [subst {
		execute procedure pDelFraudLmtRetAcct (
			p_adminuser = ?,
			p_product_area   = ?,
			p_ref_id    = ?,
			p_acct_id   = ?
		)
	}]
	set stmt [inf_prep_sql $DB $sql]

	if {[catch { set rs  [inf_exec_stmt $stmt $USERNAME $product_area $ref_id $acct_id] } msg]} {
		ob::log::write ERROR "pDelFraudLmtRetAcct failed, msg: $msg"
		err_bind "Unable to delete, msg: $msg"
		go_cust
		return
	}
	inf_close_stmt $stmt
	db_close $rs

	# Success!
	msg_bind "Successfully deleted large returns limit."
	go_cust
}

proc go_add_cust_return_limits args {
	global DB

	set acct_id      [reqGetArg acctId ""]

	if {![string is integer $acct_id]} {
		err_bind "Invalid Account Id"
		go_cust [reqGetArg CustId]
		return
	}

	# Bind combos.
	ADMIN::PMT::bind_sports_cats $acct_id
	ADMIN::PMT::bind_ex_hosts $acct_id

	asPlayFile pmt_fraud/cust_returns_add.html
}

proc do_set_cust_return_limits {} {
	global DB

	set num_vals [reqGetNumVals]
	set array_max -1

	set req_vals [list]

	for {set i 0} {$i < $num_vals} {incr i} {
		# Split by separator (payMthd_1).
		set pos  [string last "_" [reqGetNthName $i]]

		# If not 'multi form' don't process.
		if {$pos > -1} {
			set name [string range [reqGetNthName $i] 0 [expr {$pos-1}]]
			set num  [string range [reqGetNthName $i] [expr {$pos+1}] end]

			set FORM_DATA($num,$name) [reqGetNthVal $i]

			if {$num > $array_max} {
				set array_max $num
			}
		}
	}

	set acctId      [reqGetArg acctId ""]

	# Validate.
	if {$acctId == ""} {
		err_bind "Missing required fields."
		go_cust [reqGetArg CustId]
		return
	}

	set sql [subst {
		execute procedure pSetFraudLmtRetAcct (
			p_product_area   = ?,
			p_ref_id         = ?,
			p_limit          = ?,
			p_acct_id        = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	# Update items.
	for {set i 0} {$i <= $array_max} {incr i} {
		# Update items.
		if {![info exists FORM_DATA($i,productArea)] ||
				![info exists FORM_DATA($i,refId)] ||
				![info exists FORM_DATA($i,limit)]} {
			err_bind "Missing required fields. "
			go_cust [reqGetArg CustId]
			return
		}

		set area    $FORM_DATA($i,productArea)
		set ref_id  $FORM_DATA($i,refId)
		set limit   $FORM_DATA($i,limit)
		set acct_id $acctId


		# Check that the amount's fine
		if {$limit <= 0 || ![string is double $limit]} {
			err_bind "Invalid limit, must be a number larger than 0"
			go_cust [reqGetArg CustId]
			return
		}

		if {[catch { set rs  [inf_exec_stmt $stmt $area $ref_id $limit $acct_id] } msg]} {
			ob::log::write ERROR "pSetFraudLmtRetAcct failed, msg: $msg"
			err_bind "Unable to update, msg: $msg"
			db_close $rs
			inf_close_stmt $stmt
			go_cust [reqGetArg CustId]
			return
		}

		db_close $rs
	}

	inf_close_stmt $stmt

	# Success.
	msg_bind "Updated Large Return limits."
	go_cust [reqGetArg CustId]

}

proc do_cust_return_limits args {
	set action [reqGetArg SubmitName]

	if {![op_allowed UpdateLimitRetAcct]} {
		err_bind "Insufficient permissions to perform this action."
		go_cust [reqGetArg CustId]
	}

	switch -- $action {
		goAdd { go_add_cust_return_limits }
		doAdd { do_set_cust_return_limits }
		doUpd { do_set_cust_return_limits }
		doDel { do_del_cust_return_limits }
	}
}


# Check if customer is platinum or not
# returns 0/1
proc is_platinum_customer {flag} {

	if {$flag == ""} {
		return 0
	}

	set pFlags [OT_CfgGet PLATINUM_CUST_CODE ""]
	set lPlatFlags [split $pFlags]

	if {[lsearch -exact $lPlatFlags $flag] >  -1} {
		set is_plat 1
	} else {
		set is_plat 0
	}
}


# Build up a search string for the platinum
# customer codes e.g. ('PT','PI')
proc get_platinum_search_string {args} {

	set pFlags [OT_CfgGet PLATINUM_CUST_CODE ""]
	set lPlatFlags [split $pFlags]

	set search ""

	set is_first 1

	if {[llength $lPlatFlags] == 0} {
		return ""
	}

	foreach flag $lPlatFlags {
		if {$is_first} {
			set search "('$flag'"
			set is_first 0
		} else {
			append search ",'$flag'"
		}
	}

	append search ")"

	return $search
}


# close namespace
}

