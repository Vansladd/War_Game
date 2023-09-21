# $Id: accounts.tcl,v 1.1 2011/10/04 12:40:39 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Checks for queued customer verification requests and makes them
#
package provide ovs_accounts 4.5



# Dependenciesa
#
package require util_log
package require util_db



# Variables
#
namespace eval ob_ovs_accounts {

	variable INITIALISED

	set INITIALISED 0
}



# Prepare queries
#
proc ob_ovs_accounts::init_queries {} {

	variable INITIALISED

	if {$INITIALISED} {
		return
	}
	# update verification profile as parked
	ob_db::store_qry ob_ovs_accounts::park_profile {

		insert into tVrfPrflPark values (?)
	}

	# update customer status
	ob_db::store_qry ob_ovs_accounts::alter_customer {

		update tCustomer set status = ? where cust_id = ?
	}

	set INITIALISED 1
}



# Process customer accounts
# NB. Should be wrapped in catch statement to close any transaction. This query
# should throw an error if any problems occur.
#
proc ob_ovs_accounts::callback {result profile_id cust_id} {

	variable INITIALISED

	if {!$INITIALISED} {
		init_queries
	}
	# Take action based on result
	switch $result {
		P {# Park
			if {[catch {
				ob_db::exec_qry ob_ovs_accounts::park_profile $profile_id
			} msg]} {
				ob_log::write ERROR {OVS: Failed to park profile: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}
		}
		S {# Suspend
			if {[catch {
				ob_db::exec_qry ob_ovs_accounts::alter_customer "S" $cust_id
			} msg]} {
				ob_log::write ERROR {OVS: Failed to suspend customer: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}
		}
		A {# Activate
			if {[catch {
				ob_db::exec_qry ob_ovs_accounts::alter_customer "A" $cust_id
			} msg]} {
				ob_log::write ERROR {OVS: Failed to activate customer: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}
		}
		N {} # Nothing
		default {
			ob_log::write ERROR {OVS: Unknown result action: $result}
			error OB_ERR_OVS_INVALID_DATA
		}
	}
	return OB_OK
}
