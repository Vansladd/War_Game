##
# ~name OB_prefs
# ~type tcl file
# ~title prefs.tcl
# ~summary Customer Preferences
# ~version $Id: prefs.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd.  All rights reserved.
#
# SYNOPSIS
#
# [
#	# source shared_tcl/prefs.tcl
#
#	OB_prefs::init_prefs
#	# should be called in main_init procedure.
# ]
#
# METHODS
#
# [
#	OB_prefs::init_prefs
#	OB_prefs::_prepare_pref_queries
#	OB_prefs::_prepare_flag_queries
#
#	OB_prefs::insert <cust_id> <name> <cvalue> <ivalue> *<pos 0>
#	OB_prefs::update <cust_id> <name> <cvalue> <ivalue> *<pos 0>
#	OB_prefs::delete <cust_id> <name>
#
#	OB_prefs::set_pref <pref> <val>
#	OB_prefs::get_pref <pref>
#	OB_prefs::set_flag <flag> <value>
#	OB_prefs::get_flag <flag>
#
#	OB_prefs::set_cust_pref <cust_id> <name> <value> *<type C> *<pos 0>
#	OB_prefs::get_cust_pref <cust_id> <name> *<type C>
#	OB_prefs::set_cust_flag <cust_id> <name> <value>
#	OB_prefs::get_cust_flag <cust_id> <flag>
# ]
#
##

namespace eval OB_prefs {

	namespace export init_prefs
	namespace export set_pref
	namespace export get_pref
	namespace export set_flag
	namespace export get_flag

	variable PREFS_PREP
	set PREFS_PREP 0
}

##
# OB_prefs::init_prefs - prepare flag and pref queries
#
# [
#	SYNOPSIS : OB_prefs::init_prefs
#	SCOPE    : public
#	PARAMS   : none
#	RETURN   : none
# ]
#
##
proc OB_prefs::init_prefs {} {
	variable PREFS_PREP

	if {!$PREFS_PREP} {
		_prepare_pref_queries
		_prepare_flag_queries
	}
	set PREFS_PREP 1
}


##
# OB_prefs::_prepare_pref_queries - insert, update, delete queries
#
# [
#	SYNOPSIS : OB_prefs::_prepare_pref_queries
#	SCOPE    : private
#	PARAMS   : none
#	RETURN   : none
# ]
#
##
proc OB_prefs::_prepare_pref_queries {} {
	global SHARED_SQL

	set SHARED_SQL(ob_prefs_pref_insert) {
		insert into tCustomerPref
		(pref_cvalue, pref_ivalue, cust_id, pref_name, pref_pos)
		values
		(?, ?, ?, ?, ?)
	}

	set SHARED_SQL(ob_prefs_pref_update) {
		update tCustomerPref set
		pref_cvalue = ?,
		pref_ivalue = ?
		where
		cust_id   = ?  and
		pref_name = ?  and
		pref_pos  = ?
	}

	set SHARED_SQL(ob_prefs_pref_delete) {
		delete from tCustomerPref
		where
		cust_id     = ? and
		pref_name   = ?
	}

	set SHARED_SQL(ob_prefs_pref_get) {
		SELECT
			pref_cvalue,
			pref_ivalue,
			pref_pos
		FROM
			tCustomerPref
		WHERE
			cust_id   = ?
		AND pref_name = ?
		ORDER BY
			pref_pos
	}

}


##
# OB_prefs::_prepare_flag_queries - insert, update, delete queries
#
# [
#	SYNOPSIS : OB_prefs::_prepare_flag_queries
#	SCOPE    : private
#	PARAMS   : none
#	RETURN   : none
# ]
#
##
proc OB_prefs::_prepare_flag_queries {} {
	global SHARED_SQL

	set SHARED_SQL(ob_prefs_flag_insert) {
		insert into tCustomerFlag
		(flag_value, cust_id, flag_name)
		values
		(?, ?, ?)
	}

	set SHARED_SQL(ob_prefs_flag_update) {
		update tCustomerFlag set
		flag_value = ?
		where
		cust_id   = ?  and
		flag_name = ?
	}

	set SHARED_SQL(ob_prefs_flag_delete) {
		delete from tCustomerFlag
		where
		cust_id     = ? and
		flag_name   = ?
	}

	set SHARED_SQL(ob_prefs_flag_select) {
		select flag_value
		from tCustomerFlag
		where
		cust_id = ? and
		flag_name = ?
	}
}


##
# OB_prefs::set_pref - insert or update preference
#
# [
#	SYNOPSIS    : OB_prefs::set_pref <pref> <val>
#	SCOPE       : public
#	PARAMS      : pref, tCustomerPref.pref_name
#	              val,  tCustomerPref.pref_cvalue
#	RETURN      : none
#	DESCRIPTION : assumes global USER_ID, LOGIN_DETAILS are populated
# ]
#
##
proc OB_prefs::set_pref {pref val} {

	global USER_ID LOGIN_DETAILS

	if {[ob_is_guest_user]} {
		return
	}

	set_cust_pref $USER_ID $pref $val

	set LOGIN_DETAILS(pref,$pref,vals) $val
}


##
# OB_prefs::set_cust_pref - modify preference
#
# [
#	SYNOPSIS    : OB_prefs::set_cust_pref <cust_id> <name> <value>
#	                                     *<type C> *<pos 0>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              name,    tCustomerPref.pref_name
#	              value,   tCustomerPref.pref_ivalue or tCustomer.pref_cvalue
#	              type,    I(nteger) for pref_ivalue or C(har) for pref_cvalue
#	              pos,     tCustomerPref.pref_pos
#	RETURN      : none
#	DESCRIPTION : If value is empty, preference is deleted.
# ]
#
##
proc OB_prefs::set_cust_pref {cust_id name value {type C} {pos 0}} {

	if {$value == ""} {
		OB_prefs::delete $cust_id $name
		return
	}

	set current_value [get_cust_pref $cust_id $name $type]


	if {$value == $current_value} {
		return
	}

	switch -- $type {
		C {
			set ivalue ""
			set cvalue $value
		}
		I {
			set ivalue $value
			set cvalue ""
		}
		default {
			ob::log::write ERROR {Unknown pref type, should be C|I, got $type}
		}
	}

	if {$current_value == ""} {
		OB_prefs::insert $cust_id $name $cvalue $ivalue $pos
	} else {
		OB_prefs::update $cust_id $name $cvalue $ivalue $pos
	}

}

##
# OB_prefs::insert - insert preference
#
# [
#	SYNOPSIS    : OB_prefs::insert <cust_id> <name> <cvalue> <ivalue> *<pos 0>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              name,    tCustomerPref.pref_name
#	              cvalue,  tCustomerPref.pref_cvalue
#	              ivalue,  tCustomerPref.pref_ivalue
#	              pos,     tCustomerPref.pref_pos
#	RETURN      : none
# ]
#
##
proc OB_prefs::insert {cust_id name cvalue ivalue {pos 0}} {

	if {[catch {tb_db::tb_exec_qry ob_prefs_pref_insert $cvalue\
							                            $ivalue\
							                            $cust_id\
							                            $name\
							                            $pos} msg]} {

		ob::log::write ERROR {query failed $msg}
		return -1
	}

	return [tb_db::tb_garc ob_prefs_pref_insert]
}

##
# OB_prefs::update - update preference
#
# [
#	SYNOPSIS    : OB_prefs::update <cust_id> <name> <cvalue> <ivalue> *<pos 0>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              name,    tCustomerPref.pref_name
#	              cvalue,  tCustomerPref.pref_cvalue
#	              ivalue,  tCustomerPref.pref_ivalue
#	              pos,     tCustomerPref.pref_pos
#	RETURN      : none
# ]
#
##
proc OB_prefs::update {cust_id name cvalue ivalue {pos 0}} {

	if {[catch {tb_db::tb_exec_qry ob_prefs_pref_update $cvalue\
							                            $ivalue\
							                            $cust_id\
							                            $name\
							                            $pos} msg]} {

		ob::log::write ERROR {query failed $msg}
		return -1
	}

	return [tb_db::tb_garc ob_prefs_pref_update]
}

##
# OB_prefs::delete - delete preference
#
# [
#	SYNOPSIS    : OB_prefs::delete <cust_id> <name>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              name,    tCustomerPref.pref_name
#	RETURN      : none
# ]
#
##
proc OB_prefs::delete {cust_id name} {

	if {[catch {tb_db::tb_exec_qry ob_prefs_pref_delete $cust_id $name} msg]} {
		ob::log::write ERROR {failed to delete pref: $msg}
		return -1
	}

	return [tb_db::tb_garc ob_prefs_pref_delete]
}


##
# OB_prefs::get_pref - retrieve preference value
#
# [
#	SYNOPSIS    : OB_prefs::get_pref <pref>
#	SCOPE       : public
#	PARAMS      : pref, tCustomerPref.pref_name
#	RETURN      : A string, tCustomerPref.pref_cvalue
#	DESCRIPTION : Value retrieved from global LOGIN_DETAILS
# ]
#
##

proc OB_prefs::get_pref {pref} {

	global LOGIN_DETAILS

	if {[info exists LOGIN_DETAILS(pref,$pref,vals)]} {
		return $LOGIN_DETAILS(pref,$pref,vals)
	}
	return ""

}

##
# OB_prefs::get_cust_pref - retrieve customer preference
#
# [
#	SYNOPSIS    : OB_prefs::get_cust_pref <cust_id> <name> *<type C>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              name,    tCustomerPref.pref_name
#	              type,    I(nteger) or C(har)
#	RETURN      : type I, a list of tCustomerPref.pref_ivalue's is returned
#	              type C, a list of tCustomerPref.pref_cvalue's is returned
#	              empty list, if no value found.
# ]
#
##
proc OB_prefs::get_cust_pref {cust_id name {type "C"}} {

	if {[catch {set rs [tb_db::tb_exec_qry ob_prefs_pref_get $cust_id $name]} msg]} {
		ob::log::write ERROR {failed to get pref: $name: $msg}
		return ""
	}

	set value [list]
	set nrows [db_get_nrows $rs]

	switch -- $type {
		C { set col pref_cvalue }
		I { set col pref_ivalue }
	}

	for {set r 0} {$r < $nrows} {incr r} {
		lappend value [db_get_col $rs $r $col]
	}

	tb_db::tb_close $rs

	return $value
}


##
# OB_prefs::set_flag - insert or update customer flag
#
# [
#	SYNOPSIS    : OB_prefs::set_flag <flag> <name>
#	SCOPE       : public
#	PARAMS      : flag,  tCustomerFlag.flag_name
#	              value, tCustomerFlag.flag_value
#	RETURN      : An integer, the affected row count.
#	DESCRIPTION : Global USER_ID must be defined and customer logged in.
#	              Calls OB_prefs::set_cust_flag
# ]
#
##
proc OB_prefs::set_flag {flag value} {

	global USER_ID

	if {[ob_is_guest_user]} {
		ob::log::write ERROR {Cannot set flag for guest user}
		return
	}

	set_cust_flag $USER_ID $flag $value
}


##
# OB_prefs::set_cust_flag - insert or update customer flag
#
# [
#	SYNOPSIS    : OB_prefs::set_cust_flag <cust_id> <flag> <value>
#	SCOPE       : public
#	PARAMS      : cust_id, tCustomer.cust_id
#	              flag,    tCustomerFlag.flag_name
#	              value,   tCustomerFlag.flag_value
#	RETURN      : An integer, the affected row count
#	DESCRIPTION : If value is empty the preference is deleted.
# ]
#
##
proc OB_prefs::set_cust_flag {cust_id flag value} {

	# Delete for empty value string
	if {$value == ""} {

		if {[catch {tb_db::tb_exec_qry ob_prefs_flag_delete $cust_id $flag} msg]} {
			ob::log::write ERROR {failed to delete flag: $msg}
		}
		return
	}

	if {[catch {set rs [tb_db::tb_exec_qry ob_prefs_flag_select $cust_id $flag]} msg]} {
		ob::log::write ERROR {failed to select flag $flag: $msg}
		return
	}

	if {[db_get_nrows $rs] == 1} {
		set qry ob_prefs_flag_update
	} else {
		set qry ob_prefs_flag_insert
	}

	tb_db::tb_close $rs

	if {[catch {tb_db::tb_exec_qry $qry $value $cust_id $flag} msg]} {
		ob::log::write ERROR {$qry failed for $flag: $msg}
	}

	return [tb_db::tb_garc $qry]
}

##
# OB_prefs::get_flag - retrieve customer flag
#
# [
#	SYNOPSIS    : OB_prefs::get_flag <flag>
#	SCOPE       : public
#	PARAMS      : flag, tCustomerFlag.flag_name
#	RETURN      : A string, tCustomerFlag.flag_value
#	DESCRIPTION : global USER_ID used.
# ]
#
##
proc OB_prefs::get_flag {flag} {

	global USER_ID

	return [get_cust_flag $USER_ID $flag]
}

##
# OB_prefs::get_cust_flag - retrieve customer flag
#
# [
#	SYNOPSIS    : OB_prefs::get_cust_flag <flag>
#	SCOPE       : public
#	PARAMS      : flag, tCustomer.flag_name
#	RETURN      : A string, tCustomer.flag_value
# ]
#
##
proc OB_prefs::get_cust_flag {cust_id flag} {

	if {[catch {set rs [tb_db::tb_exec_qry ob_prefs_flag_select $cust_id $flag]} msg]} {
		ob::log::write ERROR {failed to select flag $flag: $msg}
		return ""
	}

	if {[db_get_nrows $rs] == 1} {
		set value [db_get_col $rs 0 flag_value]
	} else {
		set value ""
	}

	tb_db::tb_close $rs

	return $value
}

OB_prefs::init_prefs
