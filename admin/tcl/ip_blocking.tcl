# $Id: ip_blocking.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
namespace eval ADMIN::IP_BLOCK {

	proc ip_block_init args {

		global betBlkQry

		set betBlkQry(get_block_list) {
			select
				block_id,
				ip_addr_lo,
				ip_addr_hi,
				cr_date,
				expires
			from
				tIPBlock
		}

		set betBlkQry(view_block) {
			select
				block_id,
				ip_addr_lo,
				ip_addr_hi,
				cr_date,
				expires,
				desc
			from
				tIPBlock
			where
				block_id = ?

		}

		set betBlkQry(add_block) {
			insert into tIPBlock(
				ip_addr_lo,
				ip_addr_hi,
				cr_date,
				expires,
				desc
			) values (
				?, ?, current, ?, ?
			)
		}

		set betBlkQry(edit_block) {
			update
				tIPBlock
			set
				ip_addr_lo = ?,
				ip_addr_hi = ?,
				expires = ?,
				desc =?
			where
				block_id = ?
		}

		set betBlkQry(delete_block) {
			delete from
				tIPBlock
			where
				block_id = ?
		}

		set betBlkQry(blocked_log) {
			select
				ip_address,
				date
			from
				tBlockedAccessLog
		}

		asSetAct ADMIN::IP_BLOCK::ViewBlockList      [namespace code block_list]
		asSetAct ADMIN::IP_BLOCK::ViewBlock          [namespace code view_block]
		asSetAct ADMIN::IP_BLOCK::EditBlock          [namespace code edit_block]
		asSetAct ADMIN::IP_BLOCK::BlockedLog         [namespace code blocked_log]
	}

	proc blocked_log {} {
		global DB betBlkQry BLOCKLOG

		if {[info exists BLOCKLOG]} {
			unset BLOCKLOG
		}

		set where [list]

		set from	[reqGetArg from]
		set to		[reqGetArg to]
		set ip		[reqGetArg ip]
		set like	[reqGetArg like]

		if {([string length $from] > 0) || ([string length $to] > 0)} {
			lappend where [mk_between_clause date date $from $to]
		}

		if {[string length $ip] > 0} {
			if {$like=="Y"} {
				lappend where "ip_address like \"%${ip}%\""
			} else {
				lappend where "ip_address = \"$ip\""
			}
		}

		if {[llength $where]} {
			set where "where [join $where { and }]"
		}

		set sql "$betBlkQry(blocked_log) $where"

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set log_count [db_get_nrows $res]

		tpSetVar logCount $log_count

		if {$log_count>0} {
			for {set r 0} {$r < $log_count} {incr r} {
				set BLOCKLOG($r,date) [db_get_col $res $r date]
				set BLOCKLOG($r,ip_address) [db_get_col $res $r ip_address]
			}
		}

		tpBindVar	Date		BLOCKLOG	date	block_idx
		tpBindVar	IPAddress	BLOCKLOG	ip_address	block_idx

		db_close $res

		asPlayFile -nocache ip_blocked_log.html
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
				set BLOCKED($r,block_id)   [db_get_col $res $r block_id]
				set BLOCKED($r,ip_addr_lo) [dec_to_ip [db_get_col $res $r ip_addr_lo]]
				set BLOCKED($r,ip_addr_hi) [dec_to_ip [db_get_col $res $r ip_addr_hi]]
				set BLOCKED($r,cr_date)    [db_get_col $res $r cr_date]
				set BLOCKED($r,expires)    [db_get_col $res $r expires]
			}
		}

		tpBindVar	BlockId		BLOCKED	block_id	block_idx
		tpBindVar	IPAddrLo	BLOCKED	ip_addr_lo	block_idx
		tpBindVar	IPAddrHi	BLOCKED	ip_addr_hi	block_idx
		tpBindVar	CrDate		BLOCKED	cr_date		block_idx
		tpBindVar	Expires		BLOCKED	expires		block_idx

		db_close $res

		asPlayFile -nocache ip_blocked_list.html
	}

	proc view_block {} {
		global DB betBlkQry

		set bid [reqGetArg block_id]

		if {$bid!=""} {
			set stmt [inf_prep_sql $DB $betBlkQry(view_block)]
			set res  [inf_exec_stmt $stmt $bid]
			inf_close_stmt $stmt

			set rows [db_get_nrows $res]

			if {$rows > 0} {
				tpSetVar     block_id $bid
				tpBindString BlockId  $bid
				tpBindString IPAddrLo [dec_to_ip [db_get_col $res 0 ip_addr_lo]]
				tpBindString IPAddrHi [dec_to_ip [db_get_col $res 0 ip_addr_hi]]
				tpBindString Expires  [db_get_col $res 0 expires]
				tpBindString Comment  [db_get_col $res 0 desc]
			}

			db_close $res
		}

		asPlayFile -nocache ip_block.html
	}

	proc edit_block {} {
		global DB betBlkQry

		set exp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}

		set block_id	[reqGetArg block_id]
		set ip_addr_lo	[reqGetArg addr_lo]
		set ip_addr_hi	[reqGetArg addr_hi]
		set expires		[reqGetArg expires]
		set comment		[reqGetArg comment]

		set delete		[reqGetArg delete]

		if {$delete!=""} {
			set stmt [inf_prep_sql $DB $betBlkQry(delete_block)]
			set res  [inf_exec_stmt $stmt $delete]
		} else {

			if {[regexp $exp $ip_addr_lo] == 0 && [regexp $exp $ip_addr_hi] == 0} {
				err_bind "At least one valid IP Address must be supplied"
				asPlayFile -nocache ip_block.html
				return
			}

			# deal with the case where only one address entered - set lo and hi to that address
			if {[regexp $exp $ip_addr_lo] == 0} {
				set ip_addr_lo $ip_addr_hi
			} elseif {[regexp $exp $ip_addr_hi] == 0} {
				set ip_addr_hi $ip_addr_lo
			}

			# convert the ip addresses to decimals for insert/update
			set ip_addr_lo [ip_to_dec $ip_addr_lo]
			set ip_addr_hi [ip_to_dec $ip_addr_hi]

			if {$block_id!=""} {
				## edit an existing block
				set stmt [inf_prep_sql $DB $betBlkQry(edit_block)]
				set res  [inf_exec_stmt $stmt $ip_addr_lo $ip_addr_hi $expires $comment $block_id]

			} else {
				## new block
				set stmt [inf_prep_sql $DB $betBlkQry(add_block)]
				set res  [inf_exec_stmt $stmt $ip_addr_lo $ip_addr_hi $expires $comment]
			}
		}

		inf_close_stmt $stmt
		db_close $res
		block_list
	}
	ip_block_init
}
