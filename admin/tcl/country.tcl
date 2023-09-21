# ==============================================================
# $Id: country.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::COUNTRY {

asSetAct ADMIN::COUNTRY::GoCountryList    [namespace code go_country_list]
asSetAct ADMIN::COUNTRY::GoCountry        [namespace code go_country]
asSetAct ADMIN::COUNTRY::DoCountry        [namespace code do_country]
asSetAct ADMIN::COUNTRY::GoViewPermMatrix [namespace code go_view_perm_matrix]

asSetAct ADMIN::COUNTRY::GoCountryCheckSearch [namespace code go_cntry_chk_srch]
asSetAct ADMIN::COUNTRY::DoCountryCheckSearch [namespace code do_cntry_chk_srch]

#
# set up search screen for looking up geopoint checks
#
proc go_cntry_chk_srch args {

	global DB

	## bind op code information
	set sql [subst {
		select
			op_code,
			desc
		from
			tCntryBanOpDesc
		order by
			desc asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res1  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCodes [db_get_nrows $res1]

	tpBindTcl OpCode sb_res_data $res1 op_code_idx op_code
	tpBindTcl Desc   sb_res_data $res1 op_code_idx desc

	## bind category information
	set sql [subst {
		select
			category
		from
			tEvCategory
		order by
			category asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res2  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCats [db_get_nrows $res2]

	tpBindTcl Cat sb_res_data $res2 cat_idx category

	## bind country information
	set sql [subst {
		select
			country_code,
			country_name
		from
			tCountry
		order by
			country_code asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res3  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCountries [db_get_nrows $res3]

	tpBindTcl CountryCode sb_res_data $res3 cnt_idx country_code
	tpBindTcl Country sb_res_data $res3 cnt_idx country_name

	asPlayFile -nocache country_check_search.html

	db_close $res1
	db_close $res2
	db_close $res3
}

#
# perform country check search
#
proc do_cntry_chk_srch args {

	if {![op_allowed SearchCountryChecks]} {
		err_bind "You do not have permission to search country checks"
		go_cntry_chk_srch
		return
	}

	global DB

	set where [list]

	set formUsername        [reqGetArg username]
	set formUpperUsername   [reqGetArg upper_username]
	set formIPAddress       [reqGetArg ip_addr]
	set formStartDate       [reqGetArg start_date]
	set formEndDate         [reqGetArg end_date]
	set formOpCode          [reqGetArg op_code]
	set formCategory        [reqGetArg category]
	set formCountry         [reqGetArg country]
	set cat_or_op           [reqGetArg cat_or_op]
	set match_equals        [reqGetArg equals]
	set outer "outer"

	if {$match_equals == "Y"} {
		set uname_match "="
		set percent ""
	} else {
		set uname_match "like"
		set percent "%"
	}

	if {[string length $formUsername] > 0} {
		set outer ""
		if {$formUpperUsername == "Y"} {
			lappend where "[upper_q a.username] $uname_match [upper_q '${formUsername}$percent']"
		} else {
			lappend where "a.username $uname_match \"${formUsername}$percent\""
		}
	} else {
		if {$match_equals == "Y"} {
			lappend where "c.cust_id is null"
		}
	}

	if {[string length $formIPAddress] > 0} {
		lappend where "c.ip_address = '$formIPAddress'"
	}

	if {([string length $formStartDate] > 0) || ([string length $formEndDate] > 0)} {
		lappend where [mk_between_clause c.cr_date date $formStartDate $formEndDate]
	}

	if {$cat_or_op=="cat"} {
		if {[string length $formCategory] > 0} {
			lappend where "c.category = '$formCategory'"
		}
	} elseif {$cat_or_op=="op"} {
		if {[string length $formOpCode] > 0} {
			lappend where "c.op_code = '$formOpCode'"
		}
	}

	if {$formCountry != "--"} {
		lappend where "c.country_code = '$formCountry'"
	}

	if {[llength $where]} {
		set where "and [join $where { and }]"
	}

	set sql [subst {
		select
			a.username,
			c.cust_id,
			c.ip_address,
			decode (c.check_result, "1", "Yes", "No") check_result,
			c.cr_date,
			bd.desc,
			c.category,
			cn.country_name
		from
			tCntryChk c,
			outer tCountry cn,
			$outer tCustomer a,
			outer tcntrybanopdesc bd
		where
			a.cust_id = c.cust_id and
			c.country_code = cn.country_code and
			c.op_code = bd.op_code
			$where
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumChecks [set NumChecks [db_get_nrows $res]]

	tpBindTcl Username      sb_res_data $res chk_idx username
	tpBindTcl CustId        sb_res_data $res chk_idx cust_id
	tpBindTcl IpAddr        sb_res_data $res chk_idx ip_address
	tpBindTcl CheckResult   sb_res_data $res chk_idx check_result
	tpBindTcl CrDate        sb_res_data $res chk_idx cr_date
	tpBindTcl Operation     sb_res_data $res chk_idx desc
	tpBindTcl Category      sb_res_data $res chk_idx category
	tpBindTcl Country       sb_res_data $res chk_idx country_name

	asPlayFile -nocache country_check_list.html

	db_close $res

}
#
# ----------------------------------------------------------------------------
# Go to country list
# ----------------------------------------------------------------------------
#
proc go_country_list args {

	global DB

	set sql [subst {
		select
			country_code,
			country_code_3d,
			country_name,
			status,
			disporder,
			intl_phone_code,
			bank_template
		from
			tCountry
		order by
			disporder asc, country_name asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCountrys [db_get_nrows $res]

	set sql {
		select
			app_id,
			desc
		from
			tAuthServerApp
	}

	set stmt [inf_prep_sql $DB $sql]
	set app_res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar num_apps [db_get_nrows $app_res]

	tpBindTcl CountryCode      sb_res_data $res country_idx country_code
	tpBindTcl CountryCode3D    sb_res_data $res country_idx country_code_3d
	tpBindTcl CountryName      sb_res_data $res country_idx country_name
	tpBindTcl CountryStatus    sb_res_data $res country_idx status
	tpBindTcl CountryDisporder sb_res_data $res country_idx disporder
	tpBindTcl IntlPhoneCode    sb_res_data $res country_idx intl_phone_code
	tpBindTcl Template         sb_res_data $res country_idx bank_template
	tpBindTcl app_id           sb_res_data $app_res app_idx app_id
	tpBindTcl app_desc         sb_res_data $app_res app_idx desc

	asPlayFile -nocache country_list.html

	db_close $res
	db_close $app_res
}


#
# ----------------------------------------------------------------------------
# Go to single countryrency add/update
# ----------------------------------------------------------------------------
#
proc go_country args {

	global DB
	global MB_ALLOWED
	global ENVO_ALLOWED
	global ENVO_WTD_ROUTE

	GC::mark MB_ALLOWED
	GC::mark ENVO_ALLOWED
	GC::mark ENVO_WTD_ROUTE

	variable BANK_TEMPLATES

	if {![info exists BANK_TEMPLATES]} {
		payment_BANK::get_templates BANK_TEMPLATES
	}
	set country_code [reqGetArg CountryCode]

	foreach {n v} $args {
		set $n $v
	}

	if {$country_code != ""} {
		tpBindString CountryCode $country_code
	}

	if {$country_code == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Get country information
		#
		set sql [subst {
			select
				country_code,
				country_code_3d,
				country_name,
				status,
				disporder,
				intl_phone_code,
				ccy_code,
				bank_template,
				envoy_template,
				country_stk_scale
			from
				tCountry
			where
				country_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $country_code]
		inf_close_stmt $stmt

		tpBindString CountryCode          [db_get_col $res 0 country_code]
		tpBindString CountryCode3D        [db_get_col $res 0 country_code_3d]
		tpBindString CountryName          [db_get_col $res 0 country_name]
		tpBindString CountryStatus        [db_get_col $res 0 status]
		tpBindString CountryDisporder     [db_get_col $res 0 disporder]
		tpBindString IntlPhoneCode        [db_get_col $res 0 intl_phone_code]
		tpBindString CcyCode              [db_get_col $res 0 ccy_code]
		tpBindString TemplateId           [db_get_col $res 0 bank_template]
		tpBindString CountryStkScale      [db_get_col $res 0 country_stk_scale]
		tpBindString TemplateName         $BANK_TEMPLATES([db_get_col $res 0 bank_template])
		tpBindString TemplateFields       $BANK_TEMPLATES([db_get_col $res 0 bank_template],req_fields)
		tpBindString EnvoyTemplateId      [db_get_col $res 0 envoy_template]
		tpBindString EnvoyTemplateName    $BANK_TEMPLATES([db_get_col $res 0 envoy_template])
		tpBindString EnvoyTemplateFields  $BANK_TEMPLATES([db_get_col $res 0 envoy_template],req_fields)

		db_close $res
	}

	if {[OT_CfgGet FUNC_COUNTRY_PERM_MATRIX 0]} {


		set sql {
			select
				app_id,
				desc
			from
				tAuthServerApp
		}

		set stmt [inf_prep_sql $DB $sql]
		set app_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		global PERM_ARRAY

		set num_apps [db_get_nrows $app_res]

		for {set j 0} {$j < $num_apps} {incr j} {


			set app_id [db_get_col $app_res $j app_id]
			set desc   [db_get_col $app_res $j desc]

			set PERM_ARRAY($j,app_id) $app_id
			set PERM_ARRAY($j,app_desc)   $desc

			tpSetVar num_apps $num_apps
			tpBindString span [expr $num_apps + 1]

			#
			# Get operation permissions
			#

			set sql {
				select
					d.op_code,
					d.desc,
					d.disporder,
					b.country_code
				from
					tCntryBanOpDesc d,
					outer tCntryBanOp b
				where
					b.country_code = ?
				and
					b.app_id = ?
				and b.op_code = d.op_code
				order by
					d.disporder
			}

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $country_code $app_id]
			inf_close_stmt $stmt
			set allowed_list [list]

			for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
				set PERM_ARRAY($i,$j,op_code) [db_get_col $res $i op_code]
				set PERM_ARRAY($i,$j,desc)   [db_get_col $res $i desc]
				if {[db_get_col $res $i country_code] != ""} {
					set PERM_ARRAY($i,$j,allowed) ""
				} else {
					set PERM_ARRAY($i,$j,allowed) "checked "
					lappend allowed_list [db_get_col $res $i op_code]
				}
			}

			tpSetVar  num_perms [db_get_nrows $res]
			tpBindVar op_code PERM_ARRAY op_code perm_idx c_idx
			tpBindVar desc    PERM_ARRAY desc    perm_idx c_idx
			tpBindVar allowed PERM_ARRAY allowed perm_idx c_idx

			set PERM_ARRAY($j,allowed_list)   $allowed_list
			db_close $res

			#
			# Get category permissions
			#

			set sql {
				select
					c.category,
					b.country_code
				from
					tEvCategory c,
					outer tCntryBanCat b
				where
					c.displayed = 'Y'
				and b.category = c.category
				and b.country_code = ?
				and b.app_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set res [inf_exec_stmt $stmt $country_code $app_id]
			inf_close_stmt $stmt
			set cat_allowed_list [list]
			for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
				set PERM_ARRAY($i,$j,category) [db_get_col $res $i category]
				if {[db_get_col $res $i country_code] != ""} {
					set PERM_ARRAY($i,$j,cat_allowed) ""
				} else {
					set PERM_ARRAY($i,$j,cat_allowed) "checked "
					lappend cat_allowed_list [db_get_col $res $i category]
				}
			}
			tpSetVar num_cats [db_get_nrows $res]
			tpBindVar    cat         PERM_ARRAY category    cat_idx c_idx
			tpBindVar    cat_allowed PERM_ARRAY cat_allowed cat_idx c_idx

			set PERM_ARRAY($j,cat_allowed_list)   $cat_allowed_list

			db_close $res

			#
			# Get lottery game permissions
			#

			set sql {
				select
					g.name,
					g.sort,
					l.country_code
				from
					tXGameDef g,
					outer tCntryBanLot l
				where
					l.sort = g.sort
					and l.country_code = ?
					and l.app_id = ?
			}

			set stmt [inf_prep_sql $DB $sql]
			set res [inf_exec_stmt $stmt $country_code $app_id]
			inf_close_stmt $stmt

			set lot_allowed_list [list]
			for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
				set PERM_ARRAY($i,$j,lottery_name) [db_get_col $res $i name]
				set PERM_ARRAY($i,$j,lottery) [db_get_col $res $i sort]
				if {[db_get_col $res $i country_code] != ""} {
					set PERM_ARRAY($i,$j,lot_allowed) ""
				} else {
					set PERM_ARRAY($i,$j,lot_allowed) "checked "
					lappend lot_allowed_list [db_get_col $res $i sort]
				}
			}
			tpSetVar num_lots [db_get_nrows $res]
			tpBindVar    lot         PERM_ARRAY lottery      lot_idx c_idx
			tpBindVar    lot_name    PERM_ARRAY lottery_name lot_idx c_idx
			tpBindVar    lot_allowed PERM_ARRAY lot_allowed  lot_idx c_idx

			set PERM_ARRAY($j,lot_allowed_list)   $lot_allowed_list
			db_close $res
		}

		#
		# Get channel permissions
		#

		set sql {
			select
				c.desc,
				c.channel_id,
				l.country_code
			from
				tChannel c,
				outer tCntryBanChan l
			where
				l.channel_id = c.channel_id
				and l.country_code = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $country_code]
		inf_close_stmt $stmt
		set chan_allowed_list [list]
		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			set PERM_ARRAY($i,channel_name) [db_get_col $res $i desc]
			set PERM_ARRAY($i,channel_id) [db_get_col $res $i channel_id]
			if {[db_get_col $res $i country_code] != ""} {
				set PERM_ARRAY($i,chan_allowed) ""
			} else {
				set PERM_ARRAY($i,chan_allowed) "checked "
				lappend chan_allowed_list [db_get_col $res $i channel_id]
			}
		}

		tpSetVar num_chans [db_get_nrows $res]
		tpBindVar    channel_id      PERM_ARRAY channel_id    chan_idx
		tpBindVar    channel_name    PERM_ARRAY channel_name  chan_idx
		tpBindVar    chan_allowed    PERM_ARRAY chan_allowed  chan_idx

		set PERM_ARRAY(chan_allowed_list)   $chan_allowed_list
		db_close $res

		#
		# Get system permissions
		#

		set sql {
			select
				c.desc,
				c.group_id,
				l.country_code
			from
				tXSysHostGrp c,
				outer tCntryBanSys l
			where
				l.group_id = c.group_id
				and c.type = "SYS"
				and l.country_code = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $country_code]
		inf_close_stmt $stmt
		set sys_allowed_list [list]
		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			set PERM_ARRAY($i,sys_name) [db_get_col $res $i desc]
			set PERM_ARRAY($i,sys_group_id) [db_get_col $res $i group_id]
			if {[db_get_col $res $i country_code] != ""} {
				set PERM_ARRAY($i,sys_allowed) ""
			} else {
				set PERM_ARRAY($i,sys_allowed) "checked "
				lappend sys_allowed_list [db_get_col $res $i group_id]
			}
		}

		tpSetVar num_sys [db_get_nrows $res]
		tpBindVar    sys_group_id  PERM_ARRAY sys_group_id  sys_idx
		tpBindVar    sys_name      PERM_ARRAY sys_name      sys_idx
		tpBindVar    sys_allowed   PERM_ARRAY sys_allowed   sys_idx

		set PERM_ARRAY(sys_allowed_list)   $sys_allowed_list
		db_close $res

		#
		# Get additional permissions
		#

		set sql {
			select unique
				ad.channel_id,
				cn.desc
			from
				tChannel cn,
				tCntryBanAdditionalDesc ad
			where
				cn.channel_id = ad.channel_id
		}

		set stmt [inf_prep_sql $DB $sql]
		set ch_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_chs [db_get_nrows $ch_res]

		for {set j 0} {$j < $num_chs} {incr j} {


			set ch_id [db_get_col $ch_res $j channel_id]
			set ch_desc   [db_get_col $ch_res $j desc]

			set PERM_ARRAY($j,ch_id) $ch_id
			set PERM_ARRAY($j,ch_desc)   $ch_desc

			tpSetVar num_chs $num_chs
			tpBindString ch_span [expr $num_chs + 1]

			set sql {
				select unique
					a.country_code,
					d.name,
					NVL ((select 1 from tCntryBanAdditionalDesc where name = d.name and channel_id = c.channel_id), 0) as valid
				from
					tCntryBanAdditionalDesc d,
					tCntryBanAdditionalDesc c,
					outer tCntryBanAdd a
				where
					c.channel_id = a.channel_id
					and d.name = a.name
					and a.country_code = ?
					and c.channel_id = ?
				order by d.name
			}

			set stmt [inf_prep_sql $DB $sql]
			set res  [inf_exec_stmt $stmt $country_code $ch_id]
			inf_close_stmt $stmt
			set add_allowed_list [list]

			for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
				set PERM_ARRAY($i,$j,add_name) [db_get_col $res $i name]
				set PERM_ARRAY($i,$j,add_valid)   [db_get_col $res $i valid]
				if {[db_get_col $res $i country_code] != ""} {
					set PERM_ARRAY($i,$j,add_allowed) ""
				} else {
					set PERM_ARRAY($i,$j,add_allowed) "checked "
					lappend add_allowed_list [db_get_col $res $i name]
				}
			}

			tpSetVar  num_adds [db_get_nrows $res]
			tpBindVar add_name    PERM_ARRAY add_name    add_idx ch_idx
			tpBindVar add_valid   PERM_ARRAY add_valid   add_idx ch_idx
			tpBindVar add_allowed PERM_ARRAY add_allowed add_idx ch_idx

			set PERM_ARRAY($j,add_allowed_list)   $add_allowed_list
			db_close $res

		}


		tpBindVar ch_id             PERM_ARRAY ch_id              ch_idx
		tpBindVar ch_desc           PERM_ARRAY ch_desc            ch_idx
		tpBindVar add_allowed_list  PERM_ARRAY add_allowed_list   ch_idx

		tpBindVar chan_allowed_list PERM_ARRAY chan_allowed_list
		tpBindVar sys_allowed_list  PERM_ARRAY sys_allowed_list

		tpBindVar app_id            PERM_ARRAY app_id             c_idx
		tpBindVar app_desc          PERM_ARRAY app_desc           c_idx

		tpBindVar lot_allowed_list  PERM_ARRAY lot_allowed_list   c_idx
		tpBindVar cat_allowed_list  PERM_ARRAY cat_allowed_list   c_idx
		tpBindVar allowed_list      PERM_ARRAY allowed_list       c_idx

		db_close $app_res
	}

	set ext_sql {
		select
			s.sub_type_code,
			s.desc,
			NVL(c.country_code, 0) as selected
		from
			tExtPayMthd     p,
			tExtSubPayMthd  s,
		outer
			tExtPayCountry c
		where
			p.pay_mthd          =   ?                  and
			p.ext_pay_mthd_id   =   s.ext_pay_mthd_id  and
			s.sub_type_code     =   c.sub_type_code    and
			c.country_code      =   ?
	}

	set ccy_sql {
		select
			c.ccy_code,
			c.ccy_name,
			NVL(br.route, '----') as route
		from
			tCCY c,
			outer tPayMthdBank br
		where
			c.ccy_code = br.ccy_code and
			br.country_code = ?
	}


	if {[OT_CfgGet FUNC_MONEYBOOKERS_BY_COUNTRY 0]} {

		set stmt  [inf_prep_sql $DB $ext_sql]
		set res   [inf_exec_stmt $stmt MB $country_code]
		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set MB_ALLOWED($i,type) [db_get_col $res $i sub_type_code]
			set MB_ALLOWED($i,desc) [db_get_col $res $i desc]
			if {[db_get_col $res $i selected] != 0} {
				set MB_ALLOWED($i,checked) "checked"
			}
		}

		tpSetVar  num_mb_types $nrows
		tpBindVar mb_type    MB_ALLOWED type    mb_all_idx
		tpBindVar mb_desc    MB_ALLOWED desc    mb_all_idx
		tpBindVar mb_checked MB_ALLOWED checked mb_all_idx

		inf_close_stmt $stmt
		db_close $res
	}

	if {[OT_CfgGet FUNC_ENVOY 0]} {

		set stmt  [inf_prep_sql $DB $ext_sql]
		set res   [inf_exec_stmt $stmt ENVO $country_code]
		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set ENVO_ALLOWED($i,type) [db_get_col $res $i sub_type_code]
			set ENVO_ALLOWED($i,desc) [db_get_col $res $i desc]
			if {[db_get_col $res $i selected] != 0} {
				set ENVO_ALLOWED($i,checked) "checked"
			}
		}

		tpSetVar  num_envo_types $nrows
		tpBindVar envo_type    ENVO_ALLOWED type    envo_all_idx
		tpBindVar envo_desc    ENVO_ALLOWED desc    envo_all_idx
		tpBindVar envo_checked ENVO_ALLOWED checked envo_all_idx

		inf_close_stmt $stmt
		db_close $res
	}

	if {[OT_CfgGet FUNC_ENVOY_WTD 0]} {

		set stmt  [inf_prep_sql $DB $ccy_sql]
		set res   [inf_exec_stmt $stmt $country_code]
		set nrows [db_get_nrows $res]

		for {set i 0} {$i < $nrows} {incr i} {
			set ENVO_WTD_ROUTE($i,ccy_code) [db_get_col $res $i ccy_code]
			set ENVO_WTD_ROUTE($i,ccy_name) [db_get_col $res $i ccy_name]
			set ENVO_WTD_ROUTE($i,route) [db_get_col $res $i route]
		}

		tpSetVar  num_ccy $nrows
		tpBindVar ccy_code    ENVO_WTD_ROUTE ccy_code  envo_wtd_idx
		tpBindVar ccy_name    ENVO_WTD_ROUTE ccy_name  envo_wtd_idx
		tpBindVar route       ENVO_WTD_ROUTE route     envo_wtd_idx

		inf_close_stmt $stmt
		db_close $res
	}

	asPlayFile -nocache country.html
}


#
# ----------------------------------------------------------------------------
# Do currency insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_country args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_country_list
		return
	}

	if {$act == "CntryAdd"} {
		do_country_add
	} elseif {$act == "CntryMod"} {
		do_country_upd
	} elseif {$act == "CntryDel"} {
		do_country_del
	} elseif {$act == "GoCountry"} {
		go_country
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_country_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsCountry(
			p_adminuser = ?,
			p_country_code = ?,
			p_country_code_3d = ?,
			p_country_name = ?,
			p_status = ?,
			p_disporder = ?,
			p_intl_phone_code = ?,
			p_ccy_code = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CountryCode]\
			[reqGetArg CountryCode3D]\
			[reqGetArg CountryName]\
			[reqGetArg CountryStatus]\
			[reqGetArg CountryDisporder]\
			[reqGetArg IntlPhoneCode]\
			[reqGetArg CcyCode]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}

		# do this so the 'go_country' function doesn't think
		# that this is an existing country and try to load
		# it from db
		reqSetArg CountryCode ""
	}

	do_country_upd_perms
	do_country_update_ext
	do_country_upd_bank_mthd

	go_country
}

proc do_country_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdCountry(
			p_adminuser = ?,
			p_country_code = ?,
			p_country_code_3d = ?,
			p_country_name = ?,
			p_status = ?,
			p_disporder = ?,
			p_intl_phone_code = ?,
			p_ccy_code = ?,
            p_country_stk_scale = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CountryCode]\
			[reqGetArg CountryCode3D]\
			[reqGetArg CountryName]\
			[reqGetArg CountryStatus]\
			[reqGetArg CountryDisporder]\
			[reqGetArg IntlPhoneCode]\
			[reqGetArg CcyCode]\
            [reqGetArg CountryStkScale]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	do_country_upd_perms
	do_country_update_ext
	do_country_upd_bank_mthd

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_country
		return
	}
	go_country_list

}

proc do_country_upd_perms args {

	global DB
	if {[OT_CfgGet FUNC_COUNTRY_PERM_MATRIX 0]} {

		set sql {
			select
				app_id
			from
				tAuthServerApp
		}

		set stmt [inf_prep_sql $DB $sql]
		set app_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		global PERM_ARRAY

		set num_apps [db_get_nrows $app_res]

		for {set j 0} {$j < $num_apps} {incr j} {

			set app_id [db_get_col $app_res $j app_id]

			set allowed_list [string trim [reqGetArg ${app_id}_allowed_list]]
			set cat_allowed_list [string trim [reqGetArg ${app_id}_cat_allowed_list]]
			set lot_allowed_list [string trim [reqGetArg ${app_id}_lot_allowed_list]]

			set new_banned_list [list]
			set new_allowed_list [list]
			set new_banned_cat_list [list]
			set new_allowed_cat_list [list]
			set new_banned_lot_list [list]
			set new_allowed_lot_list [list]

			set CNTRY_PERM_REGEXP     "^${app_id}_CNTRY_PERM_(.*)$"
			set CNTRY_CAT_PERM_REGEXP "^${app_id}_CNTRY_CAT_PERM_(.*)$"
			set CNTRY_LOT_PERM_REGEXP "^${app_id}_CNTRY_LOT_PERM_(.*)$"

			# see which operations, categories and lotteries are allowed
			# if they're not in the allowed list, then they'll need to be explicitly enabled
			for {set n 0} {$n < [reqGetNumVals]} {incr n} {
				if {[regexp -- $CNTRY_PERM_REGEXP [reqGetNthName $n] not_needed op_code] } {
					if {[lsearch -exact $allowed_list $op_code] == -1} {
						# assume there are no quotes in the code
						lappend new_allowed_list '$op_code'
					}
				}
				if {[regexp -- $CNTRY_CAT_PERM_REGEXP [reqGetNthName $n] not_needed cat_code] } {
					if {[lsearch -exact $cat_allowed_list $cat_code] == -1} {
						# assume there are no quotes in this code
						lappend new_allowed_cat_list '$cat_code'
					}
				}
				if {[regexp -- $CNTRY_LOT_PERM_REGEXP [reqGetNthName $n] not_needed lot_code] } {
					if {[lsearch -exact $lot_allowed_list $lot_code] == -1} {
						# no quotes around lottery, because the code might contain quotes
						# therefore, the list items are dealt with one by one
						lappend new_allowed_lot_list $lot_code
					}
				}
			}

			#now go thru allowed list and check that all the old permissable actions are still allowed
			foreach op_code $allowed_list {
				if {[reqGetArg ${app_id}_CNTRY_PERM_${op_code}] == ""} {
					lappend new_banned_list $op_code
				}
			}
			foreach cat_code $cat_allowed_list {
				if {[reqGetArg ${app_id}_CNTRY_CAT_PERM_${cat_code}] == ""} {
					lappend new_banned_cat_list $cat_code
				}
			}
			foreach lot_code $lot_allowed_list {
				if {[reqGetArg ${app_id}_CNTRY_LOT_PERM_${lot_code}] == ""} {
					lappend new_banned_lot_list $lot_code
				}
			}

			if {[llength $new_allowed_list] != 0} {
				set new_allowed_list [join $new_allowed_list ,]
				set sql [subst {
					delete from
						tCntryBanOp
					where
						country_code = '[reqGetArg CountryCode]'
						and op_code in ($new_allowed_list)
						and app_id = $app_id
				}]
				set stmt [inf_prep_sql $DB $sql]
				inf_exec_stmt $stmt
				inf_close_stmt $stmt
			}

			if {[llength $new_banned_list] != 0} {
				set sql [subst {
					insert into
						tCntryBanOp (op_code,country_code,app_id)
					values (
						?,
						'[reqGetArg CountryCode]',
						?
					)
				}]
				set stmt [inf_prep_sql $DB $sql]
				foreach op_code $new_banned_list {
					inf_exec_stmt $stmt $op_code $app_id
				}
				inf_close_stmt $stmt
			}

			if {[llength $new_allowed_cat_list] != 0} {
				set new_allowed_cat_list [join $new_allowed_cat_list ,]
				set sql [subst {
					delete from
						tCntryBanCat
					where
						country_code = '[reqGetArg CountryCode]'
						and category in ($new_allowed_cat_list)
						and app_id = $app_id
				}]
				set stmt [inf_prep_sql $DB $sql]
				inf_exec_stmt $stmt
				inf_close_stmt $stmt
			}

			if {[llength $new_banned_cat_list] != 0} {
				set sql [subst {
					insert into
						tCntryBanCat (category,country_code, app_id)
					values (
						?,
						'[reqGetArg CountryCode]',
						?
					)
				}]
				set stmt [inf_prep_sql $DB $sql]
				foreach cat_code $new_banned_cat_list {
					inf_exec_stmt $stmt $cat_code $app_id
				}
				inf_close_stmt $stmt
			}

			# new lotteries have been allowed - remove them from the banned list
			if {[llength $new_allowed_lot_list] != 0} {
				set sql [subst {
					delete from
						tCntryBanLot
					where
						country_code = '[reqGetArg CountryCode]'
						and sort = ?
						and app_id = ?
				}]
				set stmt [inf_prep_sql $DB $sql]
				# lottery might have a quote in the code name, so needs to be dealt with one by one.
				foreach lot_code $new_allowed_lot_list {
					inf_exec_stmt $stmt $lot_code $app_id
				}
				inf_close_stmt $stmt
			}

			# new lotteries have been banned - add them to the banned list
			if {[llength $new_banned_lot_list] != 0} {
				set sql [subst {
					insert into
						tCntryBanLot (sort,country_code, app_id)
					values (
						?,
						'[reqGetArg CountryCode]',
						?
					)
				}]
				set stmt [inf_prep_sql $DB $sql]
				foreach lot_code $new_banned_lot_list {
					inf_exec_stmt $stmt $lot_code $app_id
				}
				inf_close_stmt $stmt
			}
		}
		db_close $app_res

		set chan_allowed_list [string trim [reqGetArg chan_allowed_list]]
		set sys_allowed_list  [string trim [reqGetArg sys_allowed_list]]

		set new_banned_chan_list  [list]
		set new_allowed_chan_list [list]
		set new_banned_sys_list   [list]
		set new_allowed_sys_list  [list]

		set CNTRY_CHAN_PERM_REGEXP "^CNTRY_CHAN_PERM_(.*)$"
		set CNTRY_SYS_PERM_REGEXP  "^CNTRY_SYS_PERM_(.*)$"

		# see which channels and systems are allowed - if they're not in the allowed list, then
		# they'll need to be explicitly enabled
		for {set n 0} {$n < [reqGetNumVals]} {incr n} {
			if {[regexp -- $CNTRY_CHAN_PERM_REGEXP [reqGetNthName $n] not_needed chan_code] } {
				if {[lsearch -exact $chan_allowed_list $chan_code] == -1} {
					# assume channel does not contain quotes
					lappend new_allowed_chan_list '$chan_code'
				}
			}
			if {[regexp -- $CNTRY_SYS_PERM_REGEXP [reqGetNthName $n] not_needed sys_code] } {
				if {[lsearch -exact $sys_allowed_list $sys_code] == -1} {
					# assume system does not contain quotes
					lappend new_allowed_sys_list '$sys_code'
				}
			}
		}

		foreach chan_code $chan_allowed_list {
			if {[reqGetArg CNTRY_CHAN_PERM_${chan_code}] == ""} {
				lappend new_banned_chan_list $chan_code
			}
		}

		foreach sys_code $sys_allowed_list {
			if {[reqGetArg CNTRY_SYS_PERM_${sys_code}] == ""} {
				lappend new_banned_sys_list $sys_code
			}
		}

		# new channels have been allowed - remove them from the banned list
		if {[llength $new_allowed_chan_list] != 0} {
			set new_allowed_chan_list [join $new_allowed_chan_list ,]
			set sql [subst {
				delete from
					tCntryBanChan
				where
					country_code = '[reqGetArg CountryCode]'
					and channel_id in ($new_allowed_chan_list)
			}]
			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt
			inf_close_stmt $stmt
		}

		# new channels have been banned - add them to the banned list
		if {[llength $new_banned_chan_list] != 0} {
			set sql [subst {
				insert into
					tCntryBanChan (channel_id,country_code)
				values (
					?,
					'[reqGetArg CountryCode]'
				)
			}]
			set stmt [inf_prep_sql $DB $sql]
			foreach chan_code $new_banned_chan_list {
				inf_exec_stmt $stmt $chan_code
			}
			inf_close_stmt $stmt
		}

		# new systems have been allowed - remove them from the banned list
		if {[llength $new_allowed_sys_list] != 0} {
			set new_allowed_sys_list [join $new_allowed_sys_list ,]
			set sql [subst {
				delete from
					tCntryBanSys
				where
					country_code = '[reqGetArg CountryCode]'
					and group_id in ($new_allowed_sys_list)
			}]
			set stmt [inf_prep_sql $DB $sql]
			inf_exec_stmt $stmt
			inf_close_stmt $stmt
		}

		# new systems have been banned - add them to the banned list
		if {[llength $new_banned_sys_list] != 0} {
			set sql [subst {
				insert into
					tCntryBanSys (group_id,country_code)
				values (
					?,
					'[reqGetArg CountryCode]'
				)
			}]
			set stmt [inf_prep_sql $DB $sql]
			foreach sys_code $new_banned_sys_list {
				inf_exec_stmt $stmt $sys_code
			}
			inf_close_stmt $stmt
		}

		set sql {
			select unique
				channel_id
			from
				tCntryBanAdditionalDesc ad
		}

		set stmt [inf_prep_sql $DB $sql]
		set ch_res [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_chs [db_get_nrows $ch_res]

		# for every channel that the item is available in
		for {set j 0} {$j < $num_chs} {incr j} {

			set ch_id [db_get_col $ch_res $j channel_id]
			set add_allowed_list [string trim [reqGetArg ${ch_id}_add_allowed_list]]
			set new_banned_add_list  [list]
			set new_allowed_add_list [list]

			set CNTRY_ADD_PERM_REGEXP "^${ch_id}_CNTRY_ADD_PERM_(.*)$"

			# get the newly set allowed items
			for {set n 0} {$n < [reqGetNumVals]} {incr n} {
				if {[regexp -- $CNTRY_ADD_PERM_REGEXP [reqGetNthName $n] not_needed add_code] } {
					if {[lsearch -exact $add_allowed_list $add_code] == -1} {
						lappend new_allowed_add_list '$add_code'
					}
				}
			}

			# get the newly set banned items
			foreach add_code $add_allowed_list {
				if {[reqGetArg ${ch_id}_CNTRY_ADD_PERM_${add_code}] == "" && \
				[reqGetArg ${ch_id}_CNTRY_ADD_VALID_PERM_${add_code}] == 1} {
					lappend new_banned_add_list $add_code
				}
			}

			# new items have been allowed - remove them from the banned list
			if {[llength $new_allowed_add_list] != 0} {
				set new_allowed_add_list [join $new_allowed_add_list ,]
				set sql [subst {
					delete from
						tCntryBanAdd
					where
						country_code = '[reqGetArg CountryCode]'
						and name in ($new_allowed_add_list)
						and channel_id = '$ch_id'
				}]
				set stmt [inf_prep_sql $DB $sql]
				inf_exec_stmt $stmt
				inf_close_stmt $stmt
			}

			# new items have been banned - add them from the banned list
			if {[llength $new_banned_add_list] != 0} {
				set sql [subst {
					insert into
						tCntryBanAdd (name,country_code, channel_id)
					values (
						?,
						'[reqGetArg CountryCode]',
						?
					)
				}]
				set stmt [inf_prep_sql $DB $sql]
				foreach add_code $new_banned_add_list {
					inf_exec_stmt $stmt $add_code $ch_id
				}
				inf_close_stmt $stmt
			}
		}
	}
}

proc do_country_update_ext args {

	global DB

	set is_mb_by_country    [OT_CfgGet FUNC_MONEYBOOKERS_BY_COUNTRY 0]
	set is_envoy_by_country [OT_CfgGet FUNC_ENVOY_BY_COUNTRY 0]

	if {!$is_mb_by_country && !$is_envoy_by_country} {
		go_country_list
		return
	}

	set country_code [reqGetArg CountryCode]

	# get existing settings
	set sql {
		select
			sub_type_code
		from
			tExtPayCountry
		where
			country_code = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set res  [inf_exec_stmt $stmt $country_code]
	inf_close_stmt $stmt

	set D [list]

	set n [db_get_nrows $res]
	for {set i 0} {$i < $n} {incr i} {
		lappend D [db_get_col $res $i sub_type_code]
	}

	set STMT(I) [list]
	set STMT(D) [list]

	set ext_countries_checked   [reqGetArgs mb_countries_checked]
	set ext_countries_checked   "$ext_countries_checked [reqGetArgs envo_countries_checked]"

	# which ones need inserting?
	foreach type $ext_countries_checked {
		if {[lsearch $D $type] == -1} {
			lappend STMT(I) $type
		}
	}

	# which ones need deleting?
	foreach type2 $D {
		if {[lsearch $ext_countries_checked $type2] == -1} {
			lappend STMT(D) $type2
		}
	}

	set sql_i [subst {
		insert into tExtPayCountry (
			sub_type_code,
			country_code
		) values (
			?,
			?
		)
	}]

	set sql_d [subst {
		delete from
			tExtPayCountry
		where
			sub_type_code = ? and
			country_code  = ?
	}]

	if [llength $STMT(I)] { set stmt_i [inf_prep_sql $DB $sql_i] }
	if [llength $STMT(D)] { set stmt_d [inf_prep_sql $DB $sql_d] }

	if {[catch {
		foreach ty $STMT(I) {
			inf_exec_stmt $stmt_i $ty $country_code
		}
		foreach ty $STMT(D) {
			inf_exec_stmt $stmt_d $ty $country_code
		}
	} msg]} {
		OT_LogWrite 1 "Couldn't update country permissions for External Sub Type '$type' : $msg"
		err_bind      "Couldn't update country permissions for External Sub Type '$type' : $msg"
	}

	if {[info exists stmt_i]} { inf_close_stmt $stmt_i }
	if {[info exists stmt_d]} { inf_close_stmt $stmt_d }

}

proc do_country_upd_bank_mthd {} {

	global DB

	if {![OT_CfgGet FUNC_ENVOY_WTD 0]} {
		return
	}

	set country_code [reqGetArg CountryCode]

	# get existing settings
	set sql {
		select
			ccy_code,
			route
		from
			tPayMthdBank
		where
			country_code = ?
	}

	set stmt [inf_prep_sql  $DB $sql]
	set res  [inf_exec_stmt $stmt $country_code]
	inf_close_stmt $stmt

	set D       [list]
	set D_route [list]

	set n [db_get_nrows $res]
	for {set i 0} {$i < $n} {incr i} {
		lappend D       [db_get_col $res $i ccy_code]
		lappend D_route [db_get_col $res $i route]
	}

	set STMT(I) [list]
	set STMT(U) [list]
	set STMT(D) [list]

	set bank_routes   [reqGetArgs BankRoute]

	# what to do with these routes?
	foreach routes $bank_routes {
		set ccy   [lindex $routes 0]
		set route [lindex $routes 1]
		if {$route == "----"} {
			lappend STMT(D) $ccy $route
		} elseif {[lsearch $D $ccy] == -1} {
			lappend STMT(I) $ccy $route
		} else {
			if {[lindex $D_route [lsearch $D $ccy]] ne $route} {
				lappend STMT(U) $ccy $route
			}
		}
	}

	set sql_i [subst {
		insert into tPayMthdBank (
			country_code,
			ccy_code,
			route
		) values (
			?,
			?,
			?
		)
	}]

	set sql_u [subst {
		update
			tPayMthdBank
		set 
			route = ?
		where
			country_code = ? and
			ccy_code = ?
	}]

	set sql_d [subst {
		delete from
			tPayMthdBank
		where
			country_code = ? and
			ccy_code = ?
	}]

	if [llength $STMT(I)] { set stmt_i [inf_prep_sql $DB $sql_i] }
	if [llength $STMT(U)] { set stmt_u [inf_prep_sql $DB $sql_u] }
	if [llength $STMT(D)] { set stmt_d [inf_prep_sql $DB $sql_d] }

	if {[catch {
		foreach {ccy route} $STMT(I) {
			inf_exec_stmt $stmt_i $country_code $ccy $route
		}
		foreach {ccy route} $STMT(U) {
			inf_exec_stmt $stmt_u $route $country_code $ccy
		}
		foreach {ccy route} $STMT(D) {
			inf_exec_stmt $stmt_d $country_code $ccy
		}
	} msg]} {
		OT_LogWrite 1 "Couldn't update country permissions for currency '$ty' : $msg"
		err_bind      "Couldn't update country permissions for currency '$ty' : $msg"
	}

	if {[info exists stmt_i]} { inf_close_stmt $stmt_i }
	if {[info exists stmt_d]} { inf_close_stmt $stmt_d }

}

proc do_country_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelCountry(
			p_adminuser = ?,
			p_country_code = ?,
			p_func_ext_type = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set delete_mb_type [expr {[OT_CfgGet FUNC_MONEYBOOKERS_BY_COUNTRY 0] ? "Y" : "N"}]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CountryCode]\
			$delete_mb_type]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_country
		return
	}

	go_country_list
}

#
# Displays table showing country permissions
#
proc go_view_perm_matrix {} {

	global DB
	global THE_MATRIX

	set app_id [reqGetArg app_id]

	if {$app_id == ""} {
		set app_id 1
	}

	set sql {
		select
			c.country_code,
			c.country_name,
			c.disporder
		from
			tcountry c
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	set num_countries [db_get_nrows $res]
	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,country_code) [db_get_col $res $i country_code]
		set THE_MATRIX($i,country_name) [db_get_col $res $i country_name]
		set THE_MATRIX($THE_MATRIX($i,country_code),cc_num) $i
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	set sql {
		select
			d.op_code,
			d.desc,
			d.disporder
		from
			tCntryBanOpDesc d
		order by 3
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	set num_ops [db_get_nrows $res]
	for {set i 0} {$i < $num_ops} {incr i} {
		set THE_MATRIX($i,op_code) [db_get_col $res $i op_code]
		set THE_MATRIX($i,desc)   [db_get_col $res $i desc]
		set THE_MATRIX($THE_MATRIX($i,op_code),op_num) $i
	}
	catch {db_close $res}
	inf_close_stmt $stmt

	#set all permissions to allowed
	for {set i 0} {$i < $num_countries} {incr i} {
		for {set j 0} {$j < $num_ops} {incr j} {
			set THE_MATRIX($i,$j,perm) "tick"
		}
	}

	set sql {
		select
			b.op_code,
			b.country_code
		from
			tCntryBanOp b
		where
			b.app_id = ?

	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $app_id]

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),$THE_MATRIX([db_get_col $res $i op_code],op_num),perm) "cross"
	}
	catch {db_close $res}
	inf_close_stmt $stmt

	#set banned categories to "" for all countries
	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,banned_cats) {}
	}

	set sql {
		select
			country_code,
			category
		from
			tCntryBanCat
		where
			app_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $app_id]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		#lappend THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_cats) [db_get_col $res $i category]
		set comma {}
		if {$THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_cats) != ""} {set comma ", "}
		append THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_cats) "$comma[db_get_col $res $i category]"
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	#
	# set banned lotteries
	#

	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,banned_lots) {}
	}

	set sql {
		select
			g.name,
			g.sort,
			l.country_code
		from
			tXGameDef g,
			tCntryBanLot l
		where
			l.sort = g.sort
			and l.app_id = ?
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $app_id]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set comma {}
		if {$THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_lots) != ""} {set comma ", "}
		append THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_lots) "$comma[db_get_col $res $i name]"
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	#
	# set banned channels
	#

	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,banned_chans) {}
	}

	set sql {
		select
			c.desc,
			c.channel_id,
			l.country_code
		from
			tChannel c,
			tCntryBanChan l
		where
			l.channel_id = c.channel_id
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set comma {}
		if {$THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_chans) != ""} {set comma ", "}
		append THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_chans) "$comma[db_get_col $res $i desc]"
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	#
	# set banned systems (displayed in OXi only)
	#

	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,banned_sys) {}
	}

	set sql {
			select
				c.desc,
				c.group_id,
				l.country_code
			from
				tXSysHostGrp c,
				tCntryBanSys l
			where
				l.group_id = c.group_id
	}
	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		set comma {}
		if {$THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_sys) != ""} {set comma ", "}
		append THE_MATRIX($THE_MATRIX([db_get_col $res $i country_code],cc_num),banned_sys) "$comma[db_get_col $res $i desc]"
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	#
	# set additional banned items (displayed in default app only)
	#

	for {set i 0} {$i < $num_countries} {incr i} {
		set THE_MATRIX($i,banned_adds) {}
	}

	set sql {
		select unique
			a.channel_id,
			c.desc
		from
			tCntryBanAdd a,
			tChannel c
		where
			c.channel_id = a.channel_id
	}
	set stmt [inf_prep_sql $DB $sql]
	set ch_res  [inf_exec_stmt $stmt]

	array set temp_array {}

	for {set ind 0} {$ind < [db_get_nrows $ch_res]} {incr ind} {

		for {set i 0} {$i < $num_countries} {incr i} {
			set temp_array($i,[db_get_col $ch_res $ind channel_id]) {}
		}

		set sql {
			select unique
				a.country_code,
				a.name
			from
				tCntryBanAdd a
			where
				a.channel_id = ?
		}
		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt [db_get_col $ch_res $ind channel_id]]
		for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
			set comma {}
			if {$temp_array($THE_MATRIX([db_get_col $res $i country_code],cc_num),[db_get_col $ch_res $ind channel_id]) != ""} {
				set comma ", "
			} else {
				set comma " \n[db_get_col $ch_res $ind desc]: "
			}
			append temp_array($THE_MATRIX([db_get_col $res $i country_code],cc_num),[db_get_col $ch_res $ind channel_id]) "$comma[db_get_col $res $i name]"
		}
	}

	for {set i 0} {$i < $num_countries} {incr i} {

		for {set ind 0} {$ind < [db_get_nrows $ch_res]} {incr ind} {

			append THE_MATRIX($i,banned_adds) $temp_array($i,[db_get_col $ch_res $ind channel_id])

		}
	}


	catch {db_close $ch_res}
	catch {db_close $res}
	inf_close_stmt $stmt


	tpBindVar country_name THE_MATRIX country_name country_idx
	tpBindVar country_code THE_MATRIX country_code country_idx

	tpBindVar banned_adds  THE_MATRIX banned_adds  country_idx
	tpBindVar banned_sys   THE_MATRIX banned_sys   country_idx
	tpBindVar banned_chans THE_MATRIX banned_chans country_idx
	tpBindVar banned_cats  THE_MATRIX banned_cats  country_idx
	tpBindVar banned_lots  THE_MATRIX banned_lots  country_idx

	tpBindVar op_code      THE_MATRIX op_code      op_idx
	tpBindVar op_desc      THE_MATRIX desc         op_idx
	tpBindVar perm         THE_MATRIX perm         country_idx op_idx

	tpSetVar num_countries $num_countries
	tpSetVar num_ops       $num_ops

	tpSetVar app_id        $app_id

	asPlayFile -nocache country_matrix.html
}

}
