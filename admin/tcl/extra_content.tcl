# ==============================================================
# $Id: extra_content.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::EXTRACONT {

asSetAct ADMIN::EXTRACONT::go_extra_content_list [namespace code go_extra_content_list]
asSetAct ADMIN::EXTRACONT::go_extra_content      [namespace code go_extra_content]
asSetAct ADMIN::EXTRACONT::go_upd_extra_content  [namespace code go_upd_extra_content]
asSetAct ADMIN::EXTRACONT::go_new_extra_content  [namespace code go_new_extra_content]


variable SQL

variable default_from "1999-01-01 00:00:00"
variable default_to   "9999-12-31 23:59:59"

set SQL(get_news_view)     [subst {
	select
		view
	from tView
	where sort= ?
	and   id  = ?
}]

set SQL(del_news)          {delete from tNews where news_id = ?}
set SQL(upd_news) [subst {
	execute procedure pUpdNews (
		p_news_id         =?,
		p_news            =?,
		p_url_type        =?,
		p_info_url        =?,
		p_link_title      =?,
		p_small_image     =?,
		p_large_image     =?,
		p_disporder       =?,
		p_displayed       =?,
		p_languages       =?,
		p_location        =?,
		p_locations       =?,
		p_channels        =?,
		p_link_new_window =?,
		p_link_win_width  =?,
		p_link_win_height =?,
		p_tag             =?,
		p_type            =?,
		p_id_level        =?,
		p_id_key          =?,
		p_id_name         =?,
		p_from_date       =?,
		p_to_date         =?,
		p_win_resizable   =?,
		p_win_scrollbar   =?,
		p_win_menubar     =?
	)
}]

set SQL(ins_news) [subst {
	execute procedure pInsNews (
		p_news		       =?,
		p_url_type        =?,
		p_info_url        =?,
		p_link_title      =?,
		p_small_image     =?,
		p_large_image     =?,
		p_disporder       =?,
		p_displayed       =?,
		p_languages       =?,
		p_location        =?,
		p_locations       =?,
		p_channels        =?,
		p_link_new_window =?,
		p_link_win_width  =?,
		p_link_win_height =?,
		p_tag             =?,
		p_type            =?,
		p_id_level        =?,
		p_id_key          =?,
		p_id_name         =?,
		p_from_date       =?,
		p_to_date         =?,
		p_win_resizable   =?,
		p_win_scrollbar   =?,
		p_win_menubar     =?
	)
}]

set SQL(get_news) [subst {
	select
		news_id,
		bbet_id,
		news,
		url_type,
		info_url,
		link_title,
		small_image,
		large_image,
		cr_date,
		disporder,
		displayed,
		channels,
		location,
		locations,
		languages,
		link_new_window,
		link_win_width,
		link_win_height,
		win_resizable,
		win_scrollbar,
		win_menubar,
		tag,
		type,
		NVL(from_date,'$default_from') from_date,
		NVL(to_date,  '$default_to') to_date,
		id_level,
		id_key,
		id_name
	from
		tnews
	where
		news_id = ?
}]

set SQL(get_refresh_value) [subst {
	select
		refresh_value
	from
		tNewsType
	where
		code = ?
}]

set SQL(upd_refresh_value) [subst {
	update tNewsType set
		refresh_value = ?
	where
		code = ?
}]

# ----------------------------------------------------------------------
# generate the news list
# ----------------------------------------------------------------------

proc go_extra_content_list {} {

	global NEWS DB
	global VIEW_MAP VIEWARRAY
	variable SQL
	variable default_from
	variable default_to

	OT_LogWrite 2 "go_extra_content_list"

	if [info exists VIEWARRAY]     {unset VIEWARRAY}

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		# Setup View info
		read_view_info
		set view [reqGetArg View]
		for {set i 0} {$i < $VIEW_MAP(num_views)} {incr i} {
			set VIEWARRAY($i,code) $VIEW_MAP($i,code)
			set VIEWARRAY($i,name) $VIEW_MAP($i,name)
		}

		set VIEWARRAY($VIEW_MAP(num_views),code) "-"
		set VIEWARRAY($VIEW_MAP(num_views),name) "All"
		set VIEWARRAY(entries)	[expr $VIEW_MAP(num_views) + 1]

		tpBindVar VIEW_CODE VIEWARRAY code c_idx
		tpBindVar VIEW_DESC VIEWARRAY name c_idx

		if {$view==""} {
			tpBindString View "-"
		} else {
			tpBindString View $view
		}

		# If view exists then need to pull out only those news items, if news doesn't exist then need to
		# return all news items.
		if {$view=="-" || $view==""} {
			set view_sql ""
		} else {
			set view_sql "and exists (select * from tView v where v.view = '${view}' and v.sort='NEWS' and n.news_id =v.id)"
		}
		set sql_news [subst {
			select
				t.name type,
				t.disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.info_url,
				n.link_new_window,
				n.link_win_width,
				n.link_win_height,
				n.displayed,
				n.channels,
				n.locations,
				n.type,
				n.id_name,
				n.id_level
			from
				tnews n,
				tnewstype t
			where
				n.type = t.code and
				t.code = 'EC'
				$view_sql
			order by
				2,3,4
			}]
	} else {
		set sql_news [subst {
			select
				t.name type,
				t.disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.info_url,
				n.link_new_window,
				n.link_win_width,
				n.link_win_height,
				n.displayed,
				n.channels,
				n.languages,
				n.locations,
				n.type,
				n.id_name,
				n.id_level
			from
				tnews n,
				tnewstype t
			where
				n.type = t.code and
				t.code = 'EC'
			order by
				2,3,4
			}]
	}

	set stmt [inf_prep_sql $DB [subst $sql_news]]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt
	set num_news [db_get_nrows $rs]
	set NEWS(entries) $num_news

	for {set i 0} {$i < $num_news} {incr i} {
		set NEWS($i,type)       [db_get_col $rs $i type]
		set NEWS($i,from_date)  [db_get_col $rs $i from_date]
		set NEWS($i,to_date)    [db_get_col $rs $i to_date]
		set NEWS($i,news_id)    [db_get_col $rs $i news_id]
		set NEWS($i,title)      [db_get_col $rs $i link_title]
		set NEWS($i,new_win)    [db_get_col $rs $i link_new_window]
		set NEWS($i,win_width)  [db_get_col $rs $i link_win_width]
		set NEWS($i,win_height) [db_get_col $rs $i link_win_height]
		set NEWS($i,url)        [db_get_col $rs $i info_url]
		set NEWS($i,highlight)  [db_get_col $rs $i id_name]
		set NEWS($i,id_level)   [db_get_col $rs $i id_level]
		set NEWS($i,displayed)  [db_get_col $rs $i displayed]
		set NEWS($i,channels)   [db_get_col $rs $i channels]
		set NEWS($i,locations)  [db_get_col $rs $i locations]
		set NEWS($i,disporder)  [db_get_col $rs $i disporder]

		# These checks determine whether the news highlight is currently in the
		# timeframe which would allow it to be displayed. If the clock scan fails
		# It is because the date is either before the epoch or infinity and
		# therefore should be always displayed
		set now       [clock seconds]
		if [catch {set from_time [clock scan "$NEWS($i,from_date)"]} msg] {
			set testfrom 0
		} else {
			set testfrom 1
		}
		if [catch {set to_time [clock scan "$NEWS($i,to_date)"]} msg] {
			set testto 0
		} else {
			set testto 1
		}
		set NEWS($i,suspended) 0
		set NEWS($i,status) "Active"
		if {$testfrom && $testto} {
			if {$now > $from_time && $now < $to_time} {
				set NEWS($i,suspended) 0
			} else {
				set NEWS($i,suspended) 1
				if {$now < $from_time} {
					set NEWS($i,status) "Future"
				} elseif {$now > $testto} {
					set NEWS($i,status) "Expired"
				} else {
					set NEWS($i,status) "Inactive"
				}
				set NEWS($i,suspended) 1
				set NEWS($i,status) "Expired"
			}
		}
		if {$testfrom && !$testto} {
			if {$now > $from_time} {
				set NEWS($i,suspended) 0
			} else {
				set NEWS($i,suspended) 1
				set NEWS($i,status) "Future"
			}

		}
		if {!$testfrom && $testto} {
			if {$now < $testto} {
				set NEWS($i,suspended) 0
			} else {
				set NEWS($i,suspended) 1
				set NEWS($i,status) "Expired"
			}

		}
		if {$NEWS($i,displayed)=="N"} {set NEWS($i,status) "Not Displayed"}
	}

	db_close $rs

	tpBindVar status      NEWS status    news_idx
	tpBindVar from_date   NEWS from_date news_idx
	tpBindVar to_date     NEWS to_date   news_idx
	tpBindVar type        NEWS type      news_idx
	tpBindVar link_title  NEWS title     news_idx
	tpBindVar news_id     NEWS news_id   news_idx
	tpBindVar link_url    NEWS url       news_idx
	tpBindVar id_level    NEWS id_level  news_idx
	tpBindVar highlight   NEWS highlight news_idx
	tpBindVar new_window  NEWS new_win   news_idx
	tpBindVar new_window  NEWS new_win   news_idx
	tpBindVar win_width   NEWS win_width news_idx
	tpBindVar win_height  NEWS win_width news_idx
	tpBindVar channels    NEWS channels  news_idx

	asPlayFile -nocache extra_content_list.html

	unset NEWS
}


#----------------------------------------------------------------------------
# Procedure :   go_extra_content
# Description : load up an existing news highlight
#----------------------------------------------------------------------------
proc go_extra_content {{errored 0}} {

	global DB HIGHLIGHT TYPE_MAP TYPEARRAY
	variable SQL

	read_type_info

	for {set i 0} {$i < $TYPE_MAP(num_types)} {incr i} {
		if {$TYPE_MAP($i,name) !="All"} {
			set TYPEARRAY($i,code) $TYPE_MAP($i,code)
			set TYPEARRAY($i,name) $TYPE_MAP($i,name)
		}
	}

	set TYPEARRAY(entries)	[expr $TYPE_MAP(num_types)]

	tpBindVar TYPE_CODE TYPEARRAY code t_idx
	tpBindVar TYPE_DESC TYPEARRAY name t_idx

	if {$errored==1} {
		# If there was a problem with the updated fields,
		# dont rebind fields or updates will be lost
		asPlayFile -nocache extra_content.html
		return
	}

	set news_id [reqGetArg news_id]

	set stmt    [inf_prep_sql $DB $SQL(get_news)]
	set rs      [inf_exec_stmt $stmt $news_id]
	inf_close_stmt $stmt

	set from_date [db_get_col $rs from_date]
	set to_date   [db_get_col $rs to_date]
	set type      [db_get_col $rs type]
	set news_location  [db_get_col $rs location]


	if {$type==""} {
		tpBindString Type "-"
	} else {
		tpBindString Type $type
	}


		tpBindString fromDate 	[string range $from_date 0 9]
		tpBindString fromTime 	[string range $from_date 11 end]
		tpBindString toDate   	[string range $to_date 0 9]
		tpBindString toTime   	[string range $to_date 11 end]
		tpBindString List_View  [reqGetArg list_view]
		tpBindString List_Type  [reqGetArg list_type]


		foreach n [db_get_colnames $rs] {
			if {$n == "link_title"} {
				# Make JS safe
				tpBindString $n [safe_javascript [db_get_col $rs $n]]
			} elseif {$n == "win_resizable" || $n == "win_scrollbar" || $n == "win_menubar"} {

				if {[db_get_col $rs $n] == "Y"} {
					tpBindString $n "checked=\"checked\""
				}
			} else {
				tpBindString $n [db_get_col $rs $n]
			}
		}

		make_channel_binds  [db_get_col $rs channels] -
		make_location_binds [db_get_col $rs locations] - 0 $news_location
		make_language_binds [db_get_col $rs languages] -
	db_close $rs

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {

		# Build up the View array
		set stmt [inf_prep_sql $DB $SQL(get_news_view)]
		set rs   [inf_exec_stmt $stmt NEWS $news_id]
		inf_close_stmt $stmt

		set view_list [list]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			lappend view_list [db_get_col $rs $i view]
		}
		make_view_binds $view_list -
		db_close $rs
	}

	tpSetVar Insert 0
	tpSetVar news_location $news_location

	asPlayFile -nocache extra_content.html
}

#----------------------------------------------------------------------------
# Procedure :   go_new_extra_content
# Description : load up a blank template for inserting a news item
#----------------------------------------------------------------------------
proc go_new_extra_content {{new 0}} {

	global DB TYPE_MAP TYPEARRAY

	if {$new!=1} {
		tpSetVar IsError 0
	}

	read_type_info

	for {set i 0} {$i < $TYPE_MAP(num_types)} {incr i} {
		if {$TYPE_MAP($i,name) !="All"} {
			set TYPEARRAY($i,code) $TYPE_MAP($i,code)
			set TYPEARRAY($i,name) $TYPE_MAP($i,name)
		}
	}

	set TYPEARRAY(entries)	$TYPE_MAP(num_types)

	tpBindVar TYPE_CODE TYPEARRAY code t_idx
	tpBindVar TYPE_DESC TYPEARRAY name t_idx

	# Get default language
	set sql  {select default_lang from tControl}
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	set lang [db_get_col $rs default_lang]

	inf_close_stmt $stmt
	db_close $rs

	# Get default view
	set sql  {select default_view from tControl}
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	set view [db_get_col $rs default_view]

	db_close $rs

	tpSetVar Insert 1
	if {$new!=1} {
		make_channel_binds "I" -
		make_location_binds "-" -
		make_language_binds $lang -
	}

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		make_view_binds $view -
	}

	asPlayFile -nocache extra_content.html
}


#----------------------------------------------------------------------------
# Procedure :   ins_extra_content
# Description : Insert a new news item
#----------------------------------------------------------------------------
proc ins_extra_content {} {

	global   DB
	variable SQL
	variable default_from
	variable default_to

	if {![op_allowed ManageExtraContent]} {
		tpBindString Error "User does not have ManageExtraContent permission"
		go_extra_content_list
		return
	}

	foreach a {
		link_title
		info_url
		small_image
		large_image
		disporder
		displayed
		url_type
		link_new_window
		link_win_width
		link_win_height
		location
		tag
		news_type
		id_level
		id_name
		fromDate
		fromTime
		toDate
		toTime
		news
	} {
		set $a [reqGetArg $a]
	}

	# Throw in the values that were stripped out of the HTML
	set url_type U
	set news_type EC

	# Deal with Y/N checkboxes
	foreach a {
		win_resizable
		win_scrollbar
		win_menubar
	} {
		if {[reqGetArg $a] == "on"} {
			set $a "Y"
		} else {
			set $a "N"
		}
	}

	if {[string first "XGAME" $id_level] == -1} {
		set id_key [reqGetArg id_key]
	} else {
		set id_key 0
	}
	set channels [make_channel_str]
	set languages [make_language_str]
	set locations [make_location_str]

	if {$disporder == ""} {
		set disporder 0
	}

	if {$fromDate == "" || $fromTime == ""} {
		set from_date $default_from
	} else {
		set from_date "$fromDate $fromTime"
	}
	if {$toDate == "" || $toTime == ""} {
		set to_date $default_to
	} else {
		set to_date "$toDate $toTime"
	}

	set err 0

	if {![simple_validate $link_title $info_url $id_key $news_type]} {
		set err 1
	} else {
		set stmt [inf_prep_sql $DB $SQL(ins_news)]
		if {[catch {set rs [inf_exec_stmt $stmt \
			$news \
			$url_type \
			$info_url \
			$link_title \
			$small_image \
			$large_image \
			$disporder  \
			$displayed \
			$languages \
			$location \
			$locations \
			$channels \
			$link_new_window \
			$link_win_width \
			$link_win_height \
			$tag \
			$news_type \
			$id_level \
			$id_key \
			$id_name \
			"$from_date" \
			"$to_date" \
			$win_resizable \
			$win_scrollbar \
			$win_menubar]} msg]} {
				set err 1
				err_bind $msg
		} else {
			set news_id [db_get_coln $rs 0 0]
			inf_close_stmt $stmt

			if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $err == 0} {
				set upd_view [ADMIN::VIEWS::upd_view NEWS $news_id]
				if {[lindex $upd_view 0]} {
					err_bind [lindex $upd_view 1]
					set err 1
				}
			}
		}
	}

	if {$err == 1} {
		foreach a {
			link_title
			info_url
			small_image
			large_image
			disporder
			displayed
			channels
			languages
			bbet_id
			url_type
			link_new_window
			link_win_width
			link_win_height
			location
			tag
			type
			id_level
			id_key
			id_name
			news
			fromDate
			fromTime
			toDate
			toTime
			List_View
			List_Type
			news_type
		} {
			tpBindString $a [reqGetArg $a]
		}

		# Rebind checkboxes
		foreach a {
			win_resizable
			win_scrollbar
			win_menubar
		} {
			if {[reqGetArg $a] == "on"} {
				tpBindString $a "checked=\"checked\""
			}
		}

		tpBindString Type [reqGetArg news_type]

		make_channel_binds  $channels -
		make_location_binds $locations - 0 [reqGetArg location]
		make_language_binds $languages -

		return 0
	}

	return 1
}

#----------------------------------------------------------------------------
# Procedure :   simple_validate
# Description : validate a news item before insert or update
#----------------------------------------------------------------------------
proc simple_validate {link_title info_url id_key {type "P"}} {

	if {$link_title == ""} {
		err_bind "Must enter link title"
		return 0
	} elseif {$type != {T} && $info_url=="" && $id_key==""} {
		err_bind "Must enter a link URL or link to a bet highlight"
		return 0
	}
	return 1
}

#----------------------------------------------------------------------------
# Procedure :   go_upd_extra_content
# Description : wrapper for update news
#----------------------------------------------------------------------------
proc go_upd_extra_content {} {

	global   DB
	variable SQL

	if {![op_allowed ManageExtraContent]} {
		tpBindString Error "User does not have ManageExtraContent permission"
		go_extra_content_list
		return
	}

	set ret 0

	set SubmitName [reqGetArg SubmitName]

	switch -- $SubmitName {
		Delete {
			set ret [del_extra_content]
		}
		Update {
			set ret [upd_extra_content]
		}
		Insert {
			set ret [ins_extra_content]
		}
	}

	#
	# Flush the DB Cache for this type of highlight
	#
	set news_type_code EC

	# get existing flush value
	set stmt    [inf_prep_sql $DB $SQL(get_refresh_value)]
	set rs      [inf_exec_stmt $stmt $news_type_code]
	inf_close_stmt $stmt

	if {[db_get_nrows $rs] > 0} {
		set new_refresh_value [expr [db_get_col $rs refresh_value] + 1]
	}
	# set new refresh value
	set stmt [inf_prep_sql $DB $SQL(upd_refresh_value)]
	if [catch {inf_exec_stmt $stmt $new_refresh_value $news_type_code} msg] {
		err_bind $msg
		set err 1
	}
	inf_close_stmt $stmt
	db_close $rs


	# ^^^^^ end flush code ^^^^^^^

	if {$ret == 0} {
		if {$SubmitName=="Insert"} {
			go_new_extra_content 1
		} else {
			go_extra_content 1
		}
	} else {
		go_extra_content_list
	}
}

#----------------------------------------------------------------------------
# Procedure :   upd_extra_content
# Description : update the news highlight and update the views associated
#----------------------------------------------------------------------------
proc upd_extra_content {} {

	global   DB
	variable SQL
	variable default_from
	variable default_to

	foreach a {
		news_id
		link_title
		info_url
		small_image
		large_image
		disporder
		displayed
		url_type
		link_new_window
		link_win_width
		link_win_height
		tag
		location
		id_level
		id_name
		news
		fromDate
		fromTime
		toDate
		toTime
		news_type
	} {
		set $a [reqGetArg $a]
	}

	set url_type U
	set news_type EC

	# Deal with Y/N checkboxes
	foreach a {
		win_resizable
		win_scrollbar
		win_menubar
	} {
		if {[reqGetArg $a] == "on"} {
			set $a "Y"
		} else {
			set $a "N"
		}
	}

	if {[string first "XGAME" $id_level] == -1} {
		set id_key [reqGetArg id_key]
	} else {
		set id_key 0
	  }
	set channels  [make_channel_str]
	set languages [make_language_str]
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set view_list [make_view_str]
	}

	set locations [make_location_str]
	if {$fromDate == "" || $fromTime == ""} {
		set from_date $default_from
	} else {
		set from_date "$fromDate $fromTime"
	}
	if {$toDate == "" || $toTime == ""} {
		set to_date $default_to
	} else {
		set to_date   "$toDate $toTime"
	}

	if {$disporder == ""} {set disporder 0}

	set err 0
	if {![simple_validate $link_title $info_url $id_key $news_type]} {
		set err 1
	} else {
		set stmt [inf_prep_sql $DB $SQL(upd_news)]
		if [catch {inf_exec_stmt $stmt \
			$news_id\
			$news\
			$url_type\
			$info_url\
			$link_title\
			$small_image\
			$large_image\
			$disporder\
			$displayed\
			$languages\
			$location\
			$locations\
			$channels\
			$link_new_window\
			$link_win_width\
			$link_win_height\
			$tag\
			$news_type\
			$id_level\
			$id_key\
			$id_name\
			$from_date\
			$to_date\
			$win_resizable\
			$win_scrollbar\
			$win_menubar} msg] {
			err_bind $msg
			set err 1
		}
		inf_close_stmt $stmt
	}
	if {[OT_CfgGet FUNC_VIEW_FLAGS 0] && $err !=1} {
		# Build two list, one will contain those views that need to be deleted
		# the other list will contain a list of those views that need to be inserted

		inf_begin_tran $DB
		set upd_view [ADMIN::VIEWS::upd_view NEWS $news_id]
		if {[lindex $upd_view 0]} {
			err_bind [lindex $upd_view 1]
			set err 1
		}
		if {$err} {
			inf_rollback_tran $DB
		} else {
			inf_commit_tran $DB
		}
	}

	if {$err ==1 } {
		foreach a {
			news_id
			link_title
			info_url
			small_image
			large_image
			disporder
			displayed
			channels
			languages
			bbet_id
			url_type
			link_new_window
			link_win_width
			link_win_height
			location
			tag
			type
			id_level
			id_key
			id_name
			news
			fromDate
			fromTime
			toDate
			toTime
			List_View
			List_Type
			news_type
		} {
			tpBindString $a [reqGetArg $a]
		}

		# Rebind checkboxes
		foreach a {
			win_resizable
			win_scrollbar
			win_menubar
		} {
			if {[reqGetArg $a] == "on"} {
				tpBindString $a "checked=\"checked\""
			}
		}

		tpBindString Type [reqGetArg news_type]

		make_channel_binds  $channels  -
		make_location_binds $locations - 0 [reqGetArg location]
		make_language_binds $languages -

		if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
			make_view_binds     $view_list -
		}

		return 0
	}
	return 1
}

#----------------------------------------------------------------------------
# Procedure :   del_extra_content
# Description : delete a news item and associated view information from tnewsview
# Author :      JDM 30-04-2002
#----------------------------------------------------------------------------
proc del_extra_content {} {

	global   DB
	variable SQL

	set err 0
	set news_id [reqGetArg news_id]

	set stmt [inf_prep_sql $DB $SQL(del_news)]
	if [catch {inf_exec_stmt $stmt $news_id} msg] {
		err_bind $msg
		set err 1
	}
	inf_close_stmt $stmt

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		set del_view [ADMIN::VIEWS::del_view NEWS $news_id]
		if {[lindex $del_view 0]} {
			err_bind [lindex $del_view 1]
			set err 1
		}
	}

	if {$err ==1} {
		foreach a {
			link_title
			info_url
			small_image
			large_image
			disporder
			bbet_id
			url_type
			link_new_window
			link_win_width
			link_win_height
			tag
			news
			languages
			channels
			locations
		} {
			tpBindString $a [reqGetArg $a]
		}
		return 0
	}

	return 1
}

#----------------------------------------------------------------------------
# Procedure :   read_location_info
# Description : reads the location information for the news items
# Author :      JDM 30-04-2002
#----------------------------------------------------------------------------
proc read_location_info args {

	global DB LOCATION_MAP

	if {[info exists LOCATION_MAP]} {return}

	set location_sql {
		select
			code,
			name,
			desc,
			disporder
		from
			tNewsLocations
		where
			status = 'A'
		order by
			disporder
	}

	set stmt   [inf_prep_sql $DB $location_sql]
	set res    [inf_exec_stmt $stmt]
	set n_rows [db_get_nrows $res]

	inf_close_stmt $stmt

	for {set i 0} {$i < $n_rows} {incr i} {
		set code [db_get_col $res $i code]
		set name [db_get_col $res $i name]
		set LOCATION_MAP($i,code) $code
		set LOCATION_MAP($i,name) $name
	}

	db_close $res

	set LOCATION_MAP(num_rows) $n_rows
}

#----------------------------------------------------------------------------
# Procedure :   make_locations_str
# Description : build the location string (news locations)
# Author :      JDM 30-04-2002
#----------------------------------------------------------------------------
proc make_location_str {{id ""}} {

	global LOCATION_MAP

	read_location_info

	set result ""
	set num 0

	for {set i 0} {$i < $LOCATION_MAP(num_rows)} {incr i} {
		set code $LOCATION_MAP($i,code)
		if {[reqGetArg ${code}$id] != ""} {
			if {$num > 0} {
			  append result ","
			}
			append result $code
			incr num
		}
	}
	return $result
}


#----------------------------------------------------------------------------
# Procedure :   safe_javascript
# Description : makes a string JS-safe ('->\' and "->\")
# Author :      Karim
#----------------------------------------------------------------------------
proc safe_javascript {toencode} {
	return [string map {' \\' \" \\\"} $toencode]
}


#----------------------------------------------------------------------------
# Procedure :   make_location_binds
# Description : build the location string (news locations)
# Author :      JDM 30-04-2002
#----------------------------------------------------------------------------
proc make_location_binds {{str ""} {mask ""} {add 0} {loc2 ""}} {

	global LOCATION_MAP USE_LOCATION_MAP

	read_location_info

	array set USE_LOCATION_MAP [list]

	set c 0

	for {set i 0} {$i < $LOCATION_MAP(num_rows)} {incr i} {

		set code $LOCATION_MAP($i,code)

		if {$mask != "-"} {
			if {[string first $code $mask] < 0} {
				continue
			}
		}
		set USE_LOCATION_MAP($c,code) $code
		set USE_LOCATION_MAP($c,name) $LOCATION_MAP($i,name)

		if {([string first $code $str] >= 0) || ($add==1)} {
			set USE_LOCATION_MAP($c,selected) CHECKED
		} else {
			set USE_LOCATION_MAP($c,selected) ""
		}

		if {$loc2 != "" && ([string first $code $loc2] >= 0)} {
			set USE_LOCATION_MAP($c,selected2) "selected=\"selected\""
		} else {
			set USE_LOCATION_MAP($c,selected2) ""
		}
		incr c
	}

	tpSetVar NumLocations $c

	tpBindVar name      USE_LOCATION_MAP name     location_idx
	tpBindVar code      USE_LOCATION_MAP code     location_idx
	tpBindVar selected  USE_LOCATION_MAP selected location_idx
	tpBindVar selected2  USE_LOCATION_MAP selected2 location_idx

}

}
