# =============================================================================
# $Id: kyc.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# =============================================================================


# -----------------------------------------------------------------------------
# Know Your Customer Management
# -----------------------------------------------------------------------------

namespace eval ADMIN::KYC {
}

#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One off initialisation
#
proc ADMIN::KYC::init {} {

	# Action handlers
	asSetAct ADMIN::KYC::GoCfg  [namespace code H_go_cfg]
	asSetAct ADMIN::KYC::DoCfg  [namespace code H_do_cfg]
	asSetAct ADMIN::KYC::DoCust [namespace code H_do_cust]

}



#-------------------------------------------------------------------------------
# Action handlers
#-------------------------------------------------------------------------------

# Go to KYC configuration page
#
proc ADMIN::KYC::H_go_cfg {} {

	global DB
	global KYC_GROUPS

	GC::mark KYC_GROUPS

	set sql {
		select
			g.group_id,
			g.desc,
			k.cash_out_thresh,
			k.stake_thresh,
			k.ccy_code
		from
			tXSysHostGrp       g,
			tKYCXSysCfg        k
		where
			g.type     = 'KYC'      and
			g.group_id = k.group_id
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {

		set group_id [db_get_col $res $i group_id]

		lappend KYC_GROUPS(group_ids)      $group_id

		set KYC_GROUPS($i,group_id)        $group_id
		set KYC_GROUPS($i,desc)            [db_get_col $res $i desc]
		set KYC_GROUPS($i,cash_out_thresh) [db_get_col $res $i cash_out_thresh]
		set KYC_GROUPS($i,stake_thresh)    [db_get_col $res $i stake_thresh]
		set KYC_GROUPS($i,ccy_code)        [db_get_col $res $i ccy_code]

	}

	db_close $res

	tpBindVar  KYCGroupID      KYC_GROUPS  group_id        kyc_idx
	tpBindVar  KYCDesc         KYC_GROUPS  desc            kyc_idx
	tpBindVar  KYCCashThresh   KYC_GROUPS  cash_out_thresh kyc_idx
	tpBindVar  KYCStakeThresh  KYC_GROUPS  stake_thresh    kyc_idx
	tpBindVar  KYCCcyCode      KYC_GROUPS  ccy_code        kyc_idx

	tpSetVar KYCNumRows $nrows

	tpBindString KYCGroupIds [join $KYC_GROUPS(group_ids) |]

	# bind up currencies
	make_ccy_binds

	asPlayFile -nocache kyc_cfg.html

}



# Go to KYC configuration page
#
proc ADMIN::KYC::H_do_cfg {} {

	global DB

	if {![op_allowed ManageKYCLimits]} {

		OT_LogWrite 1 "User does not have permission to update KYC limits"

		err_bind "You do not have permission to update KYC limits"
		H_go_cfg
		return
	}

	set group_ids [split [reqGetArg group_ids] |]

	set sql {
		update
			tKYCXSysCfg
		set
			cash_out_thresh  = ?,
			stake_thresh    = ?,
			ccy_code        = ?
		where
			group_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	# Start transaction
	inf_begin_tran $DB

	foreach group_id $group_ids {

		if {[catch {
			inf_exec_stmt $stmt \
				[reqGetArg cash_out_thresh_${group_id}] \
				[reqGetArg stake_thresh_${group_id}] \
				[reqGetArg ccy_code_${group_id}] \
				$group_id
		} msg]} {

			OT_LogWrite 1 "Error updating group: $group_id"
			inf_rollback_tran $DB
			err_bind "Failed to updated KYC limits"
			H_go_cfg
			return
		}

		if {![inf_get_row_count $stmt]} {

			OT_LogWrite 1 "Failed to find group: $group_id"
			inf_rollback_tran $DB
			err_bind "Failed to updated KYC limits"
			H_go_cfg
			return
		}

	}

	# Start transaction
	inf_commit_tran $DB

	inf_close_stmt $stmt

	msg_bind "Successfully updated KYC limits"

	H_go_cfg

}



# Update a customers kyc status
#
proc ADMIN::KYC::H_do_cust {} {

	global DB

	set cust_id [reqGetArg CustId]

	if {![op_allowed UpdateKYCStatus]} {

		OT_LogWrite 1 "User does not have permission to update KYC status"

		err_bind "You do not have permission to update KYC status"
		ADMIN::CUST::go_cust cust_id $cust_id
		return
	}

	# does the customer already have a row
	set sql {
		select first 1
			cust_id
		from
			tKYCCust
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]
	db_close $res

	if {$nrows} {
		set sql {
			update
				tKYCCust
			set
				status      = ?,
				reason_code = ?,
				notes       = ?
			where
				cust_id     = ?
		}
	} else {
		set sql {
			insert into tKYCCust (
				status,
				reason_code,
				notes,
				cust_id
			) values (
				?,
				?,
				?,
				?
			)
		}
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt \
		[reqGetArg status] \
		[reqGetArg reason_code] \
		[reqGetArg notes] \
		$cust_id]

	# did we modify a row?
	if {[inf_get_row_count $stmt] != 1} {
		OT_LogWrite 1 "ADMIN::KYC::H_do_cust Failed to update KYC status"
		err_bind "Failed to update KYC status"
	} else {
		OT_LogWrite 5 "ADMIN::KYC::H_do_cust Successfully update kyc status"
		msg_bind "Successfully updated customer KYC status"
	}

	inf_close_stmt $stmt
	db_close $res

	ADMIN::CUST::go_cust cust_id $cust_id

}



#-------------------------------------------------------------------------------
# Utilities
#-------------------------------------------------------------------------------

# Bind KYC details for custoemr page
#
#    cust_id - customer identifier
#
proc ADMIN::KYC::bind_cust { cust_id } {

	global DB
	global KYC_REASON

	GC::mark KYC_REASON

	foreach {status reason notes} [ADMIN::KYC::get_kyc_status $cust_id] {}

	tpBindString CustKYCStatus $status
	tpBindString CustKYCReason $reason
	tpBindString CustKYCNotes  $notes

	# bind up reason codes
	set sql {
		select
			reason_code,
			desc
		from
			tKYCReason
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	for {set i 0} {$i < $nrows} {incr i} {
		set KYC_REASON($i,reason_code)  [db_get_col $res $i reason_code]
		set KYC_REASON($i,desc)         [db_get_col $res $i desc]
	}

	db_close $res

	tpBindVar  KYCReasonCode   KYC_REASON  reason_code     kyc_idx
	tpBindVar  KYCDesc         KYC_REASON  desc            kyc_idx

	tpSetVar KYCNumReasonRows $nrows

}



# Get a customer KYC status
#
#    cust_id - customer identifier
#
#    returns list
#          status      - the customers kyc status
#          reason_code - the reason for the status
#
proc ADMIN::KYC::get_kyc_status { cust_id } {

	global DB

	set sql {
		select
			status,
			reason_code,
			notes
		from
			tKYCCust
		where
			cust_id = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $cust_id]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	if {!$nrows} {
		db_close $res
		return [list "" "" ""]
	}

	set status      [db_get_col $res 0 status]
	set reason_code [db_get_col $res 0 reason_code]
	set notes       [db_get_col $res 0 notes]

	db_close $res
	return [list $status $reason_code $notes]

}

# self initialisation
ADMIN::KYC::init
