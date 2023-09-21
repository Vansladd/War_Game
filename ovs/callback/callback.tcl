# ==========================================================================================
# $Id: callback.tcl,v 1.1 2011/10/04 12:40:38 xbourgui Exp $
# Copyright (c) Orbis Technology 2000. All rights reserved.
#
# callback.tcl
#
# This is a callback function which is called in the OVS code, when the response is received back from
# the OVS server.
# It details what needs to be done depending on the result received.
# The result will be one of four states:
# S = Suspend
# N = do Nothing
# A = Alert admin user
# P = Pending
#
# ==========================================================================================

namespace eval ob_ovs_callback {

	variable INITIALISED

	set INITIALISED 0

}


#initialise queries
proc ob_ovs_callback::init_queries {} {

	variable INITIALISED

	if {$INITIALISED} {
		return
	}

	# update customer age verification status in tAgeVerCust
	ob_db::store_qry ob_ovs_callback::upd_cust_ovs_status [subst {
		execute procedure pUpdVrfCustStatus
		(
			p_adminuser     = "[OT_CfgGet OVS_ADMIN_USER]",
			p_cust_id       = ?,
			p_status        = ?,
			p_vrf_prfl_code = ?,
			p_prfl_model_id = ?,
			p_transactional = ?,
			p_reason_code   = ?
		)
	}]

	# update customer action in tCustomerFlag
	ob_db::store_qry ob_ovs_callback::add_incident_sync {
		execute procedure pXSysSyncInc
		(
			p_cust_id  = ?,
			p_subject  = ?,
			p_type     = ?,
			p_desc     = ?
		);
	}

	# update customer action in tCustomerFlag
	ob_db::store_qry ob_ovs_callback::get_av_desc_text {
		select
			resp_value
		from
			tVrfChk c,
			tVrfAuthProChk apc,
			tVrfAuthProDef apd
		where
			c.vrf_prfl_id = ?
			and c.vrf_check_id = apc.vrf_check_id
			and apc.vrf_auth_pro_def_id = apd.vrf_auth_pro_def_id
			and apd.response_no = "decision_text"
	}

	set INITIALISED 1

}

#callback_function for UKBetting/TotalBet
proc ob_ovs_callback::callback_function {result profile_id cust_id prfl_model_id {in_tran "N"}} {

	variable INITIALISED

	ob_log::write DEBUG "ob_ovs_callback::callback_function <result $result> <profile_id $profile_id> <prfl_model_id $prfl_model_id> <cust_id $cust_id>"

	if {!$INITIALISED} {
		init_queries
	}

	# Are we in a transaction already?
	set transactional [expr {$in_tran == "Y" ? "N" : "Y"}]

	# ----------------------------
	# Status definitions
	# ----------------------------
	# 'A', -- (A)ctivate
	# 'P', -- (P) - Restricted
	# 'S', -- (S)uspend
	# 'U', -- (U)nderage - can only be put into via admin user...
	# 'N'  -- (N)othing

	ob_log::write INFO {OVS status is $result}

	switch $result {
		S {
			# Update the OVS action.
			if {[catch {
				# TODO:  EXP is Experian - need to make this generic
				ob_db::exec_qry ob_ovs_callback::upd_cust_ovs_status $cust_id "S" [OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""] $prfl_model_id $transactional "EXP"
			} msg]} {
				ob_log::write ERROR {OVS: Failed to update customer ovs action: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}

			# Insert incident in the RightNow queue.
			if {[OT_CfgGet RIGHT_NOW_ENABLE 0]} {
				add_right_now_incident $cust_id $profile_id
			}
		}
		P {
			if {[catch {
				ob_db::exec_qry ob_ovs_callback::upd_cust_ovs_status $cust_id "P" [OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""] $prfl_model_id $transactional "EXP"
			} msg]} {
				ob_log::write ERROR {OVS: Failed to update customer ovs action: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}

			# Insert incident in the RightNow queue.
			if {[OT_CfgGet RIGHT_NOW_ENABLE 0]} {
				add_right_now_incident $cust_id $profile_id
			}
		}
		N -
		A {
			# The user has passed OVS checks, give them full access.
			if {[catch {
				ob_db::exec_qry ob_ovs_callback::upd_cust_ovs_status $cust_id "A" [OT_CfgGet FUNC_OVS_AGE_VRF_PRFL_CODE ""] $prfl_model_id $transactional "EXP"
			} msg]} {
				ob_log::write ERROR {OVS: Failed to update customer ovs action: $msg}
				error OB_ERR_OVS_QRY_FAIL
			}
		}
	}

	if {[OT_CfgGet FUNC_KYC 0]} {
		ob_kyc::do_check $cust_id 1
	}

	if {[OT_CfgGet ENABLE_STRALFORS 0]} {
		# Add Stralfors flag to account to signify welcome pack generation
		tb_register::tb_stralfor_code $cust_id $transactional
	}

	return OB_OK
}



# Add an incident to RightNow.
# params:
# 	cust_id    - 
# 	profile_id - tVrfPrfl.vrf_prfl_id for the current check.
# 	type       - type of RightNow incident to raise.
proc ob_ovs_callback::add_right_now_incident {cust_id profile_id} {
	global DB

	set subject [OT_CfgGet RIGHT_NOW_AV_SUBJECT ""]
	set type    {AV}
	set desc    [get_av_desc_text $profile_id]

	if {[catch {
		ob_db::exec_qry ob_ovs_callback::add_incident_sync -inc-type \
					$cust_id STRING \
					$subject STRING \
					$type    STRING \
					$desc    TEXT \
	} msg]} {
		ob_log::write ERROR {OVS: Failed to exec ob_ovs_callback::add_incident_sync: $msg}
		return 0
	}

	return 1
}



# Retrieve the AV decision text of a customer.
proc ob_ovs_callback::get_av_desc_text {profile_id} {
	global DB

	set av_decision {}

	if {[catch {
		set res [ob_db::exec_qry ob_ovs_callback::get_av_desc_text $profile_id]
	} msg]} {
		ob_log::write ERROR {OVS: Failed to exec ob_ovs_callback::add_incident_sync: $msg}
		return $av_decision
	}

	set av_decision [db_get_coln $res 0 0]
	ob_db::rs_close $res

	return $av_decision
}

