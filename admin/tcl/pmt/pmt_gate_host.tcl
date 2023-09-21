# ==============================================================
# $Id: pmt_gate_host.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::PMT {

asSetAct ADMIN::PMT::GoPmtGateHost           [namespace code go_pmt_gate_host]
asSetAct ADMIN::PMT::DoUpdatePmtGateHost     [namespace code do_update_pmt_gate_host]
asSetAct ADMIN::PMT::DoUpdatePmtGateAcct     [namespace code do_update_pmt_gate_acct]

#
# ----------------------------------------------------------------------------
# Display current payment gateway settings
# ----------------------------------------------------------------------------
#
proc go_pmt_gate_host args {

	global DB PG_ACCTS PG_HOSTS PG_RULES PG_ACCT_CHOOSE

	GC::mark PG_ACCTS PG_HOSTS PG_RULES PG_ACCT_CHOOSE

	array set PG_ACCTS [list]
	array set PG_HOSTS [list]
	array set PG_RULES [list]

	#
	# ------- Payment Gateway Accounts -------
	#

	set sql [subst {
		select
			pg_acct_id,
			pg_type,
			desc,
			default_acct,
			pg_version,
			DECODE(default_acct,'Y','checked','') as checked
		from
			tPmtGateAcct
		where
			status = 'A'
		order by pg_type
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	set cur_def_acct ""
	set cur_def_type ""
	set cur_def_host ""

	for {set i 0} {$i < $nrows} {incr i} {

		set PG_ACCTS($i,pg_acct_id)   [db_get_col $res $i pg_acct_id]
		set PG_ACCTS($i,pg_type)      [db_get_col $res $i pg_type]
		set PG_ACCTS($i,desc)         [db_get_col $res $i desc]
		set PG_ACCTS($i,default_acct) [db_get_col $res $i default_acct]
		set PG_ACCTS($i,pg_version)   [db_get_col $res $i pg_version]
		set PG_ACCTS($i,checked)      [db_get_col $res $i checked]

		if {$PG_ACCTS($i,default_acct) == "Y"} {
			set cur_def_acct $PG_ACCTS($i,desc)
			set cur_def_type $PG_ACCTS($i,pg_type)
		}

	}

	tpSetVar NumPGAccts $nrows

	db_close $res

	tpBindVar PgAcctId           PG_ACCTS pg_acct_id      pga_idx
	tpBindVar PgAcctType         PG_ACCTS pg_type         pga_idx
	tpBindVar PgAcctDesc         PG_ACCTS desc            pga_idx
	tpBindVar PgAcctDefault      PG_ACCTS default_acct    pga_idx
	tpBindVar PgAcctVersion      PG_ACCTS pg_version      pga_idx
	tpBindVar PgAcctChecked      PG_ACCTS checked         pga_idx

	#
	# -------- Payment Gateway Hosts -------
	#

	set sql [subst {

		select
			pg_host_id,
			pg_ip,
			pg_port,
			pg_type,
			resp_timeout,
			conn_timeout,
			desc,
			default,
			DECODE(default,'Y','checked','') as checked
		from
			tPmtGateHost
		where
			status = 'A'
		order by pg_type

	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	set last_type ""
	set type -1

	# If there are no rows in tPmtGateHost, we cannot do any of this. 

	if {$nrows > 0} {

		for {set r 0} {$r < $nrows} {incr r} {

			set current_type [db_get_col $res $r pg_type]

			if {$current_type != $last_type} {
				incr type
				set last_type $current_type
				set i 0
			} else {
				incr i
			}

			set PG_HOSTS($type,$i,pg_host_id)   [db_get_col $res $r pg_host_id]
			set PG_HOSTS($type,$i,pg_ip)        [db_get_col $res $r pg_ip]
			set PG_HOSTS($type,$i,pg_port)      [db_get_col $res $r pg_port]
			set PG_HOSTS($type,$i,resp_timeout) [db_get_col $res $r resp_timeout]
			set PG_HOSTS($type,$i,conn_timeout) [db_get_col $res $r conn_timeout]
			set PG_HOSTS($type,$i,desc)         [db_get_col $res $r desc]
			set PG_HOSTS($type,$i,checked)      [db_get_col $res $r checked]
			set PG_HOSTS($type,$i,default)      [db_get_col $res $r default]

			set PG_HOSTS($type,pg_type) $current_type
			set PG_HOSTS($type,num_pgs) [expr {$i + 1}]

			if {[db_get_col $res $r default] == "Y"} {

				set desc [db_get_col $res $r desc]

				set PG_HOSTS($type,current)                         $desc
				set PG_RULES($PG_HOSTS($type,pg_type),cur_def_host) $desc

				# Is this the default host associated with our default type?
				if {$cur_def_type == $PG_HOSTS($type,pg_type)} {
					set cur_def_host $PG_RULES($PG_HOSTS($type,pg_type),cur_def_host)
				}
			}

		}

		tpSetVar NumPGTypes [expr {$type + 1}]

		db_close $res

		tpBindVar PgHostType         PG_HOSTS pg_type       type_idx
		tpBindVar CurrentPGHostName  PG_HOSTS current       type_idx
		tpBindVar PgHostId           PG_HOSTS pg_host_id    type_idx pgh_idx
		tpBindVar PgHostIP           PG_HOSTS pg_ip         type_idx pgh_idx
		tpBindVar PgHostPort         PG_HOSTS pg_port       type_idx pgh_idx
		tpBindVar RespTimeout        PG_HOSTS resp_timeout  type_idx pgh_idx
		tpBindVar ConnTimeout        PG_HOSTS conn_timeout  type_idx pgh_idx
		tpBindVar Desc               PG_HOSTS desc          type_idx pgh_idx
		tpBindVar Default            PG_HOSTS default       type_idx pgh_idx
		tpBindVar Checked            PG_HOSTS checked       type_idx pgh_idx

		#
		# ------- Payment Gateway Rules --------
		#
		set res [payment_gateway::pmt_gtwy_get_pmt_rules]  
		
		if {[lindex $res 0] == 0} { 
			OT_LogWrite 1 "Error returning from payment_gateway::pmt_gtwy_get_pmt_rules ($res)"
			if {[OT_CfgGet ENCRYPT_FROM_CONF 0] == 1} { 
				err_bind "Error returning payment gateway rules. [lindex $res 1]"  
			} else { 
				err_bind "Error returning payment gateway rules. Please check crypto server. ([lindex $res 1])"  
			} 
			asPlayFile -nocache pmt/pmt_gate_host.html
			return
		}

		for {set i 0} {$i < $PG_ACCT_CHOOSE(num_entries)} {incr i} {

			set PG_RULES($i,priority)  $PG_ACCT_CHOOSE($i,priority)
			set PG_RULES($i,cond_desc) $PG_ACCT_CHOOSE($i,condition_desc)
			set PG_RULES($i,a_desc)    $PG_ACCT_CHOOSE($i,a_desc)
			set PG_RULES($i,cp_flag)   $PG_ACCT_CHOOSE($i,cp_flag)
			set PG_RULES($i,pg_type)   $PG_ACCT_CHOOSE($i,pg_type)

			if {$PG_ACCT_CHOOSE($i,h_desc) != ""} {
				set PG_RULES($i,h_desc) $PG_ACCT_CHOOSE($i,h_desc)
			} else {
				set PG_RULES($i,h_desc) [concat \
					$PG_RULES($PG_RULES($i,pg_type),cur_def_host) \
					"(Current $PG_RULES($i,pg_type) Default)"]
			}

		}

		set nrows $PG_ACCT_CHOOSE(num_entries)

		if {$cur_def_type != "" && $cur_def_host != ""} {

			OT_LogWrite 1 "Current Default Type: $cur_def_type"
			OT_LogWrite 1 "Current Default Host: $cur_def_host"

			set i $PG_ACCT_CHOOSE(num_entries)

			set PG_RULES($i,priority)  "Last"
			set PG_RULES($i,cond_desc) "       Default"
			set PG_RULES($i,a_desc)    "$cur_def_acct (Current default)"
			set PG_RULES($i,h_desc)    \
				"$cur_def_host (Current $cur_def_type Default)"
			set PG_RULES($i,cp_flag)   "(Configurable per application)"
			set PG_RULES($i,pg_type)   "$cur_def_type"

			incr nrows

		}

	}

	tpSetVar NumPCs $nrows

	tpBindVar Priority        PG_RULES priority  pgr_idx
	tpBindVar ConditionDesc   PG_RULES cond_desc pgr_idx
	tpBindVar Type            PG_RULES pg_type   pgr_idx
	tpBindVar PmtGateHostDesc PG_RULES h_desc    pgr_idx
	tpBindVar PmtGateAcctDesc PG_RULES a_desc    pgr_idx
	tpBindVar CPFlag          PG_RULES cp_flag   pgr_idx

	asPlayFile -nocache pmt/pmt_gate_host.html

}

#
# ----------------------------------------------------------------------------
# Switch the current active payment gateway host
# ----------------------------------------------------------------------------
#
proc do_update_pmt_gate_host args {

	global DB USERNAME

	set new_pg_id [reqGetArg new_pg_host_id]
	set pg_type   [reqGetArg PgHostType]

	set sql {
		execute procedure pSetPmtGateHost(
			p_adminuser = ?,
			p_pg_host_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {

		inf_exec_stmt $stmt $USERNAME $new_pg_id

	} msg]

   inf_close_stmt $stmt

	if {$c == 0} {
		msg_bind "Default Payment Gateway for $pg_type successfully changed"
	} else {
		err_bind $msg
	}

	go_pmt_gate_host

}

#
# ----------------------------------------------------------------------------
# Switch the current active payment gateway account
# ----------------------------------------------------------------------------
#
proc do_update_pmt_gate_acct args {

	global DB USERNAME

	set new_pg_acct_id [reqGetArg new_pg_acct_id]

	set sql {
		execute procedure pSetPmtGateAcct(
			p_adminuser = ?,
			p_pg_acct_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set c [catch {

		inf_exec_stmt $stmt $USERNAME $new_pg_acct_id

	} msg]

   inf_close_stmt $stmt

	if {$c == 0} {
		msg_bind "Default Payment Gateway Account successfully changed"
	} else {
		err_bind $msg
	}

	go_pmt_gate_host

}


}
