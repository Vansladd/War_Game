# ==============================================================
# $Id: search.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2007 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SEARCH {

asSetAct ADMIN::SEARCH::GoSynonymSearch       [namespace code go_synonym_search]
asSetAct ADMIN::SEARCH::DoSynonymSearch       [namespace code do_synonym_search]
asSetAct ADMIN::SEARCH::GoSynonymKeywords     [namespace code go_synonym_keywords]
asSetAct ADMIN::SEARCH::DoSynonymKeywords     [namespace code do_synonym_keywords]
asSetAct ADMIN::SEARCH::GoSynonymList         [namespace code go_synonym_list]
asSetAct ADMIN::SEARCH::DoSynonymList         [namespace code do_synonym_list]
asSetAct ADMIN::SEARCH::GoSynonym             [namespace code go_synonym]
asSetAct ADMIN::SEARCH::DoSynonym             [namespace code do_synonym]

asSetAct ADMIN::SEARCH::GoPredefinedSearch    [namespace code go_predefined_search]
asSetAct ADMIN::SEARCH::DoPredefinedSearch    [namespace code do_predefined_search]
asSetAct ADMIN::SEARCH::GoPredefinedKeywords  [namespace code go_predefined_keywords]
asSetAct ADMIN::SEARCH::DoPredefinedKeywords  [namespace code do_predefined_keywords]
asSetAct ADMIN::SEARCH::GoPredefinedList      [namespace code go_predefined_list]
asSetAct ADMIN::SEARCH::DoPredefinedList      [namespace code do_predefined_list]
asSetAct ADMIN::SEARCH::GoPredefined          [namespace code go_predefined]
asSetAct ADMIN::SEARCH::DoPredefined          [namespace code do_predefined]

proc bind_available_langs {} {
	global LANG_ARRAY

	set langs [get_active_langs]

	set i 0
	foreach {lang name} $langs {

		set LANG_ARRAY($i,lang) $lang
		set LANG_ARRAY($i,name) $name
		incr i
	}
	tpSetVar NumLangs $i

	tpBindVar LangCode LANG_ARRAY lang lang_idx
	tpBindVar LangName LANG_ARRAY name lang_idx
}

proc go_synonym_search {} {
	bind_available_langs

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_synonym [reqGetArg crit_synonym]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile "search/synonym_search.html"
}

proc do_synonym_search {} {
	set action [reqGetArgs SubmitName]
	reqSetArg keyword [reqGetArg crit_keyword]
	reqSetArg synonym [reqGetArg crit_synonym]
	reqSetArg lang    [reqGetArg crit_lang]

	switch -- $action {
		"AddSynonym" {
			go_synonym
			return
		}
		"QuickAdd" {
			add_synonym [reqGetArg keyword] \
			            [reqGetArg synonym] \
			            [reqGetArg lang]
		}
		"FindSynonym" {
			go_synonym_keywords
			return
		}
	}
	go_synonym_search
}

proc go_synonym_keywords {} {
	global DB KEYWORD

	set keyword [reqGetArg keyword]
	set synonym [reqGetArg synonym]
	set lang    [reqGetArg lang]

	if {$keyword == ""} {
		set keywordInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set keywordInfo "like '$keyword'"
	}

	if {$synonym == ""} {
		set synonymInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set synonymInfo "with synonyms like '$synonym'"
	}

	if {$lang == ""} {
		set langInfo ""
		set lang_clause ""
	} else {
		tpSetVar ShowExtraInfo 1
		if {$lang == "--"} {
			set langInfo "(Defaults only)"
		} else {
			set langInfo "([get_lang_name $lang] only)"
		}
		set lang_clause "and lang = '$lang'"
	}

	set sql_keyword [_clean_sql_wild $keyword]
	set sql_synonym [_clean_sql_wild $synonym]
	set sql [subst {
		select distinct
			keyword
		from
			tSearchSynonym
		where
			keyword like '$sql_keyword%' and
			synonym like '$sql_synonym%'
			$lang_clause
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	tpSetVar NumKeywords [set nrows [db_get_nrows $rs]]

	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {
			set KEYWORD($r,keyword) [db_get_col $rs $r keyword]
		}
	}

	db_close $rs

	tpBindString KeywordInfo $keywordInfo
	tpBindString SynonymInfo $synonymInfo
	tpBindString LangInfo    $langInfo

	tpBindVar    Keyword KEYWORD keyword keyword_idx
	tpBindString Synonym $synonym
	tpBindString Lang    $lang

	tpBindString keyword $keyword

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_synonym [reqGetArg crit_synonym]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/synonym_keywords.html"

	catch {unset KEYWORD}
}

proc do_synonym_keywords {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"DeleteKeyword" {
			delete_synonym_keyword

			reqSetArg keyword [reqGetArg crit_keyword]
			reqSetArg synonym [reqGetArg crit_synonym]
			reqSetArg lang    [reqGetArg crit_lang]
		}
		"BackSynonymSearch" {
			go_synonym_search
			return
		}
	}
	go_synonym_keywords
}

proc delete_synonym_keyword {} {
	global DB

	set keywords [reqGetArgs word_to_delete]

	if {[llength $keywords] < 1} {
		err_add "No selections have been made for deletion"
		return
	}

	set delete_list [list]
	set msg_list [list]
	foreach word $keywords {
		set sql_word        [_clean_sql_input $word]
		lappend delete_list [subst '$sql_word']
		lappend msg_list    [subst \"$word\"]
	}

	set sql_delete_list [join $delete_list ,]

	set sql [subst {
		delete from
			tSearchSynonym
		where
			keyword in ($sql_delete_list)
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	msg_bind "Deleted: ( [join $msg_list {, }] )"
}

proc go_synonym_list {} {
	global DB SYNONYM

	set keyword [string tolower [reqGetArg keyword]]
	set synonym [string tolower [reqGetArg synonym]]
	set lang    [reqGetArg lang]

	if {$keyword == ""} {
		set keywordInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set keywordInfo "of '$keyword'"
	}

	if {$synonym == ""} {
		set synonymInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set synonymInfo "like '$synonym'"
	}

	if {$lang == ""} {
		set langInfo ""
		set lang_clause ""
	} else {
		tpSetVar ShowExtraInfo 1
		if {$lang == "--"} {
			set langInfo "(Defaults only)"
		} else {
			set langInfo "([get_lang_name $lang] only)"
		}
		set lang_clause "and lang = '$lang'"
	}

	set sql_keyword [_clean_sql_input $keyword]
	set sql_synonym [_clean_sql_wild  $synonym]
	set sql [subst {
		select
			synonym_id,
			synonym,
			lang,
			disporder
		from
			tSearchSynonym
		where
			keyword =    '$sql_keyword' and
			synonym like '$sql_synonym%'
			$lang_clause
		order by
			disporder,
			lang,
			synonym
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	tpSetVar NumSynonyms [set nrows [db_get_nrows $rs]]

	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {
			set SYNONYM($r,synonym_id) [db_get_col $rs $r synonym_id]
			set SYNONYM($r,synonym)    [db_get_col $rs $r synonym]
			set SYNONYM($r,disporder)  [db_get_col $rs $r disporder]

			set synonym_lang [db_get_col $rs $r lang]
			if {$synonym_lang == "--"} {
				set SYNONYM($r,lang_name) "(Default)"
			} else {
				set SYNONYM($r,lang_name)  [get_lang_name $synonym_lang]
			}
		}
	}

	db_close $rs

	tpBindString keyword $keyword
	tpBindString synonym $synonym
	tpBindString lang    $lang

	tpBindString KeywordInfo $keywordInfo
	tpBindString SynonymInfo $synonymInfo
	tpBindString LangInfo    $langInfo

	tpBindVar  SynonymID SYNONYM synonym_id synonym_idx
	tpBindVar  Synonym   SYNONYM synonym    synonym_idx
	tpBindVar  LangName  SYNONYM lang_name  synonym_idx
	tpBindVar  Disporder SYNONYM disporder  synonym_idx

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_synonym [reqGetArg crit_synonym]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/synonym_list.html"

	catch {unset SYNONYM}
}

proc do_synonym_list {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"BackSynonymKeywords" {
			reqSetArg keyword [reqGetArg crit_keyword]
			reqSetArg synonym [reqGetArg crit_synonym]
			reqSetArg lang    [reqGetArg crit_lang]
			go_synonym_keywords
			return
		}
	}
	go_synonym_list
}

proc go_synonym {} {
	global DB

	set synonym_id [reqGetArg synonym_id]
	set keyword    [reqGetArg keyword]
	set synonym    [reqGetArg synonym]
	set lang       [reqGetArg lang]
	set disporder  [reqGetArg disporder]

	set nrows 0

	if {$synonym_id > 0} {
		set sql [subst {
			select
				keyword,
				synonym,
				lang,
				disporder
			from
				tSearchSynonym
			where
				synonym_id = $synonym_id
		}]

		set stmt [inf_prep_sql  $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $rs]

		if {$nrows > 0} {
			set keyword   [db_get_col $rs 0 keyword]
			set synonym   [db_get_col $rs 0 synonym]
			set lang      [db_get_col $rs 0 lang]
			set disporder [db_get_col $rs 0 disporder]
		}
	}

	tpSetVar NumSynonyms $nrows

	tpBindString SynonymID $synonym_id
	tpBindString Keyword   $keyword
	tpBindString Synonym   $synonym
	tpBindString Lang      $lang
	tpBindString Disporder $disporder

	bind_available_langs

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_synonym [reqGetArg crit_synonym]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/synonym.html"
}

proc do_synonym {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"AddSynonym" {
			add_synonym_multi
			return
		}
		"UpdSynonym" {
			upd_synonym [reqGetArg synonym_id] \
			            [reqGetArg keyword] \
			            [reqGetArg synonym] \
			            [reqGetArg lang] \
			            [reqGetArg disporder]
		}
		"DelSynonym" {
			del_synonym [reqGetArg synonym_id]
		}
		"BackSynonymList" {
			reqSetArg synonym [reqGetArg crit_synonym]
			reqSetArg lang    [reqGetArg crit_lang]
			go_synonym_list
			return
		}
	}
	go_synonym
}

proc add_synonym {keyword synonym lang {disporder 1}} {
	global DB USERNAME

	if {$disporder == ""} {set disporder 1}

	set sql {
		execute procedure pSearchInsSynonym (
			p_adminuser = ?,
			p_keyword   = ?,
			p_synonym   = ?,
			p_disporder = ?,
			p_lang      = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt \
		                      $USERNAME \
		                      [string trim $keyword] \
		                      [string trim $synonym] \
		                      $disporder \
		                      $lang ]
	} msg]} {
		err_add $msg
		return
	} else {
		msg_bind "Successfully added"
	}
}

proc add_synonym_multi {} {
	set keyword   [reqGetArg keyword]
	set lang      [reqGetArg lang]
	set disporder [reqGetArg disporder]

	foreach name \
	{
		synonym1
		synonym2
		synonym3
		synonym4
		synonym5
	} {
		set synonym [reqGetArg $name]

		if {$synonym != ""} {
			add_synonym $keyword \
			            $synonym \
			            $lang \
			            $disporder
		}
	}

	go_synonym_list
}

proc upd_synonym {synonym_id keyword synonym lang disporder} {
	global DB USERNAME

	set sql {
		execute procedure pSearchUpdSynonym (
			p_adminuser  = ?,
			p_synonym_id = ?,
			p_keyword    = ?,
			p_synonym    = ?,
			p_disporder  = ?,
			p_lang       = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt \
		                      $USERNAME \
		                      $synonym_id \
		                      [string trim $keyword] \
		                      [string trim $synonym] \
		                      $disporder \
		                      $lang ]
	} msg]} {
		err_add $msg
		return
	} else {
		msg_bind "Successfully updated"
	}
}

proc del_synonym {synonym_id} {
	global DB USERNAME

	set sql {
		execute procedure pSearchDelSynonym (
			p_adminuser  = ?,
			p_synonym_id = ?
		)
	}
	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt \
		                      $USERNAME \
		                      $synonym_id ]
	} msg]} {
		err_add $msg
		return
	} else {
		msg_bind "Successfully deleted"
	}
}


proc go_predefined_search {} {
	bind_available_langs

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile "search/predefined_search.html"
}

proc do_predefined_search {} {
	set action [reqGetArgs SubmitName]
	reqSetArg keyword [reqGetArg crit_keyword]
	reqSetArg lang    [reqGetArg crit_lang]

	switch -- $action {
		"AddPredefined" {
			go_predefined
			return
		}
		"FindPredefined" {
			go_predefined_keywords
			return
		}
	}
	go_predefined_search
}

proc go_predefined_keywords {} {
	global DB KEYWORD

	set keyword [reqGetArg keyword]
	set lang    [reqGetArg lang]

	if {$keyword == ""} {
		set keywordInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set keywordInfo "like '$keyword'"
	}

	if {$lang == ""} {
		set langInfo ""
		set lang_clause ""
	} else {
		tpSetVar ShowExtraInfo 1
		set langInfo "([get_lang_name $lang] only)"
		set lang_clause "and lang = '$lang'"
	}

	set sql_keyword [_clean_sql_wild $keyword]
	set sql [subst {
		select distinct
			keyword
		from
			tSearchPredefined
		where
			keyword like '$sql_keyword%'
			$lang_clause
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	tpSetVar NumKeywords [set nrows [db_get_nrows $rs]]

	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {
			set KEYWORD($r,keyword) [db_get_col $rs $r keyword]
		}
	}

	db_close $rs

	tpBindString KeywordInfo $keywordInfo
	tpBindString LangInfo    $langInfo

	tpBindVar    Keyword KEYWORD keyword keyword_idx
	tpBindString Lang    $lang

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/predefined_keywords.html"

	catch {unset KEYWORD}
}

proc do_predefined_keywords {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"DeletePredefined" {
			delete_predefined_keyword

			reqSetArg keyword [reqGetArg crit_keyword]
			reqSetArg lang    [reqGetArg crit_lang]
		}
		"BackPredefinedSearch" {
			go_predefined_search
			return
		}
	}
	go_predefined_keywords
}

proc delete_predefined_keyword {} {
	global DB

	set keywords [reqGetArgs word_to_delete]

	if {[llength $keywords] < 1} {
		err_add "No selections have been made for deletion"
		return
	}

	set delete_list [list]
	set msg_list [list]
	foreach word $keywords {
		set sql_word        [_clean_sql_input $word]
		lappend delete_list [subst '$sql_word']
		lappend msg_list    [subst \"$word\"]
	}

	set sql_delete_list [join $delete_list ,]

	set sql [subst {
		delete from
			tSearchPredefined
		where
			keyword in ($sql_delete_list)
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	msg_bind "Deleted: ( [join $msg_list {, }] )"
}

proc go_predefined_list {} {
	global DB PREDEFINED

	set keyword [reqGetArg keyword]
	set lang    [reqGetArg lang]

	if {$keyword == ""} {
		set keywordInfo ""
	} else {
		tpSetVar ShowExtraInfo 1
		set keywordInfo "of '$keyword'"
	}

	if {$lang == ""} {
		set langInfo ""
		set lang_clause ""
	} else {
		tpSetVar ShowExtraInfo 1
		set langInfo "([get_lang_name $lang] only)"
		set lang_clause "and lang = '$lang'"
	}

	set sql_keyword [_clean_sql_input $keyword]
	set sql [subst {
		select
			search_id,
			link,
			url,
			lang,
			canvas_name,
			disporder
		from
			tSearchPredefined
		where
			keyword = '$sql_keyword'
			$lang_clause
		order by
			disporder,
			lang
	}]

	set stmt [inf_prep_sql  $DB $sql]
	set rs   [inf_exec_stmt $stmt]

	tpSetVar NumPredefined [set nrows [db_get_nrows $rs]]

	if {$nrows > 0} {
		for {set r 0} {$r < $nrows} {incr r} {
			set PREDEFINED($r,search_id)   [db_get_col $rs $r search_id]
			set PREDEFINED($r,link)        [db_get_col $rs $r link]
			set PREDEFINED($r,url)         [db_get_col $rs $r url]
			set PREDEFINED($r,lang_name)   [get_lang_name [db_get_col $rs $r lang]]
			set PREDEFINED($r,disporder)   [db_get_col $rs $r disporder]
			set PREDEFINED($r,canvas_name) [db_get_col $rs $r canvas_name]
		}
	}

	db_close $rs

	tpBindString keyword     $keyword
	tpBindString lang        $lang

	tpBindString KeywordInfo $keywordInfo
	tpBindString LangInfo    $langInfo

	tpBindVar  SearchID    PREDEFINED search_id   predefined_idx
	tpBindVar  Link        PREDEFINED link        predefined_idx
	tpBindVar  URL         PREDEFINED url         predefined_idx
	tpBindVar  LangName    PREDEFINED lang_name   predefined_idx
	tpBindVar  Disporder   PREDEFINED disporder   predefined_idx
	tpBindVar  Canvas_name PREDEFINED canvas_name predefined_idx

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/predefined_list.html"

	catch {unset PREDEFINED}
}

proc do_predefined_list {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"BackPredefinedKeywords" {
			reqSetArg keyword [reqGetArg crit_keyword]
			reqSetArg lang    [reqGetArg crit_lang]
			go_predefined_keywords
			return
		}
	}
	go_predefined_list
}

proc go_predefined {} {
	global DB

	set search_id   [reqGetArg search_id]
	set keyword     [reqGetArg keyword]
	set link        [reqGetArg link]
	set url         [reqGetArg url]
	set lang        [reqGetArg lang]
	set disporder   [reqGetArg disporder]
	set canvas_name [reqGetArg canvas_name]

	set nrows 0

	if {$search_id > 0} {
		set sql [subst {
			select
				keyword,
				link,
				url,
				lang,
				canvas_name,
				disporder
			from
				tSearchPredefined
			where
				search_id = $search_id
		}]

		set stmt [inf_prep_sql  $DB $sql]
		set rs   [inf_exec_stmt $stmt]

		set nrows [db_get_nrows $rs]

		if {$nrows > 0} {
			set keyword     [db_get_col $rs 0 keyword]
			set link        [db_get_col $rs 0 link]
			set url         [db_get_col $rs 0 url]
			set lang        [db_get_col $rs 0 lang]
			set disporder   [db_get_col $rs 0 disporder]
			set canvas_name [db_get_col $rs 0 canvas_name]
		}
	}

	tpSetVar NumPredefined $nrows

	tpBindString SearchID    $search_id
	tpBindString Keyword     $keyword
	tpBindString Link        $link
	tpBindString URL         $url
	tpBindString Lang        $lang
	tpBindString Disporder   $disporder
	tpBindString Canvas_name $canvas_name

	bind_available_langs

	# Rebind search criteria
	tpBindString crit_keyword [reqGetArg crit_keyword]
	tpBindString crit_lang    [reqGetArg crit_lang]

	asPlayFile -nocache "search/predefined.html"
}

proc do_predefined {} {
	set action [reqGetArgs SubmitName]
	switch -- $action {
		"AddPredefined" {
			add_predefined [reqGetArg keyword] \
			               [reqGetArg link] \
			               [reqGetArg url] \
			               [reqGetArg lang] \
			               [reqGetArg canvas_name] \
			               [reqGetArg disporder]
		}
		"UpdPredefined" {
			upd_predefined [reqGetArg search_id] \
			               [reqGetArg keyword] \
			               [reqGetArg link] \
			               [reqGetArg url] \
			               [reqGetArg lang] \
			               [reqGetArg canvas_name] \
			               [reqGetArg disporder] \
		}
		"DelPredefined" {
			del_predefined [reqGetArg search_id]
		}
		"BackPredefinedList" {
			reqSetArg lang [reqGetArg crit_lang]
			go_predefined_list
			return
		}
	}
	go_predefined
}

proc add_predefined {keyword link url lang canvas_name {disporder 1}} {
	global DB USERNAME

	if {$disporder == ""} {set disporder 1}

	set sql {
		execute procedure pSearchInsPredefined (
			p_adminuser   = ?,
			p_keyword     = ?,
			p_link        = ?,
			p_url         = ?,
			p_disporder   = ?,
			p_lang        = ?,
			p_canvas_name = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt \
		                      $USERNAME \
		                      [string trim $keyword] \
		                      [string trim $link] \
		                      [string trim $url] \
		                      $disporder \
		                      $lang \
		                      $canvas_name]
	} msg]} {
		err_add $msg
		return
	}

	if {[db_get_nrows $rs] == 1} {
		msg_bind "Successfully added"

		set search_id [db_get_coln $rs 0 0]
		reqSetArg search_id $search_id
	} else {
		err_add "Unexpected number of inserts into tSearchPredefined"
		return
	}

}

proc upd_predefined {search_id keyword link url lang canvas_name disporder} {
	global DB USERNAME

	set sql {
		execute procedure pSearchUpdPredefined (
			p_adminuser   = ?,
			p_search_id   = ?,
			p_keyword     = ?,
			p_link        = ?,
			p_url         = ?,
			p_disporder   = ?,
			p_lang        = ?,
			p_canvas_name = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt \
		                      $USERNAME \
		                      $search_id \
		                      [string trim $keyword] \
		                      [string trim $link] \
		                      [string trim $url] \
		                      $disporder \
		                      $lang \
		                      $canvas_name]
	} msg]} {
		err_add $msg
		return
	} else {
		msg_bind "Successfully updated"
	}
}

proc del_predefined {search_id} {
	global DB USERNAME

	set sql {
		execute procedure pSearchDelPredefined (
			p_adminuser = ?,
			p_search_id = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt $USERNAME $search_id]
	} msg]} {
		err_add $msg
		return
	} else {
		msg_bind "Successfully deleted"
	}
}

proc _clean_sql_input {input_string} {
	set charMap [list ' '']
	return [string map $charMap [string tolower [string trim $input_string]]]
}

proc _clean_sql_wild {input_string} {
	set charMap [list % \\% _ \\%]
	return [string map $charMap [_clean_sql_input $input_string]]
}

proc get_lang_name {lang} {
	switch -- $lang {
		en {return "English"}
		de {return "German"}
		default {return $lang}
	}
}

}
