# ==============================================================
# $Id: pmt_checking.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT {

	asSetAct ADMIN::PMT::GoPmtChecking [namespace code go_pmt_checking]
	asSetAct ADMIN::PMT::DoUpdatePmtChecking [namespace code update_pmt_checking]


	proc go_pmt_checking {} {
		global DB checks

		set block_list ""
		set options [list Y N -]

		set stmt [inf_prep_sql $DB {
			select * from tPmtCntryChk
		}]

		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_rules_expected [OT_CfgGet NUM_CNTRY_CHK_RULES_EXPECTED] 

		if {[db_get_nrows $rs]!=$num_rules_expected} {
			err_bind "Incorrect number of rules in database"
		} else {
			set table 0
			set row 0
			for {set i 0} {$i<9} {incr i} {
				for {set col 0} {$col<3} {incr col} {
					if {[db_get_coln $rs $i [expr $col+1]]=="B"}  {
						set checks($table,$row,$col,db) "checked"
						
						set ip    [lindex $options [expr $row/3]]
						set bin   [lindex $options $col]
						set pc    [lindex $options [expr $row%3]]
	
						append block_list "${ip}${bin}${pc}<br/>"
					}
				}
				incr row
				if {$row==3} {
					incr table
					set row 0
				}
			}
			tpBindVar CHECK_BOX checks db table_idx row_idx col_idx
			
			tpBindString block_list $block_list
		}
		
		asPlayFile -nocache "pmt/pmt_checking.html"
		catch {unset checks}
	}

	proc update_pmt_checking {} {
		
		global DB
		
		set options [list Y N -]
		
		set stmt [inf_prep_sql $DB {
			update
			    tPmtCntryChk
			set us = ?,
		        non_us = ?,
			    unknown = ?
			where
			    rule_id = ?
		}]

		
		set table 0
		set row 0
		for {set i 0} {$i<9} {incr i} {
			set stmt_params ""
			for {set col 0} {$col<3} {incr col} {
				if {[reqGetArg "C$table$row$col"]=="on"} {
					set stmt_params "$stmt_params B"
				} else {
					set stmt_params "$stmt_params -"
				}
			}
			
			eval "inf_exec_stmt $stmt $stmt_params [expr $i+1]"
			
			incr row

			if {$row==3} {
				incr table
				set row 0
			}
		}
		inf_close_stmt $stmt
		msg_bind "Payment Checks updated"
		go_pmt_checking
	}
	
}
