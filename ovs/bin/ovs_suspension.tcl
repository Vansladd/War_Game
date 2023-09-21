# $Id: ovs_suspension.tcl,v 1.1 2011/10/04 12:40:37 xbourgui Exp $

load "libOT_InfTcl.so"
load "libOT_Tcl.so"

OT_CfgRead [lindex $argv 0]

set xtn [OT_CfgGet TCL_XTN tcl]

lappend auto_path [OT_CfgGet SHARED_TCL shared_tcl]

# Dependencies

package require util_log
OT_LogWrite 5 "Starting ovs_suspension.tcl..."
ob_log::sl_init [OT_CfgGet LOG_DIR] [OT_CfgGet LOG_FILE]
package require util_db_compat
package require bin_standalone
package require util_xl

namespace import OB_db::*

# Initialise Dependencies

ob_db::init
OT_LogWrite 5 "Attempting to connect to database"
OT_LogWrite 5 "initialising database"
OB_db::db_init
OT_LogWrite 5 "db_init complete"
ob_sl::init -as_restart_exit 0

proc init {} {
	ob_log::write INFO "Initializing..."
	prep_qrys
}

proc prep_qrys {} {
	ob_log::write INFO "Preparing queries..."

	OB_db::db_store_qry suspend_cust [subst {
		execute procedure pUpdVrfCustStatus(
			p_adminuser     = '[OT_CfgGet OVS_ADMIN_USER]',
			p_cust_id        = ?,
			p_status         = 'S',
			p_vrf_prfl_code  = ?
		);
	}]

	OB_db::db_store_qry cust_suspend_list {
		select
			c.cust_id,
			cvs.vrf_prfl_code,
			cvs.expiry_date
		from
			tCustomer        c,
			tVrfCustStatus   cvs
		where
				c.cust_id          = cvs.cust_id
			and lower(cvs.status)  = "p"
			and cvs.expiry_date    < current
			and c.type <> 'D'
	}
}

proc set_ovs_suspended {
	cust_id
	vrf_prfl_code
} {
	# Set customer flag to suspended.
	if {[catch [OB_db::db_exec_qry suspend_cust \
		$cust_id \
		$vrf_prfl_code \
	] msg]} {
		ob_log::write ERROR "Unable to update customer flag, msg:$msg"
		return 0
	}

	return 1
}

proc main {} {
	if {[catch {set res [OB_db::db_exec_qry cust_suspend_list]} msg]} {
		ob_log::write ERROR "Failed to run query cust_suspend_list, msg: $msg"
		return 0
	}
	
	set num_custs [db_get_nrows $res]
	set success 0

	for {set i 0} {$i < $num_custs} {incr i} {
		foreach name [db_get_colnames $res] {
			set $name [db_get_col $res $i $name]
		}
	
		ob_log::write INFO [string repeat "-" 20]
		ob_log::write INFO "Setting cust_id        : $cust_id to suspended."
		ob_log::write INFO "profile(vrf_prfl_code) : $vrf_prfl_code"
		ob_log::write INFO "expiry date            : $expiry_date"
	
		# Suspend the customer.
		if {[set_ovs_suspended \
			$cust_id \
			$vrf_prfl_code] \
		} {
			incr success
			ob_log::write INFO "SUCCESS!"
		} else {
			ob_log::write ERROR "ERROR, failed to suspend the customer, cust_id: $cust_id"
		}
	
		ob_log::write INFO [string repeat "-" 20]
	}

	ob_log::write INFO [string repeat "-" 20]
	ob_log::write INFO "FINISHED!"
	if {$num_custs} {
		ob_log::write INFO "$success/$num_custs processed."
	} else {
		ob_log::write INFO "No customers to process."
	}
	ob_log::write INFO [string repeat "-" 20]
}

proc end {} {
	# Nothing...
}

# Run...
init
main
end




