# ==============================================================
# $Id: lang.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::LANG {

asSetAct ADMIN::LANG::GoLangDisp [namespace code go_lang_disp]

#
# ----------------------------------------------------------------------------
# Go to channel list
# ----------------------------------------------------------------------------
#
proc go_lang_disp args {

	global DB

	set id      [reqGetArg Id]
	set id_sort [reqGetArg IdSort]

	set sql [subst {
		select
			l.disporder lang_order,
			l.lang,
			l.name,
			o.disporder
		from
			tLang l,
			outer tObjLangInfo o
		where
			o.obj_id = ? and
			o.obj_type = ? and
			o.lang = l.lang
		order by
			1
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt $id $id_sort]
	inf_close_stmt $stmt

	tpSetVar NumLangs [db_get_nrows $res]

	tpBindTcl LangCode      sb_res_data $res lang_idx lang
	tpBindTcl LangName      sb_res_data $res lang_idx name
	tpBindTcl LangDisporder sb_res_data $res lang_idx disporder

	asPlayFile -nocache lang_disporder.html

	db_close $res
}


}
