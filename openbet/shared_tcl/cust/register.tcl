# $Id: register.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2007 Orbis Technology Ltd.All rights reserved.
#
# Handle customer/user registration.
# Provides an interface to customer registration data.
#
# Configuration:
#
# CUST_REG_UPD_IDX  update customer indexed ids - (1)
#
# Synopsis:
#     package require cust_reg ?4.5?
#
# Procedures:
#    ob_reg::init           one time initialisation
#    ob_reg::add            add/set data
#    ob_reg::get            get data
#    ob_reg::get_all        get all the defined data
#    ob_reg::get_err        get error list
#    ob_reg::load           load registration details
#    ob_reg::insert         insert a new customer
#    ob_reg::update         update registration details
#

package provide cust_reg 4.5



# Dependencies
#
package require util_log      4.5
package require util_db       4.5
package require util_crypt    4.5
package require util_validate 4.5
package require cust_pref     4.5
package require cust_login    4.5
package require cust_util     4.5
package require util_appcontrol



# Variables
#
namespace eval ob_reg {

	variable CFG
	variable REG
	variable DATA
	variable INIT
	variable ERR_CODE
	variable DATA_NAME

	# current request number
	set REG(req_no) ""

	# allowable data names & types
	# - list indicates - type default
	# - where type     - I integer, T text, L login, IP ip-addr, D date,
	#                    DOB dob, E email, M money, SI signed integer
	array set DATA_NAME \
	    [list cust_id       [list I   ""]\
	        source          [list T   I]\
	        product_source  [list T   ""]\
	        aff_id          [list SI  "-1"]\
	        aff_asset_id    [list I   ""]\
	        username        [list L   ""]\
	        password        [list L   ""]\
	        vfy_password    [list L   ""]\
	        nickname        [list L   ""]\
	        acct_no         [list L   ""]\
	        bib_pin         [list L   ""]\
	        vfy_bib_pin     [list L   ""]\
	        lang            [list T   ""]\
	        ccy_code        [list T   ""]\
	        origin_code     [list T   ""]\
	        country_code    [list T   ""]\
	        acct_type       [list T   "DEP"]\
	        reg_status      [list T   "A"]\
	        ipaddr          [list IP  ""]\
	        challenge_1     [list T   ""]\
	        response_1      [list T   ""]\
	        challenge_2     [list T   ""]\
	        response_2      [list T   ""]\
	        sig_date        [list D   ""]\
	        title           [list T   ""]\
	        fname           [list T   ""]\
	        lname           [list T   ""]\
	        dob             [list DOB ""]\
	        addr_street_1   [list T   ""]\
	        addr_street_2   [list T   ""]\
	        addr_street_3   [list T   ""]\
	        addr_street_4   [list T   ""]\
	        addr_city       [list T   ""]\
	        addr_state_id   [list T   ""]\
	        addr_country    [list T   ""]\
	        postcode        [list T   ""]\
	        telephone       [list T   ""]\
	        office          [list T   ""]\
	        mobile          [list T   ""]\
	        mobile_pin      [list L   ""]\
	        vfy_mobile_pin  [list L   ""]\
	        email           [list E   ""]\
	        fax             [list T   ""]\
	        contact_ok      [list T   ""]\
	        contact_how     [list T   ""]\
	        ptnr_contact_ok [list T   ""]\
	        mkt_contact_ok  [list T   ""]\
	        hear_about      [list T   ""]\
	        hear_about_txt  [list T   ""]\
	        gender          [list T   ""]\
	        itv_email       [list E   ""]\
	        temp_pwd        [list T   "N"]\
	        sort            [list T   "R"]\
	        reg_combi       [list T   ""]\
	        salutation      [list T   ""]\
	        occupation      [list T   ""]\
	        code            [list T   "N"]\
	        code_txt        [list T   ""]\
	        elite           [list T   "N"]\
	        min_repay       [list M   "0"]\
	        min_funds       [list M   "0"]\
	        min_settle      [list M   "0"]\
	        credit_limit    [list M   "0"]\
	        pay_pct         [list I   "100"]\
	        reg_stage       [list I   "1"]\
	        reg_section     [list I   "1"]\
	        settle_type     [list T   "N"]\
	        fave_fb_team    [list T   ""]\
	        cd_grp_id       [list I   ""]\
	        partnership     [list T   ""]\
	        status          [list T   "A"]\
	        pay_for_ap      [list T   "Y"]\
	        price_type      [list T   "DECIMAL"]\
	        ins_login_act   [list T   "Y"]]


	# pInsCustomer stored procedure error code translations
	array set ERR_CODE \
	    [list 2401 [list [list username] OB_ERR_CUST_DUP_USERNAME username]\
	          2402 [list [list acct_no] OB_ERR_CUST_DUP_ACCT_NO  acct_no]\
	          2403 [list [list unspecified] OB_ERR_CUST_BAD_REG_COMBI]\
	          2404 [list [list unspecified] OB_ERR_CUST_INSERT]\
	          2405 [list [list unspecified] OB_ERR_CUST_ADD]\
	          2406 [list [list password vfy_password] OB_ERR_CUST_PWD_LEN]\
	          2407 [list [list username] OB_ERR_VAL_BAD_UNAME_FORMAT]\
	          2408 [list [list password vfy_password] OB_ERR_VAL_BAD_PWD_FORMAT]\
	          2409 [list [list bib_pin vfy_bib_pin] OB_ERR_VAL_BAD_PIN_FORMAT]\
	          2410 [list [list sig_date] OB_ERR_CUST_BAD_SIG_DATE]\
	          2412 [list [list username acct_no] OB_ERR_CUST_NO_UNAME_ACCTNO]\
	          2413 [list [list username] OB_ERR_CUST_IDENT_UNAME_ACCTNO]\
	          2414 [list [list username] OB_ERR_CUST_UNAME_START_ZERO]\
	          2415 [list [list unspecified] OB_ERR_CUST_REGNOT_FOUND]\
	          2416 [list [list unspecified] OB_ERR_CUST_UPD_ONEROW]\
	          2417 [list [list mobile iddcode] OB_ERR_CUST_TEXT_BETTING_DUP_MOBILE]\
	          2418 [list [list email] OB_ERR_CUST_DUP_EMAIL]]

	# init flag
	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------


# One time initialisation.
#
proc ob_reg::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_cust::init
	ob_crypt::init
	ob_cpref::init
	ob_login::init

	ob_log::write DEBUG {REG: init}

	# get configuration
	set CFG(pwd_salt)                   [OT_CfgGet CUST_PWD_SALT 0]
	set CFG(reg_upd_idx)                [OT_CfgGet CUST_REG_UPD_IDX 1]
	set CFG(text_betting)               [OT_CfgGet TEXT_BETTING N]
	set CFG(cust_pwd_case_insensitive)  [OT_CfgGet CUST_PWD_CASE_INSENSITIVE 0]
	set CFG(cust_acct_no_format)        [OT_CfgGet CUST_ACCT_NO_FORMAT A]

	# prepare SQL queries
	_prepare_qrys

	# init
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_reg::_prepare_qrys args {

	# insert a new customer
	ob_db::store_qry ob_reg::insert {
		execute procedure pInsCustomer (
				p_source = ?,
				p_product_source = ?,
				p_aff_id = ?,
				p_username = ?,
				p_password = ?,
				p_password_salt = ?,
				p_nickname = ?,
				p_acct_no = ?,
				p_bib_pin = ?,
				p_lang = ?,
				p_ccy_code = ?,
				p_origin_code = ?,
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
				p_addr_state_id = ?,
				p_addr_country = ?,
				p_postcode = ?,
				p_telephone = ?,
				p_office = ?,
				p_mobile = ?,
				p_mobile_pin = ?,
				p_email = ?,
				p_fax = ?,
				p_contact_ok = ?,
				p_contact_how = ?,
				p_ptnr_contact_ok = ?,
				p_hear_about = ?,
				p_hear_about_txt = ?,
				p_gender = ?,
				p_itv_email = ?,
				p_temp_pwd = ?,
				p_sort = ?,
				p_reg_combi = ?,
				p_salutation = ?,
				p_occupation = ?,
				p_code = ?,
				p_code_txt = ?,
				p_elite = ?,
				p_min_repay = ?,
				p_min_funds = ?,
				p_min_settle = ?,
				p_credit_limit = ?,
				p_pay_pct = ?,
				p_reg_stage = ?,
				p_reg_section = ?,
				p_settle_type = ?,
				p_price_type = ?,
				p_transactional = 'N',
				p_fave_fb_team = ?,
				p_cd_grp_id = ?,
				p_partnership = ?,
				p_status = ?,
				p_aff_asset_id = ?,
				p_text_betting = ?,
				p_locale = ?,
				p_acct_no_format = ?)
	}

	# update customer registration details
	ob_db::store_qry ob_reg::update {
		execute procedure pUpdCustomer (
				p_cust_id = ?,
				p_nickname = ?,
				p_dob = ?,
				p_title = ?,
				p_fname = ?,
				p_lname = ?,
				p_addr_street_1 = ?,
				p_addr_street_2 = ?,
				p_addr_street_3 = ?,
				p_addr_street_4 = ?,
				p_addr_city = ?,
				p_addr_state_id = ?,
				p_addr_country = ?,
				p_country_code = ?,
				p_postcode = ?,
				p_telephone = ?,
				p_mobile = ?,
				p_office = ?,
				p_email = ?,
				p_fax = ?,
				p_contact_ok = ?,
				p_contact_how = ?,
				p_ptnr_contact_ok = ?,
				p_mkt_contact_ok = ?,
				p_itv_email = ?,
				p_salutation = ?,
				p_gender = ?,
				p_occupation = ?,
				p_code = ?,
				p_code_txt = ?,
				p_challenge_1 = ?,
				p_response_1 = ?,
				p_challenge_2 = ?,
				p_response_2 = ?,
				p_text_betting = ?,
				p_mobile_pin = ?,
				p_hear_about = ?,
				p_hear_about_txt = ?,
				p_aff_id = ?,
				p_ins_login_act = ?)
	}

	# Update customer details if they are a CDT customer
	ob_db::store_qry ob_reg::update_cdt {
		execute procedure pUpdCustomer (
				p_cust_id = ?,
				p_nickname = ?,
				p_dob = ?,
				p_title = ?,
				p_fname = ?,
				p_lname = ?,
				p_addr_state_id = ?,
				p_addr_country = ?,
				p_country_code = ?,
				p_telephone = ?,
				p_mobile = ?,
				p_office = ?,
				p_email = ?,
				p_fax = ?,
				p_contact_ok = ?,
				p_contact_how = ?,
				p_ptnr_contact_ok = ?,
				p_mkt_contact_ok = ?,
				p_itv_email = ?,
				p_salutation = ?,
				p_gender = ?,
				p_occupation = ?,
				p_code = ?,
				p_code_txt = ?,
				p_challenge_1 = ?,
				p_response_1 = ?,
				p_challenge_2 = ?,
				p_response_2 = ?,
				p_text_betting = ?,
				p_mobile_pin = ?,
				p_hear_about = ?,
				p_hear_about_txt = ?,
				p_aff_id = ?,
				p_ins_login_act = ?)
	}

	# get registration details
	ob_db::store_qry ob_reg::get {
		select
			r.nickname,
			r.title,
			r.fname,
			r.lname,
			r.dob as inf_dob,
			r.addr_street_1,
			r.addr_street_2,
			r.addr_street_3,
			r.addr_street_4,
			r.addr_city,
			r.addr_state_id,
			r.addr_country,
			r.addr_postcode as postcode,
			r.telephone,
			r.mobile,
			c.mobile_pin,
			r.office,
			r.email,
			r.fax,
			r.contact_ok,
			r.contact_how,
			r.ptnr_contact_ok,
			r.mkt_contact_ok,
			r.itv_email,
			r.salutation,
			r.gender,
			r.occupation,
			r.code,
			r.code_txt,
			r.challenge_1,
			r.response_1,
			r.challenge_2,
			r.response_2,
			c.country_code
		from
			tCustomerReg r,
			tCustomer c
		where
			c.cust_id = ?
		and r.cust_id = c.cust_id
	}
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache was reset, zero if
#             cache is up to date in scope of the request
#
proc ob_reg::_auto_reset args {

	variable REG
	variable DATA

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$REG(req_no) != $id} {
		catch {unset REG}
		catch {unset DATA}
		set REG(req_no) $id
		set REG(errors) [list]
		set REG(error_fields) [list]
		ob_log::write DEV {REG: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}



#--------------------------------------------------------------------------
# Get/Set Data
#--------------------------------------------------------------------------

# Set/Add registration data.
# A tcl error will be generated if an unknown data name.
#
# NB: The procedure does not get the registration parameters from a
# HTML/WML form. It is caller's responsibility to get and supply the
# details.
#
#   name  - data name (must match an attribute name)
#   value - value
#
proc ob_reg::add { name value } {

	variable DATA
	variable DATA_NAME

	if {![info exists DATA_NAME($name)]} {
		error "invalid name - $name"
	}

	# reset data?
	_auto_reset

	# set the data
	set DATA($name) $value
}



# Get previously set registration data value.
#
#   name    - data name
#   returns - registration data value, or an empty string if the data is not
#             defined or an unknown name
#
proc ob_reg::get { name } {

	variable DATA

	# reset data?
	_auto_reset

	# get data
	if {[info exists DATA($name)]} {
		return $DATA($name)
	} else {
		return ""
	}
}



# Get all the previously set registration data.
#
#   returns - array of data
#             ARRAY(names)  contains a list of all previously set
#                           registration data names/columns
#             ARRAY(name_1) value_1
#             ARRAY(name_n) value_n
#
proc ob_reg::get_all args {

	variable DATA

	# reset data?
	_auto_reset

	set D(names) ""
	foreach n [array names DATA] {
		if {$DATA($n) != ""} {
			lappend D(names) $n
			set D($n) $DATA($n)
		}
	}

	return [array get D]
}



# Load registration details into the package cache.
# Only loads information which can be used in an update.
#
#   cust_id - customer identifier
#   returns - error status (OB_OK denotes success)
#             any error is added to the package error list
#
proc ob_reg::load { cust_id } {

	variable REG
	variable DATA

	ob_log::write DEBUG {REG: load cust_id=$cust_id}

	# force a reset
	set REG(req_no) ""
	_auto_reset

	# check supplied cust_id
	set status [_chk_cust $cust_id]
	if {$status != "OB_OK"} {
		return $status
	}

	# load
	if {[catch {set rs [ob_db::exec_qry ob_reg::get $cust_id]} msg]} {
		return [_add_err [list unspecified] OB_ERR_CUST_GET_FAILED $msg]
	}
	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		return [_add_err [list unspecified] OB_ERR_CUST_REGNOT_FOUND]
	}

	foreach c [db_get_colnames $rs] {
		set DATA($c) [db_get_col $rs 0 $c]
	}
	set DATA(cust_id) $cust_id
	ob_db::rs_close $rs

	# When we validate the dob in ob_reg::_chk we expect it in the following format:
	#   ddmmyyyy
	# so we set up two fields:
	#   DATA(inf_dob) in the Informix format (retrieved by the query), and
	#   DATA(dob) which we set here
	#
	if {$DATA(inf_dob) != ""} {
		set DATA(dob) "[string range $DATA(inf_dob) 8 9][string range $DATA(inf_dob) 5 6][string range $DATA(inf_dob) 0 3]"
	}

	# log the loaded data
	_log

	return OB_OK
}



#--------------------------------------------------------------------------
# Insert/Update
#--------------------------------------------------------------------------

# Insert a new customer.
#
# Checks the previously set data against the associated data types and sets any
# undefined data with it's default. It is caller's responsibility to define
# which data is mandatory, e.g. last-name, first-name, etc., and perform the
# necessary checks.
#
# Sets the customer preference PAY_FOR_AP and updates the customer indexed
# identifiers.
#
# NB: The procedure does not get the registration parameters from a
# HTML/WML form. It is caller's responsibility to get and supply the
# details.
#
#   in_tran - in transaction flag (default: 0)
#             if non-zero, the caller must begin, rollback & commit
#             if zero, then must be called outside a transaction
#   returns - number of errors, where each error is added to the package
#             error list
#
proc ob_reg::insert { {in_tran 0} } {

	variable CFG
	variable REG
	variable DATA

	ob_log::write DEBUG {REG: insert in_tran=$in_tran}

	# reset data
	_auto_reset

	# check data
	set err_count [_chk I]
	if {$err_count} {
		return $err_count
	}
	# encrypt pwd and/or pin
	set DATA(enc_pwd) ""
	set DATA(enc_pin) ""
	set DATA(enc_mobile_pin) ""

	if {$CFG(pwd_salt)} {
		set DATA(password_salt) [ob_crypt::generate_salt]
	} else {
		set DATA(password_salt) ""
	}

	if {$DATA(password) != ""} {

		if {$CFG(cust_pwd_case_insensitive)} {
			set DATA(password) [string toupper $DATA(password)]
		}

		set DATA(enc_pwd) [ob_crypt::encrypt_password \
		                      $DATA(password) \
		                      $DATA(password_salt)]
	}
	if {$DATA(bib_pin) != ""} {
		set DATA(enc_pin) [ob_crypt::encrypt_pin $DATA(bib_pin)]
	}
	if {$DATA(mobile_pin) != ""} {
		set DATA(enc_mobile_pin) [ob_crypt::encrypt_password \
		                             $DATA(mobile_pin) \
		                             $DATA(password_salt)]
	}


	set aff_id [reqGetArg aff_id]
	if {$aff_id != ""} {
		set DATA(aff_id) $aff_id
	}

	# log data (excluding encrypted password/pin)
	_log

	# start insert
	if {!$in_tran} {
		ob_db::begin_tran
	}

	# Is the locale configured.
	if {[lsearch [OT_CfgGet LOCALE_INCLUSION ""] REG] > -1} {
		set locale [app_control::get_val locale]
	} else {
		set locale ""
	}

	# insert
	if {[catch {
		set rs [ob_db::exec_qry ob_reg::insert \
		        $DATA(source) \
		        $DATA(product_source) \
		        $DATA(aff_id) \
		        $DATA(username) \
		        $DATA(enc_pwd) \
		        $DATA(password_salt) \
		        $DATA(nickname) \
		        $DATA(acct_no) \
		        $DATA(enc_pin) \
		        $DATA(lang) \
		        $DATA(ccy_code) \
		        $DATA(origin_code) \
		        $DATA(country_code) \
		        $DATA(acct_type) \
		        $DATA(reg_status) \
		        $DATA(ipaddr) \
		        $DATA(challenge_1) \
		        $DATA(response_1) \
		        $DATA(challenge_2) \
		        $DATA(response_2) \
		        $DATA(sig_date) \
		        $DATA(title) \
		        $DATA(fname) \
		        $DATA(lname) \
		        $DATA(inf_dob) \
		        $DATA(addr_street_1) \
		        $DATA(addr_street_2) \
		        $DATA(addr_street_3) \
		        $DATA(addr_street_4) \
		        $DATA(addr_city) \
		        $DATA(addr_state_id) \
		        $DATA(addr_country) \
		        $DATA(postcode) \
		        $DATA(telephone) \
		        $DATA(office) \
		        $DATA(mobile) \
		        $DATA(enc_mobile_pin) \
		        $DATA(email) \
		        $DATA(fax) \
		        $DATA(contact_ok) \
		        $DATA(contact_how) \
		        $DATA(ptnr_contact_ok) \
		        $DATA(hear_about) \
		        $DATA(hear_about_txt) \
		        $DATA(gender) \
		        $DATA(itv_email) \
		        $DATA(temp_pwd) \
		        $DATA(sort) \
		        $DATA(reg_combi) \
		        $DATA(salutation) \
		        $DATA(occupation) \
		        $DATA(code) \
		        $DATA(code_txt) \
		        $DATA(elite) \
		        $DATA(min_repay) \
		        $DATA(min_funds) \
		        $DATA(min_settle) \
		        $DATA(credit_limit) \
		        $DATA(pay_pct) \
		        $DATA(reg_stage) \
		        $DATA(reg_section) \
		        $DATA(settle_type) \
		        $DATA(price_type) \
		        $DATA(fave_fb_team) \
		        $DATA(cd_grp_id) \
		        $DATA(partnership) \
		        $DATA(status) \
		        $DATA(aff_asset_id) \
		        $CFG(text_betting) \
		        $locale \
				$CFG(cust_acct_no_format)]
	} msg]} {

		if {!$in_tran} {
			ob_db::rollback_tran
		}
		_get_err_code $msg REG
		return [llength $REG(errors)]
	}

	# get new customer id
	set DATA(cust_id) [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	# set customer preferences
	ob_cpref::set_value PAY_FOR_AP $DATA(pay_for_ap) $DATA(cust_id) C 0 1

	# update cust indexed ids
	if {$CFG(reg_upd_idx)} {
		ob_cust::upd_idx $DATA(cust_id) 1
	}

	# commit insert
	if {!$in_tran} {
		ob_db::commit_tran
	}

	ob_log::write INFO {REG: insert cust_id=$DATA(cust_id)}
	return 0
}



# Update customer registration details.
#
# Checks the previously set data against the associated data types and sets any
# undefined data with it's default. It is caller's responsibility to define
# which data is mandatory, e.g. last-name, first-name, etc., and perform the
# necessary checks. It is advised that ::load is called prior to updating
# information, only changing the required data via ::add.
#
# Updates the customer indexed identifiers.
#
# NB: The procedure does not get the registration parameters from a
# HTML/WML form. It is caller's responsibility to get and supply the
# details.
#
#   cust_id - customer identifier
#   in_tran - in transaction flag (default: 0)
#             if non-zero, the caller must begin, rollback & commit
#             if zero, then must be called outside a transaction
#   returns - number of errors, where each error is added to the package
#             error list
#
proc ob_reg::update { cust_id {in_tran 0} } {

	variable CFG
	variable REG
	variable DATA

	ob_log::write DEBUG {REG: update cust_id=$cust_id in_tran=$in_tran}

	# reset data
	_auto_reset
	set DATA(cust_id) $cust_id

	# check supplied cust_id
	set status [_chk_cust $cust_id]
	if {$status != "OB_OK"} {
		return [llength $REG(errors)]
	}

	# check data
	set err_count [_chk U]
	if {$err_count} {
		return $err_count
	}

	# encrypt pwd
	set DATA(enc_pwd) ""

	if {$DATA(password) != ""} {

		if {$CFG(cust_pwd_case_insensitive)} {
			set DATA(password) [string toupper $DATA(password)]
		}

		set password_salt [ob_login::get password_salt]
		set DATA(enc_pwd) [ob_crypt::encrypt_password \
		                      $DATA(password) \
		                      $password_salt]
	}

	# log data (excluding encrypted password)
	_log

	# start update
	if {!$in_tran} {
		ob_db::begin_tran
	}

	# update. For some channels CDT customers are not allowed to update their address details
	if {[OT_CfgGet STOP_ADDR_UPDATE_CDT 0]} {
		if {[catch {
			set rs [ob_db::exec_qry ob_reg::update_cdt \
				$DATA(cust_id)\
				$DATA(nickname)\
				$DATA(inf_dob)\
				$DATA(title)\
				$DATA(fname)\
				$DATA(lname)\
				$DATA(addr_state_id)\
				$DATA(addr_country)\
				$DATA(country_code)\
				$DATA(telephone)\
				$DATA(mobile)\
				$DATA(office)\
				$DATA(email)\
				$DATA(fax)\
				$DATA(contact_ok)\
				$DATA(contact_how)\
				$DATA(ptnr_contact_ok)\
				$DATA(mkt_contact_ok)\
				$DATA(itv_email)\
				$DATA(salutation)\
				$DATA(gender)\
				$DATA(occupation)\
				$DATA(code)\
				$DATA(code_txt)\
				$DATA(challenge_1)\
				$DATA(response_1)\
				$DATA(challenge_2)\
				$DATA(response_2)\
				$CFG(text_betting)\
				$DATA(mobile_pin)\
				$DATA(hear_about)\
				$DATA(hear_about_txt)\
				$DATA(aff_id)\
				$DATA(ins_login_act)]
		} msg]} {

			if {!$in_tran} {
				ob_db::rollback_tran
			}
			_get_err_code $msg UPD

			return [llength $REG(errors)]
		}
	} else {
		if {[catch {
			set rs [ob_db::exec_qry ob_reg::update \
				$DATA(cust_id)\
				$DATA(nickname)\
				$DATA(inf_dob)\
				$DATA(title)\
				$DATA(fname)\
				$DATA(lname)\
				$DATA(addr_street_1)\
				$DATA(addr_street_2)\
				$DATA(addr_street_3)\
				$DATA(addr_street_4)\
				$DATA(addr_city)\
				$DATA(addr_state_id)\
				$DATA(addr_country)\
				$DATA(country_code)\
				$DATA(postcode)\
				$DATA(telephone)\
				$DATA(mobile)\
				$DATA(office)\
				$DATA(email)\
				$DATA(fax)\
				$DATA(contact_ok)\
				$DATA(contact_how)\
				$DATA(ptnr_contact_ok)\
				$DATA(mkt_contact_ok)\
				$DATA(itv_email)\
				$DATA(salutation)\
				$DATA(gender)\
				$DATA(occupation)\
				$DATA(code)\
				$DATA(code_txt)\
				$DATA(challenge_1)\
				$DATA(response_1)\
				$DATA(challenge_2)\
				$DATA(response_2)\
				$CFG(text_betting)\
				$DATA(mobile_pin)\
				$DATA(hear_about)\
				$DATA(hear_about_txt)\
				$DATA(aff_id)\
				$DATA(ins_login_act)]
		} msg]} {

			if {!$in_tran} {
				ob_db::rollback_tran
			}
			_get_err_code $msg UPD

			return [llength $REG(errors)]
		}
	}

	# update cust indexed ids
	if {$CFG(reg_upd_idx)} {
		ob_cust::upd_idx $DATA(cust_id) 1
	}

	# commit update
	if {!$in_tran} {
		ob_db::commit_tran
	}

	ob_log::write INFO {REG: update cust_id=$cust_id}
	return 0
}



#--------------------------------------------------------------------------
# Validation
#--------------------------------------------------------------------------

# Private procedure to check previously set registration data.
# Checks the data against the set data types. Does not check for mandatory
# data (caller's responsibility)
#
#   action  - action (I - insert or U - update)
#   returns - number of validation errors, where each error is added to
#             the package error list
#
proc ob_reg::_chk { action } {

	variable REG
	variable DATA
	variable DATA_NAME

	# define any unknown data to it's default value
	set names [array names DATA_NAME]
	foreach n $names {
		if {![info exists DATA($n)]} {
			set DATA($n) [lindex $DATA_NAME($n) 1]
		}
	}
	if {$DATA(reg_combi) == ""} {
		set DATA(reg_combi) $DATA(source)
	}
	set DATA(inf_dob) ""

	# check all data
	foreach n $names {

		# ignore empty data
		# - some check procs, will fail when supply an empty string
		if {$DATA($n) == ""} {
			continue
		}

		set code OB_OK
		switch -- [lindex $DATA_NAME($n) 0] {
			"I"   { set code [ob_chk::integer $DATA($n)] }
			"SI"  { set code [ob_chk::signed_integer $DATA($n)] }
			"T"   { set code [ob_chk::optional_txt $DATA($n)] }
			"IP"  { set code [ob_chk::ipaddr $DATA($n)] }
			"D"   { set code [ob_chk::date $DATA($n)] }
			"E"   { set code [ob_chk::email $DATA($n) N]}
			"M"   { set code [ob_chk::money $DATA($n)] }
			"L"   { set code [_chk_login $action $n] }
			"DOB" {
				set y [string range $DATA($n) 4 7]
				set m [string range $DATA($n) 2 3]
				set d [string range $DATA($n) 0 1]
				set code [ob_chk::dob $y $m $d]
				if {$code == "OB_OK"} {
					set DATA(inf_dob) "$y-$m-$d"
				}
			}
			default { error "unknown data type ($n $DATA_NAME($n))" }
		}

		# add any errors
		if {$code != "OB_OK"} {
			_add_err $n $code $n
		}
	}

	# check insert data
	if {$action == "I"} {

		# check login details combinations
		if {$DATA(username) == "" && $DATA(acct_no) == ""} {
			_add_err [list username acct_no] OB_ERR_CUST_NO_UNAME_ACCTNO
		}
		if {$DATA(password) == "" && $DATA(bib_pin) == "" \
				&& ![OT_CfgGet ALLOW_NO_PASSWORD 0]} {
			_add_err [list password vfy_password bib_pin vfy_bib_pin] \
			         OB_ERR_CUST_NO_PWD_PIN
		}

		# do we allow 7 digit usernames?
		if { [OT_CfgGet DISABLE_7DIGITS_USERNAMES 0] } {
			if { [regexp {^\d{7}$} $DATA(username)] } {
				_add_err [list username] OB_ERR_VAL_BAD_UNAME_FORMAT
			}
		}

		# check intro source
		if {$DATA(hear_about) == "OTHR" && $DATA(hear_about_txt) == ""} {
			_add_err [list hear_about hear_about_txt] \
			         OB_ERR_CUST_NO_HEAR_ABOUT_TXT
		}
	}

	return [llength $REG(errors)]
}



# Private procedure to check login data.
#
#   action  - action (I - insert or U - update)
#   name    - data name
#   returns - error/status code (OB_OK indicates success)
#
proc ob_reg::_chk_login { action name } {

	variable DATA

	if {$action == "U"} {
		return [ob_chk::optional_txt $DATA($name)]
	} else {
		switch -- $name {
			"username" -
			"acct_no" {
				return [ob_chk::optional_txt $DATA($name)]
			}

			"password" {
				return [ob_chk::pwd $DATA(password) \
				                    $DATA(vfy_password) \
				                    $DATA(username)]
			}

			"bib_pin" {
				return [ob_chk::pin $DATA(bib_pin) \
				    $DATA(vfy_bib_pin) 0 0]
			}

			"mobile_pin" {
				if {$DATA(mobile_pin)     == "" &&
				    $DATA(vfy_mobile_pin) == ""} {
					return "OB_OK"
				} else {
					return [ob_chk::pin $DATA(mobile_pin) \
					    $DATA(vfy_mobile_pin) 4 4]
				}
			}

			default {
				return OB_OK
			}
		}
	}
}



#--------------------------------------------------------------------------
# Error handling
#--------------------------------------------------------------------------

# Get the list of error[s].
#
#   returns - list of errors, or an empty list if no errors
#             format {{error-code args} {error-code args} ...}
#
proc ob_reg::get_err args {

	variable REG

	# reset data
	_auto_reset

	return $REG(errors)
}



# Get the list of error field[s].
#
#   returns - list of fields having triggered errors, or an empty list if no
#             errors
#
proc ob_reg::get_err_field args {

	variable REG

	# reset data
	_auto_reset

	return $REG(error_fields)
}



# Private procedure to add an error.
#
#   fields  - list of registration fields triggering the error.
#             N.B. if not related to a specific field, use [list unspecified]
#   code    - error code (i.e. translation message)
#   name    - attribute name (error args)
#   returns - error code
#
proc ob_reg::_add_err { fields code {name ""} } {

	variable REG

	ob_log::write ERROR {REG: $code $name}
	lappend REG(errors) [list $code $name]

	foreach field $fields {
		if {[lsearch $REG(error_fields) $field] == -1} {
			lappend REG(error_fields) $field
		}
	}

	return $code
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Private procedure to log the contents of the DATA array.
# Excludes empty elements, and unencrypted password & pin
#
proc ob_reg::_log args {

	variable DATA

	set sym_level [ob_log::get_sym_level]
	if {$sym_level == "DEV" || $sym_level == "DEBUG"} {
		foreach name [lsort [array names DATA]] {
			if {$DATA($name) != ""} {
				if {![regexp {(password|bib_pin)} $name]} {
					ob_log::write DEBUG {REG: $name=$DATA($name)}
				}
			}
		}
	}
}



# Private procedure to get an error code from a stored procedure exception.
# Adds the error code, and extra arguments, to the package error list.
#
#   msg    - exception message
#   action - action (REG insert or UPD update)
#
proc ob_reg::_get_err_code { msg action } {

	variable DATA
	variable ERR_CODE

	ob_log::write ERROR {REG: $msg}

	if {[regexp {AX([0-9][0-9][0-9][0-9])} $msg all err_code]} {
		if {[info exists ERR_CODE($err_code)]} {
			set a ""
			if {[llength $ERR_CODE($err_code)] == 3} {
				set a $DATA([lindex $ERR_CODE($err_code) 2])
			}
			_add_err [lindex $ERR_CODE($err_code) 0] \
			         [lindex $ERR_CODE($err_code) 1] $a
			return
		}
	}

	_add_err [list unspecified] [format "OB_ERR_CUST_%s_FAILED" $action] $msg
}



# Check the supplied customer identifier and determine if logged in.
#
# Calls the ob_login::is_guest as a precautionary check, as there is
# no guarantee that the caller has performed the verification. Secondly,
# getting the cust_id from the login package does not check the details
# against the database, as cust_id is directly extracted from the cookie.
#
#   cust_id - customer identifier
#   returns - error status (OB_OK denotes non-guest)
#             any error is added to the package error list
#
proc ob_reg::_chk_cust { cust_id } {

	# check customer identifier
	set code [ob_chk::integer $cust_id]
	if {$code != "OB_OK"} {
		return [_add_err [list cust_id] $code cust_id]
	}

	# is logged in and matching customer identifier
	if {[ob_login::is_guest] || [ob_login::get cust_id] != $cust_id} {

		# get the error code and add to internal error list
		set status [ob_login::get login_status]
		if {$status == "" || $status == "OB_OK"} {
			set status OB_ERR_CUST_GUEST
		}
		return [_add_err [list unspecified] $status]
	}

	return OB_OK
}
