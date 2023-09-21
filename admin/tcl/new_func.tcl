# ==============================================================
# $Id: new_func.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::NEW_FUNC {

asSetAct ADMIN::NEW_FUNC::go_new_func_list       [namespace code go_new_func_list]
asSetAct ADMIN::NEW_FUNC::go_edit_new_func    [namespace code go_edit_new_func]
asSetAct ADMIN::NEW_FUNC::go_new_func     [namespace code go_new_func]
asSetAct ADMIN::NEW_FUNC::go_upd_new_func     [namespace code go_upd_new_func]


#
# generate the best bets list, this is grouped by channel so we must
# loop over the result set onece for each channel to build up the array
#
proc go_new_func_list {} {

	global NEW_FUNC CHANNEL_MAP DB LANG_MAP LANGUAGEARRAY

	if [info exists LANGUAGEARRAY] {
		unset LANGUAGEARRAY
	}

	read_language_info

	for {set i 0} {$i < $LANG_MAP(num_langs)} {incr i} {
		set LANGUAGEARRAY($i,code) $LANG_MAP($i,code)
		set LANGUAGEARRAY($i,name) $LANG_MAP($i,name)
	}

	set LANGUAGEARRAY($LANG_MAP(num_langs),code) "-"
	set LANGUAGEARRAY($LANG_MAP(num_langs),name) "All"

	set LANGUAGEARRAY(entries)	[expr $LANG_MAP(num_langs) + 1]

	tpBindVar LANG_CODE LANGUAGEARRAY code c_idx
	tpBindVar LANG_DESC LANGUAGEARRAY name c_idx

	set lang [reqGetArg Language]

	if {$lang==""} {
		tpBindString Language "-"
	} else {
		tpBindString Language $lang
	}


	set from_date  "9999-12-31 00:00:00"


	if {$lang=="-" || $lang==""} {
		set lang_sql ""
	} else {
		set lang_sql "and languages like '%${lang}%'"
	}

	set sql {
		select
			new_func_id,
			title,
			desc,
			display,
			cr_date,
			NVL(languages,"&nbsp;") languages,
			NVL(from_date,'1900-01-01 00:00:00') from_date
		from
			tNewFunc
		where
			from_date <= '$from_date'
		$lang_sql
		order by
			cr_date desc
	}

	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows  $rs]

	for {set row 0} {$row < $nrows} {incr row} {
		set NEW_FUNC($row,new_func_id) [db_get_col $rs $row new_func_id]
		set NEW_FUNC($row,cr_date) [db_get_col $rs $row cr_date]
		set NEW_FUNC($row,title) [db_get_col $rs $row title]
		set NEW_FUNC($row,desc) [db_get_col $rs $row desc]
		set NEW_FUNC($row,languages) [db_get_col $rs $row languages]
		set NEW_FUNC($row,display) [db_get_col $rs $row display]
		set NEW_FUNC($row,from_date) [db_get_col $rs $row from_date]
	}
	set NEW_FUNC(nrows)	$nrows
	tpBindVar new_func_id NEW_FUNC new_func_id  func_idx
	tpBindVar cr_date     NEW_FUNC cr_date      func_idx
	tpBindVar title       NEW_FUNC title        func_idx
	tpBindVar desc        NEW_FUNC desc         func_idx
	tpBindVar languages   NEW_FUNC languages    func_idx
	tpBindVar from_date   NEW_FUNC from_date    func_idx
	tpBindVar display	  NEW_FUNC display	    func_idx


	db_close $rs

	asPlayFile -nocache new_func_list.html

	unset NEW_FUNC
}


proc go_edit_new_func {} {

	global DB

	set sql {
		select
			new_func_id,
			cr_date,
			title,
			desc,
			from_date,
			languages,
			display
		from
			tNewFunc
		where
			new_func_id = $new_func_id
		order by
			cr_date desc
	}

	set new_func_id [reqGetArg new_func_id]
	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	foreach n [db_get_colnames $rs] {
		tpBindString $n [db_get_col $rs $n]
	}

	set from_date [db_get_col $rs from_date]


	if {$from_date == ""} {
		set from_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	}

	tpBindString fromDate [string range $from_date 0 9]
	tpBindString fromTime [string range $from_date 11 end]

	if {[db_get_col $rs display] == "N"} {
		tpBindString not_displayed selected
	}

	make_language_binds [db_get_col $rs languages] -

	db_close $rs

	tpSetVar Insert 0

	tpBindString new_func_action go_upd_new_func

	asPlayFile -nocache new_func.html
}


proc go_new_func {} {

	global DB

	set sql {
		select default_lang from tControl
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set lang [db_get_col $rs default_lang]

	db_close $rs

	tpSetVar Insert 1

	make_channel_binds I -
	make_language_binds $lang -

	tpBindString title "New Functionality"

	set from_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	tpBindString fromDate [string range $from_date 0 9]
	tpBindString fromTime [string range $from_date 11 end]

	asPlayFile -nocache new_func.html
}


proc ins_new_func {} {

	global DB

	set sql {
		insert into tNewFunc (
			title,
			desc,
			languages,
			display,
			from_date
		) values (
			?, ?, ?, ?, ?
		  )
	}

	foreach a {
		title
		desc
		display
		fromDate
		fromTime
	} {
		set $a [reqGetArg $a]
	}


	set languages [make_language_str]

	set from_date "$fromDate $fromTime"




	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt\
		$title\
		$desc\
		$languages\
		$display\
		$from_date
	inf_close_stmt $stmt
	return 1
}


proc go_upd_new_func {} {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_new_func_list
		return
	}

	if {![op_allowed UpdHomepage]} {
		tpBindString Error "User does not have UpdateHomepage permission"
		go_new_func_list
		return
	}

	if {$act == "Delete"} {
		set ret [del_new_func]
	} elseif {$act == "Update"} {
		set ret [upd_new_func]
	} else {
		if {![ins_new_func]} {
			return
		}
	}

	go_new_func_list
}

proc upd_new_func {} {

	global DB

	set sql {
		update tNewFunc set
			title     = ?,
			desc      = ?,
			languages = ?,
			display   = ?,
			from_date = ?
		where
			new_func_id   = ?
	}

	set title	      [reqGetArg title]
	set desc          [reqGetArg desc]
	set display       [reqGetArg display]
	set new_func_id   [reqGetArg new_func_id]
	set languages     [make_language_str]
	set fromDate      [reqGetArg fromDate]
	set fromTime      [reqGetArg fromTime]
	set from_date "$fromDate $fromTime"

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt\
		$title\
		$desc\
		$languages\
		$display\
		$from_date\
		$new_func_id
	inf_close_stmt $stmt

	return 1
}


proc del_new_func {} {

	global DB

	set sql {
		delete from
			tNewFunc
		where
			new_func_id   = $new_func_id
	}

	set new_func_id [reqGetArg new_func_id]
	set stmt [inf_prep_sql $DB [subst $sql]]
	inf_exec_stmt $stmt
	inf_close_stmt $stmt

	return 1
}


}
