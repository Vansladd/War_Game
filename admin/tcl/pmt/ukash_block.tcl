# ==============================================================
# $Id: ukash_block.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2010 OpenBet Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::PMT:: {

asSetAct ADMIN::PMT::GoUkashBlocks [namespace code go_ukash_blocks]

#
# ----------------------------------------------------------------------------
# Ukash Block maintenance
# ----------------------------------------------------------------------------
#
proc go_ukash_blocks args {
	set which    [reqGetArg SubmitName]
	set block_id [reqGetArg UkashBlockId]

	switch $which {
		"GoBlkAdd" {
			go_ukash_blk_add
		}
		"DoBlkAdd" {
			do_ukash_blk_add
		}
		"DoBlkUpd" {
        	do_ukash_blk_upd
		}
		"DoBlkDel" {
			do_ukash_blk_del
		}
		"Back" {
			do_ukash_blocks
		}
		default {
		 	if {$block_id != ""} {
		 		go_ukash_block
			} else {
				do_ukash_blocks
			}
		}
	}
}

proc do_ukash_blocks args {

	global DB UKASH

	set sql [subst {
   		select
   			ukash_block_id,
   			status,
   			voucher
		from
			tukashblock
		order by
			voucher
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set      num_blocks [db_get_nrows $res]
	tpSetVar NumBlocks  $num_blocks

	for {set i 0} {$i < $num_blocks} {incr i} {
    	set UKASH($i,id)           [db_get_col $res $i ukash_block_id]
    	set UKASH($i,status)       [db_get_col $res $i status]
    	set UKASH($i,voucher_code) [db_get_col $res $i voucher]
	}

	tpBindVar UkashBlockId     UKASH id           block_idx
	tpBindVar UkashStatus      UKASH status       block_idx
	tpBindVar UkashVoucherCode UKASH voucher_code block_idx

	db_close $res

	asPlayFile -nocache ukash_block_list.html	
}

proc go_ukash_blk_add args {
	global DB

	asPlayFile -nocache ukash_block_add.html
}

proc do_ukash_blk_add args {
	global DB

	set voucher [reqGetArg voucher]
	set status  [reqGetArg status]
	set comment [reqGetArg comment]

	set sql [subst {
		insert into tukashblock (
			voucher,
			status,
			comment
		) values (
            ?,
            ?,
            ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $voucher $status $comment]
	inf_close_stmt $stmt

	db_close $res

	do_ukash_blocks
}

proc go_ukash_block {{block_id ""}} {

	global DB

	if {$block_id == ""} {
		set block_id [reqGetArg UkashBlockId]
	}

	set sql [subst {
   		select
   			ukash_block_id,
   			status,
   			voucher,
   			comment
		from
			tukashblock
		where
			ukash_block_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $block_id]
	inf_close_stmt $stmt

	tpBindString UkashBlockId [db_get_col $res 0 ukash_block_id]
	tpBindString UkashStatus  [db_get_col $res 0 status]
	tpBindString UkashVoucher [db_get_col $res 0 voucher]
	tpBindString UkashComment [db_get_col $res 0 comment]

	db_close $res

	asPlayFile -nocache ukash_block.html	
}

proc do_ukash_blk_upd args {
	global DB

	set ukash_block_id [reqGetArg ukash_block_id]
	set status         [reqGetArg status]
	set voucher        [reqGetArg voucher]
	set comment        [reqGetArg comment]

	set sql [subst {
		update
			tukashblock
		set
			status  = ?,
			voucher = ?,
			comment = ?
		where
			ukash_block_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $status $voucher $comment $ukash_block_id]
	inf_close_stmt $stmt

	db_close $res

	go_ukash_block $ukash_block_id
}

proc do_ukash_blk_del args {
	global DB

	set ukash_block_id [reqGetArg ukash_block_id]

	set sql [subst {
		delete from tukashblock where ukash_block_id = ?
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $ukash_block_id]
	inf_close_stmt $stmt

	db_close $res

	do_ukash_blocks
}

}
