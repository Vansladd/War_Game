# ==============================================================
# $Id: tv_channels.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::TV {

asSetAct ADMIN::TV::GoTVChannelList  [namespace code go_tvchannel_list]
asSetAct ADMIN::TV::GoTVChannel      [namespace code go_tvchannel]
asSetAct ADMIN::TV::DoTVChannel      [namespace code do_tvchannel]

variable SQL

set SQL(get_tvchannel) {
	select
		tv_channel_id,
		channel_desc,
		channel_title,
		channel_alt,
		graphic_url,
		graphic_height,
		graphic_width,
		valid_views,
		is_key
	from
		tTVChannel
	where
		tv_channel_id = ?
}

set SQL(get_tvchannels) {
	select
		tv_channel_id,
		channel_desc,
		channel_title,
		channel_alt,
		graphic_url,
		graphic_height,
		graphic_width,
		valid_views
	from
		tTVChannel
	order by channel_desc
}

set SQL(get_views) {
	select
		view,
		sort
	from
		tView
	where
		id = ? and sort = ?
}

#
# ----------------------------------------------------------------------------
# Go to TV Channel list
# ----------------------------------------------------------------------------
#
proc go_tvchannel_list args {

	global DB TVCHANNEL
	variable SQL

	set stmt [inf_prep_sql $DB $SQL(get_tvchannels)]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	for {set i 0} {$i < [db_get_nrows $res]} {incr i} {
		foreach c {
			tv_channel_id
			channel_desc
			channel_title
			channel_alt
			graphic_url
			graphic_height
			graphic_width
			valid_views
		} {
			set TVCHANNEL($i,$c) [db_get_col $res $i $c]
		}
	}

	tpSetVar NumTVChannels [db_get_nrows $res]

	db_close $res

	tpBindVar ChannelID         TVCHANNEL  tv_channel_id   channel_idx
	tpBindVar TVChannelDesc     TVCHANNEL  channel_desc    channel_idx
	tpBindVar TVChannelTitle    TVCHANNEL  channel_title   channel_idx

	asPlayFile -nocache tv_channel_list.html
}


#
# ----------------------------------------------------------------------------
# Go to single tv channel add/update
# ----------------------------------------------------------------------------
#
proc go_tvchannel args {

	global DB
	variable SQL

	set channel_id [reqGetArg ChannelID]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString ChannelID $channel_id

	if {$channel_id == ""} {

		tpSetVar opAdd 1

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			make_view_binds "" - 1
		}

	} else {

		tpSetVar opAdd 0

		#
		# Get information
		#
		set stmt [inf_prep_sql $DB $SQL(get_tvchannel)]
		set res  [inf_exec_stmt $stmt $channel_id]

		inf_close_stmt $stmt

		tpBindString TVChannelDesc     [db_get_col $res 0 channel_desc]
		tpBindString TVChannelTitle    [db_get_col $res 0 channel_title]
		tpBindString TVChannelAlt      [db_get_col $res 0 channel_alt]
		tpBindString TVChannelGURL     [db_get_col $res 0 graphic_url]
		tpBindString TVChannelGHeight  [db_get_col $res 0 graphic_height]
		tpBindString TVChannelGWidth   [db_get_col $res 0 graphic_width]
		tpBindString TVChannelIsKey    [db_get_col $res 0 is_key]

		db_close $res

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			#
			# Build up the View array
			#
			set stmt [inf_prep_sql $DB $SQL(get_views)]
			set rs   [inf_exec_stmt $stmt $channel_id TVCHANNEL]
			inf_close_stmt $stmt

			set view_list     [list]

			for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
				lappend view_list [db_get_col $rs $i view]
			}

			make_view_binds $view_list - 0

			db_close $rs
		}
	}

	asPlayFile -nocache tv_channel.html
}


# ----------------------------------------------------------------------------
# Do TV Channel insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_tvchannel args {

	set act [reqGetArg SubmitName]


	if {$act == "TVChannelAdd"} {
		do_tvchannel_add
	} elseif {$act == "TVChannelMod"} {
		do_tvchannel_upd
	} elseif {$act == "TVChannelDel"} {
		do_tvchannel_del
	} elseif {$act == "Back"} {
		go_tvchannel_list
		return
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_tvchannel_add args {

	global DB USERNAME

	set sql [subst {
			execute procedure pInsTVChannel(
			p_adminuser       = ?,
			p_channel_desc    = ?,
			p_channel_title   = ?,
			p_channel_alt     = ?,
			p_graphic_url     = ?,
			p_graphic_height  = ?,
			p_graphic_width   = ?,
			p_valid_views     = ?,
			p_is_key          = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0
	set is_key [expr {([reqGetArg TVChannelIsKey] == "")?"N":[reqGetArg TVChannelIsKey]}]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg TVChannelDesc]\
			[reqGetArg TVChannelTitle]\
			[reqGetArg TVChannelAlt]\
			[reqGetArg TVChannelGURL]\
			[reqGetArg TVChannelGHeight]\
			[reqGetArg TVChannelGWidth]\
			""\
			$is_key\
		]

		set channel_id [db_get_coln $res 0 0]
		reqSetArg channel_id $channel_id
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	catch {db_close $res}

	# Add Views
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad !=1} {
		set upd_view [ADMIN::VIEWS::upd_view TVCHANNEL $channel_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			go_tvchannel
			return
		}
	}

	go_tvchannel_list
}


proc do_tvchannel_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdTVChannel(
			p_adminuser       = ?,
			p_tv_channel_id   = ?,
			p_channel_desc    = ?,
			p_channel_title   = ?,
			p_channel_alt     = ?,
			p_graphic_url     = ?,
			p_graphic_height  = ?,
			p_graphic_width   = ?,
			p_valid_views     = ?,
			p_is_key          = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0
	set is_key [expr {([reqGetArg TVChannelIsKey] == "")?"N":[reqGetArg TVChannelIsKey]}]

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg ChannelID]\
			[reqGetArg TVChannelDesc]\
			[reqGetArg TVChannelTitle]\
			[reqGetArg TVChannelAlt]\
			[reqGetArg TVChannelGURL]\
			[reqGetArg TVChannelGHeight]\
			[reqGetArg TVChannelGWidth]\
			""\
			$is_key\
		]
	} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	# Update Views
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $bad !=1} {
		set upd_view [ADMIN::VIEWS::upd_view TVCHANNEL [reqGetArg ChannelID]]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_tvchannel
		return
	}

	go_tvchannel_list
}

proc do_tvchannel_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelTVChannel(
			p_adminuser     = ?,
			p_tv_channel_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg ChannelID]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	# Delete the Views!
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set del_view [ADMIN::VIEWS::del_view TVCHANNEL [reqGetArg ChannelID]]
		if {[lindex $del_view 0]} {
			err_bind [lindex $del_view 1]
			set bad 1
		}
	}

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_tvchannel
		return
	}

	go_tvchannel_list
}
}
