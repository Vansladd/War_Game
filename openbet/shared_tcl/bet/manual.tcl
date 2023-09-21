################################################################################
# $Id: manual.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Interface to manual bets
################################################################################
namespace eval ob_bet {}

# Prepare manual DB queries
proc ob_bet::_prepare_manual_qrys {} {

	set on_course_parms ""
	if {[_get_config manual_bet_allow_on_course]} {
		set on_course_parms ",p_rep_code = ?, p_on_course_type = ?"
	}

	ob_db::store_qry ob_bet::place_manual_bet [subst {
		execute procedure pInsManOBet (
			p_ipaddr = ?,
			p_placed_by = ?,
			p_source = ?,
			p_unique_id = ?,
			p_temp_desc_1 = ?,
			p_temp_desc_2 = ?,
			p_temp_desc_3 = ?,
			p_temp_desc_4 = ?,
			p_desc_1 = ?,
			p_desc_2 = ?,
			p_desc_3 = ?,
			p_desc_4 = ?,
			p_to_settle_at = ?,
			p_cust_id = ?,
			p_acct_id = ?,
			p_bet_type = ?,
			p_stake = ?,
			p_stake_per_line = ?,
			p_tax_rate = ?,
			p_tax_type = ?,
			p_tax = ?,
			p_max_payout = ?,
			p_pay_now = ?,
			p_call_id = ?,
			p_receipt_format = ?,
			p_slip_id = ?,
			p_ev_class_id = ?,
			p_ev_type_id = ?,
			p_leg_type = ?,
			p_num_lines = ?,
			p_settle_info = ?
			$on_course_parms
		)
	}]
}

proc ob_bet::place_manual_bet {
	uid
	ip_addr
	call_id
	stake
	total_stake
	desc
	stl_date
	pay_now
	{placed_by    ""}
	{slip_id      ""}
	{ev_class_id  ""}
	{ev_type_id   ""}
	{leg_type    "W"}
	{num_lines     1}
	{tt          "S"}
	{tax_rate   0.00}
	{rep_code     ""}
	{course       ""}
} {
	variable CUST
	variable CUST_DETAILS

	_log INFO "API(place_manual_bet)"

	# Split up the text so it fits into the DB
	set desc_1 [string range $desc 0    254]
	set desc_2 [string range $desc 255  509]
	set desc_3 [string range $desc 510  764]
	set desc_4 [string range $desc 765 1019]

	# Calculate tax
	set tax 0.00
	if {$tt == "S"} {
		set tax [expr {ceil([expr $tax_rate * $stake]) / 100.00}]
	}

	#
	# calculate max payout
	#
	set max_payout [expr {[_get_config manual_bet_max_payout] * $CUST_DETAILS(exch_rate)}]

	set desc_1_temp $desc_1
	set desc_2_temp $desc_2
	set desc_3_temp $desc_3
	set desc_4_temp $desc_4

	if {![_get_config manual_bet_allow_unvetted]} {
		set desc_1 ""
		set desc_2 ""
		set desc_3 ""
		set desc_4 ""
	}

	set place_man_bet_args [list \
		$ip_addr \
		$placed_by \
		[_get_config source] \
		$uid \
		$desc_1_temp \
		$desc_2_temp \
		$desc_3_temp \
		$desc_4_temp \
		$desc_1 \
		$desc_2 \
		$desc_3 \
		$desc_4 \
		$stl_date \
		$CUST(cust_id) \
		$CUST(acct_id) \
		MAN \
		$total_stake \
		$stake \
		$tax_rate \
		$tt \
		$tax \
		$max_payout \
		$pay_now \
		$call_id \
		[_get_config bet_receipt_format] \
		$slip_id \
		$ev_class_id \
		$ev_type_id \
		$leg_type \
		$num_lines]

	if {[_get_config manual_bet_allow_on_course]} {
		lappend $place_man_bet_args $rep_code $course
	}

	set rs [eval ob_db::exec_qry ob_bet::place_manual_bet $place_man_bet_args]

	if {[db_get_nrows $rs] != 1} {
		db_close $rs
		_log CRITICAL "**** no rows returned from manual bet insert"
		error "no rows returned from manual bet insert"
	}

	set bet_id [db_get_coln $rs 0 0]
	db_close $rs

	return $bet_id
}

::ob_bet::_log INFO "sourced manual.tcl"
