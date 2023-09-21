# ==============================================================
# $Id: sport.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================
#
# Define Sports
#
# Create, update, and delete Sports
#
# A Sport can be either a Category or a Class, a Sport is typically
# used along with definitions of collections that belong to it.
#
#

namespace eval ADMIN::SPORT {

asSetAct ADMIN::SPORT::GoSportList          [namespace code go_sport_list]
asSetAct ADMIN::SPORT::GoSport              [namespace code go_sport]
asSetAct ADMIN::SPORT::DoSport              [namespace code do_sport]
asSetAct ADMIN::SPORT::DelSport             [namespace code del_sport]
asSetAct ADMIN::SPORT::GoSportView          [namespace code go_sport_view]
asSetAct ADMIN::SPORT::DoSportView          [namespace code do_sport_view]
asSetAct ADMIN::SPORT::DoMktLink            [namespace code do_mkt_link]
asSetAct ADMIN::SPORT::GoSportMenuItem      [namespace code go_sport_menu_item]
asSetAct ADMIN::SPORT::DoSportMenuItem      [namespace code do_sport_menu_item]
asSetAct ADMIN::SPORT::DelSportMenuItem     [namespace code del_sport_menu_item]
asSetAct ADMIN::SPORT::AddMenuLangItem      [namespace code add_menu_view_item]
asSetAct ADMIN::SPORT::DoSportMenuViewItem  [namespace code do_sport_menu_view_item]


#
# ----------------------------------------------------------------------------
# Generate list of sports
# ----------------------------------------------------------------------------
#
proc go_sport_list args {

	variable SPORT
	unset -nocomplain SPORT

	set sort [reqGetArg order]

	switch -exact -- $sort {
		"y" {
			set set_order "category"
		}
		"c" {
			set set_order "class"
		}
		default {
			set set_order "s.name"
		}
	}

	set sql [subst {
		select
			s.sport_id,
			s.name,
			c.name as class,
			y.name as category,
			s.ob_id,
			s.ob_level
		from
			tSport     s,
			tEvClass    c,
			tEvCategory y
		where
			s.ob_level = "c"           and
			s.ob_id    = c.ev_class_id and
			c.category = y.category
		union

		select
			s.sport_id,
			s.name,
			"(all)" as class,
			y.name  as category,
			s.ob_id,
			s.ob_level
		from
			tSport      s,
			tEvCategory y
		where
			s.ob_level = "y"    and
			s.ob_id    = y.ev_category_id
		order by
			%s
	}]

	set sql [format $sql ${set_order}]

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumSports $rows

	for {set i 0} {$i < $rows} {incr i} {

		set SPORT($i,sport_id)      [db_get_col $res $i sport_id]
		set SPORT($i,name)          [db_get_col $res $i name]
		set SPORT($i,category)      [db_get_col $res $i category]
		set SPORT($i,class)         [db_get_col $res $i class]
		set SPORT($i,ob_level)      [db_get_col $res $i ob_level]
		set SPORT($i,ob_id)         [db_get_col $res $i ob_id]

		if { $SPORT($i,ob_level) == "c"} {
			set SPORT($i,dd_level) $SPORT($i,class)
		} else {
			set SPORT($i,dd_level) $SPORT($i,category)
		}
	}

	set cns [namespace current]

	tpBindVar sportId       ${cns}::SPORT sport_id     sport_idx
	tpBindVar sportName     ${cns}::SPORT name         sport_idx
	tpBindVar sportClass    ${cns}::SPORT class        sport_idx
	tpBindVar sportCat      ${cns}::SPORT category     sport_idx
	tpBindVar sportDDLevel  ${cns}::SPORT dd_level     sport_idx
	tpBindVar sportObLevel  ${cns}::SPORT ob_level     sport_idx
	tpBindVar sportObId     ${cns}::SPORT ob_id        sport_idx

	db_close $res

	# Bind view dropdown variables
	_bind_view_dropdown
	tpBindString SportView [ob_control::get default_view]

	# Bind the current menu items
	_bind_menu_items

	asPlayFile sport_list.html
}


#
# ----------------------------------------------------------------------------
# Go to sport add/update page
# ----------------------------------------------------------------------------
#
proc go_sport args {

	set sportId [reqGetArg SportId]
	tpSetVar allowDDLevelUpd 1

	if { $sportId != "" } {
		# Find out if the sport is used by a collection, so that we
		# don't allow an update of its level class/category.
		set sql [subst {
			select
				count(collection_id) as num
			from
				tCollection
			where sport_id = %s
		}]

		set sql [format $sql ${sportId}]

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		if { [db_get_col $res 0 num] != 0 } {
			tpSetVar allowDDLevelUpd 0
		}
		db_close $res
	}

	tpSetVar sport_id  [ set sport_id [reqGetArg SportId]]

	# We need to bind the market link information
	if { $sport_id != "" } {
		# Bind the markets for this sport
		bind_market_link $sport_id
		# Bind the dropdown values for this sport
		bind_markets $sport_id
	}

	tpBindString SportName     [reqGetArg SportName]
	tpBindString SportDDLevel  [reqGetArg SportDDLevel]
	tpBindString SportObLevel  [reqGetArg SportObLevel]
	tpBindString SportObId     [reqGetArg SportObId]

	# Play the template
	asPlayFile sport_add_upd.html
}



#
# ----------------------------------------------------------------------------
# Add/Update Sport
# ----------------------------------------------------------------------------
#
proc do_sport args {

	set act \
		[ob_chk::get_arg SubmitName -on_err "" {RE -args {^[A-Za-z]+$}}]

	switch -exact $act {
		"GotoAdd"             { go_sport }
		"SportAddUpd"         { do_sport_add_upd }
		"Back"                { go_sport_list }
		"GoToView"            { go_sport_view }
		"DoSportViewUpdate"   { do_sport_view }
		"GoMktLink"           { go_mkt_link }
		"DoMktLink"           -
		"DelMktLink"          { do_mkt_link }
		default               { error {do_sport ERR Unexpected SubmitName: $act} }
	}

}



#
# ----------------------------------------------------------------------------
# Delete sports
# ----------------------------------------------------------------------------
#
proc del_sport args {

	set delSportList [reqGetArg delSportList]

	if { $delSportList != ""} {

		# Remove any training commas
		if { [ string range $delSportList end end] == "," } {
			set delSportList [string range $delSportList 0 end-1]
		}

		set sql [subst {
			delete
			from tSport
			where
				sport_id in (%s)
		}]

		set sql [format $sql ${delSportList}]

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {inf_exec_stmt $stmt } msg]} {
				ob::log::write ERROR {ERROR deleting \
				sport : $msg}

				inf_close_stmt $stmt
				err_bind $msg
				go_sport_list
				return

		}

		catch {inf_close_stmt $stmt}
	}

	go_sport_list
}



#
# ----------------------------------------------------------------------------
# Add/Update Sport depending on whether a sport_id is being passed
# ----------------------------------------------------------------------------
#
proc do_sport_add_upd args {

	set sport_id        [reqGetArg SportId]
	set sport_name      [reqGetArg SportName]
	set sport_ob_level  [reqGetArg SportObLevel]
	set sport_ob_id     [reqGetArg SportObId]

	if { $sport_id == ""} {
		# This is a new Sport entry that we need to add
		set sql "execute procedure pInsSport(?,?,?);"

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt $sport_name $sport_ob_id $sport_ob_level]

	} else {
		# We need to update an existing entry
		set sql "update tsport set name = ?, ob_id = ?, ob_level = ? where sport_id = ? "

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt $sport_name $sport_ob_id \
			$sport_ob_level $sport_id]
	}

	inf_close_stmt $stmt
	db_close $res

	go_sport_list
}



#
# Display config for all sports for a particular view (sport_view)
#
proc go_sport_view args {
	global DB

	variable SPORT_VIEW
	unset -nocomplain SPORT_VIEW

	# Check arguments
	set sport_sort \
		[ob_chk::get_arg sport_sort -on_err "2" {RE -args {^[2-6]$}}]

	set sport_view [ob_chk::get_arg sport_view -on_err "" {ALNUM}]

	# Defaults
	if { $sport_sort== "" } { set sport_sort 2 }
	if { $sport_view == "" } { set sport_view [ob_control::get default_view] }

	set stmt [inf_prep_sql $DB [format [subst {
		select
			s.sport_id,
			s.name as sport_name,
			d.ignore_home,
			v1.disporder as prematch_disp,
			v2.disporder as inplay_disp,
			v3.disporder as nav_disp
		from
			tSport s,
			outer tSportDispCfg d,
			outer tView v1,
			outer tView v2,
			outer tView v3
		where
			d.view = '%s'
			and d.sport_id = s.sport_id
			and v1.view = '%s'
			and v2.view = '%s'
			and v3.view = '%s'
			and v1.id = s.sport_id
			and v1.sort = "SPT_PRE"
			and v2.id = s.sport_id
			and v2.sort = "SPT_INPLAY"
			and v3.id = s.sport_id
			and v3.sort = "SPT_NAV"
		order by
			%s
		}] $sport_view $sport_view $sport_view $sport_view $sport_sort]]

	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar NumSports [set rows [db_get_nrows $res]]
	set id_list [list]

	for {set r 0} {$r < $rows} {incr r} {
		set SPORT_VIEW($r,sport_id)       [db_get_col $res $r sport_id]
		set SPORT_VIEW($r,sport_name)     [db_get_col $res $r sport_name]
		set SPORT_VIEW($r,prematch_disp)  [db_get_col $res $r prematch_disp]
		set SPORT_VIEW($r,inplay_disp)    [db_get_col $res $r inplay_disp]
		set SPORT_VIEW($r,nav_disp)       [db_get_col $res $r nav_disp]
		set SPORT_VIEW($r,ignore_home)    [db_get_col $res $r ignore_home]

		lappend id_list $SPORT_VIEW($r,sport_id)
	}

	db_close $res

	set cns [namespace current]

	tpBindVar SportId      ${cns}::SPORT_VIEW  sport_id       sport_idx
	tpBindVar SportName    ${cns}::SPORT_VIEW  sport_name     sport_idx
	tpBindVar PrematchDisp ${cns}::SPORT_VIEW  prematch_disp  sport_idx
	tpBindVar InplayDisp   ${cns}::SPORT_VIEW  inplay_disp    sport_idx
	tpBindVar NavDisp      ${cns}::SPORT_VIEW  nav_disp       sport_idx
	tpBindVar IgnoreHome   ${cns}::SPORT_VIEW  ignore_home    sport_idx

	tpBindString SportView $sport_view
	tpBindString IdList    [join $id_list { }]

	# Bind Menu Items specific to language
	_bind_menu_view_items $sport_view

	# Bind View Dropdown variables
	_bind_view_dropdown $sport_view

	GC::mark SPORT_VIEW

	asPlayFile sport_view_list.html
}


#
# Update config for sports for a particular view (sport_view)
#
proc do_sport_view args {

	global DB

	set ignore_home    ""
	set prematch_disp  ""
	set inplay_disp    ""
	set nav_disp       ""

	# The list of id to be updated
	set id_list [ob_chk::get_arg id_list -on_err "" {RE -args {^[[0-9 -]+$}}]

	set view [ob_chk::get_arg sport_view -on_err "" {ALNUM}]

	# Prepare the select query
	set stmt_get_existing [inf_prep_sql $DB {
		select
			s.sport_id,
			v1.disporder as prematch_disp,
			v2.disporder as inplay_disp,
			v3.disporder as nav_disp,
			sd.ignore_home
		from
			tSport              s,
			outer tSportDispCfg sd,
			outer tView         v1,
			outer tView         v2,
			outer tView         v3
		where
			v1.id = s.sport_id
			and v1.view = ?
			and v1.sort = "SPT_PRE"
			and v2.id = s.sport_id
			and v2.view = ?
			and v2.sort = "SPT_INPLAY"
			and sd.view = ?
			and sd.sport_id = s.sport_id
			and v3.id = s.sport_id
			and v3.view = ?
			and v3.sort = "SPT_NAV"
	}]

	# Prepare queries
	set stmt_upd_dispcfg [inf_prep_sql $DB {
		update
			tSportDispCfg
		set
			ignore_home   = ?
		where
			sport_id = ? and
			view     = ?
	}]
	set stmt_ins_dispcfg [inf_prep_sql $DB {
		insert into
			tSportDispCfg (ignore_home, sport_id, view)
		values (?, ?, ?)
	}]

	set stmt_upd_view [inf_prep_sql $DB {
		update
			tView
		set
			disporder = ?
		where
			id = ? and
			sort = ? and
			view = ?
	}]

	set stmt_ins_view [inf_prep_sql $DB {
		insert into
			tView (disporder, id, sort, view)
		values (?, ?, ?, ?)
	}]

	set stmt_del_view [inf_prep_sql $DB {
		delete from
			tview
		where
			id       = ?
			and sort = ?
			and view = ?
	}]

	# Views may not exist, so we need to check if we're doing upd or ins
	set res  [inf_exec_stmt $stmt_get_existing $view $view $view $view]

	inf_close_stmt $stmt_get_existing

	set nrows [db_get_nrows $res]

	array set EXISTING_CFG [list]

	for {set r 0} {$r < $nrows} {incr r} {
		set id   [db_get_col $res $r sport_id]

		set EXISTING_CFG($id,prematch_disp) [db_get_col $res $r prematch_disp]
		set EXISTING_CFG($id,inplay_disp)   [db_get_col $res $r inplay_disp]
		set EXISTING_CFG($id,ignore_home)   [db_get_col $res $r ignore_home]
		set EXISTING_CFG($id,nav_disp)      [db_get_col $res $r nav_disp]
	}
	db_close $res

	# Transactional
	inf_begin_tran $DB

	foreach id [split $id_list { }] {

		# Validate and grab the arguments
		set nav_disp \
			[ob_chk::get_arg nav_disp_$id -on_err 0 INT]

		set inplay_disp \
			[ob_chk::get_arg inplay_disp_$id -on_err 0 INT]
		set prematch_disp \
		  [ob_chk::get_arg prematch_disp_$id -on_err 0 INT]
		set ignore_home \
			[ob_chk::get_arg ignore_home_$id -on_err "N" {EXACT -args {Y N}}]

		# Execute statements
		# delete views if they're empty strings

		if {$EXISTING_CFG($id,prematch_disp) != ""} {
			if {$prematch_disp == ""} {
				# delete
				inf_exec_stmt $stmt_del_view $id "SPT_PRE" $view
			} elseif {$prematch_disp != $EXISTING_CFG($id,prematch_disp)} {
				# update
				inf_exec_stmt $stmt_upd_view $prematch_disp $id "SPT_PRE" $view
			}
		} else {
			if {$prematch_disp != ""} {
				# insert
				inf_exec_stmt $stmt_ins_view $prematch_disp $id "SPT_PRE" $view
			}
		}

		if {$EXISTING_CFG($id,inplay_disp) != ""} {
			if {$inplay_disp == ""} {
				# delete
				inf_exec_stmt $stmt_del_view $id "SPT_INPLAY" $view
			} elseif {$inplay_disp != $EXISTING_CFG($id,inplay_disp)} {
				# update
				inf_exec_stmt $stmt_upd_view $inplay_disp $id "SPT_INPLAY" $view
			}
		} else {
			if {$inplay_disp != ""} {
				# insert
				inf_exec_stmt $stmt_ins_view $inplay_disp $id "SPT_INPLAY" $view
			}
		}

		if {$EXISTING_CFG($id,nav_disp) != ""} {
			if {$nav_disp == ""} {
				# delete
				inf_exec_stmt $stmt_del_view $id "SPT_NAV" $view
			} elseif {$nav_disp != $EXISTING_CFG($id,nav_disp)} {
				# update
				inf_exec_stmt $stmt_upd_view $nav_disp $id "SPT_NAV" $view
			}
		} else {
			if {$nav_disp != ""} {
				# insert
				inf_exec_stmt $stmt_ins_view $nav_disp $id "SPT_NAV" $view
			}
		}

		if {$EXISTING_CFG($id,ignore_home) != ""} {
			if {$ignore_home != $EXISTING_CFG($id,ignore_home)} {
				# update
				inf_exec_stmt $stmt_upd_dispcfg $ignore_home $id $view
			}
		} else {
			# defaults to N so only bother inserting if it's Y
			if {$ignore_home == "Y"} {
				# insert
				inf_exec_stmt $stmt_ins_dispcfg $ignore_home $id $view
			}
		}

	}

	# Commit
	inf_commit_tran $DB

	# Cleanup
	inf_close_stmt $stmt_upd_dispcfg
	inf_close_stmt $stmt_upd_view

	go_sport_view

}



#
# ----------------------------------------------------------------------------
# bind the market linking data
# ----------------------------------------------------------------------------
#
proc bind_market_link { {sport_id -1} } {

	global DB

	variable MKT_LINK
	unset -nocomplain MKT_LINK

	ob_log::write DEBUG {Binding Market Link info}

	set stmt [inf_prep_sql $DB {
		select
			link_id,
			mkt_master,
			mkt_slave
		from
			tSportMktLink
		where
			sport_id = ?
		order by
			mkt_master
		}]

	set res  [inf_exec_stmt $stmt $sport_id]

	tpSetVar NumLinks [set rows [db_get_nrows $res]]

	inf_close_stmt $stmt

	set link_id_list [list]

	for {set r 0} {$r < $rows} {incr r} {
		set MKT_LINK($r,link_id)        [db_get_col $res $r link_id]
		set MKT_LINK($r,mkt_master)     [db_get_col $res $r mkt_master]
		set MKT_LINK($r,mkt_slave)      [db_get_col $res $r mkt_slave]

		if {$MKT_LINK($r,mkt_master) != $MKT_LINK($r,mkt_slave)} {
			lappend link_id_list $MKT_LINK($r,link_id)
		}
	}

	db_close $res

	set cns [namespace current]

	tpBindVar LinkId      ${cns}::MKT_LINK  link_id     mkt_idx
	tpBindVar MktMaster   ${cns}::MKT_LINK  mkt_master  mkt_idx
	tpBindVar MktSlave    ${cns}::MKT_LINK  mkt_slave   mkt_idx

	tpBindString ExistingLinks  [join $link_id_list { }]

	GC::mark MKT_LINK

}

#
# ----------------------------------------------------------------------------
# bind all the markets
# ----------------------------------------------------------------------------
#
proc bind_markets { {sport_id -1} } {

	global DB
	variable MAS_MKTS
	unset -nocomplain MAS_MKTS
	variable SLV_MKTS
	unset -nocomplain SLV_MKTS

	# Master markets query

	# We search for all those markets for the sport where
	#  - we don't have that market name in the slave column
	#  - UNLESS we have it but the row is the master row (master = slave)
	set mas_sql [ subst {
		select distinct
			o.name           as mkt_name
		from
			tSport       s,
			tEvCategory  y,
			tEvClass     c,
			tEvType      t,
			tEvOcGrp     o
		where
			s.sport_id = ?                    and
			y.category    = c.category        and
			c.ev_class_id = t.ev_class_id     and
			o.ev_type_id  = t.ev_type_id      and
			(
				(s.ob_id      = y.ev_category_id  and
				s.ob_level   = 'y')
			or
				(s.ob_id      = c.ev_class_id     and
				s.ob_level   = 'c')
			)
			and
			(
				(not exists
					(
					select
						1
					from
						tSportMktLink m
					where
						m.sport_id = ? and
						m.mkt_slave = o.name
					)
				) or exists
					(
				select
					1
				from
					tSportMktLink m
				where
					m.sport_id = ? and
					m.mkt_slave = m.mkt_master
					and m.mkt_slave = o.name
				)
			)
	}]

	# Slave markets query
	# Just take out all the markets that don't appear as a slave
	# (this include the master as the master row has master = slave)
	set slv_sql [ subst {
		select distinct
			o.name           as mkt_name
		from
			tSport       s,
			tEvCategory  y,
			tEvClass     c,
			tEvType      t,
			tEvOcGrp     o
		where
			s.sport_id = ?                    and
			y.category    = c.category        and
			c.ev_class_id = t.ev_class_id     and
			o.ev_type_id  = t.ev_type_id      and
			(
			(s.ob_id      = y.ev_category_id  and
			s.ob_level   = 'y'
			)
			or
			(s.ob_id      = c.ev_class_id     and
			s.ob_level   = 'c'
			)
			)                                 and
			not exists
			(
				select
					1
				from
					tSportMktLink m
				where
					m.sport_id = ? and
					m.mkt_slave = o.name
			)
			order by
				o.name asc
	}]

	set stmt     [inf_prep_sql $DB $mas_sql ]
	set rs_mas   [inf_exec_stmt $stmt $sport_id $sport_id $sport_id]
	inf_close_stmt $stmt

	array set MAS_MKTS [list]

	for {set r 0} {$r < [db_get_nrows $rs_mas]} {incr r} {
		set MAS_MKTS($r,mkt_name) [db_get_col $rs_mas $r mkt_name]
	}

	set cns [namespace current]

	tpSetVar NumberMasMarketNames [db_get_nrows $rs_mas]

	tpBindVar   MasMktName      ${cns}::MAS_MKTS  mkt_name    MAS_MKTS_idx

	db_close $rs_mas

	set stmt     [inf_prep_sql $DB $slv_sql ]
	set rs_slv   [inf_exec_stmt $stmt $sport_id $sport_id]
	inf_close_stmt $stmt

	array set MAS_MKTS [list]

	for {set s 0} {$s < [db_get_nrows $rs_slv]} {incr s} {
		set SLV_MKTS($s,mkt_name) [db_get_col $rs_slv $s mkt_name]
	}

	tpSetVar NumberSlvMarketNames [db_get_nrows $rs_slv]
	tpBindVar   SlvMktName      ${cns}::SLV_MKTS  mkt_name    SLV_MKTS_idx

	db_close $rs_slv

	GC::mark MAS_MKTS
	GC::mark SLV_MKTS

}

#
# ----------------------------------------------------------------------------
# Action the market linking page functions
# TODO: All of this is not very secure ... would need more input checking
# ----------------------------------------------------------------------------
#
proc do_mkt_link {} {

	global DB

	set submit_name    [reqGetArg SubmitName]
	set curr_sport     [reqGetArg SportId]
	set to_delete_list [split [reqGetArg ToDelete] { }]

	switch -exact $submit_name {

	"DEL" {

		# Is there anything to delete
		if { [llength $to_delete_list] > 0 } {

			set del_sql [inf_prep_sql $DB {
				execute procedure pDelMktMapping (?,?)
			}]

			# Transactional
			inf_begin_tran $DB

			foreach to_del $to_delete_list {
				inf_exec_stmt $del_sql $curr_sport $to_del
			}

			# Cleanup
			inf_close_stmt $del_sql

			# Commit
			inf_commit_tran $DB

		} else {
			error {do_mkt_link : Delete request with no parameters}
			}
		}

	"ADD" {

		set master_name [reqGetArg SelectedMaster]
		set separator   [reqGetArg Separator]
		set has_master  0

		# Fetch the single market names
		set slave_names [split [reqGetArg SelectedSlave] '$separator']

		set ins_sql [inf_prep_sql $DB {
			insert into
				tSportMktLink
			(sport_id,mkt_master,mkt_slave)
				values
			(?,?,?)
		}]

		set check_master_sql [inf_prep_sql $DB {
			select
				1
			from
				tSportMktLink
			where
				mkt_master = ? and
				mkt_slave = mkt_master
		}]

		set rs [inf_exec_stmt $check_master_sql $master_name]
		inf_close_stmt $check_master_sql

		set has_master [db_get_nrows $rs]

		ob_log::write DEV {Has master? $has_master}
		db_close $rs

		# Transactional
		inf_begin_tran $DB

		foreach curr_slv $slave_names {

			# Do we already have the master? If so don't create it again
			# to avoid constraint violation
			if { $curr_slv == $master_name && $has_master} {
				 continue
			} else {
				inf_exec_stmt $ins_sql $curr_sport $master_name $curr_slv
			}
		}

		# Cleanup
		inf_close_stmt $ins_sql

		# Commit
		inf_commit_tran $DB

		}
	}

	# Rebind the required values for the page
	tpBindString SportName     [reqGetArg SportName]
	tpBindString SportDDLevel  [reqGetArg SportDDLevel]
	tpBindString SportObLevel  [reqGetArg SportObLevel]
	tpBindString SportObId     [reqGetArg SportObId]

	go_sport

}



#==============================================================================
#
# _bind_sports: Bind Up the sports information for the dropdown
#
proc _bind_sports { {sport_sel -1} } {

	global DB
	variable SPORTS
	unset -nocomplain SPORTS

	set stmt [inf_prep_sql $DB {
		select
			sport_id,
			name,
			ob_level,
			ob_id
		from
			tSport
		order by
			name;
	}]

	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumSports [set n_rows [db_get_nrows $res]]

	set selected_sport_name ""

	for {set r 0} {$r < $n_rows} {incr r} {
		set SPORTS($r,sport_id) [db_get_col $res $r sport_id]
		set SPORTS($r,ob_id)    [db_get_col $res $r ob_id]
		set SPORTS($r,ob_level) [db_get_col $res $r ob_level]
		set SPORTS($r,name)     [db_get_col $res $r name]

		# set the default to the 1st sport in the dropdown
		if {$r == 0 || ($SPORTS($r,sport_id) == $sport_sel)} {
			set default_sport_id   $SPORTS($r,sport_id)
			set default_sport_dd   $SPORTS($r,ob_level)
			set default_sport_obid $SPORTS($r,ob_id)
			if { $SPORTS($r,sport_id) == $sport_sel } {
				set SPORTS($r,selected) {selected="selected"}
				set selected_sport_name $SPORTS($r,name)
			}
		}
	}

	tpBindString SelectedSportId $default_sport_id
	tpBindString SportOBId       $default_sport_obid

	tpBindString sport_id $sport_sel

	# Remember the drilldown level for the default sport
	switch -exact $default_sport_dd {
		"y" {
			tpBindString SelectedSportDD ROOT
		}
		"c" {
			tpBindString SelectedSportDD CLASS
		}
		default {
			error {Drilldown filter is not 'y' or 'c'}
		}

	}

	set cns [namespace current]

	tpBindVar SportId   ${cns}::SPORTS   sport_id   sport_idx
	tpBindVar SportName ${cns}::SPORTS   name       sport_idx
	tpBindVar SportLev  ${cns}::SPORTS   ob_level   sport_idx
	tpBindVar SportSel  ${cns}::SPORTS   selected   sport_idx

	tpBindString selSportName $selected_sport_name

	# Cleanup
	GC::mark SPORTS
	db_close $res
}


#
# ----------------------------------------------------------------------------
# Bind up the (non-sport) menu items
# ----------------------------------------------------------------------------
#
proc _bind_menu_items {args} {

	variable MENU_ITEM
	unset -nocomplain MENU_ITEM

	set sql {
		select unique
			m.desc,
			s.name,
			m.menu_item_id
		from
			tMenuItem m,
			outer tSport s
		where
			m.sport_id = s.sport_id
	}

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]
	tpSetVar NumMenuItems $rows

	for {set i 0} {$i < $rows} {incr i} {
		set MENU_ITEM($i,desc)       [db_get_col $res $i desc]
		set MENU_ITEM($i,sport_name) [db_get_col $res $i name]
		if {$MENU_ITEM($i,sport_name) == ""} {
			set MENU_ITEM($i,sport_name) "None"
		}
		set MENU_ITEM($i,menu_item_id) [db_get_col $res $i menu_item_id]
	}

	set cns [namespace current]

	tpBindVar menuDesc      ${cns}::MENU_ITEM desc          menu_item_idx
	tpBindVar menuSportName ${cns}::MENU_ITEM sport_name    menu_item_idx
	tpBindVar menuItemId    ${cns}::MENU_ITEM menu_item_id  menu_item_idx
}


#
# ----------------------------------------------------------------------------
# Show menu item details
# ----------------------------------------------------------------------------
#
proc go_sport_menu_item {{menu_item_id ""}} {

	variable MENU_ITEM
	unset -nocomplain MENU_ITEM

	if {$menu_item_id == ""} {
		set menu_item_id [reqGetArg menuItemId]
	}

	if {$menu_item_id != ""} {

		# Retrieve non-language specific details
		set sql {
			select unique
				m.desc,
				m.sport_id
			from
				tMenuItem m
			where
				m.menu_item_id = ?
		}

		set stmt [inf_prep_sql $::DB $sql]
		set res  [inf_exec_stmt $stmt $menu_item_id]
		inf_close_stmt $stmt

		set rows [db_get_nrows $res]

		if {$rows == 1} {
			set menu_desc   [db_get_col $res 0 desc]
			set sport_id    [db_get_col $res 0 sport_id]
		} else {
			db_close $res
			err_bind "Menu Item not found"
			go_sport_list
			return
		}

		db_close $res

		# Retrieve language specific details
		set sql2 {
			select unique
				mv.display_name,
				mv.url,
				mv.displayed,
				mv.priority_disporder,
				mv.nav_disporder,
				mv.menu_item_view_id,
				vt.name as view_name,
				vt.view
			from
				tViewType            vt,
				outer tMenuItemView  mv
			where
				mv.view              = vt.view
				and mv.menu_item_id     = ?
			order by vt.name asc
		}

		set stmt2 [inf_prep_sql $::DB $sql2]
		set res2  [inf_exec_stmt $stmt2 $menu_item_id]
		inf_close_stmt $stmt2

		set rows [db_get_nrows $res2]

		for {set i 0} {$i < $rows} {incr i} {
			set MENU_ITEM($i,display_name)       [db_get_col $res2 $i display_name]
			set MENU_ITEM($i,url)                [db_get_col $res2 $i url]
			set MENU_ITEM($i,displayed)          [db_get_col $res2 $i displayed]
			set MENU_ITEM($i,view_name)          [db_get_col $res2 $i view_name]
			set MENU_ITEM($i,view)               [db_get_col $res2 $i view]
			set MENU_ITEM($i,priority_disporder) [db_get_col $res2 $i priority_disporder]
			set MENU_ITEM($i,nav_disporder)      [db_get_col $res2 $i nav_disporder]
			set MENU_ITEM($i,menu_item_view_id)  [db_get_col $res2 $i menu_item_view_id]

			if {$MENU_ITEM($i,priority_disporder) == ""} {
				set MENU_ITEM($i,priority_disporder) "0"
			}
			if {$MENU_ITEM($i,nav_disporder) == ""} {
				set MENU_ITEM($i,nav_disporder) "0"
			}
			if {$MENU_ITEM($i,url) != ""} {
				set MENU_ITEM($i,is_active) "Y"
			} else {
				set MENU_ITEM($i,is_active) "N"
			}
		}

		db_close $res2

		set cns [namespace current]

		# Bind up values
		tpSetVar NumMenuItems $rows

		tpBindVar displayName         ${cns}::MENU_ITEM display_name        menu_item_idx
		tpBindVar url                 ${cns}::MENU_ITEM url                 menu_item_idx
		tpBindVar displayed           ${cns}::MENU_ITEM displayed           menu_item_idx
		tpBindVar view                ${cns}::MENU_ITEM view                menu_item_idx
		tpBindVar view_name           ${cns}::MENU_ITEM view_name           menu_item_idx
		tpBindVar is_active           ${cns}::MENU_ITEM is_active           menu_item_idx
		tpBindVar nav_disporder       ${cns}::MENU_ITEM nav_disporder       menu_item_idx
		tpBindVar priority_disporder  ${cns}::MENU_ITEM priority_disporder  menu_item_idx
		tpBindVar menu_item_view_id   ${cns}::MENU_ITEM menu_item_view_id   menu_item_idx

		_bind_sports $sport_id

		tpBindString menuDesc $menu_desc
		tpBindString add_item 0

	} else {

		# Bind up values
		_bind_sports
		tpBindString add_item 1
	}

	tpBindString menuItemId $menu_item_id

	asPlayFile menu_item.html
}


#
# ----------------------------------------------------------------------------
# Delete menu items
# 	- remove from tMenuItem / tMenuItemLang
# ----------------------------------------------------------------------------
#
proc del_sport_menu_item args {

	global DB

	# Split up comma delimited list of items to remove
	set to_delete_list [split [reqGetArg delMenuBoxList] { ,}]

	# Delete each in turn from both tables
	if { [llength $to_delete_list] > 0 } {

		set del_sql [inf_prep_sql $::DB {
			delete from tMenuItemView where menu_item_id = ?
		}]

		set del_sql2 [inf_prep_sql $::DB {
			delete from tMenuItem where menu_item_id = ?
		}]

		foreach to_del $to_delete_list {

			ob_log::write INFO {del_sport_menu_item:: deleting item $to_del}

			# Transactional
			inf_begin_tran $::DB
			inf_exec_stmt $del_sql   $to_del
			inf_exec_stmt $del_sql2  $to_del
			inf_commit_tran $::DB
		}

		inf_close_stmt $del_sql
		inf_close_stmt $del_sql2
	}

	go_sport_list
}


#
# ----------------------------------------------------------------------------
# Navigate to appropriate update
# ----------------------------------------------------------------------------
#
proc do_sport_menu_item args {

	set action [reqGetArg "SubmitName"]

	if {$action == "UpdateItem"} {
		update_sport_menu_item
	} else {
		update_menu_view_item
	}
}


#
# ----------------------------------------------------------------------------
# Add/update menu item
# ----------------------------------------------------------------------------
#
proc update_sport_menu_item args {

	set sport_id      [reqGetArg sport_id]
	set desc          [reqGetArg MenuDesc]
	set menu_item_id  [reqGetArg menuItemId]

	if {$menu_item_id == ""} {

		#
		# Add a new menu item
		#

		set sql {
			insert into tMenuItem
				(sport_id, desc)
			values
				(?,?)
		}

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $sport_id $desc]} msg]} {
			ob::log::write ERROR {ERROR adding menu item: $msg}
			inf_close_stmt $stmt
			catch {db_close $res}
			err_bind $msg
			go_sport_menu_item
			return
		}

		set menu_item_id [inf_get_serial $stmt]

		inf_close_stmt $stmt
		db_close $res

	} else {

		#
		# Update a menu item
		#

		set sql {
			update
				tMenuItem
			set
				sport_id = ?,
				desc = ?
			where
				menu_item_id = ?
		}

		set stmt [inf_prep_sql $::DB $sql]

		if {[catch {set res [inf_exec_stmt $stmt $sport_id $desc $menu_item_id]} msg]} {
			ob::log::write ERROR {ERROR updating menu item: $msg}
			inf_close_stmt $stmt
			catch {db_close $res}
			err_bind $msg
			go_sport_menu_item
			return
		}

		db_close $res
	}

	go_sport_menu_item $menu_item_id
}


#
# ----------------------------------------------------------------------------
# Add/update a menu items lang specific details
# ----------------------------------------------------------------------------
#
proc update_menu_view_item args {

	set menu_item_id [reqGetArg menuItemId]

	set lViewList [list]

	#
	# Get the current values from the database
	#
	set sql2 {
		select unique
			mv.display_name,
			mv.url,
			mv.displayed,
			mv.priority_disporder,
			mv.nav_disporder,
			mv.menu_item_view_id,
			vt.name as view_name,
			vt.view
		from
			tViewType           vt,
			outer tMenuItemView mv
		where
			mv.view               = vt.view
			and mv.menu_item_id   = ?
	}

	set stmt2 [inf_prep_sql $::DB $sql2]
	set res2  [inf_exec_stmt $stmt2 $menu_item_id]
	inf_close_stmt $stmt2

	set rows [db_get_nrows $res2]

	for {set i 0} {$i < $rows} {incr i} {

		set view [db_get_col $res2 $i view]

		set MENU_ITEM($view,display_name)        [db_get_col $res2 $i display_name]
		set MENU_ITEM($view,url)                 [db_get_col $res2 $i url]
		set MENU_ITEM($view,view_name)           [db_get_col $res2 $i view_name]
		set MENU_ITEM($view,priority_disporder)  [db_get_col $res2 $i priority_disporder]
		set MENU_ITEM($view,nav_disporder)       [db_get_col $res2 $i nav_disporder]
		set MENU_ITEM($view,menu_item_view_id)   [db_get_col $res2 $i menu_item_view_id]
		set MENU_ITEM($view,delete)              "N"

		lappend lViewList $view
	}

	#
	# Prepare the SQL for inserting / updating / deleting
	#
	set sql_insert {
		insert into tMenuItemView
			(priority_disporder,nav_disporder,url,displayed,view,menu_item_id)
		values
			(?,?,?,?,?,?)
	}

	set sql_update {
		update
			tMenuItemView
		set
			url                 = ?,
			priority_disporder  = ?,
			nav_disporder       = ?,
			displayed           = ?
		where
			menu_item_id        = ?
			and view            = ?
	}

	set sql_delete {
		delete from
			tMenuItemView
		where
			menu_item_id = ?
			and view     = ?
	}

	set stmt_insert [inf_prep_sql $::DB $sql_insert]
	set stmt_delete [inf_prep_sql $::DB $sql_delete]
	set stmt_update [inf_prep_sql $::DB $sql_update]

	# Work out which items to delete
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set name [reqGetNthName $i]
		if {[string first "delete_" $name] > -1} {
			set view [string range $name 7 end]
			set MENU_ITEM($view,delete) "Y"
		}
	}

	#
	# Iterate through languages seeing if we need to update/insert any items
	#
	foreach view $lViewList {

		set url  [reqGetArg url_$view]

		if {$MENU_ITEM($view,delete) == "Y" || $url == ""} {

			#
			# Delete if checked or if the URL isn't populated
			#

			if {[catch {set res [inf_exec_stmt $stmt_delete\
				$menu_item_id $view]} msg]} {

				ob::log::write ERROR {ERROR deleting menu view item: $msg}
				inf_close_stmt $stmt_delete
				err_bind $msg
				go_sport_menu_item $menu_item_id
				return
			}

			db_close $res

		} else {

			set priority_disporder  [reqGetArg priority_disporder_$view]
			set nav_disporder       [reqGetArg nav_disporder_$view]
			set displayed           [reqGetArg display_$view]

			if {$MENU_ITEM($view,url) == ""} {

				#
				# Insert
				#

				if {[catch {set res [inf_exec_stmt $stmt_insert\
				$priority_disporder $nav_disporder $url\
				$displayed $view $menu_item_id]} msg]} {
					ob::log::write ERROR {ERROR adding menu view item: $msg}
					inf_close_stmt $stmt_insert
					err_bind $msg
					go_sport_menu_item $menu_item_id
					return
				}

				db_close $res

			} else {

				#
				# Update
				#

				if {[catch {set res [inf_exec_stmt $stmt_update\
				$url $priority_disporder $nav_disporder \
				$displayed $menu_item_id $view]} msg]} {
					ob::log::write ERROR {ERROR updating menu view item: $msg}
					inf_close_stmt $stmt_update
					err_bind $msg
					go_sport_menu_item $menu_item_id
					return
				}

				db_close $res
			}

		}
	}

	inf_close_stmt $stmt_update
	inf_close_stmt $stmt_insert
	inf_close_stmt $stmt_delete

	go_sport_menu_item $menu_item_id
}


#
# ----------------------------------------------------------------------------
# Bind up the menu items for a specific language
# ----------------------------------------------------------------------------
#
proc _bind_menu_view_items {view} {

	variable MENU_ITEM
	unset -nocomplain MENU_ITEM

	set sql {
		select unique
			m.desc,
			m.menu_item_id,
			vl.priority_disporder,
			vl.nav_disporder,
			vl.menu_item_view_id,
			vl.displayed
		from
			tMenuItem m,
			tMenuItemView vl
		where
			vl.view            = ?
			and m.menu_item_id = vl.menu_item_id
	}

	set stmt [inf_prep_sql $::DB $sql]
	set res  [inf_exec_stmt $stmt $view]
	inf_close_stmt $stmt

	set rows [db_get_nrows $res]

	for {set i 0} {$i < $rows} {incr i} {
		set MENU_ITEM($i,desc)               [db_get_col $res $i desc]
		set MENU_ITEM($i,priority_disporder) [db_get_col $res $i priority_disporder]
		set MENU_ITEM($i,nav_disporder)      [db_get_col $res $i nav_disporder]
		set MENU_ITEM($i,displayed)          [db_get_col $res $i displayed]
		set MENU_ITEM($i,menu_item_id)       [db_get_col $res $i menu_item_id]
		set MENU_ITEM($i,menu_item_view_id)  [db_get_col $res $i menu_item_view_id]
	}

	set cns [namespace current]

	tpSetVar NumMenuItems $rows

	tpBindVar menuDesc              ${cns}::MENU_ITEM desc               menu_item_idx
	tpBindVar menuDisplayed         ${cns}::MENU_ITEM displayed          menu_item_idx
	tpBindVar menuItemId            ${cns}::MENU_ITEM menu_item_id       menu_item_idx
	tpBindVar menuItemViewId        ${cns}::MENU_ITEM menu_item_view_id  menu_item_idx
	tpBindVar menuPriorityDisporder ${cns}::MENU_ITEM priority_disporder menu_item_idx
	tpBindVar menuNavDisporder      ${cns}::MENU_ITEM nav_disporder      menu_item_idx
}


#
# ----------------------------------------------------------------------------
# Update disporder/display preferences for menu items based on a language
# ----------------------------------------------------------------------------
#
proc do_sport_menu_view_item {args} {

	set sql {
		update
			tMenuItemView
		set
			priority_disporder = ?,
			nav_disporder      = ?,
			displayed          = ?
		where
			menu_item_view_id  = ?
	}

	set stmt [inf_prep_sql $::DB $sql]

	set idList [list]

	# Work out which items to update
	for {set i 0} {$i < [reqGetNumVals]} {incr i} {
		set name [reqGetNthName $i]
		if {[string first "miPriorityDisporder_" $name] > -1} {
			lappend idList [string range $name 20 end]
		}
	}

	# Update each in turn
	foreach id $idList {

		set priority_disporder [reqGetArg miPriorityDisporder_$id]
		set nav_disporder      [reqGetArg miNavDisporder_$id]
		set displayed          [reqGetArg miDisplay_$id]

		if {[catch {set res [inf_exec_stmt $stmt\
		$priority_disporder $nav_disporder $displayed $id]} msg]} {
			ob::log::write ERROR {ERROR updating menu view item: $msg}
			inf_close_stmt $stmt
			err_bind $msg
			go_sport_view
			return
		}

		db_close $res
	}

	inf_close_stmt $stmt

	go_sport_view
}


}


