# ==============================================================
# $Id: tb_cust.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

############################################
# source the telebetting registration procs
############################################
namespace eval ADMIN::TB_CUST {

asSetAct ADMIN::TB_CUST::GoRegister   [namespace code go_register]
asSetAct ADMIN::TB_CUST::DoRegister   [namespace code do_register]

#
# go registration
#
########################
proc go_register args {
########################

	global DB

	set cust_id [reqGetArg CustId]

	if {$cust_id != ""} {
		tpSetVar NewUser 0
		tpBindString NewUser 0

		OT_LogWrite 5 "loading customer details"

		array set CUST_DATA ""
		set result [tb_register::tb_get_customer_details $cust_id CUST_DATA]
		set col_pos [string first : $CUST_DATA(hear_about_txt)]
		set hear_about [string range $CUST_DATA(hear_about_txt) 0 [expr $col_pos -1]]
		set CUST_DATA(hear_about_free_txt) [string range $CUST_DATA(hear_about_txt) [expr $col_pos +1] end]
		set CUST_DATA(hear_about_txt) $hear_about

		if {$result != 1} {
			err_bind "Could not load customer details"

		} else {

			#
			# old user
			#
			reqSetArg NewUser 		0

			#
			# set the fields (picked up in play_register)
			#
			foreach f [array names CUST_DATA] {
				reqSetArg $f $CUST_DATA($f)
			}
		}

	} else {
		OT_LogWrite 5 "registering new customer"

		tpSetVar NewUser 1
		tpBindString NewUser 1

		OT_LogWrite 1 "[OT_CfgGet REG_ACCT_TYPES [list DEP]]"

		#
		# set some defaults (these are picked up in play_register)
		#
		reqSetArg NewUser              1
		reqSetArg gender               ""
		reqSetArg title                "Mr"
		reqSetArg code                 [OT_CfgGet DEFAULT_REG_CUST_CODE ""]
		reqSetArg hear_about           ""
		reqSetArg partnership          ""
		reqSetArg settle_type          "N"
		reqSetArg acct_type            [lindex [OT_CfgGet REG_ACCT_TYPES {DEP}] 0]
		reqSetArg min_repay            "0.00"
		reqSetArg min_funds            "0.00"
		reqSetArg min_settle           "0.00"
		reqSetArg credit_limit         "0.00"
		reqSetArg deposit_limit        "-1"
		reqSetArg pay_pct              "100"
		reqSetArg settle_type          "N"
		reqSetArg contact_ok           "Y"
		reqSetArg contact_how          "TPES"
		reqSetArg mkt_contact_ok       "Y"
		reqSetArg ptnr_contact_ok      "Y"
		reqSetArg source               "P"

		#
		# Statements
		#
		reqSetArg stmt_on             "N"
		reqSetArg freq_amt            "2"
		reqSetArg freq_unit           "W"
		reqSetArg dlv_method          "E"
		reqSetArg brief               "N"
		reqSetArg enforce_period      "Y"

		set current [clock format [tb_statement::tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]
		reqSetArg due_from            $current
		reqSetArg due_to              $current


		#
		# set default ccy, country, lang from based on tcontrol values
		#
		set sql {
			select
				default_ccy,
				default_lang,
				default_country
			from
				tControl
		}
		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		reqSetArg lang_code     [db_get_col $rs 0 default_lang]
		reqSetArg currency_code [db_get_col $rs 0 default_ccy]
		reqSetArg country_code  [db_get_col $rs 0 default_country]
		reqSetArg cd_grp_id     [OT_CfgGet DEFAULT_CDG_GRP ""]

		db_close $rs
	}

	play_register
}


#
# Play the registration page
#
########################
proc play_register {} {
########################

	global DB DATA CONTACT_HOW DEPOSIT_LIMIT
	variable IntroSource

	OT_LogWrite 5 "==> play_register"

	#
	# set the defaults
	#
	set DefaultLang             [reqGetArg lang_code]
	set DefaultCCY              [reqGetArg currency_code]
	set DefaultCountry          [reqGetArg country_code]
	set DefaultState            [reqGetArg addr_state_id]
	set DefaultCode             [reqGetArg code]
	set DefaultSort             [reqGetArg cust_sort]
	set DefaultHearAboutType    [reqGetArg hear_about]
	set DefaultPartner          [reqGetArg partnership]
	set DefaultFBTeam           [reqGetArg fbteam]
	set DefaultCDGroup          [reqGetArg cd_grp_id]

	set DefaultAffiliate	[reqGetArg aff_id]

	# hear_about_txt is actually hear_about_txt:hear_about_free_txt so separate
	# these now
	set DefaultHearAbout ""

	if {[catch {
		set DefaultHearAbout [string range [reqGetArg hear_about_txt] 0 [expr {[string first ":" [reqGetArg hear_about_txt]] -1}]]
	} msg]} {
		ob_log::write ERROR "play_register - $msg"
	}

	#
	# bind the valid account types
	#
	set reg_acct_types ""
	set reg_acct_owner [reqGetArg acct_owner]

	# for hedging/fielding cust_types, only allow credit accounts
	if {$reg_acct_owner == "Y" || $reg_acct_owner == "F" || $reg_acct_owner == "G"} {
		if {[op_allowed CreateCreditAcc]} {
			append reg_acct_types ",\"CDT\", \"Credit\""
		}
	} else {
		foreach f [OT_CfgGet REG_ACCT_TYPES [list DEP]] {
			switch -- $f {
				"DBT" { append reg_acct_types ",\"DBT\", \"Debit\"" }
				"DEP" { append reg_acct_types ",\"DEP\", \"Deposit\"" }
				"CDT" { if {[op_allowed CreateCreditAcc]} {
						append reg_acct_types ",\"CDT\", \"Credit\""
					}
				}
			}
		}
	}

	OT_LogWrite 5 "$reg_acct_types"
	tpBindString reg_acct_types $reg_acct_types

	#
	# reset any previous defaults
	#
	tpSetVar NewUser 	 [reqGetArg NewUser]
	tpBindString NewUser [reqGetArg NewUser]

	reqSetArg ShopNumber  [reqGetArg shop_no]
	reqSetArg StaffMember [reqGetArg staff_member]

	#
	# bind textual values
	#
	foreach f {
		title
		fname
		mname
		lname
		dob
		addr_street_1
		addr_street_2
		addr_street_3
		addr_street_4
		addr_city
		addr_country
		addr_postcode
		telephone
		mobile
		office
		email
		fax
		pager
		source
		challenge_1
		response_1
		challenge_2
		response_2
		salutation
		occupation
		min_repay
		min_settle
		min_funds
		hear_about_txt
		code_txt
		acct_no
		card_no
		start
		expiry
		issue_no
		hldr_name
		username
		cust_id
		pay_pct
		settle_type
		due_from
		due_to
		freq_amt
		freq_unit
		acct_type
		currency_code
		itv_email
		sig_date
		credit_limit
		CustId
		aff_id
		contact_how
		ShopNumber
		StaffMember
		deposit_limit
		rep_code
	} {

		tpBindString $f [reqGetArg $f]
	}
	tpBindString CCYCode    [reqGetArg currency_code]

	#
	# bind values for check boxes
	#
	foreach f {
		elite
		ap_on
		tax_on
		contact_ok
		ptnr_contact_ok
		mkt_contact_ok
		brief
		enforce_period
		stmt_on
	} {
		if {[reqGetArg $f] == "Y"} {
			tpBindString ${f}_chk "checked"
		}
	}

	#
	# If a cust_type has been submitted, use it. If not, set it to the default
	# value of (C)ustomer
	#
	if {[reqGetArg acct_owner] == ""} {
		tpBindString acct_owner "C"
	} else {
		tpBindString acct_owner [reqGetArg acct_owner]
	}

	# For each of Email,Letter,Telephone and SMS
 	# set the value to whether or not contact_how has the that letter in it
	array set contact_how_map [OT_CfgGet CONTACT_HOW_MAP ""]
	if {[array size contact_how_map] > 0} {

		set idx 0
		foreach {code name} [array get contact_how_map] {
			OT_LogWrite 12 "Checking for '$code' in '[reqGetArg contact_how]'"
			set CONTACT_HOW($idx,code) $code
			set CONTACT_HOW($idx,name) $name
			set CONTACT_HOW($idx,chk) [expr {[string first $code [reqGetArg contact_how]] >= 0?"checked":""}]
			incr idx
		}
		set CONTACT_HOW(num) $idx

		tpBindString contact_how_all_chk [expr {[string length [reqGetArg contact_how]] == $idx?"checked":""}]

		unset idx

		# the one letter code, the name of the contact method and whether it is checked
		tpBindVar contact_how_code	CONTACT_HOW code	contact_how_idx
		tpBindVar contact_how_name	CONTACT_HOW name	contact_how_idx
		tpBindVar contact_how_chk	CONTACT_HOW chk		contact_how_idx
	}
	array unset contact_how_map

	#
	# other
	#
	if {[reqGetArg price_type] == "DECIMAL"} {
		tpBindString decimal_chk "checked"
	}
	tpBindString gender_[reqGetArg gender]_chk "checked"
	tpBindString settle_type_[reqGetArg settle_type]_chk "checked"
	tpSetVar acct_type [reqGetArg acct_type]
	tpBindString selected_[reqGetArg deposit_limit] "selected"

	#
	# Is the rep code enabled, or is it a new customer?
	#
	if {[reqGetArg rep_code_status] == "X" || [reqGetArg rep_code_disable] == "on" 
			|| [reqGetArg SubmitName] == "ChangeAcctOwner"} {
		tpBindString rep_code_disabled "disabled"
		tpBindString rep_code_chk "checked"
	}

	#
	# grab list of currencies
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
			('ATS','DEM','ESP','FIM','FRF','GRD','IEP','ITL','NLG','PTE')
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

	#
	# countries
	#
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

	db_close $res

	#
        # states
        #

        set state_sql {
                select
                        s.id,
                        s.country_code,
                        s.state
                from
                        tCountryState s,
			tCountry      c
		where
			c.country_code = s.country_code and
			c.status       = 'A'
                order by
                        s.country_code,
			s.state
        }

        set stmt [inf_prep_sql $DB $state_sql]
        set res  [inf_exec_stmt $stmt $]
        inf_close_stmt $stmt

        tpSetVar NumStates [set n_rows [db_get_nrows $res]]

        for {set r 0} {$r < $n_rows} {incr r} {

                set state_code 		[db_get_col $res $r id]
		set state 		[db_get_col $res $r state]
		set state_cc		[db_get_col $res $r country_code]

                set DATA($r,state_code) 	$state_code
                set DATA($r,state) 		$state
		set DATA($r,state_cc) 		$state_cc
                if {$DefaultState == $state_code} {
                        set DATA($r,state_sel) SELECTED
                } else {
                        set DATA($r,state_sel) ""
                }
        }

        tpBindVar StateCode 	DATA state_code 	state_idx
        tpBindVar State 	DATA state 		state_idx
        tpBindVar StateSel  	DATA state_sel  	state_idx
	tpBindVar StateCC	DATA state_cc		state_idx
	tpBindString	DefaultState	$DefaultState

        db_close $res

	#
	# affiliates
	#
	set affiliate_sql {
		select
			aff_id,
			aff_name
		from
			tAffiliate
		where
			status = 'A'
	}

	set stmt [inf_prep_sql $DB $affiliate_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumAffiliates [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set aff_id [db_get_col $res $r aff_id]

		set DATA($r,aff_id) $aff_id
		set DATA($r,aff_name) [db_get_col $res $r aff_name]

		if {$DefaultAffiliate == $aff_id} {
			set DATA($r,aff_sel) SELECTED
		} else {
			set DATA($r,aff_sel) ""
		}
	}

	tpBindVar AffiliateId DATA aff_id affiliate_idx
	tpBindVar AffiliateName DATA aff_name affiliate_idx
	tpBindVar AffiliateSel DATA aff_sel affiliate_idx

	db_close $res

	#
	# languages
	#
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

	#
	# football teams
	#
	set fbteam_sql {
		select
			flag_value fbteam
		from
			tcustflagval
		where
			flag_name = 'FootBall Team'
		order by
			flag_value
	}

	set stmt [inf_prep_sql $DB $fbteam_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumFBTeams [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set fbteam [db_get_col $res $r fbteam]

		set DATA($r,fbteam)   $fbteam
		if {$DefaultFBTeam == $fbteam} {
			set DATA($r,fbteam_sel) SELECTED
		} else {
			set DATA($r,fbteam_sel) ""
		}
	}

	tpBindVar FBTeam   	  DATA fbteam    	 fbteam_idx
	tpBindVar FBTeamSel   DATA fbteam_sel    fbteam_idx


	#
	# Customer analysis codes
	#
	set code_sql {
		select
			cust_code,
			desc
		from
			tCustCode
	}

	set stmt [inf_prep_sql $DB $code_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set n_rows [db_get_nrows $res]

	for {set r 0} {$r < $n_rows} {incr r} {

		set DATA($r,code)       [db_get_col $res $r cust_code]
		set DATA($r,code_desc)  [db_get_col $res $r desc]

		if {$DefaultCode == [db_get_col $res $r cust_code]} {
			set DATA($r,code_sel) SELECTED
		} else {
			set DATA($r,code_sel) ""
		}
	}

	tpSetVar  NumCodes  $r
	tpBindVar code      DATA code      code_idx
	tpBindVar code_desc DATA code_desc code_idx
	tpBindVar code_sel  DATA code_sel  code_idx

	#
	# Customer sorts (tax group)
	#
	set sort_sql {
		select
			sort
		from
			tcustomersort
	}

	set stmt [inf_prep_sql $DB $sort_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSorts [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {

		set DATA($r,sort)       [db_get_col $res $r sort]

		if {$DefaultSort == [db_get_col $res $r sort]} {
			set DATA($r,sort_sel) SELECTED
		} else {
			set DATA($r,sort_sel) ""
		}
	}

	tpBindVar sort      DATA sort      sort_idx
	tpBindVar sort_sel  DATA sort_sel  sort_idx

	#
	# Intro Source Type
	#
	set hear_about_type_sql {
		select unique
			hear_about_type
		from
			tHearAbout
	}

	set stmt [inf_prep_sql $DB $hear_about_type_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumHearAboutType [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,hear_about_type) ""

	for {set r 0} {$r < $n_rows} {incr r} {

		set rr [expr {$r+1}]

		set hear_about_type [db_get_col $res $r hear_about_type]

		set DATA($rr,hear_about_type)   $hear_about_type

		if {$DefaultHearAboutType == $hear_about_type} {
			set DATA($rr,hear_about_type_sel)  SELECTED
		} else {
			set DATA($rr,hear_about_type_sel)  ""
		}
	}
	tpBindVar hear_about_type      DATA hear_about_type      hear_about_type_idx
	tpBindVar hear_about_type_sel  DATA hear_about_type_sel  hear_about_type_idx

	#
	# Introductory Source
	#
	set hear_about_sql {
		select
			hear_about hear_about,
			hear_about_type type,
			desc desc,
			disporder
		from
			tHearAbout
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $hear_about_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumHearAbout [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,hear_about) ""
	set DATA(0,hear_about_desc) ""
	set DATA(0,hear_about_type_id) ""

	for {set r 0} {$r < $n_rows} {incr r} {

		set rr [expr {$r+1}]

		set hear_about [db_get_col $res $r hear_about]

		set DATA($rr,hear_about)   $hear_about
		set DATA($rr,hear_about_desc)        [db_get_col $res $r desc]
		set DATA($rr,hear_about_type_id)     [db_get_col $res $r type]

	}

	tpBindVar hear_about         DATA hear_about      hear_about_idx
	tpBindVar hear_about_desc    DATA hear_about_desc hear_about_idx
	tpBindVar hear_about_type_id DATA hear_about_type_id hear_about_idx
	tpBindString hear_about_sel $DefaultHearAbout

	tpBindString hear_about_free_txt  [reqGetArg hear_about_free_txt]


	#
	# Partnership Flags
	#
	set partner_sql {
		select
			ptnr_code,
			desc desc,
			disporder
		from
			tPartner
		order by
			disporder
	}

	set stmt [inf_prep_sql $DB $partner_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumPartner [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,ptnr_code) ""
	set DATA(0,partner_desc) "Unspecified"

	for {set r 0} {$r < $n_rows} {incr r} {

		set rr [expr {$r+1}]

		set ptnr_code [db_get_col $res $r ptnr_code]

		set DATA($rr,ptnr_code)      $ptnr_code
		set DATA($rr,partner_desc)   [db_get_col $res $r desc]

		if {$DefaultPartner == $ptnr_code} {
			set DATA($rr,partner_sel)  SELECTED
		} else {
			set DATA($rr,partner_sel)  ""
		}
	}

	tpBindVar ptnr_code    DATA ptnr_code    partner_idx
	tpBindVar partner_desc DATA partner_desc partner_idx
	tpBindVar partner_sel  DATA partner_sel  partner_idx

	#
	# Channels
	#

	# If we have a default source defined in the config
	# override the global default of P
	tpBindString source [OT_CfgGet DEFAULT_TB_REG_SOURCE "P"]

	set control_sql {
		select reg_param_combi
		from tcontrol
	}
	set stmt [inf_prep_sql $DB $control_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set reg_param_combi [db_get_col $res 0 reg_param_combi]
	db_close $res

	if {$reg_param_combi == "C" || [op_allowed UpdRegChannel] || [OT_CfgGet TB_REG_SHOW_CHANNELS 0]} {
		#
		# Registration source
		#
		if {![reqGetArg NewUser]} {
			#Existing user - get existing source
			set default_source_sql {
				select
					source
				from
					tcustomer
				where
					cust_id = ?
			}

			set stmt [inf_prep_sql $DB $default_source_sql]
			set res  [inf_exec_stmt $stmt [reqGetArg CustId]]
			inf_close_stmt $stmt

			if {[db_get_nrows $res] != 1} {
				tpBindString source          I
			} else {
				tpBindString source   [db_get_col $res 0 source]
			}
			db_close $res
		}

		set channel_sql {
			select
				channel_id,
				desc
			from
				tChannel
		}

		set stmt [inf_prep_sql $DB $channel_sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpSetVar NumChannels [set n_rows [db_get_nrows $res]]

		for {set r 0} {$r < $n_rows} {incr r} {
			set DATA($r,channel)      [db_get_col $res $r channel_id]
			set DATA($r,channel_name) [db_get_col $res $r desc]
		}

		tpBindVar Channel     DATA channel      channel_idx
		tpBindVar ChannelName DATA channel_name channel_idx

		tpSetVar ShowChannels 1

	} else {

		tpSetVar ShowChannels 0
	}

	#
	# Group Cleardowns
	#
	set group_sql {
		select
			cd_grp_id,
			cd_grp_name,
			cd_days
		from
			tGrpClearDown
		where
			status = 'A'
		order by
			cd_grp_name
	}

	set stmt [inf_prep_sql $DB $group_sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumGroups [expr {1+[set n_rows [db_get_nrows $res]]}]

	set DATA(0,cd_grp_id) ""
	set DATA(0,cd_grp_name) "None"
	set DATA(0,cd_days) ""

	for {set r 0} {$r < $n_rows} {incr r} {

		set rr [expr {$r+1}]

		set cd_grp_id [db_get_col $res $r cd_grp_id]

		set DATA($rr,cd_grp_id)     $cd_grp_id
		set DATA($rr,cd_grp_name)   [db_get_col $res $r cd_grp_name]
		set DATA($rr,cd_days)       [db_get_col $res $r cd_days]

		if {$DefaultCDGroup == $cd_grp_id} {
			set DATA($rr,cd_grp_sel)  SELECTED
		} else {
			set DATA($rr,cd_grp_sel)  ""
		}
	}

	tpBindVar     cd_grp_id       DATA cd_grp_id    cd_grp_idx
	tpBindVar     cd_grp_name     DATA cd_grp_name  cd_grp_idx
	tpBindVar     cd_days         DATA cd_days      cd_grp_idx
	tpBindVar     cd_grp_sel      DATA cd_grp_sel   cd_grp_idx
	tpBindString  cd_grp_default  $DefaultCDGroup

	#
	# bind external customer groups
	#
	set ext_groups_count [reqGetArg ext_groups_count]
	if {$ext_groups_count==""} {
		set ext_groups_count 0
	}

	for {set r 0} {$r < $ext_groups_count} {incr r} {
		set DATA($r,ext_code) 		[reqGetArg "ext_code_$r"]
		set DATA($r,ext_display) 	[reqGetArg "ext_display_$r"]
		set DATA($r,ext_cust_id) 	[reqGetArg "ext_cust_id_$r"]

		# Convert Y/N columns to 'checked'
		foreach f {ext_master ext_permanent} {
			if {[reqGetArg "${f}_$r"] == "Y"} {
				set DATA($r,$f) "checked=\"checked\""
			} else {
				set DATA($r,$f) ""
			}
		}
	}

	if {[OT_CfgGet FUNC_OVS 0]} {
		tpBindString AGE_VRF_STATUS \
			[verification_check::get_ovs_status [reqGetArg CustId] {AGE}]
	}


	tpSetVar NumExtGroups $ext_groups_count

	tpBindVar ExtGroupCode  DATA ext_code           ext_group_idx
	tpBindVar ExtGroupDisp  DATA ext_display        ext_group_idx
	tpBindVar ExtCustId     DATA ext_cust_id        ext_group_idx
	tpBindVar ExtMaster     DATA ext_master         ext_group_idx
	tpBindVar ExtPermanent  DATA ext_permanent      ext_group_idx


	# Customer deposit limits work
	# get available deposit limits for all currencies

	set get_all_ccy_limits {
		select
			trunc(setting_value * 1, 2) as dep_limit,
			setting_name as ccy_code
		from
			tSiteCustomVal
		order by
			ccy_code,
			dep_limit
	}

	set stmt [inf_prep_sql $DB $get_all_ccy_limits]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set ccy_code ""
	set ccy_idx  -1
	set lim_idx  0

	if {[db_get_nrows $res] > 0} {

		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {

			if {[db_get_col $res $i ccy_code] != $ccy_code} {
				set  ccy_code [db_get_col $res $i ccy_code]
				incr ccy_idx
				set  lim_idx  0
			}

			set DEPOSIT_LIMIT($ccy_idx,ccy_code) $ccy_code
			set DEPOSIT_LIMIT($ccy_idx,$lim_idx,dep_limit) [db_get_col $res $i dep_limit]

			incr lim_idx

			set DEPOSIT_LIMIT($ccy_idx,num_limits) $lim_idx
		}
	}

	tpSetVar num_currencies [expr {$ccy_idx + 1}]

	db_close $res

	tpBindVar  dep_limit_ccy_code    DEPOSIT_LIMIT  ccy_code     dep_lim_idx
	tpBindVar  dep_limit_num_limits  DEPOSIT_LIMIT  num_limits   dep_lim_idx
	tpBindVar  dep_limit_amount      DEPOSIT_LIMIT  dep_limit    dep_lim_idx  dep_lim_val_idx

	#
	# If a source has been selected, rebind it
	#
	if {[reqGetArg source] != ""} {
		tpBindString source [reqGetArg source]
	}

	asPlayFile -nocache tb_reg.html
}

#
# The registration process
#
######################
proc do_register {} {
######################

	global DB DATA

	set action [reqGetArg SubmitName]
	OT_LogWrite 5 "==> do_register ($action)"

	#
	# return to customer details part of cust.tcl
	#
	if {$action == "Back"} {
		ADMIN::CUST::go_cust
		return
	}

	#
	# generate an account number and re_register
	#
	if {$action == "GoGenAcctNo"} {
		gen_acct_no
		play_register
		return
	}

	#
	# reloads the page when account type is changed so
	# that only applicable fields are displayed
	#
	if {$action == "ChangeAcctType"} {

		#
		# check if we've just changed to a credit account, if so then
		# enable statements by default
		#
		if {[reqGetArg acct_type] == "CDT"} {
			reqSetArg stmt_on "Y"
			# and also change default credit_limit to "".
			reqSetArg credit_limit ""
		} else {
			# also change default deposit_limit to "".
			reqSetArg deposit_limit "-1"
			reqSetArg stmt_on "N"
			reqSetArg credit_limit "0.00"
		}
		play_register
		return
	}

	#
	# reloads the page when customer type is changed so that we
	# can fix things like acct type.
	#
	if {$action == "ChangeAcctOwner"} {

		#
		# check if we've changed to a hedging/fielding account. If so, then
		# set the account type to credit
		#
		if {[reqGetArg acct_owner] == "Y" || [reqGetArg acct_owner] == "F" || [reqGetArg acct_owner] == "G"} {
			reqSetArg acct_type "CDT"
		}
		play_register
		return
	}

	#
	# get the address details given a post code
	#
	if {$action == "GoPCodeLookup"} {
		get_address [reqGetArg addr_street_1] [reqGetArg addr_postcode]
		play_register
		return
	}

	#
	# Force some parameters (for registration/update)
	#
	if {[reqGetArg price_type] != "DECIMAL"} {
		reqSetArg price_type "ODDS"
	}
	foreach f {elite ap_on tax_on contact_ok ptnr_contact_ok mkt_contact_ok stmt_brief stmt_on} {
		if {[reqGetArg $f] != "Y"} {
			reqSetArg $f "N"
		}
	}

	#
	# check permissions
	#
	if {![op_allowed DoCustReg]} {
		err_bind "You do not have permission to add/update customer registrations"
		play_register
		return
	}

	if {![op_allowed CreateCreditAcc] && [reqGetArg acct_type] == "CDT" } {
		err_bind "You do not have permission to create a credit account"
		play_register
		return
	}

	if {![op_allowed CreateHedgingAcc] && [reqGetArg acct_owner] == "Y" } {
		err_bind "You do not have permission to create a hedging account"
		play_register
		return
	}

	if {![op_allowed CreateFieldingAcc] && [reqGetArg acct_owner] == "F" } {
		err_bind "You do not have permission to create a fielding account"
		play_register
		return
	}

	#
	# tCustomerReg.hear_about is the hear_about_type. E.g GEN, NEWS etc
	# tCustomerReg.hear_about_txt is the hear_about and free form text
	#		E.g. SU:The nations favourite
	#	So here we concat the hear_about and free form text
	#
	set hear_about [reqGetArg -unsafe hear_about_txt]
	set free_form [reqGetArg -unsafe hear_about_free_txt]
	set new_hear_about_text "$hear_about:$free_form"
	reqSetArg hear_about_txt $new_hear_about_text


	#
	# Update customer registration
	#
	if {$action == "UpdCustReg"} {

		# if the admin user cannot view the security answer, we need to populate
		# it before calling the shared code to do the update.
		if {[OT_CfgGet FUNC_HIDE_SECURITY_RESPONSE 0] == 1 &&
				![op_allowed ViewSecurityResponse]} {
			set sec_ans_sql {
				select
					response_1,
					response_2
				from
					tCustomerReg
				where
					cust_id = ?}

			set stmt [inf_prep_sql $DB $sec_ans_sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					[reqGetArg CustId]]} msg]} {
						err_bind $msg
						play_register
						return
			}

			set nrows [db_get_nrows $res]

			if {$nrows != 1} {
				err_bind "Unable to get customer responses - 1 row expected, $nrows returned"
				play_register
				return
			}

			reqSetArg response_1 [db_get_col $res 0 response_1]
			reqSetArg response_2 [db_get_col $res 0 response_2]
		}

		#
		# Check for a valid rep code
		#
		set rep_code [reqGetArg rep_code]
		if {[reqGetArg rep_code_disable] == "on"} {
			set rep_code_status "X"
		} else {
			set rep_code_status "A"
		}

		if {$rep_code != "" && $rep_code_status == "A" && [reqGetArg acct_owner] == "F"} {
			# Need to ignore the account which we're updating
			set rep_code_sql {
				select
					ocr.rep_code
				from
					tOnCourseRep ocr,
					tAcct a
				where
					ocr.status = 'A' and
					ocr.acct_id = a.acct_id and
					a.cust_id <> ?
			}

			set stmt         [inf_prep_sql $DB $rep_code_sql]
			set rep_code_res [inf_exec_stmt $stmt [reqGetArg CustId]]
			inf_close_stmt $stmt

			set codes ""
			for {set i 0} {$i < [db_get_nrows $rep_code_res]} {incr i} {
				lappend codes [db_get_coln $rep_code_res $i 0]
			}

			if {[lsearch $codes $rep_code] != -1} {
				err_bind [subst {Invalid rep code - other currently used rep codes are: [join $codes ", "]}]
				play_register
				return
			}
		}

		# attempt update
		array set DATA ""
		if {![tb_register::tb_do_update_details DATA]} {
			err_bind [join [tb_register::tb_reg_err_get] "<br>\n"]
			play_register
			return
		} elseif {[op_allowed UpdRegChannel] && ![OT_CfgGet USE_SITE_OPERATOR 0]} {

			# swalker - update source - NB: Would be neater to do this with the rest but
			# this would involve changing shared_tcl and impact other apps

			set upd_source_sql {
				update
					tCustomer
				set
					source =?
				where
					cust_id = ?

			}

			set stmt [inf_prep_sql $DB $upd_source_sql]

			set regsource [reqGetArg -unsafe source]

			if {$regsource != ""} {
				if {[catch {
					set res [inf_exec_stmt $stmt\
						$regsource\
						[reqGetArg CustId]]} msg]} {
							err_bind $msg
							play_register
							return
				}
			}
			inf_close_stmt $stmt
			db_close $res

		}
		unset DATA

		if {[OT_CfgGet FUNC_OVS 0]} {
			_do_cust_upd_ovs_flag [reqGetArg CustId]
		}

		# return to customer details (cust.tcl)
		OT_LogWrite 5 "cust_id = [reqGetArg CustId]"

		if {[OT_CfgGet FUNC_SEND_CUST_EMAILS 0] == 1} {
			set queue_email_func [OT_CfgGet CUST_QUEUE_EMAIL_FUNC "queue_email"]
			set params [list CHANGE_OF_DETAILS [reqGetArg CustId]]

			# send an email
			if {[catch {set res [eval $queue_email_func $params]} msg]} {
				OT_LogWrite 2 "Failed to queue change of details email, $msg"
			}
		}

		ADMIN::CUST::go_cust
		return

	} elseif {$action == "DoRegister"} {


		#if the customer is not a debit customer not interested
		#in the cleardown groups
		set acct_type [reqGetArg acct_type]

		if {$acct_type != "DBT"} {
			reqSetArg cd_grp_id ""
		}

		set site_operator_id [card_util::get_chan_site_operator_id [reqGetArg -unsafe source]]

		# check for duplicate card
		if {[reqGetArg card_no] != ""} {
		
			if {![card_util::verify_card_not_used \
			                 [reqGetArg card_no] -1 $acct_type $site_operator_id]} {
				
				#check permissions
				if {![op_allowed OverrideDuplicateCPM]} {
					if {[OT_CfgGet CPM_CHECK_FOR_ANY_DUPLICATES 0]} {
						OT_LogWrite 1 "***Warning duplicate card: Override Allowed but card will be suspended"
						msg_bind "Warning duplicate card: Card has been suspended and deposits and withdrawals have been blocked on this account"
						reqSetArg allow_duplicate_card 0
						reqSetArg check_for_duplicate_card 0
					} else {
						err_bind "card already registered on another account<br>\n"
						play_register
						return
					}
				} else {
					OT_LogWrite 1 "***Warning duplicate card: Override Allowed"
					msg_bind "Warning duplicate card: Override Allowed"
					# override in tb_do_registration
					reqSetArg allow_duplicate_card 1
				}
			}
		}

		if {[reqGetArg aff_id] != ""} {

			# Check the affliliate id is valid
			set affiliate_sql {
				select
					aff_name
				from
					taffiliate
				where
					aff_id = ?
			}

			set stmt [inf_prep_sql $DB $affiliate_sql]
			set res  [inf_exec_stmt $stmt [reqGetArg aff_id]]
			inf_close_stmt $stmt

			if {[db_get_nrows $res] == 0} {
				err_bind "The affiliate id [reqGetArg aff_id] is invalid<br>\n"
				play_register
				return
			}
			db_close $res
		}

		if {[reqGetArg ShopNumber] != ""} {
			# Get the shop_id using the shop number
			set shop_sql {
				select
					shop_id
				from
					tRetailShop
				where
					shop_no = ?
			}

			set stmt [inf_prep_sql $DB $shop_sql]
			set res  [inf_exec_stmt $stmt [reqGetArg ShopNumber]]
			inf_close_stmt $stmt

			if {[db_get_nrows $res] == 0} {
				db_close $res
				err_bind "The shop id [reqGetArg ShopNumber] is invalid<br>\n"
				play_register
				return
			}

			reqSetArg ShopId [db_get_col $res 0 shop_id]
			db_close $res
		}

		#
		# Validate the form input
		#

		set acct_type [reqGetArg acct_type]

		set is_shop_fielding_account 0
		if {[reqGetArg ShopNumber] != "" && [reqGetArg acct_owner] == "F"} {
			set is_shop_fielding_account 1
		}

		if {$is_shop_fielding_account} {
			# Shop Fielding accounts require only a shop number
			array set MANDATORY_FIELDS [list]
		} else {
			# The mandatory fields. Array of field_name and the account types
			# that it is mandatory for
			array set MANDATORY_FIELDS [list \
				acct_type      {DBT DEP CDT} \
				hldr_name      {DBT}         \
				card_no        {DBT}         \
				expiry         {DBT}         \
				title          {DBT DEP CDT} \
				fname          {DBT DEP CDT} \
				lname          {DBT DEP CDT} \
				addr_street_1  {DBT DEP CDT} \
				addr_street_2  {DBT DEP CDT} \
				addr_postcode  {DBT DEP CDT} \
				country_code   {DBT DEP CDT} \
				salutation     {DBT}         \
				occupation     {CDT}         \
				gender         {DBT DEP}     \
				dob            {DBT DEP CDT} \
				hear_about     {DBT DEP CDT} \
				contact_ok     {DBT DEP}     \
				freq_unit      {DBT DEP CDT} \
				dlv_method     {DBT DEP CDT} \
				lang_code      {DBT CDT}     \
				currency_code  {DBT DEP CDT} \
				credit_limit   {CDT}         \
				deposit_limit  {DBT DEP}     \
			]
		}

		foreach field_name [array names MANDATORY_FIELDS] {
			if {[lsearch $MANDATORY_FIELDS($field_name) $acct_type] != -1} {
				if {[reqGetArg $field_name] eq ""} {
					# Madatory field missing
					err_bind "Mandatory field missing: $field_name"
					play_register
					return
				}
			}
		}

		if {$acct_type eq "DBT" || $acct_type eq "DEP"} {
			# Ensure that we have a phone number
			if {[reqGetArg mobile] eq "" && [reqGetArg telephone] eq ""} {
				err_bind "Mandatory field missing: Mobile or Telephone"
				play_register
				return
			}
		}

		if {$is_shop_fielding_account} {
			# This must be a shop fielding account and we need to generate some extra fields
			# The first char of the username will be a space
			reqSetArg ignore_mand "Y"
			reqSetArg OwnerType "LOG"

			# Get and check the log number
			set log_no  [reqGetArg LogNo]
			set shop_no [reqGetArg ShopNumber]

			set username [_get_next_shop_username $shop_no $log_no]

			# Check to make sure a valid log number has been used
			if {$username == "failed"} {
				err_bind "Log number already in use for this shop"
				play_register
				return
			} else {
				reqSetArg username $username
			}

			# Set the statements to off
			reqSetArg stmt_available "N"
			reqSetArg stmt_on        "N"

			if {[reqGetArg credit_limit] == "" || [reqGetArg credit_limit] == "0.00"} {
				reqSetArg credit_limit [OT_CfgGet SHOP_FIELDING_CRED_LIMIT "9999999999.99"]
			}

			# Rebind the logs and shop numbers
			reqSetArg log_no  $log_no
			reqSetArg shop_no $shop_no

		} else {

			if {[reqGetArg username] == "" && [reqGetArg acct_no] == ""} {
				reqSetArg gen_acct_no_on_reg "Y"
			}

			# For non shop fielding accounts we need to make sure the first char is not a space
			if {[string first " " [reqGetArg username]] != -1} {
				## no spaces in username please
				err_bind "invalid username (no spaces allowed)"
				play_register
				return
			}

			# Non-null usernames must be 6-15 characters 
			if {[reqGetArg username] != "" && [string length [reqGetArg username]] < 6} {
				err_bind "invalid username (minimum username length is 6)"
				play_register
				return
			}
			if {[string length [reqGetArg username]] > 15} {
				err_bind "invalid username (maximum username length is 15)"
				play_register
				return
			}
		}

		# dob as a required field using calls to tb_register functions in shared_tcl
		set dob_string [reqGetArg dob]
		if {$dob_string != ""} {

			# check if dob is in valid format, NB: doesn't check if valid date.
			if {![regexp {^\d{4}-\d\d-\d\d$} $dob_string]} {
				err_bind "incorrect format for date of birth"
				play_register
				return
			}

			set dob_list   [split $dob_string -]
			set dob_y      [lindex $dob_list 0]
			set dob_m      [lindex $dob_list 1]
			set dob_d      [lindex $dob_list 2]
			# use function in shared_tcl/tb_register to check if valid date
			tb_register::tb_reg_err_reset
			tb_register::chk_dob $dob_y $dob_m $dob_d

			if {[tb_register::tb_reg_err_num]} {
				err_bind [join [tb_register::tb_reg_err_get] "<br>\n"]
				play_register
				return
			}

		} elseif {!$is_shop_fielding_account} {
			err_bind "date of birth is mandatory"
			play_register
			return
		}

		if {[reqGetArg credit_limit] == "" && [reqGetArg acct_type] == "CDT"} {
			# mandatory credit limit
			err_bind "credit limit is mandatory"
			play_register
			return
		}

		if {[reqGetArg deposit_limit] == "-1" && ([reqGetArg acct_type] == "DBT" || [reqGetArg acct_type] == "DEP")} {
			#mandatory deposit limit
			err_bind "deposit limit is mandatory"
			play_register
			return
		}

		#
		# Check the rep code, if invalid return taken values
		#
		set rep_code [reqGetArg rep_code]
		if {[reqGetArg rep_code_disable] == "on"} {
			set rep_code_status "X"
		} else {
			set rep_code_status "A"
		}

		if {$rep_code != "" && $rep_code_status == "A" && [reqGetArg acct_owner] == "F"} {
			set rep_code_sql {
				select
					rep_code
				from
					tOnCourseRep
				where
					status = 'A'
			}

			set stmt         [inf_prep_sql $DB $rep_code_sql]
			set rep_code_res [inf_exec_stmt $stmt]
			inf_close_stmt $stmt

			set codes ""
			for {set i 0} {$i < [db_get_nrows $rep_code_res]} {incr i} {
				lappend codes [db_get_coln $rep_code_res $i 0]
			}

			if {[lsearch $codes $rep_code] != -1} {
				err_bind [subst {Invalid rep code - currently used rep codes are: [join $codes ", "]}]
				play_register
				return
			}
		}

		#
		# Actually do the registration
		#
		set new_cust_id [tb_register::tb_do_registration]
		if [tb_register::tb_reg_err_num] {
			err_bind [join [tb_register::tb_reg_err_get] "<br>\n"]
			play_register
			return
		}

		set code ""
		if {$new_cust_id && [OT_CfgGetTrue CUST_MATCHER_ENABLED]} {
			ob_log::write DEV "CM was enabled"
			# link customer via URN by CUST_MATCHER rules
			# if an error was thrown, then cust_mather found a problem with the registration
			set match_code ""
			if {[catch {
				set match_code [cust_matcher::match $new_cust_id]
			} msg]} {
				ob_log::write WARNING "Problem running cust_matcher::match $new_cust_id:  $msg"
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

		if {!$new_cust_id || $code != ""} {
			# rebind all the variables
			play_register
			return
		}

		# ok, we have created the new customer. let's see if we need to
		# set him a deposit limit
		if {[reqGetArg deposit_limit] != "-1" && [reqGetArg deposit_limit] != "NO_LIMIT"} {
			set res [ob_srp::set_deposit_limit $new_cust_id \
			                                   [reqGetArg deposit_limit_freq] \
			                                   [reqGetArg deposit_limit]]
			if {[lindex $res 0] == 0} {
				OT_LogWrite 2 [set msg "Failed to update deposit limit: You must wait [OT_CfgGet DAY_DEP_LIMIT_CHNG_PERIOD -1] days before changing the limit"]
				tb_reg_err_add $msg
				play_register
				return
			}
		}

		#
		# return to customer details
		#
		reqSetArg CustId $new_cust_id
		OT_LogWrite 5 "cust_id = [reqGetArg CustId]"
		#srobins - MCS add user
		if {[OT_CfgGet FUNC_MCS_POKER 0]} {
			set result [ADMIN::MCS_CUST::do_mcs_registration $new_cust_id]
			if {[lindex $result 0]} {
				err_bind "[lindex $result 1]"
			}
		}
		ADMIN::CUST::go_cust
		return
	}

	error "invalid action"
}


#
# generate an account number automatically (bound in play_register)
#
######################
proc gen_acct_no {} {
######################

	set acct_no [tb_register::tb_reg_gen_acct_no]
	reqSetArg acct_no $acct_no
}


#
# get the address details the post code
#
####################################
proc get_address {house_no pcode} {
####################################

	set addr [capscan::capscan_pcode_lookup $house_no $pcode]
	OT_LogWrite 15 "capscan: $addr"
	if { $addr != "FAULT" } {
		reqSetArg addr_street_1 [capscan::capitalise_first [lindex $addr 3]]
		reqSetArg addr_street_2 [capscan::capitalise_first [lindex $addr 5]]
		reqSetArg addr_street_3 [capscan::capitalise_first [lindex $addr 7]]
		reqSetArg addr_street_4 [capscan::capitalise_first [lindex $addr 8]]
		reqSetArg addr_city     [capscan::capitalise_first [lindex $addr 9]]
		reqSetArg addr_postcode [capscan::split_pcode [string toupper $pcode]]

	} else {
		reqSetArg addr_street_1 ""
		reqSetArg addr_street_2 ""
		reqSetArg addr_street_3 ""
		reqSetArg addr_street_4 ""
		reqSetArg addr_city ""
		reqSetArg addr_postcode ""
	}
}


######################################################
proc get_array_key_for {value array_name {debug 0}} {
######################################################
#
# searches an array for a value and returns the key for that value
# assumes values are unique - else you'll get the first one
#

	upvar 1 $array_name arry

	foreach {e f} [array get arry] {
		if {$f == $value} {
			return $e
		}
	}

	return ""
}


#
# ----------------------------------------------------------------------------
# Updates customer ovs status flag
# ----------------------------------------------------------------------------
#

proc _do_cust_upd_ovs_flag {cust_id} {

	global DB USERNAME

	set upd_age_vrf_status {
		execute procedure pUpdVrfCustStatus
		(
			p_adminuser     = ?,
			p_cust_id       = ?,
			p_status        = ?,
			p_vrf_prfl_code = ?
		)
	}

	set vrf_status [reqGetArg age_verified_list]

	if {$vrf_status != ""} {
		set stmt [inf_prep_sql $DB $upd_age_vrf_status]
		set c [catch {
			set res [inf_exec_stmt $stmt\
				$USERNAME \
				[reqGetArg CustId]\
				$vrf_status\
				[OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""]]
				catch {db_close $res}
		} msg]

		if {$c} {
			err_bind $msg
		}

		inf_close_stmt $stmt

		db_close $res
	}
}



#
# Generate and return a username for a new shop fielding account.  Creates 
# the username based upon the shop number and log number.  If no log number 
# is provided, then it is autogenerated.
#
# - shop_no : shop which this punter is associated with
# - log_no : OPTIONAL, without being supplied, autogenerates log number, 
#             otherwise creates username with this log_no (if valid)
#
# - returns: username if autogenerating or log_no is not already used,
#             otherwise returns "failed"
#
proc _get_next_shop_username { shop_no {log_no ""} } {
	global DB

	if {$log_no == ""} {

		# Check for other logged punters at this shop
		set sql [subst {
			select
				username
			from
				tCustomer
			where
				username like ' LBO_${shop_no}_LOG_%'
				and username not like '%CLOSED%'
			}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set nrows [db_get_nrows $rs]

		if {$nrows == 0} {
			db_close $rs
			return " LBO_${shop_no}_LOG_1"
		}

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

		return " LBO_${shop_no}_LOG_${max_user_num}"

	} else {
		# Check for other logged punter with this log number
		set sql [subst {
			select
				username
			from
				tCustomer
			where
				username like ' LBO_${shop_no}_LOG_${log_no}'
				and username not like '%CLOSED%'
			}]

		set stmt [inf_prep_sql $DB $sql]
		set rs  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		# If one is found, return failed, otherwise return new username
		if {[db_get_nrows $rs]} {
			return "failed"
		} else {
			return " LBO_${shop_no}_LOG_${log_no}"
		}
	}

}

}
