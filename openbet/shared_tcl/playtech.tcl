#-----------------------------------------------------------------------------
#
# $Id: playtech.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# Copyright (C) 2009 Orbis Technology Ltd. All rights reserved.
#
# Playtech Integration Code
#
# This code implements a tcl interface for some of the 3rd Party -> Playtech
# functions of the Playtech Integration API
#
#
# Commands
#
#
# Initialisation:
#
#
# playtech::init
#   call on startup
#
#
# Calling Scripts:
#
#
# playtech::call script ?{name value}....?
#   This is the main command of the package. To make a call to a playtech script,
#   this command can be called directly, with the required parameters, or one of
#   the various wrappers defined below can be called.
#
# playtech::newplayer username pwd1 pwd2 country_code currency_code......
#   A wrapper for calls to the newplayer.php script. Performs various validation
#   on the inputs and configuring test accounts (according to config setting)
#
# playtech::change_player username password country_code fname lname.....
#   A wrapper for calls to the change_player.php script
#
# playtech::transfer_funds cust_id username password currency amount unique_id
#   Transfer funds between openbet and playtech. Wraps calls to the
#   externaldeposit.php or externalwithdraw.php script and updates the customers
#   openbet account.
#
# playtech::get_playerinfo username password system
#   A wrapper for calls to the get_playerinfo.php script.
#
# playtech::change_password username password
#   A wrapper for calls to the change_password.php script.
#
# checktransaction
#   Check the status of a previously done but incomplete transaction to set its status
#
# Obtaining Response/Status:
#
#
# playtech::status
#   returns either OK, ERROR, UNKNOWN
#   When a call to a script has succeeded OK is returned.
#   When the script returns a valid response that indicates an error, ERROR is
#   returned.
#   When the request fails or no valid response is received, UNKNOWN is returned.
#
# playtech::code
#   returns a translatable message code in the case of ERROR or UNKNOWN statuses
#   This command will throw an error if the status is OK
#
# playtech::response parameter
#   Obtain values from the response
#   This command throws an error if the status is UNKNOWN
#
#
# Other:
#
#
# playtech::encodeid username password cur_date system
#   returns a key used to access the playtech client
# -----------------------------------------------------------------------------

package require tls
package require tdom
package require util_log
package require util_db
package require net_socket

namespace eval playtech {

# static data arrays
variable CONFIG
variable SCRIPTS
variable ERRORS
variable INIT 0

# other variables
variable REQID
variable RESPONSE
variable STATUS
variable REQCONFIG

array set CONFIG        [list]
array set REQCONFIG     [list]
array set SCRIPTS       [list]
array set ERRORS        [list]

set SCRIPTS(newplayer.php,mandatory) {
	address
	birthdate
	casino
	city
	countrycode
	creferer
	currency
	email
	firstname
	lastname
	password1
	password2
	phone
	remotecreate
	remoteip
	serial
	state
	username
	wantmail
	zip
	responsetype
}

set SCRIPTS(newplayer.php,optional) {
	advertiser
	customclient01
	customclient02
	profileid
	bannerid
	refererurl
	custom05
	custom06
	title
	fax
	occupation
	sex
	language
	coupon
}

set SCRIPTS(change_password.php,mandatory) {
	casino
	newpassword
	remotecreate
	username
	secretkey
	responsetype
}

set SCRIPTS(change_pwd.php,mandatory) {
	casino
	oldpwd
	newpwd
	remotecreate
	username
	secretkey
	responsetype
}

set SCRIPTS(change_player.php,mandatory) {
	casino
	secretkey
	sync_username
	sync_password
	responsetype
}

set SCRIPTS(change_player.php,optional) {
	username
	address
	zip
	city
	state
	countrycode
	email
	firstname
	lastname
	phone
	haveidcopyfax
	wantmail
	frozen
	title
	releaseheldfunds
	custom05
	custom06
	cellphone
	occupation
	sex
}

set SCRIPTS(newccard.php,mandatory) {
	casino
	username
	password
	remotecreate
	cardnumber
	cardtype
	expmonth
	expyear
	firstname
	lastname
	address
	city
	state
	zip
	countrycode
	responsetype
}

set SCRIPTS(newccard.php,optional) {
	cardpin
}

set SCRIPTS(change_ccard.php,mandatory) {
	casino
	secretkey
	username
	password
	cardnumber
	responsetype
}

set SCRIPTS(change_ccard.php,optional) {
	photocopyexists
	frozen
}

set SCRIPTS(get_playerinfo.php,mandatory) {
	casino
	secretkey
	username
	password
	responsetype
}

set SCRIPTS(get_balance.php,mandatory) {
	casino
	secretkey
	username
	password
	responsetype
}

set SCRIPTS(get_balance.php,optional) {
	additional_fields
}


set SCRIPTS(externaldeposit.php,mandatory) {
	casino
	username
	amount
	currency
	password
	externaltranid
	secretkey
	responsetype
}

set SCRIPTS(externaldeposit.php,optional) {
	promocode
}

set SCRIPTS(externaldeposit.php,location) {payments}

set SCRIPTS(externalwithdraw.php,mandatory) {
	casino
	username
	amount
	currency
	password
	externaltranid
	secretkey
	responsetype
}

set SCRIPTS(externalwithdraw.php,location) {payments}

set SCRIPTS(checktransaction.php,mandatory) {
	casino
	secretkey
	username
	externaltranid
	responsetype
}

set SCRIPTS(checktransaction.php,location) {payments}

set SCRIPTS(check_logintoken.php,mandatory) {
	casino
	secretkey
	username
	logintoken
	responsetype
	invalidate
}


set SCRIPTS(getplayerfunds.php,mandatory) {
	admin
	password
	casino
	usernames
}


set SCRIPTS(report_view.php,mandatory) {
	reportcode
	action
	casino
	admin
	password
	startdate
	enddate
}

set SCRIPTS(report_view.php,optional) {
	username
}

set SCRIPTS(HTMLLayout/WebCashierLogin.php,mandatory) {
	username
	password
	casino
	clienttype
}

set SCRIPTS(HTMLLayout/WebCashierLogin.php,optional) {
	language
}

set SCRIPTS(HTMLLayout/CashierProxy.php,mandatory) {
	casino
	script
	clienttype
	wcusersessionid
	mode
}

set SCRIPTS(HTMLLayout/CashierProxy.php,optional) {
	amount
	firstname
	lastname
	address
	city
	state
	zip
	country
	productcode
	productname
	quantity
	amount
}

set SCRIPTS(remote_bonus.php,mandatory) {
	casino
	bonus
	admin
	password
	username
	amount
}

proc init {} {

	variable INIT

	if {$INIT} return

	_store_queries
	_bind_config

	set INIT 1

}



# Allow extra configuration items (relevant to the request only) to be set.
#
# Currently have the following request config parameters:
#
#   -is_critical_request (Y/N) - determines if the request to playtech is
#                                a critical one or not
#   -force_use_req_timeout     - force to use this timeout instead of the standard critical/no critical request.
#   -force_use_conn_timeout    - ""
#   -channel  (I, P, etc)      - the channel of the calling application
#
proc configure_request args {
	_log DEBUG "configure_request ($args)"

	variable REQCONFIG
	if {[catch {
		ob_gc::add ::playtech::REQCONFIG
	} msg]} {
		_log WARNING {unable to add REQCONFIG to gc - $msg}
	}

	if {[llength $args] % 2 == 1} {
		error "Error - playtech::configure called with ($args)"
	}

	foreach {n v} $args {
		switch -- $n {
			"-is_critical_request"    {set REQCONFIG(is_critical_request) $v}
			"-channel"                {set REQCONFIG(channel) $v}
			"-force_use_req_timeout"  {set REQCONFIG(forced_req_timeout) $v}
			"-force_use_conn_timeout" {set REQCONFIG(forced_conn_timeout) $v}
			default {error "playtech::configure - unknown param $n"}
		}
	}

	_log DEBUG {configure_request - REQCONFIG = [array get REQCONFIG]}
}



#
#
proc call {system script args} {

	variable CONFIG

	_reset

	_log INFO {calling playtech script $script}

	# make the url to send to playtech
	foreach {success url params_str} [eval _make_url $system $script $args] {break}
	_log INFO {success: $success}
	if {$success != "OK"} {
		error "Playtech error - cannot make url"
	}

	_log DEV "url = ($url) ; params_str = ($params_str)"

	# Now we have a url of the form:
	#    https://cashier1.demo.playtech.com/get_playerinfo.php
	#
	# And some parameters (params_str) of the form:
	#    casino playtech4 secretkey AbCdEfG username JEANGREY
	#    bingo playtech10 secretkey bingoland
	#
	# We now split the url down to get the:
	#    host        (e.g. cashier1.demo.playtech.com)
	#    port        (currently ignored)
	#    script_name (e.g. /get_playerinfo.php)
	#

	set reg_exp_url {^https://([^/:]+)(:(\d+))?(/.*)?$}

	if {[OT_CfgGet PLAYTECH_USE_HTTP_URL 0]} {
		set reg_exp_url {^http://([^/:]+)(:(\d+))?(/.*)?$}
	}

	if {![regexp -nocase $reg_exp_url $url all host ignore port script_name]} {
		error "Playtech error - cannot make url"
	}

	_log DEV "host = ($host) ; script_name = ($script_name)"


	set request [::ob_socket::format_http_req -host $host \
			-port $port \
			-method "POST" \
			-form_args $params_str \
			-urlencode_unsafe [expr {$script == "report_view.php" ? 1 : 0}]\
			-headers [list Authorization "Basic $CONFIG($system,admin_auth_key)"]\
			$script_name]

	# send the request to playtech
	set response [_send_request $system $host $request]

	# process the request
	if {$response != ""} {
		# rt 5784 ipoints hack - remote_bonus returns string, dont process
		if {$script == "remote_bonus.php"} {
			if {$response == "Ok"} {
				_set_status OK
			} else {
				_set_status ERROR
			}
		} else {
			_process_response $script $response
		}
	}

	# as an integrity check, make sure we have set the status before returning
	if {[catch {status} msg]} {
		error "cannot return from playtech::call without setting status: $msg"
	}
}



proc newplayer {
	username
	pwd1
	pwd2
	countrycode
	currency_code
	fname
	lname
	addr_1
	addr_2
	addr_3
	addr_4
	addr_cty
	addr_pc
	dob
	email
	mobile
	telephone
	ipaddr
	title
	contact_ok
	contact_how
	elite
	system
	custom06
	acct_no
	fax
	occupation
	sex
	language
	{creferer ""}
	{advertiser ""}
	{bannerid ""}
	{profileid ""}
	{refererurl ""}
	{coupon ""}
} {
	global DB
	variable CONFIG

	_reset

	# the following sets up/validates details that are common to this and the change_player command
	_process_details

	# check if the above has caused errors
	if {![catch {status}]} {
		return
	}

	if {![OT_CfgGet PLAYTECH_AFFILIATES_UNITED 0]} {
		if {$elite == "N"} {
			# Get any Playtech affiliates that may have been passed Playtech client software
			if {[catch {set rs [ob_db::exec_qry playtech::get_affiliate $username]} msg]} {
				_log ERROR {error executing playtech::get_affiliate:$msg}
				_set_status ERROR
				return
			}
			set nrows [db_get_nrows $rs]
			if {$nrows != 0} {
				set aff_string [db_get_col $rs flag_value]
				set advertiser [lindex [split $aff_string "|"] 0]
				set profileid [lindex [split $aff_string "|"] 1]
			} else {
				set advertiser ""
				set profileid ""
			}
			ob_db::rs_close $rs
		} else {
			# For "elite" customers we fudge the advertiser information in order
			# to protect their data in the Playtech Administration system
			set advertiser $CONFIG($system,playtech_elite_advertiser_id)
			set profileid $CONFIG($system,playtech_elite_profile_id)
		}
	}

	if {$custom06 == "Y"} {
		set custom06 "Yes"
	} else {
		set custom06 "No"
	}

	call $system \
	        newplayer.php\
		"address $address"\
		"birthdate $dob"\
		"city $addr_cty"\
		"countrycode $countrycode"\
		"currency $currency_code"\
		"email $email"\
		"firstname $fname"\
		"lastname $lname"\
		"password1 $pwd1"\
		"password2 $pwd2"\
		"phone $telephone"\
		"remoteip $ipaddr"\
		"serial {}"\
		"state $state"\
		"username $username"\
		"wantmail $chkEmail"\
		"zip $addr_pc"\
		"custom06 $custom06"\
		"custom05 $acct_no"\
		"title $title"\
		"fax $fax"\
		"occupation $occupation"\
		"sex $sex"\
		"language $language"\
		"advertiser $advertiser"\
		"bannerid $bannerid"\
		"profileid $profileid"\
		"refererurl $refererurl"\
		"creferer $creferer"\
		"coupon $coupon"
}



proc change_player {
	username
	password
	countrycode
	fname
	lname
	addr_1
	addr_2
	addr_3
	addr_4
	addr_cty
	addr_pc
	email
	mobile
	telephone
	title
	contact_ok
	contact_how
	frozen
	kill
	system
	custom06
	acct_no
	occupation
	sex
	{dob ""}
} {
	global DB

	_reset

	# the following performs validation and sets up address, state etc
	set dob ""
	_process_details

	# check if the above has caused errors
	if {![catch {status}]} {
		return
	}

	if {$custom06 == "Y"} {
		set custom06 "Yes"
	} else {
		set custom06 "No"
	}

	set details [list\
		"sync_username $username"\
		"sync_password $password"\
		"address $address"\
		"city $addr_cty"\
		"email $email"\
		"firstname $fname"\
		"lastname $lname"\
		"phone $telephone"\
		"wantmail $chkEmail"\
		"state $state"\
		"title $title"\
		"zip $addr_pc"\
		"frozen $frozen"\
		"kill $kill"\
		"custom06 $custom06"\
		"cellphone $mobile"\
		"countrycode $countrycode"\
		"custom05 $acct_no"\
		"occupation $occupation"\
		"sex $sex"]

	eval call $system \
	change_player.php $details
}



proc change_username {
	old_username
	new_username
	password
	system
} {

	call $system \
	        change_player.php\
		"sync_username $old_username"\
		"username $new_username"\
		"sync_password $password"\
		"kill 1"
}


proc change_player_status {
	username
	password
	system
	frozen
} {

	_log ERROR {change_player_status}
	_log ERROR "username=$username password=$password system=$system frozen=$frozen"
	call $system change_player.php\
		"sync_username $username"\
		"sync_password $password"\
		"frozen $frozen"

}



proc transfer_funds {
	system
	cust_id
	username
	password
	currency
	amount
	unique_id
	{desc "Playtech Transfer"}
	{promocode ""}
} {

	variable CONFIG

	_reset

	set source [OT_CfgGet CHANNEL "I"]

	#----------------------
	# check amount is valid
	if {![regexp {^-?\d+(\.\d\d*)?$} $amount]} {
		_log INFO {invalid amount:$amount (does not match ^-?\\d+(\\.\\d\\d*)?\$)}
		_set_status ERROR PT_ERR_INVALID_AMOUNT
		return
	}

	set amount [format "%.2f" $amount]
	if {$amount == 0} {
		_set_status OK
		return
	}

	#--------------------------------------------------
	# set correct remote action for the tXSysXfer entry
	if {[info exists CONFIG($system,xfer_desc)]} {
		set desc_type $CONFIG($system,xfer_desc)
	} else {
		set desc_type "$system"
	}

	if {$amount < 0} {
		# Chip purchase
		_log DEBUG {Playtech chip purchase attempt}
		set remote_action PRCH
		set desc "$desc_type purchase"
	} else {
		# Chip sale
		_log DEBUG {Playtech chip sale attempt}
		set remote_action SALE
		set desc "$desc_type sale"
	}

	# determine whether to include credit to 3rd parties
	if {[OT_CfgGet ENABLE_3RD_PARTY_CREDIT 0]} {
		set include_credit "Y"
	} else {
		set include_credit "N"
	}

	#-------------------------------------------------
	# insert the external transfer with unknown status
	if {[catch {
		set rs [ob_db::exec_qry playtech::insert_transfer\
			$system\
			$cust_id\
			$currency\
			$amount\
			$remote_action\
			$unique_id\
			$desc\
			$source\
			$include_credit]
	} msg]} {
		_log ERROR {error inserting transaction: $msg}
		if {[regexp {Insufficient funds to make this transfer} $msg]} {
			_set_status ERROR PT_ERR_INSUFFICIENT_FUNDS
		} elseif {[regexp {Customer has bad debt status} $msg]} {
			_set_status ERROR PT_ERR_BAD_DEBT_STATUS
		} else {
			_set_status ERROR [_get_code]
		}
		return
	}
	_log DEBUG {Playtech successfully attempted pInsXSysXfer}
	set xfer_id     [db_get_coln $rs 0 0]
	set xfer_exists [db_get_coln $rs 0 1]
	ob_db::rs_close $rs

	if {$xfer_exists} {
		_set_status ERROR PT_ERR_TRANSFER_EXISTS
		return
	}

	# Playteach needs the id to have alpha chars in it so tag on "pt"
	set externaltranid "${xfer_id}pt"

	#----------------------------------------------------------------------
	# determine if this is a deposit or withdrawal and make amount positive
	if {$amount < 0} {
		set script externaldeposit.php
		set amount [expr {0 - $amount}]
	} else {
		set script externalwithdraw.php

		# If withdrawal, do we need to check for large returns as well?
		if {$CONFIG(chk_large_returns)} {
			if {![_check_large_returns $system $xfer_id]} {
				_log ERROR {error checking large returns. Unable to complete transfer}
				_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
				return
			}
		}

		# If withdrawal, promocodes are not valid
		set promocode ""
	}

	#-------------------------
	# call playtech php script
	foreach param [list username password currency amount externaltranid] {
		lappend parameters [list $param [set $param]]
	}

	lappend parameters [list secretkey $CONFIG($system,xfer_secret_key)]

	# If we have a promocode, add it to the parameters list
	if {$promocode != ""} {
		lappend parameters [list promocode $promocode]
	}

	eval call $system $script $parameters

	#--------------------------------------------------------------------------
	# decide upon a return value and update the transfer status in the database
	if {![catch {set status [response status]}]
		&& ($status == "approved" || $status == "declined")} {

		# we know for definite the outcome of the call, so we can make the appropriate
		# update to the external transfer in the database
		array set XSYS_XFER_STATUS_CODES {approved G declined B}
		set xsys_xfer_status_code $XSYS_XFER_STATUS_CODES($status)

		if {[catch {ob_db::exec_qry playtech::update_transfer $xfer_id $xsys_xfer_status_code $externaltranid} msg]} {
			_log ERROR {error updating transaction: $msg}
			_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
		} else {
			if {[status] == "OK" && $status != "approved"} {
				# I'm not sure if this can happen, but this means that the status
				# of the call is OK, but the status element of the response is not
				# 'approved'. We want to modify the status in this case, otherwise
				# we would have a status of OK when the transaction has failed
				_overide_status ERROR [_get_code $script]
			}
		}

	} else {
		# we don't know what happend so we leave the transfer status as unknown
		# and set a suitable status/message code
		_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
	}

	return $xfer_id
}



proc get_playerinfo {username password system} {
	call $system \
		get_playerinfo.php \
		"username $username" \
		"password $password"
}


proc get_balance {username password system} {
	set additional_fields [join [OT_CfgGet PT_BALANCE_ADD_FIELDS \
									{declineable_winnings declineable_bonuses}] ";"]

	if {$system == "PlaytechCasino"} {
		call $system \
			get_balance.php \
			"username           $username"          \
			"password           $password"          \
			"additional_fields  $additional_fields"
	} else {
		call $system \
			get_balance.php \
			"username           $username" \
			"password           $password"
	}
}


proc web_cashier_login {system username password clienttype} {

	variable CONFIG
	_reset

	set parameters [list "{casino} $CONFIG($system,casino)"]

	foreach param [list username password clienttype] {
		if {[set $param] != ""} {
			lappend parameters [list $param [set $param]]
		}
	}

	eval call $system {HTMLLayout/WebCashierLogin.php} $parameters

}


proc web_cashier_get_balance {system wcusersessionid amount} {
	
	variable CONFIG
	_reset

	set parameters [list {{mode} {check_balance}} \
	                     {{script} {poker_ipointsgift}} \
	                     {{clienttype} {poker}} \
	                     "{amount} ${amount}" \
	                     "{wcusersessionid} ${wcusersessionid}" \
	                     "{casino} $CONFIG($system,casino)"]

	eval call $system {HTMLLayout/CashierProxy.php} $parameters
}


proc web_cashier_redeem_ipoints {system wcusersessionid firstname lastname country amount} {
	
	variable CONFIG
	_reset

	set parameters [list {{mode} {make_transaction}} \
	                     {{script} {poker_ipointsgift}} \
	                     {{clienttype} {poker}} \
	                     {{address} {Address}} \
	                     {{city} {City}} \
	                     {{state} {State}} \
	                     {{zip} {Zip}} \
	                     {{productcode} {cash}} \
	                     {{productname} {iPoints}} \
	                     {{quantity} {1}} \
	                     "{casino} $CONFIG($system,casino)" \
	                     "{wcusersessionid} ${wcusersessionid}" \
	                     "{firstname} ${firstname}" \
	                     "{lastname} ${lastname}" \
	                     "{country} ${country}" \
	                     "{amount} ${amount}"]

	eval call $system {HTMLLayout/CashierProxy.php} $parameters
}


proc web_cashier_add_ipoints_bonus {system username amount} {

	variable CONFIG
	_reset

	set parameters [list "{username}  ${username}"\
	                     "{amount}    ${amount}"\
	                     "{bonus}     $CONFIG($system,remote_bonus_bonus)"\
	                     "{admin}     $CONFIG($system,remote_bonus_admin_username)"\
	                     "{password}  $CONFIG($system,remote_bonus_admin_password)"\
	                     "{casino}    $CONFIG($system,casino)"]

	eval call $system {remote_bonus.php} $parameters

}

# this doesn't require the old username
proc change_password {username new_pwd system} {

	ob_log::write ERROR {system:$system username: $username new_pwd: $new_pwd}

	call $system\
		change_password.php \
		"newpassword $new_pwd" \
		"username $username"
}



# check the status of a transaction
# ONLY called from unknown_xfer_handler script
# logging is different
proc checktransaction {system username externaltranid xfer_id} {

	variable CONFIG

	_reset

	# do we need to check for large returns as well?
	if {$CONFIG(chk_large_returns)} {
		if {![_check_large_returns $system $xfer_id]} {
			_log ERROR {error checking large returns. Unable to complete transfer}
			_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
			return [list ERROR]
		}
	}


	# first, do the call for the transaction
	call $system \
		checktransaction.php \
		"username $username" \
		"externaltranid $externaltranid"

	# get the status
	set status [playtech::status]

	# is it ok?
	if {$status != "OK"} {
		# there was a problem - exit
		return [list ERROR]
	}

	set response_status [string toupper [playtech::response status]]
	set response_id     [playtech::response id]
	set remote_ref      $externaltranid

	# remove pt from externaltranid
	set externaltranid [string trim $externaltranid pt]


	switch -exact -- $response_status {
		"APPROVED" {
			# payment was successful on the playtech side. Update openbet
			# to reflect this.

			if {[catch {
				ob_db::exec_qry playtech::update_transfer $externaltranid G $remote_ref
			} msg]} {
				_log ERROR {error updating transaction $externaltranid to G: $msg}
				_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
			} else {
				_log INFO {updated transaction $externaltranid to G}
			}
		}
		"DECLINED" {
			# payment was failed on the playtech side. Update openbet
			# to reflect this.


			if {[catch {
				ob_db::exec_qry playtech::update_transfer $externaltranid B $remote_ref
			} msg]} {
				_log ERROR {error updating transaction $externaltranid to B: $msg}
				_overide_status UNKNOWN PT_ERR_TRANSFER_STATUS_UNKNOWN
			} else {
				_log INFO  {updated transaction $externaltranid to B}
			}
		}
		"WAITING" -
		"MISSING" {
			_log DEV  {transaction $externaltranid has status $response_status. \
			           Leaving openbet payment status as UNKNOWN.}
		}
		default {
			# we got an unknown response
			_log INFO  {unknown response for payment}
		}
	}
}



# this requires the old username
proc change_pwd {username old_password new_password system} {
	call $system \
	         change_pwd.php \
		"oldpwd $old_password" \
		"newpwd $new_password" \
		"username $username"
}

proc check_playtech_login { system channel username logintoken } {
	set fn "playtech::check_playtech_login"

	# We dont have enough information for the check_logintoken API.
	if {$username == "" || $logintoken == "" || $system == ""} {
		return 0
	}

	playtech::check_logintoken $system $username $logintoken

	set code [playtech::status]

	if {$code != "OK"} {
		return 0
	}

	# at this point we know that token is ok, so we can log the user into
	# openbet.

	if {[catch {set rs [ob_db::exec_qry playtech::get_cust_details $username]} msg]} {
		ob_log::write CRITICAL {$fn : Failed to execute get_cust_details qry. $msg}
		return 0
	}

	if {[db_get_nrows $rs] != 1} {
		ob_db::rs_close $rs
		return 0
	}

	set cust_id  [db_get_col $rs 0 cust_id]
	set enc_pwd  [db_get_col $rs 0 password]
	ob_db::rs_close $rs

	# Playtech have authenticated the token.
	# Log the customer into Openbet (full DB login + fill in package cache. Login cookies
	# will not yet be set)
	set status [ob_login::get login_status]

	if {$status != "OB_OK"} {
		set status [ob_login::form_login\
			W\
			$username\
			$enc_pwd\
			[ob_login::get_uid]\
			""\
			$channel\
			1\
			1]
	}

	if {$status != "OB_OK"} {
		return 0
	}

	return 1
}

# This is for a one time only token login
proc check_logintoken {
	system
	username
	logintoken
	{invalidate 1}
} {
	_auto_reset

	call $system \
		check_logintoken.php\
		"username $username"\
		"logintoken $logintoken"\
		"invalidate $invalidate"
}


#
# returns avail_funds_in_table/avail_funds_in_tourn
# for user. In theory can expand this to use multiple usernames
# which the API handles.
#
proc get_playerfunds {system username} {

	variable CONFIG

	call $system \
		getplayerfunds.php \
		"usernames $username" \
		"admin $CONFIG($system,admin_username)" \
		"password $CONFIG($system,admin_password)"
}


#
#
#
proc get_report {
	system
	reportcode
	action
	casino
	startdate
	enddate
	{username ""}} {

	variable CONFIG

	_reset

	set parameters [list "admin $CONFIG($system,admin_username)"\
	                     "password $CONFIG($system,admin_password)"\
	                     "action $action"\
	                     "reportcode $reportcode"\
	                     "casino $casino"\
	                     "startdate $startdate"\
	                     "enddate $enddate"]

	if {$username != ""} {
		lappend parameters [list username $username]
	}

	eval call $system report_view.php $parameters
}


proc response {parameter args} {
	variable RESPONSE

	_auto_reset

	if {[info exists RESPONSE($parameter)]} {
		_log DEV {fetching parameter:$parameter = $RESPONSE($parameter)}
		return $RESPONSE($parameter)
	} else {
		# If there's a default use it.
        if {[llength $args] == 1} {
            return [lindex $args 0]
        }

		set msg "no value exists in the playtech response for parameter:$parameter"
		_log WARNING {$msg}
		error $msg
	}
}



proc status {} {
	variable STATUS

	_auto_reset

	if {![info exists STATUS(status)]} {
		error "invalid state: must make a playtech call before calling playtech::status"
	}
	return $STATUS(status)
}



proc code {} {
	variable STATUS

	_auto_reset

	if {![info exists STATUS(status)]} {
		error "invalid state: must make a playtech call before calling playtech::code"
	}
	set status $STATUS(status)
	if {$status == "OK"} {
		error "called playtech::code when status is OK. \
		Only call this command when status is UNKNOWN or ERROR"
	}
	return $STATUS(code)
}



proc encodeid {username password cur_date system} {

	variable CONFIG
	variable INIT

	if {!$INIT} {
		init
	}

	set key $CONFIG($system,playtech_key)

	set tmpstr [join [list [urlencode $username] [urlencode $password] [urlencode $cur_date]] "&"]
	set c0 [expr {int(rand() * 255)}]

	set outstr [format "%02x" $c0]

	for {set i 0} {$i < [string length $tmpstr]} {incr i} {
		set ci [expr {
			[scan [string index $tmpstr $i] "%c"] ^ \
			[scan [string index $key [expr { $i %  [string length $key]}]] "%c"] ^ \
			$c0
		}]
		append outstr [format "%02x" $ci]
	}

	return $outstr
}



#  crude "PING" to Playtech (used by the queue)
proc ping {system} {

	variable STATUS

	_reset

	set host [_get_host_db $system]

	set request [::ob_socket::format_http_req -host $host \
			-method "POST" \
			-form_args "" \
			-urlencode_unsafe 1\
			$host]

	regsub -all {(https://)} $host {} host

	set response [_send_request $system $host $request]

	if {[info exists STATUS(code)] && $STATUS(code) == "PT_ERR_CONNECT_FAILED"} {
		set ping 0
	} else {
		set ping 1
	}

	_log INFO "**** PING for $system **** $ping"

	return $ping
}



#
# private procedures
#

#
# _make_url
#
# make a URL string
#
proc _make_url {system script args} {
	variable SCRIPTS
	variable CONFIG

	#---------------------------------------------------------------
	# find out which parameters need to be submitted for this script
	if {[info exists SCRIPTS($script,mandatory)]} {
		set mandatory_parameters $SCRIPTS($script,mandatory)
	} else {
		return [list "ERROR_PLAYTECH_URL"]
	}

	if {[info exists SCRIPTS($script,optional)]} {
		set optional_parameters $SCRIPTS($script,optional)
	} else {
		set optional_parameters [list]
	}

	#-----------------------------------------------------------------
	# setup the input parameters filling in missing ones with values from CONFIG
	foreach arg $args {
		set PARAMS([lindex $arg 0]) [join [lrange $arg 1 end] " "]
	}
	foreach param $mandatory_parameters {
		if {[info exists PARAMS($param)]} {
			# do nothing
		} elseif {[info exists CONFIG($system,$param)]} {

			set PARAMS($param) $CONFIG($system,$param)

		} else {
			_log ERROR {Missing param=$param}
			return [list "ERROR_PLAYTECH_URL"]
		}
	}

	foreach param $optional_parameters {
		if {![info exists PARAMS($param)] && [info exists CONFIG($system,$param)]} {
			set PARAM($param) $CONFIG($system,$param)
		}
	}

	#---------------------------------------------------
	# construct URL string from the parameters available
	foreach param [concat $mandatory_parameters $optional_parameters] {
		if {[info exists PARAMS($param)]} {
			# Do we need to send the hashed pwd to Playtech?
			if {$CONFIG(send_hashed_pwd) && $script != "remote_bonus.php" && $script != "HTMLLayout/WebCashierLogin.php" && $script != "getplayerfunds.php" && $script != "report_view.php" && [lsearch {password1 password2 newpassword oldpwd newpwd sync_password password} $param] != -1} {
				set PARAMS($param) [md5 $PARAMS($param)]
			}

			lappend parameters $param $PARAMS($param)

			# Log out params (mask sensitive data).
			switch $param {
				password -
				secretkey {
					_log INFO {$param=xxxxxx}
				}
				default {
					_log INFO {$param=$PARAMS($param)}
				}
			}
		}
	}

	if {![info exists PARAMS(host)]} {
		if {[lsearch { "getplayerfunds.php" "report_view.php" } $script] != -1} {
			set host $CONFIG($system,admin_url)
		} elseif {$script == "remote_bonus.php"} {
			set host $CONFIG($system,remote_bonus_admin_url)
		} else {
			set host [_get_host_db $system]
		}
	}

	# If we're using locations, then we need to set the URL to the relevant path
	if {[info exists SCRIPTS($script,location)] && $CONFIG(use_locations)} {
		set location $SCRIPTS($script,location)
		_log INFO {host = $host location = $location script = ${script}}
		return [list "OK" "${host}/${location}/${script}" $parameters]
	} else {
		_log INFO {host = $host script = ${script}}
		return [list "OK" "${host}/${script}" $parameters]
	}
}



#
# _send_request
#
# send the request and deal with timeouts etc
#
proc _send_request {system host request} {
	variable CONFIG
	variable REQCONFIG

	regsub -all {(secretkey=)[^&]*&} $request     {\1******} log_request
	regsub -all {(password=)[^&]*&}  $log_request {\1******} log_request

	set header [list "Content-Type" "text/html"  "Cache-Control" "no-cache"]
	_log INFO {**** request ****\n$host $log_request\n}

	# Determine timeouts in 2 ways determined in the configure_request call
	# critical or non critical request is set --> use config in DB
	# timeout is specified in the call --> use that instead

	if {[info exists REQCONFIG(is_critical_request)] &&
	    $REQCONFIG(is_critical_request) == "N"} {
		set crit "noncritical"
	} else {
		set crit "critical"
	}

	# determine response timeout
	if {[info exists REQCONFIG(forced_req_timeout)]} {
		set resp_timeout $REQCONFIG(forced_req_timeout)
		_log DEBUG {using REQCONFIG(forced_req_timeout) = $resp_timeout}
	} elseif {[info exists CONFIG(${system},${crit}_response_timeout)]} {
		set resp_timeout $CONFIG(${system},${crit}_response_timeout)
		_log DEBUG {using CONFIG(${system},${crit}_response_timeout) = $resp_timeout}
	} else {
		set resp_timeout $CONFIG($system,playtech_timeout)
		_log DEBUG {$crit, but using cfg file resp_timeout = $resp_timeout}
	}

	# determine connection timeout
	if {[info exists REQCONFIG(forced_conn_timeout)]} {
		set conn_timeout $REQCONFIG(forced_conn_timeout)
		_log DEBUG {using REQCONFIG(forced_conn_timeout) = $conn_timeout}
	} elseif {[info exists CONFIG(${system},${crit}_connection_timeout)]} {
		set conn_timeout $CONFIG(${system},${crit}_connection_timeout)
		_log DEBUG {using CONFIG(${system},${crit}_connection_timeout) = $conn_timeout}
	} else {
		set conn_timeout $CONFIG($system,playtech_timeout)
		_log DEBUG {$crit, but using cfg file conn_timeout = $conn_timeout}
	}

	# If the timeout is set to 0 then we shouldn't even attempt to make the
	# request to playtech.
	# The purpose of this is so that non-critical requests (such as displaying
	# the playtech balance to the user) can be switched off.
	#
	# Once the new socket code has been plugged in, we will need to tweak this
	# (since the connect/response timeouts will be split out; and in order to
	# make sure that we are setting the correct status).
	if {$conn_timeout == 0 || $resp_timeout == 0} {
		_log INFO {timeout set to 0 - not making request}
		_force_decline
		return
	}

	set conn_timeout [expr {int($conn_timeout)}]
	set resp_timeout [expr {int($resp_timeout)}]

	set response {}
	set server_processed {}

	foreach {req_id status complete} [::ob_socket::send_req\
	                                         -conn_timeout $conn_timeout\
	                                         -req_timeout  $resp_timeout\
	                                         -tls          {}\
	                                         -is_http      1\
	                                         $request $host 443] {break}
	if {$status == "OK"} {
		set response [::ob_socket::req_info $req_id http_body]
	}
	set server_processed [::ob_socket::server_processed $req_id]
	::ob_socket::clear_req $req_id

	if {$status == "OK"} {
		set status O
	} else {
		#
		# If the server definately hasn't processed the request, give an error.
		# Otherwise, set status as unknown.

		if {$server_processed == 0} {
			_force_decline
			return
		}

		_set_status UNKNOWN
		return
	}

	return $response
}



#
# _process_response
#
# process the xml that is returned from a script
#
proc _process_response {script body} {
	variable RESPONSE

	_log INFO {**** response ****\n$body}
	if {[catch {
		set doc [dom parse $body]
		set xml [$doc documentElement]
	} msg]} {
		_log ERROR {error:unable to interpret the response}
		catch {$doc delete}
		_set_status UNKNOWN
		return
	}

	set RESPONSE(xml) $body

	#----------------------------
	# populate the RESPONSE array
	set nodes [$xml selectNodes /*/*]
	if {[llength $nodes] == 0 && $script != "report_view.php"} {
		_log ERROR {error:response appears to be empty}
		$doc delete
		_set_status UNKNOWN
		return
	}

	foreach node $nodes {
		# record the text contained within the element
		_log DEV {setting RESPONSE([$node nodeName]):[$node text]}
		set RESPONSE([$node nodeName]) [$node text]
		# record the names and values of any attributes
		set attributes [$node selectNodes @*]
		foreach attribute $attributes {
			_log DEV {setting RESPONSE([$node nodeName],[lindex $attribute 0]):[lindex $attribute 1]}
			set RESPONSE([$node nodeName],[lindex $attribute 0]) [lindex $attribute 1]
		}

		# need to check sub-nodes
		set sub_nodes [$xml selectNodes /*/[$node nodeName]/*/*]

		if {[llength $sub_nodes ] != 0} {
			foreach sub_node $sub_nodes {
				_log DEV {setting RESPONSE([$node nodeName],[$sub_node nodeName]):[$sub_node text]}
				set RESPONSE([$node nodeName],[$sub_node nodeName]) [$sub_node text]
			}
		}
	}

	#------------------------------------
	# decide upon the status of this call
	switch -exact $script {
		externaldeposit.php  -
		externalwithdraw.php -
		checktransaction.php -
	 	get_playerinfo.php   {
			# for these three scripts, we return status OK if there is a status element and no error element
			if {[info exists RESPONSE(status)] && ![info exists RESPONSE(error)]} {
				_set_status OK
			} else {
				_set_status ERROR [_get_code $script]
			}
		}
		getplayerfunds.php {
			# for this script, we return OK if there is a result
			if {[info exists RESPONSE(result,code)] && $RESPONSE(result,code) == 0} {
				_set_status OK
			} else {
				_set_status ERROR [_get_code $script]
			}
		}
		report_view.php {
			if {[info exists RESPONSE(xml)]} {
				_set_status OK
				#_set_status ERROR [_get_code $script]
			} else {
				_set_status ERROR [_get_code $script]
			}
		}
		get_balance.php {
			if {[info exists RESPONSE(balance)]} {
				_set_status OK
				#_set_status ERROR [_get_code $script]
			} else {
				_set_status ERROR [_get_code $script]
			}
		}
		default {
			# for all the other scripts, a successful response is indicated
			# by the result attribute of the transaction element
			if {[catch {set result $RESPONSE(transaction,result)} msg]} {
				_log INFO {unable to retrieve result attribute from transaction element}
				$doc delete
				_set_status UNKNOWN
				return
			}

			if {$result == "OK"} {
				_set_status OK
			} else {
				_set_status ERROR [_get_code $script]
			}
		}
	}

	$doc delete

	ob_log::write_array ERROR RESPONSE
}



#
# _get_code
#
# try to get a meaningful translatable code from the response
# in the case of scripts returning an error
#
proc _get_code {{script ""}} {
	variable RESPONSE
	variable ERRORS

	# see if the response contains an error code
	#
	# the error code is sometimes stored as the nr attribute of the error element:
	#      <newplayer><error nr="18">Requested username already in use</error></newplayer>
	# it may also be the text within the error element
	#      <externaldeposit><error>1</error></externaldeposit>
	if {[info exists RESPONSE(error,nr)] && [string is integer $RESPONSE(error,nr)]} {
		set error_code $RESPONSE(error,nr)
	} elseif {[info exists RESPONSE(error)] && [string is integer $RESPONSE(error)]} {
		set error_code $RESPONSE(error)
	} elseif {[info exists RESPONSE(result,code)] && [string is integer $RESPONSE(result,code)]} {
		set error_code $RESPONSE(result,code)
	}

	if {[info exists error_code]} {
		# we have an error code, see if we have a corresponding error message
		if {[info exists ERRORS($script,$error_code)]} {
			# we have an error message specific to this script that we can return
			set rtn $ERRORS($script,$error_code)
		} elseif {[info exists ERRORS($error_code)]} {
			# we have a message code to return
			set rtn $ERRORS($error_code)
		} else {
			# just return the default error message, we can't find anything more useful
			set rtn $ERRORS(default)
		}
	} else {
		# no error code, just return the default error message
		set rtn $ERRORS(default)
	}

	return $rtn
}



#
# _set_status
#
# set the status of the current call
#
proc _set_status {status {code ""} {overide 0}} {
	variable STATUS

	_log INFO {setting status to $status}

	if {!$overide && ![catch {status}]} {
		error "status is already set to [status]"
	}

	switch $status {
		"OK" {
			# we don't need to set an error code
		}
		"ERROR" {
			if {$code == ""} {
				set code PT_ERR_DEFAULT
			}
			set STATUS(code) $code
			_log INFO {setting code to $code}
		}
		"UNKNOWN" {
			if {$code == ""} {
				set code PT_ERR_REQUEST_FAILED
			}
			set STATUS(code) $code
			_log INFO {setting code to $code}
		}
		default {
			error "invalid status:$status"
		}
	}

	set STATUS(status) $status
}



#
# _set_status
#
# set the status without throwing an error if it is already set
#
proc _overide_status {status {code ""}} {

	_set_status $status $code 1
}

#
# _force_decline
#
# This is called when we know that the request never made it to playtech
# it forces a decline (so that the payment is refunded if necessary),
# but sets an appropriate error code so that we can differentiate this with
# an actual decline from playtech.
#
proc _force_decline {} {
	variable RESPONSE
	set RESPONSE(status) declined
	_set_status ERROR PT_ERR_CONNECT_FAILED
}



#
# _process_details
#
# used when registering or updating customers
#
proc _process_details {} {
	variable CONFIG

	foreach param {
		fname
		lname
		address
		addr_cty
		addr_1
		addr_2
		addr_3
		addr_4
		state
		countrycode
		addr_pc
		email
		contact_ok
		contact_how
		chkEmail
		telephone
		title
		dob
	} {
		upvar $param $param
	}

	# set the wantEmail based on contact_how and contact_ok
	if {($contact_ok == "Y") && ([string first "E" $contact_how] != -1) } {
		set chkEmail 1
	} else {
		set chkEmail 0
	}

	# base sex on title
	#set sex "M"
	#set female_titles {Ms Miss Mrs}
	#if {[lsearch $female_titles $title] != -1} {
	#		set sex "F"
	#}

	# country codes in tCountry that need changing to the Playtech version
	array set COUNTRYCODES {
		-- GB
		TP TL
		GG GB
		IM GB
		JE GB
		YU CS
		UK GB
	}
	if {[info exists COUNTRYCODES($countrycode)]} {
		   set countrycode $COUNTRYCODES($countrycode)
	}

	####
	# This is for RFC394, we filter what we send for certain fields
	####

	# city
	regsub -all {[^A-Za-z\-\s]} $addr_cty {} addr_cty
	if {[string length $addr_cty] > 50} { set addr_cty [string range $addr_cty 0 49] }
	if {[string length $addr_cty] < 3} { set addr_cty "Blank" }

	# addr_1
	regsub -all {[^A-Za-z0-9_\-,\.&#\s\n\r\t]} $addr_1 {} addr_1
	if {[string length $addr_1] > 160} { set addr_1 [string range $addr_1 0 159] }
	if {[string length $addr_1] < 1} { set addr_1 "" }

	# addr_2
	regsub -all {[^A-Za-z0-9_\-,\.&#\s\n\r\t]} $addr_2 {} addr_2
	if {[string length $addr_2] > 160} { set addr_2 [string range $addr_2 0 159] }
	if {[string length $addr_2] < 3} { set addr_2 "" }

	# addr_3
	regsub -all {[^A-Za-z0-9_\-,\.&#\s\n\r\t]} $addr_3 {} addr_3
	if {[string length $addr_3] > 160} { set addr_3 [string range $addr_3 0 159] }
	if {[string length $addr_3] < 3} { set addr_3 "" }

	# addr_4
	regsub -all {[^A-Za-z0-9_\-,\.&#\s\n\r\t]} $addr_4 {} addr_4
	if {[string length $addr_4] > 160} { set addr_4 [string range $addr_4 0 159] }
	if {[string length $addr_4] < 3} { set addr_4 "" }

	if {[OT_CfgGet PLAYTECH_DO_LONG_CONCAT 0]} {
		set address "$addr_1, $addr_2, $addr_3, $addr_4, $addr_cty"
	} else {
		set address "$addr_1, $addr_2, $addr_3, $addr_4"
	}

	# address
	regsub -all {[^A-Za-z0-9_\-,\.&#\s\n\r\t]} $address {} address
	if {[string length $address] > 160} { set address [string range $address 0 159] }
	if {[string length $address] < 3} { set address "Blank" }

	# birth date
	regsub -all {[^0-9\-\\]} $dob {} dob
	if {$dob != ""} {
		set year [string range $dob 0 3]
	} else {
		set year ""
	}
	if {[string length $year] != 4 || $year < 1900} {
		set dob $CONFIG(defaults,dob)
	}

	# countrycode
	if {$countrycode == "" || $countrycode == "--"} {
		set countrycode "UK"
	}

	# email
	if {$email == "" || [string first "@" $email] == -1} {
		set email $CONFIG(defaults,email)
	}

	# state
	if {![info exists state] || ([info exists state] && $countrycode != "USA")} {
		set state ""
	}

	# firstname
	regsub -all {[^A-Za-z\-,\.\s]} $fname {} fname
	if {[string length $fname] > 50} { set fname [string range $fname 0 49] }
	if {[string length $fname] < 1} { set fname "Player" }

	# lastname
	regsub -all {[^A-Za-z\-,\.\s]} $lname {} lname
	if {[string length $lname] > 50} { set lname [string range $lname 0 49] }
	if {[string length $lname] < 1} { set lname "Player" }

	# phone
	regsub -all {[^0-9\.\+\-\(\)\s]} $telephone {} telephone
	if {[string length $telephone] > 20} { set telephone [string range $telephone 0 19] }
	if {[string length $telephone] < 6} { set telephone $CONFIG(defaults,telephone)  }

	# title
	regsub -all {[^A-Za-z\-,\.\s]} $title {} title
	if {[string length $title] > 25} { set title [string range $title 0 24] }

	# zip
	regsub -all {[^A-Za-z0-9\-\s]} $addr_pc {} addr_pc
	if {[string length $addr_pc] > 12} { set addr_pc [string range $addr_pc 0 11] }
	if {[string length $addr_pc] == 0} { set addr_pc $CONFIG(defaults,postcode) }

	# code below removed since RFC 394
	# Strip specific characters from first name and city as Playtech regards
	# them as illegal characters and will reject the request.
	#set illegal_chars    {(\d)|(!)|(\$)|(@)|(#)|(%)|(\()|(\))|(_)|(,)|}
	#append illegal_chars {(=)|(\+)|(\{)|(\})|(\[)|(\])|(\|)|(\\)|(\^)|}
	#append illegal_chars {(<)|(>)|(\.)|(\?)|(\/)|(:)|(;)|(\")|(~)|(')|(&)}

	#regsub -all $illegal_chars $fname    {} fname
	#regsub -all $illegal_chars $addr_cty {} addr_cty
}



#
# _bind_config
#
# set up config variables from database
#
proc _bind_config {args} {

	variable CONFIG
	variable ERRORS

	set CONFIG(systems) [list]

	foreach sys_name [OT_CfgGet PLAYTECH_SYSTEMS {}] {

		lappend CONFIG(systems) $sys_name

		set rs [ob_db::exec_qry playtech::get_system_config $sys_name]

		set nrows [db_get_nrows $rs]

		if {!$nrows} {
			error "Invalid system provided: $sys_name"
		}

		for {set r 0} {$r<[db_get_nrows $rs]} {incr r} {
			set name  [string tolower [db_get_col $rs $r config_name]]
			set value [db_get_col $rs $r config_value]
			set CONFIG($sys_name,$name) $value
			_log DEBUG {setting CONFIG($sys_name,$name) $value}
		}

		ob_db::rs_close $rs

	}

	# Miscellaneous non sys specific config
	array set ERRORS [OT_CfgGet PLAYTECH_ERRORS]

	set CONFIG(send_hashed_pwd)   [OT_CfgGet PLAYTECH_SEND_HASHED_PWD 0]
	set CONFIG(use_locations)     [OT_CfgGet PLAYTECH_USE_LOCATIONS 0]
	set CONFIG(chk_large_returns) [OT_CfgGet PLAYTECH_CHK_LARGE_RETURNS 0]

	# set up default values
	foreach {name dflt} [list \
		email       noname@noname.com \
		dob         1970-01-01 \
		telephone   0123456789 \
		postcode    AB1CD2 \
	] {
		set CONFIG(defaults,$name) \
			[OT_CfgGet PLAYTECH_DEFAULT_[string toupper $name] $dflt]
	}

}



# Carry out some large returns checks
#
#    xfer_id  - id of the transfer to link the check too (event though the
#               xfer is not the direct cause of the large return)
#
#   return - 1 if successsfully checked, 0 if not
#
proc _check_large_returns {system xfer_id} {

	set fn "_check_large_returns"

	# load customer information
	if {[catch {set rs [ob_db::exec_qry playtech::get_large_return_details $xfer_id]} msg]} {
		_log ERROR {$fn error loading customer details: $msg}
		return 0
	}

	if {![db_get_nrows $rs]} {
		_log ERROR {$fn customer details not found}
		return 0
	}

	set acct_id   [db_get_col $rs 0 acct_id]
	set system_id [db_get_col $rs 0 system_id]
	set username  [db_get_col $rs 0 username]
	set password  [db_get_col $rs 0 password]
	ob_db::rs_close $rs

	playtech::get_playerinfo $username $password $system

	if {[status] == "OK"} {

		set held_funds [response heldfundsamount 0]

		if {[catch {set rs [ob_db::exec_qry playtech::chk_large_returns $held_funds $acct_id $system_id $xfer_id]} msg]} {
			_log ERROR {$fn error checking large returns: $msg}
			return 0
		}

		set result [db_get_coln $rs 0 0]
		ob_db::rs_close $rs

		if {$result} {
			# try to clear held funds balance (if fails don't worry -
			# we'll just end up adding another flag on next xfer and clear then)
			_reset

			eval call $system \
				change_player.php [list \
					"sync_username $username" \
					"sync_password $password" \
					"releaseheldfunds 1" \
				]

			if {[status] != "OK"} {
				_log ERROR \
					{$fn Failed to clear held funds balance for: $username}
			}
		}

		return 1

	} else {
		_log ERROR \
			{$fn error checking large returns - get_playerinfo call failed: [code]}
		# unable to check large returns - bail out
		return 0
	}
}



# Accessor for Playtech configuration items
#
proc get_cfg {name} {

	variable CONFIG
	variable INIT

	if {!$INIT} {
		init
	}

	return $CONFIG($name)

}



# Config values can also be set/overridden by values from the database,
# stored in tXSysHostConfig.
#
# This allows some config values (such as timeouts) to be changed on the fly
# without having to restart the application(s).
#
# Hence this procedure is called every time we make a call to playtech.
#
#   CRITICAL_CONNECTION_TIMEOUT
#   NONCRITICAL_CONNECTION_TIMEOUT
#   CRITICAL_RESPONSE_TIMEOUT
#   NONCRITICAL_RESPONSE_TIMEOUT
#   DISPLAY_BALANCE
#
#    - Timeout values are given in seconds.
#    - Critical timeouts are for critical requests such as funds transfer.
#    - Non-critical timeouts are for non-critical requests such as checking
#      the balance to display to the user.
#    - Connection timeout is the timeout for making a connection to playtech
#    - Response timeout is the timeout for getting a response back from
#      playtech (once we have submitted our request).
#    - If the applicable connection or request timeout is set to 0 then we
#      won't even attempt to make the request.  This is useful for non-critical
#      requests such as balance display.
#

# Getting the system name from the database

proc _get_host_db {system} {

	if {[catch {
		set rs [ob_db::exec_qry playtech::get_host $system]
	} msg]} {
		_log ERROR {error getting host from db: $msg}
		return
	}
	for {set r 0} {$r<[db_get_nrows $rs]} {incr r} {
		set url [string tolower [db_get_col $rs $r url]]
	}
	ob_db::rs_close $rs
	return $url
}



#
# _store_queries
#
# called on startup
#
proc _store_queries {} {

	ob_db::store_qry playtech::insert_transfer {
		execute procedure pInsXSysXfer (
			p_system_name      = ?,
			p_cust_id          = ?,
			p_ccy_code         = ?,
			p_amount           = ?,
			p_remote_action    = ?,
			p_local_unique_id  = ?,
			p_desc             = ?,
			p_status           = 'U',
			p_bm_acct_type     = 'MAN',
			p_channel          = ?,
			p_include_credit   = ?
		)
	}

	ob_db::store_qry playtech::update_transfer {
		execute procedure pUpdXSysXfer (
			p_xfer_id          = ?,
			p_status           = ?,
			p_remote_ref       = ?
		)
	}

	ob_db::store_qry playtech::get_affiliate {
		select
			f.flag_value
		from
			tCustomerFlag f,
			tCustomer c
		where
			c.cust_id = f.cust_id
		and c.username = ?
		and f.flag_name = 'PlaytechAff'
	}

	ob_db::store_qry playtech::get_system_config {
		select
			c.config_name,
			c.config_value
		from
			tXSysHost h,
			tXSysHostConfig c
		where
			c.system_id = h.system_id and
			h.name      = ?
	} 60


	 ob_db::store_qry playtech::get_host {
	   select first 1 url
	   from tXSysHost
	   where name = ?
	 }

	# get details needed for large returns check
	ob_db::store_qry playtech::get_large_return_details {
		select
			x.acct_id,
			x.system_id,
			c.username,
			c.password
		from
			tXSysXfer  x,
			tAcct      a,
			tCustomer  c
		where
			x.xfer_id = ?          and
			x.acct_id = a.acct_id  and
			a.cust_id = c.cust_id
	}

	ob_db::store_qry playtech::chk_large_returns {
		execute procedure pChkLargeReturns (
			p_amount       = ?,
			p_acct_id      = ?,
			p_product_area = 'XSYS',
			p_prod_ref_id  = ?,
			p_ref_id       = ?,
			p_is_sub       = 'N'
		)
	}

	ob_db::store_qry playtech::get_cust_details {
		select
			c.cust_id,
			c.password
		from
			tCustomer c
		where
			c.username = ?
	}

}



#
# _log
#
# log message with PLAYTECH prefix
#
# optionally obfuscate a portion of the message (specified by re parameter)
#
proc _log {level msg {re ""} {s "xxxxx"}} {
#regsub {secretkey=[^&]*&} $msg "xxxxx\\&"
	if {$re == ""} {
		ob_log::write $level {PLAYTECH:: [uplevel subst [list $msg]]}
	} else {
		ob_log::write $level {PLAYTECH:: [regsub $re [uplevel subst [list $msg]] $s]}
	}
}



#
# _reset
#
# reset everything
#
proc _reset {} {
	variable REQID
	variable RESPONSE
	variable STATUS
	variable INIT

	unset -nocomplain RESPONSE
	unset -nocomplain STATUS
	set REQID [reqGetId]

	if {!$INIT} {
		init
	}

	_bind_config

}



#
# _auto_reset
#
# make sure we can't access responses from previous requests
#

proc _auto_reset {} {
	variable REQID

	set reqid [reqGetId]

	if {![info exists REQID] || $reqid != $REQID} {
		_reset
	}
}


#close namespace
}
