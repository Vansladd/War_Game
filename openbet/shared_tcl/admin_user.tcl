#
# $id$
#

namespace eval AdminUser {}

proc AdminUser::prep_admin_user_qrys {} {

	tb_db::tb_store_qry chg_admin_user_password {
		execute procedure pChgAdminPwd (
			p_username = ?,
			p_old_pass = ?,
			p_new_pass = ?,
			p_new_salt = ?
		)
	}

	tb_db::tb_store_qry get_pwd_settings {
		select
			admn_pwd_min_len,
			admn_pwd_num_rpt
		from
			tControl
	}
}

proc AdminUser::init_admin_user {} {
	prep_admin_user_qrys
}


#
# ---------------------------------------------------------------------------
# Attempts to change the password of an admin user
# ---------------------------------------------------------------------------
#
proc AdminUser::change_user_password args {

	set username [reqGetArg username]
	set pwd_0    [reqGetArg Password_0]
	set pwd_1    [reqGetArg Password_1]
	set pwd_2    [reqGetArg Password_2]

	# some password criteria and checks:

	if {[catch {set rs \
		[tb_db::tb_exec_qry get_pwd_settings]
		} msg]} {
			OT_LogWrite 1 "Failed to get tControl values for password settings : $msg"
			return [list 0 "Failed to get tControl values for password settings : $msg"]
	}

	set min_length [db_get_col $rs 0 admn_pwd_min_len]
	## admn_pwd_num_rpt could be useful for future translations with placeholders
	##      set num_repeat [db_get_col $rs 0 admn_pwd_num_rpt]

	db_close $rs

	# check that the new password entries match
	if {$pwd_1 != $pwd_2} {
		return  [list 0 [ml_printf PWD_PASSWD_MISMATCH]]
	}

	# Check that the new password is different from the old one
	if {$pwd_0 == $pwd_1} {
		return [list 0 [ml_printf PWD_NEW_SAME_AS_OLD]]
	}

	# check new password has at least the minimum length
	# we have to use one general message because we cannot use placeholders in this translation
	if {[string length $pwd_1] < $min_length} {
		return [list 0 [ml_printf PWD_MUST_BE_X_PLUS_CHARS $min_length]]
	}

	# Apply regular expression to password to check its validity.
	foreach rexp [OT_CfgGet PWD_REGEXPS [list {[a-zA-Z]} {[0-9]}]] {
		if {[regexp $rexp $pwd_1] == 0} {
			OT_LogWrite 1 "Password must be $min_length or more characters containing letters and at least one number."
			return [list 0 "Password must be $min_length or more characters containing letters and at least one number."]
		}
	}

	# Deal with converting unsalted hashes
	set salt_resp [get_admin_salt $username]
	set old_salt [lindex $salt_resp 1]
	if {[lindex $salt_resp 0] == "ERROR"} {
		set old_salt ""
	}

	set new_salt [generate_salt]

	# encode the passwords
	set pwd_old_hash [encrypt_admin_password $pwd_0 $old_salt]
	set pwd_new_hash [encrypt_admin_password $pwd_1 $new_salt]

	# Check for duplicates in the last n passwords
	set pwd_ok [is_prev_admin_pwd $username $pwd_1]
	if {$pwd_ok != "PWD_IS_OK"} {
		set num_pwds [get_prev_admin_pwd_count]
		set msg "Password should not be the same as the last $num_pwds passwords"
		OT_LogWrite 1 "Failed to change user($username) password : $msg"
		return [list 0 "Failed to change user($username) password : $msg"]
		go_user_list
		return
	}

	if {[catch {set rs \
		[tb_db::tb_exec_qry chg_admin_user_password \
		$username \
		$pwd_old_hash \
		$pwd_new_hash \
		$new_salt]
		} msg]} {
			OT_LogWrite 1 "Failed to change user($username) password : $msg"
			return [list 0 "Failed to change user($username) password : $msg"]
	}

	if {[db_get_coln $rs 0] == 1} {
		ob::log::write ERROR {Pwd change succeeded}
		reqSetArg password $pwd_1
		return [list 1 [ml_printf PWD_CHANGE_SUCCESS]]
	} else {
		ob::log::write ERROR {Pwd change failed}
		return  [list 0 [ml_printf PWD_INVALID_PASSWD]]
	}
}

# initialise this namespace
AdminUser::init_admin_user

