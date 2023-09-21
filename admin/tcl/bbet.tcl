# ==============================================================
# $Id: bbet.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BESTBETS {

asSetAct ADMIN::BESTBETS::go_bbets            [namespace code go_bbets_list]
asSetAct ADMIN::BESTBETS::go_edit_bbet        [namespace code go_bbet]
asSetAct ADMIN::BESTBETS::go_new_bbet         [namespace code go_new_bbet]
asSetAct ADMIN::BESTBETS::go_upd_bbet         [namespace code go_upd_bbet]
asSetAct ADMIN::BESTBETS::autosettler         [namespace code go_bbet_category]
if {![OT_CfgGet FUNC_CATEGORY_COUP 0] && ![OT_CfgGet FUNC_EV_CATEGORY_ID 0] } {
	asSetAct ADMIN::BESTBETS::go_bbet_dd      [namespace code go_bbet_classes]
} else {
	asSetAct ADMIN::BESTBETS::go_bbet_dd      [namespace code go_bbet_category]
	asSetAct ADMIN::BESTBETS::go_bbet_class   [namespace code go_bbet_classes_for_cat]
}

asSetAct ADMIN::BESTBETS::go_bbet_types       [namespace code go_bbet_types]
asSetAct ADMIN::BESTBETS::go_bbet_events      [namespace code go_bbet_events]
asSetAct ADMIN::BESTBETS::go_bbet_markets     [namespace code go_bbet_markets]
asSetAct ADMIN::BESTBETS::go_bbet_evocgrps    [namespace code go_bbet_evocgrps]
asSetAct ADMIN::BESTBETS::go_bbet_selns       [namespace code go_bbet_selns]
asSetAct ADMIN::BESTBETS::go_bbet_xgame_types [namespace code go_bbet_xgame_types]
asSetAct ADMIN::BESTBETS::go_bbet_xgame_sorts [namespace code go_bbet_xgame_sorts]
asSetAct ADMIN::BESTBETS::go_bbet_game_sorts  [namespace code go_bbet_game_sorts]


#
# generate the best bets list, this is grouped by channel so we must
# loop over the result set onece for each channel to build up the array
#
proc go_bbets_list {} {

	global BBETS CHANNEL_MAP DB LANG_MAP LANGUAGEARRAY

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

	set to_date    "1900-01-01 00:00:00"
	set from_date  "9999-12-31 00:00:00"
	set useEffDate [reqGetArg UseEffDate]

	if {$useEffDate == "Y"} {
		set eff_date  [reqGetArg EffDate]
		set eff_time  [reqGetArg EffTime]
		set from_date "$eff_date $eff_time"
		set to_date   $from_date

		tpBindString EffDate $eff_date
		tpBindString EffTime $eff_time
		tpBindString UseEffDate "checked"
	} else {
		set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		tpBindString EffDate [string range $now 0 9]
		tpBindString EffTime [string range $now 11 end]
	}

	if {$lang=="-" || $lang==""} {
		set lang_sql ""
	} else {
		set lang_sql "and languages like '%${lang}%'"
	}

	set sql {
		select
			bbet_id,
			id_key,
			id_level,
			id_name,
			disp_title title,
			desc,
			image,
			disporder,
			cr_date,
			channels,
			NVL(languages,"&nbsp;") languages,
			NVL(from_date,'1900-01-01 00:00:00') from_date,
			NVL(to_date, '9999-12-31 23:59:59') to_date,
			displayed
		from
			vBestBets
		where
			from_date <= '$from_date'
		and to_date   >= '$to_date'
		$lang_sql
		order by
			disporder,
			cr_date desc
	}

	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows    $rs]
	set names [db_get_colnames $rs]

	make_channel_binds "" -

	set nchans 0

	for {set i 0} {$i < $CHANNEL_MAP(num_channels)} {incr i} {

		set ccode $CHANNEL_MAP($i,code)
		set nbbets 0

		for {set j 0} {$j < $nrows} {incr j} {

			set channels [db_get_col $rs $j channels]

			if {[string first $ccode $channels] < 0} {
				continue
			}
			set BBETS($j,used) 1


			foreach n $names {
				set BBETS($nchans,$nbbets,$n) [db_get_col $rs $j $n]
			}
			incr nbbets
		}

		if {$nbbets > 0} {
			set BBETS($nchans,name) $CHANNEL_MAP($i,name)
			set BBETS($nchans,num_bbets) $nbbets
			incr nchans
		}
	}


	#
	# all the unreferenced bbets are put in a special channel
	#
	set nbbets 0

	for {set j 0} {$j < $nrows} {incr j} {
		if {[info exists BBETS($j,used)]} {
			continue
		}
		foreach n $names {
			set BBETS($nchans,$nbbets,$n) [db_get_col $rs $j $n]
		}
		incr nbbets
	}

	if {$nbbets > 0} {
		set BBETS($nchans,name) Unused
		set BBETS($nchans,num_bbets) $nbbets
		incr nchans
	}

	set BBETS(num_chans) $nchans

	tpBindVar channel   BBETS name      chan_idx
	tpBindVar languages BBETS languages chan_idx bbet_idx
	tpBindVar from_date BBETS from_date chan_idx bbet_idx
	tpBindVar to_date   BBETS to_date   chan_idx bbet_idx
	tpBindVar bbet_id   BBETS bbet_id   chan_idx bbet_idx
	tpBindVar title     BBETS title     chan_idx bbet_idx
	tpBindVar id_level  BBETS id_level  chan_idx bbet_idx
	tpBindVar id_name   BBETS id_name   chan_idx bbet_idx
	tpBindVar displayed BBETS displayed chan_idx bbet_idx

	db_close $rs

	asPlayFile -nocache bbet_list.html

	unset BBETS
}


proc go_bbet {} {

	global CHANNEL_MAP DB

	set sql {
		select
			bbet_id,
			id_key,
			id_level,
			id_name,
			title,
			desc,
			image,
			disporder,
			cr_date,
			from_date,
			to_date,
			languages,
			channels,
			displayed
		from
			vBestBets
		where
			bbet_id = $bbet_id
		order by
			disporder,
			cr_date desc
	}

	set bbet_id [reqGetArg bbet_id]
	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	foreach n [db_get_colnames $rs] {
		tpBindString $n [db_get_col $rs $n]
	}

	set from_date [db_get_col $rs from_date]
	set to_date   [db_get_col $rs to_date]

	if {$from_date == ""} {
		set from_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	}
	if {$to_date == ""} {
		set to_date "9999-12-31 23:59:59"
	}

	tpBindString fromDate [string range $from_date 0 9]
	tpBindString fromTime [string range $from_date 11 end]
	tpBindString toDate   [string range $to_date 0 9]
	tpBindString toTime   [string range $to_date 11 end]

	if {[db_get_col $rs displayed] == "N"} {
		tpBindString not_displayed selected
	}

	make_channel_binds [db_get_col $rs channels] -
	make_language_binds [db_get_col $rs languages] -

	db_close $rs

	tpSetVar Insert 0

	tpBindString bbet_action go_upd_bbet

	asPlayFile -nocache bbet.html
}


proc go_new_bbet {} {

	global DB

	set sql {
		select default_lang from tControl
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set lang [db_get_col $rs default_lang]

	tpSetVar Insert 1

	make_channel_binds I -
	make_language_binds $lang -

	tpBindString title "New Bet Highlight"

	set from_date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	tpBindString fromDate [string range $from_date 0 9]
	tpBindString fromTime [string range $from_date 11 end]
	tpBindString toDate   "9999-12-31"
	tpBindString toTime   "23:59:59"

	asPlayFile -nocache bbet.html
}


proc ins_bbet {} {

	global DB

	set sql {
		insert into tbestBets (
			id_key,
			id_level,
			title,
			desc,
			image,
			disporder,
			channels,
			languages,
			from_date,
			to_date,
			displayed
		) values (
			?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
		)
	}

	foreach a {key level title desc image disporder displayed fromDate fromTime toDate toTime} {
		set $a [reqGetArg $a]
	}

	set channels  [make_channel_str]
	set languages [make_language_str]

	set from_date "$fromDate $fromTime"
	set to_date   "$toDate $toTime"

	if {$key == "" || $level == ""} {
		foreach a {key level title desc image disporder displayed} {
			tpBindString $a [reqGetArg $a]
		}
		tpSetVar Insert 1
		make_channel_binds $channels -
		tpBindString bbet_action go_ins_bbet
		asPlayFile -nocache bbet.html
		return 0
	}

	if {$disporder == ""} {
		set disporder 0
	}

	OT_LogWrite 2 "$from_date, $to_date"

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt\
		$key\
		$level\
		$title\
		$desc\
		$image\
		$disporder\
		$channels\
		$languages\
		$from_date\
		$to_date\
		$displayed

	inf_close_stmt $stmt
	return 1
}


proc go_upd_bbet {} {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_bbets_list
		return
	}

	if {![op_allowed UpdHomepage]} {
		tpBindString Error "User does not have UpdateHomepage permission"
		go_bbets_list
		return
	}

	if {$act == "Delete"} {
		set ret [del_bbet]
	} elseif {$act == "Update"} {
		set ret [upd_bbet]
	} else {
		if {![ins_bbet]} {
			return
		}
	}

	go_bbets_list
}

proc upd_bbet {} {

	global DB

	set sql {
		update tBestBets set
			id_key    = ?,
			id_level  = ?,
			title     = ?,
			desc      = ?,
			image     = ?,
			disporder = ?,
			channels  = ?,
			languages = ?,
			from_date = ?,
			to_date   = ?,
			displayed = ?
		where
			bbet_id   = ?
	}

	set key       [reqGetArg key]
	set level     [reqGetArg level]
	set title     [reqGetArg title]
	set desc      [reqGetArg desc]
	set image     [reqGetArg image]
	set disporder [reqGetArg disporder]
	set displayed [reqGetArg displayed]
	set bbet_id   [reqGetArg bbet_id]
	set channels  [make_channel_str]
	set languages [make_language_str]
	set fromDate  [reqGetArg fromDate]
	set fromTime  [reqGetArg fromTime]
	set toDate    [reqGetArg toDate]
	set toTime    [reqGetArg toTime]
	set from_date "$fromDate $fromTime"
	set to_date   "$toDate $toTime"

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt\
		$key\
		$level\
		$title\
		$desc\
		$image\
		$disporder\
		$channels\
		$languages\
		$from_date\
		$to_date\
		$displayed\
		$bbet_id

	inf_close_stmt $stmt

	return 1
}


proc del_bbet {} {

	global DB

	set sql {
		delete from
			tBestBets
		where
			bbet_id   = $bbet_id
	}

	set bbet_id [reqGetArg bbet_id]
	set stmt    [inf_prep_sql $DB [subst $sql]]

	inf_exec_stmt $stmt

	inf_close_stmt $stmt

	return 1
}

#
# Generate category list
#
proc go_bbet_category {} {
	global DB

	if {[OT_CfgGet FUNC_EV_CATEGORY_ID 0]} {
		set qry_ev_cat_id ", ev_category_id"
	} else {
		set qry_ev_cat_id ""
	}

	set sql [subst {
		select
			category
			$qry_ev_cat_id
		from
			tEvCategory
		order by
			disporder
	}]

	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpSetVar show_link 1

	if {[OT_CfgGet FUNC_EV_CATEGORY_ID 0]} {
		tpBindTcl id   "sb_res_data $rs dd_idx ev_category_id"
		tpBindTcl key  "sb_res_data $rs dd_idx ev_category_id"
	} else {
		tpBindTcl id   "sb_res_data $rs dd_idx category"
		tpBindTcl key  "sb_res_data $rs dd_idx category"
	}

	tpBindTcl name "sb_res_data $rs dd_idx category"

	tpBindString level   CATEGORY
	tpSetVar     level   CATEGORY
	tpBindString title   Categories
	tpBindString link_action ADMIN::BESTBETS::go_bbet_class
	tpBindString index   [reqGetArg index]
	tpBindString index   [reqGetArg index]
    if { [reqGetArg type] == "autosettler" } {
		tpBindString remove_links "Yes"
	        tpBindString type    "autosettler"
	        tpBindString back    "No"
	} else {
	        tpBindString type    [reqGetArg type]
	}
	asPlayFile -nocache bbet_dd.html

	db_close $rs
}


#
# Generate class list
#
proc go_bbet_classes {} {
	global DB
	set sql {
		select
			c.ev_class_id,
			c.name as class_name,
			c.disporder
		from
			tEvClass c
		order by
			c.disporder
	}

	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpSetVar show_link 1

	tpBindTcl id   "sb_res_data $rs dd_idx ev_class_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_class_id"
	tpBindTcl name "sb_res_data $rs dd_idx class_name"

	tpBindString level   CLASS
	tpSetVar     level   CLASS
	tpBindString title   Classes
	tpBindString link_action ADMIN::BESTBETS::go_bbet_types
	tpBindString type    [reqGetArg type]
	asPlayFile -nocache bbet_dd.html

	db_close $rs
}

#
# Generate class list
#
proc go_bbet_classes_for_cat {} {
	global DB

	if { ([OT_CfgGet FUNC_EV_CATEGORY_ID 0]) && ([reqGetArg type] != "autosettler") } {
		set sql {
			select distinct
				'CL' as type,
				'CL' || c.ev_class_id as key,
				c.ev_class_id as id,
				c.name as name,
				c.disporder
			from
				tEvClass c,
				tEvCategory y
			where
				    y.ev_category_id = ?
				and c.category = y.category

			union all

			select distinct
				'C' as type,
				'C' || u.coupon_id as key,
				u.coupon_id as id,
				u.desc      as name,
				0
			from
				tcoupon    u,
				tEvCategory y1
			where
				    u.category = y1.category
				and y1.ev_category_id = ?
			order by
				5
		}

	} elseif { [reqGetArg type] != "autosettler" } {

		set sql {
			select distinct
				'CL' as type,
				'CL' || c.ev_class_id as key,
				c.ev_class_id as id,
				c.name as name,
				c.disporder
			from
				tEvClass c
			where
				c.category = ?

			union all

			select distinct
				'C' as type,
				'C' || u.coupon_id as key,
				u.coupon_id as id,
				u.desc      as name,
				0
			from
				tcoupon    u
			where
				u.category = ?
			order by
				5
		} 
	} else {

		set sql {
			select distinct
				'CL' as type,
				'CL' || c.ev_class_id as key,
				c.ev_class_id as id,
				c.name as name,
				c.disporder
			from
				tEvClass c,
				tEvCategory y
			where
				    y.ev_category_id = ?
				and c.category = y.category

			order by
				5
		}
	}

	set cat  [reqGetArg id]
	set stmt [inf_prep_sql $DB [subst $sql]]
	set rs   [inf_exec_stmt $stmt $cat $cat]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpSetVar show_link 1

	tpBindTcl id     "sb_res_data $rs dd_idx id"
	tpBindTcl key    "sb_res_data $rs dd_idx key"
	tpBindTcl name   "sb_res_data $rs dd_idx name"
	tpBindTcl level  "ADMIN::BESTBETS::print_level $rs dd_idx type"

	tpBindString title   "Classes/Coupons"
	tpBindString link_action ADMIN::BESTBETS::go_bbet_types
	tpBindString index   [reqGetArg index]
	tpBindString type    [reqGetArg type]

	if { [reqGetArg type] == "autosettler" } {
	        tpBindString remove_links   "Yes"
		tpBindString title          "Classes"
	}

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}

#
# show types and coupons
#
proc go_bbet_types {} {
	global DB
	if {[reqGetArg type] == "autosettler"} {
		set sql_arg ""
	} elseif {[reqGetArg type] == "PERFVOD"} {
		set sql_arg "and e.start_time    > current - interval(1) day to day and e.result_conf   = 'Y'"
	} else {
		set sql_arg "and e.start_time    > current - interval(7) day to day and e.result_conf   = 'N'"
	}

	if { [reqGetArg type] != "autosettler" } {
		set sql "
			select distinct
				'T' as type,
				'T' || t.ev_type_id as key,
				t.ev_type_id as id,
				t.name       as name,
				t.disporder
			from
				tevclass  c,
				tevtype   t,
				tev       e
			where
				c.ev_class_id   = ?
			and c.ev_class_id   = t.ev_class_id
			and t.ev_type_id    = e.ev_type_id
			$sql_arg
			union all
	
			select distinct
				'C' as type,
				'C' || u.coupon_id as key,
				u.coupon_id as id,
				u.desc      as name,
				0
			from
				tevclass   c,
				tevtype    t,
				tcoupon    u,
				tcouponmkt cm,
				tev        e,
				tevmkt     m
			where
				c.ev_class_id   = ?
				and t.ev_class_id   = c.ev_class_id
				and t.ev_type_id    = e.ev_type_id
				and e.ev_id         = m.ev_id
				and u.ev_class_id   = c.ev_class_id
				and u.coupon_id     = cm.coupon_id
				and cm.ev_mkt_id    = m.ev_mkt_id
				$sql_arg
			order by
				5
		"
	} else {

			set sql "
			select distinct
				'T' as type,
				'T' || t.ev_type_id as key,
				t.ev_type_id as id,
				t.name       as name,
				t.disporder
			from
				tevclass  c,
				tevtype   t,
				tev       e
			where
				c.ev_class_id   = ?
				and c.ev_class_id   = t.ev_class_id
				and t.ev_type_id    = e.ev_type_id
				$sql_arg
			order by
				5
			"

	}

	set class [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $class $class]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]

	tpBindTcl id     "sb_res_data $rs dd_idx id"
	tpBindTcl key    "sb_res_data $rs dd_idx key"
	tpBindTcl name   "sb_res_data $rs dd_idx name"
	tpBindTcl level  "ADMIN::BESTBETS::print_level $rs dd_idx type"

	if {[reqGetArg type] == "CustLimit" || [reqGetArg type] == "autosettler" } {
		tpBindString link_action ADMIN::BESTBETS::go_bbet_evocgrps
	} else {
		tpBindString link_action ADMIN::BESTBETS::go_bbet_events
	}

	tpBindString title "Types/Coupons"
	tpBindString index   [reqGetArg index]
	tpBindString type    [reqGetArg type]


	if { [reqGetArg type] == "autosettler" } {
	        tpBindString remove_links   "Yes"
		tpBindString title "Types"
	}

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}


proc print_level {rs row col} {
	if {[db_get_col $rs [tpGetVar $row] type] == "T"} {
		tpSetVar show_link 1
		tpBufWrite TYPE
	} elseif {[db_get_col $rs [tpGetVar $row] type] == "CL"} {
		tpSetVar show_link 1
		tpBufWrite CLASS
	} else {
		tpSetVar show_link 0
		tpBufWrite COUPON
	}
}


#
# show Events
#
proc go_bbet_events {} {

	global DB

	# For Perform Mapping - if VoD, we want to display past events!
	if {[reqGetArg type] == "PERFVOD"} {
		set sql {
			select
				e.ev_id,
				e.desc as event_name,
				extend(e.start_time, month to day) as start_time,
				e.disporder as ev_disporder
			from
				tEvClass    c,
				tEvType     t,
				tEv         e
			where
				t.ev_class_id   = c.ev_class_id
			and t.ev_type_id    = e.ev_type_id
			and t.ev_type_id    = ?
			and t.ev_type_id    = e.ev_type_id
			and e.start_time    > current - interval(1) day to day
			and e.result_conf   = 'Y'
			order by
				e.start_time,
				e.disporder
		}
	} else {
		set sql {
			select
				e.ev_id,
				e.desc as event_name,
				e.start_time,
				e.disporder as ev_disporder
			from
				tEvClass    c,
				tEvType     t,
				tEv         e
			where
				t.ev_class_id   = c.ev_class_id
			and t.ev_type_id    = e.ev_type_id
			and t.ev_type_id    = ?
			and t.ev_type_id    = e.ev_type_id
			and e.start_time    > current - interval(7) day to day
			and e.result_conf   = 'N'
			order by
				e.start_time,
				e.disporder
		}
	}

	set type [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $type]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 1
	tpBindTcl id   "sb_res_data $rs dd_idx ev_id"
	tpBindTcl key  "sb_res_data $rs dd_idx ev_id"
	tpBindTcl name "sb_res_data $rs dd_idx event_name"
	tpBindTcl start_time "sb_res_data $rs dd_idx start_time"

	tpBindString level   EVENT
	tpBindString title   Events
	tpBindString link_action ADMIN::BESTBETS::go_bbet_markets
	tpBindString index   [reqGetArg index]
	asPlayFile -nocache bbet_dd.html

	db_close $rs
}



#
# show Events
#
proc go_bbet_markets {} {

	global DB
	set sql {
		select distinct
			m.ev_mkt_id,
			g.name as mkt_name,
			g.disporder
		from
			tEvClass    c,
			tEvType     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    g
		where
			t.ev_class_id   = c.ev_class_id
		and t.ev_type_id    = e.ev_type_id
		and e.ev_id         = ?
		and m.ev_id         = e.ev_id
		and m.ev_oc_grp_id  = g.ev_oc_grp_id
		and t.ev_type_id    = g.ev_type_id
		and e.start_time    > current - interval(7) day to day
		and e.result_conf   = 'N'
		order by
			g.disporder
	}

	set event [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $event]

	inf_close_stmt $stmt
	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 1
	tpBindTcl id   "sb_res_data $rs dd_idx ev_mkt_id"
	tpBindTcl name "sb_res_data $rs dd_idx mkt_name"

	tpBindString level   MARKET
	tpBindString title   Markets
	tpBindString link_action ADMIN::BESTBETS::go_bbet_selns
	tpBindString index   [reqGetArg index]
	asPlayFile -nocache bbet_dd.html

	db_close $rs
}



#
# Show event outcome groups
#

proc go_bbet_evocgrps {} {

	global DB

	if {[reqGetArg type] == "autosettler" } {
		set sql_arg ""
	} else {
		set sql_arg "and e.start_time    > current - interval(7) day to day and e.result_conf   = 'N'"
	}

	set sql "
		select distinct
			m.ev_oc_grp_id,
			g.name as evocgrp_name,
			g.disporder
		from
			tEvClass    c,
			tEvType     t,
			tEv         e,
			tEvMkt      m,
			tEvOcGrp    g
		where
			t.ev_class_id   = c.ev_class_id
		and e.ev_type_id    = ?
		and m.ev_id         = e.ev_id
		and m.ev_oc_grp_id  = g.ev_oc_grp_id
		and t.ev_type_id    = g.ev_type_id
		$sql_arg
		order by
			g.disporder
	"

	set event [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $event]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 0
	tpBindTcl id   "sb_res_data $rs dd_idx ev_oc_grp_id"
	tpBindTcl name "sb_res_data $rs dd_idx evocgrp_name"
	if {[reqGetArg type] == "autosettler" } {
		tpBindString level   EV_OC_GRP
	} else {
		tpBindString level   EVOCGRP
	}
	tpBindString title   "Event Outcome Groups"

	tpBindString index   [reqGetArg index]


	asPlayFile -nocache bbet_dd.html

	db_close $rs

}



proc go_bbet_selns {} {

	global DB

	set sql {
		select distinct
			ev_oc_id,
			desc,
			disporder
		from
			tEvOc
		where
			ev_mkt_id = ?
		order by
			disporder
	}

	set mkt  [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $mkt]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 0
	tpBindTcl id   "sb_res_data $rs dd_idx ev_oc_id"
	tpBindTcl name "sb_res_data $rs dd_idx desc"

	tpBindString level   SELECTION
	tpBindString title   Selections
	tpBindString index   [reqGetArg index]

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}

proc go_bbet_xgame_types {} {
	global DB

	set sql {
		select distinct game_type
		from  tXGameDef
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 1
	tpBindTcl id "sb_res_data $rs dd_idx game_type"
	tpBindTcl name "sb_res_data $rs dd_idx game_type"

	tpBindString level   XGAME_TYPE
	tpBindString title   "XGame Type"
	tpBindString link_action ADMIN::BESTBETS::go_bbet_xgame_sorts
	tpBindString index   [reqGetArg index]

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}

proc go_bbet_xgame_sorts {} {
	global DB

	set sql {
		select name
		from  tXGameDef
		where game_type = ?
	}

	set game_type [reqGetArg id]
	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt $game_type]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 0
	tpBindTcl id "sb_res_data $rs dd_idx name"
	tpBindTcl name "sb_res_data $rs dd_idx name"

	tpBindString level   XGAME_SORT
	tpBindString title   "XGame Sort"
	tpBindString index   [reqGetArg index]

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}

proc go_bbet_game_sorts {} {
	global DB

	set sql {
		select distinct game_id, name
		from  tGameDef
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	tpSetVar dd_rows [db_get_nrows $rs]
	tpSetVar show_link 0
	tpBindTcl id "sb_res_data $rs dd_idx game_id"
	tpBindTcl name "sb_res_data $rs dd_idx name"

	tpBindString level   GAME_SORT
	tpBindString title   "Game Type"
	tpBindString link_action ADMIN::BESTBETS::go_bbet_xgame_sorts
	tpBindString index   [reqGetArg index]

	asPlayFile -nocache bbet_dd.html

	db_close $rs
}


}
