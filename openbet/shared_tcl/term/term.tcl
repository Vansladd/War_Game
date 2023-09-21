# $Id: term.tcl,v 1.1 2011/10/04 12:27:28 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utilities to provide manage bet placement terminals
#
# Configuration:
#    TERM_KEY           terminal private encryption key
#
# Synopsis:
#    package require term_term ?4.5?
#
# Procedures:
#    ob_term::login     login a terminal based on the supplied ID:
#                       tAdminTerm.ident
#    ob_term::set_term  register the terminal by supplying the encrypted string
#    ob_term::get_term  get the tAdminTerm.term_code (must be called after
#                       either login or set_term
#

package provide term_term 4.5


# Dependencies
#
package require util_log 4.5
package require util_db 4.5



# Variables
#
namespace eval ob_term {

	variable KEY
	variable INIT
	variable TERM
	variable REQ_ID

	set INIT 0
}



#--------------------------------------------------------------------------
# Login
#--------------------------------------------------------------------------

# Log the terminal in given the tAdminTerm.ident string
#
#    ident   - tAdminTerm.ident
#    returns - encoding string of the format 'SALT|term_code|login_time'
#
proc ::ob_term::login { ident } {

	variable KEY
	variable TERM
	variable REQ_ID
	variable TERM_DETAILS

	array unset TERM_DETAILS

	ob_log::write INFO {TERM: logging in terminal $ident}
	_check_init

	set rs [ob_db::exec_qry ob_term::get_term_code $ident]
	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		ob_db::rs_close $rs
		error\
			"No terminals match this identity"\
			""\
			TERM_INVALID_IDENT
	} elseif {$nrows > 1} {
		ob_db::rs_close $rs
		error\
			"Terminal identity not unique"\
			""\
			TERM_DUPLICATE_IDENT
	}

	# OK so we have just one row
	set TERM   [db_get_col $rs 0 term_code]
	set status [db_get_col $rs 0 status]
	set time   [db_get_col $rs 0 time]
	ob_db::rs_close $rs

	#make sure the terminal is set up to be registered
	if {$status != "R"} {
		error\
			"Terminal $ident not set up to be registered"\
			""\
			TERM_NON_REG_STATE
	}

	#everything OK register termnial as active
	ob_db::exec_qry ob_term::login_term $TERM

	# encode string of the format
	# SALT|term_code|login_time
	set ip_addr [reqGetEnv REMOTE_ADDR]
	set str "[clock clicks]|$TERM|$ip_addr|$time"

	set enc [blowfish encrypt -hex $KEY -bin $str]
	set enc [convertto b64 -hex $enc]

	set REQ_ID [reqGetId]

	return $enc
}



#--------------------------------------------------------------------------
# Accessors
#--------------------------------------------------------------------------

# Register the terminal based on the encypted string produced from ::login
#
#   enc - Encrypted string returned from login
#
proc ::ob_term::set_term { enc } {

	variable KEY
	variable REQ_ID
	variable TERM
	variable TERM_DETAILS

	array unset TERM_DETAILS

	_check_init

	set str [blowfish decrypt -hex $KEY -b64 $enc]
	set str [hextobin $str]

	ob_log::write INFO {TERM: Decrypted string is $str key: $KEY enc:$enc}

	set l [split $str "|"]
	if {[llength $l] != 4} {
		error\
			"Invalid terminal string"\
			""\
			TERM_STR_INVALID
	}

	#compare the ip_addr of this request with the original
	set ip_addr [lindex $l 2]
	if {$ip_addr != [reqGetEnv REMOTE_ADDR]} {
		error\
			"TERM: registered from $ip_addr came from [reqGetEnv REMOTE_ADDR]"\
			""\
			TERM_DIFFERENT_IP
	}

	set TERM [lindex $l 1]
	set REQ_ID [reqGetId]
}



# Get the tAdminTerm.term_code for the registered application
# NB: ::login or ::set_term must be called first in the request
#
#   returns - tAdminTerm.term_code
#
proc ::ob_term::get_term {} {

	variable REQ_ID
	variable TERM

	set req [reqGetId]

	if {$req != $REQ_ID} {
		error\
			"Call login or set_term to set the term first"\
			""\
			TERM_NOT_SET
	}

	return $TERM
}

proc ::ob_term::get_term_acct {ccy_code} {

	variable REQ_ID
	variable TERM
	variable TERM_DETAILS

	set req [reqGetId]

	if {$req != $REQ_ID} {
		error\
			"Call login or set_term to set the term first"\
			""\
			TERM_NOT_SET
	}

	#check if we already have the details
	if {[info exists TERM_DETAILS($ccy_code)]} {
		return $TERM_DETAILS($ccy_code)
	}

	set rs [ob_db::exec_qry ob_term::get_term_acct $TERM $ccy_code]
	set nrows [db_get_nrows $rs]

	#we would expect a public and private account for this currency
	if {$nrows != 2} {
		ob_db::rs_close $rs
		error\
			"Could not find accounts for $TERM $ccy_code"\
			""\
			TERM_NO_PUB_PRIV_ACCT
	}

	set public_acct ""
	set private_acct ""
	for {set i 0} {$i < 2} {incr i} {
		set acct_id   [db_get_col $rs $i acct_id]
		set acct_type [db_get_col $rs $i acct_type]

		ob_log::write INFO {acct_type $acct_type}
		switch -- $acct_type {
			"PUB" {
				set public_acct $acct_id
			}
			"PRV" {
				set private_acct $acct_id
			}
			default {
				ob_db::rs_close $rs
				error\
					"Invalid acct type fro termnial"\
					""\
					TERM_INVALID_ACCT_TYPE
			}
		}
	}
	ob_db::rs_close $rs

	if {$public_acct == "" || $private_acct == ""} {
		error\
			"Could not find public and private account for $TERM $ccy_code"\
			""\
			TERM_NO_PUB_PRIV_ACCT
	}

	set TERM_DETAILS($ccy_code) [list $public_acct $private_acct]

	return $TERM_DETAILS($ccy_code)
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to prepare DB queries
#
proc ::ob_term::_prepare_queries {} {

	ob_db::store_qry ob_term::get_term_code {
		select
		  term_code,
		  status,
		  current time
		from
		  tAdminTerm
		where
		  ident = ?
	}

	ob_db::store_qry ob_term::login_term {
		update
		  tAdminTerm
		set
		  status = 'A'
		where
		  term_code = ?
	}

	ob_db::store_qry ob_term::get_term_acct {
		select
		  a.acct_type,
		  a.acct_id
		from
		  tTermAcct ta,
		  tAcct a
		where ta.term_code = ?
		and   ta.acct_id = a.acct_id
		and   a.ccy_code  = ?
	} 500
}



# Privare procedure to perform one-time initialisation
#
proc ::ob_term::_init {} {

	variable INIT
	variable KEY

	set KEY [md5 [OT_CfgGet TERM_KEY]]
	_prepare_queries

	set INIT 1
}



# Private procedure to check to see if the package has been initialised
#
proc ::ob_term::_check_init {} {

	variable INIT

	if {!$INIT} {
		error
			"Package didn't initialise properly"\
			""\
			TERM_NO_INIT
	}
}


# Self initialise
::ob_term::_init
