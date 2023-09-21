# $Id: group.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ----------------------------------------------------------------------
# Functions for inserting/updating/deleting customer (and other) groups
# ----------------------------------------------------------------------

namespace eval group {

variable INIT 0

# ----------------------------------------------------------------------
# Store queries in the SHARED_SQL array
# ----------------------------------------------------------------------
proc initGroup args {

	global   SHARED_SQL
	variable INIT

	if {!$INIT} {

		ob::log::write ERROR "<== group_init"

		set SHARED_SQL(grp_get_cust_group_val) {
			select
				gv.group_value
			from
				tCustGroup  c,
				tGroupValue gv
			where
				c.group_value_id = gv.group_value_id
			and
				c.cust_id = ?
			and
				gv.group_name = ?
		}

		set SHARED_SQL(grp_ins_cust_group) {
			execute procedure pInsCustGroup(
				p_cust_id         = ?,
				p_group_value_id  = ?,
				p_group_value_txt = ?,
				p_group_name      = ?
			)
		}

		set SHARED_SQL(grp_del_cust_group) {
			execute procedure pDelCustGroup(
				p_cust_id         = ?,
				p_group_value_id  = ?,
				p_group_name      = ?
			)
		}

		set SHARED_SQL(grp_upd_cust_group_txt) {
			execute procedure pUpdCustGroup(
				p_cust_id         = ?,
				p_group_value_id  = ?,
				p_group_value_txt = ?
			)
		}

		set INIT 1
	}
}

# ----------------------------------------------------------------------------
# Finds and returns the list of group values for the specified customer and group
# ----------------------------------------------------------------------------
proc getCustGroupValues {cust_id group_name} {
	global DB SHARED_SQL

	# execute query
	if {[catch {set rs [tb_db::tb_exec_qry grp_get_cust_group_val \
	$cust_id $group_name]} msg]} {

		ob::log::write ERROR {proc getCustGroupValues, grp_get_cust_group_val: $msg}
		error  {grp_get_cust_group_val failed in proc getCustGroupValue}
		return [list]
	}

	set num_rows   [db_get_nrows $rs]
	set group_vals [list]

	for {set i 0} {$i < $num_rows} {incr i} {
		lappend group_vals [db_get_col $rs $i group_value]
	}

	db_close $rs
	return   $group_vals
}

# ----------------------------------------------------------------------------
# Sets the group value and text for the specified customer;
# if group value id is specified then it is used else the default group
# value for the specified group name is used
# ----------------------------------------------------------------------------
proc setCustGroupValue {cust_id {group_value_id {}} {group_value_txt {}} {group_name {}} } {
	global DB SHARED_SQL

	# execute query
	if {[catch {tb_db::tb_exec_qry grp_ins_cust_group \
	$cust_id $group_value_id $group_value_txt $group_name} msg]} {

		ob::log::write ERROR {proc setCustGroupValue, grp_ins_cust_group: $msg}
		error {grp_ins_cust_group failed in proc setCustGroupValue}
	}
}

# ----------------------------------------------------------------------------
# Updates the group value text for the specified customer and group value;
# using -1 as the text will not change it, using "" will nullify it
# ----------------------------------------------------------------------------
proc setCustGroupValueTxt {cust_id group_value_id {group_value_txt -1}} {
	global DB SHARED_SQL

	# execute query
	if {[catch {tb_db::tb_exec_qry grp_upd_cust_group_txt \
	$cust_id $group_value_id $group_value_txt} msg]} {

		ob::log::write ERROR {proc setCustGroupValueTxt, grp_del_cust_group: $msg}
		error {grp_upd_cust_group_txt failed in proc setCustGroupValueTxt}
	}
}

# ----------------------------------------------------------------------------
# Deletes the group value for the specified customer;
# if group value id is specified then it is used else all associations
# between the customer and group values of the specified group name are deleted
# ----------------------------------------------------------------------------
proc delCustGroupValue {cust_id {group_value_id {}} {group_name {}} } {
	global DB SHARED_SQL

	# execute query
	if {[catch {tb_db::tb_exec_qry grp_del_cust_group \
	$cust_id $group_value_id $group_name} msg]} {

		ob::log::write ERROR {proc delCustGroupValue, grp_del_cust_group: $msg}
		error {grp_del_cust_group failed in proc delCustGroupValue}
	}
}

# initialize if required
initGroup

# close namespace
}
