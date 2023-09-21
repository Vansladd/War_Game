# ==============================================================
# $Id: ix_comm_grp.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2002 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IX_COMM_GRP {

asSetAct ADMIN::IX_COMM_GRP::GoCommGrps [namespace code go_ix_comm_grps]
asSetAct ADMIN::IX_COMM_GRP::GoCommGrp  [namespace code go_ix_comm_grp]
asSetAct ADMIN::IX_COMM_GRP::DoCommGrp  [namespace code do_ix_comm_grp]

#
# ----------------------------------------------------------------------------
# Show list of commission groups
# ----------------------------------------------------------------------------
#
proc go_ix_comm_grps args {

	#
	# Find out some information about the class and type
	#
	set sql [subst {
		select
			c.comm_grp_id,
			c.name,
			c.comm_mul
		from
			tfCommGrp c
		order by
			c.name
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumCommGrps [set n_rows [db_get_nrows $res]]

	for {set r 0} {$r < $n_rows} {incr r} {
		set ::CGRP($r,comm_grp_id) [db_get_col $res $r comm_grp_id]
		set ::CGRP($r,name)        [db_get_col $res $r name]
		set ::CGRP($r,mul)         [db_get_col $res $r comm_mul]
	}

	db_close $res

	GC::mark ::CGRP

	tpBindVar CommGrpId   ::CGRP comm_grp_id cg_idx
	tpBindVar CommGrpName ::CGRP name        cg_idx
	tpBindVar CommGrpMul  ::CGRP mul         cg_idx

	asPlayFile -nocache ix_comm_grp_list.html
}


#
# ----------------------------------------------------------------------------
# Go to commission group
# ----------------------------------------------------------------------------
#
proc go_ix_comm_grp args {

	set comm_grp_id [reqGetArg CommGrpId]

	if {$comm_grp_id == ""} {

		tpSetVar opAdd 1

	} else {

		tpSetVar opAdd 0

		#
		# Find out some information about the class and type
		#
		set sql [subst {
			select
				c.comm_grp_id,
				c.name,
				c.desc,
				c.comm_mul
			from
				tfCommGrp c
			where
				c.comm_grp_id = ?
		}]

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt $comm_grp_id]
		inf_close_stmt $stmt

		tpBindString CommGrpId     $comm_grp_id
		tpBindString CommGrpName   [db_get_col $res 0 name]
		tpBindString CommGrpDesc   [db_get_col $res 0 desc]
		tpBindString CommGrpMul    [db_get_col $res 0 comm_mul]

		db_close $res
	}

	asPlayFile -nocache ix_comm_grp.html
}


#
# ----------------------------------------------------------------------------
# Update market group
# ----------------------------------------------------------------------------
#
proc do_ix_comm_grp args {

	set act [reqGetArg SubmitName]

	if {$act == "CommGrpAdd"} {
		do_ix_comm_grp_add
	} elseif {$act == "CommGrpMod"} {
		do_ix_comm_grp_upd
	} elseif {$act == "CommGrpDel"} {
		do_ix_comm_grp_del
	} elseif {$act == "CommGrpBack"} {
		go_ix_comm_grps
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_ix_comm_grp_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoCommGrp(
			p_op = 'I',
			p_adminuser = ?,
			p_name = ?,
			p_desc = ?,
			p_comm_mul = ?
		)
	}]

	set bad 0

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CommGrpName]\
			[reqGetArg CommGrpDesc]\
			[reqGetArg CommGrpMul]]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add commission group"
			set bad 1
		} else {
			set comm_grp_id [db_get_coln $res 0 0]
		}
		catch {db_close $res}
	}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ix_comm_grp
		return
	}

	inf_commit_tran $DB

	tpSetVar MarketAdded 1

	go_ix_comm_grps
}

proc do_ix_comm_grp_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoCommGrp(
			p_op = 'U',
			p_adminuser = ?,
			p_comm_grp_id = ?,
			p_name = ?,
			p_desc = ?,
			p_comm_mul = ?
		)
	}]

	set channels [make_channel_str]

	set bad 0

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CommGrpId]\
			[reqGetArg CommGrpName]\
			[reqGetArg CommGrpDesc]\
			[reqGetArg CommGrpMul]]} msg]} {
		set bad 1
		err_bind $msg
	}
	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		#
		# Something went wrong
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		tpSetVar MarketAddFailed 1
		go_ix_comm_grp
		return
	}

	inf_commit_tran $DB

	go_ix_comm_grps
}

proc do_ix_comm_grp_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoCommGrp(
			p_op = 'D',
			p_adminuser = ?,
			p_comm_grp_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg CommGrpId]]} msg]} {
		err_bind $msg
		set bad 1
	}
	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad} {
		#
		# Something went wrong
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ix_comm_grp
		return
	}

	go_ix_comm_grps
}

}
