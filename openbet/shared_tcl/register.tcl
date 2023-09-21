# $Id: register.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================


# This module is pretty much self contained
# To get it to work...
# 1) In init.tcl (or equivalent) need to import OB_register namespace
#    (remeber to place register.tcl before init.tcl in the
#      config file's sourcing list)
# 2) put a call to init_reg in the main_init function
# 3) set an activator which calls go_register to display the registration page
# 4) set an activator which calls do_registration to process the registration
# 5) config file stuff - can set or unset multi currency etc.
#    pinscustomer will use defaults for missing stuff
# 6) in config file set REG_SUCCESS_ACTION to determine what
#    happens after a successful registration
# 7) in init.tcl need to have line...
#   tpBindTcl ERROR -global {tpBufWrite [join [err_get_list] "<br>\n"]}
#   in function that registers global tcl sites
# 8) include call to err_reset in req_init
# 9) Uses config variable ONE_REG_QUESTION to determine if there are one or two personal questions
#    on the registration form (only 1 if it is true)

package require util_appcontrol

namespace eval OB_register {

namespace export init_reg
namespace export do_registration
namespace export do_currency_drop_down
namespace export do_country_drop_down
namespace export do_lang_drop_down
namespace export do_update_details
namespace export get_cust_details
namespace export go_register
namespace export chk_pin

namespace export set_reg_template
namespace export play_reg_template

variable REG_TEMPLATE
variable DFLT_CCY
variable DFLT_COUNTRY
variable DFLT_LANG

variable BAD_PWDS
set BAD_PWDS {SECRET PASSWORD GAMBLE WAGER PUNTER BOOKIE BOOKMAKER }

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
			  123456 1234567 12345678 }

array set REG_TEMPLATE [list\
	Register    register.html \
	RegSuccess  register_successful.html]

####################
proc init_reg args {
####################

	#
	# Initialise Registration Stuff
	#

	global MULTI_LANG
	global MULTI_CCY
	global MULTI_CNTRY
	global REG_SUCCESS_ACTION
	global ERR_MSG

	set ERR_MSG(PWD_WRONG,en) "Incorrect Username or Password"

	# Get stuff from Config File
	tpSetVar MULTI_LANG  -global [OT_CfgGetTrue MULTI_LANG]
	tpSetVar MULTI_CCY   -global [OT_CfgGetTrue MULTI_CCY]
	tpSetVar MULTI_CNTRY -global [OT_CfgGetTrue MULTI_CNTRY]
	tpSetVar MULTI_LANG  -global 1
	tpSetVar MULTI_CCY   -global 1
	tpSetVar MULTI_CNTRY -global 1

	set REG_SUCCESS_ACTION [OT_CfgGet REG_SUCCESS_ACTION]


	# Prepare Registration Queries
	prep_reg_qrys

	load_dflts
}

####################################
# Override default templates to play
####################################
proc set_reg_template args {

	variable REG_TEMPLATE

	if {[llength $args] == 1} {
		return $REG_TEMPLATE([lindex $args 0])
	} elseif {[llength $args] == 2} {
		set REG_TEMPLATE([lindex $args 0]) [lindex $args 1]
	} else {
		error "usage: set_reg_template key ?file?"
	}
}

#####################################################
# Play template specified in REG_TEMPLATE array
#####################################################
proc play_reg_template {which} {

	variable REG_TEMPLATE

	tpSetVar RegPlayFile $which
	play_file $REG_TEMPLATE($which)
}


####################
proc load_dflts {} {
####################
	variable DFLT_CCY
	variable DFLT_COUNTRY
	variable DFLT_LANG

	if {[catch {set rs [db_exec_qry reg_dflts]} msg]} {
		ob::log::write ERROR {failed to load registration defaults}
		return
	}

	if {[db_get_nrows $rs] == 1} {
		set DFLT_CCY      [db_get_col $rs default_ccy]
		set DFLT_COUNTRY  [db_get_col $rs default_country]
		set DFLT_LANG     [db_get_col $rs default_lang]
	} else {
		ob::log::write ERROR {failed to load registration defaults}
		return
	}

	db_close $rs
}

#########################
proc prep_reg_qrys args {
#########################

	#
	# Prepares Queries to handle registration stuff
	#

	variable regQRY

	# Query to insert customer
	db_store_qry insert_cust_qry {
		execute procedure pinscustomer (
						p_aff_id=?,
						p_username=?,
						p_password=?,
						p_lang=?,
						p_ccy_code =?,
						p_country_code =?,
						p_reg_status=?,
						p_ipaddr=?,
						p_challenge_1=?,
						p_response_1=?,
						p_challenge_2=?,
						p_response_2=?,
						p_title=?,
						p_fname=?,
						p_lname=?,
						p_addr_street_1=?,
						p_addr_street_2=?,
						p_addr_street_3=?,
						p_addr_street_4=?,
						p_addr_city=?,
						p_postcode=?,
						p_telephone=?,
						p_email=?,
						p_itv_email=?,
						p_contact_ok=?,
						p_ptnr_contact_ok=?,
						p_hear_about=?,
						p_hear_about_txt=?,
						p_dob=?,
						p_mobile=?,
						p_source=?,
						p_bib_pin=?,
						p_sig_date=?,
						p_price_type=?,
						p_reg_combi=?,
						p_locale = ?,
						p_acct_no_format = ?
		)
	}

	# Query to update customer
	db_store_qry update_cust_details {
		execute procedure pUpdCustomer (
						p_username=?,
						p_password=?,
						p_title=?,
						p_fname=?,
						p_lname=?,
						p_addr_street_1=?,
						p_addr_street_2=?,
						p_addr_street_3=?,
						p_addr_street_4=?,
						p_addr_city=?,
						p_postcode=?,
						p_telephone=?,
						p_email=?,
						p_itv_email=?,
						p_contact_ok=?,
						p_mobile=?
		)
	}

	# Query to update customer's interactive TV email
	db_store_qry update_cust_itv_email {
		update tcustomerreg
			set itv_email = ?
			where cust_id = (   select cust_id from tcustomer
							    where username = ?      )
	}

	# Query to update customer's pin no
	db_store_qry update_cust_pin {
		update tcustomer
			set bib_pin = ?
			where username = ?
	}

	db_store_qry check_cust_pin {
		select bib_pin from tcustomer
		where username = ?
		and bib_pin != ""
	}

	# query to get currencies for currency drop-down
	db_store_qry get_currencies {
		select
				ccy_code,
				ccy_name,
				disporder
		from
				tCcy
		where
						status='A'
		order by
				disporder
	} 60

	# query to get countries for country drop-down
	db_store_qry get_countries {
		select
				country_code,
				country_name,
				disporder
		from
				tCountry
		where
				status='A'
		order by
				country_name
	} 999999

	# query to get languages for language drop-down
	db_store_qry get_languages {
		select
				lang,
				name,
				disporder
		from
				tLang
		where
				status='A'
		order by
				disporder
	} 999999

	# query to get everything from tcustomer,
	# tcustomerreg and tacct given cust_id
	# used to populate CUST_INFO array

	db_store_qry get_cust_info {
		select
				c.cust_id cust_id,
				c.cr_date cr_date,
				username,
			password,
			bet_count,
			last_bet,
			last_bet_1,
				login_count,
				login_uid,
				login_fails,
				aff_id,
				source,
				cashback_avail,
				receipt_counter,
				max_stake_scale,
				lang,
				a.ccy_code ccy_code,
				country_code,
				a.acct_type acct_type,
				c.sig_date,
				challenge_1,
				response_1,
				challenge_2,
				response_2,
				title,
				fname,
				lname,
				addr_street_1,
				addr_street_2,
				addr_street_3,
				addr_street_4,
				addr_city,
				addr_postcode,
				telephone,
				email,
				contact_ok,
				ptnr_contact_ok,
				hear_about,
				hear_about_txt,
				mobile,
				ipaddr,
				oper_notes,
				acct_id,
				acct_line,
				balance,
				balance_nowtd,
				credit_limit,
				itv_email,
				acct_no
		from
				tcustomer c,
			tcustomerreg r,
			tacct a
		where
				c.cust_id=?         and
				c.type='C'          and
				c.status='A'        and
				c.sort='R'          and
				c.cust_id=r.cust_id and
				c.cust_id=a.cust_id and
				a.status='A'
	}

	db_store_qry reg_dflts {
		select
			   default_ccy,
			   default_lang,
			   default_country
		from
			   tControl
	}

}


# ------------------------------------------------------------------
# Play the html file register.html unless passed an alternative
#
# ------------------------------------------------------------------
##############################################
proc go_register {} {
##############################################

	# Need to do something about languages here so that the text
	# in the options is in the correct language.

	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS 0] == 1} {
		global ALL_DEP_LIMITS DB ALL_DEP_CURR

		set sql_all [subst {
			select
				*
			from
				tsitecustomval
			order by 1
		}]
		set stmt_all [inf_prep_sql $DB $sql_all]
		set rs_all [inf_exec_stmt $stmt_all]
		set nrows_all [db_get_nrows $rs_all]
		tpSetVar num_dep_limits $nrows_all

		#this query is needed to order the deposit limit values in numerical order
		#Ordering had to be done in tcl as column 'setting_value' in tsitecustomval is of type varchar.
		set sql_curr [subst {
			select distinct
				setting_name
			from
				tsitecustomval
			order by 1
		}]
		set stmt_curr [inf_prep_sql $DB $sql_curr]
		set rs_curr [inf_exec_stmt $stmt_curr]
		set nrows_curr [db_get_nrows $rs_curr]
		tpSetVar num_dep_curr $nrows_curr

		for {set i 0} {$i < $nrows_curr } {incr i} {
			set unsorted_list [list]
			set sorted_list [list]
			for {set j 0} {$j < $nrows_all } {incr j} {
			set outer_curr_name [db_get_col $rs_curr $i setting_name]
			set inner_curr_name [db_get_col $rs_all $j setting_name]
			if { $inner_curr_name == $outer_curr_name } {
				lappend unsorted_list [db_get_col $rs_all $j setting_value]
			}
			}
			set sorted_list [lsort -integer $unsorted_list]
			set list_$outer_curr_name [list $outer_curr_name $sorted_list]
		}

		set total_length 0
		set start_pos 0

		for {set i 0} {$i < $nrows_curr} {incr i} {
		set curr_name [db_get_col $rs_curr $i setting_name]
		upvar 0 list_$curr_name curr_list
		set dep_limits_length [llength [lindex $curr_list 1]]
		set dep_limits_list [lindex $curr_list 1]
		set dep_limits_curr [lindex $curr_list 0]
		if {$curr_name == $dep_limits_curr} {
			set total_length [expr $total_length + $dep_limits_length]
			for {set j $start_pos; set k 0} {$j < $total_length} {incr j; incr k} {
				set ALL_DEP_LIMITS($j,setting_name) $curr_name
				set ALL_DEP_LIMITS($j,setting_value) [lindex $dep_limits_list $k]
			}
			set start_pos [expr $start_pos + $dep_limits_length]
		}
		set ALL_DEP_CURR($i,setting_name) $curr_name
		}

		tpBindVar currency_name  ALL_DEP_LIMITS setting_name   dep_limit_idx
		tpBindVar currency_dep   ALL_DEP_LIMITS setting_value  dep_limit_idx
		tpBindVar actual_curr    ALL_DEP_CURR   setting_name   dep_curr_idx
	}

	tpBindTcl CURR_SEL do_currency_drop_down [reqGetArg currency_code]
	tpBindTcl BIND_CURR_SEL bind_currency_drop_down [reqGetArg currency_code]
	tpBindTcl BIND_CTRY_SEL bind_country_drop_down  [reqGetArg country_code]

	tpBindTcl CTRY_SEL do_country_drop_down  [reqGetArg country_code]
	tpBindTcl LANG_SEL do_lang_drop_down     [reqGetArg lang_code]

	tpSetVar  CONTACT_OK "Y"

	set secs  [clock seconds]
	tpBindTcl dob_day_options   "openbet_func_pop_date_menus_at_time DAY $secs"
	tpBindTcl dob_month_options "openbet_func_pop_date_menus_at_time MONTH $secs"

	play_reg_template Register
}



# ------------------------------------------------------------------
# dump a list of value desc pairs for use by the javascript function
# write_options_with_selected_value()
# ------------------------------------------------------------------
################################################################
proc write_select_opt_list {rs val_col desc_col {sel_row ""}} {
################################################################

	if {$sel_row != ""} {
		tpBufWrite \"$sel_row\"
	} else {
		tpBufWrite "\"\""
	}

	set rows [db_get_nrows $rs]

	if {$rows > 0} {
		tpBufWrite ","
	}

	for {set i 0} {$i < $rows} {incr i} {
		tpBufWrite "\"[db_get_col $rs $i $val_col]\","
		tpBufWrite "\"[XL [db_get_col $rs $i $desc_col]]\""

		if {$i + 1 != $rows} {
			tpBufWrite ","
		}
	}
}

# ----------------------------------------------------------
# generate the args for the ccurrency select box
# ----------------------------------------------------------
########################################
proc do_currency_drop_down {selected} {
########################################

	#
	# dumps the key value pairs into data_site for js function
	#

	variable DFLT_CCY

	set output ""

	# get the currencies
	if {[catch {set rs [db_exec_qry get_currencies]} msg]} {
		ob::log::write ERROR {do_currency_drop_down: failed to get currency details. $msg}
		return
	}

	# generate html for select box

	if {$selected==""} {
		set selected  $DFLT_CCY
	}

	write_select_opt_list $rs ccy_code ccy_name $selected

	db_close $rs
}


proc bind_currency_drop_down {selected} {

	global CURRENCIES

	#
	# Just like do_currency_drop_down except I bind
	# the data up using tpBindVar as opposed to a Javascript
	# array.

	# get the currencies
	if {[catch {set rs [db_exec_qry get_currencies]} msg]} {
		ob::log::write ERROR {do_currency_drop_down: failed to get currency details. $msg}
		return
	}

	set nrows [db_get_nrows $rs]
	tpSetVar currNrows $nrows
	set cols [list ccy_code ccy_name]
	for {set r 0} {$r < $nrows} {incr r} {
		foreach x $cols {
			set CURRENCIES($r,$x) [db_get_col $rs $r $x]
		}
		if {$CURRENCIES($r,ccy_code)==$selected} {
			tpSetVar selectedCurrIdx $r
		}
	}
	foreach x $cols {
		tpBindVar [string toupper $x] CURRENCIES $x curr_idx
	}
	db_close $rs

}


proc bind_country_drop_down {selected} {

	global COUNTRIES

	#
	# Just like do_country_drop_down except I bind
	# the data up using tpBindVar as opposed to a Javascript
	# array.

	# get the countries
	if {[catch {set rs [db_exec_qry get_countries]} msg]} {
		ob::log::write ERROR {do_currency_drop_down: failed to get country details. $msg}
		return
	}

	set nrows [db_get_nrows $rs]
	tpSetVar currNrows $nrows
	set cols [list country_code country_name disporder]
	for {set r 0} {$r < $nrows} {incr r} {
		foreach x $cols {
			set COUNTRIES($r,$x) [db_get_col $rs $r $x]
		}
		if {$COUNTRIES($r,country_code)==$selected} {
			tpSetVar selectedCurrIdx $r
		}
	}
	foreach x $cols {
		tpBindVar [string toupper $x] COUNTRIES $x curr_idx
	}
	db_close $rs

}




# ----------------------------------------------------------
# generate the args for the country select box
# ----------------------------------------------------------
######################################
proc do_country_drop_down {selected} {
######################################
	#
	# dumps the countries out into datasite for
	# js function

	variable DFLT_COUNTRY

	# get the countries
	if {[catch {set rs [db_exec_qry get_countries]} msg]} {
		ob::log::write ERROR {do_country_drop_down: failed to get country details. $msg}
		return
	}

	if {$selected==""} {
		set selected $DFLT_COUNTRY
	}

	write_select_opt_list $rs country_code country_name $selected

	db_close $rs

}

# -----------------------------------------------------
# generate the argument list for the language select box
# ----------------------------------------------------
####################################
proc do_lang_drop_down {selected} {
####################################

	variable DFLT_LANG

	# get the languages
	if {[catch {set rs [db_exec_qry get_languages]} msg]} {
		ob::log::write ERROR {do_lang_drop_down: failed to get language details. $msg}
		return
	}

	if {$selected==""} {
		set selected $DFLT_LANG
	}

	write_select_opt_list $rs lang name $selected

	db_close $rs
}



# --------------------------------------------------------
# Handle Customer Registration Form
#
# on failure this procedure will call go_register
#
# on success it will evaluate the expression
# in the config value REG_SUCCESS_ACTION
# -------------------------------------------------------
############################
proc do_registration {{type PASSWD}} {
###########################
	global MULTI_LANG
	global MULTI_CCY
	global MULTI_CNTRY
	global REG_SUCCESS_ACTION
	global LANG CHARSET
	global USER_ID

	variable regQRY

	###########################
	# get the customers input #
	###########################
	set aff_id              [get_cookie AFF_ID]
	set username            [reqGetArg -unsafe tbUserName]

	set pwd1                [reqGetArg -unsafe tbPassword1]
	set pwd2                [reqGetArg -unsafe tbPassword2]

	set pin1                [reqGetArg -unsafe tbPin1]
	set pin2                [reqGetArg -unsafe tbPin2]


	set country_code        [encoding convertfrom $CHARSET [reqGetArg  country_code]]
	set currency_code       [encoding convertfrom $CHARSET [reqGetArg  currency_code]]
	set lang_code           $LANG

	set reg_status          "A"
	set ipaddr              [encoding convertfrom $CHARSET [reqGetEnv REMOTE_ADDR]]
	set challenge_1         [reqGetArg -unsafe tbQ1]
	set response_1          [reqGetArg -unsafe tbAns1]

   # if only 1 question, these will be blank which is okay
   set challenge_2         [reqGetArg -unsafe tbQ2]
	set response_2          [reqGetArg -unsafe tbAns2]

	set sig_date        [reqGetArg -unsafe tbMemDate]
	set source              [OT_CfgGet CHANNEL "I"]
	set title               [reqGetArg -unsafe tbTitle]
	set fname               [reqGetArg -unsafe tbFname]
	set lname               [reqGetArg -unsafe tbLname]
	set addr_1              [reqGetArg -unsafe tbAddr1]
	set addr_2              [reqGetArg -unsafe tbAddr2]
	set addr_3              [reqGetArg -unsafe tbAddr3]
	set addr_4              [reqGetArg -unsafe tbAddr4]
	set addr_cty            [reqGetArg -unsafe tbAddrCty]
	set addr_pc             [reqGetArg -unsafe tbAddrPc]
	set price_type          [reqGetArg -unsafe tbPriceType]
	set telephone           [encoding convertfrom $CHARSET [reqGetArg tbTel]]
	set email               [encoding convertfrom $CHARSET [reqGetArg tbEmail]]
	set itv_email           [encoding convertfrom $CHARSET [reqGetArg tbItvEmail]]
	set contact_ok          [encoding convertfrom $CHARSET [reqGetArg rdContact]]
	set ptnr_cnt_ok         [encoding convertfrom $CHARSET [reqGetArg rdPnrContact]]
	set over_18             [encoding convertfrom $CHARSET [reqGetArg over18]]
	set read_rules          [encoding convertfrom $CHARSET [reqGetArg readRules]]
	set dob_day     [encoding convertfrom $CHARSET [reqGetArg dob_day]]
	set dob_month       [encoding convertfrom $CHARSET [reqGetArg dob_month]]
	set dob_year1       [encoding convertfrom $CHARSET [reqGetArg dob_year1]]
	set dob_year2       [encoding convertfrom $CHARSET [reqGetArg dob_year2]]
	set dob                 [reqGetArg dob]
	set mobile      [encoding convertfrom $CHARSET [reqGetArg mobile]]
	if {$mobile == ""} {
		set mobile      [encoding convertfrom $CHARSET [reqGetArg tbMobile]]
	}

	# set to U if registering with username/passwd, A if registering with accno/passwd
	set reg_combi       [reqGetArg -unsafe regCombination]
	# sort out marketing stuff
	# in general will be a load of radio icons (rdMarketing)
	# an 'other' test box (marketingOther)
	# any number of select boxes which will be converted to a marketing code
	# along with extra text
	# currently do newspaper in this fashion
	# just copy the code to add others..
	if {[reqGetArg newspaper]!=""} {
		set hear_about "NEWS"
		set hear_about_txt [reqGetArg -unsafe newspaper]
	} else {
		set hear_about     [reqGetArg -unsafe rdHearAbout]
		set hear_about_txt [reqGetArg -unsafe tbOther]
	}

	if {[OT_CfgGetTrue "PASS_NOT_CASE_SENSITIVE"]} {
		set pwd1 [string toupper $pwd1]
		set pwd2 [string toupper $pwd2]
	}

	############################
	# Validate customers input #
	############################

	if {$type == "PASSWD"} {
		chk_mandatory_txt   $username "username"
		set tmpErrList [chk_unsafe_pwd $CUSTDETAIL(password) $CUSTDETAIL(password2) $CUSTDETAIL(username)]
		foreach tmpErr $tmpErrList {
			err_add $tmpErr
		}
		if {[OT_CfgGetTrue ONE_REG_QUESTION]} {
			chk_mandatory_txt $challenge_1 "personal question"
			chk_mandatory_txt $response_1 "answer to the personal question"
		} else {
			chk_mandatory_txt $challenge_1 "first personal question"
			chk_mandatory_txt $response_1 "answer to the first personal question"
			chk_mandatory_txt $challenge_2 "second personal question"
			chk_mandatory_txt $response_2 "answer to the second personal question"
		}
		chk_mandatory_txt   $addr_1 "first line of your address"
		chk_optional_txt    $addr_2 "second line of your address"
		chk_optional_txt    $addr_3 "third line of your address"
		chk_optional_txt    $addr_4 "fourth line of your address"
		chk_mandatory_txt $addr_cty "town / city "
		if {[OT_CfgGet CUSTOMER none] == "littlewoods"} {
			chk_mandatory_txt $addr_pc "post code"
		}
		chk_email $email
		chk_email $itv_email "interactive TV email address" N
	} elseif {$type == "PIN"} {
		chk_pin $pin1 $pin2
		chk_date $sig_date "Memorable date"
		chk_email $itv_email "email address"
	}

	chk_ipaddr $ipaddr
	if {[OT_CfgGet CUSTOMER none] == "littlewoods"} {
		chk_mandatory_txt $title "title"
	}
	chk_mandatory_txt $fname "first name"
	chk_mandatory_txt $lname "last name"
	chk_optional_txt    $hear_about "marketing source"
	chk_optional_txt    $hear_about_txt  "marketing source \"other\" box"
	chk_phone_no $telephone "telphone number"
	chk_phone_no $mobile "mobile number"
	chk_contact $contact_ok

	if {[OT_CfgGet ODDS_DISPLAY 0] == 1} {
		chk_pricetype $price_type
	}
	chk_age $over_18
	chk_rules $read_rules

	# Sort out source
	if {$source == ""} {
		set source "I"
	}

	# Deal with date of birth...
	# get year ...
	if {$dob ==""} {
		if {$dob_year1!=""} {
			set dob [chk_dob "19$dob_year1$dob_year2" $dob_month $dob_day]
		} elseif {$challenge_1 == "Date Of Birth"} {
			ob::log::write INFO "Using first challenge's answer as DOB"
			if {[regexp {^(\d{2})\/(\d{2})\/(\d{4})$} $response_1 match dob_day dob_month dob_year]} {
				set dob [chk_dob $dob_year $dob_month $dob_day]
			} else { err_add [ml_printf REG_DOB_INVALID] }
		}
   }

	if {[err_numerrs]} {
		re_register
		return
	}

	##################################
	# Try to put input into database #
	##################################
	set enc_pwd ""
	set enc_pin ""
	set password_salt ""
	if {$type == "PASSWD"} {
		if {[OT_CfgGet CUST_PWD_SALT 0]} {
			set password_salt [generate_salt]
		}
		set enc_pwd [encrypt_password $pwd1 $password_salt]
	} elseif {$type == "PIN"} {
		set enc_pin [encrypt_pin $pin1]
	} else {
		OT_LogWrite 2 "Unknown registration type"
		return 1
	}

	# Is the locale configured.
	if {[lsearch [OT_CfgGet LOCALE_INCLUSION] REG] > -1} {
		set locale [app_control::get_val locale]
	} else {
		set locale ""
	}

	# do we allow 7 digit usernames?
	if { [OT_CfgGet DISABLE_7DIGITS_USERNAMES 0] } {
		if { [regexp {^\d{7}$} $username] } {
			OT_LogWrite 2 "Bad Username (Config disallows 7digits usernames)"
			return 1
		}
	}

	if {[catch {set rs [db_exec_qry insert_cust_qry   $aff_id \
			$username \
			$enc_pwd \
			$password_salt \
			$lang_code\
			$currency_code\
			$country_code\
			$reg_status \
			$ipaddr \
			$challenge_1 \
			$response_1 \
			$challenge_2 \
			$response_2 \
			$title \
			$fname \
			$lname \
			$addr_1 \
			$addr_2 \
			$addr_3 \
			$addr_4 \
			$addr_cty \
			$addr_pc \
			$telephone \
			$email \
			$itv_email \
			$contact_ok \
			$ptnr_cnt_ok \
			$hear_about \
			$hear_about_txt \
			$dob \
			$mobile \
			$source \
			$enc_pin \
			$sig_date \
			$price_type \
			$reg_combi \
			$locale \
			[OT_CfgGet CUST_ACCT_NO_FORMAT A] \
	]} msg]} {
				# Need to check username already chosen msg
				if {[regexp {already chosen by someone else} $msg ]} {
					err_add [ml_printf "Username %s already chosen by someone else" $username]
				} else {
					err_add $msg
				}
				re_register
				return
	}

	# If registered ok then goto home page
	set USER_ID [db_get_coln $rs 0 0]
	db_close $rs

	if {[OT_CfgGet FUNC_CUST_DEP_LIMITS 0] == 1} {
		#insert cust deposit limits
		if { [reqGetArg dep_curr] != "-1"} {
			set dep_amt [reqGetArg dep_amt]
			if { [reqGetArg dep_interval] == "DAILY"} {
				set dep_period "1"
			} else {
				set dep_period "7"
			}
			if {![OB_srp::insert_update_cust_dep_limit $USER_ID \
			$dep_amt $dep_period "" "" $USER_ID ""]} {
			err_add [ml_printf "There was an error inserting your deposit limits"]
			}
		}
	}

	# Pass action to FreeBets(tm)
	if {[OT_CfgGet ENABLE_FREEBETS2 "FALSE"] == "TRUE"} {
		OB_freebets::check_action [list REG REGAFF] $USER_ID $aff_id
	}

	eval $REG_SUCCESS_ACTION
}

#####################
proc re_register {} {
#####################
#
# Spit out the registration form again populating the fields with
# the data the user has already entered.
# This is useful if there is an error not detected client-side.
#

	tpBindString USERNAME       [reqGetArg -unsafe tbUserName]
	tpBindString PWD1           [reqGetArg -unsafe tbPassword1]
	tpBindString PWD2           [reqGetArg -unsafe tbPassword2]
	tpBindString PIN1           [reqGetArg -unsafe tbPin1]
	tpBindString PIN2           [reqGetArg -unsafe tbPin2]
	tpBindString CHALLENGE_1    [reqGetArg -unsafe tbQ1]
	tpBindString RESPONSE_1     [reqGetArg -unsafe tbAns1]
	tpBindString CHALLENGE_2    [reqGetArg -unsafe tbQ2]
	tpBindString MEM_DATE       [reqGetArg -unsafe tbMemDate]
	tpBindString RESPONSE_2     [reqGetArg -unsafe tbAns2]
	tpBindString TITLE          [reqGetArg -unsafe tbTitle]
	tpBindString FNAME          [reqGetArg -unsafe tbFname]
	tpBindString LNAME          [reqGetArg -unsafe tbLname]
	tpBindString ADDR_1         [reqGetArg -unsafe tbAddr1]
	tpBindString ADDR_2         [reqGetArg -unsafe tbAddr2]
	tpBindString ADDR_3         [reqGetArg -unsafe tbAddr3]
	tpBindString ADDR_4         [reqGetArg -unsafe tbAddr4]
	tpBindString ADDR_CTY       [reqGetArg -unsafe tbAddrCty]
	tpBindString ADDR_PC        [reqGetArg -unsafe tbAddrPc]
	tpBindString TELEPHONE      [reqGetArg tbTel]
	tpBindString MOBILE         [reqGetArg tbMobile]
	tpBindString EMAIL          [reqGetArg tbEmail]
	tpBindString ITV_EMAIL      [reqGetArg tbItvEmail]
	tpBindString CONTACT_OK     [reqGetArg rdContact]
	tpBindString PTNR_CNT_OK    [reqGetArg rdPnrContact]
	tpBindString PRICE_TYPE     [reqGetArg tbPriceType]

	go_register
}

####################################
proc chk_mandatory_txt {str field} {
####################################
#
# str : value to check
# field : name of field - for use in error message
#
   global CHARSET
	if {$str == ""} {
		err_add [ml_printf "The %s is empty." $field]
		return 0
	}

	# chek that there are no unsafe characters...
	set test [encoding convertfrom $CHARSET $str]
	if {[regexp {[][${}\\]} $str]} {
		err_add [ml_printf "The %s contains invalid characters." $field]
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
		err_add [ml_printf "The %s contains invalid characters." $field]
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
			lappend returnList "The password must be 6 - 8 characters long"
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
		err_add [ml_printf "The %s contains invalid characters." $field]
		return 0
	}
	return 1
}

##########################
proc chk_ipaddr {ipaddr} {
##########################
	set exp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}
	if {[regexp $exp $ipaddr] == 0} {
		err_add [ml_printf "The %s is invalid." "IP Address of your computer"]
		return 0
	}
	return 1
}


########################
proc chk_email {email {desc email} {compulsory Y}} {
########################
	if {$email==""} {
		if {$compulsory == "Y"} {
			err_add [ml_printf "The %s is empty." $desc]
			return 0
		} else {
			return 1
		}
	}
	set exp {^[^@]+\@([-a-zA-Z0-9]+\.)*[a-zA-Z]+$}
	if {[regexp $exp $email] == 0} {
		err_add [ml_printf "The %s contains invalid characters." $desc]
		return 0
	}
	return 1
}

####################
proc chk_age {ans} {
####################
	global LANG
	if {$ans!="Y"} {
		err_add [ml_printf "You must be over 18 to use this site"]
		return 0
	}
}

########################
proc chk_contact {str} {
########################
	set exp {{^[Y|N]?$}}
	if {[regexp $exp $str] == 1} {
		err_add [ml_printf "Please indicate whether you would like us to contact you or not."]
		return 0
	}
	return 1
}

######################
proc chk_rules {ans} {
######################
	global LANG
	if {$ans!="Y"} {
		err_add [ml_printf "You must have read and understood the rules to use this site"]
		return 0
	}
	 return 1
}

######################
proc chk_pricetype {ans} {
######################
	global LANG
	if {$ans!="ODDS" && $ans !="DECIMAL"} {
		err_add [ml_printf "Please choose a preferred odds display"]
		return 0
	}
	return 1
}

##########################
proc chk_pin {pin1 pin2 {min 6} {max 8}} {
##########################
	variable BAD_PINS

	if {$pin1 != $pin2} {
		err_add [ml_printf "PINS do not match"]
		return 0
	}

	#check not empty
	if {$pin1 == ""} {
		err_add [ml_printf "PIN cannot be empty"]
		return 1
	}

	#make sure only digits
	if {![regexp {^[0-9]+$} $pin1]} {
		err_add [ml_printf "Only numeric characters permitted in the PIN."]
		return 0
	}

	if {[lsearch $BAD_PINS [string toupper $pin1]] >= 0} {
		err_add [ml_printf "That PIN is too easy to guess"]
		return 0
	}

	if {[string length $pin1] < $min} {
		err_add "PIN too short"
		return 0
	}

	if {[string length $pin1] > $max} {
		err_add "PIN too long"
		return 0
	}

	return 1
}


###########################################
proc chk_dob {dob_year dob_month dob_day} {
###########################################
# -----------------------------------------------------------------
# given a year and month check that the customer
# is over 18, return their dob as an informix datatime, year to day
# -----------------------------------------------------------------
	# check it's a valid date...
	if {[days_in_month $dob_month $dob_year]<$dob_day} {
		err_add [ml_printf REG_DOB_INVALID]
	}

	set dob_month [string trimleft $dob_month 0]
	set dob_day   [string trimleft $dob_day 0]

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

	set dob "$dob_year-[format %02d $dob_month]-[format %02d $dob_day]"

	if {($year_diff < 18) ||
		(($year_diff == 18) && ($curr_month < $dob_month)) ||
		(($year_diff == 18) && ($curr_month == $dob_month) && ($curr_day < $dob_day))
	} {
		err_add [ml_printf "We are unable to register you as your date of birth indicates that you are under 18 years old"]
	}

	if {$year_diff > 150} {
		err_add [ml_printf "We are unable to register you as your date of birth indicates that you are over 150 years old"]
	}

	return $dob
}

############################
proc chk_date {date field} {
############################

	#check date has the correct number of characters
	if {[string length $date] != 8} {
	err_add "$field format should be DDMMYYYY"
	return 0
	}

	#make sure only digits
	if {![regexp {^[0-9]+$} $date]} {
	err_add "Only numeric characters permitted in $field."
	return 0
	}

	#make sure it is a valid date
	set day [string range $date 0 1]
	set month [string range $date 2 3]
	set year [string range $date 4 7]

	#remove any preceding zeros - no octals here thank you
	set day [string trimleft $day 0]
	set month [string trimleft $month 0]
	set year [string trimleft $year 0]

	#catch any errors here incase punter trys months 00 or too large months
	if {[catch {set days_in_month [days_in_month $month $year]} msg]} {
	err_add "$field is not a valid date."
	return 0
	}

	if {$days_in_month < $day} {
	err_add "$field is not a valid date."
	return 0
	}

	return 1
}


####################################
proc do_update_details { cust_detail  args } {
####################################
#
# Updates a customers registration details
# Argument is an array that holds the new details
# Returns 1 on success, 0 on failure
# Error messages will appear in template data site TP_ERROR
#
	global USERNAME LANG ERR_MSG LOGIN_DETAILS
	variable regQRY
	upvar $cust_detail CUST_DETAIL

	if {[string length $CUST_DETAIL(PASSWORD)] == 0 && $CUST_DETAIL(PIN) == ""} {
		err_add "Please enter your pin/password"
		return 0
	}

	# Validate the new details
	chk_mandatory_txt $CUST_DETAIL(FNAME) "first name"
	chk_mandatory_txt $CUST_DETAIL(LNAME) "last name"
	if {[OT_CfgGet CUSTOMER none] == "littlewoods"} {
		chk_mandatory_txt $CUST_DETAIL(TITLE) "title"
		chk_mandatory_txt $CUST_DETAIL(ADDR_PC) "post code"
	}
	chk_contact $CUST_DETAIL(CONTACT_OK)
	if {[OT_CfgGet ODDS_DISPLAY 0] == 1} {
		chk_pricetype $CUST_DETAIL(PRICE_TYPE)
	}

	if {$CUST_DETAIL(PASSWORD) != ""} {
		chk_mandatory_txt   $CUST_DETAIL(ADDR_1) "first line of your address"
		chk_optional_txt    $CUST_DETAIL(ADDR_2) "second line of your address"
		chk_optional_txt    $CUST_DETAIL(ADDR_3) "third line of your address"
		chk_optional_txt    $CUST_DETAIL(ADDR_4) "fourth line of your address"
		chk_mandatory_txt $CUST_DETAIL(ADDR_CTY) "town / city "
		chk_optional_txt    $CUST_DETAIL(ADDR_PC)   "postcode / zipcode"
		chk_phone_no $CUST_DETAIL(TELEPHONE) "telphone number"
		chk_phone_no $CUST_DETAIL(MOBILE) "mobile number"
		chk_email $CUST_DETAIL(EMAIL)
		chk_email $CUST_DETAIL(ITV_EMAIL) "interactive TV email" N
	} else {
		chk_email $CUST_DETAIL(ITV_EMAIL) "interactive TV email"
	}

	if {[err_numerrs]} {
		return 0
	}

	if {[string first "-noencrypt" $args] == -1} {

		set enc_pwd [encrypt_password $CUST_DETAIL(PASSWORD) $LOGIN_DETAILS(PASSWORD_SALT)]

		if {[catch {set rs [db_exec_qry update_cust_details \
							   $USERNAME \
							   $enc_pwd \
							   $CUST_DETAIL(TITLE) \
							   $CUST_DETAIL(FNAME) \
							   $CUST_DETAIL(LNAME) \
							   $CUST_DETAIL(ADDR_1) \
							   $CUST_DETAIL(ADDR_2) \
							   $CUST_DETAIL(ADDR_3) \
							   $CUST_DETAIL(ADDR_4) \
							   $CUST_DETAIL(ADDR_CTY) \
							   $CUST_DETAIL(ADDR_PC) \
							   $CUST_DETAIL(TELEPHONE) \
							   $CUST_DETAIL(EMAIL) \
							   $CUST_DETAIL(ITV_EMAIL) \
							   $CUST_DETAIL(CONTACT_OK) \
							   $CUST_DETAIL(MOBILE)]} msg]} {
			set errs [split $msg ","]
			if {[llength $errs] > 1} {
				err_add [lindex $errs 1]
			} else {
				if {[regexp {AX2001} $msg]} {
					err_add [ml_printf "Incorrect Password"]
				} else {
					err_add [ml_printf "Unable to retrieve your account details at this time, please try again later."]
				}
			}
			return 0
		}
	} else {
		if {[catch {set rs [db_exec_qry update_cust_details \
							   $USERNAME \
							   $CUST_DETAIL(PASSWORD) \
							   $CUST_DETAIL(TITLE) \
							   $CUST_DETAIL(FNAME) \
							   $CUST_DETAIL(LNAME) \
							   $CUST_DETAIL(ADDR_1) \
							   $CUST_DETAIL(ADDR_2) \
							   $CUST_DETAIL(ADDR_3) \
							   $CUST_DETAIL(ADDR_4) \
							   $CUST_DETAIL(ADDR_CTY) \
							   $CUST_DETAIL(ADDR_PC) \
							   $CUST_DETAIL(TELEPHONE) \
							   $CUST_DETAIL(EMAIL) \
							   $CUST_DETAIL(ITV_EMAIL) \
							   $CUST_DETAIL(CONTACT_OK) \
							   $CUST_DETAIL(MOBILE)]} msg]} {
			set errs [split $msg ","]
			ob::log::write ERROR {Register error: $msg}

			if {[llength $errs] > 1} {
				err_add [lindex $errs 1]
			} else {
				if {[regexp {AX2001} $msg]} {
					err_add [ml_printf "Incorrect Password"]
				} else {
					err_add [ml_printf "Unable to retrieve your details at this time, please try again later."]
				}
			}
			return 0
		}
	}



	# Set user PRICE_TYPE pref
	if {[OT_CfgGet ODDS_DISPLAY 0] == 1} {
		if {$CUST_DETAIL(PRICE_TYPE) != ""} {
			OB_prefs::set_pref PRICE_TYPE $CUST_DETAIL(PRICE_TYPE)
		}
	}

	# If registered ok then goto home page
	return 1
}

############################
proc get_cust_details args {
############################
	global USER_ID

	if {[catch {set rs [db_exec_qry get_cust_info $USER_ID]} msg]} {
		ob::log::write ERROR {Failed to get customer details : $msg}
		return 0
	}
	return $rs
}

# Close Registration Namespace
}

