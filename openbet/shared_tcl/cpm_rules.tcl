# $Id: cpm_rules.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
##
#
# Customer Payment Method & Messages Rules
# ----------------------------------------
#
# Purpose
# --------
# The payment rules' purpose is three-fold :
#        1. to determine which payment methods a customer is offered when setting
#           up a payment method
#        2. to validate the payment method a customer is attempting to register
#        3. to validate the customers active payment method when attempting to make
#           a transaction
#
# The messages are to alert customers about changes to rules and any other payment
# related information. The messages can be displayed at Login, Registration on attempting
# to make a deposit or withdrawal.
#
#
# Database :
# ----------
# The main tables associated with these rules are tCPMRule, tCPMOp and tPayMthdAllow.
# * 'cpm_allow_id' links a rule (tCPMRule) to a Allowable Pay Mthd (tPayMthdAllow)
# * 'rule_id' lins a rule (tCPMRule) to its components in tCPMOp
#
##

##
# PROCEDURES
# ______________________________________________________________________________________________________________
# Procedure               |   Description
# ________________________|_____________________________________________________________________________________
# init                    |  query and variable initialisation.
#
# get_active_cpm_for      |  returns a customer's active payment method for depositing / withdrawals
# cpm_still_valid   |  for checking if a pay mthd is still valid when making a payment
# check_avail_cpms        |  returns an ordered list of pay mthds availbale to register for a customer
# check_for_cpm_msg       |  checks if we need to display any messages to the customer at this time
# cpm_reg_possible_for    |  checks upon registering a payment method whether it is still possible to do so or not.
#
# evaluate_msg_rules      |  evaluates a message rules result set
# evaluate_cpm_rules      |  evaluates a CPM rules result set
# do_op                   |  evaluates an operation to true / false
#
# get_all_avail_cpm_ids   |  gets a list of all cpm_allow_ids available
# get_cust_rule_details   |  gets and sets customer details to be used in rule evaluation
# get_cpm_details         |  retrieves detailed information on a customer's active CPM
# upd_cpm_txn_status      |  used for updating the dep or wtd status of a customer pay mthd
# convert_ids_to_mthds    |  helper method used to convert cpm_llow_ids to pay mthds/type pairs
# convert_mthds_to_descs  |  helper method used to convert mthd/type pairs to textual descriptions
# set_cpm_type            |  set the type of a pay method
# get_rule_vars           |  gets all rule variables and english descriptions used
# get_var_desc            |  gets an Enlish description for a particular rule variable
# get_customer_details    |  gets customer details for use in rule evaluation
#
#
##

namespace eval CPMRules {

namespace export check_avail_cpms
namespace export check_for_cpm_msg
namespace export get_active_cpm_for
namespace export cpm_reg_possible_for
namespace export check_cpm_can_register

namespace export set_cpm_type

namespace export get_rule_vars
namespace export get_var_desc

namespace export convert_mthds_to_descs


variable CUST_RULE_DETAILS
variable VAR_MAP
variable EXEC_RULES


##
# CPMRules::init - initialise CPM Rules namespace
#
# SYNOPSIS
#
#       [CPMRules::init]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#       Sets up queries and variables needed in namespace.
#
##
proc init {} {
	ob::log::write INFO {Initialising CPMRules ....}

	global SHARED_SQL
	variable VAR_MAP


	#
	# Get all Pay Method rules that
	# relate to a transaction type.
	#
	set SHARED_SQL(get_all_cpm_rules) {
		select
			r.rule_id,
			r.rule_name,
			r.cpm_allow_id,
			r.rule_type,
			r.pmt_type,
			r.channels,
			r.msg,
			r.type,
			o.op_id,
			o.sequence,
			o.op_level,
			o.op_operator,
			o.op_left_value,
			o.op_right_value,
			m.pay_mthd,
			m.cpm_type
		from
			tCPMRule r,
			tCPMOp o,
			tPayMthdAllow m
		where
			r.rule_id = o.rule_id
			and r.cpm_allow_id = m.cpm_allow_id
			and r.type = 'R'
			and r.pmt_type in ('BOTH',?)
			and r.status in (?,?)
			and o.status in (?,?)
			and r.channels like ?
		order by rule_id, sequence

	}


	#
	# Get all rules associated with a particular
	# transaction type and payment method.
	#
	set SHARED_SQL(get_cpm_rules) {
		select
			r.rule_id,
			r.rule_name,
			r.cpm_allow_id,
			r.rule_type,
			r.pmt_type,
			r.channels,
			r.msg,
			r.type,
			o.op_id,
			o.sequence,
			o.op_level,
			o.op_operator,
			o.op_left_value,
			o.op_right_value,
			m.cpm_allow_id,
			m.pay_mthd,
			m.cpm_type
		from
			tCPMRule r,
			tCPMOp o,
			tPayMthdAllow m
		where
			r.rule_id = o.rule_id
			and r.cpm_allow_id = m.cpm_allow_id
			and r.type = 'R'
			and r.pmt_type in ('BOTH',?)
			and r.cpm_allow_id = ?
			and r.status in (?,?)
			and o.status in (?,?)
			and r.channels like ?
		order by rule_id, sequence
	}


	#
	# Get all available deposit pay methods.
	#
	set SHARED_SQL(get_dep_avail_cpm_ids) {
		select
			cpm_allow_id,
			pay_mthd,
			cpm_type,
			dep_order
		from
			tPayMthdAllow
		where
			allow_dep = 'Y'
		order by
			dep_order
	}


	#
	# Get all available withdrawal pay methods.
	#
	set SHARED_SQL(get_wtd_avail_cpm_ids) {
		select
			cpm_allow_id,
			pay_mthd,
			cpm_type,
			wtd_order
		from
			tPayMthdAllow
		where
			allow_wtd = 'Y'
		order by
			wtd_order
	}

	set SHARED_SQL(non_withdrawable_mthds) {
		select
			m.cpm_id
		from
			tCustPayMthd m
		where
			m.cust_id = ?
			and m.status = 'A'
			and m.auth_wtd = 'N'
			and m.status_wtd = 'S'
	}

	set SHARED_SQL(check_linked_mthd) {
		select
			1
	  	from
		  tCpmGroup g,
		  tCpmGroupLink l1,
		  tCpmGroupLink l2,
		  tCustPayMthd c
	  	where
		  g.cust_id = ? and
		  l1.cpm_id = ? and
		  l1.cpm_grp_id = g.cpm_grp_id and
		  g.cpm_grp_id = l2.cpm_grp_id and
		  l2.type IN ('B','W') and
		  l2.cpm_id = c.cpm_id and
		  c.status = 'A'
	}


	#
	# Get all id details
	#
	set SHARED_SQL(get_all_id_details) {
		select
			cpm_allow_id,
			pay_mthd,
			nvl(cpm_type,'-') cpm_type,
			desc
		from
			tPayMthdAllow
	}


	#
	# Get all message rules for a particular
	# message point.
	#
	set SHARED_SQL(get_msg_rules) {
		select
			r.rule_id,
			r.rule_name,
			r.msg,
			r.channels,
			o.op_id,
			o.sequence,
			o.op_level,
			o.op_operator,
			o.op_left_value,
			o.op_right_value,
			nvl(r.priority, 9999) priority
		from
			tCPMRule r,
			tCPMOp o
		where
			r.rule_id = o.rule_id
			and r.msg_point = ?
			and r.type = 'M'
			and r.status in (?,?)
			and o.status in (?,?)
			and r.channels like ?
		order by
			priority,
			rule_id,
			sequence
	}


	#
	# Get all active CPM's for the customer
	#
	set SHARED_SQL(get_cust_active_cpms) {
		select
			m.cpm_id,
			m.pay_mthd,
			m.status_dep,
			m.status_wtd,
			m.auth_dep,
			m.auth_wtd,
			nvl(m.type,'-') as type,
			a.cpm_allow_id,
			a.allow_dep,
			a.allow_wtd
		from
			tcustpaymthd m,
			tpaymthdallow a
		where
			m.pay_mthd = a.pay_mthd
			and nvl(m.type,'-') = nvl(a.cpm_type,'-')
			and m.status = 'A'
			and (a.allow_dep = 'Y' or a.allow_wtd = 'Y')
			and m.cust_id = ?
	}

	#
	# Get all active deposit CPM's for the customer
	#
	set SHARED_SQL(get_cust_active_cpms_dep) {

		select
			m.cpm_id,
			m.pay_mthd,
			m.status_dep,
			m.status_wtd,
			m.disallow_dep_rsn,
			m.disallow_wtd_rsn,
			m.auth_dep,
			m.auth_wtd,
			nvl(m.type,'-') as type,
			a.dep_order,
			a.cpm_allow_id
		from
			tcustpaymthd m,
			tpaymthdallow a
		where
			m.pay_mthd = a.pay_mthd
			and nvl(m.type,'-') = nvl(a.cpm_type,'-')
			and m.status = 'A'
			and m.status_dep = 'A'
			and m.cust_id = ?
		order by
			a.dep_order

	}

	#
	# Get all active withdrawal CPM's for the customer
	#
	set SHARED_SQL(get_cust_active_cpms_wtd) {
		select
			m.cpm_id,
			m.pay_mthd,
			m.status_dep,
			m.status_wtd,
			m.disallow_dep_rsn,
			m.disallow_wtd_rsn,
			m.auth_dep,
			m.auth_wtd,
			nvl(m.type,'-') as type,
			a.wtd_order,
			a.cpm_allow_id
		from
			tcustpaymthd m,
			tpaymthdallow a
		where
			m.pay_mthd = a.pay_mthd
			and nvl(m.type,'-') = nvl(a.cpm_type,'-')
			and m.status = 'A'
			and m.status_wtd = 'A'
			and m.cust_id = ?
		order by
			a.wtd_order
	}

	#
	# Get all active wtd and dep CPMs for a customer
	#
	set SHARED_SQL(get_cust_active_cpms_both) {
		select
			m.cpm_id,
			m.pay_mthd,
			m.status_dep,
			m.status_wtd,
			m.disallow_dep_rsn,
			m.disallow_wtd_rsn,
			m.auth_dep,
			m.auth_wtd,
			nvl(m.type,'-') as type,
			a.cpm_allow_id
		from
			tcustpaymthd m,
			tpaymthdallow a
		where
			m.pay_mthd = a.pay_mthd
			and nvl(m.type,'-') = nvl(a.cpm_type,'-')
			and m.status = 'A'
			and (m.status_wtd = 'A' or m.status_dep = 'A')
			and m.cust_id = ?
	}


	#
	# Update CPM status's
	#
	set SHARED_SQL(upd_cpm_status) {
		update
			tCustPayMthd
		set
			status_dep = ?,
			status_wtd = ?,
			auth_dep = ?,
			auth_wtd = ?,
			status = ?,
			disallow_dep_rsn = ?,
			disallow_wtd_rsn = ?
		where
			cpm_id = ?
	}

	#
	# Updates the type of a CPM
	#
	set SHARED_SQL(set_cpm_type) {
		update
			tCustPayMthd
		set
			type = ?
		where
			cpm_id = ?
	}


	#
	# Gets basic customer account information
	#
	set SHARED_SQL(get_customer_details) {
		select
			c.username,
			c.country_code,
			a.ccy_code
		from
			tCustomer c,
			tAcct a
		where
			c.cust_id = a.cust_id
			and c.cust_id = ?
	}


	#
	# Gets card bin range allow
	#
	set SHARED_SQL(get_scheme_allow) {
		select
			i.wtd_allowed as allow_wtd,
			i.dep_allowed as allow_dep
		from
			tCardScheme s,
			tCardSchemeInfo i,
			tcpmcc c
		where
			c.cpm_id = ? and
			s.scheme = i.scheme and
			s.bin_lo <= c.card_bin and
			s.bin_hi >= c.card_bin
	}

	set SHARED_SQL(get_info_allow) {
		select
			i.allow_dep,
			i.allow_wtd
		from
			tCardInfo i,
			tCPMCC c
		where
			c.cpm_id = ? and
			i.card_bin = c.card_bin
	}

	set SHARED_SQL(get_cpm_allow) {
		select
			a.cpm_allow_id,
			c.pay_mthd
		from
			tPayMthdAllow a,
			tCustPayMthd c
		where
			c.cpm_id = ?
			and a.pay_mthd = c.pay_mthd
	}

	set SHARED_SQL(get_CC_details) {
		select
			i.country,
			i.scheme
		from
			tCpmCC       cpm,
			tCardInfo    i
		where
			cpm.cpm_id   = ? and
			cpm.card_bin = i.card_bin
	}

	set SHARED_SQL(get_dep_decl_vars) {
		select
			m.card_bin,
			g.pg_type,
			c.enrol_3d_resp,
			c.auth_3d_resp,
			c.gw_ret_code,
			i.scheme
		from
			tPmt         p,
			tPmtCC       c,
			tPmtGateHost g,
			tCPMCC       m,
			tCardInfo    i
		where
			c.pmt_id     = ?            and
			p.pmt_id     = c.pmt_id     and
			c.pg_host_id = g.pg_host_id and
			p.cpm_id     = m.cpm_id     and
			m.card_bin   = i.card_bin
	}


	#
	# Map of variables to Engliah text
	# (for Admin screen rules set up)
	#
	#                     VALUE                  TEXT                                                        VARIABLE OR        INFO TYPE    RULE TYPE ('R'ule, 'M'essage, or 'B'oth)
	#                                                                                                        OPERATOR
	set VAR_MAP [list \
			[list "\$CCY"                "Customer's currency code"                                  "V"                "CCY_CODE"           "B"]\
			[list "\$CUST_CNTRY"         "Customer's country code"                                   "V"                "CNTRY_CODE"         "B"]\
			[list "\$CC_CNTRY"           "Customer's Card issue country"                             "V"                "CARD_CNTRY"         "R"]\
			[list "\$CC_SCHEME"          "Customer's Card scheme"                                    "V"                "CARD_SCHEME"        "B"]\
			[list "\$DEP_MTHDS"          "Customer's current deposit methods"                        "V"                "CPM"                "R"]\
			[list "\$WTD_MTHDS"          "Customer's current withdrawal methods"                     "V"                "CPM"                "R"]\
			[list "\$NUM_DEP_MTHDS"      "Customer's current number of active deposit methods"       "V"                "-"                  "R"]\
			[list "\$NUM_WTD_MTHDS"      "Customer's current number of active withdrawal methods"    "V"                "-"                  "R"]\
			[list "\$PMT_GW"             "Payment Gateway"                                           "V"                "PMT_GW"             "M"]\
			[list "\$CARD_BIN"           "Card Bin Range"                                            "V"                "CARD_BIN"           "M"]\
			[list "\$ENROL_3DS"          "Enrol 3DS Response"                                        "V"                "ENROL_3DS"         "M"]\
			[list "\$AUTH_3DS"           "Auth 3DS Response"                                         "V"                "AUTH_3DS"           "M"]\
			[list "\$GW_RET"             "Payment Gateway Return Code"                               "V"                "GW_RET"             "M"]\
			[list "EQUALS"               "equals"                                                    "O"                "-"]\
			[list "NOT_EQUALS"           "does not equal"                                            "O"                "-"]\
			[list "IN"                   "is one of"                                                 "O"                "-"]\
			[list "NOT_IN"               "is not one of"                                             "O"                "-"]\
			[list "GT"                   "is greater than"                                           "O"                "-"]\
			[list "LT"                   "is less than"                                              "O"                "-"]\
		   ]
}


################################################################################
#
#                           MAIN PROCEDURES
#
################################################################################




##
# CPMRules::get_active_cpm_for
#
# SYNOPSIS
#
#       [CPMRules::get_active_cpm_for <cust_id> <txn_type>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       [cust_id]  - customers id. like tCustomer.cust_id
#       [txn_type] - transaction type {DEP,WTD,BOTH}
#
# RETURN
#
#       {<code> {<pay_mthd>,<type>}}
#
#            <code>              - 0 : no active CP found for this tax type
#                                  1 : use <pay_mthd> of type <type> for this transaction.
#            {<pay_mthd>,<type>} - The highest priority active CPM for the requested
#                                 transaction type for this customer (if one exists)
#
# DESCRIPTION
#       Gets from the DB the active pay method the customer
#       has registered on their account for this transaction type. IF
#       there are multiple the highest priority one is returned.
#
#       1. Get all customer's active methods for this transaction type.
#       2. Check in order that the customer can still use each payment
#          method until one is found.
#       3. Return the payment method they should use or false otherwise.
#
##
proc get_active_cpm_for {cust_id txn_type {channel "I"} {testing 0}} {

	ob::log::write INFO {==>CPMRULES CALL get_active_cpm_for\
		txn_type:$txn_type channel=$channel testing=$testing}

	variable EXEC_RULES

	set to_use_id      ""
	set to_use_cpm     ""
	set ltxn_type      [string tolower $txn_type]


	#
	# Get the customer's active pay methods
	#
	set cpm_rs [tb_db::tb_exec_qry get_cust_active_cpms_${ltxn_type} $cust_id]


	#
	# Check that these methods can still be used for
	# this transaction type.
	#
	for {set i 0} {$i < [db_get_nrows $cpm_rs]} {incr i} {
		set mthd          [db_get_col $cpm_rs $i pay_mthd]
		set id            [db_get_col $cpm_rs $i cpm_id]
		set status_dep    [db_get_col $cpm_rs $i status_dep]
		set status_wtd    [db_get_col $cpm_rs $i status_wtd]
		set auth_dep      [db_get_col $cpm_rs $i auth_dep]
		set auth_wtd      [db_get_col $cpm_rs $i auth_wtd]
		set type          [db_get_col $cpm_rs $i type]
		set cpm_allow_id  [db_get_col $cpm_rs $i cpm_allow_id]
		set dep_rsn       [db_get_col $cpm_rs $i disallow_dep_rsn]
		set wtd_rsn       [db_get_col $cpm_rs $i disallow_wtd_rsn]


		ob::log::write INFO {Checking if customer can still use $mthd $type}
		if {[check_cpm_still_valid $cust_id $id $txn_type $cpm_allow_id $channel]} {
			set to_use_id  $cpm_allow_id
			break
		} else {
			ob::log::write INFO {$mthd $type : no longer allowed for this customer.}
			if {[OT_CfgGet CPM_RULES_UPDATE_CPM_ON_FAIL 1]} {

				# work out the reason why - which rule blocked it ?

				if {[info exists EXEC_RULES($cpm_allow_id)]} {
					set ${ltxn_type}_rsn "Pay Method not available due to\
						(1) DISALLOW CPM Rule(s): $EXEC_RULES($cpm_allow_id) OR\
						(2) tPayMthd.allow_${ltxn_type}=N"
				} elseif {$EXEC_RULES(forced) != ""} {
					set ${ltxn_type}_rsn "Pay Method not available due to\
						(1) FORCE CPM Rule(s): $EXEC_RULES(forced) OR\
						(2) tPayMthd.allow_${ltxn_type}=N"
				} else {
					set ${ltxn_type}_rsn "Pay Method not available\
						(tPayMthd.allow_${ltxn_type}=N)"
				}

				if {!$testing} {
					# update/delete this mthd for this trans type for the customer
					upd_cpm_txn_status      $id $txn_type \
								$status_dep $status_wtd \
								$auth_dep $auth_wtd \
								$dep_rsn $wtd_rsn
				}
			}
		}
	}

	#
	# Convert to mthd,type format
	#
	set to_use_cpm [convert_ids_to_mthds $to_use_id]


	#
	# clean up & work out what to return
	#
	db_close $cpm_rs
	if {[info exists EXEC_RULES]} {unset EXEC_RULES}
	ob::log::write INFO {<==CPMRULES RETURN get_active_cpm_for:\
		[list [llength $to_use_cpm] [lindex $to_use_cpm 0]]}
	return [list [llength $to_use_cpm] [lindex $to_use_cpm 0]]
}

##
# CPMRules::get_all_active_cpms_for - Gets all active CPMs for the given
#                                     customer
#
proc get_all_active_cpms_for {cust_id txn_type {channel "I"} {testing 0}} {

	ob::log::write INFO {==>CPMRULES CALL get_active_cpm_for\
		txn_type:$txn_type channel=$channel}

	variable EXEC_RULES

	set ltxn_type      [string tolower $txn_type]

	#
	# Get the customer's active pay methods
	#
	set cpm_rs [tb_db::tb_exec_qry get_cust_active_cpms_${ltxn_type} $cust_id]

	set ret_cpms [list]

	#
	# Check that these methods can still be used for
	# this transaction type.
	#
	set nrows [db_get_nrows $cpm_rs]
	for {set i 0} {$i < $nrows} {incr i} {

		set mthd          [db_get_col $cpm_rs $i pay_mthd]
		set id            [db_get_col $cpm_rs $i cpm_id]
		set status_dep    [db_get_col $cpm_rs $i status_dep]
		set status_wtd    [db_get_col $cpm_rs $i status_wtd]
		set auth_dep      [db_get_col $cpm_rs $i auth_dep]
		set auth_wtd      [db_get_col $cpm_rs $i auth_wtd]
		set type          [db_get_col $cpm_rs $i type]
		set cpm_allow_id  [db_get_col $cpm_rs $i cpm_allow_id]
		set dep_rsn       [db_get_col $cpm_rs $i disallow_dep_rsn]
		set wtd_rsn       [db_get_col $cpm_rs $i disallow_wtd_rsn]

		ob::log::write INFO {Checking if customer can still use $mthd $type}

		if {[check_cpm_still_valid $cust_id $id $txn_type $cpm_allow_id $channel]} {
			lappend ret_cpms $id $mthd
		} else {
			ob::log::write INFO {$mthd $type : no longer allowed for this customer.}
			if {[OT_CfgGet CPM_RULES_UPDATE_CPM_ON_FAIL 1]} {

				# work out the reason why - which rule blocked it ?

				if {[info exists EXEC_RULES($cpm_allow_id)]} {
					set ${ltxn_type}_rsn "Pay Method not available due to\
						(1) DISALLOW CPM Rule(s): $EXEC_RULES($cpm_allow_id) OR\
						(2) tPayMthd.allow_${ltxn_type}=N"
				} elseif {$EXEC_RULES(forced) != ""} {
					set ${ltxn_type}_rsn "Pay Method not available due to\
						(1) FORCE CPM Rule(s): $EXEC_RULES(forced) OR\
						(2) tPayMthd.allow_${ltxn_type}=N"
				} else {
					set ${ltxn_type}_rsn "Pay Method not available\
						(tPayMthd.allow_${ltxn_type}=N)"
				}

				if {!$testing} {
					# update/delete this mthd for this trans type for the customer
					upd_cpm_txn_status      $id $txn_type \
								$status_dep $status_wtd \
								$auth_dep $auth_wtd \
								$dep_rsn $wtd_rsn
				}
			}
		}
	}

	db_close $cpm_rs

	if {[llength $ret_cpms] == 0} {
		set code 0
	} else {
		set code 1
	}
	return [list $code $ret_cpms]


}



proc check_cust_needs_wtd_mthd {cust_id} {

	set cpm_rs [tb_db::tb_exec_qry non_withdrawable_mthds $cust_id]

	set nrows [db_get_nrows $cpm_rs]
	set wtd_mthd_needed 0
	for {set i 0} {$i < $nrows} {incr i} {
		set cpm_id [db_get_col $cpm_rs $i cpm_id]

		set rs [tb_db::tb_exec_qry check_linked_mthd $cust_id $cpm_id]
		if {![db_get_nrows $rs]} {
			set wtd_mthd_needed 1
			break
		}
	}

	if {$nrows} {
		db_close $rs
	}


	db_close $cpm_rs

	return $wtd_mthd_needed
}


proc check_cpm_valid {cust_id cpm_id txn_type {channel "I"} {testing 0}} {

	variable EXEC_RULES

	set cpm_rs [tb_db::tb_exec_qry get_cpm_allow $cpm_id]
	set success 0

	if {[db_get_nrows $cpm_rs] == 1} {
		set cpm_allow_id  [db_get_col $cpm_rs 0 cpm_allow_id]
	} else {
		ob_log::write ERROR {check_cpm_valid cannot get cpm_allow_i $cpm_id}
		db_close $cpm_rs
		return $success
	}
	db_close $cpm_rs

	if {[check_cpm_still_valid $cust_id $cpm_id $txn_type $cpm_allow_id $channel]} {
		set success 1
	} else {
		ob::log::write INFO {$mthd $type $cpm_id : no longer allowed for this customer.}

		if {[OT_CfgGet CPM_RULES_UPDATE_CPM_ON_FAIL 1]} {

			# work out the reason why - which rule blocked it ?

			if {[info exists EXEC_RULES($cpm_allow_id)]} {
				set ${ltxn_type}_rsn "Pay Method not available due to\
					(1) DISALLOW CPM Rule(s): $EXEC_RULES($cpm_allow_id) OR\
					(2) tPayMthd.allow_${ltxn_type}=N"
			} elseif {$EXEC_RULES(forced) != ""} {
				set ${ltxn_type}_rsn "Pay Method not available due to\
					(1) FORCE CPM Rule(s): $EXEC_RULES(forced) OR\
					(2) tPayMthd.allow_${ltxn_type}=N"
			} else {
				set ${ltxn_type}_rsn "Pay Method not available\
					(tPayMthd.allow_${ltxn_type}=N)"
			}

			if {!$testing} {
				# update/delete this mthd for this trans type for the customer
				upd_cpm_txn_status      $id $txn_type \
							$status_dep $status_wtd \
							$auth_dep $auth_wtd \
							$dep_rsn $wtd_rsn
			}
		}
	}

	# CPM allowed?
	return $success
}



proc check_cpm_can_register {cust_id pay_mthd pay_scheme txn_type} {

	set avail_mthds [payment_multi::get_avail_mthds $cust_id]

	if {[lindex $avail_mthds 0] != "OK"} {
		ob::log::write ERROR {==>check_cpm_can_register}
		return ERROR
	}

	if {[llength $avail_mthds] == 1} {
		# Not allowed to register more methods return empty
		return 0
	}

	set max_methods [lindex $avail_mthds 1]
	set found 0

	foreach {mthd scheme} $max_methods {
		if {$mthd == $pay_mthd && $scheme == $pay_scheme} {
			return 1
		}
	}

	return 0
}


##
# CPMRules::check_cpm_still_valid - checks if cust can still use this pay mthd
#
# SYNOPSIS
#
#       [CPMRules::check_cpm_still_valid <cust_id> <txn_type>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [cust_id]           - customers id. like tCustomer.cust_id
#       [txn_type]          - transaction type {DEP,WTD}
#       [cpm_allow_id]      - the "cpm" we are checking (like tPayMthdAllow.cpm_allow_id)
#       [<channel>]         - the current channel - default is internet (I)
#       [<and_suspended>] - include suspended rules (for Admin testing)
#
# RETURN
#
#       0 - unsucessful
#       positive integer - success
#
# DESCRIPTION
#
#       Checks to see if the customer can still use this CPM method
#       for the particular type of transaction they are doing.
#
#       1. Get the necessary account information for the customer.
#       2. Evaluate the rules.
#       3. If the method is in the result list return true
#          Otherwise delete/update the payment method and return false.
#
##
proc check_cpm_still_valid {cust_id cpm_id txn_type cpm_allow_id {channel "I"} {and_suspended 0} } {
	ob::log::write INFO {==>check_cpm_still_valid txn_type=$txn_type cpm_allow_id=$cpm_allow_id channel=$channel and_suspended=$and_suspended}

	global DB
	variable CUST_RULE_DETAILS

	#
	# get the necessary customer details
	#
	get_cust_rule_details $cust_id $cpm_id


	#
	# execute rules query
	#
	set channel "%$channel%"
	set statusa "A"
	set statusb [expr {$and_suspended?"S":"A"}]

	set rs [tb_db::tb_exec_qry get_all_cpm_rules $txn_type $statusa $statusb $statusa $statusb $channel]

	#
	# evaluate which CPMs are available to the customer
	#
	set cpm_allow_list [evaluate_cpm_rules $rs $txn_type]

	if {[OT_CfgGet CPM_CHECK_CARD_BIN 0]} {
		set cpm_rs [tb_db::tb_exec_qry get_cpm_allow $cpm_id]

		set pay_mthd [db_get_col $cpm_rs 0 pay_mthd]
		db_close $cpm_rs

		if {$pay_mthd == "CC"} {
			set cpm_allow_list \
				[check_card_bin $cust_id $cpm_allow_list $txn_type $cpm_id]
		}
	}

	#
	# clean up
	#
	db_close $rs
	unset CUST_RULE_DETAILS

	ob::log::write INFO {==>check_cpm_valid RETURNING [expr {[lsearch -exact $cpm_allow_list $cpm_allow_id]==-1?0:1}]}
	return [expr [lsearch -exact $cpm_allow_list $cpm_allow_id]==-1?0:1]
}

##
# CPMRules::check_card_bin
#
# SYNOPSIS
#
#       [CPMRules::check_card_bin <cpm_id_list> <txn_type>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       [cust_id]      - cust_id
#       [cpm_id_list]  - cpm id list - a list of valid cpms after going through
#                      cpm rules checks
#       [txn_type]     - DEP or WTD
#       [cpm_id]       - cpm_id to check
#
# RETURN
#
#       [cpm_id_list] - a new list with any credit cards with bad bins removed
#
# DESCRIPTION
#       1. Loops through the given list of cpms
#       2. Check to see if its a credit card
#       3. If it is then check the bin, if not just append to allowed list
#       4. Check the bin against either tcardinfo or tcardschemeinfo
#       5. If allowed then append to list
#
##
proc check_card_bin {cust_id cpm_id_list txn_type cpm_id} {

	set txn_type        [string tolower $txn_type]
	set allow_list [list]
	set mthds_list [convert_ids_to_mthds $cpm_id_list]

	for {set i 0} {$i < [llength $cpm_id_list]} {incr i} {

		set cpm_type_id [lindex $cpm_id_list $i]

		# check to see if its a card
		if {[string first "CC" [lindex $mthds_list $i]] != -1} {
			# check the bin range

			if {[OT_CfgGet CPM_CARD_BIN_TABLE "tcardinfo"] == "tcardschemeinfo"} {
				set qry get_scheme_allow
			} else {
				set qry get_info_allow
			}

			set rs [tb_db::tb_exec_qry $qry $cpm_id]

			# Only add the cpm_id if we get back one row, we know the card data ok
			if {[db_get_nrows $rs] == 1} {

				set allow [db_get_col $rs 0 "allow_$txn_type"]
				if {$allow == "Y"} {
					lappend allow_list $cpm_type_id
				}
			}

			db_close $rs

		} else {
			lappend allow_list $cpm_type_id
		}
	}
	return $allow_list

}


proc check_all_avail_cpms {cust_id txn_type {override_ccy ""} \
	{channel "I"} {and_suspended 0} {ignore_duplicate_check 0} {ignore_methods ""}} {

	ob::log::write INFO {==>CPMRULES CALL check_avail_cpms cust_id=$cust_id txn_type=$txn_type override_ccy=$override_ccy channel=$channel and_suspended=$and_suspended ignore_duplicate_check=$ignore_duplicate_check}

	global DB
	variable CUST_RULE_DETAILS


	#
	# get the necessary customer details
	#
	get_cust_rule_details $cust_id $override_ccy


	#
	# execute query
	#
	set channel "%$channel%"
	set statusa "A"
	set statusb [expr {$and_suspended?"S":"A"}]
	set rs [tb_db::tb_exec_qry get_all_cpm_rules $txn_type $statusa $statusb $statusa $statusb $channel]


	#
	# evaluate which CPMs are available to the customer
	#
	set cpm_allow_list [evaluate_cpm_rules $rs $txn_type]


	#
	# Take the cpm_allow_id list and convert it into more
	# meaningful (pay_mthd,type) tuples.
	#
	set cpm_list [convert_ids_to_mthds $cpm_allow_list]


	#
	# Make sure the customer does not register a
	# method they already have registered on their
	# account.
	#
	if {!$ignore_duplicate_check} {
		ob::log::write INFO {==>check_avail_cpms reged_cpms=$CUST_RULE_DETAILS(reged_cpms)}
		foreach rcpm $CUST_RULE_DETAILS(reged_cpms) {

			# we may want to ignore duplicate checks for certain methods
			if {[lsearch $ignore_methods $rcpm] > -1} {
				ob::log::write DEBUG {==>check_avail_cpms ignoring $rcpm}
				continue
			}

			# go through cpm_list and checl for matching mthds
			set new_list [list]
			ob::log::write DEBUG {==>check_avail_cpms BEFORE cpm_list=$cpm_list}
			for {set i 0} {$i < [llength $cpm_list]} {incr i} {
				set m [lindex $cpm_list $i]
				if {[lindex $m 0] != $rcpm} {
					# build new list
					lappend new_list $m
				} else {
					ob::log::write DEBUG {Taking $m out of returned values.}
				}
			}
			ob::log::write DEBUG {==>check_avail_cpms new_list=$new_list}
			set cpm_list $new_list
			ob::log::write DEBUG {==>check_avail_cpms cpm_list=$cpm_list}
		}
	}


	#
	# clean up
	#
	db_close $rs
	unset CUST_RULE_DETAILS

	ob::log::write INFO {<==CPMRULES RETURN check_avail_cpms : $cpm_list}
	return $cpm_list
}




##
# CPMRules::check_avail_cpms - checks which pay mthds a cust can use for a txn type
#
# SYNOPSIS
#
#       [CPMRules::check_avail_cpms <cust_id> <txn_type>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       <cust_id>         - customers id. like tCustomer.cust_id
#       <txn_type>        - transaction type {DEP,WTD}
#       [<override_ccy>]  - override the customer's DB ccy. (Special case for registration)
#       [<channel>]       - the current channel - default is internet (I)
#       [<and_suspended>] - include suspended rules (for Admin testing)
#       [<max_methods>]   - ma
#
# RETURN
#
#       List of CPM's a customer can register for this transaction type.
#       List of distinct tPayMthd.pay_mthd values.
#
# DESCRIPTION
#
#       Customer wishes to make a transaction. He currently has no
#       active method registered to make this transaction with.
#
#       1. Get the customers details
#       2. Evaluate the CPM rules
#       3. Return an ordered list of pay methods and their schemes.
#
##
proc check_avail_cpms {cust_id txn_type {override_ccy ""} \
	{channel "I"} {and_suspended 0} {ignore_duplicate_check 0} {ignore_methods ""} {max_methods 0}} {

	ob::log::write INFO {==>CPMRULES CALL check_avail_cpms cust_id=$cust_id txn_type=$txn_type override_ccy=$override_ccy channel=$channel and_suspended=$and_suspended ignore_duplicate_check=$ignore_duplicate_check}

	global DB
	global CARD_SCHEMES
	variable CUST_RULE_DETAILS

	#
	# get the necessary customer details
	#
	get_cust_rule_details $cust_id $override_ccy

	#
	# execute query
	#
	set channel "%$channel%"
	set statusa "A"
	set statusb [expr {$and_suspended?"S":"A"}]
	set rs [tb_db::tb_exec_qry get_all_cpm_rules $txn_type $statusa $statusb $statusa $statusb $channel]

	#
	# evaluate which CPMs are available to the customer
	#
	set cpm_allow_list [evaluate_cpm_rules $rs $txn_type]
	db_close $rs
	#
	# Take the cpm_allow_id list and convert it into more
	# meaningful (pay_mthd,type) tuples.
	#
	set cpm_list [convert_ids_to_mthds $cpm_allow_list]
	set cpms_allow_list ""

	if {!$ignore_duplicate_check} {
		ob::log::write INFO {==>check_avail_cpms reged_cpms=$CUST_RULE_DETAILS(reged_cpms)}
		foreach rcpm $CUST_RULE_DETAILS(reged_cpms) {

			# we may want to ignore duplicate checks for certain methods
			if {[lsearch $ignore_methods $rcpm] > -1} {
				ob::log::write DEBUG {==>check_avail_cpms ignoring $rcpm}
				continue
			}

			# go through cpm_list and checl for matching mthds
			set new_list [list]
			ob::log::write DEBUG {==>check_avail_cpms BEFORE cpm_list=$cpm_list}
			for {set i 0} {$i < [llength $cpm_list]} {incr i} {
				set m [lindex $cpm_list $i]
				if {[lindex $m 0] != $rcpm} {
					# build new list
					lappend new_list $m
				} else {
					ob::log::write DEBUG {Taking $m out of returned values.}
				}
			}
			ob::log::write DEBUG {==>check_avail_cpms new_list=$new_list}
			set cpm_list $new_list
			ob::log::write DEBUG {==>check_avail_cpms cpm_list=$cpm_list}
		}
	}

	if {$max_methods} {
	  # Call to check the max methods allowed for the customer
	  #
	  set max_methods [payment_multi::get_avail_mthds $cust_id]

	  if {[lindex $max_methods 0] != "OK"} {
		  ob::log::write ERROR {==>check_avail_cpms}
		  return ERROR
	  }

	  if {[llength $max_methods] == 1} {
		  # Not allowed to register more methods return empty
		  return ""
	  }

	  set max_methods [lindex $max_methods 1]
	  set cpm_list [join $cpm_list]

	  foreach {mthd scheme} $max_methods {
		  set found [lsearch $cpm_list $mthd]

		  if {$found > -1} {
			  lappend cpms_allow_list [list $mthd $scheme]
		  }
	  }
	} else {
		set cpm_list [join $cpm_list]

		foreach {mthd scheme} $cpm_list {
			if {$mthd == "CC"} {
				pmt_util::_get_schemes $txn_type
				for {set i 0} {$i < $CARD_SCHEMES(num_card_scheme)} {incr i} {
					lappend cpms_allow_list [list $mthd $CARD_SCHEMES($i)]
				}
			} else {
				lappend cpms_allow_list [list $mthd "----"]
			}
		}
	}

	#
	# clean up
	#
	unset CUST_RULE_DETAILS

	ob::log::write INFO {<==CPMRULES RETURN check_avail_cpms : $cpm_list}
	return $cpms_allow_list
}


##
# CPMRules::check_for_cpm_msg
#
# SYNOPSIS
#
#       [CPMRules::check_for_cpm_msg <cust_id> <msg_point>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       [cust_id]   - customers id. like tCustomer.cust_id
#       [msg_point] - what action the customer performed.
#                     like CPMMsg.msg_point. one from {REG,LOGIN,DEP,WTD}
#       [override_ccy]    - override the customer's DB ccy. (Special case for registration)
#       [<channel>]       - the current channel - default is internet (I)
#       [<and_suspended>] - include suspended rules (for Admin testing)
#
# RETURN
#
#       {0} - no message needs to be shown to the customer
#       {1 <msg>} - show 'msg' to the customer
#
# DESCRIPTION
#
#       Checks to see if a message needs to be shown to the
#       customer based on what action they have preformed.
#       and
#
##
proc check_for_cpm_msg {cust_id msg_point {override_ccy ""} {channel "I"} {and_suspended 0} {pmt_id -1}} {
	ob::log::write INFO {==>CPMRULES CALL check_for_cpm_msg cust_id=$cust_id \
							                  msg_point=$msg_point \
							                  override_ccy=$override_ccy \
							                  channel=$channel \
							                  and_suspended=$and_suspended \
							                  pmt_id=$pmt_id}

	global DB
	variable CUST_RULE_DETAILS


	#
	# get the necessary customer details
	#
	get_cust_rule_details $cust_id {} $override_ccy {} $pmt_id


	#
	# execute query
	#
	set channel "%$channel%"
	set statusa "A"
	set statusb [expr {$and_suspended?"S":"A"}]
	set rs [tb_db::tb_exec_qry get_msg_rules $msg_point $statusa $statusb $statusa $statusb $channel]


	#
	# Evaluate which messages if any should be
	# displayed to the customer
	#
	set msg_list [evaluate_msg_rules $rs $msg_point]


	#
	# clean up
	#
	db_close $rs
	unset CUST_RULE_DETAILS


	#
	# return necessary messages
	#
	ob::log::write INFO {==>CPMRULES RETURN check_for_cpm_msg : [llength $msg_list] $msg_list}
	return [list [llength $msg_list] $msg_list]
}


##
# CPMRules::evaluate_msg_rules - Evaluates message rules and builds message list.
#
# SYNOPSIS
#
#       [CPMRules::evaluate_msg_rules <rs>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [rs] - a result set of message rules
#
# RETURN
#
#       List of messages that should be displayed to the customer.
#
# DESCRIPTION
#
#
#
##
proc evaluate_msg_rules {rs {msg_point ""}} {
	ob::log::write DEBUG {==>evaluate_msg_rules}

	global DB


	#
	# intialiase variables
	#
	set msg_list   [list]


	#
	# loop through the rules and build msg list
	#
	set last_level "none"
	set val        "none"
	set num_ops   [db_get_nrows $rs]

	set matched_id -1
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {

		# if not the first iteration set 'last' variables
		if {$r != 0} {
			set last_level $level
		}

		# retrieve next rule details
		set op    [db_get_col $rs $r op_operator]
		set lval  [db_get_col $rs $r op_left_value]
		set rval  [db_get_col $rs $r op_right_value]
		set level [db_get_col $rs $r op_level]
		set id    [db_get_col $rs $r rule_id]
		set msg   [db_get_col $rs $r msg]

		ob::log::write INFO {Current Msg Rule : ID:$id : $lval $op $rval => $msg}


		# Get the value of this rule op
		set this_val [do_op $lval $op $rval]


		# then we have changed rule
		# * we should set last_level to force an AND
		# * also set 'val' to 'this_val' to get the correct result from the AND
		if {$r == 0 || ($r > 0 && $id != [db_get_col $rs [expr $r-1] rule_id])} {

			set last_level $level
			set val        $this_val
		}


		# Combine this rule op with previous running value.
		# On the same level is 'and'.
		# On different levels is 'or'.
		if {$level == $last_level} {
			set val [expr {$this_val && $val}]
		} else {
			set val [expr {$this_val || $val}]
		}
		ob::log::write DEBUG {==>evaluate_msg_rules: after val = $val}


		# Check whether we need to add the current msg to the list.
		#
		# We check only when the next msg/level is different
		# or when we are on the last row in the result set.
		if {$val && ($r == [expr {$num_ops -1}] || \
		    $id != [db_get_col $rs [expr {$r + 1}] rule_id] || \
			$level != [db_get_col $rs [expr {$r + 1}] op_level])} {
			lappend msg_list $msg

			# Remember the first rule_id that is matched
			if {$matched_id == -1} {
				set matched_id $id
			}
		}

		ob::log::write DEBUG {this_val=$this_val val=$val level=$level last_level=$last_level}

	}


	#
	# return the message list and the rule id
	#
	if {$msg_point != "DEP_DECL"} {
		return $msg_list
	} else {
		return [list $matched_id $msg_list]
	}
}


##
# CPMRules::evaluate_cpm_rules - Evaluates pay mthd rules and builds CPM list.
#
# SYNOPSIS
#
#       [CPMRules::evaluate_cpm_rules <rs> <txn_type>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [rs] - a result set of rules
#       [txn_type] - transaction type : WTD or DEP
#
# RETURN
#
#       List of CPM's a customer can use..
#       List of distinct tPayMthd.pay_mthd values.
#
# DESCRIPTION
#
#
#
##
proc evaluate_cpm_rules {rs txn_type} {
	ob::log::write DEBUG {==>evaluate_cpm_rules}

	global DB
	variable EXEC_RULES


	#
	# intialiase variables
	#
	set full_avail_id_list   [get_all_avail_cpm_ids $txn_type]
	set avail_cpm_ids        $full_avail_id_list
	set force_cpm_ids        [list]
	set EXEC_RULES(forced)   ""

	#
	# loop through the rules and build both available
	# and force pay method lists
	#
	set last_level "none"
	set val        "none"
	set num_ops   [db_get_nrows $rs]
	# summary_val preserves the value of the last levels in  a rule
	# it is ||ed, so default to 0
	set summary_val 0

	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {

		# if not the first iteration set 'last' variables
		if {$r != 0} {
			set last_level $level
		}

		# retrieve next rule details
		set op    [db_get_col $rs $r op_operator]
		set lval  [db_get_col $rs $r op_left_value]
		set rval  [db_get_col $rs $r op_right_value]
		set level [db_get_col $rs $r op_level]
		set cpm   [db_get_col $rs $r pay_mthd]
		set aid   [db_get_col $rs $r cpm_allow_id]
		set rtype [db_get_col $rs $r rule_type]
		set ptype [db_get_col $rs $r pmt_type]
		set rid   [db_get_col $rs $r rule_id]
		set rname [db_get_col $rs $r rule_name]

		ob::log::write INFO {Evaluating CPM rule: ID=$rid NAME=$rname}

		# summary_val - value of past levels
		# val         - value of current level
		# this_val    - value of current op

		# Get the value of this rule op
		set this_val [do_op $lval $op $rval]


		# then we have changed rule
		# * we should set last_level to force an AND
		# * also set 'val' to 'this_val' to get the correct result from the AND
		#
		# do likewise if it's the first iteration
		if {$r == 0 || ($r > 0 && $rid != [db_get_col $rs [expr $r-1] rule_id])} {
			set last_level     $level
			set val            $this_val
			set summary_val    0
		}

		set change_rule [expr {($r ==  $num_ops -1)
		 || ($rid != [db_get_col $rs [expr $r+1] rule_id])}]

		# Combine this rule op with previous running value.
		# On the same level is 'and'.
		# On different levels is 'or'.
		set check_val 1
		if {$level == $last_level} {
			set val [expr {$this_val && $val}]
			if {$change_rule} {
				set check_val [expr {$val || $summary_val}]
			}
		} else {
			set summary_val [expr {$val || $summary_val}]
			set val $this_val
			if {$change_rule} {
				set check_val [expr {$this_val || $summary_val}]
			}
		}


		# Check whether we need to take the current pay mthd
		# from the allow list or whether we need to add it to the
		# force list. If adding to the force list we first need
		# to make sure the cpm is available first by checking if
		# it exists in the full vailable list.
		#
		# We check only when the next pay mthd is different
		# or when we are on the last row in the result set.
		if {$check_val && ($r == [expr $num_ops -1] || $rid != [db_get_col $rs [expr $r+1] rule_id])} {
			if {$rtype == "FORCE" && [lsearch -exact $full_avail_id_list $aid]!=-1} {
				ob::log::write DEBUG {==>evaluate_cpm_rules: Adding $aid to force list}

				lappend force_cpm_ids $aid
				set EXEC_RULES(forced) "$EXEC_RULES(forced) $rname"
			} else {
				# rule_type is 'DISALLOW'
				ob::log::write DEBUG {==>evaluate_cpm_rules: Taking $aid out of available list}

				# populate vars so we know which rule bloocked out pmt mthd
				if {[info exists EXEC_RULES($aid)]} {
					set EXEC_RULES($aid) "$EXEC_RULES($aid) $rname"
				} else {
					set EXEC_RULES($aid) $rname
				}

				set pos [lsearch -exact $avail_cpm_ids $aid]
				if {$pos != -1} {
					set avail_cpm_ids [lreplace $avail_cpm_ids $pos $pos]
				}
			}
		}
	}


	#
	# if there exists mthds in the force list then return
	# that, else return what exist in the available list
	#
	if {[llength $force_cpm_ids]} {
		ob::log::write INFO {==>evaluate_cpm_rules: returning force list :$force_cpm_ids}
		return $force_cpm_ids
	} else {
		ob::log::write INFO {==>evaluate_cpm_rules: returning avail list :$avail_cpm_ids}
		return $avail_cpm_ids
	}
}


##
# CPMRules::do_op - evaluates a component of a rule
#
# SYNOPSIS
#
#       [CPMRules::do_op <lval> <op> <rval>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [lval] - left hand side of rule. like tCPMOp.op_left_value
#       [op]   - operator. like tCPMOp.op_operator
#       [rval] - right hand side of rule. like tCPMOp.o_right_value
#
# RETURN
#
#       Whether this rule component evaluated to true or false.
#
# DESCRIPTION
#
#
#
##
proc do_op {lval op rval} {

	ob::log::write DEBUG {==>do_op: lval=$lval op=$op rval=$rval}

	variable CUST_RULE_DETAILS

	#
	# set up variables. These are the ones available to
	# use in the tCPMOp rule table.
	#
	set result             ""
	set CCY                $CUST_RULE_DETAILS(ccy)
	set CUST_CNTRY         $CUST_RULE_DETAILS(cust_cntry)
	set CC_CNTRY           $CUST_RULE_DETAILS(cc_cntry)
	set CC_SCHEME          $CUST_RULE_DETAILS(cc_scheme)
	set DEP_MTHDS          $CUST_RULE_DETAILS(dep_mthds)
	set WTD_MTHDS          $CUST_RULE_DETAILS(wtd_mthds)
	set NUM_DEP_MTHDS      $CUST_RULE_DETAILS(num_dep_mthds)
	set NUM_WTD_MTHDS      $CUST_RULE_DETAILS(num_wtd_mthds)

	#
	# These variable are specific for deposit decline
	#
	set PMT_GW    $CUST_RULE_DETAILS(pg_type)
	set CARD_BIN  $CUST_RULE_DETAILS(card_bin)
	set ENROL_3DS $CUST_RULE_DETAILS(enrol_3d_resp)
	set AUTH_3DS  $CUST_RULE_DETAILS(auth_3d_resp)
	set GW_RET    $CUST_RULE_DETAILS(gw_ret_code)

	ob::log::write DEV {CCY=$CCY CUST_CNTRY=$CUST_CNTRY CC_CNTRY=$CC_CNTRY CC_SCHEME=$CC_SCHEME\
				DEP_MTHDS=$DEP_MTHDS WTD_MTHDS=$WTD_MTHDS NUM_DEP_MTHDS=$NUM_DEP_MTHDS\
				NUM_WTD_MTHDS=$NUM_WTD_MTHDS PMT_GW=$PMT_GW CARD_BIN=$CARD_BIN\
				ENROL_3DS=$ENROL_3DS AUTH_3DS=$AUTH_3DS GW_RET=$GW_RET}

	set lval [string trim [subst $lval]]
	set op [string trim $op]
	set rval [string trim [subst $rval]]

	#
	# do the evaluation
	#
	if {[catch {
		switch -- $op {
			"IN"            {
						set r      [lsearch -exact "$rval" "$lval" ]
						set result [expr {$r == -1 ? 0:1}]
					}
			"NOT_IN"        {
						set r      [lsearch -exact "$rval" "$lval" ]
						set result [expr {$r == -1 ? 1:0}]
					}
			"EQUALS"        {
						set result [expr [subst "{$lval} == {$rval}"]]
					}
			"NOT_EQUALS"    {
						set result [expr [subst "{$lval} != {$rval}"]]
					}
			"GT"            {
						set result [expr [subst "{$lval} > {$rval}"]]
					}
			"LT"            {
						set result [expr [subst "{$lval} < {$rval}"]]
					}
		}
		ob::log::write INFO {Evaluating : *[subst $lval]*$op*[subst $rval]* to $result}
	} msg]} {
		ob::log::write WARNING {WARNING WARNING Problem evaluating rule - component syntax must be changed!!}
		return 0
	}

	return $result
}




##
# CPMRules::cpm_reg_possible_for
#
# SYNOPSIS
#
#       [CPMRules::cpm_reg_possible_for <cust_id> <txn_type> <pay_mthd> <cpm_type> [<channel>]]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       <cust_id>  - the customers cust_id
#       <txn_type> - DEP or WTD
#       <pay_mthd> - payment method (like tCustPayMthd.pay_mthd) CC, NTLR
#       <cpm_type> - pay method type (like tCustPayMthd.type)
#       <channel>  - the channel we eant to check for
#
# RETURN
#
#       {1}           - success
#       {2 <cpm_id>}  - customer already has a payment method of this
#                       type. Return the cpm_id of this method.
#       {0 <message>} - can no longer register this method and cust does
#                       not have one already registered. Return a message to show the customer.
#
# DESCRIPTION
#
#
#
##
proc cpm_reg_possible_for {cust_id txn_type pay_mthd cpm_type {channel "I"} {card_no ""} {ccy ""} {cust_country ""} {check_max_methods 0} } {

	variable CUST_REG_DETAILS

	ob::log::write INFO {==>cpm_reg_possible_for cust_id=$cust_id txn_type:$txn_type pay_mthd=$pay_mthd cpm_type=$cpm_type channel=$channel}

	global DB

	if {[string length card_no]} {
		set CUST_REG_DETAILS(cc_scheme)      \
			[lindex [card_util::get_card_scheme $card_no] 0]
		set cpm_type $CUST_REG_DETAILS(cc_scheme)
	}


	set cpm_type [expr {$cpm_type == ""?"-":$cpm_type}]
	set CUST_REG_DETAILS(ccy)            $ccy
	set CUST_REG_DETAILS(cust_cntry)     $cust_country


	#
	# Get all available pay methods for this customer
	# doing this type of transaction.
	#
	set result [check_avail_cpms $cust_id $txn_type "" $channel 0 1 "" 0]
	#
	# Loop through the results and see if our method is in there ?
	#
	foreach cpm_pair $result {
		set res_pay_mthd [lindex $cpm_pair 0]
		set res_type     [lindex $cpm_pair 1]

        if {$res_pay_mthd==$pay_mthd && ($res_type==$cpm_type || $res_type=="----" && $cpm_type=="-")} {
			catch {unset CUST_REG_DETAILS}
			ob::log::write DEBUG {<==cpm_reg_possible_for RETURNING:[list 1]}
			if {$check_max_methods} {
				if {$cpm_type == "-"} {
					set scheme "----"
				} else {
					set scheme $cpm_type
				}

				set result [check_cpm_can_register $cust_id $pay_mthd $scheme DEP]
				if {$result} {
					return [list 1]
				} else {
					return [list 0 CPM_MAX_ALLOWED]
				}
			} else {
				return [list 1]
			}
		}
	}

	#
	# If we are not registering a new method then get
	# the cpm ID of the customer's currently registered method.
	#
	set cpm_rs [tb_db::tb_exec_qry get_cust_active_cpms $cust_id]

	for {set i 0} {$i < [db_get_nrows $cpm_rs]} {incr i} {
		set res_pay_mthd   [db_get_col $cpm_rs $i pay_mthd]
		set res_dep        [db_get_col $cpm_rs $i status_dep]
		set res_wtd        [db_get_col $cpm_rs $i status_wtd]
		set res_cpm_id     [db_get_col $cpm_rs $i cpm_id]
		set res_type       [db_get_col $cpm_rs $i type]

		ob::log::write DEV {Checking if the customer has this method registered already? $res_pay_mthd==$pay_mthd $res_type==$cpm_type}

		if {$res_pay_mthd==$pay_mthd && $res_type==$cpm_type} {
			# registered method found
			ob::log::write DEBUG {<==cpm_reg_possible_for RETURNING:[list 2 $res_cpm_id]}
			db_close $cpm_rs
			catch {unset CUST_REG_DETAILS}
			return [list 2 $res_cpm_id]
		}
	}
	db_close $cpm_rs


	#
	# If we get this far then it means that payment method rules
	# have changed since they first clicked 'Deposit'/'Withdraw'. As a result
	# they cannot register the payment method we offered them originally.
	#

	catch {unset CUST_REG_DETAILS}
	ob::log::write INFO {<==cpm_reg_possible_for RETURNING:[list 0]}
	return [list 0 CPM_NO_LONGER_AVAILABLE]

}


################################################################################
#
#                           UTILITY PROCEDURES
#
################################################################################




##
# CPMRules::get_all_avail_cpm_ids gets a list of all avail CPM's
#
# SYNOPSIS
#
#       [CPMRules::get_all_avail_cpm_ids]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [txn_type]  -  making a deposit or withdrawal ?
#
# RETURN
#
#       A list of all pay methods. List of tPayMthd.pay_mthd.
#
# DESCRIPTION
#
#
#
##
proc get_all_avail_cpm_ids {txn_type} {
	ob::log::write INFO {==>get_all_avail_cpm_ids txn_type=$txn_type}

	global DB

	set cpm_allow_ids   ""
	set txn_type        [string tolower $txn_type]


	#
	# execute query
	#
	set rs [tb_db::tb_exec_qry get_${txn_type}_avail_cpm_ids]


	#
	# create list
	#
	for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
		lappend cpm_allow_ids [db_get_col $rs $r cpm_allow_id]
	}

	db_close $rs


	ob::log::write INFO {==>get_all_avail_cpm_ids: returning $cpm_allow_ids}
	return $cpm_allow_ids
}


##
# CPMRules::get_cust_rule_details - gets cust details needed for rule evaluation.
#
# SYNOPSIS
#
#       [CPMRules::get_cust_rule_details <cust_id>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [cust_id]          - customers id. like tCustomer.cust_id
#       [override_ccy]     - override the customer's ccy
#
# RETURN
#
#       Sets the CUST_RULE_DETAILS namespace variable appropriately.
#
# DESCRIPTION
#
#       Sets all variables necessary for the evaluation of
#       the rules.
#             1. Sets any config file vars needed.
#             2. Gets all active CPMs for the customer and seta any related vars.
#
##
proc get_cust_rule_details {cust_id cpm_id {override_ccy ""} {override_cntry ""} {pmt_id -1}} {
	ob::log::write INFO {==>get_cust_rule_details}

	global DB
	variable CUST_RULE_DETAILS
	variable CUST_REG_DETAILS


	#
	# Initialise variables used in rules
	#

	set CUST_RULE_DETAILS(cc_cntry)             ""
	set CUST_RULE_DETAILS(dep_mthds)            ""
	set CUST_RULE_DETAILS(wtd_mthds)            ""
	set CUST_RULE_DETAILS(num_dep_mthds)        0
	set CUST_RULE_DETAILS(num_wtd_mthds)        0
	set CUST_RULE_DETAILS(reged_cpms)           ""
	set CUST_RULE_DETAILS(cc_scheme)            ""

	#
	# The following vars are for deposit decline rules
	#
	set CUST_RULE_DETAILS(pg_type)              ""
	set CUST_RULE_DETAILS(card_bin)             -1
	set CUST_RULE_DETAILS(enrol_3d_resp)        ""
	set CUST_RULE_DETAILS(auth_3d_resp)         ""
	set CUST_RULE_DETAILS(gw_ret_code)          -1

	#
	# Get customer details
	#
	get_customer_details $cust_id $override_ccy $override_cntry

	#
	# We maybe doing a registration, use the overides for that here
	# We need to do this because we do not know the scheme etc
	# before we register the card
	#

	foreach r {cc_scheme cust_cntry ccy} {
		if {[info exists CUST_REG_DETAILS($r)] && $CUST_REG_DETAILS($r) != ""} {
			set CUST_RULE_DETAILS($r) $CUST_REG_DETAILS($r)
		}
	}

	#
	# Work out what deposit / withdraw methods the customer has
	# and set details appropriately.
	#

	# Get all the active CPM's for this customer
	set cpm_rs [tb_db::tb_exec_qry get_cust_active_cpms $cust_id]

	set dep_cpms   ""
	set wtd_cpms   ""
	set both_cpms  ""
	for {set i 0} {$i < [db_get_nrows $cpm_rs]} {incr i} {
		set mthd           [db_get_col $cpm_rs $i pay_mthd]
		set s_dep          [db_get_col $cpm_rs $i status_dep]
		set s_wtd          [db_get_col $cpm_rs $i status_wtd]
		set cpm_id_current [db_get_col $cpm_rs $i cpm_id]

		lappend CUST_RULE_DETAILS(reged_cpms) $mthd
		get_cpm_details $cust_id $cpm_id_current $mthd
		ob::log::write DEBUG {==>get_cust_rule_details current method = $mthd}

		# build cpm lists
		if {$s_dep == "A" && $s_wtd == "A"} {
			lappend both_cpms $mthd
		} elseif {$s_dep == "A"} {
			lappend dep_cpms $mthd
		} elseif {$s_wtd == "A"} {
			lappend wtd_cpms $mthd
		}
	}
	ob::log::write INFO {==>get_cust_rule_details: both_cpms=*$both_cpms* dep_cpms=*$dep_cpms* wtd_cpms=*$wtd_cpms*}
	ob::log::write INFO {==>get_cust_rule_details: num CPMs : [db_get_nrows $cpm_rs]}
	ob::log::write INFO {==>get_cust_rule_details: possible deposit CPMS : [expr [llength $dep_cpms]+[llength $both_cpms]]}
	ob::log::write INFO {==>get_cust_rule_details: possible withdraw CPMS : [expr [llength $wtd_cpms]+[llength $both_cpms]]}

	# Set CPM method vars
	set CUST_RULE_DETAILS(dep_mthds)            "$both_cpms $dep_cpms"
	set CUST_RULE_DETAILS(wtd_mthds)            "$both_cpms $wtd_cpms"
	set CUST_RULE_DETAILS(num_dep_mthds)        [llength $CUST_RULE_DETAILS(dep_mthds)]
	set CUST_RULE_DETAILS(num_wtd_mthds)        [llength $CUST_RULE_DETAILS(wtd_mthds)]

	#
	# Clean up
	#
	db_close $cpm_rs

	#
	# Determine values of the variables for deposit decline
	#
	if {$pmt_id != -1} {
		set decl_rs [tb_db::tb_exec_qry get_dep_decl_vars $pmt_id]

		if {[db_get_nrows $decl_rs] != 1} {
			# We should only get exactly one row back
			ob::log::write ERROR {get_cust_rule_details: get_dep_decl_vars failed to get exactly one row}
			return
		}

		set CUST_RULE_DETAILS(pg_type)              [db_get_col $decl_rs 0 pg_type]
		set CUST_RULE_DETAILS(card_bin)             [db_get_col $decl_rs 0 card_bin]
		set CUST_RULE_DETAILS(enrol_3d_resp)        [db_get_col $decl_rs 0 enrol_3d_resp]
		set CUST_RULE_DETAILS(auth_3d_resp)         [db_get_col $decl_rs 0 auth_3d_resp]
		set CUST_RULE_DETAILS(gw_ret_code)          [db_get_col $decl_rs 0 gw_ret_code]
		set CUST_RULE_DETAILS(cc_scheme)            [db_get_col $decl_rs 0 scheme]

		db_close $decl_rs
	}

}


##
# CPMRules::get_cpm_details - gets cpm details needed for rule evaluation.
#
# SYNOPSIS
#
#       [CPMRules::get_cpm_details <cust_id> <cpm>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [cust_id] - customers id. like tCustomer.cust_id
#       [cpm]     - the cpm we are checking (like tPayMthd.pay_mthd)
#
# RETURN
#
#
#
# DESCRIPTION
#
#
#
##
proc get_cpm_details {cust_id cpm_id mthd} {
	ob::log::write INFO {==>get_cpm_details cust_id=$cust_id cpm=$cpm_id}

	global DB
	variable CUST_RULE_DETAILS

	#
	# Get the necessary details
	#
	switch -- $mthd {
		CC   {
			ob::log::write INFO {==>get_cpm_details : CC }

			if {[catch {
				set rs [tb_db::tb_exec_qry get_CC_details $cpm_id]
			} msg]} {
				ob::log::write ERROR {Could not get_CC_details $cpm_id : $msg}
				return
			}
			set CUST_RULE_DETAILS(cc_scheme) [db_get_col $rs 0 scheme]
			set CUST_RULE_DETAILS(cc_cntry)  [db_get_col $rs 0 country]
			db_close $rs

			ob::log::write INFO {==>get_cpm_details : CC : $CUST_RULE_DETAILS(cc_scheme) $CUST_RULE_DETAILS(cc_cntry)}
			 }

		EP   {

			 }
	}
	ob::log::write INFO {<==get_cpm_details}
}


##
# CPMRules::upd_cpm_txn_status Updates the status of a CPM for a customer
#
# SYNOPSIS
#
#       [CPMRules::get_cpm_details <cpm_id> <txn_type> <status_dep status_wtd <auth_dep> <auth_wtd>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       [cpm_id]      - the cpm being updated (like tCustPayMthd.cpm_id)
#       [txn_type]    - is this a DEP or WTD
#       [status_dep]  - current deposit status of the CPM
#       [status_wtd]  - current withdrawal status of the CPM
#       [auth_dep]    - current deposit authorisation of the CPM
#       [auth_wtd]    - current withdrawal authorisation of the CPM
#       [dep_rsn]     - reason for disallowing deposits
#       [wtd_rsn]     - reason for disallowing withdrawals
#
# RETURN
#
#       Whether the update was successful or not. (0/1)
#
# DESCRIPTION
#
#       This procedure removes deposit or withdrawal ability for
#       a pay method belonging to a customer. IF it is going to
#       be the case that the CPM with not have any transction ability
#       then the CPM will be marked as deleted.
#
##
proc upd_cpm_txn_status {cpm_id txn_type status_dep status_wtd auth_dep auth_wtd dep_rsn wtd_rsn} {
	ob::log::write INFO {==>upd_cpm_txn_status cpm_id=$cpm_id txn_type=$txn_type \
							                   status_dep=$status_dep status_wtd=$status_wtd\
							                       dep_rsn=$dep_rsn wtd_rsn=$wtd_rsn}

	global DB

	set success    0
	set ltxn_type  [string tolower $txn_type]

	#
	# We are currently removing 'txn_type' ability from
	# this payment method. If its opposite is already
	# suspended then there is no more use for this CPM
	# so we'll delete it.
	#
	set status_${ltxn_type}  "S"
	set auth_${ltxn_type}    "N"
	set status               "A"
	set opposite_txn_type   [expr {$txn_type=="DEP"?"wtd":"dep"}]
	ob::log::write INFO {==>upd_cpm_txn_status opposite_txn_type=$opposite_txn_type}

	upvar status_$opposite_txn_type myvar

	if {$myvar == "S"} {
		set status "X"
		set status_${opposite_txn_type}  "S"
		set auth_${opposite_txn_type}    "N"
	}



	#
	# Remove deposit / withdrawal func from customers CPM
	# and delete it if no longer of use.
	#
	ob::log::write INFO {==>upd_cpm_txn_status : Updating to status=$status status_dep=$status_dep\
							                                 status_wtd=$status_wtd auth_dep=$auth_dep\
							                                 auth_wtd=$auth_wtd\
							                                     dep_rsn=$dep_rsn wtd_rsn=$wtd_rsn}

	if {[catch {
		set rs [tb_db::tb_exec_qry upd_cpm_status $status_dep $status_wtd $auth_dep $auth_wtd $status $dep_rsn $wtd_rsn $cpm_id]
		#db_close $rs
		} msg]} {
		ob::log::write WARNING {Could not update CPM $cpm_id : $msg}
	} else {
		set success 1
		ob::log::write INFO {Updated status of CPM : status=$status status_dep=$status_dep status_wtd=$status_wtd}
	}


	#
	# Clean Up and Return
	#
	return $success
}


##
# CPMRules::convert_ids_to_mthds
#
# SYNOPSIS
#
#       [CPMRules::convert_ids_to_mthds <id_list>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       <mthd_list> - a list of distinct CPM allow ids (like tPayMthdAllow.cpm_allow_id)
#
# RETURN
#
#      {{<pay_mthd>,<type>}.....}
#      ( A list of pay_mthd,type lists )
#
# DESCRIPTION
#
#      Takes as a parameter a list if CPM allow IDs (like tPayMthdAllow.cpm_allow_id).
#      For each id it returns a <pay_mthd>,<type> tuple in its place.
#
##
proc convert_ids_to_mthds {mthd_list} {
	ob::log::write DEBUG {==>convert_ids_to_mthds mthd_list=$mthd_list}

	global DB


	#
	# Get all CPM allow details. (Esentially maps a cpm_allow_id to
	# pay_mthd,tpe pairs.
	#
	set rs [tb_db::tb_exec_qry get_all_id_details]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set mthd   [db_get_col $rs $i pay_mthd]
		set type   [db_get_col $rs $i cpm_type]
		set id     [db_get_col $rs $i cpm_allow_id]

		set current [list $mthd $type]

		# if the id is in the list then replace it with
		# the current tuple
		set pos [lsearch -exact $mthd_list $id]
		if {$pos != -1} {
			set mthd_list [lreplace $mthd_list $pos $pos $current]
		}

	}


	#
	# Clean Up and Return
	#
	db_close $rs

	ob::log::write DEBUG {<==convert_ids_to_mthds RETURNING : $mthd_list}
	return $mthd_list
}



##
# CPMRules::convert_mthds_to_descs
#
# SYNOPSIS
#
#       [CPMRules::convert_mthds_to_descs <mthd_list>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       <mthd_list> - a list of {mthd cpm_type} lists
#
# RETURN
#
#      {{<pay_mthd description>}.....}
#      (list of tpaymthdallow.desc's)
#
# DESCRIPTION
#
#      Takes as a parameter a list of mthd/type pairs (tpaymthdallow.pay_mthd tpaymthdallow.cpm_type).
#      For each id it returns a description in its place (tpaymthdallow.desc).
#
##
proc convert_mthds_to_descs {mthd_list} {
	ob::log::write DEBUG {==>convert_mthds_to_descs mthd_list=$mthd_list}

	global DB
	set desc_list ""

	#
	# Get all CPM allow details. (Esentially maps a cpm_allow_id to
	# pay_mthd,tpe pairs.
	#
	set rs [tb_db::tb_exec_qry get_all_id_details]

	foreach cpm_pair $mthd_list {
		set curr_mthd [lindex $cpm_pair 0]
		set curr_type [lindex $cpm_pair 1]

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set mthd   [db_get_col $rs $i pay_mthd]
			set type   [db_get_col $rs $i cpm_type]
			set id     [db_get_col $rs $i cpm_allow_id]
			set desc   [db_get_col $rs $i desc]

			if {$mthd == $curr_mthd && $type == $curr_type} {
				lappend desc_list $desc
			}

		}
	}

	#
	# Clean Up and Return
	#
	db_close $rs

	ob::log::write DEBUG {<==convert_mthds_to_descs RETURNING : $desc_list}
	return $desc_list
}

##
# CPMRules::set_cpm_type
#
# SYNOPSIS
#
#       [CPMRules::set_cpm_type <cpm_type> <cpm_id>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       <cpm_id>   - cpm_id for the payment method you want to set the type for
#       <cpm_type> - the type you would like to set this CPM to
#
# RETURN
#
#       {1} - for success
#       {0} - otherwise
#
# DESCRIPTION
#
#       Sets tCustPayMthd.type for a payment method identified by <cpm_id>
#
##
proc set_cpm_type {cpm_id cpm_type} {
	ob::log::write DEBUG {==>set_cpm_type cpm_id=$cpm_id cpm_type=$cpm_type}

	global DB

	set success 0

	#
	# Execute the query
	#
	if {[catch {
		set rs [tb_db::tb_exec_qry set_cpm_type $cpm_type $cpm_id]
		#db_close $rs
		} msg]} {
		ob::log::write WARNING {Could not update type to $cpm_type for CPM $cpm_id : $msg}
	} else {
		set success 1
		ob::log::write INFO {Updated cpm_type of CPM $cpm_id to $cpm_type}
	}

	ob::log::write DEBUG {<==set_cpm_type RETURNING $success}
	return [list $success]

}

##
# CPMRules::get_rule_vars
#
# SYNOPSIS
#
#       [CPMRules::get_rule_vars]
#
# SCOPE
#
#       public
#
# PARAMS
#
#
#
# RETURN
#
#
#
# DESCRIPTION
#
#      Returns all varaiables with English descriptions used
#      in rules.
#
##
proc get_rule_vars {} {
	ob::log::write DEBUG {==>get_rule_vars}

	variable VAR_MAP

	return $VAR_MAP

	ob::log::write DEBUG {<==get_rule_vars}
}


##
# CPMRules::get_var_desc
#
# SYNOPSIS
#
#       [CPMRules::get_var_desc <var>]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       <var> - the variable you would like a description for
#
# RETURN
#
#
#
# DESCRIPTION
#
#      Returns an English description for a variable used in
#      the rules.
#
##
proc get_var_desc {var} {
	ob::log::write DEBUG {==>get_var_desc}

	variable VAR_MAP

	foreach v $VAR_MAP {
		if {[lindex $v 0] == $var} {
			return [lindex $v 1]
		}
	}

	ob::log::write DEBUG {<==get_var_desc}
	return $var
}

##
# CPMRules::get_customer_details
#
# SYNOPSIS
#
#       [CPMRules::get_customer_details <cust_id>]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       <cust_id> - customer's customer id
#       <override_ccy> - to override the customer's currency
#       <override_cntry> - to override the customer's country
#
# RETURN
#
#
#
# DESCRIPTION
#
#      Retrieves basic customer details to be used in rule evaluations.
#
##
proc get_customer_details {cust_id {override_ccy ""} {override_cntry ""}} {
	ob::log::write DEBUG {==>get_customer_details}

	variable CUST_RULE_DETAILS

	#
	# Execute the query
	#
	if {[catch {
		set rs [tb_db::tb_exec_qry get_customer_details $cust_id]
		} msg]} {
		ob::log::write WARNING {Could not get details for cust_id $cust_id : $msg}
		return
	}
	#
	# Set the necessary details & overrides
	#
	set CUST_RULE_DETAILS(ccy)                  [db_get_col $rs 0 ccy_code]
	set CUST_RULE_DETAILS(cust_cntry)           [db_get_col $rs 0 country_code]


	# is there a ccy override ?
	if {$override_ccy != ""} {
		set CUST_RULE_DETAILS(ccy) $override_ccy
	}

	# is there an override country
	if {$override_cntry != ""} {
		set CUST_RULE_DETAILS(cust_cntry) override_cntry
	}

	ob::log::write DEBUG {get_customer_details> ccy=$CUST_RULE_DETAILS(ccy) cust_cntry=$CUST_RULE_DETAILS(cust_cntry)}


	ob::log::write DEBUG {<==get_customer_details}
}






# initialise this namespace
init

# close namespace
}
