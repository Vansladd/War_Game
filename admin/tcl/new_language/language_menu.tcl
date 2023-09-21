# ==============================================================
# $Id: language_menu.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::LANGMENU {

asSetAct ADMIN::LANGMENU::GoLocaleList       [namespace code go_locale_list]
asSetAct ADMIN::LANGMENU::GoLocale           [namespace code go_locale]
asSetAct ADMIN::LANGMENU::DoLocale           [namespace code do_locale]



#
# Handler for displaying add/modify form for a locale.
# If LocaleID is set, show modify locale form, else, show add locale form.
#
proc go_locale args {

	global DB

	set lang_menu_id [reqGetArg LocaleID]

	if {$lang_menu_id == ""} {
		tpBindString LocaleID          ""
		tpBindString LocaleCode        ""
		tpBindString LocaleName        ""
		tpBindString LocaleXlName      ""
		tpBindString LocaleLang        ""
		tpBindString LocaleView        ""
		tpBindString LocaleDisporder   ""
		tpBindString LocaleStatus      ""
		tpBindString LocaleDisplayed   ""
		tpBindString LocalePriceDisplay ""
		tpBindString LocaleFlagFilename ""
		tpSetVar opAdd 1
	} else {

		set sql [subst {
			select
				locale,
				name,
				xl_name,
				lang,
				view,
				disporder,
				status,
				displayed,
				price_display,
				flag_filename
			from
				tLangMenu
			where
				lang_menu_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt $lang_menu_id]

		if {[db_get_nrows $rs] > 0} {
			tpBindString LocaleID           $lang_menu_id
			tpBindString LocaleCode         [db_get_col $rs 0 locale]
			tpBindString LocaleName         [db_get_col $rs 0 name]
			tpBindString LocaleXlName       [db_get_col $rs 0 xl_name]
			tpBindString LocaleLang         [db_get_col $rs 0 lang]
			tpBindString LocaleView         [db_get_col $rs 0 view]
			tpBindString LocaleDisporder    [db_get_col $rs 0 disporder]
			tpBindString LocaleStatus       [db_get_col $rs 0 status]
			tpBindString LocaleDisplayed    [db_get_col $rs 0 displayed]
			tpBindString LocalePriceDisplay [db_get_col $rs 0 price_display]
			tpBindString LocaleFlagFilename [db_get_col $rs 0 flag_filename]
		}

		db_close $rs

		tpSetVar opAdd 0
	}

	# bind languages & views for the default drop-downs
	_bind_lang_dropdown
	_bind_view_dropdown

	asPlayFile -nocache new_language/language_menu.html

}



#
# Perform add/update/delete locale.
#
proc do_locale args {

	global DB USERNAME

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_locale_list
		return
	}

	if {![op_allowed ManageLocale]} {
		err_bind "You do not have permission to update language menu"
		go_language_list
		return
	}

	if {$act != "LocaleAdd" && $act != "LocaleMod" && $act != "LocaleDel" } {
		err_bind "unexpected SubmitName: $act"
		return
	}

	if {$act == "SaveLangRowsPerColumn"} {
		_save_lang_per_column
	} elseif {$act == "LocaleAdd"} {

		set sql [subst {
			insert into
				tLangMenu (
					locale,
					name,
					xl_name,
					lang,
					view,
					disporder,
					status,
					displayed,
					price_display,
					flag_filename
				)
			values (?,?,?,?,?,?,?,?,?,?)
		}]

		set stmt [inf_prep_sql $DB $sql]

		set upd_error 0

		if {[catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg LocaleCode]\
				[reqGetArg LocaleName]\
				[reqGetArg LocaleXlName]\
				[reqGetArg LocaleLang]\
				[reqGetArg LocaleView]\
				[reqGetArg LocaleDisporder]\
				[reqGetArg LocaleStatus]\
				[reqGetArg LocaleDisplayed]\
				[reqGetArg LocalePriceDisplay]\
				[reqGetArg LocaleFlagFilename]]} msg]} {
			err_bind $msg
			set upd_error 1
		}

		catch {db_close $res}
		inf_close_stmt $stmt

	} elseif {$act == "LocaleMod"} {

		set sql [subst {
			update
				tLangMenu
			set
				locale = ?,
				name = ?,
				xl_name = ?,
				lang = ?,
				view = ?,
				disporder = ?,
				status = ?,
				displayed = ?,
				price_display = ?,
				flag_filename = ?
			where
				lang_menu_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set upd_error 0

		if {[catch {
			set res [inf_exec_stmt $stmt\
				[reqGetArg LocaleCode]\
				[reqGetArg LocaleName]\
				[reqGetArg LocaleXlName]\
				[reqGetArg LocaleLang]\
				[reqGetArg LocaleView]\
				[reqGetArg LocaleDisporder]\
				[reqGetArg LocaleStatus]\
				[reqGetArg LocaleDisplayed]\
				[reqGetArg LocalePriceDisplay]\
				[reqGetArg LocaleFlagFilename]\
				[reqGetArg LocaleID]]} msg]} {
			err_bind $msg
			set upd_error 1
		}

		catch {db_close $res}
		inf_close_stmt $stmt

	} elseif {$act == "LocaleDel"} {

		set sql [subst {
			delete from
				tLangMenu
			where
				lang_menu_id = ?
		}]

		set stmt [inf_prep_sql $DB $sql]

		set upd_error 0

		if {[catch {
			set res [inf_exec_stmt $stmt [reqGetArg LocaleID]]} msg]} {
			err_bind $msg
			set upd_error 1
		}

		catch {db_close $res}
		inf_close_stmt $stmt
	}

	if {$upd_error} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_locale
		return
	}

	go_locale_list
}


#
# Display the main list of all locales.
#
proc go_locale_list args {

	global DB LOCALES

	_bind_lang_rows_per_column

	set sql [subst {
		select
			lang_menu_id,
			locale,
			name,
			xl_name,
			lang,
			view,
			disporder,
			status,
			displayed,
			price_display,
			flag_filename
		from
			tLangMenu
		order by
			disporder
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]

	set num_locales [db_get_nrows $rs]
	for {set r 0} {$r < $num_locales} {incr r} {
		set LOCALES($r,locale_id)   [db_get_col $rs $r lang_menu_id]
		set LOCALES($r,locale_code) [db_get_col $rs $r locale]
		set LOCALES($r,name)        [db_get_col $rs $r name]
		set LOCALES($r,xl_name)     [db_get_col $rs $r xl_name]
		set LOCALES($r,lang)        [db_get_col $rs $r lang]
		set LOCALES($r,view)        [db_get_col $rs $r view]
		set LOCALES($r,disporder)   [db_get_col $rs $r disporder]
		set LOCALES($r,status)      [db_get_col $rs $r status]
		set LOCALES($r,displayed)   [db_get_col $rs $r displayed]
		set LOCALES($r,price_display)   [db_get_col $rs $r price_display]
		set LOCALES($r,flag_filename)   [db_get_col $rs $r flag_filename]
	}

	db_close $rs

	tpSetVar NumLocales $num_locales
	tpBindVar LocaleID           LOCALES locale_id   locales_idx
	tpBindVar LocaleCode         LOCALES locale_code locales_idx
	tpBindVar LocaleName         LOCALES name        locales_idx
	tpBindVar LocaleXlName       LOCALES xl_name     locales_idx
	tpBindVar LocaleLang         LOCALES lang        locales_idx
	tpBindVar LocaleView         LOCALES view        locales_idx
	tpBindVar LocaleDisporder    LOCALES disporder   locales_idx
	tpBindVar LocaleStatus       LOCALES status      locales_idx
	tpBindVar LocaleDisplayed    LOCALES displayed   locales_idx
	tpBindVar LocalePriceDisplay LOCALES price_display   locales_idx
	tpBindVar LocaleFlagFilename LOCALES flag_filename   locales_idx

	asPlayFile -nocache new_language/language_menu_list.html
}



# ------------------
# Private procedures
#
proc _save_lang_per_column args {

	global DB

	set sql {
		update
			tControl
		set
			lang_rows_per_col = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	set upd_lang_per_column_error 0

	if {[catch {
		set res [inf_exec_stmt $stmt [reqGetArg LangRowsPerColumn]]} msg]} {
		err_bind $msg
		set upd_lang_per_column_error 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$upd_lang_per_column_error} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_language
		return
	}

	go_language_list

}



proc _bind_lang_rows_per_column args {

	global DB

	set sql {
		select
			lang_rows_per_col
		from
			tControl
	}

	set stmt [inf_prep_sql $DB $sql]
	set res_list  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpBindString LangRowsPerColumn       [db_get_col $res_list 0 lang_rows_per_col]
}

}
