# ==============================================================
# $Id: ix_mkt_grp.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::IX_MKT_GRP {

asSetAct ADMIN::IX_MKT_GRP::GoIxMktGrp [namespace code go_ix_mkt_grp]
asSetAct ADMIN::IX_MKT_GRP::DoIxMktGrp [namespace code do_ix_mkt_grp]

#
# ----------------------------------------------------------------------------
# Go to market type page - two activators, one with a market id, one without
# ----------------------------------------------------------------------------
#
proc go_ix_mkt_grp args {

	set class_id   [reqGetArg ClassId]
	set type_id    [reqGetArg TypeId]
	set mkt_grp_id [reqGetArg MktGrpId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ClassId $class_id
	tpBindString TypeId  $type_id

	#
	# Find out some information about the class and type
	#
	set sql [subst {
		select
			c.name,
			c.sort,
			t.channels,
			t.name type_name,
			g.acc_max
		from
			tEvType t,
			tEvClass c,
			tControl g
		where
			t.ev_type_id = ? and
			t.ev_class_id = c.ev_class_id
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt $type_id]
	inf_close_stmt $stmt

	tpSetVar ClassSort [set csort [db_get_col $res 0 sort]]

	tpBindString ClassSort $csort

	set channel_mask [db_get_col $res 0 channels]

	tpBindString TypeName [db_get_col $res 0 type_name]

	db_close $res

	ADMIN::IXMKTPROPS::make_mkt_binds $csort

	if {$mkt_grp_id == ""} {

		tpSetVar opAdd 1

		set msort [reqGetArg IxMktGrpSort]

		make_channel_binds "" $channel_mask 1

		foreach {n v} {
			MktGrpIndexMin   index_min
			MktGrpIndexMax   index_max
			MktGrpIndexStep  index_step
			MktGrpMakeupStep makeup_step
			MktGrpEndOfDay   end_of_day
			MktGrpName       name
			MktGrpCode       code
			MktGrpPointPrice point_price
			MktGrpCommission commission
		} {
			tpBindString $n [ADMIN::IXMKTPROPS::mkt_flag $csort $msort $v]
		}

	} else {

		tpBindString MktGrpId $mkt_grp_id

		tpSetVar opAdd 0

		#
		# Get market information
		#
		set sql [subst {
			select
				t.name type_name,
				t.ev_class_id,
				f.sort,
				f.disporder,
				f.index_min,
				f.index_max,
				f.index_step,
				f.makeup_step,
				f.end_of_day,
				f.point_price,
				f.commission,
				f.name,
				f.code,
				f.channels,
				f.blurb_buy,
				f.blurb_sell
			from
				tEvType  t,
				tfMktGrp f
			where
				t.ev_type_id = f.ev_type_id and
				f.f_mkt_grp_id = $mkt_grp_id
		}]

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set msort [db_get_col $res 0 sort]

		tpBindString ClassId            [db_get_col $res 0 ev_class_id]
		tpBindString TypeName           [db_get_col $res 0 type_name]
		tpBindString MktGrpName         [db_get_col $res 0 name]
		tpBindString MktGrpCode         [db_get_col $res 0 code]
		tpBindString MktGrpIndexMin     [db_get_col $res 0 index_min]
		tpBindString MktGrpIndexMax     [db_get_col $res 0 index_max]
		tpBindString MktGrpIndexStep    [db_get_col $res 0 index_step]
		tpBindString MktGrpMakeupStep   [db_get_col $res 0 makeup_step]
		tpBindString MktGrpEndOfDay     [db_get_col $res 0 end_of_day]
		tpBindString MktGrpPointPrice   [db_get_col $res 0 point_price]
		tpBindString MktGrpCommission   [db_get_col $res 0 commission]
		tpBindString MktGrpDisporder    [db_get_col $res 0 disporder]
		tpBindString MktGrpBlurbBuy     [db_get_col $res 0 blurb_buy]
		tpBindString MktGrpBlurbSell    [db_get_col $res 0 blurb_sell]

		make_channel_binds [db_get_col $res 0 channels] $channel_mask

		db_close $res

	}

	#
	# Set site variables which control which bits of the template # are played
	#
	tpSetVar     IxMktGrpSort $msort
	tpBindString IxMktGrpSort $msort

	asPlayFile -nocache ix_mkt_grp.html
}


#
# ----------------------------------------------------------------------------
# Update market group
# ----------------------------------------------------------------------------
#
proc do_ix_mkt_grp args {

	set act [reqGetArg SubmitName]

	if {$act == "MktGrpAdd"} {
		do_ix_mkt_grp_add
	} elseif {$act == "MktGrpMod"} {
		do_ix_mkt_grp_upd
	} elseif {$act == "MktGrpDel"} {
		do_ix_mkt_grp_del
	} elseif {$act == "Back"} {
		ADMIN::TYPE::go_type
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_ix_mkt_grp_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMktGrp(
			p_op = 'I',
			p_adminuser = ?,
			p_ev_type_id = ?,
			p_sort = ?,
			p_disporder = ?,
			p_channels = ?,
			p_index_min = ?,
			p_index_max = ?,
			p_index_step = ?,
			p_makeup_step = ?,
			p_end_of_day = ?,
			p_point_price = ?,
			p_commission = ?,
			p_name = ?,
			p_code = ?,
			p_blurb_buy = ?,
			p_blurb_sell = ?
		)
	}]

	set channels [make_channel_str]

	set bad 0

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg TypeId]\
			[reqGetArg IxMktGrpSort]\
			[reqGetArg MktGrpDisporder]\
			$channels\
			[reqGetArg MktGrpIndexMin]\
			[reqGetArg MktGrpIndexMax]\
			[reqGetArg MktGrpIndexStep]\
			[reqGetArg MktGrpMakeupStep]\
			[reqGetArg MktGrpEndOfDay]\
			[reqGetArg MktGrpPointPrice]\
			[reqGetArg MktGrpCommission]\
			[reqGetArg MktGrpName]\
			[reqGetArg MktGrpCode]\
			[reqGetArg MktGrpBlurbBuy]\
			[reqGetArg MktGrpBlurbSell]]} msg]} {
		set bad 1
		err_bind $msg
	} else {
		if {[db_get_nrows $res] != 1} {
			err_bind "Failed to add market (no f_mkt_grp_id retrieved)"
			set bad 1
		} else {
			set mkt_grp_id [db_get_coln $res 0 0]
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
		tpSetVar MarketAddFailed 1
		go_ix_mkt_grp
		return
	}

	inf_commit_tran $DB

	tpSetVar MarketAdded 1

	ADMIN::TYPE::go_type
}

proc do_ix_mkt_grp_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMktGrp(
			p_op = 'U',
			p_adminuser = ?,
			p_f_mkt_grp_id = ?,
			p_sort = ?,
			p_disporder = ?,
			p_channels = ?,
			p_index_min = ?,
			p_index_max = ?,
			p_index_step = ?,
			p_makeup_step = ?,
			p_end_of_day = ?,
			p_point_price = ?,
			p_commission = ?,
			p_name = ?,
			p_code = ?,
			p_blurb_buy = ?,
			p_blurb_sell = ?
		)
	}]

	set channels [make_channel_str]

	set bad 0

	inf_begin_tran $DB

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktGrpId]\
			[reqGetArg IxMktGrpSort]\
			[reqGetArg MktGrpDisporder]\
			$channels\
			[reqGetArg MktGrpIndexMin]\
			[reqGetArg MktGrpIndexMax]\
			[reqGetArg MktGrpIndexStep]\
			[reqGetArg MktGrpMakeupStep]\
			[reqGetArg MktGrpEndOfDay]\
			[reqGetArg MktGrpPointPrice]\
			[reqGetArg MktGrpCommission]\
			[reqGetArg MktGrpName]\
			[reqGetArg MktGrpCode]\
			[reqGetArg MktGrpBlurbBuy]\
			[reqGetArg MktGrpBlurbSell]]} msg]} {
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
		go_ix_mkt_grp
		return
	}

	inf_commit_tran $DB

	tpSetVar MarketUpdated 1

	ADMIN::TYPE::go_type
}

proc do_ix_mkt_grp_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMktGrp(
			p_op = 'D',
			p_adminuser = ?,
			p_f_mkt_grp_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg MktGrpId]]} msg]} {
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
		go_mkt_grp
		return
	}

	ADMIN::TYPE::go_type
}

}
