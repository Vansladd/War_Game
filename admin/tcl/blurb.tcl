# ==============================================================
# $Id: blurb.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::BLURB {

asSetAct ADMIN::BLURB::do_blurb      [namespace code do_blurb]


proc do_blurb args {
	set sn [reqGetArg SubmitName]

	if {$sn == "Insert"} {
		insert_blurb
	} elseif {$sn == "Update"} {
		update_blurb
	} elseif {$sn == "Delete"} {
		delete_blurb
	}

	get_blurb
}

proc get_blurb {} {

	global DB

	set ref_id [reqGetArg ref_id]
	set sort   [reqGetArg sort]
	set lang   [reqGetArg lang]

	if {$lang == ""} {
		set sql {
			select default_lang from tcontrol
		}

		set stmt [inf_prep_sql $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		if {[db_get_nrows $rs] > 0} {
			set lang [db_get_coln $rs 0 0]
		}
		db_close $rs
		inf_close_stmt $stmt
	}


	set sql [subst {
		select
			lang,
			name,
			case when lang = \'$lang\'
			then \'selected\' else \'\'
			end as selected,
			disporder
		from
			tlang
		where
			status = 'A'
		order by
			disporder
	}]

	set stmt    [inf_prep_sql $DB $sql]
	set rsl [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	if {$lang == "" && [db_get_nrows $rsl] > 0} {
		set lang [db_get_col $rsl 0 lang]
	}

	tpSetVar  num_lang [db_get_nrows $rsl]
	tpBindTcl SELECTED sb_res_data $rsl lang_idx selected
	tpBindTcl LANG     sb_res_data $rsl lang_idx lang
	tpBindTcl NAME     sb_res_data $rsl lang_idx name


	# now retrieve the blurb
	set sql {
		select
			sort,
			xl_blurb_1,
			xl_blurb_2,
			xl_blurb_3
		from
			tBlurbXLate
		where
			ref_id = ? and
			sort   = ? and
			lang   = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set rsb  [inf_exec_stmt $stmt $ref_id $sort $lang]
	inf_close_stmt $stmt

	if {[db_get_nrows $rsb] > 0} {

		set s    [db_get_col $rsb xl_blurb_1]
		append s [db_get_col $rsb xl_blurb_2]
		append s [db_get_col $rsb xl_blurb_3]
		tpBindString blurb $s
		tpBindString OP Update

	} else {
		tpBindString OP Insert
	}

	tpBindString ref_id $ref_id
	tpBindString sort   $sort

	asPlayFile -nocache blurb.html

	db_close $rsl
	db_close $rsb
}


proc insert_blurb {} {

	global DB

	set sql {
		insert into tblurbxlate (
			ref_id,
			sort,
			lang,
			xl_blurb_1,
			xl_blurb_2,
			xl_blurb_3
		) values (
			?,
			?,
			?,
			?,
			?,
			?
		)
	}


	set ref_id [reqGetArg ref_id]
	set sort   [reqGetArg sort]
	set lang   [reqGetArg lang]
	set blurb  [reqGetArg blurb]

#	set blurb [encoding convertfrom utf-8 $blurb]
#	set blurb [encoding convertto binary  $blurb]

	set b1 [string range $blurb 0 254]
	set b2 [string range $blurb 255 509]
	set b3 [string range $blurb 510 764]


	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $ref_id $sort $lang $b1 $b2 $b3
	inf_close_stmt $stmt
}

proc update_blurb {} {

	global DB

	set sql {
		update tblurbxlate set
			xl_blurb_1  = ?,
			xl_blurb_2  = ?,
			xl_blurb_3  = ?,
			last_update = CURRENT
		where
			ref_id = ? and
			sort   = ? and
			lang   = ?
	}


	set blurb  [reqGetArg blurb]
	set ref_id [reqGetArg ref_id]
	set sort   [reqGetArg sort]
	set lang   [reqGetArg lang]

#	set blurb [encoding convertfrom utf-8 $blurb]
#	set blurb [encoding convertto binary  $blurb]

	set b1 [string range $blurb 0 254]
	set b2 [string range $blurb 255 509]
	set b3 [string range $blurb 510 764]


	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $b1 $b2 $b3 $ref_id $sort $lang
	inf_close_stmt $stmt
}


proc delete_blurb {} {

	global DB

	set sql {
		delete from tBlurbXLate
		where
			ref_id = ? and
			sort   = ? and
			lang   = ?
	}


	set ref_id [reqGetArg ref_id]
	set sort   [reqGetArg sort]
	set lang   [reqGetArg lang]

	set stmt [inf_prep_sql $DB $sql]
	inf_exec_stmt $stmt $ref_id $sort $lang
	inf_close_stmt $stmt
}


# end namespace
}

