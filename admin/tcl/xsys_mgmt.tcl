# ==============================================================
# $Id: xsys_mgmt.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# External systems management, including optional systems
#

package provide xsys_mgmt 1.0

package require xsys
package require util_db  4.5

namespace eval ADMIN::XSYS_MGMT {

	# Initialization flag
	variable INIT 0

	# Configuration
	variable CFG

	# Actions
	asSetAct ADMIN::XSYS_MGMT::OptInSystem [namespace code opt_in_system]

}


#-------------------------------------------------------------------------------
# Initialization function
#
proc ADMIN::XSYS_MGMT::init {} {

	variable CFG
	variable INIT

	set fn {ADMIN::XSYS_MGMT::_init}

	if {$INIT} return

	ob_log::write DEBUG {$fn - Initializing External System Management}

	set CFG(XSYS_OPTIONAL_SYNCTYPE) [OT_CfgGet XSYS_OPTIONAL_SYNCTYPE O]
	ob_log::write DEBUG {$fn - Optional type is $CFG(XSYS_OPTIONAL_SYNCTYPE)}

	set INIT 1

}


#-------------------------------------------------------------------------------
# Bind up optional systems defined in the database
# An optional system has tXsysHost.sync_types containing "O"
#
#   cust_id : a cust_id or 0 . When passing a cust_id, we will bind
#   the customer_system details as well.
#
proc ADMIN::XSYS_MGMT::bind_optional_sys_sync { {cust_id 0} } {

	set fn {ADMIN::XSYS_MGMT::bind_optional_sys_sync}

	variable CFG
	variable OPT_XSYS
	variable CUST_OPT_XSYS

	set opt_xsys_cols      [list system_id name]
	set cust_opt_xsys_cols [list system_id name cr_date]
	set cns                [namespace current]

	ob_log::write DEBUG {$fn - binding optional systems (Cust id is $cust_id)}

	set opt_sync_type "%$CFG(XSYS_OPTIONAL_SYNCTYPE)%"

	if {[catch {
		set res [ob_db::exec_qry xsys::get_systems_for_type $opt_sync_type]
		} msg]} {
		error "$fn - Error retrieving Optional Systems : $msg"
	}

	set OPT_XSYS(num) [db_get_nrows $res]

	# Fetch info from DB
	for {set i 0} {$i < $OPT_XSYS(num)} {incr i} {
		foreach c $opt_xsys_cols {
			set OPT_XSYS($i,$c) [db_get_col $res $i $c]
		}
	}

	db_close $res

	# Bind for template player
	tpSetVar num_opt_xsys $OPT_XSYS(num)

	foreach c $opt_xsys_cols {
		tpBindVar opt_xsys_${c} ${cns}::OPT_XSYS $c opt_xsys_idx
	}

	GC::mark OPT_XSYS

	# If the cust_id is passed, also bind the customer systems
	if {$cust_id != 0} {

		# Sanity check
		if { [regexp {^\d+$} $cust_id]} {

			if {[catch {
				set res [ob_db::exec_qry xsys::get_cust_optional_systems $cust_id]
				} msg]} {
			error "$fn - Error retrieving Cust $cust_id optional systems : $msg"
			}

			set CUST_OPT_XSYS(num)     [db_get_nrows $res]
			set CUST_OPT_XSYS(systems) [list]

			# Fetch info from DB
			for {set i 0} {$i < $CUST_OPT_XSYS(num)} {incr i} {
				foreach c $cust_opt_xsys_cols {
					set CUST_OPT_XSYS($i,$c) [db_get_col $res $i $c]
					if { $c == "system_id" } {
						lappend CUST_OPT_XSYS(systems) $CUST_OPT_XSYS($i,$c)
					}
				}
			}

			db_close $res

			# Bind for template player
			tpSetVar     num_cust_opt_xsys  $CUST_OPT_XSYS(num)
			tpBindString opted_in_xsys_list [join $CUST_OPT_XSYS(systems) ,]

			foreach c $cust_opt_xsys_cols {
				tpBindVar cust_opt_xsys_${c} \
					${cns}::CUST_OPT_XSYS $c cust_opt_xsys_idx
			}

			GC::mark CUST_OPT_XSYS

		} else {
			ob_log::write ERROR {$fn - Invalid cust_id passed}
		}
	}

}


#-------------------------------------------------------------------------------
# Opt in a system
#
# TODO : graceful error handling
#
proc ADMIN::XSYS_MGMT::opt_in_system {} {

	set fn {ADMIN::XSYS_MGMT::opt_in_system}

	ob_log::write INFO {$fn - Opting in system}

	# Grab Params
	set system_id [ob_chk::get_arg xsys_id_toadd -on_err "" {RE -args {^\d+$}}]
	set cust_id   [ob_chk::get_arg cust_id -on_err "" {RE -args {^\d+$}}]
	set dest_act  [ob_chk::get_arg dest_act -on_err "" {RE -args {^[A-Za-z:_-]+$}}]

	ob_log::write DEBUG {$fn - Opt In $system_id for $cust_id  - ($dest_act)}

	# Transactional
	ob_db::begin_tran

	if {[catch {
		# Opt in Customer
		::xsys::opt_in_cust_xsys $system_id $cust_id 1

		# Queue customer registration
		::xsys::opt_queue_cust_reg $system_id $cust_id 1
		} msg]} {
			# Rollback
			ob_db::rollback_tran
			error "$fn - Opt-in failed for $cust_id on $system_id : $msg"
	}

	# Commit
	ob_db::commit_tran
	ob_log::write INFO {$fn - Opt-in successfull for $cust_id on $system_id}

	# Do we have a destination
	if {$dest_act != ""} {
		# Rebind Cust Id
		reqSetArg CustId $cust_id
			tpSetVar IsBindMsg 1
		tpBindString BindMsg \
			"Successfully opted in customer for system $system_id"
		# Eval the destination procedure

		ob_log::write INFO {$fn - now redirecting to $dest_act}
		eval $dest_act
	} else {
		set msg "$fn - Don't know where to redirect after opt-in"
		ob_log::write ERROR $msg
		error $msg
	}
}
