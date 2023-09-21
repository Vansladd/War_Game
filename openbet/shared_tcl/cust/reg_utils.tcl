# $Id: reg_utils.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2007 Orbis Technology Ltd.All rights reserved.
#
# This package covers all parts of registration that is not carried out in
# ob_reg i.e. customer statements

package provide reg_utils 0.1

# Dependencies

# Variables
namespace eval reg_utils {

	variable CFG
	variable INIT

	variable REG
	variable DATA
	variable DATA_NAME

	# Current request number
	set REG(req_no) ""

	# Set the available names for the DATA_NAME array. Set the data type for them as well
	# - list indicates - type default
	# - where type     - I integer, T text, Llogin, IP ip-addr, D date,
	#                    DOB dob, E email, M money
	array set DATA_NAME \
		[list \
			cust_id         [list I   ""]\
			acct_id         [list I   ""]\
			source          [list T   I]\
			username        [list L   ""]\
			acct_no         [list L   ""]\
			lang            [list T   ""]\
			ccy_code        [list T   ""]\
			country_code    [list T   ""]\
			acct_type       [list T   "DEP"]\
			reg_status      [list T   "A"]\
			ipaddr          [list IP  ""]\
			title           [list T   ""]\
			fname           [list T   ""]\
			lname           [list T   ""]\
			dob             [list DOB ""]\
			stmt_status     [list T   A]\
			stmt_on         [list I   0]\
			stmt_freq       [list I   1]\
			stmt_period     [list T   "W"]\
			stmt_dlv_method [list T   "post"]\
			stmt_brief      [list T   N]\
			stmt_due_from   [list D   ""]\
			stmt_due_to     [list D   ""]\
			promo_code      [list T   ""]\
			aff_id          [list I   ""]\
		]

	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
proc reg_utils::init args {

	variable CFG
	variable INIT

	set fn "reg_utils"

	ob_log::write INFO {$fn init started}

	# Already initialised?
	if {$INIT} {
		return
	}

	# Prepare SQL queries
	_prepare_qrys

	# Init
	set INIT 1
	ob_log::write INFO {$fn init finished}
}



# -----------------------------------------------------------------------------
#  Public Procedures
# -----------------------------------------------------------------------------

# Set/Add registration data.
# A tcl error will be generated if an unknown data name.
#
# NB: The procedure does not get the registration parameters from a
# HTML/WML form. It is caller's responsibility to get and supply the
# details.
#
#   name  - Must match a name in the DATA_NAME array
#   value - value
#
proc reg_utils::add { name value } {

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



# Register a customers statements
#
#   in_tran - in transaction flag (default: 0)
#             if non-zero, the caller must begin, rollback & commit
#             if zero, then must be called outside a transaction
#   returns - A list with the first element indicating success and the second element providing a
#             list of errors if required
#
proc reg_utils::reg_stmt_insert {{in_tran 0}} {

	variable DATA

	set fn "reg_utils::reg_stmt"
	set error_list [list]

	# If a deposit customer then error as they don't have statements. Really shouldn't be allowed to
	# get this far
	if {$DATA(acct_type) == "DEP"} {
		lappend error_list "TB_REG_ERR_INAVLID_ACCT_TYPE_STMT"
		ob_log::write WARNING {$fn: Invalid account type used}
		return [list 0 $error_list]
	}

	# If a CDT customer and there is no stmt details then error as CDT customers must have statements
	if {$DATA(acct_type) == "CDT" && !$DATA(stmt_on)} {
		lappend error_list "TB_REG_ERR_CDT_REQ_STMT"
		ob_log::write WARNING {$fn: Invalid account type used}
		return [list 0 $error_list]
	}

	# Force the statement from the current time (registration this is ok)
	set DATA(stmt_due_from) [clock format [tb_statement::tb_stmt_get_time] -format "%Y-%m-%d %H:%M:%S"]

	# Start the transaction if not in one
	if {!$in_tran} {
		ob_db::begin_tran
	}

	if {[catch {
		tb_statement::tb_stmt_add $DATA(acct_id) \
			$DATA(stmt_period) \
			$DATA(stmt_freq) \
			$DATA(stmt_due_from) \
			$DATA(stmt_due_to) \
			$DATA(stmt_dlv_method) \
			$DATA(stmt_brief) \
			1 \
			$DATA(acct_type)
	} msg]} {

		lappend error_list "TB_REG_ERR_FAILED_REG_STMT"
		ob_log::write WARNING {$fn: Failed to add stmt for customer - $msg}
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		return [list 0 $error_list]
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}
	return [list 1]
}

# Update a customers statements
#
#   in_tran - in transaction flag (default: 0)
#             if non-zero, the caller must begin, rollback & commit
#             if zero, then must be called outside a transaction
#   returns - A list with the first element indicating success and the second element providing a
#             list of errors if required
#
proc reg_utils::reg_stmt_update {{in_tran 0}} {

	variable DATA

	set fn "reg_utils::reg_stmt"
	set error_list [list]

	# If a deposit customer then error as they don't have statements. Really shouldn't be allowed to
	# get this far
	if {$DATA(acct_type) == "DEP"} {
		lappend error_list "TB_REG_ERR_INAVLID_ACCT_TYPE_STMT"
		ob_log::write WARNING {$fn: Invalid account type used}
		return [list 0 $error_list]
	}

	# If a CDT customer and there is no stmt details then error as CDT customers must have statements
	if {$DATA(acct_type) == "CDT" && !$DATA(stmt_on)} {
		lappend error_list "TB_REG_ERR_CDT_REQ_STMT"
		ob_log::write WARNING {$fn: Invalid account type used}
		return [list 0 $error_list]
	}

	# Update the stmt
	if {[catch {
		tb_statement::tb_stmt_upd \
			$DATA(acct_id) \
			$DATA(stmt_period) \
			$DATA(stmt_freq) \
			$DATA(stmt_due_from) \
			$DATA(stmt_due_to) \
			$DATA(stmt_status) \
			$DATA(stmt_dlv_method) \
			$DATA(stmt_brief) \
			1 \
			$DATA(acct_type)
	} msg]} {

		lappend error_list "TB_REG_ERR_FAILED_REG_STMT"
		ob_log::write WARNING {$fn: Failed to update stmt for customer - $msg}
		if {!$in_tran} {
			ob_db::rollback_tran
		}
		return [list 0 $error_list]
	}

	if {!$in_tran} {
		ob_db::commit_tran
	}
	return [list 1]
}

# Check that the customer earns a registration freebet
#
proc reg_utils::check_reg_offer {} {

	global FBDATA

	variable DATA

	# Use the faster freebets method
	if {[OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0]} {

		catch {unset FBDATA}
		set check_action_fn "::ob_fbets::go_check_action_fast"
		set FBDATA(lang)           $DATA(lang)
		set FBDATA(ccy_code)       $DATA(ccy_code)
		set FBDATA(country_code)   $DATA(country_code)
	} else {
		set check_action_fn "OB_freebets::check_action"
	}

	# freebets registration call
	$check_action_fn  REG $DATA(cust_id) $DATA(aff_id)
}


# Check and redeem a promo code
#
#   in_tran - in transaction flag (default: 0)
#             if non-zero, the caller must begin, rollback & commit
#             if zero, then must be called outside a transaction
#   returns - A list with the first element indicating success and the second
#             element providing a list of errors if required
#
proc reg_utils::check_promo_code {{in_tran 0}} {

	global FBDATA

	variable DATA

	set fn {reg_utils::check_promo_code}

	set promo_code [string toupper $DATA(promo_code)]

	# Use the faster freebets method
	if {[OT_CfgGet USE_FREEBET_CHECK_ACTION_FAST 0]} {

		catch {unset FBDATA}
		set redeem_promo_fn "::ob_fbets::redeem_promo_fast"
		set FBDATA(lang)           $DATA(lang)
		set FBDATA(ccy_code)       $DATA(ccy_code)
		set FBDATA(country_code)   $DATA(country_code)

	} else {
		set redeem_promo_fn "OB_freebets::redeem_promo"
	}

	set success [$redeem_promo_fn $DATA(cust_id) $promo_code]

	if {$success} {
		ob_log::write INFO {Storing promo code ($promo_code) as flag REG_PROMO_CODE}
		set nrows [ob_cflag::insert "REG_PROMO_CODE" $promo_code $DATA(cust_id) 1]
		if {$nrows != 1} {
			ob_log::write ERROR {$fn: Failed to store promo code as flag ($nrows)}
			return [list 0 "TB_REG_ERR_PROMO_FLAG"]
		}
	} else {
		ob_log::write ERROR {$fn: Failed to redeem promo code $promo_code}
		return [list 0 "TB_REG_ERR_PROMO_REDEEM"]
	}

	return [list 1]
}



# Generate an account number
#
#   returns - A list with the first element indicating success and the second
#             element providing a list of errors if required or the account
#             number
#
proc reg_utils::gen_acct_no {} {

	variable DATA

	if {[OT_CfgGet ACCT_NO_INITIALS_PREFIX 0]} {
		set f_initial [string index $DATA(regFName) 0]
		set l_initial [string index $DATA(regLName) 0]
		set prefix "$f_initial$l_initial"
	} else {
		set prefix [OT_CfgGet ACCT_NO_PREFIX ""]
	}

	# Generate the password
	if {[catch {
		set rs [ob_db::exec_qry reg_utils::generate_acct_no "STD" $prefix]
	} msg]} {
		ob_log::write ERROR {Failed to generate acct_no: $msg}
		return [list 0 "TB_REG_ACCT_FAILED_GEN_ACCT"]
	}

	set acct_no [db_get_coln $rs 0 0]
	db_close $rs

	set acct_no [string map [list " " ""] $acct_no]

	return [list 1 $acct_no]
}

# Add the temporary password flag to the customer.
# Requires the cust_id to have been loaded to the package cache before it is called
#
#   returns - A list with the first element indicating success and the second
#             element providing a list of errors if required
#
proc reg_utils::set_password_temp {} {

	variable DATA

	# Set the password to temp.
	if {[catch {
		set rs [ob_db::exec_qry reg_utils::insert_status_flag $DATA(cust_id) "PWORD" "Registered via TelebetV2" "N"]
	} msg]} {
		ob_log::write ERROR {Failed to set password to temporary: $msg}
		return [list 0 "TB_REG_ACCT_FAILED_TO_TEMP_PASS"]
	}

	db_close $rs

	return [list 1]
}

# -----------------------------------------------------------------------------
#  Private Procedures
# -----------------------------------------------------------------------------

# Should the package cache be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache was reset, zero if
#             cache is up to date in scope of the request
#
proc reg_utils::_auto_reset args {

	variable REG
	variable DATA
	variable error_list

	# Get the request id
	set id [reqGetId]

	# Different request numbers, must reload cache
	if {$REG(req_no) != $id} {
		catch {unset REG}
		catch {unset DATA}
		set REG(req_no) $id
		set error_list  [list]
		ob_log::write DEV {REG: auto reset cache, req_no=$id}

		return 1
	}

	# Already loaded
	return 0
}



# Prepare the queries for the package
proc reg_utils::_prepare_qrys args {

	ob_db::store_qry reg_utils::generate_acct_no {
		execute procedure pTbGenAcctNo (
			p_cust_type = ?,
			p_prefix    = ?
		)
	}

	ob_db::store_qry reg_utils::insert_status_flag {
		execute procedure pInsCustStatusFlag (
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_reason = ?,
			p_transactional = ?
		)
	}
}
