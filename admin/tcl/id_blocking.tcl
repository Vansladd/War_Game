# $Id: id_blocking.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
namespace eval ADMIN::ID_BLOCK {

	proc ip_block_init args {

		global betBlkQry

		set betBlkQry(get_block_list) {
			select
				*
			from
				tMachineId
		}


		set betBlkQry(add_block) {
			insert into tMachineId(
				machine_id,
				description
			) values (
				?, ?
			)
		}

		set betBlkQry(edit_block) {
			update
				tMachineId
			set
				machine_id = ?
			where
				machine_id = ?
		}

		set betBlkQry(delete_block) {
			delete from
				tMachineId
			where
				machine_id = ?
		}


		asSetAct ADMIN::ID_BLOCK::ViewBlockList      [namespace code block_list]
		asSetAct ADMIN::ID_BLOCK::AddBlock           [namespace code add_block]
		asSetAct ADMIN::ID_BLOCK::UpdateList         [namespace code update_list]
		asSetAct ADMIN::ID_BLOCK::EditBlock          [namespace code edit_block]
		asSetAct ADMIN::ID_BLOCK::DeleteBlock        [namespace code delete_block]
		asSetAct ADMIN::ID_BLOCK::ChangeBlock        [namespace code change_block]
		asSetAct ADMIN::ID_BLOCK::ChangedBlock       [namespace code changed_block]
		
	}

	proc update_list {} {
		asPlayFile -nocache update_machine_id.html
	}

	proc block_list {} {
		global DB betBlkQry BLOCKED
		

		if {[info exists BLOCKED]} {
			unset BLOCKED
		}

		set stmt [inf_prep_sql $DB $betBlkQry(get_block_list)]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set num_blocks [db_get_nrows $res]

		tpSetVar NumBlocks $num_blocks

		OT_LogWrite 1 "rows: $num_blocks"

		if {$num_blocks>0} {
			for {set r 0} {$r < $num_blocks} {incr r} {
				set BLOCKED($r,machine_id)   [db_get_col $res $r machine_id]
			}
		}

		tpBindVar    MachineId    BLOCKED    machine_id    block_idx

		db_close $res

		asPlayFile -nocache id_blocked_list.html
	}

	proc add_block {} {
		asPlayFile -nocache id_block.html
	}

	proc edit_block {} {
		global DB betBlkQry

		set exp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}

		set block_id    [reqGetArg m_id]
		set comment    [reqGetArg comment]

			if {$block_id == ""} {
				err_bind "Valid Machine ID must be supplied"
				asPlayFile -nocache id_block.html
				return
			}
				## new block
				set stmt [inf_prep_sql $DB $betBlkQry(add_block)]
				set res  [inf_exec_stmt $stmt $block_id $comment]

		inf_close_stmt $stmt
		db_close $res
		block_list
	}
	
	proc delete_block {} {
		global DB betBlkQry

		set delete  [reqGetArg delete]
                set stmt [inf_prep_sql $DB $betBlkQry(delete_block)]
                set res  [inf_exec_stmt $stmt $delete]
		inf_close_stmt $stmt
                db_close $res
                block_list
	}

	proc change_block {} {
	        asPlayFile -nocache change_machine_id.html
	}
	
	proc changed_block {} {
		global DB betBlkQry
		
		set previous_mid [reqGetArg previous_mid]
		set changed_mid [reqGetArg changed_mid]
                if {$changed_mid == ""} {
		    err_bind "Valid Machine ID must be supplied"
		    asPlayFile -nocache change_machine_id.html
		    return
		}
                set stmt [inf_prep_sql $DB $betBlkQry(edit_block)]
                set res  [inf_exec_stmt $stmt $changed_mid $previous_mid]
		inf_close_stmt $stmt
                db_close $res
                block_list
			
	}

	ip_block_init
}
