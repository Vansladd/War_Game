# ==============================================================
# $Id: news.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::NEWS {

asSetAct ADMIN::NEWS::go_news_highlight_list [namespace code go_news_highlight_list]
asSetAct ADMIN::NEWS::go_news_highlight      [namespace code go_news_highlight]
asSetAct ADMIN::NEWS::go_upd_news_highlight  [namespace code go_upd_news_highlight]
asSetAct ADMIN::NEWS::go_new_news_highlight  [namespace code go_new_news_highlight]
asSetAct ADMIN::NEWS::go_news_group          [namespace code go_news_group]
asSetAct ADMIN::NEWS::upd_news_group         [namespace code upd_news_group]

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

set SQL(get_lang_info)     [subst {
	select
		distinct name
	from tView n,
		tViewLang v,
		tLang l
	where   n.view = v.view
	and     v.lang = l.lang
	and     n.id = ?
}]

set SQL(del_news) {execute procedure pDelNews (p_news_id = ?)}

set SQL(upd_news) [subst {
	execute procedure pUpdNews (
		p_news_id         =?,
		p_news            =?,
		p_url_type        =?,
		p_info_url        =?,
		p_link_title      =?,
		p_name            =?,
		p_small_image     =?,
		p_large_image     =?,
		p_image_align     =?,
		p_disporder       =?,
		p_displayed       =?,
		p_languages       =?,
		p_location        =?,
		p_locations       =?,
		p_item_pos        =?,
		p_channels        =?,
		p_link_new_window =?,
		p_link_heading    =?,
		p_link_text       =?,
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
		p_win_menubar     =?,
		p_grp_id = ?
	)
}]

set SQL(ins_news) [subst {
	execute procedure pInsNews (
		p_news            =?,
		p_url_type        =?,
		p_info_url        =?,
		p_link_title      =?,
		p_name            =?,
		p_small_image     =?,
		p_large_image     =?,
		p_image_align     =?,
		p_disporder       =?,
		p_displayed       =?,
		p_languages       =?,
		p_location        =?,
		p_locations       =?,
		p_item_pos        =?,
		p_channels        =?,
		p_link_new_window =?,
		p_link_heading    =?,
		p_link_text       =?,
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
		p_win_menubar     =?,
		p_grp_id          =?
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
		name,
		small_image,
		large_image,
		image_align,
		cr_date,
		disporder,
		displayed,
		channels,
		location,
		locations,
		item_pos,
		languages,
		link_new_window,
		link_heading,
		link_text,
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
		id_name,
		grp_id
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

if [OT_CfgGet FUNC_NEWS_TAGS 0] {
	set SQL(get_news_tags) {
		select
			ty.type_id type_id,
			ty.code,
			t.tag_id,
			t.type_id,
			t.desc,
			DECODE(NVL(l.news_id,0),0,0,1) selected

		from
			tNewsType ty,
			tNewsTag t,
			outer (tNewsTagLink l)
		where
			ty.type_id = t.type_id
		and
			t.tag_id = l.tag_id
		and
			news_id = ?
		order by
			ty.type_id,
			t.type_id
	}

	set SQL(del_news_tags) {
		delete from
			tNewsTagLink
		where
			news_id = ?
	}

	set SQL(ins_news_tag) {
		insert into
			tNewsTagLink (news_id, tag_id)
		values
			(?,?)
	}
}

# ----------------------------------------------------------------------
# generate the news list
# ----------------------------------------------------------------------

proc go_news_highlight_list {} {

	global NEWS DB
	global LANG_MAP LANGUAGEARRAY
	global TYPE_MAP TYPEARRAY
	global VIEW_MAP VIEWARRAY
	variable SQL
	variable default_from
	variable default_to

	OT_LogWrite 2 "go_news_highlight_list"

	if [info exists LANGUAGEARRAY] {unset LANGUAGEARRAY}
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
	}

	# Setup language info
	read_language_info
	set lang [reqGetArg Language]

	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {
		set LANGUAGEARRAY($i,code) $LANG_MAP($i,code)
		set LANGUAGEARRAY($i,name) $LANG_MAP($i,name)
	}

	set LANGUAGEARRAY($LANG_MAP(num_langs),code) "-"
	set LANGUAGEARRAY($LANG_MAP(num_langs),name) "All"
	set LANGUAGEARRAY(entries)	[expr $LANG_MAP(num_langs) + 1]

	tpBindVar LANG_CODE LANGUAGEARRAY code c_idx
	tpBindVar LANG_DESC LANGUAGEARRAY name c_idx

	if {$lang==""} {
		tpBindString Language "-"
	} else {
		tpBindString Language $lang
	}

	# Setup type info
	read_type_info

	set type [reqGetArg Type]
	tpBindString TypeDesc "Displaying all news types"

	for {set i 0} {$i < $TYPE_MAP(num_types)} {incr i} {
		set TYPEARRAY($i,code) $TYPE_MAP($i,code)
		set TYPEARRAY($i,name) $TYPE_MAP($i,name)
		if {$TYPEARRAY($i,code) == $type} {
			tpBindString TypeDesc $TYPE_MAP($i,desc)
		}
	}

	set TYPEARRAY($TYPE_MAP(num_types),code) "-"
	set TYPEARRAY($TYPE_MAP(num_types),name) "All"
	set TYPEARRAY(entries)	[expr $TYPE_MAP(num_types) + 1]

	tpBindVar TYPE_CODE TYPEARRAY code t_idx
	tpBindVar TYPE_DESC TYPEARRAY name t_idx

	if {$type=="-" || $type==""} {
		tpBindString Type "-"
		tpBindString TypeDesc "Displaying all news types"
		set type_sql ""
	} else {
		tpBindString Type $type
		set type_sql "and n.type = '${type}'"
	}



	if {$lang=="-" || $lang==""} {
		set lang_sql ""
	} else {
		set lang_sql "and languages like '%${lang}%'"
	}

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		# If view exists then need to pull out only those news items, if news doesn't exist then need to
		# return all news items.
		if {$view=="-" || $view==""} {
			set view_sql ""
		} else {
			set view_sql "and exists (select * from tView v where v.view = '${view}' and v.sort='NEWS' and n.news_id =v.id)"
		}

		if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
			set order_by "19,20,3"
		} else {
			set order_by "3"
		}

		set sql_news [subst {
			select
				'' type,
				-1 disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.name,
				n.info_url,
				n.link_new_window,
				n.link_win_width,
				n.link_win_height,
				n.displayed,
				n.channels,
				n.locations,
				n.type,
				n.id_name,
				g.title grp_title,
				NVL (g.disporder, n.disporder) as merge_disporder,
				g.grp_id as grp_id
			from
				tnews n,
				tnewsgrp g
			where
				(n.type is null or n.type ='') and
						g.grp_id = n.grp_id
				$view_sql

			union

			select
				t.name type,
				t.disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.name,
				n.info_url,
				n.link_new_window,
				n.link_win_width,
				n.link_win_height,
				n.displayed,
				n.channels,
				n.locations,
				n.type,
				n.id_name,
				g.title grp_title,
				NVL (g.disporder, n.disporder) as merge_disporder,
				g.grp_id as grp_id
			from
				tnews n,
				tnewstype t,
				outer tNewsGrp g
			where
				n.type = t.code and
				g.grp_id = n.grp_id
				$type_sql
				$view_sql
			order by
				$order_by
		}]
	} else {
		if {$lang=="-" || $lang==""} {
			set lang_sql ""
		} else {
			set lang_sql "and n.languages like '%${lang}%'"
		}

		if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
		set order_by "20,21,3"
		} else {
		set order_by "3"
		}

		set sql_news [subst {
			select
				'' type,
				-1 disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.name,
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
				g.title grp_title,
				NVL (g.disporder, n.disporder) as merge_disporder,
				g.grp_id as grp_id
			from
				tnews n,
				tNewsGrp g
			where
				g.grp_id = n.grp_id and
				n.type is null or
				n.type =''

			union

			select
				t.name type,
				t.disporder,
				n.disporder,
				n.cr_date,
				NVL(n.from_date,'$default_from') from_date,
				NVL(n.to_date,  '$default_to') to_date,
				n.news_id,
				n.link_title,
				n.name,
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
				g.title grp_title,
				NVL (g.disporder, n.disporder) as merge_disporder,
				g.grp_id as grp_id
			from
				tnews n,
				tnewstype t,
				outer tNewsGrp g
			where
				n.type = t.code and
				g.grp_id = n.grp_id
				$lang_sql
				$type_sql
			order by
						$order_by
		}]
	}

	set sql_bbet {
		select
			title
		from
			tbestbets
		where
			bbet_id	= ?
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
		set NEWS($i,link_title) [db_get_col $rs $i link_title]
		set NEWS($i,name)       [db_get_col $rs $i name]
		if { $NEWS($i,name)!="" } {
			set NEWS($i,title) $NEWS($i,name)
		} else {
			set NEWS($i,title) $NEWS($i,link_title)
		}
		set NEWS($i,new_win)    [db_get_col $rs $i link_new_window]
		set NEWS($i,win_width)  [db_get_col $rs $i link_win_width]
		set NEWS($i,win_height) [db_get_col $rs $i link_win_height]
		set NEWS($i,url)        [db_get_col $rs $i info_url]
		set NEWS($i,highlight)  [db_get_col $rs $i id_name]
		set NEWS($i,displayed)  [db_get_col $rs $i displayed]
		set NEWS($i,channels)   [db_get_col $rs $i channels]
		set NEWS($i,locations)  [db_get_col $rs $i locations]

		set NEWS($i,disporder)  [db_get_col $rs $i merge_disporder]
		set NEWS($i,grp_title)  [db_get_col $rs $i grp_title]
		set NEWS($i,grp_id)     [db_get_col $rs $i grp_id]

		if {![OT_CfgGet FUNC_VIEWS 0]} {set NEWS($i,languages)  [db_get_col $rs $i languages]}


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

	tpBindVar status         NEWS status     news_idx
	tpBindVar from_date      NEWS from_date  news_idx
	tpBindVar to_date        NEWS to_date    news_idx
	tpBindVar type           NEWS type       news_idx
	tpBindVar title          NEWS title      news_idx
	tpBindVar link_title     NEWS link_title news_idx
	tpBindVar name           NEWS name       news_idx
	tpBindVar news_id        NEWS news_id    news_idx
	tpBindVar link_url       NEWS url        news_idx
	tpBindVar highlight      NEWS highlight  news_idx
	tpBindVar new_window     NEWS new_win    news_idx
	tpBindVar new_window     NEWS new_win    news_idx
	tpBindVar win_width      NEWS win_width  news_idx
	tpBindVar win_height     NEWS win_width  news_idx
	tpBindVar channels       NEWS channels   news_idx
	tpBindVar locations      NEWS languages  news_idx

	tpBindVar item_grp_id      NEWS grp_id    news_idx
	tpBindVar item_grp_title   NEWS grp_title news_idx

	if {![OT_CfgGet FUNC_VIEW_FLAGS 0]} {tpBindVar languages   NEWS languages news_idx}

	if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
		bind_news_grps
	}

	asPlayFile -nocache news_list.html

	unset NEWS
}


#----------------------------------------------------------------------------
# Procedure :   go_news_highlight
# Description : load up an existing news highlight
#----------------------------------------------------------------------------
proc go_news_highlight {{errored 0}} {

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
		asPlayFile -nocache news.html
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


	if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
		tpSetVar grp_id [db_get_col $rs grp_id]
	}

	if {$type==""} {
		tpBindString Type "-"
	} else {
		tpBindString Type $type
	}


		tpBindString fromDate $from_date

		tpBindString toDate   $to_date

		tpBindString List_View  [reqGetArg list_view]
		tpBindString List_Type  [reqGetArg list_type]


		foreach n [db_get_colnames $rs] {
			if {$n == "link_title" || $n == "title"} {
				# Make JS safe
				tpBindString $n [ADMIN::EXTRACONT::safe_javascript [db_get_col $rs $n]]
				ob_log::write INFO "go_news_highlight: tpBindString $n: value: [ADMIN::EXTRACONT::safe_javascript [db_get_col $rs $n]]"
			} elseif {$n == "name"} {
				# "tpBindString name" would be overwritten by make_location_binds
				tpBindString news_name [ADMIN::EXTRACONT::safe_javascript [db_get_col $rs $n]]
				ob_log::write INFO "go_news_highlight: tpBindString news_name: value: [ADMIN::EXTRACONT::safe_javascript [db_get_col $rs $n]]"
			} elseif {$n == "win_resizable" ||
				        $n == "win_scrollbar" ||
				        $n == "win_menubar"   ||
				        $n == "link_heading"  ||
				        $n == "link_text"} {

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


		# Build up a list of languages that will need to be translated with the current view list
		set stmt [inf_prep_sql $DB $SQL(get_lang_info)]
		set rs   [inf_exec_stmt $stmt $news_id]
		inf_close_stmt $stmt

		set lang_list [list]
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			lappend lang_list [db_get_col $rs $i name]
		}
		if {[llength $lang_list] < 1} {set lang_list "No Views Selected"}
		tpBindString lang_list $lang_list

	}

	if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
		# for drop down
		bind_news_grps
	}

	if [OT_CfgGet FUNC_NEWS_TAGS 0] {
		bind_news_tags $news_id
	}

	tpSetVar Insert 0
	tpSetVar news_location $news_location

	asPlayFile -nocache news.html
}

#
# Bind up the tags for display on the news page (tNewsTag and tNewsTagLink).
# Tags are per news type (for example, there are a set
# of tags for type Games and a different set for type Promo)
#
proc bind_news_tags { news_id } {
	global DB NEWS_TAGS
	variable SQL

	OT_LogWrite 2 "bind_news_tags ($news_id)"

	catch {unset NEWS_TAGS}

	# in case something bad happens...
	tpSetVar NumNewsTypes 0

	set stmt [inf_prep_sql $DB $SQL(get_news_tags)]

	if {[catch {set rs [inf_exec_stmt $stmt $news_id]} msg]} {
		inf_close_stmt $stmt
		OT_LogWrite 2 "bind_news_tags: Error executing get_news_tags - $msg"
		return 0
	}
	inf_close_stmt $stmt
	set nrows [db_get_nrows $rs]

	set cur_type ""
	set num_types -1
	set num_tags 0

	for {set i 0} {$i < $nrows} {incr i} {

		set type_id [db_get_col $rs $i type_id]

		if {$cur_type != $type_id} {
			if {$cur_type != ""} {
				set NEWS_TAGS($num_types,num_tags) $num_tags
			}
			set cur_type $type_id
			incr num_types
			set num_tags 0
			set NEWS_TAGS($num_types,type_id) $type_id
			set NEWS_TAGS($num_types,code)    [db_get_col $rs $i code]
		}

		foreach c  {tag_id desc selected} {
			set NEWS_TAGS($num_types,$num_tags,$c) [db_get_col $rs $i $c]
		}
		set NEWS_TAGS($num_types,$num_tags,selected) [expr {($NEWS_TAGS($num_types,$num_tags,selected))? {checked="checked"}:{}}]
		incr num_tags
	}
	db_close $rs

	set NEWS_TAGS($num_types,num_tags) $num_tags

	ob::log::write_array 10 NEWS_TAGS

	tpSetVar  NumNewsTypes [incr num_types]
	tpBindVar tagTypeId    NEWS_TAGS type_id  news_type_idx
	tpBindVar tagTypeCode  NEWS_TAGS code     news_type_idx
	tpBindVar tagTagId     NEWS_TAGS tag_id   news_type_idx news_tag_idx
	tpBindVar tagDesc      NEWS_TAGS desc     news_type_idx news_tag_idx
	tpBindVar tagSelected  NEWS_TAGS selected news_type_idx news_tag_idx
	return 1
}

#----------------------------------------------------------------------------
# Procedure :   go_new_news_highlight
# Description : load up a blank template for inserting a news item
#----------------------------------------------------------------------------
proc go_new_news_highlight {{new 0}} {

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



	tpSetVar Insert 1
	if {$new!=1} {
		make_channel_binds "I" -
		make_location_binds "-" -
		make_language_binds $lang -
	}

	if {[OT_CfgGet FUNC_VIEW_FLAGS 0]} {
		make_view_binds $view -
	}

	# Make sure link_text and link_heading are checked by default
	tpBindString link_text "checked=\"checked\""
	tpBindString link_heading "checked=\"checked\""

	if [OT_CfgGet FUNC_NEWS_TAGS 0] {
		bind_news_tags -1
	}

	if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {
		tpSetVar grp_id -1
		bind_news_grps
	}

	asPlayFile -nocache news.html
}


#----------------------------------------------------------------------------
# Procedure :   ins_news_highlight
# Description : Insert a new news item
#----------------------------------------------------------------------------
proc ins_news_highlight {} {

	global   DB
	variable SQL
	variable default_from
	variable default_to

	if {![op_allowed UpdHomepage]} {
		tpBindString Error "User does not have UpdateHomepage permission"
		go_news_highlight_list
	}

	foreach a {
		link_title
		name
		info_url
		small_image
		large_image
		image_align
		item_pos
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
		toDate
		news
		grp_id
		bbet_id
	} {
		set $a [reqGetArg $a]
	}

	# Deal with Y/N checkboxes
	foreach a {
		win_resizable
		win_scrollbar
		win_menubar
		link_heading
		link_text
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

	if {$disporder == ""} {set disporder 0}

	if {$fromDate == "" } {
		set from_date $default_from
	} else {
		set from_date "$fromDate"
	}
	if {$toDate == "" } {
		set to_date $default_to
	} else {
		set to_date "$toDate"
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
			$name \
			$small_image \
			$large_image \
			$image_align\
			$disporder  \
			$displayed \
			$languages \
			$location \
			$locations \
			$item_pos \
			$channels \
			$link_new_window \
			$link_heading \
			$link_text \
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
			$win_menubar \
			$grp_id]} msg]} {
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

	if {$err != 1 && [OT_CfgGet FUNC_NEWS_TAGS 0]} {
		ins_news_tags $news_id
	}

	if {$err == 1} {
		foreach a {
			link_title
			name
			info_url
			small_image
			large_image
			image_align
			disporder
			displayed
			channels
			languages
			item_pos
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
			toDate
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
			link_heading
			link_text
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
	} elseif {$info_url!="" && $id_key!=""} {
		err_bind "Cannot have both link URL and bet highlight"
		return 0
	}
	return 1
}

#----------------------------------------------------------------------------
# Procedure :   go_upd_news_highlight
# Description : wrapper for update news
#----------------------------------------------------------------------------
proc go_upd_news_highlight {} {

	global   DB
	variable SQL

	if {![op_allowed UpdHomepage]} {
		tpBindString Error "User does not have UpdateHomepage permission"
		go_news_highlight_list
	}

	set ret 0

	set SubmitName [reqGetArg SubmitName]

	switch -- $SubmitName {
		Delete {
			set ret [del_news_highlight]
		}
		Update {
			set ret [upd_news_highlight]
		}
		Insert {
			set ret [ins_news_highlight]
		}
	}

	#
	# Flush the DB Cache for this type of highlight
	#
	set news_type_code [reqGetArg news_type]

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


	# ^^^^^ end flush code ^^^^^^^

	if {$ret == 0} {
		if {$SubmitName=="Insert"} {
			go_new_news_highlight 1
		} else {
			go_news_highlight 1
		}
	} else {
		go_news_highlight_list
	}
}

#----------------------------------------------------------------------------
# Procedure :   upd_news_highlight
# Description : update the news highlight and update the views associated
#----------------------------------------------------------------------------
proc upd_news_highlight {} {

	global   DB
	variable SQL
	variable default_from
	variable default_to

	OT_LogWrite 16 "in upd_news_highlight"

	foreach a {
		news_id
		link_title
		name
		info_url
		small_image
		large_image
		image_align
		disporder
		displayed
		item_pos
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
		toDate
		news_type
		grp_id
		bbet_id
		type
		List_View
		List_Type
		views
	} {
		set $a [reqGetArg $a]
	}

	# Deal with Y/N checkboxes
	foreach a {
		win_resizable
		win_scrollbar
		win_menubar
		link_heading
		link_text
	} {
		if {[reqGetArg $a] == "on"} {
			set $a "Y"
		} else {
			set $a "N"
		}
	}


	if {([string first "XGAME" $id_level] == -1 && [string first "CATEGORY" $id_level] == -1 ) || [OT_CfgGet FUNC_EV_CATEGORY_ID 0]} {
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
	if {$fromDate == ""} {
		set from_date $default_from
	} else {
		set from_date "$fromDate"
	}
	if {$toDate == "" } {
		set to_date $default_to
	} else {
		set to_date   "$toDate"
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
			$name\
			$small_image\
			$large_image\
			$image_align\
			$disporder\
			$displayed\
			$languages\
			$location\
			$locations\
			$item_pos\
			$channels\
			$link_new_window\
			$link_heading\
			$link_text\
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
			$win_menubar\
			$grp_id} msg] {
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

	if {$err != 1 && [OT_CfgGet FUNC_NEWS_TAGS 0]} {
		upd_news_tags $news_id
	}

	if {$err == 1} {
		foreach a {
			news_id
			link_title
			name
			info_url
			small_image
			large_image
			image_align
			disporder
			displayed
			channels
			languages
			item_pos
			bbet_id
			url_type
			link_new_window
			link_win_width
			link_win_height
			location
			locations
			tag
			type
			id_level
			id_key
			id_name
			news
			fromDate
			toDate
			List_View
			List_Type
			news_type
			views
			grp_id
		} {
			tpBindString $a [set $a]
		}

		# Rebind checkboxes
		foreach a {
			win_resizable
			win_scrollbar
			win_menubar
			link_heading
			link_text
		} {
			if {[reqGetArg $a] == "on"} {
				tpBindString $a "checked=\"checked\""
			}
		}

		tpBindString Type [reqGetArg news_type]

		make_channel_binds  $channels -
		make_location_binds $locations - 0 [reqGetArg location]
		make_language_binds $languages -

		if [OT_CfgGet FUNC_NEWS_TAGS 0] {
			bind_news_tags $news_id
		}

		return 0
	}
	return 1
}

#
# Manipulate the news tags tables (tNewsTag and tNewsTagLink)
#

#
# Delete and then insert the links for tNewsTagLink.
#
proc upd_news_tags { news_id } {
	if [del_news_tags $news_id] {
		ins_news_tags $news_id
	}
}

#
# Delete the links from tNewsTagLink
#
proc del_news_tags { news_id } {
	global DB
	variable SQL

	set stmt [inf_prep_sql $DB $SQL(del_news_tags)]

	if {[catch {set rs [inf_exec_stmt $stmt $news_id]} msg]} {
		inf_close_stmt $stmt
		OT_LogWrite 2 "Error executing del_news_tags($news_id) - $msg"
		err_bind {Error deleting news tags}
		return 0
	}
	inf_close_stmt $stmt
	return 1
}

#
# Insert the links into tNewsTagLink
#
proc ins_news_tags { news_id } {
	global DB
	variable SQL

	set num [reqGetNumVals]
	set stmt [inf_prep_sql $DB $SQL(ins_news_tag)]

	for {set i 0} {$i < $num} {incr i} {
		if {[regexp {newstag_([0-9])+} [reqGetNthName $i] all tag_id]} {
			if {[catch {set rs [inf_exec_stmt $stmt $news_id $tag_id]} msg]} {
				inf_close_stmt $stmt
				OT_LogWrite 2 "Error executing ins_news_tag($news_id,$tag_id) - $msg"
				err_bind {Error inserting news tags}
				return 0
			}
		}
	}
	inf_close_stmt $stmt
	return 1
}

#----------------------------------------------------------------------------
# Procedure :   del_news_highlight
# Description : delete a news item and associated view information from tnewsview
# Author :      JDM 30-04-2002
#----------------------------------------------------------------------------
proc del_news_highlight {} {

	global   DB
	variable SQL

	set err 0
	set news_id [reqGetArg news_id]

	if [OT_CfgGet FUNC_NEWS_TAGS 0] {
		del_news_tags $news_id
	}

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

	if {$err == 1} {
		foreach a {
			link_title
			name
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

#
# Extra functionallity for news grps
#
if {[OT_CfgGet FUNC_NEWS_GRPS 0]} {

	set SQL(get_news_grps) [subst {
	select *
	from tNewsGrp
	order by disporder
	}]

	set SQL(get_grp) [subst {
	select *
	from tNewsGrp
	where grp_id = ?
	}]

	set SQL(upd_grp) [subst {
	update tNewsGrp
	set
			title = ?,
			disporder = ?,
			text      = ?
	where
			grp_id = ?
	}]

	set SQL(ins_grp) [subst {
	execute procedure pInsNewsGrp (
		p_title      = ?,
		p_disporder  = ?,
		p_text       = ?
	)
	}]

	set SQL(del_grp) [subst {
	execute procedure pDelNewsGrp (
		p_grp_id      = ?
	)
	}]

	#
	# Binds up info for all news groups
	#
	proc bind_news_grps {} {
	global NEWS_GRPS DB
	variable SQL

	set stmt    [inf_prep_sql $DB $SQL(get_news_grps)]
	set rs      [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set NEWS_GRPS($i,grp_id) [db_get_col $rs $i grp_id]
		set NEWS_GRPS($i,title) [db_get_col $rs $i title]
		set NEWS_GRPS($i,disporder) [db_get_col $rs $i disporder]
	}
	db_close $rs

	set NEWS_GRPS(num_grps) $nrows

	tpBindVar grp_id NEWS_GRPS grp_id grp_idx
	tpBindVar grp_title NEWS_GRPS title grp_idx
	tpBindVar grp_disporder NEWS_GRPS disporder grp_idx
	} ;# end bind_news_group

	#
	# Binds up info for a particular news group
	#
	proc go_news_group {} {
	global DB
	variable SQL

	set grp_id [reqGetArg grp_id]

	OT_LogWrite 16 "in go_news_group (grp_id => $grp_id)"

	if {$grp_id == -1} {
		tpSetVar do_insert 1
	} else {

		set stmt    [inf_prep_sql $DB $SQL(get_grp)]
		set rs      [inf_exec_stmt $stmt $grp_id]
		inf_close_stmt $stmt

		foreach n {title disporder text} {
		tpBindString $n [db_get_col $rs 0 $n]
		}

		db_close $rs
	}
	tpBindString grp_id $grp_id
	asPlayFile news_group.html
	} ;# end go_news_group

	#
	# Performs inserts, updates and deletes for news groups
	#
	proc upd_news_group {} {
	global DB
	variable SQL

	foreach n {grp_id title disporder text} {
		set $n [reqGetArg $n]
	}

	set err 0
	if {$disporder == ""} {
		set dispo 0
	} else {
		set dispo $disporder
	}

	switch -exact [reqGetArg button] {
		Insert {
		OT_LogWrite 16 "do an insert"

		if {$title == ""} {
			err_bind "Must enter value for title."
			set err 1
			tpSetVar do_insert 1
		} else {
			set stmt [inf_prep_sql $DB $SQL(ins_grp)]

			if [catch {inf_exec_stmt $stmt $title $dispo &text} msg] {
			err_bind $msg
			set err 1
			tpSetVar do_insert 1
			}
			inf_close_stmt $stmt
		}
		}
		Update {
		OT_LogWrite 16 "do an update"

		if {$title == ""} {
			err_bind "Must enter value for title."
			set err 1
		} else {
			set stmt [inf_prep_sql $DB $SQL(upd_grp)]

			if [catch {inf_exec_stmt $stmt $title $dispo $text $grp_id} msg] {
			err_bind $msg
			set err 1
			}
			inf_close_stmt $stmt
		}
		}
		Delete {
		OT_LogWrite 16 "do a delete"

		set stmt [inf_prep_sql $DB $SQL(del_grp)]
		if [catch {inf_exec_stmt $stmt $grp_id} msg] {
			err_bind $msg
			set err 1
		}
		inf_close_stmt $stmt
		}
	} ;# end switch

	if {$err} {
		# play back news_group.html with error msg
		foreach n {grp_id title disporder text} {
		tpBindString $n [set $n]
		}
		go_news_group
	} else {
		# go back to the news list
		go_news_highlight_list
	}
	} ;# end upd_news_group

} ;# end if FUNC_NEWS_GRPS

} ;# end namespace
