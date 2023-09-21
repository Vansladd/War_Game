	# ==============================================================
	# $Id: ixmarket.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
	#
	# (C) 2002 Orbis Technology Ltd. All rights reserved.
	# ==============================================================

	namespace eval ADMIN::IXMARKET {

	asSetAct ADMIN::IXMARKET::GoIxMkt      [namespace code go_ix_mkt]
	asSetAct ADMIN::IXMARKET::DoIxMkt      [namespace code do_ix_mkt]


	#
	# ----------------------------------------------------------------------------
	# Add/Update market activator
	# ----------------------------------------------------------------------------
	#
	proc go_ix_mkt args {

		set mkt_id [reqGetArg IxMktId]

		if {$mkt_id == ""} {
			go_ix_mkt_add
		} else {
			go_ix_mkt_upd
		}
	}


	#
	# ----------------------------------------------------------------------------
	# Go to "add new market" page
	# ----------------------------------------------------------------------------
	#
	proc go_ix_mkt_add args {

		global DB

		tpSetVar opAdd 1

		set ev_id        [reqGetArg EvId]
		set f_mkt_grp_id [reqGetArg IxMktGrpId]


		#
		# Get setup information
		#
		set sql [subst {
			select
				c.sort csort,
				e.desc desc,
				e.ev_type_id,
				e.channels
			from
				tEv      e,
				tEvType  t,
				tEvClass c
			where
				e.ev_id = $ev_id and
				e.ev_type_id = t.ev_type_id and
				t.ev_class_id = c.ev_class_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set ev_type_id  [db_get_col $res 0 ev_type_id]
		set csort       [db_get_col $res 0 csort]

		tpBindString EvDesc          [db_get_col $res 0 desc]
		tpBindString ClassSort       $csort
		tpSetVar     ClassSort       $csort
		tpBindString EvId            $ev_id
		tpBindString TypeId          $ev_type_id
		tpBindString IxMktGrpId      $f_mkt_grp_id

		set event_channels [db_get_col $res 0 channels]

		db_close $res


		#
		# Get information about the market we're about to add
		#
		set sql [subst {
			select
				f_mkt_grp_id,
				ev_type_id,
				sort,
				disporder,
				index_min,
				index_max,
				index_step,
				point_price,
				commission,
				makeup_step,
				end_of_day,
				name,
				code,
				channels
			from
				tfMktGrp
			where
				f_mkt_grp_id = $f_mkt_grp_id
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		set mkt_sort     [db_get_col $res 0 sort]
		set mkt_code     [db_get_col $res 0 code]
		set mkt_channels [db_get_col $res 0 channels]

		tpBindString IxMktSort       $mkt_sort
		tpBindString IxMktDisporder  [db_get_col $res 0 disporder]
		tpBindString IxMktIndexMin   [db_get_col $res 0 index_min]
		tpBindString IxMktIndexMax   [db_get_col $res 0 index_max]
		tpBindString IxMktIndexStep  [db_get_col $res 0 index_step]
		tpBindString IxMktPointPrice [db_get_col $res 0 point_price]
		tpBindString IxMktCommission [db_get_col $res 0 commission]
		tpBindString IxMktMakeupStep [db_get_col $res 0 makeup_step]
		tpBindString IxMktEndOfDay   [db_get_col $res 0 end_of_day]
		tpBindString IxMktName       [db_get_col $res 0 name]
		tpBindString IxMktStatus     "C"

		db_close $res

		tpSetVar IxMktSort $mkt_sort
		tpSetVar IxMktStatus "C"


		set chans_offered ""
		for {set i 0} {$i < [string length $event_channels]} {incr i} {
			set c [string range $event_channels $i $i]
			if {[string first $c $mkt_channels]>=0} {
				append chans_offered $c
			}
		}

		make_channel_binds ${chans_offered} $event_channels$mkt_channels

		#
		# tfMkt.code is a string which is used to uniquely identofy a market.
		# The value in tfMKtGrp is a "template" which can contain Tcl variable
		# references which we will interpolate to get a final value for the
		# string. The set of useful interpolations varies by class, so we
		# pass the buck to a class-sort-specific procedure which is defined
		# in the config file
		#
		set codesubproc [OT_CfgGet index.${csort}.codesubproc ""]

		if {$codesubproc == ""} {
			set codesubproc ADMIN::IXMARKET::codesubproc_dflt
		}

		set code [$codesubproc $csort $ev_id $mkt_sort $f_mkt_grp_id $mkt_code]

		tpBindString IxMktCode $code

		# Check whether it is allowed to insert or delete selections.
		# When allow_dd_creation is set to Y, it enables the creating
		# any dilldown items. Such as categories, classes types and
		# markets. and allow_dd_deletion is for deleting items
		if {[ob_control::get allow_dd_deletion] == "Y"} {
			tpSetVar AllowDDDeletion 1
		} else {
			tpSetVar AllowDDDeletion 0
		}
		if {[ob_control::get allow_dd_creation] == "Y"} {
			tpSetVar AllowDDCreation 1
		} else {
			tpSetVar AllowDDCreation 0
		}

	asPlayFile -nocache ix_market.html
}


#
# ----------------------------------------------------------------------------
# Go to index update page
# ----------------------------------------------------------------------------
#
proc go_ix_mkt_upd args {

	global DB

	tpSetVar opAdd 0

	set ix_mkt_id [reqGetArg IxMktId]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString IxMktId  $ix_mkt_id

	#
	# Get current market setup
	#
	set sql [subst {
		select
			c.sort csort,
			c.ev_class_id,
			t.ev_type_id,
			e.ev_id,
			e.desc,
			e.start_time,
			e.channels event_channels,
			m.sort,
			m.name,
			m.code,
			m.status,
			m.displayed,
			m.disporder,
			m.blurb,
			m.index_min,
			m.index_max,
			m.index_step,
			m.point_price,
			m.commission,
			m.result,
			m.makeup,
			m.makeup_step,
			m.end_of_day,
			m.result_conf,
			m.settled,
			m.channels,
			m.f_mkt_grp_id,
			g.channels mkt_channels
		from
			tEvClass     c,
			tEvType      t,
			tEv          e,
			tfMkt        m,
			tfMktGrp     g
		where
			m.f_mkt_id     = $ix_mkt_id     and
			m.ev_id        = e.ev_id        and
			e.ev_type_id   = t.ev_type_id   and
			t.ev_class_id  = c.ev_class_id  and
			m.f_mkt_grp_id = g.f_mkt_grp_id
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	#
	# Build information
	#
	set ev_id          [db_get_col $res 0 ev_id]
	set type_id        [db_get_col $res 0 ev_type_id]
	set mkt_channels   [db_get_col $res 0 mkt_channels]
	set event_channels [db_get_col $res 0 event_channels]
	set channels       [db_get_col $res 0 channels]
	set csort          [db_get_col $res 0 csort]
	set mkt_sort       [db_get_col $res 0 sort]
	set start          [db_get_col $res 0 start_time]
	set makeup         [db_get_col $res 0 makeup]
	set result         [db_get_col $res 0 result]
	set result_conf    [db_get_col $res 0 result_conf]
	set settled        [db_get_col $res 0 settled]

	tpBindString EvId   $ev_id
	tpBindString TypeId $type_id

	make_channel_binds $channels ${mkt_channels}${event_channels}

	tpBindString ClassId             [db_get_col $res 0 ev_class_id]
	tpBindString TypeId              [db_get_col $res 0 ev_type_id]
	tpBindString EvDesc              [db_get_col $res 0 desc]
	tpBindString IxMktSort           $mkt_sort
	tpBindString IxMktName           [db_get_col $res 0 name]
	tpBindString IxMktCode           [db_get_col $res 0 code]
	tpBindString IxMktGrpId          [db_get_col $res 0 f_mkt_grp_id]
	tpBindString IxMktStatus         [db_get_col $res 0 status]
	tpBindString IxMktDisporder      [db_get_col $res 0 disporder]
	tpBindString IxMktBlurb          [db_get_col $res 0 blurb]
	tpBindString IxMktDisplayed      [db_get_col $res 0 displayed]
	tpBindString IxMktIndexMin       [db_get_col $res 0 index_min]
	tpBindString IxMktIndexMax       [db_get_col $res 0 index_max]
	tpBindString IxMktIndexStep      [db_get_col $res 0 index_step]
	tpBindString IxMktPointPrice     [db_get_col $res 0 point_price]
	tpBindString IxMktCommission     [db_get_col $res 0 commission]
	tpBindString IxMktMakeupStep     [db_get_col $res 0 makeup_step]
	tpBindString IxMktEndOfDay       [db_get_col $res 0 end_of_day]
	tpBindString IxMktResult         $result
	tpBindString IxMktMakeup         $makeup


	tpSetVar Confirmed [expr {$result_conf == "Y"}]
	tpSetVar Settled   [expr {$settled == "Y"}]
	tpSetVar ClassSort $csort
	tpSetVar MktSort   $mkt_sort
	tpSetVar ResultSet [expr {($result == "-") ? 0 : 1}]
	tpSetVar IxMktStatus [db_get_col $res 0 status]

	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	if {[string compare $start $now] <= 0} {
		tpSetVar AfterEventStart 1
	} else {
		tpSetVar AfterEventStart 0
	}

	db_close $res

	# Check whether it is allowed to insert or delete selections.
	# When allow_dd_creation is set to Y, it enables the creating
	# any dilldown items. Such as categories, classes types and
	# markets. and allow_dd_deletion is for deleting items
	if {[ob_control::get allow_dd_deletion] == "Y"} {
		tpSetVar AllowDDDeletion 1
	} else {
		tpSetVar AllowDDDeletion 0
	}
	if {[ob_control::get allow_dd_creation] == "Y"} {
		tpSetVar AllowDDCreation 1
	} else {
		tpSetVar AllowDDCreation 0
	}

	asPlayFile -nocache ix_market.html
}


#
# ----------------------------------------------------------------------------
# Add event activator
# ----------------------------------------------------------------------------
#
proc do_ix_mkt args {

	set act [reqGetArg SubmitName]

	if {$act == "IxMktAdd"} {
		do_mkt_add
	} elseif {$act == "IxMktMod"} {
		do_mkt_upd
	} elseif {$act == "IxMktDel"} {
		do_mkt_del
	} elseif {$act == "IxMktClear"} {
		do_mkt_clear
	} elseif {$act == "IxMktSetRes"} {
		do_mkt_set_res
	} elseif {$act == "IxMktConf"} {
		do_mkt_conf_yn Y
	} elseif {$act == "IxMktUnConf"} {
		do_mkt_conf_yn N
	} elseif {$act == "IxMktStl"} {
		do_mkt_stl
	} elseif {$act == "Back"} {
		ADMIN::EVENT::go_ev
	} else {
		error "unexpected market operation SubmitName: $act"
	}
}


proc do_mkt_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMkt(
			p_op = 'I',
			p_adminuser = ?,
			p_ev_id = ?,
			p_f_mkt_grp_id = ?,
			p_sort = ?,
			p_name = ?,
			p_code = ?,
			p_status = ?,
			p_disporder = ?,
			p_blurb = ?,
			p_displayed = ?,
			p_channels = ?,
			p_makeup_step = ?,
			p_end_of_day = ?,
			p_index_min = ?,
			p_index_max = ?,
			p_index_step = ?,
			p_point_price = ?,
			p_commission = ?
		)
	}]

	set channels [make_channel_str]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg EvId]\
			[reqGetArg IxMktGrpId]\
			[reqGetArg IxMktSort]\
			[reqGetArg IxMktName]\
			[reqGetArg IxMktCode]\
			[reqGetArg IxMktStatus]\
			[reqGetArg IxMktDisporder]\
			[reqGetArg IxMktBlurb]\
			[reqGetArg IxMktDisplayed]\
			$channels\
			[reqGetArg IxMktMakeupStep]\
			[reqGetArg IxMktEndOfDay]\
			[reqGetArg IxMktIndexMin]\
			[reqGetArg IxMktIndexMax]\
			[reqGetArg IxMktIndexStep]\
			[reqGetArg IxMktPointPrice]\
			[reqGetArg IxMktCommission]]} msg]} {
		err_bind $msg
		set bad 1
	}

	if {!$bad} {
		set ix_mkt_id [db_get_coln $res 0 0]
	}

	inf_close_stmt $stmt

	if {$bad || [db_get_nrows $res] != 1} {
		#
		# Something went wrong : go back to the event with the form elements
		# reset
		#
		inf_rollback_tran $DB
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ix_mkt_add
		return
	}

	inf_commit_tran $DB

	db_close $res

	#
	# Insertion was OK, go back to the market screen in update mode
	#
#	tpSetVar MktAdded 1

#	go_ix_mkt_upd ix_mkt_id $ix_mkt_id

	ADMIN::EVENT::go_ev_upd ev_id [reqGetArg EvId]
}


proc do_mkt_upd args {

	global DB USERNAME

	set ix_mkt_id [reqGetArg IxMktId]

	set sql [subst {
		execute procedure pfDoMkt(
			p_op = 'U',
			p_adminuser = ?,
			p_f_mkt_id = ?,
			p_sort = ?,
			p_name = ?,
			p_code = ?,
			p_status = ?,
			p_disporder = ?,
			p_blurb = ?,
			p_displayed = ?,
			p_channels = ?,
			p_makeup_step = ?,
			p_end_of_day = ?,
			p_index_min = ?,
			p_index_max = ?,
			p_index_step = ?,
			p_point_price = ?,
			p_commission = ?
		)
	}]

	set channels [make_channel_str]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$ix_mkt_id\
			[reqGetArg IxMktSort]\
			[reqGetArg IxMktName]\
			[reqGetArg IxMktCode]\
			[reqGetArg IxMktStatus]\
			[reqGetArg IxMktDisporder]\
			[reqGetArg IxMktBlurb]\
			[reqGetArg IxMktDisplayed]\
			$channels\
			[reqGetArg IxMktMakeupStep]\
			[reqGetArg IxMktEndOfDay]\
			[reqGetArg IxMktIndexMin]\
			[reqGetArg IxMktIndexMax]\
			[reqGetArg IxMktIndexStep]\
			[reqGetArg IxMktPointPrice]\
			[reqGetArg IxMktCommission]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
	}

	inf_close_stmt $stmt
	catch {db_close $res}

	if {$bad} {
		#
		# Something went wrong : go back to the market with the form elements
		# reset
		#
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_ix_mkt
		return
	}

	ADMIN::EVENT::go_ev
}

proc do_mkt_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMkt(
			p_op = 'D',
			p_adminuser = ?,
			p_f_mkt_id = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg IxMktId]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
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
		ADMIN::EVENT::go_ev
		return
	}

	ADMIN::EVENT::go_ev
}

proc do_mkt_clear {args} {

	global DB USERNAME

	set sql [subst {
		execute procedure pfClearWorking(
			p_adminuser = ?,
			p_f_mkt_id = ?
		)
	}]

	set f_mkt_id [reqGetArg IxMktId]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			$f_mkt_id]} msg]} {
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
		ADMIN::EVENT::go_ev
		return
	}

	msg_bind "cleared all working orders for mkt $f_mkt_id"
	go_ix_mkt_upd
}



#
# ----------------------------------------------------------------------------
# Settle this market's result
# ----------------------------------------------------------------------------
#
proc do_mkt_set_res args {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMktSetRes(
			p_adminuser = ?,
			p_f_mkt_id = ?,
			p_result = ?,
			p_makeup = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg IxMktId]\
			[reqGetArg IxMktResult]\
			[reqGetArg IxMktMakeup]]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
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
		go_ix_mkt
		return
	}

	go_ix_mkt
}

#
# ----------------------------------------------------------------------------
# Confirm/unconfirm this market's result
# ----------------------------------------------------------------------------
#
proc do_mkt_conf_yn conf {

	global DB USERNAME

	set sql [subst {
		execute procedure pfDoMktConfRes(
			p_adminuser = ?,
			p_f_mkt_id = ?,
			p_result_conf = ?
		)
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	inf_begin_tran $DB

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg IxMktId]\
			$conf]} msg]} {
		err_bind $msg
		set bad 1
		inf_rollback_tran $DB
	} else {
		inf_commit_tran $DB
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
		ADMIN::EVENT::go_ix_mkt
		return
	}

	go_ix_mkt

}

#
# ----------------------------------------------------------------------------
# Settle this market
# ----------------------------------------------------------------------------
#
proc do_mkt_stl args {

	global USERNAME

	tpSetVar StlObj   index
	tpSetVar StlObjId [reqGetArg IxMktId]
	tpSetVar StlDoIt  [reqGetArg DoSettle]

	asPlayFile -nocache settlement.html
}


proc stl_settle_index {f_mkt_id} {

	global DB USERNAME

	set sql_stl [subst {
		execute procedure pfSettleMkt (
			p_adminuser = ?,
			p_f_mkt_id = ?,
			p_do_tran = 'Y'
		)
	}]

	set sql_mark [subst {
		execute procedure pSetSettled (
			p_adminuser = ?,
			p_obj_type = 'X',
			p_obj_id = ?
		)
	}]

	set sql_depth [subst {
		execute procedure pfMktDepth (
			p_f_mkt_id = ?
		)
	}]


	set c [catch {
		set stmt [inf_prep_sql $DB $sql_stl]
		set res  [inf_exec_stmt $stmt $USERNAME $f_mkt_id]
		inf_close_stmt $stmt
		db_close $res
	} msg]

	if {$c} {
		ADMIN::SETTLE::log 1 "Failed to Settle: pfSettleMkt returns: $msg"
		return 0
	}

	set c [catch {
		set stmt [inf_prep_sql $DB $sql_mark]
		set res  [inf_exec_stmt $stmt $USERNAME $f_mkt_id]
		inf_close_stmt $stmt
		db_close $res
	} msg]

	if {$c} {
		ADMIN::SETTLE::log 1 "Failed to Settle: pfSetSettled returns: $msg"
		return 0
	}

	# call the depth procedure to clean up the mkt depth
	# delta table. not strictly neccessary, but good
	# for the sake of tidyness

	set c [catch {
		set stmt [inf_prep_sql $DB $sql_depth]
		set res  [inf_exec_stmt $stmt $f_mkt_id]
		inf_close_stmt $stmt
		db_close $res
	} msg]

	if {$c} {
		ADMIN::SETTLE::log 1 "Market settled, but depth error: $msg"
		return 0
	}
	return 1

}


#
# ----------------------------------------------------------------------------
# Re-Settle this market
# ----------------------------------------------------------------------------
#
proc do_mkt_restl args {

	global USERNAME

	if {![op_allowed ReSettle]} {
		err_bind "You don't have permission to re-settle markets"
		do_mkt_upd
		return
	} else {
		do_mkt_stl
	}
}


#
# ----------------------------------------------------------------------------
# Default code substitution procedure
# ----------------------------------------------------------------------------
#
proc codesubproc_dflt {csort ev_id ix_mkt_sort f_mkt_grp_id code} {

	set sql [subst {
		select
			e.start_time,
			e.desc,
			e.sort
		from
			tEv e
		where
			e.ev_id = $ev_id
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set time      [db_get_col $res 0 start_time]
	set sort      [db_get_col $res 0 sort]

	foreach n {YYYY MM DD hh mm ss} v [split $time " :-"] {
		set $n $v
	}

	set YY [string range $YYYY 2 3]

	return [subst $code]
}


}


#
# ----------------------------------------------------------------------------
# Footy-specific code substitution procedure
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::IXMARKET::FB {

proc codesubst {csort ev_id ix_mkt_sort f_mkt_grp_id code} {

	set sql [subst {
		select
			e.start_time,
			e.desc,
			e.sort,
			th.code home_code,
			ta.code away_code
		from
			tEv e,
			outer (tTeamEvent teh, tTeam th),
			outer (tTeamEvent tea, tTeam ta)
		where
			e.ev_id = $ev_id and
			e.ev_id = teh.ev_id and
			teh.side = 'H' and
			teh.team_id = th.team_id and
			e.ev_id = tea.ev_id and
			tea.side = 'A' and
			tea.team_id = ta.team_id
	}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set time      [db_get_col $res 0 start_time]
	set sort      [db_get_col $res 0 sort]
	set home_code [db_get_col $res 0 home_code]
	set away_code [db_get_col $res 0 away_code]

	foreach n {YYYY MM DD hh mm ss} v [split $time " :-"] {
		set $n $v
	}

	set YY [string range $YYYY 2 3]

	set HOME $home_code
	set AWAY $away_code

	return [subst $code]
}

}
