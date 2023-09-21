# ==============================================================
# $Id: control.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CONTROL {

asSetAct ADMIN::CONTROL::GoControl [namespace code go_control]
asSetAct ADMIN::CONTROL::DoControl [namespace code do_control]
asSetAct ADMIN::CONTROL::UpdateURN [namespace code update_urn]
asSetAct ADMIN::CONTROL::UpdateWON [namespace code update_won]

#
# ----------------------------------------------------------------------------
# Got to the "control" page
# ----------------------------------------------------------------------------
#
proc go_control args {

	global DB

	set stmt [inf_prep_sql $DB {

		select
			offer_expiry,
			bets_allowed,
			login_keepalive,
			allow_funds_dep,
			allow_funds_wtd,
			default_ccy,
			default_lang,
			default_country,
			default_view,
			max_login_fails,
			acc_max,
			ah_refund_pct,
			default_tax_rate,
			stl_pay_limit,
			fraud_screen,
			cum_stakes_delay,
			prev_stk_bir,
			prev_stk_nobir,
			enable_liab,
			async_bet,
			bir_async_bet,
			async_timeout,
			async_off_timeout,
			async_rule_stk1,
			async_rule_stk2,
			async_rule_liab,
			async_max_payout,
			night_mode,
			night_max_bet,
			night_start_time,
			night_max_apc,
			credit_limit_or,
			use_captchas,
			shop_liab_mult,
			admn_pwd_num_rpt,
			admn_pwd_min_len,
			admn_pwd_num_bad,
			admn_pwd_lock,
			admn_pwd_chg_frq,
			mkt_collection_disp,
			en_rn_livechat,
			en_rn_indirect,
			auto_coupon_on,
			tmrw_race_disp_at,
			password_expiry,
			oxi_hbeat_active,
			perf_min_balance,
			tmrw_race_disp_at,
			password_expiry,
			push_enabled,
			max_payout_parking,
			nice_api_active,
			susp_inactive_days,
			del_inactive_days,
			virtual_race_disp,
			perf_last_bet_interval
		from tControl;

	}]
	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString OfferExpiry	  [db_get_col $res offer_expiry]
	tpBindString LoginKeepalive   [db_get_col $res login_keepalive]
	tpBindString AllowBetting	  [db_get_col $res bets_allowed]
	tpBindString AllowFundsDep	  [db_get_col $res allow_funds_dep]
	tpBindString AllowFundsWtd	  [db_get_col $res allow_funds_wtd]
	tpBindString MaxLoginFails	  [db_get_col $res max_login_fails]
	tpBindString AccMax           [db_get_col $res acc_max]
	tpBindString AHRefundPct      [db_get_col $res ah_refund_pct]
	tpBindString DefaultTaxRate   [db_get_col $res default_tax_rate]
	tpBindString StlPayLimit      [db_get_col $res stl_pay_limit]
	tpBindString AllowFraudScreen [db_get_col $res fraud_screen]
	tpBindString CumStakesDelay   [db_get_col $res cum_stakes_delay]
	tpBindString PrevStkBir       [db_get_col $res prev_stk_bir]
	tpBindString PrevStkNoBir     [db_get_col $res prev_stk_nobir]
	tpBindString EnableLiab	      [db_get_col $res enable_liab]
	tpBindString CreditLimitOr    [db_get_col $res credit_limit_or]
	tpBindString UseCaptchas      [db_get_col $res use_captchas]
	tpBindString ShopLiabMult     [db_get_col $res shop_liab_mult]
	tpBindString AdmnPwdNumRpt    [db_get_col $res admn_pwd_num_rpt]
	tpBindString AdmnPwdMinLen    [db_get_col $res admn_pwd_min_len]
	tpBindString AdmnPwdNumBad    [db_get_col $res admn_pwd_num_bad]
	tpBindString AdmnPwdLock      [db_get_col $res admn_pwd_lock]
	tpBindString AdmnPwdChgFrq    [db_get_col $res admn_pwd_chg_frq]
	tpBindString TmrwRaceDispAt   [db_get_col $res tmrw_race_disp_at]
	tpBindString PasswordExpiry   [db_get_col $res password_expiry]
	tpBindString OxiHBActive      [db_get_col $res oxi_hbeat_active]
	tpBindString PerformVoDMinBal [db_get_col $res perf_min_balance]
	tpBindString PushEnabled      [db_get_col $res push_enabled]
	tpBindString MaxPayoutParking [db_get_col $res max_payout_parking]


	# Bind the information saved in tCDN Control
	bind_cdn_control

    # Nice API
	if { [OT_CfgGet FUNC_NICE_API 0] } {
		tpBindString NiceApiActive    [db_get_col $res nice_api_active]
	}

	tpBindString AdminSuspendUsers [db_get_col $res susp_inactive_days]
	tpBindString AdminDeleteUsers  [db_get_col $res del_inactive_days]

	# LiveChat
	if {[OT_CfgGet FUNC_RN_LIVE_CHAT 0]} {
		tpBindString EnableRNLiveChat [db_get_col $res en_rn_livechat]
		tpBindString EnableRNIndirect [db_get_col $res en_rn_indirect]
	}

	set DefaultCCY	   [db_get_col $res 0 default_ccy]
	set DefaultLang	   [db_get_col $res 0 default_lang]
	set DefaultCountry [db_get_col $res 0 default_country]
	set DefaultView    [db_get_col $res 0 default_view]


	if {[OT_CfgGet FUNC_MENU_COLLECTIONS 0]} {
		tpBindString MarketsDispPerCollection [db_get_col $res mkt_collection_disp]
	}

	# Night Mode
	if {[OT_CfgGetTrue FUNC_NIGHT_MODE]} {
		tpBindString NightMode        [db_get_col $res 0 night_mode]
		tpBindString NightMaxBet      [db_get_col $res 0 night_max_bet]
		tpBindString NightStartTime   [db_get_col $res 0 night_start_time]
		tpBindString NightMaxAPC      [db_get_col $res 0 night_max_apc]
	}

	# Async' Betting
	if {[OT_CfgGetTrue FUNC_ASYNC_BET]} {
		tpBindString AsyncBet        [db_get_col $res 0 async_bet]
		tpBindString BirAsyncBet     [db_get_col $res 0 bir_async_bet]
		tpBindString AsyncTimeout    [db_get_col $res 0 async_timeout]
		tpBindString AsyncOffTimeout [db_get_col $res 0 async_off_timeout]
		tpBindString AsyncRuleStk1   [db_get_col $res 0 async_rule_stk1]
		tpBindString AsyncRuleStk2   [db_get_col $res 0 async_rule_stk2]
		tpBindString AsyncRuleLiab   [db_get_col $res 0 async_rule_liab]
		tpBindString AsyncMaxPayout  [db_get_col $res 0 async_max_payout]
	}

	if {[OT_CfgGet USE_AUTO_COUPONS 1]} {
		tpBindString AutoCouponOn    [db_get_col $res 0 auto_coupon_on]
	}

	if {[OT_CfgGetTrue FUNC_MEDIA_CONTENT]} {
		tpBindString PerformVoDMinBal          [db_get_col $res perf_min_balance]
		tpBindString PerformVoDLastBetInterval [db_get_col $res perf_last_bet_interval]
	}

	db_close $res

	global DATA

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

	set view_sql {
		select
			view view_id,
			name view_name,
			disporder
		from
			tViewType
		where
			status = 'A'
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $view_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumView [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set view_id [db_get_col $res $r view_id]

		set DATA($r,view_id)   $view_id
		set DATA($r,view_name) [db_get_col $res $r view_name]

		if {$DefaultView == $view_id} {
			set DATA($r,view_sel) SELECTED
		} else {
			set DATA($r,view_sel) ""
		}
	}

	tpBindVar ViewId   DATA view_id   view_idx
	tpBindVar ViewName DATA view_name view_idx
	tpBindVar ViewSel  DATA view_sel  view_idx

	db_close $res

	set ccy_sql {
		select
			ccy_code,
			ccy_name,
			disporder
		from
			tCCY
		where
			status = 'A'
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

	set country_sql {
		select
			country_code,
			country_name,
			disporder
		from
			tCountry
		where
			status = 'A'
		order by
			disporder
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

	if {[OT_CfgGet FUNC_URN_MATCHING 0]} {

		set urn_matching_enabled_sql {
			select
			allow_processing,
			last_proc_date
			from
			tURNMatchControl
		}

		set stmt [inf_prep_sql $DB $urn_matching_enabled_sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set allow [db_get_col $res 0 allow_processing]
		if {[string equal $allow "Y"]} {
			tpBindString MatchingChecked "checked"
		}

		tpBindString LastProcessedDate [db_get_col $res 0 last_proc_date]

		db_close $res
	}

	if {[OT_CfgGet FUNC_WON_ACTIVE 0] && [op_allowed WONView]} {
		go_won_control
	}

	asPlayFile -nocache control.html

	unset DATA
}


#
# ----------------------------------------------------------------------------
# Update control information
# ----------------------------------------------------------------------------
#
proc do_control args {

	global DB USERNAME

	# Night Mode
	# - if Async Betting, then the night-mode enables/disables async-betting
	if {[OT_CfgGetTrue FUNC_NIGHT_MODE] && [OT_CfgGetTrue FUNC_ASYNC_BET]} {
		if {[reqGetArg NightMode] == "Y"} {
			reqSetArg AsyncBet N
		} else {
			reqSetArg AsyncBet Y
		}
	}

	set params {

			p_adminuser        = ?,
			p_offer_expiry     = ?,
			p_bets_allowed     = ?,
			p_login_keepalive  = ?,
			p_allow_funds_dep  = ?,
			p_allow_funds_wtd  = ?,
			p_default_ccy      = ?,
			p_default_lang     = ?,
			p_default_country  = ?,
			p_max_login_fails  = ?,
			p_acc_max          = ?,
			p_ah_refund_pct    = ?,
			p_default_tax_rate = ?,
			p_stl_pay_limit    = ?,
			p_fraud_screen     = ?,
			p_cum_stakes_delay = ?,
			p_prev_stk_bir     = ?,
			p_prev_stk_nobir   = ?,
			p_credit_limit_or  = ?,
			p_enable_liab      = ?,
			p_async_bet        = ?,
			p_bir_async_bet    = ?,
			p_async_tout       = ?,
			p_async_off_tout   = ?,
			p_async_rule_stk1  = ?,
			p_async_rule_stk2  = ?,
			p_async_rule_liab  = ?,
			p_async_max_payout = ?,
			p_use_captchas     = ?,
			p_shop_liab_mult   = ?,
			p_admn_pwd_num_rpt = ?,
			p_admn_pwd_min_len = ?,
			p_admn_pwd_num_bad = ?,
			p_admn_pwd_lock    = ?,
			p_admn_pwd_chg_frq = ?,
			p_tmrw_race_disp_at = ?,
			p_oxi_hbeat_active = ?,
			p_push_enabled = ?,
			p_max_payout_parking = ?,
			p_suspend_admin_user = ?,
			p_delete_admin_user = ?
	}

	# Nice API
	if { [OT_CfgGet FUNC_NICE_API 0] } {
		append params {
				              ,
			p_nice_api_active  = ?
		}
	}

	# LiveChat
	if { [OT_CfgGet FUNC_RN_LIVE_CHAT 0] } {
		append params {
			                    ,
			p_en_rn_livechat = ?,
			p_en_rn_indirect = ?
		}
	}

	if { [OT_CfgGetTrue FUNC_NIGHT_MODE] } {

		append params {
			                      ,
			p_night_mode       = ?,
			p_night_max_bet    = ?,
			p_night_max_apc    = ?

		}

	}

	if {[OT_CfgGet FUNC_VIEWS 0]} {
		append params {
						,
			p_default_view     = ?
		}
	}


	if {[OT_CfgGet USE_AUTO_COUPONS 1]} {
		append params {
									,
			p_auto_coupon_on       = ?
		}
	}

	if {[OT_CfgGet FUNC_MENU_COLLECTIONS 0]} {

		append params {
									,
			p_mkt_collection_disp   = ?
		}

	}

	if {[OT_CfgGet FUNC_PWD_EXPIRY 0]} {

		append params {
									,
			p_password_expiry = ?
		}

	}

	if {[OT_CfgGetTrue FUNC_MEDIA_CONTENT]} {

		append params {
			, p_perf_min_balance = ?
			, p_perf_last_bet_interval = ?
		}

	}

	set sql [subst {

		execute procedure pUpdControl(
			$params
		)

	}]

	set stmt [inf_prep_sql $DB $sql]

	set query_eval [list inf_exec_stmt $stmt\
	                     $USERNAME\
	                     [reqGetArg OfferExpiry]\
	                     [reqGetArg AllowBetting]\
	                     [reqGetArg LoginKeepalive]\
	                     [reqGetArg AllowFundsDep]\
	                     [reqGetArg AllowFundsWtd]\
	                     [reqGetArg DefaultCCY]\
	                     [reqGetArg DefaultLang]\
	                     [reqGetArg DefaultCountry]\
	                     [reqGetArg MaxLoginFails]\
	                     [reqGetArg AccMax]\
	                     [reqGetArg AHRefundPct]\
	                     [reqGetArg DefaultTaxRate]\
	                     [reqGetArg StlPayLimit]\
	                     [reqGetArg FraudScreen]\
	                     [reqGetArg CumStakesDelay]\
	                     [reqGetArg PrevStkBir]\
	                     [reqGetArg PrevStkNoBir]\
	                     [reqGetArg CreditLimitOr]\
	                     [reqGetArg EnableLiab]\
	                     [reqGetArg AsyncBet]\
	                     [reqGetArg BirAsyncBet]\
	                     [reqGetArg AsyncTimeout]\
	                     [reqGetArg AsyncOffTimeout]\
	                     [reqGetArg AsyncRuleStk1]\
	                     [reqGetArg AsyncRuleStk2]\
	                     [reqGetArg AsyncRuleLiab]\
	                     [reqGetArg AsyncMaxPayout]\
	                     [reqGetArg UseCaptchas]\
	                     [reqGetArg ShopLiabMult]\
	                     [reqGetArg AdmnPwdNumRpt]\
	                     [reqGetArg AdmnPwdMinLen]\
	                     [reqGetArg AdmnPwdNumBad]\
	                     [reqGetArg AdmnPwdLock]\
	                     [reqGetArg AdmnPwdChgFrq]\
	                     [reqGetArg TmrwRaceDispAt]\
	                     [reqGetArg OxiHBActive]\
	                     [reqGetArg PushEnabled]\
                         [reqGetArg MaxPayoutParking]\
		                 [reqGetArg AdminSuspendUsers]\
		                 [reqGetArg AdminDeleteUsers]\
	]

    # Nice API
	if { [OT_CfgGet FUNC_NICE_API 0] } {
		lappend query_eval [reqGetArg NiceApiActive]\
	}

    # LiveChat
	if { [OT_CfgGet FUNC_RN_LIVE_CHAT 0] } {
		lappend query_eval [reqGetArg EnableRNLiveChat]\
			               [reqGetArg EnableRNIndirect]
    }


	if { [OT_CfgGetTrue FUNC_NIGHT_MODE] } {
		lappend query_eval [reqGetArg NightMode]\
	                       [reqGetArg NightMaxBet]\
	                       [reqGetArg NightMaxAPC]
	}

	if {[OT_CfgGet FUNC_VIEWS 0]} {
		lappend query_eval [reqGetArg DefaultView]
	}


	if {[OT_CfgGet CHOOSE_NUMBER_VIRTUAL_RACES 0]} {
		lappend query_eval [reqGetArg VirtualRaceDisp]
	}

	if {[OT_CfgGet USE_AUTO_COUPONS 1]} {
		lappend query_eval [reqGetArg AutoCouponOn]
	}


	if {[OT_CfgGet FUNC_MENU_COLLECTIONS 0]} {
		lappend query_eval [reqGetArg MarketsDispPerCollection]
	}

	if {[OT_CfgGet FUNC_PWD_EXPIRY 0]} {
		lappend query_eval [reqGetArg PasswordExpiry]
	}

	if {[OT_CfgGetTrue FUNC_MEDIA_CONTENT]} {
		lappend query_eval [reqGetArg PerformVoDMinBal]\
	                     [reqGetArg PerformVoDLastBetInterval]
	}

	if {[catch {
		set res [eval $query_eval]
	} msg]} {
		err_bind $msg
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar UpdateFailed 1
	}

	inf_close_stmt $stmt

	# Finally save the CDN site stuff
	if {[OT_CfgGet FUNC_CDN 0]} {
		update_cdn_control
	}

	go_control

}


#
# Bind the current CDN Conrtol settings fromt the DB
#
proc bind_cdn_control {} {

	global DB

	set stmt [inf_prep_sql $DB {
		select
			cdn_enabled,
			js_cdn_enabled,
			css_cdn_enabled,
			gif_cdn_enabled,
			swf_cdn_enabled
		from
			tCDNControl
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString JsCdnEnabled     [db_get_col $res js_cdn_enabled]
	tpBindString CssCdnEnabled    [db_get_col $res css_cdn_enabled]
	tpBindString GifCdnEnabled    [db_get_col $res gif_cdn_enabled]
	tpBindString SwfCdnEnabled    [db_get_col $res swf_cdn_enabled]
	tpBindString CdnEnabled       [set CdnEnabled [db_get_col $res cdn_enabled]]

	if {$CdnEnabled == "I"} {
		tpBindString cdnDisable ""
	} else {
		tpBindString cdnDisable "disabled"
	}
}


#
# Update the CDN Control table (tCDNControl)
# - play_cont_page
#    Takes either 0/1 and decides if control
#    page should be played
#
proc update_cdn_control {{play_cont_page 0}} {

	global DB USERNAME

	set upd_cdn_control_sql {
		execute procedure pUpdCDNControl (
			p_adminuser       = ?,
			p_cdn_enabled     = ?,
			p_js_cdn_enabled  = ?,
			p_css_cdn_enabled = ?,
			p_gif_cdn_enabled = ?,
			p_swf_cdn_enabled = ?
		)
	}

	set stmt [inf_prep_sql $DB $upd_cdn_control_sql]
	if [catch {set rs [inf_exec_stmt $stmt \
	           $USERNAME\
	           [reqGetArg CdnEnabled]\
	           [reqGetArg JsCdnEnabled]\
	           [reqGetArg CssCdnEnabled]\
	           [reqGetArg GifCdnEnabled]\
             [reqGetArg SwfCdnEnabled]\
	]} msg] {
		err_bind $msg
	} else {
		inf_close_stmt $stmt
		db_close $rs
	}

	if {$play_cont_page} {
		# Play the page
		go_control
	}
}

proc update_urn {} {

	global DB

	set urn_update_allowed_sql {
		update
			tURNMatchControl
		set
			allow_processing = ?,
			last_proc_date = ?
	}

	if {[string equal [reqGetArg matching_allowed] "Y"]} {
		set allow "Y"
	} else {
		set allow "N"
	}

	set last_proc [reqGetArg last_executed]

	if {[string length $last_proc] == 0} {
		err_bind "You must enter a correct date for Last Executed"
		go_control
		return
	}

	set stmt [inf_prep_sql $DB $urn_update_allowed_sql]

	if {[catch {set res  [inf_exec_stmt $stmt $allow $last_proc]} msg]} {
		err_bind "The date format used is incorrect. Please use yyyy-mm-dd hh:mm:ss"
		go_control
		return
	}

	inf_close_stmt $stmt
	db_close $res

	go_control
}

#
# Procedures for viewing/updating the World Online Network (WON) control table.
#

#
# Display the contents of tWONControl.
#
proc go_won_control {} {

	global DB WON_CTRL

	array set DESC [list \
						lic_id          {Licensee Id} \
						lic_pwd         {Licensee Password} \
						lic_rev_pwd     {Admin password on WON} \
						lic_rev_pwd_old {Old admin password on WON} \
						login_url		{Login URL} \
						balance_url     {Balance URL} \
						transfer_url    {Transfer URL} \
						server_ccy      {WON server currency} \
						timeout         {Timeout for contacting server (ms)} \
						admin_user      {Openbet Admin username} \
						system_name     {External System name (tXSysHost)}
				   ]

	set sql {

		select
			lic_id,
			lic_pwd,
			lic_rev_pwd,
			lic_rev_pwd_old,
			login_url,
			balance_url,
			transfer_url,
			server_ccy,
			timeout,
			admin_user,
			system_name
		from
			tWONControl
		where
			only_one_row = 'A'

	}

	tpBindString WonTitle {WON Control Information}
	tpSetVar WonNumRows 0

	if [catch {
		set stmt [inf_prep_sql $DB $sql]
		set rs	 [inf_exec_stmt $stmt]
		inf_close_stmt $stmt
	}] {

		tpBindString WonErrMsg {Error loading WON control data}
		return
	}

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		# bind...
		tpSetVar WonNumRows 1
		set i 0

		set cols [db_get_colnames $rs]

		foreach c $cols {
			set WON_CTRL($i,name) $c
			set WON_CTRL($i,value) [db_get_col $rs 0 $c]
			set WON_CTRL($i,desc) $DESC($c)
			incr i
		}
		tpSetVar WonNumCols $i

		tpBindVar WonColName  WON_CTRL name  won_idx
		tpBindVar WonColValue WON_CTRL value won_idx
		tpBindVar WonColDesc  WON_CTRL desc  won_idx

	} elseif {$nrows == 0} {
		tpBindString WonErrMsg {WON control data not installed}
	} else {
		tpBindString WonErrMsg {Error retrieving WON data}
	}
	db_close $rs
}

#
# Update tWONControl.
# (Note: check the javascript in control.html)
#
proc update_won {} {

	global DB

	set sql {

		update
			tWONControl
		set
			lic_id          = ?,
			lic_pwd         = ?,
			lic_rev_pwd     = ?,
			lic_rev_pwd_old = ?,
			login_url       = ?,
			balance_url     = ?,
			transfer_url    = ?,
			server_ccy      = ?,
			timeout         = ?,
			admin_user      = ?,
			system_name     = ?
		where
			only_one_row = 'A'

	}

	set stmt [inf_prep_sql $DB $sql]
	if [catch {set rs [inf_exec_stmt $stmt \
						   [reqGetArg lic_id] \
						   [reqGetArg lic_pwd] \
						   [reqGetArg lic_rev_pwd] \
						   [reqGetArg lic_rev_pwd_old] \
						   [reqGetArg login_url] \
						   [reqGetArg balance_url] \
						   [reqGetArg transfer_url] \
						   [reqGetArg server_ccy] \
						   [reqGetArg timeout] \
						   [reqGetArg admin_user] \
						   [reqGetArg system_name]
					  ]} msg] {
		err_bind $msg
	} else {
		inf_close_stmt $stmt
		db_close $rs
	}
	go_control
}

}
