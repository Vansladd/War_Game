# $Id: tmp_pwd_generator.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Lost Login
#
package provide util_tmp_pwd_generator 1.0

package require cust_login 4.5
package require util_validate 4.5


namespace eval ob_tmp_pwd_generator {
	variable INIT
	set INIT 0
}


proc ob_tmp_pwd_generator::init {} {
	variable INIT

	# package initialised?
	if {$INIT} {
		return
	}

	ob_login::init
	ob_chk::init
	_prepare_qrys
	set INIT   1
}


proc ob_tmp_pwd_generator::change_pwd {cust_id} {

	if [catch {set rs [ob_db::exec_qry ob_tmp_pwd_generator::check_user $cust_id]} msg] {
		ob_log::write ERROR {failed to execute ob_tmp_pwd_generator::check_user: $msg}
		return [list "ERR" "LOST_LOGIN_TEMPORARY_PW"]
	}

	if {[db_get_nrows $rs] != 1} {

		ob_log::write ERROR {failed to get details for customer: $cust_id}
		ob_db::rs_close $rs
		return [list "ERR" "LOST_LOGIN_TEMPORARY_PW"]

	} else {

		set old_password [db_get_col $rs 0 password]
		set username     [db_get_col $rs 0 username]
		ob_db::rs_close $rs

	}

	
	ob_log::write INFO {changing password for user $username}
	
	# randomly generate a password
	set new_password     [_generate_password]

	# Fake login to change the password
	set status [ob_login::tbs_login $cust_id]

	if {$status ne "OB_OK"} {

		ob_log::write ERROR {ob_tmp_pwd_generator::change_pwd couldn't login: $status}
		ob_login::logout
		return [list "ERR" "LOST_LOGIN_TEMPORARY_PW"]
	}


	# Update pwd
	set status [ob_login::upd_pwd - $new_password $new_password "Y" 0 1]

	if {$status ne "OB_OK"} {
		ob_log::write ERROR {::sb_acct::_lost_login_4: couldn't upd pwd:$status}
		ob_login::logout
		return [list "ERR" "LOST_LOGIN_TEMPORARY_PW"]

	}

	ob_login::logout

	return [list "OK" $new_password]
}


proc ob_tmp_pwd_generator::_prepare_qrys {} {

	ob_db::store_qry ob_tmp_pwd_generator::check_user {
		select
			c.password,
			c.username
		from
			tCustomer c
		where
			c.cust_id     = ?
	}

	ob_db::store_qry ob_tmp_pwd_generator::update_password {
		execute procedure pUpdCustPasswd (
			p_username = ?,
			p_old_pwd = ?,
			p_new_pwd = ?,
			p_temp_pwd = 'Y'
		)
	}

}


# Generate an 8 character random-ish password
proc ob_tmp_pwd_generator::_generate_password {} {

	set password ""
	for {set i 0} {$i < 8} {incr i} {
		set cap 65
		set random [expr int([expr rand() * 10])]
		if {[expr fmod($random, 2)] == 1} {
			set cap 97
		}
		set random [expr rand() * 1000]
		set number [expr int([expr fmod($random, 26)]) + $cap]
		set password [format "%s%c" $password $number]
	}
	return [string tolower $password]
}


