# ==============================================================
# $Id: language.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::LANGUAGE {

asSetAct ADMIN::LANGUAGE::GoLanguageList     [namespace code go_language_list]
asSetAct ADMIN::LANGUAGE::GoLanguage         [namespace code go_language]
asSetAct ADMIN::LANGUAGE::DoLanguage         [namespace code do_language]
asSetAct ADMIN::LANGUAGE::DoAddClone         [namespace code do_add_clone]
asSetAct ADMIN::LANGUAGE::GoISOLanguagesList [namespace code iso_languages_popup]

variable LANG

#
# ----------------------------------------------------------------------------
# Go to language list
# ----------------------------------------------------------------------------
#
proc go_language_list args {

	global DB

	_bind_languages

	asPlayFile -nocache new_language/language_list.html

}



#
# ----------------------------------------------------------------------------
# Go to single language add/update
# ----------------------------------------------------------------------------
#
proc go_language args {

	global DB LANG_CODES

	# bind ISO languages for js validation
	_bind_iso_language_codes

	# bind languages & locales for the default dropdown
	_bind_locale_dropdown
	_bind_lang_dropdown

	# bind system default language

	set default_lang_sql {
		select first 1
			default_lang
		from
			tcontrol
		}

	set stmt [inf_prep_sql $DB $default_lang_sql]
	set rs [inf_exec_stmt $stmt]

	set system_default_lang [db_get_col $rs 0 default_lang]
	db_close $rs

	tpBindString LanguageSystemDefault $system_default_lang

	set language_lang [reqGetArg LanguageLang]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString LanguageLang $language_lang

	if {$language_lang == ""} {

		if {![op_allowed ManageLanguage]} {
			err_bind "You do not have permission to update language information"
			go_language_list
			return
		}

		tpBindString LanguageLang          ""
		tpBindString LanguageName          ""
		tpBindString LanguageXlName        ""
		tpBindString LanguageStatus        "A"
		tpBindString LanguageDisplayed     "N"
		tpBindString LanguageDispOrder     0
		tpBindString LanguageSportsbookWarning "Y"
		tpBindString LanguageFailover      ""
		tpBindString LanguageLocale        ""

		_bind_languages $language_lang

		tpSetVar opAdd 1

	} else {

		#
		# Get language information
		#
		set sql {
			select
				l.lang,
				l.name,
				l.xl_name,
				l.status,
				l.displayed,
				l.disporder,
				slv.value,
				l.failover,
				l.locale
			from
				tLang l,
				outer (tSiteLangCfg slc, tSiteLangVal slv)
			where
				l.lang = slc.lang and
				slv.site_lang_id = slc.site_lang_id and
				slv.type = "WARNING_FLAG" and
				l.lang = ?
				order by
				l.lang asc
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $language_lang]
		inf_close_stmt $stmt

		tpBindString LanguageLang              [db_get_col $res 0 lang]
		tpBindString LanguageName              [db_get_col $res 0 name]
		tpBindString LanguageXlName            [db_get_col $res 0 xl_name]
		tpBindString LanguageStatus            [db_get_col $res 0 status]
		tpBindString LanguageDisplayed         [db_get_col $res 0 displayed]
		tpBindString LanguageDispOrder         [db_get_col $res 0 disporder]
		tpBindString LanguageSportsbookWarning [db_get_col $res 0 value]
		tpBindString LanguageDefaultLanguage   [db_get_col $res 0 failover]
		tpBindString LanguageDefaultLocale     [db_get_col $res 0 locale]

		db_close $res

		tpSetVar opAdd 0

	}


	asPlayFile -nocache new_language/language.html

}


#
# ----------------------------------------------------------------------------
# Do language insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_language args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_language_list
		return
	}

	if {![op_allowed ManageLanguage]} {
		err_bind "You do not have permission to update language information"
		go_language_list
		return
	}

	if {$act == "LangMod"} {
		do_language_upd
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_language_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdLanguage(
			p_adminuser = ?,
			p_lang = ?,
			p_name = ?,
			p_charset = ?,
			p_xl_name = ?,
			p_status = ?,
			p_displayed = ?,
			p_disporder = ?,
			p_type = ?,
			p_value = ?,
			p_failover = ?,
			p_locale = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set upd_error 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg LanguageLang]\
			[reqGetArg LanguageName]\
			"utf-8"\
			[reqGetArg LanguageXlName]\
			[reqGetArg LanguageStatus]\
			[reqGetArg LanguageDisplayed]\
			[reqGetArg LanguageDispOrder]\
			"WARNING_FLAG"\
			[reqGetArg LanguageSportsbookWarning]\
			[reqGetArg LanguageDefaultLanguage]\
			[reqGetArg LanguageDefaultLocale]]} msg]} {
		err_bind $msg
		set upd_error 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$upd_error} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_language
		return
	}

	go_language_list
}



proc _bind_languages args {

	global DB
	variable LANG

	if { $args != ""} {
		set current_language $args
	} else {
		set current_language "\'\'"
	}

	set sql {
		select
			l.lang,
			l.name,
			l.xl_name,
			l.status,
			l.displayed,
			l.disporder,
			slv.value,
			l.failover,
			l.locale
		from
			tLang l,
			outer (tSiteLangCfg slc, tSiteLangVal slv)
		where
			l.lang = slc.lang and
			slv.site_lang_id = slc.site_lang_id and
			l.lang != ? and
			slv.type = "WARNING_FLAG"
		order by
			l.lang asc
	}

	set stmt [inf_prep_sql $DB $sql]
	set res_list  [inf_exec_stmt $stmt $current_language]
	inf_close_stmt $stmt

	set LANG(num) [db_get_nrows $res_list]

	for {set i 0} {$i < $LANG(num)} {incr i} {
		set LANG($i,lang)      [db_get_col $res_list $i lang]
		set LANG($i,name)      [db_get_col $res_list $i name]
		set LANG($i,xl_name)   [db_get_col $res_list $i xl_name]
		set LANG($i,status)    [db_get_col $res_list $i status]
		set LANG($i,displayed) [db_get_col $res_list $i displayed]
		set LANG($i,disporder) [db_get_col $res_list $i disporder]
		set LANG($i,value)     [db_get_col $res_list $i value]
		set LANG($i,failover)  [db_get_col $res_list $i failover]
		set LANG($i,locale)    [db_get_col $res_list $i locale]
	}
	catch {db_close $res_list}

	tpSetVar NumLanguages $LANG(num)

	tpBindVar LanguageLang              ADMIN::LANGUAGE::LANG lang       lang_idx
	tpBindVar LanguageName              ADMIN::LANGUAGE::LANG name       lang_idx
	tpBindVar LanguageXlName            ADMIN::LANGUAGE::LANG xl_name    lang_idx
	tpBindVar LanguageStatus            ADMIN::LANGUAGE::LANG status     lang_idx
	tpBindVar LanguageDispOrder         ADMIN::LANGUAGE::LANG disporder  lang_idx
	tpBindVar LanguageDisplayed         ADMIN::LANGUAGE::LANG displayed  lang_idx
	tpBindVar LanguageSportsbookWarning ADMIN::LANGUAGE::LANG value      lang_idx
	tpBindVar LanguageDefaultLanguage   ADMIN::LANGUAGE::LANG failover   lang_idx
	tpBindVar LanguageDefaultLocale     ADMIN::LANGUAGE::LANG locale     lang_idx

}

proc do_add_clone args {

	global DB USERNAME

	set do_action [reqGetArg do_action]
	set root_lang [reqGetArg root_lang]
	set new_lang [reqGetArg new_lang]

	set err ""

	tpBufAddHdr "Content-Type" "text/html"
	switch $do_action {
		LangAdd {

			set sql [subst {
				execute procedure pInsLanguage(
					p_adminuser = ?,
					p_lang = ?,
					p_name = ?,
					p_charset = ?,
					p_xl_name = ?,
					p_status = ?,
					p_displayed = ?,
					p_disporder = ?,
					p_type = ?,
					p_value = ?,
					p_type_2 = ?,
					p_value_2 = ?,
					p_failover = ?,
					p_locale = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$new_lang\
					[reqGetArg lang_name]\
					"utf-8"\
					[reqGetArg lang_xl_name]\
					[reqGetArg lang_status]\
					[reqGetArg lang_displayed]\
					[reqGetArg lang_disp_order]\
					"WARNING_FLAG"\
					[reqGetArg lang_sportsbook_warn]\
					"NAME_LANG_GROUPS"\
					[reqGetArg lang_default_lang]\
					$new_lang\
					[reqGetArg lang_default_locale]]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "LangAdd|1|$err"
		}
		CloneLangWebsiteConfig {

			set sql [subst {
				execute procedure pCloneLangWebsiteConfig(
					p_adminuser = ?,
					p_root_lang = ?,
					p_new_lang = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$root_lang\
					$new_lang]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneLangWebsiteConfig|1|$err"

		}
		CloneLangDisplayManagerConfig {

			set sql [subst {
				execute procedure pCloneLangDisplayManageConfig(
					p_adminuser = ?,
					p_root_lang = ?,
					p_new_lang = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$root_lang\
					$new_lang]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneLangDisplayManagerConfig|1|$err"

		}
		CloneImageLocationsFlag {

			set sql [subst {
				execute procedure pInsUpdSiteLangValue(
					p_adminuser = ?,
					p_lang = ?,
					p_type = ?,
					p_value = ?
				)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					$USERNAME\
					$new_lang\
					"IMG_LOC_FLAG"\
					$root_lang]} msg]} {
				err_bind $msg
				set err $msg
			}

			catch {db_close $res}
			inf_close_stmt $stmt

			tpBufWrite "CloneImageLocationsFlag|1|$err"

		}
	}

}



#
# Handler for the ISO languages pop-up window.
#
proc iso_languages_popup args {

	_bind_iso_language_codes

	asPlayFile -nocache new_language/iso_languages.html
}



#
# Bind ISO 639-1 language codes for display. Used for the pop-up
# window and also for JS validation on the form.
#
proc _bind_iso_language_codes args {

	global DB ISO_LANGUAGE_CODES

	set iso_codes_sql [subst {
			select
				iso_lang_code,
				lang_name
			from
				tISOLangCode
			}]

	set stmt [inf_prep_sql $DB $iso_codes_sql]
	set rs [inf_exec_stmt $stmt]

	set num_iso_lang_codes [db_get_nrows $rs]
	for {set r 0} {$r < $num_iso_lang_codes} {incr r} {
		set ISO_LANGUAGE_CODES($r,code) [db_get_col $rs $r iso_lang_code]
		set ISO_LANGUAGE_CODES($r,name) [db_get_col $rs $r lang_name]
	}

	db_close $rs

	tpSetVar NumIsoLangCodes $num_iso_lang_codes
	tpBindVar IsoLangName ISO_LANGUAGE_CODES name iso_idx
	tpBindVar IsoLangCode ISO_LANGUAGE_CODES code iso_idx
}

}
