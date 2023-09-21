# =============================================================================
# $Id: business_period.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# =============================================================================
#
# -= BUSINESS PERIOD ADMIN MODULE =-
#
# This module contains the admin function to administrate business periods
#
# CONFIGURATION:
#
#   FUNC_BUSINESS_PERIOD      (admin_base.cfg)   : flag to activate this submodule
#   FUNC_MENU_BUSINESS_PERIOD (admin_base.cfg)   : flag to show / don't show this item
#                                             in the admin menu
#
# PERMISSIONS:
#
#   No permissions are checked to perform operations
#
#
# PROCEDURES:
#
#   go_business_period_setup     : displays the CRUD interface (listing and add bp modules)
#   do_business_period_setup     : executes CRUD actions (add,edit)
#
#   _bind_error             : (private proc) logs errors and binds error msgs 
#   _bind_info              : (private proc) binds informative text for user
#   _check_valid_bp         : (private proc) checks if the user submitted BP is valid
#   _to_informix            : (private proc) converts a dd/mm/yy data into informix format
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# =============================================================================

namespace eval ADMIN::BUSINESSPERIOD {

asSetAct ADMIN::BUSINESSPERIOD::GoBusinessPeriodSetup     [namespace code go_business_period_setup]
asSetAct ADMIN::BUSINESSPERIOD::DoBusinessPeriodSetup     [namespace code do_business_period_setup]



#
# ----------------------------------------------------------------------------
# Display CRUD interface for Business Periods
# ----------------------------------------------------------------------------
#
proc go_business_period_setup {} {

	set fn {ADMIN::BUSINESSPERIOD::go_business_period_setup >}

	ob_log::write DEBUG {$fn : start}

	global DB

	set select_sql {
				select
					bp_id,
					TO_CHAR (period_date_from, "%d/%m/%y") p_date_from,
					TO_CHAR (period_date_to, "%d/%m/%y") p_date_to,
					TO_CHAR (period_date_to, "%b") p_month,
					TO_CHAR (period_date_to,"%Y") p_year
				from 
					tBusinessPeriod
				order by
					period_date_to DESC
				}

	set stmt [inf_prep_sql $DB $select_sql]

	if [catch {set res  [inf_exec_stmt $stmt]} msg] { 
		_bind_error $fn {Selecting business periods in DB has failed} \
		                {Cannot retrieve business periods from database}
	} else {

		if { [db_get_nrows $res] < 1 } {
			_bind_error $fn {Selecting business periods in DB has returned 0 rows} \
			                {There are no business periods in database}
		} else {
			tpSetVar NumBP [db_get_nrows $res]

			tpBindTcl BpId              sb_res_data $res bp_idx bp_id
			tpBindTcl PeriodDateFrom    sb_res_data $res bp_idx p_date_from
			tpBindTcl PeriodDateTo      sb_res_data $res bp_idx p_date_to
			tpBindTcl Month             sb_res_data $res bp_idx p_month
			tpBindTcl Year              sb_res_data $res bp_idx p_year

		}
	}

	inf_close_stmt $stmt

	asPlayFile -nocache business_period_list.html

	catch {db_close $res}

	} ;# end proc



#
# ----------------------------------------------------------------------------
# Execute CRUD actions for Business Periods
#
#   "BPAdd"         Adds a new business period
#   "BPShowEdit"    Rebinds template vars and shows editing form
#   "BPDoEdit"      Edits an existing business period
# ----------------------------------------------------------------------------
#
proc do_business_period_setup args {

	set fn {ADMIN::BUSINESSPERIOD::do_business_period_setup >}

	ob_log::write DEBUG {$fn : start}

	global DB

	# get the action value
	set act [reqGetArg SubmitName]

	# choose what to do
	switch -exact $act {

		"BPAdd" {
			# Add a new Business Period
			ob_log::write DEBUG {$fn : Action $act. Commencing.}

			# expected arguments : 2
			set bp_date_from     [_to_informix [reqGetArg bp_date_from]]
			set bp_date_to       [_to_informix [reqGetArg bp_date_to]]

			set valid [_check_valid_bp $bp_date_from $bp_date_to]

			if { !$valid } {
			# proposed bp is invalid for some reason
				tpBindString InsertedDateFrom   $bp_date_from
				tpBindString InsertedDateTo     $bp_date_to

				go_business_period_setup
				return
			}

			set insert_sql {
				insert into tBusinessPeriod (
					period_date_from,
					period_date_to
				) values (
					?, ?
				)
			}

			set stmt_ins [inf_prep_sql $DB $insert_sql]

			if { [catch { set res [inf_exec_stmt $stmt_ins $bp_date_from $bp_date_to] } msg]} {
				_bind_error $fn $msg {Business period adding failed}
				set valid 0
			}

			if { $valid } {  _bind_info {Business period added}  }

			catch {db_close $res}
			inf_close_stmt $stmt_ins

			go_business_period_setup
			return

		} ;# END ADD action

		"BPShowEdit" {
			# Show Edit page
			ob_log::write DEBUG {$fn : Action $act. Commencing.}

			tpBindString PeriodID           [set editID [reqGetArg EditID]]
			tpBindString PeriodDateFrom     [reqGetArg "t_period_date_from_$editID"]
			tpBindString PeriodDateTo       [reqGetArg "t_period_date_to_$editID"]

			asPlayFile -nocache business_period_edit.html
			return
		}

		"BPDoEdit" {
			# Edit existing Business Period
			ob_log::write DEBUG {$fn : Action $act. Commencing.}

			# Required args: 3
			set bp_id               [reqGetArg EditID]
			set bp_date_from        [_to_informix [reqGetArg bp_date_from]]
			set bp_date_to          [_to_informix [reqGetArg bp_date_to]]

			set valid [_check_valid_bp $bp_date_from $bp_date_to]

			if { !$valid } {
				# proposed bp is invalid for some reason
				go_business_period_setup
				return
			}

			set update_sql {
				update 
					tBusinessPeriod 
				set
					period_date_from = ?,
					period_date_to  = ?
				where
					bp_id = ?
			}

			set stmt_upd [inf_prep_sql $DB $update_sql]

			if { [catch { set res [inf_exec_stmt $stmt_upd $bp_date_from $bp_date_to $bp_id] } msg]} {
				_bind_error $fn $msg {Business period editing failed}
				set valid 0
			}

			if { $valid } { _bind_info {Business period edited}  }

			catch {db_close $res}
			inf_close_stmt $stmt_upd

			go_business_period_setup
			return

		} ;# END EDIT action

		default { 
			_bind_error     $fn \
			                {Unexpected SubmitName value} \
			                {Unexpected Input}
			go_business_period_setup
			return
		}
	} ;# end switch 

} ;# end proc



#
# ----------------------------------------------------------------------------
# _to_informix : Converts a dd/mm/yy data into informix format
#    does nothing if starting format is other than dd/mm/yy
#    you could add other formats if needed
# ----------------------------------------------------------------------------
#

proc _to_informix {data} {

	# dd/mm/yy --> yyyy-mm-dd
	if {[regexp {^(\d{2})/(\d{2})/(\d{2})$} $data all dd mm yy]} {
		set data [clock format [clock scan "$mm/$dd/$yy"] -format "%Y-%m-%d"]
	}
	return $data
}



#
# ----------------------------------------------------------------------------
# _check_valid_bp : private helper function to check if the BP being added or
#      edited is valid 
#
#   inputs the two dates and the function name (for logging purposes) 
#       returns 0 if the bp is not valid
#       returns 1 if the bp is valid  
# ----------------------------------------------------------------------------
#
proc _check_valid_bp {from to} {

	set fn {ADMIN::BUSINESSPERIOD::_check_valid_bp >}

    # test if $from date is valid informix date yyyy-mm-dd
	if {! [regexp {^\d{4}-\d{2}-\d{2}$} $from match]} {
		_bind_error $fn \
		            "ERROR: $from bad format" \
		            "Operation failed: bad date format"
		return 0
	}

	# test if $to date is valid informix date yyyy-mm-dd
	if {! [regexp {^\d{4}-\d{2}-\d{2}$} $to match]} {
		_bind_error $fn \
		            "ERROR: $to bad format" \
		            "Operation failed: bad date format"
		return 0
	}

	# if $to is before $from , the BP is invalid
	if {[expr [clock scan $to] < [clock scan $from]] } {
		_bind_error $fn \
		            "ERROR: $to is earlier than $from" \
		            "Operation failed: $to is earlier than $from"

		return 0
	}

	###########################################################################
	# TODO:Check for Overlapping BP
	###########################################################################
	# This functionality is commented out, because user can correct the 
	# overlapping BPs by editing them (they should not even type them in, but
	# this can happen with typing errors or so).
	#
	# If there are overlapping business periods left into the system, this can
	# lead to problems in the "Customer Totals" screen
	#
	# This works but gives problems if we try to edit a BP which is "inside" a 
	# overlapping boundary
	#
	# example   Feb     2009-01-29   2009-02-26
	#           Mar     2009-02-27   2009-03-25
	#
	# and we want to change to 
	#
	# 1)         Feb      2009-01-29  2009-02-24
	#
	# and then to 
	# 
	# 2)         Mar      2009-02-25  2009-03-25
	#
	# Final result is legal but the 1) editing fails to pass the following
	# check
	#
	# This needs more testing
	############################################################################

	#set overlap_sql {
	#        select
	#            bp_id
	#        from 
	#            tBusinessPeriod
	#        where 
	#            period_date_to >= ?
	#            and period_date_from <= ?
	#        }

	#set stmt_ovrlp [inf_prep_sql $DB $overlap_sql]

	#if { [catch { set res [inf_exec_stmt $stmt_ovrlp $from $to] } msg]} {
                # db failure
	#           _bind_error $fn \
	#                       $msg \
	#                       {Business period operation failed}
	#            return 0
	#        }

	# if we insert / update , we will create an overlapping BP so we stop here
	#if { [db_get_nrows $res] != 0} {
	#            _bind_error $fn \
	#                       "ERROR: Tried to create overlapping BP. Aborted." \
	#                       {Operation failed: Overlapping Business Periods are not allowed}

	#        catch {db_close $res}
	#        inf_close_stmt $stmt_ovrlp

	#        return 0
	#}

	#catch {db_close $res}
	#inf_close_stmt $stmt_ovrlp

	# all was fine
	return 1
}



#
# ----------------------------------------------------------------------------
# _bind_error : private helper function on error messages
#      Logs error into the OT Log, and binds vars to warn user about the error   
# ----------------------------------------------------------------------------
#
proc _bind_error {fn msg to_user_msg} {
	ob_log::write DEBUG {$fn Error: $msg}
	tpSetVar     ErrorFlag  1
	tpBindString ErrorMsg   $to_user_msg
	}



#
# ----------------------------------------------------------------------------
# _bind_info : private helper function to display user infos
#     Binding of informative messages for the template to display
# ----------------------------------------------------------------------------
#
proc _bind_info {msg} {
	tpSetVar     InfoFlag  1
	tpBindString InfoMsg   $msg
	}

} ;# Closing namespace 