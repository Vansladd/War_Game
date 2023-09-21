# ==============================================================
# $Id: tb_register.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

#
# WARNING: this file is initialised immediately after the source
#

# built upon register.tcl in shared_tcl version 1.33 modified
# for telebetting server

if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {
	package require fbets_fbets
	ob_fbets::init
}

namespace eval tb_register {

namespace export init_tb_reg

#
# do the registration
#
namespace export tb_do_registration
namespace export tb_do_update_details
namespace export tb_get_customer_details
namespace export tb_reg_gen_acct_no
namespace export get_pref
namespace export set_pref
namespace export tb_upd_acct_pin
namespace export tb_insert_cust_index
namespace export tb_update_cust_index

#
# errors
#
namespace export tb_reg_err_get
namespace export tb_reg_err_num


variable CUSTDETAIL
variable TB_REG_ERR

# have the queries been initialised?
variable INITIALISED
set INITIALISED 0


variable BAD_PWDS
set BAD_PWDS {SECRET PASSWORD GAMBLE WAGER PUNTER BOOKIE BOOKMAKER ARSE}

variable    BAD_PINS
set         BAD_PINS {000000 0000000 00000000 /
					  111111 1111111 11111111 /
					  222222 2222222 22222222 /
					  333333 3333333 33333333 /
					  444444 4444444 44444444 /
					  555555 5555555 55555555 /
					  666666 6666666 66666666 /
					  777777 7777777 77777777 /
					  888888 8888888 88888888 /
					  999999 9999999 99999999 /
					  012345 0123456 01234567 /
					  123456 1234567 12345678
}

variable FIELD_DESCRIPTIONS
set FIELD_DESCRIPTIONS {"challenge_1"        "first challenge question"
						"response_1"         "answer to the first challenge"
						"addr_street_2"      "second line of your address"
						"addr_city"          "town / city of your address"
						"telephone"          "telephone number"
						"addr_postcode"      "postcode of your address"
						"email"              "email"
						"title"              "title"
						"fname"              "first name"
						"lname"              "last name"
						"mname"              "middle name"
						"addr_street_1"      "first line of your address"
						"dob_day"            "day in the date of birth"
						"dob_month"          "month in the date of birth"
						"dob_year"           "year in the date of birth"
						"salutation"         "salutation"
						"gender"             "gender"
						"mobile"             "mobile number"
						"aff_id"             "affiliate details"
						"acct_no"            "account number"
						"pin"                "pin number"
						"lang_code"          "language code"
						"country_code"       "country code"
						"challenge_2"        "second challenge question"
						"response_2"         "answer to the second challenge"
						"sig_date"           "significant date"
						"addr_street_2"      "second line of your address"
						"addr_street_3"      "third line of your address"
						"addr_street_4"      "fourth line of your address"
						"addr_city"          "city"
						"addr_country"       "country"
						"addr_state_id"      "state id"
						"itv_email"          "itv email"
						"contact_ok"         "ok to contact"
						"contact_how"        "how to contact"
						"mkt_contact_ok"     "ok to contact mkt"
						"ptnr_contact_ok"    "ok to contact partner"
						"dob"                "date of birth"
						"office"             "office telephone number"
						"fax"                "fax number"
						"price_type"         "pricing type"
						"cust_sort"          "customer sort"
						"occupation"         "occupation"
						"code"               "code"
						"code_txt"           "code text"
						"min_repay"          "minimum repayment"
						"min_settle"         "payment request"
						"min_funds"          "minimum funds"
						"pay_pct"            "payment percentage"
						"credit_limit"       "credit limit"
						"cd_grp_id"          "cleardown group"
						"fbteam"             "fb team"
						"elite"              "elite"
						"tax_on"             "tax on stake"
						"ap_on"              "ap on"
						"hear_about"         "intro source"
						"hear_about_txt"     "intro source text"
						"partnership"        "partnership"
						"settle_type"        "settle type"
						"stmt_available"     "statements enabled"
						"stmt_on"            "statements on"
						"freq_unit"          "statement frequency"
						"freq_amt"           "statement frequency amount"
						"dlv_method"         "statement delivery method"
						"due_from"           "statement due from"
						"due_to"             "statement due to"
						"status"             "status"
						"ignore_mand"        "ignore mand"
						"brief"              "brief statements"
						"username"           "username"
						"password"           "password"
						"password2"          "password 2"
						"pin2"               "pin 2"
						"currency_code"      "currency"
						"csc"                "card security code"
						"over_18"            "over 18"
						"read_rules"         "read rules"
						"acct_owner"         "account owner"
						"reg_combi"          "reg combi"
						"ref_cust_id"        "ref customer id"
						"card_no"            "card number"
						"expiry"             "expiry"
						"gen_acct_no_on_reg" "generate account number upon registration"
						"start"              "card start date"
						"issue_no"           "card issue number"
}


########################
proc init_tb_reg args {
########################

	variable INITIALISED

	if {$INITIALISED} {
		return
	}

	prep_reg_qrys

	set INITIALISED 1
}


#########################
proc prep_reg_qrys args {
#########################

	global SHARED_SQL

	tb_reg_err_reset

	set SHARED_SQL(tb_reg_insert_cust) {
		execute procedure pInsCustomer (
						p_source=?,
						p_aff_id=?,
						p_acct_no=?,
						p_bib_pin=?,
						p_username=?,
						p_password=?,
						p_password_salt=?,
						p_lang=?,
						p_ccy_code=?,
						p_country_code=?,
						p_acct_type=?,
						p_ipaddr=?,
						p_challenge_1=?,
						p_response_1=?,
						p_challenge_2=?,
						p_response_2=?,
						p_sig_date=?,
						p_title=?,
						p_fname=?,
						p_mname=?,
						p_lname=?,
						p_dob=?,
						p_addr_street_1=?,
						p_addr_street_2=?,
						p_addr_street_3=?,
						p_addr_street_4=?,
						p_addr_city=?,
						p_addr_country=?,
						p_addr_state_id=?,
						p_postcode=?,
						p_telephone=?,
						p_mobile=?,
						p_office=?,
						p_fax=?,
						p_email=?,
						p_contact_ok=?,
						p_contact_how=?,
						p_mkt_contact_ok=?,
						p_ptnr_contact_ok=?,
						p_hear_about=?,
						p_hear_about_txt=?,
						p_gender = ?,
						p_itv_email=?,
						p_temp_pwd=?,
						p_sort=?,
						p_reg_combi=?,
						p_salutation=?,
						p_occupation=?,
						p_code=?,
						p_code_txt=?,
						p_elite=?,
						p_min_repay=?,
						p_min_funds=?,
						p_min_settle=?,
						p_credit_limit=?,
						p_pay_pct=?,
						p_settle_type=?,
						p_transactional=?,
						p_fave_fb_team=?,
						p_partnership=?,
						p_cd_grp_id=?,
						p_acct_owner=?,
						p_owner_type=?,
						p_aff_asset_id=?,
						p_text_betting=?,
						p_shop_id=?,
						p_staff_member=?,
						p_acct_no_format = ?,
						p_rep_code=?,
						p_rep_code_status=?
		)
	}

	set SHARED_SQL(tb_reg_cust_detail) {

		select
			c.acct_no,
			c.elite,
			c.lang as lang_code,
			c.country_code,
			c.sort as cust_sort,
			c.sig_date,
			c.username,
			c.aff_id,
			c.aff_asset_id,
			c.source,
			r.challenge_1,
			r.response_1,
			r.challenge_2,
			r.response_2,
			r.title,
			r.fname,
			r.mname,
			r.lname,
			r.gender,
			r.dob,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_state_id,
			r.addr_country,
			r.addr_postcode,
			r.telephone,
			r.mobile,
			r.office,
			r.email,
			r.itv_email,
			r.fax,
			r.contact_ok,
			r.contact_how,
			r.mkt_contact_ok,
			r.ptnr_contact_ok,
			r.hear_about,
			r.hear_about_txt,
			r.salutation,
			r.occupation,
			r.code,
			r.code_txt,
			r.partnership,
			a.acct_type,
			a.cr_date,
			a.ccy_code as currency_code,
			a.acct_id,
			a.settle_type as settle_type,
			a.min_funds,
			a.min_repay,
			a.min_settle,
			a.credit_limit,
			a.pay_pct,
			a.owner as acct_owner,
			l.charset,
			f.flag_value as fbteam,
			a.cd_grp_id,
			r.staff_member,
			rs.shop_no,
			ocr.rep_code,
			ocr.status as rep_code_status
		from
			tcustomer c,
			tcustomerreg r,
			tacct a,
			tlang l,
			outer tcustomerflag f,
			outer tRetailShop rs,
			outer tOnCourseRep ocr
		where
			c.cust_id = ? and
			c.cust_id = r.cust_id and
			c.cust_id = a.cust_id and
			c.lang    = l.lang and
			c.cust_id = f.cust_id and
			f.flag_name = 'FootBall Team' and
			rs.shop_id = r.shop_id and
			a.acct_id = ocr.acct_id
	}



	# Query to update customer
	set SHARED_SQL(tb_reg_upd_cust_reg) {
		execute procedure pTbUpdCustomer (
						p_cust_id=?,
						p_challenge_1=?,
						p_response_1=?,
						p_challenge_2=?,
						p_response_2=?,
						p_title=?,
						p_fname=?,
						p_mname=?,
						p_lname=?,
						p_dob=?,
						p_addr_street_1=?,
						p_addr_street_2=?,
						p_addr_street_3=?,
						p_addr_street_4=?,
						p_addr_city=?,
						p_addr_country=?,
						p_addr_state_id=?,
						p_postcode=?,
						p_telephone=?,
						p_mobile=?,
						p_office=?,
						p_fax=?,
						p_email=?,
						p_contact_ok=?,
						p_contact_how=?,
						p_mkt_contact_ok=?,
						p_ptnr_contact_ok=?,
						p_hear_about=?,
						p_hear_about_txt=?,
						p_gender = ?,
						p_itv_email=?,
						p_salutation=?,
						p_occupation=?,
						p_code=?,
						p_code_txt=?,
						p_fave_fb_team=?,
						p_partnership=?,
						p_text_betting=?,
						p_rep_code=?,
						p_rep_code_status=?
		)
	}

	# Query to update customer flags
	set SHARED_SQL(tb_reg_upd_cust_flag) {
		execute procedure pUpdCustFlag (
			p_cust_id=?,
			p_flag_name=?,
			p_flag_value=?
		)
	}


	#
	# update tcustomer table
	#
	set SHARED_SQL(tb_reg_upd_cust) {
		update
			tCustomer
		set
			elite=?,
			lang=?,
			country_code=?,
			sort=?,
			sig_date=?,
			aff_id =?
		where
			cust_id = ?
	}

	#
	# update tacct table
	#
	set SHARED_SQL(tb_reg_upd_acct) {
		update
			tAcct
		set
			min_repay=?,
			min_funds=?,
			min_settle=?,
			pay_pct=?,
			settle_type=?,
			credit_limit=?,
			cd_grp_id=?
		where
			acct_id = ?
	}


	#
	# Account number generation
	#
	set SHARED_SQL(tb_reg_gen_acct_no) {
		execute procedure pTbGenAcctNo (
			p_cust_type = ?,
			p_prefix = ?
		)
	}

	#
	#
	#
	set SHARED_SQL(upd_bib_pin_tb) {
		update
			tcustomer
		set
			bib_pin = ?,
			temporary_pin = 'Y'
		where
			cust_id=?
	}



	#
	# Customer preferences (this may be removed)
	#
	set SHARED_SQL(pref_insert) {
		insert into tCustomerPref
		(pref_cvalue, pref_name, cust_id)
		values
		(?, ?, ?)
	}

	set SHARED_SQL(pref_update) {
		update
			tCustomerPref
		set
			pref_cvalue = ?
		where
			pref_name = ? and
			cust_id = ?
	}

	set SHARED_SQL(get_cust_pref) {
		select
			pref_cvalue
		from
			tcustomerpref
		where
			cust_id=? and
			pref_name =?

	}

	set SHARED_SQL(tb_reg_acct_id) {
		select
			acct_id
		from
			tAcct
		where
			cust_id = ? and
			owner   in ('C','Y','F','G')
	}

	set SHARED_SQL(ins_cust_index) {
		insert into
			tCustIndexedId
		values
			(?, ?, ?)
	}

	set SHARED_SQL(upd_cust_index) {
		update
			tCustIndexedId
		set
			identifier = ?
		where
			type = ? and
			cust_id = ?
	}

	set SHARED_SQL(chk_cust_index) {
		select
			first 1 identifier
		from
			tCustIndexedId
		where
			type = ? and
			cust_id = ?
	}

	set SHARED_SQL(del_cust_index) {
		delete from
			tCustIndexedId
		where
			type = ? and
			cust_id = ?
	}

	set SHARED_SQL(upd_open_t_c) {
		update
			tCustomer
		set
			open_t_c = 'Y'
		where
			cust_id = ?
	}

	# query to get cust_id given username

	set SHARED_SQL(chk_cust_id_username) {
		select
			cust_id
		from
			tcustomer
		where
			username = ?
	}

	set SHARED_SQL(chk_cust_id_acct_no) {
		select
			cust_id
		from
			tcustomer
		where
			acct_no = ?
	}

	set SHARED_SQL(get_external_groups) {
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
	}

	set SHARED_SQL(upd_ext_cust) {
		execute procedure pUpdExtCust(
			p_cust_id =?,
			p_ext_cust_id=?,
			p_code=?,
			p_master=?,
			p_permanent=?
		)
	}

	# Query to get the appropriate stralfors code for a cust_id
	set SHARED_SQL(get_stralfors_code_id) {
		select
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.business_cond
		from
			tStralforCode s,
			tCustomer c,
			tAcct a,
			tCustomerReg r
		where
			c.cust_id = ?
			and c.cust_id = a.cust_id
			and s.acct_type = a.acct_type
			and (?=0 or s.cust_sort = r.code)
			and (a.acct_type = 'CDT' or  s.age_verified = ?)
			and s.letter <> 'R'
			and r.cust_id = c.cust_id
	}

	set SHARED_SQL(get_cust_stralfors) {
		select
			s.stralfor_id,
			s.print_code,
			s.account_type,
			s.letter,
			s.tel_no,
			s.bus_cond
		from
			tCustStralfor s
		where
			cust_id = ?
	}

	set SHARED_SQL(insert_cust_stralfors) {
		insert into
			tCustStralfor
			(cust_id, print_code,account_type,letter,tel_no,bus_cond)
		values
			(?,?,?,?,?,?)
	}

	set SHARED_SQL(update_cust_stralfors) {
		update tCustStralfor
			set
				print_code = ?,
				account_type = ?,
				letter = ?,
				tel_no = ?,
				bus_cond = ?
			where
				stralfor_id = ?
	}

	set SHARED_SQL(set_exported) {
		update tCustStralfor
			set
				exported = ?
			where
				cust_id = ?
	}

	set SHARED_SQL(get_cust_group_id) {
		select
			r.code
		from
			tCustomerReg r
		where
			cust_id = ?
	}

	set SHARED_SQL(upd_cust_group_id) {
		update
			tCustomerReg
		set
			code = ?
		where
			cust_id = ?
	}

	set SHARED_SQL(get_flag_value) {
		select
			f.flag_value
		from
			tCustomerFlag f
		where
			f.cust_id = ?
			and f.flag_name = ?
	}

	set SHARED_SQL(get_ext_promo) {
		select
			g.desc
		from
			tXSysPromo     p,
			tXSysHostGrp   g,
			tXSysHostGrpLk l
		where
			p.xsys_promo_code = ?           and
			p.status          = 'A'         and
			p.system_id       = l.system_id and
			l.group_id        = g.group_id  and
			g.type            = 'SYS'
	}

	set SHARED_SQL(ins_netrefer_tag) {
		execute procedure pTagNetRefCust (
			p_cust_id        = ?,
			p_banner_tag     = ?
		)
	}

	set SHARED_SQL(get_email_restr) {
		select
			r.restriction,
			r.restr_type
		from
			tEmailRegRestrictions r
	}

	set SHARED_SQL(update_max_stake_scale) {
		update tCustomer
			set
				max_stake_scale = ?
			where
				cust_id = ?
	}

	set SHARED_SQL(getInternetCust) {
		select
			1
		from
			tCustomer
		where
			cust_id = ? and
			source  = "I"
	}

}


#
# Error handling
#
proc tb_reg_err_add args {
	variable TB_REG_ERR
	set err [join $args " "]
	lappend TB_REG_ERR $err
	ob::log::write ERROR {tb_register: $err}
}

proc tb_reg_err_get {} {
	variable TB_REG_ERR
	return $TB_REG_ERR
}

proc tb_reg_err_reset {} {
	variable TB_REG_ERR
	catch {unset TB_REG_ERR}
	set TB_REG_ERR {}
}

proc tb_reg_err_num {} {
	variable TB_REG_ERR
	return [llength $TB_REG_ERR]
}



#
# Grabs the default arguments for registration/update details
#
proc get_default_args {{register 1}} {

	global CHARSET
	global admin_screens
	variable CUSTDETAIL
	variable FIELD_DESCRIPTIONS

	set CUSTDETAIL(lang_code)           [reqGetArg lang_code]
	set CUSTDETAIL(country_code)        [encoding convertfrom $CHARSET [reqGetArg  country_code]]


	set CUSTDETAIL(challenge_1) [reqGetArg -unsafe challenge_1]
	set CUSTDETAIL(response_1)   [reqGetArg -unsafe response_1]

	set challenge_2		[reqGetArg -unsafe challenge_2]
	if {$challenge_2 == ""} {
	set challenge_2 "--"
	}
	set CUSTDETAIL(challenge_2)         $challenge_2
	set response_2		[reqGetArg -unsafe response_2]
	if {$response_2 == ""} {
	set response_2 "--"
	}
	set CUSTDETAIL(response_2)         $response_2

	set CUSTDETAIL(sig_date)            [reqGetArg -unsafe sig_date]
	set CUSTDETAIL(fname)               [reqGetArg -unsafe fname]

	if {[OT_CfgGet CAPTURE_FULL_NAME 0]} {
		set CUSTDETAIL(mname)               [reqGetArg -unsafe mname]
	} else {
		set CUSTDETAIL(mname) ""
	}

	set CUSTDETAIL(lname)               [reqGetArg -unsafe lname]
	set CUSTDETAIL(addr_street_1)       [reqGetArg -unsafe addr_street_1]
	set CUSTDETAIL(addr_street_2)       [reqGetArg -unsafe addr_street_2]
	set CUSTDETAIL(addr_street_3)       [reqGetArg -unsafe addr_street_3]
	set CUSTDETAIL(addr_street_4)       [reqGetArg -unsafe addr_street_4]
	set CUSTDETAIL(addr_city)           [reqGetArg -unsafe addr_city]
	set CUSTDETAIL(addr_country)        [reqGetArg -unsafe addr_country]
	set CUSTDETAIL(addr_state_id)	    [reqGetArg -unsafe addr_state_id]
	set CUSTDETAIL(addr_postcode)       [reqGetArg -unsafe addr_postcode]

	set CUSTDETAIL(email)               [encoding convertfrom $CHARSET [reqGetArg email]]
	set CUSTDETAIL(ignore_empty_email)  [reqGetArg ignore_empty_email]
	set CUSTDETAIL(itv_email)           [encoding convertfrom $CHARSET [reqGetArg itv_email]]

	set CUSTDETAIL(contact_ok)          [encoding convertfrom $CHARSET [reqGetArg contact_ok]]
	set CUSTDETAIL(contact_how)			[encoding convertfrom $CHARSET [reqGetArg contact_how]]
	set CUSTDETAIL(mkt_contact_ok)      [encoding convertfrom $CHARSET [reqGetArg mkt_contact_ok]]
	set CUSTDETAIL(ptnr_contact_ok)     [encoding convertfrom $CHARSET [reqGetArg ptnr_contact_ok]]
	if {$CUSTDETAIL(mkt_contact_ok) == ""} {
		set CUSTDETAIL(mkt_contact_ok) "N"
	}
	if {$CUSTDETAIL(ptnr_contact_ok) == ""} {
		set CUSTDETAIL(ptnr_contact_ok) "N"
	}

	set CUSTDETAIL(dob)                 [encoding convertfrom $CHARSET [reqGetArg dob]]
	set CUSTDETAIL(dob_day)             [encoding convertfrom $CHARSET [reqGetArg dob_day]]
	set CUSTDETAIL(dob_month)           [encoding convertfrom $CHARSET [reqGetArg dob_month]]
	set CUSTDETAIL(dob_year)            [encoding convertfrom $CHARSET [reqGetArg dob_year]]

	# Even if operator hasnt selected a year, the value
	# of 'CUSTDETAIL(dob_year)' is '19--'. So the
	# corresponding field is never going to be empty.
	if {([string index $CUSTDETAIL(dob_year) 2] == "-") || \
			([string index $CUSTDETAIL(dob_year) 3] == "-")} {
		set CUSTDETAIL(dob_year) ""
	}

	set CUSTDETAIL(telephone)           [encoding convertfrom $CHARSET [reqGetArg telephone]]
	set CUSTDETAIL(mobile)              [encoding convertfrom $CHARSET [reqGetArg mobile]]
	set CUSTDETAIL(office)              [encoding convertfrom $CHARSET [reqGetArg office]]
	set CUSTDETAIL(fax)                 [encoding convertfrom $CHARSET [reqGetArg fax]]

	set CUSTDETAIL(promo_code)          [reqGetArg promo_code]

	set CUSTDETAIL(price_type)          [reqGetArg price_type]

	# additions for telebet
	set CUSTDETAIL(title)               [reqGetArg title]
	set CUSTDETAIL(cust_sort)           [reqGetArg cust_sort]

	set CUSTDETAIL(salutation)          [reqGetArg salutation]
	set CUSTDETAIL(occupation)          [reqGetArg occupation]
	set CUSTDETAIL(gender)              [reqGetArg gender]

	set CUSTDETAIL(code)                [reqGetArg code]
	set CUSTDETAIL(code_txt)            [reqGetArg code_txt]

	set CUSTDETAIL(group_value_id1)     [reqGetArg group_value_id1]
	set CUSTDETAIL(group_value_txt1)    [reqGetArg group_value_id1]
	set CUSTDETAIL(group_value_id2)     [reqGetArg group_value_id2]
	set CUSTDETAIL(group_value_txt2)    [reqGetArg group_value_id2]
	set CUSTDETAIL(group_value_id3)     [reqGetArg group_value_id3]
	set CUSTDETAIL(group_value_txt3)    [reqGetArg group_value_id3]
	set CUSTDETAIL(group_value_id4)     [reqGetArg group_value_id4]
	set CUSTDETAIL(group_value_txt4)    [reqGetArg group_value_id4]

	# elite customer type
	set CUSTDETAIL(elite)               [reqGetArg elite]

	# and the clear down
	set CUSTDETAIL(min_repay)           [reqGetArg min_repay]
	set CUSTDETAIL(min_settle)          [reqGetArg min_settle]
	set CUSTDETAIL(min_funds)           [reqGetArg min_funds]
	set CUSTDETAIL(pay_pct)             [reqGetArg pay_pct]
	set CUSTDETAIL(credit_limit)        [reqGetArg credit_limit]
	set CUSTDETAIL(cd_grp_id)           [reqGetArg cd_grp_id]

	set CUSTDETAIL(fbteam) 		        [reqGetArg fbteam]
	set CUSTDETAIL(net_access)          [reqGetArg net_access]

	# options
	set CUSTDETAIL(tax_on)              [reqGetArg tax_on]
	set CUSTDETAIL(ap_on)               [reqGetArg ap_on]

	# hear about details
	set CUSTDETAIL(hear_about)          [reqGetArg -unsafe hear_about]
	set CUSTDETAIL(hear_about_txt)      [reqGetArg -unsafe hear_about_txt]
	set CUSTDETAIL(hear_about_free_txt)      [reqGetArg -unsafe hear_about_free_txt]

	# partnership details
	set CUSTDETAIL(partnership)         [reqGetArg -unsafe partnership]

	# affiliate details
	set CUSTDETAIL(aff_id)					 [reqGetArg -unsafe aff_id]

	# settle type
	set CUSTDETAIL(settle_type)    		[reqGetArg settle_type]

	# are statement details included?
	set CUSTDETAIL(stmt_available)		[reqGetArg stmt_available]

	# card details
	set CUSTDETAIL(card_no)			[reqGetArg card_no]
	set CUSTDETAIL(expiry)			[reqGetArg expiry]
	set CUSTDETAIL(start)			[reqGetArg start]
	set CUSTDETAIL(issue_no)		[reqGetArg issue_no]
	set CUSTDETAIL(hldr_name)		[reqGetArg hldr_name]

	if {$CUSTDETAIL(stmt_available) == "Y"} {
		set CUSTDETAIL(stmt_on)			[reqGetArg stmt_on]

		if {$CUSTDETAIL(stmt_on) == "Y"} {
			set CUSTDETAIL(freq_unit)		[reqGetArg freq_unit]
			set CUSTDETAIL(freq_amt)		[reqGetArg freq_amt]
			set CUSTDETAIL(dlv_method)		[reqGetArg dlv_method]
			set CUSTDETAIL(due_from)		[reqGetArg due_from]
			set CUSTDETAIL(due_to)			[reqGetArg due_to]
			set CUSTDETAIL(status)			[reqGetArg status]

			if {[reqGetArg brief] != "Y"} {
				set CUSTDETAIL(brief) "N"
			} else {
				set CUSTDETAIL(brief) "Y"
			}
		}
	}
	if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0]} {
		set CUSTDETAIL(cpm_id) [reqGetArg cpm_id]
	}
	set CUSTDETAIL(ignore_mand)		[reqGetArg ignore_mand]

	#
	# Validate customers input
	#

	if {$CUSTDETAIL(ignore_mand)=="Y"} {
		chk_optional_txt   $CUSTDETAIL(addr_street_1)  "first line of your address"
		chk_optional_txt   $CUSTDETAIL(fname)              "first name"
		if {[OT_CfgGet CAPTURE_FULL_NAME 0]} {
			chk_optional_txt   $CUSTDETAIL(lname)      "last name"
		} else {
			chk_optional_txt   $CUSTDETAIL(lname)      "last name"
		}
	} else {
		chk_mandatory_txt   $CUSTDETAIL(addr_street_1)  "first line of your address"
		chk_mandatory_txt   $CUSTDETAIL(fname)             "first name"
		if {[OT_CfgGet CAPTURE_FULL_NAME 0]} {
			chk_mandatory_txt   $CUSTDETAIL(lname)     "last name" 2
		} else {
			chk_mandatory_txt   $CUSTDETAIL(lname)     "last name"
		}
	}

	chk_optional_txt    $CUSTDETAIL(addr_street_3)  "third line of your address"
	chk_optional_txt    $CUSTDETAIL(addr_street_4)  "fourth line of your address"

	#
	# check if the following registration fields (paired in list at top of file
	# with text required for screen output) are included in config variable
	# MANDATORY_REG_DETAILS_... if so, call chk_mandatory_txt, if not call chk_optional_txt
	# Differnet fields for Update and Registration
	#

	# This is an unfortunate hack to avoid telebet configs which need to be
	# sourced for offshore only to affect registration in admin.
	if {[info exists admin_screens] && $admin_screens} {
		set mandatory_list [list]
	} else {
		switch -- $CUSTDETAIL(acct_type) {
			"DBT" {set mandatory_list [OT_CfgGet MANDATORY_REG_DETAILS_DBT ""]}
			"DEP" {set mandatory_list [OT_CfgGet MANDATORY_REG_DETAILS_DEP ""]}
			"CDT" {set mandatory_list [OT_CfgGet MANDATORY_REG_DETAILS_CDT ""]}
		}
		if {[reqGetArg doUpdate] != 1} {
			set mandatory_list \
				[concat $mandatory_list [OT_CfgGet MANDATORY_REG_DETAILS_COMMON ""]]
		}
	}

	# Add postcode th the mandatory list if postcode is manadatory for the users country
	set postcode_mand_countries [OT_CfgGet MANDATORY_POSTCODE_COUNTRIES [list]]
	set mandatory [lsearch $postcode_mand_countries $CUSTDETAIL(country_code)]
	if {$mandatory != -1 && \
		($CUSTDETAIL(acct_type) == "DBT" || $CUSTDETAIL(acct_type) == "DEP"
	)} {
		lappend mandatory_list "addr_postcode"
	}

	# If this customer has Internet access add email, username and password
	# to the mandatory list
	if {[OT_CfgGetTrue TELEBET] && $CUSTDETAIL(acct_type) == "DEP" && $CUSTDETAIL(net_access) != "N"} {
		lappend mandatory_list "email"

		if {$register == 1} {
			if {[OT_CfgGet ALLOW_SPECIFIED_USERNAME 0]} {
				lappend mandatory_list "username"
			}

			lappend mandatory_list "password"
		}
	}

	foreach {field screen_output} $FIELD_DESCRIPTIONS {
		# if the field has not been set try to retrieve it form the call
		# if it is not present this it will be defaulted to ""
		# then chek if it is mandatory or optional
		if {![info exists CUSTDETAIL($field)]} {
			set CUSTDETAIL($field) [reqGetArg $field]
		}
		if {[lsearch -exact $mandatory_list $field] >= 0} {
			chk_mandatory_txt $CUSTDETAIL($field) $screen_output
		} else {
			chk_optional_txt $CUSTDETAIL($field) $screen_output
		}
	}

	# do checks for exclusive details here
	foreach {mand_list txt} [OT_CfgGet MAND_REG_EXCLUSIVE_DETAILS {}] {
		set success 0
		# go through the fields and check that at least one is not empty
		foreach excl_field $mand_list {
			if {[info exists CUSTDETAIL($excl_field)] &&
					$CUSTDETAIL($excl_field) != ""} {
				set success 1
			}
		}

		if {!$success} {
			tb_reg_err_add $txt
		}
	}

	#
	# Channel specific checks
	#
	if {$CUSTDETAIL(email) != ""} {
		chk_email $CUSTDETAIL(email)
	}
	
	chk_optional_txt  $CUSTDETAIL(hear_about_txt) "marketing source \"other\" box"
	chk_optional_txt    $CUSTDETAIL(hear_about)         "marketing source"
	chk_optional_txt    $CUSTDETAIL(partnership)        "partnership flag"
	chk_optional_txt    $CUSTDETAIL(aff_id)             "affiliate"
	chk_phone_no        $CUSTDETAIL(telephone)          "telphone number"
	chk_phone_no        $CUSTDETAIL(mobile)             "mobile number"
	chk_phone_no        $CUSTDETAIL(office)             "office number"
	chk_phone_no        $CUSTDETAIL(fax)                "fax number"
	chk_contact         $CUSTDETAIL(contact_ok)
	chk_pricetype       $CUSTDETAIL(price_type)

	#
	# Deal with date of birth...
	#
	if {$CUSTDETAIL(dob) == ""} {
		if {$CUSTDETAIL(dob_day) != ""} {
			set dob_chk_string "$CUSTDETAIL(dob_day)$CUSTDETAIL(dob_month)$CUSTDETAIL(dob_year)"
			if {[chk_date $dob_chk_string "Date of birth"]} {
				set CUSTDETAIL(dob) [chk_dob $CUSTDETAIL(dob_year) $CUSTDETAIL(dob_month) $CUSTDETAIL(dob_day)]
			}
		}
	}

	if {$CUSTDETAIL(sig_date) != ""} {
		chk_date $CUSTDETAIL(sig_date) "Memorable date"
	}

	# settlement type
	if {[lsearch [list "N" "T"] $CUSTDETAIL(settle_type)] == -1} {
		tb_reg_err_add "The settlement type is invalid"
		OT_LogWrite 5 "settlement type is invalid ($CUSTDETAIL(settle_type))"
	}


	# check the clear down amounts
	chk_money $CUSTDETAIL(min_repay)		"Minimum repayment"
	chk_money $CUSTDETAIL(min_settle) 		"Payment Request"
	chk_money $CUSTDETAIL(min_funds)		"Minimum funds"
	chk_money $CUSTDETAIL(credit_limit)		"Credit limit"
	chk_integer $CUSTDETAIL(pay_pct)  		"Payment percentage"

	set CUSTDETAIL(external_groups_count) [reqGetArg ext_group_count]

	if {$CUSTDETAIL(external_groups_count)==""} {
		set CUSTDETAIL(external_groups_count) 0
	}

	for {set r 0} {$r < $CUSTDETAIL(external_groups_count)} {incr r} {
		set parameter "ext_group_id_$r"
		set CUSTDETAIL($r,ext_group_code) [reqGetArg $parameter]

		set parameter "ext_cust_id_$r"
		set CUSTDETAIL($r,ext_cust_id) [reqGetArg $parameter]

		# Will be either 'on' or ''
		foreach f {ext_master ext_permanent} {
			if {[reqGetArg "${f}_$r"] == "on"} {
				set CUSTDETAIL($r,$f) "Y"
			} elseif {[reqGetArg "${f}_$r"] == "undef"} {
				set CUSTDETAIL($r,$f) "U"
			} else {
				set CUSTDETAIL($r,$f) "N"
			}
		}
	}

	# Get the log_no for logged punters, needed for disabling statements (WH)
	set CUSTDETAIL(shop_no) [reqGetArg shop_no]
	set CUSTDETAIL(log_no)  [reqGetArg log_no]

	# Get the Rep Code
	set rep_code_status [reqGetArg rep_code_disable]

	if {$rep_code_status == "on"} {
		# If checked, the rep code is disabled
		set rep_code_status "X"
	} else {
		set rep_code_status "A"
	}

	set CUSTDETAIL(rep_code)        [reqGetArg rep_code]
	set CUSTDETAIL(rep_code_status) $rep_code_status

}



# tb_stralfor_code
# Add or update a Stralfors code on an account
# cust_id        - the cust_id for adding the code
# transact       - whether to do this in its own transaction
# priority       - the customer is a priority customer
proc tb_stralfor_code {cust_id {transact 0} {priority 0}} {

	ob_log::write INFO {tb_register: tb_stralfor_code Cust:$cust_id \
		Transact:$transact}

	# Check whether internet customer or not - Internet customers don't get welcome packs
	if {[catch {
		set rs [tb_db::tb_exec_qry getInternetCust $cust_id]
	} msg]} {
		ob_log::write ERROR {Error checking customer type}
		return
	}

	if {[db_get_nrows $rs]} {
		# Customer is internet customer don't add Stralfors code
		db_close $rs
		return
	}
	db_close $rs

	# Get the customer's group
	if {[catch {
		set rs [tb_db::tb_exec_qry get_cust_group_id $cust_id]
	} msg]} {
		if {$transact} {
			tb_db::tb_rollback_tran
		}
		tb_reg_err_add $msg
		return
	}
	set group_code [db_get_col $rs 0 code]
	db_close $rs

	set stralfors_flag [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]

	set av_status 0

	if{[OT_CfgGet FUNC_OVS 0]} {
		set av_status [verification_check::get_ovs_status $cust_id "AGE"]
	}

	switch $av_status {
		A {
			set age_vrf 1
		}
		default {
			set age_vrf 0
		}
	}

	if {$transact} {
		tb_db::tb_begin_tran
	}

	if {$priority == 0} {
		if {[lsearch {"G" "P" "T3"} $group_code] != -1} {
			set check_group 1
		} else {
			set check_group 0
		}

		if {[catch {
			set rs [tb_db::tb_exec_qry get_stralfors_code_id $cust_id $check_group \
				$age_vrf]
		} msg]} {
			if {$transact} {
				tb_db::tb_rollback_tran
			}
			tb_reg_err_add $msg
			return 0
		}

		if {[db_get_nrows $rs] > 0} {
			set print_code      [db_get_col $rs 0 print_code]
			set account_code    [db_get_col $rs 0 account_type]
			set letter_code     [db_get_col $rs 0 letter]
			set tel_code        [db_get_col $rs 0 tel_no]
			set business_code   [db_get_col $rs 0 business_cond]

			db_close $rs
		} else {
			# No Stralfors code returned
			db_close $rs
			if {$transact} {
				tb_db::tb_rollback_tran
			}
			return 0
		}
	} else {
		set print_code    "1"
		set account_code  "C"
		set letter_code   "E"
		set tel_code      "C"
		set business_code "1"
	}

	if {[catch {
		set rs [tb_db::tb_exec_qry get_cust_stralfors $cust_id]
	} msg]} {
		if {$transact} {
			tb_db::tb_rollback_tran
		}
		tb_reg_err_add $msg
		return 0
	}

	if {[db_get_nrows $rs] == 0} {
		tb_db::tb_exec_qry insert_cust_stralfors $cust_id $print_code \
			$account_code $letter_code $tel_code $business_code
		set update 1
	} elseif {[db_get_nrows $rs] == 1} {
		set stralfor_id [db_get_col $rs 0 stralfor_id]
		if {$print_code == [db_get_col $rs print_code] && $account_code == [db_get_col $rs account_type] \
			 && $letter_code == [db_get_col $rs letter] && $tel_code == [db_get_col $rs tel_no] \
			&& $business_code == [db_get_col $rs bus_cond]} {
				set update 0
		} else {
			set update 1
			tb_db::tb_exec_qry update_cust_stralfors $print_code \
				$account_code $letter_code $tel_code $business_code $stralfor_id
		}
	} else {
		return 0
	}
	db_close $rs

	if {$update} {
		OB_prefs::set_cust_flag $cust_id $stralfors_flag "Y"
		tb_db::tb_exec_qry set_exported "N" $cust_id
	}

	if {$transact} {
		tb_db::tb_commit_tran
	}
}


#
# Registration
#
proc tb_do_registration {{type PASSWD} {transactional "Y"}} {

	global LANG CHARSET USER_ID FBDATA
	variable CUSTDETAIL

	OT_LogWrite 5 "==> tb_do_registration"
	OT_LogWrite 20 "Raw post : [reqGetRawPost]"

	catch {unset CUSTDETAIL}

	set cfg "MANDATORY_REG_DETAILS_[reqGetArg acct_type]"
	set mandatory_list [OT_CfgGet $cfg ""]

	#
	# reset the error condition
	#
	tb_reg_err_reset

	#
	# Username/Acct no/Pin/Password
	#
	set CUSTDETAIL(username)        [reqGetArg -unsafe username]
	set CUSTDETAIL(password)        [reqGetArg -unsafe password]
	set CUSTDETAIL(password2)       [reqGetArg -unsafe password2]
	# do we allow 7 digit usernames?
	if { [OT_CfgGet DISABLE_7DIGITS_USERNAMES 0] } {
		if { [regexp {^\d{7}$} $CUSTDETAIL(username)] } {
			tb_reg_err_add  "Bad Username (Config disallows 7digits usernames)"
		}
	}

	# Check if we're using case insensitive password
	if {[OT_CfgGet CUST_PWD_CASE_INSENSITIVE 0]} {
		set CUSTDETAIL(password)    [string toupper $CUSTDETAIL(password)]
		set CUSTDETAIL(password2)   [string toupper $CUSTDETAIL(password2)]
	}

	#
	# auto generate acct_no?
	#
	set CUSTDETAIL(gen_acct_no_on_reg) [reqGetArg gen_acct_no_on_reg]
	set CUSTDETAIL(acct_no)         [reqGetArg -unsafe acct_no]
	set CUSTDETAIL(pin)             [reqGetArg -unsafe pin]
	set CUSTDETAIL(pin2)            [reqGetArg -unsafe pin2]

	# Tote want to gnerate customer account numbers from the DB in pInsCustomer.
	#
	if {[string toupper [OT_CfgGet OPENBET_CUST LBR]] == "TOTE"} {
		set CUSTDETAIL(gen_acct_no_on_reg) "N"
		if {$CUSTDETAIL(username) == ""} {
			set inet_activated 0
		} else {
			set inet_activated 1
		}
	}

	if {[string toupper [OT_CfgGet OPENBET_CUST LBR]] != "TOTE" &&
		$CUSTDETAIL(gen_acct_no_on_reg) != "Y"} {

		if {$CUSTDETAIL(username) == "" && $CUSTDETAIL(acct_no) == ""} {
			tb_reg_err_add "Customer requires a username or account number"
		}
		# If we allow a specified username, check that it's not empty
		if { [OT_CfgGet ALLOW_SPECIFIED_USERNAME 1] } {
			if {$CUSTDETAIL(username) != ""} {
				chk_mandatory_txt   $CUSTDETAIL(username) "username"
			}
		}

		if {$CUSTDETAIL(acct_no) != ""} {
			chk_mandatory_txt   $CUSTDETAIL(acct_no) "account"

			# Do a completely customer check on the customer's username.
			# The description allows us to specify a human readable error message.
			#
			set rx   [OT_CfgGet REG_ACCT_NO_REG_EXP {}]
			set desc [OT_CfgGet REG_ACCT_NO_REG_EXP_DESC ""]

			if {![regexp $rx $CUSTDETAIL(acct_no)]} {
				tb_reg_err_add "Invalid Accout ID ($desc)"
			}

			# Add check to make sure only a-zA-Z0-9-_ are allowed

			if { [OT_CfgGet REG_ALLOW_SPACES_AND_AT 0] == 1} {
				set check {[^a-zA-Z0-9\ @_-]+}
				set err_string "Invalid Account ID (can only contain a-z A-Z 0-9 spaces @ _ and -)"
			} else {
				set check {[^a-zA-Z0-9_-]+}
				set err_string "Invalid Account ID (can only contain a-z A-Z 0-9 _ and -)"
			}

			if { [regexp $check $CUSTDETAIL(acct_no)] } {
				tb_reg_err_add $err_string
			}
		}
	}

	if {$CUSTDETAIL(pin) != "" || $CUSTDETAIL(pin2) != ""} {
		chk_pin $CUSTDETAIL(pin) $CUSTDETAIL(pin) [OT_CfgGet MIN_PIN_LENGTH 6] [OT_CfgGet MAX_PIN_LENGTH 8]
	}

	if {[lsearch -exact $mandatory_list "pin"] >= 0 && $CUSTDETAIL(pin)==""} {
		tb_reg_err_add "PIN is mandatory"
	}

	#
	# Other registration specific stuff
	#
	set CUSTDETAIL(currency_code)   [encoding convertfrom $CHARSET [reqGetArg currency_code]]
	set CUSTDETAIL(ipaddr)          [reqGetEnv REMOTE_ADDR]
	set CUSTDETAIL(reg_status)      "A"
	set CUSTDETAIL(acct_type)       [reqGetArg acct_type]
	set CUSTDETAIL(csc)             [reqGetArg csc]

	if {[lsearch [list "DEP" "DBT" "CDT"] $CUSTDETAIL(acct_type)] == -1} {
		# Currently, a customer can have only one type of account, one of
		# DEP - deposit
		# DBT - debit-card-driven
		# CDT - credit
		tb_reg_err_add "The customers account type is invalid"
		OT_LogWrite 5 "The customers account type is invalid: $CUSTDETAIL(acct_type)"
	}

	set CUSTDETAIL(over_18)         [reqGetArg over18]
	set CUSTDETAIL(read_rules)      [reqGetArg read_rules]
	set CUSTDETAIL(source)          [reqGetArg -unsafe source]

	#
	# Get the acct owner value - if it doesn't exist, set it to "C"
	#
	if {[reqGetArg acct_owner] == ""} {
		set CUSTDETAIL(acct_owner)   "C"
	} else {
		set CUSTDETAIL(acct_owner)   [reqGetArg acct_owner]
	}

	#
	# Change the rep_code_status to a char(1)
	#
	set rep_code_status [reqGetArg rep_code_disable]

	if {$rep_code_status == "on"} {
		# If checked, the rep code is disabled
		set rep_code_status "X"
	} else {
		set rep_code_status "A"
	}

	set CUSTDETAIL(rep_code)        [reqGetArg rep_code]
	set CUSTDETAIL(rep_code_status) $rep_code_status
	set CUSTDETAIL(owner_type)      [reqGetArg OwnerType]
	set CUSTDETAIL(shop_id)         [reqGetArg ShopId]
	set CUSTDETAIL(staff_member)    [reqGetArg StaffMember]

	set CUSTDETAIL(reg_combi)       [reqGetArg reg_combi]

	if {$CUSTDETAIL(reg_combi) == ""} {
		set CUSTDETAIL(reg_combi) $CUSTDETAIL(source)
	}

	# Set customer referral information
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"]         == "TRUE" &&
	    [OT_CfgGet ENABLE_FREEBET_REFERRALS "FALSE"] == "TRUE"} {
		set CUSTDETAIL(ref_cust_id) [reqGetArg ref_cust_id]
	} else {
		set CUSTDETAIL(ref_cust_id) ""
	}


	chk_ipaddr          $CUSTDETAIL(ipaddr)
	chk_age             $CUSTDETAIL(over_18)
	chk_rules           $CUSTDETAIL(read_rules)


	#
	# get the default arguments (non-register specific)
	#
	get_default_args 1

	# checking if registering is allowed for this country.
	# Requires CUSTDETAIL(country_code) which is set above in get_default_args
	if {[OT_CfgGet FUNC_RESPECT_CNTRY_PERM_ON_REG 0] == 1} {
		chk_country         $CUSTDETAIL(country_code) $CUSTDETAIL(ipaddr) \
		                    $CUSTDETAIL(addr_postcode)
	}

	#
	# Verify the customers card (if specified)
	#
	set card_required [reqGetArg card_required]
	set register_card 0

	if {[lsearch -exact $mandatory_list "card_no"] == -1} {
		set card_required "N"
	}

	if {$card_required != "N" || [reqGetArg card_no] != ""} {
		 if {[OT_CfgGet ALLOW_REG_CREDIT_CARDS 0]} {
			set allow_cc N
		 } else {
			set allow_cc Y
		 }


		#
		# do we allow duplicate cards?
		#
		if {[OT_CfgGet ALLOW_TB_DUPLICATE_CARDS 0]} {
			if {$CUSTDETAIL(source)=="E" || $CUSTDETAIL(reg_combi)=="P"} {
				set allow_duplicate_card 1
			} else {
				set allow_duplicate_card 0
			}
		} else {
			if {[reqGetArg allow_duplicate_card] == 1} {
				set allow_duplicate_card 1
			} else {
				set allow_duplicate_card 0
			}
		}

		# Check for duplicated card? Default to yes
		if {[reqGetArg check_for_duplicate_card] == 0} {
			set check_for_duplicate_card 0
		} else {
			set check_for_duplicate_card 1
		}

		#
		# verify this card is ok
		#
		set verify_result [card_util::verify_cust_card_all \
		                "Y" \
		                $allow_cc \
		                -1 \
		                $allow_duplicate_card \
		                0 \
		                $CUSTDETAIL(acct_type) \
		                [::card_util::get_chan_site_operator_id $CUSTDETAIL(source)] \
		                $check_for_duplicate_card]

		if {[lindex $verify_result 0] != 1} {
			OT_LogWrite 5 "Customers card failed verification check"
			tb_reg_err_add [lindex $verify_result 1]
			return 0
		}
		set register_card 1
	}

	#
	# if we're a CDT customer then a statementing period must be set, unless a
	# logged punter (WH)
	#
	set CUSTDETAIL(credit_limit) [reqGetArg credit_limit]
	if {$CUSTDETAIL(shop_no) == "" && $CUSTDETAIL(log_no) == ""} {
		if {$CUSTDETAIL(acct_type) == "CDT"} {
			if {$CUSTDETAIL(stmt_available) == "N" || $CUSTDETAIL(stmt_on) == "N"} {
				tb_reg_err_add	"Credit accounts must have statements enabled"
			}
		} else {
			if {$CUSTDETAIL(credit_limit) != 0} {
				tb_reg_err_add	"Credit limit must be zero for non-credit accounts"
			}
		}
	}

	if {$CUSTDETAIL(password) != "" || $CUSTDETAIL(password2) != ""} {
		set tmpErrList [chk_unsafe_pwd $CUSTDETAIL(password) $CUSTDETAIL(password2) $CUSTDETAIL(username)]
		foreach tmpErr $tmpErrList {
			tb_reg_err_add $tmpErr
		}
	} elseif {[lsearch -exact $mandatory_list "password"] >= 0} {
		tb_reg_err_add "Password is mandatory"
	}


	#
	# Check whether the CSC was mandatory for registration
	#
	if {[lsearch -exact $mandatory_list "csc"] >= 0 && $CUSTDETAIL(csc)==""} {
		tb_reg_err_add "Card Security Number is mandatory"
	}

	#
	# Check whether the DOB was mandatory for registration
	#
	if {[lsearch -exact $mandatory_list "dob"] >= 0 && $CUSTDETAIL(dob)==""} {
		tb_reg_err_add "Date of birth is mandatory"
	}

	#
	# Check that an intro source (hear_about) has been specified if it is required
	#
	if {([lsearch -exact $mandatory_list "hear_about"] >= 0)  && ($CUSTDETAIL(hear_about)=="" || $CUSTDETAIL(hear_about_txt)=="")} {
		tb_reg_err_add "Intro source is mandatory, ensure both the type and source pulldown boxes have been selected"
	}

	#
	# If we are specifying a referral customer then check they exist
	#
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" && [OT_CfgGet ENABLE_FREEBET_REFERRALS "FALSE"] == "TRUE"} {

		OT_LogWrite 5 "Checking referral customer :$CUSTDETAIL(ref_cust_id)"
		if {$CUSTDETAIL(ref_cust_id) != ""} {

			if [catch {set ref_rs [tb_db::tb_exec_qry chk_cust_id_username $CUSTDETAIL(ref_cust_id)]} msg] {

				OT_LogWrite 1 "Referral customer check failed - retrieve on username"
				tb_reg_err_add  "Unable to retrieve referral customer details"

			} else {

				set ref_nrows [db_get_nrows $ref_rs]
				db_close $ref_rs

				if {$ref_nrows != 1} {

					# If the account doesn't exist under username then check account ID
					if [catch {set ref_rs [tb_db::tb_exec_qry chk_cust_id_acct_no $CUSTDETAIL(ref_cust_id)]} msg] {

						OT_LogWrite 1 "Referral customer check failed - retrieve on acct id"
						tb_reg_err_add  "Unable to retrieve referral customer details"

					} else {

						set ref_nrows [db_get_nrows $ref_rs]
						db_close $ref_rs

						if {$ref_nrows != 1} {
							OT_LogWrite 1 "Referral customer check failed - no user"
							tb_reg_err_add  "Referral customer does not exist"
						}
					}
				}
			}
		}
	}

	#
	# the nice bail out point
	#
	if [tb_reg_err_num] {
		OT_LogWrite 5 "too many errors"
		return 0
	}


	#
	# encrypt the pin/password
	#
	set enc_pin ""
	set enc_pwd ""
	set password_salt ""

	if {[OT_CfgGet CUST_PWD_SALT 0]} {
		set password_salt [generate_salt]
	}


	if {$CUSTDETAIL(pin) != ""} {
		set enc_pin [encrypt_pin $CUSTDETAIL(pin)]
	}
	if {$CUSTDETAIL(password) != ""} {
		set enc_pwd [encrypt_password $CUSTDETAIL(password) $password_salt]
	}


	#
	# force some parameters to required values
	#
	set CUSTDETAIL(temp_pwd) "N"

	# An asset id cannot be provided via telebet/admin. We'll use the id of
	# the fake asset set up specifically for customers registering through
	# telebet/admin
	set CUSTDETAIL(aff_asset_id) ""
	if {$CUSTDETAIL(aff_id) != ""} {
		set CUSTDETAIL(aff_asset_id) [OT_CfgGet DEFAULT_AFF_ASSET_ID 1]
	}

	#
	# start the database work
	#
	if {$transactional == "Y"} {
		tb_db::tb_begin_tran
	}

	if {$CUSTDETAIL(gen_acct_no_on_reg) == "Y"} {
		set CUSTDETAIL(acct_no) [tb_reg_gen_acct_no]
	}

	# set username to be same as acct_no if not specified
	# added for betdirect
	if {[OT_CfgGet REG_USERNAME_AS_ACCT_NO 0] && $CUSTDETAIL(username) == ""} {
		set CUSTDETAIL(username) $CUSTDETAIL(acct_no)
	}

	if [tb_reg_err_num] {
		OT_LogWrite 5 "too many errors"
		if {$transactional == "Y"} {
			tb_db::tb_rollback_tran
		}
		return 0
	}

	if {[OT_CfgGet FUNC_TEXT_BETTING_SUPPORT 0] == 1} {
		set CUSTDETAIL(text_betting) Y
	} else {
		set CUSTDETAIL(text_betting) N
	}


	#
	# Add this to the database
	#
	if {[catch {set rs [tb_db::tb_exec_qry tb_reg_insert_cust \
			$CUSTDETAIL(source)         \
			$CUSTDETAIL(aff_id)         \
			$CUSTDETAIL(acct_no)        \
			$enc_pin                    \
			$CUSTDETAIL(username)       \
			$enc_pwd                    \
			$password_salt              \
			$CUSTDETAIL(lang_code)      \
			$CUSTDETAIL(currency_code)  \
			$CUSTDETAIL(country_code)   \
			$CUSTDETAIL(acct_type)      \
			$CUSTDETAIL(ipaddr)         \
			$CUSTDETAIL(challenge_1)    \
			$CUSTDETAIL(response_1)     \
			$CUSTDETAIL(challenge_2)    \
			$CUSTDETAIL(response_2)     \
			$CUSTDETAIL(sig_date)       \
			$CUSTDETAIL(title)          \
			$CUSTDETAIL(fname)          \
			$CUSTDETAIL(mname)          \
			$CUSTDETAIL(lname)          \
			$CUSTDETAIL(dob)            \
			$CUSTDETAIL(addr_street_1)  \
			$CUSTDETAIL(addr_street_2)  \
			$CUSTDETAIL(addr_street_3)  \
			$CUSTDETAIL(addr_street_4)  \
			$CUSTDETAIL(addr_city)      \
			$CUSTDETAIL(addr_country)   \
			$CUSTDETAIL(addr_state_id)  \
			$CUSTDETAIL(addr_postcode)  \
			$CUSTDETAIL(telephone)      \
			$CUSTDETAIL(mobile)         \
			$CUSTDETAIL(office)         \
			$CUSTDETAIL(fax)            \
			$CUSTDETAIL(email)          \
			$CUSTDETAIL(contact_ok)     \
			$CUSTDETAIL(contact_how)	\
			$CUSTDETAIL(mkt_contact_ok)	\
			$CUSTDETAIL(ptnr_contact_ok)\
			$CUSTDETAIL(hear_about)     \
			$CUSTDETAIL(hear_about_txt) \
			$CUSTDETAIL(gender)         \
			$CUSTDETAIL(itv_email)      \
			$CUSTDETAIL(temp_pwd)       \
			$CUSTDETAIL(cust_sort)      \
			[OT_CfgGet REG_COMBI_$CUSTDETAIL(source) $CUSTDETAIL(reg_combi)] \
			$CUSTDETAIL(salutation)     \
			$CUSTDETAIL(occupation)     \
			$CUSTDETAIL(code)           \
			$CUSTDETAIL(code_txt)       \
			$CUSTDETAIL(elite)          \
			$CUSTDETAIL(min_repay)      \
			$CUSTDETAIL(min_funds)      \
			$CUSTDETAIL(min_settle)     \
			$CUSTDETAIL(credit_limit)   \
			$CUSTDETAIL(pay_pct)        \
			$CUSTDETAIL(settle_type)    \
			"N"                         \
			$CUSTDETAIL(fbteam)			\
			$CUSTDETAIL(partnership)    \
			$CUSTDETAIL(cd_grp_id)      \
			$CUSTDETAIL(acct_owner)     \
			$CUSTDETAIL(owner_type)     \
			$CUSTDETAIL(aff_asset_id)   \
			$CUSTDETAIL(text_betting)   \
			$CUSTDETAIL(shop_id)        \
			$CUSTDETAIL(staff_member)   \
			[OT_CfgGet CUST_ACCT_NO_FORMAT A] \
			$CUSTDETAIL(rep_code)       \
			$CUSTDETAIL(rep_code_status)]} msg]} {

		if {$transactional == "Y"} {
			tb_db::tb_rollback_tran
		}

	OT_LogWrite 5 "MSG> $msg"
		# Need to check account number already used
		if {[regexp {already chosen} $msg]} {
			if {[regexp {username} $msg]} {
				tb_reg_err_add [format "Username %s already chosen by someone else" $CUSTDETAIL(username)]
			} elseif {[regexp {account no} $msg]} {
				tb_reg_err_add [format "Account number %s already used" $CUSTDETAIL(acct_no)]
			} else {
				tb_reg_err_add $msg
			}
		} else {
			tb_reg_err_add $msg
		}
		return 0
	}

	set cust_id [db_get_coln $rs 0 0]
	db_close $rs


	# Note that this is not required if a customer supplies a username and
	# password, as they will effectively be Internet Activated already. I
	# think this is mandatory through Admin registration at least.
	#
	# Note: check against inconsistent capitalisation of the customer name.
	#
	if {[string toupper [OT_CfgGet OPENBET_CUST ""]] == "TOTE"} {
		OB_prefs::set_cust_flag $cust_id "inet_activated" $inet_activated
	}

	# Add Stralfors flag to account to signify welcome pack generation
	if {[OT_CfgGet ENABLE_STRALFORS 0]} {
		# If the new credit limit is over 1000 pounds and the user is a New or
		# Regular customer, make the customer a Priority customer
		if {[catch {
			set rs [tb_db::tb_exec_qry get_cust_group_id $cust_id]
		} msg]} {
				tb_db::tb_rollback_tran
				OT_LogWrite 1 "Failed to get customer group: $msg"
				tb_reg_err_add $msg
				return 0
		}
		set group_code [db_get_col $rs 0 code]
		db_close $rs

		set priority 0
		if {($group_code == "N" || $group_code == "R") && $CUSTDETAIL(acct_type) == "CDT" \
			&& $CUSTDETAIL(credit_limit) >= [OT_CfgGet CDT_LIMIT_THRESHOLD 1000]} {
				tb_db::tb_exec_qry upd_cust_group_id "P" $cust_id
				set priority 1
		}

		tb_stralfor_code $cust_id 0 $priority
	}

	# If either are blank, then Telebet will show no account number to the
	# operator.
	#
	if {$CUSTDETAIL(acct_no) == "" || $CUSTDETAIL(username) == "" ||
		[string toupper [OT_CfgGet OPENBET_CUST LBR]] == "TOTE"   ||
		[string toupper [OT_CfgGet OPENBET_CUST LBR]] == "WILLHILL"} {
		if {[catch {
			set rs [tb_db::tb_exec_qry tb_reg_cust_detail $cust_id]
		} msg]} {
			if {$transactional == "Y"} {
				tb_rollback_tran
			}
			tb_reg_err_add $msg
			return 0
		}

		set CUSTDETAIL(acct_no)  [db_get_col $rs 0 acct_no]
		set CUSTDETAIL(username) [db_get_col $rs 0 username]

		db_close $rs
	}

	# Right, the customer is logged in, this is for freebets.
	#
	if {[OT_CfgGet TELEBET 0] && [lsearch [package names] "cust_login"] >= 0} {
		ob_login::tbs_login $cust_id
	}

	#
	# tCustomerReg.hear_about == tHearAbout.hear_about_type
	# tCustomerReg.hear_about_text == tHearAbout.hear_about : tHearAbout.desc
	#
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE" } {
		set txt $CUSTDETAIL(hear_about_txt)
		set txt [string range $txt 0 [expr {[string first : $txt] -1}]]
		set is_data [join [list $CUSTDETAIL(hear_about) $txt] :]

		OB_freebets::check_action INTRO $cust_id 0 0 -1 $is_data
	}

	if {[catch {
		set CUSTDETAIL(acct_id) [get_acct_id $cust_id]
	} msg]} {
		if {$transactional == "Y"} {
			tb_db::tb_rollback_tran
		}
		set msg "Failed to get account ID: $msg"
		OT_LogWrite 2 $msg
		tb_reg_err_add $msg
		return 0
	}
	#
	# add the statementing details
	#
	if {$CUSTDETAIL(stmt_available) == "Y"} {

		if {$CUSTDETAIL(stmt_on) == "Y"} {

			# force the statement from the current time (registration this is ok)
			set CUSTDETAIL(due_from) [clock format [tb_statement::tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]

			if {[tb_statement::tb_stmt_add $CUSTDETAIL(acct_id) \
							$CUSTDETAIL(freq_unit) \
							$CUSTDETAIL(freq_amt) \
							$CUSTDETAIL(due_from) \
							$CUSTDETAIL(due_to) \
							$CUSTDETAIL(dlv_method) \
							$CUSTDETAIL(brief) \
							1 \
							$CUSTDETAIL(acct_type)] == 0} {

				if {$transactional == "Y"} {
					tb_db::tb_rollback_tran
				}
				tb_reg_err_add "Failed adding statement information."
				return 0
			}
		}
	}

	#
	# Register the card details
	#
	set fraud_monitor_details ""
	if {$register_card} {

		# Check if fraud screen functionality is required

		if {[OT_CfgGet FRAUD_SCREEN 0] != 0} {

			# Fraud check:
			# - store card registration attempt in tcardreg
			# - check for tumbling and swapping (10 channels)
			# - IP address monitoring (internet only)
			# - compare address country, currency country
			# 	and ip country with card country (internet only)

			OT_LogWrite 10 "fraud check"

			if {[catch {set fraud_monitor_details [fraud_check::screen_customer $cust_id $CUSTDETAIL(source) "" 0 "Y"]} msg]} {
				if {$transactional == "Y"} {
					tb_db::tb_rollback_tran
				}
				tb_reg_err_add "Cannot complete fraud check: $msg"
				return 0
			}
		}

		#
		# register the card
		#
		if {$allow_duplicate_card} {
			set result [card_util::cd_reg_card $cust_id "N" "Y"]
		} else {
			set result [card_util::cd_reg_card $cust_id "N"]
		}

		if {[lindex $result 0] != 1} {
			if {$transactional == "Y"} {
				tb_db::tb_rollback_tran
			}
			OT_LogWrite 5 "register card error [lindex $result 1]"
			tb_reg_err_add [lindex $result 1]
			return 0
		}
		set cpm_id [lindex $result 1]


		#
		# Register card as 1-Pay card ?
		#
		if {[OT_CfgGetTrue ENTROPAY] && [entropay::is_entropay_cpm $cpm_id]} {
			entropay::upd_entropay_cpm $cpm_id
		} elseif {[OT_CfgGet FUNC_ONEPAY 0]} {
			if {[ventmear::is_1pay_cust $cust_id]} {
				ventmear::set_1pay_cpmtype $cpm_id
			}
		}
	}

	#
	# Take extra steps required for shop fielding accounts
	#
	if {$CUSTDETAIL(acct_owner) == "F" && [regexp {^(STR|VAR|OCC|REG|LOG)$} $CUSTDETAIL(owner_type)]} {
		# The Max Stake Scale should be set to maximum to allow large stakes on shop fielding accounts
		if {[catch {
			tb_db::tb_exec_qry update_max_stake_scale \
			                   "99.99" \
			                   $cust_id
		} msg]} {
			if {$transactional == "Y"} {
				tb_db::tb_rollback_tran
			}
			set msg "Failed to update customers Max Stake Factor: $msg"
			OT_LogWrite 2 $msg
			tb_reg_err_add $msg
			return 0
		}
	}

	if {$transactional == "Y"} {
		tb_db::tb_commit_tran
	}

	# Send fraud monitor now that we have committed the transaction
	if {$register_card
		&& [OT_CfgGet FRAUD_SCREEN 0]
		&& [llength $fraud_monitor_details] > 0
		&& $fraud_monitor_details != 0
	} {
		eval [concat fraud_check::send_ticker $fraud_monitor_details]
	}

	#
	# Set some user preferences
	#
	set_pref $cust_id PRICE_TYPE $CUSTDETAIL(price_type)
	set_pref $cust_id TAX_ON_STAKE $CUSTDETAIL(tax_on)
	set_pref $cust_id PAY_FOR_AP $CUSTDETAIL(ap_on)


	# if SHOW_ELITE_EVENTS_BY_LOCATION is set then check location and set custflags if required
	# Should only affect Telebet registrations

	set show_elite_events [OT_CfgGet SHOW_ELITE_EVENTS_BY_LOCATION ""]
	if { $show_elite_events != "" } {
		# Check terminal location
			set term_code  [reqGetArg -unsafe term_code]
			set term_ext  [reqGetArg -unsafe term_ext]
		if {[catch {set term_rs [db_exec_qry get_term_location $term_code $term_ext]} msg]} {
			OT_LogWrite 1 "SHOW ELITE EVENTS: Unable to get terminal location. $term_code $term_ext"
		} else {
			set locn [db_get_coln $term_rs 0 0]
			if {[lsearch $show_elite_events $locn] != -1} {
				# update custflags
				if {[catch {set rs [tb_db::tb_exec_qry tb_reg_upd_cust_flag \
					$cust_id \
					"EventSrcChan" \
					"L"
				]} msg]} {
					OT_LogWrite 3 "SHOW_ELITE_EVENTS: Unable to update cust flags"
				} else {
					db_close $rs
				}
			}
			db_close $term_rs
				}
	}

	#
	# update indexed identifiers...
	#
	if {[OT_CfgGet UPD_CUST_INDEXED_ID_FIELDS 0]} {
		foreach {f} [OT_CfgGet CUST_INDEXED_ID_FIELDS [list]] {

			set field [lindex $f 0]
			set op    [lindex $f 1]
			set value [lindex $f 2]

			set c [catch {

				if {$op != ""} {
					eval $op
				}
				set value [subst $value]

				if {$value != ""} {
					tb_update_cust_index $cust_id $field $value
				}

			}  msg]

			if {$c} {
				OT_LogWrite 3 "failed update into tCustIndexedId: $msg"
			}
		}
	}


	## Bluesq send welcome mails to new customers.
	## Store the new customer in tCustMail

	if {([string equal [OT_CfgGet OPENBET_CUST ""] "BlueSQ"]) && (![string equal $CUSTDETAIL(email) ""])} {
		ins_cust_mail "REG" $cust_id $cust_id
	}

	# build ticker message
	set REG_MESSAGE [list]
	lappend REG_MESSAGE\
		firstname    $CUSTDETAIL(fname)\
		surname      $CUSTDETAIL(lname)\
		username     $CUSTDETAIL(username)\
		acct_no      $CUSTDETAIL(acct_no)\
		ip_addr      [reqGetEnv REMOTE_ADDR]\
		country      $CUSTDETAIL(country_code)\
		currency     $CUSTDETAIL(currency_code)\
		email        $CUSTDETAIL(email)\
		channel      $CUSTDETAIL(source)

	set REG_MESSAGES {}
	lappend REG_MESSAGES $REG_MESSAGE

	# send ticker message
	foreach M $REG_MESSAGES {
		OT_LogWrite 20 "MSG: $M"
		eval [concat MsgSvcNotify reg $M]
	}

	#
	# Open Terms and Conditions
	#
	if {[lsearch -exact $mandatory_list "open_t_c"] >= 0} {

		set c [catch {
			tb_db::tb_exec_qry upd_open_t_c $cust_id
		} msg]

		if {$c} {
			OT_LogWrite 3 "failed update of open_t_c: $msg"
		}
	}

	# Pass action to FreeBets(tm)
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {

		set check_action_fn "OB_freebets::check_action"

		if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

				catch {unset FBDATA}

				set check_action_fn "::ob_fbets::go_check_action_fast"

				set FBDATA(lang)           $CUSTDETAIL(lang_code)
				set FBDATA(ccy_code)       $CUSTDETAIL(currency_code)
				set FBDATA(country_code)   $CUSTDETAIL(country_code)

		}

		${check_action_fn} [list REG REGAFF] $cust_id $CUSTDETAIL(aff_id)

		if {$CUSTDETAIL(promo_code) != ""} {

			# first check for freebets promo
			set pc [string toupper $CUSTDETAIL(promo_code)]
			set pc_success [ ${check_action_fn} PROMO $cust_id $CUSTDETAIL(aff_id) \
			                                 	"" "" "" "" "" "" "" $pc]
			# Store the promo code used
			if {$pc_success} {
				OT_LogWrite 4 "Storing promo code ($pc) as flag REG_PROMO_CODE"
				tb_db::tb_exec_qry fb_flag_insert $pc $cust_id "REG_PROMO_CODE"
				set nrows [tb_db::tb_garc fb_flag_insert]
				if {$nrows==1} {
					OT_LogWrite 4 "Promo code successfully stored as flag"
				} else {
					OT_LogWrite 2 "ERROR - failed to store promo code as flag ($nrows)"
				}
			}

			# and then external system promos
			_check_ext_promo $cust_id $CUSTDETAIL(promo_code)

		}

		# now need to save ref_cust_id, if a referral username was given
		if {[OT_CfgGet ENABLE_FREEBET_REFERRALS "FALSE"] == "TRUE"} {

			if {$CUSTDETAIL(ref_cust_id) != ""} {
				OB_freebets::check_referral $CUSTDETAIL(ref_cust_id) $CUSTDETAIL(aff_id) $cust_id
			}
		}
	}

	OT_LogWrite 5 "<== tb_do_registration SUCCESS"

	return $cust_id
}



#
# Update some details...
#
proc tb_do_update_details {arry} {

	global   FBDATA
	variable CUSTDETAIL

	catch {unset CUSTDETAIL}

	upvar 1 $arry DATA


	#
	# reset the error condition
	#
	tb_reg_err_reset

	#
	# customer id
	#
	set cust_id                     [reqGetArg cust_id]
	set CUSTDETAIL(acct_type)       [reqGetArg acct_type]

	#
	# get all the default arguments
	#
	get_default_args 0

	#
	# check any updates to the customers preferred card
	#
	set card_required [reqGetArg card_required]
	set register_new_card 0


	set CUSTDETAIL(source) [reqGetArg -unsafe source]

	# check for allow duplicate cards
	if {[OT_CfgGet ALLOW_TB_DUPLICATE_CARDS 0]} {
		if {$CUSTDETAIL(source)=="E" || $CUSTDETAIL(source)=="P"} {
			set allow_duplicate_card 1
		} else {
			set allow_duplicate_card 0
		}
	} else {
		if {[reqGetArg allow_duplicate_card] == 1} {
			set allow_duplicate_card 1
		} else {
			set allow_duplicate_card 0
		}
	}

	 if {$CUSTDETAIL(promo_code) != ""} {

			set check_action_fn "OB_freebets::check_action"

			if { [OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0] } {

				catch {unset FBDATA}

				set check_action_fn "::ob_fbets::go_check_action_fast"

				set FBDATA(lang)           $CUSTDETAIL(lang_code)
				set FBDATA(ccy_code)       $CUSTDETAIL(currency_code)
				set FBDATA(country_code)   $CUSTDETAIL(country_code)
			}

		${check_action_fn} PROMO $cust_id $CUSTDETAIL(aff_id) "" "" "" "" "" "" "" $CUSTDETAIL(promo_code)
	}

	if {[reqGetArg card_available] == "Y"} {

		#
		# verify any changes to a customers card
		#
		# card must already exist on a customers account (same card number)
		# issue/start and expiry may be different though
		#
		set card_upd [card_util::verify_cust_card_update $cust_id]
		if {[lindex $card_upd 0] == 0} {
			tb_reg_err_add [lindex $card_upd 1]
		}
	} elseif {$card_required != "N" || [reqGetArg card_no] != ""} {

		#
		# If no card is available, and either one is required or new
		# card details have been specified, proceed to register this
		# new card. (Should only happen for DEPOSIT and CREDIT accounts only)
		#
		# verify this card is ok
		#
		if {[OT_CfgGet ALLOW_REG_CREDIT_CARDS 0]} {
			set allow_cc N
		} else {
			set allow_cc Y
		}

		# Check if fraud screen functionality is required
		if {[OT_CfgGet FRAUD_SCREEN 0] != 0} {

			tb_db::tb_begin_tran

			# Fraud check:
			# - store card registration attempt in tcardreg
			# - check for tumbling and swapping (10 channels)
			# - IP address monitoring (internet only)
			# - compare address country, currency country
			# 	and ip country with card country (internet only)

			OT_LogWrite 10 "fraud check"
			if {[catch {set fraud_monitor_details [fraud_check::screen_customer $cust_id $CUSTDETAIL(source) "" 0 "Y"]} msg]} {
				tb_db::tb_rollback_tran
				tb_reg_err_add "Cannot complete fraud check: $msg"
				return 0
			} else {
				tb_db::tb_commit_tran

				# Can send fraud ticker now, since we're not in a transaction
				# and therefore can't get into the situation where we rollback
				# but still send the ticker msg
				if {[llength $fraud_monitor_details] > 0
					&& $fraud_monitor_details != 0
				} {
					eval [concat fraud_check::send_ticker $fraud_monitor_details]
				}
			}
		}

		set check_for_duplicate_card [reqGetArg check_for_duplicate_card]

		if {$check_for_duplicate_card == ""} {
			set check_for_duplicate_card 1
		}

		set verify_result [card_util::verify_cust_card_all \
		                              "Y" \
		                              $allow_cc \
		                              $cust_id \
		                              $allow_duplicate_card\
		                              0 \
		                              -1 \
		                              -1 \
		                              $check_for_duplicate_card]

		if {$verify_result != 1} {
			OT_LogWrite 5 "Customers card failed verification check"
			tb_reg_err_add $verify_result
			return 0
		}
		set register_new_card 1
	}

	# bail out nicely
	if [tb_reg_err_num] {
		return 0
	}

	#
	# start updating values
	#
	tb_db::tb_begin_tran

	if {$CUSTDETAIL(mkt_contact_ok) == ""} {
		set CUSTDETAIL(mkt_contact_ok) "N"
	}
	if {$CUSTDETAIL(ptnr_contact_ok) == ""} {
		set CUSTDETAIL(ptnr_contact_ok) "N"
	}

	if {[OT_CfgGet FUNC_TEXT_BETTING_SUPPORT 0] == 1} {
		set CUSTDETAIL(text_betting) Y
	} else {
		set CUSTDETAIL(text_betting) N
	}

	if {! [OT_CfgGet CAPTURE_FULL_NAME 0]} {
		set CUSTDETAIL(mname) ""
	}

	# If the customer's group code has changed, we must update the Stralfor code later
	if {[catch {
		set rs [tb_db::tb_exec_qry get_cust_group_id $cust_id]
	} msg]} {
			tb_db::tb_rollback_tran
			OT_LogWrite 1 "Failed to get customer group: $msg"
			tb_reg_err_add $msg
			return 0
	}
	set code [db_get_col $rs 0 code]
	db_close $rs

	if {$CUSTDETAIL(code) != $code} {
		set cust_grp_changed 1
	} else {
		set cust_grp_changed 0
	}

	if {[catch {set rs [tb_db::tb_exec_qry tb_reg_upd_cust_reg \
						$cust_id \
			$CUSTDETAIL(challenge_1) \
			$CUSTDETAIL(response_1) \
			$CUSTDETAIL(challenge_2) \
			$CUSTDETAIL(response_2) \
			$CUSTDETAIL(title) \
			$CUSTDETAIL(fname) \
			$CUSTDETAIL(mname) \
			$CUSTDETAIL(lname) \
			$CUSTDETAIL(dob) \
			$CUSTDETAIL(addr_street_1) \
			$CUSTDETAIL(addr_street_2) \
			$CUSTDETAIL(addr_street_3) \
			$CUSTDETAIL(addr_street_4) \
			$CUSTDETAIL(addr_city) \
			$CUSTDETAIL(addr_country) \
			$CUSTDETAIL(addr_state_id) \
			$CUSTDETAIL(addr_postcode) \
			$CUSTDETAIL(telephone) \
			$CUSTDETAIL(mobile) \
			$CUSTDETAIL(office) \
			$CUSTDETAIL(fax) \
			$CUSTDETAIL(email) \
			$CUSTDETAIL(contact_ok) \
			$CUSTDETAIL(contact_how) \
			$CUSTDETAIL(mkt_contact_ok) \
			$CUSTDETAIL(ptnr_contact_ok) \
			$CUSTDETAIL(hear_about) \
			$CUSTDETAIL(hear_about_txt) \
			$CUSTDETAIL(gender) \
			$CUSTDETAIL(itv_email) \
			$CUSTDETAIL(salutation) \
			$CUSTDETAIL(occupation) \
			$CUSTDETAIL(code) \
			$CUSTDETAIL(code_txt) \
			$CUSTDETAIL(fbteam) \
			$CUSTDETAIL(partnership) \
			$CUSTDETAIL(text_betting) \
			$CUSTDETAIL(rep_code) \
			$CUSTDETAIL(rep_code_status)
					]} msg]} {

		tb_db::tb_rollback_tran
		OT_LogWrite 1 "Failed to update customer details: $msg"
		tb_reg_err_add "$msg"
		return 0
	}


	db_close $rs

	#
	# update tcustomer values
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_reg_upd_cust \
			$CUSTDETAIL(elite) \
			$CUSTDETAIL(lang_code) \
			$CUSTDETAIL(country_code) \
			$CUSTDETAIL(cust_sort) \
			$CUSTDETAIL(sig_date) \
			$CUSTDETAIL(aff_id) \
			$cust_id]} msg] {

		tb_db::tb_rollback_tran
		OT_LogWrite 1 "Failed to update customer details: $msg"
		tb_reg_err_add "$msg"
		return 0
	}

	db_close $rs


	#
	# update tacct values
	#
	if {[catch {
		set acct_id [get_acct_id $cust_id]
	} msg]} {
		tb_db::tb_rollback_tran
		OT_LogWrite 2 [set msg "Failed to get account ID: $msg"]
		tb_reg_err_add $msg
		return 0
	}

	if [catch {set rs [tb_db::tb_exec_qry tb_reg_upd_acct \
			$CUSTDETAIL(min_repay) \
			$CUSTDETAIL(min_funds) \
			$CUSTDETAIL(min_settle) \
			$CUSTDETAIL(pay_pct) \
			$CUSTDETAIL(settle_type) \
			$CUSTDETAIL(credit_limit) \
			$CUSTDETAIL(cd_grp_id) \
			$acct_id
					]} msg] {
		tb_db::tb_rollback_tran
		OT_LogWrite 1 "Failed to update customer account details: $msg"
		tb_reg_err_add "$msg"
		return 0
	}

	db_close $rs

	if [catch {
		for {set r 0} {$r < $CUSTDETAIL(external_groups_count)} {incr r} {
			set res [tb_db::tb_exec_qry upd_ext_cust \
										$cust_id \
										$CUSTDETAIL($r,ext_cust_id) \
										$CUSTDETAIL($r,ext_group_code)\
										$CUSTDETAIL($r,ext_master)\
										$CUSTDETAIL($r,ext_permanent)]
			catch {db_close $res}
		}
	} msg] {
		tb_db::tb_rollback_tran
		OT_LogWrite 1 "Failed to update customer external cust id details: $msg"
		tb_reg_err_add "$msg"
		return 0
	}

	# Add Stralfors flag to account to signify welcome pack generation
	if {[OT_CfgGet ENABLE_STRALFORS 0]} {
		if {[catch {set rs [tb_db::tb_exec_qry get_flag_value $cust_id [OT_CfgGet STRALFORS_FLAG_NAME "Stralfors"]]} msg]} {
			tb_db::tb_rollback_tran
			OT_LogWrite 1 "Failed to get customer Stralfors flag: $msg"
			tb_reg_err_add $msg
			return 0
		}

		set nrows [db_get_nrows $rs]
		if {$nrows == 0} {
			set stralfors_flag "N"
		} else {
			set stralfors_flag [db_get_col $rs 0 flag_value]
		}
		db_close $rs

		# If the new credit limit is over 1000 pounds and the user is a New or
		# Regular customer, make the customer a Priority customer
		if {[catch {
			set rs [tb_db::tb_exec_qry get_cust_group_id $cust_id]
		} msg]} {
				tb_db::tb_rollback_tran
				OT_LogWrite 1 "Failed to get customer group: $msg"
				tb_reg_err_add $msg
				return 0
		}
		set group_code [db_get_col $rs 0 code]
		db_close $rs

		set priority 0
		if {($group_code == "N" || $group_code == "R") && $CUSTDETAIL(acct_type) == "CDT" \
			&& $CUSTDETAIL(credit_limit) >= [OT_CfgGet CDT_LIMIT_THRESHOLD 1000]} {
				tb_db::tb_exec_qry upd_cust_group_id "P" $cust_id
				set priority 1
				set cust_grp_changed 1
		}

		if {$stralfors_flag == "Y" || $cust_grp_changed} {
			tb_stralfor_code $cust_id 0 $priority
		}
	}

	#
	# Statementing
	#

	set c [catch {


		if {$CUSTDETAIL(stmt_available) == "Y"} {

			if {$CUSTDETAIL(stmt_on) == "Y"} {

				if {$CUSTDETAIL(due_from) == ""} {
					set CUSTDETAIL(due_from) [clock format [tb_statement::tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]
				}

				set acct_id [get_acct_id $cust_id]

				if {![tb_statement::tb_stmt_acct_has_stmt $acct_id]} {

					#
					# add customers statement
					#
					tb_statement::tb_stmt_add $acct_id \
									$CUSTDETAIL(freq_unit) \
									$CUSTDETAIL(freq_amt) \
									$CUSTDETAIL(due_from) \
									$CUSTDETAIL(due_to) \
									$CUSTDETAIL(dlv_method) \
									$CUSTDETAIL(brief) \
									1


				} elseif {![OT_CfgGet STMT_CONTROL 0]} {

					#
					# update the customers statement
					#
					tb_statement::tb_stmt_upd $acct_id \
									$CUSTDETAIL(freq_unit) \
									$CUSTDETAIL(freq_amt) \
									$CUSTDETAIL(due_from) \
									$CUSTDETAIL(due_to) \
									$CUSTDETAIL(status) \
									$CUSTDETAIL(dlv_method) \
									$CUSTDETAIL(brief)
				}
			} else {

				#
				# delete the customers statement
				#
				tb_statement::tb_stmt_del $acct_id
			}
		}
	} msg]

	if {$c} {
		tb_db::tb_rollback_tran
		OT_LogWrite 1 "Failed to update customer statement details: $msg"
		tb_reg_err_add "Failed to update customer statement details: $msg"
		return 0
	}


	#
	# Card details
	#
	if {[reqGetArg card_available] == "Y"} {

		if {[OT_CfgGet ENABLE_MULTIPLE_CPMS 0]} {
			set cpm_id $CUSTDETAIL(cpm_id)
		} else {
			set cpm_id ""
		}

		if {[lindex $card_upd 0] == 2} {
			#
			# card is the same so don't update the details
			#
		} else {
			#
			# one of start,expiry,issue have changed so register a new card
			#
			set transactional "N"

			if {$allow_duplicate_card} {
				set result [card_util::cd_reg_card $cust_id $transactional "Y" 0 "Y" $cpm_id]
			} else {
				set result [card_util::cd_reg_card $cust_id $transactional "N" 0 "Y" $cpm_id]
			}

				if {[lindex $result 0] != 1} {
					tb_db::tb_rollback_tran
					OT_LogWrite 5 "update card error [lindex $result 1]"
					tb_reg_err_add [lindex $result 1]
					return 0
				}
		}
	} elseif {$register_new_card} {
			#
			# register the card
			#
			if {$allow_duplicate_card} {
				set result [card_util::cd_reg_card $cust_id "N" "Y"]
			} else {
				set result [card_util::cd_reg_card $cust_id "N"]
			}

			if {[lindex $result 0] != 1} {
				tb_db::tb_rollback_tran
				OT_LogWrite 5 "register card error [lindex $result 1]"
				tb_reg_err_add [lindex $result 1]
				return 0
			}
	}


	#    OT_LogWrite 5 "COMMIT"
	tb_db::tb_commit_tran

	#
	# Preferences
	#
	set_pref $cust_id PRICE_TYPE $CUSTDETAIL(price_type)
	set_pref $cust_id TAX_ON_STAKE $CUSTDETAIL(tax_on)
	set_pref $cust_id PAY_FOR_AP $CUSTDETAIL(ap_on)



	#
	# update indexed identifiers...
	#
	if {[OT_CfgGet UPD_CUST_INDEXED_ID_FIELDS 0]} {
		foreach {f} [OT_CfgGet CUST_INDEXED_ID_FIELDS [list]] {

			set field [lindex $f 0]
			set op    [lindex $f 1]
			set value [lindex $f 2]

			set c [catch {

				if {$op != ""} {
					eval $op
				}

				set value [subst $value]

				tb_update_cust_index $cust_id $field $value

			} msg]

			if {$c==1} {
				OT_LogWrite 3 "Update cust index error: $msg"
				return 0
			}
		}
	}

	#
	# Retrieve statement information
	#
	if {[catch {
		set acct_id [get_acct_id $cust_id]
	} msg]} {
		OT_LogWrite 2 [set msg "Failed to get account ID: $msg"]
		tb_reg_err_add $msg
		return 0
	}

	if {[tb_statement::tb_stmt_get_info $acct_id DATA] == 0} {
		set DATA(stmt_available) "N"
	} else {
		set DATA(stmt_available) "Y"
		set DATA(stmt_status)    $DATA(status)
	}

	#
	# Update customer deposit limits
	#
	if {[OT_CfgGet CHANGE_DEP_LIMITS 0]} {
		if {[reqGetArg upd_dep_limits] == 1} {
			if {[reqGetArg cancel_dep_limits] == 1} {
				set freq "none"
			} else {
				set freq    [reqGetArg dep_lim_freq]
			}
			set lim_amt [reqGetArg dep_lim_val]
			set res [ob_srp::set_deposit_limit $cust_id $freq $lim_amt]
			if {[lindex $res 0] == 0} {
				OT_LogWrite 2 [set msg "Failed to update deposit limit: You must wait [OT_CfgGet DAY_DEP_LIMIT_CHNG_PERIOD -1] days before changing the limit"]
				tb_reg_err_add $msg
				return 0
			}
		}

		if {[reqGetArg upd_dep_limits] == 0 || \
			[reqGetArg cancel_dep_limits] == 1} {
			# customer does not want to set deposit limits, add a flag to
			# indicate this
			if {[catch {db_exec_qry add_cust_flag $cust_id DECL_DEP_LIM 1} msg]} {
				OT_LogWrite 3 "add_cust_flag failed : $msg"
				return 0
			}
		}
	}

	# Update ok
	return 1
}

#
# Update customer index
#
proc tb_update_cust_index {cust_id field value} {

	if {[string length $field] > 10} {
		set field [string range $field 0 9]
	}

    set value [ob_cust::normalise_unicode $value]

	set rs [tb_db::tb_exec_qry chk_cust_index $field $cust_id]

	if {$value != ""} {

		if {[db_get_nrows $rs] == 0} {
			#
			# Value doesn't exists, do an insert
			#
			tb_insert_cust_index $cust_id $field $value
		} else {
			#
			# Value already exists, do an update
			#
			tb_db::tb_exec_qry upd_cust_index [string toupper $value] $field $cust_id
		}
	} else {

		if {[db_get_nrows $rs] > 0} {
			#
			# Indx value already exists, but has been updated to empty
			# delete indexed entry
			#
			tb_db::tb_exec_qry del_cust_index $field $cust_id
		}
	}
	db_close $rs
}

proc tb_insert_cust_index {cust_id field value} {

	if {[string length $field] > 10} {
		set field [string range $field 0 9]
	}

	tb_db::tb_exec_qry ins_cust_index [string toupper $value] $field $cust_id

}

proc tb_get_customer_details {cust_id arry} {

	global CHARSET

	upvar 1 $arry DATA

	#
	# Retrieve all customer details
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_reg_cust_detail $cust_id]} msg] {
		return "failed to retrieve customers details: $msg"
	}

	if {[db_get_nrows $rs] != 1} {
		return "failed to retrieve customers details"
	}

	foreach f [db_get_colnames $rs] {
		set DATA($f) "[db_get_col $rs 0 $f]"
	}

	set CHARSET [db_get_col $rs 0 charset]

	set acct_id [db_get_col $rs 0 acct_id]
	db_close $rs

	#
	# Retrieve statement information
	#
	if {[catch {
		set acct_id [get_acct_id $cust_id]
	} msg]} {
		tb_db::tb_rollback_tran
		OT_LogWrite 2 [set msg "Failed to get account ID: $msg"]
		tb_reg_err_add $msg
		return 0
	}

	if {[tb_statement::tb_stmt_get_info $acct_id DATA] == 0} {
		set DATA(stmt_available) "N"
	} else {
		set DATA(stmt_available) "Y"
		set DATA(stmt_status)    $DATA(status)
	}

	if {[OT_CfgGet SHOW_SUSP_CARDS 0]} {
		set and_suspended 1
	} else {
		set and_suspended 0
	}

	#
	# Card information
	#
	array set CARD ""
	set card_result [card_util::cd_get_active $cust_id CARD $and_suspended]

	if {$card_result == 0} {
		OT_LogWrite 1 "There was an error getting card details, setting no card status"
		set CARD(card_available) "N"
	}

	if {$CARD(card_available) == "Y"} {

		set DATA(card_available) "Y"
		set cpm_id [lindex $CARD(cpm_id) 0]
		set DATA(cpm_id)		 $CARD(cpm_id)
		set DATA(enc_card_no)	 $CARD($cpm_id,enc_card_no)
		set DATA(card_no)		 $CARD($cpm_id,card_no)
		set DATA(start)			 $CARD($cpm_id,start)
		set DATA(expiry)		 $CARD($cpm_id,expiry)
		set DATA(issue_no)		 $CARD($cpm_id,issue_no)
		set DATA(hldr_name)		 $CARD($cpm_id,hldr_name)
		set DATA(card_status)	 $CARD($cpm_id,status)

	} else {
		set DATA(card_available) "N"
	}
	unset CARD


	#
	# Preferences
	#
	set prc_type [get_pref $cust_id PRICE_TYPE]
	if {$prc_type == ""} {
		OT_LogWrite 5 "Failed to retrieve price type for $cust_id"
		set DATA(price_type) ODDS
	} else {
		set DATA(price_type) $prc_type
	}

	set tax_on [get_pref $cust_id TAX_ON_STAKE]
	if {$tax_on == ""} {
		OT_LogWrite 5 "Failed to retrieve tax on stake for $cust_id"
		set DATA(tax_on) Y
	} else {
		set DATA(tax_on) $tax_on
	}

	set ap_on [get_pref $cust_id PAY_FOR_AP]
	if {$ap_on == ""} {
		OT_LogWrite 5 "Failed to retrieve pay for ap for $cust_id"
		set DATA(ap_on) Y
	} else {
		set DATA(ap_on) $ap_on
	}

	#
	# load external customer groups
	#
	if [catch {set res_ext_groups [tb_db::tb_exec_qry get_external_groups $cust_id]} msg] {
		return "failed to retrieve customers details: $msg"
	}

	set num_rows [db_get_nrows $res_ext_groups]
	set DATA(ext_groups_count) $num_rows

	for {set r 0} {$r < $num_rows} {incr r} {
		set DATA(ext_code_$r)      [db_get_col $res_ext_groups $r code]
		set DATA(ext_display_$r)   [db_get_col $res_ext_groups $r display]
		set DATA(ext_cust_id_$r)   [db_get_col $res_ext_groups $r ext_cust_id]
		set DATA(ext_master_$r)    [db_get_col $res_ext_groups $r master]
		set DATA(ext_permanent_$r) [db_get_col $res_ext_groups $r permanent]
	}

	db_close $res_ext_groups

	return 1
}



#
# generate a telebetting account number according to customer type
#
proc tb_reg_gen_acct_no {} {
	variable CUSTDETAIL

	#
	# Customer type is either elite (or not)
	#
	if {[reqGetArg elite] == "Y"} {
		set cust_type "ELTE"
	} else {
		set cust_type "STD"
	}

	if {[OT_CfgGet ACCT_NO_INITIALS_PREFIX 0]} {
		set f_initial [string index $CUSTDETAIL(fname) 0]
		set l_initial [string index $CUSTDETAIL(lname) 0]
		set prefix "$f_initial$l_initial"
	} else {
		set prefix [OT_CfgGet ACCT_NO_PREFIX ""]
	}
	#
	# get the next available uid
	#
	if [catch {set rs [tb_db::tb_exec_qry tb_reg_gen_acct_no $cust_type $prefix]} msg] {
		OT_LogWrite 5 "Failed to generate acct_no: $msg"
		tb_reg_err_add "Failed to automatically generate a valid account number - please enter one manually"
		return
	}

	set acct_no [db_get_coln $rs 0 0]
	db_close $rs

	set acct_no [string map [list " " ""] $acct_no]

	return $acct_no
}

#
# update a customers pin number
#
proc tb_upd_acct_pin {cust_id new_pin {pin_min 6} {pin_max 8}} {

	variable BAD_PINS

	if {$new_pin == ""} {
		OT_LogWrite 5 "new PIN not specified"
		return "new PIN number not specified"
	}

	if {[string length $new_pin] < $pin_min || \
		[string length $new_pin] > $pin_max} {
		return "PIN number must be between $pin_min and $pin_max characters."
	}

	if {[lsearch $BAD_PINS $new_pin] >= 0} {
		OT_LogWrite 5 "you cannot choose this pin number"
		return "you cannot choose this pin number"
	}

	if {[OT_CfgGet PWORD_NUM_ONLY 0]} {
		if {![regexp {^[0-9]+$} $new_pin]} {
	   		return "Only numeric characters permitted in the PIN."
		}
	}

	set new_pin [encrypt_pin $new_pin]
	if [catch {tb_db::tb_exec_qry upd_bib_pin_tb $new_pin $cust_id} msg] {
		OT_LogWrite 1 "failed updating pin number"
		return "failed updating pin number"
	}

	return 1
}





#------------------------------------------------------------------------------#
#
# Now the utility check functions for this file
#
#------------------------------------------------------------------------------#


####################################
proc chk_mandatory_txt {str field {min -1} {max -1}} {
####################################
#
# str : value to check
# field : name of field - for use in error message
#
   global CHARSET
   variable CUSTDETAIL
	if {$field == "email" && $CUSTDETAIL(ignore_empty_email) != "" && $CUSTDETAIL(ignore_empty_email)} {
		return 1
	}

	if {$str == ""} {
		tb_reg_err_add [format "The %s is empty." $field]
		return 0
	}

	# Check the string length
	set length [string length $str]
	if {$min > 0 && $length < $min} {
		tb_reg_err_add [format "The %s must be at least $min characters." $field]
		return 0
	} elseif {$max >= 0 && $length > $max} {
		tb_reg_err_add [format "The %s must be no more than $max characters." $field]
		return 0
	}

	# chek that there are no unsafe characters...
	set test [encoding convertfrom $CHARSET $str]
	if {[regexp {[][${}\\]} $str]} {
		tb_reg_err_add [format "The %s contains invalid characters." $field]
		return 0
	}
	return 1
}

####################################
proc chk_money {amount desc} {
####################################
#
# amount : value to check
# desc : description of field - for use in error message
#
	if {![regexp {^[0-9]*\.[0-9][0-9]$} $amount] && ![regexp {^[0-9]*$} $amount]} {
		tb_reg_err_add [format "%s amount is invalid" $desc]
		return 0
	}
	return 1
}

###################################
proc chk_optional_txt {str field} {
###################################
	global CHARSET
	# chek that there are no unsafe characters...
	set test [encoding convertfrom $CHARSET $str]
	if {[regexp {[][${}\\]} $str]} {
		tb_reg_err_add [format "The %s contains invalid characters." $field]
		return 0
	}
	return 1
}

##########################################
proc chk_unsafe_pwd {pwd1 pwd2 username} {
##########################################
#
# Currently checks that usrname/pwd only alphanumeric or '_',
# passwords same and not same as username,
# length of password is 6 - 8 chars,
# length of username is 6 - 15 chars
#
# Wrapper for function ob_chk::pwd {pwd1 pwd2 username}

	set errsList [ob_chk::pwd $pwd1 $pwd2 $username]
	set returnList [list]

	foreach err $errsList {
		switch -- $err \
		REG_ERR_VAL_PWDUSERNAME  {
			lappend returnList "The password can not be the same as the username"
			} \
		REG_ERR_REG_USERNAME  {
			lappend returnList "The username contains invalid characters"
			} \
		REG_ERR_USERNAME_LEN  {
			lappend returnList "The username must be 6 - 15 characters long"
			} \
		REG_ERR_VFY_PASSWORD  {
			lappend returnList "The passwords do not match"
			} \
		REG_ERR_VAL_EASYPWD  {
			lappend returnList "The password you have chosen is too easy to guess"
			} \
		REG_ERR_CUST_PWD_LEN  {
			lappend returnList "The password must be 6 - 15 characters long"
			} \
		REG_ERR_PASSWORD  {
			lappend returnList "The password contains invalid characters"
			} \
		OB_OK  {
			set returnList ""
			} \
		default {
			lappend returnList "Unknown problem with password/username"
			break
		}
	}
	return $returnList
}



##############################
proc chk_phone_no {str field} {
##############################
	global CHARSET

	# chek that there are no unsafe characters...
	set test [encoding convertfrom $CHARSET $str]
	if {[regexp {{^[-_.+0-9() ]*$}} $str]} {
		tb_reg_err_add [format "The %s contains invalid characters." $field]
		return 0
	}
	return 1
}

##############################
proc chk_integer {str field} {
##############################
	global CHARSET

	if {$str == ""} {
		tb_reg_err_add [format "The %s is empty." $field]
		return 0
	}

	# check that there are no unsafe characters...
	set test [encoding convertfrom $CHARSET $str]
	if {[regexp {{^[0-9]*$}} $str]} {
		tb_reg_err_add [format "The %s contains invalid characters." $field]
		return 0
	}
	return 1
}

##########################
proc chk_ipaddr {ipaddr} {
##########################
	set exp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}
	if {[regexp $exp $ipaddr] == 0} {
		tb_reg_err_add [format "The %s is invalid." "IP Address of your computer"]
		return 0
	}
	return 1
}


########################
proc chk_email {email {desc email} {compulsory Y}} {
########################
	variable CUSTDETAIL

	if {$email==""} {
		if {$compulsory == "Y" && !$CUSTDETAIL(ignore_empty_email)} {
			tb_reg_err_add [format "The %s is empty." $desc]
			return 0
		}
	}

	if {[OT_CfgGet EMAIL_CHECK_ENHANCED 0]} {
		if {[ob_chk::email $email] != "OB_OK" } {
			tb_reg_err_add [format "The %s contains invalid characters." $desc]
			return 0
		}
	} else {
		set exp {^[^@]+\@([-a-zA-Z0-9]+\.)*[a-zA-Z]+$}
	    if {[regexp $exp $email] == 0} {
			 tb_reg_err_add [format "The %s contains invalid characters." $desc]
			return 0
		}
	}

	if {[OT_CfgGet FUNC_RESTRICT_EMAIL 0] &&
	    [ob_restrict_email::is_restricted $email]} {
		tb_reg_err_add "Email address $email is restricted."
		return 0
	}

	return 1
}

####################
proc chk_age {ans} {
####################
	global LANG
	if {$ans!="Y"} {
		tb_reg_err_add [format "You must be over 18 to use this site"]
		return 0
	}
}

########################
proc chk_contact {str} {
########################
	set exp {{^[Y|N]?$}}
	if {[regexp $exp $str] == 1} {
		tb_reg_err_add [format "Please indicate whether you would like us to contact you or not."]
		return 0
	}
	return 1
}

######################
proc chk_rules {ans} {
######################
	global LANG
	if {$ans!="Y"} {
		tb_reg_err_add [format "You must have read and understood the rules to use this site"]
		return 0
	}
	 return 1
}

######################
proc chk_pricetype {ans} {
######################
	global LANG
	if {$ans!="ODDS" && $ans !="DECIMAL"} {
		tb_reg_err_add [format "Please choose a preferred odds display"]
		return 0
	}
	return 1
}

##########################
proc chk_country {country_code ipaddr addr_postcode} {
##########################

	# Checking that users can register from this country.
	# We set the country code in app_control so because country_check may need it
	# Yeah it's kinda a hack.
	app_control::set_val country_code $country_code
	set ip_country [OB::country_check::get_cust_country $ipaddr]

	# Check whether ip-address is allowed by the admin user or country is banned
	set block [OB::AUTHENTICATE::check_country_and_ip "REG" $ipaddr $ip_country]

	if {$block} {
		tb_reg_err_add  "Country Code $country_code is restricted from registering"
		return 0
	}
	return 1
}

##########################
proc chk_pin {pin1 pin2 {min 6} {max 8}} {
##########################
	variable BAD_PINS

	if {$pin1 != $pin2} {
		tb_reg_err_add [format "PINS do not match"]
		return 0
	}

	#check not empty
	if {$pin1 == ""} {
		tb_reg_err_add [format "PIN cannot be empty"]
		return 1
	}

	#make sure only digits
	if {![regexp {^[0-9]+$} $pin1]} {
		tb_reg_err_add [format "Only numeric characters permitted in the PIN."]
		return 0
	}

	if {[lsearch $BAD_PINS [string toupper $pin1]] >= 0} {
		tb_reg_err_add [format "That PIN is too easy to guess"]
		return 0
	}

	if {[string length $pin1] < $min} {
		tb_reg_err_add "PIN too short"
		return 0
	}

	if {[string length $pin1] > $max} {
		tb_reg_err_add "PIN too long"
		return 0
	}

	return 1
}


###########################################
proc chk_dob {dob_year dob_month dob_day} {
###########################################
# -----------------------------------------------------------------
# given a year and month check that the customer
# is over 18, return their dob as an informix datetime, year to day
# -----------------------------------------------------------------

	# ensure all preceding zeros are removed
	set dob_month [string trimleft $dob_month 0]
	set dob_year  [string trimleft $dob_year 0]
	set dob_day   [string trimleft $dob_day 0]


	# check it's a valid date...
	if {[days_in_month $dob_month $dob_year]<$dob_day} {
		tb_reg_err_add [format "Your date of birth is not a valid date"]
	}

	# now check they are over 18
	# get current day,month,year
	set secs [clock seconds]
	set dt   [clock format $secs -format "%Y-%m-%d"]

	foreach {y m d} [split $dt -] {
		set curr_year  [string trimleft $y 0]
		set curr_month [string trimleft $m 0]
		set curr_day   [string trimleft $d 0]
	}

	set year_diff [expr $curr_year - $dob_year]
	OT_LogWrite 9 "year_diff=$year_diff"

	set dob "$dob_year-[format %02d $dob_month]-[format %02d $dob_day]"

	OT_LogWrite 9 "dob=$dob"
	OT_LogWrite 9 "curr=$curr_year-[format %02d $curr_month]"
	OT_LogWrite 9 "-[format %02d $curr_day]"

	if {($year_diff < 18) ||
		(($year_diff == 18) && ($curr_month < $dob_month)) ||
		(($year_diff == 18) && ($curr_month == $dob_month) && ($curr_day < $dob_day))
	} {
		tb_reg_err_add [format "We are unable to register you as your date of birth indicates that you are under 18 years old"]
	}

	return $dob
}

############################
proc chk_date {date field} {
############################

	OT_LogWrite 1 "%$%$% chk_date: $date $field"

	# check date has the correct number of characters
	if {[string length $date] != 8} {
		tb_reg_err_add "$field format should be DDMMYYYY"
		return 0
	}

	# make sure only digits
	if {![regexp {^[0-9]+$} $date]} {
		tb_reg_err_add "Only numeric characters permitted in $field."
		return 0
	}

	# make sure it is a valid date
	set day [string range $date 0 1]
	set month [string range $date 2 3]
	set year [string range $date 4 7]

	# remove any preceding zeros - no octals here thank you
	set day [string trimleft $day 0]
	set month [string trimleft $month 0]
	set year [string trimleft $year 0]

	OT_LogWrite 2 "day is $day, month is $month.";

	# catch any errors here incase punter trys months 00 or too large months
	if [catch {set days_in_month [days_in_month $month $year]} msg] {
		tb_reg_err_add "$field is not a valid date."
		return 0
	}

	if {$days_in_month < $day} {
		tb_reg_err_add "$field is not a valid date."
		return 0
	}

	return 1
}


####################################
proc set_pref {cust_id pref cvalue} {
####################################
#
# sets a customer pref
#
	if {$cvalue == ""} {
		if [catch {tb_db::tb_exec_qry pref_delete $cust_id $pref} msg] {
			OT_LogWrite 1 "failed to delete pref: $msg"
		}
	} else {

		# check if an entry already exists
		set result [get_pref $cust_id $pref]

		# set the query accordingly
		if {$result == ""} {
			set qry "pref_insert"
		} else {
			set qry "pref_update"
		}

		# run the query
		if [catch {tb_db::tb_exec_qry $qry $cvalue $pref $cust_id} msg] {
			OT_LogWrite 1 "failed to insert/update pref: $msg"
		}
	}
}

####################################
proc get_pref {cust_id pref} {
####################################
#
# retrieves a customer pref
#
	if [catch {set rs [tb_db::tb_exec_qry get_cust_pref $cust_id $pref]} msg] {
		return ""
	}

	if {[db_get_nrows $rs] != 1} {
		return ""
	}

	set c_val [db_get_col $rs 0 pref_cvalue]
	db_close $rs

	return $c_val
}


# Get the account ID for a customer.
#
#   cust_id  - The customer's ID.
#   returns  - The account ID.
#   throws   - DB errors.
#
proc get_acct_id {cust_id} {

	if {![string is integer -strict $cust_id]} {
		error "expected integer, got \"$cust_id\""
	}

	set rs [tb_db::tb_exec_qry tb_reg_acct_id $cust_id]

	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set acct_id [db_get_col $rs acct_id]
	}

	db_close $rs

	if {$nrows != 1} {
		error "expected one row, got $nrows rows"
	}

	return $acct_id
}

##############################################################################
# Procedure :   ins_cust_mail - copied from bluesq internet init.tcl
##############################################################################
proc ins_cust_mail { cust_mail_type cust_id ref_id} {

	db_store_qry ins_cust_mail {
			execute procedure pInsCustMail (
					p_cust_mail_type = ?,
						p_cust_id = ?,
				p_ref_id = ?
		)
	}

		if [catch {set rs [db_exec_qry ins_cust_mail $cust_mail_type $cust_id $ref_id]} msg] {
		   OT_LogWrite 2 "\n****\n**** Unable to insert email:$msg ****\n****"
		return
	}

		set cust_mail_id [db_get_coln $rs 0 0]
		if { $cust_mail_id == -1 } {
			OT_LogWrite 2 "\n****\n**** Failed to create cust_mail - cust_mail_type $cust_mail_type maybe be turned off. ****\n****"
	} else {
		OT_LogWrite 2 "Inserted email $cust_mail_id"
	  }
}



# Check for external system promo
#
#    cust_id     - customer identifier
#    promo_code  - the promo code
#
proc _check_ext_promo { cust_id promo_code } {

	if [catch {set rs [tb_db::tb_exec_qry get_ext_promo $promo_code]} msg] {
		OT_LogWrite 1 "Failed to retrieve promo codes: $msg"
		tb_reg_err_add  "Failed to check external system promo codes"
	} else {

		set nrows [db_get_nrows $rs]

		if {$nrows} {

			set group_desc [db_get_col $rs 0 desc]

			if {$group_desc == [OT_CfgGet XSYS_HOST_NETREFER_GROUP NetRefer]} {

				if [catch {tb_db::tb_exec_qry ins_netrefer_tag $cust_id $promo_code} msg] {
					OT_LogWrite 1 "Failed to insert netrefer tag: $msg"
					tb_reg_err_add  "Failed to insert netrefer tag"
				}
			}
		}
		db_close $rs
	}

}

#
# Initialise this file
#
init_tb_reg

# Close Registration Namespace
}

