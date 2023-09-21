# $Id: hist.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Account History manager.
#
# Configuration:
#    HIST_TXN_PER_PAGE         default transactions per page        (20)
#    HIST_FMT_CCY_PROC         format ccy amount procedure          ("")
#    HIST_XL_PROC              translate history text procedure     ("")
#    HIST_COMBINE_SB_AND_POOLS whether to show pools txns in the    (0)
#                              main bet query
#
# Synopsis:
#    package require hist_hist ?4.5?
#
# Procedures:
#    ob_hist::init            one-time initialisation
#    ob_hist::get_op_type     get op_type details
#    ob_hist::add_param       add a history parameter
#    ob_hist::get_param       get a history parameter
#    ob_hist::clear_params    clear all the history parameters
#    ob_hist::get_timestamp   get timestamp
#    ob_hist::get_hist        get history
#    ob_hist::add_hist        add history
#    ob_hist::add_hist_value  add a history value
#    ob_hist::add_err         add an error status code
#    ob_hist::handler         history handler
#    ob_hist::XL              xl wrapper
#

package provide hist_hist 4.5



# Dependencies
#
package require util_log      4.5
package require util_db       4.5
package require util_date     4.5
package require util_validate 4.5
package require util_xl       4.5
package require cust_login    4.5



# Variables
#
namespace eval ob_hist {

	variable CFG
	variable HIST
	variable INIT
	variable PARAM
	variable OP_TYPE
	variable REQ_NO
	variable CALLBACK

	# default history handler callbacks
	#     txn_type  initialisation-statement history-handler j_op_types
	#
	# NB: j_op_types is a list of journal types which are associated with a
	#     txn_type. The package will automatically give each j_op_type an
	#     entry within the array which shares the same handler as the associated
	#     txn_type
	array set CALLBACK [list\
	    TX     {{package require hist_TX     4.5} ob_hist::_TX     {}}\
	    PMT    {{package require hist_PMT    4.5} ob_hist::_PMT    {DEP WTD RWTD}}\
	    XGAME  {{package require hist_XGAME  4.5} ob_hist::_XGAME  {XGAM}}\
	    BET    {{package require hist_BET    4.5} ob_hist::_BET    {ESB}}\
	    POOLS  {{package require hist_PBET   4.5} ob_hist::_PBET   {TPB}}\
	    GAM    {{package require hist_GAM    4.5} ob_hist::_GAM    {}}\
	    BS     {{}                                ob_hist::_BS     {BSTK BSTL BREF BCAN BUST BWIN BRFD BURF BUWN}}\
	    BALLS  {{package require hist_BALLS  4.5} ob_hist::_BALLS  {LB-- LB++ IB-- IB++}}\
	    NBALLS {{package require hist_NBALLS 4.5} ob_hist::_NBALLS {NBST NBWN}}\
	    SNG    {{package require hist_SNG    4.5} ob_hist::_SNG    {UGAM UGSK UGRT}}\
	    IGF    {{package require hist_IGF    4.5} ob_hist::_IGF    {CGSK CGWN CGPS CGPW}}]

	# package initialisation
	set INIT 0

}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Prepares the package queries and initialises the history handler callbacks.
#
#    user_callback - array of user supplied callback which may override
#                    or add to the available callback.
#
proc ob_hist::init { {user_callback ""} } {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_xl::init
	ob_login::init

	ob_log::write DEBUG {HIST: init}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "HIST: reqGetId not available for auto reset"
	}

	# get configuration
	array set OPT [list \
	    txn_per_page  20\
	    fmt_ccy_proc  ""\
	    xl_proc       ""\
	    combine_sb_and_pools 0\
		check_login 0]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "HIST_[string toupper $c]" $OPT($c)]
	}

	# cant have more than 20 transactions per-page
	if {$CFG(txn_per_page) > 20} {
		set CFG(txn_per_page) 20
	}

	# prepare package queries
	_prepare_qrys

	# init callbacks
	_init_callbacks $user_callback

	# initialised
	set INIT 1
}



# Private procedure to prepare the package queries
#
proc ob_hist::_prepare_qrys args {

	# get all the op_types (cached)
	ob_db::store_qry hist_hist::get_op_types {
		select
			j_op_type,
			j_op_name
		from
			tJrnlOp
	} 600

	# get the antepost balance for the given account at the given time
	ob_db::store_qry ob_hist::get_ap_balance {
		select first 1
			ap_balance,
			cr_date,
			appmt_id
		from
			tAPPmt
		where
			acct_id = ? and
			cr_date < ?
		order by cr_date desc, appmt_id desc
	}

	# get the antepost amount associated with a given bet placement/settlement
	# (basically the same amount as the bet stake - or the negative of it)
	ob_db::store_qry ob_hist::get_ap_bet_place_amount {
		select
			ap_amount
		from
			tAPPmt
		where
			bet_id = ?  and
			ap_op_type = 'APLC'
	}

	# get the antepost amount associated with a given bet placement/settlement
	# (basically the same amount as the bet stake - or the negative of it)
	ob_db::store_qry ob_hist::get_ap_bet_settle_amount {
		select
			ap_amount
		from
			tAPPmt
		where
			appmt_id = ?
	}
}



# Initialise history handler callbacks.
# Executes each of the defined j_op_type callback initialisation statements.
# If any statement, fails, the type is removed from the callback array
# and all requests for this type will be processed by the _default_ handler.
#
#    user_callback - array of user supplied callback which may override
#                    or add to the available callbacks.
#
proc ob_hist::_init_callbacks { {user_callback ""} } {

	variable CALLBACK

	ob_log::write DEBUG {HIST: init callbacks}

	# add user supplied history handler callbacks to CALLBACK array
	foreach {n v} $user_callback {
		set CALLBACK($n) $v
	}

	# initialise history handler callbacks
	foreach type [array names CALLBACK] {

		set init [lindex $CALLBACK($type) 0]
		ob_log::write DEV {HIST: $type initialisation - $init}

		if {$init != "" &&  [catch {eval [subst $init]} msg]} {
			ob_log::write ERROR {HIST: $type init - $msg}
			unset CALLBACK($type)
		}
	}

	# expand j_op_types
	# - each j_op_type associated with a txn_type is given a CALLBACK entry
	#   which share the same handler as the txn_type
	foreach type [array names CALLBACK] {

		set list [lindex $CALLBACK($type) 2]
		set len  [llength $list]
		for {set i 0} {$i < $len} {incr i} {
			set j_op_type [lindex $list $i]
			set CALLBACK($j_op_type) "{} [lindex $CALLBACK($type) 1] {}"
		}
	}
	
	ob_log::write_array DEV ob_hist::CALLBACK
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the cache should be
# reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in the scope of the request
#
proc ob_hist::_auto_reset args {

	variable HIST
	variable PARAM
	variable REQ_NO
	variable OP_TYPE

	# get current request identifier
	set id [reqGetId]

	if {![info exists REQ_NO] || $REQ_NO != $id} {
		_clear_hist
		catch {unset PARAM}
		catch {unset OP_TYPE}
		set REQ_NO $id

		ob_log::write DEV {HIST: auto reset cache, req_no=$id}
		return 1
	}

	return 0
}



# Private procedure to clear the history cache.
#
proc ob_hist::_clear_hist args {

	variable HIST

	catch {unset HIST}
	set HIST(total) 0
	add_err OB_OK

}



#--------------------------------------------------------------------------
# Get/Set Accessors
#--------------------------------------------------------------------------

# Get op_type name/description, or all the available op_types.
#
#   type    - op_type, or _all_ for a list of op_types (default: _all_)
#   returns - op_type name/description, or a list of all op_types
#
proc ob_hist::get_op_type { {type _all_} } {

	variable OP_TYPE

	# different request, reload op_types
	if {[_auto_reset] || ![info exists OP_TYPE(_all_)]} {

		set rs [ob_db::exec_qry hist_hist::get_op_types]
		set nrows [db_get_nrows $rs]
		for {set i 0} {$i < $nrows} {incr i} {
			set op_type                 [db_get_col $rs $i j_op_type]
			set OP_TYPE($op_type)  [db_get_col $rs $i j_op_name]
			lappend OP_TYPE(_all_) $op_type
		}
		ob_db::rs_close $rs
	}

	if {$type == "_all_"} {
		return $OP_TYPE(_all_)
	} else {
		return $OP_TYPE($type)
	}
}



# Add a history parameter to the package cache.
# The procedure allows any argument to be set, as each of the handlers will
# require different parameters which will be unknown to this package.
#
#   item  - param item name
#   value - param item's value
#
proc ob_hist::add_param { item value } {

	variable PARAM

	_auto_reset
	set PARAM($item) $value
}



# Get a history parameter from the package cache.
#
#    item    - param item name
#    def     - default value if not found within the cache (default: "")
#    returns - param item's value, or def if not found
#
proc ob_hist::get_param { item {def ""} } {

	variable PARAM

	if {[_auto_reset] || ![info exist PARAM($item)] || $PARAM($item) == ""} {
		return $def
	}

	return $PARAM($item)
}



# Clear the history parameter from the package cache.
#
proc ob_hist::clear_param args  {

	variable PARAM

	if {![_auto_reset]} {
		catch {unset PARAM}
	}
}



# Get a timestamp from the history parameters.
#
# The package uses Informix formatted dates (used as a query argument), however,
# for backwards compliance, also allows YYYYMMDD and integer-time (time from
# 'epoch'), both of which will be converted to an informix time.
#
# The various formats are taken from one of the following history parameters
# (set via ::add_param) - <start|end>_yyymmdd, <start|end>_seconds or
# <start|end>_ifmx.
#
# The <start|end>_ifmx parameter will be updated.
#
#    timestamp - which timestamp to get (start|end)
#    returns   - status string (OB_OK denotes success)
#
proc ob_hist::get_timestamp { timestamp } {

	variable PARAM

	# if detected a new request then bail-out, as no parameters have been set
	if {[_auto_reset] || ![info exists PARAM]} {
		return OB_ERR_HIST_RESET
	}

	if {![regexp {start|end} $timestamp]} {
		return OB_ERR_HIST_BAD_TIMESTAMP
	}

	# get HIST cache parameter elements
	foreach e {yyyymmdd seconds ifmx} {
		set $e [format "%s_%s" $timestamp $e]
	}

	# if an Informix date is supplied, validate
	if {[eval {set t [get_param $ifmx]}] != ""} {
		return [ob_chk::informix_date $t]
	}

	# if YYMMDD is supplied, convert to an Informix representation
	if {[eval {set t [get_param $yyyymmdd]}] != ""} {

		# validate
		if {[eval {set status [ob_chk::date $t YYYYMMDD]}] != "OB_OK"} {
			return $status
		}

		# convert to Informix (add time accordingly)
		if {$timestamp == "start"} {
			set seconds [clock scan "$t 00:00:00"]
		} else {
			set seconds [clock scan "$t 23:59:59"]
		}
		set PARAM($ifmx) [ob_date::get_ifmx_date $seconds]

		return OB_OK
	}

	# else validate & convert seconds to an Informix representation
	set t [get_param $seconds]
	if {[eval {set status [ob_chk::integer_time $t]}] != "OB_OK"} {
		return $status
	}
	set PARAM($ifmx) [ob_date::get_ifmx_date $t]

	return OB_OK
}



# Get history data.
#
#    returns - history data array (contents depend on last transaction-type)
#
proc ob_hist::get_hist args {

	variable HIST

	_auto_reset

	return [array get HIST]
}



# Add data from a result set to the history package cache.
# One row is added to cache, where all the column names are added to HIST(n,..)
# Also translate and/or format currency amounts for particular columns
# Original column is left un-changed, but a new column is created, xl_colname
# for translated columns, and fmt_colname for ccy formatted columns.
#
# To translate the columns, xl_proc parameter must be defined. To format
# ccy amounts, fmt_ccy_proc parameter must be defined.
#
#   rs        - result set
#   index     - result set index/row (0 indexed)
#   txn_type  - transaction type
#   colnames  - list of result-set colnames (default "")
#               if not-supplied, procedure to get from result-set
#   xl_list   - optional list of columns which are translated (default "")
#               each column must be within the result-set
#   ccy_list  - optional list of columns which are ccy formatted (default "")
#               each column must be within the result-set
#   returns   - status (OB_OK denotes success)
#               the status is always added to HIST(err,status)
#
proc ob_hist::add_hist {
	rs index txn_type {colnames ""} {xl_list ""} {ccy_list ""}
} {

	variable HIST
	variable PARAM

	# if data is empty, what to add in it's place, e.g. &nbsp;
	set empty_str [get_param empty_str]

	if {[catch {

		# get colnames?
		if {$colnames == ""} {
			set colnames [db_get_colnames $rs]
		}

		# set data from result-set
		foreach c $colnames {
			if {$c == "event_desc"} {
				set HIST($index,$c) [ob_xl::XL {en} [db_get_col $rs $index $c]]
			} else {
				set HIST($index,$c) [db_get_col $rs $index $c]
			}
			if {$c == "j_op_type"} {
				set HIST($index,j_op_type_name) [get_op_type $HIST($index,$c)]
			}
			# if empty, replace it?
			if {$HIST($index,$c) == ""} {
				set HIST($index,$c) $empty_str
			}
		}

		# translate text?
		# - ignore empty strings
		if {$PARAM(xl_proc) != "" && $xl_list != ""} {
			foreach c $xl_list {
				if {$HIST($index,$c) != $empty_str} {
					set HIST($index,xl_${c}) [_XL $HIST($index,$c)]
				} else {
					set HIST($index,xl_${c}) $empty_str
				}
			}
		}

		# format currency columns?
		# - ignore empty strings
		if {$PARAM(fmt_ccy_proc) != "" && $ccy_list != ""} {
			foreach c $ccy_list {
				if {$HIST($index,$c) != $empty_str} {
					set HIST($index,fmt_${c}) [_fmt_ccy_amount $HIST($index,$c)]
				} else {
					set HIST($index,fmt_${c}) $empty_str
				}
			}
		}

		set status [add_err OB_OK]

	} msg]} {
		ob_log::write ERROR {${txn_type}_HIST: $msg}
		set status [add_err OB_ERR_HIST_${txn_type}_FAILED $msg]
	}

	return $status
}



# Add a hist value to the history result set cache.
#
#   item  - history item/index
#   value - value to set
#
proc ob_hist::add_hist_value { item value } {

	variable HIST

	set HIST($item) $value
}



#--------------------------------------------------------------------------
# Error Handler
#--------------------------------------------------------------------------

# Add an error status code to the history cache.
#
#    status  - error status code
#    xl_args - additional error arguments (placeholders)
#    returns - status
#
proc ob_hist::add_err { status {xl_args ""} } {

	variable HIST

	set HIST(err,status) $status
	set HIST(err,args)   $xl_args

	return $status
}



#--------------------------------------------------------------------------
# Account History Handler
#--------------------------------------------------------------------------

# Account history handler.
#
# The history is extracted from the database via a series of callbacks, where
# each callback deals with a particular sub-set of transaction types. The
# callbacks allows the caller to override the existing set of procedures, e.g.
# incorporate customer specific handling, or to add new procedures which deal
# with transactions not-supported by the package.
#
# As there is a multitude of history search parameters, the package utilises
# a package variable PARAM, which must be set prior to calling the handler.
# The variable is reset on each request.
#
#   returns - status (OB_OK denotes success)
#             the status is always added to HIST(err,status)
#
proc ob_hist::handler args {

	variable CFG
	variable HIST
	variable PARAM
	variable CALLBACK

	# if detected a new request then bail-out, as no parameters have been set
	if {[_auto_reset]} {
		return [add_err OB_ERR_HIST_RESET]
	}
	
	set txn_type [get_param txn_type]
	if {$txn_type == "TPB"} {
		ob_hist::add_param j_op_ref_key "TPB"
	}
	ob_log::write DEBUG {HIST: handler txn_type=$txn_type}

	# reset history cache
	_clear_hist

	set acct_id [get_param acct_id]
	if {[ob_chk::integer $acct_id] != "OB_OK"} {
		return [add_err OB_ERR_HIST_BAD_ACCT_ID]
	}

	# get/set transactions-per-page
	set txn_per_page [get_param txn_per_page $CFG(txn_per_page)]
	if {[ob_chk::integer $txn_per_page] != "OB_OK"} {
		return [add_err OB_ERR_HIST_BAD_TXN_PER_PAGE]
	}
	if {$txn_per_page > 20} {
		ob_log::write WARNING {HIST: cannot exceed 20 txn_per_page}
		set txn_per_page 20
	}
	set PARAM(txn_per_page) $txn_per_page
	
	# must have a txn type
	if {$txn_type == "" || ![info exists CALLBACK($txn_type)]} {
		return [add_err OB_ERR_HIST_BAD_TXN_TYPE]
	}

	# using a procedure to format ccy amounts
	set PARAM(fmt_ccy_proc) [get_param fmt_ccy_proc $CFG(fmt_ccy_proc)]

	# if using the above procedure, must have a ccy_code
	if {$PARAM(fmt_ccy_proc) != "" && [get_param ccy_code] == ""} {
		return [add_err OB_ERR_HIST_BAD_CCY_CODE]
	}

	# using a procedure to translate history text
	set PARAM(xl_proc) [get_param xl_proc $CFG(xl_proc)]

	# if using the above procedure, must have a language code
	if {$PARAM(xl_proc) != "" && [get_param lang] == ""} {
		return [add_err OB_ERR_HIST_BAD_LANG]
	}

	#TODO: Temporary Hack?
	if {$CFG(check_login)} {
		# cannot be a guest (pre-cautionary check)
		if {[ob_login::is_guest]} {
			set status [ob_login::get login_status]
			if {$status == "OB_OK"} {
				set status OB_ERR_CUST_GUEST
			}
			return [add_err $status]
		}
	}

	# handle the transaction type
	if {[catch {
		eval [subst [lindex $CALLBACK($txn_type) 1]]
	} msg]} {
		ob_log::write ERROR {${txn_type}_HIST: $msg}
		add_err OB_ERR_HIST_${txn_type}_FAILED $msg
	}

	return $HIST(err,status)
}



#--------------------------------------------------------------------------
# Journal
#--------------------------------------------------------------------------

# Private procedure to get one of the following journal entries -
#    a) between two dates
#    b) between a journal identifier and a date
#
# The procedure must be supplied with two 'stored' queries which provide the
# necessary restrictions on which j_op_types to return and secondly, provide
# three placeholders -
#    1) start-date
#    2) end-date or jrnl_id
#    3) acct_id
#
# The supplied txn_type is only used for the construction of log messages and
# error codes.
#
# The entries are stored within the history package cache.
#
#     txn_type           - TXN type
#     qry_get            - query used to get jrnl entries between 2 dates
#     qry_get_w_jrnl_id  - query used to get jrnl entries between an id and date
#     returns            - status (OB_OK denotes success)
#                          the status is always added to HIST(err,status)
#
proc ob_hist::_journal_list { txn_type qry_get qry_get_w_jrnl_id } {

	variable HIST
	variable PARAM

	ob_log::write DEBUG {${txn_type}_HIST: ${txn_type} journal list}

	# must have an start timestamp
	set status [get_timestamp start]
	if {$status != "OB_OK"} {
		return [add_err $status]
	}
	set start $PARAM(start_ifmx)

	# last jrnl_id or end-time
	set last_jrnl_id [get_param last_jrnl_id]
	if {$last_jrnl_id == ""} {
		set status [get_timestamp end]
		if {$status != "OB_OK"} {
			return [add_err $status]
		}
		set qry $qry_get
		set end $PARAM(end_ifmx)
	} else {
		set qry $qry_get_w_jrnl_id
		set end $last_jrnl_id
	}

	ob_log::write_array DEV ob_hist::PARAM

	lappend qry_cmd ob_db::exec_qry $qry $start $end

	lappend qry_cmd $PARAM(acct_id)

	if {[info exists PARAM(sng_game_subclass)]} {
		lappend qry_cmd $PARAM(sng_game_subclass)
	}

	# execute the query
	if {[catch {set rs [eval $qry_cmd]} msg]} {
		ob_log::write ERROR {${txn_type}_HIST: $msg}
		return [add_err OB_ERR_HIST_${txn_type}_FAILED $msg]
	}

	# store data
	set nrows    [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]
	for {set i 0} {$i < $nrows && $i <= $PARAM(txn_per_page)} {incr i} {
		# add history details
		set status [add_hist \
			$rs \
			$i \
			$txn_type \
			$colnames\
		    {j_op_type j_op_type_name desc} \
		    {amount balance}]

		if {$status == "OB_OK"} {
			set HIST(last_jrnl_id) $HIST($i,jrnl_id)
		}
	}
	ob_db::rs_close $rs

	if {$status == "OB_OK"} {
		set HIST(total) $i
	}

	ob_log::write DEV {HIST(total) is $HIST(total)}

	#
	# Correct the running balance for Antepost stakes
	#
	if {[get_param do_ap_adjustment 0] && $HIST(total)>0} {
		set err [catch {
			set earliest_entry [expr {$HIST(total) - 1}]
			set running_ap_balance [_AP_find_running_ap_balance $earliest_entry]
			ob_log::write DEV {init running_ap_balance = $running_ap_balance}
		
			for {set i $earliest_entry} {$i >= 0} {incr i -1} {
				set ap_amount [_AP_affect_to_ap_balance $i]
				set HIST($i,ap_amount) $ap_amount
				_AP_fix_amount $i $ap_amount
				set running_ap_balance [expr {$running_ap_balance + $ap_amount}]
				ob_log::write DEV {running_ap_balance is $running_ap_balance}
				_AP_fix_running_balance $i $running_ap_balance
			}
		} msg]
	
		if {$err} {
			ob_log::write ERROR {BET_HIST: $msg}
			set status [add_err OB_ERR_HIST_BET_FAILED $msg]
		}
	}

	return $status
}



#--------------------------------------------------------------------------
# Procs to deal with correcting the running balance due to Antepost Bets
#--------------------------------------------------------------------------

# Find what the customer's ap balance would have been at the time of
# the given entry in the HIST array.  (Or rather the time just before the
# given entry).
#
# Calling procedure must handle any errors thrown from here.
#
proc ob_hist::_AP_find_running_ap_balance {idx} {
	variable PARAM
	variable HIST

	set acct_id $PARAM(acct_id)
	set date    $HIST($idx,cr_date)

	set rs [ob_db::exec_qry ob_hist::get_ap_balance $acct_id $date]

	if {[db_get_nrows $rs] < 1} {
		set ap_balance 0.00
	} else {
		set ap_balance [db_get_col $rs 0 ap_balance]
	}

	ob_db::rs_close $rs

	return $ap_balance
}



# Find out whether the given entry in the HIST array would affect the
# customer's ap_balance.
#
# Return by how much the ap_balance would be affected.
#
# Calling procedure must handle any errors thrown from here.
#
proc ob_hist::_AP_affect_to_ap_balance {idx} {
	variable HIST

	if {$HIST($idx,j_op_type) != "BSTK"} {
		return 0.0
	}

	if {$HIST($idx,j_op_ref_key) == "ESB"} {
		set bet_id $HIST($idx,j_op_ref_id)
		set rs [ob_db::exec_qry ob_hist::get_ap_bet_place_amount $bet_id]
	} elseif {$HIST($idx,j_op_ref_key) == "APAY"} {
		set appmt_id $HIST($idx,j_op_ref_id)
		set rs [ob_db::exec_qry ob_hist::get_ap_bet_settle_amount $appmt_id]
	} else {
		ob_log::write DEBUG {ob_hist::_AP_affect_to_ap_balance - ignoring\
		                               j_op_ref_key of $HIST($idx,j_op_ref_key)}
		return 0.0
	}

	if {[db_get_nrows $rs] == 0} {
		ob_db::rs_close $rs
		return 0.0
	}

	set ap_amount [db_get_col $rs 0 ap_amount]

	ob_db::rs_close $rs

	return $ap_amount
}



# Fix the amount for the given entry in the HIST array.
#
# We only need to do this if the following conditions are all true:
#  - given amount is non-zero
#  - HIST entry is for an AP bet stake at settlement time (i.e. BSTK/APAY)
#
proc ob_hist::_AP_fix_amount {idx amount} {
	variable HIST

	if {$amount == 0} {return}
	if {$HIST($idx,j_op_type) != "BSTK"} {return}
	if {$HIST($idx,j_op_ref_key) != "APAY"} {return}

	set HIST($idx,amount)  $amount
	set HIST($idx,fmt_amount) [_fmt_ccy_amount $amount]
}



# Fix the running balance for the given entry in the HIST array, by
# adding the given ap_balance amount to it.
#
proc ob_hist::_AP_fix_running_balance {idx ap_balance} {
	variable HIST

	set HIST($idx,balance) [expr {$HIST($idx,balance) + $ap_balance}]
	set HIST($idx,fmt_balance) [_fmt_ccy_amount $HIST($idx,balance)]
}



#--------------------------------------------------------------------------
# Bet Stake/Settle Handler (proxy)
#--------------------------------------------------------------------------

# Private procedure to handle Bet Stake/Settle journal entries (BSTK & BSTL).
# These j_op_types are shared between ESB and XGAME j_op_ref_keys, therefore,
# get the j_op_ref_key parameter and execute the appropriate handler.
#
#     returns - status (OB_OK denotes success)
#               the status is always added to HIST(err,status)
#
proc ob_hist::_BS args {

	variable HIST
	variable CALLBACK

	# get the j_op_ref_key
	set j_op_ref_key [get_param j_op_ref_key]
	set receipt      [get_param receipt]

	if {$receipt == ""} {
		if {$j_op_ref_key == "" || ![info exists CALLBACK($j_op_ref_key)]} {
			return [add_err OB_ERR_HIST_BAD_J_OP_REF_KEY]
		}
	} else {
		set j_op_ref_key "ESB"
	}
	ob_log::write DEBUG {BS_HIST: j_op_ref_key=$j_op_ref_key}

	# handle the transaction type
	if {[catch {
		eval [subst [lindex $CALLBACK($j_op_ref_key) 1]]
	} msg]} {
		ob_log::write ERROR {${j_op_ref_key}_HIST: $msg}
		add_err OB_ERR_HIST_${j_op_ref_key}_FAILED $msg
	}

	return $HIST(err,status)
}


#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Translate history text.
#
#    lang    - language code
#    text    - text to translate (maybe a phrase or a code)
#    returns - translated text
#
proc ob_hist::XL { lang text } {

	set exp {([^\|]*)\|([^\|]*)\|(.*)}
	if {[regexp $exp $text]} {
		return [ob_xl::XL $lang $text]
	} else {
		return [ob_xl::sprintf $lang $text]
	}
}



# Private procedure to translate history text.
# The procedure calls the user-supplied 'xl_proc'.
#
#    text - text to translate (maybe a phrase or a code)
#    returns - formatted journal description
#
proc ob_hist::_XL { text } {

	variable PARAM

	return [eval [subst "$PARAM(xl_proc) $PARAM(lang) {$text}"]]
}



# Private procedure to pre-fix a ccy-symbol to an amount.
# The procedure calls the user-supplied 'fmt_ccy_proc'.
#
#    amount  - amount to format
#    returns - formatted amount
#
proc ob_hist::_fmt_ccy_amount { amount } {

	variable PARAM

	set exec "$PARAM(fmt_ccy_proc) $amount $PARAM(ccy_code)"
	return [eval [subst $exec]]
}
